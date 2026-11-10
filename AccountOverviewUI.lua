-- "My characters": the player's own characters in one view on the profile page.
-- Two tabs: Overview (character list plus a character sheet with gold, rested
-- XP, played time, professions and recorded bags/bank) and Saved items (item
-- search over the recorded bags and banks). Reads local data only; nothing
-- here sends data to other players. Main changes go through Z.SetMain,
-- deletion through the existing Z.RemoveCharacter confirmation; hiding only
-- affects this view.
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
local HIT_HEIGHT=30
local HOLDER_HEIGHT=40
-- Content widths from here on use the wide two-column layout; below it the
-- list and the detail alternate (list first, selection opens the detail).
local WIDE_WIDTH=860
local SHEET_TWO_COLUMNS=520
local BUTTON_HEIGHT=28

U.myCharactersTab=U.myCharactersTab or'overview'

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
local function plain(text)return(text or''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')end
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

-- Visible rows after realm, faction, hidden and name filters, plus the
-- context needed to explain an empty list. The name search only filters
-- characters; items are searched on the Saved items tab (U.MyCharactersItemHits).
-- context.scoped is the scope shared by both tabs (before the name search).
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
    local rows={}
    for _,r in ipairs(scoped)do
        if query==''or string.lower(r.name):find(needle,1,true)~=nil then rows[#rows+1]=r end
    end
    return rows,{all=#all,scoped=scoped,hidden=hidden,query=query,filtered=f.realm~=nil or f.faction~=nil,
        realm=f.realm,faction=f.faction,showHidden=showHidden}
end
-- Item hits of the Saved items tab: only AccountOverview.Search over the
-- characters of the overview scope. An empty query finds nothing.
function U.MyCharactersItemHits(context)
    local query=trim(U.itemSearch:GetText())
    if query==''then return{},0,query end
    local hits,unresolved=O().Search(query,context.scoped)
    return hits,unresolved,query
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

local function openDetail()
    -- Below the wide width a selection replaces the list by the detail.
    U.myCharactersDetailOpen=true
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
    if r.hidden then sub[#sub+1]=tr('hidden')end
    local subtitle=table.concat(sub,' · ')
    return{icon=classIcon(r),text=title,subtitle=subtitle,noWrap=true,height=ROW_HEIGHT,selected=r.key==U.characterKey,
        tooltip=r.name..'\n'..subtitle,click=function()U.characterKey=r.key;U.CloseDropdowns();openDetail();U.RefreshMyCharacters()end}
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

-- Character sheet: notes spanning the full width plus typed sections
-- (heading and value). Missing data keeps its "unknown" wording, never zero.
local function sheet(r)
    local out={}
    local function note(text)out[#out+1]={full=true,text=text}end
    local function section(head,text)out[#out+1]={head=tr(head),text=text}end
    local role=roleText(r);if role then note(role)end
    if r.hidden then note(tr('Hidden from this overview. Its data is kept; show hidden characters to see it again.'))end
    section('GOLD',r.money and(A.MoneyText(r.money)..' · '..tr('as of %s',when(r.moneyAt)))or tr('Unknown'))
    -- Values from the taken-over Utility copy are named, with the takeover time.
    local fields={}
    if r.moneyFromUtility then fields[#fields+1]=tr('Gold')end
    if r.levelFromUtility then fields[#fields+1]=tr('Level')end
    if r.classFromUtility then fields[#fields+1]=tr('Class')end
    if #fields>0 and r.importedAt then
        note(DIM..tr('From ZENIAL Utility')..': '..table.concat(fields,', ')..' · '..tr('taken over %s',when(r.importedAt))..'|r')
    end
    if r.utilityOnly then
        note(tr('Only known from the data taken over from ZENIAL Utility. Log in with this character to record more.'))
    else
        section('RESTED XP',restedText(r))
        section('PLAYED TIME',r.played and(duration(r.played)..' · '..tr('as of %s',when(r.playedAt)))or tr('Type /played on this character.'))
        local professions={}
        for _,p in ipairs(r.professions)do professions[#professions+1]=tr(L.ProfessionName(p.name))..' '..p.rank..(p.max and('/'..p.max)or'')end
        section('PROFESSIONS',#professions>0 and table.concat(professions,'\n')or tr('None recorded'))
        section('BAGS',r.bagsAt and(tr('%d items',r.bagCount or 0)..' · '..tr('as of %s',when(r.bagsAt)))or tr('Not recorded'))
        section('BANK',r.bankAt and(tr('%d items',r.bankCount or 0)..' · '..tr('as of %s',when(r.bankAt)))or tr('Bank never opened while recording.'))
    end
    -- Data line: where the values come from and how old they are.
    local data={tr('Last login')..': '..when(r.lastLogin)}
    if r.updatedAt then data[#data+1]=tr('Last updated')..': '..when(r.updatedAt)end
    note(DIM..table.concat(data,' · ')..'|r')
    return out
end
local function sheetNode(index)
    local nodes=U.sheetNodes;local node=nodes[index]
    if not node then
        local child=U.accountOverviewDetails.child
        local function text(font)
            local fs=T and T.Text(child,'',font)or child:CreateFontString(nil,'OVERLAY',font)
            if not T then fs:SetJustifyH('LEFT');fs:SetJustifyV('TOP')end
            return fs
        end
        node={head=text('GameFontNormalSmall'),body=text('GameFontHighlightSmall')};nodes[index]=node
    end
    return node
end
-- Places the sheet blocks: sections in two columns once the scroll area is
-- wide enough, otherwise one column; notes always use the full width.
local function layoutSheet()
    local view=U.accountOverviewDetails;local blocks=U.sheetBlocks or{}
    local width=math.max(120,view.width or 400);local two=width>=SHEET_TWO_COLUMNS;local gap=16
    local column=two and math.floor((width-gap)/2)or width
    local y,pending=0,nil
    local function place(node,block,x,w)
        node.body:ClearAllPoints();node.head:ClearAllPoints()
        local top=0
        if block.head then
            node.head:SetPoint('TOPLEFT',x,-y);node.head:SetWidth(w);node.head:SetText(GOLD..block.head..'|r');node.head:SetHeight(14);node.head:Show();top=16
        else node.head:Hide()end
        node.body:SetPoint('TOPLEFT',x,-(y+top));node.body:SetWidth(w);node.body:SetText(block.text)
        local height=math.max(14,math.ceil(node.body:GetStringHeight()))
        node.body:SetHeight(height);node.body:Show()
        return top+height+10
    end
    for index,block in ipairs(blocks)do
        local node=sheetNode(index)
        if block.full or not two then
            if pending then y=y+pending;pending=nil end
            y=y+place(node,block,0,width)
        elseif not pending then
            pending=place(node,block,0,column)
        else
            local second=place(node,block,column+gap,column);y=y+math.max(pending,second);pending=nil
        end
    end
    if pending then y=y+pending end
    for index=#blocks+1,#U.sheetNodes do local node=U.sheetNodes[index];node.head:Hide();node.body:Hide()end
    view.child:SetHeight(math.max(1,y))
    if U.sheetKey~=U.characterKey then U.sheetKey=U.characterKey;view:SetVerticalScroll(0)end
end

-- Scope shown on the Saved items tab: the overview's realm, faction and
-- hidden choice. Items are searched exactly there.
local function scopeText(context)
    local parts={context.realm or tr('All realms'),context.faction and tr(context.faction)or tr('All factions')}
    if context.showHidden then parts[#parts+1]=tr('including hidden')end
    return tr('Scope: %s',table.concat(parts,' · '))
end
local function holderItem(h,byKey)
    local r=byKey[h.key];local place={}
    local function part(name,count,at)
        if count>0 then place[#place+1]=tr(name)..' '..count..(at and(' ('..tr('as of %s',when(at))..')')or'')end
    end
    part('Bags',h.bags,r and r.bagsAt);part('Bank',h.bank,r and r.bankAt)
    local where=h.realm~=''and h.realm or''
    if r and r.faction~=''then where=where..(where~=''and' / 'or'')..tr(r.faction)end
    return{text=h.name..(where~=''and(' · '..where)or''),subtitle=table.concat(place,' · '),noWrap=true,height=HOLDER_HEIGHT}
end
local function refreshItems(context)
    local overview=O()
    local hits,unresolved,query=U.MyCharactersItemHits(context)
    U.itemScope:SetText(scopeText(context))
    local notes={}
    if unresolved>0 then notes[#notes+1]=tr('%d item names are still loading. Search again in a moment.',unresolved)end
    if not overview.InventoryEnabled()then notes[#notes+1]=tr('Bags and bank are only searched once their recording is on.')end
    U.itemsNote:SetText(table.concat(notes,' '))
    local selectedHit
    for _,hit in ipairs(hits)do if hit.id==U.itemHitId then selectedHit=hit end end
    if not selectedHit then selectedHit=hits[1];U.itemHitId=selectedHit and selectedHit.id end
    if not selectedHit then U.itemsDetailOpen=false end
    local items={}
    for _,hit in ipairs(hits)do
        items[#items+1]={text=hit.name..' · '..hit.total,noWrap=true,height=HIT_HEIGHT,selected=selectedHit==hit,
            click=function()U.itemHitId=hit.id;U.itemsDetailOpen=true;U.CloseDropdowns();U.RefreshMyCharacters()end}
    end
    local hint
    if #query<2 and not tonumber(query)then hint=tr('Enter an item name with at least 2 characters or an item ID to search recorded bags and banks.')
    elseif #hits==0 then hint=tr('No matching items in recorded bags and banks.')end
    U.SetEmptyHint(U.itemHitList,hint)
    S.rows(U.itemHitList,items,HIT_HEIGHT)
    local byKey={};for _,r in ipairs(context.scoped)do byKey[r.key]=r end
    local holders={}
    if selectedHit then
        holders[1]={text=GOLD..selectedHit.name..' · '..selectedHit.total..'|r',height=24,header=true}
        for _,h in ipairs(selectedHit.holders)do holders[#holders+1]=holderItem(h,byKey)end
    end
    U.SetEmptyHint(U.itemHolderList,#hits>0 and tr('Select an item to see which characters hold it.')or nil)
    S.rows(U.itemHolderList,holders,HOLDER_HEIGHT)
end

local function emptyHint(context)
    if context.query~=''then return tr('No character matches this search.')end
    if context.hidden>0 then return tr('All matching characters are hidden. Turn on "Show hidden" to see them.')end
    if context.filtered then return tr('No character for this realm and faction.')end
    return tr('No characters recorded yet.')
end

local function selectedRow(rows)
    for _,r in ipairs(rows)do if r.key==U.characterKey then return r end end
    for _,r in ipairs(rows)do if r.current then U.characterKey=r.key;return r end end
    if rows[1]then U.characterKey=rows[1].key;return rows[1]end
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
    U.myCharactersRecordStatus:SetText(DIM..tr('Recording: %s · Bags and bank: %s',onOff(recording),onOff(recording and inventory))..'|r')
    local rows,context=U.MyCharactersRows()
    local selected=selectedRow(rows)
    if not selected then U.myCharactersDetailOpen=false end
    local items={};for _,r in ipairs(rows)do items[#items+1]=listItem(r)end
    U.SetEmptyHint(U.characterList,emptyHint(context))
    S.rows(U.characterList,items,ROW_HEIGHT)
    U.myCharactersSummary:SetText(summary(context))
    U.myCharactersSelected=selected
    U.myCharactersHeader:SetText(selected and header(selected)or tr('Select a character.'))
    if selected and U.myCharactersIcon and T then T.SetTexture(U.myCharactersIcon,classIcon(selected))end
    U.sheetBlocks=selected and sheet(selected)or{}
    local texts={}
    for _,block in ipairs(U.sheetBlocks)do texts[#texts+1]={text=(block.head and(block.head..': ')or'')..block.text}end
    U.accountOverviewDetails.zenialItems=texts
    U.setMainButton:SetEnabled(canSetMain(selected)==true)
    local utility=overview.UtilityLoaded()and not overview.readOnly
    U.myCharactersMore:SetEnabled(selected~=nil or utility)
    U.importUtilityButton:SetShown(utility)
    U.hideCharacterButton:SetText(tr(selected and selected.hidden and'Show in overview again'or'Hide from overview'))
    U.hideCharacterButton:SetEnabled(canHide(selected)==true)
    U.removeCharacterButton:SetEnabled(canDelete(selected)==true)
    local note
    if selected and selected.current then note=tr('The logged-in character always stays visible and cannot be deleted.')
    elseif selected and not canDelete(selected)then note=tr('Data can only be deleted for characters of the game world and faction you are logged in to.')end
    U.myCharactersMenuNote:SetText(note or'')
    if U.myCharactersTab=='items'then refreshItems(context)end
    layoutMenus()
    U.LayoutProfileCharacters()
end

-- Opens the destructive confirmation with the concrete consequences.
local function confirmDelete()
    local r=U.myCharactersSelected;U.CloseDropdowns()
    if not canDelete(r)then return end
    U.removeCharacterKey=r.key
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
    if U.importUtilityButton:IsShown()then buttons[#buttons+1]=U.importUtilityButton end
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
function U.SetMyCharactersTab(tab)setTab(tab=='items'and'items'or'overview')end

-- Builds the view into the profile page's characters frame.
function U.CreateMyCharacters(frame,helpers)
    S=helpers;local overview=O()
    local label,button,checkbox=S.label,S.button,S.checkbox
    U.sheetNodes={}
    -- Head: title and the private-storage note with its explanation.
    U.profileCharactersTitle=label(frame,GOLD..tr('My characters')..'|r',0,0,400,'GameFontNormalLarge')
    U.myCharactersPrivacy=label(frame,tr('Stored privately'),400,-4,200)
    U.myCharactersPrivacy:SetJustifyH('RIGHT')
    U.myCharactersPrivacyHit=CreateFrame('Frame',nil,frame)
    tooltip(U.myCharactersPrivacyHit,function()return tr('Stored only on this computer. This list itself is not sent to other players. While your public profile is visible, your main character and up to 10 other characters of the same realm and faction are published with it. The optional Companion export is a separate setting.')end)
    -- Tabs.
    U.myCharactersOverviewTab=S.navButton(frame,'Overview',0,-26,110,function()setTab('overview')end)
    U.myCharactersItemsTab=S.navButton(frame,'Saved items',120,-26,150,function()setTab('items')end)
    U.myCharactersPublicTab=S.navButton(frame,'Public profile: current character',280,-26,260,function()U.SetProfileView('public')end)
    -- Overview filters.
    U.myCharactersSummary=label(frame,'',0,-108,800)
    U.myCharactersSummary:SetHeight(30)
    U.myCharactersSummaryHit=CreateFrame('Frame',nil,frame)
    tooltip(U.myCharactersSummaryHit,function()return plain(U.myCharactersSummary:GetText())end)
    local function reset()U.RefreshMyCharacters()end
    U.accountOverviewSearch=S.edit(frame,'Search character',0,-60,200,64);U.accountOverviewSearch:SetScript('OnTextChanged',reset)
    U.accountOverviewRealm=S.selector(frame,'Realm',210,-60,200,{'AO_ALL'},reset,function(v)return v=='AO_ALL'and tr('All')or(v:match('^AO_R:(.+)$')or v)end)
    U.accountOverviewFaction=S.selector(frame,'Faction',420,-60,150,{'AO_ALL'},reset,function(v)return tr(FACTION_NAMES[v]or v)end)
    U.accountOverviewRealm:SetText('AO_ALL');U.accountOverviewFaction:SetText('AO_ALL')
    U.myCharactersShowHidden=checkbox(frame,tr('Show hidden'),600,-78,170,reset)
    U.characterList=S.list(frame,0,-142,300,260)
    -- Character sheet.
    U.myCharactersIcon=frame:CreateTexture(nil,'ARTWORK');U.myCharactersIcon:SetSize(32,32)
    U.myCharactersHeader=label(frame,'',320,-142,400,'GameFontHighlight')
    U.myCharactersHeader:SetHeight(36)
    U.myCharactersBack=button(frame,'Back to results',320,-142,140,function()U.myCharactersDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end)
    U.setMainButton=button(frame,'Set as main character',320,-182,200,function()
        local r=U.myCharactersSelected
        if canSetMain(r)and Z.SetMain(r.key)then U.Message(tr('%s is now your main.',r.name))end
        U.Refresh()
    end,'primary')
    buttonTooltip(U.setMainButton,tr('While your public profile is visible, other players can see your main character and up to 10 other characters of this realm and faction.'))
    U.myCharactersMore=button(frame,'More',530,-182,80,toggleMenu)
    U.accountOverviewDetails=S.list(frame,320,-216,400,180)
    -- Saved items: its own search, hits on the left and holders on the right.
    U.itemSearch=S.edit(frame,'Item name (2+ characters) or item ID',0,-60,300,64);U.itemSearch:SetScript('OnTextChanged',reset)
    U.itemScope=label(frame,'',320,-77,300)
    U.itemsNote=label(frame,'',0,-108,800)
    U.itemsNote:SetHeight(30)
    U.itemHitList=S.list(frame,0,-142,300,260)
    U.itemHolderList=S.list(frame,320,-142,400,260)
    U.itemsBack=button(frame,'Back to results',0,-142,140,function()U.itemsDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end)
    -- Footer: recording status and the options popup.
    U.myCharactersRecordStatus=label(frame,'',0,-380,400)
    U.myCharactersRecordButton=button(frame,'Recording options',600,-374,160,toggleRecordMenu)
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
    U.menuButtons={U.hideCharacterButton,U.removeCharacterButton,U.importUtilityButton}
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
-- U.PageUsesNativeScale), so the frame width is the real content width and the
-- layout switches between one and two columns by it. The bottom row stays
-- free for the page-wide Settings button.
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
local function placeEdit(e,x,y,w)place(e.caption,x,y,w);place(e,x,y-17,w)end
local function shown(f,value)if f then f:SetShown(value==true)end end
function U.LayoutProfileCharacters()
    local frame=U.profileCharactersFrame
    if not frame or not U.myCharactersBuilt then return end
    local page=U.pages[6]
    local width=math.max(620,math.floor(page:GetWidth()))
    local height=math.max(300,page:GetHeight())
    frame:SetSize(width,height)
    local items=U.myCharactersTab=='items'
    local wide=width>=WIDE_WIDTH
    U.myCharactersWide=wide
    -- Head: title left, private-storage note right.
    local privacyWidth=math.min(math.floor(width*.4),labelTextWidth(U.myCharactersPrivacy)+4)
    place(U.profileCharactersTitle,0,0,width-privacyWidth-10)
    place(U.myCharactersPrivacy,width-privacyWidth,-4,privacyWidth)
    place(U.myCharactersPrivacyHit,width-privacyWidth,-2,privacyWidth,20)
    -- Tabs: widths from their text.
    local x=0
    for _,tab in ipairs({U.myCharactersOverviewTab,U.myCharactersItemsTab,U.myCharactersPublicTab})do
        local tabWidth=fitButton(tab,96);place(tab,x,-26);x=x+tabWidth+6
    end
    S.selectNav(U.myCharactersOverviewTab,not items);S.selectNav(U.myCharactersItemsTab,items)
    -- Filter row (head, tabs and filters end at y=104, within 120).
    shown(U.accountOverviewSearch,not items);shown(U.accountOverviewSearch.caption,not items)
    U.accountOverviewRealm:SetShown(not items);U.accountOverviewFaction:SetShown(not items)
    shown(U.myCharactersShowHidden,not items);shown(U.myCharactersShowHidden.text,not items)
    shown(U.myCharactersSummary,not items);shown(U.myCharactersSummaryHit,not items)
    shown(U.itemSearch,items);shown(U.itemSearch.caption,items);shown(U.itemScope,items);shown(U.itemsNote,items)
    if items then
        local searchWidth=math.min(360,math.floor(width*.5))
        placeEdit(U.itemSearch,0,-60,searchWidth)
        place(U.itemScope,searchWidth+16,-77,width-searchWidth-16,24)
        place(U.itemsNote,0,-108,width,30)
    else
        local hiddenWidth=labelTextWidth(U.myCharactersShowHidden.text)+31
        local rest=width-hiddenWidth-30
        local search=math.floor(rest*.4);local realm=math.floor(rest*.35);local faction=rest-search-realm
        placeEdit(U.accountOverviewSearch,0,-60,search)
        placeSelector(U.accountOverviewRealm,search+10,-60,realm)
        placeSelector(U.accountOverviewFaction,search+realm+20,-60,faction)
        placeCheck(U.myCharactersShowHidden,width-hiddenWidth,-78,hiddenWidth)
        place(U.myCharactersSummary,0,-108,width,30)
        place(U.myCharactersSummaryHit,0,-108,width,30)
    end
    -- Body: list left (wide) or list/detail alternating (narrow).
    local focusedDetail=not wide and (items and U.itemsDetailOpen or not items and U.myCharactersDetailOpen)
    local top=focusedDetail and 60 or 142;local body=math.max(120,height-top-34)
    local listWidth=wide and math.max(280,math.min(340,math.floor(width*.32)))or width
    local detailX=wide and listWidth+16 or 0;local detailWidth=width-detailX
    local overviewDetail=wide or U.myCharactersDetailOpen
    local overviewList=wide or not U.myCharactersDetailOpen
    local itemsDetail=wide or U.itemsDetailOpen
    if not wide and overviewDetail then
        for _, control in ipairs({ U.accountOverviewSearch, U.accountOverviewSearch.caption, U.accountOverviewRealm, U.accountOverviewFaction, U.myCharactersShowHidden, U.myCharactersShowHidden.text, U.myCharactersSummary, U.myCharactersSummaryHit }) do shown(control,false) end
    elseif not wide and itemsDetail then
        for _, control in ipairs({ U.itemSearch, U.itemSearch.caption, U.itemScope, U.itemsNote }) do shown(control,false) end
    end
    local itemsList=wide or not U.itemsDetailOpen
    shown(U.characterList,not items and overviewList)
    for _,f in ipairs({U.myCharactersIcon,U.myCharactersHeader,U.setMainButton,U.myCharactersMore,U.accountOverviewDetails})do shown(f,not items and overviewDetail)end
    local backShown=not items and not wide and U.myCharactersDetailOpen
    shown(U.myCharactersBack,backShown)
    shown(U.itemHitList,items and itemsList);shown(U.itemHolderList,items and itemsDetail)
    shown(U.itemsBack,items and not wide and U.itemsDetailOpen)
    if not items then
        placeList(U.characterList,0,-top,listWidth,body)
        local headerX=detailX
        if backShown then headerX=headerX+fitButton(U.myCharactersBack,96)+10;place(U.myCharactersBack,detailX,-top)end
        place(U.myCharactersIcon,headerX,-top)
        place(U.myCharactersHeader,headerX+40,-top,math.max(100,width-headerX-40),36)
        local mainWidth=fitButton(U.setMainButton,120);fitButton(U.myCharactersMore,64)
        place(U.setMainButton,detailX,-(top+40));place(U.myCharactersMore,detailX+mainWidth+8,-(top+40))
        placeList(U.accountOverviewDetails,detailX,-(top+74),detailWidth,body-74)
        layoutSheet()
    else
        placeList(U.itemHitList,0,-top,listWidth,body)
        local holderTop=top
        if itemsDetail and not wide then fitButton(U.itemsBack,96);place(U.itemsBack,0,-top);holderTop=top+34 end
        placeList(U.itemHolderList,detailX,-holderTop,detailWidth,body-(holderTop-top))
    end
    -- Footer: recording state left, options right.
    local recordWidth=fitButton(U.myCharactersRecordButton,120)
    place(U.myCharactersRecordButton,width-recordWidth,-(height-BUTTON_HEIGHT))
    place(U.myCharactersRecordStatus,0,-(height-BUTTON_HEIGHT+6),math.max(120,width-recordWidth-12),18)
    U.myCharactersMenu:ClearAllPoints();U.myCharactersMenu:SetPoint('TOPRIGHT',U.myCharactersMore,'BOTTOMRIGHT',0,-2)
    U.myCharactersRecordMenu:ClearAllPoints();U.myCharactersRecordMenu:SetPoint('BOTTOMRIGHT',U.myCharactersRecordButton,'TOPRIGHT',0,2)
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
