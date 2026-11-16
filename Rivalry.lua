-- ZENIAL Rivalry: private, permanent PvP history (kills, deaths, assists, duels) per opponent.
-- Stored only in the saved variable ZenialRivalryDB; nothing here is ever sent to other players.
--
-- What the client lets an addon see (the combat log is closed to addons):
--   kill    PARTY_KILL with the player or the player's pet as attacker and a player as victim
--   assist  an enemy player dies (PARTY_KILL by someone else, or UNIT_DIED) and the player successfully
--           used an ability on exactly that player within ASSIST_WINDOW seconds before
--   death   the Death Recap read by PvPDeathDetection: fatal blow by a player, further attackers as a minimum
--   duel    the client's own duel result message (DUEL_WINNER_KNOCKOUT / DUEL_WINNER_RETREAT)
-- An honorable kill alone is never counted. Whatever cannot be read (secret values) is not recorded.
--
-- Storage: no entry limit and no automatic cleanup. Every opponent has running counters plus a compact
-- event list ("<time>:<kind><context>:<zone>:<subzone>", zone names in one shared dictionary). Recording
-- touches one profile only; lists are built when the window asks for them and cached per revision.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local R={VERSION=1,ASSIST_WINDOW=10,SETTLE=.5,DEDUPE=5,CAST_TTL=20,MAX_CASTS=8,MAX_ENGAGED=32,MAX_SETTLED=64,
    DUEL_DEDUPE=3,MAX_INVOLVED=5,RIVAL_FIGHTS=5,NEMESIS_DEATHS=3,revision=0}
Z.Rivalry=R
local MAX_TIME=4102444800
-- Event kind -> profile counter. X: took part in the player's death without the fatal blow.
local KINDS={K="kills",D="deaths",A="assists",X="involved",W="duelWins",L="duelLosses"}
local COUNTERS={"kills","deaths","assists","involved","duelWins","duelLosses"}
local TOTALS={"kills","deaths","assists","duelWins","duelLosses","unknownDeaths"}
local KIND_TOTAL={K="kills",D="deaths",A="assists",W="duelWins",L="duelLosses"}
local ENEMY_UNITS={"target","focus","mouseover"}
local RACE_FACTION={Human="Alliance",Dwarf="Alliance",NightElf="Alliance",Gnome="Alliance",Draenei="Alliance",Worgen="Alliance",
    Orc="Horde",Scourge="Horde",Tauren="Horde",Troll="Horde",BloodElf="Horde",Goblin="Horde"}
local DEFAULTS={banner=true,kills=true,deaths=true,assists=true,duels=true,animation=true,sound=true,style="standard",scale=1,duration=4}
local STYLES={standard=true,compact=true}
R.DEFAULTS=DEFAULTS

local lower=string.lower
-- A secret value errors when compared; every event payload passes through here before use.
local function public(v)
    if v==nil then return nil end
    if type(issecretvalue)=="function"then local ok,secret=pcall(issecretvalue,v);if not ok or secret then return nil end end
    return v
end
local function guidKind(guid)return type(guid)=="string"and guid:match("^(%a+)%-")or nil end
local function int(v)return L.Int(v,0,2147483646)and v or 0 end
local function classToken(v)return type(v)=="string"and #v<=16 and v:match("^[A-Z_]+$")and v or nil end
local function clean(name)
    if type(name)~="string"or not L.Text(name,113)then return nil end
    name=((name:match("^%s*(.-)%s*$")or""):gsub("%s+"," "))
    return name~=""and name or nil
end
-- Storage key, display name and foreign realm of a player name. Forever has one megaserver; a realm
-- suffix only becomes part of the key when it names another realm than the player's own.
local function identify(name,realm)
    name=clean(name);if not name then return nil end
    local base,suffix=name:match("^(.-)%-(.+)$")
    if base and base~=""then name=base;if not clean(realm)then realm=suffix end end
    realm=clean(realm);realm=realm and(realm:gsub("%s",""))or nil
    local own=Z.me and type(Z.me.realm)=="string"and lower((Z.me.realm:gsub("%s","")))or""
    local foreign=realm~=nil and realm~=""and lower(realm)~=own
    if #name>80 then return nil end
    return lower(name)..(foreign and"-"..lower(realm)or""),name,foreign and realm or nil
end
R.Identify=identify

-- Saved-variable root; read fresh, never cached across a reset.
local function root()
    if type(ZenialRivalryDB)~="table"then ZenialRivalryDB={}end
    return ZenialRivalryDB
end
local function sanitizeTotals(t)
    t=type(t)=="table"and t or{}
    for _,f in ipairs(TOTALS)do t[f]=int(t[f])end
    return t
end
-- A character record, checked once per session. Corrupt parts are replaced, valid history is never dropped.
local function character(key)
    local c=R.store and key and R.store.characters[key];if type(c)~="table"then return nil end
    if not R.cleanChars[c]then
        R.cleanChars[c]=true
        if type(c.rivals)~="table"then c.rivals={}end
        c.totals=sanitizeTotals(c.totals)
        if not L.Int(c.totals.rivals,0,2147483646)then
            local n=0;for _,p in pairs(c.rivals)do if type(p)=="table"then n=n+1 end end;c.totals.rivals=n
        end
        if not L.Text(c.name,113)then c.name=nil end
        c.classFile=classToken(c.classFile)
    end
    return c
