-- Rating card after a dungeon together (FWR-3). See _dev/addons/ZenialCommunity/FINDER-FILTERS-WHISPERS-RATING-PLAN.md
-- While the player is in a 5-player dungeon with a group, the party members are remembered. When the player
-- leaves the instance or the group disbands, a small non-modal card offers the stars and the private comment for
-- up to four of them, never in combat and once per run. Ratings and comments are the ones of the social diary.
local Z = ZenialCommunity
local A, L = Z.Adapter, Z.Logic
local P = { MAX = 4 }
Z.RatingPrompt = P
local W, ROW = 340, 36
local EVENTS = { 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'GROUP_ROSTER_UPDATE', 'PLAYER_REGEN_ENABLED', 'PLAYER_ALIVE', 'PLAYER_UNGHOST' }
local function tr(s, ...) return Z.T(s, ...) end
local function diary() return Z.SocialDiary end

-- Name of the 5-player dungeon the player is in; raids and the open world do not count.
local function dungeon()
    local name, kind = A.Call(GetInstanceInfo)
    if kind == 'party' and L.Text(name, 96) then return name end
end
local function groupSize()
    local total = A.Call(GetNumGroupMembers)
    return type(total) == 'number' and total or 0
end
local function capture(run, total)
    local D = diary()
    run.scan = (run.scan or 0) + 1
    for i = 1, math.min(total - 1, 4) do
        local unit = 'party' .. i
        if A.Call(UnitIsUnit, unit, 'player') ~= true then
            local key, target = D.UnitKey(unit)
            if key and key ~= Z.me.key and not Z.db.blocked[key] then
                local info = D.UnitDetails(unit)
                run.seq = run.seq + 1
                local m = run.members[key]
                if not m then m = { key = key, target = target }; run.members[key] = m end
                m.classFile, m.level, m.seq = info.classFile or m.classFile, info.level or m.level, run.seq
                m.here, m.scan = true, run.scan
            end
        end
    end
end
-- The run is over: it waits to be shown (now, or after the fight).
function P.Finish()
    local run = P.run
    P.run = nil
    if run then
        -- Members already offered in their own card when they left are not listed again.
        for key, m in pairs(run.members) do if m.handled then run.members[key] = nil end end
        if next(run.members) then P.pending = run end
    end
