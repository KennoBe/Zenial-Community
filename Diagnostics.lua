local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local D={events={},counts={},evicted=0,limited=0,MAX_EVENTS=500}
Z.Diagnostics=D
local function tr(value)return Z.T and Z.T(value)or value end
local function printable(value)
    if not A.Safe(value)then return "<unreadable>"end
    local kind=type(value)
    if kind~="string"and kind~="number"and kind~="boolean"and kind~="nil"then return "<"..kind..">"end
    return tostring(value):gsub("|","||"):gsub("[%z\1-\31\127]"," "):sub(1,240)
end
-- Bounded local session trace. No message payloads, private notes or chat text.
function D.Record(event,...)
    if not A.Safe(event)or type(event)~="string"then return end
    D.counts[event]=(D.counts[event]or 0)+1
    local now=A.Clock();local second=math.floor(now)
    if D.second~=second then D.second=second;D.inSecond=0 end
    D.inSecond=D.inSecond+1
    if D.inSecond>40 then D.limited=D.limited+1;return end
    local values={string.format("%.3f %s",now,event)}
    for i=1,math.min(select("#",...),6)do values[#values+1]=printable(select(i,...))end
    D.events[#D.events+1]=table.concat(values," ")
    if #D.events>D.MAX_EVENTS then table.remove(D.events,1);D.evicted=D.evicted+1 end
end
local function summary(out,title,values)
    out[#out+1]="\n["..title.."]"
    local names={};for name,value in pairs(values or{})do if type(name)=="string"and type(value)~="table"and type(value)~="function"then names[#names+1]=name end end
    table.sort(names);for _,name in ipairs(names)do out[#out+1]=name.."="..printable(values[name])end
end
function D.State()
    local online,legacy,reachable,reported=0,0,0,0;local routes={}
    for _,route in pairs(Z.BattleNetTransport and Z.BattleNetTransport.routes or{})do
        if A.Clock()-route.at<300 then routes[L.Identity(route.name)]=true end
    end
    for key,p in pairs(Z.db and Z.db.peers or{})do
        if Z.IsOnline(key)then
            online=online+1;local c=Z.db.contacts[key]
            if not p.cap4 or c and routes[L.Identity(c.target)]then reachable=reachable+1 else reported=reported+1 end
        end
        if p.updateRequired then legacy=legacy+1 end
    end
    local n=Z.Network3 and Z.Network3.Status()or{}
    local directory=Z.CommunityDirectory and Z.CommunityDirectory.Status()or{}
    local bnet=Z.BattleNetTransport and Z.BattleNetTransport.Status()or{}
    local label
    if(bnet.bnet or 0)>0 or(bnet.whisper or 0)>0 then label=tr("Battle.net network connected")
    elseif(directory.joined or 0)==0 then label=tr("Waiting for lounge membership")
    elseif n.throttled then label=tr("Transmission throttled")
    elseif(directory.candidates or 0)==0 then label=tr("No matching players in lounge")
    else label=tr("Connection test pending")end
    return{label=label,online=online,reachable=reachable,reported=reported,legacy=legacy,queue=n.queue or 0,queueBytes=n.bytes or 0,inbound=n.inbound or 0,assemblies=n.assemblies or 0,lastReceive=n.lastReceive or 0,lastError=n.lastError or"",search=Z.RecipeSearch and Z.RecipeSearch.Progress()or nil}
end
-- SavedVariables backups (P4-5): listed with an approximate size, deleted only on explicit request.
D.BACKUPS={"foreverLiveBackup","migrationBackup","characterBackup","realmCorrectionBackup"};D.SIZE_NODE_LIMIT=20000
local function backupOwner(name)
    local root=ZenialCommunityDB;if type(root)~="table"then return nil end
    if name=="characterBackup"then return type(root.account)=="table"and root.account or nil end
    if name=="foreverLiveBackup"or name=="migrationBackup"or name=="realmCorrectionBackup"then return root end
end
local function estimate(value)
    local bytes,nodes,seen,truncated=0,0,{},false
    local function walk(item)
        if truncated then return end
        local kind=type(item)
        if kind=="string"then bytes=bytes+#item+4 elseif kind=="number"then bytes=bytes+8 elseif kind=="boolean"then bytes=bytes+1
        elseif kind=="table"and not seen[item]then
            seen[item]=true;bytes=bytes+16
            for key,child in pairs(item)do
                nodes=nodes+1;if nodes>D.SIZE_NODE_LIMIT then truncated=true;return end
                if type(key)=="string"then bytes=bytes+#key+4 else bytes=bytes+8 end;walk(child)
            end
        end
    end
    walk(value);return bytes,truncated
end
function D.Backups()
    local rows={};local now=A.Now()
    for _,name in ipairs(D.BACKUPS)do
        local owner=backupOwner(name);local value=owner and owner[name]
        if value~=nil and not(type(value)=="table"and next(value)==nil)then
            local size,truncated=estimate(value);local at=type(value)=="table"and L.Int(value.backupAt,1,4102444800)and value.backupAt or nil
            rows[#rows+1]={name=name,size=size,truncated=truncated,at=at,age=at and math.max(0,now-at)or nil}
        end
    end
    return rows
end
function D.DeleteBackup(name)
    local known=false;for _,candidate in ipairs(D.BACKUPS)do if candidate==name then known=true end end
    local owner=known and backupOwner(name);if not owner or owner[name]==nil then return false end
    if name=="characterBackup"then owner[name]={}else owner[name]=nil end;return true
end
function D.SizeText(row)
    local size=row.size;local text=size<1024 and string.format("%d B",size)or size<1048576 and string.format("%.1f KB",size/1024)or string.format("%.1f MB",size/1048576)
    return(row.truncated and"≥ "or"~ ")..text
end
-- Public group search of the client: which parts it provides (see PublicLFG.lua).
local function publicSearch()
    local p=Z.PublicLFG;if not p then return"" end
    local c=p.Capabilities();local function yes(v)return v and"yes"or"no"end
    -- A fault inside the public part (interface or events): it was switched off or went on without that call.
    local fault=Z.UI and Z.UI.FinderPublic and Z.UI.FinderPublic.broken or Z.publicLFGFault
    return"\nPublic group search: "..yes(p.Available()).." · search: "..yes(c.search).." · results: "..yes(c.results).." · role slots: "..yes(c.counts).." · languages: "..yes(c.languages).." · own listing: "..yes(c.listing)..(fault and" · stopped after an error: "..tostring(fault):sub(1,160)or"")..(Z.lastBlockedCall and" · last call the game blocked: "..Z.lastBlockedCall or"")
end
function D.Capabilities()
    local t=C_TradeSkillUI or{};local k=C_SkillInfo or{};local v,b,_,i=A.Call(GetBuildInfo)
    local function has(fn)return type(fn)=="function"and"yes"or"no"end
    return "Client: "..tostring(v or"?").." / "..tostring(b or"?").." / "..tostring(i or"?").."\nSkill indices: "..has(k.GetSkillLineInfo).." · full recipes: "..has(t.GetAllRecipeIDs).." · filtered recipes: "..has(t.GetFilteredRecipeIDs).." · own/linked check: "..has(t.IsTradeSkillLinked)..publicSearch()
end
function D.LocalLine()
    local LN=Z.LocalNetwork;if not LN then return tr("Local network")..": -"end
    local direct,indirect=LN.Counts();local st=LN.Status()
    return tr("Local network")..": "..(direct or 0).." "..tr("direct").." · "..(indirect or 0).." "..tr("indirect").." · "..tr("gateway")..": "..((st.gateway or"")~=""and st.gateway or"-")
end
function D.Lines()
    local s=D.State();local lines={s.label,tr("Mode: direct network without channel"),tr("Confirmed reachable")..": "..s.reachable.." · "..tr("Reported in network")..": "..s.reported,D.LocalLine(),tr("Queue")..": "..s.queue.." / "..s.queueBytes.." Bytes · "..tr("Inbound")..": "..s.inbound.." · "..tr("fragments")..": "..s.assemblies}
    if s.lastReceive>0 then lines[#lines+1]=tr("Last received")..": "..date("%d.%m.%Y %H:%M:%S",s.lastReceive)end
    if s.lastError~=""then lines[#lines+1]=tr("Last error")..": "..s.lastError end
    if s.search then lines[#lines+1]=tr("Recipe search")..": "..s.search.checked.."/"..s.search.total.." "..tr("checked")..", "..s.search.matches.." "..tr("matches")end
    if Z.CommunityDirectory and Z.CommunityDirectory.config then
        local directory,bnet=Z.CommunityDirectory.Status(),Z.BattleNetTransport.Status()
        lines[#lines+1]=Z.T("Assigned lounges: %d/%d joined",directory.joined,math.max(1,directory.assigned)).." · "..directory.candidates.." "..tr("members")
        lines[#lines+1]=Z.T("Confirmed: Battle.net %d · addon whisper %d · pending %d",bnet.bnet,bnet.whisper,bnet.pending)
    end
    lines[#lines+1]=D.Capabilities();return lines
end
-- World probe (/zenial welt): which values the client still gives that tell the world (PvE, PvP, Hardcore, RP)
-- after realm names and IDs went blank. Own character only; other players appear as counts and realm parts, never names.
function D.WorldProbe()
    local out={}
    local function add(...)local parts={};for i=1,select("#",...)do parts[#parts+1]=printable((select(i,...)))end;out[#out+1]=table.concat(parts," | ")end
    local function call(name,fn,...)
        if type(fn)~="function"then add(name,"<missing>");return end
        local results={pcall(fn,...)}
        if not results[1]then add(name,"<error>",results[2]);return end
        local shown={};for i=2,math.max(2,#results)do shown[#shown+1]=printable(results[i])end
        add(name,table.concat(shown," , "))
    end
    local function fields(name,t,keys)
        if type(t)~="table"then add(name,"<"..type(t)..">");return end
        for _,key in ipairs(keys)do local ok,value=pcall(function()return t[key]end);add(name.."."..key,ok and value or"<error>")end
    end
    out[#out+1]="ZENIAL world probe "..printable(date and date("!%Y-%m-%d %H:%M UTC")or"")
    call("GetBuildInfo",GetBuildInfo)
    call("GetRealmName",GetRealmName);call("GetNormalizedRealmName",GetNormalizedRealmName);call("GetRealmID",GetRealmID)
    call("GetCurrentRegion",GetCurrentRegion);call("GetCurrentRegionName",GetCurrentRegionName)
    call("UnitFullName(player)",UnitFullName,"player");call("GetUnitName(player,true)",GetUnitName,"player",true)
    local ok,guid=pcall(UnitGUID,"player")
    add("UnitGUID(player)",ok and guid or"<error>")
    if ok and type(guid)=="string"then
        local kind,server=guid:match("^(%a+)%-(%d+)%-")
        add("player GUID realm part",kind,server)
        call("GetPlayerInfoByGUID(player)",GetPlayerInfoByGUID,guid)
        local bn=C_BattleNet
        local info=bn and type(bn.GetGameAccountInfoByGUID)=="function"and select(2,pcall(bn.GetGameAccountInfoByGUID,guid))or nil
        fields("BN game account",info,{"realmName","realmID","realmDisplayName","wowProjectID","regionID","isInCurrentRegion","factionName","clientProgram","isOnline","isAppearOffline","isWowMobile"})
        local account=bn and type(bn.GetAccountInfoByGUID)=="function"and select(2,pcall(bn.GetAccountInfoByGUID,guid))or nil
        fields("BN account.gameAccountInfo",type(account)=="table"and account.gameAccountInfo or account,{"realmName","realmID","realmDisplayName","wowProjectID"})
    end
    call("BNConnected",BNConnected)
    local rules=C_GameRules
    if type(rules)=="table"then
        call("C_GameRules.IsHardcoreActive",rules.IsHardcoreActive);call("C_GameRules.GetActiveGameMode",rules.GetActiveGameMode)
        call("C_GameRules.IsSelfFoundAllowed",rules.IsSelfFoundAllowed)
    else add("C_GameRules","<missing>")end
    if type(C_Seasons)=="table"then call("C_Seasons.HasActiveSeason",C_Seasons.HasActiveSeason);call("C_Seasons.GetActiveSeason",C_Seasons.GetActiveSeason)end
    -- Realm parts of other characters, without their names.
    local suffixes,members={},0
    local n=type(GetNumGuildMembers)=="function"and select(2,pcall(GetNumGuildMembers))or 0
    for i=1,math.min(tonumber(n)or 0,50)do
        local okName,name=pcall(GetGuildRosterInfo,i)
        if okName and type(name)=="string"then members=members+1;local realm=name:match("%-(.+)$");suffixes[realm or"<none>"]=(suffixes[realm or"<none>"]or 0)+1 end
    end
    local list={};for realm,count in pairs(suffixes)do list[#list+1]=realm.."="..count end;table.sort(list)
    add("guild roster realm suffixes ("..members.." read)",table.concat(list,", "))
    local bn=C_BattleNet;local withRealm,withoutRealm=0,0
    if bn and type(bn.GetFriendNumGameAccounts)=="function"and type(BNGetNumFriends)=="function"then
        local okCount,total=pcall(BNGetNumFriends)
        for f=1,math.min(okCount and tonumber(total)or 0,50)do
            local okGames,games=pcall(bn.GetFriendNumGameAccounts,f)
            for g=1,math.min(okGames and tonumber(games)or 0,5)do
                local okInfo,info=pcall(bn.GetFriendGameAccountInfo,f,g)
                if okInfo and type(info)=="table"and info.clientProgram=="WoW"then if type(info.realmName)=="string"and info.realmName~=""then withRealm=withRealm+1 else withoutRealm=withoutRealm+1 end end
            end
        end
    end
    add("BN friends in WoW with realm / without",withRealm,withoutRealm)
    -- Every client function whose name points to realm, server, world rules or game mode.
    local found={}
    local function scan(prefix,t)
        for key,value in pairs(t)do
            if type(key)=="string"and type(value)=="function"and(key:find("Realm")or key:find("Server")or key:find("Hardcore")or key:find("GameMode")or key:find("RuleSet")or key:find("Shard"))then found[#found+1]=prefix..key end
        end
    end
    scan("",_G)
    for key,value in pairs(_G)do if type(key)=="string"and key:match("^C_")and type(value)=="table"then scan(key..".",value)end end
    table.sort(found)
    -- Names only: calling unknown client functions can hit one reserved for the Blizzard UI.
    add("functions ("..#found..")",table.concat(found,", "))
    if type(GetNativeRealmID)=="function"then call("GetNativeRealmID",GetNativeRealmID)end
    if type(IsOnTournamentRealm)=="function"then call("IsOnTournamentRealm",IsOnTournamentRealm)end
    if type(GetServerExpansionLevel)=="function"then call("GetServerExpansionLevel",GetServerExpansionLevel)end
    if type(rules)=="table"then
        call("C_GameRules.GetCurrentGameModeRecordID",rules.GetCurrentGameModeRecordID)
        local okInfo,info=pcall(function()return rules.GetCurrentGameModeDisplayInfo and rules.GetCurrentGameModeDisplayInfo()end)
        if okInfo and type(info)=="table"then for key,value in pairs(info)do add("C_GameRules.GetCurrentGameModeDisplayInfo."..tostring(key),value)end end
    end
    for _,source in ipairs({{"GetAutoCompleteRealms",GetAutoCompleteRealms},{"C_AutoComplete.GetAutoCompleteRealms",C_AutoComplete and C_AutoComplete.GetAutoCompleteRealms}})do
        local okList,list=pcall(function()return type(source[2])=="function"and source[2]()or nil end)
        if okList and type(list)=="table"then local values={};for _,value in pairs(list)do values[#values+1]=printable(value)end;add(source[1].." ("..#values..")",table.concat(values,", "))end
    end
    -- Lounge members playing WoW: realm number of their character GUID and whether the client calls their game account
    -- "same realm". Numbers and counts only, no names.
    local stats,order,checked={},{},0
    local bn=C_BattleNet;local club=C_Club
    local sameRealm=bn and bn.IsGameAccountOnSameRealm
    if type(club)=="table"and type(club.GetSubscribedClubs)=="function"and bn and type(bn.GetAccountInfoByID)=="function"then
        local okClubs,clubs=pcall(club.GetSubscribedClubs)
        for _,entry in ipairs(okClubs and type(clubs)=="table"and clubs or{})do
            local okType,clubType=pcall(function()return entry.clubType end)
            local okId,clubId=pcall(function()return entry.clubId end)
            if okType and clubType==nil and okId and type(club.GetClubInfo)=="function"then
                local okClub,clubInfo=pcall(club.GetClubInfo,clubId);if okClub and type(clubInfo)=="table"then clubType=clubInfo.clubType end
            end
            if okType and okId and clubType==(Enum and Enum.ClubType and Enum.ClubType.BattleNet or 0)then
                local okMembers,members=pcall(club.GetClubMembers,clubId)
                for _,member in ipairs(okMembers and type(members)=="table"and members or{})do
                    if checked>=200 then break end
                    local okMember,memberInfo=pcall(club.GetMemberInfo,clubId,member)
                    local okAccount,accountID=pcall(function()return memberInfo.bnetAccountId end)
                    local okInfo,account=false,nil
                    if okMember and okAccount and type(accountID)=="number"then okInfo,account=pcall(bn.GetAccountInfoByID,accountID)end
                    local okGame,rawGame=false,nil
                    if okInfo and type(account)=="table"then okGame,rawGame=pcall(function()return account.gameAccountInfo end)end
                    local game=okGame and A.GameAccount(rawGame)
                    if game and game.clientProgram=="WoW"and game.isOnline==true and type(game.playerGuid)=="string"then
                        checked=checked+1
                        local number=game.playerGuid:match("^Player%-(%d+)%-")or"?"
                        local okSame,same=false,nil
                        if type(sameRealm)=="function"and type(game.gameAccountID)=="number"then okSame,same=pcall(sameRealm,game.gameAccountID)end
                        local row=stats[number]
                        if not row then row={yes=0,no=0,unknown=0,project=game.wowProjectID};stats[number]=row;order[#order+1]=number end
                        if okSame and same==true then row.yes=row.yes+1 elseif okSame and same==false then row.no=row.no+1 else row.unknown=row.unknown+1 end
                    end
                end
            end
        end
    end
    table.sort(order)
    add("lounge members in WoW checked",checked,"IsGameAccountOnSameRealm",type(sameRealm)=="function"and"present"or"missing")
    for _,number in ipairs(order)do local row=stats[number];add("  realm number "..number,"same realm yes "..row.yes,"no "..row.no,"unknown "..row.unknown,"project "..tostring(row.project))end
    add("Community realm",Z.me and Z.me.realm,"world",Z.CommunityDirectory and Z.me and Z.CommunityDirectory.World(Z.me.realm))
    add("advertised world",Z.CommunityDirectory and Z.me and Z.CommunityDirectory.WorldToken(),Z.CommunityDirectory and Z.me and Z.CommunityDirectory.OwnWorld())
    local text=table.concat(out,"\n")
    -- Kept in the saved variables as well, so the report can be read from the WTF folder after a /reload.
    if type(ZenialCommunityDB)=="table"then ZenialCommunityDB.worldProbe=text end
    return text
end
function D.Export()
    local out={"ZENIAL Community diagnostic report", "addon="..printable(Z.ADDON_VERSION).." time="..A.Now(),
        "Session counters and recent local trace reset on /reload. API success does not confirm peer delivery.",
        "The old community chat channel is disabled. Only a reciprocal handshake confirms direct reachability.",
        "Peer realm metadata is ignored for member discovery. Local world scope separates saved main/alt profiles.",table.concat(D.Lines(),"\n"),"\n[Network]",table.concat(A.NetworkStatus(),"\n")}
    summary(out,"Identity",{target=Z.me and Z.me.target,realm=Z.me and Z.me.realm,faction=Z.me and Z.me.faction,identityReady=Z.identityReady,session=Z.session,offlineOnly=Z.offlineOnly})
    local unitName,unitSecond,unitThird=A.Call(UnitFullName,"player")
    summary(out,"Identity API",{unitFullName=unitName,unitFullNameSecond=unitSecond,unitFullNameThird=unitThird,getRealmName=A.Call(GetRealmName),getUnitName=A.Call(GetUnitName,"player",true),correctedSurnameRealm=Z.me and Z.me.surnameRealm})
    local backups={};for _,row in ipairs(D.Backups())do backups[row.name]=D.SizeText(row)end;summary(out,"Backups (SavedVariables)",backups)
    local db=Z.db or{}
    summary(out,"Preferences",{consent=db.consent,autoDiscovery=db.autoDiscovery,visible=db.visible,shareProfessions=db.shareProfessions,shareGuild=db.shareGuild,shareQuests=db.shareQuests})
    if Z.QuestHelper then summary(out,"Quest helper scan",Z.QuestHelper.Status())end
    summary(out,"Adapter counters (lastCode is historical)",A.network)
    summary(out,"Protocol 3 counters",Z.Network3 and Z.Network3.stats)
    if Z.CommunityDirectory then
        summary(out,"Battle.net directory",Z.CommunityDirectory.Status())
        summary(out,"Directory exclusion reasons",Z.CommunityDirectory.scanReasons)
        summary(out,"Battle.net APIs",{clubs=type(C_Club and C_Club.GetSubscribedClubs)=="function",members=type(C_Club and C_Club.GetMemberInfo)=="function",send=type(C_BattleNet and C_BattleNet.SendGameData)=="function",accounts=type(C_BattleNet and C_BattleNet.GetAccountInfoByID)=="function",receiveEvent=Z.bnetReceiveEvent,region=Z.CommunityDirectory.Region(),project=Z.CommunityDirectory.Project()})
        out[#out+1]="\n[Client clubs: BattleNet=0, Character=1, Guild=2, Other=3]"
        for _,row in ipairs(Z.CommunityDirectory.ClientClubs())do out[#out+1]=string.format("%.0f",row.id).." type="..row.clubType.." "..printable(row.name)end
        summary(out,"Lounge setup",{numericRegion=Z.CommunityDirectory.Region()or 0,regionPolicy="native-current-region",regionSource=Z.CommunityDirectory.regionSource,regionName=A.Call(GetCurrentRegionName),loungeTypeAllowed=Z.CommunityDirectory.loungesAllowed,clubsReady=Z.CommunityDirectory.clubsReady,expectedLounge=Z.CommunityDirectory.BOOTSTRAP_ID})
    end
    if Z.CommunityDirectory then
        local proof={currentRegion=0,otherRegion=0,unknownRegion=0,numericRegion=0,guid=0,fullName=0}
        for _,candidate in pairs(Z.CommunityDirectory.candidates or{})do local game=candidate.info
            if A.PublicTable(game)and A.Safe(game.isInCurrentRegion,game.regionID,game.playerGuid,game.characterName)then
                local field=game.isInCurrentRegion==true and"currentRegion"or game.isInCurrentRegion==false and"otherRegion"or"unknownRegion";proof[field]=proof[field]+1
                if L.Int(game.regionID,1,10)then proof.numericRegion=proof.numericRegion+1 end
                if L.Text(game.playerGuid or"",80)then proof.guid=proof.guid+1 end
                if type(game.characterName)=="string"and game.characterName:find(" ",1,true)then proof.fullName=proof.fullName+1 end
            end
        end
        summary(out,"Lounge game-account proofs",proof)
    end
    if Z.BattleNetTransport then summary(out,"Verified direct connections",Z.BattleNetTransport.Status());summary(out,"Battle.net transport counters",Z.BattleNetTransport.stats)end
    if Z.BattleNetTransport then
        out[#out+1]="\n[Battle.net route metadata]"
        for _,row in ipairs(Z.BattleNetTransport.RouteDiagnostics())do
            out[#out+1]="address="..row.address.." nativeRealm="..printable(row.nativeRealm).." characterRealm="..printable(row.characterRealm).." world="..printable(row.world).." proof="..printable(row.proof).." state="..printable(row.state)
        end
    end
    if Z.LocalNetwork then summary(out,"Local network",Z.LocalNetwork.Status())end
    if Z.CommunityMesh then summary(out,"Public mesh",Z.CommunityMesh.Status());summary(out,"Public mesh counters",Z.CommunityMesh.stats)end
    if Z.CommunityMap then summary(out,"Community map",Z.CommunityMap.Status())end
    summary(out,"Receive and processing reasons",D.counts)
    if Z.ProfessionScan then summary(out,"Profession scan",Z.ProfessionScan.Status());summary(out,"Profession scan runtime",Z.ProfessionScan)end
    if Z.RecipeSearch then summary(out,"Recipe search",Z.RecipeSearch.Progress())end
    if Z.engine then summary(out,"Legacy engine",{status=Z.engine.status,blocked=Z.engine.blocked,queued=L.Count(Z.engine.out),pending=L.Count(Z.engine.pending),parts=L.Count(Z.engine.parts)})end
    local u=Z.UI or{};local filters={}
    for _,name in ipairs({"memberSearch","memberStatus","memberClass","memberProfession","memberFavoriteFilter","memberSort"})do local control=u[name];filters[name]=control and control:GetText()or "<UI not opened>"end
    filters.visibleCount=u.memberCount and u.memberCount:GetText()or "<UI not opened>"
    summary(out,"Members filters",filters)
    out[#out+1]="\n[Known peers]"
    local keys={};for key in pairs(db.peers or{})do keys[#keys+1]=key end;table.sort(keys)
    out[#out+1]="total="..#keys
    for i=1,math.min(#keys,100)do local key=keys[i];local p=db.peers[key];local c=db.contacts and db.contacts[key]
        out[#out+1]=table.concat({printable(c and c.target or key),"online="..tostring(Z.IsOnline(key)),"cap30="..printable(p.cap30),"presence="..tostring(p.presence~=nil),"profile="..tostring(p.data~=nil),"blocked="..tostring(db.blocked and db.blocked[key]==true),"lastContact="..printable(p.lastContact),"state="..printable(Z.Locale.PeerState(p.state)),"source="..printable(Z.LocalNetwork and Z.LocalNetwork.Source(key)or""),"advertisedRealm="..printable(p.advertisedRealm)}," ")
    end
    if #keys>100 then out[#out+1]="Peer list limited to 100 entries."end
    for _,name in ipairs({"lfg","quest","market","craftOrders","craftOrderOps","recipeStates","recipeCatalogs","sentApplications","interests","questInterests","sentQuestApplications"})do out[#out+1]=name.." entries="..L.Count(type(db[name])=="table"and db[name]or{})end
    if Z.PvPHelp then summary(out,"PvP runtime",Z.PvPHelp)end
    if Z.CraftOrders then summary(out,"Craft orders runtime",Z.CraftOrders)end
    out[#out+1]="\n[Recent session trace] stored="..#D.events.." evicted="..D.evicted.." rateLimited="..D.limited
    for _,line in ipairs(D.events)do out[#out+1]=line end
    out[#out+1]="\n[ZenialDevLogger]"
    local logger=ZenialDevLogger
    if logger and logger.db and type(logger.Export)=="function"then
        local ok,report=pcall(logger.Export)
        out[#out+1]=ok and A.Safe(report)and type(report)=="string"and report or "Logger export unavailable."
    else out[#out+1]="Not loaded; no DevLogger capture available."end
    return table.concat(out,"\n")
end
return D
