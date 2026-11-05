-- Optional outbound-only transport. Pixel display is not proof of reception.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local P,T=Z.CompanionProtocol,Z.CompanionTelemetry
local C={};Z.Companion=C
C.TOPICS={'position','map','inventory','quests','character','community','materials','activities','private','groups','requests','notifications','chat','professions','trade','player','itemdetails','mapcatalog','questareas','progress'}
local intervals={identity=60,position=1,inventory=5,quests=5,character=10,community=60,materials=15,activities=30,private=60,heartbeat=5,policy=60}
for _,topic in ipairs({'groups','requests','notifications','chat','player'})do intervals[topic]=5 end
intervals.professions=60;intervals.trade=30;intervals.map=5
intervals.itemdetails=1
intervals.mapcatalog=.5;intervals.questareas=5
intervals.progress=5
local incomingEvents={'CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER','CHAT_MSG_RAID_WARNING','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER','CHAT_MSG_GUILD','CHAT_MSG_OFFICER','CHAT_MSG_WHISPER','CHAT_MSG_BN_WHISPER','CHAT_MSG_WHISPER_INFORM','CHAT_MSG_BN_WHISPER_INFORM','CHAT_MSG_CHANNEL','CHAT_MSG_EMOTE','CHAT_MSG_TEXT_EMOTE','CHAT_MSG_LOOT','CHAT_MSG_MONEY','CHAT_MSG_SYSTEM'}
local incomingSet={};for _,event in ipairs(incomingEvents)do incomingSet[event]=true end
local defaultCategories={position=true,inventory=true,quests=true,character=true,community=true,activities=true}
local function logging()
    local fn=C_ChatInfo and C_ChatInfo.IsLoggingChat
    if type(fn)=='function'then return A.Call(fn)==true end
    return A.Call(LoggingChat)==true
end
local function changed()if C.RefreshUI then C.RefreshUI()end end
function C.IsPixel()return not C.settings or C.settings.transport~='chatlog'end
function C.Status()
    local f=C.filterStats or{};local p=C.flushProbe
    return{state=C.state or'disabled',reason=C.reason or'',sent=C.stats and C.stats.sent or 0,echoed=C.stats and C.stats.echoed or 0,
        automatic=C.stats and C.stats.automatic or 0,queued=C.pendingCount or 0,logging=not C.IsPixel()and logging()or false,session=C.session or'',lastSend=C.lastSend or 0,
        filterCalls=f.calls or 0,filterHidden=f.hidden or 0,filterUnmatched=f.unmatched or 0,filterForeign=f.foreign or 0,filterUnreadable=f.unreadable or 0,
        transport=C.IsPixel()and'pixel'or'chatlog',pixelPackets=C.Pixel and C.Pixel.packets or 0,
        flushState=p and p.state or'idle',flushStep=p and p.step or 0,flushMethod=p and p.method or'',flushStartedAt=p and p.startedAt or 0}
end
function C.Stop(reason)
    if C.QuestAreas then C.QuestAreas.Reset()end
    if C.Pixel and not C.debugPixel then C.Pixel.Stop()end
    local probe=C.flushProbe
    -- Late server echoes can arrive after an automatic timeout. Keep only the
    -- exact own lines for a short, callback-only drain; manual OFF removes it.
    if reason and C.settings and C.settings.enabled then
        C.retiredLines={};for line in pairs(C.waiting or{})do C.retiredLines[line]=true end
        for line in pairs(C.seenEcho or{})do C.retiredLines[line]=true end
        C.retiredUntil=A.Clock()+60
    else C.retiredLines=nil;C.retiredUntil=nil end
    C.running=false;C.state=reason and'blocked'or'disabled';C.reason=reason or'';C.jobs={};C.latest={};C.waiting={};C.due={};C.signatures={};C.finished={};C.seenEcho={};C.pendingCount=0
    if C.SetActive then C.SetActive(C.debugPixel==true,C.retiredUntil~=nil)end
    if C.flushFrame then C.flushFrame:UnregisterAllEvents();C.flushFrame:SetScript('OnEvent',nil);C.flushFrame:SetScript('OnUpdate',nil)end
    C.chatRows={};C.chatCounter=0;C.chatDropped=0;C.clubChatBlocked=false;C.positionRenewAt=0
    -- Restore only logging enabled by this module. Pre-existing user logging stays on.
    if C.flushProbe and C.flushProbe.state=='running'then C.flushProbe.state='stopped'end
    -- An explicit stop between the two timer phases must preserve logging
    -- which was already enabled before the export. Never retry a refused call.
    if probe and probe.closed and not C.ownsLogging and not C.loggingCall then
        probe.closed=false;C.inCall=true;C.loggingCall=true
        local ok=type(LoggingChat)=='function'and pcall(LoggingChat,true)
        C.inCall=false;C.loggingCall=false
        if not ok or not logging()then C.state='blocked';C.reason='Log test stopped; logging could not be restored. Check /chatlog.'end
    end
    if C.ownsLogging then C.ownsLogging=false;if not C.loggingCall and type(LoggingChat)=='function'then pcall(LoggingChat,false)end end
    changed()
