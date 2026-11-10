local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local H = Z.History
local T = Z.Theme
local I = Z.Locale
local S = U.Shared
local tr = S.tr
local NAV_ICONS, selectNav, updateNavPath, rows, keys = S.NAV_ICONS, S.selectNav, S.updateNavPath, S.rows, S.keys
local peerOnline, stateName, deliveryState, peerLocation = S.peerOnline, S.stateName, S.deliveryState, S.peerLocation
local peerLocationLine, priorContactsText = S.peerLocationLine, S.priorContactsText

function U.OpenSharedQuestRequest()
    local chosen
    for _, q in ipairs(Z.QuestHelper.quests) do
        if q.id == U.sharedQuestID then
            chosen = q
            break
        end
    end
    if not chosen then
        return
    end
    U.SetQuestView('mine')
    if Z.db.quest then
        U.OpenQuestEditor(Z.db.quest)
        U.Message(tr('Your existing request is open for editing.'))
        return
    end
    Z.UIState.ActivityInput('quest', false)
    U.OpenQuestEditor(nil)
    U.questEditQuestID = chosen.id
    U.questFields.title:SetText(chosen.title)
    if chosen.level > 0 then
        U.questFields.min:SetText(tostring(chosen.level))
        U.questFields.max:SetText(tostring(chosen.level))
    end
    U.CaptureQuestDraft()
