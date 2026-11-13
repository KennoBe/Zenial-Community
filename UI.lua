local _, ns = ...
local Z = ZenialCommunity
local U, T = {}, Z.Theme
Z.UI = U

-- Native close button for Community windows. The Blizzard template is probed with pcall so a client
-- without it gets a plain text button instead of a Lua error. Close semantics (OnClick handler, ESC via
-- UISpecialFrames / the dialog keyboard handling) stay with the caller.
function U.CloseButton(parent, x, y, onClick, size)
    local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
    if not ok or not button then
        button = CreateFrame("Button", nil, parent)
        button:SetSize(24, 24)
        button.zenialFallbackClose = true
        local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        glyph:SetPoint("CENTER")
        glyph:SetText("\195\151")
        button.glyph = glyph
        button:SetScript("OnEnter", function(self)
            if GameTooltip and GameTooltip.SetOwner then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(Z.T and Z.T("Close") or "Close")
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
    end
    if size then button:SetSize(size, size) end
    button:SetPoint("TOPRIGHT", x, y)
    button:SetScript("OnClick", onClick)
    return button
end

local DISCORD_URL = "https://discord.gg/wow-forever-deutsch"

local function label(parent, value, x, y, width, font)
    local text = T and T.Text(parent, value, font) or parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if not T then text:SetText(value); text:SetJustifyH("LEFT") end
    text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); return text
end

