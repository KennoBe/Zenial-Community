-- Community-only theme data layered on the shared Theme (_dev/shared/Theme.lua).
-- Loaded directly after Theme.lua; no other addon uses these navigation or profession icons or this skin.
local Z = ZenialCommunity
local T = Z and Z.Theme
if type(T) ~= "table" or type(T.assets) ~= "table" then return end

local icons = T.assets.icons
for key, path in pairs({
    members = "Interface\\Icons\\INV_Misc_GroupLooking",
    crafting = "Interface\\Icons\\Trade_BlackSmithing",
    groups = "Interface\\LFGFrame\\UI-LFG-PORTRAIT",
    quests = "Interface\\GossipFrame\\AvailableQuestIcon",
    trade = "Interface\\Icons\\INV_Misc_Coin_01",
    profile = "Interface\\Icons\\INV_Misc_GroupLooking",
}) do icons[key] = path end

T.assets.professions = {
    ["Alchemie"]="Interface\\Icons\\Trade_Alchemy", ["Alchimie"]="Interface\\Icons\\Trade_Alchemy", ["Alchemy"]="Interface\\Icons\\Trade_Alchemy",
    ["Schmiedekunst"]="Interface\\Icons\\Trade_BlackSmithing", ["Blacksmithing"]="Interface\\Icons\\Trade_BlackSmithing",
    ["Verzauberkunst"]="Interface\\Icons\\Trade_Engraving", ["Enchanting"]="Interface\\Icons\\Trade_Engraving",
    ["Ingenieurskunst"]="Interface\\Icons\\Trade_Engineering", ["Engineering"]="Interface\\Icons\\Trade_Engineering",
    ["Kräuterkunde"]="Interface\\Icons\\Trade_Herbalism", ["Herbalism"]="Interface\\Icons\\Trade_Herbalism",
    ["Lederverarbeitung"]="Interface\\Icons\\Trade_LeatherWorking", ["Leatherworking"]="Interface\\Icons\\Trade_LeatherWorking",
    ["Bergbau"]="Interface\\Icons\\Trade_Mining", ["Mining"]="Interface\\Icons\\Trade_Mining",
    ["Kürschnerei"]="Interface\\Icons\\INV_Misc_Pelt_Wolf_01", ["Skinning"]="Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    ["Schneiderei"]="Interface\\Icons\\Trade_Tailoring", ["Tailoring"]="Interface\\Icons\\Trade_Tailoring",
    ["Kochkunst"]="Interface\\Icons\\INV_Misc_Food_15",["Kochen"]="Interface\\Icons\\INV_Misc_Food_15", ["Cooking"]="Interface\\Icons\\INV_Misc_Food_15",
    ["Erste Hilfe"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice", ["First Aid"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Angeln"]="Interface\\Icons\\Trade_Fishing", ["Fishing"]="Interface\\Icons\\Trade_Fishing",
}

function T.ProfessionIcon(name) return name and T.assets.professions[name] or nil end

-- ---------------------------------------------------------------------------------------------
-- Community skin. Redraws the shared widgets (shell, panels, buttons, navigation, rows, inputs) with
-- the named palette of the shared Theme so every page inherits the new look. All colours below are
-- palette keys; a different hue is a change to T.palette only. Newer client APIs (SetGradient,
-- AnimationGroup, CreateFont, SetBlendMode) are probed and each has a static fallback.
-- ---------------------------------------------------------------------------------------------
if type(T.palette) ~= "table" or type(T.PaletteColor) ~= "function" then return end

local FLAT = "Interface\\Buttons\\WHITE8X8"
T.assets.flat = FLAT
T.animation = { pageRise = 6, pageDuration = .16, navDuration = .22, pressScale = .97 }
-- Set while the window is being built: nothing animates then (the frame is still "shown" during Create).
T.suppressMotion = false

-- Calls an optional widget method; false when the client lacks it or it raises.
local function call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return false end
    return pcall(fn, object, ...)
end

local function hook(frame, event, fn)
    if not frame then return end
    if frame.HookScript then frame:HookScript(event, fn); return end
    if not frame.SetScript then return end
    local previous = frame.GetScript and frame:GetScript(event)
    frame:SetScript(event, function(...) if previous then previous(...) end; fn(...) end)
end

local function tint(region, method, key, alpha) return T.Tint(region, method, key, alpha) end

