-- Central navigation: legacy aliases -> canonical routes, protection of unsaved input,
-- and the one-slot return context for the craft request -> trade excursion.
local Z = ZenialCommunity
local U = Z.UI
local S = U.Shared
local N = {}
U.Navigation = N

local ADDON_PAGE = S.ADDON_PAGE
N.TEXT = {
    ['unknown-section'] = 'This link is not supported.',
    ['unknown-view'] = 'This link is not supported.',
    ['invalid-selection'] = 'This link is not supported.',
    ['target-unavailable'] = 'This target is no longer available.',
    ['unsaved-input'] = 'Save or explicitly cancel the unsaved edit first; then open the link again.',
}

-- canonical section, canonical view, page, legacy section, legacy subview, selection kind
local function r(section, view, page, legacySection, legacySubview, selection)
    return { section, view, page, legacySection, legacySubview, selection }
end
local ROUTES = {
    ['today'] = r('today', nil, 9, 'today', nil),
    ['groups/today'] = r('today', nil, 9, 'groups', 'today'),
    ['activities'] = r('activities', 'discover', 10, 'activities', nil),
    ['activities/discover'] = r('activities', 'discover', 10, 'activities', nil),
    -- Finder tabs (UXFinder.lua); 'list' is the former board.
    ['activities/now'] = r('activities', 'discover', 10, 'activities', 'now'),
    ['activities/dungeons'] = r('activities', 'discover', 10, 'activities', 'dungeons'),
    ['activities/raids'] = r('activities', 'discover', 10, 'activities', 'raids'),
    ['activities/pvp'] = r('activities', 'discover', 10, 'activities', 'pvp'),
    ['activities/quests'] = r('activities', 'discover', 10, 'activities', 'quests'),
    ['activities/other'] = r('activities', 'discover', 10, 'activities', 'other'),
    ['activities/list'] = r('activities', 'discover', 10, 'activities', 'list'),
    ['activities/mine'] = r('activities', 'mine', 3, 'groups', 'mine'),
    ['activities/planned'] = r('activities', 'planned', 3, 'groups', 'scheduled'),
    ['groups'] = r('activities', 'discover', 3, 'groups', nil),
    ['groups/browse'] = r('activities', 'discover', 3, 'groups', 'browse'),
    ['groups/follow'] = r('activities', 'discover', 3, 'groups', 'follow'),
    ['groups/mine'] = r('activities', 'mine', 3, 'groups', 'mine'),
    ['groups/outgoing'] = r('activities', 'mine', 3, 'groups', 'outgoing'),
    ['groups/scheduled'] = r('activities', 'planned', 3, 'groups', 'scheduled'),
    ['groups/pvp'] = r('activities', 'discover', 3, 'groups', 'pvp'),
    ['quests'] = r('quests', 'shared', 4, 'quests', nil),
    ['quests/shared'] = r('quests', 'shared', 4, 'quests', 'shared'),
    ['quests/questgroups'] = r('quests', 'questgroups', 4, 'quests', 'questgroups'),
    ['quests/browse'] = r('quests', 'help', 4, 'quests', 'browse'),
    ['quests/mine'] = r('quests', 'help', 4, 'quests', 'mine'),
    ['quests/outgoing'] = r('quests', 'help', 4, 'quests', 'outgoing'),
    ['quests/help'] = r('quests', 'help', 4, 'quests', 'browse'),
    ['craft'] = r('craft', 'search', 2, 'craft', nil),
    ['craft/search'] = r('craft', 'search', 2, 'craft', 'search'),
    ['craft/orders'] = r('craft', 'orders', 2, 'craft', 'orders'),
    ['craft/mine'] = r('craft', 'mine', 2, 'craft', 'mine'),
    ['craft/materials'] = r('craft', 'orders', 2, 'craft', 'materials'),
    ['trade'] = r('trade', 'browse', 5, 'trade', nil),
    ['trade/browse'] = r('trade', 'browse', 5, 'trade', 'browse'),
    ['trade/mine'] = r('trade', 'mine', 5, 'trade', 'mine'),
    ['trade/rules'] = r('trade', 'rules', 5, 'trade', 'rules'),
    ['trade/manage'] = r('trade', 'mine', 5, 'trade', 'manage'),
    ['members'] = r('members', nil, 1, 'members', nil),
    ['profile'] = r('characters', 'public', 6, 'profile', nil),
    ['profile/public'] = r('characters', 'public', 6, 'profile', 'public'),
    ['characters/public'] = r('characters', 'public', 6, 'profile', 'public'),
    ['profile/characters'] = r('characters', 'overview', 6, 'profile', 'characters', 'character'),
    ['characters'] = r('characters', 'overview', 6, 'profile', 'characters', 'character'),
    ['characters/overview'] = r('characters', 'overview', 6, 'profile', 'characters', 'character'),
    ['characters/items'] = r('characters', 'items', 6, 'profile', 'characters', 'character'),
    ['profile/display'] = r('settings', 'display', 11, 'settings', 'display'),
    ['settings/display'] = r('settings', 'display', 11, 'settings', 'display'),
    ['profile/network'] = r('settings', 'privacy', 11, 'settings', 'privacy'),
    ['settings/connection'] = r('settings', 'privacy', 11, 'settings', 'privacy'),
    ['settings/privacy'] = r('settings', 'privacy', 11, 'settings', 'privacy'),
    ['settings/tools'] = r('settings', 'tools', 11, 'settings', 'tools'),
    ['settings/integrations'] = r('settings', 'tools', 11, 'settings', 'tools'),
    ['settings/data'] = r('settings', 'data', 11, 'settings', 'data'),
    ['settings'] = r('settings', nil, 11, 'settings', nil),
    ['addons'] = r('settings', 'addons', ADDON_PAGE, 'addons', nil, 'addon'),
    ['history'] = r('settings', nil, 7, 'history', nil),
}
local KNOWN_SECTIONS = {}
for key in pairs(ROUTES) do
    KNOWN_SECTIONS[key:match('^[^/]+')] = true
