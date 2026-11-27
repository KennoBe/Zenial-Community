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

return W
