-- Coarse, short-lived public positions. These never establish peer identity or
-- extend online presence; profiles and private transactions use their own routes.
local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local C={TTL=300,MAX_POSITIONS=5000,TEMPLATE="ZenialCommunityMemberPinTemplate"}
Z.CommunityMap=C
local function tr(text,...)return Z.Locale.Format(text,...)end
local function enabled()return Z.db and Z.db.consent and Z.db.autoDiscovery and Z.identityReady and not Z.offlineOnly end
function C.IsShown()return Z.uiCharacter and Z.uiCharacter.mapMembers~=false or false end
function C.SetShown(value)
    if not Z.uiCharacter then return end
    Z.uiCharacter.mapMembers=value==true;C.Refresh()
end
function C.IsGuildOnly()return Z.uiCharacter and Z.uiCharacter.mapGuildOnly==true or false end
function C.SetGuildOnly(value)
    if not Z.uiCharacter then return end
    Z.uiCharacter.mapGuildOnly=value==true
    if value then Z.uiCharacter.mapMembers=true end
    C.Refresh()
end
function C.Initialize()
    C.positions={};C.nextSample=0;C.nextRefresh=0;C.nextAttach=0;C.lastSent=nil;C.lastPosition=nil;C.lastMap=nil;C.mapShown=nil
    C.sent,C.received,C.sampleAvailable=0,0,false
    C.TryAttach();C.Refresh()
end
local function sessionOrder(session)
    local epoch,sequence=session:match("^(%d+)%.(%d+)%.")
    return tonumber(epoch)or 0,tonumber(sequence)or 0
end
function C.Receive(sender,wire,context)
    if not enabled()then return false end
    local row=Z.Network3.DecodeMapPosition(wire)
    if not row or not context or context.session~=row.session or context.at~=row.at or L.Identity(context.origin)~=L.Identity(sender)then return false end
    local key=Z.ResolvePeerKey(sender)
    if not key or key==Z.me.key or Z.db.blocked[key]then return false end
    local peer=Z.db.peers[key]
    if peer and peer.retiredSessions and peer.retiredSessions[row.session]then return false end
    if peer and peer.session and peer.session~=row.session then
        local a,b=sessionOrder(row.session);local x,y=sessionOrder(peer.session)
        if a<x or a==x and b<=y then return false end
    end
    local old=C.positions[key]
    if old then
        if old.session==row.session and old.at>=row.at then return false end
        if old.session~=row.session then
            local a,b=sessionOrder(row.session);local x,y=sessionOrder(old.session)
            if a<x or a==x and b<=y then return false end
        end
    elseif L.Count(C.positions)>=C.MAX_POSITIONS then return false end
    -- Keep zero-position withdrawals until expiry, so delayed older samples
    -- cannot restore a hidden or instanced member's last dot.
    row.target=sender;C.positions[key]=row;C.received=C.received+1;C.nextRefresh=0;return true
end
local function validPoint(x,y)
    return A.Safe(x,y)and type(x)=="number"and type(y)=="number"and x==x and y==y and x>=0 and x<=1 and y>=0 and y<=1
end
function C.Project(row,mapID)
    if row.mapID==mapID then return row.x/10000,row.y/10000 end
    if row.projectMap==mapID then return row.projectX,row.projectY end
    if not C_Map or type(CreateVector2D)~="function"then return nil end
    local vector=A.Call(CreateVector2D,row.x/10000,row.y/10000)
    if not vector then return nil end
    local continent,world=A.Call(C_Map.GetWorldPosFromMapPos,row.mapID,vector)
    if not continent or not world then return nil end
    local result,point=A.Call(C_Map.GetMapPosFromWorldPos,continent,world,mapID)
    if result~=mapID or not A.PublicTable(point)then return nil end
    local x,y
    if type(point.GetXY)=="function"then x,y=A.Call(point.GetXY,point)else x,y=point.x,point.y end
    if validPoint(x,y)then row.projectMap,row.projectX,row.projectY=mapID,x,y;return x,y end
