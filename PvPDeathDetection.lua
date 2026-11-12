-- PvP death detection. At PLAYER_DEAD the place of death is secured at once; the Death Recap is read
-- afterwards (0.3 s, then once more 0.7 s later) and classified. Only a death whose fatal blow came from
-- a player (or a player's pet) is confirmed. Everything unreadable stays unknown and never counts.
-- The Recap is no full combat log: attackers are only ever a minimum, never an exact number.
-- GUIDs are used for de-duplication in memory only; they are neither saved nor sent.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local D={WAIT=.3,RETRY=.7,MAX_ATTACKERS=5,MAX_EVENTS=40,CACHE_TTL=120,CACHE_MAX=60,serial=0,armed=false}
Z.PvPDeath=D

-- A secret value errors when compared; every API value passes through here before use.
local function public(v)
    if v==nil then return nil end
    if type(issecretvalue)=="function"then local ok,secret=pcall(issecretvalue,v);if not ok or secret then return nil end end
    return v
end
local function text(v,max)v=public(v);return type(v)=="string"and L.Text(v,max,false)and v or nil end
local function flagSet(flags,mask)
    if type(flags)~="number"or type(mask)~="number"or mask<=0 then return false end
    if type(bit)=="table"and bit.band then return bit.band(flags,mask)~=0 end
    return math.floor(flags/mask)%2==1 -- single-bit masks only
end
local function objectFlag(name)local F=type(Enum)=="table"and Enum.CombatLogObject;local v=F and F[name];return type(v)=="number"and v or nil end
local function guidKind(guid)return type(guid)=="string"and guid:match("^(%a+)%-")or nil end

-- Classifies one Recap event. cause: player | mob | environment | self | unknown.
function D.Classify(e,myGUID)
    if type(e)~="table"then return{cause="unknown"}end
    local event=public(e.event)
    if event=="ENVIRONMENTAL_DAMAGE"then return{cause="environment"}end
    local guid,flags=public(e.sourceGUID),public(e.sourceFlags)
    if type(guid)~="string"then guid=nil end
    if type(flags)~="number"then flags=nil end
    if public(e.hideCaster)==true or not(guid or flags)then return{cause="unknown"}end
    if guid and myGUID and guid==myGUID then return{cause="self"}end
    local kind=guidKind(guid)
    local control,pet,object=objectFlag("ControlPlayer"),objectFlag("TypePet"),objectFlag("TypeObject")
    if flags and control then
        if flagSet(flags,control)then return{cause="player",pet=(pet and flagSet(flags,pet))or kind=="Pet"or nil,guid=guid,name=text(e.sourceName,80)}end
        if flagSet(flags,object or 0)or kind=="GameObject"then return{cause="unknown"}end
        return{cause="mob"}
    end
    if kind=="Player"then return{cause="player",guid=guid,name=text(e.sourceName,80)}end
    if kind=="Pet"then return{cause="player",pet=true,guid=guid,name=text(e.sourceName,80)}end
    if kind=="Creature"or kind=="Vehicle"then return{cause="mob"}end
    return{cause="unknown"}
end

-- Short-lived GUID -> level cache fed from target, mouseover and nameplates.
local function validLevel(v)v=public(v);return type(v)=="number"and v==math.floor(v)and v>=1 and v<=100 and v or nil end
function D.Observe(unit)
    if type(unit)~="string"then return end
    if A.Call(UnitIsPlayer,unit)~=true then return end
    local guid=public(A.Call(UnitGUID,unit));if type(guid)~="string"or guidKind(guid)~="Player"then return end
    local level=validLevel(A.Call(UnitLevel,unit));D.cache=D.cache or{}
    local entry=D.cache[guid];if not level and not entry then return end
    if not D.cache[guid]then
        local n=0;local oldest,at;for g,v in pairs(D.cache)do n=n+1;if not at or v.at<at then oldest,at=g,v.at end end
        if n>=D.CACHE_MAX and oldest then D.cache[oldest]=nil end
    end
    D.cache[guid]={level=level or entry and entry.level,at=A.Clock()}
end
local function cachedLevel(guid)
    local entry=D.cache and D.cache[guid];if not entry then return nil end
    if A.Clock()-entry.at>D.CACHE_TTL then D.cache[guid]=nil;return nil end
    return entry.level
end

-- Name, class, race and level of one player GUID; nil for whatever cannot be read.
local function resolve(guid,eventName)
    local out={name=eventName}
    local className,classFile,raceName,_,_,name,realm=nil,nil,nil,nil,nil,nil,nil
    if type(GetPlayerInfoByGUID)=="function"then
        local ok,a,b,c,d,e,f,g=pcall(GetPlayerInfoByGUID,guid)
        if ok then className,classFile,raceName,name,realm=public(a),public(b),public(c),public(f),public(g)end
    end
    if not out.name then
        name=text(name,64);realm=text(realm,48)
        if name then out.name=realm and name.."-"..realm or name end
    end
    out.classFile=type(classFile)=="string"and #classFile<=16 and classFile:match("^[A-Z_]+$")and classFile or nil
    out.race=text(raceName,24)
    local level
    if type(UnitTokenFromGUID)=="function"then
        local ok,unit=pcall(UnitTokenFromGUID,guid);unit=ok and public(unit)or nil
        if type(unit)=="string"then level=validLevel(A.Call(UnitLevel,unit))end
    end
    out.level=level or cachedLevel(guid)
    if not out.name then return nil end
    return out
end

local function signature(e)
    if type(e)~="table"then return nil end
    local parts={}
    for _,k in ipairs({"event","timestamp","amount","sourceGUID","environmentalType"})do
        local v=public(e[k]);parts[#parts+1]=v==nil and"?"or tostring(v)
    end
    return table.concat(parts,"|")
end

-- Builds the death record from the Recap events (nil: no readable recap -> unknown, not confirmed).
function D.Evaluate(events,snapshot,myGUID)
    local fatal=type(events)=="table"and events[1]or nil
    local c=D.Classify(fatal,myGUID)
    if c.cause~="player"then return nil,c.cause end
    local order,seen={},{}
    local function add(class)
        if class.cause=="player"and not class.pet and class.guid and not seen[class.guid]then seen[class.guid]=true;order[#order+1]=class end
    end
    for i=1,math.min(#events,D.MAX_EVENTS)do add(i==1 and c or D.Classify(events[i],myGUID))end
    local death={id=snapshot.at.."."..snapshot.serial,at=snapshot.at,cause="player",confirmed=true,
        mapID=snapshot.mapID,area=snapshot.area,subzone=snapshot.subzone,hasPos=snapshot.hasPos,x=snapshot.x,y=snapshot.y,layerID=snapshot.layerID,
        attackers={},minAttackers=math.max(1,#order),attackersComplete=false}
    for _,class in ipairs(order)do
        if #death.attackers>=D.MAX_ATTACKERS then break end
        local person=resolve(class.guid,class.name)
        if person then
            death.attackers[#death.attackers+1]=person
            if class==c then death.killer=person end
        end
    end
    return death,"player"
end

local function snapshotNow(at)
    local loc=A.PvpLocation(false);local snap=Z.CommunityLayer and Z.CommunityLayer.Snapshot and Z.CommunityLayer.Snapshot(loc.mapID)
    D.serial=D.serial+1
    return{at=at,serial=D.serial,mapID=loc.mapID,area=loc.area,subzone=loc.subzone,hasPos=loc.hasPos,x=loc.x,y=loc.y,layerID=snap and snap.layerID or nil}
end

function D.Initialize()D.pending=nil;D.cache={};D.armed=not A.IsDeadOrGhost()end

-- One death per life: PLAYER_DEAD may fire again while dead, a reload while dead does not re-arm.
function D.OnEvent(event)
    if event=="PLAYER_DEAD"then
        if not D.armed or D.pending then return end
        D.armed=false
        if A.Call(UnitIsFeignDeath,"player")==true or not A.OpenWorld()then return end
        D.pending={snapshot=snapshotNow(A.Now()),due=A.Clock()+D.WAIT,stage=1}
    elseif(event=="PLAYER_ALIVE"or event=="PLAYER_UNGHOST")and not A.IsDeadOrGhost()then D.armed=true end
end

local function readEvents()
    local api=C_DeathRecap;if type(api)~="table"or type(api.GetRecapEvents)~="function"then return nil end
    if type(api.HasRecapEvents)=="function"then local ok,has=pcall(api.HasRecapEvents);if not ok or public(has)~=true then return nil end end
    local ok,events=pcall(api.GetRecapEvents);events=ok and public(events)or nil
    return type(events)=="table"and events or nil
end

function D.Tick()
    local p=D.pending;if not p or A.Clock()<p.due then return end
    local events=readEvents();local e=events and events[1];local sig=signature(e)
    local store=Z.PvPHelp and Z.PvPHelp.store
    -- A recap identical to the one of the previous death is stale: it belongs to an earlier life.
    local fresh=sig~=nil and(not store or sig~=store.recapSig)
    if not fresh then
        if p.stage==1 then p.stage=2;p.due=A.Clock()+D.RETRY;return end
        D.pending=nil;D.last={cause="unknown"};return
    end
    D.pending=nil
    if store then store.recapSig=sig end
    local death,cause=D.Evaluate(events,p.snapshot,public(A.Call(UnitGUID,"player")))
    D.last={cause=cause,death=death}
    if death and Z.PvPHelp then Z.PvPHelp.RecordDeath(death)end
end
return D
