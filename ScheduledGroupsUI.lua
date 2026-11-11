-- Uses the established theme/controls and virtual scrolling. Domain and network
-- decisions remain in ScheduledGroups; open inputs are never overwritten by refresh.
local Z,L,A,S,T,U=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.ScheduledGroups,ZenialCommunity.ScheduleTime,ZenialCommunity.UI
local H
local function tr(v)return Z.T(v)end
local function selected()return S.Get(U.scheduledOwner,U.scheduledID)end
local function message(ok,reason)U.Message(ok and tr('Scheduled change saved.')or tr(reason));U.RefreshScheduledGroups()end
function U.CanForgetScheduled(e)
    if not e or e.ownerKey==Z.me.key then return false end
    local following=S.Follow(e.ownerKey,e.id)
    return following and not following.pending and(following.state=='NONE'or following.state=='WITHDRAWN'or following.state=='DECLINED'or e.status~='OPEN'or e.endsAt<=A.Now())or false
end
function U.ForgetScheduledActivity(key)
    local r=key and Z.ActivityBoard.Get(key)
    if not r or r.kind~='EVENT'or r.own then U.Message(tr('This activity is no longer available.'));U.RefreshActivityBoard();return end
    local e=S.Get(r.owner,r.id)
    if not e or e.ownerKey~=r.owner or e.ownerKey==Z.me.key or not U.CanForgetScheduled(e)then U.Message(tr('This activity is no longer available.'));U.RefreshActivityBoard();return end
    local ok,why=S.Forget(e.ownerKey,e.id)
    if not ok then U.Message(tr(why))end
    U.RefreshActivityBoard();U.Refresh()
end
function U.OpenScheduledEditor(e)
    U.scheduledEditingID=e and e.id;U.scheduledEditingRevision=e and e.revision
    U.scheduledActivity:SetText(e and e.activity or'Blackrock Depths')
    local draft=not e and Z.UIState.ActivityInput('scheduled')
    local at=e and e.startsAt or math.floor((A.Now()+3600)/60)*60
    local mode=T.Local(at)and'LOCAL'or'UTC';U.scheduledClock:SetText(mode);U.scheduledDate:SetText(T.Input(at,mode)or'')
    U.scheduledDuration:SetText(tostring(e and(e.endsAt-e.startsAt)/60 or 120));local ownRole=e and e.organizerRole or (L.Role(Z.db.roles)or'')
    for role,field in pairs(U.scheduledSlots)do field:SetText(tostring(math.max(0,(e and e.roleSlots[role]or(role=='DAMAGER'and 3 or 1))-(ownRole==role and 1 or 0))))end
    U.scheduledOrganizerRole:SetText(ownRole~=''and ownRole or'NONE');U.scheduledNote:SetText(e and e.note or'')
    U.scheduledEditorNotice:SetText(tr(e and'Editing a published event invalidates existing applications. Participants must apply again.'or''))
    if draft then
        U.scheduledEditingID=draft.editID~=''and draft.editID or nil;U.scheduledEditingRevision=draft.revision
        U.scheduledActivity:SetText(draft.activity or'');U.scheduledDate:SetText(draft.date or'');U.scheduledClock:SetText(draft.clock or'LOCAL')
        U.scheduledDuration:SetText(draft.duration or'120');U.scheduledOrganizerRole:SetText(draft.organizerRole or'NONE');U.scheduledNote:SetText(draft.note or'')
        for role,f in pairs(U.scheduledSlots)do f:SetText(draft[role]or'0')end
    end
    if U.scheduledEditingID then U.scheduledEditorNotice:SetText(tr('Editing a published event invalidates existing applications. Participants must apply again.'))end
    U.ConfigureScheduledActivity(nil,U.scheduledActivity:GetText());U.scheduledEditor:Show();U.Navigation.Pristine('scheduledEditor')
