local Z = ZenialCommunity
local U = Z.UI
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local label, button, edit, selector, list, rows, roleName = S.label, S.button, S.edit, S.selector, S.list, S.rows, S.roleName
local activityName = S.activityName

local function wanted(g)
    local a = {}
    if g.tank > 0 then
        a[#a + 1] = g.tank .. ' ' .. roleName('TANK')
    end
    if g.healer > 0 then
        a[#a + 1] = g.healer .. ' ' .. roleName('HEALER')
    end
    if g.dd > 0 then
        a[#a + 1] = g.dd .. ' ' .. roleName('DAMAGER')
    end
    return table.concat(a, ', ')
end
S.wanted = wanted
local sessionRestoring = false
function U.MarkSessionDraft()
    if sessionRestoring then
        return
    end
    U.sessionDirty = true
    if U.sessionEditStatus then
        U.sessionEditStatus:SetText(tr('Unsaved changes'))
    end
end
function U.ConfigureSessionWish(index, kind, selection)
    local row = U.sessionRows[index]
    local choices = {}
    local choose = kind == 'QUEST' or Z.GroupFinder.Activities[kind] ~= nil
    if kind == 'QUEST' then
        choices[1] = 'ANY_QUEST'
        local seen = {}
        for _, quest in ipairs(Z.QuestHelper.quests or {}) do
            local value = 'Q:' .. quest.id
            choices[#choices + 1] = value
            seen[value] = true
        end
        if selection and selection:match('^Q:%d+$') and not seen[selection] then
            choices[#choices + 1] = selection
        end
    elseif choose then
        choices = Z.GroupFinder.Activities[kind]
    end
    row.target:SetOptions(choices, selection)
    row.target:SetShown(choose)
    local text = kind == 'FARM' or kind == 'CUSTOM'
    row.text:SetShown(text)
    row.text.caption:SetShown(text)
    row.hint:Hide()
end
function U.SetSessionWishKind(index, kind)
    sessionRestoring = true
    local row = U.sessionRows[index]
    row.kind:SetText(kind)
    row.text:SetText('')
    U.ConfigureSessionWish(index, kind)
    sessionRestoring = false
    U.MarkSessionDraft()
end
function U.LoadSessionEditor()
    if not U.sessionDuration then
        return
    end
    sessionRestoring = true
    local P = Z.SessionPlans
    local store = P.store or { duration = P.DEFAULT_MINUTES, wishes = {} }
    local byPriority = {}
    for _, wish in ipairs(store.wishes) do
        byPriority[wish.priority] = wish
    end
    for index, row in ipairs(U.sessionRows) do
        local wish = byPriority[index]
        local kind = wish and wish.kind or 'NONE'
        row.kind:SetText(kind)
        row.text:SetText(wish and wish.label or '')
        local target = wish and (wish.kind == 'QUEST' and (wish.targetID == 0 and 'ANY_QUEST' or 'Q:' .. wish.targetID) or wish.activity)
        U.ConfigureSessionWish(index, kind, target)
    end
    U.sessionDuration:SetText(tostring(store.duration))
    U.sessionEditorRevision = P.revision
    U.sessionDirty = false
    sessionRestoring = false
end
function U.SaveSessionPlans()
    local minutes = nil -- The UI saves wishes for this local calendar day.
    local wishes = {}
    for index, row in ipairs(U.sessionRows) do
        local kind = row.kind:GetText()
        if kind ~= 'NONE' then
            local value = row.target:GetText()
            if kind == 'QUEST' and value ~= 'ANY_QUEST' and not value:match('^Q:%d+$') then
                U.sessionEditStatus:SetText(tr('Quest ID is invalid.'))
                return
            end
            wishes[#wishes + 1] = {
                kind = kind,
                priority = index,
                targetID = kind == 'QUEST' and (value == 'ANY_QUEST' and 0 or tonumber(value:match('^Q:(%d+)$'))) or 0,
                activity = Z.GroupFinder.Activities[kind] and value or '',
                label = row.text:GetText() or '',
            }
        end
    end
    local ok, reason = Z.SessionPlans.Save(wishes, minutes)
    if not ok then
        U.sessionEditStatus:SetText(tr(reason))
        return
    end
    U.sessionDirty = false
    U.sessionMemberKey = nil
    U.LoadSessionEditor()
    U.RefreshSessionPlans()
    if U.RefreshCommunityHome then
        U.RefreshCommunityHome()
    end
    U.sessionEditStatus:SetText(tr('Private wishes saved.'))
end
function U.RefreshSessionPlans()
    if not U.sessionMemberList or not U.sessionDuration then
        return
    end
    local P = Z.SessionPlans
    if not U.sessionDirty and U.sessionEditorRevision ~= P.revision then
        U.LoadSessionEditor()
    end
    local state = P.State()
    local message = state == 'active'
            and (P.store.mode == 'DAY' and Z.T('%d private wishes for today', #P.store.wishes) or Z.T(
                '%d private wishes · %d min remaining',
                #P.store.wishes,
                math.ceil((P.store.expiresAt - A.Now()) / 60)
            ))
        or state == 'expired' and tr('Session expired. Save explicitly to start again.')
        or state == 'unsupported' and tr('Saved session wishes use an unsupported version. Data was preserved.')
        or state == 'unknown' and tr('Server time is unavailable.')
        or tr('No session wishes saved.')
    U.sessionState:SetText(message)
    U.sessionSave:SetEnabled(P.store ~= nil)
    U.sessionEnd:SetEnabled(P.store ~= nil and #P.store.wishes > 0)
    if not U.sessionDirty then
        U.sessionEditStatus:SetText(P.loadError == 'invalid' and tr('Saved session wishes were invalid and could not be restored.') or '')
    end
    local matches, meta = P.BuildMatches()
    local display, chosen = {}, nil
    for _, entry in ipairs(matches) do
        local key = entry.key
        local level = entry.level and entry.level > 0 and tostring(entry.level) or tr('Unknown')
        display[#display + 1] = {
            selected = key == U.sessionMemberKey,
            icon = T and T.ClassIcon(entry.classFile),
            text = entry.target .. ' · ' .. tr('Level') .. ' ' .. level .. '\n' .. tr(entry.status),
            tooltip = entry.target .. '\n' .. table.concat(entry.reasons, '\n'),
            click = function()
                U.sessionMemberKey = key
                U.RefreshSessionPlans()
            end,
        }
        if key == U.sessionMemberKey then
            chosen = entry
        end
    end
    U.SetEmptyHint(U.sessionMemberList, 'No matching members. Save a session wish above so players can be matched.')
    rows(U.sessionMemberList, display, 50)
    U.sessionMatchStatus:SetText(
        meta.exchange == false and tr('Matching requires addon exchange. Wishes stay private.')
            or (meta.pending or 0) > 0 and Z.T('%d matches · %d contacts left to check', #matches, meta.pending)
            or #matches > 0 and Z.T('%d matching members', #matches)
            or tr('No verified matches in the considered candidates.')
    )
    U.sessionInvite:SetEnabled(false)
    U.sessionWhisper:SetEnabled(false)
    U.sessionOffer:SetEnabled(false)
    if not chosen then
        U.sessionMemberKey = nil
        rows(U.sessionReasons, { { text = tr('Select a member to see the evidence.') } }, 44)
        return
    end
    local reasons = {}
    for _, reason in ipairs(chosen.reasons) do
        reasons[#reasons + 1] = { text = reason, height = math.max(32, math.ceil(#reason / 45) * 16 + 12), tooltip = reason }
    end
    rows(U.sessionReasons, reasons, 44)
    local canInvite, reason = P.CanInvite(chosen.key)
    U.sessionInvite:SetEnabled(canInvite)
    U.sessionWhisper:SetEnabled(true)
    U.sessionOffer:SetEnabled(chosen.groupID ~= nil)
    if not canInvite then
        reasons[#reasons + 1] = { text = tr(reason), height = 44 }
        rows(U.sessionReasons, reasons, 44)
    end
end
function U.CreateSessionPlans(parent)
    local P = Z.SessionPlans
    local f = CreateFrame('Frame', nil, parent)
    U.sessionPlanFrame = f
    f:SetPoint('TOPLEFT', 0, -36)
    f:SetSize(856, 414)
    label(f, 'What shall we do today?', 0, 0, 408, 'GameFontHighlight'):SetHeight(22)
    U.sessionState = label(f, '', 0, -27, 408)
    U.sessionState:SetHeight(38)
    U.sessionMatchStatus = label(f, '', 426, 0, 420)
    U.sessionMatchStatus:SetHeight(24)
    U.sessionMemberList = list(f, 426, -30, 420, 178)
    U.sessionReasons = list(f, 426, -218, 420, 136)
    U.sessionRows = {}
    for index = 1, P.MAX_WISHES do
        local number = index
        local y = -78 - (index - 1) * 75
        local row = {}
        U.sessionRows[index] = row
        row.kind = selector(
            f,
            Z.T('Priority %d', index),
            0,
            y,
            120,
            { 'NONE', 'QUEST', 'DUNGEON', 'RAID', 'PVP', 'FARM', 'LEVEL', 'CUSTOM' },
            function(kind)
                U.SetSessionWishKind(number, kind)
            end,
            P.KindLabel
        )
        row.target = selector(f, 'Goal', 130, y, 278, {}, U.MarkSessionDraft, function(value)
            if value == 'ANY_QUEST' then
                return tr('Any shared quests')
            end
            local id = tonumber(value:match('^Q:(%d+)$'))
            return id and P.WishLabel({ kind = 'QUEST', targetID = id }) or activityName(value)
        end)
        row.text = edit(f, 'Activity / material (private)', 130, y, 278, 96)
        row.text:SetScript('OnTextChanged', U.MarkSessionDraft)
        row.hint = label(f, '', 130, y - 20, 278)
        row.hint:SetHeight(32)
    end
    U.sessionDuration = edit(f, 'Duration (minutes)', 0, -314, 110, 3)
    U.sessionDuration:SetScript('OnTextChanged', U.MarkSessionDraft)
    U.sessionSave = button(f, 'Save', 120, -332, 110, U.SaveSessionPlans, 'primary')
    U.sessionEnd = button(f, 'End session', 240, -332, 165, function()
        local ok, reason = P.End()
        if not ok then
            U.Message(reason)
            return
        end
        U.sessionDirty = false
        U.sessionMemberKey = nil
        U.LoadSessionEditor()
        U.RefreshSessionPlans()
        if U.RefreshCommunityHome then
            U.RefreshCommunityHome()
        end
    end, 'danger')
    U.sessionEditStatus = label(f, '', 0, -370, 408)
    U.sessionEditStatus:SetHeight(36)
    U.sessionInvite = button(f, 'Invite', 426, -366, 140, function()
        local ok, reason = P.Invite(U.sessionMemberKey)
        U.Message(ok and tr('Invitation submitted; awaiting response.') or tr(reason))
        U.RefreshSessionPlans()
    end)
    U.sessionWhisper = button(f, 'Whisper', 576, -366, 140, function()
        local ok, reason = P.Whisper(U.sessionMemberKey)
        if not ok then
            U.Message(tr(reason))
        end
        U.RefreshSessionPlans()
    end)
    U.sessionOffer = button(f, 'Open offer', 726, -366, 120, function()
        local match = P.Match(U.sessionMemberKey)
        if not match or not match.groupID then
            U.Message(tr('Session match no longer available.'))
            U.RefreshSessionPlans()
            return
        end
        if U.Navigate('groups', 'browse') then
            U.SelectGroup(match.key, match.groupID)
        end
    end)
    U.LoadSessionEditor()
    f:Hide()
end
