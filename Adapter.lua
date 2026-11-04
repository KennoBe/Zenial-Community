local Z = ZenialCommunity
local A, L = {}, Z.Logic; Z.Adapter = A
A.network = {sent=0,ok=0,noResult=0,throttle=0,blocked=0,error=0,received=0}

function A.Safe(...)
    if type(issecretvalue) ~= "function" then return false end
    for i = 1, select("#", ...) do
        local ok, secret = pcall(issecretvalue, select(i, ...))
        if not ok or secret then return false end
    end
    return true
end
function A.PublicTable(v)
    if not A.Safe(v) or type(v) ~= "table" or type(canaccesstable) ~= "function" then return false end
    local ok, accessible = pcall(canaccesstable, v)
    return ok and accessible == true
end
-- Probes only the values actually returned (max five, nil gaps included):
-- the former padding was nil and never secret, so the result contract is unchanged.
local function checked(ok, ...)
    if not ok or type(issecretvalue) ~= "function" then return nil end
    for i = 1, math.min(select("#", ...), 5) do
        local probe, secret = pcall(issecretvalue, (select(i, ...)))
        if not probe or secret then return nil end
    end
    local a, b, c, d, e = ...
    return a, b, c, d, e
end
function A.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return checked(pcall(fn, ...))
end
function A.Now() local n=A.Call(GetServerTime);n=type(n)=="number"and math.floor(n)or nil;return L.Int(n,1,4102444800)and n or 0 end
function A.Clock()
    local fn=GetTimePreciseSec or GetTime;local n=A.Call(fn)
    return type(n)=="number" and n==n and n>=0 and n or 0
end
function A.RuntimeAvailable()
    return type(issecretvalue)=="function"and type(canaccesstable)=="function"
