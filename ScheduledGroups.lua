-- Scheduled groups are independent of the one-slot/24h live finder. Public
-- announcements are claims; attendance is authoritative only on private routes.
local Z,L,A,T=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.ScheduleTime
local S={VERSION=1,MAX_EVENTS=100,MAX_PUBLIC=10,MAX_FOLLOWING=100,MAX_PARTICIPANTS=40,MAX_TEMPLATES=20,MAX_REMOTE=2048,HORIZON=90*86400};Z.ScheduledGroups=S
-- Carrying on: while the organizer of an event is offline, its participants (confirmed, waitlisted or with an
-- open request) repeat the public announcement so the event stays visible. They repeat only what the organizer
-- announced publicly, only for events that start within CARRY_HORIZON, and under a session that ranks below
-- every real session of the organizer (same epoch, middle part 0): whatever the organizer sends later always
-- wins. Among carried records the later session of the organizer wins, then the newer state of the event, then
-- time. "State" is the content revision and whether the event is closed; the plain revision also counts every
-- participant's change and differs between participants without anyone being out of date. A participant who
-- knows a newer state corrects one who repeats an older one (a changed or cancelled event), and the one with
-- the older state stops until the organizer has verified it again. Not a setting; players who are hidden
-- (S.Enabled) take no part.
S.CARRY_HORIZON=14*86400;S.CARRY_INTERVAL=600
local CARRIER={CONFIRMED=true,WAITLIST=true,REQUESTED=true}
local function carriedSession(session)return type(session)=='string'and session:match('^%d+%.0%.')~=nil end
-- Orders two states of one event: positive when a is newer than b.
local function newerState(a,b)
    if a.contentRevision~=b.contentRevision then return a.contentRevision>b.contentRevision end
    return a.status~='OPEN'and b.status=='OPEN'
end
local EVENTS={DRAFT=true,OPEN=true,CANCELLED=true,FINISHED=true}
local APPS={NONE=true,REQUESTED=true,CONFIRMED=true,WAITLIST=true,DECLINED=true,WITHDRAWN=true}
local REASONS={OK=true,STALE=true,FULL=true,CLOSED=true,MISSING=true,CHANGED=true,PRIVACY=true}
local STATE_EN={DRAFT='Draft',OPEN='Open',CANCELLED='Cancelled',FINISHED='Finished',NONE='No application',REQUESTED='Requested',CONFIRMED='Confirmed',WAITLIST='Waitlisted',DECLINED='Declined',WITHDRAWN='Withdrawn'}
local STATE_DE={DRAFT='Entwurf',OPEN='Offen',CANCELLED='Abgesagt',FINISHED='Beendet',NONE='Keine Anmeldung',REQUESTED='Angefragt',CONFIRMED='Bestätigt',WAITLIST='Ersatzbank',DECLINED='Abgelehnt',WITHDRAWN='Zurückgezogen'}
function S.StateLabel(state)return(Z.Locale.isGerman and STATE_DE[state]or STATE_EN[state])or Z.T('Unknown')end
function S.DeliveryLabel(value)
    local labels={saved='Saved state',unknown='Unknown',querying='Verification in progress',offline='No direct route',pending='Awaiting organizer response',queued='Queued operation',verified='Verified with organizer',blocked='Blocked',unconfirmed='No confirmed response',deposited='Left with a participant; the organizer has not seen it yet',OK='Verified with organizer',STALE='Event changed; request rejected',FULL='Application limit reached',CLOSED='Registration closed',MISSING='Event unavailable',CHANGED='Scheduled event changed; apply again',PRIVACY='Publication withdrawn'}
    return Z.T(labels[value]or'Unknown')
end
local MAX=2147483646
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function id(v)return L.Text(v,32)and v:match('^%d+%.%d+$')~=nil end
local function token(owner,eventID)return owner..':'..eventID end
S.Token=token
local function scalar(t)local out={};for k,v in pairs(t)do if type(v)~='table'then out[k]=v end end;return out end
local function validRole(value)return value=='TANK'or value=='HEALER'or value=='DAMAGER'end
local function roles(r)return type(r)=='table'and L.Int(r.TANK,0,40)and L.Int(r.HEALER,0,40)and L.Int(r.DAMAGER,0,40)and r.TANK+r.HEALER+r.DAMAGER>=1 and r.TANK+r.HEALER+r.DAMAGER<=40 end
local function usedCounts(used,slots)
    if used==nil then return true end
    return type(used)=='table'and L.Int(used.TANK,0,slots.TANK)and L.Int(used.HEALER,0,slots.HEALER)and L.Int(used.DAMAGER,0,slots.DAMAGER)
end
local function header(e)
    return type(e)=='table'and id(e.id)and L.ValidIdentityKey(e.ownerKey)and L.Int(e.revision,1,MAX)and L.Int(e.contentRevision,1,e.revision)and EVENTS[e.status]
        and L.Text(e.activity,64,e.status=='DRAFT')and L.Text(e.note or'',192,true)and L.Int(e.startsAt,1,4102444799)and L.Int(e.endsAt,e.startsAt+900,math.min(4102444799,e.startsAt+8*3600))and roles(e.roleSlots)and usedCounts(e.used,e.roleSlots)
end
local function snapshot(e)
    local out={id=e.id,ownerKey=e.ownerKey,revision=e.revision,contentRevision=e.contentRevision,status=e.status,activity=e.activity,startsAt=e.startsAt,endsAt=e.endsAt,note=e.note or'',roleSlots={TANK=e.roleSlots.TANK,HEALER=e.roleSlots.HEALER,DAMAGER=e.roleSlots.DAMAGER}}
    if e.used then out.used={TANK=e.used.TANK,HEALER=e.used.HEALER,DAMAGER=e.used.DAMAGER}end;return out
end
local function empty()return{version=S.VERSION,owned={},following={},templates={},reminded={},reminderSeq=0}end
local function validApp(p)
    return type(p)=='table'and APPS[p.state]and p.state~='NONE'and validRole(p.role)and L.Int(p.seq,1,MAX)and L.Int(p.revision,1,MAX)
        and id(p.lastNonce)and(p.lastAction=='APPLY'or p.lastAction=='WITHDRAW')and L.Int(p.lastContentRevision,1,MAX)
        and L.Int(p.ackEventRevision or 0,0,MAX)and L.Int(p.ackAppRevision or 0,0,MAX)
