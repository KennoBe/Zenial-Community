-- XF3-T06 passive detection through invisible presence messages (D-09, 6.5): own addon prefix ZENIALXF1, never visible chat.
-- Payload: <kind>:<protocol>:<capabilities>:<major>.<minor>:<GUID>. Kinds: H greeting, P ping, A answer, B beacon.
-- Everything timed hangs on N.Tick (the one-second tick of Main.lua): no timer, no OnUpdate. SendChatMessage is never called here.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local R=Z.CrossFactionRegistry
-- XF3-T07 (D-09 d): Battle.net ping for opponents (C_BattleNet.SendGameData, same prefix). Built and tested, but locked: it only
-- works when BNET_UNLOCKED is true (set by hand after test G10 and decision E-07) and the bnetDiscovery switch is on.
local N={PREFIX='ZENIALXF1',PROTO=1,BNET_UNLOCKED=false,
    RATE={hello=30,bundle=1.5,ping=300,pingGap=2,beacon=15,reply=60,await=10,pendingTTL=600,pendingMax=64,awaitingMax=32,
        bnetPing=1800,bnetGap=10,bnetReply=60},
    pending={},awaiting={},
    stats={sent={H=0,P=0,A=0,B=0,BP=0,BA=0},failed={H=0,P=0,A=0,B=0,BP=0,BA=0}}}
Z.CrossFactionPresence=N
local MAX_BYTES=64
local KINDS={H=true,P=true,A=true,B=true}
-- Channels whose senders are certainly of our own faction. Groups and guilds may be mixed on some clients, so only
-- an addon whisper counts; everywhere else the faction stays unknown until a chat line shows the language.
local OWN_FACTION={WHISPER=true}
local helloAt,helloDone,beaconAt,pingAt,replyAt,lastPing={},{},{},{},{}
local bnetPingAt,bnetReplyAt,bnetLast={},{},nil
local dueAt
local registered,listening
local hooked={}

local function discovery()
    local XF=Z.CrossFaction
    return type(XF)=='table'and XF.Settings().discovery==true
end
local function bnetEnabled()
    local XF=Z.CrossFaction
    return N.BNET_UNLOCKED==true and type(XF)=='table'and XF.Settings().bnetDiscovery==true
end
local function ownGuid()
    local g=Z.me and Z.me.guid
    if type(g)~='string'or g==''then g=A.Call(UnitGUID,'player')end
    if type(g)=='string'and g~=''then return g end
end
local function within(last,now,window)return last~=nil and now>=last and now-last<window end
local function normRealm(r)
    if type(r)=='string'then r=r:gsub('[%s%-]','');if r~=''then return r end end
end
local function ownRealm()
    local r=normRealm(A.Call(GetNormalizedRealmName))
    if not r and Z.me and A.Safe(Z.me.realm)then r=normRealm(Z.me.realm)end
    return r
end
-- Identity keys come from Logic.Identity (Forever: "first last", realm suffix is not part of it; old one-part names: "name-realm").
-- A one-part name without realm part gets the own realm; own realm unreadable: no key (two-part names need no realm).
local function senderKey(name)
    local L=Z.Logic
    if type(L)~='table'or type(name)~='string'then return nil end
    local key=L.Identity(name)
    if key then return key end
    local own=ownRealm()
    if own then return(L.Identity(name,own))end
end
-- All keys the client's answer of GetPlayerInfoByGUID can stand for (whole name, surname in the realm field, Retail name+realm, empty realm = own).
local function guidKeys(name,realm)
    local L=Z.Logic
    local keys={}
    local function add(key)if key then keys[key]=true end end
    if type(L)~='table'then return keys end
    add((L.Identity(name)))
    if type(realm)=='string'and realm~=''then
        add((L.Identity(name..' '..realm)))
        add((L.Identity(name,realm)))
    else
        local own=ownRealm()
        if own then add((L.Identity(name,own)))end
    end
    return keys
end
-- Addon whispers go to the name in the form of the client: a realm suffix of a two-part name is dropped.
local function whisperTarget(name)
    local L=Z.Logic
    local key,target=L.Identity(name)
    if key and type(target)=='string'then return target end
    return name
