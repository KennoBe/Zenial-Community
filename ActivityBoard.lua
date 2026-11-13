-- A read-only local view of existing finder, quest, PvP and scheduled records.
-- IDs retain their source and owner. This module never queues network operations.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local B={};Z.ActivityBoard=B
local function day(at)
    local T=Z.ScheduleTime;local now=T.Local(A.Now());local other=T.Local(at)
    if not now or not other then now=T.UTC(A.Now());other=T.UTC(at)end
    return now and other and now.year==other.year and now.month==other.month and now.day==other.day or false
end
B.IsToday=day
local function activeApplication(p)return p and p.state~='withdrawn'and p.state~='rejected'end
local function app(kind,owner,id)
    if kind=='EVENT'then local p=Z.ScheduledGroups.Follow(owner,id);return p and(p.pending or p.state=='REQUESTED'or p.state=='CONFIRMED'or p.state=='WAITLIST')and p or nil end
    local bucket=kind=='QUEST'and Z.db.sentQuestApplications or Z.db.sentApplications
    local p=bucket[id]and bucket[id][owner];return activeApplication(p)and p or nil
end
local function name(owner)
    local c=Z.db.contacts[owner];return owner==Z.me.key and Z.me.target or c and c.target or owner
end
local function row(kind,owner,id,title,starts,ends,data)
    return{key=kind..':'..owner..':'..id,kind=kind,owner=owner,id=id,title=title,startsAt=starts,endsAt=ends,data=data,
        ownerName=(not Z.db.contacts[owner]and owner~=Z.me.key and data and data.ownerTarget)or name(owner),own=owner==Z.me.key,category=(kind=='QUEST'or title=='Questing'or title=='Level together')and'QUEST'or kind=='PVP'and'PVP'or Z.GroupFinder.ActivityKind(title),application=app(kind,owner,id)}
end
local function build()
    local out,seen={},{};local now=A.Now()
    local function add(r)if not seen[r.key]and not Z.db.blocked[r.owner]then seen[r.key]=true;out[#out+1]=r end end
    local function live(owner,g,kind)
        if kind=='QUEST'then if not L.ValidQuest(g,now)then return end;add(row(kind,owner,g.id,g.title,now,g.expires,g))
        else if not L.ValidGroup(g,now)then return end;add(row('LIVE',owner,g.id,g.activity,g.start,g.expires,g))end
    end
    if Z.db.lfg[1]then live(Z.me.key,Z.db.lfg[1])end
    if Z.db.quest then live(Z.me.key,Z.db.quest,'QUEST')end
    local inspected=0
    if Z.db.consent then for owner,p in pairs(Z.db.peers)do
        inspected=inspected+1;if inspected>L.MAX_CONTACTS then break end
        if owner~=Z.me.key and Z.db.contacts[owner]and not Z.db.blocked[owner]and Z.IsOnline(owner)then
            local data=p.data
            if data and(not p.cap4 or data.generation==(p.verifiedSession or p.session))then
                if data.group or data.lfg and data.lfg[1]then live(owner,data.group or data.lfg[1])end
                if data.quest then live(owner,data.quest,'QUEST')end
            end
        end
    end end
    for _,e in ipairs(Z.ScheduledGroups.List(true))do
        local application=app('EVENT',e.ownerKey,e.id)
        if e.endsAt>now and e.status=='OPEN'then
            local r=row('EVENT',e.ownerKey,e.id,e.activity,e.startsAt,e.endsAt,e);r.saved=not r.own and not e.announcement and not Z.ScheduledGroups.Verified(e.ownerKey,e.id);add(r)
        end
    end
    for _,r in ipairs(Z.PvPHelp.ListReceived())do add(row('PVP',r.key,r.id,'Open World PvP',now,r.expires,r))end
    local own=Z.PvPHelp.Own();if own then add(row('PVP',Z.me.key,own.id,'Open World PvP',now,own.expires,own))end
    -- Retain active saved applications when the organizer/profile is offline.
    for _,kind in ipairs({'LIVE','QUEST'})do
        local bucket=kind=='QUEST'and Z.db.sentQuestApplications or Z.db.sentApplications;inspected=0
        for id,people in pairs(bucket)do for owner,p in pairs(people)do
            inspected=inspected+1;if inspected>5000 then break end
            local key=kind..':'..owner..':'..id
            if not seen[key]and activeApplication(p)and p.at and p.at>now-86400 and not Z.db.blocked[owner]then
                local title=Z.History.FindContent(kind=='LIVE'and'group'or'quest',id,owner)
                local r=row(kind,owner,id,title~=''and title or Z.T('Saved activity'),p.at,p.at+86400,nil);r.saved=true;add(r)
            end
        end;if inspected>5000 then break end end
    end
    table.sort(out,function(a,b)if a.startsAt~=b.startsAt then return a.startsAt<b.startsAt end;return a.key<b.key end)
    return out
end
function B.List(filter)
    if not Z.db then return{}end
    local clock=A.Clock();if not B.cache or B.cache.db~=Z.db or B.cache.rev~=Z.viewRevision or clock>=B.cache.untilAt then
        B.cache={db=Z.db,rev=Z.viewRevision,untilAt=clock+5,rows=build()}
    end
    filter=filter or{};local out={};local query=string.lower(filter.query or'');local now=A.Now()
    for _,r in ipairs(B.cache.rows)do
        local time=filter.when or'ALL';local mine=filter.mine or'ALL';local category=filter.category or'ALL'
        if not Z.db.blocked[r.owner]and r.endsAt>now and(time=='ALL'or time=='NOW'and r.startsAt<=now+120 or time=='TODAY'and day(math.max(now,r.startsAt))or time=='LATER'and r.startsAt>now+120)
            and(mine=='ALL'or mine=='ORGANIZED'and r.own or mine=='APPLICATIONS'and r.application)
            and(category=='ALL'or r.category==category)and(query==''or string.lower(r.title..' '..r.ownerName):find(query,1,true))then out[#out+1]=r end
    end
    return out
end
function B.Get(key)for _,r in ipairs(B.List())do if r.key==key then return r end end end
return B
