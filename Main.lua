local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local H=Z.History
local uiDirty=false

-- Kinds that never touch peers, contacts, own profile, location, layers or
-- links, i.e. nothing the member list model reads. Their changes still refresh
-- the visible page at once and invalidate every other view cache; only the
-- member list model is reused. Unknown or missing kinds invalidate everything.
local MEMBER_INDEPENDENT={guild=true,order=true,history=true,materials=true,materialOffers=true,search=true,questHelper=true,scheduled=true,party=true}
function Z.MarkDirty(kind)
    Z.viewRevision=(Z.viewRevision or 0)+1
    if not MEMBER_INDEPENDENT[kind]then Z.memberRevision=(Z.memberRevision or 0)+1 end
    uiDirty=true
end
function Z.Publish()
    if Z.engine then Z.engine:Publish()end
    if Z.Network3 then Z.Network3.Publish()end
end

local function account()
    ZenialCommunityDB.account=type(ZenialCommunityDB.account)=="table" and ZenialCommunityDB.account or {characters={},main="",linkVersion=1}
    local a=ZenialCommunityDB.account
    a.characters=type(a.characters)=="table" and a.characters or {};a.main=L.Text(a.main,113,true)and a.main or"";a.mainKey=L.Text(a.mainKey,260,true)and a.mainKey or"";a.linkVersion=L.Int(a.linkVersion,1,2147483646)and a.linkVersion or 1
    return a
end
local function accountCharacterKey(me)return L.ScopeKey(me.target,me.realm,me.faction)or me.key end
Z.AccountCharacterKey=accountCharacterKey
local function normalizeAccount(a,me,legacyKey)
    local normalized,redirect={},{}
    a.characterBackup=type(a.characterBackup)=="table"and a.characterBackup or{}
    a.characterAliases=type(a.characterAliases)=="table"and a.characterAliases or{}
    for key,c in pairs(a.characters)do
        if type(c)=="table"then
            c.lastLogin=L.Int(c.lastLogin,0,4102444800)and c.lastLogin or 0
            c.level=L.Int(c.level,0,100)and c.level or 0
            c.class=L.Text(c.class,24,true)and c.class or ""
            c.realm=L.Text(c.realm,64,true)and c.realm or nil
            c.faction=(c.faction=="Alliance"or c.faction=="Horde"or c.faction=="Neutral")and c.faction or nil
            local canonical=c.realm and c.faction and L.ScopeKey(c.target,c.realm,c.faction)
            if not canonical and(key==me.legacyKey or key==legacyKey)then canonical=accountCharacterKey(me)end
            if canonical then
                local old=normalized[canonical]
                if not old or(c.lastLogin or 0)>(old.lastLogin or 0)then normalized[canonical]=c end
                redirect[key]=canonical
                if key~=canonical then a.characterAliases[key]=canonical end
                if key~=canonical then a.characterBackup[key]=c end
            else if L.Text(key,180)and L.Identity(c.target,c.realm)then normalized[key]=c end end
        end
    end
    a.characters=normalized
    a.mainKey=redirect[a.mainKey]or a.mainKey
    a.mains=type(a.mains)=="table"and a.mains or{}
    local function scope(c)return string.lower((c.realm or""):gsub("%s+","")).."@"..string.lower(c.faction or"")end
    local previous=a.characters[a.mainKey]
    if not previous then
        for key,c in pairs(a.characters)do
            if c.target==a.main and c.realm==me.realm and c.faction==me.faction then a.mainKey=key;previous=c;break end
        end
    end
    if previous and previous.realm and previous.faction then a.mains[scope(previous)]=a.mainKey end
    local ownKey=accountCharacterKey(me)
    a.characters[ownKey]={target=me.target,realm=me.realm,faction=me.faction,class=me.class,level=me.level,lastLogin=A.Now(),shareLink=true}
    for _,c in pairs(a.characters)do c.shareLink=true end
    local selected=a.mains[scope(me)];selected=redirect[selected]or selected
    local function sameScope(c)return c and c.realm==me.realm and c.faction==me.faction end
    if not sameScope(a.characters[selected])then
        selected=nil
        for key,c in pairs(a.characters)do
            if sameScope(c)and(not selected or(c.lastLogin or 0)<(a.characters[selected].lastLogin or 0)or(c.lastLogin or 0)==(a.characters[selected].lastLogin or 0)and key<selected)then selected=key end
        end
    end
    a.mainKey=selected or ownKey;a.main=a.characters[a.mainKey].target;a.mains[scope(me)]=a.mainKey
    a.linkVersion=math.min(a.linkVersion+1,2147483646)
