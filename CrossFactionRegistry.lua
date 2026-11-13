-- XF3-T01 registry of players that sent a valid cross-faction protocol signal (key: character GUID). Pure logic over a passed table; time is always a parameter.
local Z=ZenialCommunity
local A=Z.Adapter
local R={TTL=2592000,RECENT=300,MAX=1000,MAX_MISSES=3,INCOMPATIBLE_TTL=7200,MAX_INCOMPATIBLE=200};Z.CrossFactionRegistry=R
local floor,huge=math.floor,math.huge
local SOURCES={xf=true,addon=true,bnet=true}
local STATUS_SOURCES={xf=true,addon=true,bnet=true,community=true}
local players,count,selfGuid
local verified,missed,incompat,incompatCount,faction={},{},{},0,{}

local function validGuid(g)
    if not A.Safe(g) or type(g)~='string' or #g>64 or g:sub(1,7)~='Player-' then return false end
    return true
end
local function validNow(n)return A.Safe(n) and type(n)=='number' and n==n and n>0 and n<huge end
local function num(v)
    if A.Safe(v) and type(v)=='number' and v==v and v>=0 and v<huge then return floor(v) end
end
local function cleanName(n)
    if A.Safe(n) and type(n)=='string' and #n<=64 then return n end
    return ''
end
local function validEntry(g,e)
    if not validGuid(g) or type(e)~='table' then return false end
    local n,t,p,c,s,m=e.n,e.t,e.p,e.c,e.s,e.m
    return type(n)=='string' and #n<=64 and type(t)=='number' and t==t and t>0 and t<huge
        and type(p)=='number' and p==p and p>=0 and type(c)=='number' and c==c and c>=0
        and SOURCES[s]==true and type(m)=='number' and m==m and m>=0 and m<R.MAX_MISSES
end
-- Oldest signal first; equal times resolved by the smaller GUID (deterministic).
local function older(ga,ta,gb,tb)return ta<tb or(ta==tb and ga<gb)end
local function dropSession(g)verified[g]=nil;missed[g]=nil;faction[g]=nil end
local function removeStored(g)
    if players and players[g]~=nil then players[g]=nil;count=count-1 end
    dropSession(g)
end
local function evictOldest()
    local og,ot
    for g,e in pairs(players)do if not og or older(g,e.t,og,ot)then og,ot=g,e.t end end
    if og then removeStored(og) end
end
local function resetSession()verified,missed,incompat,incompatCount,faction={},{},{},0,{}end
local function recent(t,now)return now-t<R.RECENT end

function R.SetSelf(guid)
    selfGuid=validGuid(guid)and guid or nil
    if selfGuid and players and players[selfGuid]~=nil then removeStored(selfGuid) end
