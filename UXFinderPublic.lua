-- Group finder: groups of the public group search of the game inside the adventure browser.
--
-- One interface, two sources. ZENIAL groups come from the activity board and keep their workflow (apply,
-- withdraw, invite). Public groups come from PublicLFG.lua, live in memory only and are contacted through
-- their leader. This file adds what the finder needs for the second source:
--   - the card of a public group or of a single player,
--   - the bar below the tool row: source choice, the two local filters, "More filters" (own roles and the
--     languages of the public search) and the field that shows the state of the public search and starts it,
--   - merging both sources of one instance into one list, best fitting first,
--   - the figures for the tiles and the public section of the tabs without tiles.
-- UXFinder.lua calls in at fixed places. Nothing here searches by itself: a search starts from a click on
-- the search field or on a tile, never from a filter, a refresh or a language change.
-- See _dev/addons/ZenialCommunity/PUBLIC-LFG-INTEGRATION-PLAN.md.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local C, P, M, Q, X, Y = Z.GroupFinderCatalog, Z.PublicLFG, Z.PublicLFGMap, Z.PublicLFGMatch, Z.PublicLFGContact, Z.PublicLFGListing
if type(U) ~= 'table' or type(U.Finder) ~= 'table' or type(P) ~= 'table' or type(M) ~= 'table' or type(Q) ~= 'table' or type(X) ~= 'table' then
    return
end

local F = U.Finder
local FP = { filters = { fitting = false, open = false }, fits = {}, marks = {} }
U.FinderPublic = FP

local ROLES = Q.ROLES
local VIEW_KIND = { dungeons = 'DUNGEON', raids = 'RAID', pvp = 'PVP', quests = 'QUEST', other = 'CUSTOM' }
local SOURCES = { ALL = true, ZENIAL = true, PUBLIC = true }
local ROW = 30
local FRESH = 120 -- a complete list of an instance younger than this is not searched again when the instance opens
local TIER_LABEL = {
    BEST = { 'Very fitting', 'success' }, GOOD = { 'Fitting', 'info' }, UNKNOWN = { 'Role unknown', 'neutral' }, FULL = { 'Full', 'neutral' },
}

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

-- ---------------------------------------------------------------------------------------------
-- Choices: source, languages, roles
-- ---------------------------------------------------------------------------------------------
-- Which groups are shown: ALL, ZENIAL or PUBLIC. Kept per character.
function FP.Source()
    local source = Z.uiCharacter and Z.uiCharacter.finderSource
    return FP.Active() and SOURCES[source] and source or 'ALL'
end
function FP.SetSource(source)
    if Z.uiCharacter and SOURCES[source] then
        Z.uiCharacter.finderSource = source
    end
    U.RefreshFinder()
end

-- Languages of the public search: { mode = 'DEFAULT' | 'ALL' | 'CUSTOM', codes = { deDE = true } }. Kept for the account.
function FP.Languages()
    local saved = Z.ui and Z.ui.finderLanguages
    if type(saved) ~= 'table' then
        return { mode = 'DEFAULT', codes = {} }
    end
    return { mode = (saved.mode == 'ALL' or saved.mode == 'CUSTOM') and saved.mode or 'DEFAULT', codes = type(saved.codes) == 'table' and saved.codes or {} }
end
-- Changing the languages never searches: the search field then says that the filter changed.
function FP.SetLanguageMode(mode)
    if Z.ui then
        local languages = FP.Languages()
        languages.mode = mode
        Z.ui.finderLanguages = languages
    end
    U.RefreshFinder()
end
function FP.ToggleLanguage(code)
    if Z.ui then
        local languages = FP.Languages()
        languages.codes[code] = not languages.codes[code] or nil
        Z.ui.finderLanguages = languages
    end
    U.RefreshFinder()
end
function FP.ToggleRole(role)
    local roles = Q.OwnRoles()
    roles[role] = not roles[role]
    Q.SetOwnRoles(roles)
    U.RefreshFinder()
end

-- Query of the open view: the activities of the open instance, otherwise everything the client offers in the
-- category of the tab, with the chosen languages. nil for views without a public counterpart.
function FP.Query()
    local category, ids
    if F.activity then
        local e = C.Get(F.activity)
        category, ids = e and M.Category(e.kind), M.Activities(F.activity)
    else
        local kind = VIEW_KIND[F.view]
        category, ids = kind and M.Category(kind), kind and M.CategoryActivities(kind) or nil
    end
    if not category or not ids or #ids == 0 then
        return nil
    end
    local languages = FP.Languages()
    return { category = category, activities = ids, languageMode = languages.mode, languages = languages.codes }
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

