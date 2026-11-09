-- Account overview of the player's own characters. Local SavedVariables only;
-- nothing here is published, sent or exported. Identity, level and last login
-- come from the existing account character list, professions from each
-- character's profile and item names from the shared item index. This store
-- keeps only what no other store has: gold, class and level with their own
-- timestamps, rested XP, played time and an optional compact bag/bank
-- inventory (item ID -> count). Every recorded field carries the time it was
-- read; a missing field is unknown, never zero.
-- Basic data is recorded by default for new stores. Stores saved before that
-- default existed carry no enabledBy marker; their switch is kept as it was,
-- because 5.3.0 saved enabled=false for everybody and an explicit choice
-- cannot be told apart from the old default. Bags and bank stay opt-in.
-- Played time is only recorded when the player types /played: requesting it
-- automatically would print to the chat frame on every login.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local O={VERSION=1,MAX_CHARACTERS=100,MAX_BAG_ITEMS=400,MAX_BANK_ITEMS=800,MAX_SEARCH=50,MAX_REQUESTS=50,MAX_UTILITY=200}
Z.AccountOverview=O
local MAX_TIME=4102444800
local MAX_MONEY=99999999999
local EVENTS={"PLAYER_ENTERING_WORLD","PLAYER_MONEY","TIME_PLAYED_MSG","PLAYER_XP_UPDATE","UPDATE_EXHAUSTION","PLAYER_UPDATE_RESTING","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED"}
local INVENTORY_EVENTS={"BAG_UPDATE_DELAYED","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED"}
local frame

local function defaults()return{version=O.VERSION,enabled=true,enabledBy="default",inventory=false,characters={}}end
local function stamp()local now=A.Now();return now>0 and now or nil end
local function changed()O.revision=(O.revision or 0)+1 end
local function int(value,min,max)return L.Int(value,min,max)and value or nil end
local function items(raw,limit)
    local out,n={},0
    for id,count in pairs(type(raw)=="table"and raw or{})do
        if n>=limit then break end
        if L.Int(id,1,10000000)and L.Int(count,1,1000000)then out[id]=count;n=n+1 end
    end
    return out
end
-- Copies only known fields; anything else in SavedVariables is dropped.
local function sanitize(raw)
    if type(raw)~="table"then return nil end
    local c={}
    if type(raw.classFile)=="string"and raw.classFile:match("^[A-Z]+$")and #raw.classFile<=16 then c.classFile=raw.classFile;c.classAt=int(raw.classAt,1,MAX_TIME)end
    c.level=int(raw.level,1,100);c.levelAt=c.level and int(raw.levelAt,1,MAX_TIME);c.updatedAt=int(raw.updatedAt,1,MAX_TIME)
    c.money=int(raw.money,0,MAX_MONEY);c.moneyAt=c.money and int(raw.moneyAt,1,MAX_TIME)
    c.xp=int(raw.xp,0,100000000);c.xpMax=int(raw.xpMax,1,100000000);c.rested=int(raw.rested,0,100000000)
    c.restedAt=int(raw.restedAt,1,MAX_TIME);c.resting=raw.resting==true or nil;c.maxLevel=raw.maxLevel==true or nil
    c.played=int(raw.played,0,2147483646);c.playedLevel=int(raw.playedLevel,0,2147483646);c.playedAt=c.played and int(raw.playedAt,1,MAX_TIME)
    if type(raw.bags)=="table"and L.Int(raw.bagsAt,1,MAX_TIME)then c.bags=items(raw.bags,O.MAX_BAG_ITEMS);c.bagsAt=raw.bagsAt end
    if type(raw.bank)=="table"and L.Int(raw.bankAt,1,MAX_TIME)then c.bank=items(raw.bank,O.MAX_BANK_ITEMS);c.bankAt=raw.bankAt end
    return c
end
local function accountCharacters()return Z.account and type(Z.account.characters)=="table"and Z.account.characters or{}end
local function ownKey()return Z.accountCharacterKey or Z.storageKey end

local function setEvents()
    if not frame then return end
    frame:UnregisterAllEvents()
    if not O.Enabled()then return end
    for _,event in ipairs(EVENTS)do frame:RegisterEvent(event)end
    if O.InventoryEnabled()then for _,event in ipairs(INVENTORY_EVENTS)do frame:RegisterEvent(event)end end
end

