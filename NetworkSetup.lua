local Z,D,B=ZenialCommunity,ZenialCommunity.CommunityDirectory,ZenialCommunity.BattleNetTransport
local S={};Z.NetworkSetup=S
S.DISCORD_URL="https://discord.gg/wow-forever-deutsch"
local function tr(value,...)return Z.T(value,...)end
local function label(parent,text,x,y,width,height)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f:SetPoint("TOPLEFT",x,y);f:SetWidth(width);f:SetHeight(height or 24);f:SetJustifyH("LEFT");f:SetJustifyV("TOP");f:SetText(tr(text));return f
end
local function button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,26);b:SetText(tr(text));b:SetScript("OnClick",fn);if Z.Theme then Z.Theme.StyleButton(b)end;return b
end
local function edit(parent,x,y,width,max,multi)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");e:SetPoint("TOPLEFT",x,y);e:SetSize(width,multi and 170 or 24);e:SetAutoFocus(false);e:SetMaxLetters(max);e:SetFontObject("GameFontHighlightSmall");e:SetMultiLine(multi==true)
    e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);if Z.Theme then Z.Theme.StyleEditBox(e)end;return e
end
-- Addons cannot read installation paths. Battle.net exposes the product that
-- selects _classic_beta_ through agentUID; do not infer beta from realm names.
function S.IsUnsupportedBeta()
    local product=Z.Adapter.Call(C_CVar and C_CVar.GetCVar or GetCVar,"agentUID")
    return type(product)=="string"and product:lower()=="wow_classic_beta"