end
local function migrateLegacyCharacter(root,me,a)
    if root.characters[me.key] then return nil end
    local given=me.target:match("^([^ ]+) ");if not given then return nil end
    local prefix=string.lower(given).."-";local best
    for key,row in pairs(a.characters)do
        if type(key)=="string"and key:sub(1,#prefix)==prefix and root.characters[key]then
            if type(row)=="table"and row.realm==me.realm and row.faction==me.faction then
                if best then return nil end
                best=key
            end
        end
    end
    if not best then return nil end
    root.characters[me.key]=root.characters[best]
    if type(root.ui)=="table"and type(root.ui.characters)=="table"and not root.ui.characters[me.key]then root.ui.characters[me.key]=root.ui.characters[best]end
    if type(root.pvpHelp)=="table"and not root.pvpHelp[me.key]then root.pvpHelp[me.key]=root.pvpHelp[best]end
    return best
end
function Z.PublicLinks()
    local a=Z.account;local ownKey=Z.accountCharacterKey or accountCharacterKey(Z.me);local own=a.characters[ownKey]
    local function sameScope(c)return c and c.realm==Z.me.realm and c.faction==Z.me.faction end
    if not own or not sameScope(own)or a.main=="" then return {main="",version=a.linkVersion,alts={}} end
    local mainKey=a.mainKey;local main=a.characters[mainKey]
    if not sameScope(main)then for key,c in pairs(a.characters)do if sameScope(c)and c.target==a.main then mainKey,main=key,c;break end end end
    if not main or not sameScope(main)then return {main="",version=a.linkVersion,alts={}} end
    if ownKey==mainKey then
        local alts={}; for key,c in pairs(a.characters) do if key~=mainKey and sameScope(c)then alts[#alts+1]=c.target end end; table.sort(alts); while #alts>10 do table.remove(alts) end
        return {main=main.target,version=a.linkVersion,alts=alts}
    end
    return {main=main.target,version=a.linkVersion,alts={}}
end
function Z.SetMain(key)
    local c=Z.account.characters[key]; if not c or c.realm~=Z.me.realm or c.faction~=Z.me.faction then return false end
    Z.account.main,Z.account.mainKey=c.target,key;Z.account.mains[string.lower(Z.me.realm:gsub("%s+","")).."@"..string.lower(Z.me.faction)]=key;Z.account.linkVersion=math.min(Z.account.linkVersion+1,2147483646);L.Touch(Z.db);Z.Publish();return true
end
function Z.RemoveCharacter(key)
    local a=Z.account;local c=a.characters[key]
    if key==Z.accountCharacterKey then return nil,"The logged-in character cannot be removed."end
    if not c or c.realm~=Z.me.realm or c.faction~=Z.me.faction then return nil,"Select a character on your server and faction."end
    local aliases={[key]=true};local base=L.Identity(c.target);local ambiguous=false
    for other,row in pairs(a.characters)do
        if other~=key and L.Identity(row.target)==base and(row.realm~=c.realm or row.faction~=c.faction)then ambiguous=true end
        if L.ScopeKey(row.target,row.realm,row.faction)==key then aliases[other]=true end
    end
    if base then
        aliases[base.."@"..string.lower(c.realm).."@"..string.lower(c.faction)]=true
        if not ambiguous then aliases[base]=true end
    end
    if Z.AccountOverview and Z.AccountOverview.ForgetImported then Z.AccountOverview.ForgetImported(c.target,c.realm,c.faction)end
    local expanded=true;while expanded do expanded=false;for alias,canonical in pairs(a.characterAliases or{})do if aliases[canonical]and not aliases[alias]then aliases[alias]=true;expanded=true end end end
    for alias,row in pairs(a.characterBackup or{})do if type(row)=="table"and L.ScopeKey(row.target,row.realm,row.faction)==key then aliases[alias]=true end end
    for alias in pairs(aliases)do
        a.characters[alias]=nil;a.characterBackup[alias]=nil;a.characterAliases[alias]=nil
        ZenialCommunityDB.characters[alias]=nil
        if ZenialCommunityDB.migrationBackup then ZenialCommunityDB.migrationBackup[alias]=nil end
        if ZenialCommunityDB.ui and ZenialCommunityDB.ui.characters then ZenialCommunityDB.ui.characters[alias]=nil end
        if ZenialCommunityDB.pvpHelp then ZenialCommunityDB.pvpHelp[alias]=nil end
        Z.db.contacts[alias]=nil;Z.db.peers[alias]=nil;Z.db.recipeCatalogs[alias]=nil
        if Z.Social and Z.Social.store then Z.Social.store.favorites[alias]=nil;Z.Social.store.notes[alias]=nil;if Z.SocialCategories then Z.SocialCategories.Forget(alias)end;if Z.SocialDiary then Z.SocialDiary.Forget(alias)end end
        if Z.UI and Z.UI.noteDrafts then Z.UI.noteDrafts[alias]=nil end
        if Z.AccountOverview then Z.AccountOverview.Forget(alias)end
        for _,results in pairs(Z.db.recipeResults)do results[alias]=nil end
    end
    -- Other own profiles may still contain pre-shared-social migration copies.
    -- Purge those references too so the next login cannot import them again.
    for _,profile in pairs(ZenialCommunityDB.characters)do if type(profile)=="table"then
        for _,field in ipairs({"favorites","privateNotes"})do if type(profile[field])=="table"then for alias in pairs(aliases)do profile[field][alias]=nil end end end
    end end
    if base and Z.Social and Z.Social.store then Z.Social.store.favorites[base]=nil;Z.Social.store.notes[base]=nil end
    for scope,main in pairs(a.mains)do if aliases[main]then a.mains[scope]=Z.accountCharacterKey end end
    if aliases[a.mainKey]then a.mainKey=Z.accountCharacterKey;a.main=Z.me.target end
    a.linkVersion=math.min(a.linkVersion+1,2147483646);L.Touch(Z.db);Z.Publish();Z.MarkDirty("character")
    return true
end
function Z.ConfirmedMain(key)
    local p=Z.db.peers[key]; local s=p and p.data; if not s or s.kind~="S3" or not p.received or A.Now()-p.received>604800 then return nil end
    -- A character reports its own main; the main need not be online or cached.
    if s.faction==Z.me.faction and L.Identity(s.linkMain)then return s.linkMain end
    return nil
end
function Z.SearchOwnRecipes(query,profession)
    profession=L.ProfessionName(profession)
    query=string.lower(query or ""); local out={}; if query=="" then return out end
    for _,r in ipairs(Z.db.recipes) do
        local hay=string.lower((r.name or "").." "..(r.itemName or "").." "..L.ProfessionSearchText(r.profession))
        if (not profession or profession=="ALL_PROFESSIONS"or L.ProfessionName(r.profession)==profession)and hay:find(query,1,true) then out[#out+1]=r; if #out>=8 then break end end
    end
    return out
end
function Z.RecipeCatalogPage(profession,offset)
    profession=L.ProfessionName(profession);offset=tonumber(offset)or 0;local all={}
    if not Z.db.visible or not Z.db.shareProfessions or not L.Text(profession,64)or not L.Int(offset,0,L.MAX_RECIPES_PER_PROFESSION)then return {},0 end
    for _,r in ipairs(Z.db.recipes or{})do if L.ProfessionName(r.profession or"")==profession then all[#all+1]=r end end
    table.sort(all,function(a,b)return a.name<b.name end);local page={}
    for i=offset+1,math.min(#all,offset+16)do page[#page+1]=all[i]end
    return page,#all
end
local function pruneRecipeCatalogs(protectKey,protectProfession)
    local all={};for key,byProfession in pairs(Z.db.recipeCatalogs or{})do for profession,catalog in pairs(byProfession)do all[#all+1]={key=key,profession=profession,catalog=catalog,at=catalog.at or 0,count=#(catalog.results or{})}end end
    table.sort(all,function(a,b)return a.at>b.at end);local recipes=0;for index,row in ipairs(all)do recipes=recipes+row.count;local protected=row.key==protectKey and row.profession==protectProfession;if not protected and(index>50 or recipes>30000)then Z.db.recipeCatalogs[row.key][row.profession]=nil;recipes=recipes-row.count;if not next(Z.db.recipeCatalogs[row.key])then Z.db.recipeCatalogs[row.key]=nil end end end
end
function Z.RequestRecipeCatalog(key,profession)
    profession=L.ProfessionName(profession);if key==Z.me.key or not Z.db.contacts[key]or not L.Text(profession,64)then return nil end
    if not Z.IsOnline(key)then return nil,"Spieler ist nicht erreichbar."end
    Z.db.recipeCatalogs=Z.db.recipeCatalogs or{};Z.db.recipeCatalogs[key]=Z.db.recipeCatalogs[key]or{}
    local id=L.NextID(Z.db,A.Now())..".101";local peer=Z.db.peers[key]or{};Z.db.recipeCatalogs[key][profession]={id=id,profession=profession,results={},total=0,nextOffset=0,complete=false,recipeRev=peer.presence and peer.presence.recipeRev or 0,session=peer.session,at=A.Now()};pruneRecipeCatalogs(key,profession)
    return Z.QueuePriority(key,{kind="CQ",id=id,profession=profession,offset=0},35,"CAT:"..key..":"..id)
end
local function compactPeerProfile(peer)
    local data=peer and peer.data;if not data then return end;local presence=peer.presence or{};local professions={};for _,id in ipairs(presence.professionIDs or{})do local name=L.ProfessionNameByID(id);if name then professions[#professions+1]={id=id,name=name,rank=0,max=1}end end
    peer.guildRank=nil
    peer.data={kind="S3",rev=data.rev or 0,generation=peer.session or"",community="",faction=peer.faction or Z.me.faction,class=presence.classFile or"",classFile=presence.classFile or"",level=presence.level or 0,guild="",guid="",roles=presence.role or"",note="",professionNote="",professions=professions,group=data.group,quest=data.quest,market=data.market or{},linkMain=data.linkMain or"",linkVersion=data.linkVersion or 0,linkAlts={},recipeRev=presence.recipeRev or 0,recipeCount=0,recipeScan=0,publicOnly=true};peer.profileAt=nil
end
local function pruneProfileCache(protect)
    local full={};for candidate,row in pairs(Z.db.peers)do if row.data and not row.data.publicOnly then full[#full+1]={key=candidate,at=row.profileAt or row.received or 0}end end
    table.sort(full,function(a,b)return a.at>b.at end);for i=501,#full do if full[i].key~=protect then compactPeerProfile(Z.db.peers[full[i].key])end end
end
function Z.OnProfileReceived(key)
    local peer=Z.db.peers[key];if not peer or not peer.data then return end;peer.profileAt=A.Now();peer.data.publicOnly=nil
    local session=peer.verifiedSession or peer.data.generation or peer.session
    local revision=peer.data.recipeRev
    if L.Int(revision,0,2147483646)then
        peer.recipeSearchRev=peer.recipeSearchSession==session and math.max(peer.recipeSearchRev or 0,revision)or revision
        peer.recipeSearchSession=session
    end
    if peer.cap30 and peer.presence then
        local data,previous=peer.data,peer.presence
        if peer.verifiedSession and peer.verifiedSession==data.generation or data.rev>=previous.rev and data.recipeRev>=previous.recipeRev then
            local current={};for k,v in pairs(previous)do current[k]=v end
            current.rev,current.recipeRev=data.rev,data.recipeRev;current.professionIDs={}
            current.level,current.classFile,current.role=data.level,data.classFile,data.roles
            for _,p in ipairs(data.professions or{})do current.professionIDs[#current.professionIDs+1]=p.id end
            peer.presence=current;Z.UpdatePeerProfessions(key,previous)
        else Z.UpdatePeerProfessions(key)end
    end
    pruneProfileCache(key)
end
function Z.UpdatePeerProfessions(key,previous,sessionChanged)
    local peer=Z.db.peers[key];local presence=peer and peer.presence;if not presence then return end
    local function signature(p)return table.concat(p and p.professionIDs or{},",")end
    local changed=sessionChanged or previous and(previous.recipeRev~=presence.recipeRev or signature(previous)~=signature(presence))
    local data=peer.data
    if data then
        local old={};for _,p in ipairs(data.professions or{})do old[p.id]=p end
        local professions={};for _,id in ipairs(presence.professionIDs)do
            local name=L.ProfessionNameByID(id)or old[id]and old[id].name
            if name then professions[#professions+1]=old[id]or{id=id,name=name,rank=0,max=1}end
        end
        if data.recipeRev~=presence.recipeRev then changed=true;data.recipeCount=0 end
        if sessionChanged or data.rev~=presence.rev or data.recipeRev~=presence.recipeRev then data.publicOnly=true;peer.profileAt=nil end
        data.professions=professions;data.recipeRev=presence.recipeRev;data.level=presence.level;data.classFile=presence.classFile;data.roles=presence.role;data.class=presence.classFile~=""and L.ClassName("",presence.classFile)or""
    end
    if changed then
        Z.db.recipeCatalogs[key]=nil
        if Z.RecipeSearch then Z.RecipeSearch.InvalidatePeer(key)end
        Z.MarkDirty("profession")
    end
end
function Z.RequestProfile(key)
    local peer=Z.db.peers[key];if not peer or not Z.db.contacts[key]or not Z.IsOnline(key)then return nil,"Spieler ist nicht erreichbar."end
    if peer.data and not peer.data.publicOnly then return true end
    local now=A.Now();if Z.engine.lastRequest[key]and now-Z.engine.lastRequest[key]<10 then return nil,Z.T("Profile is already loading.")end;Z.engine.lastRequest[key]=now
    return Z.engine:Queue(key,{kind="Q3",rev=peer.data and peer.data.rev or 0},true,45,"PROFILE:"..key)
end
local function attach(db)
    Z.db=db
    Z.engine=L.Engine(db,Z.me,{now=A.Now,clock=A.Clock,send=A.Send,allowed=A.Allowed,refresh=Z.RefreshIdentity,
        reachable=function(key)local c=db.contacts[key];return c and Z.BattleNetTransport and Z.BattleNetTransport.IsReachable(c.target)end,
        pendingUntil=function(target)return Z.BattleNetTransport and Z.BattleNetTransport.PendingUntil(target)end,
        snapshot=function() return L.Snapshot(db,Z.me,Z.PublicLinks()) end,
        guildRank=function() return Z.Social and Z.Social.OwnGuildRank() or "" end,
        recipeSearch=function(q) return Z.SearchOwnRecipes(q) end,
        recipeCatalog=function(profession,offset) return Z.RecipeCatalogPage(profession,offset) end,
        catalogRevision=function(key)local peer=db.peers[key];return peer and peer.presence and peer.presence.recipeRev end,
        catalogRestart=function(key,profession)Z.RequestRecipeCatalog(key,profession)end,
        catalogUpdated=function(key,profession)pruneRecipeCatalogs(key,profession)end,
        items=function(market)if Z.Items then Z.Items.SeedMarket(market)end end,
        profile=Z.OnProfileReceived,
        application=function(kind,key,id) if Z.OnApplicationReceived then Z.OnApplicationReceived(kind,key,id) end end,
        group=function(key,group) if Z.OnGroupReceived then Z.OnGroupReceived(key,group) end end,
        pvp=function(key,message) if Z.PvPHelp then Z.PvPHelp.Receive(key,message) end end,
        finder=function(kind,event,key,id,content)if Z.RecordFinderEvent then Z.RecordFinderEvent(kind,event,key,id,content)end end,
        delivery=function(key,dedupe,ok)if Z.PvPHelp then Z.PvPHelp.Delivery(key,dedupe,ok)end;if H then H.Delivery(key,dedupe,ok)end end,
        changed=function()Z.MarkDirty()end})
    Z.engine.blocked=not Z.registered
end
function Z.RefreshIdentity()
    if not Z.db then Z.Initialize();return Z.identityReady==true end
    if Z.offlineOnly and A.Identity()then Z.db=nil;Z.offlineOnly=false;Z.Initialize();return Z.identityReady==true end
    local me=A.Identity(); if not me or me.key~=Z.me.key then
        if Z.identityReady then
            Z.identityReady=false;Z.BattleNetTransport.Reset("identity changed");Z.engine:Stop("")
            if Z.Network3 then Z.Network3.jobs={};Z.Network3.jobBytes=0 end
        end
        return false
    end
    local changed=false; for k,v in pairs(me) do if Z.me[k]~=v then changed=true end; Z.me[k]=v end
    Z.identityReady=true
    local c=Z.account and Z.account.characters[Z.accountCharacterKey];if c then c.target=Z.me.target;c.realm=Z.me.realm;c.faction=Z.me.faction;c.class=Z.me.class;c.level=Z.me.level;c.lastLogin=A.Now()end
    if changed and Z.db then L.Touch(Z.db) end
    return changed
end
function Z.SendLocation(key,background)
    if not Z.engine or not Z.db or not Z.db.contacts[key] then return nil end
    local loc=Z.location or A.PlayerLocation();local public=Z.db.visible==true
    return Z.engine:Queue(key,{kind="L1",at=A.Now(),faction=Z.me.faction,mapID=public and loc.mapID or 0,area=public and loc.area or"",subzone=public and loc.subzone or""},true,35,"LOC:"..key,{background=background==true,reason="location"})
end
function Z.RefreshLocation(force,silent)
    if not Z.db then return false end
    local loc=A.PlayerLocation();local old=Z.location
    local changed=not old or old.mapID~=loc.mapID or old.area~=loc.area or old.subzone~=loc.subzone
    if changed then loc.at=A.Now();Z.location=loc end
    if not silent and(changed or force)then if Z.Network3 then Z.Network3.Publish()end;for key,p in pairs(Z.db.peers)do local c=Z.db.contacts[key];if not p.cap30 and p.lastContact and c and Z.BattleNetTransport.IsReachable(c.target)then Z.SendLocation(key,true)end end end
    return changed
end
function Z.OnPublicBundle(key,snapshot)
    if Z.TradeManager then Z.TradeManager.OnBundle(key,snapshot)end
    if Z.OnGroupReceived and snapshot.group then Z.OnGroupReceived(key,snapshot.group)end
end
function Z.ResolvePeerKey(sender)
    if not Z.db or not L.Text(sender,113)then return nil end
    local _,target=L.Identity(sender,Z.me and Z.me.realm);if not target then return nil end
    local scoped=Z.me and L.ScopeKey(target,Z.me.realm,Z.me.faction)
    if Z.Network3 and Z.Network3.meshContext then return scoped end
    if scoped and(Z.db.contacts[scoped]or scoped==Z.me.key)then return scoped end
    for key,contact in pairs(Z.db.contacts or{})do if contact.target==target then return key end end
    return scoped
end
function Z.Receive3(sender,kind,wire)
    if kind=="SP"and Z.ActivityParty then return Z.ActivityParty.Receive(sender,wire)end
    if(kind=="SH"or kind=="SA"or kind=="SQ"or kind=="SS"or kind=="SK"or kind=="SX")and Z.ScheduledGroups then return Z.ScheduledGroups.Receive(sender,kind,wire)end
    if kind=="AV"and Z.UpdateNotice then return Z.UpdateNotice.Receive(sender,wire)end
    if(kind=="RQ"or kind=="RR"or kind=="RB")and Z.RecipeSearch then return Z.RecipeSearch.Receive(sender,kind,wire)end
    if(kind=="OC"or kind=="OO"or kind=="OS"or kind=="OQ"or kind=="OA")and Z.CraftOrders then return Z.CraftOrders.Receive(sender,kind,wire)end
    if(kind=="PC"or kind=="PU"or kind=="PX")and Z.PvPHelp and Z.PvPHelp.Receive3 then return Z.PvPHelp.Receive3(sender,kind,wire)end
    return false
end
function Z.Queue(key,message) return Z.engine:Queue(key,message,true,60) end
function Z.QueuePriority(key,message,priority,dedupe) return Z.engine:Queue(key,message,true,priority or 90,dedupe) end
function Z.IsOnline(key)
    if key==Z.me.key then return true end
    local peer=Z.db and Z.db.peers[key]
    if peer and peer.cap4 then return Z.Network3.IsOnline(key)end
    return(Z.Network3 and Z.Network3.IsOnline(key))or L.PeerOnline(Z.db,key,A.Now())
end
function Z.Reachability(key)
    local c=Z.db and Z.db.contacts[key];local p=Z.db and Z.db.peers[key]
    if key==Z.me.key or c and Z.BattleNetTransport.IsReachable(c.target)then return "Directly reachable"end
    if p and p.cap4 and Z.IsOnline(key)then return "Reported in network"end
    return Z.IsOnline(key)and"Online"or"Offline"
end
function Z.RecordFinderEvent(kind,event,key,id,content,contentOwnerKey)
    if Z.Notifications then Z.Notifications.Finder(kind,event,key,id,contentOwnerKey or(event=="joined"and key))end
    if not H then return end;local c=Z.db.contacts[key];if not contentOwnerKey and(event=="withdrawal_sent"or event=="invited_received"or event=="rejected_received"or event=="joined")then contentOwnerKey=key end;contentOwnerKey=contentOwnerKey or Z.me.key;local token=event=="joined"and("joined:"..kind..":"..contentOwnerKey..":"..id..":"..key..":"..Z.me.key)or nil
    return H.RecordPeer(kind,event,id,content,key,c and c.target or key,token,contentOwnerKey)
end
function Z.ExpireFinder(now)
    now=now or A.Now();local g=Z.db.lfg[1];local q=Z.db.quest
    if H and g and g.expires<=now then H.RecordOwn("group","group_expired",g)end
    if H and q and q.expires<=now then H.RecordOwn("quest","quest_expired",q)end
    local changed=Z.TradeManager and Z.TradeManager.ArchiveExpired(now)or false;if L.Expire(Z.db,now)then changed=true end;if H then H.Prune(now)end;return changed
end
function Z.SaveGroup(g,now)
    if Z.ActivityParty then Z.ActivityParty.liveBaseline=nil end
    now=now or A.Now();Z.ExpireFinder(now);local editing=Z.db.lfg[1]and Z.db.lfg[1].id==g.id;local id,err=L.SaveGroup(Z.db,g,now);if id and H then H.RecordOwn("group",editing and"group_updated"or"group_created",g)end;if id and Z.UIState then Z.UIState.Draft("group",false)end;if id and Z.ActivityParty then Z.ActivityParty.SyncLive()end;return id,err
end
function Z.CloseGroup(id)
    local g=Z.db.lfg[1];if not g or g.id~=id then return false end;if H then H.RecordOwn("group","group_closed",g)end;local closed=L.CloseGroup(Z.db,id);if closed and Z.Network3 then Z.Network3.Retract("G",id,Z.db.rev)end;return closed
end
function Z.SaveQuest(q,now)
    now=now or A.Now();Z.ExpireFinder(now);local editing=Z.db.quest and Z.db.quest.id==q.id;local id,err=L.SaveQuest(Z.db,q,now);if id and H then H.RecordOwn("quest",editing and"quest_updated"or"quest_created",q)end;if id and Z.UIState then Z.UIState.Draft("quest",false)end;return id,err
end
function Z.CloseQuest(id)
    local q=Z.db.quest;if not q or q.id~=id then return false end;if H then H.RecordOwn("quest","quest_closed",q)end;local closed=L.CloseQuest(Z.db,id);if closed and Z.Network3 then Z.Network3.Retract("Q",id,Z.db.rev)end;return closed
end
function Z.FindForeignGroup(key,id)
    if not Z.IsOnline(key)then return nil end;local p=Z.db.peers[key];local s=p and p.data;local g=s and(s.group or s.lfg and s.lfg[1]);if g and g.id==id and g.expires>A.Now()then return g end
end
function Z.FindForeignQuest(key,id)
    if not Z.IsOnline(key)then return nil end;local p=Z.db.peers[key];local q=p and p.data and p.data.quest;if q and q.id==id and q.expires>A.Now()then return q end
end
function Z.ApplyGroup(key,id,role,note)
    local content=Z.FindForeignGroup(key,id);if not content then return nil,"Die Gruppe ist nicht mehr aktiv." end
    role=L.Role(role);if not role then return nil,"Ungültige Rolle."end
    local old=Z.db.sentApplications[id] and Z.db.sentApplications[id][key];if old and old.state~="withdrawn" then return nil,"Du hast dich bereits beworben." end
    local c=Z.db.contacts[key];local dedupe,entry;if H then dedupe,entry=H.QueueApplication("group",content,key,c and c.target or key)end;local q,e=Z.QueuePriority(key,{kind="GA",id=id,role=role,note=note or""},60,dedupe);if q then Z.db.sentApplications[id]=Z.db.sentApplications[id]or{};Z.db.sentApplications[id][key]={state="applied",at=A.Now()};Z.RefreshLocation(true,true);Z.SendLocation(key)elseif H and entry then H.Remove(entry.id)end;return q,e
end
function Z.WithdrawGroup(key,id)
    local old=Z.db.sentApplications[id] and Z.db.sentApplications[id][key];if not old or old.state=="withdrawn" then return nil,"Keine aktive Bewerbung." end
    local q,e=Z.Queue(key,{kind="GW",id=id});if q then old.state="withdrawn";old.at=A.Now();Z.RecordFinderEvent("group","withdrawal_sent",key,id)end;return q,e
end
function Z.ApplyQuest(key,id,note)
    local content=Z.FindForeignQuest(key,id);if not content then return nil,"Die Questanfrage ist nicht mehr aktiv." end
    local old=Z.db.sentQuestApplications[id] and Z.db.sentQuestApplications[id][key];if old and old.state~="withdrawn" then return nil,"Du hast bereits Hilfe angeboten." end
    local c=Z.db.contacts[key];local dedupe,entry;if H then dedupe,entry=H.QueueApplication("quest",content,key,c and c.target or key)end;local q,e=Z.QueuePriority(key,{kind="QA",id=id,note=note or""},60,dedupe);if q then Z.db.sentQuestApplications[id]=Z.db.sentQuestApplications[id]or{};Z.db.sentQuestApplications[id][key]={state="applied",at=A.Now()};Z.RefreshLocation(true,true);Z.SendLocation(key)elseif H and entry then H.Remove(entry.id)end;return q,e
end
function Z.WithdrawQuest(key,id)
    local old=Z.db.sentQuestApplications[id] and Z.db.sentQuestApplications[id][key];if not old or old.state=="withdrawn" then return nil,"Kein aktives Hilfeangebot." end
    local q,e=Z.Queue(key,{kind="QW",id=id});if q then old.state="withdrawn";old.at=A.Now();Z.RecordFinderEvent("quest","withdrawal_sent",key,id)end;return q,e
end
function Z.RecordDecision(kind,key,id,state,content)
    if state=="invited"then Z.RecordFinderEvent(kind,"invited_sent",key,id,content,Z.me.key)elseif state=="rejected"then Z.RecordFinderEvent(kind,"rejected_sent",key,id,content,Z.me.key)end
end
function Z.ObserveFinderGroup()
    if not H or not A.GroupMembers then return end;local members=A.GroupMembers();local function joined(kind,id,key,content,row,notify)
        if(row.state~="invited"and row.state~="joined")or not members[key]or Z.db.blocked[key]then return end
        local owner=notify and Z.me.key or key;local token="joined:"..kind..":"..owner..":"..id..":"..key..":"..Z.me.key
        local existing=H.byToken[token];if row.state=="joined"and existing and existing.observedAt then return end
        local invited=row.state=="invited";row.state="joined";row.at=A.Now()
        local entry=Z.RecordFinderEvent(kind,"joined",key,id,content,owner);H.MarkObserved(entry)
        if notify and invited then Z.Queue(key,{kind=kind=="group"and"GS"or"QS",id=id,state="joined"})end
    end
    local g=Z.db.lfg[1];if g then for key,row in pairs(Z.db.interests[g.id]or{})do joined("group",g.id,key,g,row,true)end end
    local q=Z.db.quest;if q then for key,row in pairs(Z.db.questInterests[q.id]or{})do joined("quest",q.id,key,q,row,true)end end
    for id,people in pairs(Z.db.sentApplications)do for key,row in pairs(people)do joined("group",id,key,nil,row,false)end end
    for id,people in pairs(Z.db.sentQuestApplications)do for key,row in pairs(people)do joined("quest",id,key,nil,row,false)end end
end
function Z.OnApplicationReceived(kind,key,id) if Z.UI and Z.UI.NotifyApplication then Z.UI.NotifyApplication(kind,key,id) end end
function Z.OnPvpHelpIncoming(key,id)if Z.UI and Z.UI.NotifyPvPHelp then Z.UI.NotifyPvPHelp(key,id)end end
function Z.OnPvpHelpEligible()if Z.UI and Z.UI.NotifyPvPHelpEligible then Z.UI.NotifyPvPHelpEligible()end end
function Z.SetGroupFollow(activity,enabled)
    activity=L.ActivityID(activity);if not L.Text(activity,64)then return false end
    if enabled then
        Z.db.groupFollows[activity]=true
        for key,p in pairs(Z.db.peers)do local s=p.data;local g=s and(s.group or s.lfg and s.lfg[1]);local name=g and L.ActivityID(g.activity);if g and name==activity then Z.db.groupFollowSeen[key]=g.id end end
    else Z.db.groupFollows[activity]=nil end
    return true
end
function Z.OnGroupReceived(key,group)
    if not Z.db or type(group)~="table"or not L.Text(group.id,32)or not L.Text(group.activity,64)then return end
    if Z.db.groupFollowSeen[key]==group.id then return end
    Z.db.groupFollowSeen[key]=group.id
    local activity=L.ActivityID(group.activity)
    if Z.db.groupFollows[activity]and Z.UI and Z.UI.NotifyGroupFollow then Z.UI.NotifyGroupFollow(key,group.id,activity)end
end
function Z.SetPreference(name,value)
    local allowed={consent=true,autoDiscovery=true,visible=true,shareProfessions=true,shareGuild=true,shareQuests=true}
    if not allowed[name]or type(value)~="boolean"or not Z.db then return false end
    Z.db[name]=value
    if Z.AccountPreferences then Z.AccountPreferences.Save()end
    if Z.QuestHelper then Z.QuestHelper.PrivacyChanged()end
    if Z.ScheduledGroups then Z.ScheduledGroups.PrivacyChanged()end
    if Z.BattleNetTransport then Z.BattleNetTransport.Reset("privacy")end
    if Z.CommunityMesh then Z.CommunityMesh.PrivacyChanged()end
    if Z.CommunityDirectory then Z.CommunityDirectory.RequestScan()end
    -- Retract queued data assembled under an older privacy setting.
    if Z.engine then Z.engine:Stop("")end
    if Z.Network3 then
        Z.Network3.CancelPublic()
        if name=="consent"and not value then Z.Network3.jobs={};Z.Network3.jobBytes=0 end
        if name=="visible"or name=="shareProfessions"then for i=#Z.Network3.jobs,1,-1 do local job=Z.Network3.jobs[i];if job.kind=="RR"then Z.Network3.jobBytes=math.max(0,Z.Network3.jobBytes-#job.wire);table.remove(Z.Network3.jobs,i)end end end
        Z.Network3.nextPresence=0
    end
    L.Touch(Z.db);Z.Publish();Z.MarkDirty("settings");return true
end
function Z.Block(key)
    local contact=Z.db.contacts[key];local target=contact and contact.target
    if Z.engine then Z.engine:CancelPeer(key)end
    if Z.Network3 then Z.Network3.CancelPeer(key,target)end
    if target and Z.BattleNetTransport then Z.BattleNetTransport.CancelPeer(target)end
    if target and Z.CommunityMesh then Z.CommunityMesh.CancelPeer(target)end
    if target and Z.QuestMesh then Z.QuestMesh.CancelPeer(target)end
    if Z.RecipeSearch then Z.RecipeSearch.Block(key)end
    if Z.CraftOrders then Z.CraftOrders.Block(key)end
    if Z.ScheduledGroups then Z.ScheduledGroups.Block(key)end
    if target and Z.ScheduledMesh then Z.ScheduledMesh.CancelPeer(target)end
    if Z.PvPHelp and Z.PvPHelp.store then Z.PvPHelp.Block(key)end
    if Z.Notifications then Z.Notifications.RemovePeer(key)end
    return L.Block(Z.db,key)
end
function Z.Reset()
    if Z.offlineOnly then return false end
    local rev,seq=Z.db.rev,Z.db.seq; Z.engine:Stop(""); local d=L.New(); d.rev=math.min(rev+1,2147483646); d.seq=seq; d.generation=tostring(A.Now()).."."..tostring(seq)
    for _,name in ipairs({"consent","autoDiscovery","visible","shareProfessions","shareGuild","shareQuests"})do d[name]=Z.db[name]end
    if Z.UI and Z.UI.CloseDialogs then Z.UI.CloseDialogs()end
    ZenialCommunityDB.characters[Z.storageKey]=d;Z.db=nil;Z.Initialize();Z.MarkDirty("reset")
end
-- Z.Initialize runs these steps strictly in the order listed in the function body below.
-- Splitting the former single-line statements into named steps changes no call, condition or order.

-- Step 1: player identity. Returns nil when initialisation has to stop (secret-value client without identity).
local function acquireIdentity()
    local me=A.Identity()
    Z.identityReady=me~=nil
    if not me then
        if type(issecretvalue)=="function"then return nil end
        -- A client without a secret-value inspector can still open the UI, but
        -- its offline state is transient and cannot send or migrate player data.
        Z.offlineRoot=ZenialCommunityDB
        ZenialCommunityDB={}
        me={key="local-unavailable",target="Unknown Player",realm="",faction="Neutral",class="",classFile="",level=0,guild="",guid=""}
        Z.offlineOnly=true
    end
    return me
end

-- Step 2: saved-variable root, forever/live migration and account table.
local function prepareAccount(me)
    Z.me=me
    Z.storageKey=accountCharacterKey(me)
    if type(ZenialCommunityDB)~="table" then ZenialCommunityDB={} end
    if not Z.offlineOnly then Z.MigrateForeverLive(ZenialCommunityDB)end
    if type(ZenialCommunityDB.characters)~="table" then ZenialCommunityDB.characters={} end
    Z.account=account()
    Z.MigrateSurnameRealms(ZenialCommunityDB,Z.me,Z.account)
    local legacyKey=migrateLegacyCharacter(ZenialCommunityDB,Z.me,Z.account)
    Z.accountCharacterKey=accountCharacterKey(Z.me)
    normalizeAccount(Z.account,Z.me,legacyKey)
    if Z.Items then Z.Items.Initialize(ZenialCommunityDB)end
end

-- Step 3: adopt data stored under the beta or legacy character keys (the originals are kept as a backup).
local function adoptLegacyStorageKeys()
    local betaKey=(Z.me.legacyKey or Z.me.key).."@"..string.lower(Z.me.realm or"").."@"..string.lower(Z.me.faction or"")
    if not ZenialCommunityDB.characters[Z.storageKey]and ZenialCommunityDB.characters[betaKey]then
        ZenialCommunityDB.migrationBackup=ZenialCommunityDB.migrationBackup or{}
        ZenialCommunityDB.migrationBackup[betaKey]=ZenialCommunityDB.characters[betaKey]
        ZenialCommunityDB.characters[Z.storageKey]=ZenialCommunityDB.characters[betaKey]
    end
    if not ZenialCommunityDB.characters[Z.storageKey]and ZenialCommunityDB.characters[Z.me.key]then
        ZenialCommunityDB.migrationBackup=ZenialCommunityDB.migrationBackup or{}
        ZenialCommunityDB.migrationBackup[Z.me.key]=ZenialCommunityDB.characters[Z.me.key]
        ZenialCommunityDB.characters[Z.storageKey]=ZenialCommunityDB.characters[Z.me.key]
    end
    if type(ZenialCommunityDB.ui)=="table"and type(ZenialCommunityDB.ui.characters)=="table"and not ZenialCommunityDB.ui.characters[Z.storageKey]then
        ZenialCommunityDB.ui.characters[Z.storageKey]=ZenialCommunityDB.ui.characters[betaKey]or ZenialCommunityDB.ui.characters[Z.me.key]
    end
    if type(ZenialCommunityDB.pvpHelp)=="table"and not ZenialCommunityDB.pvpHelp[Z.storageKey]then
        ZenialCommunityDB.pvpHelp[Z.storageKey]=ZenialCommunityDB.pvpHelp[betaKey]or ZenialCommunityDB.pvpHelp[Z.me.key]
    end
end

-- Step 4: load and normalise the character record. Returns it.
local function loadCharacterData()
    local d=L.Load(ZenialCommunityDB.characters[Z.storageKey])
    if Z.AccountPreferences then Z.AccountPreferences.Apply(d)end
    if Z.offlineOnly then d.consent=false end
    L.Touch(d)
    if d.generation=="" then d.generation=tostring(A.Now()).."."..tostring(d.seq) end
    return d
end

-- Step 5: register the record and start the local gameplay modules.
local function initializeGameplayModules(d)
    ZenialCommunityDB.version=L.VERSION
    ZenialCommunityDB.characters[Z.storageKey]=d
    Z.registered=A.Register()
    attach(d)
    pruneProfileCache()
    if Z.Network3 then Z.Network3.Initialize()end
    if Z.TradeManager then Z.TradeManager.Initialize()end
    if Z.GroupFinder then Z.GroupFinder.Initialize()end
    if Z.GroupFinderCatalog then Z.GroupFinderCatalog.Resume()end
    if Z.Social then Z.Social.Initialize()end
    if Z.SocialCategories then Z.SocialCategories.Initialize()end
    if Z.SocialDiary then Z.SocialDiary.Initialize()end
    if Z.AccountOverview then Z.AccountOverview.Initialize()end
    if Z.CraftOrders then Z.CraftOrders.Initialize()end
    if Z.ProfessionScan then Z.ProfessionScan.Initialize()end
    if Z.RecipeSearch then Z.RecipeSearch.Initialize()end
    if Z.Items then Z.Items.Seed()end
    Z.RefreshLocation(false,true)
    if Z.UIState then
        Z.UIState.Initialize(ZenialCommunityDB,Z.storageKey,d)
        Z.Notifications.Initialize()
    end
    if H then H.Initialize(ZenialCommunityDB,Z.me)end
    Z.ExpireFinder(A.Now())
    if Z.PvPHelp then Z.PvPHelp.Initialize(ZenialCommunityDB,Z.storageKey)end
end

-- Step 6: directory, transport, mesh, map and scheduled-group modules.
local function initializeNetworkModules()
    Z.CommunityDirectory.Initialize(ZenialCommunityDB)
    Z.BattleNetTransport.Initialize()
    Z.CommunityMesh.Initialize()
    if Z.CommunityLayer then Z.CommunityLayer.Initialize()end
    Z.QuestMesh.Initialize()
    Z.QuestHelper.Initialize()
    Z.CommunityMap.Initialize()
    Z.UpdateNotice.Initialize(ZenialCommunityDB)
    Z.MaterialPlanner.Initialize()
    Z.ScheduledGroups.Initialize()
    Z.ActivityParty.Initialize()
    Z.ScheduledMesh.Initialize()
    if Z.CrossFaction then Z.CrossFaction.Initialize()end
end

-- Step 7: companion, account preferences, minimap button and badges.
local function initializeCompanionAndViews()
    if Z.Companion then
        Z.Companion.Initialize()
        Z.Companion.InitializeIntroduction()
    end
    if Z.CompanionProgress then Z.CompanionProgress.Initialize()end
    if Z.AccountPreferences then Z.AccountPreferences.ApplyViews()end
    -- Drop the obsolete channel membership retained by older installations.
    A.Call(LeaveChannelByName,"ZENIALCommunity")
    if Z.UI and Z.UI.CreateMinimapButton then Z.UI.CreateMinimapButton() end
    if Z.UI and Z.UI.UpdateBadges then Z.UI.UpdateBadges() end
end

function Z.Initialize()
    if Z.db then return end
    local me=acquireIdentity()
    if not me then return false end
    prepareAccount(me)
    adoptLegacyStorageKeys()
    local d=loadCharacterData()
    initializeGameplayModules(d)
    initializeNetworkModules()
    initializeCompanionAndViews()
    if Z.offlineOnly then Z.transientRoot=ZenialCommunityDB;ZenialCommunityDB=Z.offlineRoot or{} end
end
SLASH_ZENIALCOMMUNITY1="/zenial"
SlashCmdList.ZENIALCOMMUNITY=function(text)
    Z.Initialize();if not Z.db then return end
    if Z.CrossFaction and Z.CrossFaction.HandleSubcommand and Z.CrossFaction.HandleSubcommand(text) then return end
    text=type(text)=="string" and string.lower(text:match("^%s*(.-)%s*$") or "") or ""
    if text=="discover" or text=="finden" then Z.CommunityDirectory.RequestScan();A.DiscoveryTick(true)
    elseif text=="debug on"then Z.Companion.SetDebugPixel(true)
    elseif text=="debug off"then Z.Companion.SetDebugPixel(false)
    elseif text=="companion"then Z.Companion.Show()
    elseif text=="diary"or text=="tagebuch"then if Z.UI and Z.UI.OpenSocialDiaryForUnit then Z.UI.OpenSocialDiaryForUnit("target")end
    elseif text=="alts"or text=="twinks"or text=="account"then if Z.UI and Z.UI.OpenMyCharacters then Z.UI.OpenMyCharacters()end
    elseif text=="setup advanced"then Z.NetworkSetup.ShowAdvanced()
    elseif text=="setup"or text=="bnet"or text=="lounge"then Z.NetworkSetup.Show()
    elseif text=="network" or text=="netzwerk" then for _,line in ipairs(A.NetworkStatus())do if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line)else print(line)end end;if Z.UI then Z.UI.ShowDiagnostics()end
    elseif text=="debug"or text=="diagnose"or text=="diagnostics"or text=="logs"then if Z.UI then Z.UI.ShowDiagnostics()end
    elseif text=="finderart"then
        -- Which finder pictures the client resolves (GroupFinderArt.lua): one line per activity without a picture.
        local function say(line)if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line)else print(line)end end
        local client,journal,missing=0,0,0
        for _,row in ipairs(Z.GroupFinderArt and Z.GroupFinderArt.Report()or{})do
            if row.source=="client"then client=client+1 elseif row.source=="journal"then journal=journal+1
            else missing=missing+1;say("ZENIAL finder art: "..row.id..(row.listed>0 and" - listed client texture not found"or" - no picture (neutral tile)"))end
        end
        say(("ZENIAL finder art: %d client, %d DungeonJournal, %d neutral. DungeonJournal %s."):format(client,journal,missing,Z.DungeonJournalLink and Z.DungeonJournalLink.Available()and"found"or"not loaded"))
    elseif text=="resetpos" then Z.db.position=nil; Z.db.scale=1; if Z.UI and Z.UI.frame then Z.UI.frame:SetScale(1); Z.UI.frame:ClearAllPoints(); Z.UI.frame:SetPoint("CENTER") end
    elseif text=="pvptest" then
        local on=Z.PvPHelp and Z.PvPHelp.ToggleTestMode();local line="ZENIAL: PvP test mode "..(on and"on until /reload."or"off.")
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line)else print(line)end
    elseif Z.UI then Z.UI.Toggle() end
end
-- Named by the TOC; clients without an addon compartment simply never call it.
function ZenialCommunity_OnAddonCompartmentClick() SlashCmdList.ZENIALCOMMUNITY("") end
local frame=CreateFrame("Frame"); Z.eventFrame=frame
local function register(event) local ok,r=pcall(frame.RegisterEvent,frame,event); return ok and r~=false end
Z.bnetReceiveEvent=register("BN_CHAT_MSG_ADDON");register("INITIAL_CLUBS_LOADED")
for _,event in ipairs({"BN_CONNECTED","BN_DISCONNECTED","BN_FRIEND_INFO_CHANGED","CLUB_ADDED","CLUB_REMOVED","CLUB_UPDATED","CLUB_MEMBERS_UPDATED","CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED","CLUB_MEMBER_UPDATED","CLUB_MEMBER_PRESENCE_UPDATED","PLAYER_ENTERING_WORLD"})do register(event)end
register("PLAYER_LOGIN")
register("PLAYER_LEVEL_UP")
register("ADDON_LOADED")
Z.receiveEvent=register("CHAT_MSG_ADDON")
register("GROUP_ROSTER_UPDATE")
register("PLAYER_GUILD_UPDATE");register("GUILD_ROSTER_UPDATE")
register("SKILL_LINES_CHANGED")
register("SPELLS_CHANGED")
register("TRADE_SKILL_SHOW")
register("TRADE_SKILL_CLOSE")
register("TRADE_SKILL_DATA_SOURCE_CHANGING")
register("TRADE_SKILL_DATA_SOURCE_CHANGED")
register("TRADE_SKILL_LIST_UPDATE")
register("TRADE_SKILL_DETAILS_UPDATE")
register("QUEST_LOG_UPDATE")
register("QUEST_ACCEPTED")
register("QUEST_REMOVED")
register("QUEST_TURNED_IN")
register("PLAYER_REGEN_ENABLED")
register("PLAYER_DEAD")
register("PLAYER_FLAGS_CHANGED")
register("PLAYER_ALIVE")
register("PLAYER_UNGHOST")
register("ZONE_CHANGED_NEW_AREA")
register("ZONE_CHANGED")
register("ZONE_CHANGED_INDOORS")
register("PLAYER_TARGET_CHANGED")
register("UPDATE_MOUSEOVER_UNIT")
register("NAME_PLATE_UNIT_ADDED")
register("NAME_PLATE_UNIT_REMOVED")
-- Layer transfer signals; registration is defensive because the client may not know them.
register("SHARD_TRANSFER");register("SHARD_TRANSFER_IMMINENT")
register("BAG_UPDATE_DELAYED")
register("GET_ITEM_INFO_RECEIVED")
register("ITEM_DATA_LOAD_RESULT")
register("ADDON_ACTION_BLOCKED");register("ADDON_ACTION_FORBIDDEN")
register("CHAT_MSG_SAY");register("CHAT_MSG_YELL")
register("CHAT_MSG_WHISPER");register("CHAT_MSG_WHISPER_INFORM")
frame:SetScript("OnEvent",function(_,event,...)
    if Z.db and Z.Social and Z.Social.OnGuildEvent then Z.Social.OnGuildEvent(event,...)end
    if event=="GUILD_ROSTER_UPDATE" then return end
    if(event=="PLAYER_TARGET_CHANGED"or event=="PLAYER_REGEN_ENABLED")and Z.CrossFactionTargetBadge then pcall(Z.CrossFactionTargetBadge.Refresh)end
    -- Presence messages (XF3-T06): greetings, pings to targets and whisper partners; a whisper event has no other consumer.
    local presence=Z.CrossFactionPresence
    if presence then
        if event=="PLAYER_ENTERING_WORLD"or event=="GROUP_ROSTER_UPDATE"then pcall(presence.Announce)
        elseif event=="PLAYER_TARGET_CHANGED"then pcall(presence.OnTarget)
        elseif event=="CHAT_MSG_WHISPER"or event=="CHAT_MSG_WHISPER_INFORM"then pcall(presence.OnWhisper,event,...);return end
    end
    if event=="PLAYER_LOGIN" then Z.Initialize();if Z.CrossFaction then pcall(Z.CrossFaction.RegisterCommands)end
    elseif event:match("^QUEST_")or event=="PLAYER_REGEN_ENABLED"then if Z.db and Z.QuestHelper then Z.QuestHelper.OnEvent(event)end
    elseif event=="BN_CHAT_MSG_ADDON"then if Z.db then local prefix,payload,_,sender=...
        -- The presence prefix never reaches BattleNetTransport; a secret or non-string prefix goes the old way.
        if Z.CrossFactionPresence and A.Safe(prefix)and type(prefix)=="string"and prefix==Z.CrossFactionPresence.PREFIX then pcall(Z.CrossFactionPresence.OnBNet,prefix,payload,sender)
        else Z.BattleNetTransport.Receive(prefix,payload,"BNET",sender)end end
    elseif event:match("^BN_")or event:match("^CLUB_")or event=="INITIAL_CLUBS_LOADED"or event=="PLAYER_ENTERING_WORLD"then
        if Z.db then if event=="PLAYER_ENTERING_WORLD"and Z.CommunityLayer then Z.CommunityLayer.OnEvent(event)end;if event=="PLAYER_ENTERING_WORLD"and Z.SocialDiary then Z.SocialDiary.OnEvent(event)end;Z.CommunityDirectory.OnEvent(event);if event=="BN_DISCONNECTED"then Z.BattleNetTransport.Reset("disconnect")end end
    elseif event=="PLAYER_LEVEL_UP" then
        if Z.RefreshIdentity() then Z.Publish() end
        if Z.UI and Z.UI.frame and Z.UI.frame:IsShown() then Z.UI.Refresh() end
    elseif event=="ADDON_LOADED" then Z.CommunityMap.TryAttach();if Z.UI and Z.UI.frame and Z.UI.frame:IsShown() and Z.UI.OnAddonLoaded then Z.UI.OnAddonLoaded(...)end
    elseif event=="GET_ITEM_INFO_RECEIVED"or event=="ITEM_DATA_LOAD_RESULT"then if Z.Items then Z.Items.OnEvent(...)end
    elseif event=="BAG_UPDATE_DELAYED"then if Z.Items then Z.Items.SeedBags()end;if Z.db and Z.MaterialPlanner then Z.MaterialPlanner.InvalidateInventory()end
    elseif event=="CHAT_MSG_ADDON" then
        -- The presence prefix never reaches A.Receive; a secret or non-string prefix goes the old way.
        local prefix=...
        if Z.CrossFactionPresence and A.Safe(prefix)and type(prefix)=="string"and prefix==Z.CrossFactionPresence.PREFIX then pcall(Z.CrossFactionPresence.OnAddon,...)
        elseif Z.db then A.Receive(...) end
    elseif event=="SKILL_LINES_CHANGED"or event=="SPELLS_CHANGED"or event:match("^TRADE_SKILL_")then if Z.ProfessionScan then Z.ProfessionScan.OnEvent(event,...)end
    elseif event=="PLAYER_DEAD"or event=="PLAYER_ALIVE"or event=="PLAYER_UNGHOST"or event=="PLAYER_FLAGS_CHANGED"then if Z.PvPHelp then Z.PvPHelp.OnEvent(event,...)end
    elseif event=="ZONE_CHANGED_NEW_AREA"or event=="ZONE_CHANGED"or event=="ZONE_CHANGED_INDOORS"then if Z.CommunityLayer then Z.CommunityLayer.OnEvent(event)end;if Z.db and Z.SocialDiary and event=="ZONE_CHANGED_NEW_AREA"then Z.SocialDiary.OnEvent(event)end;Z.RefreshLocation(false)
    elseif event=="PLAYER_TARGET_CHANGED"or event=="UPDATE_MOUSEOVER_UNIT"or event=="NAME_PLATE_UNIT_ADDED"or event=="NAME_PLATE_UNIT_REMOVED"then local unit=event=="PLAYER_TARGET_CHANGED"and"target"or event=="UPDATE_MOUSEOVER_UNIT"and"mouseover"or event=="NAME_PLATE_UNIT_ADDED"and...or nil;if Z.CommunityLayer then Z.CommunityLayer.RequestScan(unit)end;if Z.PvPDeath and unit and event~="NAME_PLATE_UNIT_REMOVED"then Z.PvPDeath.Observe(unit)end
    elseif event=="SHARD_TRANSFER"or event=="SHARD_TRANSFER_IMMINENT"then if Z.db and Z.CommunityLayer then Z.CommunityLayer.OnEvent(event)end
    elseif event=="GROUP_ROSTER_UPDATE" then
        if Z.CommunityLayer then Z.CommunityLayer.OnEvent(event)end
        Z.CommunityMap.Refresh()
        if Z.ActivityParty and Z.ActivityParty.SyncLive()then L.Touch(Z.db);Z.Publish()end
        if Z.db and Z.db.lfg[1] and Z.db.lfg[1].mode~="LFG" then local have=A.GroupRoles(); if Z.db.lfg[1].have~=have then Z.db.lfg[1].have=have; L.Touch(Z.db); Z.Publish() end end
        if Z.db then Z.ObserveFinderGroup()end
        if Z.db and Z.SocialDiary then Z.SocialDiary.OnEvent(event)end
        A.DiscoveryTick(true)
    elseif event=="PLAYER_GUILD_UPDATE" then A.DiscoveryTick(true)
    elseif event=="ADDON_ACTION_BLOCKED"or event=="ADDON_ACTION_FORBIDDEN"then if Z.CrossFaction then Z.CrossFaction.OnBlocked(event,...)end
    elseif event=="CHAT_MSG_SAY"or event=="CHAT_MSG_YELL"then if Z.CrossFaction then pcall(Z.CrossFaction.OnChat,event,...)end
    elseif Z.UI and Z.UI.frame and Z.UI.frame:IsShown() then Z.UI.Refresh() end
end)
local elapsed,refresh,timed=0,0,0

-- OnUpdate runs three accumulated steps in this order: every 0.25 s, every 1 s, every 5 s.
-- The call order inside each step is deliberate (transport before mesh before UI) and is pinned by
-- _dev/tests/test_community_main_order.lua; do not reorder without updating that test.

-- Every 0.25 s: protocol/transport/gameplay ticks, then pending UI refresh and notices.
local function tickQuarterSecond()
    Z.CommunityDirectory.Tick()
    Z.UpdateNotice.Tick()
    if Z.NetworkSetup then Z.NetworkSetup.Tick()end
    if Z.Companion then Z.Companion.TickIntroduction()end
    Z.BattleNetTransport.Tick()
    Z.engine:Tick()
    if Z.Network3 then
        Z.Network3.Tick()
        Z.Network3.ExpireAssemblies()
    end
    Z.CommunityMesh.Tick()
    if Z.CommunityLayer then Z.CommunityLayer.Tick()end
    Z.QuestHelper.Tick()
    Z.MaterialPlanner.Tick()
    Z.ScheduledMesh.Tick()
    Z.ScheduledGroups.Tick()
    Z.ActivityParty.Tick()
    Z.QuestMesh.Tick()
    Z.CommunityMap.Tick()
    if Z.ProfessionScan then Z.ProfessionScan.Tick()end
    if Z.RecipeSearch then Z.RecipeSearch.Tick()end
    if Z.CraftOrders then Z.CraftOrders.Tick()end
    if Z.PvPHelp then Z.PvPHelp.Tick()end
    if Z.Items then Z.Items.Tick()end
    A.DiscoveryTick(false)
    if uiDirty and Z.UI and Z.UI.frame and Z.UI.frame:IsShown()then
        uiDirty=false
        Z.UI.Refresh(nil,true)
    end
    if Z.UI and Z.UI.TickNotices then Z.UI.TickNotices(A.Clock())end
end

-- Every 1 s: time-dependent UI state.
local function tickSecond()
    if Z.Social and Z.Social.GuildTick then Z.Social.GuildTick()end
    if Z.UI and Z.UI.RefreshTimed then Z.UI.RefreshTimed(A.Clock())end
    if Z.CrossFaction then pcall(function()Z.CrossFaction.Tick()end)end
end

-- Every 5 s: identity, location and expiry housekeeping.
local function tickFiveSeconds()
    if Z.RefreshIdentity()then Z.Publish()end
    Z.RefreshLocation(false)
    if Z.ExpireFinder(A.Now())then Z.Publish()end
    if Z.PvPHelp then Z.PvPHelp.Expire()end
end

frame:SetScript("OnUpdate",function(_,dt)
    if type(dt)~="number"then return end
    if not Z.engine then
        -- Not initialised yet: retry once per second.
        refresh=refresh+dt
        if refresh>=1 then
            refresh=0
            Z.Initialize()
        end
        return
    end
    elapsed=elapsed+dt
    refresh=refresh+dt
    timed=timed+dt
    if elapsed>=.25 then elapsed=0;tickQuarterSecond()end
    if timed>=1 then timed=0;tickSecond()end
    if refresh>=5 then refresh=0;tickFiveSeconds()end
end)