function O.Initialize()
    O.revision=0;O.bankOpen=false;O.bagsDirty=false;O.bankDirty=false;O.bankScanQueued=false
    local root=ZenialCommunityDB;if type(root)~="table"then return end
    local raw=root.accountOverview
    -- A newer format from a later addon version stays untouched and read-only.
    O.readOnly=type(raw)=="table"and raw.version~=nil and raw.version~=O.VERSION
    if O.readOnly then O.store=defaults();setEvents();return end
    local store=defaults();local known=accountCharacters()
    local aliases=Z.account and type(Z.account.characterAliases)=="table"and Z.account.characterAliases or{}
    if type(raw)=="table"then
        store.enabled=raw.enabled==true;store.inventory=raw.inventory==true
        store.enabledBy=(raw.enabledBy=="default"or raw.enabledBy=="user")and raw.enabledBy or"legacy"
        local n=0
        for key,row in pairs(type(raw.characters)=="table"and raw.characters or{})do
            -- Rows follow renamed account keys and vanish with removed characters.
            local canonical=type(key)=="string"and(known[key]and key or aliases[key])
            if canonical and known[canonical]and not store.characters[canonical]and n<O.MAX_CHARACTERS then
                local c=sanitize(row);if c then store.characters[canonical]=c;n=n+1 end
            end
        end
    end
    root.accountOverview=store;O.store=store
    if not frame then frame=CreateFrame("Frame");frame:SetScript("OnEvent",function(_,event,...)O.OnEvent(event,...)end)end
    setEvents()
    if O.Enabled()then O.Sample()end
end
function O.Enabled()return O.store~=nil and not O.readOnly and O.store.enabled==true end
function O.InventoryEnabled()return O.Enabled()and O.store.inventory==true end
function O.SetEnabled(value)
    if not O.store or O.readOnly then return nil,"The account overview uses a newer format."end
    O.store.enabled=value==true;O.store.enabledBy="user";setEvents();if O.store.enabled then O.Sample()end;changed();return true
end
function O.SetInventory(value)
    if not O.store or O.readOnly then return nil,"The account overview uses a newer format."end
    O.store.inventory=value==true;setEvents();if O.InventoryEnabled()then O.ScanBags()end;changed();return true
end

-- Writable row of the logged-in character, created on demand.
local function own()
    local key=ownKey();if not O.Enabled()or not key or not accountCharacters()[key]then return nil end
    local c=O.store.characters[key]
    if not c then
        local n=0;for _ in pairs(O.store.characters)do n=n+1 end
        if n>=O.MAX_CHARACTERS then return nil end
        c={};O.store.characters[key]=c
    end
    return c
end
function O.SampleMoney(allowZero)
    local c=own();if not c then return end
    local money=A.Call(GetMoney);if not L.Int(money,0,MAX_MONEY)then return end
    -- The client reports 0 copper while loading; keep a known value then.
    if money==0 and not allowZero and(c.money or 0)>0 then return end
    c.money=money;c.moneyAt=stamp();c.updatedAt=c.moneyAt or c.updatedAt;changed()
end
function O.SampleXP()
    local c=own();if not c then return end
    local level=A.Call(UnitLevel,"player");local cap=A.Call(GetMaxPlayerLevel)
    if L.Int(level,1,100)and L.Int(cap,1,100)and level>=cap then
        c.maxLevel=true;c.xp,c.xpMax,c.rested,c.restedAt,c.resting=nil,nil,nil,nil,nil;changed();return
    end
    c.maxLevel=nil
    local xp,maximum=A.Call(UnitXP,"player"),A.Call(UnitXPMax,"player")
    if not L.Int(xp,0,100000000)or not L.Int(maximum,1,100000000)then return end
    local rested=A.Call(GetXPExhaustion)
    c.xp,c.xpMax,c.rested=xp,maximum,L.Int(rested,0,100000000)and rested or 0
    c.resting=A.Call(IsResting)==true or nil;c.restedAt=stamp();c.updatedAt=c.restedAt or c.updatedAt;changed()
end
function O.SamplePlayed(total,level)
    local c=own();if not c or not L.Int(total,0,2147483646)then return end
    c.played=total;c.playedLevel=L.Int(level,0,2147483646)and level or nil;c.playedAt=stamp();c.updatedAt=c.playedAt or c.updatedAt;changed()
end
-- PLAYER_LEVEL_UP passes the new level before UnitLevel reports it. Level 0
-- while the client is still loading is ignored and keeps the known value.
function O.SampleLevel(level)
    local c=own();if not c then return end
    if not L.Int(level,1,100)then level=A.Call(UnitLevel,"player")end
    if not L.Int(level,1,100)then return end
    c.level=level;c.levelAt=stamp();c.updatedAt=c.levelAt or c.updatedAt;changed()
