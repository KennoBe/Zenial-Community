local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local O={}
Z.CraftOrders=O
local TERMINAL={COMPLETED=true,DECLINED=true,CANCELLED=true,EXPIRED=true}
local STATES={REQUESTED=true,ACCEPTED=true,READY=true,COMPLETED=true,DECLINED=true,CANCELLED=true,EXPIRED=true}
-- Normal admission remains capped at 100. A delayed acceptance may additionally
-- restore any of the 1,000 retained local expirations without losing an order.
local MAX_RETAINED_ACTIVE=1100
local function orderKey(direction,peer,id)return direction=="incoming"and peer..":"..id or id end
O.Key=orderKey
function O.Get(id,peer,direction)
    local key=orderKey(direction or"incoming",peer,id)
    return O.orders[key]or Z.db.craftOrderHistory[key]
end
local function hasRecipe(id,profession)
    for _,r in ipairs(Z.db.recipes or{})do if r.id==id and(not profession or profession==""or L.ProfessionName(r.profession)==L.ProfessionName(profession))then return true end end
    return false
end
local function contactTarget(key)local c=Z.db.contacts[key];return c and c.target end
local function queueOperation(order,kind,values,opSeq)
    local target=contactTarget(order.peer);if not target then return nil,"Spieler nicht bekannt."end
    local wire=Z.Network3.Pack(values);local token="ORDER:"..order.key..":"..tostring(opSeq or 0)
    local op={kind=kind,wire=wire,target=target,opSeq=opSeq or 0,attempts=0,next=A.Clock()};Z.db.craftOrderOps[order.key]=op
    local sent,err=Z.Network3.QueueDirect(target,kind,wire,95,token)
    if sent then op.attempts=1;op.next=A.Clock()+20;order.delivery="sending"else order.delivery="queued"end
    return sent or true,err
end
local function sendStatus(order,opSeq,result)
    local target=contactTarget(order.peer);if not target then return false end
    local sent=Z.Network3.QueueDirect(target,"OS",Z.Network3.Pack({order.id,opSeq or 0,result or"OK",order.state,order.revision,order.updatedAt}),100,"ORDERSTATUS:"..order.key);order.statusPending=true;order.statusAttempts=(order.statusAttempts or 0)+1;order.statusRetry=A.Clock()+(order.statusAttempts<=3 and 20 or 120);return sent
end
local function validOrder(id,row)
    return type(row)=="table"and L.Text(id,32)and id:match("^[%d%.]+$")and(row.direction=="incoming"or row.direction=="outgoing")
        and L.ValidIdentityKey(row.peer)and L.Int(row.recipeID,1,10000000)and L.Int(row.itemID or 0,0,10000000)
        and L.Text(row.recipeName,96)and L.Text(row.profession or"",64,true)and L.Int(row.quantity,1,100000)
        and type(row.materialsProvided)=="boolean"and L.Int(row.tip or 0,0,2147483646)and L.Text(row.note or"",192,true)
        and L.Int(row.createdAt,1,4102444800)and L.Int(row.expires,1,4102444800)and row.expires==row.createdAt+86400
        and STATES[row.state]and L.Int(row.revision or 0,0,2147483646)and L.Int(row.operationSeq or 0,0,2147483646)
        and L.Int(row.updatedAt or row.createdAt,1,4102444800)
