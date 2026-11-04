-- Bounded local daily counters, independent of whether the companion is open.
-- Source hints only classify observed deltas; they never create money or XP.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local R={};Z.CompanionProgress=R
local function number(v)return A.Safe(v)and type(v)=='number'and v==v and v>=0 and v<1e12 and math.floor(v)or nil end
local function read(fn,...)return number(A.Call(fn,...))end
local function text(v)return A.Safe(v)and type(v)=='string'and#v<=1024 and v or nil end
local function day()return A.Call(date,'%Y-%m-%d',A.Now())end
local function touch(row)row.revision=row.revision+1 end
local function ordinal(key)
    if type(key)~='string'then return end
    local year,month,date=key:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year,month,date=tonumber(year),tonumber(month),tonumber(date)
    if not year or month<1 or month>12 then return end
    local leap=year%4==0 and(year%100~=0 or year%400==0)
    local lengths={31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31}
    if date<1 or date>lengths[month]then return end
    local y=year-1;local result=365*y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)+date
    for i=1,month-1 do result=result+lengths[i]end;return result
end
local function bucket(key)
    local row=R.record.days[key]
    if not row then row={day=key,revision=1,levels=0,xp={},income={},expenses={},transfersIn=0,transfersOut=0,professions={}};R.record.days[key]=row end
    return row
