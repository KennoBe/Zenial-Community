-- Local, bounded suggestions from QuestHelper; no persistence or network IO.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local Q=Z.QuestHelper
local G={MAX_CANDIDATES=40,MAX_MEMBERS=4,MAX_SUGGESTIONS=10};Z.QuestGroups=G
local function rank(m)return m.inGroup and m.availability~="AFK"and m.availability~="BUSY"and 3 or m.free and 2 or 1 end
local function better(a,b)
    if rank(a)~=rank(b)then return rank(a)>rank(b)end
    if a.common~=b.common then return a.common>b.common end
    if a.target~=b.target then return a.target<b.target end
    return a.key<b.key
end
local function ids(set)local out={};for id in pairs(set)do out[#out+1]=id end;table.sort(out);return out end
local function ready()return Z.db and Q.sampleAt and A.Now()-Q.sampleAt<=Q.TTL and Q.scanState=="ready"end
local function prepare(m)
    table.sort(m.quests);m.ids={};for _,id in ipairs(m.quests)do m.ids[id]=true end;return m
end
-- Returns at most 40 fresh overlaps, plus honest sampling/truncation metadata.
-- Missing/old-client/offline/unshared data never becomes a negative quest claim.
function G.GetCandidates()
    local out,meta={},{state=ready()and"ready"or"unknown",total=0}
    if meta.state~="ready"then return out,meta end
    Q.VisitMatches(function(m)
        meta.total=meta.total+1;prepare(m)
        -- Bounded ordered insertion: independent of pairs() iteration order.
        local index=1;while index<=#out and not better(m,out[index])do index=index+1 end
        if index<=G.MAX_CANDIDATES then table.insert(out,index,m);if #out>G.MAX_CANDIDATES then table.remove(out)end end
    end)
    meta.considered=#out;meta.truncated=meta.total>#out;return out,meta
end
local function coverage(members)
    local union,intersection={},{};local keys,names={},{};local free,grouped,unavailable=0,0,0
    for i,m in ipairs(members)do
        keys[#keys+1]=m.key;names[#names+1]=m.target
        for _,id in ipairs(m.quests)do union[id]=true;if i==1 then intersection[id]=true end end
        if i>1 then for id in pairs(intersection)do if not m.ids[id]then intersection[id]=nil end end end
        if m.inGroup then grouped=grouped+1 end
        if m.free then free=free+1 elseif not m.inGroup or m.availability=="AFK"or m.availability=="BUSY"then unavailable=unavailable+1 end
    end
    table.sort(keys);local covered,all=ids(union),ids(intersection)
    return{key=table.concat(keys,"\n"),memberKeys=keys,members=members,names=names,coverageIDs=covered,intersectionIDs=all,
        coverageCount=#covered,intersectionCount=#all,availableCount=free,groupedCount=grouped,unavailableCount=unavailable}
end
-- Revalidates up to four selected keys, including candidates outside the top 40.
-- Unknown membership invalidates the whole result, never a partial intersection.
function G.GetCoverage(memberKeys)
    if not ready()or type(memberKeys)~="table"or#memberKeys<1 or#memberKeys>G.MAX_MEMBERS then return nil,"Quest data unavailable."end
    local wanted,found={},{};for _,key in ipairs(memberKeys)do if type(key)~="string"or wanted[key]then return nil,"Quest data unavailable."end;wanted[key]=true end
    for key in pairs(wanted)do local m=Q.MatchMember(key);if m then found[key]=prepare(m)end end
    local members={};for _,key in ipairs(memberKeys)do if not found[key]then return nil,"Quest match no longer available."end;members[#members+1]=found[key]end
    table.sort(members,better);return coverage(members)
end
local function suggestionBetter(a,b)
    if a.unavailableCount~=b.unavailableCount then return a.unavailableCount<b.unavailableCount end
    if a.coverageCount~=b.coverageCount then return a.coverageCount>b.coverageCount end
    if a.intersectionCount~=b.intersectionCount then return a.intersectionCount>b.intersectionCount end
    if a.groupedCount~=b.groupedCount then return a.groupedCount>b.groupedCount end
    if #a.members~=#b.members then return #a.members>#b.members end
    return a.key<b.key
end
-- Seeded greedy cover, O(C^2 * M * Q), with C<=40, M<=4, Q<=256.
-- Prefixes retain useful small groups; identical member sets are deduplicated.
-- Cached only after a fresh QuestHelper snapshot, so privacy/expiry cannot lag.
-- Shared bounded candidate snapshot for suggestions and session-plan consumers.
-- Never caches proof of sharing/presence: retained members are checked each call.
function G.CurrentCandidates()
    local candidates,meta
    if ready()and G.pool and A.Clock()<G.nextPoolScan then
        -- New candidates wait at most five seconds. Every displayed candidate
        -- is nevertheless revalidated now, even without a dirty notification.
        candidates={};for _,old in ipairs(G.pool)do local m=Q.MatchMember(old.key);if m then candidates[#candidates+1]=prepare(m)end end
        table.sort(candidates,better);meta={state="ready",considered=#candidates,total=G.poolTotal,truncated=G.poolTotal>#candidates}
    else
        candidates,meta=G.GetCandidates();G.pool=candidates;G.poolTotal=meta.total;G.nextPoolScan=A.Clock()+5
    end
    return candidates,meta
end
function G.BuildSuggestions(options)
    options=type(options)=="table"and options or{}
    local limit=L.Int(options.maxSuggestions,1,G.MAX_SUGGESTIONS)and options.maxSuggestions or G.MAX_SUGGESTIONS
    local maxMembers=L.Int(options.maxMembers,1,G.MAX_MEMBERS)and options.maxMembers or G.MAX_MEMBERS
    local candidates,meta=G.CurrentCandidates()
    local state=A.GroupState();local slots=A.Call(IsInRaid)==true and 0 or math.max(0,5-state.total)
    local signature={tostring(Q.sampleAt),meta.state,tostring(slots),tostring(maxMembers),tostring(limit)}
    for _,m in ipairs(candidates)do signature[#signature+1]=m.key..":"..m.target..":"..m.status..":"..tostring(m.availability)..":"..tostring(m.level)..":"..m.classFile..":"..table.concat(m.quests,",")end
    signature=table.concat(signature,"\n")
    if G.cache and G.cache.signature==signature then return G.cache.suggestions,meta end
    local proposals,seen={},{}
    for _,seed in ipairs(candidates)do
        local members,selected,union={}, {}, {};local outsiders=0
        local nextMember=seed
        while nextMember and#members<maxMembers do
            if not nextMember.inGroup and outsiders>=slots then break end
            members[#members+1]=nextMember;selected[nextMember.key]=true
            if not nextMember.inGroup then outsiders=outsiders+1 end
            for _,id in ipairs(nextMember.quests)do union[id]=true end
            local copy={};for i,m in ipairs(members)do copy[i]=m end;table.sort(copy,better)
            local proposal=coverage(copy);if not seen[proposal.key]then proposals[#proposals+1]=proposal;seen[proposal.key]=true end
            local chosen,gainBest,allBest
            for _,m in ipairs(candidates)do
                if not selected[m.key]and(m.inGroup or outsiders<slots)then
                    local gain,all=0,0;for _,id in ipairs(m.quests)do if not union[id]then gain=gain+1 end end
                    for _,id in ipairs(proposal.intersectionIDs)do if m.ids[id]then all=all+1 end end
                    if gain>0 or all>0 then
                        if not chosen or rank(m)>rank(chosen)or rank(m)==rank(chosen)and(gain>gainBest or gain==gainBest and(all>allBest or all==allBest and better(m,chosen)))then chosen,gainBest,allBest=m,gain,all end
                    end
                end
            end
            nextMember=chosen
        end
    end
    table.sort(proposals,suggestionBetter);while #proposals>limit do table.remove(proposals)end
    G.cache={signature=signature,suggestions=proposals};return proposals,meta
end
-- Localized, evidence-based explanation; coverage is never a completion claim.
function G.Explain(s)
    return Z.T("%d quests covered; %d shared by everyone.",s.coverageCount,s.intersectionCount).."\n"..
        Z.T("%d available · %d in your group · %d unavailable",s.availableCount,s.groupedCount,s.unavailableCount)
end
-- Optional explicit invalidation for callers; snapshots are checked regardless.
function G.Invalidate()G.cache,G.pool=nil,nil end
return G
