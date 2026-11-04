-- Optional, bounded native hit tests. Never touches the visible map, selection,
-- cursor, supertracking or global POI map. Empty hits are NOT proof of no area.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local C,P=Z.Companion,Z.CompanionProtocol
local B={SIZE=64,MAX_QUESTS=40,MAX_MAPS=16,MAX_RUNS=256,MAX_CALLS=64,BUDGET_MS=.5};C.QuestAreas=B
local function nowMS()local n=A.Call(debugprofilestop);return A.Safe(n)and type(n)=='number'and n==n and n>=0 and n end
local function state(value,reason)if B.state~=value or B.reason~=reason then B.state,B.reason=value,reason;C.due.questareas=0 end end
function B.Reset()
    if B.frame then pcall(B.frame.Hide,B.frame)end
    B.job=nil;B.cache={};B.signatures={};B.maps={};B.ids={};B.cursor=0;B.context=nil;B.mapID=0;B.nextCheck=0;B.failed=false;B.calls=0;B.maxStepMs=0;B.completed=0;B.state='off';B.reason=nil;B.phase='idle'
end
function B.Fail(reason)
    B.inCall=false;B.failed=true;B.job=nil;if B.frame then pcall(B.frame.Hide,B.frame)end;state('blocked',reason)
end
local function invoke(phase,fn,...)
    B.phase=phase
    if type(fn)~='function'then error('native-method-unavailable-'..phase)end
    B.inCall=true;local ok,a,b=pcall(fn,...);B.inCall=false
    if B.failed then error('native-call-blocked')end
    if not ok then error('native-api-error-'..phase)end
    if not A.Safe(a,b)then error('protected-native-result-'..phase)end
    return a,b
end
local function setup()
    if B.frame then return true end
    if not nowMS()then B.Fail('profiling-unavailable');return false end
    local f=invoke('CreateFrame',CreateFrame,'QuestPOIFrame',nil,UIParent)
    if not f then error('native-widget-unavailable')end
    B.frame=f
    for _,method in ipairs({'SetMapID','DrawBlob','DrawNone','UpdateMouseOverTooltip','SetSize','SetPoint','SetAlpha','Show','Hide','EnableMouse'})do if type(f[method])~='function'then error('native-method-unavailable-'..method)end end
    if type(f.SetFillTexture)=='function'then invoke('SetFillTexture',f.SetFillTexture,f,'Interface\\WorldMap\\UI-QuestBlob-Inside')end
    if type(f.SetBorderTexture)=='function'then invoke('SetBorderTexture',f.SetBorderTexture,f,'Interface\\WorldMap\\UI-QuestBlob-Outside')end
    invoke('SetSize',f.SetSize,f,1024,768);invoke('SetPoint',f.SetPoint,f,'TOPLEFT',UIParent,'TOPLEFT',0,0);invoke('SetAlpha',f.SetAlpha,f,0);invoke('EnableMouse',f.EnableMouse,f,false);invoke('Hide',f.Hide,f)
    return true
