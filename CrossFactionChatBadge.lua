-- Cross-faction chat badge: ZENIAL icon before the name of confirmed Zenial players in the Blizzard chat.
-- The icon is added through ChatFrameUtil.AddSenderNameFilter: Blizzard calls the callback securely while it builds the
-- decorated sender name (and skips it for secret names). No field of a Blizzard chat frame is replaced, so no chat code is tainted.
-- Without AddSenderNameFilter (older client) there are no icons. The message event filter only resolves pending identities
-- (never hides, never changes a line); every error falls back to the unchanged name/event.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local B={
    ICON_PATH='Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga',
    ICON='|TInterface\\AddOns\\ZenialCommunity\\Media\\Icon.tga:0|t ',
    EVENTS={'CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_GUILD','CHAT_MSG_OFFICER','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER',
        'CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER','CHAT_MSG_RAID_WARNING','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER',
        'CHAT_MSG_WHISPER','CHAT_MSG_CHANNEL'},
}
Z.CrossFactionChatBadge=B
local installed={}
local nameFilterAdded=false
local eventSet={}
for _,event in ipairs(B.EVENTS)do eventSet[event]=true end

local function eligible(guid)
    local XF=Z.CrossFaction
    if type(XF)~='table'or XF.Settings().chatIcons~=true then return false end
    local st=XF.GetPlayerStatus(guid)
    return type(st)=='table'and st.status=='CONFIRMED'
end
local function run(...)
    -- args: arg1..argN (without frame and event)
    local flag,guid=(select(6,...)),(select(12,...))
    if not A.Safe(flag,guid)or type(flag)~='string'or type(guid)~='string'then return end
    local N=Z.CrossFactionPresence
    if type(N)=='table'and type(N.HasPending)=='function'and N.HasPending()then
        local sender=(select(2,...))
        if A.Safe(sender)and type(sender)=='string'then N.Resolve(guid,sender)end
    end
end
function B.Filter(_,_,...)
    pcall(run,...)
    return false
end

-- Sender name filter: callback(event,decoratedName,text,senderName,language,channel,player2,flags,zoneID,channelIndex,
-- channelBase,languageID,lineID,senderGUID,...) -> new decorated name (the unchanged name when nothing applies).
function B.NameFilter(event,name,...)
    if not eventSet[event]then return name end
    local guid=(select(12,...))
    if not A.Safe(name,guid)or type(name)~='string'or type(guid)~='string'then return name end
    local ok,yes=pcall(eligible,guid)
    if not ok or yes~=true then return name end
    if name:find(B.ICON_PATH,1,true)then return name end
    return B.ICON..name
end

-- Idempotent: the message filters and the sender name filter are installed once.
function B.Initialize()
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)=='function'then
        for _,event in ipairs(B.EVENTS)do
            if not installed[event]and pcall(add,event,B.Filter)then installed[event]=true end
        end
    end
    local addName=ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter
    if not nameFilterAdded and type(addName)=='function'and pcall(addName,B.NameFilter)then nameFilterAdded=true end
end
