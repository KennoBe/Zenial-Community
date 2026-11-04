local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local I={MAX=2000,pending={}}
Z.Items=I

local CLASS_CATEGORY={
    [0]="CONSUMABLE",[1]="CONTAINER",[2]="WEAPON",[4]="ARMOR",[5]="TRADE_GOODS",
    [6]="PROJECTILE",[7]="TRADE_GOODS",[8]="TRADE_GOODS",[9]="RECIPE",[12]="QUEST_ITEM",
}

local function buildKey()
    local version,build,_,interface=A.Call(GetBuildInfo)
    return tostring(version or"")..":"..tostring(build or"")..":"..tostring(interface or"")
end

local function cleanName(value)
    if type(value)~="string"then return nil end
    value=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H.-|h",""):gsub("|h","")
    value=value:match("^%s*(.-)%s*$")or""
    return L.Text(value,96)and value or nil
end

local function details(fn,value)
    if type(fn)~="function"then return nil end
    local ok,name,link,quality,itemLevel,minLevel,itemType,itemSubType,stack,equipLoc,icon,sellPrice,classID,subclassID=pcall(fn,value)
    if not ok or not A.Safe(name,link,quality,itemLevel,minLevel,itemType,itemSubType,stack,equipLoc,icon,sellPrice,classID,subclassID)then return nil end
    if not L.Text(name,96)then return nil end
    return{name=name,icon=icon,classID=classID,subclassID=subclassID}
end

local function instant(fn,value)
    if type(fn)~="function"then return nil end
    local ok,id,itemType,itemSubType,equipLoc,icon,classID,subclassID=pcall(fn,value)
    if not ok or not A.Safe(id,itemType,itemSubType,equipLoc,icon,classID,subclassID)then return nil end
    if not L.Int(id or 0,1,10000000)then return nil end
    return{id=id,icon=icon,classID=classID,subclassID=subclassID}
end

local function prune()
    local count=L.Count(I.store.rows)
    while count>I.MAX do
        local oldest,oldestAt
        for key,row in pairs(I.store.rows)do
            local at=tonumber(row.at)or 0
            if not oldestAt or at<oldestAt then oldest,oldestAt=key,at end
        end
        if not oldest then break end
        I.store.rows[oldest]=nil;count=count-1
    end
end

function I.Initialize(root)
    local locale=type(GetLocale)=="function"and GetLocale()or""
    local raw=type(root.itemIndex)=="table"and root.itemIndex or{}
    local store={version=1,build=buildKey(),locale=locale,rows={}}
    if raw.version==store.version and raw.build==store.build and raw.locale==store.locale and type(raw.rows)=="table"then
        for key,row in pairs(raw.rows)do
            local id=tonumber(key)
            if L.Int(id or 0,1,10000000)and type(row)=="table"and L.Text(row.name,96)and L.Int(row.classID or 15,0,100)and L.Int(row.subclassID or 0,0,100)then
                store.rows[tostring(id)]={id=id,name=row.name,icon=row.icon,classID=row.classID or 15,subclassID=row.subclassID or 0,at=L.Int(row.at or 0,0,4102444800)and row.at or 0}
            end
        end
    end
    I.store=store;I.pending={};I.pendingCount=0;I.nextExpiry=0;root.itemIndex=store;prune();return store
end

function I.Get(id)
    id=tonumber(id);return I.store and id and I.store.rows[tostring(id)]or nil
end

function I.Tick()
    if A.Clock()<(I.nextExpiry or 0)then return end;I.nextExpiry=A.Clock()+5
    for id,row in pairs(I.pending)do if type(row)~="table"or A.Clock()-row.at>=60 then I.pending[id]=nil;I.pendingCount=math.max(0,(I.pendingCount or 0)-1)end end
