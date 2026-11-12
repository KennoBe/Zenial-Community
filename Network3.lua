local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local N={PREFIX=L.PREFIX3,FRAME_BYTES=180,MAX_JOBS=256,MAX_QUEUE_BYTES=65536}
Z.Network3=N

local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local PUBLIC={P=true,B=true,RX=true,PC=true,PU=true,PX=true,MP=true,LY=true,L2=true,PD=true}
local DIRECT={RQ=true,RR=true,RB=true,OC=true,OO=true,OS=true,OQ=true,OA=true,AV=true,SH=true,SA=true,SQ=true,SS=true,SK=true,SP=true}
local function allowedKind(channel,kind)return channel=="PUBLIC"and PUBLIC[kind]or channel=="WHISPER"and DIRECT[kind]or false end
local function trace(reason,...)
    if Z.Diagnostics then Z.Diagnostics.Record("protocol3:"..reason,...)end
end
local function releaseAssembly(bucket,token,field)
    local p=bucket[token];if not p then return end
    bucket[token]=nil;N[field]=math.max(0,N[field]-p.size)
    local remaining=(N.senderParts[p.key]or 1)-1;N.senderParts[p.key]=remaining>0 and remaining or nil
end
local function clean(v,max)
    v=tostring(v or"")
    if #v>max or v:find("[%z\1-\31\127|]")then return nil end
    return v
end
local function encodeField(v)
    return tostring(v or""):gsub("%%","%%25"):gsub("\t","%%09"):gsub("\n","%%0A"):gsub("\r","%%0D")
end
local function decodeField(v)
    local bad=false
    v=v:gsub("%%(%x%x)",function(h)
        if h~="25"and h~="09"and h~="0A"and h~="0D"then bad=true;return""end
        return string.char(tonumber(h,16))
    end)
    return not bad and v or nil
