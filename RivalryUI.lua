-- Main-window page "Rivalry" (page 13): overview of the private PvP history and the opponent list with a detail view.
-- Reads Z.Rivalry only (lists are cached per revision there). Items are built from R.List / R.Timeline when something
-- changed; the lists are virtualised, so no frame is created per opponent or event.
local Z,U=ZenialCommunity,ZenialCommunity.UI
local T,K=Z.Theme,Z.Kit
if type(T)~='table'or type(K)~='table'then return U end
local H
local PAGE,TOP,SIDE,GAP,SWITCH=13,38,300,16,110
local LIST_ROW,FACT_ROW,CARD_ROWS,CARD_ROW=44,24,5,24
local function tr(s,...)return Z.T(s,...)end
local function R()return Z.Rivalry end
local function place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y);if w then f:SetWidth(w)end;if h then f:SetHeight(h)end
end
local function sizeList(f,x,y,w,h)
    local changed=f:GetWidth()~=w or f:GetHeight()~=h
    place(f,x,y,w,h);f.width=w-24;f.height=h;f.child:SetWidth(f.width);if changed and f.zenialRender then f.zenialRender()end
end
local function when(at,withTime)
    if type(at)~='number'then return tr('Unknown')end
    if type(date)=='function'then
        local ok,text=pcall(date,withTime and'%d.%m.%Y %H:%M'or'%d.%m.%Y',at);if ok and type(text)=='string'then return text end
    end
    return Z.ScheduleTime.Format(at)
end
local function age(at)return U.Shared.age(at)end
local function nameText(row)
    local hex=row.classFile and T.ClassColorHex(row.classFile)
    return hex and('|cff'..hex..row.name..'|r')or K.Paint('text',row.name)
end
local function setClassIcon(texture,classFile)
    if texture.SetTexCoord then texture:SetTexCoord(0,1,0,1)end
    local spec=classFile and T.ClassIcon(classFile)
    if spec and T.SetTexture(texture,spec)then T.Tint(texture,'SetVertexColor','text');return end
    T.SetIcon(texture,'pvp','muted')
end
-- Badge caption with an explicit text box (K.Badge leaves a wide, left-aligned one): the caption sits in the middle of the pill.
local function setBadge(badge,value,tone)
    badge:SetTone(tone);badge:SetLabel(value)
    local width=badge.GetWidth and tonumber(badge:GetWidth())or 60
    badge.text:ClearAllPoints();badge.text:SetPoint('LEFT',0,0);badge.text:SetWidth(width);badge.text:SetJustifyH('CENTER')
    if badge.text.SetWordWrap then badge.text:SetWordWrap(false)end
end
local function rgba(key)return{T.PaletteColor(key)}end
local KIND_COLOR={K='gold',D='dangerText',A='accentBlue',W='toastText',L='warning',X='dim'}

-- Scope: the current character (nil) or every character ("ALL", only offered with a second character).
local function characters()local r=R();return r and r.Enabled()and r.Characters()or{}end
function U.RivalryScope()
    if U.rivalryScope=='ALL'and #characters()>1 then return'ALL'end
    return nil
end
local function listFilter()
    return{query=U.rivalrySearch:GetText(),mode=U.rivalryFilter:GetText(),sort=U.rivalrySort:GetText()}
end
local EMPTY={totals={kills=0,deaths=0,assists=0,duelWins=0,duelLosses=0,unknownDeaths=0,rivals=0},opponents=0,rivals={},killed={},killedBy={},recent={}}
local function overview()
    local r=R();if not(r and r.Enabled())then return EMPTY end
    return r.Overview(U.RivalryScope(),CARD_ROWS)or EMPTY
end
local function hasHistory(o)
    local t=o.totals
    return o.opponents>0 or t.kills+t.deaths+t.assists+t.duelWins+t.duelLosses>0
end
local function kdText(t)
    if t.deaths>0 then return string.format('%.2f',t.kills/t.deaths)end
    if t.kills>0 then return tostring(t.kills)end
    return'–'
end

