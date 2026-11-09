local Z = ZenialCommunity
local U = Z.UI
local A = Z.Adapter
local S = U.Shared
local HISTORY_PAGE, ADDON_PAGE, selectNav, mainTabSelected = S.HISTORY_PAGE, S.ADDON_PAGE, S.selectNav, S.mainTabSelected
local updateNavPath, age, presenceDeadline, memberEntries = S.updateNavPath, S.age, S.presenceDeadline, S.memberEntries
local refreshMembers, refreshProfessions, refreshCraftOrders = S.refreshMembers, S.refreshProfessions, S.refreshCraftOrders
local refreshOffers, refreshTradeRules, refreshTradeManage = S.refreshOffers, S.refreshTradeRules, S.refreshTradeManage
local refreshCharacters = S.refreshCharacters

function U.LayoutMainTabs()
    if not U.tabs or not U.frame then
        return
    end
    local width = U.sidebarWidth or 150
    local y = -86
    local positions = {}
    for _, index in ipairs({ 9, 10, 4, 1, 2, 5 }) do
        positions[index] = y
        y = y - 48
    end
    local height = U.sidebar and U.sidebar:GetHeight() or (U.frame:GetHeight() - 84)
    -- Availability is based on installed providers, never leftover SavedVariables.
    if (U.addonAvailableCount or 0) > 0 and (not Z.ui or Z.ui.showAddonManager ~= false) then
        positions[ADDON_PAGE] = -height + 96
    end
    positions[11] = -height + 48
    -- Background refreshes run while the mouse may still be held down.
    -- Hiding and showing an unchanged button cancels its native release-click.
    for index, tab in ipairs(U.tabs) do
        local target = positions[index]
        if target then
            local point, parent, relative, x, offset = tab:GetPoint()
            if
                tab:GetNumPoints() ~= 1
                or point ~= 'TOPLEFT'
                or parent ~= tab:GetParent()
                or relative ~= 'TOPLEFT'
                or x ~= 6
                or offset ~= target
            then
                tab:ClearAllPoints()
                tab:SetPoint('TOPLEFT', 6, target)
            end
            if tab:GetWidth() ~= width or tab:GetHeight() ~= 42 then
                tab:SetSize(width, 42)
            end
            if not tab:IsShown() then
                tab:Show()
            end
        elseif tab:IsShown() then
            tab:Hide()
        end
    end
    for i, tab in ipairs(U.tabs) do
        selectNav(tab, mainTabSelected(i, U.page))
    end
end
function U.SetAddonManagerNavigation(shown)
    if not Z.ui or type(shown) ~= 'boolean' then
        return
    end
    Z.ui.showAddonManager = shown
    if U.homeAddonNavigationOption then
        U.homeAddonNavigationOption:SetChecked(shown)
    end
    U.LayoutMainTabs()
end

U.JOIN_BANNER_HEIGHT = 36

-- Shows the membership notice only while it applies; the layout changes only when that flips.
function U.RefreshJoinBanner()
    if not U.joinBanner then
        return
    end
    local active = Z.NetworkSetup.NeedsJoin()
    if active == (U.joinBannerActive == true) then
        return
    end
    U.joinBannerActive = active
    if active then
        U.joinBanner:Show()
    else
        U.joinBanner:Hide()
    end
    U.Layout()
end

-- Pages that are not scaled proportionally with the window. Only the profile
-- page while its "My characters" view is active: it switches between one and
-- two columns by the real width, which a proportional scale (logical width
-- always about 856) would hide.
function U.PageUsesNativeScale(i)
    return i == 6 and U.profileView == 'characters'
end
-- Changing the profile subview can change the page scale; apply the layout then.
local setProfileView = U.SetProfileView
function U.SetProfileView(v)
    setProfileView(v)
    if U.frame and U.pages and U.PageUsesNativeScale(6) ~= (U.profileNativeScale == true) then
        U.Layout(U.page == 6)
    end
end

