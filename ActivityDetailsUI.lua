-- One modal for all activity sources, retaining their existing action authority.
local Z,U,A,B,S=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter,ZenialCommunity.ActivityBoard,ZenialCommunity.ScheduledGroups
local H
local function tr(s)return Z.T(s)end
local function current()
    local r=U.activityDetailKey and B.Get(U.activityDetailKey);if not r then return end
    if r.kind=='EVENT'and not S.Get(r.owner,r.id)then return end
    if r.own and r.kind=='LIVE'and(not Z.db.lfg[1]or Z.db.lfg[1].id~=r.id)then return end
    if r.own and r.kind=='QUEST'and(not Z.db.quest or Z.db.quest.id~=r.id)then return end
    return r
end
local function state(r)
    if r.kind=='EVENT'then return S.Participation(r.owner,r.id)end
    if r.kind=='PVP'then return tr(r.data and r.data.response=='coming'and'Coming'or'No application')end
    local bucket=r.kind=='QUEST'and Z.db.sentQuestApplications or Z.db.sentApplications
    local p=bucket[r.id]and bucket[r.id][r.owner];return p and Z.Locale.State(p.state)or tr('No application'),p
end
local function whisperTarget(r)
    if not r then return end
    local key=r.own and U.activityParticipantKey or r.owner
    if not key or key==Z.me.key or Z.db.blocked[key]then return end
    local c=Z.db.contacts[key]
    local target=c and c.target or not r.own and r.data and r.data.ownerTarget
    if target and Z.Logic.Identity(target)and Z.ResolvePeerKey(target)==key then return target end
end
-- The selected participant of an own activity, otherwise the organizer.
local function diaryPlayer(r)
    if not r then return end
    local key=r.own and U.activityParticipantKey or r.owner
    if not key or key==Z.me.key or Z.db.blocked[key]then return end
    local c=Z.db.contacts[key]
    return key,c and c.target or not r.own and r.data and r.data.ownerTarget or nil
end
function U.ActivityActionState(r)
    local result={join=false,withdraw=false,whisper=false,diary=false,edit=false,manage=false,archive=false,repeatSeries=false}
    if not r then return result end
    result.whisper=whisperTarget(r)~=nil
    result.diary=diaryPlayer(r)~=nil
    if r.own then
        local e=r.kind=='EVENT'and S.Get(r.owner,r.id)or r.data
        result.edit=r.kind~='PVP'and(r.kind~='EVENT'or e and(e.status=='OPEN'or e.status=='DRAFT')and e.startsAt>A.Now())or false
        result.manage=r.kind~='PVP'
        result.archive=r.kind~='PVP'and(r.kind~='EVENT'or e and e.status=='OPEN')or false
        result.repeatSeries=r.kind=='EVENT'and S.GetOwned(r.id)~=nil
        return result
    end
    local _,p=state(r);local e=r.kind=='EVENT'and S.Get(r.owner,r.id)or r.data
    local can=r.kind=='EVENT'and(S.CanApply(r.owner,r.id)==true or Z.ScheduledRelay~=nil and Z.ScheduledRelay.CanApply(r.owner,r.id))or r.kind~='EVENT'and not r.saved and Z.IsOnline(r.owner)and(not p or p.state=='withdrawn')
    if r.kind=='PVP'then can=e and e.response~='coming'and Z.IsOnline(r.owner)end
    result.join=can==true
    local withdraw=r.kind=='EVENT'and S.CanWithdraw(r.owner,r.id)or r.kind~='EVENT'and(p and p.state~='withdrawn'or r.kind=='PVP'and e and e.response=='coming')
    result.withdraw=withdraw and true or false
    return result
end
local function canInviteParticipant(r,e,p,key,revision)
    local pending=U.activityInvitePending and U.activityInvitePending[r.key..':'..tostring(key)]
    return p~=nil and p.state=='CONFIRMED'and e.status=='OPEN'and e.endsAt>A.Now()
        and p.revision==revision and Z.db.contacts[key]~=nil and not Z.db.blocked[key]
        and Z.IsOnline(key)and A.GroupState().canInvite==true and not A.GroupMembers()[key]
        and not(pending and pending>A.Clock())
