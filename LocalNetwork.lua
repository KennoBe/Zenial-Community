-- Local network (hybrid network levels B and C): verified addon-whisper routes without the Battle.net lounge.
-- Discovery only collects candidates from observable contacts (guild/group greetings, target pings, gateway lists).
-- The W/R whisper handshake of BattleNetTransport stays the only trust anchor: a frame is read only from the native
-- sender of an existing route, and every session in it must be that route's session. Anything a gateway reports
-- about third players is indirect: it keeps its original time and session and never enters the Battle.net mesh.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local LN={PREFIX="ZENIALLN1",PROTO=1,CHUNK=190,MAX_PARTS=24,TTL=300,
    HANDSHAKE_GAP=3,PROBES_PER_MINUTE=10,MAX_DIRECT=16,RETRY=600,PROBE_WAIT=35,MAX_KNOWN=64,
    PRESENCE_GAP=60,HEARTBEAT=150,BUNDLE_GAP=60,HELLO_GAP=30,MESH_GRACE=60,
    MAX_CANDIDATES=64,CANDIDATE_TTL=600,MAX_OUT_FRAMES=96,MAX_OUT_BYTES=24576,MAX_IN_FLIGHT=3,TRANSPORT_BUSY=24,
    MAX_ASSEMBLIES=32,MAX_ASSEMBLY_BYTES=65536,ASSEMBLY_TTL=30,INBOUND_PER_MINUTE=120,
    CAP_PRESENCE=1,CAP_GATEWAY=2,CAP_MESH=4,CAP_BUNDLE=8,CAP_RELAY=16,
    PRIORITY_PRESENCE=4,PRIORITY_GATEWAY=3,PRIORITY_BACKGROUND=2}
Z.LocalNetwork=LN
local H={} -- message handlers by kind
LN.handlers=H
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function has(caps,bit)return math.floor((tonumber(caps)or 0)/bit)%2==1 end
LN.Has=has
local function trace(event,...)if Z.Diagnostics then Z.Diagnostics.Record("local:"..event,...)end end
local function stat(field,n)LN.stats[field]=(LN.stats[field]or 0)+(n or 1)end
local function reject(reason,...)
    stat("rejected");LN.stats.lastReject=reason;LN.rejects[reason]=(LN.rejects[reason]or 0)+1
    trace("reject_"..reason,...);return false
end
LN.Reject=reject
local function transport()return Z.BattleNetTransport end
local function route(id)local routes=transport()and transport().routes;return routes and routes["WHISPER:"..id]or nil end
LN.Route=route
function LN.Enabled()
    local b=transport()
    return Z.db and Z.db.consent and Z.db.autoDiscovery and Z.db.localNetwork~=false and Z.identityReady and not Z.offlineOnly
        and LN.registered and b and b.registered and b.jobs and LN.stats and true or false
end
local function me()return Z.me and L.Identity(Z.me.target)end

