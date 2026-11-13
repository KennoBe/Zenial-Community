-- Group form of the activity dialog, laid out for few decisions: the picture and facts of the chosen activity,
-- size and running time as switches, wanted roles as counters with the role symbols.
-- The existing controls stay the data: every switch and counter writes into the edit box that already holds
-- the value (U.groupFields.*, U.groupTemplateDuration), so validation, drafts, templates and publishing are
-- untouched. Choosing an activity for a new group fills level range and size from GroupFinderCatalog.
-- Called once from U.CreateCommunityHome after U.ApplyFormLayouts.
local Z = ZenialCommunity
local U, A, T, K = Z.UI, Z.Adapter, Z.Theme, Z.Kit
local C = Z.GroupFinderCatalog
if type(U) ~= 'table' or type(T) ~= 'table' or type(K) ~= 'table' or type(C) ~= 'table' or type(U.Finder) ~= 'table' then
    return
end
local F = U.Finder
local G = {}
U.GroupForm = G

local ROLES = { { 'TANK', 'tank', 10 }, { 'HEALER', 'healer', 15 }, { 'DAMAGER', 'dd', 40 } }
local SIZES = { '5', '10', '20', '40' }
local DURATIONS = { '30', '60', '120', '240' }

local function tr(value)
    return Z.T(value)
end
local function call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= 'function' then
        return false
    end
    return pcall(fn, object, ...)
end
local function place(f, x, y, width, height)
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT', x, y)
    if width then
        f:SetWidth(width)
    end
    if height then
        f:SetHeight(height)
    end
end
local function number(field)
    return tonumber(field:GetText()) or 0
end
local function overline(parent, value, x, y, width)
    local fs = K.Text(parent, K.Upper(tr(value)), 'overline', 'goldDim')
    place(fs, x, y, width or 300, 12)
    call(fs, 'SetWordWrap', false)
    return fs
end

-- Activity the form currently names (id) and its catalogue entry.
local function currentActivity()
    local custom = U.groupKind:GetText() == 'CUSTOM'
    local id = custom and U.groupCustom:GetText() or U.groupActivity:GetText()
    return id, not custom and C.Get(id) or nil, custom
end

-- A new group takes level range and size of its activity; an edited group keeps what it has.
local function applyCatalogue(activity)
    if U.groupEditID or U.Shared.restoringDraft or U.groupLoading or not U.groupFields then
        return
    end
    local e = C.Get(activity)
    if not e then
        return
    end
    local fields = U.groupFields
    U.groupLoading = true
    fields.min:SetText(tostring(e.min))
    fields.max:SetText(tostring(e.max))
    fields.size:SetText(tostring(e.size))
    U.groupLoading = false
    if U.AutofillGroupNeeds then
        U.AutofillGroupNeeds()
    end
end

local function bump(key, delta, limit)
    local fields = U.groupFields
    local size = math.max(2, number(fields.size))
    local others = number(fields.tank) + number(fields.healer) + number(fields.dd) - number(fields[key])
    local value = math.max(0, math.min(limit, size - others, number(fields[key]) + delta))
    U.groupNeedsAuto = false
    U.groupAutofilling = true
    fields[key]:SetText(tostring(value))
    U.groupAutofilling = false
    U.CaptureGroupDraft()
end

local function createStepper(parent, role, key, limit)
    local s = CreateFrame('Frame', nil, parent)
    s:SetSize(200, 38)
    s.fill = s:CreateTexture(nil, 'BACKGROUND')
    s.fill:SetAllPoints()
    T.Tint(s.fill, 'SetColorTexture', 'inset')
    s.edges = T.Edges(s, 'BORDER')
    T.TintEdges(s.edges, 'line')
    s.icon = s:CreateTexture(nil, 'ARTWORK')
    s.icon:SetSize(18, 18)
    s.icon:SetPoint('LEFT', 10, 0)
    F.SetRoleIcon(s.icon, role)
    s.label = K.Text(s, Z.Locale.Role(role), 'heading', T.roleColors[role])
    s.label:SetPoint('LEFT', 34, 0)
    s.label:SetWidth(70)
    s.label:SetHeight(14)
    call(s.label, 'SetWordWrap', false)
    s.plus = T.Button(s, '+', 26, 26, function()
        bump(key, 1, limit)
    end, 'secondary')
    s.plus:SetPoint('RIGHT', -6, 0)
    s.value = K.Text(s, '0', 'title', 'text')
    s.value:SetPoint('RIGHT', -36, 0)
    s.value:SetWidth(34)
    s.value:SetHeight(18)
    s.value:SetJustifyH('CENTER')
    s.minus = T.Button(s, '-', 26, 26, function()
        bump(key, -1, limit)
    end, 'secondary')
    s.minus:SetPoint('RIGHT', -74, 0)
    s.key, s.limit = key, limit
    return s