end
local function fields(wire)
    if type(wire)~="string"or#wire>4096 then return nil end
    local out={}
    for value in(wire.."\t"):gmatch("([^\t]*)\t")do
        value=decodeField(value);if not value then return nil end
        out[#out+1]=value;if#out>80 then return nil end
    end
    return out
end
local function joined(t)return table.concat(t,"\t")end
function N.Pack(values)local out={};for i=1,#values do out[i]=encodeField(values[i])end;return joined(out)end
function N.Unpack(wire)return fields(wire)end
-- Separate optional position records keep the established 17-field presence
-- wire compatible with clients that do not yet display community map members.
function N.DecodeMapPosition(wire)
    local f=fields(wire)
    if not f or#f~=5 or not L.Text(f[1],32)or not f[1]:match("^%d+%.%d+%.%d+$")then return nil end
    local at,mapID,x,y=tonumber(f[2]),tonumber(f[3]),tonumber(f[4]),tonumber(f[5])
    if not L.Int(at,1,4102444800)or at>A.Now()+120 or A.Now()-at>300
        or not L.Int(mapID,0,1000000)or not L.Int(x,0,10000)or not L.Int(y,0,10000)
        or mapID==0 and(x~=0 or y~=0)then return nil end
    return{session=f[1],at=at,mapID=mapID,x=x,y=y}
end
-- PD (PvP death marker) wire: session, at (time of death), deathId, mapID, x, y, area, subzone, layerID (0 = unknown),
-- minAttackers, killerFirst, attackerCount, then per attacker: name, classFile, race, level (0 = unknown).
-- The victim is never part of the wire; receivers take it from the validated mesh origin. No GUIDs.
N.PD_LIFETIME=600
local function digits(v,max)return type(v)=="string"and#v<=(max or 10)and v:match("^%d+$")and tonumber(v)end
function N.DecodePvPDeath(wire)
    local f=fields(wire);if not f or#f<12 then return nil end
    if not L.Text(f[1],32)or not f[1]:match("^%d+%.%d+%.%d+$")or not L.Text(f[3],24)or not f[3]:match("^%d+%.%d+$")then return nil end
    local at,mapID,x,y=digits(f[2]),digits(f[4]),digits(f[5]),digits(f[6])
    local layerID,minA,killerFirst,count=digits(f[9]),digits(f[10]),digits(f[11]),digits(f[12])
    local now=A.Now()
    if not L.Int(at,1,4102444800)or at>now+120 or now-at>N.PD_LIFETIME or not L.Int(mapID,1,1000000)or not L.Int(x,0,10000)or not L.Int(y,0,10000)
        or not L.Int(layerID,0,4294967295)or not L.Int(minA,1,40)or not L.Int(killerFirst,0,1)or not L.Int(count,0,5)
        or not L.Text(f[7],64,true)or not L.Text(f[8],64,true)or#f~=12+4*count or killerFirst==1 and count<1 or minA<count then return nil end
    local attackers={}
    for i=1,count do
        local base=12+(i-1)*4;local level=digits(f[base+4],3)
        if not L.Text(f[base+1],80)or not L.Text(f[base+2],16,true)or f[base+2]~=""and not f[base+2]:match("^[A-Z_]+$")or not L.Text(f[base+3],24,true)or not L.Int(level,0,100)then return nil end
        attackers[i]={name=f[base+1],classFile=f[base+2],race=f[base+3],level=level>0 and level or nil}
    end
    return{session=f[1],at=at,deathId=f[3],mapID=mapID,x=x,y=y,area=f[7],subzone=f[8],layerID=layerID>0 and layerID or nil,minAttackers=minA,killerFirst=killerFirst==1,attackers=attackers}
end
function N.PackPvPDeath(session,d)
    local list={};local killer=d.killer
    if killer then list[1]=killer end
    for _,a in ipairs(d.attackers or{})do if not(killer and a.name==killer.name)and#list<5 then list[#list+1]=a end end
    local values={session,d.at,d.id,d.mapID,d.x,d.y,d.area or"",d.subzone or"",d.layerID or 0,math.max(d.minAttackers or 1,#list),killer and 1 or 0,#list}
    for _,a in ipairs(list)do values[#values+1]=a.name;values[#values+1]=a.classFile or"";values[#values+1]=a.race or"";values[#values+1]=a.level or 0 end
    return N.Pack(values)
end
local function professionIDs()
    local ids={}
    if not Z.db.visible or not Z.db.shareProfessions then return""end
    for _,p in ipairs(Z.db.professions or{})do if L.Int(p.id,1,100000)then ids[#ids+1]=p.id end end
    table.sort(ids);while#ids>6 do table.remove(ids)end
    for i,id in ipairs(ids)do ids[i]=tostring(id)end
    return table.concat(ids,",")
end
local function availability()
    if A.Call(UnitIsAFK,"player")==true then return"AFK"end
    if Z.db.availability=="BUSY"then return"BUSY"end
    if A.Call(IsInGroup)==true or A.Call(IsInRaid)==true then return"GROUP"end
    return"AVAILABLE"
end
local function presenceWire()
    local loc=Z.location or A.PlayerLocation()
    local visible=Z.db.visible;local pvp=Z.PvPHelp and Z.PvPHelp.store;local values={"P","3",Z.session,Z.me.realm,Z.me.faction,visible and Z.me.classFile or"",visible and Z.me.level or 0,visible and Z.db.roles or"",visible and availability()or"AVAILABLE",professionIDs(),Z.db.rev,Z.db.recipeRev,Z.db.publicRev,visible and(loc.instanceID and 900000+loc.instanceID or loc.mapID or 0)or 0,pvp and pvp.receive and 1 or 0,pvp and pvp.scope or"all",visible and A.CurrentMapID()or 0}
    for i=1,#values do values[i]=encodeField(values[i])end
    local wire=joined(values)
    return#wire<=238 and wire or nil
end
function N.Initialize()
    N.jobs,N.jobBytes,N.assemblies,N.directAssemblies,N.senderParts,N.waitingTargets={},0,{},{},{},{}
    N.assemblyBytes,N.directAssemblyBytes=0,0;N.inboundPublic,N.inboundDirect={},{};N.inboundPublicBytes,N.inboundDirectBytes=0,0
    N.stats={sent=0,received=0,throttle=0,dropped=0,invalid=0,presence=0,bundles=0,lastReceive=0,lastError=""}
    N.tokens,N.byteTokens,N.lastClock=8,1600,A.Clock()
    N.nextSend=0;N.backoff=0;N.throttledUntil=0;N.nextPresence=A.Clock()+math.random(0,30)
    N.pendingPublish=true;N.publishDue=A.Clock()+2;N.lastPublish=-100
    N.session=L.NextID(Z.db,A.Now()).."."..tostring(math.random(100000,999999));Z.session=N.session;Z.db.generation=N.session
end
function N.Queue(channel,target,kind,wire,priority,dedupe)
    if not Z.db.consent or channel~="WHISPER"then return nil,"Austausch nicht verfügbar."end
    if channel=="WHISPER"then local key=Z.ResolvePeerKey(target);if not key or not Z.db.contacts[key]or Z.db.blocked[key]then return nil,"Austausch nicht verfügbar."end end
    if not allowedKind(channel,kind)or type(wire)~="string"or#wire>L.MAX_BYTES or not clean(kind,4)then return nil,"Daten sind ungültig oder zu groß."end
    local total=math.ceil(#wire/N.FRAME_BYTES);if total<1 or total>L.MAX_PARTS then return nil,"Daten sind ungültig oder zu groß."end
    if dedupe then
        for _,job in ipairs(N.jobs)do if job.dedupe==dedupe and job.part==1 then local bytes=N.jobBytes-#job.wire+#wire;if bytes>N.MAX_QUEUE_BYTES then return nil,"Warteschlange voll."end;N.jobBytes=bytes;job.wire=wire;job.total=total;job.kind=kind;job.channel=channel;job.target=target;job.priority=priority or job.priority;return job.id end end
    end
    local direct=(priority or 20)>=80;local jobLimit=direct and N.MAX_JOBS or N.MAX_JOBS-32;local byteLimit=direct and N.MAX_QUEUE_BYTES or N.MAX_QUEUE_BYTES-8192
    if#N.jobs>=jobLimit or N.jobBytes+#wire>byteLimit then N.stats.dropped=N.stats.dropped+1;N.stats.lastError="Warteschlange voll";return nil,"Warteschlange voll."end
    local id=L.NextID(Z.db,A.Now());N.jobs[#N.jobs+1]={id=id,channel=channel,target=target,kind=kind,wire=wire,total=total,part=1,priority=priority or 20,dedupe=dedupe,serial=id};N.jobBytes=N.jobBytes+#wire
    return id
end
function N.TakeLegacyBudget(bytes)
    local clock=A.Clock();local elapsed=math.max(0,math.min(2,clock-(N.lastClock or clock)));N.lastClock=clock;N.tokens=math.min(8,N.tokens+elapsed*4);N.byteTokens=math.min(1600,N.byteTokens+elapsed*800)
    bytes=tonumber(bytes)or 240;if N.tokens<1 or N.byteTokens<bytes then return false end;N.tokens=N.tokens-1;N.byteTokens=N.byteTokens-bytes;return true
end
function N.QueuePublic(kind,wire,priority,dedupe)
    if not Z.db.consent or not Z.db.autoDiscovery then return nil,"Austausch nicht verfügbar."end
    local mesh=Z.CommunityMesh and Z.CommunityMesh.Publish(kind,wire)
    if mesh then return mesh end
    return nil,"Network is not ready yet."
end
function N.QueueDirect(target,kind,wire,priority,dedupe)
    if not L.Text(target,113)then return nil,"Ungültiges Ziel."end
    return N.Queue("WHISPER",target,kind,wire,priority or 80,dedupe)
end
function N.Publish()
    N.pendingPublish=true;N.publishDue=math.max(A.Clock()+2,(N.lastPublish or 0)+10)
    Z.db.publicRev=math.min(math.max((Z.db.publicRev or 1)+1,Z.db.rev or 1),2147483646)
end
function N.Retract(entryType,id,revision)
    if(entryType~="G"and entryType~="Q"and entryType~="M")or not L.Text(id,32)or not L.Int(revision,0,2147483646)then return nil end
    return N.QueuePublic("RX",N.Pack({entryType,id,revision}),85,"RETRACT:"..entryType..":"..id)
end
local function bundleWire()
    local snapshot=L.Snapshot(Z.db,Z.me,Z.PublicLinks and Z.PublicLinks()or{main="",version=0,alts={}})
    snapshot.community,snapshot.class,snapshot.classFile,snapshot.guild,snapshot.guid,snapshot.roles,snapshot.note,snapshot.professionNote="","","","","","","",""
    snapshot.level,snapshot.professions,snapshot.linkAlts,snapshot.recipeRev,snapshot.recipeCount,snapshot.recipeScan=0,{},{},0,0,0
    return L.Encode(snapshot)
end
N.PresenceWire=presenceWire;N.BundleWire=bundleWire
local function chooseJob(clock)
    local best,index
    for i,job in ipairs(N.jobs)do
        local readyAt=N.waitingTargets[L.Identity(job.target)]or 0
        if clock>=readyAt and(not best or job.priority>best.priority or job.priority==best.priority and job.serial<best.serial)then best,index=job,i end
    end
    return best,index
end
local function removeJob(index,job)
    N.jobBytes=math.max(0,N.jobBytes-#job.wire);table.remove(N.jobs,index)
end
function N.Tick()
    if not Z.db then return end
    for i=#N.jobs,1,-1 do local job=N.jobs[i];local key=job.channel=="WHISPER"and Z.ResolvePeerKey(job.target);if not Z.db.consent or job.channel~="WHISPER"or job.channel=="WHISPER"and(not key or not Z.db.contacts[key]or Z.db.blocked[key])then removeJob(i,job)end end
    if not Z.db.consent then return end
    local started=A.Clock();local processed=0
    while processed<32 and A.Clock()-started<.002 do
        local presence=N.inboundPublic[1]and N.inboundPublic[1].kind=="P";local direct=not presence and#N.inboundDirect>0;local queue=direct and N.inboundDirect or N.inboundPublic;local item=table.remove(queue,1);if not item then break end
        if direct then N.inboundDirectBytes=math.max(0,N.inboundDirectBytes-#item.wire)else N.inboundPublicBytes=math.max(0,N.inboundPublicBytes-#item.wire)end
        local ok,changed=N.ProcessComplete(item.sender,item.channel,item.kind,item.wire);trace(ok and "accepted"or "rejected_message",item.sender,item.kind);if ok and changed~=false and Z.MarkDirty then Z.MarkDirty(item.kind)end;processed=processed+1
    end
    local clock=A.Clock();local elapsed=math.max(0,math.min(2,clock-(N.lastClock or clock)));N.lastClock=clock
    N.tokens=math.min(8,N.tokens+elapsed*4);N.byteTokens=math.min(1600,N.byteTokens+elapsed*800)
    if Z.db.autoDiscovery then
        if clock>=N.nextPresence then local wire=presenceWire();if wire then N.QueuePublic("P",wire,70,"PRESENCE")end;N.nextPresence=clock+105+math.random(0,30)end
        if N.pendingPublish and clock>=(N.publishDue or 0)then local wire=bundleWire();if wire then local id=N.QueuePublic("B",wire,35,"PUBLIC");if id then N.pendingPublish=false;N.lastPublish=clock end end end
    end
    if clock<N.nextSend or N.tokens<1 then return end
    for target,at in pairs(N.waitingTargets)do if clock>=at then N.waitingTargets[target]=nil end end
    -- A handshake wait belongs to one destination. Look past it without
    -- charging a frame budget or holding up another player's direct action.
    for _=1,8 do
        local job,index=chooseJob(clock);if not job then return end
        local chunk=job.wire:sub((job.part-1)*N.FRAME_BYTES+1,job.part*N.FRAME_BYTES)
        local frame="3|"..job.id.."|"..job.part.."|"..job.total.."|"..job.kind.."|"..chunk
        if#frame>240 then N.stats.lastError="Frame zu groß";removeJob(index,job);return end
        if N.byteTokens<#frame then return end
        local result=A.Send3(frame,job.channel,job.target,{reason=job.kind,background=false})
        if result=="pending_route"then
            local transport=Z.BattleNetTransport
            N.waitingTargets[L.Identity(job.target)]=transport and transport.PendingUntil and transport.PendingUntil(job.target)or clock+1
        else
            N.tokens=N.tokens-1;N.byteTokens=N.byteTokens-#frame
            if result=="ok"then N.stats.sent=N.stats.sent+1;N.stats.lastError="";N.backoff=0;job.part=job.part+1;if job.part>job.total then if Z.PvPHelp then Z.PvPHelp.BroadcastResult(job.kind,job.wire,"sent")end;removeJob(index,job)end
            elseif result=="throttle"then N.stats.throttle=N.stats.throttle+1;N.backoff=math.min((N.backoff or 0)+1,5);N.nextSend=clock+({2,4,8,16,30})[N.backoff];N.throttledUntil=N.nextSend
            elseif result=="blocked"then N.nextSend=clock+5;N.stats.lastError="Addon-Nachrichten gesperrt"
            else N.stats.lastError=A.network.lastError or"Senden fehlgeschlagen";if Z.PvPHelp then Z.PvPHelp.BroadcastResult(job.kind,job.wire,"error")end;removeJob(index,job)end
            return
        end
    end
end
function N.PublicSessionAllowed(target,session)
    local epoch=type(session)=="string"and tonumber(session:match("^(%d+)%."))
    if epoch and epoch>A.Now()+120 then return false end
    local key=Z.ResolvePeerKey(target);local peer=key and Z.db.peers[key]
    if peer and peer.verifiedSession and peer.verifiedSession~=session then
        local route=Z.BattleNetTransport and Z.BattleNetTransport.Route(target)
        if route and route.session==peer.verifiedSession then
            -- A real /reload can change the owner's session while ordinary
            -- incoming traffic keeps the old route fresh. Verify the claim
            -- through that native account, never grant a relay authority.
            local transport=Z.BattleNetTransport;local clock=A.Clock()
            if route.transport=="BNET"and clock>=(peer.sessionProbeAt or 0)then
                peer.sessionProbeAt=clock+30
                if not transport.pending["BNET:"..route.target]then transport.Probe("BNET",route.target,"session_refresh")end
            end
            return false
        end
    end
    return true
end
function N.ConfirmSession(target,session)
    local key=Z.ResolvePeerKey(target);local peer=key and Z.db.peers[key]
    if not peer or not L.Text(session,32)then return false end
    local changed=peer.verifiedSession and peer.verifiedSession~=session
    if changed or peer.session~=session then
        peer.publicAppliedRev,peer.publicDeltaRev,peer.retractions,peer.presenceSignature=nil,nil,nil,nil
        peer.presence,peer.reportedAt,peer.reportedClock=nil,nil,nil
        if peer.data and peer.data.generation~=session then peer.data,peer.wire=nil,nil end
    end
    peer.verifiedSession=session;peer.verifiedAt=A.Clock();peer.session=session
    if peer.retiredSessions then peer.retiredSessions[session]=nil end
    for i=#(peer.retiredSessionOrder or{}),1,-1 do if peer.retiredSessionOrder[i]==session then table.remove(peer.retiredSessionOrder,i)end end
    N.waitingTargets[L.Identity(target)]=nil
    if Z.engine and Z.engine.waitingTargets then Z.engine.waitingTargets[key]=nil end
    if changed then
        for index,bucket in ipairs({N.assemblies,N.directAssemblies})do for id,p in pairs(bucket)do if p.key==key then releaseAssembly(bucket,id,index==1 and"assemblyBytes"or"directAssemblyBytes")end end end
        for index,queue in ipairs({N.inboundPublic,N.inboundDirect})do for i=#queue,1,-1 do if Z.ResolvePeerKey(queue[i].sender)==key then
            local field=index==1 and"inboundPublicBytes"or"inboundDirectBytes";N[field]=math.max(0,N[field]-#queue[i].wire);table.remove(queue,i)
        end end end
        local engine=Z.engine
        if engine then for id,p in pairs(engine.parts)do if p.key==key then engine.parts[id]=nil end end;engine.partCounts[key]=nil end
        if Z.CommunityMap and Z.CommunityMap.positions then Z.CommunityMap.positions[key]=nil end
        Z.db.recipeCatalogs[key]=nil
        if Z.RecipeSearch and Z.RecipeSearch.InvalidatePeer then Z.RecipeSearch.InvalidatePeer(key)
        else for _,results in pairs(Z.db.recipeResults or{})do results[key]=nil end end
    end
    if Z.CommunityMesh then Z.CommunityMesh.ConfirmSession(target,session)end
    if Z.QuestMesh then Z.QuestMesh.ConfirmSession(target,session)end
    if Z.ScheduledMesh then Z.ScheduledMesh.ConfirmSession(target,session)end
    return true
end
local function touchPeer(sender,realm,faction,session)
    -- The transport validates direct senders; mesh context preserves the origin.
    -- The old realm wire field is compatibility metadata, never a membership
    -- boundary. Store peers in this local profile's world/faction namespace.
    local _,target=L.Identity(sender);local key=target and L.ScopeKey(target,Z.me.realm,faction)
    if not key then trace("invalid_identity",sender);return nil end
    if key==Z.me.key then trace("self",sender);return nil end
    if faction~=Z.me.faction then trace("faction_mismatch",sender,faction,Z.me.faction);return nil end
    if realm~=Z.me.realm then trace("realm_metadata_ignored",sender,realm)end
    if Z.db.blocked[key]then trace("blocked_sender",sender);return nil end
    if not N.PublicSessionAllowed(target,session)then trace("unverified_session",sender);return nil end
    if not Z.db.contacts[key]then local added=L.Discover(Z.db,target,Z.me.realm,"Community 3.0",A.Now(),faction);if not added then trace("contact_limit",sender);return nil end end
    local peer=Z.db.peers[key]or{};Z.db.peers[key]=peer
    local sessionChanged=peer.session~=session
    peer.retiredSessions=peer.retiredSessions or{};peer.retiredSessionOrder=peer.retiredSessionOrder or{}
    if peer.retiredSessions[session]and session~=peer.verifiedSession then trace("retired_session",sender);return nil end
    local epoch=tonumber(session:match("^(%d+)%."));local current=peer.session and tonumber(peer.session:match("^(%d+)%."))
    local seq=tonumber(session:match("^%d+%.(%d+)%.%d+$"));local currentSeq=peer.session and tonumber(peer.session:match("^%d+%.(%d+)%.%d+$"))
    if session~=peer.verifiedSession and sessionChanged and epoch and current and(epoch<current or epoch==current and seq and currentSeq and seq<currentSeq)then trace("older_session",sender);return nil end
    if sessionChanged then
        if peer.session and peer.session~=peer.verifiedSession then peer.retiredSessions[peer.session]=true;peer.retiredSessionOrder[#peer.retiredSessionOrder+1]=peer.session;while#peer.retiredSessionOrder>16 do peer.retiredSessions[table.remove(peer.retiredSessionOrder,1)]=nil end end
        peer.publicAppliedRev,peer.publicDeltaRev,peer.retractions,peer.presenceSignature=nil,nil,nil,nil
    end
    if N.meshContext then
        peer.cap4=true;peer.networkReported=true;peer.reportedAt=N.meshContext.at;peer.reportedClock=A.Clock()-math.max(0,A.Now()-N.meshContext.at)
    else peer.lastContact=A.Now();peer.lastContactClock=A.Clock()end
    peer.session=session;peer.realm=Z.me.realm;peer.advertisedRealm=realm;peer.faction=faction;peer.cap30=true;peer.state="reached"
    return key,peer,sessionChanged
end
local function receivePresence(sender,wire)
    local f=fields(wire);if not f or f[1]~="P"or f[2]~="3"or#f~=17 then return false end
    local session,realm,faction=f[3],f[4],f[5]
    if not L.Text(session,32)or not L.Text(realm,64,true)or(faction~="Alliance"and faction~="Horde"and faction~="Neutral")then return false end
    local level,rev,recipeRev,publicRev,mapID,pvpEnabled,pvpMap=tonumber(f[7]),tonumber(f[11]),tonumber(f[12]),tonumber(f[13]),tonumber(f[14]),tonumber(f[15]),tonumber(f[17])
    if not L.Int(level,0,100)or not L.Int(rev,0,2147483646)or not L.Int(recipeRev,0,2147483646)or not L.Int(publicRev,0,2147483646)or not L.Int(mapID,0,1000000)or not L.Int(pvpEnabled,0,1)or(f[16]~="all"and f[16]~="zone")or not L.Int(pvpMap,0,1000000)then return false end
    local professionList={};for id in f[10]:gmatch("%d+")do id=tonumber(id);if L.Int(id,1,100000)and#professionList<6 then professionList[#professionList+1]=id end end
    if f[10]~=""and#professionList==0 or not L.Text(f[6],16,true)or not L.Text(f[8],16,true)or not L.Text(f[9],16)then return false end
    local key,peer,sessionChanged=touchPeer(sender,realm,faction,session);if not key then return false end
    local previous=peer.presence
    if not sessionChanged and previous and(rev<previous.rev or recipeRev<previous.recipeRev)then return true,false end
    local signature=table.concat(f,"\t",3,17);local changed=peer.presenceSignature~=signature;peer.presenceSignature=signature
    peer.presence={classFile=f[6],level=level,role=f[8],availability=f[9],professionIDs=professionList,rev=rev,recipeRev=recipeRev,publicRev=publicRev,mapID=mapID,pvpEnabled=pvpEnabled==1,pvpScope=f[16],pvpMapID=pvpMap,at=A.Now(),sourceAt=N.meshContext and N.meshContext.at or A.Now()}
    if mapID>900000 and mapID<910000 and Z.DungeonData then
        peer.presence.instanceID=mapID-900000;peer.presence.mapID=0
        peer.location={mapID=0,area=Z.DungeonData.Name(mapID-900000)or"",instanceID=mapID-900000,at=peer.presence.at}
    elseif peer.location and peer.location.instanceID then peer.location=nil end
    if Z.UpdatePeerProfessions then Z.UpdatePeerProfessions(key,previous,sessionChanged)end
    peer.cap3=true;N.stats.presence=N.stats.presence+1;if not N.meshContext and Z.CraftOrders and Z.CraftOrders.OnPeerOnline then Z.CraftOrders.OnPeerOnline(key,session)end;return true,changed
end
local function assemblyBucket(channel)return channel=="PUBLIC"and N.assemblies or N.directAssemblies end
function N.ProcessComplete(sender,channel,kind,wire)
    if not Z.db or not Z.db.consent or channel=="PUBLIC"and not Z.db.autoDiscovery or not allowedKind(channel,kind)then return false end
    local senderKey=Z.ResolvePeerKey(sender);if senderKey==Z.me.key or senderKey and Z.db.blocked[senderKey]then return false end
    if kind=="P"then return receivePresence(sender,wire)end
    if kind=="MP"then return Z.CommunityMap and Z.CommunityMap.Receive(sender,wire,N.meshContext)or false end
    if kind=="PD"then return Z.CommunityMap and Z.CommunityMap.ReceiveDeath(sender,wire,N.meshContext)or false end
    if kind=="LY"then
        if Z.CommunityLayer then return Z.CommunityLayer.Receive(sender,wire,N.meshContext)end
        return false
    end
    if kind=="L2"then
        if Z.CommunityLayer then return Z.CommunityLayer.ReceiveV2(sender,wire,N.meshContext)end
        return false
    end
    if kind=="RX"then
        local f=fields(wire);local key=Z.ResolvePeerKey and Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key];local revision=f and tonumber(f[3]);if not f or#f~=3 or(f[1]~="G"and f[1]~="Q"and f[1]~="M")or not L.Text(f[2],32)or not L.Int(revision,0,2147483646)or not peer or not peer.cap30 or not N.IsOnline(key)or revision<(peer.publicAppliedRev or-1)then return false end
        local data=peer.data;if data then if f[1]=="G"and data.group and data.group.id==f[2]then data.group=nil elseif f[1]=="Q"and data.quest and data.quest.id==f[2]then data.quest=nil elseif f[1]=="M"then for i=#(data.market or{}),1,-1 do if data.market[i].id==f[2]then table.remove(data.market,i)end end end end
        if f[1]=="M"and Z.TradeManager then Z.TradeManager.OnRetract(key,f[2],revision)end
        peer.publicDeltaRev=math.max(peer.publicDeltaRev or 0,revision);peer.retractions=peer.retractions or{}
        local token=f[1]..":"..f[2];if count(peer.retractions)>=32 and not peer.retractions[token]then local oldest,at;for k,v in pairs(peer.retractions)do if not at or v<at then oldest,at=k,v end end;peer.retractions[oldest]=nil end
        peer.retractions[token]=revision;return true
    end
    if kind=="B"then
        local key=Z.ResolvePeerKey and Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key];if not peer or not peer.cap30 or not N.IsOnline(key)then return false end
        local snapshot=L.Decode(wire,A.Now());if not snapshot or snapshot.kind~="S3"or snapshot.faction~=Z.me.faction then return false end
        if peer.retiredSessions and peer.retiredSessions[snapshot.generation]or peer.session:match("^%d+%.%d+%.%d+$")and snapshot.generation~=peer.session then return false end
        local oldRev=peer.publicAppliedRev or-1;if snapshot.rev<oldRev then return false end
        if snapshot.rev<(peer.publicDeltaRev or-1)then return false end
        if snapshot.rev==oldRev then return true,false end
        L.ApplyRetractions(snapshot,peer.retractions)
        local data=peer.data
        if not data then local presence=peer.presence or{};local professions={};for _,id in ipairs(presence.professionIDs or{})do local name=L.ProfessionNameByID(id);if name then professions[#professions+1]={id=id,name=name,rank=0,max=1}end end;data={kind="S3",rev=0,generation=peer.session or"",community="",faction=snapshot.faction,class=presence.classFile or"",classFile=presence.classFile or"",level=presence.level or 0,guild="",guid="",roles=presence.role or"",note="",professionNote="",professions=professions,market={},linkMain="",linkVersion=0,linkAlts={},recipeRev=presence.recipeRev or 0,recipeCount=0,recipeScan=0,publicOnly=true};peer.data=data end
        data.group,data.quest,data.market=snapshot.group,snapshot.quest,snapshot.market;data.linkMain,data.linkVersion=snapshot.linkMain,snapshot.linkVersion;peer.publicAppliedRev=snapshot.rev;peer.received=A.Now();peer.state="reached"
        if Z.Items then Z.Items.SeedMarket(snapshot.market)end
        if Z.OnPublicBundle then Z.OnPublicBundle(key,snapshot)end
        N.stats.bundles=N.stats.bundles+1;return true
    end
    local directKey=Z.ResolvePeerKey and Z.ResolvePeerKey(sender);local directPeer=directKey and Z.db.peers[directKey]
    if Z.Receive3 then local ok=Z.Receive3(sender,kind,wire);if ok and channel=="WHISPER"and directPeer and directPeer.cap30 then directPeer.lastContact=A.Now();directPeer.lastContactClock=A.Clock()end;return ok end
    return false
end
function N.Receive(sender,payload,channel)
    if type(payload)~="string"or#payload>240 then N.stats.invalid=N.stats.invalid+1;trace("invalid_payload",sender);return false end
    local id,index,total,kind,chunk=payload:match("^3|([%d%.]+)|(%d+)|(%d+)|([A-Z][A-Z0-9]?[A-Z0-9]?[A-Z0-9]?)|(.*)$")
    index,total=tonumber(index),tonumber(total)
    if not id or#id>32 or not L.Int(total,1,L.MAX_PARTS)or not L.Int(index,1,total)or#chunk>N.FRAME_BYTES then N.stats.invalid=N.stats.invalid+1;trace("invalid_frame",sender);return false end
    if not Z.db.consent or channel=="PUBLIC"and not Z.db.autoDiscovery or not allowedKind(channel,kind)then trace("disabled_or_unsupported",sender,channel,kind);return false end
    local bucket=assemblyBucket(channel);local rawKey=L.Identity(sender);if not rawKey then trace("invalid_identity",sender);return false end;local key=(Z.ResolvePeerKey and Z.ResolvePeerKey(sender))or rawKey
    if key==Z.me.key then trace("self",sender,kind);return false end
    if Z.db.blocked[key]then trace("blocked_sender",sender,kind);return false end
    local byteField=channel=="PUBLIC"and"assemblyBytes"or"directAssemblyBytes"
    local token=key..":"..id;local p=bucket[token]
    if not p then
        local limit=channel=="PUBLIC"and 256 or 64;if count(bucket)>=limit or(N.senderParts[key]or 0)>=2 then N.stats.dropped=N.stats.dropped+1;trace("assembly_limit",sender,kind);return false end
        p={total=total,kind=kind,chunks={},size=0,at=A.Clock(),sender=sender,key=key};bucket[token]=p;N.senderParts[key]=(N.senderParts[key]or 0)+1
    end
    if p.total~=total or p.kind~=kind or p.chunks[index]and p.chunks[index]~=chunk then releaseAssembly(bucket,token,byteField);trace("fragment_conflict",sender,kind);return false end
    if not p.chunks[index]then
        local byteField=channel=="PUBLIC"and"assemblyBytes"or"directAssemblyBytes";local byteLimit=channel=="PUBLIC"and 1048576 or 262144
        if N[byteField]+#chunk>byteLimit then releaseAssembly(bucket,token,byteField);N.stats.dropped=N.stats.dropped+1;trace("assembly_byte_limit",sender,kind);return false end
        p.chunks[index]=chunk;p.size=p.size+#chunk;N[byteField]=N[byteField]+#chunk
    end
    if p.size>L.MAX_BYTES then releaseAssembly(bucket,token,byteField);trace("message_size_limit",sender,kind);return false end
    for i=1,total do if not p.chunks[i]then trace("fragment_wait",sender,kind,index,total);return false end end
    releaseAssembly(bucket,token,byteField);N.stats.received=N.stats.received+1;N.stats.lastReceive=A.Now()
    local wire=table.concat(p.chunks);local direct=channel=="WHISPER";local queue=direct and N.inboundDirect or N.inboundPublic;local bytesField=direct and"inboundDirectBytes"or"inboundPublicBytes";local queueLimit=direct and 64 or 256;local bytesLimit=direct and 262144 or 1048576
    if#queue>=queueLimit or N[bytesField]+#wire>bytesLimit then N.stats.dropped=N.stats.dropped+1;trace("inbound_limit",sender,kind);return false end
    queue[#queue+1]={sender=sender,channel=channel,kind=kind,wire=wire};N[bytesField]=N[bytesField]+#wire;trace("queued",sender,kind);return true
end
function N.ExpireAssemblies()
    local now=A.Clock();for index,bucket in ipairs({N.assemblies,N.directAssemblies})do for token,p in pairs(bucket)do if now-p.at>45 then releaseAssembly(bucket,token,index==1 and"assemblyBytes"or"directAssemblyBytes");N.stats.dropped=N.stats.dropped+1 end end end
end
function N.CancelPublic(dedupe)
    -- Public records are queued exclusively by CommunityMesh.
    if not dedupe and Z.CommunityMesh then Z.CommunityMesh.PrivacyChanged()end
end
function N.CancelPeer(key,target)
    local identity=L.Identity(target);if identity then N.waitingTargets[identity]=nil end
    for i=#N.jobs,1,-1 do local job=N.jobs[i];if job.channel=="WHISPER"and(job.target==target or Z.ResolvePeerKey(job.target)==key)then removeJob(i,job)end end
    for index,bucket in ipairs({N.assemblies,N.directAssemblies})do for token,p in pairs(bucket)do if p.key==key then releaseAssembly(bucket,token,index==1 and"assemblyBytes"or"directAssemblyBytes")end end end
    for index,queue in ipairs({N.inboundPublic,N.inboundDirect})do for i=#queue,1,-1 do if Z.ResolvePeerKey(queue[i].sender)==key then local field=index==1 and"inboundPublicBytes"or"inboundDirectBytes";N[field]=math.max(0,N[field]-#queue[i].wire);table.remove(queue,i)end end end
end
function N.IsOnline(key)
    local peer=Z.db and Z.db.peers[key];if not peer then return false end
    if peer.cap30 or peer.cap4 then
        local at=math.max(peer.lastContactClock or-1000,peer.reportedClock or-1000)
        return A.Clock()>=at and A.Clock()-at<300
    end
    return L.PeerOnline(Z.db,key,A.Now())
end
function N.Status()
    return{queue=#N.jobs,bytes=N.jobBytes,assemblies=count(N.assemblies)+count(N.directAssemblies),inbound=#N.inboundPublic+#N.inboundDirect,lastReceive=N.stats.lastReceive,lastError=N.stats.lastError,throttle=N.stats.throttle,throttled=(N.throttledUntil or 0)>A.Clock(),sent=N.stats.sent,received=N.stats.received}
end
return N
