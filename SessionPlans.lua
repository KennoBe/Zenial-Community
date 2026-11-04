-- Private per-character session wishes. Uses existing quest and finder evidence;
-- never publishes wishes, requests profiles, queues messages or sends whispers.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local G,F,Q=Z.QuestGroups,Z.GroupFinder,Z.QuestHelper
local P={VERSION=2,MAX_WISHES=3,MAX_CANDIDATES=40,MAX_RESULTS=10,SCAN_BATCH=50,SCAN_SECONDS=.004,MIN_MINUTES=15,MAX_MINUTES=480,DEFAULT_MINUTES=120};Z.SessionPlans=P
local KINDS={QUEST=true,DUNGEON=true,RAID=true,PVP=true,FARM=true,LEVEL=true,CUSTOM=true}
local LABELS={NONE="No wish",QUEST="Questing",DUNGEON="Dungeon",RAID="Raid",PVP="PvP",FARM="Farm materials",LEVEL="Level together",CUSTOM="Custom activity"}
local function trim(text)return text:match("^%s*(.-)%s*$")end
local function empty(duration,at)return{version=P.VERSION,updatedAt=at or 0,expiresAt=0,duration=duration or P.DEFAULT_MINUTES,mode='DAY',dayKey='',dayBasis='LOCAL',wishes={}}end
local function validList(raw)
    if type(raw)~="table"then return nil,"Session wishes are invalid."end
    local n=0;for key in pairs(raw)do n=n+1;if n>P.MAX_WISHES or not L.Int(key,1,P.MAX_WISHES)then return nil,"Choose no more than three wishes."end end
    if n~=#raw then return nil,"Session wishes are invalid."end
    local out,seen,priorities={},{},{}
    for index=1,n do
        local row=raw[index];if type(row)~="table"or not KINDS[row.kind]then return nil,"Session wish type is invalid."end
        local priority=row.priority==nil and index or row.priority;if not L.Int(priority,1,P.MAX_WISHES)or priorities[priority]then return nil,"Wish priorities must be distinct: 1 to 3."end
        if row.label~=nil and not L.Text(row.label,96,true)then return nil,"Private wish text is too long."end
        local wish={id=tostring(priority),kind=row.kind,priority=priority,targetID=0,activity="",label=""}
        if row.kind=="QUEST"then
            wish.targetID=row.targetID==nil and 0 or row.targetID;if not L.Int(wish.targetID,0,10000000)then return nil,"Quest ID is invalid."end
        elseif F.Activities[row.kind]then
            wish.activity=L.ActivityID(row.activity);if not L.Text(wish.activity,64)or F.ActivityKind(wish.activity)~=row.kind then return nil,"Choose a known activity or use a custom wish."end
        elseif row.kind=="FARM"or row.kind=="CUSTOM"then
            wish.label=trim(row.label or"");if wish.label==""then return nil,"Enter a private activity or material name."end
        end
        local signature=wish.kind..":"..tostring(wish.targetID)..":"..wish.activity..":"..string.lower(wish.label)
        if seen[signature]then return nil,"Duplicate wishes are not allowed."end
        seen[signature],priorities[priority]=true,true;out[#out+1]=wish
    end
    table.sort(out,function(a,b)return a.priority<b.priority end);return out
end
-- Controlled version 0/unversioned migration. Future versions are preserved by
-- Initialize and disable edits; malformed known data is rejected, never merged.
function P.Normalize(raw,now)
    if raw==nil then return empty()end
    if type(raw)~="table"then return empty(),"invalid"end
    if raw.version~=nil and raw.version~=0 and raw.version~=1 and raw.version~=P.VERSION then return nil,"unsupported"end
    local at=raw.updatedAt==nil and 0 or raw.updatedAt;local expires=raw.expiresAt==nil and 0 or raw.expiresAt
    if not L.Int(at,0,4102444800)or not L.Int(expires,0,4102444800)then return empty(),"invalid"end
    local duration=raw.duration==nil and P.DEFAULT_MINUTES or raw.duration
    if raw.duration==nil and(raw.version==nil or raw.version==0)and expires>at then duration=(expires-at)/60 end
    if not L.Int(duration,P.MIN_MINUTES,P.MAX_MINUTES)then return empty(),"invalid"end
    local wishes=validList(raw.wishes==nil and{}or raw.wishes);if not wishes then return empty(),"invalid"end
    if L.Int(now,1,4102444800)and at>now+120 then return empty(),"invalid"end
    local mode=raw.version==P.VERSION and raw.mode or 'TIMED'
    if mode~='DAY'and mode~='TIMED'then return empty(),"invalid"end
    local dayKey=mode=='DAY'and raw.dayKey or '';local basis=mode=='DAY'and raw.dayBasis or''
    if mode=='DAY'and basis~='LOCAL'and basis~='UTC'then return empty(),"invalid"end
    if mode=='DAY'and(type(dayKey)~='string'or(#wishes>0 and (not dayKey:match('^%d%d%d%d%-%d%d%-%d%d$')or not Z.ScheduleTime.Parse(dayKey..' 00:00','UTC'))))then return empty(),"invalid"end
    if #wishes>0 and(at<1 or expires<=at or mode=='TIMED'and expires~=at+duration*60 or mode=='DAY'and expires-at>27*3600)then return empty(),"invalid"end
    if #wishes==0 and expires~=0 then return empty(),"invalid"end
    return{version=P.VERSION,updatedAt=at,expiresAt=expires,duration=duration,mode=mode,dayKey=dayKey,dayBasis=basis,wishes=wishes}
end
function P.Initialize()
    P.store,P.loadError=P.Normalize(Z.db.sessionPlans,A.Now());P.revision=0;P.expired=false;P.pool,P.scan=nil,nil;P.dayCheckedAt,P.dayKey=nil,nil
    if P.store then
        local today,ends,localDay=Z.ScheduleTime.DayBounds(A.Now())
        if P.store.mode=='TIMED'and type(Z.db.sessionPlans)=='table'and Z.db.sessionPlans.version~=P.VERSION and #P.store.wishes>0 then
            local savedDay=Z.ScheduleTime.DayBounds(P.store.updatedAt)
            if today then if savedDay==today then P.store.mode='DAY';P.store.dayKey=today;P.store.dayBasis=localDay and'LOCAL'or'UTC';P.store.expiresAt=ends else P.store=empty(P.store.duration,A.Now())end end
        elseif P.store.mode=='DAY'and #P.store.wishes>0 then
            local currentDay=Z.ScheduleTime.DayKey(A.Now(),P.store.dayBasis)
            if currentDay and currentDay~=P.store.dayKey or A.Now()>=P.store.expiresAt then P.store=empty(P.store.duration,A.Now())end
        end
        Z.db.sessionPlans=P.store
    end
end
function P.Invalidate()P.pool,P.scan=nil,nil;P.revision=(P.revision or 0)+1 end
local function changed()P.Invalidate();if Z.MarkDirty then Z.MarkDirty("sessionPlans")end end
-- UI saves for the local day. Explicit minute lifetimes remain readable for
-- compatibility; reload never copies or renews another character's wishes.
function P.Save(wishes,minutes)
    if not P.store then return false,"Saved session wishes use an unsupported version. Data was preserved."end
    local rows,reason=validList(wishes);if not rows then return false,reason end
    local daily=minutes==nil;minutes=minutes or P.DEFAULT_MINUTES;if not L.Int(minutes,P.MIN_MINUTES,P.MAX_MINUTES)then return false,"Session duration must be 15 to 480 minutes."end
    local now=A.Now();if not L.Int(now,1,4102444800)or now+minutes*60>4102444800 then return false,"Server time is unavailable."end
    local dayKey,ends,localDay;if daily then dayKey,ends,localDay=Z.ScheduleTime.DayBounds(now)end
    if daily and not dayKey then return false,"Server time is unavailable."end
    P.store=#rows==0 and empty(minutes,now)or{version=P.VERSION,updatedAt=now,expiresAt=daily and ends or now+minutes*60,duration=minutes,mode=daily and 'DAY'or'TIMED',dayKey=daily and dayKey or'',dayBasis=daily and(localDay and'LOCAL'or'UTC')or'',wishes=rows}
    Z.db.sessionPlans=P.store;P.loadError=nil;P.expired=false;changed();return true
end
function P.End()
    if not P.store then return false,"Saved session wishes use an unsupported version. Data was preserved."end
    P.store=empty(P.store.duration,A.Now());Z.db.sessionPlans=P.store;P.loadError=nil;P.expired=false;changed();return true
end
function P.State()
    if not P.store then return"unsupported"end
    if #P.store.wishes==0 then return"empty"end
    if A.Now()<1 then return"unknown"end
    local today
    if P.store.mode=='DAY'then
        local now=A.Now()
        if not P.dayCheckedAt or P.dayBasis~=P.store.dayBasis or now<P.dayCheckedAt or now-P.dayCheckedAt>=5 then P.dayCheckedAt=now;P.dayBasis=P.store.dayBasis;P.dayKey=Z.ScheduleTime.DayKey(now,P.store.dayBasis)end
        today=P.dayKey
    end
    return(A.Now()>=P.store.expiresAt or today and today~=P.store.dayKey)and"expired"or"active"
end
function P.KindLabel(kind)return Z.T(LABELS[kind]or"No wish")end
function P.WishLabel(wish)
    if wish.kind=="QUEST"then
        if wish.targetID==0 then return Z.T("Any shared quests")end
        for _,quest in ipairs(Q.quests or{})do if quest.id==wish.targetID then return quest.title.." (#"..wish.targetID..")"end end
        return Z.T("Quest #%d",wish.targetID)
    end
    if wish.activity~=""then return Z.Locale.Activity(wish.activity)end
    return wish.label~=""and wish.label or P.KindLabel(wish.kind)
end
local function own(key,target)
    if key==Z.me.key then return true end
    local identity=L.Identity(target);for _,character in pairs(Z.account and Z.account.characters or{})do if L.Identity(character.target)==identity then return true end end
    return false
end
local function enabled()return P.State()=="active"and Z.db.consent and Z.identityReady and not Z.offlineOnly end
local function offer(key)
    local peer=Z.db.peers[key];local data=peer and peer.data;local g=data and(data.group or data.lfg and data.lfg[1]);local now=A.Now()
    if peer and peer.cap4 and data and data.generation~=(peer.verifiedSession or peer.session)then return nil end
    if not g or not L.ValidGroup(g,now)or g.start>now+120 or not Z.FindForeignGroup(key,g.id)then return nil end
    if not F.Matches(g,Z.me.level)then return nil end
    return g
end
local function offerMatches(wish,g)
    if not g then return false end
    if F.Activities[wish.kind]then return wish.activity==L.ActivityID(g.activity)end
    return(wish.kind=="CUSTOM"or wish.kind=="FARM")and F.ActivityKind(g.activity)=="CUSTOM"and string.lower(trim(g.activity))==string.lower(wish.label)
end
local function member(key)
    local c,p=Z.db.contacts[key],Z.db.peers[key]
    if not c or not p or Z.db.blocked[key]or own(key,c.target)or not Z.IsOnline(key)then return nil end
    local presence=p.presence;local at=presence and(presence.sourceAt or presence.at)
    local current=presence and L.Int(at,1,4102444800)and at<=A.Now()+120 and A.Now()-at<300
    local availability=current and presence.availability or"UNKNOWN";local grouped=A.GroupMembers()[key]~=nil
    local status=availability=="AFK"and"AFK"or availability=="BUSY"and"Busy"or grouped and"Your group"or availability=="GROUP"and"In group"or availability=="AVAILABLE"and"Available"or"Unknown"
    return{key=key,target=c.target,level=current and presence.level or 0,classFile=current and presence.classFile or"",inGroup=grouped,free=not grouped and availability=="AVAILABLE",status=status}
end
local function evaluate(key,quest,g)
    local entry=member(key);if not entry then return nil end
    local shared=quest and quest.ids or{};local count=quest and quest.common or 0
    entry.score,entry.reasons,entry.questID=0,{},nil
    for _,wish in ipairs(P.store.wishes)do
        local weight=4-wish.priority;local reason,points
        if wish.kind=="QUEST"and wish.targetID>0 and shared[wish.targetID]then
            reason=Z.T("Shared quest: %s",P.WishLabel(wish));points=100;entry.questID=entry.questID or wish.targetID
        elseif(wish.kind=="QUEST"and wish.targetID==0 or wish.kind=="LEVEL")and count>0 then
            reason=Z.T("%d shared quests",count);points=20+math.min(count,20);entry.questID=entry.questID or quest.quests[1]
        elseif offerMatches(wish,g)then
            reason=Z.T("Published group offer: %s",Z.Locale.Activity(g.activity));points=100;entry.groupID=g.id
        end
        if reason then entry.score=entry.score+weight*points;entry.reasons[#entry.reasons+1]=Z.T("Wish %d: %s",wish.priority,reason)end
    end
    if entry.score==0 then return nil end
    if entry.free then entry.score=entry.score+10;entry.reasons[#entry.reasons+1]=Z.T("Reported available")
    elseif entry.inGroup then entry.reasons[#entry.reasons+1]=Z.T("Already in your group")end
    return entry
end
local function questFromCoverage(key)
    local c=G.GetCoverage({key});if not c then return nil end
    local set={};for _,id in ipairs(c.coverageIDs)do set[id]=true end
    return{ids=set,common=c.coverageCount,quests=c.coverageIDs}
end
local function wantsQuests()
    for _,w in ipairs(P.store.wishes)do if w.kind=="QUEST"or w.kind=="LEVEL"then return true end end;return false
end
-- Click-time revalidation. Scores cannot turn stale claims into actions.
function P.Match(key)
    if not enabled()or type(key)~="string"then return nil end
    return evaluate(key,wantsQuests()and questFromCoverage(key)or nil,offer(key))
end
local function better(a,b)
    if a.score~=b.score then return a.score>b.score end
    if a.free~=b.free then return a.free end
    if a.target~=b.target then return a.target<b.target end;return a.key<b.key
end
local function insert(out,entry)
    if not entry then return end
    local index=1;while index<=#out and not better(entry,out[index])do index=index+1 end
    if index<=P.MAX_CANDIDATES then table.insert(out,index,entry);if #out>P.MAX_CANDIDATES then table.remove(out)end end
end
local function poolFrom(entries)
    P.pool={};for _,entry in ipairs(entries)do P.pool[#P.pool+1]=entry.key end
end
local function startScan()
    local entries,seen={},{};local questWanted=wantsQuests()
    if questWanted then
        local candidates=G.CurrentCandidates()
        for _,q in ipairs(candidates)do seen[q.key]=true;insert(entries,evaluate(q.key,q,offer(q.key)))end
    end
    for _,key in ipairs(P.pool or{})do if not seen[key]then seen[key]=true;insert(entries,P.Match(key))end end
    local keys={};local wantsOffer=false
    for _,w in ipairs(P.store.wishes)do if F.Activities[w.kind]or w.kind=="CUSTOM"or w.kind=="FARM"then wantsOffer=true end end
    -- The phase-1 pool is a fast seed, not a hard recall limit: a specific wish
    -- may match someone with fewer total overlaps outside that initial top 40.
    if wantsOffer or questWanted then for key in pairs(Z.db.peers)do if #keys>=L.MAX_CONTACTS then break end;keys[#keys+1]=key end end
    poolFrom(entries)
    if #keys>0 then P.scan={keys=keys,index=1,entries=entries,seen=seen,questWanted=questWanted};P.nextBatch=0
    else P.scan=nil;P.nextScan=A.Clock()+5 end
end
local function scanBatch()
    local scan=P.scan;if not scan or A.Clock()<(P.nextBatch or 0)then return end
    local started=A.Clock();local count=0;P.nextBatch=started+.25
    while scan.index<=#scan.keys and count<P.SCAN_BATCH do
        if count>0 and A.Clock()-started>=P.SCAN_SECONDS then break end
        local key=scan.keys[scan.index];scan.index=scan.index+1;count=count+1
        if not scan.seen[key]then
            local g=offer(key);local match=false;for _,w in ipairs(P.store.wishes)do if offerMatches(w,g)then match=true;break end end
            if scan.questWanted or match then insert(scan.entries,evaluate(key,scan.questWanted and questFromCoverage(key)or nil,g))end
        end
    end
    poolFrom(scan.entries)
    if scan.index>#scan.keys then P.scan=nil;P.nextScan=A.Clock()+5 end
    if Z.MarkDirty then Z.MarkDirty("sessionMatches")end
end
-- Bounded top-40 selection, progressively scanning existing group offers. No
-- full community sort or second quest algorithm. Repeated calls only revalidate
-- the retained pool; the existing 0.25-second tick advances one bounded batch.
function P.BuildMatches(options)
    local state=P.State();local meta={state=state,mode="local",questState="unknown"};local out={}
    if not enabled()then meta.exchange=Z.db.consent and not Z.offlineOnly;return out,meta end
    if not P.pool or not P.scan and A.Clock()>=(P.nextScan or 0)then startScan();scanBatch()end
    for _,key in ipairs(P.pool)do insert(out,P.Match(key))end
    meta.questState=Q.sampleAt and A.Now()-Q.sampleAt<=Q.TTL and Q.scanState=="ready"and"ready"or"unknown"
    meta.considered=#out;meta.pending=P.scan and(#P.scan.keys-P.scan.index+1)or 0
    local limit=type(options)=="table"and L.Int(options.maxResults,1,P.MAX_RESULTS)and options.maxResults or P.MAX_RESULTS
    while #out>limit do table.remove(out)end;return out,meta
end
function P.Tick()
    if P.State()=="expired"and not P.expired then
        if P.store.mode=='DAY'then P.store=empty(P.store.duration,A.Now());Z.db.sessionPlans=P.store end
        P.expired=true;changed()
    end
    if not enabled()then P.pool,P.scan=nil,nil;return end
    if P.scan then scanBatch()end
end
function P.CanInvite(key)
    local entry=P.Match(key);if not entry then return false,"Session match no longer available."end
    if entry.status=="Unknown"then return false,"Player availability is unknown."end
    if entry.questID then return Q.CanInvite(key,entry.questID)end
    if not entry.free or entry.inGroup then return false,"Player is unavailable or already grouped."end
    if Q.invites[key]and A.Clock()<Q.invites[key]then return false,"Invitation pending."end
    local state=A.GroupState();if not state.canInvite then return false,"You cannot invite players."end
    local limit=A.Call(IsInRaid)==true and(MAX_RAID_MEMBERS or 40)or(MAX_PARTY_MEMBERS and MAX_PARTY_MEMBERS+1 or 5)
    if state.total>=limit then return false,"The group is full."end
    return true
end
function P.Invite(key)
    local ok,reason=P.CanInvite(key);if not ok then return false,reason end
    local entry=P.Match(key);if not entry then return false,"Session match no longer available."end
    if entry.questID then return Q.Invite(key,entry.questID)end
    ok,reason=A.Invite(entry.target);if ok then Q.invites[key]=A.Clock()+60;changed()end;return ok,reason
end
function P.Whisper(key)
    local entry=P.Match(key);if not entry then return false,"Session match no longer available."end
    if not A.Whisper(entry.target)then return false,"Whisper input is unavailable."end;return true
end
return P