function U.Layout(activeOnly, geometryOnly)
    if not U.frame or not U.pages then
        return
    end
    local width, height = U.frame:GetWidth(), U.frame:GetHeight()
    local compact = width < 1000
    U.sidebarWidth = compact and 124 or 150
    local pageX = compact and 158 or 188
    local contentX = pageX + 8
    local available = math.max(620, width - contentX - 16)
    local bannerHeight = U.joinBannerActive and U.JOIN_BANNER_HEIGHT or 0
    local pageHeight = math.max(1, height - 146 - bannerHeight)
    local scale = math.min(available / 856, pageHeight / 500)
    local wasCompact = U.compactContent
    if not geometryOnly then
        U.compactContent = available < 780
    end
    if U.sidebar then
        U.sidebar:ClearAllPoints()
        U.sidebar:SetPoint('TOPLEFT', 12, -72)
        U.sidebar:SetPoint('BOTTOMLEFT', 12, 12)
        U.sidebar:SetWidth(U.sidebarWidth + 12)
    end
    U.navPath:ClearAllPoints()
    U.navPath:SetPoint('TOPLEFT', pageX, -77)
    U.navPath:SetWidth(available)
    U.navSeparator:ClearAllPoints()
    U.navSeparator:SetPoint('TOPLEFT', pageX, -108)
    U.navSeparator:SetWidth(available)
    if U.contentBackground then
        U.contentBackground:ClearAllPoints()
        U.contentBackground:SetPoint('TOPLEFT', pageX - 8, -112 - bannerHeight)
        U.contentBackground:SetPoint('BOTTOMRIGHT', -12, 28)
    end
    if U.joinBanner then
        U.joinBanner:ClearAllPoints()
        U.joinBanner:SetPoint('TOPLEFT', pageX - 8, -112)
        U.joinBanner:SetPoint('TOPRIGHT', -12, -112)
    end
    -- A scaled frame also scales its own anchor offsets on Forever. Compensate
    -- those offsets so only the page contents grow; the page origin stays on
    -- the unscaled content boundary instead of drifting right and down.
    for i, page in ipairs(U.pages) do
        if not activeOnly or i == U.page then
            -- "My characters" lays itself out by its real content width, so it
            -- keeps scale 1 and the unscaled available size (P0-B2).
            local native = U.PageUsesNativeScale(i)
            local pageScale = native and 1 or scale
            if i == 6 then
                U.profileNativeScale = native
            end
            page:SetScale(pageScale)
            page:ClearAllPoints()
            page:SetPoint('TOPLEFT', U.frame, 'TOPLEFT', contentX / pageScale, (-118 - bannerHeight) / pageScale)
            page:SetSize(available / pageScale, pageHeight / pageScale)
        end
    end
    U.status:ClearAllPoints()
    U.status:SetPoint('BOTTOMLEFT', contentX, 12)
    U.status:SetWidth(math.max(200, available - 160))
    if not U.resizing and Z.ui then
        Z.ui.window.width, Z.ui.window.height = math.floor(width), math.floor(height)
    end
    U.LayoutMainTabs()
    if not geometryOnly then
        if U.ApplyResponsiveLayout then
            U.ApplyResponsiveLayout(activeOnly and U.pages[U.page] or nil)
        end
        if wasCompact and not U.compactContent and U.compactArea then
            U.CloseCompactArea(U.compactArea)
        end
    end
end

-- Native sizing remains immediate. Coalesce size events into one lightweight
-- geometry pass per rendered frame; reflow only the visible page at 10 Hz.
-- Mouse release (or hiding the window) finishes every page and saves once.
function U.ResizeUpdate(_, elapsed)
    U.resizeElapsed = (U.resizeElapsed or 0) + elapsed
    if not U.resizePending then
        return
    end
    U.resizePending = false
    local reflow = U.resizeElapsed >= 0.1
    if reflow then
        U.resizeElapsed = 0
    end
    U.Layout(true, not reflow)
end
function U.FinishResize()
    if not U.resizing then
        return
    end
    U.frame:StopMovingOrSizing()
    U.resizing = false
    U.resizePending = false
    U.resizeElapsed = 0
    U.resizeDriver:SetScript('OnUpdate', nil)
    U.Layout()
end

local PAGE_BY_KEY =
    { members = 1, craft = 2, groups = 3, quests = 4, trade = 5, profile = 6, history = 7, addons = 8, today = 9, activities = 10, settings = 11 }
