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
-- cannot be told apart from the old default. Bag and bank recording is on for
-- new stores and switched on once when a schema v1 store is migrated to v2
-- (inventoryBy says who set it); after that the player's switch decides.
-- Bags and bank are kept per slot (only complete scans are stored) next to
-- the aggregated item counts.
-- Played time is requested automatically (20 s after the first login of a
-- session, then every 30 minutes, never in combat). The chat line is kept out
-- of the chat by unregistering TIME_PLAYED_MSG on the chat frames that have it
-- for the duration of the request; a /played typed by the player stays visible
-- and is stored as well. A /played typed or requested by another addon during
-- those few seconds is stored but not printed.
-- Characters can be hidden from the "My characters" view; hiding only changes
-- that view and keeps every stored value and link.
-- Community is the only live source. Rows once taken over from ZENIAL Utility
-- stay readable as a separate, labelled snapshot that a newer Community value
-- always replaces; Utility itself is never read.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local O={VERSION=2,MAX_CHARACTERS=100,MAX_BAG_ITEMS=400,MAX_BANK_ITEMS=1500,MAX_CONTAINERS=12,BANK_RETRIES=3,MAX_SEARCH=50,MAX_REQUESTS=50,MAX_UTILITY=200,PLAYED_FIRST=20,PLAYED_EVERY=1800,PLAYED_TIMEOUT=10}
Z.AccountOverview=O
local MAX_TIME=4102444800
local MAX_MONEY=99999999999
local EVENTS={"PLAYER_ENTERING_WORLD","PLAYER_MONEY","TIME_PLAYED_MSG","PLAYER_XP_UPDATE","UPDATE_EXHAUSTION","PLAYER_UPDATE_RESTING","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED"}
local INVENTORY_EVENTS={"BAG_UPDATE_DELAYED","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED"}
local frame
local played,startPlayed={}

