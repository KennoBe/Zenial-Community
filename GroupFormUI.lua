-- Group form of the activity dialog: few decisions first, everything else on request.
-- Simple view: picture and activity, the facts the catalogue brings (level range, size, zone) and the wanted
-- roles as counters, filled in for the group size, the player's own role and the present group. That is enough
-- to publish.
-- "More options" opens what most players never change: level range, group size, preferred classes, comment and
-- saving as a template. It is closed for a new group and opens by itself when a group already holds such values,
-- so nothing that is set stays hidden. The dialog is as tall as its content.
-- A group has no running time to choose: it stays open until its leader goes offline (GroupFinderCatalog, C.Resume).
-- The existing controls stay the data: every switch and counter writes into the edit box that already holds
-- the value (U.groupFields.*), so validation, drafts, templates and publishing are untouched. Preferred classes
-- have no field of their own; they travel behind the present roles (GroupFinderCatalog, C.JoinHave).
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
local LEFT, WIDTH = 16, 618
G.classes = {} -- preferred classes: token -> true
G.more = false -- whether the optional part is open

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
local function textWidth(fs, value)
    local ok, width = call(fs, 'GetStringWidth')
    if ok and type(width) == 'number' and width > 0 then
        return width
    end
    -- Without a measuring font string (test mock): about 6 px per character.
    return #tostring(value or ''):gsub('[\128-\191]', '') * 6
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

-- Preferred classes ------------------------------------------------------------------------------------------
local function classList()
    local out = {}
    for _, class in ipairs(C.CLASSES) do
        if G.classes[class] then
            out[#out + 1] = class
        end
    end
    return out
end
local function className(class, colored)
    local name = Z.Locale.Class(nil, class)
    local hex = colored and T.ClassColorHex(class)
    return hex and ('|cff' .. hex .. name .. '|r') or name
end
-- Present roles plus preferred classes, as the record stores them.
function G.Have()
    return C.JoinHave(A.GroupRoles(), classList())
end
function U.ToggleGroupFormClass(class)
    G.classes[class] = not G.classes[class] or nil
    U.CaptureGroupDraft()
end

-- Whether the form holds values of the optional part: a comment, preferred classes, or a level range or size
-- other than the activity's own.
function G.HasExtras()
    local fields = U.groupFields
    if next(G.classes) or (fields.note:GetText() or '') ~= '' then
        return true
    end
    local _, e = currentActivity()
    return e ~= nil and (number(fields.min) ~= e.min or number(fields.max) ~= e.max or number(fields.size) ~= e.size)
end
function U.SetGroupFormMore(open)
    G.more = open == true
    U.CaptureGroupDraft()
end
-- After values were filled in from outside (finder): open the optional part only if something in it is set.
function G.Reset()
    U.SetGroupFormMore(G.HasExtras())
end

-- Wanted roles ---------------------------------------------------------------------------------------------
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

-- Counter for one role: symbol, name, minus, value, plus. onBump(delta) changes the value behind it.
local function createStepper(parent, role, key, limit, onBump)
    onBump = onBump or function(delta)
        bump(key, delta, limit)
    end
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
        onBump(1)
    end, 'secondary')
    s.plus:SetPoint('RIGHT', -6, 0)
    s.value = K.Text(s, '0', 'title', 'text')
    s.value:SetPoint('RIGHT', -36, 0)
    s.value:SetWidth(34)
    s.value:SetHeight(18)
    s.value:SetJustifyH('CENTER')
    s.minus = T.Button(s, '-', 26, 26, function()
        onBump(-1)
    end, 'secondary')
    s.minus:SetPoint('RIGHT', -74, 0)
    s.key, s.limit = key, limit
    return s
end
G.CreateStepper = createStepper

