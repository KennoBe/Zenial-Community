-- Public group search: contacting the leader of a public group, and remembering whom the player contacted.
--
-- The group search of this client has no applications: one whispers the leader. This module prepares the
-- whisper (the chat box opens with a short text, the player sends it) and keeps a small record per
-- character, so a group is not written to twice and the finder can say "chat opened", "message sent" or
-- "in the group". It never sends anything by itself and never claims more than it saw:
--   OPENED  the chat box was opened with the text
--   SENT    the client reported the player's own whisper to that leader
--   JOINED  the leader is in the player's group
-- The record lives in the saved variable ZenialPublicLFGDB, apart from the applications of ZENIAL groups,
-- and is never sent to other players or exported. Result ids are not stored: they change with every search.
local Z = ZenialCommunity
local L, A = Z.Logic, Z.Adapter
local X = {}
Z.PublicLFGContact = X

local LOCK, KEEP, LIMIT, WATCH = 1800, 86400, 50, 600
local STATES = { OPENED = true, SENT = true, JOINED = true }
X.LOCK, X.KEEP, X.LIMIT = LOCK, KEEP, LIMIT

-- Texts that go to another player. They are written in the language of the listing, not of the interface.
local TEXT = {
    de = { group = 'Hi, ich bin %s, Level %d. Habt ihr noch einen Platz frei?', solo = 'Hi, wir suchen noch jemanden für %s. Hast du Lust?',
        TANK = 'Tank', HEALER = 'Heiler', DAMAGER = 'DD', join = ' oder ' },
    en = { group = "Hi, I'm a level %d %s. Do you still have a spot available?", levelFirst = true,
        solo = 'Hi, we are looking for one more for %s. Are you interested?', TANK = 'tank', HEALER = 'healer', DAMAGER = 'DPS', join = ' or ' },
}
local ORDER = { 'TANK', 'HEALER', 'DAMAGER' }

local contacts = {}

local function identity(name)
    if not A.Safe(name) or type(name) ~= 'string' then
        return nil
    end
    return (L.Identity(name))
end

