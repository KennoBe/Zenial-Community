-- Public group search (Blizzard group search of the client): reading layer.
--
-- Everything the client returns is read through the adapter guards. A value the client keeps secret, does
-- not deliver yet or delivers in an unexpected shape stays unknown; nothing is guessed. Results live in
-- memory only: they never enter Z.db, the activity board, a network message or the companion export.
--
-- Search control, the result store and the events follow in this file with the next work packages.
local Z, A = ZenialCommunity, ZenialCommunity.Adapter
local M = Z.PublicLFGMap
local P = {}
Z.PublicLFG = P

local ROLES = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'dps' }
local MEMBER_LIMIT = 10
local activities = {}

local function has(space, name)
    local t = _G[space]
    return type(t) == 'table' and type(t[name]) == 'function'
end

local function api(name)
    local t = C_LFGList
    local fn = type(t) == 'table' and t[name] or nil
    return type(fn) == 'function' and fn or nil
end

-- One readable table from the client, otherwise nil.
local function one(name, ...)
    local value = A.Call(api(name), ...)
    return A.PublicTable(value) and value or nil
end

-- Field of a readable table. Returns the value when it has the expected type, otherwise nil; the second
-- result is true when the client keeps the value secret.
local function field(t, key, kind)
    local value = t[key]
    if not A.Safe(value) then
        return nil, true
    end
    if type(value) ~= kind then
        return nil
    end
    return value
end

local function text(t, key)
    local value, secret = field(t, key, 'string')
    return value ~= '' and value or nil, secret
end

-- What the client provides, one flag per function group.
function P.Capabilities()
    return {
        runtime = A.RuntimeAvailable(),
        search = has('C_LFGList', 'Search'),
        results = has('C_LFGList', 'GetSearchResultInfo') and (has('C_LFGList', 'GetFilteredSearchResults') or has('C_LFGList', 'GetSearchResults')),
        activities = has('C_LFGList', 'GetActivityInfoTable'),
        counts = has('C_LFGList', 'GetSearchResultMemberCounts'),
        leader = has('C_LFGList', 'GetSearchResultLeaderInfo'),
        members = has('C_LFGList', 'GetSearchResultPlayerInfo'),
        languages = has('C_LFGList', 'GetAvailableLanguageSearchFilter'),
        roles = has('C_LFGListRoles', 'GetRoles'),
        whisperText = has('ChatFrameUtil', 'SendTellWithMessage') or has('ChatFrameUtil', 'OpenChat'),
        invite = has('C_PartyInfo', 'InviteUnit'),
        listing = has('C_LFGList', 'CreateListing') and has('C_LFGList', 'RemoveListing') and has('C_LFGList', 'HasActiveEntryInfo'),
    }
end

-- Whether the public group search can be used at all.
function P.Available()
    local c = P.Capabilities()
    if c.runtime and c.search and c.results and c.activities then
        return true
    end
    return false, 'UNAVAILABLE'
end

