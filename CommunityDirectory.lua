-- Account-wide, explicitly configured Battle.net lounge directory.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local D={MAX_GROUPS=64,SCAN_BATCH=25,MAX_CANDIDATES=5000,candidates={},groups={},available={}}
D.BOOTSTRAP_NAME="Zenial Network"
D.BOOTSTRAP_ID=200669412 -- Live lounge confirmed by the operator in the Forever client.
D.BOOTSTRAP_INVITE="https://launch.battle.net/invite/EWYKlz5SAj2"
local BETA_BOOTSTRAP_ID=23099311
local BETA_BOOTSTRAP_INVITE="https://blizzard.com/invite/GnrrkJsXow"
local OLD_BOOTSTRAP_INVITE="https://launch.battle.net/invite/9EKj2poHooq"
Z.CommunityDirectory=D
local function trace(reason,...)
    if Z.Diagnostics then Z.Diagnostics.Record("directory:"..reason,...)end
end
local function norm(value)return type(value)=="string"and value:lower():gsub("[%s%-%'_]","")or nil end
function D.World(realm)
    local key=norm(realm);if not key or key==""then return nil end
    if key:match("^classicbetapve%d*$")then return "forever-normal"end
    if key:match("^classicbetapvp%d*$")then return "forever-pvp"end
    if key:match("^classicbetarp%d*$")then return "forever-rp"end
    if key:match("^classicbetahardcore%d*$")then return "forever-hardcore"end
    return "realm:"..key -- Unknown worlds are exact-match only, never merged by guesswork.
end
function D.Project()
    if D.projectGUID==(Z.me and Z.me.guid)and A.Clock()<(D.projectUntil or 0)then return D.projectValue end
    local info=A.Call(C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID,Z.me and Z.me.guid)
    local project
    if A.PublicTable(info)and A.Safe(info.wowProjectID)and L.Int(info.wowProjectID,1,1000)then project=info.wowProjectID end
    local _,_,_,interface=A.Call(GetBuildInfo)
    if not project and interface==16001 then project=18 end
    if not project then project=A.Safe(WOW_PROJECT_ID)and L.Int(WOW_PROJECT_ID,1,1000)and WOW_PROJECT_ID or nil end
    D.projectGUID=Z.me and Z.me.guid;D.projectValue=project;D.projectUntil=A.Clock()+10;return project
end
function D.Region()
    local region=A.Call(GetCurrentRegion)
    if L.Int(region,1,10)then D.regionSource="GetCurrentRegion";return region end
    local name=A.Call(GetCurrentRegionName)
    local regions={US=1,KR=2,EU=3,TW=4,CN=5}
    if type(name)=="string"and regions[name:upper()]then D.regionSource="GetCurrentRegionName";return regions[name:upper()]end
    local info=A.Call(C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID,Z.me and Z.me.guid)
    if A.PublicTable(info)and A.Safe(info.regionID)and L.Int(info.regionID,1,10)then D.regionSource="own game account";return info.regionID end
    if D.regionCandidateSource==D.candidates and A.Clock()<(D.regionCandidateUntil or 0)then
        D.regionSource=D.regionCandidateValue and"current-region lounge account"or"unavailable";return D.regionCandidateValue
    end
    D.regionCandidateSource=D.candidates;D.regionCandidateUntil=A.Clock()+1;D.regionCandidateValue=nil
    for _,candidate in pairs(D.candidates or{})do local game=candidate.info
        if A.PublicTable(game)and A.Safe(game.isInCurrentRegion,game.regionID)and game.isInCurrentRegion==true and L.Int(game.regionID,1,10)then
            D.regionSource="current-region lounge account";D.regionCandidateValue=game.regionID;return game.regionID
        end
    end
    D.regionSource="unavailable";return nil
end
-- Zero means an unavailable numeric ID, never a guessed US/EU region. Incoming
-- traffic is still bound to native current-region BN metadata or a WoW whisper.
function D.RegionMatches(region)
    if not L.Int(region,0,10)then return false end
    local current=D.Region();return region==0 or current==nil or region==current
end
function D.OwnGameAccountID()
    local info=A.Call(C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID,Z.me and Z.me.guid)
    return A.PublicTable(info)and A.Safe(info.gameAccountID)and L.Int(info.gameAccountID,1,2147483647)and info.gameAccountID or 0
end
local function clubType()return Enum and Enum.ClubType and Enum.ClubType.BattleNet or 0 end
local function validLink(link)
    return link==""or L.Text(link,180)and(link:match("^https://blizzard%.com/invite/[%w]+$")or link:match("^https://www%.blizzard%.com/invite/[%w]+$")or link:match("^https://launch%.battle%.net/invite/[%w]+$"))~=nil
