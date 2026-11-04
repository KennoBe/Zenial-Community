local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local H={VERSION=1,RETENTION=90*86400,MAX_ENTRIES=5000};Z.History=H
local EVENTS={
    recipe_scanned="Recipe catalog updated",recipe_partial="Partial recipe scan",group_created="Group published",group_updated="Group updated",group_closed="Group closed",group_expired="Group expired",
    quest_created="Quest request created",quest_updated="Quest request updated",quest_closed="Quest request closed",quest_expired="Quest request expired",
    application_received="Application received",application_queued="Application queued",application_delivered="Application delivered",application_failed="Application failed",
    withdrawal_sent="Application withdrawn",withdrawal_received="Withdrawal received",invited_sent="Invitation sent",invited_received="Invitation received",rejected_sent="Rejection sent",rejected_received="Rejection received",joined="Observed together in group",
}
H.EVENTS=EVENTS
local function validIdentity(key,target)
    if not L.Text(key,180)or not L.Text(target,113)then return false end
    return L.ValidIdentityKey(key)and L.Identity(target)~=nil
end
local function validEntry(e,now)
    if type(e)~="table"or not L.Text(e.id,64)or not L.Int(e.at,0,4102444800)or e.at<now-H.RETENTION then return false end
    if not validIdentity(e.ownKey,e.ownTarget)or(e.peerKey~=""and not validIdentity(e.peerKey,e.peerTarget))then return false end
    if(e.kind~="group"and e.kind~="quest"and e.kind~="craft")or not L.Text(e.contentID,32)or not L.Text(e.content,96,true)or not EVENTS[e.event]or not L.ValidIdentityKey(e.contentOwnerKey)then return false end
    return (e.observedAt==nil or L.Int(e.observedAt,1,4102444800))and(e.token==nil or L.Text(e.token,768,true))
end
local function sequence(e)return tonumber(e.id:match("%.(%d+)$"))or 0 end
local function sortNewest(a,b)if a.at==b.at then if sequence(a)~=sequence(b)then return sequence(a)>sequence(b)end;return a.id>b.id end;return a.at>b.at end
local function sortOldest(a,b)return sortNewest(b,a)end
local TERMINAL={group_closed=true,group_expired=true,quest_closed=true,quest_expired=true}
local SNAPSHOT_FIELDS={group={'id','mode','activity','min','max','have','note','start','expires','size','tank','healer','dd'},quest={'id','questID','title','zone','min','max','note','expires'}}
-- Archive only the validated content fields, never arbitrary SavedVariables.
local function snapshot(kind,content)
    if type(content)~='table'or not SNAPSHOT_FIELDS[kind]then return end
    local out={};for _,key in ipairs(SNAPSHOT_FIELDS[kind])do out[key]=content[key]end
    local valid=kind=='group'and L.ValidGroup(out,A.Now(),true)or kind=='quest'and L.ValidQuest(out,A.Now(),true)
    if valid then return out end