-- Search languages the client offers: { { code = 'deDE', label = 'Deutsch' }, ... }. Never a fixed list.
function P.Languages()
    local list, out = one('GetAvailableLanguageSearchFilter'), {}
    for _, code in ipairs(list or {}) do
        if A.Safe(code) and type(code) == 'string' and code ~= '' then
            local label = _G['LFG_LIST_LANGUAGE_' .. string.upper(code)]
            out[#out + 1] = { code = code, label = A.Safe(label) and type(label) == 'string' and label ~= '' and label or code }
        end
    end
    return out
end

-- Facts of one activity of the group search, nil while the client does not have them:
-- { id, name, short, kind, catalog, size, minLevel, maxLevel, roles }
-- size is nil when the activity has no fixed group size; roles tells whether the client expects one tank,
-- one healer and three damage dealers, which is what makes the open role slots of a result meaningful.
function P.Activity(id)
    if type(id) ~= 'number' then
        return nil
    end
    if activities[id] then
        return activities[id]
    end
    local info = one('GetActivityInfoTable', id)
    local full = info and text(info, 'fullName')
    if not full then
        return nil
    end
    local players = field(info, 'maxNumPlayers', 'number')
    local low, high = field(info, 'minLevelSuggestion', 'number'), field(info, 'maxLevelSuggestion', 'number')
    local row = {
        id = id, name = full, short = text(info, 'shortName') or full,
        kind = M.KindOf(field(info, 'categoryID', 'number')) or M.Kind(id),
        catalog = M.ActivityOf(id),
        size = players and players > 0 and players or M.Size(id),
        minLevel = low and low > 0 and low or nil,
        maxLevel = high and high > 0 and high or nil,
        roles = field(info, 'useDungeonRoleExpectations', 'boolean') == true,
    }
    activities[id] = row
    return row
end

-- Result ids of the last search and the number the service reports: the list Blizzard already filtered
-- (reported and ignored players are gone), otherwise the plain list. nil when the client gives neither.
function P.ReadList()
    for _, name in ipairs({ 'GetFilteredSearchResults', 'GetSearchResults' }) do
        local total, ids = A.Call(api(name))
        if type(total) == 'number' and A.PublicTable(ids) then
            local out = {}
            for _, id in ipairs(ids) do
                if A.Safe(id) and type(id) == 'number' then
                    out[#out + 1] = id
                end
            end
            return out, total
        end
    end
    return nil
end

local function roleFlags(t)
    if not A.PublicTable(t) then
        return nil
    end
    local out = {}
    for role, key in pairs(ROLES) do
        out[role] = field(t, key, 'boolean') == true
    end
    return out
end

local function roleNumbers(t, suffix)
    local out = {}
    for role in pairs(ROLES) do
        local value = field(t, role .. suffix, 'number')
        if not value then
            return nil
        end
        out[role] = value
    end
    return out
end

-- Activities of one result: ids, catalogue activities, the shared size and whether role slots count.
local function readActivities(row, ids)
    local seen, size, mixed, roles = {}, nil, false, true
    row.activityIds, row.activities = {}, {}
    for _, id in ipairs(ids) do
        if A.Safe(id) and type(id) == 'number' then
            row.activityIds[#row.activityIds + 1] = id
            local activity = P.Activity(id)
            if not activity then
                row.pending, roles = true, false
            else
                row.activityName = row.activityName or activity.name
                if activity.catalog and not seen[activity.catalog] then
                    seen[activity.catalog] = true
                    row.activities[#row.activities + 1] = activity.catalog
                end
                if activity.size == nil or (size ~= nil and size ~= activity.size) then
                    mixed = true
                end
                size = size or activity.size
                roles = roles and activity.roles
            end
        end
    end
    row.size = not mixed and not row.pending and size or nil
    row.roleSlots = roles and #row.activityIds > 0
end

-- One search result as a ZENIAL row, built only from values the client delivered.
-- Returns nil, 'MISSING' while the client has no data for the id and nil, 'OWN' for the player's own listing.
-- row.restricted: the client kept a value secret; row.pending: activity facts are not there yet;
-- row.leader is nil until the client delivers the name (it usually follows shortly after the result).
function P.ReadRow(id, runId)
    local info = type(id) == 'number' and one('GetSearchResultInfo', id) or nil
    if not info then
        return nil, 'MISSING'
    end
    if field(info, 'hasSelf', 'boolean') then
        return nil, 'OWN'
    end
    runId = runId or 0
    local row = { key = 'PUB:' .. runId .. ':' .. id, source = 'PUBLIC', resultId = id, runId = runId, readAt = A.Clock(), activityIds = {}, activities = {} }
    local function get(key, kind)
        local value, secret = field(info, key, kind)
        if secret then
            row.restricted = true
        end
        return value
    end
    local function note(key)
        local value = get(key, 'string')
        return value ~= '' and value or nil
    end
    row.members = get('numMembers', 'number')
    local ids = get('activityIDs', 'table')
    if not row.members or not A.PublicTable(ids) then
        row.restricted = true
        return row
    end
    readActivities(row, ids)
    row.solo = row.members <= 1
    row.leader, row.comment, row.title = note('leaderName'), note('comment'), note('name')
    row.age = get('age', 'number')
    row.friends = (get('numBNetFriends', 'number') or 0) + (get('numCharFriends', 'number') or 0)
    row.guildMates = get('numGuildMates', 'number') or 0
    local playstyle = get('generalPlaystyle', 'number')
    row.playstyle = playstyle and playstyle > 0 and playstyle or nil
    row.beginners = get('newPlayerFriendly', 'boolean') == true
    row.delisted = get('isDelisted', 'boolean') == true
    row.partyGuid = note('partyGUID')

    local counts = one('GetSearchResultMemberCounts', id)
    if counts then
        row.counts = roleNumbers(counts, '')
        row.remaining = row.roleSlots and roleNumbers(counts, '_REMAINING') or nil
    end
    local leader = one('GetSearchResultLeaderInfo', id)
    if leader then
        row.leaderClass, row.leaderLevel, row.leaderArea = text(leader, 'classFilename'), field(leader, 'level', 'number'), text(leader, 'areaName')
        if row.solo then
            -- The role a single player offers is in lfgRoles; assignedRole is not reliable for a player without a group.
            row.soloRoles = roleFlags(field(leader, 'lfgRoles', 'table'))
        end
    end
    return row
end

-- Members of one result for the visible card: { { class, level, role, leader, name }, ... }, at most ten.
function P.ReadMembers(id, count)
    local out = {}
    for index = 1, math.min(type(count) == 'number' and count or 0, MEMBER_LIMIT) do
        local info = one('GetSearchResultPlayerInfo', id, index)
        if info then
            local role = text(info, 'assignedRole')
            out[#out + 1] = {
                class = text(info, 'classFilename'), level = field(info, 'level', 'number'),
                role = role and ROLES[role] and role or nil,
                leader = field(info, 'isLeader', 'boolean') == true, name = text(info, 'name'),
            }
        end
    end
    return out
end

-- Forget what was read about activities (the client announced a change of what it offers).
function P.Reset()
    activities = {}
end

return P
