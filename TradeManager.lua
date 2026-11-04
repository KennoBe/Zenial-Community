local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local M={alerts={}}
Z.TradeManager=M

local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function copy(o)local c={};for k,v in pairs(o or{})do if type(v)~="table"then c[k]=v end end;return c end
local function unit(o)return(o.quantity or 1)>0 and(o.price or 0)/(o.quantity or 1)or(o.price or 0)end
local function category(o)return Z.Items and Z.Items.Category(o.itemID,o.kind)or(o.kind=="SERVICE"and"SERVICE"or"UNCLASSIFIED")end
local function validRule(r)
    return type(r)=="table"and L.Text(r.id,32)and L.Text(r.name or"",64,true)and L.Text(r.query or"",96,true)and(r.kind=="ALL"or r.kind=="BUY"or r.kind=="SELL"or r.kind=="SERVICE")and L.Text(r.category or"ALL_ITEM_CATEGORIES",32)
        and L.Int(r.itemID or 0,0,10000000)and(r.minPrice==nil or L.Int(r.minPrice,0,2147483646))and(r.maxPrice==nil or L.Int(r.maxPrice,0,2147483646))
        and(not r.minPrice or not r.maxPrice or r.minPrice<=r.maxPrice)and L.Int(r.createdAt or 0,0,4102444800)
end
local function validStoredOffer(row)
    return type(row)=="table"and(row.kind=="BUY"or row.kind=="SELL"or row.kind=="SERVICE")and L.Int(row.itemID or 0,0,10000000)
        and(row.duration==nil or L.Int(row.duration,1,1440))and(row.archivedAt==nil or L.Int(row.archivedAt,0,4102444800))and(row.localID==nil or L.Text(row.localID,64))
        and L.Text(row.name,96)and L.Int(row.quantity or 1,1,100000)and L.Int(row.price or 0,0,2147483646)and L.Text(row.note or"",96,true)
