local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local function tr(value)return Z.T and Z.T(value)or value end
local P={jobs={},deathArmed=false};Z.PvPHelp=P
local CALL_LIFETIME,DEATH_WINDOW,CALL_COOLDOWN=600,3600,600
P.HISTORY_WINDOW,P.MAX_HISTORY=7200,100
P.DEATH_MARK_WINDOW=1800

local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function validID(v)return L.Text(v,32)and v:match("^[%d%.]+$")end
local function cleanLocation(v)
    if type(v)~="table"then return{mapID=0,area="",subzone="",hasPos=false,x=0,y=0}end
    local mapID=L.Int(v.mapID or 0,0,1000000)and v.mapID or 0;local x=L.Int(v.x or 0,0,10000)and v.x or 0;local y=L.Int(v.y or 0,0,10000)and v.y or 0
    return{mapID=mapID,area=L.Text(v.area or"",64,true)and v.area or"",subzone=L.Text(v.subzone or"",64,true)and v.subzone or"",hasPos=v.hasPos==true and mapID>0,x=x,y=y,layerID=L.Int(v.layerID,1,4294967295)and v.layerID or nil}
end
local function cleanEnemy(v)
    if type(v)~="table"or not L.Text(v.name,113)then return nil end
    return{name=v.name,class=L.Text(v.class or"",24,true)and v.class or"",level=L.Int(v.level or 0,0,100)and v.level or 0,faction=L.Text(v.faction or"",16,true)and v.faction or""}
end
local MAX_DEATHS,MAX_ATTACKERS,MAX_LOG=16,5,8
P.DEATH_SCHEMA,P.MAX_LOG,P.MAX_ATTACKERS=2,MAX_LOG,MAX_ATTACKERS
-- One identified attacker. Level is nil when unknown (never 0 and never the skull level -1).
local function cleanPerson(v)
    if type(v)~="table"or not L.Text(v.name,80)then return nil end
    local classFile=type(v.classFile)=="string"and#v.classFile<=16 and v.classFile:match("^[A-Z_]+$")and v.classFile or""
    return{name=v.name,classFile=classFile,race=L.Text(v.race or"",24,true)and v.race or"",level=L.Int(v.level,1,100)and v.level or nil}
