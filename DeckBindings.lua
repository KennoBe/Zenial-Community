-- Zenial Deck, addon side: bindings for the Companion's "Deck" plus three export topics (bindings, pvp, deckslots).
-- Keys are set only as override bindings (never SetBinding/SaveBindings), never on a taken key, never in combat.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local P,T=Z.CompanionProtocol,Z.CompanionTelemetry
local D={};Z.Deck=D
local SLOTS,SETTLE=5,.5
D.SLOTS=SLOTS
BINDING_HEADER_ZENIALCOMMUNITY='Zenial Community'
-- Order = order of assignment. Binding names are the ones Bindings.xml declares.
local ACTIONS={{id='open',name='Open / close Zenial Community',run='toggle'}}
for _,page in ipairs({{'today','Show page: Start'},{'members','Show page: Members'},{'activities','Show page: Activities'},{'quests','Show page: Quests'},
    {'craft','Show page: Crafting'},{'trade','Show page: Trade'},{'characters','Show page: My Characters'}})do
    ACTIONS[#ACTIONS+1]={id='nav_'..page[1],name=page[2],run='page',page=page[1]}
end
ACTIONS[#ACTIONS+1]={id='pvp_request',name='Open the PvP help request form',run='pvp_request'}
ACTIONS[#ACTIONS+1]={id='pvp_calls',name='Show PvP help calls',run='pvp_calls'}
for n=1,SLOTS do
    ACTIONS[#ACTIONS+1]={id='slot'..n..'_whisper',name='Deck slot %d: open whisper',run='whisper',slot=n}
    ACTIONS[#ACTIONS+1]={id='slot'..n..'_invite',name='Deck slot %d: invite',run='invite',slot=n}
    ACTIONS[#ACTIONS+1]={id='slot'..n..'_profile',name='Deck slot %d: show profile',run='profile',slot=n}
end
local byId={}
for _,a in ipairs(ACTIONS)do
    a.binding='ZENIALCOMMUNITY_'..(a.id=='open'and'TOGGLE'or a.id:upper())
    byId[a.id]=a;_G['BINDING_NAME_'..a.binding]=a.slot and Z.T(a.name,a.slot)or Z.T(a.name)
end
D.ACTIONS=ACTIONS

local function say(text)
    local U=Z.UI;if U and U.status and U.Message then U.Message(text)end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(text)else print(text)end
end
local function scope()
    return string.lower((Z.me.realm or""):gsub("%s+","")).."@"..string.lower(Z.me.faction or"")
end
-- Own root. A foreign version stays untouched and disables the module (nothing is assigned, topics report available=false).
function D.Init()
    local root=ZenialCommunityDB
    if type(root)~='table'or Z.offlineOnly or not Z.me or not Z.db then D.store=nil;return nil end
    if root.deck==nil then root.deck={version=1,auto=true,fkeys=false,keys={},slots={},notified=false}end
    local s=root.deck
    if type(s)~='table'or s.version~=1 then D.store=nil;return nil end
    if type(s.auto)~='boolean'then s.auto=true end
    if type(s.fkeys)~='boolean'then s.fkeys=false end
    if type(s.keys)~='table'then s.keys={}end
    if type(s.slots)~='table'then s.slots={}end
    if not D.sessionStarted then s.notified=false;D.sessionStarted=true end -- the exhaustion note is once per session
    D.store=s;return s
end
local function api()
    return type(GetBindingKey)=='function'and type(GetBindingAction)=='function'and type(SetOverrideBinding)=='function'and type(ClearOverrideBindings)=='function'
end
local function inCombat()return A.Call(InCombatLockdown)==true end
local function due(topic)if Z.Companion and Z.Companion.due then Z.Companion.due[topic]=0 end end

-- Slots (shared per realm and faction, like the favorites).
local function slotTable(create)
    local s=D.store;if not s or not Z.me then return nil end
    local key=scope();local t=s.slots[key]
    if type(t)~='table'then if not create then return nil end;t={};s.slots[key]=t end
    return t
end
function D.SlotKey(index)
    D.Init();local t=L.Int(index,1,SLOTS)and slotTable(false);local key=t and t[index]
    return type(key)=='string'and L.ValidIdentityKey(key)and key or nil
end
-- key=nil (or "") empties the slot. Only known contacts can be stored. Returns true, or false,reason.
function D.SetSlot(index,key)
    if not D.Init()then return false,"Deck unavailable."end
    if not L.Int(index,1,SLOTS)then return false,"Invalid slot."end
    if key==nil or key==""then local t=slotTable(false);if t then t[index]=nil end
    else
        if type(key)~='string'or not L.ValidIdentityKey(key)or not Z.db.contacts[key]then return false,"Unknown player."end
        slotTable(true)[index]=key
    end
    due('deckslots');return true
end
-- Returns true,key or false,reason.
function D.SetSlotByName(index,name)
    if not D.Init()then return false,"Deck unavailable."end
    local key=Z.ResolvePeerKey(name);if not key or not Z.db.contacts[key]then return false,"Unknown player."end
    local ok,why=D.SetSlot(index,key);if not ok then return false,why end
    return true,key
end
-- Occupied slots only: { index, key, target, classFile }.
function D.Slots()
    local out={};D.Init();if not D.store then return out end
    for i=1,SLOTS do
        local key=D.SlotKey(i);local c=key and Z.db.contacts[key]
        if c then
            local peer=Z.db.peers[key];local presence=peer and peer.presence;local profile=peer and peer.data
            local class=presence and presence.classFile or c.classFile or profile and profile.classFile
            out[#out+1]={index=i,key=key,target=c.target,classFile=type(class)=='string'and#class<=16 and class or nil}
        end
    end
    return out
end

-- Automatic keys.
local function pool(fkeys)
    local out={}
    if fkeys then for i=13,24 do out[#out+1]='F'..i end end
    for i=1,12 do out[#out+1]='CTRL-SHIFT-F'..i end
    for i=1,12 do if i~=4 then out[#out+1]='ALT-SHIFT-F'..i end end -- ALT-F4 closes the game window
    for i=1,9 do out[#out+1]='CTRL-SHIFT-'..i end
    for i=1,9 do out[#out+1]='ALT-SHIFT-'..i end
    return out
end
D.Pool=pool
local function bound(binding)
    local ok,key=pcall(GetBindingKey,binding)
    return ok and A.Safe(key)and type(key)=='string'and key~=''and key or nil
end
local function action(key)
    local ok,name=pcall(GetBindingAction,key,true)
    if not ok or not A.Safe(name)then return nil end
    return name or''
end
local function reconcile(store)
    local frame=D.frame
    pcall(ClearOverrideBindings,frame)
    local companion=Z.Companion and Z.Companion.settings
    local wanted=store.auto==true and companion and companion.enabled==true or false
    local keys=wanted and pool(store.fkeys==true)or{};local inPool={}
    for _,key in ipairs(keys)do inPool[key]=true end
    local used,result={},{}
    local function place(key,binding)
        used[key]=true
        if action(key)~=''then return false end -- taken (or unreadable): never overwrite
        if not pcall(SetOverrideBinding,frame,false,key,binding)then return false end
        if action(key)==binding then return true end
        pcall(SetOverrideBinding,frame,false,key,nil) -- the client did not take it
        return false
    end
    for _,a in ipairs(ACTIONS)do local key=bound(a.binding);if key then result[a.id]={key=key,source='user'}end end
    if wanted then
        -- Remembered keys first, so a newly freed action cannot take another action's key.
        for _,a in ipairs(ACTIONS)do
            local key=store.keys[a.id]
            if not result[a.id]and type(key)=='string'and inPool[key]and not used[key]and place(key,a.binding)then result[a.id]={key=key,source='pool'}end
        end
    end
    local exhausted=false
    if wanted then
        for _,a in ipairs(ACTIONS)do
            if not result[a.id]then
                for _,key in ipairs(keys)do
                    if not used[key]and place(key,a.binding)then result[a.id]={key=key,source='pool'};break end
                end
                if not result[a.id]then exhausted=true end
            end
        end
    end
    local assigned={}
    for _,r in pairs(result)do if r.source=='pool'then assigned[r.key]=true end end
    for id,key in pairs(store.keys)do
        local r=result[id]
        if not byId[id]or type(key)~='string'then store.keys[id]=nil
        elseif r and r.source=='pool'then store.keys[id]=r.key
        elseif assigned[key]then store.keys[id]=nil end -- a key now used by another action is not remembered twice
    end
    for id,r in pairs(result)do if r.source=='pool'then store.keys[id]=r.key end end
    D.state={result=result,exhausted=exhausted}
    if exhausted and not store.notified then
        store.notified=true;say(Z.T("ZENIAL Deck: no free key combination is left. Assign the remaining actions under Key Bindings."))
    end
end
-- One reconciliation pass now. Returns true, or false,"unavailable"/"combat".
function D.Apply()
    local store=D.Init()
    if not store or not api()then D.state=nil;D.pending=false;return false,"unavailable"end
    if inCombat()then D.pending=true;due('bindings');return false,"combat"end
    D.pending=false;D.busy=true
    local ok,err=pcall(reconcile,store)
    D.busy=nil;D.quietUntil=A.Clock()+SETTLE;D.nextAt=D.quietUntil
    if not ok then D.lastError=err end
    due('bindings');return ok
end
local function onUpdate()
    if A.Clock()<(D.nextAt or 0)then return end
    D.frame:SetScript('OnUpdate',nil);D.Apply()
end
-- Triggers are merged: one pass at most every SETTLE seconds, run from the next frame.
function D.Request()
    if D.frame then D.frame:SetScript('OnUpdate',onUpdate)end
end
-- Current state per action, in declaration order: { id, key?, source = user|pool|none }.
function D.Effective()
    local out={};local result=D.state and D.state.result or{}
    for _,a in ipairs(ACTIONS)do
        local r=result[a.id];out[#out+1]={id=a.id,key=r and r.key,source=r and r.source or'none'}
    end
    return out
end
function D.Available()return D.Init()~=nil and api()==true end

-- Running an action (called from Bindings.xml).
local function show()
    local U=Z.UI;if not U or not U.Create or not U.Navigate then return nil end
    U.Create();U.frame:Show();return U
end
function D.Run(id)
    local a=byId[id];if not a or not Z.db or not Z.me or Z.offlineOnly or not Z.UI then return false end
    local U=Z.UI
    if a.run=='toggle'then U.Toggle();return true end
    if a.run=='page'then local u=show();if not u then return false end;u.Navigate(a.page);return true end
    if a.run=='pvp_request'then U.OpenPvPHelp(nil,nil,nil,true);return true end
    if a.run=='pvp_calls'then U.OpenPvPHelp();return true end
    local key=D.SlotKey(a.slot);local contact=key and Z.db.contacts[key]
    if not contact then say(Z.T("Deck slot %d is not assigned.",a.slot));return false end
    if a.run=='whisper'then return A.Whisper(contact.target)==true end
    if a.run=='invite'then
        local ok,why=A.Invite(contact.target);if not ok and why then say(Z.T(why))end;return ok==true
    end
    local u=show();if not u then return false end
    U.memberKey,U.memberFollowActive=key,false;U.Navigate('members');return true
end

-- /zenial deck ...  (returns true when the text was a deck command)
function D.HandleCommand(text)
    if type(text)~='string'then return false end
    local rest=text:match("^%s*[Dd][Ee][Cc][Kk]$")and""or text:match("^%s*[Dd][Ee][Cc][Kk]%s+(.-)%s*$")
    if not rest then return false end
    local store=D.Init()
    if not store then say(Z.T("ZENIAL Deck is not available."));return true end
    local lower=rest:lower();local function onoff(v)return Z.T(v and"on"or"off")end
    if lower==""then
        local n=0;for _,e in ipairs(D.Effective())do if e.key then n=n+1 end end
        say(Z.T("ZENIAL Deck: automatic keys %s, %d of %d actions assigned, F13-F24 %s.",onoff(store.auto),n,#ACTIONS,onoff(store.fkeys)))
    elseif lower=="on"or lower=="off"then
        store.auto=lower=="on";D.Request();say(Z.T("ZENIAL Deck: automatic keys %s.",onoff(store.auto)))
    elseif lower=="fkeys on"or lower=="fkeys off"then
        -- Remembered keys would otherwise keep the old pool in place.
        store.fkeys=lower=="fkeys on";store.keys={};D.Request();say(Z.T("ZENIAL Deck: F13-F24 %s.",onoff(store.fkeys)))
    else
        local n,name=rest:match("^[Ss][Ll][Oo][Tt]%s+(%d+)%s*(.-)$");n=tonumber(n)
        if not n or not L.Int(n,1,SLOTS)or name==""then say(Z.T("Usage: /zenial deck [on|off|fkeys on|fkeys off|slot <1-5> <name>|slot <1-5> clear]"))
        elseif name:lower()=="clear"then D.SetSlot(n,nil);say(Z.T("Deck slot %d cleared.",n))
        else
            local ok,key=D.SetSlotByName(n,name)
            if ok then say(Z.T("Deck slot %d: %s",n,Z.db.contacts[key].target))else say(Z.T("Deck slot %d: no known player named %s.",n,name))end
        end
    end
    return true
end

-- Export topics. They always return a table.
T.bindings=function()
    local s=D.Init();if not s or not api()then return{available=false}end
    local actions=P.Array();for _,e in ipairs(D.Effective())do actions[#actions+1]={id=e.id,key=e.key,source=e.source}end
    return{available=true,auto=s.auto==true,pending=D.pending==true,poolExhausted=D.state and D.state.exhausted==true or false,actions=actions}
end
T.deckslots=function()
    if not D.Init()then return{available=false}end
    local slots=P.Array();for _,s in ipairs(D.Slots())do slots[#slots+1]={index=s.index,key=s.key,name=s.target,classFile=s.classFile}end
    return{available=true,slots=slots}
end
T.pvp=function()
    local V=Z.PvPHelp;if not V or not V.store or not Z.db or not Z.me then return{available=false}end
    local ok,code,text,cooldownUntil=V.CallState();local own=V.Own()
    return{available=true,canCall=ok==true,reason=not ok and code or nil,reasonText=not ok and text or nil,cooldownUntil=cooldownUntil,
        flagged=A.IsPvpFlagged(),unread=V.UnreadCount(),own=own and{id=own.id,expiresAt=own.expires}or nil}
end

local frame=CreateFrame('Frame');D.frame=frame
for _,event in ipairs({'PLAYER_ENTERING_WORLD','UPDATE_BINDINGS','PLAYER_REGEN_ENABLED'})do pcall(frame.RegisterEvent,frame,event)end
frame:SetScript('OnEvent',function(_,event)
    -- Our own override changes must not start another pass.
    if event=='UPDATE_BINDINGS'and(D.busy or A.Clock()<(D.quietUntil or 0))then return end
    if event=='PLAYER_REGEN_ENABLED'and not D.pending then return end
    D.Request()
end)
