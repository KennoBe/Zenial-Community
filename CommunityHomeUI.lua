-- User-facing navigation over the existing workflows. No transport changes.
local Z,U,L,A,B=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Logic,ZenialCommunity.Adapter,ZenialCommunity.ActivityBoard
local H
local function tr(s)return Z.T(s)end
local function title(r)return Z.Locale.Activity(r.title)end
local function line(r)
    local kind=r.kind=='EVENT'and'Scheduled'or r.kind=='QUEST'and'Quest assistance'or r.kind=='PVP'and'PvP Help'or'Group'
    local time=r.kind=='EVENT'or r.startsAt>A.Now()+120
    return title(r)..' · '..tr(kind)..(r.kind=='EVENT'and r.data and(' · '..Z.ScheduledGroups.StateLabel(r.data.status))or'')..'\n'..(r.saved and r.kind~='EVENT'and tr('Saved application')or time and Z.ScheduleTime.Format(r.startsAt)or tr('Now'))..' · '..r.ownerName
        ..(r.kind=='EVENT'and('\n'..Z.ScheduledGroups.Participation(r.owner,r.id))or r.application and('\n'..Z.Locale.State(r.application.state))or'')
end
local function activityType(r)
    return tr(({DUNGEON='Dungeon',RAID='Raid',PVP='PvP',QUEST='Quest assistance',CUSTOM='Custom activity'})[r.category]or'Custom activity')
end
local function applicationStatus(r)
    local text,hex,accent
    if r.own then
        local pending=0
        if r.kind=='EVENT'then
            for _,p in pairs(r.data and r.data.participants or{})do if p.state=='REQUESTED'then pending=pending+1 end end
        elseif r.kind=='LIVE'or r.kind=='QUEST'then pending=L.ApplicationCounts(Z.db,r.kind=='QUEST'and'quest'or'group',r.id)end
        if pending>0 then return Z.T('%d pending applications · organized by you',pending),'ffb466',{1,.52,.15,1}end
        return tr('Organized by you'),'ffd36b',{1,.75,.25,1}
    end
    local p=r.kind=='EVENT'and Z.ScheduledGroups.Follow(r.owner,r.id)or r.application
    if r.kind=='LIVE'or r.kind=='QUEST'then
        local bucket=r.kind=='QUEST'and Z.db.sentQuestApplications or Z.db.sentApplications
        p=bucket[r.id]and bucket[r.id][r.owner]
    end
    local state=p and p.state
    if p and p.pending then text=p.pending.action=='WITHDRAW'and'Withdrawal pending'or'Application pending delivery';hex='79bbff';accent={.3,.62,1,1}
    elseif state=='applied'or state=='REQUESTED'then text='Your application: pending';hex='79bbff';accent={.3,.62,1,1}
    elseif state=='invited'then text='You were invited';hex='83df8b';accent={.35,.8,.4,1}
    elseif state=='joined'then text='You are in the group';hex='83df8b';accent={.35,.8,.4,1}
    elseif state=='CONFIRMED'then text='Your attendance is confirmed';hex='83df8b';accent={.35,.8,.4,1}
    elseif state=='WAITLIST'then text='You are on the waitlist';hex='ffd36b';accent={1,.75,.25,1}
    elseif state=='rejected'or state=='DECLINED'then text='Your application was declined';hex='ff9690';accent={.95,.35,.3,1}
    elseif state=='withdrawn'or state=='WITHDRAWN'then text='Application withdrawn';hex='aaa69b';accent={.55,.53,.48,1}
    else text='No application';hex='c5b797'end
    text=tr(text)
    if p and(r.saved or r.kind=='EVENT'and not Z.ScheduledGroups.Verified(r.owner,r.id))then text=Z.T('Saved: %s',text)end
    return text,hex,accent
end
local function activitySummary(r)
    local when=r.kind=='EVENT'and Z.ScheduleTime.Format(r.startsAt)or r.startsAt>A.Now()+120 and Z.ScheduleTime.Format(r.startsAt)or tr('Now')
    local source=tr(r.kind=='EVENT'and'Scheduled'or r.kind=='QUEST'and'Quest assistance'or r.kind=='PVP'and'PvP Help'or'Group')
    local meta=source..' · '..activityType(r)..' · '..when
    if r.data and r.data.min then meta=meta..' · '..tr('Level')..' '..r.data.min..'–'..r.data.max end
    local status,hex,accent=applicationStatus(r)
    local heading=title(r)..(r.kind=='EVENT'and r.data and r.data.status=='DRAFT'and' · '..Z.ScheduledGroups.StateLabel('DRAFT')or'')
    return '|cffffd36b'..heading..'|r\n'..meta..'\n'..Z.T('Organizer: %s',r.ownerName)..'\n|cff'..hex..status..'|r',accent