end
local function validGroup(row)
    return A.PublicTable(row)and A.Safe(row.id,row.name,row.invite)and L.Int(row.id,1,9007199254740991)
        and L.Text(row.name,96)and type(row.invite)=="string"and validLink(row.invite)
end
function D.Initialize(root)
    local raw=A.PublicTable(root.network)and root.network or{};local config={version=1,catalogVersion=1,groups={},assignment={},mode="direct"}
    config.seed=L.Int(raw.seed,1,2147483646)and raw.seed or math.random(1,2147483646)
    config.serial=L.Int(raw.serial,0,2147483646)and raw.serial or 0
    config.stores=A.PublicTable(raw.stores)and raw.stores or{}
    config.storeUsed=A.PublicTable(raw.storeUsed)and raw.storeUsed or{}
    config.catalogVersion=L.Int(raw.catalogVersion,1,2147483646)and raw.catalogVersion or 1
    local seen={};if A.PublicTable(raw.groups)then for _,row in ipairs(raw.groups)do
        if #config.groups>=D.MAX_GROUPS then break end
        if validGroup(row)and row.id~=BETA_BOOTSTRAP_ID and row.invite~=BETA_BOOTSTRAP_INVITE and row.invite~=OLD_BOOTSTRAP_INVITE and not seen[row.id]then config.groups[#config.groups+1]={id=row.id,name=row.name,invite=row.invite};seen[row.id]=true end
    end end
    if A.PublicTable(raw.assignment)then for _,id in ipairs(raw.assignment)do
        if L.Int(id,1,9007199254740991)and seen[id]and id~=config.assignment[1]and#config.assignment<2 then config.assignment[#config.assignment+1]=id end
    end end
    if #config.groups==0 and D.BOOTSTRAP_ID then
        config.groups={{id=D.BOOTSTRAP_ID,name=D.BOOTSTRAP_NAME,invite=D.BOOTSTRAP_INVITE}};config.assignment={D.BOOTSTRAP_ID}
    else
        for _,row in ipairs(config.groups)do if row.id==D.BOOTSTRAP_ID and(row.invite==OLD_BOOTSTRAP_INVITE or row.invite=="")then row.invite=D.BOOTSTRAP_INVITE end end
    end
    root.network=config;D.config=config;D.candidates,D.groups,D.available={},{},{};D.ChoosePair(false);D.RequestScan(true)
end
function D.ChoosePair(nextPair)
    local c=D.config;if not c then return end
    if not nextPair and #c.assignment==math.min(2,#c.groups)then return end
    local total=#c.groups;c.assignment={};if total==0 then return end
    if nextPair then c.seed=c.seed%2147483646+1 end
    local first=c.seed%total+1;local second=total>1 and((first-1+1+math.floor(c.seed/total)%(total-1))%total+1)or nil
    c.assignment[1]=c.groups[first].id;if second then c.assignment[2]=c.groups[second].id end
end
function D.CatalogChanged()
    D.config.catalogVersion=math.min(2147483646,D.config.catalogVersion+1)
    if Z.BattleNetTransport then Z.BattleNetTransport.Reset("configuration")end
    D.RequestScan(true);if Z.MarkDirty then Z.MarkDirty("settings")end
end
function D.ClientClubs()
    local result={};local pending=false;local clubs=A.Call(C_Club and C_Club.GetSubscribedClubs)
    D.loungesAllowed=A.Call(C_Club and C_Club.ShouldAllowClubType,clubType())
    if not A.PublicTable(clubs)then D.clientClubs={};D.clubsReady=false;return result,false end
    for _,club in ipairs(clubs)do
        if #result>=D.MAX_GROUPS then break end
        if A.PublicTable(club)and A.Safe(club.clubId)then
            local id=type(club.clubId)=="number"and club.clubId or type(club.clubId)=="string"and club.clubId:match("^%d+$")and tonumber(club.clubId)
            if L.Int(id,1,9007199254740991)then
            local info=club
            if not A.Safe(info.clubType,info.name)or not L.Int(info.clubType,0,3)or not L.Text(info.name,96)then info=A.Call(C_Club and C_Club.GetClubInfo,club.clubId)end
            if A.PublicTable(info)and A.Safe(info.clubType,info.name)and L.Int(info.clubType,0,3)and L.Text(info.name,96)then
                result[#result+1]={id=id,name=info.name,clubType=info.clubType}
            else pending=true end
            end
        end
    end
    table.sort(result,function(a,b)return a.id<b.id end);D.clientClubs=result;D.clubsReady=not pending;return result,not pending
end
function D.AvailableGroups()
    local all,ready=D.ClientClubs();local result={}
    for _,row in ipairs(all)do if row.clubType==clubType()then result[#result+1]=row end end
    return result,ready
end
function D.SetupIssue()
    if not C_Club or type(C_Club.GetSubscribedClubs)~="function"then return"The client's lounge API is unavailable."end
    if not D.clubsReady then return"Group roster loading"end
    for _,row in ipairs(D.clientClubs or{})do
        if row.name:lower()==D.BOOTSTRAP_NAME:lower()and row.clubType==1 then return"Zenial Network is a WoW character community. A Battle.net lounge is required."end
    end
    if D.loungesAllowed==false then return"This client does not allow Battle.net lounges. Copy diagnostics."end
    return"Group setup required"
end
function D.AddGroup(id,invite)
    if not D.config or not L.Int(id,1,9007199254740991)or not validLink(invite or"")then return false,"Invalid group or invite link."end
    local available=D.AvailableGroups();local match
    for _,row in ipairs(available)do if row.id==id then match=row;break end end
    if not match then return false,"Join this Battle.net group first."end
    for _,row in ipairs(D.config.groups)do if row.id==id then
        if invite and invite~=""then row.invite=invite end
        D.CatalogChanged();return true
    end end
    if #D.config.groups>=D.MAX_GROUPS then return false,"Group catalog is full."end
    D.config.groups[#D.config.groups+1]={id=id,name=match.name,invite=id==D.BOOTSTRAP_ID and(not invite or invite=="")and D.BOOTSTRAP_INVITE or invite or""};D.ChoosePair(false);D.CatalogChanged();return true
end
function D.ExportCatalog()
    local lines={"ZENIAL-GROUPS-1"};for _,row in ipairs(D.config and D.config.groups or{})do lines[#lines+1]=table.concat({string.format("%.0f",row.id),row.name,row.invite},"\t")end
    return table.concat(lines,"\n")
end
function D.ImportCatalog(text)
    if type(text)~="string"or #text>20000 then return false,"Invalid group catalog."end
    text=text:gsub("\r\n","\n");local rows,seen={},{};local header=true
    for line in(text.."\n"):gmatch("([^\n]*)\n")do
        if header then if line~="ZENIAL-GROUPS-1"then return false,"Invalid group catalog."end;header=false
        elseif line~=""then
            local id,name,invite=line:match("^(%d+)\t([^\t]+)\t([^\t]*)$");id=tonumber(id)
            if not id or not validGroup({id=id,name=name,invite=invite})or seen[id]or#rows>=D.MAX_GROUPS then return false,"Invalid group catalog."end
            rows[#rows+1]={id=id,name=name,invite=invite};seen[id]=true
        end
    end
    if #rows<1 then return false,"At least one group is required."end
    D.config.groups=rows;local pair={};for _,id in ipairs(D.config.assignment)do if seen[id]then pair[#pair+1]=id end end;D.config.assignment=pair;D.ChoosePair(false);D.CatalogChanged();return true
end
function D.Eligible(info)
    if not A.PublicTable(info)or not A.Safe(info.gameAccountID,info.clientProgram,info.isOnline,info.isAppearOffline,info.isInCurrentRegion,info.regionID,info.wowProjectID,info.factionName,info.realmName,info.characterName,info.playerGuid)then return false,"unreadable"end
    if not L.Int(info.gameAccountID,1,2147483647)or info.clientProgram~="WoW"or info.isOnline~=true or info.isAppearOffline==true then return false,"offline"end
    local region=D.Region()
    if info.isInCurrentRegion==false or region and L.Int(info.regionID,1,10)and info.regionID~=region then return false,"region"end
    if info.isInCurrentRegion~=true and not(region and info.regionID==region)then return false,"region_unverified"end
    if info.wowProjectID~=D.Project()then return false,"project"end
    if not Z.me or info.factionName~=Z.me.faction then return false,"faction"end
    if D.World(info.realmName)~=D.World(Z.me.realm)then return false,"world"end
    if not L.Text(info.characterName or"",64)then return false,"character"end
    return true
end
local function resolve(member)
    local id=member.bnetAccountId;local guid=member.guid
    if not A.Safe(id,guid)then return nil end
    if not L.Int(id,1,2147483647)and guid and A.Call(C_AccountInfo and C_AccountInfo.IsGUIDBattleNetAccountType,guid)==true then id=A.Call(C_AccountInfo and C_AccountInfo.GetIDFromBattleNetAccountGUID,guid)end
    if L.Int(id,1,2147483647)then
        local account=A.Call(C_BattleNet and C_BattleNet.GetAccountInfoByID,id)
        if A.PublicTable(account)and A.PublicTable(account.gameAccountInfo)then return account.gameAccountInfo end
    end
    if guid and A.Call(C_AccountInfo and C_AccountInfo.IsGUIDBattleNetAccountType,guid)~=true then return A.Call(C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID,guid)end
end
function D.RequestScan(reset)
    D.regionCandidateUntil=0
    -- Roster events may arrive faster than a complete large-roster scan. Finish
    -- the current snapshot, then scan once more instead of restarting forever.
    if reset then D.scan=nil;D.scanDirty=false end
    if D.scan then D.scanDirty=true else D.nextScan=0 end
end
function D.OnEvent(event)
    D.projectUntil=0
    if event=="BN_DISCONNECTED"then D.candidates={};D.scan=nil;D.scanDirty=false;D.state="Battle.net disconnected";D.nextScan=math.huge
    else D.RequestScan()end
end
local function beginScan()
    D.available,D.rosterReady=D.AvailableGroups();D.groups={};local joined={}
    -- The invite does not encode a verified club ID. Learn it only from a
    -- subscribed Battle.net club with the operator's exact lounge name.
    if #D.config.groups==0 and D.BOOTSTRAP_ID then for _,row in ipairs(D.available)do
        if row.id==D.BOOTSTRAP_ID then
            D.config.groups[1]={id=row.id,name=row.name,invite=D.BOOTSTRAP_INVITE};D.ChoosePair(false);break
        end
    end end
    for _,row in ipairs(D.available)do joined[row.id]=true end
    local scan={groups={},group=1,index=1,found={},foundCount=0,scanned=0,total=0,unresolved=0,reasons={},loading=not D.rosterReady}
    for _,id in ipairs(D.config.assignment)do
        local row={id=id,joined=joined[id]==true};D.groups[id]=row
        if row.joined then
            -- Do not steal the native Communities window's shared presence focus.
            if A.Call(InCombatLockdown)~=true and not(CommunitiesFrame and CommunitiesFrame:IsShown())then
                A.Call(C_Club and C_Club.SetClubPresenceSubscription,id);A.Call(C_Club and C_Club.FocusMembers,id)
            end
            local members=A.Call(C_Club and C_Club.GetClubMembers,id)
            if A.PublicTable(members)and #members>0 then row.members=#members;scan.total=scan.total+#members;scan.groups[#scan.groups+1]={id=id,members=members}
            else row.loading=true;scan.loading=true end
        end
    end
    D.scan=scan;D.state=scan.loading and"Group roster loading"or"Scanning group members"
end
function D.Tick()
    if not D.config or not Z.db or not Z.db.consent or not Z.db.autoDiscovery then return end
    local clock=A.Clock();if not D.scan then if clock<(D.nextScan or 0)then return end;beginScan()end
    local s=D.scan;local processed=0
    while processed<D.SCAN_BATCH do
        local group=s.groups[s.group];if not group then break end
        local memberID=group.members[s.index]
        if memberID==nil then s.group=s.group+1;s.index=1
        else
            processed=processed+1;s.scanned=s.scanned+1;s.index=s.index+1
            local member=A.Call(C_Club and C_Club.GetMemberInfo,group.id,memberID)
            if A.PublicTable(member)and A.Safe(member.isSelf,member.presence)and not member.isSelf then
                local info=resolve(member);local eligible,reason=D.Eligible(info)
                if eligible then
                    local id=info.gameAccountID;local row=s.found[id]
                    if not row and s.foundCount<D.MAX_CANDIDATES then row={id=id,info=info,groups={}};s.found[id]=row;s.foundCount=s.foundCount+1 end
                    if row then row.groups[group.id]=true end
                else
                    reason=reason or"unresolved";s.reasons[reason]=(s.reasons[reason]or 0)+1
                    if reason=="unreadable"then s.unresolved=s.unresolved+1 end
                end
            end
        end
    end
    D.progress,D.total,D.unresolved=s.scanned,s.total,s.unresolved
    if not s.groups[s.group]then
        D.scanReasons=s.reasons
        for reason,n in pairs(s.reasons)do trace("excluded_"..reason,n)end
        D.candidates=s.found;D.scan=nil;D.state=s.loading and"Group roster loading"or"Group roster ready"
        if not s.loading then
            if#D.config.assignment==0 then D.state=D.SetupIssue()
            elseif s.total==0 then D.state="Waiting for lounge membership"
            elseif s.foundCount==0 then D.state="No matching players in lounge"end
        end
        D.nextScan=clock+(D.scanDirty and .25 or s.loading and 5 or 30);D.scanDirty=false
        if Z.BattleNetTransport then Z.BattleNetTransport.Reconcile()end
    end
end
function D.Status()
    local joined=0;for _,row in pairs(D.groups)do if row.joined then joined=joined+1 end end
    return{state=D.state or"Group setup required",configured=D.config and#D.config.groups or 0,assigned=D.config and#D.config.assignment or 0,joined=joined,candidates=L.Count(D.candidates),scanned=D.progress or 0,total=D.total or 0,unresolved=D.unresolved or 0,mode=D.config and D.config.mode or"direct",project=D.Project(),region=D.Region()}
end