end
function O.Sample()
    local c=own();if not c then return end
    local _,classFile=A.Call(UnitClass,"player")
    if type(classFile)=="string"and classFile:match("^[A-Z]+$")and #classFile<=16 then c.classFile=classFile;c.classAt=stamp()end
    O.SampleLevel();O.SampleMoney(false);O.SampleXP();if O.InventoryEnabled()then O.ScanBags()end
end

-- Container reads: modern C_Container table results, then the legacy globals.
local function slotItem(bag,slot)
    local C=C_Container
    if C and type(C.GetContainerItemInfo)=="function"then
        local info=A.Call(C.GetContainerItemInfo,bag,slot)
        if type(info)=="table"then return info.itemID,info.stackCount end
    end
    local id=C and type(C.GetContainerItemID)=="function"and A.Call(C.GetContainerItemID,bag,slot)or A.Call(GetContainerItemID,bag,slot)
    if not id then return nil end
    local _,count=A.Call(GetContainerItemInfo,bag,slot)
    return id,count
end
local function slots(bag)
    local C=C_Container
    local n=C and type(C.GetContainerNumSlots)=="function"and A.Call(C.GetContainerNumSlots,bag)or A.Call(GetContainerNumSlots,bag)
    return L.Int(n,0,200)and n or 0
end
local function scan(bags,limit)
    local out,n,observed={},0,0
    for _,bag in ipairs(bags)do
        for slot=1,slots(bag)do
            local id,count=slotItem(bag,slot)
            if L.Int(id,1,10000000)then
                count=L.Int(count,1,1000000)and count or 1
                if out[id]then out[id]=math.min(1000000,out[id]+count)
                elseif n<limit then out[id]=count;n=n+1
                    -- Seeds the shared name index so searches can name the item later.
                    if Z.Items and observed<O.MAX_REQUESTS and not Z.Items.Get(id)then Z.Items.Observe(id);observed=observed+1 end
                end
            end
        end
    end
    return out
