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
    if not me.surnameRealm or not L.Text(me.realm,64)then return end
    local changes,scopes={},{};local rows={}
    for key,row in pairs(account.characters)do
        if L.Text(key,260)and type(row)=="table"and L.Text(row.target,113)and L.Text(row.realm,64)and(row.faction=="Alliance"or row.faction=="Horde"or row.faction=="Neutral")then
            local family=row.target:match("^[^ ]+ ([^ ]+)$")
            local canonical=L.ScopeKey(row.target,me.realm,row.faction)
            if family and canonical and string.lower(row.realm)==string.lower(family)and realmKey(row.realm,row.faction)~=realmKey(me.realm,row.faction)then
                rows[#rows+1]={key=key,row=row,canonical=canonical}
            end
        end
    end
    if #rows==0 then return end
    table.sort(rows,function(a,b)return a.key<b.key end)
    root.realmCorrectionBackup=type(root.realmCorrectionBackup)=="table"and root.realmCorrectionBackup or{}
    local backup=root.realmCorrectionBackup
    for _,name in ipairs({"accounts","characters","ui","pvpHelp","social","history"})do backup[name]=type(backup[name])=="table"and backup[name]or{}end
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
            root.social[scope]=nil
        end
    end
    account.mains=mains
    for _,entry in ipairs(type(root.history)=="table"and type(root.history.entries)=="table"and root.history.entries or{})do
        if type(entry)=="table"then
            for _,field in ipairs({"ownKey","peerKey","contentOwnerKey"})do
                if changes[entry[field]]then
                    local id=entry.id or tostring(entry)
                    if not backup.history[id]then backup.history[id]=copy(entry)end
                    entry[field]=changes[entry[field]]
                end
            end
        end
    end
    if Z.Diagnostics then Z.Diagnostics.Record("identity:realm_migration",#rows,me.realm)end
end
