-- Additional read models. No query, acknowledgement, scan, application or game
-- action is started while collecting these views. Every field is allowlisted.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local P,T=Z.CompanionProtocol,Z.CompanionTelemetry
local function project(value,fields)
    local out={};if not A.PublicTable(value)then return out end
    for _,key in ipairs(fields)do local v=value[key]
        if A.Safe(v)and(type(v)=='boolean'or type(v)=='number'and v==v and math.abs(v)<1e15 or type(v)=='string'and#v<=2048)then out[key]=v end
    end;return out
end
-- A public maximum does not make an opaque current value serializable.
-- ClassFrames can pass such values directly to native FontStrings; JSON cannot.
local function readNumber(fn,...)
    if type(fn)~='function'then return nil,'api-unavailable'end
    local ok,v=pcall(fn,...);if not ok then return nil,'api-error'end
    if not A.Safe(v)then return nil,'protected'end
    if type(v)=='number'and v==v and math.abs(v)<1e15 then return v end
    return nil,'unknown'
end
local function collection(maxBytes,maxRows)
    local out=P.Array();local bytes=0;local truncated=false
    local function add(row)
        local ok,json=pcall(P.Json,row)
        if not ok or#out>=(maxRows or 100)or bytes+#json>(maxBytes or 40000)then truncated=true;return false end
        out[#out+1]=row;bytes=bytes+#json+1;return true
    end
    return out,add,function()return truncated end
end
local function target(key)return Z.db.contacts[key]and Z.db.contacts[key].target or key==Z.me.key and Z.me.target or key end
function T.notifications()
    local rows,add,limited=collection(40000,50)
    for _,n in ipairs(Z.Notifications.Recent())do
        local row=project(n,{'logID','title','text','at','unread'})
        row.destination=project(n.entry,{'area','view','id','peer','code','subject'});add(row)
    end
    return{entries=rows,truncated=limited(),readOnly=true}
end
function T.requests()
    local rows,add,limited=collection(42000,150)
    for _,spec in ipairs({{'group','incoming',Z.db.interests},{'quest','incoming',Z.db.questInterests},{'group','outgoing',Z.db.sentApplications},{'quest','outgoing',Z.db.sentQuestApplications}})do
        local ids={};for id in pairs(spec[3]or{})do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do for peer,r in pairs(spec[3][id])do if not Z.db.blocked[peer]then
            local row=project(r,{'state','at','role','note'});row.kind=spec[1];row.direction=spec[2];row.id=id;row.peer=peer;row.target=target(peer);add(row)
        end end end
    end
    for _,order in ipairs(Z.CraftOrders.List())do if not Z.db.blocked[order.peer]then
        local row=project(order,{'key','id','peer','direction','recipeID','itemID','recipeName','profession','quantity','materialsProvided','tip','note','createdAt','updatedAt','expires','state','delivery'})
        row.kind='craft';row.target=target(order.peer);add(row)
    end end
    for _,e in ipairs(Z.ScheduledGroups.List(true))do
        if e.own or e.ownerKey==Z.me.key then for peer,p in pairs(e.participants or{})do if not Z.db.blocked[peer]then
            local row=project(p,{'state','role','note','at','updatedAt'});row.kind='event';row.direction='incoming';row.peer=peer;row.target=target(peer);row.id=e.id;row.title=e.activity;add(row)
        end end
        else local p=Z.ScheduledGroups.Follow(e.ownerKey,e.id);if p then
            local row=project(p,{'state','role','note','at','updatedAt'});row.kind='event';row.direction='outgoing';row.peer=e.ownerKey;row.target=target(e.ownerKey);row.id=e.id;row.title=e.activity;add(row)
        end end
    end
    table.sort(rows,function(a,b)return(a.updatedAt or a.at or a.createdAt or 0)>(b.updatedAt or b.at or b.createdAt or 0)end)
    return{entries=rows,truncated=limited(),readOnly=true}
end
function T.activities()
    local rows,add,limited=collection(20000,60)
    for _,r in ipairs(Z.ActivityBoard.List())do
        local row=project(r,{'key','kind','owner','id','title','startsAt','endsAt','ownerName','own','category','saved'})
        row.details=project(r.data,{'status','mode','activity','title','min','max','have','want','start','expires','note','capacity','location','mapID','x','y'})
        row.application=project(r.application,{'state','role','at'})
        if r.kind=='EVENT'and r.data then row.roleSlots=project(r.data.roleSlots,{'TANK','HEALER','DAMAGER'});row.used=project(Z.ScheduledGroups.Counts(r.data),{'TANK','HEALER','DAMAGER'})end
        add(row)
    end
    return{entries=rows,truncated=limited(),readOnly=true}
end
function T.groups()
    local function n(v)return A.Safe(v)and type(v)=='number'and v==v and v>=0 and v<=1e12 and v or nil end
    local function vital(fn,...)local value,reason=readNumber(fn,...);if value~=nil and not n(value)then return nil,'unknown'end;return value,reason end
    local function flag(fn,...)local value=A.Call(fn,...);if A.Safe(value)and type(value)=='boolean'then return value end end
    local roster=P.Array();local raid=A.Call(IsInRaid)==true;local sampleTotal=n(A.Call(GetNumGroupMembers));local rawTotal=sampleTotal or 0
    local units={};if raid then for i=1,math.min(40,rawTotal)do units[#units+1]='raid'..i end else units[1]='player';for i=1,math.min(4,math.max(0,rawTotal-1))do units[#units+1]='party'..i end end
    local seen={};for _,unit in ipairs(units)do local key,name,realm=A.UnitIdentity(unit);if key then key=L.ScopeKey(name,realm,Z.me.faction)or key end
        if key and not seen[key]then
            seen[key]=true;local row={key=key,target=name,role=A.Call(UnitGroupRolesAssigned,unit),level=n(A.Call(UnitLevel,unit)),online=flag(UnitIsConnected,unit),leader=flag(UnitIsGroupLeader,unit),assistant=flag(UnitIsGroupAssistant,unit),self=unit=='player'or flag(UnitIsUnit,unit,'player')==true,dead=flag(UnitIsDeadOrGhost,unit),ghost=flag(UnitIsGhost,unit)}
            if not L.Text(row.role,16,true)then row.role=nil end
            local _,classFile=A.Call(UnitClass,unit);if L.Text(classFile,16)and L.CLASS_DE[classFile]then row.classFile=classFile end
            row.unavailable={}
            row.health,row.unavailable.health=vital(UnitHealth,unit);row.maxHealth,row.unavailable.maxHealth=vital(UnitHealthMax,unit);row.healthAvailable=row.health~=nil and row.maxHealth~=nil and row.maxHealth>0
            local powerType,powerToken=A.Call(UnitPowerType,unit);row.powerType=n(powerType);if L.Text(powerToken,24)then row.powerToken=powerToken end
            row.power,row.unavailable.power=vital(UnitPower,unit);row.maxPower,row.unavailable.maxPower=vital(UnitPowerMax,unit);row.powerAvailable=row.power~=nil and row.maxPower~=nil and row.maxPower>0
            if raid then local index=tonumber(unit:match('%d+'));local _,_,subgroup=A.Call(GetRaidRosterInfo,index);row.subgroup=L.Int(subgroup,1,8)and subgroup or nil else row.subgroup=1 end
            local mapID=A.Call(C_Map and C_Map.GetBestMapForUnit,unit);local info=L.Int(mapID,1,1000000)and A.Call(C_Map and C_Map.GetMapInfo,mapID)
            if A.PublicTable(info)and L.Text(info.name,64,true)then row.location={mapID=mapID,area=info.name}end
            if row.self then row.location=A.PlayerLocation()end
            roster[#roster+1]=row
        end
    end
    local name,kind,difficultyID,difficulty,maxPlayers=A.Call(GetInstanceInfo)
    local instance=project({name=name,kind=kind,difficultyID=n(difficultyID),difficulty=difficulty,maxPlayers=n(maxPlayers)},{'name','kind','difficultyID','difficulty','maxPlayers'})
    return{available=sampleTotal~=nil,roster=roster,total=math.max(1,rawTotal),inGroup=rawTotal>0,isRaid=raid,capacity=raid and 40 or 5,instance=instance,readOnly=true}
end
function T.professions()
    local professions=P.Array();for _,r in ipairs(Z.db.professions or{})do professions[#professions+1]=project(r,{'id','name','rank','max'})end
    local recipes,add,limited=collection(38000,250)
    for _,r in ipairs(Z.db.recipes or{})do add(project(r,{'id','itemID','name','itemName','profession','materials'}))end
    return{professions=professions,recipes=recipes,complete=Z.db.recipeComplete==true and not limited(),truncated=limited(),source='existing-profession-scan'}
end
function T.trade()
    local rows,add,limited=collection(40000,150)
    local function offers(owner,market)
        for _,offer in ipairs(market or{})do if L.ValidOffer(offer,A.Now())then
            local row=project(offer,{'id','kind','itemID','name','quantity','price','note','expires'});row.owner=owner;row.target=target(owner);row.own=owner==Z.me.key;add(row)
        end end
    end
    offers(Z.me.key,Z.db.market)
    if Z.db.consent then for key,peer in pairs(Z.db.peers)do
        local data=peer.data
        if key~=Z.me.key and Z.db.contacts[key]and not Z.db.blocked[key]and Z.IsOnline(key)and data and data.faction==Z.me.faction and(not peer.cap4 or data.generation==(peer.verifiedSession or peer.session))then offers(key,data.market)end
    end end
    return{entries=rows,truncated=limited(),source='existing-market-cache'}
end
function T.player()
    local unavailable={}
    local function n(key,fn,...)
        local value,reason=readNumber(fn,...);unavailable[key]=reason;return value
    end
    return{health=n('health',UnitHealth,'player'),healthMax=n('healthMax',UnitHealthMax,'player'),power=n('power',UnitPower,'player'),powerMax=n('powerMax',UnitPowerMax,'player'),powerType=n('powerType',UnitPowerType,'player'),
        xp=n('xp',UnitXP,'player'),xpMax=n('xpMax',UnitXPMax,'player'),restedXP=n('restedXP',GetXPExhaustion),money=n('money',GetMoney),speed=n('speed',GetUnitSpeed,'player'),
        runSpeed=n('runSpeed',function()local _,run=A.Call(GetUnitSpeed,'player');return run end),source='accessible-player-api',unavailable=unavailable}
end
function T.chat()
    local C=Z.Companion;local rows=P.Array();for _,r in ipairs(C.chatRows or{})do rows[#rows+1]=r end
    return{entries=rows,dropped=C.chatDropped or 0,lastCounter=C.chatCounter or 0,clubChatBlocked=C.clubChatBlocked==true,scope='read-only-chat-events',historyBeforeEnable=false}
end
