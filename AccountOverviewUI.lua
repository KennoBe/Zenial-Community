-- "My characters": the player's own characters in one view on the profile page.
-- List with class icons, main/alt badges and data age; details with gold,
-- rested XP, played time, professions and recorded bags/bank; realm, faction
-- and name/item search. Reads local data only; nothing here sends data to
-- other players. Main changes go through Z.SetMain, deletion through the
-- existing Z.RemoveCharacter confirmation; hiding only affects this view.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local L,T=Z.Logic,Z.Theme
local S
local function tr(s,...)return Z.T(s,...)end
local function O()return Z.AccountOverview end
local FACTION_VALUES={AO_ALLIANCE='Alliance',AO_HORDE='Horde',AO_NEUTRAL='Neutral'}
local FACTION_OPTIONS={Alliance='AO_ALLIANCE',Horde='AO_HORDE',Neutral='AO_NEUTRAL'}
local FACTION_NAMES={AO_ALL='All',AO_ALLIANCE='Alliance',AO_HORDE='Horde',AO_NEUTRAL='Neutral'}
local GOLD,DIM,ALT,WARN='|cffffd36b','|cff9d9d9d','|cff9fc5e8','|cffe0a050'
local ROW_HEIGHT=46

local function when(at)return at and Z.ScheduleTime.Format(at)or tr('Unknown')end
local function duration(seconds)
    local days=math.floor(seconds/86400);local hours=math.floor(seconds%86400/3600);local minutes=math.floor(seconds%3600/60)
    if days>0 then return tr('%dd %dh',days,hours)end
    return tr('%dh %dm',hours,minutes)
end
local function className(r)
    if r.className then return r.className end
    return r.classFile and Z.Locale.Class(nil,r.classFile)or''
end
local function trim(v)return type(v)=='string'and v:match('^%s*(.-)%s*$')or''end
local function badge(r)
    if r.utilityOnly then return DIM..tr('From ZENIAL Utility')..'|r'end
    if r.role=='main'then return GOLD..tr('Main')..'|r'end
    if r.role=='alt'then return ALT..tr('Alt')..'|r'end
end
local function classIcon(r)
    local icon=T and T.ClassIcon(r.classFile,r.className)
    if not icon and T and T.assets then icon={file=T.assets.neutralIcon}end
    return icon
end
-- Removal is the existing Z.RemoveCharacter: same world and faction, never
-- the logged-in character.
local function canDelete(r)return r and not r.utilityOnly and r.sameScope and not r.current end
local function canSetMain(r)return r and not r.utilityOnly and r.sameScope and r.role~='main'end
local function canHide(r)return r and not r.current end

