local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local TRADE_CATEGORIES, TRADE_SORTS, label, button, navButton = S.TRADE_CATEGORIES, S.TRADE_SORTS, S.label, S.button, S.navButton
local edit, selector, list, itemSuggestions, peerOnline = S.edit, S.selector, S.list, S.itemSuggestions, S.peerOnline
local goldFilter, refreshOffers, refreshTradeRules = S.goldFilter, S.refreshOffers, S.refreshTradeRules
local storedOfferDraft, refreshTradeManage = S.storedOfferDraft, S.refreshTradeManage

function S.createTradePage(f)
    local p = U.pages[5]
    U.tradeBrowseTab = navButton(p, tr('Find'), 0, 0, 170, function()
        U.SetTradeView('browse')
    end)
    U.tradeManageTab = navButton(p, tr('My Offers'), 180, 0, 170, function()
        U.SetTradeView('manage')
    end)
    U.tradeRulesTab = navButton(p, tr('Search alerts'), 360, 0, 170, function()
        U.SetTradeView('rules')
    end)
    U.tradeMineTab = button(p, tr('Create offer'), 540, 0, 170, function()
        U.SetTradeView('mine')
    end, 'primary')
    U.tradeCreateButton = U.tradeMineTab
    U.tradeBrowseFrame = CreateFrame('Frame', nil, p)
    U.tradeBrowseFrame:SetPoint('TOPLEFT', 0, -40)
    U.tradeBrowseFrame:SetSize(856, 414)
    -- Plate of frame textures behind the filter line (placed by U.LayoutTradeVisual).
    U.tradeFilterBar = Z.Kit and Z.Kit.FilterBar(U.tradeBrowseFrame)
    U.offerSearch = edit(U.tradeBrowseFrame, tr('Gegenstand, Dienstleistung oder Spieler'), 8, 0, 280, 96)
    U.tradeKindFilter = selector(U.tradeBrowseFrame, tr('Art'), 300, 0, 125, { 'ALL', 'SELL', 'BUY', 'SERVICE' }, refreshOffers)
    U.tradeAdvancedOpen = false
    U.tradeAdvancedToggle = button(U.tradeBrowseFrame, tr('Advanced'), 437, -17, 100, function()
        U.tradeAdvancedOpen = not U.tradeAdvancedOpen
        U.RefreshTradeAdvanced()
    end)
    U.tradeResetButton = button(U.tradeBrowseFrame, tr('Reset'), 543, -17, 100, function()
        U.offerSearchItemID = nil
        U.offerSearch:SetText('')
        U.tradeKindFilter:SetText('ALL')
        U.tradeCategoryFilter:SetText('ALL_ITEM_CATEGORIES')
        U.tradeMinPrice:SetText('')
        U.tradeMaxPrice:SetText('')
        U.tradeSort:SetText('TRADE_NAME')
        refreshOffers()
    end)
    U.tradeSaveSearch = button(U.tradeBrowseFrame, tr('Save search'), 649, -17, 197, function()
        local minPrice, minOK = goldFilter(U.tradeMinPrice:GetText())
        local maxPrice, maxOK = goldFilter(U.tradeMaxPrice:GetText())
        if not minOK or not maxOK or minPrice and maxPrice and minPrice > maxPrice then
            U.Message(tr('Preisfilter ist ungültig.'))
            return
        end
        local query = U.offerSearch:GetText()
        local id, err = Z.TradeManager.SaveRule({
            name = query ~= '' and query or tr('Alle Angebote'),
            query = query,
            itemID = U.offerSearchItemID or 0,
            kind = U.tradeKindFilter:GetText(),
            category = U.tradeCategoryFilter:GetText(),
            minPrice = minPrice,
            maxPrice = maxPrice,
        })
        U.Message(id and tr('Suchalarm gespeichert.') or err)
        refreshTradeRules()
    end)
    U.tradeAdvancedFrame=CreateFrame('Frame',nil,U.tradeBrowseFrame)
    U.tradeAdvancedFrame:SetAllPoints(U.tradeBrowseFrame)
    U.tradeCategoryFilter = selector(U.tradeAdvancedFrame, tr('Kategorie'), 8, -48, 190, TRADE_CATEGORIES, refreshOffers)
    U.tradeMinPrice = edit(U.tradeAdvancedFrame, 'Minimum unit price (gold)', 208, -48, 120, 12)
    U.tradeMaxPrice = edit(U.tradeAdvancedFrame, 'Maximum unit price (gold)', 338, -48, 120, 12)
    U.tradeSort = selector(U.tradeAdvancedFrame, 'Sort', 468, -48, 205, TRADE_SORTS, refreshOffers)
    U.tradeFilterSummary = label(U.tradeBrowseFrame, '', 8, -48, 832, 'GameFontHighlight')
    U.tradeFilterSummary:SetHeight(28)
    U.tradeCategoryFilter:SetShown(false)
    U.tradeMinPrice:Hide();U.tradeMinPrice.caption:Hide()
    U.tradeMaxPrice:Hide();U.tradeMaxPrice.caption:Hide()
    U.tradeSort:SetShown(false)
    U.tradeAdvancedFrame:Hide()
    U.tradeMinPrice:SetScript('OnTextChanged', refreshOffers)
    U.tradeMaxPrice:SetScript('OnTextChanged', refreshOffers)
    U.offerCount = label(U.tradeBrowseFrame, '0 Angebote', 0, -92, 455, 'GameFontNormal')
    U.offerCount:SetJustifyH('RIGHT')
    U.offerList = list(U.tradeBrowseFrame, 0, -112, 455, 260)
    U.offerDetail = label(U.tradeBrowseFrame, tr('Wähle ein Angebot aus.'), 480, -112, 360, 'GameFontHighlight')
    U.offerDetail:SetHeight(230)
    U.offerWhisper = button(U.tradeBrowseFrame, tr('Anflüstern'), 480, -350, 140, function()
        local c = Z.db.contacts[U.offerKey]
        if c and peerOnline(U.offerKey) then
            A.Whisper(c.target)
        end
    end)
    U.offerWhisper:SetEnabled(false)
    U.tradeBack = button(U.tradeBrowseFrame, tr('← Zurück zur Liste'), 665, 0, 180, function()
        U.CloseCompactArea('trade')
    end)
    U.tradeBack:Hide()
    U.tradeContextText = label(U.tradeBrowseFrame, '', 0, -382, 275, 'GameFontHighlight')
    U.tradeContextText:SetHeight(32)
    U.tradeContextBack = button(U.tradeBrowseFrame, tr('Back to crafting'), 285, -388, 190, function()
        local token = U.Navigation.ActiveContext('craft')
        if token then U.Navigation.Return(token) end
    end)
    U.tradeContextBack:Hide()
    U.offerManageOwn = button(U.tradeBrowseFrame, tr('Open in My Offers'), 485, -388, 220, function()
        if U.offerID then
            U.tradeManageID = 'active\0' .. U.offerID
            U.SetTradeView('manage')
        end
    end)
    U.offerManageOwn:Hide()
    U.offerSearchPicker = itemSuggestions(U.offerSearch, U.tradeBrowseFrame, 340, refreshOffers, function(id)
        U.offerSearchItemID = id
    end)

    U.tradeMineFrame = CreateFrame('Frame', nil, p)
    U.tradeMineFrame:SetPoint('TOPLEFT', 0, -40)
    U.tradeMineFrame:SetSize(856, 414)
    U.offerPreviewCard = Z.Kit and Z.Kit.Plate(U.tradeMineFrame, 'surface')
    U.tradeEditorTitle = label(U.tradeMineFrame, tr('Create offer'), 0, 0, 420, 'GameFontNormalLarge')
    U.tradeEditorBack = button(U.tradeMineFrame, tr('← My Offers'), 650, 0, 190, function()
        U.SetTradeView('manage')
    end)
    U.tradeEditorLimitInfo = label(U.tradeMineFrame, '', 0, -320, 840, 'GameFontHighlight')
    U.tradeEditorLimitInfo:SetHeight(40)
    U.offerKind = selector(U.tradeMineFrame, 'Type', 0, -38, 195, { 'SELL', 'BUY', 'SERVICE' }, U.CaptureOfferDraft)
    U.offerFields = {}
    U.offerFields.name = edit(U.tradeMineFrame, 'Item or service', 210, -38, 420, 96)
    U.offerItemPicker = itemSuggestions(U.offerFields.name, U.tradeMineFrame, 420, U.CaptureOfferDraft, function(id)
        U.offerItemID = id
    end)
    U.offerFields.quantity = edit(U.tradeMineFrame, 'Quantity', 0, -96, 90, 6)
    U.offerFields.gold = edit(U.tradeMineFrame, 'Total price gold', 105, -96, 130, 7)
    U.offerFields.silver = edit(U.tradeMineFrame, 'Silver', 250, -96, 90, 2)
    U.offerFields.copper = edit(U.tradeMineFrame, 'Copper', 355, -96, 90, 2)
    U.offerDuration = edit(U.tradeMineFrame, 'Duration in minutes (max. 1440)', 460, -96, 170, 4)
    U.offerFields.note = edit(U.tradeMineFrame, 'Note (optional)', 0, -158, 630, 96, true)
    U.offerPreview = label(U.tradeMineFrame, Z.Kit and Z.Kit.Paint('warning', 'PREVIEW') or 'PREVIEW', 655, -38, 190, 'GameFontHighlight')
    U.offerPreview:SetHeight(210)
    U.offerSave = button(U.tradeMineFrame, 'Publish offer', 0, -263, 190, function()
        if not U.ValidateOfferForm() then
            return
        end
        if U.offerEditID then
            local exists = false
            for _, item in ipairs(Z.db.market) do
                if item.id == U.offerEditID then
                    exists = true
                end
            end
            if not exists then
                U.Message('This offer is no longer active. Discard the old draft.')
                return
            end
        end
        local raw = U.offerFields.name:GetText()
        local itemID, name = U.offerItemID, raw
        if not itemID then
            itemID, name = A.ResolveItem(raw)
        end
        if U.offerKind:GetText() == 'SERVICE' and L.Text(raw, 96) then
            itemID, name = 0, raw
        end
        local o = {
            id = U.offerEditID,
            kind = U.offerKind:GetText(),
            itemID = itemID or 0,
            name = name or '',
            quantity = tonumber(U.offerFields.quantity:GetText()),
            price = (tonumber(U.offerFields.gold:GetText()) or 0) * 10000
                + (tonumber(U.offerFields.silver:GetText()) or 0) * 100
                + (tonumber(U.offerFields.copper:GetText()) or 0),
            note = U.offerFields.note:GetText(),
            expires = A.Now() + (tonumber(U.offerDuration:GetText()) or 1440) * 60,
        }
        local id, err = L.SaveOffer(Z.db, o, A.Now())
        if id then
            if Z.Items and o.itemID > 0 then
                Z.Items.Observe(o.itemID, o.name)
            end
            Z.TradeManager.TrackPublication(
                id,
                U.offerEditID,
                (U.offerStoredState == 'draft' or U.offerStoredState == 'paused') and U.offerStoredID or nil
            )
            if U.offerStoredState then
                Z.TradeManager.ConsumeStored(U.offerStoredState, U.offerStoredID)
                U.offerStoredState, U.offerStoredID = nil, nil
            end
            if Z.UIState then
                Z.UIState.Draft('offer', false)
            end
            U.offerEditID = id
            U.tradeEditorTitle:SetText(tr('Edit offer'))
            U.offerSave:SetText(tr('Save changes'))
            U.Publish()
            U.Message('Offer saved.')
        else
            U.Message(err or 'Item not found.')
        end
    end, 'primary')
    U.offerDiscard = button(U.tradeMineFrame, 'Discard draft', 200, -263, 165, function()
        U.DiscardOfferDraft()
    end)
    U.offerSaveDraft = button(U.tradeMineFrame, 'Save as local draft', 375, -263, 255, function()
        if not U.ValidateOfferForm() then
            return
        end
        local raw = U.offerFields.name:GetText()
        local itemID, name = U.offerItemID, raw
        if not itemID then
            itemID, name = A.ResolveItem(raw)
        end
        if U.offerKind:GetText() == 'SERVICE' then
            itemID, name = 0, raw
        end
        local row = {
            kind = U.offerKind:GetText(),
            itemID = itemID or 0,
            name = name or '',
            quantity = tonumber(U.offerFields.quantity:GetText()),
            price = (tonumber(U.offerFields.gold:GetText()) or 0) * 10000
                + (tonumber(U.offerFields.silver:GetText()) or 0) * 100
                + (tonumber(U.offerFields.copper:GetText()) or 0),
            note = U.offerFields.note:GetText(),
            duration = tonumber(U.offerDuration:GetText()),
        }
        local id, err = Z.TradeManager.SaveDraft(row, U.offerStoredState == 'draft' and U.offerStoredID or nil)
        U.Message(id and 'Local draft saved.' or err)
        if id then
            U.offerEditID = nil
            U.offerStoredState, U.offerStoredID = 'draft', id
            U.tradeManageID = 'draft\0' .. id
            U.tradeEditorTitle:SetText(tr('Create offer'))
            U.offerSave:SetText(tr('Publish offer'))
            U.CaptureOfferDraft()
            refreshTradeManage()
        end
    end)
    for key, field in pairs(U.offerFields) do
        if key ~= 'name' then
            field:SetScript('OnTextChanged', U.CaptureOfferDraft)
        end
    end
    U.offerDuration:SetScript('OnTextChanged', U.CaptureOfferDraft)
    U.tradeMineFrame:Hide()
    U.tradeManageFrame = CreateFrame('Frame', nil, p)
    U.tradeManageFrame:SetPoint('TOPLEFT', 0, -40)
    U.tradeManageFrame:SetSize(856, 414)
    U.tradeManageCount = label(U.tradeManageFrame, tr('0 lokale Einträge'), 0, 0, 250, 'GameFontNormal')
    U.tradeFilterButtons = {}
    local filterKeys = { 'all', 'active', 'draft', 'paused', 'expired', 'completed', 'template' }
    for i, key in ipairs(filterKeys) do
        U.tradeFilterButtons[key] = button(U.tradeManageFrame, tr(({all='All',active='Active',draft='Draft',paused='Paused',expired='Expired',completed='Completed',template='Templates'})[key]), (i-1)*116, -28, 108, function() U.SetTradeOfferFilter(key) end)
    end
    U.tradeLimitInfo = label(U.tradeManageFrame, '', 0, -62, 840, 'GameFontHighlight')
    U.tradeLimitInfo:SetHeight(40)
    U.tradeManageList = list(U.tradeManageFrame, 0, -118, 470, 275)
    U.tradeManageDetail = label(U.tradeManageFrame, tr('Wähle einen Eintrag aus.'), 495, -106, 345, 'GameFontHighlight')
    U.tradeManageDetail:SetHeight(70)
    U.tradeManageOpen = button(U.tradeManageFrame, tr('Öffnen / erneut anbieten'), 495, -185, 210, function()
        local e = U.tradeManageSelected
        if not e then
            return
        end
        if e.state == 'active' then
            U.offerStoredState, U.offerStoredID = nil, nil
            U.EditOffer(e.row)
        else
            U.offerStoredState, U.offerStoredID = e.state, e.id
            if Z.UIState then
                Z.UIState.Draft('offer', storedOfferDraft(e.row, e.state, e.id))
            end
            U.EditOffer(nil)
            U.offerEditID = nil
            U.tradeEditorTitle:SetText(tr('Create offer'))
            U.offerSave:SetText(tr('Publish offer'))
        end
        U.SetTradeView('mine')
    end)
    local function clearInactiveOfferEditor(id)
        if U.offerEditID ~= id then return end
        U.offerEditID = nil
        U.tradeEditorTitle:SetText(tr('Create offer'))
        U.offerSave:SetText(tr('Publish offer'))
        U.CaptureOfferDraft()
    end
    U.tradeManagePause = button(U.tradeManageFrame, tr('Pausieren'), 495, -220, 125, function()
        local e = U.tradeManageSelected
        if e then
            local ok, err = Z.TradeManager.Pause(e.id)
            if ok then clearInactiveOfferEditor(e.id) end
            U.Message(ok and 'Angebot pausiert.' or err)
            U.tradeManageID = nil
            refreshTradeManage()
        end
    end)
    U.tradeManageDone = button(U.tradeManageFrame, tr('Erledigt'), 630, -220, 125, function()
        local e = U.tradeManageSelected
        if e and Z.TradeManager.Complete(e.id) then
            clearInactiveOfferEditor(e.id)
            U.tradeManageID = nil
            refreshTradeManage()
        end
    end, 'danger')
    U.tradeManageDuplicate = button(U.tradeManageFrame, tr('Duplizieren'), 495, -255, 125, function()
        local e = U.tradeManageSelected
        if e then
            local ok, err = Z.TradeManager.Duplicate(e.id)
            U.Message(ok and 'Entwurf angelegt.' or err)
            refreshTradeManage()
        end
    end)
    U.tradeManageDelete = button(U.tradeManageFrame, 'Delete draft', 495, -255, 345, function()
        local e = U.tradeManageSelected
        if not e or e.state == 'active' then
            return
        end
        local bucket = e.state == 'paused' and Z.TradeManager.store.paused
            or e.state == 'draft' and Z.TradeManager.store.drafts
            or (e.state == 'completed' or e.state == 'expired') and Z.TradeManager.store.closed
            or Z.TradeManager.store.templates
        bucket[e.id] = nil
        if U.offerStoredState == e.state and U.offerStoredID == e.id then
            U.offerStoredState, U.offerStoredID = nil, nil
            U.CaptureOfferDraft()
        end
        U.tradeManageID = nil
        refreshTradeManage()
    end, 'danger')
    U.tradeManageTemplate = button(U.tradeManageFrame, tr('Als Vorlage speichern'), 495, -290, 210, function()
        local e = U.tradeManageSelected
        if e then
            local ok, err = Z.TradeManager.SaveTemplate(e.row.name, e.row)
            U.Message(ok and tr('Angebotsvorlage gespeichert.') or err)
            refreshTradeManage()
        end
    end)
    U.tradeManageFrame:Hide()
    U.tradeRulesFrame = CreateFrame('Frame', nil, p)
    U.tradeRulesFrame:SetPoint('TOPLEFT', 0, -40)
    U.tradeRulesFrame:SetSize(856, 414)
    U.tradeAlertTitle = label(U.tradeRulesFrame, tr('Alert matches'), 495, -244, 345, 'GameFontNormal')
    U.tradeAlertList = list(U.tradeRulesFrame, 495, -264, 345, 135)
    U.tradeRuleCount = label(U.tradeRulesFrame, tr('0 gespeicherte Suchen'), 0, 0, 280, 'GameFontNormal')
    U.tradeRuleList = list(U.tradeRulesFrame, 0, -28, 470, 328)
    U.tradeRuleDetail = label(U.tradeRulesFrame, tr('Wähle eine gespeicherte Suche aus.'), 495, -28, 345, 'GameFontHighlight')
    U.tradeRuleDetail:SetHeight(120)
    U.tradeRuleLimitInfo = label(U.tradeRulesFrame, '', 0, -362, 470, 'GameFontHighlight')
    U.tradeRuleLimitInfo:SetHeight(48)
    U.tradeAlertStatus = label(U.tradeRulesFrame, '', 495, -160, 345, 'GameFontHighlight')
    U.tradeAlertStatus:SetHeight(34)
    U.tradeRuleApply = button(U.tradeRulesFrame, 'Filter anwenden', 495, -200, 150, function()
        local r = Z.TradeManager.store.rules[U.tradeRuleID]
        if not r then
            return
        end
        U.offerSearchItemID = r.itemID and r.itemID > 0 and r.itemID or nil
        U.offerSearch:SetText(r.query or '')
        U.tradeKindFilter:SetText(r.kind)
        U.tradeCategoryFilter:SetText(r.category)
        U.tradeMinPrice:SetText(r.minPrice and tostring(r.minPrice / 10000) or '')
        U.tradeMaxPrice:SetText(r.maxPrice and tostring(r.maxPrice / 10000) or '')
        U.SetTradeView('browse')
    end)
    U.tradeRuleDelete = button(U.tradeRulesFrame, tr('Suchalarm löschen'), 655, -200, 165, function()
        if U.tradeRuleID then
            Z.TradeManager.DeleteRule(U.tradeRuleID)
            U.tradeRuleID = nil
            refreshTradeRules()
        end
    end, 'danger')
    U.tradeRulesFrame:Hide()
    U.tradeView = 'browse'
    -- Information lines recede behind the content they describe.
    if T then
        for _, info in ipairs({ U.tradeFilterSummary, U.tradeLimitInfo, U.tradeEditorLimitInfo, U.tradeRuleLimitInfo }) do
            T.Tint(info, 'SetTextColor', 'textSoft')
        end
    end
    U.LayoutTradeVisual()