end
function I.Observe(id,fallbackName)
    id=tonumber(id)
    if not I.store or not L.Int(id or 0,1,10000000)then return nil end
    local full=details(C_Item and C_Item.GetItemInfo or GetItemInfo,id)
    local fast=instant(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,id)
    local old=I.Get(id);local name=full and full.name or old and old.name or cleanName(fallbackName)
    if name then
        local row={id=id,name=name,icon=full and full.icon or fast and fast.icon or old and old.icon,classID=full and full.classID or fast and fast.classID or old and old.classID or 15,subclassID=full and full.subclassID or fast and fast.subclassID or old and old.subclassID or 0,at=A.Now()}
        I.store.rows[tostring(id)]=row;if I.pending[id]then I.pendingCount=math.max(0,I.pendingCount-1);I.pending[id]=nil end;prune();return row
    end
    local request=C_Item and C_Item.RequestLoadItemDataByID
    I.Tick();if type(request)=="function"and not I.pending[id]and I.pendingCount<I.MAX then I.pending[id]={at=A.Clock()};I.pendingCount=I.pendingCount+1;pcall(request,id)end
end

function I.Resolve(value)
    if type(value)~="string"or#value>256 or not A.Safe(value)then return nil end
    local id=tonumber(value:match("|Hitem:(%d+)")or value:match("^%s*(%d+)%s*$"))
    if id then local row=I.Observe(id,value);return id,row and row.name or cleanName(value)end
    local wanted=cleanName(value);if not wanted then return nil end
    for _,row in pairs(I.store and I.store.rows or{})do if string.lower(row.name)==string.lower(wanted)then return row.id,row.name end end
    local full=details(C_Item and C_Item.GetItemInfo or GetItemInfo,value)
    local fast=instant(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,value)
    if fast then local row=I.Observe(fast.id,full and full.name or wanted);return fast.id,row and row.name or wanted end
    return 0,wanted
end

function I.Category(itemID,kind)
    if kind=="SERVICE"then return"SERVICE"end
    local row=I.Get(itemID)or I.Observe(itemID)
    if not row then return tonumber(itemID)and tonumber(itemID)>0 and"UNCLASSIFIED"or"MISC"end
    return CLASS_CATEGORY[row.classID]or"MISC"
end

function I.Suggestions(query,limit)
    query=string.lower(cleanName(query or"")or"");local out={}
    for _,row in pairs(I.store and I.store.rows or{})do if query==""or string.lower(row.name):find(query,1,true)then out[#out+1]=row end end
    table.sort(out,function(a,b)if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    while#out>(limit or 60)do table.remove(out)end;return out
end

function I.SeedBags()
    if not I.store then return end
    local containers=C_Container
    if containers and type(containers.GetContainerNumSlots)=="function"and type(containers.GetContainerItemID)=="function"then
        for bag=0,4 do local slots=A.Call(containers.GetContainerNumSlots,bag)or 0;for slot=1,math.min(slots,200)do local id=A.Call(containers.GetContainerItemID,bag,slot);if id then I.Observe(id)end end end
    end
end

function I.SeedRecipes(recipes)
    for _,recipe in ipairs(recipes or{})do if recipe.itemID and recipe.itemID>0 then I.Observe(recipe.itemID,recipe.itemName~=""and recipe.itemName or recipe.name)end end
end

function I.SeedMarket(market)
    for _,offer in ipairs(market or{})do if offer.itemID and offer.itemID>0 then I.Observe(offer.itemID,offer.name)end end
end

function I.Seed()
    if not I.store or not Z.db then return end
    I.SeedBags();I.SeedRecipes(Z.db.recipes);I.SeedMarket(Z.db.market)
    for _,peer in pairs(Z.db.peers or{})do I.SeedMarket(peer.data and peer.data.market)end
end

function I.OnEvent(itemID,success)
    itemID=tonumber(itemID);if not itemID then return end
    if success~=false then if I.pending[itemID]then I.pending[itemID]=nil;I.pendingCount=math.max(0,I.pendingCount-1)end;I.Observe(itemID)elseif I.pending[itemID]then I.pending[itemID].failed=true end
    if Z.UI and Z.UI.OnItemData then Z.UI.OnItemData(itemID)end
end