end
local function grouped()
    local names,guids={},{}
    for _,name in pairs(A.GroupMembers())do names[L.Identity(name)or name]=true end
    local total=A.Call(GetNumGroupMembers)or 0
    if not L.Int(total,0,40)then total=0 end
    local raid=A.Call(IsInRaid)==true
    for i=1,raid and total or math.max(0,total-1)do
        local guid=A.Call(UnitGUID,(raid and"raid"or"party")..i)
        if L.Text(guid,80)then guids[guid]=true end
    end
    return names,guids
end
function C.Points(mapID)
    local points={}
    if not enabled()or not C.IsShown()or not L.Int(mapID,1,1000000)then return points end
    local names,guids=grouped();local now=A.Now()
    for key,row in pairs(C.positions or{})do
        local peer=Z.db.peers[key];local data=peer and peer.data;local presence=peer and peer.presence
        if row.mapID>0 and now-row.at<C.TTL and row.at<=now+120 and key~=Z.me.key and not Z.db.blocked[key]
            and peer and peer.session==row.session and presence and presence.level>0 and Z.IsOnline(key)
            and not names[L.Identity(row.target)]and not(data and guids[data.guid])
            and(not C.IsGuildOnly()or Z.Social.IsGuildMember(key))then
            local x,y=C.Project(row,mapID)
            if x then points[#points+1]={key=key,target=row.target,x=x,y=y,at=row.at,classFile=presence.classFile,level=presence.level}end
        end
    end
    table.sort(points,function(a,b)return a.key<b.key end);return points
end

-- Places of death of PvP help calls this helper received, kept separate from member positions.
function C.DeathPoints(mapID)
    local points={}
    if not enabled()or not Z.PvPHelp or not L.Int(mapID,1,1000000)then return points end
    for _,r in ipairs(Z.PvPHelp.DeathMarks())do
        local x,y=C.Project({mapID=r.deathMapID,x=r.deathX,y=r.deathY},mapID)
        if x then
            local contact=Z.db.contacts[r.key]
            points[#points+1]={death=true,key="death:"..r.key..":"..r.id,owner=r.key,id=r.id,target=contact and contact.target or r.key,x=x,y=y,at=r.at,note=r.note,closed=r.closed,expires=r.expires}
        end
    end
    table.sort(points,function(a,b)return a.key<b.key end);return points
end

local function pinBounds(pin)
    if not pin or not pin:IsVisible()then return end
    local x,y=A.Call(pin.GetCenter,pin);local scale=A.Call(pin.GetEffectiveScale,pin)
    local w,h=A.Call(pin.GetWidth,pin),A.Call(pin.GetHeight,pin)
    if not A.Safe(x,y,scale,w,h)or type(x)~='number'or type(y)~='number'or type(scale)~='number'or type(w)~='number'or type(h)~='number'
        or x~=x or y~=y or scale<=0 or w<=0 or h<=0 then return end
    return x*scale,y*scale,w*scale,h*scale
end
function C.TooltipRows(pin)
    if not pin or not pin.row then return{}end
    local rows={};local provider=C.provider;local owner=provider and provider:GetMap()
    if not owner then return{pin.row}end
    local x,y,w,h=pinBounds(pin)
    -- Compare rendered rectangles, so zoom and UI scale do not change the
    -- overlap threshold. Only currently eligible Community positions qualify.
    for _,row in ipairs(C.Points(owner:GetMapID()))do
        local other=provider.pins[row.key];local include=row.key==pin.row.key
        if not include and x then
            local ox,oy,ow,oh=pinBounds(other)
            if ox then
                local width=math.max(0,math.min(x+w/2,ox+ow/2)-math.max(x-w/2,ox-ow/2))
                local height=math.max(0,math.min(y+h/2,oy+oh/2)-math.max(y-h/2,oy-oh/2))
                include=width*height>=.8*math.min(w*h,ow*oh)
            end
        end
        if include then rows[#rows+1]=row end
    end
    table.sort(rows,function(a,b)
        if a.key==pin.row.key then return b.key~=pin.row.key elseif b.key==pin.row.key then return false end
        if a.target~=b.target then return a.target<b.target end;return a.key<b.key
    end)
    return rows
end

-- The virtual XML template may load before Blizzard_MapCanvas. Mix in the
-- native base only when the actual map and its provider APIs are available.
ZenialCommunityMemberPinMixin={}
local pinMethods={}
function pinMethods:CheckMouseButtonPassthrough()
    -- This template accepts mouse motion for tooltips, never clicks. All
    -- clicks already reach the map, so there is no passthrough state to set.
    -- AcquirePin calls this even on reused pins; Blizzard's default calls
    -- SetPassThroughButtons, which addon code cannot use during combat.
end
function pinMethods:OnLoad()
    self:SetScalingLimits(1,1,1);self:SetSize(11,11)
    self.icon=self:CreateTexture(nil,"ARTWORK");self.icon:SetAllPoints()
    self.icon:SetAtlas("WhiteCircle-RaidBlips")
end
local SKULL="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
function pinMethods:OnAcquired(row)
    self.row=row;self:UseFrameLevelType("PIN_FRAME_LEVEL_GROUP_MEMBER");self:SetPosition(row.x,row.y)
    -- Pins are pooled across both kinds, so the look is set on every acquire.
    if row.death then
        self:SetSize(18,18);self.icon:SetTexture(SKULL);self.icon:SetTexCoord(0,1,0,1);self.icon:SetVertexColor(1,1,1);return
    end
    self:SetSize(11,11);self.icon:SetAtlas("WhiteCircle-RaidBlips")
    local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.classFile]
    self.icon:SetVertexColor(color and color.r or .3,color and color.g or .85,color and color.b or 1)
end
function pinMethods:OnReleased()
    MapCanvasPinMixin.OnReleased(self)
    if GameTooltip and A.Call(GameTooltip.IsOwned,GameTooltip,self)then GameTooltip:Hide()end
    self.row=nil
end
function pinMethods:OnMouseEnter()
    local row=self.row;if not row or not GameTooltip then return end
    if row.death then
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(tr("Place of death")..": "..row.target,1,.82,.3)
        local age=math.max(0,A.Now()-row.at)
        GameTooltip:AddLine(age<60 and tr("Help request less than a minute ago")or tr("Help request %d min ago",math.floor(age/60)),.75,.75,.75)
        if(row.note or"")~=""then GameTooltip:AddLine(tr("Attackers")..": "..row.note,1,1,1)end
        GameTooltip:AddLine(tr(row.closed and"Completed"or row.expires<=A.Now()and"Expired"or"Active"),.85,.85,.85)
        GameTooltip:Show();return
    end
    local rows=C.TooltipRows(self);if #rows==0 then GameTooltip:Hide();return end
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    for index,member in ipairs(rows)do
        if index>1 then GameTooltip:AddLine(' ')end
        GameTooltip:AddLine(member.target,1,1,1)
        GameTooltip:AddLine(L.ClassName("",member.classFile).." · "..tr("Level %d",member.level),.85,.85,.85)
        local age=math.max(0,A.Now()-member.at)
        GameTooltip:AddLine(age<60 and tr("Position less than a minute ago")or tr("Position %d min ago",math.floor(age/60)),.75,.75,.75)
    end
    GameTooltip:Show()
end
function pinMethods:OnMouseLeave()if GameTooltip then GameTooltip:Hide()end end
function C.TryAttach()
    if not C.menuAttached and Menu and type(Menu.ModifyMenu)=="function"then
        Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING",function(_,root)
            root:CreateCheckbox(tr("Community members"),C.IsShown,function()C.SetShown(not C.IsShown())end)
            root:CreateCheckbox(tr("My guild only"),C.IsGuildOnly,function()C.SetGuildOnly(not C.IsGuildOnly())end)
        end)
        C.menuAttached=true
    end
    local map=WorldMapFrame
    if C.provider or not map or type(map.AddDataProvider)~="function"or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then return end
    for k,v in pairs(MapCanvasPinMixin)do ZenialCommunityMemberPinMixin[k]=v end
    for k,v in pairs(pinMethods)do ZenialCommunityMemberPinMixin[k]=v end
    local provider={}
    for k,v in pairs(MapCanvasDataProviderMixin)do provider[k]=v end
    provider.pins={}
    function provider:RemoveAllData()self:GetMap():RemoveAllPinsByTemplate(C.TEMPLATE);self.pins={}end
    function provider:RefreshAllData()
        local owner=self:GetMap()
        if not owner:IsShown()then self:RemoveAllData();return end
        local keep={}
        local rows=C.Points(owner:GetMapID())
        for _,row in ipairs(C.DeathPoints(owner:GetMapID()))do rows[#rows+1]=row end
        for _,row in ipairs(rows)do
            local pin=self.pins[row.key]
            if pin and pin.row and pin.row.key==row.key then
                local old=pin.row
                if old.x~=row.x or old.y~=row.y or old.at~=row.at or old.classFile~=row.classFile or old.note~=row.note or old.closed~=row.closed then pin:OnAcquired(row)else pin.row=row end
            else pin=owner:AcquirePin(C.TEMPLATE,row)end
            keep[row.key]=pin
        end
        for key,pin in pairs(self.pins)do if not keep[key]and pin.row and pin.row.key==key then owner:RemovePin(pin)end end
        self.pins=keep
        for _,pin in pairs(keep)do if GameTooltip and A.Call(GameTooltip.IsOwned,GameTooltip,pin)then pin:OnMouseEnter();break end end
    end
    C.provider=provider;map:AddDataProvider(provider)
    provider:RefreshAllData()
end
function C.Refresh()if C.provider then C.provider:RefreshAllData()end end
function C.Tick()
    if not C.positions then return end
    local clock,now=A.Clock(),A.Now()
    if clock>=C.nextAttach then C.nextAttach=clock+5;C.TryAttach()end
    if clock>=C.nextSample then
        C.nextSample=clock+5
        for key,row in pairs(C.positions)do if now-row.at>=C.TTL or Z.db.blocked[key]then C.positions[key]=nil end end
        if enabled()then
            local pos=Z.db.visible and A.MapPosition()or{mapID=0,x=0,y=0}
            C.sampleAvailable=pos.mapID>0
            local signature=pos.mapID..":"..pos.x..":"..pos.y
            local changed=signature~=C.lastPosition
            -- Zone changes/withdrawals can replace the last sample promptly;
            -- walking updates at most once a minute, stationary refreshes 2 min.
            local transition=C.lastMap and pos.mapID~=C.lastMap
            local due=not C.lastSent or transition or clock-C.lastSent>=(changed and 60 or 120)
            if due and(pos.mapID>0 or C.lastMap and C.lastMap>0)then
                local wire=Z.Network3.Pack({Z.session,now,pos.mapID,pos.x,pos.y})
                if Z.Network3.QueuePublic("MP",wire,5,"MAP_POSITION")then C.sent=C.sent+1;C.lastSent=clock;C.lastPosition=signature;C.lastMap=pos.mapID end
            end
        else
            C.positions={};C.lastSent=nil;C.lastPosition=nil;C.lastMap=nil;C.sampleAvailable=false
        end
    end
    local shown=WorldMapFrame and WorldMapFrame:IsShown()
    if clock>=C.nextRefresh or shown~=C.mapShown then
        C.nextRefresh=clock+1;C.mapShown=shown
        if shown or C.hadPins or C.provider and next(C.provider.pins)then C.Refresh()end;C.hadPins=shown==true
    end
end
function C.Status()
    return{enabled=enabled()==true,filter=C.IsShown(),guildOnly=C.IsGuildOnly(),menuAttached=C.menuAttached==true,providerAttached=C.provider~=nil,
        positions=L.Count(C.positions),pins=C.provider and L.Count(C.provider.pins)or 0,sampleAvailable=C.sampleAvailable==true,
        published=C.sent or 0,received=C.received or 0,lastPublishedAge=C.lastSent and math.floor(A.Clock()-C.lastSent)or-1}
end