end
function S.Normalize(raw,owner)
    if raw==nil then return empty()end
    if type(raw)~='table'then return empty(),'invalid'end
    if raw.version~=S.VERSION then return nil,'unsupported'end
    if type(raw.owned)~='table'or type(raw.following)~='table'or type(raw.templates)~='table'or type(raw.reminded)~='table'or not L.Int(raw.reminderSeq,0,MAX)then return empty(),'invalid'end
    local out=empty();out.reminderSeq=raw.reminderSeq
    local n,published=0,0;for key,e in pairs(raw.owned)do
        n=n+1;if n>S.MAX_EVENTS or not header(e)or key~=e.id or e.ownerKey~=owner or type(e.public)~='boolean'or e.public and e.status=='DRAFT'
            or e.status=='OPEN'and not e.public or not L.Text(e.activity,64)or not L.Int(e.createdAt,1,4102444799)or not L.Int(e.updatedAt,e.createdAt,4102444799)
            or(e.organizerRole~=''and not validRole(e.organizerRole))or e.organizerRole~=''and e.roleSlots[e.organizerRole]<1
            or not L.Text(e.templateID or'',32,true)or e.templateID~=''and not id(e.templateID)or type(e.participants)~='table'then return empty(),'invalid'end
        if e.public and e.status=='OPEN'then published=published+1;if published>S.MAX_PUBLIC then return empty(),'invalid'end end
        local row=snapshot(e);row.public=e.public;row.createdAt=e.createdAt;row.updatedAt=e.updatedAt;row.organizerRole=e.organizerRole;row.templateID=e.templateID or'';row.participants={}
        local m=0;for peer,p in pairs(e.participants)do m=m+1;if m>S.MAX_PARTICIPANTS or not L.ValidIdentityKey(peer)or peer==owner or not validApp(p)or p.revision>e.revision or p.lastContentRevision>e.contentRevision or(p.ackEventRevision or 0)>e.revision or(p.ackAppRevision or 0)>p.revision or(e.status=='DRAFT'or e.status=='CANCELLED')and(p.state=='REQUESTED'or p.state=='CONFIRMED'or p.state=='WAITLIST')then return empty(),'invalid'end;row.participants[peer]={state=p.state,role=p.role,seq=p.seq,revision=p.revision,lastNonce=p.lastNonce,lastAction=p.lastAction,lastContentRevision=p.lastContentRevision,ackEventRevision=p.ackEventRevision or 0,ackAppRevision=p.ackAppRevision or 0,reason=REASONS[p.reason]and p.reason or'OK',
            target=L.Text(p.target,49)and L.Identity(p.target)and p.target or nil,via=L.ValidIdentityKey(p.via)and p.via or nil,relayedAt=L.Int(p.relayedAt,1,4102444799)and p.relayedAt or nil}end
        local used=S.Counts(row);for role,amount in pairs(used)do if amount>row.roleSlots[role]then return empty(),'invalid'end end
        out.owned[key]=row
    end
    n=0;for key,r in pairs(raw.following)do
        n=n+1;if n>S.MAX_FOLLOWING or type(r)~='table'or not header(r.snapshot)or not L.ValidIdentityKey(r.ownerKey)or r.ownerKey==owner or not id(r.id)or key~=token(r.ownerKey,r.id)
            or r.snapshot.ownerKey~=r.ownerKey or r.snapshot.id~=r.id or not APPS[r.state]or(r.role~=''and not validRole(r.role))
            or not L.Text(r.operationNonce or'',32,true)or(r.operationNonce and r.operationNonce~=''and not id(r.operationNonce))or not L.Int(r.seq,0,MAX)or not L.Int(r.acceptedSeq or 0,0,r.seq)or not L.Int(r.authorityRevision or 0,0,MAX)or not L.Int(r.appRevision,0,MAX)or not L.Int(r.updatedAt,1,4102444799)then return empty(),'invalid'end
        local row={ownerKey=r.ownerKey,id=r.id,snapshot=snapshot(r.snapshot),state=r.state,role=r.role,seq=r.seq,operationNonce=r.operationNonce or'',acceptedSeq=r.acceptedSeq or 0,authorityRevision=r.authorityRevision or 0,appRevision=r.appRevision,updatedAt=r.updatedAt,delivery='saved',
            superseded=L.Int(r.superseded,1,MAX)and r.superseded or nil,
            box=Z.ScheduledRelay and Z.ScheduledRelay.CleanBox(r.box)or nil,relayed=Z.ScheduledRelay and Z.ScheduledRelay.CleanRelayed(r.relayed)or nil,
            announced=r.announced==true,ownerSession=type(r.ownerSession)=='string'and L.Text(r.ownerSession,32)and r.ownerSession:match('^%d+%.%d+%.%d+$')and r.ownerSession or nil}
        if r.pending~=nil then local p=r.pending;if type(p)~='table'or(p.action~='APPLY'and p.action~='WITHDRAW')or not validRole(p.role)or not L.Int(p.seq,1,MAX)or p.seq~=r.seq or not L.Int(p.contentRevision,1,MAX)or not id(p.nonce)then return empty(),'invalid'end;row.pending={action=p.action,role=p.role,seq=p.seq,contentRevision=p.contentRevision,nonce=p.nonce,attempts=0,next=0,deposited=p.deposited==true or nil}end
        out.following[key]=row
    end
    n=0;for key,p in pairs(raw.templates)do
        n=n+1;if n>S.MAX_TEMPLATES or type(p)~='table'or not id(key)or p.id~=key or not header(p.base)or p.base.ownerKey~=owner or not T.Valid(p.localCivil)or not L.Int(p.nextIndex,1,520)
            or(p.organizerRole~=''and not validRole(p.organizerRole))then return empty(),'invalid'end
        out.templates[key]={id=key,base=snapshot(p.base),localCivil={year=p.localCivil.year,month=p.localCivil.month,day=p.localCivil.day,hour=p.localCivil.hour,min=p.localCivil.min,sec=p.localCivil.sec or 0},nextIndex=p.nextIndex,organizerRole=p.organizerRole}
    end
    n=0;for key,r in pairs(raw.reminded)do n=n+1;if n>200 or not L.Text(key,300)or type(r)~='table'or not L.Int(r.contentRevision,1,MAX)or not L.Int(r.stage,0,3)then return empty(),'invalid'end;out.reminded[key]={contentRevision=r.contentRevision,stage=r.stage}end
    return out
end
function S.Initialize()
    S.store,S.loadError=S.Normalize(Z.db.scheduledGroups,Z.me.key);if S.store then Z.db.scheduledGroups=S.store end
    -- Remove old unpublished drafts; retain withdrawn events with a participant history.
    for key,e in pairs(S.store and S.store.owned or{})do if e.status=='DRAFT'then
        if not next(e.participants)then S.store.owned[key]=nil else e.status='CANCELLED' end
    end end
    S.announceAt,S.withdrawn,S.pushAt,S.pushAttempts,S.queryAt,S.queryNonce,S.rates,S.hellos={},{},{},{},{},{},{},{}
    S.nextTick,S.nextPublish,S.nextPrune=0,0,0;S.syncedSessions={};S.decodePending={};S.querySentAt={}
end
local function changed()S.listCache=nil;if Z.MarkDirty then Z.MarkDirty('scheduled')end end
function S.Invalidate()S.listCache=nil end
function S.CacheRecord(record)
    record.scheduledWire=record.wire;record.scheduledDecoded=S.DecodeRecord(record.wire)or false
    record.scheduledOwner=L.ScopeKey(record.origin,Z.me.realm,Z.me.faction)
end
function S.DecodePending()
    local n,started=0,A.Clock()
    for key,record in pairs(S.decodePending or{})do
        S.decodePending[key]=nil
        if Z.ScheduledMesh.records[key]==record then S.CacheRecord(record);n=n+1 end
        if n>=50 or A.Clock()-started>=.004 then break end
    end
    if n>0 then S.Invalidate();if Z.MarkDirty then Z.MarkDirty('scheduled')end end
