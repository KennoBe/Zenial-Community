-- Cross-faction chat badge: ZENIAL icon before the name of confirmed Zenial players in the Blizzard chat.
-- The filter only remembers lineIDs, a wrapper around AddMessage inserts the icon before the player link.
-- The chat event never disappears: the filter never returns true, every error falls back to the unchanged event/text.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local B={
    ICON_PATH='Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga',
    ICON='|TInterface\\AddOns\\ZenialCommunity\\Media\\Icon.tga:0|t ',
    EVENTS={'CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_GUILD','CHAT_MSG_OFFICER','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER',
        'CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER','CHAT_MSG_RAID_WARNING','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER',
        'CHAT_MSG_WHISPER','CHAT_MSG_CHANNEL'},
}
Z.CrossFactionChatBadge=B
local RING=64
local ring,ringPos,known={},0,{}
local installed={}
local wrapped={}

local function eligible(guid)
    local XF=Z.CrossFaction
    if type(XF)~='table'or XF.Settings().chatIcons~=true then return false end
    local st=XF.GetPlayerStatus(guid)
    return type(st)=='table'and st.status=='CONFIRMED'
end
local function remember(lineID)
    if known[lineID]then return end
    ringPos=ringPos%RING+1
    local old=ring[ringPos]
    if old~=nil then known[old]=nil end
    ring[ringPos]=lineID;known[lineID]=true
end
local function run(...)
    -- args: arg1..argN (without frame and event)
    local flag,lineID,guid=(select(6,...)),(select(11,...)),(select(12,...))
    if not A.Safe(flag,guid)or type(flag)~='string'or type(guid)~='string'then return false end
    local N=Z.CrossFactionPresence
    if type(N)=='table'and type(N.HasPending)=='function'and N.HasPending()then
        local sender=(select(2,...))
        if A.Safe(sender)and type(sender)=='string'then N.Resolve(guid,sender)end
    end
    if A.Safe(lineID)and type(lineID)=='number'and lineID~=0 and eligible(guid)then remember(lineID)end
    return false
end
function B.Filter(_,_,...)
    pcall(run,...)
    return false
end

function B.Rewrite(text)
    if not A.Safe(text)or type(text)~='string'then return text end
    local s,_,lineID=text:find('|Hplayer:[^:|]+:(%d+)')
    if not s then return text end
    if not known[tonumber(lineID)]then return text end
    if text:find(B.ICON_PATH,1,true)then return text end
    return text:sub(1,s-1)..B.ICON..text:sub(s)
end
local function wrap(frame)
    local original=frame.AddMessage
    frame.AddMessage=function(self,text,...)
        -- fast path: no readable string with a player link -> straight to the original, no closure, no settings
        if not A.Safe(text)or type(text)~='string'or not text:find('|Hplayer:',1,true)then return original(self,text,...)end
        local newText=text
        local ok,res=pcall(function()
            local XF=Z.CrossFaction
            if type(XF)~='table'or XF.Settings().chatIcons~=true then return text end
            return B.Rewrite(text)
        end)
        if ok and type(res)=='string'then newText=res end
        return original(self,newText,...)
    end
end
local function installWrappers()
    local count=_G.NUM_CHAT_WINDOWS
    if type(count)~='number'then return end
    for i=1,count do
        if not wrapped[i]then
            local frame=_G['ChatFrame'..i]
            local combatLog=type(_G.COMBATLOG)=='table'and frame==_G.COMBATLOG or(type(_G.COMBATLOG)~='table'and i==2)
            if type(frame)=='table'and not combatLog and frame.isTemporary~=true and type(frame.AddMessage)=='function'then
                wrapped[i]=true
                wrap(frame)
            end
        end
    end
end
-- Idempotent: filters and wrappers are installed once.
function B.Initialize()
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)=='function'then
        for _,event in ipairs(B.EVENTS)do
            if not installed[event]and pcall(add,event,B.Filter)then installed[event]=true end
        end
    end
    installWrappers()
end
