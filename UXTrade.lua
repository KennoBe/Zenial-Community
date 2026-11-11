local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local NAV_ICONS, displayValue, rows, itemIcon, keys = S.NAV_ICONS, S.displayValue, S.rows, S.itemIcon, S.keys
local peerOnline, faction = S.peerOnline, S.faction

local function offers()
    local all = {}
    local now = A.Now()
    for _, o in ipairs(Z.db.market) do
        if o.expires > now then
            all[#all + 1] = { key = Z.me.key, target = Z.me.target, o = o }
        end
    end
    for key, p in pairs(Z.db.peers) do
        if peerOnline(key) and p.data and Z.db.contacts[key] then
            for _, o in ipairs(p.data.market or {}) do
                if o.expires > now then
                    all[#all + 1] = { key = key, target = Z.db.contacts[key].target, o = o }
                end
            end
        end
    end
    return all
end
local function unitPrice(o)
    return o.quantity > 0 and o.price / o.quantity or o.price
end
local function goldFilter(value)
    value = (value or ''):match('^%s*(.-)%s*$') or ''
    if value == '' then
        return nil, true
    end
    if not value:match('^%d+[.,]?%d*$') then
        return nil, false
    end
    local fraction = value:match('[.,](%d+)$')
    if fraction and #fraction > 4 then
        return nil, false
    end
    local normalized = value:gsub(',', '.')
    local number = tonumber(normalized)
    if not number or number < 0 or number > 214748 then
        return nil, false
    end
    return math.floor(number * 10000 + 0.5), true
end
S.goldFilter = goldFilter
local function offerCategory(o)
    return Z.Items and Z.Items.Category(o.itemID, o.kind) or (o.kind == 'SERVICE' and 'SERVICE' or 'UNCLASSIFIED')
end
function U.CaptureOfferDraft()
    if S.restoringDraft or not U.offerFields then
        return
    end
    local draft = {
        editID = U.offerEditID or '',
        storedState = U.offerStoredState or '',
        storedID = U.offerStoredID or '',
        kind = U.offerKind:GetText(),
        duration = U.offerDuration:GetText(),
        itemID = U.offerItemID or 0,
    }
    for key, field in pairs(U.offerFields) do
        draft[key] = field:GetText()
    end
    if Z.UIState then
        Z.UIState.Draft('offer', draft)
    end
    if U.offerPreview then
        local quantity = tonumber(draft.quantity) or 1
        local price = (tonumber(draft.gold) or 0) * 10000 + (tonumber(draft.silver) or 0) * 100 + (tonumber(draft.copper) or 0)
        U.offerPreview:SetText(
            '|cffffd36b'
                .. tr('PREVIEW')
                .. '|r\n'
                .. displayValue(draft.kind or '')
                .. ': '
                .. ((draft.name or '') ~= '' and draft.name or tr('Item or service'))
                .. '\n'
                .. tr('Quantity')
                .. ': '
                .. (draft.quantity or '')
                .. '\n'
                .. tr('Unit price')
                .. ': '
                .. A.MoneyText(math.floor(price / math.max(1, quantity) + 0.5))
                .. '\n'
                .. tr('Total price')
                .. ': '
                .. A.MoneyText(price)
                .. ((draft.note or '') ~= '' and '\n\n' .. draft.note or '')
        )
    end
end
function U.ValidateOfferForm()
    if not L.Text(U.offerFields.name:GetText(), 96) then
        U.offerFields.name:SetFocus()
        U.Message(tr('Bitte einen Gegenstand oder eine Dienstleistung angeben.'))
        return false
    end
    local quantity, duration = tonumber(U.offerFields.quantity:GetText()), tonumber(U.offerDuration:GetText())
    if not L.Int(quantity, 1, 100000) then
        U.offerFields.quantity:SetFocus()
        U.Message(tr('Die Menge ist ungültig.'))
        return false
    end
    if not L.Int(duration, 1, 1440) then
        U.offerDuration:SetFocus()
        U.Message(tr('Die Laufzeit muss zwischen 1 und 1440 Minuten liegen.'))
        return false
    end
    for _, key in ipairs({ 'gold', 'silver', 'copper' }) do
        local value = tonumber(U.offerFields[key]:GetText())
        local max = key == 'gold' and 214748 or 99
        if not L.Int(value, 0, max) then
            U.offerFields[key]:SetFocus()
            U.Message(tr('Der Preis ist ungültig.'))
            return false
        end
    end
    return true
end
function U.DiscardOfferDraft()
    if Z.UIState then
        Z.UIState.Draft('offer', false)
    end
    U.offerStoredState, U.offerStoredID = nil, nil
    U.EditOffer(nil)
end
function U.EditOffer(o)
    local draft = not o and Z.UIState and Z.UIState.Draft('offer')
    S.restoringDraft = true
    U.offerStoredState, U.offerStoredID = nil, nil
    if draft and draft.storedID and draft.storedID ~= '' then
        local state = draft.storedState
        local store = Z.TradeManager.store
        local bucket = state == 'draft' and store.drafts
            or state == 'paused' and store.paused
            or state == 'template' and store.templates
            or (state == 'completed' or state == 'expired') and store.closed
        if bucket and bucket[draft.storedID] then
            U.offerStoredState, U.offerStoredID = state, draft.storedID
        end
    end
    U.offerEditID = o and o.id or draft and draft.editID and draft.editID ~= '' and draft.editID or nil
    if U.tradeEditorTitle then
        U.tradeEditorTitle:SetText(tr(U.offerEditID and 'Edit offer' or 'Create offer'))
    end
    U.offerSave:SetText(tr(U.offerEditID and 'Save changes' or 'Publish offer'))
    U.offerKind:SetText(o and o.kind or draft and draft.kind or 'SELL')
    local price = o and o.price or 0
    local itemID = o and o.itemID or draft and tonumber(draft.itemID) or 0
    local name = o and o.name or draft and draft.name or ''
    U.offerItemID = itemID > 0 and itemID or nil
    if U.offerItemPicker then
        U.offerItemPicker:Set(U.offerItemID, name)
    else
        U.offerFields.name:SetText(name)
    end
    U.offerFields.quantity:SetText(tostring(o and o.quantity or draft and draft.quantity or 1))
    U.offerFields.gold:SetText(tostring(o and math.floor(price / 10000) or draft and draft.gold or 0))
    U.offerFields.silver:SetText(tostring(o and math.floor(price % 10000 / 100) or draft and draft.silver or 0))
    U.offerFields.copper:SetText(tostring(o and price % 100 or draft and draft.copper or 0))
    U.offerFields.note:SetText(o and o.note or draft and draft.note or '')
    U.offerDuration:SetText(tostring(draft and draft.duration or '1440'))
    S.restoringDraft = false
    U.CaptureOfferDraft()
end
function U.CaptureProfileDraft()
    if S.restoringDraft or not U.profileFields then
        return
    end
    local draft = { community = U.profileFields.community:GetText(), note = U.profileFields.note:GetText(), role = U.profileRole:GetText() }
    if Z.UIState then
        Z.UIState.Draft('profile', draft)
    end
    if U.profilePreview then
        U.profilePreview:SetText(
            '|cffffd36b'
                .. tr('PREVIEW')
                .. '|r\n'
                .. Z.me.target
                .. ' · '
                .. L.ClassName(Z.me.class)
                .. ' · '
                .. tr('Level')
                .. ' '
                .. Z.me.level
                .. '\n'
                .. tr('Role')
                .. ': '
                .. displayValue(draft.role)
                .. ((draft.community or '') ~= '' and '\n' .. tr('Display name') .. ': ' .. draft.community or '')
                .. ((draft.note or '') ~= '' and '\n\n' .. draft.note or '')
        )
    end
end
local function showOffer(key, target, offer)
    local kind = tr(({ BUY = 'Wanted', SELL = 'For sale', SERVICE = 'Service' })[offer.kind])
    U.offerDetail:SetText(
        '|cffffd36b'
            .. kind
            .. ': '
            .. offer.name
            .. '|r\n'
            .. target
            .. ' · '
            .. displayValue(offerCategory(offer))
            .. '\n'
            .. tr('Quantity')
            .. ': '
            .. offer.quantity
            .. '\n'
            .. tr('Unit price')
            .. ': '
            .. A.MoneyText(math.floor(unitPrice(offer) + 0.5))
            .. '\n'
            .. tr('Total price')
            .. ': '
            .. A.MoneyText(offer.price)
            .. ((offer.note or '') ~= '' and '\n\n' .. offer.note or '')
    )
    U.offerWhisper:SetEnabled(key ~= Z.me.key)
    if U.offerManageOwn then
        U.offerManageOwn:SetShown(key == Z.me.key)
        U.offerManageOwn:SetEnabled(key == Z.me.key)
    end
end
local function refreshOffers()
    if not U.offerSearch then
        return
    end
    local q = string.lower(U.offerSearch:GetText() or '')
    local kindFilter = U.tradeKindFilter and U.tradeKindFilter:GetText() or 'ALL'
    local categoryFilter = U.tradeCategoryFilter and U.tradeCategoryFilter:GetText() or 'ALL_ITEM_CATEGORIES'
    local sort = U.tradeSort and U.tradeSort:GetText() or 'TRADE_NAME'
    local minPrice, minOK = goldFilter(U.tradeMinPrice and U.tradeMinPrice:GetText())
    local maxPrice, maxOK = goldFilter(U.tradeMaxPrice and U.tradeMaxPrice:GetText())
    local priceOK = minOK and maxOK and (not minPrice or not maxPrice or minPrice <= maxPrice)
    local filtered = {}
    if priceOK then
        for _, x in ipairs(offers()) do
            local o = x.o
            local price = unitPrice(o)
            local category = offerCategory(o)
            local exact = U.offerSearchItemID and o.itemID == U.offerSearchItemID
            local hay = string.lower(o.name .. ' ' .. x.target .. ' ' .. (o.note or ''))
            local textMatch = U.offerSearchItemID and exact or q == '' or hay:find(q, 1, true)
            if
                textMatch
                and (kindFilter == 'ALL' or o.kind == kindFilter)
                and (categoryFilter == 'ALL_ITEM_CATEGORIES' or category == categoryFilter)
                and (not minPrice or price >= minPrice)
                and (not maxPrice or price <= maxPrice)
            then
                x.unitPrice, x.category = price, category
                filtered[#filtered + 1] = x
            end
        end
    end
    table.sort(filtered, function(a, b)
        local ao, bo = a.o, b.o
        if sort == 'UNIT_ASC' and a.unitPrice ~= b.unitPrice then
            return a.unitPrice < b.unitPrice
        end
        if sort == 'UNIT_DESC' and a.unitPrice ~= b.unitPrice then
            return a.unitPrice > b.unitPrice
        end
        if sort == 'ENDING_SOON' and ao.expires ~= bo.expires then
            return ao.expires < bo.expires
        end
        if sort == 'TRADE_NAME' then
            local an, bn = string.lower(ao.name), string.lower(bo.name)
            if an ~= bn then
                return an < bn
            end
        end
        if a.target ~= b.target then
            return a.target < b.target
        end
        return ao.id < bo.id
    end)
    if U.tradeFilterSummary then
        local parts = {}
        if kindFilter ~= 'ALL' then parts[#parts + 1] = displayValue(kindFilter) end
        if categoryFilter ~= 'ALL_ITEM_CATEGORIES' then parts[#parts + 1] = displayValue(categoryFilter) end
        if minPrice then parts[#parts + 1] = tr('From') .. ' ' .. A.MoneyText(minPrice) end
        if maxPrice then parts[#parts + 1] = tr('To') .. ' ' .. A.MoneyText(maxPrice) end
        if sort ~= 'TRADE_NAME' then parts[#parts + 1] = displayValue(sort) end
        U.tradeFilterSummary:SetText(#parts > 0 and table.concat(parts, ' · ') or tr('No additional filters'))
    end
    if U.tradeAdvancedToggle then
        local count = 0
        if categoryFilter ~= 'ALL_ITEM_CATEGORIES' then count = count + 1 end
        if minPrice then count = count + 1 end
        if maxPrice then count = count + 1 end
        if sort ~= 'TRADE_NAME' then count = count + 1 end
        U.tradeAdvancedToggle:SetText(tr('Advanced') .. (count > 0 and (' (' .. count .. ')') or ''))
    end
    local items = {}
    local valid = false
    for _, x in ipairs(filtered) do
        local o = x.o
        local kind = tr(({ BUY = 'Wanted', SELL = 'For sale', SERVICE = 'Service' })[o.kind])
        local key, id, target, offer = x.key, o.id, x.target, o
        if key == U.offerKey and id == U.offerID then
            valid = true
            showOffer(key, target, offer)
        end
        local value = kind
            .. ': '
            .. o.name
            .. ' · '
            .. tr('Quantity')
            .. ' '
            .. o.quantity
            .. ' · '
            .. tr('Unit price')
            .. ' '
            .. A.MoneyText(math.floor(x.unitPrice + 0.5))
            .. '\n'
            .. target
            .. ' · '
            .. displayValue(x.category)
            .. ' · '
            .. tr('Total price')
            .. ' '
            .. A.MoneyText(o.price)
        items[#items + 1] = {
            selected = key == U.offerKey and id == U.offerID,
            icon = itemIcon(o.itemID) or NAV_ICONS.trade,
            text = value,
            click = function()
                if key ~= Z.me.key and not peerOnline(key) then
                    U.offerKey, U.offerID = nil, nil
                    refreshOffers()
                    return
                end
                U.offerKey, U.offerID = key, id
                showOffer(key, target, offer)
                refreshOffers()
                U.OpenCompactArea('trade')
            end,
        }
    end
    if not valid then
        U.offerKey, U.offerID = nil, nil
    end
    rows(U.offerList, items, 72)
    if U.offerCount then
        U.offerCount:SetText(priceOK and (#items .. ' ' .. tr(#items == 1 and 'offer' or 'offers')) or tr('Invalid price filter'))
    end
    if not U.offerKey then
        U.offerDetail:SetText(tr(#items == 0 and (q == '' and 'No active offers.' or 'No offers match the filter.') or 'Select an offer.'))
        U.offerWhisper:SetEnabled(false)
        if U.offerManageOwn then U.offerManageOwn:Hide() end
    end
    if U.RefreshTradeContext then U.RefreshTradeContext() end
end
S.refreshOffers = refreshOffers
function U.RefreshTradeAdvanced()
    if U.compactArea == 'trade' then
        U.tradeCategoryFilter.button:Hide(); U.tradeCategoryFilter.caption:Hide()
        U.tradeMinPrice:Hide(); U.tradeMinPrice.caption:Hide()
        U.tradeMaxPrice:Hide(); U.tradeMaxPrice.caption:Hide()
        U.tradeSort.button:Hide(); U.tradeSort.caption:Hide()
        U.tradeFilterSummary:Hide()
        U.tradeAdvancedToggle:Hide()
        U.tradeSaveSearch:Hide()
        refreshOffers()
        return
    end
    U.tradeAdvancedToggle:Show()
    U.tradeSaveSearch:Show()
    if not U.tradeAdvancedOpen then
        U.tradeCategoryFilter.button:Hide(); U.tradeCategoryFilter.caption:Hide()
        U.tradeMinPrice:Hide(); U.tradeMinPrice.caption:Hide()
        U.tradeMaxPrice:Hide(); U.tradeMaxPrice.caption:Hide()
        U.tradeSort.button:Hide(); U.tradeSort.caption:Hide()
        U.tradeFilterSummary:Show()
    else
        U.tradeCategoryFilter.button:Show(); U.tradeCategoryFilter.caption:Show()
        U.tradeMinPrice:Show(); U.tradeMinPrice.caption:Show()
        U.tradeMaxPrice:Show(); U.tradeMaxPrice.caption:Show()
        U.tradeSort.button:Show(); U.tradeSort.caption:Show()
        U.tradeFilterSummary:Hide()
    end
    refreshOffers()
end
function U.RefreshTradeContext()
    if not U.tradeContextText then return end
    local token, planID = U.Navigation.ActiveContext('craft')
    local plan = token and Z.MaterialPlanner.Get(planID)
    local item = plan and (Z.Items and Z.Items.Get(U.materialItemID) and Z.Items.Get(U.materialItemID).name or tostring(U.materialItemID))
    U.tradeContextText:SetText(token and tr('Returning to crafting') .. (item and (': ' .. item) or '') or '')
    U.tradeContextText:SetShown(token ~= nil)
    U.tradeContextBack:SetShown(token ~= nil)
end
function U.OpenTradeAlert(entry)
    if type(entry) ~= 'table' then return false, 'missing' end
    local contact = Z.db.contacts[entry.peer]
    if entry.code == 'TRADE_CLOSED' then
        U.tradeAlertStatus:SetText(tr('This offer is closed or withdrawn.'))
        return false, 'closed'
    end
    if not contact or not peerOnline(entry.peer) then
        U.tradeAlertStatus:SetText(Z.T('%s is offline; no current snapshot.', contact and contact.target or entry.peer))
        return false, 'offline'
    end
    local snapshot = Z.db.peers[entry.peer]
    local found
    for _, offer in ipairs(snapshot and snapshot.data and snapshot.data.market or {}) do
        if offer.id == entry.id then found = offer; break end
    end
    if not found then
        U.tradeAlertStatus:SetText(Z.T('Offer is no longer in the latest snapshot of %s.', contact.target))
        return false, 'missing'
    end
    if found.expires <= A.Now() then
        U.tradeAlertStatus:SetText(tr('This offer has expired.'))
        return false, 'expired'
    end
    U.tradeAlertStatus:SetText('')
    U.offerSearch:SetText(found.itemID > 0 and tostring(found.itemID) or found.name)
    U.offerSearchItemID = found.itemID > 0 and found.itemID or nil
    U.tradeKindFilter:SetText('ALL'); U.tradeCategoryFilter:SetText('ALL_ITEM_CATEGORIES')
    U.tradeMinPrice:SetText(''); U.tradeMaxPrice:SetText('')
    U.tradeAdvancedOpen = false
    U.offerKey, U.offerID = entry.peer, entry.id
    if not U.Navigate('trade', 'browse') then return false, 'navigation' end
    U.RefreshTradeAdvanced(); U.OpenCompactArea('trade')
    return true
end
function U.OpenMaterialOffer(key, id, itemID)
    local P = Z.MaterialPlanner
    local plan = P.Get(U.materialPlanID)
    if not plan or not P.Active(plan) or U.materialItemID ~= itemID or not P.GetOffer(key, id, itemID) then
        U.Message(tr('This offer is no longer available.'))
        U.RefreshMaterialPlans()
        return
    end
    -- Only navigate to the existing offer details. Its separate whisper button
    -- opens a chat draft; no purchase, message or saved trade rule is created.
    -- Leaving the craft request for the offer keeps its draft in the return context.
    local N, ctx, token = U.Navigation, U.craftOrderContext, nil
    if ctx and ctx.planID == plan.id and not plan.order then
        token = N.BeginContext('craft', {
            peerKey = ctx.peer,
            recipeRef = ctx.recipe,
            quantityText = U.craftOrderQuantity:GetText(),
            craftsText = U.craftMaterialCount:GetText(),
            tipGoldText = U.craftOrderTip:GetText(),
            noteText = U.craftOrderNote:GetText(),
            materialsProvided = U.craftOrderMaterials:GetChecked() == true,
            planID = plan.id,
            materialPlanID = U.materialPlanID,
            materialItemID = U.materialItemID,
            materialFindID = U.materialFindID,
        }, (N.Resolve('craft', 'materials')))
        if not token then
            U.Message(tr('The note is too long to keep in the return context. Shorten the note before opening this offer.'))
            return
        end
    end
    if not U.Navigate('trade', 'browse') then
        N.DiscardContext(token)
        return
    end
    U.offerSearch:SetText(tostring(itemID))
    U.offerSearchItemID = itemID
    U.tradeKindFilter:SetText('SELL')
    U.tradeCategoryFilter:SetText('ALL_ITEM_CATEGORIES')
    U.tradeMinPrice:SetText('')
    U.tradeMaxPrice:SetText('')
    U.offerKey, U.offerID = key, id
    refreshOffers()
    U.OpenCompactArea('trade')
end
local function refreshTradeRules()
    if not U.tradeRuleList then
        return
    end
    local items = {}
    local selected
    local notices = {}
    for i, entry in ipairs(Z.Notifications.List('trade', U.tradeRuleID)) do
        if i > 30 then
            break
        end
        local row = entry
        notices[#notices + 1] = {
            text = (row.unread and '|cffff5555!|r ' or '') .. Z.Notifications.Describe(row) .. '\n' .. date('%d.%m. %H:%M', row.at),
            click = function()
                Z.Notifications.Read(row.token)
                U.OpenTradeAlert(row)
                refreshTradeRules()
            end,
        }
    end
    if U.tradeAlertList then
        U.SetEmptyHint(U.tradeAlertList, 'No updates yet. A saved search alerts you here when a matching offer appears.')
        rows(U.tradeAlertList, notices, 54)
    end
    for id, rule in pairs(Z.TradeManager.store.rules) do
        local token = id
        if token == U.tradeRuleID then
            selected = rule
        end
        items[#items + 1] = {
            selected = token == U.tradeRuleID,
            icon = NAV_ICONS.trade,
            text = '|cffffd36b'
                .. (rule.name ~= '' and rule.name or tr('Gespeicherte Suche'))
                .. '|r\n'
                .. (rule.query ~= '' and rule.query or tr('Alle Angebote'))
                .. ' · '
                .. displayValue(rule.kind)
                .. ' · '
                .. displayValue(rule.category),
            click = function()
                U.tradeRuleID = token
                U.tradeAlertStatus:SetText('')
                refreshTradeRules()
            end,
        }
    end
    table.sort(items, function(a, b)
        return a.text < b.text
    end)
    U.SetEmptyHint(U.tradeRuleList, 'No saved searches. Filter offers under Find Offers and press Save search.')
    rows(U.tradeRuleList, items, 58)
    U.tradeRuleCount:SetText(#items .. tr(' gespeicherte Suchen'))
    if U.tradeRuleLimitInfo then
        local count = #items
        U.tradeRuleLimitInfo:SetText(count .. tr(' of 20 search alerts') .. (count >= 20 and tr('. Delete an alert before saving another.') or ''))
    end
    U.tradeRuleDelete:SetEnabled(selected ~= nil)
    U.tradeRuleApply:SetEnabled(selected ~= nil)
    U.tradeRuleDetail:SetText(
        selected
                and ('|cffffd36b' .. selected.name .. tr(
                    '|r\nNeue passende Angebote, Änderungen und Schließungen erzeugen einen lokalen Hinweis. Bestehende Treffer nach Login bleiben still.'
                ))
            or tr('Wähle eine gespeicherte Suche aus.')
    )
end
S.refreshTradeRules = refreshTradeRules
local function storedOfferDraft(row, state, id)
    local price = row.price or 0
    return {
        storedState = state or '',
        storedID = id or '',
        kind = row.kind or 'SELL',
        itemID = row.itemID or 0,
        name = row.name or '',
        quantity = tostring(row.quantity or 1),
        gold = tostring(math.floor(price / 10000)),
        silver = tostring(math.floor(price % 10000 / 100)),
        copper = tostring(price % 100),
        duration = tostring(row.duration or 1440),
        note = row.note or '',
    }
end
S.storedOfferDraft = storedOfferDraft
local TRADE_STATES =
    { active = 'Active', paused = 'Paused', draft = 'Draft', completed = 'Completed', expired = 'Expired', template = 'Template' }
local TRADE_OPEN = {
    active = 'Edit offer',
    draft = 'Open draft',
    paused = 'Relist offer',
    completed = 'Relist offer',
    expired = 'Relist offer',
    template = 'Use template',
}
local TRADE_DELETE = {
    draft = 'Delete draft',
    paused = 'Delete paused offer',
    completed = 'Delete archived entry',
    expired = 'Delete archived entry',
    template = 'Delete template',
}
local tradeFilterChangeInProgress = false
local function refreshTradeManage()
    if not U.tradeManageList then
        return
    end
    local entries = {}
    for _, o in ipairs(Z.db.market) do
        entries[#entries + 1] = { state = 'active', id = o.id, row = o }
    end
    for id, o in pairs(Z.TradeManager.store.paused) do
        entries[#entries + 1] = { state = 'paused', id = id, row = o }
    end
    for id, o in pairs(Z.TradeManager.store.drafts) do
        entries[#entries + 1] = { state = 'draft', id = id, row = o }
    end
    for id, o in pairs(Z.TradeManager.store.closed) do
        entries[#entries + 1] = { state = o.state, id = id, row = o }
    end
    for id, o in pairs(Z.TradeManager.store.templates) do
        entries[#entries + 1] = { state = 'template', id = id, row = o }
    end
    table.sort(entries, function(a, b)
        return (a.row.name or '') < (b.row.name or '')
    end)
    local counts = { all = #entries, active = 0, draft = 0, paused = 0, expired = 0, completed = 0, template = 0 }
    for _, entry in ipairs(entries) do counts[entry.state] = (counts[entry.state] or 0) + 1 end
    if not U.tradeOfferFilter then U.tradeOfferFilter = 'all' end
    local matching = false
    for _, entry in ipairs(entries) do
        if U.tradeManageID == entry.state .. '\0' .. entry.id and U.tradeOfferFilter ~= 'all' and U.tradeOfferFilter ~= entry.state then matching = true end
    end
    if matching and not tradeFilterChangeInProgress then U.tradeOfferFilter = 'all' end
    for key, control in pairs(U.tradeFilterButtons or {}) do
        control:SetText(tr(({all='All',active='Active',draft='Draft',paused='Paused',expired='Expired',completed='Completed offers',template='Templates'})[key]) .. ' (' .. (counts[key] or 0) .. ')')
        control:SetEnabled(key ~= U.tradeOfferFilter)
    end
    if U.tradeLimitInfo then
        local n = counts.active
        U.tradeLimitInfo:SetText(Z.T('Active offers: %d of 3.', n) .. (n >= 3 and tr(' Only three entries can be active; pause, complete, or save one as a draft.') or ''))
    end
    if U.tradeEditorLimitInfo then
        local n = counts.active
        U.tradeEditorLimitInfo:SetText(Z.T('Active offers: %d of 3.', n) .. (n >= 3 and tr(' Only three entries can be active; pause, complete, or save one as a draft.') or ''))
    end
    local items = {}
    local selected
    for _, entry in ipairs(entries) do
        local token = entry.state .. '\0' .. entry.id
        if token == U.tradeManageID then
            selected = entry
        end
        if U.tradeOfferFilter == 'all' or U.tradeOfferFilter == entry.state then items[#items + 1] = {
            selected = token == U.tradeManageID,
            icon = itemIcon(entry.row.itemID) or NAV_ICONS.trade,
            text = '|cffffd36b' .. entry.row.name .. '|r · ' .. tr(TRADE_STATES[entry.state] or entry.state) .. '\n' .. displayValue(
                entry.row.kind
            ) .. ' · ' .. A.MoneyText(entry.row.price or 0),
            click = function()
                U.tradeManageID = token
                refreshTradeManage()
            end,
        } end
    end
    local empty = U.tradeOfferFilter == 'all' and 'Nothing stored locally. Drafts, templates and finished offers appear after you create an offer.' or ({active='No active offers.',draft='No drafts.',paused='No paused offers.',expired='No expired offers.',completed='No completed offers.',template='No templates.'})[U.tradeOfferFilter]
    U.SetEmptyHint(U.tradeManageList, empty)
    rows(U.tradeManageList, items, 58)
    U.tradeManageCount:SetText(#items .. tr(' lokale Einträge'))
    U.tradeManageSelected = selected
    local active = selected and selected.state == 'active' or false
    U.tradeManageOpen:SetEnabled(selected ~= nil)
    U.tradeManageOpen:SetText(tr(selected and TRADE_OPEN[selected.state] or 'Open draft'))
    for _, control in ipairs({ U.tradeManagePause, U.tradeManageDone, U.tradeManageDuplicate }) do
        control:SetEnabled(active)
        control:SetShown(active)
    end
    U.tradeManageDelete:SetEnabled(selected ~= nil and not active)
    U.tradeManageDelete:SetShown(selected ~= nil and not active)
    U.tradeManageDelete:SetText(tr(selected and TRADE_DELETE[selected.state] or 'Delete draft'))
    if U.tradeManageTemplate then
        U.tradeManageTemplate:SetEnabled(selected ~= nil)
        U.tradeManageTemplate:SetShown(selected ~= nil)
        U.tradeManageTemplate:ClearAllPoints()
        U.tradeManageTemplate:SetPoint('TOPLEFT', 495, active and -270 or -200)
    end
    U.tradeManageDetail:SetText(
        selected
                and ('|cffffd36b' .. selected.row.name .. '|r\n' .. tr('Status') .. ': ' .. tr(
                    TRADE_STATES[selected.state] or selected.state
                ) .. ' · ' .. tr('Quantity') .. ' ' .. (selected.row.quantity or 1) .. ' · ' .. A.MoneyText(
                    selected.row.price or 0
                ))
            or tr('Wähle einen Eintrag aus.')
    )
end
S.refreshTradeManage = refreshTradeManage
function U.SetTradeOfferFilter(key)
    local valid = { all=true, active=true, draft=true, paused=true, expired=true, completed=true, template=true }
    U.tradeOfferFilter = valid[key] and key or 'all'
    local selected = U.tradeManageSelected
    if selected and U.tradeOfferFilter ~= 'all' and U.tradeOfferFilter ~= selected.state then
        U.tradeManageID = nil
    end
    tradeFilterChangeInProgress = true
    refreshTradeManage()
    tradeFilterChangeInProgress = false
end
-- "My characters" lives in AccountOverviewUI.lua; kept as the shared refresh hook.
local function refreshCharacters()
    if U.RefreshMyCharacters then
        U.RefreshMyCharacters()
    end
end
S.refreshCharacters = refreshCharacters
