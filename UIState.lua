local Z,L=ZenialCommunity,ZenialCommunity.Logic
local S={VERSION=5};Z.UIState=S

local SECTIONS={members=true,craft=true,groups=true,quests=true,trade=true,history=true,profile=true,addons=true,today=true,activities=true,settings=true,pvp=true,rivalry=true}
local SUBVIEWS={
    craft={search=true,mine=true,orders=true,materials=true},
    groups={browse=true,mine=true,outgoing=true,follow=true,today=true,scheduled=true},
    quests={shared=true,questgroups=true,browse=true,mine=true,outgoing=true},
    trade={browse=true,mine=true,rules=true,manage=true},
    profile={public=true,characters=true,display=true,network=true},
    rivalry={overview=true,rivals=true},
}
local DEFAULT_SUBVIEW={craft="search",groups="browse",quests="shared",trade="browse",profile="public",rivalry="overview"}
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
-- Group finder, public group search: which groups are shown (per character), the roles the player looks
-- with, the languages of the public search, "Only fitting" and whether own entries are also listed in the
-- group search of the game (on unless switched off). All per character.
local function finderSource(value)return(value=="ZENIAL"or value=="PUBLIC")and value or"ALL"end
local function finderRoles(raw)
    if type(raw)~="table"then return nil end
    local out={TANK=raw.TANK==true,HEALER=raw.HEALER==true,DAMAGER=raw.DAMAGER==true}
    return(out.TANK or out.HEALER or out.DAMAGER)and out or nil
end
local function finderLanguages(raw)
    local out={mode="DEFAULT",codes={}};if type(raw)~="table"then return out end
    if raw.mode=="ALL"or raw.mode=="CUSTOM"then out.mode=raw.mode end
    local count=0
    for code,on in pairs(type(raw.codes)=="table"and raw.codes or{})do
        if count<32 and on==true and type(code)=="string"and code:match("^%a%a%a%a$")then out.codes[code]=true;count=count+1 end
    end
    return out
end
-- Finder filters (group and player filters of the bar, saved filters). A role set keeps only valid roles that are on;
-- no class set means every class, an empty one means none; a level is empty or a whole number.
local FILTER_CLASSES={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}
local MAX_FINDER_FILTERS=10
local function roleSet(raw,list)
    local out={};if type(raw)~="table"then return out end
    for _,role in ipairs(list)do if raw[role]==true then out[role]=true end end
    return out
end
local function seekerRoles(raw)
    local out,any={},false
    for _,role in ipairs({"TANK","HEALER","DAMAGER"})do out[role]=type(raw)~="table"or raw[role]~=false;any=any or out[role]end
    if not any then for _,role in ipairs({"TANK","HEALER","DAMAGER"})do out[role]=true end end
    return out
end
local function finderFilter(raw)
    raw=type(raw)=="table"and raw or{}
    local out={free=roleSet(raw.free,{"TANK","HEALER","DAMAGER"}),has=roleSet(raw.has,{"TANK","HEALER"}),style=L.Int(raw.style,1,4)and raw.style or 0}
    if L.Int(raw.minLevel,1,100)then out.minLevel=raw.minLevel end
    if L.Int(raw.maxLevel,1,100)then out.maxLevel=raw.maxLevel end
    if out.minLevel and out.maxLevel and out.minLevel>out.maxLevel then out.minLevel,out.maxLevel=out.maxLevel,out.minLevel end
    if type(raw.classes)=="table"then
        local set,count={},0
        for _,class in ipairs(FILTER_CLASSES)do if raw.classes[class]==true then set[class]=true;count=count+1 end end
        if count<#FILTER_CLASSES then out.classes=set end
    end
    return out
