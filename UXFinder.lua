-- Group finder ("adventure browser"): picture tiles per dungeon, raid and battleground, the groups and the
-- players looking for one behind each tile, and what is going on right now. A presentation only: every
-- figure comes from GroupFinderCatalog.Snapshot (ActivityBoard rows) and every action calls the existing
-- workflow (apply, withdraw, invite, whisper, editor, details dialog). See
-- _dev/addons/ZenialCommunity/GROUPFINDER-REDESIGN-PLAN.md.
--
-- The finder is one frame over page 10. The former list stays underneath as the "list view".
-- Its controls are created with T.* / K.* directly: the S.* helpers register controls for the proportional
-- page layout, which would move them.
local Z = ZenialCommunity
local U, L, A, T, K = Z.UI, Z.Logic, Z.Adapter, Z.Theme, Z.Kit
local C, Art, J = Z.GroupFinderCatalog, Z.GroupFinderArt, Z.DungeonJournalLink
if type(U) ~= 'table' or type(T) ~= 'table' or type(K) ~= 'table' or type(C) ~= 'table' or type(Art) ~= 'table' then
    return
end

local F = { view = 'now', filters = { level = false, groups = false, seekers = false }, query = '' }
U.Finder = F

local VIEWS = { 'now', 'dungeons', 'raids', 'pvp', 'quests', 'other' }
local VIEW_LABEL = { now = 'Live', dungeons = 'Dungeons', raids = 'Raids', pvp = 'PvP', quests = 'Levelling', other = 'Miscellaneous' }
local VIEW_WIDTH = { now = 76, dungeons = 94, raids = 68, pvp = 58, quests = 88, other = 110 }
-- The row of tabs is shared with page 3 (events and own requests): the six views of the finder, then two
-- more places with a little room between. Width of "Create group" included, the row ends before it at 856.
local EXTRA_TABS = { 'events', 'requests' }
local EXTRA_LABEL = { events = 'Events', requests = 'Requests' }
local EXTRA_WIDTH = { events = 68, requests = 92 }
local TAB_GAP, EXTRA_GAP, CREATE_WIDTH, LIST_VIEW_WIDTH = 2, 14, 150, 120
local VIEW_KIND = { dungeons = 'DUNGEON', raids = 'RAID', pvp = 'PVP' }
local VIEW_CATEGORY = { dungeons = 'DUNGEON', raids = 'RAID', pvp = 'PVP', quests = 'QUEST', other = 'CUSTOM' }
local KIND_VIEW = { DUNGEON = 'dungeons', RAID = 'raids', PVP = 'pvp' }
local ROLES = { 'TANK', 'HEALER', 'DAMAGER' }
local ROLE_FIELD = { TANK = 'tank', HEALER = 'healer', DAMAGER = 'dd' }
-- Role symbols: Media/Roles.tga, four cells of 64 px (_dev/tools/generate_community_role_icons.py).
local ROLE_ATLAS = 'Interface\\AddOns\\ZenialCommunity\\Media\\Roles.tga'
local ROLE_CELL = { TANK = 0, HEALER = 1, DAMAGER = 2, SEEKER = 3 }
local GAP = 12
local GUTTER = 18 -- room of the scroll bar inside a scroll area
local CARD_HEIGHT = 104
local TILE_SHAPE = 16 / 9

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
local function paint(key, value)
    return K.Paint(key, value)
end
local function oneLine(fs, width, height)
    fs:SetWidth(width)
    fs:SetHeight(height or 14)
    call(fs, 'SetWordWrap', false)
    return fs
end
local function setRoleIcon(texture, role, colorKey)
    local cell = ROLE_CELL[role] or 0
    texture:SetTexture(ROLE_ATLAS)
    if texture.SetTexCoord then
        texture:SetTexCoord(cell / 4, (cell + 1) / 4, 0, 1)
    end
    T.Tint(texture, 'SetVertexColor', colorKey or T.roleColors[role] or 'textSoft')
end
local function activityName(id)
    return Z.Locale.Activity(id)
end
-- Texts in another script (a Russian, Korean or Chinese player name, a note). The texts of the addon keep the
-- font file of the client's Latin alphabet (T.Font), which has no such letters: they would show as empty
-- boxes. A text that holds them takes the font the client has for that alphabet, at the same size.
local ALPHABET_FILE = {}
local function alphabetOf(text)
    if type(text) ~= 'string' then
        return nil
    end
    -- The first byte of a letter tells its block: Cyrillic, Korean, Chinese. Punctuation (dashes, quotation
    -- marks, the ellipsis) starts with a byte of the same range and is passed over.
    for lead in text:gmatch('[\208-\237]') do
        local byte = lead:byte()
        if byte <= 211 then
            return 'russian'
        elseif byte >= 234 then
            return 'korean'
        elseif byte >= 227 and byte <= 233 then
            return 'simplifiedchinese'
        end
    end
    return nil
end
local function alphabetFile(alphabet)
    if ALPHABET_FILE[alphabet] == nil then
        local file = false
        local base = _G.GameFontNormal
        if type(base) == 'table' and type(base.GetFontObjectForAlphabet) == 'function' then
            local ok, object = pcall(base.GetFontObjectForAlphabet, base, alphabet)
            if ok and type(object) == 'table' and type(object.GetFont) == 'function' then
                local read, found = pcall(object.GetFont, object)
                if read and type(found) == 'string' and found ~= '' then
                    file = found
                end
            end
        end
        -- The narrow font of the client has Cyrillic letters in every language version.
        if not file and alphabet == 'russian' then
            file = 'Fonts\\ARIALN.TTF'
        end
        ALPHABET_FILE[alphabet] = file
    end
    return ALPHABET_FILE[alphabet] or nil
end
local function scriptFont(fs, text)
    if type(fs.GetFont) ~= 'function' or type(fs.SetFont) ~= 'function' then
        return
    end
    if not fs.zenialFont then
        local ok, file, size, flags = pcall(fs.GetFont, fs)
        if not ok or type(file) ~= 'string' or file == '' then
            return
        end
        fs.zenialFont = { file, size, flags or '' }
    end
    local alphabet = alphabetOf(text)
    local file = alphabet and alphabetFile(alphabet) or fs.zenialFont[1]
    if fs.zenialFontFile ~= file then
        local ok, set = pcall(fs.SetFont, fs, file, fs.zenialFont[2], fs.zenialFont[3])
        if ok and set ~= false then
            fs.zenialFontFile = file
        elseif file ~= fs.zenialFont[1] then
            pcall(fs.SetFont, fs, fs.zenialFont[1], fs.zenialFont[2], fs.zenialFont[3])
            fs.zenialFontFile = fs.zenialFont[1]
        end
    end
end
-- Badge caption with an explicit text box: the tag then has a width the layout can rely on.
local function setBadge(badge, value, tone)
    if tone then
        badge:SetTone(tone)
    end
    badge:SetLabel(value)
    local width = badge.GetWidth and tonumber(badge:GetWidth()) or 60
    badge.text:ClearAllPoints()
    badge.text:SetPoint('LEFT', 0, 0)
    badge.text:SetWidth(width)
    badge.text:SetJustifyH('CENTER')
    call(badge.text, 'SetWordWrap', false)
    return width
end
local function plural(one, many, n)
    return n == 1 and tr(one) or Z.T(many, n)
end
local function countText(sort, n)
    if sort == 'groups' then
        return plural('1 group', '%d groups', n)
    elseif sort == 'seekers' then
        return plural('1 looking', '%d looking', n)
    end
    return plural('1 planned', '%d planned', n)
end
local function levelText(e)
    return e.min == e.max and Z.T('Level %d', e.min) or Z.T('Level %d–%d', e.min, e.max)
end
local function myLevel()
    return tonumber(Z.me and Z.me.level) or 0
end

