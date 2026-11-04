-- Private account-scoped data. No profile field or transport handler uses this store.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local C={VERSION=2,MAX_CONTACTS=1000,MAX_CATEGORIES=20};Z.SocialCategories=C
C.ORDER={"TANK","HEALER","DAMAGER","RELIABLE"}
local DEFAULTS={{id="TANK",name="Top Tank"},{id="HEALER",name="Top Heal"},{id="DAMAGER",name="Top DPS"},{id="RELIABLE",name="Nice Guy"}}
local LEGACY={ENCHANTER="Enchanter",LEVELING="Leveling partner"}
local function definitions(raw)
    local out,ids,names={},{},{}
    for inspected,d in ipairs(type(raw)=='table'and raw or DEFAULTS)do
        if inspected>100 then break end
        if #out<C.MAX_CATEGORIES and type(d)=='table'and type(d.id)=='string'and #d.id<=32 and d.id:match('^[A-Z][A-Z%d_]*$')and L.Text(d.name,32)and d.name:find('%S')and not ids[d.id]and not names[string.lower(d.name)]then
            out[#out+1]={id=d.id,name=d.name};ids[d.id]=true;names[string.lower(d.name)]=true
        end
    end
    return out,ids
end
local function targetMatches(key,target)
    if not L.ValidIdentityKey(key)then return false end
    local realm,faction=key:match("^([^@]+)@([^@]+)@")
    return realm and L.ScopeKey(target,realm,faction)==key or false
end
local function changed()
    C.revision=(C.revision or 0)+1
    if Z.MarkDirty then Z.MarkDirty("private categories")end
end
function C.Label(id)
    for _,d in ipairs(C.store and C.store.definitions or DEFAULTS)do if d.id==id then return d.name end end
    return id or''
end
local function syncOrder()
    C.ORDER={};for _,d in ipairs(C.store.definitions)do C.ORDER[#C.ORDER+1]=d.id end
end
function C.Initialize()
    local raw=Z.Social.store.categories
    C.readOnly=type(raw)=="table"and raw.version~=nil and raw.version~=1 and raw.version~=C.VERSION
    C.cache={};C.cacheSize=0;C.revision=0
    if C.readOnly then C.store={version=C.VERSION,definitions=definitions(nil),seq=0,contacts={}}
    else
        local defs,allowed=definitions(type(raw)=='table'and raw.version==C.VERSION and type(raw.definitions)=='table'and raw.definitions or nil)
        local store={version=C.VERSION,definitions=defs,seq=type(raw)=='table'and L.Int(raw.seq,0,2147483646)and raw.seq or 0,contacts={}}
        local source=type(raw)=="table"and(type(raw.contacts)=="table"and raw.contacts or raw)or{}
        local inspected=0
        for key,row in pairs(source)do
            inspected=inspected+1;if inspected>5000 then break end
            if type(row)=="table"and L.Count(store.contacts)<C.MAX_CONTACTS then
                local contact=Z.db.contacts[key];local target=row.target or(contact and contact.target)
                if targetMatches(key,target)then
                    local tags={};local input=type(row.tags)=="table"and row.tags or row
                    if type(raw)~='table'or raw.version~=C.VERSION then
                        for id,name in pairs(LEGACY)do if input[id]==true and not allowed[id]then defs[#defs+1]={id=id,name=Z.T(name)};allowed[id]=true end end
                    end
                    for id in pairs(allowed)do if input[id]==true then tags[id]=true end end
                    if next(tags)then store.contacts[key]={target=target,tags=tags}end
                end
            end
        end
        C.store=store;Z.Social.store.categories=store
    end
    syncOrder()
    -- Validated alias used only by eviction. Core.Load never imports this field.
    Z.db.privateCategories=C.store.contacts
end
function C.Has(key,id)
    local row=C.store and C.store.contacts[key]
    return row~=nil and(id==nil or row.tags[id]==true)or false
end
function C.Text(key)
    local out={};for _,id in ipairs(C.ORDER)do if C.Has(key,id)then out[#out+1]=C.Label(id)end end
    return table.concat(out,", ")
end
function C.Set(key,id,enabled)
    if C.readOnly then return nil,"Private categories use a newer format."end
    local known=false;for _,d in ipairs(C.store.definitions)do if d.id==id then known=true end end
    if not known or type(enabled)~="boolean"then return nil,"Invalid private category."end
    local row=C.store.contacts[key];local contact=Z.db.contacts[key]
    if key==Z.me.key or Z.db.blocked[key]or not targetMatches(key,row and row.target or contact and contact.target)then return nil,"Select an unblocked contact."end
    -- Removing the last shared tag on an alt keeps that explicitly selected
    -- contact locally accessible, including its favorite and private note.
    if row and not contact and not enabled and row.tags[id]and L.Count(row.tags)==1 then
        local realm,faction=key:match("^([^@]+)@([^@]+)@")
        if L.Contact(Z.db,row.target,"Private contact",false,realm,faction)~=key then return nil,"Contact storage is full."end
    end
    if not row and enabled then
        if L.Count(C.store.contacts)>=C.MAX_CONTACTS then return nil,"Maximum 1,000 categorized contacts."end
        row={target=contact.target,tags={}};C.store.contacts[key]=row
    end
    if row then row.tags[id]=enabled and true or nil;if not next(row.tags)then C.store.contacts[key]=nil end end
    changed();return true
end
function C.Forget(key)
    if not C.readOnly and C.store.contacts[key]then C.store.contacts[key]=nil;changed()end
end
local function validName(name,except)
    if not L.Text(name,32)then return nil,'Category name must be 1 to 32 bytes.'end
    name=name:match('^%s*(.-)%s*$');if name==''then return nil,'Enter a category name.'end
    for _,d in ipairs(C.store.definitions)do if d.id~=except and string.lower(d.name)==string.lower(name)then return nil,'This category name already exists.'end end
    return name
end
function C.Add(name)
    if C.readOnly then return nil,'Private categories use a newer format.'end
    local value,why=validName(name);if not value then return nil,why end
    if #C.store.definitions>=C.MAX_CATEGORIES then return nil,'Maximum 20 private categories.'end
    local used={};for _,d in ipairs(C.store.definitions)do used[d.id]=true end
    local id
    repeat
        if C.store.seq>=2147483646 then return nil,'Category ID limit reached.'end
        C.store.seq=C.store.seq+1;id='C'..string.format('%d',C.store.seq)
    until not used[id]
    C.store.definitions[#C.store.definitions+1]={id=id,name=value};syncOrder();changed();return id
end
function C.Rename(id,name)
    if C.readOnly then return nil,'Private categories use a newer format.'end
    local value,why=validName(name,id);if not value then return nil,why end
    for _,d in ipairs(C.store.definitions)do if d.id==id then d.name=value;changed();return true end end
    return nil,'Invalid private category.'
end
function C.Remove(id)
    if C.readOnly then return nil,'Private categories use a newer format.'end
    local index;for i,d in ipairs(C.store.definitions)do if d.id==id then index=i end end
    if not index then return nil,'Invalid private category.'end
    -- Materialize a shared old contact before removing its last category. Keep
    -- favorites and notes accessible; a failed materialization leaves all tags.
    for key,row in pairs(C.store.contacts)do
        if row.tags[id]and L.Count(row.tags)==1 and not Z.db.contacts[key]then
            local realm,faction=key:match('^([^@]+)@([^@]+)@')
            if L.Contact(Z.db,row.target,'Private contact',false,realm,faction)~=key then return nil,'Contact storage is full.'end
        end
    end
    for key,row in pairs(C.store.contacts)do row.tags[id]=nil;if not next(row.tags)then C.store.contacts[key]=nil end end
    table.remove(C.store.definitions,index);syncOrder();changed();return true
end
function C.LastTogether(key)
    if not L.ValidIdentityKey(key)or Z.db.blocked[key]then return nil end
    local H=Z.History;local now=A.Now();local cached=C.cache[key]
    if not L.Int(now,1,4102444800)then return nil end
    if cached and cached.revision==(H.revision or 0)and cached.untilAt>now then return cached.at end
    local newest
    for _,e in ipairs(H.byPeer and H.byPeer[key]or{})do
        local realm,faction=e.ownKey:match("^([^@]+)@([^@]+)@")
        if e.event=="joined"and e.observedAt and realm==string.lower((Z.me.realm or""):gsub("%s+",""))and faction==string.lower(Z.me.faction)
            and e.at>=now-H.RETENTION and e.observedAt<=now and e.observedAt>=now-H.RETENTION and(not newest or e.observedAt>newest)then newest=e.observedAt end
    end
    if not cached then if C.cacheSize>=L.MAX_CONTACTS then C.cache={};C.cacheSize=0 end;C.cacheSize=C.cacheSize+1 end
    C.cache[key]={revision=H.revision or 0,untilAt=now+5,at=newest};return newest
end
function C.Reason(key)
    if Z.db.blocked[key]then return""end
    local out={};local tags=C.Text(key);if tags~=""then out[#out+1]=Z.T("Your private categories:").." "..tags end
    local at=C.LastTogether(key)
    if at then out[#out+1]=Z.T("Previously observed together in a group.");out[#out+1]=Z.T("Last together %d days ago.",math.floor((A.Now()-at)/86400))end
    return table.concat(out,"\n")
end
function C.Matches(key,id)
    if Z.db.blocked[key]then return false end
    if id=="ALL"then return true end
    if id=="RECONTACT"then return C.Has(key)or C.LastTogether(key)~=nil end
    return C.Has(key,id)
end
return C
