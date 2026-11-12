-- Client-observed open-world layer samples. These are short-lived hints, not
-- proof that two players occupy the same physical instance.
--
-- Observed WoW Forever heuristic (algorithm 2): the server-ID part of a
-- Creature GUID (Creature-0-<serverID>-<mapID>-<zoneUID>-<npcID>-<spawnUID>)
-- separates layers; the zoneUID can differ on one layer. The server ID is a
-- candidate, never a guaranteed global layer number. The zoneUID is kept only
-- locally and for the legacy LY record that older clients still compare.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local C={TTL=300,SAMPLE_TTL=60,MAX_ROWS=5000,EVENT_DELAY=.5,MAX_SEEN=64,WINDOW=5,CONFIRM_VOTES=2,SWITCH_VOTES=3,
    TRANSFER_IGNORE=10,BORDER_IGNORE=15,RESCAN={2,5,12},ALGORITHM=2};Z.CommunityLayer=C
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function cleanLayer(value)return L.Int(value,1,4294967295)and value or nil end
local function cleanCall(id,rev,mapID,layerID)
    if id==""and rev==0 and mapID==0 and layerID==0 then return true end
    return L.Text(id,32)and id:match("^[%d%.]+$")and L.Int(rev,1,2147483646)and L.Int(mapID,0,1000000)
        and L.Int(layerID,0,4294967295)and(layerID==0 or mapID>0)
end
local function sessionOrder(session)
    local epoch,sequence=session:match("^(%d+)%.(%d+)%.")
    return tonumber(epoch)or 0,tonumber(sequence)or 0
end
local function markDirty()
    if Z.MarkDirty then Z.MarkDirty("LY")end
    if Z.UI and Z.UI.RefreshPvPHelp then Z.UI.RefreshPvPHelp()end
end
-- Every game value is checked for secrecy before any string, numeric or table
-- operation. A client without issecretvalue has no secret values to fear.
local function secret(value)
    if type(issecretvalue)~="function"then return false end
    local ok,hidden=pcall(issecretvalue,value);return not ok or hidden==true
end
local function safeCall(fn,...)
    if type(fn)~="function"then return nil end
    local ok,value=pcall(fn,...);if not ok or secret(value)then return nil end
    return value
end
local function field(t,key)
    local ok,value=pcall(function()return t[key]end);if not ok or secret(value)then return nil end
    return value