end
function R.Prune()
    if not R.record then return end
    local current=ordinal(day());local keys={}
    for key in pairs(R.record.days)do
        local value=ordinal(key)
        if not value or current and(value<current-34 or value>current)then R.record.days[key]=nil else keys[#keys+1]=key end
    end
    table.sort(keys)
    for i=1,math.max(0,#keys-35)do R.record.days[keys[i]]=nil end
end
local function add(kind,amount)
    if not amount or amount<=0 then return end
    R.pending[#R.pending+1]={kind=kind,amount=amount,at=A.Clock(),day=day()}
    if#R.pending>32 then R.Flush(true)end
end
local function hint(kind,source,amount)
    amount=number(amount);if not amount or amount<=0 then return end
    R.hints[#R.hints+1]={kind=kind,source=source,amount=amount,at=A.Clock()}
    while#R.hints>32 do table.remove(R.hints,1)end
end
function R.Flush(force)
    if not R.record then return end
    local now=A.Clock();local remaining={}
    for _,entry in ipairs(R.pending)do
        if force or now-entry.at>=1 then
            local row=bucket(entry.day);local left=entry.amount
            if entry.unknownThresholds then
                left=0
                for _,credit in ipairs(R.hints)do if credit.kind=='xp'and math.abs(credit.at-entry.at)<=2 then left=left+credit.amount end end
            end
            for _,credit in ipairs(R.hints)do
                if credit.kind==entry.kind and math.abs(credit.at-entry.at)<=2 and credit.amount>0 then
                    local amount=math.min(left,credit.amount);left=left-amount;credit.amount=credit.amount-amount
                    if credit.source=='transferIn'then row.transfersIn=row.transfersIn+amount
                    elseif credit.source=='transferOut'then row.transfersOut=row.transfersOut+amount
                    else row[entry.kind][credit.source]=(row[entry.kind][credit.source]or 0)+amount end
                    if left==0 then break end
                end
            end
            if left>0 then row[entry.kind].other=(row[entry.kind].other or 0)+left end
            touch(row)
        else remaining[#remaining+1]=entry end
    end
    R.pending=remaining
    local credits={};for _,credit in ipairs(R.hints)do if credit.amount>0 and now-credit.at<=2 then credits[#credits+1]=credit end end;R.hints=credits
    R.Prune()
end
function R.Sample(deferLevel)
    if not R.record then return end
    local key=day();if not text(key)then return end;bucket(key)
    local money=read(GetMoney)
    if money then if R.money then local delta=money-R.money;add(delta<0 and'expenses'or'income',math.abs(delta))end;R.money=money
    else R.money=nil end
    local level,xp,maximum=read(UnitLevel,'player'),read(UnitXP,'player'),read(UnitXPMax,'player')
    if level and xp and maximum then
      local wrapped=R.level==level and R.xp and xp<R.xp
      if wrapped then R.xpDropAt=R.xpDropAt or A.Clock()else R.xpDropAt=nil end
      -- XP and level updates can arrive separately. Preserve the old level's
      -- threshold until a wrap has settled; a lasting reset starts a baseline.
      if wrapped and A.Clock()-R.xpDropAt>=2 then R.level,R.xp,R.maximum=level,xp,maximum;R.xpDropAt=nil
      elseif not wrapped and(not deferLevel or not R.level or level==R.level)then
        if R.level and R.xp and R.maximum then
            local gained=level-R.level
            if gained>0 then local row=bucket(key);row.levels=row.levels+gained;touch(row)end
            local delta=level==R.level and xp-R.xp or gained==1 and R.maximum-R.xp+xp or 0
            add('xp',math.max(0,delta))
            if gained>1 then R.pending[#R.pending+1]={kind='xp',amount=0,unknownThresholds=true,at=A.Clock(),day=key}end
        end
        R.level,R.xp,R.maximum=level,xp,maximum
      end
    else R.level=nil;R.xp=nil;R.maximum=nil;R.xpDropAt=nil end
    if A.Clock()>=(R.skillDue or 0)then
        R.skillDue=A.Clock()+2
        local professions=A.ScanProfessions()
        if type(professions)=='table'then
            local nextRanks={}
            for _,p in ipairs(professions)do
                local id,rank=number(p.id),number(p.rank);local name=text(p.name)
                if id and id>0 and rank and name and#name<=64 then
                    nextRanks[id]=rank
                    local before=R.ranks and R.ranks[id]
                    local gain=R.ranks and rank-(before or 0)or 0
                    if gain>0 then
                        local row=bucket(key);local found
                        for _,skill in ipairs(row.professions)do if skill.id==id then found=skill;break end end
                        if not found and#row.professions<12 then found={id=id,name=name,points=0};row.professions[#row.professions+1]=found end
                        if found then found.points=found.points+gain;touch(row)end
                    end
                end
            end
            R.ranks=nextRanks
        else R.ranks=nil end
    end
    R.Prune()
end
-- Native localized format matcher, including positional placeholders and %%.
local function matchFormat(format,message)
    if not text(format)or not text(message)then return end
    local parts,captures={},{};local i,arg=1,0
    while i<=#format do
        local c=format:sub(i,i)
        if c=='%'then
            if format:sub(i+1,i+1)=='%'then parts[#parts+1]='%%';i=i+2
            else
                local rest=format:sub(i);local token,index,kind=rest:match('^(%%(%d+)%$([sd]))')
                if not token then token,kind=rest:match('^(%%([sd]))');arg=arg+1;index=arg end
                if not token then return end
                parts[#parts+1]=kind=='d'and'(%d+)'or'(.-)';captures[#captures+1]={kind=kind,index=tonumber(index)};i=i+#token
            end
        else parts[#parts+1]=c:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');i=i+1 end
    end
    local values={message:match('^'..table.concat(parts)..'$')};if#values==0 then return end
    local numeric,strings={},{ }
    for n,info in ipairs(captures)do if info.kind=='d'then numeric[info.index]=number(tonumber(values[n]))else strings[info.index]=values[n]end end
    return numeric,strings
end
local function firstNumber(values)
    local first;for index in pairs(values or{})do if not first or index<first then first=index end end
    return first and values[first]
end
local function lootMoney(message)
    for _,key in ipairs({'YOU_LOOT_MONEY','YOU_LOOT_MONEY_GUILD','LOOT_MONEY_SPLIT','LOOT_MONEY_SPLIT_GUILD'})do
        local _,strings=matchFormat(_G[key],message)
        if strings and strings[1]then
            local value=strings[1]:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','');local total=0
            -- Amount templates are locale-specific. Only fully parsed coin text counts.
            for _,coin in ipairs({{'GOLD_AMOUNT',10000},{'SILVER_AMOUNT',100},{'COPPER_AMOUNT',1}})do
                local format=_G[coin[1]]
                if text(format)then
                    local escaped=format:gsub('([%^%$%(%)%.%[%]%*%+%-%?])','%%%1'):gsub('%%d','(%%d+)')
                    value=value:gsub(escaped,function(n)total=total+(tonumber(n)or 0)*coin[2];return''end)
                end
            end
            if total>0 and value:match('^%s*$')then return total end
        end
    end
end
local function ownAlt(target)
    target=text(target);if not target then return false end
    target=target:lower()
    for _,c in pairs(Z.account and Z.account.characters or{})do
        if c.realm==Z.me.realm and c.faction==Z.me.faction and type(c.target)=='string'and c.target:lower()==target then return true end
    end
    return false
end
function R.OnEvent(event,...)
    if not R.record then return end
    R.Sample(true)
    if event=='QUEST_TURNED_IN'then local _,xp,money=...;hint('xp','quest',xp);hint('income','quest',money)
    elseif event=='CHAT_MSG_COMBAT_XP_GAIN'then
        local message=...
        for _,format in ipairs(R.xpFormats or{})do
            local values=matchFormat(format,message)
            if values then hint('xp','loot',firstNumber(values));break end
        end
    elseif event=='CHAT_MSG_MONEY'then hint('income','loot',lootMoney(...))
    elseif event=='CHAT_MSG_SYSTEM'then local values=matchFormat(ERR_ZONE_EXPLORED_XP,...);if values then hint('xp','exploration',firstNumber(values))end
    elseif event=='SEND_MAIL_MONEY_CHANGED'then R.mailMoney=read(GetSendMailMoney)
    elseif event=='MAIL_SEND_SUCCESS'then
        local sent=R.mailSent
        if sent then hint('expenses',sent.own and'transferOut'or'mail',sent.amount)end
        R.mailMoney=nil;R.mailSent=nil
    elseif event=='MAIL_FAILED'or event=='MAIL_CLOSED'then R.mailMoney=nil;R.mailSent=nil
    elseif event=='MAIL_INBOX_UPDATE'or event=='MAIL_SHOW'then
        R.inbox={};local count=read(GetInboxNumItems)or 0
        for i=1,math.min(count,100)do local _,_,sender,subject,amount=A.Call(GetInboxHeaderInfo,i);if number(amount)and amount>0 then R.inbox[i]={amount=amount,own=ownAlt(sender),sender=text(sender),subject=text(subject)}end end
    elseif event=='PLAYER_LOGOUT'then R.Flush(true)end
end
local function hooks()
    if R.hooked or type(hooksecurefunc)~='function'then return end;R.hooked=true
    local function hook(owner,key,callback)if type(owner)=='table'and type(owner[key])=='function'then pcall(hooksecurefunc,owner,key,callback)end end
    hook(_G,'SendMail',function(target)R.mailSent={own=ownAlt(target),amount=read(GetSendMailMoney)}end)
    hook(_G,'TakeInboxMoney',function(index)
        local mail=R.inbox and R.inbox[index];if not mail then return end
        local _,_,sender,subject,amount=A.Call(GetInboxHeaderInfo,index)
        if read(GetMoney)and number(amount)==0 and text(sender)==mail.sender and text(subject)==mail.subject then
            local before=#R.pending;R.Sample(true)
            for i=before+1,#R.pending do local entry=R.pending[i]
                if entry.kind=='income'and entry.amount==mail.amount then hint('income',mail.own and'transferIn'or'mail',mail.amount);R.inbox[index]=nil;break end
            end
        end
    end)
    -- Only reclassify an immediate, observed movement after the exact action.
    -- A window being open is never enough to assign a source.
    local function action(kind,source)
        return function()
            if not R.record then return end;local before=#R.pending;R.Sample()
            for i=before+1,#R.pending do local entry=R.pending[i];if entry.kind==kind then hint(kind,source,entry.amount)end end
        end
    end
    hook(_G,'BuyMerchantItem',action('expenses','vendor'))
    hook(_G,'RepairAllItems',action('expenses','repair'))
    hook(_G,'BuyTrainerService',action('expenses','training'))
    hook(_G,'TakeTaxiNode',action('expenses','travel'))
end
function R.Initialize()
    if not ZenialCommunityDB or not Z.me or Z.offlineOnly then return end
    local root=ZenialCommunityDB
    if root.progress~=nil and(type(root.progress)~='table'or root.progress.version~=1)then return end
    root.progress=root.progress or{version=1,characters={}}
    if type(root.progress.characters)~='table'then return end
    local key=Z.storageKey or Z.me.key
    local record=root.progress.characters[key]
    if type(record)~='table'then record={startedAt=A.Now(),days={}};root.progress.characters[key]=record end
    if type(record.days)~='table'then return end
    if R.record==record then return end -- slash commands may initialize the addon again.
    R.record=record;R.pending={};R.hints={};R.money=nil;R.level=nil;R.ranks=nil;R.skillDue=0;R.cursor=0;R.turn=false
    R.xpFormats={}
    for key,format in pairs(_G)do
        if type(key)=='string'and key:match('^COMBATLOG_XPGAIN_')and not key:find('QUEST',1,true)and not key:find('UNNAMED',1,true)and text(format)then R.xpFormats[#R.xpFormats+1]=format end
    end
    R.Sample();hooks()
    if not R.frame then
        R.frame=CreateFrame('Frame')
        for _,event in ipairs({'PLAYER_MONEY','PLAYER_XP_UPDATE','PLAYER_LEVEL_UP','QUEST_TURNED_IN','CHAT_MSG_COMBAT_XP_GAIN','CHAT_MSG_MONEY','CHAT_MSG_SYSTEM','SKILL_LINES_CHANGED','PLAYER_LOGOUT','SEND_MAIL_MONEY_CHANGED','MAIL_SEND_SUCCESS','MAIL_FAILED','MAIL_CLOSED','MAIL_SHOW','MAIL_INBOX_UPDATE'})do pcall(R.frame.RegisterEvent,R.frame,event)end
        R.frame:SetScript('OnEvent',function(_,event,...)R.OnEvent(event,...)end)
        local elapsed=0;R.frame:SetScript('OnUpdate',function(_,delta)elapsed=elapsed+delta;if elapsed>=.5 then elapsed=0;R.Sample();R.Flush()end end)
    end
end
function R.Export()
    local P=Z.CompanionProtocol
    if not R.record then return{available=false}end
    R.Sample();R.Flush()
    local keys={};local current=day();for key in pairs(R.record.days)do if key~=current then keys[#keys+1]=key end end;table.sort(keys,function(a,b)return a>b end)
    local key=current
    if R.turn and#keys>0 then R.cursor=R.cursor%#keys+1;key=keys[R.cursor]end
    R.turn=not R.turn
    local source=bucket(key);local row={}
    for field,value in pairs(source)do row[field]=value end
    row.professions=P.Array();for _,skill in ipairs(source.professions)do row.professions[#row.professions+1]={id=skill.id,name=skill.name,points=skill.points}end
    return{available=true,version=1,startedAt=R.record.startedAt,entries=P.Array({row})}
end
Z.CompanionTelemetry.progress=R.Export