end
-- Binds store.players (created if missing), drops expired/invalid entries, trims to MAX and starts a new session.
function R.Attach(store,now,guid)
    resetSession()
    if type(store)~='table' then players,count=nil,0;return end
    if type(store.players)~='table' then store.players={} end
    players,count=store.players,0
    selfGuid=validGuid(guid)and guid or nil
    local drop,keep,n={},{},0
    for g,e in pairs(players)do
        local ok=validEntry(g,e) and g~=selfGuid
        if ok and validNow(now) and now-e.t>R.TTL then ok=false end
        if ok then n=n+1;keep[n]=g else drop[#drop+1]=g end
    end
    for i=1,#drop do players[drop[i]]=nil end
    if n>R.MAX then
        table.sort(keep,function(a,b)return older(b,players[b].t,a,players[a].t)end) -- newest first
        for i=R.MAX+1,n do players[keep[i]]=nil end
        n=R.MAX
    end
    count=n
end
-- info={name,faction,proto,xfChat,caps,source}; returns true when written.
function R.Confirm(guid,info,now)
    if not players or not validNow(now) or not validGuid(guid) or guid==selfGuid then return false end
    if not A.Safe(info) or type(info)~='table' then return false end
    local source=info.source
    if not A.Safe(source) or SOURCES[source]~=true then return false end
    local e=players[guid]
    if not e then
        if count>=R.MAX then evictOldest() end
        e={n='',p=0,c=0};players[guid]=e;count=count+1
    end
    local name=cleanName(info.name)
    if name~='' or e.n==nil then e.n=name end
    e.p=num(info.proto)or e.p
    local caps=num(info.caps)or e.c
    if A.Safe(info.xfChat) and info.xfChat==true and caps%2==0 then caps=caps+1
    elseif A.Safe(info.xfChat) and info.xfChat==false and caps%2==1 then caps=caps-1 end
    e.c,e.s,e.t,e.m=caps,source,now,0
    verified[guid]=true;missed[guid]=nil
    local f=info.faction
    if A.Safe(f) and type(f)=='string' and #f<=64 then faction[guid]=f end
    return true
end
function R.Incompatible(guid,info,now)
    if not validNow(now) or not validGuid(guid) or guid==selfGuid then return end
    if not A.Safe(info) or type(info)~='table' then info={} end
    local src=info.source
    if not A.Safe(src) or STATUS_SOURCES[src]~=true then src=nil end
    local f=info.faction
    if not(A.Safe(f) and type(f)=='string' and #f<=64)then f=nil end
    if not incompat[guid] then
        if incompatCount>=R.MAX_INCOMPATIBLE then
            local og,ot
            for g,v in pairs(incompat)do if not og or older(g,v.t,og,ot)then og,ot=g,v.t end end
            if og then incompat[og]=nil;incompatCount=incompatCount-1 end
        end
        incompatCount=incompatCount+1
    end
    incompat[guid]={n=cleanName(info.name),t=now,p=num(info.proto)or 0,s=src,f=f}
end
local function liveIncompat(guid,now)
    local v=incompat[guid]
    if not v then return nil end
    if validNow(now) and now-v.t>R.INCOMPATIBLE_TTL then incompat[guid]=nil;incompatCount=incompatCount-1;return nil end
    return v
end
function R.Get(guid,now)
    if not validGuid(guid) then return nil end
    local e=players and players[guid]
    if e and validNow(now) and now-e.t>R.TTL then removeStored(guid);e=nil end
    local v=liveIncompat(guid,now)
    local isRecent=function(t)return validNow(now) and recent(t,now)end
    if e and not(v and not isRecent(e.t))then
        return {status='CONFIRMED',name=e.n,proto=e.p,caps=e.c,xfChat=e.c%2==1 or nil,source=e.s,lastSeen=e.t,
            misses=e.m,verified=verified[guid]==true,recent=isRecent(e.t),faction=faction[guid]}
    end
    if v then
        return {status='INCOMPATIBLE',name=v.n,proto=v.p,caps=0,source=v.s,lastSeen=v.t,misses=0,verified=false,
            recent=isRecent(v.t),faction=v.f or faction[guid]}
    end
    return nil
end
function R.NeedsRefresh(guid)
    return validGuid(guid) and players~=nil and players[guid]~=nil and verified[guid]~=true
end
function R.Miss(guid,now)
    if not players or not validNow(now) or not validGuid(guid) then return 'ignored' end
    local e=players[guid]
    if not e or verified[guid] or missed[guid] then return 'ignored' end
    missed[guid]=true
    e.m=e.m+1
    if e.m>=R.MAX_MISSES then removeStored(guid);return 'removed' end
    return 'counted'
end
-- Returns the GUIDs whose status changed through expiry (stored entries by TTL, INCOMPATIBLE by its own TTL).
function R.Expire(now)
    local changed,list={},{}
    if not validNow(now) then return list end
    local goneInc,goneStored={},{}
    for g,v in pairs(incompat)do if now-v.t>R.INCOMPATIBLE_TTL then goneInc[#goneInc+1]=g end end
    if players then for g,e in pairs(players)do if now-e.t>R.TTL then goneStored[#goneStored+1]=g end end end
    for i=1,#goneStored do local g=goneStored[i];removeStored(g);changed[g]=true end
    for i=1,#goneInc do
        local g=goneInc[i];incompat[g]=nil;incompatCount=incompatCount-1
        local e=players and players[g]
        if not(e and recent(e.t,now))then changed[g]=true end -- a recent stored entry stayed CONFIRMED all along
    end
    for g in pairs(changed)do list[#list+1]=g end
    table.sort(list)
    return list
end
function R.Forget(guid)
    if not validGuid(guid) then return end
    removeStored(guid)
    if incompat[guid] then incompat[guid]=nil;incompatCount=incompatCount-1 end
end
function R.Reset()
    if players then for g in pairs(players)do players[g]=nil end end
    count=0
    resetSession()
end
function R.Count()return count or 0 end
