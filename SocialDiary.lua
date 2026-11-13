-- Private encounter diary. Account-scoped like favorites and notes, stored only
-- in SavedVariables. No profile field, transport, mesh or companion topic reads
-- this store, and chat messages are never recorded.
-- The diary is always on and records the players you were in a group with. Players who were only
-- targeted, hovered or seen nearby are no longer recorded; rows and events an earlier version stored
-- for them stay in SavedVariables untouched but are not listed.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local D={VERSION=1,MAX_PLAYERS=2000,PRUNE_TO=1900,MAX_EVENTS=30,RETENTION=180*86400,EVENT_RETENTION=365*86400,
    GAP=1800,GROUP_THROTTLE=10,DUNGEON_GAP=4*3600}
Z.SocialDiary=D
-- Event kinds a stored row may carry. Only group and dungeon are still written.
local KINDS={target=true,mouseover=true,nameplate=true,group=true,dungeon=true}
local SOURCES={"target","mouseover","nameplate","group"}
local MAX_TIME=4102444800

local function defaults()
    return{version=D.VERSION,enabled=false,sources={target=true,mouseover=true,nameplate=true,group=true},players={}}
end
local function changed()
    D.revision=(D.revision or 0)+1
end
local function validEvent(e,now)
    return type(e)=="table"and KINDS[e.kind]and L.Int(e.at,1,MAX_TIME)and e.at>=now-D.EVENT_RETENTION
        and L.Text(e.zone or"",64,true)and(e.detail==nil or L.Text(e.detail,96))