end
function U.RefreshSharedQuests()
    if not U.sharedQuestList then
        return
    end
    local Q = Z.QuestHelper
    local matchIndex = Q.AllMatches()
    local query = string.lower(U.sharedQuestSearch:GetText() or '')
    local items = {}
    local selected
    for _, q in ipairs(Q.quests) do
        if query == '' or string.lower(q.title):find(query, 1, true) or string.lower(q.category or ''):find(query, 1, true) then
            local id = q.id
            local matches = matchIndex[id] or {}
            items[#items + 1] = {
                q = q,
                count = #matches,
                selected = id == U.sharedQuestID,
                icon = NAV_ICONS.quests,
                iconSize = 20,
                textInset = 36,
                noWrap = true,
                text = '|cffffd36b' .. q.title .. '|r',
                subtitle = tr('Fellow players') .. ': ' .. #matches,
                tooltip = q.title .. '\n' .. tr('Fellow players') .. ': ' .. #matches,
                click = function()
                    U.sharedQuestID = id
                    U.sharedMemberKey = nil
                    U.RefreshSharedQuests()
                end,
            }
            if id == U.sharedQuestID then
                selected = q
            end
        end
    end
    local categories, byCategory = {}, {}
    for _, item in ipairs(items) do
        local name = item.q.category or ''
        local group = byCategory[name]
        if not group then
            group = { name = name, order = item.q.categoryOrder or 0, items = {} }
            byCategory[name] = group
            categories[#categories + 1] = group
        end
        group.items[#group.items + 1] = item
        group.order = math.min(group.order, item.q.categoryOrder or 0)
    end
    table.sort(categories, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.name < b.name
    end)
    local collapsed = query ~= '' and (U.sharedQuestSearchCollapsed or {}) or Z.uiCharacter.questCategories
    local display = {}
    for _, group in ipairs(categories) do
        local name = group.name
        local isCollapsed = collapsed[name] == true
        display[#display + 1] = {
            category = name,
            header = true,
            height = 30,
            iconSize = 14,
            icon = isCollapsed and 'Interface\\Buttons\\UI-PlusButton-Up' or 'Interface\\Buttons\\UI-MinusButton-Up',
            color = { 0.10, 0.08, 0.05, 0.9 },
            text = '|cffd9b86b' .. (name ~= '' and name or tr('Other quests')) .. ' |cff9d927b(' .. #group.items .. ')|r',
            click = function()
                collapsed[name] = not collapsed[name] or nil
                U.RefreshSharedQuests()
            end,
        }
        table.sort(group.items, function(a, b)
            if a.count ~= b.count then
                return a.count > b.count
            end
            return a.q.title < b.q.title
        end)
        if not isCollapsed then
            for _, item in ipairs(group.items) do
                display[#display + 1] = item
            end
        end
    end
    U.SetEmptyHint(U.sharedQuestList, 'No quests found. Accept a quest in the game and it appears here.')
    rows(U.sharedQuestList, display, 38)
    U.sharedQuestCount:SetText(Z.T('%d quests', #items))
    U.sharedRequest:SetEnabled(selected ~= nil)
    U.sharedInvite:SetEnabled(false)
    U.sharedWhisper:SetEnabled(false)
    local valid = Q.sampleAt and A.Now() - Q.sampleAt <= Q.TTL
    U.sharedQuestStatus:SetText(
        Q.scanState == 'error' and tr('Quest log could not be read. Details are available in Diagnostics.')
            or not valid and tr(
                Q.scanState == 'deferred' and 'Quest log scan pending. Close the map and leave combat.' or 'Reading your quest log…'
            )
            or not Q.Sharing() and tr('Quest sharing is disabled.')
            or ''
    )
    if not selected then
        U.sharedQuestID = nil
        U.sharedMemberKey = nil
        U.sharedQuestTitle:SetText(tr('Select one of your quests.'))
        U.sharedMemberState:SetText('')
        rows(U.sharedMemberList, {}, 68)
        return
    end
    U.sharedQuestTitle:SetText('|cffffd36b' .. selected.title .. '|r')
    local matches = matchIndex[selected.id] or {}
    local members = {}
    local chosen
    for _, m in ipairs(matches) do
        local key = m.key
        if key == U.sharedMemberKey then
            chosen = m
        end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.classFile]
        local hex = color and string.format('%02x%02x%02x', color.r * 255, color.g * 255, color.b * 255) or 'ffd36b'
        members[#members + 1] = {
            selected = key == U.sharedMemberKey,
            icon = T and T.ClassIcon(m.classFile),
            text = '|cff'
                .. hex
                .. m.target
                .. '|r · '
                .. tr('Level')
                .. ' '
                .. m.level
                .. ' · '
                .. tr(m.status)
                .. '\n'
                .. peerLocation(key)
                .. '\n'
                .. Z.T('%d other shared quests', m.common - 1),
            click = function()
                U.sharedMemberKey = key
                U.RefreshSharedQuests()
            end,
        }
    end
    rows(U.sharedMemberList, members, 68)
    if not chosen then
        U.sharedMemberKey = nil
        U.sharedMemberState:SetText(#matches == 0 and tr('No other players with this quest found.') or tr('Select a member.'))
        return
    end
    local canInvite, reason = Q.CanInvite(chosen.key, selected.id)
    U.sharedInvite:SetEnabled(canInvite)
    U.sharedWhisper:SetEnabled(true)
    U.sharedMemberState:SetText(chosen.target .. ' · ' .. (canInvite and tr(chosen.status) or tr(reason)))
end

-- Display only: all matching, scoring and identity decisions live in QuestGroups.
function U.RefreshQuestGroups()
    if not U.questGroupList then
        return
    end
    local G = Z.QuestGroups
    local suggestions, meta = G.BuildSuggestions()
    local items, chosen = {}, nil
    for _, s in ipairs(suggestions) do
        local key = s.key
        local names = table.concat(s.names, ', ')
        items[#items + 1] = {
            selected = key == U.questGroupKey,
            text = names,
            subtitle = Z.T('%d covered · %d shared by all', s.coverageCount, s.intersectionCount),
            noWrap = true,
            tooltip = names .. '\n' .. G.Explain(s),
            click = function()
                U.questGroupKey = key
                U.questGroupMemberKey = nil
                U.RefreshQuestGroups()
            end,
        }
        if key == U.questGroupKey then
            chosen = s
        end
    end
    U.SetEmptyHint(U.questGroupList, 'No quest groups yet. They appear when other players share quests that overlap with yours.')
    rows(U.questGroupList, items, 42)
    U.questGroupStatus:SetText(
        meta.state ~= 'ready' and tr('Quest data unavailable.')
            or Z.T('%d suggestions · %d players considered', #suggestions, meta.considered)
    )
    U.questGroupInvite:SetEnabled(false)
    U.questGroupWhisper:SetEnabled(false)
    U.questGroupActionState:SetText('')
    U.questGroupSelected = chosen
    if not chosen then
        U.questGroupKey, U.questGroupMemberKey = nil, nil
        U.questGroupSummary:SetText(tr('Select a quest group. Missing quest data is unknown.'))
        rows(U.questGroupMembers, {}, 52)
        rows(U.questGroupQuests, {}, 38)
        return
    end
    U.questGroupSummary:SetText(G.Explain(chosen))
    local members, member = {}, nil
    for _, m in ipairs(chosen.members) do
        local key = m.key
        if key == U.questGroupMemberKey then
            member = m
        end
        local status = m.inGroup
                and (m.availability == 'AFK' or m.availability == 'BUSY')
                and (tr('Your group') .. ' · ' .. tr(m.availability == 'AFK' and 'AFK' or 'Busy'))
            or tr(m.status)
        members[#members + 1] = {
            selected = key == U.questGroupMemberKey,
            icon = T and T.ClassIcon(m.classFile),
            text = m.target .. ' · ' .. tr('Level') .. ' ' .. m.level .. '\n' .. status .. ' · ' .. Z.T('%d shared quests', m.common),
            click = function()
                U.questGroupMemberKey = U.questGroupMemberKey ~= key and key or nil
                U.RefreshQuestGroups()
            end,
        }
    end
    rows(U.questGroupMembers, members, 52)
    local titles = {}
    for _, q in ipairs(Z.QuestHelper.quests) do
        titles[q.id] = q.title
    end
    local quests = {}
    local all = {}
    for _, id in ipairs(chosen.intersectionIDs) do
        all[id] = true
    end
    for _, id in ipairs(chosen.coverageIDs) do
        local names = {}
        for _, m in ipairs(chosen.members) do
            if m.ids[id] then
                names[#names + 1] = m.target
            end
        end
        local text = (all[id] and tr('Everyone') or table.concat(names, ', '))
        quests[#quests + 1] = {
            selected = member and member.ids[id] or false,
            text = titles[id] or tostring(id),
            subtitle = text,
            noWrap = true,
            tooltip = (titles[id] or tostring(id)) .. ' (#' .. id .. ')\n' .. text,
        }
    end
    rows(U.questGroupQuests, quests, 38)
    if not member then
        U.questGroupMemberKey = nil
        return
    end
    local ok, reason = Z.QuestHelper.CanInvite(member.key, member.quests[1])
    U.questGroupInvite:SetEnabled(ok)
    U.questGroupWhisper:SetEnabled(true)
    U.questGroupActionState:SetText(member.target .. ' · ' .. (ok and tr(member.status) or tr(reason)))
end
function U.InviteQuestGroupMember()
    local s = U.questGroupSelected
    local fresh, reason = Z.QuestGroups.GetCoverage(s and s.memberKeys)
    local member
    for _, m in ipairs(fresh and fresh.members or {}) do
        if m.key == U.questGroupMemberKey then
            member = m
        end
    end
    local ok
    if member then
        ok, reason = Z.QuestHelper.Invite(member.key, member.quests[1])
    end
    U.Message(ok and tr('Invitation submitted; awaiting response.') or tr(reason or 'Quest match no longer available.'))
    U.RefreshQuestGroups()
end
local function foreignQuests()
    local a = {}
    for key, p in pairs(Z.db.peers) do
        local q = p.data and p.data.quest
        if peerOnline(key) and q and q.expires > A.Now() and Z.db.contacts[key] then
            a[#a + 1] = { key = key, target = Z.db.contacts[key].target, q = q }
        end
    end
    table.sort(a, function(x, y)
        return x.q.title < y.q.title
    end)
    return a
end
local function selectedQuest()
    return U.questKey and Z.FindForeignQuest(U.questKey, U.questID)
end
function U.SelectQuest(key, id)
    U.questKey, U.questID = key, id
    U.questApplyOpen = false
    U.questApplyFrame:Hide()
    S.refreshQuestBrowse()
    U.OpenCompactArea('quests')
end
S.refreshQuestBrowse = function()
    local items = {}
    local query = string.lower(U.questFilterSearch and U.questFilterSearch:GetText() or '')
    local zone = string.lower(U.questFilterZone and U.questFilterZone:GetText() or '')
    local level = tonumber(U.questFilterLevel and U.questFilterLevel:GetText())
    for _, x in ipairs(foreignQuests()) do
        local q = x.q
        local where = peerLocation(x.key)
        local hay = string.lower(q.title .. ' ' .. x.target .. ' ' .. (q.note or '') .. ' ' .. where)
        local matchesQuery = query == '' or hay:find(query, 1, true)
        local matchesZone = zone == '' or string.lower((q.zone or '') .. ' ' .. where):find(zone, 1, true)
        local matchesLevel = not level or level >= q.min and level <= q.max
        if matchesQuery and matchesZone and matchesLevel then
            local key, id = x.key, q.id
            items[#items + 1] = {
                selected = key == U.questKey and id == U.questID,
                icon = NAV_ICONS.quests,
                text = '|cffffd36b'
                    .. q.title
                    .. '|r\n'
                    .. x.target
                    .. ' · Level '
                    .. q.min
                    .. '–'
                    .. q.max
                    .. (q.zone ~= '' and '\nQuestgebiet: ' .. q.zone or '')
                    .. '\n'
                    .. peerLocationLine(key, tr('Leader-Ort')),
                click = function()
                    U.SelectQuest(key, id)
                end,
            }
        end
    end
    U.SetEmptyHint(U.questBrowseList, 'No quest requests match. Change the filters or create your own request under My Quest Request.')
    rows(U.questBrowseList, items, 80)
    if U.questBrowseCount then
        U.questBrowseCount:SetText(#items == 1 and '1 Questanfrage' or #items .. ' Questanfragen')
    end
    local q = selectedQuest()
    if not q then
        U.questKey, U.questID = nil, nil
        U.questBrowseDetail:SetText(tr('Wähle eine Questanfrage aus.'))
        U.questApplyStart:Hide()
        U.questWithdraw:Hide()
        U.questBrowseWhisper:Hide()
        U.questApplyFrame:Hide()
        U.questApplyState:SetText('')
        return
    end
    local c = Z.db.contacts[U.questKey]
    U.questBrowseDetail:SetText(
        '|cffffd36b'
            .. q.title
            .. '|r\n'
            .. (c and c.target or U.questKey)
            .. '\n'
            .. peerLocationLine(U.questKey, 'Leader current location')
            .. (q.zone ~= '' and '\n' .. tr('Quest area') .. ': ' .. q.zone or '')
            .. '\nLevel '
            .. q.min
            .. '–'
            .. q.max
            .. (q.note ~= '' and '\n\n' .. q.note or '')
    )
    U.questBrowseWhisper:Show()
    local sent = Z.db.sentQuestApplications[q.id] and Z.db.sentQuestApplications[q.id][U.questKey]
    U.questApplyState:SetText(sent and tr('Status') .. ': ' .. stateName(sent.state) or '')
    local active = sent and (sent.state == 'applied' or sent.state == 'invited')
    U.questApplyStart:SetShown(not active and not U.questApplyOpen and (not sent or sent.state == 'withdrawn'))
    U.questWithdraw:SetShown(active)
    U.questApplyFrame:SetShown(U.questApplyOpen and not active)
end
S.refreshQuestOutgoing = function()
    if not U.questOutgoingList then
        return
    end
    local items, selected = {}, false
    for id, people in pairs(Z.db.sentQuestApplications or {}) do
        for key, row in pairs(people) do
            local peer = Z.db.peers[key]
            local current = peer and peer.data and peer.data.quest
            local content = current and current.id == id and current.title or H.FindContent('quest', id, key)
            local target = Z.db.contacts[key] and Z.db.contacts[key].target or key
            local token = key .. '\0' .. id
            if token == U.questOutgoingToken then
                selected = true
            end
            items[#items + 1] = {
                at = row.at or 0,
                key = key,
                id = id,
                row = row,
                target = target,
                content = content ~= '' and content or tr('Nicht mehr verfügbare Questanfrage'),
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
            selected = token == U.questOutgoingToken,
            icon = NAV_ICONS.quests,
            text = '|cffffd36b' .. entry.content .. '|r\n' .. entry.target .. ' · ' .. stateName(entry.row.state) .. ' · ' .. date(
                '%d.%m. %H:%M',
                entry.at
            ) .. '\n' .. peerLocationLine(entry.key, tr('Leader-Ort')),
            click = function()
                U.questOutgoingToken = token
                S.refreshQuestOutgoing()
            end,
        }
    end
    if not selected then
        U.questOutgoingToken = nil
    end
    U.SetEmptyHint(U.questOutgoingList, 'You have not offered help yet. Open Quest Requests and press Offer help.')
    rows(U.questOutgoingList, display, 68)
    U.questOutgoingCount:SetText(#display == 1 and tr('1 Hilfsangebot') or #display .. tr(' Hilfsangebote'))
    local chosen
    for _, entry in ipairs(items) do
        if entry.token == U.questOutgoingToken then
            chosen = entry
        end
    end
    if not chosen then
        U.questOutgoingDetail:SetText(tr('Select a help offer.'))
        U.questOutgoingWithdraw:SetEnabled(false)
        return
    end
    Z.Notifications.ReadVisible('quests', 'outgoing', 'quests:outgoing:' .. chosen.key .. ':' .. chosen.id)
    U.questOutgoingDetail:SetText(
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
            .. '\nTransport: '
            .. deliveryState('quest', chosen.id, chosen.key)
            .. '\n'
            .. (I.isGerman and 'Stand: ' or 'As of: ')
            .. date('%d.%m.%Y %H:%M', chosen.at)
    )
    U.questOutgoingWithdraw:SetEnabled(chosen.row.state == 'applied' or chosen.row.state == 'invited')
end
function U.SetQuestView(v)
    U.questView = v
    if U.sharedQuestFrame then
        U.sharedQuestFrame:SetShown(v == 'shared')
    end
    if U.questGroupFrame then
        U.questGroupFrame:SetShown(v == 'questgroups')
    end
    selectNav(U.questGroupTab, v == 'questgroups')
    selectNav(U.sharedQuestTab, v == 'shared')
    U.questBrowseFrame:SetShown(v == 'browse')
    U.questMineFrame:SetShown(v == 'mine')
    if v ~= 'mine' then
        U.questMineEmpty:Hide()
        U.questMineSummary:Hide()
        U.questForm:Hide()
    end
    if U.questOutgoingFrame then
        U.questOutgoingFrame:SetShown(v == 'outgoing')
    end
    selectNav(U.questBrowseTab, v == 'browse')
    selectNav(U.questMineTab, v == 'mine')
    selectNav(U.questOutgoingTab, v == 'outgoing')
    updateNavPath()
    if Z.UIState then
        Z.UIState.Route('quests', v)
    end
    if v == 'outgoing' then
        S.refreshQuestOutgoing()
    end
    U.Refresh()
end
local function questOptions()
    local o = { tr('Manuell / Levelgruppe') }
    U.questMap = {}
    for _, q in ipairs(Z.QuestHelper and Z.QuestHelper.sampleAt and Z.QuestHelper.quests or A.GetQuests()) do
        local text = (q.level and q.level > 0 and '[' .. q.level .. '] ' or '') .. q.title
        o[#o + 1] = text
        U.questMap[text] = q
    end
    return o
end
function U.FilterQuestPicker()
    local all = questOptions()
    local query = string.lower(U.questPickerSearch and U.questPickerSearch:GetText() or '')
    local filtered = { all[1] }
    for i = 2, #all do
        if query == '' or string.lower(all[i]):find(query, 1, true) then
            filtered[#filtered + 1] = all[i]
        end
    end
    U.questPicker:SetOptions(filtered, U.questPicker:GetText())
end
function U.CaptureQuestDraft()
    if S.restoringDraft or not U.questEditing or not U.questFields then
        return
    end
    local draft = { editID = U.questEditID or '', questID = U.questEditQuestID or 0, duration = U.questDuration:GetText() }
    for key, field in pairs(U.questFields) do
        draft[key] = field:GetText()
    end
    if Z.UIState then
        Z.UIState.ActivityInput('quest', draft)
    end
    if U.questNoteCount then
        U.questNoteCount:SetText(#(draft.note or '') .. ' / 96')
    end
    if U.questFormPreview then
        U.questFormPreview:SetText(
            '|cffffd36bVORSCHAU|r\n'
                .. (draft.title ~= '' and draft.title or 'Titel eingeben')
                .. ((draft.zone or '') ~= '' and '\n' .. draft.zone or '')
                .. '\nLevel '
                .. (draft.min or '')
                .. '–'
                .. (draft.max or '')
                .. ((draft.note or '') ~= '' and '\n\n' .. draft.note or '')
        )
    end
end
function U.ValidateQuestForm()
    if not L.Text(U.questFields.title:GetText(), 96) then
        U.questFields.title:SetFocus()
        U.Message(tr('Bitte einen Titel oder eine Levelgruppe angeben.'))
        return false
    end
    local min, max, duration =
        tonumber(U.questFields.min:GetText()), tonumber(U.questFields.max:GetText()), tonumber(U.questDuration:GetText())
    if not L.Int(min, 1, 100) then
        U.questFields.min:SetFocus()
        U.Message(tr('Level von ist ungültig.'))
        return false
    end
    if not L.Int(max, min, 100) then
        U.questFields.max:SetFocus()
        U.Message(tr('Level bis ist ungültig.'))
        return false
    end
    if not L.Int(duration, 1, 120) then
        U.questDuration:SetFocus()
        U.Message(tr('Die Laufzeit muss zwischen 1 und 120 Minuten liegen.'))
        return false
    end
    return true
end
function U.DiscardQuestDraft()
    if Z.UIState then
        Z.UIState.ActivityInput('quest', false)
    end
    U.questEditing = false
    U.questEditID = nil
    U.questForm:Hide()
    U.Refresh()
end
function U.OpenQuestEditor(q)
    local draft = not q and Z.UIState and Z.UIState.ActivityInput('quest')
    S.restoringDraft = true
    U.questEditing = true
    U.questEditID = q and q.id or draft and draft.editID ~= '' and draft.editID or nil
    U.questEditQuestID = q and q.questID or draft and tonumber(draft.questID) or 0
    U.questMineEmpty:Hide()
    U.questMineSummary:Hide()
    U.questForm:Show()
    if U.questPickerSearch then
        U.questPickerSearch:SetText('')
    end
    U.questPicker:SetOptions(questOptions(), tr('Manuell / Levelgruppe'))
    local v = q or draft or { title = '', zone = '', min = 1, max = 60, note = '' }
    for k, e in pairs(U.questFields) do
        e:SetText(tostring(v[k] or ''))
    end
    U.questDuration:SetText(tostring(q and math.max(1, math.ceil((q.expires - A.Now()) / 60)) or draft and draft.duration or 60))
    U.questSave:SetText(q and tr('Änderungen speichern') or tr('Questanfrage veröffentlichen'))
    S.restoringDraft = false
    U.CaptureQuestDraft()
    U.Navigation.Pristine('activityCreator')
end
local function refreshQuestApplicants()
    local q = Z.db.quest
    local bucket = q and Z.db.questInterests[q.id] or {}
    local open = 0
    local items = {}
    local valid = false
    for _, key in ipairs(keys(bucket)) do
        local r = bucket[key]
        if r.state == 'applied' then
            open = open + 1
        end
        if key == U.questApplicantKey then
            valid = true
        end
        local target = Z.db.contacts[key] and Z.db.contacts[key].target or key
        local applicantKey = key
        items[#items + 1] = {
            selected = key == U.questApplicantKey,
            icon = NAV_ICONS.quests,
            text = target
                .. ' · '
                .. stateName(r.state)
                .. '\n'
                .. peerLocationLine(key, 'Location')
                .. (r.note ~= '' and '\n' .. r.note or ''),
            click = function()
                U.questApplicantKey = applicantKey
                if q then
                    L.MarkApplicationsRead(Z.db, 'quest', q.id, applicantKey)
                    Z.Notifications.ReadVisible('quests', 'mine', 'quests:mine:' .. applicantKey .. ':' .. q.id)
                end
                refreshQuestApplicants()
                U.UpdateBadges()
            end,
        }
    end
    if not valid then
        U.questApplicantKey = nil
    end
    U.questApplicantCount:SetText(tr('My helpers') .. ' (' .. open .. ')')
    U.SetEmptyHint(U.questApplicantList, 'No helpers yet. They appear here as soon as someone offers help.')
    rows(U.questApplicantList, items, 64)
    local r = U.questApplicantKey and bucket[U.questApplicantKey]
    if r and q then
        Z.Notifications.ReadVisible('quests', 'mine', 'quests:mine:' .. U.questApplicantKey .. ':' .. q.id)
    end
    local enabled = r and r.state == 'applied'
    U.questAccept:SetEnabled(enabled and peerOnline(U.questApplicantKey) or false)
    U.questReject:SetEnabled(enabled and true or false)
    U.questApplicantWhisper:SetEnabled(r and true or false)
    U.questApplicantLocation:SetText(
        U.questApplicantKey and peerLocationLine(U.questApplicantKey, 'Helper location')
            or tr('Current location') .. '\n' .. tr('Choose a helper.')
    )
    U.questPriorContacts:SetText(priorContactsText(U.questApplicantKey, q and q.id))
    U.questHistoryOpen:SetEnabled(U.questApplicantKey ~= nil)
end
S.refreshQuestMine = function()
    local editingDialog = U.questEditing and U.activityStepBody == U.questForm and U.activityCreator and U.activityCreator:IsShown()
    if U.questView ~= 'mine' and not editingDialog then
        U.questMineEmpty:Hide()
        U.questMineSummary:Hide()
        U.questForm:Hide()
        return
    end
    local q = Z.db.quest
    if U.questEditing then
        if U.questEditID and (not q or q.id ~= U.questEditID) then
            U.questEditing = false
            U.questForm:Hide()
        else
            U.questForm:Show()
            refreshQuestApplicants()
            return
        end
    end
    U.questForm:Hide()
    U.questMineEmpty:SetShown(not q)
    U.questMineSummary:SetShown(q ~= nil)
    if q then
        U.questOwnSummary:SetText(
            '|cffffd36b'
                .. q.title
                .. '|r'
                .. (q.zone ~= '' and ' · ' .. q.zone or '')
                .. ' · Level '
                .. q.min
                .. '–'
                .. q.max
                .. tr('\nLäuft noch ')
                .. math.max(1, math.ceil((q.expires - A.Now()) / 60))
                .. tr(' Minuten')
                .. (q.note ~= '' and '\n' .. q.note or '')
        )
        refreshQuestApplicants()
    end
end
local function decideQuest(state)
    state = L.ApplicationState(state) or state
    local q = Z.db.quest
    local key = U.questApplicantKey
    local row = q and Z.db.questInterests[q.id] and Z.db.questInterests[q.id][key]
    if not q or not row or row.state ~= 'applied' then
        U.Message(tr('Hilfsangebot nicht mehr aktiv.'))
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
        local ok, err = A.Invite(c.target)
        if not ok then
            U.Message(err)
            return
        end
        row.state = state
        row.at = A.Now()
        Z.RecordDecision('quest', key, q.id, state, q)
        local sent, e = Z.Queue(key, { kind = 'QS', id = q.id, state = state })
        U.Message(
            sent and tr('Invitation submitted; awaiting response.')
                or (e or tr('Invitation submitted; addon status could not be delivered.'))
        )
    else
        local sent, e = Z.Queue(key, { kind = 'QS', id = q.id, state = state })
        if not sent then
            U.Message(e)
            return
        end
        row.state = state
        row.at = A.Now()
        Z.RecordDecision('quest', key, q.id, state, q)
        U.Message('')
    end
    U.Refresh()
end
S.decideQuest = decideQuest
U.DecideQuestApplicant = decideQuest

