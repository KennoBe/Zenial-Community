local Z = ZenialCommunity
local U = Z.UI
local tr = U.Shared.tr

-- Card plates behind the groups of each settings view: { plate, x, y, width, height } in the logical
-- 856-wide coordinates the controls are created in. U.LayoutSettings scales them with the page width.
local PLATES = {}
U.settingsPlates = PLATES
local function plate(frame, x, y, width, height)
    local K = Z.Kit
    if not (K and K.Plate) then
        return
    end
    PLATES[frame] = PLATES[frame] or {}
    table.insert(PLATES[frame], { K.Plate(frame, 'surface'), x, y, width, height })
end
function U.LayoutSettings()
    for frame, list in pairs(PLATES) do
        local horizontal = frame:GetWidth() / 856
        for _, spec in ipairs(list) do
            spec[1]:Place(spec[2] * horizontal, spec[3], spec[4] * horizontal, spec[5])
        end
    end
end

-- Summary line and connection table of the privacy view.
local STATE_COLORS = { ok = 'online', warn = 'warning', bad = 'dangerText', idle = 'dim' }
function U.RefreshConnectionOverview()
    if not U.profileNetworkText then
        return
    end
    U.profileNetworkText:SetText(Z.NetworkSetup.UserSummary())
    local rows = Z.NetworkSetup.ConnectionRows and Z.NetworkSetup.ConnectionRows() or {}
    local T, age = Z.Theme, U.Shared.age
    for index, cells in ipairs(U.connectionRows or {}) do
        local row = rows[index]
        cells.name:SetText(row and row.label or '')
        cells.shared:SetText(row and row.shared or '')
        cells.online:SetText(row and row.online and tostring(row.online) or (row and '–' or ''))
        cells.status:SetText(row and row.status or '')
        cells.rx:SetText(row and age(row.rx) or '')
        cells.tx:SetText(row and age(row.tx) or '')
        if T and T.Tint then
            T.Tint(cells.status, 'SetTextColor', STATE_COLORS[row and row.state] or 'dim')
        end
    end
