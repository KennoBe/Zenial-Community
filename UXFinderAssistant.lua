-- Group finder: the assistant "Contact fitting groups".
--
-- It saves the player from opening every fitting group by hand, and nothing more: it lists the groups of
-- the open instance that fit, lets the player pick, and then goes through them one at a time. Every
-- contact is one click of the player. A ZENIAL group gets the usual join request (Z.ApplyGroup); for a
-- public group the chat box opens with the message and the player presses Enter. Nothing is sent
-- unattended, no group is written to twice, and closing the assistant leaves nothing behind.
-- See _dev/addons/ZenialCommunity/PUBLIC-LFG-INTEGRATION-PLAN.md, work package PLFG-16.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local X, Q = Z.PublicLFGContact, Z.PublicLFGMatch
local F, FP = U and U.Finder, U and U.FinderPublic
if type(F) ~= 'table' or type(FP) ~= 'table' or type(X) ~= 'table' or type(Q) ~= 'table' then
    return
end

local FA = {}
U.FinderAssistant = FA

local ROWS, WIDTH = 8, 580
local ROLE_FIELD = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'dd' }
local TIER = { BEST = 'Very fitting', GOOD = 'Fitting', UNKNOWN = 'Role unknown' }

local function tr(value)
    return Z.T(value)
