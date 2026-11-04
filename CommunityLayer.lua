-- Client-observed open-world layer samples. These are short-lived hints, not
-- proof that two players occupy the same physical instance.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local C={TTL=300,SAMPLE_TTL=60,MAX_ROWS=5000,EVENT_DELAY=.5,MAX_SEEN=64};Z.CommunityLayer=C
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
local function parseGuid(guid)
    if type(guid)~="string"or#guid>128 then return nil end
    local kind,rest=guid:match("^(Creature)%-(.+)$")
    if not kind then kind,rest=guid:match("^(Vehicle)%-(.+)$")end
    if not kind then return nil end
    local fields={};for part in(rest.."-"):gmatch("(.-)-")do fields[#fields+1]=part;if#fields>7 then return nil end end
    if#fields~=6 then return nil end
    for i=1,5 do if not fields[i]:match("^%d+$")then return nil end end
    if not fields[6]:match("^%x+$")then return nil end
    local layer=tonumber(fields[4]);if not cleanLayer(layer)then return nil end
    return layer
end
local function openMap()
    local mapID=A.CurrentMapID()
    return A.OpenWorld()and L.Int(mapID,1,1000000)and mapID or nil
end
function C.Own(mapID)
    local state=C.own;local current=openMap()
    if not state or not current or current~=state.mapID or mapID and mapID~=state.mapID or A.Now()-state.at>C.SAMPLE_TTL then return nil end
    return state.layerID
end
function C.Member(key,mapID)
    if key==Z.me.key then return C.Own(mapID)end
    local row=C.rows and C.rows[key];local peer=Z.db and Z.db.peers[key]
    local sourceMap=peer and peer.presence and peer.presence.mapID;local expectedMap=mapID or sourceMap
    if not row or not peer or not Z.IsOnline(key)or not peer.session or row.session~=peer.session or row.at>A.Now()+120
        or A.Now()-row.at>C.TTL or not L.Int(expectedMap,1,1000000)
        or row.mapID~=expectedMap or not cleanLayer(row.layerID)then return nil end
    return row.layerID
end
function C.Call(key,id,rev,mapID)
    local row=C.rows and C.rows[key];local peer=Z.db and Z.db.peers[key]
    if not row or not peer or not Z.IsOnline(key)or row.session~=peer.session or A.Now()-row.at>C.TTL
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
function C.Receive(sender,wire,context)
    local row=C.Decode(wire);local key=Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key]
    if not row or not context or L.Identity(context.origin)~=L.Identity(sender)or context.session~=row.session or context.at~=row.at
        or not L.Int(context.seq,0,2147483646)or not key or peer and peer.retiredSessions and peer.retiredSessions[row.session]then return false end
    if peer and peer.session and peer.session~=row.session then local a,b=sessionOrder(row.session);local x,y=sessionOrder(peer.session);if a<x or a==x and b<=y then return false end end
    row.seq=context.seq
    C.rows=C.rows or{}
    local old=C.rows[key]
    if old then
        if old.session==row.session and(row.at<old.at or row.at==old.at and row.seq<=old.seq)then return true,false end
        if old.session~=row.session then local a,b=sessionOrder(row.session);local x,y=sessionOrder(old.session);if a<x or a==x and b<=y then return false end end
    end
    if not old and count(C.rows)>=C.MAX_ROWS then local oldest,at;for k,v in pairs(C.rows)do if not at or v.at<at then oldest,at=k,v.at end end;if oldest then C.rows[oldest]=nil end end
    local changed=not old or old.session~=row.session or old.mapID~=row.mapID or old.layerID~=row.layerID
        or old.callID~=row.callID or old.callRev~=row.callRev or old.callMapID~=row.callMapID or old.callLayerID~=row.callLayerID
    C.rows[key]=row;return true,changed
