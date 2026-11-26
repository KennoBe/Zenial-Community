-- "My characters": Recipes tab. Account-wide recipe list (grouped by profession, one entry per recipe with all
-- characters that know it) and a detail page with the material table for a chosen crafter and craft count.
-- Reads Z.AccountRecipes (index, materials, gather plan) only; planning, no mail/trade/bank actions. The list is
-- virtualised by S.rows, the material table is recomputed only when recipe, crafter, count or data change.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local L,T=Z.Logic,Z.Theme
local function tr(s,...)return Z.T(s,...)end
local function K()return Z.Kit end
local H=U.MyCharactersUI

local WIDE=840
local ROW_HEIGHT,SECTION_HEIGHT,MATERIAL_HEIGHT=40,26,28
local QUESTION=134400
local ALL='AO_ALL'
-- Column widths of the material table (right aligned, 8 px gap each).
local COL_NEED,COL_BAGS,COL_BANK,COL_MISSING=64,58,86,64
local STATE_COLOR={direct='success',elsewhere='goldBright',missing='dangerText'}

local M={crafts=1,pools={}}
U.MyCharactersRecipes=M

local function trim(v)return type(v)=='string'and v:match('^%s*(.-)%s*$')or''end
local function paint(key,text)return H.paint(key,text)end
local function age(t)return U.Shared.age(t)end
local function itemName(id)
    local items=Z.Items
    local row=items and(items.Get(id)or items.Observe(id))
    return row and row.name or('#'..tostring(id))
end
local function itemIconFile(id)
    local icon=M.S and M.S.itemIcon and M.S.itemIcon(id)
    return icon and icon.file or nil
end
local function entryKey(e)return e.profession..'\0'..e.id end

-- ---------------------------------------------------------------------------------------------
-- Pools in the scroll area of the detail page
-- ---------------------------------------------------------------------------------------------
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
local function createMaterialRow(parent)
    local kit=K()
    local row=CreateFrame('Button',nil,parent)
    row.hover=row:CreateTexture(nil,'HIGHLIGHT');row.hover:SetAllPoints();T.Tint(row.hover,'SetColorTexture','hover')
    row.accent=row:CreateTexture(nil,'ARTWORK');row.accent:SetWidth(3)
    row.accent:SetPoint('TOPLEFT',row,'TOPLEFT',0,-3);row.accent:SetPoint('BOTTOMLEFT',row,'BOTTOMLEFT',0,3)
    row.slot=kit.ItemSlot(row,22);row.slot:SetOnClick(function()row:Click()end)
    row.name=kit.Text(row,'','body','text');row.name:SetWordWrap(false);row.name:SetJustifyH('LEFT');row.name:SetHeight(14)
    row.need=kit.Text(row,'','body','text');row.bags=kit.Text(row,'','body','text')
    row.bank=kit.Text(row,'','body','textSoft');row.missing=kit.Text(row,'','body','text')
    for _,fs in ipairs({row.need,row.bags,row.bank,row.missing})do fs:SetWordWrap(false);fs:SetJustifyH('RIGHT');fs:SetHeight(14)end
    row:SetScript('OnEnter',function(self)
        local r=self.material
        if not r or not GameTooltip or not GameTooltip.SetOwner then return end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(itemName(r.itemID),1,.85,.42)
        local names=M.names or{}
        local function place(label,count,at)
            if count==nil then return label..': '..tr('Unknown')end
            return label..' '..count..(at and(' ('..tr('as of %s',age(at))..')')or'')
        end
        local own=M.crafter and(names[M.crafter]or M.crafter)or''
        GameTooltip:AddLine(own..' · '..place(tr('Bags'),r.bags),.78,.8,.85,true)
        GameTooltip:AddLine(own..' · '..place(tr('Bank'),r.bank),.78,.8,.85,true)
        for _,e in ipairs(r.elsewhere or{})do
            GameTooltip:AddLine((names[e.key]or e.key)..' · '..place(tr('Bags'),e.bags,e.bagsAt)..' · '..place(tr('Bank'),e.bank,e.bankAt),.78,.8,.85,true)
        end
        GameTooltip:Show()
    end)
    row:SetScript('OnLeave',function()if GameTooltip and GameTooltip.Hide then GameTooltip:Hide()end end)
    return row
end