end
-- Strict GUID parser. Only Creature and Vehicle GUIDs qualify; the caller still
-- rejects player-controlled units (pets, totems, guardians).
local function parseGuid(guid)
    if secret(guid)or type(guid)~="string"or#guid>128 then return nil end
    local kind,rest=guid:match("^(%a+)%-(.+)$")
    if kind~="Creature"and kind~="Vehicle"then return nil end
    local fields={};for part in(rest.."-"):gmatch("(.-)-")do fields[#fields+1]=part;if#fields>7 then return nil end end
    if#fields~=6 then return nil end
    for i=1,5 do if not fields[i]:match("^%d+$")or#fields[i]>10 then return nil end end
    if not fields[6]:match("^%x+$")then return nil end
    local server,zoneUID=tonumber(fields[2]),tonumber(fields[4])
    if not cleanLayer(server)or not L.Int(zoneUID,0,4294967295)then return nil end
    return{kind=kind,serverID=server,zoneUID=zoneUID}
end
C.ParseGuid=parseGuid
-- Zone-level map ID: sub-zones and buildings resolve to their Zone ancestor.
-- Without usable map info the raw ID is its own anchor.
local function zoneType()
    local types=type(Enum)=="table"and field(Enum,"UIMapType");local zone=type(types)=="table"and field(types,"Zone")
    return type(zone)=="number"and zone or 3
end
local function zoneOf(mapID)
    if not L.Int(mapID,1,1000000)then return nil end
    C.zoneCache=C.zoneCache or{}
    if C.zoneCache[mapID]then return C.zoneCache[mapID]end
    local id,result,readable=mapID,nil,false
    for _=1,8 do
        local info=type(C_Map)=="table"and safeCall(field(C_Map,"GetMapInfo"),id)
        if type(info)~="table"then break end
        if type(canaccesstable)=="function"then local ok,accessible=pcall(canaccesstable,info);if not ok or accessible~=true then break end end
        readable=true
        local mapType,parent=field(info,"mapType"),field(info,"parentMapID")
        if mapType==zoneType()then result=id;break end
        if L.Int(parent,1,1000000)and parent~=id then id=parent else break end
    end
    result=result or mapID
    if readable then if count(C.zoneCache)>=64 then C.zoneCache={}end;C.zoneCache[mapID]=result end
    return result
end
C.ZoneOf=zoneOf
local function openMap()
    local raw=A.OpenWorld()and A.CurrentMapID()
    local zone=raw and zoneOf(raw);return zone,raw
end
local function ownState(mapID)
    local state=C.own;if not state then return nil end
    local zone=openMap()
    if not zone or zone~=state.zoneMapID or A.Now()-state.at>C.SAMPLE_TTL then return nil end
    if mapID and zoneOf(mapID)~=state.zoneMapID then return nil end
    return state
end
local function snapshot(state)
    return{layerID=state.layerID,zoneMapID=state.zoneMapID,observedAt=state.at,status="observed",algorithmVersion=C.ALGORITHM}
end
-- unknown | observed | stale. Only an observed sample is ever readable.
function C.Status()
    if ownState()then return"observed"end
    local old=C.stale;if old and A.Now()-old.observedAt<=C.TTL then return"stale"end
    return"unknown"
end
function C.Own(mapID)local state=ownState(mapID);return state and state.layerID end
function C.Snapshot(mapID)local state=ownState(mapID);return state and snapshot(state)end
local function remoteRow(key,mapID)
    local row=C.rows2 and C.rows2[key];local peer=Z.db and Z.db.peers[key]
    if not row or not peer or not Z.IsOnline(key)or not peer.session or row.session~=peer.session or row.at>A.Now()+120
        or A.Now()-row.at>C.TTL then return nil end
    local sourceMap=peer.presence and peer.presence.mapID;local expectedMap=zoneOf(mapID or sourceMap)
    if not expectedMap or row.zoneMapID~=expectedMap
        or row.algorithm~=C.ALGORITHM or not cleanLayer(row.layerID)then return nil end
    return row
end
function C.MemberSnapshot(key,mapID)
    if key==Z.me.key then return C.Snapshot(mapID)end
    local row=remoteRow(key,mapID)
    return row and{layerID=row.layerID,zoneMapID=row.zoneMapID,observedAt=row.at,status="observed",algorithmVersion=row.algorithm}
end
function C.Member(key,mapID)local s=C.MemberSnapshot(key,mapID);return s and s.layerID end
-- "probable" (same zone context and same heuristic layer ID), "different" or nil
-- (unknown, stale or no common zone). Never a certain statement.
function C.Relation(key)
    if key==Z.me.key then return nil end
    local mine,theirs=C.Snapshot(),C.MemberSnapshot(key)
    if not mine or not theirs or mine.zoneMapID~=theirs.zoneMapID then return nil end
    return mine.layerID==theirs.layerID and"probable"or"different"
end
function C.Call(key,id,rev,mapID)
    local row=C.rows and C.rows[key];local peer=Z.db and Z.db.peers[key]
    -- The call layer travels in the legacy LY record; it is trusted only from
    -- senders that also publish the versioned L2 record (same layer semantics).
    local v2=C.rows2 and C.rows2[key]
    if not row or not peer or not Z.IsOnline(key)or row.session~=peer.session or A.Now()-row.at>C.TTL
        or not v2 or v2.session~=row.session or v2.algorithm~=C.ALGORITHM
        or row.callID~=id or row.callRev~=rev or row.callMapID~=mapID or not cleanLayer(row.callLayerID)then return nil end
    return row.callLayerID
end
function C.Label(value)
    value=cleanLayer(value);return value and Z.T("Layer ID %d",value)or Z.T("Layer unknown")
end
-- Known layers only: callers decide where an unknown layer is explained (row tooltip, detail footer).
function C.KnownLabel(value)value=cleanLayer(value);return value and Z.T("Layer ID %d",value)or nil end
function C.Decode(wire)
    local f=Z.Network3 and Z.Network3.Unpack(wire);if not f or#f~=8 then return nil end
    local at,mapID,layerID=tonumber(f[2]),tonumber(f[3]),tonumber(f[4])
    local callRev,callMapID,callLayerID=tonumber(f[6]),tonumber(f[7]),tonumber(f[8])
    if not L.Text(f[1],32)or not f[1]:match("^%d+%.%d+%.%d+$")or not L.Int(at,1,4102444800)
        or at>A.Now()+120 or A.Now()-at>C.TTL or not L.Int(mapID,0,1000000)
        or not L.Int(layerID,0,4294967295)or not L.Int(callRev,0,2147483646)
        or not L.Int(callMapID,0,1000000)or not L.Int(callLayerID,0,4294967295)
        or not cleanCall(f[5],callRev,callMapID,callLayerID)
        or mapID==0 and layerID~=0 or mapID>0 and layerID>0 and not cleanLayer(layerID)then return nil end
    return{session=f[1],at=at,mapID=mapID,layerID=cleanLayer(layerID),callID=f[5],callRev=callRev,callMapID=callMapID,callLayerID=cleanLayer(callLayerID)}
end
-- L2 wire: session, at, zoneMapID, layerID, algorithmVersion (zoneMapID and
-- layerID are both 0 for a withdrawal). The layerID is the algorithm-versioned
-- heuristic candidate; receivers compare only equal algorithm versions.
function C.DecodeV2(wire)
    local f=Z.Network3 and Z.Network3.Unpack(wire);if not f or#f~=5 then return nil end
    for i=2,5 do if type(f[i])~="string"or not f[i]:match("^%d+$")or#f[i]>10 then return nil end end
    local at,zoneMapID,layerID,algorithm=tonumber(f[2]),tonumber(f[3]),tonumber(f[4]),tonumber(f[5])
    if not L.Text(f[1],32)or not f[1]:match("^%d+%.%d+%.%d+$")or not L.Int(at,1,4102444800)
        or at>A.Now()+120 or A.Now()-at>C.TTL or not L.Int(zoneMapID,0,1000000)
        or not L.Int(layerID,0,4294967295)or not L.Int(algorithm,1,255)
        or(zoneMapID==0)~=(layerID==0)then return nil end
    return{session=f[1],at=at,zoneMapID=zoneMapID,layerID=cleanLayer(layerID),algorithm=algorithm}
end
-- Shared receive path: session order, monotonic sequence, bounded store.
local function accept(store,decode,same,sender,wire,context)
    local row=decode(wire);local key=Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key]
    if not row or not context or L.Identity(context.origin)~=L.Identity(sender)or context.session~=row.session or context.at~=row.at
        or not L.Int(context.seq,0,2147483646)or not key or peer and peer.retiredSessions and peer.retiredSessions[row.session]then return false end
    if peer and peer.session and peer.session~=row.session then local a,b=sessionOrder(row.session);local x,y=sessionOrder(peer.session);if a<x or a==x and b<=y then return false end end
    row.seq=context.seq
    C[store]=C[store]or{}
    local rows=C[store];local old=rows[key]
    if old then
        if old.session==row.session and(row.at<old.at or row.at==old.at and row.seq<=old.seq)then return true,false end
        if old.session~=row.session then local a,b=sessionOrder(row.session);local x,y=sessionOrder(old.session);if a<x or a==x and b<=y then return false end end
    end
    if not old and count(rows)>=C.MAX_ROWS then local oldest,at;for k,v in pairs(rows)do if not at or v.at<at then oldest,at=k,v.at end end;if oldest then rows[oldest]=nil end end
    local changed=not old or old.session~=row.session or not same(old,row)
    rows[key]=row;return true,changed