-- ---------------------------------------------------------------------------------------------
-- Picture with the neutral ZENIAL look underneath (shown when the client has no picture)
-- ---------------------------------------------------------------------------------------------
local function createPicture(owner, glyphSize)
    local picture = {}
    picture.base = owner:CreateTexture(nil, 'BACKGROUND')
    T.SetGradient(picture.base, 'VERTICAL', 'panelRaised', 'inset')
    picture.glyph = K.Icon(owner, 'activities', glyphSize or 40, 'highlight')
    -- Corner brackets frame the neutral look, so it reads as a deliberate plate and not as a missing file.
    picture.corners = {}
    for _, corner in ipairs({ { 'TOPLEFT', 6, -6 }, { 'TOPRIGHT', -6, -6 }, { 'BOTTOMLEFT', 6, 6 }, { 'BOTTOMRIGHT', -6, 6 } }) do
        for _, shape in ipairs({ { 12, 1 }, { 1, 12 } }) do
            local line = owner:CreateTexture(nil, 'BORDER')
            line:SetPoint(corner[1], picture.base, corner[1], corner[2], corner[3])
            line:SetSize(shape[1], shape[2])
            T.Tint(line, 'SetColorTexture', 'goldDim', 0.55)
            picture.corners[#picture.corners + 1] = line
        end
    end
    picture.glyph:SetPoint('CENTER', picture.base, 'CENTER', 0, 0)
    picture.art = owner:CreateTexture(nil, 'ARTWORK')
    picture.art:SetAllPoints(picture.base)
    function picture:Place(point, x, y, width, height)
        self.width, self.height = width, height
        self.base:ClearAllPoints()
        self.base:SetPoint(point, owner, point, x, y)
        self.base:SetSize(width, height)
    end
    -- e: catalogue entry, or nil for an activity without one (glyph names the sort).
    function picture:Show(e, glyph, dimmed)
        local has = e ~= nil and Art.Apply(self.art, e, (self.width or 16) / math.max(1, self.height or 9))
        self.has = has and true or false
        -- SetShown(false) hides the base too; showing the picture brings it back.
        self.base:Show()
        self.art:SetShown(self.has)
        self.glyph:SetShown(not self.has)
        for _, line in ipairs(self.corners) do
            line:SetShown(not self.has)
        end
        if not self.has then
            T.SetIcon(self.glyph, glyph or (e and e.kind == 'PVP' and 'pvp') or 'activities', 'highlight')
        end
        -- Out of the player's level range: a little quieter, still clearly the instance.
        self.art:SetAlpha(dimmed and 0.62 or 1)
    end
    function picture:SetShown(shown)
        self.base:SetShown(shown)
        self.art:SetShown(shown and self.has == true)
        self.glyph:SetShown(shown and not self.has)
        for _, line in ipairs(self.corners) do
            line:SetShown(shown and not self.has)
        end
    end
    return picture
end

-- ---------------------------------------------------------------------------------------------
-- Scroll area
-- ---------------------------------------------------------------------------------------------
local function createScroll(parent)
    local scroll = CreateFrame('ScrollFrame', nil, parent, 'UIPanelScrollFrameTemplate')
    local child = CreateFrame('Frame', nil, scroll)
    child:SetSize(100, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    T.StyleScroll(scroll)
    T.AttachScrollWheel(scroll, 64)
    -- No sunken well: tiles and cards carry their own surface.
    if scroll.zenialTrack then
        scroll.zenialTrack:Hide()
    end
    function scroll:Fit(width, height, contentHeight)
        self:SetSize(width, height)
        self.child:SetWidth(math.max(1, width - GUTTER))
        self.child:SetHeight(math.max(1, contentHeight))
        if contentHeight <= height and (self.zenialOffset or 0) ~= 0 then
            self.zenialOffset = 0
            self:SetVerticalScroll(0)
        end
        T.UpdateScroll(self)
    end
    return scroll
end

-- ---------------------------------------------------------------------------------------------
-- Tiles
-- ---------------------------------------------------------------------------------------------
local function tileEdge(tile, hover)
    T.TintEdges(tile.edges, hover and 'gold' or tile.edgeKey or 'edgeDeep')
end
local function tileTooltip(tile)
    local e, stats = tile.entry, tile.stats
    if not e or not GameTooltip or not GameTooltip.SetOwner then
        return
    end
    GameTooltip:SetOwner(tile, 'ANCHOR_RIGHT')
    GameTooltip:AddLine(activityName(e.id), 1, 0.85, 0.42)
    local zone = C.Zone(e)
    GameTooltip:AddLine(levelText(e) .. ' · ' .. Z.T('%d players', e.size) .. (zone and ' · ' .. zone or ''), 0.78, 0.8, 0.85, true)
    if stats then
        GameTooltip:AddLine(countText('groups', stats.groups) .. ' · ' .. countText('seekers', stats.seekers) .. ' · ' .. countText('planned', stats.planned), 0.78, 0.8, 0.85, true)
    end
    GameTooltip:AddLine(tr('Figures from the ZENIAL community'), 0.5, 0.52, 0.58, true)
    local hint = U.FinderPublic and U.FinderPublic.TileHint(e.id)
    if hint then
        GameTooltip:AddLine(hint, 0.78, 0.8, 0.85, true)
    end
    GameTooltip:Show()
end
local function createTile(parent)
    local tile = CreateFrame('Button', nil, parent)
    tile.picture = createPicture(tile, 40)
    tile.picture.base:SetAllPoints(tile)
    tile.shade = tile:CreateTexture(nil, 'ARTWORK')
    call(tile.shade, 'SetDrawLayer', 'ARTWORK', 2)
    tile.shade:SetPoint('BOTTOMLEFT', 1, 1)
    tile.shade:SetPoint('BOTTOMRIGHT', -1, 1)
    T.SetGradient(tile.shade, 'VERTICAL', 'overlay', 'overlay', 0, 0.95)
    tile.glow = tile:CreateTexture(nil, 'HIGHLIGHT')
    tile.glow:SetPoint('TOPLEFT', 1, -1)
    tile.glow:SetPoint('BOTTOMRIGHT', -1, 1)
    T.Tint(tile.glow, 'SetColorTexture', 'white', 0.07)
    call(tile.glow, 'SetBlendMode', 'ADD')
    tile.edges = T.Edges(tile, 'OVERLAY')
    tile.name = K.Text(tile, '', 'heading', 'text')
    tile.name:SetPoint('BOTTOMLEFT', 10, 23)
    call(tile.name, 'SetShadowOffset', 1, -1)
    call(tile.name, 'SetShadowColor', 0, 0, 0, 1)
    tile.level = K.Text(tile, '', 'caption', 'textSoft')
    tile.level:SetPoint('BOTTOMLEFT', 10, 8)
    call(tile.level, 'SetShadowOffset', 1, -1)
    call(tile.level, 'SetShadowColor', 0, 0, 0, 1)
    tile.flag = K.Badge(tile, '', 'gold')
    tile.flag:SetPoint('TOPLEFT', 6, -6)
    tile.bell = K.Icon(tile, 'bell', 14, 'goldBright')
    tile.pills = { groups = K.Badge(tile, '', 'success'), seekers = K.Badge(tile, '', 'info'), planned = K.Badge(tile, '', 'neutral') }
    -- Groups of the public group search of the game: a mark of its own, never part of the community figures.
    tile.public = K.Badge(tile, '', 'neutral')
    tile:SetScript('OnEnter', function(self)
        tileEdge(self, true)
        tileTooltip(self)
    end)
    tile:SetScript('OnLeave', function(self)
        tileEdge(self, false)
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)
    tile:SetScript('OnClick', function(self)
        if self.entry then
            U.OpenFinderActivity(self.entry.id, true)
        end
    end)
    return tile
end
local function updateTile(tile, e, stats, width, height)
    tile.entry, tile.stats = e, stats
    tile:SetSize(width, height)
    tile.picture.width, tile.picture.height = width, height
    local fits = C.Fits(e, myLevel())
    tile.picture:Show(e, nil, not fits)
    tile.shade:SetHeight(math.floor(height * 0.62))
    tile.name:SetText(activityName(e.id))
    oneLine(tile.name, width - 20, 16)
    T.Tint(tile.name, 'SetTextColor', fits and 'text' or 'textSoft')
    tile.level:SetText(levelText(e) .. (e.kind == 'RAID' and ' · ' .. Z.T('%d players', e.size) or ''))
    oneLine(tile.level, width - 20, 13)
    T.Tint(tile.level, 'SetTextColor', fits and 'goldText' or 'dim')
    -- Own entries first, then an application, then the "new in Forever" mark.
    local flag, tone = nil, 'gold'
    if stats.ownGroup then
        flag = tr('Your group')
    elseif stats.ownSearch then
        flag = tr('Your search')
    elseif stats.applied then
        flag, tone = tr('Requested'), 'info'
    elseif e.new then
        flag, tone = tr('New'), 'neutral'
    end
    tile.flag:SetShown(flag ~= nil)
    if flag then
        setBadge(tile.flag, K.Upper(flag), tone)
    end
    local followed = Z.db.groupFollows[e.id] == true
    tile.bell:SetShown(followed)
    if followed then
        tile.bell:ClearAllPoints()
        if flag then
            tile.bell:SetPoint('LEFT', tile.flag, 'RIGHT', 6, 0)
        else
            tile.bell:SetPoint('TOPLEFT', 8, -8)
        end
    end
    local y = -6
    for _, sort in ipairs({ 'groups', 'seekers', 'planned' }) do
        local pill, n = tile.pills[sort], stats[sort]
        pill:SetShown(n > 0)
        if n > 0 then
            setBadge(pill, countText(sort, n))
            pill:ClearAllPoints()
            pill:SetPoint('TOPRIGHT', -6, y)
            y = y - 21
        end
    end
    local public = U.FinderPublic and U.FinderPublic.TileText(e.id)
    tile.public:SetShown(public ~= nil)
    if public then
        setBadge(tile.public, public)
        tile.public:ClearAllPoints()
        tile.public:SetPoint('TOPRIGHT', -6, y)
    end
    tile.edgeKey = (stats.ownGroup or stats.ownSearch) and 'gold' or (stats.groups > 0 or stats.seekers > 0) and 'goldDim' or 'edgeDeep'
    tileEdge(tile, false)
    if stats.ownGroup or stats.ownSearch then
        K.Accent(tile, 'gold')
    elseif tile.zenialAccent then
        tile.zenialAccent:Hide()
    end
end

-- ---------------------------------------------------------------------------------------------
-- Cards (one activity-board row each)
-- ---------------------------------------------------------------------------------------------
local function ownerFacts(r)
    if r.own then
        return Z.me.classFile, Z.me.class
    end
    local peer = Z.db.peers[r.owner]
    local data, presence = peer and peer.data, peer and peer.presence
    return data and data.classFile or presence and presence.classFile, data and data.class
end
local function partySize(r)
    local g = r.data
    local party = Z.ActivityParty and Z.ActivityParty.Info(r)
    if party and party.total then
        return party.total
    end
    if r.own then
        return A.GroupState().total
    end
    return math.max(1, g.size - C.Wanted(g))
end
-- The members of a ZENIAL party as symbols, like the card of a public group: who is there (as far as the
-- record tells their roles), then the places the group still looks for. { { role, free } }
local HAVE_ROLE = { TANK = 'TANK', HEALER = 'HEALER', DAMAGER = 'DAMAGER', DD = 'DAMAGER' }
local function ownerRole(r)
    if r.own then
        return L.Role(Z.db.roles)
    end
    local peer = Z.db.peers[r.owner]
    local data, presence = peer and peer.data, peer and peer.presence
    return L.Role(data and data.roles) or L.Role(presence and presence.role)
end
local function groupMembers(r, g, present)
    local out, known, total = {}, { TANK = 0, HEALER = 0, DAMAGER = 0 }, 0
    for token, count in tostring((C.SplitHave(g.have))):gmatch('(%u+)=(%d+)') do
        local role = HAVE_ROLE[token]
        if role then
            known[role] = known[role] + tonumber(count)
        end
    end
    for _, role in ipairs(ROLES) do
        for _ = 1, known[role] do
            if total < present then
                out[#out + 1] = { role = role }
                total = total + 1
            end
        end
    end
    -- Alone: the organizer with the role of the profile, where it is known.
    if total == 0 and present == 1 then
        local role = ownerRole(r)
        out[1] = { role = ROLE_FIELD[role or ''] and role or 'SEEKER' }
        total = 1
    end
    for _ = total + 1, present do
        out[#out + 1] = { role = 'SEEKER' }
    end
    for _, role in ipairs(ROLES) do
        for _ = 1, g[ROLE_FIELD[role]] or 0 do
            out[#out + 1] = { role = role, free = true }
        end
    end
    while #out > g.size do
        table.remove(out)
    end
    return out
end
local function wantedRoles(g)
    local parts = {}
    for _, role in ipairs(ROLES) do
        local n = g[ROLE_FIELD[role]] or 0
        if n > 0 then
            parts[#parts + 1] = { role, n .. ' ' .. Z.Locale.Role(role) }
        end
    end
    if #parts == 0 then
        return paint('dim', tr('Group is full'))
    end
    return paint('dim', tr('Needed') .. ': ') .. K.Roles(parts)
end
local function applicationBadge(r)
    local state = type(r.application) == 'table' and r.application.state
    if state == 'applied' or state == 'REQUESTED' then
        return tr('Request pending'), 'info'
    elseif state == 'invited' then
        return tr('Invited'), 'success'
    elseif state == 'joined' then
        return tr('In the group'), 'success'
    elseif state == 'CONFIRMED' then
        return tr('Confirmed'), 'success'
    elseif state == 'WAITLIST' then
        return tr('Waitlist'), 'warning'
    elseif state == 'rejected' or state == 'DECLINED' then
        return tr('Rejected'), 'danger'
    end
end
local function pendingRequests(r)
    if r.kind == 'EVENT' then
        local n = 0
        for _, p in pairs(r.data and r.data.participants or {}) do
            if p.state == 'REQUESTED' then
                n = n + 1
            end
        end
        return n
    end
    local open = L.ApplicationCounts(Z.db, r.kind == 'QUEST' and 'quest' or 'group', r.id)
    -- Whisper requests of the own open group count like applications.
    if r.own and r.kind == 'LIVE' and Z.WhisperInbox then
        open = open + Z.WhisperInbox.Pending()
    end
    return open
end
-- The warning badge of a poorly rated player: it takes the place of no badge and of the "New" and "Full" marks,
-- never of a contact or application state (Request pending, Invited, Waitlist, Rejected ...).
local function warnPoorly(d, text)
    if d.badge == nil or d.badge == tr('New') or d.badge == tr('Full') then
        d.badge, d.tone = text, 'danger'
    end
end
local function whisperAction(r, state)
    return { text = tr('Whisper'), enabled = state.whisper == true, click = function()
        U.ActivityWhisper(r.key)
    end }
end

-- Quests the player has in common with another member. The members share the ids of their quest log
-- (QuestHelper.lua, their own privacy switch); titles come from the player's own log. nil means unknown
-- (not shared, offline, own log not read yet) and is never shown as "none".
local function commonQuests(key)
    local Q = Z.QuestHelper
    if not Q or type(Q.MatchMember) ~= 'function' or not key or key == Z.me.key then
        return nil
    end
    return Q.MatchMember(key)
end
local function questTitles(ids)
    local Q, byID, titles = Z.QuestHelper, {}, {}
    for _, quest in ipairs(Q and Q.quests or {}) do
        byID[quest.id] = quest.title
    end
    for _, id in ipairs(ids or {}) do
        if byID[id] then
            titles[#titles + 1] = byID[id]
        end
    end
    table.sort(titles)
    return titles
end
local function commonText(n)
    return plural('1 quest in common', '%d shared quests', n)
end
-- Card of a member who shares quests with the player (Questing tab).
local function describePartner(m)
    local d = { actions = {}, glyph = 'quests' }
    local hex = T.ClassColorHex and T.ClassColorHex(m.classFile)
    d.title = hex and ('|cff' .. hex .. m.target .. '|r') or m.target
    local where = U.Shared.peerLocation and U.Shared.peerLocation(m.key)
    d.meta = Z.T('Level %d', tonumber(m.level) or 0)
        .. (m.classFile and ' · ' .. L.ClassName(nil, m.classFile) or '')
        .. ' · '
        .. tr(m.status)
        .. (type(where) == 'string' and where ~= '' and ' · ' .. where or '')
    d.common, d.commonTitles = m.common, questTitles(m.quests)
    d.roles = paint('goldBright', commonText(m.common))
    d.note, d.noteRaw = table.concat(d.commonTitles, ', '), true
    local Q = Z.QuestHelper
    d.actions[1] = { text = tr('Invite'), enabled = Q.CanInvite(m.key, m.quests[1]) == true, click = function()
        local ok, why = Q.Invite(m.key, m.quests[1])
        U.Message(ok and tr('Invitation submitted; awaiting response.') or tr(why or 'Quest match no longer available.'))
        U.RefreshFinder()
    end }
    d.actions[2] = { text = tr('Whisper'), click = function()
        if not A.Whisper(m.target) then
            U.Message(tr('Whisper is unavailable.'))
        end
    end }
    return d
end
-- Returns what a card shows for row r. context.named: the card stands among other activities and names its own.
local function describe(r, context)
    local d = { actions = {} }
    local state = U.ActivityActionState(r)
    local e = C.Get(r.title)
    d.entry, d.glyph = e, r.kind == 'QUEST' and 'quests' or r.kind == 'PVP' and 'pvp' or r.kind == 'EVENT' and 'calendar' or nil
    local name = r.kind == 'QUEST' and r.title or activityName(r.title)
    local match = not r.own and commonQuests(r.owner)
    if match then
        d.common, d.commonTitles = match.common, questTitles(match.quests)
    end
    if r.kind == 'LIVE' and r.data and C.IsSearch(r.data) then
        local g = r.data
        local classFile, class = ownerFacts(r)
        local hex = T.ClassColorHex and T.ClassColorHex(classFile, class)
        d.title = hex and ('|cff' .. hex .. r.ownerName .. '|r') or r.ownerName
        -- The private rating of the player: stars behind the name, a red badge for 1-2 stars, stars and comment on hover.
        local rating = not r.own and U.PlayerRating(r.ownerName) or nil
        if rating then
            d.title = d.title .. ' ' .. rating.markup
            d.hover = { title = r.ownerName, lines = { U.RatingTipText(rating) } }
        end
        local who = Z.T('Level %d', g.min) .. (classFile and ' · ' .. L.ClassName(class, classFile) or '')
        local wanted = C.SearchActivities(g)
        if context.named then
            local names = {}
            for index, id in ipairs(wanted) do
                names[index] = activityName(id)
            end
            d.meta = Z.T('Looking for: %s', table.concat(names, ', ')) .. ' · ' .. who
        else
            d.meta = who .. (#wanted > 1 and ' · ' .. plural('1 more instance', '%d more instances', #wanted - 1) or '')
        end
        d.roleItems = {}
        for _, role in ipairs(C.SearchRoles(g)) do
            d.roleItems[#d.roleItems + 1] = { role = role, text = Z.Locale.Role(role) }
        end
        d.note = g.note
        d.glyph = d.glyph or 'members'
        if r.own then
            d.badge, d.tone, d.accent = tr('Your search'), 'gold', 'gold'
            d.actions[1] = { text = tr('Stop search'), variant = 'danger', click = function()
                U.StopFinderSearch()
            end }
        else
            d.actions[1] = { text = tr('Invite'), enabled = state.whisper == true and A.GroupState().canInvite == true, click = function()
                U.InviteFinderSeeker(r.key)
            end }
            d.actions[2] = whisperAction(r, state)
            if rating and rating.low then
                warnPoorly(d, tr('Poorly rated'))
            end
        end
        return d
    end
    if r.kind == 'LIVE' and r.data then
        local g = r.data
        -- Built like the card of a public group: the organizer's name in the class colour, the members as
        -- symbols, the free places faint. The marks (ZENIAL, your group) and what only ZENIAL knows
        -- (level range, preferred classes, comment) tell the two apart.
        local classFile, class = ownerFacts(r)
        local hex = T.ClassColorHex and T.ClassColorHex(classFile, class)
        local owner = hex and ('|cff' .. hex .. r.ownerName .. '|r') or r.ownerName
        -- The private rating of the organizer: stars behind the name, a red badge for 1-2 stars, stars and comment on hover.
        local rating = not r.own and U.PlayerRating(r.ownerName) or nil
        local ownerShown = rating and owner .. ' ' .. rating.markup or owner
        local present = partySize(r)
        local levels = g.min == g.max and Z.T('Level %d', g.min) or Z.T('Level %d–%d', g.min, g.max)
        d.title = context.named and name or ownerShown
        d.meta = (context.named and not r.own and r.ownerName .. ' · ' or '') .. Z.T('%d/%d players', present, g.size) .. ' · ' .. levels
        -- Play style and "new players welcome" of the group, as on the card of a public group.
        local manner, mannerWords = C.Manner(g), {}
        local styles = Z.PublicLFG and Z.PublicLFG.Playstyles and Z.PublicLFG.Playstyles() or {}
        if styles[manner.style] then
            mannerWords[#mannerWords + 1] = paint('success', styles[manner.style].label)
        end
        if manner.beginners then
            mannerWords[#mannerWords + 1] = tr('New players welcome')
        end
        if #mannerWords > 0 then
            d.meta = d.meta .. paint('dim', ' · ') .. table.concat(mannerWords, paint('dim', ' · '))
        end
        local wanted = {}
        for _, role in ipairs(ROLES) do
            local n = g[ROLE_FIELD[role]] or 0
            if n > 0 then
                wanted[#wanted + 1] = { role = role, text = n .. ' ' .. Z.Locale.Role(role) }
            end
        end
        if type(g.size) == 'number' and g.size <= 5 then
            d.members = groupMembers(r, g, present)
            local parts = {}
            for index, item in ipairs(wanted) do
                parts[index] = { item.role, item.text }
            end
            d.roles = #parts > 0 and paint('dim', tr('Needed') .. ': ') .. K.Roles(parts) or paint('dim', tr('Group is full'))
        elseif #wanted > 0 then
            d.roleItems = wanted
        else
            d.roles = paint('dim', tr('Group is full'))
        end
        d.note = g.note
        -- Hover info: the organizer, and what the card has no room to spell out.
        local ownerLevel = r.own and tonumber(Z.me and Z.me.level) or (Z.db.peers[r.owner] and Z.db.peers[r.owner].data and tonumber(Z.db.peers[r.owner].data.level))
        local facts = {}
        if ownerLevel then
            facts[#facts + 1] = Z.T('Level %d', ownerLevel)
        end
        if classFile then
            facts[#facts + 1] = L.ClassName(class, classFile)
        end
        d.hover = { title = owner, lines = { name .. ' · ' .. Z.T('%d/%d players', present, g.size) .. ' · ' .. levels } }
        if #facts > 0 then
            d.hover.pair = { rating and ownerShown or owner, table.concat(facts, ' · ') }
        end
        if rating then
            d.hover.lines[#d.hover.lines + 1] = U.RatingTipText(rating)
        end
        if #mannerWords > 0 then
            d.hover.lines[#d.hover.lines + 1] = table.concat(mannerWords, paint('dim', ' · '))
        end
        -- Preferred classes lead the comment line, in their class colours.
        local classes = C.WantedClasses(g)
        if #classes > 0 then
            local names = {}
            for index, class in ipairs(classes) do
                local hex = T.ClassColorHex(class)
                local label = Z.Locale.Class(nil, class)
                names[index] = hex and ('|cff' .. hex .. label .. '|r') or label
            end
            d.note = paint('dim', Z.T('Preferred: %s', '')) .. table.concat(names, ', ')
                .. ((g.note or '') ~= '' and paint('dim', ' · ') .. '„' .. g.note .. '“' or '')
            d.noteRaw = true
            d.hover.lines[#d.hover.lines + 1] = paint('dim', Z.T('Preferred: %s', '')) .. table.concat(names, ', ')
        end
        if (g.note or '') ~= '' then
            d.hover.lines[#d.hover.lines + 1] = '„' .. g.note .. '“'
        end
        d.click = function()
            U.OpenActivity(r.key)
        end
        if r.own then
            local pending = pendingRequests(r)
            d.badge, d.tone, d.accent = tr('Your group'), 'gold', 'gold'
            d.actions[1] = { text = Z.T('Requests (%d)', pending), click = d.click }
            d.actions[2] = { text = tr('Edit'), enabled = state.edit == true, click = function()
                U.EditActivity(r.key)
            end }
            return d
        end
        d.badge, d.tone = applicationBadge(r)
        if not d.badge and C.Wanted(g) == 0 then
            d.badge, d.tone = tr('Full'), 'neutral'
        elseif not d.badge and g.start and g.start > A.Now() - 600 then
            d.badge, d.tone = tr('New'), 'gold'
        end
        if rating and rating.low then
            warnPoorly(d, tr('Poorly rated player in the group'))
        end
        if state.withdraw then
            d.actions[1] = { text = tr('Withdraw'), click = function()
                U.WithdrawActivity(r.key)
            end }
        else
            d.apply = state.join == true
            d.actions[1] = { text = tr('Request to join'), enabled = state.join == true and C.Wanted(g) > 0, click = function()
                U.StartFinderApply(r.key)
            end }
        end
        d.actions[2] = whisperAction(r, state)
        return d
    end
    if r.kind == 'EVENT' then
        local ev = r.data or {}
        local when = Z.ScheduleTime.Format(r.startsAt)
        d.title = context.named and name or when
        d.meta = (context.named and when .. ' · ' or '') .. Z.T('Organizer: %s', r.ownerName)
        local slots = ev.roleSlots
        if type(slots) == 'table' then
            local used = ev.participants and Z.ScheduledGroups.Counts(ev) or ev.used or {}
            d.roleItems = {}
            for _, role in ipairs(ROLES) do
                if (slots[role] or 0) > 0 then
                    d.roleItems[#d.roleItems + 1] = { role = role, text = (used[role] or 0) .. '/' .. slots[role] .. ' ' .. Z.Locale.Role(role) }
                end
            end
        end
        d.note = ev.note
        d.click = function()
            U.OpenActivity(r.key)
        end
        if r.own then
            d.badge, d.tone, d.accent = tr('Your event'), 'gold', 'gold'
            d.actions[1] = { text = Z.T('Requests (%d)', pendingRequests(r)), click = d.click }
            d.actions[2] = { text = tr('Edit'), enabled = state.edit == true, click = function()
                U.EditActivity(r.key)
            end }
            return d
        end
        d.badge, d.tone = applicationBadge(r)
        if not d.badge and r.saved then
            d.badge, d.tone = tr('Saved state'), 'neutral'
        elseif not d.badge and ev.carried then
            -- Kept visible by confirmed participants while the organizer is offline.
            d.badge, d.tone = tr('Organizer offline'), 'neutral'
        end
        -- A decision that reached the player through a participant, or an application left with one.
        local relay = Z.ScheduledRelay
        local follow = relay and Z.ScheduledGroups.Follow(r.owner, r.id)
        if follow then
            local carriedState, _, carriedOn = relay.Effective(follow)
            if carriedOn then
                d.badge = Z.ScheduledGroups.StateLabel(carriedState)
                d.tone = carriedState == 'CONFIRMED' and 'success' or carriedState == 'WAITLIST' and 'warning' or carriedState == 'DECLINED' and 'danger' or 'neutral'
                d.meta = d.meta .. ' · ' .. tr('carried on, not yet confirmed')
            elseif follow.pending and follow.pending.deposited then
                d.badge, d.tone = tr('Left with a participant'), 'info'
            end
        end
        if state.withdraw then
            d.actions[1] = { text = tr('Sign off'), click = function()
                U.WithdrawActivity(r.key)
            end }
        else
            d.actions[1] = { text = tr('Sign up'), enabled = state.join == true, click = function()
                U.JoinActivity(r.key)
            end }
        end
        d.actions[2] = { text = tr('Details'), click = d.click }
        return d
    end
    -- Quest assistance and PvP help: shown, opened in their own dialog.
    d.title = name
    d.meta = tr(r.kind == 'QUEST' and 'Quest assistance' or 'PvP Help') .. ' · ' .. Z.T('Organizer: %s', r.ownerName)
    d.note = r.data and r.data.note
    d.click = function()
        U.OpenActivity(r.key)
    end
    if r.own then
        d.badge, d.tone, d.accent = tr('Organized by you'), 'gold', 'gold'
    else
        d.badge, d.tone = applicationBadge(r)
    end
    d.actions[1] = { text = tr('Details'), click = d.click }
    return d
end

local function createCard(parent)
    local card = CreateFrame('Button', nil, parent)
    card.fill = card:CreateTexture(nil, 'BACKGROUND')
    card.fill:SetAllPoints()
    T.Tint(card.fill, 'SetColorTexture', 'panel')
    card.edges = T.Edges(card, 'BORDER')
    T.TintEdges(card.edges, 'line')
    card.glow = card:CreateTexture(nil, 'HIGHLIGHT')
    card.glow:SetPoint('TOPLEFT', 1, -1)
    card.glow:SetPoint('BOTTOMRIGHT', -1, 1)
    T.Tint(card.glow, 'SetColorTexture', 'white', 0.035)
    card.picture = createPicture(card, 26)
    card.title = K.Text(card, '', 'heading', 'text')
    card.meta = K.Text(card, '', 'caption', 'dim')
    card.roles = K.Text(card, '', 'caption', 'textSoft')
    card.note = K.Text(card, '', 'caption', 'textSoft')
    card.roleSlots = {}
    for index = 1, 3 do
        local icon = card:CreateTexture(nil, 'ARTWORK')
        icon:SetSize(14, 14)
        card.roleSlots[index] = { icon = icon, text = K.Text(card, '', 'caption', 'textSoft') }
    end
    card.badge = K.Badge(card, '', 'neutral')
    card.badge:SetPoint('TOPRIGHT', -8, -8)
    -- Source of the entry (ZENIAL or public), shown while both sources stand side by side.
    card.source = K.Badge(card, '', 'neutral')
    card.actions, card.arrows = {}, {}
    for index = 1, 2 do
        card.actions[index] = T.Button(card, '', 116, 22, nil, 'secondary')
        -- The arrow of an action with a list (the whisper texts of a public card).
        local arrow = T.Button(card, '', 22, 22, nil, 'secondary')
        T.StyleDropdown(arrow)
        arrow:Hide()
        card.arrows[index] = arrow
    end
    card.chips = {}
    for index, role in ipairs(ROLES) do
        card.chips[index] = T.Chip(card, Z.Locale.Role(role), 78, 20, function()
            F.applyRole = role
            U.RefreshFinder()
        end)
        card.chips[index].zenialRole = role
    end
    -- Titles of the quests in common, as far as the own log knows them.
    card:SetScript('OnEnter', function(self)
        -- A public group: who is in it.
        if self.public and U.FinderPublic then
            U.FinderPublic.Tooltip(self, self.public)
            return
        end
        local titles = self.zenialCommon
        -- A ZENIAL group without quests in common: who organizes it and what the card cannot spell out.
        local hover = self.zenialHover
        if (not titles or #titles == 0) and hover and GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:AddLine(hover.title, 1, 0.85, 0.42)
            for _, text in ipairs(hover.lines) do
                GameTooltip:AddLine(text, 0.78, 0.8, 0.85, true)
            end
            if hover.pair then
                if GameTooltip.AddDoubleLine then
                    GameTooltip:AddDoubleLine(hover.pair[1], hover.pair[2], 1, 1, 1, 0.78, 0.8, 0.85)
                else
                    GameTooltip:AddLine(hover.pair[1] .. '  ' .. hover.pair[2], 0.78, 0.8, 0.85)
                end
            end
            GameTooltip:Show()
            return
        end
        if not titles or #titles == 0 or not GameTooltip or not GameTooltip.SetOwner then
            return
        end
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:AddLine(commonText(#titles), 1, 0.85, 0.42)
        for index, title in ipairs(titles) do
            if index > 12 then
                GameTooltip:AddLine('…', 0.78, 0.8, 0.85)
                break
            end
            GameTooltip:AddLine(title, 0.78, 0.8, 0.85)
        end
        GameTooltip:Show()
    end)
    card:SetScript('OnLeave', function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)
    card:SetScript('OnClick', function(self)
        if self.zenialClick then
            self.zenialClick()
        end
    end)
    return card
end
-- The member symbols of a party in front of the role line of its card (d.members). Called for every card: one
-- without symbols gets its own hidden.
local function drawMembers(card, d, left)
    local icons, list = card.zenialMembers, d and d.members
    if not icons then
        if not list then
            return
        end
        icons = {}
        card.zenialMembers = icons
    end
    local x = left
    for index = 1, math.max(#icons, list and #list or 0) do
        local icon, member = icons[index], list and list[index]
        if member and not icon then
            icon = card:CreateTexture(nil, 'ARTWORK')
            icon:SetSize(16, 16)
            icons[index] = icon
        end
        if icon then
            icon:SetShown(member ~= nil)
            if member then
                setRoleIcon(icon, member.role)
                icon:SetAlpha(member.free and 0.28 or 1)
                icon:ClearAllPoints()
                icon:SetPoint('TOPLEFT', x, -42)
                x = x + 19
            end
        end
    end
    if list and #list > 0 then
        card.roles:ClearAllPoints()
        card.roles:SetPoint('TOPLEFT', x + 6, -44)
    end
end
local function updateCard(card, item, width, context)
    local r = item.row
    local FP = U.FinderPublic
    local d
    if item.partner then
        d = describePartner(item.partner)
    elseif item.public then
        -- A group of the public group search: its own description, nothing of the activity board.
        d = FP.Describe(item.public, context)
    else
        d = describe(r, context)
        if FP then
            FP.Mark(d, r)
        end
    end
    card.row, card.public = r, item.public
    card.zenialCommon = d.commonTitles
    card.zenialHover = d.hover
    card:SetSize(width, CARD_HEIGHT)
    card.zenialClick = d.click
    local left = 12
    local picture = context.thumbs == true and not item.partner
    card.picture:SetShown(false)
    if picture then
        card.picture:Place('TOPLEFT', 8, -8, 124, 70)
        card.picture:Show(d.entry, d.glyph)
        left = 142
    end
    if d.accent then
        K.Accent(card, d.accent)
    elseif card.zenialAccent then
        card.zenialAccent:Hide()
    end
    card.badge:SetShown(d.badge ~= nil)
    local badgeWidth = 0
    if d.badge then
        badgeWidth = setBadge(card.badge, d.badge, d.tone or 'neutral') + 10
    end
    card.source:SetShown(d.source ~= nil)
    if d.source then
        local sourceWidth = setBadge(card.source, d.source, d.sourceTone or 'neutral')
        card.source:ClearAllPoints()
        card.source:SetPoint('TOPRIGHT', -8 - (badgeWidth > 0 and badgeWidth - 4 or 0), -8)
        badgeWidth = (badgeWidth > 0 and badgeWidth - 4 or 0) + sourceWidth + 10
    end
    local applying = r ~= nil and F.applyKey == r.key and d.apply == true
    local textWidth = width - left - 12
    card.title:ClearAllPoints()
    card.title:SetPoint('TOPLEFT', left, -9)
    card.title:SetText(d.title or '')
    scriptFont(card.title, d.title)
    oneLine(card.title, math.max(40, textWidth - badgeWidth), 15)
    card.meta:ClearAllPoints()
    card.meta:SetPoint('TOPLEFT', left, -27)
    -- Quests in common with the organizer or the player looking, where both share their quests.
    local shared = not item.partner and d.common and paint('dim', ' · ') .. paint('goldBright', commonText(d.common)) or ''
    card.meta:SetText((d.meta or '') .. shared)
    scriptFont(card.meta, d.meta)
    oneLine(card.meta, textWidth, 13)
    card.roles:ClearAllPoints()
    card.roles:SetPoint('TOPLEFT', left, -44)
    local roleItems = not applying and d.roleItems or nil
    card.roles:SetText(applying and paint('dim', tr('Your role') .. ':') or not roleItems and d.roles or '')
    oneLine(card.roles, applying and 70 or textWidth, 13)
    -- Roles as symbol and word in the role colour: wanted places of a group, offered roles of a player.
    local slotX, slotWidth = left, math.floor(math.min(96, textWidth / 3))
    for index, slot in ipairs(card.roleSlots) do
        local roleItem = roleItems and roleItems[index]
        slot.icon:SetShown(roleItem ~= nil)
        slot.text:SetShown(roleItem ~= nil)
        if roleItem then
            setRoleIcon(slot.icon, roleItem.role)
            slot.icon:ClearAllPoints()
            slot.icon:SetPoint('TOPLEFT', slotX, -43)
            slot.text:ClearAllPoints()
            slot.text:SetPoint('TOPLEFT', slotX + 18, -44)
            slot.text:SetText(roleItem.text)
            T.Tint(slot.text, 'SetTextColor', T.roleColors[roleItem.role] or 'textSoft')
            oneLine(slot.text, slotWidth - 20, 13)
            slotX = slotX + slotWidth
        end
    end
    -- A party shows its members as symbols in front of the role line.
    drawMembers(card, not applying and d or nil, left)
    -- Role choice of a join request: only the roles the group still looks for.
    local chipX = left + 74
    for _, chip in ipairs(card.chips) do
        local wanted = applying and (r.data[ROLE_FIELD[chip.zenialRole]] or 0) > 0
        chip:SetShown(applying)
        if applying then
            chip:ClearAllPoints()
            chip:SetPoint('TOPLEFT', chipX, -41)
            chip:SetEnabled(wanted)
            chip:SetChecked(wanted and F.applyRole == chip.zenialRole)
            chipX = chipX + 82
        end
    end
    local actions = d.actions
    if applying then
        actions = {
            { text = tr('Send request'), enabled = F.applyRole ~= nil, click = function()
                U.SendFinderApply()
            end },
            { text = tr('Cancel'), click = function()
                F.applyKey, F.applyRole = nil, nil
                U.RefreshFinder()
            end },
        }
    end
    local right = 8
    local shown = 0
    for index = #card.actions, 1, -1 do
        local button, action, arrow = card.actions[index], actions[index], card.arrows[index]
        button:SetShown(action ~= nil)
        local menu = action and action.menu
        arrow:SetShown(menu ~= nil)
        if action then
            shown = shown + 1
            if button.zenialVariant ~= (action.variant or 'secondary') then
                T.StyleButton(button, action.variant or 'secondary')
            end
            button:SetText(action.text)
            button:SetEnabled(action.enabled ~= false)
            button:SetScript('OnClick', action.click)
            button:ClearAllPoints()
            local width = action.width or 116
            if menu then
                -- Main part and arrow side by side in the width of the action. The arrow takes the height of
                -- the main part (the client draws buttons taller than their nominal size), so both line up.
                button:SetWidth(width - 24)
                button:SetPoint('BOTTOMRIGHT', -(right + 24), 8)
                arrow:ClearAllPoints()
                arrow:SetPoint('TOPLEFT', button, 'TOPRIGHT', 2, 0)
                arrow:SetPoint('BOTTOMLEFT', button, 'BOTTOMRIGHT', 2, 0)
                arrow:SetWidth(22)
                -- The open list of texts belongs to the entry of this card, not to the card frame: a redraw
                -- that keeps the entry keeps the list open (UXFinderPublic.lua FP.End).
                arrow.zenialMenuKey = (item.public and item.public.key) or (r and r.key) or nil
                arrow:SetScript('OnClick', function(self)
                    U.WhisperDesigner.Menu(self, menu.kind, action.enabled ~= false, menu.pick)
                end)
            else
                button:SetWidth(width)
                button:SetPoint('BOTTOMRIGHT', -right, 8)
            end
            right = right + width + 6
        end
    end
    local note = d.note or ''
    card.note:ClearAllPoints()
    card.note:SetPoint('TOPLEFT', left, -61)
    card.note:SetText(note == '' and '' or d.noteRaw and note or '„' .. note .. '“')
    scriptFont(card.note, note)
    oneLine(card.note, textWidth, 13)
end

-- ---------------------------------------------------------------------------------------------
-- Stream: sections, cards and hints in one scroll area
-- ---------------------------------------------------------------------------------------------
local function createStream(parent)
    local stream = createScroll(parent)
    stream.cards, stream.headers, stream.hints = {}, {}, {}
    return stream
end
-- items: { type = 'section', text, count } | { type = 'card', row } | { type = 'hint', text }
-- Role filter of the "Players looking for a group" sections (_dev/addons/ZenialCommunity/SEEKER-ROLE-FILTER-DESIGN.md):
-- one choice per character for every view, all roles on by default, the last role stays on, a row whose roles are
-- unknown stays visible.
function F.SeekerRoles()
    local saved = Z.db and Z.db.finderSeekerRoles
    local out, any = {}, false
    for _, role in ipairs(ROLES) do
        out[role] = type(saved) ~= 'table' or saved[role] ~= false
        any = any or out[role]
    end
    if not any then
        for _, role in ipairs(ROLES) do
            out[role] = true
        end
    end
    return out
end
-- Switches a role; false when the role is unknown or the last one switched on.
function F.ToggleSeekerRole(role)
    local roles = F.SeekerRoles()
    if roles[role] == nil or not Z.db then
        return false
    end
    if roles[role] then
        local on = 0
        for _, other in ipairs(ROLES) do
            if roles[other] then
                on = on + 1
            end
        end
        if on <= 1 then
            return false
        end
    end
    roles[role] = not roles[role]
    Z.db.finderSeekerRoles = roles
    return true
end
-- Roles a seeker offers as a set; nil when they are unknown.
local function offeredRoles(row)
    local offered = {}
    if row.source == 'PUBLIC' then
        if type(row.soloRoles) ~= 'table' then
            return nil
        end
        offered = row.soloRoles
    else
        for _, role in ipairs(C.SearchRoles(type(row.data) == 'table' and row.data or {})) do
            offered[role] = true
        end
    end
    for _, role in ipairs(ROLES) do
        if offered[role] then
            return offered
        end
    end
    return nil
end
-- New list of the seekers that offer at least one switched-on role (or whose roles are unknown), order kept.
-- withFilters: the views with the filter bar also apply its level and class filters (FinderPublic.SeekerKeeps).
function F.FilterSeekers(rows, withFilters)
    local roles, out = F.SeekerRoles(), {}
    local FP = withFilters and U.FinderPublic or nil
    for _, row in ipairs(rows) do
        local offered, fits = offeredRoles(row), false
        if offered then
            for _, role in ipairs(ROLES) do
                fits = fits or (offered[role] == true and roles[role])
            end
        end
        if (not offered or fits) and (not FP or FP.SeekerKeeps(row)) then
            out[#out + 1] = row
        end
    end
    return out
end
-- The three role icons left of the count of a section header; hidden on every other header of the pool.
local function setSeekerIcons(header, shown)
    if not shown then
        if header.roleButtons then
            for _, b in ipairs(header.roleButtons) do
                b:Hide()
            end
            header.line:SetPoint('RIGHT', header.count, 'LEFT', -10, 0)
        end
        return
    end
    if not header.roleButtons then
        header.roleButtons = {}
        for index, role in ipairs(ROLES) do
            local b = CreateFrame('Button', nil, header)
            b:SetSize(14, 14)
            b.icon = b:CreateTexture(nil, 'ARTWORK')
            b.icon:SetAllPoints()
            b.zenialRole = role
            b:SetScript('OnClick', function(self)
                if F.ToggleSeekerRole(self.zenialRole) then
                    U.RefreshFinder()
                end
            end)
            b:SetScript('OnEnter', function(self)
                if GameTooltip and GameTooltip.SetOwner then
                    GameTooltip:SetOwner(self, 'ANCHOR_TOP')
                    GameTooltip:AddLine(Z.Locale.Role(self.zenialRole), 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            b:SetScript('OnLeave', function()
                if GameTooltip and GameTooltip.Hide then
                    GameTooltip:Hide()
                end
            end)
            header.roleButtons[index] = b
        end
    end
    local roles, previous = F.SeekerRoles(), header.count
    for index = #ROLES, 1, -1 do
        local b = header.roleButtons[index]
        b:ClearAllPoints()
        b:SetPoint('RIGHT', previous, 'LEFT', previous == header.count and -10 or -4, 0)
        setRoleIcon(b.icon, b.zenialRole, not roles[b.zenialRole] and 'muted' or nil)
        b:Show()
        previous = b
    end
    header.line:SetPoint('RIGHT', previous, 'LEFT', -10, 0)
end
local function renderStream(stream, width, height, items, columns, context)
    local inner = math.max(1, width - GUTTER)
    local cardWidth = math.floor((inner - (columns - 1) * GAP) / columns)
    local y, column = 0, 0
    local used = { cards = 0, headers = 0, hints = 0 }
    local function newLine()
        if column > 0 then
            y, column = y + CARD_HEIGHT + GAP, 0
        end
    end
    for _, item in ipairs(items) do
        if item.type == 'section' then
            newLine()
            used.headers = used.headers + 1
            local header = stream.headers[used.headers]
            if not header then
                header = K.SectionHeader(stream.child, '')
                stream.headers[used.headers] = header
            end
            header:ClearAllPoints()
            header:SetPoint('TOPLEFT', 0, -(y + (y > 0 and 6 or 0)))
            header:SetWidth(inner)
            -- A reused header keeps the width of its last caption, and the client measures a text only up to
            -- the width it has: without this a longer caption would be cut down to an ellipsis.
            header.label:SetWidth(0)
            header.count:SetWidth(0)
            header:SetText(item.text)
            header:SetCount(item.count)
            setSeekerIcons(header, item.seekerRoles == true)
            header:Show()
            y = y + (y > 0 and 6 or 0) + 26
        elseif item.type == 'card' then
            used.cards = used.cards + 1
            local card = stream.cards[used.cards]
            if not card then
                card = createCard(stream.child)
                stream.cards[used.cards] = card
            end
            card:ClearAllPoints()
            card:SetPoint('TOPLEFT', column * (cardWidth + GAP), -y)
            updateCard(card, item, cardWidth, context)
            card:Show()
            column = column + 1
            if column >= columns then
                y, column = y + CARD_HEIGHT + GAP, 0
            end
        else
            newLine()
            used.hints = used.hints + 1
            local hint = stream.hints[used.hints]
            if not hint then
                hint = K.Text(stream.child, '', 'caption', 'dim')
                stream.hints[used.hints] = hint
            end
            hint:ClearAllPoints()
            hint:SetPoint('TOPLEFT', 2, -y)
            hint:SetWidth(inner - 4)
            hint:SetHeight(30)
            call(hint, 'SetWordWrap', true)
            hint:SetText(item.text)
            hint:Show()
            y = y + 36
        end
    end
    newLine()
    for sort, pool in pairs({ cards = stream.cards, headers = stream.headers, hints = stream.hints }) do
        for index = used[sort] + 1, #pool do
            pool[index]:Hide()
        end
    end
    stream:Fit(width, height, y)
end
-- opts.seekerRoles: the section of players looking for a group, filtered by the role icons in its header.
-- opts.seekerFilters: the level and class filters of the bar apply too. opts.cut: how many rows the group
-- filters of the bar took out of this section.
local function addSection(items, text, rows, emptyText, limit, opts)
    local seekerRoles = opts ~= nil and opts.seekerRoles == true or nil
    if seekerRoles then
        local all = #rows
        local filters = opts.seekerFilters == true
        rows = F.FilterSeekers(rows, filters)
        if all > 0 and #rows == 0 then
            local FP = U.FinderPublic
            emptyText = tr(filters and FP and FP.SeekerFilterOn() and 'Nothing matches your filters.' or 'Nobody with this role is looking right now.')
        end
    elseif opts ~= nil and (opts.cut or 0) > 0 and #rows == 0 then
        emptyText = tr('Nothing matches your filters.')
    end
    items[#items + 1] = { type = 'section', text = text, count = #rows, seekerRoles = seekerRoles }
    if #rows == 0 then
        if emptyText then
            items[#items + 1] = { type = 'hint', text = emptyText }
        end
        return
    end
    for index, row in ipairs(rows) do
        if index > (limit or 60) then
            break
        end
        items[#items + 1] = row.source == 'PUBLIC' and { type = 'card', public = row } or { type = 'card', row = row }
    end
end
-- Copy of rows with the player's own entry first.
local function ownFirst(rows)
    local out = {}
    for _, r in ipairs(rows) do
        if r.own then
            out[#out + 1] = r
        end
    end
    for _, r in ipairs(rows) do
        if not r.own then
            out[#out + 1] = r
        end
    end
    return out
end
local function ofCategory(rows, category)
    local out = {}
    -- Source "Public": only the player's own rows of ZENIAL stay.
    local publicOnly = U.FinderPublic and U.FinderPublic.Source() == 'PUBLIC'
    for _, r in ipairs(rows) do
        if r.category == category and (r.own or not publicOnly) then
            out[#out + 1] = r
        end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------------------------
function U.StartFinderApply(key)
    local r = Z.ActivityBoard.Get(key)
    if not r or not r.data then
        return
    end
    local preferred = L.Role(Z.db.roles)
    local role
    for _, candidate in ipairs(ROLES) do
        if (r.data[ROLE_FIELD[candidate]] or 0) > 0 and (candidate == preferred or not role) then
            role = candidate
            if candidate == preferred then
                break
            end
        end
    end
    F.applyKey, F.applyRole = key, role
    U.RefreshFinder()
end
function U.SendFinderApply()
    local r = F.applyKey and Z.ActivityBoard.Get(F.applyKey)
    if not r or r.own or r.kind ~= 'LIVE' or not F.applyRole then
        F.applyKey, F.applyRole = nil, nil
        U.Message(tr('This activity is no longer available.'))
        U.RefreshFinder()
        return false
    end
    local ok, why = Z.ApplyGroup(r.owner, r.id, F.applyRole, '')
    U.Message(ok and tr('Application submitted; awaiting response.') or tr(why))
    F.applyKey, F.applyRole = nil, nil
    U.Refresh()
    return ok and true or false
end
function U.InviteFinderSeeker(key)
    local r = Z.ActivityBoard.Get(key)
    local contact = r and not r.own and Z.db.contacts[r.owner]
    if not contact then
        U.Message(tr('This activity is no longer available.'))
        return false
    end
    local ok, why = A.Invite(contact.target)
    U.Message(ok and tr('Invitation submitted; awaiting response.') or tr(why))
    return ok and true or false
end
-- The own group or search changed through a click: a public listing of it follows (UXFinderPublic.lua).
-- Called before the interface is redrawn, while the button that was clicked is still on screen.
local function syncListing()
    if U.FinderPublic then
        U.FinderPublic.SyncListing()
    end
end
U.SyncPublicListing = syncListing
function U.StartFinderSearch(activity, roles, note)
    local id, why = C.StartSearch(activity, roles, note)
    if not id then
        U.Message(tr(why))
        return false
    end
    F.searchOpen = false
    syncListing()
    U.Message(Z.T('You are now looking for a group for %s.', activityName(activity)))
    U.Publish()
    return true
end
function U.AddFinderSearch(activity)
    local id, why = C.AddSearch(activity)
    if not id then
        U.Message(tr(why))
        return false
    end
    syncListing()
    U.Message(Z.T('%s added to your search (%d/%d).', activityName(activity), #C.SearchActivities(Z.db.lfg[1]), C.MAX_SEARCH))
    U.Publish()
    return true
end
function U.RemoveFinderSearch(activity)
    if not C.RemoveSearch(activity) then
        return false
    end
    local g = Z.db.lfg[1]
    syncListing()
    U.Message(g and C.IsSearch(g) and Z.T('%s removed from your search.', activityName(activity)) or tr('Search ended.'))
    U.Publish()
    return true
end
function U.StopFinderSearch()
    if C.StopSearch() then
        syncListing()
        U.Message(tr('Search ended.'))
        U.Publish()
        return true
    end
    return false
end
function U.ToggleFinderFollow(activity)
    local followed = Z.db.groupFollows[L.ActivityID(activity)] == true
    if Z.SetGroupFollow(activity, not followed) then
        U.Message(followed and Z.T('You no longer follow %s.', activityName(activity)) or Z.T('You will be notified about new groups for %s.', activityName(activity)))
    end
    U.RefreshFinder()
end
-- Opens the existing creator on its second step with the activity, its level range, its size and the
-- usual roles filled in. A running search is taken over by the editor and becomes the group on saving.
function U.OpenFinderCreate(activity, planned)
    local e = activity and C.Get(activity)
    local own = Z.db.lfg[1]
    if own and not planned and not C.IsSearch(own) then
        local snap = C.Snapshot()
        if snap.own.group then
            U.EditActivity(snap.own.group.key)
        end
        return
    end
    U.OpenActivityCreator()
    if not U.creatorKind then
        return
    end
    if not e and not planned then
        -- No instance chosen: straight to the form for the content of the open tab. The first step of the
        -- creator (when, kind, template) stays one "Back" away.
        if F.view == 'quests' then
            U.creatorWhen:SetText('NOW')
            U.creatorKind:SetText('QUEST')
            U.ConfigureActivityCreator()
            U.creatorGoal:SetText('Questing')
            U.ContinueActivityCreator()
            return
        elseif F.view == 'other' then
            U.creatorWhen:SetText('NOW')
            U.creatorKind:SetText('CUSTOM')
            U.ConfigureActivityCreator()
            U.creatorFlow = true
            U.OpenGroupEditor(own)
            U.groupKind:SetText('CUSTOM')
            U.GroupKind('CUSTOM', '')
            return
        end
        -- The instance of this kind that fits the player's level best.
        local list = C.List(({ raids = 'RAID', pvp = 'PVP' })[F.view] or 'DUNGEON')
        local level = Z.me and Z.me.level
        for _, entry in ipairs(list) do
            if C.Fits(entry, level) then
                e = entry
            end
        end
        if not e and type(level) == 'number' then
            for _, entry in ipairs(list) do
                if not e and entry.min > level then
                    e = entry
                end
            end
        end
        e = e or list[#list]
    end
    if not e then
        return
    end
    U.creatorWhen:SetText(planned and 'PLANNED' or 'NOW')
    U.creatorKind:SetText(e.kind)
    U.ConfigureActivityCreator()
    U.creatorGoal:SetText(e.id)
    if U.creatorTemplate then
        U.creatorTemplate:SetText('Choose template')
    end
    U.ContinueActivityCreator()
    if planned or not U.groupFields then
        return
    end
    local fields = U.groupFields
    U.groupLoading = true
    fields.min:SetText(tostring(e.min))
    fields.max:SetText(tostring(e.max))
    fields.size:SetText(tostring(e.size))
    if fields.note and own then
        fields.note:SetText(own.note or '')
    end
    U.groupLoading = false
    -- Wanted roles follow the group size (U.AutofillGroupNeeds, also when the size field changes later).
    if U.AutofillGroupNeeds then
        U.AutofillGroupNeeds()
    end
    U.CaptureGroupDraft()
    -- The optional part of the form opens only when something in it is set (GroupFormUI.lua).
    if U.GroupForm and U.GroupForm.Reset then
        U.GroupForm.Reset()
    end
end
function U.OpenFinderJournal(activity)
    local ok, why = J.Open(activity)
    if not ok then
        U.Message(tr(why == 'unknown' and 'The Dungeon Journal has no page for this instance yet.' or 'The Dungeon Journal could not be opened.'))
    end
    return ok
end

-- ---------------------------------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------------------------------
local function size()
    local page = U.pages[10]
    local width, height = page:GetWidth(), page:GetHeight()
    return math.max(640, type(width) == 'number' and width > 0 and width or 856), math.max(360, type(height) == 'number' and height > 0 and height or 500)
end

local function renderGrid(snap, top, width, height)
    local kind = VIEW_KIND[F.view]
    -- PvP shows no filter row or search field, so hidden filters must not apply there.
    local filtersOn = F.view ~= 'pvp'
    local query = filtersOn and string.lower(F.query or '') or ''
    local level = myLevel()
    local shownEntries, groups, seekers, seen = {}, 0, 0, {}
    local all = C.List(kind)
    for _, e in ipairs(all) do
        local stats = snap.by[e.id]
        if stats then
            -- One player looking for up to three activities counts once.
            groups = groups + stats.groups
            for _, r in ipairs(stats.rows.seekers) do
                if not seen[r] then
                    seen[r] = true
                    seekers = seekers + 1
                end
            end
        end
        local matches = query == '' or string.lower(activityName(e.id)):find(query, 1, true) or string.lower(e.id):find(query, 1, true)
        if matches and filtersOn and F.filters.level and not C.Fits(e, level) then
            matches = false
        end
        if matches and filtersOn and F.filters.groups and not (stats and stats.groups > 0) then
            matches = false
        end
        if matches and filtersOn and F.filters.seekers and not (stats and stats.seekers > 0) then
            matches = false
        end
        if matches then
            shownEntries[#shownEntries + 1] = e
        end
    end
    local grid = F.grid
    grid:ClearAllPoints()
    grid:SetPoint('TOPLEFT', 0, -top)
    local inner = width - GUTTER
    local columns = math.max(2, math.floor((inner + GAP) / (196 + GAP)))
    local tileWidth = math.floor((inner - (columns - 1) * GAP) / columns)
    local tileHeight = math.floor(tileWidth / TILE_SHAPE)
    local empty = { groups = 0, full = 0, seekers = 0, planned = 0 }
    for index, e in ipairs(shownEntries) do
        local tile = F.tiles[index]
        if not tile then
            tile = createTile(grid.child)
            F.tiles[index] = tile
        end
        local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
        tile:ClearAllPoints()
        tile:SetPoint('TOPLEFT', column * (tileWidth + GAP), -row * (tileHeight + GAP))
        updateTile(tile, e, snap.by[e.id] or empty, tileWidth, tileHeight)
        tile:Show()
    end
    for index = #shownEntries + 1, #F.tiles do
        F.tiles[index]:Hide()
    end
    local rows = math.ceil(#shownEntries / columns)
    grid:Fit(width, height, rows * (tileHeight + GAP))
    F.gridEmpty:SetShown(#shownEntries == 0)
    if #shownEntries == 0 then
        F.gridEmpty:ClearAllPoints()
        F.gridEmpty:SetPoint('TOP', F.frame, 'TOP', 0, -(top + 40))
        F.gridEmpty:SetState(tr('No instance matches'), tr('Change the filters or the search text.'), 'search')
    end
    local noun = kind == 'DUNGEON' and '%d dungeons' or kind == 'RAID' and '%d raids' or '%d battlegrounds'
    F.summary:SetText(Z.T(noun, #all) .. ' · ' .. paint('success', countText('groups', groups)) .. ' · ' .. paint('accentBlue', countText('seekers', seekers)))
end

local function renderNow(snap, top, width, height)
    local items = {}
    local total = #snap.groups + #snap.seekers + #snap.planned + #snap.other
    if total == 0 then
        items[1] = { type = 'section', text = tr('Right now'), count = 0 }
        items[2] = { type = 'hint', text = tr('Nothing is open in the ZENIAL community right now. Create a group, or pick an instance under Dungeons and look for one.') }
    else
        if #snap.groups > 0 then
            -- Own group first, then groups with a free place (newest first), full groups last.
            local groups = {}
            for index, r in ipairs(snap.groups) do
                groups[index] = r
            end
            local function rank(r)
                return r.own and 0 or C.Wanted(r.data) > 0 and 1 or 2
            end
            table.sort(groups, function(a, b)
                local ra, rb = rank(a), rank(b)
                if ra ~= rb then
                    return ra < rb
                end
                if a.startsAt ~= b.startsAt then
                    return a.startsAt > b.startsAt
                end
                return a.key < b.key
            end)
            addSection(items, tr('Open groups'), groups)
        end
        if #snap.seekers > 0 then
            addSection(items, tr('Players looking for a group'), snap.seekers, nil, nil, { seekerRoles = true })
        end
        if #snap.planned > 0 then
            addSection(items, tr('Planned'), snap.planned)
        end
        if #snap.other > 0 then
            addSection(items, tr('Quest and PvP help'), snap.other)
        end
    end
    F.stream:ClearAllPoints()
    F.stream:SetPoint('TOPLEFT', 0, -top)
    renderStream(F.stream, width, height, items, width >= 760 and 2 or 1, { named = true, thumbs = true })
    F.summary:SetText(paint('success', countText('groups', snap.open)) .. ' · ' .. paint('accentBlue', countText('seekers', #snap.seekers)) .. ' · ' .. countText('planned', #snap.planned))
end

local function renderCategory(snap, top, width, height)
    local category = VIEW_CATEGORY[F.view]
    local items = {}
    local quest = F.view == 'quests'
    if quest then
        -- Members who share quests with the player, most quests first (QuestGroups keeps the ranking).
        local Q, G = Z.QuestHelper, Z.QuestGroups
        local partners = Q and G and G.CurrentCandidates and G.CurrentCandidates() or {}
        items[#items + 1] = { type = 'section', text = tr('Players with quests in common'), count = #partners }
        if not Q or not Q.Sharing() then
            items[#items + 1] = { type = 'hint', text = tr('Quest sharing is disabled.') .. ' ' .. tr('Switch it on under Settings, Privacy, to see who has the same quests.') }
        elseif #partners == 0 then
            items[#items + 1] = { type = 'hint', text = tr('Nobody online shares one of your quests right now.') }
        end
        for index, partner in ipairs(partners) do
            if index > 12 then
                break
            end
            items[#items + 1] = { type = 'card', partner = partner }
        end
        local help = {}
        for _, r in ipairs(ofCategory(snap.other, category)) do
            if r.kind == 'QUEST' then
                help[#help + 1] = r
            end
        end
        addSection(items, tr('Quest assistance'), help, tr('Nobody asks for quest help right now.'))
    end
    local open, cut = ofCategory(snap.groups, category), 0
    if U.FinderPublic then
        open, cut = U.FinderPublic.FilterGroups(open)
    end
    addSection(items, tr('Open groups'), open, tr(quest and 'No questing or levelling group is open.' or 'No other group is open.'), nil, { cut = cut })
    -- Sections without entries are left out here; the open groups above keep their hint.
    local looking, planned = ofCategory(snap.seekers, category), ofCategory(snap.planned, category)
    if #looking > 0 then
        addSection(items, tr('Players looking for a group'), looking, nil, nil, { seekerRoles = true, seekerFilters = true })
    end
    if #planned > 0 then
        addSection(items, tr('Planned'), planned)
    end
    -- Groups and single players of the public group search of the game in this category.
    local public, loaded, publicCut = nil, false, 0
    if U.FinderPublic then
        public, loaded, publicCut = U.FinderPublic.CategoryRows()
    end
    if public then
        addSection(items, tr('Public groups'), public, tr(loaded and 'No public group is listed right now.' or 'Load the public groups to see what is listed in the game.'), nil, { cut = publicCut })
    end
    F.stream:ClearAllPoints()
    F.stream:SetPoint('TOPLEFT', 0, -top)
    renderStream(F.stream, width, height, items, width >= 760 and 2 or 1, { named = true, thumbs = true })
    local t = snap.totals[category] or { groups = 0, seekers = 0, planned = 0 }
    F.summary:SetText(paint('success', countText('groups', t.groups)) .. ' · ' .. paint('accentBlue', countText('seekers', t.seekers)) .. ' · ' .. countText('planned', t.planned))
end

local function renderDetail(snap, top, width, height)
    local detail, e = F.detail, C.Get(F.activity)
    local stats = snap.by[e.id] or { groups = 0, full = 0, seekers = 0, planned = 0, rows = { groups = {}, seekers = {}, planned = {} } }
    detail:ClearAllPoints()
    detail:SetPoint('TOPLEFT', 0, -top)
    detail:SetSize(width, height)
    local hero = detail.hero
    local heroHeight = 132
    hero:ClearAllPoints()
    hero:SetPoint('TOPLEFT', 0, 0)
    hero:SetSize(width, heroHeight)
    local artWidth = math.floor((heroHeight - 2) * TILE_SHAPE)
    hero.picture:Place('TOPLEFT', 1, -1, artWidth, heroHeight - 2)
    hero.picture:Show(e)
    hero.fade:ClearAllPoints()
    hero.fade:SetPoint('TOPRIGHT', hero.picture.base, 'TOPRIGHT', 0, 0)
    hero.fade:SetSize(72, heroHeight - 2)
    local x = artWidth + 18
    local textWidth = width - x - 12
    hero.title:ClearAllPoints()
    hero.title:SetPoint('TOPLEFT', x, -11)
    hero.title:SetText(activityName(e.id))
    oneLine(hero.title, textWidth - 204, 24)
    local zone = C.Zone(e)
    hero.facts:ClearAllPoints()
    hero.facts:SetPoint('TOPLEFT', x, -40)
    hero.facts:SetText(paint(C.Fits(e, myLevel()) and 'goldText' or 'textSoft', levelText(e)) .. paint('dim', ' · ') .. paint('textSoft', Z.T('%d players', e.size)) .. (zone and paint('dim', ' · ') .. paint('textSoft', zone) or ''))
    oneLine(hero.facts, textWidth, 15)
    hero.counts:ClearAllPoints()
    hero.counts:SetPoint('TOPLEFT', x, -64)
    -- With a list of the public group search the figures count both sources and say so.
    local groupCount, seekerCount, where = stats.groups, stats.seekers, tr('in the ZENIAL community')
    local groups, seekers = ownFirst(stats.rows.groups), ownFirst(stats.rows.seekers)
    local both = U.FinderPublic and U.FinderPublic.Totals(e.id, stats, groups, seekers)
    if both then
        groupCount, seekerCount, where = both.groups, both.seekers, both.where
    end
    hero.counts:SetText(
        paint(groupCount > 0 and 'success' or 'dim', countText('groups', groupCount) .. ' ' .. tr('open'))
            .. paint('dim', '   ·   ')
            .. paint(seekerCount > 0 and 'accentBlue' or 'dim', countText('seekers', seekerCount))
            .. paint('dim', '   ·   ')
            .. paint(stats.planned > 0 and 'text' or 'dim', countText('planned', stats.planned))
            .. paint('muted', '   ' .. where)
    )
    oneLine(hero.counts, textWidth, 15)
    hero.back:ClearAllPoints()
    hero.back:SetPoint('TOPRIGHT', -12, -10)
    -- The bell beside "Back to overview": follow this instance and hear about new ZENIAL groups for it.
    local followed = Z.db.groupFollows[e.id] == true
    hero.follow:ClearAllPoints()
    hero.follow:SetPoint('TOPRIGHT', -12 - 160 - 6, -9)
    hero.follow:SetChecked(followed)
    -- Actions: one primary (create), the search switch and the journal.
    local own = Z.db.lfg[1]
    local searching = stats.ownSearch == true
    hero.create:ClearAllPoints()
    hero.create:SetPoint('BOTTOMLEFT', x, 10)
    hero.create:SetText(tr(own and not C.IsSearch(own) and 'Manage my group' or 'Create group'))
    hero.search:ClearAllPoints()
    hero.search:SetPoint('BOTTOMLEFT', x + 168, 10)
    -- One search, up to three instances: start it here, add this instance to it, or take it out again.
    local searched = own and C.IsSearch(own) and #C.SearchActivities(own) or 0
    if searching then
        hero.search:SetText(tr('Stop looking here'))
    elseif searched > 0 then
        hero.search:SetText(Z.T('Look here too (%d/%d)', searched, C.MAX_SEARCH))
    else
        hero.search:SetText(tr('I am looking for a group'))
    end
    hero.search:SetEnabled(searching or not own or (searched > 0 and searched < C.MAX_SEARCH))
    local journal = e.journal ~= nil and J.Available()
    hero.journal:SetShown(journal)
    if journal then
        hero.journal:ClearAllPoints()
        hero.journal:SetPoint('BOTTOMLEFT', x + 168 + 186, 10)
        hero.journal:SetEnabled(J.Knows(e.id))
    end
    -- Search form (roles and note) between the head and the lists.
    local y = heroHeight + 10
    local bar = detail.searchBar
    bar:SetShown(F.searchOpen == true and not searching)
    if bar:IsShown() then
        bar:ClearAllPoints()
        bar:SetPoint('TOPLEFT', 0, -y)
        bar:SetSize(width, 42)
        y = y + 52
    end
    -- Public group search: its field between the head and the lists, its rows behind the ZENIAL rows.
    local FP = U.FinderPublic
    local groupsCut = 0
    if FP then
        y = y + FP.LayoutBar(top + y, width, true)
        groups, groupsCut = FP.Merge(groups, e.id, 'groups')
        seekers = FP.Merge(seekers, e.id, 'seekers')
    end
    local columnWidth = math.floor((width - GAP) / 2)
    local listHeight = math.max(60, height - y)
    local left, right = {}, {}
    addSection(left, tr('Open groups'), groups, tr('No group is open for this instance. Create one, or look for a group and let others find you.'), nil, { cut = groupsCut })
    if #stats.rows.planned > 0 then
        addSection(left, tr('Planned'), stats.rows.planned)
    end
    addSection(right, tr('Players looking for a group'), seekers, tr('Nobody is looking for this instance right now.'), nil, { seekerRoles = true, seekerFilters = true })
    detail.left:ClearAllPoints()
    detail.left:SetPoint('TOPLEFT', 0, -y)
    renderStream(detail.left, columnWidth, listHeight, left, 1, { named = false, thumbs = false })
    detail.right:ClearAllPoints()
    detail.right:SetPoint('TOPLEFT', columnWidth + GAP, -y)
    renderStream(detail.right, columnWidth, listHeight, right, 1, { named = false, thumbs = false })
end

-- Own requests that still wait for an answer (status line and the "Requests" tab).
local function countRequests(snap)
    local requests = 0
    for _, rows in ipairs({ snap.groups, snap.planned }) do
        for _, r in ipairs(rows) do
            local state = not r.own and type(r.application) == 'table' and r.application.state
            if state == 'applied' or state == 'invited' or state == 'REQUESTED' then
                requests = requests + 1
            end
        end
    end
    return requests
end

-- The row of tabs of the finder; page 3 (events, own requests) carries the same row.
-- selected: view name, 'events' or 'requests'; nil marks no tab.
local function layoutTabRow(row, width, selected, snap)
    local x = 0
    for _, view in ipairs(VIEWS) do
        local tab = row.tabs[view]
        local category = VIEW_CATEGORY[view]
        local n = category and (snap.totals[category] and snap.totals[category].groups or 0) or snap.open
        tab:SetText(tr(VIEW_LABEL[view]) .. (n > 0 and '  ' .. paint('success', tostring(n)) or ''))
        tab:ClearAllPoints()
        tab:SetPoint('TOPLEFT', x, 0)
        T.SetSelected(tab, selected == view)
        x = x + VIEW_WIDTH[view] + TAB_GAP
    end
    x = x - TAB_GAP + EXTRA_GAP
    local requests = countRequests(snap)
    for _, name in ipairs(EXTRA_TABS) do
        local tab = row.tabs[name]
        tab:SetText(tr(EXTRA_LABEL[name]) .. (name == 'requests' and requests > 0 and '  ' .. paint('success', tostring(requests)) or ''))
        tab:ClearAllPoints()
        tab:SetPoint('TOPLEFT', x, 0)
        T.SetSelected(tab, selected == name)
        x = x + EXTRA_WIDTH[name] + TAB_GAP
    end
    row.create:ClearAllPoints()
    row.create:SetPoint('TOPRIGHT', row.parent, 'TOPLEFT', width, -2)
    row.line:ClearAllPoints()
    row.line:SetPoint('TOPLEFT', 0, -31)
    row.line:SetSize(width, 1)
end
local function buildTabRow(parent, onCreate)
    local row = { parent = parent, tabs = {} }
    local function open(name)
        return function()
            if name == 'events' then
                if U.Navigate('groups', 'scheduled') and U.scheduledArchive then
                    U.scheduledArchive:SetChecked(false)
                    U.RefreshScheduledGroups()
                end
            elseif name == 'requests' then
                U.Navigate('groups', 'outgoing')
            else
                U.Navigate('activities', name)
            end
        end
    end
    for _, view in ipairs(VIEWS) do
        row.tabs[view] = T.Button(parent, tr(VIEW_LABEL[view]), VIEW_WIDTH[view], 30, open(view), 'tab')
    end
    for _, name in ipairs(EXTRA_TABS) do
        row.tabs[name] = T.Button(parent, tr(EXTRA_LABEL[name]), EXTRA_WIDTH[name], 30, open(name), 'tab')
    end
    for _, tab in pairs(row.tabs) do
        T.SetSelected(tab, false)
    end
    row.line = parent:CreateTexture(nil, 'ARTWORK')
    T.Tint(row.line, 'SetColorTexture', 'lineSoft')
    row.create = T.Button(parent, tr('Create group'), CREATE_WIDTH, 26, onCreate, 'primary')
    F.rows = F.rows or {}
    F.rows[#F.rows + 1] = row
    return row
end
-- Page 3 (events, own requests, and the views reached from the notices): same row, nothing marked except the
-- two places that live there.
function U.RefreshFinderTabs()
    local row = F.row3
    if not row or U.page ~= 3 then
        return
    end
    local width = size()
    layoutTabRow(row, width, U.groupView == 'scheduled' and 'events' or U.groupView == 'outgoing' and 'requests' or nil, C.Snapshot())
end

-- Own group, own search or own requests: always one line above the content.
local function renderStatus(snap, width)
    local status = F.status
    local group, search = snap.own.group, snap.own.search
    local requests = countRequests(snap)
    local actions = {}
    if group then
        local g = group.data
        local pending = pendingRequests(group)
        status.over:SetText(K.Upper(tr('My Group')))
        status.line:SetText(
            paint('text', activityName(group.title))
                .. paint('dim', ' · ')
                .. paint('textSoft', Z.T('%d/%d players', partySize(group), g.size))
                .. paint('dim', ' · ')
                .. wantedRoles(g)
        )
        actions[1] = { text = Z.T('Requests (%d)', pending), width = 124, click = function()
            U.OpenActivity(group.key)
        end }
        actions[2] = { text = tr('Edit'), width = 100, click = function()
            U.EditActivity(group.key)
        end }
        actions[3] = { text = tr('Close group'), width = 132, variant = 'danger', click = function()
            U.ArchiveActivity(group.key)
        end }
    elseif search then
        local parts = {}
        for _, role in ipairs(C.SearchRoles(search.data)) do
            parts[#parts + 1] = { role, Z.Locale.Role(role) }
        end
        status.over:SetText(K.Upper(tr('My search')))
        local names = {}
        for index, id in ipairs(C.SearchActivities(search.data)) do
            names[index] = activityName(id)
        end
        status.line:SetText(paint('dim', tr('Looking for a group') .. ': ') .. paint('text', table.concat(names, ' · ')) .. paint('dim', '   ' .. tr('Roles') .. ': ') .. K.Roles(parts))
        if C.Get(search.title) then
            actions[1] = { text = tr('Show instance'), width = 132, click = function()
                U.OpenFinderActivity(search.title)
            end }
        end
        actions[#actions + 1] = { text = tr('Stop search'), width = 132, variant = 'danger', click = function()
            U.StopFinderSearch()
        end }
    elseif requests > 0 then
        status.over:SetText(K.Upper(tr('My requests')))
        status.line:SetText(paint('text', plural('1 request is waiting for an answer.', '%d requests are waiting for an answer.', requests)))
        actions[1] = { text = tr('Show requests'), width = 150, click = function()
            U.Navigate('groups', 'outgoing')
        end }
    else
        status:Hide()
        return 0
    end
    status:ClearAllPoints()
    status:SetPoint('TOPLEFT', 0, -40)
    status:SetSize(width, 46)
    local right = 10
    for index = #status.actions, 1, -1 do
        local button, action = status.actions[index], actions[index]
        button:SetShown(action ~= nil)
        if action then
            if button.zenialVariant ~= (action.variant or 'secondary') then
                T.StyleButton(button, action.variant or 'secondary')
            end
            button:SetText(action.text)
            button:SetWidth(action.width)
            button:SetScript('OnClick', action.click)
            button:ClearAllPoints()
            button:SetPoint('RIGHT', status, 'RIGHT', -right, 0)
            right = right + action.width + 6
        end
    end
    -- Public group search: the switch that also lists the own group or search in the game.
    if U.FinderPublic then
        right = U.FinderPublic.LayoutListing(status, right, group or search)
    end
    oneLine(status.line, math.max(80, width - right - 24), 15)
    status:Show()
    return 54
end

function U.RefreshFinder()
    local frame = F.frame
    if not frame or not frame:IsShown() then
        return
    end
    local width, height = size()
    local snap = C.Snapshot()
    F.snapshot = snap
    if F.applyKey and not Z.ActivityBoard.Get(F.applyKey) then
        F.applyKey, F.applyRole = nil, nil
    end
    if F.activity and not C.Get(F.activity) then
        F.activity = nil
    end
    -- Tabs with the open groups of their category.
    layoutTabRow(F.row, width, F.view, snap)
    local top = 40 + renderStatus(snap, width)
    local detailed = F.activity ~= nil
    local gridView = VIEW_KIND[F.view] ~= nil and not detailed
    local filters = gridView and F.view ~= 'pvp'
    -- Tool row: filters for the tile grids, the figures of the view on the right.
    for _, chip in ipairs(F.chips) do
        chip:SetShown(filters)
    end
    F.search:SetShown(filters)
    F.summary:SetShown(not detailed)
    local chipX = 0
    for _, chip in ipairs(F.chips) do
        chip:ClearAllPoints()
        chip:SetPoint('TOPLEFT', chipX, -(top + 2))
        chip:SetChecked(F.filters[chip.zenialFilter] == true)
        chipX = chipX + chip.zenialWidth + 6
    end
    F.search:ClearAllPoints()
    F.search:SetPoint('TOPLEFT', chipX + 6, -(top + 1))
    -- The old list stays one click away at the right end of the tool row of "Live".
    local listView = not detailed and F.view == 'now'
    F.listView:SetShown(listView)
    F.listView:ClearAllPoints()
    F.listView:SetPoint('TOPRIGHT', frame, 'TOPLEFT', width - 2, -(top + 1))
    F.summary:ClearAllPoints()
    F.summary:SetPoint('TOPRIGHT', frame, 'TOPLEFT', width - 2 - (listView and LIST_VIEW_WIDTH + 8 or 0), -(top + 6))
    oneLine(F.summary, 330, 14)
    F.summary:SetJustifyH('RIGHT')
    for _, link in ipairs(F.links) do
        link:Hide()
    end
    local links = not detailed and F.linkSets[F.view]
    if links then
        local linkX = 0
        for index, spec in ipairs(links) do
            local link = F.links[index]
            link:SetText(tr(spec.text))
            link:SetWidth(spec.width)
            link:SetScript('OnClick', spec.click)
            link:ClearAllPoints()
            link:SetPoint('TOPLEFT', linkX, -top)
            link:Show()
            linkX = linkX + spec.width + 6
        end
    end
    local contentTop = detailed and top or top + ((filters or links or listView) and 34 or 24)
    -- Public group search: one row with its search field below the tool row (the overview of an instance
    -- places it itself).
    local FP = U.FinderPublic
    if FP then
        FP.Begin()
        FP.HideBar()
        if not detailed then
            contentTop = contentTop + FP.LayoutBar(contentTop, width)
        end
    end
    local contentHeight = math.max(80, height - contentTop)
    F.grid:SetShown(gridView)
    F.gridEmpty:Hide()
    F.stream:SetShown(not gridView and not detailed)
    F.detail:SetShown(detailed)
    if detailed then
        renderDetail(snap, contentTop, width, contentHeight)
    elseif gridView then
        renderGrid(snap, contentTop, width, contentHeight)
    elseif F.view == 'now' then
        renderNow(snap, contentTop, width, contentHeight)
    else
        renderCategory(snap, contentTop, width, contentHeight)
    end
    if U.FinderAssistant then
        U.FinderAssistant.Refresh()
    end
    if FP then
        FP.End()
    end
end
function U.LayoutFinder()
    if F.frame and F.frame:IsShown() then
        U.RefreshFinder()
    end
end

-- The former board shares page 10 with the finder. It is hidden while the finder shows, not merely covered:
-- the window turns translucent while the character moves, and anything left underneath would shine through.
local function coverPage(page, keep, covered)
    for _, getter in ipairs({ 'GetChildren', 'GetRegions' }) do
        local parts = type(page[getter]) == 'function' and { pcall(page[getter], page) } or { false }
        for index = 2, parts[1] and #parts or 0 do
            local part = parts[index]
            if part ~= keep and type(part) == 'table' and type(part.IsShown) == 'function' then
                if covered then
                    if part:IsShown() then
                        part.zenialFinderCovered = true
                        part:Hide()
                    end
                elseif part.zenialFinderCovered then
                    part.zenialFinderCovered = nil
                    part:Show()
                end
            end
        end
    end
end
local function coverBoard(covered)
    coverPage(U.pages[10], F.frame, covered)
end
-- view: now | dungeons | raids | pvp | quests | other | list. nil keeps the tab that was open.
function U.SetFinderView(view, keepActivity)
    if not F.frame then
        return
    end
    if view == 'list' then
        F.frame:Hide()
        coverBoard(false)
        U.RefreshActivityBoard()
        return
    end
    if view and VIEW_LABEL[view] then
        if F.view ~= view then
            F.searchOpen = false
        end
        F.view = view
    end
    if not keepActivity then
        F.activity, F.searchOpen = nil, false
    end
    F.applyKey, F.applyRole = nil, nil
    -- Another view or instance starts at the top, not at the scroll position of the one before.
    local place = tostring(F.view) .. '|' .. tostring(F.activity)
    if F.scrollPlace ~= place then
        F.scrollPlace = place
        for _, scroll in ipairs({ F.grid, F.stream, F.detail and F.detail.left, F.detail and F.detail.right }) do
            if scroll then
                scroll.zenialOffset = 0
                scroll:SetVerticalScroll(0)
            end
        end
    end
    F.frame:Show()
    coverBoard(true)
    U.RefreshFinder()
end
-- Opens the group overview of one catalogue activity (from a tile, a notice or another page).
-- clicked: the player clicked a tile; only then the public group search may start a search by itself.
function U.OpenFinderActivity(activity, clicked)
    local e = C.Get(activity)
    if not e then
        return false
    end
    -- The click that opens an instance also searches its public groups. The search goes out first, while the
    -- tile that was clicked is still on screen: the game takes the call only from the click itself, and in the
    -- client a search that followed the redraw was refused (owner's test, 2026-11-18).
    if clicked and U.FinderPublic then
        U.FinderPublic.OnOpen(e.id)
    end
    if U.page ~= 10 and not U.Navigate('activities', KIND_VIEW[e.kind]) then
        return false
    end
    F.activity, F.searchOpen = e.id, false
    U.SetFinderView(KIND_VIEW[e.kind], true)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------------------------
local function createEdit(parent, width, maxLetters, hintText)
    local edit = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
    edit:SetAutoFocus(false)
    edit:SetSize(width, 24)
    edit:SetMaxLetters(maxLetters)
    edit:SetFontObject('GameFontHighlightSmall')
    edit:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
    end)
    edit:SetScript('OnEnterPressed', function(self)
        self:ClearFocus()
    end)
    T.StyleEditBox(edit)
    edit.hint = K.Text(edit, hintText, 'caption', 'muted')
    edit.hint:SetPoint('LEFT', 8, 0)
    return edit
end

function U.CreateFinder()
    if F.frame then
        return F.frame
    end
    local page = U.pages[10]
    local frame = CreateFrame('Frame', nil, page)
    F.frame = frame
    frame:SetAllPoints(page)
    -- Above the board's own controls (lists, rows, sliders), far below the dialog blocker (window level + 40):
    -- the deepest finder widget sits six levels above this frame.
    frame:SetFrameLevel((page:GetFrameLevel() or 1) + 8)
    frame:EnableMouse(true)
    -- The board's refresh shows and hides its own buttons; while the finder is up they stay hidden.
    local refreshBoard = U.RefreshActivityBoard
    U.RefreshActivityBoard = function(...)
        -- While the finder is up the board stays hidden and is not rebuilt; leaving the finder refreshes it.
        if F.frame:IsShown() then
            return
        end
        return refreshBoard(...)
    end
    frame.fill = frame:CreateTexture(nil, 'BACKGROUND')
    frame.fill:SetPoint('TOPLEFT', -8, 6)
    frame.fill:SetPoint('BOTTOMRIGHT', 8, -6)
    T.Tint(frame.fill, 'SetColorTexture', 'bg')

    F.row = buildTabRow(frame, function()
        U.OpenFinderCreate(F.activity)
    end)
    -- The same row on page 3 (events, own requests): the change reads as a change of tab.
    F.row3 = buildTabRow(U.pages[3], function()
        U.OpenActivityCreator()
    end)

    local status = K.Card(frame, 'raised')
    K.Accent(status, 'gold')
    status.over = K.Text(status, '', 'overline', 'goldDim')
    status.over:SetPoint('TOPLEFT', 14, -7)
    oneLine(status.over, 300, 12)
    status.line = K.Text(status, '', 'heading', 'text')
    status.line:SetPoint('TOPLEFT', 14, -23)
    status.actions = {}
    for index = 1, 3 do
        status.actions[index] = T.Button(status, '', 120, 24, nil, 'secondary')
    end
    status:Hide()
    F.status = status

    F.chips = {}
    for _, spec in ipairs({ { 'level', 'My level', 104 }, { 'groups', 'Open groups', 130 }, { 'seekers', 'Players looking', 136 } }) do
        local chip = T.Chip(frame, tr(spec[2]), spec[3], 24, function(self)
            F.filters[spec[1]] = self:GetChecked() and true or false
            U.RefreshFinder()
        end)
        chip.zenialFilter, chip.zenialWidth = spec[1], spec[3]
        F.chips[#F.chips + 1] = chip
    end
    F.search = createEdit(frame, 190, 40, tr('Search instance'))
    F.search:SetScript('OnTextChanged', function(self)
        local text = self:GetText() or ''
        self.hint:SetShown(text == '')
        if text ~= F.query then
            F.query = text
            U.RefreshFinder()
        end
    end)
    F.summary = K.Text(frame, '', 'caption', 'dim')
    F.listView = T.Button(frame, tr('List view'), LIST_VIEW_WIDTH, 24, function()
        U.Navigate('activities', 'list')
    end, 'secondary')
    F.listView:Hide()

    -- Links of the views without a tile grid of their own subject.
    F.links = {}
    for index = 1, 3 do
        F.links[index] = T.Button(frame, '', 160, 24, nil, 'secondary')
        F.links[index]:Hide()
    end
    F.linkSets = {
        pvp = {
            { text = 'Open PvP Help', width = 170, click = function()
                U.Navigate('pvp', 'help')
            end },
        },
        quests = {
            { text = 'Shared quests', width = 170, click = function()
                U.Navigate('quests', 'shared')
            end },
            { text = 'Quest groups', width = 150, click = function()
                U.Navigate('quests', 'questgroups')
            end },
            { text = 'Help Requests', width = 150, click = function()
                U.Navigate('quests', 'help')
            end },
        },
    }

    F.grid = createScroll(frame)
    F.tiles = {}
    F.gridEmpty = K.EmptyState(frame, { icon = 'search', width = 360 })
    F.gridEmpty:Hide()
    F.stream = createStream(frame)

    local detail = CreateFrame('Frame', nil, frame)
    F.detail = detail
    local hero = K.Card(detail, 'raised')
    detail.hero = hero
    hero.picture = createPicture(hero, 44)
    hero.fade = hero:CreateTexture(nil, 'ARTWORK')
    call(hero.fade, 'SetDrawLayer', 'ARTWORK', 2)
    T.SetGradient(hero.fade, 'HORIZONTAL', 'panelRaised', 'panelRaised', 0, 1)
    hero.title = K.Text(hero, '', 'display', 'text')
    hero.facts = K.Text(hero, '', 'body', 'textSoft')
    hero.counts = K.Text(hero, '', 'body', 'textSoft')
    hero.back = T.Button(hero, tr('Back to overview'), 160, 24, function()
        U.SetFinderView(F.view)
    end, 'secondary')
    hero.follow = K.IconButton(hero, 'bell', 26, function()
        U.ToggleFinderFollow(F.activity)
    end)
    hero.follow.edges = T.Edges(hero.follow, 'BORDER')
    function hero.follow:SetChecked(on)
        self.zenialOn = on == true
        self:SetIconColor(self.zenialOn and 'goldBright' or 'textSoft')
        T.TintEdges(self.edges, self.zenialOn and 'gold' or 'line')
        self.zenialTooltip = tr(self.zenialOn and 'You are notified about new ZENIAL groups for this instance. Click to stop.' or 'Notify me about new ZENIAL groups for this instance')
    end
    hero.create = T.Button(hero, tr('Create group'), 160, 26, function()
        U.OpenFinderCreate(F.activity)
    end, 'secondary')
    hero.search = T.Button(hero, tr('I am looking for a group'), 178, 26, function()
        local stats = F.snapshot and F.snapshot.by[F.activity]
        local own = Z.db.lfg[1]
        if stats and stats.ownSearch then
            U.RemoveFinderSearch(F.activity)
        elseif own and C.IsSearch(own) then
            U.AddFinderSearch(F.activity)
        else
            F.searchOpen = not F.searchOpen
            if F.searchOpen and U.FinderPublic then
                U.FinderPublic.PresetRoles(detail.searchBar.roles)
            end
            U.RefreshFinder()
        end
    end, 'secondary')
    hero.journal = T.Button(hero, tr('Open Dungeon Journal'), 178, 26, function()
        U.OpenFinderJournal(F.activity)
    end, 'secondary')

    local bar = K.Card(detail, 'surface')
    detail.searchBar = bar
    bar.caption = K.Text(bar, tr('My roles') .. ':', 'caption', 'dim')
    bar.caption:SetPoint('LEFT', 12, 0)
    oneLine(bar.caption, 86, 14)
    bar.roles = {}
    local preferred = L.Role(Z.db.roles) or 'DAMAGER'
    for index, role in ipairs(ROLES) do
        local chip = T.Chip(bar, Z.Locale.Role(role), 80, 24)
        chip:SetPoint('LEFT', 100 + (index - 1) * 86, 0)
        chip:SetChecked(role == preferred)
        bar.roles[role] = chip
    end
    bar.note = createEdit(bar, 250, 96, tr('Note (optional)'))
    bar.note:SetPoint('LEFT', 372, 0)
    bar.note:SetScript('OnTextChanged', function(self)
        self.hint:SetShown((self:GetText() or '') == '')
    end)
    bar.start = T.Button(bar, tr('Start search'), 130, 24, function()
        local roles = {}
        for role, chip in pairs(bar.roles) do
            roles[role] = chip:GetChecked() and true or false
        end
        if U.StartFinderSearch(F.activity, roles, bar.note:GetText() or '') then
            bar.note:SetText('')
        end
    end, 'secondary')
    bar.start:SetPoint('RIGHT', -98, 0)
    bar.cancel = T.Button(bar, tr('Cancel'), 84, 24, function()
        F.searchOpen = false
        U.RefreshFinder()
    end, 'secondary')
    bar.cancel:SetPoint('RIGHT', -8, 0)
    bar:Hide()
    detail.left = createStream(detail)
    detail.right = createStream(detail)
    detail:Hide()

    if U.FinderPublic then
        U.FinderPublic.Create(frame)
    end
    return frame
end

-- Shared with the group form (GroupFormUI.lua).
F.CreatePicture, F.SetRoleIcon = createPicture, setRoleIcon
-- Shared with the assistant of the public group search (UXFinderAssistant.lua).
F.CreateEdit = createEdit
F.ScriptFont = scriptFont
F.DrawMembers = drawMembers
-- Shared with the start page (UXStart.lua).
F.CreateTile, F.UpdateTile = createTile, updateTile

return F
