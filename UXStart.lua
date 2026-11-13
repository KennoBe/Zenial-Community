-- Start page (formerly "Today"): what is going on in the ZENIAL community right now. Who is online, how many
-- groups are open, how many players look for one, what is planned, what waits for the player, and the
-- instances that are asked for at the moment. Group search itself lives under Activities (UXFinder.lua).
--
-- The page is one frame over page 9. The former content (private wishes and their feed) is hidden, its code
-- and stored data are untouched. Every figure counts members of the ZENIAL community the client can reach,
-- never the whole realm.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local C = Z.GroupFinderCatalog
if type(U) ~= 'table' or type(T) ~= 'table' or type(K) ~= 'table' or type(C) ~= 'table' or type(U.Finder) ~= 'table' then
    return
end
local F = U.Finder
local S = {}
U.Start = S

local GAP = 12
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

-- Figures of the page. Online members are known contacts that are not blocked and reachable right now.
function S.Figures()
    local snap = C.Snapshot()
    local out = { online = 0, members = 0, groups = 0, seekers = #snap.seekers, planned = #snap.planned, help = #snap.other, requests = 0, waiting = 0, partners = 0, snapshot = snap }
    local inspected = 0
    for key in pairs(Z.db.contacts or {}) do
        inspected = inspected + 1
        if inspected > (L.MAX_CONTACTS or 5000) then
            break
        end
        if key ~= Z.me.key and not Z.db.blocked[key] then
            out.members = out.members + 1
            if Z.IsOnline(key) then
                out.online = out.online + 1
            end
        end
    end
    for _, r in ipairs(snap.groups) do
        if C.Wanted(r.data) > 0 then
            out.groups = out.groups + 1
        end
    end
    -- Requests that wait for the player (own group, own events) and requests the player waits on.
    local own = snap.own.group
    if own then
        out.requests = out.requests + (L.ApplicationCounts(Z.db, 'group', own.id))
    end
    for _, rows in ipairs({ snap.groups, snap.planned }) do
        for _, r in ipairs(rows) do
            if r.own and r.kind == 'EVENT' then
                for _, p in pairs(r.data and r.data.participants or {}) do
                    if p.state == 'REQUESTED' then
                        out.requests = out.requests + 1
                    end
                end
            elseif not r.own then
                local state = type(r.application) == 'table' and r.application.state
                if state == 'applied' or state == 'invited' or state == 'REQUESTED' then
                    out.waiting = out.waiting + 1
                end
            end
        end
    end
    local Q, G = Z.QuestHelper, Z.QuestGroups
    if Q and G and Q.Sharing and Q.Sharing() and G.CurrentCandidates then
        out.partners = #(G.CurrentCandidates())
    end
    return out
end

-- Catalogue activities with open groups or players looking, busiest first.
local function busiest(snap, limit)
    local list = {}
    for id, stats in pairs(snap.by) do
        local e = C.Get(id)
        if e and (stats.groups > 0 or stats.seekers > 0 or stats.planned > 0) then
            list[#list + 1] = { entry = e, stats = stats, weight = stats.groups * 3 + stats.seekers * 2 + stats.planned }
        end
    end
    table.sort(list, function(a, b)
        if a.weight ~= b.weight then
            return a.weight > b.weight
        end
        return a.entry.id < b.entry.id
    end)
    for index = #list, limit + 1, -1 do
        list[index] = nil
    end
    return list
end

local TILES = {
    { key = 'online', icon = 'members', label = 'Members online', go = function()
        U.Navigate('members')
    end },
    { key = 'groups', icon = 'activities', label = 'Open groups', go = function()
        U.Navigate('activities', 'now')
    end },
    { key = 'seekers', icon = 'search', label = 'Players looking for a group', go = function()
        U.Navigate('activities', 'now')
    end },
    { key = 'planned', icon = 'calendar', label = 'Planned groups', go = function()
        U.Navigate('activities', 'now')
    end },
}
local SMALL = {
    { key = 'requests', icon = 'invite', label = 'Requests waiting for you', go = function()
        local snap = S.figures and S.figures.snapshot
        if snap and snap.own.group then
            U.OpenActivity(snap.own.group.key)
        else
            U.Navigate('activities', 'now')
        end
    end },
    { key = 'waiting', icon = 'clock', label = 'Your open requests', go = function()
        U.Navigate('groups', 'outgoing')
    end },
    { key = 'help', icon = 'quests', label = 'Quest and PvP help', go = function()
        U.Navigate('activities', 'now')
    end },
    { key = 'partners', icon = 'quests', label = 'Players with quests in common', go = function()
        U.Navigate('activities', 'quests')
    end },
}
local LINKS = {
    { 'Create group', 170, 'primary', function()
        U.Navigate('activities', 'now')
        U.OpenFinderCreate(nil)
    end },
    { 'Dungeons', 120, 'secondary', function()
        U.Navigate('activities', 'dungeons')
    end },
    { 'Raids', 110, 'secondary', function()
        U.Navigate('activities', 'raids')
    end },
    { 'PvP', 100, 'secondary', function()
        U.Navigate('activities', 'pvp')
    end },
    { 'Questing and levelling', 120, 'secondary', function()
        U.Navigate('activities', 'quests')
    end },
}

local function size()
    local page = U.pages[9]
    local width, height = page:GetWidth(), page:GetHeight()
    return math.max(640, type(width) == 'number' and width > 0 and width or 856), math.max(360, type(height) == 'number' and height > 0 and height or 500)
end

function U.CreateStart()
    if S.frame then
        return S.frame
    end
    local page = U.pages[9]
    local frame = CreateFrame('Frame', nil, page)
    S.frame = frame
    frame:SetAllPoints(page)
    frame:SetFrameLevel((page:GetFrameLevel() or 1) + 8)
    frame:EnableMouse(true)
    frame.fill = frame:CreateTexture(nil, 'BACKGROUND')
    frame.fill:SetPoint('TOPLEFT', -8, 6)
    frame.fill:SetPoint('BOTTOMRIGHT', 8, -6)
    T.Tint(frame.fill, 'SetColorTexture', 'bg')
    S.tiles, S.small = {}, {}
    for index, spec in ipairs(TILES) do
        S.tiles[index] = K.StatTile(frame, { icon = spec.icon, label = tr(spec.label), value = 0, onClick = spec.go })
    end
    for index, spec in ipairs(SMALL) do
        S.small[index] = K.StatTile(frame, { icon = spec.icon, label = tr(spec.label), value = 0, onClick = spec.go })
    end
    S.scope = K.Text(frame, tr('Figures from the ZENIAL community'), 'caption', 'muted')
    call(S.scope, 'SetWordWrap', false)
    S.status = K.Card(frame, 'raised')
    K.Accent(S.status, 'gold')
    S.status.over = K.Text(S.status, '', 'overline', 'goldDim')
    S.status.over:SetPoint('TOPLEFT', 14, -7)
    S.status.over:SetWidth(300)
    S.status.over:SetHeight(12)
    S.status.line = K.Text(S.status, '', 'heading', 'text')
    S.status.line:SetPoint('TOPLEFT', 14, -23)
    S.status.line:SetHeight(15)
    call(S.status.line, 'SetWordWrap', false)
    S.status.open = T.Button(S.status, tr('Show'), 130, 24, function()
        local snap = S.figures and S.figures.snapshot
        local search = snap and snap.own.search
        if search and C.Get(search.title) then
            U.OpenFinderActivity(search.title)
        else
            U.Navigate('activities', 'now')
        end
    end, 'secondary')
    S.status.open:SetPoint('RIGHT', -10, 0)
    S.header = K.SectionHeader(frame, tr('In demand right now'))
    S.instances = {}
    S.empty = K.Text(frame, '', 'body', 'dim')
    call(S.empty, 'SetWordWrap', true)
    S.links = {}
    for index, spec in ipairs(LINKS) do
        S.links[index] = T.Button(frame, tr(spec[1]), spec[2], 26, spec[4], spec[3])
        S.links[index].zenialWidth = spec[2]
    end
    return frame
end

function U.RefreshStart()
    if not U.pages or not U.pages[9] or not U.homeList then
        return
    end
    local frame = U.CreateStart()
    -- The former content of the page stays hidden under the start page (see UXFinder.lua, cover).
    F.CoverPage(U.pages[9], frame, true)
    if not U.pages[9]:IsShown() then
        return
    end
    local width, height = size()
    local figures = S.Figures()
    S.figures = figures
    local snap = figures.snapshot
    local tileWidth = math.floor((width - 3 * GAP) / 4)
    for index, spec in ipairs(TILES) do
        local tile, value = S.tiles[index], figures[spec.key]
        tile:ClearAllPoints()
        tile:SetPoint('TOPLEFT', (index - 1) * (tileWidth + GAP), 0)
        tile:SetSize(tileWidth, 68)
        tile:SetValue(spec.key == 'online' and value .. ' / ' .. figures.members or value, value == 0 and 'muted' or (spec.key == 'groups' and 'success' or spec.key == 'seekers' and 'accentBlue' or 'text'))
    end
    for index, spec in ipairs(SMALL) do
        local tile, value = S.small[index], figures[spec.key]
        tile:ClearAllPoints()
        tile:SetPoint('TOPLEFT', (index - 1) * (tileWidth + GAP), -80)
        tile:SetSize(tileWidth, 60)
        tile:SetValue(value, value == 0 and 'muted' or (spec.key == 'requests' and 'goldBright' or 'text'))
    end
    S.scope:ClearAllPoints()
    S.scope:SetPoint('TOPLEFT', 2, -146)
    S.scope:SetWidth(width - 4)
    S.scope:SetHeight(13)
    local y = 168
    -- Own group or own search, one line.
    local group, search = snap.own.group, snap.own.search
    S.status:SetShown(group ~= nil or search ~= nil)
    if group or search then
        local names = {}
        if group then
            names[1] = Z.Locale.Activity(group.title)
        else
            for index, id in ipairs(C.SearchActivities(search.data)) do
                names[index] = Z.Locale.Activity(id)
            end
        end
        S.status.over:SetText(K.Upper(tr(group and 'My Group' or 'My search')))
        S.status.line:SetText(table.concat(names, ' · '))
        S.status.line:SetWidth(math.max(80, width - 170))
        S.status:ClearAllPoints()
        S.status:SetPoint('TOPLEFT', 0, -y)
        S.status:SetSize(width, 46)
        y = y + 58
    end
    S.header:ClearAllPoints()
    S.header:SetPoint('TOPLEFT', 0, -y)
    S.header:SetWidth(width)
    y = y + 26
    local footer = 34
    local busy = busiest(snap, 4)
    local tileHeight = math.min(math.floor(tileWidth * 9 / 16), math.max(60, height - y - footer - 8))
    for index = 1, 4 do
        local item = busy[index]
        local tile = S.instances[index]
        if item and not tile then
            tile = F.CreateTile(frame)
            S.instances[index] = tile
        end
        if tile then
            tile:SetShown(item ~= nil)
            if item then
                tile:ClearAllPoints()
                tile:SetPoint('TOPLEFT', (index - 1) * (tileWidth + GAP), -y)
                F.UpdateTile(tile, item.entry, item.stats, tileWidth, tileHeight)
            end
        end
    end
    S.header:SetCount(#busy > 0 and tostring(#busy) or '')
    S.empty:SetShown(#busy == 0)
    if #busy == 0 then
        S.empty:ClearAllPoints()
        S.empty:SetPoint('TOPLEFT', 2, -y)
        S.empty:SetWidth(width - 4)
        S.empty:SetHeight(40)
        S.empty:SetText(tr('Nothing is open in the ZENIAL community right now. Create a group, or pick an instance under Dungeons and look for one.'))
    end
    local x = 0
    for _, button in ipairs(S.links) do
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', x, -(height - 28))
        x = x + button.zenialWidth + 6
    end
end
function U.LayoutStart()
    if S.frame and U.pages[9]:IsShown() then
        U.RefreshStart()
    end
end

-- The page's refresh (U.Refresh, page 9) keeps the former feed up to date for its own callers and draws the
-- start page afterwards.
local refreshHome = U.RefreshCommunityHome
function U.RefreshCommunityHome(...)
    if refreshHome then
        refreshHome(...)
    end
    U.RefreshStart()
end

return S
