-- Group finder: the whisper texts of the player (WhisperTexts.lua) in the interface.
--
-- Menu: the list of texts behind the arrow of a whisper button (cards and the assistant). It is Community's
-- usual selector list: the texts of one kind, the last used one marked, and "Edit texts…" at the end.
-- See _dev/addons/ZenialCommunity/WHISPER-DESIGNER-DESIGN.md.
local Z = ZenialCommunity
local U, W = Z.UI, Z.WhisperTexts
local S = U and U.Shared
if type(U) ~= 'table' or type(W) ~= 'table' or type(S) ~= 'table' then
    return
end

local WD = {}
U.WhisperDesigner = WD

local EDIT = 'EDIT'
local function tr(value)
    return Z.T(value)
end

local function optionId(value)
    return type(value) == 'string' and tonumber(value:match('^T(%d+)$')) or nil
end

-- Opens the list of texts below anchor. canContact: whether picking a text may write now; pick(id) writes.
-- "Edit texts…" opens the designer on the same kind in any case. A second click on the same arrow closes it.
function WD.Menu(anchor, kind, canContact, pick)
    local parent = U.Finder and U.Finder.frame
    if not parent then
        return
    end
    local menu = WD.menu
    if not menu then
        menu = S.selector(parent, '', 0, 0, 200, {}, function(value)
            local state = WD.menuState or {}
            if value == EDIT then
                WD.Open(state.kind)
            elseif state.canContact and state.pick and optionId(value) then
                state.pick(optionId(value))
            end
        end, function(value)
            if value == EDIT then
                return tr('Edit texts…')
            end
            local entry = W.Get((WD.menuState or {}).kind, optionId(value))
            return entry and entry.name or ''
        end)
        menu.caption:Hide()
        menu.button:Hide()
        WD.menu = menu
    end
    local popup = menu.popup
    if popup:IsShown() then
        popup:Hide()
        S.openPopup = nil
        if WD.menuState and WD.menuState.anchor == anchor then
            return
        end
    end
    WD.menuState = { anchor = anchor, kind = kind, canContact = canContact == true, pick = pick }
    local options = {}
    for _, entry in ipairs(W.List(kind)) do
        options[#options + 1] = 'T' .. entry.id
    end
    options[#options + 1] = EDIT
    local last = W.Last(kind)
    menu:SetOptions(options, last and 'T' .. last.id or nil)
    popup:ClearAllPoints()
    popup:SetPoint('TOPRIGHT', anchor, 'BOTTOMRIGHT', 0, -2)
    menu.button:GetScript('OnClick')(menu.button)
end

function WD.CloseMenu()
    if WD.menu and WD.menu.popup:IsShown() then
        WD.menu.popup:Hide()
        S.openPopup = nil
    end
end

-- ---------------------------------------------------------------------------------------------
-- The designer: an overlay above the finder (and above the assistant). Left the texts of one kind, right the
-- editor of the selected one. Every change is saved at once; the window closes with the X in its head.
-- ---------------------------------------------------------------------------------------------
local T, K = Z.Theme, Z.Kit
local WIDTH, HEIGHT, ROWS, LEFT_W = 640, 452, 12, 180
local EDIT_X, EDIT_W = 212, 412
local SAMPLE = { name = 'Anna Beispiel', activity = 'Scholomance' }

local function kindOf(value)
    return value == 'solo' and 'solo' or 'group'
end

local function variableLabel(variable, kind)
    local label = variable.label
    return tr(type(label) == 'table' and label[kind] or label)
end

-- Values for the preview: the own values, the open instance, and an example for the receiver.
local function previewValues()
    local FP = U.FinderPublic
    local values = FP and FP.WhisperValues and FP.WhisperValues(nil) or {}
    values.name = SAMPLE.name
    values.activity = values.activity or SAMPLE.activity
    return values
end

-- Puts the text into the box without saving it again.
local function fill(edit, text)
    edit.zenialFilling = true
    edit:SetText(text or '')
    edit.zenialFilling = nil
end

local function cursorOf(edit)
    local text = edit:GetText()
    local position = edit.zenialCursor
    if position == nil and edit.GetCursorPosition then
        position = edit:GetCursorPosition()
    end
    position = tonumber(position) or #text
    position = math.max(0, math.min(#text, position))
    -- Never between the bytes of one character.
    while position > 0 and position < #text do
        local nextByte = text:byte(position + 1)
        if nextByte < 0x80 or nextByte >= 0xC0 then
            break
        end
        position = position - 1
    end
    return position
end

local function insert(key)
    local f = WD.frame
    local edit, piece = f.text, '{' .. key .. '}'
    local text, position = edit:GetText(), cursorOf(edit)
    edit.zenialCursor = nil
    edit:SetText(text:sub(1, position) .. piece .. text:sub(position + 1))
    if edit.SetCursorPosition then
        edit:SetCursorPosition(position + #piece)
    end
    edit:SetFocus()
end

local function selectedEntry()
    return W.Get(WD.kind, WD.selected)
end

local function drawPreview()
    local f, entry = WD.frame, selectedEntry()
    if not entry then
        f.preview:SetText('')
        f.tooLong:Hide()
        return
    end
    local full = W.Expand(entry.text, entry.language, previewValues())
    f.preview:SetText(W.Fit(full))
    f.tooLong:SetShown(#full > W.MAX_TEXT)
end

local function drawList()
    local f = WD.frame
    local list, last = W.List(WD.kind), W.Last(WD.kind)
    for index, row in ipairs(f.rows) do
        local entry = list[index]
        row:SetShown(entry ~= nil)
        if entry then
            row.zenialId = entry.id
            row:SetText(entry.name)
            T.SetSelected(row, entry.id == WD.selected)
            row.check:SetShown(last ~= nil and entry.id == last.id)
        end
    end
    f.add:ClearAllPoints()
    f.add:SetPoint('TOPLEFT', 16, -(96 + #list * 26 + 6))
    f.add:SetEnabled(#list < W.MAX_TEXTS)
    f.remove:SetEnabled(#list > 1)
end

-- Draws everything for the selected text. The boxes are filled only here, never while typing.
function WD.Refresh()
    local f = WD.frame
    if not f then
        return
    end
    if not selectedEntry() then
        local last = W.Last(WD.kind)
        WD.selected = last and last.id or nil
    end
    local entry = selectedEntry()
    f.kinds:Select(WD.kind)
    fill(f.name, entry and entry.name or '')
    fill(f.text, entry and entry.text or '')
    f.text.zenialCursor = nil
    f.language:Select(entry and entry.language or 'en')
    for index, button in ipairs(f.vars) do
        button:SetText(variableLabel(W.VARIABLES[index], WD.kind))
    end
    drawList()
    drawPreview()
end

local function label(frame, text, x, y)
    local fs = K.Text(frame, tr(text), 'overline', 'goldDim')
    fs:SetPoint('TOPLEFT', x, -y)
    return fs
end

function WD.Build()
    if WD.frame then
        return WD.frame
    end
    local parent = U.Finder.frame
    local f = CreateFrame('Frame', nil, parent)
    if f.SetFrameLevel and parent.GetFrameLevel then
        f:SetFrameLevel((parent:GetFrameLevel() or 1) + 80)
    end
    f:EnableMouse(true)
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint('CENTER', parent, 'CENTER', 0, 0)
    f.fill = f:CreateTexture(nil, 'BACKGROUND')
    f.fill:SetAllPoints()
    T.Tint(f.fill, 'SetColorTexture', 'panelRaised')
    f.edges = T.Edges(f, 'BORDER')
    T.TintEdges(f.edges, 'goldDim')
    f.title = f:CreateFontString(nil, 'OVERLAY')
    f.header = K.DialogHeader(f, f.title, WD.Close)
    f.title:SetText(tr('Texts'))
    f.kinds = K.Segmented(f, { { key = 'group', label = tr('To groups') }, { key = 'solo', label = tr('To players') } }, function(key)
        WD.kind, WD.selected = kindOf(key), nil
        WD.Refresh()
    end)
    f.kinds:SetSegmentWidth(120)
    f.kinds:SetPoint('TOPLEFT', 16, -58)
    -- The list of texts.
    f.rows = {}
    for index = 1, ROWS do
        local row = T.Button(f, '', LEFT_W, 24, function(self)
            WD.selected = self.zenialId
            WD.Refresh()
        end, 'ghost')
        T.AlignButtonText(row, 8, 24)
        row:SetPoint('TOPLEFT', 16, -(96 + (index - 1) * 26))
        row.check = row:CreateTexture(nil, 'OVERLAY')
        row.check:SetSize(14, 14)
        row.check:SetPoint('RIGHT', -6, 0)
        row.check:SetTexture('Interface\\Buttons\\UI-CheckBox-Check')
        f.rows[index] = row
    end
    f.add = T.Button(f, '+ ' .. tr('New text'), LEFT_W, 24, function()
        local entry = W.Add(WD.kind)
        if entry then
            WD.selected = entry.id
            WD.Refresh()
            f.name:SetFocus()
        end
    end, 'secondary')
    -- The editor of the selected text.
    label(f, 'Name', EDIT_X, 96)
    f.name = U.Finder.CreateEdit(f, EDIT_W, W.MAX_NAME, '')
    f.name:SetPoint('TOPLEFT', EDIT_X + 2, -112)
    f.name:SetScript('OnTextChanged', function(self)
        if not self.zenialFilling and W.Update(WD.kind, WD.selected, { name = self:GetText() }) then
            drawList()
        end
    end)
    label(f, 'Text', EDIT_X, 146)
    f.text = U.Finder.CreateEdit(f, EDIT_W, W.MAX_TEXT, '')
    f.text:SetPoint('TOPLEFT', EDIT_X + 2, -162)
    if f.text.SetMaxBytes then
        f.text:SetMaxBytes(W.MAX_TEXT + 1)
    end
    f.text:SetScript('OnTextChanged', function(self)
        if not self.zenialFilling and W.Update(WD.kind, WD.selected, { text = self:GetText() }) then
            drawPreview()
        end
    end)
    -- The insert buttons take the focus: the position of the cursor is kept from before.
    f.text:SetScript('OnEditFocusLost', function(self)
        self.zenialCursor = self.GetCursorPosition and self:GetCursorPosition() or nil
    end)
    f.text:SetScript('OnEditFocusGained', function(self)
        self.zenialCursor = nil
    end)
    label(f, 'Insert', EDIT_X, 196)
    f.vars = {}
    for index, variable in ipairs(W.VARIABLES) do
        local button = T.Button(f, '', 66, 22, function()
            insert(variable.key)
        end, 'secondary')
        button:SetPoint('TOPLEFT', EDIT_X + (index - 1) * 70, -212)
        f.vars[index] = button
    end
    label(f, 'Language of values', EDIT_X, 248)
    f.language = K.Segmented(f, { { key = 'de', label = 'Deutsch' }, { key = 'en', label = 'English' } }, function(key)
        W.Update(WD.kind, WD.selected, { language = key })
        drawPreview()
    end)
    f.language:SetSegmentWidth(90)
    f.language:SetPoint('TOPLEFT', EDIT_X, -264)
    label(f, 'Preview', EDIT_X, 300)
    f.preview = K.Text(f, '', 'body', 'text')
    f.preview:SetPoint('TOPLEFT', EDIT_X, -316)
    f.preview:SetWidth(EDIT_W)
    f.preview:SetHeight(42)
    if f.preview.SetWordWrap then
        f.preview:SetWordWrap(true)
    end
    f.preview:SetJustifyH('LEFT')
    f.tooLong = K.Text(f, tr('Too long: the end is cut off.'), 'caption', 'danger')
    f.tooLong:SetPoint('TOPLEFT', EDIT_X, -362)
    f.tooLong:Hide()
    f.remove = T.Button(f, tr('Delete'), 120, 24, function()
        if W.Remove(WD.kind, WD.selected) then
            WD.selected = nil
            WD.Refresh()
        end
    end, 'danger')
    f.remove:SetPoint('TOPLEFT', EDIT_X, -(HEIGHT - 44))
    f:Hide()
    WD.frame = f
    return f
end

-- Opens the designer on a kind ('group' when none is given), on the last used text of it.
function WD.Open(kind)
    if not (U.Finder and U.Finder.frame) then
        return false
    end
    WD.CloseMenu()
    WD.Build()
    WD.kind, WD.selected = kindOf(kind), nil
    WD.Refresh()
    WD.frame:Show()
    return true
end

function WD.Close()
    if WD.frame then
        WD.frame:Hide()
    end
    local after = WD.onClose
    WD.onClose = nil
    if after then
        after()
    end
    -- The captions of the whisper buttons carry the name of the text.
    U.RefreshFinder()
end

return WD
