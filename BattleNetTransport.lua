-- Verified direct transport. Private application frames never enter the mesh.
local Z,L,A,D=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.CommunityDirectory
local B={PREFIX="ZENIALNET1",MAX_JOBS=256,MAX_BYTES=65536,MAX_ROUTES=256,MAX_TEST_TARGETS=20}
Z.BattleNetTransport=B
local function trace(reason,...)
    if Z.Diagnostics then Z.Diagnostics.Record("bnet:"..reason,...)end
end
local function enabled()return Z.db and Z.db.consent and Z.identityReady and not Z.offlineOnly end
B.Enabled=enabled
function B.Available()return enabled()and B.registered and Z.bnetReceiveEvent and C_BattleNet and type(C_BattleNet.SendGameData)=="function"and type(securecall)=="function"or false end
local function key(transport,target)
    if transport=="BNET"then return "BNET:"..tostring(target)end
    local name=L.Identity(target);return name and"WHISPER:"..name or nil
end
local function identity(nonce,kind)
    return Z.Network3.Pack({"1",kind,nonce,Z.me.target,Z.me.guid or"",Z.me.realm,Z.me.faction,D.Region()or 0,D.Project()or 0,Z.session,D.OwnGameAccountID()})
end
local function parse(wire)
    local f=Z.Network3.Unpack(wire)
    if not f or#f~=11 or f[1]~="1"or not L.Int(tonumber(f[11]),0,2147483647)or not({H=true,A=true,W=true,R=true,V=true,F=true})[f[2]]then return nil,"frame"end
    if not L.Text(f[3],64)or not f[3]:match("^[%w%.]+$")or not L.Text(f[4],49)or not L.Identity(f[4])or not f[4]:find(" ",1,true)
        or not L.Text(f[5],80,true)or not L.Text(f[6],64)or not L.Text(f[10],32)then return nil,"identity_frame"end
    if f[7]~=Z.me.faction then return nil,"faction"end
    if D.World(f[6])~=D.World(Z.me.realm)then return nil,"world"end
    if not D.RegionMatches(tonumber(f[8]))then return nil,"region"end
    if tonumber(f[9])~=D.Project()then return nil,"project"end
    return f
end
function B.Reset(reason)
    B.jobs,B.bytes,B.pending,B.routes,B.proofs,B.inbound={},0,{},{},{},{}
    B.test=nil;B.serial=0;B.nextSend=0;B.tokens=1;B.byteTokens=6144;B.lastClock=A.Clock();B.nextExpiry=0;B.nextProbe=0
    B.failed={};B.publicTokens=1;B.publicLastClock=A.Clock()
    if Z.Network3 then Z.Network3.waitingTargets={}end
    if Z.engine then Z.engine.waitingTargets={}end
    if Z.CommunityMesh then Z.CommunityMesh.poolUntil=0 end
    trace("reset",reason or"initialize")
end
function B.Initialize()
    B.stats={sent=0,received=0,acknowledged=0,confirmedBNet=0,confirmedWhisper=0,throttled=0,rejected=0,timeouts=0,errors=0,cancelled=0,dropped=0,lastError=""}
    B.registered=false
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix)=="function"then
        local result=A.Call(C_ChatInfo.RegisterAddonMessagePrefix,B.PREFIX);local e=Enum and Enum.RegisterAddonMessagePrefixResult
        B.registered=result==true or e and(result==e.Success or result==e.DuplicatePrefix)or false
    end
    B.Reset()
    if Z.WhisperGuard then Z.WhisperGuard.Initialize()end
end
function B.Nonce()
    B.serial=B.serial+1;return tostring(A.Now()).."."..tostring(math.random(100000,999999)).."."..B.serial