end
function U.SaveScheduledEditor()
    local starts,why=T.Parse(U.scheduledDate:GetText(),U.scheduledClock:GetText());if not starts then U.Message(tr(U.scheduledClock:GetText()=='LOCAL'and'Local date or time is invalid or ambiguous. Choose another time.'or why));return end
    if not L.Text(U.scheduledNote:GetText(),96,true)then U.Message(tr('Comment must be no more than 96 bytes.'));return end
    if not S.Enabled()then U.Message(tr('Publishing scheduled groups is unavailable.'));return end
    local owned=U.scheduledEditingID and S.GetOwned(U.scheduledEditingID);local public=0;for _,e in pairs(S.store.owned)do if e.status=='OPEN'and e.public then public=public+1 end end
    if not(owned and owned.public)and public>=S.MAX_PUBLIC then U.Message(tr('Publish no more than ten upcoming events.'));return end
    local input={activity=U.scheduledActivity:GetText(),startsAt=starts,duration=tonumber(U.scheduledDuration:GetText()),roleSlots={},note=U.scheduledNote:GetText(),organizerRole=U.scheduledOrganizerRole:GetText()}
    if input.organizerRole=='NONE'then input.organizerRole=''end
    if input.organizerRole~=''and input.organizerRole~='TANK'and input.organizerRole~='HEALER'and input.organizerRole~='DAMAGER'then U.Message(tr('Scheduled event fields are invalid.'));return end
    for role,field in pairs(U.scheduledSlots)do local n=tonumber(field:GetText());if not L.Int(n,0,40)then U.Message(tr("Scheduled event fields are invalid."));return end;input.roleSlots[role]=n end
    if input.organizerRole~=""then input.roleSlots[input.organizerRole]=input.roleSlots[input.organizerRole]+1 end
    local key,err
    if U.scheduledEditingID then local ok;ok,err=S.Edit(U.scheduledEditingID,input,U.scheduledEditingRevision);if ok then key=U.scheduledEditingID end
    else key,err=S.Create(input)end
    if key then local published,why=S.Publish(key);if not published then if not U.scheduledEditingID then S.DeleteDraft(key)end;U.Message(tr(why));return end;U.scheduledOwner,U.scheduledID=Z.me.key,key;U.scheduledEditor:Hide();Z.UIState.ActivityInput('scheduled',false);U.RefreshScheduledGroups();U.Refresh()else U.Message(tr(err))end
end
function U.OpenScheduledRecurrence(e)
    if not e then return end
    local key,why=S.SaveTemplate(e.id);if not key then U.Message(tr(why));return end
    U.scheduledTemplateID=key;U.scheduledSeriesCount:SetText('2');U.scheduledProposal=nil;U.scheduledSeriesCreate:SetEnabled(false);H.rows(U.scheduledSeriesPreview,{},64);U.scheduledSeries:Show();U.Navigation.Pristine('scheduledSeries')
