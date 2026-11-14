local Z = ZenialCommunity
local U = Z.UI
local A = Z.Adapter
local S = U.Shared
local tr = S.tr
local label, button, navButton, edit, selector, list, panel = S.label, S.button, S.navButton, S.edit, S.selector, S.list, S.panel
local panelContent, decideQuest = S.panelContent, S.decideQuest

-- Plate behind the quest-help filters, scaled with the page width like the members page. It belongs to the
-- browse frame (so it is gone with it in the other sub views) and is hidden while the compact detail is open.
function U.LayoutQuestsVisual()
    local bar = U.questFilterBar
    if not bar then
        return
    end
    local page = U.pages and U.pages[4]
    local pageWidth = page and page:GetWidth()
    local horizontal = (type(pageWidth) == 'number' and pageWidth > 0 and pageWidth or 856) / 856
    bar:Place(0, 0, 850 * horizontal, 56)
    bar:SetShown(U.compactArea ~= 'quests')
end

function S.createQuestsPage(f)
    local p = U.pages[4]
    U.questBrowseTab = navButton(p, tr('Questanfragen'), 0, 0, 170, function()
        U.SetQuestView('browse')
    end)
    U.questMineTab = navButton(p, tr('Meine Questanfrage'), 180, 0, 190, function()
        U.SetQuestView('mine')
    end)
    U.questBrowseFrame = CreateFrame('Frame', nil, p)
    U.questBrowseFrame:SetPoint('TOPLEFT', 0, -36)
    U.questBrowseFrame:SetSize(856, 414)
    U.questBrowseList = list(U.questBrowseFrame, 0, 0, 410, 370)
    U.questBrowseDetail = label(U.questBrowseFrame, tr('Wähle eine Questanfrage aus.'), 430, 0, 416, 'GameFontHighlight')
    U.questBrowseDetail:SetHeight(205)
    U.questApplyState = label(U.questBrowseFrame, '', 430, -205, 416)
    U.questApplyStart = button(U.questBrowseFrame, tr('Hilfe anbieten'), 430, -230, 140, function()
        U.questApplyOpen = true
        U.questApplyFrame:Show()
        S.refreshQuestBrowse()
    end)
    U.questWithdraw = button(U.questBrowseFrame, tr('Zurückziehen'), 430, -230, 125, function()
        local q, e = Z.WithdrawQuest(U.questKey, U.questID)
        U.Message(q and tr('Hilfeangebot zurückgezogen.') or e)
        U.Refresh()
    end)
    U.questBrowseWhisper = button(U.questBrowseFrame, tr('Anflüstern'), 580, -230, 125, function()
        local c = Z.db.contacts[U.questKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.questApplyFrame = CreateFrame('Frame', nil, U.questBrowseFrame)
    U.questApplyFrame:SetPoint('TOPLEFT', 430, -260)
    U.questApplyFrame:SetSize(416, 145)
    U.questHelpNote = edit(U.questApplyFrame, tr('Nachricht (optional)'), 0, 0, 410, 64)
    U.questApplicationSend = button(U.questApplyFrame, tr('Hilfe anbieten'), 0, -55, 140, function()
        local q, e = Z.ApplyQuest(U.questKey, U.questID, U.questHelpNote:GetText())
        if q then
            U.questApplyOpen = false
            U.Message(tr('Hilfeangebot gesendet.'))
        else
            U.Message(e)
        end
        U.Refresh()
    end)
    U.questApplicationCancel = button(U.questApplyFrame, tr('Abbrechen'), 150, -55, 125, function()
        U.questApplyOpen = false
        U.questApplyFrame:Hide()
        S.refreshQuestBrowse()
    end)
    U.questApplyFrame:Hide()
    -- Filter bar: a plate of page textures behind the filters (placed by U.LayoutQuestsVisual).
    U.questFilterBar = Z.Kit and Z.Kit.FilterBar(U.questBrowseFrame)
    U.questFilterSearch = edit(U.questBrowseFrame, tr('Spieler, Titel oder Notiz'), 10, -6, 300, 96)
    U.questFilterZone = edit(U.questBrowseFrame, tr('Zone'), 325, -6, 210, 64)
    U.questFilterLevel = edit(U.questBrowseFrame, tr('Level'), 550, -6, 90, 3)
    U.questFilterSearch:SetScript('OnTextChanged', S.refreshQuestBrowse)
    U.questFilterZone:SetScript('OnTextChanged', S.refreshQuestBrowse)
    U.questFilterLevel:SetScript('OnTextChanged', S.refreshQuestBrowse)
    U.questFilterReset = button(U.questBrowseFrame, tr('Filter zurücksetzen'), 660, -23, 170, function()
        U.questFilterSearch:SetText('')
        U.questFilterZone:SetText('')
        U.questFilterLevel:SetText('')
        S.refreshQuestBrowse()
    end)
    U.questBrowseList:ClearAllPoints()
    U.questBrowseList:SetPoint('TOPLEFT', 0, -86)
    U.questBrowseList:SetSize(410, 284)
    U.questBrowseDetail:ClearAllPoints()
    U.questBrowseDetail:SetPoint('TOPLEFT', 430, -68)
    U.questBrowseCount = label(U.questBrowseFrame, '0 Questanfragen', 0, -64, 220, 'GameFontNormal')
    U.questBack = button(U.questBrowseFrame, tr('← Zurück zur Liste'), 665, 0, 180, function()
        U.CloseCompactArea('quests')
    end)
    U.questBack:Hide()
    U.LayoutQuestsVisual()
    U.sharedQuestTab = navButton(p, 'Shared Quests', 0, 0, 165, function()
        U.SetQuestView('shared')
    end)
    U.questGroupTab = navButton(p, 'Quest Groups', 171, 0, 165, function()
        U.SetQuestView('questgroups')
    end)
    U.questBrowseTab:ClearAllPoints()
    U.questBrowseTab:SetPoint('TOPLEFT', 342, 0)
    U.questBrowseTab:SetWidth(165)
    U.questBrowseTab:SetText(tr('Help Requests'))
    U.questMineTab:ClearAllPoints()
    U.questMineTab:SetPoint('TOPLEFT', 513, 0)
    U.questMineTab:SetWidth(165)
    U.questMineTab:SetText(tr('My Help Request'))
    U.questOutgoingTab = navButton(p, 'My Help Offers', 684, 0, 165, function()
        U.SetQuestView('outgoing')
    end)
    U.questGroupFrame = CreateFrame('Frame', nil, p)
    U.questGroupFrame:SetPoint('TOPLEFT', 0, -36)
    U.questGroupFrame:SetSize(856, 414)
    U.questGroupStatus = label(U.questGroupFrame, '', 0, 0, 846)
    U.questGroupStatus:SetHeight(20)
    U.questGroupList = list(U.questGroupFrame, 0, -26, 330, 280)
    U.questGroupHint = label(
        U.questGroupFrame,
        'Coverage: at least one fellow player. Shared by all: you and every proposed player. No guarantee of quest completion or reachability. Other party members are not counted.',
        0,
        -316,
        330
    )
    U.questGroupHint:SetHeight(88)
    U.questGroupSummary = label(U.questGroupFrame, '', 350, -26, 496, 'GameFontHighlight')
    U.questGroupSummary:SetHeight(42)
    U.questGroupMembers = list(U.questGroupFrame, 350, -74, 496, 112)
    -- Only shows which quests the members share and cannot be clicked: an info block, not a list of cells.
    U.questGroupQuests = Z.Kit.InfoBlock(list(U.questGroupFrame, 350, -192, 496, 112))
    U.questGroupActionState = label(U.questGroupFrame, '', 350, -312, 496)
    U.questGroupActionState:SetHeight(45)
    U.questGroupInvite = button(U.questGroupFrame, 'Invite', 350, -366, 145, U.InviteQuestGroupMember)
    U.questGroupWhisper = button(U.questGroupFrame, 'Whisper', 505, -366, 145, function()
        local s = U.questGroupSelected
        local fresh = Z.QuestGroups.GetCoverage(s and s.memberKeys)
        for _, m in ipairs(fresh and fresh.members or {}) do
            if m.key == U.questGroupMemberKey then
                A.Whisper(m.target)
                return
            end
        end
        U.Message(tr('Quest match no longer available.'))
        U.RefreshQuestGroups()
    end)
    U.questGroupFrame:Hide()
    U.sharedQuestFrame = CreateFrame('Frame', nil, p)
    U.sharedQuestFrame:SetPoint('TOPLEFT', 0, -36)
    U.sharedQuestFrame:SetSize(856, 414)
    U.sharedQuestSearch = edit(U.sharedQuestFrame, 'Search quests', 0, 0, 330, 96)
    U.sharedQuestSearch:SetScript('OnTextChanged', function()
        U.sharedQuestSearchCollapsed = {}
        U.RefreshSharedQuests()
    end)
    U.sharedQuestCount = label(U.sharedQuestFrame, '', 0, -49, 330)
    U.sharedQuestList = list(U.sharedQuestFrame, 0, -70, 330, 280)
    U.sharedQuestTitle = label(U.sharedQuestFrame, 'Select one of your quests.', 350, 0, 496, 'GameFontHighlight')
    U.sharedQuestTitle:SetHeight(40)
    U.sharedMemberHeading = label(U.sharedQuestFrame, 'Players with this quest', 350, -45, 496, 'GameFontNormal')
    U.sharedMemberHeading:SetHeight(20)
    U.sharedQuestStatus = label(U.sharedQuestFrame, '', 350, -68, 496, 'GameFontHighlightSmall')
    U.sharedQuestStatus:SetHeight(35)
    U.sharedMemberList = list(U.sharedQuestFrame, 350, -108, 496, 196)
    U.sharedMemberState = label(U.sharedQuestFrame, '', 350, -312, 496)
    U.sharedMemberState:SetHeight(45)
    U.sharedInvite = button(U.sharedQuestFrame, 'Invite', 350, -366, 145, function()
        local ok, err = Z.QuestHelper.Invite(U.sharedMemberKey, U.sharedQuestID)
        U.Message(ok and tr('Invitation sent.') or tr(err))
        U.RefreshSharedQuests()
    end)
    U.sharedWhisper = button(U.sharedQuestFrame, 'Whisper', 505, -366, 145, function()
        local c = Z.db.contacts[U.sharedMemberKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.sharedRequest = button(U.sharedQuestFrame, 'Find help for this quest', 0, -366, 330, function()
        U.OpenSharedQuestRequest()
    end)
    U.sharedQuestFrame:Hide()
    U.questOutgoingFrame = CreateFrame('Frame', nil, p)
    U.questOutgoingFrame:SetPoint('TOPLEFT', 0, -36)
    U.questOutgoingFrame:SetSize(856, 414)
    U.questOutgoingCount = label(U.questOutgoingFrame, tr('0 Hilfsangebote'), 0, 0, 300, 'GameFontNormal')
    U.questOutgoingList = list(U.questOutgoingFrame, 0, -28, 460, 355)
    U.questOutgoingDetail = label(U.questOutgoingFrame, tr('Wähle ein Hilfsangebot aus.'), 490, -28, 350, 'GameFontHighlight')
    U.questOutgoingDetail:SetHeight(170)
    U.questOutgoingWithdraw = button(U.questOutgoingFrame, tr('Hilfsangebot zurückziehen'), 490, -215, 210, function()
        if not U.questOutgoingToken then
            return
        end
        local key, id = U.questOutgoingToken:match('^(.-)%z(.+)$')
        local ok, err = Z.WithdrawQuest(key, id)
        U.Message(ok and tr('Help offer withdrawn.') or err)
        U.Refresh()
    end, 'danger')
    U.questOutgoingFrame:Hide()
    U.questMineFrame = CreateFrame('Frame', nil, p)
    U.questMineFrame:SetPoint('TOPLEFT', 0, -36)
    U.questMineFrame:SetSize(856, 414)
    U.questMineEmpty = panel(U.questMineFrame)
    U.questMineEmptyContent = panelContent(U.questMineEmpty)
    label(U.questMineEmptyContent, tr('Du hast keine aktive Questanfrage.'), 0, 0, 500, 'GameFontHighlight')
    button(U.questMineEmptyContent, tr('Questanfrage erstellen'), 0, -35, 190, function()
        U.OpenQuestEditor(nil)
    end)
    U.questMineSummary = panel(U.questMineFrame)
    U.questMineSummaryContent = panelContent(U.questMineSummary)
    U.questOwnSummary = label(U.questMineSummaryContent, '', 0, 0, 832, 'GameFontHighlight')
    U.questOwnSummary:SetHeight(72)
    button(U.questMineSummaryContent, tr('Bearbeiten'), 0, -78, 125, function()
        U.OpenQuestEditor(Z.db.quest)
    end)
    button(U.questMineSummaryContent, tr('Löschen'), 135, -78, 125, function()
        local q = Z.db.quest
        if q and Z.CloseQuest(q.id) then
            U.questApplicantKey = nil
            U.Publish()
        end
    end)
    U.questApplicantCount = label(U.questMineSummaryContent, tr('Eigene Helfer (0)'), 0, -120, 350, 'GameFontNormal')
    U.questApplicantList = list(U.questMineSummaryContent, 0, -143, 545, 205)
    U.questAccept = button(U.questMineSummaryContent, tr('Annehmen & einladen'), 565, -143, 200, function()
        decideQuest('eingeladen')
    end)
    U.questReject = button(U.questMineSummaryContent, tr('Ablehnen'), 565, -177, 125, function()
        decideQuest('abgelehnt')
    end)
    U.questApplicantWhisper = button(U.questMineSummaryContent, tr('Anflüstern'), 565, -211, 125, function()
        local c = Z.db.contacts[U.questApplicantKey]
        if c then
            A.Whisper(c.target)
        end
    end)
    U.questApplicantLocation =
        label(U.questMineSummaryContent, tr('Aufenthaltsort\nWähle einen Helfer aus.'), 565, -250, 267, 'GameFontHighlightSmall')
    U.questApplicantLocation:SetHeight(35)
    U.questPriorContacts = label(U.questMineSummaryContent, tr('Bisherige Kontakte'), 565, -291, 267)
    U.questPriorContacts:SetHeight(64)
    U.questHistoryOpen = button(U.questMineSummaryContent, tr('Gesamten Verlauf anzeigen'), 565, -364, 220, function()
        U.OpenHistory(U.questApplicantKey)
    end)
    U.questForm = panel(U.questMineFrame)
    U.questFormContent = panelContent(U.questForm)
    U.questPicker = selector(U.questFormContent, tr('Aus dem Questlog'), 0, 0, 260, { tr('Manuell / Levelgruppe') }, function(v)
        local q = U.questMap and U.questMap[v]
        if q then
            U.questEditQuestID = q.id
            U.questFields.title:SetText(q.title)
            if q.level and q.level > 0 then
                U.questFields.min:SetText(tostring(q.level))
                U.questFields.max:SetText(tostring(q.level))
            end
            if Z.Logic.Text(q.category, 64) then
                U.questFields.zone:SetText(q.category)
            end
            U.CaptureQuestDraft()
        end
    end)
    U.questFields = {}
    U.questPickerSearch = edit(U.questFormContent, tr('Quest suchen'), 655, 0, 177, 96)
    U.questPickerSearch:SetScript('OnTextChanged', U.FilterQuestPicker)
    U.questFields.title = edit(U.questFormContent, tr('Titel / Levelgruppe'), 280, 0, 360, 96)
    U.questFields.zone = edit(U.questFormContent, tr('Zone (optional)'), 0, -56, 260, 64)
    U.questFields.min = edit(U.questFormContent, tr('Level von'), 280, -56, 90, 3)
    U.questFields.max = edit(U.questFormContent, tr('Level bis'), 385, -56, 90, 3)
    U.questDuration = edit(U.questFormContent, tr('Ablauf in Minuten'), 490, -56, 150, 3)
    U.questFields.note = edit(U.questFormContent, tr('Notiz (optional)'), 0, -118, 640, 96, true)
    U.questNoteCount = label(U.questFormContent, '0 / 96', 558, -187, 82)
    U.questNoteCount:SetJustifyH('RIGHT')
    U.questFormPreview = label(U.questFormContent, Z.Kit.Paint('goldText', 'VORSCHAU'), 665, -60, 167, 'GameFontHighlight')
    U.questFormPreview:SetHeight(125)
    U.questSave = button(U.questFormContent, 'Erstellen', 0, -225, 190, function()
        local now = A.Now()
        if not U.ValidateQuestForm() then
            return
        end
        if not U.questEditID and Z.db.quest and Z.db.quest.expires > now then
            U.Message('Archive your current quest request before creating another.')
            return
        end
        if U.questEditID and (not Z.db.quest or Z.db.quest.id ~= U.questEditID) then
            U.Message('This activity is no longer active. Close the form and open it again.')
            return
        end
        local minutes = tonumber(U.questDuration:GetText()) or 60
        local q = { id = U.questEditID, questID = U.questEditQuestID or 0, expires = now + minutes * 60 }
        for k, e in pairs(U.questFields) do
            q[k] = (k == 'min' or k == 'max') and tonumber(e:GetText()) or e:GetText()
        end
        local id, err = Z.SaveQuest(q, now)
        if id then
            U.questEditing = false
            U.questForm:Hide()
            U.Publish()
        else
            U.Message(err)
        end
    end, 'primary')
    U.questFormBack = button(U.questFormContent, tr('Zurück'), 200, -225, 115, function()
        U.BackActivityStep()
    end)
    U.questDiscard = button(U.questFormContent, tr('Entwurf verwerfen'), 325, -225, 165, function()
        U.DiscardQuestDraft()
    end, 'danger')
    for _, field in pairs(U.questFields) do
        field:SetScript('OnTextChanged', U.CaptureQuestDraft)
    end
    U.questDuration:SetScript('OnTextChanged', U.CaptureQuestDraft)
    U.questForm:Hide()
    U.questView = 'shared'
end
