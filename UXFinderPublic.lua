-- Group finder: groups of the public group search of the game inside the adventure browser.
--
-- One interface, two sources. ZENIAL groups come from the activity board and keep their workflow (apply,
-- withdraw, invite). Public groups come from PublicLFG.lua, live in memory only and are contacted through
-- their leader. This file adds what the finder needs for the second source:
--   - the card of a public group or of a single player,
--   - the bar of an instance: source choice, "Only fitting", the own roles, the filters (groups, players and the
--     languages of the public search) and the refresh button with the age of the list,
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

-- ---------------------------------------------------------------------------------------------
-- Filters of the bar: groups (free places, present roles, play style), players (roles, level, classes) and the
-- language of the search, kept per character, plus saved filters. They only narrow the lists the bar belongs to
-- (FP.barOn) and never start a search; the roles of the players are the role icons of their section header.
-- ---------------------------------------------------------------------------------------------
local S = Z.UIState
local MAX_PROFILES = S and S.MAX_FINDER_FILTERS or 10
local GROUP_ROLES = { free = ROLES, has = { 'TANK', 'HEALER' } }

-- The filter values of the character (created on first use). Always a table.
function FP.Filter()
    local character = Z.uiCharacter
    if not character then
        return S.FinderFilter(nil)
    end
    if type(character.finderFilter) ~= 'table' or type(character.finderFilter.free) ~= 'table' then
        character.finderFilter = S.FinderFilter(character.finderFilter)
    end
    return character.finderFilter
end
function FP.Profiles()
    local character = Z.uiCharacter
    if not character then
        return {}
    end
    if type(character.finderFilters) ~= 'table' then
        character.finderFilters = {}
    end
    return character.finderFilters
end
local function copyFilter(filter)
    return S.FinderFilter(filter)
end
function FP.ToggleGroupRole(kind, role)
    local filter = FP.Filter()
    if GROUP_ROLES[kind] and type(filter[kind]) == 'table' then
        filter[kind][role] = not filter[kind][role] or nil
    end
    U.RefreshFinder()
end
-- Play style: 0 is every style, 1 to 4 the position in the list of the client.
function FP.SetStyle(position)
    FP.Filter().style = position >= 1 and position <= 4 and position or 0
    U.RefreshFinder()
end
-- which: 'minLevel' | 'maxLevel'; an empty or invalid value leaves the end open.
function FP.SetLevel(which, value)
    if which ~= 'minLevel' and which ~= 'maxLevel' then
        return
    end
    local filter = FP.Filter()
    value = tonumber(value)
    value = value and value == math.floor(value) and value >= 1 and value <= 100 and value or nil
    if filter[which] == value then
        return
    end
    filter[which] = value
    if filter.minLevel and filter.maxLevel and filter.minLevel > filter.maxLevel then
        filter.minLevel, filter.maxLevel = filter.maxLevel, filter.minLevel
    end
    U.RefreshFinder()
end
function FP.ClassOn(class)
    local classes = FP.Filter().classes
    return classes == nil or classes[class] == true
end
function FP.ToggleClass(class)
    local filter = FP.Filter()
    local set = {}
    for _, name in ipairs(C.CLASSES) do
        set[name] = FP.ClassOn(name) or nil
    end
    set[class] = not set[class] or nil
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    filter.classes = count < #C.CLASSES and set or nil
    U.RefreshFinder()
end
-- "All" takes the class filter away, "None" switches every class off (only players of unknown class stay).
function FP.SetClasses(all)
    FP.Filter().classes = (not all) and {} or nil
    U.RefreshFinder()
end
function FP.ToggleFilterRole(role)
    F.ToggleSeekerRole(role)
    U.RefreshFinder()
end

-- How many parts of the filter are set: free places, present roles, play style, roles of the players, level,
-- classes, language.
function FP.FilterCount()
    local filter, n = FP.Filter(), 0
    n = n + (next(filter.free) and 1 or 0) + (next(filter.has) and 1 or 0) + (filter.style > 0 and 1 or 0)
    local roles = F.SeekerRoles()
    n = n + ((roles.TANK and roles.HEALER and roles.DAMAGER) and 0 or 1)
    n = n + ((filter.minLevel or filter.maxLevel) and 1 or 0) + (filter.classes and 1 or 0)
    n = n + (FP.Languages().mode ~= 'DEFAULT' and 1 or 0)
    return n
end

-- Back to no filter; the language goes back to the default of the game (and so changes the query, never searches).
function FP.ResetFilters()
    if Z.uiCharacter then
        Z.uiCharacter.finderFilter = S.FinderFilter(nil)
        Z.uiCharacter.finderLanguages = S.FinderLanguages(nil)
    end
    if Z.db then
        Z.db.finderSeekerRoles = nil
    end
    FP.selected = nil
    U.RefreshFinder()
