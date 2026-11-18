-- Group finder: how well a group fits the player, for ZENIAL groups and public groups alike.
--
-- Both sources keep their own records and their own actions. For sorting and filtering each record is
-- turned into the same small read-only view; nothing here writes anywhere, reads the interface or calls the
-- group search. The rule is meant to be explainable in one sentence per step:
--   1. a group that looks for one of my roles and fits my level comes first, ahead of it only the ones that
--      are about to start ("very fitting"),
--   2. a group whose role needs are unknown is never treated as unfitting,
--   3. inside the same step ZENIAL comes before public, then friends and guild, then the fuller group.
local Z = ZenialCommunity
local L, A = Z.Logic, Z.Adapter
local Q = {}
Z.PublicLFGMatch = Q

local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local ROLE_FIELD = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'dd' }
local LFG_FIELD = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'dps' }
local RANK = { BEST = 1, GOOD = 2, UNKNOWN = 3, POOR = 4, FULL = 5 }
Q.ROLES, Q.RANK = ROLES, RANK

local function any(roles)
    return type(roles) == 'table' and (roles.TANK == true or roles.HEALER == true or roles.DAMAGER == true)
end

-- The roles the player looks with. In this order: what was chosen in the finder, the role of the profile,
-- the roles set in the group search of the game, the roles the class can play, every role.
-- Returns the roles and where they come from: 'CHOSEN' | 'PROFILE' | 'GAME' | 'CLASS' | 'ALL'.
-- What the game answers is remembered for ten seconds: the finder asks on every refresh, and a refresh must
-- not call into the group search of the game. Q.Forget() drops what was remembered.
local MEMO = 10
local memo
function Q.Forget()
    memo = nil
end
local function remember(roles, origin)
    memo = { at = A.Clock(), roles = { TANK = roles.TANK == true, HEALER = roles.HEALER == true, DAMAGER = roles.DAMAGER == true }, origin = origin }
    return roles, origin
end
local function fromGame()
    local api = C_LFGListRoles
    local game = type(api) == 'table' and A.Call(api.GetRoles) or nil
    if A.PublicTable(game) then
        local out = {}
        for _, role in ipairs(ROLES) do
            local value = game[LFG_FIELD[role]]
            out[role] = A.Safe(value) and value == true
        end
        if any(out) then
            return out, 'GAME'
        end
    end
    local list = C_LFGList
    if type(list) == 'table' and type(list.GetAvailableRoles) == 'function' then
        local tank, healer, dps = A.Call(list.GetAvailableRoles)
        local out = { TANK = tank == true, HEALER = healer == true, DAMAGER = dps == true }
        if any(out) then
            return out, 'CLASS'
        end
    end
    return { TANK = true, HEALER = true, DAMAGER = true }, 'ALL'
end
function Q.OwnRoles()
    local chosen = Z.uiCharacter and Z.uiCharacter.finderRoles
    if any(chosen) then
        return { TANK = chosen.TANK == true, HEALER = chosen.HEALER == true, DAMAGER = chosen.DAMAGER == true }, 'CHOSEN'
    end
    local profile = Z.db and L.Role(Z.db.roles)
    if profile and ROLE_FIELD[profile] then
        return { TANK = profile == 'TANK', HEALER = profile == 'HEALER', DAMAGER = profile == 'DAMAGER' }, 'PROFILE'
    end
    if memo and A.Clock() - memo.at < MEMO then
        -- A copy: callers change what they get.
        return { TANK = memo.roles.TANK, HEALER = memo.roles.HEALER, DAMAGER = memo.roles.DAMAGER }, memo.origin
    end
    return remember(fromGame())
end

-- Remembers the roles for this character. An empty choice goes back to the automatic roles.
function Q.SetOwnRoles(roles)
    if not Z.uiCharacter then
        return
    end
    Z.uiCharacter.finderRoles = any(roles) and { TANK = roles.TANK == true, HEALER = roles.HEALER == true, DAMAGER = roles.DAMAGER == true } or nil
end