end
-- Bags only. Never infer a zero from a failed call, secret value, missing stack
-- count or a locked stack. Names need not be cached. Bank/alt stock is excluded.
function A.ReadBagInventory()
    local out={counts={},unknown={},slots={},bags={},at=A.Now(),known=false}
    local api=C_Container
    if not A.PublicTable(api)or type(api.GetContainerNumSlots)~="function"or type(api.GetContainerItemInfo)~="function"or type(api.GetContainerItemID)~="function"then return out end
    if not A.Safe(NUM_TOTAL_EQUIPPED_BAG_SLOTS,NUM_BAG_SLOTS)then return out end
    local last=NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    if not A.Safe(last)or not L.Int(last,4,5)then return out end
    for bag=0,last do
        local slots=A.Call(api.GetContainerNumSlots,bag)
        if not L.Int(slots,0,200)then return out end
        if bag==0 and slots==0 then return out end -- inventory not initialized
        out.bags[#out.bags+1]={bag=bag,size=slots}
        for slot=1,slots do
            local ok,id=pcall(api.GetContainerItemID,bag,slot)
            if not ok or not A.Safe(id)or(id~=nil and not L.Int(id,1,10000000))then return out end
            local good,info=pcall(api.GetContainerItemInfo,bag,slot)
            if not good or not A.Safe(info)then return out end
            if info==nil then
                if id then out.unknown[id]=true end
            elseif not A.PublicTable(info)then return out
            elseif not A.Safe(info.itemID,info.stackCount,info.isLocked)then return out
            elseif not L.Int(info.itemID,1,10000000)or info.itemID~=id then return out
            elseif not L.Int(info.stackCount,1,2147483646)or info.isLocked~=false then out.unknown[id]=true
            else
                local n=(out.counts[id]or 0)+info.stackCount
                if n>2147483646 then out.unknown[id]=true else out.counts[id]=n end
            end
            if id then
                local instance;local link=A.Call(api.GetContainerItemLink,bag,slot)
                if Z.CompanionProtocol and type(link)=='string'and#link<=1024 then instance=Z.CompanionProtocol.Source(link)end
                out.slots[#out.slots+1]={bag=bag,slot=slot,itemID=id,instance=instance,quantity=not out.unknown[id]and info and info.stackCount or nil,available=not out.unknown[id]}
            end
        end
    end
    out.known=true;return out
end
-- Retain the exported compatibility entry point. Build metadata is diagnostic
-- only; feature-specific API checks determine whether an operation can run.
A.Build=A.RuntimeAvailable
function A.UnitIdentity(unit)
    local givenOrFull,surname=A.Call(UnitFullName,unit)
    local full=A.Call(GetUnitName,unit,true);local key,target=L.Identity(full)
    if not key or not target:find(" ",1,true)then key,target=L.Identity(givenOrFull)end
    if (not key or not target:find(" ",1,true))and L.Text(givenOrFull,24)and L.Text(surname,24)then
        key,target=L.Identity(givenOrFull.." "..surname)
    end
    if not key or not target:find(" ",1,true)then return nil end
    local family=target:match(" ([^ ]+)$");local localRealm=A.Call(GetRealmName)
    -- Forever identities have a first name and surname. Neither name API return
    -- provides a world scope; only the dedicated API scopes local saved data.
    local realm=L.Text(localRealm,64)and localRealm
    if not realm then return nil end
    local surnameReturn=L.Text(surname,24)and string.lower(surname)==string.lower(family)
    local oldRealm=surnameReturn and string.lower(surname)~=string.lower(realm)and surname or nil
    return key,target,realm,oldRealm
end
function A.Identity()
    local key,target,cleanRealm,oldRealm=A.UnitIdentity("player"); local faction=A.Call(UnitFactionGroup,"player")
    local className,classFile=A.Call(UnitClass,"player"); local level=A.Call(UnitLevel,"player")
    local guild,guid=A.Call(GetGuildInfo,"player"),A.Call(UnitGUID,"player")
    if not key or (faction~="Alliance" and faction~="Horde" and faction~="Neutral") then return nil end
    classFile=L.Text(classFile,16,true) and classFile or ""
    return {key=L.ScopeKey(target,cleanRealm,faction)or key,legacyKey=key,target=target,realm=cleanRealm,surnameRealm=oldRealm,faction=faction,class=L.ClassName(className,classFile),classFile=classFile,
        level=L.Int(level,0,100) and level or 0,guild=L.Text(guild,64,true) and guild or "",guid=L.Text(guid,80,true) and guid or ""}
end
function A.Allowed()
    if not A.RuntimeAvailable() then return false,"Erforderliche Sicherheits-APIs sind nicht verfügbar." end
    if not Z.identityReady or A.Now()==0 then return false,"Charakterdaten sind noch nicht verfügbar." end
    if not Z.registered or not Z.receiveEvent then return false,"Addon-Nachrichten sind nicht verfügbar." end
    if Z.BattleNetTransport and Z.BattleNetTransport.Available()then return true end
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function"or type(C_ChatInfo.InChatMessagingLockdown)~="function"or not Enum or not Enum.SendAddonMessageResult then return false,"Chat-API fehlt." end
    -- Forever reports AreOutgoingAddonChatMessagesRestricted()==true even while
    -- SendAddonMessage itself accepts direct addon whispers.  The actual send
    -- result below is authoritative; only the active chat-security lockdown is
    -- a preflight blocker.
    if A.Call(C_ChatInfo.InChatMessagingLockdown)~=false then return false,"Addon-Nachrichten sind gerade gesperrt." end
    return true
end
function A.Register()
    if not C_ChatInfo or not Enum or not Enum.RegisterAddonMessagePrefixResult then return false end
    local e=Enum.RegisterAddonMessagePrefixResult
    local function register(prefix)local r=A.Call(C_ChatInfo.RegisterAddonMessagePrefix,prefix);return r~=nil and(r==e.Success or r==e.DuplicatePrefix)end
    A.registeredLegacy=register(L.PREFIX);A.registered3=register(L.PREFIX3)
    return A.registeredLegacy and A.registered3
end
local function send(prefix,message,chatType,target)
    local stats=A.network;stats.sent=stats.sent+1
    local function done(result,detail)
        if result=="ok"then stats.lastError=nil end
        if result=="error"then stats.lastFailure=detail;stats.lastFailureAt=A.Now()end
        if Z.Diagnostics then Z.Diagnostics.Record("send:"..result,prefix,chatType,target,detail)end
        return result
    end
    if not A.Safe(message,chatType,target) or type(message)~="string" or #message>240 then stats.error=stats.error+1;return done("error","invalid arguments")end
    local ok,reason=A.Allowed(); if not ok then stats.blocked=stats.blocked+1;return done("blocked",reason)end
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function"or A.Call(C_ChatInfo.InChatMessagingLockdown)~=false then stats.blocked=stats.blocked+1;return done("blocked","Native addon transport unavailable")end
    local called,r=pcall(C_ChatInfo.SendAddonMessage,prefix,message,chatType,target)
    if not called then stats.error=stats.error+1;stats.lastError=L.Text(r,240,true)and r or"Chat-API-Aufruf fehlgeschlagen";return done("error",stats.lastError)end
    if not A.Safe(r)then stats.blocked=stats.blocked+1;return done("blocked","unreadable result")end
    -- Legacy chat implementations return no value on a successful API call.
    -- Count those separately; only a received peer message confirms reachability.
    if r==nil then stats.noResult=stats.noResult+1;return done("ok","no API result")end
    local e=Enum.SendAddonMessageResult
    if r==e.Success or r==true then stats.ok=stats.ok+1;return done("ok",r)elseif r==e.AddonMessageThrottle or r==e.ChannelThrottle then stats.throttle=stats.throttle+1;return done("throttle",r)elseif r==e.AddOnMessageLockdown then stats.blocked=stats.blocked+1;return done("blocked",r)end
    stats.error=stats.error+1;stats.lastCode=r
    local name="unknown";for key,value in pairs(e)do if value==r then name=key;break end end
    stats.lastError="Senden fehlgeschlagen: "..name.." ("..tostring(r)..")"
    return done("error",stats.lastError)
end
function A.Send(wire,target,context)
    if not L.Text(target,113)then return"error"end
    if Z.BattleNetTransport then local result=Z.BattleNetTransport.SendApplication("1",wire,target,context);if result then return result end end
    if Z.Network3 and Z.Network3.jobs and not Z.Network3.TakeLegacyBudget(#wire+32)then return"throttle"end
    return send(L.PREFIX,wire,"WHISPER",target)
end
function A.Send3(wire,chatType,target,context)
    if chatType~="WHISPER"then return"blocked"end
    if Z.BattleNetTransport then return Z.BattleNetTransport.SendApplication("3",wire,target,context)end
    return send(L.PREFIX3,wire,"WHISPER",target)
end
local function shown(v)if v==true then return"true"elseif v==false then return"false"else return"unavailable"end end
function A.NetworkStatus()
    local version,build,_,interface=A.Call(GetBuildInfo);local contacts=0
    for _ in pairs(Z.db and Z.db.contacts or{})do contacts=contacts+1 end
    local stats=A.network
    return{
        "ZENIAL network: build "..tostring(version or"?").." / "..tostring(build or"?").." / "..tostring(interface or"?"),
        "prefix3="..shown(A.registered3).." legacy="..shown(A.registeredLegacy).." event="..shown(Z.receiveEvent).." consent="..shown(Z.db and Z.db.consent).." auto="..shown(Z.db and Z.db.autoDiscovery),
        "transport=direct channel=disabled restricted="..shown(A.Call(C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)).." lockdown="..shown(A.Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)),
        "contacts="..contacts.." sent="..stats.sent.." ok="..stats.ok.." noResult="..stats.noResult.." throttle="..stats.throttle.." blocked="..stats.blocked.." error="..stats.error..(stats.lastCode and" lastCode="..tostring(stats.lastCode)or"")..(stats.lastError and" lastError="..stats.lastError or""),
        "receivedNative="..stats.received,
        "queue3="..tostring(Z.Network3 and#Z.Network3.jobs or 0).." legacyQueue="..tostring(Z.engine and#Z.engine.out or 0).." pending="..tostring(Z.engine and L.Count(Z.engine.pending)or 0).." engine="..(Z.engine and Z.engine.blocked and"blocked"or"ready")..(Z.engine and Z.engine.status~=""and" ("..Z.engine.status..")"or""),
    }
end
function A.DiscoveryTick(force)
    if not Z.db or not Z.db.consent or not Z.db.autoDiscovery then return false end
    if force and Z.CommunityDirectory then Z.CommunityDirectory.RequestScan()end
    if force and Z.Network3 then Z.Network3.nextPresence=0 end
    return true
end
function A.Receive(prefix,payload,channel,sender,target,zoneChannelID,localID,channelName)
    if not A.Safe(prefix,channel)or channel~="WHISPER"then return false end
    if Z.BattleNetTransport and prefix==Z.BattleNetTransport.PREFIX then return Z.BattleNetTransport.Receive(prefix,payload,channel,sender)end
    if not A.Safe(prefix,payload,channel,sender) or(prefix~=L.PREFIX and prefix~=L.PREFIX3)or not Z.engine or not A.RuntimeAvailable() then return false end
    if not Z.db.consent or type(payload)~="string" or type(sender)~="string" or A.Call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)~=false then if Z.Diagnostics then Z.Diagnostics.Record("receive:not_ready",prefix,channel,sender)end;return false end
    A.network.received=A.network.received+1
    if Z.Diagnostics then Z.Diagnostics.Record("receive:raw",prefix,channel,sender,localID,channelName)end
    if Z.BattleNetTransport then
        local route=Z.BattleNetTransport.Route(sender);if not route then return false end
        route.at=A.Clock()
        local peerKey=Z.ResolvePeerKey(sender);local peer=peerKey and Z.db.peers[peerKey]
        if peer then peer.lastContact=A.Now();peer.lastContactClock=A.Clock()end
    end
    if prefix==L.PREFIX3 then return Z.Network3 and Z.Network3.Receive(sender,payload,channel)or false end
    return channel=="WHISPER" and Z.engine:Receive(sender,payload) or false
end
-- Only called with an identity bound to an event sender by the transport.
function A.ReceiveApplication(prefix,payload,sender)
    if not Z.db or not Z.db.consent or not A.RuntimeAvailable()or not A.Safe(prefix,payload,sender)or type(payload)~="string"or#payload>240 then return false end
    if prefix==L.PREFIX3 then return Z.Network3.Receive(sender,payload,"WHISPER")end
    return prefix==L.PREFIX and Z.engine:Receive(sender,payload)or false
end

function A.ScanProfessions()
    if not A.RuntimeAvailable() or not C_SkillInfo then return nil,"SCAN NICHT AUSGEFÜHRT: Öffne zuerst das WoW-Berufsfenster deines Charakters." end
    -- Skill information belongs to the player, even when a foreign recipe link
    -- is open. Require a loaded skill list before treating an empty result as
    -- authoritative; the profession-window API alone can be empty during login.
    local skillCount=A.Call(C_SkillInfo.GetNumSkillLines)
    if not L.Int(skillCount,1,1000)then return nil,"Profession data is not ready yet."end
    if type(C_SkillInfo.GetSkillLineInfo)=="function"then
        local out,seen={},{}
        for index=1,skillCount do
            local p=A.Call(C_SkillInfo.GetSkillLineInfo,index)
            if not A.PublicTable(p)or not A.Safe(p.skillID,p.name,p.rank,p.maxRank,p.isHeader,p.isCollapsed)or type(p.isHeader)~="boolean"then return nil,"Profession data is not ready yet."end
            if p.isCollapsed==true then return nil,"Expand your skill categories to update professions safely."end
            if p.isHeader==false and L.ProfessionNameByID(p.skillID)then
                local row={id=p.skillID,name=L.ProfessionNameByID(p.skillID),rank=p.rank,max=p.maxRank}
                if not L.ValidProfession(row)or seen[row.id]then return nil,"Profession data is not ready yet."end
                out[#out+1]=row;seen[row.id]=true
            end
        end
        if #out>6 then return nil,"Profession data is not ready yet."end
        table.sort(out,function(a,b)return a.name<b.name end);return out,"Berufe aktualisiert."
    end
    local ids=A.Call(C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines);if not A.PublicTable(ids)then return nil,"Profession data is not ready yet."end
    local candidates,required={},{};for id in pairs(L.PROFESSION_NAMES)do candidates[id]=true end
    for _,p in ipairs(Z.db and Z.db.professions or{})do candidates[p.id]=true end
    for _,id in pairs(ids)do if not L.Int(id,1,100000)then return nil,"Profession data is not ready yet."end;candidates[id]=true;required[id]=true end
    local out,seenIDs,byName={},{},{}
    for id in pairs(candidates) do
        if L.Int(id,1,100000) and not seenIDs[id] then
            seenIDs[id]=true
            local ok,p=pcall(C_SkillInfo.GetSkillLineInfoByID,id)
            if not ok or not A.Safe(p)or(p~=nil and not A.PublicTable(p))then return nil,"Profession data is not ready yet."end
            if required[id]and not p then return nil,"Profession data is not ready yet."end
            if p then
                if not A.Safe(p.skillID,p.name,p.rank,p.maxRank,p.isHeader,p.isCollapsed)or type(p.isHeader)~="boolean"then return nil,"Profession data is not ready yet."end
                local row={id=p.skillID,name=L.ProfessionName(p.name),rank=p.rank,max=p.maxRank}
                if p.isHeader~=true and not L.ValidProfession(row)then return nil,"Profession data is not ready yet."end
                if p.isHeader==false and L.ValidProfession(row) then
                    local key=string.lower(row.name)
                    local old=byName[key]
                    if not old then out[#out+1]=row;byName[key]=row
                    elseif row.rank>old.rank or row.rank==old.rank and row.max>old.max then old.id,old.rank,old.max=row.id,row.rank,row.max end
                end
            end
        end
        if #out>6 then return nil,"Profession data is not ready yet."end
    end
    table.sort(out,function(a,b)return a.name<b.name end); return out,"Berufe aktualisiert."
end
local function recipeIDs()
    if not C_TradeSkillUI then return nil end
    local ids=A.Call(C_TradeSkillUI.GetAllRecipeIDs);if A.PublicTable(ids)then return ids,true end
    ids=A.Call(C_TradeSkillUI.GetFilteredRecipeIDs)
    return A.PublicTable(ids)and ids or nil,false
end
function A.ScanRecipes()
    local ids,complete=recipeIDs(); if not ids then return nil,"SCAN NICHT AUSGEFÜHRT: Öffne das gewünschte WoW-Berufsfenster, sodass seine Rezeptliste sichtbar ist." end
    local linked=A.Call(C_TradeSkillUI.IsTradeSkillLinked)
    if linked~=false then return nil,linked==true and"Verlinkte Berufe werden nicht als eigene Rezepte gespeichert."or"Own profession data is not ready yet." end
    local base=A.Call(C_TradeSkillUI.GetBaseProfessionInfo);local profession=A.PublicTable(base)and L.ProfessionName(base.parentProfessionName or base.professionName)or nil
    local out,seen={},{}
    for _,id in pairs(ids) do
        if #out>=L.MAX_RECIPES_PER_PROFESSION then complete=false;break end
        if L.Int(id,1,10000000) and not seen[id] then
            seen[id]=true; local info=A.Call(C_TradeSkillUI.GetRecipeInfo,id)
            if not A.PublicTable(info)then complete=false end
            local learned=A.PublicTable(info)and(info.learned==true or info.isLearned==true)
            if A.PublicTable(info)and info.learned==nil and info.isLearned==nil then complete=false end
            if learned and not L.Text(info.name,96)then complete=false end
            if learned and L.Text(info.name,96) then
                local itemID,itemName=0,""; local output=A.Call(C_TradeSkillUI.GetRecipeOutputItemData,id)
                if A.PublicTable(output) then itemID=tonumber(output.itemID) or 0; local outputName=A.Call(GetItemInfo,itemID); itemName=L.Text(outputName,96,true) and outputName or "" end
                local materials={}; local schematic=A.Call(C_TradeSkillUI.GetRecipeSchematic,id,false)
                if A.PublicTable(schematic) and A.PublicTable(schematic.reagentSlotSchematics) then
                    for _,slot in ipairs(schematic.reagentSlotSchematics)do
                        if A.PublicTable(slot)and A.PublicTable(slot.reagents)then
                            local reagent=slot.reagents[1]
                            if A.PublicTable(reagent)and A.Safe(reagent.itemID,slot.quantityRequired,reagent.quantityRequired)and L.Int(reagent.itemID,1,10000000)then
                                -- Modern schematics put the required amount on the slot.
                                local quantity=slot.quantityRequired
                                if quantity==nil then quantity=reagent.quantityRequired end
                                if not L.Int(quantity,0,100000)then materials={};break end
                                if quantity>0 then materials[#materials+1]=reagent.itemID..":"..quantity end
                            else materials={};break end
                        else materials={};break end
                        if #materials>12 then materials={};break end
                    end
                end
                local recipeProfession=A.Call(C_TradeSkillUI.GetProfessionInfoByRecipeID,id)
                local recipeName=A.PublicTable(recipeProfession)and L.ProfessionName(recipeProfession.parentProfessionName or recipeProfession.professionName)or profession
                local row={id=id,itemID=L.Int(itemID,0,10000000) and itemID or 0,name=info.name,itemName=itemName,profession=recipeName or"",materials=table.concat(materials,",")}
                if L.ValidRecipe(row) then out[#out+1]=row else complete=false end
            end
        elseif not L.Int(id,1,10000000)then complete=false end
    end
    profession=profession or(out[1]and out[1].profession)
    if not L.Text(profession,64)then return nil,"SCAN NICHT AUSGEFÜHRT: Der geöffnete Beruf konnte nicht erkannt werden. Schließe fremde Links und öffne dein eigenes Berufsfenster erneut." end
    if #out==0 and not complete then return nil,"SCAN NICHT AUSGEFÜHRT: In diesem geöffneten Berufsfenster wurden keine gelernten Rezepte gefunden." end
    for _,r in ipairs(out)do r.profession=profession end
    table.sort(out,function(a,b)return a.name<b.name end);return out,Z.T("%d recipes found for %s.",#out,Z.T(profession)),profession,complete
end
function A.GetQuests()
    local out={}; if not C_QuestLog then return out end; local n=A.Call(C_QuestLog.GetNumQuestLogEntries) or 0
    for i=1,math.min(n,100) do local q=A.Call(C_QuestLog.GetInfo,i); if A.PublicTable(q) and not q.isHeader and L.Int(q.questID,1,10000000) and L.Text(q.title,96) then out[#out+1]={id=q.questID,title=q.title,level=L.Int(q.level,0,100) and q.level or 0} end end
    return out
end
function A.ResolveItem(text)
    if Z.Items then return Z.Items.Resolve(text)end
    if type(text)~="string" or #text>256 or not A.Safe(text) then return nil end
    local id=tonumber(text:match("|Hitem:(%d+)") or text:match("^%s*(%d+)%s*$")); if not id and not L.Text(text,96) then return nil end
    local name=A.Call(GetItemInfo,id or text)
    local instant=A.Call(GetItemInfoInstant,id or text); id=id or instant or 0; name=L.Text(name,96,true) and name or text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H.-|h",""):gsub("|h","")
    if not L.Text(name,96) then return nil end
    return L.Int(id,0,10000000) and id or 0,name
end
function A.GroupState()
    local total=A.Call(GetNumGroupMembers) or 0; local counts={TANK=0,HEALER=0,DAMAGER=0}; local units={}
    if A.Call(IsInRaid)==true then for i=1,total do units[#units+1]="raid"..i end else units[1]="player"; for i=1,math.max(0,total-1) do units[#units+1]="party"..i end end
    for _,unit in ipairs(units) do local role=A.Call(UnitGroupRolesAssigned,unit); if counts[role] then counts[role]=counts[role]+1 end end
    return {total=math.max(1,total),tank=counts.TANK,healer=counts.HEALER,dd=counts.DAMAGER,canInvite=A.Call(UnitIsGroupLeader,"player")==true or total==0}
end
function A.GroupRoles() local s=A.GroupState(); local out={}; if s.tank>0 then out[#out+1]="TANK="..s.tank end; if s.healer>0 then out[#out+1]="HEALER="..s.healer end; if s.dd>0 then out[#out+1]="DAMAGER="..s.dd end; return #out>0 and table.concat(out,";") or (s.total>1 and "UNASSIGNED" or "SOLO") end
function A.GroupMembers()
    local out={};local total=A.Call(GetNumGroupMembers)or 0;if total<2 then return out end;local units={}
    if A.Call(IsInRaid)==true then for i=1,total do units[#units+1]="raid"..i end else for i=1,total-1 do units[#units+1]="party"..i end end
    for _,unit in ipairs(units)do local key,full,realm=A.UnitIdentity(unit);if key then local faction=A.Call(UnitFactionGroup,unit)or(ZenialCommunity.me and ZenialCommunity.me.faction);out[L.ScopeKey(full,realm,faction)or key]=full end end
    return out
end
function A.Invite(target)
    if not L.Text(target,113) then return false,"Ungültiger Charakter." end
    local key=Z.ResolvePeerKey and Z.ResolvePeerKey(target)
    if not key or not Z.IsOnline(key)then return false,"Spieler ist nicht erreichbar."end
    if not A.GroupState().canInvite then return false,"Du hast kein Einladungsrecht." end
    local fn=C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit; if type(fn)~="function" then return false,"Einladen ist nicht verfügbar." end
    local guard=Z.WhisperGuard
    -- This is an explicit native invitation. Whisper correlation is optional:
    -- missing chat filters or a recent manual whisper must not block the click.
    local tracked=guard and guard.Begin(target,"invite")
    local ok,result=pcall(fn,target)
    if not ok or result==false then if tracked then guard.Undo(target)end;return false,"Einladen fehlgeschlagen."end
    return true
end
function A.InvitePvp(target)
    local state=A.GroupState()
    if not state.canInvite then return false,"Du hast kein Einladungsrecht." end
    local raid=A.Call(IsInRaid)==true;local limit=raid and 40 or 5
    if state.total>=limit then return false,raid and"Der Schlachtzug ist voll."or"Die Gruppe ist voll." end
    return A.Invite(target)
end
function A.IsDeadOrGhost() return A.Call(UnitIsDeadOrGhost,"player")==true end
function A.OpenWorld()
    local _,instanceType=A.Call(GetInstanceInfo)
    return instanceType=="none"
end
local function vectorXY(v)
    if not A.PublicTable(v) then return nil end
    local x,y
    if type(v.GetXY)=="function" then x,y=A.Call(v.GetXY,v) end
    x=x or v.x;y=y or v.y
    if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<0 or x>1 or y<0 or y>1 then return nil end
    return math.floor(x*10000+.5),math.floor(y*10000+.5)
end
function A.CurrentMapID()
    local id=A.Call(C_Map and C_Map.GetBestMapForUnit,"player")
    return L.Int(id,1,1000000) and id or 0
end
function A.PlayerLocation()
    local mapID=A.CurrentMapID();local area=A.Call(GetZoneText);local subzone=A.Call(GetSubZoneText)
    area=L.Text(area,64,true) and area or "";subzone=L.Text(subzone,64,true) and subzone or ""
    local instance=Z.DungeonData and Z.DungeonData.Current()
    return {mapID=mapID,area=area,subzone=subzone,instanceID=instance and instance.id,instanceName=instance and instance.name,entrance=instance and instance.entrance}
end
-- Community positions are deliberately coarse (0.1% of the current zone).
-- Native player coordinates only; a corpse or an instanced map is not a member position.
function A.MapPosition()
    if not A.OpenWorld()then return{mapID=0,hasPos=false,x=0,y=0}end
    local mapID=A.CurrentMapID();local point
    if mapID>0 then point=A.Call(C_Map and C_Map.GetPlayerMapPosition,mapID,"player")end
    local x,y=vectorXY(point)
    if not x then return{mapID=0,hasPos=false,x=0,y=0}end
    return{mapID=mapID,hasPos=true,x=math.floor(x/10+.5)*10,y=math.floor(y/10+.5)*10}
end
function A.PvpLocation(corpse)
    local location=A.PlayerLocation();local mapID,area,subzone=location.mapID,location.area,location.subzone
    local point
    if mapID>0 then
        if corpse and C_DeathInfo then point=A.Call(C_DeathInfo.GetCorpseMapPosition,mapID) end
        if not point then point=A.Call(C_Map and C_Map.GetPlayerMapPosition,mapID,"player") end
    end
    local x,y=vectorXY(point)
    return {mapID=mapID,area=area,subzone=subzone,hasPos=x~=nil,x=x or 0,y=y or 0,layerID=Z.CommunityLayer and Z.CommunityLayer.Own(mapID)or nil}
end
function A.PvpEnemy()
    if A.Call(UnitExists,"target")~=true or A.Call(UnitIsPlayer,"target")~=true or A.Call(UnitCanAttack,"player","target")~=true then return nil end
    local _,name=A.UnitIdentity("target");if not name then name=A.Call(GetUnitName,"target",true)or A.Call(UnitName,"target") end
    if not L.Text(name,80) then return nil end
    local className,classFile=A.Call(UnitClass,"target");local level=A.Call(UnitLevel,"target");local faction=A.Call(UnitFactionGroup,"target")
    return {name=name,class=L.ClassName(className,classFile),level=L.Int(level,0,100) and level or 0,faction=L.Text(faction,16,true) and faction or ""}
end
function A.ShowMap(mapID)
    if not L.Int(mapID,1,1000000) then return false end
    if type(OpenWorldMap)=="function" then return pcall(OpenWorldMap,mapID) end
    if WorldMapFrame then
        local ok=pcall(function()if type(WorldMapFrame.SetMapID)=="function"then WorldMapFrame:SetMapID(mapID)end;if type(ShowUIPanel)=="function"then ShowUIPanel(WorldMapFrame)else WorldMapFrame:Show()end end)
        return ok
    end
    return false
end
function A.SetWaypoint(mapID,x,y)
    if not (L.Int(mapID,1,1000000) and L.Int(x,0,10000) and L.Int(y,0,10000) and C_Map and type(C_Map.SetUserWaypoint)=="function" and UiMapPoint and type(UiMapPoint.CreateFromCoordinates)=="function") then return false,"Kein gültiger Kartenpunkt." end
    if type(C_Map.CanSetUserWaypointOnMap)=="function" and A.Call(C_Map.CanSetUserWaypointOnMap,mapID)~=true then return false,"Auf dieser Karte ist kein Wegpunkt möglich." end
    local point=A.Call(UiMapPoint.CreateFromCoordinates,mapID,x/10000,y/10000);if not A.PublicTable(point) then return false,"Kartenpunkt nicht verfügbar." end
    local ok=pcall(C_Map.SetUserWaypoint,point);if ok and type(C_SuperTrack)~="nil" and type(C_SuperTrack.SetSuperTrackedUserWaypoint)=="function" then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
    return ok,ok and nil or"Wegpunkt konnte nicht gesetzt werden."
end
function A.Whisper(target)
    if not A.Safe(target)or not L.Identity(target)then return false end
    -- Configure WHISPER directly so full Forever names and the selected chat
    -- window cannot change the recipient or choose another whisper channel.
    if ChatFrameUtil and type(ChatFrameUtil.ChooseBoxForSend)=="function"and type(ChatFrameUtil.ActivateChat)=="function"then
        local ok,box=pcall(ChatFrameUtil.ChooseBoxForSend)
        if ok and box and type(box.SetChatType)=="function"and type(box.SetTellTarget)=="function"and type(box.SetText)=="function"then
            return pcall(function()
                box:SetChatType("WHISPER");box:SetTellTarget(target);box:SetText("")
                ChatFrameUtil.ActivateChat(box)
            end)
        end
    end
    local command="/w "..target.." "
    if ChatFrameUtil and type(ChatFrameUtil.OpenChat)=="function"then return pcall(ChatFrameUtil.OpenChat,command)end
    if type(ChatFrame_OpenChat)=="function"then return pcall(ChatFrame_OpenChat,command)end
    return false
end
function A.PlayApplicationSound()
    local id=SOUNDKIT and (SOUNDKIT.TELL_MESSAGE or SOUNDKIT.READY_CHECK)
    if not id or not C_Sound or type(C_Sound.PlaySound)~="function" then return false end
    return pcall(C_Sound.PlaySound,id)
end
-- Plain text for contexts without texture markup: deDE g/s/k (Kupfer), other locales g/s/c.
function A.MoneyPlain(copper) copper=math.floor(tonumber(copper) or 0); return math.floor(copper/10000).."g "..math.floor(copper%10000/100).."s "..(copper%100)..(A.Call(GetLocale)=="deDE"and"k"or"c") end
-- All callers feed FontStrings, so coin icons are used when the client returns a string; otherwise plain text.
function A.MoneyText(copper) copper=math.floor(tonumber(copper) or 0); local coins=A.Call(GetCoinTextureString,copper); return type(coins)=="string"and coins~=""and coins or A.MoneyPlain(copper) end
