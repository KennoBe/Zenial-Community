local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local S = U.Shared

-- Derived, read-only grouping of the character-based member model by declared
-- main character. Nothing here is stored, published or sent: S.memberEntries()
-- and S.memberModel.byKey stay the source for every action, note, favourite
-- and contact. A group only projects existing entries.
--
-- Links come from participating addons (own account data, or a peer's fresh
-- linkMain as accepted by Z.ConfirmedMain: same faction, at most 7 days old).
-- They are declared, never verified. Characters are only joined through such a
-- link inside the same world and faction, never through equal names, classes,
-- guilds or community aliases.
--
-- groupKey is "G:<world>@<faction>@<main identity>" and is never a member key;
-- mainKey is the main's scope key, which need not belong to any known member
-- (virtual anchor: mainMember is nil, no class, level, presence or profile is
-- invented for it).

local function scopeOf(key)
    if type(key) ~= 'string' then
        return nil
    end
    local realm, faction, name = key:match('^([^@]+)@([^@]+)@(.+)$')
    if not realm then
        return nil
    end
    return realm, faction, name
end

-- Declared main of one member entry: { mainKey, display, version } or nil.
local function claimOf(m, ownMain, ownVersion)
    local realm, faction, name = scopeOf(m.key)
    if not realm then
        return nil
    end
    local declared, version
    if m.own then
        declared, version = ownMain, ownVersion
    else
        local s = m.data
        if not s or type(s.faction) ~= 'string' or string.lower(s.faction) ~= faction then
            return nil
        end
        declared, version = m.main, L.Int(s.linkVersion, 0, 2147483646) and s.linkVersion or 0
    end
    local id, display = L.Identity(declared)
    if not id or display == '' then
        return nil
    end
    return { mainKey = realm .. '@' .. faction .. '@' .. id, display = display, version = version, self = id == name }
end

-- The main's own full profile lists its alts (at most 10). It only counts when
-- no newer public bundle replaced the link fields after that profile.
local function altsContradict(mainEntry, claimer, claim)
    if not mainEntry or mainEntry.own or not claim then
        return false
    end
    local s = mainEntry.data
    local peer = Z.db.peers[mainEntry.key]
    if not s or s.publicOnly or type(s.linkAlts) ~= 'table' or #s.linkAlts == 0 or #s.linkAlts >= 10 then
        return false
    end
    if peer and (peer.publicAppliedRev or 0) > (s.rev or 0) then
        return false
    end
    if (L.Int(s.linkVersion, 0, 2147483646) and s.linkVersion or 0) < claim.version then
        return false
    end
    local wanted = L.Identity(claimer.target)
    for _, alt in ipairs(s.linkAlts) do
        if L.Identity(alt) == wanted then
            return false
        end
    end
    return true
end

