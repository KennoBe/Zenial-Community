-- Local, per-character unread updates. Nothing here enters an addon message.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local N={MAX_ENTRIES=200};Z.Notifications=N
local VIEWS={craft={orders=true},trade={rules=true},groups={mine=true,outgoing=true,browse=true,pvp=true,scheduled=true},quests={mine=true,outgoing=true}}
local TITLES={
    SCHEDULE_APPLICATION="Scheduled application changed",SCHEDULE_STATUS="Scheduled participation updated",SCHEDULE_CHANGED="Scheduled event changed; apply again",SCHEDULE_REMINDER="Reminder for a saved event",SCHEDULE_REMINDER_1="Saved event starts in 30 minutes",SCHEDULE_REMINDER_2="Saved event starts in 10 minutes",SCHEDULE_REMINDER_3="Saved event starts now",
    REQUESTED="New craft request",ACCEPTED="Craft request accepted",READY="Craft order ready",COMPLETED="Craft handoff confirmed",DECLINED="Craft request declined",CANCELLED="Craft order cancelled",EXPIRED="Craft request expired",
    TRADE_NEW="New matching offer",TRADE_UPDATED="Matching offer updated",TRADE_CLOSED="Matching offer closed",
    invited_received="Application accepted",rejected_received="Application declined",joined="Group joined",withdrawal_received="Application withdrawn",
    coming="A player is coming to help",withdrawn="Help commitment withdrawn",GROUP_FOLLOW="New group for a followed activity",
    application_received="Application received",
}
local function valid(row)
    return type(row)=="table"and VIEWS[row.area]and VIEWS[row.area][row.view]and TITLES[row.code]
        and L.Text(row.token,512)and L.Text(row.id,row.area=="craft"and 224 or 64)and L.ValidIdentityKey(row.peer)
        and L.Int(row.version,0,4102444800)and L.Int(row.at,1,4102444800)
        and L.Text(row.subject or"",96,true)and L.Text(row.source or"",64,true)