-- Switch that opens and closes the optional part of a form: arrow, name, and on the right what is set while
-- it is closed. button:Set(open, summary).
local function createMore(parent, onClick)
    local button = T.Button(parent, tr('More options'), WIDTH, 26, onClick, 'secondary')
    button.chevron = K.Icon(button, 'chevronRight', 12, 'dim')
    button.chevron:SetPoint('LEFT', 10, 0)
    if T.AlignButtonText then
        T.AlignButtonText(button, 30, 8)
    end
    button.summary = K.Text(button, '', 'caption', 'dim')
    button.summary:SetPoint('RIGHT', -10, 0)
    button.summary:SetWidth(400)
    button.summary:SetHeight(14)
    button.summary:SetJustifyH('RIGHT')
    call(button.summary, 'SetWordWrap', false)
    function button:Set(open, summary)
        T.SetIcon(self.chevron, open and 'chevronDown' or 'chevronRight', 'dim')
        self.summary:SetText(open and '' or summary or '')
    end
    return button
end
G.CreateMore = createMore

-- A multi-line edit box takes the height of its text in the client; the field is drawn by a box of fixed
-- size behind it, and a click anywhere in the box starts typing.
local function createNoteBox(parent, field)
    local box = CreateFrame('Button', nil, parent)
    box.fill = box:CreateTexture(nil, 'BACKGROUND')
    box.fill:SetAllPoints()
    T.Tint(box.fill, 'SetColorTexture', 'inset')
    box.edges = T.Edges(box, 'BORDER')
    T.TintEdges(box.edges, 'fieldEdge')
    box:SetScript('OnClick', function()
        field:SetFocus()
    end)
    field:SetFrameLevel((box:GetFrameLevel() or 1) + 1)
    local own = field.zenialField
    if own then
        own.fill:SetAlpha(0)
        for _, edge in pairs(own.edges) do
            edge:SetAlpha(0)
        end
    end
    return box
end
G.CreateNoteBox = createNoteBox
G.Overline, G.Place = overline, place