end
-- A member who was with the player in this run is gone while the player stays in a group: rate them right away.
local function detectLeavers(run, total)
    if run.total and total < run.total then
        for _, m in pairs(run.members) do
            if m.here and m.scan ~= run.scan then
                m.here = false
                if not m.handled then
                    m.handled = true
                    P.leavers = P.leavers or {}
                    P.leavers[#P.leavers + 1] = m
                end
            end
        end
    end
    run.total = total
end
function P.TryShow()
    local run, leavers = P.pending, P.leavers
    if not run and not (leavers and #leavers > 0) then return end
    local D = diary()
    if not D or not D.PromptEnabled() then P.pending, P.leavers = nil, nil; return end
    if A.Call(InCombatLockdown) == true or A.Call(UnitAffectingCombat, 'player') == true then return end
    if run then
        -- The end-of-run card lists everyone not handled yet, leavers included; leavers still waiting for the
        -- end of a fight (removed from the run as handled) come along.
        for _, m in ipairs(leavers or {}) do run.members[m.key] = run.members[m.key] or m end
        P.pending, P.leavers = nil, nil
        P.Show(run)
    else
        local members = {}
        for _, m in ipairs(leavers) do members[m.key] = m end
        P.leavers = nil
        P.Show({ members = members }, #leavers == 1 and tr('%s left the group', leavers[1].target) or tr('Players left the group'))
    end
end
function P.Evaluate()
    local D = diary()
    if not Z.db or not D or not D.store then return end
    if not D.PromptEnabled() then P.run, P.pending, P.leavers = nil, nil, nil; return end
    local name, total = dungeon(), groupSize()
    if name then
        if P.run and P.run.name ~= name then P.Finish() end
        if total >= 2 and A.Call(IsInRaid) ~= true then
            P.run = P.run or { name = name, members = {}, seq = 0 }
            capture(P.run, total)
            detectLeavers(P.run, total)
        elseif P.run then
            P.Finish()
        end
    -- A ghost running back to the entrance is still on the same run.
    elseif P.run and A.Call(UnitIsDeadOrGhost, 'player') ~= true then
        P.Finish()
    end
    P.TryShow()
end
function P.OnEvent(event)
    if not Z.db or not diary() or not diary().store then return end
    if event == 'PLAYER_REGEN_ENABLED' then P.TryShow() else P.Evaluate() end
end

-- ---------------------------------------------------------------------------------------------
-- The card
-- ---------------------------------------------------------------------------------------------
local function classLine(m)
    local class = m.classFile and Z.Locale and Z.Locale.Class(nil, m.classFile) or ''
    local level = m.level and (tr('Level') .. ' ' .. m.level) or ''
    return level ~= '' and class ~= '' and (level .. ' · ' .. class) or (level .. class)
end
function P.Refresh()
    local f = P.frame
    if not f or not P.members then return end
    local D, T, K = diary(), Z.Theme, Z.Kit
    for i, row in ipairs(f.rows) do
        local m = P.members[i]
        row:SetShown(m ~= nil)
        if m then
            local hex = T.ClassColorHex(m.classFile)
            row.name:SetText(hex and ('|cff' .. hex .. m.target .. '|r') or K.Paint('text', m.target))
            row.class:SetText(classLine(m))
            row.stars:SetValue(D.Rating(m.key), not D.readOnly)
            row.sel:SetShown(P.selected == i)
        end
    end
    local m = P.members[P.selected]
    f.noteCaption:SetText(tr('Private comment') .. (m and (' · ' .. m.target) or ''))
    P.noteBinding = true
    f.note:SetText(m and Z.Social.GetNote(m.key) or '')
    P.noteBinding = false
    f.note:SetEnabled(m ~= nil and not D.readOnly)
end
function P.Select(i)
    if P.members and P.members[i] then P.selected = i; P.Refresh() end
end
function P.Pick(i, stars)
    local m = P.members and P.members[i]
    if not m then return end
    local ok, why = diary().SetRating(m.key, m.target, stars)
    if not ok and Z.UI and Z.UI.Message then Z.UI.Message(tr(why)) end
    P.selected = i
    P.Refresh()
    -- An open diary shows the new stars right away.
    if Z.UI and Z.UI.socialDiary and Z.UI.socialDiary:IsShown() then Z.UI.RefreshSocialDiary() end
end
local function saveNote()
    local m = P.members and P.members[P.selected]
    if not m or P.noteBinding or diary().readOnly then return end
    local text = P.frame.note:GetText()
    local ok, why = Z.Social.Note(m.key, text)
    if ok then
        P.noteError = nil
        if Z.UI and Z.UI.NoteSaved then Z.UI.NoteSaved(m.key, text) end
        if Z.UI and Z.UI.socialDiary and Z.UI.socialDiary:IsShown() then Z.UI.RefreshSocialDiary() end
    elseif P.noteError ~= why then
        P.noteError = why
        if Z.UI and Z.UI.Message then Z.UI.Message(tr(why)) end
    end
end
local function build()
    if P.frame then return P.frame end
    local T, K, U = Z.Theme, Z.Kit, Z.UI
    if not (T and K and U and U.CreateRatingStars and type(CreateFrame) == 'function' and UIParent) then return nil end
    local f = CreateFrame('Frame', nil, UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
    f:SetSize(W, 300)
    f:SetFrameStrata('DIALOG')
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    -- Right of the screen centre: clear of the top-left pixel strip and the left edge.
    f:SetPoint('RIGHT', UIParent, 'RIGHT', -60, 0)
    T.Shell(f)
    f.title = T.Text(f, tr('Rate your group'), 'GameFontNormalLarge')
    K.DialogHeader(f, f.title, function() f:Hide() end)
    f.rows = {}
    for i = 1, P.MAX do
        local row = CreateFrame('Button', nil, f)
        row:SetSize(W - 24, ROW)
        row:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -(52 + (i - 1) * ROW))
        row.sel = row:CreateTexture(nil, 'BACKGROUND')
        row.sel:SetAllPoints()
        T.Tint(row.sel, 'SetColorTexture', 'hover', .12)
        row.name = T.Text(row, '', 'GameFontHighlight')
        row.name:SetPoint('TOPLEFT', row, 'TOPLEFT', 6, -3)
        row.name:SetWidth(170)
        row.name:SetWordWrap(false)
        row.class = T.Text(row, '', 'GameFontHighlightSmall')
        row.class:SetPoint('TOPLEFT', row, 'TOPLEFT', 6, -19)
        row.class:SetWidth(170)
        row.class:SetWordWrap(false)
        T.Font(row.class, 'caption', 'dim')
        row.stars = U.CreateRatingStars(row, 20, function(stars) P.Pick(i, stars) end)
        row.stars:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -4, -8)
        row:SetScript('OnClick', function() P.Select(i) end)
        f.rows[i] = row
    end
    f.noteCaption = T.Text(f, '', 'GameFontHighlightSmall')
    T.Font(f.noteCaption, 'caption', 'dim')
    f.noteCaption:SetWidth(W - 24)
    f.noteCaption:SetWordWrap(false)
    local e = CreateFrame('EditBox', nil, f, 'InputBoxTemplate')
    e:SetAutoFocus(false)
    e:SetSize(W - 24, 56)
    e:SetMultiLine(true)
    e:SetMaxLetters(500)
    if e.SetMaxBytes then e:SetMaxBytes(500) end
    e:SetFontObject('GameFontHighlightSmall')
    T.StyleEditBox(e)
    T.FieldBackground(e)
    e:SetScript('OnEscapePressed', function(s) s:ClearFocus() end)
    -- Enter would add a line break, which the note check rejects: it becomes a space. The note saves while typing.
    e:SetScript('OnTextChanged', function(box)
        local text = box:GetText() or ''
        if text:find('[\r\n]') then box:SetText((text:gsub('[\r\n]+', ' '))); return end
        saveNote()
    end)
    f.note = e
    f.done = T.Button(f, tr('Done'), 110, 26, function() f:Hide() end)
    f.done:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -12, 12)
    f:Hide()
    P.frame = f
    return f
end
-- Shows the card for a finished run or for leavers: up to four members, the latest seen.
-- While the card is still open, new leavers and the rest of the run are added to it instead of replacing it,
-- so members who leave one after another (the end of a dungeon) all stay on one card.
function P.Show(run, title)
    local f = build()
    if not f then return false end
    local list = {}
    for _, m in pairs(run.members) do list[#list + 1] = m end
    table.sort(list, function(a, b) if a.seq ~= b.seq then return a.seq > b.seq end; return a.key < b.key end)
    local open = f:IsShown() and P.members and #P.members > 0
    local kind = title and 'LEAVE' or 'END'
    if open then
        local merged, seen = {}, {}
        for _, m in ipairs(P.members) do merged[#merged + 1] = m; seen[m.key] = true end
        for _, m in ipairs(list) do
            if not seen[m.key] and #merged < P.MAX then merged[#merged + 1] = m; seen[m.key] = true end
        end
        list = merged
        -- A card that only names leavers becomes the card of the group once the run ends.
        if P.kind == 'END' or kind == 'END' then
            kind, title = 'END', nil
        elseif #list > 1 then
            title = tr('Players left the group')
        end
    else
        while #list > P.MAX do table.remove(list) end
        table.sort(list, function(a, b) if a.seq ~= b.seq then return a.seq < b.seq end; return a.key < b.key end)
    end
    f.title:SetText(title or tr('Rate your group'))
    local keep = open and P.members[P.selected] and P.members[P.selected].key
    P.members, P.selected, P.noteError, P.kind = list, 1, nil, kind
    for i, m in ipairs(list) do
        if keep and m.key == keep then P.selected = i; break end
        if not keep and not diary().Rating(m.key) then P.selected = i; break end
    end
    local n = #list
    f:SetHeight(184 + n * ROW)
    local y = 52 + n * ROW + 10
    f.noteCaption:ClearAllPoints(); f.noteCaption:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -y)
    f.note:ClearAllPoints(); f.note:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -(y + 16))
    P.Refresh()
    f:Show()
    return true
end

local events = CreateFrame('Frame')
for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
events:SetScript('OnEvent', function(_, event) P.OnEvent(event) end)
return P