end
-- One opponent profile, checked on first use only (never the whole history at login).
local function profile(p)
    if type(p)~="table"then return nil end
    if R.cleanProfiles[p]then return p end
    R.cleanProfiles[p]=true
    for _,f in ipairs(COUNTERS)do p[f]=int(p[f])end
    if type(p.events)~="table"then p.events={}end
    p.name=L.Text(p.name,80)and p.name or nil
    p.realm=L.Text(p.realm,64)and p.realm or nil
    p.guid=L.Text(p.guid,80)and p.guid or nil
    p.classFile=classToken(p.classFile)
    p.race=L.Text(p.race,24)and p.race or nil
    p.raceFile=type(p.raceFile)=="string"and #p.raceFile<=24 and p.raceFile:match("^%a+$")and p.raceFile or nil
    p.faction=(p.faction=="Alliance"or p.faction=="Horde")and p.faction or nil
    p.level=L.Int(p.level,1,100)and p.level or nil
    p.first=L.Int(p.first,1,MAX_TIME)and p.first or nil
    p.last=L.Int(p.last,1,MAX_TIME)and p.last or nil
    p.outcome=(p.outcome=="K"or p.outcome=="D")and p.outcome or nil
    return p
end
local function newCharacter()
    return{totals=sanitizeTotals(nil),rivals={}}
end
-- The logged-in character's record. A record stored under an older storage key is found by the character GUID.
local function adoptCharacter(store)
    local key=Z.storageKey;local c=store.characters[key]
    local guid=L.Text(Z.me.guid,80)and Z.me.guid or nil
    if type(c)~="table"and guid then
        for other,row in pairs(store.characters)do
            if type(row)=="table"and row.guid==guid then c=row;store.characters[other]=nil;break end
        end
    end
    if type(c)~="table"then c=newCharacter()end
    store.characters[key]=c
    c=character(key)
    c.totals.rivals=c.totals.rivals or 0
    c.name=Z.me.target;c.classFile=classToken(Z.me.classFile);c.guid=guid or c.guid
    return c
end

local function zoneIndex(name)
    if not L.Text(name,64)then return 0 end
    local index=R.zoneIndex
    if not index then
        index={};for i,v in ipairs(R.store.zones)do if type(v)=="string"then index[v]=i end end;R.zoneIndex=index
    end
    local i=index[name];if i then return i end
    i=#R.store.zones+1;R.store.zones[i]=name;index[name]=i;return i
end
local function zoneName(i)
    local v=R.store and R.store.zones[tonumber(i)or 0]
    return type(v)=="string"and v or""
end
-- Context and place right now. W open world, B battleground, A arena, I instance, U unknown.
local function here()
    local name,instanceType=A.Call(GetInstanceInfo)
    local ctx=instanceType=="none"and"W"or instanceType=="pvp"and"B"or instanceType=="arena"and"A"
        or(instanceType=="party"or instanceType=="raid"or instanceType=="scenario")and"I"or"U"
    local area=A.Call(GetRealZoneText)or A.Call(GetZoneText);local sub=A.Call(GetSubZoneText)
    if ctx~="W"and ctx~="U"and L.Text(name,64)then area=name end
    area=L.Text(area,64)and area or""
    sub=L.Text(sub,64)and sub~=area and sub or""
    return ctx,area,sub
end

-- Unit details of a player the client shows right now.
local function describeUnit(unit,info)
    info=info or{}
    local _,full=A.UnitIdentity(unit)
    if full then info.name=full;info.realm=nil end
    local guid=A.Call(UnitGUID,unit);if guidKind(guid)=="Player"then info.guid=info.guid or guid end
    local _,classFile=A.Call(UnitClass,unit);info.classFile=classToken(classFile)or info.classFile
    local level=A.Call(UnitLevel,unit);if L.Int(level,1,100)then info.level=level end
    local faction=A.Call(UnitFactionGroup,unit);if faction=="Alliance"or faction=="Horde"then info.faction=faction end
    local race,raceFile=A.Call(UnitRace,unit)
    if L.Text(race,24)then info.race=race end
    if type(raceFile)=="string"and #raceFile<=24 and raceFile:match("^%a+$")then info.raceFile=raceFile end
    return info
end
-- Name, class, race, faction and level of one player GUID; nil without a readable name.
local function describe(guid,eventName)
    local resolve=Z.PvPDeath and Z.PvPDeath.Resolve
    local info=resolve and resolve(guid,eventName)or(clean(eventName)and{name=eventName})or{}
    info.guid=guid
    local unit=type(UnitTokenFromGUID)=="function"and A.Call(UnitTokenFromGUID,guid)or nil
    if type(unit)=="string"and A.Call(UnitIsPlayer,unit)==true then describeUnit(unit,info)end
    info.faction=info.faction or RACE_FACTION[info.raceFile or""]
    if not clean(info.name)then return nil end
    return info
end

