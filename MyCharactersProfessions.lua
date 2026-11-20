-- "My characters": Professions tab. Every recorded profession of the filtered characters, by character or by
-- profession, with rank bars. Rows are pooled and only the visible ones are drawn. A row opens the Recipes tab
-- for that character and profession. Reads the local AccountOverview read model only.
local Z,U=ZenialCommunity,ZenialCommunity.UI
local L,T=Z.Logic,Z.Theme
local function tr(s,...)return Z.T(s,...)end
local function K()return Z.Kit end
local H=U.MyCharactersUI

local GUTTER=18
local MODE_TOP=36        -- below the mode switch
local HEAD_HEIGHT,HEAD_GAP=26,12
local ROW_WIDE,ROW_NARROW,ROW_GAP=28,44,2
local NARROW_WIDTH=640
local INDENT=10

local P={mode='character',entries={},rows={},heads={items={},used=0},lines={items={},used=0}}
U.MyCharactersProfessions=P

local function age(t)return U.Shared.age(t)end
local function newPool(pool,create)pool.create=create;return pool end
local function take(pool,parent)
    pool.used=pool.used+1
    local item=pool.items[pool.used]
    if not item then item=pool.create(parent);pool.items[pool.used]=item end
    item:Show();return item
end

-- Same scroll area as the cards tab: own surfaces, render after every scroll step.
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

-- The Inventory tab (loaded after this file) uses the same scroll area.
H.createScroll,H.bindScroll=createScroll,bindScroll

-- ---------------------------------------------------------------------------------------------
-- Pooled frames
-- ---------------------------------------------------------------------------------------------
local function createHead(parent)
    local kit=K()
    local head=CreateFrame('Frame',nil,parent)
    head.icon=head:CreateTexture(nil,'ARTWORK');head.icon:SetSize(20,20)
    head.name=kit.Text(head,'','heading','goldBright');head.name:SetWordWrap(false);head.name:SetJustifyH('LEFT');head.name:SetHeight(16)
    head.info=kit.Text(head,'','caption','dim');head.info:SetWordWrap(false);head.info:SetJustifyH('RIGHT');head.info:SetHeight(14)
    head.rule=head:CreateTexture(nil,'ARTWORK');head.rule:SetHeight(1);T.Tint(head.rule,'SetColorTexture','line')
    return head
end
local function createLine(parent)
    local kit=K()
    local row=CreateFrame('Button',nil,parent)
    row.hover=row:CreateTexture(nil,'HIGHLIGHT');row.hover:SetAllPoints();T.Tint(row.hover,'SetColorTexture','hover')
    row.name=kit.Text(row,'','body','text');row.name:SetWordWrap(false);row.name:SetJustifyH('LEFT');row.name:SetHeight(14)
    row.rank=kit.Text(row,'','caption','textSoft');row.rank:SetWordWrap(false);row.rank:SetJustifyH('RIGHT');row.rank:SetHeight(14)
    row.meta=kit.Text(row,'','caption','dim');row.meta:SetWordWrap(false);row.meta:SetJustifyH('RIGHT');row.meta:SetHeight(14)
    row.bar=kit.ProgressBar(row,{width=100,height=6,tone='gold'})
    row:SetScript('OnClick',function(self)
        local e=self.entry
        if e and e.profession then U.OpenMyCharactersRecipes({profession=e.profession,characterKey=e.key})end
    end)
    return row
end
local function at(region,parent,x,y,w)
    region:ClearAllPoints();region:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    if w then region:SetWidth(w)end
end

-- Recipe count of a profession, like the details page: the recipe index, else the stored scan state.
local function recipeCount(r,profession)
    local R=Z.AccountRecipes
    local count
    if R and R.Counts then count=(R.Counts(r.key)or{})[profession.name]end
    local entry=r.recipeStates and r.recipeStates[profession.name]
    if count==nil and entry then count=entry.count end
    return count
end

-- ---------------------------------------------------------------------------------------------
-- Entries: the flat list of everything the tab shows, with its position. Built on layout, drawn on scroll.
-- ---------------------------------------------------------------------------------------------
local function charLabel(r,context)
    if context and not context.realm and r.realm~=''then return r.name..' · '..r.realm end
    return r.name