end

-- Saved filters: a name and every value of the filter (also the language and the roles of the players).
local function cleanName(name)
    name = tostring(name or ''):gsub('[%z\1-\31\127|]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name:sub(1, 24)
end
-- Returns true, or false and the reason ('NAME' | 'FULL').
function FP.SaveProfile(name)
    name = cleanName(name)
    local list = FP.Profiles()
    if name == '' or not Z.uiCharacter then
        return false, 'NAME'
    end
    local entry = { name = name, filter = copyFilter(FP.Filter()), languages = S.FinderLanguages(FP.Languages()), roles = S.SeekerRoles(F.SeekerRoles()) }
    for index, saved in ipairs(list) do
        if saved.name:lower() == name:lower() then
            list[index] = entry
            FP.selected = name
            U.RefreshFinder()
            return true
        end
    end
    if #list >= MAX_PROFILES then
        return false, 'FULL'
    end
    list[#list + 1] = entry
    FP.selected = name
    U.RefreshFinder()
    return true
end
function FP.ApplyProfile(index)
    local entry = FP.Profiles()[index]
    if not entry or not Z.uiCharacter then
        return false
    end
    Z.uiCharacter.finderFilter = copyFilter(entry.filter)
    Z.uiCharacter.finderLanguages = S.FinderLanguages(entry.languages)
    if Z.db then
        Z.db.finderSeekerRoles = S.SeekerRoles(entry.roles)
    end
    FP.selected = entry.name
    U.RefreshFinder()
    return true
end
function FP.DeleteProfile(index)
    local list = FP.Profiles()
    if not list[index] then
        return false
    end
    table.remove(list, index)
    FP.selected = nil
    U.RefreshFinder()
    return true
end

-- The play style value of the client for the position the player chose; nil while the filter has none.
local function styleValue(filter)
    if filter.style > 0 then
        FP.styles = FP.styles or P.Playstyles()
        local item = FP.styles[filter.style]
        return item and item.value or nil
    end
end
-- The group filter, only while the bar of the view is up and something is set.
local function groupFilter()
    local filter = FP.barOn and FP.Filter() or nil
    return filter and Q.GroupFilterActive(filter) and filter or nil
end

-- Groups of the list tabs without the merge (ZENIAL rows of the board, rows of the public search): the ones the
-- group filter keeps, and how many it hid.
function FP.FilterGroups(rows)
    local filter = groupFilter()
    if not filter then
        return rows, 0
    end
    local value, out, cut = styleValue(filter), {}, 0
    for _, row in ipairs(rows) do
        local view
        if row.source == 'PUBLIC' then
            view = Q.FromPublic(row)
        elseif row.kind == 'LIVE' and type(row.data) == 'table' then
            view = Q.FromBoard(row)
        end
        if not view or Q.GroupKept(view, filter, value) then
            out[#out + 1] = row
        else
            cut = cut + 1
        end
    end
    return out, cut
end

-- Whether the filters of the players (level, classes) are set and the view has the bar.
function FP.SeekerFilterOn()
    return FP.barOn == true and Q.SeekerFilterActive(FP.Filter())
end
-- Class and level of a player looking for a group, as far as known (ZENIAL: profile of the member or the presence).
local function seekerFacts(row)
    if row.source == 'PUBLIC' then
        return row.leaderLevel, row.leaderClass
    elseif row.own then
        return tonumber(Z.me and Z.me.level), Z.me and Z.me.classFile
    end
    local peer = Z.db and Z.db.peers and Z.db.peers[row.owner]
    local data, presence = peer and peer.data, peer and peer.presence
    return tonumber(data and data.level or presence and presence.level), data and data.classFile or presence and presence.classFile
end
-- true: the player stays in the list.
function FP.SeekerKeeps(row)
    if not FP.SeekerFilterOn() or row.own then
        return true
    end
    local level, class = seekerFacts(row)
    return Q.SeekerKept(FP.Filter(), level, class)
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
    BUSY = 'Another search is still running. Click Refresh afterwards.',
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
    local ok, reason = P.Search(query)
    -- A running search refuses the new one: the status says so while it runs (a click on Refresh searches
    -- this instance afterwards; the game takes a search only from a click, so nothing starts by itself).
    FP.refused = not ok and { reason = reason, at = A.Clock() } or nil
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
    local refused = FP.refused
    if state.phase == 'SEARCHING' then
        -- The running search belongs to another instance: the one that is shown was refused.
        if refused and refused.reason == 'BUSY' and query and state.signature ~= P.Signature(query) then
            return tr(REFUSED.BUSY), true
        end
        return tr('Searching public groups …'), false
    end
    if refused and REFUSED[refused.reason] and A.Clock() - refused.at < 6 then
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
-- The small window below the role or the filter button. It lies over the lists, so opening it moves nothing.
-- left: where the role window starts inside the bar, so it never leaves the page. The filter window starts at the
-- left edge of the bar.
local FILTER_WIDTH = 834
local COLUMN = { 12, 286, 560 }
local CHIP, STEP, LINE = 82, 88, 28

local function place(widget, x, y)
    widget:ClearAllPoints()
    widget:SetPoint('TOPLEFT', x, -y)
end
-- Chips of a row list, three to a line, from (x, y); returns the y below the last line.
local function chipGrid(chips, x, y, perLine)
    for index, chip in ipairs(chips) do
        place(chip, x + ((index - 1) % perLine) * STEP, y + math.floor((index - 1) / perLine) * LINE)
    end
    return y + math.ceil(#chips / perLine) * LINE
end

local function layoutFilter()
    local panel = FP.panel
    local f, filter = panel.f, FP.Filter()
    local public = FP.Source() ~= 'ZENIAL'
    -- Groups
    place(f.groupsLabel, COLUMN[1], 12)
    place(f.freeLabel, COLUMN[1], 32)
    place(f.hasLabel, COLUMN[1], 80)
    place(f.styleLabel, COLUMN[1], 128)
    for _, chip in ipairs(f.free) do
        chip:SetChecked(filter.free[chip.zenialRole] == true)
    end
    for _, chip in ipairs(f.has) do
        chip:SetChecked(filter.has[chip.zenialRole] == true)
    end
    chipGrid(f.free, COLUMN[1], 48, 3)
    chipGrid(f.has, COLUMN[1], 96, 3)
    FP.styles = FP.styles or P.Playstyles()
    for index, chip in ipairs(f.styles) do
        local item = FP.styles[index - 1]
        chip.text:SetText(index == 1 and tr('All') or item and item.label or '?')
        chip:SetShown(index == 1 or item ~= nil)
        chip:SetChecked(filter.style == index - 1)
    end
    local bottom = chipGrid(f.styles, COLUMN[1], 144, 3)
    -- Players
    place(f.playersLabel, COLUMN[2], 12)
    place(f.rolesLabel, COLUMN[2], 32)
    place(f.levelLabel, COLUMN[2], 80)
    place(f.classesLabel, COLUMN[2], 128)
    local roles = F.SeekerRoles()
    for _, chip in ipairs(f.roles) do
        chip:SetChecked(roles[chip.zenialRole] == true)
    end
    chipGrid(f.roles, COLUMN[2], 48, 3)
    place(f.minLevel, COLUMN[2], 96)
    place(f.dash, COLUMN[2] + 66, 100)
    place(f.maxLevel, COLUMN[2] + 82, 96)
    for _, pair in ipairs({ { f.minLevel, filter.minLevel }, { f.maxLevel, filter.maxLevel } }) do
        local edit, value = pair[1], pair[2]
        if not edit:HasFocus() and edit:GetText() ~= (value and tostring(value) or '') then
            edit:SetText(value and tostring(value) or '')
        end
        edit.hint:SetShown((edit:GetText() or '') == '')
    end
    place(f.classesAll, COLUMN[2] + 150, 124)
    place(f.classesNone, COLUMN[2] + 206, 124)
    for _, chip in ipairs(f.classes) do
        chip:SetChecked(FP.ClassOn(chip.zenialClass))
    end
    bottom = math.max(bottom, chipGrid(f.classes, COLUMN[2], 148, 3))
    -- Language (a parameter of the search) and the saved filters
    f.languagesLabel:SetShown(public)
    f.mode:SetShown(public)
    local y = 12
    local languages = FP.Languages()
    local offered = public and P.Languages() or {}
    if public then
        place(f.languagesLabel, COLUMN[3], 12)
        place(f.mode, COLUMN[3], 30)
        f.mode:Select(languages.mode)
        for index, language in ipairs(offered) do
            local chip = f.languages[index]
            if not chip then
                chip = T.Chip(f.box, '', CHIP, 22, function(self)
                    FP.ToggleLanguage(self.zenialCode)
                end)
                f.languages[index] = chip
            end
            chip.zenialCode = language.code
            chip.text:SetText(language.label)
            chip:SetChecked(languages.mode == 'CUSTOM' and languages.codes[language.code] == true)
            chip:SetEnabled(languages.mode == 'CUSTOM')
            chip:Show()
        end
        -- Only as many chips as the client offers languages.
        local shown = {}
        for index = 1, #offered do
            shown[index] = f.languages[index]
        end
        y = chipGrid(shown, COLUMN[3], 64, 3) + 10
    end
    for index = #offered + 1, #f.languages do
        f.languages[index]:Hide()
    end
    local profiles = FP.Profiles()
    f.savedLabel:SetShown(#profiles > 0)
    if #profiles > 0 then
        place(f.savedLabel, COLUMN[3], y)
    end
    for index = 1, MAX_PROFILES do
        local chip = f.saved[index]
        if not chip then
            chip = T.Chip(f.box, '', CHIP, 22, function(self)
                FP.ApplyProfile(self.zenialIndex)
            end)
            f.saved[index] = chip
        end
        local entry = profiles[index]
        chip.zenialIndex = index
        chip:SetShown(entry ~= nil)
        if entry then
            chip.text:SetText(entry.name)
            chip:SetChecked(FP.selected == entry.name)
        end
    end
    local savedBottom = y
    if #profiles > 0 then
        local shown = {}
        for index = 1, #profiles do
            shown[index] = f.saved[index]
        end
        savedBottom = chipGrid(shown, COLUMN[3], y + 18, 3)
    end
    bottom = math.max(bottom, savedBottom)
    -- Footer: save, reset and delete; the name is asked inside the window.
    local footer = bottom + 12
    place(f.save, COLUMN[1], footer)
    f.name:SetShown(FP.naming == true)
    f.confirm:SetShown(FP.naming == true)
    if FP.naming then
        place(f.name, COLUMN[1] + 130, footer)
        place(f.confirm, COLUMN[1] + 130 + 196, footer)
    end
    place(f.reset, FILTER_WIDTH - 12 - 130, footer)
    f.reset:SetEnabled(FP.FilterCount() > 0)
    local selected
    for index, entry in ipairs(profiles) do
        if FP.selected == entry.name then
            selected = index
        end
    end
    f.delete.zenialIndex = selected
    f.delete:SetShown(selected ~= nil)
    place(f.delete, FILTER_WIDTH - 12 - 130 - 6 - 130, footer)
    return footer + 24 + 12
end

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
    panel.f.box:SetShown(not role)
    if role then
        -- What the other window draws is hidden by its own flag too, not only through the hidden frame.
        panel.f.mode:Hide()
        panel.f.languagesLabel:Hide()
        for _, chip in ipairs(panel.f.languages) do
            chip:Hide()
        end
        panel:SetSize(330, 88)
        panel:ClearAllPoints()
        panel:SetPoint('TOPLEFT', FP.bar, 'TOPLEFT', left, -(ROW - 2))
        return
    end
    local height = layoutFilter()
    panel:SetSize(FILTER_WIDTH, height)
    panel:ClearAllPoints()
    panel:SetPoint('TOPLEFT', FP.bar, 'TOPLEFT', 0, -(ROW - 2))
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
        FP.popup, FP.naming, FP.barOn = nil, nil, false
        FP.HideBar()
        return 0
    end
    FP.barOn = true
    local source = FP.Source()
    local public = source ~= 'ZENIAL'
    bar:ClearAllPoints()
    bar:SetPoint('TOPLEFT', 0, -y)
    bar.source:ClearAllPoints()
    bar.source:SetPoint('TOPLEFT', 0, 0)
    bar.source:Select(source)
    local x = 240
    local roleLeft = x
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
    -- The filters (groups, players, language) narrow the lists of both sources.
    bar.filter:ClearAllPoints()
    bar.filter:SetPoint('TOPLEFT', x, -1)
    local count = FP.FilterCount()
    bar.filter:SetText(count > 0 and Z.T('Filter (%d)', count) or tr('Filter'))
    T.SetSelected(bar.filter, FP.popup == 'FILTER')
    x = x + 120 + 6
    if public then
        -- The whisper texts of the player (UXWhisperDesigner.lua); in the overview of an instance on the
        -- second line beside the assistant.
        if not detailed then
            bar.texts:ClearAllPoints()
            bar.texts:SetPoint('TOPLEFT', x, -1)
            x = x + 90 + 6
        end
    end
    bar.texts:SetShown(public)
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
        if public then
            bar.texts:ClearAllPoints()
            bar.texts:SetPoint('TOPLEFT', 236, -ROW)
            left = 236 + 90 + 6
        end
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
        layoutPopup(roleLeft)
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
        FP.naming = nil
        U.RefreshFinder()
    end
    bar.role = T.Button(bar, '', 170, 24, function()
        toggle('ROLE')
    end, 'secondary')
    bar.filter = T.Button(bar, tr('Filter'), 120, 24, function()
        toggle('FILTER')
    end, 'secondary')
    bar.texts = T.Button(bar, tr('Texts'), 90, 24, function()
        if U.WhisperDesigner then
            U.WhisperDesigner.Open('group')
        end
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

    -- The window of the role button and of the filter button.
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

    -- The filter window: groups, players, language, saved filters.
    local box = CreateFrame('Frame', nil, panel)
    box:SetAllPoints(panel)
    local f = { box = box, free = {}, has = {}, styles = {}, roles = {}, classes = {}, languages = {}, saved = {} }
    panel.f = f
    local function head(text)
        return K.Text(box, tr(text), 'overline', 'goldDim')
    end
    local function caption(text)
        return K.Text(box, tr(text), 'caption', 'dim')
    end
    f.groupsLabel, f.playersLabel = head('Groups'), head('Players')
    f.languagesLabel = head('Languages of the public search')
    f.freeLabel, f.hasLabel, f.styleLabel = caption('Free place for'), caption('Already has'), caption('Play style')
    f.rolesLabel, f.levelLabel, f.classesLabel = caption('Roles'), caption('Level'), caption('Classes')
    f.savedLabel = caption('Saved filters')
    for index, role in ipairs(ROLES) do
        local label = Z.Locale.Role(role)
        f.free[index] = T.Chip(box, label, CHIP, 22, function()
            FP.ToggleGroupRole('free', role)
        end)
        f.free[index].zenialRole = role
        f.roles[index] = T.Chip(box, label, CHIP, 22, function(self)
            FP.ToggleFilterRole(self.zenialRole)
            self:SetChecked(F.SeekerRoles()[self.zenialRole] == true)
        end)
        f.roles[index].zenialRole = role
    end
    for index, role in ipairs(GROUP_ROLES.has) do
        f.has[index] = T.Chip(box, Z.Locale.Role(role), CHIP, 22, function()
            FP.ToggleGroupRole('has', role)
        end)
        f.has[index].zenialRole = role
    end
    for index = 1, 5 do
        f.styles[index] = T.Chip(box, '', CHIP, 22, function()
            FP.SetStyle(index - 1)
        end)
    end
    for index, class in ipairs(C.CLASSES) do
        local chip = T.Chip(box, L.ClassName(nil, class) or class, CHIP, 22, function()
            FP.ToggleClass(class)
        end)
        chip.zenialClass = class
        f.classes[index] = chip
    end
    f.classesAll = T.Button(box, tr('All'), 52, 20, function()
        FP.SetClasses(true)
    end, 'secondary')
    f.classesNone = T.Button(box, tr('None'), 52, 20, function()
        FP.SetClasses(false)
    end, 'secondary')
    -- Level range: two small number fields, empty is open. The value is taken when the field is left or Enter is pressed.
    local function levelField(which, hint)
        local edit = F.CreateEdit(box, 60, 3, tr(hint))
        if edit.SetNumeric then
            edit:SetNumeric(true)
        end
        edit:SetScript('OnTextChanged', function(self)
            self.hint:SetShown((self:GetText() or '') == '')
        end)
        local function take(self)
            FP.SetLevel(which, self:GetText())
        end
        edit:SetScript('OnEnterPressed', function(self)
            self:ClearFocus()
            take(self)
        end)
        edit:SetScript('OnEditFocusLost', take)
        return edit
    end
    f.minLevel, f.maxLevel = levelField('minLevel', 'From'), levelField('maxLevel', 'To')
    f.dash = K.Text(box, '–', 'caption', 'dim')
    f.mode = K.Segmented(box, { { key = 'DEFAULT', label = tr('Game default') }, { key = 'ALL', label = tr('All') }, { key = 'CUSTOM', label = tr('Selection') } }, function(key)
        FP.SetLanguageMode(key)
    end)
    f.mode:SetSegmentWidth(86)
    -- Footer. The name of a new saved filter is asked in place.
    f.save = T.Button(box, tr('Save filter'), 120, 24, function()
        FP.naming = not FP.naming or nil
        U.RefreshFinder()
        if FP.naming then
            f.name:SetFocus()
        end
    end, 'secondary')
    f.name = F.CreateEdit(box, 190, 24, tr('Name'))
    f.name:SetScript('OnTextChanged', function(self)
        self.hint:SetShown((self:GetText() or '') == '')
    end)
    local function confirm()
        local ok, reason = FP.SaveProfile(f.name:GetText())
        if ok then
            FP.naming = nil
            f.name:SetText('')
            f.name:ClearFocus()
            U.RefreshFinder()
        elseif reason == 'FULL' then
            U.Message(Z.T('You can save up to %d filters. Delete one first.', MAX_PROFILES))
        end
    end
    f.name:SetScript('OnEnterPressed', confirm)
    f.name:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
        FP.naming = nil
        U.RefreshFinder()
    end)
    f.confirm = T.Button(box, tr('Save'), 70, 24, confirm, 'secondary')
    f.delete = T.Button(box, tr('Delete filter'), 130, 24, function(self)
        if self.zenialIndex then
            FP.DeleteProfile(self.zenialIndex)
        end
    end, 'secondary')
    f.reset = T.Button(box, tr('Reset filters'), 130, 24, function()
        FP.ResetFilters()
    end, 'secondary')
    panel.languagesLabel, panel.mode, panel.languages = f.languagesLabel, f.mode, f.languages
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
    EMPTY = 'This text is empty.',
}
local CONTACT_BADGE = { OPENED = { 'Chat opened', 'info' }, SENT = { 'Message sent', 'success' }, JOINED = { 'In the group', 'success' } }

-- The player with the roles the finder looks with, for fit and for the message.
function FP.Me()
    return { roles = Q.OwnRoles(), level = tonumber(Z.me and Z.me.level) }
end

local function kindOf(row)
    return row.solo and 'solo' or 'group'
end
local function displayName(name)
    return type(name) == 'string' and select(2, L.Identity(name)) or nil
end

-- The values of the placeholders for a row (WhisperTexts.Expand). To a single player the activity is the
-- open instance, to a group the activity of its listing: its catalog id (an English name that can be
-- translated), the name of the client only when there is none.
function FP.WhisperValues(row)
    local me = Z.me or {}
    local listed = row and (type(row.activities) == 'table' and row.activities[1] or row.activityName) or nil
    return {
        level = tonumber(me.level), roles = Q.OwnRoles(), classFile = me.classFile, me = displayName(me.target),
        name = displayName(row and row.leader),
        activity = row and (row.solo and F.activity or listed) or F.activity or listed,
    }
end

-- The message for a row: the text id of its kind (to the leader of a group, or to a single player), the
-- last used one when no id is given, with its placeholders filled.
function FP.Message(row, id)
    local kind = kindOf(row)
    local entry = id and Z.WhisperTexts.Get(kind, id) or Z.WhisperTexts.Last(kind)
    if not entry then
        return ''
    end
    return Z.WhisperTexts.Fit(Z.WhisperTexts.Expand(entry.text, entry.language, FP.WhisperValues(row)))
end

-- Opens the chat box for the leader with the message in it. The player sends it. The text id that was
-- used (or the last used one) is remembered only once the chat box is open.
function FP.Contact(row, text, id)
    local message = text or FP.Message(row, id)
    local ok, reason
    -- An empty text would open an empty chat box and still lock the group: nothing happens instead.
    if message == '' then
        ok, reason = false, 'EMPTY'
    else
        ok, reason = X.Prepare(row, message)
    end
    if ok then
        local kind = kindOf(row)
        local used = id and Z.WhisperTexts.Get(kind, id) or Z.WhisperTexts.Last(kind)
        if used then
            Z.WhisperTexts.SetLast(kind, used.id)
        end
    end
    U.Message(tr(ok and 'The chat box is ready. Press Enter to send.' or REASON_CONTACT[reason] or 'Whisper is unavailable.'))
    U.RefreshFinder()
    return ok, reason
end
-- The whisper action of a card: the main part writes with the last used text, the arrow lists the texts.
local function whisperAction(row)
    local kind = kindOf(row)
    local last = Z.WhisperTexts.Last(kind)
    return { text = Z.T('Whisper · %s', last and last.name or '?'), width = 150, enabled = X.CanContact(row) == true,
        click = function()
            FP.Contact(row)
        end,
        menu = { kind = kind, pick = function(id)
            FP.Contact(row, nil, id)
        end } }
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

-- Where the leader of a group or a single player is, as the search results tell it: the text for the card
-- and the hover info, and whether that is the area of the open instance. The area alone never says that
-- somebody stands at the entrance, so nothing here claims that.
function FP.Location(row)
    local area = row.leaderArea
    if not area then
        return paint('muted', tr('Area unknown')), nil
    end
    local text = paint('dim', Z.T(row.solo and 'Location: %s' or 'Group leader: %s', '')) .. paint('textSoft', area)
    local e = F.activity and C.Get(F.activity)
    -- Only with an area id of the activity is the comparison independent of the language of the names.
    local zone = e and e.area and C.Zone(e)
    if zone and zone == area then
        return text, tr(e.kind == 'DUNGEON' and 'In the dungeon area' or 'In the area of the activity')
    end
    return text, nil
end

-- The private ratings of a public listing: the one of the leader and whether anybody in the group is poorly rated.
-- The other members are read only when the player has a rating of 1-2 at all (cheap check first), so normal use
-- never reads members for the cards. Members the client keeps secret have no name and are skipped.
local function ratingsOf(row)
    local rating = U.PlayerRating(row.leader)
    local low = rating ~= nil and rating.low == true
    local D = Z.SocialDiary
    if not low and not row.solo and D and D.HasLowRating() then
        for _, member in ipairs(P.Members(row) or {}) do
            local other = member.name and U.PlayerRating(member.name)
            if other and other.low then
                low = true
                break
            end
        end
    end
    return rating, low
end

-- What the card of a public group or of a single player shows. Same shape as the description of a ZENIAL
-- card in UXFinder.lua; nothing here reads the activity board.
function FP.Describe(row, context)
    local d = { actions = {}, source = tr('Public'), sourceTone = 'neutral' }
    local class = row.leaderClass and L.ClassName(nil, row.leaderClass) or nil
    local hex = row.leaderClass and T.ClassColorHex and T.ClassColorHex(row.leaderClass)
    local who = row.leader or class or tr('Unknown player')
    who = hex and ('|cff' .. hex .. who .. '|r') or who
    -- The private rating of the leader (stars behind the name) and the warning for a poorly rated player.
    local rating, poorly = ratingsOf(row)
    if rating then
        who = who .. ' ' .. rating.markup
    end
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
        d.actions[2] = whisperAction(row)
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
        d.actions[1] = whisperAction(row)
    end
    -- A poorly rated player takes the place of the fit label; a contact state and "No longer listed" outrank it.
    if poorly then
        d.badge, d.tone = tr(row.solo and 'Poorly rated' or 'Poorly rated player in the group'), 'danger'
    end
    -- What is known about a contact with this leader replaces the fit label.
    local contact = CONTACT_BADGE[X.State(row)]
    if contact then
        d.badge, d.tone = tr(contact[1]), contact[2]
    end
    -- Play style and "new players welcome", as the group search of the game shows them.
    local style = P.PlaystyleName(row.playstyle)
    if style then
        parts[#parts + 1] = paint('success', style)
    end
    if row.beginners then
        parts[#parts + 1] = tr('New players welcome')
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
    -- Last line: where the leader or the player is, then the comment of the listing.
    local where, near = FP.Location(row)
    d.note = where .. (near and paint('dim', ' · ') .. paint('goldBright', near) or '')
        .. (type(row.comment) == 'string' and row.comment ~= '' and paint('dim', ' · ') .. '„' .. row.comment .. '“' or '')
    d.noteRaw = true
    if gone then
        d.badge, d.tone = tr('No longer listed'), 'neutral'
    end
    return d
end

-- The member symbols of a party are drawn by the finder itself (ZENIAL cards have them too).

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
    local where, near = FP.Location(row)
    GameTooltip:AddLine(where .. (near and paint('dim', ' · ') .. paint('goldBright', near) or ''), 0.78, 0.8, 0.85, true)
    -- Stars and private comment of each rated member stand in the member list below; the leader gets a line of
    -- his own unless the list names him.
    local members = P.Members(row)
    local leaderListed = false
    for _, member in ipairs(members or {}) do
        leaderListed = leaderListed or (member.leader and member.name ~= nil)
    end
    if not leaderListed then
        local rating = U.PlayerRating(row.leader)
        if rating then
            GameTooltip:AddLine(U.RatingTipText(rating), 0.78, 0.8, 0.85, true)
        end
    end
    local manner = {}
    if P.PlaystyleName(row.playstyle) then
        manner[#manner + 1] = P.PlaystyleName(row.playstyle)
    end
    if row.beginners then
        manner[#manner + 1] = tr('New players welcome')
    end
    if #manner > 0 then
        GameTooltip:AddLine(table.concat(manner, ' · '), 0.45, 0.82, 0.5, true)
    end
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
            if member.area and not member.leader then
                facts[#facts + 1] = member.area
            end
            who = hex and ('|cff' .. hex .. who .. '|r') or who
            local rating = member.name and U.PlayerRating(member.name)
            if rating then
                who = who .. ' ' .. rating.markup
            end
            if GameTooltip.AddDoubleLine then
                GameTooltip:AddDoubleLine(who, table.concat(facts, ' · '), 1, 1, 1, 0.78, 0.8, 0.85)
            else
                GameTooltip:AddLine(who .. '  ' .. table.concat(facts, ' · '), 0.78, 0.8, 0.85)
            end
            -- The private comment of a rated member; a poorly rated one without comment is still marked.
            if rating and (rating.comment ~= '' or rating.low) then
                GameTooltip:AddLine(rating.comment ~= '' and rating.comment or tr('Poorly rated'), rating.low and 0.95 or 0.78, rating.low and 0.54 or 0.8, rating.low and 0.45 or 0.85, true)
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
    -- The source badge only tells ZENIAL from public where both stand side by side.
    if FP.mixed then
        d.source, d.sourceTone = 'ZENIAL', 'gold'
    end
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
    -- Within one refresh the entries are computed once per instance and sort (FP.Begin starts the cache,
    -- FP.End drops it); the rows of one instance are the same set in every call of a refresh.
    local cacheKey = tostring(activity) .. '|' .. tostring(sort)
    if FP.cache and FP.cache[cacheKey] then
        return FP.cache[cacheKey]
    end
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
                local view = Q.FromPublic(row, e and { levelMin = e.min })
                view.zenial, view.contacted = key ~= nil, X.Contacted(row)
                FP.marks[row.key] = { zenial = key ~= nil }
                FP.mixed = true
                entries[#entries + 1] = { row = row, view = view, fit = Q.Fit(view, me), zenial = false }
            end
        end
    end
    if sort == 'groups' then
        Q.Sort(entries)
    end
    if FP.cache then
        FP.cache[cacheKey] = entries
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
        local filter = groupFilter()
        local cut, options = 0, { fitting = FP.Fitting(), group = filter, styleValue = filter and styleValue(filter) or nil }
        for _, entry in ipairs(entries) do
            local kept, why = Q.Passes(entry.view, entry.fit, options)
            if kept then
                FP.fits[entry.view.key] = entry.fit
                out[#out + 1] = entry.row
            elseif why == 'FILTER' then
                cut = cut + 1
            end
        end
        return out, cut
    else
        for _, entry in ipairs(entries) do
            out[#out + 1] = entry.row
        end
    end
    return out
end

-- Called at the start of every refresh: what was noted about the rows of the last one is forgotten.
function FP.Begin()
    -- The list of whisper texts belongs to a card; the cards are drawn anew, so it closes.
    if U.WhisperDesigner then
        U.WhisperDesigner.CloseMenu()
    end
    -- The window of the role or filter button belongs to the view it was opened in.
    local place = tostring(F.view) .. '|' .. tostring(F.activity)
    if FP.place ~= place then
        FP.place, FP.popup, FP.naming = place, nil, nil
    end
    FP.barOn = false
    FP.fits, FP.marks, FP.mixed = {}, {}, false
    FP.cache = {}
end

-- Called at the end of every refresh: the merged entries of this refresh are dropped.
function FP.End()
    FP.cache = nil
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
    local cut
    out, cut = FP.FilterGroups(out)
    FP.mixed = FP.mixed or #out > 0
    return out, info ~= nil, cut
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
        chip.hint = K.Text(parent, tr('The group search of the game shows the activity, your members and the play style. Level, preferred classes and comment are seen by ZENIAL members only.'), 'caption', 'dim')
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
-- The figures count what the lists show (the merged entries, a group listed in both sources once), groups only
-- while they have a free place. groupRows / seekerRows: the ZENIAL rows of the instance as the lists get them.
function FP.Totals(activity, stats, groupRows, seekerRows)
    local figures = FP.Figures(activity)
    if not figures then
        return nil
    end
    local public = FP.Source() == 'PUBLIC'
    local groups, seekers = 0, 0
    for _, entry in ipairs(collect(groupRows or stats.rows.groups, activity, 'groups')) do
        if entry.fit.tier ~= 'FULL' and not (public and entry.zenial) then
            groups = groups + 1
        end
    end
    for _, entry in ipairs(collect(seekerRows or stats.rows.seekers, activity, 'seekers')) do
        if not entry.view.gone and not (public and entry.zenial) then
            seekers = seekers + 1
        end
    end
    return { groups = groups, seekers = seekers, where = tr(public and 'in the group search of the game' or 'ZENIAL and public') }
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
FP.Guard(FP, 'End', nothing)
FP.Guard(FP, 'OnOpen', nothing)
FP.Guard(FP, 'SyncListing', nothing)
FP.Guard(FP, 'PresetRoles', nothing)
FP.Guard(FP, 'Figures', nothing)
FP.Guard(FP, 'TileText', nothing)
FP.Guard(FP, 'Totals', nothing)
FP.Guard(FP, 'Location', function() return '', nil end)
FP.Guard(FP, 'TileHint', nothing)
FP.Guard(FP, 'CategoryRows', nothing)
FP.Guard(FP, 'FilterGroups', function(rows) return rows, 0 end)
FP.Guard(FP, 'SeekerKeeps', function() return true end)
FP.Guard(FP, 'SeekerFilterOn', no)
FP.Guard(FP, 'Candidates', function() return {} end)
FP.Guard(FP, 'Status', function() return '', false end)
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
