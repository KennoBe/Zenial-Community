local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local R={active=nil,nextLaunch=0,cache={},cacheOrder={}}
Z.RecipeSearch=R
local function professionMatches(peer,profession)
    profession=L.ProfessionName(profession)
    if not profession or profession==""or profession=="ALL_PROFESSIONS"then return true end
    if peer.presence then
        for _,id in ipairs(peer.presence.professionIDs or{})do if L.ProfessionNameByID(id)==profession then return true end end
    else for _,p in ipairs(peer.data and peer.data.professions or{})do if L.ProfessionName(p.name)==profession then return true end end end
    return false
end
local function hash(value)local n=5381;for i=1,#value do n=(n*33+value:byte(i))%2147483647 end;return n end
local function resultKey(key,query,profession,rev,session)return table.concat({key,string.lower(query),profession or"",rev or 0,session or""},"\0")end
local function cachePut(key,value)
    if not R.cache[key]then R.cacheOrder[#R.cacheOrder+1]=key end;R.cache[key]=value
    while#R.cacheOrder>2000 do R.cache[table.remove(R.cacheOrder,1)]=nil end
end
function R.Initialize()R.active=nil;R.nextLaunch=0;R.cache={};R.cacheOrder={}end
function R.RefreshOwn()
    local s=R.active;local old=s and Z.db.recipeResults[s.id]and Z.db.recipeResults[s.id][Z.me.key]
    for _,results in pairs(Z.db.recipeResults)do results[Z.me.key]=nil end
    if not s then return end
    if old and #(old.results or{})>0 then s.matches=math.max(0,s.matches-1)end
    local results=Z.SearchOwnRecipes(s.query,s.profession)
    Z.db.recipeResults[s.id]=Z.db.recipeResults[s.id]or{};Z.db.recipeResults[s.id][Z.me.key]={results=results,at=A.Now()}
    if #results>0 then s.matches=s.matches+1 end
end
function R.InvalidatePeer(key)
    local s=R.active;local hadResult=s and Z.db.recipeResults[s.id]and Z.db.recipeResults[s.id][key]
    for _,results in pairs(Z.db.recipeResults)do results[key]=nil end
    local prefix=key.."\0";local order={}
    for _,token in ipairs(R.cacheOrder)do if token:sub(1,#prefix)==prefix then R.cache[token]=nil else order[#order+1]=token end end;R.cacheOrder=order
    if not s or s.cancelled then return end
    local pending=s.inflight[key]~=nil;s.inflight[key]=nil
    for i=#s.queue,1,-1 do if s.queue[i].key==key then pending=true;table.remove(s.queue,i)end end
    if not pending and not hadResult then return end
    if hadResult and((hadResult.total or 0)>0 or #(hadResult.results or{})>0)then s.matches=math.max(0,s.matches-1)end
    local peer=Z.db.peers[key]
    if peer and Z.IsOnline(key)and professionMatches(peer,s.profession)then
        if hadResult then s.checked=math.max(0,s.checked-1)end
        s.queue[#s.queue+1]={key=key,attempts=0};s.done=false
    elseif pending then s.checked=s.checked+1 end
    if #s.queue==0 and not next(s.inflight)then s.done=true end
end
function R.Start(query,profession)
    profession=L.ProfessionName(profession)
    if not profession or profession==""then profession="ALL_PROFESSIONS"end
    if type(query)=="string"then query=query:match("^%s*(.-)%s*$")end
    if not L.Text(query,64)then return nil,"Suchbegriff eingeben."end
    -- An opaque request ID opts in to material details without changing RQ's
    -- three-field shape. Older responders echo it and still send legacy RR.
    local id=L.NextID(Z.db,A.Now())..".101";local candidates={};local cachedResults={};local checked,matches,total=0,0,0
    for key,peer in pairs(Z.db.peers)do if peer.cap30 and Z.IsOnline(key)and professionMatches(peer,profession)and Z.db.contacts[key]then
        total=total+1;local presence=peer.presence or{};local directRev=peer.recipeSearchSession==peer.session and peer.recipeSearchRev or 0;local token=resultKey(key,query,profession or"ALL_PROFESSIONS",math.max(presence.recipeRev or 0,directRev or 0),peer.session);local cached=R.cache[token]
        if cached and A.Now()-(cached.at or 0)<300 then cachedResults[key]=cached;checked=checked+1;if(cached.total or 0)>0 then matches=matches+1 end
        else candidates[#candidates+1]={key=key,score=hash(id..key),attempts=0}end
    end end
    table.sort(candidates,function(a,b)return a.score<b.score end)
    R.active={id=id,query=query,profession=profession or"ALL_PROFESSIONS",queue=candidates,inflight={},checked=checked,matches=matches,noResponse=0,busy=0,started=A.Clock(),done=#candidates==0,total=total,generation=id}
    Z.db.recipeResults[id]=cachedResults;Z.db.recipeResults[id][Z.me.key]={results=Z.SearchOwnRecipes(query,profession),at=A.Now()}
    if#Z.db.recipeResults[id][Z.me.key].results>0 then R.active.matches=R.active.matches+1 end;R.nextLaunch=0;if Z.MarkDirty then Z.MarkDirty("search")end;return id
end
function R.Block(key)
    R.InvalidatePeer(key);local s=R.active;if not s then return end
    s.inflight[key]=nil;for i=#s.queue,1,-1 do if s.queue[i].key==key then table.remove(s.queue,i)end end
    if #s.queue==0 and not next(s.inflight)then s.done=true end
end
function R.Cancel()if R.active then R.active.done=true;R.active.cancelled=true;R.active.queue={};R.active.inflight={}end end
local function queueRequest(entry)
    local s=R.active;local contact=Z.db.contacts[entry.key];if not contact then return false end
    local wire=Z.Network3.Pack({s.id,s.profession,s.query});local id=Z.Network3.QueueDirect(contact.target,"RQ",wire,25,"SEARCH:"..s.id..":"..entry.key)
    if not id then return false end;entry.at=A.Clock();entry.deadline=entry.at+20;local peer=Z.db.peers[entry.key];entry.session=peer and peer.session;entry.verifiedSession=peer and peer.verifiedSession;s.inflight[entry.key]=entry;return true
end
function R.Tick()
    local s=R.active;if not s or s.done then return end;local now=A.Clock();local before=table.concat({s.checked,#s.queue,L.Count(s.inflight),s.busy,s.noResponse,tostring(s.done)},":")
    if now-s.started>=1800 then s.done=true;s.timedOut=true;if Z.MarkDirty then Z.MarkDirty("search")end;return end
    for key,entry in pairs(s.inflight)do if now>=entry.deadline then s.inflight[key]=nil;if entry.attempts<2 then entry.attempts=entry.attempts+1;s.queue[#s.queue+1]=entry else s.checked=s.checked+1;s.noResponse=s.noResponse+1 end end end
    local open=0;for _ in pairs(s.inflight)do open=open+1 end
    if open<32 and#s.queue>0 and now>=R.nextLaunch then
        local entry=table.remove(s.queue,1)
        if entry.defer and now<entry.defer then
            s.queue[#s.queue+1]=entry;R.nextLaunch=math.min(entry.defer,now+1)
        elseif queueRequest(entry)then
            entry.defer=nil;R.nextLaunch=now+2/3
        else
            entry.attempts=entry.attempts+1
            if entry.attempts<3 then s.queue[#s.queue+1]=entry else s.checked=s.checked+1;s.noResponse=s.noResponse+1 end
            R.nextLaunch=now+1
        end
    end
    if#s.queue==0 and not next(s.inflight)then s.done=true end
    local after=table.concat({s.checked,#s.queue,L.Count(s.inflight),s.busy,s.noResponse,tostring(s.done)},":");if before~=after and Z.MarkDirty then Z.MarkDirty("search")end
end
local function receiveQuery(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f~=3 or not L.Text(f[1],32)or not L.Text(f[2],64)or not L.Text(f[3],64)then return false end
    if not Z.db.visible or not Z.db.shareProfessions then return false end
    local key=Z.ResolvePeerKey(sender);local target=key and Z.db.contacts[key]and Z.db.contacts[key].target;if not key or not target then return false end
    if#Z.Network3.jobs>220 then Z.Network3.QueueDirect(target,"RB",Z.Network3.Pack({f[1],10}),20);return true end
    local matches={};local q=string.lower(f[3]);local total=0
    for _,recipe in ipairs(Z.db.recipes or{})do local profession=L.ProfessionName(recipe.profession);local hay=string.lower((recipe.name or"").." "..(recipe.itemName or"").." "..L.ProfessionSearchText(profession));if(f[2]=="ALL_PROFESSIONS"or f[2]==""or profession==L.ProfessionName(f[2]))and hay:find(q,1,true)then total=total+1;if#matches<3 then matches[#matches+1]=recipe end end end
    local materials=L.RecipeMaterialsRequested(f[1])
    local function responseWire()
        local values={f[1],Z.db.recipeRev,total,#matches}
        for _,recipe in ipairs(matches)do values[#values+1]=recipe.id;values[#values+1]=recipe.itemID or 0;values[#values+1]=recipe.name;values[#values+1]=recipe.itemName or"";values[#values+1]=recipe.profession or"";if materials then values[#values+1]=recipe.materials or""end end
        return Z.Network3.Pack(values)
    end
    local response=responseWire();while#response>768 and#matches>0 do table.remove(matches);response=responseWire()end
    Z.Network3.QueueDirect(target,"RR",response,30);return true
end
local function receiveResult(sender,wire)
    local f=Z.Network3.Unpack(wire);if not f or#f<4 then return false end;local s=R.active;if not s or s.id~=f[1]then return false end
    local key=Z.ResolvePeerKey(sender);local entry=key and s.inflight[key];if not entry then return false end
    local rev,total,n=tonumber(f[2]),tonumber(f[3]),tonumber(f[4]);if not L.Int(rev,0,2147483646)or not L.Int(total,0,s.profession=="ALL_PROFESSIONS"and L.MAX_RECIPES or L.MAX_RECIPES_PER_PROFESSION)or not L.Int(n,0,3)or n>total then return false end
    local width=L.RecipeMaterialsRequested(s.id)and#f==4+n*6 and 6 or 5;if#f~=4+n*width then return false end
    local current=Z.db.peers[key]
    if not current or entry.verifiedSession and current.verifiedSession~=entry.verifiedSession then return false end
    -- Public recipe revisions can be delayed or forwarded by another player.
    -- Only a previous direct reply in this session can reject a direct result.
    local session=current.verifiedSession or current.session
    if current.recipeSearchSession==session and rev<(current.recipeSearchRev or 0)then return false end
    local results,seen={},{};local at=5
    for _=1,n do
        local row={id=tonumber(f[at]),itemID=tonumber(f[at+1]),name=f[at+2],itemName=f[at+3],profession=L.ProfessionName(f[at+4]),materials=width==6 and f[at+5]or""};at=at+width
        if not L.ValidRecipe(row)or seen[row.id]or s.profession~="ALL_PROFESSIONS"and row.profession~=s.profession then return false end
        seen[row.id]=true;results[#results+1]=row
    end
    current.recipeSearchSession=session;current.recipeSearchRev=rev
    s.inflight[key]=nil;s.checked=s.checked+1;if total>0 then s.matches=s.matches+1 end
    Z.db.recipeResults[s.id]=Z.db.recipeResults[s.id]or{};Z.db.recipeResults[s.id][key]={results=results,total=total,recipeRev=rev,at=A.Now()}
    local peer=Z.db.peers[key]or{};cachePut(resultKey(key,s.query,s.profession,rev,peer.session),Z.db.recipeResults[s.id][key]);if Z.MarkDirty then Z.MarkDirty("search")end;return true
end
local function receiveBusy(sender,wire)
    local f=Z.Network3.Unpack(wire);local s=R.active;if not f or#f~=2 or not s or s.id~=f[1]then return false end;local key=Z.ResolvePeerKey(sender);local entry=key and s.inflight[key];if not entry then return false end
    s.inflight[key]=nil;s.busy=s.busy+1;entry.attempts=entry.attempts+1;entry.defer=A.Clock()+math.max(5,math.min(30,tonumber(f[2])or 10));if entry.attempts<3 then s.queue[#s.queue+1]=entry else s.checked=s.checked+1;s.noResponse=s.noResponse+1 end;return true
end
function R.Receive(sender,kind,wire)if kind=="RQ"then return receiveQuery(sender,wire)elseif kind=="RR"then return receiveResult(sender,wire)elseif kind=="RB"then return receiveBusy(sender,wire)end;return false end
function R.Progress()
    local s=R.active;if not s then return nil end;local waiting=#s.queue;for _ in pairs(s.inflight)do waiting=waiting+1 end
    return{id=s.id,checked=s.checked,total=s.total,matches=s.matches,waiting=waiting,busy=s.busy,noResponse=s.noResponse,done=s.done,timedOut=s.timedOut==true}
end
return R
