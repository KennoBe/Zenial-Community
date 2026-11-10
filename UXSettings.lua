local Z = ZenialCommunity
local U = Z.UI
local tr = U.Shared.tr

function U.CreateSettings(helpers)
    local label, button, checkbox = helpers.label, helpers.button, helpers.checkbox
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
    U.settingsDisplayFrame = CreateFrame('Frame', nil, p)
    U.settingsDisplayFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsDisplayFrame:SetSize(856, 414)
    U.profileDisplayFrame = U.settingsDisplayFrame
    label(U.profileDisplayFrame, '|cffffd36b' .. tr('APPEARANCE') .. '|r', 0, 0, 400, 'GameFontNormalLarge')
    label(U.profileDisplayFrame, tr('Fenster: 1060 × 690 Standard · mindestens 900 × 610'), 0, -88, 600, 'GameFontHighlight')
    button(U.profileDisplayFrame, tr('Standardgröße'), 0, -125, 170, function()
        U.frame:SetSize(1060, 690)
        U.Layout()
    end)
    button(U.profileDisplayFrame, tr('Position zurücksetzen'), 182, -125, 190, function()
        Z.db.position = nil
        Z.db.scale = 1
        U.frame:SetScale(1)
        U.frame:ClearAllPoints()
        U.frame:SetPoint('CENTER')
    end)

    U.settingsPrivacyFrame = CreateFrame('Frame', nil, p)
    U.settingsPrivacyFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsPrivacyFrame:SetSize(856, 414)
    U.profileNetworkFrame = U.settingsPrivacyFrame
    label(U.profileNetworkFrame, '|cffffd36b' .. Z.T('Community connection') .. '|r', 0, 0, 650, 'GameFontNormalLarge')
    U.profileNetworkText = label(U.profileNetworkFrame, '', 0, -42, 535, 'GameFontHighlight')
    U.profileNetworkText:SetFontObject('GameFontHighlightSmall')
    U.profileNetworkText:SetHeight(240)
    U.preferences = {}
    for index, spec in ipairs({ { 'visible', 'Visible profile' }, { 'shareProfessions', 'Share professions and recipes' } }) do
        local name = spec[1]
        local control = checkbox(U.profileNetworkFrame, spec[2], 570, -42 - (index - 1) * 44, 270, function(self)
            Z.SetPreference(name, self:GetChecked())
            U.Refresh()
        end)
        control:SetChecked(Z.db[name])
        U.preferences[name] = control
    end
    button(U.profileNetworkFrame, tr('Aktualisieren'), 0, -290, 140, function()
        U.profileNetworkText:SetText(Z.NetworkSetup.UserSummary())
    end)
    U.profileDiagnosticButton = button(U.profileNetworkFrame, 'Technical details', 150, -290, 175, U.ShowDiagnostics)
    U.networkSetupButton = button(U.profileNetworkFrame, 'Community connection', 335, -290, 210, function()
        Z.NetworkSetup.Show()
    end)

    U.settingsToolsFrame = CreateFrame('Frame', nil, p)
    U.settingsToolsFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsToolsFrame:SetSize(856, 414)
    U.settingsAddon = button(U.settingsToolsFrame, tr('Addon Manager'), 0, 0, 240, function() U.Navigate('addons') end)
    U.settingsAddon:SetEnabled((U.addonAvailableCount or 0) > 0)
    button(U.settingsToolsFrame, tr('Companion'), 0, -52, 240, function() Z.Companion.Show() end)
    U.homeAddonNavigationOption = checkbox(U.settingsToolsFrame, tr('Show Addon Manager in the left navigation'), 0, -112, 520, function(self)
        U.SetAddonManagerNavigation(self:GetChecked() == true)
    end)

    U.settingsDataFrame = CreateFrame('Frame', nil, p)
    U.settingsDataFrame:SetPoint('TOPLEFT', 0, -42)
    U.settingsDataFrame:SetSize(856, 414)
    button(U.settingsDataFrame, tr('History'), 0, 0, 240, function() U.OpenHistory() end)
    U.profileDisplayFrame:SetParent(p)
    U.profileNetworkFrame:SetParent(p)
    U.SetSettingsView('display', true)
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
    if not skipRoute and Z.UIState then
        Z.UIState.Route('settings', U.settingsView)
    end
end