end

-- Plates behind the browse filters and the editor preview, plus the one gold primary of the
-- current view. Called after creation, on every trade refresh (U.RefreshTradeAdvanced) and from the responsive layout.
function U.LayoutTradeVisual()
    local browse, mine = U.tradeBrowseFrame, U.tradeMineFrame
    if not browse or not mine then
        return
    end
    local function factor(frame)
        local width = frame:GetWidth()
        return (type(width) == 'number' and width > 0 and width or 856) / 856
    end
    local compact = U.compactArea == 'trade'
    local horizontal = factor(browse)
    local open = U.tradeAdvancedOpen == true
    if not compact then
        -- The advanced filters are placed by FormLayoutUI at x = 0; here they get the plate's inner padding.
        for _, spec in ipairs({ { 'tradeCategoryFilter', 8 }, { 'tradeMinPrice', 208 }, { 'tradeMaxPrice', 338 }, { 'tradeSort', 468 } }) do
            local control = U[spec[1]]
            if control then
                control.caption:ClearAllPoints()
                control.caption:SetPoint('TOPLEFT', spec[2] * horizontal, -48)
                local target = control.button or control
                target:ClearAllPoints()
                target:SetPoint('TOPLEFT', spec[2] * horizontal, -80)
            end
        end
    end
    if U.tradeFilterBar then
        U.tradeFilterBar:Place(0, -4, 850 * horizontal, open and 112 or 70)
        U.tradeFilterBar:SetShown(not compact)
    end
    if U.offerPreviewCard then
        local previewScale = factor(mine)
        U.offerPreviewCard:Place(647 * previewScale, 32, 206 * previewScale, 222)
    end
    -- One primary action per view: the editor's Publish button, otherwise Create offer.
    if T and T.StyleButton and U.tradeMineTab then
        T.StyleButton(U.tradeMineTab, U.tradeView == 'mine' and 'secondary' or 'primary')
    end
end