end

-- Pure lookup: no UI or state is touched.
function N.Resolve(section, subview, selection)
    if type(section) ~= 'string' or not KNOWN_SECTIONS[section] then
        return nil, 'unknown-section'
    end
    if subview ~= nil and type(subview) ~= 'string' then
        return nil, 'unknown-view'
    end
    local def = ROUTES[subview ~= nil and section .. '/' .. subview or section]
    if not def then
        return nil, 'unknown-view'
    end
    local route = {
        section = def[1],
        view = def[2],
        page = def[3],
        legacy = { section = def[4], subview = def[5] },
    }
    if selection ~= nil then
        if def[6] == 'addon' then
            if type(selection) ~= 'number' or selection % 1 ~= 0 or selection < 1 or selection > #S.ADDON_CATALOG then
                return nil, 'invalid-selection'
            end
            route.selection = selection
        elseif def[6] == 'character' then
            if type(selection) ~= 'table' or type(selection.characterKey) ~= 'string' or selection.characterKey == '' then
                return nil, 'invalid-selection'
            end
            for k in pairs(selection) do
                if k ~= 'characterKey' then
                    return nil, 'invalid-selection'
                end
            end
            route.selection = { characterKey = selection.characterKey }
        else
            return nil, 'invalid-selection'
        end
    end
    return route
end

local function shown(name)
    return U[name] and U[name]:IsShown()
end
local pristine = {}
local pristineHooks = {}
local function fieldType(name, index, field)
    if name == 'craftOrderForm' then
        return index == 5 and 'checked' or 'text'
    end
    if field.GetText then return 'text' end
    if field.GetChecked then return 'checked' end
