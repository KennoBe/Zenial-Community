-- ZXF1 frame layer: header, CRC-16, fragmentation and reassembly on top of CrossFactionCodec. Pure logic, no WoW API.
local Z=ZenialCommunity
local P={VERSION=1,MAX_FRAGMENTS=16,SAFE_PAYLOAD=30,LIMITS={maxTextBytes=120,maxFragments=4,rateLines=8,rateWindow=10,timeout=20,echoTimeout=5}};Z.CrossFactionProtocol=P
local C=Z.CrossFactionCodec
local floor,char=math.floor,string.char
local HEADER,CRC_BYTES=4,2
local function xor(a,b,bits)
    local r,p=0,1
    for _=1,bits do
        if a%2~=b%2 then r=r+p end
        a,b,p=floor(a/2),floor(b/2),p*2
    end
    return r
end
local crcTable
local function buildTable()
    crcTable={}
    for i=0,255 do
        local c=i*256
        for _=1,8 do if c>=32768 then c=xor((c*2)%65536,0x1021,16) else c=(c*2)%65536 end end
        crcTable[i]=c
    end
end
-- CRC-16/CCITT-FALSE over a byte list (1-based), optionally only up to index `last`.
function P.CRC16(bytes,last)
    if not crcTable then buildTable() end
    local crc=0xFFFF
    for i=1,last or #bytes do
        crc=xor((crc%256)*256,crcTable[xor(floor(crc/256),bytes[i],8)],16)
    end
    return crc
end
local function toBytes(s)local t={};for i=1,#s do t[i]=s:byte(i)end;return t end
local function trim(s)return(s:gsub('^%s+',''):gsub('%s+$',''))end
-- Rules 6.4: links reduced to their label, colour codes removed, trimmed, control characters refused, length checked.
function P.Prepare(text)
    if type(text)~='string'then return nil,'empty'end
    text=text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|H[^|]*|h(.-)|h','%1')
    text=trim(text)
    if text==''then return nil,'empty'end
    if text:find('[%z\1-\31\127]')then return nil,'invalid_chars'end
    local over=#text-P.LIMITS.maxTextBytes
    if over>0 then return nil,'too_long',over end
    return text