end
local function addProfession(list,r,p,primary,showName)
    local count=recipeCount(r,p)
    local meta={}
    if count then meta[#meta+1]=count==1 and tr('1 recipe')or tr('%d recipes',count)end
    if r.professionsAt then meta[#meta+1]=age(r.professionsAt)end
    list[#list+1]={kind='line',key=r.key,profession=p.name,rank=p.rank,max=p.max,primary=primary,
        text=showName,meta=table.concat(meta,' · ')}
end
local function build(rows,context,width)
    local entries={}
    local narrow=width<NARROW_WIDTH
    local rowHeight=narrow and ROW_NARROW or ROW_WIDE
    if P.mode=='character'then
        for _,r in ipairs(rows)do
            local professions={}
            for _,p in ipairs(r.primary or{})do addProfession(professions,r,p,true,tr(L.ProfessionName(p.name)))end
            for _,p in ipairs(r.secondary or{})do addProfession(professions,r,p,false,tr(L.ProfessionName(p.name)))end
            entries[#entries+1]={kind='head',row=r,text=r.name,info=tr('Level')..' '..(r.level or'?'),gold=r.current}
            if #professions==0 then entries[#entries+1]={kind='note',text=tr('No professions recorded')}end
            for _,e in ipairs(professions)do entries[#entries+1]=e end
        end
    else
        local byName,order={},{}
        for _,r in ipairs(rows)do
            for _,list in ipairs({{r.primary or{},true},{r.secondary or{},false}})do
                for _,p in ipairs(list[1])do
                    local section=byName[p.name]
                    if not section then
                        section={name=p.name,primary=list[2],text=tr(L.ProfessionName(p.name)),lines={}};byName[p.name]=section;order[#order+1]=section
                    end
                    addProfession(section.lines,r,p,list[2],charLabel(r,context))
                end
            end
        end
        table.sort(order,function(a,b)
            if a.primary~=b.primary then return a.primary end
            return a.text<b.text
        end)
        for _,section in ipairs(order)do
            table.sort(section.lines,function(a,b)
                if(a.rank or 0)~=(b.rank or 0)then return(a.rank or 0)>(b.rank or 0)end
                return a.text<b.text
            end)
            entries[#entries+1]={kind='head',text=section.text,info=tostring(#section.lines),gold=section.primary}
            for _,e in ipairs(section.lines)do entries[#entries+1]=e end
        end
    end
    local y=0
    for index,e in ipairs(entries)do
        if e.kind=='head'then
            if index>1 then y=y+HEAD_GAP end
            e.y,e.h=y,HEAD_HEIGHT
        else
            e.y,e.h=y,e.kind=='note'and 20 or rowHeight
        end
        y=y+e.h+(e.kind=='head'and 4 or ROW_GAP)
    end
    return entries,math.max(1,y),narrow
end

-- ---------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------
local function updateHead(head,e,w)
    head:SetSize(w,HEAD_HEIGHT)
    local r=e.row
    local x=0
    if r then
        T.SetTexture(head.icon,H.classIcon(r));at(head.icon,head,0,2);head.icon:Show();x=26
    else head.icon:Hide()end
    head.info:SetText(e.info or'')
    local infoWidth=math.max(20,math.ceil(head.info:GetStringWidth())+4)
    at(head.info,head,w-infoWidth,5,infoWidth)
    head.name:SetText(e.text);T.Font(head.name,'heading',e.gold and'goldBright'or'text')
    at(head.name,head,x,3,math.max(40,w-x-infoWidth-8))
    at(head.rule,head,0,HEAD_HEIGHT-2,w)
end
local function updateLine(row,e,w,narrow)
    row.entry=e
    local h=narrow and ROW_NARROW or ROW_WIDE
    row:SetSize(w,h)
    row.name:SetText(e.text);row.rank:SetText(e.rank..(e.max and('/'..e.max)or''));row.meta:SetText(e.meta or'')
    row.bar:SetTone(e.primary and'gold'or'dim')
    local rankWidth=64
    if narrow then
        local inner=w-2*INDENT
        at(row.name,row,INDENT,4,math.max(40,inner-rankWidth-8))
        at(row.rank,row,w-INDENT-rankWidth,4,rankWidth)
        local metaWidth=math.min(math.floor(inner*.55),math.max(20,math.ceil(row.meta:GetStringWidth())+4))
        at(row.meta,row,w-INDENT-metaWidth,23,metaWidth)
        row.bar:SetBarWidth(math.max(20,inner-metaWidth-10));at(row.bar,row,INDENT,26)
    else
        local metaWidth=180
        local nameWidth=math.max(110,math.min(200,math.floor(w*.26)))
        at(row.name,row,INDENT,7,nameWidth)
        at(row.meta,row,w-INDENT-metaWidth,7,metaWidth)
        at(row.rank,row,w-INDENT-metaWidth-8-rankWidth,7,rankWidth)
        local barX=INDENT+nameWidth+10
        row.bar:SetBarWidth(math.max(20,w-INDENT-metaWidth-8-rankWidth-10-barX));at(row.bar,row,barX,11)
    end
    row.bar:SetValue(e.rank,e.max)
end
local function createNote(parent)
    local fs=K().Text(parent,'','caption','dim');fs:SetWordWrap(false);fs:SetJustifyH('LEFT');fs:SetHeight(14);return fs
end
P.notes={items={},used=0}
newPool(P.heads,createHead);newPool(P.lines,createLine);newPool(P.notes,createNote)

-- Draws the entries around the scroll position; frames are reused.
local function render()
    local view=P.view
    if not view or view.zenialRendering or not P.contentHeight then return end
    view.zenialRendering=true
    local width,height=view:GetWidth(),view:GetHeight()
    view:Fit(width,height,P.contentHeight)
    local maximum=math.max(0,P.contentHeight-height)
    local offset=math.max(0,math.min(tonumber(view.zenialOffset)or view:GetVerticalScroll()or 0,maximum))
    local inner=math.max(1,width-GUTTER)
    for _,pool in ipairs({P.heads,P.lines,P.notes})do pool.used=0 end
    for _,e in ipairs(P.entries)do
        if e.y+e.h>=offset and e.y<=offset+height then
            if e.kind=='head'then
                local head=take(P.heads,view.child);at(head,view.child,0,e.y);updateHead(head,e,inner)
            elseif e.kind=='line'then
                local row=take(P.lines,view.child);at(row,view.child,0,e.y);updateLine(row,e,inner,P.narrow)
            else
                local fs=take(P.notes,view.child);fs:SetText(e.text);at(fs,view.child,INDENT,e.y+2,math.max(40,inner-INDENT))
            end
        end
    end
    for _,pool in ipairs({P.heads,P.lines,P.notes})do for index=pool.used+1,#pool.items do pool.items[index]:Hide()end end
    view.zenialRendering=false
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
    P.body=body
    P.seg=kit.Segmented(body,{{key='character',label=tr('By character')},{key='profession',label=tr('By profession')}},function(key)
        P.mode=key;U.RefreshMyCharacters()
    end)
    P.seg:SetPoint('TOPLEFT',body,'TOPLEFT',0,0)
    P.view=createScroll(body);P.view:SetPoint('TOPLEFT',body,'TOPLEFT',0,-MODE_TOP)
    bindScroll(P.view,render)
    P.empty=kit.EmptyState(body,{icon='characters',title='',width=520});P.empty:Hide()
    U.professionsList=P.view
end

local function refresh(rows,context)
    P.rows,P.context=rows,context
    P.seg:Select(P.mode)
    local any=false
    for _,r in ipairs(rows)do if #(r.primary or{})+#(r.secondary or{})>0 then any=true end end
    if #rows==0 then P.emptyHint=emptyHint(context)
    elseif P.mode=='profession'and not any then P.emptyHint=tr('No professions recorded')
    else P.emptyHint=nil end
end

local function layout(_,_,w,h)
    local widest=0
    for _,segment in ipairs(P.seg.segments)do widest=math.max(widest,H.buttonTextWidth(segment))end
    P.seg:SetSegmentWidth(math.max(90,widest+28))
    P.entries,P.contentHeight,P.narrow=build(P.rows or{},P.context,w-GUTTER)
    P.view:SetShown(P.emptyHint==nil)
    P.empty:SetShown(P.emptyHint~=nil)
    if P.emptyHint then
        P.empty:ClearAllPoints();P.empty:SetPoint('TOP',P.body,'TOP',0,-MODE_TOP-30)
        P.empty:SetState(P.emptyHint,'','characters')
        return
    end
    P.view:SetSize(w,math.max(60,h-MODE_TOP))
    render()
end

U.RegisterMyCharactersTab('professions',{create=create,refresh=refresh,layout=layout})
return U
