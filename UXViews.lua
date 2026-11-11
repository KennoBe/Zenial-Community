local Z = ZenialCommunity
local U = Z.UI
local A = Z.Adapter
local H = Z.History
local S = U.Shared
local tr = S.tr
local NAV_ICONS, selectNav, rows, resizeList, keys = S.NAV_ICONS, S.selectNav, S.rows, S.resizeList, S.keys
local craftStatusText, refreshProfessions, refreshCraftOrders = S.craftStatusText, S.refreshProfessions, S.refreshCraftOrders
local refreshOffers, refreshTradeRules, refreshTradeManage = S.refreshOffers, S.refreshTradeRules, S.refreshTradeManage
local refreshCharacters = S.refreshCharacters

function U.SetCraftView(v)
    local allowed = { search = true, mine = true, orders = true, materials = true }
    v = allowed[v] and v or 'search'
    if v ~= U.craftView and U.craftOrderForm and U.craftOrderForm:IsShown()
        and U.Navigation and U.Navigation.UnsavedInput() == 'craftOrderForm'
    then
        U.Message(U.Navigation.TEXT['unsaved-input'])
        return false
    end
    U.craftView = v
    U.craftSearchFrame:SetShown(U.craftView == 'search')
    U.craftMineFrame:SetShown(U.craftView == 'mine')
    if U.craftOrdersFrame then
        U.craftOrdersFrame:SetShown(U.craftView == 'orders')
    end
    if U.materialPlanFrame then
        U.materialPlanFrame:SetShown(U.craftView == 'materials')
        selectNav(U.craftMaterialsTab, U.craftView == 'materials')
    end
    if U.craftOrderFilterBar then
        U.craftOrderFilterBar:SetShown(U.craftView == 'orders' or U.craftView == 'materials')
        selectNav(U.craftFilterAll, U.craftView == 'orders' and U.craftOrderFilter == 'all')
        selectNav(U.craftFilterIncoming, U.craftView == 'orders' and U.craftOrderFilter == 'incoming')
        selectNav(U.craftFilterOutgoing, U.craftView == 'orders' and U.craftOrderFilter == 'outgoing')
        selectNav(U.craftFilterLists, U.craftView == 'materials')
    end
    selectNav(U.craftSearchTab, U.craftView == 'search')
    selectNav(U.craftMineTab, U.craftView == 'mine')
    selectNav(U.craftOrdersTab, U.craftView == 'orders' or U.craftView == 'materials')
    if U.materialBackOrders then
        U.materialBackOrders:SetShown(U.craftView == 'materials')
    end
    if U.craftScanStatus then
        U.craftScanStatus:SetText(craftStatusText())
    end
    if Z.UIState then
        Z.UIState.Route('craft', U.craftView)
    end
    refreshProfessions()
    refreshCraftOrders()
    if U.craftView == 'materials' then
        U.RefreshMaterialPlans()
    end
    U.UpdateBadges()
end
function U.SetCraftOrderFilter(value)
    if value == 'lists' then
        U.SetCraftView('materials')
        return
    end
    if value ~= 'all' and value ~= 'incoming' and value ~= 'outgoing' then value = 'all' end
    if value ~= 'all' and U.craftOrderID and Z.CraftOrders then
        for _, order in ipairs(Z.CraftOrders.List()) do
            if order.key == U.craftOrderID and order.direction ~= value then
                U.craftOrderID = nil
                break
            end
        end
    end
    U.craftOrderFilter = value
    U.SetCraftView('orders')
