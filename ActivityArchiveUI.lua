-- Active events, private drafts and templates have different lifecycles.
local Z,U,L,A,S,T=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.ScheduledGroups,ZenialCommunity.ScheduleTime
local H
local function tr(s)return Z.T(s)end
local function owned(kind,id)
    local e=kind=='EVENT'and S.GetOwned(id)or kind=='LIVE'and Z.db.lfg[1]or kind=='QUEST'and Z.db.quest
    if e and e.id==id then return e end
end
local function archiveable(kind,e)
    return e and(kind=='EVENT'and e.status=='OPEN'or kind=='LIVE'and L.ValidGroup(e,A.Now())or kind=='QUEST'and L.ValidQuest(e,A.Now()))
end
function U.RequestActivityArchive(kind,id)
    local e=owned(kind,id);if not archiveable(kind,e)then U.Message(tr('This activity is no longer available.'));return end
    local expected={};for k,v in pairs(e)do if type(v)~='table'then expected[k]=v end end
    U.activityArchiveRequest={kind=kind,id=id,expected=expected}
    local title=kind=='QUEST'and e.title or Z.Locale.Activity(e.activity)
    U.activityArchiveConfirmText:SetText(title..'\n\n'..tr(kind=='EVENT'and'Archive this event? It will be cancelled and participants will be notified.'or'Archive this activity? The public offer will end. Its details remain in the archive.'))
    U.activityArchiveConfirm:Show()
end
function U.ConfirmActivityArchive()
    local request=U.activityArchiveRequest;if not request then return end
    local e=owned(request.kind,request.id);local fresh=archiveable(request.kind,e)
    if fresh then for k,v in pairs(request.expected)do if e[k]~=v then fresh=false;break end end end
    if not fresh then U.Message(tr('The activity changed. Reopen it before archiving.'));U.activityArchiveConfirm:Hide();return end
    local ok,why
    if request.kind=='EVENT'then ok,why=S.Cancel(e.id,request.expected.revision)
    elseif request.kind=='LIVE'then ok=Z.CloseGroup(e.id)
    else ok=Z.CloseQuest(e.id)end
    if not ok then U.Message(tr(why or'This activity is no longer available.'));return end
    U.CloseDialogs()
    if request.kind~='EVENT'then U.Publish()else U.Refresh()end
    U.Message(tr('Activity archived.'))
end
function U.ConfigureActivityEditor(body,record)
    local kind=body==U.groupForm and'LIVE'or body==U.questForm and'QUEST'or'EVENT'
    local id;if kind=='LIVE'then id=U.groupEditID elseif kind=='QUEST'then id=U.questEditID else id=U.scheduledEditingID end
    local e=id and owned(kind,id);local published=archiveable(kind,e)
    local template=kind=='LIVE'and not id and Z.db.groupTemplates[U.groupTemplateName:GetText()]~=nil
    body.editorContext=published and'Published activity'or template and'Template'or'New activity'
    local discard=kind=='LIVE'and U.groupDiscard or kind=='QUEST'and U.questDiscard or U.scheduledDiscard
    discard:SetText(tr(published and'Archive activity'or'Cancel'))
    discard:SetScript('OnClick',function()
        if published then U.RequestActivityArchive(kind,id)
        elseif kind=='LIVE'then U.DiscardGroupDraft()
        elseif kind=='QUEST'then U.DiscardQuestDraft()
        else
            if id then local ok,why=S.DeleteDraft(id);if not ok then U.Message(tr(why));return end end
            U.scheduledEditor:Hide();U.Refresh()
        end
    end)
    if kind=='LIVE'then
        U.groupTemplateSave:SetShown(not id);U.groupTemplateSave:SetText(tr(template and'Update template'or'Save template'))
        U.groupSave:SetText(tr(published and'Save changes'or'Create activity'))
    elseif kind=='QUEST'then U.questSave:SetText(tr(published and'Save changes'or'Create activity'))
    else
        U.scheduledSave:SetText(tr(published and'Save changes'or'Create activity'))
        U.scheduledEditorNotice:SetText(tr(published and'Editing a published event invalidates existing applications. Participants must apply again.'or'The activity is published only when you click Create activity. Closing discards your input.'))
    end