end
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
    local seen,held=senderKey(name),senderKey(p.name)
    if not seen or not held then return false end -- form not classifiable: the entry stays until it expires
    N.pending[guid]=nil
    if seen~=held then return false end
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
    local mineKey,keys=senderKey(sender),guidKeys(name,realm)
    local comparable=false
    if mineKey then
        local forever=mineKey:find(' ',1,true)~=nil
        for key in pairs(keys)do if(key:find(' ',1,true)~=nil)==forever then comparable=true end end
    end
    if not comparable then
        -- name forms of sender and client cannot be compared (no key, or Forever name against Name-Realm only): neither confirmed nor discarded
        addPending(msg.guid,{name=sender,kind=msg.kind,proto=msg.proto,caps=msg.caps,channel=channel,at=A.Clock()})
        return true
    end
    if not keys[mineKey]then return false end
    if not accept(msg.guid,sender,msg.proto,msg.caps,channel)then return false end
    if(msg.kind=='H'or msg.kind=='P')and msg.proto==N.PROTO and discovery()then
        local now=A.Clock()
        if not within(replyAt[msg.guid],now,N.RATE.reply)then
            replyAt[msg.guid]=now
            send('A','WHISPER',whisperTarget(sender))
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
function N.TargetName()
    local key,target=A.UnitIdentity('target')
    if key and type(target)=='string'then
        -- Retail-style clients return the own realm as second value of UnitFullName; that is no surname.
        local family,own=target:match(' ([^ ]+)$'),ownRealm()
        if not(family and own and family:lower()==own:lower())then return cleanSender(target)end
    end
    local full=A.Call(GetUnitName,'target',true)
    if type(full)=='string'and full~=''then return cleanSender(full)end
    local name,realm=A.Call(UnitFullName,'target')
    if type(name)=='string'and name~=''then
        if type(realm)=='string'and realm~=''then name=name..'-'..realm end
        return cleanSender(name)
    end
end
-- ===== Battle.net ping (D-09 d, locked) =====
-- Same send path as BattleNetTransport: securecall in pcall, native result captured inside; nothing reported = success there.
local function bnetSend(kind,gameAccountID)
    local payload=N.Payload(kind)
    if not payload then return false end
    local stat='B'..kind
    local fn=C_BattleNet and C_BattleNet.SendGameData
    local ok=false
    if type(fn)=='function'and type(securecall)=='function'then
        local nativeOK,result
        local called=pcall(securecall,function()nativeOK,result=pcall(fn,gameAccountID,N.PREFIX,payload)end)
        if called and nativeOK and A.Safe(result)then
            local e=Enum and Enum.SendAddonMessageResult or{}
            ok=result==nil or result==true or result==e.Success
        end
    end
    local bucket=ok and N.stats.sent or N.stats.failed
    bucket[stat]=bucket[stat]+1
    return ok
end
local function readableAccount(info)
    return A.PublicTable(info)and A.Safe(info.playerGuid,info.characterName,info.factionName)and info or nil
end
-- Online game account of the same project for a target GUID, or nil.
local function bnetAccountFor(guid)
    local fn=C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID
    if type(fn)~='function'then return nil end
    local ok,info=pcall(fn,guid)
    if not ok or not A.PublicTable(info)then return nil end
    if not A.Safe(info.gameAccountID,info.isOnline,info.clientProgram,info.wowProjectID)then return nil end
    local id=info.gameAccountID
    if type(id)~='number'or id~=id or id<1 or id>2147483647 or id%1~=0 or info.isOnline~=true then return nil end
    if info.clientProgram~=nil and info.clientProgram~='WoW'then return nil end
    if info.wowProjectID~=nil and WOW_PROJECT_ID~=nil and info.wowProjectID~=WOW_PROJECT_ID then return nil end
    return id
end
local function bnetPing(guid)
    local XF=Z.CrossFaction
    if not bnetEnabled()then return false end
    local mine=ownGuid()
    if not mine or guid==mine then return false end
    local now=A.Clock()
    if within(bnetLast,now,N.RATE.bnetGap)or within(bnetPingAt[guid],now,N.RATE.bnetPing)then return false end
    local refresh=R.NeedsRefresh(guid)
    if XF.GetPlayerStatus(guid)~=nil and not refresh then return false end
    local id=bnetAccountFor(guid)
    if not id then return false end
    bnetLast,bnetPingAt[guid]=now,now
    local ok=bnetSend('P',id)
    if ok and refresh then noteAwaiting(guid,now)end
    return ok
