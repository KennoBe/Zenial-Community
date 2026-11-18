-- Group finder: groups of the public group search of the game inside the adventure browser.
--
-- One interface, two sources. ZENIAL groups come from the activity board and keep their workflow (apply,
-- withdraw, invite). Public groups come from PublicLFG.lua, live in memory only and are contacted through
-- their leader. This file adds what the finder needs for the second source:
--   - the card of a public group or of a single player,
--   - the bar of an instance: source choice, "Only fitting", the own roles, the languages of the public
--     search, and the refresh button with the age of the list,
--   - merging both sources of one instance into one list, best fitting first,
--   - the figures for the tiles and the public section of the tabs without tiles.
-- UXFinder.lua calls in at fixed places. A search starts from a click only (the client takes nothing else):
-- the click that opens an instance, or the refresh button. Never from a filter, a redraw or a language change.
-- See _dev/addons/ZenialCommunity/PUBLIC-LFG-INTEGRATION-PLAN.md.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local C, P, M, Q, X, Y = Z.GroupFinderCatalog, Z.PublicLFG, Z.PublicLFGMap, Z.PublicLFGMatch, Z.PublicLFGContact, Z.PublicLFGListing
if type(U) ~= 'table' or type(U.Finder) ~= 'table' or type(P) ~= 'table' or type(M) ~= 'table' or type(Q) ~= 'table' or type(X) ~= 'table' then
    return
end

local F = U.Finder
local FP = { fits = {}, marks = {} }
U.FinderPublic = FP

local ROLES = Q.ROLES
local VIEW_KIND = { dungeons = 'DUNGEON', raids = 'RAID', pvp = 'PVP', quests = 'QUEST', other = 'CUSTOM' }
local SOURCES = { ALL = true, ZENIAL = true, PUBLIC = true }
local ROW = 30
local FRESH = 30 -- a complete list of an instance younger than this is not searched again when the instance opens
local LIST_VIEWS = { quests = true, other = true } -- tabs without tiles: their public groups stand in the tab itself
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
    return not FP.broken and P.Available() == true
end

-- ---------------------------------------------------------------------------------------------
-- Choices: source, languages, roles, "Only fitting". All kept per character.
-- ---------------------------------------------------------------------------------------------
-- Which groups are shown: ALL, ZENIAL or PUBLIC.
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

-- Languages of the public search: { mode = 'DEFAULT' | 'ALL' | 'CUSTOM', codes = { deDE = true } }.
function FP.Languages()
    local saved = Z.uiCharacter and Z.uiCharacter.finderLanguages
    if type(saved) ~= 'table' then
        return { mode = 'DEFAULT', codes = {} }
    end
    return { mode = (saved.mode == 'ALL' or saved.mode == 'CUSTOM') and saved.mode or 'DEFAULT', codes = type(saved.codes) == 'table' and saved.codes or {} }
end
-- Changing the languages never searches: the line beside the refresh button then says that they changed.
function FP.SetLanguageMode(mode)
    if Z.uiCharacter then
        local languages = FP.Languages()
        languages.mode = mode
        Z.uiCharacter.finderLanguages = languages
    end
    U.RefreshFinder()
end
function FP.ToggleLanguage(code)
    if Z.uiCharacter then
        local languages = FP.Languages()
        languages.codes[code] = not languages.codes[code] or nil
        Z.uiCharacter.finderLanguages = languages
    end
    U.RefreshFinder()
end
function FP.ToggleRole(role)
    local roles = Q.OwnRoles()
    roles[role] = not roles[role]
    Q.SetOwnRoles(roles)
    U.RefreshFinder()
end
-- "Only fitting": groups without a place for the player and full groups stay away.
function FP.Fitting()
    return Z.uiCharacter ~= nil and Z.uiCharacter.finderFitting == true
end
function FP.SetFitting(on)
    if Z.uiCharacter then
        Z.uiCharacter.finderFitting = on == true
    end
    U.RefreshFinder()
end

