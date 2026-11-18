-- Group finder: groups of the public group search of the game inside the adventure browser.
--
-- One interface, two sources. ZENIAL groups come from the activity board and keep their workflow (apply,
-- withdraw, invite). Public groups come from PublicLFG.lua, live in memory only and are contacted through
-- their leader. This file adds what the finder needs for the second source: the card of a public group or
-- of a single player, the field that shows the state of the public search and starts it, the figures for
-- the tiles and the public section of the tabs without tiles. UXFinder.lua calls in at fixed places.
-- See _dev/addons/ZenialCommunity/PUBLIC-LFG-INTEGRATION-PLAN.md.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local C, P, M = Z.GroupFinderCatalog, Z.PublicLFG, Z.PublicLFGMap
if type(U) ~= 'table' or type(U.Finder) ~= 'table' or type(P) ~= 'table' or type(M) ~= 'table' then
    return
end

local F = U.Finder
local FP = {}
U.FinderPublic = FP

local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local VIEW_KIND = { dungeons = 'DUNGEON', raids = 'RAID', pvp = 'PVP', quests = 'QUEST', other = 'CUSTOM' }
local BAR_HEIGHT = 30
local FRESH = 120 -- a complete list of an instance younger than this is not searched again when the instance opens

local function tr(value)
    return Z.T(value)
end
local function paint(key, value)
    return K.Paint(key, value)
end
local function plural(one, many, n)
    return n == 1 and tr(one) or Z.T(many, n)
end

-- Whether the public group search takes part in the finder: the client has it and the player left it on.
function FP.Active()
    return P.Available() == true
end

-- Query of the open view: the activities of the open instance, otherwise everything the client offers in the
-- category of the tab. nil for views without a public counterpart.
function FP.Query()
    if F.activity then
        local e, ids = C.Get(F.activity), M.Activities(F.activity)
        if not e or not ids then
            return nil
        end
        return { category = M.Category(e.kind), activities = ids }
    end
    local kind = VIEW_KIND[F.view]
    local ids = kind and M.CategoryActivities(kind) or {}
    if #ids == 0 then
        return nil
    end
    return { category = M.Category(kind), activities = ids }
end

-- Rows and list facts of the open view.
local function listing()
    if F.activity then
        return P.Rows(F.activity)
    end
    local query = FP.Query()
    if not query then
        return {}, nil
    end
    return P.List(P.Signature(query))
end

