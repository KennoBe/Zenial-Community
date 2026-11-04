local Z,U,P=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.PvPHelp
local H
local function tr(s,...)return Z.T(s,...)end
local function place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y);if w then f:SetWidth(w)end;if h then f:SetHeight(h)end
end
local function sizeList(f,x,y,w,h)
    local changed=f:GetWidth()~=w or f:GetHeight()~=h
    place(f,x,y,w,h);f.width=w-24;f.height=h;f.child:SetWidth(f.width);if changed and f.zenialRender then f.zenialRender()end
end
local function state(r)
    return tr(r.closed and'Completed'or r.expires<=Z.Adapter.Now()and'Expired'or not Z.IsOnline(r.key)and r.key~=Z.me.key and'Offline'or'Active')
end
function U.LayoutPvPHelp()
    if not U.pvpUnified then return end
    local width=U.pages[3]:GetWidth();local height=math.max(414,U.pages[3]:GetHeight()-48);local col=(width-16)/2
    U.groupPvpFrame:SetSize(width,height)
    place(U.pvpMinePanel,0,0,col,174);U.pvpMineBase:SetSize(col,174)
    U.pvpMineStatus:SetWidth(col-24);U.pvpMineStatus:SetHeight(90)
    place(U.pvpStart,0,-100,math.min(230,col-24),26)
    place(U.pvpOwnControls,0,-100,col-24,28)
    for i,b in ipairs(U.pvpOwnActionButtons)do place(b,(i-1)*(col-24)/2,0,(col-32)/2,26)end
    place(U.pvpShowHelpers,0,-136,col-24,26)
    place(U.pvpSignupPanel,col+16,0,col,174)
    U.pvpSignupTitle:SetWidth(col-24)
    place(U.pvpReceive,col-38,-40,24,24);place(U.pvpReceive.text,12,-38,col-60,52)
    place(U.pvpScope.caption,12,-102,col-24,18);U.pvpScope:SetWidth(col-24);place(U.pvpScope.button,12,-123,col-24,26)
    place(U.pvpRecentTitle,0,-188,width,20)
    place(U.pvpCallsPanel,0,-216,width,height-216)
    local body=height-216;sizeList(U.pvpCallList,0,0,col,body)
    sizeList(U.pvpCallDetailList,col+16,0,col,math.max(60,body-72))
    local bw=(col-16)/3
    for i,b in ipairs({U.pvpCome,U.pvpMap,U.pvpWhisper})do place(b,col+16+(i-1)*(bw+8),-body+64,bw,26)end
    place(U.pvpWaypoint,col+16,-body+32,(col-8)/2,26);place(U.pvpBlock,col+24+(col-8)/2,-body+32,(col-8)/2,26)