end
function S.Loading()return next(S.decodePending or{})~=nil end
function S.Enabled()return S.store and Z.db.consent and Z.db.autoDiscovery and Z.db.visible and Z.identityReady and not Z.offlineOnly end
local function editable()return S.store~=nil and A.Now()>0 end
local function bump(e,content)
    if e.revision>=MAX or content and e.contentRevision>=MAX then return false,'Scheduled revision limit reached.'end
    e.revision=e.revision+1;if content then e.contentRevision=e.contentRevision+1 end;e.updatedAt=A.Now();S.announceAt[e.id]=0;changed();return true
end
function S.Counts(e)
    local used={TANK=0,HEALER=0,DAMAGER=0}
    if e.organizerRole and used[e.organizerRole]then used[e.organizerRole]=1 end
    for _,p in pairs(e.participants or{})do if p.state=='CONFIRMED'then used[p.role]=used[p.role]+1 end end;return used
end
function S.GetOwned(eventID)return S.store and S.store.owned[eventID]end
local function dropOwned(eventID)
    local e=S.store.owned[eventID];if not e then return end
    for peer in pairs(e.participants)do local tok=token(peer,eventID);S.pushAt[tok]=nil;S.pushAttempts[tok]=nil end
    S.announceAt[eventID]=nil;S.withdrawn[eventID]=nil;S.store.reminded[token(e.ownerKey,eventID)]=nil;S.store.owned[eventID]=nil
end
function S.Create(input)
    if not editable()then return nil,'Saved scheduled groups are unavailable. Data was preserved.'end
    if type(input)~='table'or not L.Text(input.activity,64)or not L.Text(input.note or'',192,true)or not roles(input.roleSlots)
        or not L.Int(input.startsAt,A.Now()+1,math.min(A.Now()+S.HORIZON,4102444799))or not L.Int(input.duration,15,480)
        or input.startsAt+input.duration*60>4102444799 or(input.organizerRole and input.organizerRole~=''and not validRole(input.organizerRole))then return nil,'Scheduled event fields are invalid.'end
    local ownRole=input.organizerRole or'';if ownRole~=''and input.roleSlots[ownRole]<1 then return nil,'Organizer role needs a slot.'end
    if count(S.store.owned)>=S.MAX_EVENTS then return nil,'Scheduled storage is full (100 events). Wait for archive cleanup.'end
    local eventID=L.NextID(Z.db,A.Now());local now=A.Now();local e={id=eventID,ownerKey=Z.me.key,revision=1,contentRevision=1,status='DRAFT',activity=L.ActivityID(input.activity),startsAt=input.startsAt,endsAt=input.startsAt+input.duration*60,
        roleSlots={TANK=input.roleSlots.TANK,HEALER=input.roleSlots.HEALER,DAMAGER=input.roleSlots.DAMAGER},note=input.note or'',organizerRole=ownRole,createdAt=now,updatedAt=now,public=false,templateID='',participants={}}
    S.store.owned[eventID]=e;changed();return eventID
end
local function pushAll(e)
    for key in pairs(e.participants)do local tok=token(key,e.id);S.pushAt[tok]=0;S.pushAttempts[tok]=0 end
end
local function invalidateApps(e,reason)
    for _,p in pairs(e.participants)do if p.state=='REQUESTED'or p.state=='CONFIRMED'or p.state=='WAITLIST'then p.state='WITHDRAWN';p.revision=math.min(MAX,p.revision+1);p.reason=reason end end;pushAll(e)
end
function S.Edit(eventID,input,expectedRevision)
    local e=S.GetOwned(eventID);if not e or not editable()or e.revision~=expectedRevision or(e.status~='DRAFT'and e.status~='OPEN')or A.Now()>=e.startsAt then return false,'Scheduled event changed or is no longer editable.'end
    -- Validate with the same creation rules before changing the existing record.
    if type(input)~='table'or not L.Text(input.activity,64)or not L.Text(input.note or'',192,true)or not roles(input.roleSlots)or not L.Int(input.startsAt,A.Now()+1,A.Now()+S.HORIZON)
        or not L.Int(input.duration,15,480)or input.startsAt+input.duration*60>4102444799 or(input.organizerRole~=''and not validRole(input.organizerRole))or input.organizerRole~=''and input.roleSlots[input.organizerRole]<1 then return false,'Scheduled event fields are invalid.'end
    local ok,why=bump(e,true);if not ok then return false,why end
    e.activity=L.ActivityID(input.activity);e.startsAt=input.startsAt;e.endsAt=input.startsAt+input.duration*60;e.note=input.note or'';e.roleSlots={TANK=input.roleSlots.TANK,HEALER=input.roleSlots.HEALER,DAMAGER=input.roleSlots.DAMAGER};e.organizerRole=input.organizerRole
    invalidateApps(e,'CHANGED');return true
end
function S.Publish(eventID)
    local e=S.GetOwned(eventID);if not e or not S.Enabled()or(e.status~='DRAFT'and e.status~='OPEN')or A.Now()>=e.startsAt then return false,'Publishing scheduled groups is unavailable.'end
    local n=0;for _,owned in pairs(S.store.owned)do if owned.public and owned.status=='OPEN'then n=n+1 end end
    if not e.public and n>=S.MAX_PUBLIC then return false,'Publish no more than ten upcoming events.'end
    if e.status=='DRAFT'then local ok,why=bump(e,false);if not ok then return false,why end;e.status='OPEN';e.public=true end
    S.announceAt[eventID]=0;changed();return true
end
function S.Cancel(eventID,expectedRevision)
    local e=S.GetOwned(eventID);if not e or not editable()or e.revision~=expectedRevision or(e.status~='DRAFT'and e.status~='OPEN')then return false,'Scheduled event changed or is closed.'end
    local ok,why=bump(e,true);if not ok then return false,why end;e.status='CANCELLED';invalidateApps(e,'CLOSED');return true
end
function S.DeleteDraft(eventID)
    local e=S.GetOwned(eventID);if e and e.status=='DRAFT'and not next(e.participants)then dropOwned(eventID);changed();return true end;return false,'Only unused private drafts can be deleted.'
end
function S.SaveTemplate(eventID)
    local e=S.GetOwned(eventID);local civil=e and T.Local(e.startsAt)
    if not e or not editable()or not civil then return nil,'Local time conversion is unavailable.'end
    if e.templateID~=''and S.store.templates[e.templateID]then return e.templateID end
    if count(S.store.templates)>=S.MAX_TEMPLATES then return nil,'No more than twenty recurrence templates.'end
    local key=L.NextID(Z.db,A.Now());S.store.templates[key]={id=key,base=snapshot(e),localCivil=civil,organizerRole=e.organizerRole,nextIndex=1};e.templateID=key;changed();return key
