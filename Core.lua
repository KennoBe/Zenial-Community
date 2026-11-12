ZenialCommunity = ZenialCommunity or {}
-- The TOC is the source of truth. The fallback is only used when the client
-- cannot report metadata and must equal the TOC (test_addon_version.lua).
local FALLBACK_VERSION = "5.4.1"
local function tocVersion()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(function()
        local v = get("ZenialCommunity", "Version")
        if type(v) == "string" and #v <= 32 and v:match("^%d+%.%d+%.%d+[%w%.%-]*$") then return v end
    end)
    return ok and value or nil
end
ZenialCommunity.ADDON_VERSION = tocVersion() or FALLBACK_VERSION
local L = {}; ZenialCommunity.Logic = L
L.VERSION, L.PREFIX, L.PREFIX3, L.DISCOVERY = 7, "ZENIALC1", "ZENIALC3", "HELLO2"
L.MAX_CONTACTS, L.MAX_BYTES, L.MAX_PARTS = 5000, 4096, 24
L.MAX_RECIPES_PER_PROFESSION, L.MAX_RECIPES = 2000, 12000
-- Opaque numeric request suffix: old clients still accept and echo the ID,
-- while updated responders may include the optional ingredients column.
function L.RecipeMaterialsRequested(id)return type(id)=="string"and id:match("^%d+%.%d+%.101$")~=nil end
L.PROFESSION_NAMES={[129]="Erste Hilfe",[164]="Schmiedekunst",[165]="Lederverarbeitung",[171]="Alchemie",[182]="Kräuterkunde",[185]="Kochkunst",[186]="Bergbau",[197]="Schneiderei",[202]="Ingenieurskunst",[333]="Verzauberkunst",[356]="Angeln",[393]="Kürschnerei",[755]="Juwelenschleifen",[773]="Inschriftenkunde"}
L.CLASS_DE = {WARRIOR="Krieger",PALADIN="Paladin",HUNTER="Jäger",ROGUE="Schurke",PRIEST="Priester",SHAMAN="Schamane",MAGE="Magier",WARLOCK="Hexenmeister",DRUID="Druide"}
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local APP_STATES={applied=true,invited=true,rejected=true,joined=true,withdrawn=true}
local STATE_ALIASES={applied="applied",invited="invited",rejected="rejected",joined="joined",withdrawn="withdrawn",beworben="applied",eingeladen="invited",abgelehnt="rejected",beigetreten="joined",["zurückgezogen"]="withdrawn"}
local ROLE_ALIASES={TANK="TANK",HEALER="HEALER",DAMAGER="DAMAGER",DPS="DAMAGER",DD="DAMAGER",Tank="TANK",Heiler="HEALER",Heal="HEALER"}
local ACTIVITY_ALIASES={
    ["Open-World-PvP"]="Open World PvP",["Kriegshymnenschlucht"]="Warsong Gulch",["Arathibecken"]="Arathi Basin",["Alteractal"]="Alterac Valley",
    ["Halle der Thanen"]="Hall of Thanes",["Ruinen von Lordaeron"]="Ruins of Lordaeron",["Ausgrabungsstätte"]="Excavation Site",["Stadt Dalaran"]="City of Dalaran",["Die versunkene Stadt"]="The Drowned City",["Gefängnis von Alcaz"]="Alcaz Prison",["Schwarzschlundfeste"]="Blackmaw Hold",["Terrasse des Formers"]="Shaper's Terrace",
    ["Ragefireabgrund"]="Ragefire Chasm",["Höhlen des Wehklagens"]="Wailing Caverns",["Die Todesminen"]="The Deadmines",["Burg Schattenfang"]="Shadowfang Keep",["Tiefschwarze Grotte"]="Blackfathom Deeps",["Das Verlies"]="The Stockade",["Kral der Klingenhauer"]="Razorfen Kraul",
    ["Scharlachrotes Kloster: Friedhof"]="Scarlet Monastery: Graveyard",["Scharlachrotes Kloster: Bibliothek"]="Scarlet Monastery: Library",["Scharlachrotes Kloster: Waffenkammer"]="Scarlet Monastery: Armory",["Scharlachrotes Kloster: Kathedrale"]="Scarlet Monastery: Cathedral",["Hügel der Klingenhauer"]="Razorfen Downs",
    ["Der Versunkene Tempel"]="Sunken Temple",["Blackrocktiefen"]="Blackrock Depths",["Düsterbruch: Ost"]="Dire Maul East",["Düsterbruch: Nord"]="Dire Maul North",["Düsterbruch: West"]="Dire Maul West",["Untere Schwarzfelsspitze"]="Lower Blackrock Spire",["Stratholme: Haupteingang"]="Stratholme: Main Gate",["Stratholme: Dienstboteneingang"]="Stratholme: Service Gate",["Obere Schwarzfelsspitze"]="Upper Blackrock Spire",
    ["Tiefengrabhügel"]="Deepgrove Tomb",["Hyjalgipfel"]="Mount Hyjal Summit",["Onyxias Hort"]="Onyxia's Lair",["Geschmolzener Kern"]="Molten Core",["Pechschwingenhort"]="Blackwing Lair",["Ruinen von Ahn'Qiraj"]="Ruins of Ahn'Qiraj",["Tempel von Ahn'Qiraj"]="Temple of Ahn'Qiraj"
}
L.Count=count
function L.PeerOnline(d,key,now)
    local peer=type(d)=="table"and type(d.peers)=="table"and d.peers[key]
    return peer and L.Int(peer.lastContact or -1,0,4102444800)and L.Int(now,0,4102444800)
        and peer.lastContact<=now and now-peer.lastContact<300 or false
end
function L.ScopeKey(name,realm,faction)
    local key=L.Identity(name)
    if not key or not L.Text(realm or"",64,true)or not L.Text(faction or"",16)then return nil end
    return string.lower((realm or""):gsub("%s+","")).."@"..string.lower(faction).."@"..key
end
function L.ValidIdentityKey(value)
    if L.Identity(value)then return true end
    if not L.Text(value,180)then return false end
    local realm,faction,name=value:match("^([^@]+)@([^@]+)@(.+)$")
    return realm~=nil and(faction=="alliance"or faction=="horde"or faction=="neutral")and L.Identity(name)~=nil
end
function L.ApplicationState(value)return STATE_ALIASES[value]end
-- peer.state is a language-neutral token; stored German/English display names from older versions map onto it.
local PEER_STATES={reached="reached",Erreicht="reached",Reached="reached",unreachable="unreachable",["Nicht erreichbar"]="unreachable",["Not reachable"]="unreachable",saved="saved",["Datenstand gespeichert"]="saved",["Saved data"]="saved"}
function L.PeerState(value)return type(value)=="string"and PEER_STATES[value]or nil end
function L.ApplicationCanAdvance(old,new)
    return old~=new and (old=="applied"and(new=="invited"or new=="rejected"or new=="joined")or old=="invited"and(new=="joined"or new=="rejected"))
end
function L.Role(value)return ROLE_ALIASES[value]end
function L.ActivityID(value)return ACTIVITY_ALIASES[value]or value end
function L.Text(v,max,empty) return type(v)=="string" and #v<=max and (empty or #v>0) and not v:find("[%z\1-\31\127|]") end
function L.Int(v,min,max) return type(v)=="number" and v==v and v>=min and v<=max and v==math.floor(v) end
local PROFESSION_ALIASES={FirstAid="Erste Hilfe",["First Aid"]="Erste Hilfe",Blacksmithing="Schmiedekunst",Leatherworking="Lederverarbeitung",Alchemy="Alchemie",Herbalism="Kräuterkunde",Cooking="Kochkunst",Kochen="Kochkunst",Mining="Bergbau",Tailoring="Schneiderei",Engineering="Ingenieurskunst",Enchanting="Verzauberkunst",Fishing="Angeln",Skinning="Kürschnerei",Jewelcrafting="Juwelenschleifen",Inscription="Inschriftenkunde"}
local PROFESSION_SEARCH={}
for alias,name in pairs(PROFESSION_ALIASES)do PROFESSION_SEARCH[name]=(PROFESSION_SEARCH[name]or name).." "..alias end
function L.ProfessionSearchText(value)local name=L.ProfessionName(value);return PROFESSION_SEARCH[name]or name or""end
function L.ProfessionName(value)
    if value=="Alchimie"then return"Alchemie"end
    return PROFESSION_ALIASES[value]or value
