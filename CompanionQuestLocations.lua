-- Read-only quest locations on every known map. Never change the selected
-- game quest, open the world map, or invent an objective coordinate.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local Q={};Z.CompanionQuestLocations=Q
local function num(v)return A.Safe(v)and type(v)=='number'and v==v and v or nil end
local function point(map,x,y)
    map,x,y=num(map),num(x),num(y)
    if map and map>0 and map<=1000000 and x and y and x>=0 and y>=0 and x<=1 and y<=1 then return{mapID=map,x=x,y=y}end
end
local function maps()
    if Q.ids then return end
    Q.ids,Q.names,Q.cursor={},{},1;local seen={}
    local function add(id,name)
        id=num(id);if not id or id<=0 or seen[id]or#Q.ids>=200 then return end
        seen[id]=true;Q.ids[#Q.ids+1]=id
        if A.Safe(name)and type(name)=='string'then Q.names[name]=id end
    end
    add(A.CurrentMapID())
    for _,kind in ipairs({3,5,4})do
        local children=A.Call(C_Map and C_Map.GetMapChildrenInfo,947,kind,true)
        if A.PublicTable(children)then for _,info in ipairs(children)do if A.PublicTable(info)then add(info.mapID,info.name)end end end
    end
    -- Starting subzones have quest headers, but no separate UI map. Resolve
    -- their localized area names to the actual zone map, not a fake POI.
    for area,map in pairs({[9]=1429,[59]=1426,[188]=1438,[363]=1411,[221]=1412,[154]=1420})do
        local name=A.Call(C_Map and C_Map.GetAreaInfo,area);if A.Safe(name)and type(name)=='string'then Q.names[name]=map end
    end
end
function Q.AreaMap(category)
    maps();return A.Safe(category)and type(category)=='string'and Q.names[category]or nil
end
function Q.Read(quests)
    maps();local current,points,areas,queried=A.CurrentMapID(),{},{},{}
    local function scan(id)
        if not id or id<=0 or queried[id]then return end;queried[id]=true
        local pois=A.Call(C_QuestLog and C_QuestLog.GetQuestsOnMap,id)
        if A.PublicTable(pois)then for _,poi in ipairs(pois)do if A.PublicTable(poi)then
            local quest=num(poi.questID);local p=point(id,poi.x,poi.y)
            if quest and p then points[quest]=p end
        end end end
    end
    scan(current)
    for _,quest in ipairs(quests)do
        areas[quest.id]=Q.names[quest.category]
        scan(areas[quest.id])
        local map,x,y=A.Call(C_QuestLog and C_QuestLog.GetNextWaypoint,quest.id)
        local p=point(map,x,y);if p then points[quest.id]=p end
    end
    -- Bounded background discovery covers objectives outside the current zone.
    -- Known header maps and waypoints are handled immediately above.
    for _=1,8 do
        local id=Q.ids[Q.cursor];if not id then break end
        scan(id);Q.cursor=Q.cursor%#Q.ids+1
    end
    return points,areas
end