-- Overview ---------------------------------------------------------------------------------------------------------
local CARDS={
    {key='rivals',title='Most frequent rivals',list='rivals',value=function(r)return r.kills..' : '..r.deaths end},
    {key='killed',title='Defeated most often',list='killed',value=function(r)return tostring(r.kills)end},
    {key='killedBy',title='Killed you most often',list='killedBy',value=function(r)return tostring(r.deaths)end},
    {key='recent',title='Fought most recently',list='recent',value=function(r)return age(r.last)end},
}
local TILES={
    {key='kills',label='Kills',icon='pvp',color='gold'},{key='deaths',label='Deaths',icon='warning',color='dangerText'},
    {key='assists',label='Assists',icon='members'},{key='kd',label='K/D',icon='layers'},
    {key='duels',label='Duels',icon='activities'},{key='opponents',label='Opponents',icon='characters'},
}
local function openOpponent(key)if key then U.Navigate('rivalry','rivals',key)end end
local function newCardRow(parent)
    local b=CreateFrame('Button',nil,parent);b:SetHeight(CARD_ROW)
    b.hover=b:CreateTexture(nil,'BACKGROUND');b.hover:SetAllPoints();T.Tint(b.hover,'SetColorTexture','hover');b.hover:Hide()
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(18,18);b.icon:SetPoint('LEFT',6,0)
    b.value=K.Text(b,'','body','textSoft');b.value:SetPoint('RIGHT',-8,0);b.value:SetWidth(90);b.value:SetJustifyH('RIGHT');b.value:SetHeight(14)
    b.name=K.Text(b,'','body');b.name:SetPoint('LEFT',32,0);b.name:SetPoint('RIGHT',b.value,'LEFT',-6,0);b.name:SetJustifyH('LEFT');b.name:SetHeight(14)
    for _,fs in ipairs({b.value,b.name})do if fs.SetWordWrap then fs:SetWordWrap(false)end end
    b:SetScript('OnEnter',function(self)self.hover:Show()end);b:SetScript('OnLeave',function(self)self.hover:Hide()end)
    b:SetScript('OnClick',function(self)openOpponent(self.zenialKey)end)
    return b
end
local function buildOverview(page)
    local ov=CreateFrame('Frame',nil,page);U.rivalryOverview=ov
    U.rivalryTiles={}
    for index,spec in ipairs(TILES)do
        local tile=K.StatTile(ov,{icon=spec.icon,label=tr(spec.label),value='0',height=64})
        tile.zenialSpec=spec;U.rivalryTiles[spec.key]=tile
    end
    U.rivalryTiles.opponents:SetAction(function()U.SetRivalryView('rivals')end)
    local nem=CreateFrame('Button',nil,ov);nem:SetHeight(22);U.rivalryNemesis=nem
    nem.text=K.Text(nem,'','body','textSoft');nem.text:SetPoint('LEFT',2,0);nem.text:SetPoint('RIGHT',0,0);nem.text:SetJustifyH('LEFT')
    if nem.text.SetWordWrap then nem.text:SetWordWrap(false)end
    nem:SetScript('OnClick',function(self)openOpponent(self.zenialKey)end)
    U.rivalryCards={}
    for index,spec in ipairs(CARDS)do
        local card=K.Card(ov,'surface');card.zenialSpec=spec;U.rivalryCards[index]=card
        if card.SetClipsChildren then card:SetClipsChildren(true)end
        card.header=K.SectionHeader(card,tr(spec.title));card.header:SetPoint('TOPLEFT',12,-10);card.header:SetWidth(300)
        card.rows={}
        for i=1,CARD_ROWS do
            local row=newCardRow(card);row:SetPoint('TOPLEFT',6,-(34+(i-1)*CARD_ROW));row:SetPoint('TOPRIGHT',-6,-(34+(i-1)*CARD_ROW))
            card.rows[i]=row
        end
        card.empty=K.Text(card,tr('No entries yet'),'body','dim');card.empty:SetPoint('TOPLEFT',14,-40);card.empty:SetWidth(240)
    end
    return ov
end
local fillCards
function U.LayoutRivalryOverview()
    local ov=U.rivalryOverview;if not ov then return end
    local W,Hh=ov:GetWidth(),ov:GetHeight()
    local tileWidth=math.floor((W-5*8)/6)
    for index,spec in ipairs(TILES)do place(U.rivalryTiles[spec.key],(index-1)*(tileWidth+8),0,tileWidth,64)end
    local nem=U.rivalryNemesis;local top=76
    if nem:IsShown()then place(nem,0,-top,W,22);top=top+30 end
    local changed=false
    local cardWidth=math.floor((W-GAP)/2);local cardHeight=math.max(60,math.floor((Hh-top-GAP)/2))
    local slots=math.max(1,math.min(CARD_ROWS,math.floor((cardHeight-40)/CARD_ROW)))
    for index,card in ipairs(U.rivalryCards)do
        local column,line=(index-1)%2,math.floor((index-1)/2)
        place(card,column*(cardWidth+GAP),-(top+line*(cardHeight+GAP)),cardWidth,cardHeight)
        card.header:SetWidth(cardWidth-24)
        if card.slots~=slots then card.slots=slots;if U.rivalryData then changed=true end end
    end
    if changed then fillCards(U.rivalryData)end
