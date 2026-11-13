-- Optional aggregate party updates use a separate authenticated message.
-- Existing scheduled-event and application packets remain compatible.
local Z,L,A,S=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.ScheduledGroups
local P={cache={},queries={},receivers={},sequence=0};Z.ActivityParty=P
function P.Initialize()P.cache,P.queries,P.receivers={},{},{};P.sequence=0;P.nextTick=0;P.liveBaseline=nil end
local function token(r)return r.kind..':'..r.owner..':'..r.id end
local function route(key)
    local c=Z.db.contacts[key];local p=Z.db.peers[key];local r=c and Z.BattleNetTransport.Route(c.target)
    if not Z.db.consent or not Z.db.autoDiscovery or not Z.identityReady or Z.offlineOnly or Z.db.blocked[key]or not r or not p or p.verifiedSession~=r.session or not Z.IsOnline(key)then return end
    return r,c
end
local function current(kind,owner,id)
    if kind=='EVENT'then return S.Get(owner,id)end
    local e=owner==Z.me.key and(kind=='LIVE'and Z.db.lfg[1]or Z.db.quest)
        or kind=='LIVE'and Z.FindForeignGroup(owner,id)or kind=='QUEST'and Z.FindForeignQuest(owner,id)
    if e and e.id==id then return e end
