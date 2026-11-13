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
-- Colour codes for item.display, always from the palette.
local function paint(key,value)return'|cff'..Z.Theme.PaletteHex(key)..value..'|r'end
local ACTIVITY_ICON={EVENT='calendar',QUEST='quests',PVP='pvp'}
local ACTIVITY_ICON_COLUMN=32
local function activitySummary(r)
    local when=r.kind=='EVENT'and Z.ScheduleTime.Format(r.startsAt)or r.startsAt>A.Now()+120 and Z.ScheduleTime.Format(r.startsAt)or tr('Now')
    local source=tr(r.kind=='EVENT'and'Scheduled'or r.kind=='QUEST'and'Quest assistance'or r.kind=='PVP'and'PvP Help'or'Group')
    local meta=source..' · '..activityType(r)..' · '..when
    if r.data and r.data.min then meta=meta..' · '..tr('Level')..' '..r.data.min..'–'..r.data.max end
    local status,hex,accent=applicationStatus(r)
    local heading=title(r)..(r.kind=='EVENT'and r.data and r.data.status=='DRAFT'and' · '..Z.ScheduledGroups.StateLabel('DRAFT')or'')
    local organizer=Z.T('Organizer: %s',r.ownerName)
    -- Visual weighting only (display): bright title, receding meta, status in its own colour. Colour changes
    -- sit on the line breaks of text, never inside a line.
    local display=paint('text',heading)..'\n'..paint('dim',meta)..'\n'..paint('dim',organizer)..'\n|cff'..hex..status..'|r'
    local iconColor=r.own and'gold'or hex=='79bbff'and'accentBlue'or hex=='83df8b'and'success'or hex=='ff9690'and'dangerText'or'dim'
    return '|cffffd36b'..heading..'|r\n'..meta..'\n'..organizer..'\n|cff'..hex..status..'|r',accent,display,ACTIVITY_ICON[r.kind]or'activities',iconColor
end
local function measuredHeight(text,width,minimum)
    U.activityMeasure:SetWidth(width);U.activityMeasure:SetText(text)
    local measured=A.Call(U.activityMeasure.GetStringHeight,U.activityMeasure)
    return math.max(minimum,math.ceil(type(measured)=='number'and measured or minimum-12)+12)
end
local DETAIL_FACT_HEIGHT=26
local DETAIL_ROLE_COLOR={TANK='accentBlue',HEALER='success',DAMAGER='dangerText'}
-- Plate behind the board's filters, scaled with the page width like the members page.
function U.LayoutActivityBoard()
    local bar=U.activityFilterBar;if not bar then return end
    local pageWidth=U.pages[10]:GetWidth()
    local horizontal=(type(pageWidth)=='number'and pageWidth>0 and pageWidth or 856)/856
    bar:Place(0,0,850*horizontal,54)
