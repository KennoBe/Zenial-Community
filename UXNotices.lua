local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local S = U.Shared
local T = Z.Theme
local tr = S.tr
local ORDER_TERMINAL, MAIN_TAB_NAMES, roleName, activityName = S.ORDER_TERMINAL, S.MAIN_TAB_NAMES, S.roleName, S.activityName

local function ownID(kind)
    local e = kind == 'group' and Z.db.lfg[1] or kind == 'quest' and Z.db.quest
    if e and (not e.expires or e.expires > A.Now()) then
        return e.id
    end
end
local function counts(kind)
    return L.ApplicationCounts(Z.db, kind, ownID(kind))
end
local function badge(control, count, minimap)
    if not control then
        return
    end
    if not control.noticeIcon then
        local f = CreateFrame('Frame', nil, control, BackdropTemplateMixin and 'BackdropTemplate' or nil)
        control.noticeIcon = f
        f:SetFrameLevel(control:GetFrameLevel() + 2)
        f:EnableMouse(false)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
                edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
                tile = true,
                tileSize = 16,
                edgeSize = 8,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
        end
        if f.SetBackdropColor then
            f:SetBackdropColor(0.45, 0.045, 0.025, 1)
            f:SetBackdropBorderColor(1, 0.76, 0.28, 1)
        end
        f.text = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        f.text:SetPoint('CENTER')
        f.text:SetJustifyH('CENTER')
        f.text:SetJustifyV('MIDDLE')
        f.text:SetTextColor(1, 0.96, 0.82, 1)
        if minimap then
            U.minimapBadge = f.text
        end
    end
    local f = control.noticeIcon
    local width = count > 99 and 28 or 20
    f:SetSize(width, 20)
    f.text:SetSize(width - 4, 16)
    f.text:SetText(count > 0 and (count > 99 and '99+' or tostring(count)) or '')
    f:ClearAllPoints()
    f:SetPoint(minimap and 'TOPRIGHT' or 'RIGHT', control, minimap and 'TOPRIGHT' or 'RIGHT', minimap and 4 or -8, minimap and 4 or 0)
    f:SetShown(count > 0)
    control.unreadCount = count
    -- Keep the main-navigation caption beside its icon and inside the badge.
    local font = control.GetFontString and control:GetFontString()
    if font and control:GetParent() == U.sidebar then
        font:ClearAllPoints()
        font:SetPoint('LEFT', control, 'LEFT', 34, 0)
        font:SetPoint('RIGHT', control, 'RIGHT', count > 0 and -width - 14 or -8, 0)
        font:SetJustifyH('LEFT')
        font:SetWordWrap(false)
        local size = control:GetWidth() < 140 and 10 or 12
        if T and T.StyleButtonText then
            T.StyleButtonText(control, size)
        else
            local file = font:GetFont()
            if file then
                font:SetFont(file, size)
            end
        end
    end
end
function U.UpdateBadges()
    local N = Z.Notifications
    local function updates(area, view)
        return N and N.Count(area, view) or 0
    end
    local _, gu = counts('group')
    local _, qu = counts('quest')
    local pu = Z.PvPHelp and Z.PvPHelp.UnreadCount() or 0
    local totals = {
        0,
        updates('craft'),
        gu + pu + updates('groups'),
        qu + updates('quests'),
        updates('trade'),
        0,
        0,
        0,
        0,
        gu + pu + updates('groups') + qu + updates('quests'),
        0,
    }
    U.unreadTotal = totals[2] + totals[3] + totals[4] + totals[5]
    for i, tab in ipairs(U.tabs or {}) do
        local n = totals[i] or 0
        tab:SetText(MAIN_TAB_NAMES[i])
        badge(tab, n)
    end
    badge(U.craftOrdersTab, updates('craft'))
    badge(U.tradeRulesTab, updates('trade'))
    badge(U.groupMineTab, gu + updates('groups', 'mine'))
    badge(U.groupOutgoingTab, updates('groups', 'outgoing'))
    badge(U.scheduledTab, updates('groups', 'scheduled'))
    badge(U.activityScopeOrganized, gu + updates('groups', 'mine'))
    badge(U.activityScopeApplications, updates('groups', 'outgoing'))
    badge(U.activityScopePlanned, updates('groups', 'scheduled'))
    badge(U.groupBrowseTab, updates('groups', 'browse'))
    badge(U.questMineTab, qu + updates('quests', 'mine'))
    badge(U.questOutgoingTab, updates('quests', 'outgoing'))
    local pvp = pu + updates('groups', 'pvp')
    if U.pvpTab then
        U.pvpTab:SetText(tr('PvP Help') .. (pvp > 0 and (' (' .. pvp .. ')') or ''))
        badge(U.pvpTab, pvp)
    end
    badge(U.minimapButton, U.unreadTotal, true)
    if U.RefreshNotificationInbox then
        U.RefreshNotificationInbox()
    end