local function put(region,x,y,w,h)
    region:ClearAllPoints();region:SetPoint('TOPLEFT',M.child,'TOPLEFT',x,-y)
    if w then region:SetWidth(w)end
    if h then region:SetHeight(h)end
end
local function sectionHead(y,w,title,count)
    local head=take(M.pools.heads,M.child);head:SetText(title);head:SetCount(count)
    put(head,0,y,w,16)
    head:SetPoint('TOPRIGHT',M.child,'TOPLEFT',w,-y)
    head.line:SetWidth(math.max(1,w-head.label:GetWidth()-head.count:GetWidth()-20))
    return 24
end
local function textBlock(y,w,value,role,colorKey)
    local fs=take(M.pools.texts,M.child)
    fs:SetWordWrap(true);T.Font(fs,role or'body',colorKey or'text');fs:SetJustifyH('LEFT')
    fs:SetWidth(w);fs:SetText(value)
    local height=math.max(14,math.ceil(fs:GetStringHeight()))
    put(fs,0,y,w,height);return height
end
-- label left, value right
local function valueLine(y,w,labelText,valueText,colorKey)
    local label=take(M.pools.texts,M.child);label:SetWordWrap(false);T.Font(label,'body','text');label:SetJustifyH('LEFT')
    local value=take(M.pools.texts,M.child);value:SetWordWrap(false);T.Font(value,'body',colorKey or'text');value:SetJustifyH('RIGHT')
    label:SetText(labelText);value:SetText(valueText)
    local valueWidth=math.min(math.floor(w*.6),math.max(20,math.ceil(value:GetStringWidth())+4))
    put(label,0,y,w-valueWidth-8,14);put(value,w-valueWidth,y,valueWidth,14)
    return 22
end

-- ---------------------------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------------------------
local function materialsFor(e,crafter,crafts)
    local R,P=Z.AccountRecipes,Z.MaterialPlanner
    local key=table.concat({e.profession,e.id,crafter,crafts,R.Index().sig,Z.AccountOverview and Z.AccountOverview.revision or 0,P and P.store and P.store.revision or 0},'|')
    if M.materialKey~=key then
        M.materialKey=key;M.material=R.Materials(e,crafter,crafts);M.gatherPlan=nil
    end
    return M.material
end
local function gatherPlan()
    if not M.gatherPlan then M.gatherPlan=Z.AccountRecipes.Gather(M.material,M.crafter)end
    return M.gatherPlan
end

local function chooseCrafter(e)
    local valid={};for _,key in ipairs(e.holders)do valid[key]=true end
    if M.crafterPicked and M.crafter and valid[M.crafter]then return end
    local me=Z.accountCharacterKey
    if me and valid[me]then M.crafter=me
    elseif M.characterKey and valid[M.characterKey]then M.crafter=M.characterKey
    else M.crafter=e.holders[1]end
end

local function openRecipe(e)
    M.recipeKey=entryKey(e);M.detailOpen=true;M.gather=false
    U.CloseDropdowns();U.RefreshMyCharacters()
end