end
function C.Initialize()
    local root=ZenialCommunityDB
    if not root or not Z.me or Z.offlineOnly then return end
    root.companion=type(root.companion)=='table'and root.companion or{version=1,characters={}}
    if root.companion.version~=1 or type(root.companion.characters)~='table'then C.Stop('Unsupported companion settings; preserved.');return end
    local key=Z.storageKey or Z.me.key;local s=root.companion.characters[key]
    if type(root.companion.shared)=='table'then s=root.companion.shared
    elseif type(s)~='table'then
        for _,previous in pairs(root.companion.characters)do if type(previous)=='table'and previous.enabled==true then s=previous;break end end
    end
    if type(s)~='table'then s={enabled=false,categories={},sessionSequence=0};root.companion.characters[key]=s end
    -- Export options belong to the account. Character data and old settings
    -- remain separate/preserved; later logins use this one authoritative table.
    root.companion.shared=s
    s.categories=type(s.categories)=='table'and s.categories or{}
    for _,topic in ipairs(C.TOPICS)do if type(s.categories[topic])~='boolean'then s.categories[topic]=defaultCategories[topic]==true end end
    if s.enabled==true then for _,topic in ipairs(C.TOPICS)do s.categories[topic]=true end end
    s.questAreasEnabled=s.questAreasEnabled==true;s.categories.questareas=s.questAreasEnabled
    s.categories.map=s.categories.position -- Map texture references share the position opt-in.
    s.categories.mapcatalog=s.categories.position
    s.categories.itemdetails=s.categories.inventory or s.categories.character
    if s.transport~='chatlog'then s.transport='pixel'end
    C.settings=s;C.source=P.Source(Z.me.key);C.stats={sent=0,echoed=0,automatic=0};C.Stop()
    if s.enabled==true then C.BeginSession()end
end
function C.BeginSession()
    if not C.settings or not Z.identityReady or A.Now()<1 then return false end
    C.settings.sessionSequence=(tonumber(C.settings.sessionSequence)or 0)%1000000000+1
    C.session=string.format('%.0f.%d.%.0f',A.Now(),C.settings.sessionSequence,math.floor(A.Clock()*1000))
    C.sequence=0;C.jobs={};C.latest={};C.finished={};C.signatures={};C.due={};C.waiting={};C.seenEcho={};C.stats={sent=0,echoed=0,automatic=0}
    C.itemDetailSent={}
    C.questScanDue=0;if C.QuestAreas then C.QuestAreas.Reset()end
    C.mapCatalogIDs=nil;C.mapCatalogCursor=nil;C.mapCatalogDue=nil;C.mapCatalogEssential=nil;C.mapCatalogEssentialMap=nil;C.mapCatalogEssentialDue=0
    C.chatRows={};C.chatCounter=0;C.chatDropped=0;C.clubChatBlocked=false
    C.questPoints={}
    C.filterStats={calls=0,hidden=0,unmatched=0,foreign=0,unreadable=0};C.flushProbe=nil
    C.retiredLines=nil;C.retiredUntil=nil
    if C.Pixel and not C.debugPixel then C.Pixel.Stop();C.Pixel.packets=0 end
    C.cursor=1;C.state='logging-required';C.reason='';C.running=true;C.nextSend=0;C.loggingAttempted=false;C.loggingDue=A.Clock()+1;C.startedAt=A.Clock();C.blockedCall=nil
    C.SetActive(true)
    changed();return true
end
function C.Enable(enabled)
    if not C.settings then return false end;C.settings.enabled=enabled==true
    if enabled then return C.BeginSession()else C.Stop();return true end
end
function C.SetExportEnabled(enabled)
    if not C.settings then return false end
    if enabled then
        for _,topic in ipairs(C.TOPICS)do C.settings.categories[topic]=true end
        C.settings.categories.questareas=C.settings.questAreasEnabled==true
        C.settings.transport='pixel'
    end
    return C.Enable(enabled)
