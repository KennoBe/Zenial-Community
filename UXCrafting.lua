local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local ORDER_TERMINAL, NAV_ICONS, rows, itemIcon, peerOnline = S.ORDER_TERMINAL, S.NAV_ICONS, S.rows, S.itemIcon, S.peerOnline

local function recipeScanCoverage()
    local total, scanned = 0, 0
    local scans = Z.db.recipeScans or {}
    for _, p in ipairs(Z.db.professions or {}) do
        total = total + 1
        if scans[L.ProfessionName(p.name)] then
            scanned = scanned + 1
        end
    end
    return scanned, total
end
local function craftStatusText()
    local scanned, total = recipeScanCoverage()
    local coverage = total > 0 and (scanned .. '/' .. total .. tr(' Berufen')) or tr('0 Berufen')
    return tr('Erfasste Berufe: ')
        .. #(Z.db.professions or {})
        .. tr('\nRezeptkatalog: ')
        .. #(Z.db.recipes or {})
        .. tr(' Rezepte aus ')
        .. coverage
        .. tr('\nLetzter Rezeptscan: ')
        .. (Z.db.recipeScan and Z.db.recipeScan > 0 and date('%d.%m.%Y %H:%M', Z.db.recipeScan) or tr('noch nicht ausgeführt'))
end
S.craftStatusText = craftStatusText
local function setCraftFeedback(message, ok)
    if not U.craftScanFeedback then
        return
    end
    U.craftScanFeedback:SetText(
        (ok and tr('|cff55ff55SCAN SUCCESSFUL|r\n') or tr('|cffff5555SCAN NICHT AUSGEFÜHRT|r\n')) .. tr(tostring(message or ''))
    )
