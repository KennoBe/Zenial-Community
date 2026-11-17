-- Public group search (Blizzard group search of the client): reading layer.
--
-- Everything the client returns is read through the adapter guards. A value the client keeps secret, does
-- not deliver yet or delivers in an unexpected shape stays unknown; nothing is guessed. Results live in
-- memory only: they never enter Z.db, the activity board, a network message or the companion export.
--
-- The file has three parts: reading (capabilities, languages, activities, one result), search control
-- (signature, start, waiting time, timeout, blocked calls, foreign searches) and the result store (rows per
-- query, late updates of single results, figures for the tiles).
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

---------------------------------------------------------------------------------------------------
-- Search control
---------------------------------------------------------------------------------------------------
-- The client has one search and one result list, shared with Blizzard's own window and with other addons.
-- A search of ours starts only from a click of the player (the client refuses anything else), never by
-- itself and never again on its own. Every search call that is seen, ours or a foreign one, starts the
-- waiting time. A search without an answer and a failed search are states of their own, never "no groups".
local WAIT, TIMEOUT, LIMIT = 5, 30, 100
P.WAIT, P.TIMEOUT, P.LIMIT = WAIT, TIMEOUT, LIMIT
local store = {}               -- result store, filled in at the end of the file

local state = { phase = 'IDLE', runId = 0 }
local runs = 0
local lastCall                 -- clock of the last search call seen
local calling, blocked = false, false
local hooked = false
local foreignCall              -- query of a foreign search call whose results are still to come; false = query unknown

local function numbers(list)
    local out, seen = {}, {}
    if A.PublicTable(list) then
        for _, id in ipairs(list) do
            if A.Safe(id) and type(id) == 'number' and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    table.sort(out)
    return out
end