end
function B.Queue(transport,target,kind,nonce,reason)
    if not enabled()or not B.registered then return false,"Connection tests are disabled."end
    local wire=identity(nonce,kind)
    if #wire>(transport=="WHISPER"and 240 or 3800)then return false,"Probe frame is too large."end
    if #B.jobs>=B.MAX_JOBS or B.bytes+#wire>B.MAX_BYTES then B.stats.dropped=B.stats.dropped+1;return false,"Probe queue is full."end
    B.jobs[#B.jobs+1]={transport=transport,target=target,wire=wire,kind=kind,nonce=nonce,private=true,reason=reason or"handshake",queuedAt=A.Clock(),priority=(kind=="H"or kind=="W")and 80 or 110};B.bytes=B.bytes+#wire;return true
end
local function freshAccount(id)
    local candidate=D.candidates[id];if not candidate then return nil,"roster_missing"end
    local info=A.Call(C_BattleNet and C_BattleNet.GetGameAccountInfoByID,id)
    local eligible,reason=D.Eligible(info);if not eligible then return nil,"account_"..(reason or"unavailable")end
    if info.gameAccountID~=id then return nil,"account_address_changed"end
    -- Compare two native snapshots here, never native realm spelling with the
    -- character's GetRealmName. A real character switch still invalidates proof.
    if info.characterName~=candidate.info.characterName then return nil,"roster_character_changed"end
    if info.realmName~=candidate.info.realmName then return nil,"roster_realm_changed"end
    if info.playerGuid~=candidate.info.playerGuid then return nil,"roster_guid_changed"end
    return info
end
local function boundIdentity(info,f)
    if info.characterName:find(" ",1,true)then
        if L.Identity(info.characterName)~=L.Identity(f[4])then return false end
    elseif info.characterName:lower()~=f[4]:match("^([^ ]+)"):lower()then return false end
    if L.Text(info.playerGuid or"",80)then return info.playerGuid==f[5]end
    -- Full name and GUID proof via native addon whisper is required when BN has no GUID.
    return "whisper-proof"
end
local function routeAccount(route)
    local info,reason=freshAccount(route.target);if not info then return nil,reason end
    local bound=boundIdentity(info,{[4]=route.name,[5]=route.guid})
    if not bound then return nil,"character_changed"end
    if bound=="whisper-proof"and route.identityProof~="whisper"then return nil,"identity_proof_missing"end
    if D.World(info.realmName)~=D.World(route.realm)then return nil,"world_changed"end
    return info
end
local function jobRoute(job)
    local route=B.routes[key(job.transport,job.target)]
    if not route then return nil,"route_missing"end
    if route.session~=job.session then return nil,"session_changed"end
    if route.guid~=job.guid or L.Identity(route.name)~=L.Identity(job.name)then return nil,"character_changed"end
    return route
end
function B.Probe(transport,target,reason)
    local routeKey=key(transport,target);if not routeKey then return false,"Enter a full character name."end
    if transport=="BNET"and not freshAccount(target)then return false,"Game account is not in the selected groups."end
    if transport=="WHISPER"and(not L.Text(target,49)or not target:find(" ",1,true))then return false,"Enter a full character name."end
    if L.ScopeKey(target,Z.me.realm,Z.me.faction)==Z.me.key then return false,"Choose another character."end
    if B.pending[routeKey]then return false,"A connection test is already pending."end
    if B.failed[routeKey]and A.Clock()<B.failed[routeKey]then return false,"Connection is temporarily unavailable."end
    if L.Count(B.pending)>=B.MAX_ROUTES then return false,"Probe queue is full."end
    local nonce=B.Nonce();local ok,error=B.Queue(transport,target,transport=="BNET"and"H"or"W",nonce,reason)
    if not ok then return false,error end
    B.pending[routeKey]={nonce=nonce,target=target,transport=transport,started=A.Clock(),deadline=A.Clock()+30,attempts=1,reason=reason or"handshake"}
    trace("probe",transport,target,reason or"handshake");return true
end
function B.Test(target)
    if not enabled()then return false,"Addon exchange or character identity is unavailable."end
    if not D.Project()then return false,"WoW project data is unavailable. Copy diagnostics."end
    if target and target~=""then return B.Probe("WHISPER",target,"manual_test")end
    local ids={};for id in pairs(D.candidates)do ids[#ids+1]=id end;table.sort(ids)
    while #ids>B.MAX_TEST_TARGETS do table.remove(ids)end
    if #ids==0 then D.RequestScan();return false,"No eligible game accounts found yet."end
    B.test={ids=ids,index=1};return true
end
local function blocked(target)
    local peerKey=L.ScopeKey(target,Z.me.realm,Z.me.faction);return peerKey==Z.me.key or peerKey and Z.db.blocked[peerKey]
end
local function confirm(transport,target,f,identityProof)
    if blocked(f[4])then return false end
    local routeKey=key(transport,target);if not B.routes[routeKey]and L.Count(B.routes)>=B.MAX_ROUTES then return false end
    local oldRoute=B.routes[routeKey]
    local first=not oldRoute
    B.routes[routeKey]={transport=transport,target=target,name=f[4],guid=f[5],session=f[10],realm=f[6],at=A.Clock(),region=tonumber(f[8]),identityProof=identityProof}
    if oldRoute and oldRoute.session==f[10]then B.routes[routeKey].questHelper=oldRoute.questHelper;B.routes[routeKey].scheduledGroups=oldRoute.scheduledGroups end
    if transport=="BNET"then local info=freshAccount(target);B.routes[routeKey].nativeRealm=info and info.realmName end
    B.pending[routeKey]=nil
    B.failed[routeKey]=nil
    B.failed[key("WHISPER",f[4])]=nil
    local peerKey=L.ScopeKey(f[4],Z.me.realm,Z.me.faction)
    if not Z.db.contacts[peerKey]then L.Discover(Z.db,f[4],Z.me.realm,"Battle.net network",A.Now(),Z.me.faction)end
    if not Z.db.contacts[peerKey]then B.routes[routeKey]=nil;return false end
    local peer=Z.db.peers[peerKey]or{};Z.db.peers[peerKey]=peer
    peer.cap4=true;peer.cap3=true;peer.lastContact=A.Now();peer.lastContactClock=A.Clock();peer.state="reached"
    if Z.WhisperGuard then Z.WhisperGuard.Verified(f[4])end
    if Z.Network3.ConfirmSession then Z.Network3.ConfirmSession(f[4],f[10])end
    if first and Z.CommunityMesh then Z.CommunityMesh.OnConnected(B.routes[routeKey])end
    if Z.QuestMesh and(first or not B.routes[routeKey].questHelper)then Z.QuestMesh.OnConnected(B.routes[routeKey])end
    if first then local field=transport=="BNET"and"confirmedBNet"or"confirmedWhisper";B.stats[field]=B.stats[field]+1 end
    if Z.ScheduledGroups then Z.ScheduledGroups.OnConnected(B.routes[routeKey])end
    if Z.UpdateNotice then Z.UpdateNotice.OnConnected(B.routes[routeKey])end
    B.stats.acknowledged=B.stats.acknowledged+1;B.stats.lastError="";trace("confirmed",transport,f[4]);return true
end
local function allowInbound(routeKey)
    local now=A.Clock();local row=B.inbound[routeKey]
    if not row then if L.Count(B.inbound)>=512 then return false end;row={at=now,count=0};B.inbound[routeKey]=row end
    if now-row.at>=60 then row.at=now;row.count=0 end
    if row.count>=600 then return false end;row.count=row.count+1;return true
end
function B.Route(target)
    local identity=L.Identity(target);if not identity then return nil end
    local whisper
    for _,row in pairs(B.routes or{})do if L.Identity(row.name)==identity and A.Clock()-row.at<300 then
        if row.transport=="BNET"and routeAccount(row)then return row elseif row.transport=="WHISPER"then whisper=row end
    end end
    return whisper
end
function B.IsReachable(target)return B.Route(target)~=nil end
function B.PendingUntil(target)
    local id=L.Identity(target);if not id then return nil end
    local pending=B.pending[key("WHISPER",target)];if pending then return pending.deadline end
    for _,proof in pairs(B.proofs or{})do if L.Identity(proof.target)==id and A.Clock()<=proof.deadline then return proof.deadline end end
    for _,row in pairs(B.pending or{})do if row.transport=="BNET"then
        local candidate=D.candidates[row.target]
        if candidate and L.Identity(candidate.info.characterName)==id then return row.deadline end
    end end
end
local function complete(job,result)
    if job.completed then return end;job.completed=true
    if job.onResult then pcall(job.onResult,result)end
end
function B.QueueData(route,protocol,payload,private,dedupe,priority,onResult,context)
    if not enabled()or not B.registered or not route or type(payload)~="string"then return false end
    if B.routes[key(route.transport,route.target)]~=route or blocked(route.name)then return false end
    local wire,prefix
    if route.transport=="BNET"then wire="D|"..protocol.."|"..payload
    elseif protocol=="1"or protocol=="3"then wire=payload;prefix=protocol=="1"and L.PREFIX or L.PREFIX3 else return false end
    if #wire>(route.transport=="BNET"and 3800 or 240)then return false end
    local job={transport=route.transport,target=route.target,wire=wire,prefix=prefix,kind=protocol,private=private==true,guid=route.guid,name=route.name,realm=route.realm,session=route.session,dedupe=dedupe,priority=private and 100 or priority or 20,onResult=onResult,reason=context and context.reason or protocol,queuedAt=A.Clock()}
    if dedupe then for i,old in ipairs(B.jobs)do if old.dedupe==dedupe then
        if B.bytes-#old.wire+#wire>B.MAX_BYTES then return false end
        B.bytes=B.bytes-#old.wire+#wire;B.jobs[i]=job;complete(old,"superseded");return true
    end end end
    local jobLimit=private and B.MAX_JOBS or B.MAX_JOBS-64;local byteLimit=private and B.MAX_BYTES or B.MAX_BYTES-16384
    if #B.jobs>=jobLimit or B.bytes+#wire>byteLimit then B.stats.dropped=B.stats.dropped+1;return false end
    B.jobs[#B.jobs+1]=job;B.bytes=B.bytes+#wire;return true
end
function B.SendApplication(protocol,wire,target,context)
    if not enabled()then return "blocked"end
    context=context or{}
    local route=B.Route(target)
    if route then return B.QueueData(route,protocol,wire,true,nil,nil,nil,context)and"ok"or"throttle"end
    if context.background then trace("skip_background",target,context.reason or protocol);return"error"end
    local routeKey=key("WHISPER",target)
    if not routeKey then return"error"end
    if B.failed[routeKey]and A.Clock()<B.failed[routeKey]then return "error"end
    if B.PendingUntil(target)then return"pending_route"end
    -- Prefer an eligible native account in our lounges over a name-only probe.
    for id,candidate in pairs(D.candidates or{})do
        if L.Identity(candidate.info.characterName)==L.Identity(target)and freshAccount(id)then
            local accountKey=key("BNET",id)
            if B.failed[accountKey]and A.Clock()<B.failed[accountKey]then return"error"end
            if not B.pending[accountKey]then local accepted=B.Probe("BNET",id,context.reason or protocol);if not accepted then return"error"end end
            return"pending_route"
        end
    end
    if not B.pending[routeKey]then
        local accepted,reason=B.Probe("WHISPER",target,context.reason or protocol)
        if not accepted then B.stats.lastError=reason or"Connection test unavailable.";return"error"end
    end
    return "pending_route"
end
function B.FailTarget(target,reason)
    local id=L.Identity(target);if not id then return end
    local ids={}
    for routeKey,route in pairs(B.routes or{})do if L.Identity(route.name)==id then ids[route.target]=true;B.routes[routeKey]=nil;B.failed[routeKey]=A.Clock()+60 end end
    for nonce,proof in pairs(B.proofs or{})do if L.Identity(proof.target)==id then ids[proof.id]=true;B.proofs[nonce]=nil end end
    for routeKey,pending in pairs(B.pending or{})do
        if pending.transport=="WHISPER"and L.Identity(pending.target)==id or ids[pending.target]then B.pending[routeKey]=nil;B.failed[routeKey]=A.Clock()+60 end
    end
    B.failed[key("WHISPER",target)]=A.Clock()+60
    for i=#B.jobs,1,-1 do local job=B.jobs[i]
        if L.Identity(job.name or(job.transport=="WHISPER"and job.target or""))==id or ids[job.target]then
            table.remove(B.jobs,i);B.bytes=math.max(0,B.bytes-#job.wire);complete(job,"error")
        end
    end
    local peerKey=Z.ResolvePeerKey(target);local peer=peerKey and Z.db.peers[peerKey]
    if peer then peer.lastContact,peer.lastContactClock,peer.reportedAt,peer.reportedClock=nil,nil,nil,nil;peer.state="unreachable"end
    if peerKey and Z.engine then
        local io=Z.engine.io
        if io.delivery then for _,p in ipairs(Z.engine.out)do if p.key==peerKey then io.delivery(peerKey,p.dedupe,false)end end;for _,p in pairs(Z.engine.pending)do if p.key==peerKey then io.delivery(peerKey,p.dedupe,false)end end end
        Z.engine:CancelPeer(peerKey)
    end
    if peerKey and Z.Network3 then Z.Network3.CancelPeer(peerKey,target)end
    if Z.MarkDirty then Z.MarkDirty("offline")end
    trace("unreachable",target,reason or"timeout")
end
function B.ReceiveData(wire,transport,sender)
    local route=B.routes[key(transport,sender)];if not route or blocked(route.name)then return false end
    if transport=="BNET"then
        local info,reason=routeAccount(route)
        if not info then B.stats.rejected=B.stats.rejected+1;trace("data_rejected",reason);return false end
    end
    local protocol,payload=wire:match("^D|([13MQE])|(.*)$");if not protocol then return false end
    route.at=A.Clock()
    local peer=Z.db.peers[Z.ResolvePeerKey(route.name)]
    if peer then peer.lastContact=A.Now();peer.lastContactClock=A.Clock()end
    if protocol=="E"then return Z.db.autoDiscovery and Z.ScheduledMesh and Z.ScheduledMesh.Receive(route,payload)or false end
    if protocol=="Q"then return Z.db.autoDiscovery and Z.QuestMesh and Z.QuestMesh.Receive(route,payload)or false end
    if protocol=="M"then return Z.db.autoDiscovery and Z.CommunityMesh and Z.CommunityMesh.Receive(route,payload)or false end
    if #payload>240 then return false end
    return A.ReceiveApplication(protocol=="1"and L.PREFIX or L.PREFIX3,payload,route.name)
end
function B.Receive(prefix,wire,transport,sender)
    if not A.Safe(prefix)or prefix~=B.PREFIX then return false end
    if not enabled()or not B.registered or not A.Safe(wire,sender,transport)or type(wire)~="string"
        or#wire>(transport=="WHISPER"and 240 or 3800)then return false end
    if transport~="WHISPER"and transport~="BNET"then return false end
    if transport=="BNET"and not L.Int(sender,1,2147483647)or transport=="WHISPER"and not L.Text(sender,113)then return false end
    local routeKey=key(transport,sender);if not routeKey or not allowInbound(routeKey)then return false end
    B.stats.received=B.stats.received+1
    if wire:sub(1,2)=="D|"then return B.ReceiveData(wire,transport,sender)end
    local f,reason=parse(wire);if not f or blocked(f[4])then
        reason=reason or"blocked";B.stats.rejected=B.stats.rejected+1;trace("rejected",transport,reason);trace("reject_"..reason);return false
    end
    if transport=="BNET"then
        if f[2]~="H"and f[2]~="A"then B.stats.rejected=B.stats.rejected+1;return false end
        local info=freshAccount(sender);local bound=info and boundIdentity(info,f)
        if not bound then B.stats.rejected=B.stats.rejected+1;trace("rejected","BNET","identity_or_membership");return false end
        if f[2]=="H"then
            B.Queue("BNET",sender,"A",f[3]);if not B.pending[routeKey]and not B.routes[routeKey]then B.Probe("BNET",sender)end;return true
        end
        local pending=B.pending[routeKey]
        if not pending or pending.nonce~=f[3]or A.Clock()>pending.deadline then B.stats.rejected=B.stats.rejected+1;return false end
        if bound==true then return confirm("BNET",sender,f,"guid")end
        if not pending.proof then
            local nonce=B.Nonce();pending.proof=nonce;pending.deadline=A.Clock()+30
            B.proofs[nonce]={id=sender,target=f[4],fields=f,deadline=pending.deadline}
            B.Queue("WHISPER",f[4],"V",nonce,"identity_proof")
        end
        return true
    end
    if L.Identity(sender)~=L.Identity(f[4])then B.stats.rejected=B.stats.rejected+1;return false end
    -- A new native challenge proves current activity; permit its reciprocal proof.
    if f[2]=="W"or f[2]=="V"then B.failed[routeKey]=nil end
    if f[2]=="W"then
        B.Queue("WHISPER",sender,"R",f[3],"handshake_reply")
        local route=B.routes[routeKey]
        -- The native sender is active, but its new session still needs our own
        -- challenge. A cached reciprocal route must not freeze it after reload.
        if not B.pending[routeKey]and(not route or route.session~=f[10])then B.Probe("WHISPER",sender,"reciprocal")end
        return true
    end
    if f[2]=="V"then return B.Queue("WHISPER",sender,"F",f[3])end
    if f[2]=="F"then
        local proof=B.proofs[f[3]];local info=proof and freshAccount(proof.id)
        if not proof or A.Clock()>proof.deadline or L.Identity(sender)~=L.Identity(proof.target)
            or tonumber(f[11])~=proof.id or f[5]~=proof.fields[5]or f[10]~=proof.fields[10]or not info or not boundIdentity(info,proof.fields)then B.stats.rejected=B.stats.rejected+1;return false end
        B.proofs[f[3]]=nil;return confirm("BNET",proof.id,proof.fields,"whisper")
    end
    if f[2]=="R"then
        local pending=B.pending[routeKey];if pending and pending.nonce==f[3]and A.Clock()<=pending.deadline then return confirm("WHISPER",sender,f,"whisper")end
    end
    B.stats.rejected=B.stats.rejected+1;return false
end
function B.Reconcile()
    for routeKey,row in pairs(B.routes)do if row.transport=="BNET"then
        local info,reason=routeAccount(row)
        if not info then B.routes[routeKey]=nil;trace("route_invalidated",reason)end
    end end
    for routeKey,row in pairs(B.pending)do if row.transport=="BNET"and not freshAccount(row.target)then B.pending[routeKey]=nil end end
end
local function send(job)
    if job.name and blocked(job.name)then return"cancelled","Target is blocked."end
    if job.name then
        local route,reason=jobRoute(job)
        if not route then return "cancelled","Connection changed: "..reason end
        if job.transport=="BNET"then
            local info;info,reason=routeAccount(route)
            if not info then return "error","Game account unavailable: "..reason end
        end
    end
    if job.transport=="BNET"then
        if not job.name then local info,reason=freshAccount(job.target);if not info then return "error","Game account unavailable: "..reason end end
        if not C_BattleNet or type(C_BattleNet.SendGameData)~="function"or type(securecall)~="function"then return "error","Battle.net data API unavailable."end
        trace("attempt","BNET",job.target,job.kind,job.reason,math.max(0,A.Clock()-(job.queuedAt or A.Clock())))
        local ok,result=pcall(securecall,C_BattleNet.SendGameData,job.target,B.PREFIX,job.wire)
        if not ok then return "error","Battle.net send failed."end
        if not A.Safe(result)then return "error","Unreadable send result."end
        local e=Enum and Enum.SendAddonMessageResult or{}
        if result==nil or result==true or result==e.Success then return "ok"end
        if result==e.AddonMessageThrottle or result==e.ChannelThrottle then return "throttle"end
        return "error","Battle.net send rejected."
    end
    if B.failed[key("WHISPER",job.target)]and A.Clock()<B.failed[key("WHISPER",job.target)]then return"error","Target is temporarily unavailable."end
    if job.nonce and(job.kind=="W")then local pending=B.pending[key("WHISPER",job.target)];if not pending or pending.nonce~=job.nonce then return"error","Probe expired."end end
    if job.nonce and job.kind=="V"then local proof=B.proofs[job.nonce];if not proof or A.Clock()>proof.deadline then return"cancelled","Identity proof expired."end end
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function"or A.Call(C_ChatInfo.InChatMessagingLockdown)~=false then return "error","Addon whisper is unavailable."end
    local guard=Z.WhisperGuard
    local safe,why;if guard then safe,why=guard.CanSend(job.target)end
    if not safe then if why=="manual_whisper"then return"pending_route"end;return"error","Whisper reply protection is unavailable."end
    if not guard.Begin(job.target,job.reason)then return"error","Whisper reply protection is full."end
    trace("attempt","WHISPER",job.target,job.kind,job.reason,math.max(0,A.Clock()-(job.queuedAt or A.Clock())))
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,job.prefix or B.PREFIX,job.wire,"WHISPER",job.target)
    local e=Enum and Enum.SendAddonMessageResult or{}
    if ok and A.Safe(result)and e.TargetOffline~=nil and result==e.TargetOffline then B.FailTarget(job.target,"native_target_offline");return"error","Target is offline."end
    if ok and A.Safe(result)and(result==nil or result==true or result==e.Success)then return "ok"end
    guard.Undo(job.target)
    if ok and A.Safe(result)and(result==e.AddonMessageThrottle or result==e.ChannelThrottle)then return "throttle"end
    return "error","Addon whisper send failed."
end
function B.Tick()
    if not B.jobs then return end
    if not enabled()then if #B.jobs>0 or next(B.routes)or next(B.pending)then B.Reset("disabled")end;return end
    local clock=A.Clock();local elapsed=math.max(0,math.min(2,clock-B.lastClock));B.lastClock=clock
    B.tokens=math.min(1,B.tokens+elapsed*2);B.byteTokens=math.min(6144,B.byteTokens+elapsed*6144)
    B.publicTokens=math.min(1,B.publicTokens+elapsed*1.5) -- reserve at least 25% for controls/private transactions
    if clock>=B.nextExpiry then
        B.nextExpiry=clock+1
        for routeKey,p in pairs(B.pending)do
            if clock>p.deadline then B.pending[routeKey]=nil;B.failed[routeKey]=clock+60;B.stats.timeouts=B.stats.timeouts+1;B.stats.lastError="No matching reply received.";trace("timeout",p.transport,p.target,p.reason)
                if p.transport=="WHISPER"then B.FailTarget(p.target,"timeout")end
            elseif p.transport=="BNET"and not p.proof and p.attempts<3 and clock-p.started>=p.attempts*8 then
                if B.Queue(p.transport,p.target,p.transport=="BNET"and"H"or"W",p.nonce)then p.attempts=p.attempts+1 end
            end
        end
        for nonce,p in pairs(B.proofs)do if clock>p.deadline then B.proofs[nonce]=nil end end
        for routeKey,p in pairs(B.routes)do if clock-p.at>300 then B.routes[routeKey]=nil end end
        for routeKey,p in pairs(B.inbound)do if clock-p.at>=60 then B.inbound[routeKey]=nil end end
        for routeKey,untilAt in pairs(B.failed)do if clock>=untilAt then B.failed[routeKey]=nil end end
    end
    if B.Available()and Z.db.autoDiscovery and clock>=B.nextProbe and #B.jobs<16 then
        B.nextProbe=clock+2
        local candidates=Z.CommunityMesh and Z.CommunityMesh.Candidates()or{}
        for _,id in ipairs(candidates)do
            local routeKey=key("BNET",id);local route=B.routes[routeKey]
            if not B.pending[routeKey]and(not B.failed[routeKey]or clock>=B.failed[routeKey])and(not route or clock-route.at>=120)then B.Probe("BNET",id);break end
        end
    end
    if B.test and #B.jobs<8 then
        local id=B.test.ids[B.test.index];if id then B.Probe("BNET",id);B.test.index=B.test.index+1 else B.test=nil end
    end
    if clock<B.nextSend or B.tokens<1 then return end
    local index,best=1,-1;for i,row in ipairs(B.jobs)do local priority=row.priority or(row.private and 100 or 20);if clock>=(row.readyAt or 0)and priority>best then index,best=i,priority end end
    if best<0 then return end
    local job=B.jobs[index];if not job or B.byteTokens<#job.wire or not job.private and B.publicTokens<1 then return end
    if not job.private then B.publicTokens=B.publicTokens-1 end
    B.tokens=B.tokens-1;B.byteTokens=B.byteTokens-#job.wire;local result,error=send(job)
    if result=="pending_route"then job.readyAt=clock+.5;B.tokens=math.min(1,B.tokens+1);B.byteTokens=math.min(6144,B.byteTokens+#job.wire);if not job.private then B.publicTokens=math.min(1,B.publicTokens+1)end;return end
    if result=="throttle"then B.stats.throttled=B.stats.throttled+1;B.nextSend=clock+2;return end
    -- The native API may synchronously deliver an offline event which cancels jobs.
    for i,current in ipairs(B.jobs)do if current==job then table.remove(B.jobs,i);B.bytes=math.max(0,B.bytes-#job.wire);break end end
    complete(job,result=="cancelled"and"error"or result)
    if result=="ok"then B.stats.sent=B.stats.sent+1;trace("sent",job.transport,job.target,job.kind,job.reason,math.max(0,clock-(job.queuedAt or clock)))
    elseif result=="cancelled"then B.stats.cancelled=B.stats.cancelled+1;trace("cancelled",job.transport,job.name or job.target,job.kind,job.reason,error,math.max(0,clock-(job.queuedAt or clock)))
    else B.stats.errors=B.stats.errors+1;B.stats.lastError=error;trace("send_error",job.transport,error,job.name or job.target,job.kind,job.reason,math.max(0,clock-(job.queuedAt or clock)))end
end
function B.CancelPeer(target)
    local ids={}
    for routeKey,p in pairs(B.routes or{})do if L.Identity(p.name)==L.Identity(target)then if p.transport=="BNET"then ids[p.target]=true end;B.routes[routeKey]=nil end end
    for routeKey,p in pairs(B.pending or{})do if ids[p.target]or p.transport=="WHISPER"and L.Identity(p.target)==L.Identity(target)then B.pending[routeKey]=nil end end
    for nonce,p in pairs(B.proofs or{})do if ids[p.id]or L.Identity(p.target)==L.Identity(target)then B.proofs[nonce]=nil end end
    -- Drop only jobs addressed to the blocked player. Public relays to other
    -- neighbours stay queued: the mesh already marked them as sent and purges
    -- the blocked origin's records itself (CommunityMesh.CancelPeer).
    local removed={}
    for i=#(B.jobs or{}),1,-1 do local p=B.jobs[i];local info=p.transport=="BNET"and D.candidates[p.target];local name=info and info.info.characterName or p.target
        if ids[p.target]or L.Identity(name)==L.Identity(target)then B.bytes=math.max(0,B.bytes-#p.wire);table.remove(B.jobs,i);removed[#removed+1]=p end
    end
    -- Report each cancelled job exactly once, after the queue is consistent.
    for _,p in ipairs(removed)do complete(p,"error")end
end
function B.RouteDiagnostics()
    local rows={}
    for _,route in pairs(B.routes or{})do if route.transport=="BNET"then
        local info,reason=routeAccount(route)
        rows[#rows+1]={address=route.target,nativeRealm=info and info.realmName or route.nativeRealm or"",characterRealm=route.realm,world=D.World(route.realm),proof=route.identityProof or"",state=info and"current"or reason}
    end end
    table.sort(rows,function(a,b)return a.address<b.address end);return rows
end
function B.Status()
    local bn,wh=0,0;for _,row in pairs(B.routes or{})do if row.transport=="BNET"then bn=bn+1 else wh=wh+1 end end
    local oldest=0;for _,job in ipairs(B.jobs or{})do oldest=math.max(oldest,A.Clock()-(job.queuedAt or A.Clock()))end
    return{stage="4.0",bnet=bn,whisper=wh,pending=L.Count(B.pending),queued=#(B.jobs or{}),bytes=B.bytes or 0,oldestQueueAge=math.floor(oldest),whisperProtection=Z.WhisperGuard and Z.WhisperGuard.available==true or false,registered=B.registered==true,lastError=B.stats and B.stats.lastError or""}
end
