-- Correlate only our own native whisper attempts with localized offline replies.
-- Never replace the chat handler or suppress unrelated system messages.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local G={WINDOW=10,MAX_TARGETS=256};Z.WhisperGuard=G
local function identity(target)return A.Safe(target)and L.Identity(target)or nil end
local function expire()
    local now=A.Clock()
    for target,row in pairs(G.pending)do
        for i=#row.attempts,1,-1 do if now>row.attempts[i].untilAt then table.remove(row.attempts,i)end end
        if #row.attempts==0 then G.pending[target]=nil end
    end
    for target,untilAt in pairs(G.manual)do if now>untilAt then G.manual[target]=nil end end
    for token,row in pairs(G.decisions)do if now>row.untilAt then G.decisions[token]=nil end end
end
function G.Manual(target)
    local id=identity(target);if not id or not G.pending then return end
    expire();G.pending[id]=nil
    if G.manual[id]or L.Count(G.manual)<G.MAX_TARGETS then G.manual[id]=A.Clock()+G.WINDOW end
end
function G.CanSend(target)
    if not G.available then return false,"unavailable"end
    expire();local id=identity(target)
    if not id then return false,"invalid_target"end
    if G.manual[id]then return false,"manual_whisper"end
    return true
end
function G.Begin(target,reason)
    local ok=G.CanSend(target);if not ok then return false end
    local id=identity(target);local row=G.pending[id]
    if not row then if L.Count(G.pending)>=G.MAX_TARGETS then return false end;row={attempts={}};G.pending[id]=row end
    if #row.attempts>=64 then return false end
    row.attempts[#row.attempts+1]={untilAt=A.Clock()+G.WINDOW,reason=reason,verifiedAfterSend=false}
    return true
end
function G.Verified(target)
    local row=G.pending and G.pending[identity(target)]
    if row then for _,attempt in ipairs(row.attempts)do attempt.verifiedAfterSend=true end end
end
function G.Undo(target)
    local row=G.pending and G.pending[identity(target)]
    if row then table.remove(row.attempts);if #row.attempts==0 then G.pending[identity(target)]=nil end end
end
function G.Filter(_,event,message,...)
    if event~="CHAT_MSG_SYSTEM"or not G.available or not A.Safe(message)or type(message)~="string"then return false end
    expire()
    local target=message:match(G.pattern);local id=target and identity(target)
    if not id or G.manual[id]then return false end
    -- CHAT_MSG_SYSTEM uses the normal chat payload; lineID is argument 11.
    -- A filter is invoked once per chat frame, so remember the event decision.
    local lineID=select(10,...)
    if not A.Safe(lineID)then return false end
    local token=(type(lineID)=="number"and lineID>0)and("line:"..lineID)or(tostring(A.Clock())..":"..message)
    if G.decisions[token]then return true end
    local row=G.pending[id];if not row or #row.attempts<1 then return false end
    local attempt=table.remove(row.attempts,1);if #row.attempts==0 then G.pending[id]=nil end
    if L.Count(G.decisions)<512 then G.decisions[token]={untilAt=A.Clock()+G.WINDOW}end
    if not attempt.verifiedAfterSend and Z.BattleNetTransport then Z.BattleNetTransport.FailTarget(target,"target_offline")end
    if Z.Diagnostics then Z.Diagnostics.Record("whisper:offline",target,attempt.reason or"direct")end
    return true
end
function G.Initialize()
    G.pending,G.manual,G.decisions={},{},{};G.available=false
    local format=ERR_CHAT_PLAYER_NOT_FOUND_S
    if not A.Safe(format)or type(format)~="string"then return end
    local first,last=format:find("%%s")
    if not first then first,last=format:find("%%1%$s")end
    if not first then return end
    local function escape(value)return(value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"))end
    G.pattern="^"..escape(format:sub(1,first-1)).."(.+)"..escape(format:sub(last+1)).."$"
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)~="function"then return end
    if not G.registered then local ok=pcall(add,"CHAT_MSG_SYSTEM",G.Filter);if not ok then return end;G.registered=true end
    G.available=true
    if not G.hooked and type(hooksecurefunc)=="function"then
        local function manual(_,channel,_,target)if A.Safe(channel)and channel=="WHISPER"then G.Manual(target)end end
        if C_ChatInfo and type(C_ChatInfo.SendChatMessage)=="function"then pcall(hooksecurefunc,C_ChatInfo,"SendChatMessage",manual)end
        if type(SendChatMessage)=="function"then pcall(hooksecurefunc,"SendChatMessage",manual)end
        G.hooked=true
    end
end