-- A query in its comparable form: { category, activities (sorted, unique), mode, codes (sorted) }.
-- In the mode CUSTOM only languages the client offers count.
local function normalize(query)
    if type(query) ~= 'table' or type(query.category) ~= 'number' then
        return nil
    end
    local q = { category = query.category, activities = numbers(query.activities), codes = {} }
    q.mode = query.languageMode == 'ALL' and 'ALL' or query.languageMode == 'CUSTOM' and 'CUSTOM' or 'DEFAULT'
    if q.mode == 'CUSTOM' and type(query.languages) == 'table' then
        for _, language in ipairs(P.Languages()) do
            if query.languages[language.code] == true then
                q.codes[#q.codes + 1] = language.code
            end
        end
        table.sort(q.codes)
    end
    return q
end

local function signature(q)
    return q.category .. '|' .. table.concat(q.activities, ',') .. '|' .. q.mode .. '|' .. table.concat(q.codes, ',')
end

-- What the search call gets as its language argument: nil = the default of the game.
local function languageFilter(q)
    if q.mode == 'DEFAULT' then
        return nil
    end
    local chosen, out, any = {}, {}, false
    for _, code in ipairs(q.codes) do
        chosen[code] = true
    end
    for _, language in ipairs(P.Languages()) do
        out[language.code] = q.mode == 'ALL' or chosen[language.code] == true
        any = true
    end
    return any and out or nil
end

-- Identity of a search: category, activities and languages, independent of their order.
-- query = { category = number, activities = { ids }, languageMode = 'DEFAULT'|'ALL'|'CUSTOM', languages = { deDE = true } }
function P.Signature(query)
    local q = normalize(query)
    return q and signature(q) or nil
end

-- Whether a search may start now. Reasons: UNAVAILABLE, NO_ACTIVITY, NO_LANGUAGE, BUSY, COOLDOWN, COMBAT, LOCKDOWN.
function P.CanSearch(query)
    local ok, reason = P.Available()
    if not ok then
        return false, reason
    end
    local q = normalize(query)
    if not q or #q.activities == 0 then
        return false, 'NO_ACTIVITY'
    end
    if q.mode == 'CUSTOM' and #q.codes == 0 then
        return false, 'NO_LANGUAGE'
    end
    if state.phase == 'SEARCHING' then
        return false, 'BUSY'
    end
    if lastCall and A.Clock() - lastCall < WAIT then
        return false, 'COOLDOWN'
    end
    if A.Call(InCombatLockdown) ~= false then
        return false, 'COMBAT'
    end
    local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if type(lockdown) == 'function' and A.Call(lockdown) ~= false then
        return false, 'LOCKDOWN'
    end
    return true, nil, q
end

-- A search call was made, by us or by someone else (Blizzard's window, another addon).
local function onSearchCall(category, _, _, languages, _, _, ids)
    lastCall = A.Clock()
    if calling then
        return
    end
    local q = nil
    if A.Safe(category, languages) and type(category) == 'number' then
        q = { category = category, activities = numbers(ids), mode = 'DEFAULT', codes = {} }
        if A.PublicTable(languages) then
            q.mode = 'CUSTOM'
            for code, on in pairs(languages) do
                if A.Safe(code, on) and type(code) == 'string' and on == true then
                    q.codes[#q.codes + 1] = code
                end
            end
            table.sort(q.codes)
        elseif languages ~= nil then
            q = nil
        end
    end
    foreignCall = q and #q.activities > 0 and q or false
    if state.phase == 'SEARCHING' then
        state.superseded = true
    end
end

local function installHook()
    if hooked or type(hooksecurefunc) ~= 'function' or type(C_LFGList) ~= 'table' or type(C_LFGList.Search) ~= 'function' then
        return
    end
    hooked = pcall(hooksecurefunc, C_LFGList, 'Search', function(...)
        pcall(onSearchCall, ...)
    end)
end

-- Starts watching for foreign searches. Called once the character is known.
function P.Initialize()
    if P.Available() then
        installHook()
    end
end

-- Starts a search. Call it only from a click handler: the client refuses the call otherwise.
-- Returns true, or false and the reason of P.CanSearch or 'BLOCKED'.
function P.Search(query)
    local ok, reason, q = P.CanSearch(query)
    if not ok then
        return false, reason
    end
    installHook()
    runs = runs + 1
    local before = lastCall
    calling, blocked = true, false
    local fine = pcall(api('Search'), q.category, 0, 0, languageFilter(q), false, nil, q.activities)
    calling = false
    if blocked or not fine then
        -- The client did not take the call: nothing went out, so no waiting time either.
        lastCall = before
        state = { phase = 'BLOCKED', runId = runs, signature = signature(q), reason = blocked and 'BLOCKED' or 'ERROR' }
        blocked = false
        return false, 'BLOCKED'
    end
    lastCall, foreignCall = A.Clock(), nil
    state = { phase = 'SEARCHING', runId = runs, signature = signature(q), query = q, startedAt = lastCall }
    store.release()
    return true
end

-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN: counts only while our own search call is running.
function P.OnBlocked()
    if calling then
        blocked = true
    end
end

-- Without the hook a foreign search cannot be seen. Results that name none of the searched activities
-- then show that the list belongs to someone else.
local function plausible(q, ids)
    local wanted = {}
    for _, id in ipairs(q.activities) do
        wanted[id] = true
    end
    for index = 1, math.min(#ids, 5) do
        local info = one('GetSearchResultInfo', ids[index])
        local list = info and field(info, 'activityIDs', 'table')
        if A.PublicTable(list) then
            for _, id in ipairs(list) do
                if A.Safe(id) and wanted[id] then
                    return true
                end
            end
            return false
        end
    end
    return true
end

local function results(target, ids, total)
    target.phase, target.receivedAt, target.ids, target.total = 'READY', A.Clock(), ids, total
    target.count = #ids
    -- The service never returns more than LIMIT results and then reports LIMIT as the total.
    target.truncated = #ids >= LIMIT or total > #ids
end

local function onResults()
    local ids, total = P.ReadList()
    local own = state.phase == 'SEARCHING' and not state.superseded
    if own and ids and not hooked and not plausible(state.query, ids) then
        own = false
    end
    if own then
        if ids then
            results(state, ids, total)
            store.take()
        else
            state.phase, state.reason = 'FAILED', 'UNREADABLE'
        end
    else
        local q = foreignCall
        foreignCall = nil
        if not hooked then
            lastCall = A.Clock()
        end
        if q and ids then
            -- A foreign search whose query is known: a valid result for exactly that query.
            runs = runs + 1
            state = { runId = runs, foreign = true, signature = signature(q), query = q }
            results(state, ids, total)
            store.take()
        else
            -- A list nobody announced: what we hold is no longer the list of the client.
            if state.phase == 'SEARCHING' then
                state = { phase = 'FAILED', runId = state.runId, signature = state.signature, reason = 'REPLACED' }
            end
            state.stale, state.foreign = true, true
            store.release()
        end
    end
    Z.MarkDirty()
end

local function onFailed(detail)
    if state.phase == 'SEARCHING' then
        state.reason = state.superseded and 'REPLACED' or 'SERVICE'
        state.detail = not state.superseded and A.Safe(detail) and type(detail) == 'string' and detail ~= '' and detail or nil
        state.phase = 'FAILED'
        Z.MarkDirty()
    end
    foreignCall = nil
end

-- Events of the group search, passed on by Main.lua.
function P.OnEvent(event, ...)
    if event == 'LFG_LIST_SEARCH_RESULTS_RECEIVED' then
        onResults()
    elseif event == 'LFG_LIST_SEARCH_FAILED' then
        onFailed(...)
    elseif event == 'LFG_LIST_SEARCH_RESULT_UPDATED' then
        store.touch((...))
    end
end

-- From the quarter-second step of Main.lua. Works only while a search is waiting for its answer or the
-- result store has something to read again.
function P.Tick()
    if state.phase == 'SEARCHING' and A.Clock() - state.startedAt >= TIMEOUT then
        state.phase, state.reason = 'TIMEOUT', nil
        Z.MarkDirty()
    end
    if store.busy then
        store.work()
    end
end

-- State of the search for the interface:
-- { phase = 'IDLE'|'SEARCHING'|'READY'|'FAILED'|'TIMEOUT'|'BLOCKED', runId, signature, startedAt, receivedAt,
--   total, count, truncated, stale, foreign, reason, detail, cooldownUntil }
-- foreign: the result comes from a search someone else started; stale: the list of the client was replaced
-- by a search we know nothing about, so what was read before is no longer current.
function P.State()
    return {
        phase = state.phase, runId = state.runId, signature = state.signature, startedAt = state.startedAt,
        receivedAt = state.receivedAt, total = state.total, count = state.count, truncated = state.truncated == true,
        stale = state.stale == true, foreign = state.foreign == true, reason = state.reason, detail = state.detail,
        cooldownUntil = lastCall and lastCall + WAIT or nil,
    }
end

-- Result ids of the current list, nil when there is none (for the result store).
function P.ResultIds()
    return state.phase == 'READY' and not state.stale and state.ids or nil
end

---------------------------------------------------------------------------------------------------
-- Result store
---------------------------------------------------------------------------------------------------
-- Results are taken over once, when a list arrives, into rows of our own. A list is kept per query
-- (signature): the search over a whole category feeds the tiles, the search for one instance feeds its
-- overview, and going back and forth costs no new search. Only the newest list is "live": it is the list
-- the client holds, so single results can still be read again when the client reports a change (leader
-- names arrive that way). Every other list is a snapshot with its age. Nothing here is saved or sent.
local ROW_LIMIT, SET_LIMIT, KEEP = 300, 8, 900
local RETRY = { 0.25, 1, 3 }
P.ROW_LIMIT, P.KEEP = ROW_LIMIT, KEEP

local sets = {}                -- [signature] = set
local live                     -- the set that is the current list of the client
local dirty, dirtyCount = {}, 0
local revision = 0
local memo = { rows = {} }

local function windowShown()
    local ui = Z.UI
    return ui ~= nil and ui.frame ~= nil and ui.frame:IsShown() == true
end

local function reindex(set)
    set.byId, set.byKey = {}, {}
    for index, row in ipairs(set.rows) do
        set.byId[row.resultId], set.byKey[row.key] = index, row
    end
end

local function hasPending(set)
    for _, row in ipairs(set.rows) do
        if row.pending then
            return true
        end
    end
    return false
end

-- Plans the next reading of rows whose activity facts are missing: 0.25 s, then 1 s, then 3 s later.
local function arm(set)
    set.retryAt = nil
    if set.live and set.attempts < #RETRY and hasPending(set) then
        set.retryAt = A.Clock() + RETRY[set.attempts + 1]
        store.busy = true
    end
end

local function prune()
    local now, list = A.Clock(), {}
    for key, set in pairs(sets) do
        if now - set.receivedAt > KEEP then
            sets[key] = nil
        else
            list[#list + 1] = set
        end
    end
    table.sort(list, function(a, b) return a.receivedAt > b.receivedAt end)
    for index = SET_LIMIT + 1, #list do
        sets[list[index].signature] = nil
    end
end

-- The list of the client is no longer ours to read (new search, foreign list): the live set becomes a snapshot.
function store.release()
    if live then
        live.live, live.retryAt = false, nil
        revision = revision + 1
    end
    live, dirty, dirtyCount, store.busy = nil, {}, 0, false
end

-- Takes the list of the current state over as the live set.
function store.take()
    store.release()
    local set = {
        signature = state.signature, query = state.query, runId = state.runId, receivedAt = state.receivedAt, total = state.total,
        truncated = state.truncated == true, foreign = state.foreign == true, rows = {}, wanted = {}, live = true, attempts = 0, unreadable = 0,
    }
    for _, id in ipairs(state.query.activities) do
        set.wanted[id] = true
    end
    for _, id in ipairs(state.ids or {}) do
        if #set.rows >= ROW_LIMIT then
            set.truncated = true
            break
        end
        local row = P.ReadRow(id, set.runId)
        if row then
            set.rows[#set.rows + 1] = row
            if row.restricted and #row.activityIds == 0 then
                set.unreadable = set.unreadable + 1
            end
        end
    end
    reindex(set)
    sets[set.signature] = set
    live = set
    prune()
    arm(set)
    revision = revision + 1
end

-- LFG_LIST_SEARCH_RESULT_UPDATED: only noted here; the reading happens once in the next step.
function store.touch(id)
    if not live or not A.Safe(id) or type(id) ~= 'number' then
        return
    end
    if not dirty[id] then
        dirty[id] = true
        dirtyCount = dirtyCount + 1
    end
    store.busy = true
end

local function update(set, id, row, why)
    local index = set.byId[id]
    if row then
        if index then
            set.rows[index] = row
        elseif #set.rows < ROW_LIMIT then
            set.rows[#set.rows + 1] = row
        else
            return false
        end
        reindex(set)
        return true
    end
    if not index then
        return false
    end
    if why == 'OWN' then
        table.remove(set.rows, index)
        reindex(set)
        return true
    end
    -- The client has nothing about the result any more: the listing is gone.
    local old = set.rows[index]
    if old.gone then
        return false
    end
    old.gone, old.delisted = true, true
    return true
end

-- The work of one step: read the results the client reported as changed, then the rows that still wait for
-- activity facts. Local reads only; a search is never started from here.
function store.work()
    local changed = false
    if live and dirtyCount > 0 then
        local ids = dirty
        dirty, dirtyCount = {}, 0
        for id in pairs(ids) do
            local row, why = P.ReadRow(id, live.runId)
            changed = update(live, id, row, why) or changed
        end
    end
    if live and live.retryAt then
        if not windowShown() then
            -- Nobody is looking: stop; P.Rows plans it again when the rows are asked for.
            live.retryAt = nil
        elseif A.Clock() >= live.retryAt then
            live.attempts = live.attempts + 1
            for index, row in ipairs(live.rows) do
                if row.pending then
                    local fresh = P.ReadRow(row.resultId, live.runId)
                    if fresh then
                        live.rows[index] = fresh
                        changed = changed or not fresh.pending
                    end
                end
            end
            reindex(live)
            arm(live)
        end
    end
    store.busy = live ~= nil and (dirtyCount > 0 or live.retryAt ~= nil)
    if changed then
        revision = revision + 1
        Z.MarkDirty()
    end
end

-- The newest list that was searched for one of these activities.
local function covering(ids)
    local best, now = nil, A.Clock()
    for _, set in pairs(sets) do
        if now - set.receivedAt <= KEEP and (not best or set.receivedAt > best.receivedAt) then
            for _, id in ipairs(ids) do
                if set.wanted[id] then
                    best = set
                    break
                end
            end
        end
    end
    return best
end

local function describe(set, complete)
    return {
        signature = set.signature, runId = set.runId, receivedAt = set.receivedAt, live = set.live == true, complete = complete,
        truncated = set.truncated, foreign = set.foreign, total = set.total, unreadable = set.unreadable,
    }
end

-- Rows of one catalogue activity from the newest list that was searched for it, and facts about that list:
-- { signature, runId, receivedAt, live, complete, truncated, foreign, total, unreadable }.
-- complete: the list was searched for every activity of the catalogue entry and was not cut off.
-- Returns {}, nil when no list covers the activity. The returned tables belong to the store: do not change them.
function P.Rows(activity)
    local ids = M.Activities(activity)
    local set = ids and covering(ids)
    if not set then
        return {}, nil
    end
    if set.live and not set.retryAt and set.attempts < #RETRY and hasPending(set) then
        arm(set)
    end
    local cache = memo.rows[activity]
    if not cache or cache.revision ~= revision or cache.set ~= set then
        local wanted, rows, complete = {}, {}, not set.truncated
        for _, id in ipairs(ids) do
            wanted[id] = true
            complete = complete and set.wanted[id] == true
        end
        for _, row in ipairs(set.rows) do
            for _, id in ipairs(row.activityIds) do
                if wanted[id] then
                    rows[#rows + 1] = row
                    break
                end
            end
        end
        cache = { revision = revision, set = set, rows = rows, info = describe(set, complete) }
        memo.rows[activity] = cache
    end
    return cache.rows, cache.info
end

-- One row by its key, from any list that is still kept.
function P.Row(key)
    for _, set in pairs(sets) do
        if set.byKey[key] then
            return set.byKey[key]
        end
    end
    return nil
end

-- Figures per catalogue activity for the tiles: { [activity] = { groups, seekers, capped, at } }.
-- Each activity takes its figures from the newest list that was searched for it. capped: that list was cut
-- off, so the figures are a sample and never a total. Listings that are gone or unreadable do not count.
function P.Counts()
    local now = A.Clock()
    local cache = memo.counts
    if cache and cache.revision == revision and now < cache.validUntil then
        return cache.map
    end
    local list, validUntil = {}, math.huge
    for _, set in pairs(sets) do
        if now - set.receivedAt <= KEEP then
            list[#list + 1] = set
            validUntil = math.min(validUntil, set.receivedAt + KEEP)
        end
    end
    table.sort(list, function(a, b) return a.receivedAt > b.receivedAt end)
    local map, owner = {}, {}
    for _, set in ipairs(list) do
        for id in pairs(set.wanted) do
            local activity = M.ActivityOf(id)
            if activity and not owner[activity] then
                owner[activity] = set
                map[activity] = { groups = 0, seekers = 0, capped = set.truncated, at = set.receivedAt }
            end
        end
        for _, row in ipairs(set.rows) do
            if not row.delisted and not row.restricted then
                for _, activity in ipairs(row.activities) do
                    if owner[activity] == set then
                        local entry = map[activity]
                        if row.solo then
                            entry.seekers = entry.seekers + 1
                        else
                            entry.groups = entry.groups + 1
                        end
                    end
                end
            end
        end
    end
    memo.counts = { revision = revision, validUntil = validUntil, map = map }
    return map
end

-- Drops every list that was read.
function P.Clear()
    store.release()
    sets, memo = {}, { rows = {} }
    revision = revision + 1
end

return P
