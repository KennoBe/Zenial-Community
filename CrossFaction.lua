-- Cross-faction runtime: account-wide settings and sending of user-typed text as ZXF1 SAY/YELL lines (D-13, D-14, 6.4).
-- Sends only from an explicit user action (the caller); Tick never sends. Receiving/filters/slash commands live in later steps.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P=Z.CrossFactionProtocol
local XF={API_VERSION=1,attempts={},sending=nil};Z.CrossFaction=XF
local DEFAULTS={enabled=true,chatIcons=true,targetIcon=true,discovery=true,bnetDiscovery=false}
local NAMES={'enabled','chatIcons','targetIcon','discovery','bnetDiscovery'}
local MAX_ATTEMPTS=8
local messageCounter,attemptCounter,sendTimes
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
    return true
end
function XF.IsEnabled()return XF.Settings().enabled==true end
function XF.Initialize()XF.Settings()end
-- Sliding window over the send times of single lines; only lines that were really handed to the client count.
local function prune(now)
    sendTimes=sendTimes or{}
    local keep,window={},P.LIMITS.rateWindow
    for _,t in ipairs(sendTimes)do if now-t<window then keep[#keep+1]=t end end
    sendTimes=keep
end
-- Hook point for later expiry checks. Must never send chat.
function XF.Tick()
    prune(A.Clock())
end
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
    for _,line in ipairs(lines)do
        local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        XF.sending=attempt
        local ok=pcall(send,line,channel)
        XF.sending=nil
        if not ok then attempt.state='failed';return false,'api_error',attemptId end
        if attempt.blocked then attempt.state='failed';return false,'blocked',attemptId end
        attempt.lines[#attempt.lines+1]=line
        sendTimes[#sendTimes+1]=A.Clock()
    end
    return true,nil,attemptId
end
-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN: only relevant while one of our own send calls runs.
function XF.OnBlocked(event,addonName,functionName)
    local attempt=XF.sending
    if not attempt or not A.Safe(event,addonName,functionName)then return end
    attempt.blocked=true
end