end
local function finderProfiles(raw)
    local out,seen={},{};if type(raw)~="table"then return out end
    for _,entry in ipairs(raw)do
        local name=type(entry)=="table"and text(entry.name,24)or""
        if #out<MAX_FINDER_FILTERS and name~=""and not seen[name:lower()]then
            seen[name:lower()]=true
            out[#out+1]={name=name,filter=finderFilter(entry.filter),roles=seekerRoles(entry.roles)}
        end
    end
    return out
end
S.FinderFilter,S.FinderProfiles,S.SeekerRoles,S.MAX_FINDER_FILTERS,S.FinderLanguages=finderFilter,finderProfiles,seekerRoles,MAX_FINDER_FILTERS,finderLanguages
-- The player's own wording of the message to a public group, per language of the message.
local function finderTemplates(raw)
    local out={};if type(raw)~="table"then return out end
    for _,language in ipairs({"de","en"})do if text(raw[language],255)==raw[language]and raw[language]~=""then out[language]=raw[language]end end
    return out
end
-- The player's whisper texts (WhisperTexts.lua): per kind at most 12 valid entries with unique ids.
local function whisperTexts(raw)
    if type(raw)~="table"then return nil end
    local out={}
    for _,kind in ipairs({"group","solo"})do
        local section=type(raw[kind])=="table"and raw[kind]or{};local list,seen={},{}
        for _,e in ipairs(type(section.list)=="table"and section.list or{})do
            if #list<12 and type(e)=="table"and L.Int(e.id,1,100000)and not seen[e.id]and L.Text(e.name,32)and L.Text(e.text,255,true)and(e.language=="de"or e.language=="en")then
                seen[e.id]=true;list[#list+1]={id=e.id,name=e.name,text=e.text,language=e.language}
            end
        end
        out[kind]={list=list,last=L.Int(section.last,1,100000)and section.last or nil}
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
    local ui={version=S.VERSION,showAddonManager=raw.showAddonManager~=false,memberGrouping=raw.memberGrouping~=false,finderNotices=raw.finderNotices~=false,finderPublic=raw.finderPublic~=false,finderTemplates=finderTemplates(raw.finderTemplates),whisperTexts=whisperTexts(raw.whisperTexts),window={width=L.Int(window.width,900,1280)and window.width or 1060,height=L.Int(window.height,610,860)and window.height or 690},characters={}}
    ui.window.width=math.max(900,math.min(1280,math.floor(ui.window.width)));ui.window.height=math.max(610,math.min(860,math.floor(ui.window.height)))
    for key,value in pairs(type(raw.characters)=="table"and raw.characters or{})do
        if type(value)=="table"and L.ValidIdentityKey(key)then
        local section=SECTIONS[value.section]and value.section or"today";local subviews,drafts={},{}
        for area,allowed in pairs(SUBVIEWS)do local selected=type(value.subviews)=="table"and value.subviews[area];subviews[area]=allowed[selected]and selected or DEFAULT_SUBVIEW[area]end
        for kind,draft in pairs(type(value.drafts)=="table"and value.drafts or{})do if kind=="offer"or kind=="profile"then drafts[kind]=copyDraft(draft)end end
        section=section=="groups"and(subviews.groups=="today"and"today"or"activities")or section=="quests"and((subviews.quests=="shared"or subviews.quests=="questgroups")and"today"or"activities")or(section=="profile"or section=="history"or section=="addons")and"settings"or section
        ui.characters[key]={section=section,subviews=subviews,drafts=drafts,memberStatus=value.memberStatus=="ONLINE"and"ONLINE"or"ALL",mapMembers=value.mapMembers~=false,mapGuildOnly=value.mapGuildOnly==true,mapDeaths=value.mapDeaths~=false,questCategories=questCategories(value.questCategories),notifications=Z.Notifications.Normalize(value.notifications),finderSource=finderSource(value.finderSource),finderRoles=finderRoles(value.finderRoles),finderLanguages=finderLanguages(value.finderLanguages or raw.finderLanguages),finderFitting=value.finderFitting==true,finderPublish=value.finderPublish~=false,finderPlaystyle=L.Int(value.finderPlaystyle,1,4)and value.finderPlaystyle or 0,finderBeginners=value.finderBeginners==true,finderFilter=finderFilter(value.finderFilter),finderFilters=finderProfiles(value.finderFilters)}
        end
    end
    ui.characters[characterKey]=ui.characters[characterKey]or{section="today",memberStatus="ALL",subviews={craft="search",groups="browse",quests="shared",trade="browse",profile="public",rivalry="overview"},drafts={}}
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