end
function C.SetCategory(topic,enabled)
    if not C.settings or C.settings.categories[topic]==nil then return false end
    if topic=='questareas'then C.settings.questAreasEnabled=enabled==true;if C.QuestAreas then C.QuestAreas.Reset()end end
    C.settings.categories[topic]=enabled==true;C.jobs[topic]=nil;C.latest[topic]=nil;C.signatures[topic]=nil;C.due[topic]=0;C.due.policy=0
    if topic=='position'then
        for _,related in ipairs({'map','mapcatalog'})do C.settings.categories[related]=enabled==true;C.jobs[related]=nil;C.latest[related]=nil;C.signatures[related]=nil;C.due[related]=0 end
        C.mapCatalogIDs=nil
    end
    if topic=='inventory'or topic=='character'then
        C.settings.categories.itemdetails=C.settings.categories.inventory or C.settings.categories.character
        C.jobs.itemdetails=nil;C.latest.itemdetails=nil;C.signatures.itemdetails=nil;C.due.itemdetails=0;C.itemDetailSent={}
    end
    C.jobs.policy=nil;C.latest.policy=nil;C.finished.policy=nil
    if topic=='chat'then C.chatRows={};C.chatCounter=0;C.chatDropped=0;C.finished.chat=nil;C.ConfigureChat()end
    changed();return true
end
function C.Queue(topic,data,force)
    local ok,signature=pcall(P.Json,data)
    if not ok then
        -- A single restricted/oversized category must not stop position updates.
        -- Export an explicit unavailable state instead of a partial fake baseline.
        data={available=false,reason='restricted-or-excessive-export'}
        if topic=='inventory'then data.items=P.Array();data.replace=true end
        signature=P.Json(data);C.reason='Export unavailable: '..topic;changed()
    end
    if force or C.signatures[topic]~=signature then C.latest[topic]={data=data,signature=signature,observedAt=A.Now()};C.signatures[topic]=signature end
    return true
