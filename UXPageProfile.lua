local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local S = U.Shared
local tr = S.tr
local HISTORY_PAGE, ADDON_PAGE, ROLE_OPTIONS, ADDON_CATALOG = S.HISTORY_PAGE, S.ADDON_PAGE, S.ROLE_OPTIONS, S.ADDON_CATALOG
local label, button, navButton, edit, selector, checkbox = S.label, S.button, S.navButton, S.edit, S.selector, S.checkbox
local list, faction = S.list, S.faction

function S.createProfilePage(f)
    local p = U.pages[6]
    U.profilePublicTab = navButton(p, tr('Charakterprofil'), 0, 0, 175, function()
        U.SetProfileView('public')
    end)
    U.profileCharactersTab = navButton(p, tr('My characters'), 185, 0, 175, function()
        U.SetProfileView('characters')
    end)
    U.profileDisplayTab = navButton(p, tr('Darstellung'), 370, 0, 155, function()
        U.SetProfileView('display')
    end)
    U.profileNetworkTab = navButton(p, tr('Verbindung'), 535, 0, 155, function()
        U.SetProfileView('network')
    end)
    U.profileDisplayTab:Hide()
    U.profileNetworkTab:Hide()
    -- Public profile: the third tab of "My characters" (head and tabs belong to the characters frame).
    -- Form on the left plate, preview on the right plate.
    U.profilePublicFrame = CreateFrame('Frame', nil, p)
    U.profilePublicFrame:SetPoint('TOPLEFT', 0, -66)
    U.profilePublicFrame:SetSize(856, 414)
    if Z.Kit and Z.Kit.Plate then
        U.profilePublicPlates = { { Z.Kit.Plate(U.profilePublicFrame, 'surface'), 0, 0, 482, 290 }, { Z.Kit.Plate(U.profilePublicFrame, 'surface'), 494, 0, 356, 290 } }
    end
    function U.LayoutProfilePublic()
        local horizontal = U.profilePublicFrame:GetWidth() / 856
        for _, spec in ipairs(U.profilePublicPlates or {}) do
            spec[1]:Place(spec[2] * horizontal, spec[3], spec[4] * horizontal, spec[5])
        end
    end
    label(
        U.profilePublicFrame,
        '|cffffd36b'
            .. tr('YOUR CHARACTER')
            .. '|r\n'
            .. Z.me.target
            .. ' · '
            .. L.ClassName(Z.me.class)
            .. ' · '
            .. tr('Level')
            .. ' '
            .. Z.me.level
            .. ' · '
            .. faction(Z.me.faction),
        16,
        -14,
        450,
        'GameFontNormalLarge'
    )
    U.profileFields = {}
    U.profileFields.community = edit(U.profilePublicFrame, 'Display name (optional)', 16, -70, 250, 32)
    U.profileRole = selector(U.profilePublicFrame, 'Preferred role', 282, -70, 184, ROLE_OPTIONS, U.CaptureProfileDraft)
    U.profileFields.note = edit(U.profilePublicFrame, 'Note (optional)', 16, -130, 450, 64, true)
    U.profilePreview = label(U.profilePublicFrame, '|cffffd36bPREVIEW|r', 510, -14, 325, 'GameFontHighlight')
    U.profilePreview:SetHeight(262)
    U.profileSave = button(U.profilePublicFrame, 'Save profile', 16, -222, 155, function()
        local community, note = U.profileFields.community:GetText(), U.profileFields.note:GetText()
        if not L.Text(community, 32, true) or not L.Text(note, 64, true) then
            U.Message('Input is too long.')
            return
        end
        Z.db.community, Z.db.note = community, note
        Z.db.roles = U.profileRole:GetText() == 'NONE' and '' or U.profileRole:GetText()
        if Z.UIState then
            Z.UIState.Draft('profile', false)
        end
        U.Publish()
        U.Message('Profile saved.')
    end, 'primary')
    U.profileShow = button(U.profilePublicFrame, 'Show profile in Members', 181, -222, 250, function()
        U.memberKey, U.memberFollowActive = Z.me.key, false
        U.Navigate('members')
    end)
    for _, field in pairs(U.profileFields) do
        field:SetScript('OnTextChanged', U.CaptureProfileDraft)
    end
    -- "My characters" owns its layout (U.LayoutProfileCharacters in
    -- AccountOverviewUI.lua): character list, details and the private overview
    -- in one view instead of a separate dialog.
    U.profileCharactersFrame = CreateFrame('Frame', nil, p)
    U.profileCharactersFrame.zenialOwnLayout = true
    U.profileCharactersFrame:SetPoint('TOPLEFT', 0, -42)
    U.profileCharactersFrame:SetSize(856, 414)
    U.CreateMyCharacters(U.profileCharactersFrame, S)
    U.profileCharactersFrame:Hide()
    U.profileView = 'public'