end
function U.CreateSettings(helpers)
    local label, button, checkbox = helpers.label, helpers.button, helpers.checkbox
    local T, K = Z.Theme, Z.Kit
    -- Group heading inside a plate: small upper-case label in the dim gold.
    local function heading(parent, key, x, y, width)
        local text = tr(key)
        local caption = label(parent, K and K.Upper(text) or text, x, y, width, 'GameFontHighlightSmall')
        caption:SetHeight(12)
        if T and T.Font then
            T.Font(caption, 'overline', 'goldDim')
        end
        return caption
    end
    local p = U.pages[11]
    local tabs = {
        { 'display', 'Display settings', 0, 140 },
        { 'privacy', 'Connection and privacy', 148, 210 },
        { 'tools', 'Integrations', 366, 150 },
        { 'data', 'History and categories', 524, 210 },
        { 'rivalry', 'Rivalry', 742, 114 },
    }
    U.settingsTabs = {}
    for _, spec in ipairs(tabs) do
        U.settingsTabs[spec[1]] = helpers.navButton(p, tr(spec[2]), spec[3], 0, spec[4], function()
            U.SetSettingsView(spec[1])
        end)
    end

    -- Display: window size and position.
    U.settingsDisplayFrame = CreateFrame('Frame', nil, p)
    U.settingsDisplayFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsDisplayFrame:SetSize(856, 414)
    U.profileDisplayFrame = U.settingsDisplayFrame
    -- The plate also carries the account-wide cross-faction section below the appearance controls.
    plate(U.profileDisplayFrame, 0, 0, 850, 390)
    heading(U.profileDisplayFrame, 'APPEARANCE', 16, -14, 400)
    label(U.profileDisplayFrame, tr('Fenster: 1060 × 690 Standard · mindestens 900 × 610'), 16, -40, 600, 'GameFontHighlight')
    button(U.profileDisplayFrame, tr('Standardgröße'), 16, -70, 170, function()
        local bounds = U.resizeBounds or { 900, 610, 1280, 860 }
        U.frame:SetSize(math.max(bounds[1], math.min(1060, bounds[3])), math.max(bounds[2], math.min(690, bounds[4])))
        U.Layout()
    end)
    button(U.profileDisplayFrame, tr('Position zurücksetzen'), 198, -70, 190, function()
        Z.db.position = nil
        U.frame:SetScale(1)
        U.frame:ClearAllPoints()
        U.frame:SetPoint('CENTER')
    end)

    -- Cross-faction: account-wide switches (ZenialCommunityDB.crossFaction), appended below the appearance group.
    -- Without Z.CrossFaction the section is simply absent.
    if Z.CrossFaction then
        local function note(text, y)
            local line = label(U.profileDisplayFrame, tr(text), 40, y, 790, 'GameFontHighlightSmall')
            line:SetHeight(28)
            line:SetWordWrap(true)
            if T and T.Tint then
                T.Tint(line, 'SetTextColor', 'dim')
            end
            return line
        end
        U.crossFactionOptions = {}
        local function option(name, text, y)
            local control = checkbox(U.profileDisplayFrame, text, 12, y, 810, function(self)
                local XF = Z.CrossFaction
                if XF and XF.SetSetting then
                    XF.SetSetting(name, self:GetChecked() == true)
                end
                local badge = Z.CrossFactionTargetBadge
                if badge and type(badge.Refresh) == 'function' then
                    pcall(badge.Refresh)
                end
            end)
            U.crossFactionOptions[name] = control
            return control
        end
        heading(U.profileDisplayFrame, 'Cross-faction', 16, -128, 400)
        option('enabled', 'Enable cross-faction chat (/z, /zy)', -148)
        note('Messages sent with /z are visible to everyone nearby as coded words. Only players with ZENIAL Community can read them.', -176)
        option('discovery', 'Detect ZENIAL players automatically', -208)
        note('Sends an invisible addon signal to your group, guild, target and nearby players. No chat message is sent.', -236)
        option('chatIcons', 'Show ZENIAL icons in chat', -268)
        option('targetIcon', 'Show ZENIAL icon on target', -296)
        note('No icon does not mean a player has no ZENIAL addon. It only means no signal has been received yet.', -324)
        -- Only offered once the Battle.net signal is released; evaluated whenever the view is shown.
        option('bnetDiscovery', 'Detect ZENIAL players through Battle.net', -356)
        function U.RefreshCrossFactionSettings()
            local XF = Z.CrossFaction
            if not (XF and XF.Settings) then
                return
            end
            local values = XF.Settings()
            local presence = Z.CrossFactionPresence
            local unlocked = type(presence) == 'table' and presence.BNET_UNLOCKED == true
            for name, control in pairs(U.crossFactionOptions) do
                control:SetChecked(values[name] == true)
                if name == 'bnetDiscovery' then
                    control:SetShown(unlocked)
                    control.text:SetShown(unlocked)
                end
            end
        end
        U.profileDisplayFrame:HookScript('OnShow', U.RefreshCrossFactionSettings)
        U.RefreshCrossFactionSettings()
    end

    -- Connection and privacy: connection summary on the left, sharing switches on the right.
    U.settingsPrivacyFrame = CreateFrame('Frame', nil, p)
    U.settingsPrivacyFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsPrivacyFrame:SetSize(856, 414)
    U.profileNetworkFrame = U.settingsPrivacyFrame
    plate(U.profileNetworkFrame, 0, 0, 548, 268)
    plate(U.profileNetworkFrame, 562, 0, 288, 348)
    plate(U.profileNetworkFrame, 0, 280, 548, 68)
    heading(U.profileNetworkFrame, 'Connection', 16, -14, 290)
    U.networkSetupButton = button(U.profileNetworkFrame, 'Community connection', 322, -8, 210, function()
        Z.NetworkSetup.Show()
    end)
    U.profileNetworkText = label(U.profileNetworkFrame, '', 16, -40, 516, 'GameFontHighlight')
    U.profileNetworkText:SetFontObject('GameFontHighlightSmall')
    U.profileNetworkText:SetHeight(16)
    -- Connection table: one row per kind of connection.
    local columns = { { 'Connection', 16, 170 }, { 'Online', 190, 40 }, { 'Status', 234, 130 }, { 'Received', 368, 84 }, { 'Sent', 456, 80 } }
    for _, column in ipairs(columns) do
        local caption = label(U.profileNetworkFrame, K and K.Upper(tr(column[1])) or tr(column[1]), column[2], -62, column[3], 'GameFontHighlightSmall')
        caption:SetHeight(12)
        if T and T.Font then
            T.Font(caption, 'overline', 'goldDim')
        end
    end
    U.connectionRows = {}
    for index = 1, 7 do
        local y = -78 - (index - 1) * 26
        local row = {}
        row.name = label(U.profileNetworkFrame, '', 16, y, 170, 'GameFontHighlightSmall')
        row.shared = label(U.profileNetworkFrame, '', 16, y - 12, 170, 'GameFontHighlightSmall')
        row.online = label(U.profileNetworkFrame, '', 190, y, 40, 'GameFontHighlightSmall')
        row.status = label(U.profileNetworkFrame, '', 234, y, 130, 'GameFontHighlightSmall')
        row.rx = label(U.profileNetworkFrame, '', 368, y, 84, 'GameFontHighlightSmall')
        row.tx = label(U.profileNetworkFrame, '', 456, y, 80, 'GameFontHighlightSmall')
        for _, field in ipairs({ 'name', 'shared', 'online', 'status', 'rx', 'tx' }) do
            row[field]:SetHeight(12)
            row[field]:SetWordWrap(false)
        end
        if T and T.Font then
            T.Font(row.shared, 'caption', 'dim')
        end
        U.connectionRows[index] = row
    end
    U.preferences = {}
    for index, spec in ipairs({ { 'visible', 'Visible profile' }, { 'shareProfessions', 'Share professions and recipes' } }) do
        local name = spec[1]
        local control = checkbox(U.profileNetworkFrame, spec[2], 574, -36 - (index - 1) * 40, 262, function(self)
            Z.SetPreference(name, self:GetChecked())
            U.Refresh()
        end)
        control:SetChecked(Z.db[name])
        U.preferences[name] = control
    end
    U.settingsVisibleNote = label(U.profileNetworkFrame, tr('When enabled, your display name, class, level, guild, roles, note, group listing, quest request, trade offers, main and alts are shared with other players. Professions and recipes are shared only when the second setting is enabled. When disabled, those details are omitted. Character name, realm, faction, online presence and PvP receiving marker remain visible.'), 578, -124, 256, 'GameFontHighlightSmall')
    U.settingsVisibleNote:SetHeight(212)
    U.settingsVisibleNote:SetWordWrap(true)
    if T and T.Tint then
        T.Tint(U.settingsVisibleNote, 'SetTextColor', 'dim')
    end
    heading(U.profileNetworkFrame, 'Privacy', 578, -14, 256)
    heading(U.profileNetworkFrame, 'Diagnostics and backups', 16, -292, 380)
    button(U.profileNetworkFrame, tr('Aktualisieren'), 16, -314, 140, function()
        U.RefreshConnectionOverview()
    end)
    U.profileDiagnosticButton = button(U.profileNetworkFrame, 'Technical details', 166, -314, 175, U.ShowDiagnostics)

    -- Integrations: Addon Manager, Companion, navigation shortcut, notification hints.
    U.settingsToolsFrame = CreateFrame('Frame', nil, p)
    U.settingsToolsFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsToolsFrame:SetSize(856, 414)
    plate(U.settingsToolsFrame, 0, 0, 270, 112)
    plate(U.settingsToolsFrame, 282, 0, 568, 112)
    plate(U.settingsToolsFrame, 0, 124, 850, 44)
    plate(U.settingsToolsFrame, 0, 180, 850, 96)
    heading(U.settingsToolsFrame, 'Addon Manager', 16, -14, 240)
    U.settingsAddon = button(U.settingsToolsFrame, tr('Open Addon Manager'), 16, -40, 238, function() U.Navigate('addons') end)
    U.settingsAddon:SetEnabled((U.addonAvailableCount or 0) > 0)
    heading(U.settingsToolsFrame, 'Companion', 298, -14, 350)
    button(U.settingsToolsFrame, tr('Open Companion'), 298, -40, 240, function() Z.Companion.Show() end)
    button(U.settingsToolsFrame, tr('Zenial Deck'), 550, -40, 284, function() if Z.DeckUI then Z.DeckUI.Show() end end)
    U.settingsCompanionSummary = label(U.settingsToolsFrame, '', 298, -76, 536, 'GameFontHighlightSmall')
    U.settingsCompanionSummary:SetHeight(28)
    U.settingsToolsFrame:HookScript('OnShow', U.RefreshSettingsCompanionSummary)
    U.homeAddonNavigationOption = checkbox(U.settingsToolsFrame, tr('Show Addon Manager in the left navigation'), 12, -134, 520, function(self)
        U.SetAddonManagerNavigation(self:GetChecked() == true)
    end)
    U.publicGroupsOption = checkbox(U.settingsToolsFrame, tr('Show public groups of the game in the group finder'), 12, -160, 520, function(self)
        local on = self:GetChecked() == true
        if Z.ui then
            Z.ui.finderPublic = on
        end
        Z.SetPublicLFG(on)
        U.Message(tr(on and 'Public groups of the game are shown in the group finder.' or 'Public groups of the game are hidden.'))
    end)
    U.publicGroupsOption:SetChecked(not Z.ui or Z.ui.finderPublic ~= false)
    heading(U.settingsToolsFrame, 'Notifications', 16, -194, 300)
    -- Pop-up and sound for new groups of followed instances (the bell in the head of an instance follows it).
    -- Off: the notice still goes into the bell of the window.
    U.groupNoticesOption = checkbox(U.settingsToolsFrame, tr('Show a pop-up for new groups of instances you follow'), 12, -214, 520, function(self)
        local on = self:GetChecked() == true
        if Z.ui then
            Z.ui.finderNotices = on
        end
        U.Message(tr(on and 'Notices for new groups of followed activities are on.' or 'Notices for new groups of followed activities are off. They stay in the bell.'))
    end)
    U.groupNoticesOption:SetChecked(not Z.ui or Z.ui.finderNotices ~= false)
    label(U.settingsToolsFrame, tr('Use the bell in the window header for notifications. PvP receiving is controlled in the existing PvP option.'), 16, -244, 800, 'GameFontHighlightSmall')
    label(U.settingsToolsFrame, tr('Map, minimap and slash command entry points remain available.'), 16, -274, 800, 'GameFontHighlightSmall')

    -- History and categories (the categories button is added by CategorySettingsUI.lua at 430, -52).
    U.settingsDataFrame = CreateFrame('Frame', nil, p)
    U.settingsDataFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsDataFrame:SetSize(856, 414)
    plate(U.settingsDataFrame, 0, 0, 850, 96)
    heading(U.settingsDataFrame, 'History and categories', 16, -14, 400)
    button(U.settingsDataFrame, tr('History'), 16, -52, 240, function() U.OpenHistory() end)
    -- Social diary: the rating card that follows a dungeon together (RatingPrompt.lua). The diary itself is always on.
    plate(U.settingsDataFrame, 0, 108, 850, 66)
    heading(U.settingsDataFrame, 'Social diary', 16, -122, 400)
    U.diaryPromptOption = checkbox(U.settingsDataFrame, tr('Ask for a rating after dungeons'), 12, -140, 520, function(self)
        local diary = Z.SocialDiary
        if diary and diary.SetPrompt then
            diary.SetPrompt(self:GetChecked() == true)
        end
        U.RefreshDiarySettings()
    end)
    function U.RefreshDiarySettings()
        local diary = Z.SocialDiary
        local available = diary ~= nil and diary.Enabled ~= nil and diary.Enabled()
        U.diaryPromptOption:SetChecked(available and diary.PromptEnabled())
        U.diaryPromptOption:SetEnabled(available)
    end
    U.settingsDataFrame:HookScript('OnShow', U.RefreshDiarySettings)
    -- Rivalry: banner of the private PvP history and deleting this character's history (Rivalry.lua, RivalryBanner.lua).
    U.settingsRivalryFrame = CreateFrame('Frame', nil, p)
    U.settingsRivalryFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsRivalryFrame:SetSize(856, 414)
    if Z.Rivalry then
        local RF = U.settingsRivalryFrame
        plate(RF, 0, 0, 850, 214)
        plate(RF, 0, 226, 850, 120)
        heading(RF, 'Banner', 16, -14, 400)
        U.rivalryChecks = {}
        local function option(name, text, x, y, width)
            U.rivalryChecks[name] = checkbox(RF, text, x, y, width, function(self)
                Z.Rivalry.SetSetting(name, self:GetChecked() == true)
            end)
        end
        option('banner', 'Show banner', 12, -38, 400)
        for index, spec in ipairs({ { 'kills', 'Kills' }, { 'deaths', 'Deaths' }, { 'assists', 'Assists' }, { 'duels', 'Duels' }, { 'animation', 'Animation' }, { 'sound', 'Sound' } }) do
            option(spec[1], spec[2], 12 + (index - 1) * 138, -68, 130)
        end
        local SIZES, TIMES = { '0.8', '0.9', '1', '1.1', '1.25', '1.5' }, { '2', '3', '4', '5', '6', '8' }
        U.rivalryStyle = helpers.selector(RF, 'Style', 16, -108, 200, { 'standard', 'compact' }, function(value)
            Z.Rivalry.SetSetting('style', value)
        end, function(value)
            return tr(value == 'compact' and 'Compact' or 'Standard')
        end)
        U.rivalrySize = helpers.selector(RF, 'Size', 232, -108, 200, SIZES, function(value)
            Z.Rivalry.SetSetting('scale', tonumber(value))
        end, function(value)
            return math.floor(tonumber(value) * 100 + 0.5) .. ' %'
        end)
        U.rivalryDuration = helpers.selector(RF, 'Display time', 448, -108, 200, TIMES, function(value)
            Z.Rivalry.SetSetting('duration', tonumber(value))
        end, function(value)
            return value .. ' s'
        end)
        local previewKinds, previewIndex = { 'K', 'D', 'A', 'W' }, 0
        U.rivalryPreview = button(RF, tr('Preview'), 16, -168, 150, function()
            previewIndex = previewIndex % #previewKinds + 1
            Z.Rivalry.Preview(previewKinds[previewIndex])
        end)
        U.rivalryMove = button(RF, tr('Move banner'), 176, -168, 190, function()
            local banner = Z.RivalryBanner
            if banner and banner.IsUnlocked then
                if banner.IsUnlocked() then
                    banner.Lock()
                else
                    banner.Unlock()
                end
            end
            U.RefreshRivalrySettings()
        end)
        U.rivalryResetPosition = button(RF, tr('Reset position'), 376, -168, 190, function()
            Z.Rivalry.SetPosition(nil)
        end)
        heading(RF, 'PvP history', 16, -240, 400)
        option('tooltip', 'Show record in player tooltips', 12, -262, 400)
        U.rivalryReset = button(RF, tr("Delete this character's history"), 16, -298, 300, function()
            if not U.rivalryResetConfirm then
                U.rivalryResetConfirm = true
                U.RefreshRivalrySettings()
                return
            end
            U.rivalryResetConfirm = false
            if Z.Rivalry.ResetCharacter() then
                U.Message(tr('History deleted.'))
            end
            U.RefreshRivalrySettings()
        end, 'danger')
        U.rivalryResetCancel = button(RF, tr('Cancel'), 324, -298, 110, function()
            U.rivalryResetConfirm = false
            U.RefreshRivalrySettings()
        end)
        local function nearest(options, value)
            local best, distance = options[1], math.huge
            for _, option in ipairs(options) do
                local gap = math.abs(tonumber(option) - (tonumber(value) or 0))
                if gap < distance then
                    best, distance = option, gap
                end
            end
            return best
        end
        function U.RefreshRivalrySettings()
            local values = Z.Rivalry.Settings()
            for name, control in pairs(U.rivalryChecks) do
                control:SetChecked(values[name] == true)
            end
            U.rivalryStyle:SetText(values.style)
            U.rivalrySize:SetText(nearest(SIZES, values.scale))
            U.rivalryDuration:SetText(nearest(TIMES, values.duration))
            local banner = Z.RivalryBanner
            U.rivalryMove:SetText(tr(banner and banner.IsUnlocked and banner.IsUnlocked() and 'Lock position' or 'Move banner'))
            U.rivalryReset:SetText(tr(U.rivalryResetConfirm and 'Confirm deletion' or "Delete this character's history"))
            U.rivalryResetCancel:SetShown(U.rivalryResetConfirm == true)
        end
        -- The banner can only be moved while this view is open; leaving it (or closing the window) locks it again.
        function U.LockRivalryBanner()
            local banner = Z.RivalryBanner
            if banner and banner.IsUnlocked and banner.IsUnlocked() then
                banner.Lock()
            end
            U.rivalryResetConfirm = false
            if U.rivalryMove then
                U.RefreshRivalrySettings()
            end
        end
        RF:HookScript('OnShow', U.RefreshRivalrySettings)
        RF:HookScript('OnHide', U.LockRivalryBanner)
        p:HookScript('OnHide', U.LockRivalryBanner)
        U.frame:HookScript('OnHide', U.LockRivalryBanner)
        U.RefreshRivalrySettings()
    end
    U.profileDisplayFrame:SetParent(p)
    U.profileNetworkFrame:SetParent(p)
    U.SetSettingsView('display', true)
    U.LayoutSettings()