end
function C.Receive(sender,wire,context)
    return accept("rows",C.Decode,function(old,row)
        return old.mapID==row.mapID and old.layerID==row.layerID and old.callID==row.callID and old.callRev==row.callRev
            and old.callMapID==row.callMapID and old.callLayerID==row.callLayerID
    end,sender,wire,context)
end
function C.ReceiveV2(sender,wire,context)
    return accept("rows2",C.DecodeV2,function(old,row)
        return old.zoneMapID==row.zoneMapID and old.layerID==row.layerID and old.algorithm==row.algorithm
    end,sender,wire,context)
end
local function units()
    local out={"target","mouseover"};for i=1,40 do out[#out+1]="nameplate"..i end;return out
end
-- Returns the GUID and parsed data of an NPC the unit may count as a vote.
local function probe(unit)
    local guid=safeCall(UnitGUID,unit);local info=parseGuid(guid)
    if info and safeCall(UnitIsPlayer,unit)~=true and safeCall(UnitPlayerControlled,unit)~=true then return guid,info end
end
local function addFound(list,set,guid,info,limit)
    if set[guid]or limit and#list>=limit then return end
    set[guid]=true;list[#list+1]={guid=guid,layer=info.serverID,zoneUID=info.zoneUID}
end
-- Ordered, de-duplicated NPC list: current units first (fixed order), then NPCs
-- probed at their own unit event since the last scan.
local function scan()
    local zone=openMap();local seen=C.seen;C.seen=nil;if not zone then return nil end
    local found,set={},{}
    for _,unit in ipairs(units())do local guid,info=probe(unit);if guid then addFound(found,set,guid,info)end end
    if seen and seen.zoneMapID==zone then for _,entry in ipairs(seen.list)do addFound(found,set,entry.guid,{serverID=entry.layer,zoneUID=entry.zoneUID})end end
    return zone,found
end
-- A zone/instance change or an expired sample ends the own layer. The last value
-- stays visible only as the internal "stale" status, never as a readable layer.
local function invalidate()
    if C.own then C.stale={layerID=C.own.layerID,zoneMapID=C.own.zoneMapID,observedAt=C.own.at};C.own=nil;C.changed=true end
    C.window={};C.windowZone=nil;C.seen=nil
end
-- Deterministic vote: highest count; `unique` is true only if that count is
-- strictly greater than every other layer's (a tie is never a majority). No
-- pairs() order is ever used for the decision.
local function tally(window)
    local votes,last,order={}, {}, {}
    for index,entry in ipairs(window)do
        if not votes[entry.layer]then order[#order+1]=entry.layer end
        votes[entry.layer]=(votes[entry.layer]or 0)+1;last[entry.layer]=index
    end
    local best
    for _,layer in ipairs(order)do
        if not best or votes[layer]>votes[best]or votes[layer]==votes[best]and last[layer]>last[best]then best=layer end
    end
    local unique=best~=nil
    for _,layer in ipairs(order)do if layer~=best and votes[layer]>=votes[best]then unique=false end end
    return votes,last,best,unique
end
local function observe(zone,found,now,clock)
    local ignore=C.ignore and clock<C.ignore.untilAt and C.ignore.guids or nil
    if C.windowZone~=zone then C.window={};C.windowZone=zone end
    local window={}
    for _,entry in ipairs(C.window)do if now-entry.at<=C.SAMPLE_TTL then window[#window+1]=entry end end
    local fresh={}
    for _,seen in ipairs(found)do
        if not(ignore and ignore[seen.guid])then
            fresh[seen.layer]=true;local present
            for _,entry in ipairs(window)do if entry.guid==seen.guid then entry.at=now;present=true;break end end
            if not present then
                window[#window+1]={guid=seen.guid,layer=seen.layer,zoneUID=seen.zoneUID,at=now}
                if#window>C.WINDOW then table.remove(window,1)end
            end
        end
    end
    C.window=window
    local votes,last,best,unique=tally(window);local current=C.own and C.own.zoneMapID==zone and C.own.layerID or nil
    local target
    if current then
        if best and unique and best~=current and votes[best]>=C.SWITCH_VOTES and votes[best]>(votes[current]or 0)then target=best
        elseif fresh[current]then C.own.at=now end
    elseif best and unique and votes[best]>=C.CONFIRM_VOTES then target=best end
    if target then
        C.own={layerID=target,zoneUID=window[last[target]].zoneUID,zoneMapID=zone,at=now};C.stale=nil;C.changed=true
    end
end
local function ownCall()
    local call=Z.PvPHelp and Z.PvPHelp.Own and Z.PvPHelp.Own()
    return call and call.id or"",call and call.rev or 0,call and call.mapID or 0,call and cleanLayer(call.layerID)or 0
end
-- Legacy LY record, unchanged for older clients: it carries the zoneUID those
-- clients compare. Newer clients read the layer from L2 only.
local function publishLegacy(force)
    if not Z.db or not Z.Network3 then return false end
    if not Z.db.consent or not Z.db.autoDiscovery then C.nextPublish=A.Clock()+5;return false end
    local now=A.Now();local mapID,layerID=0,0
    if Z.db.visible then local current=openMap();local state=ownState(current);if state then mapID,layerID=current,cleanLayer(state.zoneUID)or 0 end end
    local callID,callRev,callMapID,callLayerID=ownCall()
    if mapID==0 and callID==""and not C.lastPublished then C.nextPublish=A.Clock()+60;return false end
    local signature=table.concat({Z.session,now,mapID,layerID,callID,callRev,callMapID,callLayerID},"\t")
    local key=table.concat({mapID,layerID,callID,callRev,callMapID,callLayerID},"\t")
    local empty=mapID==0 and callID==""
    if not force and key==C.lastPublished then
        -- An unchanged withdrawal is renewed only while the last non-empty record could still be alive.
        if empty and A.Clock()-(C.lastLive or 0)>=C.TTL then C.nextPublish=A.Clock()+105;return false end
        if A.Clock()<(C.nextPublish or 0)then return false end
    end
    local wire=Z.Network3.Pack({Z.session,now,mapID,layerID,callID,callRev,callMapID,callLayerID})
    local result=Z.Network3.QueuePublic("LY",wire,5,"LAYERSAMPLE")
    if result then if not empty then C.lastLive=A.Clock()end;C.lastPublished=key;C.nextPublish=A.Clock()+105;C.changed=false else C.nextPublish=A.Clock()+5 end
    return result~=nil,signature
end
-- Versioned L2 record, same cadence rules: on change, on refresh, and one
-- withdrawal that is renewed only while a live record could still exist.
local function publishV2(force)
    if not Z.db or not Z.Network3 then return false end
    if not Z.db.consent or not Z.db.autoDiscovery then C.nextPublish2=A.Clock()+5;return false end
    local now=A.Now();local zone,layer=0,0
    if Z.db.visible then local state=ownState(openMap());if state then zone,layer=state.zoneMapID,state.layerID end end
    if zone==0 and not C.lastPublished2 then C.nextPublish2=A.Clock()+60;return false end
    local key=zone.."\t"..layer;local empty=zone==0
    if not force and key==C.lastPublished2 then
        if empty and A.Clock()-(C.lastLive2 or 0)>=C.TTL then C.nextPublish2=A.Clock()+105;return false end
        if A.Clock()<(C.nextPublish2 or 0)then return false end
    end
    local result=Z.Network3.QueuePublic("L2",Z.Network3.Pack({Z.session,now,zone,layer,C.ALGORITHM}),5,"LAYERSAMPLEV2")
    if result then if not empty then C.lastLive2=A.Clock()end;C.lastPublished2=key;C.nextPublish2=A.Clock()+105 else C.nextPublish2=A.Clock()+5 end
    return result~=nil
end
function C.Publish(force)
    local ok,signature=publishLegacy(force);publishV2(force);return ok,signature
end
local function grouped()
    local members=safeCall(GetNumGroupMembers);return type(members)=="number"and members>0
end
function C.Initialize()
    C.rows={};C.rows2={};C.own=nil;C.stale=nil;C.window={};C.windowZone=nil;C.seen=nil;C.ignore=nil;C.rescans=nil;C.zoneCache=nil
    C.nextScan=0;C.nextPublish=0;C.nextPublish2=0;C.lastPublished=nil;C.lastPublished2=nil;C.lastLive=nil;C.lastLive2=nil;C.changed=true;C.grouped=grouped()
end
local function scheduleRescans()
    local clock=A.Clock();C.rescans={};for _,delay in ipairs(C.RESCAN)do C.rescans[#C.rescans+1]=clock+delay end
end
-- A shard transfer moves the player to another layer. NPCs seen before it must
-- not confirm the old layer again for a short time; the cache is dropped and
-- targeted rescans follow.
local function lockKnown(duration)
    local clock=A.Clock();local guids=C.ignore and clock<C.ignore.untilAt and C.ignore.guids or{}
    for _,entry in ipairs(C.window or{})do guids[entry.guid]=true end
    local zone,visible=scan();if zone then for _,entry in ipairs(visible)do guids[entry.guid]=true end end
    C.ignore={guids=guids,untilAt=math.max(clock+duration,C.ignore and C.ignore.untilAt or 0)}
    return clock
end
local function transfer()
    local clock=lockKnown(C.TRANSFER_IGNORE)
    invalidate();C.zoneCache=nil;scheduleRescans();C.nextScan=clock+1
end
-- Events only invalidate the local sample and request a rescan. Publishing is
-- left to Tick, which sends a record only when its content changed or the
-- regular refresh is due, so event bursts cannot flood the lounge.
function C.OnEvent(event)
    if event=="ZONE_CHANGED"or event=="ZONE_CHANGED_INDOORS"then
        -- Subzone changes keep zone and layer; rescan without dropping the sample.
        C.nextScan=0;return
    end
    -- SHARD_TRANSFER_IMMINENT only announces a transfer; the layer stays valid until it happens.
    if event=="SHARD_TRANSFER"then transfer();return end
    if event=="SHARD_TRANSFER_IMMINENT"then return end
    if event=="GROUP_ROSTER_UPDATE"then
        -- Joining or leaving a group can move the player, but the roster is no
        -- proof of a layer change: only rescan and let the votes decide.
        local now=grouped();if now==C.grouped then return end;C.grouped=now
        scheduleRescans();C.nextScan=0;return
    end
    if event=="PLAYER_ENTERING_WORLD"or event=="ZONE_CHANGED_NEW_AREA"then
        -- Units carried over the border still belong to the old zone's layer; only new NPCs may vote at once.
        if event=="ZONE_CHANGED_NEW_AREA"then lockKnown(C.BORDER_IGNORE)end
        invalidate();C.zoneCache=nil;C.changed=true;C.nextScan=0
    end
end
-- Target/mouseover/nameplate events: probe only the event's unit now and pull
-- the full scan forward to at most EVENT_DELAY away. Later events never push
-- an already scheduled scan back, so constant traffic cannot postpone it.
function C.RequestScan(unit)
    if not Z.db then return end
    if not secret(unit)and type(unit)=="string"and(unit=="target"or unit=="mouseover"or unit:match("^nameplate%d+$"))then
        local zone=openMap()
        if zone then
            if not C.seen or C.seen.zoneMapID~=zone then C.seen={zoneMapID=zone,list={},set={}}end
            local guid,info=probe(unit);if guid then addFound(C.seen.list,C.seen.set,guid,info,C.MAX_SEEN)end
        end
    end
    C.nextScan=math.min(C.nextScan or 0,A.Clock()+C.EVENT_DELAY)
end
function C.Tick(force)
    if not Z.db then return end
    local clock=A.Clock()
    if C.ignore and clock>=C.ignore.untilAt then C.ignore=nil end
    if C.rescans then
        for i=#C.rescans,1,-1 do if clock>=C.rescans[i] then table.remove(C.rescans,i);C.nextScan=0 end end
        if#C.rescans==0 then C.rescans=nil end
    end
    if force or clock>=(C.nextScan or 0)then
        local zone,found=scan()
        if zone then
            if C.own and C.own.zoneMapID~=zone then invalidate()end
            observe(zone,found,A.Now(),clock)
        else invalidate()end
        C.nextScan=clock+5
    end
    if C.own and A.Now()-C.own.at>C.SAMPLE_TTL then invalidate()end
    local now=A.Now()
    for _,store in ipairs({"rows","rows2"})do
        for key,row in pairs(C[store]or{})do local peer=Z.db.peers[key];if peer and peer.retiredSessions and peer.retiredSessions[row.session]or now-row.at>C.TTL then C[store][key]=nil;C.changed=true end end
    end
    local currentZone,currentLayer,currentUID=0,0,0
    if Z.db.visible then local state=ownState(openMap());if state then currentZone,currentLayer,currentUID=state.zoneMapID,state.layerID,state.zoneUID or 0 end end
    local callID,callRev,callMapID,callLayerID=ownCall();local currentKey=table.concat({Z.db.visible and 1 or 0,Z.db.consent and 1 or 0,Z.db.autoDiscovery and 1 or 0,currentZone,currentLayer,currentUID,callID,callRev,callMapID,callLayerID},"\t")
    if currentKey~=C.lastStatus then C.lastStatus=currentKey;C.changed=true end
    local changed=C.changed
    if changed then markDirty();C.changed=false end
    -- Publish deduplicates on content; local status changes (UI refresh,
    -- re-confirmed sample) must not resend an identical record.
    if changed or clock>=math.min(C.nextPublish or 0,C.nextPublish2 or 0)then C.Publish(false)end
end