-- Filter options come from the known characters only, so a realm or faction
-- filter never offers a choice that has no character behind it.
local function refreshFilters(all)
    local realms,factions,seenRealm,seenFaction={},{},{},{}
    for _,r in ipairs(all)do
        if r.realm~=''and not seenRealm[r.realm]then seenRealm[r.realm]=true;realms[#realms+1]=r.realm end
        local option=FACTION_OPTIONS[r.faction];if option and not seenFaction[option]then seenFaction[option]=true;factions[#factions+1]=option end
    end
    table.sort(realms);table.sort(factions)
    local realmValues={'AO_ALL'};for _,realm in ipairs(realms)do realmValues[#realmValues+1]='AO_R:'..realm end
    local factionValues={'AO_ALL'};for _,option in ipairs(factions)do factionValues[#factionValues+1]=option end
    for _,spec in ipairs({{U.accountOverviewRealm,realmValues},{U.accountOverviewFaction,factionValues}})do
        local selector,values=spec[1],spec[2];local current=selector:GetText();local keep='AO_ALL'
        for _,v in ipairs(values)do if v==current then keep=v end end
        selector:SetOptions(values,keep);selector:SetText(keep)
    end
end
local function scopeFilter()
    local realm=U.accountOverviewRealm:GetText()
    return{realm=type(realm)=='string'and realm:match('^AO_R:(.+)$')or nil,faction=FACTION_VALUES[U.accountOverviewFaction:GetText()]}
end

-- Visible rows after realm, faction, hidden and search filters, plus the
-- context needed to explain an empty list.
function U.MyCharactersRows()
    local overview=O();local all=overview.List()
    refreshFilters(all)
    local f=scopeFilter();local query=trim(U.accountOverviewSearch:GetText());local needle=string.lower(query)
    local showHidden=U.myCharactersShowHidden:GetChecked()==true
    local scoped,hidden={},0
    for _,r in ipairs(all)do
        if(not f.realm or r.realm==f.realm)and(not f.faction or r.faction==f.faction)then
            if r.hidden and not r.current and not showHidden then hidden=hidden+1 else scoped[#scoped+1]=r end
        end
    end
    local hits,unresolved,holders={},0,{}
    if query~=''then
        hits,unresolved=overview.Search(query,scoped)
        for _,hit in ipairs(hits)do for _,h in ipairs(hit.holders)do holders[h.key]=true end end
    end
    local rows={}
    for _,r in ipairs(scoped)do
        local nameMatch=query==''or string.lower(r.name):find(needle,1,true)~=nil
        if nameMatch or holders[r.key]then r.itemMatch=holders[r.key]and not nameMatch or nil;rows[#rows+1]=r end
    end
    return rows,{all=#all,scoped=scoped,hidden=hidden,query=query,hits=hits,unresolved=unresolved,filtered=f.realm~=nil or f.faction~=nil}
end

local function summary(context)
    local overview=O();local scoped=context.scoped;local known,unknown,oldest,professions=0,0,nil,0
    for _,r in ipairs(scoped)do
        if r.money then known=known+1;if r.moneyAt and(not oldest or r.moneyAt<oldest)then oldest=r.moneyAt end else unknown=unknown+1 end
        if #(r.professions or{})>0 then professions=professions+1 end
    end
    local first=tr('Characters')..': '..#scoped
    if context.hidden>0 then first=first..' · '..tr('%d hidden',context.hidden)end
    if context.filtered then first=first..' · '..tr('Filter active')end
    first=first..' · '..tr('Last recorded gold')..': '..(known>0 and A.MoneyText(overview.TotalMoney(scoped))or tr('Unknown'))
    local second={tr('Sum of the last recorded values, not live')}
    if unknown>0 then second[#second+1]=tr('no gold recorded for %d',unknown)end
    if oldest then second[#second+1]=tr('oldest value %s',S.age(oldest))end
    if professions>0 then second[#second+1]=tr('%d with professions',professions)end
    local note=''
    if overview.readOnly then note=' · '..WARN..tr('The account overview uses a newer format.')..'|r'
    elseif not overview.Enabled()then note=' · '..WARN..tr('Recording is off.')..'|r'end
    -- Taken-over Utility data is named with its age; unassignable rows are counted.
    local status=overview.ImportStatus()
    if status then
        note=note..' · '..DIM..tr('ZENIAL Utility data taken over %s',S.age(status.at))..'|r'
        if status.ambiguous>0 then note=note..' · '..WARN..tr('%d not assignable',status.ambiguous)..'|r'end
    end
    return first..'\n'..DIM..table.concat(second,' · ')..'|r'..note
end

local function listItem(r)
    local b=badge(r)
    local title=(r.hidden and DIM or'')..r.name..(r.hidden and'|r'or'')..(b and('  '..b)or'')
        ..(r.current and('  '..GOLD..'· '..tr('Logged in')..'|r')or'')
    local sub={r.level and(tr('Level')..' '..r.level)or(tr('Level')..' ?')}
    if r.realm~=''then sub[#sub+1]=r.realm end
    if r.faction~=''then sub[#sub+1]=tr(r.faction)end
    local updated=math.max(r.updatedAt or 0,r.lastLogin or 0)
    sub[#sub+1]=tr('updated %s',updated>0 and S.age(updated)or tr('never'))
    if r.itemMatch then table.insert(sub,1,tr('Holds matching items'))end
    if r.hidden then sub[#sub+1]=tr('hidden')end
    local subtitle=table.concat(sub,' · ')
    return{icon=classIcon(r),text=title,subtitle=subtitle,noWrap=true,height=ROW_HEIGHT,selected=r.key==U.characterKey,
        tooltip=r.name..'\n'..subtitle,click=function()U.characterKey=r.key;U.CloseDropdowns();U.RefreshMyCharacters()end}
end

local function restedText(r)
    if r.maxLevel then return tr('Maximum level')end
    if not r.rested or not r.xpMax then return tr('Unknown')end
    local percent=math.floor(r.rested*100/r.xpMax+.5)
    return tr('%d%% of a level',percent)..(r.resting and(' · '..tr('Resting'))or'')..' · '..tr('as of %s',when(r.restedAt))
end
local function header(r)
    local b=badge(r)
    local line=GOLD..r.name..'|r'..(b and('  '..b)or'')..(r.current and('  · '..tr('Logged in'))or'')
    local info={}
    if className(r)~=''then info[#info+1]=className(r)end
    info[#info+1]=tr('Level')..' '..(r.level or tr('Unknown'))
    local ruleset=r.realm~=''and O().Ruleset(r.realm)
    if r.realm~=''then info[#info+1]=r.realm..(ruleset and(' ('..tr(ruleset)..')')or'')end
    if r.faction~=''then info[#info+1]=tr(r.faction)end
    return line..'\n'..table.concat(info,' · ')
end
local function roleText(r)
    if r.utilityOnly then return nil end
    if not r.sameScope then return tr('Main and alts are set in the game world and faction you are logged in to. Log in there to change this character.')end
    if r.role=='main'then return tr('Main of this game world and faction. Without your own choice the first character saved with ZENIAL becomes main; you can change it on any alt.')end
    if r.role=='alt'then return tr('Alt of %s. Other members see this link only while your profile is visible.',r.mainName or tr('Unknown'))end
end
local function details(r)
    local out={}
    local role=roleText(r);if role then out[#out+1]={text=role,height=48}end
    if r.hidden then out[#out+1]={text=tr('Hidden from this overview. Its data is kept; show hidden characters to see it again.'),height=34}end
    out[#out+1]={text=tr('Gold')..': '..(r.money and A.MoneyText(r.money)or tr('Unknown'))..(r.money and(' · '..tr('as of %s',when(r.moneyAt)))or''),height=30}
    out[#out+1]={text=tr('Last login')..': '..when(r.lastLogin),height=30}
    if r.updatedAt then out[#out+1]={text=tr('Last updated')..': '..when(r.updatedAt),height=30}end
    -- Values from the taken-over Utility copy are named, with the takeover time.
    local fields={}
    if r.moneyFromUtility then fields[#fields+1]=tr('Gold')end
    if r.levelFromUtility then fields[#fields+1]=tr('Level')end
    if r.classFromUtility then fields[#fields+1]=tr('Class')end
    if #fields>0 and r.importedAt then
        out[#out+1]={text=DIM..tr('From ZENIAL Utility')..': '..table.concat(fields,', ')..' · '..tr('taken over %s',when(r.importedAt))..'|r',height=44}
    end
    if r.utilityOnly then
        out[#out+1]={text=tr('Only known from the data taken over from ZENIAL Utility. Log in with this character to record more.'),height=44}
        return out
    end
    out[#out+1]={text=tr('Rested XP')..': '..restedText(r),height=44}
    out[#out+1]={text=tr('Played time')..': '..(r.played and(duration(r.played)..' · '..tr('as of %s',when(r.playedAt)))or tr('Type /played on this character.')),height=44}
    local professions={}
    for _,p in ipairs(r.professions)do professions[#professions+1]=tr(L.ProfessionName(p.name))..' '..p.rank..(p.max and('/'..p.max)or'')end
    out[#out+1]={text=tr('Professions')..': '..(#professions>0 and table.concat(professions,', ')or tr('None recorded')),height=44}
    out[#out+1]={text=tr('Bags')..': '..(r.bagsAt and(tr('%d items',r.bagCount or 0)..' · '..tr('as of %s',when(r.bagsAt)))or tr('Not recorded')),height=30}
    out[#out+1]={text=tr('Bank')..': '..(r.bankAt and(tr('%d items',r.bankCount or 0)..' · '..tr('as of %s',when(r.bankAt)))or tr('Bank never opened while recording.')),height=44}
    return out
end
-- Item hits for the current search across all listed characters, shown above
-- the selected character's details.
local function searchResults(context)
    local out={}
    out[1]={text=GOLD..tr('Items matching "%s"',context.query)..'|r',height=24,header=true}
    for _,hit in ipairs(context.hits)do
        local lines={}
        for _,h in ipairs(hit.holders)do
            local places={};if h.bags>0 then places[#places+1]=tr('Bags')..' '..h.bags end;if h.bank>0 then places[#places+1]=tr('Bank')..' '..h.bank end
            lines[#lines+1]=h.name..': '..table.concat(places,', ')
        end
        out[#out+1]={text=hit.name..' · '..hit.total..'\n'..table.concat(lines,'\n'),height=24+16*#lines}
    end
    if #context.hits==0 then out[#out+1]={text=tr('No matching items in recorded bags and banks.'),height=36}end
    if context.unresolved>0 then out[#out+1]={text=tr('%d item names are still loading. Search again in a moment.',context.unresolved),height=36}end
    if not O().InventoryEnabled()then out[#out+1]={text=tr('Bags and bank are only searched once their recording is on.'),height=36}end
    return out
end
local function emptyHint(context)
    if context.query~=''then return tr('No character or recorded item matches this search.')end
    if context.hidden>0 then return tr('All matching characters are hidden. Turn on "Show hidden" to see them.')end
    if context.filtered then return tr('No character for this realm and faction.')end
    return tr('No characters recorded yet.')
end

local function selectedRow(rows)
    for _,r in ipairs(rows)do if r.key==U.characterKey then return r end end
    for _,r in ipairs(rows)do if r.current then U.characterKey=r.key;return r end end
    if rows[1]then U.characterKey=rows[1].key;return rows[1]end
end
function U.RefreshMyCharacters()
    if not U.myCharactersBuilt then return end
    local overview=O()
    U.accountOverviewEnabled:SetChecked(overview.Enabled())
    U.accountOverviewInventory:SetChecked(overview.store and overview.store.inventory==true)
    U.accountOverviewInventory:SetEnabled(overview.Enabled())
    local rows,context=U.MyCharactersRows()
    local selected=selectedRow(rows)
    local items={};for _,r in ipairs(rows)do items[#items+1]=listItem(r)end
    U.SetEmptyHint(U.characterList,emptyHint(context))
    S.rows(U.characterList,items,ROW_HEIGHT)
    U.myCharactersSummary:SetText(summary(context))
    U.myCharactersSelected=selected
    U.myCharactersHeader:SetText(selected and header(selected)or tr('Select a character.'))
    local detailRows={}
    if context.query~=''then for _,row in ipairs(searchResults(context))do detailRows[#detailRows+1]=row end end
    if selected then for _,row in ipairs(details(selected))do detailRows[#detailRows+1]=row end end
    S.rows(U.accountOverviewDetails,detailRows,40)
    U.setMainButton:SetEnabled(canSetMain(selected)==true)
    local utility=overview.UtilityLoaded()and not overview.readOnly
    U.myCharactersMore:SetEnabled(selected~=nil or utility)
    U.importUtilityButton:SetShown(utility)
    U.myCharactersMenu:SetHeight(utility and 160 or 128)
    U.hideCharacterButton:SetText(tr(selected and selected.hidden and'Show in overview again'or'Hide from overview'))
    U.hideCharacterButton:SetEnabled(canHide(selected)==true)
    U.removeCharacterButton:SetEnabled(canDelete(selected)==true)
    local note
    if selected and selected.current then note=tr('The logged-in character always stays visible and cannot be deleted.')
    elseif selected and not canDelete(selected)then note=tr('Data can only be deleted for characters of the game world and faction you are logged in to.')end
    U.myCharactersMenuNote:SetText(note or'')
end

-- Opens the destructive confirmation with the concrete consequences.
local function confirmDelete()
    local r=U.myCharactersSelected;U.CloseDropdowns()
    if not canDelete(r)then return end
    U.removeCharacterKey=r.key
    U.characterConfirmText:SetText(tr('Delete all data of %s? This removes its saved profile, professions, recipes, drafts and private overview data (gold, rested XP, bags, bank) as well as notes, favorites and categories stored for it. History is kept. If it is your main, the logged-in character becomes main. This cannot be undone.',r.name))
    U.characterConfirm:Show()
end
local function toggleMenu()
    local menu=U.myCharactersMenu
    if menu:IsShown()then menu:Hide();S.openPopup=nil;return end
    U.CloseDropdowns();menu:Show();S.openPopup=menu
end

-- Builds the view into the profile page's characters frame.
function U.CreateMyCharacters(frame,helpers)
    S=helpers;local overview=O()
    local label,button,checkbox=S.label,S.button,S.checkbox
    U.profileCharactersTitle=label(frame,'|cffffd36b'..tr('MY CHARACTERS')..'|r',0,0,400,'GameFontNormalLarge')
    U.myCharactersPrivacy=label(frame,tr('Private and local. Never shared.'),400,-4,300)
    U.myCharactersPrivacy:SetJustifyH('RIGHT')
    U.myCharactersSummary=label(frame,'',0,-28,800)
    U.myCharactersSummary:SetHeight(30)
    U.accountOverviewEnabled=checkbox(frame,tr('Record own characters at login'),0,-62,400,function(self)
        local ok,why=overview.SetEnabled(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshMyCharacters()
    end)
    U.accountOverviewInventory=checkbox(frame,tr('Record bags and opened bank'),400,-62,400,function(self)
        local ok,why=overview.SetInventory(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshMyCharacters()
    end)
    local function reset()U.RefreshMyCharacters()end
    U.accountOverviewRealm=S.selector(frame,'Realm',0,-92,200,{'AO_ALL'},reset,function(v)return v=='AO_ALL'and tr('All')or(v:match('^AO_R:(.+)$')or v)end)
    U.accountOverviewFaction=S.selector(frame,'Faction',210,-92,150,{'AO_ALL'},reset,function(v)return tr(FACTION_NAMES[v]or v)end)
    U.accountOverviewRealm:SetText('AO_ALL');U.accountOverviewFaction:SetText('AO_ALL')
    U.accountOverviewSearch=S.edit(frame,'Character or item',370,-92,220,64);U.accountOverviewSearch:SetScript('OnTextChanged',reset)
    U.myCharactersShowHidden=checkbox(frame,tr('Show hidden'),600,-109,170,reset)
    U.characterList=S.list(frame,0,-146,300,260)
    U.myCharactersHeader=label(frame,'',320,-146,400,'GameFontHighlight')
    U.myCharactersHeader:SetHeight(40)
    U.setMainButton=button(frame,'Set as main character',320,-190,200,function()
        local r=U.myCharactersSelected
        if canSetMain(r)and Z.SetMain(r.key)then U.Message(tr('%s is now your main.',r.name))end
        U.Refresh()
    end,'primary')
    U.myCharactersMore=button(frame,'More actions',530,-190,150,toggleMenu)
    U.accountOverviewDetails=S.list(frame,320,-224,400,180)
    -- Secondary menu: the reversible hide action apart from the destructive deletion.
    local menu=CreateFrame('Frame',nil,frame,BackdropTemplateMixin and'BackdropTemplate'or nil)
    U.myCharactersMenu=menu;menu:SetFrameStrata('TOOLTIP');menu:SetClampedToScreen(true);menu:SetSize(250,128)
    if T then T.Panel(menu,'inset')end
    U.hideCharacterButton=button(menu,'Hide from overview',8,-8,234,function()
        local r=U.myCharactersSelected;U.CloseDropdowns()
        if not canHide(r)then return end
        local ok,why=overview.SetHidden(r.key,not r.hidden);if not ok then U.Message(tr(why))end
        U.RefreshMyCharacters()
    end)
    U.removeCharacterButton=button(menu,'Delete character data…',8,-40,234,confirmDelete,'danger')
    U.myCharactersMenuNote=label(menu,'',10,-74,230)
    U.myCharactersMenuNote:SetHeight(48)
    -- Only offered while ZENIAL Utility is loaded; reads it, never writes it.
    -- Repeating it replaces the earlier copy.
    U.importUtilityButton=button(menu,'Take over data from ZENIAL Utility',8,-124,234,function()
        U.CloseDropdowns()
        local n,ambiguous=overview.ImportUtility()
        if not n then U.Message(tr(ambiguous))
        elseif ambiguous>0 then U.Message(tr('%d characters taken over from ZENIAL Utility, %d not assignable.',n,ambiguous))
        else U.Message(tr('%d characters taken over from ZENIAL Utility.',n))end
        U.RefreshMyCharacters()
    end)
    U.importUtilityButton:Hide()
    menu:Hide()
    U.myCharactersBuilt=true
    U.LayoutProfileCharacters()
end

-- Explicit reflow. The page keeps a logical height of at least 500 through
-- window scaling, so the view never needs its own scrollbar; the character
-- list and the details scroll. The bottom row stays free for the page-wide
-- Settings button.
local PROFILE_FOOTER=48
local function place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y)
    if w then f:SetWidth(w)end
    if h then f:SetHeight(h)end
end
local function placeList(view,x,y,w,h)
    local changed=view:GetWidth()~=w or view:GetHeight()~=h
    place(view,x,y,w,h);view.width,view.height=w-24,h;view.child:SetWidth(w-24)
    if changed and view.zenialRender then view.zenialRender()end
end
local function placeCheck(c,x,y,w)place(c,x,y);place(c.text,x+27,y-4,w-27)end
local function placeSelector(s,x,y,w)place(s.caption,x,y);place(s.button,x,y-17);s:SetWidth(w)end
function U.LayoutProfileCharacters()
    local frame=U.profileCharactersFrame
    if not frame or not U.myCharactersBuilt then return end
    local page=U.pages[6]
    local width=math.max(620,page:GetWidth())
    local height=math.max(400,page:GetHeight()-42-PROFILE_FOOTER)
    frame:SetSize(width,height)
    local privacy=math.min(300,math.floor(width*.4))
    place(U.profileCharactersTitle,0,0,width-privacy-10)
    place(U.myCharactersPrivacy,width-privacy,-4,privacy)
    place(U.myCharactersSummary,0,-28,width,30)
    local half=math.floor(width/2)
    placeCheck(U.accountOverviewEnabled,0,-62,half-10)
    placeCheck(U.accountOverviewInventory,half,-62,width-half)
    -- Filter row: realm, faction, search and the hidden switch side by side.
    local hiddenWidth=170;local rest=width-hiddenWidth-30
    local realm=math.floor(rest*.3);local factionWidth=math.floor(rest*.25);local search=rest-realm-factionWidth
    placeSelector(U.accountOverviewRealm,0,-92,realm)
    placeSelector(U.accountOverviewFaction,realm+10,-92,factionWidth)
    local searchX=realm+factionWidth+20
    place(U.accountOverviewSearch.caption,searchX,-92,search);place(U.accountOverviewSearch,searchX,-109,search)
    placeCheck(U.myCharactersShowHidden,width-hiddenWidth,-110,hiddenWidth)
    -- List and detail column share the remaining height.
    local top=146;local body=height-top
    local listWidth=math.max(240,math.min(420,math.floor(width*.42)))
    local detailX=listWidth+16;local detailWidth=width-detailX
    placeList(U.characterList,0,-top,listWidth,body)
    place(U.myCharactersHeader,detailX,-top,detailWidth,40)
    local mainWidth=math.min(210,math.floor(detailWidth*.55));local moreWidth=math.min(170,detailWidth-mainWidth-8)
    place(U.setMainButton,detailX,-(top+44),mainWidth)
    place(U.myCharactersMore,detailX+mainWidth+8,-(top+44),moreWidth)
    placeList(U.accountOverviewDetails,detailX,-(top+78),detailWidth,body-78)
    U.myCharactersMenu:ClearAllPoints();U.myCharactersMenu:SetPoint('TOPRIGHT',U.myCharactersMore,'BOTTOMRIGHT',0,-2)
end

-- One entry point for the own characters, also used by /zenial alts|twinks|account.
function U.OpenMyCharacters()
    U.Create()
    if not U.frame:IsShown()then U.frame:Show()end
    U.CloseDialogs()
    U.Navigate('profile','characters')
    U.Refresh()
end
-- Former name of the account overview entry point; the overview is now part of
-- "My characters".
U.OpenAccountOverview=U.OpenMyCharacters
return U