local function build(entries)
    local blocked = Z.db.blocked or {}
    local ownMain = Z.PublicLinks().main
    local ownVersion = Z.account and Z.account.linkVersion or 0
    local byKey, claims, reasons = {}, {}, {}
    for _, m in ipairs(entries) do
        byKey[m.key] = m
    end
    -- 1. Raw declarations; blocked characters never join or anchor a group.
    for _, m in ipairs(entries) do
        if blocked[m.key] then
            reasons[m.key] = 'blocked'
        else
            local c = claimOf(m, ownMain, ownVersion)
            if c and not c.self then
                if blocked[c.mainKey] then
                    reasons[m.key] = 'blocked'
                else
                    claims[m.key] = c
                end
            end
        end
    end
    -- 2. The main's own fresh alt list contradicts a claim.
    for key, c in pairs(claims) do
        if not byKey[key].own and altsContradict(byKey[c.mainKey], byKey[key], c) then
            claims[key] = nil
            reasons[key] = 'conflict'
        end
    end
    -- 3. Chains and cycles (A -> X while X -> Y). The account-wide link version
    -- decides: an equal or newer declaration of X wins over A, a strictly newer
    -- claim to X demotes X's own link. Both are decided on the same input, so
    -- the result does not depend on iteration order; an equal-version cycle
    -- drops both links.
    local rejected, demoted = {}, {}
    for key, c in pairs(claims) do
        local target = claims[c.mainKey]
        if target and c.mainKey ~= key then
            if target.version >= c.version and not byKey[key].own then
                rejected[key] = true
            elseif c.version > target.version and not byKey[c.mainKey].own then
                demoted[c.mainKey] = true
            end
        end
    end
    for key in pairs(rejected) do
        claims[key] = nil
        reasons[key] = 'conflict'
    end
    for key in pairs(demoted) do
        if claims[key] then
            claims[key] = nil
            reasons[key] = 'conflict'
        end
    end

    local model = { groups = {}, byGroup = {}, groupOf = {}, reasons = reasons, identities = 0, characters = #entries }
    local function groupFor(scopeKey)
        local gk = 'G:' .. scopeKey
        local g = model.byGroup[gk]
        if not g then
            g = { groupKey = gk, mainKey = scopeKey, members = {}, activeMembers = {}, online = false, lastSeen = 0, isOwn = false }
            model.byGroup[gk] = g
            model.groups[#model.groups + 1] = g
        end
        return g
    end
    for _, m in ipairs(entries) do
        local c = claims[m.key]
        local g = groupFor(c and c.mainKey or m.key)
        g.members[#g.members + 1] = m
        if c and (not g.display or m.key < g.displayFrom) then
            g.display, g.displayFrom = c.display, m.key
        end
        g.blocked = g.blocked or blocked[m.key] == true or nil
        model.groupOf[m.key] = g
    end
    for _, g in ipairs(model.groups) do
        local main = byKey[g.mainKey]
        g.mainMember = main and model.groupOf[main.key] == g and main or nil
        g.virtual = g.mainMember == nil
        g.mainName = g.mainMember and g.mainMember.target or g.display
        g.display, g.displayFrom = nil, nil
        g.linked = #g.members > 1 or g.virtual
        -- Safe fallback: a rejected, blocked or contradictory link leaves a single group.
        g.fallback = not g.linked and reasons[g.members[1].key] or nil
        -- Declared by participating addons; never presented as verified.
        g.declared = g.linked or nil
        table.sort(g.members, function(a, b)
            if (a == g.mainMember) ~= (b == g.mainMember) then
                return a == g.mainMember
            end
            local x, y = string.lower(a.target or ''), string.lower(b.target or '')
            if x ~= y then
                return x < y
            end
            return a.key < b.key
        end)
        g.memberKeys = {}
        for _, m in ipairs(g.members) do
            g.memberKeys[#g.memberKeys + 1] = m.key
            g.isOwn = g.isOwn or m.own == true
            g.lastSeen = math.max(g.lastSeen, m.seen or 0)
            if m.online then
                g.activeMembers[#g.activeMembers + 1] = m
            end
        end
        -- All online candidates stay; the preferred one is the freshest presence
        -- (own character first), then the main, then the member key.
        table.sort(g.activeMembers, function(a, b)
            local x, y = a.own and math.huge or a.seen or 0, b.own and math.huge or b.seen or 0
            if x ~= y then
                return x > y
            end
            if (a == g.mainMember) ~= (b == g.mainMember) then
                return a == g.mainMember
            end
            return a.key < b.key
        end)
        g.activeMember = g.activeMembers[1]
        g.online = g.activeMember ~= nil
        g.mainOnline = g.mainMember ~= nil and g.mainMember.online == true
        if not g.blocked then
            model.identities = model.identities + 1
        end
    end
    -- Own known characters of this world and faction from local account data.
    -- Local only: the list is never published and holds no gold or inventory.
    local ownGroup = model.groupOf[Z.me.key]
    if ownGroup and Z.account then
        local O = Z.AccountOverview
        local list = {}
        for key, c in pairs(Z.account.characters or {}) do
            if type(c) == 'table' and c.realm == Z.me.realm and c.faction == Z.me.faction and not (O and O.IsHidden and O.IsHidden(key)) then
                list[#list + 1] = {
                    key = key,
                    target = c.target,
                    class = c.class,
                    level = c.level,
                    lastLogin = c.lastLogin,
                    current = key == Z.accountCharacterKey,
                    main = key == Z.account.mainKey,
                }
            end
        end
        table.sort(list, function(a, b)
            if a.main ~= b.main then
                return a.main
            end
            return string.lower(a.target or '') < string.lower(b.target or '')
        end)
        ownGroup.ownCharacters = list
    end
    table.sort(model.groups, function(a, b)
        return a.groupKey < b.groupKey
    end)
    return model
end

-- Cached; rebuilt only when the member model, the own main/link or the hidden
-- own characters change. Presence timeouts, blocking and aging links already
-- rebuild S.memberModel through its revision and deadline.
local function memberGroups()
    local entries = S.memberEntries()
    local O = Z.AccountOverview
    local a = Z.account or {}
    local cache = S.memberGroupModel
    if
        not cache
        or cache.source ~= S.memberModel
        or cache.db ~= Z.db
        or cache.linkVersion ~= a.linkVersion
        or cache.mainKey ~= a.mainKey
        or cache.hiddenRevision ~= (O and O.revision)
    then
        cache = build(entries)
        cache.source, cache.db, cache.linkVersion, cache.mainKey, cache.hiddenRevision =
            S.memberModel, Z.db, a.linkVersion, a.mainKey, O and O.revision
        S.memberGroupModel = cache
    end
    return cache.groups, cache
end
S.memberGroups = memberGroups
function S.memberGroupFor(memberKey)
    local _, model = memberGroups()
    return model.groupOf[memberKey]
end