end
function L.ProfessionNameByID(id)return L.PROFESSION_NAMES[tonumber(id)]end
function L.Identity(name,realm)
    if not L.Text(name,113) then return nil end
    name=(name:match("^%s*(.-)%s*$")or""):gsub("%s+"," ")
    local base,suffix=name:match("^(.-)%-(.+)$");base=base or name
    base=base:match("^%s*(.-)%s*$")or""
    -- Forever has one megaserver and identifies characters as exactly two
    -- name segments. Some APIs still append a Retail-style realm suffix; it
    -- is transport metadata, never part of the identity or whisper target.
    local given,family=base:match("^([^%s;]+) ([^%s;]+)$")
    if given and family and #given<=24 and #family<=24 and L.Text(base,80) then
        return string.lower(base),base,""
    end
    -- Keep old Name-Realm values loadable for the 2.3.2 migration. New live
    -- identities never use this compatibility branch.
    local r=suffix or realm
    if not L.Text(base,48) or not L.Text(r,64) or base:find("[%s;]") or r:find("[;]") then return nil end
    r=r:gsub("%s","");if r=="" then return nil end
    return string.lower(base.."-"..r),base.."-"..r,r
end
function L.ClassName(value,token)
    if ZenialCommunity.Locale then return ZenialCommunity.Locale.Class(value,token)end
    return token or value or"Unknown"
end
function L.New()
    return {consent=true,autoDiscovery=true,visible=true,shareProfessions=true,shareGuild=true,shareQuests=true,community="",roles="",note="",professionNote="",availability="AUTO",rev=1,publicRev=1,seq=0,generation="",contacts={},peers={},blocked={},professions={},recipes={},recipeRev=1,recipeScan=0,recipeScans={},recipeStates={},recipeComplete=false,recipeResults={},recipeCatalogs={},lfg={},interests={},sentApplications={},quest=nil,questInterests={},sentQuestApplications={},applicationAlerts={group={},quest={}},groupFollows={},groupFollowSeen={},market={},tradeStore={drafts={},paused={},templates={},rules={},alertsSeen={}},groupTemplates={},favorites={},privateNotes={},craftOrders={},craftOrderOps={},craftOrderHistory={},scale=1,minimapAngle=225}
end
function L.ValidProfession(p) return type(p)=="table" and L.Int(p.id,1,100000) and L.Text(p.name,64) and L.Int(p.rank,0,10000) and L.Int(p.max,1,10000) and p.rank<=p.max end
function L.ValidRecipe(r) return type(r)=="table" and L.Int(r.id,1,10000000) and L.Int(r.itemID or 0,0,10000000) and L.Text(r.name,96) and L.Text(r.itemName or "",96,true) and L.Text(r.profession or "",64,true) and L.Text(r.materials or "",320,true) end
function L.ValidGroup(g,now,historical)
    return type(g)=="table" and L.Text(g.id,32) and g.id:match("^[%d%.]+$") and (g.mode=="LFG" or g.mode=="LFM") and L.Text(g.activity,64)
        and L.Int(g.min,1,100) and L.Int(g.max,g.min,100) and L.Text(g.have or "",64,true) and L.Text(g.note or "",96,true)
        and L.Int(g.start,0,4102444800) and L.Int(g.expires,1,4102444800) and L.Int(g.size,2,40) and L.Int(g.tank,0,10)
        and L.Int(g.healer,0,15) and L.Int(g.dd,0,40) and g.tank+g.healer+g.dd<=g.size and g.start<=g.expires
        and (historical or (g.expires>now and g.expires<=now+86400))
end
function L.ValidQuest(q,now,historical)
    return type(q)=="table" and L.Text(q.id,32) and q.id:match("^[%d%.]+$") and L.Int(q.questID or 0,0,10000000)
        and L.Text(q.title,96) and L.Text(q.zone or "",64,true) and L.Int(q.min,1,100) and L.Int(q.max,q.min,100)
        and L.Text(q.note or "",96,true) and L.Int(q.expires,1,4102444800) and (historical or (q.expires>now and q.expires<=now+7200))
end
function L.ValidOffer(o,now,historical)
    return type(o)=="table" and L.Text(o.id,32) and o.id:match("^[%d%.]+$") and (o.kind=="BUY" or o.kind=="SELL" or o.kind=="SERVICE")
        and L.Int(o.itemID or 0,0,10000000) and L.Text(o.name,96) and L.Int(o.quantity or 1,1,100000) and L.Int(o.price or 0,0,2147483646)
        and L.Text(o.note or "",96,true) and L.Int(o.expires,1,4102444800) and (historical or (o.expires>now and o.expires<=now+86400))
end
function L.ValidLocation(o,now,historical)
    return type(o)=="table" and L.Int(o.at,1,4102444800) and L.Int(o.mapID or 0,0,1000000)
        and L.Text(o.area or "",64,true) and L.Text(o.subzone or "",64,true)
        and (historical or o.at<=now+300)
end
function L.Touch(d) d.rev=math.min((d.rev or 1)+1,2147483646) end
function L.NextID(d,now) d.seq=math.min((d.seq or 0)+1,2147483646);return tostring(now).."."..tostring(d.seq) end

local function loadMemberPeer(p)
    if type(p)~="table"then return nil end
    local peer={state="saved",cap4=p.cap4==true or nil}
    -- Keep historical sightings separately from live presence. Session clocks,
    -- routes and verification must be established again after every login.
    local seen=0
    for _,field in ipairs({"memberSeenAt","lastContact","reportedAt"})do
        if L.Int(p[field],1,4102444800)then seen=math.max(seen,p[field])end
    end
    -- Legacy snapshots have no origin timestamp. Modern relayed bundles do:
    -- their local arrival time must never renew the owner's visible lifetime.
    if not p.cap4 and L.Int(p.received,1,4102444800)then seen=math.max(seen,p.received)end
    if seen>0 then peer.memberSeenAt=seen end
    if type(p.wire)=="string"and L.Int(p.received,0,4102444800)then
        local s=L.Decode(p.wire,0,true)
        if s and(s.kind=="S3"or s.kind=="S")then
            peer.data,peer.wire,peer.received,peer.cap3=s,p.wire,p.received,s.kind=="S3"
            if type(p.data)=="table"and p.data.publicOnly==true then s.publicOnly=true end
        end
    end
    -- A presence announcement is enough to remember a member; opening their
    -- full profile must not be required for them to survive /reload.
    local presence=p.presence;local own=ZenialCommunity.me
    if not peer.data and own and type(presence)=="table"and L.Text(presence.classFile,16,true)and L.Int(presence.level,0,100)then
        local d=L.New();d.roles=L.Role(presence.role)or""
        d.rev=L.Int(presence.rev,1,2147483646)and presence.rev or 1
        d.recipeRev=L.Int(presence.recipeRev,1,2147483646)and presence.recipeRev or 1
        d.generation=L.Text(p.session,32,true)and p.session or""
        local ids={}
        for _,id in ipairs(type(presence.professionIDs)=="table"and presence.professionIDs or{})do
            local name=L.Int(id,1,100000)and L.ProfessionNameByID(id)
            if name and not ids[id]and#d.professions<6 then ids[id]=true;d.professions[#d.professions+1]={id=id,name=name,rank=0,max=1}end
        end
        local s=L.Snapshot(d,{faction=own.faction,class="",classFile=presence.classFile,level=presence.level,guild="",guid=""},{main="",alts={},version=0})
        local wire=L.Encode(s);s=wire and L.Decode(wire,0,true)
        if s then s.publicOnly=true;peer.data,peer.wire,peer.received,peer.cap3=s,wire,seen,true end
    end
    if L.ValidLocation(p.location,0,true)then peer.location={at=p.location.at,mapID=p.location.mapID or 0,area=p.location.area or"",subzone=p.location.subzone or""}end
    return peer