end
function U.RefreshActivityBoard()
    if not U.activityList then return end
    local source=B.List({when=U.activityWhen:GetText(),category=U.activityKind:GetText(),mine=U.activityMine:GetText(),query=U.activitySearch:GetText()})
    local pages=math.max(1,math.ceil(#source/25));U.activityPage=math.max(1,math.min(U.activityPage or 1,pages))
    local items={};local selected
    for _,r in ipairs(source)do if r.key==U.activityKey then selected=r end end
    local first=(U.activityPage-1)*25+1
    for i=first,math.min(first+24,#source)do local r=source[i];local text,accent,display,iconName,iconColor=activitySummary(r)
        -- The type symbol takes a column of the row; the measured width shrinks by the same amount.
        items[#items+1]={text=text,display=display,icon=Z.Theme.IconSpec(iconName),iconColor=iconColor,iconSize=18,textInset=40,accent=accent,selected=r.key==U.activityKey,height=measuredHeight(text,U.activityList.width-20-ACTIVITY_ICON_COLUMN,72),click=function()
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
    -- Detail column: the selected activity as a section head, its facts as plain lines on the column (flat),
    -- the comment set apart as a card. item.text stays the data contract; display only recolours it at the
    -- label/value boundary and at line breaks.
    local detail={};if selected then
        local width=U.activityDetail.width-20
        local summary,accent,summaryDisplay=activitySummary(selected)
        detail[#detail+1]={text=summary,display=summaryDisplay,section=true,accent=accent,height=measuredHeight(summary,width,72)}
        local function fact(text,display,height)detail[#detail+1]={text=text,display=display,flat=true,height=height or DETAIL_FACT_HEIGHT}end
        local function pair(label,value,key)return paint('dim',label)..paint(key or'text',value)end
        local function roleList(parts)
            local shown={};for i,part in ipairs(parts)do shown[i]=paint(DETAIL_ROLE_COLOR[part[1]],part[2])end
            return table.concat(shown,paint('dim',' · '))
        end
        local e=selected.data
        if e then
            if selected.kind=='EVENT'and not selected.own then
                local reach=tr(Z.ScheduledGroups.Reach(selected.owner));fact(reach,paint('textSoft',reach))
                local following=Z.ScheduledGroups.Follow(selected.owner,selected.id)
                if following then local label,value=tr('Delivery: '),Z.ScheduledGroups.DeliveryLabel(following.delivery);fact(label..value,pair(label,value))end
            end
            if e.min then local label,value=tr('Level')..' ',e.min..' – '..e.max;fact(label..value,pair(label,value))end
            if selected.kind=='LIVE'then
                local parts={{'TANK',e.tank..' '..Z.Locale.Role('TANK')},{'HEALER',e.healer..' '..Z.Locale.Role('HEALER')},{'DAMAGER',e.dd..' '..Z.Locale.Role('DAMAGER')}}
                local needed=tr('Needed')..': '
                local party=Z.ActivityParty.Info(selected)
                local label,value=tr('Current party size')..': ',(party and party.total or tr('Unknown'))..' / '..e.size
                local text=label..value..'\n'..needed..parts[1][2]..' · '..parts[2][2]..' · '..parts[3][2]
                fact(text,pair(label,value)..'\n'..paint('dim',needed)..roleList(parts),measuredHeight(text,width,DETAIL_FACT_HEIGHT))
            elseif selected.kind=='EVENT'then
                local party=Z.ActivityParty.Info(selected);local used=party and party.used or e.participants and Z.ScheduledGroups.Counts(e)or e.used;local roles,parts={},{}
                local label,value=tr('Current party size')..': ',(party and party.total or tr('Unknown'))..' / '..(e.roleSlots.TANK+e.roleSlots.HEALER+e.roleSlots.DAMAGER)
                fact(label..value,pair(label,value))
                for _,role in ipairs({'TANK','HEALER','DAMAGER'})do roles[#roles+1]=Z.Locale.Role(role)..': '..(used and tostring(math.max(0,e.roleSlots[role]-used[role]))or tr('Unknown'))..'/'..e.roleSlots[role];parts[#parts+1]={role,roles[#roles]}end
                local free,duration=tr('Free roles: '),Z.T('Duration: %d min',math.floor((e.endsAt-e.startsAt)/60))
                local text=free..table.concat(roles,' · ')..'\n'..duration
                fact(text,paint('dim',free)..roleList(parts)..'\n'..paint('textSoft',duration),measuredHeight(text,width,DETAIL_FACT_HEIGHT))
            end
            if selected.kind=='PVP'then local response=tr(e.response=='coming'and'Coming to help'or'No application');fact(response,paint(e.response=='coming'and'success'or'dim',response))end
        end
        if not selected.own and(selected.kind=='LIVE'or selected.kind=='EVENT')then
            local role=Z.Logic.Role(Z.db.roles)or'DAMAGER';local label,value=tr('My role')..': ',Z.Locale.Role(role)
            fact(label..value,pair(label,value,DETAIL_ROLE_COLOR[role]))
        end
        local reason,outside=B.Reason(selected)
        if reason then
            fact(reason,paint('textSoft',reason),measuredHeight(reason,width,DETAIL_FACT_HEIGHT))
            if outside then local text=tr(Z.SessionPlans.store and Z.SessionPlans.store.mode=='DAY'and'Continues tomorrow'or'Outside your session time budget');fact(text,paint('warning',text),measuredHeight(text,width,DETAIL_FACT_HEIGHT))end
        end
        if selected.saved then local text=tr('Saved state; verification pending');fact(text,paint('warning',text),measuredHeight(text,width,DETAIL_FACT_HEIGHT))end
        if selected.data and selected.data.note and selected.data.note~=''then
            local note=tr('Comment')..'\n'..selected.data.note
            detail[#detail+1]={text=note,display=paint('goldDim',Z.Kit.Upper(tr('Comment')))..'\n'..paint('text',selected.data.note),height=measuredHeight(note,width,48)}
        end
    else
        local hint=tr('Select an activity to see its details and actions.')
        detail={{text=hint,display=paint('muted',hint),flat=true,icon=Z.Theme.IconSpec('info'),iconColor='muted',iconSize=14,iconTop=true,textInset=30,height=72}}
    end
    H.rows(U.activityDetail,detail,48)
end
-- Today page. Top to bottom: four figures, the private wishes (cards expose only the saved, active
-- values; changing them still uses the private editor and its explicit Save), the feed, quick actions.
local HOME_TILE_HEIGHT,HOME_GAP=58,14
function U.LayoutHomeWishes()
    if not U.homeWishCards then return end
    local pageWidth=U.pages[9]:GetWidth()-6;local top=0
    if U.homeTiles then
        local gap=10;local tileWidth=(pageWidth-(#U.homeTiles-1)*gap)/#U.homeTiles
        for i,tile in ipairs(U.homeTiles)do tile:ClearAllPoints();tile:SetPoint('TOPLEFT',(i-1)*(tileWidth+gap),0);tile:SetSize(tileWidth,HOME_TILE_HEIGHT)end
        top=HOME_TILE_HEIGHT+HOME_GAP
    end
    -- Caption of the wish block on the left, its edit action on the right.
    -- The responsive layout scales the button with the page; use its real width so it never leaves the page.
    local editWidth=math.min(pageWidth,U.homeWishEdit:GetWidth())
    U.homeWishEdit:ClearAllPoints();U.homeWishEdit:SetPoint('TOPLEFT',pageWidth-editWidth,-top)
    U.homeWishState:ClearAllPoints();U.homeWishState:SetPoint('TOPLEFT',0,-(top+6));U.homeWishState:SetWidth(math.max(120,pageWidth-editWidth-12))
    local cardsTop=top+26+8
    local count=U.homeWishCardCount or 1;local width=(pageWidth-(count-1)*10)/count;local bodyHeight=30
    for i,card in ipairs(U.homeWishCards)do
        card.value:SetWidth(width-28)
        if i<=count then local measured=A.Call(card.value.GetStringHeight,card.value)
            if type(measured)=='number'then bodyHeight=math.max(bodyHeight,math.min(88,math.ceil(measured)))end
        end
    end
    local cardHeight=bodyHeight+38
    for i,card in ipairs(U.homeWishCards)do
        card:ClearAllPoints();card:SetPoint('TOPLEFT',(i-1)*(width+10),-cardsTop);card:SetSize(width,cardHeight)
        card.heading:ClearAllPoints();card.heading:SetPoint('TOPLEFT',16,-9);card.heading:SetSize(width-28,14)
        card.value:ClearAllPoints();card.value:SetPoint('TOPLEFT',16,-28);card.value:SetSize(width-28,bodyHeight)
    end
    if U.homeList then
        local _,_,_,x,y=U.homeList:GetPoint(1);local bottom=-y+U.homeList:GetHeight();local listTop=cardsTop+cardHeight+HOME_GAP
        U.homeList:ClearAllPoints();U.homeList:SetPoint('TOPLEFT',x,-listTop);U.homeList:SetHeight(math.max(120,bottom-listTop));U.homeList.height=U.homeList:GetHeight()
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
        -- A saved wish carries the gold marker; the placeholder card stays neutral.
        if card.zenialAccent then card.zenialAccent:SetShown(wish~=nil)end
    end
    U.LayoutHomeWishes()
end
-- Feed rows keep their plain data text (item.text); item.display adds the visual weighting.
local function feedDisplay(text)
    local first,rest=text:match('^([^\n]*)\n?(.*)$')
    local title,meta=first:match('^(.-)( · .*)$')
    local out=paint('text',title or first)..(meta and paint('dim',meta)or'')
    if rest~=''then out=out..'\n'..paint('dim',rest)end
    return out
end
local function lineCount(text)local _,breaks=text:gsub('\n','\n');return breaks+1 end
local KIND_ICON={EVENT='calendar',QUEST='quests',PVP='pvp'}
function U.RefreshCommunityHome()
    if not U.homeList then return end
    local T=Z.Theme
    local P=Z.SessionPlans;local state=P.State();refreshWishSummary(P,state)
    local home=B.Home();local items={}
    local function heading(label,count)
        local text=tr(label)..' ('..count..')'
        items[#items+1]={text='|cffffd36b'..text..'|r',display=paint('goldDim',Z.Kit.Upper(tr(label)))..'  '..paint('muted',tostring(count)),section=true,height=30}
    end
    local function section(label,entries,emptyText,iconColor)
        heading(label,#entries)
        if#entries==0 then items[#items+1]={text=tr(emptyText),display=paint('muted',tr(emptyText)),flat=true,height=28}end
        for i,entry in ipairs(entries)do if i>20 then break end
            local r=entry.activity or entry
            local text=line(r)..(entry.reason and('\n'..Z.T('Matches wish %d',entry.priority))or'')..(entry.outside and('\n'..tr(Z.SessionPlans.store and Z.SessionPlans.store.mode=='DAY'and'Continues tomorrow'or'Outside your session time budget'))or'')
            items[#items+1]={text=text,display=feedDisplay(text),icon=T.IconSpec(KIND_ICON[r.kind]or'activities'),iconColor=iconColor,iconSize=18,textInset=40,
                height=18+lineCount(text)*14,click=function()U.OpenActivity(r.key)end}
        end
        if#entries>20 then items[#items+1]={text=tr('More matches are available under Activities.'),icon=T.IconSpec('chevronRight'),iconColor='dim',iconSize=14,textInset=40,height=34,click=function()U.Navigate('activities')end}end
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
    section('Open own tasks',tasks,'No open tasks today.','gold')
    section('Now relevant',relevant,'No matching activities received.','accentBlue')
    for i,m in ipairs(home.people)do if i>3 then break end;local member=m
        local text=tr('Matching player')..': '..m.target..' · '..tr(m.status)
        items[#items+1]={text=text,display=paint('dim',tr('Matching player')..': ')..paint('text',m.target)..paint('dim',' · '..tr(m.status)),icon=T.IconSpec('members'),iconColor='accentBlue',iconSize=18,textInset=40,height=34,click=function()
        if U.Navigate('members')then U.memberKey=member.key;U.memberFollowActive=false;U.Refresh();U.OpenCompactArea('members')end
    end}end
    section('Next appointments',appointments,'No upcoming appointments today.','textSoft')
    H.rows(U.homeList,items,48)
    if U.homeTiles then
        local figures={#tasks,#relevant,#appointments,#home.people}
        for i,tile in ipairs(U.homeTiles)do tile:SetValue(figures[i],figures[i]==0 and'muted'or i==1 and'gold'or'text')end
    end
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
    if U.memberFilterBar then U.memberFilterBar:SetShown(not compact)end
    local showCategories=U.memberKey~=nil and U.memberKey~=Z.me.key and not Z.db.blocked[U.memberKey]
    local headerHeight=U.memberCardHasMember and 82 or 12
    -- Private categories are one multi-select field: a dropdown button on the card and a popup that lists
    -- every category as a toggle (the same chips as before, stacked; several can be on at once).
    local C=Z.SocialCategories
    local scroll=U.memberCategoryScroll;local chipRow,chipGap=22,4;local count=0
    local popup=U.memberCategoryPopup
    if not popup and scroll then
        popup=CreateFrame('Frame',nil,page,BackdropTemplateMixin and'BackdropTemplate'or nil);U.memberCategoryPopup=popup
        popup:SetFrameStrata('TOOLTIP');popup:SetClampedToScreen(true);popup:EnableMouse(true)
        if Z.Theme then Z.Theme.Panel(popup,'raised');if Z.Theme.Shadow then Z.Theme.Shadow(popup,8,.5)end end
        scroll:SetParent(popup);popup:Hide()
        popup:SetScript('OnHide',function(self)if U.Shared.openPopup==self then U.Shared.openPopup=nil end end)
    end
    local chosen={}
    for _,id in ipairs(C.ORDER)do
        local chip=U.categoryChecks[id]
        if chip then
            chip:SetSize(math.max(60,inner-8-18),chipRow);chip:ClearAllPoints();chip:SetPoint('TOPLEFT',0,-count*(chipRow+chipGap))
            count=count+1
        end
        if showCategories and C.Has(U.memberKey,id)then chosen[#chosen+1]=C.Label(id)end
    end
    local listHeight=math.max(chipRow,count*(chipRow+chipGap)-chipGap);local visibleHeight=math.min(listHeight,8*(chipRow+chipGap)-chipGap)
    if popup then
        popup:ClearAllPoints();popup:SetPoint('TOPLEFT',U.memberCategoryButton,'BOTTOMLEFT',0,-2);popup:SetSize(inner,visibleHeight+8)
        scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',4,-4);scroll:SetSize(inner-8,visibleHeight);scroll.height=visibleHeight;scroll.width=inner-8-18
        scroll.child:SetWidth(inner-8-18);scroll.child:SetHeight(listHeight)
        -- A popup opened for another member, or for one without categories, closes.
        if popup:IsShown()and(not showCategories or U.memberCategoryPopupKey~=U.memberKey)then popup:Hide()end
    end
    if U.memberCategoryButton then
        U.memberCategoryButton:SetText(#chosen>0 and table.concat(chosen,', ')or tr('Select'))
        U.memberCategoryButton:SetEnabled(showCategories and not C.readOnly)
    end
    -- Bottom-up stack: whisper / invite, note, category field; the fact list takes what remains.
    local buttonHeight,fieldHeight=26,24;local rowActions=bottom-pad-buttonHeight
    local noteTop=rowActions-10-46;local noteCaption=noteTop-16
    local chipsHeight=showCategories and fieldHeight or 0
    local chipsTop=showCategories and(noteCaption-12-fieldHeight)or noteCaption
    local factsBottom=(showCategories and chipsTop-18 or noteCaption)-8;local factsTop=top+headerHeight
    local factsHeight=math.max(40,factsBottom-factsTop)
    if card then
        card:ClearAllPoints();card:SetPoint('TOPLEFT',x0,-top);card:SetSize(W,math.max(1,bottom-top))
        -- The name leaves room for the favourite star in the top right corner.
        for _,region in ipairs({card.name,card.classLine})do region:SetWidth(math.max(40,W-86-30))end
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
    if U.memberCategoryButton then U.memberCategoryButton:ClearAllPoints();U.memberCategoryButton:SetPoint('TOPLEFT',pad,0);U.memberCategoryButton:SetSize(inner,fieldHeight)end
    H.showControl(U.memberPrivateNote,true);U.memberFavorite:SetShown(U.memberCardHasMember==true)
    local function position(control,x,y,width)control:ClearAllPoints();control:SetPoint('TOPLEFT',x,y);if width then control:SetWidth(width)end end
    position(U.memberPrivateNote,x0+pad,-noteTop,inner);position(U.memberPrivateNote.caption,x0+pad,-noteCaption,inner);U.memberPrivateNote.caption:SetHeight(14)
    -- The note caption is a region of the page and the card is a child frame drawn above page regions:
    -- the caption belongs to the card (draw order) but keeps its anchor on the page (layout).
    local noteCaptionText=U.memberPrivateNote.caption
    if card and noteCaptionText.SetParent then
        noteCaptionText:SetParent(card);noteCaptionText:ClearAllPoints();noteCaptionText:SetPoint('TOPLEFT',page,'TOPLEFT',x0+pad,-noteCaption)
    end
    local buttonWidth=compact and math.min(190,(inner-8)/2)or(inner-8)/2
    position(U.memberWhisper,x0+pad,-rowActions,buttonWidth);position(U.memberInvite,x0+pad+buttonWidth+8,-rowActions,buttonWidth)
    -- Favourite: a star in the top right corner of the card, right of the name.
    position(U.memberFavorite,x0+W-10-26,-(top+11));U.memberFavorite:SetSize(26,26)
    if card and U.memberFavorite.SetFrameLevel then U.memberFavorite:SetFrameLevel(card:GetFrameLevel()+2)end
    -- Saved marker of the private note, at the right end of its caption line.
    if U.memberNoteSaved then U.memberNoteSaved:ClearAllPoints();U.memberNoteSaved:SetPoint('TOPRIGHT',page,'TOPLEFT',x0+pad+inner,-(noteCaption+1))end
    -- Action symbols: the caption never loses characters to the symbol. Per button: normal layout, then a
    -- tighter one, finally no symbol (the caption is centred again).
    if Z.Theme and Z.Theme.AlignButtonText then
        local function textWidth(button)
            local fs=button.GetFontString and button:GetFontString()
            local width=fs and fs.GetStringWidth and A.Call(fs.GetStringWidth,fs)
            if type(width)=='number'then return width end
            -- Without a font string (test mock): about 6 px per character.
            local text=button.GetText and button:GetText()or''
            return #text:gsub('[\128-\191]','')*6
        end
        for _,button in ipairs({U.memberWhisper,U.memberInvite})do
            local icon=button.zenialActionIcon
            if icon then
                local width=textWidth(button)
                local level=width+38<=buttonWidth and 1 or width+24<=buttonWidth and 2 or 3
                icon:SetShown(level<3);icon:ClearAllPoints()
                if level==1 then icon:SetSize(14,14);icon:SetPoint('LEFT',10,0);Z.Theme.AlignButtonText(button,30)
                elseif level==2 then icon:SetSize(12,12);icon:SetPoint('LEFT',6,0);Z.Theme.AlignButtonText(button,22,2)
                else
                    Z.Theme.AlignButtonText(button,4,4)
                    local fs=button.GetFontString and button:GetFontString();if fs then fs:SetJustifyH('CENTER')end
                end
            end
        end
    end
    if not U.memberCardCaptionsStyled and Z.Theme and Z.Theme.Font then
        U.memberCardCaptionsStyled=true
        for _,caption in ipairs({U.memberPrivateNote.caption,U.memberCategoryCaption})do
            Z.Theme.Font(caption,'overline','goldDim')
            if Z.Kit and caption:GetText()then caption:SetText(Z.Kit.Upper(caption:GetText()))end
        end
    end
    if card and card.empty then
        card.empty:ClearAllPoints();card.empty:SetPoint('TOP',card,'TOP',0,-(headerHeight+16));card.empty:SetWidth(math.max(120,W-24))
    end
end
function U.CreateCommunityHome(helpers)
    H=helpers;local label,button,list,selector,edit=H.label,H.button,H.list,H.selector,H.edit
    local home=U.pages[9]
    -- Figures first: what needs me, what fits now, what is planned, who fits. Each tile opens its area.
    local K,T=Z.Kit,Z.Theme
    U.homeTiles={}
    for i,spec in ipairs({
        {icon='check',label='Open own tasks',go=function()U.Navigate('activities')end},
        {icon='activities',label='Now relevant',go=function()U.Navigate('activities')end},
        {icon='calendar',label='Next appointments',go=function()U.Navigate('groups','scheduled')end},
        {icon='members',label='Matching fellow players',go=function()U.Navigate('members')end},
    })do
        local tile=K.StatTile(home,{icon=spec.icon,label=tr(spec.label),value=0,onClick=spec.go})
        tile:SetPoint('TOPLEFT',(i-1)*214,0);tile:SetSize(204,58);U.homeTiles[i]=tile
    end
    U.homeWishState=label(home,'',0,-78,620);U.homeWishState:SetHeight(14);U.homeWishState:SetWordWrap(false);T.Font(U.homeWishState,'caption','dim')
    U.homeWishEdit=button(home,tr('Edit private wishes'),630,-72,220,U.OpenHomeWishes)
    U.homeWishCards={}
    for i=1,Z.SessionPlans.MAX_WISHES do
        local card=H.panel(home);card:ClearAllPoints();card:SetPoint('TOPLEFT',(i-1)*280,-106);card:SetSize(270,68)
        K.Accent(card,'gold')
        card.heading=label(card,'',16,-9,242,'GameFontHighlightSmall');card.heading:SetHeight(14);card.heading:SetWordWrap(false);T.Font(card.heading,'caption','goldDim')
        card.value=label(card,'',16,-28,242,'GameFontHighlight');card.value:SetHeight(30);card.value:SetWordWrap(true);if card.value.SetNonSpaceWrap then card.value:SetNonSpaceWrap(true)end;T.Font(card.value,'heading','text')
        U.homeWishCards[i]=card
    end
    U.homeList=list(home,0,-188,832,208)
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
    -- Filter bar: a plate of page textures behind the four filters (placed by U.LayoutActivityBoard).
    U.activityFilterBar=K.FilterBar(board)
    U.activityWhen=selector(board,'When',10,-6,150,{'ALL','NOW','TODAY','LATER'},reset,function(v)return tr(timeLabels[v])end)
    U.activityKind=selector(board,'Activity',168,-6,200,{'ALL','QUEST','DUNGEON','RAID','PVP','CUSTOM'},reset,function(v)return tr(kindLabels[v])end)
    U.activityMine=selector(board,'Show',376,-6,200,{'ALL','ORGANIZED','APPLICATIONS'},reset,function(v)return tr(mineLabels[v])end)
    U.activitySearch=edit(board,'Search',584,-6,256,64);U.activitySearch:SetScript('OnTextChanged',reset)
    local searchIcon=K.Icon(U.activitySearch,'search',14,'muted');searchIcon:SetPoint('LEFT',8,0);U.activitySearchIcon=searchIcon
    if U.activitySearch.SetTextInsets then U.activitySearch:SetTextInsets(26,8,4,4)end
    U.activityCount=label(board,'',10,-62,600);T.Font(U.activityCount,'caption','dim')
    U.activityList=list(board,0,-80,350,310);U.activityDetail=list(board,370,-80,480,212)
    U.activityMeasure=label(board,'',0,0,310);U.activityMeasure:SetWordWrap(true);U.activityMeasure:Hide()
    U.LayoutActivityBoard()
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
    -- The multi-select field: opens the popup with the category toggles (built in U.RefreshMemberCategories).
    U.memberCategoryButton=button(U.memberCategoryFrame,'',12,0,256,function()
        local popup=U.memberCategoryPopup;if not popup then return end
        local shared=U.Shared
        if popup:IsShown()then popup:Hide();return end
        if shared.openPopup and shared.openPopup~=popup then shared.openPopup:Hide()end
        U.memberCategoryPopupKey=U.memberKey;popup:Show();shared.openPopup=popup
        if U.memberCategoryScroll and U.memberCategoryScroll.zenialRender then U.memberCategoryScroll.zenialRender()end
    end)
    if Z.Theme and Z.Theme.StyleDropdown then Z.Theme.StyleDropdown(U.memberCategoryButton);Z.Theme.AlignButtonText(U.memberCategoryButton,8,28)end
    for _,id in ipairs(Z.SocialCategories.ORDER)do U.categoryChecks[id]=U.NewCategoryChip(U.memberCategoryFrame,id,H)end
    U.memberProfileScroll=CreateFrame('ScrollFrame',nil,U.pages[1],'UIPanelScrollFrameTemplate');U.memberProfileChild=CreateFrame('Frame',nil,U.memberProfileScroll);U.memberProfileScroll:SetScrollChild(U.memberProfileChild);U.memberDetail:SetParent(U.memberProfileChild)
    if Z.Theme and Z.Theme.Font then Z.Theme.Font(U.memberDetail,'body','textSoft')end
    if U.memberDetail.SetSpacing then U.memberDetail:SetSpacing(3)end
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
