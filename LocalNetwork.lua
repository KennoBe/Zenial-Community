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
-- Gateway messages count for the gateway role, everything else for the kind of contact (group, guild, other).
local CLIENT_SENDS={GQ=true,GL=true,GX=true,GE=true}
local SERVER_SENDS={GP=true,GD=true,GB=true}
local function contactKind(id)
    if LN.group and LN.group[id]then return"group"end
    local p=LN.peers and LN.peers[id];local name=p and p.name or id
    local key=Z.me and L.ScopeKey(name,Z.me.realm,Z.me.faction)
    if key and Z.Social and Z.Social.IsGuildMember and Z.Social.IsGuildMember(key)then return"guild"end
    return"other"
end
LN.ContactKind=contactKind
local function activity(id,kind,direction)
    local category
    if CLIENT_SENDS[kind]then category=direction=="tx"and"gateway"or"serve"
    elseif SERVER_SENDS[kind]then category=direction=="tx"and"serve"or"gateway"
    else category=contactKind(id)end
    LN.activity=LN.activity or{};local row=LN.activity[category]or{};LN.activity[category]=row
    row[direction]=A.Now()
end
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
    return Z.db and Z.db.consent and Z.db.autoDiscovery and Z.identityReady and not Z.offlineOnly
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
                if result=="ok"then stat("sentFrames");stat("sentBytes",#frame);activity(m.id,m.kind,"tx")
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
    -- Field 7 asks for an answer while we hold no hello of the peer (first contact or our own reset).
    if queueValues(id,"HI",{tostring(LN.PROTO),LN.Capabilities(),Z.session,LN.MeshActive()and 1 or 0,load,size,p.hello and 0 or 1},LN.PRIORITY_PRESENCE,"HI:"..id)then
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
    LN.candidates[bestID]=nil
    local blockedKey=L.ScopeKey(best.name,Z.me.realm,Z.me.faction)
    if blockedKey and Z.db.blocked[blockedKey]then trace("probe_blocked",best.name);return end
    LN.nextProbe=clock+LN.HANDSHAKE_GAP
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
    if result then activity(id,kind,"rx")end
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
    -- A peer that asks for an answer has lost its local state (reset) and needs our hello and data again.
    local restarted=f[7]=="1"and not first
    p.hello=A.Clock();p.caps=caps;p.mesh=mesh==1;p.load=load;p.size=size;p.rx=A.Clock()
    -- An answer request is always answered (the answer carries 0, so there is no ping-pong).
    if p.helloSent~=r.session or restarted or f[7]=="1"then sendHello(id,p)end
    if first or restarted then p.presenceSig,p.presenceAt,p.bundleRev,p.bundleAt=nil,nil,nil,nil end
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
    local key=Z.ResolvePeerKey(r.name);local before=key and LN.sources[key]
    local ok,changed=N.ProcessComplete(r.name,"PUBLIC","P",wire)
    if not ok then return reject("presence",r.name)end
    key=key or Z.ResolvePeerKey(r.name)
    LN.direct[id]={wire=wire,session=r.session,at=A.Now(),name=r.name}
    if key then LN.sources[key]={via="direct",at=A.Now()}end
    stat("presenceReceived")
    if(changed~=false or not(before and before.via=="direct"))and Z.MarkDirty then Z.MarkDirty("P")end
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
    -- The presence wire reads location APIs; build it at most every 5 s.
    local visible=Z.db.visible==true
    if not LN.presenceAt or clock-LN.presenceAt>=5 or clock<LN.presenceAt or LN.presenceVisible~=visible then
        LN.presenceAt=clock;LN.presenceVisible=visible;LN.presence=Z.Network3.PresenceWire and Z.Network3.PresenceWire()
    end
    local presence=LN.presence
    local caps=LN.Capabilities()
    local list={}
    for id,p in pairs(LN.peers)do
        local r=route(id)
        if not r or r.session~=p.session then
            LN.peers[id]=nil;trace("route_lost",p.name)
            if LN.OnPeerLost then LN.OnPeerLost(id,p)end
        elseif not p.hello then
            -- No hello from the peer yet: ours may have been lost. Ask again a few times.
            if(p.helloTries or 0)<3 and clock-(p.helloSentAt or -1000)>=LN.HELLO_GAP then p.helloTries=(p.helloTries or 0)+1;sendHello(id,p)end
        else
            -- Capabilities changed (mesh up/down, gateway ready): tell the peer, at most every 30 s.
            if p.helloCaps~=caps and clock-(p.helloSentAt or -1000)>=LN.HELLO_GAP then sendHello(id,p)end
            if needsDirect(p)then list[#list+1]={id=id,p=p,score=score(id,p)}else p.maintained=false end
        end
    end
    table.sort(list,function(a,b)if a.score~=b.score then return a.score>b.score end;return a.id<b.id end)
    local bundle
    for i,row in ipairs(list)do
        local id,p=row.id,row.p
        p.maintained=i<=LN.MAX_DIRECT
        -- A peer that keeps talking to us gets heartbeats as well, so neither side's route runs out.
        local echo=p.rx and clock-p.rx<LN.HEARTBEAT
        if p.maintained or echo then
            -- A visibility change is a privacy decision and skips the minimum gap; peers beyond the
            -- maintained ones only get heartbeats, except for that privacy update.
            local changedVisibility=p.presenceSig and p.presenceVisible~=visible
            if presence and p.presenceSig~=presence and(p.maintained and clock-(p.presenceAt or -1000)>=LN.PRESENCE_GAP or changedVisibility)then
                if LN.Queue(id,"PR",presence,LN.PRIORITY_PRESENCE,"PR:"..id)then p.presenceSig=presence;p.presenceAt=clock;p.presenceVisible=visible;p.sentAt=clock;stat("presenceSent")end
            elseif clock-(p.sentAt or -1000)>=LN.HEARTBEAT then
                if queueValues(id,"PT",{Z.session},LN.PRIORITY_PRESENCE,"PT:"..id)then p.sentAt=clock;stat("heartbeats")end
            end
            if p.maintained and has(p.caps,LN.CAP_BUNDLE)and p.bundleRev~=Z.db.publicRev and clock-(p.bundleAt or -1000)>=LN.BUNDLE_GAP then
                if bundle==nil then bundle=Z.Network3.BundleWire and Z.Network3.BundleWire()or false end
                local wire=bundle
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
    LN.tokens=4;LN.lastClock=A.Clock();LN.nextProbe=0;LN.probeWindow={};LN.presenceAt=nil
    if LN.ResetGateway then LN.ResetGateway(reason)end
    -- A privacy change rebuilds the transport; peers confirmed in this session are tried again within the budget.
    if reason=="privacy"then
        local clock=A.Clock()
        for id,row in pairs(LN.known)do
            local key=L.ScopeKey(row.name,Z.me.realm,Z.me.faction)
            if not(key and Z.db.blocked[key])then LN.candidates[id]={name=row.name,source="known",priority=SOURCE_PRIORITY.known,due=clock+math.random(2,15),at=clock}end
        end
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
        -- A fault in the optional local network must never stop the modules ticking after it.
        local ok,err=pcall(function()probeTick(clock);maintain(clock);if LN.GatewayTick then LN.GatewayTick(clock)end end)
        if not ok then stat("tickErrors");trace("tick_error",err)end
    end
    local ok,err=pcall(pump,clock)
    if not ok then stat("tickErrors");trace("pump_error",err)end
end

-- ===== Presence gateway (level C) and limited relay =====
-- A gateway passes valid public presence it already holds (Battle.net mesh, own direct peers, or as relay its
-- first-hop gateway entries) to at most two players without mesh. Everything is pulled page by page or as a delta,
-- so a gateway never queues more than one answer per client. Entries keep their original time; hop 2 is final.
local GW={MAX_CLIENTS=2,MAX_ENTRIES=150,PAGE=8,POLL=60,POLL_JITTER=10,MORE=3,PAGE_TIMEOUT=20,DELTA_TIMEOUT=30,ATTEMPTS=3,
    COOLDOWN=600,CLIENT_IDLE=240,MAX_HOP=2,DELTA_BYTES=1400,DELTA_ITEMS=76,MAX_NEED=32,EXCLUDE_GAP=30,MAX_EXCLUDE=64,
    SWITCH_GAP=300,MAX_IDS=2000,MAX_CLIENT_ENTRIES=300,OTHER_SYNC=4,OTHER_WINDOW=600,NEW_CONTACTS=200}
LN.GW=GW
local SEP="~"
local AVAILABILITY={AVAILABLE=true,AFK=true,BUSY=true,GROUP=true}
local function clean(value)return type(value)=="string"and not value:find(SEP,1,true)end
local function validSession(session)
    if not L.Text(session,32)or not session:match("^%d+%.%d+%.%d+$")then return false end
    local epoch=tonumber(session:match("^(%d+)%."));return L.Int(epoch,1,4102444800)and epoch<=A.Now()+120
end
-- The same field rules as a mesh presence record (CommunityMesh validate, kind P).
local function validPresence(f)
    local D=Z.CommunityDirectory
    if not f or#f~=17 or f[1]~="P"or f[2]~="3"or f[5]~=Z.me.faction or not D or D.World(f[4])~=D.OwnWorld()then return false end
    if not L.Text(f[6],16,true)or not L.Text(f[8],16,true)or not AVAILABILITY[f[9]]or not L.Text(f[10],48,true)
        or f[10]~=""and not f[10]:match("^[%d,]+$")or(f[16]~="all"and f[16]~="zone")then return false end
    for _,i in ipairs({7,11,12,13,14,15,17})do
        local max=i==7 and 100 or i==15 and 1 or(i==14 or i==17)and 1000000 or 2147483646
        if not L.Int(tonumber(f[i]),0,max)then return false end
    end
    return true
end
local function newerVersion(a,b)
    if not b then return true end
    if a.session==b.session then return a.at>b.at end
    local x,y=tonumber(a.session:match("^(%d+)%.")),tonumber(b.session:match("^(%d+)%."))
    if x and y and x~=y then return x>y end
    return a.at>b.at
end
local function fieldsOf(wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=17 or f[1]~="P"or f[2]~="3"then return nil end
    local values={};for i=6,17 do values[#values+1]=f[i]end;return f,values
end
-- Hidden profiles (visible=false) publish an empty class and level 0; a gateway never passes them on.
local function hidden(values)return values[1]==""and tonumber(values[2])==0 end
local function buildOffer(requester,keep)
    local offer={};local now=A.Now();local own=me()
    local function add(origin,session,at,realm,hop,values)
        local id=L.Identity(origin)
        if not id or id==requester or id==own or hop>GW.MAX_HOP or not L.Int(at,1,4102444800)or now-at>LN.TTL or at>now+120 then return end
        local key=L.ScopeKey(origin,Z.me.realm,Z.me.faction);if not key or Z.db.blocked[key]or hidden(values)then return end
        if not clean(origin)or not clean(session)or not clean(realm)then return end
        for i=1,12 do if not clean(values[i])then return end end
        local old=offer[id];if old and(old.at>at or old.at==at and old.hop<=hop)then return end
        offer[id]={id=id,origin=origin,session=session,at=at,realm=realm,hop=hop,values=values,sig=session..SEP..table.concat(values,SEP)}
    end
    local M=Z.CommunityMesh
    if LN.MeshActive()and M and M.records then
        for _,row in pairs(M.records)do if row.kind=="P"then
            local f,values=fieldsOf(row.wire);if f and f[3]==row.session then add(row.origin,row.session,row.at,row.realm,1,values)end
        end end
    end
    for id,d in pairs(LN.direct)do
        local r=route(id);local f,values=fieldsOf(d.wire)
        if f and r and r.session==d.session then add(d.name,d.session,d.at,f[4],1,values)end
    end
    local gw=LN.gw
    if not LN.MeshActive()and gw and gw.synced then
        for _,e in pairs(gw.entries)do if e.hop<GW.MAX_HOP then add(e.origin,e.session,e.at,e.realm,e.hop+1,e.values)end end
    end
    -- Above the bound, entries a client already holds stay first so the selection does not churn.
    local valid={};local list={};for id,rec in pairs(offer)do valid[id]=true;list[#list+1]=rec end
    table.sort(list,function(a,b)
        local x,y=keep and keep[a.id]and 1 or 0,keep and keep[b.id]and 1 or 0
        if x~=y then return x>y end;if a.at~=b.at then return a.at>b.at end;return a.id<b.id end)
    for i=#list,GW.MAX_ENTRIES+1,-1 do offer[list[i].id]=nil;list[i]=nil end
    LN.offerSize=#list
    return offer,list,valid
end
LN.BuildOffer=buildOffer
function LN.OfferSize()return LN.offerSize or 0 end
function LN.CanServe()
    if not LN.Enabled()then return false end
    if LN.MeshActive()then return true end
    local gw=LN.gw;return gw and gw.synced and next(gw.entries)~=nil or false
end
function LN.IsGatewayRelation(id)return LN.gw and LN.gw.primary==id or LN.serve and LN.serve.clients[id]~=nil or false end
local function encodeEntry(n,rec)
    local realm=rec.realm==Z.CommunityDirectory.WorldToken()and"="or rec.realm
    return table.concat({n,rec.origin,rec.session,rec.at,realm,rec.hop,table.concat(rec.values,SEP)},SEP)
end
local function split(text)
    local out={};local start=1
    while true do
        local i=text:find(SEP,start,true)
        if not i then out[#out+1]=text:sub(start);break end
        out[#out+1]=text:sub(start,i-1);start=i+1
        if#out>40 then return nil end
    end
    return out
end
-- Rebuilds and checks the original presence wire. The gateway's route is verified; the third player's claim is not.
local function decodeEntry(text,r,offset)
    local parts=type(text)=="string"and#text<=600 and split(text);offset=offset or 0
    if not parts or#parts~=18+offset then return nil end
    local n,origin,session,at,realm,hop=tonumber(parts[1+offset]),parts[2+offset],parts[3+offset],tonumber(parts[4+offset]),parts[5+offset],tonumber(parts[6+offset])
    if realm=="="then realm=r.realm end
    local id,full=L.Identity(origin)
    if not L.Int(n,1,100000)or not id or type(full)~="string"or not full:find(" ",1,true)or not validSession(session)or not L.Int(at,1,4102444800)
        or not L.Text(realm,64)or not L.Int(hop,1,GW.MAX_HOP)then return nil end
    local values={};for i=7+offset,18+offset do values[#values+1]=parts[i]end
    local wireValues={"P","3",session,realm,Z.me.faction};for _,v in ipairs(values)do wireValues[#wireValues+1]=v end
    local wire=Z.Network3.Pack(wireValues)
    if#wire>238 or not validPresence(Z.Network3.Unpack(wire))then return nil end
    return{n=n,origin=full,id=id,session=session,at=at,realm=realm,hop=hop,values=values,wire=wire}
end
local function scopeKey(origin)return L.ScopeKey(origin,Z.me.realm,Z.me.faction)end
local function applyRelayed(e,gw)
    local key=scopeKey(e.origin)
    if not key or key==Z.me.key or Z.db.blocked[key]then return reject("relay_identity",e.origin)end
    local now=A.Now()
    if now-e.at>LN.TTL or e.at>now+120 then stat("stale");return false end
    -- A direct local connection outranks every relayed statement about the same player.
    local d=LN.direct[e.id];if d and route(e.id)and now-d.at<LN.TTL then stat("directPreferred");return false end
    local applied=LN.applied[e.id]
    if applied and not newerVersion(e,applied)then stat("duplicates");return false end
    local peer=Z.db.peers[key];local source=LN.sources[key];local N=Z.Network3
    if peer and peer.reportedAt and peer.reportedAt>=e.at and not(source and source.via=="gateway")and N.IsOnline(key)then stat("stale");return false end
    local wasOnline=Z.IsOnline and Z.IsOnline(key)
    -- New names from one gateway are bounded: relayed statements must not flood the contact list.
    if not Z.db.contacts[key]then
        if(gw.newContacts or 0)>=GW.NEW_CONTACTS then stat("newContactLimit");return false end
        gw.newContacts=(gw.newContacts or 0)+1
    end
    N.meshContext={at=e.at,origin=e.origin,session=e.session,seq=0}
    local called,ok,changed=pcall(N.ProcessComplete,e.origin,"PUBLIC","P",e.wire)
    N.meshContext=nil
    if not called then trace("relay_error",ok);ok=false end
    if not ok then return reject("relay_presence",e.origin)end
    LN.applied[e.id]={session=e.session,at=e.at}
    LN.sources[key]={via="gateway",gateway=gw.primary,gatewayName=gw.name,hop=e.hop,at=e.at}
    stat("relayed")
    if(changed~=false or not wasOnline)and Z.MarkDirty then Z.MarkDirty("P")end
    return true
end
LN.ApplyRelayed=applyRelayed
local function dropEntry(gw,n)
    local e=gw.entries[n];if not e then return end
    gw.entries[n]=nil;if gw.byOrigin[e.id]==n then gw.byOrigin[e.id]=nil end
    local key=scopeKey(e.origin);local s=key and LN.sources[key]
    -- Only the gateway that reported a state can withdraw it.
    if s and s.via=="gateway"and s.gateway==gw.primary then
        local peer=Z.db.peers[key];if peer then peer.reportedAt,peer.reportedClock=nil,nil end
        LN.sources[key]=nil;LN.applied[e.id]=nil
        if Z.MarkDirty then Z.MarkDirty("offline")end
    end
end
-- Self-sync: try to reach relevant reported players directly; never the whole list.
local function selfSync(e)
    if LN.direct[e.id]or route(e.id)or LN.failed[e.id]then return end
    local key=scopeKey(e.origin);local peer=key and Z.db.peers[key]
    local source
    if LN.group[e.id]then source="gateway_group"
    elseif key and Z.Social and Z.Social.IsGuildMember and Z.Social.IsGuildMember(key)then source="gateway_guild"
    elseif peer and peer.lastContact then source="gateway_contact"
    else
        if(LN.otherSync or 0)<=0 then return end
        LN.otherSync=LN.otherSync-1;source="gateway"
    end
    LN.Candidate(e.origin,source)
end
local function storeEntry(gw,e)
    local old=gw.entries[e.n]
    if old and old.id~=e.id then return reject("entry_conflict",e.origin)end
    local previous=gw.byOrigin[e.id];if previous and previous~=e.n then dropEntry(gw,previous)end
    if not old and count(gw.entries)>=GW.MAX_CLIENT_ENTRIES then return reject("entry_limit")end
    gw.entries[e.n]=e;gw.byOrigin[e.id]=e.n
    applyRelayed(e,gw)
    if not old then selfSync(e)end
    return true
end
local function poll()return GW.POLL+math.random(-GW.POLL_JITTER,GW.POLL_JITTER)end
local function gwCooldown(id,clock)local untilAt=LN.gwCooldown[id];return untilAt and clock<untilAt end
local function gatewayCandidates(clock)
    local list={}
    for id,p in pairs(LN.peers)do
        if p.hello and has(p.caps,LN.CAP_GATEWAY)and route(id)and not gwCooldown(id,clock)and not LN.serve.clients[id]then
            local key=scopeKey(p.name)
            local value=(has(p.caps,LN.CAP_MESH)and 1000 or 0)+(LN.group[id]and 50 or 0)
                +(key and Z.Social and Z.Social.IsGuildMember and Z.Social.IsGuildMember(key)and 30 or 0)
                -math.min(2,p.load or 0)*20+math.min(60,math.floor((clock-(p.since or clock))/60))
            list[#list+1]={id=id,p=p,score=value}
        end
    end
    table.sort(list,function(a,b)if a.score~=b.score then return a.score>b.score end;return a.id<b.id end)
    return list
end
local function needGateway(clock)
    if not LN.Enabled()or LN.MeshActive()or not LN.noMeshSince then return false end
    -- Members of a lounge first get the chance to build their mesh routes.
    local D=Z.CommunityDirectory;local joined=D and D.Status and D.Status().joined or 0
    return clock-LN.noMeshSince>=((joined or 0)>0 and LN.MESH_GRACE or 5)
end
local function startGateway(clock,choice)
    LN.gw={primary=choice.id,name=choice.p.name,mesh=has(choice.p.caps,LN.CAP_MESH),epoch="",page=1,pages=1,state="snapshot",requestAt=clock,attempts=1,
        ackSeq=0,entries={},byOrigin={},need={},startedAt=clock,restarts=0}
    queueValues(choice.id,"GQ",{"",1},LN.PRIORITY_GATEWAY,"GQ:"..choice.id)
    stat("gatewayStarts");trace("gateway_start",choice.p.name,LN.gw.mesh and"mesh"or"relay")
end
-- Reported states stay until their own time runs out; a failed gateway is only avoided for a while.
local function failGateway(reason,cooldown)
    local gw=LN.gw;if not gw then return end
    if cooldown then LN.gwCooldown[gw.primary]=A.Clock()+GW.COOLDOWN end
    LN.gw=nil;LN.lastGateway={name=gw.name,reason=reason,at=A.Clock()}
    stat("gatewayFailures");trace("gateway_failed",gw.name,reason)
end
local function releaseGateway(reason)
    local gw=LN.gw;if not gw then return end
    queueValues(gw.primary,"GE",{gw.epoch},LN.PRIORITY_GATEWAY,"GE:"..gw.primary)
    LN.gw=nil;trace("gateway_release",gw.name,reason)
end
local function sendPoll(gw)
    local need={};for n in pairs(gw.need)do if#need<GW.MAX_NEED then need[#need+1]=n end end;table.sort(need);gw.need={}
    return queueValues(gw.primary,"GL",{gw.epoch,gw.ackSeq,table.concat(need,",")},LN.PRIORITY_GATEWAY,"GL:"..gw.primary)
end
function LN.OnPeerLost(id)
    if LN.gw and LN.gw.primary==id then failGateway("route",false)end
    if LN.serve then LN.serve.clients[id]=nil end
end
function LN.ResetGateway()
    LN.gw=nil;LN.serve={clients={},built={}};LN.gwCooldown={};LN.otherSync=GW.OTHER_SYNC;LN.otherSyncAt=A.Clock();LN.backupName=""
end
function LN.GatewayTick(clock)
    local now=A.Now()
    for id,c in pairs(LN.serve.clients)do
        if not route(id)or clock-c.lastSeen>GW.CLIENT_IDLE or not LN.CanServe()then LN.serve.clients[id]=nil;trace("serve_end",c.name)end
    end
    for id,untilAt in pairs(LN.gwCooldown)do if clock>=untilAt then LN.gwCooldown[id]=nil end end
    for id,a in pairs(LN.applied)do if now-a.at>2*LN.TTL then LN.applied[id]=nil end end
    if clock-(LN.otherSyncAt or 0)>=GW.OTHER_WINDOW then LN.otherSync=GW.OTHER_SYNC;LN.otherSyncAt=clock end
    if not needGateway(clock)then
        if LN.gw then releaseGateway(LN.MeshActive()and"mesh"or"disabled")end
        LN.backupName="";return
    end
    local gw=LN.gw
    if gw and clock-(gw.newContactsAt or 0)>=GW.OTHER_WINDOW then gw.newContacts=0;gw.newContactsAt=clock end
    if gw and not route(gw.primary)then failGateway("route",false);gw=nil end
    local list=gatewayCandidates(clock)
    if not gw then
        LN.backupName=list[2]and list[2].p.name or""
        if list[1]then startGateway(clock,list[1])end
        return
    end
    LN.backupName="";for _,row in ipairs(list)do if row.id~=gw.primary then LN.backupName=row.p.name;break end end
    -- A relay gateway gives way to a mesh gateway, at most once per SWITCH_GAP.
    local best=list[1]
    if not gw.mesh and best and best.id~=gw.primary and has(best.p.caps,LN.CAP_MESH)and clock-gw.startedAt>=GW.SWITCH_GAP then
        releaseGateway("better_gateway");startGateway(clock,best);return
    end
    if gw.state=="snapshot"then
        if clock-gw.requestAt>GW.PAGE_TIMEOUT then
            if gw.attempts>=GW.ATTEMPTS then failGateway("snapshot_timeout",true)
            else gw.attempts=gw.attempts+1;gw.requestAt=clock;queueValues(gw.primary,"GQ",{gw.epoch,gw.page},LN.PRIORITY_GATEWAY,"GQ:"..gw.primary)end
        end
    elseif gw.state=="polling"then
        if clock-gw.requestAt>GW.DELTA_TIMEOUT then
            if gw.attempts>=GW.ATTEMPTS then failGateway("delta_timeout",true)
            else gw.attempts=gw.attempts+1;gw.requestAt=clock;sendPoll(gw)end
        end
    elseif gw.state=="synced"and clock>=gw.pollAt then
        gw.state="polling";gw.requestAt=clock;gw.attempts=1;sendPoll(gw)
    end
    -- Players reached directly need no gateway updates any more.
    if gw.synced then
        local ids={}
        for n,e in pairs(gw.entries)do local d=LN.direct[e.id];if d and route(e.id)and#ids<GW.MAX_EXCLUDE then ids[#ids+1]=n end end
        table.sort(ids);local signature=table.concat(ids,",")
        if signature~=(gw.excludeSig or"")and clock-(gw.excludeAt or -1000)>=GW.EXCLUDE_GAP then
            if queueValues(gw.primary,"GX",{gw.epoch,signature},LN.PRIORITY_GATEWAY,"GX:"..gw.primary)then gw.excludeSig=signature;gw.excludeAt=clock end
        end
    end
end
-- Server side
local function refuse(id,reason)stat("gatewayRefused");return queueValues(id,"GB",{reason},LN.PRIORITY_GATEWAY,"GB:"..id)end
local function newEpoch()LN.order=LN.order+1;return tostring(A.Now()).."."..tostring(LN.order%100000)end
local function sendPage(id,c,page)
    local values={c.epoch,page,c.pages};local first=(page-1)*GW.PAGE+1
    for i=first,math.min(#c.list,first+GW.PAGE-1)do
        local rec=c.list[i];values[#values+1]=encodeEntry(c.ids[rec.id],rec)
        c.acked[rec.id]={session=rec.session,at=rec.at,sig=rec.sig}
    end
    stat("pagesServed")
    return queueValues(id,"GP",values,LN.PRIORITY_GATEWAY,"GP:"..id)
end
function H.GQ(id,wire,r)
    local f=Z.Network3.Unpack(wire);if not f or#f<2 then return reject("gateway_request",r.name)end
    local epoch,page=f[1],tonumber(f[2])
    if not L.Text(epoch,32,true)or not L.Int(page,1,100)then return reject("gateway_request",r.name)end
    if not LN.CanServe()then return refuse(id,"unavailable")end
    -- Our own gateway cannot become our client: no gateway loops.
    if LN.gw and LN.gw.primary==id then return refuse(id,"loop")end
    local c=LN.serve.clients[id]
    if epoch==""or not c or c.epoch~=epoch or c.session~=r.session then
        if page~=1 then return refuse(id,"epoch")end
        -- A new snapshot reads the whole mesh store: at most one every 10 s per requester.
        local last=LN.serve.built[id];if last and A.Clock()-last<10 then stat("rateLimited");return false end
        LN.serve.built[id]=A.Clock()
        if not c and count(LN.serve.clients)>=GW.MAX_CLIENTS then return refuse(id,"busy")end
        local _,list=buildOffer(id)
        c={name=r.name,session=r.session,epoch=newEpoch(),list=list,pages=math.max(1,math.ceil(#list/GW.PAGE)),ids={},byId={},nextId=0,acked={},dseq=0,exclude={},lastSeen=A.Clock()}
        for _,rec in ipairs(list)do c.nextId=c.nextId+1;c.ids[rec.id]=c.nextId;c.byId[c.nextId]=rec.id end
        LN.serve.clients[id]=c;stat("snapshotsServed");trace("serve_snapshot",r.name,#list)
    end
    if page>c.pages then return refuse(id,"epoch")end
    c.lastSeen=A.Clock()
    return sendPage(id,c,page)
end
function H.GL(id,wire,r)
    local f=Z.Network3.Unpack(wire);if not f or#f<3 then return reject("gateway_poll",r.name)end
    local c=LN.serve.clients[id]
    if not c or c.epoch~=f[1]or c.session~=r.session then return refuse(id,"epoch")end
    if not LN.CanServe()then LN.serve.clients[id]=nil;return refuse(id,"unavailable")end
    if c.polledAt and A.Clock()-c.polledAt<2 then stat("rateLimited");return false end
    c.polledAt=A.Clock()
    local ack=tonumber(f[2]);if not L.Int(ack,0,2147483646)or not L.Text(f[3],400,true)then return reject("gateway_poll",r.name)end
    c.lastSeen=A.Clock()
    -- The previous delta counts as delivered only once the client confirms it; otherwise it is recomputed.
    if c.pending and ack==c.dseq then for origin,v in pairs(c.pending)do c.acked[origin]=v or nil end end
    c.pending=nil
    local need={};for n in f[3]:gmatch("%d+")do n=tonumber(n);if c.byId[n]then need[n]=true end end
    local offer,_,valid=buildOffer(id,c.acked)
    local items,size,pending,more={},0,{},false
    local function push(item,origin,version)
        if size+#item+1>GW.DELTA_BYTES or#items>=GW.DELTA_ITEMS then more=true;return false end
        items[#items+1]=item;size=size+#item+1;pending[origin]=version;return true
    end
    -- Only a state that became invalid is withdrawn, never one cut by the size bound.
    for origin in pairs(c.acked)do if not valid[origin]and c.ids[origin]then if not push("X"..SEP..c.ids[origin],origin,false)then break end end end
    if not more then
        local list={};for _,rec in pairs(offer)do list[#list+1]=rec end
        table.sort(list,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.id<b.id end)
        for _,rec in ipairs(list)do
            local n=c.ids[rec.id]
            if not n then
                if c.nextId>=GW.MAX_IDS then LN.serve.clients[id]=nil;return refuse(id,"epoch")end
                c.nextId=c.nextId+1;n=c.nextId;c.ids[rec.id]=n;c.byId[n]=rec.id
            end
            if not c.exclude[n]or need[n]then
                local old=c.acked[rec.id];local version={session=rec.session,at=rec.at,sig=rec.sig}
                local ok=true
                if need[n]or not old or old.sig~=rec.sig then ok=push("U"..SEP..encodeEntry(n,rec),rec.id,version)
                elseif rec.at>old.at then ok=push("T"..SEP..n..SEP..rec.at,rec.id,version)end
                if not ok then break end
            end
        end
    end
    c.dseq=c.dseq+1;c.pending=pending
    local values={c.epoch,c.dseq,more and 1 or 0};for _,item in ipairs(items)do values[#values+1]=item end
    stat("deltasServed")
    return queueValues(id,"GD",values,LN.PRIORITY_GATEWAY,"GD:"..id)
end
function H.GX(id,wire,r)
    local f=Z.Network3.Unpack(wire);local c=LN.serve.clients[id]
    if not f or#f<2 or not c or c.epoch~=f[1]or not L.Text(f[2],600,true)then return reject("gateway_exclude",r.name)end
    local exclude,n={},0
    for value in f[2]:gmatch("%d+")do value=tonumber(value);if c.byId[value]and n<GW.MAX_EXCLUDE then exclude[value]=true;n=n+1 end end
    c.exclude=exclude;c.lastSeen=A.Clock();return true
end
function H.GE(id,wire)
    local f=Z.Network3.Unpack(wire);local c=LN.serve.clients[id]
    if f and c and c.epoch==f[1]then LN.serve.clients[id]=nil;trace("serve_end",c.name,"released")end
    return true
end
-- Client side
local function fromGateway(id,r)
    local gw=LN.gw;if not gw or gw.primary~=id or not route(id)or route(id).session~=r.session then return nil end
    return gw
end
function H.GP(id,wire,r)
    local gw=fromGateway(id,r);if not gw or gw.state~="snapshot"then return reject("not_gateway",r.name)end
    local f=Z.Network3.Unpack(wire);if not f or#f<3 then return reject("gateway_page",r.name)end
    local epoch,page,pages=f[1],tonumber(f[2]),tonumber(f[3])
    if not L.Text(epoch,32)or not L.Int(pages,1,100)or page~=gw.page or#f-3>GW.PAGE then return reject("gateway_page",r.name)end
    if gw.epoch==""then gw.epoch=epoch elseif gw.epoch~=epoch then return reject("gateway_epoch",r.name)end
    gw.pages=pages
    for i=4,#f do local e=decodeEntry(f[i],r);if e then storeEntry(gw,e)else reject("gateway_entry",r.name)end end
    stat("pages")
    local clock=A.Clock()
    if page<pages then
        gw.page=page+1;gw.requestAt=clock;gw.attempts=1
        queueValues(id,"GQ",{gw.epoch,gw.page},LN.PRIORITY_GATEWAY,"GQ:"..id)
    else
        gw.state="synced";gw.synced=true;gw.lastSync=A.Now();gw.pollAt=clock+poll();gw.attempts=0;gw.restarts=0
        stat("snapshots");trace("gateway_snapshot",gw.name,count(gw.entries))
    end
    return true
end
function H.GD(id,wire,r)
    local gw=fromGateway(id,r);if not gw or not gw.synced then return reject("not_gateway",r.name)end
    local f=Z.Network3.Unpack(wire);if not f or#f<3 then return reject("gateway_delta",r.name)end
    local dseq,more=tonumber(f[2]),tonumber(f[3])
    if f[1]~=gw.epoch or not L.Int(dseq,1,2147483646)or not L.Int(more,0,1)or#f-3>GW.DELTA_ITEMS then return reject("gateway_delta",r.name)end
    if dseq<=gw.ackSeq then stat("duplicates");return true end
    for i=4,#f do
        local item=f[i];local kind=item:sub(1,2)
        if kind=="U"..SEP then
            local e=decodeEntry(item,r,1)
            if e then storeEntry(gw,e)else reject("gateway_entry",r.name)end
        elseif kind=="T"..SEP then
            local n,at=item:match("^T~(%d+)~(%d+)$");n,at=tonumber(n),tonumber(at)
            local e=n and gw.entries[n]
            if not e then if n and count(gw.need)<GW.MAX_NEED then gw.need[n]=true end
            elseif L.Int(at,1,4102444800)and at>e.at then
                local touched={n=e.n,origin=e.origin,id=e.id,session=e.session,at=at,realm=e.realm,hop=e.hop,values=e.values,wire=e.wire}
                gw.entries[n]=touched;applyRelayed(touched,gw)
            end
        elseif kind=="X"..SEP then
            local n=tonumber(item:match("^X~(%d+)$"));if n then dropEntry(gw,n)end
        else reject("gateway_item",r.name)end
    end
    gw.ackSeq=dseq;gw.lastSync=A.Now();gw.attempts=0;gw.state="synced"
    gw.pollAt=A.Clock()+(more==1 and GW.MORE or poll())
    stat("deltas")
    return true
end
function H.GB(id,wire,r)
    local gw=fromGateway(id,r);if not gw then return reject("not_gateway",r.name)end
    local f=Z.Network3.Unpack(wire);local reason=f and f[1]or""
    if reason=="epoch"and gw.restarts<2 then
        local restarts=gw.restarts+1
        startGateway(A.Clock(),{id=id,p=LN.peers[id]or{name=gw.name,caps=gw.mesh and LN.CAP_MESH or 0}});LN.gw.restarts=restarts
    else failGateway(L.Text(reason,16)and reason or"refused",true)end
    return true
end
function LN.GatewayStatus()
    local gw=LN.gw;local s=LN.stats or{}
    return{gateway=gw and gw.name or"",gatewayState=gw and gw.state or"idle",backup=LN.backupName or"",gatewayEntries=gw and count(gw.entries)or 0,
        lastSyncAge=gw and gw.lastSync and math.max(0,A.Now()-gw.lastSync)or -1,serving=LN.serve and count(LN.serve.clients)or 0,offer=LN.offerSize or 0,
        snapshots=s.snapshots or 0,deltas=s.deltas or 0,relayed=s.relayed or 0,directPreferred=s.directPreferred or 0,stale=s.stale or 0,
        gatewayStarts=s.gatewayStarts or 0,gatewayFailures=s.gatewayFailures or 0,snapshotsServed=s.snapshotsServed or 0,deltasServed=s.deltasServed or 0,
        lastGatewayIssue=LN.lastGateway and(LN.lastGateway.name..": "..LN.lastGateway.reason)or""}
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
-- Plain state of every connection kind for the connection overview: online players whose current
-- state comes through that kind, and when something was last received and sent there.
function LN.ConnectionData()
    local data={lounge={online=0},group={online=0},guild={online=0},other={online=0},gateway={online=0},serve={online=0}}
    local act=LN.activity or{}
    for name,row in pairs(data)do local a=act[name];if a then row.rx,row.tx=a.rx,a.tx end end
    data.lounge.rx,data.lounge.tx=transport()and transport().lastBnetRx,transport()and transport().lastBnetTx
    if Z.db and LN.sources then
        for key in pairs(Z.db.contacts)do
            local via,detail=LN.Source(key)
            if via=="mesh"or via=="direct"and not(detail and detail.localRoute)then data.lounge.online=data.lounge.online+1
            elseif via=="gateway"then data.gateway.online=data.gateway.online+1
            elseif via=="direct"then
                local c=Z.db.contacts[key];local id=c and L.Identity(c.target)
                local kind=id and contactKind(id)or"other";data[kind].online=data[kind].online+1
            end
        end
    end
    data.serve.online=LN.serve and count(LN.serve.clients)or 0
    data.gateway.name=LN.gw and LN.gw.name or nil;data.gateway.loading=LN.gw and not LN.gw.synced or false
    data.mesh=LN.MeshActive()
    return data
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
