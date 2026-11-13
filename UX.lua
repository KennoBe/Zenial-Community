local Z, L, A = ZenialCommunity, ZenialCommunity.Logic, ZenialCommunity.Adapter
local H = Z.History
local U = Z.UI
local T = Z.Theme
local I = Z.Locale
-- Private table shared by the UX*.lua parts (locals that more than one part needs). Not a public API.
local S = {}
U.Shared = S

local function tr(value)
    return I and I.Text(value) or value
end
S.tr = tr
local HISTORY_PAGE, ADDON_PAGE = 7, 8
S.HISTORY_PAGE = HISTORY_PAGE
S.ADDON_PAGE = ADDON_PAGE
local ORDER_TERMINAL = { COMPLETED = true, DECLINED = true, CANCELLED = true, EXPIRED = true }
S.ORDER_TERMINAL = ORDER_TERMINAL
local MAIN_TAB_NAMES = {
    tr('Fellow players'),
    tr('Crafting'),
    tr('Groups'),
    tr('Quests'),
    tr('Trade'),
    tr('My characters'),
    tr('History'),
    tr('Addon Manager'),
    tr('Today'),
    tr('Activities'),
    tr('Settings'),
}
S.MAIN_TAB_NAMES = MAIN_TAB_NAMES
local NAV_ICONS = T and T.assets and T.assets.icons or {}
S.NAV_ICONS = NAV_ICONS
-- Sidebar icons are names of the Community icon atlas (T.iconCells); list rows keep NAV_ICONS.
local MAIN_TAB_ICONS = { 'members', 'craft', 'activities', 'quests', 'trade', 'characters', 'history', 'addons', 'today', 'activities', 'settings' }
S.MAIN_TAB_ICONS = MAIN_TAB_ICONS
-- One line under the page title in the top bar, per main page.
local PAGE_SUBTITLES = {
    'Find fellow players, keep notes and stay in touch',
    'Recipes, crafting orders and shopping lists',
    'Groups, events and PvP help from the community',
    'Shared quests, quest groups and help requests',
    'Offers, requests and search alerts',
    'Your characters, public profile and item search',
    'Past contacts and requests',
    'Settings of your installed ZENIAL addons',
    'Your wishes, open tasks and next appointments',
    'Groups, events and PvP help from the community',
    'Display, privacy, tools and data',
}
S.PAGE_SUBTITLES = PAGE_SUBTITLES
local PVP, DUNGEONS, RAIDS = Z.GroupFinder.Activities.PVP, Z.GroupFinder.Activities.DUNGEON, Z.GroupFinder.Activities.RAID
S.PVP = PVP
S.DUNGEONS = DUNGEONS
S.RAIDS = RAIDS
local RAID_SIZE = {
    ['Deepgrove Tomb'] = 10,
    ['Mount Hyjal Summit'] = 20,
    ["Onyxia's Lair"] = 40,
    ['Molten Core'] = 40,
    ['Blackwing Lair'] = 40,
    ["Zul'Gurub"] = 20,
    ["Ruins of Ahn'Qiraj"] = 20,
    ["Temple of Ahn'Qiraj"] = 40,
    ['Naxxramas'] = 40,
}
S.RAID_SIZE = RAID_SIZE
local CLASSES = { 'ALL_CLASSES', 'DRUID', 'WARLOCK', 'HUNTER', 'WARRIOR', 'MAGE', 'PALADIN', 'PRIEST', 'SHAMAN', 'ROGUE' }
S.CLASSES = CLASSES
local ROLE_OPTIONS = { 'NONE', 'TANK', 'HEALER', 'DAMAGER' }
S.ROLE_OPTIONS = ROLE_OPTIONS
local TRADE_CATEGORIES = {
    'ALL_ITEM_CATEGORIES',
    'WEAPON',
    'ARMOR',
    'CONTAINER',
    'CONSUMABLE',
    'TRADE_GOODS',
    'PROJECTILE',
    'RECIPE',
    'QUEST_ITEM',
    'MISC',
    'SERVICE',
    'UNCLASSIFIED',
}
S.TRADE_CATEGORIES = TRADE_CATEGORIES
local TRADE_SORTS = { 'TRADE_NAME', 'UNIT_ASC', 'UNIT_DESC', 'ENDING_SOON' }
S.TRADE_SORTS = TRADE_SORTS
local OPTION_LABELS = {
    ALL = 'All',
    ALL_CLASSES = 'All classes',
    ALL_PROFESSIONS = 'All professions',
    ONLINE = tr('Online'),
    NAME = 'Name A–Z',
    LEVEL_ASC = 'Level ascending',
    LEVEL_DESC = 'Level descending',
    LAST_SEEN = 'Last seen',
    NONE = 'No preference',
    PVP = 'PvP',
    DUNGEON = 'Dungeons',
    RAID = 'Raids',
    CUSTOM = 'Custom activity',
    SELL = 'Sell',
    BUY = 'Buy',
    SERVICE = 'Service',
    ALL_CATEGORIES = 'All categories',
    ALL_ACTIVITIES = 'All activities',
    ALL_ZONES = 'All zones',
    CURRENT_ZONE = 'Only my current zone',
    DAYS_7 = 'Last 7 days',
    DAYS_30 = 'Last 30 days',
    DAYS_90 = 'Last 90 days',
    ALL_KINDS = 'All areas',
    GROUP = 'Groups',
    QUEST = 'Quest Help',
    CRAFT = 'Crafting',
    ALL_CHARACTERS = 'All characters',
    ALL_ITEM_CATEGORIES = 'All item categories',
    WEAPON = 'Weapons',
    ARMOR = 'Armor',
    CONTAINER = 'Bags',
    CONSUMABLE = 'Consumables',
    TRADE_GOODS = 'Materials',
    PROJECTILE = 'Ammunition',
    RECIPE = 'Recipes',
    QUEST_ITEM = 'Quest items',
    MISC = 'Miscellaneous',
    UNCLASSIFIED = 'Unclassified',
    TRADE_NAME = tr('Name'),
    UNIT_ASC = 'Unit price ascending',
    UNIT_DESC = 'Unit price descending',
    ENDING_SOON = 'Ending soon',
}
local OPTION_VALUES = {
    ['Alle'] = 'ALL',
    ['Alle Klassen'] = 'ALL_CLASSES',
    ['Alle Berufe'] = 'ALL_PROFESSIONS',
    ['Name A–Z'] = 'NAME',
    ['Level aufsteigend'] = 'LEVEL_ASC',
    ['Level absteigend'] = 'LEVEL_DESC',
    ['Zuletzt gesehen'] = 'LAST_SEEN',
    ['Keine Angabe'] = 'NONE',
    ['Tank'] = 'TANK',
    ['Heiler'] = 'HEALER',
    ['DD'] = 'DAMAGER',
    ['PvP'] = 'PVP',
    ['Dungeons'] = 'DUNGEON',
    ['Raids'] = 'RAID',
    ['Eigene Aktivität'] = 'CUSTOM',
    ['Alle Kategorien'] = 'ALL_CATEGORIES',
    ['Alle Aktivitäten'] = 'ALL_ACTIVITIES',
    ['Alle Gebiete'] = 'ALL_ZONES',
    ['Nur meine aktuelle Zone'] = 'CURRENT_ZONE',
    ['Verkaufen'] = 'SELL',
    ['Kaufen'] = 'BUY',
    ['Dienstleistung'] = 'SERVICE',
    ['Letzte 7 Tage'] = 'DAYS_7',
    ['Letzte 30 Tage'] = 'DAYS_30',
    ['Letzte 90 Tage'] = 'DAYS_90',
    ['Alle Bereiche'] = 'ALL_KINDS',
    ['Gruppen'] = 'GROUP',
    ['Questhilfe'] = 'QUEST',
    ['Alle Charaktere'] = 'ALL_CHARACTERS',
    ['Alle Gegenstandskategorien'] = 'ALL_ITEM_CATEGORIES',
    ['Waffen'] = 'WEAPON',
    ['Rüstung'] = 'ARMOR',
    ['Taschen'] = 'CONTAINER',
    ['Verbrauchsgüter'] = 'CONSUMABLE',
    ['Materialien'] = 'TRADE_GOODS',
    ['Munition'] = 'PROJECTILE',
    ['Rezepte'] = 'RECIPE',
    ['Questgegenstände'] = 'QUEST_ITEM',
    ['Sonstiges'] = 'MISC',
    ['Nicht zugeordnet'] = 'UNCLASSIFIED',
    ['Stückpreis aufsteigend'] = 'UNIT_ASC',
    ['Stückpreis absteigend'] = 'UNIT_DESC',
    ['Endet bald'] = 'ENDING_SOON',
}
OPTION_LABELS.FAVORITES = 'Favorites'
OPTION_LABELS.ONLINE_FIRST = 'Online first'
local function canonicalOption(value)
    return OPTION_VALUES[value] or value