-- Existing consumers read T.colors; re-derive them from the palette.
local function setColor(name, key, alpha) T.colors[name] = { T.PaletteColor(key, alpha) } end
setColor("shell", "bg", .995); setColor("sidebar", "side", .995); setColor("surface", "panel", .985)
setColor("inset", "inset", .99); setColor("parchment", "panel", .98); setColor("border", "edge")
setColor("borderSoft", "line"); setColor("gold", "gold"); setColor("text", "text"); setColor("muted", "dim")
setColor("red", "dangerBottom", .9); setColor("redHover", "dangerTop", .9); setColor("green", "online")
setColor("danger", "danger"); setColor("blue", "accentBlueEdge", .62); setColor("disabled", "disabled", .94)

-- ---------------------------------------------------------------------------------------------
-- Flat 1px frames (backdrop with the client's white texture) and plain texture borders
-- ---------------------------------------------------------------------------------------------
local function flatBackdrop(frame, fillKey, fillAlpha, edgeKey, edgeAlpha)
    if not frame or not frame.SetBackdrop then return frame end
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    tint(frame, "SetBackdropColor", fillKey, fillAlpha)
    tint(frame, "SetBackdropBorderColor", edgeKey, edgeAlpha)
    return frame
end

local PANELS = { shell = { "bg", .995, "edge" }, sidebar = { "side", .995, "line" }, surface = { "panel", .985, "line" },
    inset = { "inset", .99, "line" }, parchment = { "panel", .98, "line" } }
function T.Panel(frame, kind)
    local spec = PANELS[kind or "surface"] or PANELS.surface
    return flatBackdrop(frame, spec[1], spec[2], spec[3])
end

function T.Shell(frame)
    flatBackdrop(frame, "bg", .995, "edge")
    if not frame or frame.zenialShellSkin then return frame end
    local skin = {}; frame.zenialShellSkin = skin
    skin.title = frame:CreateTexture(nil, "BORDER")
    skin.title:SetPoint("TOPLEFT", 1, -1); skin.title:SetPoint("TOPRIGHT", -1, -1); skin.title:SetHeight(69)
    T.SetGradient(skin.title, "VERTICAL", "panelRaised", "bg")
    skin.top = frame:CreateTexture(nil, "ARTWORK")
    skin.top:SetPoint("TOPLEFT", 1, -70); skin.top:SetPoint("TOPRIGHT", -1, -70); skin.top:SetHeight(1)
    tint(skin.top, "SetColorTexture", "edgeDeep")
    return frame
end

-- Four 1px edge textures; returns them keyed top/bottom/left/right.
local function edges(parent, layer)
    local set = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do set[side] = parent:CreateTexture(nil, layer or "BORDER") end
    set.top:SetPoint("TOPLEFT"); set.top:SetPoint("TOPRIGHT"); set.top:SetHeight(1)
    set.bottom:SetPoint("BOTTOMLEFT"); set.bottom:SetPoint("BOTTOMRIGHT"); set.bottom:SetHeight(1)
    set.left:SetPoint("TOPLEFT"); set.left:SetPoint("BOTTOMLEFT"); set.left:SetWidth(1)
    set.right:SetPoint("TOPRIGHT"); set.right:SetPoint("BOTTOMRIGHT"); set.right:SetWidth(1)
    return set
end
local function tintEdges(set, key, alpha) for _, texture in pairs(set) do tint(texture, "SetColorTexture", key, alpha) end end
T.Edges, T.TintEdges = edges, tintEdges

-- ---------------------------------------------------------------------------------------------
-- Class colours (RAID_CLASS_COLORS / C_ClassColor, probed) -- nil when the class is not known
-- ---------------------------------------------------------------------------------------------
local classNames = { Krieger = "WARRIOR", Paladin = "PALADIN", ["Jäger"] = "HUNTER", Schurke = "ROGUE", Priester = "PRIEST",
    Schamane = "SHAMAN", Magier = "MAGE", Hexenmeister = "WARLOCK", Druide = "DRUID" }
function T.ClassColor(classFile, className)
    local value = type(classFile) == "string" and classFile ~= "" and classFile or className
    if type(value) ~= "string" or value == "" then return nil end
    local token = classNames[value] or string.upper(value)
    if type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" then
        local ok, color = pcall(C_ClassColor.GetClassColor, token)
        if ok and type(color) == "table" then
            local r, g, b = color.r, color.g, color.b
            if type(color.GetRGB) == "function" then
                local okRGB, cr, cg, cb = pcall(color.GetRGB, color)
                if okRGB then r, g, b = cr, cg, cb end
            end
            if type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
        end
    end
    local color = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token]
    if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
        return color.r, color.g, color.b
    end
    return nil
