local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local label, button, navButton, edit, selector, checkbox = S.label, S.button, S.navButton, S.edit, S.selector, S.checkbox
local list, panel, craftStatusText, setCraftFeedback = S.list, S.panel, S.craftStatusText, S.setCraftFeedback
local refreshProfessions, refreshCraftOrders, place = S.refreshProfessions, S.refreshCraftOrders, S.place

function S.createCraftPage(f)
    local p = U.pages[2]
    U.craftSearchTab = navButton(p, tr('Suchen'), 0, 0, 150, function()
        U.SetCraftView('search')
    end)
    U.craftMineTab = navButton(p, tr('Meine Berufe'), 380, 0, 170, function()
        U.SetCraftView('mine')
    end)
    U.craftOrdersTab = navButton(p, tr('Craft requests'), 160, 0, 210, function()
        U.SetCraftView('orders')
    end)
    U.craftMaterialsTab = navButton(p, tr('Material planning'), 560, 0, 230, function()
        U.SetCraftView('materials')
    end)
    U.craftMaterialsTab:Hide()
    U.craftOrderFilterBar = CreateFrame('Frame', nil, p)
    U.craftOrderFilterBar:SetPoint('TOPLEFT', 0, -38)
    U.craftOrderFilterBar:SetSize(856, 34)
    U.craftFilterAll = navButton(U.craftOrderFilterBar, tr('All requests'), 0, 0, 130, function() U.SetCraftOrderFilter('all') end)
    U.craftFilterIncoming = navButton(U.craftOrderFilterBar, tr('Incoming requests'), 138, 0, 155, function() U.SetCraftOrderFilter('incoming') end)
    U.craftFilterOutgoing = navButton(U.craftOrderFilterBar, tr('Outgoing requests'), 301, 0, 155, function() U.SetCraftOrderFilter('outgoing') end)
    U.craftFilterLists = navButton(U.craftOrderFilterBar, tr('Shopping lists'), 464, 0, 180, function() U.SetCraftOrderFilter('lists') end)
    U.craftOrderFilter = 'all'
    U.craftOrderFilterBar:Hide()
    U.craftSearchFrame = CreateFrame('Frame', nil, p)
    U.craftSearchFrame:SetPoint('TOPLEFT', 0, -40)
    U.craftSearchFrame:SetSize(856, 500)
    U.recipeSearch = edit(U.craftSearchFrame, tr('Rezept, Gegenstand oder Beruf'), 0, 0, 365, 64)
    U.recipeSearch:SetScript('OnTextChanged', U.RecipeSearchChanged)
    U.recipeSearch:SetScript('OnEnterPressed', U.StartRecipeSearch)
    U.craftSearchButton = button(U.craftSearchFrame, tr('Suchen'), 377, -17, 105, U.StartRecipeSearch)
    U.craftResetButton = button(U.craftSearchFrame, tr('Zurücksetzen'), 494, -17, 125, function()
        if Z.RecipeSearch then
            Z.RecipeSearch.Cancel()
        end
        U.recipeSearch:SetText('')
        U.professionSelection, U.professionKey, U.professionRecipe = nil, nil, nil
        U.recipeQueryID = nil
        refreshProfessions()
    end)
    U.craftProfessionFilter = selector(U.craftSearchFrame, tr('Beruf'), 0, -48, 220, { 'ALL_PROFESSIONS' }, U.RecipeSearchChanged)
    U.craftOnlineFilter = selector(U.craftSearchFrame, tr('Spieler'), 232, -48, 145, { 'ALL', 'ONLINE' }, refreshProfessions)
    U.professionCount = label(U.craftSearchFrame, tr('0 Ergebnisse'), 389, -66, 105, 'GameFontNormal')
    U.craftSearchState = label(U.craftSearchFrame, '', 500, -66, 340, 'GameFontHighlightSmall')
    U.craftSearchState:SetJustifyH('RIGHT')
    U.professionList = list(U.craftSearchFrame, 0, -102, 470, 270)
    U.professionDetail =
        label(U.craftSearchFrame, tr('Wähle einen Beruf oder einen Rezepttreffer aus.'), 495, -102, 345, 'GameFontHighlight')
    U.professionDetail:SetHeight(68)
    U.professionRecipeTitle = label(U.craftSearchFrame, 'Rezepte', 495, -176, 345, 'GameFontNormal')
    U.professionRecipeList = list(U.craftSearchFrame, 495, -196, 345, 90)
    U.craftDetailMaterialsTitle = label(U.craftSearchFrame, tr('Materials for this recipe'), 495, -292, 345, 'GameFontNormal')
    U.craftDetailMaterials = list(U.craftSearchFrame, 495, -312, 345, 64)
    U.craftDetailMaterialState = label(U.craftSearchFrame, '', 495, -390, 345, 'GameFontHighlightSmall')
    U.craftDetailMaterialState:SetHeight(30)
    U.craftDetailCrafts = edit(U.craftSearchFrame, tr('Crafts for material planning'), 495, -426, 90, 6)
    U.craftDetailCrafts:SetText('1')
    U.craftDetailCrafts:SetScript('OnTextChanged', function() if U.RefreshCraftDetailMaterials then U.RefreshCraftDetailMaterials() end end)
    U.craftDetailCrafts.caption:Hide()
    U.craftDetailSaveList = button(U.craftSearchFrame, tr('Save shopping list'), 592, -443, 130, function()
        local id, err = U.SaveCraftDetailShopping()
        U.Message(id and tr('Private shopping list saved.') or tr(err or 'Recipe data is unavailable.'))
        U.RefreshCraftDetailMaterials()
    end)
    U.craftDetailOffers = button(U.craftSearchFrame, tr('View offers'), 728, -443, 112, function()
        local id, err = U.SaveCraftDetailShopping()
        if not id then U.Message(tr(err or 'Recipe data is unavailable.')); return end
        U.materialPlanID, U.materialFindID = id, nil
        U.materialItemID = U.craftDetailMissingItem
        U.SetCraftView('materials')
    end)
    U.craftDetailMaterialsTitle:Hide(); U.craftDetailMaterials:Hide(); U.craftDetailMaterialState:Hide()
    U.craftDetailCrafts:Hide(); U.craftDetailCrafts.caption:Hide(); U.craftDetailSaveList:Hide(); U.craftDetailOffers:Hide()
    U.professionWhisper = button(U.craftSearchFrame, tr('Anflüstern'), 105, -443, 110, function()
        if U.professionTarget then
            A.Whisper(U.professionTarget)
        end
    end)
    U.professionWhisper:SetEnabled(false)
    U.craftOrderRequest = button(U.craftSearchFrame, tr('Herstellung anfragen'), 220, -443, 190, function()
        if not U.professionRecipe then
            return
        end
        U.Navigation.DiscardContext()
        local recipe = {}
        for k, v in pairs(U.professionRecipe) do
            recipe[k] = v
        end
        local crafts = tonumber(U.craftDetailCrafts:GetText())
        local saved = Z.MaterialPlanner.Get(U.craftDetailPlanID)
        U.craftOrderContext = { peer = U.professionKey, recipe = recipe }
        if saved and not saved.order and Z.MaterialPlanner.Active(saved) and saved.recipe.id == recipe.id
            and saved.recipe.itemID == recipe.itemID and saved.crafts == crafts then
            U.craftOrderContext.planID = saved.id
        end
        local c = Z.db.contacts[U.professionKey]
        U.craftOrderContextText:SetText(Z.T('Request from %s: %s', c and c.target or U.professionKey, recipe.name))
        U.craftMaterialCount:SetText(L.Int(crafts, 1, 100000) and tostring(crafts) or '1')
        U.LayoutCraftOrderForm()
        U.craftOrderForm:Show()
        U.craftOrderQuantity:SetText('1')
        U.craftOrderTip:SetText('0')
        U.craftOrderNote:SetText('')
        U.craftOrderMaterials:SetChecked(false)
        U.RefreshCraftIngredients()
        U.Navigation.Pristine('craftOrderForm')
    end)
    U.craftOrderRequest:SetEnabled(false)
    U.craftBack = button(U.craftSearchFrame, tr('← Zurück zur Liste'), 665, 0, 180, function()
        U.CloseCompactArea('craft')
    end)
    U.craftBack:Hide()
    U.craftFavorite = button(U.craftSearchFrame, 'Favorite', 0, -443, 95, function()
        if U.professionKey then
            local value, err = Z.Social.ToggleFavorite(U.professionKey)
            if value == nil then
                U.Message(err)
            else
                refreshProfessions()
            end
        end
    end)
    U.craftFavorite:SetEnabled(false)
    place(U.professionWhisper, 105, -443, 110)
    place(U.craftOrderRequest, 220, -443, 190)
    U.craftOrderForm = panel(U.craftSearchFrame)
    U.craftOrderForm:ClearAllPoints()
    U.craftOrderForm:SetPoint('TOPLEFT', U.craftSearchFrame, 'TOPLEFT', 0, -102)
    U.craftOrderForm:SetPoint('BOTTOMRIGHT', U.craftSearchFrame, 'BOTTOMRIGHT', 0, 0)
    U.craftOrderForm:SetFrameLevel(U.craftSearchFrame:GetFrameLevel() + 4)
    U.craftOrderTitle = label(U.craftOrderForm, tr('|cffffd36bHERSTELLUNG ANFRAGEN|r'), 16, -8, 824, 'GameFontNormalLarge')
    U.craftOrderContextText = label(U.craftOrderForm, '', 16, -32, 824, 'GameFontHighlightSmall')
    U.craftOrderContextText:SetHeight(36)
    U.craftOrderQuantity = edit(U.craftOrderForm, tr('Gewünschte Stückzahl'), 16, -60, 190, 6)
    U.craftOrderTip = edit(U.craftOrderForm, tr('Trinkgeld in Gold'), 220, -60, 190, 10)
    U.craftOrderMaterials = checkbox(U.craftOrderForm, tr('Materialien werden gestellt'), 432, -78, 300)
    U.craftOrderMaterials.text:SetHeight(32)
    U.craftMaterialCount = edit(U.craftOrderForm, tr('Crafts for material planning'), 16, -124, 190, 6)
    U.craftMaterialCount:SetText('1')
    U.craftMaterialCount:SetScript('OnTextChanged', U.RefreshCraftIngredients)
    U.craftYieldNote = label(
        U.craftOrderForm,
        tr('Set craft count explicitly; recipe yield is unknown.') .. '\n' .. tr('Ingredient list completeness is unverified.'),
        220,
        -126,
        560,
        'GameFontHighlightSmall'
    )
    U.craftYieldNote:SetHeight(40)
    U.craftIngredientTitle = label(U.craftOrderForm, tr('Ingredients per craft'), 16, -164, 824, 'GameFontNormal')
    U.craftIngredientList = list(U.craftOrderForm, 16, -184, 824, 58)
    U.craftShoppingSave = button(U.craftOrderForm, tr('Save shopping list'), 16, -250, 220, function()
        local id, err = U.SaveCraftShopping()
        U.Message(id and tr('Private shopping list saved.') or err)
        U.RefreshCraftIngredients()
    end)
    U.craftShoppingOpen = button(U.craftOrderForm, tr('Open shopping lists'), 250, -250, 220, function()
        local id, err = U.SaveCraftShopping()
        if id then
            U.materialPlanID = id
            U.materialItemID = nil
            U.craftOrderForm:Hide()
            U.SetCraftView('materials')
        else
            U.Message(err)
        end
    end)
    U.craftOrderNote = edit(U.craftOrderForm, tr('Notiz (optional)'), 490, -250, 330, 192, true)
    U.craftOrderNote:SetHeight(50)
    U.craftOrderSend = button(U.craftOrderForm, tr('Anfrage senden'), 16, -334, 220, function()
        local quantity = tonumber(U.craftOrderQuantity:GetText())
        local gold = (U.craftOrderTip:GetText() or ''):gsub(',', '.')
        local tip = tonumber(gold)
        if not L.Int(quantity, 1, 100000) or not tip or tip ~= tip or tip < 0 or tip > 214748.3646 then
            U.Message(tr('Stückzahl oder Trinkgeld ist ungültig.'))
            return
        end
        local id, err = Z.CraftOrders.Create(
            U.craftOrderContext and U.craftOrderContext.peer,
            U.craftOrderContext and U.craftOrderContext.recipe,
            quantity,
            U.craftOrderMaterials:GetChecked(),
            math.floor(tip * 10000 + 0.5),
            U.craftOrderNote:GetText()
        )
        if id then
            local planID, planError = U.SaveCraftShopping()
            if planID then
                local ok, reason = Z.MaterialPlanner.AttachToOrder(planID, Z.CraftOrders.orders[id])
                if not ok then
                    planError = reason
                end
            end
            U.craftOrderForm:Hide()
            U.craftOrderID = id
            U.SetCraftView('orders')
            if planError then
                U.Message(tr('Order sent; shopping list could not be saved: ') .. tr(planError))
            end
        else
            U.Message(err)
        end
    end, 'primary')
    U.craftOrderCancel = button(U.craftOrderForm, tr('Abbrechen'), 250, -334, 220, function()
        U.craftOrderForm:Hide()
    end)
    function U.LayoutCraftOrderForm()
        U.craftOrderForm:ClearAllPoints()
        U.craftOrderForm:SetPoint('TOPLEFT', U.craftSearchFrame, 'TOPLEFT', 0, U.compactArea == 'craft' and 0 or -102)
        U.craftOrderForm:SetPoint('BOTTOMRIGHT', U.craftSearchFrame, 'BOTTOMRIGHT', 0, 0)
    end
    U.LayoutCraftOrderForm()
    U.craftOrderForm:Hide()
    for _, field in ipairs({ U.craftOrderQuantity, U.craftMaterialCount, U.craftOrderTip, U.craftOrderNote }) do
        field:SetScript('OnEscapePressed', function(self)
            self:ClearFocus()
            U.craftOrderForm:Hide()
        end)
    end
    U.craftMineFrame = CreateFrame('Frame', nil, p)
    U.craftMineFrame:SetPoint('TOPLEFT', 0, -40)
    U.craftMineFrame:SetSize(856, 414)
    label(U.craftMineFrame, '|cffffd36bMEINE BERUFE|r', 12, -8, 350, 'GameFontNormalLarge')
    U.craftScanStatus = label(U.craftMineFrame, craftStatusText(), 12, -38, 800, 'GameFontHighlight')
    U.craftScanStatus:SetHeight(58)
    U.craftNotice = CreateFrame('Frame', nil, U.craftMineFrame, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    U.craftNotice:SetPoint('TOPLEFT', 0, -102)
    U.craftNotice:SetSize(820, 124)
    if T then
        T.Panel(U.craftNotice, 'inset')
    end
    label(U.craftNotice, tr('|cffff5555WICHTIG: DAS PASSENDE BERUFSFENSTER MUSS GEÖFFNET SEIN|r'), 14, -12, 790, 'GameFontNormalLarge')
    local scanHelp = label(
        U.craftNotice,
        tr(
            'Öffne dein eigenes WoW-Berufsfenster und lasse die Rezeptliste sichtbar. ZenialCommunity scannt dann automatisch. Ist die vollständige ungefilterte Liste nicht sicher verfügbar, werden erkannte Rezepte nur ergänzt und nichts aus dem letzten vollständigen Stand gelöscht.'
        ),
        14,
        -42,
        790,
        'GameFontHighlight'
    )
    scanHelp:SetHeight(70)
    button(U.craftMineFrame, tr('Berufe scannen'), 0, -242, 180, function()
        local data, msg = Z.ProfessionScan.RefreshProfessions(true)
        U.Message(msg)
        U.SetCraftView('mine')
        setCraftFeedback(msg, data == true)
    end, 'primary')
    button(U.craftMineFrame, tr('Jetzt erneut prüfen'), 192, -242, 220, function()
        local ok, msg = Z.ProfessionScan.Request()
        U.Message(msg)
        U.SetCraftView('mine')
        setCraftFeedback(msg, ok)
    end, 'primary')
    U.craftScanFeedback = label(
        U.craftMineFrame,
        tr('Der automatische Scan wartet auf ein eigenes geöffnetes Berufsfenster.'),
        0,
        -286,
        820,
        'GameFontHighlight'
    )
    U.craftScanFeedback:SetHeight(72)
    U.craftMineFrame:Hide()
    U.craftOrdersFrame = CreateFrame('Frame', nil, p)
    U.craftOrdersFrame:SetPoint('TOPLEFT', 0, -78)
    U.craftOrdersFrame:SetSize(856, 376)
    U.craftOrderCount = label(U.craftOrdersFrame, tr('0 Aufträge'), 0, 0, 220, 'GameFontNormal')
    U.craftShowCompleted = checkbox(U.craftOrdersFrame, 'Show completed', 235, 2, 235, refreshCraftOrders)
    U.craftShowCompleted:SetChecked(false)
    U.craftOrderList = list(U.craftOrdersFrame, 0, -28, 470, 365)
    U.craftOrderDetail = label(U.craftOrdersFrame, tr('Wähle einen Herstellungsauftrag aus.'), 495, -28, 345, 'GameFontHighlight')
    U.craftOrderDetail:SetHeight(220)
    U.craftOrderButtons = {
        button(U.craftOrdersFrame, '', 495, -270, 165, function() end, 'primary'),
        button(U.craftOrdersFrame, '', 670, -270, 150, function() end, 'danger'),
    }
    for _, b in ipairs(U.craftOrderButtons) do
        b:Hide()
    end
    U.craftOrderPlan = button(U.craftOrdersFrame, tr('Material planning'), 495, -315, 325, function()
        local order = Z.CraftOrders.orders[U.craftOrderID] or Z.db.craftOrderHistory[U.craftOrderID]
        U.OpenOrderMaterials(order)
    end)
    U.craftOrderPlan:SetEnabled(false)
    U.craftOrdersFrame:Hide()
    U.craftView = 'search'
    U.materialOrderForm = panel(U.frame)
    U.materialOrderForm:ClearAllPoints()
    U.materialOrderForm:SetPoint('CENTER', U.frame, 'CENTER', 0, 0)
    U.materialOrderForm:SetSize(520, 270)
    label(U.materialOrderForm, tr('Material planning'), 16, -16, 480, 'GameFontNormalLarge')
    U.materialOrderText = label(U.materialOrderForm, '', 16, -48, 480, 'GameFontHighlightSmall')
    U.materialOrderText:SetHeight(80)
    U.materialOrderCount = edit(U.materialOrderForm, tr('Crafts for material planning'), 16, -140, 240, 6)
    U.materialOrderSave = button(U.materialOrderForm, tr('Save shopping list'), 16, -220, 240, function()
        local ref = U.materialOrderRef
        local order = ref and Z.CraftOrders.Get(ref.id, ref.peer, ref.direction)
        if not order or order.createdAt ~= ref.createdAt then
            U.Message(tr('Order is unavailable.'))
            return
        end
        local existing = Z.MaterialPlanner.ForOrder(order)
        local id, err = existing and existing.id
        if not id then
            id, err = Z.MaterialPlanner.BuildShoppingList(Z.MaterialPlanner.RecipeForOrder(order), tonumber(U.materialOrderCount:GetText()))
        end
        if id then
            local ok, reason = Z.MaterialPlanner.AttachToOrder(id, order)
            if ok then
                U.materialPlanID = id
                U.materialItemID = nil
                U.materialOrderForm:Hide()
                U.SetCraftView('materials')
            else
                U.Message(reason)
            end
        else
            U.Message(err)
        end
    end)
    U.materialOrderCancel = button(U.materialOrderForm, tr('Cancel'), 270, -220, 220, function()
        U.materialOrderForm:Hide()
    end)
    U.materialOrderForm:Hide()
    U.materialPlanFrame = CreateFrame('Frame', nil, p)
    U.materialPlanFrame:SetPoint('TOPLEFT', 0, -78)
    U.materialPlanFrame:SetSize(856, 376)
    U.materialStoreState = label(U.materialPlanFrame, '', 0, -4, 240, 'GameFontHighlightSmall')
    U.materialStoreState:SetHeight(64)
    U.materialPlanList = list(U.materialPlanFrame, 0, -74, 216, 242)
    U.materialDetail = list(U.materialPlanFrame, 270, -4, 546, 88)
    U.materialIngredients = list(U.materialPlanFrame, 270, -102, 546, 126)
    U.materialRecheck = button(U.materialPlanFrame, tr('Recheck'), 0, -330, 112, function()
        U.RefreshMaterialPlans(true)
    end)
    U.materialDelete = button(U.materialPlanFrame, tr('Delete list'), 124, -330, 112, function()
        if Z.MaterialPlanner.Delete(U.materialPlanID) then
            U.materialPlanID = nil
            U.materialItemID = nil
            U.RefreshMaterialPlans()
        end
    end, 'danger')
    U.materialContinue = button(U.materialPlanFrame, tr('Continue craft request'), 0, -368, 236, function()
        local plan = Z.MaterialPlanner.Get(U.materialPlanID)
        if plan and not plan.order and U.craftOrderContext and U.craftOrderContext.planID == plan.id then
            U.SetCraftView('search')
            U.craftOrderForm:Show()
            U.RefreshCraftIngredients()
            U.Navigation.Pristine('craftOrderForm', { '1', '1', '0', '', false })
        elseif plan and not plan.order then
            local token, planID = U.Navigation.ActiveContext('craft')
            if token and planID == plan.id then
                U.Navigation.Return(token)
            end
        end
    end)
    U.materialMark = button(U.materialPlanFrame, tr('Mark acquired'), 270, -239, 220, function()
        local plan = Z.MaterialPlanner.Get(U.materialPlanID)
        local result = plan and Z.MaterialPlanner.Progress(plan.id)
        local ingredient
        for _, row in ipairs(result and result.rows or {}) do
            if row.itemID == U.materialItemID then
                ingredient = row
            end
        end
        if ingredient then
            local ok, err = Z.MaterialPlanner.UpdateProgress(plan.id, ingredient.itemID, ingredient.manual > 0 and 0 or ingredient.needed)
            if not ok then
                U.Message(err)
            end
        end
        U.RefreshMaterialPlans()
    end)
    U.materialFind = button(U.materialPlanFrame, tr('Find offers'), 502, -239, 230, function()
        U.materialFindID = U.materialItemID
        U.RefreshMaterialPlans(true)
    end)
    U.materialOfferState = label(U.materialPlanFrame, '', 270, -264, 570, 'GameFontHighlightSmall')
    U.materialOfferState:SetHeight(30)
    U.materialOffers = list(U.materialPlanFrame, 270, -296, 546, 64)
    U.materialPlanFrame:Hide()
end