-- Query of the open view: the activities of the open instance, otherwise everything the client offers in the
-- category of the tab, with the chosen languages. nil for views without a public counterpart.
function FP.Query(activity)
    activity = activity or F.activity
    local category, ids
    if activity then
        local e = C.Get(activity)
        category, ids = e and M.Category(e.kind), M.Activities(activity)
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

-- The part of a signature that names the languages.
local function languagePart(signature)
    return type(signature) == 'string' and signature:match('|([^|]*|[^|]*)$') or nil
end

-- ---------------------------------------------------------------------------------------------
-- Refresh: the state of the public search in words, and what starts a search
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

-- The player opens an instance with a click: its public groups are searched right away. Not when its list
-- is only a few seconds old, and not while only ZENIAL groups are shown. Called before the instance is drawn
-- (the caller draws it afterwards), so the call into the game is the first thing the click does.
function FP.OnOpen(activity)
    if not activity or not FP.Active() or FP.Source() == 'ZENIAL' then
        return
    end
    local query = FP.Query(activity)
    if not query then
        return
    end
    local _, info = P.Rows(activity)
    if info and info.complete and A.Clock() - info.receivedAt <= FRESH and languagePart(info.signature) == languagePart(P.Signature(query)) then
        return
    end
    FP.refused = nil
    P.Search(query)
end

