-- Quest IDs are optional public statements, never proof of identity or presence.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local Q={MAX_ENTRIES=1024,MAX_IDS=256,TTL=1200};Z.QuestHelper=Q
function Q.Sharing()return Z.db and Z.db.consent and Z.db.autoDiscovery and Z.db.visible and Z.db.shareQuests and Z.identityReady and not Z.offlineOnly or false end
local function dirty()if Z.MarkDirty then Z.MarkDirty("questHelper")end end
function Q.Initialize()
    Q.quests,Q.ids,Q.invites={},{},{};Q.sampleAt=nil;Q.scanning=false;Q.scanDue=A.Clock()+1;Q.lastPublish=-100;Q.nextRefresh=0;Q.publishedSignature=nil;Q.lastError="";Q.scanState="pending"
end
function Q.OnEvent()if not Q.scanning and not Q.scanDue then Q.scanDue=A.Clock()+1 end end
local function safeCall(fn,...)
    local ok,a,b=pcall(fn,...);if not ok or not A.Safe(a,b)then error("quest API unavailable")end;return a,b
end
local function readInfo(api,index)
    local info=safeCall(api.GetInfo,index)
    if not A.PublicTable(info)or not A.Safe(info.title,info.isHeader,info.isCollapsed,info.questID,info.level,info.isHidden,info.isInternal,info.headerSortKey)then error("quest entry unavailable")end
    return info
end
local function shown(frame)
    if not frame then return false end
    -- QuestMapFrame can remain shown beneath a hidden WorldMapFrame. Visibility
    -- includes its ancestors and avoids deferring every scan on such clients.
    local fn=frame.IsVisible or frame.IsShown
    if type(fn)~="function"then return true end
    local ok,value=pcall(fn,frame);return not ok or not A.Safe(value)or value~=false
end
function Q.CanScan()
    if A.Call(InCombatLockdown)~=false then return false,"combat"end
    for _,frame in pairs({WorldMapFrame,QuestLogFrame,QuestMapFrame,QuestFrame,QuestChoiceFrame,QuestLogPopupDetailFrame})do if shown(frame)then return false,"quest-panel-open"end end
    return true
end
-- Header functions are global in Blizzard's client, while modern log readers
-- and selection are namespaced. Older clients expose indexed log readers.
local function questAPI()
    local c=C_QuestLog or{};local api={IsOnQuest=c.IsOnQuest}
    if type(c.GetInfo)=="function"and type(c.GetNumQuestLogEntries)=="function"then
        api.GetInfo=c.GetInfo;api.GetNumQuestLogEntries=c.GetNumQuestLogEntries;api.mode="modern"
    else
        api.GetNumQuestLogEntries=GetNumQuestLogEntries;api.mode="legacy"
        if type(GetQuestLogTitle)=="function"then api.GetInfo=function(index)
            local title,level,tag,header,collapsed,complete,frequency,id=GetQuestLogTitle(index)
            if not A.Safe(title,level,header,collapsed,id)then error("quest entry unavailable")end
            return{title=title,level=level,isHeader=header,isCollapsed=collapsed,questID=id}
        end end
    end
    if type(c.GetSelectedQuest)=="function"and type(c.SetSelectedQuest)=="function"then
        api.GetSelectedQuest=c.GetSelectedQuest;api.SetSelectedQuest=c.SetSelectedQuest
    else api.GetSelectedQuest=GetQuestLogSelection;api.SetSelectedQuest=SelectQuestLogEntry end
    api.ExpandQuestHeader=type(ExpandQuestHeader)=="function"and ExpandQuestHeader or c.ExpandQuestHeader
    api.CollapseQuestHeader=type(CollapseQuestHeader)=="function"and CollapseQuestHeader or c.CollapseQuestHeader
    return api
end
local function scanState(state,reason)
    reason=reason or""
    if Q.scanState~=state or Q.lastError~=reason then Q.scanState,Q.lastError=state,reason;dirty()end
