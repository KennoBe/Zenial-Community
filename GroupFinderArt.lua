-- Pictures for the group finder. Textures come from the user's game installation (and, for the new Forever
-- dungeons the client has no picture of, from an installed DungeonJournal); the addon ships none.
--
-- Order per activity: the client textures listed in GroupFinderCatalog, then the journal's picture, then
-- nothing. "Nothing" means the caller draws the neutral ZENIAL tile. A picture of another instance is never
-- substituted.
--
--   Art.Resolve(entry)                 -> { file, kind, coords?, source = 'client' | 'journal' } or nil
--   Art.Apply(texture, entry, aspect)  -> true when a picture was set (texture + crop for width / height)
--   Art.Report()                       -> rows { id, source, file } for diagnostics
local Z = ZenialCommunity
local Art = {}
Z.GroupFinderArt = Art

-- Visible part of each texture sort and the shape of the picture inside it.
--   lore    Adventure Guide lore art: 390 x 336 px inside a 512 x 512 texture
--   button  Adventure Guide dungeon button: 175 x 95 px inside a 256 x 128 texture
--   screen  classic loading screen, a 4:3 picture stretched over the whole texture
--   wide    wide loading screen, a 16:9 picture stretched over the whole texture
--   journal picture of DungeonJournal with that addon's own coordinates (shown there about 2.2 : 1)
local KINDS = {
    lore = { 0, 0.76171875, 0, 0.65625, 390 / 336 },
    button = { 0, 0.68359375, 0, 0.7421875, 175 / 95 },
    screen = { 0.02, 0.98, 0.04, 0.96, 4 / 3 },
    wide = { 0, 1, 0, 1, 16 / 9 },
}
local JOURNAL_ASPECT = 2.2
Art.KINDS = KINDS

-- Crop of a region { left, right, top, bottom } whose picture has `shape` (width / height) to `aspect`,
-- centred horizontally and at `focus` (0 top .. 1 bottom, default middle) vertically.
function Art.Crop(left, right, top, bottom, shape, aspect, focus)
    aspect = type(aspect) == 'number' and aspect > 0 and aspect or shape
    local width, height = right - left, bottom - top
    if aspect >= shape then
        local keep = height * shape / aspect
        local start = top + (height - keep) * (focus or 0.5)
        return left, right, start, start + keep
    end
    local keep = width * aspect / shape
    local start = left + (width - keep) / 2
    return start, start + keep, top, bottom
end

local function exists(file)
    if type(file) == 'number' then
        return file > 0
    end
    if type(file) ~= 'string' or file == '' then
        return false
    end
    -- Without the probe the path is taken as given; with it a path the client does not know is skipped.
    if type(GetFileIDFromPath) ~= 'function' then
        return true
    end
    local ok, id = pcall(GetFileIDFromPath, file)
    if not ok then
        return true
    end
    return type(id) == 'number' and id > 0
end

Art.cache = {}
function Art.Resolve(entry)
    if type(entry) ~= 'table' or not entry.id then
        return nil
    end
    local journal = Z.DungeonJournalLink
    local journalLoaded = journal ~= nil and journal.Available()
    local cached = Art.cache[entry.id]
    if cached and cached.journalLoaded == journalLoaded then
        return cached.art or nil
    end
    local art
    for _, candidate in ipairs(entry.art or {}) do
        if KINDS[candidate.kind] and exists(candidate.file) then
            art = { file = candidate.file, kind = candidate.kind, source = 'client' }
            break
        end
    end
    if not art and journalLoaded then
        local file, coords = journal.Art(entry.id)
        if file and exists(file) then
            art = { file = file, kind = 'journal', coords = coords, source = 'journal' }
        end
    end
    Art.cache[entry.id] = { art = art or false, journalLoaded = journalLoaded }
    return art
end

-- Texture coordinates of `art` for a frame of `aspect` (width / height).
function Art.Coords(art, aspect, focus)
    if art.kind == 'journal' then
        local c = art.coords or { 0, 1, 0, 1 }
        return Art.Crop(c[1], c[2], c[3], c[4], JOURNAL_ASPECT, aspect, focus)
    end
    local k = KINDS[art.kind]
    return Art.Crop(k[1], k[2], k[3], k[4], k[5], aspect, focus)
end

function Art.Apply(texture, entry, aspect, focus)
    local art = Art.Resolve(entry)
    if not art or not texture then
        return false
    end
    texture:SetTexture(art.file)
    if texture.SetTexCoord then
        texture:SetTexCoord(Art.Coords(art, aspect, focus))
    end
    return true, art
end

function Art.Report()
    local rows = {}
    local catalog = Z.GroupFinderCatalog
    for id, entry in pairs(catalog and catalog.entries or {}) do
        local art = Art.Resolve(entry)
        rows[#rows + 1] = { id = id, source = art and art.source or 'none', file = art and art.file or nil, listed = #(entry.art or {}) }
    end
    table.sort(rows, function(a, b)
        return a.id < b.id
    end)
    return rows
end

return Art