function S.applyRoute(route)
    local section, subview = route.legacy.section, route.legacy.subview
    U.Page(route.page)
    if section == 'craft' then
        U.SetCraftView(subview)
    elseif section == 'groups' then
        U.SetGroupView(subview or 'browse')
    elseif section == 'quests' then
        U.SetQuestView(subview or 'shared')
    elseif section == 'trade' then
        U.SetTradeView(subview)
    elseif section == 'profile' then
        U.SetProfileView(subview)
    elseif section == 'addons' and route.selection then
        U.SetAddonView(route.selection)
    end
    if Z.UIState then
        Z.UIState.Route(section, subview)
    end
end
-- Legacy section/subview names stay valid; U.Navigation resolves them and guards unsaved input.
function U.Navigate(section, subview, selection)
    local N = U.Navigation
    local route, reason = N.Resolve(section, subview, selection)
    if not route then
        return N.Fail(reason)
    end
    local ok, why = N.Open(route)
    if not ok then
        return N.Fail(why)
    end
    return true
end
function U.IsRoute(section)
    return U.page == PAGE_BY_KEY[section]
end
function U.OnAddonLoaded()
    U.RefreshAddonAvailability()
    if U.IsRoute('addons') then
        U.RefreshAddonManager()
    end
end

function U.Page(n)
    local enterQuests = n == 4 and U.page ~= 4
    U.CloseDialogs()
    local compactPage = ({ members = 1, craft = 2, groups = 3, quests = 4, trade = 5 })[U.compactArea or '']
    if compactPage and compactPage ~= n then
        U.CloseCompactArea(U.compactArea)
    end
    if n == ADDON_PAGE and U.RefreshAddonAvailability() == 0 then
        n = 1
    end
    if U.page == ADDON_PAGE and n ~= ADDON_PAGE then
        U.HideAddonPanels()
    end
    local switched = U.page ~= n
    U.page = n
    for i, p in ipairs(U.pages) do
        p:SetShown(i == n)
        selectNav(U.tabs[i], mainTabSelected(i, n))
    end
    updateNavPath()
    local key = ({ 'members', 'craft', 'groups', 'quests', 'trade', 'profile', 'history', 'addons', 'today', 'activities', 'settings' })[n]
    if key and Z.UIState then
        Z.UIState.Route(key)
    end
    if n == ADDON_PAGE then
        U.SetAddonView(U.addonIndex or 1)
    elseif enterQuests then
        U.SetQuestView('shared')
    else
        U.Refresh()
    end
    -- Page switch animation (fade-in plus a small rise); instant where AnimationGroup is unavailable.
    local T = Z.Theme
    if switched and T and T.Reveal and U.frame and U.frame:IsVisible() and U.pages[n] then
        T.Reveal(U.pages[n], T.animation.pageRise, T.animation.pageDuration)
    end
end
local function timedRoute()
    return table.concat({ U.page or 0, U.craftView or '', U.groupView or '', U.questView or '', U.tradeView or '', U.pvpView or '' }, ':')
