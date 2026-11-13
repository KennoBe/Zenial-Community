local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local S = U.Shared
local tr = S.tr
local DUNGEONS, PVP, label, button, navButton, edit, selector = S.DUNGEONS, S.PVP, S.label, S.button, S.navButton, S.edit, S.selector
local checkbox, list, rows, peerOnline, activityName, panel = S.checkbox, S.list, S.rows, S.peerOnline, S.activityName, S.panel
local panelContent, selectedPvpCall, decideGroup, showControl = S.panelContent, S.selectedPvpCall, S.decideGroup, S.showControl
local makeModal = S.makeModal

function S.createGroupsPage(f)
    local p = U.pages[3]
    U.activityScopeDiscover = navButton(p, 'Discover', 0, 0, 112, function() U.Navigate('activities') end)
    U.activityScopeOrganized = navButton(p, 'Organized', 118, 0, 112, function() U.Navigate('activities', 'mine') end)
    U.activityScopeApplications = navButton(p, 'Applications', 236, 0, 126, function() U.Navigate('groups', 'outgoing') end)
    U.activityScopePlanned = navButton(p, 'Planned', 368, 0, 112, function() U.Navigate('activities', 'planned') end)
    U.activityScopeArchive = navButton(p, 'Archive', 486, 0, 112, U.OpenActivityArchive)
    U.groupBrowseTab = navButton(p, 'Group Search', 0, 0, 150, function()
        U.SetGroupView('browse')
    end)
    U.groupMineTab = navButton(p, 'My Group', 160, 0, 140, function()
        U.SetGroupView('mine')
    end)
    U.groupFollowTab = navButton(p, 'Follow Activities', 310, 0, 180, function()
        U.SetGroupView('follow')
    end)
    U.pvpTab = navButton(p, 'PvP Help', 500, 0, 170, function()
        U.SetGroupView('pvp')
    end)
    U.groupBrowseFrame = CreateFrame('Frame', nil, p)
    U.groupBrowseFrame:SetPoint('TOPLEFT', 0, -36)
    U.groupBrowseFrame:SetSize(856, 414)
    U.groupBrowseList = list(U.groupBrowseFrame, 0, 0, 410, 370)
    U.groupBrowseDetail = label(U.groupBrowseFrame, 'Select a group.', 430, 0, 416, 'GameFontHighlight')
    U.groupBrowseDetail:SetHeight(205)
    U.groupApplyState = label(U.groupBrowseFrame, '', 430, -205, 416)
    U.groupApplyStart = button(U.groupBrowseFrame, 'Apply', 430, -230, 125, function()
        U.groupApplyOpen = true
        U.groupRole:SetText(L.Role(Z.db.roles) or 'DAMAGER')
        U.groupApplyFrame:Show()
        S.refreshGroupBrowse()
    end)
    U.groupWithdraw = button(U.groupBrowseFrame, 'Withdraw', 430, -230, 125, function()
        local q, e = Z.WithdrawGroup(U.groupKey, U.groupID)
        U.Message(q and 'Application withdrawn.' or e)
        U.Refresh()
    end)
    U.groupBrowseWhisper = button(U.groupBrowseFrame, 'Whisper', 565, -230, 125, function()
        local c = Z.db.contacts[U.groupKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.groupApplyFrame = CreateFrame('Frame', nil, U.groupBrowseFrame)
    U.groupApplyFrame:SetPoint('TOPLEFT', 430, -260)
    U.groupApplyFrame:SetSize(416, 145)
    U.groupRole = selector(U.groupApplyFrame, 'My role', 0, 0, 125, { 'TANK', 'HEALER', 'DAMAGER' })
    U.groupApplyNote = edit(U.groupApplyFrame, 'Application note (optional)', 140, 0, 270, 64)
    U.groupApplicationSend = button(U.groupApplyFrame, 'Apply', 0, -55, 165, function()
        local q, e = Z.ApplyGroup(U.groupKey, U.groupID, U.groupRole:GetText(), U.groupApplyNote:GetText())
        if q then
            U.groupApplyOpen = false
            U.Message('Application sent.')
        else
            U.Message(e)
        end
        U.Refresh()
    end)
    U.groupApplicationCancel = button(U.groupApplyFrame, 'Cancel', 175, -55, 125, function()
        U.groupApplyOpen = false
        U.groupApplyFrame:Hide()
        S.refreshGroupBrowse()
    end)
    U.groupApplyFrame:Hide()
    U.groupFilterKind = selector(
        U.groupBrowseFrame,
        tr('Kategorie'),
        0,
        0,
        175,
        { 'Alle Kategorien', 'PvP', 'Dungeons', 'Raids', 'Eigene Aktivität' },
        function(v)
            U.SetGroupFilterKind(v)
        end
    )
    U.groupFilterActivity = selector(U.groupBrowseFrame, tr('Aktivität'), 185, 0, 255, { 'Alle Aktivitäten' }, S.refreshGroupBrowse)
    U.groupFilterSearch = edit(U.groupBrowseFrame, tr('Notiz durchsuchen'), 450, 0, 300, 96)
    U.groupFilterSearch:SetScript('OnTextChanged', S.refreshGroupBrowse)
    U.groupBrowseCount = label(U.groupBrowseFrame, tr('0 offene Gruppen'), 760, -21, 95)
    U.groupMatchLevel = checkbox(U.groupBrowseFrame, tr('Mein Level passt'), 0, -45, 160, function()
        S.refreshGroupBrowse()
    end)
    U.groupMatchRole = checkbox(U.groupBrowseFrame, tr('Meine Rolle wird gesucht'), 175, -45, 205, function()
        S.refreshGroupBrowse()
    end)
    U.groupMatchAvailable = checkbox(U.groupBrowseFrame, tr('Nur verfügbare Leiter'), 395, -45, 200, function()
        S.refreshGroupBrowse()
    end)
    U.groupBrowseList:ClearAllPoints()
    U.groupBrowseList:SetPoint('TOPLEFT', 0, -82)
    U.groupBrowseList:SetSize(410, 288)
    U.groupBrowseDetail:ClearAllPoints()
    U.groupBrowseDetail:SetPoint('TOPLEFT', 430, -82)
    U.groupBrowseDetail:SetHeight(136)
    U.groupApplyState:ClearAllPoints()
    U.groupApplyState:SetPoint('TOPLEFT', 430, -218)
    U.groupApplyStart:ClearAllPoints()
    U.groupApplyStart:SetPoint('TOPLEFT', 430, -243)
    U.groupWithdraw:ClearAllPoints()
    U.groupWithdraw:SetPoint('TOPLEFT', 430, -243)
    U.groupBrowseWhisper:ClearAllPoints()
    U.groupBrowseWhisper:SetPoint('TOPLEFT', 565, -243)
    U.groupApplyFrame:ClearAllPoints()
    U.groupApplyFrame:SetPoint('TOPLEFT', 430, -273)
    U.groupApplyFrame:SetSize(416, 135)
    U.groupBack = button(U.groupBrowseFrame, tr('← Zurück zur Liste'), 665, 0, 180, function()
        U.CloseCompactArea('groups')
    end)
    U.groupBack:Hide()
    U.groupMineFrame = CreateFrame('Frame', nil, p)
    U.groupMineFrame:SetPoint('TOPLEFT', 0, -36)
    U.groupMineFrame:SetSize(856, 414)
    U.groupMineEmpty = panel(U.groupMineFrame)
    label(U.groupMineEmpty, tr('Du hast keine aktive Gruppe.'), 12, -10, 500, 'GameFontHighlight')
    button(U.groupMineEmpty, 'Create group or template', 12, -45, 240, function()
        U.OpenGroupEditor(nil)
    end)
    U.groupTemplate = selector(U.groupMineEmpty, 'Manage templates', 12, -90, 280, { 'Choose template' }, function(value)
        if U.groupTemplateDelete then
            U.groupTemplateDelete:SetEnabled(Z.db.groupTemplates[value] ~= nil)
        end
    end)
    button(U.groupMineEmpty, 'Use template', 305, -107, 165, function()
        local g = Z.GroupFinder.FromTemplate(U.groupTemplate:GetText())
        if g then
            U.OpenGroupEditor(g)
        else
            U.Message('Choose a template first.')
        end
    end)
    U.groupTemplateDelete = button(U.groupMineEmpty, 'Delete template', 480, -107, 150, function()
        local ok, err = Z.GroupFinder.DeleteTemplate(U.groupTemplate:GetText())
        U.Message(ok and 'Group template deleted.' or err)
        if ok then
            U.groupTemplate:SetText('Choose template')
            S.refreshGroupMine()
        end
    end, 'danger')
    U.groupTemplateDelete:SetEnabled(false)
    -- Template actions are explicit in the editor; no repeated instruction block.
    U.groupMineSummary = panel(U.groupMineFrame)
    U.groupOwnSummary = label(U.groupMineSummary, '', 12, -10, 816, 'GameFontHighlight')
    U.groupOwnSummary:SetHeight(60)
    button(U.groupMineSummary, tr('Bearbeiten'), 0, -78, 125, function()
        U.OpenGroupEditor(Z.db.lfg[1])
    end)
    button(U.groupMineSummary, tr('Löschen'), 135, -78, 125, function()
        local g = Z.db.lfg[1]
        if g and Z.CloseGroup(g.id) then
            U.groupApplicantKey = nil
            U.Publish()
        end
    end)
    U.groupOwnTemplate = button(U.groupMineSummary, tr('Als Vorlage speichern'), 270, -78, 190, function()
        local g = Z.db.lfg[1]
        if not g then
            return
        end
        U.OpenGroupEditor(g)
        U.groupTemplateName:SetText(activityName(g.activity))
        U.groupTemplateDuration:SetText(tostring(math.max(1, math.ceil((g.expires - A.Now()) / 60))))
        U.Message('Check the template name and save it below.')
    end)
    U.groupOwnTemplate:Hide()
    U.groupActiveTemplate = selector(U.groupMineSummary, 'Manage templates', 12, -111, 275, { 'Choose template' }, function(value)
        U.groupActiveTemplateDelete:SetEnabled(Z.db.groupTemplates[value] ~= nil)
    end)
    U.groupActiveTemplateUse = button(U.groupMineSummary, 'Use template', 302, -111, 150, function()
        local g = Z.GroupFinder.FromTemplate(U.groupActiveTemplate:GetText())
        if not g then
            U.Message('Choose a template first.')
            return
        end
        local current = Z.db.lfg[1]
        if current then g.id = current.id end
        U.OpenGroupEditor(g)
    end, 'primary')
    U.groupActiveTemplateDelete = button(U.groupMineSummary, 'Delete template', 462, -111, 150, function()
        local ok, err = Z.GroupFinder.DeleteTemplate(U.groupActiveTemplate:GetText())
        U.Message(ok and 'Group template deleted.' or err)
        if ok then
            U.groupActiveTemplate:SetText('Choose template')
            S.refreshGroupMine()
        end
    end, 'danger')
    U.groupActiveTemplateDelete:SetEnabled(false)
    -- Below the template row (its dropdown ends at 154): the heading no longer sits under the dropdown.
    U.groupApplicantCount = label(U.groupMineSummary, tr('Eigene Bewerber (0)'), 0, -164, 350, 'GameFontNormal')
    U.groupApplicantList = list(U.groupMineSummary, 0, -186, 545, 193)
    U.groupAccept = button(U.groupMineSummary, tr('Annehmen & einladen'), 565, -143, 200, function()
        decideGroup('eingeladen')
    end)
    U.groupReject = button(U.groupMineSummary, tr('Ablehnen'), 565, -177, 125, function()
        decideGroup('abgelehnt')
    end)
    U.groupApplicantWhisper = button(U.groupMineSummary, tr('Anflüstern'), 565, -211, 125, function()
        local c = Z.db.contacts[U.groupApplicantKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.groupApplicantLocation =
        label(U.groupMineSummary, tr('Aufenthaltsort\nWähle einen Bewerber aus.'), 565, -250, 285, 'GameFontHighlightSmall')
    U.groupApplicantLocation:SetHeight(35)
    U.groupPriorContacts = label(U.groupMineSummary, tr('Bisherige Kontakte'), 565, -291, 285)
    U.groupPriorContacts:SetHeight(64)
    U.groupHistoryOpen = button(U.groupMineSummary, tr('Gesamten Verlauf anzeigen'), 565, -366, 220, function()
        U.OpenHistory(U.groupApplicantKey)
    end)
    U.groupForm = panel(U.groupMineFrame)
    U.groupKind = selector(U.groupForm, 'Category', 12, 0, 165, { 'PVP', 'DUNGEON', 'RAID', 'CUSTOM' }, function(v)
        U.GroupKind(v)
    end)
    U.groupActivity = selector(U.groupForm, 'Activity', 192, 0, 260, DUNGEONS, function(v)
        U.GroupActivity(v)
    end)
    U.groupCustom = edit(U.groupForm, 'Activity', 192, 0, 260, 64)
    U.groupActivitySearch = edit(U.groupForm, 'Search activity', 467, 0, 135, 64)
    U.groupActivitySearch:SetScript('OnTextChanged', U.FilterGroupActivities)
    U.groupFields = {}
    U.groupFields.min = edit(U.groupForm, 'Level from', 12, -56, 80, 3)
    U.groupFields.max = edit(U.groupForm, 'Level to', 107, -56, 80, 3)
    U.groupFields.size = edit(U.groupForm, 'Target size', 202, -56, 80, 2)
    U.groupFields.tank = edit(U.groupForm, 'Tank needed', 297, -56, 90, 2)
    U.groupFields.healer = edit(U.groupForm, 'Healer needed', 402, -56, 90, 2)
    U.groupFields.dd = edit(U.groupForm, 'Damage needed', 507, -56, 95, 2)
    U.groupHaveCaption = label(U.groupForm, 'Current group', 627, -56, 217)
    U.groupHave = label(U.groupForm, '', 627, -76, 217)
    U.groupFields.note = edit(U.groupForm, 'Note (optional)', 12, -118, 590, 96, true)
    U.groupNoteCount = label(U.groupForm, '0 / 96', 520, -187, 82)
    U.groupNoteCount:SetJustifyH('RIGHT')
    U.groupFormPreview = label(U.groupForm, '|cffffd36bPREVIEW|r', 627, -118, 217, 'GameFontHighlight')
    U.groupFormPreview:SetHeight(150)
    if U.groupFormPreview.SetWordWrap then
        U.groupFormPreview:SetWordWrap(true)
    end
    if U.groupFormPreview.SetNonSpaceWrap then
        U.groupFormPreview:SetNonSpaceWrap(true)
    end
    U.groupSave = button(U.groupForm, 'Publish group', 12, -225, 190, function()
        local now = A.Now()
        if not U.ValidateGroupForm() then
            return
        end
        if not U.groupEditID and Z.db.lfg[1] and Z.db.lfg[1].expires > now then
            U.Message('Archive your current group before creating another.')
            return
        end
        if not L.Int(tonumber(U.groupTemplateDuration:GetText()), 1, 1440) then
            U.Message('The duration must be between 1 and 1440 minutes.')
            return
        end
        if U.groupEditID and (not Z.db.lfg[1] or Z.db.lfg[1].id ~= U.groupEditID) then
            U.Message('This activity is no longer active. Close the form and open it again.')
            return
        end
        local g = {
            id = U.groupEditID,
            mode = 'LFM',
            activity = U.groupKind:GetText() == 'CUSTOM' and U.groupCustom:GetText() or U.groupActivity:GetText(),
            have = A.GroupRoles(),
            start = U.groupEditID and Z.db.lfg[1].start or now,
            expires = U.groupEditID and Z.db.lfg[1].expires or now + (tonumber(U.groupTemplateDuration:GetText()) or 120) * 60,
        }
        for k, e in pairs(U.groupFields) do
            g[k] = k == 'note' and e:GetText() or tonumber(e:GetText())
        end
        local id, err = Z.SaveGroup(g, now)
        if id then
            U.groupEditing = false
            U.groupForm:Hide()
            U.Publish()
        else
            U.Message(err)
        end
    end, 'primary')
    U.groupFormBack = button(U.groupForm, 'Back', 212, -225, 115, function()
        U.BackActivityStep()
    end)
    U.groupDiscard = button(U.groupForm, 'Discard draft', 337, -225, 165, function()
        U.DiscardGroupDraft()
    end, 'danger')
    U.groupTemplateName = edit(U.groupForm, 'Template name', 12, -275, 220, 64)
    U.groupTemplateDuration = edit(U.groupForm, 'Duration (min.)', 247, -275, 115, 4)
    U.groupTemplateDuration:SetScript('OnTextChanged', U.CaptureGroupDraft)
    U.groupTemplateName:SetScript('OnTextChanged', U.CaptureGroupDraft)
    U.groupTemplateSave = button(U.groupForm, 'Save template', 377, -292, 180, U.SaveGroupTemplate)
    U.groupTemplateHint = label(U.groupForm, 'Saves locally without publishing the group.', 572, -292, 272)
    for _, field in pairs(U.groupFields) do
        field:SetScript('OnTextChanged', U.CaptureGroupDraft)
    end
    U.groupCustom:SetScript('OnTextChanged', U.CaptureGroupDraft)
    U.groupForm:Hide()
    U.groupView = 'browse'
    U.groupFollowFrame = CreateFrame('Frame', nil, p)
    U.groupFollowFrame:SetPoint('TOPLEFT', 0, -36)
    U.groupFollowFrame:SetSize(856, 414)
    label(
        U.groupFollowFrame,
        tr('Wähle Aktivitäten aus, bei deren neu veröffentlichten Gruppen du benachrichtigt werden möchtest.'),
        0,
        0,
        850,
        'GameFontHighlight'
    )
    U.followKind = selector(U.groupFollowFrame, tr('Kategorie'), 0, -42, 190, { 'PvP', 'Dungeons', 'Raids' }, function(v)
        U.FollowKind(v)
    end)
    U.followActivity = selector(U.groupFollowFrame, tr('Aktivität'), 210, -42, 330, PVP)
    button(U.groupFollowFrame, tr('Folgen'), 560, -59, 125, function()
        U.AddGroupFollow()
    end)
    U.followCount = label(U.groupFollowFrame, tr('0 Aktivitäten gefolgt'), 0, -105, 350, 'GameFontNormal')
    U.followList = list(U.groupFollowFrame, 0, -128, 430, 250)
    U.followDetail = label(U.groupFollowFrame, tr('Wähle links eine gefolgte Aktivität aus.'), 460, -128, 380, 'GameFontHighlight')
    U.followDetail:SetHeight(105)
    U.followRemove = button(U.groupFollowFrame, tr('Nicht mehr folgen'), 460, -245, 170, function()
        U.RemoveGroupFollow()
    end)
    U.followKind:SetText('PvP')
    U.FollowKind('PvP')
    U.groupFollowFrame:Hide()

    U.groupBrowseTab:SetWidth(136)
    U.groupMineTab:ClearAllPoints()
    U.groupMineTab:SetPoint('TOPLEFT', 142, 0)
    U.groupMineTab:SetWidth(136)
    U.groupOutgoingTab = navButton(p, tr('Meine Bewerbungen'), 284, 0, 136, function()
        U.SetGroupView('outgoing')
    end)
    U.groupFollowTab:ClearAllPoints()
    U.groupFollowTab:SetPoint('TOPLEFT', 426, 0)
    U.groupFollowTab:SetWidth(136)
    U.sessionPlanTab = navButton(p, 'Today', 568, 0, 136, function()
        U.SetGroupView('today')
    end)
    U.pvpTab:ClearAllPoints()
    U.pvpTab:SetPoint('TOPLEFT', 710, 0)
    U.pvpTab:SetWidth(136)
    U.CreateSessionPlans(p)
    U.scheduledTab = navButton(p, tr('Scheduled'), 610, 0, 116, function()
        U.SetGroupView('scheduled')
    end)
    for i, tab in ipairs({ U.groupBrowseTab, U.groupMineTab, U.groupOutgoingTab, U.groupFollowTab, U.sessionPlanTab, U.scheduledTab, U.pvpTab }) do
        tab:ClearAllPoints()
        tab:SetPoint('TOPLEFT', (i - 1) * 122, 0)
        tab:SetWidth(116)
    end
    U.groupOutgoingTab:SetText(tr('Applications'))
    U.groupFollowTab:SetText(tr('Follow'))
    U.CreateScheduledGroups(
        p,
        {
            label = label,
            button = button,
            list = list,
            rows = rows,
            edit = edit,
            selector = selector,
            checkbox = checkbox,
            panel = panel,
            showControl = showControl,
            makeModal = makeModal,
        }
    )
    U.groupOutgoingFrame = CreateFrame('Frame', nil, p)
    U.groupOutgoingFrame:SetPoint('TOPLEFT', 0, -36)
    U.groupOutgoingFrame:SetSize(856, 414)
    U.groupOutgoingCount = label(U.groupOutgoingFrame, tr('0 Bewerbungen'), 0, 0, 300, 'GameFontNormal')
    U.groupOutgoingList = list(U.groupOutgoingFrame, 0, -28, 460, 355)
    U.groupOutgoingDetail = label(U.groupOutgoingFrame, tr('Wähle eine Bewerbung aus.'), 490, -28, 350, 'GameFontHighlight')
    U.groupOutgoingDetail:SetHeight(170)
    U.groupOutgoingWithdraw = button(U.groupOutgoingFrame, tr('Bewerbung zurückziehen'), 490, -215, 210, function()
        if not U.groupOutgoingToken then
            return
        end
        local key, id = U.groupOutgoingToken:match('^(.-)%z(.+)$')
        local ok, err = Z.WithdrawGroup(key, id)
        U.Message(ok and tr('Bewerbung zurückgezogen.') or err)
        U.Refresh()
    end, 'danger')
    U.activityQuestApplications = button(U.groupOutgoingFrame, tr('Quest applications'), 490, -254, 210, function()
        U.Navigate('quests', 'outgoing')
    end)
    U.groupOutgoingFrame:Hide()
    U.groupPvpFrame = CreateFrame('Frame', nil, p)
    U.groupPvpFrame:SetPoint('TOPLEFT', 0, -36)
    U.groupPvpFrame:SetSize(856, 414)
    U.pvpReceive = checkbox(U.groupPvpFrame, 'Receive PvP help requests', 330, -1, 220, function(self)
        Z.PvPHelp.SetReceive(self:GetChecked())
    end)
    U.pvpScope = selector(U.groupPvpFrame, 'Area filter', 570, 0, 270, { 'ALL_ZONES', 'CURRENT_ZONE' }, function(v)
        Z.PvPHelp.SetScope(v == 'CURRENT_ZONE' and 'zone' or 'all')
    end)
    U.pvpCallsPanel = CreateFrame('Frame', nil, U.groupPvpFrame)
    U.pvpCallsPanel:SetPoint('TOPLEFT', 0, -58)
    U.pvpCallsPanel:SetSize(856, 356)
    U.pvpCallList = list(U.pvpCallsPanel, 0, 0, 395, 350)
    U.pvpCallDetail = label(U.pvpCallsPanel, tr('Wähle einen aktiven PvP-Hilferuf aus.'), 420, 0, 425, 'GameFontHighlight')
    U.pvpCallDetail:SetHeight(205)
    U.pvpCome = button(U.pvpCallsPanel, tr('Ich komme'), 420, -218, 175, function()
        local r = selectedPvpCall()
        if r then
            local state = r.response == 'coming' and 'withdrawn' or 'coming'
            local ok, err = Z.PvPHelp.Respond(r.key, r.id, state)
            U.Message(ok and (state == 'coming' and tr('Zusage gesendet.') or tr('Zusage zurückgezogen.')) or err)
        end
    end)
    U.pvpMap = button(U.pvpCallsPanel, tr('Auf Karte zeigen'), 605, -218, 150, function()
        local r = selectedPvpCall()
        if r then
            A.ShowMap(r.mapID)
        end
    end)
    U.pvpWaypoint = button(U.pvpCallsPanel, tr('Wegpunkt setzen'), 420, -252, 175, function()
        local r = selectedPvpCall()
        if r then
            local ok, err = A.SetWaypoint(r.mapID, r.x, r.y)
            U.Message(ok and tr('Wegpunkt gesetzt.') or err)
        end
    end)
    U.pvpWhisper = button(U.pvpCallsPanel, tr('Anflüstern'), 605, -252, 150, function()
        local r = selectedPvpCall()
        local c = r and Z.db.contacts[r.key]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.pvpBlock = button(U.pvpCallsPanel, tr('Blockieren'), 605, -286, 150, function()
        local r = selectedPvpCall()
        if r then
            Z.Block(r.key)
            U.pvpCallKey, U.pvpCallID = nil, nil
            U.Refresh()
        end
    end)
    U.pvpMinePanel = CreateFrame('Frame', nil, U.groupPvpFrame)
    U.pvpMinePanel:SetPoint('TOPLEFT', 0, 0)
    U.pvpMinePanel:SetSize(856, 414)
    U.pvpMineBase = panel(U.pvpMinePanel)
    U.pvpMineContent = panelContent(U.pvpMineBase)
    U.pvpMineStatus = label(U.pvpMineContent, '', 0, 0, 832, 'GameFontHighlight')
    U.pvpMineStatus:SetHeight(76)
    U.pvpStart = button(U.pvpMineContent, tr('Werde gegankt. HILFE!'), 0, -82, 205, function()
        U.OpenPvpPreview()
    end)
    U.pvpOwnControls = CreateFrame('Frame', nil, U.pvpMineContent)
    U.pvpOwnControls:SetPoint('TOPLEFT', 0, -86)
    U.pvpOwnControls:SetSize(832, 35)
    button(U.pvpOwnControls, tr('Standort aktualisieren'), 0, 0, 180, function()
        local ok, err = Z.PvPHelp.UpdateLocation()
        U.Message(ok and tr('Standort aktualisiert.') or err)
    end)
    button(U.pvpOwnControls, tr('Erledigt'), 190, 0, 110, function()
        local ok, err = Z.PvPHelp.EndOwn()
        U.Message(ok and tr('Hilferuf beendet.') or err)
    end)
    U.pvpHelperCount = label(U.pvpMineContent, tr('Helfer zugesagt (0)'), 0, -132, 300, 'GameFontNormal')
    U.pvpHelperList = list(U.pvpMineContent, 0, -154, 520, 195)
    U.pvpInvite = button(U.pvpMineContent, tr('Einladen'), 545, -154, 125, function()
        if U.pvpHelperKey then
            if not peerOnline(U.pvpHelperKey) then
                U.Message('This player is offline.')
                U.RefreshPvPHelp()
                return
            end
            local ok, err = Z.PvPHelp.InviteHelper(U.pvpHelperKey)
            U.Message(ok and tr('Invitation submitted; awaiting response.') or err)
        end
    end)
    U.pvpHelperWhisper = button(U.pvpMineContent, tr('Anflüstern'), 680, -154, 125, function()
        local c = U.pvpHelperKey and Z.db.contacts[U.pvpHelperKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.pvpPreview = panel(U.pvpMinePanel)
    U.pvpPreviewContent = panelContent(U.pvpPreview)
    U.pvpPreviewLocation = label(U.pvpPreviewContent, '', 0, 0, 832, 'GameFontHighlight')
    U.pvpPreviewLocation:SetHeight(58)
    U.pvpPreviewEnemy = label(U.pvpPreviewContent, '', 0, -65, 832)
    U.pvpPreviewEnemy:SetHeight(45)
    U.pvpCallNote = edit(
        U.pvpPreviewContent,
        tr('Wer greift dich an? Anzahl und Level (optional, z. B. 3× Level 60)'),
        0,
        -116,
        520,
        96,
        true
    )
    U.pvpShareEnemy = checkbox(U.pvpPreviewContent, tr('Share detected PvP combat data'), 545, -128, 287)
    U.pvpConfirm = checkbox(U.pvpPreviewContent, tr('Ich werde von Spielern angegriffen'), 545, -184, 287)
    U.pvpSend = button(U.pvpPreviewContent, tr('Hilfe rufen'), 0, -248, 140, function()
        if not U.pvpConfirm:GetChecked() then
            U.Message(tr('Bestätige zuerst, dass Spieler dich angreifen.'))
            return
        end
        local id, err = Z.PvPHelp.CreateCall(U.pvpCallNote:GetText(), U.pvpShareEnemy:GetChecked())
        if id then
            U.pvpPreviewOpen = false
            U.Message(tr('Hilferuf wird versendet.'))
        else
            U.Message(err)
        end
        S.refreshPvPHelp()
    end)
    U.pvpCancel = button(U.pvpPreviewContent, tr('Abbrechen'), 150, -248, 125, function()
        U.pvpPreviewOpen = false
        U.pvpPreview:Hide()
        U.pvpMineBase:Show()
        S.refreshPvPHelp()
    end)
    U.pvpCallNote.caption:SetHeight(42)
    U.pvpCallNote:ClearAllPoints()
    U.pvpCallNote:SetPoint('TOPLEFT', 0, -164)
    U.pvpPreview:Hide()
    U.pvpView = 'calls'
    U.pvpMinePanel:Hide()
    U.groupPvpFrame:Hide()

    U.pvpReceive:ClearAllPoints()
    U.pvpReceive:SetPoint('TOPLEFT', 0, -1)
    U.pvpReceive.text:ClearAllPoints()
    U.pvpReceive.text:SetPoint('TOPLEFT', 27, -5)
    U.pvpTab:SetScript('OnClick', function()
        U.SetGroupView('pvp')
        U.SetPvpView('calls')
    end)
end
