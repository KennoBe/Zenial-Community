-- Public group search: the player's own listing in the group search of the game.
--
-- A ZENIAL group or a ZENIAL search can also be listed publicly. ZENIAL stays in charge: the public listing
-- is a mirror with the same activities and, for a player without a group, the same roles. Two things the
-- client does not take from an addon: a comment (it reads that from its own protected input field) and
-- therefore free listings, which need one. So the public listing carries no note.
--
-- Creating, changing and removing happen only from a click of the player: the client refuses these calls
-- otherwise. Nothing here runs from a timer or an event. A listing the player made in Blizzard's window is
-- shown as it is and never touched without a click. The client ends a listing by itself after half an hour
-- and when the group is full; ZENIAL does not renew it on its own.
-- See _dev/addons/ZenialCommunity/PUBLIC-LFG-INTEGRATION-PLAN.md, work packages PLFG-25 to PLFG-27.
local Z = ZenialCommunity
local L, A = Z.Logic, Z.Adapter
local C, P, M, Q = Z.GroupFinderCatalog, Z.PublicLFG, Z.PublicLFGMap, Z.PublicLFGMatch
local Y = {}
Z.PublicLFGListing = Y

local FALLBACK_CAPACITY = 16
local state = { phase = 'NONE' }
local calling, blocked = false, false

local function api(name)
    local t = C_LFGList
    local fn = type(t) == 'table' and t[name] or nil
    return type(fn) == 'function' and fn or nil
end

-- How many activities one listing may name.
local function capacity()
    local constants = type(Constants) == 'table' and Constants.LFGConstsExposed or nil
    local value = A.PublicTable(constants) and constants.GROUP_FINDER_MAX_ACTIVITY_CAPACITY or nil
    return A.Safe(value) and type(value) == 'number' and value > 0 and value or FALLBACK_CAPACITY
end

-- Whether the client can list at all and the player left the public search on.
function Y.Available()
    return P.Available() == true and P.Capabilities().listing == true
end

-- Activity ids of the group search for the player's own record: the activity of a group, the up to three
-- activities of a search. Sorted, without doubles; empty when the game has no counterpart.
function Y.Activities(group)
    local out, seen = {}, {}
    if type(group) ~= 'table' then
        return out
    end
    local names = C.IsSearch(group) and C.SearchActivities(group) or { group.activity }
    for _, name in ipairs(names) do
        for _, id in ipairs(M.Activities(name) or {}) do
            if not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    table.sort(out)
    return out
end

local function same(a, b)
    if #a ~= #b then
        return false
    end
    for index = 1, #a do
        if a[index] ~= b[index] then
            return false
        end
    end
    return true
end

-- Whether the record may be listed now. Reasons: UNAVAILABLE, NO_GROUP, NO_ACTIVITY, TOO_MANY, NOT_LEADER,
-- GROUP_FULL, COMBAT, LOCKDOWN. On success the third result is the list of activity ids.
function Y.CanPublish(group)
    if not Y.Available() then
        return false, 'UNAVAILABLE'
    end
    if type(group) ~= 'table' then
        return false, 'NO_GROUP'
    end
    local ids = Y.Activities(group)
    if #ids == 0 then
        return false, 'NO_ACTIVITY'
    end
    if #ids > capacity() then
        return false, 'TOO_MANY'
    end
    local party = A.GroupState()
    if party.total > 1 and not party.canInvite then
        return false, 'NOT_LEADER'
    end
    for _, id in ipairs(ids) do
        local facts = P.Activity(id)
        local size = facts and facts.size or M.Size(id)
        if size and party.total >= size then
            return false, 'GROUP_FULL'
        end
    end
    if A.Call(InCombatLockdown) ~= false then
        return false, 'COMBAT'
    end
    local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if type(lockdown) == 'function' and A.Call(lockdown) ~= false then
        return false, 'LOCKDOWN'
    end
    return true, nil, ids
end

-- One call the client may refuse. Returns true when it went through.
local function guarded(fn, ...)
    if not fn then
        return false
    end
    calling, blocked = true, false
    local ok, result = pcall(fn, ...)
    calling = false
    local refused = blocked
    blocked = false
    return ok and not refused and result ~= false, refused
end