end
local function formFields()
    return {
    craftOrderForm = { U.craftOrderQuantity, U.craftMaterialCount, U.craftOrderTip, U.craftOrderNote, U.craftOrderMaterials },
    materialOrderForm = { U.materialOrderCount },
    activityCreator = { U.creatorWhen, U.creatorKind, U.creatorGoal, U.creatorText, U.groupCustom, U.groupKind, U.groupActivity, U.groupActivitySearch, U.groupFields and U.groupFields.size, U.groupFields and U.groupFields.min, U.groupFields and U.groupFields.max, U.groupFields and U.groupFields.tank, U.groupFields and U.groupFields.healer, U.groupFields and U.groupFields.dd, U.groupFields and U.groupFields.note, U.groupTemplateDuration, U.questPicker, U.questPickerSearch, U.questFields and U.questFields.title, U.questFields and U.questFields.zone, U.questFields and U.questFields.min, U.questFields and U.questFields.max, U.questFields and U.questFields.note, U.questDuration },
    scheduledEditor = { U.scheduledKind, U.scheduledGoal, U.scheduledActivity, U.scheduledSearch, U.scheduledDay, U.scheduledTime, U.scheduledDuration, U.scheduledNote, U.scheduledOrganizerRole, U.scheduledSlots and U.scheduledSlots.TANK, U.scheduledSlots and U.scheduledSlots.HEALER, U.scheduledSlots and U.scheduledSlots.DAMAGER },
    templateNameDialog = { U.groupTemplateName },
    scheduledSeries = { U.scheduledSeriesCount },
    }
end
function N.Pristine(name, baseline)
    if U[name] and not pristineHooks[name] then
        local formName = name
        U[name]:HookScript('OnHide', function() pristine[formName] = nil end)
        pristineHooks[name] = true
    end
    local snapshot = {}
    if type(baseline) == 'table' then
        for i, value in pairs(baseline) do
            local field = (formFields()[name] or {})[i]
            if field then
                local kind = fieldType(name, i, field)
                snapshot[i] = kind == 'checked' and { checked = value and true or false } or { text = value }
            else
                snapshot[i] = value
            end
        end
    else
    for i, field in ipairs(formFields()[name] or {}) do
        if field then
            local kind = fieldType(name, i, field)
            if kind == 'checked' then
                snapshot[i] = { checked = field:GetChecked() and true or false }
            else
                snapshot[i] = { text = field:GetText() }
            end
        end
    end
    end
    pristine[name] = snapshot
end
local function changedForm(name)
    local snapshot = pristine[name]
    if not snapshot then return true end
    for i, field in ipairs(formFields()[name] or {}) do
        if field then
            local value = snapshot[i]
            if type(value) ~= 'table' then return true end
            local kind = fieldType(name, i, field)
            if kind == 'checked' and (field:GetChecked() and true or false) ~= value.checked then return true end
            if kind == 'text' and field:GetText() ~= value.text then return true end
        end
    end
    return false
end
-- Returns the name of the first open dialog that holds input a navigation would destroy.
function N.UnsavedInput()
    for _, name in ipairs({ 'craftOrderForm', 'materialOrderForm', 'activityCreator', 'scheduledEditor', 'templateNameDialog', 'scheduledSeries' }) do
        if shown(name) and changedForm(name) then
            return name
        end
    end
    if shown('activityDetails') and U.activityDetailNote and U.activityDetailNote:GetText() ~= '' then
        return 'activityDetails'
    end
    if shown('socialDiary') and U.socialDiaryNoteOwner and U.socialDiaryNote and U.socialDiaryNote:GetText() ~= (Z.Social.GetNote(U.socialDiaryNoteOwner) or '') then
        return 'socialDiary'
    end
    if shown('categorySettings') and U.categoryName then
        local C = Z.SocialCategories
        local saved = U.categoryEditID and C and C.Label(U.categoryEditID) or ''
        if U.categoryName:GetText() ~= saved then
            return 'categorySettings'
        end
    end
    if shown('pvpPreview') and U.pvpCallNote and U.pvpCallNote:GetText() ~= '' then
        return 'pvpPreview'
    end
end

function N.Fail(reason)
    U.Message(N.TEXT[reason] or N.TEXT['unknown-view'])
    return false, reason
end

-- Availability, input guard, then the unchanged page/subview switch. Reports nothing itself.
function N.Open(route, opts)
    if type(route) ~= 'table' or not route.page or not route.legacy then
        return false, 'unknown-section'
    end
    if route.page == ADDON_PAGE and (U.RefreshAddonAvailability and U.RefreshAddonAvailability() or 0) == 0 then
        return false, 'target-unavailable'
    end
    local characterKey = route.selection and route.page == 6 and route.selection.characterKey
    if characterKey then
        local found = false
        for _, row in ipairs(Z.AccountOverview and Z.AccountOverview.List() or {}) do
            if row.key == characterKey then
                found = true
                break
            end
        end
        if not found then
            return false, 'target-unavailable'
        end
    end
    if not (opts and opts.skipGuard) and N.UnsavedInput() then
        return false, 'unsaved-input'
    end
    if characterKey then
        U.characterKey = characterKey
    end
    S.applyRoute(route)
    return true
