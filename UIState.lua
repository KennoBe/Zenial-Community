local Z,L=ZenialCommunity,ZenialCommunity.Logic
local S={VERSION=5};Z.UIState=S

local SECTIONS={members=true,craft=true,groups=true,quests=true,trade=true,history=true,profile=true,addons=true,today=true,activities=true,settings=true}
local SUBVIEWS={
    craft={search=true,mine=true,orders=true,materials=true},
    groups={browse=true,mine=true,outgoing=true,follow=true,pvp=true,today=true,scheduled=true},
    quests={shared=true,questgroups=true,browse=true,mine=true,outgoing=true},
    trade={browse=true,mine=true,rules=true,manage=true},
    profile={public=true,characters=true,display=true,network=true},
}
local DEFAULT_SUBVIEW={craft="search",groups="browse",quests="shared",trade="browse",profile="public"}
local function text(v,max)return type(v)=="string"and#v<=max and not v:find("[%z\1-\31\127|]")and v or""end
local function copyDraft(raw)
    local out={};if type(raw)~="table"then return out end
    for key,value in pairs(raw)do
        if type(key)=="string"and#key<=32 then
            if type(value)=="string"then out[key]=text(value,192)
            elseif type(value)=="number"and value==value and math.abs(value)<=4102444800 then out[key]=value
            elseif type(value)=="boolean"then out[key]=value end
        end
    end
    return out
end
local function questCategories(raw)
    local out,count={},0
    for name,collapsed in pairs(type(raw)=="table"and raw or{})do
        if count<256 and type(name)=="string"and text(name,256)==name and collapsed==true then out[name]=true;count=count+1 end
    end
    return out
end
function S.Initialize(root,characterKey,legacy)
    local raw=type(root.ui)=="table"and root.ui or{};local window=type(raw.window)=="table"and raw.window or{}
    -- Account-wide navigation preference; existing installations show the manager by default.
    local ui={version=S.VERSION,showAddonManager=raw.showAddonManager~=false,memberGrouping=raw.memberGrouping~=false,window={width=L.Int(window.width,900,1280)and window.width or 1060,height=L.Int(window.height,610,860)and window.height or 690},characters={}}
    ui.window.width=math.max(900,math.min(1280,math.floor(ui.window.width)));ui.window.height=math.max(610,math.min(860,math.floor(ui.window.height)))
    for key,value in pairs(type(raw.characters)=="table"and raw.characters or{})do
        if type(value)=="table"and L.ValidIdentityKey(key)then
        local section=SECTIONS[value.section]and value.section or"today";local subviews,drafts={},{}
        for area,allowed in pairs(SUBVIEWS)do local selected=type(value.subviews)=="table"and value.subviews[area];subviews[area]=allowed[selected]and selected or DEFAULT_SUBVIEW[area]end
        for kind,draft in pairs(type(value.drafts)=="table"and value.drafts or{})do if kind=="offer"or kind=="profile"then drafts[kind]=copyDraft(draft)end end
        section=section=="groups"and(subviews.groups=="today"and"today"or"activities")or section=="quests"and((subviews.quests=="shared"or subviews.quests=="questgroups")and"today"or"activities")or(section=="profile"or section=="history"or section=="addons")and"settings"or section
        ui.characters[key]={section=section,subviews=subviews,drafts=drafts,memberStatus=value.memberStatus=="ONLINE"and"ONLINE"or"ALL",mapMembers=value.mapMembers~=false,mapGuildOnly=value.mapGuildOnly==true,questCategories=questCategories(value.questCategories),notifications=Z.Notifications.Normalize(value.notifications)}
        end
    end
    ui.characters[characterKey]=ui.characters[characterKey]or{section="today",memberStatus="ALL",subviews={craft="search",groups="browse",quests="shared",trade="browse",profile="public"},drafts={}}
    ui.characters[characterKey].section="today"
    ui.characters[characterKey].questCategories=ui.characters[characterKey].questCategories or{}
    S.activityInputs={};root.ui=ui;Z.ui=ui;Z.uiCharacter=ui.characters[characterKey];return ui
end
function S.Route(section,subview)
    local state=Z.uiCharacter;if not state or not SECTIONS[section]then return end
    state.section=section=="groups"and(subview=="today"and"today"or"activities")or(section=="profile"or section=="history"or section=="addons")and"settings"or section
    local allowed=SUBVIEWS[section];if allowed and allowed[subview]then state.subviews[section]=subview end
end
function S.Draft(kind,value)
    local state=Z.uiCharacter;if not state then return nil end
    if kind=='group'or kind=='quest'or kind=='scheduled'then state.drafts[kind]=nil;return nil end
    if value==false then state.drafts[kind]=nil
    elseif type(value)=="table"then state.drafts[kind]=copyDraft(value)end
    return state.drafts[kind]
end
-- Back/Continue preserves only the current dialog's input, never SavedVariables.
function S.ActivityInput(kind,value)
    S.activityInputs=S.activityInputs or{}
    if value==false then S.activityInputs[kind]=nil
    elseif type(value)=='table'then S.activityInputs[kind]=copyDraft(value)end
    return S.activityInputs[kind]
end