-- Row models of the list: a section row per profession (with the count), then its recipes.
local function buildModels(entries,names,fallbackIcon)
    local counts={}
    for _,e in ipairs(entries)do
        if not counts[e.profession]then counts[e.profession]=0 end
        counts[e.profession]=counts[e.profession]+1
    end
    local items,last={},nil
    for _,e in ipairs(entries)do
        if e.profession~=last then
            last=e.profession
            local title=tr(L.ProfessionName(e.profession))
            items[#items+1]={text=title..' · '..counts[e.profession],noWrap=true,height=SECTION_HEIGHT,header=true,section=true,textInset=0,
                display=paint('goldBright',title)..paint('dim',' · '..counts[e.profession])}
        end
        local holders={}
        for _,key in ipairs(e.holders)do holders[#holders+1]=names[key]or key end
        local subtitle=table.concat(holders,', ')
        local icon=e.itemID and e.itemID>0 and M.S.itemIcon(e.itemID)or nil
        local item={text=e.name,noWrap=true,height=ROW_HEIGHT,subtitle=subtitle,selected=M.recipeKey==entryKey(e),
            display=paint('text',e.name),subtitleDisplay=paint('textSoft',subtitle),icon=icon or fallbackIcon,iconSize=26,textInset=42,
            click=function()openRecipe(e)end,entry=e}
        items[#items+1]=item
    end
    return items
end

local function scanNote(characterKey,profession,byKey)
    if not characterKey then return nil end
    local r=byKey[characterKey];if not r then return nil end
    local R=Z.AccountRecipes
    local function incomplete(p)return R.Coverage(characterKey,p.name)~='complete'end
    for _,list in ipairs({r.primary or{},r.secondary or{}})do
        for _,p in ipairs(list)do
            if(not profession or L.ProfessionName(p.name)==profession)and incomplete(p)then
                return tr('Recipe scan incomplete – missing recipes are not "not learned".')
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Route selection {characterKey, profession, recipe}
-- ---------------------------------------------------------------------------------------------
function M.Apply(selection)
    if type(selection)~='table'then return end
    M.profession=type(selection.profession)=='string'and L.ProfessionName(selection.profession)or nil
    M.characterKey=type(selection.characterKey)=='string'and selection.characterKey or nil
    M.wantRecipe=selection.recipe
    M.recipeKey=nil;M.gather=false
    M.detailOpen=selection.recipe~=nil
end
local previousApply=U.ApplyMyCharactersSelection
function U.ApplyMyCharactersSelection(route)
    if previousApply then previousApply(route)end
    if type(route)=='table'and route.view=='recipes'then
        M.Apply(type(route.selection)=='table'and route.selection or nil)
        U.RefreshMyCharacters()
    end
end

-- ---------------------------------------------------------------------------------------------
-- Tab
-- ---------------------------------------------------------------------------------------------
local function placeSelector(s,x,y,w)H.place(s.caption,x,y);H.place(s.button,x,y-17);s:SetWidth(w)end
local function placeEdit(e,x,y,w)H.place(e.caption,x,y,w);H.place(e,x,y-17,w)end
local function placeList(view,x,y,w,h)
    local changed=view:GetWidth()~=w or view:GetHeight()~=h
    H.place(view,x,y,w,h);view.width,view.height=w-24,h;view.child:SetWidth(w-24)
    if changed and view.zenialRender then view.zenialRender()end
end
local function setOptions(selector,values,selected,signature)
    if selector.zenialSignature~=signature then selector.zenialSignature=signature;selector:SetOptions(values,selected)end
    selector:SetText(selected)
end

local function create(body,S)
    local kit=K()
    M.S=S;M.body=body
    local function reset()U.RefreshMyCharacters()end
    M.search=S.edit(body,'Search recipe',0,0,300,64);M.search:SetScript('OnTextChanged',reset)
    if Z.Kit and T then
        local icon=Z.Kit.Icon(M.search,'search',14,'muted');icon:SetPoint('LEFT',8,0)
        if M.search.SetTextInsets then M.search:SetTextInsets(26,8,4,4)end
    end
    M.professionSelector=S.selector(body,'Profession',0,0,140,{ALL},function(value)
        M.profession=value~=ALL and value or nil;M.recipeKey=nil;M.detailOpen=false;reset()
    end,function(value)return value==ALL and tr('All')or tr(L.ProfessionName(value))end)
    M.characterSelector=S.selector(body,'Character',0,0,140,{ALL},function(value)
        M.characterKey=value~=ALL and value or nil;M.recipeKey=nil;M.detailOpen=false;reset()
    end,function(value)return value==ALL and tr('All')or(M.names and M.names[value])or value end)
    M.note=kit.Text(body,'','caption','dim');M.note:SetWordWrap(true);M.note:SetJustifyH('LEFT')
    M.list=S.list(body,0,0,300,200)
    -- Detail head (fixed): back, item slot, names, holders, crafter and count.
    M.back=S.button(body,'Back to list',0,0,120,function()M.detailOpen=false;U.CloseDropdowns();U.RefreshMyCharacters()end)
    M.slot=kit.ItemSlot(body,40)
    M.title=kit.Text(body,'','heading','goldBright');M.title:SetWordWrap(false);M.title:SetJustifyH('LEFT');M.title:SetHeight(18)
    M.sub=kit.Text(body,'','caption','dim');M.sub:SetWordWrap(false);M.sub:SetJustifyH('LEFT');M.sub:SetHeight(14)
    M.holders=kit.Text(body,'','caption','textSoft');M.holders:SetWordWrap(true);M.holders:SetJustifyH('LEFT')
    M.crafterSelector=S.selector(body,'Crafter',0,0,200,{ALL},function(value)
        M.crafter=value;M.crafterPicked=true;M.gather=false;reset()
    end,function(value)return(M.names and M.names[value])or value end)
    M.craftsEdit=S.edit(body,'Crafts',0,0,90,3)
    M.craftsEdit:SetScript('OnTextChanged',function(self)
        if M.settingCrafts then return end
        local text=self:GetText()or''
        local n=tonumber(text:match('^%d+$'))
        if n then
            n=math.max(1,math.min(999,n))
            if n~=tonumber(text)then M.settingCrafts=true;self:SetText(tostring(n));M.settingCrafts=false end
            if n~=M.crafts then M.crafts=n;reset()end
        end
    end)
    M.craftsEdit:SetScript('OnEditFocusLost',function(self)
        M.settingCrafts=true;self:SetText(tostring(M.crafts));M.settingCrafts=false
    end)
    M.craftsEdit:SetText('1')
    -- Scroll area: material table, summary, gather plan. Flat, nothing to select inside.
    M.scroll=S.list(body,0,0,300,200);kit.InfoBlock(M.scroll)
    M.child=M.scroll.child
    M.pools.heads=newPool(function(parent)return kit.SectionHeader(parent,'')end)
    M.pools.texts=newPool(createText)
    M.pools.rows=newPool(createMaterialRow)
    M.gatherButton=T.Button(M.child,tr('Gather materials'),180,28,function()M.gather=not M.gather;U.RefreshMyCharacters()end,'primary')
    M.entries={};M.models={};M.names={}
end

local function refresh(rows,context)
    local R,O=Z.AccountRecipes,Z.AccountOverview
    M.context=context
    local names,byKey={},{}
    for _,r in ipairs(O.List())do names[r.key]=r.name;byKey[r.key]=r end
    M.names=names
    local keys,scoped={},{}
    for _,r in ipairs(context.scoped)do keys[r.key]=true;scoped[#scoped+1]=r end
    table.sort(scoped,function(a,b)if a.name~=b.name then return a.name<b.name end;return a.key<b.key end)
    if M.characterKey and not keys[M.characterKey]then M.characterKey=nil end
    -- Filter options: professions with recipes in the shown scope (of the chosen character), all scope characters.
    local professions,seen={},{}
    local function addProfession(p)if p and not seen[p]then seen[p]=true;professions[#professions+1]=p end end
    for _,r in ipairs(scoped)do
        if not M.characterKey or r.key==M.characterKey then for p in pairs(R.Counts(r.key))do addProfession(p)end end
    end
    addProfession(M.profession)
    table.sort(professions)
    local professionValues={ALL};for _,p in ipairs(professions)do professionValues[#professionValues+1]=p end
    local characterValues={ALL};for _,r in ipairs(scoped)do characterValues[#characterValues+1]=r.key end
    setOptions(M.professionSelector,professionValues,M.profession or ALL,table.concat(professionValues,'\1'))
    setOptions(M.characterSelector,characterValues,M.characterKey or ALL,table.concat(characterValues,'\1'))
    -- The list is searched and the rows are built again only when the index, a filter, the search text or the
    -- characters changed (also see M.modelKey below).
    local query=trim(M.search:GetText());local scopedKeys,nameParts={},{}
    for _,r in ipairs(scoped)do scopedKeys[#scopedKeys+1]=r.key end
    local allKeys={};for key in pairs(names)do allKeys[#allKeys+1]=key end
    table.sort(allKeys);for _,key in ipairs(allKeys)do nameParts[#nameParts+1]=key..'='..names[key]end
    local namesKey=table.concat(nameParts,'\1')
    local entriesKey=table.concat({R.Index().sig,M.profession or'',M.characterKey or'',query,table.concat(scopedKeys,'\1')},'\2')
    if M.entriesKey~=entriesKey or not M.entries then
        M.entriesKey=entriesKey
        M.entries=R.List({keys=keys,profession=M.profession,characterKey=M.characterKey,query=query})
    end
    local entries=M.entries
    -- Selected recipe: the requested one, the kept one, else the first.
    local byEntry,chosen={},nil
    for _,e in ipairs(entries)do byEntry[entryKey(e)]=e end
    if M.wantRecipe~=nil then
        for _,e in ipairs(entries)do
            if e.id==M.wantRecipe or tostring(e.id)==tostring(M.wantRecipe)or entryKey(e)==M.wantRecipe then chosen=e;break end
        end
        if chosen then M.recipeKey=entryKey(chosen);M.detailOpen=true end
        M.wantRecipe=nil
    end
    chosen=chosen or(M.recipeKey and byEntry[M.recipeKey])or entries[1]
    if chosen and M.recipeKey~=entryKey(chosen)then M.recipeKey=entryKey(chosen);M.gather=false end
    if not chosen then M.recipeKey=nil;M.detailOpen=false end
    M.entry=chosen
    if chosen then chooseCrafter(chosen)end
    -- Hint and scan note.
    local total=0
    for _,r in ipairs(scoped)do for _,n in pairs(R.Counts(r.key))do total=total+n end end
    local hint=#entries==0 and(total==0 and tr('No recipes recorded yet.')or tr('No matching recipes.'))or nil
    U.SetEmptyHint(M.list,hint,hint and'search'or nil)
    -- The scope line names the realm, faction and hidden choice this list applies (the filter row is not shown here).
    local scanText=scanNote(M.characterKey,M.profession,byKey);local scope=H.scopeText(context)
    M.noteText=scanText and(scope..'\n'..scanText)or scope
    local modelKey=table.concat({entriesKey,namesKey,tostring(M.recipeKey),tostring(M.itemRev)},'\2')
    if M.modelKey~=modelKey then
        M.modelKey=modelKey
        M.models=buildModels(entries,names,{file=QUESTION})
        M.S.rows(M.list,M.models,ROW_HEIGHT)
    end
    M.refreshed=true
end

-- Item data arrived: redraw once in a while (names and icons only).
local previousItemData=U.OnItemData
function U.OnItemData(...)
    if previousItemData then previousItemData(...)end
    M.itemRev=(M.itemRev or 0)+1
    if not M.refreshed or not U.frame or not U.frame:IsShown()or U.page~=6 or U.myCharactersTab~='recipes'or not U.myCharactersBuilt then return end
    local now=A.Clock()
    if now-(M.itemRedrawAt or 0)<.5 then
        if not M.itemRedrawPending and C_Timer and C_Timer.After then
            M.itemRedrawPending=true
            C_Timer.After(.5,function()M.itemRedrawPending=false;M.itemRedrawAt=A.Clock();U.RefreshMyCharacters()end)
        end
        return
    end
    M.itemRedrawAt=now;U.RefreshMyCharacters()
end

-- ---------------------------------------------------------------------------------------------
-- Detail
-- ---------------------------------------------------------------------------------------------
local function materialName(r)return itemName(r.itemID)end
local function buildMaterialTable(y,w,m)
    y=y+sectionHead(y,w,tr('Materials'),#m.rows)
    -- Column captions.
    local nameW=math.max(60,w-COL_NEED-COL_BAGS-COL_BANK-COL_MISSING-36)
    local function caption(x,cw,text,justify)
        local fs=take(M.pools.texts,M.child);fs:SetWordWrap(false);T.Font(fs,'caption','dim');fs:SetJustifyH(justify)
        fs:SetText(text);put(fs,x,y,cw,14)
    end
    caption(36,nameW,tr('Material'),'LEFT')
    local x=w-COL_NEED-COL_BAGS-COL_BANK-COL_MISSING
    caption(x,COL_NEED-8,tr('Required'),'RIGHT');x=x+COL_NEED
    caption(x,COL_BAGS-8,tr('Bags'),'RIGHT');x=x+COL_BAGS
    caption(x,COL_BANK-8,tr('Bank/Alts'),'RIGHT');x=x+COL_BANK
    caption(x,COL_MISSING-8,tr('Missing'),'RIGHT')
    y=y+18
    local anyPartial,anyStale=false,false
    for _,r in ipairs(m.rows)do
        local row=take(M.pools.rows,M.child)
        row.material=r
        row:SetSize(w,MATERIAL_HEIGHT);put(row,0,y)
        row.slot:SetItem({itemID=r.itemID,icon=itemIconFile(r.itemID)or QUESTION})
        H.place(row.slot,8,-3)
        local color=STATE_COLOR[r.state]or'text'
        T.Tint(row.accent,'SetColorTexture',color)
        row.name:SetText(materialName(r));H.place(row.name,36,-7,nameW)
        local others=r.total-(r.bags or 0)
        local bagsText=r.bags~=nil and tostring(r.bags)or'?'
        local bankText=(r.partial and r.bags==nil and others==0)and'?'or(tostring(others)..(r.stale and'*'or''))
        if r.partial and bankText~='?'then bankText='~'..bankText end
        local missingText=(r.partial and r.missing>0 and'~'or'')..tostring(r.missing)
        row.need:SetText(tostring(r.needed));row.bags:SetText(bagsText);row.bank:SetText(bankText);row.missing:SetText(missingText)
        T.Font(row.bags,'body',r.state=='direct'and'success'or'text');T.Font(row.missing,'body',color)
        local cx=w-COL_NEED-COL_BAGS-COL_BANK-COL_MISSING
        H.place(row.need,cx,-7,COL_NEED-8);cx=cx+COL_NEED
        H.place(row.bags,cx,-7,COL_BAGS-8);cx=cx+COL_BAGS
        H.place(row.bank,cx,-7,COL_BANK-8);cx=cx+COL_BANK
        H.place(row.missing,cx,-7,COL_MISSING-8)
        row:SetScript('OnClick',function()U.OpenMyCharactersInventory({itemID=r.itemID})end)
        anyPartial=anyPartial or r.partial;anyStale=anyStale or r.stale
        y=y+MATERIAL_HEIGHT
    end
    local notes={}
    if anyPartial then notes[#notes+1]=tr('~ Not every place is recorded.')end
    if anyStale then notes[#notes+1]=tr('* Saved more than 7 days ago.')end
    if #notes>0 then y=y+4+textBlock(y+4,w,table.concat(notes,' '),'caption','dim')end
    return y+8
end

local function countText(n,partial)
    if n==nil then return tr('Not fully calculable')end
    return partial and tr('at least %d',n)or tostring(n)
end
local function buildGather(y,w,m)
    local plan=gatherPlan()
    y=y+sectionHead(y,w,tr('Collect'),nil)
    local lines=0
    for _,t in ipairs(plan.transfers)do
        if not(t.fromKey==M.crafter and t.place=='bags')then
            local who=M.names[t.fromKey]or t.fromKey
            local text=t.count..' × '..itemName(t.itemID)..' · '..tr('from %s',who)..' · '..(t.place=='bank'and tr('Bank')or tr('Bags'))
            y=y+textBlock(y,w,text,'body','text')+4;lines=lines+1
        end
    end
    if lines==0 then y=y+textBlock(y,w,tr('Nothing to collect.'),'body','dim')+4 end
    if #plan.buy>0 then
        y=y+8+sectionHead(y+8,w,tr('To get'),#plan.buy)
        for _,b in ipairs(plan.buy)do y=y+textBlock(y,w,b.count..' × '..itemName(b.itemID),'body','dangerText')+4 end
    end
    return y
end

local function buildDetail(width)
    for _,pool in pairs(M.pools)do pool.used=0 end
    local e=M.entry
    local m=materialsFor(e,M.crafter,M.crafts)
    local y=0
    if not m.known then
        y=y+textBlock(y,width,tr('The materials of this recipe are unknown.'),'body','dim')
        M.gatherButton:Hide()
    else
        y=buildMaterialTable(y,width,m)
        y=y+valueLine(y,width,tr('Craftable now'),countText(m.immediate,false),m.immediate==nil and'dim'or'text')+2
        y=y+valueLine(y,width,tr('Possible account-wide'),countText(m.accountWide,m.accountWidePartial),m.accountWide==nil and'dim'or'text')+10
        M.gatherButton:SetText(tr(M.gather and'Hide plan'or'Gather materials'))
        M.gatherButton:SetWidth(math.max(120,H.buttonTextWidth(M.gatherButton)+28))
        M.gatherButton:ClearAllPoints();M.gatherButton:SetPoint('TOPLEFT',M.child,'TOPLEFT',0,-y);M.gatherButton:Show()
        y=y+36
        if M.gather then y=buildGather(y+8,width,m)end
    end
    for _,pool in pairs(M.pools)do finishPool(pool)end
    M.child:SetHeight(math.max(1,y))
    if M.detailKey~=M.recipeKey then M.detailKey=M.recipeKey;M.scroll.zenialOffset=0;M.scroll:SetVerticalScroll(0)end
    T.UpdateScroll(M.scroll)
end

local function layout(_,_,w,h)
    local entry=M.entry
    local wide=w>=WIDE
    local twoColumn=wide and entry~=nil
    local detailView=entry~=nil and(wide or M.detailOpen)
    local listView=entry==nil or wide or not M.detailOpen
    local lw=twoColumn and math.max(280,math.min(340,math.floor(w*.34)))or w
    for _,c in ipairs({M.search,M.search.caption,M.note,M.list})do H.shown(c,listView)end
    M.professionSelector:SetShown(listView);M.characterSelector:SetShown(listView)
    if not listView then M.professionSelector.popup:Hide();M.characterSelector.popup:Hide()end
    if listView then
        local top
        if lw>=520 then
            local rest=lw-20;local sw=math.floor(rest*.4);local pw=math.floor(rest*.3);local cw=rest-sw-pw
            placeEdit(M.search,0,0,sw);placeSelector(M.professionSelector,sw+10,0,pw);placeSelector(M.characterSelector,sw+pw+20,0,cw)
            top=41
        else
            local half=math.floor((lw-8)/2)
            placeEdit(M.search,0,0,lw);placeSelector(M.professionSelector,0,-48,half);placeSelector(M.characterSelector,half+8,-48,lw-half-8)
            top=89
        end
        M.note:SetText(M.noteText or'');M.note:SetShown(M.noteText~=nil)
        if M.noteText then
            M.note:SetWidth(lw);local noteHeight=math.max(14,math.ceil(M.note:GetStringHeight()))
            H.place(M.note,0,-(top+6),lw,noteHeight);top=top+6+noteHeight
        end
        top=top+8
        placeList(M.list,0,-top,lw,math.max(60,h-top))
    end
    local detailControls={M.slot,M.title,M.sub,M.holders,M.crafterSelector.caption,M.crafterSelector.button,M.craftsEdit,M.craftsEdit.caption,M.scroll,M.back}
    for _,c in ipairs(detailControls)do c:SetShown(detailView)end
    M.back:SetShown(detailView and not wide)
    if not detailView then
        M.crafterSelector:SetShown(false);M.gatherButton:Hide()
        return
    end
    M.crafterSelector:SetShown(true)
    local dx=twoColumn and lw+16 or 0
    local dw=w-dx
    local y=0
    if not wide then H.fitButton(M.back,96);H.place(M.back,dx,-y);y=y+36 end
    local e=entry
    local iconFile=e.itemID>0 and itemIconFile(e.itemID)or nil
    if e.itemID>0 then M.slot:SetItem({itemID=e.itemID,icon=iconFile or QUESTION})else M.slot:SetEmpty()end
    H.place(M.slot,dx,-y)
    M.title:SetText(e.name);H.place(M.title,dx+50,-y,dw-50)
    local sub={}
    if e.itemName~=''and e.itemName~=e.name then sub[#sub+1]=e.itemName end
    sub[#sub+1]=tr(L.ProfessionName(e.profession))
    M.sub:SetText(table.concat(sub,' · '));H.place(M.sub,dx+50,-(y+22),dw-50)
    y=y+48
    local who={};for _,key in ipairs(e.holders)do who[#who+1]=M.names[key]or key end
    M.holders:SetText(tr('Known by: %s',table.concat(who,', ')));M.holders:SetWidth(dw)
    local holderHeight=math.max(14,math.min(28,math.ceil(M.holders:GetStringHeight())))
    H.place(M.holders,dx,-y,dw,holderHeight);y=y+holderHeight+8
    local options={};for _,key in ipairs(e.holders)do options[#options+1]=key end
    setOptions(M.crafterSelector,options,M.crafter or options[1],table.concat(options,'\1')..'|'..tostring(M.names[options[1]]))
    local craftsWidth=90
    placeSelector(M.crafterSelector,dx,-y,math.max(120,dw-craftsWidth-10))
    placeEdit(M.craftsEdit,dx+dw-craftsWidth,-y,craftsWidth)
    if not M.craftsEdit:HasFocus()and M.craftsEdit:GetText()~=tostring(M.crafts)then
        M.settingCrafts=true;M.craftsEdit:SetText(tostring(M.crafts));M.settingCrafts=false
    end
    y=y+49
    local scrollHeight=math.max(60,h-y)
    H.place(M.scroll,dx,-y,dw,scrollHeight);M.scroll.width,M.scroll.height=dw-24,scrollHeight;M.child:SetWidth(dw-24)
    buildDetail(dw-24)
end

U.RegisterMyCharactersTab('recipes',{filters=false,create=create,refresh=refresh,layout=layout})
return U
