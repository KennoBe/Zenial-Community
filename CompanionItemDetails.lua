-- Bounded, public tooltip snapshots. No hidden GameTooltip, hover simulation,
-- input, combat action or whole-cache export. Kept separate from fast inventory.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local P,T=Z.CompanionProtocol,Z.CompanionTelemetry
local function publicText(value)
    if not A.Safe(value)or type(value)~='string'or#value>600 then return nil end
    return value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|H.-|h(.-)|h','%1')
end
local function color(value)
    if not A.PublicTable(value)then return nil end
    local r,g,b=value.r,value.g,value.b
    if not A.Safe(r,g,b)or type(r)~='number'or type(g)~='number'or type(b)~='number'or r~=r or g~=g or b~=b or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return nil end
    return string.format('#%02x%02x%02x',math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
end
local function collect(ref)
    local api=C_TooltipInfo or{};local raw
    if ref.context=='equipment'then raw=A.Call(api.GetInventoryItem,'player',ref.slot)
    elseif ref.bag~=nil then raw=A.Call(api.GetBagItem,ref.bag,ref.slot)
    else raw=A.Call(api.GetItemByID,ref.itemID)end
    local out={key=ref.key,itemID=ref.itemID,slot=ref.slot,bag=ref.bag,instance=ref.instance,link=ref.link,context=ref.context,lines=P.Array(),complete=false}
    if not A.PublicTable(raw)or not A.PublicTable(raw.lines)then out.reason='not-loaded-or-unavailable';return out end
    local bytes=0;local protected=false;local truncated=false
    for i,line in ipairs(raw.lines)do
        if i>32 then truncated=true;break end
        if A.PublicTable(line)then
            local left,right=publicText(line.leftText),publicText(line.rightText)
            if A.Safe(line.leftText,line.rightText)and(type(line.leftText)=='string'and#line.leftText>600 or type(line.rightText)=='string'and#line.rightText>600)then truncated=true end
            if left or right then
                local row={left=left,right=right,leftColor=color(line.leftColor),rightColor=color(line.rightColor)}
                local length=#P.Json(row)
                if bytes+length>3000 then truncated=true;break end
                out.lines[#out.lines+1]=row;bytes=bytes+length
            elseif not A.Safe(line.leftText,line.rightText)then protected=true end
        else protected=true end
    end
    out.complete=not protected and not truncated and#out.lines>0
    out.reason=protected and'protected-lines'or truncated and'truncated'or#out.lines==0 and'not-loaded-or-unavailable'or nil
    return out
end
-- The slots come from the last sent inventory, which can lag behind the bags. An emptied or
-- refilled slot has nothing to describe yet; its next inventory corrects the list.
local function slotChanged(ref)
    if ref.bag==nil or not A.PublicTable(C_Container)then return false end
    local id=A.Call(C_Container.GetContainerItemID,ref.bag,ref.slot)
    return A.Safe(id)and id~=ref.itemID
end
function T.itemdetails()
    local C=Z.Companion
    if C.jobs.itemdetails or C.latest.itemdetails then return nil end
    local refs={}
    if C.settings.categories.character then for _,row in ipairs(C.finished.character and C.finished.character.data.equipment or{})do
        if row.itemID and row.slot then refs[#refs+1]={key='gear:'..row.slot,slot=row.slot,itemID=row.itemID,link=row.link,context='equipment'}end
    end end
    if C.settings.categories.inventory then
        local data=C.finished.inventory and C.finished.inventory.data or{}
        for _,row in ipairs(data.slots or{})do
            if row.itemID and#refs<256 then refs[#refs+1]={key='bag:'..row.bag..':'..row.slot,itemID=row.itemID,bag=row.bag,slot=row.slot,instance=row.instance,context='bags'}end
        end
        if not data.slots or#data.slots==0 then for _,row in ipairs(data.items or{})do
            if row.itemID and#refs<256 then refs[#refs+1]={key='bag:'..row.itemID,itemID=row.itemID,context='bags'}end
        end end
    end
    if#refs==0 then return{entries=P.Array()}end
    C.itemDetailSent=C.itemDetailSent or{};local now=A.Clock()
    local active={};for _,ref in ipairs(refs)do active[ref.key]=true end
    for key in pairs(C.itemDetailSent)do if not active[key]then C.itemDetailSent[key]=nil end end
    local cursor=C.itemDetailCursor or 1
    for i=0,#refs-1 do
        local index=(cursor+i-1)%#refs+1;local ref=refs[index]
        local previous=C.itemDetailSent[ref.key]
        local signature=tostring(ref.itemID)..':'..(ref.link or ref.instance or'')
        if(not previous or previous.signature~=signature or now>=previous.due)and not slotChanged(ref)then
            C.itemDetailCursor=index%#refs+1
            local row=collect(ref);C.itemDetailSent[ref.key]={signature=signature,due=now+(row.complete and 60 or 8)}
            return{entries=P.Array({row}),bootstrap=not previous or previous.signature~=signature}
        end
    end
    return nil
end