end
-- A confirmed PvP death record; GUIDs are never part of it.
local function cleanDeath(v,now)
    if type(v)~="table"or v.cause~="player"or v.confirmed~=true or not L.Text(v.id,32)or not v.id:match("^[%d%.]+$")
        or not L.Int(v.at,1,4102444800)or v.at>now+120 then return nil end
    local d=cleanLocation(v);d.id,d.at,d.cause,d.confirmed,d.attackersComplete=v.id,v.at,"player",true,false
    d.minAttackers=L.Int(v.minAttackers,1,40)and v.minAttackers or 1;d.killer=cleanPerson(v.killer);d.attackers={}
    for _,a in ipairs(type(v.attackers)=="table"and v.attackers or{})do if#d.attackers>=MAX_ATTACKERS then break end;local c=cleanPerson(a);if c then d.attackers[#d.attackers+1]=c end end
    if d.killer and#d.attackers==0 then d.attackers[1]=cleanPerson(d.killer)end
    d.minAttackers=math.max(d.minAttackers,#d.attackers);return d
end
local function cleanKillLog(list,now)
    local out={};for _,v in ipairs(type(list)=="table"and list or{})do if#out>=MAX_LOG then break end;local d=cleanDeath(v,now);if d then out[#out+1]=d end end
    return#out>0 and out or nil
end
P.CleanDeath,P.CleanKillLog=cleanDeath,cleanKillLog
local function copyLocation(dst,src)dst.mapID, dst.area, dst.subzone, dst.hasPos, dst.x, dst.y,dst.layerID=src.mapID,src.area,src.subzone,src.hasPos,src.x,src.y,src.layerID end
local function peerFaction(key)local p=Z.db and Z.db.peers[key];return p and(p.faction or p.data and p.data.faction)end
local function currentCall()local o=P.store and P.store.own;return o and o.expires>A.Now()and o or nil end
local function contactTarget(key)local c=Z.db and Z.db.contacts[key];return c and c.target end
local function refresh()if Z.UI and Z.UI.RefreshPvPHelp then Z.UI.RefreshPvPHelp()end;if Z.UI and Z.UI.UpdateBadges then Z.UI.UpdateBadges()end end

local function loadStore(raw,now)
    raw=type(raw)=="table"and raw or{};local s={history={},receive=raw.receive==true,scope=raw.scope=="zone"and"zone"or"all",deaths={},lastDeath=nil,own=nil,received={},helpers={},seen={},cancelled={},ended={},senderLast={},lastCallAt=L.Int(raw.lastCallAt or 0,0,4102444800)and raw.lastCallAt or 0}
    -- Schema 2: confirmed PvP death records. Plain timestamps of older versions were never validated as PvP and are dropped.
    s.schema=P.DEATH_SCHEMA;s.recapSig=L.Text(raw.recapSig or"",200,true)and raw.recapSig or""
    if raw.schema==P.DEATH_SCHEMA and type(raw.deaths)=="table"then for _,v in ipairs(raw.deaths)do
        local d=#s.deaths<MAX_DEATHS and cleanDeath(v,now);if d and d.at>now-DEATH_WINDOW then s.deaths[#s.deaths+1]=d end end end
    if type(raw.lastDeath)=="table"and L.Int(raw.lastDeath.at or 0,1,4102444800)then
        s.lastDeath=cleanLocation(raw.lastDeath);s.lastDeath.at=raw.lastDeath.at
        for _,d in ipairs(s.deaths)do if d.id==raw.lastDeath.id then s.lastDeath=d;break end end
    end
    if type(raw.own)=="table"and validID(raw.own.id)and L.Int(raw.own.expires or 0,1,4102444800)and raw.own.expires>now and raw.own.expires<=now+CALL_LIFETIME and L.Int(raw.own.at,1,4102444800)then
        local o=cleanLocation(raw.own);o.id,o.rev,o.at,o.expires,o.note,o.enemy,o.recipients,o.responses=raw.own.id,L.Int(raw.own.rev or 1,1,2147483646)and raw.own.rev or 1,raw.own.at or now,raw.own.expires,L.Text(raw.own.note or"",96,true)and raw.own.note or"",cleanEnemy(raw.own.enemy),{},{};o.killLog=cleanKillLog(raw.own.killLog,now);o.killRev=o.rev
        for key,row in pairs(type(raw.own.recipients)=="table"and raw.own.recipients or{})do if L.ValidIdentityKey(key)and type(row)=="table"then local state=row.state=="confirmed"and"confirmed"or row.state=="error"and"error"or row.state=="notified"and"notified"or"queued";o.recipients[key]={state=state,at=L.Int(row.at or 0,0,4102444800)and row.at or 0}end end
        for key,row in pairs(type(raw.own.responses)=="table"and raw.own.responses or{})do if L.ValidIdentityKey(key)and type(row)=="table"and(row.state=="coming"or row.state=="withdrawn")then o.responses[key]={state=row.state,at=L.Int(row.at or 0,0,4102444800)and row.at or 0}end end;s.own=o
    end
    for token,row in pairs(type(raw.received)=="table"and raw.received or{})do if count(s.received)>=40 then break end;if type(row)=="table"and L.ValidIdentityKey(row.key)and validID(row.id)and L.Int(row.expires or 0,1,4102444800)and row.expires>now and row.expires<=now+CALL_LIFETIME and L.Int(row.at,1,4102444800)then local r=cleanLocation(row);r.key,r.id,r.rev,r.at,r.expires,r.unread,r.note,r.detail,r.response=row.key,row.id,L.Int(row.rev or 1,1,2147483646)and row.rev or 1,row.at or now,row.expires,row.unread==true,L.Text(row.note or"",96,true)and row.note or"",row.detail==true,row.response=="coming"and"coming"or"";r.locationRev=L.Int(row.locationRev,1,2147483646)and row.locationRev or r.rev;r.detailRev=L.Int(row.detailRev,0,2147483646)and row.detailRev or 0;r.enemy=cleanEnemy(row.enemy);r.killLog=cleanKillLog(row.killLog,now);r.killRev=L.Int(row.killRev,0,2147483646)and row.killRev or 0;s.received[row.key..":"..row.id]=r end end
    for key,row in pairs(type(raw.helpers)=="table"and raw.helpers or{})do if count(s.helpers)>=L.MAX_CONTACTS then break end;if L.ValidIdentityKey(key)and type(row)=="table"and row.enabled==true then s.helpers[key]={enabled=true,scope=row.scope=="zone"and"zone"or"all",mapID=L.Int(row.mapID or 0,0,1000000)and row.mapID or 0,at=L.Int(row.at or 0,0,4102444800)and row.at or 0}end end
    for token,expires in pairs(type(raw.seen)=="table"and raw.seen or{})do if count(s.seen)>=100 then break end;if type(token)=="string"and L.Int(expires,1,4102444800)and expires>now then s.seen[token]=expires end end
    for key,at in pairs(type(raw.senderLast)=="table"and raw.senderLast or{})do if count(s.senderLast)<L.MAX_CONTACTS and L.ValidIdentityKey(key)and L.Int(at,1,4102444800)and at>now-86400 and at<=now then s.senderLast[key]=at end end
    for token,row in pairs(type(raw.cancelled)=="table"and raw.cancelled or{})do if count(s.cancelled)<100 and L.Text(token,220)and type(row)=="table"and L.Int(row.rev,1,2147483646)and L.Int(row.expires,1,4102444800)and row.expires>now and row.expires<=now+1200 then s.cancelled[token]=row end end
    for id,row in pairs(type(raw.ended)=="table"and raw.ended or{})do if count(s.ended)<20 and validID(id)and type(row)=="table"and L.Int(row.rev,1,2147483646)and L.Int(row.expires,1,4102444800)and row.expires>now and row.expires<=now+1200 then s.ended[id]=row;row.next=0 end end
    for _,row in pairs(type(raw.history)=="table"and raw.history or{})do
        if count(s.history)>=P.MAX_HISTORY then break end
        if type(row)=="table"and L.ValidIdentityKey(row.key)and validID(row.id)and L.Int(row.at,1,4102444800)
            and row.at>now-P.HISTORY_WINDOW and row.at<=now+120 and L.Int(row.expires,1,4102444800)and row.expires>=row.at and row.expires<=row.at+CALL_LIFETIME then
            local r=cleanLocation(row);r.key,r.id,r.at,r.expires=row.key,row.id,row.at,row.expires
            r.rev=L.Int(row.rev,1,2147483646)and row.rev or 1;r.closed=row.closed==true;r.note=L.Text(row.note or"",96,true)and row.note or""
            r.enemy=cleanEnemy(row.enemy);r.killLog=cleanKillLog(row.killLog,now);r.killRev=L.Int(row.killRev,0,2147483646)and row.killRev or 0;r.detail=row.detail==true;r.response=row.response=="coming"and"coming"or""
            if L.Int(row.deathMapID,1,1000000)and L.Int(row.deathX,0,10000)and L.Int(row.deathY,0,10000)then r.deathMapID,r.deathX,r.deathY=row.deathMapID,row.deathX,row.deathY end
            s.history[r.key..":"..r.id]=r
        end
    end
    return s
end
local function remember(key,row,closed)
    if not P.store or not key or Z.db.blocked[key]or(key~=Z.me.key and peerFaction(key)~=Z.me.faction)then return end
    local token=key..":"..row.id;local old=P.store.history[token]
    if old and(row.rev or 1)<old.rev then return old end
    if not old and count(P.store.history)>=P.MAX_HISTORY then
        local oldest,at;for k,r in pairs(P.store.history)do if not at or r.at<at then oldest,at=k,r.at end end
        if at and row.at<at then return end;P.store.history[oldest]=nil
    end
    local r=old or cleanLocation(row);copyLocation(r,cleanLocation(row));r.key,r.id,r.at,r.expires=key,row.id,row.at,row.expires
    r.rev=row.rev or 1;r.closed=closed==true or r.closed==true
    if row.detail==true or key==Z.me.key then r.note=row.note or"";r.enemy=cleanEnemy(row.enemy);r.detail=true;if row.killLog then r.killLog,r.killRev=row.killLog,row.killRev or r.killRev end
    elseif not r.detail then r.note=row.note or r.note or""end
    r.response=row.response or r.response or"";P.store.history[token]=r;return r
end
-- "Name – Class – Race – Level"; whatever is unknown is said so (level -1/0 is never shown as a number).
function P.FormatPerson(v)
    local unknown=Z.T("Unknown")
    return table.concat({v.name or unknown,(v.classFile or"")~=""and L.ClassName("",v.classFile)or unknown,(v.race or"")~=""and v.race or unknown,
        v.level and Z.T("Level %d",v.level)or Z.T("Level unknown")}," – ")
end
-- Readable lines of one kill log (killer and further attackers separated), used by preview and helper details.
function P.KillLogLines(log,truncated)
    local lines={}
    for _,d in ipairs(log or{})do
        lines[#lines+1]=date("%H:%M",d.at)..(d.area and d.area~=""and" · "..d.area or"")
        local attackers=d.attackers or{};local killer=d.killer
        lines[#lines+1]="  "..Z.T("Killer: %s",killer and P.FormatPerson(killer)or Z.T("Unknown"))
        local more=(d.minAttackers or 1)-(killer and 1 or 0)
        if more>0 then
            lines[#lines+1]="  "..Z.T(killer and"Further attackers (at least %d)"or"Attackers (at least %d)",more)
            for _,a in ipairs(attackers)do if not(killer and a.name==killer.name)then lines[#lines+1]="    "..P.FormatPerson(a)end end
        end
    end
    if truncated then lines[#lines+1]=Z.T("Kill log shortened")end
    return lines
end
function P.GetCall(key,id)
    local r=P.store and(P.store.received[key..":"..id]or P.store.history[key..":"..id])
    return r and not Z.db.blocked[key]and A.Now()-r.at<P.HISTORY_WINDOW and r or nil
end
function P.IsActive(r)return r and not r.closed and r.expires>A.Now()and(r.key==Z.me.key or Z.IsOnline(r.key))or false end
function P.ListCalls()
    P.Expire();local out={};local seen={}
    for token,r in pairs(P.store.received)do remember(r.key,r);seen[token]=true;out[#out+1]=r end
    for token,r in pairs(P.store.history)do if not seen[token]and not Z.db.blocked[r.key]then out[#out+1]=r end end
    table.sort(out,function(a,b)if a.at~=b.at then return a.at>b.at end;if a.key~=b.key then return a.key<b.key end;return a.id<b.id end);return out
end

function P.Initialize(root,key)
    root.pvpHelp=type(root.pvpHelp)=="table"and root.pvpHelp or{};P.store=loadStore(root.pvpHelp[key],A.Now());root.pvpHelp[key]=P.store;P.deathArmed=not A.IsDeadOrGhost();P.notified=nil;if Z.PvPDeath then Z.PvPDeath.Initialize()end;P.jobs={};P.nextAnnounce=0;if P.store.own then remember(Z.me.key,P.store.own)end;P.Expire()
end
function P.UnreadCount()local n,now=0,A.Now();for _,r in pairs(P.store and P.store.received or{})do if r.unread and r.expires>now and not Z.db.blocked[r.key]and Z.IsOnline(r.key)then n=n+1 end end;return n end
-- Confirmed PvP deaths of the last 60 minutes (older or future records are dropped).
function P.DeathCount()
    local now=A.Now();for i=#P.store.deaths,1,-1 do local d=P.store.deaths[i];if type(d)~="table"or d.at<=now-DEATH_WINDOW or d.at>now+120 then table.remove(P.store.deaths,i)end end;return #P.store.deaths
end
-- Unlock rule: two confirmed PvP deaths in 60 minutes, or one with at least two proven player attackers.
function P.RuleMet()
    local n=P.DeathCount();if n>=2 then return true end
    for _,d in ipairs(P.store.deaths)do if(d.minAttackers or 0)>=2 then return true end end
    return false
end
-- Same checks and texts as before; the code and cooldown end serve the Companion export (cooldownUntil is server time).
function P.CallState()
    local now=A.Now();local cooldownUntil=P.store.lastCallAt>0 and P.store.lastCallAt+CALL_COOLDOWN>now and P.store.lastCallAt+CALL_COOLDOWN or nil
    if currentCall()then return false,"active","Es läuft bereits ein Hilferuf.",cooldownUntil end
    if cooldownUntil then return false,"cooldown","Ein neuer Hilferuf ist erst nach zehn Minuten möglich.",cooldownUntil end
    if not A.IsPvpFlagged()then return false,"unflagged",Z.T("You must be flagged for PvP to request help."),cooldownUntil end
    if P.testMode then return true,nil,nil,cooldownUntil end
    if not P.RuleMet()then return false,"deaths",Z.T("Another %d death(s) needed before requesting help.",math.max(1,2-P.DeathCount())),cooldownUntil end
    if not P.store.lastDeath then return false,"no-location","Kein Todesort gespeichert.",cooldownUntil end;return true,nil,nil,cooldownUntil
end
function P.CanCall()
    local ok,_,text=P.CallState();if ok then return true end;return false,text
end
-- Test aid: lifts only the two-deaths rule, until the next reload (a plain field, never saved).
-- The current position stands in for the place of death. All other limits still apply.
function P.ToggleTestMode()P.testMode=not P.testMode or nil;refresh();return P.testMode==true end
function P.UseTestLocation()
    if not P.testMode then return end
    local loc=A.PvpLocation(false);loc.at=A.Now();P.store.lastDeath=loc
end
function P.FormatLocation(v)
    if not v then return tr("Location unknown")end;local place=v.area~=""and v.area or tr("Area unknown");if v.subzone and v.subzone~=""and v.subzone~=v.area then place=place.." · "..v.subzone end
    if v.hasPos then place=place..string.format(" · %.1f / %.1f",v.x/100,v.y/100)end
    local layer=v.layerID
    if not layer and v.key and v.id and v.rev and Z.CommunityLayer then layer=Z.CommunityLayer.Call(v.key,v.id,v.rev,v.mapID)end
    -- Only the caller's own reported layer is shown; an unknown layer (always so in dungeons) is simply omitted.
    local known=Z.CommunityLayer and Z.CommunityLayer.KnownLabel(layer);return known and place.." · "..known or place
end
function P.Own()return currentCall()end
function P.RecipientCounts()
    local notified,confirmed,errors,queued=0,0,0,0
    for _,r in pairs(currentCall()and currentCall().recipients or{})do
        if r.state=="confirmed"then notified=notified+1;confirmed=confirmed+1 elseif r.state=="notified"then notified=notified+1 elseif r.state=="error"then errors=errors+1 else queued=queued+1 end
    end
    return notified,confirmed,errors,queued
end
function P.ComingCount()
    local n=0;for _,r in pairs(currentCall()and currentCall().responses or{})do if r.state=="coming"then n=n+1 end end;return n
end
function P.BroadcastResult(kind,wire,result)
    local f=Z.Network3.Unpack(wire);local o=currentCall();local revision=f and tonumber(f[2])
    if not o or not f or f[1]~=o.id or not L.Int(revision,1,2147483646)or revision~=o.rev or(kind~="PC"and kind~="PU")or(result~="sent"and result~="error")then return end
    -- Each relay route completes separately. One successful send establishes
    -- this revision's broadcast state; later redundant failures cannot undo it.
    if result=="sent"then o.broadcastSentRev=o.rev elseif o.broadcastSentRev==o.rev then return end
    if o.broadcastState~=result then o.broadcastState=result;refresh()end
end
function P.Delivery(key,dedupe,ok)
    local o=currentCall();if not o or type(dedupe)~="string"or dedupe~="H1C:"..key..":"..o.id then return end
    local r=o.recipients[key];if not r or r.state=="confirmed"then return end;r.state=ok and"notified"or"error";r.at=A.Now();refresh()
end
local function compact(kind,o)return{kind=kind,id=o.id,rev=o.rev,at=o.at,expires=o.expires,mapID=o.mapID,area=o.area,subzone=o.subzone,hasPos=o.hasPos,x=o.x,y=o.y}end
local function enqueue(key,msg,priority,dedupe,track)
    P.jobs[#P.jobs+1]={key=key,msg=msg,priority=priority or 90,dedupe=dedupe,track=track};return true
end
local function clearCallJobs(id)for i=#P.jobs,1,-1 do if P.jobs[i].track==id then table.remove(P.jobs,i)end end end
function P.PumpJobs()
    if not Z.engine then return end
    while #P.jobs>0 and #Z.engine.out<48 do
        local j=table.remove(P.jobs,1);local ok,err=Z.engine:Queue(j.key,j.msg,true,j.priority,j.dedupe)
        if ok then if j.track then local o=currentCall();if o and o.id==j.track then o.recipients[j.key]={state="queued",at=A.Now()}end end
        elseif err=="Warteschlange voll."then table.insert(P.jobs,1,j);break
        elseif j.track then local o=currentCall();if o and o.id==j.track then o.recipients[j.key]={state="error",at=A.Now()}end end
    end
end
local function eligibleHelper(key,o)
    local h=P.store.helpers[key]
    return h and h.enabled and h.at>A.Now()-600 and Z.IsOnline(key) and peerFaction(key)==Z.me.faction and (h.scope=="all"or h.mapID==o.mapID)
end
local function enqueueCallFor(key,o)
    if o.recipients[key]or not eligibleHelper(key,o)then return false end
    return enqueue(key,compact("H1C",o),95,"H1C:"..key..":"..o.id,o.id)
end
function P.SendReadiness(key)
    if not P.store or not Z.db.contacts[key]or key==Z.me.key then return end
    enqueue(key,{kind="H1R",enabled=P.store.receive,scope=P.store.scope,mapID=A.CurrentMapID()},85,"H1R:"..key)
end
function P.SendReadinessAll()if not P.store or not Z.db then return end;for key in pairs(Z.db.contacts)do P.SendReadiness(key)end end
function P.SetReceive(enabled)P.store.receive=enabled==true;if Z.Network3 then Z.Network3.nextPresence=0 end;refresh();return P.store.receive end
function P.SetScope(scope)P.store.scope=scope=="zone"and"zone"or"all";if Z.Network3 then Z.Network3.nextPresence=0 end;refresh();return P.store.scope end
local function announce(o,kind)
    local queued=Z.Network3.QueuePublic(kind or"PC",Z.Network3.Pack({o.id,o.rev,o.at,o.expires,o.mapID,o.area,o.subzone,o.hasPos and 1 or 0,o.x,o.y}),90,"PVPCALL")
    if o.broadcastSentRev~=o.rev then o.broadcastState=queued and"queued"or"error"end
    P.nextAnnounce=A.Clock()+60;return queued
end
-- Snapshot of the proven PvP deaths of the last 60 minutes, newest first (the unlock counters are reset afterwards).
function P.KillLog()
    local now=A.Now();P.DeathCount();local list={}
    for _,d in ipairs(P.store.deaths)do list[#list+1]=d end
    table.sort(list,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.id<b.id end)
    while#list>MAX_LOG do table.remove(list)end
    return cleanKillLog(list,now)
end
function P.CreateCall(note,shareEnemy)
    local ok,err=P.CanCall();if not ok then return nil,err end;if not L.Text(note or"",96,true)then return nil,"Die Nachricht ist zu lang."end
    P.UseTestLocation();local now=A.Now();local d=P.store.lastDeath;local o=cleanLocation(d);o.id=L.NextID(Z.db,now);o.rev=1;o.at=now;o.expires=now+CALL_LIFETIME;o.note=note or"";o.killLog=shareEnemy and P.KillLog()or nil;o.killRev=o.rev
    -- H1I (old clients) carries the proven killer of the latest death, never the current target.
    local k=o.killLog and o.killLog[1] and o.killLog[1].killer;o.enemy=k and cleanEnemy({name=k.name,class=L.ClassName("",k.classFile),level=k.level or 0,faction=""})or nil
    o.recipients={};o.responses={};P.store.own=o;P.store.deaths={};P.notified=nil;P.store.lastCallAt=now;remember(Z.me.key,o)
    if Z.Network3 then announce(o)end;refresh();return o.id
end
function P.EndOwn()
    local o=currentCall();if not o then return false,"Kein aktiver Hilferuf."end
    clearCallJobs(o.id);o.rev=math.min(o.rev+1,2147483646);remember(Z.me.key,o,true)
    P.store.ended[o.id]={rev=o.rev,expires=o.expires+CALL_LIFETIME,next=0}
    if Z.Network3 then Z.Network3.CancelPublic("PVPCALL");Z.Network3.QueuePublic("PX",Z.Network3.Pack({o.id,o.rev}),100,"PVPCANCEL:"..o.id)end;P.store.own=nil;refresh();return true
end
function P.UpdateLocation()
    local o=currentCall();if not o then return false,"Kein aktiver Hilferuf."end;local now=A.Now();if o.lastUpdate and now-o.lastUpdate<30 then return false,"Standort kann nur alle 30 Sekunden aktualisiert werden."end
    local loc=A.PvpLocation(false);copyLocation(o,loc);o.rev=math.min(o.rev+1,2147483646);o.lastUpdate=now;remember(Z.me.key,o)
    if Z.Network3 then announce(o,"PU")end;refresh();return true
end
function P.ListReceived()
    P.Expire();local out={};for _,r in pairs(P.store.received)do if Z.IsOnline(r.key)then out[#out+1]=r end end;table.sort(out,function(a,b)return a.at>b.at end);return out
end
function P.GetReceived(key,id)return Z.IsOnline(key)and P.store.received[key..":"..id]or nil end
function P.MarkRead(key,id)local r=P.GetCall(key,id);if r then r.unread=false;local h=P.store.history[key..":"..id];if h then h.unread=false end;refresh();return true end end
function P.RequestDetails(key,id)local r=P.GetCall(key,id);if not P.IsActive(r)or key==Z.me.key then return false end;P.MarkRead(key,id);if not r.detail then enqueue(key,{kind="H1D",id=id},100,"H1D:"..key..":"..id)end;if not r.killLog then enqueue(key,{kind="H2D",id=id},90,"H2D:"..key..":"..id)end;return true end
function P.Respond(key,id,state)
    local r=P.GetCall(key,id);if not P.IsActive(r)or key==Z.me.key or(state~="coming"and state~="withdrawn")then return false,"Hilferuf nicht mehr aktiv."end
    enqueue(key,{kind="H1J",id=id,state=state},100,"H1J:"..key..":"..id);r.response=state=="coming"and"coming"or"";refresh();return true
end
function P.InviteHelper(key)
    local o=currentCall();local r=o and o.responses[key];local target=contactTarget(key);if not o or not r or r.state~="coming"or not target then return false,"Keine aktive Zusage."end
    return A.InvitePvp(target)
end
function P.Block(key)
    for i=#P.jobs,1,-1 do if P.jobs[i].key==key then table.remove(P.jobs,i)end end
    for token,r in pairs(P.store.history)do if r.key==key then P.store.history[token]=nil end end
    P.store.helpers[key]=nil;P.store.senderLast[key]=nil;for token,r in pairs(P.store.received)do if r.key==key then P.store.received[token]=nil end end;local o=currentCall();if o then o.recipients[key]=nil;o.responses[key]=nil end
end

-- Only a call that actually reached this helper gets a map marker. The first reported position
-- is the place of death; later location updates must not move it.
local function rememberDeathPlace(token,s)
    local h=P.store.history[token]
    if h and not h.deathMapID and s.hasPos and L.Int(s.mapID,1,1000000)then h.deathMapID,h.deathX,h.deathY=s.mapID,s.x,s.y end
end
function P.DeathMarks()
    local out={};if not P.store or not P.store.receive then return out end;local now=A.Now()
    for _,r in pairs(P.store.history)do
        if r.deathMapID and r.key~=Z.me.key and not Z.db.blocked[r.key]and now-r.at<P.DEATH_MARK_WINDOW and r.at<=now+120 then out[#out+1]=r end
    end
    return out
end
local function acceptCall(key,s,noAck)
    if peerFaction(key)~=Z.me.faction or Z.db.blocked[key]then return end
    if not P.store.cancelled[key..":"..s.id]then remember(key,s)end
    -- Every active call of the same faction is listed (and counted as unread); only a helper who opted in (and whose area
    -- filter matches) is also acked, fetches the details at once and gets the banner.
    local listen=P.store.receive and(P.store.scope~="zone"or A.CurrentMapID()==s.mapID)or false
    local now=A.Now();local token=key..":"..s.id
    if P.store.cancelled[token]then return end
    if P.store.received[token]then
        local r=P.store.received[token];rememberDeathPlace(token,s)
        if s.rev>(r.locationRev or 0)then copyLocation(r,cleanLocation(s));r.locationRev=s.rev;r.rev=math.max(r.rev,s.rev)end
        if not noAck and listen then enqueue(key,{kind="H1A",id=s.id},100,"H1A:"..key..":"..s.id)end;return end
    if P.store.seen[token]or(P.store.senderLast[key]and now-P.store.senderLast[key]<CALL_COOLDOWN)then return end
    if count(P.store.received)>=40 then return end
    local r=cleanLocation(s);r.locationRev=s.rev;r.detailRev=0;r.key,r.id,r.rev,r.at,r.expires,r.unread,r.note,r.detail,r.response=key,s.id,s.rev,s.at,s.expires,true,"",false,"";P.store.received[token]=r;P.store.seen[token]=s.expires+CALL_COOLDOWN;P.store.senderLast[key]=now
    rememberDeathPlace(token,s);local known=P.store.history[token]
    if known then r.response=known.response or"";if known.detail then r.note,r.enemy,r.detail=known.note,cleanEnemy(known.enemy),true;r.killLog,r.killRev=known.killLog,known.killRev end end
    if not listen then refresh();return end -- listed silently; details are requested when the call is opened
    if not noAck then enqueue(key,{kind="H1A",id=s.id},100,"H1A:"..key..":"..s.id)end
    -- Enrolled helpers fetch the details right away for the banner; once per call, and it stays unread.
    if not r.detail then enqueue(key,{kind="H1D",id=s.id},100,"H1D:"..key..":"..s.id)end
    enqueue(key,{kind="H2D",id=s.id},90,"H2D:"..key..":"..s.id) -- new clients ask for the kill log separately; old senders ignore H2D
    if Z.OnPvpHelpIncoming then Z.OnPvpHelpIncoming(key,s.id)end;refresh()
end
function P.Receive(key,s)
    if not P.store or not Z.db.contacts[key]then return end;local now=A.Now()
    if s.kind=="H1R"then P.store.helpers[key]={enabled=s.enabled,scope=s.scope,mapID=s.mapID,at=now};local o=currentCall();if o then enqueueCallFor(key,o)end
    elseif s.kind=="H1C"then acceptCall(key,s)
    elseif s.kind=="H1A"then local o=currentCall();local r=o and o.id==s.id and o.recipients[key];if r then r.state="confirmed";r.at=now end
    elseif s.kind=="H1D"then local o=currentCall();if o and o.id==s.id then local e=o.enemy;enqueue(key,{kind="H1I",id=o.id,rev=o.rev,note=o.note,hasEnemy=e~=nil,enemyName=e and e.name or"",enemyClass=e and e.class or"",enemyLevel=e and e.level or 0,enemyFaction=e and e.faction or""},100,"H1I:"..key..":"..o.id)end
    elseif s.kind=="H2D"then
        -- Structured kill log (H2I) only on this explicit request and only when the player shared the detected combat data.
        local o=currentCall();if o and o.id==s.id then local fit=o.killLog and L.FitH2I({id=o.id,rev=o.rev,note=o.note,deaths=o.killLog});if fit then enqueue(key,fit,90,"H2I:"..key..":"..o.id)end end
    elseif s.kind=="H2I"then local r=P.GetCall(key,s.id);if P.IsActive(r)and s.rev>=(r.killRev or 0)then r.killRev=s.rev;r.rev=math.max(r.rev,s.rev);r.note=s.note;r.detail=true;r.killLog=cleanKillLog(s.deaths,A.Now());r.killTruncated=s.truncated;remember(key,r);if Z.UI and Z.UI.RefreshPvPNotice then Z.UI.RefreshPvPNotice(key,s.id)end end
    elseif s.kind=="H1I"then local r=P.GetCall(key,s.id);if P.IsActive(r)and s.rev>=(r.detailRev or 0)then r.detailRev=s.rev;r.rev=math.max(r.rev,s.rev);r.note=s.note;r.detail=true;r.enemy=s.hasEnemy and{name=s.enemyName,class=s.enemyClass,level=s.enemyLevel,faction=s.enemyFaction}or nil;remember(key,r);if Z.UI and Z.UI.RefreshPvPNotice then Z.UI.RefreshPvPNotice(key,s.id)end end
    elseif s.kind=="H1U"then local r=P.GetReceived(key,s.id);if r and s.rev>(r.locationRev or 0)then copyLocation(r,cleanLocation(s));r.locationRev=s.rev;r.rev=math.max(r.rev,s.rev)end
    elseif s.kind=="H1X"then local r=P.GetCall(key,s.id);if r then remember(key,r,true)end;P.store.received[key..":"..s.id]=nil
    elseif s.kind=="H1J"then local o=currentCall();if o and o.id==s.id then local old=o.responses[key];o.responses[key]={state=s.state,at=now};if(not old or old.state~=s.state)and Z.Notifications then Z.Notifications.Push("groups","pvp","pvp:"..o.id..":"..key,now,s.state,key,o.id)end end end
    refresh()
end
function P.Receive3(sender,kind,wire)
    local key=Z.ResolvePeerKey(sender);local peer=key and Z.db.peers[key];if not key or not peer or not peer.cap30 or not Z.IsOnline(key)then return false end
    local f=Z.Network3.Unpack(wire);if not f then return false end
    if kind=="PX"then
        local rev=tonumber(f[2]);if#f~=2 or not validID(f[1])or not L.Int(rev,1,2147483646)then return false end
        local token=key..":"..f[1];local r=P.GetCall(key,f[1]);if r and rev>=r.rev then r.rev=rev;remember(key,r,true)end;P.store.received[token]=nil
        if count(P.store.cancelled)>=100 and not P.store.cancelled[token]then local oldest,at;for k,row in pairs(P.store.cancelled)do if not at or row.expires<at then oldest,at=k,row.expires end end;P.store.cancelled[oldest]=nil end
        P.store.cancelled[token]={rev=rev,expires=A.Now()+CALL_LIFETIME*2};refresh();return true
    end
    if(kind~="PC"and kind~="PU")or#f~=10 then return false end
    local s={kind=kind,id=f[1],rev=tonumber(f[2]),at=tonumber(f[3]),expires=tonumber(f[4]),mapID=tonumber(f[5]),area=f[6],subzone=f[7],hasPos=tonumber(f[8])==1,x=tonumber(f[9]),y=tonumber(f[10])}
    if not L.Int(tonumber(f[8]),0,1)or not validID(s.id)or not L.Int(s.rev,1,2147483646)or not L.Int(s.at,1,4102444800)or not L.Int(s.expires,1,4102444800)or s.at>s.expires or s.expires>A.Now()+CALL_LIFETIME or s.expires<=A.Now()or not L.Int(s.mapID,0,1000000)or not L.Text(s.area,64,true)or not L.Text(s.subzone,64,true)or not L.Int(s.x,0,10000)or not L.Int(s.y,0,10000)then return false end
    acceptCall(key,s,true);refresh()
    return true
end
-- Called by the detection with a confirmed PvP death (cause player, fatal blow by a player or a player's pet).
function P.RecordDeath(death)
    if not P.store then return false end
    local now=A.Now();local d=cleanDeath(death,now);if not d then return false end
    for _,old in ipairs(P.store.deaths)do if old.id==d.id then return false end end
    P.DeathCount();P.store.deaths[#P.store.deaths+1]=d;while#P.store.deaths>MAX_DEATHS do table.remove(P.store.deaths,1)end
    P.store.lastDeath=d
    -- The offer appears once per unlock; it never sends anything and never opens a window by itself.
    if P.RuleMet()and not P.notified and P.CanCall()then P.notified=true;if Z.OnPvpHelpEligible then Z.OnPvpHelpEligible()end end
    -- The map marker is independent of the unlock rule and of CanCall().
    if Z.CommunityMap and Z.CommunityMap.PublishDeath then Z.CommunityMap.PublishDeath(d)end
    refresh();return true
end
function P.OnEvent(event,unit)
    if not P.store then return end
    if event=="PLAYER_FLAGS_CHANGED"then
        if A.Safe(unit)and unit=="player"then refresh()end
    elseif event=="PLAYER_DEAD"then
        if Z.PvPDeath then Z.PvPDeath.OnEvent(event)end;refresh()
    elseif event=="PLAYER_ALIVE"or event=="PLAYER_UNGHOST"then
        if Z.PvPDeath then Z.PvPDeath.OnEvent(event)end
        local d=P.store.lastDeath;if d and not d.hasPos then local corpse=A.PvpLocation(true);if corpse.hasPos and(d.mapID==0 or corpse.mapID==d.mapID)then d.mapID,d.hasPos,d.x,d.y=corpse.mapID,true,corpse.x,corpse.y end end
        if not A.IsDeadOrGhost()then P.deathArmed=true end;refresh()
    end
end
function P.Expire()
    if not P.store then return end;local now=A.Now();P.DeathCount();if P.notified and not P.RuleMet()then P.notified=nil end
    local o=P.store.own;if o and o.expires<=now then remember(Z.me.key,o);clearCallJobs(o.id);P.store.own=nil end
    for token,r in pairs(P.store.received)do if r.expires<=now or Z.db.blocked[r.key]then if not Z.db.blocked[r.key]then remember(r.key,r)end;P.store.received[token]=nil end end
    for token,r in pairs(P.store.history)do if now-r.at>=P.HISTORY_WINDOW or Z.db.blocked[r.key]then P.store.history[token]=nil end end
    for token,row in pairs(P.store.cancelled)do if row.expires<=now then P.store.cancelled[token]=nil end end
    for key,at in pairs(P.store.senderLast)do if at<=now-86400 then P.store.senderLast[key]=nil end end
    for token,expires in pairs(P.store.seen)do if expires<=now then P.store.seen[token]=nil end end
    for key,h in pairs(P.store.helpers)do if Z.db.blocked[key]or h.at<now-3600 then P.store.helpers[key]=nil end end
end
function P.Tick()
    P.Expire();P.PumpJobs();if Z.PvPDeath then Z.PvPDeath.Tick()end
    if not Z.Network3 or not Z.db.consent or not Z.db.autoDiscovery then return end
    local o=currentCall();if o and A.Clock()>=(P.nextAnnounce or 0)then announce(o)end
    local now=A.Now();for id,row in pairs(P.store.ended)do if row.expires<=now then P.store.ended[id]=nil elseif A.Clock()>=(row.next or 0)then Z.Network3.QueuePublic("PX",Z.Network3.Pack({id,row.rev}),100,"PVPCANCEL:"..id);row.next=A.Clock()+60 end end
end