end
local function pruneHistory(now)
    local rows={};for id,row in pairs(Z.db.craftOrderHistory)do if validOrder(row.id,row)and TERMINAL[row.state]and(row.updatedAt or 0)>=now-90*86400 then rows[#rows+1]=row else Z.db.craftOrderHistory[id]=nil end end
    table.sort(rows,function(a,b)return(a.updatedAt or 0)>(b.updatedAt or 0)end);for i=1001,#rows do Z.db.craftOrderHistory[rows[i].key]=nil end
end
local function rememberTerminal(order)
    if not TERMINAL[order.state]then return end;local row={};for k,v in pairs(order)do if type(v)~="table"then row[k]=v end end;Z.db.craftOrderHistory[order.key]=row;pruneHistory(A.Now())
end
function O.Initialize()
    local orders,history,redirects={},{},{};local active=0
    local function normalize(oldKey,row)
        local id=type(row)=="table"and(row.id or oldKey)
        if not validOrder(id,row)then return end
        row.id=id;row.key=orderKey(row.direction,row.peer,id);row.updatedAt=row.updatedAt or row.createdAt;row.operationSeq=row.operationSeq or 0;row.revision=row.revision or 0;row.profession=L.ProfessionName(row.profession);row.lastOpSeq=L.Int(row.lastOpSeq,1,2147483646)and row.lastOpSeq or nil;row.lastOpResult=(row.lastOpResult=="OK"or row.lastOpResult=="STALE"or row.lastOpResult=="INVALID")and row.lastOpResult or nil
        -- Pre-fix saves did not record who expired a request. Recheck those
        -- outgoing archives once the owner is reachable instead of freezing
        -- potentially accepted work forever.
        row.localExpired=row.direction=="outgoing"and row.state=="EXPIRED"and row.expiryConfirmed~=true or nil
        if row.localExpired then row.nextQuery=A.Clock()+2 end
        redirects[oldKey]=row.key;return row
    end
    for key,row in pairs(type(Z.db.craftOrderHistory)=="table"and Z.db.craftOrderHistory or{})do row=normalize(key,row);if row and TERMINAL[row.state]then history[row.key]=row end end
    for key,row in pairs(type(Z.db.craftOrders)=="table"and Z.db.craftOrders or{})do
        row=normalize(key,row)
        if row then
            if TERMINAL[row.state]then history[row.key]=row
            elseif active<MAX_RETAINED_ACTIVE then orders[row.key]=row;history[row.key]=nil;active=active+1;row.nextQuery=A.Clock()+2;if row.direction=="incoming"then row.statusPending=true;row.statusAttempts=0;row.statusRetry=A.Clock()+2 end end
        end
    end
    Z.db.craftOrders=orders;Z.db.craftOrderHistory=history;O.orders=orders;pruneHistory(A.Now())
    local ops={}
    for oldKey,op in pairs(type(Z.db.craftOrderOps)=="table"and Z.db.craftOrderOps or{})do
        local key=redirects[oldKey]or oldKey;local order=orders[key]
        if order and type(op)=="table"then
            if order.direction=="outgoing"and(op.kind=="OC"or op.kind=="OO")and type(op.wire)=="string"and#op.wire<=4096 and op.target==contactTarget(order.peer)and L.Int(op.opSeq,1,2147483646)then
                ops[key]={kind=op.kind,wire=op.wire,target=op.target,opSeq=op.opSeq,attempts=0,next=A.Clock()+2}
            elseif order.direction=="incoming"and L.Int(op.receivedSeq,1,2147483646)and(op.result=="OK"or op.result=="STALE"or op.result=="INVALID")then ops[key]={receivedSeq=op.receivedSeq,result=op.result}end
        end
    end
    Z.db.craftOrderOps=ops;O.ops=ops;O.syncedSessions={};O.nextPrune=A.Clock()+60;O.nextHistoryQuery=A.Clock()+1
end
function O.Create(peer,recipe,quantity,materialsProvided,tip,note)
    if not Z.IsOnline(peer)then return nil,"Der Handwerker ist nicht erreichbar."end
    local p=Z.db.peers[peer];if not p or not p.cap30 then return nil,"Für Herstellungsaufträge ist ZenialCommunity 3.0 erforderlich."end
    if type(recipe)~="table"or not L.ValidRecipe(recipe)or not L.Int(quantity,1,100000)or not L.Int(tip or 0,0,2147483646)or not L.Text(note or"",192,true)then return nil,"Auftragsdaten sind ungültig."end
    local active,pair=0,0;for _,row in pairs(O.orders)do if not TERMINAL[row.state]then active=active+1;if row.peer==peer then pair=pair+1 end end end
    if active>=100 then return nil,"Maximal 100 laufende Herstellungsaufträge."end;if pair>=5 then return nil,"Maximal fünf offene Anfragen je Handwerker."end
    local now=A.Now();local id=L.NextID(Z.db,now);local order={id=id,key=id,nextQuery=A.Clock()+30,direction="outgoing",peer=peer,recipeID=recipe.id,itemID=recipe.itemID or 0,recipeName=recipe.name,profession=L.ProfessionName(recipe.profession or""),quantity=quantity,materialsProvided=materialsProvided==true,tip=tip or 0,note=note or"",createdAt=now,expires=now+86400,state="REQUESTED",revision=0,operationSeq=1,updatedAt=now,delivery="sending"}
    O.orders[order.key]=order;local values={id,order.recipeID,order.itemID,order.recipeName,order.profession,quantity,order.materialsProvided and 1 or 0,order.tip,order.note,now,order.expires,order.operationSeq};local sent,err=queueOperation(order,"OC",values,order.operationSeq);if not sent then order.delivery="queued";return id,err end;return id
end
local function validTransition(state,action,actor)
    if actor=="crafter"then
        if action=="ACCEPT"then return state=="REQUESTED","ACCEPTED"end
        if action=="DECLINE"then return state=="REQUESTED","DECLINED"end
        if action=="READY"then return state=="ACCEPTED","READY"end
        if action=="CANCEL"then return state=="ACCEPTED"or state=="READY","CANCELLED"end
    else
        if action=="CONFIRM"then return state=="READY","COMPLETED"end
        if action=="CANCEL"then return state=="REQUESTED"or state=="ACCEPTED"or state=="READY","CANCELLED"end
    end
    return false
end
function O.Transition(id,action)
    local order=O.orders[id]
    if not order then for _,row in pairs(O.orders)do if row.id==id then if order then return nil,"Auftrag ist mehrdeutig."end;order=row end end end;if not order then return nil,"Auftrag nicht gefunden."end
    local actor=order.direction=="incoming"and"crafter"or"requester";local allowed,nextState=validTransition(order.state,action,actor);if not allowed then return nil,"Dieser Statuswechsel ist nicht möglich."end
    if actor=="crafter"then
        if action=="ACCEPT"and not hasRecipe(order.recipeID,order.profession)then return nil,"Das Rezept ist nicht mehr im eigenen Katalog."end
        order.state=nextState;order.revision=order.revision+1;order.updatedAt=A.Now();order.statusAttempts=0;sendStatus(order,0,"OK");rememberTerminal(order)
    else
        order.operationSeq=(order.operationSeq or 0)+1;local sent,err=queueOperation(order,"OO",{order.id,order.operationSeq,order.revision,action},order.operationSeq);if not sent then return nil,err end;order.delivery="sending"
    end
    if Z.MarkDirty then Z.MarkDirty("order")end;return true
end
local function receiveCreate(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=12 then return false end;local key=Z.ResolvePeerKey(sender);if not key or not Z.db.contacts[key]then return false end
    local id=f[1];local existing=O.Get(id,key,"incoming");if existing then if existing.peer==key then sendStatus(existing,tonumber(f[12])or 0,"DUPLICATE");return true end;return false end
    local recipeID,itemID,quantity,materials,tip,created,expires,opSeq=tonumber(f[2]),tonumber(f[3]),tonumber(f[6]),tonumber(f[7]),tonumber(f[8]),tonumber(f[10]),tonumber(f[11]),tonumber(f[12])
    if not L.Text(id,32)or not id:match("^[%d%.]+$")or not L.Int(recipeID,1,10000000)or not L.Int(itemID,0,10000000)or not L.Text(f[4],96)or not L.Text(f[5],64,true)or not L.Int(quantity,1,100000)or not L.Int(materials,0,1)or not L.Int(tip,0,2147483646)or not L.Text(f[9],192,true)or not L.Int(created,1,4102444800)or not L.Int(expires,1,4102444800)or expires~=created+86400 or not L.Int(opSeq,1,2147483646)or created>A.Now()+300 then return false end
    local active,pair=0,0;for _,row in pairs(O.orders)do if not TERMINAL[row.state]then active=active+1;if row.peer==key then pair=pair+1 end end end;if active>=100 or pair>=5 then return false end
    local state=A.Now()>=expires and"EXPIRED"or"REQUESTED";local order={id=id,key=orderKey("incoming",key,id),direction="incoming",peer=key,recipeID=recipeID,itemID=itemID,recipeName=f[4],profession=L.ProfessionName(f[5]),quantity=quantity,materialsProvided=materials==1,tip=tip,note=f[9],createdAt=created,expires=expires,state=state,revision=1,operationSeq=opSeq,updatedAt=A.Now(),delivery="received"};O.orders[order.key]=order;sendStatus(order,opSeq,"OK");if Z.Notifications then Z.Notifications.Craft(order)end;if Z.MarkDirty then Z.MarkDirty("order")end;return true
end
local function receiveOperation(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=4 then return false end;local key=Z.ResolvePeerKey(sender);local order=key and O.Get(f[1],key,"incoming");if not order or order.direction~="incoming"or order.peer~=key then return false end
    local opSeq,expected=tonumber(f[2]),tonumber(f[3]);if not L.Int(opSeq,1,2147483646)or not L.Int(expected,0,2147483646)then return false end
    local old=Z.db.craftOrderOps[order.key]or(order.lastOpSeq and{receivedSeq=order.lastOpSeq,result=order.lastOpResult});if old and old.receivedSeq and old.receivedSeq>=opSeq then sendStatus(order,opSeq,old.result);return true end
    if expected~=order.revision then Z.db.craftOrderOps[order.key]={receivedSeq=opSeq,result="STALE"};order.lastOpSeq,order.lastOpResult=opSeq,"STALE";sendStatus(order,opSeq,"STALE");return true end
    local allowed,nextState=validTransition(order.state,f[4],"requester");if not allowed then Z.db.craftOrderOps[order.key]={receivedSeq=opSeq,result="INVALID"};order.lastOpSeq,order.lastOpResult=opSeq,"INVALID";sendStatus(order,opSeq,"INVALID");return true end
    order.state=nextState;order.revision=order.revision+1;order.operationSeq=opSeq;order.updatedAt=A.Now();Z.db.craftOrderOps[order.key]={receivedSeq=opSeq,result="OK"};order.lastOpSeq,order.lastOpResult=opSeq,"OK";sendStatus(order,opSeq,"OK");rememberTerminal(order);if Z.Notifications then Z.Notifications.Craft(order)end;if Z.MarkDirty then Z.MarkDirty("order")end;return true
end
local function receiveStatus(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=6 then return false end;local key=Z.ResolvePeerKey(sender);local order=key and O.Get(f[1],key,"outgoing");if not order or order.direction~="outgoing"or order.peer~=key then return false end
    local opSeq,revision,updated=tonumber(f[2]),tonumber(f[5]),tonumber(f[6]);if not L.Int(opSeq,0,2147483646)or not L.Int(revision,0,2147483646)or not L.Int(updated,1,4102444800)then return false end
    if not STATES[f[4]]or(f[3]~="OK"and f[3]~="DUPLICATE"and f[3]~="STALE"and f[3]~="INVALID")or updated>A.Now()+300 then return false end
    local previous=order.state;local knownState=order.localExpired and"REQUESTED"or order.state
    local equivalent=revision==order.revision and(f[4]==knownState or order.localExpired and f[4]=="EXPIRED")and updated==order.updatedAt
    -- Only the crafter owns revisions. Local request expiry is provisional;
    -- never ACK a revision that was discarded, or the owner stops retrying it.
    if not equivalent then
        if revision<=order.revision or(TERMINAL[order.state]and not order.localExpired)then return false end
        if not TERMINAL[f[4]]and not O.orders[order.key]and L.Count(O.orders)>=MAX_RETAINED_ACTIVE then return false end
        order.state=f[4];order.revision=revision;order.updatedAt=updated;order.localExpired=nil;order.localExpiredAt=nil
        if order.state=="REQUESTED"and A.Now()>=order.expires then order.state="EXPIRED";order.localExpired=true end
        if not TERMINAL[order.state]then O.orders[order.key]=order;Z.db.craftOrderHistory[order.key]=nil end
    end
    if f[4]=="EXPIRED"then order.localExpired=nil;order.localExpiredAt=nil;order.expiryConfirmed=true end
    if order.state~=previous and Z.Notifications then Z.Notifications.Craft(order)end
    local pending=O.ops[order.key];if pending and pending.opSeq==opSeq then O.ops[order.key]=nil end;order.delivery=(f[3]=="OK"or f[3]=="DUPLICATE")and"confirmed"or string.lower(f[3]);order.nextQuery=A.Clock()+(order.localExpired and 300 or 60);rememberTerminal(order)
    local target=contactTarget(order.peer);if target then Z.Network3.QueueDirect(target,"OA",Z.Network3.Pack({order.id,revision}),100,"ORDERACK:"..order.key)end;if Z.MarkDirty then Z.MarkDirty("order")end;return true
end
local function receiveQuery(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=1 then return false end;local key=Z.ResolvePeerKey(sender);local order=key and O.Get(f[1],key,"incoming")
    if not order or order.peer~=key or order.direction~="incoming"then return false end;sendStatus(order,order.operationSeq or 0,"OK");return true
end
function O.OnPeerOnline(key,session)
    if Z.db.blocked[key]then return end
    if O.syncedSessions[key]==session then return end;O.syncedSessions[key]=session
    local target=contactTarget(key);if not target then return end
    local sent=0
    for _,source in ipairs({O.orders,Z.db.craftOrderHistory})do for id,order in pairs(source)do
        if order.peer==key and order.direction=="outgoing"and(not TERMINAL[order.state]or order.localExpired)then
            order.nextQuery=A.Clock()
            if sent<5 then local queued=Z.Network3.QueueDirect(target,"OQ",Z.Network3.Pack({order.id}),90,"ORDERQUERY:"..id);if queued then sent=sent+1;order.nextQuery=A.Clock()+(order.localExpired and 300 or 60)else O.syncedSessions[key]=nil end end
        end
    end end
end
function O.Receive(sender,kind,wire)
    local key=Z.ResolvePeerKey(sender);if not key or Z.db.blocked[key]then return false end
    if kind=="OC"then return receiveCreate(sender,wire)elseif kind=="OO"then return receiveOperation(sender,wire)elseif kind=="OS"then return receiveStatus(sender,wire)elseif kind=="OQ"then return receiveQuery(sender,wire)
    elseif kind=="OA"then
        local f=Z.Network3.Unpack(wire);if not f or#f~=2 then return false end
        local order=O.Get(f[1],key,"incoming");local revision=tonumber(f[2])
        if order and L.Int(revision,0,2147483646)and revision==order.revision then order.statusPending=false;return true end
    end
    return false
end
function O.Block(key)
    for id,order in pairs(O.orders)do if order.peer==key then O.ops[id]=nil;order.statusPending=false;order.delivery="blocked"end end
    O.syncedSessions[key]=nil
end
function O.Tick()
    local clock,now=A.Clock(),A.Now()
    for id in pairs(O.ops)do if not O.orders[id]then O.ops[id]=nil end end
    for id,op in pairs(O.ops)do if op.wire and clock>=(op.next or 0)then
        local order=O.orders[id]
        if not order or TERMINAL[order.state]or Z.db.blocked[order.peer]or not contactTarget(order.peer)then O.ops[id]=nil
        elseif op.attempts>=3 then order.delivery="failed";O.ops[id]=nil
        elseif Z.IsOnline(order.peer)then
            local queued=Z.Network3.QueueDirect(op.target,op.kind,op.wire,95,"ORDER:"..id..":"..op.opSeq)
            if queued then op.attempts=op.attempts+1;op.next=clock+20 else order.delivery="queued";op.next=clock+2 end
        else order.delivery="offline";op.next=clock+20 end
    end end
    local queried=0
    for id,order in pairs(O.orders)do
        if order.state=="REQUESTED"and now>=order.expires then
            order.state="EXPIRED";O.ops[id]=nil
            if order.direction=="incoming"then order.updatedAt=now;order.revision=order.revision+1;order.statusAttempts=0;sendStatus(order,0,"OK")
            else order.localExpired=true;order.expiryConfirmed=nil;order.localExpiredAt=now;order.nextQuery=clock end
            rememberTerminal(order);if Z.Notifications then Z.Notifications.Craft(order)end;Z.MarkDirty("order")
        end
        if order.direction=="incoming"and order.statusPending and clock>=(order.statusRetry or 0)and Z.IsOnline(order.peer)then sendStatus(order,order.operationSeq or 0,"OK")end
        if order.direction=="outgoing"and not TERMINAL[order.state]and Z.IsOnline(order.peer)and not Z.db.blocked[order.peer]and clock>=(order.nextQuery or 0)and queried<4 then
            local target=contactTarget(order.peer);if target then Z.Network3.QueueDirect(target,"OQ",Z.Network3.Pack({order.id}),90,"ORDERQUERY:"..id);order.nextQuery=clock+60;queried=queried+1 end
        end
        if TERMINAL[order.state]and(not order.statusPending or now-order.updatedAt>=300)then rememberTerminal(order);O.orders[id]=nil;O.ops[id]=nil end
    end
    -- Reconcile archived requester timeouts too, including after a reload. The
    -- oldest due query wins so large archives cannot starve their later rows.
    if clock>=O.nextHistoryQuery then
        O.nextHistoryQuery=clock+1;local due
        for _,order in pairs(Z.db.craftOrderHistory)do
            if order.localExpired and clock>=(order.nextQuery or 0)and(not due or(order.nextQuery or 0)<(due.nextQuery or 0))and not O.orders[order.key]and not Z.db.blocked[order.peer]and Z.IsOnline(order.peer)and contactTarget(order.peer)then due=order end
        end
        if due then local queued=Z.Network3.QueueDirect(contactTarget(due.peer),"OQ",Z.Network3.Pack({due.id}),90,"ORDERQUERY:"..due.key);due.nextQuery=clock+(queued and 300 or 2)end
    end
    if clock>=O.nextPrune then O.nextPrune=clock+60;pruneHistory(now)end
end
function O.List(direction)local out={};local seen={};for _,source in ipairs({O.orders,Z.db.craftOrderHistory})do for id,order in pairs(source)do if not seen[id]and(not direction or order.direction==direction)then out[#out+1]=order;seen[id]=true end end end;table.sort(out,function(a,b)return(a.updatedAt or 0)>(b.updatedAt or 0)end);return out end
return O