-- ===== Sending: own frame budget below every mesh and private priority =====
-- Frame: L1|<message>|<part>|<total>|<KIND>|<chunk>. A message's frames leave in order; messages with the same
-- dedupe token replace an older one that has not started yet.
local function dropMessage(index)
    local m=table.remove(LN.out,index);if not m then return end
    LN.outBytes=math.max(0,LN.outBytes-m.bytes);LN.outFrames=math.max(0,LN.outFrames-(#m.parts-m.next+1))
end
function LN.Queue(id,kind,payload,priority,dedupe)
    if not LN.Enabled()or type(payload)~="string"or not route(id)then return false end
    local total=math.max(1,math.ceil(#payload/LN.CHUNK))
    if total>LN.MAX_PARTS then return reject("too_large",kind)end
    if dedupe then for i=#LN.out,1,-1 do local m=LN.out[i];if m.dedupe==dedupe and m.next==1 then dropMessage(i)end end end
    LN.serial=LN.serial%999999+1;LN.order=LN.order+1
    local m={id=id,kind=kind,priority=priority or LN.PRIORITY_BACKGROUND,dedupe=dedupe,order=LN.order,parts={},next=1,bytes=0}
    for part=1,total do
        local frame="L1|"..LN.serial.."|"..part.."|"..total.."|"..kind.."|"..payload:sub((part-1)*LN.CHUNK+1,part*LN.CHUNK)
        m.parts[part]=frame;m.bytes=m.bytes+#frame
    end
    -- A full outbox gives way to higher priorities only; nothing grows beyond the fixed bounds.
    while LN.outFrames+total>LN.MAX_OUT_FRAMES or LN.outBytes+m.bytes>LN.MAX_OUT_BYTES do
        local victim
        for i,old in ipairs(LN.out)do if old.next==1 and old.priority<m.priority and(not victim or old.priority<LN.out[victim].priority)then victim=i end end
        if not victim then stat("dropped");return reject("queue_full",kind)end
        dropMessage(victim);stat("dropped")
    end
    LN.out[#LN.out+1]=m;LN.outBytes=LN.outBytes+m.bytes;LN.outFrames=LN.outFrames+total
    return true
end
local function queueValues(id,kind,values,priority,dedupe)return LN.Queue(id,kind,Z.Network3.Pack(values),priority,dedupe)end
LN.QueueValues=queueValues
local function pump(clock)
    local elapsed=math.max(0,math.min(4,clock-(LN.lastClock or clock)));LN.lastClock=clock
    LN.tokens=math.min(4,LN.tokens+elapsed)
    -- A lost completion must never block the local network for good.
    if LN.inFlight>0 and clock-(LN.progressAt or clock)>60 then LN.inFlight=0 end
    local b=transport()
    while LN.tokens>=1 and LN.inFlight<LN.MAX_IN_FLIGHT and#LN.out>0 do
        -- Battle.net mesh and private actions share the transport queue: back off while it is busy.
        if#b.jobs>=LN.TRANSPORT_BUSY then stat("deferred");return end
        local index,m
        for i,row in ipairs(LN.out)do
            local started,best=row.next>1,m and m.next>1
            if not m or started and not best or started==best and(row.priority>m.priority or row.priority==m.priority and row.order<m.order)then index,m=i,row end
        end
        local r=route(m.id)
        if not r or m.failed then dropMessage(index);stat("dropped")
        else
            local frame=m.parts[m.next]
            local accepted=b.QueueData(r,"L",frame,false,nil,m.priority,function(result)
                LN.inFlight=math.max(0,LN.inFlight-1);LN.progressAt=A.Clock()
                if result=="ok"then stat("sentFrames");stat("sentBytes",#frame)
                elseif result~="superseded"then m.failed=true;stat("sendErrors")end
            end,{reason="local_"..m.kind})
            if not accepted then stat("throttled");return end
            LN.inFlight=LN.inFlight+1;LN.tokens=LN.tokens-1;LN.progressAt=clock
            m.next=m.next+1;LN.outFrames=math.max(0,LN.outFrames-1)
            if m.next>#m.parts then table.remove(LN.out,index);LN.outBytes=math.max(0,LN.outBytes-m.bytes)end
        end
    end
end

-- ===== Peers =====
local function meshRoutes()local n=0;for _,r in pairs(transport().routes or{})do if r.transport=="BNET"then n=n+1 end end;return n end
function LN.MeshActive()return(LN.meshCount or 0)>0 end
-- Both sides inside the Battle.net mesh: the mesh carries presence, the local route only exchanged capabilities.
local function needsDirect(p)return not(LN.MeshActive()and p.mesh)end
LN.NeedsDirect=needsDirect
local function peerFor(id,r)
    local p=LN.peers[id]
    if not p or p.session~=r.session then
        p={name=r.name,session=r.session,since=A.Clock(),source=p and p.session==r.session and p.source or"inbound",caps=0};LN.peers[id]=p
    end
    return p
end
function LN.Capabilities()
    local caps=LN.CAP_PRESENCE+LN.CAP_BUNDLE
    if LN.MeshActive()then caps=caps+LN.CAP_MESH end
    if LN.CanServe and LN.CanServe()then caps=caps+LN.CAP_GATEWAY;if not LN.MeshActive()then caps=caps+LN.CAP_RELAY end end
    return caps
end
local function sendHello(id,p)
    local load=LN.serve and count(LN.serve.clients)or 0
    local size=LN.OfferSize and LN.OfferSize()or 0
    if queueValues(id,"HI",{tostring(LN.PROTO),LN.Capabilities(),Z.session,LN.MeshActive()and 1 or 0,load,size},LN.PRIORITY_PRESENCE,"HI:"..id)then
        p.helloSent=p.session;p.helloSentAt=A.Clock();p.helloCaps=LN.Capabilities();return true
    end
    return false
end
local function remember(id,name,source)
    LN.known[id]={name=name,at=A.Clock(),source=source}
    if count(LN.known)>LN.MAX_KNOWN then
        local oldest;for k,row in pairs(LN.known)do if not oldest or row.at<LN.known[oldest].at then oldest=k end end
        LN.known[oldest]=nil
    end
end
-- Called by BattleNetTransport for every confirmed route; only addon-whisper routes join the local network.
function LN.OnConnected(r,fresh)
    if not LN.stats or type(r)~="table"or r.transport~="WHISPER"then return end
    local id=L.Identity(r.name);if not id then return end
    local probe=LN.probes[id];local old=LN.peers[id]
    local p=peerFor(id,r)
    if probe then p.source=probe.source elseif old and old.source and p.source=="inbound"then p.source=old.source end
    LN.probes[id]=nil;LN.candidates[id]=nil;LN.failed[id]=nil
    remember(id,r.name,p.source)
    trace("connected",r.name,p.source,fresh and"fresh"or"refresh")
    if LN.Enabled()and p.helloSent~=r.session then sendHello(id,p)end
end

-- ===== Discovery candidates =====
local SOURCE_PRIORITY={group=90,gateway_group=85,known=75,guild=70,gateway_guild=65,whisper=60,target=60,gateway_contact=50,gateway=20}
LN.SOURCE_PRIORITY=SOURCE_PRIORITY
local function reportedByMesh(key)
    local peer=key and Z.db.peers[key];local source=LN.sources[key]
    return peer and peer.networkReported and Z.Network3.IsOnline(key)and not(source and source.via=="gateway")or false
end
-- A candidate is only a name to try: nothing is trusted or shown before the whisper handshake succeeds.
function LN.Candidate(name,source)
    if not LN.Enabled()then return false end
    local id,target=L.Identity(name)
    if not id or type(target)~="string"or not target:find(" ",1,true)then trace("candidate_identity",source);return false end
    if id==me()then return false end
    local key=L.ScopeKey(target,Z.me.realm,Z.me.faction)
    if key and Z.db.blocked[key]then return false end
    if route(id)then local p=LN.peers[id];if p and p.source=="inbound"then p.source=source end;return false end
    -- Inside the mesh a player the mesh already reports needs no extra handshake.
    if LN.MeshActive()and reportedByMesh(key)then stat("meshCovered");return false end
    local priority=SOURCE_PRIORITY[source]or 10;local clock=A.Clock();local row=LN.candidates[id]
    if row then if priority>row.priority then row.priority,row.source=priority,source end;row.at=clock;return true end
    if count(LN.candidates)>=LN.MAX_CANDIDATES then
        local lowest;for k,c in pairs(LN.candidates)do if not lowest or c.priority<LN.candidates[lowest].priority or c.priority==LN.candidates[lowest].priority and c.at<LN.candidates[lowest].at then lowest=k end end
        if not lowest or LN.candidates[lowest].priority>=priority then stat("candidateLimit");return false end
        LN.candidates[lowest]=nil
    end
    -- A guild greeting reaches everybody at once; spread the answers.
    local delay=(source=="guild"or source=="known")and math.random(2,15)or 1
    LN.candidates[id]={name=target,source=source,priority=priority,due=clock+delay,at=clock}
    trace("candidate",target,source);return true
end
local CHANNEL_SOURCE={GUILD="guild",OFFICER="guild",PARTY="group",RAID="group",INSTANCE_CHAT="group",WHISPER="whisper"}
-- A confirmed ZENIAL presence signal (CrossFactionPresence) of a player of unknown network state.
function LN.OnPresenceSignal(name,channel)
    return LN.Candidate(name,CHANNEL_SOURCE[type(channel)=="string"and channel:upper()or""]or"whisper")
end
function LN.DirectCount()
    local n=0;for id,p in pairs(LN.peers)do if p.hello and route(id)then n=n+1 end end;return n
end
local function probeTick(clock)
    local b=transport()
    for id,p in pairs(LN.probes)do
        if route(id)then LN.probes[id]=nil
        elseif clock-p.at>LN.PROBE_WAIT then LN.probes[id]=nil;LN.failed[id]=clock+LN.RETRY;stat("probeFailures");trace("probe_failed",p.name,p.source)end
    end
    for id,untilAt in pairs(LN.failed)do if clock>=untilAt then LN.failed[id]=nil end end
    for id,row in pairs(LN.candidates)do if clock-row.at>LN.CANDIDATE_TTL or route(id)then LN.candidates[id]=nil end end
    local window=LN.probeWindow;while window[1]and clock-window[1]>=60 do table.remove(window,1)end
    if not next(LN.candidates)or clock<LN.nextProbe then return end
    if#window>=LN.PROBES_PER_MINUTE then stat("probeBudget");return end
    if LN.DirectCount()>=LN.MAX_DIRECT then stat("directLimit");return end
    if#b.jobs>=16 then stat("deferred");return end
    local best,bestID
    for id,row in pairs(LN.candidates)do
        local key="WHISPER:"..id
        if clock>=row.due and not LN.failed[id]and not LN.probes[id]and not b.pending[key]and not(b.failed[key]and clock<b.failed[key])
            and(not best or row.priority>best.priority or row.priority==best.priority and row.due<best.due)then best,bestID=row,id end
    end
    if not best then return end
    LN.candidates[bestID]=nil;LN.nextProbe=clock+LN.HANDSHAKE_GAP
    local ok,why=b.Probe("WHISPER",best.name,"local_"..best.source)
    if ok then window[#window+1]=clock;LN.probes[bestID]={at=clock,name=best.name,source=best.source};stat("probes");trace("probe",best.name,best.source)
    else LN.failed[bestID]=clock+LN.RETRY;trace("probe_skipped",best.name,why)end
end

-- ===== Receiving =====
function LN.Receive(sender,payload,r)
    if not LN.stats or not LN.Enabled()then return false end
    if type(payload)~="string"or#payload>240 then return reject("frame_size")end
    local id=L.Identity(sender);if not id or type(r)~="table"or L.Identity(r.name)~=id then return reject("route",sender)end
    local clock=A.Clock();local row=LN.inbound[id]
    if not row then if count(LN.inbound)>=256 then return reject("inbound_table")end;row={at=clock,n=0};LN.inbound[id]=row end
    if clock-row.at>=60 then row.at=clock;row.n=0 end
    row.n=row.n+1;if row.n>LN.INBOUND_PER_MINUTE then return reject("inbound_rate",sender)end
    local message,part,total,kind,chunk=payload:match("^L1|(%d+)|(%d+)|(%d+)|(%u%u)|(.*)$")
    part,total=tonumber(part),tonumber(total)
    if not message or#message>6 or not L.Int(total,1,LN.MAX_PARTS)or not L.Int(part,1,total)or#chunk>LN.CHUNK then return reject("frame",sender)end
    stat("receivedFrames");stat("receivedBytes",#payload)
    local wire
    if total==1 then wire=chunk
    else
        local token=id..":"..message;local p=LN.assemblies[token]
        local function release()if LN.assemblies[token]then LN.assemblies[token]=nil;LN.assemblyBytes=math.max(0,LN.assemblyBytes-p.size)end end
        if not p then
            local mine=0;for _,other in pairs(LN.assemblies)do if other.id==id then mine=mine+1 end end
            if mine>=2 or count(LN.assemblies)>=LN.MAX_ASSEMBLIES then return reject("assembly_limit",sender)end
            p={id=id,kind=kind,total=total,chunks={},size=0,at=clock};LN.assemblies[token]=p
        end
        if p.kind~=kind or p.total~=total or p.chunks[part]and p.chunks[part]~=chunk then release();return reject("fragment_conflict",sender)end
        if p.chunks[part]then stat("duplicates");return true end
        if LN.assemblyBytes+#chunk>LN.MAX_ASSEMBLY_BYTES then release();return reject("assembly_bytes",sender)end
        p.chunks[part]=chunk;p.size=p.size+#chunk;LN.assemblyBytes=LN.assemblyBytes+#chunk
        for i=1,total do if not p.chunks[i]then return true end end
        wire=table.concat(p.chunks);release()
    end
    local handler=H[kind];if not handler then return reject("kind",kind)end
    local ok,result=pcall(handler,id,wire,r)
    if not ok then trace("handler_error",kind,result);return reject("handler",kind)end
    return result
end
function H.HI(id,wire,r)
    local f=Z.Network3.Unpack(wire)
    -- Later versions may append fields; the first six keep their meaning.
    if not f or#f<6 then return reject("hello")end
    if f[1]~=tostring(LN.PROTO)then return reject("protocol",f[1])end
    if f[3]~=r.session then return reject("session",r.name)end
    local caps,mesh,load,size=tonumber(f[2]),tonumber(f[4]),tonumber(f[5]),tonumber(f[6])
    if not L.Int(caps,0,1023)or not L.Int(mesh,0,1)or not L.Int(load,0,99)or not L.Int(size,0,100000)then return reject("hello")end
    local p=peerFor(id,r);local first=not p.hello
    p.hello=A.Clock();p.caps=caps;p.mesh=mesh==1;p.load=load;p.size=size;p.rx=A.Clock()
    if p.helloSent~=r.session then sendHello(id,p)end
    if first then p.presenceSig,p.presenceAt,p.bundleRev,p.bundleAt=nil,nil,nil,nil;LN.maintainDue=0 end
    trace("hello",r.name,caps);return true
end
local function directPeer(id,r)
    local p=LN.peers[id]
    if not p or not p.hello or p.session~=r.session then return nil end
    p.rx=A.Clock();return p
end
function H.PR(id,wire,r)
    if not directPeer(id,r)then return reject("no_hello",r.name)end
    local f=Z.Network3.Unpack(wire)
    if not f or f[1]~="P"or f[2]~="3"or f[3]~=r.session then return reject("presence_session",r.name)end
    local N=Z.Network3;N.meshContext=nil
    local ok,changed=N.ProcessComplete(r.name,"PUBLIC","P",wire)
    if not ok then return reject("presence",r.name)end
    local key=Z.ResolvePeerKey(r.name)
    LN.direct[id]={wire=wire,session=r.session,at=A.Now(),name=r.name}
    if key then LN.sources[key]={via="direct",at=A.Now()}end
    stat("presenceReceived")
    if changed~=false and Z.MarkDirty then Z.MarkDirty("P")end
    return true
end
function H.PT(id,wire,r)
    if not directPeer(id,r)then return reject("no_hello",r.name)end
    local f=Z.Network3.Unpack(wire)
    if not f or f[1]~=r.session then return reject("session",r.name)end
    local d=LN.direct[id];if d and d.session==r.session then d.at=A.Now()end
    local key=Z.ResolvePeerKey(r.name);local source=key and LN.sources[key]
    if source and source.via=="direct"then source.at=A.Now()end
    return true
end
function H.BU(id,wire,r)
    if not directPeer(id,r)then return reject("no_hello",r.name)end
    local ok,changed=Z.Network3.ProcessComplete(r.name,"PUBLIC","B",wire)
    if not ok then return reject("bundle",r.name)end
    stat("bundlesReceived")
    if changed~=false and Z.MarkDirty then Z.MarkDirty("B")end
    return true
end

-- ===== Maintenance =====
local function score(id,p)
    local key=L.ScopeKey(p.name,Z.me.realm,Z.me.faction)
    local value=SOURCE_PRIORITY[p.source]or 30
    if LN.group[id]then value=value+100 end
    if LN.IsGatewayRelation and LN.IsGatewayRelation(id)then value=value+90 end
    if key and Z.Social and Z.Social.IsGuildMember and Z.Social.IsGuildMember(key)then value=value+40 end
    return value
end
local function maintain(clock)
    local presence=Z.Network3.PresenceWire and Z.Network3.PresenceWire()
    local caps=LN.Capabilities()
    local list={}
    for id,p in pairs(LN.peers)do
        local r=route(id)
        if not r or r.session~=p.session then
            LN.peers[id]=nil;trace("route_lost",p.name)
            if LN.OnPeerLost then LN.OnPeerLost(id,p)end
        elseif p.hello then
            -- Capabilities changed (mesh up/down, gateway ready): tell the peer, at most every 30 s.
            if p.helloCaps~=caps and clock-(p.helloSentAt or -1000)>=LN.HELLO_GAP then sendHello(id,p)end
            if needsDirect(p)then list[#list+1]={id=id,p=p,score=score(id,p)}else p.maintained=false end
        end
    end
    table.sort(list,function(a,b)if a.score~=b.score then return a.score>b.score end;return a.id<b.id end)
    for i,row in ipairs(list)do
        local id,p=row.id,row.p
        p.maintained=i<=LN.MAX_DIRECT
        -- A peer that keeps talking to us gets heartbeats as well, so neither side's route runs out.
        local echo=p.rx and clock-p.rx<LN.HEARTBEAT
        if p.maintained or echo then
            if presence and p.presenceSig~=presence and clock-(p.presenceAt or -1000)>=LN.PRESENCE_GAP then
                if LN.Queue(id,"PR",presence,LN.PRIORITY_PRESENCE,"PR:"..id)then p.presenceSig=presence;p.presenceAt=clock;p.sentAt=clock;stat("presenceSent")end
            elseif clock-(p.sentAt or -1000)>=LN.HEARTBEAT then
                if queueValues(id,"PT",{Z.session},LN.PRIORITY_PRESENCE,"PT:"..id)then p.sentAt=clock;stat("heartbeats")end
            end
            if p.maintained and has(p.caps,LN.CAP_BUNDLE)and p.bundleRev~=Z.db.publicRev and clock-(p.bundleAt or -1000)>=LN.BUNDLE_GAP then
                local wire=Z.Network3.BundleWire and Z.Network3.BundleWire()
                if wire and LN.Queue(id,"BU",wire,LN.PRIORITY_BACKGROUND,"BU:"..id)then p.bundleRev=Z.db.publicRev;p.bundleAt=clock;stat("bundlesSent")end
            end
        end
    end
    local now=A.Now()
    for id,d in pairs(LN.direct)do if now-d.at>LN.TTL then LN.direct[id]=nil end end
    for key,s in pairs(LN.sources)do if now-(s.at or 0)>2*LN.TTL then LN.sources[key]=nil end end
    for id,row in pairs(LN.inbound)do if clock-row.at>=60 then LN.inbound[id]=nil end end
    for token,p in pairs(LN.assemblies)do if clock-p.at>LN.ASSEMBLY_TTL then LN.assemblies[token]=nil;LN.assemblyBytes=math.max(0,LN.assemblyBytes-p.size);stat("assemblyExpired")end end
end

-- ===== Lifecycle =====
function LN.RefreshGroup()
    local set={}
    for _,full in pairs(A.GroupMembers and A.GroupMembers()or{})do local id=L.Identity(full);if id then set[id]=true end end
    LN.group=set
end
function LN.Reset(reason)
    if not LN.stats then return end
    LN.peers,LN.direct,LN.out,LN.assemblies,LN.inbound,LN.probes,LN.candidates={},{},{},{},{},{},{}
    LN.outBytes,LN.outFrames,LN.assemblyBytes,LN.inFlight=0,0,0,0
    LN.tokens=4;LN.lastClock=A.Clock();LN.nextProbe=0;LN.probeWindow={};LN.maintainDue=0
    if LN.ResetGateway then LN.ResetGateway(reason)end
    -- A privacy change rebuilds the transport; peers confirmed in this session are tried again within the budget.
    if reason=="privacy"then
        local clock=A.Clock()
        for id,row in pairs(LN.known)do LN.candidates[id]={name=row.name,source="known",priority=SOURCE_PRIORITY.known,due=clock+math.random(2,15),at=clock}end
    else LN.known={}end
    trace("reset",reason or"")
end
function LN.Initialize()
    LN.stats={rejected=0,lastReject=""};LN.rejects={};LN.sources={};LN.applied={};LN.known={};LN.failed={}
    LN.serial=0;LN.order=0;LN.meshCount=0;LN.noMeshSince=A.Clock();LN.group={};LN.nextSecond=0
    LN.registered=false
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix)=="function"then
        local result=A.Call(C_ChatInfo.RegisterAddonMessagePrefix,LN.PREFIX);local e=Enum and Enum.RegisterAddonMessagePrefixResult
        LN.registered=result==true or e and(result==e.Success or result==e.DuplicatePrefix)or false
    end
    LN.Reset("initialize")
    LN.RefreshGroup()
end
function LN.Tick()
    if not LN.stats then return end
    if not LN.Enabled()then
        if#LN.out>0 or next(LN.peers)or next(LN.candidates)then LN.Reset("disabled")end
        return
    end
    local clock=A.Clock()
    if clock>=LN.nextSecond then
        LN.nextSecond=clock+1
        LN.meshCount=meshRoutes()
        if LN.meshCount>0 then LN.noMeshSince=nil else LN.noMeshSince=LN.noMeshSince or clock end
        probeTick(clock)
        maintain(clock)
        if LN.GatewayTick then LN.GatewayTick(clock)end
    end
    pump(clock)
end

-- ===== Status =====
-- Source of the current online state of one member: "direct", "gateway" (indirect), "mesh" or nil.
function LN.Source(key)
    local peer=key and Z.db and Z.db.peers[key];if not peer then return nil end
    local s=LN.sources and LN.sources[key]
    local direct=peer.lastContactClock and A.Clock()-peer.lastContactClock<LN.TTL
    local reported=peer.reportedClock and A.Clock()-peer.reportedClock<LN.TTL
    if direct then return"direct",{localRoute=s and s.via=="direct"or false,at=peer.lastContact}end
    if reported then
        if s and s.via=="gateway"then return"gateway",s end
        return"mesh",{at=peer.reportedAt}
    end
    return nil
end
function LN.Counts()
    local direct,indirect=0,0
    if not LN.sources then return 0,0 end
    for key,s in pairs(LN.sources)do
        local via=LN.Source(key)
        if via=="direct"and s.via=="direct"then direct=direct+1 elseif via=="gateway"then indirect=indirect+1 end
    end
    return direct,indirect
end
function LN.Status()
    local s=LN.stats or{}
    local direct,indirect=LN.Counts()
    local maintained=0;for _,p in pairs(LN.peers or{})do if p.maintained then maintained=maintained+1 end end
    local row={enabled=LN.Enabled(),registered=LN.registered==true,mesh=LN.MeshActive(),connected=LN.DirectCount and LN.peers and LN.DirectCount()or 0,maintained=maintained,
        directOnline=direct,indirectOnline=indirect,candidates=count(LN.candidates),probing=count(LN.probes),failed=count(LN.failed),known=count(LN.known),
        outMessages=#(LN.out or{}),outFrames=LN.outFrames or 0,outBytes=LN.outBytes or 0,inFlight=LN.inFlight or 0,assemblies=count(LN.assemblies),
        sentFrames=s.sentFrames or 0,sentBytes=s.sentBytes or 0,receivedFrames=s.receivedFrames or 0,receivedBytes=s.receivedBytes or 0,
        probes=s.probes or 0,probeFailures=s.probeFailures or 0,throttled=s.throttled or 0,deferred=s.deferred or 0,dropped=s.dropped or 0,
        rejected=s.rejected or 0,lastReject=s.lastReject or"",duplicates=s.duplicates or 0,meshCovered=s.meshCovered or 0}
    if LN.GatewayStatus then for k,v in pairs(LN.GatewayStatus())do row[k]=v end end
    return row
end
return LN
