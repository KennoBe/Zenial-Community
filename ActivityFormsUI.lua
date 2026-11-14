-- Quest request form and scheduled event form of the activity dialog, in the pattern of the group form
-- (GroupFormUI.lua): a head with picture and choice, the few values everybody sets, and "More options" for
-- the rest. The dialogs are as tall as their content.
-- The existing controls stay the data and keep their handlers; this file places them, adds text that is drawn
-- from their values, and replaces the number fields of the event's roles by counters that write into them.
-- Called once from U.CreateCommunityHome after U.StyleGroupForm.
local Z = ZenialCommunity
local U, T, K = Z.UI, Z.Theme, Z.Kit
local C = Z.GroupFinderCatalog
local G = type(U) == 'table' and U.GroupForm
if type(T) ~= 'table' or type(K) ~= 'table' or type(C) ~= 'table' or type(G) ~= 'table' or type(U.Finder) ~= 'table' then
    return
end
local F = U.Finder
local Forms = { quest = { more = false }, event = { more = false } }
U.ActivityForms = Forms

local LEFT, WIDTH = 16, 618
local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local place, overline = G.Place, G.Overline

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
local function number(field)
    return tonumber(field:GetText()) or 0
end
local function text(parent, role, color)
    local fs = K.Text(parent, '', role, color)
    call(fs, 'SetWordWrap', false)
    return fs
end
local function levelText(min, max)
    return min == max and Z.T('Level %d', min) or Z.T('Level %d–%d', min, max)
end
local function pictureFrame(parent, picture)
    for _, side in ipairs({ { 'TOPLEFT', 'TOPRIGHT', nil, 1 }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 }, { 'TOPLEFT', 'BOTTOMLEFT', 1, nil }, { 'TOPRIGHT', 'BOTTOMRIGHT', 1, nil } }) do
        local line = parent:CreateTexture(nil, 'OVERLAY')
        line:SetPoint(side[1], picture.base, side[1])
        line:SetPoint(side[2], picture.base, side[2])
        if side[3] then
            line:SetWidth(side[3])
        else
            line:SetHeight(side[4])
        end
        T.Tint(line, 'SetColorTexture', 'edge')
    end
end
-- Sets the height of a form and of the dialog around it while that form is the one shown.
local function resize(form, height, content)
    form:SetHeight(height)
    if content then
        content:SetHeight(height)
    end
    if U.activityStepBody == form and U.activityCreator then
        U.activityCreator:SetHeight(height)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Quest request
-- ---------------------------------------------------------------------------------------------
local Q = Forms.quest

local function layoutQuest()
    local fields = U.questFields
    local y = -214 -- lower edge of the title field
    y = y - 12
    place(Q.moreButton, LEFT, y, WIDTH, 26)
    y = y - 26
    for _, region in ipairs(Q.optional) do
        region:SetShown(Q.more)
    end
    for _, field in ipairs({ fields.zone, fields.min, U.questDuration }) do
        field.caption:Hide()
    end
    if Q.more then
        y = y - 14
        place(Q.zoneLabel, LEFT, y, 200, 12)
        place(fields.zone, LEFT, y - 18, 230, 24)
        place(Q.levelLabel, 266, y, 120, 12)
        place(fields.min, 266, y - 18, 48, 24)
        place(fields.max.caption, 320, y - 16, 14, 20)
        place(fields.max, 336, y - 18, 48, 24)
        place(Q.durationLabel, 420, y, 214, 12)
        place(U.questDuration, 420, y - 18, 60, 24)
        y = y - 58
        place(fields.note.caption, LEFT, y, 300, 14)
        place(U.questNoteCount, 538, y, 96, 14)
        place(Q.noteBox, LEFT, y - 18, WIDTH, 40)
        place(fields.note, LEFT, y - 18, WIDTH, 40)
        y = y - 58
    end
    y = y - 16
    place(U.questFormBack, LEFT, y, 130)
    place(U.questDiscard, 154, y, 150)
    place(U.questSave, 404, y, 230)
    resize(U.questForm, 26 + 18 - y, U.questFormContent)
end