end
function U.SetTradeView(v)
    local allowed = { browse = true, mine = true, rules = true, manage = true }
    U.tradeView = allowed[v] and v or 'browse'
    U.tradeBrowseFrame:SetShown(U.tradeView == 'browse')
    U.tradeMineFrame:SetShown(U.tradeView == 'mine')
    if U.tradeRulesFrame then
        U.tradeRulesFrame:SetShown(U.tradeView == 'rules')
    end
    if U.tradeManageFrame then
        U.tradeManageFrame:SetShown(U.tradeView == 'manage')
    end
    selectNav(U.tradeBrowseTab, U.tradeView == 'browse')
    selectNav(U.tradeMineTab, U.tradeView == 'mine')
    selectNav(U.tradeRulesTab, U.tradeView == 'rules')
    selectNav(U.tradeManageTab, U.tradeView == 'manage')
    if Z.UIState then
        Z.UIState.Route('trade', U.tradeView)
    end
    refreshOffers()
    refreshTradeRules()
    refreshTradeManage()
end
function U.OnItemData()
    if U.craftOrderForm and U.craftOrderForm:IsShown() then
        U.RefreshCraftIngredients()
    end
    if U.frame and U.page == 2 and U.craftView == 'materials' then
        U.RefreshMaterialPlans()
    end
    if not U.frame or U.page ~= 5 then
        return
    end
    if U.offerSearchPicker then
        U.offerSearchPicker:Refresh(U.offerSearch:HasFocus())
    end
    if U.offerItemPicker then
        U.offerItemPicker:Refresh(U.offerFields.name:HasFocus())
    end
    refreshOffers()
end
function U.SetProfileView(v)
    if v == 'display' then
        U.Navigate('settings', 'display')
        return
    elseif v == 'network' then
        U.Navigate('settings', 'privacy')
        return
    end
    U.profileView = v == 'characters' and 'characters' or 'public'
    U.profilePublicFrame:SetShown(U.profileView == 'public')
    U.profileCharactersFrame:SetShown(U.profileView == 'characters')
    U.profilePublicTab:SetShown(U.profileView ~= 'characters')
    U.profileCharactersTab:SetShown(U.profileView ~= 'characters')
    U.profileDisplayTab:Hide()
    U.profileNetworkTab:Hide()
    U.profileCharactersFrame:ClearAllPoints()
    U.profileCharactersFrame:SetPoint('TOPLEFT', 0, U.profileView == 'characters' and 0 or -42)
    selectNav(U.profilePublicTab, U.profileView == 'public')
    selectNav(U.profileCharactersTab, U.profileView == 'characters')
    if Z.UIState then
        Z.UIState.Route('profile', U.profileView)
    end
    refreshCharacters()
end

local function showControl(control, shown)
    if not control then
        return
    end
    if control.SetShown then
        control:SetShown(shown)
    end
    if control.caption then
        control.caption:SetShown(shown)
    end
    if control.button then
        control.button:SetShown(shown)
    end
    if control.text and type(control.text) ~= 'string' and control.text.SetShown then
        control.text:SetShown(shown)
    end