end

-- Return context for the craft request -> trade excursion (one slot, replaced by a new one).
local context
local sequence = 0
local function text(value, max)
    return type(value) == 'string' and #value <= max and value or nil
end
function N.BeginContext(kind, payload, returnRoute)
    if kind ~= 'craft' or type(payload) ~= 'table' or type(returnRoute) ~= 'table' then
        return nil, 'invalid-selection'
    end
    local L = Z.Logic
    local recipe = payload.recipeRef
    local clean = {
        peerKey = L.ValidIdentityKey(payload.peerKey) and payload.peerKey or nil,
        quantityText = text(payload.quantityText, 6),
        craftsText = text(payload.craftsText, 6),
        tipGoldText = text(payload.tipGoldText, 10),
        noteText = text(payload.noteText, 192),
        materialsProvided = payload.materialsProvided == true,
        planID = text(payload.planID, 64),
        materialPlanID = payload.materialPlanID,
        materialItemID = payload.materialItemID,
        materialFindID = payload.materialFindID,
    }
    if not clean.peerKey or not clean.planID or not clean.quantityText or not clean.craftsText or not clean.tipGoldText or not clean.noteText or type(recipe) ~= 'table' then
        return nil, 'invalid-selection'
    end
    clean.recipeRef = {}
    for _, field in ipairs({ 'id', 'itemID', 'name', 'itemName', 'profession', 'materials' }) do
        clean.recipeRef[field] = recipe[field]
    end
    for _, field in ipairs({ 'materialPlanID', 'materialItemID', 'materialFindID' }) do
        local kind = type(clean[field])
        if kind ~= 'nil' and kind ~= 'string' and kind ~= 'number' then
            return nil, 'invalid-selection'
        end
    end
    sequence = sequence + 1
    context = { token = 'craft:' .. sequence, kind = kind, payload = clean, route = returnRoute }
    return context.token
end
function N.ActiveContext(kind)
    if context and context.kind == kind then
        return context.token, context.payload.planID
    end
end
function N.DiscardContext(token)
    if context and (token == nil or token == context.token) then
        context = nil
    end
end
function N.Return(token)
    local c = context
    if not c or token ~= c.token then
        return false, 'target-unavailable'
    end
    local p, P = c.payload, Z.MaterialPlanner
    local plan = P and P.Get(p.planID)
    if not Z.db.contacts[p.peerKey] or Z.db.blocked[p.peerKey] or not Z.Logic.ValidRecipe(p.recipeRef) or not plan or not P.Active(plan) or plan.order then
        return N.Fail('target-unavailable')
    end
    if N.UnsavedInput() then
        return N.Fail('unsaved-input')
    end
    local ok, why = N.Open(c.route)
    if not ok then
        return N.Fail(why)
    end
    U.craftOrderContext = { peer = p.peerKey, recipe = p.recipeRef, planID = p.planID }
    U.materialPlanID, U.materialItemID, U.materialFindID = p.materialPlanID, p.materialItemID, p.materialFindID
    local contact = Z.db.contacts[p.peerKey]
    U.craftOrderContextText:SetText(Z.T('Request from %s: %s', contact.target or p.peerKey, p.recipeRef.name))
    U.LayoutCraftOrderForm()
    U.craftOrderForm:Show()
    -- The context must exist before the craft count changes (its OnTextChanged refreshes the ingredients).
    U.craftOrderQuantity:SetText(p.quantityText)
    U.craftMaterialCount:SetText(p.craftsText)
    U.craftOrderTip:SetText(p.tipGoldText)
    U.craftOrderNote:SetText(p.noteText)
    U.craftOrderMaterials:SetChecked(p.materialsProvided)
    U.RefreshCraftIngredients()
    N.Pristine('craftOrderForm', { '1', '1', '0', '', false })
    context = nil
    return true
end
return N
