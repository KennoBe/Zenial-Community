local Z = ZenialCommunity
local U = Z.UI
local A = Z.Adapter
local S = U.Shared
local tr = S.tr
local CLASSES, label, button, edit, selector, checkbox, list = S.CLASSES, S.label, S.button, S.edit, S.selector, S.checkbox, S.list
local peerOnline, panel, memberFor, refreshMembers = S.peerOnline, S.panel, S.memberFor, S.refreshMembers
local T = Z.Theme

-- Background and header of the member detail card. Positions are set by U.RefreshMemberCategories; the card
-- is created first so every control placed on it is drawn above it.
local function createMemberCard(page)
    local card = CreateFrame('Frame', nil, page, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.memberCard = card
    card:SetSize(280, 400)
    card:SetPoint('TOPLEFT', 570, -70)
    if T then
        T.Panel(card, 'surface')
    end
    local glow = card:CreateTexture(nil, 'BACKGROUND')
    glow:SetPoint('TOPLEFT', 1, -1)
    glow:SetPoint('TOPRIGHT', -1, -1)
    glow:SetHeight(77)
    card.headerGlow = glow
    if T then
        T.SetGradient(glow, 'VERTICAL', 'panelRaised', 'panel')
    end
    card.divider = card:CreateTexture(nil, 'BORDER')
    card.divider:SetPoint('TOPLEFT', 1, -78)
    card.divider:SetPoint('TOPRIGHT', -1, -78)
    card.divider:SetHeight(1)
    card.portrait = card:CreateTexture(nil, 'ARTWORK')
    card.portrait:SetSize(52, 52)
    card.portrait:SetPoint('TOPLEFT', 12, -13)
    card.name = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    card.name:SetPoint('TOPLEFT', 74, -13)
    card.name:SetSize(190, 20)
    card.name:SetJustifyH('LEFT')
    card.name:SetWordWrap(false)
    card.classLine = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    card.classLine:SetPoint('TOPLEFT', 74, -37)
    card.classLine:SetSize(190, 14)
    card.classLine:SetJustifyH('LEFT')
    card.classLine:SetWordWrap(false)
    card.statusDot = card:CreateTexture(nil, 'ARTWORK')
    card.statusDot:SetSize(7, 7)
    card.statusDot:SetPoint('TOPLEFT', 74, -57)
    card.status = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    card.status:SetPoint('TOPLEFT', 86, -54)
    card.status:SetJustifyH('LEFT')
    card.status:SetWordWrap(false)
    if T then
        T.Tint(card.divider, 'SetColorTexture', 'line')
        T.Tint(card.classLine, 'SetTextColor', 'dim')
        card.layerTag = T.CreateTag(card, 'accentBlueBg', 'accentBlueEdge', 'accentBlue')
    else
        card.layerTag = CreateFrame('Frame', nil, card)
        card.layerTag.text = card.layerTag:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        card.layerTag.SetLabel = function(self, value)
            self.text:SetText(value)
        end
    end
    card.layerTag:SetHeight(16)
    card.layerTag:Hide()
    -- No member selected: a symbol and the hint instead of an empty sheet (positioned by U.RefreshMemberCategories).
    if Z.Kit and T then
        card.empty = Z.Kit.EmptyState(card, { icon = 'members', title = tr('Select a member.'), hint = '', width = 240 })
    end
    return card
end

function S.createMembersPage(f)
    local p = U.pages[1]
    local C = Z.SocialCategories
    createMemberCard(p)
    -- Filter bar: a plate of page textures behind the filter controls (placed in U.RefreshMembersPageLayout).
    U.memberFilterBar = Z.Kit and Z.Kit.FilterBar(p)
    U.memberSearch = edit(p, 'Search', 10, -6, 230, 64)
    if Z.Kit and T then
        local icon = Z.Kit.Icon(U.memberSearch, 'search', 14, 'muted')
        icon:SetPoint('LEFT', 8, 0)
        U.memberSearchIcon = icon
        if U.memberSearch.SetTextInsets then
            U.memberSearch:SetTextInsets(26, 8, 4, 4)
        end
    end
    U.memberStatus = selector(p, tr('Status'), 250, -6, 100, { 'ALL', 'ONLINE' }, refreshMembers)
    U.memberStatus:SetText(Z.uiCharacter and Z.uiCharacter.memberStatus == 'ONLINE' and 'ONLINE' or 'ALL')
    U.memberFavoriteFilter = selector(p, tr('Quick filter'), 360, -6, 145, { 'ALL', 'FAVORITES', 'MY_GUILD' }, refreshMembers, function(id)
        return id == 'ALL' and tr('All') or id == 'FAVORITES' and tr('Favorites') or id == 'MY_GUILD' and tr('My guild') or C.Label(id)
    end)
    U.memberFavoriteFilter:SetPopupWidth(270)
    U.memberAdvanced = button(p, tr('Advanced'), 515, -22, 120, function()
        U.memberAdvancedOpen = not U.memberAdvancedOpen
        U.RefreshMembersPageLayout()
    end, 'ghost')
    U.memberClass = selector(p, 'Class', 10, -56, 105, CLASSES, refreshMembers)
    U.memberProfession = selector(p, 'Profession', 125, -56, 130, { 'ALL_PROFESSIONS' }, refreshMembers)
    U.memberSort = selector(p, 'Sort', 265, -56, 175, { 'ONLINE_FIRST', 'LAST_SEEN', 'NAME', 'LEVEL_ASC', 'LEVEL_DESC' }, refreshMembers)
    U.memberCategoryFilter = selector(p, tr('Private category'), 450, -56, 330, { 'ALL', 'RECONTACT' }, refreshMembers, function(id)
        return id == 'ALL' and tr('All private categories') or id == 'RECONTACT' and tr('Recontact suggestions') or C.Label(id)
    end)
    U.memberSearch:SetScript('OnTextChanged', refreshMembers)
    U.memberDiary = button(p, tr('Social diary'), 645, -22, 195, function() U.OpenSocialDiary(nil, nil) end, 'ghost')
    if Z.Kit and T then
        for button, name in pairs({ [U.memberAdvanced] = 'filter', [U.memberDiary] = 'history' }) do
            local icon = Z.Kit.Icon(button, name, 14, 'textSoft')
            icon:SetPoint('LEFT', 10, 0)
            T.AlignButtonText(button, 30)
        end
    end
    U.memberCount = label(p, '', 10, -62, 300)
    if T and T.Font then
        T.Font(U.memberCount, 'caption', 'dim')
    end
    -- Local view preference only; it changes neither contacts nor published data.
    U.memberGrouping = checkbox(p, tr('Group by main character'), 320, -57, 225, function(self)
        U.SetMemberGrouping(self:GetChecked() == true)
    end)
    U.memberGrouping:SetChecked(not Z.ui or Z.ui.memberGrouping ~= false)
    U.memberList = list(p, 0, -80, 545, 314)
    U.memberDetail = label(p, 'Select a member.', 570, -68, 280, 'GameFontHighlight')
    U.memberDetail:SetHeight(205)
    button(p, 'Refresh', 0, -407, 125, function()
        A.DiscoveryTick(true)
        U.Refresh()
    end)
    U.memberPrivateNote = edit(p, tr('Private Notiz'), 570, -282, 280, 500, true)
    U.memberPrivateNote:SetHeight(46)
    -- The multi-line box has no visible field of its own in the client: draw one.
    if T and T.FieldBackground then
        T.FieldBackground(U.memberPrivateNote)
    end
    -- Favourite: an icon-only star in the card's top right corner (placed by U.RefreshMemberCategories).
    U.memberFavorite = button(p, '', 820, -81, 26, function()
        if U.memberKey then
            local value, err = Z.Social.ToggleFavorite(U.memberKey)
            if value == nil then
                U.Message(err)
            else
                refreshMembers()
            end
        end
    end, 'ghost')
    U.memberFavorite:SetHeight(26)
    if Z.Kit and T then
        U.memberFavorite.zenialStar = Z.Kit.Icon(U.memberFavorite, 'star', 16, 'muted')
        U.memberFavorite.zenialStar:SetPoint('CENTER')
    end
    if GameTooltip and U.memberFavorite.HookScript then
        U.memberFavorite:HookScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
            GameTooltip:SetText(tr(self.zenialSelected and 'Remove favorite' or 'Favorite'))
            GameTooltip:Show()
        end)
        U.memberFavorite:HookScript('OnLeave', function()
            GameTooltip:Hide()
        end)
    end
    -- Draws the star for the current state; zenialSelected keeps carrying the favourite flag.
    function U.UpdateFavoriteStar(enabled, favorite)
        local star = U.memberFavorite
        star:SetEnabled(enabled == true)
        star.zenialSelected = favorite == true
        if star.zenialStar and T then
            T.Tint(star.zenialStar, 'SetVertexColor', favorite and 'gold' or enabled and 'dim' or 'disabledText')
        end
    end
    U.memberWhisper = button(p, 'Whisper', 570, -382, 125, function()
        -- Real, reachable character (active twink of a group), never an offline main or a group anchor.
        local c = S.memberContactTarget(memberFor(U.memberKey))
        if c and not Z.db.blocked[c.key] then
            A.Whisper(c.target)
        end
    end)
    U.memberInvite = button(p, 'Invite to group', 705, -382, 145, function()
        local t = S.memberContactTarget(memberFor(U.memberKey))
        local c = t and Z.db.contacts[t.key]
        if c then
            if not peerOnline(t.key) then
                U.Message('This player is offline.')
                U.Refresh()
                return
            end
            local ok, err = A.Invite(c.target)
            U.Message(ok and Z.T('Invitation submitted to %s; awaiting response.', c.target) or err)
        end
    end)
    -- Action symbols on the left of the four secondary buttons.
    if Z.Kit and T then
        for button, name in pairs({ [U.memberWhisper] = 'whisper', [U.memberInvite] = 'invite' }) do
            local icon = Z.Kit.Icon(button, name, 14, 'textSoft')
            icon:SetPoint('LEFT', 8, 0)
            button.zenialActionIcon = icon
            T.AlignButtonText(button, 28)
        end
    end
    for _, b in ipairs({ U.memberWhisper, U.memberInvite }) do
        if GameTooltip and b.HookScript then
            b:HookScript('OnEnter', function(self)
                if self.tipText then
                    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                    GameTooltip:AddLine(self.tipText, 1, 0.9, 0.7, true)
                    GameTooltip:Show()
                end
            end)
            b:HookScript('OnLeave', function()
                GameTooltip:Hide()
            end)
        end
    end
    U.memberBack = button(p, '← Back to list', 665, 0, 180, function()
        U.CloseCompactArea('members')
    end)
    U.memberBack:Hide()

    -- The private note saves itself while typing. Only text the note store rejects stays a draft.
    if Z.Kit and T and U.memberCard then
        U.memberNoteSaved = Z.Kit.Icon(U.memberCard, 'check', 12, 'success')
        U.memberNoteSaved:Hide()
    end
    U.memberPrivateNote:SetScript('OnTextChanged', function(self)
        if U.memberNoteOwner and not U.memberNoteBinding then
            U.AutoSavePrivateNote()
        end
    end)
    local categoryOptions = { 'ALL', 'RECONTACT' }
    for _, id in ipairs(C.ORDER) do categoryOptions[#categoryOptions + 1] = id end
    U.memberCategoryFilter:SetOptions(categoryOptions, 'ALL')
    function U.RefreshMembersPageLayout()
        local advanced = U.memberAdvancedOpen == true
        if U.compactArea ~= 'members' then
            for _, control in ipairs({ U.memberClass, U.memberClass.caption, U.memberProfession, U.memberProfession.caption, U.memberSort, U.memberSort.caption }) do
                control:SetShown(advanced)
            end
        end
        -- Category choices remain in the quick filter; the legacy category control is intentionally unreachable.
        U.memberCategoryFilter:SetShown(false)
        U.memberCount:ClearAllPoints(); U.memberCount:SetPoint('TOPLEFT', 10, advanced and -110 or -62)
        U.memberGrouping:ClearAllPoints(); U.memberGrouping:SetPoint('TOPLEFT', 320, advanced and -105 or -57)
        local bar = U.memberFilterBar
        if bar then
            local pageWidth = U.pages[1]:GetWidth()
            local horizontal = (type(pageWidth) == 'number' and pageWidth > 0 and pageWidth or 856) / 856
            bar:Place(0, 0, 850 * horizontal, advanced and 102 or 54)
            bar:SetShown(U.compactArea ~= 'members')
        end
        U.memberList:ClearAllPoints(); U.memberList:SetPoint('TOPLEFT', 0, advanced and -128 or -80)
        local offset = advanced and 48 or 0
        local previousOffset = U.memberLayoutOffset or 0
        local height = U.memberList:GetHeight() - (offset - previousOffset)
        U.memberList.height = height
        U.memberList:SetHeight(height)
        U.memberList.child:SetHeight(U.memberList.height)
        U.memberLayoutOffset = offset
    end
    U.memberAdvancedOpen = false
    U.RefreshMembersPageLayout()
    U.memberCategories = button(p, tr('Private categories'), 140, -407, 180, function()
        U.OpenPrivateCategories(false)
    end)
    U.categoryPanel = panel(U.frame)
    U.categoryPanel:ClearAllPoints()
    U.categoryPanel:SetPoint('CENTER', U.frame, 'CENTER', 0, 0)
    U.categoryPanel:SetSize(620, 430)
    U.categoryPanel:SetClampedToScreen(true)
    if U.categoryPanel.SetBackdropColor then
        if T then
            T.Tint(U.categoryPanel, 'SetBackdropColor', 'inset', 1)
        else
            U.categoryPanel:SetBackdropColor(0.045, 0.031, 0.021, 1)
        end
    end
    label(U.categoryPanel, tr('Private categories'), 16, -14, 585, 'GameFontNormalLarge')
    U.categoryContact = selector(U.categoryPanel, tr('Contact'), 16, -42, 585, {}, function(key)
        U.categoryKey = key
        U.RefreshCategoryPanel()
    end, function(key)
        local m = memberFor(key)
        return m and m.target or key
    end)
    U.categorySummary = label(U.categoryPanel, '', 16, -91, 585, 'GameFontHighlight')
    U.categorySummary:SetHeight(134)
    U.categoryChecks = {}
    for i, id in ipairs(C.ORDER) do
        local tag = id
        U.categoryChecks[id] = checkbox(
            U.categoryPanel,
            C.Label(id),
            16 + ((i - 1) % 2) * 292,
            -236 - math.floor((i - 1) / 2) * 34,
            280,
            function(self)
                local ok, err = C.Set(U.categoryKey, tag, self:GetChecked() == true)
                if not ok then
                    U.Message(err)
                end
                refreshMembers()
            end
        )
    end
    button(U.categoryPanel, tr('Close'), 454, -390, 146, function()
        U.categoryPanel:Hide()
    end)
    U.categoryPanel:Hide()
end