end

-- Redraws everything this file added from the values of the form's own fields.
function U.RefreshGroupForm()
    local form = U.groupForm
    if not G.ready or not form or not U.groupFields then
        return
    end
    local fields = U.groupFields
    local id, e, custom = currentActivity()
    G.picture:Show(e, custom and 'activities' or U.groupKind:GetText() == 'PVP' and 'pvp' or nil)
    local size = number(fields.size)
    local name = id ~= '' and Z.Locale.Activity(id) or tr('Select activity')
    local facts = name
    if e then
        local zone = C.Zone(e)
        facts = name .. ' · ' .. (e.min == e.max and Z.T('Level %d', e.min) or Z.T('Level %d–%d', e.min, e.max)) .. (zone and ' · ' .. zone or '')
    end
    if form.zenialDialogHeader then
        form.zenialDialogHeader:SetSubtitle(facts)
    end
    G.size:Select(tostring(size))
    G.duration:Select(tostring(number(U.groupTemplateDuration)))
    local wanted = 0
    for _, s in ipairs(G.steppers) do
        local value = number(fields[s.key])
        wanted = wanted + value
        s.value:SetText(tostring(value))
        T.Tint(s.value, 'SetTextColor', value > 0 and 'text' or 'muted')
    end
    for _, s in ipairs(G.steppers) do
        s.minus:SetEnabled(number(fields[s.key]) > 0)
        s.plus:SetEnabled(wanted < size and number(fields[s.key]) < s.limit)
    end
    local here = A.GroupState().total
    G.summary:SetText(Z.T('%d of %d places wanted', wanted, size) .. ' · ' .. (here <= 1 and tr('you are alone') or Z.T('%d players in your group', here)))
    T.Tint(G.summary, 'SetTextColor', wanted > size and 'dangerText' or 'dim')
    -- The composition of the present group only matters once there is one.
    U.groupHaveCaption:SetShown(here > 1)
    U.groupHave:SetShown(here > 1)
end

