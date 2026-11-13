-- ZXF1 carrier layer: bytes <-> one chat line of 1-4 letter words. Pure logic, no WoW API.
-- Word length carries 2 bits (L = value + 1), the capitalisation of its letters carries the next L bits.
local Z=ZenialCommunity
local C={MAX_LINE=255,MARKER='zENi AlxF',LENGTH_BITS=2,MAX_UNKNOWN=2};Z.CrossFactionCodec=C
local MARKER_PATTERNS={'0110','1001'}
local CONSONANTS,VOWELS='bdfgklmnrstvz','aeiou'
local floor=math.floor
local function xor(a,b)
    local r,p=0,1
    for _=1,8 do
        if a%2~=b%2 then r=r+p end
        a,b,p=floor(a/2),floor(b/2),p*2
    end
    return r
end
local function mask(i)return(167*i+89)%256 end
local function bitsOf(bytes)
    local bits,n={},0
    for i=1,#bytes do
        local v=xor(bytes[i],mask(i-1))
        for s=7,0,-1 do n=n+1;bits[n]=floor(v/2^s)%2 end
    end
    return bits,n
end
-- Letters carry nothing; they are derived from the frame so lines look like words.
local function letter(sum,n,odd)
    local set=odd and CONSONANTS or VOWELS
    local i=(sum+7*n)%#set+1
    return set:sub(i,i)
end
function C.EncodeLine(bytes)
    local bits,total=bitsOf(bytes)
    local sum=0;for i=1,#bytes do sum=sum+bytes[i]end
    local pos,n,words,length=0,0,{},#C.MARKER
    while pos<total do
        local value=0
        for _=1,C.LENGTH_BITS do pos=pos+1;value=value*2+(bits[pos]or 0)end
        local count=value+1;local chars={}
        for k=1,count do
            pos=pos+1
            local ch=letter(sum,n,k%2==1);n=n+1
            chars[k]=(bits[pos]==1)and ch:upper()or ch
        end
        words[#words+1]=table.concat(chars)
        length=length+1+count
        if length>C.MAX_LINE then return nil,'too_long'end
    end
    if #words==0 then return C.MARKER end
    return C.MARKER..' '..table.concat(words,' ')
end
function C.Fits(bytes)return(C.EncodeLine(bytes))~=nil end
local function split(text)
    local words,from={},1
    while true do
        local at=text:find(' ',from,true)
        if not at then words[#words+1]=text:sub(from);return words end
        words[#words+1]=text:sub(from,at-1);from=at+1
    end
end
local function markerOk(words)
    for w=1,2 do
        local word=words[w]
        if not word or #word~=4 or word:find('[^A-Za-z]')then return false end
        local pattern=word:gsub('%u','1'):gsub('%l','0')
        if pattern~=MARKER_PATTERNS[w]then return false end
    end
    return true
end
-- Returns bytes, unknownBits. unknownBits are 0-based positions in the scrambled bit stream
-- (bit 0 = most significant bit of scrambled byte 0); the stream placeholder there is 0.
-- Unknown bits that fall into a discarded partial last byte are not reported.
function C.DecodeLine(text)
    if type(text)~='string'then return nil,'no_marker'end
    local words=split(text)
    if not markerOk(words)then return nil,'no_marker'end
    if #text>C.MAX_LINE then return nil,'bad_word'end
    local bits,total,unknown={},0,{}
    for w=3,#words do
        local word=words[w];local count=#word
        if count<1 or count>4 then return nil,'bad_word'end
        local value=count-1
        bits[total+1]=floor(value/2);bits[total+2]=value%2;total=total+2
        for k=1,count do
            local ch=word:sub(k,k);total=total+1
            if ch:find('^%u$')then bits[total]=1
            elseif ch:find('^%l$')then bits[total]=0
            else bits[total]=0;unknown[#unknown+1]=total-1 end
        end
    end
    local out={}
    for i=1,floor(total/8)do
        local v=0;for k=1,8 do v=v*2+bits[(i-1)*8+k]end
        out[i]=xor(v,mask(i-1))
    end
    local kept,limit={},#out*8
    for _,p in ipairs(unknown)do if p<limit then kept[#kept+1]=p end end
    if #kept>C.MAX_UNKNOWN then return nil,'unknown_bits'end
    return out,kept
end
-- position as reported by DecodeLine. The scrambling is a bitwise XOR, so flipping the same bit in the
-- decoded bytes equals flipping it in the scrambled stream. Returns a copy.
function C.FlipBit(bytes,position)
    local copy={};for i=1,#bytes do copy[i]=bytes[i]end
    local i=floor(position/8)+1;local weight=2^(7-position%8)
    if copy[i]then
        copy[i]=floor(copy[i]/weight)%2==1 and copy[i]-weight or copy[i]+weight
    end
    return copy
end