-- How long ago a list arrived.
local function ago(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 5 then
        return tr('Updated just now')
    elseif seconds < 60 then
        return Z.T('Updated %d seconds ago', seconds)
    elseif seconds < 120 then
        return tr('Updated 1 minute ago')
    end
    return Z.T('Updated %d minutes ago', math.floor(seconds / 60))
end

-- The line beside the refresh button and whether a click may search.
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
    local _, info = listing()
    if not info then
        return tr(query and 'Public groups are not loaded yet.' or 'The group search of the game offers nothing here.'), query ~= nil
    end
    if languagePart(info.signature) ~= languagePart(signature) then
        return tr('Language changed. Refresh to search again.'), true
    end
    local text = ago(A.Clock() - info.receivedAt)
    -- A list that was cut off, or that was searched for more than this instance, holds only part of the entries.
    if F.activity and not info.complete or not F.activity and info.truncated then
        text = text .. ' · ' .. tr('only part of the entries')
    end
    return text, true
end

-- ---------------------------------------------------------------------------------------------
-- Bar: source choice, "Only fitting", role, language, refresh
-- ---------------------------------------------------------------------------------------------
local function roleCaption()
    local roles, names = Q.OwnRoles(), {}
    for _, role in ipairs(ROLES) do
        if roles[role] then
            names[#names + 1] = Z.Locale.Role(role)
        end
    end
    return Z.T('Role: %s', table.concat(names, ', '))
end
local function languageCaption()
    local languages, value = FP.Languages(), tr('Game default')
    if languages.mode == 'ALL' then
        value = tr('All')
    elseif languages.mode == 'CUSTOM' then
        local labels = {}
        for _, language in ipairs(P.Languages()) do
            if languages.codes[language.code] then
                labels[#labels + 1] = language.label
            end
        end
        value = #labels == 0 and '–' or #labels <= 2 and table.concat(labels, ', ') or Z.T('%d languages', #labels)
    end
    return Z.T('Language: %s', value)
end

-- The small window below the role or the language button. It lies over the lists, so opening it moves nothing.
-- left: where the window starts inside the bar, so it never leaves the page.
local function layoutPopup(left)
    local panel = FP.panel
    local role = FP.popup == 'ROLE'
    panel.rolesLabel:SetShown(role)
    panel.rolesHint:SetShown(role)
    local roles = Q.OwnRoles()
    for _, chip in ipairs(panel.roles) do
        chip:SetShown(role)
        chip:SetChecked(roles[chip.zenialRole] == true)
    end
    panel.languagesLabel:SetShown(not role)
    panel.mode:SetShown(not role)
    local rows = 0
    if not role then
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
            chip:SetPoint('TOPLEFT', 12 + ((index - 1) % 4) * 102, -(70 + math.floor((index - 1) / 4) * 28))
            chip:SetChecked(languages.mode == 'CUSTOM' and languages.codes[language.code] == true)
            chip:SetEnabled(languages.mode == 'CUSTOM')
            chip:Show()
        end
        for index = #offered + 1, #panel.languages do
            panel.languages[index]:Hide()
        end
        rows = math.max(1, math.ceil(#offered / 4))
    else
        for _, chip in ipairs(panel.languages) do
            chip:Hide()
        end
    end
    panel:SetSize(role and 330 or 432, role and 88 or 78 + rows * 28)
    panel:ClearAllPoints()
    panel:SetPoint('TOPLEFT', FP.bar, 'TOPLEFT', left, -(ROW - 2))
end

-- "I am looking for a group": the role chips of the search bar start with the roles chosen under "Role", so
-- the player does not choose them twice. Automatic roles leave the bar as it is.
function FP.PresetRoles(chips)
    if not FP.Active() then
        return
    end
    local roles, origin = Q.OwnRoles()
    if origin ~= 'CHOSEN' then
        return
    end
    for role, chip in pairs(chips) do
        chip:SetChecked(roles[role] == true)
    end
end

-- Lays the bar out below y and returns its height; 0 where there is none.
-- detailed: the overview of an instance (two lines). The tabs with tiles have no bar: the public groups of an
-- instance are searched when it is opened. The tabs without tiles have one line.
function FP.LayoutBar(y, width, detailed)
    local bar = FP.bar
    if not bar then
        return 0
    end
    if not FP.Active() or not (detailed or LIST_VIEWS[F.view]) then
        FP.popup = nil
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
    local x = 240
    local roleLeft, languageLeft = x, x
    bar.fitting:SetShown(detailed == true)
    bar.role:SetShown(detailed == true)
    if detailed then
        bar.fitting:ClearAllPoints()
        bar.fitting:SetPoint('TOPLEFT', x, -2)
        bar.fitting:SetChecked(FP.Fitting())
        x = x + 108 + 6
        roleLeft = x
        bar.role:ClearAllPoints()
        bar.role:SetPoint('TOPLEFT', x, -1)
        bar.role:SetText(roleCaption())
        T.SetSelected(bar.role, FP.popup == 'ROLE')
        x = x + 170 + 6
    elseif FP.popup == 'ROLE' then
        FP.popup = nil
    end
    bar.language:SetShown(public)
    if public then
        -- The window of the languages is wider than its button: it ends where the button ends.
        languageLeft = math.max(0, x + 190 - 432)
        bar.language:ClearAllPoints()
        bar.language:SetPoint('TOPLEFT', x, -1)
        bar.language:SetText(languageCaption())
        T.SetSelected(bar.language, FP.popup == 'LANGUAGE')
        x = x + 190 + 6
    elseif FP.popup == 'LANGUAGE' then
        FP.popup = nil
    end
    local text, enabled = FP.Status()
    bar.status:SetShown(public)
    bar.refresh:SetShown(public)
    bar.status:SetText(text)
    bar.refresh:SetEnabled(enabled)
    bar.status:ClearAllPoints()
    bar.refresh:ClearAllPoints()
    bar.assist:SetShown(detailed == true)
    local rows, line, left = 1, 0, x
    if detailed then
        -- Second line: the assistant on the left, the age of the list and the refresh button on the right.
        rows, line, left = 2, ROW, 236
        local candidates = #FP.Candidates()
        bar.assist:ClearAllPoints()
        bar.assist:SetPoint('TOPLEFT', 0, -ROW)
        bar.assist:SetText(Z.T('Contact fitting groups (%d)', candidates))
        bar.assist:SetEnabled(candidates > 0)
    end
    bar.refresh:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -(line + 1))
    bar.status:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', -128, -(line + 6))
    bar.status:SetWidth(math.max(60, width - left - 128 - 8))
    bar.status:SetHeight(14)
    bar:SetSize(width, rows * ROW - 6)
    bar:Show()
    local panel = FP.panel
    panel:SetShown(FP.popup ~= nil)
    if FP.popup then
        layoutPopup(FP.popup == 'ROLE' and roleLeft or languageLeft)
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
    bar.source:SetSegmentWidth(78)
    bar.fitting = T.Chip(bar, tr('Only fitting'), 108, 22, function(self)
        FP.SetFitting(self:GetChecked() and true or false)
    end)
    local function toggle(kind)
        FP.popup = FP.popup ~= kind and kind or nil
        U.RefreshFinder()
    end
    bar.role = T.Button(bar, '', 170, 24, function()
        toggle('ROLE')
    end, 'secondary')
    bar.language = T.Button(bar, '', 190, 24, function()
        toggle('LANGUAGE')
    end, 'secondary')
    bar.assist = T.Button(bar, '', 230, 24, function()
        if U.FinderAssistant then
            U.FinderAssistant.Open()
        end
    end, 'secondary')
    bar.status = K.Text(bar, '', 'caption', 'dim')
    bar.status:SetJustifyH('RIGHT')
    if bar.status.SetWordWrap then
        bar.status:SetWordWrap(false)
    end
    bar.refresh = T.Button(bar, tr('Refresh'), 120, 24, function()
        FP.Search()
    end, 'secondary')
    -- The age of the list counts on while the bar is visible. Only the text changes; nothing is read or drawn.
    bar:SetScript('OnUpdate', function(self, elapsed)
        self.zenialWait = (self.zenialWait or 0) + (tonumber(elapsed) or 0)
        if self.zenialWait < 1 then
            return
        end
        self.zenialWait = 0
        if self.status:IsShown() then
            local text, enabled = FP.Status()
            self.status:SetText(text)
            self.refresh:SetEnabled(enabled)
        end
    end)
    local function tooltip(widget, title, lines)
        widget:HookScript('OnEnter', function(self)
            if not GameTooltip or not GameTooltip.SetOwner then
                return
            end
            GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMLEFT')
            GameTooltip:AddLine(tr(title), 1, 0.85, 0.42)
            for _, text in ipairs(lines) do
                GameTooltip:AddLine(tr(text), 0.78, 0.8, 0.85, true)
            end
            GameTooltip:Show()
        end)
        widget:HookScript('OnLeave', function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
    end
    tooltip(bar.refresh, 'Public group search', {
        'Searches the group search of the game again for what you see here.',
        'Opening an instance searches by itself.',
        'The game returns at most 100 entries.',
    })
    tooltip(bar.assist, 'Contact fitting groups', {
        'Goes through the groups that fit you, one at a time. You confirm every contact with a click.',
    })
    tooltip(bar.fitting, 'Only fitting', {
        'Very fitting: only your role is missing, or tank and healer are already there.',
        'Fitting: there is a place for one of your roles.',
        'Role unknown: the game does not tell which roles are missing.',
        'Groups without a place for you and full groups are hidden.',
    })
    for _, button in ipairs(bar.source.segments) do
        tooltip(button, 'Shown groups', {
            'ZENIAL: groups of ZENIAL members. You apply with a click.',
            'Public: groups from the group search of the game. You whisper their leader.',
        })
    end
    bar:Hide()
    FP.bar = bar

    -- The window of the role and the language button.
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
    panel.rolesHint = K.Text(panel, tr('No choice: your role comes from your profile or from the game.'), 'caption', 'dim')
    panel.rolesHint:SetPoint('TOPLEFT', 12, -60)
    panel.rolesHint:SetWidth(306)
    panel.rolesHint:SetHeight(24)
    panel.rolesHint:SetJustifyH('LEFT')
    panel.languagesLabel = K.Text(panel, tr('Languages of the public search'), 'overline', 'goldDim')
    panel.languagesLabel:SetPoint('TOPLEFT', 12, -12)
    panel.mode = K.Segmented(panel, { { key = 'DEFAULT', label = tr('Game default') }, { key = 'ALL', label = tr('All') }, { key = 'CUSTOM', label = tr('Selection') } }, function(key)
        FP.SetLanguageMode(key)
    end)
    panel.mode:SetSegmentWidth(120)
    panel.mode:SetPoint('TOPLEFT', 12, -30)
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
        local counts, remaining = row.counts, row.remaining
        if counts and row.size and row.size <= 5 then
            -- A party: one symbol per member (tank, healer, damage), then the places that are still free.
            d.members = {}
            local known = 0
            for _, role in ipairs(ROLES) do
                for _ = 1, counts[role] or 0 do
                    d.members[#d.members + 1] = { role = role }
                    known = known + 1
                end
            end
            for _ = 1, math.max(0, (row.members or 0) - known) do
                d.members[#d.members + 1] = { role = 'SEEKER' }
            end
            local free, missing, wanted, either = math.max(0, row.size - (row.members or 0)), 0, {}, {}
            for _, role in ipairs(ROLES) do
                local n = remaining and remaining[role] or 0
                missing = missing + n
                if n > 0 then
                    wanted[#wanted + 1] = { role, n .. ' ' .. Z.Locale.Role(role) }
                    either[#either + 1] = paint(T.roleColors[role] or 'text', Z.Locale.Role(role))
                end
            end
            if remaining and missing <= free then
                for _, role in ipairs(ROLES) do
                    for _ = 1, remaining[role] or 0 do
                        d.members[#d.members + 1] = { role = role, free = true }
                    end
                end
            else
                -- No role needs, or more roles missing than places free (a member without a role, or one who
                -- can play two): which role a free place is for is open, so the place is drawn without one.
                for _ = 1, free do
                    d.members[#d.members + 1] = { role = 'SEEKER', free = true }
                end
            end
            while #d.members > row.size do
                table.remove(d.members)
            end
            if remaining and missing > free and #either > 1 then
                d.roles = paint('dim', tr('Needed') .. ': ') .. table.concat(either, paint('dim', ' ' .. tr('or') .. ' '))
            elseif #wanted > 0 then
                d.roles = paint('dim', tr('Needed') .. ': ') .. K.Roles(wanted)
            elseif remaining then
                d.roles = paint('dim', tr('Group is full'))
            end
        elseif counts then
            -- A raid or a group without a fixed size: how many of each role are there.
            d.roleItems = {}
            for _, role in ipairs(ROLES) do
                if (counts[role] or 0) > 0 then
                    d.roleItems[#d.roleItems + 1] = { role = role, text = counts[role] .. ' ' .. Z.Locale.Role(role) }
                end
            end
            if #d.roleItems == 0 then
                d.roleItems, d.roles = nil, paint('dim', tr('Role needs unknown'))
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

-- The member symbols of a party in front of the role line of its card (d.members of FP.Describe). Called for
-- every card: one without symbols gets its own hidden.
function FP.DrawMembers(card, d, left)
    local icons, list = card.zenialMembers, d and d.members
    if not icons then
        if not list then
            return
        end
        icons = {}
        card.zenialMembers = icons
    end
    local x = left
    for index = 1, math.max(#icons, list and #list or 0) do
        local icon, member = icons[index], list and list[index]
        if member and not icon then
            icon = card:CreateTexture(nil, 'ARTWORK')
            icon:SetSize(16, 16)
            icons[index] = icon
        end
        if icon then
            icon:SetShown(member ~= nil)
            if member then
                F.SetRoleIcon(icon, member.role)
                icon:SetAlpha(member.free and 0.28 or 1)
                icon:ClearAllPoints()
                icon:SetPoint('TOPLEFT', x, -42)
                x = x + 19
            end
        end
    end
    if list and #list > 0 then
        card.roles:ClearAllPoints()
        card.roles:SetPoint('TOPLEFT', x + 6, -44)
    end
end

-- Hover info of a public card: who is in the group, with level and class. The members are read from the
-- client the moment the mouse is over the card, and only for a list the client still holds.
function FP.Tooltip(card, row)
    if not GameTooltip or not GameTooltip.SetOwner or type(row) ~= 'table' then
        return
    end
    GameTooltip:SetOwner(card, 'ANCHOR_RIGHT')
    GameTooltip:AddLine(row.leader or tr(row.solo and 'Unknown player' or 'Public group'), 1, 0.85, 0.42)
    local head = {}
    if row.activityName then
        head[#head + 1] = row.activityName
    end
    if not row.solo and row.members then
        head[#head + 1] = row.size and Z.T('%d/%d players', row.members, row.size) or Z.T('%d players', row.members)
    end
    if #head > 0 then
        GameTooltip:AddLine(table.concat(head, ' · '), 0.78, 0.8, 0.85, true)
    end
    local members = P.Members(row)
    if members and #members > 0 then
        for _, member in ipairs(members) do
            local class = member.class and L.ClassName(nil, member.class) or nil
            local hex = member.class and T.ClassColorHex and T.ClassColorHex(member.class)
            local who = member.name or class or tr('Unknown player')
            local facts = {}
            if member.level then
                facts[#facts + 1] = Z.T('Level %d', member.level)
            end
            if member.name and class then
                facts[#facts + 1] = class
            end
            if member.role then
                facts[#facts + 1] = Z.Locale.Role(member.role)
            end
            who = hex and ('|cff' .. hex .. who .. '|r') or who
            if GameTooltip.AddDoubleLine then
                GameTooltip:AddDoubleLine(who, table.concat(facts, ' · '), 1, 1, 1, 0.78, 0.8, 0.85)
            else
                GameTooltip:AddLine(who .. '  ' .. table.concat(facts, ' · '), 0.78, 0.8, 0.85)
            end
        end
    elseif not row.solo then
        GameTooltip:AddLine(tr('Refresh to see the members.'), 0.5, 0.52, 0.58, true)
    end
    if type(row.comment) == 'string' and row.comment ~= '' then
        GameTooltip:AddLine('„' .. row.comment .. '“', 0.78, 0.8, 0.85, true)
    end
    GameTooltip:Show()
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
            if Q.Passes(entry.view, entry.fit, { fitting = FP.Fitting() }) then
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
    -- The window of the role or language button belongs to the view it was opened in.
    local place = tostring(F.view) .. '|' .. tostring(F.activity)
    if FP.place ~= place then
        FP.place, FP.popup = place, nil
    end
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
-- The choice of the character to list the own group or search in the group search of the game as well.
-- On unless the player switched it off.
function FP.ListsPublicly()
    return Z.uiCharacter ~= nil and Z.uiCharacter.finderPublish ~= false
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
            Z.uiCharacter.finderPublish = false
        end
        listingMessage(ok, reason, 'Your public listing was removed.')
    else
        local ok, reason = Y.Publish(Z.db.lfg[1])
        if ok and Z.uiCharacter then
            Z.uiCharacter.finderPublish = true
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
        chip = T.Chip(status, '', 150, 18, function()
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
    -- Beside the caption of the line ("My group"), so the line itself keeps its full width for the roles.
    local caption = status.over.GetStringWidth and tonumber(status.over:GetStringWidth()) or 0
    chip:ClearAllPoints()
    chip:SetPoint('TOPLEFT', status, 'TOPLEFT', 14 + (caption > 0 and caption or 90) + 12, -3)
    return right
end

-- The same choice inside the create form of a group, so it is there before the group exists. Returns the
-- chip, or nil where the activity has no counterpart in the group search of the game.
function FP.FormChip(parent, activity)
    local chip = FP.formChip
    local ids = FP.Active() and Y and Y.Available() and activity and M.Activities(activity) or nil
    if not ids or #ids == 0 then
        if chip then
            chip:Hide()
            chip.hint:Hide()
        end
        return nil
    end
    if not chip then
        chip = T.Chip(parent, tr('List publicly'), 190, 24, function(self)
            if Z.uiCharacter then
                Z.uiCharacter.finderPublish = self:GetChecked() and true or false
            end
        end)
        chip:HookScript('OnEnter', listingTooltip)
        chip:HookScript('OnLeave', function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
        -- What the group search of the game does not carry: said where the player fills it in.
        chip.hint = K.Text(parent, tr('The group search of the game shows only the activity and your members. Level, preferred classes and comment are seen by ZENIAL members only.'), 'caption', 'dim')
        chip.hint:SetJustifyH('LEFT')
        if chip.hint.SetJustifyV then
            chip.hint:SetJustifyV('TOP')
        end
        FP.formChip = chip
    end
    chip:SetChecked(FP.ListsPublicly())
    chip:Show()
    chip.hint:Show()
    return chip
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

-- Figures for the head of an instance while a list of the public group search is there: the groups and the
-- players looking of both sources (of the public one alone while only public groups are shown), and the words
-- that say what was counted. nil without a list: the head then shows the figures of the community as before.
-- The figures of the community themselves (tiles, tabs, catalogue) never include public groups.
function FP.Totals(activity, stats)
    local figures = FP.Figures(activity)
    if not figures then
        return nil
    end
    local public = FP.Source() == 'PUBLIC'
    return {
        groups = figures.groups + (public and 0 or stats.groups), seekers = figures.seekers + (public and 0 or stats.seekers),
        where = tr(public and 'in the group search of the game' or 'ZENIAL and public'),
    }
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

-- ---------------------------------------------------------------------------------------------
-- Protection of the finder
-- ---------------------------------------------------------------------------------------------
-- UXFinder.lua calls into this file while it draws. An error here must not take the finder with it: the
-- public part is switched off until the interface is loaded again, the error goes to the error handler of
-- the client once (so it is not lost), and the finder goes on with the ZENIAL groups.
local function hide()
    for _, name in ipairs({ 'bar', 'panel', 'listing' }) do
        local widget = FP[name]
        if widget then
            pcall(widget.Hide, widget)
        end
    end
end
local function fail(err)
    if FP.broken then
        return
    end
    FP.broken = tostring(err)
    hide()
    local handler = type(geterrorhandler) == 'function' and geterrorhandler()
    if type(handler) == 'function' then
        pcall(handler, 'ZENIAL Community, public group search: ' .. FP.broken)
    end
    -- Draw again without the public part.
    Z.MarkDirty()
end
-- Wraps owner[name]: the fallback answers while the public part is off and after an error.
function FP.Guard(owner, name, fallback)
    local fn = owner[name]
    owner[name] = function(...)
        if FP.broken then
            return fallback(...)
        end
        local ok, a, b, c = pcall(fn, ...)
        if ok then
            return a, b, c
        end
        fail(a)
        return fallback(...)
    end
end
local function nothing() end
local function no() return false end
FP.Guard(FP, 'Active', no)
FP.Guard(FP, 'Create', nothing)
FP.Guard(FP, 'Begin', nothing)
FP.Guard(FP, 'OnOpen', nothing)
FP.Guard(FP, 'SyncListing', nothing)
FP.Guard(FP, 'PresetRoles', nothing)
FP.Guard(FP, 'Figures', nothing)
FP.Guard(FP, 'TileText', nothing)
FP.Guard(FP, 'Totals', nothing)
FP.Guard(FP, 'TileHint', nothing)
FP.Guard(FP, 'CategoryRows', nothing)
FP.Guard(FP, 'Candidates', function() return {} end)
FP.Guard(FP, 'Status', function() return '', false end)
FP.Guard(FP, 'DrawMembers', nothing)
FP.Guard(FP, 'Tooltip', nothing)
FP.Guard(FP, 'FormChip', nothing)
FP.Guard(FP, 'LayoutBar', function() hide() return 0 end)
FP.Guard(FP, 'HideBar', hide)
FP.Guard(FP, 'Merge', function(rows) return rows end)
FP.Guard(FP, 'LayoutListing', function(_, right) hide() return right end)
FP.Guard(FP, 'Mark', function(d) return d end)
FP.Guard(FP, 'Describe', function(row)
    return { actions = {}, title = type(row) == 'table' and type(row.leader) == 'string' and row.leader or '', meta = '' }
end)

return FP