function U.StyleGroupForm()
    local form, fields = U.groupForm, U.groupFields
    if G.ready or not form or not fields or not U.groupKind or not U.groupTemplateDuration then
        return
    end
    local show = U.Shared.showControl
    -- Head: picture of the activity, category and activity beside it.
    G.picture = F.CreatePicture(form, 34)
    G.picture:Place('TOPLEFT', 16, -70, 150, 84)
    G.pictureEdges = {}
    for _, side in ipairs({ { 'TOPLEFT', 'TOPRIGHT', nil, 1 }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 }, { 'TOPLEFT', 'BOTTOMLEFT', 1, nil }, { 'TOPRIGHT', 'BOTTOMRIGHT', 1, nil } }) do
        local line = form:CreateTexture(nil, 'OVERLAY')
        line:SetPoint(side[1], G.picture.base, side[1])
        line:SetPoint(side[2], G.picture.base, side[2])
        if side[3] then
            line:SetWidth(side[3])
        else
            line:SetHeight(side[4])
        end
        T.Tint(line, 'SetColorTexture', 'edge')
        G.pictureEdges[#G.pictureEdges + 1] = line
    end
    place(U.groupKind.caption, 182, -68, 150, 14)
    place(U.groupKind.button, 182, -86, 150, 26)
    U.groupKind:SetWidth(150)
    place(U.groupActivity.caption, 342, -68, 110, 14)
    place(U.groupActivity.button, 342, -86, 292, 26)
    U.groupActivity:SetWidth(292)
    place(U.groupCustom.caption, 342, -68, 110, 14)
    place(U.groupCustom, 342, -86, 292, 26)
    place(U.groupActivitySearch, 474, -64, 160, 20)
    -- Level range under the selectors.
    place(fields.min.caption, 182, -128, 50, 20)
    place(fields.min, 236, -126, 48, 24)
    place(fields.max.caption, 290, -128, 14, 20)
    place(fields.max, 306, -126, 48, 24)

    -- Size and running time: the usual values as switches, the field beside them for anything else.
    overline(form, 'Group size', 16, -170)
    G.size = K.Segmented(form, { { key = '5', label = '5' }, { key = '10', label = '10' }, { key = '20', label = '20' }, { key = '40', label = '40' } }, function(key)
        fields.size:SetText(key)
        if U.AutofillGroupNeeds then
            U.AutofillGroupNeeds()
        end
        U.CaptureGroupDraft()
    end)
    G.size:SetSegmentWidth(52)
    place(G.size, 16, -186)
    fields.size.caption:Hide()
    place(fields.size, 232, -187, 46, 24)
    G.durationLabel = overline(form, 'Open for (minutes)', 342, -170)
    G.duration = K.Segmented(form, { { key = '30', label = '30' }, { key = '60', label = '60' }, { key = '120', label = '120' }, { key = '240', label = '240' } }, function(key)
        U.groupTemplateDuration:SetText(key)
        U.CaptureGroupDraft()
    end)
    G.duration:SetSegmentWidth(52)
    place(G.duration, 342, -186)
    U.groupTemplateDuration.caption:Hide()
    place(U.groupTemplateDuration, 558, -187, 54, 24)

    -- Wanted roles: counters instead of number fields. The fields stay (hidden) as the values.
    overline(form, 'Wanted roles', 16, -228)
    G.summary = K.Text(form, '', 'caption', 'dim')
    place(G.summary, 234, -227, 400, 14)
    G.summary:SetJustifyH('RIGHT')
    call(G.summary, 'SetWordWrap', false)
    G.steppers = {}
    for index, spec in ipairs(ROLES) do
        local s = createStepper(form, spec[1], spec[2], spec[3])
        place(s, 16 + (index - 1) * 209, -244)
        G.steppers[index] = s
        show(fields[spec[2]], false)
    end

    -- Comment.
    place(fields.note.caption, 16, -294, 300, 14)
    place(U.groupNoteCount, 538, -294, 96, 14)
    U.groupNoteCount:SetJustifyH('RIGHT')
    -- A multi-line edit box takes the height of its text in the client; the field is drawn by a box of fixed
    -- size behind it, and a click anywhere in the box starts typing.
    G.noteBox = CreateFrame('Button', nil, form)
    place(G.noteBox, 16, -312, 618, 40)
    G.noteBox.fill = G.noteBox:CreateTexture(nil, 'BACKGROUND')
    G.noteBox.fill:SetAllPoints()
    T.Tint(G.noteBox.fill, 'SetColorTexture', 'inset')
    G.noteBox.edges = T.Edges(G.noteBox, 'BORDER')
    T.TintEdges(G.noteBox.edges, 'fieldEdge')
    G.noteBox:SetScript('OnClick', function()
        fields.note:SetFocus()
    end)
    fields.note:SetFrameLevel((G.noteBox:GetFrameLevel() or 1) + 1)
    place(fields.note, 16, -312, 618, 40)
    local own = fields.note.zenialField
    if own then
        own.fill:SetAlpha(0)
        for _, edge in pairs(own.edges) do
            edge:SetAlpha(0)
        end
    end
    place(U.groupHaveCaption, 16, -362, 124, 16)
    place(U.groupHave, 142, -362, 492, 28)

    -- Foot: back and discard on the left, template and the one primary action on the right.
    place(U.groupFormBack, 16, -396, 130)
    place(U.groupDiscard, 154, -396, 150)
    place(U.groupTemplateSave, 330, -396, 150)
    place(U.groupSave, 488, -396, 146)

    -- Keep the added widgets in step with the fields.
    local capture = U.CaptureGroupDraft
    U.CaptureGroupDraft = function(...)
        capture(...)
        U.RefreshGroupForm()
    end
    local openEditor = U.OpenGroupEditor
    U.OpenGroupEditor = function(...)
        openEditor(...)
        U.RefreshGroupForm()
    end
    local groupActivity = U.GroupActivity
    U.GroupActivity = function(activity)
        groupActivity(activity)
        applyCatalogue(activity)
        U.RefreshGroupForm()
    end
    local groupKind = U.GroupKind
    U.GroupKind = function(kind, activity)
        groupKind(kind, activity)
        if U.groupKind:GetText() ~= 'CUSTOM' then
            applyCatalogue(U.groupActivity:GetText())
        end
        U.RefreshGroupForm()
    end
    for _, field in ipairs({ fields.size, fields.tank, fields.healer, fields.dd, U.groupTemplateDuration }) do
        if field.HookScript then
            field:HookScript('OnTextChanged', function()
                U.RefreshGroupForm()
            end)
        end
    end
    G.ready = true
    U.RefreshGroupForm()
end

return G
