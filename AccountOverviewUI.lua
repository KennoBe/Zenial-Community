-- "My characters": the player's own characters in one view on the profile page.
-- This file is the shell: head, tab row, shared filters, footer with the recording
-- options and the character menu. Every tab registers itself with
-- U.RegisterMyCharactersTab(id, {create, layout, refresh}); the shell only calls
-- the visible one. The tabs live in MyCharactersCards.lua (Overview),
-- MyCharactersProfessions.lua and MyCharactersInventory.lua (bags, bank and item
-- search). Reads local data only; nothing here sends data to
-- other players. Main changes go through Z.SetMain, deletion through the existing
-- Z.RemoveCharacter confirmation; hiding only affects this view.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local T=Z.Theme
local S
local function tr(s,...)return Z.T(s,...)end
local function O()return Z.AccountOverview end
local FACTION_VALUES={AO_ALLIANCE='Alliance',AO_HORDE='Horde',AO_NEUTRAL='Neutral'}
local FACTION_OPTIONS={Alliance='AO_ALLIANCE',Horde='AO_HORDE',Neutral='AO_NEUTRAL'}
local FACTION_NAMES={AO_ALL='All',AO_ALLIANCE='Alliance',AO_HORDE='Horde',AO_NEUTRAL='Neutral'}
-- GOLD/DIM/ALT stay only for the colour codes inside item.text of list rows (data contract); everything that is
-- merely displayed goes through the palette (paint).
local GOLD,DIM,ALT='|cffffd36b','|cff9d9d9d','|cff9fc5e8'
local function paint(key,text)
    local K=Z.Kit
    if K and T and T.PaletteHex then return K.Paint(key,text)end
    return text
end
local function styled()return Z.Kit~=nil and T~=nil and T.PaletteHex~=nil end
-- Content widths from here on use the wide two-column layout of the Inventory
-- tab; below it the hits and the holders alternate (hits first).
local WIDE_WIDTH=840
local BUTTON_HEIGHT=28
-- Tabs of the view in their order. The public profile is the last tab and
-- belongs to the profile page, not to this registry.
local TAB_ORDER={'overview','professions','recipes','items'}
local TAB_LABEL={overview='Overview',professions='Professions',recipes='Recipes',items='Inventory'}
local TAB_SPEC={}

U.myCharactersTab=U.myCharactersTab or'overview'
U.myCharactersBodies=U.myCharactersBodies or{}
U.myCharactersTabButtons=U.myCharactersTabButtons or{}

local function when(at)return at and Z.ScheduleTime.Format(at)or tr('Unknown')end
local function duration(seconds)
    local days=math.floor(seconds/86400);local hours=math.floor(seconds%86400/3600);local minutes=math.floor(seconds%3600/60)
    if days>0 then return tr('%dd %dh',days,hours)end
    return tr('%dh %dm',hours,minutes)
end
local function className(r)
    -- A known class file is always shown localized; the stored class name is only the fallback.
    local localized=r.classFile and Z.Locale.Class(nil,r.classFile)
    if localized and localized~=''then return localized end
    return r.className or''
end
local function trim(v)return type(v)=='string'and v:match('^%s*(.-)%s*$')or''end
local function plain(text)return(text or''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')end
local function badge(r,display)
    local function tone(key,legacy,text)return display and paint(key,text)or legacy..text..'|r'end
    if r.utilityOnly then return tone('dim',DIM,tr('From ZENIAL Utility'))end
    if r.role=='main'then return tone('goldBright',GOLD,tr('Main'))end
    if r.role=='alt'then return tone('accentBlue',ALT,tr('Alt'))end
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

-- Text widths come from the rendered strings, so German labels and long
-- translations size their buttons and popups instead of a fixed number.
local function stringWidth(fs)
    if not fs or not fs.GetStringWidth then return 0 end
    return math.ceil(fs:GetStringWidth())
end
local function buttonTextWidth(b)
    local fs=b.GetFontString and b:GetFontString()
    if fs then return stringWidth(fs)end
    return #plain(b:GetText())*7
end
local function labelTextWidth(fs)
    local old=fs:GetWidth();fs:SetWidth(1000);local width=stringWidth(fs);fs:SetWidth(old);return width
end
local function fitButton(b,minimum)
    b:SetSize(math.max(minimum or 80,buttonTextWidth(b)+28),BUTTON_HEIGHT);return b:GetWidth()
end
local function tooltip(frame,text)
    frame:EnableMouse(true)
    frame:SetScript('OnEnter',function(self)
        local value=type(text)=='function'and text()or text
        if GameTooltip and value and value~=''then
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(value,1,.9,.7,true);GameTooltip:Show()
        end
    end)
    frame:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
end
local function buttonTooltip(button,text)
    button:HookScript('OnEnter',function(self)
        if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(text,1,.9,.7,true);GameTooltip:Show()end
    end)
    button:HookScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
end
-- Explicit placement relative to the parent's top left corner.
local function place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y)
    if w then f:SetWidth(w)end
    if h then f:SetHeight(h)end
