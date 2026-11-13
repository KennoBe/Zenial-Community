-- Cross-faction target badge: small ZENIAL icon at the target frame when the target is a confirmed Zenial player (D-12).
-- Own non-protected frame, child of TargetFrame, never clickable. TargetFrame itself is never changed, hooked or queried
-- (no IsShown/GetCenter); it only gets this child. Created outside combat only; a pending creation is made up for on
-- PLAYER_REGEN_ENABLED (Main.lua calls Refresh then).
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local T={SIZE=18,pending=false}
Z.CrossFactionTargetBadge=T
local frame,listening
local CONTACT_SOURCES={xf=true,addon=true,bnet=true}

-- Reads a nested field chain defensively; every level may be missing or hostile.
local function field(root,...)
    local value=root
    for i=1,select('#',...)do
        if type(value)~='table'then return nil end
        local key=select(i,...)
        local ok,v=pcall(function()return value[key]end)
        if not ok then return nil end
        value=v
    end
    return value
end
local function isFontString(region)
    if type(region)~='table'or type(region.GetObjectType)~='function'then return false end
    local ok,kind=pcall(region.GetObjectType,region)
    return ok and A.Safe(kind)and kind=='FontString'
end
local function global(name)
    local ok,v=pcall(function()return _G[name]end)
    if ok then return v end
end
local function targetFrame()
    local f=global('TargetFrame')
    if type(f)=='table'then return f end
end

-- region, point, relativePoint, x, y: the badge's RIGHT at the left edge of the name text, else top right of TargetFrame.
function T.Anchor()
    local tf=targetFrame()
    local candidates={
        field(tf,'name'),
        field(tf,'TargetFrameContent','TargetFrameContentMain','Name'),
        global('TargetFrameTextureFrameName'),
        global('TargetFrameName'),
    }
    for i=1,4 do
        if isFontString(candidates[i])then return candidates[i],'RIGHT','LEFT',-2,0 end
    end
    return tf,'TOPRIGHT','TOPRIGHT',-6,-4
end

local function place()
    if not frame then return end
    local region,point,relativePoint,x,y=T.Anchor()
    if not region then return end
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(point,region,relativePoint,x,y)
    end)
end

local function age(seconds)
    local minutes=math.floor(seconds/60)
    if minutes<60 then return Z.T('%d min',minutes)end
    local hours=math.floor(minutes/60)
    if hours<24 then return Z.T('%d h',hours)end
    return Z.T('%d d',math.floor(hours/24))
end
-- Pure: status table (XF.GetPlayerStatus) and server time -> list of tooltip lines.
function T.TooltipLines(status,now)
    local lines={Z.T('ZENIAL Community detected')}
    if type(status)~='table'then return lines end
    if status.xfChat==true and type(status.proto)=='number'then
        lines[#lines+1]=Z.T('Cross-faction chat: supported (protocol %d)',status.proto)
    end
    if status.verified==false then
        lines[#lines+1]=Z.T('Not confirmed in this session yet')
    elseif CONTACT_SOURCES[status.source]and type(status.lastSeen)=='number'and type(now)=='number'then
        local seconds=now-status.lastSeen
        if seconds<0 then seconds=0 end
        if seconds<60 then lines[#lines+1]=Z.T('Last confirmed contact: just now')
        else lines[#lines+1]=Z.T('Last confirmed contact: %s ago',age(seconds))end
    end
    return lines
end

local function currentTarget()
    local exists=A.Call(UnitExists,'target')
    if exists~=true then return nil end
    if A.Call(UnitIsPlayer,'target')~=true then return nil end
    local guid=A.Call(UnitGUID,'target')
    if type(guid)=='string'and guid~=''then return guid end
end
local function showTooltip()
    pcall(function()
        local guid=currentTarget()
        local XF=Z.CrossFaction
        if not guid or type(XF)~='table'then return end
        local status=XF.GetPlayerStatus(guid)
        if type(status)~='table'or status.status~='CONFIRMED'then return end
        GameTooltip:SetOwner(frame,'ANCHOR_RIGHT')
        for _,line in ipairs(T.TooltipLines(status,A.Now()))do GameTooltip:AddLine(line,1,1,1)end
        GameTooltip:Show()
    end)
end

function T.Ensure()
    if frame then return frame end
    local tf=targetFrame()
    if not tf or type(CreateFrame)~='function'then return nil end
    if A.Call(InCombatLockdown)==true then T.pending=true;return nil end
    local ok,created=pcall(function()
        local f=CreateFrame('Frame',nil,tf)
        f:SetSize(T.SIZE,T.SIZE)
        local texture=f:CreateTexture(nil,'OVERLAY')
        texture:SetAllPoints(f)
        texture:SetTexture(Z.CrossFaction and Z.CrossFaction.ICON_PATH or 'Interface\\AddOns\\ZenialCommunity\\Media\\Icon.tga')
        f.texture=texture
        pcall(function()f:SetFrameLevel(tf:GetFrameLevel()+5)end)
        f:EnableMouse(false)
        if type(f.SetMouseClickEnabled)=='function'then
            f:EnableMouse(true)
            f:SetMouseClickEnabled(false)
            f:SetScript('OnEnter',showTooltip)
            f:SetScript('OnLeave',function()pcall(function()GameTooltip:Hide()end)end)
        end
        f:Hide()
        return f
    end)
    if not ok or type(created)~='table'then return nil end
    frame=created;T.pending=false
    place()
    return frame
end

function T.Refresh()
    pcall(function()
        local XF=Z.CrossFaction
        local show=false
        if type(XF)=='table'and XF.Settings().targetIcon==true then
            local guid=currentTarget()
            if guid then
                local N=Z.CrossFactionPresence
                if type(N)=='table'and type(N.HasPending)=='function'and N.HasPending()then
                    local name=A.Call(UnitName,'target')
                    if type(name)=='string'and name~=''then N.Resolve(guid,name)end
                end
                local status=XF.GetPlayerStatus(guid)
                show=type(status)=='table'and status.status=='CONFIRMED'
            end
        end
        if show then
            local f=T.Ensure()
            if f then place();f:Show()end
        elseif frame then
            frame:Hide()
        end
    end)
end

function T.Initialize()
    if listening then return end
    local XF=Z.CrossFaction
    if type(XF)~='table'or type(XF.RegisterListener)~='function'then return end
    listening=XF.RegisterListener('targetBadge',function(event,payload)
        if event~='PLAYER'or type(payload)~='table'then return end
        local guid=payload.guid
        if not A.Safe(guid)or type(guid)~='string'then return end
        if currentTarget()==guid then T.Refresh()end
    end)==true
end