-- How long a listing has been up, in the unit that fits.
local function listedFor(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then
        return Z.T('listed for %d s', seconds)
    elseif seconds < 3600 then
        return Z.T('listed for %d min', math.floor(seconds / 60))
    end
    return Z.T('listed for %d h', math.floor(seconds / 3600))
end

-- Clock time at which a list arrived.
local function asOf(receivedAt)
    local at = A.Now() - math.max(0, math.floor(A.Clock() - receivedAt))
    return type(date) == 'function' and date('%H:%M', at) or '?'
end

local function tally(rows)
    local groups, seekers = 0, 0
    for _, row in ipairs(rows) do
        if not row.delisted and not row.restricted then
            if row.solo then
                seekers = seekers + 1
            else
                groups = groups + 1
            end
        end
    end
    return groups, seekers
end

-- ---------------------------------------------------------------------------------------------
-- Search field: state of the public search and its only trigger
-- ---------------------------------------------------------------------------------------------
local REFUSED = {
    COMBAT = 'Not possible in combat.',
    LOCKDOWN = 'Not possible right now.',
    COOLDOWN = 'Possible again in a moment.',
    NO_ACTIVITY = 'The group search of the game offers nothing here.',
    NO_LANGUAGE = 'Choose at least one language.',
    BLOCKED = 'The game refused the search.',
}

-- Starts the public search for the open view. Runs from a click only.
function FP.Search()
    if not FP.Active() then
        return false
    end
    local query = FP.Query()
    local ok, reason = false, 'NO_ACTIVITY'
    if query then
        ok, reason = P.Search(query)
    end
    FP.refused = not ok and reason ~= 'BUSY' and { reason = reason, at = A.Clock() } or nil
    U.RefreshFinder()
    return ok
end

-- The player opened an instance with a click: search it once, unless a complete list of it is still fresh.
function FP.OnOpen(activity)
    if not FP.Active() or not M.Activities(activity) then
        return
    end
    local _, info = P.Rows(activity)
    if info and info.complete and A.Clock() - info.receivedAt <= FRESH then
        return
    end
    FP.refused = nil
    if P.Search({ category = M.Category(C.Get(activity).kind), activities = M.Activities(activity) }) then
        U.RefreshFinder()
    end
end

-- Text of the search field and whether a click may search.
function FP.Status()
    local state, query = P.State(), FP.Query()
    if state.phase == 'SEARCHING' then
        return tr('Searching public groups …'), false
    end
    local refused = FP.refused
    if refused and A.Clock() - refused.at < 6 and REFUSED[refused.reason] then
        return tr(REFUSED[refused.reason]), true
    end
    local current = query ~= nil and state.signature == P.Signature(query)
    if current and state.phase == 'TIMEOUT' then
        return tr('The group search did not answer. Try again.'), true
    elseif current and state.phase == 'FAILED' then
        return tr('The group search failed. Try again.'), true
    elseif current and state.phase == 'BLOCKED' then
        return tr('The game refused the search.'), true
    end
    local rows, info = listing()
    if not info then
        return tr(query and 'Load public groups' or 'The group search of the game offers nothing here.'), query ~= nil
    end
    local groups, seekers = tally(rows)
    local found = plural('1 group', '%d groups', groups) .. ' · ' .. plural('1 looking', '%d looking', seekers)
    -- A list that was cut off, or that was searched for more than this instance, is a sample.
    local head = (F.activity and not info.complete or not F.activity and info.truncated) and 'Public sample: %s' or 'Public: %s'
    return Z.T(head, found) .. ' · ' .. Z.T('as of %s', asOf(info.receivedAt)) .. ' · ' .. tr('refresh'), true
end

-- Lays the bar with the search field out below y and returns its height; 0 while the public search is off.
function FP.LayoutBar(y, width)
    local bar = FP.bar
    if not bar then
        return 0
    end
    if not FP.Active() or F.view == 'now' and not F.activity then
        bar:Hide()
        return 0
    end
    bar:ClearAllPoints()
    bar:SetPoint('TOPLEFT', 0, -y)
    bar:SetSize(width, BAR_HEIGHT - 6)
    local text, enabled = FP.Status()
    bar.field:SetText(text)
    bar.field:SetEnabled(enabled)
    bar.field:ClearAllPoints()
    bar.field:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, 0)
    bar:Show()
    return BAR_HEIGHT
end
function FP.HideBar()
    if FP.bar then
        FP.bar:Hide()
    end
end

-- Built once with the finder frame.
function FP.Create(frame)
    local bar = CreateFrame('Frame', nil, frame)
    bar.field = T.Button(bar, '', 400, 24, function()
        FP.Search()
    end, 'secondary')
    bar:Hide()
    FP.bar = bar
end

-- ---------------------------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------------------------
local function whisper(row)
    if not row.leader or not A.Whisper(row.leader) then
        U.Message(tr('Whisper is unavailable.'))
    end
end
local function invite(row)
    local ok, why = false, nil
    if row.leader then
        ok, why = A.InviteName(row.leader)
    end
    U.Message(ok and tr('Invitation sent.') or tr(why or 'Inviting is unavailable.'))
end