end
function L.Load(raw)
    local d=L.New();if type(raw)~="table" then return d end
    -- Community connection, discovery, guild and quest sharing are always enabled
    -- in the normal configuration. Migrate former off switches when loading.
    for _,k in ipairs({"visible","shareProfessions","minimapHidden"}) do if type(raw[k])=="boolean" then d[k]=raw[k] end end
    for _,k in ipairs({"community","note","professionNote","generation"}) do local max=k=="community" and 32 or (k=="generation" and 32 or 64);if L.Text(raw[k],max,true) then d[k]=raw[k] end end
    if raw.availability=="AUTO"or raw.availability=="AVAILABLE"or raw.availability=="BUSY"then d.availability=raw.availability end
    d.roles=L.Role(raw.roles)or""
    for _,k in ipairs({"rev","publicRev","seq","recipeRev","recipeScan"}) do local max=k=="recipeScan" and 4102444800 or 2147483646;if L.Int(raw[k],0,max) then d[k]=raw[k] end end
    if d.rev<1 then d.rev=1 end;if d.recipeRev<1 then d.recipeRev=1 end;if type(raw.recipeComplete)=="boolean" then d.recipeComplete=raw.recipeComplete end
    -- Startup acknowledgements are local character preferences, never public data.
    d.networkSetupSeen=raw.networkSetupSeen==true
    d.betaUnsupportedNoticeSeen=raw.betaUnsupportedNoticeSeen==true
    if raw.companionIntroductionMajor==5 then d.companionIntroductionMajor=5 end
    if type(raw.scale)=="number" and raw.scale>=.65 and raw.scale<=1.4 then d.scale=raw.scale end
    if type(raw.minimapAngle)=="number" and raw.minimapAngle>=-360 and raw.minimapAngle<=360 then d.minimapAngle=raw.minimapAngle end
    if type(raw.position)=="table" and L.Int(raw.position.x,-10000,10000) and L.Int(raw.position.y,-10000,10000) then d.position={x=raw.position.x,y=raw.position.y} end
    if type(raw.blocked)=="table" then for k,v in pairs(raw.blocked) do if v==true and L.ValidIdentityKey(k) then d.blocked[k]=true end end end
    if type(raw.contacts)=="table" then for _,c in pairs(raw.contacts) do if count(d.contacts)>=L.MAX_CONTACTS then break end;if type(c)=="table" then local key=L.Contact(d,c.target,c.origin,c.confirmed);if key then d.contacts[key].automatic=c.automatic==true;if ZenialCommunity.me and key==ZenialCommunity.me.key then d.contacts[key]=nil end end end end end
    if type(raw.groupFollows)=="table" then for activity,enabled in pairs(raw.groupFollows) do if count(d.groupFollows)>=64 then break end;if enabled==true and L.Text(activity,64) then d.groupFollows[L.ActivityID(activity)]=true end end end
    if type(raw.groupFollowSeen)=="table" then for key,id in pairs(raw.groupFollowSeen) do if count(d.groupFollowSeen)>=L.MAX_CONTACTS then break end;if d.contacts[key] and L.Text(id,32) and id:match("^[%d%.]+$") then d.groupFollowSeen[key]=id end end end
    if type(raw.professions)=="table" then local seenIDs,byName={},{};for _,p in ipairs(raw.professions) do local name=type(p)=="table"and L.ProfessionName(p.name);local normalized=type(p)=="table"and{id=p.id,name=name,rank=p.rank,max=p.max};if #d.professions<6 and L.ValidProfession(normalized) then local key=string.lower(normalized.name);local old=byName[key];if not seenIDs[normalized.id]and not old then d.professions[#d.professions+1]=normalized;seenIDs[normalized.id]=true;byName[key]=normalized elseif old and(normalized.rank>old.rank or normalized.rank==old.rank and normalized.max>old.max)then old.id,old.rank,old.max=normalized.id,normalized.rank,normalized.max;seenIDs[normalized.id]=true end end end end
    if type(raw.recipes)=="table" then local professionCounts={};for _,r in ipairs(raw.recipes) do if #d.recipes<L.MAX_RECIPES and type(r)=="table"then local row={id=r.id,itemID=r.itemID or 0,name=r.name,itemName=r.itemName or"",profession=L.ProfessionName(r.profession or""),materials=r.materials or""};local n=professionCounts[row.profession]or 0;if n<L.MAX_RECIPES_PER_PROFESSION and L.ValidRecipe(row)then d.recipes[#d.recipes+1]=row;professionCounts[row.profession]=n+1 end end end end
    if type(raw.recipeScans)=="table"then for name,at in pairs(raw.recipeScans)do name=L.ProfessionName(name);if L.Text(name,64)and L.Int(at,1,4102444800)then d.recipeScans[name]=at end end end
    if type(raw.recipeStates)=="table"then for name,state in pairs(raw.recipeStates)do name=L.ProfessionName(name);if L.Text(name,64)and type(state)=="table"then d.recipeStates[name]={complete=state.complete==true,at=L.Int(state.at or 0,0,4102444800)and state.at or 0,fullAt=L.Int(state.fullAt or 0,0,4102444800)and state.fullAt or 0,count=L.Int(state.count or 0,0,L.MAX_RECIPES_PER_PROFESSION)and state.count or 0,message=L.Text(state.message or"",192,true)and state.message or""}end end end
    if type(raw.lfg)=="table" then for i=#raw.lfg,1,-1 do local g=raw.lfg[i];if type(g)=="table" then g.activity=L.ActivityID(g.activity);g.size,g.tank,g.healer,g.dd=g.size or 5,g.tank or 1,g.healer or 1,g.dd or 3;if L.ValidGroup(g,0,true) then d.lfg[1]=g;break end end end end
    if L.ValidQuest(raw.quest,0,true) then d.quest=raw.quest end
    if type(raw.market)=="table" then for _,o in ipairs(raw.market) do if #d.market<3 and L.ValidOffer(o,0,true) then d.market[#d.market+1]=o end end end
    local function loadApplications(source,withRole)
        local out={};if type(source)~="table" then return out end
        for id,people in pairs(source) do if L.Text(id,32) and id:match("^[%d%.]+$") and type(people)=="table" then local saved={};out[id]=saved
            for key,row in pairs(people) do local state=type(row)=="table"and L.ApplicationState(row.state);local role=type(row)=="table"and L.Role(row.role);if count(saved)<40 and d.contacts[key] and state and APP_STATES[state] and L.Int(row.at or 0,0,4102444800) and L.Text(row.note or"",64,true) and (not withRole or role) then saved[key]={state=state,at=row.at or 0,note=row.note or"",role=withRole and role or nil} end end
            if not next(saved) then out[id]=nil end
        end end;return out
    end
    d.interests=loadApplications(raw.interests,true);d.sentApplications=loadApplications(raw.sentApplications,false);d.questInterests=loadApplications(raw.questInterests,false);d.sentQuestApplications=loadApplications(raw.sentQuestApplications,false)
    -- Search results are ephemeral. A new search rebuilds them, and no malformed
    -- or stale saved reply should survive into an active query.
    d.recipeResults={}
    if type(raw.applicationAlerts)=="table" then
        for _,kind in ipairs({"group","quest"}) do
            local source=raw.applicationAlerts[kind]
            if type(source)=="table" then for id,people in pairs(source) do
                if L.Text(id,32) and id:match("^[%d%.]+$") and type(people)=="table" then
                    local saved={};d.applicationAlerts[kind][id]=saved
                    for key,a in pairs(people) do if count(saved)<40 and d.contacts[key] and type(a)=="table" then saved[key]={unread=a.unread==true,notified=a.notified==true} end end
                end
            end end
        end
    end
    if type(raw.peers)=="table"then for k,p in pairs(raw.peers)do if d.contacts[k]and not d.blocked[k]then d.peers[k]=loadMemberPeer(p)end end end
    -- SessionPlans.Initialize validates only this named private store after load;
    -- passing future schemas through here preserves them without interpreting them.
    if raw.sessionPlans~=nil then d.sessionPlans=raw.sessionPlans end
    -- The private planner owns validation and preserves unsupported schemas.
    if raw.materialPlans~=nil then d.materialPlans=raw.materialPlans end
    if raw.scheduledGroups~=nil then d.scheduledGroups=raw.scheduledGroups end
    for _,name in ipairs({"tradeStore","favorites","privateNotes","craftOrders","craftOrderOps","craftOrderHistory"})do if type(raw[name])=="table"then d[name]=raw[name]end end
    if type(raw.groupTemplates)=="table"then d.groupTemplates=raw.groupTemplates end
    return d