end
local function units()
    local out={"target","mouseover"};for i=1,40 do out[#out+1]="nameplate"..i end;return out
end
local function probe(unit,found)
    local guid=A.Call(UnitGUID,unit);local layer=parseGuid(guid)
    if layer and A.Call(UnitIsPlayer,unit)~=true and A.Call(UnitPlayerControlled,unit)~=true then found[guid]=layer end
end
local function scan()
    local mapID=openMap();local seen=C.seen;C.seen=nil;if not mapID then return nil end
    local found={};for _,unit in ipairs(units())do probe(unit,found)end
    -- NPCs probed at their own unit event since the last scan still count, so a
    -- quick mouseover sweep keeps its second distinct NPC for confirmation.
    if seen and seen.mapID==mapID then for guid,layer in pairs(seen.found)do found[guid]=found[guid]or layer end end
    return mapID,found
end
local function observe(mapID,found,now)
    local seen={};for guid,layer in pairs(found)do seen[layer]=seen[layer]or{};seen[layer][guid]=true end
    local confirmed
    for layer,guids in pairs(seen)do local distinct=0;for _ in pairs(guids)do distinct=distinct+1 end;if distinct>=2 then confirmed=layer;break end end
    if not confirmed and C.own and C.own.mapID==mapID and seen[C.own.layerID]then C.own.at=now end
    if not confirmed then
        local layer,guid;for candidate,guids in pairs(seen)do for value in pairs(guids)do layer,guid=candidate,value;break end;if guid then break end end
        if layer then
            if C.candidate and C.candidate.mapID==mapID and C.candidate.layerID==layer and C.candidate.at>=now-60 and C.candidate.guid~=guid then confirmed=layer end
            C.candidate={mapID=mapID,layerID=layer,guid=guid,at=now}
        end
    end
    if confirmed then
        C.candidate=nil
        if not C.own or C.own.mapID~=mapID or C.own.layerID~=confirmed then C.own={mapID=mapID,layerID=confirmed,at=now};C.changed=true
        else C.own.at=now end
    elseif C.own and C.own.mapID~=mapID then C.own=nil;C.changed=true end
end
local function ownCall()
    local call=Z.PvPHelp and Z.PvPHelp.Own and Z.PvPHelp.Own()
    return call and call.id or"",call and call.rev or 0,call and call.mapID or 0,call and cleanLayer(call.layerID)or 0
end
function C.Publish(force)
    if not Z.db or not Z.Network3 then return false end
    if not Z.db.consent or not Z.db.autoDiscovery then C.nextPublish=A.Clock()+5;return false end
    local now=A.Now();local mapID,layerID=0,0
    if Z.db.visible then local current=openMap();local own=C.Own(current);if own then mapID,layerID=current,own end end
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
local function grouped()
    local members=A.Call(GetNumGroupMembers);return type(members)=="number"and members>0
end
function C.Initialize()
    C.rows={};C.own=nil;C.candidate=nil;C.seen=nil;C.nextScan=0;C.nextPublish=0;C.lastPublished=nil;C.lastLive=nil;C.changed=true;C.grouped=grouped()
end
-- Events only invalidate the local sample and request a rescan. Publishing is
-- left to Tick, which sends a record only when its content changed or the
-- regular refresh is due, so event bursts cannot flood the lounge.
function C.OnEvent(event)
    if event=="ZONE_CHANGED"or event=="ZONE_CHANGED_INDOORS"then
        -- Subzone changes keep map and layer; rescan without dropping the sample.
        C.nextScan=0;return
    end
    if event=="GROUP_ROSTER_UPDATE"then
        -- Joining or leaving a group can move the player to another layer;
        -- roster churn inside an existing group cannot.
        local now=grouped();if now==C.grouped then return end;C.grouped=now
    end
    if event=="PLAYER_ENTERING_WORLD"or event=="ZONE_CHANGED_NEW_AREA"or event=="GROUP_ROSTER_UPDATE"then
        C.own=nil;C.candidate=nil;C.seen=nil;C.changed=true;C.nextScan=0
    end
end
-- Target/mouseover/nameplate events: probe only the event's unit now and pull
-- the full scan forward to at most EVENT_DELAY away. Later events never push
-- an already scheduled scan back, so constant traffic cannot postpone it.
function C.RequestScan(unit)
    if not Z.db then return end
    if A.Safe(unit)and type(unit)=="string"and(unit=="target"or unit=="mouseover"or unit:match("^nameplate%d+$"))then
        local mapID=openMap()
        if mapID then
            if not C.seen or C.seen.mapID~=mapID then C.seen={mapID=mapID,found={},count=0}end
            local found={};probe(unit,found)
            for guid,layer in pairs(found)do if not C.seen.found[guid]and C.seen.count<C.MAX_SEEN then C.seen.found[guid]=layer;C.seen.count=C.seen.count+1 end end
        end
    end
    C.nextScan=math.min(C.nextScan or 0,A.Clock()+C.EVENT_DELAY)
end
function C.Tick(force)
    if not Z.db then return end
    local clock=A.Clock();if force or clock>=(C.nextScan or 0)then local mapID,found=scan();if mapID then if C.own and C.own.mapID~=mapID then C.own=nil;C.candidate=nil;C.changed=true end;observe(mapID,found,A.Now())elseif C.own then C.own=nil;C.changed=true end;C.nextScan=clock+5 end
    if C.own and A.Now()-C.own.at>C.SAMPLE_TTL then C.own=nil;C.changed=true end
    local now=A.Now();for key,row in pairs(C.rows or{})do local peer=Z.db.peers[key];if peer and peer.retiredSessions and peer.retiredSessions[row.session]or now-row.at>C.TTL then C.rows[key]=nil;C.changed=true end end
    local currentMap,currentLayer=0,0;if Z.db.visible then local map=openMap();local layer=map and C.Own(map);if layer then currentMap,currentLayer=map,layer end end
    local callID,callRev,callMapID,callLayerID=ownCall();local currentKey=table.concat({Z.db.visible and 1 or 0,Z.db.consent and 1 or 0,Z.db.autoDiscovery and 1 or 0,currentMap,currentLayer,callID,callRev,callMapID,callLayerID},"\t")
    if currentKey~=C.lastStatus then C.lastStatus=currentKey;C.changed=true end
    local changed=C.changed
    if changed then markDirty();C.changed=false end
    -- Publish deduplicates on map/layer/call content; local status changes
    -- (UI refresh, re-confirmed sample) must not resend an identical record.
    if changed or clock>=(C.nextPublish or 0)then C.Publish(false)end
end