end
local function scheduleTimedRefresh()
    local clock, now = A.Clock(), A.Now()
    local deadline = math.huge
    local function at(epoch)
        if epoch and epoch > now then
            deadline = math.min(deadline, clock + epoch - now)
        end
    end
    local function expiry(row, countdown)
        if not row then
            return
        end
        at(row.expires)
        if countdown and row.expires and row.expires > now then
            at(row.expires - (math.ceil((row.expires - now) / 60) - 1) * 60)
        end
    end
    if U.page >= 1 and U.page <= 5 then
        for _, peer in pairs(Z.db.peers) do
            deadline = math.min(deadline, presenceDeadline(peer, clock, now))
            local data = peer.data
            if data and U.page == 3 then
                expiry(data.group or data.lfg and data.lfg[1])
            elseif data and U.page == 4 then
                expiry(data.quest)
            elseif data and U.page == 5 then
                for _, offer in ipairs(data.market or {}) do
                    expiry(offer)
                end
            end
        end
    end
    if (U.page == 1 or U.page == 2) and S.memberModel then
        deadline = math.min(deadline, S.memberModel.deadline)
    end
    if U.page == 3 then
        expiry(Z.db.lfg[1])
        for _, people in pairs(Z.db.sentApplications) do
            for _, row in pairs(people) do
                at(row.at + 86401)
            end
        end
        if U.groupView == 'pvp' and Z.PvPHelp and Z.PvPHelp.store then
            local store = Z.PvPHelp.store
            expiry(store.own, true)
            at(store.lastCallAt + 600)
            for _, death in ipairs(store.deaths) do
                at(death + 3600)
            end
            for _, call in pairs(store.received) do
                expiry(call, true)
            end
        end
    elseif U.page == 4 then
        expiry(Z.db.quest, true)
        for _, people in pairs(Z.db.sentQuestApplications) do
            for _, row in pairs(people) do
                at(row.at + 7201)
            end
        end
    elseif U.page == 5 then
        for _, offer in ipairs(Z.db.market) do
            expiry(offer)
        end
    elseif U.page == 2 then
        for _, professions in pairs(Z.db.recipeCatalogs) do
            for _, catalog in pairs(professions) do
                at(catalog.at and catalog.at + 601)
            end
        end
        for _, results in pairs(Z.db.recipeResults) do
            for _, result in pairs(results) do
                at(result.at and result.at + 601)
            end
        end
    end
    U.nextTimedRefresh, U.timedRoute = deadline, timedRoute()
end
function U.RefreshTimed(clock)
    if not U.frame or not U.frame:IsShown() or not Z.db then
        return false
    end
    if U.timedRoute ~= timedRoute() then
        scheduleTimedRefresh()
    end
    if (U.page == 9 or U.page == 10) and (clock or A.Clock()) >= (U.nextHomeRefresh or 0) then
        U.nextHomeRefresh = (clock or A.Clock()) + 5
        U.RefreshCommunityHome()
        if U.page == 10 then
            U.RefreshActivityBoard()
        end
    end
    if U.RefreshActivityDetails and U.activityDetails and U.activityDetails:IsShown() then
        U.RefreshActivityDetails()
    end
    if U.activityArchive and U.activityArchive:IsShown() then
        U.RefreshActivityArchive()
    end
    if U.page == 3 and U.groupView == 'today' and (clock or A.Clock()) >= (U.nextSessionRefresh or 0) then
        U.nextSessionRefresh = (clock or A.Clock()) + 5
        U.RefreshSessionPlans()
    end
    if U.page == 4 and (U.questView == 'shared' or U.questView == 'questgroups') and (clock or A.Clock()) >= (U.nextSharedRefresh or 0) then
        U.nextSharedRefresh = (clock or A.Clock()) + 5
        if U.questView == 'questgroups' then
            U.RefreshQuestGroups()
        else
            U.RefreshSharedQuests()
        end
    end
    local changed = false
    if U.page == 1 then
        for _, row in ipairs(U.memberList.rows) do
            local item = row.zenialItem
            if row:IsShown() and item and item.ageAt and age(item.ageAt) ~= item.ageText then
                changed = true
                break
            end
        end
    end
    if not changed and (clock or A.Clock()) < (U.nextTimedRefresh or math.huge) then
        return false
    end
    U.Refresh(nil, true)
    return true
