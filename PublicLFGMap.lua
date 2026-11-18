-- Public group search: which activities of the Blizzard group search belong to an activity of the ZENIAL
-- catalogue, and back. The catalogue ids of GroupFinder.lua stay what they are; this is a separate assignment
-- by id, never by name. The data comes from PublicLFGMapData.lua (generated from the game's data table).
--
-- The client offers each character only a part of the activities (no raids below their level, one level
-- bracket per battleground). Where the client says what it offers, the assignment is cut down to that.
--
-- Extra activities: dungeons, raids and battlegrounds of the game data the catalogue of GroupFinder.lua does
-- not have. The catalogue takes one in as soon as the client offers it (GroupFinderCatalog, C.SyncExtras).
local Z, L, A = ZenialCommunity, ZenialCommunity.Logic, ZenialCommunity.Adapter
local D = Z.PublicLFGMapData
local M = { build = D.build, none = D.none }
Z.PublicLFGMap = M

local owner, kindOf, offered = {}, {}, {}
for kind, category in pairs(D.categories) do
    kindOf[category] = kind
end
for activity, ids in pairs(D.catalog) do
    for _, id in ipairs(ids) do
        owner[id] = activity
    end
end

-- Kind of the finder (DUNGEON, RAID, PVP, QUEST, CUSTOM) -> category id of the public group search.
function M.Category(kind)
    return D.categories[kind]
end

function M.KindOf(category)
    return kindOf[category]
end

-- Activity id of the public group search -> kind of the finder, nil for an id the data does not know.
function M.Kind(id)
    local row = D.activities[id]
    return row and kindOf[row[1]] or nil
end

-- Activity id of the public group search -> catalogue id, nil when the catalogue has no such activity.
function M.ActivityOf(id)
    return owner[id]
end

-- Group size from the game data; nil when the activity has no fixed size or is unknown.
function M.Size(id)
    local row = D.activities[id]
    return row and row[2] > 0 and row[2] or nil
end

-- What the client offers this character in one category: { set = {[id]=true}, list = {ids} }.
-- nil while the client does not say (no group search, list not loaded yet, unreadable answer).
local function offer(kind)
    if offered[kind] then
        return offered[kind]
    end
    local category, api = D.categories[kind], C_LFGList
    if not category or type(api) ~= 'table' or type(api.GetAvailableActivities) ~= 'function' then
        return nil
    end
    if type(api.HasActivityList) == 'function' and A.Call(api.HasActivityList) ~= true then
        return nil
    end
    local list = A.Call(api.GetAvailableActivities, category)
    if not A.PublicTable(list) then
        return nil
    end
    local found = { set = {}, list = {} }
    for _, id in ipairs(list) do
        if A.Safe(id) and type(id) == 'number' and not found.set[id] then
            found.set[id] = true
            found.list[#found.list + 1] = id
        end
    end
    offered[kind] = found
    return found
end

-- Catalogue id -> activity ids of the public group search this character can use; nil when there are none.
function M.Activities(activity)
    local ids = D.catalog[L.ActivityID(activity)]
    if not ids then
        return nil
    end
    local found, out = offer(M.Kind(ids[1])), {}
    for _, id in ipairs(ids) do
        if not found or found.set[id] then
            out[#out + 1] = id
        end
    end
    return #out > 0 and out or nil
end

-- All activity ids of one kind: what the client offers, otherwise what the game data lists.
function M.CategoryActivities(kind)
    local found, out = offer(kind), {}
    if found then
        for index, id in ipairs(found.list) do
            out[index] = id
        end
        return out
    end
    local category = D.categories[kind]
    for id, row in pairs(D.activities) do
        if row[1] == category then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

local KIND_WORD = { DUNGEON = 'Dungeon', RAID = 'Raid', PVP = 'PvP' }

-- Facts of an extra activity: { id, kind, min, max, size, twin }, nil for every other activity.
function M.Extra(activity)
    local row = D.extra[activity]
    if not row then
        return nil
    end
    return { id = activity, kind = row[1], min = row[2], max = row[3], size = row[4], twin = row[5] == true }
end

-- Extra activities of one kind the client offers this character right now, sorted. Empty while the client
-- does not say what it offers: an activity nobody can enter gets no tile.
function M.Extras(kind)
    local found, out = offer(kind), {}
    if not found then
        return out
    end
    for activity, row in pairs(D.extra) do
        if row[1] == kind then
            for _, id in ipairs(D.catalog[activity]) do
                if found.set[id] then
                    out[#out + 1] = activity
                    break
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- Name of an extra activity in the language of the client, the English id while the client has no name.
function M.ExtraName(activity)
    local row = D.extra[activity]
    if not row then
        return nil
    end
    local read = Z.PublicLFG and Z.PublicLFG.Activity
    -- The ids the client offers first: that is the name the player sees in the group search.
    for _, id in ipairs(read and (M.Activities(activity) or D.catalog[activity]) or {}) do
        local facts = read(id)
        if facts then
            return row[5] and facts.name .. ' (' .. Z.T(KIND_WORD[row[1]]) .. ')' or facts.name
        end
    end
    return activity
end

-- The client announced a change of what it offers.
function M.Reset()
    offered = {}
end

-- The catalogue and the activity names of the addon ask these three (GroupFinderCatalog.lua, Locale.lua), also
-- while the public group search is switched off. An error in here must never reach them: they get "nothing".
local function shield(name, empty)
    local fn = M[name]
    M[name] = function(...)
        local ok, value = pcall(fn, ...)
        if ok then
            return value
        end
        Z.publicLFGFault = Z.publicLFGFault or tostring(value)
        return empty and {} or nil
    end
end
shield('Extra')
shield('ExtraName')
shield('Extras', true)

return M
