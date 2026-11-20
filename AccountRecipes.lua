-- Account-wide recipe index and material availability over the player's own
-- characters. Local only: it reads the saved profiles and the stored bag and
-- bank amounts of AccountOverview and never publishes, sends or exports them.
-- The index is rebuilt only when its signature changes. A place that was never
-- recorded is unknown, never zero: results then say "partial" instead of
-- showing a falsely low number. Planning only; nothing here moves items.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local R={MAX_LIST=2000,STALE=7*86400};Z.AccountRecipes=R
local P=Z.MaterialPlanner
local function characters()return Z.account and type(Z.account.characters)=="table"and Z.account.characters or{}end
local function profile(key)
    if Z.db and key==Z.storageKey then return Z.db end
    local all=type(ZenialCommunityDB)=="table"and ZenialCommunityDB.characters;local p=type(all)=="table"and all[key]
    return type(p)=="table"and p or nil
end
local function sortedKeys()local out={};for key in pairs(characters())do out[#out+1]=key end;table.sort(out);return out end
local function number(v)return type(v)=="number"and v or 0 end
local function signature(keys)
    local O=Z.AccountOverview;local rev,at,n=0,0,0
    for _,key in ipairs(keys)do
        local p=profile(key)
        if p then rev=rev+number(p.recipeRev);at=at+number(p.professionsAt);n=n+(type(p.recipes)=="table"and#p.recipes or 0)end
    end
    return#keys..":"..(O and O.revision or 0)..":"..rev..":"..at..":"..n
end
function R.Index()
    local keys=sortedKeys();local sig=signature(keys)
    if R.index and R.index.sig==sig then return R.index end
    local by,entries,counts={},{},{}
    for _,key in ipairs(keys)do
        local p=profile(key);local seen={};local mine={};counts[key]=mine
        for _,row in ipairs(p and type(p.recipes)=="table"and p.recipes or{})do
            if type(row)=="table"then
                local profession=L.ProfessionName(row.profession or"")
                local clean={id=row.id,itemID=row.itemID or 0,name=row.name,itemName=row.itemName or"",profession=profession,materials=row.materials or""}
                local id=L.ValidRecipe(clean)and profession.."\0"..clean.id
                if id and not seen[id]then
                    seen[id]=true;mine[profession]=(mine[profession]or 0)+1
                    local e=by[id]
                    if not e then
                        e={key=key,id=clean.id,itemID=clean.itemID,name=clean.name,itemName=clean.itemName,profession=profession,materials=clean.materials,holders={},
                            search=string.lower(clean.name.." "..clean.itemName)};by[id]=e;entries[#entries+1]=e
                    elseif e.materials==""and clean.materials~=""then e.materials=clean.materials end
                    e.holders[#e.holders+1]=key
                end
            end
        end
    end
    table.sort(entries,function(a,b)
        if a.profession~=b.profession then return a.profession<b.profession end
        if a.name~=b.name then return a.name<b.name end
        return a.id<b.id
    end)
    R.index={sig=sig,entries=entries,by=by,counts=counts};return R.index
end
-- filter: keys (set of allowed characters), profession, characterKey, query.
function R.List(filter)
    filter=type(filter)=="table"and filter or{}
    local out={};local query=type(filter.query)=="string"and string.lower(filter.query)or""
    for _,e in ipairs(R.Index().entries)do
        if not filter.profession or e.profession==filter.profession then
            local ok=true
            if query~=""and not e.search:find(query,1,true)then ok=false end
            if ok and(filter.keys or filter.characterKey)then
                ok=false
                for _,holder in ipairs(e.holders)do
                    if(not filter.characterKey or holder==filter.characterKey)and(not filter.keys or filter.keys[holder])then ok=true;break end
                end
            end
            if ok then out[#out+1]=e;if#out>=R.MAX_LIST then break end end
        end
    end
    return out
end
function R.Counts(key)
    local out={};for profession,n in pairs(R.Index().counts[key]or{})do out[profession]=n end;return out
end
-- complete: the profession was read completely; partial: it was read, but not
-- completely; unknown: not learned or never scanned.
function R.Coverage(key,profession)
    local p=profile(key);profession=L.ProfessionName(profession or"");if not p or profession==""then return"unknown"end
    local learned=type(p.professions)~="table"or#p.professions==0
    for _,row in ipairs(type(p.professions)=="table"and p.professions or{})do if L.ProfessionName(row.name)==profession then learned=true end end
    if not learned then return"unknown"end
    local state,scan
    for name,value in pairs(type(p.recipeStates)=="table"and p.recipeStates or{})do if L.ProfessionName(name)==profession then state=value end end
    for name,at in pairs(type(p.recipeScans)=="table"and p.recipeScans or{})do if L.ProfessionName(name)==profession then scan=at end end
    if type(state)=="table"then
        local at=state.at or 0
        return state.complete==true and"complete"or"partial",at>0 and at or nil
    end
    if type(scan)=="number"then return"partial",scan end
    return"unknown"
end
local function scope(crafterKey)
    local me=characters()[crafterKey];local out={}
    if not me then return out end
    for key,c in pairs(characters())do if c.realm==me.realm and c.faction==me.faction then out[#out+1]=key end end
    table.sort(out);return out
end
-- Normalized saved shopping lists of a character; lists of other characters
-- are cached per saved table and revision.
local function plansOf(key)
    if Z.db and key==Z.storageKey then return P.store end
    local p=profile(key);local raw=p and p.materialPlans;if type(raw)~="table"then return nil end
    local c=R.planCache and R.planCache[key]
    if not c or c.raw~=raw or c.revision~=raw.revision then
        c={raw=raw,revision=raw.revision,store=P.Normalize(raw)}
        R.planCache=R.planCache or{};R.planCache[key]=c
    end
    return c.store
end
local function recordedAt(s,place)return s and type(s[place])=="table"and s[place.."At"]or nil end
local function always()return true end
function R.Materials(entry,crafterKey,crafts)
    crafts=L.Int(crafts,1,100000)and crafts or 1
    local ingredients=type(entry)=="table"and P.ParseIngredients(entry.materials)
    local out={crafts=crafts,known=ingredients~=nil,rows={}}
    if not ingredients then return out end
    local O=Z.AccountOverview;local keys=scope(crafterKey);local store=O and O.store
    local stock=O and O.Stock(keys)or{};local now=A.Now()
    local function row(key)return store and store.characters[key]end
    local function amount(id,key,place)
        local s=row(key);if not s or type(s[place])~="table"then return nil end
        local per=stock[id]and stock[id][key];return per and per[place]or 0
    end
    -- Amounts of this recipe's items that saved shopping lists already claim.
    local reserved={}
    for _,key in ipairs(keys)do
        local plans=plansOf(key);local counts={}
        for _,ing in ipairs(ingredients)do counts[ing.itemID]=amount(ing.itemID,key,"bags")end
        reserved[key]=plans and P.Reservations(plans,counts,key==Z.storageKey and P.Active or always)or{}
    end
    local immediate,accountWide,anyStand=nil,nil,false
    for _,key in ipairs(keys)do local s=row(key);if s and(type(s.bags)=="table"or type(s.bank)=="table")then anyStand=true end end
    out.accountWidePartial=false
    for _,ing in ipairs(ingredients)do
        local id,needed=ing.itemID,ing.perCraft*crafts
        local r={itemID=id,perCraft=ing.perCraft,needed=needed,reserved=reserved[crafterKey]and reserved[crafterKey][id]or 0,elsewhere={},partial=false,stale=false}
        local total=0
        for _,key in ipairs(keys)do
            local bags,bank=amount(id,key,"bags"),amount(id,key,"bank")
            local bagsAt,bankAt=recordedAt(row(key),"bags"),recordedAt(row(key),"bank")
            if bags~=nil then bags=math.max(0,bags-(reserved[key]and reserved[key][id]or 0))end
            -- A place never recorded (e.g. a bank never opened) is unknown, not empty.
            if bags==nil or bank==nil then r.partial=true end
            total=total+(bags or 0)+(bank or 0)
            if(bags or 0)>0 and bagsAt and now-bagsAt>R.STALE or(bank or 0)>0 and bankAt and now-bankAt>R.STALE then r.stale=true end
            if key==crafterKey then r.bags,r.bank=bags,bank
            elseif bags~=nil or bank~=nil then r.elsewhere[#r.elsewhere+1]={key=key,bags=bags,bank=bank,bagsAt=bagsAt,bankAt=bankAt}end
        end
        r.total=total;r.missing=math.max(0,needed-total)
        r.state=r.bags and r.bags>=needed and"direct"or total>=needed and"elsewhere"or"missing"
        out.rows[#out.rows+1]=r
        if immediate~=false then
            if r.bags==nil then immediate=false else local n=math.floor(r.bags/r.perCraft);if immediate==nil or n<immediate then immediate=n end end
        end
        local n=math.floor(total/r.perCraft);if accountWide==nil or n<accountWide then accountWide=n end
        if r.partial then out.accountWidePartial=true end
    end
    out.immediate=immediate or nil
    out.accountWide=anyStand and accountWide or nil
    if not anyStand then out.accountWidePartial=false end
    return out
end
-- Planning only. Order: crafter bags, crafter bank, then other characters
-- (bags before banks, largest amount first). What is left is to buy.
function R.Gather(materials,crafterKey)
    local plan={transfers={},buy={}}
    for _,r in ipairs(type(materials)=="table"and materials.rows or{})do
        local left=r.needed
        local function take(key,place,n)
            local c=math.min(left,n or 0)
            if c>0 then plan.transfers[#plan.transfers+1]={itemID=r.itemID,fromKey=key,place=place,count=c};left=left-c end
        end
        take(crafterKey,"bags",r.bags);take(crafterKey,"bank",r.bank)
        for _,place in ipairs({"bags","bank"})do
            local list={};for _,e in ipairs(r.elsewhere)do if(e[place]or 0)>0 then list[#list+1]=e end end
            table.sort(list,function(a,b)if a[place]~=b[place]then return a[place]>b[place]end;return a.key<b.key end)
            for _,e in ipairs(list)do take(e.key,place,e[place])end
        end
        if left>0 then plan.buy[#plan.buy+1]={itemID=r.itemID,count=left}end
    end
    return plan
end
return R