end

function N.OnTarget()
    if A.Call(UnitIsPlayer,'target')~=true then return end
    local friend=A.Call(UnitIsFriend,'player','target')
    if friend==false then
        if not bnetEnabled()then return end
        local guid=readableGuid(A.Call(UnitGUID,'target'))
        if guid then bnetPing(guid)end
        return
    end
    if not discovery()or friend~=true then return end
    local guid=readableGuid(A.Call(UnitGUID,'target'))
    if not guid then return end
    local now=A.Clock()
    if within(lastPing,now,N.RATE.pingGap)or within(pingAt[guid],now,N.RATE.ping)then return end
    local name=N.TargetName()
    if name then ping(guid,name)end
end
-- BN_CHAT_MSG_ADDON with our prefix: sender is the game account ID. The GUID counts only if the client reports it for that account.
function N.OnBNet(prefix,payload,sender)
    if not A.Safe(prefix,payload,sender)then return false end
    if type(prefix)~='string'or prefix~=N.PREFIX or type(payload)~='string'or type(sender)~='number'then return false end
    if sender~=sender or sender<1 or sender>2147483647 or sender%1~=0 then return false end
    if not bnetEnabled()then return false end
    local msg=N.Parse(payload)
    if not msg or(msg.kind~='P'and msg.kind~='A')then return false end
    local mine=ownGuid()
    if mine and msg.guid==mine then return false end
    local fn=C_BattleNet and C_BattleNet.GetGameAccountInfoByID
    if type(fn)~='function'then return false end
    local ok,info=pcall(fn,sender)
    info=ok and readableAccount(info)
    if not info or info.playerGuid~=msg.guid then return false end
    local name=type(info.characterName)=='string'and#info.characterName<=64 and info.characterName or''
    local f=info.factionName
    if f~='Horde'and f~='Alliance'then f=nil end
    local XF=Z.CrossFaction
    if type(XF)~='table'then return false end
    N.awaiting[msg.guid]=nil
    if msg.proto~=N.PROTO then
        XF.MarkIncompatible(msg.guid,{name=name,proto=msg.proto,source='bnet',faction=f})
        return true
    end
    if not XF.Confirm(msg.guid,{name=name,proto=msg.proto,caps=msg.caps,xfChat=msg.caps%2==1,source='bnet',faction=f})then return false end
    if msg.kind=='P'then
        local now=A.Clock()
        if not within(bnetReplyAt[msg.guid],now,N.RATE.bnetReply)then
            bnetReplyAt[msg.guid]=now
            bnetSend('A',sender)
        end
    end
    return true
end
-- CHAT_MSG_WHISPER / CHAT_MSG_WHISPER_INFORM: arg2 is the conversation partner, arg12 his GUID.
function N.OnWhisper(event,...)
    if event~='CHAT_MSG_WHISPER'and event~='CHAT_MSG_WHISPER_INFORM'then return end
    if not discovery()then return end
    local _,sender,_,_,_,_,_,_,_,_,_,guid=...
    if not A.Safe(sender,guid)then return end
    sender,guid=cleanSender(sender),readableGuid(guid)
    if sender and guid then ping(guid,whisperTarget(sender))end
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
local function installHooks()
    if type(hooksecurefunc)~='function'then return end
    if not hooked.SendChatMessage and type(SendChatMessage)=='function'then
        hooked.SendChatMessage=pcall(hooksecurefunc,'SendChatMessage',hookSend)
    end
    if not hooked.CSendChatMessage and type(C_ChatInfo)=='table'and type(C_ChatInfo.SendChatMessage)=='function'then
        hooked.CSendChatMessage=pcall(hooksecurefunc,C_ChatInfo,'SendChatMessage',hookSend)
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
    for guid,at in pairs(bnetPingAt)do if not within(at,now,N.RATE.bnetPing)then bnetPingAt[guid]=nil end end
    for guid,at in pairs(bnetReplyAt)do if not within(at,now,N.RATE.bnetReply)then bnetReplyAt[guid]=nil end end
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