end
function S.Preview(templateID,amount)
    local p=S.store and S.store.templates[templateID];if not p or not L.Int(amount,1,4)then return nil,'Choose one to four upcoming instances.'end
    if not T.SameLocal(p.base.startsAt,p.localCivil)then return nil,'Client timezone changed. Create a new recurrence template.'end
    local out={};local index=p.nextIndex
    while#out<amount and index<=520 do
        local at,why=T.Weekly(p.base.startsAt,index);if not at then return nil,why end
        if at>A.Now()+S.HORIZON then return nil,'Events must start within ninety days.'end
        if at>A.Now()then out[#out+1]={startsAt=at,index=index}end;index=index+1
    end
    if#out~=amount then return nil,'Choose one to four upcoming instances.'end;return out
end
function S.Generate(templateID,proposal)
    if not editable()or type(proposal)~='table'then return nil,'Recurrence preview changed. Review it again.'end
    local current,why=S.Preview(templateID,#proposal);if not current then return nil,why end
    for i,row in ipairs(current)do if type(proposal[i])~='table'or row.startsAt~=proposal[i].startsAt or row.index~=proposal[i].index then return nil,'Recurrence preview changed. Review it again.'end end
    if count(S.store.owned)+#current>S.MAX_EVENTS then return nil,'Scheduled storage is full (100 events). Wait for archive cleanup.'end
    local p=S.store.templates[templateID];local created={}
    for _,row in ipairs(current)do
        local eventID,reason=S.Create({activity=p.base.activity,startsAt=row.startsAt,duration=(p.base.endsAt-p.base.startsAt)/60,roleSlots=p.base.roleSlots,note=p.base.note,organizerRole=p.organizerRole})
        if not eventID then for _,key in ipairs(created)do S.store.owned[key]=nil end;return nil,reason end
        S.store.owned[eventID].templateID=templateID;created[#created+1]=eventID
    end
    p.nextIndex=current[#current].index+1;changed();return created
end
function S.GenerateAndPublish(templateID,proposal)
    if not S.Enabled()then return nil,'Publishing scheduled groups is unavailable.'end
    local public=0;for _,e in pairs(S.store.owned)do if e.public and e.status=='OPEN'then public=public+1 end end
    if type(proposal)~='table'or public+#proposal>S.MAX_PUBLIC then return nil,'Publish no more than ten upcoming events.'end
    local template=S.store.templates[templateID];local previous=template and template.nextIndex
    local keys,why=S.Generate(templateID,proposal);if not keys then return nil,why end
    for _,key in ipairs(keys)do local ok,reason=S.Publish(key);if not ok then
        for _,created in ipairs(keys)do dropOwned(created)end
        template.nextIndex=previous;changed();return nil,reason
    end end
    return keys
end
local function headerFields(e,state)
    return{e.id,e.revision,e.contentRevision,state or e.status,e.activity,e.startsAt,e.endsAt,e.roleSlots.TANK,e.roleSlots.HEALER,e.roleSlots.DAMAGER,e.note or''}
end
local function decodeHeader(f,at,owner)
    local e={ownerKey=owner,id=f[at],revision=tonumber(f[at+1]),contentRevision=tonumber(f[at+2]),status=f[at+3],activity=f[at+4],startsAt=tonumber(f[at+5]),endsAt=tonumber(f[at+6]),roleSlots={TANK=tonumber(f[at+7]),HEALER=tonumber(f[at+8]),DAMAGER=tonumber(f[at+9])},note=f[at+10]}
    return header(e)and e or nil
end
function S.Record(e)
    local h=headerFields(e);local used=S.Counts(e)
    if not e.public then h[4]='DRAFT';h[5]='';h[11]='';used={TANK=0,HEALER=0,DAMAGER=0}end
    local values={'1',Z.session,A.Now(),Z.me.faction};for _,v in ipairs(h)do values[#values+1]=v end
    for _,role in ipairs({'TANK','HEALER','DAMAGER'})do values[#values+1]=used[role]end;return Z.Network3.Pack(values)
end
function S.DecodeRecord(wire)
    if type(wire)~='string'or#wire>768 then return nil end
    local f=Z.Network3.Unpack(wire);if not f or#f~=18 or f[1]~='1'or not L.Text(f[2],32)or not f[2]:match('^%d+%.%d+%.%d+$')or f[4]~=Z.me.faction then return nil end
    local at=tonumber(f[3]);if not L.Int(at,1,4102444799)or at>A.Now()+120 or A.Now()-at>900 then return nil end
    local e=decodeHeader(f,5,Z.me.key);if not e or e.startsAt>A.Now()+S.HORIZON or e.endsAt<A.Now()-30*86400 then return nil end
    e.ownerKey=nil;e.session=f[2];e.at=at;e.used={TANK=tonumber(f[16]),HEALER=tonumber(f[17]),DAMAGER=tonumber(f[18])}
    for _,role in ipairs({'TANK','HEALER','DAMAGER'})do local n=e.used[role];if not L.Int(n,0,e.roleSlots[role])then return nil end end
    return e
end
local function currentRoute(key)
    local c=Z.db.contacts[key];local p=Z.db.peers[key];local r=c and Z.BattleNetTransport.Route(c.target)
    if not Z.db.consent or not Z.identityReady or Z.offlineOnly or not c or not p or Z.db.blocked[key]or key==Z.me.key or not r or r.session~=p.verifiedSession or not Z.IsOnline(key)then return nil end;return r,c
end
function S.Reach(owner)
    if owner==Z.me.key then return 'Organizer'end
    local r=currentRoute(owner);return r and(r.scheduledGroups and'Directly reachable'or'Scheduled groups unsupported or not yet verified')or'Organizer offline or not directly reachable'
end
function S.ParticipantStatus(key)
    if currentRoute(key)then return 'Directly reachable'end
    return Z.IsOnline(key)and'Reported online; not directly reachable'or'Offline or unknown'
end
function S.List(includeClosed)
    local cacheKey=includeClosed and'all'or'active';local cache=S.listCache and S.listCache[cacheKey];if cache and A.Clock()<cache.untilAt then return cache.rows end
    -- Native records are decoded once at acceptance. Imported/replayed records
    -- without that cache are prepared in bounded batches, never all in one UI tick.
    local inspected=0
    for key,record in pairs(Z.ScheduledMesh and Z.ScheduledMesh.records or{})do
        inspected=inspected+1;if inspected>S.MAX_REMOTE then break end
        if record.scheduledWire~=record.wire then S.decodePending[key]=record end
    end
    S.DecodePending()
    local out,seen={},{}
    for _,e in pairs(S.store and S.store.owned or{})do if e.status~='DRAFT'and(includeClosed or e.status=='OPEN'and e.endsAt>A.Now())then out[#out+1]=e;seen[token(e.ownerKey,e.id)]=true end end
    if Z.db.consent and Z.db.autoDiscovery then
        inspected=0;for _,record in pairs(Z.ScheduledMesh and Z.ScheduledMesh.records or{})do
            inspected=inspected+1;if inspected>S.MAX_REMOTE then break end
            local e=record.scheduledWire==record.wire and record.scheduledDecoded;local owner=record.scheduledOwner
            -- What the organizer announces publicly, seen while the organizer is verified on a direct route: the
            -- only evidence a participant accepts for carrying the event on later.
            local known=e and owner and S.store and S.store.following[token(owner,e.id)]
            if known and known.verifiedSession and known.verifiedSession==record.session then local route=currentRoute(owner)
                if route and route.session==record.session then known.announced=e.status~='DRAFT';known.ownerSession=record.session end -- an unpublished event is announced as DRAFT
            end
            if e and A.Now()-e.at<=900 and owner and owner~=Z.me.key and not Z.db.blocked[owner]and e.status=='OPEN'and e.endsAt>A.Now()then
                e.carried=carriedSession(record.session)
                e.ownerKey=owner;e.ownerTarget=record.origin;e.announcement=true;local key=token(owner,e.id)
                local follow=S.store and S.store.following[key]
                if follow and follow.verifiedSession and follow.verifiedSession==record.session and currentRoute(owner)and follow.verifiedSession==currentRoute(owner).session then e= snapshot(follow.snapshot)end
                if not seen[key]and(includeClosed or e.status=='OPEN'and e.endsAt>A.Now())then out[#out+1]=e;seen[key]=true end
            end
        end
    end
    for key,r in pairs(S.store and S.store.following or{})do if not seen[key]and not Z.db.blocked[r.ownerKey]and(includeClosed or r.snapshot.status=='OPEN'and r.snapshot.endsAt>A.Now())then out[#out+1]=snapshot(r.snapshot);seen[key]=true end end
    table.sort(out,function(a,b)if a.startsAt~=b.startsAt then return a.startsAt<b.startsAt end;if a.ownerKey~=b.ownerKey then return a.ownerKey<b.ownerKey end;return a.id<b.id end);S.listCache=S.listCache or{};S.listCache[cacheKey]={rows=out,untilAt=A.Clock()+5};return out
end
function S.Get(owner,eventID)
    if owner==Z.me.key then return S.GetOwned(eventID)end
    for _,e in ipairs(S.List(true))do if e.ownerKey==owner and e.id==eventID then return e end end
end
function S.Follow(owner,eventID)return S.store and S.store.following[token(owner,eventID)]end
function S.Forget(owner,eventID)
    local r=S.Follow(owner,eventID)
    if not r or r.pending or(r.snapshot.status=='OPEN'and r.snapshot.endsAt>A.Now()and(r.state=='REQUESTED'or r.state=='CONFIRMED'or r.state=='WAITLIST'))then return false,'Withdraw and verify an active application before forgetting it.'end
    local key=token(owner,eventID);S.store.following[key]=nil;S.store.reminded[key]=nil;S.queryAt[key]=nil;S.queryNonce[key]=nil;S.querySentAt[key]=nil;changed();return true
end
function S.DeleteTemplate(templateID)
    if S.store and S.store.templates[templateID]then S.store.templates[templateID]=nil;changed();return true end;return false
end
local function ensureFollow(e)
    if not S.store or e.ownerKey==Z.me.key then return nil end
    local key=token(e.ownerKey,e.id);local r=S.store.following[key]
    if not r then if count(S.store.following)>=S.MAX_FOLLOWING then return nil end;r={ownerKey=e.ownerKey,id=e.id,snapshot=snapshot(e),state='NONE',role='',seq=0,operationNonce='',acceptedSeq=0,authorityRevision=0,appRevision=0,updatedAt=A.Now(),delivery='unknown'};S.store.following[key]=r end;return r
end
local function notify(e,code,peer,source)
    local c=source and Z.db.contacts[source]
    if Z.Notifications and Z.Notifications.store then Z.Notifications.Push('groups','scheduled','schedule:'..e.ownerKey..':'..e.id..':'..(source or code),e.revision,code,peer or e.ownerKey,e.id,e.activity,c and c.target or nil)end
end
function S.OnConnected(route)
    if not S.store or not Z.db.consent then return end
    if route.scheduledGroups then S.OnPeerOnline(route.name,route.session);return end
    local key=route.transport..':'..route.target..':'..route.session;if S.hellos[key]and A.Clock()-S.hellos[key]<60 then return end
    if count(S.hellos)>=512 then return end;S.hellos[key]=A.Clock()
    if route.transport=='BNET'then Z.ScheduledMesh.OnConnected(route)
    else Z.Network3.QueueDirect(route.name,'SH',Z.Network3.Pack({'1',Z.session,route.session,'H'}),20,'SCHEDULEHELLO:'..route.name)end
end
function S.OnPeerOnline(target,session,force)
    local key=Z.ResolvePeerKey(target);if not key or not S.store then return end
    if not force and S.syncedSessions[key]==session then return end
    if not S.syncedSessions[key]and count(S.syncedSessions)>=512 then for old in pairs(S.syncedSessions)do if not currentRoute(old)then S.syncedSessions[old]=nil;break end end;if count(S.syncedSessions)>=512 then return end end
    S.syncedSessions[key]=session
    for tok,r in pairs(S.store.following)do if r.ownerKey==key then r.verifiedSession=nil;S.queryAt[tok]=0;if r.pending then r.pending.next=0;r.pending.attempts=0 end end end
    for _,e in pairs(S.store.owned)do if e.participants[key]then local tok=token(key,e.id);S.pushAt[tok]=0;S.pushAttempts[tok]=0 end end;changed()
end
local function sendQuery(r)
    local route,contact=currentRoute(r.ownerKey);if not route or not route.scheduledGroups then r.delivery='offline';return false end
    local nonce=L.NextID(Z.db,A.Now());local wire=Z.Network3.Pack({'1',Z.session,route.session,r.id,r.snapshot.revision,nonce})
    if Z.Network3.QueueDirect(contact.target,'SQ',wire,85,'SCHEDULEQUERY:'..token(r.ownerKey,r.id))then S.queryNonce[token(r.ownerKey,r.id)]=nonce;S.querySentAt[token(r.ownerKey,r.id)]=A.Clock();S.queryAt[token(r.ownerKey,r.id)]=A.Clock()+60;r.delivery='querying';return true end;return false
end
local sendPending
function S.Query(owner,eventID)
    local e=S.Get(owner,eventID);local r=e and ensureFollow(e);if not r then return false,'Scheduled subscription storage is unavailable or full.'end
    if r.pending then if(r.pending.attempts or 0)>=3 then r.pending.attempts=0;r.pending.next=0;sendPending(r)end;return true end
    if A.Clock()<(S.queryAt[token(owner,eventID)]or 0)then return true end;return sendQuery(r)
end
function S.CanApply(owner,eventID)
    local r=S.Follow(owner,eventID);local route=currentRoute(owner)
    local inactive=r and(r.state=='NONE'or r.state=='WITHDRAWN'or r.state=='DECLINED')
    return inactive and route and route.scheduledGroups and r.verifiedSession==route.session and A.Clock()-(r.verifiedAt or-1000)<300 and r.snapshot.status=='OPEN'and r.snapshot.startsAt>A.Now()and not r.pending or false
end
sendPending=function(r)
    local route,contact=currentRoute(r.ownerKey);local p=r.pending;if not route or not route.scheduledGroups or not p then r.delivery='offline';return false end
    local wire=Z.Network3.Pack({'1',Z.session,route.session,r.id,p.contentRevision,p.seq,p.action,p.role,p.nonce})
    local queued=Z.Network3.QueueDirect(contact.target,'SA',wire,95,'SCHEDULEOP:'..token(r.ownerKey,r.id))
    r.delivery=queued and'pending'or'queued';p.next=A.Clock()+20;p.attempts=(p.attempts or 0)+1;return queued~=nil
end
function S.Apply(owner,eventID,role)
    -- The organizer cannot be reached: the application is left with the event's confirmed participants (ScheduledRelay.lua).
    if Z.ScheduledRelay and Z.ScheduledRelay.CanApply(owner,eventID)then return Z.ScheduledRelay.Apply(owner,eventID,role)end
    if not S.CanApply(owner,eventID)or not validRole(role)then return false,'Verify the event with its organizer before applying.'end
    local r=S.Follow(owner,eventID);if r.snapshot.roleSlots[role]<1 then return false,'This role has no scheduled slot.'end;if r.seq>=MAX then return false,'Scheduled revision limit reached.'end
    r.seq=r.seq+1;r.pending={action='APPLY',role=role,seq=r.seq,contentRevision=r.snapshot.contentRevision,nonce=L.NextID(Z.db,A.Now()),attempts=0,next=0};r.updatedAt=A.Now();sendPending(r);changed();return true
end
function S.CanWithdraw(owner,eventID)
    local r=S.Follow(owner,eventID)
    if Z.ScheduledRelay and Z.ScheduledRelay.CanWithdraw(owner,eventID)then return true end
    return r~=nil and editable()and(r.state=='REQUESTED'or r.state=='CONFIRMED'or r.state=='WAITLIST')and not r.pending and r.seq<MAX and r.snapshot.status=='OPEN'and r.snapshot.endsAt>A.Now()
end
function S.Withdraw(owner,eventID)
    if Z.ScheduledRelay and Z.ScheduledRelay.CanWithdraw(owner,eventID)then return Z.ScheduledRelay.Withdraw(owner,eventID)end
    local r=S.Follow(owner,eventID);if not S.CanWithdraw(owner,eventID)then return false,'No active scheduled application to withdraw.'end
    r.seq=r.seq+1;r.pending={action='WITHDRAW',role=L.Role(r.role)or'DAMAGER',seq=r.seq,contentRevision=r.snapshot.contentRevision,nonce=L.NextID(Z.db,A.Now()),attempts=0,next=0};r.updatedAt=A.Now();sendPending(r);changed();return true
end
function S.CanDecide(eventID,peer,state,expectedAppRevision)
    local e=S.GetOwned(eventID);local p=e and e.participants[peer]
    if not p or Z.db.blocked[peer]or not editable()or not S.Enabled()or e.status~='OPEN'or A.Now()>=e.startsAt or p.revision~=expectedAppRevision or(p.state~='REQUESTED'and p.state~='WAITLIST'and p.state~='CONFIRMED')or(state~='CONFIRMED'and state~='WAITLIST'and state~='DECLINED')then return false,'Application changed or event is closed.'end
    if p.state==state then return false,'Participant already has this status.'end
    local used=S.Counts(e);if state=='CONFIRMED'and p.state~='CONFIRMED'and used[p.role]>=e.roleSlots[p.role]then return false,'This role is already full. Use the waitlist.'end
    if p.revision>=MAX then return false,'Scheduled revision limit reached.'end
    return true
end
function S.Decide(eventID,peer,state,expectedAppRevision)
    local allowed,reason=S.CanDecide(eventID,peer,state,expectedAppRevision);if not allowed then return false,reason end
    local e=S.GetOwned(eventID);local p=e.participants[peer]
    local ok,why=bump(e,false);if not ok then return false,why end;p.state=state;p.revision=p.revision+1;p.reason='OK';local tok=token(peer,eventID);S.pushAt[tok]=0;S.pushAttempts[tok]=0;return true
end
local function auth(sender,f)
    local key=Z.ResolvePeerKey(sender);local route=key and currentRoute(key)
    if Z.Network3.meshContext or not route or not f or f[1]~='1'or f[2]~=route.session or f[3]~=Z.session then return nil end;return key,route
end
local function rate(key)
    local r=S.rates[key];local clock=A.Clock()
    if not r then if count(S.rates)>=512 then return false end;r={at=clock,tokens=8};S.rates[key]=r end
    r.tokens=math.min(8,r.tokens+math.max(0,clock-r.at));r.at=clock;if r.tokens<1 then return false end;r.tokens=r.tokens-1;return true
end
local function statusWire(e,p,route,nonce,reason)
    local h=headerFields(e);if not e.public then h[5]=e.status=='DRAFT'and''or'Private event';h[6]=e.createdAt;h[7]=e.createdAt+900;h[8],h[9],h[10]=0,0,1;h[11]=''end
    local values={'1',Z.session,route.session};for _,v in ipairs(h)do values[#values+1]=v end
    local tail={p and p.state or'NONE',p and p.role or'',p and p.seq or 0,p and p.revision or 0,nonce or'',reason or p and p.reason or'OK'};for _,v in ipairs(tail)do values[#values+1]=v end
    local used=e.public and S.Counts(e)or{TANK=0,HEALER=0,DAMAGER=0};for _,role in ipairs({'TANK','HEALER','DAMAGER'})do values[#values+1]=used[role]end;values[#values+1]=p and p.lastNonce or''
    return Z.Network3.Pack(values)
end
local function sendStatus(e,key,nonce,reason)
    local route,contact=currentRoute(key);if not route then return false end
    local queued=Z.Network3.QueueDirect(contact.target,'SS',statusWire(e,e.participants[key],route,nonce,reason),95,'SCHEDULESTATUS:'..token(key,e.id))
    return queued~=nil
end
local function receiveAction(key,f)
    if#f~=9 or not id(f[4])or not L.Int(tonumber(f[5]),1,MAX)or not L.Int(tonumber(f[6]),1,MAX)or(f[7]~='APPLY'and f[7]~='WITHDRAW')or not validRole(f[8])or not id(f[9])then return false end
    local e=S.GetOwned(f[4]);if not e then return false end
    local content,seq=tonumber(f[5]),tonumber(f[6]);local p=e.participants[key]
    if p and seq<=p.seq then
        if seq==p.seq and p.lastNonce==f[9]and p.lastAction==f[7]and p.lastContentRevision==content and p.role==f[8]then sendStatus(e,key,f[9]);return true end
        sendStatus(e,key,f[9],'STALE');return false
    end
    if content~=e.contentRevision then sendStatus(e,key,f[9],'STALE');return true end
    if e.status~='OPEN'or not e.public or not S.Enabled()or A.Now()>=e.endsAt or f[7]=='APPLY'and A.Now()>=e.startsAt then sendStatus(e,key,f[9],'CLOSED');return true end
    if not p and count(e.participants)>=S.MAX_PARTICIPANTS then sendStatus(e,key,f[9],'FULL');return true end
    if not p and f[7]=='WITHDRAW'then sendStatus(e,key,f[9],'STALE');return true end
    local ok=bump(e,false);if not ok then return false end
    p=p or{revision=0,ackEventRevision=0,ackAppRevision=0};e.participants[key]=p
    p.state=f[7]=='APPLY'and'REQUESTED'or'WITHDRAWN';p.role=f[8];p.seq=seq;p.revision=math.min(MAX,p.revision+1);p.lastNonce=f[9];p.lastAction=f[7];p.lastContentRevision=content;p.reason='OK'
    sendStatus(e,key,f[9]);local tok=token(key,e.id);S.pushAt[tok]=A.Clock()+20;S.pushAttempts[tok]=1;notify(e,'SCHEDULE_APPLICATION',Z.me.key,key);return true
end
local function receiveStatus(key,route,f)
    if#f~=24 then return false end
    local e=decodeHeader(f,4,key);local state,role,seq,revision=f[15],f[16],tonumber(f[17]),tonumber(f[18]);local nonce,reason=f[19],f[20]
    if not e or not APPS[state]or(role~=''and not validRole(role))or state~='NONE'and not validRole(role)or not L.Int(seq,0,MAX)or not L.Int(revision,0,MAX)or not L.Text(nonce,32,true)or nonce~=''and not id(nonce)or not REASONS[reason]then return false end
    e.used={TANK=tonumber(f[21]),HEALER=tonumber(f[22]),DAMAGER=tonumber(f[23])};if not usedCounts(e.used,e.roleSlots)then return false end
    local operationNonce=f[24];if not L.Text(operationNonce,32,true)or state~='NONE'and not id(operationNonce)then return false end
    local tok=token(key,e.id);local r=S.store.following[tok];if not r or e.revision<(r.authorityRevision or 0) or revision<r.appRevision then return false end
    local correlated=r.pending and nonce==r.pending.nonce or nonce~=''and nonce==S.queryNonce[tok]
    if nonce~=''and not correlated then return false end
    if r.pending and not correlated and seq<r.pending.seq then return false end
    if seq<(r.acceptedSeq or 0)or seq>r.seq or state~='NONE'and seq==0 then return false end
    if reason=='OK'and r.pending and nonce==r.pending.nonce and seq~=r.pending.seq then return false end
    if r.pending and seq==r.pending.seq and operationNonce~=r.pending.nonce then return false end
    if seq==r.acceptedSeq and seq>0 and operationNonce~=r.operationNonce then return false end
    local previous=r.state;local changedContent=e.contentRevision~=r.snapshot.contentRevision;r.snapshot=snapshot(e);r.state=state;r.role=role;r.appRevision=revision;r.updatedAt=A.Now();r.verifiedSession=route.session;r.verifiedAt=A.Clock();r.superseded=nil;r.relayed=nil;r.delivery=reason=='OK'and'verified'or reason
    if r.pending and(nonce==r.pending.nonce or seq==r.pending.seq and operationNonce==r.pending.nonce)then r.pending=nil end
    r.seq=math.max(r.seq,seq);r.acceptedSeq=seq;r.operationNonce=operationNonce;r.authorityRevision=e.revision;S.queryNonce[tok]=nil;S.querySentAt[tok]=nil;S.queryAt[tok]=A.Clock()+60
    local contact=Z.db.contacts[key];Z.Network3.QueueDirect(contact.target,'SK',Z.Network3.Pack({'1',Z.session,route.session,e.id,e.revision,revision}),85,'SCHEDULEACK:'..tok)
    if previous~=state or changedContent then notify(e,changedContent and'SCHEDULE_CHANGED'or'SCHEDULE_STATUS',key)end;changed();return true
end
function S.Receive(sender,kind,wire)
    if not S.store or type(wire)~='string'or#wire>1024 then return false end
    local f=Z.Network3.Unpack(wire);local key,route=auth(sender,f);if not key or not rate(key)then return false end
    if kind=='SH'then
        if#f~=4 or(f[4]~='H'and f[4]~='A')then return false end
        local first=not route.scheduledGroups;route.scheduledGroups=true
        if f[4]=='H'then Z.Network3.QueueDirect(sender,'SH',Z.Network3.Pack({'1',Z.session,route.session,'A'}),20,'SCHEDULEHELLOACK:'..key)end
        if first then S.OnPeerOnline(sender,route.session,true)end;return true
    elseif kind=='SA'then return receiveAction(key,f)
    elseif kind=='SQ'then
        if#f~=6 or not id(f[4])or not L.Int(tonumber(f[5]),1,MAX)or not id(f[6])then return false end
        local e=S.GetOwned(f[4]);if not e or not e.public and not e.participants[key]then return false end;sendStatus(e,key,f[6]);return true
    elseif kind=='SS'then return receiveStatus(key,route,f)
    elseif kind=='SK'then
        if#f~=6 or not id(f[4])or not L.Int(tonumber(f[5]),1,MAX)or not L.Int(tonumber(f[6]),0,MAX)then return false end
        local e=S.GetOwned(f[4]);local p=e and e.participants[key]
        if not p or tonumber(f[5])~=e.revision or tonumber(f[6])~=p.revision then return false end;p.ackEventRevision=e.revision;p.ackAppRevision=p.revision;S.pushAt[token(key,e.id)]=nil;return true
    elseif kind=='SX'then return Z.ScheduledRelay~=nil and Z.ScheduledRelay.Receive(key,route,f)or false
    end;return false
end
function S.Block(key)
    if not S.store then return end
    for _,e in pairs(S.store.owned)do local p=e.participants[key];if p then p.state='WITHDRAWN';p.revision=math.min(MAX,p.revision+1);bump(e,false);S.pushAt[token(key,e.id)]=nil end end
    for tok,r in pairs(S.store.following)do if r.ownerKey==key then r.pending=nil;r.verifiedSession=nil;r.delivery='blocked';S.queryAt[tok]=nil end end;changed()
end
function S.PrivacyChanged()
    if not S.store then return end
    if not Z.db.consent or not Z.db.visible or not Z.db.autoDiscovery then
        for _,e in pairs(S.store.owned)do if e.status=='OPEN'then e.status='CANCELLED';e.public=false;bump(e,true);invalidateApps(e,'PRIVACY')end end
        for _,r in pairs(S.store.following)do r.verifiedSession=nil end
        if Z.ScheduledMesh then Z.ScheduledMesh.PrivacyChanged()end
    end;changed()
end
function S.Verified(owner,eventID)
    local r=S.Follow(owner,eventID);local route=currentRoute(owner)
    return r~=nil and route~=nil and r.verifiedSession==route.session and A.Clock()-(r.verifiedAt or-1000)<300 or false
end
function S.Participation(owner,eventID)
    if owner==Z.me.key then return Z.T('Organizer')end
    local r=S.Follow(owner,eventID);if not r then return Z.T('No application')end
    local state,_,carried=r.state,nil,false;if Z.ScheduledRelay then state,_,carried=Z.ScheduledRelay.Effective(r)end
    if carried then return S.StateLabel(state)..' · '..Z.T('Carried on; not yet confirmed by the organizer')end
    if r.pending then return Z.T(r.pending.action=='WITHDRAW'and'Withdrawal pending'or'Application pending')..(r.pending.deposited and' · '..S.DeliveryLabel('deposited')or'')end
    local current=S.Verified(owner,eventID)
    return S.StateLabel(r.state)..(current and''or' · '..Z.T('Saved state; verification pending'))
end
local function reminders()
    local now=A.Now();local examined=0
    for _,e in ipairs(S.List(true))do
        local following=S.Follow(e.ownerKey,e.id);local eligible=e.ownerKey==Z.me.key or following and following.state=='CONFIRMED'and not following.pending
            or following and Z.ScheduledRelay and Z.ScheduledRelay.Effective(following)=='CONFIRMED'
        if eligible and e.status=='OPEN'then
            local tok=token(e.ownerKey,e.id);local mark=S.store.reminded[tok];if not mark or mark.contentRevision~=e.contentRevision then mark={contentRevision=e.contentRevision,stage=0};S.store.reminded[tok]=mark end
            local delta=e.startsAt-now;local stage=delta<=0 and 3 or delta<=600 and 2 or delta<=1800 and 1 or 0
            if stage>mark.stage then mark.stage=stage
                if now<e.endsAt and delta>=-600 and examined<4 then S.store.reminderSeq=math.min(MAX,S.store.reminderSeq+1)
                    if Z.Notifications and Z.Notifications.store then Z.Notifications.Push('groups','scheduled','schedule-reminder:'..tok,S.store.reminderSeq,'SCHEDULE_REMINDER_'..stage,e.ownerKey,e.id,e.activity,nil)end;examined=examined+1 end
            end
        end
    end
end
-- One pass over the followed events (see the rules above).
local function carry(now,clock)
    if clock<(S.nextCarry or 0)then return end;S.nextCarry=clock+15;S.carryAt=S.carryAt or{}
    local mesh=Z.ScheduledMesh;if not mesh or not mesh.Relay or not S.Enabled()then return end
    for tok,r in pairs(S.store.following)do local e=r.snapshot
        if r.announced and r.ownerSession and not r.pending and not Z.db.blocked[r.ownerKey]and e.endsAt>now and e.startsAt<=now+S.CARRY_HORIZON
            and not Z.IsOnline(r.ownerKey)and clock>=(S.carryAt[tok]or 0)then
            local contact=Z.db.contacts[r.ownerKey];local epoch=tonumber(r.ownerSession:match('^(%d+)%.'))
            if contact and epoch then
                local record=mesh.records and mesh.records[L.Identity(contact.target)..'/SE/'..e.id]
                local seen=record and record.scheduledWire==record.wire and record.scheduledDecoded or nil
                local seenEpoch=seen and tonumber(record.session:match('^(%d+)%.'))or 0
                local carried=seen and carriedSession(record.session)
                if seen and(seenEpoch>epoch or seenEpoch==epoch and newerState(seen,e))then
                    -- Somebody knows a newer state of this event: stay quiet until the organizer verifies this one again.
                    if r.superseded~=seen.contentRevision then r.superseded=seen.contentRevision;changed()end;S.carryAt[tok]=clock+60
                elseif r.superseded then S.carryAt[tok]=clock+60
                else
                    local stale=carried and(seenEpoch<epoch or newerState(e,seen))
                    if seen and not stale and(not carried and now-record.at<=900 or carried and now-record.at<S.CARRY_INTERVAL)then
                        S.carryAt[tok]=clock+30 -- alive: the organizer's own record, or a carried one of this state
                    elseif stale or CARRIER[r.state]and e.status=='OPEN'then
                        -- Either a correction of an older carried state (also for a closed event and from a former
                        -- participant), or the regular repetition by a participant.
                        local session=epoch..'.0.0';local used=e.used or{TANK=0,HEALER=0,DAMAGER=0}
                        local values={'1',session,now,Z.me.faction};for _,v in ipairs(headerFields(e))do values[#values+1]=v end
                        for _,role in ipairs({'TANK','HEALER','DAMAGER'})do values[#values+1]=used[role]or 0 end
                        -- Rank inside the carried session: content revision, closed before open, then time (20 s steps).
                        local seq=math.min(e.contentRevision,1022)*2097152+(e.status~='OPEN'and 1048576 or 0)+math.floor(now/20)%1048576
                        local sent=mesh.Relay(contact.target,session,seq,now,'SE',Z.Network3.Pack(values))
                        S.carryAt[tok]=clock+(sent and S.CARRY_INTERVAL+math.random(0,60)or 120)
                    else S.carryAt[tok]=clock+60 end
                end
            end
        end
    end
end
function S.Tick()
    S.DecodePending()
    if not S.store or not Z.db or A.Now()<1 or A.Clock()<S.nextTick then return end;S.nextTick=A.Clock()+1
    local now,clock=A.Now(),A.Clock();local sent=0
    for _,e in pairs(S.store.owned)do
        if(e.status=='OPEN'or e.status=='DRAFT')and now>=e.endsAt then e.status='FINISHED';bump(e,false);pushAll(e)end
        if S.Enabled()and(e.public and(e.status=='OPEN'or now-e.updatedAt<=1800)or S.withdrawn[e.id])and clock>=(S.announceAt[e.id]or 0)and clock>=S.nextPublish then
            if Z.ScheduledMesh.Publish('SE',S.Record(e))then S.announceAt[e.id]=clock+600;S.withdrawn[e.id]=nil;S.nextPublish=clock+1 end
        end
        for peer,p in pairs(e.participants)do local tok=token(peer,e.id)
            if not Z.db.blocked[peer]and S.pushAt[tok]and clock>=S.pushAt[tok]and(S.pushAttempts[tok]or 0)<3 and sent<4 and currentRoute(peer)then
                if sendStatus(e,peer,'')then S.pushAt[tok]=clock+20;S.pushAttempts[tok]=(S.pushAttempts[tok]or 0)+1;sent=sent+1 end
            end
        end
    end
    for tok,r in pairs(S.store.following)do
        if S.queryNonce[tok]and S.querySentAt[tok]and clock-S.querySentAt[tok]>=20 and r.delivery=='querying'then r.delivery='unconfirmed';changed()end
        if not Z.db.blocked[r.ownerKey]and r.snapshot.endsAt>now-86400 and sent<4 then
            if r.pending and clock>=(r.pending.next or 0)and(r.pending.attempts or 0)<3 then if sendPending(r)then sent=sent+1 end
            elseif r.pending and(r.pending.attempts or 0)>=3 and clock>=(r.pending.next or 0)then r.delivery='unconfirmed'
            elseif not r.pending and r.state~='NONE'and clock>=(S.queryAt[tok]or 0)then if sendQuery(r)then sent=sent+1 end end
        end
    end
    carry(now,clock)
    if Z.ScheduledRelay then Z.ScheduledRelay.Tick(now,clock)end
    reminders()
    if clock>=S.nextPrune then
        S.nextPrune=clock+60
        for key,e in pairs(S.store.owned)do if(e.status=='FINISHED'or e.status=='CANCELLED')and now-math.max(e.endsAt,e.updatedAt)>30*86400 then dropOwned(key);changed()end end
        for key,r in pairs(S.store.following)do if now-r.snapshot.endsAt>30*86400 then S.store.following[key]=nil;S.queryAt[key]=nil;S.queryNonce[key]=nil;S.querySentAt[key]=nil;changed()end end
        for key in pairs(S.store.reminded)do local keep=false;for _,e in pairs(S.store.owned)do if key==token(e.ownerKey,e.id)then keep=true;break end end;if not keep and not S.store.following[key]then S.store.reminded[key]=nil end end
        for key,at in pairs(S.hellos)do if clock-at>600 then S.hellos[key]=nil end end
        for key in pairs(S.syncedSessions)do if not currentRoute(key)then S.syncedSessions[key]=nil end end
        for key,r in pairs(S.rates)do if clock-r.at>300 then S.rates[key]=nil end end
    end
end
-- For ScheduledRelay.lua, which continues this module.
S.internal={MAX=MAX,id=id,validRole=validRole,currentRoute=currentRoute,ensureFollow=ensureFollow,receiveAction=receiveAction,notify=notify,changed=changed}
return S