end
S.showControl = showControl
local function place(frame, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', x, y)
    if width then
        frame:SetWidth(width)
    end
    if height then
        frame:SetHeight(height)
    end
end
S.place = place
function U.OpenCompactArea(area)
    if not U.compactContent then
        return
    end
    U.compactArea = area
    if area == 'members' then
        showControl(U.memberAdvanced, false)
        showControl(U.memberDiary, false)
        showControl(U.memberSearch, false)
        showControl(U.memberStatus, false)
        showControl(U.memberClass, false)
        showControl(U.memberProfession, false)
        showControl(U.memberFavoriteFilter, false)
        showControl(U.memberSort, false)
        showControl(U.memberCategoryFilter, false)
        showControl(U.memberGrouping, false)
        showControl(U.memberPrivateNote, false)
        U.memberFavorite:Hide()
        U.memberNoteSave:Hide()
        U.memberCount:Hide()
        U.memberList:Hide()
        place(U.memberDetail, 0, -46, 820, 265)
        place(U.memberWhisper, 0, -330)
        place(U.memberInvite, 140, -330)
        U.memberBack:Show()
    elseif area == 'groups' then
        showControl(U.groupFilterKind, false)
        showControl(U.groupFilterActivity, false)
        showControl(U.groupFilterSearch, false)
        showControl(U.groupMatchRole, false)
        showControl(U.groupMatchLevel, false)
        showControl(U.groupMatchAvailable, false)
        U.groupBrowseCount:Hide()
        U.groupBrowseList:Hide()
        place(U.groupBrowseDetail, 0, -46, 820, 165)
        place(U.groupApplyState, 0, -218, 820)
        place(U.groupApplyStart, 0, -245)
        place(U.groupWithdraw, 0, -245)
        place(U.groupBrowseWhisper, 140, -245)
        place(U.groupApplyFrame, 0, -278)
        U.groupBack:Show()
    elseif area == 'quests' then
        showControl(U.questFilterSearch, false)
        showControl(U.questFilterZone, false)
        showControl(U.questFilterLevel, false)
        U.questFilterReset:Hide()
        U.questBrowseCount:Hide()
        U.questBrowseList:Hide()
        place(U.questBrowseDetail, 0, -46, 820, 190)
        place(U.questApplyState, 0, -240, 820)
        place(U.questApplyStart, 0, -268)
        place(U.questWithdraw, 0, -268)
        place(U.questBrowseWhisper, 150, -268)
        place(U.questApplyFrame, 0, -300)
        U.questBack:Show()
    elseif area == 'craft' then
        showControl(U.recipeSearch, false)
        showControl(U.craftProfessionFilter, false)
        showControl(U.craftOnlineFilter, false)
        U.craftSearchButton:Hide()
        U.craftResetButton:Hide()
        U.professionCount:Hide()
        U.craftSearchState:Hide()
        U.professionList:Hide()
        place(U.professionDetail, 0, -46, 820, 68)
        place(U.professionRecipeTitle, 0, -120, 820)
        place(U.professionRecipeList, 0, -140)
        resizeList(U.professionRecipeList, 820, 195)
        place(U.craftFavorite, 0, -355)
        place(U.professionWhisper, 105, -355)
        place(U.craftOrderRequest, 220, -355)
        U.craftBack:Show()
    elseif area == 'trade' then
        showControl(U.offerSearch, false)
        showControl(U.tradeKindFilter, false)
        showControl(U.tradeCategoryFilter, false)
        showControl(U.tradeMinPrice, false)
        showControl(U.tradeMaxPrice, false)
        showControl(U.tradeSort, false)
        U.tradeResetButton:Hide()
        U.offerCount:Hide()
        U.offerList:Hide()
        place(U.offerDetail, 0, -46, 820, 280)
        place(U.offerWhisper, 0, -342)
        U.tradeBack:Show()
    end
    if area == 'members' and U.RefreshMemberCategories then
        U.RefreshMemberCategories()
    end
end
function U.CloseCompactArea(area)
    area = area or U.compactArea
    U.compactArea = nil
    if area == 'members' then
        showControl(U.memberAdvanced, true)
        showControl(U.memberDiary, true)
        showControl(U.memberSearch, true)
        showControl(U.memberStatus, true)
        showControl(U.memberFavoriteFilter, true)
        if U.RefreshMembersPageLayout then
            U.RefreshMembersPageLayout()
        else
            showControl(U.memberClass, U.memberAdvancedOpen == true)
            showControl(U.memberProfession, U.memberAdvancedOpen == true)
            showControl(U.memberSort, U.memberAdvancedOpen == true)
        end
        showControl(U.memberCategoryFilter, false)
        showControl(U.memberGrouping, true)
        showControl(U.memberPrivateNote, true)
        U.memberFavorite:Show()
        U.memberNoteSave:Show()
        U.memberCount:Show()
        U.memberList:Show()
        place(U.memberDetail, 570, -68, 280, 205)
        place(U.memberWhisper, 570, -382)
        place(U.memberInvite, 705, -382)
        U.memberBack:Hide()
    elseif area == 'groups' then
        showControl(U.groupFilterKind, true)
        showControl(U.groupFilterActivity, true)
        showControl(U.groupFilterSearch, true)
        showControl(U.groupMatchRole, true)
        showControl(U.groupMatchLevel, true)
        showControl(U.groupMatchAvailable, true)
        U.groupBrowseCount:Show()
        U.groupBrowseList:Show()
        place(U.groupBrowseDetail, 430, -82, 416, 136)
        place(U.groupApplyState, 430, -218, 416)
        place(U.groupApplyStart, 430, -243)
        place(U.groupWithdraw, 430, -243)
        place(U.groupBrowseWhisper, 565, -243)
        place(U.groupApplyFrame, 430, -273)
        U.groupBack:Hide()
    elseif area == 'quests' then
        showControl(U.questFilterSearch, true)
        showControl(U.questFilterZone, true)
        showControl(U.questFilterLevel, true)
        U.questFilterReset:Show()
        U.questBrowseCount:Show()
        U.questBrowseList:Show()
        place(U.questBrowseDetail, 430, -68, 416, 132)
        place(U.questApplyState, 430, -205, 416)
        place(U.questApplyStart, 430, -230)
        place(U.questWithdraw, 430, -230)
        place(U.questBrowseWhisper, 580, -230)
        place(U.questApplyFrame, 430, -260)
        U.questBack:Hide()
    elseif area == 'craft' then
        showControl(U.recipeSearch, true)
        showControl(U.craftProfessionFilter, true)
        showControl(U.craftOnlineFilter, true)
        U.craftSearchButton:Show()
        U.craftResetButton:Show()
        U.professionCount:Show()
        U.craftSearchState:Show()
        U.professionList:Show()
        place(U.professionDetail, 495, -102, 345, 68)
        place(U.professionRecipeTitle, 495, -176, 345)
        place(U.professionRecipeList, 495, -196)
        resizeList(U.professionRecipeList, 345, 145)
        place(U.craftFavorite, 495, -365)
        place(U.professionWhisper, 595, -365)
        place(U.craftOrderRequest, 710, -365)
        U.craftBack:Hide()
    elseif area == 'trade' then
        showControl(U.offerSearch, true)
        showControl(U.tradeKindFilter, true)
        showControl(U.tradeCategoryFilter, true)
        showControl(U.tradeMinPrice, true)
        showControl(U.tradeMaxPrice, true)
        showControl(U.tradeSort, true)
        U.tradeResetButton:Show()
        U.offerCount:Show()
        U.offerList:Show()
        place(U.offerDetail, 480, -112, 360, 240)
        place(U.offerWhisper, 480, -365)
        U.tradeBack:Hide()
    end
    U.Refresh()
    if U.ApplyResponsiveLayout then
        U.ApplyResponsiveLayout()
    end
end

local function historyTime(at)
    local now = A.Now()
    local today = date('%Y%m%d', now)
    local day = date('%Y%m%d', at)
    if day == today then
        return tr('Heute, ') .. date('%H:%M', at)
    end
    if date('%Y%m%d', now - 86400) == day then
        return tr('Gestern, ') .. date('%H:%M', at)
    end
    return date('%d.%m.%Y %H:%M', at)
end
local function selectedHistoryEntry()
    if not H or not H.store or not U.historyEntryID then
        return nil
    end
    for _, e in ipairs(H.store.entries) do
        if e.id == U.historyEntryID then
            return e
        end
    end
end
function U.RefreshHistory()
    if not U.historyList or not H then
        return
    end
    local charOptions = { 'ALL_CHARACTERS' }
    U.historyCharacterMap = {}
    for _, key in ipairs(keys(Z.account.characters)) do
        local c = Z.account.characters[key]
        charOptions[#charOptions + 1] = c.target
        U.historyCharacterMap[c.target] = key
    end
    U.historyCharacter:SetOptions(charOptions, U.historyCharacter:GetText())
    local days = ({ DAYS_7 = 7, DAYS_30 = 30, DAYS_90 = 90 })[U.historyPeriod:GetText()] or 7
    local kind = ({ GROUP = 'group', QUEST = 'quest', CRAFT = 'craft' })[U.historyKind:GetText()]
    local ownKey = U.historyCharacterMap[U.historyCharacter:GetText()]
    local filtered = H.Query({ days = days, kind = kind, ownKey = ownKey, query = U.historySearch:GetText() })
    local items, valid = {}, false
    for _, e in ipairs(filtered) do
        local entryID = e.id
        if entryID == U.historyEntryID then
            valid = true
        end
        local peer = e.peerTarget ~= '' and e.peerTarget or tr('Kein Spieler')
        items[#items + 1] = {
            selected = entryID == U.historyEntryID,
            icon = e.kind == 'quest' and NAV_ICONS.quests or e.kind == 'craft' and NAV_ICONS.crafting or NAV_ICONS.groups,
            text = '|cffffd36b'
                .. historyTime(e.at)
                .. '|r · '
                .. e.ownTarget
                .. '\n'
                .. peer
                .. ' · '
                .. e.content
                .. ' · '
                .. H.EventLabel(e.event),
            click = function()
                U.historyEntryID = entryID
                U.RefreshHistory()
            end,
        }
    end
    if not valid then
        U.historyEntryID = nil
    end
    U.SetEmptyHint(U.historyList, 'No events in this period. Widen the period or reset the filters.')
    rows(U.historyList, items, 58)
    U.historyCount:SetText(#items == 1 and tr('1 Ereignis') or #items .. tr(' Ereignisse'))
    local entry = selectedHistoryEntry()
    if not entry then
        U.historyDetail:SetText(tr('Wähle einen Eintrag aus, um den Verlauf der Anfrage zu sehen.'))
        rows(U.historyRelatedList, {}, 42)
        U.historyDeletePlayer:SetEnabled(false)
        return
    end
    U.historyDetail:SetText(
        '|cffffd36b'
            .. entry.content
            .. '|r\n'
            .. (entry.kind == 'group' and tr('Gruppe') or entry.kind == 'craft' and tr('Crafting') or tr('Quest Help'))
            .. ' · '
            .. entry.ownTarget
            .. '\n'
            .. (entry.peerTarget ~= '' and entry.peerTarget or tr('Kein Spieler'))
    )
    local related = {}
    for _, e in ipairs(H.Related(entry)) do
        related[#related + 1] = {
            icon = e.kind == 'quest' and NAV_ICONS.quests or e.kind == 'craft' and NAV_ICONS.crafting or NAV_ICONS.groups,
            text = historyTime(e.at) .. ' · ' .. (e.peerTarget ~= '' and e.peerTarget or e.ownTarget) .. '\n' .. H.EventLabel(e.event),
        }
    end
    rows(U.historyRelatedList, related, 42)
    U.historyDeletePlayer:SetEnabled(entry.peerKey ~= '')
end
function U.OpenHistory(peerKey)
    U.Create()
    if U.Navigation.UnsavedInput() then
        return U.Navigation.Fail('unsaved-input')
    end
    U.historyPeriod:SetText('DAYS_90')
    U.historyKind:SetText('ALL_KINDS')
    U.historyCharacter:SetText('ALL_CHARACTERS')
    local target = peerKey and Z.db.contacts[peerKey] and Z.db.contacts[peerKey].target
    if not target and peerKey and H.byPeer and H.byPeer[peerKey] and H.byPeer[peerKey][1] then
        target = H.byPeer[peerKey][1].peerTarget
    end
    U.historySearch:SetText(target or '')
    return U.Navigate('history')
end
function U.ShowHistoryDeleteConfirm(peerOnly)
    local entry = selectedHistoryEntry()
    if peerOnly and (not entry or entry.peerKey == '') then
        return
    end
    U.historyDeletePeer = peerOnly and entry.peerKey or nil
    U.historyConfirmText:SetText(
        peerOnly and (tr('Alle Historieneinträge zu ') .. entry.peerTarget .. tr(' wirklich löschen?'))
            or tr('Die gesamte Finder-Historie wirklich löschen?')
    )
    U.historyConfirm:Show()
end