end
S.setCraftFeedback = setCraftFeedback
local function refreshProfessions()
    local items = {}
    local rawQuery = U.recipeSearch:GetText() or ''
    local q = string.lower(rawQuery)
    local professionFilter = U.craftProfessionFilter and U.craftProfessionFilter:GetText() or 'ALL_PROFESSIONS'
    local onlineOnly = U.craftOnlineFilter and U.craftOnlineFilter:GetText() == 'ONLINE'
    local function isOnline(key)
        return peerOnline(key)
    end
    local function professionMatches(name)
        return professionFilter == 'ALL_PROFESSIONS' or L.ProfessionName(name or '') == professionFilter
    end
    local function ownRecipes(profession)
        local result = {}
        for _, r in ipairs(Z.db.recipes or {}) do
            if L.ProfessionName(r.profession or '') == profession then
                result[#result + 1] = r
            end
        end
        table.sort(result, function(a, b)
            return a.name < b.name
        end)
        return result
    end
    local function catalog(key, profession)
        if key == Z.me.key then
            local result = ownRecipes(profession)
            return { results = result, total = #result, complete = true }
        end
        return Z.db.recipeCatalogs and Z.db.recipeCatalogs[key] and Z.db.recipeCatalogs[key][profession]
    end
    local function showDetail()
        local key, profession = U.professionKey, U.professionName
        local own = key == Z.me.key
        local target = U.professionTarget
        local online = own or peerOnline(key)
        if not key or not profession then
            rows(U.professionRecipeList, {}, 40)
            U.professionRecipeTitle:SetText(tr('Recipes'))
            return
        end
        local c = catalog(key, profession)
        local recipeItems = {}
        local selectedRecipe = U.professionRecipe
        for _, recipe in ipairs(c and c.results or {}) do
            local r = recipe
            recipeItems[#recipeItems + 1] = {
                selected = selectedRecipe and selectedRecipe.id == r.id,
                icon = itemIcon(r.itemID) or NAV_ICONS.crafting,
                text = r.name .. ((r.itemName or '') ~= '' and r.itemName ~= r.name and '\n' .. r.itemName or ''),
                click = function()
                    U.professionRecipe = r
                    U.professionEntryKind = 'catalogRecipe'
                    refreshProfessions()
                end,
            }
        end
        local state = own and (#recipeItems .. tr(' Rezepte'))
            or c and c.complete and ((c.total or #recipeItems) .. tr(' Rezepte'))
            or c and (tr('Lade Rezepte … ') .. #recipeItems .. '/' .. (c.total or '?'))
            or U.professionEntryKind == 'recipe' and tr('Search result')
            or tr('Rezepte werden angefragt …')
        if not online then
            state = tr('Offline · recipes cannot be fetched')
        end
        U.professionRecipeTitle:SetText(tr(profession) .. ' · ' .. state)
        rows(U.professionRecipeList, recipeItems, 42)
        if U.professionEntryKind == 'recipe' and selectedRecipe then
            U.professionDetail:SetText(
                '|cffffd36b'
                    .. selectedRecipe.name
                    .. '|r\n'
                    .. target
                    .. ' · '
                    .. tr(profession)
                    .. tr('\nDieser Spieler kann das gesuchte Rezept herstellen.')
            )
        elseif U.professionEntryKind == 'catalogRecipe' and selectedRecipe then
            U.professionDetail:SetText(
                '|cffffd36b' .. selectedRecipe.name .. tr('|r\nRezept im Katalog von ') .. target .. ' · ' .. tr(profession)
            )
        else
            U.professionDetail:SetText(
                '|cffffd36b'
                    .. tr(profession)
                    .. '|r\n'
                    .. target
                    .. (
                        own and tr(' · dein eigener Eintrag')
                        or online and tr('\nWähle rechts ein Rezept aus.')
                        or '\n' .. tr('Offline · recipes cannot be fetched')
                    )
            )
        end
        if not online and selectedRecipe then
            U.professionDetail:SetText(U.professionDetail:GetText() .. '\n' .. tr('Saved recipe data (offline).'))
        end
        U.professionWhisper:SetEnabled(not own)
        if U.craftFavorite then
            local favorite = not own and Z.Social.IsFavorite(key)
            U.craftFavorite:SetEnabled(not own)
            U.craftFavorite:SetText(tr('Favorite'))
            if T then
                T.SetSelected(U.craftFavorite, favorite)
            end
        end
        if U.craftOrderRequest then
            U.craftOrderRequest:SetEnabled(
                not own and selectedRecipe ~= nil and peerOnline(key) and Z.db.peers[key] and Z.db.peers[key].cap30
            )
        end
    end
    local valid = false
    local function addEntry(key, target, text, own, icon, profession, kind, recipe)
        local token = kind .. '\0' .. key .. '\0' .. profession .. '\0' .. (recipe and recipe.id or '')
        if token == U.professionSelection then
            valid = true
        end
        if not own and not isOnline(key) then
            text = text .. ' · ' .. tr('Offline')
        end
        items[#items + 1] = {
            selected = token == U.professionSelection,
            icon = icon,
            text = text,
            click = function()
                U.professionSelection, U.professionKey, U.professionTarget, U.professionName, U.professionEntryKind, U.professionRecipe =
                    token, key, target, profession, kind, recipe
                if kind == 'profession' and not own and isOnline(key) then
                    Z.RequestProfile(key)
                    Z.RequestRecipeCatalog(key, profession)
                end
                refreshProfessions()
                U.OpenCompactArea('craft')
            end,
        }
    end
    local function addProfessions(key, target, s, own)
        if onlineOnly and not isOnline(key) then
            return
        end
        for _, p in ipairs(s.professions or {}) do
            local profession = L.ProfessionName(p.name)
            local value = tr(profession)
                .. '  '
                .. p.rank
                .. '/'
                .. p.max
                .. '\n'
                .. target
                .. ((s.professionNote or '') ~= '' and ' · ' .. s.professionNote or '')
            if professionMatches(profession) and (q == '' or string.lower(value):find(q, 1, true)) then
                addEntry(key, target, value, own, T and T.ProfessionIcon(profession) or NAV_ICONS.crafting, profession, 'profession')
            end
        end
    end
    addProfessions(Z.me.key, Z.me.target, { professions = Z.db.professions, professionNote = Z.db.professionNote }, true)
    for key, p in pairs(Z.db.peers) do
        if p.data and Z.db.contacts[key] then
            addProfessions(key, Z.db.contacts[key].target, p.data, false)
        end
    end
    if q ~= '' and U.recipeQueryID and Z.db.recipeResults[U.recipeQueryID] then
        for key, result in pairs(Z.db.recipeResults[U.recipeQueryID]) do
            if not onlineOnly or isOnline(key) then
                local target = key == Z.me.key and Z.me.target or Z.db.contacts[key] and Z.db.contacts[key].target or key
                for _, r in ipairs(result.results) do
                    local profession = L.ProfessionName(r.profession or '')
                    if professionMatches(profession) then
                        local value = '|cffffd36b' .. r.name .. '|r\n' .. target .. (profession ~= '' and ' · ' .. profession or '')
                        addEntry(key, target, value, key == Z.me.key, itemIcon(r.itemID) or NAV_ICONS.crafting, profession, 'recipe', r)
                    end
                end
            end
        end
    end
    if U.craftSearchState then
        local progress = Z.RecipeSearch and Z.RecipeSearch.Progress()
        if not progress or progress.id ~= U.recipeQueryID then
            progress = nil
        end
        U.craftSearchState:SetText(
            progress
                    and (progress.checked .. '/' .. progress.total .. tr(' geprüft · ') .. progress.matches .. tr(' Treffer') .. (progress.noResponse > 0 and ' · ' .. progress.noResponse .. tr(
                        ' ohne Antwort'
                    ) or '') .. (progress.done and tr(' · abgeschlossen') or tr(' · läuft')))
                or (q ~= '' and tr('Press Enter or Search to find community recipes.') or '')
        )
    end
    rows(U.professionList, items, 55)
    if U.professionCount then
        U.professionCount:SetText(#items == 1 and tr('1 Ergebnis') or #items .. tr(' Ergebnisse'))
    end
    if not valid then
        U.professionSelection, U.professionKey, U.professionTarget, U.professionName, U.professionEntryKind, U.professionRecipe =
            nil, nil, nil, nil, nil, nil
    end
    if U.professionKey then
        showDetail()
    else
        rows(U.professionRecipeList, {}, 42)
        U.professionRecipeTitle:SetText(tr('Recipes'))
        U.professionDetail:SetText(
            #items == 0
                    and (q == '' and tr('Keine Handwerker entsprechen den Filtern.') or tr(
                        'Keine passenden Handwerker oder Rezepte gefunden.'
                    ))
                or tr('Wähle einen Beruf oder einen Rezepttreffer aus.')
        )
        U.professionWhisper:SetEnabled(false)
        if U.craftFavorite then
            U.craftFavorite:SetEnabled(false)
            if T then
                T.SetSelected(U.craftFavorite, false)
            end
        end
        if U.craftOrderRequest then
            U.craftOrderRequest:SetEnabled(false)
        end
    end
end
S.refreshProfessions = refreshProfessions
function U.StartRecipeSearch()
    local id, err = Z.RecipeSearch.Start(U.recipeSearch:GetText(), U.craftProfessionFilter:GetText())
    if not id then
        U.Message(err)
        return
    end
    U.recipeQueryID = id
    U.recipeSubmittedQuery = string.lower(U.recipeSearch:GetText())
    U.recipeSubmittedProfession = U.craftProfessionFilter:GetText()
    U.recipeSearch:ClearFocus()
    refreshProfessions()
    return id
end
function U.RecipeSearchChanged()
    if
        U.recipeQueryID
        and (
            string.lower(U.recipeSearch:GetText()) ~= U.recipeSubmittedQuery
            or U.craftProfessionFilter:GetText() ~= U.recipeSubmittedProfession
        )
    then
        Z.RecipeSearch.Cancel()
        U.recipeQueryID = nil
        U.recipeSubmittedQuery = nil
        U.recipeSubmittedProfession = nil
        U.professionSelection, U.professionKey, U.professionRecipe = nil, nil, nil
    end
    refreshProfessions()
end
local ORDER_NAMES
local function materialName(id)
    local item = Z.Items and (Z.Items.Get(id) or Z.Items.Observe(id))
    return item and item.name or Z.T('Item #%d', id)
end
local function materialRow(row, perCraft)
    local unknown = tr('Unknown')
    return (perCraft and (row.perCraft .. ' × ' .. materialName(row.itemID) .. '\n') or (materialName(row.itemID) .. '\n'))
        .. Z.T(
            'Need %d · Bags %s · Allocated %s · Missing %s',
            row.needed,
            tostring(row.available or unknown),
            tostring(row.allocated or unknown),
            tostring(row.missing or unknown)
        )
        .. '\n'
        .. Z.T(
            'Marked %d · Still unconfirmed %d · Reserved elsewhere %s',
            row.manual,
            row.open,
            tostring(row.reservedElsewhere or unknown)
        )
end
function U.SaveCraftShopping()
    local context = U.craftOrderContext
    if not context then
        return nil
    end
    local crafts = tonumber(U.craftMaterialCount:GetText())
    local P = Z.MaterialPlanner
    local saved = P.Get(context.planID)
    if saved and saved.crafts == crafts then
        return saved.id
    end
    local id, err = P.BuildShoppingList(context.recipe, crafts)
    if id then
        context.planID = id
    end
    return id, err
end
function U.RefreshCraftIngredients()
    if not U.craftIngredientList or not U.craftOrderContext or U.refreshingIngredients then
        return
    end
    U.refreshingIngredients = true
    local P = Z.MaterialPlanner
    local context = U.craftOrderContext
    local crafts = tonumber(U.craftMaterialCount:GetText())
    local saved = P.Get(context.planID)
    local result, reason
    if saved and saved.crafts == crafts then
        result = P.Progress(saved.id)
    else
        result, reason = P.Calculate(context.recipe, crafts, P.ReadInventory())
    end
    local items = {}
    for _, row in ipairs(result and result.rows or {}) do
        items[#items + 1] = { icon = itemIcon(row.itemID) or NAV_ICONS.crafting, text = materialRow(row, true) }
    end
    if #items == 0 then
        items = { { text = tr(reason or result and result.reason or 'Recipe data is unavailable.') } }
    end
    rows(U.craftIngredientList, items, 62)
    U.refreshingIngredients = false
end
function U.OpenOrderMaterials(order)
    if not order then
        return
    end
    local P = Z.MaterialPlanner
    local saved = P.ForOrder(order)
    if saved then
        U.materialPlanID = saved.id
        U.materialItemID = nil
        U.SetCraftView('materials')
        return
    end
    U.materialOrderRef = { id = order.id, peer = order.peer, direction = order.direction, createdAt = order.createdAt }
    U.materialOrderCount:SetText('1')
    U.materialOrderText:SetText(order.recipeName .. '\n' .. tr('Craft count is the number of crafting operations.'))
    U.materialOrderForm:Show()
    U.Navigation.Pristine('materialOrderForm')
end
function U.RefreshMaterialPlans(force)
    if not U.materialPlanList then
        return
    end
    local P = Z.MaterialPlanner
    local items = {}
    local selected = P.Get(U.materialPlanID)
    for _, plan in ipairs(P.List()) do
        local state = P.State(plan)
        items[#items + 1] = {
            selected = plan == selected,
            text = plan.recipe.name .. '\n' .. Z.T(
                '%d crafts · %s',
                plan.crafts,
                tr(
                    state == 'LOCAL' and 'Private list'
                        or state == 'UNAVAILABLE' and 'Order unavailable'
                        or ORDER_NAMES and ORDER_NAMES[state]
                        or state
                )
            ),
            click = function()
                U.materialPlanID = plan.id
                U.materialItemID = nil
                U.RefreshMaterialPlans()
            end,
        }
    end
    U.SetEmptyHint(U.materialPlanList, 'No shopping lists yet. Open a craft request and press Save shopping list.')
    rows(U.materialPlanList, items, 54)
    U.materialStoreState:SetText(
        tr(
            not P.store and 'Saved material plans use an unsupported version. Data was preserved.'
                or P.loadError and 'Invalid material plans were discarded.'
                or 'Private shopping lists (maximum 100).'
        )
    )
    U.materialDelete:SetEnabled(selected ~= nil)
    U.materialRecheck:SetEnabled(selected ~= nil)
    U.materialMark:SetEnabled(false)
    U.materialFind:SetEnabled(false)
    local _, returnPlanID = U.Navigation.ActiveContext('craft')
    U.materialContinue:SetEnabled(
        selected and not selected.order and (U.craftOrderContext and U.craftOrderContext.planID == selected.id or returnPlanID == selected.id) or false
    )
    if not selected then
        rows(U.materialDetail, { { text = tr('Select a private shopping list.') } }, 48)
        rows(U.materialIngredients, {}, 62)
        rows(U.materialOffers, {}, 64)
        U.materialOfferState:SetText('')
        return
    end
    local order = P.Order(selected)
    local state = P.State(selected)
    local details = {
        { text = selected.recipe.name, height = 48 },
        {
            text = Z.T(
                '%d crafts · %s',
                selected.crafts,
                tr(state == 'LOCAL' and 'Private list' or state == 'UNAVAILABLE' and 'Order unavailable' or ORDER_NAMES[state] or state)
            ),
            height = 32,
        },
        { text = tr('Ingredient list completeness is unverified.'), height = 36 },
        {
            text = tr('Bags only; oldest active list reserves first.') .. '\n' .. tr('Manual marks do not confirm inventory or handoff.'),
            height = 56,
        },
    }
    if order then
        details[#details + 1] = { text = tr('Materials supplied: ') .. tr(order.materialsProvided and 'Yes' or 'No'), height = 32 }
    end
    rows(U.materialDetail, details, 36)
    local result = P.Progress(selected.id, force)
    items = {}
    local ingredient
    for _, row in ipairs(result.rows) do
        if row.itemID == U.materialItemID then
            ingredient = row
        end
        items[#items + 1] = {
            selected = row.itemID == U.materialItemID,
            icon = itemIcon(row.itemID) or NAV_ICONS.crafting,
            text = materialRow(row, false),
            click = function()
                U.materialItemID = row.itemID
                U.RefreshMaterialPlans()
            end,
        }
    end
    if #items == 0 then
        items = { { text = tr(result.reason or 'Recipe data is unavailable.') } }
    end
    rows(U.materialIngredients, items, 62)
    local active = P.Active(selected)
    U.materialMark:SetEnabled(active and ingredient ~= nil)
    U.materialFind:SetEnabled(active and ingredient ~= nil)
    U.materialMark:SetText(tr(ingredient and ingredient.manual > 0 and 'Reset acquired mark' or 'Mark acquired'))
    local offers, searching = {}, false
    if ingredient and active and U.materialFindID == ingredient.itemID then
        offers, searching = P.FindOffers(ingredient.itemID, force)
    end
    items = {}
    for _, offer in ipairs(offers) do
        items[#items + 1] = {
            text = offer.target .. ' · ' .. tr(offer.reachability) .. '\n' .. Z.T(
                'Quantity %d · Unit price %s',
                offer.o.quantity,
                A.MoneyText(math.floor(offer.unitPrice + 0.5))
            ),
            click = function()
                U.OpenMaterialOffer(offer.key, offer.o.id, offer.o.itemID)
            end,
        }
    end
    rows(U.materialOffers, items, 56)
    U.materialOfferState:SetText(
        tr(
            searching and 'Searching community offers…'
                or #offers > 0 and 'Community offers; availability is not guaranteed. Click to open.'
                or 'Select an ingredient and find offers. No auction house scan.'
        )
    )
end
ORDER_NAMES = {
    REQUESTED = tr('Requested'),
    ACCEPTED = tr('Angenommen'),
    READY = tr('Bereit'),
    COMPLETED = tr('Übergabe bestätigt'),
    DECLINED = tr('Abgelehnt'),
    CANCELLED = tr('Cancelled'),
    EXPIRED = tr('Expired'),
}
local function refreshCraftOrders()
    if not U.craftOrderList or not Z.CraftOrders then
        return
    end
    local items = {}
    local selected
    local includeClosed = U.craftShowCompleted and U.craftShowCompleted:GetChecked()
    for _, order in ipairs(Z.CraftOrders.List()) do
        if includeClosed or not ORDER_TERMINAL[order.state] then
            local token = order.key
            if token == U.craftOrderID then
                selected = order
                Z.Notifications.ReadVisible('craft', 'orders', 'craft:' .. token)
            end
            local peer = Z.db.contacts[order.peer]
            items[#items + 1] = {
                selected = token == U.craftOrderID,
                icon = itemIcon(order.itemID) or NAV_ICONS.crafting,
                text = (Z.Notifications.IsUnread('craft:' .. token) and '|cffff5555!|r ' or '')
                    .. '|cffffd36b'
                    .. order.recipeName
                    .. '|r · '
                    .. order.quantity
                    .. '\n'
                    .. (peer and peer.target or order.peer)
                    .. ' · '
                    .. (ORDER_NAMES[order.state] or order.state)
                    .. ' · '
                    .. (order.direction == 'incoming' and tr('Eingang') or tr('Ausgang')),
                click = function()
                    U.craftOrderID = token
                    refreshCraftOrders()
                end,
            }
        end
    end
    U.SetEmptyHint(U.craftOrderList, 'No craft requests yet. Search a recipe and press Request crafting.')
    rows(U.craftOrderList, items, 58)
    U.craftOrderCount:SetText(#items .. tr(' Aufträge'))
    if U.craftOrderPlan then
        U.craftOrderPlan:SetEnabled(selected ~= nil)
    end
    if not selected then
        U.craftOrderID = nil
        U.craftOrderDetail:SetText(tr('Wähle einen Herstellungsauftrag aus.'))
        for _, b in ipairs(U.craftOrderButtons) do
            b:Hide()
        end
        return
    end
    if Z.Notifications then
        Z.Notifications.ReadVisible('craft', 'orders', 'craft:' .. selected.key)
    end
    local peer = Z.db.contacts[selected.peer]
    U.craftOrderDetail:SetText(
        '|cffffd36b'
            .. selected.recipeName
            .. '|r\n'
            .. (peer and peer.target or selected.peer)
            .. ' · '
            .. selected.quantity
            .. tr(' Stück\nStatus: ')
            .. (ORDER_NAMES[selected.state] or selected.state)
            .. tr(' · Übertragung: ')
            .. (selected.delivery or '-')
            .. tr('\nMaterialien: ')
            .. (selected.materialsProvided and tr('werden gestellt') or tr('nicht gestellt'))
            .. tr(' · Trinkgeld: ')
            .. A.MoneyText(selected.tip or 0)
            .. ((selected.note or '') ~= '' and '\n\n' .. selected.note or '')
    )
    for _, b in ipairs(U.craftOrderButtons) do
        b:Hide()
    end
    local actions = selected.direction == 'incoming'
            and (selected.state == 'REQUESTED' and { { 'Annehmen', 'ACCEPT' }, { tr('Ablehnen'), 'DECLINE' } } or selected.state == 'ACCEPTED' and {
                { 'Als bereit markieren', 'READY' },
                { tr('Abbrechen'), 'CANCEL' },
            } or selected.state == 'READY' and { { tr('Abbrechen'), 'CANCEL' } } or {})
        or (
            selected.state == 'READY' and { { tr('Übergabe bestätigen'), 'CONFIRM' }, { tr('Abbrechen'), 'CANCEL' } }
            or (selected.state == 'REQUESTED' or selected.state == 'ACCEPTED') and { { tr('Abbrechen'), 'CANCEL' } }
            or {}
        )
    for i, action in ipairs(actions) do
        local b = U.craftOrderButtons[i]
        b:SetText(action[1])
        b:SetScript('OnClick', function()
            local ok, err = Z.CraftOrders.Transition(selected.key, action[2])
            U.Message(ok and tr('Auftrag aktualisiert.') or err)
            refreshCraftOrders()
        end)
        b:Show()
    end
end
S.refreshCraftOrders = refreshCraftOrders