end
function Q.Status()
    local api=questAPI();local missing={}
    for _,name in ipairs({"GetNumQuestLogEntries","GetInfo","IsOnQuest","GetSelectedQuest","SetSelectedQuest","ExpandQuestHeader","CollapseQuestHeader"})do
        if type(api[name])~="function"then missing[#missing+1]=name end
    end
    return{state=Q.scanState or"pending",lastError=Q.lastError or"",mode=api.mode,missing=table.concat(missing,","),quests=#(Q.quests or{}),sampleAge=Q.sampleAt and A.Now()-Q.sampleAt or -1}
end
-- Synchronous transaction: record every expansion before mutating, and undo
-- in reverse order even when an API throws or a bounded scan is incomplete.
function Q.Scan()
    if Q.scanning then return false,"deferred"end
    local canScan,deferReason=Q.CanScan()
    if not canScan then scanState("deferred",deferReason);return false,"deferred"end
    local api=questAPI()
    for _,name in ipairs({"GetNumQuestLogEntries","GetInfo","IsOnQuest","GetSelectedQuest","SetSelectedQuest","ExpandQuestHeader","CollapseQuestHeader"})do
        if type(api[name])~="function"then scanState("error","quest API unavailable: "..name);return false,Q.lastError end
    end
    Q.scanning=true
    local undo,headers,quests,ids={},{},{},{};local selection,originalCount
    local function entries()local n=safeCall(api.GetNumQuestLogEntries);if not L.Int(n,0,Q.MAX_ENTRIES)then error("incomplete quest log")end;return n end
    local function headerMatches(info,h)return info.isHeader==true and info.title==h.title and info.headerSortKey==h.sortKey end
    local ok,reason=pcall(function()
        selection=safeCall(api.GetSelectedQuest);if not L.Int(selection,0,10000000)then error("quest selection unavailable")end
        originalCount=entries()
        for index=1,originalCount do local info=readInfo(api,index);if info.isHeader then headers[#headers+1]={index=index,title=info.title,sortKey=info.headerSortKey,collapsed=info.isCollapsed}end end
        local index,category,categoryOrder=1,"",0
        while index<=entries()do
            local info=readInfo(api,index)
            if info.isHeader then
                if type(info.isCollapsed)~="boolean"or not L.Text(info.title,256)then error("invalid quest header")end
                category,categoryOrder=info.title,index
                if info.isCollapsed then
                    undo[#undo+1]={index=index,title=info.title,sortKey=info.headerSortKey}
                    if safeCall(api.ExpandQuestHeader,index)==false then error("quest header expansion failed")end
                    local opened=readInfo(api,index);if not headerMatches(opened,undo[#undo])or opened.isCollapsed then error("quest header expansion incomplete")end
                end
            elseif not info.isHidden and not info.isInternal then
                local id=info.questID
                if not L.Int(id,1,10000000)or not L.Text(info.title,256)or safeCall(api.IsOnQuest,id)~=true then error("incomplete quest entry")end
                if not ids[id]then
                    if #quests>=Q.MAX_IDS then error("quest ID limit exceeded")end
                    ids[id]=true;quests[#quests+1]={id=id,title=info.title,level=L.Int(info.level,0,100)and info.level or 0,category=category,categoryOrder=categoryOrder}
                end
            end
            index=index+1
        end
    end)
    local restored=true
    for index=#undo,1,-1 do local h=undo[index]
        local success=pcall(function()
            local info=readInfo(api,h.index);if not headerMatches(info,h)then error("quest header changed")end
            if not info.isCollapsed and safeCall(api.CollapseQuestHeader,h.index)==false then error("quest header restoration failed")end
            info=readInfo(api,h.index);if not headerMatches(info,h)or info.isCollapsed~=true then error("quest header not restored")end
        end);if not success then restored=false end
    end
    local success=pcall(function()
        if selection~=nil and safeCall(api.GetSelectedQuest)~=selection then if safeCall(api.SetSelectedQuest,selection)==false then error("selection restoration failed")end end
        if selection~=nil and safeCall(api.GetSelectedQuest)~=selection then error("selection not restored")end
        if originalCount~=nil and entries()~=originalCount then error("quest log changed during scan")end
        for _,h in ipairs(headers)do local info=readInfo(api,h.index);if not headerMatches(info,h)or info.isCollapsed~=h.collapsed then error("header not restored")end end
    end)
    Q.scanning=false
    if not ok or not restored or not success then scanState("error",tostring(reason or"quest log restoration failed"));return false,Q.lastError end
    table.sort(quests,function(a,b)return a.id<b.id end)
    local values={};for _,q in ipairs(quests)do values[#values+1]=tostring(q.id)end
    Q.quests,Q.ids,Q.sampleAt,Q.signature=quests,ids,A.Now(),table.concat(values,",");scanState("ready");dirty();return true
end
function Q.DecodeRecord(wire)
    local f=Z.Network3.Unpack(wire)
    if not f or #f~=5 or f[1]~="1"or not L.Text(f[2],32)or not f[2]:match("^%d+%.%d+%.%d+$")or(f[4]~="0"and f[4]~="1")then return nil end
    local at=tonumber(f[3]);if not L.Int(at,1,4102444800)or at>A.Now()+120 or A.Now()-at>Q.TTL or#f[5]>2304 then return nil end
    if f[4]=="0"and f[5]~=""then return nil end
    local ids,count,previous={},0,0
    if f[5]~=""then
        if not f[5]:match("^%d[%d,]*%d$")and not f[5]:match("^%d+$")then return nil end
        if f[5]:find(",,",1,true)then return nil end
        for value in f[5]:gmatch("[^,]+")do local id=tonumber(value);count=count+1
            if not L.Int(id,1,10000000)or id<=previous or count>Q.MAX_IDS or tostring(id)~=value then return nil end
            ids[id]=true;previous=id
        end
    end
    return{session=f[2],at=at,shared=f[4]=="1",ids=ids}
end
function Q.Record(key)
    local contact=Z.db.contacts[key];local peer=Z.db.peers[key]
    if not contact or key==Z.me.key or Z.db.blocked[key]or not peer or not peer.presence or peer.presence.classFile==""or not Z.IsOnline(key)then return nil end
    if A.Now()-(peer.presence.sourceAt or peer.presence.at or 0)>=300 then return nil end
    for _,character in pairs(Z.account and Z.account.characters or{})do if L.Identity(character.target)==L.Identity(contact.target)then return nil end end
    local mesh=Z.QuestMesh;local row=mesh and mesh.records[L.Identity(contact.target).."/QH/"]
    if not row or row.session~=peer.session or A.Now()-row.at>Q.TTL then return nil end
    local record=row.questRecord or Q.DecodeRecord(row.wire);if not record or not record.shared then return nil end
    row.questRecord=record -- Immutable record; replacement/session expiry drops this cache.
    return record
end
local function matchEntry(key,contact,members)
    local record=Q.Record(key);if not record then return nil end
    local presence=Z.db.peers[key].presence;local common,shared=0,{}
    for questID in pairs(Q.ids)do if record.ids[questID]then common=common+1;shared[#shared+1]=questID end end
    local status=members[key]and"Your group"or presence.availability=="GROUP"and"In group"or presence.availability=="AFK"and"AFK"or presence.availability=="BUSY"and"Busy"or"Available"
    if common>0 then return{key=key,target=contact.target,classFile=presence.classFile,level=presence.level,common=common,status=status,free=status=="Available",quests=shared,inGroup=members[key]~=nil,availability=presence.availability}end
end
-- Revalidate one overlap, without rescanning or sorting all community contacts.
function Q.MatchMember(key)
    if not Q.sampleAt or A.Now()-Q.sampleAt>Q.TTL then return nil end
    local contact=Z.db.contacts[key];if contact then return matchEntry(key,contact,A.GroupMembers())end
end
-- Visit validated overlaps without sorting the entire community. The visitor
-- owns each ephemeral entry; QuestHelper remains the authority for its data.
function Q.VisitMatches(visitor)
    if not Q.sampleAt or A.Now()-Q.sampleAt>Q.TTL then return end
    local members=A.GroupMembers()
    for key,contact in pairs(Z.db.contacts)do local entry=matchEntry(key,contact,members);if entry then visitor(entry)end end
end
function Q.AllMatches()
    local result,entries={},{};Q.VisitMatches(function(entry)entries[#entries+1]=entry end)
    table.sort(entries,function(a,b)if a.free~=b.free then return a.free end;if a.common~=b.common then return a.common>b.common end;return a.target<b.target end)
    for _,entry in ipairs(entries)do for _,id in ipairs(entry.quests)do result[id]=result[id]or{};result[id][#result[id]+1]=entry end end
    return result
end
function Q.Matches(id)return Q.AllMatches()[id]or{} end
function Q.CanInvite(key,id)
    if not Q.ids[id]or not Q.sampleAt or A.Now()-Q.sampleAt>Q.TTL then return false,"Quest data unavailable."end
    local record=Q.Record(key);if not record or not record.ids[id]then return false,"Quest match no longer available."end
    if A.GroupMembers()[key]or Z.db.peers[key].presence.availability~="AVAILABLE"then return false,"Player is unavailable or already grouped."end
    if Q.invites[key]and A.Clock()<Q.invites[key]then return false,"Invitation pending."end
    local state=A.GroupState();if not state.canInvite then return false,"You cannot invite players."end
    local limit=A.Call(IsInRaid)==true and(MAX_RAID_MEMBERS or 40)or(MAX_PARTY_MEMBERS and MAX_PARTY_MEMBERS+1 or 5)
    if state.total>=limit then return false,"The group is full."end
    return true
end
function Q.Invite(key,id)
    local ok,reason=Q.CanInvite(key,id);if not ok then return false,reason end
    if not C_QuestLog or A.Call(C_QuestLog.IsOnQuest,id)~=true then Q.OnEvent();return false,"Quest match no longer available."end
    ok,reason=A.Invite(Z.db.contacts[key].target);if ok then Q.invites[key]=A.Clock()+60;dirty()end;return ok,reason
end
function Q.PrivacyChanged()
    Q.publishedSignature=nil;Q.nextRefresh=0;Q.scanDue=A.Clock()+1
    if Z.QuestMesh then Z.QuestMesh.PrivacyChanged()end
end
function Q.Tick()
    if not Q.quests then return end
    local clock=A.Clock()
    local members=A.GroupMembers()
    for key,untilClock in pairs(Q.invites)do if clock>=untilClock or members[key]then Q.invites[key]=nil;dirty()end end
    if Q.scanDue and clock>=Q.scanDue then if Q.Scan()then Q.scanDue=nil else Q.scanDue=clock+2 end end
    if clock-Q.lastPublish<10 then return end
    if not Q.Sharing()then
        if Q.publishedSignature~="withdrawn"and Z.db.consent and Z.db.autoDiscovery and Z.identityReady and not Z.offlineOnly then
            if Z.QuestMesh.Publish("QH",Z.Network3.Pack({"1",Z.session,A.Now(),"0",""}))then Q.publishedSignature="withdrawn";Q.lastPublish=clock end
        end
        return
    end
    if not Q.sampleAt or A.Now()-Q.sampleAt>Q.TTL or Q.scanDue then return end
    if Q.signature~=Q.publishedSignature or clock>=Q.nextRefresh then
        -- A heartbeat must certify the current log, never renew a failed sample.
        if clock>=Q.nextRefresh and Q.publishedSignature~=nil and not Q.Scan()then Q.scanDue=clock+2;return end
        local wire=Z.Network3.Pack({"1",Z.session,Q.sampleAt,"1",Q.signature})
        if Z.QuestMesh.Publish("QH",wire)then Q.publishedSignature=Q.signature;Q.lastPublish=clock;Q.nextRefresh=clock+math.random(600,720)end
    end
end
return Q
