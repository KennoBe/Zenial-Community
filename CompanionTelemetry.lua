-- Explicit read models: never serialize SavedVariables, private peer profiles or UI controls wholesale.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local P=Z.CompanionProtocol;local T={};Z.CompanionTelemetry=T
local function text(v,max)return A.Safe(v)and type(v)=='string'and#v<=(max or 256)and v or nil end
local function number(v) return A.Safe(v)and type(v)=='number'and v==v and math.abs(v)<1e12 and v or nil end
local function field(t,k)return A.PublicTable(t)and A.Safe(t[k])and t[k]or nil end
local function item(id)
    local api=C_Item or{}
    local fn=api.GetItemInfo or GetItemInfo
    local ok,name,link,quality,level,minLevel,kind,subtype,maxStack,equip,icon,sellPrice,classID,subclassID,bindType
    if type(fn)=='function'then ok,name,link,quality,level,minLevel,kind,subtype,maxStack,equip,icon,sellPrice,classID,subclassID,bindType=pcall(fn,id)end
    if not ok then name,link,quality,level,minLevel,kind,subtype,maxStack,equip,icon,sellPrice,classID,subclassID,bindType=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil end
    local _,instantKind,instantSubtype,instantEquip,instantIcon=A.Call(api.GetItemInfoInstant or GetItemInfoInstant,id)
    if not text(name)and type(api.RequestLoadItemDataByID)=='function'then
        Z.Companion.itemRequests=Z.Companion.itemRequests or{}
        if not Z.Companion.itemRequests[id]and(Z.Companion.itemRequestCount or 0)<500 then Z.Companion.itemRequests[id]=true;Z.Companion.itemRequestCount=(Z.Companion.itemRequestCount or 0)+1;A.Call(api.RequestLoadItemDataByID,id)end
    end
    return{itemID=id,name=text(name),link=text(link,1024),quality=number(quality),itemLevel=number(level),requiredLevel=number(minLevel),
        kind=text(kind)or text(instantKind),subtype=text(subtype)or text(instantSubtype),equipLocation=text(equip)or text(instantEquip),
        icon=number(icon)or number(instantIcon),maxStack=number(maxStack),sellPrice=number(sellPrice),classID=number(classID),subclassID=number(subclassID),bindType=number(bindType),metadataAvailable=text(name)~=nil}
end
function T.identity()
    local me=A.Identity();if not me then return{available=false}end
    local version,build,_,interface=A.Call(GetBuildInfo)
    return{available=true,key=me.key,target=me.target,realm=me.realm,faction=me.faction,classFile=me.classFile,class=me.class,level=me.level,guid=me.guid,
        clientFlavor='forever',build=text(build),interface=number(interface),clientVersion=text(version),addonVersion=Z.ADDON_VERSION,locale=text(A.Call(GetLocale))}
end
local function point(unit,mapID)
    local p=A.Call(C_Map and C_Map.GetPlayerMapPosition,mapID,unit);if not A.PublicTable(p)then return nil end
    local x,y;if type(p.GetXY)=='function'then x,y=A.Call(p.GetXY,p)else x,y=field(p,'x'),field(p,'y')end
    x,y=number(x),number(y);if not x or not y or x<0 or y<0 or x>1 or y>1 then return nil end
    return{x=x,y=y}