-- Loads and cleans the record of this character: valid entries of the last day, the newest fifty.
function X.Initialize()
    contacts = {}
    if not Z.storageKey then
        return
    end
    if type(ZenialPublicLFGDB) ~= 'table' then
        ZenialPublicLFGDB = {}
    end
    local root = ZenialPublicLFGDB
    root.v = 1
    if type(root.characters) ~= 'table' then
        root.characters = {}
    end
    local own = type(root.characters[Z.storageKey]) == 'table' and root.characters[Z.storageKey] or {}
    local now, kept = A.Now(), {}
    for _, entry in ipairs(type(own.contacts) == 'table' and own.contacts or {}) do
        if type(entry) == 'table' and STATES[entry.state] and L.Int(entry.at, 1, 4102444800) and now - entry.at <= KEEP and entry.at <= now + 300
            and L.Text(entry.leader, 113) and identity(entry.leader) and (entry.guid == nil or L.Text(entry.guid, 80)) then
            kept[#kept + 1] = { leader = entry.leader, key = identity(entry.leader), guid = entry.guid, state = entry.state, at = entry.at }
        end
    end
    table.sort(kept, function(a, b) return a.at > b.at end)
    for index = LIMIT + 1, #kept do
        kept[index] = nil
    end
    contacts = kept
    root.characters[Z.storageKey] = { contacts = contacts }
end

-- The entry of a row: by the id of its party, otherwise by its leader.
local function find(row)
    local key = identity(row.leader)
    for _, entry in ipairs(contacts) do
        if (row.partyGuid and entry.guid == row.partyGuid) or (key and entry.key == key) then
            return entry
        end
    end
    return nil
end

-- 'NONE' | 'OPENED' | 'SENT' | 'JOINED'
function X.State(row)
    local entry = find(row)
    return entry and entry.state or 'NONE'
end

function X.Contacted(row)
    return find(row) ~= nil
end

-- Whether the leader may be written to now: there is a name, the listing is up, and the last contact with
-- this leader is at least half an hour ago. Reasons: NO_LEADER, GONE, LOCKED.
function X.CanContact(row)
    if not identity(row.leader) then
        return false, 'NO_LEADER'
    end
    if row.delisted then
        return false, 'GONE'
    end
    local entry = find(row)
    if entry and A.Now() - entry.at < LOCK then
        return false, 'LOCKED'
    end
    return true
end

local function record(row, state)
    local entry = find(row)
    if not entry then
        entry = { leader = row.leader, key = identity(row.leader) }
        table.insert(contacts, 1, entry)
        for index = LIMIT + 1, #contacts do
            contacts[index] = nil
        end
    end
    entry.guid, entry.state, entry.at = row.partyGuid or entry.guid, state, A.Now()
    return entry
end

-- 'de' or 'en' for the text: the chosen override, the one language that was searched, otherwise the
-- language of the interface.
function X.Language(searched)
    if X.language == 'de' or X.language == 'en' then
        return X.language
    end
    local one, count = nil, 0
    for code, on in pairs(type(searched) == 'table' and searched.mode == 'CUSTOM' and searched.codes or {}) do
        if on == true then
            one, count = code, count + 1
        end
    end
    local code = count == 1 and one or (type(GetLocale) == 'function' and GetLocale()) or 'enUS'
    return type(code) == 'string' and code:sub(1, 2) == 'de' and 'de' or 'en'
end

-- The standard text. kind 'group': to the leader of a group, with the player's roles and level.
-- kind 'solo': to a single player, with the name of the activity. me = { roles, level, activity }.
function X.DefaultText(language, kind, me)
    local t = TEXT[language == 'de' and 'de' or 'en']
    if kind == 'solo' then
        return string.format(t.solo, tostring(me.activity or '?'))
    end
    local roles = {}
    for _, role in ipairs(ORDER) do
        if me.roles and me.roles[role] then
            roles[#roles + 1] = t[role]
        end
    end
    local role, level = #roles > 0 and table.concat(roles, t.join) or t.DAMAGER, tonumber(me.level) or 1
    if t.levelFirst then
        return string.format(t.group, level, role)
    end
    return string.format(t.group, role, level)
end

-- The text for a contact: the player's own wording for that language when there is one, else the standard.
function X.Template(language, kind, me)
    local saved = Z.ui and type(Z.ui.finderTemplates) == 'table' and Z.ui.finderTemplates[language == 'de' and 'de' or 'en'] or nil
    if kind ~= 'solo' and L.Text(saved, 255) then
        return saved
    end
    return X.DefaultText(language, kind, me)
end

-- Keeps the player's own wording for a language; the standard text (or nothing) removes it again.
function X.SetTemplate(language, text, me)
    if not Z.ui then
        return
    end
    language = language == 'de' and 'de' or 'en'
    local templates = type(Z.ui.finderTemplates) == 'table' and Z.ui.finderTemplates or {}
    templates[language] = L.Text(text, 255) and text ~= X.DefaultText(language, 'group', me) and text or nil
    Z.ui.finderTemplates = templates
end

-- Opens the chat box for the leader of the row with the text in it. Nothing is sent: the player does that.
-- Returns true, or false and NO_LEADER | GONE | LOCKED | UNAVAILABLE.
function X.Prepare(row, text)
    local ok, reason = X.CanContact(row)
    if not ok then
        return false, reason
    end
    if not A.Whisper(row.leader, text) then
        return false, 'UNAVAILABLE'
    end
    record(row, 'OPENED')
    Z.MarkDirty()
    return true
end

-- Names of the players in the own group, as identity keys.
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

-- CHAT_MSG_WHISPER_INFORM: the client reports a whisper of the player. GROUP_ROSTER_UPDATE: the group changed.
function X.OnEvent(event, ...)
    if #contacts == 0 then
        return
    end
    local changed, now = false, A.Now()
    if event == 'CHAT_MSG_WHISPER_INFORM' then
        local _, target = ...
        local key = identity(target)
        for _, entry in ipairs(contacts) do
            if key and entry.key == key and entry.state == 'OPENED' and now - entry.at <= WATCH then
                entry.state, changed = 'SENT', true
            end
        end
    elseif event == 'GROUP_ROSTER_UPDATE' then
        local members = groupKeys()
        for _, entry in ipairs(contacts) do
            if members[entry.key] and entry.state ~= 'JOINED' then
                entry.state, changed = 'JOINED', true
            end
        end
    end
    if changed then
        Z.MarkDirty()
    end
end

-- Number of remembered contacts (for tests and diagnostics).
function X.Count()
    return #contacts
end

return X
