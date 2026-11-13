local Z = ZenialCommunity
local U = Z.UI
local L = Z.Logic
local A = Z.Adapter
local T = Z.Theme
local S = U.Shared
local tr = S.tr
local rows, peerOnline, faction, age, roleName = S.rows, S.peerOnline, S.faction, S.age, S.roleName

local mapNames, mapNameOrder = {}, {}
local function mapName(id)
    local now = A.Clock()
    local cached = mapNames[id]
    if cached and now < cached.retryAt then
        return cached.name
    end
    local info = A.Call(C_Map and C_Map.GetMapInfo, id)
    local name = A.PublicTable(info) and L.Text(info.name, 64) and info.name or ''
    if not cached then
        if #mapNameOrder >= 512 then
            mapNames[table.remove(mapNameOrder, 1)] = nil
        end
        mapNameOrder[#mapNameOrder + 1] = id
    end
    mapNames[id] = { name = name, retryAt = name ~= '' and math.huge or now + 5 }
    return name
end
local function modernLocation(p)
    if not p then
        return nil
    end
    if not p.cap30 or not p.presence then
        return p.location
    end
    local id = p.presence.mapID or 0
    if id == 0 then
        return nil
    end
    local name = mapName(id)
    return { mapID = id, area = name, subzone = '', at = p.presence.at }
end
local MEMBER_LIST_MAX_AGE = 90 * 86400
local function memberSeen(peer)
    if not peer then
        return 0
    end
    -- Relaying an old public bundle must not extend a member's visible lifetime.
    return math.max(peer.memberSeenAt or 0, peer.lastContact or 0, peer.reportedAt or 0, not peer.cap4 and (peer.received or 0) or 0)
end
local function visibleMember(m, query, now)
    -- This is a view filter only: archived contacts, notes and history stay intact.
    -- Search still exposes older contacts so their notes remain accessible.
    return not Z.db.blocked[m.key]
        and (
            m.own
            or m.online
            or Z.Social.IsFavorite(m.key)
            or Z.SocialCategories.Has(m.key)
            or query ~= ''
            or U.memberCategoryFilter and U.memberCategoryFilter:GetText() == 'RECONTACT' and Z.SocialCategories.LastTogether(m.key)
            or m.seen > 0 and now - m.seen <= MEMBER_LIST_MAX_AGE
        )
end
local function profText(s)
    local a = {}
    for _, p in ipairs(s and s.professions or {}) do
        a[#a + 1] = tr(p.name)
    end
    return table.concat(a, ', ')
end
local function locationText(o)
    if not o then
        return ''
    end
    local area, sub = o.area or '', o.subzone or ''
    if sub ~= '' and sub ~= area then
        return area ~= '' and (area .. ' · ' .. sub) or sub
    end
    return area
end
local function presenceDeadline(peer, clock, now)
    if not peer then
        return math.huge
    end
    local deadline = math.huge
    if peer.cap30 or peer.cap4 then
        local at = math.max(peer.lastContactClock or -1000, peer.reportedClock or -1000)
        if clock >= at and at + 300 > clock then
            deadline = at + 300
        end
    end
    if not peer.cap4 and peer.lastContact and peer.lastContact <= now and peer.lastContact + 300 > now then
        deadline = math.min(deadline, clock + peer.lastContact + 300 - now)
    end
    return deadline
end
S.presenceDeadline = presenceDeadline
local function memberEntries(ownOnly)
    local clock, now = A.Clock(), A.Now()
    local revision = Z.memberRevision or 0
    if not S.memberModel or S.memberModel.db ~= Z.db or S.memberModel.revision ~= revision or clock >= S.memberModel.deadline then
        local previous = S.memberModel and S.memberModel.db == Z.db and S.memberModel.byKey or {}
        local own = {
            class = Z.me.class,
            classFile = Z.me.classFile,
            level = Z.me.level,
            guild = Z.me.guild,
            professions = Z.db.professions,
            community = Z.db.community,
            faction = Z.me.faction,
            roles = Z.db.roles,
            note = Z.db.note,
        }
        local model =
            { db = Z.db, revision = revision, deadline = math.huge, entries = {}, byKey = {}, professions = { 'ALL_PROFESSIONS' } }
        local seenProfessions = {}
        local ownMain = Z.PublicLinks().main
        local function add(m, peer)
            local s = m.data
            local old = previous[m.key]
            m.sourceRevision = s and s.rev
            m.sourcePresence = peer and peer.presence
            m.sourceReceived = peer and peer.received
            m.sourceMain = s and s.linkMain
            m.sourceLinkVersion = s and s.linkVersion
            m.layerID = Z.CommunityLayer and (m.own and Z.CommunityLayer.Own() or not m.own and Z.CommunityLayer.Member(m.key)) or nil
            -- Heuristic hints only: "probable" never claims a certain shared layer.
            m.layerRelation = not m.own and m.layerID and Z.CommunityLayer.Relation and Z.CommunityLayer.Relation(m.key) or nil
            local layerSnapshot = not m.own and m.layerID and Z.CommunityLayer.MemberSnapshot and Z.CommunityLayer.MemberSnapshot(m.key) or nil
            m.layerSeenAt = layerSnapshot and layerSnapshot.observedAt or nil
            m.where = locationText(m.location)
            if
                not m.own
                and old
                and old.data == s
                and old.sourceRevision == m.sourceRevision
                and old.sourcePresence == m.sourcePresence
                and old.sourceReceived == m.sourceReceived
                and old.sourceMain == m.sourceMain
                and old.sourceLinkVersion == m.sourceLinkVersion
                and old.target == m.target
                and old.where == m.where
                and (not old.main or not m.sourceReceived or now <= m.sourceReceived + 604800)
            then
                m.main, m.cn, m.prof, m.hay, m.professionNames = old.main, old.cn, old.prof, old.hay, old.professionNames
            else
                m.main = m.own and ownMain or Z.ConfirmedMain(m.key)
                m.cn, m.prof = L.ClassName(s and s.class, s and s.classFile), profText(s)
                m.hay = string.lower(
                    m.target
                        .. ' '
                        .. (m.main or '')
                        .. ' '
                        .. m.cn
                        .. ' '
                        .. m.prof
                        .. ' '
                        .. m.where
                        .. ' '
                        .. (s and s.guild or '')
                        .. ' '
                        .. (s and s.community or '')
                        .. ' '
                        .. (s and s.roles or '')
                        .. ' '
                        .. (s and s.note or '')
                )
                m.professionNames = {}
                for _, p in ipairs(s and s.professions or {}) do
                    local name = L.ProfessionName(p.name)
                    if name then
                        m.professionNames[#m.professionNames + 1] = name
                    end
                end
            end
            model.entries[#model.entries + 1] = m
            model.byKey[m.key] = m
            for _, name in ipairs(m.professionNames) do
                if not seenProfessions[name] then
                    seenProfessions[name] = true
                    model.professions[#model.professions + 1] = name
                end
            end
            model.deadline = math.min(model.deadline, presenceDeadline(peer, clock, now))
            if not m.own and m.seen > 0 and m.seen + MEMBER_LIST_MAX_AGE >= now then
                model.deadline = math.min(model.deadline, clock + m.seen + MEMBER_LIST_MAX_AGE + 1 - now)
            end
            if m.main and m.sourceReceived and m.sourceReceived + 604800 >= now then
                model.deadline = math.min(model.deadline, clock + m.sourceReceived + 604801 - now)
            end
            local mapID = peer and peer.presence and peer.presence.mapID
            local cached = mapID and mapNames[mapID]
            if cached then
                model.deadline = math.min(model.deadline, cached.retryAt)
            end
        end
        add({ key = Z.me.key, target = Z.me.target, data = own, location = Z.location, online = true, seen = now, own = true })
        for key, c in pairs(Z.db.contacts) do
            if key ~= Z.me.key then
                local p = Z.db.peers[key]
                add(
                    { key = key, target = c.target, data = p and p.data, location = modernLocation(p), online = peerOnline(key), seen = memberSeen(
                        p
                    ) },
                    p
                )
            end
        end
        -- Shared private contacts remain accessible on another own character.
        -- These view entries do not discover peers or trigger profile traffic.
        for key, c in pairs(Z.SocialCategories.store.contacts) do
            if key ~= Z.me.key and not model.byKey[key] and not Z.db.blocked[key] then
                add({ key = key, target = c.target, online = false, seen = 0 })
            end
        end
        table.sort(model.professions, function(a, b)
            if a == 'ALL_PROFESSIONS' then
                return b ~= 'ALL_PROFESSIONS'
            elseif b == 'ALL_PROFESSIONS' then
                return false
            else
                return a < b
            end
        end)
        S.memberModel = model
    end
    return ownOnly and { S.memberModel.entries[1] } or S.memberModel.entries
end
S.memberEntries = memberEntries
local function peerLocation(key)
    local p = key and Z.db.peers[key]
    local where = locationText(modernLocation(p))
    local online = key and peerOnline(key)
    return where, online == true
end
S.peerLocation = peerLocation
local function peerLocationLine(key, label)
    local where, online = peerLocation(key)
    label = tr(label or 'Location')
    if where == '' then
        return label .. ': ' .. string.lower(tr('Unknown'))
    end
    return (online and label or tr('Last known location')) .. ': ' .. where
end
S.peerLocationLine = peerLocationLine
local function memberFor(key)
    memberEntries()
    return S.memberModel.byKey[key]
end
S.memberFor = memberFor
local function bindPrivateNote(key)
    if not U.memberPrivateNote then
        return
    end
    U.noteDrafts = U.noteDrafts or {}
    U.memberNoteBinding = true
    if U.memberNoteOwner ~= key then
        if U.memberNoteOwner then
            U.noteDrafts[U.memberNoteOwner] = U.memberPrivateNote:GetText()
        end
        U.memberPrivateNote:ClearFocus()
        U.memberNoteOwner = key
        U.memberPrivateNote:SetText(key and (U.noteDrafts[key] or Z.Social.GetNote(key)) or '')
    elseif not U.memberPrivateNote:HasFocus() then
        U.memberPrivateNote:SetText(key and (U.noteDrafts[key] or Z.Social.GetNote(key)) or '')
    end
    U.memberNoteBinding = false
    if U.memberNoteSaved then
        U.memberNoteSaved:SetShown(key ~= nil and U.memberPrivateNote:GetText() ~= '' and U.memberPrivateNote:GetText() == Z.Social.GetNote(key))
    end
end
-- Saves the note of the bound member as it is typed. A rejected text (invalid characters, too long)
-- is kept as a draft and reported once in the status line; nothing is lost.
function U.AutoSavePrivateNote()
    local key = U.memberNoteOwner
    if not key then
        return nil
    end
    local text = U.memberPrivateNote:GetText()
    local ok, err = Z.Social.Note(key, text)
    U.noteDrafts = U.noteDrafts or {}
    U.noteDrafts[key] = not ok and text or nil
    if U.memberNoteSaved then
        U.memberNoteSaved:SetShown(ok == true and text ~= '')
    end
    if not ok and U.memberNoteError ~= err then
        U.Message(err)
    end
    U.memberNoteError = not ok and err or nil
    return ok, err
end
function U.SavePrivateNote()
    if not U.memberKey or U.memberNoteOwner ~= U.memberKey then
        bindPrivateNote(U.memberKey)
        return nil, "Select the note's member before saving."
    end
    local ok, err = Z.Social.Note(U.memberNoteOwner, U.memberPrivateNote:GetText())
    if ok then
        U.noteDrafts[U.memberNoteOwner] = nil
    end
    U.Message(ok and 'Private note saved.' or err)
    if ok then
        U.Toast('Private note saved.')
    end
    return ok, err
end
function U.RefreshCategoryPanel()
    local C = Z.SocialCategories
    local key = U.categoryKey
    if not U.categoryPanel then
        return
    end
    local m = memberFor(key)
    local valid = m and not m.own and not Z.db.blocked[key]
    U.categorySummary:SetText(valid and (m.target .. '\n\n' .. C.Reason(key)) or tr('Select a contact to mark. Categories stay private.'))
    if C.readOnly then
        U.categorySummary:SetText(tr('Private categories use a newer format.'))
    end
    for id, b in pairs(U.categoryChecks) do
        b:SetChecked(C.Has(key, id))
        b:SetEnabled(valid and not C.readOnly)
    end
end
function U.OpenPrivateCategories()
    local peers = {}
    U.categoryKey = U.memberKey
    if #peers == 0 and U.categoryKey then
        peers = { U.categoryKey }
    end
    -- Dropdowns use TOOLTIP strata; dismiss background popups before the dialog.
    if S.openPopup then
        S.openPopup:Hide()
        S.openPopup = nil
    end
    U.categoryContact:SetOptions(peers, U.categoryKey)
    U.RefreshCategoryPanel()
    U.categoryPanel:Show()
end
-- Palette access for the member card (white when the shared theme is missing).
local function paletteHex(key)
    return T and T.PaletteHex and T.PaletteHex(key) or 'ffffff'
end
local function dimText(value)
    return '|cff' .. paletteHex('dim') .. value .. '|r'
end
local function paint(key, value)
    return '|cff' .. paletteHex(key) .. value .. '|r'
end
local function stripColors(value)
    return (tostring(value or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end
-- Plain text of the whole card (header lines, layer chip and fact list) as shown to the player.
function U.MemberCardText()
    local card = U.memberCard
    local parts = {}
    if card then
        for _, region in ipairs({ card.name, card.classLine, card.status }) do
            if region:IsShown() and region:GetText() ~= '' then
                parts[#parts + 1] = region:GetText()
            end
        end
        if card.layerTag and card.layerTag:IsShown() then
            parts[#parts + 1] = card.layerTag.text:GetText()
        end
    end
    parts[#parts + 1] = U.memberDetail:GetText()
    return stripColors(table.concat(parts, '\n'))
end
-- Header of the member card: portrait, class-coloured name, class line, presence and the known layer chip.
local function updateMemberHeader(m, s, layerText)
    local card = U.memberCard
    if not card then
        return
    end
    local has = m ~= nil
    U.memberCardHasMember = has
    if card.empty then
        card.empty:SetShown(not has)
    end
    if U.memberProfileScroll then
        U.memberProfileScroll:SetShown(has)
    end
    for _, region in ipairs({ card.portrait, card.name, card.classLine, card.status, card.statusDot, card.divider }) do
        region:SetShown(has)
    end
    if not has then
        card.layerTag:Hide()
        return
    end
    local r, g, b
    if T and T.ClassColor and s then
        r, g, b = T.ClassColor(s.classFile, s.class)
    end
    if r then
        card.name:SetTextColor(r, g, b)
    else
        T.Tint(card.name, 'SetTextColor', 'goldBright')
    end
    card.name:SetText(m.target)
    local icon = T and (s and T.ClassIcon(s.classFile, s.class) or { file = T.assets.neutralIcon })
    card.portrait:SetTexCoord(0, 1, 0, 1)
    if icon then
        T.SetTexture(card.portrait, icon)
    end
    card.classLine:SetText(s and (L.ClassName(s.class, s.classFile) .. ' · ' .. tr('Level') .. ' ' .. (s.level or 0) .. ' · ' .. faction(
        s.faction or Z.me.faction
    )) or '')
    card.status:SetText(m.online and tr('Online') or age(m.seen))
    if T and T.Tint then
        T.Tint(card.status, 'SetTextColor', m.online and 'online' or 'dim')
        T.Tint(card.statusDot, 'SetColorTexture', m.online and 'online' or 'dim')
    end
    if s and layerText then
        card.layerTag:SetLabel(layerText)
        card.layerTag:ClearAllPoints()
        local width = card.status.GetStringWidth and card.status:GetStringWidth()
        card.layerTag:SetPoint('LEFT', card.status, 'LEFT', (type(width) == 'number' and width or 40) + 10, 0)
        card.layerTag:Show()
    else
        card.layerTag:Hide()
    end
end
-- Linked group of a member in the grouped view; nil for single characters, in the single-character view
-- and for blocked characters. Groups only project member entries: every action keeps using real member keys.
local function linkedGroupOf(m)
    if not m or Z.db.blocked[m.key] or not (S.memberGroupingEnabled and S.memberGroupingEnabled()) then
        return nil
    end
    local g = S.memberGroupFor(m.key)
    return g and g.linked and not g.blocked and g or nil
end
-- Real character that whisper/invite reach. Own character: none. An explicitly chosen character (row click,
-- jump from another page) is always the exact target, as before. Only the group-header selection (follow
-- mode) redirects to the preferred online character of the group; never the offline main or the anchor.
local function contactTarget(m)
    if not m or m.own or Z.db.blocked[m.key] then
        return nil
    end
    local g = linkedGroupOf(m)
    if not g or U.memberFollowActive ~= true then
        return m
    end
    if m.online then
        return m
    end
    for _, a in ipairs(g.activeMembers) do
        if not a.own and not Z.db.blocked[a.key] then
            return a
        end
    end
    return nil
end
S.memberContactTarget = contactTarget
-- Identity block of a linked group: main headline, active character, action targets and known characters.
local function groupDetailLines(m, g, target)
    local lines = {}
    local function fact(caption, value)
        return dimText(caption .. ':') .. ' ' .. value
    end
    local active = g.activeMember
    lines[#lines + 1] = fact(tr('Main'), g.mainName .. (g.virtual and not g.isOwn and ' ' .. dimText('(' .. tr('not seen yet') .. ')') or ''))
    lines[#lines + 1] = fact(tr('Active'), active and active.target or tr('Offline'))
    lines[#lines + 1] = fact(tr('Acts on'), m.target)
    -- Own characters are never contacted: no contact line for them.
    if not m.own then
        lines[#lines + 1] = fact(tr('Whisper') .. ' / ' .. tr('Invite to group'), target and target.target or tr('No character online'))
    end
    if not m.online and U.memberFollowActive ~= true then
        for _, a in ipairs(g.activeMembers) do
            if not a.own and not Z.db.blocked[a.key] then
                lines[#lines + 1] = dimText(Z.T('Online: %s - select the row to contact', a.target))
                break
            end
        end
    end
    lines[#lines + 1] = dimText(tr('Known characters') .. ':')
    local shown = 0
    for _, c in ipairs(g.members) do
        if shown >= 4 then
            lines[#lines + 1] = dimText(Z.T('+%d more characters', #g.members - shown))
            break
        end
        shown = shown + 1
        local where = locationText(c.location)
        lines[#lines + 1] = (c == m and '> ' or '  ')
            .. c.target
            .. ' · '
            .. (c.data and (c.cn .. ' ' .. (type(c.data.level) == 'number' and c.data.level > 0 and c.data.level or tr('Unknown'))) or tr('Profile not received yet'))
            .. ' · '
            .. (c.online and tr('Online') or age(c.seen))
            .. (where ~= '' and ' · ' .. where or '')
    end
    lines[#lines + 1] = dimText(tr('Main and alts as declared by their addon; not verified.'))
    return lines
end
local function updateContactActions(m)
    local target = contactTarget(m)
    U.memberWhisper:SetEnabled(target ~= nil)
    U.memberInvite:SetEnabled(target ~= nil and target.online == true)
    U.memberWhisper.tipText = target and Z.T('Contact: %s', target.target) or nil
    U.memberInvite.tipText = target and Z.T('Contact: %s', target.target) or nil
    return target
end
local function refreshMemberDetail()
    local m = memberFor(U.memberKey)
    if m and Z.db.blocked[m.key] then
        m = nil
    end
    bindPrivateNote(m and m.key)
    if not m then
        updateMemberHeader(nil)
        U.memberDetail:SetText(dimText(tr('Select a member.')))
        U.memberWhisper:SetEnabled(false)
        U.memberInvite:SetEnabled(false)
        if U.UpdateFavoriteStar then
            U.UpdateFavoriteStar(false, false)
        end
        if U.memberPrivateNote then
            U.memberPrivateNote:SetText('')
        end
        return
    end
    local target = updateContactActions(m)
    local group = linkedGroupOf(m)
    local groupLines = group and groupDetailLines(m, group, target) or {}
    groupLines[#groupLines + 1] = dimText(Z.T('Private for %s', m.target or U.memberKey or m.key))
    if U.UpdateFavoriteStar then
        U.UpdateFavoriteStar(not m.own, Z.Social.IsFavorite(m.key))
    end
    local s = m.data
    if not s then
        updateMemberHeader(m, nil, nil)
        groupLines[#groupLines + 1] = dimText(tr('Profile not received yet'))
        U.memberDetail:SetText(table.concat(groupLines, '\n'))
        return
    end
    local layerText = Z.CommunityLayer.KnownLabel(m.layerID)
    updateMemberHeader(m, s, layerText)
    -- Fact list: every line the plain detail used to carry, with a dim caption in front of the value.
    local function fact(caption, value)
        return dimText(caption) .. ' ' .. value
    end
    local lines = groupLines
    if s.community and s.community ~= '' then
        lines[#lines + 1] = fact(tr('Display name') .. ':', s.community)
    end
    local where = locationText(m.location)
    if where ~= '' then
        lines[#lines + 1] = fact(m.online and tr('Current location:') or (tr('Last known location') .. ':'), where)
    end
    if s.roles and s.roles ~= '' then
        lines[#lines + 1] = fact(tr('Preferred role') .. ':', roleName(s.roles))
    end
    if s.guild and s.guild ~= '' then
        local rank = Z.Social.GuildRank(m.key)
        lines[#lines + 1] = fact(tr('Guild') .. ':', rank and (s.guild .. ' (' .. rank .. ')') or s.guild)
    end
    local prof = profText(s)
    if prof ~= '' then
        lines[#lines + 1] = fact(tr('Professions') .. ':', prof)
    end
    if s.note and s.note ~= '' then
        lines[#lines + 1] = '\n|cff' .. paletteHex('textSoft') .. s.note .. '|r'
    end
    local main = m.own and Z.PublicLinks().main or Z.ConfirmedMain(m.key)
    if main then
        lines[#lines + 1] = fact(tr('Main') .. ':', main)
    end
    -- Private, local only: what the own social diary recorded about this player.
    local met = not m.own and Z.SocialDiary and Z.SocialDiary.Get and Z.SocialDiary.Get(m.key)
    if type(met) == 'table' and type(met.count) == 'number' and met.count > 0 then
        lines[#lines + 1] = fact(tr('Social diary') .. ':', Z.T('%d encounters', met.count)
            .. (met.last and ' · ' .. tr('Last encounter') .. ' ' .. age(met.last) or ''))
    end
    if not layerText then
        lines[#lines + 1] = '\n|cff' .. paletteHex('muted') .. Z.CommunityLayer.Label(nil) .. '|r'
    else
        if m.layerRelation == 'probable' then
            lines[#lines + 1] = dimText(tr('Probably the same layer'))
        end
        if m.layerSeenAt then
            lines[#lines + 1] = dimText(Z.T('Layer last detected %s', age(m.layerSeenAt)))
        end
    end
    U.memberDetail:SetText(table.concat(lines, '\n'))
end
local refreshMembers
-- Grouping by declared main is a local view preference (account-wide, never published).
local function groupingEnabled()
    return not Z.ui or Z.ui.memberGrouping ~= false
end
S.memberGroupingEnabled = groupingEnabled
function U.SetMemberGrouping(enabled)
    if Z.ui then
        Z.ui.memberGrouping = enabled ~= false
    end
    if U.memberGrouping then
        U.memberGrouping:SetChecked(enabled ~= false)
    end
    if U.memberList then
        refreshMembers()
    end
end
-- Character filter shared by both views; the status filter is applied per view.
local function memberMatches(m, ctx)
    local s = m.data
    local hay = m.hay .. ' ' .. string.lower(ctx.C.Text(m.key))
    return visibleMember(m, ctx.query, ctx.now)
        and (ctx.query == '' or hay:find(ctx.query, 1, true))
        and (ctx.class == 'ALL_CLASSES' or s and s.classFile == ctx.class)
        and (ctx.profession == 'ALL_PROFESSIONS' or m.prof:find(tr(ctx.profession), 1, true))
        and (not ctx.favoriteOnly or Z.Social.IsFavorite(m.key))
        and (ctx.selected ~= 'MY_GUILD' or Z.Social.IsGuildMember(m.key))
        and ctx.C.Matches(m.key, ctx.category)
end
local function sortRecords(records, sort)
    table.sort(records, function(a, b)
        if a.favorite ~= b.favorite then
            return a.favorite == true
        end
        if sort == 'ONLINE_FIRST' then
            if a.online ~= b.online then
                return a.online == true
            end
            if not a.online and a.seen ~= b.seen then
                return a.seen > b.seen
            end
            if a.target ~= b.target then
                return a.target > b.target
            end
            return a.key > b.key
        end
        local av, bv = a.level, b.level
        if sort == 'LEVEL_ASC' and av ~= bv then
            return av < bv
        elseif sort == 'LEVEL_DESC' and av ~= bv then
            return av > bv
        elseif sort == 'LAST_SEEN' and a.seen ~= b.seen then
            return a.seen > b.seen
        end
        if a.target ~= b.target then
            return a.target < b.target
        end
        return a.key < b.key
    end)
end
local function memberRecord(m)
    return {
        member = m,
        favorite = m.online == true and Z.Social.IsFavorite(m.key) == true,
        online = m.online,
        seen = m.seen,
        target = m.target,
        key = m.key,
        level = m.data and m.data.level or 0,
    }
end
-- Selection is a real member key (U.memberKey) plus a follow flag: a group header selects the group and
-- follows its active character; a character row or an external jump (U.memberKey set directly) pins it.
local function selectMember(memberKey, m, follow)
    U.memberKey, U.memberKeySeen, U.memberFollowActive = memberKey, memberKey, follow == true
    if m and not m.own and m.data and m.data.publicOnly then
        Z.RequestProfile(memberKey)
    end
    refreshMembers()
    refreshMemberDetail()
    U.OpenCompactArea('members')
end
local function locationLine(m)
    return m.where ~= '' and ((m.online and tr('Location:') .. ' ' or tr('Last known location') .. ': ') .. m.where)
        or (tr('Location') .. ': ' .. string.lower(tr('Unknown')))
end
local function layerChip(m)
    local layerText = Z.CommunityLayer.KnownLabel(m.layerID)
    return layerText and ('|cff' .. paletteHex('accentBlue') .. layerText .. '|r · ') or '', layerText
end
-- One character row: the unchanged per-character item of the list.
local function characterItem(m, ctx)
    local s = m.data
    local name = m.target .. (s and s.community and s.community ~= '' and ' (' .. s.community .. ')' or '')
    -- Class colour where the class is known; otherwise the previous colours (own gold, others white).
    local classHex = T and T.ClassColorHex and s and T.ClassColorHex(s.classFile, s.class)
    local title = '|cff'
        .. (classHex or (m.own and 'ffd36b' or 'ffffff'))
        .. name
        .. '|r'
        .. (m.own and ' |cff' .. paletteHex('gold') .. '[' .. tr('You') .. ']|r' or '')
        .. '    '
        .. (m.online and '|cff' .. paletteHex('online') .. tr('Online') .. '|r' or dimText(age(m.seen)))
    local info = s and (m.cn .. ' · ' .. tr('Level') .. ' ' .. (s.level or 0) .. (s.roles and s.roles ~= '' and ' · ' .. roleName(
        s.roles
    ) or '')) or tr('Profile not received yet')
    local location = m.where ~= '' and ((m.online and tr('Location:') .. ' ' or tr('Last known location') .. ': ') .. m.where) or ''
    if m.main and m.main ~= '' and L.Identity(m.main) ~= L.Identity(m.target) then
        if location ~= '' then
            location = location .. ' · ' .. tr('Main') .. ': ' .. m.main
        else
            info = info .. ' · ' .. tr('Main') .. ': ' .. m.main
        end
    end
    -- Visual weighting only (item.display): class-coloured name first, community and meta recede.
    local display = '|cff'
        .. (classHex or (m.own and 'ffd36b' or 'ffffff'))
        .. m.target
        .. '|r'
        .. (s and s.community and s.community ~= '' and dimText(' (' .. s.community .. ')') or '')
        .. (m.own and ' ' .. paint('gold', '[' .. tr('You') .. ']') or '')
        .. '    '
        .. (m.online and paint('online', tr('Online')) or dimText(age(m.seen)))
    local tooltip = title .. '\n' .. info .. (location ~= '' and '\n' .. location or '')
    if Z.Social.IsFavorite(m.key) then
        tooltip = tooltip .. '\n' .. tr('Favorite')
    end
    if Z.Social.IsGuildMember(m.key) then
        tooltip = tooltip .. '\n' .. tr('Guild') .. ': ' .. Z.Social.GuildName()
    end
    local chip, layerText = layerChip(m)
    if layerText then
        tooltip = tooltip .. '\n' .. layerText
        if m.layerRelation == 'probable' then
            tooltip = tooltip .. '\n' .. tr('Probably the same layer')
        end
        if m.layerSeenAt then
            tooltip = tooltip .. '\n' .. Z.T('Layer last detected %s', age(m.layerSeenAt))
        end
    end
    local level = s and type(s.level) == 'number' and s.level > 0 and tostring(s.level) or tr('Unknown')
    local at = ctx.category == 'RECONTACT' and ctx.C.LastTogether(m.key)
    if at then
        tooltip = tooltip .. '\n' .. Z.T('Last together %d days ago.', math.floor((ctx.now - at) / 86400))
    end
    local memberKey = m.key
    return {
        iconTop = true,
        noWrap = true,
        ageAt = not m.online and m.seen or nil,
        ageText = not m.online and age(m.seen) or nil,
        selected = memberKey == U.memberKey,
        icon = T and T.ClassIcon(s and s.classFile, s and s.class),
        iconSize = 28,
        textInset = 46,
        text = title,
        display = display,
        subtitle = tr('Level') .. ' ' .. level .. ' · ' .. chip .. locationLine(m),
        subtitleDisplay = paint('textSoft', tr('Level') .. ' ' .. level) .. ' · ' .. chip .. locationLine(m),
        tooltip = tooltip,
        favorite = Z.Social.IsFavorite(m.key),
        sameGuild = Z.Social.IsGuildMember(m.key),
        click = function()
            selectMember(memberKey, m)
        end,
    }
end
local function neutralIcon()
    return { file = 'Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon' }
end
local function roleLabel(g, m)
    return tr(m == g.mainMember and 'Main' or 'Alt')
end
-- Short class/level text of one real character; nothing is invented for missing data.
local function classLevel(m)
    local s = m.data
    if not s then
        return tr('Profile not received yet')
    end
    local level = type(s.level) == 'number' and s.level > 0 and tostring(s.level) or tr('Unknown')
    return m.cn .. ' ' .. level
end
local function containsKey(g, key)
    for _, k in ipairs(g.memberKeys) do
        if k == key then
            return true
        end
    end
    return false
end
-- Header of one linked group. The headline is the main's name; every live detail
-- (class, level, location, layer) belongs to the active character only.
local function groupItem(g, hits, ctx)
    local main, active = g.mainMember, g.activeMember
    local ms = main and main.data
    local expanded = U.memberGroupExpanded[g.groupKey] == true
    local classHex = T and T.ClassColorHex and ms and T.ClassColorHex(ms.classFile, ms.class)
    local status
    if active and active == main then
        status = '|cff' .. paletteHex('online') .. tr('Online') .. ' · ' .. tr('playing main') .. '|r'
    elseif active then
        status = '|cff' .. paletteHex('online') .. Z.T('Online · playing %s', active.target) .. '|r'
    elseif g.lastSeen > 0 then
        status = dimText(Z.T('Offline · last seen %s', age(g.lastSeen)))
    else
        status = dimText(tr('Offline'))
    end
    local mark = '|TInterface\\Buttons\\UI-' .. (expanded and 'Minus' or 'Plus') .. 'Button-Up:14:14|t '
    local title = mark
        .. '|cff'
        .. (classHex or (g.isOwn and 'ffd36b' or 'ffffff'))
        .. g.mainName
        .. '|r '
        .. dimText('(' .. tr('Main') .. ')')
        .. (g.isOwn and ' |cff' .. paletteHex('gold') .. '[' .. tr('You') .. ']|r' or '')
        .. '    '
        .. status
    local subtitle
    if active then
        local chip = layerChip(active)
        subtitle = tr('Active') .. ': ' .. active.target .. ' · ' .. classLevel(active) .. ' · ' .. chip .. locationLine(active)
        if #g.activeMembers > 1 then
            subtitle = subtitle .. ' · ' .. Z.T('+%d more online', #g.activeMembers - 1)
        end
    else
        subtitle = (ms and classLevel(main) .. ' · ' or '')
            .. Z.T(#g.members == 1 and '%d known character' or '%d known characters', #g.members)
    end
    -- A filter that only matches alts is shown, so the group never looks like a random result.
    local hitMain, names = false, {}
    for _, m in ipairs(hits) do
        if m == main then
            hitMain = true
        end
        names[#names + 1] = m.target
    end
    if ctx.filtering and not hitMain then
        subtitle = subtitle .. ' · ' .. tr('Match') .. ': ' .. table.concat(names, ', ')
    end
    -- No subtitleDisplay here: the rendered subtitle of a group head is read as plain text elsewhere.
    local display = mark
        .. '|cff'
        .. (classHex or (g.isOwn and 'ffd36b' or 'ffffff'))
        .. g.mainName
        .. '|r '
        .. dimText('(' .. tr('Main') .. ')')
        .. (g.isOwn and ' ' .. paint('gold', '[' .. tr('You') .. ']') or '')
        .. '    '
        .. status
    local favorite, sameGuild = false, false
    local lines = { g.mainName .. ' (' .. tr('Main') .. ')' }
    if active then
        lines[#lines + 1] = (active == main and tr('Online') or Z.T('Online: %s', active.target)) .. ' · ' .. classLevel(active)
        if active.where and active.where ~= '' then lines[#lines + 1] = active.where end
        local _, knownLayer = layerChip(active)
        if knownLayer then lines[#lines + 1] = knownLayer end
    else
        lines[#lines + 1] = g.lastSeen > 0 and Z.T('Offline · last seen %s', age(g.lastSeen)) or tr('Offline')
    end
    for _, m in ipairs(g.members) do
        favorite = favorite or Z.Social.IsFavorite(m.key)
        sameGuild = sameGuild or Z.Social.IsGuildMember(m.key)
    end
    local hoverMember = active or main
    if hoverMember and Z.Social.IsGuildMember(hoverMember.key) then
        lines[#lines + 1] = tr('Guild') .. ': ' .. Z.Social.GuildName()
    end
    -- The concrete character a selection uses: the active one, else the main, else the first known.
    local pick = active or main or g.members[1]
    return {
        iconTop = true,
        noWrap = true,
        ageAt = not g.online and g.lastSeen > 0 and g.lastSeen or nil,
        ageText = not g.online and g.lastSeen > 0 and age(g.lastSeen) or nil,
        selected = not expanded and containsKey(g, U.memberKey),
        icon = T and (classHex and T.ClassIcon(ms.classFile, ms.class) or neutralIcon()),
        iconSize = 28,
        textInset = 46,
        text = title,
        display = display,
        subtitle = subtitle,
        tooltip = table.concat(lines, '\n'),
        favorite = favorite,
        sameGuild = sameGuild,
        click = function()
            if containsKey(g, U.memberKey) and U.memberGroupExpanded[g.groupKey] then
                U.memberGroupExpanded[g.groupKey] = nil
                refreshMembers()
                return
            end
            U.memberGroupExpanded[g.groupKey] = true
            if containsKey(g, U.memberKey) then
                refreshMembers()
                return
            end
            selectMember(pick.key, pick, true)
        end,
    }
end
-- One known character inside an expanded group, with its own status.
local function groupMemberItem(g, m, hit, ctx)
    local s = m.data
    local classHex = T and T.ClassColorHex and s and T.ClassColorHex(s.classFile, s.class)
    local title = '|cff'
        .. (classHex or (m.own and 'ffd36b' or 'ffffff'))
        .. m.target
        .. '|r '
        .. dimText('· ' .. roleLabel(g, m))
        .. (m.own and ' |cff' .. paletteHex('gold') .. '[' .. tr('You') .. ']|r' or '')
        .. (ctx.filtering and hit and dimText(' · ' .. tr('Match')) or '')
        .. '    '
        .. (m.online and '|cff' .. paletteHex('online') .. tr('Online') .. '|r' or dimText(age(m.seen)))
    local chip = layerChip(m)
    local memberKey = m.key
    local display = '|cff'
        .. (classHex or (m.own and 'ffd36b' or 'ffffff'))
        .. m.target
        .. '|r '
        .. dimText('· ' .. roleLabel(g, m))
        .. (m.own and ' ' .. paint('gold', '[' .. tr('You') .. ']') or '')
        .. (ctx.filtering and hit and dimText(' · ' .. tr('Match')) or '')
        .. '    '
        .. (m.online and paint('online', tr('Online')) or dimText(age(m.seen)))
    return {
        iconTop = true,
        noWrap = true,
        indent = 22,
        height = 44,
        ageAt = not m.online and m.seen or nil,
        ageText = not m.online and age(m.seen) or nil,
        selected = memberKey == U.memberKey,
        icon = T and (T.ClassIcon(s and s.classFile, s and s.class) or neutralIcon()),
        text = title,
        display = display,
        subtitle = classLevel(m) .. ' · ' .. chip .. locationLine(m),
        subtitleDisplay = paint('textSoft', classLevel(m)) .. ' · ' .. chip .. locationLine(m),
        tooltip = Z.Social.IsGuildMember(m.key) and tr('Guild') .. ': ' .. Z.Social.GuildName() or nil,
        favorite = Z.Social.IsFavorite(m.key),
        sameGuild = Z.Social.IsGuildMember(m.key),
        click = function()
            selectMember(memberKey, m)
        end,
    }
end
local function groupLevel(g)
    local m = g.activeMember or g.mainMember
    return m and m.data and m.data.level or 0
end
local function groupedItems(ctx)
    local records, characters = {}, 0
    for _, g in ipairs((S.memberGroups())) do
        if not g.blocked then
            local hits, hitSet = {}, {}
            for _, m in ipairs(g.members) do
                if memberMatches(m, ctx) then
                    hits[#hits + 1] = m
                    hitSet[m] = true
                end
            end
            -- The online filter needs at least one online character of the group.
            if #hits > 0 and (ctx.status == 'ALL' or g.online) then
                characters = characters + #g.members
                if g.linked then
                    local favorite = false
                    for _, m in ipairs(g.members) do
                        favorite = favorite or Z.Social.IsFavorite(m.key)
                    end
                    records[#records + 1] = {
                        group = g,
                        hits = hits,
                        hitSet = hitSet,
                        favorite = g.online == true and favorite == true,
                        online = g.online,
                        seen = g.lastSeen,
                        target = g.mainName,
                        key = g.groupKey,
                        level = groupLevel(g),
                    }
                else
                    records[#records + 1] = memberRecord(g.members[1])
                end
            end
        end
    end
    sortRecords(records, ctx.sort)
    local items = {}
    for _, r in ipairs(records) do
        if r.group then
            items[#items + 1] = groupItem(r.group, r.hits, ctx)
            if U.memberGroupExpanded[r.group.groupKey] then
                for _, m in ipairs(r.group.members) do
                    items[#items + 1] = groupMemberItem(r.group, m, r.hitSet[m], ctx)
                end
            end
        else
            items[#items + 1] = characterItem(r.member, ctx)
        end
    end
    return items, #records, characters
end
-- Keeps the selection stable across refreshes: a jump from another page (key set from outside) selects
-- exactly that character and opens its group; a group selection follows the group's active character.
local function syncSelection()
    if U.memberKey ~= U.memberKeySeen then
        U.memberKeySeen, U.memberFollowActive = U.memberKey, false
        local m = U.memberKey and memberFor(U.memberKey)
        local g = m and linkedGroupOf(m)
        if g then
            U.memberGroupExpanded[g.groupKey] = true
        end
    elseif U.memberFollowActive and U.memberKey and not (U.memberPrivateNote and U.memberPrivateNote:HasFocus()) then
        local g = linkedGroupOf(memberFor(U.memberKey))
        local pick = g and (g.activeMember or g.mainMember or g.members[1])
        if pick and pick.key ~= U.memberKey then
            U.memberKey, U.memberKeySeen = pick.key, pick.key
        end
    end
    local g = U.memberKey and S.memberGroupFor(U.memberKey)
    U.memberGroupKey = g and g.groupKey or nil
end
function refreshMembers()
    U.memberGroupExpanded = U.memberGroupExpanded or {}
    syncSelection()
    local query = string.lower(U.memberSearch:GetText() or '')
    local status, class, profession = U.memberStatus:GetText(), U.memberClass:GetText(), U.memberProfession:GetText()
    if status ~= 'ONLINE' then
        status = 'ALL'
        U.memberStatus:SetText(status)
    end
    if Z.uiCharacter then
        Z.uiCharacter.memberStatus = status
    end
    local favoriteOnly = U.memberFavoriteFilter and U.memberFavoriteFilter:GetText() == 'FAVORITES'
    local C = Z.SocialCategories
    if U.SyncCategoryControls then
        U.SyncCategoryControls()
    end
    local selected = U.memberFavoriteFilter and U.memberFavoriteFilter:GetText() or 'ALL'
    local category = selected ~= 'FAVORITES' and selected ~= 'MY_GUILD' and selected or 'ALL'
    local ctx = {
        query = query,
        status = status,
        class = class,
        profession = profession,
        favoriteOnly = favoriteOnly,
        selected = selected,
        category = category,
        now = A.Now(),
        C = C,
        sort = U.memberSort:GetText(),
    }
    -- Filters that pick characters (the online status is a group signal in the grouped view).
    ctx.filtering = query ~= '' or class ~= 'ALL_CLASSES' or profession ~= 'ALL_PROFESSIONS' or favoriteOnly or selected ~= 'ALL'
    local grouped = groupingEnabled()
    if U.memberGrouping then
        U.memberGrouping:SetChecked(grouped)
    end
    local items, count
    if grouped then
        local identities, characters
        items, identities, characters = groupedItems(ctx)
        count = Z.T(identities == 1 and '%d player identity' or '%d player identities', identities)
            .. ' · '
            .. Z.T(characters == 1 and '%d known character' or '%d known characters', characters)
    else
        local records = {}
        for _, m in ipairs(memberEntries()) do
            if memberMatches(m, ctx) and (status == 'ALL' or status == 'ONLINE' and m.online) then
                records[#records + 1] = memberRecord(m)
            end
        end
        sortRecords(records, ctx.sort)
        items = {}
        for _, r in ipairs(records) do
            items[#items + 1] = characterItem(r.member, ctx)
        end
        count = #records .. ' ' .. tr(#records == 1 and 'member' or 'members')
    end
    local filtering = ctx.filtering or status ~= 'ALL'
    U.SetEmptyHint(
        U.memberList,
        filtering and 'No members match your filters. Reset the filters or press Refresh.'
            or 'No community members found yet. Press Refresh to search again.',
        filtering and 'search' or 'members'
    )
    rows(U.memberList, items, 48)
    U.memberCount:SetText(count)
    refreshMemberDetail()
    U.RefreshCategoryPanel()
    if U.RefreshMemberCategories then
        U.RefreshMemberCategories()
    end
end

S.refreshMembers = refreshMembers
