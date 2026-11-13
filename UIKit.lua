-- ZENIAL Community component kit. Small building blocks on top of the skin (ThemeCommunity.lua) and the
-- tokens (ThemeTokens.lua). Every block is a plain frame with a few documented methods; nothing here
-- knows about pages, data or navigation. Colours are palette keys, sizes are token roles.
--
--   K.Text(parent, text, role[, colorKey])        font string in a T.type role
--   K.Icon(parent, name, size[, colorKey])        atlas icon texture (T.iconCells)
--   K.Card(parent[, kind])                        panel: "surface" | "raised" | "inset" | "canvas"
--   K.Accent(frame[, colorKey])                   3px bar on the left edge of a card / row
--   K.Corners(frame[, colorKey, size])            four small corner brackets (hero cards)
--   K.SectionHeader(parent, text)                 upper-case label, hairline, optional count
--   K.Badge(parent, text[, tone])                 pill: neutral | gold | info | success | warning | danger
--   K.IconButton(parent, name, size, onClick[, tooltip])
--   K.StatTile(parent, opts)                      clickable number + label (+ icon)
--   K.EmptyState(parent, opts)                    icon, title, hint for empty / loading / error
--   K.Dot(parent[, colorKey, size])               status dot
local Z = ZenialCommunity
local T = Z and Z.Theme
if type(T) ~= "table" or type(T.Font) ~= "function" then return end
local K = {}
Z.Kit = K

local function call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return false end
    return pcall(fn, object, ...)
end
local function backdropFrame(kind, parent)
    return CreateFrame(kind, nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
end

-- Upper case including the German umlauts (string.upper is byte based).
local UPPER = { ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü" }
function K.Upper(value)
    value = string.upper(tostring(value or ""))
    for lower, upper in pairs(UPPER) do value = value:gsub(lower, upper) end
    return value
end

function K.Text(parent, value, role, colorKey)
    local spec = T.type[role] or T.type.body
    local base = spec.size >= 16 and "GameFontNormalLarge" or spec.size <= 11 and "GameFontHighlightSmall" or "GameFontHighlight"
    local fs = T.Text(parent, value or "", base)
    T.Font(fs, role, colorKey)
    fs.zenialRole = role
    return fs
end

function K.Icon(parent, name, size, colorKey)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size or 16, size or 16)
    T.SetIcon(texture, name, colorKey or "dim")
    return texture
end

function K.Dot(parent, colorKey, size)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size or 8, size or 8)
    T.SetIcon(texture, "dot", colorKey or "online")
    return texture
end

-- ---------------------------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------------------------
function K.Card(parent, kind)
    local card = backdropFrame("Frame", parent)
    T.Panel(card, kind or "surface")
    card.zenialCard = kind or "surface"
    if kind ~= "inset" and kind ~= "canvas" then
        -- A lighter hairline under the top edge reads as a soft bevel.
        local bevel = card:CreateTexture(nil, "BORDER")
        bevel:SetPoint("TOPLEFT", 1, -1); bevel:SetPoint("TOPRIGHT", -1, -1); bevel:SetHeight(1)
        T.Tint(bevel, "SetColorTexture", "highlight", .28)
        card.bevel = bevel
    end
    return card
end

function K.Accent(frame, colorKey)
    if not frame.zenialAccent then
        local bar = frame:CreateTexture(nil, "OVERLAY")
        bar:SetPoint("TOPLEFT", 0, 0); bar:SetPoint("BOTTOMLEFT", 0, 0); bar:SetWidth(3)
        frame.zenialAccent = bar
    end
    T.Tint(frame.zenialAccent, "SetColorTexture", colorKey or "gold")
    frame.zenialAccent:Show()
    return frame.zenialAccent
end

