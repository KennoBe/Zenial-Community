-- Public anti-entropy mesh. Only the explicit public protocol kinds are admitted.
-- Records are statements by peers, never an authenticated private sender.
local Z,L,A,D,B=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.CommunityDirectory,ZenialCommunity.BattleNetTransport
local function createMesh(optional,scheduled)
local protocol=scheduled and "E"or optional and "Q"or"M"
local M={MAX_RECORDS=(optional or scheduled)and 2048 or 16000,MAX_STORE_BYTES=8388608,MAX_PENDING=256,MAX_PENDING_BYTES=65536,MAX_PARTS=8,CHUNK=1400,SCOPE_IDLE=90000}
if scheduled then Z.ScheduledMesh=M elseif optional then Z.QuestMesh=M else Z.CommunityMesh=M end
local function queueData(route,_,payload,private,dedupe,priority,...)
    return B.QueueData(route,protocol,payload,private,dedupe,optional and 5 or priority,...)
end
local PUBLIC=scheduled and{SE=true}or optional and{QH=true}or{P=true,B=true,RX=true,PC=true,PU=true,PX=true,MP=true,LY=true,L2=true,PD=true}
local TRANSIENT={MP=true,LY=true,L2=true,PD=true} -- optional short-lived kinds: never inventoried, never durable, own batch frames
local function enabled()return B.Enabled()and Z.db.autoDiscovery end
local function trace(event,...)if Z.Diagnostics then Z.Diagnostics.Record((scheduled and "scheduledmesh:"or optional and "questmesh:"or"mesh:")..event,...)end end
local function hash(value)
    local n=5381;for i=1,#value do n=(n*48271+value:byte(i))%2147483647 end
    local high,low=math.floor(n/65536),n%65536
    -- Nonlinear final mixing avoids identical rankings shifted around a ring.
    -- All products remain below 2^53 for deterministic Lua-number arithmetic.
    return string.format("%.0f",(low*low*48271+high*high*16807+low*high*31)%2147483647)
end
local function recordHash(value)
    -- Independent forward/reverse fingerprints avoid a single 31-bit inventory
    -- collision suppressing another origin's state. These are not signatures.
    return string.format("%010d%010d",tonumber(hash(value)),tonumber(hash(value:reverse())))
end
local function token(row)
    local suffix=""
    if row.kind=="RX"then local f=Z.Network3.Unpack(row.wire);suffix=f and(f[1]..":"..f[2])or"?"
    elseif row.kind=="PC"or row.kind=="PU"or row.kind=="PX"then local f=Z.Network3.Unpack(row.wire);suffix=f and f[1]or"?"
    elseif row.kind=="PD"then local f=Z.Network3.Unpack(row.wire);suffix=f and f[3]or"?" end -- one record per death, not per sender
    if scheduled then local f=Z.Network3.Unpack(row.wire);suffix=f and f[5]or"?"end
    local family=(row.kind=="PC"or row.kind=="PU"or row.kind=="PX")and"PV"or row.kind
    return L.Identity(row.origin).."/"..family.."/"..suffix
end
-- A PD marker lives 600 s from the time of death (row.at), not from reception.
local function lifetime(row)if scheduled then return 900 end;if optional then return 1200 end;if row.kind=="PD"then return 600 end;return(row.kind=="P"or TRANSIENT[row.kind])and 300 or 86400 end
local function validSession(session,now)
    if not L.Text(session,32)or not session:match("^%d+%.%d+%.%d+$")then return false end
    local epoch=tonumber(session:match("^(%d+)%."))
    return L.Int(epoch,1,4102444800)and epoch<=(now or A.Now())+120
end
local function newer(row,old)
    if not old then return true end
    if row.session==old.session then return row.seq>old.seq end
    local a,b=tonumber(row.session:match("^(%d+)%.")),tonumber(old.session:match("^(%d+)%."))
    if a and b and a~=b then return a>b end
    local x,y=tonumber(row.session:match("^%d+%.(%d+)%.")),tonumber(old.session:match("^%d+%.(%d+)%."))
    if x and y and x~=y then return x>y end
    return row.at>old.at
