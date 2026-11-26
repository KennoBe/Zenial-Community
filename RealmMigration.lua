local Z,L=ZenialCommunity,ZenialCommunity.Logic

local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return seen[value]end
    local out={};seen[value]=out;for key,item in pairs(value)do out[key]=copy(item,seen)end;return out
end
local function realmKey(realm,faction)return string.lower(realm:gsub("%s+","")).."@"..string.lower(faction)end

-- Only run when the live player API demonstrates the surname/realm confusion.
-- Preserve the original values and never overwrite an existing corrected profile.
function Z.MigrateSurnameRealms(root,me,account)
    if not L.Text(me.realm,64)then return end
    local changes,scopes={},{};local rows={}
    for key,row in pairs(me.surnameRealm and account.characters or{})do
        if L.Text(key,260)and type(row)=="table"and L.Text(row.target,113)and L.Text(row.realm,64)and(row.faction=="Alliance"or row.faction=="Horde"or row.faction=="Neutral")then
            local family=row.target:match("^[^ ]+ ([^ ]+)$")
            local canonical=L.ScopeKey(row.target,me.realm,row.faction)
            if family and canonical and string.lower(row.realm)==string.lower(family)and realmKey(row.realm,row.faction)~=realmKey(me.realm,row.faction)then
                rows[#rows+1]={key=key,row=row,canonical=canonical}
            end
        end
    end
    -- Accounts corrected by an earlier version: its backup names the wrong scopes, the account rows the corrected ones.
    -- Their other saved keys (contacts, peers, blocks, notes, events) may still sit under the wrong scope.
    local repair={}
    local saved=type(root.realmCorrectionBackup)=="table"and root.realmCorrectionBackup or nil
    local done=saved and type(saved.remapped)=="table"and saved.remapped or{}
    for key,old in pairs(saved and type(saved.accounts)=="table"and saved.accounts or{})do
        local current=type(old)=="table"and L.Text(old.realm,64)and(old.faction=="Alliance"or old.faction=="Horde"or old.faction=="Neutral")and account.characters[key]
        if type(current)=="table"and L.Text(current.realm,64)and current.faction==old.faction then
            local from,to=realmKey(old.realm,old.faction),realmKey(current.realm,current.faction)
            if from~=to and done[from]~=to then repair[from]=to end
        end
    end
    if #rows==0 and not next(repair)then return end
    table.sort(rows,function(a,b)return a.key<b.key end)
    root.realmCorrectionBackup=type(root.realmCorrectionBackup)=="table"and root.realmCorrectionBackup or{}
    local backup=root.realmCorrectionBackup
    for _,name in ipairs({"accounts","characters","ui","pvpHelp","social","history","profiles","remapped"})do backup[name]=type(backup[name])=="table"and backup[name]or{}end
    if not backup.backupAt and Z.Adapter and Z.Adapter.Now then backup.backupAt=Z.Adapter.Now()end
    for _,entry in ipairs(rows)do
        local row,key,canonical=entry.row,entry.key,entry.canonical
        if not backup.accounts[key]then backup.accounts[key]=copy(row)end
        changes[key]=canonical
        changes[L.ScopeKey(row.target,row.realm,row.faction)]=canonical
        changes[string.lower(row.target).."@"..realmKey(row.realm,row.faction)]=canonical
        local oldScope=realmKey(row.realm,row.faction);scopes[oldScope]=realmKey(me.realm,row.faction)
        account.characters[key]=copy(row);account.characters[key].realm=me.realm
    end
    local function move(bucket,kind)
        if type(bucket)~="table"then return end
        local keys={};for key in pairs(changes)do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys)do local dest=changes[key]
            if key~=dest and bucket[key]~=nil then
                if not backup[kind][key]then backup[kind][key]=copy(bucket[key])end
                if bucket[dest]==nil then bucket[dest]=bucket[key]end
                bucket[key]=nil
            end
        end
    end
    for scope,dest in pairs(repair)do if not scopes[scope]then scopes[scope]=dest end end
    move(root.characters,"characters")
    move(type(root.ui)=="table"and root.ui.characters,"ui")
    move(root.pvpHelp,"pvpHelp")
    account.mainKey=changes[account.mainKey]or account.mainKey
    local mains=type(account.mains)=="table"and account.mains or{}
    for scope,main in pairs(mains)do if changes[main]then mains[scope]=changes[main]end end
    local oldScopes={};for scope in pairs(scopes)do oldScopes[#oldScopes+1]=scope end;table.sort(oldScopes)
    for _,scope in ipairs(oldScopes)do local dest=scopes[scope]
        if mains[scope]and not mains[dest]then mains[dest]=mains[scope]end
        if mains[scope]==account.mainKey then mains[dest]=account.mainKey end
        mains[scope]=nil
        local store=type(root.social)=="table"and root.social[scope]
        if type(store)=="table"then
            if not backup.social[scope]then backup.social[scope]=copy(store)end
            local target=type(root.social[dest])=="table"and root.social[dest]or{favorites={},notes={}};root.social[dest]=target
            for _,field in ipairs({"favorites","notes"})do
                target[field]=type(target[field])=="table"and target[field]or{}
                for key,value in pairs(type(store[field])=="table"and store[field]or{})do local canonical=changes[key]or key;if target[field][canonical]==nil then target[field][canonical]=value end end
            end
            -- Categories and the diary move along; keys of other players are rewritten below.
            for _,part in ipairs({{"categories","contacts"},{"diary","players"}})do
                local source=store[part[1]]
                if type(source)=="table"then
                    if type(target[part[1]])~="table"then target[part[1]]=source
                    else
                        local into=target[part[1]];into[part[2]]=type(into[part[2]])=="table"and into[part[2]]or{}
                        for key,value in pairs(type(source[part[2]])=="table"and source[part[2]]or{})do if into[part[2]][key]==nil then into[part[2]][key]=value end end
                    end
                end
            end
            root.social[scope]=nil
        end
    end
    account.mains=mains
    -- Every saved key of another player or of an own character: same scope prefix, new scope.
    local function map(key)
        if type(key)~="string"then return key end
        if changes[key]then return changes[key]end
        local scope,name=key:match("^([^@:]+@[^@:]+)@(.+)$");local dest=scope and scopes[scope]
        return dest and dest.."@"..name or key
    end
    for _,entry in ipairs(type(root.history)=="table"and type(root.history.entries)=="table"and root.history.entries or{})do
        if type(entry)=="table"then
            for _,field in ipairs({"ownKey","peerKey","contentOwnerKey"})do
                if map(entry[field])~=entry[field]then
                    local id=entry.id or tostring(entry)
                    if not backup.history[id]then backup.history[id]=copy(entry)end
                    entry[field]=map(entry[field])
                end
            end
        end
    end
    -- Moves the entries of a table keyed by player key; an entry that already exists under the new key wins.
    local function keys(bucket,ensure)
        if type(bucket)~="table"then return end
        local list={};for key in pairs(bucket)do if map(key)~=key then list[#list+1]=key end end;table.sort(list)
        for _,key in ipairs(list)do if ensure then ensure()end;local dest=map(key);if bucket[dest]==nil then bucket[dest]=bucket[key]end;bucket[key]=nil end
    end
    local function nested(bucket,ensure)if type(bucket)=="table"then for _,inner in pairs(bucket)do keys(inner,ensure)end end end
    -- Keys of the form "<player key>:<id>" (scheduled events, trade alerts): the player key is everything before the last colon.
    local function tokens(bucket,ensure)
        if type(bucket)~="table"then return end
        local list={};for token in pairs(bucket)do local who,rest;if type(token)=="string"then who,rest=token:match("^(.*):([^:]+)$")end;if who and map(who)~=who then list[#list+1]={token,map(who)..":"..rest}end end
        table.sort(list,function(a,b)return a[1]<b[1]end)
        for _,move in ipairs(list)do if ensure then ensure()end;if bucket[move[2]]==nil then bucket[move[2]]=bucket[move[1]]end;bucket[move[1]]=nil end
    end
    for profileKey,profile in pairs(type(root.characters)=="table"and root.characters or{})do
        if type(profile)=="table"then
            local function ensure()if backup.profiles[profileKey]==nil then backup.profiles[profileKey]=copy(profile)end end
            for _,field in ipairs({"contacts","peers","blocked","groupFollowSeen","favorites","privateNotes","recipeCatalogs"})do keys(profile[field],ensure)end
            for _,field in ipairs({"interests","sentApplications","questInterests","sentQuestApplications"})do nested(profile[field],ensure)end
            if type(profile.applicationAlerts)=="table"then nested(profile.applicationAlerts.group,ensure);nested(profile.applicationAlerts.quest,ensure)end
            for _,field in ipairs({"craftOrders","craftOrderHistory"})do
                for _,row in pairs(type(profile[field])=="table"and profile[field]or{})do if type(row)=="table"and map(row.peer)~=row.peer then ensure();row.peer=map(row.peer)end end
            end
            for _,plan in pairs(type(profile.materialPlans)=="table"and type(profile.materialPlans.plans)=="table"and profile.materialPlans.plans or{})do
                if type(plan)=="table"and type(plan.order)=="table"and map(plan.order.peer)~=plan.order.peer then ensure();plan.order.peer=map(plan.order.peer)end
            end
            if type(profile.tradeStore)=="table"then for _,seen in pairs(type(profile.tradeStore.alertsSeen)=="table"and profile.tradeStore.alertsSeen or{})do tokens(seen,ensure)end end
            local groups=profile.scheduledGroups
            if type(groups)=="table"then
                for _,event in pairs(type(groups.owned)=="table"and groups.owned or{})do
                    if type(event)=="table"then
                        if map(event.ownerKey)~=event.ownerKey then ensure();event.ownerKey=map(event.ownerKey)end
                        keys(event.participants,ensure)
                        for _,participant in pairs(type(event.participants)=="table"and event.participants or{})do if type(participant)=="table"and map(participant.via)~=participant.via then ensure();participant.via=map(participant.via)end end
                    end
                end
                for _,template in pairs(type(groups.templates)=="table"and groups.templates or{})do
                    if type(template)=="table"and type(template.base)=="table"and map(template.base.ownerKey)~=template.base.ownerKey then ensure();template.base.ownerKey=map(template.base.ownerKey)end
                end
                if type(groups.following)=="table"then
                    local list={};for token,follow in pairs(groups.following)do if type(follow)=="table"and map(follow.ownerKey)~=follow.ownerKey then list[#list+1]=token end end;table.sort(list)
                    for _,token in ipairs(list)do
                        ensure();local follow=groups.following[token];follow.ownerKey=map(follow.ownerKey)
                        if type(follow.snapshot)=="table"then follow.snapshot.ownerKey=follow.ownerKey end
                        local dest=follow.ownerKey..":"..tostring(follow.id);if groups.following[dest]==nil then groups.following[dest]=follow end;groups.following[token]=nil
                    end
                    for _,follow in pairs(groups.following)do if type(follow)=="table"then keys(follow.box,ensure)end end
                end
                tokens(groups.reminded,ensure)
            end
        end
    end
    for scope,store in pairs(type(root.social)=="table"and root.social or{})do
        if type(store)=="table"then
            local function ensure()if backup.social[scope]==nil then backup.social[scope]=copy(store)end end
            keys(store.favorites,ensure);keys(store.notes,ensure)
            if type(store.categories)=="table"then keys(store.categories.contacts,ensure)end
            if type(store.diary)=="table"then keys(store.diary.players,ensure)end
        end
    end
    for scope,dest in pairs(scopes)do backup.remapped[scope]=dest end
    if Z.Diagnostics then Z.Diagnostics.Record("identity:realm_migration",#rows,me.realm)end
end
