local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local H = Z.History
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local ADDON_PAGE, MAIN_TAB_NAMES, MAIN_TAB_ICONS = S.ADDON_PAGE, S.MAIN_TAB_NAMES, S.MAIN_TAB_ICONS
local ROLE_OPTIONS, canonicalOption, label, button, navButton = S.ROLE_OPTIONS, S.canonicalOption, S.label, S.button, S.navButton
local selectNav, edit, tabChain, selector, checkbox, list = S.selectNav, S.edit, S.tabChain, S.selector, S.checkbox, S.list
local rows, panel, showControl, makeModal = S.rows, S.panel, S.showControl, S.makeModal

-- Text colour from the palette (plain RGB only when the shared theme is missing).
local function tone(region, key, r, g, b)
    if T and T.Tint then
        T.Tint(region, 'SetTextColor', key)
    else
        region:SetTextColor(r, g, b)
    end
end

function U.Create()
    if U.frame then
        return
    end
    local f = CreateFrame('Frame', 'ZenialCommunityFrame', UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.frame = f
    local saved = Z.ui and Z.ui.window or {}
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local maxWidth = math.max(900, math.min(1280, (type(screenWidth) == 'number' and screenWidth or 1320) - 40))
    local maxHeight = math.max(610, math.min(860, (type(screenHeight) == 'number' and screenHeight or 900) - 40))
    f:SetSize(math.min(saved.width or 1060, maxWidth), math.min(saved.height or 690, maxHeight))
    f:SetFrameStrata('DIALOG')
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(900, 610, maxWidth, maxHeight)
    end
    f:EnableMouse(true)
    f:RegisterForDrag('LeftButton')
    f:SetScale(Z.db.scale or 1)
    local pos = Z.db.position or { x = 0, y = 0 }
    f:SetPoint('CENTER', UIParent, 'CENTER', pos.x, pos.y)
    if T then
        T.Shell(f)
    elseif f.SetBackdrop then
        f:SetBackdrop({
            bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background-Dark',
            edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 10, right = 10, top = 10, bottom = 10 },
        })
        f:SetBackdropColor(0.06, 0.04, 0.02, 0.98)
        f:SetBackdropBorderColor(0.82, 0.62, 0.25, 1)
    end
    f:SetScript('OnDragStart', function(s)
        s:StartMoving()
    end)
    f:SetScript('OnDragStop', function(s)
        s:StopMovingOrSizing()
        local x, y = s:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local sc = s:GetScale()
        if type(x) == 'number' then
            Z.db.position = { x = math.floor(x - ux / sc), y = math.floor(y - uy / sc) }
        end
    end)
    -- Header: logo, title and subtitle on the left; bell, PvP-Hilfe and Discord (secondary buttons) and
    -- the native close button on the right.
    local icon = f:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(40, 40)
    icon:SetPoint('TOPLEFT', 16, -15)
    icon:SetTexture('Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga')
    local title = label(f, 'ZENIAL COMMUNITY', 66, -17, 460, 'GameFontNormalLarge')
    tone(title, 'gold', 1, 0.82, 0.36)
    U.headerSubtitle = label(f, tr('Community-Werkzeuge für Azeroth'), 66, -41, 430)
    tone(U.headerSubtitle, 'dim', 0.7, 0.64, 0.54)
    U.pvpHeaderButton = button(f, tr('PvP-Hilfe'), 0, 0, 190, function()
        U.OpenPvPRequester()
    end)
    U.pvpHeaderButton:SetHeight(30)
    U.pvpHeaderButton:ClearAllPoints()
    U.pvpHeaderButton:SetPoint('TOPRIGHT', -146, -20)
    local discord = button(f, 'Discord', 0, 0, 105, function()
        U.ShowDiscord()
    end)
    discord:SetHeight(30)
    discord:ClearAllPoints()
    discord:SetPoint('TOPRIGHT', -38, -20)
    local close = U.CloseButton(f, -4, -4, function()
        if S.openPopup then
            S.openPopup:Hide()
            S.openPopup = nil
        end
        U.HideAddonPanels()
        f:Hide()
    end)
    f:SetScript('OnHide', function()
        U.FinishResize()
        U.CloseDialogs()
        U.HideAddonPanels()
        -- Running animations are ended so nothing stays transparent or displaced while the window is closed.
        if T and T.CancelReveal then
            for _, page in ipairs(U.pages or {}) do
                T.CancelReveal(page)
            end
            if U.statusToast then
                T.CancelReveal(U.statusToast)
                U.statusToast:Hide()
            end
        end
        if U.navIndicator then
            U.navIndicator:Settle()
        end
    end)
    U.modalBlocker = CreateFrame('Frame', nil, f)
    U.modalBlocker:SetAllPoints(f)
    U.modalBlocker:SetFrameLevel(f:GetFrameLevel() + 40)
    U.modalBlocker:EnableMouse(true)
    U.modalBlocker:Hide()
    U.sidebar = CreateFrame('Frame', nil, f, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    if T then
        T.Panel(U.sidebar, 'sidebar')
        -- One shared selection marker for the main navigation (created before the entries so it is drawn below them).
        if T.CreateNavIndicator then
            U.navIndicator = T.CreateNavIndicator(U.sidebar)
        end
    end
    U.contentBackground = CreateFrame('Frame', nil, f, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    if T then
        T.Panel(U.contentBackground, 'parchment')
    end
    -- Notice while ZENIAL Community membership is missing; U.RefreshJoinBanner shows it and U.Layout makes room.
    U.joinBanner = CreateFrame('Frame', nil, f, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.joinBanner:SetHeight(U.JOIN_BANNER_HEIGHT - 2)
    if T then
        T.Panel(U.joinBanner, 'parchment')
        T.Tint(U.joinBanner, 'SetBackdropColor', 'noticeBg')
        T.Tint(U.joinBanner, 'SetBackdropBorderColor', 'gold')
    end
    U.joinBannerButton = button(U.joinBanner, tr('Join now'), 0, 0, 130, function()
        f:Hide()
        Z.NetworkSetup.Show()
    end)
    U.joinBannerButton:ClearAllPoints()
    U.joinBannerButton:SetPoint('RIGHT', -5, 0)
    if T then
        T.StyleButton(U.joinBannerButton, 'primary')
    end
    U.joinBannerText = label(U.joinBanner, tr('You are not in ZENIAL Community yet. Join to find members and offers.'), 0, 0, 500, 'GameFontHighlightSmall')
    U.joinBannerText:ClearAllPoints()
    U.joinBannerText:SetPoint('LEFT', 10, 0)
    U.joinBannerText:SetPoint('RIGHT', U.joinBannerButton, 'LEFT', -10, 0)
    tone(U.joinBannerText, 'goldText', 1, 0.95, 0.8)
    U.joinBanner:Hide()
    U.navSeparator = f:CreateTexture(nil, 'ARTWORK')
    if T and T.Tint then
        T.Tint(U.navSeparator, 'SetColorTexture', 'edge', 0.72)
    else
        U.navSeparator:SetColorTexture(0.72, 0.5, 0.2, 0.72)
    end
    U.navSeparator:SetSize(856, 1)
    U.navPath = label(f, '', 188, -77, 850, 'GameFontNormalLarge')
    tone(U.navPath, 'gold', 1, 0.82, 0.36)
    U.pages, U.tabs = {}, {}
    for i, name in ipairs(MAIN_TAB_NAMES) do
        local p = CreateFrame('Frame', nil, f)
        p:SetSize(856, 500)
        p:Hide()
        U.pages[i] = p
        U.tabs[i] = navButton(U.sidebar, name, 0, 0, 150, function()
            if i == 4 then
                U.Navigate('quests', 'shared')
            else
                U.Page(i)
            end
        end, MAIN_TAB_ICONS[i])
        U.tabs[i].zenialIndicator = U.navIndicator
    end
    U.status = label(f, '', 188, -660, 850)
    tone(U.status, 'gold', 1, 0.75, 0.35)
    if T and T.CreateToast then
        U.statusToast = T.CreateToast(f)
    end
    local resize = CreateFrame('Button', nil, f)
    resize:SetSize(22, 22)
    resize:SetPoint('BOTTOMRIGHT', -7, 7)
    local resizeTexture = resize:CreateTexture(nil, 'ARTWORK')
    resizeTexture:SetAllPoints()
    resizeTexture:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    U.resizeDriver = CreateFrame('Frame', nil, f)
    resize:SetScript('OnMouseDown', function(_, button)
        if button ~= 'LeftButton' then
            return
        end
        U.resizing = true
        U.resizeElapsed = 0
        U.resizePending = false
        U.resizeDriver:SetScript('OnUpdate', U.ResizeUpdate)
        f:StartSizing('BOTTOMRIGHT')
    end)
    resize:SetScript('OnMouseUp', function()
        U.FinishResize()
    end)
    resize:SetScript('OnEnter', function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
            GameTooltip:SetText(tr('Drag to resize the window.'))
            GameTooltip:Show()
        end
    end)
    resize:SetScript('OnLeave', function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    U.resizeHandle = resize
    U.versionLabel = label(f, Z.ADDON_VERSION, 0, 0, 150, 'GameFontHighlightSmall')
    U.versionLabel:ClearAllPoints()
    U.versionLabel:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -36, 13)
    U.versionLabel:SetJustifyH('RIGHT')
    U.versionLabel:SetHeight(14)
    tone(U.versionLabel, 'dim', 0.65, 0.6, 0.47)
    f:SetScript('OnSizeChanged', function()
        if U.pages then
            if U.resizing then
                U.resizePending = true
            else
                U.Layout()
            end
        end
    end)
    UISpecialFrames = UISpecialFrames or {}
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == 'ZenialCommunityFrame' then
            registered = true
        end
    end
    if not registered then
        UISpecialFrames[#UISpecialFrames + 1] = 'ZenialCommunityFrame'
    end

    S.createMembersPage(f)
    S.createCraftPage(f)
    S.createGroupsPage(f)
    S.createQuestsPage(f)
    S.createTradePage(f)
    S.createProfilePage(f)
    S.createHistoryPage(f)
    S.createAddonPage(f)

    U.characterConfirm = CreateFrame('Frame', nil, f, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.characterConfirm:SetSize(460, 255)
    U.characterConfirm:SetPoint('CENTER')
    U.characterConfirm:SetFrameLevel(f:GetFrameLevel() + 50)
    if T then
        T.Shell(U.characterConfirm)
    end
    U.characterConfirmText = label(U.characterConfirm, '', 25, -25, 410, 'GameFontHighlight')
    U.characterConfirmText:SetHeight(160)
    U.characterConfirmDelete = button(U.characterConfirm, 'Delete character data', 50, -205, 175, function()
        local ok, err = Z.RemoveCharacter(U.removeCharacterKey)
        U.removeCharacterKey = nil
        U.characterConfirm:Hide()
        if ok then
            U.characterKey = Z.accountCharacterKey
            U.Refresh()
        else
            U.Message(err)
        end
    end, 'danger')
    U.characterConfirmCancel = button(U.characterConfirm, 'Cancel', 255, -205, 155, function()
        U.removeCharacterKey = nil
        U.characterConfirm:Hide()
    end)
    U.characterConfirm:Hide()
    U.historyConfirm = CreateFrame('Frame', nil, f, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.historyConfirm:SetSize(440, 150)
    U.historyConfirm:SetPoint('CENTER')
    U.historyConfirm:SetFrameLevel(f:GetFrameLevel() + 50)
    if T then
        T.Shell(U.historyConfirm)
    elseif U.historyConfirm.SetBackdrop then
        U.historyConfirm:SetBackdrop({
            bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background-Dark',
            edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
            tile = true,
            tileSize = 32,
            edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    U.historyConfirmText = label(U.historyConfirm, '', 25, -28, 390, 'GameFontHighlight')
    U.historyConfirmText:SetHeight(45)
    button(U.historyConfirm, tr('Löschen'), 75, -92, 125, function()
        local peer = U.historyDeletePeer
        local n = H.Delete(peer)
        U.historyEntryID = nil
        U.historyDeletePeer = nil
        U.historyConfirm:Hide()
        U.Message(n .. tr(' Historieneinträge gelöscht.'))
        U.RefreshHistory()
    end, 'danger')
    button(U.historyConfirm, tr('Abbrechen'), 240, -92, 125, function()
        U.historyDeletePeer = nil
        U.historyConfirm:Hide()
    end)
    U.historyConfirm:Hide()

    for _, dialog in ipairs({ U.characterConfirm, U.historyConfirm, U.craftOrderForm, U.materialOrderForm, U.categoryPanel }) do
        makeModal(dialog)
        dialog:Hide()
    end
    U.CreateCommunityHome({
        label = label,
        button = button,
        list = list,
        rows = rows,
        edit = edit,
        selector = selector,
        checkbox = checkbox,
        panel = panel,
        showControl = showControl,
        makeModal = makeModal,
    })
    local profileDraft = Z.UIState and Z.UIState.Draft('profile')
    local rawRole = L.Role(Z.db.roles) or ''
    S.restoringDraft = true
    U.profileRole:SetOptions(ROLE_OPTIONS, profileDraft and canonicalOption(profileDraft.role) or (rawRole ~= '' and rawRole or 'NONE'))
    U.profileFields.community:SetText(profileDraft and profileDraft.community or Z.db.community or '')
    U.profileFields.note:SetText(profileDraft and profileDraft.note or Z.db.note or '')
    S.restoringDraft = false
    U.CaptureProfileDraft()
    U.characterKey = Z.accountCharacterKey
    U.EditOffer(nil)
    tabChain({
        U.offerFields.name,
        U.offerFields.quantity,
        U.offerFields.gold,
        U.offerFields.silver,
        U.offerFields.copper,
        U.offerDuration,
        U.offerFields.note,
    })
    tabChain({ U.profileFields.community, U.profileFields.note })
    U.groupBrowseFrame:Show()
    U.groupMineFrame:Hide()
    selectNav(U.groupBrowseTab, true)
    selectNav(U.groupMineTab, false)
    selectNav(U.groupOutgoingTab, false)
    selectNav(U.groupFollowTab, false)
    selectNav(U.pvpTab, false)
    U.sharedQuestFrame:Show()
    U.questBrowseFrame:Hide()
    U.questMineFrame:Hide()
    selectNav(U.sharedQuestTab, true)
    selectNav(U.questBrowseTab, false)
    selectNav(U.questMineTab, false)
    selectNav(U.questOutgoingTab, false)
    U.Layout()
    local state = Z.uiCharacter or { section = 'today', subviews = {} }
    if T then
        T.suppressMotion = true
    end
    U.groupView = state.subviews and state.subviews.groups or 'browse'
    U.craftView = state.subviews and state.subviews.craft or 'search'
    U.tradeView = state.subviews and state.subviews.trade or 'browse'
    U.profileView = state.subviews and state.subviews.profile or 'public'
    U.Navigate(
        state.section,
        state.section == 'quests' and (state.subviews and state.subviews.quests == 'questgroups' and 'questgroups' or 'shared')
            or (state.subviews and state.subviews[state.section])
    )
    U.Refresh(true)
    if T then
        T.suppressMotion = false
    end
    f:Hide()
    U.UpdateBadges()
end
function U.Toggle()
    U.Create()
    if U.frame:IsShown() then
        U.HideAddonPanels()
        U.frame:Hide()
    else
        U.frame:Show()
        if U.page == ADDON_PAGE then
            U.SetAddonView(U.addonIndex or 1)
        elseif U.page == 4 then
            U.SetQuestView(U.questView == 'questgroups' and 'questgroups' or 'shared')
        else
            U.Refresh()
        end
    end
end
