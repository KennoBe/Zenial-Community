local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local H = Z.History
local T = Z.Theme
local I = Z.Locale
local S = U.Shared
local tr = S.tr
local NAV_ICONS, DUNGEONS, RAIDS, PVP, RAID_SIZE = S.NAV_ICONS, S.DUNGEONS, S.RAIDS, S.PVP, S.RAID_SIZE
local canonicalOption, selectNav, updateNavPath, rows, keys = S.canonicalOption, S.selectNav, S.updateNavPath, S.rows, S.keys
local peerOnline, roleName, activityName, activityCategory = S.peerOnline, S.roleName, S.activityName, S.activityCategory
local groupCategory, stateName, groupHave, deliveryState = S.groupCategory, S.stateName, S.groupHave, S.deliveryState
local peerLocationLine, wanted = S.peerLocationLine, S.wanted

local function foreignGroups()
    local a = {}
    for key, p in pairs(Z.db.peers) do
        if peerOnline(key) and Z.db.contacts[key] and p.data then
            local g = p.data.group or p.data.lfg and p.data.lfg[1]
            if g and g.expires > A.Now() then
                a[#a + 1] = { key = key, target = Z.db.contacts[key].target, g = g }
            end
        end
    end
    table.sort(a, function(x, y)
        return activityName(x.g.activity) < activityName(y.g.activity)
    end)
    return a
end
local function groupFilterActivities(kind, groups)
    local values, seen = { 'ALL_ACTIVITIES' }, { ALL_ACTIVITIES = true }
    local function add(v)
        if v and v ~= '' and not seen[v] then
            seen[v] = true
            values[#values + 1] = v
        end
    end
    local function addAll(source)
        for _, v in ipairs(source) do
            add(v)
        end
    end
    if kind == 'ALL_CATEGORIES' or kind == 'PVP' then
        addAll(PVP)
    end
    if kind == 'ALL_CATEGORIES' or kind == 'DUNGEON' then
        addAll(DUNGEONS)
    end
    if kind == 'ALL_CATEGORIES' or kind == 'RAID' then
        addAll(RAIDS)
    end
    if kind == 'ALL_CATEGORIES' or kind == 'CUSTOM' then
        for _, x in ipairs(groups or foreignGroups()) do
            local id = L.ActivityID(x.g.activity)
            if groupCategory(id) == 'CUSTOM' then
                add(id)
            end
        end
    end
    return values
end
local function selectedGroup()
    return U.groupKey and Z.FindForeignGroup(U.groupKey, U.groupID)
end
function U.SelectGroup(key, id)
    Z.Notifications.ReadVisible('groups', 'browse', 'follow:' .. key .. ':' .. id)
    U.groupKey, U.groupID = key, id
    U.groupApplyOpen = false
    U.groupApplyFrame:Hide()
    S.refreshGroupBrowse()
    U.OpenCompactArea('groups')
end
function U.SetGroupFilterKind(kind)
    kind = canonicalOption(kind)
    if not U.groupFilterActivity then
        return
    end
    U.groupFilterKind:SetText(kind)
    U.groupFilterActivity:SetOptions(groupFilterActivities(kind), 'ALL_ACTIVITIES')
    S.refreshGroupBrowse()
end
S.refreshGroupBrowse = function()
    local groups = foreignGroups()
    local kind = U.groupFilterKind and U.groupFilterKind:GetText() or 'ALL_CATEGORIES'
    local activity = U.groupFilterActivity and U.groupFilterActivity:GetText() or 'ALL_ACTIVITIES'
    local query = string.lower(U.groupFilterSearch and U.groupFilterSearch:GetText() or '')
    local current = U.groupFilterActivity and U.groupFilterActivity:GetText()
    if U.groupFilterActivity then
        U.groupFilterActivity:SetOptions(groupFilterActivities(kind, groups), current)
        activity = U.groupFilterActivity:GetText()
    end
    local items, selectionVisible = {}, false
    for _, x in ipairs(groups) do
        local g = x.g
        local activityID = L.ActivityID(g.activity)
        local name = activityName(activityID)
        local matchesKind = kind == 'ALL_CATEGORIES' or groupCategory(activityID) == kind
        local matchesActivity = activity == 'ALL_ACTIVITIES' or activityID == activity
        local matchesNote = query == '' or string.lower(g.note or ''):find(query, 1, true)
        local peer = Z.db.peers[x.key]
        local availability = peer and peer.presence and peer.presence.availability or 'AVAILABLE'
        local levelOK = not U.groupMatchLevel or not U.groupMatchLevel:GetChecked() or Z.me.level >= g.min and Z.me.level <= g.max
        local role = Z.db.roles
        local roleOK = not U.groupMatchRole or not U.groupMatchRole:GetChecked() or role ~= '' and Z.GroupFinder.Matches(g, nil, role)
        local availableOK = not U.groupMatchAvailable or not U.groupMatchAvailable:GetChecked() or availability == 'AVAILABLE'
        if matchesKind and matchesActivity and matchesNote and levelOK and roleOK and availableOK then
            local key, id = x.key, g.id
            if key == U.groupKey and id == U.groupID then
                selectionVisible = true
            end
            items[#items + 1] = {
                selected = key == U.groupKey and id == U.groupID,
                icon = NAV_ICONS.groups,
                text = '|cffffd36b'
                    .. name
                    .. '|r\n'
                    .. x.target
                    .. ' · Level '
                    .. g.min
                    .. '–'
                    .. g.max
                    .. ' · '
                    .. availability
                    .. '\n'
                    .. peerLocationLine(key, 'Leader location')
                    .. '\n'
                    .. (I.isGerman and 'Gesucht: ' or 'Needed: ')
                    .. wanted(g),
                click = function()
                    U.SelectGroup(key, id)
                end,
            }
        end
    end
    if U.groupKey and not selectionVisible then
        U.groupKey, U.groupID = nil, nil
        U.groupApplyOpen = false
    end
    U.SetEmptyHint(U.groupBrowseList, 'No open groups match. Change the filters or create your own group under My Group.')
    rows(U.groupBrowseList, items, 80)
    if U.groupBrowseCount then
        U.groupBrowseCount:SetText(
            #items == 1 and (I.isGerman and tr('1 offene Gruppe') or '1 open group')
                or #items .. (I.isGerman and tr(' offene Gruppen') or ' open groups')
        )
    end
    local g = selectedGroup()
    if not g then
        U.groupKey, U.groupID = nil, nil
        local missingRole = U.groupMatchRole and U.groupMatchRole:GetChecked() and Z.db.roles == ''
        U.groupBrowseDetail:SetText(
            missingRole and tr('Choose a preferred role in your profile to use the role filter.') or tr('Wähle eine Gruppe aus.')
        )
        U.groupApplyStart:Hide()
        U.groupWithdraw:Hide()
        U.groupBrowseWhisper:Hide()
        U.groupApplyFrame:Hide()
        U.groupApplyState:SetText('')
        return
    end
    local c = Z.db.contacts[U.groupKey]
    U.groupBrowseDetail:SetText(
        '|cffffd36b'
            .. activityName(g.activity)
            .. '|r\n'
            .. (c and c.target or U.groupKey)
            .. ' · Level '
            .. g.min
            .. '–'
            .. g.max
            .. '\n'
            .. peerLocationLine(U.groupKey, 'Leader current location')
            .. '\n'
            .. (I.isGerman and tr('Zielgröße: ') or 'Target size: ')
            .. g.size
            .. (I.isGerman and ' · Vorhanden: ' or ' · Current: ')
            .. groupHave(g.have)
            .. '\n'
            .. (I.isGerman and 'Gesucht: ' or 'Needed: ')
            .. wanted(g)
            .. (g.note ~= '' and '\n\n' .. g.note or '')
    )
    U.groupBrowseWhisper:Show()
    local sent = Z.db.sentApplications[g.id] and Z.db.sentApplications[g.id][U.groupKey]
    U.groupApplyState:SetText(sent and tr('Status') .. ': ' .. stateName(sent.state) or '')
    local active = sent and (sent.state == 'applied' or sent.state == 'invited')
    U.groupApplyStart:SetShown(not active and not U.groupApplyOpen and (not sent or sent.state == 'withdrawn'))
    U.groupWithdraw:SetShown(active)
    U.groupApplyFrame:SetShown(U.groupApplyOpen and not active)
end
S.refreshGroupOutgoing = function()
    if not U.groupOutgoingList then
        return
    end
    local items, selected = {}, false
    for id, people in pairs(Z.db.sentApplications or {}) do
        for key, row in pairs(people) do
            local peer = Z.db.peers[key]
            local current = peer and peer.data and peer.data.group
            local content = current and current.id == id and activityName(current.activity) or H.FindContent('group', id, key)
            local target = Z.db.contacts[key] and Z.db.contacts[key].target or key
            local token = key .. '\0' .. id
            if token == U.groupOutgoingToken then
                selected = true
            end
            items[#items + 1] = {
                at = row.at or 0,
                key = key,
                id = id,
                row = row,
                target = target,
                content = content ~= '' and content or tr('Nicht mehr verfügbare Gruppe'),
                token = token,
            }
        end
    end
    table.sort(items, function(a, b)
        return a.at > b.at
    end)
    local display = {}
    for _, entry in ipairs(items) do
        local token = entry.token
        display[#display + 1] = {
            selected = token == U.groupOutgoingToken,
            icon = NAV_ICONS.groups,
            text = '|cffffd36b' .. entry.content .. '|r\n' .. entry.target .. ' · ' .. stateName(entry.row.state) .. ' · ' .. date(
                '%d.%m. %H:%M',
                entry.at
            ) .. '\n' .. peerLocationLine(entry.key, tr('Leader-Ort')),
            click = function()
                U.groupOutgoingToken = token
                S.refreshGroupOutgoing()
            end,
        }
    end
    if not selected then
        U.groupOutgoingToken = nil
    end
    U.SetEmptyHint(U.groupOutgoingList, 'You have not applied to a group yet. Open Group Search and press Apply.')
    rows(U.groupOutgoingList, display, 68)
    U.groupOutgoingCount:SetText(#display == 1 and tr('1 Bewerbung') or #display .. tr(' Bewerbungen'))
    local chosen
    for _, entry in ipairs(items) do
        if entry.token == U.groupOutgoingToken then
            chosen = entry
        end
    end
    if not chosen then
        U.groupOutgoingDetail:SetText(tr('Select an application.'))
        U.groupOutgoingWithdraw:SetEnabled(false)
        return
    end
    Z.Notifications.ReadVisible('groups', 'outgoing', 'groups:outgoing:' .. chosen.key .. ':' .. chosen.id)
    U.groupOutgoingDetail:SetText(
        '|cffffd36b'
            .. chosen.content
            .. '|r\n'
            .. chosen.target
            .. '\n'
            .. peerLocationLine(chosen.key, 'Leader current location')
            .. '\n'
            .. tr('Status')
            .. ': '
            .. stateName(chosen.row.state)
            .. '\n'
            .. (I.isGerman and 'Transport: ' or 'Transport: ')
            .. deliveryState('group', chosen.id, chosen.key)
            .. '\n'
            .. (I.isGerman and 'Stand: ' or 'As of: ')
            .. date('%d.%m.%Y %H:%M', chosen.at)
    )
    U.groupOutgoingWithdraw:SetEnabled(chosen.row.state == 'applied' or chosen.row.state == 'invited')
end
function U.SetGroupView(v)
    U.groupView = v
    U.groupBrowseFrame:SetShown(v == 'browse')
    U.groupMineFrame:SetShown(v == 'mine')
    if U.groupOutgoingFrame then
        U.groupOutgoingFrame:SetShown(v == 'outgoing')
    end
    U.groupFollowFrame:SetShown(v == 'follow')
    if U.groupPvpFrame then
        U.groupPvpFrame:SetShown(v == 'pvp')
    end
    if U.sessionPlanFrame then
        U.sessionPlanFrame:SetShown(v == 'today')
    end
    if U.scheduledFrame then
        U.scheduledFrame:SetShown(v == 'scheduled')
        selectNav(U.scheduledTab, v == 'scheduled')
    end
    selectNav(U.activityScopeOrganized, v == 'mine')
    selectNav(U.activityScopeApplications, v == 'outgoing')
    selectNav(U.activityScopePlanned, v == 'scheduled')
    selectNav(U.sessionPlanTab, v == 'today')
    selectNav(U.groupBrowseTab, v == 'browse')
    selectNav(U.groupMineTab, v == 'mine')
    selectNav(U.groupOutgoingTab, v == 'outgoing')
    selectNav(U.groupFollowTab, v == 'follow')
    selectNav(U.pvpTab, v == 'pvp')
    updateNavPath()
    if Z.UIState then
        Z.UIState.Route('groups', v)
    end
    if v == 'outgoing' then
        S.refreshGroupOutgoing()
    end
    U.Refresh()
end
S.restoringDraft = false
function U.CaptureGroupDraft()
    if S.restoringDraft or not U.groupEditing or not U.groupFields then
        return
    end
    local draft = {
        editID = U.groupEditID or '',
        kind = U.groupKind:GetText(),
        activity = U.groupActivity:GetText(),
        custom = U.groupCustom:GetText(),
        templateDuration = U.groupTemplateDuration and U.groupTemplateDuration:GetText() or '120',
        templateName = U.groupTemplateName and U.groupTemplateName:GetText() or '',
    }
    for key, field in pairs(U.groupFields) do
        draft[key] = field:GetText()
    end
    if Z.UIState then
        Z.UIState.ActivityInput('group', draft)
    end
    if U.groupNoteCount then
        U.groupNoteCount:SetText(#(draft.note or '') .. ' / 96')
    end
    if U.groupFormPreview then
        local activity = draft.kind == 'CUSTOM' and draft.custom or draft.activity
        U.groupFormPreview:SetText(
            '|cffffd36b'
                .. (I.isGerman and tr('VORSCHAU') or 'PREVIEW')
                .. '|r\n'
                .. (activity ~= '' and activityName(activity) or (I.isGerman and tr('Aktivität wählen') or 'Select activity'))
                .. '\nLevel '
                .. (draft.min or '')
                .. '–'
                .. (draft.max or '')
                .. '\n'
                .. (I.isGerman and tr('Zielgröße: ') or 'Target size: ')
                .. (draft.size or '')
                .. '\n'
                .. (I.isGerman and 'Gesucht:' or 'Needed:')
                .. '\n'
                .. (draft.tank or '0')
                .. ' '
                .. roleName('TANK')
                .. ' · '
                .. (draft.healer or '0')
                .. ' '
                .. roleName('HEALER')
                .. '\n'
                .. (draft.dd or '0')
                .. ' '
                .. roleName('DAMAGER')
                .. ((draft.note or '') ~= '' and '\n\n' .. draft.note or '')
        )
    end
end
function U.ValidateGroupForm()
    local activity = U.groupKind:GetText() == 'CUSTOM' and U.groupCustom:GetText() or U.groupActivity:GetText()
    if not L.Text(activity, 64) then
        (U.groupKind:GetText() == 'CUSTOM' and U.groupCustom or U.groupFields.min):SetFocus()
        U.Message(tr('Bitte eine gültige Aktivität angeben.'))
        return false
    end
    local order = {
        { 'min', 1, 100, tr('Level von') },
        { 'max', 1, 100, tr('Level bis') },
        { 'size', 2, 40, tr('Zielgröße') },
        { 'tank', 0, 10, 'Tank' },
        { 'healer', 0, 15, 'Heiler' },
        { 'dd', 0, 40, 'DD' },
    }
    local values = {}
    for _, rule in ipairs(order) do
        local value = tonumber(U.groupFields[rule[1]]:GetText())
        if not L.Int(value, rule[2], rule[3]) then
            U.groupFields[rule[1]]:SetFocus()
            U.Message(rule[4] .. tr(' ist ungültig.'))
            return false
        end
        values[rule[1]] = value
    end
    if values.max < values.min then
        U.groupFields.max:SetFocus()
        U.Message('Das maximale Level muss mindestens dem Mindestlevel entsprechen.')
        return false
    end
    if values.tank + values.healer + values.dd > values.size then
        U.groupFields.size:SetFocus()
        U.Message(tr('Die gesuchten Rollen überschreiten die Zielgröße.'))
        return false
    end
    return true
end
function U.DiscardGroupDraft()
    if Z.UIState then
        Z.UIState.ActivityInput('group', false)
    end
    U.groupEditing = false
    U.groupEditID = nil
    U.groupForm:Hide()
    U.Refresh()
end
function U.SaveGroupTemplate()
    if not U.ValidateGroupForm() then
        return
    end
    local name = U.groupTemplateName and U.groupTemplateName:GetText() or ''
    local duration = tonumber(U.groupTemplateDuration and U.groupTemplateDuration:GetText())
    if not L.Text(name, 64) then
        U.groupTemplateName:SetFocus()
        U.Message('Please enter a template name.')
        return
    end
    if not L.Int(duration, 1, 1440) then
        U.groupTemplateDuration:SetFocus()
        U.Message('The duration must be between 1 and 1440 minutes.')
        return
    end
    local group = {
        mode = 'LFM',
        activity = U.groupKind:GetText() == 'CUSTOM' and U.groupCustom:GetText() or U.groupActivity:GetText(),
        have = A.GroupRoles(),
    }
    for key, field in pairs(U.groupFields) do
        group[key] = key == 'note' and field:GetText() or tonumber(field:GetText())
    end
    local ok, err = Z.GroupFinder.SaveTemplate(name, group, duration)
    if ok then
        U.Message('Group template saved. It was not published.')
        if S.refreshGroupMine then
            S.refreshGroupMine()
        end
    else
        U.Message(err)
    end
    return ok
end
function U.OpenGroupEditor(g)
    local draft = not g and Z.UIState and Z.UIState.ActivityInput('group')
    S.restoringDraft = true
    U.groupEditing = true
    U.groupEditID = g and g.id or draft and draft.editID ~= '' and draft.editID or nil
    U.groupMineEmpty:Hide()
    U.groupMineSummary:Hide()
    U.groupForm:Show()
    local activity = L.ActivityID(g and g.activity or draft and (draft.kind == 'CUSTOM' and draft.custom or draft.activity) or DUNGEONS[1])
    local kind = g and activityCategory(activity) or draft and draft.kind or 'DUNGEON'
    if U.groupActivitySearch then
        U.groupActivitySearch:SetText('')
    end
    U.groupKind:SetText(kind)
    U.GroupKind(kind, activity)
    local v = g or draft or { min = 1, max = 60, size = 5, tank = 1, healer = 1, dd = 3, note = '' }
    for k, e in pairs(U.groupFields) do
        e:SetText(tostring(v[k] or ''))
    end
    U.groupCustom:SetText(v.custom or (kind == 'CUSTOM' and activity or ''))
    U.groupHave:SetText(groupHave(A.GroupRoles()))
    if U.groupTemplateName then
        U.groupTemplateName:SetText(g and g.templateName or draft and draft.templateName or '')
    end
    if U.groupTemplateDuration then
        U.groupTemplateDuration:SetText(tostring(g and g.templateDuration or draft and draft.templateDuration or 120))
    end
    U.groupSave:SetText(tr(U.groupEditID and 'Save changes' or 'Publish group'))
    S.restoringDraft = false
    if U.AutofillGroupNeeds and not g and not draft then
        U.AutofillGroupNeeds()
    end
    U.CaptureGroupDraft()
end
function U.FilterGroupActivities()
    if not U.groupActivitySearch or U.groupKind:GetText() == 'CUSTOM' then
        return
    end
    local source = U.groupKind:GetText() == 'PVP' and PVP or U.groupKind:GetText() == 'RAID' and RAIDS or DUNGEONS
    local query = string.lower(U.groupActivitySearch:GetText() or '')
    local filtered = {}
    for _, name in ipairs(source) do
        if query == '' or string.lower(activityName(name)):find(query, 1, true) then
            filtered[#filtered + 1] = name
        end
    end
    U.groupActivity:SetOptions(filtered, U.groupActivity:GetText())
end
function U.GroupKind(kind, activity)
    kind = canonicalOption(kind)
    local custom = kind == 'CUSTOM'
    U.groupActivity:SetShown(not custom)
    U.groupCustom.caption:SetShown(custom)
    U.groupCustom:SetShown(custom)
    if U.groupActivitySearch then
        U.groupActivitySearch:SetShown(not custom)
        U.groupActivitySearch.caption:Hide()
    end
    if kind == 'PVP' then
        U.groupActivity:SetOptions(PVP, activity)
    elseif kind == 'DUNGEON' then
        U.groupActivity:SetOptions(DUNGEONS, activity)
    elseif kind == 'RAID' then
        U.groupActivity:SetOptions(RAIDS, activity)
        if not U.groupEditID and U.groupFields and U.groupFields.size then
            U.groupFields.size:SetText(tostring(RAID_SIZE[U.groupActivity:GetText()] or 10))
        end
    elseif activity then
        U.groupCustom:SetText(activity)
    end
    if U.groupActivitySearch then
        U.FilterGroupActivities()
    end
    U.CaptureGroupDraft()
end
function U.GroupActivity(activity)
    if not U.groupEditID and RAID_SIZE[activity] and U.groupFields and U.groupFields.size then
        U.groupFields.size:SetText(tostring(RAID_SIZE[activity]))
    end
    U.CaptureGroupDraft()
end
function U.FollowKind(kind)
    kind = canonicalOption(kind)
    local values = kind == 'PVP' and PVP or kind == 'DUNGEON' and DUNGEONS or RAIDS
    U.followActivity:SetOptions(values, U.followActivity:GetText())
end
function U.AddGroupFollow()
    local activity = U.followActivity:GetText()
    if Z.SetGroupFollow(activity, true) then
        U.followSelected = activity
        U.Message(tr('Du folgst jetzt ') .. activity .. '.')
        S.refreshGroupFollows()
    end
end
function U.RemoveGroupFollow()
    if U.followSelected and Z.SetGroupFollow(U.followSelected, false) then
        U.Message(Z.T('You no longer follow %s.', U.followSelected))
        U.followSelected = nil
        S.refreshGroupFollows()
    end
end
S.refreshGroupFollows = function()
    local followed = {}
    for activity in pairs(Z.db.groupFollows) do
        followed[#followed + 1] = activity
    end
    table.sort(followed)
    local items = {}
    local valid = false
    for _, activity in ipairs(followed) do
        local selectedActivity = activity
        if selectedActivity == U.followSelected then
            valid = true
        end
        items[#items + 1] = {
            selected = selectedActivity == U.followSelected,
            icon = NAV_ICONS.groups,
            text = '|cffffd36b' .. selectedActivity .. '|r\n' .. activityCategory(selectedActivity),
            click = function()
                U.followSelected = selectedActivity
                S.refreshGroupFollows()
            end,
        }
    end
    if not valid then
        U.followSelected = nil
    end
    U.SetEmptyHint(U.followList, 'You follow no activities. Choose a category and activity above and press Follow.')
    rows(U.followList, items, 48)
    U.followCount:SetText(#followed .. tr(' Aktivitäten gefolgt'))
    U.followRemove:SetEnabled(U.followSelected ~= nil)
    U.followDetail:SetText(
        U.followSelected and (tr('Du erhältst einen Hinweis, wenn eine neue Gruppe für ') .. U.followSelected .. tr(' empfangen wird.'))
            or tr('Wähle links eine gefolgte Aktivität aus.')
    )
end
function U.SetPvpView(v)
    U.pvpView = 'all'
    if U.RefreshPvPPage then
        U.RefreshPvPPage()
    end
end
function U.SelectPvpCall(key, id)
    U.pvpCallKey, U.pvpCallID = key, id
    if Z.PvPHelp then
        Z.PvPHelp.RequestDetails(key, id)
    end
    S.refreshPvPHelp()
end
function U.OpenPvPHelp(view, key, id, preview)
    U.Create()
    U.frame:Show()
    if key and id and (Z.db.blocked[key] or not (Z.PvPHelp and Z.PvPHelp.GetCall(key, id))) then
        return U.Navigation.Fail('target-unavailable')
    end
    if not U.Navigate('groups', 'pvp') then
        return false
    end
    U.SetPvpView(view or 'calls')
    if key and id then
        U.SelectPvpCall(key, id)
    end
    if preview then
        U.OpenPvpPreview()
    end
    return true
end
function U.OpenPvPRequester()
    U.OpenPvPHelp('mine')
end
function U.OpenPvpPreview()
    local P = Z.PvPHelp
    local ok, err = P and P.CanCall()
    if not ok then
        U.Message(err or tr('Hilferuf nicht verfügbar.'))
        return
    end
    P.UseTestLocation()
    local d = P.store.lastDeath
    U.pvpPreviewLocation:SetText('|cffffd36bVORSCHAU|r\n' .. P.FormatLocation(d) .. '\nZeitpunkt: ' .. date('%H:%M', d.at))
    -- The detected PvP deaths (never the current target) that unlock the request; the helpers get them unless unchecked.
    local log = P.KillLog() or {}
    local lines = {}
    for index, death in ipairs(log) do
        if index > 3 then
            lines[#lines + 1] = '...'
            break
        end
        local killer = death.killer
        local more = (death.minAttackers or 1) - (killer and 1 or 0)
        lines[#lines + 1] = date('%H:%M', death.at)
            .. ' · '
            .. Z.T('Killer: %s', killer and P.FormatPerson(killer) or tr('Unknown'))
            .. (more > 0 and ' · ' .. Z.T(killer and 'Further attackers (at least %d)' or 'Attackers (at least %d)', more) or '')
    end
    U.pvpPreviewEnemy:SetText(#lines > 0 and table.concat(lines, '\n') or tr('No confirmed PvP combat data detected.'))
    U.pvpShareEnemy:SetChecked(true)
    U.pvpShareEnemy:SetEnabled(#log > 0)
    U.pvpConfirm:SetChecked(false)
    U.pvpCallNote:SetText('')
    U.pvpPreviewOpen = true
    if not U.pvpUnified then
        U.pvpMineBase:Hide()
    end
    U.pvpPreview:Show()
end
local function selectedPvpCall()
    return Z.PvPHelp and U.pvpCallKey and Z.PvPHelp.GetCall(U.pvpCallKey, U.pvpCallID)
end
S.selectedPvpCall = selectedPvpCall
S.refreshPvPHelp = function()
    if U.RefreshPvPPage then
        U.RefreshPvPPage()
    end
end
function U.RefreshPvPHelp()
    S.refreshPvPHelp()
end
local function priorContactsText(key, currentID)
    if not key or not H then
        return tr('Bisherige Kontakte\nWähle einen Bewerber aus.')
    end
    local previous = H.ContactSummaries(key, currentID, 3)
    if #previous == 0 then
        return tr('Bisherige Kontakte\nNoch keine früheren Kontakte gespeichert.')
    end
    local lines = { tr('Bisherige Kontakte') }
    for _, e in ipairs(previous) do
        lines[#lines + 1] = date('%d.%m.%Y', e.at) .. ' · ' .. e.content .. ' · ' .. H.EventLabel(e.event)
    end
    return table.concat(lines, '\n')
end
S.priorContactsText = priorContactsText
local function refreshGroupApplicants()
    local g = Z.db.lfg[1]
    local bucket = g and Z.db.interests[g.id] or {}
    local open = 0
    local items = {}
    local valid = false
    for _, key in ipairs(keys(bucket)) do
        local r = bucket[key]
        if r.state == 'applied' then
            open = open + 1
        end
        if key == U.groupApplicantKey then
            valid = true
        end
        local target = Z.db.contacts[key] and Z.db.contacts[key].target or key
        local applicantKey = key
        items[#items + 1] = {
            selected = key == U.groupApplicantKey,
            icon = T and T.RoleIcon(r.role),
            text = target .. (r.role and ' · ' .. roleName(r.role) or '') .. ' · ' .. stateName(r.state) .. '\n' .. peerLocationLine(
                key,
                'Location'
            ) .. (r.note ~= '' and '\n' .. r.note or ''),
            click = function()
                U.groupApplicantKey = applicantKey
                if g then
                    L.MarkApplicationsRead(Z.db, 'group', g.id, applicantKey)
                    Z.Notifications.ReadVisible('groups', 'mine', 'groups:mine:' .. applicantKey .. ':' .. g.id)
                end
                refreshGroupApplicants()
                U.UpdateBadges()
            end,
        }
    end
    if not valid then
        U.groupApplicantKey = nil
    end
    U.groupApplicantCount:SetText(tr('Incoming applicants') .. ' (' .. open .. ')')
    U.SetEmptyHint(U.groupApplicantList, 'No applicants yet. They appear here as soon as someone applies to your group.')
    rows(U.groupApplicantList, items, 64)
    local r = U.groupApplicantKey and bucket[U.groupApplicantKey]
    if r and g then
        Z.Notifications.ReadVisible('groups', 'mine', 'groups:mine:' .. U.groupApplicantKey .. ':' .. g.id)
    end
    local enabled = r and r.state == 'applied'
    U.groupAccept:SetEnabled(enabled and peerOnline(U.groupApplicantKey) or false)
    U.groupReject:SetEnabled(enabled and true or false)
    U.groupApplicantWhisper:SetEnabled(r and true or false)
    U.groupApplicantLocation:SetText(
        U.groupApplicantKey and peerLocationLine(U.groupApplicantKey, 'Applicant location')
            or tr('Current location') .. '\n' .. tr('Choose an applicant.')
    )
    U.groupPriorContacts:SetText(priorContactsText(U.groupApplicantKey, g and g.id))
    U.groupHistoryOpen:SetEnabled(U.groupApplicantKey ~= nil)
end
S.refreshGroupMine = function()
    local g = Z.db.lfg[1]
    if U.groupTemplate then
        local names = {}
        for name in pairs(Z.db.groupTemplates or {}) do
            names[#names + 1] = name
        end
        table.sort(names)
        table.insert(names, 1, 'Choose template')
        U.groupTemplate:SetOptions(names, U.groupTemplate:GetText())
        if U.groupTemplateDelete then
            U.groupTemplateDelete:SetEnabled(Z.db.groupTemplates[U.groupTemplate:GetText()] ~= nil)
        end
        if U.groupActiveTemplate then
            U.groupActiveTemplate:SetOptions(names, U.groupActiveTemplate:GetText())
            if U.groupActiveTemplateDelete then
                U.groupActiveTemplateDelete:SetEnabled(Z.db.groupTemplates[U.groupActiveTemplate:GetText()] ~= nil)
            end
        end
    end
    if U.groupEditing then
        if U.groupEditID and (not g or g.id ~= U.groupEditID) then
            U.groupEditing = false
            U.groupForm:Hide()
        else
            refreshGroupApplicants()
            return
        end
    end
    U.groupForm:Hide()
    U.groupMineEmpty:SetShown(not g)
    U.groupMineSummary:SetShown(g ~= nil)
    if g then
        U.groupOwnSummary:SetText(
            '|cffffd36b'
                .. activityName(g.activity)
                .. '|r · '
                .. tr('Level')
                .. ' '
                .. g.min
                .. '–'
                .. g.max
                .. '\n'
                .. tr('Target size')
                .. ': '
                .. g.size
                .. ' · '
                .. tr('Current')
                .. ': '
                .. groupHave(g.have)
                .. ' · '
                .. tr('Needed')
                .. ': '
                .. wanted(g)
                .. (g.note ~= '' and '\n' .. g.note or '')
        )
        refreshGroupApplicants()
    end
end
local function decideGroup(state)
    state = L.ApplicationState(state) or state
    local g = Z.db.lfg[1]
    local key = U.groupApplicantKey
    local row = g and Z.db.interests[g.id] and Z.db.interests[g.id][key]
    if not g or not row or row.state ~= 'applied' then
        U.Message(tr('Bewerbung nicht mehr aktiv.'))
        return
    end
    local c = Z.db.contacts[key]
    if not c then
        return
    end
    if state == 'invited' then
        if not peerOnline(key) then
            U.Message('This player is offline.')
            U.Refresh()
            return
        end
        local gs = A.GroupState()
        if gs.total >= g.size then
            U.Message(tr('Die Zielgröße ist bereits erreicht.'))
            return
        end
        local ok, err = A.Invite(c.target)
        if not ok then
            U.Message(err)
            return
        end
        row.state = 'invited'
        row.at = A.Now()
        Z.RecordDecision('group', key, g.id, state, g)
        local q, e = Z.Queue(key, { kind = 'GS', id = g.id, state = state })
        U.Message(
            q and tr('Invitation submitted; awaiting response.') or (e or tr('Invitation submitted; addon status could not be delivered.'))
        )
    else
        local q, e = Z.Queue(key, { kind = 'GS', id = g.id, state = state })
        if not q then
            U.Message(e)
            return
        end
        row.state = state
        row.at = A.Now()
        Z.RecordDecision('group', key, g.id, state, g)
        U.Message('')
    end
    U.Refresh()
end
S.decideGroup = decideGroup
U.DecideGroupApplicant = decideGroup

