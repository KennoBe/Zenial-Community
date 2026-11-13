-- Cross-faction runtime: account-wide settings, sending of user-typed text as ZXF1 SAY/YELL lines (D-13, D-14, 6.4)
-- and receiving/displaying them (6.3). Sends only from an explicit user action (the caller); Tick never sends.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P=Z.CrossFactionProtocol
local XF={API_VERSION=1,ICON_PATH='Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga',attempts={},sending=nil};Z.CrossFaction=XF
local DEFAULTS={enabled=true,chatIcons=true,targetIcon=true,discovery=true,bnetDiscovery=false}
local NAMES={'enabled','chatIcons','targetIcon','discovery','bnetDiscovery'}
local MAX_ATTEMPTS,MAX_RESULTS=8,64
local messageCounter,attemptCounter,sendTimes
local asm,pending,results,order,listeners,messageSeq=nil,{},{},{},{},0
local fire,reset
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
function XF.Initialize()
    XF.Settings()
    if XF.filtersInstalled then return end
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)~='function'then return end
    local a=pcall(add,'CHAT_MSG_SAY',XF.filterSay)
    local b=pcall(add,'CHAT_MSG_YELL',XF.filterYell)
    XF.filtersInstalled=a and b
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
function XF.Send(text,channel)
    if channel~='SAY'and channel~='YELL'then return false,'api_error'end
    if not XF.IsEnabled()then return false,'disabled'end
    local clean,why,over=P.Prepare(text)
    if not clean then return false,why,nil,over end
    if type(InChatMessagingLockdown)=='function'and A.Call(InChatMessagingLockdown)then return false,'lockdown'end
    local messageId=nextMessageId()
    local lines=P.BuildMessage(clean,messageId)
    if not lines then return false,'too_long'end
    local now=A.Clock();prune(now)
    if#sendTimes+#lines>P.LIMITS.rateLines then return false,'throttled'end
    local attemptId,attempt=newAttempt(channel,messageId,clean)
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
local function compute(event,text,sender,guid,lineID)
    local result={protocol=false,hide=false}
    if not XF.IsEnabled()then return result end
    local frame=P.ParseLine(text)
    if not frame then return result end
    if frame.version~=P.VERSION then result.incompatible=true;return result end
    result.protocol=true;result.hide=true
    local mine=myGuid()
    if mine and guid==mine then confirmEcho(text)end
    if frame.type==1 then return result end
    asm=asm or P.NewAssembler()
    local channel=event=='CHAT_MSG_YELL'and'YELL'or'SAY'
    local status,out=asm:Accept(guid,frame,A.Clock())
    local key=guid..':'..frame.messageId
    local p=pending[key]
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
-- One shared step per lineID, whether the event or a chat filter comes first.
local function process(event,text,sender,lineID,guid)
    if not A.Safe(text,lineID,guid)or type(text)~='string'or type(lineID)~='number'or lineID<=0
        or type(guid)~='string'or guid:sub(1,7)~='Player-'then return nil end
    local r=results[lineID]
    if r then return r end
    r=compute(event,text,sender,guid,lineID)
    results[lineID]=r;order[#order+1]=lineID
    if#order>MAX_RESULTS then results[table.remove(order,1)]=nil end
    return r
end
function XF.OnChat(event,...)
    local text,sender,_,_,_,_,_,_,_,_,lineID,guid=...
    process(event,text,sender,lineID,guid)
end
local function filterBody(chatFrame,event,...)
    if not XF.IsEnabled()then return false end
    local text,sender,_,_,_,_,_,_,_,_,lineID,guid=...
    local r=process(event,text,sender,lineID,guid)
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