-- Layout: everything below the head depends on whether the player is in a group and whether the optional part
-- is open. Returns nothing; sets the height of the form and of the dialog around it.
local function layout()
    local form, fields = U.groupForm, U.groupFields
    local more = G.more
    local party = A.GroupState().total > 1
    local y = -226 -- lower edge of the role counters
    -- The present group only matters once there is one.
    U.groupHaveCaption:SetShown(party)
    U.groupHave:SetShown(party)
    if party then
        place(U.groupHaveCaption, LEFT, y - 8, 124, 16)
        place(U.groupHave, 142, y - 8, 492, 28)
        y = y - 36
    end
    y = y - 12
    place(G.moreButton, LEFT, y, WIDTH, 26)
    y = y - 26
    for _, region in ipairs(G.optional) do
        region:SetShown(more)
    end
    fields.min.caption:Hide()
    fields.size.caption:Hide()
    if more then
        y = y - 14
        place(G.levelLabel, LEFT, y, 150, 12)
        place(fields.min, LEFT, y - 18, 48, 24)
        place(fields.max.caption, LEFT + 54, y - 16, 14, 20)
        place(fields.max, LEFT + 70, y - 18, 48, 24)
        place(G.sizeLabel, 182, y, 200, 12)
        place(G.size, 182, y - 17)
        place(fields.size, 398, y - 18, 46, 24)
        y = y - 58
        place(G.classLabel, LEFT, y, 200, 12)
        place(G.classHint, 234, y + 1, 400, 14)
        y = y - 18
        -- One row where the names fit (the padding takes what is left); otherwise the chips wrap.
        local text = 0
        for _, chip in ipairs(G.chips) do
            text = text + chip.zenialText
        end
        local pad = math.floor((WIDTH - 3 * (#G.chips - 1) - text) / #G.chips)
        local oneRow = pad >= 12
        pad = oneRow and math.min(pad, 28) or 18
        local x, inRow = LEFT, 0
        for _, chip in ipairs(G.chips) do
            local width = chip.zenialText + pad
            -- Two rows are split evenly, so no single chip is left over.
            if x > LEFT and (x + width > LEFT + WIDTH or not oneRow and inRow >= math.ceil(#G.chips / 2)) then
                x, y, inRow = LEFT, y - 28, 0
            end
            place(chip, x, y, width, 24)
            x, inRow = x + width + 3, inRow + 1
        end
        y = y - 24 - 14
        place(fields.note.caption, LEFT, y, 300, 14)
        place(U.groupNoteCount, 538, y, 96, 14)
        place(G.noteBox, LEFT, y - 18, WIDTH, 40)
        place(fields.note, LEFT, y - 18, WIDTH, 40)
        y = y - 58
    end
    y = y - 16
    -- Foot: back and discard on the left, the one primary action on the right; saving a template belongs to
    -- the optional part.
    place(U.groupFormBack, LEFT, y, 130)
    place(U.groupDiscard, 154, y, 150)
    place(U.groupTemplateSave, 330, y, 150)
    U.groupTemplateSave:SetShown(more and not U.groupEditID)
    place(U.groupSave, 488, y, 146)
    local height = 26 + 18 - y
    form:SetHeight(height)
    if U.activityStepBody == form and U.activityCreator then
        U.activityCreator:SetHeight(height)
    end
    G.height = height
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
    if form.zenialDialogHeader then
        form.zenialDialogHeader:SetSubtitle(name)
    end
    -- Facts of the activity as text; the fields behind them are in the optional part.
    local min, max = number(fields.min), number(fields.max)
    local zone = e and C.Zone(e)
    G.facts:SetText((min == max and Z.T('Level %d', min) or Z.T('Level %d–%d', min, max)) .. ' · ' .. Z.T('%d players', size) .. (zone and ' · ' .. zone or ''))
    G.size:Select(tostring(size))
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
    -- What is there already: the group, or the player and the role they play.
    local here = A.GroupState().total
    local role = Z.Logic.Role(Z.db.roles)
    local present = here > 1 and Z.T('%d players in your group', here) or role and Z.T('You play %s', Z.Locale.Role(role)) or tr('you are alone')
    G.summary:SetText(present .. ' · ' .. Z.T('%d of %d places wanted', wanted, size))
    T.Tint(G.summary, 'SetTextColor', wanted > size and 'dangerText' or 'dim')
    -- Optional part: the switch says what is set while it is closed.
    local chosen = classList()
    for _, chip in ipairs(G.chips) do
        chip:SetChecked(G.classes[chip.zenialClass] == true)
    end
    local parts = {}
    if #chosen > 0 then
        local names = {}
        for index, class in ipairs(chosen) do
            names[index] = className(class, true)
        end
        parts[#parts + 1] = table.concat(names, ', ')
    end
    if (fields.note:GetText() or '') ~= '' then
        parts[#parts + 1] = tr('Comment')
    end
    G.moreButton:Set(G.more, #parts > 0 and table.concat(parts, ' · ') or tr('optional: level, size, classes, comment'))
    layout()
end

function U.StyleGroupForm()
    local form, fields = U.groupForm, U.groupFields
    if G.ready or not form or not fields or not U.groupKind or not U.groupTemplateDuration then
        return
    end
    local show = U.Shared.showControl
    -- Head: picture of the activity, category and activity beside it, the facts below.
    G.picture = F.CreatePicture(form, 34)
    G.picture:Place('TOPLEFT', LEFT, -70, 150, 84)
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
    G.facts = K.Text(form, '', 'body', 'text')
    place(G.facts, 182, -124, 452, 16)
    call(G.facts, 'SetWordWrap', false)
    G.durationHint = K.Text(form, tr('Stays open until you go offline.'), 'caption', 'dim')
    place(G.durationHint, 182, -143, 452, 14)
    call(G.durationHint, 'SetWordWrap', false)
    show(U.groupTemplateDuration, false)

    -- Wanted roles: counters instead of number fields. The fields stay (hidden) as the values.
    overline(form, 'Wanted roles', LEFT, -172)
    G.summary = K.Text(form, '', 'caption', 'dim')
    place(G.summary, 204, -171, 430, 14)
    G.summary:SetJustifyH('RIGHT')
    call(G.summary, 'SetWordWrap', false)
    G.steppers = {}
    for index, spec in ipairs(ROLES) do
        local s = createStepper(form, spec[1], spec[2], spec[3])
        place(s, LEFT + (index - 1) * 209, -188)
        G.steppers[index] = s
        show(fields[spec[2]], false)
    end

    -- Switch for the optional part.
    G.moreButton = createMore(form, function()
        U.SetGroupFormMore(not G.more)
    end)

    -- Optional part. G.optional lists what is only shown while it is open.
    G.levelLabel = overline(form, 'Level', LEFT, -280)
    G.sizeLabel = overline(form, 'Group size', 182, -280)
    G.size = K.Segmented(form, { { key = '5', label = '5' }, { key = '10', label = '10' }, { key = '20', label = '20' }, { key = '40', label = '40' } }, function(key)
        fields.size:SetText(key)
        if U.AutofillGroupNeeds then
            U.AutofillGroupNeeds()
        end
        U.CaptureGroupDraft()
    end)
    G.size:SetSegmentWidth(52)
    G.classLabel = overline(form, 'Preferred classes', LEFT, -338)
    G.classHint = K.Text(form, tr('No selection: every class is welcome'), 'caption', 'dim')
    G.classHint:SetJustifyH('RIGHT')
    call(G.classHint, 'SetWordWrap', false)
    G.chips = {}
    for index, class in ipairs(C.CLASSES) do
        -- Measured with the plain name, shown in the class colour.
        local chip = T.Chip(form, className(class), 60, 24, function()
            U.ToggleGroupFormClass(class)
        end)
        chip.zenialClass = class
        chip.zenialText = math.ceil(textWidth(chip.text, className(class)))
        chip.text:SetText(className(class, true))
        -- Nine names in one row: a little less room beside the text than a chip has by default.
        chip.text:ClearAllPoints()
        chip.text:SetPoint('LEFT', 5, 0)
        chip.text:SetPoint('RIGHT', -5, 0)
        G.chips[index] = chip
    end
    G.noteBox = createNoteBox(form, fields.note)
    place(G.noteBox, LEFT, -400, WIDTH, 40)
    place(fields.note, LEFT, -400, WIDTH, 40)
    U.groupNoteCount:SetJustifyH('RIGHT')
    G.optional = { G.levelLabel, fields.min, fields.max.caption, fields.max, G.sizeLabel, G.size, fields.size, G.classLabel, G.classHint, fields.note.caption,
        U.groupNoteCount, G.noteBox, fields.note }
    for _, chip in ipairs(G.chips) do
        G.optional[#G.optional + 1] = chip
    end

    -- Keep the added widgets in step with the fields. The draft of the dialog also keeps the preferred classes
    -- and whether the optional part is open.
    local capture = U.CaptureGroupDraft
    U.CaptureGroupDraft = function(...)
        capture(...)
        local draft = U.groupEditing and not U.Shared.restoringDraft and Z.UIState and Z.UIState.ActivityInput('group')
        if draft then
            draft.classes = C.JoinHave('', classList())
            draft.more = G.more
        end
        U.RefreshGroupForm()
    end
    local openEditor = U.OpenGroupEditor
    U.OpenGroupEditor = function(g, ...)
        local draft = not g and Z.UIState and Z.UIState.ActivityInput('group')
        local classes = g and C.WantedClasses(g) or draft and select(2, C.SplitHave(draft.classes)) or {}
        G.classes = {}
        for _, class in ipairs(classes) do
            G.classes[class] = true
        end
        G.more = draft and draft.more == true or false
        openEditor(g, ...)
        if g then
            -- A template is opened to be changed and saved again: that action sits in the optional part.
            G.more = G.HasExtras() or g.templateName ~= nil
        end
        U.RefreshGroupForm()
    end
    local showStep = U.ShowActivityStep
    U.ShowActivityStep = function(step, body, ...)
        showStep(step, body, ...)
        if step == 2 and body == form then
            layout()
        end
    end
    local validate = U.ValidateGroupForm
    U.ValidateGroupForm = function(...)
        local ok = validate(...)
        -- A value that does not pass sits in the optional part: show it.
        if not ok and not G.more then
            U.SetGroupFormMore(true)
        end
        return ok
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
    for _, field in ipairs({ fields.size, fields.tank, fields.healer, fields.dd, fields.min, fields.max, fields.note }) do
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
