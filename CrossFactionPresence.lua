-- XF3-T06 passive detection through invisible presence messages (D-09, 6.5): own addon prefix ZENIALXF1, never visible chat.
-- Payload: <kind>:<protocol>:<capabilities>:<major>.<minor>:<GUID>. Kinds: H greeting, P ping, A answer, B beacon.
-- Everything timed hangs on N.Tick (the one-second tick of Main.lua): no timer, no OnUpdate. SendChatMessage is never called here.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local R=Z.CrossFactionRegistry
local N={PREFIX='ZENIALXF1',PROTO=1,
    RATE={hello=30,bundle=1.5,ping=300,pingGap=2,beacon=15,reply=60,await=10,pendingTTL=600,pendingMax=64,awaitingMax=32},
    pending={},awaiting={},
    stats={sent={H=0,P=0,A=0,B=0},failed={H=0,P=0,A=0,B=0}}}
Z.CrossFactionPresence=N
local MAX_BYTES=64
local KINDS={H=true,P=true,A=true,B=true}
-- Channels whose senders are certainly of our own faction. Groups and guilds may be mixed on some clients, so only
-- an addon whisper counts; everywhere else the faction stays unknown until a chat line shows the language.
local OWN_FACTION={WHISPER=true}
local helloAt,helloDone,beaconAt,pingAt,replyAt,lastPing={},{},{},{},{}
local dueAt
local registered,listening
local hooked={}

local function discovery()
    local XF=Z.CrossFaction
    return type(XF)=='table'and XF.Settings().discovery==true
end
local function ownGuid()
    local g=Z.me and Z.me.guid
    if type(g)~='string'or g==''then g=A.Call(UnitGUID,'player')end
    if type(g)=='string'and g~=''then return g end
end
local function within(last,now,window)return last~=nil and now>=last and now-last<window end
local function namePart(n)return n:match('^([^%-]+)')end
local function realmPart(n)local r=n:match('^[^%-]+%-(.+)$');return r and r:gsub('[%s%-]','')end
local function cleanSender(sender)
    if A.Safe(sender)and type(sender)=='string'and#sender>0 and#sender<=64 and not sender:find('[|%z\1-\31\127]')then return sender end
end
local function readableGuid(g)return A.Safe(g)and type(g)=='string'and g:sub(1,7)=='Player-'and#g<=64 and g or nil end

-- ===== Payload =====
function N.Payload(kind)
    if not KINDS[kind]then return nil end
    local guid=ownGuid()
    local XF=Z.CrossFaction
    if not guid or guid:find(':',1,true)or type(XF)~='table'then return nil end
    local major,minor=XF.Version()
    major=math.min(math.max(tonumber(major)or 0,0),999);minor=math.min(math.max(tonumber(minor)or 0,0),999)
    local caps=XF.Settings().enabled and 1 or 0
    local text=string.format('%s:%d:%d:%d.%d:%s',kind,N.PROTO,caps,major,minor,guid)
    if#text>MAX_BYTES then return nil end
    return text
end
function N.Parse(text)
    if not A.Safe(text)or type(text)~='string'or#text>MAX_BYTES then return nil end
    local kind,proto,caps,major,minor,guid=text:match('^(%u):(%d+):(%d+):(%d+)%.(%d+):([^:]+)$')
    if not kind or not KINDS[kind]then return nil end
    if#proto>3 or#caps>3 or#major>3 or#minor>3 then return nil end
    proto,caps,major,minor=tonumber(proto),tonumber(caps),tonumber(major),tonumber(minor)
    if proto<1 or proto>255 or caps>255 then return nil end
    if#guid>64 or not guid:match('^Player%-[%w%-]+$')then return nil end
    return{kind=kind,proto=proto,caps=caps,major=major,minor=minor,guid=guid}
end

-- ===== Sending (invisible addon messages only) =====
local function sendOk(r)
    local e=Enum and Enum.SendAddonMessageResult
    return r==true or r==(e and e.Success or 0)
end
-- Counts the outcome per kind; a result other than success is never retried (nil = nothing reported = not a reported success).
local function send(kind,channel,target)
    local payload=N.Payload(kind)
    if not payload then return false end
    local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage
    local ok=false
    if type(fn)=='function'then ok=sendOk(A.Call(fn,N.PREFIX,payload,channel,target))end
    local bucket=ok and N.stats.sent or N.stats.failed
    bucket[kind]=bucket[kind]+1
    return ok
end

-- ===== Confirmation =====
local function faction(channel)
    if OWN_FACTION[channel]then
        local f=Z.me and Z.me.faction
        if type(f)=='string'then return f end
    end
end
-- Any valid signal (also an incompatible one) ends a pending refresh wait for that GUID.
local function accept(guid,sender,proto,caps,channel)
    local XF=Z.CrossFaction
    if type(XF)~='table'then return false end
    N.awaiting[guid]=nil
    local f=faction(channel)
    if proto==N.PROTO then
        return XF.Confirm(guid,{name=sender,proto=proto,caps=caps,xfChat=caps%2==1,source='addon',faction=f})
    end
    XF.MarkIncompatible(guid,{name=sender,proto=proto,source='addon',faction=f})
    return true
