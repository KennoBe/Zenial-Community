-- Account overview dialog: own characters, gold, rested XP, played time,
-- professions and an optional item search across recorded bags and banks.
-- Reads local data only; nothing here sends data to other players.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local L=Z.Logic
local H
local function tr(s,...)return Z.T(s,...)end
local function O()return Z.AccountOverview end
local FACTIONS={AO_ALL='All',AO_ALLIANCE='Alliance',AO_HORDE='Horde'}
local FACTION_VALUES={AO_ALLIANCE='Alliance',AO_HORDE='Horde'}
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
local function filter()
    local realm=U.accountOverviewRealm:GetText();local faction=U.accountOverviewFaction:GetText()
    return{realm=type(realm)=='string'and realm:match('^AO_R:(.+)$')or nil,faction=FACTION_VALUES[faction]}
end
function U.AccountOverviewRows()return O().List(filter())end
local function refreshRealms()
    local values={'AO_ALL'};for _,realm in ipairs(O().Realms())do values[#values+1]='AO_R:'..realm end
    local current=U.accountOverviewRealm:GetText();local keep='AO_ALL'
    for _,v in ipairs(values)do if v==current then keep=v end end
    U.accountOverviewRealm:SetOptions(values,keep);U.accountOverviewRealm:SetText(keep)
end
local function restedText(r)
    if r.maxLevel then return tr('Maximum level')end
    if not r.rested or not r.xpMax then return tr('Unknown')end
    local percent=math.floor(r.rested*100/r.xpMax+.5)
    return tr('%d%% of a level',percent)..(r.resting and(' · '..tr('Resting'))or'')..' · '..tr('as of %s',when(r.restedAt))
end
local function details(r)
    local out={}
    local head=r.name..(r.level and(' · '..tr('Level')..' '..r.level)or'')..(className(r)~=''and(' · '..className(r))or'')
    local ruleset=O().Ruleset(r.realm)
    out[#out+1]={text=head..'\n'..r.realm..(ruleset and(' · '..tr(ruleset))or'')..(r.faction~=''and(' · '..tr(r.faction))or''),height=44}
    out[#out+1]={text=tr('Gold')..': '..(r.money and A.MoneyText(r.money)or tr('Unknown'))..(r.money and(' · '..tr('as of %s',when(r.moneyAt)))or'')
        ..(r.moneyFromUtility and('\n'..tr('From ZENIAL Utility'))or''),height=r.moneyFromUtility and 44 or 30}
    out[#out+1]={text=tr('Last login')..': '..when(r.lastLogin),height=30}
    if r.utilityOnly then
        out[#out+1]={text=tr('Only known to ZENIAL Utility. Log in with this character to record more.'),height=44}
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
local function searchResults(rows)
    local hits,unresolved=O().Search(U.accountOverviewSearch:GetText(),rows)
    local out={}
    for _,hit in ipairs(hits)do
        local lines={}
        for _,h in ipairs(hit.holders)do
            local places={};if h.bags>0 then places[#places+1]=tr('Bags')..' '..h.bags end;if h.bank>0 then places[#places+1]=tr('Bank')..' '..h.bank end
            lines[#lines+1]=h.name..': '..table.concat(places,', ')
        end
        out[#out+1]={text=hit.name..' · '..hit.total..'\n'..table.concat(lines,'\n'),height=24+16*#lines}
    end
    if #out==0 then out[1]={text=tr('No matching items in recorded bags and banks.'),height=36}end
    if unresolved>0 then out[#out+1]={text=tr('%d item names are still loading. Search again in a moment.',unresolved),height=36}end
    return out
end
function U.RefreshAccountOverview()
    if not U.accountOverview then return end
    local overview=O()
    U.accountOverviewEnabled:SetChecked(overview.Enabled())
    U.accountOverviewInventory:SetChecked(overview.store and overview.store.inventory==true)
    U.accountOverviewInventory:SetEnabled(overview.Enabled())
    refreshRealms()
    local rows=U.AccountOverviewRows();local items={};local selected
    for _,r in ipairs(rows)do
        if r.key==U.accountOverviewKey then selected=r end
        items[#items+1]={text=r.name..(r.current and(' · '..tr('Logged in'))or'')..'\n'..(r.level and(tr('Level')..' '..r.level..' ')or'')..className(r)..'\n'..(r.money and A.MoneyText(r.money)or tr('Gold unknown')),
            height=58,selected=r.key==U.accountOverviewKey,click=function()U.accountOverviewKey=r.key;U.RefreshAccountOverview()end}
    end
    H.rows(U.accountOverviewList,items,58)
    U.accountOverviewCount:SetText(tr('Characters')..' ('..#rows..') · '..tr('Total gold')..': '..A.MoneyText(overview.TotalMoney(rows))
        ..(overview.readOnly and(' · '..tr('The account overview uses a newer format.'))or''))
    local query=U.accountOverviewSearch:GetText()or''
    if query:match('%S')then
        H.rows(U.accountOverviewDetails,searchResults(rows),40)
    elseif selected then
        H.rows(U.accountOverviewDetails,details(selected),40)
    else
        H.rows(U.accountOverviewDetails,{{text=tr(overview.Enabled()and'Select a character.'or'Recording is off. Turn it on to update each character at login.'),height=48}},40)
    end
end
function U.OpenAccountOverview()
    U.Create();if not U.frame:IsShown()then U.frame:Show()end
    U.CloseDialogs()
    U.accountOverviewSearch:SetText('')
    if not U.accountOverviewKey then U.accountOverviewKey=Z.accountCharacterKey end
    U.RefreshAccountOverview();U.accountOverview:Show()
end
function U.CreateAccountOverview(helpers)
    H=helpers;local overview=O()
    local f=H.panel(U.frame);U.accountOverview=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,550)
    H.label(f,'Account overview',16,-18,400,'GameFontNormalLarge')
    H.label(f,'Private and local. Never shared.',330,-22,304)
    U.accountOverviewEnabled=H.checkbox(f,tr('Record own characters at login'),16,-48,300,function(self)
        local ok,why=overview.SetEnabled(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshAccountOverview()
    end)
    U.accountOverviewInventory=H.checkbox(f,tr('Record bags and opened bank'),330,-48,304,function(self)
        local ok,why=overview.SetInventory(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshAccountOverview()
    end)
    local function reset()U.RefreshAccountOverview()end
    U.accountOverviewRealm=H.selector(f,'Realm',16,-84,200,{'AO_ALL'},reset,function(v)return v=='AO_ALL'and tr('All')or(v:match('^AO_R:(.+)$')or v)end)
    U.accountOverviewFaction=H.selector(f,'Faction',226,-84,190,{'AO_ALL','AO_ALLIANCE','AO_HORDE'},reset,function(v)return tr(FACTIONS[v]or v)end)
    U.accountOverviewRealm:SetText('AO_ALL');U.accountOverviewFaction:SetText('AO_ALL')
    U.accountOverviewSearch=H.edit(f,'Item search',426,-84,208,64);U.accountOverviewSearch:SetScript('OnTextChanged',reset)
    U.accountOverviewCount=H.label(f,'',16,-138,618)
    U.accountOverviewList=H.list(f,16,-158,252,342);U.accountOverviewDetails=H.list(f,290,-158,344,342)
    H.button(f,tr('Close'),460,-512,174,function()f:Hide()end)
    H.makeModal(f);f:Hide()
end
return U