end
local function bagIDs()local n=L.Int(NUM_BAG_SLOTS,1,20)and NUM_BAG_SLOTS or 4;local out={};for bag=0,n do out[#out+1]=bag end;return out end
local function bankIDs()
    local first=(L.Int(NUM_BAG_SLOTS,1,20)and NUM_BAG_SLOTS or 4)+1;local count=L.Int(NUM_BANKBAGSLOTS,0,20)and NUM_BANKBAGSLOTS or 6
    local out={L.Int(BANK_CONTAINER,-10,0)and BANK_CONTAINER or -1};for bag=first,first+count-1 do out[#out+1]=bag end;return out
end
-- Bags and bank are not protected, but scans wait for the end of combat.
function O.ScanBags()
    local c=own();if not c or not O.InventoryEnabled()then return end
    if A.Call(InCombatLockdown)==true then O.bagsDirty=true;return end
    O.bagsDirty=false;c.bags=scan(bagIDs(),O.MAX_BAG_ITEMS);c.bagsAt=A.Now()>0 and A.Now()or nil
    if not c.bagsAt then c.bags=nil end;changed()
end
-- Only a bank that is actually open is read; otherwise the old snapshot stays.
function O.ScanBank()
    local c=own();if not c or not O.InventoryEnabled()or not O.bankOpen then return end
    if A.Call(InCombatLockdown)==true then O.bankDirty=true;return end
    O.bankDirty=false;local at=A.Now();if at<=0 then return end
    c.bank=scan(bankIDs(),O.MAX_BANK_ITEMS);c.bankAt=at;changed()
end
local function queueBank()
    if O.bankScanQueued then return end
    if C_Timer and type(C_Timer.After)=="function"then
        O.bankScanQueued=true;C_Timer.After(.5,function()O.bankScanQueued=false;O.ScanBank()end)
    else O.ScanBank()end
end
function O.OnEvent(event,...)
    if not O.Enabled()then return end
    if event=="PLAYER_ENTERING_WORLD"then O.Sample()
    elseif event=="PLAYER_MONEY"then O.SampleMoney(true)
    elseif event=="TIME_PLAYED_MSG"then O.SamplePlayed(...)
    elseif event=="PLAYER_LEVEL_UP"then O.SampleLevel(...);O.SampleXP()
    elseif event=="PLAYER_XP_UPDATE"or event=="UPDATE_EXHAUSTION"or event=="PLAYER_UPDATE_RESTING"then O.SampleXP()
    elseif event=="PLAYER_REGEN_ENABLED"then if O.bagsDirty then O.ScanBags()end;if O.bankDirty then O.ScanBank()end
    elseif event=="BAG_UPDATE_DELAYED"then O.ScanBags();if O.bankOpen then O.ScanBank()end
    elseif event=="BANKFRAME_OPENED"then O.bankOpen=true;O.ScanBank()
    elseif event=="BANKFRAME_CLOSED"then O.bankOpen=false
    elseif event=="PLAYERBANKSLOTS_CHANGED"then if O.bankOpen then queueBank()end end
end
function O.Forget(key)
    if O.store and not O.readOnly and O.store.characters[key]then O.store.characters[key]=nil;changed();return true end
    return false
end

-- ZENIAL Utility keeps its own record of the player's characters. When it is
-- loaded, its rows are read (never written) to fill gaps; nothing depends on it.
local function norm(value)return type(value)=="string"and value:lower():gsub("[%s%-%'_]","")or""end
function O.UtilityLoaded()
    local loaded=C_AddOns and type(C_AddOns.IsAddOnLoaded)=="function"and A.Call(C_AddOns.IsAddOnLoaded,"ZenialUtility")or A.Call(IsAddOnLoaded,"ZenialUtility")
    return loaded==true and type(ZenialUtilityDB)=="table"and type(ZenialUtilityDB.characters)=="table"
end
function O.UtilityRows()
    local out={};if not O.UtilityLoaded()then return out end
    for _,row in pairs(ZenialUtilityDB.characters)do
        if #out>=O.MAX_UTILITY then break end
        if type(row)=="table"and L.Text(row.name,48)and L.Text(row.realm,64)and(row.faction=="Alliance"or row.faction=="Horde"or row.faction=="Neutral")then
            out[#out+1]={name=row.name,realm=row.realm,faction=row.faction,level=int(row.level,1,100),
                classFile=type(row.class)=="string"and row.class:match("^[A-Z]+$")and row.class~="GENERAL"and row.class or nil,
                money=int(row.money,0,MAX_MONEY),seen=int(row.seen,1,MAX_TIME)}
        end
    end
    return out
end
-- Utility stores the given name only. A row matches a Community character with
-- the same world, faction and given name; ambiguous names stay unmatched.
local function utilityIndex(characters)
    local index,count={},{}
    for key,c in pairs(characters)do if type(c)=="table"and c.target then
        local id=norm(c.realm).."|"..tostring(c.faction).."|"..norm(c.target:match("^(%S+)"))
        count[id]=(count[id]or 0)+1;index[id]=key
    end end
    for id,n in pairs(count)do if n>1 then index[id]=false end end
    return index
end

local function professions(key)
    local profile=type(ZenialCommunityDB)=="table"and type(ZenialCommunityDB.characters)=="table"and ZenialCommunityDB.characters[key]
    local out={}
    for _,p in ipairs(type(profile)=="table"and type(profile.professions)=="table"and profile.professions or{})do
        if type(p)=="table"and L.Text(p.name,64)and L.Int(p.rank,0,1000)then out[#out+1]={name=p.name,rank=p.rank,max=L.Int(p.max,0,1000)and p.max or nil}end
    end
    table.sort(out,function(a,b)return a.name<b.name end)
    return out
end
local RULESETS={["forever-normal"]="Normal",["forever-pvp"]="PvP",["forever-rp"]="RP",["forever-hardcore"]="Hardcore"}
function O.Ruleset(realm)
    local world=Z.CommunityDirectory and Z.CommunityDirectory.World and Z.CommunityDirectory.World(realm)
    if not world then return nil end
    if world:match("^forever%-live%-pvp:")then return"PvP"end
    return RULESETS[world]
end
local function count(map)local n=0;for _,c in pairs(map or{})do n=n+c end;return n end

-- All known characters, optionally filtered by realm and faction.
function O.List(filter)
    filter=filter or{}
    local characters=accountCharacters();local rows,matched={},{}
    local index=utilityIndex(characters)
    local utility=O.UtilityRows()
    for _,u in ipairs(utility)do
        local key=index[norm(u.realm).."|"..u.faction.."|"..norm(u.name)]
        if key then matched[key]=u else u.unmatched=true end
    end
    local me=ownKey()
    for key,c in pairs(characters)do if type(c)=="table"and L.Text(c.target,113)then
        local s=O.store and O.store.characters[key]or{};local u=matched[key]
        local money,fromUtility=s.money,false
        if money==nil and u and u.money then money,fromUtility=u.money,true end
        -- Level: the newer of the recorded level and the account list (as of
        -- its last login), then Utility. Each value keeps its own time.
        local lastLogin=L.Int(c.lastLogin,1,MAX_TIME)and c.lastLogin or nil
        local level=L.Int(c.level,1,100)and c.level or nil
        local levelAt,levelFromUtility=level and lastLogin,nil
        if s.level and(not level or(s.levelAt or 0)>=(lastLogin or 0))then level,levelAt=s.level,s.levelAt end
        if not level and u and u.level then level,levelAt,levelFromUtility=u.level,u.seen,true end
        local classFromUtility=not s.classFile and u and u.classFile and true or nil
        rows[#rows+1]={key=key,name=c.target,realm=c.realm or"",faction=c.faction or"",current=key==me,
            classFile=s.classFile or u and u.classFile,classAt=s.classFile and s.classAt or classFromUtility and u.seen or nil,classFromUtility=classFromUtility,
            className=c.class~=""and c.class or nil,level=level,levelAt=levelAt,levelFromUtility=levelFromUtility,updatedAt=s.updatedAt,
            lastLogin=lastLogin,money=money,moneyAt=fromUtility and u.seen or s.moneyAt,moneyFromUtility=fromUtility or nil,
            maxLevel=s.maxLevel,xp=s.xp,xpMax=s.xpMax,rested=s.rested,restedAt=s.restedAt,resting=s.resting,
            played=s.played,playedLevel=s.playedLevel,playedAt=s.playedAt,professions=professions(key),
            bagsAt=s.bagsAt,bagCount=s.bags and count(s.bags),bankAt=s.bankAt,bankCount=s.bank and count(s.bank)}
    end end
    -- Characters only Utility knows: never logged in with Community yet.
    for _,u in ipairs(utility)do if u.unmatched then
        rows[#rows+1]={key="utility:"..u.realm.."@"..u.faction.."@"..u.name,name=u.name,realm=u.realm,faction=u.faction,utilityOnly=true,
            classFile=u.classFile,level=u.level,lastLogin=u.seen,money=u.money,moneyAt=u.seen,moneyFromUtility=u.money~=nil or nil,professions={}}
    end end
    local out={}
    for _,r in ipairs(rows)do
        if(not filter.realm or r.realm==filter.realm)and(not filter.faction or r.faction==filter.faction)then out[#out+1]=r end
    end
    table.sort(out,function(a,b)
        if a.current~=b.current then return a.current==true end
        if(a.lastLogin or 0)~=(b.lastLogin or 0)then return(a.lastLogin or 0)>(b.lastLogin or 0)end
        return a.name<b.name
    end)
    return out
end
function O.Realms()
    local seen,out={},{}
    for _,r in ipairs(O.List())do if r.realm~=""and not seen[r.realm]then seen[r.realm]=true;out[#out+1]=r.realm end end
    table.sort(out);return out
end
function O.TotalMoney(rows)local n=0;for _,r in ipairs(rows)do n=n+(r.money or 0)end;return n end

-- Searches stored bags and banks of the listed characters by item name or ID.
-- Unknown names are requested from the client; such items appear once loaded.
function O.Search(query,rows)
    query=type(query)=="string"and query:match("^%s*(.-)%s*$")or""
    local id=tonumber(query);local needle=string.lower(query)
    if not id and #needle<2 then return{},0 end
    local hits,unresolved,requests={},0,0
    for _,r in ipairs(rows)do
        local s=O.store and O.store.characters[r.key]
        if s then for _,place in ipairs({"bags","bank"})do
            for itemID,n in pairs(s[place]or{})do
                local row=Z.Items and Z.Items.Get(itemID)
                if not row and Z.Items and requests<O.MAX_REQUESTS then row=Z.Items.Observe(itemID);requests=requests+1 end
                local name=row and row.name
                local match=id and itemID==id or not id and name and string.lower(name):find(needle,1,true)
                if not name and not id then unresolved=unresolved+1 end
                if match then
                    local hit=hits[itemID]or{id=itemID,name=name or("#"..itemID),total=0,holders={},byKey={}}
                    hits[itemID]=hit;hit.total=hit.total+n
                    local holder=hit.byKey[r.key]
                    if not holder then holder={name=r.name,realm=r.realm,bags=0,bank=0};hit.byKey[r.key]=holder;hit.holders[#hit.holders+1]=holder end
                    holder[place]=holder[place]+n
                end
            end
        end end
    end
    local out={};for _,hit in pairs(hits)do hit.byKey=nil;out[#out+1]=hit end
    table.sort(out,function(a,b)if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    while #out>O.MAX_SEARCH do table.remove(out)end
    return out,unresolved
end
return O