end
function L.MergeRecipes(existing,scanned,profession,additive,allowEmpty)
    profession=L.ProfessionName(profession)
    if not L.Text(profession,64)or type(scanned)~="table"then return nil end
    local incoming,seen={},{}
    for _,r in ipairs(scanned)do if type(r)=="table"then local row={id=r.id,itemID=r.itemID or 0,name=r.name,itemName=r.itemName or"",profession=profession,materials=r.materials or""};if L.ValidRecipe(row)and not seen[row.id]then incoming[#incoming+1]=row;seen[row.id]=true end end end
    if #incoming==0 and(not allowEmpty or next(scanned)~=nil)then return nil end
    local out={};local professionCount=0
    for _,r in ipairs(type(existing)=="table"and existing or{})do
        local oldProfession=L.ProfessionName(type(r)=="table"and(r.profession or"")or"")
        local keep=oldProfession~=""and(oldProfession~=profession or additive==true)
        if keep and not seen[r.id]and L.ValidRecipe(r)and#out<L.MAX_RECIPES then out[#out+1]={id=r.id,itemID=r.itemID or 0,name=r.name,itemName=r.itemName or"",profession=oldProfession,materials=r.materials or""};seen[r.id]=true;if oldProfession==profession then professionCount=professionCount+1 end end
    end
    for _,r in ipairs(incoming)do if#out<L.MAX_RECIPES and professionCount<L.MAX_RECIPES_PER_PROFESSION then out[#out+1]=r;professionCount=professionCount+1 end end
    table.sort(out,function(a,b)if a.profession==b.profession then return a.name<b.name end;return a.profession<b.profession end)
    return out
end
function L.Contact(d,target,origin,confirmed,realm,faction)
    local own=ZenialCommunity and ZenialCommunity.me;realm=realm or(own and own.realm);faction=faction or(own and own.faction)
    local legacy,full=L.Identity(target,realm);local key=faction and L.ScopeKey(full,realm,faction)or legacy;if not key or not L.Text(origin,80) then return nil,"Vollständiger Charaktername und Herkunft erforderlich." end
    if d.blocked[key] then return nil,"Spieler ist blockiert." end;if not d.contacts[key] and count(d.contacts)>=L.MAX_CONTACTS then return nil,"Maximal 5.000 Kontakte." end
    d.contacts[key]={target=full,origin=origin,confirmed=confirmed==true};return key
end
function L.Discover(d,target,realm,source,now,faction)
    local own=ZenialCommunity and ZenialCommunity.me;realm=realm or(own and own.realm);faction=faction or(own and own.faction)
    local legacy,full=L.Identity(target,realm);local key=faction and L.ScopeKey(full,realm,faction)or legacy;if not key or d.blocked[key]or own and key==own.key then return nil end
    if not d.contacts[key] and count(d.contacts)>=L.MAX_CONTACTS then
        local protected={};for _,order in pairs(d.craftOrders or{})do if type(order)=="table"and order.peer then protected[order.peer]=true end end
        local scheduled=d.scheduledGroups
        if type(scheduled)=="table"and scheduled.version==1 then
            local inspected=0
            for _,event in pairs(type(scheduled.owned)=="table"and scheduled.owned or{})do
                inspected=inspected+1;if inspected>100 then break end
                if type(event)=="table"and event.status=="OPEN"and type(event.participants)=="table"then
                    local people=0;for peer,application in pairs(event.participants)do people=people+1;if people>40 then break end
                        if L.ValidIdentityKey(peer)and type(application)=="table"and(application.state=="REQUESTED"or application.state=="CONFIRMED"or application.state=="WAITLIST")then protected[peer]=true end
                    end
                end
            end
            inspected=0;for _,following in pairs(type(scheduled.following)=="table"and scheduled.following or{})do
                inspected=inspected+1;if inspected>100 then break end
                if type(following)=="table"and L.ValidIdentityKey(following.ownerKey)and(following.pending or following.state=="REQUESTED"or following.state=="CONFIRMED"or following.state=="WAITLIST")then protected[following.ownerKey]=true end
            end
        end
        local oldest,oldestAt;for candidate,contact in pairs(d.contacts)do local peer=d.peers[candidate];local at=peer and(peer.lastContact or peer.received)or 0;local offline=not peer or not peer.lastContact or type(now)=="number"and peer.lastContact<=now-300;if contact.automatic and offline and not(d.favorites and d.favorites[candidate])and not(d.privateNotes and d.privateNotes[candidate])and not(d.privateCategories and d.privateCategories[candidate])and not protected[candidate]and(not oldestAt or at<oldestAt)then oldest,oldestAt=candidate,at end end
        if not oldest then return nil end;d.contacts[oldest]=nil;d.peers[oldest]=nil
    end;local added=d.contacts[key]==nil
    if added then d.contacts[key]={target=full,origin="Automatisch entdeckt",automatic=true,confirmed=false} end;return key,added
end
function L.Block(d,key)
    if not L.ValidIdentityKey(key) then return false end;d.blocked[key]=true;d.contacts[key]=nil;d.peers[key]=nil
    d.groupFollowSeen[key]=nil
    for _,bucket in ipairs({d.interests,d.questInterests,d.sentApplications,d.sentQuestApplications,d.applicationAlerts.group,d.applicationAlerts.quest}) do for _,people in pairs(bucket) do if type(people)=="table" then people[key]=nil end end end;L.Touch(d);return true
end
function L.SaveGroup(d,g,now)
    L.Expire(d,now);if not g.id or g.id=="" then g.id=L.NextID(d,now) end;if not L.ValidGroup(g,now) then return nil,"Gruppenangaben ungültig." end
    if d.lfg[1] and d.lfg[1].id~=g.id then return nil,"Du hast bereits eine aktive Gruppe." end;d.lfg[1]=g;L.Touch(d);return g.id
end
function L.CloseGroup(d,id) if d.lfg[1] and d.lfg[1].id==id then d.lfg={};d.interests[id]=nil;d.applicationAlerts.group[id]=nil;L.Touch(d);return true end end
function L.SaveQuest(d,q,now)
    L.Expire(d,now);if not q.id or q.id=="" then q.id=L.NextID(d,now) end;if not L.ValidQuest(q,now) then return nil,"Questanfrage ungültig." end
    if d.quest and d.quest.id~=q.id then return nil,"Du hast bereits eine aktive Questanfrage." end;d.quest=q;L.Touch(d);return q.id
end
function L.CloseQuest(d,id) if d.quest and d.quest.id==id then d.quest=nil;d.questInterests[id]=nil;d.applicationAlerts.quest[id]=nil;L.Touch(d);return true end end
function L.SaveOffer(d,o,now)
    L.Expire(d,now);if not o.id or o.id=="" then o.id=L.NextID(d,now) end;if not L.ValidOffer(o,now) then return nil,"Angebot ungültig." end
    for i,old in ipairs(d.market) do if old.id==o.id then d.market[i]=o;L.Touch(d);return o.id end end
    if #d.market>=3 then return nil,"Maximal drei aktive Handelseinträge." end;d.market[#d.market+1]=o;L.Touch(d);return o.id
end
function L.CloseOffer(d,id) for i,o in ipairs(d.market) do if o.id==id then table.remove(d.market,i);L.Touch(d);return true end end end
function L.Expire(d,now)
    if not L.Int(now,0,4102444800) then return false end;local changed=false
    if d.lfg[1] and d.lfg[1].expires<=now then local id=d.lfg[1].id;d.interests[id]=nil;d.applicationAlerts.group[id]=nil;d.lfg={};changed=true end
    if d.quest and d.quest.expires<=now then local id=d.quest.id;d.questInterests[id]=nil;d.applicationAlerts.quest[id]=nil;d.quest=nil;changed=true end
    for i=#d.market,1,-1 do if d.market[i].expires<=now then table.remove(d.market,i);changed=true end end
    local groupID=d.lfg[1] and d.lfg[1].id;for id in pairs(d.interests) do if id~=groupID then d.interests[id]=nil;d.applicationAlerts.group[id]=nil;changed=true end end
    local questID=d.quest and d.quest.id;for id in pairs(d.questInterests) do if id~=questID then d.questInterests[id]=nil;d.applicationAlerts.quest[id]=nil;changed=true end end
    for _,spec in ipairs({{d.sentApplications,86400},{d.sentQuestApplications,7200}}) do for id,people in pairs(spec[1]) do for key,row in pairs(people) do if type(row)~="table"or not row.at or row.at+spec[2]<now or d.blocked[key]then people[key]=nil;changed=true end end;if not next(people)then spec[1][id]=nil end end end
    for qid,byPeer in pairs(d.recipeResults) do for key,row in pairs(byPeer) do if not row.at or row.at+600<now then byPeer[key]=nil end end;if not next(byPeer) then d.recipeResults[qid]=nil end end
    for key,byProfession in pairs(d.recipeCatalogs or{})do for profession,row in pairs(byProfession)do if not row.at or row.at+600<now then byProfession[profession]=nil end end;if not next(byProfession)then d.recipeCatalogs[key]=nil end end
    if changed then L.Touch(d) end;return changed
end

local function escape(s) return (tostring(s):gsub("%%","%%25"):gsub("\t","%%09"):gsub("\n","%%0A"):gsub("\r","%%0D"):gsub("|","%%7C")) end
local function fields(s)
    if type(s)~="string" or #s>L.MAX_BYTES or s:find("[%z\1-\8\10-\31\127|]") then return nil end;local t={}
    for f in (s.."\t"):gmatch("([^\t]*)\t") do if #t>=260 or f:gsub("%%[%x][%x]",""):find("%%") then return nil end;local bad=false
        f=f:gsub("%%(%x%x)",function(h) if h~="25" and h~="09" and h~="0A" and h~="0D" and h~="7C" then bad=true end;return string.char(tonumber(h,16)) end);if bad then return nil end;t[#t+1]=f end
    return t
end
function L.Encode(s)
    local t={s.kind};local function put(...) for i=1,select("#",...) do t[#t+1]=escape(select(i,...)) end end
    if s.kind=="A" then put(s.id)
    elseif s.kind=="Q" or s.kind=="Q3" then put(s.rev or 0)
    elseif s.kind=="GA" then put(s.id,s.role,s.note or "")
    elseif s.kind=="GW" or s.kind=="QW" then put(s.id)
    elseif s.kind=="GS" or s.kind=="QS" then put(s.id,s.state)
    elseif s.kind=="QA" then put(s.id,s.note or "")
    elseif s.kind=="RQ" then put(s.id,s.query)
    elseif s.kind=="RS" then put(s.id,#s.results);for _,r in ipairs(s.results) do put(r.id,r.itemID or 0,r.profession or "",r.name,r.itemName or "",r.materials or "") end
    elseif s.kind=="CQ" then put(s.id,s.profession,s.offset or 0)
    elseif s.kind=="CS" then
        put(s.id,s.profession,s.offset or 0,s.total or 0,#s.results)
        local materials=L.RecipeMaterialsRequested(s.id)
        for _,r in ipairs(s.results)do put(r.id,r.itemID or 0,r.name,r.itemName or"");if materials then put(r.materials or"")end end
    elseif s.kind=="L1" then put(s.at,s.faction,s.mapID or 0,s.area or "",s.subzone or "")
    elseif s.kind=="H1R" then put(s.enabled and 1 or 0,s.scope or "all",s.mapID or 0)
    elseif s.kind=="H1A" or s.kind=="H1D" or s.kind=="H1X" then put(s.id)
    elseif s.kind=="H1J" then put(s.id,s.state)
    elseif s.kind=="H1C" or s.kind=="H1U" then put(s.id,s.rev,s.at,s.expires,s.mapID or 0,s.area or "",s.subzone or "",s.hasPos and 1 or 0,s.x or 0,s.y or 0)
    elseif s.kind=="H1I" then put(s.id,s.rev,s.note or "",s.hasEnemy and 1 or 0,s.enemyName or "",s.enemyClass or "",s.enemyLevel or 0,s.enemyFaction or "")
    elseif s.kind=="H2I" then
        put(s.id,s.rev,s.note or "",s.truncated and 1 or 0,#s.deaths)
        for _,d in ipairs(s.deaths) do
            put(d.at,d.mapID or 0,d.area or "",d.subzone or "",d.minAttackers or 1,d.killerFirst and 1 or 0,#d.attackers)
            for _,a in ipairs(d.attackers) do put(a.name,a.classFile or "",a.race or "",a.level or 0) end
        end
    elseif s.kind=="S" then put(s.rev,s.community,s.faction,s.class,s.level,s.guild,s.guid,s.roles,s.note,s.professionNote,#s.professions);for _,p in ipairs(s.professions) do put(p.id,p.name,p.rank,p.max) end;put(#s.lfg);for _,g in ipairs(s.lfg) do put(g.id,g.mode,g.activity,g.min,g.max,g.have,g.want or "",g.start,g.expires,g.note) end
    elseif s.kind=="S3" then
        put(s.rev,s.generation,s.community,s.faction,s.class,s.classFile,s.level,s.guild,s.guid,s.roles,s.note,s.professionNote,#s.professions);for _,p in ipairs(s.professions) do put(p.id,p.name,p.rank,p.max) end
        put(s.group and 1 or 0);if s.group then local g=s.group;put(g.id,g.mode,g.activity,g.min,g.max,g.have,g.start,g.expires,g.note,g.size,g.tank,g.healer,g.dd) end
        put(s.quest and 1 or 0);if s.quest then local q=s.quest;put(q.id,q.questID,q.title,q.zone,q.min,q.max,q.note,q.expires) end
        put(#s.market);for _,o in ipairs(s.market) do put(o.id,o.kind,o.itemID,o.name,o.quantity,o.price,o.note,o.expires) end
        put(s.linkMain or "",s.linkVersion or 0,#(s.linkAlts or {}));for _,v in ipairs(s.linkAlts or {}) do put(v) end;put(s.recipeRev or 0,s.recipeCount or 0,s.recipeScan or 0)
    else return nil end
    local wire=table.concat(t,"\t");if #wire>L.MAX_BYTES then return nil end;return wire
end
function L.Decode(wire,now,historical)
    local f=fields(wire);if not f then return nil end;local s={kind=f[1]};local at=2
    local function str(max,empty) local v=f[at];at=at+1;if L.Text(v,max,empty) then return v end end
    local function num(min,max) local v=f[at];at=at+1;if not v or not v:match("^%d+$") or #v>10 then return nil end;v=tonumber(v);if L.Int(v,min,max) then return v end end
    if s.kind=="A" then s.id=str(32)
    elseif s.kind=="Q" or s.kind=="Q3" then s.rev=num(0,2147483646)
    elseif s.kind=="GA" then s.id=str(32);s.role=L.Role(str(8));s.note=str(64,true);if not s.role then return nil end
    elseif s.kind=="GW" or s.kind=="QW" then s.id=str(32)
    elseif s.kind=="GS" or s.kind=="QS" then s.id=str(32);s.state=L.ApplicationState(str(12));if s.state~="invited" and s.state~="rejected" and s.state~="joined" then return nil end
    elseif s.kind=="QA" then s.id=str(32);s.note=str(64,true)
    elseif s.kind=="RQ" then s.id=str(32);s.query=str(64)
    elseif s.kind=="RS" then s.id=str(32);local n=num(0,8);if not n then return nil end;s.results={};local seen={};for i=1,n do local r={id=num(1,10000000),itemID=num(0,10000000),profession=str(64,true),name=str(96),itemName=str(96,true),materials=str(320,true)};if not L.ValidRecipe(r) or seen[r.id] then return nil end;seen[r.id]=true;s.results[i]=r end
    elseif s.kind=="CQ" then s.id=str(32);s.profession=L.ProfessionName(str(64));s.offset=num(0,L.MAX_RECIPES_PER_PROFESSION);if not s.profession or s.profession==""or s.offset==nil then return nil end
    elseif s.kind=="CS" then
        s.id=str(32);s.profession=L.ProfessionName(str(64));s.offset=num(0,L.MAX_RECIPES_PER_PROFESSION);s.total=num(0,L.MAX_RECIPES_PER_PROFESSION);local n=num(0,16)
        if not(s.id and s.profession and s.profession~=""and s.offset and s.total and n)or s.offset+n>s.total then return nil end
        local withMaterials=L.RecipeMaterialsRequested(s.id)and #f-at+1==n*5
        if #f-at+1~=n*4 and not withMaterials then return nil end
        s.results={};local seen={};for i=1,n do
            local r={id=num(1,10000000),itemID=num(0,10000000),profession=s.profession,name=str(96),itemName=str(96,true),materials=""}
            if withMaterials then r.materials=str(320,true);if r.materials==nil then return nil end end
            if not L.ValidRecipe(r)or seen[r.id]then return nil end;seen[r.id]=true;s.results[i]=r
        end
    elseif s.kind=="L1" then s.at,s.faction,s.mapID=num(1,4102444800),str(16),num(0,1000000);s.area,s.subzone=str(64,true),str(64,true);if not L.ValidLocation(s,now,historical)or(s.faction~="Alliance"and s.faction~="Horde"and s.faction~="Neutral")then return nil end
    elseif s.kind=="H1R" then local enabled=num(0,1);s.scope=str(4);s.mapID=num(0,1000000);if enabled==nil or (s.scope~="all" and s.scope~="zone") or not s.mapID then return nil end;s.enabled=enabled==1
    elseif s.kind=="H1A" or s.kind=="H1D" or s.kind=="H1X" then s.id=str(32)
    elseif s.kind=="H1J" then s.id=str(32);s.state=str(9);if s.state~="coming" and s.state~="withdrawn" then return nil end
    elseif s.kind=="H1C" or s.kind=="H1U" then
        s.id,s.rev,s.at,s.expires,s.mapID=str(32),num(1,2147483646),num(1,4102444800),num(1,4102444800),num(0,1000000);s.area,s.subzone=str(64,true),str(64,true);local hasPos=num(0,1);s.x,s.y=num(0,10000),num(0,10000)
        if not (s.id and s.rev and s.at and s.expires and s.mapID and s.area and s.subzone and hasPos~=nil and s.x and s.y) or s.at>s.expires or (not historical and (s.expires<=now or s.expires>now+600)) then return nil end;s.hasPos=hasPos==1
    elseif s.kind=="H1I" then
        s.id,s.rev,s.note=str(32),num(1,2147483646),str(96,true);local hasEnemy=num(0,1);s.enemyName,s.enemyClass=str(113,true),str(24,true);s.enemyLevel,s.enemyFaction=num(0,100),str(16,true)
        if not (s.id and s.rev and s.note and hasEnemy~=nil and s.enemyName and s.enemyClass and s.enemyLevel and s.enemyFaction) then return nil end;s.hasEnemy=hasEnemy==1
    elseif s.kind=="H2I" then
        -- Versioned PvP kill log: up to 8 deaths with up to 5 attackers each; level 0 on the wire is "unknown".
        s.id,s.rev,s.note=str(32),num(1,2147483646),str(96,true);local truncated,n=num(0,1),num(0,8)
        if not (s.id and s.rev and s.note and truncated~=nil and n) then return nil end;s.truncated=truncated==1;s.deaths={}
        for i=1,n do
            local d={at=num(1,4102444800),mapID=num(0,1000000),area=str(64,true),subzone=str(64,true),minAttackers=num(1,40)};local killerFirst,m=num(0,1),num(0,5)
            if not (d.at and d.mapID and d.area and d.subzone and d.minAttackers and killerFirst~=nil and m) then return nil end
            d.attackers={}
            for j=1,m do
                local a={name=str(80),classFile=str(16,true),race=str(24,true),level=num(0,100)}
                if not (a.name and a.classFile and a.race and a.level) or (a.classFile~="" and not a.classFile:match("^[A-Z_]+$")) then return nil end
                if a.level==0 then a.level=nil end;d.attackers[j]=a
            end
            if killerFirst==1 then if m<1 then return nil end;d.killer=d.attackers[1] end
            d.minAttackers=math.max(d.minAttackers,m);d.id=d.at.."."..i;d.cause,d.confirmed,d.hasPos="player",true,false;s.deaths[i]=d
        end
    elseif s.kind=="S" then
        s.rev,s.community,s.faction,s.class,s.level=num(1,2147483646),str(32,true),str(16),str(24,true),num(0,100);s.guild,s.guid,s.roles,s.note,s.professionNote=str(64,true),str(80,true),str(64,true),str(64,true),str(64,true);s.roles=L.Role(s.roles)or""
        local n=num(0,6);if not (s.rev and s.faction and n) then return nil end;s.professions={};local seenIDs,byName={},{};for i=1,n do local p={id=num(1,100000),name=str(64),rank=num(0,10000),max=num(1,10000)};if not L.ValidProfession(p) then return nil end;local key=string.lower(p.name);local old=byName[key];if not seenIDs[p.id]and not old then s.professions[#s.professions+1]=p;seenIDs[p.id]=true;byName[key]=p elseif old and(p.rank>old.rank or p.rank==old.rank and p.max>old.max)then old.id,old.rank,old.max=p.id,p.rank,p.max;seenIDs[p.id]=true end end
        n=num(0,3);if not n then return nil end;s.lfg={};for i=1,n do local g={id=str(32),mode=str(3),activity=L.ActivityID(str(64)),min=num(1,100),max=num(1,100),have=str(32,true),want=str(32,true),start=num(0,4102444800),expires=num(1,4102444800),note=str(96,true),size=5,tank=1,healer=1,dd=3};if L.ValidGroup(g,now,true) and #s.lfg==0 then s.lfg[1]=g end end
    elseif s.kind=="S3" then
        s.rev,s.generation,s.community,s.faction=num(1,2147483646),str(32,true),str(32,true),str(16);s.class,s.classFile,s.level,s.guild,s.guid=str(24,true),str(16,true),num(0,100),str(64,true),str(80,true);s.roles,s.note,s.professionNote=str(64,true),str(64,true),str(64,true);s.roles=L.Role(s.roles)or""
        local n=num(0,6);if not (s.rev and s.generation and s.faction and s.class and s.classFile and n) then return nil end;if s.faction~="Alliance" and s.faction~="Horde" and s.faction~="Neutral" then return nil end
        s.professions={};local seenIDs,byName={},{};for i=1,n do local p={id=num(1,100000),name=str(64),rank=num(0,10000),max=num(1,10000)};if not L.ValidProfession(p) then return nil end;local key=string.lower(p.name);local old=byName[key];if not seenIDs[p.id]and not old then s.professions[#s.professions+1]=p;seenIDs[p.id]=true;byName[key]=p elseif old and(p.rank>old.rank or p.rank==old.rank and p.max>old.max)then old.id,old.rank,old.max=p.id,p.rank,p.max;seenIDs[p.id]=true end end
        local present=num(0,1);if not present then return nil end;if present==1 then local g={id=str(32),mode=str(3),activity=L.ActivityID(str(64)),min=num(1,100),max=num(1,100),have=str(64,true),start=num(0,4102444800),expires=num(1,4102444800),note=str(96,true),size=num(2,40),tank=num(0,10),healer=num(0,15),dd=num(0,40)};if not L.ValidGroup(g,now,true) or (not historical and g.expires>now+86400) then return nil end;s.group=g end
        present=num(0,1);if not present then return nil end;if present==1 then local q={id=str(32),questID=num(0,10000000),title=str(96),zone=str(64,true),min=num(1,100),max=num(1,100),note=str(96,true),expires=num(1,4102444800)};if not L.ValidQuest(q,now,true) or (not historical and q.expires>now+7200) then return nil end;s.quest=q end
        n=num(0,3);if not n then return nil end;s.market={};seen={};for i=1,n do local o={id=str(32),kind=str(8),itemID=num(0,10000000),name=str(96),quantity=num(1,100000),price=num(0,2147483646),note=str(96,true),expires=num(1,4102444800)};if not L.ValidOffer(o,now,true) or seen[o.id] or (not historical and o.expires>now+86400) then return nil end;seen[o.id]=true;s.market[i]=o end
        s.linkMain=str(113,true);if s.linkMain~="" and not L.Identity(s.linkMain) then return nil end;s.linkVersion=num(0,2147483646);n=num(0,10);if not (s.linkVersion and n) then return nil end;s.linkAlts={};seen={}
        for i=1,n do local v=str(113);if not v or not L.Identity(v) or seen[string.lower(v)] then return nil end;seen[string.lower(v)]=true;s.linkAlts[i]=v end
        s.recipeRev,s.recipeCount,s.recipeScan=num(0,2147483646),num(0,L.MAX_RECIPES),num(0,4102444800);if not (s.recipeRev and s.recipeCount and s.recipeScan) then return nil end
    else return nil end
    if not s.id and (s.kind=="A" or s.kind=="GA" or s.kind=="GW" or s.kind=="GS" or s.kind=="QA" or s.kind=="QW" or s.kind=="QS" or s.kind=="RQ" or s.kind=="RS" or s.kind=="CQ" or s.kind=="CS" or s.kind=="H1A" or s.kind=="H1D" or s.kind=="H1X" or s.kind=="H1J" or s.kind=="H1C" or s.kind=="H1U" or s.kind=="H1I" or s.kind=="H2I") then return nil end
    if s.id and not s.id:match("^[%d%.]+$") then return nil end;if at~=#f+1 then return nil end;return s
end
-- Fits a kill log into one H2I message: newest deaths first, killer kept first, at most 8 deaths and 5 attackers each.
-- Whatever has to be cut to respect L.MAX_BYTES is marked with the truncated flag. Returns nil if even one death does not fit.
function L.FitH2I(s)
    local deaths,truncated={},false
    for i,d in ipairs(s.deaths or {}) do
        if i>8 then truncated=true;break end
        local list={};local killer=d.killer
        if killer then list[1]=killer end
        for _,a in ipairs(d.attackers or {}) do if not (killer and a.name==killer.name) then list[#list+1]=a end end
        if #list>5 then truncated=true;while #list>5 do table.remove(list) end end
        deaths[#deaths+1]={at=d.at,mapID=d.mapID,area=d.area,subzone=d.subzone,minAttackers=d.minAttackers,killerFirst=killer~=nil,attackers=list}
    end
    local msg={kind="H2I",id=s.id,rev=s.rev,note=s.note,deaths=deaths,truncated=truncated}
    while not L.Encode(msg) do
        local cut=false
        for i=#deaths,1,-1 do local d=deaths[i];if #d.attackers>(d.killerFirst and 1 or 0) then table.remove(d.attackers);cut=true;break end end
        if not cut then if #deaths<=1 then return nil end;table.remove(deaths);cut=true end
        msg.truncated=true
    end
    return msg
end
function L.LegacySnapshot(d,me)
    local old={};local g=d.lfg[1];if g then old[1]={id=g.id,mode=g.mode,activity=g.activity,min=g.min,max=g.max,have=g.have,want="",start=g.start,expires=g.expires,note=g.note} end
    return {kind="S",rev=d.rev,community=d.visible and d.community or "",faction=me.faction,class=d.visible and me.class or "",level=d.visible and me.level or 0,guild=d.visible and d.shareGuild and me.guild or "",guid=d.visible and me.guid or "",roles=d.visible and d.roles or "",note=d.visible and d.note or "",professionNote=d.visible and d.shareProfessions and d.professionNote or "",professions=d.visible and d.shareProfessions and d.professions or {},lfg=d.visible and old or {}}
end
function L.Snapshot(d,me,links)
    return {kind="S3",rev=d.rev,generation=d.generation,community=d.visible and d.community or "",faction=me.faction,class=d.visible and me.class or "",classFile=d.visible and me.classFile or "",level=d.visible and me.level or 0,guild=d.visible and d.shareGuild and me.guild or "",guid=d.visible and me.guid or "",roles=d.visible and d.roles or "",note=d.visible and d.note or "",professionNote=d.visible and d.shareProfessions and d.professionNote or "",professions=d.visible and d.shareProfessions and d.professions or {},group=d.visible and d.lfg[1] or nil,quest=d.visible and d.quest or nil,market=d.visible and d.market or {},linkMain=d.visible and links.main or "",linkVersion=links.version or 0,linkAlts=d.visible and links.alts or {},recipeRev=d.recipeRev,recipeCount=d.visible and d.shareProfessions and #d.recipes or 0,recipeScan=d.recipeScan}
end
function L.ApplyRetractions(snapshot,retractions)
    for token,revision in pairs(retractions or{})do
        if revision>=snapshot.rev then
            local kind,id=token:match("^([^:]+):(.+)$")
            if kind=="G"and snapshot.group and snapshot.group.id==id then snapshot.group=nil
            elseif kind=="Q"and snapshot.quest and snapshot.quest.id==id then snapshot.quest=nil
            elseif kind=="M"then for i=#(snapshot.market or{}),1,-1 do if snapshot.market[i].id==id then table.remove(snapshot.market,i)end end end
        end
    end
end
function L.Accept(d,key,s,now,wire)
    if not d.contacts[key] or d.blocked[key] or (s.kind~="S3" and s.kind~="S") then return false end;local old=d.peers[key];local generation=s.generation or "legacy"
    local authority=old and(old.verifiedSession or not old.cap4 and old.session)
    if s.kind=="S3"and authority and authority:match("^%d+%.%d+%.%d+$")and generation~=authority then return false end
    if old and not old.verifiedSession and not old.cap4 and old.retiredSessions and old.retiredSessions[generation]then return false end
    -- A compatibility Q request can arrive after Q3 and produce an older S
    -- snapshot. Never let that response erase S3-only fields such as the
    -- canonical class token used by member icons.
    if old and old.cap3 and s.kind=="S" then return false end
    if old and old.verifiedSession then
        if old.profileGeneration==generation and(old.profileRevision or 0)>s.rev then return false end
    elseif old and old.data and(old.data.generation or"legacy")==generation and old.data.rev>s.rev then return false end
    local location=old and old.location;local samePublic=old and(not old.cap4 or old.session==generation);local preservePublic=samePublic and s.kind=="S3"and s.rev<math.max(old.publicAppliedRev or-1,old.publicDeltaRev or-1);local group,quest,market=old and old.data and old.data.group,old and old.data and old.data.quest,old and old.data and old.data.market
    if preservePublic then s.group,s.quest,s.market=group,quest,market elseif samePublic and s.kind=="S3"then L.ApplyRetractions(s,old.retractions)end
    local peer=old or{};peer.data,peer.wire,peer.received,peer.lastContact=s,wire,now,now;peer.profileGeneration,peer.profileRevision=generation,s.rev;peer.state="reached";peer.cap3=s.kind=="S3";peer.faction=peer.faction or s.faction;peer.location=location;d.peers[key]=peer;return true
end
function L.ApplicationCounts(d,kind,id)
    local bucket=kind=="group" and d.interests or d.questInterests;local alerts=d.applicationAlerts[kind] or {};local open,unread=0,0
    for key,row in pairs(id and bucket[id] or {}) do if type(row)=="table" and row.state=="applied" then open=open+1;local a=alerts[id] and alerts[id][key];if a and a.unread then unread=unread+1 end end end
    return open,unread
end
function L.MarkApplicationsRead(d,kind,id,key)
    local byID=d.applicationAlerts[kind] and d.applicationAlerts[kind][id];if not byID then return false end;local changed=false
    for peer,a in pairs(byID) do if (not key or peer==key)and a.unread then a.unread=false;changed=true end end;return changed
end

function L.Engine(d,me,io)
    local e={db=d,me=me,io=io,out={},pending={},parts={},partCounts={},seen={},seenOrder={},dirty={},waitingTargets={},nextSend=0,serial=0,status="",blocked=false,lastRequest={}}
    local function ui() if io.changed then io.changed() end end
    function e:Stop(reason)
        if io.delivery then for _,p in ipairs(self.out)do io.delivery(p.key,p.dedupe,false)end;for _,p in pairs(self.pending)do io.delivery(p.key,p.dedupe,false)end end
        self.out,self.pending,self.parts,self.partCounts,self.waitingTargets={},{},{},{},{};self.status=reason or""
    end
    function e:CancelPeer(key)
        for i=#self.out,1,-1 do if self.out[i].key==key then table.remove(self.out,i)end end
        for id,p in pairs(self.pending)do if p.key==key then self.pending[id]=nil end end
        for token,p in pairs(self.parts)do if p.key==key then self.parts[token]=nil end end
        self.partCounts[key],self.dirty[key],self.lastRequest[key]=nil,nil,nil
        self.waitingTargets[key]=nil
    end
    function e:Queue(key,s,reliable,priority,dedupe,context)
        if not d.consent or d.blocked[key] or not d.contacts[key] or self.blocked then return nil,"Austausch nicht verfügbar." end
        local wire=L.Encode(s);if not wire or not L.Decode(wire,io.now(),true) then return nil,"Daten sind ungültig oder zu groß." end
        if dedupe then for _,item in ipairs(self.out) do if item.dedupe==dedupe and item.part==1 then item.wire=wire;item.total=math.ceil(#wire/180);item.priority=priority or 10;return item.id end end end
        if #self.out>=64 then return nil,"Warteschlange voll." end;local id=L.NextID(d,io.now());self.serial=self.serial+1;self.out[#self.out+1]={id=id,key=key,wire=wire,total=math.ceil(#wire/180),part=1,tries=0,reliable=reliable~=false,priority=priority or 10,dedupe=dedupe,serial=self.serial,context=context or{reason=s.kind}};return id
    end
    function e:Request(key) local now=io.now();if self.lastRequest[key] and now-self.lastRequest[key]<10 then return nil,"Bereits angefragt." end;self.lastRequest[key]=now;self:Queue(key,{kind="Q3",rev=d.peers[key] and d.peers[key].data and d.peers[key].data.rev or 0},true,40,"Q3:"..key);return self:Queue(key,{kind="Q",rev=0},true,20,"Q:"..key) end
    local function reachable(key)return io.reachable and io.reachable(key)or not io.reachable and L.PeerOnline(d,key,io.now())end
    function e:Publish() for key,p in pairs(d.peers) do if p.received and d.contacts[key] and not d.blocked[key]and reachable(key)and(not p.cap4 or p.profileRequested)then self.dirty[key]=true end end end
    function e:QueueSnapshot(key,legacy,background) return self:Queue(key,legacy and L.LegacySnapshot(d,me) or io.snapshot(),true,30,(legacy and"SNAP1:"or"SNAP3:")..key,{reason="profile",background=background==true}) end
    local function partCount(key) return e.partCounts[key] or 0 end
    local function choose(clock) local best,index;local pendingCount=count(e.pending);for i,item in ipairs(e.out) do if clock>=(e.waitingTargets[item.key]or 0)and(not item.reliable or e.pending[item.id] or pendingCount<8) and (not best or item.priority>best.priority or (item.priority==best.priority and item.serial<best.serial)) then best,index=item,i end end;return best,index end
    function e:Tick()
        local now=io.now();if not d.consent then self:Stop("");return end
        for _,p in ipairs(self.out)do if d.blocked[p.key]or not d.contacts[p.key]then self:CancelPeer(p.key);break end end
        for _,p in pairs(self.pending)do if d.blocked[p.key]or not d.contacts[p.key]then self:CancelPeer(p.key)end end
        for token,p in pairs(self.parts) do if p.at+90<now then self.parts[token]=nil;self.partCounts[p.key]=math.max(0,partCount(p.key)-1) end end
        for id,p in pairs(self.pending) do if p.deadline and p.deadline<=now then self.pending[id]=nil;if p.tries<3 and #self.out<64 then p.part=1;p.deadline=nil;p.priority=70;self.out[#self.out+1]=p elseif io.delivery then io.delivery(p.key,p.dedupe,false)end end end
        if #self.out<48 and count(self.pending)<8 then for key in pairs(self.dirty) do
            if not reachable(key)then self.dirty[key]=nil else local q=self:QueueSnapshot(key,d.peers[key]and not d.peers[key].cap3,true);if q then self.dirty[key]=nil end end;break
        end end
        if self.blocked or now<self.nextSend then return end
        local allowed,reason=io.allowed();if not allowed then self.status=reason or"";self.nextSend=now+5;return end;self.status=""
        local clock=io.clock and io.clock()or now
        for _=1,8 do
            local p,index=choose(clock);if not p then return end
            local contact=d.contacts[p.key];if not contact or d.blocked[p.key]then self:CancelPeer(p.key);return end
            local frame="1|"..p.id.."|"..p.part.."|"..p.total.."|"..p.wire:sub((p.part-1)*180+1,p.part*180)
            local result=io.send(frame,contact.target,p.context);self.nextSend=now
            if result=="pending_route"then
                self.waitingTargets[p.key]=io.pendingUntil and io.pendingUntil(contact.target)or clock+1
            elseif result=="ok"then
                self.waitingTargets[p.key]=nil;p.throttles=0;p.part=p.part+1
                if p.part>p.total then table.remove(self.out,index);p.tries=p.tries+1;if p.reliable then p.deadline=now+45;self.pending[p.id]=p end end
                return
            elseif result=="blocked"then self.status="Addon-Nachrichten sind gerade gesperrt.";self.nextSend=now+5;return
            elseif result=="throttle"then
                self.nextSend=now+5;p.throttles=(p.throttles or 0)+1
                if p.throttles>=3 then table.remove(self.out,index);if io.delivery then io.delivery(p.key,p.dedupe,false)end end;return
            else table.remove(self.out,index);if io.delivery then io.delivery(p.key,p.dedupe,false)end end
        end
    end
    local function groupFor(id) local g=d.lfg[1];if g and g.id==id and g.expires>io.now() then return g end end
    function e:Receive(sender,message)
        if not d.consent or type(message)~="string" or #message>240 then return false end;local legacy=L.Identity(sender,me.realm);local scoped=L.ScopeKey(sender,me.realm,me.faction);local key=scoped and d.contacts[scoped]and scoped or legacy;if not key or d.blocked[key] or not d.contacts[key] then return false end
        local id,index,total,chunk=message:match("^1|([%d%.]+)|(%d+)|(%d+)|(.*)$");if not id or #id>32 or #index>2 or #total>2 or #chunk>180 then return false end;index,total=tonumber(index),tonumber(total);if not L.Int(total,1,L.MAX_PARTS) or not L.Int(index,1,total) then return false end
        local token=key..":"..id;local now=io.now();if self.seen[token] then if index==total and self.seen[token].ack then self:Queue(key,{kind="A",id=id},false,100) end;return false end
        local p=self.parts[token];if not p then if count(self.parts)>=8 or partCount(key)>=2 then return false end;p={n=total,at=now,chunks={},size=0,key=key};self.parts[token]=p;self.partCounts[key]=partCount(key)+1 end
        if p.n~=total then self.parts[token]=nil;self.partCounts[key]=math.max(0,partCount(key)-1);return false end;if not p.chunks[index] then p.chunks[index]=chunk;p.size=p.size+#chunk end;if p.size>L.MAX_BYTES then self.parts[token]=nil;self.partCounts[key]=math.max(0,partCount(key)-1);return false end;for i=1,total do if not p.chunks[i] then return false end end
        self.parts[token]=nil;self.partCounts[key]=math.max(0,partCount(key)-1);local wire=table.concat(p.chunks);local s=L.Decode(wire,now);if not s then return false end;self.seen[token]={ack=s.kind~="A"};self.seenOrder[#self.seenOrder+1]=token;if #self.seenOrder>128 then self.seen[table.remove(self.seenOrder,1)]=nil end;if s.kind~="A" then self:Queue(key,{kind="A",id=id},false,100) end
        local peer=d.peers[key] or {};d.peers[key]=peer;peer.lastContact=now;peer.state="reached"
        if s.kind=="A" then local sent=self.pending[s.id];if sent and sent.key==key then self.pending[s.id]=nil;if io.delivery then io.delivery(key,sent.dedupe,true)end end
        elseif s.kind=="L1" then if s.faction==me.faction and(not peer.location or s.at>=peer.location.at)then peer.location={at=s.at,mapID=s.mapID,area=s.area,subzone=s.subzone};ui()end
        elseif s.kind=="Q3" then peer.profileRequested=true;self:QueueSnapshot(key,false)
        elseif s.kind=="Q" then peer.profileRequested=true;self:QueueSnapshot(key,true)
        elseif s.kind=="S3" or s.kind=="S" then if s.faction==me.faction then
            local old=d.peers[key]and d.peers[key].data;local oldGroup=old and(old.group or old.lfg and old.lfg[1])
            if L.Accept(d,key,s,now,wire)then if io.profile then io.profile(key)end;if io.items then io.items(s.market)end;local newGroup=s.group or s.lfg and s.lfg[1];if newGroup and(not oldGroup or oldGroup.id~=newGroup.id)and io.group then io.group(key,newGroup)end end
        end
        elseif s.kind=="GA" then
            local g=groupFor(s.id);if g then d.interests[s.id]=d.interests[s.id] or {};local people=d.interests[s.id]
                if count(people)<40 or people[key] then
                    local old=people[key];people[key]={role=s.role,note=s.note,at=now,state="applied"}
                    if old and old.state~="applied" and old.state~="withdrawn" then people[key]=old
                    else
                    d.applicationAlerts.group[s.id]=d.applicationAlerts.group[s.id] or {};local alerts=d.applicationAlerts.group[s.id];local first=alerts[key]==nil
                    if first then alerts[key]={unread=true,notified=true};if io.application then io.application("group",key,s.id) end
                    elseif old and old.state=="applied" then people[key].at=old.at or now end
                    end
                    if(not old or old.state=="withdrawn")and io.finder then io.finder("group","application_received",key,s.id,g)end
                end
            end
        elseif s.kind=="GW" then if d.interests[s.id] and d.interests[s.id][key]then local row=d.interests[s.id][key];if row.state~="withdrawn"then row.state="withdrawn";row.at=now;if io.finder then io.finder("group","withdrawal_received",key,s.id,groupFor(s.id))end end;local a=d.applicationAlerts.group[s.id] and d.applicationAlerts.group[s.id][key];if a then a.unread=false end end
        elseif s.kind=="GS" then local sent=d.sentApplications[s.id] and d.sentApplications[s.id][key];if sent and L.ApplicationCanAdvance(sent.state,s.state) then sent.state=s.state;sent.at=now;if io.finder then io.finder("group",s.state=="invited"and"invited_received"or s.state=="rejected"and"rejected_received"or"joined",key,s.id,nil)end end
        elseif s.kind=="QA" then
            if d.quest and d.quest.id==s.id and d.quest.expires>now then d.questInterests[s.id]=d.questInterests[s.id] or {};local people=d.questInterests[s.id]
                if count(people)<40 or people[key] then
                    local old=people[key];people[key]={note=s.note,at=now,state="applied"}
                    if old and old.state~="applied" and old.state~="withdrawn" then people[key]=old
                    else
                    d.applicationAlerts.quest[s.id]=d.applicationAlerts.quest[s.id] or {};local alerts=d.applicationAlerts.quest[s.id];local first=alerts[key]==nil
                    if first then alerts[key]={unread=true,notified=true};if io.application then io.application("quest",key,s.id) end
                    elseif old and old.state=="applied" then people[key].at=old.at or now end
                    end
                    if(not old or old.state=="withdrawn")and io.finder then io.finder("quest","application_received",key,s.id,d.quest)end
                end
            end
        elseif s.kind=="QW" then if d.questInterests[s.id] and d.questInterests[s.id][key]then local row=d.questInterests[s.id][key];if row.state~="withdrawn"then row.state="withdrawn";row.at=now;if io.finder then io.finder("quest","withdrawal_received",key,s.id,d.quest)end end;local a=d.applicationAlerts.quest[s.id] and d.applicationAlerts.quest[s.id][key];if a then a.unread=false end end
        elseif s.kind=="QS" then local sent=d.sentQuestApplications[s.id] and d.sentQuestApplications[s.id][key];if sent and L.ApplicationCanAdvance(sent.state,s.state) then sent.state=s.state;sent.at=now;if io.finder then io.finder("quest",s.state=="invited"and"invited_received"or s.state=="rejected"and"rejected_received"or"joined",key,s.id,nil)end end
        elseif s.kind:match("^H[12]") then if io.pvp then io.pvp(key,s) end
        elseif s.kind=="RQ" then if d.visible and d.shareProfessions then self:Queue(key,{kind="RS",id=s.id,results=io.recipeSearch(s.query)},true,25)end
        elseif s.kind=="RS" then d.recipeResults[s.id]=d.recipeResults[s.id] or {};d.recipeResults[s.id][key]={results=s.results,at=now}
        elseif s.kind=="CQ"then
            local results,total={},0;if io.recipeCatalog then results,total=io.recipeCatalog(s.profession,s.offset)end
            local response={kind="CS",id=s.id,profession=s.profession,offset=s.offset,total=total or 0,results=results or{}}
            -- Ingredient-aware pages stay inside the original frame/message limits.
            while #response.results>0 and not L.Encode(response)do table.remove(response.results)end
            self:Queue(key,response,true,25)
        elseif s.kind=="CS" then
            local byProfession=d.recipeCatalogs and d.recipeCatalogs[key];local catalog=byProfession and byProfession[s.profession]
            if catalog and catalog.id==s.id and catalog.nextOffset==s.offset then
                local current=io.catalogRevision and io.catalogRevision(key)
                if current and catalog.recipeRev and current~=catalog.recipeRev then catalog.stale=true;catalog.results={};catalog.complete=false;if io.catalogRestart then io.catalogRestart(key,s.profession)end
                else
                    local seen={};for _,r in ipairs(catalog.results)do seen[r.id]=true end;for _,r in ipairs(s.results)do if not seen[r.id]and#catalog.results<L.MAX_RECIPES_PER_PROFESSION then catalog.results[#catalog.results+1]=r;seen[r.id]=true end end
                    catalog.total=s.total;catalog.at=now;catalog.nextOffset=s.offset+#s.results
                    if catalog.nextOffset<s.total and#s.results>0 then self:Queue(key,{kind="CQ",id=s.id,profession=s.profession,offset=catalog.nextOffset},true,25,"CAT:"..key..":"..s.id)
                    else catalog.complete=catalog.nextOffset>=s.total end;if io.catalogUpdated then io.catalogUpdated(key,s.profession)end
                end
            end
        end
        if s.kind~="A"then ui()end;return true
    end
    return e
end
return L