end
fillCards=function(o)
    for _,card in ipairs(U.rivalryCards)do
        local list=o[card.zenialSpec.list]or{}
        for i,row in ipairs(card.rows)do
            local item=i<=(card.slots or CARD_ROWS)and list[i]or nil
            if item then
                row.zenialKey=item.key;setClassIcon(row.icon,item.classFile)
                row.name:SetText(nameText(item));row.value:SetText(card.zenialSpec.value(item));row:Show()
            else row.zenialKey=nil;row:Hide()end
        end
        card.empty:SetShown(#list==0)
    end
end
function U.RefreshRivalryOverview(o)
    local t=o.totals
    local values={kills=t.kills,deaths=t.deaths,assists=t.assists,kd=kdText(t),duels=t.duelWins..' : '..t.duelLosses,opponents=o.opponents}
    for _,spec in ipairs(TILES)do U.rivalryTiles[spec.key]:SetValue(values[spec.key],spec.color)end
    local nem=U.rivalryNemesis;local n=o.nemesis
    if n then
        nem.zenialKey=n.key;nem.text:SetText(tr('Nemesis: %s has killed you %d times',nameText(n),n.deaths))
    else nem.zenialKey=nil end
    nem:SetShown(n~=nil)
    U.rivalryData=o
    U.LayoutRivalryOverview();fillCards(o)
end

-- Opponents ---------------------------------------------------------------------------------------------------------
local MODES={ALL='All',RIVALS='Rivals',KILLED='Defeated',KILLEDBY='Killed me',ASSISTS='Assists',DUELS='Duels'}
local SORTS={LAST='Last fight',FIGHTS='Most fights',KILLS='Kills',DEATHS='Deaths',NAME='Name'}
function U.SelectRivalryKey(key)
    U.rivalryKey=key;U.rivalryConfirm=false
    if key then
        U.rivalryBinding=true;U.rivalrySearch:SetText('');U.rivalryBinding=false
        U.rivalryFilter:SetText('ALL')
    end
    U.rivalrySig=nil
end
function U.RivalryCanSelect(key)
    local r=R();if not(r and r.Enabled())or type(key)~='string'then return false end
    if r.Get(U.RivalryScope(),key)then return true end
    return #characters()>1 and r.Get('ALL',key)~=nil
end
local function fact(items,label,value,valueKey)
    items[#items+1]={text=label..': '..value,display=K.Fact(label..': ',value,valueKey),flat=true,textInset=0,noWrap=true,height=FACT_ROW}
end
-- ZENIAL Watch (optional): where it sees this player right now. Any wrong answer means no row.
local WATCH_TEXT={near='Out of sight · %d s',past='Last seen · %d s',shared='Reported by the group · %d s'}
local function watchFact(name)
    local api=ZenialWatchAPI
    if type(api)~='table'or api.version~=1 or type(api.Sighting)~='function'then return nil end
    local ok,state,seconds=pcall(api.Sighting,name)
    if not ok then return nil end
    if state=='visible'then return tr('In sight'),'success'end
    if WATCH_TEXT[state]and type(seconds)=='number'and seconds>=0 and seconds<1e9 then return tr(WATCH_TEXT[state],math.floor(seconds)),'dim'end
end
-- Facts of the selected opponent; the Watch row (if any) goes first and is the only one that changes between redraws.
local function applyFacts(row)
    local items={};local text,key=watchFact(row.name)
    if text then fact(items,tr('Watch'),text,key)end
    U.rivalryWatchText=text and(text..'|'..key)or''
    for _,item in ipairs(U.rivalryFactBase)do items[#items+1]=item end
    U.rivalryFactCount=#items
    H.rows(U.rivalryFacts,items,FACT_ROW)
end
local function detailLine(row)
    local parts={}
    if row.classFile then parts[#parts+1]=Z.Locale.Class(nil,row.classFile)end
    if type(row.race)=='string'and row.race~=''then parts[#parts+1]=row.race end
    if row.level then parts[#parts+1]=tr('Level %d',row.level)end
    if row.faction then parts[#parts+1]=tr(row.faction)end
    return#parts>0 and table.concat(parts,' · ')or tr('Details unknown')
end
local function timelineItems(timeline,scope,name)
    local r,items=R(),{}
    for _,e in ipairs(timeline)do
        local head=when(e.at,true)..(e.zone~=''and(' · '..e.zone)or'')..' · '..r.EventText(e.kind,name)
        local subs={};local context=r.ContextLabel(e.context);if context~=''then subs[#subs+1]=context end
        if scope=='ALL'and type(e.character)=='string'and e.character~=''then subs[#subs+1]=e.character end
        local sub=table.concat(subs,' · ')
        items[#items+1]={text=sub~=''and(head..'\n'..sub)or head,display=K.Paint(KIND_COLOR[e.kind]or'text',head)..(sub~=''and('\n'..K.Paint('dim',sub))or''),
            flat=true,textInset=0,noWrap=true,height=sub~=''and 40 or 24}
    end
    return items
end
local function opponentItems(rows,scope)
    local items,accentRival,accentNemesis={},rgba('gold'),rgba('danger')
    for i,row in ipairs(rows)do
        local key=row.key
        local stats=tr('K %d · D %d · A %d',row.kills,row.deaths,row.assists)..(row.last and(' · '..age(row.last))or'')
        local item={text=row.name,display=nameText(row),subtitle=stats,height=LIST_ROW,selected=key==U.rivalryKey,
            icon=row.classFile and T.ClassIcon(row.classFile)or T.IconSpec('pvp'),iconColor=not row.classFile and'muted'or nil,iconSize=26,
            accent=row.nemesis and accentNemesis or row.rival and accentRival or nil,
            click=function()U.rivalryKey=key;U.rivalryConfirm=false;U.rivalrySig=nil;U.RefreshRivalryPage()end}
        items[i]=item
    end
    return items
end
function U.RefreshRivalryOpponents()
    local r=R();local scope=U.RivalryScope();local rows=r and r.Enabled()and r.List(scope,listFilter())or{}
    local unfiltered=U.rivalrySearch:GetText()==''and U.rivalryFilter:GetText()=='ALL'
    U.SetEmptyHint(U.rivalryList,unfiltered and'No PvP fights recorded yet'or nil,unfiltered and'pvp'or nil)
    local items=opponentItems(rows,scope)
    if U.rivalryScrollTo then
        for i,row in ipairs(rows)do if row.key==U.rivalryScrollTo then U.rivalryList.zenialOffset=math.max(0,(i-1)*LIST_ROW);break end end
        U.rivalryScrollTo=nil
    end
    H.rows(U.rivalryList,items,LIST_ROW)
    U.rivalryCount:SetText(tr('Opponents')..' ('..#rows..')')
    local row=U.rivalryKey and r and r.Enabled()and r.Get(scope,U.rivalryKey)
    if not row then U.rivalryKey=nil end
    U.rivalryDetailRow=row or nil
    local show=row~=nil
    for _,frame in ipairs({U.rivalryName,U.rivalryInfo,U.rivalryFacts,U.rivalryTimeline,U.rivalryRemove})do frame:SetShown(show)end
    U.rivalryHint:SetShown(not show)
    U.rivalryDiary:SetShown(false);U.rivalryCancel:SetShown(false);for _,badge in ipairs(U.rivalryBadges)do badge:Hide()end
    if not show then H.rows(U.rivalryFacts,{},FACT_ROW);H.rows(U.rivalryTimeline,{},24);U.LayoutRivalryOpponents();return end
    U.rivalryName:SetText(nameText(row));U.rivalryInfo:SetText(detailLine(row))
    local marks={};if row.rival then marks[#marks+1]={'Rival','gold'}end;if row.nemesis then marks[#marks+1]={'Nemesis','danger'}end
    for i,badge in ipairs(U.rivalryBadges)do
        local mark=marks[i]
        if mark then setBadge(badge,tr(mark[1]),mark[2]);badge:Show()end
    end
    -- Decoded once per opponent, scope and revision: a long history is not rebuilt by the minute tick.
    local cache=U.rivalryTimelineCache;local cacheKey=row.key..'|'..tostring(scope)..'|'..r.revision
    if not cache or cache.key~=cacheKey then
        local timeline=r.Timeline(scope,row.key)
        cache={key=cacheKey,timeline=timeline,items=timelineItems(timeline,scope,row.name)};U.rivalryTimelineCache=cache
    end
    local timeline=cache.timeline
    local items2={}
    fact(items2,tr('Record'),tr('Kills %d · Deaths %d · Assists %d',row.kills,row.deaths,row.assists))
    fact(items2,tr('Duels'),tr('%d won · %d lost',row.duelWins,row.duelLosses))
    fact(items2,tr('Fights in total'),tostring(row.encounters))
    fact(items2,tr('First fight'),when(row.first));fact(items2,tr('Last fight'),when(row.last))
    local places={};for _,place_ in ipairs(r.Places(timeline,3))do places[#places+1]=place_.zone..' ('..place_.count..')'end
    if#places>0 then fact(items2,tr('Places'),table.concat(places,', '))end
    local kind,count=r.Streak(timeline)
    if kind and count>=2 then fact(items2,tr('Streak'),tr(kind=='K'and'%d kills in a row'or'%d deaths in a row',count))end
    U.rivalryFactBase=items2;applyFacts(row)
    if U.rivalryTimelineKey~=row.key then
        U.rivalryTimelineKey=row.key;U.rivalryTimeline.zenialOffset=0;if U.rivalryTimeline.SetVerticalScroll then U.rivalryTimeline:SetVerticalScroll(0)end
    end
    H.rows(U.rivalryTimeline,cache.items,24)
    U.rivalryDiaryKey=r.DiaryKey(row)
    U.rivalryRemove:SetText(tr(U.rivalryConfirm and'Confirm removal'or'Remove opponent'))
    U.rivalryCancel:SetShown(U.rivalryConfirm==true);U.rivalryDiary:SetShown(U.rivalryDiaryKey~=nil and not U.rivalryConfirm)
    U.LayoutRivalryOpponents()
end
function U.LayoutRivalryOpponents()
    local op=U.rivalryOpponents;if not op then return end
    local W,Hh=op:GetWidth(),op:GetHeight();local x0=SIDE+GAP;local w=math.max(200,W-x0)
    place(U.rivalrySearch.caption,0,0,SIDE);place(U.rivalrySearch,0,-17,SIDE)
    local half=(SIDE-8)/2
    U.rivalryFilter:SetWidth(half);U.rivalrySort:SetWidth(half)
    for _,s in ipairs({U.rivalryFilter,U.rivalrySort})do
        local x=s==U.rivalryFilter and 0 or half+8
        place(s.caption,x,-48,half);place(s.button,x,-65,half)
    end
    place(U.rivalryCount,0,-98,SIDE)
    sizeList(U.rivalryList,0,-116,SIDE,math.max(80,Hh-116))
    place(U.rivalryHint,x0,-4,w)
    place(U.rivalryName,x0,0,w,22);place(U.rivalryInfo,x0,-26,w,16)
    local badgeRow=U.rivalryBadges[1]:IsShown()and 26 or 0
    local factsTop=-(48+badgeRow+4);local factsHeight=(U.rivalryFactCount or 0)*FACT_ROW+8
    sizeList(U.rivalryFacts,x0,factsTop,w,factsHeight)
    local timelineTop=factsTop-factsHeight-8;local buttonsY=-(Hh-26)
    sizeList(U.rivalryTimeline,x0,timelineTop,w,math.max(60,Hh-34+timelineTop))
    place(U.rivalryDiary,x0,buttonsY,170,26);place(U.rivalryRemove,x0+(U.rivalryDiary:IsShown()and 178 or 0),buttonsY,U.rivalryConfirm and 180 or 170,26)
    place(U.rivalryCancel,x0+(U.rivalryDiary:IsShown()and 178 or 0)+188,buttonsY,110,26)
end
local function buildOpponents(page)
    local op=CreateFrame('Frame',nil,page);U.rivalryOpponents=op
    local function reset()if U.rivalryBinding then return end;U.rivalryConfirm=false;U.rivalrySig=nil;U.RefreshRivalryPage()end
    U.rivalrySearch=H.edit(op,'Search',0,0,SIDE,64);U.rivalrySearch:SetScript('OnTextChanged',reset)
    U.rivalryFilter=H.selector(op,'Filter',0,-48,146,{'ALL','RIVALS','KILLED','KILLEDBY','ASSISTS','DUELS'},reset,function(v)return tr(MODES[v]or v)end)
    U.rivalrySort=H.selector(op,'Sort',154,-48,146,{'LAST','FIGHTS','KILLS','DEATHS','NAME'},reset,function(v)return tr(SORTS[v]or v)end)
    U.rivalryCount=H.label(op,'',0,-98,SIDE);T.Font(U.rivalryCount,'caption','dim')
    U.rivalryList=H.list(op,0,-116,SIDE,300)
    U.rivalryHint=H.label(op,tr('Select an opponent.'),SIDE+GAP,-4,400);T.Font(U.rivalryHint,'body','muted')
    U.rivalryName=K.Text(op,'','title');U.rivalryName:SetHeight(22);if U.rivalryName.SetWordWrap then U.rivalryName:SetWordWrap(false)end
    U.rivalryInfo=K.Text(op,'','body','textSoft');U.rivalryInfo:SetHeight(16);if U.rivalryInfo.SetWordWrap then U.rivalryInfo:SetWordWrap(false)end
    -- Two marks at most (rival, nemesis), placed once: the first at the left edge of the detail column, the second right of it.
    U.rivalryBadges={K.Badge(op,'','gold'),K.Badge(op,'','danger')}
    U.rivalryBadges[1]:SetPoint('TOPLEFT',SIDE+GAP,-48);U.rivalryBadges[2]:SetPoint('LEFT',U.rivalryBadges[1],'RIGHT',6,0)
    U.rivalryFacts=K.InfoBlock(H.list(op,SIDE+GAP,-72,400,150));U.rivalryTimeline=K.InfoBlock(H.list(op,SIDE+GAP,-230,400,150))
    U.rivalryDiary=H.button(op,'Social diary',SIDE+GAP,-400,170,function()
        local r=R();local row=U.rivalryDetailRow;local key=row and r.DiaryKey(row)
        if key then U.OpenSocialDiary(key,row.name)end
    end)
    -- Removing needs a second click: the button asks once, Cancel (or any other selection) takes it back.
    U.rivalryRemove=H.button(op,'Remove opponent',SIDE+GAP,-400,170,function()
        if not U.rivalryConfirm then U.rivalryConfirm=true;U.rivalrySig=nil;U.RefreshRivalryPage();return end
        local r=R();local key=U.rivalryKey;U.rivalryConfirm=false
        if key and r and r.Forget(U.RivalryScope(),key)then U.rivalryKey=nil;U.Message(tr('Opponent removed.'))end
        U.rivalrySig=nil;U.RefreshRivalryPage()
    end,'danger')
    U.rivalryCancel=H.button(op,'Cancel',SIDE+GAP,-400,110,function()U.rivalryConfirm=false;U.rivalrySig=nil;U.RefreshRivalryPage()end)
    return op
end

-- Page ---------------------------------------------------------------------------------------------------------------
function U.LayoutRivalry()
    local page=U.rivalryPage;if not page then return end
    local W,Hh=page:GetWidth(),page:GetHeight();if not(W and W>0 and Hh and Hh>0)then W,Hh=856,500 end
    local bannerButton=U.rivalryBannerSettings;local scope=U.rivalryScopeSelector
    place(U.rivalryTabs,0,0)
    place(bannerButton,W-150,0,150,26)
    scope:SetWidth(170);place(scope.button,W-150-8-170,0,170,26)
    for _,frame in ipairs({U.rivalryOverview,U.rivalryOpponents})do place(frame,0,-TOP,W,Hh-TOP)end
    place(U.rivalryEmpty,math.floor((W-520)/2),-(TOP+120),520)
    U.LayoutRivalryOverview();U.LayoutRivalryOpponents()
end
function U.SetRivalryView(view,key)
    if not U.rivalryPage then return end
    view=view=='rivals'and'rivals'or'overview'
    U.rivalryView=view
    if key then
        if not R().Get(U.RivalryScope(),key)and#characters()>1 and R().Get('ALL',key)then
            U.rivalryScope='ALL';U.rivalryScopeSelector:SetText('ALL')
        end
        U.SelectRivalryKey(key);U.rivalryScrollTo=key
    end
    U.rivalryTabs:Select(view)
    if Z.UIState then Z.UIState.Route('rivalry',view)end
    U.rivalrySig=nil;U.RefreshRivalryPage()
end
-- Draws the page now (no check whether it is the visible one).
function U.RefreshRivalryPage()
    local page=U.rivalryPage;if not page then return end
    local r=R();local chars=characters();local multi=#chars>1
    if not multi then U.rivalryScope=nil;U.rivalryScopeSelector:SetText('CURRENT')end
    local o=overview();local filled=hasHistory(o)
    local signature=table.concat({r and r.revision or 0,tostring(U.RivalryScope()),U.rivalryView,U.rivalrySearch:GetText(),U.rivalryFilter:GetText(),
        U.rivalrySort:GetText(),tostring(U.rivalryKey),tostring(U.rivalryConfirm),math.floor(Z.Adapter.Now()/60),tostring(r and r.readOnly),#chars,tostring(filled)},'|')
    if signature==U.rivalrySig then return end
    U.rivalrySig=signature
    U.rivalryScopeSelector.button:SetShown(multi);if not multi then U.rivalryScopeSelector.popup:Hide()end
    local readOnly=r and r.readOnly==true
    U.rivalryOverview:SetShown(filled and U.rivalryView=='overview')
    U.rivalryOpponents:SetShown(filled and U.rivalryView=='rivals')
    U.rivalryEmpty:SetShown(not filled)
    if not filled then
        U.rivalryEmpty:SetState(tr(readOnly and'This history was saved by a newer addon version.'or'No PvP fights recorded yet'),
            readOnly and''or tr('Kills, deaths, assists and duels are recorded automatically.'),'pvp')
    end
    U.LayoutRivalry()
    if filled and U.rivalryView=='overview'then U.RefreshRivalryOverview(o)
    elseif filled then U.RefreshRivalryOpponents()end
end
-- Once per second from the UI tick (U.RefreshTimed): only the Watch row follows Watch; list and timeline stay untouched.
function U.TickRivalryWatch(clock)
    local row=U.rivalryDetailRow
    if U.page~=PAGE or not row or not U.rivalryKey or not U.rivalryFactBase or not U.rivalryOpponents or not U.rivalryOpponents:IsShown()then return end
    if clock<(U.nextRivalryWatch or 0)then return end
    U.nextRivalryWatch=clock+1
    local text,key=watchFact(row.name)
    if(text and(text..'|'..key)or'')==U.rivalryWatchText then return end
    applyFacts(row);U.LayoutRivalryOpponents()
end
-- Called by the core after every recorded event: does nothing unless the page is on screen.
function U.RefreshRivalry()
    if not U.rivalryPage or not U.frame or not U.frame:IsShown()or U.page~=PAGE then return end
    U.RefreshRivalryPage()
end
function U.OpenRivalry(view,key)
    U.Create();if not U.frame:IsShown()then U.frame:Show()end
    return U.Navigate('rivalry',view=='rivals'and'rivals'or'overview',key)
end
function U.CreateRivalry(helpers)
    H=helpers;local page=U.pages and U.pages[PAGE];if not page then return end
    U.rivalryPage=page;page.zenialOwnLayout=true
    local state=Z.uiCharacter;local saved=state and state.subviews and state.subviews.rivalry
    U.rivalryView=saved=='rivals'and'rivals'or'overview'
    U.rivalryTabs=K.Segmented(page,{{key='overview',label=tr('Overview')},{key='rivals',label=tr('Opponents')}},function(key)U.SetRivalryView(key)end)
    U.rivalryTabs:SetSegmentWidth(SWITCH);U.rivalryTabs:Select(U.rivalryView)
    U.rivalryScopeSelector=H.selector(page,'',0,0,170,{'CURRENT','ALL'},function(value)
        U.rivalryScope=value=='ALL'and'ALL'or nil;U.rivalryConfirm=false;U.rivalrySig=nil;U.RefreshRivalryPage()
    end,function(v)return tr(v=='ALL'and'All characters'or'This character')end)
    U.rivalryScopeSelector.caption:Hide();U.rivalryScopeSelector:SetText('CURRENT')
    U.rivalryBannerSettings=H.button(page,'Banner settings',0,0,150,function()U.Navigate('settings','rivalry')end,'secondary')
    buildOverview(page);buildOpponents(page)
    U.rivalryEmpty=K.EmptyState(page,{icon='pvp',title='',hint='',width=520})
    U.LayoutRivalry()
    U.rivalryOverview:Hide();U.rivalryOpponents:Hide();U.rivalryEmpty:Hide()
end
return U
