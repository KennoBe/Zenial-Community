local Z,L=ZenialCommunity,ZenialCommunity.Logic
local S={}
Z.Social=S

local function scope()
    return string.lower((Z.me.realm or""):gsub("%s+","")).."@"..string.lower(Z.me.faction or"")
end
local ROSTER_ECHO_GAP,ROSTER_SERVER_GAP=5,60
local ROSTER_REQUEST_GAP,ROSTER_REFRESH_GAP=10,2
local guild={left=false,name="",names={},complete=false,loaded=false,pending=false,wantRequest=false,wantServer=false,serverAt=-math.huge,ids={},requestAt=-math.huge,refreshAt=-math.huge}
S.guildCache=guild
local function size(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function snapshot(source)
    local out={};for key,value in pairs(type(source)=="table"and source or{})do if type(key)=="string"and(type(value)=="string"or type(value)=="boolean")then out[key]=value end end;return out
end
function S.Initialize()
    ZenialCommunityDB.social=type(ZenialCommunityDB.social)=="table"and ZenialCommunityDB.social or{}
    local key=scope();local store=ZenialCommunityDB.social[key]
    local existing=type(store)=="table"
    -- SavedVariables serialize aliases as separate copies. Never reimport a
    -- character's old copy over an existing shared store, even an empty one.
    ZenialCommunityDB.socialMigration=type(ZenialCommunityDB.socialMigration)=="table"and ZenialCommunityDB.socialMigration or{}
    local migration=ZenialCommunityDB.socialMigration;migration.version=1;migration.characters=type(migration.characters)=="table"and migration.characters or{}
    local character=Z.storageKey or Z.me.key
    local migrated=type(migration.characters[character])=="table"
    if not migrated then migration.characters[character]={version=1,favorites=snapshot(Z.db.favorites),notes=snapshot(Z.db.privateNotes)}end
    if not existing then
        store={favorites={},notes={}};ZenialCommunityDB.social[key]=store
        if not migrated then store.favorites=snapshot(Z.db.favorites);store.notes=snapshot(Z.db.privateNotes)end
    end
    local favorites,notes={},{};for peer,enabled in pairs(type(store.favorites)=="table"and store.favorites or{})do if size(favorites)<1000 and enabled==true and L.ValidIdentityKey(peer)then favorites[peer]=true end end;for peer,note in pairs(type(store.notes)=="table"and store.notes or{})do if L.ValidIdentityKey(peer)and L.Text(note,500,true)then notes[peer]=note end end;store.favorites,store.notes=favorites,notes
    store.migrationVersion=1
    Z.db.favorites,Z.db.privateNotes=store.favorites,store.notes;S.store=store
    guild.pending=true;S.RequestGuildRoster()
end
function S.IsFavorite(key)return S.store and S.store.favorites[key]==true end
-- Local guild roster cache. The roster is the primary source for "same guild":
-- public snapshots never carry the guild name (Network3 bundleWire clears it).
-- Rendering only reads this cache; roster requests come from events/ticks.
local function clearGuild()
    local changed=guild.name~=""or guild.loaded or next(guild.names)~=nil
    guild.name,guild.names,guild.complete,guild.loaded,guild.ids="",{},false,false,{}
    return changed
end
-- Name of the own guild: the cache first, the identity snapshot as fallback.
function S.GuildName()
    if guild.left then return""end -- confirmed outside any guild; Z.me.guild may lag behind
    if guild.name~=""then return guild.name end
    local own=Z.me and Z.me.guild
    return type(own)=="string"and own:find("%S")and own or""
end
local function realmId(value)return(string.lower((tostring(value or""):gsub("[%s%-]",""))))end
-- Identity of a roster name inside the own scope: no realm suffix or the own realm.
function S.RosterIdentity(member)
    if type(member)~="string"then return nil end
    local id,_,realm=L.Identity(member)
    if not id then return nil end
    local suffix=member:match("^.-%-(.+)$")
    if suffix and realmId(suffix)~=realmId(Z.me and Z.me.realm)then return nil end
    if realm~=""and realmId(realm)~=realmId(Z.me and Z.me.realm)then return nil end
    return id
end
-- Reads the roster once and reports whether anything visible changed.
function S.RefreshGuildRoster()
    local A=Z.Adapter
    local inGuild=type(IsInGuild)=="function"and A.Call(IsInGuild)or nil
    if type(IsInGuild)=="function"then
        local was=guild.left;guild.left=not inGuild
        if not inGuild then return clearGuild()or was~=guild.left end
        if was then guild.left=false end
    end
    local name=A.Call(GetGuildInfo,"player")
    name=L.Text(name,64)and name or nil
    local changed=false
    -- Login timing: in a guild, but the guild name is not available yet.
    if not name and inGuild then guild.pending=true;return false end
    if not name and inGuild==nil and guild.name~=""then return clearGuild()end
    if name and guild.name~=name then
        -- Guild change: drop every entry of the former guild before reading.
        changed=clearGuild();guild.name=name;changed=true
    end
    if guild.name==""and not name and inGuild==nil then return changed end
    local total=A.Call(GetNumGuildMembers)
    if type(total)~="number"or total<=0 then return changed end
    local names,count={},0
    for index=1,total do
        local id=S.RosterIdentity(A.Call(GetGuildRosterInfo,index))
        if id then names[id]=true;count=count+1 end
    end
    if count==0 then
        -- No entry maps to a valid identity of this scope (unexpected format):
        -- treat the roster as not loaded so the profile fallback stays active.
        if guild.loaded then guild.names,guild.complete,guild.loaded={},false,false;changed=true end
        return changed
    end
    -- Complete only if every index delivered a name (hidden offline members do not).
    local complete=count==total
    local same=guild.loaded and guild.complete==complete
    if same then for id in pairs(names)do if not guild.names[id]then same=false;break end end end
    if same then for id in pairs(guild.names)do if not names[id]then same=false;break end end end
    if not same then guild.names,guild.complete,guild.loaded=names,complete,true;changed=true end
    return changed
end
-- Never at render time; WoW itself limits roster requests, so keep a gap.
function S.RequestGuildRoster()
    local A=Z.Adapter;local clock=A.Clock()
    if type(IsInGuild)=="function"and not A.Call(IsInGuild)then guild.wantRequest=false;return false end
    local request=type(C_GuildInfo)=="table"and C_GuildInfo.GuildRoster or GuildRoster
    if type(request)~="function"then guild.wantRequest=false;return false end
    -- Suppressed by the gap: remember it, GuildTick repeats it once.
    if clock<guild.requestAt+ROSTER_REQUEST_GAP then guild.wantRequest=true;return false end
    guild.wantRequest=false;guild.requestAt=clock;A.Call(request);return true
end
function S.OnGuildEvent(event,...)
    if event=="PLAYER_ENTERING_WORLD"or event=="PLAYER_GUILD_UPDATE"then S.RequestGuildRoster();guild.pending=true
    elseif event=="GUILD_ROSTER_UPDATE"then
        -- canRequestRosterUpdate: the server asks for a new roster; once, after the gap.
        -- Own request answers (within 5 s) are ignored; server-asked repeats are limited to one per 60 s.
        if(...)==true and Z.Adapter.Clock()>=guild.requestAt+ROSTER_ECHO_GAP then guild.wantRequest,guild.wantServer=true,true end
        guild.pending=true
    end
end
-- Throttled: re-reads after events and refreshes the visible list only on change.
function S.GuildTick()
    local clock=Z.Adapter.Clock()
    if guild.wantRequest and clock>=guild.requestAt+ROSTER_REQUEST_GAP and(not guild.wantServer or clock>=guild.serverAt+ROSTER_SERVER_GAP)then
        local server=guild.wantServer
        if S.RequestGuildRoster()then
            guild.pending=true
            if server then guild.wantServer,guild.serverAt=false,clock end
        end
    end
    if not guild.pending then return false end
    if clock<guild.refreshAt+ROSTER_REFRESH_GAP then return false end
    guild.pending,guild.refreshAt=false,clock
    if S.RefreshGuildRoster()then Z.MarkDirty("guild");return true end
    return false
end
-- Roster identity of a member key, only inside the own world/faction scope.
local function rosterName(key)
    if type(key)~="string"then return nil end
    local cached=guild.ids[key]
    if cached~=nil then return cached or nil end
    local id
    local realm,faction,name=key:match("^([^@]+)@([^@]+)@(.+)$")
    if realm then
        if realm.."@"..faction==scope()then id=(L.Identity(name))end
    else id=(L.Identity(key))end
    guild.ids[key]=id or false
    return id
end
-- Pure cache lookup: filtering must never request profiles or a guild roster.
-- Forever uses one megaserver. A loaded roster decides; without one (not loaded,
-- hidden offline members) the guild name of a complete profile is the fallback.
-- A missing name is never read as "other guild".
function S.IsGuildMember(key)
    local own=S.GuildName()
    if own==""then return false end
    if key==Z.me.key then return true end
    if guild.loaded and guild.name==own then
        local name=rosterName(key)
        if name and guild.names[name]then return true end
        if guild.complete or not name then return false end
    end
    local peer=Z.db and Z.db.peers[key];local data=peer and peer.data
    return data~=nil and type(data.guild)=="string"and data.guild~=""and data.guild==own
end
function S.ToggleFavorite(key)
    if not L.ValidIdentityKey(key)then return nil,"Ungültiger Spieler."end
    if S.store.favorites[key]then S.store.favorites[key]=nil;return false end
    if size(S.store.favorites)>=1000 then return nil,"Maximal 1.000 Favoriten."end
    S.store.favorites[key]=true;return true
end
function S.Note(key,value)
    if not L.ValidIdentityKey(key)or not L.Text(value or"",500,true)then return nil,"Notiz ist ungültig."end
    S.store.notes[key]=value~=""and value or nil;return true
end
function S.GetNote(key)return S.store and S.store.notes[key]or""end
return S
