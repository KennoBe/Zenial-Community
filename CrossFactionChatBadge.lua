-- Cross-faction chat badge: ZENIAL icon before the name of confirmed Zenial players in the Blizzard chat.
-- Strategy 'addmessage': the filter only remembers lineIDs, a wrapper around AddMessage inserts the icon before the player link.
-- Strategy 'flag': the filter replaces arg6 with ZENIAL/ZENIALAFK/ZENIALDND (CHAT_FLAG_ZENIAL* hold the icon). 'off': nothing changes.
-- The chat event never disappears: the filter never returns true, every error falls back to the unchanged event/text.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local B={
    ICON_PATH='Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga',
    ICON='|TInterface\\AddOns\\ZenialCommunity\\Media\\Icon.tga:0|t ',
    strategy='addmessage',
    EVENTS={'CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_GUILD','CHAT_MSG_OFFICER','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER',
        'CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER','CHAT_MSG_RAID_WARNING','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER',
        'CHAT_MSG_WHISPER','CHAT_MSG_CHANNEL'},
}
Z.CrossFactionChatBadge=B
local FLAGS={[''] ='ZENIAL',AFK='ZENIALAFK',DND='ZENIALDND'}
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
local function packed(...)return select('#',...),{...}end

local function run(...)
    -- args: arg1..argN (without frame and event)
    local n,t=packed(...)
    local flag,lineID,guid=t[6],t[11],t[12]
    if not A.Safe(flag,guid)or type(flag)~='string'or type(guid)~='string'then return false end
    local N=Z.CrossFactionPresence
    if type(N)=='table'and type(N.HasPending)=='function'and N.HasPending()then
        local sender=t[2]
        if A.Safe(sender)and type(sender)=='string'then N.Resolve(guid,sender)end
    end
    if B.strategy=='flag'then
        local replaced=FLAGS[flag]
        if replaced and eligible(guid)then
            t[6]=replaced
            return false,unpack(t,1,math.max(n,6))
        end
    elseif B.strategy=='addmessage'then
        if A.Safe(lineID)and type(lineID)=='number'and lineID~=0 and eligible(guid)then remember(lineID)end
    end
    return false
end
local function result(ok,first,...)
    if ok and first==false then return false,...end
    return false
end
function B.Filter(_,_,...)
    return result(pcall(run,...))
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
        local newText=text
        if B.strategy=='addmessage'then
            local ok,res=pcall(function()
                local XF=Z.CrossFaction
                if type(XF)~='table'or XF.Settings().chatIcons~=true then return text end
                return B.Rewrite(text)
            end)
            if ok and type(res)=='string'then newText=res end
        end
        return original(self,newText,...)
    end
end
local function installWrappers()
    local count=_G.NUM_CHAT_WINDOWS
    if type(count)~='number'then return end
    for i=1,count do
        if not wrapped[i]then
            local frame=_G['ChatFrame'..i]
            if type(frame)=='table'and type(frame.AddMessage)=='function'then
                wrapped[i]=true
                wrap(frame)
            end
        end
    end
end
local function setGlobals()
    _G.CHAT_FLAG_ZENIAL=B.ICON
    if type(_G.CHAT_FLAG_AFK)=='string'then _G.CHAT_FLAG_ZENIALAFK=B.ICON.._G.CHAT_FLAG_AFK end
    if type(_G.CHAT_FLAG_DND)=='string'then _G.CHAT_FLAG_ZENIALDND=B.ICON.._G.CHAT_FLAG_DND end
end
local function apply()
    if B.strategy=='flag'then setGlobals()
    elseif B.strategy=='addmessage'then installWrappers()end
end
function B.SetStrategy(name)
    if name~='addmessage'and name~='flag'and name~='off'then return false end
    B.strategy=name
    if B.initialized then apply()end
    return true
end
-- Idempotent: filters, globals and wrappers are installed once.
function B.Initialize()
    B.initialized=true
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)=='function'then
        for _,event in ipairs(B.EVENTS)do
            if not installed[event]and pcall(add,event,B.Filter)then installed[event]=true end
        end
    end
    apply()
end