end
function U.ActivityArchiveEntries()
    local out={}
    for _,e in ipairs(Z.History.Archived())do out[#out+1]={key=e.kind..':'..e.contentID,kind=e.kind=='group'and'LIVE'or'QUEST',title=e.content,at=e.at,label=Z.History.EventLabel(e.event),data=e.snapshot,history=e}end
    for _,e in ipairs(S.List(true))do
        if(e.status=='CANCELLED'or e.status=='FINISHED')and not Z.db.blocked[e.ownerKey]then
            out[#out+1]={key='EVENT:'..e.ownerKey..':'..e.id,kind='EVENT',title=e.activity,at=e.updatedAt or e.endsAt,label=S.StateLabel(e.status),data=e}
        end
    end
    table.sort(out,function(a,b)if a.at~=b.at then return a.at>b.at end;return a.key<b.key end);return out
end
function U.RecreateActivity(key)
    local r;for _,entry in ipairs(U.ActivityArchiveEntries())do if entry.key==key then r=entry;break end end
    if not r then U.Message(tr('This activity is no longer available.'));return end
    local e=r.data or{};U.CloseDialogs();U.creatorFlow=false
    if r.kind=='EVENT'then
        U.OpenScheduledEditor()
        U.scheduledEditingID,U.scheduledEditingRevision=nil,nil
        U.scheduledActivity:SetText(e.activity);U.ConfigureScheduledActivity(nil,e.activity)
        U.scheduledOrganizerRole:SetText(e.organizerRole and e.organizerRole~=''and e.organizerRole or'NONE')
        for role,f in pairs(U.scheduledSlots)do f:SetText(tostring(math.max(0,e.roleSlots[role]-(e.organizerRole==role and 1 or 0))))end
        U.scheduledDuration:SetText(tostring((e.endsAt-e.startsAt)/60));U.scheduledNote:SetText(e.note or'')
        U.scheduledDate:SetText('');U.scheduledEditorNotice:SetText(tr('Choose a new date and time, then create the activity.'))
    elseif r.kind=='QUEST'then
        local q={title=e.title or r.title,questID=e.questID or 0,zone=e.zone or'',min=e.min or 1,max=e.max or 60,note=e.note or'',expires=A.Now()+3600}
        U.OpenQuestEditor(q)
    else
        local g={activity=e.activity or r.title,min=e.min or 1,max=e.max or 60,size=e.size or 5,tank=e.tank or 1,healer=e.healer or 1,dd=e.dd or 3,note=e.note or'',templateDuration=e.start and math.max(1,math.min(1440,math.ceil((e.expires-e.start)/60)))or 120}
        U.OpenGroupEditor(g)
    end
end
function U.RefreshActivityArchive()
    if not U.activityArchive then return end
    local entries=U.ActivityArchiveEntries();local items,selected={},nil
    local maxPage=math.max(1,math.ceil(#entries/25));U.activityArchivePage=math.min(U.activityArchivePage or 1,maxPage)
    for _,r in ipairs(entries)do if r.key==U.activityArchiveKey then selected=r;break end end
    U.activityArchiveRecreate:SetEnabled(selected~=nil)
    for i=(U.activityArchivePage-1)*25+1,math.min(U.activityArchivePage*25,#entries)do local r=entries[i]
        items[#items+1]={text=Z.Locale.Activity(r.title)..'\n'..r.label..'\n'..T.Format(r.at),height=82,selected=r.key==U.activityArchiveKey,click=function()U.activityArchiveKey=r.key;U.RefreshActivityArchive()end}
    end
    H.rows(U.activityArchiveList,items,82)
    U.activityArchiveCount:SetText(tr('Archived activities')..' ('..#entries..') · '..U.activityArchivePage..'/'..maxPage)
    U.activityArchivePrev:SetEnabled(U.activityArchivePage>1);U.activityArchiveNext:SetEnabled(U.activityArchivePage<maxPage)
    -- The right column is a block of facts about the selected entry, not a list: flat rows without cells.
    -- item.text stays the data contract; display dims the label and brightens the value.
    local K=Z.Kit;local details={}
    local function fact(text,display,height)details[#details+1]={text=text,display=display,flat=true,textInset=0,height=height}end
    if selected then
        local r,e=selected,selected.data
        local name,label=Z.Locale.Activity(r.title),' · '..r.label
        details[1]={text=name..label,display=K.Paint('text',name)..K.Paint('dim',label),section=true,textInset=0,height=34}
        local archived=tr('Archived on')..': ';fact(archived..T.Format(r.at),K.Fact(archived,T.Format(r.at)),28)
        if e then
            if r.kind=='EVENT'then
                local c=Z.db.contacts[e.ownerKey];local owner=e.ownerKey==Z.me.key and Z.me.target or c and c.target or e.ownerTarget or e.ownerKey
                local span=T.Format(e.startsAt)..' – '..T.Format(e.endsAt)
                fact(owner..'\n'..span,K.Paint('text',owner)..'\n'..K.Paint('textSoft',span),56)
                local roles,parts={},{};for _,role in ipairs({'TANK','HEALER','DAMAGER'})do roles[#roles+1]=Z.Locale.Role(role)..': '..e.roleSlots[role];parts[#parts+1]={role,roles[#roles]}end
                fact(table.concat(roles,' · '),K.Roles(parts),28)
            else
                local level,range=tr('Level')..' ',e.min..' – '..e.max
                local sizeLabel,size=e.size and' · '..tr('Target size')..': 'or'',e.size and tostring(e.size)or''
                fact(level..range..sizeLabel..size,K.Fact(level,range)..(e.size and K.Fact(sizeLabel,size)or''),28)
                if r.kind=='LIVE'then
                    local parts={{'TANK',e.tank..' '..Z.Locale.Role('TANK')},{'HEALER',e.healer..' '..Z.Locale.Role('HEALER')},{'DAMAGER',e.dd..' '..Z.Locale.Role('DAMAGER')}}
                    local needed=tr('Needed')..': '
                    fact(needed..parts[1][2]..' · '..parts[2][2]..' · '..parts[3][2],K.Paint('dim',needed)..K.Roles(parts),42)
                elseif e.zone and e.zone~=''then fact(e.zone,K.Paint('textSoft',e.zone),28)end
            end
            if e.note and e.note~=''then fact(e.note,K.Paint('goldDim',K.Upper(tr('Comment')))..'\n'..K.Paint('text',e.note),94)end
        end
    else
        local hint=tr(#entries==0 and'No archived activities.'or'Select an archived activity.');fact(hint,K.Paint('muted',hint),48)
    end
    H.rows(U.activityArchiveDetails,details,48)
end
function U.OpenActivityArchive()
    U.CloseDialogs();U.activityArchivePage=1;U.activityArchiveKey=nil;U.RefreshActivityArchive();U.activityArchive:Show()
end
function U.CreateActivityArchive(helpers)
    H=helpers
    local f=H.panel(U.frame);U.activityArchive=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,550)
    H.label(f,'Archived activities',16,-18,618,'GameFontNormalLarge');U.activityArchiveCount=H.label(f,'',16,-52,618)
    U.activityArchiveList=H.list(f,16,-82,252,406);U.activityArchiveDetails=Z.Kit.InfoBlock(H.list(f,300,-82,310,406))
    U.activityArchivePrev=H.button(f,tr('Previous'),16,-512,102,function()U.activityArchivePage=U.activityArchivePage-1;U.RefreshActivityArchive()end)
    U.activityArchiveNext=H.button(f,tr('Next'),128,-512,102,function()U.activityArchivePage=U.activityArchivePage+1;U.RefreshActivityArchive()end)
    U.activityArchiveRecreate=H.button(f,tr('Create again'),244,-512,196,function()U.RecreateActivity(U.activityArchiveKey)end,'primary')
    H.button(f,tr('Close'),454,-512,180,function()f:Hide()end);H.makeModal(f);f:Hide()
    local confirm=H.panel(U.frame);U.activityArchiveConfirm=confirm;confirm:ClearAllPoints();confirm:SetPoint('CENTER',U.frame,'CENTER',90,0);confirm:SetSize(650,230)
    H.label(confirm,'Archive activity',16,-18,618,'GameFontNormalLarge')
    U.activityArchiveConfirmText=H.label(confirm,'',16,-62,618);U.activityArchiveConfirmText:SetHeight(112)
    U.activityArchiveConfirmYes=H.button(confirm,tr('Archive activity'),16,-192,294,U.ConfirmActivityArchive,'danger')
    U.activityArchiveConfirmNo=H.button(confirm,tr('Cancel'),324,-192,310,function()confirm:Hide()end)
    H.makeModal(confirm);confirm:SetFrameLevel(U.activityCreator:GetFrameLevel()+30)
    confirm:HookScript('OnHide',function()U.activityArchiveRequest=nil end);confirm:Hide()
end
return U