-- Lists the record publicly, or brings an existing listing in line with it. Call it only from a click.
-- Returns true, or false and a reason of Y.CanPublish, BLOCKED or FAILED.
function Y.Publish(group)
    local ok, reason, ids = Y.CanPublish(group)
    if not ok then
        return false, reason
    end
    -- A player without a group is listed with the roles of the search, or the roles the finder looks with.
    if A.GroupState().total <= 1 and type(C_LFGListRoles) == 'table' and type(C_LFGListRoles.SetRoles) == 'function' then
        local roles = Q.OwnRoles()
        if C.IsSearch(group) then
            roles = { TANK = false, HEALER = false, DAMAGER = false }
            for _, role in ipairs(C.SearchRoles(group)) do
                roles[role] = true
            end
        end
        pcall(C_LFGListRoles.SetRoles, { tank = roles.TANK == true, healer = roles.HEALER == true, dps = roles.DAMAGER == true })
    end
    -- Whatever was typed into Blizzard's own listing window last must not go out with this listing.
    pcall(api('ClearCreationTextFields') or function() end)
    local active = A.Call(api('HasActiveEntryInfo')) == true
    local done, refused = guarded(api(active and 'UpdateListing' or 'CreateListing'), { activityIDs = ids, newPlayerFriendly = false })
    if not done then
        state = { phase = refused and 'BLOCKED' or 'FAILED' }
        return false, refused and 'BLOCKED' or 'FAILED'
    end
    state = { phase = active and 'LISTED' or 'PENDING', own = true, activities = ids }
    Z.MarkDirty()
    return true
end

-- Removes the public listing. Call it only from a click. Returns true when the call went through.
function Y.Remove()
    if not Y.Available() then
        return false, 'UNAVAILABLE'
    end
    local done, refused = guarded(api('RemoveListing'))
    if not done then
        return false, refused and 'BLOCKED' or 'FAILED'
    end
    state = { phase = 'NONE' }
    Z.MarkDirty()
    return true
end

-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN: counts only while one of our listing calls is running.
function Y.OnBlocked()
    if calling then
        blocked = true
    end
end

-- Reads what the client holds as the player's listing.
local function readActive()
    if A.Call(api('HasActiveEntryInfo')) ~= true then
        return nil
    end
    local entry = A.Call(api('GetActiveEntryInfo'))
    local ids, out = A.PublicTable(entry) and entry.activityIDs or nil, {}
    if A.PublicTable(ids) then
        for _, id in ipairs(ids) do
            if A.Safe(id) and type(id) == 'number' then
                out[#out + 1] = id
            end
        end
    end
    table.sort(out)
    return out
end

-- Takes over what the client holds, e.g. after logging in: a listing made earlier or in Blizzard's window.
function Y.Initialize()
    state = { phase = 'NONE' }
    if not Y.Available() then
        return
    end
    local ids = readActive()
    if ids then
        state = { phase = 'LISTED', own = false, activities = ids }
    end
end

-- Events of the player's listing, passed on by Main.lua.
function Y.OnEvent(event)
    if not Y.Available() then
        return
    end
    if event == 'LFG_LIST_ACTIVE_ENTRY_UPDATE' then
        local ids = readActive()
        if ids then
            state = { phase = 'LISTED', own = state.own == true, activities = ids }
        elseif state.phase == 'LISTED' or state.phase == 'PENDING' then
            state = { phase = 'NONE' }
        end
    elseif event == 'LFG_LIST_ENTRY_CREATION_FAILED' then
        state = { phase = 'FAILED' }
    elseif event == 'LFG_LIST_ENTRY_EXPIRED_TIMEOUT' or event == 'LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS' then
        state = { phase = 'EXPIRED', reason = event == 'LFG_LIST_ENTRY_EXPIRED_TIMEOUT' and 'TIMEOUT' or 'FULL' }
    else
        return
    end
    Z.MarkDirty()
end

-- State of the public listing for the interface:
-- { phase = 'NONE'|'PENDING'|'LISTED'|'FAILED'|'BLOCKED'|'EXPIRED', own, activities, matches, reason }
-- own: listed from ZENIAL in this session (false: found as it was, e.g. made in Blizzard's window).
-- matches: the listing names exactly the activities of the player's ZENIAL record.
function Y.State()
    local wanted = Y.Activities(Z.db and Z.db.lfg[1])
    return {
        phase = state.phase, own = state.own == true, activities = state.activities, reason = state.reason,
        matches = state.activities ~= nil and #wanted > 0 and same(state.activities, wanted),
    }
end

return Y