end

function S.createHistoryPage(f)
    local p = U.pages[HISTORY_PAGE]
    U.historyPeriod = selector(p, 'Period', 0, 0, 145, { 'DAYS_7', 'DAYS_30', 'DAYS_90' }, U.RefreshHistory)
    U.historyKind = selector(p, 'Area', 155, 0, 145, { 'ALL_KINDS', 'GROUP', 'QUEST', 'CRAFT' }, U.RefreshHistory)
    U.historyCharacter = selector(p, 'Own character', 310, 0, 220, { 'ALL_CHARACTERS' }, U.RefreshHistory)
    U.historySearch = edit(p, 'Player or content', 540, 0, 250, 96)
    U.historySearch:SetScript('OnTextChanged', U.RefreshHistory)
    U.historyCount = label(p, '0 events', 0, -50, 220, 'GameFontNormal')
    if Z.Theme and Z.Theme.Font then
        Z.Theme.Font(U.historyCount, 'caption', 'dim')
    end
    U.historyList = list(p, 0, -68, 445, 330)
    U.historyDetail = label(p, 'Select an entry to view the request timeline.', 470, -68, 375, 'GameFontHighlight')
    U.historyDetail:SetHeight(58)
    -- The timeline of a selected entry is information, nothing in it is clickable: an info block without a well.
    U.historyRelatedList = list(p, 470, -135, 375, 220)
    if Z.Kit then
        Z.Kit.InfoBlock(U.historyRelatedList)
    end
    U.historyDeletePlayer = button(p, 'Delete player history', 470, -370, 180, function()
        U.ShowHistoryDeleteConfirm(true)
    end)
    button(p, 'Delete history', 665, -370, 180, function()
        U.ShowHistoryDeleteConfirm(false)
    end)
end

function S.createAddonPage(f)
    local p = U.pages[ADDON_PAGE]
    local addonNames = {}
    for _, entry in ipairs(ADDON_CATALOG) do addonNames[#addonNames + 1] = entry.addon end
    U.addonSelector = selector(p, tr('ZENIAL Addon'), 0, 0, 360, addonNames, function(addon)
        for i, entry in ipairs(ADDON_CATALOG) do
            if entry.addon == addon then U.SetAddonView(i); return end
        end
    end, function(addon)
        for _, entry in ipairs(ADDON_CATALOG) do
            if entry.addon == addon then
                local state = U.GetAddonState and U.GetAddonState(entry)
                return entry.label .. (state and state.version and state.version ~= '' and ' (' .. state.version .. ')' or '')
                    .. (state and state.kind == 'missing' and ' · ' .. tr('Not installed') or '')
            end
        end
        return addon
    end)
    U.addonSelector.caption:Hide()
    U.addonSelector.button:ClearAllPoints()
    U.addonSelector.button:SetPoint('TOPLEFT', 0, 0)
    U.addonStatus = label(p, '', 372, 0, 260, 'GameFontNormal')
    U.addonStatus:SetHeight(56)
    U.addonStatus:SetWordWrap(true)
    U.addonBack = button(p, tr('Back to Integrations'), 638, 0, 218, function()
        U.Navigate('settings', 'tools')
    end)
    U.addonDescription = label(p, '', 0, -60, 850, 'GameFontHighlight')
    U.addonDescription:SetHeight(32)
    U.addonAction = button(p, '', 0, -104, 220, function() end)
    U.addonAction:Hide()
    U.addonHost = CreateFrame('Frame', nil, p)
    U.addonHost:SetPoint('TOPLEFT', 0, -60)
    U.addonHost:SetPoint('BOTTOMRIGHT', 0, 0)
    U.addonHost:SetFrameLevel(p:GetFrameLevel() + 5)
    U.addonHost:EnableMouse(false)
    U.addonPanels = {}
    U.addonIndex = nil
    U.RefreshAddonAvailability()
end