end
local function rebuildIndexes()
    H.revision=(H.revision or 0)+1
    if Z.MarkDirty then Z.MarkDirty("history")end
    H.byID,H.byToken,H.byPeer,H.byContent={},{},{},{};for _,e in ipairs(H.store and H.store.entries or{})do H.byID[e.id]=e;if e.token then H.byToken[e.token]=e end;if e.peerKey~=""then H.byPeer[e.peerKey]=H.byPeer[e.peerKey]or{};H.byPeer[e.peerKey][#H.byPeer[e.peerKey]+1]=e end;local id=e.kind..":"..e.contentOwnerKey..":"..e.contentID;H.byContent[id]=H.byContent[id]or{};H.byContent[id][#H.byContent[id]+1]=e end
end
function H.Initialize(root,me)
    local raw=type(root.history)=="table"and root.history or{};local store={version=H.VERSION,seq=L.Int(raw.seq,0,2147483646)and raw.seq or 0,entries={}}
    local now=A.Now();if type(raw.entries)=="table"then for _,e in ipairs(raw.entries)do if validEntry(e,now)then
        e.snapshot=TERMINAL[e.event]and e.peerKey==''and e.contentOwnerKey==e.ownKey and snapshot(e.kind,e.snapshot)or nil
        if e.snapshot and e.snapshot.id~=e.contentID then e.snapshot=nil end
        store.entries[#store.entries+1]=e
    end end end
    table.sort(store.entries,sortOldest);while #store.entries>H.MAX_ENTRIES do table.remove(store.entries,1)end
    root.history=store;H.store=store;H.me=me;rebuildIndexes();return store
end
function H.Prune(now)
    if not H.store then return false end;now=now or A.Now();local out,changed={},false
    for _,e in ipairs(H.store.entries)do if validEntry(e,now)then out[#out+1]=e else changed=true end end
    while #out>H.MAX_ENTRIES do table.remove(out,1);changed=true end
    if changed then H.store.entries=out;rebuildIndexes()end;return changed
end
function H.ContentName(kind,content)
    if type(content)=="string"then return L.Text(content,96,true)and content or""end
    if type(content)~="table"then return""end
    if kind=="group"then return L.Text(content.activity,64,true)and content.activity or""end
    local name=L.Text(content.title,96,true)and content.title or"";local zone=L.Text(content.zone,64,true)and content.zone or"";return zone~=""and(name.." · "..zone):sub(1,96)or name
end
function H.FindContent(kind,contentID,ownerKey)
    if not H.store then return""end
    if ownerKey then local entries=H.byContent[kind..":"..ownerKey..":"..contentID]or{};for i=#entries,1,-1 do if entries[i].content~=""then return entries[i].content end end else for i=#H.store.entries,1,-1 do local e=H.store.entries[i];if e.kind==kind and e.contentID==contentID and e.content~=""then return e.content end end end
    return""
end
function H.Record(kind,event,contentID,content,peerKey,peerTarget,token,contentOwnerKey)
    if not H.store or not EVENTS[event]or(kind~="group"and kind~="quest"and kind~="craft")or not L.Text(contentID,32)then return nil end
    peerKey,peerTarget=peerKey or"",peerTarget or"";if peerKey~=""and not validIdentity(peerKey,peerTarget)then return nil end
    if token and H.byToken[token]then return H.byToken[token]end
    contentOwnerKey=contentOwnerKey or H.me.key;if not L.ValidIdentityKey(contentOwnerKey)then return nil end;local now=A.Now();H.store.seq=math.min(H.store.seq+1,2147483646);local e={id=tostring(now).."."..tostring(H.store.seq),at=now,ownKey=H.me.key,ownTarget=H.me.target,peerKey=peerKey,peerTarget=peerTarget,kind=kind,contentID=contentID,contentOwnerKey=contentOwnerKey,content=H.ContentName(kind,content),event=event,token=token}
    if not validEntry(e,now)then return nil end;H.store.entries[#H.store.entries+1]=e;H.Prune(now);rebuildIndexes();if Z.UI and Z.UI.RefreshHistory then Z.UI.RefreshHistory()end;return e
end
function H.MarkObserved(entry)
    local now=A.Now()
    if entry and entry.event=="joined"and not entry.observedAt and L.Int(now,1,4102444800)then entry.observedAt=now;rebuildIndexes()end
end
function H.RecordOwn(kind,event,content)
    local e=H.Record(kind,event,content.id,content)
    if e and TERMINAL[event]then e.snapshot=snapshot(kind,content)end
    return e
end
function H.Archived()
    H.Prune();local out,seen={},{}
    for i=#(H.store and H.store.entries or{}),1,-1 do local e=H.store.entries[i]
        local key=e.kind..':'..e.contentID
        if TERMINAL[e.event]and e.ownKey==H.me.key and e.contentOwnerKey==H.me.key and e.peerKey==''and not seen[key]then
            seen[key]=true;out[#out+1]=e
        end
    end
    table.sort(out,sortNewest);return out
end
function H.RecordPeer(kind,event,contentID,content,peerKey,peerTarget,token,contentOwnerKey)
    contentOwnerKey=contentOwnerKey or H.me.key;local name=H.ContentName(kind,content);if name==""then name=H.FindContent(kind,contentID,contentOwnerKey)end
    return H.Record(kind,event,contentID,name,peerKey,peerTarget,token,contentOwnerKey)
end
function H.QueueApplication(kind,content,peerKey,peerTarget)
    local e=H.RecordPeer(kind,"application_queued",content.id,content,peerKey,peerTarget,nil,peerKey);return e and("ZH:"..e.id)or nil,e
end
function H.Remove(id)
    if not H.store or not id then return false end;for i=#H.store.entries,1,-1 do if H.store.entries[i].id==id then table.remove(H.store.entries,i);rebuildIndexes();return true end end;return false
end
function H.Delivery(peerKey,dedupe,ok)
    local sourceID=type(dedupe)=="string"and dedupe:match("^ZH:(.+)$");if not sourceID or not H.store then return false end
    local e=H.byID[sourceID];if e and e.peerKey==peerKey then H.RecordPeer(e.kind,ok and"application_delivered"or"application_failed",e.contentID,e.content,e.peerKey,e.peerTarget,"delivery:"..sourceID,e.contentOwnerKey);return true end
    return false
end
function H.EventLabel(event)local value=EVENTS[event]or event or"";return Z.T and Z.T(value)or value end
function H.Query(filter)
    filter=filter or{};local now=A.Now();local cutoff=now-(tonumber(filter.days)or 7)*86400;local query=string.lower(filter.query or"");local out={}
    for _,e in ipairs(H.store and H.store.entries or{})do local hay=string.lower(e.peerTarget.." "..e.content.." "..e.ownTarget);if e.at>=cutoff and(not filter.kind or e.kind==filter.kind)and(not filter.ownKey or e.ownKey==filter.ownKey)and(not filter.peerKey or e.peerKey==filter.peerKey)and(query==""or hay:find(query,1,true))then out[#out+1]=e end end
    table.sort(out,sortNewest);return out
end
function H.Related(entry)
    local out={};if not entry then return out end;for _,e in ipairs(H.byContent[entry.kind..":"..entry.contentOwnerKey..":"..entry.contentID]or{})do out[#out+1]=e end;table.sort(out,sortOldest);return out
end
function H.ContactSummaries(peerKey,currentID,limit,currentOwnerKey)
    currentOwnerKey=currentOwnerKey or H.me.key
    local grouped={};for _,e in ipairs(H.byPeer and H.byPeer[peerKey]or{})do if e.contentID~=currentID or e.contentOwnerKey~=currentOwnerKey then local id=e.kind..":"..e.contentOwnerKey..":"..e.contentID;local old=grouped[id];if not old or e.at>old.at or e.at==old.at and e.id>old.id then grouped[id]=e end end end
    local out={};for _,e in pairs(grouped)do out[#out+1]=e end;table.sort(out,sortNewest);while #out>(limit or 3)do table.remove(out)end;return out
end
function H.Delete(peerKey)
    if not H.store then return 0 end;local out,n={},0;for _,e in ipairs(H.store.entries)do if not peerKey or e.peerKey==peerKey then n=n+1 else out[#out+1]=e end end;H.store.entries=out;rebuildIndexes();if Z.UI and Z.UI.RefreshHistory then Z.UI.RefreshHistory()end;return n
end
