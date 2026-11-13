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
        U.frame:SetSize(1060, 690)
        U.Layout()
    end)
    button(U.profileDisplayFrame, tr('Position zurücksetzen'), 198, -70, 190, function()
        Z.db.position = nil
        Z.db.scale = 1
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
    U.profileNetworkText = label(U.profileNetworkFrame, '', 16, -44, 516, 'GameFontHighlight')
    U.profileNetworkText:SetFontObject('GameFontHighlightSmall')
    U.profileNetworkText:SetHeight(214)
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
        U.profileNetworkText:SetText(Z.NetworkSetup.UserSummary())
    end)
    U.profileDiagnosticButton = button(U.profileNetworkFrame, 'Technical details', 166, -314, 175, U.ShowDiagnostics)

    -- Integrations: Addon Manager, Companion, navigation shortcut, notification hints.
    U.settingsToolsFrame = CreateFrame('Frame', nil, p)
    U.settingsToolsFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsToolsFrame:SetSize(856, 414)
    plate(U.settingsToolsFrame, 0, 0, 270, 112)
    plate(U.settingsToolsFrame, 282, 0, 568, 112)
    plate(U.settingsToolsFrame, 0, 124, 850, 44)
    plate(U.settingsToolsFrame, 0, 180, 850, 126)
    heading(U.settingsToolsFrame, 'Addon Manager', 16, -14, 240)
    U.settingsAddon = button(U.settingsToolsFrame, tr('Open Addon Manager'), 16, -40, 238, function() U.Navigate('addons') end)
    U.settingsAddon:SetEnabled((U.addonAvailableCount or 0) > 0)
    heading(U.settingsToolsFrame, 'Companion', 298, -14, 350)
    button(U.settingsToolsFrame, tr('Open Companion'), 298, -40, 240, function() Z.Companion.Show() end)
    U.settingsCompanionSummary = label(U.settingsToolsFrame, '', 298, -76, 536, 'GameFontHighlightSmall')
    U.settingsCompanionSummary:SetHeight(28)
    U.settingsToolsFrame:HookScript('OnShow', U.RefreshSettingsCompanionSummary)
    U.homeAddonNavigationOption = checkbox(U.settingsToolsFrame, tr('Show Addon Manager in the left navigation'), 12, -134, 520, function(self)
        U.SetAddonManagerNavigation(self:GetChecked() == true)
    end)
    heading(U.settingsToolsFrame, 'Notifications', 16, -194, 300)
    label(U.settingsToolsFrame, tr('Use the bell in the window header for notifications. PvP receiving is controlled in the existing PvP option.'), 16, -216, 800, 'GameFontHighlightSmall')
    label(U.settingsToolsFrame, tr('Map, minimap and slash command entry points remain available.'), 16, -246, 800, 'GameFontHighlightSmall')
    U.finderNoticeOption = checkbox(U.settingsToolsFrame, tr('Show a notice when a group opens for an activity I follow'), 12, -270, 700, function(self)
        if Z.ui then
            Z.ui.finderNotices = self:GetChecked() == true
        end
    end)
    U.finderNoticeOption:SetChecked(not Z.ui or Z.ui.finderNotices ~= false)

    -- History and categories (the categories button is added by CategorySettingsUI.lua at 430, -52).
    U.settingsDataFrame = CreateFrame('Frame', nil, p)
    U.settingsDataFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsDataFrame:SetSize(856, 414)
    plate(U.settingsDataFrame, 0, 0, 850, 96)
    heading(U.settingsDataFrame, 'History and categories', 16, -14, 400)
    button(U.settingsDataFrame, tr('History'), 16, -52, 240, function() U.OpenHistory() end)
    U.profileDisplayFrame:SetParent(p)
    U.profileNetworkFrame:SetParent(p)
    U.SetSettingsView('display', true)
    U.LayoutSettings()
end

function U.RefreshSettingsCompanionSummary()
    if not U.settingsCompanionSummary or not Z.Companion or not Z.Companion.Status then return end
    local status = Z.Companion.Status()
    local states = { disabled = 'Disabled', blocked = 'Export stopped',
        ['logging-required'] = 'Chat logging required', probing = 'Connection probe',
        unverified = 'Export active' }
    U.settingsCompanionSummary:SetText(tr('Status: ') .. tr(states[status.state] or status.state or '') .. ' · '
        .. tr('Account-wide export for all characters, including chat and private notes.'))
end

function U.SetSettingsView(v, skipRoute)
    local allowed = { display = true, privacy = true, tools = true, data = true }
    U.settingsView = allowed[v] and v or 'display'
    U.settingsDisplayFrame:SetShown(U.settingsView == 'display')
    U.settingsPrivacyFrame:SetShown(U.settingsView == 'privacy')
    U.settingsToolsFrame:SetShown(U.settingsView == 'tools')
    U.settingsDataFrame:SetShown(U.settingsView == 'data')
    for name, tab in pairs(U.settingsTabs) do
        U.Shared.selectNav(tab, U.settingsView == name)
    end
    if U.settingsView == 'privacy' and U.profileNetworkText then
        U.profileNetworkText:SetText(Z.NetworkSetup.UserSummary())
    end
    U.RefreshSettingsCompanionSummary()
    if U.RefreshCrossFactionSettings then
        U.RefreshCrossFactionSettings()
    end
    U.LayoutSettings()
    if not skipRoute and Z.UIState then
        Z.UIState.Route('settings', U.settingsView)
    end
end