end
local function validate(row,now)
    now=now or A.Now()
    if type(row)~="table"or not PUBLIC[row.kind]or not L.Text(row.origin,49)or not L.Identity(row.origin)or not row.origin:find(" ",1,true)
        or not validSession(row.session,now)or not L.Int(row.seq,0,2147483646)
        or not L.Int(row.at,1,4102444800)or row.at>now+120 or now-row.at>lifetime(row)
        or not L.Text(row.realm,64)or D.World(row.realm)~=D.World(Z.me.realm)or not D.RegionMatches(row.region)or row.project~=D.Project()
        or type(row.wire)~="string"or#row.wire>L.MAX_BYTES then return false end
    if scheduled then local e=Z.ScheduledGroups and Z.ScheduledGroups.DecodeRecord(row.wire);return e and e.session==row.session and e.at==row.at or false end
    if optional then local q=Z.QuestHelper.DecodeRecord(row.wire);return q and q.session==row.session and q.at==row.at or false end
    local f=Z.Network3.Unpack(row.wire)
    if row.kind=="P"then
        if not f or#f~=17 or#row.wire>238 or f[1]~="P"or f[2]~="3"or f[3]~=row.session or f[5]~=Z.me.faction or D.World(f[4])~=D.World(row.realm)
            or not L.Text(f[6],16,true)or not L.Text(f[8],16,true)or not({AVAILABLE=true,AFK=true,BUSY=true,GROUP=true})[f[9]]
            or not L.Text(f[10],48,true)or f[10]~=""and not f[10]:match("^[%d,]+$")or(f[16]~="all"and f[16]~="zone")then return false end
        for _,i in ipairs({7,11,12,13,14,15,17})do
            local max=i==7 and 100 or i==15 and 1 or(i==14 or i==17)and 1000000 or 2147483646
            if not L.Int(tonumber(f[i]),0,max)then return false end
        end
        return true
    end
    if row.kind=="MP"then
        local position=Z.Network3.DecodeMapPosition(row.wire)
        return position and position.session==row.session and position.at==row.at or false
    end
    if row.kind=="LY"then
        local layer=Z.CommunityLayer and Z.CommunityLayer.Decode(row.wire)
        return layer and layer.session==row.session and layer.at==row.at or false
    end
    if row.kind=="L2"then
        local layer=Z.CommunityLayer and Z.CommunityLayer.DecodeV2(row.wire)
        return layer and layer.session==row.session and layer.at==row.at or false
    end
    if row.kind=="PD"then
        local death=Z.Network3.DecodePvPDeath(row.wire)
        return death and death.session==row.session and death.at==row.at or false
    end
    if row.kind=="B"then
        local s=L.Decode(row.wire,A.Now());return s and s.kind=="S3"and s.generation==row.session and s.faction==Z.me.faction
            and s.community==""and s.class==""and s.classFile==""and s.level==0 and s.guild==""and s.guid==""and s.roles==""
            and s.note==""and s.professionNote==""and#s.professions==0 and#s.linkAlts==0
    end
    if row.kind=="RX"then return f and#f==3 and({G=true,Q=true,M=true})[f[1]]and L.Text(f[2],32)and L.Int(tonumber(f[3]),0,2147483646)end
    if row.kind=="PX"then return f and#f==2 and L.Text(f[1],32)and L.Int(tonumber(f[2]),0,2147483646)end
    return f and#f==10 and L.Text(f[1],32)and f[1]:match("^[%d%.]+$")and L.Int(tonumber(f[2]),1,2147483646)
        and L.Int(tonumber(f[3]),1,4102444800)and L.Int(tonumber(f[4]),1,4102444800)and tonumber(f[3])<=tonumber(f[4])
        and L.Int(tonumber(f[5]),0,1000000)and L.Text(f[6],64,true)and L.Text(f[7],64,true)
        and L.Int(tonumber(f[8]),0,1)and L.Int(tonumber(f[9]),0,10000)and L.Int(tonumber(f[10]),0,10000)
end
-- Presence/position/layer rows live for minutes; they are relayed from memory
-- only and never written to the account-wide SavedVariables store.
local function durable(row)return row.kind~="P"and not TRANSIENT[row.kind]end
local function persist()
    if optional or scheduled or not M.scope or not M.region then return end -- No persistent public cache under an unknown region.
    D.config.stores[M.scope]=M.durable;D.config.storeUsed[M.scope]=A.Now()
