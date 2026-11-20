-- "My characters": Overview tab. One calm card per character in a scrolling grid (pooled, only the visible
-- card rows exist) and the character details page that a card opens. Reads the local AccountOverview read model
-- only; main changes, hiding and deletion are the shell's handlers (AccountOverviewUI.lua).
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local L,T=Z.Logic,Z.Theme
local function tr(s,...)return Z.T(s,...)end
local function O()return Z.AccountOverview end
local function K()return Z.Kit end
local H=U.MyCharactersUI

local CARD_HEIGHT,GAP,GUTTER,MIN_CARD,MAX_COLUMNS=196,12,18,280,3
local PAD=12
local ICON_SIZE=38
local DETAIL_TOP=88

local G={cards={},rows={},models={}}   -- grid state
local D={}                              -- details state
G.details=D
U.MyCharactersCards=G

local function age(t)return U.Shared.age(t)end
local function metaLine(r)
    local parts={}
    local class=H.className(r);if class~=''then parts[#parts+1]=class end
    if r.realm~=''then parts[#parts+1]=r.realm end
    if r.faction~=''then parts[#parts+1]=tr(r.faction)end
    return table.concat(parts,' · ')
end
local function seenAt(r)return math.max(r.updatedAt or 0,r.lastLogin or 0)end

-- ---------------------------------------------------------------------------------------------
-- Scroll area (same pattern as the finder grid): own surfaces, no sunken well.
-- ---------------------------------------------------------------------------------------------
local function createScroll(parent)
    local scroll=CreateFrame('ScrollFrame',nil,parent,'UIPanelScrollFrameTemplate')
    local child=CreateFrame('Frame',nil,scroll)
    child:SetSize(100,1)
    scroll:SetScrollChild(child)
    scroll.child=child
    T.StyleScroll(scroll);T.AttachScrollWheel(scroll,64)
    if scroll.zenialTrack then scroll.zenialTrack:Hide()end
    function scroll:Fit(width,height,contentHeight)
        self:SetSize(width,height)
        self.width,self.height=width-GUTTER,height
        self.child:SetWidth(math.max(1,width-GUTTER))
        self.child:SetHeight(math.max(1,contentHeight))
        if contentHeight<=height and(self.zenialOffset or 0)~=0 then
            self.zenialOffset=0;self:SetVerticalScroll(0)
        end
        T.UpdateScroll(self)
    end
    return scroll
end
-- Calls render after every scroll step (wheel, bar, programmatic).
local function bindScroll(scroll,render)
    scroll.zenialRender=render
    scroll:SetScript('OnVerticalScroll',function(self,offset)
        if self.zenialRendering then return end
        self.zenialOffset=offset
        render()
    end)
    if scroll.HookScript then
        scroll:HookScript('OnMouseWheel',function(self)
            self.zenialOffset=self.GetVerticalScroll and self:GetVerticalScroll()or 0
            render()
        end)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Card
-- ---------------------------------------------------------------------------------------------
local function createCard(parent)
    local kit=K()
    local card=kit.Card(parent,'raised')
    card:SetSize(MIN_CARD,CARD_HEIGHT);card:EnableMouse(true)
    card.accent=card:CreateTexture(nil,'OVERLAY')
    card.accent:SetPoint('TOPLEFT',1,-1);card.accent:SetPoint('TOPRIGHT',-1,-1);card.accent:SetHeight(2)
    -- Class icon in a thin frame of the class colour.
    card.iconFrame=CreateFrame('Frame',nil,card);card.iconFrame:SetSize(ICON_SIZE,ICON_SIZE)
    card.iconBack=card.iconFrame:CreateTexture(nil,'BACKGROUND');card.iconBack:SetAllPoints()
    T.Tint(card.iconBack,'SetColorTexture','inset')
    card.iconEdges=T.Edges(card.iconFrame,'BORDER')
    card.icon=card.iconFrame:CreateTexture(nil,'ARTWORK')
    card.icon:SetPoint('TOPLEFT',2,-2);card.icon:SetPoint('BOTTOMRIGHT',-2,2)
    card.name=kit.Text(card,'','heading','text');card.name:SetWordWrap(false);card.name:SetJustifyH('LEFT');card.name:SetHeight(16)
    card.meta=kit.Text(card,'','caption','dim');card.meta:SetWordWrap(false);card.meta:SetJustifyH('LEFT');card.meta:SetHeight(14)
    card.level=kit.Badge(card,'','neutral')
    card.badges={kit.Badge(card,'','gold'),kit.Badge(card,'','info'),kit.Badge(card,'','neutral')}
    card.rule=card:CreateTexture(nil,'ARTWORK');card.rule:SetHeight(1);T.Tint(card.rule,'SetColorTexture','lineSoft')
    card.professions={}
    for index=1,2 do
        local row={name=kit.Text(card,'','body','text'),rank=kit.Text(card,'','caption','textSoft'),bar=kit.ProgressBar(card,{width=100,height=4,tone='gold'})}
        row.name:SetWordWrap(false);row.name:SetJustifyH('LEFT');row.name:SetHeight(14)
        row.rank:SetWordWrap(false);row.rank:SetJustifyH('RIGHT');row.rank:SetHeight(14)
        card.professions[index]=row
    end
    card.secondary=kit.Text(card,'','caption','dim');card.secondary:SetWordWrap(false);card.secondary:SetJustifyH('LEFT');card.secondary:SetHeight(14)
    card.noProfessions=kit.Text(card,tr('No professions recorded'),'caption','dim');card.noProfessions:SetWordWrap(false);card.noProfessions:SetJustifyH('LEFT');card.noProfessions:SetHeight(14)
    card.footerRule=card:CreateTexture(nil,'ARTWORK');card.footerRule:SetHeight(1);T.Tint(card.footerRule,'SetColorTexture','lineSoft')
    card.footer=kit.Text(card,'','caption','dim');card.footer:SetWordWrap(false);card.footer:SetJustifyH('LEFT');card.footer:SetHeight(14)
    card.details=T.Button(card,tr('Details'),70,24,function(self)
        local parentCard=self:GetParent();if parentCard.row then H.showDetail(parentCard.row.key)end
    end,'ghost')
    card.details:SetWidth(math.max(70,H.buttonTextWidth(card.details)+24))
    card:SetScript('OnMouseUp',function(self,button)
        if button=='LeftButton'and self.row then H.showDetail(self.row.key)end
    end)
    card:SetScript('OnEnter',function(self)
        T.Tint(self,'SetBackdropBorderColor','goldDim')
        local r=self.row
        if not r or not GameTooltip or not GameTooltip.SetOwner then return end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(r.name,1,.85,.42)
        local meta=metaLine(r);if meta~=''then GameTooltip:AddLine(meta,.78,.8,.85,true)end
        GameTooltip:Show()
    end)
    card:SetScript('OnLeave',function(self)
        T.Tint(self,'SetBackdropBorderColor',self.edgeKey or'highlight')
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide()end
    end)
    return card
end

-- Badge caption in the middle of the pill: an explicit text box (K.Badge leaves a wide, left-aligned one).
local function setBadge(badge,value,tone)
    if tone then badge:SetTone(tone)end
    badge:SetLabel(value)
    local width=tonumber(badge:GetWidth())or 60
    badge.text:ClearAllPoints();badge.text:SetPoint('LEFT',0,0);badge.text:SetWidth(width);badge.text:SetJustifyH('CENTER')
    if badge.text.SetWordWrap then badge.text:SetWordWrap(false)end
end
local function at(region,card,x,y,w)
    region:ClearAllPoints();region:SetPoint('TOPLEFT',card,'TOPLEFT',x,-y)
    if w then region:SetWidth(w)end
end
local function updateCard(card,r,cw)
    card.row=r
    card:SetSize(cw,CARD_HEIGHT)
    card.edgeKey=r.current and'goldDim'or'highlight'
    T.Tint(card,'SetBackdropBorderColor',card.edgeKey)
    card:SetAlpha(r.hidden and .7 or 1)
    -- Class colour only as a thin top accent and the icon frame (muted).
    local cr,cg,cb=T.ClassColor(r.classFile,r.className)
    if cr then
        card.accent:SetColorTexture(cr,cg,cb,.6)
        for _,edge in pairs(card.iconEdges)do edge:SetColorTexture(cr,cg,cb,.55)end
    else
        T.Tint(card.accent,'SetColorTexture','line');T.TintEdges(card.iconEdges,'line')
    end
    T.SetTexture(card.icon,H.classIcon(r))
    at(card.iconFrame,card,PAD,14)
    -- Head: level badge right, name and class line left of it.
    setBadge(card.level,r.level and(tr('Level')..' '..r.level)or(tr('Level')..' ?'))
    at(card.level,card,cw-PAD-card.level:GetWidth(),12)
    local nameX=PAD+ICON_SIZE+10
    card.name:SetText(r.name);T.Font(card.name,'heading',r.hidden and'dim'or'text')
    at(card.name,card,nameX,12,math.max(40,cw-nameX-PAD-card.level:GetWidth()-8))
    card.meta:SetText(metaLine(r));at(card.meta,card,nameX,31,math.max(40,cw-nameX-PAD))
    -- Role and state badges, as many as fit.
    local labels={}
    if r.utilityOnly then labels[#labels+1]={tr('From ZENIAL Utility'),'neutral'}
    elseif r.role=='main'then labels[#labels+1]={tr('Main'),'gold'}
    elseif r.role=='alt'then labels[#labels+1]={tr('Alt'),'info'}end
    if r.current then labels[#labels+1]={tr('Logged in'),'success'}end
    if r.hidden then labels[#labels+1]={tr('hidden'),'neutral'}end
    local x=PAD
    for index,badge in ipairs(card.badges)do
        local spec=labels[index]
        if spec then
            setBadge(badge,spec[1],spec[2])
            if x+badge:GetWidth()<=cw-PAD then at(badge,card,x,56);badge:Show();x=x+badge:GetWidth()+6 else badge:Hide()end
        else badge:Hide()end
    end
    at(card.rule,card,PAD,80,cw-2*PAD)
    -- Professions: primary with rank and bar, secondary in one dim line.
    local y=88
    local primary,secondary=r.primary or{},r.secondary or{}
    for index,row in ipairs(card.professions)do
        local p=primary[index]
        if p then
            row.name:SetText(tr(L.ProfessionName(p.name)));row.rank:SetText(p.rank..(p.max and('/'..p.max)or''))
            local rankWidth=math.max(30,math.ceil(row.rank:GetStringWidth())+4)
            at(row.name,card,PAD,y,cw-2*PAD-rankWidth-8);at(row.rank,card,cw-PAD-rankWidth,y,rankWidth)
            row.bar:SetBarWidth(cw-2*PAD);row.bar:SetValue(p.rank,p.max);at(row.bar,card,PAD,y+16)
            row.name:Show();row.rank:Show();row.bar:Show();y=y+26
        else row.name:Hide();row.rank:Hide();row.bar:Hide()end
    end
    local line={}
    for _,p in ipairs(secondary)do line[#line+1]=tr(L.ProfessionName(p.name))..' '..p.rank end
    card.secondary:SetText(table.concat(line,' · '))
    card.secondary:SetShown(#line>0);if #line>0 then at(card.secondary,card,PAD,y,cw-2*PAD)end
    card.noProfessions:SetShown(#primary==0 and #line==0);at(card.noProfessions,card,PAD,88,cw-2*PAD)
    -- Footer: gold and last seen left, details right.
    at(card.footerRule,card,PAD,160,cw-2*PAD)
    local text={}
    if r.money then text[#text+1]=A.MoneyText(r.money)end
    local seen=seenAt(r);text[#text+1]=seen>0 and age(seen)or tr('never')
    card.footer:SetText(table.concat(text,' · '))
    local buttonWidth=card.details:GetWidth()
    at(card.footer,card,PAD,172,math.max(40,cw-2*PAD-buttonWidth-8))
    card.details:ClearAllPoints();card.details:SetPoint('TOPLEFT',card,'TOPLEFT',cw-8-buttonWidth,-166)
end

local function cardModel(r)
    local words={r.name}
    local badge=H.badge(r);if badge then words[#words+1]=H.plain(badge)end
    if r.current then words[#words+1]=tr('Logged in')end
    local subtitle=metaLine(r);if r.hidden then subtitle=subtitle..(subtitle~=''and' · 'or'')..tr('hidden')end
    return{key=r.key,text=table.concat(words,' · '),subtitle=subtitle,hidden=r.hidden==true,row=r,click=function()H.showDetail(r.key)end}
end

-- Draws only the card rows around the scroll position; cards are reused.
local function renderGrid()
    local view=G.view
    if not view or view.zenialRendering then return end
    view.zenialRendering=true
    local rows=G.rows
    local width,height=view:GetWidth(),view:GetHeight()
    local columns,cardWidth=K().Columns(math.max(1,width-GUTTER),MIN_CARD,GAP,MAX_COLUMNS)
    local rowHeight=CARD_HEIGHT+GAP
    local total=math.ceil(#rows/columns)
    view:Fit(width,height,math.max(1,total*rowHeight-GAP))
    local maximum=math.max(0,total*rowHeight-GAP-height)
    local offset=math.max(0,math.min(tonumber(view.zenialOffset)or view:GetVerticalScroll()or 0,maximum))
    local visibleRows=math.ceil(height/rowHeight)+1
    local first=math.max(0,math.min(math.floor(offset/rowHeight),math.max(0,total-1)))
    local last=math.min(total-1,first+visibleRows)
    local count=0
    for row=first,last do
        for column=0,columns-1 do
            local index=row*columns+column+1
            local r=rows[index]
            if r then
                count=count+1
                local card=G.cards[count]
                if not card then card=createCard(view.child);G.cards[count]=card end
                card:ClearAllPoints();card:SetPoint('TOPLEFT',view.child,'TOPLEFT',column*(cardWidth+GAP),-row*rowHeight)
                updateCard(card,r,cardWidth);card:Show()
            end
        end
    end
    for index=count+1,#G.cards do G.cards[index]:Hide()end
    view.zenialCardCount,view.zenialColumns,view.zenialCardWidth=count,columns,cardWidth
    view.zenialRendering=false
end

-- ---------------------------------------------------------------------------------------------
-- Details
-- ---------------------------------------------------------------------------------------------
local function restedPercent(r)
    if not r.rested or not r.xpMax or r.xpMax<=0 then return nil end
    return math.floor(r.rested*100/r.xpMax+.5)
end
local function header(r)
    local b=H.badge(r,true)
    local line=H.paint('goldBright',r.name)..(b and('  '..b)or'')..(r.current and('  '..H.paint('textSoft','· '..tr('Logged in')))or'')
    local info={}
    local class=H.className(r);if class~=''then info[#info+1]=class end
    info[#info+1]=tr('Level')..' '..(r.level or tr('Unknown'))
    local ruleset=r.realm~=''and O().Ruleset(r.realm)
    if r.realm~=''then info[#info+1]=r.realm..(ruleset and(' ('..tr(ruleset)..')')or'')end
    if r.faction~=''then info[#info+1]=tr(r.faction)end
    return line..'\n'..H.paint('textSoft',table.concat(info,' · '))
end
local function roleText(r)
    if r.utilityOnly then return nil end
    if not r.sameScope then return tr('Main and alts are set in the game world and faction you are logged in to. Log in there to change this character.')end
    if r.role=='main'then return tr('Main of this game world and faction. Without your own choice the first character saved with ZENIAL becomes main; you can change it on any alt.')end
    if r.role=='alt'then return tr('Alt of %s. Other members see this link only while your profile is visible.',r.mainName or tr('Unknown'))end
end

local function newPool(create)return{items={},used=0,create=create}end
local function take(pool,parent)
    pool.used=pool.used+1
    local item=pool.items[pool.used]
    if not item then item=pool.create(parent);pool.items[pool.used]=item end
    item:Show();return item
end
local function finishPool(pool)for index=pool.used+1,#pool.items do pool.items[index]:Hide()end end
local function createText(parent)
    local fs=K().Text(parent,'','body','text');fs:SetJustifyH('LEFT');return fs
end
local function createLinkRow(parent)
    local row=CreateFrame('Button',nil,parent)
    row.hover=row:CreateTexture(nil,'HIGHLIGHT');row.hover:SetAllPoints();T.Tint(row.hover,'SetColorTexture','hover')
    row.label=K().Text(row,'','body','text');row.label:SetWordWrap(false);row.label:SetJustifyH('LEFT');row.label:SetHeight(14)
    row.value=K().Text(row,'','caption','dim');row.value:SetWordWrap(false);row.value:SetJustifyH('RIGHT');row.value:SetHeight(14)
    row.chevron=K().Icon(row,'chevronRight',10,'muted')
    row.bar=K().ProgressBar(row,{width=100,height=4,tone='info'})
    return row
end

local function put(region,x,y,w,h)
    region:ClearAllPoints();region:SetPoint('TOPLEFT',D.child,'TOPLEFT',x,-y)
    if w then region:SetWidth(w)end
    if h then region:SetHeight(h)end
end
local function mirror(head,value)
    D.mirror[#D.mirror+1]={text=(head and(head..': ')or'')..H.plain(value or''),flat=true,section=head~=nil or nil}
end
local function sectionHead(x,y,w,title)
    local head=take(D.heads,D.child);head:SetText(title);put(head,x,y,w,16)
    head:SetPoint('TOPRIGHT',D.child,'TOPLEFT',x+w,-y)
    -- The rule runs from the label to the count; its width is set as well, so it also ends inside the column
    -- where only the first anchor is read.
    head.line:SetWidth(math.max(1,w-head.label:GetWidth()-head.count:GetWidth()-20))
    return 22
end
local function textBlock(x,y,w,value,role,colorKey)
    local fs=take(D.texts,D.child)
    fs:SetWordWrap(true);T.Font(fs,role or'body',colorKey or'text');fs:SetJustifyH('LEFT')
    fs:SetWidth(w);fs:SetText(value)
    local height=math.max(14,math.ceil(fs:GetStringHeight()))
    put(fs,x,y,w,height);return height
end
-- One line: label left, value right-aligned; optional bar below.
local function valueLine(x,y,w,labelText,valueText,cur,max,tone)
    local label=take(D.texts,D.child);label:SetWordWrap(false);T.Font(label,'body','text');label:SetJustifyH('LEFT')
    local value=take(D.texts,D.child);value:SetWordWrap(false);T.Font(value,'caption','textSoft');value:SetJustifyH('RIGHT')
    label:SetText(labelText);value:SetText(valueText or'')
    local valueWidth=math.min(math.floor(w*.6),math.max(20,math.ceil(value:GetStringWidth())+4))
    put(label,x,y,w-valueWidth-8,14);put(value,x+w-valueWidth,y,valueWidth,14)
    if max then
        local bar=take(D.bars,D.child);bar:SetTone(tone or'gold');bar:SetBarWidth(w);bar:SetValue(cur,max);put(bar,x,y+18,nil,6)
        return 32
    end
    return 22
end
local function linkRow(x,y,w,labelText,valueText,click,cur,max)
    local row=take(D.rows,D.child)
    local height=max and 38 or 24
    row:SetSize(w,height);put(row,x,y)
    row.label:SetText(labelText);row.value:SetText(valueText or'')
    local valueWidth=math.min(math.floor(w*.62),math.max(20,math.ceil(row.value:GetStringWidth())+4))
    row.chevron:ClearAllPoints();row.chevron:SetPoint('TOPLEFT',row,'TOPLEFT',w-12,-2)
    row.value:ClearAllPoints();row.value:SetPoint('TOPLEFT',row,'TOPLEFT',w-18-valueWidth,0);row.value:SetWidth(valueWidth)
    row.label:ClearAllPoints();row.label:SetPoint('TOPLEFT',row,'TOPLEFT',0,0);row.label:SetWidth(math.max(20,w-valueWidth-26))
    row.bar:SetShown(max~=nil)
    if max then row.bar:SetBarWidth(w);row.bar:SetValue(cur,max);row.bar:ClearAllPoints();row.bar:SetPoint('TOPLEFT',row,'TOPLEFT',0,-20)end
    row:SetScript('OnClick',click or function()end);row:EnableMouse(click~=nil);row.chevron:SetShown(click~=nil)
    return height+4
end

local function statusText(state)
    if state=='complete'then return tr('Complete')elseif state=='partial'then return tr('Partial')end
    return tr('Unknown')
end
local function recipeFacts(r,profession)
    local R=Z.AccountRecipes
    local count,state
    if R and R.Counts then local counts=R.Counts(r.key)or{};count=counts[profession.name]end
    if R and R.Coverage then state=R.Coverage(r.key,profession.name)end
    local entry=r.recipeStates and r.recipeStates[profession.name]
    if entry then
        count=count or entry.count
        if not state then state=entry.complete and'complete'or(entry.count and entry.count>0)and'partial'or nil end
    end
    return count,state or'unknown'
end

local function goldSection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('Gold'))
        local value=r.money and A.MoneyText(r.money)or tr('Unknown')
        used=used+textBlock(x,y+used,w,value,'heading','text')
        if r.money then used=used+2+textBlock(x,y+used+2,w,tr('as of %s',H.when(r.moneyAt)),'caption','dim')end
        mirror(tr('Gold'),r.money and(A.MoneyText(r.money)..' · '..tr('as of %s',H.when(r.moneyAt)))or tr('Unknown'))
        return used
    end
end
local function xpSection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('XP'))
        local words={}
        if r.maxLevel then
            used=used+textBlock(x,y+used,w,tr('Maximum level'),'body','text');words[#words+1]=tr('Maximum level')
        elseif r.xp and r.xpMax then
            local percent=r.xpMax>0 and math.floor(r.xp*100/r.xpMax)or 0
            local value=r.xp..' / '..r.xpMax..' ('..percent..'%)'
            used=used+valueLine(x,y+used,w,tr('Level')..' '..(r.level or'?'),value,r.xp,r.xpMax,'gold')+4;words[#words+1]=value
        else
            used=used+textBlock(x,y+used,w,tr('Unknown'),'body','text');words[#words+1]=tr('Unknown')
        end
        local percent=restedPercent(r)
        if not r.maxLevel and percent then
            local value=tr('%d%% of a level',percent)
            used=used+valueLine(x,y+used,w,tr('Rested XP'),value,r.rested,r.xpMax,'info')
            local note=(r.resting and(tr('Resting')..' · ')or'')..tr('as of %s',H.when(r.restedAt))
            used=used+textBlock(x,y+used,w,note,'caption','dim');words[#words+1]=value..' · '..note
        end
        mirror(tr('XP'),table.concat(words,' · '))
        return used
    end
end
local function playedSection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('Played time'))
        local value=r.played and H.duration(r.played)or tr('Unknown')
        used=used+textBlock(x,y+used,w,value,'body','text')
        if r.played then used=used+2+textBlock(x,y+used+2,w,tr('as of %s',H.when(r.playedAt)),'caption','dim')end
        mirror(tr('Played time'),r.played and(value..' · '..tr('as of %s',H.when(r.playedAt)))or value)
        return used
    end
end
local function professionsSection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('Professions'))
        local primary,secondary=r.primary or{},r.secondary or{}
        local words={}
        if #primary==0 and #secondary==0 then
            used=used+textBlock(x,y+used,w,tr('None recorded'),'body','text');words[#words+1]=tr('None recorded')
        end
        local function list(profs,title,tone)
            if #profs==0 then return end
            used=used+textBlock(x,y+used,w,title,'caption','dim')+2
            for _,p in ipairs(profs)do
                local name=tr(L.ProfessionName(p.name));local value=p.rank..(p.max and('/'..p.max)or'')
                used=used+valueLine(x,y+used,w,name,value,p.rank,p.max,tone)+4;words[#words+1]=name..' '..value
            end
        end
        list(primary,tr('Primary professions'),'gold');list(secondary,tr('Secondary professions'),'dim')
        if r.professionsAt then used=used+textBlock(x,y+used,w,tr('as of %s',H.when(r.professionsAt)),'caption','dim')end
        mirror(tr('Professions'),table.concat(words,', '))
        return used
    end
end
local function recipesSection(r)
    return function(x,y,w)
        local professions={}
        for _,p in ipairs(r.primary or{})do professions[#professions+1]=p end
        for _,p in ipairs(r.secondary or{})do professions[#professions+1]=p end
        if #professions==0 then return 0 end
        local used=sectionHead(x,y,w,tr('Recipes'))
        local words={}
        for _,p in ipairs(professions)do
            local count,state=recipeFacts(r,p)
            local countText=count and(count==1 and tr('1 recipe')or tr('%d recipes',count))
            local value=countText and(countText..' · '..statusText(state))or tr('Unknown')
            local name=tr(L.ProfessionName(p.name))
            used=used+linkRow(x,y+used,w,name,value,function()U.OpenMyCharactersRecipes({characterKey=r.key,profession=p.name})end)
            words[#words+1]=name..' '..value
        end
        mirror(tr('Recipes'),table.concat(words,', '))
        return used
    end
end
local function placeFacts(area,label,r)
    local inv=r.inventory and r.inventory[area]
    if not inv or not inv.known then
        return tr('Not recorded')
    end
    local at=inv.at and(' · '..tr('as of %s',H.when(inv.at)))or''
    if inv.total then return tr('%d of %d slots used',inv.used,inv.total)..at end
    local count=0;for _,n in pairs(inv.counts or{})do count=count+n end
    return tr('%d items',count)..at
end
local function inventorySection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('Bags and bank'))
        local words={}
        for _,area in ipairs({'bags','bank'})do
            local inv=r.inventory and r.inventory[area]
            local name=area=='bags'and tr('Bags')or tr('Bank')
            local value=placeFacts(area,name,r)
            used=used+linkRow(x,y+used,w,name,value,function()U.OpenMyCharactersInventory({characterKey=r.key})end,inv and inv.total and inv.used or nil,inv and inv.total or nil)
            words[#words+1]=name..' '..value
        end
        if not(r.inventory and r.inventory.bank and r.inventory.bank.known)then
            used=used+textBlock(x,y+used,w,tr('Bank never opened while recording.'),'caption','dim')
        end
        mirror(tr('Bags and bank'),table.concat(words,', '))
        return used
    end
end
local function dataSection(r)
    return function(x,y,w)
        local used=sectionHead(x,y,w,tr('Data'))
        local lines={tr('Last login')..': '..H.when(r.lastLogin)}
        if r.updatedAt then lines[#lines+1]=tr('Last updated')..': '..H.when(r.updatedAt)end
        if r.moneyFromUtility or r.levelFromUtility or r.classFromUtility then
            local fields={}
            if r.moneyFromUtility then fields[#fields+1]=tr('Gold')end
            if r.levelFromUtility then fields[#fields+1]=tr('Level')end
            if r.classFromUtility then fields[#fields+1]=tr('Class')end
            if r.importedAt then lines[#lines+1]=tr('From ZENIAL Utility')..': '..table.concat(fields,', ')..' · '..tr('taken over %s',H.when(r.importedAt))end
        end
        for _,line in ipairs(lines)do used=used+textBlock(x,y+used,w,line,'caption','dim')+2 end
        mirror(tr('Data'),table.concat(lines,' · '))
        return used
    end
end

local function buildDetail(r)
    local kit=K()
    if not D.scroll then return end
    D.mirror={}
    for _,pool in ipairs({D.heads,D.texts,D.bars,D.rows})do pool.used=0 end
    local scroll=D.scroll
    local width=math.max(200,scroll.width or 400)
    local columns,columnWidth=kit.Columns(width,320,18,2)
    local y=0
    -- Notes spanning the full width.
    local notes={}
    local role=roleText(r);if role then notes[#notes+1]=role end
    if r.hidden then notes[#notes+1]=tr('Hidden from this overview. Its data is kept; show hidden characters to see it again.')end
    if r.utilityOnly then notes[#notes+1]=tr('Only known from the data taken over from ZENIAL Utility. Log in with this character to record more.')end
    for _,note in ipairs(notes)do y=y+textBlock(0,y,width,note,'caption','dim')+6;mirror(nil,note)end
    local sections={}
    if r.utilityOnly then
        sections={{1,goldSection(r)},{1,dataSection(r)}}
    else
        sections={{1,goldSection(r)},{1,xpSection(r)},{1,playedSection(r)},{2,professionsSection(r)},{2,recipesSection(r)},{2,inventorySection(r)},{1,dataSection(r)}}
    end
    if columns==1 then
        for _,section in ipairs(sections)do
            local used=section[2](0,y,width);if used>0 then y=y+used+16 end
        end
    else
        local base=y;local ys={base,base}
        for _,section in ipairs(sections)do
            local column=section[1]
            local used=section[2]((column-1)*(columnWidth+18),ys[column],columnWidth);if used>0 then ys[column]=ys[column]+used+16 end
        end
        y=math.max(ys[1],ys[2])
    end
    for _,pool in ipairs({D.heads,D.texts,D.bars,D.rows})do finishPool(pool)end
    scroll.child:SetHeight(math.max(1,y))
    if D.key~=r.key then D.key=r.key;scroll.zenialOffset=0;scroll:SetVerticalScroll(0)end
    T.UpdateScroll(scroll)
    scroll.zenialItems=D.mirror
end

-- ---------------------------------------------------------------------------------------------
-- Tab
-- ---------------------------------------------------------------------------------------------
local function emptyHint(context)
    if context.query~=''then return tr('No character matches this search.')end
    if context.hidden>0 then return tr('All matching characters are hidden. Turn on "Show hidden" to see them.')end
    if context.filtered then return tr('No character for this realm and faction.')end
    return tr('No characters recorded yet.')
end

local function create(body)
    local kit=K()
    G.body=body
    G.view=createScroll(body);G.view:SetPoint('TOPLEFT',body,'TOPLEFT',0,0)
    bindScroll(G.view,renderGrid)
    U.characterCards=G.view
    G.empty=kit.EmptyState(body,{icon='characters',title='',width=520});G.empty:Hide()
    D.scroll=createScroll(body);D.scroll:SetPoint('TOPLEFT',body,'TOPLEFT',0,-DETAIL_TOP)
    D.child=D.scroll.child
    D.heads=newPool(function(parent)return kit.SectionHeader(parent,'')end)
    D.texts=newPool(createText)
    D.bars=newPool(function(parent)return kit.ProgressBar(parent,{width=100,height=6,tone='gold'})end)
    D.rows=newPool(createLinkRow)
    D.scroll:Hide()
    U.accountOverviewDetails=D.scroll
    D.scroll.zenialItems={}
end

local function refresh(rows,context)
    G.rows=rows;G.context=context
    local models={}
    for index,r in ipairs(rows)do models[index]=cardModel(r)end
    G.models=models
    G.view.zenialItems=models
    G.view.zenialEmptyHint=#rows==0 and emptyHint(context)or nil
    local selected=U.myCharactersSelected
    if U.myCharactersDetailOpen and selected then
        U.myCharactersHeader:SetText(header(selected))
        if U.myCharactersIcon then T.SetTexture(U.myCharactersIcon,H.classIcon(selected))end
    end
end

local function layout(x,y,w,h)
    local selected=U.myCharactersDetailOpen and U.myCharactersSelected or nil
    local view=G.view
    view:SetShown(selected==nil and #G.rows>0)
    G.empty:SetShown(selected==nil and #G.rows==0)
    D.scroll:SetShown(selected~=nil)
    if selected then
        -- Head: back left, actions right, icon and name below.
        local H_=H
        H_.fitButton(U.myCharactersBack,96);H_.place(U.myCharactersBack,x,-y)
        local mainWidth=H_.fitButton(U.setMainButton,120);local moreWidth=H_.fitButton(U.myCharactersMore,64)
        H_.place(U.myCharactersMore,x+w-moreWidth,-y);H_.place(U.setMainButton,x+w-moreWidth-8-mainWidth,-y)
        H_.place(U.myCharactersIcon,x,-(y+38))
        H_.place(U.myCharactersHeader,x+46,-(y+38),math.max(100,w-46),36)
        for _,control in ipairs({U.myCharactersBack,U.setMainButton,U.myCharactersMore,U.myCharactersIcon,U.myCharactersHeader})do control:Show()end
        D.scroll:ClearAllPoints();D.scroll:SetPoint('TOPLEFT',G.body,'TOPLEFT',0,-DETAIL_TOP)
        D.scroll:Fit(w,math.max(60,h-DETAIL_TOP),D.child:GetHeight())
        buildDetail(selected)
        D.scroll:Fit(w,math.max(60,h-DETAIL_TOP),D.child:GetHeight())
    elseif #G.rows>0 then
        view:SetSize(w,h)
        renderGrid()
    else
        G.empty:ClearAllPoints();G.empty:SetPoint('TOP',G.body,'TOP',0,-40)
        G.empty:SetState(G.view.zenialEmptyHint or'','','characters')
    end
end

U.RegisterMyCharactersTab('overview',{create=create,refresh=refresh,layout=layout,
    focused=function()return U.myCharactersDetailOpen==true end})
return U