end
function U.RefreshPvPPage()
    if not P.store or not U.pvpUnified then return end
    U.LayoutPvPHelp();U.pvpMinePanel:Show();U.pvpCallsPanel:Show();U.pvpReceive:Show();U.pvpReceive.text:Show();H.showControl(U.pvpScope,true)
    U.pvpReceive:SetChecked(P.store.receive);U.pvpScope:SetText(P.store.scope=='zone'and'CURRENT_ZONE'or'ALL_ZONES');U.pvpScope.button:SetEnabled(P.store.receive)
    local o=P.Own();local can,why=P.CanCall()
    U.pvpMineBase:Show();U.pvpStart:SetShown(not o);U.pvpStart:SetEnabled(can==true);U.pvpOwnControls:SetShown(o~=nil);U.pvpShowHelpers:SetShown(o~=nil)
    U.pvpHeaderButton:SetText(tr(o and'PvP help active'or'PvP Help'))
    local broadcast=o and tr(({queued='Broadcast queued',sent='Broadcast sent',error='Broadcast failed'})[o.broadcastState]or'Waiting to broadcast')
    U.pvpMineStatus:SetText(o and(tr('ACTIVE PVP HELP REQUEST')..'\n'..P.FormatLocation(o)..'\n'..tr('%d minutes remaining · %d volunteers',math.max(0,math.ceil((o.expires-Z.Adapter.Now())/60)),P.ComingCount())..' · '..broadcast)
        or tr('My help request')..'\n'..tr('Recorded deaths in the last 60 minutes: %d / 2',P.DeathCount())..'\n'..(can and tr('You can now prepare a PvP help request.')or tr(why)))
    U.pvpShowHelpers:SetText(tr('Volunteers (%d)',P.ComingCount()))
    if o then
        local items={};local selected=false
        for key,response in pairs(o.responses)do if not Z.db.blocked[key]then
            local peer=key;local c=Z.db.contacts[key];selected=selected or peer==U.pvpHelperKey
            if peer==U.pvpHelperKey and U.pvpHelpers:IsShown()then Z.Notifications.ReadVisible('groups','pvp','pvp:'..o.id..':'..peer)end
            items[#items+1]={key=key,selected=peer==U.pvpHelperKey,text=(c and c.target or key)..'\n'..tr(response.state=='coming'and'Coming to help'or'Commitment withdrawn'),click=function()U.pvpHelperKey=peer;Z.Notifications.ReadVisible('groups','pvp','pvp:'..o.id..':'..peer);U.RefreshPvPPage()end}
        end end
        table.sort(items,function(a,b)return a.key<b.key end);if not selected then U.pvpHelperKey=nil end
        H.rows(U.pvpHelperList,items,48);U.pvpHelperCount:SetText(tr('Volunteers (%d)',P.ComingCount()))
        local hr=U.pvpHelperKey and o.responses[U.pvpHelperKey];U.pvpInvite:SetEnabled(hr and hr.state=='coming'and Z.IsOnline(U.pvpHelperKey)or false);U.pvpHelperWhisper:SetEnabled(hr~=nil and Z.IsOnline(U.pvpHelperKey))
    else U.pvpHelpers:Hide();U.pvpHelperKey=nil;H.rows(U.pvpHelperList,{},48)end
    if o then U.pvpPreviewOpen=false;U.pvpPreview:Hide()end
    local items={};local selected=false
    for _,r in ipairs(P.ListCalls())do
        local key,id=r.key,r.id;local c=Z.db.contacts[key];local active=P.IsActive(r)
        selected=selected or key==U.pvpCallKey and id==U.pvpCallID
        local attackers=(r.note or'')~=''and'\n'..tr('Attackers')..': '..r.note or''  -- known once the details were fetched
        items[#items+1]={selected=key==U.pvpCallKey and id==U.pvpCallID,text=(c and c.target or key==Z.me.key and Z.me.target or key)..' · '..state(r)..'\n'..P.FormatLocation(r)..attackers..'\n'..Z.ScheduleTime.Format(r.at),height=attackers~=''and 90 or 72,
            accent=active and{.3,.75,.3,1}or{.5,.5,.5,1},click=function()U.SelectPvpCall(key,id)end}
    end
    if not selected then U.pvpCallKey,U.pvpCallID=nil,nil end
    H.rows(U.pvpCallList,items,72);U.pvpRecentTitle:SetText(tr('Help requests in the last 2 hours (%d)',#items))
    local r=U.pvpCallKey and P.GetCall(U.pvpCallKey,U.pvpCallID);local details={}
    if r then
        local c=Z.db.contacts[r.key];local active=P.IsActive(r);local own=r.key==Z.me.key
        details={{text=(c and c.target or own and Z.me.target or r.key)..' · '..state(r),height=38},{text=P.FormatLocation(r),height=48},{text=Z.ScheduleTime.Format(r.at),height=40}}
        if (r.note or'')~=''then details[#details+1]={text=tr('Attackers')..': '..r.note,height=60}end
        if r.enemy then details[#details+1]={text=tr('Targeted enemy')..': '..r.enemy.name..(r.enemy.class~=''and' · '..r.enemy.class or'')..(r.enemy.level>0 and' · '..tr('Level %d',r.enemy.level)or''),height=48}end
        if r.response=='coming'then details[#details+1]={text=tr('Your commitment was sent.'),height=32}end
        U.pvpCome:SetText(tr(r.response=='coming'and'Withdraw commitment'or"I'm coming"));U.pvpCome:SetEnabled(active and not own)
        U.pvpMap:SetEnabled(r.mapID>0);U.pvpWaypoint:SetEnabled(active and not own and r.hasPos);U.pvpWhisper:SetEnabled(not own and c~=nil);U.pvpBlock:SetEnabled(not own)
    else
        details={{text=tr('Select a help request.'),height=40}}
        for _,b in ipairs({U.pvpCome,U.pvpMap,U.pvpWaypoint,U.pvpWhisper,U.pvpBlock})do b:SetEnabled(false)end
    end
    for _,b in ipairs({U.pvpCome,U.pvpMap,U.pvpWaypoint,U.pvpWhisper,U.pvpBlock})do b:Show()end
    H.rows(U.pvpCallDetailList,details,40);U.pvpCallDetail:Hide();U.UpdateBadges()
end
function U.CreatePvPHelpPage(helpers)
    H=helpers;U.pvpUnified=true;U.groupPvpFrame.zenialOwnLayout=true
    U.pvpSignupPanel=H.panel(U.groupPvpFrame);U.pvpSignupTitle=H.label(U.pvpSignupPanel,'Offer PvP help',12,-12,380,'GameFontNormal')
    U.pvpReceive:SetParent(U.pvpSignupPanel);U.pvpReceive.text:SetParent(U.pvpSignupPanel)
    U.pvpReceive.text:SetText(tr('I want to help. Notify me when someone needs help.'));U.pvpReceive.text:SetWordWrap(true)
    U.pvpScope.button:SetParent(U.pvpSignupPanel);U.pvpScope.caption:SetParent(U.pvpSignupPanel);U.pvpScope.popup:SetParent(U.pvpSignupPanel)
    U.pvpRecentTitle=H.label(U.groupPvpFrame,'',0,-188,856,'GameFontNormal')
    U.pvpCallDetailList=H.list(U.pvpCallsPanel,420,0,425,136)
    U.pvpOwnActionButtons={};for _,w in ipairs(U.layoutWidgets)do if w.parent==U.pvpOwnControls and w.kind=='button'then U.pvpOwnActionButtons[#U.pvpOwnActionButtons+1]=w.frame end end
    U.pvpHelpers=H.panel(U.frame);U.pvpHelpers:SetSize(600,330);U.pvpHelpers:ClearAllPoints();U.pvpHelpers:SetPoint('CENTER',U.frame,'CENTER',90,0);H.makeModal(U.pvpHelpers);U.pvpHelpers:Hide()
    U.pvpHelperCount:SetParent(U.pvpHelpers);place(U.pvpHelperCount,16,-16,568,22)
    U.pvpHelperList:SetParent(U.pvpHelpers);sizeList(U.pvpHelperList,16,-50,568,208)
    U.pvpInvite:SetParent(U.pvpHelpers);place(U.pvpInvite,16,-280,174,26)
    U.pvpHelperWhisper:SetParent(U.pvpHelpers);place(U.pvpHelperWhisper,206,-280,174,26)
    H.button(U.pvpHelpers,tr('Close'),396,-280,188,function()U.pvpHelpers:Hide()end)
    U.pvpShowHelpers=H.button(U.pvpMineContent,'',0,-136,380,function()U.CloseDialogs();U.pvpHelpers:Show();U.RefreshPvPPage()end)
    U.pvpPreview:SetParent(U.frame);U.pvpPreview:ClearAllPoints();U.pvpPreview:SetPoint('CENTER',U.frame,'CENTER',90,0);U.pvpPreview:SetSize(650,380)
    U.pvpPreviewLocation:SetWidth(626);U.pvpPreviewEnemy:SetWidth(626)
    place(U.pvpCallNote.caption,0,-116,626,28);place(U.pvpCallNote,0,-148,626,54)
    place(U.pvpShareEnemy,0,-214,24,24);place(U.pvpShareEnemy.text,27,-218,599,20)
    place(U.pvpConfirm,0,-246,24,24);place(U.pvpConfirm.text,27,-250,599,20)
    place(U.pvpSend,0,-310,300,26);place(U.pvpCancel,316,-310,310,26)
    H.makeModal(U.pvpPreview);U.pvpPreview:HookScript('OnHide',function()U.pvpPreviewOpen=false;U.pvpCallNote:ClearFocus()end)
    U.LayoutPvPHelp()
end
return U
