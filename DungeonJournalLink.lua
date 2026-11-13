-- Optional link to the addon "DungeonJournal" by Exehn (folder ForeverDungeonJournal). ZENIAL Community
-- organises groups; bosses, loot and guides stay in that addon. Nothing here is required: without the
-- journal every function reports "not available" and the finder hides its button.
--
-- Contract (read from DungeonJournal 2.0.3, the same calls OpenMap and Ginvite make):
--   _G.ForeverDungeonJournal_NS            namespace table, set while the addon loads
--   NS.DB[key]                             the journal's dungeons, keyed by their English name
--   NS.OpenBossPage(key)                   selects that dungeon; an unknown key returns silently
--   _G.ForeverDungeonJournalFrame          the window
--   _G.ForeverDungeonJournal_Toggle()      shows / hides the window (NS.ToggleJournal is the same function)
-- The key of an activity is fixed in GroupFinderCatalog (entry.journal); names are never guessed, so a
-- wrong dungeon cannot open. Every foreign call runs in pcall.
local Z = ZenialCommunity
local J = {}
Z.DungeonJournalLink = J

local function namespace()
    local ns = rawget(_G, 'ForeverDungeonJournal_NS')
    if type(ns) == 'table' and type(ns.DB) == 'table' and type(ns.OpenBossPage) == 'function' then
        return ns
    end
end

function J.Available()
    return namespace() ~= nil
end

function J.Key(activity)
    local e = Z.GroupFinderCatalog and Z.GroupFinderCatalog.Get(activity)
    return e and e.journal or nil
end

-- True when the installed journal has a page for this activity.
function J.Knows(activity)
    local ns, key = namespace(), J.Key(activity)
    return ns ~= nil and key ~= nil and ns.DB[key] ~= nil
end

-- Opens the journal on the page of `activity`. Returns true, or false and one of
-- 'missing' (journal not installed), 'unknown' (no page for this activity), 'failed' (the journal raised an error).
function J.Open(activity)
    local ns = namespace()
    if not ns then
        return false, 'missing'
    end
    local key = J.Key(activity)
    if not key or ns.DB[key] == nil then
        return false, 'unknown'
    end
    -- Show the window first: showing it restores the page it was last on, the page call then replaces that.
    local frame = rawget(_G, 'ForeverDungeonJournalFrame')
    local shown = false
    if type(frame) == 'table' and type(frame.IsShown) == 'function' then
        local ok, value = pcall(frame.IsShown, frame)
        shown = ok and value == true
    end
    if not shown then
        local toggle = rawget(_G, 'ForeverDungeonJournal_Toggle')
        if type(toggle) ~= 'function' then
            toggle = ns.ToggleJournal
        end
        if type(toggle) ~= 'function' or not pcall(toggle) then
            return false, 'failed'
        end
    end
    if not pcall(ns.OpenBossPage, key) then
        return false, 'failed'
    end
    return true
end

-- Picture the journal itself shows for this activity: texture (path or file id) and its texture
-- coordinates { left, right, top, bottom }. Only a reference into the user's installation.
function J.Art(activity)
    local ns, key = namespace(), J.Key(activity)
    if not ns or not key or ns.DB[key] == nil or type(ns.DUNGEON_HOME_ART) ~= 'table' then
        return nil
    end
    local file = ns.DUNGEON_HOME_ART[key]
    if type(file) ~= 'string' and type(file) ~= 'number' then
        return nil
    end
    if file == '' or file == 0 then
        return nil
    end
    local coords = type(ns.DUNGEON_HOME_TEXCOORD) == 'table' and ns.DUNGEON_HOME_TEXCOORD[key] or nil
    if type(coords) == 'table' then
        for index = 1, 4 do
            if type(coords[index]) ~= 'number' or coords[index] < 0 or coords[index] > 1 then
                coords = nil
                break
            end
        end
    else
        coords = nil
    end
    return file, coords
end

return J