end
S.canonicalOption = canonicalOption
local function displayValue(value)
    if OPTION_LABELS[value] then
        return tr(OPTION_LABELS[value])
    end
    if value == 'TANK' or value == 'HEALER' or value == 'DAMAGER' then
        return I.Role(value)
    end
    if
        value == 'WARRIOR'
        or value == 'PALADIN'
        or value == 'HUNTER'
        or value == 'ROGUE'
        or value == 'PRIEST'
        or value == 'SHAMAN'
        or value == 'MAGE'
        or value == 'WARLOCK'
        or value == 'DRUID'
    then
        return I.Class(nil, value)
    end
    if I and I.activities and I.activities[value] then
        return I.Activity(value)
    end
    return tr(value)
end
S.displayValue = displayValue
local ADDON_CATALOG = {
    {
        addon = 'ZenialCrit',
        label = 'Crit',
        description = 'Crit and last-hit effects with graphics, sound and a freely selectable position.',
        slash = 'ZENIALCRIT',
        icon = 'Interface\\AddOns\\ZenialCrit\\Media\\Icon.tga',
    },
    {
        addon = 'ZenialGunSound',
        label = 'GunSound',
        description = 'Local gunfire and reload sounds with random or fixed selection.',
        slash = 'ZENIALGUNSOUND',
        icon = 'Interface\\AddOns\\ZenialGunSound\\Media\\Icon.tga',
    },
    {
        addon = 'ZenialDevLogger',
        label = 'DevLogger',
        description = 'Local event and API capture for addon development.',
        slash = 'ZENIALDEVLOGGER',
        icon = 'Interface\\AddOns\\ZenialDevLogger\\Media\\Icon.tga',
    },
    {
        addon = 'ZenialClassFrames',
        label = 'ClassFrames',
        description = 'Class colors for player nameplates and group level settings.',
        slash = 'ZENIALCLASSFRAMES',
        icon = 'Interface\\AddOns\\ZenialClassFrames\\Media\\Icon.tga',
    },
    {
        addon = 'ZenialWatch',
        label = 'Watch',
        description = 'Enemy targeting and observed stealth alerts with nearby players and local history.',
        slash = 'ZENIALWATCH',
        icon = 'Interface\\AddOns\\ZenialWatch\\Media\\Icon.tga',
    },
    {
        addon = 'ZenialUtility',
        label = 'Utility',
        description = 'Macro browser, hidden graphics settings, map reveal and small everyday helpers.',
        slash = 'ZENIALUTILITY',
        icon = 'Interface\\AddOns\\ZenialUtility\\Media\\Icon.tga',
    },
}
S.ADDON_CATALOG = ADDON_CATALOG
U.AddonCatalog = ADDON_CATALOG
local function remember(f, parent, kind)
    U.layoutWidgets = U.layoutWidgets or {}
    U.layoutWidgets[#U.layoutWidgets + 1] = { frame = f, parent = parent, kind = kind }
    return f
end
local function label(parent, text, x, y, w, font)
    text = tr(text or '')
    local f = T and T.Text(parent, text, font or 'GameFontHighlightSmall')
        or parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontHighlightSmall')
    if not T then
        f:SetJustifyH('LEFT')
        f:SetJustifyV('TOP')
        f:SetText(text)
    end
    f:SetPoint('TOPLEFT', x, y)
    f:SetWidth(w or 200)
    return remember(f, parent, 'label')
end
S.label = label
local function button(parent, text, x, y, w, fn, variant)
    text = tr(text or '')
    local b = T and T.Button(parent, text, w or 120, 26, fn, variant) or CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    if not T then
        b:SetSize(w or 120, 26)
        b:SetText(text)
        b:SetScript('OnClick', fn or function() end)
    end
    b:SetPoint('TOPLEFT', x, y)
    return remember(b, parent, 'button')
end
S.button = button
local function navButton(parent, text, x, y, w, fn, icon)
    local b = button(parent, text, x, y, w, fn)
    b:SetHeight(30)
    if T then
        if icon then
            T.StyleNav(b, icon)
        else
            T.StyleTab(b)
        end
        T.SetSelected(b, false)
        b.activeLine = b.zenialSelectionLine
        b.activeFill = b.zenialSelection
    end
    return b
end
S.navButton = navButton
local function selectNav(tab, selected)
    if not tab then
        return
    end
    if not tab:IsEnabled() then
        tab:SetEnabled(true)
    end
    tab.selected = selected == true
    if T then
        T.SetSelected(tab, selected)
    end
end
S.selectNav = selectNav
local function mainTabSelected(index, page)
    return index == page
        or index == 10 and page == 3
        or index == 11 and (page == 7 or page == ADDON_PAGE and not U.tabs[ADDON_PAGE]:IsShown())
end
S.mainTabSelected = mainTabSelected
local function updateNavPath()
    if not U.navPath or not U.page then
        return
    end
    local name = MAIN_TAB_NAMES[U.page] or ''
    if U.page == 3 then
        name = tr('Activities')
            .. ' · '
            .. tr(
                ({
                    browse = 'Group details',
                    mine = 'Organized by me',
                    outgoing = 'My applications',
                    follow = 'Follow activities',
                    pvp = 'PvP Help',
                    scheduled = 'Scheduled',
                    today = 'Today',
                })[U.groupView] or 'Group details'
            )
    end
    if U.page == 4 then
        local shared = U.questView == 'shared' or U.questView == 'questgroups'
        name = tr('Quests')
            .. ' · '
            .. tr(U.questView == 'questgroups' and 'Quest groups' or shared and 'Shared quests' or 'Quest assistance')
    end
    U.navPath:SetText(name)
    if U.pageSubtitle then
        U.pageSubtitle:SetText(tr(PAGE_SUBTITLES[U.page] or ''))
    end
end
S.updateNavPath = updateNavPath
local function edit(parent, caption, x, y, w, max, multi)
    local c = label(parent, caption, x, y, w)
    local e = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
    e.caption = c
    e:SetAutoFocus(false)
    e:SetSize(w, multi and 54 or 24)
    e:SetPoint('TOPLEFT', x, y - 17)
    e:SetMaxLetters(max or 64)
    e:SetFontObject('GameFontHighlightSmall')
    if multi then
        e:SetMultiLine(true)
    end
    e:SetScript('OnEscapePressed', function(s)
        s:ClearFocus()
    end)
    if not multi then
        e:SetScript('OnEnterPressed', function(s)
            s:ClearFocus()
        end)
    end
    if T then
        T.StyleEditBox(e)
    end
    return remember(e, parent, 'input')
end
S.edit = edit
local function tabChain(fields)
    for index, field in ipairs(fields) do
        field:SetScript('OnTabPressed', function(self)
            local step = type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() and -1 or 1
            local target = fields[((index - 1 + step) % #fields) + 1]
            self:ClearFocus()
            target:SetFocus()
        end)
    end
end
S.tabChain = tabChain
local function selector(parent, caption, x, y, w, options, changed, formatter)
    local function optionText(value)
        return formatter and formatter(value) or displayValue(value)
    end
    local normalized = {}
    for _, value in ipairs(options or {}) do
        normalized[#normalized + 1] = canonicalOption(value)
    end
    local popupWidth
    local c = label(parent, caption, x, y, w)
    local s = { caption = c, options = normalized, value = '', offset = 1 }
    local b = button(parent, '', x, y - 17, w)
    s.button = b
    local p = CreateFrame('Frame', nil, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    s.popup = p
    p:SetFrameStrata('TOOLTIP')
    p:SetClampedToScreen(true)
    p:SetPoint('TOPLEFT', b, 'BOTTOMLEFT', 0, -2)
    p.rows = {}
    if T then
        T.Panel(p, 'inset')
    elseif p.SetBackdrop then
        p:SetBackdrop({
            bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
            edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        p:SetBackdropColor(0.02, 0.015, 0.01, 0.98)
        p:SetBackdropBorderColor(0.75, 0.55, 0.22, 1)
    end
    local function rebuild()
        local n = math.min(12, #s.options)
        p:SetSize(popupWidth or w, math.max(1, n) * 22 + 8)
        s.offset = math.max(1, math.min(s.offset, math.max(1, #s.options - n + 1)))
        for i = 1, 12 do
            local r = p.rows[i]
            r:SetWidth((popupWidth or w) - 8)
            local v = s.options[s.offset + i - 1]
            if v and i <= n then
                r.value = v
                r:SetText(optionText(v))
                r:Show()
            else
                r:Hide()
            end
        end
    end
    if T and T.CreateScrollBar then
        local draw = rebuild
        local bar = T.CreateScrollBar(p, function(value)
            s.offset = math.floor(value + 0.5) + 1
            rebuild()
        end)
        bar:SetPoint('TOPRIGHT', -4, -4)
        s.scrollBar = bar
        rebuild = function()
            draw()
            local visible = math.min(12, #s.options)
            local maximum = math.max(0, #s.options - visible)
            for _, row in ipairs(p.rows) do
                row:SetWidth((popupWidth or w) - (maximum > 0 and 26 or 8))
            end
            T.UpdateScrollBar(bar, maximum, s.offset - 1, math.max(1, visible) * 22 + 8, math.max(1, #s.options) * 22 + 8)
        end
    end
    for i = 1, 12 do
        local r = button(p, '', 4, -4 - (i - 1) * 22, w - 8, function(self)
            s:SetText(self.value)
            p:Hide()
            S.openPopup = nil
            if changed then
                changed(self.value)
            end
        end)
        r:SetHeight(20)
        p.rows[i] = r
    end
    function s:SetOptions(values, selected)
        self.options = {}
        for _, value in ipairs(values or {}) do
            self.options[#self.options + 1] = canonicalOption(value)
        end
        selected = canonicalOption(selected)
        self.offset = 1
        local found = false
        for _, v in ipairs(self.options) do
            if v == selected then
                found = true
            end
        end
        self:SetText(found and selected or self.options[1] or '')
        rebuild()
    end
    function s:SetText(v)
        self.value = canonicalOption(v or '')
        b:SetText(self.value ~= '' and optionText(self.value) or tr('Select'))
    end
    function s:GetText()
        return self.value
    end
    function s:SetFormatter(fn)
        formatter = fn
        self:SetText(self.value)
        rebuild()
    end
    function s:SetPopupWidth(width)
        popupWidth = width
        rebuild()
    end
    U.layoutSelectors = U.layoutSelectors or {}
    U.layoutSelectors[b] = s
    function s:SetWidth(width)
        w = width
        c:SetWidth(w)
        b:SetWidth(w)
        p:SetWidth(w)
        for _, row in ipairs(p.rows) do
            row:SetWidth(w - 8)
        end
    end
    function s:SetShown(v)
        c:SetShown(v)
        b:SetShown(v)
        if not v then
            p:Hide()
        end
    end
    p:EnableMouseWheel(true)
    p:SetScript('OnMouseWheel', function(_, d)
        s.offset = s.offset - d
        rebuild()
    end)
    b:SetScript('OnClick', function()
        if S.openPopup and S.openPopup ~= p then
            S.openPopup:Hide()
        end
        if p:IsShown() then
            p:Hide()
            S.openPopup = nil
        else
            s.offset = 1
            rebuild()
            p:Show()
            S.openPopup = p
        end
    end)
    if T then
        T.StyleDropdown(b)
    end
    if b.SetTextInsets then
        b:SetTextInsets(8, 30, 0, 0)
    end
    local font = b.GetFontString and b:GetFontString()
    if font then
        font:SetFontObject('GameFontHighlightSmall')
        font:ClearAllPoints()
        font:SetPoint('LEFT', 8, 0)
        font:SetPoint('RIGHT', -30, 0)
        font:SetJustifyH('LEFT')
        font:SetWordWrap(false)
    end
    if T and T.StyleButtonText and font and font.GetFont then
        -- The dropdown caption is smaller than the template default; keep its per-state fonts in step.
        local _, size = font:GetFont()
        T.StyleButtonText(b, type(size) == 'number' and size or nil)
    end
    s:SetOptions(s.options)
    p:Hide()
    return s
end
S.selector = selector
local function checkbox(parent, text, x, y, w, fn)
    local c = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
    c:SetPoint('TOPLEFT', x, y)
    c:SetSize(24, 24)
    local t = label(parent, text, x + 27, y - 4, w - 27)
    c:SetScript('OnClick', fn or function() end)
    c.text = t
    if T then
        T.StyleCheckbox(c)
    end
    return remember(c, parent, 'check')
end
S.checkbox = checkbox
local function list(parent, x, y, w, h)
    local s = CreateFrame('ScrollFrame', nil, parent, 'UIPanelScrollFrameTemplate')
    s:SetPoint('TOPLEFT', x, y)
    s:SetSize(w, h)
    local child = CreateFrame('Frame', nil, s)
    child:SetSize(w - 24, 1)
    s:SetScrollChild(child)
    s.child = child
    s.rows = {}
    s.width = w - 24
    s.height = h
    if T then
        T.StyleScroll(s)
        T.AttachScrollWheel(s, 48)
    end
    return remember(s, parent, 'list')
end
S.list = list
local function plainTooltip(value)
    return (value or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
end
function U.RowTooltipText(row)
    local item = row.zenialItem or {}
    local visible = plainTooltip((item.text or '') .. '\n' .. (item.subtitle or ''))
    local candidate = item.tooltip
    if candidate then
        for line in (candidate .. '\n'):gmatch('(.-)\n') do
            local text = plainTooltip(line)
            if text ~= '' and not visible:find(text, 1, true) then
                return candidate
            end
        end
    end
    local clipped = A.Call(row.text.IsTruncated, row.text) == true
    if item.noWrap and (row.text:GetStringWidth() > row.text:GetWidth()) then
        clipped = true
    end
    if row.subtitle and row.subtitle:IsShown() and row.subtitle:GetStringWidth() > row.subtitle:GetWidth() then
        clipped = true
    end
    if not item.noWrap and row.text:GetStringHeight() > row.text:GetHeight() then
        clipped = true
    end
    if clipped then
        return (item.text or '') .. (item.subtitle and '\n' .. item.subtitle or '')
    end
end
-- Centred, disabled-style hint inside a list that has no rows. `view.zenialEmptyHint` holds the
-- (untranslated) text and is set by the list's producer only where the empty state is not already
-- explained elsewhere on the page; it is translated here so a language change is picked up.
local function updateEmptyHint(view, count)
    local text = view.zenialEmptyHint
    if count > 0 or type(text) ~= 'string' or text == '' then
        if view.zenialEmpty then
            view.zenialEmpty:Hide()
        end
        return
    end
    if not view.zenialEmpty then
        local fs = view:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
        fs:SetPoint('LEFT', view, 'LEFT', 16, 0)
        fs:SetPoint('RIGHT', view, 'RIGHT', -16, 0)
        fs:SetJustifyH('CENTER')
        fs:SetJustifyV('MIDDLE')
        view.zenialEmpty = fs
    end
    view.zenialEmpty:SetText(tr(text))
    view.zenialEmpty:Show()
end
-- Sets (or clears, with nil) the empty-state hint of a list; call before rows().
function U.SetEmptyHint(view, text)
    if view then
        view.zenialEmptyHint = text
    end
end
local function rows(view, items, height)
    view.zenialItems, view.zenialRowHeight = items, height
    updateEmptyHint(view, #items)
    local offsets, sizes, total, variable = {}, {}, 0, false
    for index, item in ipairs(items) do
        offsets[index] = total
        sizes[index] = item.height or height
        total = total + sizes[index]
        if item.height then
            variable = true
        end
    end
    local function render()
        if view.zenialRendering then
            return
        end
        view.zenialRendering = true
        local current = view.zenialItems or {}
        local rowHeight = view.zenialRowHeight or height
        local offset = view.zenialOffset
        if offset == nil and view.GetVerticalScroll then
            offset = view:GetVerticalScroll()
        end
        local contentHeight = math.max(1, total)
        view.child:SetHeight(contentHeight)
        local previous = math.max(0, tonumber(offset) or 0)
        offset = math.max(0, math.min(previous, math.max(0, contentHeight - (view.height or 1))))
        view.zenialOffset = offset
        if offset ~= previous then
            view:SetVerticalScroll(offset)
            local bar = view.ScrollBar or view.scrollBar
            if bar and bar.SetValue then
                bar:SetValue(offset)
            end
        end
        local visible = math.min(#current, math.max(1, math.ceil((view.height or 1) / rowHeight) + 3))
        local first = math.floor(offset / rowHeight) + 1
        first = math.max(1, math.min(first, math.max(1, #current - visible + 1)))
        if variable and #current > 0 then
            local low, high = 1, #current
            while low < high do
                local middle = math.floor((low + high) / 2)
                if offsets[middle] + sizes[middle] <= offset then
                    low = middle + 1
                else
                    high = middle
                end
            end
            first = low
            local last = first
            while last < #current and offsets[last] + sizes[last] < offset + (view.height or 1) do
                last = last + 1
            end
            visible = math.min(#current - first + 1, last - first + 4)
        end
        for slot = 1, visible do
            local index = first + slot - 1
            local item = current[index]
            local b = view.rows[slot]
            local itemHeight = sizes[index] or rowHeight
            if not b then
                b = CreateFrame('Button', nil, view.child)
                b:SetSize(view.width, rowHeight - 3)
                b.text = label(b, '', 7, -5, view.width - 14)
                if T then
                    T.StyleRow(b)
                else
                    b.bg = b:CreateTexture(nil, 'BACKGROUND')
                    b.bg:SetAllPoints()
                    b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
                end
                if GameTooltip and b.HookScript then
                    b:HookScript('OnEnter', function(self)
                        local text = U.RowTooltipText(self)
                        if text then
                            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                            GameTooltip:AddLine(text, 1, 0.9, 0.7, true)
                            GameTooltip:Show()
                        end
                    end)
                    b:HookScript('OnLeave', function()
                        GameTooltip:Hide()
                    end)
                end
                view.rows[slot] = b
            end
            b:SetWidth(view.width)
            b:ClearAllPoints()
            b:SetPoint('TOPLEFT', 0, -offsets[index])
            b:SetHeight(itemHeight - 3)
            b.text:SetHeight(item.subtitle and 14 or item.iconTop and itemHeight - 6 or itemHeight - 10)
            b.text:SetFontObject(item.header and 'GameFontNormalSmall' or 'GameFontHighlightSmall')
            b.text:ClearAllPoints()
            local hasIcon = item.icon ~= nil
            local indent = item.indent or 0
            local textLeft = (item.textInset or (hasIcon and (item.header and 30 or 46) or 8)) + indent
            b.text:SetPoint('TOPLEFT', textLeft, item.iconTop and -3 or -5)
            b.text:SetWidth(view.width - textLeft - 8)
            b.text:SetWordWrap(item.noWrap ~= true)
            b.text:SetText(item.display or item.text)
            b.zenialTooltip = item.tooltip
            -- Keep the match count in a separate line: single-line title
            -- truncation must never hide the subtitle on the native client.
            if item.subtitle then
                if not b.subtitle then
                    b.subtitle = label(b, '', textLeft, -19, view.width - textLeft - 8)
                    if T and T.Tint then
                        T.Tint(b.subtitle, 'SetTextColor', 'dim')
                    end
                end
                b.subtitle:ClearAllPoints()
                b.subtitle:SetPoint('TOPLEFT', textLeft, item.iconTop and -23 or -19)
                b.subtitle:SetWidth(view.width - textLeft - 8)
                b.subtitle:SetHeight(14)
                b.subtitle:SetWordWrap(false)
                b.subtitle:SetText(item.subtitle)
                b.subtitle:Show()
            elseif b.subtitle then
                b.subtitle:Hide()
            end
            if item.favorite then
                if not b.favoriteStar then
                    b.favoriteStar = b:CreateTexture(nil, 'OVERLAY')
                    b.favoriteStar:SetSize(14, 14)
                    b.favoriteStar:SetPoint('TOPRIGHT', -6, -4)
                    b.favoriteStar:SetTexture('Interface\\AddOns\\ZenialCommunity\\Media\\Favorite.tga')
                end
                b.favoriteStar:Show()
                b.text:SetWidth(view.width - textLeft - 28)
            elseif b.favoriteStar then
                b.favoriteStar:Hide()
            end
            if item.sameGuild then
                if not b.guildShield then
                    b.guildShield = b:CreateTexture(nil, 'OVERLAY')
                    b.guildShield:SetSize(14, 14)
                    b.guildShield:SetTexture('Interface\\AddOns\\ZenialCommunity\\Media\\Guild.tga')
                end
                b.guildShield:ClearAllPoints()
                b.guildShield:SetPoint('TOPRIGHT', item.favorite and -24 or -6, -4)
                b.guildShield:Show()
            elseif b.guildShield then
                b.guildShield:Hide()
            end
            -- Reserve room for both badges, including when a row is recycled.
            local badges = (item.favorite and 1 or 0) + (item.sameGuild and 1 or 0)
            b.text:SetWidth(view.width - textLeft - 8 - badges * 20)

            if T then
                -- Selection is an explicit item.selected flag set by the list producer, never inferred from colours.
                T.UpdateRow(b, item)
            else
                local c = item.color or { 0.07, 0.055, 0.035, 0.94 }
                b.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
            end
            if item.accent then
                if not b.accent then
                    b.accent = b:CreateTexture(nil, 'OVERLAY')
                    b.accent:SetPoint('TOPLEFT', 0, -3)
                    b.accent:SetPoint('BOTTOMLEFT', 0, 3)
                    b.accent:SetWidth(3)
                end
                b.accent:SetColorTexture(unpack(item.accent))
                b.accent:Show()
            elseif b.accent then
                b.accent:Hide()
            end
            if b.zenialRowIcon then
                local iconSize = item.iconSize or 30
                b.zenialRowIcon:SetSize(iconSize, iconSize)
                b.zenialRowIcon:ClearAllPoints()
                b.zenialRowIcon:SetPoint(item.iconTop and 'TOPLEFT' or 'LEFT', 8 + indent, item.iconTop and -5 or 0)
            end
            b:RegisterForClicks(item.clickOnDown and 'LeftButtonDown' or 'LeftButtonUp')
            b.zenialItem = item
            b:SetScript('OnClick', item.click or function() end)
            b:Show()
        end
        for slot = visible + 1, #view.rows do
            view.rows[slot]:Hide()
        end
        if T and T.UpdateScroll then
            T.UpdateScroll(view)
        end
        view.zenialRendering = false
    end
    view.zenialRender = render
    if not view.zenialScrollHook then
        view.zenialScrollHook = true
        view:SetScript('OnVerticalScroll', function(self, offset)
            if self.zenialRendering then
                return
            end
            self.zenialOffset = offset
            self:SetVerticalScroll(offset)
            if self.zenialRender then
                self.zenialRender()
            end
        end)
        if view.HookScript then
            view:HookScript('OnMouseWheel', function(self)
                self.zenialOffset = self.GetVerticalScroll and self:GetVerticalScroll() or 0
                if self.zenialRender then
                    self.zenialRender()
                end
            end)
        end
    end
    render()
end
S.rows = rows
local function resizeList(view, w, h)
    view:SetSize(w, h)
    view.width = w - 24
    view.height = h
    view.child:SetWidth(w - 24)
    if view.zenialRender then
        view.zenialRender()
    end
end
S.resizeList = resizeList
local itemIcon
local function itemSuggestions(edit, parent, width, changed, selected)
    local state = { index = 1, id = nil, name = nil, setting = false }
    local popup = CreateFrame('Frame', nil, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    popup:SetPoint('TOPLEFT', edit, 'BOTTOMLEFT', 0, -3)
    popup:SetSize(width, 226)
    popup:SetFrameStrata('TOOLTIP')
    if T then
        T.Panel(popup, 'inset')
    end
    local view = list(popup, 5, -5, width - 10, 216)
    local function choose(row)
        if not row then
            return
        end
        state.setting = true
        state.id, state.name = row.id, row.name
        edit:SetText(row.name)
        state.setting = false
        edit:ClearFocus()
        popup:Hide()
        if selected then
            selected(row.id, row.name)
        end
        if changed then
            changed()
        end
    end
    function state:Refresh(show)
        local suggestions = Z.Items and Z.Items.Suggestions(edit:GetText(), 40) or {}
        self.items = suggestions
        self.index = math.max(1, math.min(self.index, #suggestions))
        local display = {}
        for i, row in ipairs(suggestions) do
            local item = row
            display[i] = {
                selected = i == self.index,
                clickOnDown = true,
                icon = itemIcon(row.id),
                text = row.name .. '\n' .. displayValue(Z.Items.Category(row.id)),
                click = function()
                    self.index = i
                    choose(item)
                end,
            }
        end
        rows(view, display, 42)
        popup:SetShown(show == true and #suggestions > 0)
    end
    function state:Set(id, name)
        self.id = tonumber(id)
        self.name = name
        self.setting = true
        edit:SetText(name or '')
        self.setting = false
        popup:Hide()
    end
    edit:SetScript('OnTextChanged', function(self)
        if state.setting then
            return
        end
        if state.name ~= self:GetText() then
            state.id, state.name = nil, nil
            if selected then
                selected(nil, nil)
            end
        end
        local raw = self:GetText() or ''
        if raw:find('|Hitem:', 1, true) or raw:match('^%s*%d+%s*$') then
            local id, name = A.ResolveItem(raw)
            if id and id > 0 then
                Z.Items.Observe(id, name)
            end
        end
        if changed then
            changed()
        end
        state:Refresh(self:HasFocus())
    end)
    edit:SetScript('OnEditFocusGained', function()
        state:Refresh(true)
    end)
    edit:SetScript('OnEditFocusLost', function()
        if not popup:IsShown() then
            return
        end
        -- Focus loss can precede the row's mouse-down click. Wait until the
        -- next update so selection finishes even on clients without C_Timer.
        popup:SetScript('OnUpdate', function(self)
            self:SetScript('OnUpdate', nil)
            if not edit:HasFocus() then
                self:Hide()
            end
        end)
    end)
    popup:SetScript('OnHide', function(self)
        self:SetScript('OnUpdate', nil)
    end)
    edit:SetScript('OnArrowPressed', function(_, direction)
        local step = direction == 'UP' and -1 or 1
        state.index = math.max(1, math.min(#(state.items or {}), state.index + step))
        state:Refresh(true)
    end)
    edit:SetScript('OnEnterPressed', function(self)
        if popup:IsShown() and state.items and state.items[state.index] then
            choose(state.items[state.index])
        else
            self:ClearFocus()
        end
    end)
    edit:SetScript('OnEscapePressed', function(self)
        popup:Hide()
        self:ClearFocus()
    end)
    popup:Hide()
    state.popup, state.view = popup, view
    return state
end
S.itemSuggestions = itemSuggestions
local function keys(t)
    local a = {}
    for k in pairs(t or {}) do
        a[#a + 1] = k
    end
    table.sort(a)
    return a
end
S.keys = keys
local function contains(t, v)
    for _, x in ipairs(t) do
        if x == v then
            return true
        end
    end
end
local function peerOnline(key)
    return Z.IsOnline and Z.IsOnline(key) or key == Z.me.key
end
S.peerOnline = peerOnline
local function faction(v)
    return tr(v)
end
S.faction = faction
local function age(t)
    if not t then
        return tr('never')
    end
    local minutes = math.max(0, math.floor((A.Now() - t) / 60))
    if minutes < 1 then
        return tr('just now')
    end
    if minutes < 60 then
        return Z.T('%d min ago', minutes)
    end
    if minutes < 1440 then
        return Z.T('%d h ago', math.floor(minutes / 60 + 0.5))
    end
    local days = math.floor(minutes / 1440 + 0.5)
    return days == 1 and tr('1 day ago') or Z.T('%d days ago', days)
end
S.age = age
local function roleName(v)
    return I.Role(L.Role(v) or v)
end
S.roleName = roleName
itemIcon = function(itemID)
    if not itemID or tonumber(itemID) == 0 then
        return nil
    end
    local fn = C_Item and C_Item.GetItemIconByID or GetItemIcon
    local icon = A.Call(fn, tonumber(itemID))
    if type(icon) == 'number' or type(icon) == 'string' and icon ~= '' then
        return { file = icon }
    end
end
S.itemIcon = itemIcon
local function activityName(v)
    return I.Activity(L.ActivityID(v))
end
S.activityName = activityName
U.ActivityName = activityName
local function activityCategory(v)
    v = L.ActivityID(v)
    if contains(PVP, v) then
        return 'PVP'
    elseif contains(DUNGEONS, v) then
        return 'DUNGEON'
    elseif contains(RAIDS, v) then
        return 'RAID'
    end
    return 'CUSTOM'
end
S.activityCategory = activityCategory
local function groupCategory(v)
    return activityCategory(v)
end
S.groupCategory = groupCategory
local function stateName(v)
    return I.State(L.ApplicationState(v) or v)
end
S.stateName = stateName
local function groupHave(value)
    if value == 'SOLO' or value == tr('Solo') then
        return tr('Solo')
    elseif value == 'UNASSIGNED' or value == tr('Rollen nicht zugewiesen') then
        return tr('Role not assigned')
    end
    local out = {}
    for token, count in tostring(value or ''):gmatch('([A-Z]+)=(%d+)') do
        out[#out + 1] = count .. ' ' .. roleName(token)
    end
    return #out > 0 and table.concat(out, ', ') or tostring(value or '')
end
S.groupHave = groupHave
U.FormatGroupHave = groupHave
local function deliveryState(kind, id, key)
    local latest
    for _, entry in ipairs(H and H.byPeer and H.byPeer[key] or {}) do
        if
            entry.kind == kind
            and entry.contentID == id
            and (entry.event == 'application_queued' or entry.event == 'application_delivered' or entry.event == 'application_failed')
            and (not latest or entry.at > latest.at or entry.at == latest.at and entry.id > latest.id)
        then
            latest = entry
        end
    end
    return latest
            and tr(
                (
                    {
                        application_queued = 'Delivery pending',
                        application_delivered = 'Transport confirmed',
                        application_failed = 'Delivery failed',
                    }
                )[latest.event]
            )
        or tr('Status transfer unknown')
end
S.deliveryState = deliveryState
local function panel(parent)
    local f = CreateFrame('Frame', nil, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    f:SetAllPoints()
    if T then
        -- Panels on the window itself (or inside another dialog) are dialogs; panels on a page are cards.
        if parent == U.frame or parent.zenialShellSkin then
            T.Shell(f)
        else
            T.Panel(f, 'surface')
        end
    end
    return f
end
S.panel = panel
local function panelContent(parent)
    local f = CreateFrame('Frame', nil, parent)
    f:SetPoint('TOPLEFT', 12, -12)
    f:SetPoint('BOTTOMRIGHT', -12, 12)
    return f
end
S.panelContent = panelContent
function U.Message(text)
    if U.status then
        U.status:SetText(tr(text or ''))
    end
end
-- Short success toast (bottom right of the window); the status line keeps carrying the same message.
function U.Toast(text)
    if U.statusToast and U.frame and U.frame:IsShown() then
        U.statusToast:Notify(tr(text or ''))
    end
end
function U.NotifyTradeAlerts(count)
    U.Message((count or 1) .. tr(' neuer Handelstreffer'))
    A.PlayApplicationSound()
end
function U.Publish()
    L.Touch(Z.db)
    Z.Publish()
    if Z.RefreshLocation then
        Z.RefreshLocation(true)
    end
    U.Refresh()
end

