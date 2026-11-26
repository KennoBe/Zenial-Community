-- Event intake for the optional companion event lane (API_VERSION 1).
-- Emit only validates and queues: no protected calls, no game events, no frames.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local E={API_VERSION=1};Z.Events=E
local CATALOG=Z.EventCatalog
local QUEUE_LIMIT,BURST,RATE,CONTEXT_TEXT_MAX,TEXT_MAX=16,6,1,96,48
local REASONS={'consent','transport','unknown-type','payload','secret','duplicate','rate'}
local stats={accepted=0,sent=0,dropped=0,evicted=0,rejected={}}
for _,reason in ipairs(REASONS)do stats.rejected[reason]=0 end
-- Lookup tables per type, built once from the generated catalog.
local byName,contextSet={},{}
for name,entry in pairs(CATALOG.types)do
    byName[name]={};contextSet[name]={}
    for _,field in ipairs(entry.payload)do byName[name][field.name]=field end
    for _,context in ipairs(entry.context)do contextSet[name][context]=true end
end
E.queue={}
local order,dedupe,dedupeCount,bucket=0,{},0,{tokens=BURST,at=nil}
E.counter=0
function E.Reset()
    E.queue={};E.counter=0;order=0;dedupe={};dedupeCount=0;bucket={tokens=BURST,at=nil}
end
function E.Clear()E.queue={}end
function E.Purge(eventType)
    local kept={};for _,ev in ipairs(E.queue)do if ev.type~=eventType then kept[#kept+1]=ev end end
    E.queue=kept
end
local function refuse(reason)
    stats.rejected[reason]=(stats.rejected[reason]or 0)+1;return false,reason
end
local function validValue(field,v)
    local kind=type(v)
    if field.type=='boolean'then return kind=='boolean'end
    if field.type=='integer'then
        if kind~='number'or v~=v or v~=math.floor(v)then return false end
        return v>=(field.min or-math.huge)and v<=(field.max or math.huge)
    end
    if kind~='string'or#v>(field.maxLength or TEXT_MAX)then return false end
    if field.enum then
        for _,allowed in ipairs(field.enum)do if v==allowed then return true end end
        return false
    end
    if field.pattern and not v:find(field.pattern)then return false end
    return true
end
-- Returns the wire payload (short keys), the clean long-name payload and the dedupe key, or nil and a reason.
local function check(name,entry,payload)
    if type(payload)~='table'then return nil,'payload'end
    if not A.PublicTable(payload)then return nil,'secret'end
    -- A secret cannot be compared or used as a key, so it is found before any other check.
    for k,v in pairs(payload)do if not A.Safe(k,v)then return nil,'secret'end end
    local wire,clean={},{}
    for k,v in pairs(payload)do
        if type(k)~='string'then return nil,'payload'end
        local field=byName[name][k]
        if field then
            if not validValue(field,v)then return nil,'payload'end
            wire[field.key]=v;clean[k]=v
        elseif contextSet[name][k]then
            local kind=type(v)
            if kind=='string'then if#v>CONTEXT_TEXT_MAX then return nil,'payload'end
            elseif kind~='number'and kind~='boolean'then return nil,'payload'end
        else return nil,'payload'end
    end
    for _,field in ipairs(entry.payload)do if wire[field.key]==nil then return nil,'payload'end end
    local parts={name}
    for _,field in ipairs(entry.dedupe.fields)do
        if payload[field]==nil then return nil,'payload'end
        parts[#parts+1]=tostring(payload[field])
    end
    return wire,clean,table.concat(parts,'\31')
end
local function pruneDedupe(clock)
    for key,row in pairs(dedupe)do if clock-row[1]>=row[2]then dedupe[key]=nil;dedupeCount=dedupeCount-1 end end
end
local function emit(source,eventType,payload)
    local C=Z.Companion;local s=C and C.settings
    local name=type(eventType)=='string'and A.Safe(eventType)and eventType or nil
    if not s or s.enabled~=true or s.categories.events~=true or name and not C.EventTypeEnabled(name)then return refuse('consent')end
    if not C.running or C.debugPixel or not C.session then return refuse('transport')end
    local entry=name and type(source)=='string'and A.Safe(source)and CATALOG.types[name]or nil
    if not entry or entry.source~=source then return refuse('unknown-type')end
    local wire,clean,key=check(name,entry,payload)
    if not wire then return refuse(clean)end
    local clock=A.Clock();local observedAt=A.Now()
    if observedAt<1 then return refuse('transport')end
    local last=dedupe[key]
    if last and clock-last[1]<last[2]then return refuse('duplicate')end
    -- Token bucket: one event per second, six in a burst, shared by all types.
    local tokens=bucket.tokens
    if bucket.at then tokens=math.min(BURST,tokens+math.max(0,clock-bucket.at)*RATE)end
    if#E.queue>=QUEUE_LIMIT or tokens<1 then
        if entry.priority~='high'then return refuse('rate')end
        local oldest
        for index,ev in ipairs(E.queue)do if ev.rank==0 and(not oldest or ev.order<E.queue[oldest].order)then oldest=index end end
        if not oldest then return refuse('rate')end
        table.remove(E.queue,oldest);stats.evicted=stats.evicted+1
    end
    bucket.tokens=math.max(0,tokens-1);bucket.at=clock
    if not last then dedupeCount=dedupeCount+1;if dedupeCount>64 then pruneDedupe(clock)end end
    dedupe[key]={clock,entry.dedupe.window}
    order=order+1;E.counter=E.counter>=999999 and 1 or E.counter+1
    local ev={id=E.counter,type=name,source=source,rank=entry.rank,repeats=entry.repeats,sent=0,order=order,observedAt=observedAt,payload=wire}
    E.queue[#E.queue+1]=ev;stats.accepted=stats.accepted+1
    return true
end
function E.Emit(source,eventType,payload)
    local ok,accepted,reason=pcall(emit,source,eventType,payload)
    if not ok then return refuse('payload')end
    return accepted,reason
end
function E.Describe()
    local names={};for name in pairs(CATALOG.types)do names[#names+1]=name end
    table.sort(names);return{apiVersion=E.API_VERSION,catalogVersion=CATALOG.version,types=names}
end
function E.Status()
    local rejected={};for reason,count in pairs(stats.rejected)do rejected[reason]=count end
    return{accepted=stats.accepted,sent=stats.sent,dropped=stats.dropped,evicted=stats.evicted,queued=#E.queue,rejected=rejected}
end
-- Transport side: the next events to put on the pixel strip. A waiting high event
-- allows two lines, otherwise one; order is priority, then age.
function E.Pick()
    local list={};for _,ev in ipairs(E.queue)do list[#list+1]=ev end
    if#list==0 then return list end
    table.sort(list,function(a,b)if a.rank~=b.rank then return a.rank>b.rank end;return a.order<b.order end)
    local wanted=list[1].rank==2 and 2 or 1;local out={}
    for i=1,math.min(wanted,#list)do out[i]=list[i]end
    return out
end
local function remove(ev)
    for index,row in ipairs(E.queue)do if row==ev then table.remove(E.queue,index);return end end
end
function E.Sent(ev)
    ev.sent=ev.sent+1;stats.sent=stats.sent+1
    if ev.sent>=ev.repeats then remove(ev)end
end
function E.Drop(ev)remove(ev);stats.dropped=stats.dropped+1 end
-- Wire body {"i":id,"t":type,"p":{short keys}}; no origin/data envelope.
function E.Body(ev,json)
    return string.format('{"i":%d,"t":%s,"p":%s}',ev.id,json(ev.type),json(ev.payload))
end
