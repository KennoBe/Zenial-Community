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
    return card
end

function S.createMembersPage(f)
    local p = U.pages[1]
    local C = Z.SocialCategories
    createMemberCard(p)
    U.memberSearch = edit(p, 'Search', 0, 0, 205, 64)
    U.memberStatus = selector(p, tr('Status'), 215, 0, 100, { 'ALL', 'ONLINE' }, refreshMembers)
    U.memberStatus:SetText(Z.uiCharacter and Z.uiCharacter.memberStatus == 'ONLINE' and 'ONLINE' or 'ALL')
    U.memberFavoriteFilter = selector(p, tr('Quick filter'), 325, 0, 145, { 'ALL', 'FAVORITES', 'MY_GUILD' }, refreshMembers, function(id)
        return id == 'ALL' and tr('All') or id == 'FAVORITES' and tr('Favorites') or id == 'MY_GUILD' and tr('My guild') or C.Label(id)
    end)
    U.memberFavoriteFilter:SetPopupWidth(270)
    U.memberAdvanced = button(p, tr('Advanced'), 480, 0, 120, function()
        U.memberAdvancedOpen = not U.memberAdvancedOpen
        U.RefreshMembersPageLayout()
    end)
    U.memberClass = selector(p, 'Class', 0, -54, 105, CLASSES, refreshMembers)
    U.memberProfession = selector(p, 'Profession', 115, -54, 130, { 'ALL_PROFESSIONS' }, refreshMembers)
    U.memberSort = selector(p, 'Sort', 255, -54, 175, { 'ONLINE_FIRST', 'LAST_SEEN', 'NAME', 'LEVEL_ASC', 'LEVEL_DESC' }, refreshMembers)
    U.memberCategoryFilter = selector(p, tr('Private category'), 440, -54, 330, { 'ALL', 'RECONTACT' }, refreshMembers, function(id)
        return id == 'ALL' and tr('All private categories') or id == 'RECONTACT' and tr('Recontact suggestions') or C.Label(id)
    end)
    U.memberSearch:SetScript('OnTextChanged', refreshMembers)
    U.memberDiary = button(p, tr('Social diary'), 615, 0, 180, function() U.OpenSocialDiary(nil, nil) end)
    U.memberCount = label(p, '', 0, -52, 300)
    -- Local view preference only; it changes neither contacts nor published data.
    U.memberGrouping = checkbox(p, tr('Group by main character'), 310, -47, 235, function(self)
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
    U.memberFavorite = button(p, 'Favorite', 570, -349, 125, function()
        if U.memberKey then
            local value, err = Z.Social.ToggleFavorite(U.memberKey)
            if value == nil then
                U.Message(err)
            else
                refreshMembers()
            end
        end
    end)
    U.memberNoteSave = button(p, tr('Notiz speichern'), 705, -349, 145, function()
        U.SavePrivateNote()
    end)
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

    U.memberPrivateNote:SetScript('OnTextChanged', function(self)
        if U.memberNoteOwner and not U.memberNoteBinding then
            U.noteDrafts = U.noteDrafts or {}
            U.noteDrafts[U.memberNoteOwner] = self:GetText()
        end
    end)
    local categoryOptions = { 'ALL', 'RECONTACT' }
    for _, id in ipairs(C.ORDER) do categoryOptions[#categoryOptions + 1] = id end
    U.memberCategoryFilter:SetOptions(categoryOptions, 'ALL')
    function U.RefreshMembersPageLayout()
        local advanced = U.memberAdvancedOpen == true
        for _, control in ipairs({ U.memberClass, U.memberClass.caption, U.memberProfession, U.memberProfession.caption, U.memberSort, U.memberSort.caption }) do
            control:SetShown(advanced)
        end
        -- Category choices remain in the quick filter; the legacy category control is intentionally unreachable.
        U.memberCategoryFilter:Hide()
        U.memberCategoryFilter.caption:Hide()
        U.memberCount:ClearAllPoints(); U.memberCount:SetPoint('TOPLEFT', 0, advanced and -100 or -52)
        U.memberGrouping:ClearAllPoints(); U.memberGrouping:SetPoint('TOPLEFT', 310, advanced and -95 or -47)
        U.memberList:ClearAllPoints(); U.memberList:SetPoint('TOPLEFT', 0, advanced and -128 or -80)
        U.memberList.height = (advanced and 262 or 314)
        U.memberList:SetHeight(U.memberList.height)
        U.memberList.child:SetHeight(U.memberList.height)
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