end
local function sort(a,b)return a.at>b.at or a.at==b.at and a.token<b.token end
function N.Normalize(raw)
    local store={version=1,initialized=type(raw)=="table"and raw.initialized==true,entries={},recent={},recentSeq=type(raw)=='table'and L.Int(raw.recentSeq,0,2147483646)and raw.recentSeq or 0}
    local rows={};for token,row in pairs(type(raw)=="table"and type(raw.entries)=="table"and raw.entries or{})do
        if valid(row)and token==row.token and row.at>=A.Now()-30*86400 and row.at<=A.Now()+300 then
            rows[#rows+1]={token=token,area=row.area,view=row.view,code=row.code,id=row.id,peer=row.peer,version=row.version,at=row.at,subject=row.subject or"",source=row.source or"",unread=row.unread==true}
        end
    end
    table.sort(rows,function(a,b)if a.unread~=b.unread then return a.unread end;return sort(a,b)end)
    for i=1,math.min(#rows,N.MAX_ENTRIES)do store.entries[rows[i].token]=rows[i]end
    for _,item in ipairs(type(raw)=='table'and type(raw.recent)=='table'and raw.recent or{})do
        if #store.recent<50 and type(item)=='table'and L.Text(item.logID,600)and L.Text(item.title,128,true)and L.Text(item.text,1024,true)and L.Int(item.at,1,A.Now()+300)and(item.entry==nil or valid(item.entry))then
            local entry
            if item.entry then entry={};for _,field in ipairs({'token','area','view','code','id','peer','version','at','subject','source','unread'})do entry[field]=item.entry[field]end end
            store.recent[#store.recent+1]={logID=item.logID,title=item.title,text=item.text,at=item.at,unread=item.unread==true,entry=entry}
        end
    end
    return store
end
function N.Initialize()
    N.store=Z.uiCharacter.notifications or N.Normalize(nil);Z.uiCharacter.notifications=N.store
    if not N.store.initialized then
        N.store.initialized=true
        for _,order in pairs(Z.CraftOrders.orders or{})do if order.direction=="incoming"and order.state=="REQUESTED"then N.Craft(order,true)end end
    end
    if #N.store.recent==0 then
        local old={};for _,row in pairs(N.store.entries)do old[#old+1]=row end;table.sort(old,sort)
        for i=math.min(50,#old),1,-1 do N.RecordRow(old[i])end
    end
end
local function line(value)return tostring(value or''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('%s+',' '):sub(1,1024)end
function N.Log(title,body,entry,callback)
    if not N.store then return end
    local text=line(body);title=line(title):sub(1,128)
    if not L.Text(title,128,true)or not L.Text(text,1024,true)then return end
    N.store.recentSeq=math.min(2147483646,N.store.recentSeq+1)
    local item={logID=tostring(A.Now())..'.'..N.store.recentSeq,at=entry and entry.at or A.Now(),title=title,text=text,unread=not entry or entry.unread~=false,entry=entry}
    table.insert(N.store.recent,1,item)
    N.cardActions=N.cardActions or{};if callback then N.cardActions[item.logID]=callback end
    while #N.store.recent>50 do local removed=table.remove(N.store.recent);N.cardActions[removed.logID]=nil end
    if Z.UI and Z.UI.RefreshNotificationInbox then Z.UI.RefreshNotificationInbox()end
    return item
end
function N.RecordRow(row)
    local copy={};for k,v in pairs(row)do if type(v)~='table'then copy[k]=v end end
    return N.Log(N.Title(row),N.Describe(row),copy)
end
function N.Recent()
    local out={};for _,item in ipairs(N.store and N.store.recent or{})do if not item.entry or not Z.db.blocked[item.entry.peer]then out[#out+1]=item end end;return out
end
function N.RecentUnread()local count=0;for _,item in ipairs(N.Recent())do if item.unread then count=count+1 end end;return count end
function N.ReadRecent()
    for _,item in ipairs(N.store and N.store.recent or{})do item.unread=false end
end
local function changed()if Z.UI and Z.UI.UpdateBadges then Z.UI.UpdateBadges()end end
function N.Push(area,view,token,version,code,peer,id,subject,source,quiet)
    local row={area=area,view=view,token=token,version=version,code=code,peer=peer,id=id,subject=subject or"",source=source or"",at=A.Now(),unread=true}
    if not N.store or not valid(row)or Z.db.blocked[peer]then return false end
    local old=N.store.entries[token]
    if old and(version<old.version or version==old.version and code==old.code)then return false end
    if not old and L.Count(N.store.entries)>=N.MAX_ENTRIES then
        local victim;for _,item in pairs(N.store.entries)do if not victim or(victim.unread and not item.unread)or victim.unread==item.unread and item.at<victim.at then victim=item end end
        if victim then N.store.entries[victim.token]=nil end
    end
    N.store.entries[token]=row;N.RecordRow(row);changed()
    if not quiet and Z.UI and Z.UI.NotifyUpdate then Z.UI.NotifyUpdate(row)end
    return true
end
local function active(row)
    if Z.db.blocked[row.peer]then return false end
    if row.code=="GROUP_FOLLOW"then return Z.FindForeignGroup(row.peer,row.id)~=nil end
    if row.code=='application_received'then return false end
    if row.view=='scheduled'then
        local e=Z.ScheduledGroups.Get(row.peer,row.id)
        return e~=nil and e.status=='OPEN'and e.endsAt>A.Now()
    end
    if row.view=='outgoing'and(row.area=='groups'or row.area=='quests')then
        return Z.ActivityBoard.Get((row.area=='groups'and'LIVE'or'QUEST')..':'..row.peer..':'..row.id)~=nil
    end
    if row.view=="mine"then local own=row.area=="groups"and Z.db.lfg[1]or row.area=="quests"and Z.db.quest;return own and own.id==row.id and(not own.expires or own.expires>A.Now())end
    if row.view=="pvp"then local own=Z.PvPHelp and Z.PvPHelp.Own();return own and own.id==row.id and(not own.expires or own.expires>A.Now())end
    return true
end
function N.Count(area,view)
    local now=A.Now();local count=0;for _,row in pairs(N.store and N.store.entries or{})do if row.unread and row.at>=now-30*86400 and active(row)and(not area or row.area==area)and(not view or row.view==view)then count=count+1 end end;return count
end
function N.IsUnread(token)local row=N.store and N.store.entries[token];return row and row.unread==true or false end
function N.Read(token)
    for _,item in ipairs(N.store and N.store.recent or{})do if item.entry and item.entry.token==token then item.unread=false end end
    local row=N.store and N.store.entries[token];if row and row.unread then row.unread=false;changed();return true end
end
function N.ReadVisible(area,view,token)
    local U=Z.UI
    if U and U.frame and U.frame:IsShown()and U.IsRoute(area)then
        local current=area=="craft"and U.craftView or area=="trade"and U.tradeView or area=="groups"and U.groupView or U.questView
        if current==view and(view~="pvp"or U.pvpUnified and U.pvpHelpers and U.pvpHelpers:IsShown()or not U.pvpUnified and U.pvpView=="mine")then N.Read(token)end
    end
end
function N.RemovePeer(peer)
    for token,row in pairs(N.store and N.store.entries or{})do if row.peer==peer then N.store.entries[token]=nil end end
    local out={};for _,item in ipairs(N.store and N.store.recent or{})do if not item.entry or item.entry.peer~=peer then out[#out+1]=item end end
    if N.store then N.store.recent=out end
    changed()
end
function N.RemoveSource(area,source)
    for token,row in pairs(N.store and N.store.entries or{})do if row.area==area and row.source==source then N.store.entries[token]=nil end end;changed()
end
function N.List(area,source)
    local rows={};for _,row in pairs(N.store and N.store.entries or{})do if row.area==area and(not source or row.source==source)and not Z.db.blocked[row.peer]then rows[#rows+1]=row end end;table.sort(rows,function(a,b)if a.unread~=b.unread then return a.unread end;return sort(a,b)end);return rows
end
function N.Title(row)
    if row.code=='SCHEDULE_CHANGED'or row.code=='SCHEDULE_STATUS'then
        local e=Z.ScheduledGroups.Get(row.peer,row.id)
        if e and e.status=='CANCELLED'then return Z.T('Activity cancelled')end
    end
    if row.code=='SCHEDULE_REMINDER_3'then return Z.T('Activity starts now')end
    if row.code:match('^SCHEDULE_REMINDER_')then return Z.T('Activity reminder')end
    if row.code=='SCHEDULE_APPLICATION'then return Z.T('Application updated')end
    if row.code=='SCHEDULE_STATUS'or row.code=='SCHEDULE_CHANGED'then return Z.T('Participation updated')end
    return Z.T('New update')
end
function N.Describe(row)
    local activity=Z.Locale.Activity(row.subject)
    if row.code=='application_received'then
        local c=Z.db.contacts[row.peer];return Z.T('%s applied for %s.',c and c.target or row.peer,activity)
    end
    if row.code=='SCHEDULE_APPLICATION'and row.source~=''then
        local e=Z.ScheduledGroups.GetOwned(row.id);local key=Z.ResolvePeerKey(row.source);local p=e and e.participants[key]
        local text=Z.T(p and p.state=='WITHDRAWN'and'%s withdrew from %s.'or'%s applied for %s.',row.source,activity)
        return text..(p and p.role and'\n'..Z.Locale.Role(p.role)or'')..(e and'\n'..Z.ScheduleTime.Format(e.startsAt)or'')
    end
    if row.code:match('^SCHEDULE_REMINDER_[123]$')then
        local e=Z.ScheduledGroups.Get(row.peer,row.id)
        local text=Z.T(({SCHEDULE_REMINDER_1='%s starts in 30 minutes.',SCHEDULE_REMINDER_2='%s starts in 10 minutes.',SCHEDULE_REMINDER_3='%s starts now.'})[row.code],activity)
        if e then
            text=text..'\n'..Z.ScheduleTime.Format(e.startsAt)
            if row.peer==Z.me.key then
                text=text..'\n'..Z.T(e.status=='DRAFT'and'This event is still a private draft.'or'Prepare the group and invite your confirmed participants.')
            else
                text=text..'\n'..Z.T(Z.ScheduledGroups.Verified(row.peer,row.id)and'Your attendance is confirmed. Wait for the organizer to invite you.'or'Saved confirmation; organizer verification is pending.')
            end
        end
        return text
    end
    if row.code=='SCHEDULE_STATUS'or row.code=='SCHEDULE_CHANGED'then
        local e=Z.ScheduledGroups.Get(row.peer,row.id);local c=Z.db.contacts[row.peer]
        local text=e and e.status=='CANCELLED'and Z.T('%s was cancelled.',activity)or row.code=='SCHEDULE_CHANGED'and Z.T('%s was changed. Apply again.',activity)or Z.T('Your attendance for %s: %s',activity,Z.ScheduledGroups.Participation(row.peer,row.id))
        return text..(c and'\n'..Z.T('Organizer: %s',c.target)or'')..(e and'\n'..Z.ScheduleTime.Format(e.startsAt)or'')
    end
    if row.area=='groups'or row.area=='quests'then
        local c=Z.db.contacts[row.peer];local who=c and c.target or Z.T('Unknown')
        local target=activity~=''and activity or Z.T('Activity')
        if row.code=='invited_received'then return Z.T('Your application for %s was accepted.',target)..'\n'..Z.T('Organizer: %s',who)
        elseif row.code=='rejected_received'then return Z.T('Your application for %s was declined.',target)..'\n'..Z.T('Organizer: %s',who)
        elseif row.code=='joined'then return Z.T('You joined %s.',target)
        elseif row.code=='withdrawal_received'then return Z.T('%s withdrew from %s.',who,target)end
    end
    return Z.T(TITLES[row.code]or"New update")..(row.subject~=""and(": "..activity)or"")
end
function N.Craft(order,quiet)return N.Push("craft","orders","craft:"..order.key,order.revision,order.state,order.peer,order.key,order.recipeName,nil,quiet)end
function N.Trade(row,revision)
    return N.Push("trade","rules","trade:"..row.rule..":"..row.key..":"..row.offer.id,revision,row.closed and"TRADE_CLOSED"or row.updated and"TRADE_UPDATED"or"TRADE_NEW",row.key,row.offer.id,row.offer.name,row.rule)
end
function N.Finder(kind,event,peer,id,owner)
    if event~="invited_received"and event~="rejected_received"and event~="withdrawal_received"and(event~="joined"or owner~=peer)then return end
    local area=kind=="group"and"groups"or"quests";local view=event=="withdrawal_received"and"mine"or"outgoing"
    local content
    if view=='mine'then content=kind=='group'and Z.db.lfg[1]or Z.db.quest
    else content=kind=='group'and Z.FindForeignGroup(peer,id)or kind=='quest'and Z.FindForeignQuest(peer,id)end
    local subject=content and content.id==id and(kind=='group'and content.activity or content.title)
        or Z.History and Z.History.FindContent(kind,id,peer)or''
    return N.Push(area,view,area..":"..view..":"..peer..":"..id,A.Now(),event,peer,id,subject)
end