end
-- Copies only known fields; anything else in SavedVariables is dropped.
local function sanitizePlayer(key,raw,now)
    if not L.ValidIdentityKey(key)or type(raw)~="table"then return nil end
    local _,target=L.Identity(raw.target);if not target then return nil end
    local p={target=target,count=L.Int(raw.count,0,1000000)and raw.count or 0,known=raw.known==true or nil,events={}}
    if L.Int(raw.first,1,MAX_TIME)then p.first=raw.first end
    if L.Int(raw.last,1,MAX_TIME)then p.last=raw.last end
    if L.Int(raw.since,1,MAX_TIME)then p.since=raw.since end
    if type(raw.classFile)=="string"and raw.classFile:match("^[A-Z]+$")and #raw.classFile<=16 then p.classFile=raw.classFile end
    if L.Int(raw.level,1,100)then p.level=raw.level end
    for _,e in ipairs(type(raw.events)=="table"and raw.events or{})do
        if #p.events>=D.MAX_EVENTS*2 then break end
        if validEvent(e,now)then p.events[#p.events+1]={at=e.at,kind=e.kind,zone=e.zone or"",detail=e.detail}end
    end
    table.sort(p.events,function(a,b)return a.at<b.at end)
    while #p.events>D.MAX_EVENTS do table.remove(p.events,1)end
    if not p.known and p.count==0 and #p.events==0 then return nil end
    return p
end
local function protected(key,p)
    local S=Z.Social
    return p.known==true or S and S.IsFavorite(key)or S and S.GetNote(key)~=""
end
local function recount()
    local n=0;for _ in pairs(D.store.players)do n=n+1 end;D.count=n
end
function D.Initialize()
    D.lastGroupScan,D.lastGroupSignature=nil,nil;D.revision=0
    local social=Z.Social and Z.Social.store;if not social then return end
    local raw=social.diary;local now=A.Now()
    -- A newer format from a later addon version stays untouched and read-only.
    D.readOnly=type(raw)=="table"and raw.version~=nil and raw.version~=D.VERSION
    if D.readOnly then D.store=defaults();recount();return end
    local store=defaults()
    if type(raw)=="table"then
        -- The former opt-in switch and source choices are carried along unchanged for older addon versions;
        -- this version no longer reads them.
        store.enabled=raw.enabled==true
        if type(raw.sources)=="table"then for _,id in ipairs(SOURCES)do store.sources[id]=raw.sources[id]~=false end end
        local inspected=0
        for key,row in pairs(type(raw.players)=="table"and raw.players or{})do
            inspected=inspected+1;if inspected>D.MAX_PLAYERS*2 then break end
            local p=sanitizePlayer(key,row,now);if p and key~=(Z.me and Z.me.key)then store.players[key]=p end
        end
    end
    social.diary=store;D.store=store;recount();D.Cleanup(now)
end
-- Always on; only a newer, unreadable format stops recording.
function D.Enabled()return D.store~=nil and not D.readOnly end
-- Removes expired unprotected rows and, when over the cap, the oldest
-- unprotected rows. Known players, favorites and players with a note stay.
function D.Cleanup(now)
    if not D.store or D.readOnly then return 0 end
    now=now or A.Now();local removed=0;local candidates={}
    for key,p in pairs(D.store.players)do
        local fresh={};for _,e in ipairs(p.events)do if e.at>=now-D.EVENT_RETENTION then fresh[#fresh+1]=e end end;p.events=fresh
        if Z.db and Z.db.blocked[key]then D.store.players[key]=nil;removed=removed+1
        elseif not protected(key,p)then
            if not p.last or p.last<now-D.RETENTION then D.store.players[key]=nil;removed=removed+1
            else candidates[#candidates+1]={key=key,last=p.last}end
        end
    end
    recount()
    if D.count>=D.MAX_PLAYERS then
        table.sort(candidates,function(a,b)if a.last~=b.last then return a.last<b.last end;return a.key<b.key end)
        local i=1;while D.count>D.PRUNE_TO and candidates[i]do D.store.players[candidates[i].key]=nil;D.count=D.count-1;removed=removed+1;i=i+1 end
    end
    if removed>0 then changed()end
    return removed
end
local function zoneText()
    local z=A.Call(GetRealZoneText)or A.Call(GetZoneText)
    return L.Text(z,64,true)and z or""
end
local function append(p,e)
    p.events[#p.events+1]=e;while #p.events>D.MAX_EVENTS do table.remove(p.events,1)end
end
local function row(key,target,now)
    local p=D.store.players[key]
    if p then return p end
    if D.count>=D.MAX_PLAYERS then D.Cleanup(now);if D.count>=D.MAX_PLAYERS then return nil end end
    p={target=target,count=0,events={}};D.store.players[key]=p;D.count=D.count+1;return p
end
-- One encounter per player and GAP window: repeated sightings only move
-- `last`. A group observation is added once per encounter, a dungeon once
-- per instance and DUNGEON_GAP; neither inflates the encounter count.
function D.Record(key,target,kind,info)
    if not D.Enabled()or not KINDS[kind]or not L.ValidIdentityKey(key)then return nil end
    local _,clean=L.Identity(target);if not clean or not Z.db or key==Z.me.key or Z.db.blocked[key]then return nil end
    local now=A.Now();if not L.Int(now,1,MAX_TIME)then return nil end
    local p=row(key,clean,now);if not p then return nil end
    info=info or{}
    p.target=clean
    if type(info.classFile)=="string"and info.classFile:match("^[A-Z]+$")and #info.classFile<=16 then p.classFile=info.classFile end
    if L.Int(info.level,1,100)then p.level=info.level end
    local zone=L.Text(info.zone or"",64,true)and info.zone or"";local added
    local fresh=not p.last or now-p.last>=D.GAP
    if fresh then
        p.count=math.min(p.count+1,1000000);p.since=now;p.first=p.first or now
        if kind~="dungeon"then added={at=now,kind=kind,zone=zone};append(p,added)end
    elseif kind=="group"then
        local seen=false;for i=#p.events,1,-1 do local e=p.events[i];if e.at<(p.since or now)then break end;if e.kind=="group"then seen=true;break end end
        if not seen then added={at=now,kind="group",zone=zone};append(p,added)end
    end
    if kind=="dungeon"and L.Text(info.detail,96)then
        local seen=false;for i=#p.events,1,-1 do local e=p.events[i];if e.at<now-D.DUNGEON_GAP then break end;if e.kind=="dungeon"and e.detail==info.detail then seen=true;break end end
        if not seen then added={at=now,kind="dungeon",zone=zone,detail=info.detail};append(p,added)end
    end
    p.last=now;changed();return p,added
end
local function identity(unit)
    local key,target,realm=A.UnitIdentity(unit);if not key then return nil end
    local faction=A.Call(UnitFactionGroup,unit)or Z.me.faction
    return L.ScopeKey(target,realm,faction)or key,target
end
local function details(unit)
    local _,classFile=A.Call(UnitClass,unit);local level=A.Call(UnitLevel,unit)
    return{classFile=classFile,level=level,zone=zoneText()}
end
local function instance()
    local name,instanceType=A.Call(GetInstanceInfo)
    if(instanceType=="party"or instanceType=="raid")and L.Text(name,96)then return name end
end
function D.ObserveGroup(force)
    if not D.Enabled()then return 0 end
    local total=A.Call(GetNumGroupMembers)or 0;if type(total)~="number"or total<2 then return 0 end
    local dungeon=instance();local signature=tostring(total).."\t"..(dungeon or"")
    local clock=A.Clock()or 0
    if not force and signature==D.lastGroupSignature and D.lastGroupScan and clock-D.lastGroupScan<D.GROUP_THROTTLE then return 0 end
    D.lastGroupScan,D.lastGroupSignature=clock,signature
    local units={};if A.Call(IsInRaid)==true then for i=1,math.min(total,40)do units[#units+1]="raid"..i end else for i=1,math.min(total-1,4)do units[#units+1]="party"..i end end
    local n=0
    for _,unit in ipairs(units)do
        if A.Call(UnitIsUnit,unit,"player")~=true then
            local key,target=identity(unit)
            if key then
                local info=details(unit)
                if D.Record(key,target,"group",info)then n=n+1 end
                if dungeon then info.detail=dungeon;D.Record(key,target,"dungeon",info)end
            end
        end
    end
    return n
end
function D.OnEvent(event)
    if not D.store then return end
    if event=="GROUP_ROSTER_UPDATE"then D.ObserveGroup(false)
    elseif event=="PLAYER_ENTERING_WORLD"or event=="ZONE_CHANGED_NEW_AREA"then D.ObserveGroup(true)end
end
-- Manual marks work for any player, grouped with or not.
function D.SetKnown(key,target,value)
    if not D.store or D.readOnly then return nil,"The social diary uses a newer format."end
    if not L.ValidIdentityKey(key)or key==Z.me.key or Z.db.blocked[key]then return nil,"Invalid player."end
    local p=D.store.players[key]
    if value then
        if not p then local _,clean=L.Identity(target);if not clean then return nil,"Invalid player."end;p=row(key,clean,A.Now());if not p then return nil,"The social diary is full."end end
        p.known=true
    elseif p then
        p.known=nil;if p.count==0 and #p.events==0 then D.store.players[key]=nil;D.count=D.count-1 end
    end
    changed();return true
end
function D.IsKnown(key)local p=D.store and D.store.players[key];return p~=nil and p.known==true end
function D.Get(key)return D.store and D.store.players[key]end
function D.Forget(key)
    if D.store and not D.readOnly and D.store.players[key]then D.store.players[key]=nil;D.count=D.count-1;changed();return true end
    return false
end
local function displayTarget(key)
    local c=Z.db.contacts[key];if c then return c.target end
    local cat=Z.SocialCategories and Z.SocialCategories.store and Z.SocialCategories.store.contacts[key];if cat then return cat.target end
    local name=key:match("@([^@]+)$")or key
    return(name:gsub("(%a)([%w']*)",function(a,b)return a:upper()..b end))
end
D.DisplayTarget=displayTarget
local function grouped(p)
    for _,e in ipairs(p and p.events or{})do if e.kind=="group"or e.kind=="dungeon"then return true end end
    return false
end
-- Players you were grouped with, plus every player you marked yourself (known, favorite, private note),
-- with or without a diary row. Rows that only hold sightings from an earlier version are not listed.
-- Favorites and notes are read from the shared social store, never copied.
function D.List(filter)
    filter=filter or{};local mode=filter.mode or"ALL";local sort=filter.sort or"LAST"
    local query=string.lower(filter.query or"");local out={};local keys={}
    local social=Z.Social and Z.Social.store
    for key in pairs(D.store and D.store.players or{})do keys[key]=true end
    for key in pairs(social and social.favorites or{})do keys[key]=true end
    for key in pairs(social and social.notes or{})do keys[key]=true end
    for key in pairs(keys)do
        if key~=Z.me.key and not Z.db.blocked[key]and L.ValidIdentityKey(key)then
            local p=D.store and D.store.players[key];local note=Z.Social.GetNote(key)
            local r={key=key,target=p and p.target or displayTarget(key),first=p and p.first,last=p and p.last,count=p and p.count or 0,
                known=p and p.known==true or false,favorite=Z.Social.IsFavorite(key),note=note,classFile=p and p.classFile,level=p and p.level,
                grouped=grouped(p),lastZone=p and p.events[#p.events]and p.events[#p.events].zone or""}
            local include=r.grouped or r.known or r.favorite or note~=""
            include=include and(mode=="ALL"or mode=="KNOWN"and r.known or mode=="FAVORITES"and r.favorite or mode=="NOTES"and note~=""or mode=="GROUPED"and r.grouped)
            if include and query~=""then include=string.lower(r.target.." "..note.." "..r.lastZone):find(query,1,true)~=nil end
            if include then out[#out+1]=r end
        end
    end
    table.sort(out,function(a,b)
        if sort=="COUNT"and a.count~=b.count then return a.count>b.count end
        if sort~="NAME"and(a.last or 0)~=(b.last or 0)then return(a.last or 0)>(b.last or 0)end
        local an,bn=string.lower(a.target),string.lower(b.target);if an~=bn then return an<bn end
        return a.key<b.key
    end)
    return out
end
local LABELS={group="Grouped together",dungeon="Dungeon together"}
function D.KindLabel(kind)return Z.T(LABELS[kind]or kind or"")end
-- Diary observations merged with the existing contact history; nothing from
-- History is copied into the diary store.
function D.Timeline(key)
    local out={};local p=D.store and D.store.players[key]
    for _,e in ipairs(p and p.events or{})do
        -- Sightings stored by an earlier version are not part of the timeline.
        if LABELS[e.kind]then out[#out+1]={at=e.at,kind=e.kind,zone=e.zone or"",text=D.KindLabel(e.kind)..(e.detail and(": "..e.detail)or""),source="diary"}end
    end
    local H=Z.History
    for _,e in ipairs(H and H.byPeer and H.byPeer[key]or{})do
        out[#out+1]={at=e.at,kind=e.kind,zone="",text=H.EventLabel(e.event)..(e.content~=""and(": "..e.content)or""),source="history"}
    end
    table.sort(out,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.text<b.text end)
    return out
end
return D
