local Z,L=ZenialCommunity,ZenialCommunity.Logic
local S={}
Z.Social=S

local function scope()
    return string.lower((Z.me.realm or""):gsub("%s+","")).."@"..string.lower(Z.me.faction or"")
end
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
end
function S.IsFavorite(key)return S.store and S.store.favorites[key]==true end
-- Pure cache lookup: filtering must never request profiles or a guild roster.
-- Forever uses one megaserver; the current character's guild is authoritative.
function S.IsGuildMember(key)
    local guild=Z.me and Z.me.guild
    if type(guild)~="string"or not guild:find("%S")then return false end
    if key==Z.me.key then return true end
    local peer=Z.db and Z.db.peers[key];local data=peer and peer.data
    return data~=nil and data.guild==guild
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
