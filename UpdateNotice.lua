-- Optional direct version statements, never public mesh records or release proof.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local V={VERSION=1,TTL=300,MAX_REPORTS=256};Z.UpdateNotice=V
local function parse(value,allowBeta)
    if not L.Text(value,32)then return nil end
    local major,minor,patch=value:match("^(%d+)%.(%d+)%.(%d+)$");local beta
    if not major and allowBeta then major,minor,patch,beta=value:match("^(%d+)%.(%d+)%.(%d+)%-beta%.(%d+)$")end
    if not major then return nil end
    local out={tonumber(major),tonumber(minor),tonumber(patch)}
    for i,n in ipairs(out)do if not L.Int(n,0,9999)then return nil end end
    if table.concat(out,".")..(beta and"-beta."..beta or"")~=value then return nil end
    out.beta=beta~=nil;return out
end
-- Numeric comparison; beta announcements are never update targets.
function V.IsNewer(stable,current)
    local a,b=parse(stable),parse(current,true);if not a or not b then return false end
    for i=1,3 do if a[i]~=b[i]then return a[i]>b[i]end end;return b.beta
end
function V.Normalize(raw)
    if type(raw)=="table"and raw.version~=nil and raw.version~=0 and raw.version~=V.VERSION then return nil end
    return{version=V.VERSION,lastNotified=type(raw)=="table"and parse(raw.lastNotified)and raw.lastNotified or""}
end
-- Account-wide bounded deduplication; reports and send state are session-local.
-- Future schemas are left untouched and suppress notices until understood.
function V.Initialize(root)
    V.reports,V.sent={},{};V.nextCheck,V.nextSend,V.nextPrune=0,0,0;V.store=V.Normalize(root.addonUpdateNotice)
    if V.store then root.addonUpdateNotice=V.store end
end
local function own(target)
    local id=L.Identity(target);if id==L.Identity(Z.me.target)then return true end
    for _,c in pairs(Z.account and Z.account.characters or{})do if L.Identity(c.target)==id then return true end end
    return false
end
-- Once per confirmed session, at most one low-priority announcement per second.
-- No periodic version heartbeat, request/reply or extra discovery.
function V.OnConnected(route)
    if not V.sent or not route or A.Clock()<V.nextSend or own(route.name)or not parse(Z.ADDON_VERSION)then return end
    local key=Z.ResolvePeerKey(route.name);if not key or Z.db.blocked[key]then return end
    if V.sent[key]==route.session then return end
    if not V.sent[key]and L.Count(V.sent)>=V.MAX_REPORTS then return end
    local wire=Z.Network3.Pack({"1",Z.session,A.Now(),Z.ADDON_VERSION})
    if Z.Network3.QueueDirect(route.name,"AV",wire,5,"AV:"..key)then V.sent[key]=route.session;V.nextSend=A.Clock()+1 end
end
local function announce()
    if not Z.db.consent or not Z.identityReady or Z.offlineOnly or A.Clock()<V.nextSend then return end
    if A.Clock()>=V.nextPrune then
        V.nextPrune=A.Clock()+30
        for key in pairs(V.sent)do local c=Z.db.contacts[key];if not c or not Z.BattleNetTransport.Route(c.target)then V.sent[key]=nil end end
    end
    local selected
    for _,route in pairs(Z.BattleNetTransport.routes or{})do
        local key=Z.ResolvePeerKey(route.name);local sent=key and V.sent[key]
        if key and sent~=route.session and not Z.db.blocked[key]and not own(route.name)and Z.BattleNetTransport.Route(route.name)==route then
            if not selected or route.name<selected.name then selected=route end
        end
    end
    if selected then V.OnConnected(selected)else V.nextSend=A.Clock()+1 end
end
-- Schema, timestamp, confirmed session and direct route are all required.
function V.Receive(sender,wire)
    if not V.reports or not Z.db.consent or type(wire)~="string"or#wire>96 then return false end
    local f=Z.Network3.Unpack(wire);local at=f and tonumber(f[3])
    if not f or#f~=4 or f[1]~="1"or not parse(f[4])or not L.Int(at,1,4102444800)or at>A.Now()+120 or A.Now()-at>=V.TTL then return false end
    local key=Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key];local contact=key and Z.db.contacts[key]
    if not contact or Z.db.blocked[key]or own(contact.target)or not peer or peer.verifiedSession~=f[2]or not Z.IsOnline(key)then return false end
    local route=Z.BattleNetTransport.Route(contact.target);if not route or route.session~=f[2]then return false end
    local old=V.reports[key];if old and old.session==f[2]and(at<old.at or f[4]~=old.release)then return false end
    if not old and L.Count(V.reports)>=V.MAX_REPORTS then return false end
    V.reports[key]={release=f[4],session=f[2],at=at};V.nextCheck=0;return true
end
-- Two independently reachable peers must report at least the proposed release.
-- Native game-account IDs collapse character changes; humans cannot be proven.
function V.Target()
    if not V.reports or not Z.db.consent or not Z.identityReady or Z.offlineOnly then return nil end
    local bySource={}
    for key,row in pairs(V.reports)do
        local c,p=Z.db.contacts[key],Z.db.peers[key];local route=c and Z.BattleNetTransport.Route(c.target)
        -- The installed version is fixed for the lifetime of this session.
        -- Fresh native routes certify its continuity without version heartbeats.
        if not c or Z.db.blocked[key]or own(c.target)or not p or p.verifiedSession~=row.session or not Z.IsOnline(key)or not route or route.session~=row.session then V.reports[key]=nil
        elseif V.IsNewer(row.release,Z.ADDON_VERSION)then
            local source=route.transport=="BNET"and("BNET:"..tostring(route.target))or("CHAR:"..L.Identity(c.target))
            local previous=bySource[source];if not previous or V.IsNewer(row.release,previous)then bySource[source]=row.release end
        end
    end
    local releases={};for _,release in pairs(bySource)do releases[#releases+1]=release end
    table.sort(releases,function(a,b)return V.IsNewer(a,b)end);return releases[2]
end
function V.Tick()
    if V.sent then announce()end
    if not V.store or A.Clock()<V.nextCheck then return end;V.nextCheck=A.Clock()+5
    if A.Call(InCombatLockdown)~=false then return end
    local target=V.Target();if not target or V.store.lastNotified~=""and not V.IsNewer(target,V.store.lastNotified)then return end
    if Z.UI and Z.UI.NotifyAddonVersion and Z.UI.NotifyAddonVersion(target)then V.store.lastNotified=target end
end
return V
