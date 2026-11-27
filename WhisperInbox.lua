-- Whisper requests to the player's own open group (FWR-2). See _dev/addons/ZenialCommunity/FINDER-FILTERS-WHISPERS-RATING-PLAN.md
--
-- While the player has an own ZENIAL group open (not an own search), every whisper becomes or updates one request
-- per sender. The requests belong to that group, live in Z.db.whisperRequests (saved with the character) and
-- disappear with the group. The text of a message is never read for meaning: any whisper is a request. No /who.
-- This file holds logic only; the rows are built in UXGroups.lua and ActivityDetailsUI.lua.
local Z = ZenialCommunity
local L, A = Z.Logic, Z.Adapter
local W = {}
Z.WhisperInbox = W

W.LIMIT, W.EARLIER, W.TEXT_MAX = 40, 5, 120
local STATES = { new = true, invited = true, joined = true }

-- Chat text as plain, single-line text: links keep their label, colour and texture codes are gone, no pipe is left.
local function cleanText(raw)
    if not A.Safe(raw) or type(raw) ~= 'string' then
        return nil
    end
    local text = raw:gsub('|H.-|h(.-)|h', '%1')
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|T.-|t', ''):gsub('|A.-|a', '')
    text = text:gsub('[%z\1-\31\127|]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #text > W.TEXT_MAX then
        text = text:sub(1, W.TEXT_MAX)
        -- Never cut a UTF-8 character in half.
        while #text > 0 do
            local byte = text:byte(#text)
            if byte >= 0xC0 then
                text = text:sub(1, #text - 1)
                break
            elseif byte >= 0x80 then
                text = text:sub(1, #text - 1)
            else
                break
            end
        end
        text = text .. '...'
    end
    return text
end

local function classToken(value)
    return type(value) == 'string' and #value <= 16 and value:match('^[A-Z]+$') and value or nil
end

-- The open own group (not an own search) or nil.
local function activeGroup()
    local d = Z.db
    local g = d and d.lfg and d.lfg[1]
    if g and g.mode ~= 'LFG' and type(g.id) == 'string' and (type(g.expires) ~= 'number' or g.expires > A.Now()) then
        return g
    end
    return nil
end

-- The store of the open group; a store of another (or no) group is dropped. create: make it when there is none.
local function store(create)
    local d = Z.db
    if not d then
        return nil
    end
    local g = activeGroup()
    local s = d.whisperRequests
    if type(s) == 'table' and s.group ~= (g and g.id or nil) then
        d.whisperRequests, s = nil, nil
    end
    if not g then
        return nil
    end
    if not s and create then
        s = { group = g.id, list = {} }
        d.whisperRequests = s
    end
    return s, g
end

local function find(s, id)
    for index, req in ipairs(s.list) do
        if req.id == id then
            return req, index
        end
    end
    return nil
end

-- Identity keys of the other members of the own group.
local function groupKeys()
    local out, total = {}, A.Call(GetNumGroupMembers) or 0
    if type(total) ~= 'number' or total < 2 then
        return out
    end
    local raid = A.Call(IsInRaid) == true
    for index = 1, raid and total or total - 1 do
        local key = A.UnitIdentity((raid and 'raid' or 'party') .. index)
        if key then
            out[key] = true
        end
    end
    return out
end

-- Flags that can change while the request lives: addon user or known peer, member of the own guild.
local function flags(req)
    local peerKey = Z.ResolvePeerKey and Z.ResolvePeerKey(req.name)
    req.zenial = peerKey ~= nil and Z.db ~= nil and (Z.db.peers[peerKey] ~= nil or Z.db.contacts[peerKey] ~= nil)
    req.guild = Z.Social ~= nil and Z.Social.IsGuildMember(req.id) == true
    return peerKey
end

-- Class and level from what the addon already knows: the GUID of the whisper, the ZENIAL profile, the Social
-- Diary and (once, at arrival) the current public group search. Existing values stay.
local function fill(req, group)
    if not req.classFile and req.guid and type(GetPlayerInfoByGUID) == 'function' then
        local ok, className, classFile = pcall(GetPlayerInfoByGUID, req.guid)
        if ok and A.Safe(className, classFile) then
            req.classFile = classToken(classFile)
            if L.Text(className, 24) then
                req.className = className
            end
        end
    end
    local peerKey = flags(req)
    local function take(classFile, level)
        req.classFile = req.classFile or classToken(classFile)
        if not req.level and L.Int(level, 1, 100) then
            req.level = level
        end
    end
    local peer = peerKey and Z.db.peers[peerKey]
    for _, data in ipairs({ peer and peer.data or false, peer and peer.presence or false }) do
        if type(data) == 'table' then
            take(data.classFile, data.level)
        end
    end
    local diary = peerKey and Z.SocialDiary and Z.SocialDiary.Get and Z.SocialDiary.Get(peerKey)
    if type(diary) == 'table' then
        take(diary.classFile, diary.level)
    end
    if group and (not req.classFile or not req.level) and Z.PublicLFG and Z.PublicLFG.Rows then
        local ok, found = pcall(Z.PublicLFG.Rows, group.activity)
        for _, row in ipairs(ok and type(found) == 'table' and found or {}) do
            if type(row.leader) == 'string' and L.Identity(row.leader) == req.id then
                take(row.leaderClass, row.leaderLevel)
                break
            end
        end
    end
end

-- The saved requests of a character (called while the character record loads; raw is the saved table). Only a
-- valid request of the group that is open now survives.
function W.Load(d, raw)
    d.whisperRequests = nil
    local g = d.lfg and d.lfg[1]
    if type(raw) ~= 'table' or type(raw.list) ~= 'table' or not g or g.mode == 'LFG' or raw.group ~= g.id then
        return
    end
    local list = {}
    for _, e in ipairs(raw.list) do
        local id = type(e) == 'table' and L.Text(e.name, 113) and (L.Identity(e.name))
        if id and e.id == id and STATES[e.state] and L.Int(e.count, 1, 9999) and L.Int(e.first, 1, 4102444800) and L.Int(e.last, 1, 4102444800)
            and L.Text(e.message, W.TEXT_MAX + 3, true) and (e.guid == nil or L.Text(e.guid, 80)) then
            local req = { id = id, name = e.name, guid = e.guid, message = e.message, earlier = {}, count = e.count, first = e.first, last = e.last, state = e.state }
            for _, text in ipairs(type(e.earlier) == 'table' and e.earlier or {}) do
                if #req.earlier < W.EARLIER and L.Text(text, W.TEXT_MAX + 3, true) then
                    req.earlier[#req.earlier + 1] = text
                end
            end
            req.classFile = classToken(e.classFile)
            req.className = L.Text(e.className, 24) and e.className or nil
            req.level = L.Int(e.level, 1, 100) and e.level or nil
            req.zenial, req.guild = e.zenial == true, e.guild == true
            if #list < W.LIMIT then
                list[#list + 1] = req
            end
        end
    end
    if #list > 0 then
        d.whisperRequests = { group = g.id, list = list }
    end
end

-- CHAT_MSG_WHISPER: text, sender, language, channel, target, flags, zoneChannelID, channelIndex, channelBase, languageID,
-- lineID, guid. Returns whether a request was added or updated.
function W.Capture(text, sender, _, _, _, flag, _, _, _, _, _, guid)
    local g = activeGroup()
    if not g or not A.Safe(text, sender, flag) or type(sender) ~= 'string' or type(text) ~= 'string' then
        return false
    end
    if flag == 'GM' or flag == 'DEV' or not L.Text(sender, 113) then
        return false
    end
    local id = L.Identity(sender)
    if not id then
        return false
    end
    -- Own name, blocked players, players already in the group.
    local me = Z.me and Z.me.target and L.Identity(Z.me.target)
    local peerKey = Z.ResolvePeerKey and Z.ResolvePeerKey(sender)
    local blocked = Z.db.blocked or {}
    if id == me or blocked[id] or (peerKey and blocked[peerKey]) or groupKeys()[id] then
        return false
    end
    -- Messages of the addon itself (cross-faction chat lines) are no requests.
    local codec = Z.CrossFactionCodec
    if codec and type(text) == 'string' and (codec.DecodeLine(text) ~= nil or codec.IsLegacyLine(text)) then
        return false
    end
    local message = cleanText(text)
    if not message then
        return false
    end
    local s = store(true)
    local now = A.Now()
    local req = find(s, id)
    if req then
        table.insert(req.earlier, 1, req.message)
        for index = W.EARLIER + 1, #req.earlier do
            req.earlier[index] = nil
        end
        req.name, req.message, req.last, req.count = sender, message, now, math.min(req.count + 1, 9999)
    else
        req = { id = id, name = sender, message = message, earlier = {}, count = 1, first = now, last = now, state = 'new' }
        if A.Safe(guid) and L.Text(guid, 80) then
            req.guid = guid
        end
        s.list[#s.list + 1] = req
        -- At most 40: the one that wrote longest ago goes.
        while #s.list > W.LIMIT do
            local oldest = 1
            for index, other in ipairs(s.list) do
                if other.last < s.list[oldest].last then
                    oldest = index
                end
            end
            table.remove(s.list, oldest)
        end
    end
    fill(req, g)
    Z.MarkDirty('whispers')
    return true
end

-- GROUP_ROSTER_UPDATE: whoever sent a request and is in the group now has joined.
function W.OnRoster()
    local s = store(false)
    if not s or #s.list == 0 then
        return false
    end
    local members, changed = groupKeys(), false
    for _, req in ipairs(s.list) do
        if members[req.id] and req.state ~= 'joined' then
            req.state, changed = 'joined', true
        end
    end
    if changed then
        Z.MarkDirty('whispers')
    end
    return changed
end

function W.OnEvent(event, ...)
    if event == 'CHAT_MSG_WHISPER' then
        return W.Capture(...)
    elseif event == 'GROUP_ROSTER_UPDATE' then
        return W.OnRoster()
    end
    return false
end

-- The requests of the open group, the newest message first.
function W.List()
    local s = store(false)
    local out = {}
    if not s then
        return out
    end
    for _, req in ipairs(s.list) do
        fill(req, nil)
        out[#out + 1] = req
    end
    table.sort(out, function(a, b)
        if a.last ~= b.last then
            return a.last > b.last
        end
        return a.id < b.id
    end)
    return out
end

function W.Get(id)
    local s = store(false)
    local req = s and find(s, id)
    if req then
        fill(req, nil)
    end
    return req
end

-- Requests nobody has dealt with yet (for counters).
function W.Pending()
    local s, n = store(false), 0
    for _, req in ipairs(s and s.list or {}) do
        if req.state == 'new' then
            n = n + 1
        end
    end
    return n
end

function W.Count()
    local s = store(false)
    return s and #s.list or 0
end

function W.Remove(id)
    local s = store(false)
    if not s then
        return false
    end
    local _, index = find(s, id)
    if not index then
        return false
    end
    table.remove(s.list, index)
    Z.MarkDirty('whispers')
    return true
end

function W.Clear()
    local s = store(false)
    if not s or #s.list == 0 then
        return false
    end
    s.list = {}
    Z.MarkDirty('whispers')
    return true
end

-- The group was closed: nothing stays.
function W.Reset()
    if Z.db and Z.db.whisperRequests then
        Z.db.whisperRequests = nil
        Z.MarkDirty('whispers')
    end
end

-- Invites the sender like the group search of the game does (only without a group or as its leader).
-- Returns true, or false and a message (a key of the interface texts).
function W.Invite(id)
    local s, g = store(false)
    local req = s and find(s, id)
    if not req then
        return false, 'Bewerbung nicht mehr aktiv.'
    end
    if req.state == 'joined' then
        return false, 'In group'
    end
    local state = A.GroupState()
    if g and state.total >= g.size then
        return false, 'Die Zielgröße ist bereits erreicht.'
    end
    local ok, err = A.InviteName(req.name)
    if not ok then
        return false, err
    end
    req.state = 'invited'
    Z.MarkDirty('whispers')
    return true
end

return W