-- The part of a signature that names the languages.
local function languagePart(signature)
    return type(signature) == 'string' and signature:match('|([^|]*|[^|]*)$') or nil
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

-- The player opened an instance with a click: search it once, unless a complete list of it is still fresh
-- or only ZENIAL groups are shown.
function FP.OnOpen()
    if not FP.Active() or FP.Source() == 'ZENIAL' then
        return
    end
    local query = FP.Query()
    if not F.activity or not query then
        return
    end
    local _, info = P.Rows(F.activity)
    if info and info.complete and A.Clock() - info.receivedAt <= FRESH and languagePart(info.signature) == languagePart(P.Signature(query)) then
        return
    end
    FP.refused = nil
    if P.Search(query) then
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
    local signature = query and P.Signature(query)
    local current = signature ~= nil and state.signature == signature
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
    local changed = languagePart(info.signature) ~= languagePart(signature)
    return Z.T(head, found) .. ' · ' .. (changed and tr('filter changed') or Z.T('as of %s', asOf(info.receivedAt))) .. ' · ' .. tr('refresh'), true
end

-- ---------------------------------------------------------------------------------------------
-- Bar: source choice, local filters, "More filters" and the search field
-- ---------------------------------------------------------------------------------------------
-- What "More filters" is set to, in words.
function FP.Summary()
    local roles, origin = Q.OwnRoles()
    local names = {}
    for _, role in ipairs(ROLES) do
        if roles[role] then
            names[#names + 1] = Z.Locale.Role(role)
        end
    end
    local languages, spoken = FP.Languages(), tr('Game default')
    if languages.mode == 'ALL' then
        spoken = tr('all languages')
    elseif languages.mode == 'CUSTOM' then
        local labels = {}
        for _, language in ipairs(P.Languages()) do
            if languages.codes[language.code] then
                labels[#labels + 1] = language.label
            end
        end
        spoken = #labels > 0 and table.concat(labels, ', ') or tr('no language chosen')
    end
    return Z.T(origin == 'CHOSEN' and 'Roles: %s' or 'Roles (automatic): %s', table.concat(names, ', ')) .. ' · ' .. Z.T('Languages: %s', spoken)
end

local function layoutPanel()
    local panel = FP.panel
    local roles = Q.OwnRoles()
    for _, chip in ipairs(panel.roles) do
        chip:SetChecked(roles[chip.zenialRole] == true)
    end
    local languages = FP.Languages()
    panel.mode:Select(languages.mode)
    local offered = P.Languages()
    for index, language in ipairs(offered) do
        local chip = panel.languages[index]
        if not chip then
            chip = T.Chip(panel, '', 96, 22, function(self)
                FP.ToggleLanguage(self.zenialCode)
            end)
            panel.languages[index] = chip
        end
        chip.zenialCode = language.code
        chip.text:SetText(language.label)
        chip:ClearAllPoints()
        chip:SetPoint('TOPLEFT', 12 + ((index - 1) % 4) * 102, -(128 + math.floor((index - 1) / 4) * 28))
        chip:SetChecked(languages.mode == 'CUSTOM' and languages.codes[language.code] == true)
        chip:SetEnabled(languages.mode == 'CUSTOM')
        chip:Show()
    end
    for index = #offered + 1, #panel.languages do
        panel.languages[index]:Hide()
    end
    panel:SetSize(432, 136 + math.max(1, math.ceil(#offered / 4)) * 28)
end

-- Lays the bar out below y and returns its height; 0 while the public search is off.
-- detailed: the overview of an instance, which also has the two local filters and one more line.
function FP.LayoutBar(y, width, detailed)
    local bar = FP.bar
    if not bar then
        return 0
    end
    if not FP.Active() or (F.view == 'now' and not detailed) then
        FP.HideBar()
        return 0
    end
    local source = FP.Source()
    local public = source ~= 'ZENIAL'
    bar:ClearAllPoints()
    bar:SetPoint('TOPLEFT', 0, -y)
    bar.source:ClearAllPoints()
    bar.source:SetPoint('TOPLEFT', 0, 0)
    bar.source:Select(source)
    local x = 216
    for _, chip in ipairs(bar.chips) do
        chip:SetShown(detailed == true)
        if detailed then
            chip:ClearAllPoints()
            chip:SetPoint('TOPLEFT', x, -2)
            chip:SetChecked(FP.filters[chip.zenialFilter] == true)
            x = x + chip.zenialWidth + 6
        end
    end
    bar.more:ClearAllPoints()
    bar.more:SetPoint('TOPLEFT', x, -1)
    T.SetSelected(bar.more, FP.panelOpen == true)
    local text, enabled = FP.Status()
    bar.field:SetShown(public)
    bar.field:SetText(text)
    bar.field:SetEnabled(enabled)
    bar.field:ClearAllPoints()
    bar.summary:SetShown(detailed == true)
    bar.assist:SetShown(detailed == true)
    local rows = 1
    if detailed then
        -- Second line: the assistant on the left, what "More filters" is set to beside it where there is
        -- room, the search field on the right.
        rows = 2
        local candidates = #FP.Candidates()
        bar.assist:ClearAllPoints()
        bar.assist:SetPoint('TOPLEFT', 0, -ROW)
        bar.assist:SetText(Z.T('Contact fitting groups (%d)', candidates))
        bar.assist:SetEnabled(candidates > 0)
        local room = width - 236 - (public and 352 or 4)
        bar.summary:SetShown(room >= 120)
        bar.summary:ClearAllPoints()
        bar.summary:SetPoint('TOPLEFT', 238, -(ROW + 5))
        bar.summary:SetText(FP.Summary())
        bar.summary:SetWidth(math.max(60, room))
        bar.summary:SetHeight(14)
        bar.field:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -ROW)
    else
        bar.field:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -1)
    end
    bar:SetSize(width, rows * ROW - 6)
    bar:Show()
    local panel = FP.panel
    panel:SetShown(FP.panelOpen == true)
    if FP.panelOpen then
        -- Right-aligned with the bar, so the panel never leaves the window.
        panel:ClearAllPoints()
        panel:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -(ROW - 2))
        layoutPanel()
    end
    return rows * ROW
end
function FP.HideBar()
    if FP.bar then
        FP.bar:Hide()
        FP.panel:Hide()
    end
end

-- Built once with the finder frame.
function FP.Create(frame)
    local bar = CreateFrame('Frame', nil, frame)
    bar.source = K.Segmented(bar, { { key = 'ALL', label = tr('All') }, { key = 'ZENIAL', label = 'ZENIAL' }, { key = 'PUBLIC', label = tr('Public') } }, function(key)
        FP.SetSource(key)
    end)
    bar.source:SetSegmentWidth(70)
    bar.chips = {}
    for _, spec in ipairs({ { 'fitting', 'Only fitting', 108 }, { 'open', 'Free places', 104 } }) do
        local chip = T.Chip(bar, tr(spec[2]), spec[3], 22, function(self)
            FP.filters[spec[1]] = self:GetChecked() and true or false
            U.RefreshFinder()
        end)
        chip.zenialFilter, chip.zenialWidth = spec[1], spec[3]
        bar.chips[#bar.chips + 1] = chip
    end
    bar.more = T.Button(bar, tr('More filters'), 120, 24, function()
        FP.panelOpen = not FP.panelOpen
        U.RefreshFinder()
    end, 'secondary')
    bar.assist = T.Button(bar, '', 230, 24, function()
        if U.FinderAssistant then
            U.FinderAssistant.Open()
        end
    end, 'secondary')
    bar.summary = K.Text(bar, '', 'caption', 'dim')
    if bar.summary.SetWordWrap then
        bar.summary:SetWordWrap(false)
    end
    bar.field = T.Button(bar, '', 340, 24, function()
        FP.Search()
    end, 'secondary')
    bar:Hide()
    FP.bar = bar

    -- "More filters": a small panel over the lists, so opening it moves nothing.
    local panel = CreateFrame('Frame', nil, frame)
    if panel.SetFrameLevel and frame.GetFrameLevel then
        panel:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
    end
    panel:EnableMouse(true)
    panel.fill = panel:CreateTexture(nil, 'BACKGROUND')
    panel.fill:SetAllPoints()
    T.Tint(panel.fill, 'SetColorTexture', 'panelRaised')
    panel.edges = T.Edges(panel, 'BORDER')
    T.TintEdges(panel.edges, 'goldDim')
    panel.rolesLabel = K.Text(panel, tr('My roles'), 'overline', 'goldDim')
    panel.rolesLabel:SetPoint('TOPLEFT', 12, -12)
    panel.roles = {}
    for index, role in ipairs(ROLES) do
        local chip = T.Chip(panel, Z.Locale.Role(role), 96, 22, function()
            FP.ToggleRole(role)
        end)
        chip.zenialRole = role
        chip:SetPoint('TOPLEFT', 12 + (index - 1) * 102, -30)
        panel.roles[index] = chip
    end
    panel.languagesLabel = K.Text(panel, tr('Languages of the public search'), 'overline', 'goldDim')
    panel.languagesLabel:SetPoint('TOPLEFT', 12, -68)
    panel.mode = K.Segmented(panel, { { key = 'DEFAULT', label = tr('Game default') }, { key = 'ALL', label = tr('All') }, { key = 'CUSTOM', label = tr('Selection') } }, function(key)
        FP.SetLanguageMode(key)
    end)
    panel.mode:SetSegmentWidth(120)
    panel.mode:SetPoint('TOPLEFT', 12, -88)
    panel.languages = {}
    panel:Hide()
    FP.panel = panel
end

-- ---------------------------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------------------------
local REASON_CONTACT = {
    LOCKED = 'You wrote to this leader a short while ago.',
    GONE = 'This listing is no longer available.',
    NO_LEADER = 'The name of the leader is not known yet.',
    UNAVAILABLE = 'Whisper is unavailable.',
}
local CONTACT_BADGE = { OPENED = { 'Chat opened', 'info' }, SENT = { 'Message sent', 'success' }, JOINED = { 'In the group', 'success' } }

-- The player with the roles the finder looks with, for fit and for the message.
function FP.Me()
    return { roles = Q.OwnRoles(), level = tonumber(Z.me and Z.me.level) }
end

-- The message for a row: to the leader of a group, or to a single player with the name of the activity.
function FP.Message(row)
    local me = FP.Me()
    me.activity = F.activity and Z.Locale.Activity(F.activity) or row.activityName
    return X.Template(X.Language(FP.Languages()), row.solo and 'solo' or 'group', me)
end

-- Opens the chat box for the leader with the message in it. The player sends it.
function FP.Contact(row, text)
    local ok, reason = X.Prepare(row, text or FP.Message(row))
    U.Message(tr(ok and 'The chat box is ready. Press Enter to send.' or REASON_CONTACT[reason] or 'Whisper is unavailable.'))
    U.RefreshFinder()
    return ok, reason
end
local function whisper(row)
    FP.Contact(row)
end
local function invite(row)
    local ok, why = false, nil
    if row.leader then
        ok, why = A.InviteName(row.leader)
    end
    U.Message(ok and tr('Invitation sent.') or tr(why or 'Inviting is unavailable.'))
end

local function tierBadge(d, fit)
    local label = fit and TIER_LABEL[fit.tier]
    if label then
        d.badge, d.tone = tr(label[1]), label[2]
    end
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
    local mark = FP.marks[row.key]
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
        d.actions[2] = { text = tr('Whisper'), enabled = X.CanContact(row) == true, click = function()
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
        tierBadge(d, FP.fits[row.key])
        d.actions[1] = { text = tr('Whisper'), enabled = X.CanContact(row) == true, click = function()
            whisper(row)
        end }
    end
    -- What is known about a contact with this leader replaces the fit label.
    local contact = CONTACT_BADGE[X.State(row)]
    if contact then
        d.badge, d.tone = tr(contact[1]), contact[2]
    end
    if mark and mark.zenial then
        parts[#parts + 1] = paint('goldBright', tr('ZENIAL member'))
    end
    if (row.friends or 0) > 0 then
        parts[#parts + 1] = paint('goldBright', tr('Friend in the group'))
    elseif (row.guildMates or 0) > 0 then
        parts[#parts + 1] = paint('goldBright', tr('Guild member in the group'))
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

-- A ZENIAL card names its source while public groups stand beside it, and how well the group fits where the
-- card has nothing more important to say.
function FP.Mark(d, r)
    if not r or r.kind ~= 'LIVE' or not FP.Active() then
        return d
    end
    d.source, d.sourceTone = 'ZENIAL', 'gold'
    local fit = FP.fits[r.key]
    if fit and not r.own and (d.badge == nil or d.badge == tr('New') or d.badge == tr('Full')) then
        d.badge, d.tone = nil, nil
        tierBadge(d, fit)
    end
    return d
end

-- The catalogue key of a known ZENIAL member behind a character name, nil for everybody else.
local function memberKey(name)
    local key = name and Z.ResolvePeerKey and Z.ResolvePeerKey(name)
    if key and Z.db and (Z.db.peers[key] or Z.db.contacts[key]) then
        return key
    end
    return nil
end

-- The rows of one instance from both sources as one list.
-- sort 'groups': ZENIAL groups and public groups, filtered by source and by the local filters, best fitting
-- first. A group that a ZENIAL member also listed publicly is shown once, as the ZENIAL group.
-- sort 'seekers': players looking for a group, ZENIAL first.
-- While the public search is off the board rows come back unchanged.
-- Entries { row, view, fit, zenial } of one instance from both sources, in the order of the lists.
local function collect(rows, activity, sort)
    local source = FP.Source()
    local e = C.Get(activity)
    local me = FP.Me()
    local entries, owners = {}, {}
    for _, r in ipairs(rows) do
        owners[r.owner] = true
        if r.own or source ~= 'PUBLIC' then
            local view = Q.FromBoard(r)
            entries[#entries + 1] = { row = r, view = view, fit = Q.Fit(view, me), zenial = true }
        end
    end
    if source ~= 'ZENIAL' then
        for _, row in ipairs((P.Rows(activity))) do
            local key = memberKey(row.leader)
            if (row.solo == true) == (sort == 'seekers') and not row.restricted and not (key and owners[key]) then
                local view = Q.FromPublic(row, e and { levelMin = e.min, levelMax = e.max })
                view.zenial, view.contacted = key ~= nil, X.Contacted(row)
                FP.marks[row.key] = { zenial = key ~= nil }
                entries[#entries + 1] = { row = row, view = view, fit = Q.Fit(view, me), zenial = false }
            end
        end
    end
    if sort == 'groups' then
        Q.Sort(entries)
    end
    return entries
end

-- Groups of the open instance the assistant may offer: they fit or might fit, are not the player's own, were
-- not contacted yet and can be contacted right now. Best first; the local filters do not apply.
function FP.Candidates()
    local out = {}
    if not FP.Active() or not F.activity then
        return out
    end
    local stats = F.snapshot and F.snapshot.by[F.activity]
    for _, entry in ipairs(collect(stats and stats.rows.groups or {}, F.activity, 'groups')) do
        local tier = entry.fit.tier
        if not entry.view.own and not entry.view.contacted and (tier == 'BEST' or tier == 'GOOD' or tier == 'UNKNOWN') then
            local ok
            if entry.zenial then
                ok = entry.fit.role == 'WANTED' and U.ActivityActionState(entry.row).join == true
            else
                ok = X.CanContact(entry.row) == true
            end
            if ok then
                out[#out + 1] = entry
            end
        end
    end
    return out
end

function FP.Merge(rows, activity, sort)
    if not FP.Active() then
        return rows
    end
    local entries = collect(rows, activity, sort)
    local out = {}
    if sort == 'groups' then
        for _, entry in ipairs(entries) do
            if Q.Passes(entry.view, entry.fit, FP.filters) then
                FP.fits[entry.view.key] = entry.fit
                out[#out + 1] = entry.row
            end
        end
    else
        for _, entry in ipairs(entries) do
            out[#out + 1] = entry.row
        end
    end
    return out
end

-- Called at the start of every refresh: what was noted about the rows of the last one is forgotten.
function FP.Begin()
    FP.fits, FP.marks = {}, {}
end

-- Public rows of the open tab without tiles (questing, miscellaneous): rows, and whether a list was loaded.
-- nil while the public search is off or only ZENIAL groups are shown.
function FP.CategoryRows()
    if not FP.Active() or FP.Source() == 'ZENIAL' or F.activity or not FP.Query() then
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
-- The player's own public listing
-- ---------------------------------------------------------------------------------------------
local REASON_LISTING = {
    NO_ACTIVITY = 'The group search of the game does not know this activity.',
    TOO_MANY = 'These are too many activities for one public listing.',
    NOT_LEADER = 'Only the leader can list the group publicly.',
    GROUP_FULL = 'Your group is already full.',
    COMBAT = 'Not possible in combat.',
    LOCKDOWN = 'Not possible right now.',
    BLOCKED = 'The game refused the public listing.',
    FAILED = 'The public listing failed.',
}

-- Whether the player wants own groups and searches listed publicly too. Kept per character, off at first.
function FP.ListsPublicly()
    return Z.uiCharacter ~= nil and Z.uiCharacter.finderListPublic == true
end

local function listingMessage(ok, reason, done)
    U.Message(tr(ok and done or REASON_LISTING[reason] or 'The public listing is unavailable.'))
end

-- The switch in the status line of the own group or search. Runs from a click.
function FP.ToggleListing()
    if not Y or not Y.Available() then
        return
    end
    local state = Y.State()
    if state.phase == 'PENDING' then
        return
    end
    if state.phase == 'LISTED' and state.matches then
        local ok, reason = Y.Remove()
        if ok and Z.uiCharacter then
            Z.uiCharacter.finderListPublic = false
        end
        listingMessage(ok, reason, 'Your public listing was removed.')
    else
        local ok, reason = Y.Publish(Z.db.lfg[1])
        if ok and Z.uiCharacter then
            Z.uiCharacter.finderListPublic = true
        end
        listingMessage(ok, reason, 'Listed publicly. Your note is not shown there.')
    end
    U.RefreshFinder()
end

-- After the player changed the own group or search with a click: the public listing follows. A new or
-- changed record is listed when the player chose that; a closed record takes a listing made here with it.
-- Never called from a timer or an event, because the client takes these calls only from a click.
function FP.SyncListing()
    if not Y or not Y.Available() then
        return
    end
    local group, state = Z.db and Z.db.lfg[1], Y.State()
    if not group then
        if state.own and (state.phase == 'LISTED' or state.phase == 'PENDING') then
            Y.Remove()
        end
        return
    end
    if FP.ListsPublicly() and not (state.phase == 'LISTED' and state.matches) and state.phase ~= 'PENDING' then
        local ok, reason = Y.Publish(group)
        if not ok and reason ~= 'NO_ACTIVITY' then
            listingMessage(false, reason)
        end
    end
end

local function listingTooltip(chip)
    if not GameTooltip or not GameTooltip.SetOwner then
        return
    end
    GameTooltip:SetOwner(chip, 'ANCHOR_BOTTOM')
    GameTooltip:AddLine(tr('Public listing'), 1, 0.85, 0.42)
    GameTooltip:AddLine(tr('Others find your group in the group search of the game and whisper you. Your note is not shown there.'), 0.78, 0.8, 0.85, true)
    if A.GroupState().total <= 1 then
        GameTooltip:AddLine(tr('Without a group you appear there as a single player.'), 0.78, 0.8, 0.85, true)
    end
    GameTooltip:AddLine(tr('The game ends a public listing after 30 minutes.'), 0.5, 0.52, 0.58, true)
    GameTooltip:Show()
end

-- Places the switch in the status line of the own group or search, left of its buttons. Returns the room
-- now taken on the right.
function FP.LayoutListing(status, right, record)
    local chip = FP.listing
    if not chip then
        chip = T.Chip(status, '', 150, 24, function()
            FP.ToggleListing()
        end)
        chip:HookScript('OnEnter', listingTooltip)
        chip:HookScript('OnLeave', function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
        FP.listing = chip
    end
    if not record or not Y or not Y.Available() then
        chip:Hide()
        return right
    end
    local state = Y.State()
    local possible, reason = Y.CanPublish(record.data)
    local listed = state.phase == 'LISTED'
    local text = 'List publicly'
    if state.phase == 'PENDING' then
        text = 'Listing publicly …'
    elseif listed and state.matches then
        text = 'Listed publicly'
    elseif listed then
        text = 'Public listing differs'
    elseif state.phase == 'EXPIRED' then
        text = 'List publicly again'
    end
    chip.text:SetText(tr(text))
    chip:SetChecked(listed and state.matches)
    chip:SetEnabled(state.phase ~= 'PENDING' and (listed or possible or (reason ~= 'NO_ACTIVITY' and reason ~= 'UNAVAILABLE')))
    chip:SetShown(listed or reason ~= 'NO_ACTIVITY')
    if not chip:IsShown() then
        return right
    end
    chip:ClearAllPoints()
    chip:SetPoint('RIGHT', status, 'RIGHT', -right, 0)
    return right + 150 + 6
end

-- ---------------------------------------------------------------------------------------------
-- Tiles
-- ---------------------------------------------------------------------------------------------
-- Public figures of one instance: { groups, seekers, capped } or nil. Never added to the community figures.
function FP.Figures(activity)
    if not FP.Active() or FP.Source() == 'ZENIAL' then
        return nil
    end
    return P.Counts()[activity]
end

-- While only public groups are shown the community marks of the tiles stay away.
function FP.HidesCommunity()
    return FP.Source() == 'PUBLIC'
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