end
local function shown(f,value)if f then f:SetShown(value==true)end end

-- The list always shows the characters of the current realm; there is no realm choice. Faction options come from
-- those characters only, so the filter never offers a choice that has no character behind it. The first time
-- characters exist, the faction filter starts on the logged-in character's faction (when it is among the options).
local function currentRealm()
    local me=Z.me or{}
    return type(me.realm)=='string'and me.realm or''
end
local function refreshFilters(all)
    local realm=currentRealm();local factions,seenFaction,count={},{},0
    for _,r in ipairs(all)do
        if r.realm==realm then
            count=count+1
            local option=FACTION_OPTIONS[r.faction];if option and not seenFaction[option]then seenFaction[option]=true;factions[#factions+1]=option end
        end
    end
    table.sort(factions)
    local values={'AO_ALL'};for _,option in ipairs(factions)do values[#values+1]=option end
    local first=not U.myCharactersScopeDefaulted and count>0
    local default=first and FACTION_OPTIONS[(Z.me or{}).faction]or nil
    local selector=U.accountOverviewFaction;local current=selector:GetText();local keep='AO_ALL'
    for _,v in ipairs(values)do if v==current then keep=v end end
    if default then for _,v in ipairs(values)do if v==default then keep=v end end end
    selector:SetOptions(values,keep);selector:SetText(keep)
    if first then U.myCharactersScopeDefaulted=true end
end
local function scopeFilter()
    return{realm=currentRealm(),faction=FACTION_VALUES[U.accountOverviewFaction:GetText()]}
end

-- Visible rows after realm, faction, hidden and name filters, plus the
-- context needed to explain an empty list. The name search only filters
-- characters; items are searched on the Inventory tab (U.MyCharactersItemHits).
-- context.scoped is the scope shared by all tabs (before the name search).
function U.MyCharactersRows()
    local overview=O();local all=overview.List()
    refreshFilters(all)
    local f=scopeFilter();local query=trim(U.accountOverviewSearch:GetText());local needle=string.lower(query)
    local showHidden=U.myCharactersShowHidden:GetChecked()==true
    local scoped,hidden={},0
    for _,r in ipairs(all)do
        if r.realm==f.realm and(not f.faction or r.faction==f.faction)then
            if r.hidden and not r.current and not showHidden then hidden=hidden+1 else scoped[#scoped+1]=r end
        end
    end
    local rows={}
    for _,r in ipairs(scoped)do
        if query==''or string.lower(r.name):find(needle,1,true)~=nil then rows[#rows+1]=r end
    end
    return rows,{all=#all,scoped=scoped,hidden=hidden,query=query,filtered=f.faction~=nil or query~='',
        realm=f.realm,faction=f.faction,showHidden=showHidden}
end
-- Realm, faction and hidden choice that every tab applies; shown where a tab has no filter row of its own.
local function scopeText(context)
    local realm=context.realm==nil and tr('All realms')or context.realm~=''and context.realm or tr('Unknown')
    local parts={realm,context.faction and tr(context.faction)or tr('All factions')}
    if context.showHidden then parts[#parts+1]=tr('including hidden')end
    return tr('Scope: %s',table.concat(parts,' · '))
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
    if overview.readOnly then note=' · '..paint('warning',tr('The account overview uses a newer format.'))
    elseif not overview.Enabled()then note=' · '..paint('warning',tr('Recording is off.'))end
    -- Taken-over Utility data is named with its age; unassignable rows are counted.
    local status=overview.ImportStatus()
    if status then
        note=note..' · '..paint('dim',tr('ZENIAL Utility data taken over %s',S.age(status.at)))
        if status.ambiguous>0 then note=note..' · '..paint('warning',tr('%d not assignable',status.ambiguous))end
    end
    return paint('text',first)..'\n'..paint('dim',table.concat(second,' · '))..note
end

local function onOff(value)return value and tr('on')or tr('off')end
local layoutMenus
function U.RefreshMyCharacters()
    if not U.myCharactersBuilt then return end
    local overview=O()
    U.accountOverviewEnabled:SetChecked(overview.Enabled())
    U.accountOverviewInventory:SetChecked(overview.store and overview.store.inventory==true)
    U.accountOverviewInventory:SetEnabled(overview.Enabled())
    local recording,inventory=overview.Enabled(),overview.InventoryEnabled()
    U.myCharactersRecordStatus:SetText(paint('dim',tr('Recording: %s · Bags and bank: %s',onOff(recording),onOff(recording and inventory))))
    local rows,context=U.MyCharactersRows()
    -- A deleted character closes its details (the delete handler selects the logged-in character).
    local deleting=U.myCharactersDeleting
    if deleting and not U.characterConfirm:IsShown()then
        if not overview.Get(deleting)then U.myCharactersDetailOpen=false end
        U.myCharactersDeleting=nil
    end
    local selected=U.myCharactersDetailOpen and overview.Get(U.characterKey)or nil
    if not selected then U.myCharactersDetailOpen=false end
    U.myCharactersSelected=selected
    U.myCharactersSummary:SetText(summary(context))
    U.setMainButton:SetEnabled(canSetMain(selected)==true)
    U.myCharactersMore:SetEnabled(selected~=nil)
    U.hideCharacterButton:SetText(tr(selected and selected.hidden and'Show in overview again'or'Hide from overview'))
    U.hideCharacterButton:SetEnabled(canHide(selected)==true)
    U.removeCharacterButton:SetEnabled(canDelete(selected)==true)
    local note
    if selected and selected.current then note=tr('The logged-in character always stays visible and cannot be deleted.')
    elseif selected and not canDelete(selected)then note=tr('Data can only be deleted for characters of the game world and faction you are logged in to.')end
    U.myCharactersMenuNote:SetText(note or'')
    local spec=TAB_SPEC[U.myCharactersTab or'overview']
    if spec and spec.refresh then spec.refresh(rows,context)end
    layoutMenus()
    U.LayoutProfileCharacters()
end

-- Opens the destructive confirmation with the concrete consequences.
local function confirmDelete()
    local r=U.myCharactersSelected;U.CloseDropdowns()
    if not canDelete(r)then return end
    U.removeCharacterKey=r.key;U.myCharactersDeleting=r.key
    U.characterConfirmText:SetText(tr('Delete all data of %s? This removes its saved profile, professions, recipes, drafts and private overview data (gold, rested XP, bags, bank) as well as notes, favorites and categories stored for it. History is kept. If it is your main, the logged-in character becomes main. This cannot be undone.',r.name))
    U.characterConfirm:Show()
end
-- Small popups share the dropdown mechanism: one open at a time, ESC and
-- U.CloseDropdowns close them first.
local function togglePopup(menu)
    if menu:IsShown()then menu:Hide();S.openPopup=nil;return end
    U.CloseDropdowns();menu:Show();S.openPopup=menu
end
local function toggleMenu()togglePopup(U.myCharactersMenu)end
local function toggleRecordMenu()togglePopup(U.myCharactersRecordMenu)end

-- Popup sizes follow their longest text (German labels are longer).
function layoutMenus()
    local menu=U.myCharactersMenu;if not menu then return end
    local buttons={U.hideCharacterButton,U.removeCharacterButton}
    local widest=160;for _,b in ipairs(buttons)do widest=math.max(widest,buttonTextWidth(b)+28)end
    local y=8
    for _,b in ipairs(U.menuButtons)do b:Hide()end
    for _,b in ipairs(buttons)do
        b:Show();b:ClearAllPoints();b:SetPoint('TOPLEFT',8,-y);b:SetSize(widest,BUTTON_HEIGHT);y=y+BUTTON_HEIGHT+4
    end
    U.myCharactersMenuNote:ClearAllPoints();U.myCharactersMenuNote:SetPoint('TOPLEFT',10,-(y+2))
    U.myCharactersMenuNote:SetWidth(widest-4)
    local hasNote=U.myCharactersMenuNote:GetText()~=''
    local noteHeight=hasNote and math.max(16,math.ceil(U.myCharactersMenuNote:GetStringHeight()))or 0
    U.myCharactersMenuNote:SetHeight(math.max(1,noteHeight))
    menu:SetSize(widest+16,y+noteHeight+(hasNote and 14 or 6))
    local record=U.myCharactersRecordMenu
    local inner=math.max(labelTextWidth(U.accountOverviewEnabled.text),labelTextWidth(U.accountOverviewInventory.text))+27
    local width=math.max(240,inner+20)
    U.myCharactersRecordNote:SetWidth(width-20)
    local noteH=math.max(16,math.ceil(U.myCharactersRecordNote:GetStringHeight()))
    U.myCharactersRecordNote:SetHeight(noteH)
    U.accountOverviewEnabled:ClearAllPoints();U.accountOverviewEnabled:SetPoint('TOPLEFT',10,-10)
    U.accountOverviewEnabled.text:ClearAllPoints();U.accountOverviewEnabled.text:SetPoint('TOPLEFT',37,-14)
    U.accountOverviewEnabled.text:SetWidth(width-47)
    U.accountOverviewInventory:ClearAllPoints();U.accountOverviewInventory:SetPoint('TOPLEFT',10,-40)
    U.accountOverviewInventory.text:ClearAllPoints();U.accountOverviewInventory.text:SetPoint('TOPLEFT',37,-44)
    U.accountOverviewInventory.text:SetWidth(width-47)
    U.myCharactersRecordNote:ClearAllPoints();U.myCharactersRecordNote:SetPoint('TOPLEFT',12,-72)
    record:SetSize(width,72+noteH+12)
end

local function setTab(tab)
    if U.myCharactersTab==tab then return end
    U.CloseDropdowns()
    U.myCharactersTab=tab;U.myCharactersDetailOpen=false;U.itemsDetailOpen=false
    U.RefreshMyCharacters()
end
function U.SetMyCharactersTab(tab)setTab(TAB_SPEC[tab]and tab or'overview')end

-- Route selection {characterKey, profession, recipe, itemID}: kept for the tab it
-- belongs to. A character on the overview route opens its details; the Inventory
-- route shows that character's bags or searches that item.
function U.ApplyMyCharactersSelection(route)
    local selection=type(route.selection)=='table'and route.selection or nil
    U.myCharactersSelection=selection
    if not selection then return end
    if selection.characterKey then U.characterKey=selection.characterKey end
    if route.view=='overview'and selection.characterKey then
        setTab('overview');U.myCharactersDetailOpen=true;U.RefreshMyCharacters()
    elseif route.view=='items'and U.ApplyMyCharactersInventorySelection then
        U.ApplyMyCharactersInventorySelection(selection);U.RefreshMyCharacters()
    end
end
local function openRoute(view,selection)
    U.Create()
    if not U.frame:IsShown()then U.frame:Show()end
    local ok=U.Navigate('characters',view,selection)
    if ok then U.Refresh()end
    return ok
end
local function cleanSelection(selection,allowed)
    local out={}
    if type(selection)=='table'then for _,field in ipairs(allowed)do if selection[field]~=nil then out[field]=selection[field]end end end
    return next(out)and out or nil
end
function U.OpenMyCharactersRecipes(selection)
    return openRoute('recipes',cleanSelection(selection,{'characterKey','profession','recipe'}))
end
function U.OpenMyCharactersInventory(selection)
    return openRoute('items',cleanSelection(selection,{'characterKey','itemID'}))
end

-- Pieces the tab files share with the shell.
U.MyCharactersUI={scopeText=scopeText,paint=paint,styled=styled,when=when,duration=duration,className=className,plain=plain,badge=badge,classIcon=classIcon,
    canDelete=canDelete,canSetMain=canSetMain,canHide=canHide,buttonTextWidth=buttonTextWidth,fitButton=fitButton,place=place,shown=shown,
    BUTTON_HEIGHT=BUTTON_HEIGHT,
    showDetail=function(key)
        U.characterKey=key;U.myCharactersDetailOpen=true;U.CloseDropdowns();U.RefreshMyCharacters()
    end,
    closeDetail=function()U.myCharactersDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end}

function U.RegisterMyCharactersTab(id,spec)
    if not TAB_LABEL[id]or type(spec)~='table'then return false end
    TAB_SPEC[id]=spec
    -- A tab that registers after the view was built gets its body at once.
    if U.myCharactersBuilt and not U.myCharactersBodies[id]and spec.create then
        local body=CreateFrame('Frame',nil,U.myCharactersFrame);body:SetSize(100,100);body:Hide()
        U.myCharactersBodies[id]=body;spec.create(body,S)
    end
    return true
end
-- Professions and Recipes get their own files; until then the tab shows an empty state.
for _,id in ipairs({'professions','recipes'})do
    local state
    U.RegisterMyCharactersTab(id,{
        create=function(body)
            state=Z.Kit.EmptyState(body,{icon='characters',title=tr(TAB_LABEL[id]),width=320});state:SetPoint('TOP',body,'TOP',0,-40)
        end,
        layout=function()end,refresh=function()end})
end

-- Builds the view into the profile page's characters frame.
function U.CreateMyCharacters(frame,helpers)
    S=helpers;local overview=O()
    local label,button,checkbox=S.label,S.button,S.checkbox
    U.myCharactersFrame=frame
    -- Head: title and the private-storage note with its explanation.
    U.profileCharactersTitle=label(frame,paint('goldBright',tr('My characters')),0,0,400,'GameFontNormalLarge')
    U.myCharactersPrivacy=label(frame,tr('Stored privately'),400,-4,200)
    U.myCharactersPrivacy:SetJustifyH('RIGHT')
    U.myCharactersPrivacyHit=CreateFrame('Frame',nil,frame)
    tooltip(U.myCharactersPrivacyHit,function()return tr('Stored only on this computer. This list itself is not sent to other players. While your public profile is visible, your main character and up to 10 other characters of the same realm and faction are published with it. The optional Companion export is a separate setting.')end)
    -- Tabs: the registered tabs plus the public profile as the last one. It keeps this head and tab row and
    -- shows its form below (U.profilePublicFrame); leaving it returns to the chosen characters tab.
    local function openTab(tab)
        if U.profileView=='public'then U.myCharactersTab=nil;U.SetProfileView('characters')end
        setTab(tab)
    end
    for _,id in ipairs(TAB_ORDER)do
        U.myCharactersTabButtons[id]=S.navButton(frame,TAB_LABEL[id],0,-26,110,function()openTab(id)end)
    end
    U.myCharactersOverviewTab=U.myCharactersTabButtons.overview
    U.myCharactersProfessionsTab=U.myCharactersTabButtons.professions
    U.myCharactersRecipesTab=U.myCharactersTabButtons.recipes
    U.myCharactersItemsTab=U.myCharactersTabButtons.items
    U.myCharactersPublicTab=S.navButton(frame,'Public profile: current character',280,-26,260,function()U.CloseDropdowns();U.SetProfileView('public')end)
    -- Shared filters.
    U.myCharactersSummary=label(frame,'',0,-108,800)
    U.myCharactersSummary:SetHeight(30)
    U.myCharactersSummaryHit=CreateFrame('Frame',nil,frame)
    tooltip(U.myCharactersSummaryHit,function()return plain(U.myCharactersSummary:GetText())end)
    local function reset()U.RefreshMyCharacters()end
    U.accountOverviewSearch=S.edit(frame,'Search character',0,-60,200,64);U.accountOverviewSearch:SetScript('OnTextChanged',reset)
    U.accountOverviewFaction=S.selector(frame,'Faction',210,-60,150,{'AO_ALL'},reset,function(v)return tr(FACTION_NAMES[v]or v)end)
    U.accountOverviewFaction:SetText('AO_ALL')
    U.myCharactersShowHidden=checkbox(frame,tr('Show hidden'),600,-78,170,reset)
    -- Details head of the Overview tab: shared controls with the existing handlers; the tab places them.
    U.myCharactersIcon=frame:CreateTexture(nil,'ARTWORK');U.myCharactersIcon:SetSize(36,36)
    U.myCharactersHeader=label(frame,'',320,-142,400,'GameFontHighlight')
    U.myCharactersHeader:SetHeight(36)
    U.myCharactersBack=button(frame,'Back to overview',320,-142,140,function()U.myCharactersDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end)
    U.setMainButton=button(frame,'Set as main character',320,-182,200,function()
        local r=U.myCharactersSelected
        if canSetMain(r)and Z.SetMain(r.key)then U.Message(tr('%s is now your main.',r.name))end
        U.Refresh()
    end,'primary')
    buttonTooltip(U.setMainButton,tr('While your public profile is visible, other players can see your main character and up to 10 other characters of this realm and faction.'))
    U.myCharactersMore=button(frame,'More',530,-182,80,toggleMenu)
    -- Footer: recording status and the options popup.
    U.myCharactersRecordStatus=label(frame,'',0,-380,400)
    U.myCharactersRecordButton=button(frame,'Recording options',600,-374,160,toggleRecordMenu)
    -- Tab bodies, below the tab row (and the filters when the tab uses them).
    for _,id in ipairs(TAB_ORDER)do
        local spec=TAB_SPEC[id]
        if spec and spec.create then
            local body=CreateFrame('Frame',nil,frame);body:SetSize(100,100);body:Hide()
            U.myCharactersBodies[id]=body;spec.create(body,S)
        end
    end
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
    U.menuButtons={U.hideCharacterButton,U.removeCharacterButton}
    menu:Hide()
    -- Recording options popup: the two existing switches with their handlers.
    local record=CreateFrame('Frame',nil,frame,BackdropTemplateMixin and'BackdropTemplate'or nil)
    U.myCharactersRecordMenu=record;record:SetFrameStrata('TOOLTIP');record:SetClampedToScreen(true);record:SetSize(300,110)
    if T then T.Panel(record,'inset')end
    U.accountOverviewEnabled=checkbox(record,tr('Record own characters at login'),10,-10,280,function(self)
        local ok,why=overview.SetEnabled(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshMyCharacters()
    end)
    U.accountOverviewInventory=checkbox(record,tr('Record bags and opened bank'),10,-40,280,function(self)
        local ok,why=overview.SetInventory(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshMyCharacters()
    end)
    U.myCharactersRecordNote=label(record,tr('Turning recording off only stops new entries. Saved data is not deleted.'),12,-72,280)
    record:Hide()
    U.myCharactersBuilt=true
    U.myCharactersDetailOpen=false;U.itemsDetailOpen=false
    layoutMenus()
    U.LayoutProfileCharacters()
end

-- Explicit reflow. The characters view runs at native scale (see
-- U.PageUsesNativeScale), so the frame width is the real content width. The
-- bottom row stays free for the page-wide Settings button.
local function placeSelector(s,x,y,w)place(s.caption,x,y);place(s.button,x,y-17);s:SetWidth(w)end
local function placeCheck(c,x,y,w)place(c,x,y);place(c.text,x+27,y-4,w-27)end
function U.LayoutProfileCharacters()
    local frame=U.profileCharactersFrame
    if not frame or not U.myCharactersBuilt then return end
    local page=U.pages[6]
    local width=math.max(620,math.floor(page:GetWidth()))
    local height=math.max(300,page:GetHeight())
    frame:SetSize(width,height)
    local public=U.profileView=='public'
    local active=not public and(U.myCharactersTab or'overview')or nil
    local spec=active and TAB_SPEC[active]
    U.myCharactersWide=width>=WIDE_WIDTH
    -- Head: title left, private-storage note right.
    local privacyWidth=math.min(math.floor(width*.4),labelTextWidth(U.myCharactersPrivacy)+4)
    place(U.profileCharactersTitle,0,0,width-privacyWidth-10)
    place(U.myCharactersPrivacy,width-privacyWidth,-4,privacyWidth)
    place(U.myCharactersPrivacyHit,width-privacyWidth,-2,privacyWidth,20)
    -- Tabs: widths from their text.
    local x=0
    local tabs={}
    for _,id in ipairs(TAB_ORDER)do tabs[#tabs+1]=U.myCharactersTabButtons[id]end
    tabs[#tabs+1]=U.myCharactersPublicTab
    for _,tab in ipairs(tabs)do
        local tabWidth=fitButton(tab,72);place(tab,x,-26);x=x+tabWidth+6
    end
    for _,id in ipairs(TAB_ORDER)do S.selectNav(U.myCharactersTabButtons[id],active==id)end
    S.selectNav(U.myCharactersPublicTab,public)
    for _,control in ipairs({U.myCharactersPrivacy,U.myCharactersPrivacyHit,U.myCharactersRecordButton,U.myCharactersRecordStatus})do shown(control,not public)end
    -- Filter row (head, tabs and filters end at y=104, within 120). A tab can hide it (own search) or ask for
    -- the whole width (its details page).
    local focused=spec and spec.focused and spec.focused()==true
    local filters=spec~=nil and spec.filters~=false and not focused
    local filterControls={U.accountOverviewSearch,U.accountOverviewSearch.caption,U.accountOverviewFaction,U.accountOverviewFaction.caption,
        U.myCharactersShowHidden,U.myCharactersShowHidden.text,U.myCharactersSummary,U.myCharactersSummaryHit}
    for _,control in ipairs(filterControls)do shown(control,filters)end
    if filters then
        local hiddenWidth=labelTextWidth(U.myCharactersShowHidden.text)+31
        local rest=width-hiddenWidth-30
        local search=math.floor(rest*.6);local faction=rest-search
        place(U.accountOverviewSearch.caption,0,-60,search);place(U.accountOverviewSearch,0,-77,search)
        placeSelector(U.accountOverviewFaction,search+10,-60,faction)
        placeCheck(U.myCharactersShowHidden,width-hiddenWidth,-78,hiddenWidth)
        place(U.myCharactersSummary,0,-108,width,30)
        place(U.myCharactersSummaryHit,0,-108,width,30)
    end
    -- The shared details controls belong to the visible tab, which shows them when it needs them.
    for _,control in ipairs({U.myCharactersIcon,U.myCharactersHeader,U.setMainButton,U.myCharactersMore,U.myCharactersBack})do shown(control,false)end
    local top=filters and 142 or 60
    for id,body in pairs(U.myCharactersBodies)do body:SetShown(id==active)end
    if spec then
        local bodyHeight=math.max(120,height-top-34)
        local body=U.myCharactersBodies[active]
        if body then place(body,0,-top,width,bodyHeight)end
        if spec.layout then spec.layout(0,top,width,bodyHeight)end
    end
    -- Footer: recording state left, options right.
    local recordWidth=fitButton(U.myCharactersRecordButton,120)
    place(U.myCharactersRecordButton,width-recordWidth,-(height-BUTTON_HEIGHT))
    place(U.myCharactersRecordStatus,0,-(height-BUTTON_HEIGHT+6),math.max(120,width-recordWidth-12),18)
    U.myCharactersMenu:ClearAllPoints();U.myCharactersMenu:SetPoint('TOPRIGHT',U.myCharactersMore,'BOTTOMRIGHT',0,-2)
    U.myCharactersRecordMenu:ClearAllPoints();U.myCharactersRecordMenu:SetPoint('BOTTOMRIGHT',U.myCharactersRecordButton,'TOPRIGHT',0,2)
    -- Public profile tab: only the head and the tab row of this frame stay; the profile form follows below.
    if public then
        U.myCharactersMenu:Hide();U.myCharactersRecordMenu:Hide()
    end
    if U.LayoutProfilePublic then U.LayoutProfilePublic()end
end

-- One entry point for the own characters, also used by /zenial alts|twinks|account.
function U.OpenMyCharacters()
    U.Create()
    if not U.frame:IsShown()then U.frame:Show()end
    local ok=U.Navigate('profile','characters')
    if not ok then return end
    U.myCharactersTab='overview';U.myCharactersDetailOpen=false;U.itemsDetailOpen=false
    U.Refresh()
end
-- Former name of the account overview entry point; the overview is now part of
-- "My characters".
U.OpenAccountOverview=U.OpenMyCharacters
return U