end
function U.PreviewScheduledSeries()
    local preview,why=S.Preview(U.scheduledTemplateID,tonumber(U.scheduledSeriesCount:GetText()));U.scheduledProposal=preview;U.scheduledSeriesCreate:SetEnabled(preview~=nil)
    local rows={};for _,instance in ipairs(preview or{})do rows[#rows+1]={text=T.Format(instance.startsAt),height=66}end
    if not preview then rows={{text=tr(why),height=76}}end;H.rows(U.scheduledSeriesPreview,rows,66)
end
function U.LayoutScheduledDetails(infoHeight,peopleHeight,own)
    -- Fill the right column up to its action row. Reserve participant space
    -- only when there are participants; short information needs no scrollbar.
    local available=own and 280 or 264
    local people=peopleHeight>0 and math.min(peopleHeight,math.max(56,available-math.min(infoHeight,available-64)-8))or 0
    local height=available-(people>0 and people+8 or 0)
    U.scheduledDetails:SetHeight(height);U.scheduledDetails.height=height
    U.scheduledParticipants:SetShown(people>0)
    U.scheduledParticipants:SetHeight(math.max(1,people));U.scheduledParticipants.height=math.max(1,people)
    U.scheduledParticipants:ClearAllPoints();U.scheduledParticipants:SetPoint('TOPLEFT',284,-4-height-8)
end
function U.RefreshScheduledGroups()
    if not U.scheduledFrame then return end
    local source=S.List(U.scheduledArchive:GetChecked());local filter=U.scheduledFilter:GetText();local data={};local visibleSelection=false
    for _,e in ipairs(source)do if e.status~='DRAFT'and(filter=='ALL_EVENTS'or filter=='MY_EVENTS'and e.ownerKey==Z.me.key or filter=='MY_APPLICATIONS'and S.Follow(e.ownerKey,e.id))then
        data[#data+1]=e;if e.ownerKey==U.scheduledOwner and e.id==U.scheduledID then visibleSelection=true end
    end end
    local maxPage=math.max(1,math.ceil(#data/25));U.scheduledPage=math.min(U.scheduledPage or 1,maxPage)
    local first=(U.scheduledPage-1)*25+1;local items={}
    for i=first,math.min(first+24,#data)do local e=data[i];local own=e.ownerKey==Z.me.key;local c=Z.db.contacts[e.ownerKey];local name=own and Z.me.target or c and c.target or e.ownerTarget or e.ownerKey
        items[#items+1]={selected=e.ownerKey==U.scheduledOwner and e.id==U.scheduledID,text=U.ActivityName(e.activity)..' · '..S.StateLabel(e.status)..'\n'..T.Format(e.startsAt)..'\n'..name..' · '..S.Participation(e.ownerKey,e.id),height=82,click=function()
            U.scheduledOwner,U.scheduledID=e.ownerKey,e.id;U.scheduledParticipant=nil
            if not own then S.Query(e.ownerKey,e.id)end;U.RefreshScheduledGroups()
        end}
    end
    if not visibleSelection then U.scheduledOwner,U.scheduledID,U.scheduledParticipant,U.scheduledParticipantRevision=nil,nil,nil,nil end
    if U.scheduledDisplayedOwner~=U.scheduledOwner or U.scheduledDisplayedID~=U.scheduledID then
        for _,view in ipairs({U.scheduledDetails,U.scheduledParticipants})do view.zenialOffset=0;view:SetVerticalScroll(0)end
        U.scheduledDisplayedOwner,U.scheduledDisplayedID=U.scheduledOwner,U.scheduledID
    end
    H.rows(U.scheduledList,items,82);U.scheduledCount:SetText(Z.T('%d events · page %d/%d',#data,U.scheduledPage,maxPage)..(S.Loading()and' · '..tr('Loading')or''))
    U.scheduledPrev:SetEnabled(U.scheduledPage>1);U.scheduledNext:SetEnabled(U.scheduledPage<maxPage)
    U.scheduledStoreState:SetText(tr(not S.store and'Saved scheduled groups are unavailable. Data was preserved.'or S.loadError and'Invalid scheduled data was rejected.'or''))
    U.scheduledReminderHint:Hide()
    local e=selected();local own=e and e.ownerKey==Z.me.key
    U.scheduledConfirmHint:SetShown(own==true)
    U.scheduledRecreate:SetShown(own==true and(e.status=='CANCELLED'or e.status=='FINISHED'))
    U.scheduledRecreate:SetEnabled(own==true and(e.status=='CANCELLED'or e.status=='FINISHED'))
    U.scheduledRepeat:SetText(tr('Repeat weekly'))
    U.scheduledDelete:SetText(tr('Remove from my list'));U.scheduledDelete:SetShown(e~=nil and not own)
    for _,button in ipairs({U.scheduledApply,U.scheduledWithdraw,U.scheduledEdit,U.scheduledPublish,U.scheduledCancel,U.scheduledRepeat,U.scheduledConfirm,U.scheduledWaitlist,U.scheduledDecline,U.scheduledDelete,U.scheduledRecreate})do button:SetEnabled(false)end
    H.showControl(U.scheduledRole,e~=nil and not own);U.scheduledApply:SetShown(e~=nil and not own);U.scheduledWithdraw:SetShown(e~=nil and not own)
    for _,button in ipairs({U.scheduledConfirm,U.scheduledWaitlist,U.scheduledDecline})do button:SetShown(own==true)end
    for _,button in ipairs({U.scheduledEdit,U.scheduledPublish,U.scheduledCancel,U.scheduledRepeat})do button:SetShown(own==true)end
    if not e then U.LayoutScheduledDetails(48,0,false);H.rows(U.scheduledDetails,{{text=tr('Select a scheduled event.'),height=48}},48);H.rows(U.scheduledParticipants,{},56);return end
    local following=S.Follow(e.ownerKey,e.id);local used=e.participants and S.Counts(e)or e.used
    local details={{text=U.ActivityName(e.activity)..' · '..S.StateLabel(e.status),height=40},{text=T.Format(e.startsAt)..' – '..T.Format(e.endsAt),height=56},
        {text=tr(S.Reach(e.ownerKey))..'\n'..S.Participation(e.ownerKey,e.id),height=48}}

    local free={};for _,role in ipairs({'TANK','HEALER','DAMAGER'})do free[#free+1]=Z.Locale.Role(role)..': '..(used and tostring(math.max(0,e.roleSlots[role]-used[role]))or tr('Unknown'))..'/'..e.roleSlots[role]end
    details[#details+1]={text=tr('Free roles: ')..table.concat(free,' · '),height=40}
    if following then details[#details+1]={text=tr('Delivery: ')..S.DeliveryLabel(following.delivery),height=40}end
    if e.note~=''then details[#details+1]={text=e.note,height=96}end
    local infoHeight=0
    for _,row in ipairs(details)do
        U.scheduledMeasure:SetText(row.text);row.height=math.max(28,U.scheduledMeasure:GetStringHeight()+10);infoHeight=infoHeight+row.height
    end
    local people={};if own then
        if e.organizerRole~=''then people[#people+1]={text=Z.me.target..' · '..Z.Locale.Role(e.organizerRole)..' · '..tr('Organizer'),height=48}end
        local keys={};for key in pairs(e.participants)do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys)do local p=e.participants[key];local c=Z.db.contacts[key];people[#people+1]={selected=key==U.scheduledParticipant,text=(c and c.target or key)..' · '..Z.Locale.Role(p.role)..'\n'..S.StateLabel(p.state)..' · '..tr(S.ParticipantStatus(key)),height=56,click=function()U.scheduledParticipant=key;U.scheduledParticipantRevision=p.revision;U.RefreshScheduledGroups()end}end
        U.scheduledConfirm:SetEnabled(S.CanDecide(e.id,U.scheduledParticipant,'CONFIRMED',U.scheduledParticipantRevision)==true)
        U.scheduledWaitlist:SetEnabled(S.CanDecide(e.id,U.scheduledParticipant,'WAITLIST',U.scheduledParticipantRevision)==true)
        U.scheduledDecline:SetEnabled(S.CanDecide(e.id,U.scheduledParticipant,'DECLINED',U.scheduledParticipantRevision)==true)
        U.scheduledEdit:SetEnabled(e.status=='OPEN'and e.startsAt>A.Now());U.scheduledPublish:Hide()
        U.scheduledCancel:SetEnabled(e.status=='OPEN');U.scheduledRepeat:SetEnabled(true)
        U.scheduledRecreate:SetEnabled(e.status=='CANCELLED'or e.status=='FINISHED')
    else
        U.scheduledDelete:SetEnabled(U.CanForgetScheduled(e))
        if following then people={{text=Z.Locale.Role(following.role)..' · '..S.Participation(e.ownerKey,e.id),height=56}}end
        U.scheduledApply:SetEnabled(S.CanApply(e.ownerKey,e.id)==true);U.scheduledWithdraw:SetEnabled(S.CanWithdraw(e.ownerKey,e.id)==true)
    end
    local peopleHeight=0;for _,row in ipairs(people)do peopleHeight=peopleHeight+row.height end
    U.LayoutScheduledDetails(infoHeight,peopleHeight,own)
    H.rows(U.scheduledDetails,details,48);H.rows(U.scheduledParticipants,people,56)
end
function U.CreateScheduledGroups(parent,helpers)
    H=helpers;local label,button,list,edit,selector=H.label,H.button,H.list,H.edit,H.selector
    local f=CreateFrame('Frame',nil,parent);U.scheduledFrame=f;f:SetPoint('TOPLEFT',0,-36);f:SetSize(856,414)
    U.scheduledFilter=selector(f,'Events',0,0,250,{'ALL_EVENTS','MY_EVENTS','MY_APPLICATIONS'},function()U.scheduledPage=1;U.RefreshScheduledGroups()end,function(v)return tr(({ALL_EVENTS='All scheduled events',MY_EVENTS='My scheduled events',MY_APPLICATIONS='My scheduled applications'})[v])end)
    U.scheduledCount=label(f,'',0,-47,260);U.scheduledList=list(f,0,-72,238,218)
    U.scheduledPrev=button(f,tr('Previous'),0,-304,118,function()U.scheduledPage=(U.scheduledPage or 1)-1;U.scheduledOwner,U.scheduledID,U.scheduledParticipant,U.scheduledParticipantRevision=nil,nil,nil,nil;U.RefreshScheduledGroups()end)
    U.scheduledNext=button(f,tr('Next'),132,-304,118,function()U.scheduledPage=(U.scheduledPage or 1)+1;U.scheduledOwner,U.scheduledID,U.scheduledParticipant,U.scheduledParticipantRevision=nil,nil,nil,nil;U.RefreshScheduledGroups()end)
    U.scheduledArchive=H.checkbox(f,'Show archived events',0,-335,260,function()U.scheduledPage=1;U.RefreshScheduledGroups()end)
    U.scheduledNew=button(f,tr('New event'),0,-374,118,function()U.OpenActivityCreator();U.creatorWhen:SetText('PLANNED')end)
    U.scheduledDelete=button(f,tr('Remove from my list'),132,-374,118,function()local e=selected();if e and e.ownerKey~=Z.me.key then message(S.Forget(e.ownerKey,e.id))end end,'danger')
    U.scheduledStoreState=label(f,'',284,-335,548);U.scheduledStoreState:SetHeight(30)
    U.scheduledStoreState:ClearAllPoints();U.scheduledStoreState:SetPoint('TOPLEFT',284,-402)
    U.scheduledDetails=list(f,284,-4,548,134);U.scheduledParticipants=list(f,284,-148,548,124)
    U.scheduledMeasure=label(f,'',0,0,500);U.scheduledMeasure:SetWordWrap(true);U.scheduledMeasure:Hide()
    U.scheduledRole=selector(f,'My role',284,-278,140,{'TANK','HEALER','DAMAGER'})
    U.scheduledApply=button(f,tr('Apply'),438,-295,126,function()local e=selected();if e then message(S.Apply(e.ownerKey,e.id,U.scheduledRole:GetText()))end end,'primary')
    U.scheduledWithdraw=button(f,tr('Withdraw'),578,-295,254,function()local e=selected();if e then message(S.Withdraw(e.ownerKey,e.id))end end)
    local function decision(state)local e=selected();if e then
        local ok,why=S.Decide(e.id,U.scheduledParticipant,state,U.scheduledParticipantRevision)
        if ok then U.scheduledParticipantRevision=e.participants[U.scheduledParticipant].revision end
        message(ok,why)
    end end
    U.scheduledConfirm=button(f,tr('Confirm participant'),284,-295,174,function()decision('CONFIRMED')end,'primary')
    U.scheduledWaitlist=button(f,tr('Waitlist'),468,-295,174,function()decision('WAITLIST')end)
    U.scheduledDecline=button(f,tr('Decline'),652,-295,180,function()decision('DECLINED')end,'danger')
    local hint=label(f,tr('Local reminders run only while WoW and the addon are running.'),284,-335,548);hint:SetHeight(30);U.scheduledReminderHint=hint
    U.scheduledEdit=button(f,tr('Edit'),284,-374,124,function()U.OpenScheduledEditor(selected())end)
    U.scheduledPublish=button(f,tr('Publish'),418,-374,124,function()local e=selected();if e then message(S.Publish(e.id))end end,'primary')
    U.scheduledCancel=button(f,tr('Cancel event'),552,-374,136,function()local e=selected();if e then message(S.Cancel(e.id,e.revision))end end,'danger')
    U.scheduledRepeat=button(f,tr('Repeat weekly'),698,-374,134,function()U.OpenScheduledRecurrence(selected())end)
    U.scheduledRecreate=button(f,tr('Create again'),418,-374,124,function()local e=selected();if e then U.RecreateActivity('EVENT:'..e.ownerKey..':'..e.id)end end,'primary')
    U.scheduledConfirmHint=label(f,tr('Confirming records attendance only. It does not invite anyone to your group.'),284,-335,548,'GameFontHighlightSmall');U.scheduledConfirmHint:SetHeight(30);U.scheduledConfirmHint:SetWordWrap(true);U.scheduledConfirmHint:Hide()
    U.scheduledEditor=H.panel(U.frame);local form=U.scheduledEditor;form:ClearAllPoints();form:SetPoint('CENTER',U.frame,'CENTER',0,0);form:SetSize(650,510)
    U.scheduledFormTitle=label(form,tr('Scheduled event'),16,-16,618,'GameFontNormalLarge')
    U.scheduledActivity=edit(form,'Activity',16,-58,618,64)
    U.scheduledDate=edit(form,'Date and time: YYYY-MM-DD HH:MM',16,-116,300,32)
    U.scheduledClock=selector(form,'Input timezone',338,-116,280,{'LOCAL','UTC'},nil,function(v)return tr(v=='LOCAL'and'Client local time'or'UTC')end)
    U.scheduledDuration=edit(form,'Duration (minutes)',16,-176,180,3);U.scheduledOrganizerRole=selector(form,'Organizer role',216,-176,402,{'NONE','TANK','HEALER','DAMAGER'})
    U.scheduledSlots={};for i,role in ipairs({'TANK','HEALER','DAMAGER'})do U.scheduledSlots[role]=edit(form,Z.Locale.Role(role)..' '..tr('slots'),16+(i-1)*208,-238,194,2)end
    U.scheduledNote=edit(form,'Note',16,-300,618,192,true);U.scheduledNote:SetHeight(54)
    U.scheduledEditorNotice=label(form,'',16,-388,618);U.scheduledEditorNotice:SetHeight(62)
    U.scheduledSave=button(form,tr('Save event'),16,-464,294,U.SaveScheduledEditor,'primary')
    U.scheduledBack=button(form,tr('Back'),324,-464,140,function()U.BackActivityStep()end);U.scheduledEditorCancel=button(form,tr('Cancel'),478,-464,140,function()form:Hide()end);H.makeModal(form);form:Hide()
    U.scheduledSeries=H.panel(U.frame);local series=U.scheduledSeries;series:ClearAllPoints();series:SetPoint('CENTER',U.frame,'CENTER',0,0);series:SetSize(650,450)
    U.scheduledSeriesTitle=label(series,tr('Weekly instances: same organizer local time'),16,-16,618,'GameFontNormalLarge')
    U.scheduledSeriesRule=label(series,tr('Review the dates. Create events publishes these dates with empty participant lists.'),16,-56,618);U.scheduledSeriesRule:SetHeight(40)
    U.scheduledSeriesCount=edit(series,'Number of instances',16,-132,200,1);U.scheduledSeriesCount:SetScript('OnTextChanged',function()U.scheduledProposal=nil;if U.scheduledSeriesCreate then U.scheduledSeriesCreate:SetEnabled(false)end end)
    U.scheduledSeriesPreviewButton=button(series,tr('Preview dates'),240,-149,184,U.PreviewScheduledSeries)
    U.scheduledTemplateDelete=button(series,tr('Delete template'),434,-149,184,function()if S.DeleteTemplate(U.scheduledTemplateID)then U.scheduledProposal=nil;series:Hide();U.RefreshScheduledGroups()end end,'danger')
    U.scheduledSeriesPreview=list(series,16,-194,594,168)
    U.scheduledSeriesCreate=button(series,tr('Create events'),16,-400,294,function()
        local keys,why=S.GenerateAndPublish(U.scheduledTemplateID,U.scheduledProposal);if keys then U.scheduledOwner,U.scheduledID=Z.me.key,keys[1];series:Hide();U.RefreshScheduledGroups()else U.Message(tr(why))end
    end,'primary');U.scheduledSeriesCreate:SetEnabled(false)
    U.scheduledSeriesCancel=button(series,tr('Cancel'),324,-400,294,function()series:Hide()end);H.makeModal(series);series:Hide();f:Hide()
end