end
local function addPending(guid,entry)
    if N.pending[guid]==nil then
        local n,oldest,at=0
        for g,p in pairs(N.pending)do n=n+1;if not at or p.at<at then oldest,at=g,p.at end end
        if n>=N.RATE.pendingMax and oldest then N.pending[oldest]=nil end
    end
    N.pending[guid]=entry
end
function N.HasPending()return next(N.pending)~=nil end
-- Called when a chat line, unit or target shows this GUID with a name.
function N.Resolve(guid,name)
    if not A.Safe(guid,name)or type(guid)~='string'or type(name)~='string'or name==''then return false end
    local p=N.pending[guid]
    if not p then return false end
    N.pending[guid]=nil
    if namePart(name)~=namePart(p.name)then return false end
    local r1,r2=realmPart(name),realmPart(p.name)
    if r1 and r2 and r1~=r2 then return false end
    return accept(guid,p.name,p.proto,p.caps,p.channel)
end

-- ===== Receiving =====
-- GetPlayerInfoByGUID returns more than the five values A.Call keeps: call it directly and check what is used.
local function identityOf(guid)
    local ok,_,_,_,_,_,name,realm=pcall(GetPlayerInfoByGUID,guid)
    if not ok or not A.Safe(name,realm)then return false end
    if type(name)~='string'or name==''then return true,nil end
    if type(realm)~='string'then realm=''end
    return true,name,realm
end
function N.OnAddon(prefix,text,channel,sender)
    if not A.Safe(prefix,text,channel,sender)then return false end
    if type(prefix)~='string'or prefix~=N.PREFIX or type(text)~='string'or type(channel)~='string'or type(sender)~='string'then return false end
    sender=cleanSender(sender)
    local msg=N.Parse(text)
    if not sender or not msg then return false end
    local mine=ownGuid()
    if mine and msg.guid==mine then return false end
    channel=channel:upper()
    local known,name,realm=identityOf(msg.guid)
    if not known then return false end
    if not name then
        addPending(msg.guid,{name=sender,kind=msg.kind,proto=msg.proto,caps=msg.caps,channel=channel,at=A.Clock()})
        return true
    end
    if name~=namePart(sender)then return false end
    local senderRealm=realmPart(sender)
    if realm~=''and senderRealm and realm:gsub('[%s%-]','')~=senderRealm then return false end
    if not accept(msg.guid,sender,msg.proto,msg.caps,channel)then return false end
    if(msg.kind=='H'or msg.kind=='P')and msg.proto==N.PROTO and discovery()then
        local now=A.Clock()
        if not within(replyAt[msg.guid],now,N.RATE.reply)then
            replyAt[msg.guid]=now
            send('A','WHISPER',sender)
        end
    end
    return true
end

-- ===== Greeting (a) =====
local function groupChannel()
    local category=LE_PARTY_CATEGORY_INSTANCE
    if category~=nil and A.Call(IsInGroup,category)==true then return'INSTANCE_CHAT'end
    if A.Call(IsInRaid)==true then return'RAID'end
    if A.Call(IsInGroup)==true then return'PARTY'end
end
-- Only notes that a greeting is due; N.Tick sends it once the triggers have been quiet for RATE.bundle.
function N.Announce()
    if not discovery()then return end
    dueAt=A.Clock();helloDone={}