end
local lastNoticeSound = 0
local function playNoticeSound(now)
    if lastNoticeSound == 0 or now - lastNoticeSound >= 10 then
        A.PlayApplicationSound()
        lastNoticeSound = now
    end
end
local function ensureToast()
    if U.toast then
        return U.toast
    end
    local f = U.NewNotice('ZenialCommunityNotice', 340, 96)
    U.toast = f
    f.skipHistory = true
    f:SetScript('OnClick', function()
        local kind, key, id = f.openKind, f.openKey, f.openID
        f:Hide()
        U.OpenApplications(kind, key, id)
    end)
    return f
end
function U.NotifyApplication(kind, key, id)
    local own = kind == 'group' and Z.db.lfg[1] or Z.db.quest
    if own and own.id == id then
        Z.Notifications.Push(
            kind == 'group' and 'groups' or 'quests',
            'mine',
            'application:' .. kind .. ':' .. id .. ':' .. key,
            A.Now(),
            'application_received',
            key,
            id,
            kind == 'group' and own.activity or own.title,
            nil,
            true
        )
    end
    local f = ensureToast()
    if kind == 'group' then
        f.pendingGroup = (f.pendingGroup or 0) + 1
    else
        f.pendingQuest = (f.pendingQuest or 0) + 1
    end
    f.openKind, f.openKey, f.openID = kind, key, id
    f.batchAt = A.Clock() + 2
    U.UpdateBadges()
end
function U.OpenApplications(kind, key, id)
    U.Create()
    U.frame:Show()
    local N = U.Navigation
    local activity = (kind == 'quest' and 'QUEST' or 'LIVE') .. ':' .. Z.me.key .. ':' .. id
    if Z.db.blocked[key] then
        return N.Fail('target-unavailable')
    end
    if Z.ActivityBoard.Get(activity) then
        if not U.OpenActivity(activity) then
            return false
        end
        U.SelectActivityParticipant(key)
        return true
    end
    local own
    if kind == 'quest' then
        own = Z.db.quest
    else
        own = Z.db.lfg[1]
    end
    if not own or own.id ~= id then
        return N.Fail('target-unavailable')
    end
    if N.UnsavedInput() then
        return N.Fail('unsaved-input')
    end
    if kind == 'quest' then
        U.questApplicantKey = key
        return U.Navigate('quests', 'mine')
    end
    U.groupApplicantKey = key
    return U.Navigate('groups', 'mine')
end
local function ensureFollowToast()
    if U.followToast then
        return U.followToast
    end
    local f = U.NewNotice('ZenialCommunityFollowNotice', 340, 96)
    U.followToast = f
    f.skipHistory = true
    f.heading:SetText(tr('New group for a followed activity'))
    f:SetScript('OnClick', function(self)
        local key, id = self.openKey, self.openID
        self:Hide()
        if key and id then
            U.Create()
            U.frame:Show()
            if Z.db.blocked[key] or not Z.FindForeignGroup(key, id) then
                U.Navigation.Fail('target-unavailable')
            elseif U.Navigate('groups', 'browse') then
                U.SelectGroup(key, id)
            end
        end
    end)
    return f
end
function U.NotifyGroupFollow(key, id, activity)
    Z.Notifications.Push('groups', 'browse', 'follow:' .. key .. ':' .. id, A.Now(), 'GROUP_FOLLOW', key, id, activity, nil, true)
    local f = ensureFollowToast()
    f.pending = (f.pending or 0) + 1
    if f.pending == 1 then
        f.openKey, f.openID, f.openActivity = key, id, activity
    end
    f.batchAt = GetTime() + 2
end
local function noticeFrame(name, y, w, h)
    return U.NewNotice(name, w, h)
end
local function ensurePvpToast()
    if U.pvpToast then
        return U.pvpToast
    end
    local f = noticeFrame('ZenialCommunityPvPNotice', -144, 340, 112)
    U.pvpToast = f
    f.heading:SetText(tr('PvP help needed'))
    f:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    -- Left click opens the call; right click and the close button only dismiss.
    f:SetScript('OnClick', function(self, mouseButton)
        local key, id = self.openKey, self.openID
        self:Hide()
        if mouseButton ~= 'RightButton' and key and id then
            U.OpenPvPHelp('calls', key, id)
        end
    end)
    return f
