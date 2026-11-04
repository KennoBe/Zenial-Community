-- Private character shopping lists. Inventory is an observation, manual marks
-- are assertions, and only CraftOrders can confirm a handoff. No wire format.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local P={VERSION=1,MAX_PLANS=100,MAX_INGREDIENTS=24,MAX_AMOUNT=2147483646,MAX_OFFERS=20,SCAN_BATCH=50};Z.MaterialPlanner=P
local TERMINAL={COMPLETED=true,DECLINED=true,CANCELLED=true,EXPIRED=true}
local function copy(row)local out={};for k,v in pairs(row)do if type(v)~="table"then out[k]=v end end;return out end
local function recipeCopy(row)return{id=row.id,itemID=row.itemID or 0,name=row.name,itemName=row.itemName or"",profession=row.profession or"",materials=row.materials or""}end
local function changed()P.store.revision=math.min(P.store.revision+1,P.MAX_AMOUNT);if Z.MarkDirty then Z.MarkDirty("materials")end end
function P.ParseIngredients(text)
    if type(text)~="string"or#text>320 then return nil,"Ingredient data is invalid."end
    if text==""then return nil,"Ingredient details were not supplied by this crafter."end
    local byID,n={},0
    for token in(text..","):gmatch("([^,]*),")do
        local id,amount=token:match("^(%d+):(%d+)$");id,amount=tonumber(id),tonumber(amount);n=n+1
        if n>P.MAX_INGREDIENTS or not L.Int(id,1,10000000)or not L.Int(amount,1,1000000)then return nil,"Ingredient data is invalid."end
        byID[id]=(byID[id]or 0)+amount;if byID[id]>P.MAX_AMOUNT then return nil,"Material quantities are too large."end
    end
    local out={};for id,amount in pairs(byID)do out[#out+1]={itemID=id,perCraft=amount}end
    table.sort(out,function(a,b)return a.itemID<b.itemID end);return out
end
function P.Calculate(recipe,crafts,inventory,manual,allocations)
    if not L.ValidRecipe(recipe)then return nil,"Recipe data is unavailable."end
    if not L.Int(crafts,1,100000)then return nil,"Craft count must be 1 to 100000."end
    local ingredients,reason=P.ParseIngredients(recipe.materials);local out={rows={},reason=reason,crafts=crafts}
    for _,ingredient in ipairs(ingredients or{})do
        local id,needed=ingredient.itemID,ingredient.perCraft*crafts
        if needed>P.MAX_AMOUNT then return nil,"Material quantities are too large."end
        local available=inventory and inventory.known and not inventory.unknown[id]and(inventory.counts[id]or 0)or nil
        local allocated=available~=nil and(allocations and allocations[id]or math.min(available,needed))or nil
        local secured=math.min(needed,manual and manual[id]or 0)
        -- Manual marks may describe the same physical stack: never add them to
        -- observed inventory. Allocations prevent reuse across saved active lists.
        local covered=math.max(secured,allocated or 0)
        out.rows[#out.rows+1]={itemID=id,perCraft=ingredient.perCraft,needed=needed,available=available,allocated=allocated,
            reservedElsewhere=available and 0 or nil,manual=secured,
            missing=allocated~=nil and math.max(0,needed-allocated)or nil,open=math.max(0,needed-covered)}
    end
    return out
end
local function validRef(raw)
    return type(raw)=="table"and(raw.direction=="incoming"or raw.direction=="outgoing")and L.ValidIdentityKey(raw.peer)
        and L.Text(raw.id,32)and raw.id:match("^[%d%.]+$")and L.Int(raw.recipeID,1,10000000)and L.Int(raw.itemID,0,10000000)
        and L.Int(raw.quantity,1,100000)and L.Int(raw.createdAt,1,4102444800)
end
local function sameOrder(a,b)
    return a and b and a.id==b.id and a.peer==b.peer and a.direction==b.direction and a.recipeID==b.recipeID
        and a.itemID==b.itemID and a.quantity==b.quantity and a.createdAt==b.createdAt
end
function P.Normalize(raw)
    local empty={version=P.VERSION,seq=0,revision=0,plans={}}
    if raw==nil then return empty end
    if type(raw)~="table"then return empty,"invalid"end
    if raw.version~=P.VERSION then return nil,"unsupported"end
    if not L.Int(raw.seq,0,P.MAX_AMOUNT)or not L.Int(raw.revision,0,P.MAX_AMOUNT)or type(raw.plans)~="table"then return empty,"invalid"end
    local out={version=P.VERSION,seq=raw.seq,revision=raw.revision,plans={}};local n=0;local orders={}
    for id,row in pairs(raw.plans)do
        n=n+1;if n>P.MAX_PLANS then return empty,"invalid"end
        local seq=type(id)=="string"and tonumber(id:match("^m(%d+)$"))
        if not L.Int(seq,1,raw.seq)or id~="m"..seq or type(row)~="table"or row.id~=id or not L.ValidRecipe(row.recipe)
            or not L.Int(row.createdAt,1,4102444800)or not L.Int(row.updatedAt,row.createdAt,4102444800)
            or not L.Int(row.observedAt,0,4102444800)or type(row.observedStock)~="table"or type(row.manual)~="table"then return empty,"invalid"end
        local calculated=P.Calculate(row.recipe,row.crafts);if not calculated then return empty,"invalid"end
        local plan={id=id,recipe=recipeCopy(row.recipe),crafts=row.crafts,createdAt=row.createdAt,updatedAt=row.updatedAt,
            observedAt=row.observedAt,observedStock={},manual={},needs={}}
        local needs={};for _,r in ipairs(calculated.rows)do needs[r.itemID]=r.needed;plan.needs[#plan.needs+1]={itemID=r.itemID,quantity=r.needed}end
        for itemID,amount in pairs(row.manual)do if not needs[itemID]or not L.Int(amount,0,needs[itemID])then return empty,"invalid"end;plan.manual[itemID]=amount end
        for itemID,amount in pairs(row.observedStock)do if not needs[itemID]or not L.Int(amount,0,P.MAX_AMOUNT)then return empty,"invalid"end;plan.observedStock[itemID]=amount end
        if row.order~=nil then
            if not validRef(row.order)or row.order.recipeID~=row.recipe.id or row.order.itemID~=row.recipe.itemID then return empty,"invalid"end
            local token=row.order.direction..":"..row.order.peer..":"..row.order.id
            if orders[token]then return empty,"invalid"end;orders[token]=true;plan.order=copy(row.order)
        end
        out.plans[id]=plan
    end
    return out
end
function P.Initialize()
    P.store,P.loadError=P.Normalize(Z.db.materialPlans);P.inventory,P.scan,P.inventoryClock=nil,nil,nil
    if P.store then Z.db.materialPlans=P.store end
end
function P.ReadInventory(force)
    local clock=A.Clock()
    if force or not P.inventory or clock<(P.inventoryClock or 0)or clock-(P.inventoryClock or 0)>=2 then P.inventory=A.ReadBagInventory();P.inventoryClock=clock end;return P.inventory
end
function P.InvalidateInventory()P.inventory=nil;if Z.MarkDirty then Z.MarkDirty("materials")end end
function P.Get(id)return P.store and P.store.plans[id]end
function P.List()
    local out={};for _,plan in pairs(P.store and P.store.plans or{})do out[#out+1]=plan end
    table.sort(out,function(a,b)if a.createdAt~=b.createdAt then return a.createdAt<b.createdAt end;return tonumber(a.id:sub(2))<tonumber(b.id:sub(2))end);return out
end
function P.Order(plan)
    local ref=plan and plan.order;if not ref then return nil end
    local order=Z.CraftOrders.Get(ref.id,ref.peer,ref.direction);return sameOrder(ref,order)and order or nil
end
function P.State(plan)
    if not plan.order then return"LOCAL"end
    local order=P.Order(plan);return order and order.state or"UNAVAILABLE"
end
function P.Active(plan)local state=P.State(plan);return state~="UNAVAILABLE"and not TERMINAL[state]end
function P.ForOrder(order)
    for _,plan in ipairs(P.List())do if sameOrder(plan.order,order)then return plan end end
end
function P.AttachToOrder(id,order)
    local plan=P.Get(id)
    if not plan or not validRef(order)or plan.recipe.id~=order.recipeID or plan.recipe.itemID~=order.itemID
        or not sameOrder(order,Z.CraftOrders.Get(order.id,order.peer,order.direction))then return false,"Order is unavailable."end
    if plan.order and not sameOrder(plan.order,order)then return false,"This shopping list already belongs to another order."end
    local existing=P.ForOrder(order);if existing and existing.id~=id then return false,"This order already has a shopping list."end
    if A.Now()<1 then return false,"Server time is unavailable."end
    if not plan.order then plan.order={id=order.id,peer=order.peer,direction=order.direction,recipeID=order.recipeID,itemID=order.itemID,quantity=order.quantity,createdAt=order.createdAt};plan.updatedAt=A.Now();changed()end
    return true
end
function P.BuildShoppingList(recipe,crafts)
    if not P.store then return nil,"Saved material plans use an unsupported version. Data was preserved."end
    local calculated,reason=P.Calculate(recipe,crafts,P.ReadInventory(true));if not calculated then return nil,reason end
    if#P.List()>=P.MAX_PLANS or P.store.seq>=P.MAX_AMOUNT then return nil,"Shopping list storage is full (100 lists)."end
    local now=A.Now();if now<1 then return nil,"Server time is unavailable."end
    P.store.seq=P.store.seq+1;local id="m"..P.store.seq
    local plan={id=id,recipe=recipeCopy(recipe),crafts=crafts,createdAt=now,updatedAt=now,observedAt=P.inventory.at,observedStock={},manual={},needs={}}
    for _,r in ipairs(calculated.rows)do plan.needs[#plan.needs+1]={itemID=r.itemID,quantity=r.needed};plan.observedStock[r.itemID]=r.available end
    P.store.plans[id]=plan;P.loadError=nil;changed();return id
end
function P.UpdateProgress(id,itemID,amount)
    local plan=P.Get(id);if not plan or not P.Active(plan)then return false,"This material plan is closed or its order is unavailable."end
    local needed;for _,r in ipairs(plan.needs)do if r.itemID==itemID then needed=r.quantity end end
    if not needed or not L.Int(amount,0,needed)then return false,"Manual amount is invalid."end
    if A.Now()<1 then return false,"Server time is unavailable."end
    if(plan.manual[itemID]or 0)~=amount then plan.manual[itemID]=amount;plan.updatedAt=A.Now();changed()end;return true
end
function P.Delete(id)if P.Get(id)then P.store.plans[id]=nil;changed();return true end;return false end
function P.Progress(id,force)
    local plan=P.Get(id);if not plan then return nil end
    local inventory=P.ReadInventory(force);local remaining,allocation,total={},{},{}
    -- Oldest active list first, including marked materials: a marked quantity
    -- might be in these bags. Terminal/unavailable orders release reservations.
    for _,saved in ipairs(P.List())do
        local active=P.Active(saved);local current={}
        for _,need in ipairs(saved.needs)do
            local itemID=need.itemID
            if inventory.known and not inventory.unknown[itemID]then
                if remaining[itemID]==nil then remaining[itemID]=inventory.counts[itemID]or 0 end
                current[itemID]=active and math.min(need.quantity,remaining[itemID])or 0
                if active then remaining[itemID]=remaining[itemID]-current[itemID];total[itemID]=(total[itemID]or 0)+current[itemID]end
            end
        end
        if saved.id==id then allocation=current end
    end
    local result=P.Calculate(plan.recipe,plan.crafts,inventory,plan.manual,allocation)
    for _,row in ipairs(result.rows)do row.reservedElsewhere=row.available and((total[row.itemID]or 0)-(row.allocated or 0))or nil end
    return result
end
function P.RecipeForOrder(order)
    local existing=P.ForOrder(order);if existing then return copy(existing.recipe)end
    -- Legacy orders have no ingredient snapshot. Only an exact local recipe can
    -- supply one; names or the output item alone never identify the ingredients.
    for _,recipe in ipairs(Z.db.recipes)do if recipe.id==order.recipeID and recipe.itemID==order.itemID then return copy(recipe)end end
    return{id=order.recipeID,itemID=order.itemID,name=order.recipeName,itemName="",profession=order.profession,materials=""}
end
local function seller(key)
    local contact,peer=Z.db.contacts[key],Z.db.peers[key]
    if not Z.db.consent or not Z.identityReady or Z.offlineOnly or not contact or not peer or Z.db.blocked[key]or key==Z.me.key or not Z.IsOnline(key)then return nil end
    local identity=L.Identity(contact.target)
    for _,character in pairs(Z.account and Z.account.characters or{})do if L.Identity(character.target)==identity then return nil end end
    local data=peer.data
    -- Contacts are keyed by scoped identity; cross-world lounge members are
    -- valid. The existing transport owns scope/region/project verification.
    if not data or data.faction~=Z.me.faction or peer.cap4 and data.generation~=(peer.verifiedSession or peer.session)then return nil end
    return contact,data
end
function P.GetOffer(key,id,itemID)
    local contact,data=seller(key);if not contact or not L.Int(itemID,1,10000000)then return nil end
    for i=1,math.min(3,#(data.market or{}))do
        local offer=data.market[i]
        if type(offer)=="table"and offer.id==id and L.ValidOffer(offer,A.Now())and L.Int(offer.quantity,1,100000)and L.Int(offer.price,0,P.MAX_AMOUNT)and offer.kind=="SELL"and offer.itemID==itemID then
            return{key=key,target=contact.target,o=copy(offer),unitPrice=offer.price/offer.quantity,reachability=Z.Reachability(key)}
        end
    end
end
local function sortOffers(rows)
    table.sort(rows,function(a,b)if a.unitPrice~=b.unitPrice then return a.unitPrice<b.unitPrice end;if a.key~=b.key then return a.key<b.key end;return a.o.id<b.o.id end)
    for i=#rows,P.MAX_OFFERS+1,-1 do rows[i]=nil end
end
function P.FindOffers(itemID,force)
    if not L.Int(itemID,1,10000000)then return{},false end
    local scan=P.scan;local now=A.Clock()
    if force or not scan or scan.itemID~=itemID or scan.done and now-(scan.finishedAt or scan.started)>=5 then
        local keys={};for key in pairs(Z.db.peers)do if#keys>=L.MAX_CONTACTS then break end;keys[#keys+1]=key end;table.sort(keys)
        scan={itemID=itemID,keys=keys,index=1,rows={},started=now,nextBatch=now};P.scan=scan;P.ScanOffers()
    end
    local rows={};for _,row in ipairs(scan.rows)do local current=P.GetOffer(row.key,row.o.id,itemID);if current then rows[#rows+1]=current end end
    sortOffers(rows);return rows,not scan.done
end
function P.ScanOffers()
    local scan=P.scan;if not scan or scan.done or A.Clock()<scan.nextBatch then return end
    scan.nextBatch=A.Clock()+.25;local started=A.Clock();local visited=0
    while scan.index<=#scan.keys and visited<P.SCAN_BATCH do
        local key=scan.keys[scan.index];scan.index=scan.index+1;visited=visited+1
        local contact,data=seller(key)
        if contact then for i=1,math.min(3,#(data.market or{}))do
            local offer=data.market[i]
            -- Reuse existing exact-ID trade matching; this never saves a rule.
            if Z.TradeManager.Match({id="materials",name="",query="",kind="SELL",category="ALL_ITEM_CATEGORIES",itemID=scan.itemID,createdAt=0},offer,contact.target)then
                local row=P.GetOffer(key,offer.id,scan.itemID);if row then scan.rows[#scan.rows+1]=row;sortOffers(scan.rows)end
            end
        end end
        if A.Clock()-started>=.004 then break end
    end
    scan.done=scan.index>#scan.keys
    if scan.done then scan.finishedAt=A.Clock()end
    if Z.MarkDirty then Z.MarkDirty("materialOffers")end
end
function P.Tick()P.ScanOffers()end
return P