-- The opponent who killed this character most often (at least NEMESIS_DEATHS times, the latest on a tie).
-- The key is kept in the character record and moved by each death, so no event has to walk the history.
local function nemesisOf(c)
    local p=type(c.nemesis)=="string"and profile(c.rivals[c.nemesis])or nil
    return p and p.deaths>=R.NEMESIS_DEATHS and c.nemesis or nil
end
-- Full search, only after a manual removal or a merge.
local function findNemesis(c)
    local best,bestKey
    for key,raw in pairs(c.rivals)do
        local p=profile(raw)
        if p and p.deaths>=R.NEMESIS_DEATHS and(not best or p.deaths>best.deaths or p.deaths==best.deaths and(p.last or 0)>(best.last or 0))then best,bestKey=p,key end
    end
    c.nemesis=bestKey
end
local function guidIndex()
    local index=R.guids
    if not index then
        index={};for key,p in pairs(R.char.rivals)do if type(p)=="table"and type(p.guid)=="string"then index[p.guid]=key end end
        R.guids=index
    end
    return index
end
local function invalidate()
    R.revision=R.revision+1
end
-- Two profiles of the same player (found by GUID under two names) become one; no event is lost.
local function merge(dst,src)
    for _,f in ipairs(COUNTERS)do dst[f]=dst[f]+src[f]end
    for _,e in ipairs(src.events)do dst.events[#dst.events+1]=e end
    table.sort(dst.events,function(a,b)return tostring(a)<tostring(b)end)
    if src.first and(not dst.first or src.first<dst.first)then dst.first=src.first end
    if src.last and(not dst.last or src.last>dst.last)then dst.last=src.last;dst.outcome=src.outcome or dst.outcome end
    for _,f in ipairs({"guid","classFile","race","raceFile","faction","level"})do dst[f]=dst[f]or src[f]end
end
-- Finds or creates the profile of one opponent. The GUID wins over the name, so a player who shows up
-- under another spelling or a new name keeps the same history.
local function upsert(info)
    local c=R.char;local key,name,realm=identify(info.name,info.realm);if not key then return nil end
    local guid=guidKind(info.guid)=="Player"and L.Text(info.guid,80)and info.guid or nil
    if guid then
        local known=guidIndex()[guid];local old=known and known~=key and profile(c.rivals[known])or nil
        if old then
            -- A two-part name is the full Forever name; it is never replaced by a shorter spelling.
            if name:find(" ",1,true)or not(old.name or""):find(" ",1,true)then
                local target=profile(c.rivals[key])
                if target then merge(target,old);c.totals.rivals=math.max(0,c.totals.rivals-1)else c.rivals[key]=old end
                c.rivals[known]=nil
                if target then findNemesis(c)elseif c.nemesis==known then c.nemesis=key end
            else key,name,realm=known,nil,nil end
        end
    end
    local p=profile(c.rivals[key]);local isNew=p==nil
    if isNew then
        p={kills=0,deaths=0,assists=0,involved=0,duelWins=0,duelLosses=0,events={}}
        R.cleanProfiles[p]=true;c.rivals[key]=p;c.totals.rivals=c.totals.rivals+1
    end
    if name then p.name=name;p.realm=realm end
    if guid then
        if p.guid and p.guid~=guid then guidIndex()[p.guid]=nil end
        p.guid=guid;guidIndex()[guid]=key
    end
    p.classFile=classToken(info.classFile)or p.classFile
    if L.Text(info.race,24)then p.race=info.race end
    if type(info.raceFile)=="string"and #info.raceFile<=24 and info.raceFile:match("^%a+$")then p.raceFile=info.raceFile end
    if info.faction=="Alliance"or info.faction=="Horde"then p.faction=info.faction end
    if L.Int(info.level,1,100)then p.level=info.level end
    return p,key,isNew
end
-- Appends one event and moves the counters; the only write path of the history.
local function record(p,kind,ctx,area,sub,at)
    local c=R.char
    p[KINDS[kind]]=p[KINDS[kind]]+1
    local total=KIND_TOTAL[kind];if total then c.totals[total]=c.totals[total]+1 end
    p.first=p.first or at;if not p.last or at>p.last then p.last=at end
    p.events[#p.events+1]=at..":"..kind..ctx..":"..zoneIndex(area)..":"..zoneIndex(sub)
    if kind=="K"or kind=="D"then p.outcome=kind end
    invalidate()
end
-- One plain marker per event, by priority: nemesis, rival, revenge, first meeting.
local function tagFor(p,key,kind,isNew,revenge)
    if kind=="K"or kind=="D"or kind=="A"then
        if nemesisOf(R.char)==key then return"NEMESIS"end
        if p.kills+p.deaths>=R.RIVAL_FIGHTS then return"RIVAL"end
    end
    if revenge then return"REVENGE"end
    if isNew then return"FIRST"end
end
local function snapshot(p,kind,tag)
    return{kind=kind,name=p.name,classFile=p.classFile,kills=p.kills,deaths=p.deaths,assists=p.assists,
        duelWins=p.duelWins,duelLosses=p.duelLosses,fights=p.kills+p.deaths,tag=tag}
end
local function notify(kind,p,key,tag)
    R.last={kind=kind,key=key,tag=tag}
    local B=Z.RivalryBanner
    if B and B.Push then pcall(B.Push,snapshot(p,kind,tag))end
    if Z.UI and Z.UI.RefreshRivalry then pcall(Z.UI.RefreshRivalry)end
end

local function prune(map,ttl,max,now)
    local n=0
    for k,v in pairs(map)do
        local at=type(v)=="table"and v.at or v
        if now-at>ttl then map[k]=nil else n=n+1 end
    end
    if n>max then
        local oldest,oldestAt
        for k,v in pairs(map)do local at=type(v)=="table"and v.at or v;if not oldestAt or at<oldestAt then oldest,oldestAt=k,at end end
        if oldest then map[oldest]=nil end
    end
end
local function myGUIDs()
    local me,pet=A.Call(UnitGUID,"player"),A.Call(UnitGUID,"pet")
    return type(me)=="string"and me or nil,type(pet)=="string"and pet or nil
end

-- A late PARTY_KILL of the player turns an already recorded assist into the kill it was.
local function upgrade(s)
    local c=R.char;local p=profile(c.rivals[s.key]);local e=p and p.events[s.index]
    if type(e)~="string"or not e:match("^%d+:A")or p.assists<1 then return end
    p.events[s.index]=(e:gsub("^(%d+):A","%1:K"))
    p.assists=p.assists-1;p.kills=p.kills+1;p.outcome="K"
    c.totals.assists=math.max(0,c.totals.assists-1);c.totals.kills=c.totals.kills+1
    s.kind="K";invalidate()
    notify("K",p,s.key,tagFor(p,s.key,"K",false,false))
end
-- Records the kill or assist of one enemy player; one entry per death of that player.
local function settle(guid,kind)
    local now=A.Clock();local s=R.settled[guid]
    if s and now-s.at<R.DEDUPE then
        if kind=="K"and s.kind=="A"then upgrade(s)end
        return false
    end
    local at=A.Now();if at==0 then return false end
    local info=describe(guid);if not info then return false end
    local p,key,isNew=upsert(info);if not p then return false end
    local ctx,area,sub=here()
    local revenge=kind=="K"and p.outcome=="D"
    record(p,kind,ctx,area,sub,at)
    prune(R.settled,R.DEDUPE,R.MAX_SETTLED,now)
    R.settled[guid]={at=now,kind=kind,key=key,index=#p.events}
    notify(kind,p,key,tagFor(p,key,kind,isNew,revenge))
    return true
end
local function engagedAt(guid)
    local at=R.engagedGuid[guid]
    if not at then
        local info=describe(guid);local key=info and identify(info.name,info.realm)
        at=key and R.engaged[key]or nil
    end
    return at
end
local function onUpdate()R.Tick()end
-- An enemy player died without the player's fatal blow: an assist only with proof of an own attack.
local function enemyDied(guid)
    local now=A.Clock()
    prune(R.engaged,R.ASSIST_WINDOW,R.MAX_ENGAGED,now);prune(R.engagedGuid,R.ASSIST_WINDOW,R.MAX_ENGAGED,now)
    if(not next(R.engaged)and not next(R.engagedGuid))or R.pending[guid]then return end
    local s=R.settled[guid];if s and now-s.at<R.DEDUPE then return end
    local at=engagedAt(guid);if not at or now-at>R.ASSIST_WINDOW then return end
    -- Wait a moment: the PARTY_KILL naming the player as attacker may arrive right after UNIT_DIED.
    R.pending[guid]=now+R.SETTLE
    if R.frame then R.frame:SetScript("OnUpdate",onUpdate)end
end
function R.Tick()
    local now=A.Clock()
    for guid,due in pairs(R.pending or{})do
        if now>=due then R.pending[guid]=nil;settle(guid,"A")end
    end
    if R.frame and not next(R.pending or{})then R.frame:SetScript("OnUpdate",nil)end
end

local function onPartyKill(attacker,victim)
    attacker,victim=public(attacker),public(victim)
    if guidKind(victim)~="Player"or type(attacker)~="string"then return end
    local me,pet=myGUIDs();if not me or victim==me then return end
    if attacker==me or(pet~=nil and attacker==pet)then R.pending[victim]=nil;settle(victim,"K")
    else enemyDied(victim)end
end
local function onUnitDied(guid)
    guid=public(guid);if guidKind(guid)~="Player"then return end
    local me=myGUIDs();if guid==me then return end
    enemyDied(guid)
end
-- UNIT_SPELLCAST_SENT names the target. It only counts as an attack when that name belongs to an
-- attackable player the client shows as target, focus or mouseover.
local function onSpellSent(unit,target,castGUID)
    unit,target,castGUID=public(unit),public(target),public(castGUID)
    if unit~="player"or type(castGUID)~="string"then return end
    local wanted=identify(target);if not wanted then return end
    for _,token in ipairs(ENEMY_UNITS)do
        if A.Call(UnitIsPlayer,token)==true and A.Call(UnitCanAttack,"player",token)==true then
            local _,full=A.UnitIdentity(token);local short=A.Call(UnitName,token)
            local key=identify(full)or identify(short)
            if key and(key==wanted or identify(short)==wanted)then
                local now=A.Clock();prune(R.casts,R.CAST_TTL,R.MAX_CASTS,now)
                local guid=A.Call(UnitGUID,token)
                R.casts[castGUID]={key=key,guid=guidKind(guid)=="Player"and guid or nil,at=now}
                return
            end
        end
    end
end
local function onSpellSucceeded(unit,castGUID)
    unit,castGUID=public(unit),public(castGUID)
    if unit~="player"or type(castGUID)~="string"then return end
    local cast=R.casts[castGUID];if not cast then return end
    R.casts[castGUID]=nil
    local now=A.Clock();if now-cast.at>R.CAST_TTL then return end
    R.engaged[cast.key]=now;if cast.guid then R.engagedGuid[cast.guid]=now end
end

-- Turns a client format string ("%1$s has defeated %2$s in a duel") into a Lua pattern plus argument order.
local function formatPattern(format)
    format=public(format);if type(format)~="string"or format==""or #format>200 then return nil end
    local order={}
    local pattern=format:gsub("[%^%$%(%)%.%[%]%*%+%-%?]","%%%0")
    pattern=pattern:gsub("%%(%d)%%%$s",function(n)order[#order+1]=tonumber(n);return"(.+)"end)
    pattern=pattern:gsub("%%s",function()order[#order+1]=#order+1;return"(.+)"end)
    if #order~=2 or order[1]==order[2]then return nil end
    return{pattern="^"..pattern.."$",order=order}
end
local function duelPatterns()
    if R.duelPatterns==nil then
        local list={}
        -- Both formats take the winner first and the loser second.
        for _,format in ipairs({DUEL_WINNER_KNOCKOUT or false,DUEL_WINNER_RETREAT or false})do
            local p=format and formatPattern(format);if p then list[#list+1]=p end
        end
        R.duelPatterns=#list>0 and list or false
    end
    return R.duelPatterns or nil
end
local function isMe(name)
    local key=identify(name);if not key then return false end
    if key==identify(Z.me.target)then return true end
    local short=A.Call(UnitName,"player")
    return identify(short)==key
end
-- Duel results are announced to everyone nearby; only a message naming the player counts.
local function onSystemMessage(text)
    text=public(text);if type(text)~="string"or #text>255 then return end
    local patterns=duelPatterns();if not patterns then return end
    for _,p in ipairs(patterns)do
        local a,b=text:match(p.pattern)
        if a then
            local args={};args[p.order[1]]=a;args[p.order[2]]=b
            local winner,loser=args[1],args[2]
            local won,lost=isMe(winner),isMe(loser)
            if won==lost then return end
            local kind,opponent=won and"W"or"L",won and loser or winner
            local info={name=opponent};local wanted=identify(opponent)
            if not wanted then return end
            for _,token in ipairs(ENEMY_UNITS)do
                if A.Call(UnitIsPlayer,token)==true then
                    local _,full=A.UnitIdentity(token);local short=A.Call(UnitName,token)
                    if identify(full)==wanted or identify(short)==wanted then describeUnit(token,info);break end
                end
            end
            local at=A.Now();if at==0 then return end
            local row,key,isNew=upsert(info);if not row then return end
            local now=A.Clock();local last=R.lastDuel
            if last and last.key==key and now-last.at<R.DUEL_DEDUPE then return end
            R.lastDuel={key=key,at=now}
            local _,area,sub=here()
            record(row,kind,"D",area,sub,at)
            notify(kind,row,key,isNew and"FIRST"or nil)
            return
        end
    end
end

-- A confirmed death by a player (any context). Called by PvPDeathDetection once per life.
local function recapDeath(events,snap,myGUID)
    if not R.char or not Z.PvPDeath then return end
    local fatal,order=Z.PvPDeath.Attackers(events,myGUID)
    if fatal.cause~="player"then return end
    local at=type(snap)=="table"and L.Int(snap.at,1,MAX_TIME)and snap.at or A.Now();if at==0 then return end
    local ctx,area,sub=here()
    if ctx=="W"and type(snap)=="table"and L.Text(snap.area,64)then
        area=snap.area;sub=L.Text(snap.subzone,64)and snap.subzone~=area and snap.subzone or""
    end
    local c=R.char;local killer=not fatal.pet and guidKind(fatal.guid)=="Player"and fatal or nil
    local named=false
    if killer then
        local info=describe(killer.guid,killer.name);local p,key,isNew=nil,nil,nil
        if info then p,key,isNew=upsert(info)end
        if p then
            record(p,"D",ctx,area,sub,at);named=true
            local worst=nemesisOf(c)and profile(c.rivals[c.nemesis])
            if p.deaths>=R.NEMESIS_DEATHS and(not worst or p.deaths>=worst.deaths)then c.nemesis=key end
            notify("D",p,key,tagFor(p,key,"D",isNew,false))
        end
    end
    -- A death whose killer cannot be named (a pet's blow, an unreadable name) still counts for the totals.
    if not named then c.totals.deaths=c.totals.deaths+1;c.totals.unknownDeaths=c.totals.unknownDeaths+1;invalidate()end
    local involved=0
    for _,class in ipairs(order)do
        if class~=killer and involved<R.MAX_INVOLVED then
            local info=describe(class.guid,class.name);local p=info and upsert(info)
            if p then record(p,"X",ctx,area,sub,at);involved=involved+1 end
        end
    end
    if Z.UI and Z.UI.RefreshRivalry then pcall(Z.UI.RefreshRivalry)end
end
function R.OnRecapDeath(events,snap,myGUID)
    local ok,err=pcall(recapDeath,events,snap,myGUID)
    if not ok then R.lastError=err end
    return ok
end

function R.OnEvent(event,...)
    if not R.char then return end
    if event=="PARTY_KILL"then onPartyKill(...)
    elseif event=="UNIT_DIED"then onUnitDied(...)
    elseif event=="UNIT_SPELLCAST_SENT"then onSpellSent(...)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED"then onSpellSucceeded(...)
    elseif event=="CHAT_MSG_SYSTEM"then onSystemMessage(...)end
end
local function registerEvents()
    if R.frame or type(CreateFrame)~="function"then return end
    local f=CreateFrame("Frame");R.frame=f
    for _,event in ipairs({"PARTY_KILL","UNIT_DIED","CHAT_MSG_SYSTEM"})do pcall(f.RegisterEvent,f,event)end
    for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED"})do
        local ok,result=pcall(f.RegisterUnitEvent,f,event,"player")
        if not ok or result==false then pcall(f.RegisterEvent,f,event)end
    end
    f:SetScript("OnEvent",function(_,event,...)
        local ok,err=pcall(R.OnEvent,event,...)
        if not ok then R.lastError=err end
    end)
end

function R.Initialize()
    R.char,R.store,R.readOnly=nil,nil,false
    R.casts,R.engaged,R.engagedGuid,R.pending,R.settled={},{},{},{},{}
    R.guids,R.zoneIndex,R.cache,R.overview,R.duelPatterns,R.lastDuel,R.last,R.lastError=nil,nil,nil,nil,nil,nil,nil,nil
    R.cleanChars=setmetatable({},{__mode="k"});R.cleanProfiles=setmetatable({},{__mode="k"})
    if Z.offlineOnly or not Z.me or not Z.storageKey then return false end
    local store=root()
    -- A newer format from a later addon version stays untouched and read-only.
    if store.version~=nil and store.version~=R.VERSION then R.readOnly=true;return false end
    store.version=R.VERSION
    if type(store.zones)~="table"then store.zones={}end
    if type(store.characters)~="table"then store.characters={}end
    R.store=store;R.char=adoptCharacter(store)
    invalidate();registerEvents()
    return true
end
function R.Enabled()return R.char~=nil end
function R.CurrentKey()return R.char and Z.storageKey or nil end

-- Settings are account-wide and live beside the history.
function R.Settings()
    local store=root();local s=store.settings
    if type(s)~="table"then s={};store.settings=s end
    for name,default in pairs(DEFAULTS)do if type(s[name])~=type(default)then s[name]=default end end
    if not STYLES[s.style]then s.style=DEFAULTS.style end
    if s.scale~=s.scale or s.scale<.6 or s.scale>1.6 then s.scale=DEFAULTS.scale end
    if s.duration~=s.duration or s.duration<1 or s.duration>15 then s.duration=DEFAULTS.duration end
    local pos=s.position
    if type(pos)~="table"or type(pos.x)~="number"or type(pos.y)~="number"or pos.x~=pos.x or pos.y~=pos.y
        or math.abs(pos.x)>10000 or math.abs(pos.y)>10000 then s.position=nil end
    return s
end
function R.SetSetting(name,value)
    local default=DEFAULTS[name]
    if default==nil or type(value)~=type(default)then return false end
    if name=="style"and not STYLES[value]then return false end
    if name=="scale"and not(value>=.6 and value<=1.6)then return false end
    if name=="duration"and not(value>=1 and value<=15)then return false end
    R.Settings()[name]=value
    if Z.RivalryBanner and Z.RivalryBanner.Apply then pcall(Z.RivalryBanner.Apply)end
    return true
end
-- Offset of the banner from the screen centre; nil restores the standard place.
function R.SetPosition(x,y)
    local s=R.Settings()
    if type(x)=="number"and type(y)=="number"and x==x and y==y and math.abs(x)<=10000 and math.abs(y)<=10000 then
        s.position={x=math.floor(x+.5),y=math.floor(y+.5)}
    else s.position=nil end
    if Z.RivalryBanner and Z.RivalryBanner.Apply then pcall(Z.RivalryBanner.Apply)end
    return true
end
-- Shows a sample banner; nothing is recorded.
function R.Preview(kind)
    local B=Z.RivalryBanner;if not B or not B.Push then return false end
    kind=KINDS[kind]and kind~="X"and kind or"K"
    return B.Push({kind=kind,name="Shadowblade",classFile="ROGUE",kills=8,deaths=5,assists=3,duelWins=2,duelLosses=1,fights=13,
        tag=kind=="K"and"RIVAL"or nil,preview=true})
end

-- Reading -------------------------------------------------------------------------------------------
local function scopeCharacters(scope)
    local out={}
    if scope=="ALL"then
        for key in pairs(R.store and R.store.characters or{})do local c=character(key);if c then out[#out+1]=c end end
    else
        local c=character(scope or R.CurrentKey());if c then out[1]=c end
    end
    return out
end
-- Characters with a history, the logged-in one first.
function R.Characters()
    local out={}
    for key in pairs(R.store and R.store.characters or{})do
        local c=character(key)
        if c then out[#out+1]={key=key,name=c.name or key,classFile=c.classFile,current=c==R.char}end
    end
    table.sort(out,function(a,b)
        if a.current~=b.current then return a.current end
        local an,bn=lower(a.name),lower(b.name);if an~=bn then return an<bn end
        return a.key<b.key
    end)
    return out
end
function R.Totals(scope)
    local t={rivals=0};for _,f in ipairs(TOTALS)do t[f]=0 end
    for _,c in ipairs(scopeCharacters(scope))do
        for _,f in ipairs(TOTALS)do t[f]=t[f]+c.totals[f]end
        t.rivals=t.rivals+c.totals.rivals
    end
    return t
end
local DETAILS={"realm","classFile","race","raceFile","faction","level"}
-- One merged row per opponent for a scope ("ALL" or a character key), cached until the history changes.
local function baseRows(scope)
    scope=scope or R.CurrentKey()or"ALL"
    local cache=R.cache
    if cache and cache.scope==scope and cache.revision==R.revision then return cache.rows,cache.byKey,cache.nemesis end
    local rows,byKey={},{}
    for _,c in ipairs(scopeCharacters(scope))do
        for key,raw in pairs(c.rivals)do
            local p=profile(raw)
            if p then
                local r=byKey[key]
                if not r then
                    r={key=key,name=p.name or key,kills=0,deaths=0,assists=0,involved=0,duelWins=0,duelLosses=0,encounters=0}
                    byKey[key]=r;rows[#rows+1]=r
                end
                for _,f in ipairs(COUNTERS)do r[f]=r[f]+p[f]end
                r.encounters=r.encounters+#p.events
                if p.first and(not r.first or p.first<r.first)then r.first=p.first end
                if p.last and(not r.last or p.last>=r.last)then
                    r.last=p.last;r.name=p.name or r.name
                    for _,f in ipairs(DETAILS)do r[f]=p[f]or r[f]end
                else
                    for _,f in ipairs(DETAILS)do r[f]=r[f]or p[f]end
                end
            end
        end
    end
    local nemesis
    for _,r in ipairs(rows)do
        r.fights=r.kills+r.deaths;r.duels=r.duelWins+r.duelLosses;r.rival=r.fights>=R.RIVAL_FIGHTS
        r.search=lower(r.name.." "..(r.classFile and L.ClassName("",r.classFile)or""))
        if r.deaths>=R.NEMESIS_DEATHS and(not nemesis or r.deaths>nemesis.deaths or r.deaths==nemesis.deaths and(r.last or 0)>(nemesis.last or 0))then nemesis=r end
    end
    if nemesis then nemesis.nemesis=true end
    R.cache={scope=scope,revision=R.revision,rows=rows,byKey=byKey,nemesis=nemesis}
    return rows,byKey,nemesis
end
local SORT_FIELD={LAST="last",FIGHTS="fights",KILLS="kills",DEATHS="deaths",ASSISTS="assists",DUELS="duels"}
local function sorter(sort)
    local field=SORT_FIELD[sort]
    return function(a,b)
        if sort=="NAME"then local an,bn=lower(a.name),lower(b.name);if an~=bn then return an<bn end;return a.key<b.key end
        local av,bv=a[field]or 0,b[field]or 0;if av~=bv then return av>bv end
        av,bv=a.last or 0,b.last or 0;if av~=bv then return av>bv end
        return a.key<b.key
    end
end
local MODES={
    ALL=function()return true end,
    RIVALS=function(r)return r.rival end,
    KILLED=function(r)return r.kills>0 end,
    KILLEDBY=function(r)return r.deaths>0 end,
    ASSISTS=function(r)return r.assists>0 end,
    DUELS=function(r)return r.duels>0 end,
}
-- filter: query (name or class), mode (ALL, RIVALS, KILLED, KILLEDBY, ASSISTS, DUELS),
-- sort (LAST, FIGHTS, KILLS, DEATHS, ASSISTS, DUELS, NAME).
function R.List(scope,filter)
    filter=filter or{};local rows=baseRows(scope);local out={}
    local query=lower(type(filter.query)=="string"and filter.query or"");local match=MODES[filter.mode]or MODES.ALL
    for _,r in ipairs(rows)do
        if match(r)and(query==""or r.search:find(query,1,true)~=nil)then out[#out+1]=r end
    end
    table.sort(out,sorter(SORT_FIELD[filter.sort]and filter.sort or filter.sort=="NAME"and"NAME"or"LAST"))
    return out
end
function R.Get(scope,key)
    local _,byKey=baseRows(scope)
    return byKey[key]
end
function R.Nemesis(scope)
    local _,_,nemesis=baseRows(scope)
    return nemesis
end
local function top(rows,field,limit)
    local out={}
    for _,r in ipairs(rows)do if(r[field]or 0)>0 then out[#out+1]=r end end
    table.sort(out,sorter(field=="last"and"LAST"or field=="fights"and"FIGHTS"or field=="kills"and"KILLS"or"DEATHS"))
    for i=#out,limit+1,-1 do out[i]=nil end
    return out
end
-- Totals and the four short lists of the overview, cached like the rows.
function R.Overview(scope,limit)
    scope=scope or R.CurrentKey()or"ALL";limit=limit or 5
    local o=R.overview
    if o and o.scope==scope and o.revision==R.revision and o.limit==limit then return o end
    local rows,_,nemesis=baseRows(scope)
    o={scope=scope,revision=R.revision,limit=limit,totals=R.Totals(scope),opponents=#rows,nemesis=nemesis,
        rivals=top(rows,"fights",limit),killed=top(rows,"kills",limit),killedBy=top(rows,"deaths",limit),recent=top(rows,"last",limit)}
    R.overview=o
    return o
end
-- The shared history with one opponent, newest first. Only this opponent's events are decoded.
function R.Timeline(scope,key)
    local out={}
    for _,c in ipairs(scopeCharacters(scope))do
        local p=profile(c.rivals[key])
        for _,e in ipairs(p and p.events or{})do
            local at,kind,ctx,zone,sub
            if type(e)=="string"then at,kind,ctx,zone,sub=e:match("^(%d+):(%a)(%a):(%d+):(%d+)$")end
            at=tonumber(at)
            if at and KINDS[kind]then
                out[#out+1]={at=at,kind=kind,context=ctx,zone=zoneName(zone),subzone=zoneName(sub),character=c.name}
            end
        end
    end
    table.sort(out,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.kind<b.kind end)
    return out
end
-- Places of a timeline, most frequent first.
function R.Places(timeline,limit)
    local counts,out={},{}
    for _,e in ipairs(timeline or{})do
        if e.zone~=""then
            local row=counts[e.zone]
            if not row then row={zone=e.zone,count=0};counts[e.zone]=row;out[#out+1]=row end
            row.count=row.count+1
        end
    end
    table.sort(out,function(a,b)if a.count~=b.count then return a.count>b.count end;return a.zone<b.zone end)
    for i=#out,(limit or 3)+1,-1 do out[i]=nil end
    return out
end
-- Current run of kills or deaths against one opponent: kind and length, nil without a lethal fight.
function R.Streak(timeline)
    local kind,count
    for _,e in ipairs(timeline or{})do
        if e.kind=="K"or e.kind=="D"then
            if not kind then kind,count=e.kind,1 elseif e.kind==kind then count=count+1 else break end
        end
    end
    return kind,count
end
local EVENT_TEXT={K="Killed %s",D="Killed by %s",A="Assist against %s",X="%s took part in your death",W="Duel won against %s",L="Duel lost against %s"}
function R.EventText(kind,name)
    return Z.T(EVENT_TEXT[kind]or"%s",name or Z.T("Unknown"))
end
local CONTEXT_TEXT={W="Open world",B="Battleground",A="Arena",I="Instance",D="Duel"}
function R.ContextLabel(ctx)
    return CONTEXT_TEXT[ctx]and Z.T(CONTEXT_TEXT[ctx])or""
end
-- The stored profile of a player the client shows (tooltip, target), by GUID first, then by name.
function R.Lookup(guid,name)
    if not R.char then return nil end
    local key=guidKind(guid)=="Player"and guidIndex()[guid]or nil
    key=key or identify(name)
    return key and profile(R.char.rivals[key])or nil,key
end
-- Key of the social-diary row of the same player, when the faction is known and a row exists.
function R.DiaryKey(row)
    local D=Z.SocialDiary
    if not D or not row or not row.faction or not Z.me then return nil end
    local key=L.ScopeKey(row.name,Z.me.realm,row.faction)
    return key and D.Get(key)and key or nil
end

-- Manual removal only; the history never shrinks by itself.
function R.Forget(scope,key)
    local removed=false
    for _,c in ipairs(scopeCharacters(scope))do
        local p=profile(c.rivals[key])
        if p then
            for kind,total in pairs(KIND_TOTAL)do c.totals[total]=math.max(0,c.totals[total]-p[KINDS[kind]])end
            c.rivals[key]=nil;c.totals.rivals=math.max(0,c.totals.rivals-1);removed=true
            if c.nemesis==key then findNemesis(c)end
        end
    end
    if removed then R.guids=nil;invalidate()end
    return removed
end
function R.ResetCharacter(key)
    key=key or R.CurrentKey()
    local c=character(key);if not c then return false end
    local fresh=newCharacter();fresh.name,fresh.classFile,fresh.guid=c.name,c.classFile,c.guid
    R.store.characters[key]=fresh;character(key).totals.rivals=0
    if c==R.char then R.char=fresh;R.guids=nil;R.settled={};R.pending={}end
    invalidate()
    return true
end
return R