end
local function inventoryDelta(data,previous)
    if data.available==false then data.replace=true;return data end
    if not previous then data.replace=true;return data end
    local old={};for _,r in ipairs(previous.data.items or{})do old[r.itemID]=P.Json(r)end
    local added=P.Array();local seen={}
    for _,r in ipairs(data.items or{})do seen[r.itemID]=true;if old[r.itemID]~=P.Json(r)then added[#added+1]=r end end
    local removed=P.Array();for id in pairs(old)do if not seen[id]then removed[#removed+1]=id end end
    return{replace=false,baseSequence=previous.sequence,available=data.available,observedAt=data.observedAt,scope=data.scope,items=added,removed=removed,slots=data.slots,bags=data.bags}
end
function C.Job(topic)
    if C.jobs[topic]then return C.jobs[topic]end
    local row=C.latest[topic];if not row then return nil end;C.latest[topic]=nil
    C.sequence=C.sequence+1
    local data=row.data
    if topic=='chat'and data.available~=false then
        local prior=C.finished.chat;local previous=prior and prior.data
        local replay=C.IsPixel()and prior and A.Clock()-(prior.fullAt or 0)>=15
        local after=not replay and previous and previous.lastCounter or 0
        local entries=P.Array();local more=false;local last=after;local missed=previous and previous.missed or 0
        for _,entry in ipairs(data.entries or{})do if entry.counter>after then
            if#entries<4 then
                if#entries==0 and entry.counter>after+1 and not replay then missed=missed+entry.counter-after-1 end
                entries[#entries+1]=entry;last=entry.counter
            else more=true end
        end end
        if more then C.latest.chat={data=row.data,signature=row.signature,observedAt=row.observedAt}end
        data={replace=previous==nil or replay==true,entries=entries,lastCounter=last,missed=missed,dropped=row.data.dropped,clubChatBlocked=row.data.clubChatBlocked,scope='incoming-selected-chat-events',historyBeforeEnable=false}
        row.fullAt=data.replace and A.Clock()or prior.fullAt
        -- Envelope time certifies this export, not the age of its oldest chat
        -- message. Per-entry timestamps preserve history without making a fresh
        -- replay fail the receiver's ten-minute transport expiry.
        row.data=data
    end
    if topic=='inventory'then
        local prior=C.finished.inventory
        if prior and A.Clock()-prior.fullAt>=(C.IsPixel()and 15 or 60)then prior=nil end
        data=inventoryDelta(data,prior);row.fullAt=data.replace and A.Clock()or C.finished.inventory.fullAt
    end
    local ok,body=pcall(P.Json,{origin='timer',uptime=A.Clock(),data=data})
    if not ok then C.Stop('Payload could not be encoded: '..topic);return nil end
    local lines,reason=P.Frames(C.source,C.session,C.sequence,topic,row.observedAt,body)
    if not lines then C.Stop(reason);return nil end
    local job={lines=lines,next=1,at=A.Clock(),data=row.data,sequence=C.sequence,fullAt=row.fullAt};C.jobs[topic]=job;return job
end
local function choose()
    -- Identity must complete before any data. Thereafter reserve every other
    -- send for position; the remaining topics rotate so bulk exports cannot starve them.
    if not C.finished.identity then return'identity'end
    if not C.finished.policy then return'policy'end
    if C.jobs.position or C.latest.position then
        if not C.positionTurn then C.positionTurn=true;return'position'end
    end
    C.positionTurn=false
    -- Reserve one in four non-position lines for initial descriptions/essential
    -- atlas records. Movement keeps its half; normal topics retain a fair share.
    C.bootstrapTurn=(C.bootstrapTurn or 0)+1
    if C.bootstrapTurn%4==0 then
        local first=C.bootstrapNext=='itemdetails'and'itemdetails'or'mapcatalog'
        for _,topic in ipairs({first,first=='itemdetails'and'mapcatalog'or'itemdetails'})do
            local job=C.jobs[topic]or C.latest[topic]
            if job and job.data and job.data.bootstrap then C.bootstrapNext=topic=='mapcatalog'and'itemdetails'or'mapcatalog';return topic end
        end
    end
    local order={'identity','policy','heartbeat'};for _,topic in ipairs(C.TOPICS)do if topic~='position'then order[#order+1]=topic end end
    for _=1,#order do local topic=order[C.cursor];C.cursor=C.cursor%#order+1
        if C.jobs[topic]or C.latest[topic]then return topic end
    end
    return'position'
end
function C.OnBlocked(event,addon,fn)
    if C.QuestAreas and C.QuestAreas.inCall and A.Safe(addon)and addon=='ZenialCommunity'then C.QuestAreas.Fail('native-call-blocked');return end
    if C.readingChat and A.Safe(addon)and addon=='ZenialCommunity'then C.clubChatBlocked=true;return end
    if C.inCall and A.Safe(addon,fn)and addon=='ZenialCommunity'then C.blockedCall=tostring(fn or event);C.Stop('WoW blocked '..C.blockedCall..'. Automatic export stopped.')end
end
function C.SendLine(line,origin)
    if C.IsPixel()then
        if not C.Pixel or not C.Pixel.Publish(line)then C.Stop('Pixel packet unavailable.');return false end
        C.stats.sent=C.stats.sent+1;if origin=='timer'then C.stats.automatic=C.stats.automatic+1 end
        C.lastSend=A.Now();return true
    end
    local fn=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if type(fn)~='function'then C.Stop('Chat sending API unavailable.');return false end
    if A.Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)==true then C.Stop('Chat is locked down. Restart the probe after the restriction ends.');return false end
    C.blockedCall=nil;C.inCall=true
    C.waiting[line]=A.Clock()
    local ok,result=pcall(fn,line,'WHISPER',nil,Z.me.target)
    C.inCall=false
    if C.blockedCall then return false end
    if not ok or not A.Safe(result)or result==false or type(result)=='number'and result~=0 then
        C.Stop('Chat send refused. Automatic export stopped.');return false
    end
    C.stats.sent=C.stats.sent+1;if origin=='timer'then C.stats.automatic=C.stats.automatic+1 end
    C.lastSend=A.Now();return true
end
function C.Probe()
    if not C.settings then return false end
    C.settings.enabled=true;if not C.BeginSession()then return false end
    if C.IsPixel()then C.state='unverified';C.reason='Pixel transport requires verification in the companion.';changed();return true end
    if not logging()then C.reason='Enable /chatlog once, then start the probe again.';changed();return false end
    -- This first send runs in our own button click. Timer-origin sends follow
    -- only in Tick; input events never drain the queue or impersonate a timer.
    local body=P.Json({origin='click',uptime=A.Clock(),data={phase='initial'}})
    C.sequence=C.sequence+1
    local lines=P.Frames(C.source,C.session,C.sequence,'probe',A.Now(),body)
    for _,line in ipairs(lines or{})do if not C.SendLine(line,'click')then return false end end
    C.state='probing';C.reason='Automatic delivery is unverified; inspect the companion diagnostics.';changed();return true
end
function C.OnEcho(message,sender)
    if C.IsPixel()then return end
    if not C.running or not A.Safe(message,sender)or type(message)~='string'or L.Identity(sender)~=L.Identity(Z.me.target)then return end
    if C.waiting[message]and not C.seenEcho[message]then C.seenEcho[message]=true;C.waiting[message]=nil;C.stats.echoed=C.stats.echoed+1 end
end
function C.ChatFilter(_,_,message,sender)
    -- Filter only an exact line actually sent in this session and only to self.
    local retired=C.retiredUntil and C.settings and C.settings.enabled and A.Clock()<=C.retiredUntil
    if not C.running and not retired then C.retiredLines=nil;C.retiredUntil=nil;return false end
    local f=C.filterStats;f.calls=f.calls+1
    if not A.Safe(message,sender)or type(message)~='string'then f.unreadable=f.unreadable+1;return false end
    if not Z.me or L.Identity(sender)~=L.Identity(Z.me.target)then f.foreign=f.foreign+1;return false end
    local hide=C.waiting and(C.waiting[message]~=nil or C.seenEcho[message]==true)or retired and C.retiredLines[message]==true or false
    if hide then f.hidden=f.hidden+1 else f.unmatched=f.unmatched+1 end
    return hide
end
function C.StartFlushProbe()
    if C.IsPixel()then return false end
    if not logging()then C.reason='Enable /chatlog before the flush test.';changed();return false end
    if C.flushProbe and C.flushProbe.state=='running'then return false end
    -- Own button arms a finite timer test; it does not call LoggingChat itself.
    -- Same-callback off/on did not flush in the real client. Leave logging
    -- off across frames for at least 250 ms; no new whispers run during this test.
    C.flushProbe={state='running',step=0,nextAt=A.Clock()+1,startedAt=A.Now(),method='close-wait-reopen'}
    if not C.running then C.reason='Independent log test running; no whisper is retried.'end
    C.flushFrame:RegisterEvent('ADDON_ACTION_BLOCKED');C.flushFrame:RegisterEvent('ADDON_ACTION_FORBIDDEN')
    C.flushFrame:SetScript('OnEvent',function(_,event,...)C.OnBlocked(event,...)end)
    C.flushFrame:SetScript('OnUpdate',function()C.FlushTick(A.Clock())end)
    changed();return true
end
local function changeLogging(enabled)
    C.blockedCall=nil;C.inCall=true;C.loggingCall=true
    local ok=type(LoggingChat)=='function'and pcall(LoggingChat,enabled)
    C.inCall=false;C.loggingCall=false
    return C.flushProbe and C.flushProbe.state=='running'and not C.blockedCall and ok and logging()==enabled
end
function C.FlushTick(clock)
    local p=C.flushProbe;if not p or p.state~='running'then return end
    if p.closed then
        if clock<p.reopenAt then return end
        -- Clear before calling so a refusal cannot cause a cleanup retry.
        p.closed=false
        if not changeLogging(true)then
            C.ownsLogging=false;if p.state=='running'then C.Stop('Timed log-flush test refused; export stopped. Check /chatlog before another test.')end;return
        end
        if p.step>=10 then
            p.state='complete';p.finishedAt=A.Now();C.flushFrame:UnregisterAllEvents();C.flushFrame:SetScript('OnEvent',nil);C.flushFrame:SetScript('OnUpdate',nil)
        else p.nextAt=clock+1 end
    else
        if clock<p.nextAt then return end
        p.step=p.step+1
        if not changeLogging(false)then
            C.ownsLogging=false;if p.state=='running'then C.Stop('Timed log-flush test refused; export stopped without retry.')end;return
        end
        p.closed=true;p.reopenAt=clock+.25
    end
    changed()
end
function C.Tick()
    if C.debugPixel then C.DebugTick();return end
    if not C.running or not C.settings or not C.settings.enabled then return end
    local clock=A.Clock()
    if C.QuestAreas then C.QuestAreas.Tick()end
    -- Refresh the existing safe quest-log transaction only while exporting.
    -- Defer for combat/open game panels; never mutate those panels for the export.
    if C.settings.categories.quests and clock>=(C.questScanDue or 0)then
        C.questScanDue=clock+30
        if Z.QuestHelper.CanScan()then Z.QuestHelper.OnEvent()end
    end
    -- The independent probe owns both logger phases. The export must neither
    -- reopen its intentional gap nor mistake pre-existing logging for its own.
    if C.flushProbe and C.flushProbe.state=='running'then return end
    if not C.IsPixel()and not logging()then
        C.state='logging-required'
        if not C.loggingAttempted and clock>=C.loggingDue then
            C.loggingAttempted=true;C.inCall=true;local ok=type(LoggingChat)=='function'and pcall(LoggingChat,true);C.inCall=false
            if C.blockedCall then return end
            if not ok or not logging()then C.reason='Enable /chatlog once; no data was sent.';changed();return end
            C.ownsLogging=true
        else return end
    end
    if not C.IsPixel()and not C.filterReady then C.Stop('Whisper filters unavailable; no export was sent.');return end
    C.state='unverified';C.reason=C.IsPixel()and'Pixel transport requires verification in the companion.'or'Automatic transport requires verification in the companion.'
    for line,at in pairs(C.waiting)do if clock-at>10 then C.Stop('No self-whisper echo within 10 seconds. Export stopped.');return end end
    -- Keep only a bounded set of previously sent exact lines for UI filtering.
    if L.Count(C.seenEcho)>2048 then C.seenEcho={}end
    for topic,interval in pairs(intervals)do
        if C.IsPixel()then
            if topic=='identity'or topic=='policy'then interval=10 elseif topic=='position'then interval=.25 elseif topic=='heartbeat'then interval=2 else interval=math.min(interval,5)end
        end
        if clock>=(C.due[topic]or 0)and(topic=='identity'or topic=='policy'or topic=='heartbeat'or C.settings.categories[topic])then
            C.due[topic]=clock+interval
            if topic=='policy'then C.Queue(topic,{categories=C.settings.categories},true)
            elseif topic=='heartbeat'then C.Queue(topic,{transport=C.IsPixel()and'pixel'or'chatlog',automatic=C.stats.automatic,echoed=C.stats.echoed,probeStartedAt=C.startedAt,flushProbe=C.flushProbe and{state=C.flushProbe.state,step=C.flushProbe.step,method=C.flushProbe.method,startedAt=C.flushProbe.startedAt}},true)
            elseif T[topic]then
                local ok,data=pcall(T[topic]);if ok and type(data)=='table'then
                    local renew=topic=='position'and clock>=(C.positionRenewAt or 0)
                    local prior=C.finished[topic]
                    local replay=C.IsPixel()and prior and clock-(prior.sentAt or 0)>=20
                    C.Queue(topic,data,renew or topic=='identity'or replay or topic=='inventory'and C.finished.inventory and clock-C.finished.inventory.fullAt>=(C.IsPixel()and 15 or 60))
                    if renew then C.positionRenewAt=clock+(C.IsPixel()and 1 or 5)end
                elseif not ok then C.reason='Data unavailable: '..topic end
            end
        end
    end
    if clock<C.nextSend then return end;C.nextSend=clock+(C.IsPixel()and .15 or .5)
    if C.IsPixel()then C.Pixel.BeginBatch()end
    for _=1,C.IsPixel()and 3 or 1 do
        local topic=choose();local job=C.Job(topic);if not job then break end
        local line=job.lines[job.next]
        if not C.SendLine(line,'timer')then return end
        job.next=job.next+1
        if job.next>#job.lines then
            C.finished[topic]={data=job.data,sequence=job.sequence,fullAt=job.fullAt,sentAt=clock};C.jobs[topic]=nil
            if C.IsPixel()and topic=='identity'then
                -- A receiver may start at any time. Every repeated identity is
                -- immediately followed by a fresh consent policy, without a reply.
                C.finished.policy=nil;C.jobs.policy=nil;C.latest.policy=nil;C.due.policy=0
            end
        end
    end
    if C.IsPixel()then C.Pixel.Commit()end
    C.pendingCount=L.Count(C.jobs)+L.Count(C.latest);changed()
end
local function debugSnapshot()
    local me=Z.me or{};local directory=Z.CommunityDirectory or{};local status=C.Status()
    local candidates=P.Array();local ids={}
    for id in pairs(directory.candidates or{})do if type(id)=="number"and id==id then ids[#ids+1]=id end end
    table.sort(ids);for i=1,math.min(#ids,20)do
        local row=directory.candidates[ids[i]];local g=row and row.info
        if A.PublicTable(g)and A.Safe(g.gameAccountID,g.characterName,g.playerGuid,g.realmName,g.wowProjectID,g.regionID)then
            candidates[#candidates+1]={gameAccountID=type(g.gameAccountID)=="number"and g.gameAccountID or nil,
                name=type(g.characterName)=="string"and g.characterName:sub(1,128)or nil,guid=type(g.playerGuid)=="string"and g.playerGuid:sub(1,80)or nil,
                realm=type(g.realmName)=="string"and g.realmName:sub(1,64)or nil,project=type(g.wowProjectID)=="number"and g.wowProjectID or nil,
                region=type(g.regionID)=="number"and g.regionID or nil}
        end
    end
    local events=P.Array();local diagnostics=Z.Diagnostics
    for i=math.max(1,#(diagnostics and diagnostics.events or{})-29),#(diagnostics and diagnostics.events or{})do
        local raw=diagnostics.events[i]
        if A.Safe(raw)and type(raw)=="string"then events[#events+1]=raw:sub(1,240)end
    end
    local network=Z.Network3 and Z.Network3.Status()or{};local directoryStatus=directory.Status and directory.Status()or{}
    local bnet=Z.BattleNetTransport or{};local bnetStatus=bnet.Status and bnet.Status()or{}
    return{version=1,addonVersion=Z.ADDON_VERSION,identity={key=me.key,name=me.target or me.name,guid=me.guid,world=me.world or me.realm,class=me.classFile or me.class,faction=me.faction},
        directory={status=directoryStatus,reasons=directory.scanReasons or{},candidates=candidates},
        transport={state=status.state,reason=status.reason,transport=status.transport,sent=status.sent,automatic=status.automatic,queued=status.queued,
            pixelPackets=status.pixelPackets,network={queue=network.queue,bytes=network.bytes,assemblies=network.assemblies,inbound=network.inbound,
                throttle=network.throttle,throttled=network.throttled,sent=network.sent,received=network.received},
            battleNet={status=bnetStatus,stats=bnet.stats or{}}},events=events}
end
function C.DebugTick()
    if not C.debugPixel or not C.Pixel then return end
    local clock=A.Clock()
    if not C.debugLines and clock>=(C.debugRefreshAt or 0)then
        C.debugRefreshAt=clock+1;C.debugSequence=(C.debugSequence or 0)+1
        local ok,body=pcall(function()return P.Json({origin="timer",data=debugSnapshot()})end)
        if ok then
            local lines=P.Frames(C.source or P.Source(Z.me and Z.me.key or"debug"),C.debugSession,C.debugSequence,"debug",A.Now(),body)
            if lines then C.debugLines=lines;C.debugNext=1 end
        end
    end
    if clock<(C.debugSendAt or 0)then return end
    C.debugSendAt=clock+.18;C.Pixel.BeginBatch()
    for _=1,3 do
        local line=C.debugLines and C.debugLines[C.debugNext];if not line then break end
        C.Pixel.Publish(line);C.debugNext=C.debugNext+1
        if C.debugNext>#C.debugLines then C.debugLines=nil;C.debugNext=1;break end
    end
    C.Pixel.Commit(true)
end
function C.SetDebugPixel(enabled)
    enabled=enabled==true
    if enabled==C.debugPixel then return true end
    if enabled then
        if not C.settings or not Z.me then return false end
        C.debugPixel=true;C.debugSession=string.format("%.0f.%d.%.0f",A.Now(),math.floor(A.Clock()*1000)%1000000000,math.floor(A.Clock()*1000))
        C.debugSequence=0;C.debugLines=nil;C.debugNext=1;C.debugRefreshAt=0;C.debugSendAt=0
        C.Pixel.Stop();if C.Vitals then C.Vitals.Hide()end;C.SetActive(true);return true
    end
    C.debugPixel=false;C.debugLines=nil;C.Pixel.Stop();if C.Vitals then C.Vitals.due=0 end;C.SetActive(C.running);return true
end
function C.OnEvent(event,...)
    if C.debugPixel then
        if event=='ADDON_ACTION_BLOCKED'or event=='ADDON_ACTION_FORBIDDEN'then
            local addon,fn=...;if A.Safe(addon,fn)and Z.Diagnostics then Z.Diagnostics.Record('debug:'..event,addon,fn)end
        end
        return
    end
    if event=='CLUB_MESSAGE_ADDED'then C.CaptureClub(...);return end
    if incomingSet[event]then C.CaptureChat(event,...)end
    if event=='CHAT_MSG_WHISPER'or event=='CHAT_MSG_WHISPER_INFORM'then C.OnEcho(...)
    elseif event=='ADDON_ACTION_BLOCKED'or event=='ADDON_ACTION_FORBIDDEN'then C.OnBlocked(event,...)
    elseif event=='BAG_UPDATE_DELAYED'then C.due.inventory=0;C.due.materials=0
    elseif event=='PLAYER_EQUIPMENT_CHANGED'then C.due.character=0
    elseif event=='UNIT_STATS'then local unit=...;if not A.Safe(unit)or unit=='player'then C.due.character=0 end
    elseif event=='GET_ITEM_INFO_RECEIVED'then C.due.inventory=0;C.due.character=0;C.itemDetailSent={};C.due.itemdetails=0
    elseif event:match('^QUEST_')then C.due.quests=A.Clock()+1 end
end
function C.CaptureChat(event,message,sender,language,channel)
    if not C.running or not C.settings.categories.chat or not A.Safe(message,sender,language,channel)or type(message)~='string'or message==''or#message>4096 then return end
    -- Ignore only protocol traffic; own ordinary chat is part of the history.
    if message:find('ZC5~',1,true)then return end
    local outgoing=event=='CHAT_MSG_WHISPER_INFORM'or event=='CHAT_MSG_BN_WHISPER_INFORM'or type(sender)=='string'and L.Identity(sender)==L.Identity(Z.me.target)
    local text=message:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t','')
    local clipped=#text>768;if clipped then text=text:sub(1,768):gsub('[\194-\244][\128-\191]*$','')end
    C.chatCounter=(C.chatCounter or 0)+1
    local recipient=(event=='CHAT_MSG_WHISPER_INFORM'or event=='CHAT_MSG_BN_WHISPER_INFORM')and type(sender)=='string'and#sender<=128 and sender or nil
    C.chatRows[#C.chatRows+1]={id=C.session..':'..C.chatCounter,counter=C.chatCounter,at=A.Now(),channel=event:sub(10):gsub('_INFORM$',''),direction=outgoing and'outgoing'or'incoming',recipient=recipient,conversation=type(channel)=='string'and#channel<=128 and channel or'',sender=outgoing and Z.me.target or type(sender)=='string'and#sender<=128 and sender or'',text=text,truncated=clipped}
    while#C.chatRows>30 do table.remove(C.chatRows,1);C.chatDropped=(C.chatDropped or 0)+1 end
    C.due.chat=0
end
function C.CaptureClub(clubID,streamID,messageID)
    if not C.running or not C.settings.categories.chat or C.clubChatBlocked or not A.Safe(clubID,streamID,messageID)then return end
    local directory=Z.CommunityDirectory;local selected=false
    for _,id in ipairs(directory and directory.config and directory.config.assignment or{})do if tostring(id)==tostring(clubID)then selected=true;break end end
    if not selected or type(C_Club and C_Club.GetMessageInfo)~='function'or A.Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)==true then return end
    C.readingChat=true;local info=A.Call(C_Club.GetMessageInfo,clubID,streamID,messageID);C.readingChat=false
    if C.clubChatBlocked or not A.PublicTable(info)then return end
    local author=info.author
    if not A.PublicTable(author)or not A.Safe(author.isSelf,author.name,info.content,info.destroyed)or info.destroyed==true then return end
    C.CaptureChat('CHAT_MSG_COMMUNITY',info.content,author.isSelf and Z.me.target or author.name,nil,tostring(clubID)..':'..tostring(streamID))
end
local frame=CreateFrame('Frame');C.frame=frame
local flushFrame=CreateFrame('Frame');C.flushFrame=flushFrame
function C.ConfigureChat()
    if C.running and C.settings.categories.chat then pcall(frame.RegisterEvent,frame,'CLUB_MESSAGE_ADDED')else pcall(frame.UnregisterEvent,frame,'CLUB_MESSAGE_ADDED')end
    for _,event in ipairs(incomingEvents)do
        if C.running and C.settings.categories.chat then pcall(frame.RegisterEvent,frame,event)
        elseif(event~='CHAT_MSG_WHISPER'and event~='CHAT_MSG_WHISPER_INFORM')or C.IsPixel()then pcall(frame.UnregisterEvent,frame,event)end
    end
end
function C.SetActive(active,keepFilters)
    frame:UnregisterAllEvents();frame:SetScript('OnEvent',nil);frame:SetScript('OnUpdate',nil)
    local remove=ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    if not keepFilters and C.filtersInstalled and type(remove)=='function'then
        pcall(remove,'CHAT_MSG_WHISPER',C.ChatFilter);pcall(remove,'CHAT_MSG_WHISPER_INFORM',C.ChatFilter);C.filtersInstalled=false
    end
    C.filterReady=false
    if not active then return end
    if C.debugPixel then
        for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN'})do pcall(frame.RegisterEvent,frame,event)end
        frame:SetScript('OnEvent',function(_,event,...)C.OnEvent(event,...)end)
        local elapsed=0;frame:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=.05 then elapsed=0;C.DebugTick()end end)
        return
    end
    for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','BAG_UPDATE_DELAYED','PLAYER_EQUIPMENT_CHANGED','GET_ITEM_INFO_RECEIVED','QUEST_LOG_UPDATE','QUEST_ACCEPTED','QUEST_REMOVED','QUEST_TURNED_IN'})do pcall(frame.RegisterEvent,frame,event)end
    -- Only the player's stats feed the character view. Prefer a player-only
    -- registration; OnEvent still filters the unit if only RegisterEvent works.
    local unitOK,unitResult=false,nil;if type(frame.RegisterUnitEvent)=='function'then unitOK,unitResult=pcall(frame.RegisterUnitEvent,frame,'UNIT_STATS','player')end
    if not unitOK or unitResult==false then pcall(frame.RegisterEvent,frame,'UNIT_STATS')end
    if not C.IsPixel()then frame:RegisterEvent('CHAT_MSG_WHISPER');frame:RegisterEvent('CHAT_MSG_WHISPER_INFORM')end
    C.ConfigureChat()
    frame:SetScript('OnEvent',function(_,event,...)if C.running then C.OnEvent(event,...)end end)
    local elapsed=0;frame:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=(C.IsPixel()and .05 or .25)then elapsed=0;C.Tick()end end)
    if C.IsPixel()then return end
    local add=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add)=='function'then
        local ok,result=pcall(add,'CHAT_MSG_WHISPER',C.ChatFilter);local other,value=pcall(add,'CHAT_MSG_WHISPER_INFORM',C.ChatFilter)
        C.filterReady=ok and result~=false and other and value~=false;C.filtersInstalled=C.filterReady
        if not C.filterReady and type(remove)=='function'then pcall(remove,'CHAT_MSG_WHISPER',C.ChatFilter);pcall(remove,'CHAT_MSG_WHISPER_INFORM',C.ChatFilter)end
    end
end