function K.Corners(frame, colorKey, size)
    if frame.zenialCorners then return frame.zenialCorners end
    size = size or 10
    local set = {}
    for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local horizontal, vertical = frame:CreateTexture(nil, "OVERLAY"), frame:CreateTexture(nil, "OVERLAY")
        horizontal:SetPoint(corner[1], 0, 0); horizontal:SetSize(size, 1)
        vertical:SetPoint(corner[1], 0, 0); vertical:SetSize(1, size)
        T.Tint(horizontal, "SetColorTexture", colorKey or "goldDim"); T.Tint(vertical, "SetColorTexture", colorKey or "goldDim")
        set[#set + 1] = horizontal; set[#set + 1] = vertical
    end
    frame.zenialCorners = set
    return set
end

-- ---------------------------------------------------------------------------------------------
-- Section header: OVERLINE ───────────── count
-- ---------------------------------------------------------------------------------------------
function K.SectionHeader(parent, value)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(16)
    header.label = K.Text(header, K.Upper(value), "overline", "goldDim")
    header.label:SetPoint("LEFT", 0, 0); header.label:SetHeight(12); call(header.label, "SetWordWrap", false)
    header.count = K.Text(header, "", "overline", "muted")
    header.count:SetPoint("RIGHT", 0, 0); header.count:SetHeight(12); header.count:SetJustifyH("RIGHT")
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetHeight(1)
    header.line:SetPoint("LEFT", header.label, "RIGHT", 10, 0); header.line:SetPoint("RIGHT", header.count, "LEFT", -10, 0)
    T.Tint(header.line, "SetColorTexture", "line")
    local function fit(fs, text)
        local measured = fs.GetStringWidth and fs:GetStringWidth()
        fs:SetWidth(math.max(1, (type(measured) == "number" and measured or #text * 6) + 2))
    end
    function header:SetText(text) text = K.Upper(text); self.label:SetText(text); fit(self.label, text) end
    function header:SetCount(text)
        text = text and tostring(text) or ""
        self.count:SetText(text); fit(self.count, text)
    end
    header:SetText(value or ""); header:SetCount("")
    return header
end

-- ---------------------------------------------------------------------------------------------
-- Badge
-- ---------------------------------------------------------------------------------------------
local TONES = {
    neutral = { "neutralBg", "line", "textSoft" }, gold = { "chipOnBg", "chipOnEdge", "chipOnText" },
    info = { "accentBlueBg", "accentBlueEdge", "accentBlue" }, success = { "toastBg", "toastEdge", "toastText" },
    warning = { "warningBg", "warningEdge", "warning" }, danger = { "dangerBg", "dangerEdge", "dangerText" },
}
function K.Badge(parent, value, tone)
    local spec = TONES[tone or "neutral"] or TONES.neutral
    local badge = T.CreateTag(parent, spec[1], spec[2], spec[3])
    badge:SetHeight(18)
    function badge:SetTone(name)
        local s = TONES[name] or TONES.neutral
        T.Tint(self.fill, "SetColorTexture", s[1]); T.TintEdges(self.edges, s[2]); T.Tint(self.text, "SetTextColor", s[3])
        self.zenialTone = name
    end
    badge.zenialTone = tone or "neutral"
    badge:SetLabel(value or "")
    return badge
end

-- ---------------------------------------------------------------------------------------------
-- Icon button (square, frameless until hovered)
-- ---------------------------------------------------------------------------------------------
function K.IconButton(parent, name, size, onClick, tooltip)
    local button = CreateFrame("Button", nil, parent)
    size = size or 28
    button:SetSize(size, size)
    button.hover = button:CreateTexture(nil, "BACKGROUND"); button.hover:SetAllPoints()
    T.Tint(button.hover, "SetColorTexture", "hover", .09); button.hover:Hide()
    button.icon = K.Icon(button, name, math.floor(size * .6 + .5), "textSoft"); button.icon:SetPoint("CENTER")
    button.zenialTooltip = tooltip
    button:SetScript("OnEnter", function(self)
        self.hover:Show(); T.Tint(self.icon, "SetVertexColor", "goldBright")
        if self.zenialTooltip and GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(self.zenialTooltip); GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hover:Hide(); T.Tint(self.icon, "SetVertexColor", self.zenialIconColor or "textSoft")
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
    button:SetScript("OnClick", onClick or function() end)
    function button:SetIconColor(colorKey) self.zenialIconColor = colorKey; T.Tint(self.icon, "SetVertexColor", colorKey or "textSoft") end
    return button
end

-- ---------------------------------------------------------------------------------------------
-- Stat tile: icon, large value, caption. opts = { icon, label, value, onClick, tooltip }
-- ---------------------------------------------------------------------------------------------
function K.StatTile(parent, opts)
    opts = opts or {}
    local tile = backdropFrame("Button", parent)
    T.Panel(tile, "surface")
    tile:SetSize(opts.width or 160, opts.height or 64)
    tile.hover = tile:CreateTexture(nil, "BORDER"); tile.hover:SetPoint("TOPLEFT", 1, -1); tile.hover:SetPoint("BOTTOMRIGHT", -1, 1)
    T.Tint(tile.hover, "SetColorTexture", "hover"); tile.hover:Hide()
    if opts.icon then
        tile.icon = K.Icon(tile, opts.icon, 20, "goldDim"); tile.icon:SetPoint("TOPRIGHT", -12, -12)
    end
    tile.value = K.Text(tile, opts.value or "0", "value"); tile.value:SetPoint("TOPLEFT", 14, -10); tile.value:SetHeight(26)
    call(tile.value, "SetWordWrap", false)
    tile.label = K.Text(tile, opts.label or "", "caption"); tile.label:SetPoint("BOTTOMLEFT", 14, 10); tile.label:SetPoint("BOTTOMRIGHT", -12, 10)
    tile.label:SetHeight(13); call(tile.label, "SetWordWrap", false)
    function tile:SetValue(value, colorKey)
        self.value:SetText(tostring(value or "0")); T.Tint(self.value, "SetTextColor", colorKey or "text")
    end
    function tile:SetLabel(value) self.label:SetText(value or "") end
    tile:SetScript("OnEnter", function(self)
        if not self.zenialClickable then return end
        self.hover:Show(); T.Tint(self, "SetBackdropBorderColor", "goldDim")
    end)
    tile:SetScript("OnLeave", function(self) self.hover:Hide(); T.Tint(self, "SetBackdropBorderColor", "line") end)
    function tile:SetAction(fn)
        self.zenialClickable = fn ~= nil
        self:SetScript("OnClick", fn or function() end)
    end
    tile:SetAction(opts.onClick)
    return tile
end

-- ---------------------------------------------------------------------------------------------
-- Empty / loading / error state. opts = { icon, title, hint, width }
-- ---------------------------------------------------------------------------------------------
function K.EmptyState(parent, opts)
    opts = opts or {}
    local state = CreateFrame("Frame", nil, parent)
    state:SetSize(opts.width or 320, 96)
    state.icon = K.Icon(state, opts.icon or "info", 28, "muted"); state.icon:SetPoint("TOP", 0, 0)
    state.title = K.Text(state, opts.title or "", "heading", "textSoft")
    state.title:SetPoint("TOPLEFT", 0, -36); state.title:SetPoint("TOPRIGHT", 0, -36); state.title:SetJustifyH("CENTER"); state.title:SetHeight(16)
    state.hint = K.Text(state, opts.hint or "", "caption", "dim")
    state.hint:SetPoint("TOPLEFT", 0, -56); state.hint:SetPoint("TOPRIGHT", 0, -56); state.hint:SetJustifyH("CENTER"); state.hint:SetHeight(40)
    function state:SetState(title, hint, icon, colorKey)
        self.title:SetText(title or ""); self.hint:SetText(hint or "")
        if icon then T.SetIcon(self.icon, icon, colorKey or "muted") end
    end
    return state
end

return K
