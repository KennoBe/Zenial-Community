-- Read-only world geometry, following OpenMap's normalized Azeroth canvas.
-- Only references/coordinates cross the transport; textures remain in CASC.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P,T=Z.CompanionProtocol,Z.CompanionTelemetry
local WORLD=947
local function n(v)return A.Safe(v)and type(v)=='number'and v==v and math.abs(v)<1e9 and v or nil end
function T.mapcatalog()
    local C=Z.Companion
    if C.jobs.mapcatalog or C.latest.mapcatalog then return nil end
    if not C.mapCatalogIDs then
        local ids,seen={},{};C.mapCatalogContinents={}
        local function add(id)id=n(id);if id and id>0 and not seen[id]and#ids<256 then seen[id]=true;ids[#ids+1]=id end end
        add(WORLD);add(A.CurrentMapID())
        for _,kind in ipairs({2,3})do -- Enum.UIMapType.Continent / Zone
            local children=A.Call(C_Map and C_Map.GetMapChildrenInfo,WORLD,kind,true)
            if A.PublicTable(children)then for _,info in ipairs(children)do if A.PublicTable(info)then add(info.mapID);if kind==2 then C.mapCatalogContinents[#C.mapCatalogContinents+1]=info.mapID end end end end
        end
        if Z.DungeonData then for _,id in ipairs(Z.DungeonData.MapIDs())do add(id)end end
        C.mapCatalogIDs=ids;C.mapCatalogCursor=1;C.mapCatalogDue=0
    end
    local now=A.Clock();local dungeon=Z.DungeonData and Z.DungeonData.Current();local current=dungeon and Z.DungeonData.MapID(dungeon.id)or A.CurrentMapID()
    if C.mapCatalogEssentialMap~=current then C.mapCatalogEssential=nil;C.mapCatalogEssentialDue=0;C.mapCatalogEssentialMap=current end
    if not C.mapCatalogEssential and now>=(C.mapCatalogEssentialDue or 0)then
        C.mapCatalogEssential={WORLD};if current>0 and current~=WORLD then C.mapCatalogEssential[#C.mapCatalogEssential+1]=current end
        for _,id in ipairs(C.mapCatalogContinents or{})do if id~=current and id~=WORLD then C.mapCatalogEssential[#C.mapCatalogEssential+1]=id end end
    end
    local id;local essential=false
    if C.mapCatalogEssential and#C.mapCatalogEssential>0 then
        id=table.remove(C.mapCatalogEssential,1);essential=true
        if#C.mapCatalogEssential==0 then C.mapCatalogEssential=nil;C.mapCatalogEssentialDue=now+15 end
    else
        if now<(C.mapCatalogDue or 0)then return nil end
        local index=C.mapCatalogCursor or 1;id=C.mapCatalogIDs[index]
        if not id then return nil end
        C.mapCatalogCursor=index%#C.mapCatalogIDs+1
        if C.mapCatalogCursor==1 then C.mapCatalogDue=now+90 end
    end
    local art=T.MapArt(id);if not art.available then return nil end
    local info=A.Call(C_Map and C_Map.GetMapInfo,id)
    if A.PublicTable(info)then
        if A.Safe(info.name)and type(info.name)=='string'and#info.name<=256 then art.name=info.name end
        art.parentMapID=n(info.parentMapID);art.mapType=n(info.mapType)
    end
    local l,r,t,b
    if id==WORLD then l,r,t,b=0,1,0,1 else l,r,t,b=A.Call(C_Map and C_Map.GetMapRectOnMap,id,WORLD)end
    l,r,t,b=n(l),n(r),n(t),n(b)
    if l and r and t and b and r>l and b>t then art.rect={left=l,right=r,top=t,bottom=b};art.worldID=WORLD end
    return{entries=P.Array({art}),worldID=WORLD,bootstrap=essential}
end