-- View of a ZENIAL group (live record of the activity board).
function Q.FromBoard(r)
    local g = r.data or {}
    local wanted = { TANK = g.tank or 0, HEALER = g.healer or 0, DAMAGER = g.dd or 0 }
    local open = wanted.TANK + wanted.HEALER + wanted.DAMAGER
    local size = type(g.size) == 'number' and g.size or nil
    return {
        source = 'ZENIAL', key = r.key, own = r.own == true, zenial = true, size = size,
        members = size and math.max(1, size - open) or nil, wanted = wanted,
        levelMin = g.min, levelMax = g.max, started = type(g.start) == 'number' and g.start or 0,
        contacted = type(r.application) == 'table', friends = 0, guildMates = 0,
    }
end

-- View of a public group (row of PublicLFG.lua). facts: { levelMin } of its activity, as far as known.
-- A public group has no upper level: the game asks for a lowest level only, what lies above is a suggestion.
function Q.FromPublic(row, facts)
    facts = facts or {}
    return {
        source = 'PUBLIC', key = row.key, own = false, zenial = row.zenial == true, size = row.size, members = row.members,
        wanted = row.remaining, levelMin = facts.levelMin,
        started = -(row.age or 0), gone = row.delisted == true, contacted = row.contacted == true,
        friends = row.friends or 0, guildMates = row.guildMates or 0,
    }
end

-- How a group fits: { tier, role, level, ready }.
--   role  WANTED: an open place for one of my roles · TAKEN: places are known, none for me · UNKNOWN
--   level true | false | nil (unknown); a view without an upper level fits from its lowest level on
--   ready the group is about to start: only my role is missing, or tank and healer are there
--   tier  BEST | GOOD | UNKNOWN | POOR | FULL
-- me = { roles = { TANK, HEALER, DAMAGER }, level = number }
function Q.Fit(view, me)
    local fit = { ready = false }
    local wanted = view.wanted
    local open = wanted and (wanted.TANK or 0) + (wanted.HEALER or 0) + (wanted.DAMAGER or 0) or nil
    if not wanted then
        fit.role = 'UNKNOWN'
    else
        fit.role = 'TAKEN'
        for _, role in ipairs(ROLES) do
            if me.roles[role] and (wanted[role] or 0) > 0 then
                fit.role = 'WANTED'
            end
        end
    end
    local level = me.level
    if type(level) == 'number' and type(view.levelMin) == 'number' then
        if type(view.levelMax) == 'number' then
            fit.level = level >= view.levelMin and level <= view.levelMax
        elseif view.levelMax == nil then
            fit.level = level >= view.levelMin
        end
    end
    local full = view.gone or (view.size ~= nil and view.members ~= nil and view.members >= view.size) or open == 0
    if full then
        fit.tier = 'FULL'
    elseif fit.level == false or fit.role == 'TAKEN' then
        fit.tier = 'POOR'
    elseif fit.role == 'UNKNOWN' then
        fit.tier = 'UNKNOWN'
    else
        fit.ready = open == 1 or ((wanted.TANK or 0) == 0 and (wanted.HEALER or 0) == 0)
        fit.tier = fit.ready and 'BEST' or 'GOOD'
    end
    return fit
end

-- Local filter "Only fitting": only groups that fit or might fit. The own group always stays.
function Q.Passes(view, fit, filters)
    if view.own then
        return true
    end
    if filters.fitting and (fit.tier == 'POOR' or fit.tier == 'FULL') then
        return false
    end
    return true
end

-- Order of two entries { view, fit }: true when a comes first.
function Q.Before(a, b)
    local va, vb = a.view, b.view
    if va.own ~= vb.own then
        return va.own
    end
    local ra, rb = RANK[a.fit.tier], RANK[b.fit.tier]
    if ra ~= rb then
        return ra < rb
    end
    if va.contacted ~= vb.contacted then
        return not va.contacted
    end
    if va.zenial ~= vb.zenial then
        return va.zenial
    end
    local ka, kb = va.friends + va.guildMates > 0, vb.friends + vb.guildMates > 0
    if ka ~= kb then
        return ka
    end
    local ma, mb = va.members or 0, vb.members or 0
    if ma ~= mb then
        return ma > mb
    end
    if va.started ~= vb.started then
        return va.started < vb.started
    end
    return va.key < vb.key
end

-- Sorts entries { view, fit, ... } in place, best first.
function Q.Sort(entries)
    table.sort(entries, Q.Before)
    return entries
end

return Q