end

function U.RefreshSettingsCompanionSummary()
    if not U.settingsCompanionSummary or not Z.Companion or not Z.Companion.Status then return end
    local status = Z.Companion.Status()
    local states = { disabled = 'Disabled', blocked = 'Export stopped', unverified = 'Export active' }
    U.settingsCompanionSummary:SetText(tr('Status: ') .. tr(states[status.state] or status.state or '') .. ' · '
        .. tr('Account-wide export for all characters, including chat and private notes.'))
end

function U.SetSettingsView(v, skipRoute)
    local allowed = { display = true, privacy = true, tools = true, data = true, rivalry = true }
    U.settingsView = allowed[v] and v or 'display'
    U.settingsDisplayFrame:SetShown(U.settingsView == 'display')
    U.settingsPrivacyFrame:SetShown(U.settingsView == 'privacy')
    U.settingsToolsFrame:SetShown(U.settingsView == 'tools')
    U.settingsDataFrame:SetShown(U.settingsView == 'data')
    U.settingsRivalryFrame:SetShown(U.settingsView == 'rivalry')
    for name, tab in pairs(U.settingsTabs) do
        U.Shared.selectNav(tab, U.settingsView == name)
    end
    if U.settingsView == 'privacy' and U.profileNetworkText then
        U.RefreshConnectionOverview()
    end
    U.RefreshSettingsCompanionSummary()
    if U.RefreshCrossFactionSettings then
        U.RefreshCrossFactionSettings()
    end
    if U.settingsView == 'rivalry' and U.RefreshRivalrySettings then
        U.RefreshRivalrySettings()
    end
    U.LayoutSettings()
    if not skipRoute and Z.UIState then
        Z.UIState.Route('settings', U.settingsView)
    end
end