end
-- "rrggbb" for colour codes, or nil.
function T.ClassColorHex(classFile, className)
    local r, g, b = T.ClassColor(classFile, className)
    if not r then return nil end
    return string.format("%02x%02x%02x", math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
end

-- ---------------------------------------------------------------------------------------------
-- Client fonts: own font objects (same Friz Quadrata face as the base object) so button text keeps
-- its colour in every state. Without CreateFont the text colour is set directly.
-- ---------------------------------------------------------------------------------------------
local fontObjects = {}
local function fontObject(colorKey, size)
    if type(CreateFont) ~= "function" then return nil end
    local id = "ZenialCommunityFont" .. colorKey .. tostring(size)
    if fontObjects[id] == nil then
        local ok, font = pcall(CreateFont, id)
        fontObjects[id] = false
        if ok and font then
            call(font, "SetFontObject", _G.GameFontNormal or "GameFontNormal")
            if type(font.GetFont) == "function" then
                local okFont, file, _, flags = pcall(font.GetFont, font)
                if okFont and file then call(font, "SetFont", file, size, flags or "") end
            end
            call(font, "SetTextColor", T.PaletteColor(colorKey))
            fontObjects[id] = font
        end
    end
    return fontObjects[id] or nil
end
T.FontObject = fontObject

local BUTTON_TEXT = {
    secondary = { "text", "goldBright", "disabledText" }, primary = { "goldText", "goldText", "disabledText" },
    danger = { "text", "goldText", "disabledText" }, nav = { "textSoft", "text", "disabledText" },
}
-- Applies the per-state font objects of the button's variant. `size` overrides the current text size.
function T.StyleButtonText(button, size)
    if not button then return end
    local fs = button.GetFontString and button:GetFontString()
    if size then button.zenialFontSize = size end
    if not button.zenialFontSize then
        local okFont, _, fontSize
        if fs and fs.GetFont then okFont, _, fontSize = pcall(fs.GetFont, fs) end
        button.zenialFontSize = okFont and type(fontSize) == "number" and fontSize > 0 and math.floor(fontSize + .5) or 12
    end
    local spec = BUTTON_TEXT[button.zenialVariant or "secondary"] or BUTTON_TEXT.secondary
    local normalKey = button.zenialSelected and button.zenialVariant == "nav" and "gold" or spec[1]
    local highlightKey = button.zenialSelected and button.zenialVariant == "nav" and "gold" or spec[2]
    local normal, highlight, disabled = fontObject(normalKey, button.zenialFontSize), fontObject(highlightKey, button.zenialFontSize), fontObject(spec[3], button.zenialFontSize)
    if normal and highlight and disabled then
        -- Per-state font objects only change with the variant, the selection or the size.
        local signature = normalKey .. "|" .. highlightKey .. "|" .. button.zenialFontSize
        if button.zenialFontSignature ~= signature then
            button.zenialFontSignature = signature
            call(button, "SetNormalFontObject", normal); call(button, "SetHighlightFontObject", highlight); call(button, "SetDisabledFontObject", disabled)
        end
    elseif fs then
        local okFont, file
        if fs.GetFont then okFont, file = pcall(fs.GetFont, fs) end
        if okFont and file and size then call(fs, "SetFont", file, size, "") end
        local enabled = not button.IsEnabled or button:IsEnabled()
        call(fs, "SetTextColor", T.PaletteColor(enabled and normalKey or spec[3]))
    end
end

-- ---------------------------------------------------------------------------------------------
-- AnimationGroup helpers (everything optional; callers get false and fall back to instant changes)
-- ---------------------------------------------------------------------------------------------
local function newGroup(owner)
    if not owner or type(owner.CreateAnimationGroup) ~= "function" then return nil end
    local ok, group = pcall(owner.CreateAnimationGroup, owner)
    return ok and group or nil
end
local function newAnim(group, kind)
    if not group or type(group.CreateAnimation) ~= "function" then return nil end
    local ok, anim = pcall(group.CreateAnimation, group, kind)
    return ok and anim or nil
end
function T.CanAnimate(frame) return frame ~= nil and type(frame.CreateAnimationGroup) == "function" end

-- Fade-in plus rise: the region starts `rise` below its anchor, fully transparent, and settles within
-- `duration` seconds. Returns true when an animation was started; anything missing leaves the region
-- exactly as it is (instant).
local function finishReveal(frame)
    local state = frame.zenialReveal
    if not state or not state.active then return end
    state.active = false
    frame:SetAlpha(1)
    if state.shifted then
        -- Anchors are stored as floats by the client; compare with a tolerance. A re-layout during the
        -- animation moved the anchor elsewhere and must not be overwritten.
        local p, _, _, x, y = frame:GetPoint(1)
        if p == state.shifted.p and type(x) == "number" and type(y) == "number"
            and math.abs(x - state.shifted.x) < .05 and math.abs(y - state.shifted.y) < .05 then
            frame:ClearAllPoints(); frame:SetPoint(state.origin.p, state.origin.relative, state.origin.rp, state.origin.x, state.origin.y)
        end
        state.shifted = nil
    end
end
function T.CancelReveal(frame)
    local state = frame and frame.zenialReveal
    if not state or not state.active then return end
    call(state.group, "Stop")
    finishReveal(frame)
end
function T.Reveal(frame, rise, duration)
    if not frame or frame.zenialReveal == false or T.suppressMotion then return false end
    rise, duration = rise or T.animation.pageRise, duration or T.animation.pageDuration
    T.CancelReveal(frame)
    local state = frame.zenialReveal
    if not state then
        local group = newGroup(frame)
        local alpha, move = newAnim(group, "Alpha"), newAnim(group, "Translation")
        if not (group and alpha and move) then frame.zenialReveal = false; return false end
        state = { group = group, alpha = alpha, move = move }
        -- The animation itself starts transparent (SetFromAlpha); the frame's own alpha is never lowered, so a
        -- client that multiplies both can never leave the content invisible.
        state.canFade = call(alpha, "SetFromAlpha", 0) and call(alpha, "SetToAlpha", 1) and true or false
        call(alpha, "SetDuration", duration); call(alpha, "SetOrder", 1)
        call(move, "SetDuration", duration); call(move, "SetOrder", 1); call(move, "SetSmoothing", "OUT")
        call(group, "SetToFinalAlpha", true)
        call(group, "SetScript", "OnFinished", function() finishReveal(frame) end)
        hook(frame, "OnHide", function() T.CancelReveal(frame) end)
        frame.zenialReveal = state
    end
    state.shifted = nil
    if frame.GetNumPoints and frame:GetNumPoints() == 1 then
        local p, relative, rp, x, y = frame:GetPoint(1)
        local shift = rise / (frame.GetScale and frame:GetScale() or 1)
        if type(x) == "number" and type(y) == "number" then
            state.origin = { p = p, relative = relative, rp = rp, x = x, y = y }
            state.shifted = { p = p, x = x, y = y - shift }
            frame:ClearAllPoints(); frame:SetPoint(p, relative, rp, x, y - shift)
            call(state.move, "SetOffset", 0, shift)
        end
    end
    if not state.shifted then call(state.move, "SetOffset", 0, 0) end
    state.active = true
    if not call(state.group, "Play") then finishReveal(frame); return false end
    return true
end

-- Press feedback: the button is scaled to 0.97 and back (two Scale animations).
local function pressFeedback(button)
    if button.zenialPress == false then return end
    if button.zenialPress == nil then
        local group = newGroup(button)
        local down, up = newAnim(group, "Scale"), newAnim(group, "Scale")
        if not (group and down and up) then button.zenialPress = false; return end
        local s = T.animation.pressScale
        local function setScale(anim, from, to)
            if not (call(anim, "SetScaleFrom", from, from) and call(anim, "SetScaleTo", to, to)) then call(anim, "SetScale", to / from, to / from) end
        end
        setScale(down, 1, s); setScale(up, s, 1)
        call(down, "SetDuration", .05); call(down, "SetOrder", 1); call(up, "SetDuration", .08); call(up, "SetOrder", 2)
        call(down, "SetOrigin", "CENTER", 0, 0); call(up, "SetOrigin", "CENTER", 0, 0)
        button.zenialPress = group
    end
    call(button.zenialPress, "Stop"); call(button.zenialPress, "Play")
end
T.PressFeedback = pressFeedback

-- ---------------------------------------------------------------------------------------------
-- Buttons: one primary (gold) and one secondary (dark) style, plus danger and the borderless nav style
-- ---------------------------------------------------------------------------------------------
local VARIANTS = {
    secondary = { top = "btnTop", bottom = "btnBottom", edge = "btnEdge", hoverEdge = "goldDim", hover = .10 },
    primary = { top = "goldFillTop", bottom = "goldFillBottom", edge = "goldEdge", hoverEdge = "goldBright", hover = .16 },
    danger = { top = "dangerTop", bottom = "dangerBottom", edge = "dangerEdge", hoverEdge = "goldDim", hover = .12 },
    nav = { hover = .07 },
}
local TEMPLATE_PARTS = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
local function hideTemplateArt(widget)
    local name = widget.GetName and widget:GetName()
    for _, part in ipairs(TEMPLATE_PARTS) do
        local region = widget[part] or (name and _G[name .. part])
        if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        if type(widget[getter]) == "function" then
            local ok, region = pcall(widget[getter], widget)
            if ok and type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
        end
    end
end

local function applyButtonState(button)
    local skin = button.zenialSkin
    if not skin then return end
    local variant = VARIANTS[button.zenialVariant] or VARIANTS.secondary
    local enabled = not button.IsEnabled or button:IsEnabled()
    if button.zenialVariant == "nav" then
        skin.fill:Hide(); for _, texture in pairs(skin.edges) do texture:Hide() end
    else
        skin.fill:Show(); for _, texture in pairs(skin.edges) do texture:Show() end
        if enabled then
            T.SetGradient(skin.fill, "VERTICAL", variant.top, variant.bottom)
            tintEdges(skin.edges, button.zenialHover and variant.hoverEdge or variant.edge)
        else
            tint(skin.fill, "SetColorTexture", "disabled")
            tintEdges(skin.edges, "line")
        end
    end
    tint(skin.hover, "SetColorTexture", "gold", variant.hover)
    T.StyleButtonText(button)
end

function T.StyleButton(button, variant)
    if not button then return button end
    button.zenialVariant = VARIANTS[variant] and variant or (VARIANTS[button.zenialVariant] and button.zenialVariant) or "secondary"
    if not button.zenialSkin and button.CreateTexture then
        -- UIPanelButtonTemplate keeps its own left/middle/right art; it is made transparent (not replaced)
        -- so no second full button texture is stacked on top.
        hideTemplateArt(button)
        local skin = {}
        skin.fill = button:CreateTexture(nil, "BACKGROUND")
        skin.fill:SetPoint("TOPLEFT", 1, -1); skin.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        skin.edges = edges(button, "BORDER")
        skin.hover = button:CreateTexture(nil, "HIGHLIGHT")
        skin.hover:SetPoint("TOPLEFT", 1, -1); skin.hover:SetPoint("BOTTOMRIGHT", -1, 1)
        call(skin.hover, "SetBlendMode", "ADD")
        button.zenialSkin, button.zenialTint = skin, skin.fill
        hook(button, "OnEnter", function(self) self.zenialHover = true; applyButtonState(self) end)
        hook(button, "OnLeave", function(self) self.zenialHover = false; applyButtonState(self) end)
        hook(button, "OnEnable", applyButtonState)
        hook(button, "OnDisable", applyButtonState)
        hook(button, "OnMouseDown", function(self) if self.IsEnabled == nil or self:IsEnabled() then pressFeedback(self) end end)
    end
    applyButtonState(button)
    return button
end

-- ---------------------------------------------------------------------------------------------
-- Navigation: borderless entries; selection is a gradient + 3px gold edge. Sidebar entries share one
-- indicator that slides (Translation animation, instant without AnimationGroup) to the selected entry.
-- ---------------------------------------------------------------------------------------------
function T.StyleNav(button, iconSpec)
    T.StyleButton(button, "nav")
    if iconSpec and not button.zenialIcon then
        local icon = button:CreateTexture(nil, "ARTWORK"); icon:SetSize(19, 19); icon:SetPoint("LEFT", 10, 0); button.zenialIcon = icon
    end
    if button.zenialIcon then
        if iconSpec then T.SetTexture(button.zenialIcon, iconSpec); button.zenialIcon:Show() else button.zenialIcon:Hide() end
    end
    return button
end

function T.StyleTab(button, iconSpec)
    T.StyleButton(button, "secondary")
    if iconSpec then T.StyleNav(button, iconSpec) end
    return button
end

function T.StyleDropdown(button)
    T.StyleButton(button, "secondary")
    if not button.zenialDropdownArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY"); arrow:SetSize(18, 18); arrow:SetPoint("RIGHT", -7, 0)
        arrow:SetTexture(T.assets.dropdownArrow); tint(arrow, "SetVertexColor", "gold"); button.zenialDropdownArrow = arrow
    end
    return button
end

function T.SetSelected(button, selected)
    if not button then return end
    selected = selected == true
    button.zenialSelected = selected
    if not button.zenialSelection then
        local fill = button:CreateTexture(nil, "BORDER"); fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMRIGHT", -1, 1)
        T.SetGradient(fill, "HORIZONTAL", "selectTop", "selectBottom")
        button.zenialSelection = fill
        local line = button:CreateTexture(nil, "OVERLAY"); line:SetPoint("TOPLEFT", 1, -1); line:SetPoint("BOTTOMLEFT", 1, 1); line:SetWidth(3)
        tint(line, "SetColorTexture", "gold")
        button.zenialSelectionLine = line
    end
    -- Entries that share the sliding indicator keep their regions as state carriers; the indicator draws.
    local visible = button.zenialIndicator and 0 or 1
    button.zenialSelection:SetShown(selected); button.zenialSelectionLine:SetShown(selected)
    button.zenialSelection:SetAlpha(visible); button.zenialSelectionLine:SetAlpha(visible)
    if button.zenialVariant == "nav" then T.StyleButtonText(button) end
    if selected and button.zenialIndicator then button.zenialIndicator:MoveTo(button) end
end

function T.CreateNavIndicator(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(10, 10); frame:EnableMouse(false); frame:Hide()
    local fill = frame:CreateTexture(nil, "BACKGROUND"); fill:SetAllPoints(); T.SetGradient(fill, "HORIZONTAL", "selectTop", "selectBottom")
    local edge = frame:CreateTexture(nil, "OVERLAY"); edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(3)
    tint(edge, "SetColorTexture", "gold")
    local indicator = { frame = frame, parent = parent }
    local function place(x, y, w, h)
        frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); frame:SetSize(w, h)
        indicator.x, indicator.y, indicator.w, indicator.h = x, y, w, h
        frame:Show()
    end
    function indicator:Finish()
        if not self.pending then return end
        local p = self.pending; self.pending, self.playing = nil, false
        place(p.x, p.y, p.w, p.h)
    end
    function indicator:Animate(dx, dy)
        if self.group == nil then
            local group = newGroup(frame)
            local move = newAnim(group, "Translation")
            if group and move then
                call(move, "SetDuration", T.animation.navDuration); call(move, "SetSmoothing", "OUT")
                call(group, "SetScript", "OnFinished", function() indicator:Finish() end)
                self.group, self.move = group, move
            else
                self.group = false
            end
        end
        if not self.group then return false end
        call(self.move, "SetOffset", dx, dy)
        if not call(self.group, "Play") then return false end
        self.playing = true
        return true
    end
    function indicator:MoveTo(button, instant)
        if not button or not button.GetPoint then return end
        local _, _, _, x, y = button:GetPoint(1)
        local w, h = button:GetWidth(), button:GetHeight()
        if type(x) ~= "number" or type(y) ~= "number" then return end
        if not button:IsShown() then frame:Hide(); self.target = nil; return end
        local last = self.pending or self
        if self.target == button and last.x == x and last.y == y and last.w == w and last.h == h and frame:IsShown() then return end
        if self.playing then
            call(self.group, "Stop")
            self:Finish()
        end
        local fromX, fromY = self.x, self.y
        local sameEntry = self.target == button
        self.target = button
        -- Only a change of the selected entry slides; a re-layout of the same entry is placed at once.
        if not instant and not T.suppressMotion and not sameEntry and fromX and frame:IsShown() and parent:IsVisible() and (fromX ~= x or fromY ~= y) then
            frame:SetSize(w, h)
            self.pending = { x = x, y = y, w = w, h = h }
            if self:Animate(x - fromX, y - fromY) then return end
            self.pending = nil
        end
        place(x, y, w, h)
    end
    function indicator:Hide() frame:Hide(); self.target = nil end
    -- Ends a running slide at once (window closed, page rebuilt).
    function indicator:Settle()
        if self.playing then call(self.group, "Stop"); self:Finish() end
    end
    return indicator
end

-- ---------------------------------------------------------------------------------------------
-- Rows (lists): flat row colour, ADD-blend hover, selected = gradient + 3px gold edge, icon slot
-- ---------------------------------------------------------------------------------------------
function T.StyleRow(row)
    if not row or row.zenialRowSkin then return row end
    row.zenialRowSkin = true
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(1, 1, 1, 1); background:SetVertexColor(T.PaletteColor("row", .96))
    row.zenialRowBackground = background
    local divider = row:CreateTexture(nil, "BORDER")
    divider:SetPoint("BOTTOMLEFT"); divider:SetPoint("BOTTOMRIGHT"); divider:SetHeight(1); tint(divider, "SetColorTexture", "lineSoft")
    row.zenialRowDivider = divider
    row.zenialRowHover = row:CreateTexture(nil, "BORDER"); row.zenialRowHover:SetAllPoints()
    tint(row.zenialRowHover, "SetColorTexture", "gold", .09); call(row.zenialRowHover, "SetBlendMode", "ADD"); row.zenialRowHover:Hide()
    row.zenialRowSelected = row:CreateTexture(nil, "BORDER"); row.zenialRowSelected:SetAllPoints()
    T.SetGradient(row.zenialRowSelected, "HORIZONTAL", "selectTop", "selectBottom"); row.zenialRowSelected:Hide()
    row.zenialRowEdge = row:CreateTexture(nil, "OVERLAY")
    row.zenialRowEdge:SetPoint("TOPLEFT", 0, -4); row.zenialRowEdge:SetPoint("BOTTOMLEFT", 0, 4); row.zenialRowEdge:SetWidth(3)
    tint(row.zenialRowEdge, "SetColorTexture", "gold"); row.zenialRowEdge:Hide()
    row.zenialRowIcon = row:CreateTexture(nil, "ARTWORK"); row.zenialRowIcon:SetSize(30, 30); row.zenialRowIcon:SetPoint("LEFT", 8, 0); row.zenialRowIcon:Hide()
    hook(row, "OnEnter", function(self) self.zenialRowHover:Show() end)
    hook(row, "OnLeave", function(self) self.zenialRowHover:Hide() end)
    return row
end

function T.UpdateRow(row, item)
    T.StyleRow(row); item = item or {}
    local selected = item.selected == true
    row.zenialRowSelected:SetShown(selected); row.zenialRowEdge:SetShown(selected)
    if item.icon then T.SetTexture(row.zenialRowIcon, item.icon); row.zenialRowIcon:Show() else row.zenialRowIcon:Hide() end
    if item.color and not selected then row.zenialRowBackground:SetVertexColor(item.color[1], item.color[2], item.color[3], item.color[4] or 1)
    else row.zenialRowBackground:SetVertexColor(T.PaletteColor("row", .96)) end
end

-- ---------------------------------------------------------------------------------------------
-- Inputs and scroll bars
-- ---------------------------------------------------------------------------------------------
function T.StyleEditBox(edit)
    if not edit then return edit end
    -- The template art is only replaced when the flat backdrop can actually be drawn.
    if edit.SetBackdrop then hideTemplateArt(edit) end
    flatBackdrop(edit, "inset", .99, "fieldEdge")
    if edit.SetTextInsets then edit:SetTextInsets(8, 8, 4, 4) end
    if not edit.zenialFocusHooks then
        edit.zenialFocusHooks = true
        hook(edit, "OnEditFocusGained", function(self) tint(self, "SetBackdropBorderColor", "goldDim") end)
        hook(edit, "OnEditFocusLost", function(self) tint(self, "SetBackdropBorderColor", "fieldEdge") end)
    end
    return edit
end

function T.CreateScrollBar(parent, onValue)
    local bar = CreateFrame("Slider", nil, parent); bar:SetOrientation("VERTICAL"); bar:SetSize(12, 100); bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(false) end
    local track = bar:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints(); tint(track, "SetColorTexture", "line", .9)
    local thumb = bar:CreateTexture(nil, "OVERLAY"); thumb:SetSize(8, 24); tint(thumb, "SetColorTexture", "goldDim", .9)
    bar:SetThumbTexture(thumb); bar.zenialThumb = thumb
    bar:SetScript("OnValueChanged", function(self, value) if not self.zenialSyncing then onValue(value) end end)
    return bar
end

-- ---------------------------------------------------------------------------------------------
-- Chips: two-state toggle buttons (CheckButton, so SetChecked/GetChecked/Click behave like a checkbox)
-- ---------------------------------------------------------------------------------------------
local function applyChip(chip)
    local enabled = not chip.IsEnabled or chip:IsEnabled()
    local on = chip:GetChecked() and true or false
    chip.zenialChipOn = on
    tint(chip.zenialChipFill, "SetColorTexture", on and "chipOnBg" or "chipBg")
    tintEdges(chip.zenialChipEdges, on and "chipOnEdge" or (chip.zenialHover and enabled) and "goldDim" or "chipEdge")
    tint(chip.text, "SetTextColor", not enabled and "disabledText" or on and "chipOnText" or "textSoft")
end
function T.Chip(parent, value, width, height, onClick)
    local chip = CreateFrame("CheckButton", nil, parent)
    chip:SetSize(width or 90, height or 22)
    chip.zenialChipFill = chip:CreateTexture(nil, "BACKGROUND"); chip.zenialChipFill:SetPoint("TOPLEFT", 1, -1); chip.zenialChipFill:SetPoint("BOTTOMRIGHT", -1, 1)
    chip.zenialChipEdges = edges(chip, "BORDER")
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.text:SetPoint("LEFT", 8, 0); chip.text:SetPoint("RIGHT", -8, 0); chip.text:SetJustifyH("CENTER"); chip.text:SetWordWrap(false)
    chip.text:SetText(value or "")
    local setChecked, setEnabled = chip.SetChecked, chip.SetEnabled
    chip.SetChecked = function(self, checked) setChecked(self, checked); applyChip(self) end
    chip.SetEnabled = function(self, enabled) setEnabled(self, enabled); applyChip(self) end
    chip:SetScript("OnClick", function(self, ...) applyChip(self); if onClick then onClick(self, ...) end end)
    hook(chip, "OnEnter", function(self) self.zenialHover = true; applyChip(self) end)
    hook(chip, "OnLeave", function(self) self.zenialHover = false; applyChip(self) end)
    hook(chip, "OnEnable", applyChip); hook(chip, "OnDisable", applyChip)
    applyChip(chip)
    return chip
end

-- ---------------------------------------------------------------------------------------------
-- Small status chip (layer) and success toast
-- ---------------------------------------------------------------------------------------------
function T.CreateTag(parent, fillKey, edgeKey, textKey)
    local tag = CreateFrame("Frame", nil, parent)
    tag:SetSize(70, 16)
    tag.fill = tag:CreateTexture(nil, "BACKGROUND"); tag.fill:SetAllPoints(); tint(tag.fill, "SetColorTexture", fillKey)
    tag.edges = edges(tag, "BORDER"); tintEdges(tag.edges, edgeKey)
    tag.text = tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tag.text:SetPoint("CENTER"); tint(tag.text, "SetTextColor", textKey)
    function tag:SetLabel(value)
        self.text:SetText(value or "")
        local measured = self.text.GetStringWidth and self.text:GetStringWidth()
        self:SetWidth(math.max(24, (type(measured) == "number" and measured or #(value or "") * 6) + 14))
    end
    return tag
end

function T.CreateToast(parent)
    local toast = CreateFrame("Frame", nil, parent)
    toast:SetSize(230, 34); toast:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 34)
    toast:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 90); toast:EnableMouse(false)
    toast.fill = toast:CreateTexture(nil, "BACKGROUND"); toast.fill:SetAllPoints(); tint(toast.fill, "SetColorTexture", "toastBg", .98)
    toast.edges = edges(toast, "BORDER"); tintEdges(toast.edges, "toastEdge")
    toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.text:SetPoint("LEFT", 12, 0); toast.text:SetPoint("RIGHT", -12, 0); toast.text:SetJustifyH("LEFT"); tint(toast.text, "SetTextColor", "toastText")
    toast:Hide()
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.remaining = (self.remaining or 0) - elapsed
        if self.remaining <= 0 then self:Hide() end
    end)
    function toast:Notify(value, seconds)
        self.text:SetText(value or "")
        self.remaining = seconds or 1.8
        self:Show()
        T.Reveal(self, 12, .2)
    end
    return toast
end

if type(Z) == "table" then Z.ThemeCommunityLoaded = true end