end
local function plain(text)
    return (tostring(text or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end

-- Name of a candidate: the organizer of a ZENIAL group, the leader of a public group.
local function name(item)
    if item.zenial then
        return item.row.ownerName or '?'
    end
    return item.row.leader or '?'
end
local function line(item)
    local members = item.view.size and item.view.members and Z.T('%d/%d players', item.view.members, item.view.size) or nil
    return name(item) .. ' · ' .. (item.zenial and 'ZENIAL' or tr('Public')) .. ' · ' .. tr(TIER[item.fit.tier] or 'Fitting') .. (members and ' · ' .. members or '')
end

-- Whether a candidate can still be contacted right now.
local function usable(item)
    if item.zenial then
        local r = Z.ActivityBoard.Get(item.row.key)
        return r ~= nil and r.data ~= nil and type(r.application) ~= 'table' and U.ActivityActionState(r).join == true
    end
    return X.CanContact(item.row) == true
end

-- Roles a ZENIAL group still looks for, the player's own first.
local function wantedRoles(item)
    local own, out = FP.Me().roles, {}
    for _, role in ipairs(Q.ROLES) do
        if (item.row.data[ROLE_FIELD[role]] or 0) > 0 and own[role] then
            out[#out + 1] = role
        end
    end
    for _, role in ipairs(Q.ROLES) do
        if (item.row.data[ROLE_FIELD[role]] or 0) > 0 and not own[role] then
            out[#out + 1] = role
        end
    end
    return out
end

-- The text for the public groups of this run: an existing group text, the last used one at first.
local function chosenText()
    local W = Z.WhisperTexts
    local s = FA.state
    local entry = s and W.Get('group', s.textId) or W.Last('group')
    if s and entry then
        s.textId = entry.id
    end
    return entry
end

function FA.Close()
    FA.state = nil
    if FA.frame then
        FA.frame:Hide()
    end
end

-- Opens the assistant for the open instance.
function FA.Open()
    if not F.activity or not FP.Active() then
        return false
    end
    local items = FP.Candidates()
    -- Only the rows that are shown can be picked; the rest is left out of the selection and the queue.
    for index = ROWS + 1, #items do
        items[index] = nil
    end
    for _, item in ipairs(items) do
        item.selected = item.fit.tier ~= 'UNKNOWN'
    end
    FA.state = { step = 'LIST', activity = F.activity, items = items, done = 0, group = A.GroupState().total }
    chosenText()
    FA.Build()
    FA.Refresh()
    return true
end

local function selected()
    local out = {}
    for _, item in ipairs(FA.state.items) do
        if item.selected then
            out[#out + 1] = item
        end
    end
    return out
end

-- Moves to the next candidate that can still be contacted, or to the end.
local function advance()
    local s = FA.state
    -- A chat box counts as contacted only once the message was sent.
    local last = s.waiting and s.queue[s.index] or nil
    if last then
        local state = X.State(last.row)
        if state == 'SENT' or state == 'JOINED' then
            s.done = s.done + 1
        end
    end
    s.waiting, s.role = false, nil
    repeat
        s.index = s.index + 1
    until s.index > #s.queue or usable(s.queue[s.index])
    if s.index > #s.queue then
        s.step = 'DONE'
    else
        s.role = s.queue[s.index].zenial and wantedRoles(s.queue[s.index])[1] or nil
    end
end

local function start()
    local s = FA.state
    local entry = chosenText()
    if entry then
        Z.WhisperTexts.SetLast('group', entry.id)
    end
    s.queue, s.index, s.step = selected(), 0, 'RUN'
    advance()
end

-- The one action of a step: a join request for a ZENIAL group, the prepared chat box for a public group.
local function act()
    local s = FA.state
    local item = s.queue[s.index]
    if item.zenial then
        local ok, why = Z.ApplyGroup(item.row.owner, item.row.id, s.role, '')
        U.Message(ok and tr('Application submitted; awaiting response.') or tr(why))
        if ok then
            s.done = s.done + 1
        end
        advance()
    else
        -- Filled for each group: the name of its leader and its activity.
        local ok = FP.Contact(item.row, FP.Message(item.row, s.textId))
        if ok then
            s.waiting = true
        else
            advance()
        end
    end
end

local function onGo()
    local s = FA.state
    if not s then
        return
    end
    if s.step == 'LIST' then
        start()
    elseif s.step == 'DONE' then
        FA.Close()
        U.RefreshFinder()
        return
    elseif s.waiting then
        advance()
    else
        act()
    end
    U.RefreshFinder()
end

function FA.Build()
    if FA.frame then
        return
    end
    local frame = CreateFrame('Frame', nil, F.frame)
    if frame.SetFrameLevel and F.frame.GetFrameLevel then
        frame:SetFrameLevel((F.frame:GetFrameLevel() or 1) + 60)
    end
    frame:EnableMouse(true)
    frame:SetPoint('CENTER', F.frame, 'CENTER', 0, 0)
    frame.fill = frame:CreateTexture(nil, 'BACKGROUND')
    frame.fill:SetAllPoints()
    T.Tint(frame.fill, 'SetColorTexture', 'panelRaised')
    frame.edges = T.Edges(frame, 'BORDER')
    T.TintEdges(frame.edges, 'goldDim')
    frame.title = K.Text(frame, '', 'heading', 'text')
    frame.title:SetPoint('TOPLEFT', 16, -14)
    frame.hint = K.Text(frame, '', 'caption', 'textSoft')
    frame.hint:SetPoint('TOPLEFT', 16, -38)
    frame.hint:SetWidth(WIDTH - 32)
    frame.hint:SetHeight(28)
    if frame.hint.SetWordWrap then
        frame.hint:SetWordWrap(true)
    end
    frame.rows = {}
    for index = 1, ROWS do
        local chip = T.Chip(frame, '', WIDTH - 32, 24, function(self)
            local item = FA.state and FA.state.items[self.zenialIndex]
            if item then
                item.selected = self:GetChecked() and true or false
                U.RefreshFinder()
            end
        end)
        chip.zenialIndex = index
        chip:SetPoint('TOPLEFT', 16, -(74 + (index - 1) * 28))
        frame.rows[index] = chip
    end
    frame.textLabel = K.Text(frame, tr('Message to public groups'), 'overline', 'goldDim')
    -- The group text of this run; the list also leads to the designer (UXWhisperDesigner.lua).
    frame.textChoice = T.Button(frame, '', 260, 24, function(self)
        local entry = chosenText()
        U.WhisperDesigner.Menu(self, 'group', true, function(id)
            if FA.state then
                FA.state.textId = id
            end
            U.RefreshFinder()
        end, entry and entry.id)
    end, 'secondary')
    T.StyleDropdown(frame.textChoice)
    T.AlignButtonText(frame.textChoice, 8, 28)
    frame.who = K.Text(frame, '', 'heading', 'text')
    frame.roles = {}
    for index, role in ipairs(Q.ROLES) do
        local chip = T.Chip(frame, Z.Locale.Role(role), 96, 22, function()
            FA.state.role = role
            U.RefreshFinder()
        end)
        chip.zenialRole = role
        frame.roles[index] = chip
    end
    frame.go = T.Button(frame, '', 230, 26, onGo, 'primary')
    frame.skip = T.Button(frame, tr('Skip'), 120, 26, function()
        if FA.state and FA.state.step == 'RUN' then
            advance()
            U.RefreshFinder()
        end
    end, 'secondary')
    frame.close = T.Button(frame, tr('Close'), 110, 26, function()
        FA.Close()
        U.RefreshFinder()
    end, 'secondary')
    frame:Hide()
    FA.frame = frame
end

local function show(widget, shown)
    widget:SetShown(shown == true)
end

-- Draws the current step. Called at the end of every refresh of the finder.
function FA.Refresh()
    local s, frame = FA.state, FA.frame
    if not frame then
        return
    end
    if not s or s.activity ~= F.activity or not FP.Active() then
        FA.Close()
        return
    end
    -- The player found a group meanwhile: the assistant has done its job.
    if s.step ~= 'LIST' and A.GroupState().total > s.group then
        FA.Close()
        U.Message(tr('You are in a group now.'))
        return
    end
    local list, run = s.step == 'LIST', s.step == 'RUN'
    local item = run and s.queue[s.index] or nil
    frame.title:SetText(Z.T('Contact fitting groups: %s', Z.Locale.Activity(s.activity)))
    for index, chip in ipairs(frame.rows) do
        local candidate = list and s.items[index] or nil
        show(chip, candidate ~= nil)
        if candidate then
            chip.text:SetText(plain(line(candidate)))
            chip:SetChecked(candidate.selected == true)
        end
    end
    local shownRows = list and math.min(#s.items, ROWS) or 0
    local y = 74 + shownRows * 28
    show(frame.textLabel, list)
    show(frame.textChoice, list)
    show(frame.who, run)
    for _, chip in ipairs(frame.roles) do
        show(chip, false)
    end
    if list then
        local count = #selected()
        frame.hint:SetText(#s.items == 0 and tr('No group fits right now, or you already contacted them all.')
            or tr('Pick the groups to contact. Each one is contacted with one click of yours, one after the other.'))
        frame.textLabel:ClearAllPoints()
        frame.textLabel:SetPoint('TOPLEFT', 16, -(y + 8))
        local entry = chosenText()
        frame.textChoice:SetText(entry and entry.name or '')
        frame.textChoice:ClearAllPoints()
        frame.textChoice:SetPoint('TOPLEFT', 16, -(y + 26))
        y = y + 60
        frame.go:SetText(Z.T('Start (%d)', count))
        frame.go:SetEnabled(count > 0)
    elseif run then
        frame.who:ClearAllPoints()
        frame.who:SetPoint('TOPLEFT', 16, -72)
        frame.who:SetText(Z.T('Group %d of %d', s.index, #s.queue) .. ': ' .. plain(line(item)))
        F.ScriptFont(frame.who, plain(line(item)))
        frame.who:SetWidth(WIDTH - 32)
        frame.who:SetHeight(18)
        y = 104
        if item.zenial then
            frame.hint:SetText(tr('Choose your role and send the join request.'))
            local x = 16
            local wanted = {}
            for _, role in ipairs(wantedRoles(item)) do
                wanted[role] = true
            end
            for _, chip in ipairs(frame.roles) do
                show(chip, true)
                chip:ClearAllPoints()
                chip:SetPoint('TOPLEFT', x, -y)
                chip:SetEnabled(wanted[chip.zenialRole] == true)
                chip:SetChecked(s.role == chip.zenialRole)
                x = x + 102
            end
            y = y + 34
            frame.go:SetText(tr('Send request'))
            frame.go:SetEnabled(s.role ~= nil)
        elseif s.waiting then
            frame.hint:SetText(tr(X.State(item.row) == 'SENT' and 'Message sent.' or 'Press Enter in the chat to send your message. Then go on.'))
            frame.go:SetText(tr(s.index < #s.queue and 'Next group' or 'Finish'))
            frame.go:SetEnabled(true)
        else
            frame.hint:SetText(tr('The chat box opens with your message. You send it with Enter.'))
            frame.go:SetText(tr('Prepare message'))
            frame.go:SetEnabled(true)
        end
    else
        frame.hint:SetText(s.done == 1 and tr('Done. 1 group contacted.') or Z.T('Done. %d groups contacted.', s.done))
        frame.go:SetText(tr('Close'))
        frame.go:SetEnabled(true)
        y = 74
    end
    show(frame.skip, run)
    show(frame.close, s.step ~= 'DONE')
    frame.go:ClearAllPoints()
    frame.go:SetPoint('TOPLEFT', 16, -(y + 8))
    frame.skip:ClearAllPoints()
    frame.skip:SetPoint('TOPLEFT', 254, -(y + 8))
    frame.close:ClearAllPoints()
    frame.close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -16, -(y + 8))
    frame:SetSize(WIDTH, y + 48)
    frame:Show()
end

return FA