end
function M.Initialize()
    if optional and Z.QuestHelper and Z.QuestHelper.quests then Z.QuestHelper.publishedSignature=nil;Z.QuestHelper.nextRefresh=0 end
    M.records,M.durable,M.index,M.keys,M.pending,M.assemblies,M.byOrigin,M.sync,M.ignored={},{},{},{},{},{},{},{},{}
    M.bytes,M.pendingBytes,M.assemblyBytes=0,0,0;M.pendingCount=0;M.nextBatch=A.Clock()+2;M.nextSync=A.Clock()+10;M.nextExpire=0;M.groupTurns={};M.cursors={};M.replay={}
    M.stats={published=0,received=0,forwarded=0,duplicates=0,rejected=0,dropped=0,reconciled=0}
    M.region=D.Region()
    M.scope=tostring(M.region or 0)..":"..tostring(D.Project()or 0)..":"..tostring(D.World(Z.me.realm))..":"..Z.me.faction
    local raw=not optional and not scheduled and M.region and D.config.stores[M.scope]or nil
    D.config.stores["0:"..tostring(D.Project()or 0)..":"..tostring(D.World(Z.me.realm))..":"..Z.me.faction]=nil
    local now=A.Now();if A.PublicTable(raw)then for _,row in pairs(raw)do
        if M.bytes>=M.MAX_STORE_BYTES or#M.keys>=M.MAX_RECORDS then break end
        if A.PublicTable(row)and A.Safe(row.origin,row.session,row.seq,row.at,row.kind,row.wire,row.realm,row.region,row.project)and durable(row)and validate(row,now)then
            local id=token(row);if not M.records[id]and M.bytes+#row.wire<=M.MAX_STORE_BYTES then
                M.records[id]=row;M.durable[id]=row;M.bytes=M.bytes+#row.wire;M.keys[#M.keys+1]=id;local h=recordHash(id);M.index[h]=M.index[h]or{};M.index[h][id]=true
                local origin=L.Identity(row.origin);M.byOrigin[origin]=M.byOrigin[origin]or{};M.byOrigin[origin][id]=true
            end
        end
    end end
    -- Keep account-level storage bounded across many characters/worlds: a scope
    -- idle longer than the longest record lifetime holds only expired rows, and
    -- at most eight scopes survive, least recently used first out. Older saves
    -- without a use time start their idle clock now.
    local used=D.config.storeUsed or{};D.config.storeUsed=used;for scope in pairs(used)do if not D.config.stores[scope]then used[scope]=nil end end
    local scopes={};for scope in pairs(D.config.stores)do
        if not L.Int(used[scope],1,4102444800)then used[scope]=now end
        if scope~=M.scope and now-used[scope]>M.SCOPE_IDLE then D.config.stores[scope]=nil;used[scope]=nil else scopes[#scopes+1]=scope end
    end
    table.sort(scopes,function(a,b)if a==b then return false end;if a==M.scope or b==M.scope then return a==M.scope end;if used[a]~=used[b]then return used[a]>used[b]end;return a<b end)
    for i=#scopes,9,-1 do D.config.stores[scopes[i]]=nil;used[scopes[i]]=nil end
    persist()
end
function M.Candidates()
    if M.candidateSource==D.candidates and M.candidateAssignment==table.concat(D.config.assignment,",")and A.Clock()<(M.candidateUntil or 0)then return M.candidateList end
    local pool,chosen={},{}
    for id,c in pairs(D.candidates)do for group in pairs(c.groups)do pool[group]=pool[group]or{};pool[group][#pool[group]+1]=id end end
    for _,list in pairs(pool)do
        table.sort(list,function(a,b)return tonumber(hash(tostring(D.config.seed)..":"..a))<tonumber(hash(tostring(D.config.seed)..":"..b))end)
        local picked=0
        for _,id in ipairs(list)do local failed=B.failed["BNET:"..id]
            if not failed or A.Clock()>=failed then chosen[id]=true;picked=picked+1;if picked>=8 then break end end
        end
    end
    local result={};for id in pairs(chosen)do result[#result+1]=id end;table.sort(result)
    M.candidateSource=D.candidates;M.candidateAssignment=table.concat(D.config.assignment,",");M.candidateUntil=A.Clock()+5;M.candidateList=result;return result
end
local function pools()
    if M.poolSource==D.candidates and A.Clock()<(M.poolUntil or 0)then return M.poolList end
    local result={}
    for _,route in pairs(B.routes or{})do if route.transport=="BNET"and(not optional or route.questHelper)and(not scheduled or route.scheduledGroups)then
        local c=D.candidates[route.target];if c then for group in pairs(c.groups)do result[group]=result[group]or{};result[group][#result[group]+1]=route end end
    end end
    for _,list in pairs(result)do
        for _,route in ipairs(list)do route.meshScore=route.meshScore or tonumber(hash("pool:"..D.config.seed..":"..route.target))end
        table.sort(list,function(a,b)return a.meshScore<b.meshScore end)
        while#list>8 do table.remove(list)end
    end
    M.poolSource=D.candidates;M.poolUntil=A.Clock()+2;M.poolList=result;return result
end
local function enqueue(id,source)
    local row=M.records[id];if not row then return false end
    local priority=optional and 5 or TRANSIENT[row.kind]and 5 or row.kind=="P"and 70 or row.kind=="B"and row.seq<=2 and 10 or 80
    local old=M.pending[id]
    if old then M.pendingBytes=M.pendingBytes-#old.row.wire;M.pending[id]=nil;M.pendingCount=M.pendingCount-1 end
    while M.pendingCount>=M.MAX_PENDING or M.pendingBytes+#row.wire>M.MAX_PENDING_BYTES do
        local discard,lowest
        for pendingID,p in pairs(M.pending)do
            if p.priority<=priority and(not lowest or p.priority<lowest.priority or p.priority==lowest.priority and p.row.at<lowest.row.at)then discard,lowest=pendingID,p end
        end
        if not discard then break end
        M.pending[discard]=nil;M.pendingCount=M.pendingCount-1;M.pendingBytes=M.pendingBytes-#lowest.row.wire;M.stats.dropped=M.stats.dropped+1
    end
    if M.pendingCount>=M.MAX_PENDING or M.pendingBytes+#row.wire>M.MAX_PENDING_BYTES then M.stats.dropped=M.stats.dropped+1;return false end
    M.pending[id]={row=row,source=source,sent={},parts={},priority=priority};M.pendingCount=M.pendingCount+1;M.pendingBytes=M.pendingBytes+#row.wire;return true
end
local function removePending(id)
    local p=M.pending[id];if p then M.pendingBytes=M.pendingBytes-#p.row.wire;M.pendingCount=M.pendingCount-1;M.pending[id]=nil end
end
-- Removes one record from every structure that references it (except M.keys).
local function drop(id,row)
    M.records[id]=nil;M.durable[id]=nil;M.bytes=M.bytes-#row.wire;removePending(id)
    local h=recordHash(id);local set=M.index[h];if set then set[id]=nil;if not next(set)then M.index[h]=nil end end
    local origin=L.Identity(row.origin);set=M.byOrigin[origin];if set then set[id]=nil;if not next(set)then M.byOrigin[origin]=nil end end
end
-- Single ordered pass with a write pointer; table.remove per hit is quadratic.
local function compact(remove)
    local keys,w=M.keys or{},0
    for i=1,#keys do local id=keys[i];local row=M.records[id]
        if row and not remove(id,row)then w=w+1;keys[w]=id elseif row then drop(id,row)end
    end
    for i=#keys,w+1,-1 do keys[i]=nil end
end
local function apply(row)
    if L.Identity(row.origin)==L.Identity(Z.me.target)then return true end
    if scheduled then if Z.ScheduledGroups then Z.ScheduledGroups.Invalidate()end;if Z.MarkDirty then Z.MarkDirty("scheduled")end;return true end
    if optional then if Z.MarkDirty then Z.MarkDirty("questHelper")end;return true end
    local N=Z.Network3;N.meshContext={at=row.at,origin=row.origin,session=row.session,seq=row.seq}
    local ok,changed=N.ProcessComplete(row.origin,"PUBLIC",row.kind,row.wire)
    N.meshContext=nil
    if ok and changed~=false and Z.MarkDirty then Z.MarkDirty(row.kind)end
    return ok
end
function M.Accept(row,source,own)
    if not enabled()or not validate(row)then M.stats.rejected=M.stats.rejected+1;return false end
    if scheduled then Z.ScheduledGroups.CacheRecord(row)end
    if not own and Z.Network3.PublicSessionAllowed and not Z.Network3.PublicSessionAllowed(row.origin,row.session)then M.stats.rejected=M.stats.rejected+1;return false end
    local key=L.ScopeKey(row.origin,Z.me.realm,Z.me.faction)
    if key==Z.me.key and not own then return false end
    if key and Z.db.blocked[key]then if L.Count(M.ignored)<M.MAX_RECORDS then M.ignored[recordHash(token(row))]=key end;return false end
    local id=token(row);local old=M.records[id]
    -- A stored record that has outlived its lifetime no longer outranks a valid one: it only waits for the next
    -- prune. (Needed when confirmed participants carry on a scheduled event after its organizer's last own
    -- announcement has run out; their records rank below every real session of the organizer.)
    if not newer(row,old)and not(old and A.Now()-old.at>lifetime(old))then M.stats.duplicates=M.stats.duplicates+1;return true end
    if row.kind=="PD"and not old then
        -- At most eight living markers per origin.
        local live,now=0,A.Now()
        for other in pairs(M.byOrigin[L.Identity(row.origin)]or{})do local r=M.records[other];if r and r.kind=="PD"and now-r.at<=lifetime(r)then live=live+1 end end
        if live>=8 then M.stats.rejected=M.stats.rejected+1;return false end
    end
    if not old and#M.keys>=M.MAX_RECORDS or M.bytes-(old and#old.wire or 0)+#row.wire>M.MAX_STORE_BYTES then M.stats.dropped=M.stats.dropped+1;return false end
    if not old then
        M.keys[#M.keys+1]=id;local h=recordHash(id);M.index[h]=M.index[h]or{};M.index[h][id]=true
        local origin=L.Identity(row.origin);M.byOrigin[origin]=M.byOrigin[origin]or{};M.byOrigin[origin][id]=true
    end
    M.records[id]=row;M.bytes=M.bytes-(old and#old.wire or 0)+#row.wire;M.durable[id]=durable(row)and row or nil
    if not own then apply(row);M.stats.received=M.stats.received+1 end
    enqueue(id,source);persist();return true
end
-- Hands in a record on behalf of another origin, as if it had arrived from a neighbour: it is validated, ranked
-- and forwarded like any received record. Used for scheduled events carried on by their confirmed participants.
function M.Relay(origin,session,seq,at,kind,wire)
    if not enabled()or not PUBLIC[kind]then return false end
    return M.Accept({origin=origin,session=session,seq=seq,at=at,kind=kind,wire=wire,realm=Z.me.realm,region=D.Region()or 0,project=D.Project()},nil,false)
end
function M.Publish(kind,wire)
    if not enabled()or not PUBLIC[kind]then return nil end
    D.config.serial=math.min(2147483646,D.config.serial+1)
    local row={origin=Z.me.target,session=Z.session,seq=D.config.serial,at=A.Now(),kind=kind,wire=wire,realm=Z.me.realm,region=D.Region()or 0,project=D.Project()}
    if scheduled then local e=Z.ScheduledGroups.DecodeRecord(wire);if not e then return nil end;row.at=e.at end
    if optional then local q=Z.QuestHelper.DecodeRecord(wire);if not q then return nil end;row.at=q.at end
    if kind=="MP"then
        local position=Z.Network3.DecodeMapPosition(wire);if not position then return nil end
        row.at=position.at -- Keep the actual sample time, including at a second boundary.
    end
    if kind=="LY"then
        local layer=Z.CommunityLayer and Z.CommunityLayer.Decode(wire);if not layer then return nil end
        row.at=layer.at
    end
    if kind=="L2"then
        local layer=Z.CommunityLayer and Z.CommunityLayer.DecodeV2(wire);if not layer then return nil end
        row.at=layer.at
    end
    if kind=="PD"then
        local death=Z.Network3.DecodePvPDeath(wire);if not death then return nil end
        row.at=death.at -- The marker expires 600 s after the death itself.
    end
    if M.Accept(row,nil,true)then M.stats.published=M.stats.published+1;return"mesh."..row.seq end
end
-- (Re)starts the direct PD delivery for one neighbour; any earlier state of that route is replaced.
function M.ReplayTo(route)
    if M.replay and route and route.transport=="BNET"and not M.optionalMesh then M.replay[route.target]={due=A.Clock()+3,round=1}end
end
function M.OnConnected(route)
    if not enabled()then return end
    if scheduled then
        if route.transport=="BNET"then queueData(route,protocol,"H1",false,"scheduled-hello:"..route.target,5)end
        return
    end
    if optional then
        if route.transport=="BNET"then queueData(route,protocol,"H1",false,"quest-hello:"..route.target,5)end
        return
    end
    M.ReplayTo(route)
    local hasPresence,hasBundle=false,false
    for id,row in pairs(M.records)do if row.origin==Z.me.target and row.session==Z.session then
        if row.kind=="P"then hasPresence=true elseif row.kind=="B"then hasBundle=true end
    end end
    if not hasPresence then Z.Network3.nextPresence=0 end
    if not hasBundle then Z.Network3.pendingPublish=true;Z.Network3.publishDue=math.min(Z.Network3.publishDue or A.Clock(),A.Clock()+2)end
    M.cursors[route.target]=1;M.nextSync=math.min(M.nextSync or A.Clock(),A.Clock()+2)
    if route.transport=="BNET"and L.Count(M.sync)<4 then M.RequestSync(route,1)end
end
local function recordFrame(row,part)
    return Z.Network3.Pack({"U",row.origin,row.session,row.seq,row.at,row.kind,row.realm,row.region,row.project,part,math.ceil(#row.wire/M.CHUNK),row.wire:sub((part-1)*M.CHUNK+1,part*M.CHUNK)})
end
local function batch(frames)local out={};for _,frame in ipairs(frames)do out[#out+1]=#frame..":"..frame end;return table.concat(out)end
local function unbatch(payload)
    local frames,pos={},1
    while pos<=#payload do
        local first,last,length=payload:find("^(%d+):",pos)
        if not first then return nil end;length=tonumber(length)
        if not L.Int(length,1,3700)or last+length>#payload or#frames>=32 then return nil end
        frames[#frames+1]=payload:sub(last+1,last+length);pos=last+length+1
    end
    return frames
end
function M.RequestSync(route,cursor)
    if not queueData(route,protocol,batch({Z.Network3.Pack({"S",cursor})}),false,"pull:"..route.target,12)then return false end
    M.sync[route.target]={cursor=cursor,at=A.Clock()};return true
end
local function haveVersion(h,version)
    if M.ignored[h]then if Z.db.blocked[M.ignored[h]]then return true else M.ignored[h]=nil end end
    for id in pairs(M.index[h]or{})do local old=M.records[id];if old and not newer(version,old)then return true end end
    return false
end
local function replyRecords(route,requested)
    local frames,size,signature={},0,{}
    local function send()
        if#frames==0 then return true end
        local ok=queueData(route,protocol,batch(frames),false,"reply:"..route.target..":"..hash(table.concat(signature,",")),20)
        frames,size,signature={},0,{};return ok
    end
    for _,id in ipairs(requested)do local row=M.records[id]
        if not TRANSIENT[row.kind]then for part=1,math.ceil(#row.wire/M.CHUNK)do
            local frame=recordFrame(row,part);local bytes=#frame+#tostring(#frame)+1
            if size+bytes>3700 and not send()then return end
            if bytes<=3700 then frames[#frames+1]=frame;signature[#signature+1]=id..":"..row.seq..":"..part;size=size+bytes end
        end end
    end
    send()
end
function M.Receive(route,payload)
    if not enabled()or route.transport~="BNET"or type(payload)~="string"or#payload>3796 then return false end
    if scheduled and(payload=="H1"or payload=="A1")then
        local first=not route.scheduledGroups;route.scheduledGroups=true;M.poolUntil=0
        if payload=="H1"then queueData(route,protocol,"A1",false,"scheduled-ack:"..route.target,5)end
        if first then if L.Count(M.sync)<4 then M.RequestSync(route,1)end;if Z.ScheduledGroups then Z.ScheduledGroups.OnPeerOnline(route.name,route.session,true)end end
        return true
    end
    if scheduled and not route.scheduledGroups then return false end
    if optional and(payload=="H1"or payload=="A1")then
        local first=not route.questHelper;route.questHelper=true;M.poolUntil=0
        if payload=="H1"then queueData(route,protocol,"A1",false,"quest-ack:"..route.target,5)end
        if first and L.Count(M.sync)<4 then M.RequestSync(route,1)end
        return true
    end
    if optional and not route.questHelper then return false end
    local frames=unbatch(payload);if not frames then M.stats.rejected=M.stats.rejected+1;return false end
    for _,wire in ipairs(frames)do
        local f=Z.Network3.Unpack(wire)
        if not f then return false end
        if f[1]=="U"and#f==12 then
            local row={origin=f[2],session=f[3],seq=tonumber(f[4]),at=tonumber(f[5]),kind=f[6],realm=f[7],region=tonumber(f[8]),project=tonumber(f[9])}
            local part,total=tonumber(f[10]),tonumber(f[11]);local chunk=f[12]
            if not PUBLIC[row.kind]or not L.Text(row.origin,49)or not L.Identity(row.origin)or not validSession(row.session)or not L.Int(row.seq,0,2147483646)
                or not L.Int(part,1,M.MAX_PARTS)or not L.Int(total,part,M.MAX_PARTS)or#chunk>M.CHUNK then return false end
            local assemblyKey=row.origin..":"..row.session..":"..row.seq..":"..row.kind
            local p=M.assemblies[assemblyKey]
            if not p then
                if L.Count(M.assemblies)>=256 then M.stats.dropped=M.stats.dropped+1;return false end
                p={row=row,total=total,chunks={},size=0,at=A.Clock(),header=table.concat(f,"\t",2,9)};M.assemblies[assemblyKey]=p
            end
            if p.header~=table.concat(f,"\t",2,9)or p.total~=total or p.chunks[part]and p.chunks[part]~=chunk then return false end
            if not p.chunks[part]then
                if M.assemblyBytes+#chunk>262144 or p.size+#chunk>L.MAX_BYTES then return false end
                p.chunks[part]=chunk;p.size=p.size+#chunk;M.assemblyBytes=M.assemblyBytes+#chunk
            end
            local complete=true;for i=1,total do if not p.chunks[i]then complete=false;break end end
            if complete then
                M.assemblies[assemblyKey]=nil;M.assemblyBytes=M.assemblyBytes-p.size;row.wire=table.concat(p.chunks)
                if M.Accept(row,route.target,false)and row.kind=="P"then
                    -- Presence may arrive after a bundle during recovery. Apply
                    -- cached dependent public records without renewing their age.
                    for id in pairs(M.byOrigin[L.Identity(row.origin)]or{})do local r=M.records[id];if r and r.session==row.session and r.kind~="P"then apply(r)end end
                end
            end
        elseif f[1]=="S"and#f==2 then
            local cursor=tonumber(f[2]);if not L.Int(cursor,1,M.MAX_RECORDS+1)then return false end
            local last=math.min(#M.keys,cursor+15);local values={"J",cursor,last<#M.keys and last+1 or 0}
            for i=cursor,last do local id=M.keys[i];local row=M.records[id];if not TRANSIENT[row.kind]then values[#values+1]=recordHash(id);values[#values+1]=row.session;values[#values+1]=row.seq;values[#values+1]=row.at end end
            queueData(route,protocol,batch({Z.Network3.Pack(values)}),false,"page:"..route.target,10)
        elseif(f[1]=="I"and(#f-1)%4==0)or(f[1]=="J"and(#f-3)%4==0)then
            local start=2;local sync
            if f[1]=="J"then
                sync=M.sync[route.target];if not sync or sync.cursor~=tonumber(f[2])or not L.Int(tonumber(f[3]),0,M.MAX_RECORDS+1)then return false end
                sync.next=tonumber(f[3]);sync.missing={};sync.at=A.Clock();start=4
            end
            local request={"Q"}
            for i=start,#f,4 do
                local h,session,seq,at=f[i],f[i+1],tonumber(f[i+2]),tonumber(f[i+3]);if not h:match("^%d+$")or not validSession(session)or not L.Int(seq,0,2147483646)or not L.Int(at,1,4102444800)then return false end
                local version={session=session,seq=seq,at=at}
                if not haveVersion(h,version)then request[#request+1]=h;if sync then sync.missing[h]=version end end
            end
            if#request>1 then queueData(route,protocol,batch({Z.Network3.Pack(request)}),false,"request:"..route.target,15)end
        elseif f[1]=="Q"and#f<=80 then
            local requested={}
            for i=2,#f do if not f[i]:match("^%d+$")then return false end;for id in pairs(M.index[f[i]]or{})do
                requested[#requested+1]=id
                M.stats.reconciled=M.stats.reconciled+1
            end end
            replyRecords(route,requested)
        else return false end
    end
    return true
end
local function flush(group,list)
    if#list==0 then return end
    M.groupTurns[group]=(M.groupTurns[group]or 0)+1;local route=list[(M.groupTurns[group]-1)%#list+1];local frames,selected,size={},{},0
    local ordered={};for id,p in pairs(M.pending)do ordered[#ordered+1]={id=id,p=p}end
    table.sort(ordered,function(a,b)return a.p.priority>b.p.priority or a.p.priority==b.p.priority and a.p.row.at<b.p.row.at end)
    local priority=10;local optionalBatch
    -- Older clients reject unknown records and stop reading their frame. Keep
    -- optional positions in separate frames, outside their inventory sync too.
    for _,entry in ipairs(ordered)do local id,p=entry.id,entry.p
        local optional=TRANSIENT[p.row.kind]and p.row.kind or""
        if p.source~=route.target and not p.sent[route.target]and(optionalBatch==nil or optionalBatch==optional)then
            local part=(p.parts[route.target]or 0)+1;p.frames=p.frames or{};local frame=p.frames[part]or recordFrame(p.row,part);p.frames[part]=frame;local bytes=#frame+#tostring(#frame)+1
            if size+bytes<=3700 then optionalBatch=optional;frames[#frames+1]=frame;selected[#selected+1]={id=id,p=p,part=part};size=size+bytes;priority=math.max(priority,p.priority)end
            if#frames>=24 then break end
        end
    end
    local function result(status)
        if status=="superseded"then return end
        for _,entry in ipairs(selected)do local row=entry.p.row
            if row.origin==Z.me.target and Z.PvPHelp then Z.PvPHelp.BroadcastResult(row.kind,row.wire,status=="ok"and"sent"or"error")end
        end
    end
    if#frames==0 or not queueData(route,protocol,batch(frames),false,nil,priority,result)then return end
    M.stats.forwarded=M.stats.forwarded+#frames
    for _,entry in ipairs(selected)do local p=entry.p;p.parts[route.target]=entry.part;if entry.part>=math.ceil(#p.row.wire/M.CHUNK)then p.sent[route.target]=true end end
end
function M.Tick()
    local region=D.Region()
    if M.region~=region then
        if M.region and region then B.Reset("region_metadata_changed")end
        M.Initialize()
        Z.Network3.nextPresence=0;Z.Network3.pendingPublish=true;Z.Network3.publishDue=A.Clock()+2
    end
    if not M.records or not enabled()then return end
    local clock=A.Clock()
    for id,s in pairs(M.sync)do
        local route=B.routes["BNET:"..id]
        if not route then M.sync[id]=nil
        else
            local complete=s.missing~=nil
            for h,version in pairs(s.missing or{})do if not haveVersion(h,version)then complete=false;break end end
            if complete then
                if s.next==0 then M.sync[id]=nil else M.RequestSync(route,s.next)end
            elseif clock-s.at>=8 then M.RequestSync(route,s.cursor)end
        end
    end
    if clock>=M.nextExpire then
        M.nextExpire=clock+10
        for id,p in pairs(M.assemblies)do if clock-p.at>45 then M.assemblies[id]=nil;M.assemblyBytes=M.assemblyBytes-p.size end end
        local now=A.Now();compact(function(_,row)return now-row.at>lifetime(row)end)
    end
    -- Late join: PD markers are never inventoried (older clients cannot read them). Each (re)connected neighbour instead gets the
    -- still living markers directly, in frames that contain only PD, twice (a few seconds after the connect and again later, in case
    -- the first batch arrived before the neighbour was ready). The pending queue is never touched; duplicates are rejected by seq.
    if not optional and not scheduled then
        for target,r in pairs(M.replay)do if clock>=r.due then
            local route=B.routes["BNET:"..target]
            if not route then M.replay[target]=nil
            else
                local live={};local now=A.Now()
                for _,row in pairs(M.records)do if row.kind=="PD"and now-row.at<=lifetime(row)then live[#live+1]=row end end
                table.sort(live,function(x,y)if x.at~=y.at then return x.at>y.at end;return x.seq>y.seq end)
                local frames,size,n={},0,0
                local function send()
                    if#frames==0 then return end
                    n=n+1;queueData(route,protocol,batch(frames),false,"pd-replay:"..target..":"..n,15);frames,size={},0
                end
                for i=1,math.min(#live,16)do
                    local frame=recordFrame(live[i],1);local bytes=#frame+#tostring(#frame)+1
                    if#live[i].wire<=M.CHUNK and bytes<=3700 then
                        if size+bytes>3700 or#frames>=24 then send()end
                        frames[#frames+1]=frame;size=size+bytes
                    end
                end
                send()
                if r.round>=2 then M.replay[target]=nil else r.round=r.round+1;r.due=clock+12 end
            end
        end end
    end
    local groups=pools()
    if clock>=M.nextBatch then
        M.nextBatch=clock+2
        for group,list in pairs(groups)do flush(group,list)end
        for id,p in pairs(M.pending)do
            local complete=true;local any=false
            for _,list in pairs(groups)do
                local n,required=0,math.min(p.row.kind=="P"and 3 or 4,#list);for _,route in ipairs(list)do if route.target==p.source or p.sent[route.target]then n=n+1 end end
                if n<required then complete=false end;any=true
            end
            if complete and any then removePending(id)end
        end
    end
    if clock>=M.nextSync then
        M.nextSync=clock+((optional or scheduled)and 30 or 5)
        for _,list in pairs(groups)do if#list>0 then
            local route=list[(math.floor(clock/((optional or scheduled)and 30 or 5)))%#list+1];local cursor=M.cursors[route.target]or 1;local values={"I"};local count=0
            while count<16 and#M.keys>0 do
                if cursor>#M.keys then cursor=1;break end
                local id=M.keys[cursor];local r=M.records[id];if not TRANSIENT[r.kind]then values[#values+1]=recordHash(id);values[#values+1]=r.session;values[#values+1]=r.seq;values[#values+1]=r.at end;count=count+1;cursor=cursor+1
            end
            -- An entire page may contain only transient positions. Advance over
            -- it even though no inventory frame is needed, or later public data
            -- would never be advertised to this neighbour.
            if#values==1 or queueData(route,protocol,batch({Z.Network3.Pack(values)}),false,"inventory:"..route.target,10)then M.cursors[route.target]=cursor end
        end end
    end
end
function M.CancelPeer(target)
    local identity=L.Identity(target)
    compact(function(id,row)if L.Identity(row.origin)~=identity then return false end;M.ignored[recordHash(id)]=L.ScopeKey(target,Z.me.realm,Z.me.faction);return true end)
    for id,p in pairs(M.assemblies or{})do if L.Identity(p.row.origin)==identity then M.assemblies[id]=nil;M.assemblyBytes=M.assemblyBytes-p.size end end
end
function M.ConfirmSession(target,session)
    local origin=L.Identity(target);if not origin then return end
    local conflicting=false
    for id in pairs(M.byOrigin[origin]or{})do if M.records[id].session~=session then conflicting=true;break end end
    if conflicting then compact(function(_,row)return L.Identity(row.origin)==origin and row.session~=session end)end
    if M.byOrigin[origin]and not next(M.byOrigin[origin])then M.byOrigin[origin]=nil end
    for id,p in pairs(M.assemblies or{})do if L.Identity(p.row.origin)==origin and p.row.session~=session then M.assemblies[id]=nil;M.assemblyBytes=M.assemblyBytes-p.size end end
end
function M.PrivacyChanged()
    if M.records then local me=L.Identity(Z.me.target);compact(function(_,row)return L.Identity(row.origin)==me end)end
    M.pending={};M.pendingBytes=0;M.pendingCount=0
end
function M.Status()return{records=#(M.keys or{}),bytes=M.bytes or 0,pending=M.pendingCount or 0,pendingBytes=M.pendingBytes or 0,assemblies=L.Count(M.assemblies),assemblyBytes=M.assemblyBytes or 0}end
return M
end
createMesh(false)
createMesh(true)
createMesh(false,true)
return Z.CommunityMesh