end
local function pruneSeen(seen)
    local rows={};local now=A.Now()
    for token,row in pairs(seen)do
        if L.Text(token,220)and type(row)=="table"and type(row.match)=="boolean"and L.Int(row.price,0,2147483646)and L.Int(row.at,0,4102444800)and row.at>=now-86400 and row.at<=now then rows[#rows+1]={token=token,at=row.at}
        else seen[token]=nil end
    end
    table.sort(rows,function(a,b)return a.at>b.at end);for i=1001,#rows do seen[rows[i].token]=nil end
end
function M.Initialize()
    local raw=type(Z.db.tradeStore)=="table"and Z.db.tradeStore or{};local t={drafts={},paused={},closed={},templates={},rules={},alertsSeen={},activeMeta={}}
    local stored=0;for _,name in ipairs({"drafts","paused"})do for id,row in pairs(type(raw[name])=="table"and raw[name]or{})do if stored<100 and L.Text(id,64)and validStoredOffer(row)then t[name][id]=row;stored=stored+1 end end end
    local n=0;for name,row in pairs(type(raw.templates)=="table"and raw.templates or{})do if n<20 and L.Text(name,64)and validStoredOffer(row)then t.templates[name]=row;n=n+1 end end
    n=0;for id,row in pairs(type(raw.closed)=="table"and raw.closed or{})do if n<100 and L.Text(id,64)and validStoredOffer(row)and(row.state=="completed"or row.state=="expired")then t.closed[id]=row;n=n+1 end end
    n=0;for id,rule in pairs(type(raw.rules)=="table"and raw.rules or{})do if n<20 and validRule(rule)and id==rule.id then rule.name=rule.name or"";rule.query=rule.query or"";rule.category=rule.category or"ALL_ITEM_CATEGORIES";t.rules[id]=rule;t.alertsSeen[id]=type(raw.alertsSeen)=="table"and type(raw.alertsSeen[id])=="table"and raw.alertsSeen[id]or{};n=n+1 end end
    for id,localID in pairs(type(raw.activeMeta)=="table"and raw.activeMeta or{})do if L.Text(id,32)and L.Text(localID,64)then t.activeMeta[id]=localID end end
    for _,seen in pairs(t.alertsSeen)do pruneSeen(seen)end
    Z.db.tradeStore=t;M.store=t;M.alerts={};M.sessionStarted=A.Now();M.baselined={}
end
function M.SaveRule(rule)
    if type(rule)~="table"then return nil,"Suchregel ist ungültig."end;rule=copy(rule);rule.name=rule.name or"";rule.query=rule.query or"";rule.id=rule.id or L.NextID(Z.db,A.Now());rule.kind=rule.kind or"ALL";rule.category=rule.category or"ALL_ITEM_CATEGORIES";rule.createdAt=rule.createdAt or A.Now()
    if not validRule(rule)then return nil,"Suchregel ist ungültig."end
    if not M.store.rules[rule.id]and count(M.store.rules)>=20 then return nil,"Maximal 20 gespeicherte Suchen."end
    M.store.rules[rule.id]=rule;return rule.id
end
function M.DeleteRule(id)M.store.rules[id]=nil;M.store.alertsSeen[id]=nil;if Z.Notifications then Z.Notifications.RemoveSource("trade",id)end end
function M.Match(rule,offer,target)
    if not validRule(rule)or type(offer)~="table"then return false end
    local q=string.lower(rule.query or"");local hay=string.lower((offer.name or"").." "..(target or"").." "..(offer.note or""))
    local textMatch=((rule.itemID or 0)==0 and(q==""or hay:find(q,1,true)~=nil))or((rule.itemID or 0)>0 and offer.itemID==rule.itemID)
    return textMatch
        and(rule.kind=="ALL"or offer.kind==rule.kind)
        and(rule.category=="ALL_ITEM_CATEGORIES"or category(offer)==rule.category)
        and(not rule.minPrice or unit(offer)>=rule.minPrice)and(not rule.maxPrice or unit(offer)<=rule.maxPrice)
end
local function fingerprint(offer)
    local wire=Z.Network3.Pack({offer.kind,offer.itemID,offer.name,offer.quantity,offer.price,offer.note or"",offer.expires})
    local first,second=1,0;for i=1,#wire do first=(first+wire:byte(i))%65521;second=(second+first)%65521 end
    return tostring(first)..":"..tostring(second)
end
local function alert(row,revision)
    M.alerts[#M.alerts+1]=row;if#M.alerts>100 then table.remove(M.alerts,1)end
    if Z.Notifications then Z.Notifications.Trade(row,revision or 0)end
end
function M.OnRetract(key,id,revision)
    local target=Z.db.contacts[key]and Z.db.contacts[key].target or key
    for rule,seen in pairs(M.store.alertsSeen)do local old=seen[key..":"..id]
        if old and old.match and not old.closed then
            alert({rule=rule,key=key,target=target,offer={id=id,name=old.name or Z.T("Offer")},at=A.Now(),closed=true},revision)
            old.closed=true;old.match=false
        end
    end
end
function M.OnBundle(key,snapshot)
    local contact=Z.db.contacts[key];local target=contact and contact.target or key;local baseline=M.baselined[key];local current={}
    for _,offer in ipairs(snapshot.market or{})do
        current[offer.id]=true;local signature=fingerprint(offer)
        for id,rule in pairs(M.store.rules)do
            local token=key..":"..offer.id;local seen=M.store.alertsSeen[id]or{};M.store.alertsSeen[id]=seen
            local matched=M.Match(rule,offer,target);local old=seen[token]
            if baseline and matched then
                local updated=old and old.match and((old.fingerprint and old.fingerprint~=signature)or(not old.fingerprint and old.price~=offer.price))
                local published=tonumber((offer.id or""):match("^(%d+)"))or 0
                local fresh=old and not old.match or not old and published>=math.max(M.sessionStarted,rule.createdAt or 0)
                if updated or fresh then alert({rule=id,key=key,offer=copy(offer),target=target,at=A.Now(),updated=updated==true,priceChanged=old and old.price~=offer.price or false},snapshot.rev)end
            end
            seen[token]={match=matched,price=offer.price,at=A.Now(),fingerprint=signature,name=offer.name,id=offer.id}
        end
    end
    if baseline then
        local prefix=key..":";local missing={}
        for _,seen in pairs(M.store.alertsSeen)do for token,old in pairs(seen)do
            if token:sub(1,#prefix)==prefix and old.match and not old.closed then
                local id=token:sub(#prefix+1);if not current[id]then missing[id]=true end
            end
        end end
        for id in pairs(missing)do M.OnRetract(key,id,snapshot.rev)end
    end
    for _,seen in pairs(M.store.alertsSeen)do pruneSeen(seen)end
    if not M.baselined[key]and count(M.baselined)>=L.MAX_CONTACTS then M.baselined[next(M.baselined)]=nil end;M.baselined[key]=true
end
local function archive(kind,offer)
    if not offer then return nil,"Angebot nicht gefunden."end
    local row=copy(offer);row.localID=M.store.activeMeta[offer.id]or L.NextID(Z.db,A.Now());row.archivedAt=A.Now();row.state=kind;row.id=nil
    local bucket=kind=="paused"and M.store.paused or M.store.drafts;if count(M.store.paused)+count(M.store.drafts)>=100 then return nil,"Lokaler Angebotsspeicher ist voll."end
    bucket[row.localID]=row;M.store.activeMeta[offer.id]=nil;L.CloseOffer(Z.db,offer.id);if Z.Network3 then Z.Network3.Retract("M",offer.id,Z.db.rev)end;Z.Publish();return row.localID
end
function M.Pause(id)for _,o in ipairs(Z.db.market)do if o.id==id then return archive("paused",o)end end;return nil,"Angebot nicht gefunden."end
function M.Duplicate(id)for _,o in ipairs(Z.db.market)do if o.id==id then local row=copy(o);row.id=nil;row.localID=L.NextID(Z.db,A.Now());row.state="draft";if count(M.store.paused)+count(M.store.drafts)>=100 then return nil,"Lokaler Angebotsspeicher ist voll."end;M.store.drafts[row.localID]=row;return row.localID end end;return nil,"Angebot nicht gefunden."end
local function rememberClosed(offer,state)
    local row=copy(offer);row.localID=M.store.activeMeta[offer.id]or L.NextID(Z.db,A.Now());row.publicationID=offer.id;row.id=nil;row.state=state;row.archivedAt=A.Now();M.store.closed[row.localID]=row
    local all={};for id,item in pairs(M.store.closed)do all[#all+1]={id=id,at=item.archivedAt or 0}end;table.sort(all,function(a,b)return a.at>b.at end);for i=101,#all do M.store.closed[all[i].id]=nil end
    M.store.activeMeta[offer.id]=nil;return row.localID
end
function M.Complete(id)for _,o in ipairs(Z.db.market)do if o.id==id then rememberClosed(o,"completed");L.CloseOffer(Z.db,id);if Z.Network3 then Z.Network3.Retract("M",id,Z.db.rev)end;Z.Publish();return true end end;return false end
function M.ArchiveExpired(now)
    local changed=false;for i=#Z.db.market,1,-1 do local offer=Z.db.market[i];if offer.expires<=now then rememberClosed(offer,"expired");table.remove(Z.db.market,i);changed=true end end;if changed then L.Touch(Z.db)end;return changed
end
function M.SaveDraft(offer,existingID)
    if not validStoredOffer(offer)then return nil,"Entwurf ist ungültig."end
    if existingID and not M.store.drafts[existingID]then return nil,"The draft no longer exists."end
    if not existingID and count(M.store.paused)+count(M.store.drafts)>=100 then return nil,"Lokaler Angebotsspeicher ist voll."end
    local row=copy(offer);row.id=nil;row.localID=existingID or L.NextID(Z.db,A.Now());row.state="draft";M.store.drafts[row.localID]=row;return row.localID
end
function M.ConsumeStored(state,id)
    local bucket=state=="paused"and M.store.paused or state=="draft"and M.store.drafts
    if bucket then bucket[id]=nil end
end
function M.TrackPublication(publicID,previousID,sourceID)
    local localID=sourceID or(previousID and M.store.activeMeta[previousID])or L.NextID(Z.db,A.Now());if previousID and previousID~=publicID then M.store.activeMeta[previousID]=nil end;M.store.activeMeta[publicID]=localID;return localID
end
function M.SaveTemplate(name,offer)
    if not L.Text(name,64)or type(offer)~="table"then return nil,"Vorlage ist ungültig."end
    if not M.store.templates[name]and count(M.store.templates)>=20 then return nil,"Maximal 20 Vorlagen."end
    local row=copy(offer);row.id=nil;row.expires=nil;M.store.templates[name]=row;return true
end
function M.PopAlert()return table.remove(M.alerts,1)end
return M
