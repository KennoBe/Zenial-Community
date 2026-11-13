-- Cross-faction runtime: account-wide settings, sending of user-typed text as ZXF1 SAY/YELL lines (D-13, D-14, 6.4)
-- and receiving/displaying them (6.3). Sends only from an explicit user action (the caller); Tick never sends.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P=Z.CrossFactionProtocol
local R=Z.CrossFactionRegistry
local XF={API_VERSION=1,ICON_PATH='Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga',attempts={},sending=nil};Z.CrossFaction=XF
local DEFAULTS={enabled=true,chatIcons=true,targetIcon=true,discovery=true,bnetDiscovery=false}
local NAMES={'enabled','chatIcons','targetIcon','discovery','bnetDiscovery'}
local MAX_ATTEMPTS,MAX_RESULTS=8,64
local messageCounter,attemptCounter,sendTimes
local asm,pending,results,order,listeners,messageSeq=nil,{},{},{},{},0
local fire,reset,ensureRegistry,expireRegistry
-- Always read the saved-variable root fresh: Z.Initialize may swap it in offline mode.
function XF.Settings()
    local root=ZenialCommunityDB
    local s
    if type(root)=='table'then
        s=root.crossFaction
        if type(s)~='table'then s={};root.crossFaction=s end
    else
        s={}
    end
    for _,name in ipairs(NAMES)do
        if type(s[name])~='boolean'then s[name]=DEFAULTS[name]end
    end
    return s
end
function XF.SetSetting(name,value)
    if type(value)~='boolean'or type(name)~='string'or DEFAULTS[name]==nil then return false end
    XF.Settings()[name]=value
    if name=='enabled'and not value then reset()end
    return true
end
function XF.IsEnabled()return XF.Settings().enabled==true end
-- Settings plus one chat filter per event (installed once).
local function installFilters()
    if XF.filtersInstalled then return end
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)~='function'then return end
    local a=pcall(add,'CHAT_MSG_SAY',XF.filterSay)
    local b=pcall(add,'CHAT_MSG_YELL',XF.filterYell)
    XF.filtersInstalled=a and b
end
function XF.Initialize()
    XF.Settings()
    ensureRegistry()
    installFilters()
    -- Neighbour modules (idempotent themselves); some may not exist yet.
    for _,name in ipairs({'CrossFactionChatBadge','CrossFactionTargetBadge','CrossFactionPresence'})do
        local module=Z[name]
        if type(module)=='table'and type(module.Initialize)=='function'then pcall(module.Initialize)end
    end