function U.RefreshQuestForm()
    if not Q.ready then
        return
    end
    local fields = U.questFields
    local title = fields.title:GetText() or ''
    if U.questForm.zenialDialogHeader then
        U.questForm.zenialDialogHeader:SetSubtitle(title ~= '' and title or tr('Quest help or levelling together'))
    end
    local zone = fields.zone:GetText() or ''
    Q.facts:SetText(levelText(number(fields.min), number(fields.max)) .. (zone ~= '' and ' · ' .. zone or ''))
    Q.hint:SetText(Z.T('The request stays open for %d minutes.', number(U.questDuration)))
    local parts = {}
    if (fields.note:GetText() or '') ~= '' then
        parts[1] = tr('Comment')
    end
    Q.moreButton:Set(Q.more, #parts > 0 and table.concat(parts, ' · ') or tr('optional: zone, level, duration, comment'))
    layoutQuest()
end
function U.SetQuestFormMore(open)
    Q.more = open == true
    U.RefreshQuestForm()
end

local function styleQuest()
    local form, content, fields = U.questForm, U.questFormContent, U.questFields
    if Q.ready or not form or not content or not fields or not U.questPicker then
        return
    end
    Q.picture = F.CreatePicture(content, 34)
    Q.picture:Place('TOPLEFT', LEFT, -70, 150, 84)
    Q.picture:Show(nil, 'quests')
    pictureFrame(content, Q.picture)
    -- Head: the quest from the player's log (it brings title, level and zone), search beside it.
    place(U.questPicker.caption, 182, -68, 200, 14)
    place(U.questPicker.button, 182, -86, 452, 26)
    U.questPicker:SetWidth(452)
    U.questPickerSearch.caption:Hide()
    place(U.questPickerSearch, 474, -64, 160, 20)
    Q.searchHint = K.Text(U.questPickerSearch, tr('Search'), 'caption', 'muted')
    Q.searchHint:SetPoint('LEFT', 6, 0)
    U.questPickerSearch:HookScript('OnTextChanged', function(self)
        Q.searchHint:SetShown(self:GetText() == '')
    end)
    Q.facts = text(content, 'body', 'text')
    place(Q.facts, 182, -124, 452, 16)
    Q.hint = text(content, 'caption', 'dim')
    place(Q.hint, 182, -143, 452, 14)
    -- What it is about: filled in by the choice above, or typed.
    fields.title.caption:Hide()
    Q.titleLabel = overline(content, 'What do you need help with?', LEFT, -172, 400)
    place(fields.title, LEFT, -188, WIDTH, 26)
    Q.moreButton = G.CreateMore(content, function()
        U.SetQuestFormMore(not Q.more)
    end)
    Q.zoneLabel = overline(content, 'Zone', LEFT, -266)
    Q.levelLabel = overline(content, 'Level', 266, -266)
    Q.durationLabel = overline(content, 'Duration (minutes)', 420, -266)
    Q.noteBox = G.CreateNoteBox(content, fields.note)
    U.questNoteCount:SetJustifyH('RIGHT')
    Q.optional = { Q.zoneLabel, fields.zone, Q.levelLabel, fields.min, fields.max.caption, fields.max, Q.durationLabel, U.questDuration, fields.note.caption,
        U.questNoteCount, Q.noteBox, fields.note }

    local openEditor = U.OpenQuestEditor
    U.OpenQuestEditor = function(q, ...)
        local draft = not q and Z.UIState and Z.UIState.ActivityInput('quest')
        openEditor(q, ...)
        -- Open the optional part only where it holds something the player wrote.
        Q.more = (fields.note:GetText() or '') ~= '' or draft and draft.more == true or false
        U.RefreshQuestForm()
    end
    local capture = U.CaptureQuestDraft
    U.CaptureQuestDraft = function(...)
        capture(...)
        local draft = U.questEditing and not U.Shared.restoringDraft and Z.UIState and Z.UIState.ActivityInput('quest')
        if draft then
            draft.more = Q.more
        end
        U.RefreshQuestForm()
    end
    -- The fields call the capture that was current when they were built: point them at the new one.
    for _, field in pairs(fields) do
        field:SetScript('OnTextChanged', U.CaptureQuestDraft)
    end
    U.questDuration:SetScript('OnTextChanged', U.CaptureQuestDraft)
    local validate = U.ValidateQuestForm
    U.ValidateQuestForm = function(...)
        local ok = validate(...)
        if not ok and not Q.more then
            U.SetQuestFormMore(true)
        end
        return ok
    end
    Q.ready = true
    U.RefreshQuestForm()
end

-- ---------------------------------------------------------------------------------------------
-- Scheduled event
-- ---------------------------------------------------------------------------------------------
local E = Forms.event

local function layoutEvent()
    local y = -282 -- lower edge of the role counters
    y = y - 12
    place(E.moreButton, LEFT, y, WIDTH, 26)
    y = y - 26
    for _, region in ipairs(E.optional) do
        region:SetShown(E.more)
    end
    U.scheduledDuration.caption:Hide()
    if E.more then
        -- Duration on one line with its name: with the notice below, the dialog has to fit the smallest window.
        y = y - 12
        place(E.durationLabel, LEFT, y - 6, 150, 12)
        place(U.scheduledDuration, LEFT + 150, y, 60, 24)
        y = y - 38
        place(U.scheduledNote.caption, LEFT, y, 300, 14)
        place(U.scheduledNoteCount, 538, y, 96, 14)
        place(E.noteBox, LEFT, y - 18, WIDTH, 40)
        place(U.scheduledNote, LEFT, y - 18, WIDTH, 40)
        y = y - 58
    end
    -- Warning of an edited, published event.
    local notice = (U.scheduledEditorNotice:GetText() or '') ~= ''
    U.scheduledEditorNotice:SetShown(notice)
    if notice then
        place(U.scheduledEditorNotice, LEFT, y - 14, WIDTH, 30)
        y = y - 44
    end
    y = y - 16
    place(U.scheduledBack, LEFT, y, 130)
    place(U.scheduledDiscard, 154, y, 150)
    place(U.scheduledSave, 404, y, 230)
    resize(U.scheduledEditor, 26 + 18 - y)
end

function U.RefreshScheduledForm()
    if not E.ready then
        return
    end
    local form = U.scheduledEditor
    local id = U.scheduledActivity:GetText() or ''
    local kind = U.scheduledKind:GetText()
    local e = kind ~= 'CUSTOM' and C.Get(id) or nil
    E.picture:Show(e, kind == 'PVP' and 'pvp' or kind == 'QUEST' and 'quests' or 'activities')
    if form.zenialDialogHeader then
        form.zenialDialogHeader:SetSubtitle(id ~= '' and Z.Locale.Activity(id) or tr('Select activity'))
    end
    local zone = e and C.Zone(e)
    E.facts:SetText(e and (levelText(e.min, e.max) .. (zone and ' · ' .. zone or '')) or '')
    place(E.hint, 182, e and -143 or -126, 452, 14)
    -- The time as it was understood, or that it cannot be read.
    local at = Z.ScheduleTime.Parse(U.scheduledDate:GetText(), U.scheduledClock:GetText())
    E.when:SetText(at and Z.ScheduleTime.Format(at) or tr('Date or time is not valid'))
    T.Tint(E.when, 'SetTextColor', at and 'textSoft' or 'dangerText')
    local wanted = 0
    for _, s in ipairs(E.steppers) do
        local value = number(U.scheduledSlots[s.role])
        wanted = wanted + value
        s.value:SetText(tostring(value))
        T.Tint(s.value, 'SetTextColor', value > 0 and 'text' or 'muted')
        s.minus:SetEnabled(value > 0)
        s.plus:SetEnabled(value < 40)
    end
    local role = Z.Logic.Role(Z.db.roles)
    E.summary:SetText((role and Z.T('You play %s', Z.Locale.Role(role)) .. ' · ' or '') .. Z.T('%d places wanted', wanted))
    local parts = {}
    if (U.scheduledNote:GetText() or '') ~= '' then
        parts[1] = tr('Comment')
    end
    E.moreButton:Set(E.more, #parts > 0 and table.concat(parts, ' · ') or tr('optional: duration, comment'))
    layoutEvent()
end
function U.SetScheduledFormMore(open)
    E.more = open == true
    U.RefreshScheduledForm()
end

local function styleEvent()
    local form = U.scheduledEditor
    if E.ready or not form or not U.scheduledKind or not U.scheduledSlots or not U.scheduledDatePicker then
        return
    end
    E.picture = F.CreatePicture(form, 34)
    E.picture:Place('TOPLEFT', LEFT, -70, 150, 84)
    pictureFrame(form, E.picture)
    place(U.scheduledKind.caption, 182, -68, 150, 14)
    place(U.scheduledKind.button, 182, -86, 150, 26)
    U.scheduledKind:SetWidth(150)
    place(U.scheduledGoal.caption, 342, -68, 110, 14)
    place(U.scheduledGoal.button, 342, -86, 292, 26)
    U.scheduledGoal:SetWidth(292)
    place(U.scheduledActivity.caption, 342, -68, 110, 14)
    place(U.scheduledActivity, 342, -86, 292, 26)
    place(U.scheduledSearch, 474, -64, 160, 20)
    E.facts = text(form, 'body', 'text')
    place(E.facts, 182, -124, 452, 16)
    E.hint = text(form, 'caption', 'dim')
    E.hint:SetText(tr('Others can sign up once the event is published.'))
    -- When: date and time with their pickers, and the time as it was understood.
    U.scheduledDay.caption:Hide()
    U.scheduledTime.caption:Hide()
    overline(form, 'When', LEFT, -172)
    place(U.scheduledDay, LEFT, -190, 104, 24)
    place(U.scheduledDatePicker, 124, -189, 26, 26)
    place(U.scheduledTime, 162, -190, 58, 24)
    place(U.scheduledTimePicker.button, 224, -189, 26, 26)
    E.when = text(form, 'body', 'textSoft')
    place(E.when, 266, -186, 368, 16)
    -- Wanted roles: counters instead of number fields. The fields stay (hidden) as the values.
    overline(form, 'Wanted roles', LEFT, -228)
    E.summary = text(form, 'caption', 'dim')
    place(E.summary, 204, -227, 430, 14)
    E.summary:SetJustifyH('RIGHT')
    E.steppers = {}
    for index, role in ipairs(ROLES) do
        local field = U.scheduledSlots[role]
        local s = G.CreateStepper(form, role, role, 40, function(delta)
            field:SetText(tostring(math.max(0, math.min(40, number(field) + delta))))
            U.RefreshScheduledForm()
        end)
        s.role = role
        place(s, LEFT + (index - 1) * 209, -244)
        E.steppers[index] = s
        U.Shared.showControl(field, false)
    end
    E.moreButton = G.CreateMore(form, function()
        U.SetScheduledFormMore(not E.more)
    end)
    E.durationLabel = overline(form, 'Duration (minutes)', LEFT, -334)
    E.noteBox = G.CreateNoteBox(form, U.scheduledNote)
    U.scheduledNoteCount:SetJustifyH('RIGHT')
    E.optional = { E.durationLabel, U.scheduledDuration, U.scheduledNote.caption, U.scheduledNoteCount, E.noteBox, U.scheduledNote }

    local openEditor = U.OpenScheduledEditor
    U.OpenScheduledEditor = function(e, ...)
        openEditor(e, ...)
        E.more = (U.scheduledNote:GetText() or '') ~= '' or number(U.scheduledDuration) ~= 120
        U.RefreshScheduledForm()
    end
    local configure = U.ConfigureScheduledActivity
    U.ConfigureScheduledActivity = function(...)
        configure(...)
        U.RefreshScheduledForm()
    end
    for _, field in ipairs({ U.scheduledActivity, U.scheduledDay, U.scheduledTime, U.scheduledDuration, U.scheduledNote, U.scheduledSlots.TANK, U.scheduledSlots.HEALER,
        U.scheduledSlots.DAMAGER }) do
        if field.HookScript then
            field:HookScript('OnTextChanged', function()
                U.RefreshScheduledForm()
            end)
        end
    end
    E.ready = true
    U.RefreshScheduledForm()
end

function U.StyleActivityForms()
    styleQuest()
    styleEvent()
    if Forms.hooked then
        return
    end
    Forms.hooked = true
    local showStep = U.ShowActivityStep
    U.ShowActivityStep = function(step, body, ...)
        showStep(step, body, ...)
        if step == 2 and body == U.questForm and Q.ready then
            layoutQuest()
        elseif step == 2 and body == U.scheduledEditor and E.ready then
            layoutEvent()
        end
    end
end

return Forms