end
local function flushHello(now)
    if not discovery()then dueAt=nil;return end
    local channels={}
    local group=groupChannel()
    if group then channels[#channels+1]=group end
    if A.Call(IsInGuild)==true then channels[#channels+1]='GUILD'end
    local blocked=false
    for _,channel in ipairs(channels)do
        if not helloDone[channel]then
            if within(helloAt[channel],now,N.RATE.hello)then blocked=true
            else helloAt[channel]=now;helloDone[channel]=true;send('H',channel)end
        end
    end
    if not blocked then dueAt=nil end
end

-- ===== Ping (b) and refresh of remembered players (D-07) =====
local function noteAwaiting(guid,now)
    if N.awaiting[guid]~=nil then return end
    local n=0
    for _ in pairs(N.awaiting)do n=n+1 end
    if n<N.RATE.awaitingMax then N.awaiting[guid]=now end
end
local function ping(guid,target)
    local XF=Z.CrossFaction
    if type(XF)~='table'or not discovery()then return false end
    local mine=ownGuid()
    if not mine or guid==mine then return false end
    local now=A.Clock()
    if within(lastPing,now,N.RATE.pingGap)or within(pingAt[guid],now,N.RATE.ping)then return false end
    local refresh=R.NeedsRefresh(guid)
    if XF.GetPlayerStatus(guid)~=nil and not refresh then return false end
    lastPing,pingAt[guid]=now,now
    local ok=send('P','WHISPER',target)
    if ok and refresh then noteAwaiting(guid,now)end
    return ok
end
local function targetName()
    local full=A.Call(GetUnitName,'target',true)
    if type(full)=='string'and full~=''then return cleanSender(full)end
    local name,realm=A.Call(UnitFullName,'target')
    if type(name)=='string'and name~=''then
        if type(realm)=='string'and realm~=''then name=name..'-'..realm end
        return cleanSender(name)
    end
end
function N.OnTarget()
    if not discovery()then return end
    if A.Call(UnitIsPlayer,'target')~=true or A.Call(UnitIsFriend,'player','target')~=true then return end
    local guid=readableGuid(A.Call(UnitGUID,'target'))
    if not guid then return end
    local now=A.Clock()
    if within(lastPing,now,N.RATE.pingGap)or within(pingAt[guid],now,N.RATE.ping)then return end
    local name=targetName()
    if name then ping(guid,name)end
end
-- CHAT_MSG_WHISPER / CHAT_MSG_WHISPER_INFORM: arg2 is the conversation partner, arg12 his GUID.
function N.OnWhisper(event,...)
    if event~='CHAT_MSG_WHISPER'and event~='CHAT_MSG_WHISPER_INFORM'then return end
    if not discovery()then return end
    local _,sender,_,_,_,_,_,_,_,_,_,guid=...
    if not A.Safe(sender,guid)then return end
    sender,guid=cleanSender(sender),readableGuid(guid)
    if sender and guid then ping(guid,sender)end
end

-- ===== Beacon (c) =====
function N.Beacon(chatType)
    if chatType~='SAY'and chatType~='YELL'then return end
    if not discovery()then return end
    local now=A.Clock()
    if within(beaconAt[chatType],now,N.RATE.beacon)then return end
    beaconAt[chatType]=now
    send('B',chatType)
end
local function beaconFor(chatType)
    if chatType==nil then chatType='SAY'end
    if not A.Safe(chatType)or type(chatType)~='string'then return end
    chatType=chatType:upper()
    if chatType=='SAY'or chatType=='YELL'then N.Beacon(chatType)end
end
local function hookSend(_,chatType)pcall(beaconFor,chatType)end
local function hookEditBox(editBox)
    pcall(function()
        if type(editBox)~='table'or type(editBox.GetAttribute)~='function'then return end
        local ok,chatType=pcall(editBox.GetAttribute,editBox,'chatType')
        if ok and chatType~=nil then beaconFor(chatType)end
    end)
end
local function installHooks()
    if type(hooksecurefunc)~='function'then return end
    if not hooked.SendChatMessage and type(SendChatMessage)=='function'then
        hooked.SendChatMessage=pcall(hooksecurefunc,'SendChatMessage',hookSend)
    end
    if not hooked.CSendChatMessage and type(C_ChatInfo)=='table'and type(C_ChatInfo.SendChatMessage)=='function'then
        hooked.CSendChatMessage=pcall(hooksecurefunc,C_ChatInfo,'SendChatMessage',hookSend)
    end
    for _,name in ipairs({'ChatEdit_ActivateChat','ChatEdit_UpdateHeader'})do
        if not hooked[name]and type(_G[name])=='function'then hooked[name]=pcall(hooksecurefunc,name,hookEditBox)end
    end
end

-- ===== Time-based work (called from XF.Tick, once per second) =====
function N.Tick()
    local now=A.Clock()
    if dueAt then
        if now<dueAt then dueAt=now end
        if now-dueAt>=N.RATE.bundle then flushHello(now)end
    end
    local XF=Z.CrossFaction
    for guid,at in pairs(N.awaiting)do
        if now<at or now-at>=N.RATE.await then
            N.awaiting[guid]=nil
            if R.Miss(guid,A.Now())=='removed'and type(XF)=='table'then XF.NotifyPlayer(guid)end
        end
    end
    for guid,p in pairs(N.pending)do
        if now<p.at or now-p.at>=N.RATE.pendingTTL then N.pending[guid]=nil end
    end
    for guid,at in pairs(pingAt)do if not within(at,now,N.RATE.ping)then pingAt[guid]=nil end end
    for guid,at in pairs(replyAt)do if not within(at,now,N.RATE.reply)then replyAt[guid]=nil end end
end

-- Idempotent: prefix, listener and hooks are set up once (hooks retried while their function is missing).
function N.Initialize()
    if not registered then
        local fn=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
        local e=Enum and Enum.RegisterAddonMessagePrefixResult
        local r=type(fn)=='function'and A.Call(fn,N.PREFIX)or nil
        registered=r==true or(r~=nil and r==(e and e.Success or 0))or(r~=nil and e~=nil and r==e.DuplicatePrefix)
    end
    local XF=Z.CrossFaction
    if not listening and type(XF)=='table'and type(XF.RegisterListener)=='function'then
        listening=XF.RegisterListener('presence',function(event,payload)
            if event=='PLAYER'and type(payload)=='table'and type(payload.guid)=='string'then N.awaiting[payload.guid]=nil end
        end)==true
    end
    installHooks()
end