end
local function measuredHeight(text,width,minimum)
    U.activityMeasure:SetWidth(width);U.activityMeasure:SetText(text)
    local measured=A.Call(U.activityMeasure.GetStringHeight,U.activityMeasure)
    return math.max(minimum,math.ceil(type(measured)=='number'and measured or minimum-12)+12)
end
function U.RefreshActivityBoard()
    if not U.activityList then return end
    local source=B.List({when=U.activityWhen:GetText(),category=U.activityKind:GetText(),mine=U.activityMine:GetText(),query=U.activitySearch:GetText()})
    local pages=math.max(1,math.ceil(#source/25));U.activityPage=math.max(1,math.min(U.activityPage or 1,pages))
    local items={};local selected
    for _,r in ipairs(source)do if r.key==U.activityKey then selected=r end end
    local first=(U.activityPage-1)*25+1
    for i=first,math.min(first+24,#source)do local r=source[i];local text,accent=activitySummary(r)
        items[#items+1]={text=text,accent=accent,selected=r.key==U.activityKey,height=measuredHeight(text,U.activityList.width-20,72),click=function()
            if U.activityKey~=r.key then
                U.activityKey=r.key
                if not r.own and r.kind=='EVENT'then Z.ScheduledGroups.Query(r.owner,r.id)
                elseif not r.own and r.kind=='PVP'then Z.PvPHelp.RequestDetails(r.owner,r.id)end
            end
            U.RefreshActivityBoard()
        end}
    end
    H.rows(U.activityList,items,72);U.activityCount:SetText(Z.T('%d activities · page %d/%d',#source,U.activityPage,pages))
    U.activityPrev:SetEnabled(U.activityPage>1);U.activityNext:SetEnabled(U.activityPage<pages);U.activityOpen:SetEnabled(selected~=nil)
    local actions=selected and U.ActivityActionState(selected)or{}
    local foreign=selected and not selected.own
    local ownEvent=selected and selected.own and selected.kind=='EVENT'
    for _,button in ipairs({U.activityInlineJoin,U.activityInlineWithdraw,U.activityInlineWhisper,U.activityInlineDiary,U.activityInlineEdit,U.activityManageApplicants})do button:SetShown(selected~=nil and (foreign and button~=U.activityInlineEdit and button~=U.activityManageApplicants or selected.own and(button==U.activityInlineEdit or button==U.activityManageApplicants) and (button~=U.activityInlineEdit or selected.kind~='PVP') and (button~=U.activityManageApplicants or selected.kind~='PVP')))end
    U.activityInlineArchive:SetShown(selected~=nil and selected.own and selected.kind~='PVP')
    U.activityInlineArchive:SetText(tr(selected and selected.kind=='EVENT'and'Cancel event'or'Archive activity'))
    U.activityInlineRepeat:SetShown(ownEvent)
    U.activityInlineRepeat:SetText(tr('Repeat weekly'))
    U.activityInlineForget:SetShown(selected~=nil and foreign and selected.kind=='EVENT')
    U.activityInlineJoin:SetEnabled(actions.join==true);U.activityInlineWithdraw:SetEnabled(actions.withdraw==true)
    U.activityInlineWhisper:SetEnabled(actions.whisper==true);U.activityInlineDiary:SetEnabled(actions.diary==true);U.activityInlineEdit:SetEnabled(actions.edit==true)
    U.activityManageApplicants:SetEnabled(actions.manage==true)
    U.activityInlineArchive:SetEnabled(actions.archive==true)
    U.activityInlineRepeat:SetEnabled(actions.repeatSeries==true)
    U.activityInlineForget:SetEnabled(selected~=nil and foreign and selected.kind=='EVENT' and U.CanForgetScheduled(Z.ScheduledGroups.Get(selected.owner,selected.id))==true)
    local detail={};if selected then
        local summary,accent=activitySummary(selected)
        detail[#detail+1]={text=summary,accent=accent,height=measuredHeight(summary,U.activityDetail.width-20,72)}
        local e=selected.data
        if e then
            if selected.kind=='EVENT'and not selected.own then
                detail[#detail+1]={text=tr(Z.ScheduledGroups.Reach(selected.owner)),height=32}
                local following=Z.ScheduledGroups.Follow(selected.owner,selected.id)
                if following then detail[#detail+1]={text=tr('Delivery: ')..Z.ScheduledGroups.DeliveryLabel(following.delivery),height=32}end
            end
            if e.min then detail[#detail+1]={text=tr('Level')..' '..e.min..' – '..e.max,height=32}end
            if selected.kind=='LIVE'then
                local roles=tr('Needed')..': '..e.tank..' '..Z.Locale.Role('TANK')..' · '..e.healer..' '..Z.Locale.Role('HEALER')..' · '..e.dd..' '..Z.Locale.Role('DAMAGER')
                local party=Z.ActivityParty.Info(selected)
                detail[#detail+1]={text=tr('Current party size')..': '..(party and party.total or tr('Unknown'))..' / '..e.size..'\n'..roles,height=measuredHeight(roles,U.activityDetail.width-20,48)}
            elseif selected.kind=='EVENT'then
                local party=Z.ActivityParty.Info(selected);local used=party and party.used or e.participants and Z.ScheduledGroups.Counts(e)or e.used;local roles={}
                detail[#detail+1]={text=tr('Current party size')..': '..(party and party.total or tr('Unknown'))..' / '..(e.roleSlots.TANK+e.roleSlots.HEALER+e.roleSlots.DAMAGER),height=32}
                for _,role in ipairs({'TANK','HEALER','DAMAGER'})do roles[#roles+1]=Z.Locale.Role(role)..': '..(used and tostring(math.max(0,e.roleSlots[role]-used[role]))or tr('Unknown'))..'/'..e.roleSlots[role]end
                detail[#detail+1]={text=tr('Free roles: ')..table.concat(roles,' · ')..'\n'..Z.T('Duration: %d min',math.floor((e.endsAt-e.startsAt)/60)),height=52}
            end
            if selected.kind=='PVP'then detail[#detail+1]={text=tr(e.response=='coming'and'Coming to help'or'No application'),height=32}end
        end
        if not selected.own and(selected.kind=='LIVE'or selected.kind=='EVENT')then
            detail[#detail+1]={text=tr('My role')..': '..Z.Locale.Role(Z.Logic.Role(Z.db.roles)or'DAMAGER'),height=30}
        end
        local reason,outside=B.Reason(selected);if reason then detail[#detail+1]={text=reason,height=48};if outside then detail[#detail+1]={text=tr(Z.SessionPlans.store and Z.SessionPlans.store.mode=='DAY'and'Continues tomorrow'or'Outside your session time budget'),height=44}end end
        if selected.saved then detail[#detail+1]={text=tr('Saved state; verification pending'),height=44}end
        if selected.data and selected.data.note and selected.data.note~=''then local note=tr('Comment')..'\n'..selected.data.note;detail[#detail+1]={text=note,height=measuredHeight(note,U.activityDetail.width-20,48)}end

    else detail={{text=tr('Select an activity to see its details and actions.'),height=72}}end
    H.rows(U.activityDetail,detail,48)
end
-- Wishes remain local criteria. Cards only expose the saved, active values;
-- changing them still uses the existing private editor and explicit Save action.
function U.LayoutHomeWishes()
    if not U.homeWishCards then return end
    local count=U.homeWishCardCount or 1;local width=(U.pages[9]:GetWidth()-6-(count-1)*10)/count;local bodyHeight=44
    for i,card in ipairs(U.homeWishCards)do
        card.value:SetWidth(width-20)
        if i<=count then local measured=A.Call(card.value.GetStringHeight,card.value)
            if type(measured)=='number'then bodyHeight=math.max(bodyHeight,math.min(88,math.ceil(measured)))end
        end
    end
    local cardHeight=bodyHeight+38
    for i,card in ipairs(U.homeWishCards)do
        card:ClearAllPoints();card:SetPoint('TOPLEFT',(i-1)*(width+10),-44);card:SetSize(width,cardHeight)
        card.heading:ClearAllPoints();card.heading:SetPoint('TOPLEFT',10,-8);card.heading:SetSize(width-20,18)
        card.value:ClearAllPoints();card.value:SetPoint('TOPLEFT',10,-30);card.value:SetSize(width-20,bodyHeight)
    end
    if U.homeList then
        local _,_,_,x,y=U.homeList:GetPoint(1);local bottom=-y+U.homeList:GetHeight();local top=44+cardHeight+16
        U.homeList:ClearAllPoints();U.homeList:SetPoint('TOPLEFT',x,-top);U.homeList:SetHeight(math.max(120,bottom-top));U.homeList.height=U.homeList:GetHeight()
        if U.homeList.zenialRender then U.homeList.zenialRender()end
    end
end
local function refreshWishSummary(P,state)
    local wishes=state=='active'and P.store.wishes or{}
    U.homeWishCardCount=math.max(1,#wishes)
    for i,card in ipairs(U.homeWishCards)do
        local wish=wishes[i];card:SetShown(wish~=nil or i==1)
        if wish then
            card.heading:SetText(Z.T('Wish %d · %s',wish.priority,P.KindLabel(wish.kind)))
            card.value:SetText(P.WishLabel(wish))
        else
            card.heading:SetText(tr(state=='empty'and'No wishes chosen'or'No active wishes'))
            card.value:SetText(tr(state=='empty'and'Choose up to three private wishes. Matching activities and players appear below.'or''))
        end
    end
    U.LayoutHomeWishes()
end
function U.RefreshCommunityHome()
    if not U.homeList then return end
    local P=Z.SessionPlans;local state=P.State();refreshWishSummary(P,state)
    local home=B.Home();local items={}
    local function heading(text)items[#items+1]={text='|cffffd36b'..tr(text)..'|r',height=32}end
    local function section(label,entries,emptyText)
        heading(tr(label)..' ('..#entries..')')
        if#entries==0 then items[#items+1]={text=tr(emptyText),height=34}end
        for i,entry in ipairs(entries)do if i>20 then break end
            local r=entry.activity or entry;items[#items+1]={text=line(r)..(entry.reason and('\n'..Z.T('Matches wish %d',entry.priority))or'')..(entry.outside and('\n'..tr(Z.SessionPlans.store and Z.SessionPlans.store.mode=='DAY'and'Continues tomorrow'or'Outside your session time budget'))or''),height=entry.outside and 118 or 98,click=function()U.OpenActivity(r.key)end}
        end
        if#entries>20 then items[#items+1]={text=tr('More matches are available under Activities.'),height=40,click=function()U.Navigate('activities')end}end
    end
    local relevant,appointments={},{}
    for _,entry in ipairs(home.now)do relevant[#relevant+1]=entry end
    for _,entry in ipairs(home.later)do
        local r=entry.activity or entry
        if r.kind=='EVENT' then appointments[#appointments+1]=entry else relevant[#relevant+1]=entry end
    end
    local appointmentKeys={}
    for _,entry in ipairs(appointments)do local r=entry.activity or entry;appointmentKeys[r.key]=true end
    local tasks={}
    for _,r in ipairs(home.mine)do
        if r.kind=='EVENT' and r.startsAt>A.Now()+120 then
            if not appointmentKeys[r.key] then
                local noAction=false
                if r.own then
                    noAction=r.data and r.data.status=='OPEN'
                    if noAction then for _,participant in pairs(r.data.participants or{})do if participant.state=='REQUESTED'then noAction=false;break end end end
                else
                    local following=Z.ScheduledGroups.Follow(r.owner,r.id)
                    noAction=following and(following.state=='CONFIRMED'or following.state=='WAITLIST')and not following.pending
                end
                if noAction then appointments[#appointments+1]=r;appointmentKeys[r.key]=true else tasks[#tasks+1]=r end
            end
        else tasks[#tasks+1]=r end
    end
    table.sort(appointments,function(a,b)local x=a.activity or a;local y=b.activity or b;if x.startsAt~=y.startsAt then return x.startsAt<y.startsAt end;return x.key<y.key end)
    section('Open own tasks',tasks,'No open tasks today.')
    section('Now relevant',relevant,'No matching activities received.')
    for i,m in ipairs(home.people)do if i>3 then break end;local member=m;items[#items+1]={text=tr('Matching player')..': '..m.target..' · '..tr(m.status),height=36,click=function()
        if U.Navigate('members')then U.memberKey=member.key;U.memberFollowActive=false;U.Refresh();U.OpenCompactArea('members')end
    end}end
    section('Next appointments',appointments,'No upcoming appointments today.')
    H.rows(U.homeList,items,48)
    U.homeWishState:SetText(state=='active'and(P.store.mode=='DAY'and Z.T('%d private wishes for today',#P.store.wishes)or Z.T('%d private wishes · %d min remaining',#P.store.wishes,math.ceil((P.store.expiresAt-A.Now())/60)))
        or tr(state=='expired'and'Session expired. Save explicitly to start again.'or state=='unsupported'and'Saved session wishes use an unsupported version. Data was preserved.'or state=='unknown'and'Server time is unavailable.'or'Your wishes for today · private'))
    U.homeWishEdit:SetEnabled(P.store~=nil)
end
function U.OpenActivityCreator()
    U.CloseDialogs();Z.UIState.activityInputs={}
    U.ShowActivityStep(1);U.ConfigureActivityCreator()
end
function U.ConfigureActivityCreator()
    local kind=U.creatorKind:GetText();local values=Z.GroupFinder.Activities[kind]or(kind=='QUEST'and{'Questing','Level together'}or{})
    U.creatorGoal:SetOptions(values,U.creatorGoal:GetText());H.showControl(U.creatorGoal,kind~='CUSTOM');H.showControl(U.creatorText,kind=='CUSTOM')
    local names={};for name in pairs(Z.db.groupTemplates or{})do names[#names+1]=name end;table.sort(names)
    if U.creatorTemplate then
        local options={'Choose template'};for _,name in ipairs(names)do options[#options+1]=name end
        U.creatorTemplate:SetOptions(options,U.creatorTemplate:GetText())
        H.showControl(U.creatorTemplate,U.creatorWhen:GetText()=='NOW'and kind~='QUEST')
    end
    if U.creatorHint then
        U.creatorHint:SetText(tr(U.creatorWhen:GetText()=='NOW'and'Creates a live request that you review before it is published.'or'Creates a scheduled event that others can apply to after you publish it.'))
        U.creatorHint:SetShown(U.activityStep==1 or U.activityStepBody==nil)
    end
end
function U.ContinueActivityCreator()
    local kind,when=U.creatorKind:GetText(),U.creatorWhen:GetText();local goal=kind=='CUSTOM'and U.creatorText:GetText()or U.creatorGoal:GetText()
    local template=U.creatorTemplate and U.creatorTemplate:GetText()
    if when=='NOW'and kind~='QUEST'and template and template~=''and template~='Choose template'then
        local g=Z.GroupFinder.FromTemplate(template)
        if not g then U.Message(tr('Choose a template first.'));return end
        U.creatorFlow=true;U.OpenGroupEditor(g);return
    end
    if not L.Text(goal,64)or not goal:find('%S')then U.Message(tr('Enter an activity.'));return end
    U.creatorFlow=true
    if when=='PLANNED'then U.OpenScheduledEditor(nil);U.scheduledActivity:SetText(goal);U.ConfigureScheduledActivity(kind,goal)
    elseif kind=='QUEST'then
        U.OpenQuestEditor(Z.db.quest);U.questFields.title:SetText(goal)
    else
        U.OpenGroupEditor(Z.db.lfg[1])
        U.groupKind:SetText(kind);U.GroupKind(kind,goal);if kind=='CUSTOM'then U.groupCustom:SetText(goal)end
    end
end
function U.OpenHomeWishes()
    U.homeWishPanel:Show();U.sessionPlanFrame:Show();U.RefreshSessionPlans()
end
-- Lays out the member detail card (header, facts, private-category chips, note, actions). Everything that
-- belongs to the selected member is placed here, for the two-column and the compact (full width) page.
function U.RefreshMemberCategories()
    if not U.memberCategoryFrame then return end;if U.SyncCategoryControls then U.SyncCategoryControls()end
    U.categoryKey=U.memberKey;U.RefreshCategoryPanel()
    local page=U.pages[1];local compact=U.compactArea=='members';local h=page:GetHeight();local horizontal=page:GetWidth()/856
    local x0=(compact and 0 or 570)*horizontal;local W=(compact and 820 or 280)*horizontal;local pad=12;local inner=W-pad*2
    local top=compact and 46 or 70;local bottom=h-6;local card=U.memberCard
    local showCategories=U.memberKey~=nil and U.memberKey~=Z.me.key and not Z.db.blocked[U.memberKey]
    local headerHeight=U.memberCardHasMember and 82 or 12
    -- Chips flow left to right and wrap; the chip frame shows at most three rows and scrolls beyond that.
    local scroll=U.memberCategoryScroll;local chipRow,chipGap=22,6;local flowWidth=math.max(60,inner-24);local flowX,flowY=0,0
    for _,id in ipairs(Z.SocialCategories.ORDER)do
        local chip=U.categoryChecks[id]
        if chip then
            local measured=chip.text.GetStringWidth and chip.text:GetStringWidth()
            local width=math.min(flowWidth,math.max(44,math.ceil(type(measured)=='number'and measured or #Z.SocialCategories.Label(id)*6)+22))
            if flowX>0 and flowX+width>flowWidth then flowX=0;flowY=flowY+chipRow+chipGap end
            chip:SetSize(width,chipRow);chip:ClearAllPoints();chip:SetPoint('TOPLEFT',flowX,-flowY)
            flowX=flowX+width+chipGap
        end
    end
    local flowHeight=flowY+chipRow
    local chipsHeight=showCategories and math.min(chipRow*3+chipGap*2,flowHeight)or 0
    if scroll then scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',pad,0);scroll:SetSize(inner,math.max(1,chipsHeight));scroll.height=math.max(1,chipsHeight);scroll.width=inner-24;scroll.child:SetWidth(inner-24);scroll.child:SetHeight(math.max(1,flowHeight))end
    -- Bottom-up stack: action buttons, note, chips; the fact list takes what remains.
    local buttonHeight=26;local rowActions=bottom-pad-buttonHeight;local rowPrimary=rowActions-6-buttonHeight
    local noteTop=rowPrimary-8-46;local noteCaption=noteTop-16
    local chipsTop=showCategories and(noteCaption-10-chipsHeight)or noteCaption
    local factsBottom=(showCategories and chipsTop-18 or noteCaption)-8;local factsTop=top+headerHeight
    local factsHeight=math.max(40,factsBottom-factsTop)
    if card then
        card:ClearAllPoints();card:SetPoint('TOPLEFT',x0,-top);card:SetSize(W,math.max(1,bottom-top))
        for _,region in ipairs({card.name,card.classLine})do region:SetWidth(math.max(40,W-86))end
        card.status:SetWidth(math.max(40,math.min(120,W-100)))
    end
    local profile=U.memberProfileScroll
    profile:ClearAllPoints();profile:SetPoint('TOPLEFT',x0+pad,-factsTop);profile:SetSize(inner-6,factsHeight)
    local w=profile:GetWidth()-24;U.memberProfileChild:SetWidth(w);U.memberDetail:ClearAllPoints();U.memberDetail:SetPoint('TOPLEFT',0,0);U.memberDetail:SetWidth(w)
    local measured=U.memberDetail.GetStringHeight and A.Call(U.memberDetail.GetStringHeight,U.memberDetail)or nil
    local textHeight=type(measured)=='number'and measured or math.ceil(#(U.memberDetail:GetText()or'')/35)*14
    U.memberDetail:SetHeight(math.max(40,textHeight+8));U.memberProfileChild:SetHeight(math.max(40,textHeight+8))
    local f=U.memberCategoryFrame;f:ClearAllPoints();f:SetPoint('TOPLEFT',x0,-chipsTop);f:SetSize(W,math.max(1,chipsHeight))
    f:SetShown(showCategories);U.memberCategories:Hide()
    H.showControl(U.memberPrivateNote,true);U.memberFavorite:Show();U.memberNoteSave:Show()
    local function position(control,x,y,width)control:ClearAllPoints();control:SetPoint('TOPLEFT',x,y);if width then control:SetWidth(width)end end
    position(U.memberPrivateNote,x0+pad,-noteTop,inner);position(U.memberPrivateNote.caption,x0+pad,-noteCaption,inner);U.memberPrivateNote.caption:SetHeight(14)
    local buttonWidth=compact and math.min(190,(inner-8)/2)or(inner-8)/2
    position(U.memberWhisper,x0+pad,-rowPrimary,buttonWidth);position(U.memberInvite,x0+pad+buttonWidth+8,-rowPrimary,buttonWidth)
    position(U.memberFavorite,x0+pad,-rowActions,buttonWidth);position(U.memberNoteSave,x0+pad+buttonWidth+8,-rowActions,buttonWidth)
    if not U.memberCardCaptionsStyled and Z.Theme and Z.Theme.Tint then
        U.memberCardCaptionsStyled=true
        Z.Theme.Tint(U.memberPrivateNote.caption,'SetTextColor','goldDim')
        if U.memberCategoryCaption then Z.Theme.Tint(U.memberCategoryCaption,'SetTextColor','goldDim')end
    end
end
function U.CreateCommunityHome(helpers)
    H=helpers;local label,button,list,selector,edit=H.label,H.button,H.list,H.selector,H.edit
    local home=U.pages[9]
    U.homeWishState=label(home,'',0,0,620);U.homeWishState:SetHeight(38)
    U.homeWishEdit=button(home,tr('Edit private wishes'),630,-5,220,U.OpenHomeWishes)
    U.homeWishCards={}
    for i=1,Z.SessionPlans.MAX_WISHES do
        local card=H.panel(home);card:ClearAllPoints();card:SetPoint('TOPLEFT',(i-1)*280,-44);card:SetSize(270,82)
        card.heading=label(card,'',10,-8,250,'GameFontNormalSmall');card.heading:SetHeight(18)
        card.value=label(card,'',10,-30,250,'GameFontHighlightSmall');card.value:SetHeight(44);card.value:SetWordWrap(true);if card.value.SetNonSpaceWrap then card.value:SetNonSpaceWrap(true)end
        U.homeWishCards[i]=card
    end
    U.homeList=list(home,0,-142,832,248)
    button(home,tr('Shared quests'),0,-408,180,function()U.Navigate('quests','shared')end)
    button(home,tr('Quest groups'),190,-408,180,function()U.Navigate('quests','questgroups')end)
    button(home,tr('All activities'),380,-408,180,function()U.Navigate('activities')end)
    button(home,tr('Create activity'),630,-408,220,U.OpenActivityCreator,'primary')
    -- Reuse the private wish editor. Its former match column is now the home feed.
    U.homeWishPanel=H.panel(U.frame);U.homeWishPanel:ClearAllPoints();U.homeWishPanel:SetPoint('CENTER');U.homeWishPanel:SetSize(650,440);H.makeModal(U.homeWishPanel);U.homeWishPanel:Hide()
    U.sessionPlanFrame:SetParent(U.homeWishPanel);U.sessionPlanFrame:SetFrameLevel(U.homeWishPanel:GetFrameLevel()+1);U.sessionPlanFrame:ClearAllPoints();U.sessionPlanFrame:SetPoint('TOPLEFT',24,-20);U.sessionPlanFrame:SetSize(408,414)
    for _,field in ipairs({U.sessionMatchStatus,U.sessionMemberList,U.sessionReasons,U.sessionInvite,U.sessionWhisper,U.sessionOffer})do field:Hide()end
    U.homeWishClose=button(U.homeWishPanel,tr('Close'),24,-458,408,function()U.homeWishPanel:Hide();U.RefreshCommunityHome()end)
    local board=U.pages[10]
    local function reset()U.activityPage=1;U.RefreshActivityBoard()end
    local timeLabels={ALL='Any time',NOW='Now',TODAY='Today',LATER='Later'}
    local kindLabels={ALL='All activities',QUEST='Questing',DUNGEON='Dungeon',RAID='Raid',PVP='PvP',CUSTOM='Other'}
    local mineLabels={ALL='All offers',ORGANIZED='Organized by me',APPLICATIONS='My applications'}
    U.activityWhen=selector(board,'When',0,0,160,{'ALL','NOW','TODAY','LATER'},reset,function(v)return tr(timeLabels[v])end)
    U.activityKind=selector(board,'Activity',170,0,210,{'ALL','QUEST','DUNGEON','RAID','PVP','CUSTOM'},reset,function(v)return tr(kindLabels[v])end)
    U.activityMine=selector(board,'Show',390,0,210,{'ALL','ORGANIZED','APPLICATIONS'},reset,function(v)return tr(mineLabels[v])end)
    U.activitySearch=edit(board,'Search',610,0,240,64);U.activitySearch:SetScript('OnTextChanged',reset)
    U.activityCount=label(board,'',0,-52,600)
    U.activityList=list(board,0,-80,350,310);U.activityDetail=list(board,370,-80,480,212)
    U.activityMeasure=label(board,'',0,0,310);U.activityMeasure:SetWordWrap(true);U.activityMeasure:Hide()
    U.activityInlineJoin=button(board,tr('Apply'),370,-302,112,function()if U.activityKey then U.JoinActivity(U.activityKey)end end,'primary')
    U.activityInlineWithdraw=button(board,tr('Withdraw'),488,-302,112,function()if U.activityKey then U.WithdrawActivity(U.activityKey)end end)
    U.activityInlineWhisper=button(board,tr('Whisper'),606,-302,112,function()if U.activityKey then U.ActivityWhisper(U.activityKey)end end)
    U.activityInlineDiary=button(board,tr('Social diary'),724,-302,126,function()if U.activityKey then U.ActivityDiary(U.activityKey)end end)
    U.activityInlineEdit=button(board,tr('Edit'),370,-342,140,function()if U.activityKey then U.EditActivity(U.activityKey)end end)
    U.activityManageApplicants=button(board,tr('Manage applicants'),518,-342,190,function()if U.activityKey then U.OpenActivity(U.activityKey)end end)
    U.activityOpen=button(board,tr('All details'),716,-342,134,function()if U.activityKey then U.OpenActivity(U.activityKey)end end)
    U.activityInlineArchive=button(board,tr('Archive activity'),370,-302,140,function()if U.activityKey then U.ArchiveActivity(U.activityKey)end end,'danger')
    U.activityInlineRepeat=button(board,tr('Repeat weekly'),518,-302,190,function()if U.activityKey then U.RepeatActivity(U.activityKey)end end)
    U.activityInlineForget=button(board,tr('Remove from my list'),370,-342,190,function()if U.activityKey then U.ForgetScheduledActivity(U.activityKey)end end,'danger')
    U.activityPrev=button(board,tr('Previous'),0,-408,88,function()U.activityPage=(U.activityPage or 1)-1;U.RefreshActivityBoard()end)
    U.activityNext=button(board,tr('Next'),96,-408,88,function()U.activityPage=(U.activityPage or 1)+1;U.RefreshActivityBoard()end)
    button(board,tr('Follow activities'),192,-408,164,function()U.Navigate('groups','follow')end)
    U.activityEvents=button(board,tr('Events'),366,-408,132,function()if U.Navigate('groups','scheduled')then U.scheduledArchive:SetChecked(false);U.RefreshScheduledGroups()end end)
    U.activityArchiveOpen=button(board,tr('Archive'),508,-408,110,function()U.OpenActivityArchive()end)
    button(board,tr('Create activity'),630,-408,220,U.OpenActivityCreator,'primary')
    U.activityCreator=H.panel(U.frame);local f=U.activityCreator;f:ClearAllPoints();f:SetPoint('CENTER');f:SetSize(650,330)
    U.creatorTitle=label(f,tr('Create activity'),16,-18,618,'GameFontNormalLarge')
    U.creatorWhen=selector(f,'When',16,-66,300,{'NOW','PLANNED'},U.ConfigureActivityCreator,function(v)return tr(v=='NOW'and'Now'or'Planned')end)
    U.creatorKind=selector(f,'Activity',334,-66,284,{'DUNGEON','RAID','PVP','QUEST','CUSTOM'},U.ConfigureActivityCreator,function(v)return tr(kindLabels[v])end)
    U.creatorGoal=selector(f,'Goal',16,-124,602,{})
    U.creatorText=edit(f,'Activity',16,-124,602,64)
    U.creatorTemplate=selector(f,'Use template',16,-178,602,{'Choose template'},nil,function(v)return v=='Choose template'and tr(v)or v end)
    U.creatorHint=label(f,'',16,-272,602);U.creatorHint:SetHeight(42);U.creatorHint:SetWordWrap(true);U.creatorHint:Hide()
    U.creatorContinue=button(f,tr('Continue'),16,-272,294,U.ContinueActivityCreator,'primary');U.creatorCancel=button(f,tr('Cancel'),324,-272,294,function()f:Hide()end)
    H.makeModal(f);f:Hide()
    U.CreateSettings(helpers)
    -- Categories belong to the selected contact. No category popup remains in the user flow.
    U.memberCategoryFrame=CreateFrame('Frame',nil,U.pages[1]);U.categoryChecks={}
    U.memberCategoryCaption=label(U.memberCategoryFrame,tr('Private categories'),12,16,256,'GameFontHighlightSmall');U.memberCategoryCaption:SetHeight(12)
    for _,id in ipairs(Z.SocialCategories.ORDER)do U.categoryChecks[id]=U.NewCategoryChip(U.memberCategoryFrame,id,H)end
    U.memberProfileScroll=CreateFrame('ScrollFrame',nil,U.pages[1],'UIPanelScrollFrameTemplate');U.memberProfileChild=CreateFrame('Frame',nil,U.memberProfileScroll);U.memberProfileScroll:SetScrollChild(U.memberProfileChild);U.memberDetail:SetParent(U.memberProfileChild)
    if Z.Theme then Z.Theme.StyleScroll(U.memberProfileScroll);Z.Theme.AttachScrollWheel(U.memberProfileScroll,32)end
    U.memberCategories:Hide();button(U.pages[1],tr('Contact history'),140,-407,180,function()if U.memberKey then U.OpenHistory(U.memberKey)end end)
    U.memberContactDiary=button(U.pages[1],tr('Social diary'),330,-407,180,function()local m=U.memberKey and U.Shared.memberFor(U.memberKey);U.OpenSocialDiary(U.memberKey,m and m.target)end)
    U.OpenPrivateCategories=function()
        U.CloseDialogs();U.Navigate('members');U.Refresh();U.OpenCompactArea('members')
    end
    -- Existing details retain their actions, with one route back to the shared board.
    for _,tab in ipairs({U.groupBrowseTab,U.groupMineTab,U.groupOutgoingTab,U.groupFollowTab,U.sessionPlanTab,U.scheduledTab,U.pvpTab})do tab:Hide()end
    button(U.pages[3],tr('Create activity'),630,0,220,U.OpenActivityCreator)
    button(U.pages[4],tr('Back to today'),630,-444,220,function()U.Navigate('today')end)
    button(U.pages[7],tr('Settings'),690,-444,160,function()U.Navigate('settings')end)
    button(U.craftOrderFilterBar,tr('All shopping lists'),650,0,200,function()U.SetCraftView('materials')end)
    U.materialBackOrders=button(U.pages[2],tr('Back to orders'),630,-444,220,function()
        local plan=Z.MaterialPlanner.Get(U.materialPlanID);local order=plan and Z.MaterialPlanner.Order(plan)
        if order and order.key then U.craftOrderID=order.key;U.craftOrderFilter='all' end
        U.SetCraftView('orders')
    end);U.materialBackOrders:Hide()
    U.CreateProfessionHistory(helpers);U.ApplyFormLayouts(helpers);U.CreateCategorySettings(helpers);U.CreateActivityDetails(helpers);U.CreateActivityArchive(helpers);U.CreateSocialDiary(helpers);U.CreateNotificationInbox(helpers);U.CreatePvPHelpPage(helpers);U.CreateResponsiveLayout(helpers)
end
return U