end
function U.Refresh(all, revisionDriven)
    if not U.frame then
        U.UpdateBadges()
        return
    end
    U.RefreshJoinBanner()
    -- Explicit user refreshes also support callers that changed local data
    -- directly. Network/timer refreshes reuse the revisioned member snapshot.
    if not revisionDriven then
        S.memberModel = nil
    end
    if Z.ExpireFinder(A.Now()) then
        Z.Publish()
    end
    if Z.PvPHelp then
        Z.PvPHelp.Expire()
    end
    if all or U.page == 1 or U.page == 2 then
        memberEntries()
        local ps = S.memberModel.professions
        local signature = table.concat(ps, '\0')
        if signature ~= U.professionOptionsSignature then
            U.professionOptionsSignature = signature
            U.memberProfession:SetOptions(ps, U.memberProfession:GetText())
            if U.craftProfessionFilter then
                U.craftProfessionFilter:SetOptions(ps, U.craftProfessionFilter:GetText())
            end
        end
    end
    if all or U.page == 1 then
        refreshMembers()
    end
    if U.RefreshProfessionHistory and (all or U.page == 2) then
        U.RefreshProfessionHistory()
    end
    if all or U.page == 2 then
        if all or U.craftView ~= 'orders' then
            refreshProfessions()
        end
        if all or U.craftView == 'orders' then
            refreshCraftOrders()
        end
        if all or U.craftView == 'materials' then
            U.RefreshMaterialPlans()
        end
        if U.craftOrderForm:IsShown() then
            U.RefreshCraftIngredients()
        end
    end
    if all or U.page == 3 then
        local v = U.groupView
        if all or v == 'browse' then
            S.refreshGroupBrowse()
        end
        if all or v == 'mine' then
            S.refreshGroupMine()
        end
        if all or v == 'outgoing' then
            S.refreshGroupOutgoing()
        end
        if all or v == 'follow' then
            S.refreshGroupFollows()
        end
        if all or v == 'pvp' then
            S.refreshPvPHelp()
        end
        if all or v == 'today' then
            U.RefreshSessionPlans()
        end
        if all or v == 'scheduled' then
            U.RefreshScheduledGroups()
        end
    end
    if all or U.page == 4 then
        local v = U.questView
        if all or v == 'shared' then
            U.RefreshSharedQuests()
        end
        if all or v == 'questgroups' then
            U.RefreshQuestGroups()
        end
        if all or v == 'browse' then
            S.refreshQuestBrowse()
        end
        if all or v == 'mine' then
            S.refreshQuestMine()
        end
        if all or v == 'outgoing' then
            S.refreshQuestOutgoing()
        end
    end
    if all or U.page == 5 then
        local v = U.tradeView
        if all or v == 'browse' then
            refreshOffers()
        end
        if all or v == 'rules' then
            refreshTradeRules()
        end
        if all or v == 'manage' then
            refreshTradeManage()
        end
    end
    if all or U.page == 6 then
        refreshCharacters()
        if U.preferences then
            for name, control in pairs(U.preferences) do
                control:SetChecked(Z.db[name])
            end
        end
        if U.profileView == 'network' then
            U.profileNetworkText:SetText(Z.NetworkSetup.UserSummary())
        end
    end
    if all or U.page == 9 then
        U.RefreshCommunityHome()
    end
    if all or U.page == 10 then
        U.RefreshActivityBoard()
    end
    if all or U.page == 11 then
        U.homeAddonNavigationOption:SetChecked(not Z.ui or Z.ui.showAddonManager ~= false)
    end
    if all or U.page == HISTORY_PAGE then
        U.RefreshHistory()
    end
    if U.RefreshActivityDetails and U.activityDetails and U.activityDetails:IsShown() then
        U.RefreshActivityDetails()
    end
    if U.activityArchive and U.activityArchive:IsShown() then
        U.RefreshActivityArchive()
    end
    U.RefreshAddonAvailability()
    if U.page == ADDON_PAGE then
        U.RefreshAddonManager()
    end
    U.UpdateBadges()
    scheduleTimedRefresh()
end

function U.CloseDialogs()
    if U.memberPrivateNote and U.memberNoteOwner then
        U.noteDrafts = U.noteDrafts or {}
        U.noteDrafts[U.memberNoteOwner] = U.memberPrivateNote:GetText()
    end
    if U.memberPrivateNote then
        U.memberPrivateNote:ClearFocus()
    end
    if U.categoryPanel then
        U.categoryPanel:Hide()
    end
    if S.openPopup then
        S.openPopup:Hide()
        S.openPopup = nil
    end
    for _, name in ipairs({
        'characterConfirm',
        'historyConfirm',
        'craftOrderForm',
        'materialOrderForm',
        'scheduledEditor',
        'scheduledSeries',
        'homeWishPanel',
        'activityCreator',
        'categorySettings',
        'activityDetails',
        'activityArchive',
        'activityArchiveConfirm',
        'socialDiary',
        'notificationInbox',
        'pvpPreview',
        'pvpHelpers',
        'templateNameDialog',
        'discord',
    }) do
        if U[name] then
            U[name]:Hide()
        end
    end
    U.removeCharacterKey, U.historyDeletePeer, U.craftOrderContext = nil, nil, nil
    if U.modalBlocker then
        U.modalBlocker:Hide()
    end