end
local function pvpNoticeText(key, r)
    local c = Z.db.contacts[key]
    local lines = { (c and c.target or tr('Unbekannt')) .. tr(' needs PvP help') }
    lines[2] = r and Z.PvPHelp.FormatLocation(r) or tr('Ort unbekannt')
    if r and (r.note or '') ~= '' then
        lines[#lines + 1] = tr('Attackers') .. ': ' .. r.note
    end
    if r and r.killLog then
        for _, line in ipairs(Z.PvPHelp.KillLogLines(r.killLog, r.killTruncated)) do
            lines[#lines + 1] = line
        end
    elseif r and r.enemy then
        lines[#lines + 1] = tr('Targeted enemy') .. ': ' .. r.enemy.name .. (r.enemy.level > 0 and ' · ' .. Z.T('Level %d', r.enemy.level) or '')
    end
    return table.concat(lines, '\n')
end
-- The details arrive separately: a visible banner about this call picks them up.
function U.RefreshPvPNotice(key, id)
    local f = U.pvpToast
    if f and f:IsShown() and f.showsOne and f.openKey == key and f.openID == id then
        f.text:SetText(pvpNoticeText(key, Z.PvPHelp.GetReceived(key, id)))
    end
end
local function ensureDeathToast()
    if U.deathToast then
        return U.deathToast
    end
    local f = noticeFrame('ZenialCommunityGankedNotice', -208, 300, 50)
    U.deathToast = f
    f.text:SetText(tr('Werde gegankt. HILFE!\nKlicken zum Prüfen'))
    f:SetScript('OnClick', function(self)
        self:Hide()
        U.OpenPvPHelp('mine', nil, nil, true)
    end)
    return f
end
function U.NotifyPvPHelp(key, id)
    local f = ensurePvpToast()
    f.pending = (f.pending or 0) + 1
    if f.pending == 1 then
        f.openKey, f.openID = key, id
    end
    f.batchAt = A.Clock() + 2
    U.UpdateBadges()
end
function U.NotifyPvPHelpEligible()
    local f = ensureDeathToast()
    f:Show()
    f.hideAt = A.Clock() + 8
end
-- True when the entry's target still exists; read-only, so a failed link changes nothing.
local function updateTarget(entry)
    local peer, id = entry.peer, entry.id
    if entry.code == 'application_received' then
        return true
    elseif entry.area == 'groups' and entry.view == 'scheduled' then
        -- The store is authoritative (archived events stay); the board cache may lag behind a deletion.
        return Z.ScheduledGroups.Get(peer, id) ~= nil
    elseif entry.area == 'craft' then
        return Z.CraftOrders.orders[id] ~= nil or Z.db.craftOrderHistory[id] ~= nil
    elseif entry.area == 'trade' then
        return Z.TradeManager.store ~= nil and Z.TradeManager.store.rules[entry.source] ~= nil
    elseif entry.view == 'outgoing' and (entry.area == 'groups' or entry.area == 'quests') then
        return Z.ActivityBoard.Get((entry.area == 'groups' and 'LIVE' or 'QUEST') .. ':' .. peer .. ':' .. id) ~= nil
    elseif entry.view == 'mine' and (entry.area == 'groups' or entry.area == 'quests') then
        local own
        if entry.area == 'groups' then
            own = Z.db.lfg[1]
        else
            own = Z.db.quest
        end
        return own ~= nil and own.id == id
    elseif entry.view == 'pvp' then
        local own = Z.PvPHelp.Own()
        return own ~= nil and own.id == id
    elseif entry.area == 'groups' and entry.view == 'browse' and entry.code == 'GROUP_FOLLOW' then
        return Z.FindForeignGroup(peer, id) ~= nil
    end
    return true
end
function U.OpenUpdate(entry)
    U.Create()
    U.frame:Show()
    local N = U.Navigation
    if Z.db.blocked[entry.peer] or not updateTarget(entry) then
        return N.Fail('target-unavailable')
    end
    if entry.code == 'application_received' then
        local ok, reason = U.OpenApplications(entry.area == 'groups' and 'group' or 'quest', entry.peer, entry.id)
        if ok then
            Z.Notifications.Read(entry.token)
            U.UpdateBadges()
        end
        return ok, reason
    end
    if N.UnsavedInput() then
        return N.Fail('unsaved-input')
    end
    if entry.area == 'groups' and entry.view == 'scheduled' then
        local key = 'EVENT:' .. entry.peer .. ':' .. entry.id
        if Z.ActivityBoard.Get(key) then
            local ok, reason = U.OpenActivity(key)
            if ok then Z.Notifications.Read(entry.token); U.UpdateBadges() end
            if ok and entry.source ~= '' then
                U.SelectActivityParticipant(Z.ResolvePeerKey(entry.source))
            end
            return ok, reason
        end
    end
    local previous = { craftOrderID=U.craftOrderID, craftShowCompleted=U.craftShowCompleted and U.craftShowCompleted:GetChecked(), scheduledOwner=U.scheduledOwner, scheduledID=U.scheduledID, scheduledArchive=U.scheduledArchive and U.scheduledArchive:GetChecked(), tradeRuleID=U.tradeRuleID, groupOutgoingToken=U.groupOutgoingToken, questOutgoingToken=U.questOutgoingToken, groupApplicantKey=U.groupApplicantKey, questApplicantKey=U.questApplicantKey }
    if entry.area == 'craft' then
        U.craftOrderID = entry.id
        local order = Z.CraftOrders.orders[entry.id] or Z.db.craftOrderHistory[entry.id]
        if order and ORDER_TERMINAL[order.state] and U.craftShowCompleted then
            U.craftShowCompleted:SetChecked(true)
        end
    elseif entry.area == 'groups' and entry.view == 'scheduled' then
        U.scheduledOwner, U.scheduledID = entry.peer, entry.id
        if U.scheduledArchive then
            U.scheduledArchive:SetChecked(true)
        end
    elseif entry.area == 'trade' then
        U.tradeRuleID = entry.source
    elseif entry.view == 'outgoing' then
        if entry.area == 'groups' then
            U.groupOutgoingToken = entry.peer .. '\0' .. entry.id
        else
            U.questOutgoingToken = entry.peer .. '\0' .. entry.id
        end
    elseif entry.view == 'mine' then
        if entry.area == 'groups' then
            U.groupApplicantKey = entry.peer
        else
            U.questApplicantKey = entry.peer
        end
    end
    local ok, reason = U.Navigate(entry.area, entry.view)
    if not ok then
        U.craftOrderID=previous.craftOrderID; if U.craftShowCompleted then U.craftShowCompleted:SetChecked(previous.craftShowCompleted == true) end
        U.scheduledOwner=previous.scheduledOwner; U.scheduledID=previous.scheduledID; if U.scheduledArchive then U.scheduledArchive:SetChecked(previous.scheduledArchive == true) end
        U.tradeRuleID=previous.tradeRuleID; U.groupOutgoingToken=previous.groupOutgoingToken; U.questOutgoingToken=previous.questOutgoingToken
        U.groupApplicantKey=previous.groupApplicantKey; U.questApplicantKey=previous.questApplicantKey
    else
        Z.Notifications.Read(entry.token); U.UpdateBadges()
    end
    if ok and entry.view == 'pvp' then
        U.SetPvpView('mine')
        local own = Z.PvPHelp.Own()
        if U.pvpUnified and own and own.id == entry.id and own.responses[entry.peer] then
            U.pvpHelperKey = entry.peer
            U.pvpHelpers:Show()
            U.RefreshPvPHelp()
        end
    end
    return ok, reason
end
function U.NotifyAddonVersion(version)
    if not U.addonVersionToast then
        local f = noticeFrame('ZenialCommunityVersionNotice', -336, 400, 88)
        U.addonVersionToast = f
        f.text:SetHeight(64)
        f:SetScript('OnClick', function(self)
            self:Hide()
        end)
    end
    local f = U.addonVersionToast
    f.text:SetText(
        Z.T('ZenialCommunity %s or newer reported by two players. Update for new features and bug fixes. Click to dismiss.', version)
    )
    f:Show()
    f.hideAt = A.Clock() + 20
    return true
end
function U.NotifyUpdate(entry)
    if not U.updateToast then
        local f = noticeFrame('ZenialCommunityUpdateNotice', -270, 350, 62)
        U.updateToast = f
        f.skipHistory = true
        f:SetScript('OnClick', function(self)
            self:Hide()
            if self.entry then
                U.OpenUpdate(self.entry)
            end
        end)
    end
    local f = U.updateToast
    f.heading:SetText(Z.Notifications.Title(entry))
    f.entry = entry
    f.pending = (f.pending or 0) + 1
    f.batchAt = A.Clock() + 2
end
function U.TickNotices(now)
    if now >= (U.nextBadgeRefresh or 0) then
        U.nextBadgeRefresh = now + 5
        U.UpdateBadges()
    end
    local f = U.toast
    if f then
        if f.batchAt and now >= f.batchAt then
            local n = (f.pendingGroup or 0) + (f.pendingQuest or 0)
            f.pendingGroup, f.pendingQuest, f.batchAt = 0, 0, nil
            local kind = f.openKind
            local e = kind == 'quest' and Z.db.quest or Z.db.lfg[1]
            local bucket = kind == 'quest' and Z.db.questInterests or Z.db.interests
            local p = bucket[f.openID] and bucket[f.openID][f.openKey]
            local c = Z.db.contacts[f.openKey]
            local who = c and c.target or tr('Unknown')
            local activity = e and e.id == f.openID and (kind == 'quest' and e.title or activityName(e.activity)) or tr('Activity')
            f.heading:SetText(tr(kind == 'quest' and 'New help offer' or 'New application'))
            local text = Z.T('%s applied for %s.', who, activity) .. (p and p.role and '\n' .. roleName(p.role) or '')
            if n > 1 then
                text = text .. '\n' .. Z.T('%d more updates', n - 1)
            end
            f.text:SetText(text .. tr('\nClick to open'))
            f:Show()
            f.hideAt = now + 16
            playNoticeSound(now)
        end
        if f.hideAt and now >= f.hideAt and not f.hovered then
            f.hideAt = nil
            f:Hide()
        end
    end
    f = U.followToast
    if f then
        if f.batchAt and now >= f.batchAt then
            local n = f.pending or 0
            f.pending, f.batchAt = 0, nil
            local c = Z.db.contacts[f.openKey]
            if n == 1 then
                f.text:SetText(
                    tr('Neue Gruppe: ')
                        .. (f.openActivity or '')
                        .. '\n'
                        .. (c and c.target or tr('Unbekannt'))
                        .. tr(' · Klicken zum Öffnen')
                )
            else
                f.text:SetText(n .. tr(' neue Gruppen für gefolgte Aktivitäten\nKlicken zum Öffnen'))
            end
            f:Show()
            f.hideAt = now + 8
            playNoticeSound(now)
        end
        if f.hideAt and now >= f.hideAt and not f.hovered then
            f.hideAt = nil
            f:Hide()
        end
    end
    f = U.pvpToast
    if f then
        if f.batchAt and now >= f.batchAt then
            local n = f.pending or 0
            f.pending, f.batchAt = 0, nil
            local r = Z.PvPHelp and Z.PvPHelp.GetReceived(f.openKey, f.openID)
            f.showsOne = n == 1
            if n == 1 then
                f.text:SetText(pvpNoticeText(f.openKey, r))
            else
                f.text:SetText(n .. tr(' neue PvP-Hilferufe\nKlicken zum Öffnen'))
            end
            f:Show()
            f.hideAt = now + 8
            playNoticeSound(now)
        end
        if f.hideAt and now >= f.hideAt and not f.hovered then
            f.hideAt = nil
            f:Hide()
        elseif f:IsShown() and f.showsOne and not (Z.PvPHelp and Z.PvPHelp.GetReceived(f.openKey, f.openID)) then
            -- The call ended or the caller went offline: nothing left to help with.
            f.hideAt = nil
            f:Hide()
        end
    end
    f = U.updateToast
    if f then
        if f.batchAt and now >= f.batchAt then
            local n = f.pending or 0
            f.pending, f.batchAt = 0, nil
            f.text:SetText(
                Z.Notifications.Describe(f.entry) .. (n > 1 and '\n' .. Z.T('%d more updates', n - 1) or '') .. tr('\nClick to open')
            )
            f:Show()
            f.hideAt = now + 16
            playNoticeSound(now)
        end
        if f.hideAt and now >= f.hideAt and not f.hovered then
            f.hideAt = nil
            f:Hide()
        end
    end
    f = U.deathToast
    if f and f.hideAt and now >= f.hideAt and not f.hovered then
        f.hideAt = nil
        f:Hide()
    end
    f = U.addonVersionToast
    if f and f.hideAt and now >= f.hideAt and not f.hovered then
        f.hideAt = nil
        f:Hide()
    end
    U.LayoutNotices()
end