end
local function pendingInvite(r,key)
    U.activityInvitePending=U.activityInvitePending or{};local now=A.Clock();local oldest,untilAt
    for token,expiry in pairs(U.activityInvitePending)do
        if expiry<=now then U.activityInvitePending[token]=nil elseif not untilAt or expiry<untilAt then oldest,untilAt=token,expiry end
    end
    if Z.Logic.Count(U.activityInvitePending)>=256 and oldest then U.activityInvitePending[oldest]=nil end
    U.activityInvitePending[r.key..':'..key]=now+30
end
function U.InviteConfirmedParticipants(all)
    local r=current();local e=r and r.own and r.kind=='EVENT'and S.GetOwned(r.id);if not e then return end
    local keys={};if all then for key,p in pairs(e.participants)do if p.state=='CONFIRMED'then keys[#keys+1]={key=key,revision=p.revision}end end
    elseif U.activityParticipantKey then keys[1]={key=U.activityParticipantKey,revision=U.activityParticipantRevision}end
    table.sort(keys,function(a,b)return a.key<b.key end)
    local sent,failed,last=0,0,nil
    for _,item in ipairs(keys)do local p=e.participants[item.key]
        if canInviteParticipant(r,e,p,item.key,item.revision)then
            local ok,why=A.Invite(Z.db.contacts[item.key].target)
            if ok then pendingInvite(r,item.key);sent=sent+1 else failed=failed+1;last=why end
        end
    end
    U.Message(all and Z.T('%d invitations sent; %d failed.',sent,failed)or sent>0 and tr('Invitation submitted; awaiting response.')or tr(last or'Inviting is temporarily unavailable.'))
    U.RefreshActivityDetails()
end
function U.LayoutActivityDetails(r,infoHeight,peopleHeight)
    local own=r and r.own;local controls=r and not own and(r.kind=='EVENT'or r.kind=='LIVE'or r.kind=='QUEST')
    local available=(own and 438 or controls and 480 or 492)-90
    local participants=own and peopleHeight>0 and math.min(peopleHeight,math.max(44,available-math.min(infoHeight,260)-24))or 0
    local height=available-(participants>0 and participants+24 or controls and 76 or 0)
    U.activityInformation:SetHeight(height);U.activityInformation.height=height
    U.activityParticipants:SetShown(participants>0);U.activityParticipantLabel:SetShown(participants>0)
    if participants>0 then
        U.activityParticipantLabel:ClearAllPoints();U.activityParticipantLabel:SetPoint('TOPLEFT',16,-90-height-6)
        U.activityParticipants:ClearAllPoints();U.activityParticipants:SetPoint('TOPLEFT',16,-90-height-24);U.activityParticipants:SetHeight(participants);U.activityParticipants.height=participants
    end
    if controls then
        for _,f in ipairs({U.activityDetailRole,U.activityDetailNote})do
            local x=f==U.activityDetailRole and 16 or 224;local y=-90-height-12
            f.caption:ClearAllPoints();f.caption:SetPoint('TOPLEFT',x,y)
            local control=f.button or f;control:ClearAllPoints();control:SetPoint('TOPLEFT',x,y-30)
        end
    end
    for _,f in ipairs({U.activityInformation,U.activityParticipants})do if f.zenialRender then f.zenialRender()end end
end
function U.OpenActivity(key)
    local r=B.Get(key);if not r then U.Message(tr('This activity is no longer available.'));return false,'target-unavailable' end
    local N=U.Navigation
    if Z.db.blocked[r.owner]then return N.Fail('target-unavailable')end
    if U.activityDetailKey==key and U.activityDetails:IsShown()then U.RefreshActivityDetails();return true end
    if N.UnsavedInput()then return N.Fail('unsaved-input')end
    U.CloseDialogs();U.activityDetailKey=key;U.activityParticipantKey=nil;U.activityDetailNote:SetText('')
    U.activityDetailRole:SetText(Z.Logic.Role(Z.db.roles)or'DAMAGER')
    if r.kind=='EVENT'and not r.own then S.Query(r.owner,r.id)elseif r.kind=='PVP'and not r.own then Z.PvPHelp.RequestDetails(r.owner,r.id)end
    U.activityDetails:Show();U.RefreshActivityDetails()
    return true
end
function U.ActivityWhisper(key)
    local r=key and B.Get(key);local target=r and whisperTarget(r)
    if not target then return end
    if not A.Whisper(target)then U.Message(tr('Whisper is unavailable.'))end
end
function U.ActivityDiary(key)
    local r=key and B.Get(key);local player,target=r and diaryPlayer(r)
    if player then U.OpenSocialDiary(player,target)end
end
local function actionRecord(key)
    local r=key and B.Get(key)
    if not r then U.Message(tr('This activity is no longer available.'));U.RefreshActivityBoard();return end
    if Z.db.blocked[r.owner]then U.Message(tr('This activity is no longer available.'));U.RefreshActivityBoard();return end
    return r
end
function U.ArchiveActivity(key)
    local r=actionRecord(key);if not r or not r.own or r.owner~=Z.me.key then return end
    if not U.ActivityActionState(r).archive then return end
    U.RequestActivityArchive(r.kind,r.id)
end
function U.RepeatActivity(key)
    local r=actionRecord(key);if not r or not r.own or r.owner~=Z.me.key then return end
    if not U.ActivityActionState(r).repeatSeries then return end
    U.OpenScheduledRecurrence(S.GetOwned(r.id))
end
function U.RefreshActivityDetails()
    if not U.activityDetails then return end
    local r=current()
    for _,b in ipairs({U.activityJoin,U.activityWithdraw,U.activityAccept,U.activityReject,U.activityWaitlist,U.activityEdit,U.activityWhisper,U.activityInvite,U.activityInviteAll,U.activityArchiveAction,U.activityDiary})do b:SetEnabled(false)end
    U.activityArchiveAction:SetShown(r~=nil and r.own and U.ActivityActionState(r).archive)
    if not r then U.activityDetailTitle:SetText(tr('This activity is no longer available.'));H.rows(U.activityInformation,{},44);H.rows(U.activityParticipants,{},42);U.LayoutActivityDetails(nil,0,0);return end
    local actionState=U.ActivityActionState(r)
    U.activityArchiveAction:SetText(tr(r.kind=='EVENT'and'Cancel event'or'Archive activity'))
    local e=r.kind=='EVENT'and S.Get(r.owner,r.id)or r.data
    U.activityDetailTitle:SetText(Z.Locale.Activity(r.title))
    -- Opening a chat does not require a current addon-presence report.
    U.activityWhisper:SetEnabled(actionState.whisper)
    U.activityDiary:SetEnabled(actionState.diary)
    -- The information is a block of facts, not a list: flat rows without cells (nothing here can be clicked).
    -- item.text stays the data contract; display dims the label and brightens the value.
    local K=Z.Kit;local details={}
    local function fact(text,display,height,measure)details[#details+1]={text=text,display=display,flat=true,textInset=0,height=height,measure=measure}end
    local function labelled(label,value,height,valueKey)fact(label..value,K.Fact(label,value,valueKey),height)end
    local when=' · '..tr(r.kind=='EVENT'and'Scheduled'or'Now')
    fact(r.ownerName..when,K.Paint('text',r.ownerName)..K.Paint('dim',when),32)
    if r.kind=='EVENT'and not r.own then
        local reach=tr(S.Reach(r.owner));fact(reach,K.Paint('textSoft',reach),32)
        local following=S.Follow(r.owner,r.id)
        if following then labelled(tr('Delivery: '),S.DeliveryLabel(following.delivery),32)end
    elseif r.kind=='EVENT'and r.own then
        local hint=tr('Confirming records attendance only. It does not invite anyone to your group.');fact(hint,K.Paint('dim',hint),42)
    end
    local party=Z.ActivityParty.Info(r)
    local capacity=r.kind=='EVENT'and(e.roleSlots.TANK+e.roleSlots.HEALER+e.roleSlots.DAMAGER)or e and e.size
    labelled(tr('Current party size')..': ',(party and party.total or tr('Unknown'))..(capacity and' / '..capacity or''),32)
    if r.kind=='EVENT'then
        local starts=Z.ScheduleTime.Format(e.startsAt);fact(starts,K.Paint('text',starts),42)
        local participation=S.Participation(r.owner,r.id)..' · '..S.StateLabel(e.status);fact(participation,K.Paint('textSoft',participation),48)
        local used=party and party.used or e.participants and S.Counts(e)or e.used;local roles,parts={},{}
        for _,role in ipairs({'TANK','HEALER','DAMAGER'})do roles[#roles+1]=Z.Locale.Role(role)..': '..(used and tostring(math.max(0,e.roleSlots[role]-used[role]))or tr('Unknown'))..'/'..e.roleSlots[role];parts[#parts+1]={role,roles[#roles]}end
        fact(tr('Free roles: ')..table.concat(roles,' · '),K.Paint('dim',tr('Free roles: '))..K.Roles(parts),40)
    elseif e then
        if e.min then
            local level,range=tr('Level')..' ',e.min..' – '..e.max
            local sizeLabel,size=e.size and' · '..tr('Target size')..': 'or'',e.size and tostring(e.size)or''
            fact(level..range..sizeLabel..size,K.Fact(level,range)..(e.size and K.Fact(sizeLabel,size)or''),32)
        end
        if r.kind=='LIVE'then
            local parts={{'TANK',e.tank..' '..Z.Locale.Role('TANK')},{'HEALER',e.healer..' '..Z.Locale.Role('HEALER')},{'DAMAGER',e.dd..' '..Z.Locale.Role('DAMAGER')}}
            local needed=tr('Needed')..': '
            fact(needed..parts[1][2]..' · '..parts[2][2]..' · '..parts[3][2],K.Paint('dim',needed)..K.Roles(parts),36)
        end
        -- The line about your own application only makes sense on someone else's activity.
        if not r.own then local applied=state(r);fact(applied,K.Paint('textSoft',applied),32)end
    else local saved=tr('Saved application; organizer data is unavailable.');fact(saved,K.Paint('warning',saved),42)end
    if e and e.note and e.note~=''then
        -- The comment gets a caption so a bare note is not mistaken for another fact.
        local caption=tr('Comment')
        fact(e.note,K.Paint('goldDim',K.Upper(caption))..'\n'..K.Paint('text',e.note),math.max(42,math.ceil(#e.note/65)*16+12)+14,caption..'\n'..e.note)
    end
    local infoHeight=0
    for _,item in ipairs(details)do
        U.activityInformationMeasure:SetText(item.measure or item.text)
        item.height=math.max(24,(A.Call(U.activityInformationMeasure.GetStringHeight,U.activityInformationMeasure)or item.height-14)+12)
        infoHeight=infoHeight+item.height
    end
    H.rows(U.activityInformation,details,42)
    H.showControl(U.activityDetailRole,not r.own and(r.kind=='LIVE'or r.kind=='EVENT'))
    H.showControl(U.activityDetailNote,not r.own and(r.kind=='LIVE'or r.kind=='QUEST'))
    U.activityJoin:SetShown(not r.own);U.activityWithdraw:SetShown(not r.own);U.activityEdit:SetShown(r.own and r.kind~="PVP")
    U.activityParticipants:SetShown(r.own)
    U.activityAccept:SetShown(r.own);U.activityReject:SetShown(r.own and r.kind~='PVP')
    U.activityWaitlist:SetShown(r.own and r.kind=='EVENT')
    U.activityInvite:SetShown(r.own and r.kind=='EVENT')
    U.activityInviteAll:SetShown(r.own and r.kind=='EVENT')
    if not r.own then
        U.activityJoin:SetEnabled(actionState.join)
        U.activityWithdraw:SetEnabled(actionState.withdraw)
        U.LayoutActivityDetails(r,infoHeight,0);return
    end
    U.activityEdit:SetEnabled(actionState.edit)
    U.activityArchiveAction:SetEnabled(actionState.archive)
    U.activityArchiveAction:SetText(tr(r.kind=='EVENT'and'Cancel event'or'Archive activity'))
    local source=r.kind=='EVENT'and e.participants or r.kind=='QUEST'and Z.db.questInterests[r.id]or r.kind=='PVP'and e.responses or Z.db.interests[r.id]
    local people={};local keys={};for key in pairs(source or{})do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys)do local p=source[key];local who=key;local c=Z.db.contacts[key]
        people[#people+1]={selected=key==U.activityParticipantKey,text=(c and c.target or key)..' · '..(r.kind=='EVENT'and S.StateLabel(p.state)or Z.Locale.State(p.state))..'\n'..(p.role and Z.Locale.Role(p.role)or''),height=44,click=function()
            U.SelectActivityParticipant(who)
        end}
    end
    H.rows(U.activityParticipants,people,44);U.LayoutActivityDetails(r,infoHeight,#people*44)
    local p=source and source[U.activityParticipantKey]
    local ready=false
    if p and not Z.db.blocked[U.activityParticipantKey]then
        if r.kind=='EVENT'then ready=p.revision==U.activityParticipantRevision and e.status=='OPEN'and e.startsAt>A.Now()and S.Enabled()and(p.state=='REQUESTED'or p.state=='CONFIRMED'or p.state=='WAITLIST')
        elseif r.kind=='PVP'then ready=p.state=='coming'
        else ready=p.state=='applied'end
    end
    if r.kind=='EVENT'then
        U.activityAccept:SetEnabled(S.CanDecide(r.id,U.activityParticipantKey,'CONFIRMED',U.activityParticipantRevision)==true)
        U.activityReject:SetEnabled(S.CanDecide(r.id,U.activityParticipantKey,'DECLINED',U.activityParticipantRevision)==true)
        U.activityWaitlist:SetEnabled(S.CanDecide(r.id,U.activityParticipantKey,'WAITLIST',U.activityParticipantRevision)==true)
        U.activityInvite:SetEnabled(canInviteParticipant(r,e,p,U.activityParticipantKey,U.activityParticipantRevision)==true)
        for key,participant in pairs(e.participants)do if canInviteParticipant(r,e,participant,key,participant.revision)then U.activityInviteAll:SetEnabled(true);break end end
    else U.activityAccept:SetEnabled(ready and true or false);U.activityReject:SetEnabled(ready and true or false);U.activityWaitlist:SetEnabled(false)end
    U.activityAccept:SetText(tr(r.kind=='EVENT'and'Confirm participant'or r.kind=='PVP'and'Invite'or'Accept & invite'))
end
function U.SelectActivityParticipant(key)
    local r=current();if not r or not r.own or not key then return end
    local e=r.kind=='EVENT'and S.GetOwned(r.id)or r.data
    local source=r.kind=='EVENT'and e and e.participants or r.kind=='QUEST'and Z.db.questInterests[r.id]or r.kind=='PVP'and e and e.responses or Z.db.interests[r.id]
    local p=source and source[key];if not p then return end
    U.activityParticipantKey=key;U.activityParticipantRevision=p.revision
    if r.kind=='EVENT'then Z.Notifications.Read('schedule:'..Z.me.key..':'..r.id..':'..key)
    elseif r.kind=='LIVE'or r.kind=='QUEST'then Z.Logic.MarkApplicationsRead(Z.db,r.kind=='QUEST'and'quest'or'group',r.id,key)end
    if r.kind=='LIVE'or r.kind=='QUEST'then Z.Notifications.Read('application:'..(r.kind=='QUEST'and'quest'or'group')..':'..r.id..':'..key)end
    U.RefreshActivityDetails();U.UpdateBadges()
end
function U.JoinActivity(key)
    local r=actionRecord(key or U.activityDetailKey);if not r or r.own then return end
    local ok,why
    local role=key and(Z.Logic.Role(Z.db.roles)or'DAMAGER')or U.activityDetailRole:GetText()
    local note=key and''or U.activityDetailNote:GetText()
    if r.kind=='EVENT'then ok,why=S.Apply(r.owner,r.id,role)
    elseif r.kind=='LIVE'then ok,why=Z.ApplyGroup(r.owner,r.id,role,note)
    elseif r.kind=='QUEST'then ok,why=Z.ApplyQuest(r.owner,r.id,note)
    else ok,why=Z.PvPHelp.Respond(r.owner,r.id,'coming')end
    U.Message(ok and tr('Application submitted; awaiting response.')or tr(why));U.RefreshActivityDetails();U.Refresh()
end
function U.WithdrawActivity(key)
    local r=actionRecord(key or U.activityDetailKey);if not r or r.own then return end;local ok,why
    if r.kind=='EVENT'then ok,why=S.Withdraw(r.owner,r.id)elseif r.kind=='LIVE'then ok,why=Z.WithdrawGroup(r.owner,r.id)elseif r.kind=='QUEST'then ok,why=Z.WithdrawQuest(r.owner,r.id)else ok,why=Z.PvPHelp.Respond(r.owner,r.id,'withdrawn')end
    U.Message(ok and tr('Withdrawal submitted.')or tr(why));U.RefreshActivityDetails();U.Refresh()
end
function U.EditActivity(key)
    local r=actionRecord(key or U.activityDetailKey);if not r or not r.own then return end
    if not U.ActivityActionState(r).edit then return end
    U.activityDetailKey=r.key
    local f=U.activityDetails;f:Hide();U.creatorFlow=false
    if r.kind=='EVENT'then U.OpenScheduledEditor(S.GetOwned(r.id))elseif r.kind=='LIVE'then U.OpenGroupEditor(r.data)elseif r.kind=='QUEST'then U.OpenQuestEditor(r.data)end
end
function U.DecideActivity(decision)
    local r=current();if not r or not r.own or not U.activityParticipantKey or Z.db.blocked[U.activityParticipantKey]then return end
    if r.kind=='EVENT'then
        local ok,why=S.Decide(r.id,U.activityParticipantKey,decision,U.activityParticipantRevision)
        if ok then U.activityParticipantRevision=S.GetOwned(r.id).participants[U.activityParticipantKey].revision end
        U.Message(ok and tr('Scheduled change saved.')or tr(why))
    elseif r.kind=='LIVE'then U.groupApplicantKey=U.activityParticipantKey;U.DecideGroupApplicant(decision=='CONFIRMED'and'invited'or'rejected')
    elseif r.kind=='QUEST'then U.questApplicantKey=U.activityParticipantKey;U.DecideQuestApplicant(decision=='CONFIRMED'and'invited'or'rejected')elseif r.kind=='PVP'and decision=='CONFIRMED'then local ok,why=Z.PvPHelp.InviteHelper(U.activityParticipantKey);if not ok then U.Message(tr(why))end end
    U.RefreshActivityDetails()
end
function U.CreateActivityDetails(helpers)
    H=helpers;local f=H.panel(U.frame);U.activityDetails=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,550)
    U.activityDetailTitle=H.label(f,'',16,-18,442,'GameFontNormalLarge');U.activityDetailTitle:SetHeight(40)
    -- Dialog head with the title; the two actions sit in their own row below it.
    Z.Kit.DialogHeader(f,U.activityDetailTitle,function()f:Hide()end)
    U.activityWhisper=H.button(f,tr('Whisper'),304,-54,160,function()
        -- Release the modal's keyboard capture before focusing native chat.
        U.CloseDialogs()
        U.ActivityWhisper(U.activityDetailKey)
    end)
    U.activityArchiveAction=H.button(f,tr('Archive activity'),474,-54,160,function()
        local r=current();if r and r.own then U.RequestActivityArchive(r.kind,r.id)end
    end,'danger')
    U.activityInformation=Z.Kit.InfoBlock(H.list(f,16,-90,594,180))
    U.activityInformationMeasure=H.label(f,'',16,0,570);U.activityInformationMeasure:SetWordWrap(true);U.activityInformationMeasure:Hide()
    U.activityDetailRole=H.selector(f,'My role',16,-290,196,{'TANK','HEALER','DAMAGER'})
    U.activityDetailNote=H.edit(f,'Message (optional)',224,-290,410,64)
    U.activityParticipants=H.list(f,16,-286,594,144)
    U.activityParticipantLabel=H.label(f,'Participants',16,-270,594)
    U.activityAccept=H.button(f,tr('Confirm participant'),16,-448,196,function()U.DecideActivity('CONFIRMED')end,'primary')
    U.activityWaitlist=H.button(f,tr('Waitlist'),224,-448,196,function()U.DecideActivity('WAITLIST')end)
    U.activityReject=H.button(f,tr('Decline'),432,-448,202,function()U.DecideActivity('DECLINED')end,'danger')
    U.activityJoin=H.button(f,tr('Apply'),432,-512,202,function()U.JoinActivity()end,'primary')
    U.activityWithdraw=H.button(f,tr('Withdraw'),224,-512,196,function()U.WithdrawActivity()end)
    U.activityInvite=H.button(f,tr('Invite'),224,-512,196,function()U.InviteConfirmedParticipants(false)end)
    U.activityInviteAll=H.button(f,tr('Invite all confirmed'),224,-480,196,function()U.InviteConfirmedParticipants(true)end)
    U.activityEdit=H.button(f,tr('Edit'),432,-512,202,function()U.EditActivity()end)
    U.activityDiary=H.button(f,tr('Social diary'),16,-480,196,function()U.ActivityDiary(U.activityDetailKey)end)
    H.button(f,tr('Close'),16,-512,196,function()f:Hide()end)
    H.makeModal(f);f:Hide()
end
return U