end
function U.CloseDropdowns()
    if S.openPopup then
        S.openPopup:Hide()
        S.openPopup = nil
    end
end
-- SetPropagateKeyboardInput is restricted in combat. Dialogs pass keys through
-- by default; only ESC is held back, and only out of combat. Combat start
-- (PLAYER_REGEN_DISABLED, before lockdown) releases every dialog, so a dialog
-- left open can never keep swallowing movement keys during a fight.
local keyboardDialogs, swallowing = {}, {}
local function propagate(dialog, value)
    if not dialog.SetPropagateKeyboardInput or A.Call(InCombatLockdown) == true then
        return false
    end
    local ok = pcall(dialog.SetPropagateKeyboardInput, dialog, value)
    if ok then
        swallowing[dialog] = value == false or nil
    end
    return ok
end
-- Lockdown may already be active when the event arrives: a dialog still holding ESC capture cannot be released then, so it is hidden (not protected) and re-synced on PLAYER_REGEN_ENABLED.
U.combatKeyboard = CreateFrame('Frame')
for _, e in ipairs({ 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED' }) do
    pcall(U.combatKeyboard.RegisterEvent, U.combatKeyboard, e)
end
-- Keyboard capture is only enabled while out of combat: EnableKeyboard(true) defaults to consuming keys and propagation cannot be changed under lockdown (ESC then relies on UISpecialFrames/close button). Re-enabled on PLAYER_REGEN_ENABLED.
local function syncKeyboard(dialog)
    if not dialog.EnableKeyboard then
        return
    end
    if A.Call(InCombatLockdown) == true then
        pcall(dialog.EnableKeyboard, dialog, false)
        swallowing[dialog] = nil
    else
        pcall(dialog.EnableKeyboard, dialog, true)
        propagate(dialog, true)
    end
end
U.combatKeyboard:SetScript('OnEvent', function(_, event)
    for dialog in pairs(keyboardDialogs) do
        if event == 'PLAYER_REGEN_ENABLED' then
            syncKeyboard(dialog)
        elseif not propagate(dialog, true) then
            if swallowing[dialog] and dialog.Hide then
                dialog:Hide()
            end
            pcall(dialog.EnableKeyboard, dialog, false)
        end
    end
end)
local function makeModal(dialog)
    dialog:EnableMouse(true)
    dialog:SetFrameLevel(U.frame:GetFrameLevel() + 50)
    if U.sidebar then
        U.sidebar:SetFrameLevel(U.frame:GetFrameLevel() + 60)
    end
    dialog:SetScript('OnShow', function(self)
        U.modalBlocker:Show()
        if keyboardDialogs[self] then
            syncKeyboard(self)
        else
            propagate(self, true)
        end
    end)
    dialog:SetScript('OnHide', function()
        for _, name in ipairs({
            'characterConfirm',
            'historyConfirm',
            'craftOrderForm',
            'materialOrderForm',
            'scheduledEditor',
            'scheduledSeries',
            'categoryPanel',
            'homeWishPanel',
            'activityCreator',
            'categorySettings',
            'activityDetails',
            'activityArchive',
            'activityArchiveConfirm',
            'socialDiary',
            'notificationInbox',
            'pvpPreview',
            'pvpHelpers',
            'templateNameDialog',
        }) do
            if U[name] and U[name]:IsShown() then
                return
            end
        end
        U.modalBlocker:Hide()
    end)
    if dialog.EnableKeyboard then
        dialog:EnableKeyboard(true)
        keyboardDialogs[dialog] = true
        dialog:SetScript('OnKeyDown', function(self, key)
            propagate(self, key ~= 'ESCAPE')
            if key == 'ESCAPE' then
                if S.openPopup and S.openPopup:IsShown() then
                    U.CloseDropdowns()
                elseif U.calendarPicker and U.calendarPicker:IsShown() then
                    U.calendarPicker:Hide()
                else
                    self:Hide()
                end
            end
        end)
    end
end
S.makeModal = makeModal
