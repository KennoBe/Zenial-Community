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

-- The designer (built in the next step of the plan).
function WD.Open(kind)
    WD.kind = kind == 'solo' and 'solo' or 'group'
end

return WD
