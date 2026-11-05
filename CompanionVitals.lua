-- Optional native display sink, read optically by the companion. Protected
-- health/power is never compared, formatted, converted or serialized in addon Lua.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local C,P=Z.Companion,Z.CompanionProtocol
local V={ROWS=17};C.Vitals=V
local MAGIC=string.char(90,67,86,84,1,254,129,126)
local function byte(cell,value)local r,g,b=C.Pixel.Color(value);cell:SetColorTexture(r,g,b,1)end
function V.Hide()for _,cell in ipairs(V.cells or{})do cell:Hide()end end
local function u32(n)return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256)end
function V.Render()
    local X=C.Pixel;if not X.frame or V.failed or A.Clock()<(V.due or 0)then return end;V.due=A.Clock()+.25
    if type(UnitHealthPercent)~='function'or not C_CurveUtil or type(C_CurveUtil.CreateColorCurve)~='function'or type(CreateColor)~='function'then return end
    local ok=pcall(function()
        if not V.curve then
            V.curve=C_CurveUtil.CreateColorCurve();V.curve:AddPoint(0,CreateColor(0,128/255,1));V.curve:AddPoint(1,CreateColor(1,128/255,1))
        end
        if not V.cells then
            V.cells={};X.frame:SetHeight(V.ROWS)
            for i=1,320 do local t=X.frame:CreateTexture(nil,'OVERLAY');t:SetSize(1,1);t:SetPoint('TOPLEFT',X.frame,'TOPLEFT',(i-1)%64,-(12+math.floor((i-1)/64)));V.cells[i]=t end
        end
        local units={};local seen={}
        local function add(unit)
            local key,target,realm=A.UnitIdentity(unit);if key then key=Z.Logic.ScopeKey(target,realm,Z.me.faction)or key end;if not key or seen[key]then return end;seen[key]=true
            units[#units+1]={unit=unit,key=key}
        end
        if C.settings.categories.player then add('player')end
        if C.settings.categories.groups then
            local raid=A.Call(IsInRaid)==true;local total=A.Call(GetNumGroupMembers)
            if A.Safe(total)and type(total)=='number'then for i=1,math.min(40,raid and total or math.max(0,total-1))do add((raid and'raid'or'party')..i)end end
        end
        V.counter=((V.counter or 0)+1)%4294967296
        local header=MAGIC..P.Source(Z.me.key)..P.Source(C.session)..u32(V.counter)..string.char(#units)
        for i=1,64 do byte(V.cells[i],header:byte(i)or 0)end
        for i=1,41 do
            local start=64+(i-1)*6;local row=units[i];local hash=row and P.Source(row.key)or'00000000'
            for j=1,4 do byte(V.cells[start+j],tonumber(hash:sub(j*2-1,j*2),16))end
            V.cells[start+5]:SetColorTexture(0,0,0,1);V.cells[start+6]:SetColorTexture(0,0,0,1)
            if row then
                -- The native color curve and texture consume the opaque value.
                -- A failed native sink only removes that value, never the main export.
                pcall(function()local color=UnitHealthPercent(row.unit,true,V.curve);V.cells[start+5]:SetColorTexture(color:GetRGB())end)
                if type(UnitPowerPercent)=='function'then
                    pcall(function()
                        local power=A.Call(UnitPowerType,row.unit)
                        if A.Safe(power)and type(power)=='number'then
                            local color=UnitPowerPercent(row.unit,power,false,V.curve);V.cells[start+6]:SetColorTexture(color:GetRGB())
                        end
                    end)
                end
            end
        end
        for _,cell in ipairs(V.cells)do cell:Show()end
    end)
    if not ok then V.failed=true end
end