end
local function frameBytes(ftype,messageId,index,last,payload,from,to)
    local b={P.VERSION*32+ftype*4,messageId%256,index*16+last,to-from+1}
    for i=from,to do b[#b+1]=payload[i]end
    local crc=P.CRC16(b);b[#b+1]=floor(crc/256);b[#b+1]=crc%256
    return b
end
-- Greedy split for a given last index; returns the lines, or nil when more than `limit` lines are needed.
local function split(payload,messageId,last,limit)
    local lines,at,n={},1,#payload
    while at<=n do
        local index=#lines
        if index>=limit then return nil end
        local line
        for take=math.min(n-at+1,40),1,-1 do
            local l=C.EncodeLine(frameBytes(0,messageId,index,last,payload,at,at+take-1))
            if l then line=l;at=at+take;break end
        end
        if not line then return nil end
        lines[index+1]=line
    end
    return lines
end
-- The last fragment index is part of every header, so try k = 1, 2, ... until the greedy split yields exactly k lines.
function P.BuildMessage(clean,messageId)
    if type(clean)~='string'or clean==''then return nil,'empty'end
    local payload=toBytes(clean)
    local limit=math.min(P.LIMITS.maxFragments,P.MAX_FRAGMENTS)
    for k=1,limit do
        local lines=split(payload,messageId,k-1,limit)
        if lines and#lines==k then return lines end
    end
    -- No exact fit: fixed pieces of the guaranteed capacity (30 payload bytes always fit one line, see 6.1).
    local size=P.SAFE_PAYLOAD
    local m=math.ceil(#payload/size)
    if m>limit then return nil,'too_long'end
    local lines={}
    for i=1,m do
        local from=(i-1)*size+1
        local line=C.EncodeLine(frameBytes(0,messageId,i-1,m-1,payload,from,math.min(#payload,from+size-1)))
        if not line then return nil,'too_long'end
        lines[i]=line
    end
    return lines
end
function P.BuildHello(messageId,major,minor)
    local payload={1,(major or 0)%256,(minor or 0)%256}
    return{assert(C.EncodeLine(frameBytes(1,messageId,0,0,payload,1,3)))}
end
local function attempt(bytes)
    if#bytes<HEADER+CRC_BYTES then return nil,'length'end
    local total=HEADER+bytes[4]+CRC_BYTES
    if#bytes~=total then return nil,'length'end
    if bytes[total-1]*256+bytes[total]~=P.CRC16(bytes,total-CRC_BYTES)then return nil,'crc'end
    local payload={};for i=HEADER+1,total-CRC_BYTES do payload[#payload+1]=char(bytes[i])end
    local b0,b2=bytes[1],bytes[3]
    return{version=floor(b0/32),type=floor(b0/4)%8,encoding=b0%4,messageId=bytes[2],index=floor(b2/16),last=b2%16,crc=bytes[total-1]*256+bytes[total],payload=table.concat(payload)}
end
-- Tries every assignment of the (at most 2) unknown bits against the CRC.
function P.ParseLine(text)
    local bytes,unknown=C.DecodeLine(text)
    if not bytes then return nil,unknown end
    local count,sawCrc=#unknown,false
    for combo=0,2^count-1 do
        local try,bit=bytes,combo
        for u=1,count do
            if bit%2==1 then try=C.FlipBit(try,unknown[u])end
            bit=floor(bit/2)
        end
        local frame,why=attempt(try)
        if frame then return frame end
        if why=='crc'then sawCrc=true end
    end
    return nil,sawCrc and'crc'or'length'
end
-- Reassembly (6.3). Open messages are keyed senderKey..':'..messageId; finished keys are remembered for LIMITS.timeout.
local Assembler={};Assembler.__index=Assembler
function P.NewAssembler()return setmetatable({open={},done={},seq=0},Assembler)end
function Assembler:Reset()self.open={};self.done={};self.seq=0 end
local MAX_OPEN,MAX_PER_SENDER=16,4
local function evictOldest(self,sender)
    local oldest
    for _,e in pairs(self.open)do
        if(not sender or e.sender==sender)and(not oldest or e.seq<oldest.seq)then oldest=e end
    end
    if oldest then self.open[oldest.key]=nil end
end
function Assembler:Accept(senderKey,frame,now)
    if frame.version~=P.VERSION then return'rejected','version'end
    if frame.type~=0 then return'rejected','type'end
    if frame.index>frame.last then return'rejected','index'end
    local key=senderKey..':'..frame.messageId
    local d=self.done[key]
    if d then
        -- same index and CRC inside the timeout: a real duplicate; anything else is a new message that reuses the id
        if now<d.untilAt and d.crcs[frame.index]==frame.crc then return'duplicate'end
        self.done[key]=nil
    end
    local e=self.open[key]
    local restarted=false
    if e then
        if e.last~=frame.last then self.open[key]=nil;return'rejected','mismatch'end
        if e.parts[frame.index]then
            if e.crcs[frame.index]==frame.crc then return'duplicate'end
            self.open[key]=nil;e=nil;restarted=true
        end
    end
    if not e then
        e={key=key,sender=senderKey,messageId=frame.messageId,last=frame.last,parts={},crcs={},count=0,first=now}
        if frame.last>0 then
            local perSender,total=0,0
            for _,o in pairs(self.open)do total=total+1;if o.sender==senderKey then perSender=perSender+1 end end
            if perSender>=MAX_PER_SENDER then evictOldest(self,senderKey);total=total-1 end
            if total>=MAX_OPEN then evictOldest(self)end
            self.seq=self.seq+1;e.seq=self.seq;self.open[key]=e
        end
    end
    e.parts[frame.index]=frame.payload;e.crcs[frame.index]=frame.crc;e.count=e.count+1
    if e.count>=e.last+1 then
        self.open[key]=nil;self.done[key]={untilAt=now+P.LIMITS.timeout,crcs=e.crcs}
        return'complete',table.concat(e.parts,'',0,e.last)
    end
    if restarted then return'partial','restart'end
    return'partial'
end
-- Lists only really incomplete expired messages; also forgets finished-message markers that ran out.
function Assembler:Expire(now)
    local expired,timeout={},P.LIMITS.timeout
    for _,e in pairs(self.open)do
        if now-e.first>=timeout then expired[#expired+1]=e end
    end
    table.sort(expired,function(a,b)return a.seq<b.seq end)
    local list={}
    for i,e in ipairs(expired)do self.open[e.key]=nil;list[i]={senderKey=e.sender,messageId=e.messageId}end
    for key,d in pairs(self.done)do if now>=d.untilAt then self.done[key]=nil end end
    return list
end
local function utf8Length(s,i)
    local b=s:byte(i)
    local function cont(k,lo,hi)local c=s:byte(i+k);return c~=nil and c>=(lo or 0x80)and c<=(hi or 0xBF)end
    if b>=0xC2 and b<=0xDF then
        if cont(1)then return 2 end
    elseif b>=0xE0 and b<=0xEF then
        local lo,hi=0x80,0xBF;if b==0xE0 then lo=0xA0 elseif b==0xED then hi=0x9F end
        if cont(1,lo,hi)and cont(2)then return 3 end
    elseif b>=0xF0 and b<=0xF4 then
        local lo,hi=0x80,0xBF;if b==0xF0 then lo=0x90 elseif b==0xF4 then hi=0x8F end
        if cont(1,lo,hi)and cont(2)and cont(3)then return 4 end
    end
    return nil
end
-- Safe for display: invalid UTF-8 becomes '?', control characters vanish, every '|' is doubled.
function P.Display(text)
    if type(text)~='string'then return''end
    local out,i,n={},1,#text
    while i<=n do
        local b=text:byte(i)
        if b<0x20 or b==0x7F then i=i+1
        elseif b==124 then out[#out+1]='||';i=i+1
        elseif b<0x80 then out[#out+1]=char(b);i=i+1
        else
            local len=utf8Length(text,i)
            if len then out[#out+1]=text:sub(i,i+len-1);i=i+len else out[#out+1]='?';i=i+1 end
        end
    end
    return table.concat(out)
end