end
-- Sliding window over the send times of single lines; only lines that were really handed to the client count.
local function prune(now)
    sendTimes=sendTimes or{}
    local keep,window={},P.LIMITS.rateWindow
    for _,t in ipairs(sendTimes)do if now-t<window then keep[#keep+1]=t end end
    sendTimes=keep
end
-- Expiry checks hang here. Must never send chat (local notices only).
function XF.Tick()
    local now=A.Clock()
    prune(now)
    if XF.IsEnabled()then XF.Expire(now)else reset()end
    XF.CheckEchoes(now)
    expireRegistry(now)
    local N=Z.CrossFactionPresence
    if type(N)=='table'and type(N.Tick)=='function'then pcall(N.Tick)end
end
-- ===== Listeners (7.1) =====
local function copy(v)
    if type(v)~='table'then return v end
    local t={};for k,x in pairs(v)do t[k]=copy(x)end
    return t
end
function XF.RegisterListener(owner,fn)
    if owner==nil or type(fn)~='function'then return false end
    for _,l in ipairs(listeners)do if l.owner==owner then l.fn=fn;return true end end
    listeners[#listeners+1]={owner=owner,fn=fn};return true
end
function XF.UnregisterListener(owner)
    for i,l in ipairs(listeners)do if l.owner==owner then table.remove(listeners,i);return true end end
    return false
end
function fire(event,payload)
    local list={};for i,l in ipairs(listeners)do list[i]=l.fn end
    for _,fn in ipairs(list)do pcall(fn,event,copy(payload))end
end
-- ===== Registry binding, status and PLAYER events (7.1) =====
local registryStore,registrySelf,lastRegistryExpire
local function currentGuid()
    local g=Z.me and Z.me.guid
    if type(g)~='string'or g==''then g=A.Call(UnitGUID,'player')end
    if type(g)=='string'and g~=''then return g end
end
-- The registry hangs on the table XF.Settings() returns right now (Z.Initialize may swap the saved-variable root).
function ensureRegistry()
    if type(R)~='table'or type(ZenialCommunityDB)~='table'then return false end
    local store=XF.Settings()
    local mine=currentGuid()
    if store~=registryStore then
        registryStore,registrySelf,lastRegistryExpire=store,mine,nil
        R.Attach(store,A.Now(),mine)
    elseif mine and mine~=registrySelf then
        registrySelf=mine;R.SetSelf(mine)
    end
    return true
end
local function statusOf(guid,now)
    local e=R.Get(guid,now)
    return e and e.status or nil
end
function XF.NotifyPlayer(guid)
    if not ensureRegistry()then return end
    fire('PLAYER',{guid=guid,status=statusOf(guid,A.Now())})
end
-- Writes a confirmed signal and fires PLAYER once per status change (or first confirmation of a remembered player this session).
function XF.Confirm(guid,info)
    if not ensureRegistry()then return false end
    local now=A.Now()
    local before=R.Get(guid,now)
    if not R.Confirm(guid,info,now)then return false end
    local after=R.Get(guid,now)
    if(before and before.status)~=(after and after.status)or(after and after.verified and not(before and before.verified))then
        fire('PLAYER',{guid=guid,status=after and after.status or nil})
    end
    return true
end
function XF.MarkIncompatible(guid,info)
    if not ensureRegistry()then return end
    local now=A.Now()
    local before=R.Get(guid,now)
    R.Incompatible(guid,info,now)
    local after=R.Get(guid,now)
    if(before and before.status)~=(after and after.status)then
        fire('PLAYER',{guid=guid,status=after and after.status or nil})
    end
end
-- At most every 60 s (A.Clock base); reports every GUID whose status changed through expiry.
function expireRegistry(clock)
    if lastRegistryExpire and clock>=lastRegistryExpire and clock-lastRegistryExpire<60 then return end
    if not ensureRegistry()then return end
    lastRegistryExpire=clock
    local list=R.Expire(A.Now())
    for _,guid in ipairs(list)do fire('PLAYER',{guid=guid,status=statusOf(guid,A.Now())})end
end
-- Source "community": read-only lookup GUID -> peer key in Z.db.peers, index rebuilt at most every 5 s.
local peerIndex,peerIndexDb,peerIndexAt
local function peerKey(db,guid)
    local clock=A.Clock()
    if not peerIndex or peerIndexDb~=db or clock<peerIndexAt or clock-peerIndexAt>=5 then
        peerIndex,peerIndexDb,peerIndexAt={},db,clock
        for key,peer in pairs(db.peers)do
            local data=type(peer)=='table'and peer.data
            local g=type(data)=='table'and data.guid
            if type(g)=='string'and g~=''then peerIndex[g]=key end
        end
    end
    return peerIndex[guid]
end
local function communityStatus(guid)
    local db=Z.db
    if type(db)~='table'or type(db.peers)~='table'then return nil end
    local key=peerKey(db,guid)
    local peer=key and db.peers[key]
    if type(peer)~='table'or type(peer.data)~='table'or peer.data.guid~=guid then return nil end
    if not Z.Logic.PeerOnline(db,key,A.Now())then return nil end
    local name=peer.name
    if type(name)~='string'or name==''then
        local contact=type(db.contacts)=='table'and db.contacts[key]
        name=type(contact)=='table'and contact.target or nil
    end
    if type(name)~='string'or name==''then name=nil end
    local faction=Z.me and Z.me.faction
    if type(faction)~='string'then faction=nil end
    return{status='CONFIRMED',addon=true,xfChat=nil,source='community',recent=true,verified=true,faction=faction,name=name,
        lastSeen=type(peer.lastContact)=='number'and peer.lastContact or nil}
end
-- nil = UNKNOWN (never "no addon"). Always returns a fresh table.
function XF.GetPlayerStatus(guid)
    local ok,result=pcall(function()
        if not A.Safe(guid)or type(guid)~='string'then return nil end
        ensureRegistry()
        local e=type(R)=='table'and R.Get(guid,A.Now())
        if e then
            return{status=e.status,addon=true,xfChat=e.xfChat,proto=e.proto,lastSeen=e.lastSeen,recent=e.recent,
                verified=e.verified,name=e.name~=''and e.name or nil,faction=e.faction,source=e.source}
        end
        return communityStatus(guid)
    end)
    if ok and type(result)=='table'then return result end
    return nil
end
function XF.IsProtocolLine(text)
    if not A.Safe(text)or type(text)~='string'then return false end
    local ok,frame=pcall(P.ParseLine,text)
    return ok and frame~=nil
end
-- ===== Sending =====
local function nextMessageId()
    if not messageCounter then messageCounter=type(math.random)=='function'and math.random(0,255)or 0 end
    return messageCounter
end
local function newAttempt(channel,messageId,text)
    attemptCounter=(attemptCounter or 0)+1
    local id=attemptCounter
    XF.attempts[id]={state='sent',lines={},echoed=0,at=A.Clock(),channel=channel,messageId=messageId,text=text}
    XF.attempts[id-MAX_ATTEMPTS]=nil
    messageCounter=(nextMessageId()+1)%256
    return id,XF.attempts[id]
end
-- Shared tail of Send/SendHello: rate budget, attempt record, synchronous client calls.
local function transmit(channel,messageId,lines,text)
    local now=A.Clock();prune(now)
    if#sendTimes+#lines>P.LIMITS.rateLines then return false,'throttled'end
    local attemptId,attempt=newAttempt(channel,messageId,text)
    local function failed(code)
        attempt.state='failed';fire('SENDSTATE',{attemptId=attemptId,state='failed'})
        return false,code,attemptId
    end
    for _,line in ipairs(lines)do
        local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        XF.sending=attempt
        local ok=pcall(send,line,channel)
        XF.sending=nil
        if not ok then return failed('api_error')end
        if attempt.blocked then return failed('blocked')end
        attempt.lines[#attempt.lines+1]=line
        sendTimes[#sendTimes+1]=A.Clock()
    end
    fire('SENDSTATE',{attemptId=attemptId,state='sent'})
    return true,nil,attemptId
end
function XF.Send(text,channel)
    if channel~='SAY'and channel~='YELL'then return false,'api_error'end
    if not XF.IsEnabled()then return false,'disabled'end
    local clean,why,over=P.Prepare(text)
    if not clean then return false,why,nil,over end
    if type(InChatMessagingLockdown)=='function'and A.Call(InChatMessagingLockdown)then return false,'lockdown'end
    local messageId=nextMessageId()
    local lines=P.BuildMessage(clean,messageId)
    if not lines then return false,'too_long'end
    return transmit(channel,messageId,lines,clean)
end
-- Addon version (major, minor) from the TOC; 0.0 when unreadable.
local function tocVersion()
    local get=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local v=A.Call(get,'ZenialCommunity','Version')
    if type(v)=='string'then
        local major,minor=v:match('^(%d+)%.(%d+)')
        if major then return tonumber(major),tonumber(minor)end
    end
    return 0,0
end
function XF.Version()return tocVersion()end
-- One hello frame (one line), same pre-checks and limiter as Send. Its own echo is tracked like any attempt line.
function XF.SendHello(channel)
    channel=channel or'SAY'
    if channel~='SAY'and channel~='YELL'then return false,'api_error'end
    if not XF.IsEnabled()then return false,'disabled'end
    if type(InChatMessagingLockdown)=='function'and A.Call(InChatMessagingLockdown)then return false,'lockdown'end
    local messageId=nextMessageId()
    local major,minor=tocVersion()
    return transmit(channel,messageId,P.BuildHello(messageId,major,minor),nil)
end
-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN: only relevant while one of our own send calls runs.
function XF.OnBlocked(event,addonName,functionName)
    local attempt=XF.sending
    if not attempt or not A.Safe(event,addonName,functionName)then return end
    attempt.blocked=true
end
-- ===== Receiving =====
function reset()
    if asm then asm:Reset()end
    pending={}
end
local function notice(text)
    local frame=DEFAULT_CHAT_FRAME
    if type(frame)=='table'and type(frame.AddMessage)=='function'then pcall(frame.AddMessage,frame,text)end
end
local function tr(key,...)
    if type(Z.T)=='function'then return Z.T(key,...)end
    local ok,r=pcall(string.format,key,...);return ok and r or key
end
local function checkedName(sender)
    if A.Safe(sender)and type(sender)=='string'and #sender>0 and #sender<=64 and not sender:find('[|%z\1-\31\127]')then return sender end
end
local function shortName(name)return name and name:match('^([^%-]+)')or nil end
local function myGuid()
    local g=Z.me and Z.me.guid
    if type(g)~='string'or g==''then g=A.Call(UnitGUID,'player')end
    if type(g)=='string'and g~=''then return g end
end
local function format(name,text)
    local who='[?]'
    if name then who='|Hplayer:'..name..'|h['..shortName(name)..']|h'end
    return '|T'..XF.ICON_PATH..':0|t |cffffd100[ZENIAL]|r '..who..': '..P.Display(text)
end
local function color(event)
    local info=ChatTypeInfo and ChatTypeInfo[event=='CHAT_MSG_YELL'and'YELL'or'SAY']
    if A.Safe(info)and type(info)=='table'then
        local r,g,b=info.r,info.g,info.b
        if A.Safe(r,g,b)and type(r)=='number'and type(g)=='number'and type(b)=='number'then return r,g,b end
    end
    return 1,1,1
end
-- An own line seen again counts for the first attempt line it matches that is not yet confirmed.
local function confirmEcho(text)
    for id=attemptCounter or 0,math.max(1,(attemptCounter or 0)-MAX_ATTEMPTS+1),-1 do
        local a=XF.attempts[id]
        if a and a.state=='sent'then
            a.confirmed=a.confirmed or{}
            for i,line in ipairs(a.lines)do
                if not a.confirmed[i]and line==text then
                    a.confirmed[i]=true;a.echoed=a.echoed+1
                    if a.echoed>=#a.lines then a.state='broadcast';fire('SENDSTATE',{attemptId=id,state='broadcast'})end
                    return
                end
            end
        end
    end
end
-- Own languages (GetNumLanguages/GetLanguageByIndex), remembered per session once readable.
local ownLanguages
local function languages()
    if ownLanguages then return ownLanguages end
    local n=A.Call(GetNumLanguages)
    if type(n)~='number'then return nil end
    if n<1 then return nil end -- too early: do not remember an empty set
    local set={}
    for i=1,n do
        local name=A.Call(GetLanguageByIndex,i)
        if type(name)=='string'and name~=''then set[name]=true end
    end
    if next(set)==nil then return nil end
    ownLanguages=set
    return set
end
-- Own language -> own faction; readable foreign language -> opposite faction; otherwise unknown.
local function senderFaction(language)
    if not A.Safe(language)or type(language)~='string'or language==''then return nil end
    local own=Z.me and Z.me.faction
    if own~='Horde'and own~='Alliance'then return nil end
    local set=languages()
    if not set then return nil end
    if set[language]then return own end
    return own=='Horde'and'Alliance'or'Horde'
end
local function register(frame,guid,sender,language,mine)
    if not guid or guid==mine then return end
    local name=checkedName(sender)
    local faction=senderFaction(language)
    if frame.version~=P.VERSION then
        XF.MarkIncompatible(guid,{name=name,proto=frame.version,source='xf',faction=faction})
        return
    end
    local info={name=name,faction=faction,proto=P.VERSION,source='xf'}
    if frame.type==0 then info.xfChat=true
    elseif frame.type==1 then
        local caps=frame.payload:byte(1)or 0
        info.caps=caps;info.xfChat=caps%2==1
    end
    XF.Confirm(guid,info)
end
local function compute(event,text,sender,guid,lineID,language)
    local result={protocol=false,hide=false}
    if not XF.IsEnabled()then return result end
    local frame=P.ParseLine(text)
    if not frame then return result end
    local mine=myGuid()
    pcall(register,frame,guid,sender,language,mine)
    if frame.version~=P.VERSION then result.incompatible=true;return result end
    result.protocol=true
    if mine and guid==mine then confirmEcho(text)end
    -- hidden only when something can be shown for it: greetings and message fragments; reserved types stay visible
    if frame.type==1 then result.hide=true;return result end
    if frame.type~=0 then return result end
    asm=asm or P.NewAssembler()
    local channel=event=='CHAT_MSG_YELL'and'YELL'or'SAY'
    local status,out=asm:Accept(guid,frame,A.Clock())
    if status=='rejected'and out~='mismatch'then return result end
    result.hide=true
    local key=guid..':'..frame.messageId
    local p=pending[key]
    if status=='partial'and out=='restart'then p=nil;pending[key]=nil end
    local name=checkedName(sender)
    if status=='partial'then
        if not p then p={guid=guid,name=name,channel=channel,lineIDs={}};pending[key]=p end
        p.lineIDs[#p.lineIDs+1]=lineID
    elseif status=='complete'then
        pending[key]=nil
        local ids=p and p.lineIDs or{}
        ids[#ids+1]=lineID
        result.display=format(name,out)
        messageSeq=messageSeq+1
        fire('MESSAGE',{id=messageSeq,guid=guid,sender=name,channel=channel,text=out,at=A.Now(),lineIDs=ids,outgoing=mine~=nil and guid==mine})
    end
    -- the assembler evicts old messages on its own: drop the companion data with them
    for k in pairs(pending)do if not asm.open[k]then pending[k]=nil end end
    return result
end
-- Presence messages that were held back until the client shows the same GUID with the same name (XF3-T06).
local function resolvePending(sender,guid)
    local N=Z.CrossFactionPresence
    if type(N)~='table'or type(N.HasPending)~='function'or not N.HasPending()then return end
    if A.Safe(sender,guid)and type(sender)=='string'and type(guid)=='string'and guid:sub(1,7)=='Player-'then pcall(N.Resolve,guid,sender)end
end
-- One shared step per lineID, whether the event or a chat filter comes first.
local function process(event,text,sender,lineID,guid,language,fromEvent)
    resolvePending(sender,guid)
    if not A.Safe(text,lineID,guid)or type(text)~='string'or type(lineID)~='number'or lineID<=0
        or type(guid)~='string'or guid:sub(1,7)~='Player-'then return nil end
    local r=results[lineID]
    if r then return r end
    r=compute(event,text,sender,guid,lineID,language)
    -- a negative result from a chat filter may stem from text another filter changed: only the event's text is final
    if not(r.protocol or r.incompatible or fromEvent)then return r end
    results[lineID]=r;order[#order+1]=lineID
    if#order>MAX_RESULTS then results[table.remove(order,1)]=nil end
    return r
end
function XF.OnChat(event,...)
    local text,sender,language,_,_,_,_,_,_,_,lineID,guid=...
    process(event,text,sender,lineID,guid,language,true)
end
local function filterBody(chatFrame,event,...)
    if not XF.IsEnabled()then return false end
    local text,sender,language,_,_,_,_,_,_,_,lineID,guid=...
    local r=process(event,text,sender,lineID,guid,language)
    if not r or not r.hide then return false end
    if r.display and type(chatFrame)=='table'then
        r.shown=r.shown or{}
        if not r.shown[chatFrame]then
            r.shown[chatFrame]=true
            local cr,cg,cb=color(event)
            if type(chatFrame.AddMessage)=='function'then chatFrame:AddMessage(r.display,cr,cg,cb)end
        end
    end
    return true
end
local function makeFilter()
    return function(chatFrame,event,...)
        local ok,result=pcall(filterBody,chatFrame,event,...)
        return ok and result==true
    end
end
XF.filterSay,XF.filterYell=makeFilter(),makeFilter()
-- Incomplete messages (6.3): one local line per expired message, plus the INCOMPLETE listener event.
function XF.Expire(now)
    if not asm then return end
    for _,e in ipairs(asm:Expire(now))do
        local key=e.senderKey..':'..e.messageId
        local p=pending[key]
        if p then
            pending[key]=nil
            local ids={};for i,v in ipairs(p.lineIDs)do ids[i]=v end
            notice(tr('ZENIAL: message from %s received incompletely.',shortName(p.name)or'?'))
            fire('INCOMPLETE',{guid=p.guid,sender=p.name,channel=p.channel,at=A.Now(),lineIDs=ids})
        end
    end
end
-- Own lines without a full echo: sent -> unconfirmed after LIMITS.echoTimeout, one local hint each.
function XF.CheckEchoes(now)
    for id=math.max(1,(attemptCounter or 0)-MAX_ATTEMPTS+1),attemptCounter or 0 do
        local a=XF.attempts[id]
        if a and a.state=='sent'and now-a.at>=P.LIMITS.echoTimeout then
            a.state='unconfirmed'
            notice(tr('ZENIAL: the message was sent, but its own echo was not seen. Others may not have received it.'))
            fire('SENDSTATE',{attemptId=id,state='unconfirmed'})
        end
    end
end
-- ===== Slash commands (XF2-T06) and hello (XF3-T05) =====
local CANDIDATES={SAY={'/z','/zsay'},YELL={'/zy','/zyell'}}
local GLOBAL_PREFIX={SAY='SLASH_ZENIALXFSAY',YELL='SLASH_ZENIALXFYELL'}
local FALLBACK={SAY='/zenial say',YELL='/zenial yell'}
local aliases={SAY={},YELL={}}
local commandsRegistered
-- Set of lower-case commands that another addon or the client already owns (one pass over _G).
local function takenCommands()
    local taken={}
    pcall(function()
        for key,value in pairs(_G)do
            if type(key)=='string'and type(value)=='string'and A.Safe(value)and key:find('^SLASH_')and key:sub(1,14)~='SLASH_ZENIALXF'then
                taken[value:lower()]=true
            end
        end
    end)
    return taken
end
function XF.RegisterCommands()
    if commandsRegistered then return end
    commandsRegistered=true
    local taken=takenCommands()
    for _,channel in ipairs({'SAY','YELL'})do
        local free,blocked={},{}
        for _,cmd in ipairs(CANDIDATES[channel])do
            if taken[cmd]then blocked[#blocked+1]=cmd else free[#free+1]=cmd end
        end
        aliases[channel]=free
        for i,cmd in ipairs(free)do _G[GLOBAL_PREFIX[channel]..i]=cmd end
        if#free>0 then
            SlashCmdList['ZENIALXF'..channel]=function(text)XF.Command(text,channel)end
        end
        for _,cmd in ipairs(blocked)do
            notice(tr('ZENIAL: %s is already used by another addon. Use %s instead.',cmd,free[1]or(FALLBACK[channel]..' <text>')))
        end
    end
end
local function commandName(channel)return aliases[channel][1]or FALLBACK[channel]end
local ERRORS={
    disabled='ZENIAL: Cross-faction chat is turned off. Turn it on in the ZENIAL Community settings (option "Enable cross-faction chat").',
    invalid_chars='ZENIAL: The text contains characters that cannot be displayed. Nothing was sent.',
    throttled='ZENIAL: Too many messages in a short time. Please wait a moment.',
    lockdown='ZENIAL: Chat is currently locked. Nothing was sent.',
    blocked='ZENIAL: The game client blocked sending. Nothing was sent.',
    api_error='ZENIAL: Sending failed.',
}
local function report(code,overBy,channel,text)
    if code=='empty'then
        notice(tr('ZENIAL: Usage: %s <text>',commandName(channel)))
    elseif code=='too_long'then
        notice(tr('ZENIAL: The message is %d characters too long (at most %d bytes). Nothing was sent.',overBy or 0,P.LIMITS.maxTextBytes))
        local open=ChatFrameUtil and ChatFrameUtil.OpenChat
        if type(open)~='function'then open=ChatFrame_OpenChat end
        if type(open)=='function'and type(text)=='string'then pcall(open,commandName(channel)..' '..text)end
    else
        notice(tr(ERRORS[code]or ERRORS.api_error))
    end
end
-- Entry point of /z, /zy, /zsay, /zyell and /zenial say|yell. Sends only from this explicit user action.
function XF.Command(text,channel)
    if channel~='SAY'and channel~='YELL'then return end
    if type(text)~='string'or not text:find('%S')then return report('empty',nil,channel)end
    local ok,code,_,overBy=XF.Send(text,channel)
    if not ok then report(code,overBy,channel,text)end
end
-- Called by /zenial before it lower-cases the text; true = handled here.
function XF.HandleSubcommand(raw)
    if type(raw)~='string'then return false end
    local word,rest=raw:match('^%s*(%S+)%s*(.*)$')
    if not word then return false end
    word=word:lower()
    if word=='say'then XF.Command(rest,'SAY');return true end
    if word=='yell'then XF.Command(rest,'YELL');return true end
    if word=='hello'then
        local arg=rest:lower():match('^%s*(.-)%s*$')
        if arg==''then arg='say'end
        if arg~='say'and arg~='yell'then return false end
        local channel=arg=='yell'and'YELL'or'SAY'
        local ok,code=XF.SendHello(channel)
        if not ok then report(code,nil,channel,nil)end
        return true
    end
    return false
end
