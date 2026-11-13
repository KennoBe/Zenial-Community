-- Group finder catalogue: display facts for the activities of GroupFinder.lua and the per-activity figures
-- the finder page shows. No transport, no stored data of its own: every figure is derived from
-- ActivityBoard.List, and "looking for group" is the existing live record with mode "LFG".
--
-- Level ranges: Forever dungeons as published by Blizzard, classic dungeons as listed by the client's own
-- group search, wings as shown by DungeonJournal. They are display and suggestion values only.
-- art: client textures of this very instance, best first. kind = lore | button | screen | wide
-- (see GroupFinderArt.lua). An entry without art gets the journal picture or the neutral tile; a picture of
-- another instance is never used as a stand-in.
local Z, L, A = ZenialCommunity, ZenialCommunity.Logic, ZenialCommunity.Adapter
local C = {}
Z.GroupFinderCatalog = C

local EJ = 'Interface\\EncounterJournal\\UI-EJ-'
local SCREEN = 'Interface\\Glues\\LoadingScreens\\LoadScreen'
local function ej(name, loreName)
    return { { kind = 'lore', file = EJ .. 'LOREBG-' .. (loreName or name) }, { kind = 'button', file = EJ .. 'DUNGEONBUTTON-' .. name } }
end
local function with(list, kind, file)
    list[#list + 1] = { kind = kind, file = file }
    return list
end

-- id = { kind, min, max, size, zone (English), area id for the localized zone name, new, journal key, art }
local function entry(kind, min, max, size, zone, area, spec)
    spec = spec or {}
    return { kind = kind, min = min, max = max, size = size, zone = zone, area = area, new = spec.new == true, journal = spec.journal, art = spec.art or {} }
end
local D, R, P = 'DUNGEON', 'RAID', 'PVP'
local ENTRIES = {
    -- New WoW: Forever dungeons
    ['Hall of Thanes'] = entry(D, 13, 18, 5, 'Dun Morogh', 1, { new = true, journal = 'Hall of Thanes' }),
    ['Ruins of Lordaeron'] = entry(D, 15, 20, 5, 'Tirisfal Glades', 85, { new = true, journal = 'Ruins of Lordaeron' }),
    ['Excavation Site'] = entry(D, 24, 29, 5, 'Wetlands', 11, { new = true, journal = 'Excavation Site: Wetlands', art = { { kind = 'wide', file = 7963777 } } }),
    ['City of Dalaran'] = entry(D, 28, 33, 5, 'Alterac Mountains', 36, { new = true, journal = 'City of Dalaran', art = { { kind = 'wide', file = 7963775 } } }),
    ['The Drowned City'] = entry(D, 35, 40, 5, 'Stranglethorn Vale', 33, { new = true, journal = 'The Drowned City' }),
    ["Krol'dok"] = entry(D, 40, 45, 5, 'Riverglades', nil, { new = true, journal = "Krol'dok Stronghold" }),
    ['Alcaz Prison'] = entry(D, 48, 53, 5, 'Dustwallow Marsh', 15, { new = true, journal = 'Alcaz Prison' }),
    ['Blackmaw Hold'] = entry(D, 55, 60, 5, 'Azshara', 16, { new = true, journal = 'Blackmaw Hold' }),
    ["Shaper's Terrace"] = entry(D, 58, 60, 5, "Un'Goro Crater", 490, { new = true, journal = "Shaper's Terrace" }),
    -- Classic dungeons
    ['Ragefire Chasm'] = entry(D, 13, 18, 5, 'Orgrimmar', 1637, { journal = 'Ragefire Chasm', art = with(ej('RagefireChasm'), 'screen', SCREEN .. 'RagefireChasm') }),
    ['Wailing Caverns'] = entry(D, 15, 24, 5, 'The Barrens', 17, { journal = 'Wailing Caverns', art = with(ej('WailingCaverns'), 'screen', SCREEN .. 'WailingCaverns') }),
    ['The Deadmines'] = entry(D, 17, 26, 5, 'Westfall', 40, { journal = 'The Deadmines', art = with(ej('Deadmines'), 'screen', SCREEN .. 'Deadmines') }),
    ['Shadowfang Keep'] = entry(D, 20, 30, 5, 'Silverpine Forest', 130, { journal = 'Shadowfang Keep', art = with(ej('ShadowfangKeep'), 'screen', SCREEN .. 'ShadowFangKeep') }),
    ['Blackfathom Deeps'] = entry(D, 24, 32, 5, 'Ashenvale', 331, { journal = 'Blackfathom Deeps', art = with(ej('BlackfathomDeeps'), 'screen', SCREEN .. 'BlackFathomDeeps') }),
    ['The Stockade'] = entry(D, 24, 32, 5, 'Stormwind City', 1519, { journal = 'The Stockade', art = with(ej('TheStockade'), 'screen', 131870) }),
    ['Gnomeregan'] = entry(D, 29, 38, 5, 'Dun Morogh', 1, { journal = 'Gnomeregan', art = with(ej('Gnomeregan'), 'screen', SCREEN .. 'Gnomeregan') }),
    ['Razorfen Kraul'] = entry(D, 29, 38, 5, 'The Barrens', 17, { journal = 'Razorfen Kraul', art = with(ej('RazorfenKraul'), 'screen', 131865) }),
    ['Scarlet Monastery: Graveyard'] = entry(D, 30, 38, 5, 'Tirisfal Glades', 85, { journal = 'Scarlet Monastery: Graveyard', art = with(ej('ScarletMonastery'), 'screen', SCREEN .. 'ScarletMonastery2') }),
    ['Scarlet Monastery: Library'] = entry(D, 33, 41, 5, 'Tirisfal Glades', 85, { journal = 'Scarlet Monastery: Library', art = ej('ScarletMonastery') }),
    ['Scarlet Monastery: Armory'] = entry(D, 34, 42, 5, 'Tirisfal Glades', 85, { journal = 'Scarlet Monastery: Armory', art = ej('ScarletMonastery') }),
    ['Scarlet Monastery: Cathedral'] = entry(D, 36, 45, 5, 'Tirisfal Glades', 85, { journal = 'Scarlet Monastery: Cathedral', art = ej('ScarletMonastery') }),
    ['Razorfen Downs'] = entry(D, 37, 46, 5, 'The Barrens', 17, { journal = 'Razorfen Downs', art = ej('RazorfenDowns') }),
    ['Uldaman'] = entry(D, 41, 51, 5, 'Badlands', 3, { journal = 'Uldaman', art = ej('Uldaman') }),
    ["Zul'Farrak"] = entry(D, 44, 54, 5, 'Tanaris', 440, { journal = "Zul'Farrak", art = ej('ZulFarrak') }),
    ['Maraudon'] = entry(D, 46, 55, 5, 'Desolace', 405, { journal = 'Maraudon', art = ej('Maraudon') }),
    ['Sunken Temple'] = entry(D, 50, 60, 5, 'Swamp of Sorrows', 8, { journal = 'Sunken Temple', art = ej('SunkenTemple') }),
    ['Blackrock Depths'] = entry(D, 52, 60, 5, 'Blackrock Mountain', 25, { journal = 'Blackrock Depths', art = ej('BlackrockDepths') }),
    ['Dire Maul East'] = entry(D, 55, 60, 5, 'Feralas', 357, { journal = 'Dire Maul: East', art = ej('DireMaul') }),
    ['Dire Maul North'] = entry(D, 57, 60, 5, 'Feralas', 357, { journal = 'Dire Maul: North', art = ej('DireMaul') }),
    ['Dire Maul West'] = entry(D, 57, 60, 5, 'Feralas', 357, { journal = 'Dire Maul: West', art = ej('DireMaul') }),
    ['Lower Blackrock Spire'] = entry(D, 55, 60, 5, 'Blackrock Mountain', 25, { journal = 'Lower Blackrock Spire', art = ej('BlackrockSpire') }),
    ['Scholomance'] = entry(D, 58, 60, 5, 'Western Plaguelands', 28, { journal = 'Scholomance', art = ej('Scholomance') }),
    ['Stratholme: Main Gate'] = entry(D, 58, 60, 5, 'Eastern Plaguelands', 139, { journal = 'Stratholme: Living', art = ej('Stratholme') }),
    ['Stratholme: Service Gate'] = entry(D, 58, 60, 5, 'Eastern Plaguelands', 139, { journal = 'Stratholme: Undead', art = ej('Stratholme') }),
    ['Upper Blackrock Spire'] = entry(D, 59, 60, 10, 'Blackrock Mountain', 25, { journal = 'Upper Blackrock Spire', art = ej('UpperBlackrockSpire') }),
    -- Raids (DungeonJournal lists no raids)
    ['Deepgrove Tomb'] = entry(R, 60, 60, 10, 'Mount Hyjal', 616, { new = true }),
    ['Mount Hyjal Summit'] = entry(R, 60, 60, 20, 'Mount Hyjal', 616, { new = true }),
    ["Onyxia's Lair"] = entry(R, 60, 60, 40, 'Dustwallow Marsh', 15, { art = ej('Onyxia', 'OnxyiasLair') }),
    ['Molten Core'] = entry(R, 60, 60, 40, 'Blackrock Mountain', 25, { art = ej('MoltenCore') }),
    ['Blackwing Lair'] = entry(R, 60, 60, 40, 'Blackrock Mountain', 25, { art = ej('BlackwingLair') }),
    ["Zul'Gurub"] = entry(R, 60, 60, 20, 'Stranglethorn Vale', 33, { art = ej('ZulGurub') }),
    ["Ruins of Ahn'Qiraj"] = entry(R, 60, 60, 20, 'Silithus', 1377, { art = ej('RuinsofAhnQiraj') }),
    ["Temple of Ahn'Qiraj"] = entry(R, 60, 60, 40, 'Silithus', 1377, { art = ej('TempleofAhnQiraj') }),
    ['Naxxramas'] = entry(R, 60, 60, 40, 'Eastern Plaguelands', 139, { art = ej('Naxxramas') }),
    -- PvP
    ['Open World PvP'] = entry(P, 1, 60, 5, nil, nil),
    ['Warsong Gulch'] = entry(P, 10, 60, 10, 'Ashenvale', 331, { art = { { kind = 'screen', file = SCREEN .. 'WarsongGulch' } } }),
    ['Arathi Basin'] = entry(P, 20, 60, 15, 'Arathi Highlands', 45, { art = { { kind = 'screen', file = SCREEN .. 'ArathiBasin' } } }),
    ['Alterac Valley'] = entry(P, 51, 60, 40, 'Alterac Mountains', 36, { art = { { kind = 'screen', file = SCREEN .. 'PvpBattleground' } } }),
}
for id, e in pairs(ENTRIES) do
    e.id = id
end
C.entries = ENTRIES

function C.Get(activity)
    return activity and ENTRIES[L.ActivityID(activity)] or nil
end

-- Catalogue entries of one kind (DUNGEON, RAID, PVP).
function C.List(kind)
    local out, order = {}, {}
    for index, id in ipairs(Z.GroupFinder.Activities[kind] or {}) do
        if ENTRIES[id] then
            out[#out + 1] = ENTRIES[id]
            order[id] = index
        end
    end
    -- By level range; equal ranges keep the order of GroupFinder.lua (new Forever instances first).
    table.sort(out, function(a, b)
        if a.min ~= b.min then
            return a.min < b.min
        end
        if a.max ~= b.max then
            return a.max < b.max
        end
        return order[a.id] < order[b.id]
    end)
    return out
end

function C.Fits(e, level)
    return e ~= nil and type(level) == 'number' and level >= e.min and level <= e.max
end

-- Zone name in the client language where the client knows the area, otherwise the translated English name.
function C.Zone(e)
    if not e or not e.zone then
        return nil
    end
    local name = e.area and C_Map and A.Call(C_Map.GetAreaInfo, e.area)
    if A.Safe(name) and type(name) == 'string' and name ~= '' then
        return name
    end
    return Z.T(e.zone)
end

function C.IsSearch(g)
    return type(g) == 'table' and g.mode == 'LFG'
end
function C.Wanted(g)
    return (g.tank or 0) + (g.healer or 0) + (g.dd or 0)
end

-- Wanted roles for a new group of `size` whose creator plays `ownRole`: one tank and one healer per five
-- players (raids: 2/2 for 10, 2/4 for 20, 4/8 for 40), the rest damage; the creator's place is taken off.
function C.RoleDefaults(size, ownRole)
    size = L.Int(size, 2, 40) and size or 5
    local tank = size >= 40 and 4 or size >= 10 and 2 or 1
    local healer = size >= 40 and 8 or size >= 20 and 4 or size >= 10 and 2 or 1
    if size < 3 then
        tank, healer = 0, 0
    end
    local dd = math.max(0, size - tank - healer)
    local role = L.Role(ownRole)
    if role == 'TANK' and tank > 0 then
        tank = tank - 1
    elseif role == 'HEALER' and healer > 0 then
        healer = healer - 1
    elseif dd > 0 then
        dd = dd - 1
    end
    return { tank = tank, healer = healer, dd = dd, size = size }
end

local function blank()
    return { groups = 0, full = 0, seekers = 0, planned = 0, ownGroup = false, ownSearch = false, applied = false, rows = { groups = {}, seekers = {}, planned = {} } }
end

-- One pass over the activity board. Returns
--   by[activityID]   figures and rows of one activity (see blank())
--   totals[category] { groups, seekers, planned } for DUNGEON / RAID / PVP / QUEST / CUSTOM
--   groups / seekers / planned / other   all rows of that sort, in board order (other = quest and PvP help)
--   own.group / own.search               the player's own live record
-- Saved rows of unreachable players are not current and are left out (r.saved).
function C.Snapshot()
    local snap = { by = {}, totals = {}, groups = {}, seekers = {}, planned = {}, other = {}, own = {} }
    local B = Z.ActivityBoard
    if not B or not Z.db then
        return snap
    end
    local function bucket(id)
        snap.by[id] = snap.by[id] or blank()
        return snap.by[id]
    end
    local function total(category)
        snap.totals[category] = snap.totals[category] or { groups = 0, seekers = 0, planned = 0 }
        return snap.totals[category]
    end
    for _, r in ipairs(B.List({ when = 'ALL', category = 'ALL', mine = 'ALL', query = '' })) do
        -- A saved live row belongs to a player who cannot be reached: not current. A saved event stays: it is
        -- planned for later and its organizer may simply be offline.
        if not r.saved or r.kind == 'EVENT' then
            local id = L.ActivityID(r.title)
            local application = r.application
            local applied = application ~= nil and (application.state == 'applied' or application.state == 'invited' or application.state == 'REQUESTED' or application.state == 'CONFIRMED')
            if r.kind == 'LIVE' and r.data then
                local b, t = bucket(id), total(r.category)
                if C.IsSearch(r.data) then
                    -- One player, up to three activities: counted under each of them, once per category.
                    local counted = {}
                    for index, activity in ipairs(C.SearchActivities(r.data)) do
                        local sb = bucket(activity)
                        sb.seekers = sb.seekers + 1
                        sb.rows.seekers[#sb.rows.seekers + 1] = r
                        if r.own then
                            sb.ownSearch = true
                        end
                        local category = index == 1 and r.category or ENTRIES[activity].kind
                        if not counted[category] then
                            counted[category] = true
                            local st = total(category)
                            st.seekers = st.seekers + 1
                        end
                    end
                    snap.seekers[#snap.seekers + 1] = r
                    if r.own then
                        snap.own.search = r
                    end
                else
                    if C.Wanted(r.data) > 0 then
                        b.groups = b.groups + 1
                        t.groups = t.groups + 1
                    else
                        b.full = b.full + 1
                    end
                    b.rows.groups[#b.rows.groups + 1] = r
                    snap.groups[#snap.groups + 1] = r
                    if r.own then
                        b.ownGroup = true
                        snap.own.group = r
                    end
                    if applied then
                        b.applied = true
                    end
                end
            elseif r.kind == 'EVENT' then
                local b, t = bucket(id), total(r.category)
                b.planned = b.planned + 1
                t.planned = t.planned + 1
                b.rows.planned[#b.rows.planned + 1] = r
                snap.planned[#snap.planned + 1] = r
                if applied then
                    b.applied = true
                end
            else
                snap.other[#snap.other + 1] = r
            end
        end
    end
    return snap
end

-- "Looking for group" -------------------------------------------------------------------------------
-- A search is the one live record a player has, with mode "LFG": roles are the roles the player offers
-- (1 or 0 each). A player may look for up to MAX_SEARCH catalogue activities at once (dungeons, raids and
-- battlegrounds in any mix). The first one is the record's activity; the others travel in the field `have`,
-- which means nothing for a search, as "+Second;Third". Clients that do not know this show the search under
-- its first activity only. Creating a group stays limited to one.
C.MAX_SEARCH = 3
function C.SearchActivities(g)
    local out, seen = {}, {}
    if type(g) ~= 'table' then
        return out
    end
    local first = L.ActivityID(g.activity)
    if type(first) == 'string' and first ~= '' then
        out[1], seen[first] = first, true
    end
    local more = type(g.have) == 'string' and g.have:match('^%+(.+)$')
    if more then
        for name in more:gmatch('[^;]+') do
            local id = L.ActivityID(name)
            if ENTRIES[id] and not seen[id] and #out < C.MAX_SEARCH then
                out[#out + 1], seen[id] = id, true
            end
        end
    end
    return out
end
-- activities: one activity or a list; roles = { TANK = true, HEALER = false, DAMAGER = true }.
-- An open group has to be closed first. Calling it again while searching replaces the search (same id).
function C.StartSearch(activities, roles, note, minutes)
    local list, seen = {}, {}
    for _, name in ipairs(type(activities) == 'table' and activities or { activities }) do
        local id = L.ActivityID(name)
        if L.Text(id, 64) and not seen[id] then
            list[#list + 1], seen[id] = id, true
        end
    end
    if #list == 0 then
        return nil, 'Enter an activity.'
    end
    if #list > C.MAX_SEARCH then
        return nil, 'You can look for at most 3 activities at once.'
    end
    if #list > 1 then
        for _, id in ipairs(list) do
            if not ENTRIES[id] then
                return nil, 'Only dungeons, raids and battlegrounds can be combined in a search.'
            end
        end
    end
    local now = A.Now()
    Z.ExpireFinder(now)
    local current = Z.db.lfg[1]
    if current and not C.IsSearch(current) then
        return nil, 'Close your group before you look for one.'
    end
    roles = type(roles) == 'table' and roles or {}
    local tank, healer, dd = roles.TANK and 1 or 0, roles.HEALER and 1 or 0, roles.DAMAGER and 1 or 0
    if tank + healer + dd == 0 then
        return nil, 'Choose at least one role.'
    end
    local have = #list > 1 and '+' .. table.concat(list, ';', 2) or 'SOLO'
    if not L.Text(have, 64) then
        return nil, 'Only dungeons, raids and battlegrounds can be combined in a search.'
    end
    local e = ENTRIES[list[1]]
    local level = math.max(1, math.min(100, math.floor(tonumber(Z.me and Z.me.level) or 1)))
    local g = {
        id = current and current.id or nil,
        mode = 'LFG',
        activity = list[1],
        min = level,
        max = level,
        have = have,
        start = current and current.start or now,
        expires = now + math.max(1, math.min(1440, tonumber(minutes) or 120)) * 60,
        note = note or '',
        size = e and e.size or 5,
        tank = tank,
        healer = healer,
        dd = dd,
    }
    return Z.SaveGroup(g, now)
end
local function searchRoles(g)
    return { TANK = (g.tank or 0) > 0, HEALER = (g.healer or 0) > 0, DAMAGER = (g.dd or 0) > 0 }
end
local function remaining(g)
    return math.max(1, math.ceil((g.expires - A.Now()) / 60))
end
-- Adds one catalogue activity to the running search (same roles, note and end time).
function C.AddSearch(activity)
    local g = Z.db and Z.db.lfg[1]
    if not g or not C.IsSearch(g) then
        return nil, 'You are not looking for a group.'
    end
    local id = L.ActivityID(activity)
    local list = C.SearchActivities(g)
    for _, existing in ipairs(list) do
        if existing == id then
            return g.id
        end
    end
    if #list >= C.MAX_SEARCH then
        return nil, 'You can look for at most 3 activities at once.'
    end
    list[#list + 1] = id
    return C.StartSearch(list, searchRoles(g), g.note, remaining(g))
end
-- Takes one activity out of the running search; the last one ends the search.
function C.RemoveSearch(activity)
    local g = Z.db and Z.db.lfg[1]
    if not g or not C.IsSearch(g) then
        return false
    end
    local id = L.ActivityID(activity)
    local list, found = {}, false
    for _, existing in ipairs(C.SearchActivities(g)) do
        if existing == id then
            found = true
        else
            list[#list + 1] = existing
        end
    end
    if not found then
        return false
    end
    if #list == 0 then
        return C.StopSearch()
    end
    return C.StartSearch(list, searchRoles(g), g.note, remaining(g)) ~= nil
end
function C.StopSearch()
    local g = Z.db and Z.db.lfg[1]
    if not g or not C.IsSearch(g) then
        return false
    end
    return Z.CloseGroup(g.id)
end
-- Roles a seeker offers, in display order.
function C.SearchRoles(g)
    local out = {}
    if (g.tank or 0) > 0 then
        out[#out + 1] = 'TANK'
    end
    if (g.healer or 0) > 0 then
        out[#out + 1] = 'HEALER'
    end
    if (g.dd or 0) > 0 then
        out[#out + 1] = 'DAMAGER'
    end
    return out
end

return C