end
function T.position()
    local location=A.PlayerLocation();local mapID=location.mapID
    local instance=location.instanceID and{id=location.instanceID,name=location.instanceName,entrance=location.entrance}
    if instance then mapID=Z.DungeonData.MapID(instance.id)or 0 end
    local own=mapID>0 and A.OpenWorld()and point('player',mapID)or nil
    local out={available=own~=nil,mapID=mapID,area=location.area,subzone=location.subzone,group=P.Array(),instance=instance}
    if own then out.x,out.y=own.x,own.y end
    local facing=number(A.Call(GetPlayerFacing));out.facingAvailable=(own and facing and facing>=0 and facing<=2*math.pi)==true
    if out.facingAvailable then out.facing=facing end
    local total=number(A.Call(GetNumGroupMembers))or 0;local raid=A.Call(IsInRaid)==true
    for i=1,math.min(40,raid and total or math.max(0,total-1))do
        local unit=(raid and'raid'or'party')..i;local key,target,realm=A.UnitIdentity(unit);if key then key=L.ScopeKey(target,realm,Z.me.faction)or key end;local pos=own and point(unit,mapID)
        if key and pos then out.group[#out.group+1]={key=key,target=target,mapID=mapID,x=pos.x,y=pos.y,at=A.Now()}end
    end
    return out
end
function T.MapArt(mapID)
    -- References only, never texture bytes. One small static topic instead of
    -- repeating the tile list with every movement update. No game UI is opened.
    local dungeon=Z.DungeonData and Z.DungeonData.Art(mapID);if dungeon then return dungeon end
    local layers=A.Call(C_Map and C_Map.GetMapArtLayers,mapID)
    local layer=A.PublicTable(layers)and layers[1];local textures=A.Call(C_Map and C_Map.GetMapArtLayerTextures,mapID,1)
    local out={mapID=mapID,available=false}
    if not A.PublicTable(layer)or not A.PublicTable(textures)then return out end
    local w,h,tw,th=number(field(layer,'layerWidth')),number(field(layer,'layerHeight')),number(field(layer,'tileWidth')),number(field(layer,'tileHeight'))
    if not w or not h or not tw or not th or w<1 or h<1 or tw<1 or th<1 or w>8192 or h>8192 then return out end
    local count=math.ceil(w/tw)*math.ceil(h/th);if count>256 then return out end
    local ids=P.Array();for i=1,count do local id=number(textures[i]);if not id or id<1 or id~=math.floor(id)then return out end;ids[i]=id end
    return{available=true,mapID=mapID,artID=number(A.Call(C_Map and C_Map.GetMapArtID,mapID)),width=w,height=h,tileWidth=tw,tileHeight=th,files=ids}
end
function T.map()local d=Z.DungeonData and Z.DungeonData.Current();return T.MapArt(d and Z.DungeonData.MapID(d.id)or A.CurrentMapID())end
function T.inventory()
    local bag=A.ReadBagInventory();local rows=P.Array();local ids={}
    for id in pairs(bag.counts)do ids[id]=true end;for id in pairs(bag.unknown)do ids[id]=true end
    local ordered={};for id in pairs(ids)do ordered[#ordered+1]=id end;table.sort(ordered)
    for _,id in ipairs(ordered)do
        local row=item(id);row.quantity=not bag.unknown[id]and bag.counts[id]or nil;row.available=bag.known and not bag.unknown[id]or false;row.location='bags';rows[#rows+1]=row
        local C=Z.Companion;C.itemSeen=C.itemSeen or{};local previous=C.itemSeen[id]
        if row.available then
            if not previous then previous={firstSeenAt=A.Now(),quantity=row.quantity};C.itemSeen[id]=previous
            elseif row.quantity>previous.quantity then previous.lastAddedAt=A.Now()end
            previous.quantity=row.quantity;row.firstSeenAt=previous.firstSeenAt;row.lastAddedAt=previous.lastAddedAt
        end
    end
    if bag.known then for id,previous in pairs(Z.Companion.itemSeen or{})do if not ids[id]then previous.quantity=0 end end end
    return{available=bag.known,observedAt=bag.at,items=rows,slots=P.Array(bag.slots),bags=P.Array(bag.bags),scope='active-character-bags'}
end
function T.quests()
    local Q=Z.QuestHelper;local rows=P.Array();local mapID=A.CurrentMapID();local objectivesAvailable=true
    local C=Z.Companion;C.questPoints=C.questPoints or{};local active={}
    local byID,areaMaps=Z.CompanionQuestLocations.Read(Q.quests or{})
    for _,quest in ipairs(Q.quests or{})do
        active[quest.id]=true
        if byID[quest.id]then C.questPoints[quest.id]=byID[quest.id]end
        local objectives=P.Array();local raw=A.Call(C_QuestLog and C_QuestLog.GetQuestObjectives,quest.id)
        if not A.PublicTable(raw)then objectivesAvailable=false end
        if A.PublicTable(raw)then for _,o in ipairs(raw)do
            if not A.PublicTable(o)or not A.Safe(o.numFulfilled,o.numRequired,o.finished)then objectivesAvailable=false end
            objectives[#objectives+1]={text=text(field(o,'text')),fulfilled=number(field(o,'numFulfilled')),required=number(field(o,'numRequired')),finished=field(o,'finished')==true}
        end end
        local shared=P.Array()
        for key in pairs(Z.db.contacts or{})do local record=Q.Record(key);if record and record.ids[quest.id]then shared[#shared+1]=key end end
        rows[#rows+1]={id=quest.id,title=quest.title,level=quest.level,category=quest.category,objectives=objectives,objectivesAvailable=A.PublicTable(raw),point=byID[quest.id]or C.questPoints[quest.id],areaMapID=areaMaps[quest.id],pointSource=byID[quest.id]and'native'or C.questPoints[quest.id]and'last-known',sharedWith=shared}
    end
    for id in pairs(C.questPoints)do if not active[id]then C.questPoints[id]=nil end end
    return{available=Q.sampleAt~=nil,observedAt=Q.sampleAt or 0,listObservedAt=Q.sampleAt or 0,objectivesAvailable=objectivesAvailable,objectivesObservedAt=objectivesAvailable and A.Now()or nil,refreshReason=Q.lastError,refreshing=Q.scanState~='ready',scanState=Q.scanState,quests=rows}
end
function T.character()
    local equipment=P.Array();local stats=P.Array();local armor=number(select(2,A.Call(UnitArmor,'player')))
    for slot=1,19 do
        local id=number(A.Call(GetInventoryItemID,'player',slot));local row={slot=slot,available=type(GetInventoryItemID)=='function'}
        if id and id>0 then row=item(id);row.slot=slot;row.available=true;row.link=text(A.Call(GetInventoryItemLink,'player',slot),1024)or row.link;row.durability,row.maxDurability=A.Call(GetInventoryItemDurability,slot)end
        equipment[#equipment+1]=row
    end
    for i,name in ipairs({'strength','agility','stamina','intellect','spirit'})do
        local base,effective=A.Call(UnitStat,'player',i);stats[#stats+1]={name=name,base=number(base),value=number(effective)}
    end
    local low,high,offLow,offHigh=A.Call(UnitDamage,'player');local base,positive,negative=A.Call(UnitAttackPower,'player');local speed,offSpeed=A.Call(UnitAttackSpeed,'player')
    return{available=true,equipment=equipment,stats=stats,armor=armor,money=number(A.Call(GetMoney)),weapons={minDamage=number(low),maxDamage=number(high),offMinDamage=number(offLow),offMaxDamage=number(offHigh),
        attackPower=number(base)and number(positive)and number(negative)and base+positive+negative or nil,speed=number(speed),offSpeed=number(offSpeed),crit=number(A.Call(GetCritChance))}}
end
function T.community()
    local rows=P.Array();local now=A.Now();local count,bytes=0,0;local truncated=false
    local offers=P.Array();local offerBytes=0;local offersTruncated=false
    local keys={};for key in pairs(Z.db.contacts or{})do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys)do local c=Z.db.contacts[key]
        if key~=Z.me.key and not Z.db.blocked[key]then
            local peer=Z.db.peers[key];local presence=peer and peer.presence;local pos=Z.CommunityMap.positions and Z.CommunityMap.positions[key]
            local profile=peer and peer.data;local professions=P.Array()
            for _,p in ipairs(profile and profile.professions or{})do if#professions<6 then professions[#professions+1]={id=number(p.id),name=text(p.name,64),rank=number(p.rank),max=number(p.max)}end end
            local record=Z.QuestHelper.Record(key);local quests=P.Array();if record then for id in pairs(record.ids)do quests[#quests+1]=id end;table.sort(quests)end
            local position;if pos and peer and presence and pos.session==peer.session and pos.hasPos~=false and pos.mapID>0 and now-pos.at<300 and pos.at<=now+120 and Z.IsOnline(key)then
                position={mapID=pos.mapID,x=pos.x/10000,y=pos.y/10000,at=pos.at}
            end
            local row={key=key,target=c.target,classFile=presence and presence.classFile or c.classFile or profile and text(profile.classFile,16),level=presence and presence.level or c.level or profile and number(profile.level),
                online=Z.IsOnline(key)==true,lastSeen=peer and peer.lastContact or c.lastSeen,availability=presence and presence.availability,position=position,questIDs=quests,questObservedAt=record and record.at,
                guild=profile and text(profile.guild,64),sameGuild=Z.Social.IsGuildMember(key)or nil,roles=profile and text(profile.roles,64),publicNote=profile and text(profile.note,192),professions=professions,profileObservedAt=peer and peer.lastContact}
            row.main=type(Z.ConfirmedMain)=='function'and text(Z.ConfirmedMain(key),128)or nil
            row.displayName=profile and text(profile.community,128)
            row.lastSeen=peer and math.max(number(peer.memberSeenAt)or 0,number(peer.lastContact)or 0,number(peer.reportedAt)or 0,not peer.cap4 and(number(peer.received)or 0)or 0)or number(c.lastSeen)
            local mapID=presence and number(presence.mapID)or peer and peer.location and number(peer.location.mapID)
            local info=mapID and A.Call(C_Map and C_Map.GetMapInfo,mapID)
            local legacy=peer and peer.location and peer.location.mapID==mapID and peer.location
            row.location={mapID=mapID,area=text(field(info,'name'))or legacy and text(legacy.area),subzone=not presence and legacy and text(legacy.subzone)or'',at=presence and number(presence.at)or legacy and number(legacy.at)}
            if presence and presence.instanceID and Z.DungeonData then row.position=nil;row.location={instanceID=presence.instanceID,area=Z.DungeonData.Name(presence.instanceID),entrance=Z.DungeonData.Entrance(presence.instanceID),at=presence.at}end
            row.layerID=Z.CommunityLayer and Z.CommunityLayer.Member(key,mapID)or nil
            local size=#P.Json(row);if bytes+size>48000 or count>=1000 then truncated=true;break end
            rows[#rows+1]=row;count=count+1;bytes=bytes+size+1
            local market=peer and peer.data and peer.data.market or{}
            for i=1,math.min(3,#market)do local offer=market[i]
                local match=Z.MaterialPlanner.GetOffer(key,offer.id,offer.itemID)
                if match then
                    local out={key=key,id=offer.id,itemID=offer.itemID,name=offer.name,target=match.target,quantity=offer.quantity,price=offer.price,unitPrice=match.unitPrice,expires=offer.expires,observedAt=peer.lastContact}
                    local n=#P.Json(out)
                    if#offers<50 and offerBytes+n<12000 then offers[#offers+1]=out;offerBytes=offerBytes+n+1 else offersTruncated=true end
                end
            end
        end
    end
    table.sort(rows,function(a,b)return a.key<b.key end)
    return{members=rows,offers=offers,positionTTL=300,source='existing-community-cache',truncated=truncated,offersTruncated=offersTruncated}
end
function T.materials()
    local plans=P.Array();local M=Z.MaterialPlanner
    for _,plan in ipairs(M.List())do
        local progress=M.Progress(plan.id);local rows=P.Array()
        for _,r in ipairs(progress and progress.rows or{})do
            local row=item(r.itemID);for _,key in ipairs({'needed','available','allocated','missing','reservedElsewhere'})do row[key]=r[key]end;rows[#rows+1]=row
        end
        plans[#plans+1]={id=plan.id,title=plan.recipe.itemName~=''and plan.recipe.itemName or plan.recipe.name,crafts=plan.crafts,items=rows,updatedAt=plan.updatedAt}
    end
    return{plans=plans}
end
function T.activities()
    local rows=P.Array()
    for _,r in ipairs(Z.ActivityBoard.List())do rows[#rows+1]={key=r.key,kind=r.kind,title=r.title,ownerName=r.ownerName,startsAt=r.startsAt,endsAt=r.endsAt,own=r.own}end
    return{activities=rows}
end
function T.private()
    -- This topic requires its own explicit opt-in; no peer private profile is copied.
    local notes=P.Array();local social=Z.Social and Z.Social.store
    local keys={};for key in pairs(social and social.notes or{})do keys[key]=true end;for key in pairs(social and social.favorites or{})do keys[key]=true end
    for key in pairs(keys)do notes[#notes+1]={key=key,note=text(social.notes[key],500),favorite=social.favorites[key]==true}end
    local wishes=P.Array();for _,w in ipairs(Z.SessionPlans.store and Z.SessionPlans.store.wishes or{})do wishes[#wishes+1]={kind=w.kind,label=w.label,targetID=w.targetID,activity=w.activity}end
    return{notes=notes,wishes=wishes}
end
