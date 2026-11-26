-- "My characters": Inventory tab. Character mode shows the recorded bags or bank of one character as slot grids
-- (pooled slots, only the visible rows are drawn); Search mode is the item search over the recorded bags and
-- banks of the filtered characters (hits on the left, holders on the right). Reads the local AccountOverview
-- read model only; nothing here scans or sends anything.
local Z,U=ZenialCommunity,ZenialCommunity.UI
local L,T=Z.Logic,Z.Theme
local function tr(s,...)return Z.T(s,...)end
local function O()return Z.AccountOverview end
local function K()return Z.Kit end
local H=U.MyCharactersUI
local S

local GOLD='|cffffd36b'
local HIT_HEIGHT,HOLDER_HEIGHT=30,40
-- From this content width on the search uses two columns; below it hits and holders alternate.
local WIDE_WIDTH=840
local MODE_TOP=36                      -- below the mode switch
local SLOT,GAP,MAX_COLUMNS=34,4,16     -- slot grid
local LIST_ROW=34                      -- legacy list row
local HEAD_HEIGHT,CONTAINER_GAP=22,14
local GUTTER=18
local QUESTION='Interface\\Icons\\INV_Misc_QuestionMark'

local I={mode='character',place='bags',names={},rows={},entries={},
    heads={items={},used=0},slots={items={},used=0},lines={items={},used=0},notes={items={},used=0}}
U.MyCharactersInventory=I

local function trim(v)return type(v)=='string'and v:match('^%s*(.-)%s*$')or''end
local function place(f,x,y,w,h)return H.place(f,x,y,w,h)end
local function shown(f,value)return H.shown(f,value)end
local function take(pool,parent)
    pool.used=pool.used+1
    local item=pool.items[pool.used]
    if not item then item=pool.create(parent);pool.items[pool.used]=item end
    item:Show();return item
end
local function at(region,parent,x,y,w)
    region:ClearAllPoints();region:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    if w then region:SetWidth(w)end
end

-- ---------------------------------------------------------------------------------------------
-- Search mode (moved from the shell; widget names stay)
-- ---------------------------------------------------------------------------------------------
-- Item hits of the search: only AccountOverview.Search over the characters of the overview scope. An empty
-- query finds nothing.
function U.MyCharactersItemHits(context)
    local query=trim(U.itemSearch:GetText())
    if query==''then return{},0,query end
    local hits,unresolved=O().Search(query,context.scoped)
    return hits,unresolved,query