end
function P.Native(r)
    local e=r.data;local g=A.GroupState();local used=r.kind=='EVENT'and S.Counts(e)or nil
    if used then
        local units={};if A.Call(IsInRaid)==true then for i=1,g.total do units[#units+1]='raid'..i end
        else units[1]='player';for i=1,g.total-1 do units[#units+1]='party'..i end end
        for _,unit in ipairs(units)do
            local key,name,realm=A.UnitIdentity(unit);key=name and L.ScopeKey(name,realm,Z.me.faction)or key
            local p=key and e.participants and e.participants[key]
            local booked=key==Z.me.key and e.organizerRole or p and p.state=='CONFIRMED'and p.role
            local role=L.Role(A.Call(UnitGroupRolesAssigned,unit))or booked
            if L.Role(role)and role~=booked then
                if L.Role(booked)then used[booked]=math.max(0,used[booked]-1)end
                used[role]=used[role]+1
            end
        end
        for role in pairs(used)do used[role]=math.min(e.roleSlots[role],used[role])end
    end
    return {total=g.total,used=used}
end
function P.Info(r)
    if not r or not r.data then return end
    if r.own then return P.Native(r)end
    P.Query(r)
    local info=P.cache[token(r)];local connected=route(r.owner)
    if info and connected and info.session==connected.session and A.Clock()-info.at<120 and(r.kind~='EVENT'or info.revision==r.data.revision)then return info end
end
function P.Query(r)
    if r.own then return end
    local connected,c=route(r.owner);if not connected then return end
    local tok=token(r);local now=A.Clock()
    for key,q in pairs(P.queries)do if now-q.at>180 then P.queries[key]=nil;P.cache[key]=nil end end
    local previous=P.queries[tok];if previous and previous.session==connected.session and now-previous.at<30 then return end
    if not previous and L.Count(P.queries)>=512 then return end
    if Z.Network3.QueueDirect(c.target,'SP',Z.Network3.Pack({'1',Z.session,connected.session,'Q',r.kind,r.id}),40,'PARTYQUERY:'..tok)then P.queries[tok]={at=now,session=connected.session}end
end
local function send(key,kind,id)
    local connected,c=route(key);local e=current(kind,Z.me.key,id)
    if not connected or not Z.db.visible or not e or kind=='EVENT'and e.status~='OPEN'then return end
    local info=P.Native({kind=kind,data=e});P.sequence=P.sequence+1
    local u=info.used or{};local revision=kind=='EVENT'and e.revision or Z.db.rev
    return Z.Network3.QueueDirect(c.target,'SP',Z.Network3.Pack({'1',Z.session,connected.session,'D',kind,id,revision,P.sequence,info.total,u.TANK or 0,u.HEALER or 0,u.DAMAGER or 0}),40,'PARTYDATA:'..kind..':'..key..':'..id)
end
function P.Receive(sender,wire)
    if Z.Network3.meshContext or type(wire)~='string'or #wire>512 then return false end
    local key=Z.ResolvePeerKey(sender);local connected=key and route(key);local f=Z.Network3.Unpack(wire)
    if not connected or not f or f[1]~='1'or f[2]~=connected.session or f[3]~=Z.session or(f[5]~='LIVE'and f[5]~='QUEST'and f[5]~='EVENT')or not L.Text(f[6],32)then return false end
    local tok=f[5]..':'..key..':'..f[6]
    if f[4]=='Q'and #f==6 then
        local entry=P.receivers[tok];local now=A.Clock()
        if entry and now-entry.at<1 then return false end
        for old,r in pairs(P.receivers)do if now-r.at>120 then P.receivers[old]=nil end end
        if not entry and L.Count(P.receivers)>=512 then return false end
        if not send(key,f[5],f[6])then return false end
        P.receivers[tok]={key=key,kind=f[5],id=f[6],at=now,session=connected.session};return true
    elseif f[4]=='D'and #f==12 then
        local query=P.queries[tok];local e=current(f[5],key,f[6]);local revision,seq,total=tonumber(f[7]),tonumber(f[8]),tonumber(f[9])
        if not query or query.session~=connected.session or not e or not L.Int(revision,1,2147483646)or not L.Int(seq,1,2147483646)or not L.Int(total,1,40)then return false end
        local old=P.cache[tok];if old and old.session==connected.session and seq<=old.sequence then return false end
        local used={TANK=tonumber(f[10]),HEALER=tonumber(f[11]),DAMAGER=tonumber(f[12])}
        for _,role in ipairs({'TANK','HEALER','DAMAGER'})do if not L.Int(used[role],0,f[5]=='EVENT'and e.roleSlots[role]or 40)then return false end end
        P.cache[tok]={total=total,used=f[5]=='EVENT'and used or nil,session=connected.session,sequence=seq,revision=revision,at=A.Clock()}
        Z.MarkDirty('party');return true
    end
    return false
end
function P.SyncLive()
    local e=Z.db.lfg[1];if not e then P.liveBaseline=nil;return end
    -- A search (mode LFG) is no group: its role flags are the roles the player offers and are never counted
    -- down. It ends as soon as the player is in a group.
    if e.mode=='LFG'then
        P.liveBaseline=nil
        if A.GroupState().total>1 and Z.CloseGroup(e.id)then Z.Publish()end
        return
    end
    local state=A.GroupState();local g={tank=0,healer=0,dd=0};local units={}
    if A.Call(IsInRaid)==true then for i=1,state.total do units[#units+1]='raid'..i end
    else units[1]='player';for i=1,state.total-1 do units[#units+1]='party'..i end end
    for _,unit in ipairs(units)do
        local _,name,realm=A.UnitIdentity(unit);local key=name and L.ScopeKey(name,realm,Z.me.faction)
        local p=key and Z.db.interests[e.id]and Z.db.interests[e.id][key]
        local role=L.Role(A.Call(UnitGroupRolesAssigned,unit))or key==Z.me.key and L.Role(Z.db.roles)or p and(p.state=='invited'or p.state=='joined')and L.Role(p.role)
        local field=({TANK='tank',HEALER='healer',DAMAGER='dd'})[role];if field then g[field]=g[field]+1 end
    end
    local previous=P.liveBaseline
    if not previous or previous.id~=e.id then previous={id=e.id,tank=g.tank,healer=g.healer,dd=g.dd}end
    local changed=false
    for _,role in ipairs({'tank','healer','dd'})do
        local other=e.tank+e.healer+e.dd-e[role]
        local value=math.max(0,math.min(e.size-other,e[role]-(g[role]-previous[role])))
        if value~=e[role]then e[role]=value;changed=true end
    end
    P.liveBaseline={id=e.id,tank=g.tank,healer=g.healer,dd=g.dd}
    return changed
end
function P.Tick()
    local now=A.Clock();if now<(P.nextTick or 0)then return end;P.nextTick=now+1
    if P.SyncLive()then Z.db.lfg[1].have=A.GroupRoles();L.Touch(Z.db);Z.Publish()end
    for tok,r in pairs(P.receivers)do
        local connected=route(r.key);local e=current(r.kind,Z.me.key,r.id)
        if now-r.at>120 or not connected or connected.session~=r.session or not e then P.receivers[tok]=nil
        else local info=P.Native({kind=r.kind,data=e});local u=info.used or{}
            local hash=table.concat({e.revision or Z.db.rev,info.total,u.TANK or 0,u.HEALER or 0,u.DAMAGER or 0},':')
            if hash~=r.hash then r.hash=hash;send(r.key,r.kind,r.id)end
        end
    end
end
return P
