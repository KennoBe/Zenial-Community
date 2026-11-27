-- Whisper texts of the player for the public group search: the texts to the leader of a group ('group') and
-- to a single player ('solo'), with placeholders that are filled when the chat box opens.
--
-- Placeholders: {level} {role} {class} {dungeon} {me} {name}. They are filled in the language of the text
-- ('de' or 'en'), never in the language of the client, so an English text says "Warrior" on a German client.
-- An unknown placeholder stays as it is; a missing value leaves nothing behind. Nothing here sends anything.
-- See _dev/addons/ZenialCommunity/WHISPER-DESIGNER-DESIGN.md.
local Z = ZenialCommunity
local L, X = Z.Logic, Z.PublicLFGContact
local W = {}
Z.WhisperTexts = W

W.KINDS = { 'group', 'solo' }
W.MAX_TEXTS, W.MAX_NAME, W.MAX_TEXT = 12, 32, 255

-- The texts of a first start, the same wording as the standard texts of PublicLFGContact.
W.SEED = {
    group = { de = 'Hi, ich bin {role}, Level {level}. Habt ihr noch einen Platz frei?', en = "Hi, I'm a level {level} {role}. Do you still have a spot available?" },
    solo = { de = 'Hi, wir suchen noch jemanden für {dungeon}. Hast du Lust?', en = 'Hi, we are looking for one more for {dungeon}. Are you interested?' },
}

-- The insert buttons of the designer, in their order. The label of {name} depends on the kind.
W.VARIABLES = {
    { key = 'level', label = 'Level' },
    { key = 'role', label = 'Role' },
    { key = 'class', label = 'Class' },
    { key = 'dungeon', label = 'Dungeon' },
    { key = 'me', label = 'My name' },
    { key = 'name', label = { group = 'Leader', solo = 'Player' } },
}

local function roles(language, wanted)
    local words, out = X.WORDS[language], {}
    for _, role in ipairs(X.ROLE_ORDER) do
        if type(wanted) == 'table' and wanted[role] then
            out[#out + 1] = words[role]
        end
    end
    return #out > 0 and table.concat(out, words.join) or nil
end

local FILL = {
    level = function(_, v) return tonumber(v.level) and tostring(math.floor(v.level)) or nil end,
    role = function(language, v) return roles(language, v.roles) end,
    class = function(language, v) return Z.Locale.ClassIn(language, v.classFile) end,
    dungeon = function(language, v) return v.activity and Z.Locale.ActivityIn(language, v.activity) or nil end,
    me = function(_, v) return type(v.me) == 'string' and v.me or nil end,
    name = function(_, v) return type(v.name) == 'string' and v.name or nil end,
}

-- The text with its placeholders filled. values = { level, roles, classFile, activity, me, name }.
function W.Expand(text, language, values)
    language = language == 'de' and 'de' or 'en'
    values = type(values) == 'table' and values or {}
    local out = tostring(text or ''):gsub('{(%a+)}', function(key)
        local fill = FILL[key]
        if not fill then
            return nil
        end
        return fill(language, values) or ''
    end)
    return (out:gsub('  +', ' '):gsub('^ +', ''):gsub(' +$', ''))
end

-- At most 255 bytes, cut before a character that would not fit whole.
function W.Fit(text)
    text = tostring(text or '')
    if #text <= W.MAX_TEXT then
        return text
    end
    local cut = W.MAX_TEXT
    while cut > 0 do
        local next = text:byte(cut + 1)
        if not next or next < 0x80 or next >= 0xC0 then
            break
        end
        cut = cut - 1
    end
    return text:sub(1, cut)
end

-- Storage: Z.ui.whisperTexts = { group = { list = { { id, name, text, language }, ... }, last = id }, solo = ... }.
local function section(kind)
    local store = Z.ui and Z.ui.whisperTexts
    return store and store[kind == 'solo' and 'solo' or 'group'] or { list = {} }
end

-- The two texts of a first start. Own wordings of the old single message per language replace the standard.
local function seed(kind, own)
    local list = {}
    for index, language in ipairs({ 'de', 'en' }) do
        local text = own and own[language] or W.SEED[kind][language]
        list[index] = { id = index, name = language == 'de' and 'Deutsch' or 'English', text = text, language = language }
    end
    local preferred = X.Language(Z.uiCharacter and Z.uiCharacter.finderLanguages)
    return { list = list, last = preferred == 'de' and 1 or 2 }
end

-- Called once the saved settings are loaded: fills empty lists and moves the old own wordings over.
function W.Ensure()
    if not Z.ui then
        return
    end
    local store = type(Z.ui.whisperTexts) == 'table' and Z.ui.whisperTexts or {}
    for _, kind in ipairs(W.KINDS) do
        if type(store[kind]) ~= 'table' or type(store[kind].list) ~= 'table' or #store[kind].list == 0 then
            store[kind] = seed(kind, kind == 'group' and Z.ui.finderTemplates or nil)
        end
    end
    Z.ui.whisperTexts = store
    Z.ui.finderTemplates = nil
end

function W.List(kind)
    return section(kind).list
end

function W.Get(kind, id)
    for _, entry in ipairs(W.List(kind)) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

-- The text used when nothing else is chosen: the last one used, otherwise the first.
function W.Last(kind)
    local s = section(kind)
    return W.Get(kind, s.last) or s.list[1]
end

function W.SetLast(kind, id)
    if W.Get(kind, id) then
        section(kind).last = id
    end
end

-- A new empty text in the language of the current one, or nil when the list is full.
function W.Add(kind)
    local list = W.List(kind)
    if #list >= W.MAX_TEXTS or not (Z.ui and Z.ui.whisperTexts) then
        return nil
    end
    local high = 0
    for _, entry in ipairs(list) do
        high = math.max(high, entry.id)
    end
    local current = W.Last(kind)
    local entry = { id = high + 1, name = Z.T('New text'), text = '', language = current and current.language or 'en' }
    list[#list + 1] = entry
    return entry
end

-- Changes name, text or language. Nothing is changed when one of the given fields is not valid.
function W.Update(kind, id, fields)
    local entry = W.Get(kind, id)
    if not entry or type(fields) ~= 'table' then
        return false
    end
    if fields.name ~= nil and not L.Text(fields.name, W.MAX_NAME) then
        return false
    end
    if fields.text ~= nil and not L.Text(fields.text, W.MAX_TEXT, true) then
        return false
    end
    if fields.language ~= nil and fields.language ~= 'de' and fields.language ~= 'en' then
        return false
    end
    entry.name = fields.name or entry.name
    entry.text = fields.text or entry.text
    entry.language = fields.language or entry.language
    return true
end

-- Removes a text; the last one of a kind stays.
function W.Remove(kind, id)
    local list = W.List(kind)
    if #list <= 1 then
        return false
    end
    for index, entry in ipairs(list) do
        if entry.id == id then
            table.remove(list, index)
            return true
        end
    end
    return false
end

return W
