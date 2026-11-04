-- Outbound-only pixel packets. No chat, logging, files, input or process access.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local C,P=Z.Companion,Z.CompanionProtocol
local X={COLS=64,ROWS=12,CELL=1,MAX_PAYLOAD=752};C.Pixel=X
local MAGIC=string.char(90,67,80,88,1,254,129,126)
function X.Color(value)
    return(16+math.floor(value/32)*32)/255,(16+math.floor(value/4)%8*32)/255,(32+value%4*64)/255
end
function X.Pack(lines,id)
    local payload=table.concat(lines,'\n')
    if#payload<1 or#payload>X.MAX_PAYLOAD then return nil end
    local header=MAGIC..string.char(#payload%256,math.floor(#payload/256),id%256,math.floor(id/256)%256,math.floor(id/65536)%256,math.floor(id/16777216)%256)
    local check=tonumber(P.Checksum(header..payload),16)
    local bytes=header..string.char(check%256,math.floor(check/256))..payload
    return bytes..string.rep('\0',X.COLS*X.ROWS-#bytes)
end
function X.BeginBatch()X.lines={}end
function X.Publish(line)
    if not X.lines or type(line)~='string'or#line>P.MAX_LINE or line:find('[%z\1-\31\127-\255]')or#X.lines>=3 then return false end
    X.lines[#X.lines+1]=line;return true
end
-- WorldFrame stays visible when the UI is hidden (Alt+Z, in-game cinematics),
-- so the export keeps running; it is not scaled by the UI scale. UIParent is
-- only a fallback when WorldFrame is unavailable.
local function parent()
    return type(WorldFrame)=='table'and type(WorldFrame.GetEffectiveScale)=='function'and WorldFrame or UIParent
end
function X.Layout(force)
    local root=X.frame.root or UIParent;local scale=A.Call(root.GetEffectiveScale,root)
    if type(scale)~='number'or scale<=0 then scale=1 end
    -- WoW coordinates use a virtual 768px screen height even with UI scale 1.
    -- Cancel both that conversion and the parent's scale: one cell = one
    -- physical pixel, including on 1440p/4K displays and after resizing.
    local _,height=A.Call(GetPhysicalScreenSize)
    local pixel=type(height)=='number'and height>0 and 768/height or 1
    -- Re-anchor only when the UI scale or display size actually changed.
    if not force and X.layoutScale==pixel/scale then return end
    X.layoutScale=pixel/scale;X.frame:SetScale(pixel/scale)
    X.frame:ClearAllPoints();X.frame:SetPoint('TOPLEFT',root,'TOPLEFT',8,-8)
end
function X.Commit()
    if not X.lines or#X.lines==0 then return end
    X.counter=((X.counter or 0)+1)%4294967296
    local bytes=X.Pack(X.lines,X.counter);X.lines=nil
    if not bytes then C.Stop('Pixel packet could not be encoded.');return end
    if not X.frame then
        local root=parent();local f=CreateFrame('Frame','ZenialCompanionPixelStrip',root);X.frame=f;f.root=root
        f:SetSize(X.COLS*X.CELL,X.ROWS*X.CELL);f:SetFrameStrata('TOOLTIP');f:SetFrameLevel(10000);f:EnableMouse(false)
        if type(f.SetIgnoreParentAlpha)=='function'then f:SetIgnoreParentAlpha(true)end
        X.cells={}
        for i=1,X.COLS*X.ROWS do
            local t=f:CreateTexture(nil,'OVERLAY');t:SetSize(X.CELL,X.CELL)
            t:SetPoint('TOPLEFT',f,'TOPLEFT',((i-1)%X.COLS)*X.CELL,-math.floor((i-1)/X.COLS)*X.CELL)
            X.cells[i]=t
        end
    end
    -- The first packet after creation or Stop redraws every cell and re-anchors;
    -- later packets only recolor cells whose byte differs from the shown one.
    -- All cells change within this call, so the frame still shows one packet.
    local last=X.lastPacket;X.Layout(not last)
    for i=1,#bytes do local v=bytes:byte(i);if not last or v~=last:byte(i)then local r,g,b=X.Color(v);X.cells[i]:SetColorTexture(r,g,b,1)end end
    if C.Vitals then C.Vitals.Render()end
    X.lastPacket=bytes;X.packets=(X.packets or 0)+1;X.frame:Show()
end
function X.Stop()
    X.lines=nil;X.lastPacket=nil
    if X.frame then X.frame:Hide()end
end