end
function S.ShowBetaNotice()
    if not Z.db or not Z.identityReady or Z.Adapter.Call(InCombatLockdown)==true then return end
    if not S.betaFrame then
        local de=Z.Adapter.Call(GetLocale)=="deDE"
        local f=CreateFrame("Frame","ZenialCommunityBetaNotice",UIParent,BackdropTemplateMixin and"BackdropTemplate"or nil);S.betaFrame=f
        f:SetSize(520,245);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true)
        if Z.Theme then Z.Theme.Panel(f,"stone")end
        label(f,de and"Bis bald im Release!"or"See you at release!",20,-18,460,24)
        label(f,de and"Die BETA wird nicht mehr unterstützt. ZenialCommunity und der Companion funktionieren nur noch mit der Release-Version.\n\nWir freuen uns auf euch am 05.11.! Kommt bis dahin auf unseren Discord:"or"The BETA is no longer supported. ZenialCommunity and the companion now work only with the release version.\n\nSee you on 5 November! Join our Discord until then:",20,-53,480,105)
        S.betaEdit=edit(f,22,-166,476,180,false);S.betaEdit:SetText(S.DISCORD_URL)
        S.betaEdit:SetScript("OnEditFocusGained",function(self)self:HighlightText()end)
        S.betaEdit:SetScript("OnMouseUp",function(self)self:HighlightText()end)
        S.betaEdit:SetScript("OnTextChanged",function(self)if self:GetText()~=S.DISCORD_URL then self:SetText(S.DISCORD_URL)end end)
        label(f,de and"Link anklicken und mit Strg+C kopieren."or"Click the link and press Ctrl+C to copy.",20,-204,450,24)
        local close=Z.UI.CloseButton(f,-4,-4,function()f:Hide()end)
        f:SetScript("OnHide",function()S.betaEdit:ClearFocus()end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityBetaNotice"end
    end
    if S.joinFrame then S.joinFrame:Hide()end
    if S.frame then S.frame:Hide()end
    if Z.Companion and Z.Companion.ui then Z.Companion.ui:Hide()end
    S.betaFrame:Show()
    -- Separate from release onboarding so beta acknowledgement cannot suppress it.
    Z.db.betaUnsupportedNoticeSeen=true
end
function S.Message(text)
    if S.message then S.message:SetText(tr(text or""))end
    if S.joinMessage then S.joinMessage:SetText(tr(text or""))end
end
function S.SelectText(field)
    field:HighlightText()
    -- SetFocus can run a forbidden Blizzard field's OnEditFocusLost in addon
    -- context. Let a normal user click transfer keyboard focus instead.
    if not field:HasFocus()then S.Message("Click the text field, then press Ctrl+A and Ctrl+C.")end
end
function S.Refresh()
    if not S.frame or not D.config then return end
    local state,transport=D.Status(),B.Status();local parts={tr("Assigned lounges: %d/%d joined",state.joined,math.max(1,state.assigned))}
    if state.assigned==0 then parts[#parts+1]=D.DISPLAY_NAME.." · "..tr("Join the lounge to resolve its ID.")end
    for _,id in ipairs(D.config.assignment)do for _,row in ipairs(D.config.groups)do if row.id==id then parts[#parts+1]=row.name.." ("..string.format("%.0f",id)..")"end end end
    S.assignment:SetText(table.concat(parts,"\n"))
    local available=D.AvailableGroups();S.available=available
    S.groupIndex=math.max(1,math.min(S.groupIndex or 1,#available));local selected=available[S.groupIndex]
    if S.inviteGroup~=(selected and selected.id)then
        S.inviteGroup=selected and selected.id;local invite=""
        for _,row in ipairs(D.config.groups)do if row.id==S.inviteGroup then invite=row.invite;break end end
        S.invite:SetText(invite)
    end
    S.groupName:SetText(selected and(selected.name.." ("..string.format("%.0f",selected.id)..")")or tr("No joined Battle.net groups available."))
    if not selected then
        for _,row in ipairs(D.clientClubs or{})do if row.name:lower()==D.BOOTSTRAP_NAME:lower()and row.clubType==1 then
            S.groupName:SetText(tr("%s: WoW character community, not a Battle.net lounge",row.name));break
        end end
    end
    S.add:SetEnabled(selected~=nil);S.previous:SetEnabled(#available>1);S.next:SetEnabled(#available>1)
    S.mode:SetText(tr("Mode: direct network without channel"))
    local issue=state.joined==0 and#available==0 and D.SetupIssue()or D.ownProfileMissing and D.OWN_PROFILE_HINT or state.state
    S.status:SetText(tr(issue).."\n"..tr("Roster: %d/%d · eligible game accounts: %d",state.scanned,state.total,state.candidates).."\n"..tr("Confirmed: Battle.net %d · addon whisper %d · pending %d",transport.bnet,transport.whisper,transport.pending))
    if state.candidates==0 then
        local reasons={};for reason,n in pairs(D.scanReasons or{})do reasons[#reasons+1]={reason=reason,n=n}end
        table.sort(reasons,function(a,b)if a.n~=b.n then return a.n>b.n end;return a.reason<b.reason end)
        local parts={};for i=1,math.min(3,#reasons)do parts[#parts+1]=reasons[i].reason.."="..reasons[i].n end
        if #parts>0 then S.status:SetText(S.status:GetText().."\n"..tr("Excluded accounts: %s",table.concat(parts,", ")))end
    end
    local rows={};for _,route in pairs(B.routes or{})do rows[#rows+1]=route.name.." · "..route.transport end;table.sort(rows)
    while#rows>4 do table.remove(rows)end
    if #rows>0 then S.confirmed:SetText(table.concat(rows,"\n"))
    else
        local stats=B.stats or{}
        local lines={"BNET registered="..tostring(transport.registered).." · available="..tostring(B.Available()),
            tr("Sent: %d · received: %d · rejected: %d · timeouts: %d",stats.sent or 0,stats.received or 0,stats.rejected or 0,stats.timeouts or 0)}
        if transport.lastError~=""then lines[#lines+1]=tr("Last error")..": "..transport.lastError end
        local events=Z.Diagnostics and Z.Diagnostics.events or{}
        for i=#events,1,-1 do if events[i]:find(" bnet:rejected ",1,true)then lines[#lines+1]=events[i];break end end
        S.confirmed:SetText(table.concat(lines,"\n"))
    end
end
function S.UserSummary()
    if not Z.db or not Z.db.consent then return tr("Community exchange is disabled.")end
    if not Z.db.autoDiscovery then return tr("Community member search is paused.")end
    local missing,ready=S.MissingGroup()
    if missing then return tr("Join the community to connect.")end
    if not ready then return tr("Checking community membership.")end
    local transport=B.Status()
    if(transport.bnet or 0)+(transport.whisper or 0)>0 then return tr("Connected to the community.")end
    if D.ownProfileMissing then return tr(D.OWN_PROFILE_HINT)end
    return tr("Searching for active community members.")
end
function S.RefreshOverview()
    if not S.overviewStatus then return end
    S.overviewStatus:SetText(S.UserSummary())
    S.overviewMessage:SetText(tr(S.overviewMessageKey or ""))
end
function S.CreateOverview()
    if S.overviewFrame then return end
    local f=CreateFrame("Frame","ZenialCommunityConnectionOverview",UIParent,BackdropTemplateMixin and"BackdropTemplate"or nil);S.overviewFrame=f
    f:SetSize(560,315);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true)
    if Z.Theme then Z.Theme.Panel(f,"stone")end
    label(f,"Community connection",24,-24,500,32)
    S.overviewStatus=label(f,"",24,-82,500,56)
    label(f,"Connect with other players to find members and community activity.",24,-145,500,48)
    S.overviewMessage=label(f,"",24,-196,500,36)
    S.overviewRefresh=button(f,"Refresh connection",24,-245,210,function()
        S.overviewMessageKey="Connection check started. It may take a moment."
        D.RequestScan();local ok=B.Test()
        if not ok then S.overviewMessageKey="The connection cannot be checked yet. Please try again shortly."end
        S.RefreshOverview()
    end)
    if Z.Theme then Z.Theme.StyleButton(S.overviewRefresh,"primary")end
    S.overviewInvite=button(f,"Invitation link",244,-245,128,function()S.ShowInvite()end)
    S.overviewAdvanced=button(f,"Technical details",382,-245,154,function()S.ShowAdvanced()end)
    button(f,"Close",406,-282,130,function()f:Hide()end)
    f:SetScript("OnHide",function()S.overviewMessageKey=nil;if S.linkFrame then S.linkFrame:Hide()end end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityConnectionOverview"end
    local elapsed=0;f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;S.RefreshOverview()end end)
    f:Hide()
end
function S.ShowOverview()
    if S.IsUnsupportedBeta()then return S.ShowBetaNotice()end
    if S.frame then S.frame:Hide()end;if S.joinFrame then S.joinFrame:Hide()end
    if S.linkFrame then S.linkFrame:Hide()end
    S.CreateOverview();S.RefreshOverview();S.overviewFrame:Show()
end
function S.ShowCatalog()
    if not S.catalogFrame then
        local f=CreateFrame("Frame","ZenialCommunityCatalogImport",S.frame,BackdropTemplateMixin and"BackdropTemplate"or nil);S.catalogFrame=f;f:SetSize(760,300);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:EnableMouse(true)
        if Z.Theme then Z.Theme.Panel(f,"stone")end
        label(f,"Group catalog: copy this text or paste the operator's catalog.",15,-15,720,35)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",15,-55);scroll:SetSize(705,170)
        if Z.Theme then Z.Theme.StyleScroll(scroll);Z.Theme.AttachScrollWheel(scroll,42)end
        S.catalogEdit=edit(scroll,0,0,680,20000,true);scroll:SetScrollChild(S.catalogEdit)
        S.catalogEdit:SetScript("OnEscapePressed",function()f:Hide()end)
        S.catalogEdit:SetScript("OnTextChanged",function(self)self:SetHeight(math.max(170,(select(2,(self:GetText()or""):gsub("\n",""))+1)*14))end)
        button(f,"Select all",15,-250,130,function()S.SelectText(S.catalogEdit)end)
        S.catalogApply=button(f,"Import catalog",155,-250,150,function()local ok,error=D.ImportCatalog(S.catalogEdit:GetText());S.Message(ok and"Group catalog saved."or error);if ok then f:Hide();S.Refresh()end end)
        button(f,"Close",625,-250,110,function()f:Hide()end)
        f:SetScript("OnHide",function()S.catalogEdit:ClearFocus()end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityCatalogImport"end
    end
    S.catalogEdit:SetText(D.ExportCatalog());S.catalogFrame:Show();S.SelectText(S.catalogEdit)
end
function S.RefreshInvite()
    local rows=S.invitationRows or{};S.linkGroupIndex=math.max(1,math.min(S.linkGroupIndex or 1,#rows))
    local row=rows[S.linkGroupIndex];S.invitationLink=row and row.invite or""
    S.linkName:SetText(row and(row.name.." ("..S.linkGroupIndex.."/"..#rows..")")or"")
    S.linkEdit:SetText(S.invitationLink);S.linkPrevious:SetEnabled(#rows>1);S.linkNext:SetEnabled(#rows>1)
end
function S.ShowInvite()
    if not S.linkFrame then
        local f=CreateFrame("Frame","ZenialCommunityInvite",UIParent,BackdropTemplateMixin and"BackdropTemplate"or nil);S.linkFrame=f;f:SetSize(760,200);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:EnableMouse(true);if Z.Theme then Z.Theme.Panel(f,"stone")end
        label(f,"Click the text field, then press Ctrl+A and Ctrl+C.",15,-15,720,35)
        S.linkName=label(f,"",15,-52,620,24)
        S.linkPrevious=button(f,"<",655,-49,32,function()S.linkGroupIndex=(S.linkGroupIndex-2)%#S.invitationRows+1;S.RefreshInvite()end)
        S.linkNext=button(f,">",695,-49,32,function()S.linkGroupIndex=S.linkGroupIndex%#S.invitationRows+1;S.RefreshInvite()end)
        S.linkEdit=edit(f,15,-86,720,180,false)
        S.linkEdit:SetScript("OnEscapePressed",function()f:Hide()end)
        S.linkEdit:SetScript("OnEditFocusGained",function(self)self:HighlightText()end)
        S.linkEdit:SetScript("OnMouseUp",function(self)self:HighlightText()end)
        S.linkEdit:SetScript("OnTextChanged",function(self)if S.invitationLink and self:GetText()~=S.invitationLink then self:SetText(S.invitationLink)end end)
        button(f,"Select all",15,-153,130,function()S.SelectText(S.linkEdit)end)
        button(f,"Close",625,-153,110,function()f:Hide()end);f:SetScript("OnHide",function()S.linkEdit:ClearFocus()end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityInvite"end
    end
    local links={};for _,id in ipairs(D.config.assignment)do for _,row in ipairs(D.config.groups)do if row.id==id then links[#links+1]=row end end end
    if#links==0 then links[1]={name=D.DISPLAY_NAME,invite=D.BOOTSTRAP_INVITE}end
    S.invitationRows=links;S.linkGroupIndex=1
    for i,row in ipairs(links)do if row.id==S.inviteGroup then S.linkGroupIndex=i;break end end
    S.RefreshInvite();S.linkFrame:Show();S.SelectText(S.linkEdit)
end
function S.Create()
    if S.frame then return end
    local f=CreateFrame("Frame","ZenialCommunityNetworkSetup",UIParent,BackdropTemplateMixin and"BackdropTemplate"or nil);S.frame=f;f:SetSize(810,580);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    if Z.Theme then Z.Theme.Panel(f,"stone")end
    label(f,"Battle.net network · 4.0",15,-15,740,24)
    label(f,"Set up ZENIAL Community to find members and offers. Public entries are shared; private requests go directly to their owner.",15,-44,775,48)
    S.assignment=label(f,"",15,-98,555,64);button(f,"Invitation links",590,-100,190,S.ShowInvite)
    button(f,"Next group pair",590,-132,190,function()D.ChoosePair(true);D.CatalogChanged();S.Refresh()end)
    label(f,"Operator: choose a joined Battle.net group and add its invite link.",15,-171,760,24)
    S.previous=button(f,"<",15,-201,32,function()S.groupIndex=(S.groupIndex or 1)-1;if S.groupIndex<1 then S.groupIndex=#S.available end;S.Refresh()end)
    S.groupName=label(f,"",55,-205,475,30)
    S.next=button(f,">",535,-201,32,function()S.groupIndex=(S.groupIndex or 1)%math.max(1,#S.available)+1;S.Refresh()end)
    S.invite=edit(f,15,-235,550,180,false)
    S.invite:SetScript("OnEscapePressed",function()f:Hide()end)
    S.add=button(f,"Add/update group",590,-235,190,function()local row=S.available[S.groupIndex or 1];if row then local ok,error=D.AddGroup(row.id,S.invite:GetText());S.Message(ok and"Group catalog saved."or error);S.Refresh()end end)
    button(f,"Copy/import catalog",590,-201,190,S.ShowCatalog)
    S.mode=label(f,"",15,-275,560,24)
    S.status=label(f,"",15,-307,775,58)
    S.test=button(f,"Test Battle.net",15,-377,180,function()local ok,error=B.Test();S.Message(ok and"Connection test started."or error);S.Refresh()end)
    button(f,"Refresh groups",205,-377,170,function()D.RequestScan();S.Refresh()end)
    button(f,"Join in WoW",385,-377,190,function()S.OpenJoinDialog()end)
    button(f,"Copy diagnostics",590,-377,190,function()Z.UI.ShowDiagnostics()end)
    label(f,"Addon whisper test: full character name (first and last name)",15,-414,760,22)
    S.target=edit(f,15,-441,550,49,false)
    S.target:SetScript("OnEscapePressed",function()f:Hide()end)
    S.whisper=button(f,"Test addon whisper",590,-441,190,function()local ok,error=B.Test(S.target:GetText());S.Message(ok and"Connection test started."or error);S.Refresh()end)
    S.confirmed=label(f,"",15,-480,555,65);S.message=label(f,"",590,-480,190,55)
    button(f,"Close",650,-542,130,function()f:Hide()end)
    f:SetScript("OnHide",function()S.invite:ClearFocus();S.target:ClearFocus();if S.catalogFrame then S.catalogFrame:Hide()end;if S.linkFrame then S.linkFrame:Hide()end end)
    local elapsed=0;f:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;S.Refresh()end end);f:Hide()
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityNetworkSetup"end
end
function S.MissingGroup()
    if not D.config then return nil,false end
    local groups,ready=D.AvailableGroups();if not ready then return nil,false end
    local joined={};for _,row in ipairs(groups)do joined[row.id]=true end
    for _,id in ipairs(D.config.assignment)do if not joined[id]then
        for _,row in ipairs(D.config.groups)do if row.id==id then return row,true end end
    end end
    if #D.config.groups==0 then return{id=0,name=D.BOOTSTRAP_NAME,invite=D.BOOTSTRAP_INVITE},true end
    return nil,true
end
-- Same conditions as the automatic prompt in S.Tick: no membership is needed without consent or discovery.
function S.NeedsJoin()
    if not D.config or not Z.db or not Z.identityReady or S.IsUnsupportedBeta()then return false end
    if not Z.db.consent or not Z.db.autoDiscovery then return false end
    local row,ready=S.MissingGroup()
    return ready==true and row~=nil
end
function S.ShowJoin(row)
    if S.IsUnsupportedBeta()then return S.ShowBetaNotice()end
    if not S.joinFrame then
        local f=CreateFrame("Frame","ZenialCommunityJoin",UIParent,BackdropTemplateMixin and"BackdropTemplate"or nil);S.joinFrame=f
        f:SetSize(520,580);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true)
        if Z.Theme then Z.Theme.Panel(f,"stone")end
        local function gold(region)if Z.Theme then Z.Theme.Tint(region,"SetTextColor","gold")end;return region end
        S.joinTitle=gold(label(f,"Welcome to ZENIAL Community",20,-18,440,24));S.joinTitle:SetFontObject("GameFontNormalLarge")
        S.joinReason=label(f,"To see members, groups and offers, join ZENIAL Community once.",20,-50,480,34)
        S.joinStepTitles={}
        local function step(index,y,height,title)
            local p=CreateFrame("Frame",nil,f,BackdropTemplateMixin and"BackdropTemplate"or nil);p:SetPoint("TOPLEFT",16,y);p:SetSize(488,height)
            if Z.Theme then Z.Theme.Panel(p,"surface")end
            S.joinStepTitles[index]=gold(label(p,"",12,-8,464,18));S.joinStepTitles[index]:SetText(index.."  "..tr(title))
            return p
        end
        local copy=step(1,-88,88,"Copy the link")
        S.joinEdit=edit(copy,16,-30,336,180,false)
        S.joinEdit:SetScript("OnEditFocusGained",function(self)self:HighlightText()end)
        S.joinEdit:SetScript("OnMouseUp",function(self)self:HighlightText();S.Message("Press Ctrl+C. Then open the join window and press Ctrl+V.")end)
        S.joinEdit:SetScript("OnTextChanged",function(self)if S.joinLink and self:GetText()~=S.joinLink then self:SetText(S.joinLink)end end)
        S.joinCopy=button(copy,"Select link",360,-29,116,function()S.SelectText(S.joinEdit);S.Message("Click the link field and press Ctrl+C.")end)
        label(copy,"Click the field and press Ctrl+C.",12,-62,464,20)
        S.joinOpen=button(step(2,-182,66,"Open the join window"),"Open join window",12,-30,250,S.OpenJoinDialog)
        if Z.Theme then Z.Theme.StyleButton(S.joinOpen,"primary")end
        S.joinSteps=label(step(3,-254,66,"Paste and join"),"Press Ctrl+V in the join window and confirm. This window then closes by itself.",12,-30,464,32)
        S.joinStatus=gold(label(f,"Not joined yet",20,-326,480,18))
        S.joinMessage=label(f,"",20,-346,480,20)
        if Z.Companion and Z.Companion.AddIntroductionToJoin then Z.Companion.AddIntroductionToJoin(f,-372)end
        S.joinClose=Z.UI.CloseButton(f,-4,-4,function()f:Hide()end)
        f:SetScript("OnHide",function()S.joinEdit:ClearFocus()end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ZenialCommunityJoin"end
    end
    S.joinGroup=row.id;S.joinLink=row.invite~=""and row.invite or D.BOOTSTRAP_INVITE;S.joinEdit:SetText(S.joinLink);S.joinMessage:SetText("")
    S.joinFrame:ClearAllPoints();S.joinFrame:SetPoint("CENTER")
    if S.frame then S.frame:Hide()end;if S.overviewFrame then S.overviewFrame:Hide()end;if S.linkFrame then S.linkFrame:Hide()end
    S.joinFrame:Show();S.prompted=true;Z.db.networkSetupSeen=true
    if Z.Companion then Z.Companion.MarkIntroductionSeen();Z.Companion.RefreshUI()end
end
function S.ShowAdvanced()
    if S.IsUnsupportedBeta()then return S.ShowBetaNotice()end
    if S.joinFrame then S.joinFrame:Hide()end;if S.overviewFrame then S.overviewFrame:Hide()end
    if S.linkFrame then S.linkFrame:Hide()end
    S.Create();S.Refresh();S.frame:Show()
end
function S.Show()
    if S.IsUnsupportedBeta()then return S.ShowBetaNotice()end
    local row=S.MissingGroup()
    if row then S.ShowJoin(row)else S.ShowOverview()end
end
function S.Tick()
    local now=Z.Adapter.Clock();S.loginReadyAt=S.loginReadyAt or now+5
    if now<(S.nextCheck or 0)then return end;S.nextCheck=now+1
    if Z.UI and Z.UI.frame and Z.UI.frame:IsShown()then Z.UI.RefreshJoinBanner()end
    if not D.config or not Z.db or not Z.identityReady then return end
    if S.IsUnsupportedBeta()then
        if not Z.db.betaUnsupportedNoticeSeen and now>=S.loginReadyAt then S.ShowBetaNotice()end
        return
    end
    if not Z.db.consent or not Z.db.autoDiscovery then if S.joinFrame then S.joinFrame:Hide()end;return end
    if Z.Companion and Z.Companion.ui and Z.Companion.ui:IsShown()then return end
    local row,ready=S.MissingGroup();if not ready then return end
    if not row then if S.joinFrame then S.joinFrame:Hide()end;return end
    if Z.Adapter.Call(InCombatLockdown)==true then return end
    if S.joinFrame and S.joinFrame:IsShown()then
        if S.joinGroup~=row.id then S.ShowJoin(row)end
    elseif not S.prompted and not Z.db.networkSetupSeen and now>=S.loginReadyAt then S.ShowJoin(row)end
end
function S.OpenJoinDialog()
    if Z.Adapter.Call(InCombatLockdown)==true then S.Message("Open the join dialog after combat.");return false end
    if C_AddOns and C_AddOns.LoadAddOn then Z.Adapter.Call(C_AddOns.LoadAddOn,"Blizzard_Communities")end
    if type(securecall)~="function"or type(AddCommunitiesFlow_Toggle)~="function"then S.Message("Paste the invite in Guilds & Communities > Join Community.");return false end
    if S.frame then S.frame:Hide()end
    if S.joinFrame and S.joinFrame:IsShown()then
        -- Keep the copy instructions available without stealing native focus.
        -- Move before the native input opens; never SetFocus from addon code.
        S.joinFrame:ClearAllPoints();S.joinFrame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-20,-140)
        S.Message("Paste with Ctrl+V in the join window, then join.")
    end
    local function open()
        if Z.Adapter.Call(InCombatLockdown)==true then return end
        if type(ToggleCommunitiesFrame)=="function"and not(CommunitiesFrame and CommunitiesFrame:IsShown())then securecall(ToggleCommunitiesFrame)end
        if type(AddCommunitiesFlow_IsShown)~="function"or not securecall(AddCommunitiesFlow_IsShown)then securecall(AddCommunitiesFlow_Toggle)end
        -- Do not show/focus addon dialogs after the native dialog takes focus.
    end
    if C_Timer and type(C_Timer.After)=="function"then C_Timer.After(0,open)else open()end
    return true
end