local function defaults()return{version=O.VERSION,enabled=true,enabledBy="default",inventory=true,inventoryBy="default",characters={},hidden={}}end
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
-- Per-slot snapshot {at=time,containers={{bag=id,size=n,slots={[slot]={itemID,count}}}}}.
local function slotSnapshot(raw,limit)
    if type(raw)~="table"or not L.Int(raw.at,1,MAX_TIME)or type(raw.containers)~="table"then return nil end
    local out,occupied,seen={at=raw.at,containers={}},0,{}
    for _,ct in ipairs(raw.containers)do
        if #out.containers>=O.MAX_CONTAINERS then break end
        if type(ct)=="table"and L.Int(ct.bag,-10,100)and not seen[ct.bag]and L.Int(ct.size,0,200)and type(ct.slots)=="table"then
            seen[ct.bag]=true;local slots={}
            for slot,entry in pairs(ct.slots)do
                if occupied<limit and L.Int(slot,1,ct.size)and type(entry)=="table"and L.Int(entry[1],1,10000000)and L.Int(entry[2],1,1000000)then
                    slots[slot]={entry[1],entry[2]};occupied=occupied+1
                end
            end
            out.containers[#out.containers+1]={bag=ct.bag,size=ct.size,slots=slots}
        end
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
    c.bagSlots=slotSnapshot(raw.bagSlots,O.MAX_BAG_ITEMS);c.bankSlots=slotSnapshot(raw.bankSlots,O.MAX_BANK_ITEMS)
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
    O.lastScan={};O.bankRetries=0;O.bankRetryQueued=false;O.stockCache=nil
    local root=ZenialCommunityDB;if type(root)~="table"then return end
    local raw=root.accountOverview
    -- A newer format from a later addon version stays untouched and read-only.
    -- Schema v1 is migrated below; only versions this code does not know are read-only.
    O.readOnly=type(raw)=="table"and raw.version~=nil and raw.version~=1 and raw.version~=O.VERSION
    if O.readOnly then O.store=defaults();setEvents();return end
    local store=defaults();local known=accountCharacters()
    local aliases=Z.account and type(Z.account.characterAliases)=="table"and Z.account.characterAliases or{}
    if type(raw)=="table"then
        store.enabled=raw.enabled==true
        if raw.version==1 then store.inventory=true;store.inventoryBy="migration"
        else store.inventory=raw.inventory==true
            store.inventoryBy=(raw.inventoryBy=="default"or raw.inventoryBy=="migration"or raw.inventoryBy=="user")and raw.inventoryBy or"default"end
        store.enabledBy=(raw.enabledBy=="default"or raw.enabledBy=="user")and raw.enabledBy or"legacy"
        local n=0
        for key,row in pairs(type(raw.characters)=="table"and raw.characters or{})do
            -- Rows follow renamed account keys and vanish with removed characters.
            local canonical=type(key)=="string"and(known[key]and key or aliases[key])
            if canonical and known[canonical]and not store.characters[canonical]and n<O.MAX_CHARACTERS then
                local c=sanitize(row);if c then store.characters[canonical]=c;n=n+1 end
            end
        end
        -- Hidden marks follow renamed keys; Utility-only rows keep their own key.
        local hidden=0
        for key,value in pairs(type(raw.hidden)=="table"and raw.hidden or{})do
            local canonical=type(key)=="string"and(known[key]and key or aliases[key])
            if canonical and not known[canonical]then canonical=nil end
            if not canonical and type(key)=="string"and #key<=200 and key:match("^utility:")then canonical=key end
            if value==true and canonical and not store.hidden[canonical]and hidden<O.MAX_CHARACTERS+O.MAX_UTILITY then store.hidden[canonical]=true;hidden=hidden+1 end
        end
        store.imported=O.SanitizeImported(raw.imported)
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
    O.store.enabled=value==true;O.store.enabledBy="user";setEvents();if O.store.enabled then O.Sample();startPlayed()end;changed();return true
end
-- Hides a character from the overview without touching any stored data.
function O.SetHidden(key,value)
    if not O.store or O.readOnly then return nil,"The account overview uses a newer format."end
    if type(key)~="string"or key==""or key==ownKey()then return nil,"The logged-in character always stays visible."end
    O.store.hidden[key]=value==true or nil;changed();return true
end
function O.IsHidden(key)return O.store~=nil and O.store.hidden~=nil and O.store.hidden[key]==true end
function O.SetInventory(value)
    if not O.store or O.readOnly then return nil,"The account overview uses a newer format."end
    O.store.inventory=value==true;O.store.inventoryBy="user";setEvents();if O.InventoryEnabled()then O.ScanBags()end;changed();return true
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
-- Automatic played time. Only one request at a time; the chat frames that show
-- TIME_PLAYED_MSG are unregistered while it is open and registered again after
-- the reply (deferred by one frame) or after a 10 s timeout. Without the chat
-- frame API, RequestTimePlayed or C_Timer there is no automatic request.
local function playedFrames()
    local n=L.Int(NUM_CHAT_WINDOWS,1,50)and NUM_CHAT_WINDOWS or 10;local out={}
    for i=1,n do
        local f=_G["ChatFrame"..i]
        if f~=nil then
            if type(f)~="table"or type(f.IsEventRegistered)~="function"or type(f.RegisterEvent)~="function"or type(f.UnregisterEvent)~="function"then return nil end
            if A.Call(f.IsEventRegistered,f,"TIME_PLAYED_MSG")==true then out[#out+1]=f end
        end
    end
    return out
end
local function restorePlayed(frames)
    for _,f in ipairs(frames or{})do A.Call(f.RegisterEvent,f,"TIME_PLAYED_MSG")end
end
local function timerReady()return C_Timer~=nil and type(C_Timer.After)=="function"end
function O.RequestPlayed()
    if not O.Enabled()or played.inflight or type(RequestTimePlayed)~="function"or not timerReady()then return false end
    if A.Call(InCombatLockdown)==true then played.waiting=true;return false end
    local frames=playedFrames();if not frames then return false end
    played.waiting=false;played.inflight=true;played.frames=frames;played.token=(played.token or 0)+1
    local token=played.token
    for _,f in ipairs(frames)do A.Call(f.UnregisterEvent,f,"TIME_PLAYED_MSG")end
    A.Call(RequestTimePlayed)
    C_Timer.After(O.PLAYED_TIMEOUT,function()
        if played.inflight and played.token==token then played.inflight=false;restorePlayed(played.frames);played.frames=nil end
    end)
    return true
end
local function playedTick()
    if not O.Enabled()then played.started=false;return end
    O.RequestPlayed()
    if timerReady()then C_Timer.After(O.PLAYED_EVERY,playedTick)end
end
function startPlayed()
    if played.started or not O.Enabled()or not timerReady()then return end
    played.started=true;C_Timer.After(O.PLAYED_FIRST,playedTick)
end
local function playedReply()
    if not played.inflight then return end
    played.inflight=false;local frames=played.frames;played.frames=nil
    C_Timer.After(0,function()restorePlayed(frames)end)
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
    return L.Int(n,0,200)and n or nil
end
-- Reads containers into the item aggregate and the per-slot snapshot. complete
-- is false if a container reported no slot count, a slot had an item without
-- a valid amount, or the limits were exceeded: such a scan is never stored.
local function scan(bags,limit)
    local out,n,observed,occupied={},0,0,0
    local containers,complete={},true
    for _,bag in ipairs(bags)do
        local size=slots(bag);local ct={bag=bag,size=size or 0,slots={}}
        if size==nil then complete=false end
        for slot=1,size or 0 do
            local id,count=slotItem(bag,slot)
            if id~=nil then
                if not L.Int(id,1,10000000)or not L.Int(count,1,1000000)or occupied>=limit then complete=false
                else
                    ct.slots[slot]={id,count};occupied=occupied+1
                    if out[id]then out[id]=math.min(1000000,out[id]+count)
                    elseif n<limit then out[id]=count;n=n+1
                        -- Seeds the shared name index so searches can name the item later.
                        if Z.Items and observed<O.MAX_REQUESTS and not Z.Items.Get(id)then Z.Items.Observe(id);observed=observed+1 end
                    end
                end
            end
        end
        containers[#containers+1]=ct
    end
    if #containers>O.MAX_CONTAINERS then complete=false end
    return out,containers,complete
end
-- Equipped bags include the reagent bag (never the keyring).
local function bagIDs()
    local n=L.Int(NUM_TOTAL_EQUIPPED_BAG_SLOTS,1,20)and NUM_TOTAL_EQUIPPED_BAG_SLOTS or L.Int(NUM_BAG_SLOTS,1,20)and NUM_BAG_SLOTS or 4
    local out={};for bag=0,n do out[#out+1]=bag end;return out
end
-- Bank containers. With C_Bank (Forever) they are the purchased character bank
-- tabs; the list is only usable if the call returned at least one valid tab.
-- Without C_Bank the legacy main bank plus bank bags are read.
local function bankIDs()
    local B=C_Bank
    if type(B)=="table"and type(B.FetchPurchasedBankTabData)=="function"and type(Enum)=="table"and type(Enum.BankType)=="table"and Enum.BankType.Character~=nil then
        local tabs=A.Call(B.FetchPurchasedBankTabData,Enum.BankType.Character)
        local out,seen,ok={},{},type(tabs)=="table"
        if ok then for _,tab in ipairs(tabs)do
            if type(tab)=="table"and L.Int(tab.ID,0,100)and not seen[tab.ID]and #out<O.MAX_CONTAINERS then seen[tab.ID]=true;out[#out+1]=tab.ID else ok=false end
        end end
        return out,true,ok and #out>0
    end
    local first=(L.Int(NUM_BAG_SLOTS,1,20)and NUM_BAG_SLOTS or 4)+1;local count=L.Int(NUM_BANKBAGSLOTS,0,20)and NUM_BANKBAGSLOTS or 6
    local out={L.Int(BANK_CONTAINER,-10,0)and BANK_CONTAINER or -1};for bag=first,first+count-1 do out[#out+1]=bag end;return out,false,true
end
-- Bags and bank are not protected, but scans wait for the end of combat.
-- An incomplete scan (client still loading) keeps the previous snapshot.
function O.ScanBags()
    local c=own();if not c or not O.InventoryEnabled()then return end
    if A.Call(InCombatLockdown)==true then O.bagsDirty=true;return end
    O.bagsDirty=false;local at=A.Now();if at<=0 then return end
    local agg,containers,complete=scan(bagIDs(),O.MAX_BAG_ITEMS)
    -- The backpack always has slots; zero means the client is still loading.
    if complete and not(containers[1]and containers[1].size>0)then complete=false end
    -- An equipped bag that reports no slots is not loaded yet.
    local C=C_Container
    if complete and C and type(C.ContainerIDToInventoryID)=="function"and type(GetInventoryItemID)=="function"then
        for _,ct in ipairs(containers)do
            if ct.bag>=1 and ct.size==0 then
                local invID=A.Call(C.ContainerIDToInventoryID,ct.bag)
                if invID and A.Call(GetInventoryItemID,"player",invID)then complete=false;break end
            end
        end
    end
    O.lastScan.bags={at=at,complete=complete}
    if not complete then return end
    c.bags=agg;c.bagsAt=at;c.bagSlots={at=at,containers=containers};changed()
end
-- Only a bank that is actually open is read; otherwise the old snapshot stays.
-- A bank the client has not loaded yet is read again up to three times.
function O.ScanBank()
    local c=own();if not c or not O.InventoryEnabled()or not O.bankOpen then return end
    if A.Call(InCombatLockdown)==true then O.bankDirty=true;return end
    O.bankDirty=false;local at=A.Now();if at<=0 then return end
    local ids,tabs,idsOk=bankIDs()
    local agg,containers,complete=scan(ids,O.MAX_BANK_ITEMS)
    if not idsOk then complete=false end
    if tabs then
        -- Every purchased bank tab has slots; zero means it is not loaded yet.
        for _,ct in ipairs(containers)do if ct.size<=0 then complete=false end end
    elseif complete and not(containers[1]and containers[1].size>0)then complete=false end -- the main bank always has slots
    O.lastScan.bank={at=at,complete=complete}
    if not complete then
        if O.bankRetries<O.BANK_RETRIES and not O.bankRetryQueued and C_Timer and type(C_Timer.After)=="function"then
            O.bankRetries=O.bankRetries+1;O.bankRetryQueued=true
            C_Timer.After(.5,function()O.bankRetryQueued=false;O.ScanBank()end)
        end
        return
    end
    O.bankRetries=0
    c.bank=agg;c.bankAt=at;c.bankSlots={at=at,containers=containers};changed()
end
local function queueBank()
    if O.bankScanQueued then return end
    if C_Timer and type(C_Timer.After)=="function"then
        O.bankScanQueued=true;C_Timer.After(.5,function()O.bankScanQueued=false;O.ScanBank()end)
    else O.ScanBank()end
end
function O.OnEvent(event,...)
    if not O.Enabled()then return end
    if event=="PLAYER_ENTERING_WORLD"then O.Sample();startPlayed()
    elseif event=="PLAYER_MONEY"then O.SampleMoney(true)
    elseif event=="TIME_PLAYED_MSG"then O.SamplePlayed(...);playedReply()
    elseif event=="PLAYER_LEVEL_UP"then O.SampleLevel(...);O.SampleXP()
    elseif event=="PLAYER_XP_UPDATE"or event=="UPDATE_EXHAUSTION"or event=="PLAYER_UPDATE_RESTING"then O.SampleXP()
    elseif event=="PLAYER_REGEN_ENABLED"then if O.bagsDirty then O.ScanBags()end;if O.bankDirty then O.ScanBank()end;if played.waiting then O.RequestPlayed()end
    elseif event=="BAG_UPDATE_DELAYED"then O.ScanBags();if O.bankOpen then O.ScanBank()end
    elseif event=="BANKFRAME_OPENED"then O.bankOpen=true;O.bankRetries=0;O.ScanBank()
    elseif event=="BANKFRAME_CLOSED"then O.bankOpen=false
    elseif event=="PLAYERBANKSLOTS_CHANGED"then if O.bankOpen then queueBank()end end
end
function O.Forget(key)
    local removed=false
    if O.store and not O.readOnly and O.store.hidden[key]then O.store.hidden[key]=nil;removed=true end
    if O.store and not O.readOnly and O.store.characters[key]then O.store.characters[key]=nil;removed=true end
    if removed then changed()end
    return removed
end

-- Rows taken over from ZENIAL Utility by earlier versions (copy with source and
-- time in this store). Nothing new is imported; the copy is only read.
local FACTIONS={Alliance=true,Horde=true,Neutral=true}
local function norm(value)return type(value)=="string"and(value:lower():gsub("[%s%-%'_]",""))or""end
local function identity(realm,faction,name)return norm(realm).."|"..tostring(faction).."|"..norm(name)end
local function utilityRow(raw)
    if type(raw)~="table"or not L.Text(raw.name,48)or not L.Text(raw.realm,64)or not FACTIONS[raw.faction]or norm(raw.name)==""then return nil end
    local classFile=raw.classFile or raw.class
    return{name=raw.name,realm=raw.realm,faction=raw.faction,level=int(raw.level,1,100),
        classFile=type(classFile)=="string"and #classFile<=16 and classFile:match("^[A-Z]+$")and classFile~="GENERAL"and classFile or nil,
        money=int(raw.money,0,MAX_MONEY),seen=int(raw.seen,1,MAX_TIME)}
end
-- Stored takeover: {source="utility",at=time,characters={identity=row}}.
function O.SanitizeImported(raw)
    if type(raw)~="table"or raw.source~="utility"or not L.Int(raw.at,1,MAX_TIME)then return nil end
    local out={source="utility",at=raw.at,ambiguous=int(raw.ambiguous,0,10000)or 0,characters={}};local n=0
    for id,row in pairs(type(raw.characters)=="table"and raw.characters or{})do
        local r=n<O.MAX_UTILITY and utilityRow(row)
        if r and id==identity(r.realm,r.faction,r.name)then out.characters[id]=r;n=n+1 end
    end
    return out
end
-- Drops the taken-over rows of a deleted character, so it does not return as
-- a Utility-only row.
function O.ForgetImported(target,realm,faction)
    local imported=O.store and not O.readOnly and O.store.imported
    if not imported or type(target)~="string"then return end
    local base=target:match("^%s*(.-)%s*$")or"";base=base:match("^(.-)%-.+$")or base
    for _,name in ipairs({base,base:match("^(%S+)")})do
        local id=identity(realm,faction,name)
        if imported.characters[id]then imported.characters[id]=nil;changed()end
    end
end
-- Utility may store the given name or the full name. A row matches a Community
-- character with the same world, faction and either name; a name that two
-- Community characters share stays unmatched.
local function accountIndex(characters)
    local index={}
    for key,c in pairs(characters)do if type(c)=="table"and L.Text(c.target,113)then
        local base=c.target:match("^(.-)%-.+$")or c.target
        local ids={[identity(c.realm,c.faction,base)]=true,[identity(c.realm,c.faction,base:match("^(%S+)"))]=true}
        for id in pairs(ids)do if index[id]==nil then index[id]=key elseif index[id]~=key then index[id]=false end end
    end end
    return index
end
-- Newer of a Community value and a taken-over Utility value; equal or unknown
-- times keep the Community value.
local function utilityNewer(at,u)return u~=nil and u.seen~=nil and u.seen>(at or 0)end

local function professions(key)
    local profile=type(ZenialCommunityDB)=="table"and type(ZenialCommunityDB.characters)=="table"and ZenialCommunityDB.characters[key]
    local out={}
    for _,p in ipairs(type(profile)=="table"and type(profile.professions)=="table"and profile.professions or{})do
        if type(p)=="table"and L.Text(p.name,64)and L.Int(p.rank,0,1000)then out[#out+1]={name=p.name,rank=p.rank,max=L.Int(p.max,0,1000)and p.max or nil}end
    end
    table.sort(out,function(a,b)return a.name<b.name end)
    return out
end
-- Professions of the profile split into main and secondary lists, validated
-- with L.ValidProfession. An ID the kind table does not know counts as primary.
local function professionLists(key)
    local profile=type(ZenialCommunityDB)=="table"and type(ZenialCommunityDB.characters)=="table"and ZenialCommunityDB.characters[key]
    local primary,secondary={},{}
    for _,p in ipairs(type(profile)=="table"and type(profile.professions)=="table"and profile.professions or{})do
        if L.ValidProfession(p)then
            local e={id=p.id,name=p.name,rank=p.rank,max=p.max}
            if L.ProfessionKind(p.id)=="secondary"then secondary[#secondary+1]=e else primary[#primary+1]=e end
        end
    end
    local function byName(a,b)return a.name<b.name end
    table.sort(primary,byName);table.sort(secondary,byName)
    local states,at={},nil
    if type(profile)=="table"then
        at=L.Int(profile.professionsAt,1,MAX_TIME)and profile.professionsAt or nil
        for name,st in pairs(type(profile.recipeStates)=="table"and profile.recipeStates or{})do
            if type(name)=="string"and type(st)=="table"then states[name]={complete=st.complete,at=st.at,fullAt=st.fullAt,count=st.count}end
        end
    end
    return primary,secondary,at,states
end
local RULESETS={["forever-normal"]="Normal",["forever-pvp"]="PvP",["forever-rp"]="RP",["forever-hardcore"]="Hardcore"}
function O.Ruleset(realm)
    local world=Z.CommunityDirectory and Z.CommunityDirectory.World and Z.CommunityDirectory.World(realm)
    if not world then return nil end
    if world:match("^forever%-live%-pvp:")then return"PvP"end
    return RULESETS[world]
end
local function count(map)local n=0;for _,c in pairs(map or{})do n=n+c end;return n end
-- Main and alt roles per world and faction, as stored by Z.SetMain.
local function scopeKey(realm,faction)return string.lower((realm or""):gsub("%s+","")).."@"..string.lower(faction or"")end
local function mainFor(characters,realm,faction)
    local a=Z.account or{}
    local key=type(a.mains)=="table"and a.mains[scopeKey(realm,faction)]or nil
    if Z.me and realm==Z.me.realm and faction==Z.me.faction and L.Text(a.mainKey,260)then key=a.mainKey end
    local c=key and characters[key]
    if type(c)=="table"and c.realm==realm and c.faction==faction then return key,c.target end
end

-- All known characters, optionally filtered by realm and faction.
function O.List(filter)
    filter=filter or{}
    local characters=accountCharacters();local rows,matched={},{}
    local index=accountIndex(characters)
    local imported=O.store and O.store.imported
    local utility={}
    for id,u in pairs(imported and imported.characters or{})do
        local key=index[id]
        -- Ambiguous rows are neither merged nor listed: that could count a
        -- character and its gold twice.
        if key then matched[key]=u elseif key==nil then utility[#utility+1]=u end
    end
    local me=ownKey();local hidden=O.store and O.store.hidden or{}
    for key,c in pairs(characters)do if type(c)=="table"and L.Text(c.target,113)then
        local s=O.store and O.store.characters[key]or{};local u=matched[key]
        -- Gold: the recorded value unless a taken-over value is newer. A Utility
        -- zero never replaces known gold (it may be a loading-time reading).
        local money,fromUtility=s.money,false
        if u and u.money and(money==nil or utilityNewer(s.moneyAt,u)and(u.money>0 or money==0))then money,fromUtility=u.money,true end
        -- Level: the newer of the recorded level and the account list (as of
        -- its last login), then a newer taken-over value. Each keeps its time.
        local lastLogin=L.Int(c.lastLogin,1,MAX_TIME)and c.lastLogin or nil
        local level=L.Int(c.level,1,100)and c.level or nil
        local levelAt,levelFromUtility=level and lastLogin,nil
        if s.level and(not level or(s.levelAt or 0)>=(lastLogin or 0))then level,levelAt=s.level,s.levelAt end
        if u and u.level and(not level or utilityNewer(levelAt,u))then level,levelAt,levelFromUtility=u.level,u.seen,true end
        local classFromUtility=not s.classFile and u and u.classFile and true or nil
        rows[#rows+1]={key=key,name=c.target,realm=c.realm or"",faction=c.faction or"",current=key==me,
            classFile=s.classFile or u and u.classFile,classAt=s.classFile and s.classAt or classFromUtility and u.seen or nil,classFromUtility=classFromUtility,
            className=c.class~=""and c.class or nil,level=level,levelAt=levelAt,levelFromUtility=levelFromUtility,updatedAt=s.updatedAt,
            lastLogin=lastLogin,money=money,moneyAt=fromUtility and u.seen or s.moneyAt,moneyFromUtility=fromUtility or nil,
            importedAt=(fromUtility or levelFromUtility or classFromUtility)and imported.at or nil,
            maxLevel=s.maxLevel,xp=s.xp,xpMax=s.xpMax,rested=s.rested,restedAt=s.restedAt,resting=s.resting,
            played=s.played,playedLevel=s.playedLevel,playedAt=s.playedAt,professions=professions(key),
            bagsAt=s.bagsAt,bagCount=s.bags and count(s.bags),bankAt=s.bankAt,bankCount=s.bank and count(s.bank),hidden=hidden[key]==true or nil,
            sameScope=Z.me~=nil and c.realm==Z.me.realm and c.faction==Z.me.faction}
        local mainKey,mainName=mainFor(characters,c.realm,c.faction)
        local r=rows[#rows]
        r.primary,r.secondary,r.professionsAt,r.recipeStates=professionLists(key);r.inventory=O.Inventory(key)
        if mainKey==key then r.role="main"elseif mainKey then r.role,r.mainName="alt",mainName end
    end end
    -- Characters only the taken-over Utility data knows: never logged in with
    -- Community yet. They merge into the Community row once that exists.
    for _,u in ipairs(utility)do
        local key="utility:"..u.realm.."@"..u.faction.."@"..u.name
        rows[#rows+1]={key=key,name=u.name,realm=u.realm,faction=u.faction,utilityOnly=true,hidden=hidden[key]==true or nil,importedAt=imported.at,
            classFile=u.classFile,classFromUtility=u.classFile~=nil or nil,level=u.level,levelAt=u.level and u.seen,levelFromUtility=u.level~=nil or nil,
            lastLogin=u.seen,money=u.money,moneyAt=u.seen,moneyFromUtility=u.money~=nil or nil,professions={},primary={},secondary={},recipeStates={},inventory=O.Inventory(key)}
    end
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
-- Source and age of the taken-over Utility data, and how many of its rows
-- could not be assigned unambiguously (left out of every list and sum).
function O.ImportStatus()
    local imported=O.store and O.store.imported;if not imported then return nil end
    local index=accountIndex(accountCharacters());local n,ambiguous=0,imported.ambiguous or 0
    for id in pairs(imported.characters)do n=n+1;if index[id]==false then ambiguous=ambiguous+1 end end
    return{source=imported.source,at=imported.at,count=n,ambiguous=ambiguous}
end
-- One row as in O.List, without filter.
function O.Get(key)
    if type(key)~="string"then return nil end
    for _,r in ipairs(O.List())do if r.key==key then return r end end
end
function O.Realms()
    local seen,out={},{}
    for _,r in ipairs(O.List())do if r.realm~=""and not seen[r.realm]then seen[r.realm]=true;out[#out+1]=r.realm end end
    table.sort(out);return out
end
function O.TotalMoney(rows)local n=0;for _,r in ipairs(rows)do n=n+(r.money or 0)end;return n end

-- Stored inventory of one character. known=false: never recorded (unknown, not
-- empty). used/free/total exist only for snapshots with slot data.
function O.Inventory(key)
    local s=O.store and O.store.characters[key]
    local out={}
    for _,place in ipairs({"bags","bank"})do
        local counts=s and s[place]
        if type(counts)~="table"then out[place]={known=false}
        else
            local e={known=true,at=s[place.."At"],counts=counts}
            local snap=s[place=="bags"and"bagSlots"or"bankSlots"]
            if snap then
                local used,total=0,0
                for _,ct in ipairs(snap.containers)do total=total+ct.size;for _ in pairs(ct.slots)do used=used+1 end end
                e.slots=snap;e.used=used;e.total=total;e.free=total-used
            end
            out[place]=e
        end
    end
    return out
end
-- Item amounts per item, character and place: {[itemID]={[key]={bags=n,bank=n}}}.
-- nil: the place was never recorded; 0: recorded and not present. Cached until
-- the data changes.
function O.Stock(keys)
    keys=type(keys)=="table"and keys or{}
    local sig=table.concat(keys,"\1")
    local cache=O.stockCache
    if cache and cache.revision==O.revision and cache.sig==sig then return cache.result end
    local result,ids,rows={},{},{}
    for _,key in ipairs(keys)do
        local s=O.store and O.store.characters[key]
        if s then
            rows[key]=s
            for _,place in ipairs({"bags","bank"})do for id in pairs(type(s[place])=="table"and s[place]or{})do ids[id]=true end end
        end
    end
    for id in pairs(ids)do
        local per={}
        for _,key in ipairs(keys)do
            local s=rows[key]
            if s then per[key]={bags=type(s.bags)=="table"and(s.bags[id]or 0)or nil,bank=type(s.bank)=="table"and(s.bank[id]or 0)or nil}end
        end
        result[id]=per
    end
    O.stockCache={revision=O.revision,sig=sig,result=result}
    return result
end

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
                    local hit=hits[itemID]or{id=itemID,name=name or("#"..itemID),total=0,bagsTotal=0,bankTotal=0,holders={},byKey={}}
                    hits[itemID]=hit;hit.total=hit.total+n;hit[place.."Total"]=hit[place.."Total"]+n
                    local holder=hit.byKey[r.key]
                    if not holder then holder={key=r.key,name=r.name,realm=r.realm,bags=0,bank=0,bagsAt=s.bagsAt,bankAt=s.bankAt};hit.byKey[r.key]=holder;hit.holders[#hit.holders+1]=holder end
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
