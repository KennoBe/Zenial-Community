local Z,C,A=ZenialCommunity,ZenialCommunity.Companion,ZenialCommunity.Adapter
local german=type(GetLocale)=='function'and GetLocale()=='deDE'
local function tr(de,en)return german and de or en end
local states={disabled={'Ausgeschaltet','Disabled'},blocked={'Export angehalten','Export stopped'},['logging-required']={'Chatlogging erforderlich','Chat logging required'},probing={'Verbindungsprobe','Connection probe'},unverified={'Export aktiv','Export active'}}
local reasons={['No self-whisper echo within 10 seconds. Export stopped.']={'Seit 10 Sekunden fehlt eine Selbst-Whisper-Bestätigung. Export vorsorglich angehalten.', 'No self-whisper echo within 10 seconds. Export stopped.'},
    ['Pixel transport requires verification in the companion.']={'Pixelstreifen sendet.','Pixel strip transmitting.'}}
local function label(parent,value,x,y,w,h)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlight');f:SetPoint('TOPLEFT',x,y);f:SetSize(w,h);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(value);return f
end
local function button(parent,value,x,y,w,fn)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',x,y);b:SetSize(w,28);b:SetText(value);b:SetScript('OnClick',fn);if Z.Theme then Z.Theme.StyleButton(b)end;return b
end
function C.RefreshUI()
    local join=Z.NetworkSetup and Z.NetworkSetup.joinFrame;if join and join.companionEnable then join.companionEnable:SetChecked(C.settings and C.settings.enabled==true)end
    local f=C.ui;if not f or not f:IsShown()then return end
    local s=C.Status();local state=states[s.state]or{s.state,s.state}
    local reason=reasons[s.reason];reason=reason and tr(reason[1],reason[2])or s.reason
    if s.transport=='pixel'then
        f.status:SetText(tr(state[1],state[2])..'\n'..string.format(tr('Pixelpakete: %d · Datenzeilen: %d · davon zeitgesteuert: %d','Pixel packets: %d · data lines: %d · timer-origin: %d'),s.pixelPackets,s.sent,s.automatic)..'\n'..reason..(C.settings.questAreasEnabled and'\n'..tr('Questflächen: ','Quest areas: ')..(C.QuestAreas.state or'waiting')..' · '..tostring(C.QuestAreas.completed or 0)..'/'..tostring(#(C.QuestAreas.ids or{}))..' · '..string.format('%.2f ms',C.QuestAreas.maxStepMs or 0)..(C.QuestAreas.reason and' · '..C.QuestAreas.reason or'')or''))
    else f.status:SetText(tr(state[1],state[2])..'\n'..string.format(tr('Gesendet: %d · davon zeitgesteuert: %d · Echos: %d','Sent: %d · timer-origin: %d · echoes: %d'),s.sent,s.automatic,s.echoed)..'\n'..reason
        ..'\n'..string.format(tr('Chatfilter: %d Aufrufe · %d ausgeblendet · %d fremd · %d unlesbar · %d ohne Treffer','Chat filter: %d calls · %d hidden · %d foreign · %d unreadable · %d unmatched'),s.filterCalls,s.filterHidden,s.filterForeign,s.filterUnreadable,s.filterUnmatched)
        ..(s.flushState~='idle'and'\n'..string.format(tr('Automatischer Logtest: %s · %d/10 · %s · Start %s','Automatic log test: %s · %d/10 · %s · started %s'),s.flushState,s.flushStep,s.flushMethod,A.Call(date,'%H:%M:%S',s.flushStartedAt)or tostring(s.flushStartedAt))or''))end
    f.enable:SetChecked(C.settings and C.settings.enabled==true)
    if f.questAreaEnable then f.questAreaEnable:SetChecked(C.settings and C.settings.questAreasEnabled==true)end
end
function C.Show(introduction)
    if Z.NetworkSetup and Z.NetworkSetup.IsUnsupportedBeta()then return Z.NetworkSetup.ShowBetaNotice()end
    if not C.settings then if Z.Initialize then Z.Initialize()end;if not C.settings then return end end
    if not C.ui then
        local f=CreateFrame('Frame','ZenialCompanionSettings',UIParent,BackdropTemplateMixin and'BackdropTemplate'or nil);C.ui=f
        local statusY=-240;local footerY=-515
        f:SetSize(750,-footerY+52);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(300);f:SetToplevel(true);f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton')
        local height=A and A.Call and A.Call(UIParent.GetHeight,UIParent)or UIParent:GetHeight();if type(height)=='number'and height<-footerY+70 then f:SetScale(math.max(.65,height/(-footerY+85)))end
        f:SetScript('OnDragStart',function(self)self:StartMoving()end);f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
        if Z.Theme then Z.Theme.Shell(f)end
        label(f,'ZENIAL Companion · 5.0',24,-22,630,28)
        f.subtitle=label(f,tr('Einmal einrichten. Deine Daten erscheinen im Browser oder auf einem externen Gerät.','Set up once. Your data appears in your browser or on an external device.'),24,-60,630,35)
        label(f,tr('Der Companion liest den kleinen Pixelstreifen links oben im WoW-Fenster. Er überträgt alle verfügbaren Daten, einschließlich eingehendem Chat und privaten Notizen. WoW sichtbar und nicht minimiert lassen und den Streifen frei halten.','The companion reads the small pixel strip at the top left of the WoW window. It carries all available data, including incoming chat and private notes. Keep WoW visible and not minimized and the strip unobstructed.'),24,-105,630,58)
        local check=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');f.enable=check;check:SetPoint('TOPLEFT',24,-170);check:SetSize(26,26)
        label(f,tr('Companion-Export aktivieren · alle Daten','Enable companion export · all data'),58,-174,630,24);check:SetScript('OnClick',function(self)C.SetExportEnabled(self:GetChecked()==true);C.RefreshUI()end)
        label(f,tr('Karte, Quests, Taschen, Ausrüstung, Community, Gruppen, Chat, Meldungen und private Planungen – nur für deine gekoppelten Browser.','Map, quests, bags, equipment, community, groups, chat, notifications and private plans – for your paired browsers only.'),24,-205,700,32)
        local areas=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');f.questAreaEnable=areas;areas:SetPoint('TOPLEFT',24,-242);areas:SetSize(26,26)
        label(f,tr('Quest-Zielflächen anzeigen · im Kampf pausiert','Show quest objective areas · paused in combat'),58,-246,650,24)
        areas:SetScript('OnClick',function(self)C.SetQuestAreasEnabled(self:GetChecked()==true);C.RefreshUI()end)
        if Z.Theme then Z.Theme.StyleCheckbox(areas)end
        f.status=label(f,'',24,statusY-38,700,95)
        label(f,tr('Nur lesend: Browser und externe Geräte führen nichts im Spiel aus. Pixel müssen sichtbar gerendert werden. Bei Minimierung oder fehlendem Empfang zeigt der Companion die Daten als veraltet.','Read only: the browser and external devices execute nothing in the game. Pixels must be visibly rendered. The companion marks data as stale when minimized or reception stops.'),24,statusY-130,700,50)
        label(f,tr('Companion herunterladen:','Download companion:'),24,-440,700,22)
        local link=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.downloadLink=link;link:SetPoint('TOPLEFT',30,-464);link:SetSize(660,24);link:SetAutoFocus(false);link:SetText('https://discord.zenial.net/zenial-companion')
        link:SetScript('OnEditFocusGained',function(self)self:HighlightText()end);link:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
        button(f,tr('Schließen','Close'),590,footerY,125,function()f:Hide()end)
        if Z.Theme then Z.Theme.StyleCheckbox(check)end
        f:SetScript('OnShow',C.RefreshUI);UISpecialFrames=UISpecialFrames or{};UISpecialFrames[#UISpecialFrames+1]='ZenialCompanionSettings'
    end
    C.ui.subtitle:SetText(introduction and tr('Neu in 5.x: Dein WoW im Browser und auf externen Geräten. Der Companion ist optional.','New in 5.x: your WoW in a browser and on external devices. The companion is optional.')or tr('Einmal einrichten. Deine Daten erscheinen im Browser oder auf einem externen Gerät.','Set up once. Your data appears in your browser or on an external device.'))
    C.ui:SetFrameStrata('FULLSCREEN_DIALOG');C.ui:SetFrameLevel(300);C.ui:Show();if C.ui.Raise then C.ui:Raise()end
    C.MarkIntroductionSeen();C.RefreshUI()
end

-- Per-character introduction: new installations and existing 4.x characters have
-- no major-5 acknowledgement. No activation, focus acquisition or game action.
function C.InitializeIntroduction()
    local store=Z.db
    C.introductionPending=type(store)=='table'and(type(store.companionIntroductionMajor)~='number'or store.companionIntroductionMajor<5)
    C.introductionDue=A.Clock()+6
end
function C.MarkIntroductionSeen()
    local store=Z.db
    if type(store)=='table'and(type(store.companionIntroductionMajor)~='number'or store.companionIntroductionMajor<5)then store.companionIntroductionMajor=5 end
    C.introductionPending=false
end
function C.TickIntroduction()
    if Z.NetworkSetup and Z.NetworkSetup.IsUnsupportedBeta()then return end
    if not C.introductionPending or not C.settings or not Z.db or not Z.db.consent or not Z.db.autoDiscovery or not Z.identityReady or Z.offlineOnly or A.Clock()<(C.introductionDue or 0)or A.Call(InCombatLockdown)~=false then return end
    local S=Z.NetworkSetup
    if S and((S.joinFrame and S.joinFrame:IsShown())or(S.frame and S.frame:IsShown()))then return end
    if Z.UI and Z.UI.frame and Z.UI.frame:IsShown()then return end
    -- Give asynchronous lounge membership metadata its normal first opportunity.
    if S and S.MissingGroup then local _,ready=S.MissingGroup();if not ready and A.Clock()<C.introductionDue+10 then return end end
    C.Show(true)
end
function C.AddIntroductionToJoin(f)
    label(f,tr('ZENIAL Companion · optional','ZENIAL Companion · optional'),20,-258,480,22)
    label(f,tr('Karte, Quests, Ausrüstung und Community im Browser oder auf externen Geräten. Nur lesend; Export umfasst auch Chat und private Planungen.','Map, quests, gear and community in a browser or on external devices. Read only; export includes chat and private plans.'),20,-284,480,38)
    local check=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate');f.companionEnable=check;check:SetPoint('TOPLEFT',20,-324);check:SetSize(26,26)
    label(f,tr('Companion-Export aktivieren','Enable companion export'),52,-328,440,22)
    check:SetScript('OnClick',function(self)C.SetExportEnabled(self:GetChecked()==true);C.RefreshUI()end)
    if Z.Theme then Z.Theme.StyleCheckbox(check)end
    label(f,tr('Companion herunterladen:','Download companion:'),20,-358,480,22)
    local link=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.companionDownload=link;link:SetPoint('TOPLEFT',26,-384);link:SetSize(470,24);link:SetAutoFocus(false);link:SetText('https://discord.zenial.net/zenial-companion')
    link:SetScript('OnEditFocusGained',function(self)self:HighlightText()end);link:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
    button(f,tr('Companion einrichten','Set up companion'),20,-424,220,function()C.Show()end)
end
