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
    U.profilePublicFrame = CreateFrame('Frame', nil, p)
    U.profilePublicFrame:SetPoint('TOPLEFT', 0, -42)
    U.profilePublicFrame:SetSize(856, 414)
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
        0,
        0,
        620,
        'GameFontNormalLarge'
    )
    U.profileFields = {}
    U.profileFields.community = edit(U.profilePublicFrame, 'Display name (optional)', 0, -66, 260, 32)
    U.profileRole = selector(U.profilePublicFrame, 'Preferred role', 280, -66, 190, ROLE_OPTIONS, U.CaptureProfileDraft)
    U.profileFields.note = edit(U.profilePublicFrame, 'Note (optional)', 0, -126, 470, 64, true)
    U.profilePreview = label(U.profilePublicFrame, '|cffffd36bPREVIEW|r', 510, -66, 325, 'GameFontHighlight')
    U.profilePreview:SetHeight(175)
    U.profileSave = button(U.profilePublicFrame, 'Save profile', 0, -218, 155, function()
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
    U.profileShow = button(U.profilePublicFrame, 'Show profile in Members', 170, -218, 220, function()
        U.memberKey = Z.me.key
        U.Navigate('members')
    end)
    for _, field in pairs(U.profileFields) do
        field:SetScript('OnTextChanged', U.CaptureProfileDraft)
    end
    -- "My characters" owns its layout (U.LayoutProfileCharacters). The generic
    -- footer heuristic used to drop the account overview button onto the
    -- page-wide Settings button; this view now reserves that footer row instead.
    U.profileCharactersFrame = CreateFrame('Frame', nil, p)
    U.profileCharactersFrame.zenialOwnLayout = true
    U.profileCharactersFrame:SetPoint('TOPLEFT', 0, -42)
    U.profileCharactersFrame:SetSize(856, 414)
    U.profileCharactersTitle =
        label(U.profileCharactersFrame, '|cffffd36b' .. tr('MY CHARACTERS') .. '|r', 0, 0, 400, 'GameFontNormalLarge')
    U.profileCharactersScope = label(
        U.profileCharactersFrame,
        tr('Only characters in your current game world and faction are shown and linked.'),
        0,
        -32,
        850
    )
    U.characterList = list(U.profileCharactersFrame, 0, -78, 525, 300)
    U.setMainButton = button(U.profileCharactersFrame, 'Als Hauptcharakter festlegen', 545, -78, 250, function()
        if U.characterKey then
            Z.SetMain(U.characterKey)
            U.Refresh()
        end
    end)
    U.accountOverviewButton = button(U.profileCharactersFrame, 'Account overview', 545, -112, 250, function()
        U.OpenAccountOverview()
    end)
    U.profileCharactersHint = label(
        U.profileCharactersFrame,
        'The first character is selected as main automatically. Log in with your other characters in the same game world and faction. Other members see your main next to your alt in Members.',
        545,
        -154,
        295
    )
    U.removeCharacterButton = button(U.profileCharactersFrame, 'Remove character', 545, -250, 250, function()
        local c = Z.account.characters[U.characterKey]
        if not c or U.characterKey == Z.accountCharacterKey then
            return
        end
        U.removeCharacterKey = U.characterKey
        U.characterConfirmText:SetText(
            Z.T(
                'Remove %s from the addon? Its saved profile, professions, recipes and drafts will be removed. History is kept. If it is your main, the logged-in character becomes main.',
                c.target
            )
        )
        U.characterConfirm:Show()
    end, 'danger')
    U.profileDisplayFrame = CreateFrame('Frame', nil, p)
    U.profileDisplayFrame:SetPoint('TOPLEFT', 0, -42)
    U.profileDisplayFrame:SetSize(856, 414)
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
    U.profileNetworkFrame = CreateFrame('Frame', nil, p)
    U.profileNetworkFrame:SetPoint('TOPLEFT', 0, -42)
    U.profileNetworkFrame:SetSize(856, 414)
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
    U.profileCharactersFrame:Hide()
    U.profileDisplayFrame:Hide()
    U.profileNetworkFrame:Hide()
    U.profileView = 'public'
    U.LayoutProfileCharacters()
end

-- Explicit reflow for "My characters". The page keeps its logical height of at
-- least 500 through window scaling, so the view never needs its own scrollbar;
-- the list scrolls. The bottom row stays free for the page-wide Settings button.
local PROFILE_FOOTER = 48
local function place(f, x, y, w, h)
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', x, y)
    if w then
        f:SetWidth(w)
    end
    if h then
        f:SetHeight(h)
    end
end
function U.LayoutProfileCharacters()
    local frame = U.profileCharactersFrame
    if not frame then
        return
    end
    local page = U.pages[6]
    local width = math.max(620, page:GetWidth())
    local height = math.max(300, page:GetHeight() - 42 - PROFILE_FOOTER)
    frame:SetSize(width, height)
    local column = math.min(360, math.max(250, math.floor(width * 0.34)))
    local columnX = width - column
    local listWidth = columnX - 20
    place(U.profileCharactersTitle, 0, 0, width)
    place(U.profileCharactersScope, 0, -32, width)
    local listHeight = height - 78
    local changed = U.characterList:GetWidth() ~= listWidth or U.characterList:GetHeight() ~= listHeight
    place(U.characterList, 0, -78, listWidth, listHeight)
    U.characterList.width, U.characterList.height = listWidth - 24, listHeight
    U.characterList.child:SetWidth(listWidth - 24)
    if changed and U.characterList.zenialRender then
        U.characterList.zenialRender()
    end
    local buttonWidth = math.min(column, 300)
    place(U.setMainButton, columnX, -78, buttonWidth)
    place(U.accountOverviewButton, columnX, -112, buttonWidth)
    place(U.profileCharactersHint, columnX, -154, column)
    -- The hint keeps its automatic height; measure the wrapped text for any font size.
    local hintHeight = math.ceil(U.profileCharactersHint:GetStringHeight() or 0)
    -- The destructive action follows the explanation, apart from the safe actions.
    place(U.removeCharacterButton, columnX, -(154 + hintHeight + 18), buttonWidth)
end

-- One entry point for the own characters, also used by /zenial alts|twinks|account.
function U.OpenMyCharacters(showOverview)
    U.Create()
    if not U.frame:IsShown() then
        U.frame:Show()
    end
    U.CloseDialogs()
    U.Navigate('profile', 'characters')
    U.Refresh()
    if showOverview then
        U.OpenAccountOverview()
    end
end

function S.createHistoryPage(f)
    local p = U.pages[HISTORY_PAGE]
    U.historyPeriod = selector(p, 'Period', 0, 0, 145, { 'DAYS_7', 'DAYS_30', 'DAYS_90' }, U.RefreshHistory)
    U.historyKind = selector(p, 'Area', 155, 0, 145, { 'ALL_KINDS', 'GROUP', 'QUEST', 'CRAFT' }, U.RefreshHistory)
    U.historyCharacter = selector(p, 'Own character', 310, 0, 220, { 'ALL_CHARACTERS' }, U.RefreshHistory)
    U.historySearch = edit(p, 'Player or content', 540, 0, 250, 96)
    U.historySearch:SetScript('OnTextChanged', U.RefreshHistory)
    U.historyCount = label(p, '0 events', 0, -50, 220, 'GameFontNormal')
    U.historyList = list(p, 0, -68, 445, 330)
    U.historyDetail = label(p, 'Select an entry to view the request timeline.', 470, -68, 375, 'GameFontHighlight')
    U.historyDetail:SetHeight(58)
    U.historyRelatedList = list(p, 470, -135, 375, 220)
    U.historyDeletePlayer = button(p, 'Delete player history', 470, -370, 180, function()
        U.ShowHistoryDeleteConfirm(true)
    end)
    button(p, 'Delete history', 665, -370, 180, function()
        U.ShowHistoryDeleteConfirm(false)
    end)
end

function S.createAddonPage(f)
    local p = U.pages[ADDON_PAGE]
    U.addonTabs = {}
    for i, entry in ipairs(ADDON_CATALOG) do
        U.addonTabs[i] = navButton(p, entry.label, (i - 1) * 180, 0, 170, function()
            U.SetAddonView(i)
        end)
        -- Name and version share a narrow tab; the small font fits six of them.
        -- Set on the button itself, which reapplies its fonts on every state change.
        local tab = U.addonTabs[i]
        if tab.SetNormalFontObject then
            tab:SetNormalFontObject('GameFontHighlightSmall')
            tab:SetHighlightFontObject('GameFontHighlightSmall')
            tab:SetDisabledFontObject('GameFontDisableSmall')
        end
        local tabText = tab.GetFontString and tab:GetFontString()
        if tabText then tabText:SetWordWrap(false) end
    end
    U.addonStatus = label(p, '', 0, -40, 850, 'GameFontNormalLarge')
    U.addonDescription = label(p, '', 0, -66, 850, 'GameFontHighlight')
    U.addonDescription:SetHeight(32)
    U.addonAction = button(p, '', 0, -98, 220, function() end)
    U.addonAction:Hide()
    U.addonHost = CreateFrame('Frame', nil, p)
    U.addonHost:SetPoint('TOPLEFT', 0, -36)
    U.addonHost:SetPoint('BOTTOMRIGHT', 0, 0)
    U.addonHost:SetFrameLevel(p:GetFrameLevel() + 5)
    U.addonHost:EnableMouse(false)
    U.addonPanels = {}
    U.addonIndex = nil
    U.RefreshAddonAvailability()
end