-- What the card of a public group or of a single player shows. Same shape as the description of a ZENIAL
-- card in UXFinder.lua; nothing here reads the activity board.
function FP.Describe(row, context)
    local d = { actions = {}, source = tr('Public'), sourceTone = 'neutral' }
    local class = row.leaderClass and L.ClassName(nil, row.leaderClass) or nil
    local hex = row.leaderClass and T.ClassColorHex and T.ClassColorHex(row.leaderClass)
    local who = row.leader or class or tr('Unknown player')
    who = hex and ('|cff' .. hex .. who .. '|r') or who
    local listed = row.age and listedFor(row.age + (A.Clock() - row.readAt)) or nil
    local gone = row.delisted == true
    local parts = {}
    if row.solo then
        d.glyph = 'members'
        d.title = who
        if context.named and row.activityName then
            parts[#parts + 1] = Z.T('Looking for: %s', row.activityName)
        end
        if row.leaderLevel then
            parts[#parts + 1] = Z.T('Level %d', row.leaderLevel)
        end
        if row.leader and class then
            parts[#parts + 1] = class
        end
        d.roleItems = {}
        for _, role in ipairs(ROLES) do
            if row.soloRoles and row.soloRoles[role] then
                d.roleItems[#d.roleItems + 1] = { role = role, text = Z.Locale.Role(role) }
            end
        end
        if #d.roleItems == 0 then
            d.roleItems, d.roles = nil, paint('dim', tr('Roles unknown'))
        end
        d.actions[1] = { text = tr('Invite'), enabled = not gone and row.leader ~= nil and A.GroupState().canInvite == true, click = function()
            invite(row)
        end }
        d.actions[2] = { text = tr('Whisper'), enabled = not gone and row.leader ~= nil, click = function()
            whisper(row)
        end }
    else
        d.title = context.named and row.activityName or who
        if context.named and row.activityName then
            parts[#parts + 1] = who
        end
        parts[#parts + 1] = row.size and Z.T('%d/%d players', row.members, row.size) or Z.T('%d players', row.members)
        if row.remaining then
            d.roleItems = {}
            for _, role in ipairs(ROLES) do
                local n = row.remaining[role] or 0
                if n > 0 then
                    d.roleItems[#d.roleItems + 1] = { role = role, text = n .. ' ' .. Z.Locale.Role(role) }
                end
            end
            if #d.roleItems == 0 then
                d.roleItems, d.roles = nil, paint('dim', tr('Group is full'))
            end
        else
            d.roles = paint('dim', tr('Role needs unknown'))
        end
        if row.size and row.members >= row.size then
            d.badge, d.tone = tr('Full'), 'neutral'
        end
        d.actions[1] = { text = tr('Whisper'), enabled = not gone and row.leader ~= nil, click = function()
            whisper(row)
        end }
    end
    if listed then
        parts[#parts + 1] = listed
    end
    d.meta = table.concat(parts, ' · ')
    d.note = row.comment
    if gone then
        d.badge, d.tone = tr('No longer listed'), 'neutral'
    end
    return d
end

-- A ZENIAL card names its source too while public groups stand beside it.
function FP.Mark(d, r)
    if r and r.kind == 'LIVE' and FP.Active() then
        d.source, d.sourceTone = 'ZENIAL', 'gold'
    end
    return d
end

-- Board rows of one instance followed by its public rows: groups, or single players for sort 'seekers'.
function FP.Merge(rows, activity, sort)
    if not FP.Active() then
        return rows
    end
    local out = {}
    for index, r in ipairs(rows) do
        out[index] = r
    end
    for _, row in ipairs((P.Rows(activity))) do
        if (row.solo == true) == (sort == 'seekers') and not row.restricted then
            out[#out + 1] = row
        end
    end
    return out
end

-- Public rows of the open tab without tiles (questing, miscellaneous): rows, and whether a list was loaded.
-- nil while the public search is off.
function FP.CategoryRows()
    if not FP.Active() or F.activity or not FP.Query() then
        return nil
    end
    local rows, info = listing()
    local out = {}
    for _, row in ipairs(rows) do
        if not row.restricted then
            out[#out + 1] = row
        end
    end
    return out, info ~= nil
end

-- ---------------------------------------------------------------------------------------------
-- Tiles and the head of an instance
-- ---------------------------------------------------------------------------------------------
-- Public figures of one instance: { groups, seekers, capped } or nil. Never added to the community figures.
function FP.Figures(activity)
    if not FP.Active() then
        return nil
    end
    return P.Counts()[activity]
end

-- Caption of the public mark on a tile, nil when there is nothing to show.
function FP.TileText(activity)
    local figures = FP.Figures(activity)
    if not figures or figures.groups == 0 then
        return nil
    end
    return Z.T(figures.capped and '%d+ public' or '%d public', figures.groups)
end

-- Line for the tooltip of a tile.
function FP.TileHint(activity)
    local figures = FP.Figures(activity)
    if not figures then
        return nil
    end
    local found = plural('1 group', '%d groups', figures.groups) .. ' · ' .. plural('1 looking', '%d looking', figures.seekers)
    return Z.T(figures.capped and 'Public sample: %s' or 'Public: %s', found)
end

return FP