end
-- Scope shown on the search (H.scopeText): the overview's realm, faction and hidden choice. Items are searched exactly there.
local function holderItem(h,byKey)
    local r=byKey[h.key];local where_={}
    local function part(name,count,time)
        if count>0 then where_[#where_+1]=tr(name)..' '..count..(time and(' ('..tr('as of %s',H.when(time))..')')or'')end
    end
    part('Bags',h.bags,r and r.bagsAt);part('Bank',h.bank,r and r.bankAt)
    local where=h.realm~=''and h.realm or''
    if r and r.faction~=''then where=where..(where~=''and' / 'or'')..tr(r.faction)end
    local item={text=h.name..(where~=''and(' · '..where)or''),subtitle=table.concat(where_,' · '),noWrap=true,height=HOLDER_HEIGHT}
    -- Holders are information, not a choice: flat row flush left (D-23).
    if H.styled()then
        item.flat,item.textInset=true,0
        item.display=H.paint('text',h.name)..(where~=''and H.paint('dim',' · '..where)or'')
        item.subtitleDisplay=H.paint('textSoft',item.subtitle)
    end
    return item
end
local function refreshSearch(context)
    local overview=O()
    local hits,unresolved,query=U.MyCharactersItemHits(context)
    U.itemScope:SetText(H.scopeText(context))
    local notes={tr('Search the recorded bags and bank compartments of your characters.'),tr('Bag and bank recording must be on. Bank contents exist only after you opened the bank while recording. Saved amounts can be older than your current inventory.')}
    if unresolved>0 then notes[#notes+1]=tr('%d item names are still loading. Search again in a moment.',unresolved)end
    if not overview.InventoryEnabled()then notes[#notes+1]=tr('Bags and bank are only searched once their recording is on.')end
    U.itemsNote:SetText(notes[1]..'\n'..notes[2]..(#notes>2 and ('\n'..table.concat({unpack(notes,3)},' '))or''))
    local noteHeight=math.max(60,(U.itemsNote:GetStringHeight() or 60)+8)
    U.itemsNote:SetHeight(noteHeight)
    local selectedHit
    for _,hit in ipairs(hits)do if hit.id==U.itemHitId then selectedHit=hit end end
    if not selectedHit then selectedHit=hits[1];U.itemHitId=selectedHit and selectedHit.id end
    if not selectedHit then U.itemsDetailOpen=false end
    local items={}
    for _,hit in ipairs(hits)do
        local item={text=hit.name..' · '..hit.total,noWrap=true,height=HIT_HEIGHT,selected=selectedHit==hit,
            click=function()U.itemHitId=hit.id;U.itemsDetailOpen=true;U.CloseDropdowns();U.RefreshMyCharacters()end}
        -- Item icon in front, name bright, amount dim.
        if H.styled()then
            item.display=H.paint('text',hit.name)..H.paint('dim',' · '..hit.total)
            local icon=S.itemIcon and S.itemIcon(hit.id)
            item.icon=icon or T.IconSpec('search')
            item.iconSize,item.textInset=20,36
            if not icon then item.iconColor='dim'end
        end
        items[#items+1]=item
    end
    local hint
    if #query<2 and not tonumber(query)then hint=tr('Enter an item name with at least 2 characters or an item ID to search recorded bags and banks.')
    elseif #hits==0 then hint=tr('No matching items in recorded bags and banks.')end
    U.SetEmptyHint(U.itemHitList,hint,hint and'search'or nil)
    S.rows(U.itemHitList,items,HIT_HEIGHT)
    local byKey={};for _,r in ipairs(context.scoped)do byKey[r.key]=r end
    local holders={}
    if selectedHit then
        local bags,bank=0,0;for _,h in ipairs(selectedHit.holders)do bags=bags+(h.bags or 0);bank=bank+(h.bank or 0)end
        local headText=selectedHit.name..' · '..selectedHit.total
        local headSub=tr('%d characters · Bags %d · Bank %d',#selectedHit.holders,bags,bank)
        holders[1]={text=GOLD..headText..'|r\n'..headSub,height=38,header=true}
        if H.styled()then
            holders[1].section,holders[1].textInset=true,0
            holders[1].display=H.paint('goldBright',headText)..'\n'..H.paint('dim',headSub)
        end
        for _,h in ipairs(selectedHit.holders)do holders[#holders+1]=holderItem(h,byKey)end
    end
    U.SetEmptyHint(U.itemHolderList,#hits>0 and tr('Select an item to see which characters hold it.')or nil,#hits>0 and'search'or nil)
    S.rows(U.itemHolderList,holders,HOLDER_HEIGHT)
end
local function createSearch(body,helpers)
    local label,button=helpers.label,helpers.button
    local function reset()U.RefreshMyCharacters()end
    U.itemSearch=helpers.edit(body,'Item name (2+ characters) or item ID',0,0,300,64);U.itemSearch:SetScript('OnTextChanged',reset)
    -- Small search symbol inside the field (pattern: U.memberSearchIcon).
    if Z.Kit and T then
        local icon=Z.Kit.Icon(U.itemSearch,'search',14,'muted');icon:SetPoint('LEFT',8,0);U.itemSearchIcon=icon
        if U.itemSearch.SetTextInsets then U.itemSearch:SetTextInsets(26,8,4,4)end
    end
    U.itemScope=label(body,'',320,-17,300)
    U.itemsNote=label(body,'',0,-48,800)
    U.itemsNote:SetHeight(60)
    U.itemHitList=helpers.list(body,0,-82,300,260)
    -- Who holds the item is information only: flat rows, no sunken well (D-23).
    U.itemHolderList=helpers.list(body,320,-82,400,260)
    if Z.Kit then Z.Kit.InfoBlock(U.itemHolderList)end
    U.itemsBack=button(body,'Back to results',0,-82,140,function()U.itemsDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end)
end
local function placeList(view,x,y,w,h)
    local changed=view:GetWidth()~=w or view:GetHeight()~=h
    place(view,x,y,w,h);view.width,view.height=w-24,h;view.child:SetWidth(w-24)
    if changed and view.zenialRender then view.zenialRender()end
end
local function placeEdit(e,x,y,w)place(e.caption,x,y,w);place(e,x,y-17,w)end
local function searchControls()
    return{U.itemSearch,U.itemSearch.caption,U.itemScope,U.itemsNote,U.itemHitList,U.itemHolderList,U.itemsBack}
end
local function layoutSearch(width,height)
    local wide=width>=WIDE_WIDTH
    local focused=not wide and U.itemsDetailOpen
    for _,control in ipairs({U.itemSearch,U.itemSearch.caption,U.itemScope,U.itemsNote})do shown(control,not focused)end
    local top=MODE_TOP
    if not focused then
        local searchWidth=math.min(360,math.floor(width*.5))
        placeEdit(U.itemSearch,0,-top,searchWidth)
        place(U.itemScope,searchWidth+16,-(top+17),width-searchWidth-16,24)
        place(U.itemsNote,0,-(top+48),width)
        local noteHeight=math.max(60,(U.itemsNote:GetStringHeight() or 60)+8)
        U.itemsNote:SetHeight(noteHeight)
        top=top+48+noteHeight+12
    end
    local body=math.max(120,height-top)
    local listWidth=wide and math.max(280,math.min(340,math.floor(width*.32)))or width
    local detailX=wide and listWidth+16 or 0;local detailWidth=width-detailX
    local itemsDetail=wide or U.itemsDetailOpen
    local itemsList=wide or not U.itemsDetailOpen
    shown(U.itemHitList,itemsList);shown(U.itemHolderList,itemsDetail)
    shown(U.itemsBack,not wide and U.itemsDetailOpen)
    placeList(U.itemHitList,0,-top,listWidth,body)
    local holderTop=top
    if itemsDetail and not wide then H.fitButton(U.itemsBack,96);place(U.itemsBack,0,-top);holderTop=top+34 end
    placeList(U.itemHolderList,detailX,-holderTop,detailWidth,body-(holderTop-top))
end

-- ---------------------------------------------------------------------------------------------
-- Character mode: slot grids
-- ---------------------------------------------------------------------------------------------
local function iconFor(itemID)
    local row=Z.Items and Z.Items.Get(itemID)
    if row and row.icon then return row.icon end
    local spec=S and S.itemIcon and S.itemIcon(itemID)
    return spec and spec.file or QUESTION
end
local function itemName(itemID)
    local row=Z.Items and Z.Items.Get(itemID)
    if row and row.name then return row.name,true end
    if Z.Items then Z.Items.Observe(itemID)end
    return'#'..itemID,false
end
-- Bank containers: legacy snapshots start with the main bank (-1), Forever
-- snapshots only hold bank tabs, named by their position.
local function containerName(area,bag,index,legacy)
    if area=='bags'then
        if bag==0 then return tr('Backpack')end
        if bag==5 then return tr('Reagent bag')end
        return tr('Bag %d',bag)
    end
    if not legacy then return tr('Bank tab %d',index or 1)end
    if bag<0 then return tr('Bank')end
    local first=(L.Int(NUM_BAG_SLOTS,1,20)and NUM_BAG_SLOTS or 4)
    return tr('Bank bag %d',bag-first)
end

local function createHead(parent)return K().SectionHeader(parent,'')end
local function createSlot(parent)return K().ItemSlot(parent,SLOT)end
local function createNote(parent)
    local fs=K().Text(parent,'','caption','dim');fs:SetWordWrap(false);fs:SetJustifyH('LEFT');fs:SetHeight(14);return fs
end
local function createLine(parent)
    local kit=K()
    local row=CreateFrame('Frame',nil,parent)
    row.slot=kit.ItemSlot(row,28);row.slot:SetPoint('TOPLEFT',row,'TOPLEFT',0,-3)
    row.name=kit.Text(row,'','body','text');row.name:SetWordWrap(false);row.name:SetJustifyH('LEFT');row.name:SetHeight(14)
    row.count=kit.Text(row,'','caption','textSoft');row.count:SetWordWrap(false);row.count:SetJustifyH('RIGHT');row.count:SetHeight(14)
    return row
end
I.heads.create,I.slots.create,I.lines.create,I.notes.create=createHead,createSlot,createLine,createNote

-- Flat list of what the character view shows, with positions. Built on layout, drawn on scroll.
local function legacyList(counts)
    local list={}
    for itemID,count in pairs(counts or{})do
        local row=Z.Items and Z.Items.Get(itemID)
        list[#list+1]={id=itemID,count=count,name=row and row.name}
    end
    table.sort(list,function(a,b)
        if(a.name~=nil)~=(b.name~=nil)then return a.name~=nil end
        if a.name and a.name~=b.name then return string.lower(a.name)<string.lower(b.name)end
        return a.id<b.id
    end)
    return list
end
local function buildCharacter(inv,area,width)
    local entries,y={},0
    if inv.slots then
        local legacy=inv.slots.containers[1]and inv.slots.containers[1].bag<0
        for index,ct in ipairs(inv.slots.containers)do
            if ct.size>0 then
                local used=0;for _ in pairs(ct.slots)do used=used+1 end
                entries[#entries+1]={kind='head',y=y,h=HEAD_HEIGHT,text=containerName(area,ct.bag,index,legacy),info=used..'/'..ct.size}
                y=y+HEAD_HEIGHT
                local columns=K().Columns(width,SLOT,GAP,MAX_COLUMNS)
                local rows=math.ceil(ct.size/columns)
                columns=math.ceil(ct.size/rows)
                for row=1,rows do
                    entries[#entries+1]={kind='slots',y=y,h=SLOT+GAP,ct=ct,first=(row-1)*columns+1,last=math.min(ct.size,row*columns)}
                    y=y+SLOT+GAP
                end
                y=y+CONTAINER_GAP-GAP
            end
        end
    else
        entries[#entries+1]={kind='note',y=y,h=22,text=tr('Older record without bag slots')};y=y+22
        for _,item in ipairs(legacyList(inv.counts))do
            entries[#entries+1]={kind='line',y=y,h=LIST_ROW,id=item.id,count=item.count};y=y+LIST_ROW
        end
    end
    return entries,math.max(1,y)
end

local function updateSlot(slot,ct,index)
    local entry=ct.slots[index]
    if entry then
        local row=Z.Items and Z.Items.Get(entry[1])
        if not row and Z.Items then Z.Items.Observe(entry[1])end
        slot:SetItem({itemID=entry[1],icon=iconFor(entry[1]),count=entry[2]})
    else
        slot:SetEmpty()
    end
end
local function render()
    local view=I.view
    if not view or view.zenialRendering or not I.contentHeight then return end
    view.zenialRendering=true
    local width,height=view:GetWidth(),view:GetHeight()
    view:Fit(width,height,I.contentHeight)
    local maximum=math.max(0,I.contentHeight-height)
    local offset=math.max(0,math.min(tonumber(view.zenialOffset)or view:GetVerticalScroll()or 0,maximum))
    local inner=math.max(1,width-GUTTER)
    for _,pool in ipairs({I.heads,I.slots,I.lines,I.notes})do pool.used=0 end
    for _,e in ipairs(I.entries)do
        if e.y+e.h>=offset and e.y<=offset+height then
            if e.kind=='head'then
                local head=take(I.heads,view.child);head:SetWidth(inner);at(head,view.child,0,e.y+2)
                head:SetText(e.text);head:SetCount(e.info)
                head.line:SetWidth(math.max(1,inner-head.label:GetWidth()-head.count:GetWidth()-20))
            elseif e.kind=='slots'then
                for index=e.first,e.last do
                    local slot=take(I.slots,view.child)
                    at(slot,view.child,(index-e.first)*(SLOT+GAP),e.y)
                    updateSlot(slot,e.ct,index)
                end
            elseif e.kind=='line'then
                local row=take(I.lines,view.child);row:SetSize(inner,LIST_ROW);at(row,view.child,0,e.y)
                local name=itemName(e.id)
                row.slot:SetItem({itemID=e.id,icon=iconFor(e.id),count=1})
                row.name:SetText(name);row.count:SetText('× '..e.count)
                local countWidth=math.max(30,math.ceil(row.count:GetStringWidth())+4)
                at(row.name,row,40,9,math.max(40,inner-40-countWidth-8));at(row.count,row,inner-countWidth,10,countWidth)
            else
                local fs=take(I.notes,view.child);fs:SetText(e.text);at(fs,view.child,0,e.y+2,inner)
            end
        end
    end
    for _,pool in ipairs({I.heads,I.slots,I.lines,I.notes})do for index=pool.used+1,#pool.items do pool.items[index]:Hide()end end
    view.zenialRendering=false
end
function I.Render()render()end

-- ---------------------------------------------------------------------------------------------
-- Tab
-- ---------------------------------------------------------------------------------------------
local function emptyHint(context)
    if context.query~=''then return tr('No character matches this search.')end
    if context.hidden>0 then return tr('All matching characters are hidden. Turn on "Show hidden" to see them.')end
    if context.filtered or context.all>0 then return tr('No character for this realm and faction.')end
    return tr('No characters recorded yet.')
end

local function create(body,helpers)
    S=helpers
    local kit=K()
    I.body=body
    I.modeSwitch=kit.Segmented(body,{{key='character',label=tr('Character')},{key='search',label=tr('Search')}},function(key)
        I.mode=key;U.itemsDetailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()
    end)
    I.modeSwitch:SetPoint('TOPLEFT',body,'TOPLEFT',0,0)
    I.placeSwitch=kit.Segmented(body,{{key='bags',label=tr('Bags')},{key='bank',label=tr('Bank')}},function(key)
        I.place=key;U.RefreshMyCharacters()
    end)
    I.placeSwitch:SetPoint('TOPLEFT',body,'TOPLEFT',0,0)
    -- The character list needs no caption: the dropdown shows the name.
    I.selector=helpers.selector(body,'Character',0,17,220,{''},function(key)I.key=key;U.RefreshMyCharacters()end,
        function(key)return I.names[key]or key end)
    I.selector.caption:Hide()
    I.info=kit.Text(body,'','caption','dim');I.info:SetWordWrap(false);I.info:SetJustifyH('LEFT');I.info:SetHeight(14)
    I.view=H.createScroll(body);I.view:SetPoint('TOPLEFT',body,'TOPLEFT',0,-MODE_TOP)
    H.bindScroll(I.view,render)
    I.empty=kit.EmptyState(body,{icon='characters',title='',width=520});I.empty:Hide()
    U.inventoryGrid=I.view
    createSearch(body,helpers)
end

local function refresh(rows,context)
    I.rows,I.context=rows,context
    I.modeSwitch:Select(I.mode);I.placeSwitch:Select(I.place)
    if I.mode=='search'then refreshSearch(context);return end
    -- Character list from the filtered rows; the logged-in character (or the one a link named) is the default.
    local values,names,chosen,current={},{},nil,nil
    for _,r in ipairs(rows)do
        values[#values+1]=r.key
        names[r.key]=(context.realm==nil and r.realm~='')and(r.name..' · '..r.realm)or r.name
        if r.key==I.key then chosen=r.key end
        if r.current then current=r.key end
    end
    I.names=names
    I.emptyHint=#rows==0 and emptyHint(context)or nil
    I.selected=nil
    chosen=chosen or current or values[1]
    for _,r in ipairs(rows)do if r.key==chosen then I.selected=r end end
    -- The popup is rebuilt (and scrolled to the top) only when its entries change.
    local list=#values>0 and values or{''}
    local parts={};for _,value in ipairs(list)do parts[#parts+1]=value..'='..(names[value]or'')end
    local signature=table.concat(parts,'\1')
    if I.selector.zenialSignature~=signature then I.selector.zenialSignature=signature;I.selector:SetOptions(list,chosen or'')
    else I.selector:SetText(chosen or'')end
end

local function modeWidth(seg)
    local widest=0
    for _,segment in ipairs(seg.segments)do widest=math.max(widest,H.buttonTextWidth(segment))end
    seg:SetSegmentWidth(math.max(80,widest+28))
    return seg:GetWidth()
end
local function layoutCharacter(w,h)
    local r=I.selected
    local modeW,placeW=I.modeSwitch:GetWidth(),I.placeSwitch:GetWidth()
    local selectorWidth=math.max(150,math.min(260,w-modeW-placeW-48))
    local oneRow=modeW+12+selectorWidth+12+placeW<=w
    local top
    I.selector:SetWidth(selectorWidth)
    if oneRow then
        place(I.selector.button,modeW+12,0);place(I.placeSwitch,modeW+12+selectorWidth+12,0);top=34
    else
        place(I.placeSwitch,modeW+12,0)
        selectorWidth=math.min(260,w);I.selector:SetWidth(selectorWidth)
        place(I.selector.button,0,-34);top=68
    end
    shown(I.selector.button,r~=nil);shown(I.placeSwitch,true)
    if not r then I.selector.popup:Hide()end
    -- State text and the grid below.
    local hint,inv
    if not r then hint=I.emptyHint
    else
        inv=r.inventory and r.inventory[I.place]
        if not inv or not inv.known then
            hint=I.place=='bank'and tr('Bank not recorded yet – open your bank once')or tr('Bags not recorded yet')
        end
    end
    shown(I.info,hint==nil)
    if hint then
        I.view:Hide();I.empty:Show();I.empty:ClearAllPoints();I.empty:SetPoint('TOP',I.body,'TOP',0,-(top+30))
        I.empty:SetState(hint,'','characters')
        I.entries,I.contentHeight={},nil
        return
    end
    I.empty:Hide()
    local line={tr('as of %s',H.when(inv.at))}
    if inv.total then line[#line+1]=tr('%d of %d slots used',inv.used,inv.total)end
    I.info:SetText(table.concat(line,' · '));place(I.info,0,-top,w,16)
    top=top+22
    I.area=I.place
    I.entries,I.contentHeight=buildCharacter(inv,I.place,w-GUTTER)
    I.view:Show();place(I.view,0,-top)
    I.view:SetSize(w,math.max(60,h-top))
    render()
end

local function layout(_,_,w,h)
    modeWidth(I.modeSwitch);modeWidth(I.placeSwitch)
    place(I.modeSwitch,0,0)
    local character=I.mode=='character'
    shown(I.placeSwitch,character);shown(I.selector.button,character);shown(I.info,character)
    if not character then
        I.selector.popup:Hide();I.view:Hide();I.empty:Hide()
    end
    for _,control in ipairs(searchControls())do if character then control:Hide()end end
    if character then layoutCharacter(w,h)else layoutSearch(w,h)end
end

-- A link to the tab: an item opens the search with it, a character its bags.
function U.ApplyMyCharactersInventorySelection(selection)
    if type(selection)~='table'then return end
    if selection.characterKey then I.key=selection.characterKey end
    if selection.itemID and U.itemSearch then
        I.mode='search';U.itemSearch:SetText(tostring(selection.itemID))
    elseif selection.characterKey then
        I.mode='character'
    end
end

-- Item names and icons arrive later from the client: redraw the visible tab once, not once per event.
local pending=false
local previousOnItemData=U.OnItemData
function U.OnItemData(...)
    if previousOnItemData then previousOnItemData(...)end
    if pending or not U.myCharactersBuilt or U.myCharactersTab~='items'or not U.frame or not U.frame:IsShown()or U.page~=6 then return end
    if U.profileView=='public'then return end
    local function redraw()
        pending=false
        if U.myCharactersTab~='items'then return end
        if I.mode=='search'then U.RefreshMyCharacters()else I.Redraw()end
    end
    pending=true
    if C_Timer and C_Timer.After then C_Timer.After(.4,redraw)else redraw()end
end
function I.Redraw()
    if I.mode~='character'or not I.view or not I.view:IsShown()then return end
    local inv=I.selected and I.selected.inventory and I.selected.inventory[I.place]
    if not inv or not inv.known then return end
    I.entries,I.contentHeight=buildCharacter(inv,I.place,I.view:GetWidth()-GUTTER)
    render()
end

U.RegisterMyCharactersTab('items',{filters=true,create=create,refresh=refresh,layout=layout,
    focused=function()return I.mode=='search'end})
return U