function U.ShowDiscord()
    if not U.discord then
        local frame = CreateFrame("Frame", "ZenialCommunityDiscord", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        U.discord = frame; frame:SetSize(470, 165); frame:SetPoint("CENTER"); frame:SetFrameStrata("FULLSCREEN_DIALOG")
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityDiscord"end
        if T then T.Shell(frame) end
        local heading = label(frame, "WoW Forever Discord", 24, -24, 350, "GameFontNormalLarge")
        -- Dialog head around the title; the native close button stays (family convention).
        if Z.Kit and Z.Kit.DialogHeader then Z.Kit.DialogHeader(frame, heading) end
        local close = U.CloseButton(frame, -5, -5, function() frame:Hide() end)
        local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate"); U.discordEdit = edit
        edit:SetSize(416, 28); edit:SetPoint("TOPLEFT", 26, -70); edit:SetAutoFocus(false); edit:SetFontObject("GameFontHighlight")
        if T then T.StyleEditBox(edit) end
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
        label(frame, Z.T("Click the text field, then press Ctrl+A and Ctrl+C."), 26, -112, 320)
    end
    U.discordEdit:SetText(DISCORD_URL); U.discord:Show(); U.discordEdit:HighlightText()
end

function U.RefreshDiagnostics()
    local report=Z.Diagnostics.Export()
    U.diagnosticEdit:SetText(report)
    U.diagnosticScroll:SetVerticalScroll(0)
    U.diagnosticEdit:HighlightText()
end

local BACKUP_TITLE={foreverLiveBackup="Forever Live migration backup",migrationBackup="Character migration backup",characterBackup="Merged character profiles backup"}
function U.RefreshBackups()
    if not U.backupPanel then return end
    local present={};for _,row in ipairs(Z.Diagnostics.Backups())do present[row.name]=row end
    if U.backupArmed and not present[U.backupArmed]then U.backupArmed=nil end
    for _,r in ipairs(U.backupRows)do
        local info=present[r.name];r.text:SetShown(info~=nil);r.delete:SetShown(info~=nil)
        if info then
            local age=info.age and" · "..Z.T("%d days ago",math.floor(info.age/86400))or""
            r.text:SetText(Z.T(BACKUP_TITLE[r.name]).." · "..Z.Diagnostics.SizeText(info)..age)
            r.delete:SetText(Z.T(U.backupArmed==r.name and"Confirm deletion"or"Delete backup"))
        end
    end
    U.backupEmpty:SetShown(next(present)==nil);U.backupCancel:SetShown(U.backupArmed~=nil)
    U.diagnosticScroll:SetShown(not U.backupPanel:IsShown())
end

function U.ShowDiagnostics()
    if not U.diagnosticWindow then
        local f=CreateFrame("Frame","ZenialCommunityDiagnostics",UIParent,BackdropTemplateMixin and "BackdropTemplate"or nil)
        U.diagnosticWindow=f;f:SetSize(math.min(900,UIParent:GetWidth()-40),math.min(650,UIParent:GetHeight()-40))
        f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function(self)self:StartMoving()end);f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
        f:SetScript("OnHide",function()U.diagnosticEdit:ClearFocus()end)
        if T then T.Shell(f)end
        local heading=label(f,Z.T("Diagnostic report"),24,-20,650,"GameFontNormalLarge")
        if Z.Kit and Z.Kit.DialogHeader then Z.Kit.DialogHeader(f,heading)end
        label(f,Z.T("Click the text field, then press Ctrl+A and Ctrl+C."),24,-53,800)
        local close=U.CloseButton(f,-5,-5,function()f:Hide()end)
        local function action(value,x,fn)
            local b=T and T.Button(f,Z.T(value),170,28,fn)or CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
            if not T then b:SetSize(170,28);b:SetText(Z.T(value));b:SetScript("OnClick",fn)end
            b:SetPoint("BOTTOMLEFT",x,20);return b
        end
        U.diagnosticSelect=action("Select all",24,function()U.diagnosticEdit:HighlightText()end)
        U.diagnosticRefresh=action("Refresh",204,U.RefreshDiagnostics)
        U.diagnosticBackups=action("Backups",384,function()U.backupArmed=nil;U.backupPanel:SetShown(not U.backupPanel:IsShown());U.RefreshBackups()end)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");U.diagnosticScroll=scroll
        scroll:SetPoint("TOPLEFT",24,-86);scroll:SetPoint("BOTTOMRIGHT",-46,65)
        if T then T.StyleScroll(scroll);T.AttachScrollWheel(scroll,42)end
        local edit=CreateFrame("EditBox",nil,scroll);U.diagnosticEdit=edit
        edit:EnableMouse(true);edit:EnableKeyboard(true)
        edit:SetScript("OnMouseDown",function(self,button)if button=="LeftButton"then self:SetFocus()end end)
        edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetMaxLetters(0);edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(f:GetWidth()-80);edit:SetPoint("TOPLEFT");if edit.SetTextInsets then edit:SetTextInsets(6,6,6,6)end
        edit:SetScript("OnEscapePressed",function()f:Hide()end)
        edit:SetScript("OnTextChanged",function(self)
            -- FontString measurement accounts for wrapped lines as well as newlines.
            U.diagnosticMeasure:SetText(self:GetText())
            local _,lines=self:GetText():gsub("\n","\n")
            self:SetHeight(math.max(480,(lines+1)*15+24,U.diagnosticMeasure:GetStringHeight()+24));scroll:UpdateScrollChildRect()
        end)
        edit:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local current=scroll:GetVerticalScroll();local top=-y;local visible=scroll:GetHeight()
            if top<current then scroll:SetVerticalScroll(math.max(0,top))elseif top+height>current+visible then scroll:SetVerticalScroll(math.max(0,top+height-visible))end
        end)
        local measure=f:CreateFontString(nil,"OVERLAY","ChatFontNormal");U.diagnosticMeasure=measure
        measure:SetWidth(f:GetWidth()-92);measure:SetWordWrap(true);measure:Hide()
        scroll:SetScrollChild(edit)
        -- Backup manager: nothing is deleted without a second, explicit confirmation click.
        local panel=CreateFrame("Frame",nil,f);U.backupPanel=panel;panel:SetPoint("TOPLEFT",24,-86);panel:SetPoint("BOTTOMRIGHT",-46,65);panel:Hide()
        label(panel,Z.T("Backups are kept until you delete them here. Deleting a backup cannot be undone."),0,0,800)
        U.backupEmpty=label(panel,Z.T("No backups stored."),0,-44,800)
        U.backupRows={}
        for i,name in ipairs(Z.Diagnostics.BACKUPS)do
            local y=-44-(i-1)*48;local text=label(panel,"",0,y,560)
            local b=T and T.Button(panel,"",170,28,nil)or CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            if not T then b:SetSize(170,28)end;b:SetPoint("TOPLEFT",600,y+4)
            b:SetScript("OnClick",function()
                if U.backupArmed==name then U.backupArmed=nil;Z.Diagnostics.DeleteBackup(name) else U.backupArmed=name end
                U.RefreshBackups()
            end)
            U.backupRows[i]={name=name,text=text,delete=b}
        end
        U.backupCancel=T and T.Button(panel,Z.T("Cancel"),170,28,function()U.backupArmed=nil;U.RefreshBackups()end)or CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        if not T then U.backupCancel:SetSize(170,28);U.backupCancel:SetText(Z.T("Cancel"));U.backupCancel:SetScript("OnClick",function()U.backupArmed=nil;U.RefreshBackups()end)end
        U.backupCancel:SetPoint("TOPLEFT",600,-190)
        panel:SetScript("OnHide",function()U.backupArmed=nil end)
        f:HookScript("OnHide",function()panel:Hide()end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityDiagnostics"end
    end
    U.diagnosticWindow:Show();U.RefreshDiagnostics()
end

-- The shared ZENIAL icon (Launcher.lua) took over from Community's own button; ZenialUI still repositions it here.
function U.PositionMinimapButton()
    if not U.minimapButton then return false end
    return U.minimapButton.Reposition()
end

function U.CreateMinimapButton()
    local launcher = ns.Launcher
    if not launcher then return end
    U.minimapButton = launcher.MinimapHub()
    launcher.AdoptMinimapAngle(Z.db and Z.db.minimapAngle)
end