end
local function inspect()
    local mapID=A.CurrentMapID();if not L.Int(mapID,1,1000000)then state('waiting','map-unavailable');return end
    local ids,seen,parts,targets={},{},{},{}
    local maps,mapSeen={},{}
    local function addMap(id)
        if A.Safe(id)and L.Int(id,1,799999)and not mapSeen[id]and#maps<B.MAX_MAPS then mapSeen[id]=true;maps[#maps+1]=id end
    end
    -- Prefer a quest's actual zone over a city's clipped POI projection.
    for index,q in ipairs(Z.QuestHelper.quests or{})do
        if index>B.MAX_QUESTS then break end
        local waypoint=A.Call(C_QuestLog and C_QuestLog.GetNextWaypoint,q.id);addMap(waypoint)
        if Z.CompanionQuestLocations then addMap(Z.CompanionQuestLocations.AreaMap(q.category))end
        local known=C.questPoints and C.questPoints[q.id];if known then addMap(known.mapID)end
    end
    local info=A.Call(C_Map and C_Map.GetMapInfo,mapID)
    if A.PublicTable(info)then addMap(info.parentMapID)end
    addMap(mapID)
    local readable=false
    for _,area in ipairs(maps)do
        local pois=A.Call(C_QuestLog and C_QuestLog.GetQuestsOnMap,area)
        if A.PublicTable(pois)then
            readable=true
            for _,poi in ipairs(pois)do
                local id=A.PublicTable(poi)and poi.questID
                if#ids<B.MAX_QUESTS and A.Safe(id)and L.Int(id,1,10000000)and not seen[id]and Z.QuestHelper.ids[id]and A.Call(C_QuestLog.IsOnQuest,id)==true then
                    seen[id]=true;ids[#ids+1]=id;targets[id]=area
                end
            end
        end
    end
    if not readable then state('waiting','quest-pois-unavailable');return end
    table.sort(ids)
    local signatures={}
    for _,id in ipairs(ids)do
        local first=#parts+1
        parts[#parts+1]=tostring(targets[id])
        parts[#parts+1]=tostring(id);local objectives=A.Call(C_QuestLog.GetQuestObjectives,id)
        if not A.PublicTable(objectives)or#objectives>32 then state('waiting','objectives-unavailable');return end
        for _,o in ipairs(objectives)do
            if not A.PublicTable(o)or not A.Safe(o.numFulfilled,o.numRequired,o.finished)then state('waiting','objectives-protected');return end
            parts[#parts+1]=tostring(o.numFulfilled);parts[#parts+1]=tostring(o.numRequired);parts[#parts+1]=tostring(o.finished)
        end
        signatures[id]=P.Source(table.concat(parts,':',first,#parts))
    end
    local context=P.Source(table.concat(parts,':'))
    if B.context~=context then
        local retained={};local completed=0
        for _,id in ipairs(ids)do
            local cached=B.cache[id]
            if cached and cached.mapID==targets[id]and B.signatures[id]==signatures[id]then retained[id]=cached;completed=completed+1 end
        end
        B.context=context;B.mapID=mapID;B.ids=ids;B.maps=targets;B.cache=retained;B.signatures=signatures;B.job=nil;B.completed=completed;B.cursor=0
        if B.frame then invoke('DrawNone',B.frame.DrawNone,B.frame);B.frame:Hide()end
        C.due.questareas=0
    end
    B.mapID=mapID
    if #ids==0 then state('waiting','no-known-quest-pois');return end
    if not B.job then
        for _,id in ipairs(ids)do if not B.cache[id]then
            if not setup()then return end
            local f=B.frame;local start=nowMS();invoke('SetMapID',f.SetMapID,f,targets[id]);invoke('DrawNone',f.DrawNone,f);invoke('DrawBlob',f.DrawBlob,f,id,true);f:Show()
            if nowMS()-start>5 then B.Fail('native-setup-too-slow');return end
            B.job={id=id,mapID=targets[id],index=0,hits=0,runs=P.Array(),waitUntil=A.Clock()+.15,started=A.Clock()};state('sampling');return
        end end
        local readable=false;for _,r in pairs(B.cache)do if r.state=='ready'then readable=true end end
        state(readable and'ready'or'unavailable',not readable and'no-readable-contour'or nil)
    end
end
local function sample()
    local j=B.job;if not j or A.Clock()<j.waitUntil then return end
    local start=nowMS();local calls=0
    while j.index<B.SIZE*B.SIZE and calls<B.MAX_CALLS and nowMS()-start<B.BUDGET_MS do
        local x=j.index%B.SIZE;local y=math.floor(j.index/B.SIZE)
        local hit,count=invoke('UpdateMouseOverTooltip',B.frame.UpdateMouseOverTooltip,B.frame,(x+.5)/B.SIZE,(y+.5)/B.SIZE)
        calls=calls+1;B.calls=B.calls+1
        if hit~=nil and(not L.Int(hit,1,10000000)or hit~=j.id)then error('unexpected-native-quest')end
        if count~=nil and not L.Int(count,0,32)then error('invalid-native-objectives')end
        if hit==j.id then
            j.hits=j.hits+1;local last=j.runs[#j.runs]
            if last and last[1]==y and last[3]==x-1 then last[3]=x
            else
                if #j.runs>=B.MAX_RUNS then j.tooComplex=true;break end
                j.runs[#j.runs+1]=P.Array({y,x,x})
            end
        end
        j.index=j.index+1
    end
    local elapsed=nowMS()-start;B.maxStepMs=math.max(B.maxStepMs or 0,elapsed)
    if elapsed>3 then B.Fail('native-hit-tests-too-slow');return end
    if j.tooComplex or j.index==B.SIZE*B.SIZE then
        local valid=not j.tooComplex and j.hits>0 and j.hits<B.SIZE*B.SIZE
        B.cache[j.id]={questID=j.id,mapID=j.mapID,resolution=B.SIZE,state=valid and'ready'or'unavailable',reason=not valid and(j.tooComplex and'too-complex'or'no-verified-inside-outside')or nil,runs=valid and j.runs or P.Array(),approximate=true,observedAt=A.Now()}
        B.completed=B.completed+1;B.job=nil;B.frame:Hide();B.nextCheck=0;C.due.questareas=0
    elseif A.Clock()-j.started>60 then B.Fail('native-sampling-timeout')end
end
function B.Tick()
    if not C.running or not C.settings or not C.settings.questAreasEnabled or not C.settings.categories.questareas or B.failed then return end
    if A.Call(InCombatLockdown)~=false then
        if B.job then B.job.waitUntil=A.Clock()+.15;B.job.started=A.Clock()end
        if B.frame then B.frame:Hide()end;state('paused','combat');return
    end
    local ok,err=pcall(function()
        local start=nowMS();if not start then B.Fail('profiling-unavailable');return end
        if A.Clock()>=(B.nextCheck or 0)then B.nextCheck=A.Clock()+5;inspect()end
        if B.job then B.frame:Show();state('sampling');sample()end
        local elapsed=nowMS()-start;B.maxStepMs=math.max(B.maxStepMs or 0,elapsed)
        if elapsed>5 then B.Fail('native-step-too-slow')end
    end)
    if not ok then B.Fail(type(err)=='string'and err:match('([%w%-]+)$')or'native-api-error')end
end
function B.Read()
    local entries=P.Array();local ready={}
    for _,id in ipairs(B.ids or{})do if B.cache[id]then ready[#ready+1]=B.cache[id]end end
    if #ready>0 then B.cursor=(B.cursor or 0)%#ready+1;entries[1]=ready[B.cursor]end
    return{enabled=C.settings and C.settings.questAreasEnabled==true,state=B.state or'off',reason=B.reason,phase=B.phase,mapID=B.mapID or 0,context=B.context or'',questIDs=P.Array(B.ids),entries=entries,
        completed=B.completed or 0,total=#(B.ids or{}),calls=B.calls or 0,maxStepMs=math.floor((B.maxStepMs or 0)*1000)/1000,source='native-questpoi-raster'}
end
function C.SetQuestAreasEnabled(enabled)
    if not C.settings then return end
    C.settings.questAreasEnabled=enabled==true;C.SetCategory('questareas',enabled==true)
end
Z.CompanionTelemetry.questareas=B.Read
B.Reset()
