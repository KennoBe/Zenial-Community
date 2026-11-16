-- ZENIAL Rivalry kill feed: a small banner for a few seconds after each recorded kill, death, assist or duel.
-- Own frames on UIParent, never protected, never clickable while locked. At most three banners are visible;
-- further events wait in a short queue. All colours are palette keys, all values are plain numbers and
-- names from the rivalry history (nothing here reads combat data).
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local T=Z.Theme
local B={SLOTS=3,MAX_QUEUE=8,FADE_IN=.18,FADE_OUT=.35,GAP=6,SOUND_GAP=.5,DEFAULT_X=0,DEFAULT_Y=180,active={},queue={},rows={}}
Z.RivalryBanner=B
local STYLE={
    standard={width=300,height=48,icon=30},
    compact={width=280,height=26,icon=18},
}
-- kind -> label, palette key, settings switch, sound kits (first one the client knows is played)
local KIND={
    K={label="KILL",color="gold",switch="kills",sounds={"MAP_PING","TELL_MESSAGE"}},
    D={label="KILLED BY",color="danger",switch="deaths",sounds={"IG_QUEST_LOG_ABANDON_QUEST","TELL_MESSAGE"}},
    A={label="ASSIST",color="accentBlue",switch="assists",sounds={"IG_MAINMENU_OPTION_CHECKBOX_ON","TELL_MESSAGE"}},
    W={label="DUEL WON",color="success",switch="duels",sounds={"LFG_REWARDS","READY_CHECK"}},
    L={label="DUEL LOST",color="warning",switch="duels",sounds={"IG_QUEST_LOG_ABANDON_QUEST","TELL_MESSAGE"}},
}
local TAG={RIVAL="RIVAL",NEMESIS="NEMESIS",REVENGE="REVENGE",FIRST="FIRST MEETING"}

local function settings()return Z.Rivalry.Settings()end
local function tint(region,method,key,alpha)if T then T.Tint(region,method,key,alpha)end end
local function try(object,method,...)
    local fn=object and object[method]
    if type(fn)=="function"then return pcall(fn,object,...)end
    return false
end

local function place()
    local root=B.root;if not root then return end
    local s=settings();local pos=s.position;local scale=s.scale
    local spec=STYLE[s.style]or STYLE.standard
    root:SetScale(scale);root:SetSize(spec.width,spec.height)
    root:ClearAllPoints()
    root:SetPoint("CENTER",UIParent,"CENTER",(pos and pos.x or B.DEFAULT_X)/scale,(pos and pos.y or B.DEFAULT_Y)/scale)
end
-- The main window sits on DIALOG. A preview or the move handle must stay visible above it; banners of real
-- events keep the lower layer.
local function layer()
    local root=B.root;if not root then return end
    local raised=B.unlocked==true
    for slot=1,B.SLOTS do local a=B.active[slot];if a and a.data.preview then raised=true end end
    local strata=raised and"TOOLTIP"or"HIGH"
    if B.strata~=strata then B.strata=strata;try(root,"SetFrameStrata",strata)end
end
local function ensureRoot()
    if B.root or type(CreateFrame)~="function"or not UIParent then return B.root end
    local root=CreateFrame("Frame",nil,UIParent)
    try(root,"SetClampedToScreen",true);try(root,"EnableMouse",false)
    B.root=root;layer();place()
    return root
end
local function text(parent,font,role,colorKey)
    local fs=parent:CreateFontString(nil,"OVERLAY",font)
    try(fs,"SetJustifyH","LEFT");try(fs,"SetWordWrap",false)
    try(fs,"SetShadowOffset",1,-1);try(fs,"SetShadowColor",0,0,0,.9)
    if T then T.Font(fs,role,colorKey)end
    return fs
end
local function buildRow(index)
    local f=CreateFrame("Frame",nil,B.root)
    try(f,"EnableMouse",false)
    f.bg=f:CreateTexture(nil,"BACKGROUND");f.bg:SetAllPoints(f);tint(f.bg,"SetColorTexture","overlay",.84)
    f.glow=f:CreateTexture(nil,"BORDER");f.glow:SetPoint("TOPLEFT");f.glow:SetPoint("BOTTOMLEFT")
    f.bar=f:CreateTexture(nil,"ARTWORK");f.bar:SetPoint("TOPLEFT");f.bar:SetPoint("BOTTOMLEFT");f.bar:SetWidth(3)
    f.line=f:CreateTexture(nil,"ARTWORK");f.line:SetPoint("BOTTOMLEFT");f.line:SetPoint("BOTTOMRIGHT");f.line:SetHeight(1)
    f.shine=f:CreateTexture(nil,"OVERLAY");f.shine:SetAllPoints(f);try(f.shine,"SetBlendMode","ADD");f.shine:Hide()
    f.icon=f:CreateTexture(nil,"ARTWORK")
    f.label=text(f,"GameFontNormalSmall","overline","dim")
    f.name=text(f,"GameFontNormal","heading","text")
    f.stats=text(f,"GameFontHighlightSmall","caption","textSoft")
    f.tag=text(f,"GameFontNormalSmall","overline","goldBright");try(f.tag,"SetJustifyH","RIGHT")
    f.index=index;f:Hide()
    return f
end
-- Positions the parts of one row for the chosen style.
local function layoutRow(f,style)
    local spec=STYLE[style]or STYLE.standard
    f.style=style;f:SetSize(spec.width,spec.height)
    f:ClearAllPoints();f:SetPoint("TOP",B.root,"TOP",0,-(f.index-1)*(spec.height+B.GAP))
    f.glow:SetWidth(spec.width*.55)
    f.icon:ClearAllPoints();f.icon:SetSize(spec.icon,spec.icon);f.icon:SetPoint("LEFT",f,"LEFT",11,0)
    local left=11+spec.icon+9
    for _,part in ipairs({f.label,f.name,f.stats,f.tag})do part:ClearAllPoints()end
    if style=="compact"then
        f.label:SetPoint("LEFT",f,"LEFT",left,0)
        f.name:SetPoint("LEFT",f.label,"RIGHT",6,0)
        f.stats:SetPoint("RIGHT",f,"RIGHT",-10,0);try(f.stats,"SetJustifyH","RIGHT")
        f.tag:Hide()
    else
        f.label:SetPoint("TOPLEFT",f,"TOPLEFT",left,-8)
        f.name:SetPoint("LEFT",f.label,"RIGHT",6,0)
        f.stats:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",left,8);try(f.stats,"SetJustifyH","LEFT")
        f.tag:SetPoint("TOPRIGHT",f,"TOPRIGHT",-10,-8)
    end
end
local function classColored(name,classFile)
    local hex=T and T.ClassColorHex and T.ClassColorHex(classFile)
    return hex and("|cff"..hex..name.."|r")or name
end
-- Text and colours of one banner. Returns the three lines so tests can read them without frames.
function B.Describe(data,style)
    local kind=KIND[data.kind]or KIND.K
    local name=type(data.name)=="string"and data.name~=""and data.name or Z.T("Unknown")
    local stats
    if data.kind=="W"or data.kind=="L"then
        stats=Z.T("Duels %d : %d",data.duelWins or 0,data.duelLosses or 0)
    elseif style=="compact"then
        stats=(data.kills or 0).." / "..(data.deaths or 0).." / "..(data.assists or 0)
    else
        stats=Z.T("Kills %d",data.kills or 0).."  ·  "..Z.T("Deaths %d",data.deaths or 0).."  ·  "..Z.T("Assists %d",data.assists or 0)
    end
    return Z.T(kind.label),name,stats,TAG[data.tag or""]and Z.T(TAG[data.tag])or nil,kind
end
local function fill(f,data,style)
    local label,name,stats,tag,kind=B.Describe(data,style)
    f.label:SetText(label);tint(f.label,"SetTextColor",kind.color)
    f.name:SetText(classColored(name,data.classFile))
    f.stats:SetText(stats)
    if tag and style~="compact"then f.tag:SetText(tag);f.tag:Show()else f.tag:SetText("");f.tag:Hide()end
    tint(f.bar,"SetColorTexture",kind.color,1);tint(f.line,"SetColorTexture",kind.color,.35)
    if T then T.SetGradient(f.glow,"HORIZONTAL",kind.color,kind.color,.22,0)end
    local icon=T and T.ClassIcon(data.classFile)
    if icon then
        try(f.icon,"SetTexCoord",0,1,0,1)
        if not T.SetTexture(f.icon,icon)then f.icon:SetTexture(T.assets.neutralIcon)end
    elseif T then try(f.icon,"SetTexCoord",0,1,0,1);f.icon:SetTexture(T.assets.neutralIcon)end
    -- A known rival or the nemesis gets a short gold flash on top of the kind colour.
    f.flash=(data.tag=="RIVAL"or data.tag=="NEMESIS")and(data.kind=="K"or data.kind=="W")
    if f.flash then tint(f.shine,"SetColorTexture","gold",.0);f.shine:Show()else f.shine:Hide()end
end
local function playSound(kind,now)
    if B.lastSound and now-B.lastSound<B.SOUND_GAP then return false end
    if not SOUNDKIT or not C_Sound or type(C_Sound.PlaySound)~="function"then return false end
    for _,name in ipairs(kind.sounds)do
        local id=SOUNDKIT[name]
        if id then B.lastSound=now;B.lastSoundKit=name;return pcall(C_Sound.PlaySound,id)end
    end
    return false
end

local function freeSlot()
    for i=1,B.SLOTS do if not B.active[i]then return i end end
end
local function start(slot,data,now)
    local s=settings();local f=B.rows[slot]
    if not f then f=buildRow(slot);B.rows[slot]=f end
    layoutRow(f,s.style);fill(f,data,s.style)
    B.active[slot]={data=data,at=now,hold=s.duration,animate=s.animation}
    f:SetAlpha(s.animation and 0 or 1);f:Show();layer()
    if s.sound and not data.silent then playSound(KIND[data.kind]or KIND.K,now)end
end
local function finish(slot)
    B.active[slot]=nil
    local f=B.rows[slot];if f then f:Hide();f.shine:Hide()end
    layer()
end
local function onUpdate()B.Tick(A.Clock())end
-- Advances the fades, frees finished slots and starts waiting banners.
function B.Tick(now)
    local busy=false
    for slot=1,B.SLOTS do
        local a=B.active[slot]
        if a then
            local f=B.rows[slot];local t=now-a.at;local total=a.hold+(a.animate and B.FADE_IN+B.FADE_OUT or 0)
            if t>=total then finish(slot)
            else
                busy=true
                if a.animate then
                    local alpha,shift=1,0
                    if t<B.FADE_IN then alpha=t/B.FADE_IN;shift=-(1-alpha)*14
                    elseif t>B.FADE_IN+a.hold then alpha=1-(t-B.FADE_IN-a.hold)/B.FADE_OUT end
                    f:SetAlpha(math.max(0,math.min(1,alpha)))
                    local spec=STYLE[f.style]or STYLE.standard
                    f:ClearAllPoints();f:SetPoint("TOP",B.root,"TOP",shift,-(slot-1)*(spec.height+B.GAP))
                    if f.flash then
                        local p=t/.6
                        tint(f.shine,"SetColorTexture","gold",p<1 and .28*(1-p)or 0)
                    end
                end
            end
        end
    end
    while #B.queue>0 do
        local slot=freeSlot();if not slot then break end
        start(slot,table.remove(B.queue,1),now);busy=true
    end
    -- A full queue shortens the banner that has been visible longest.
    if #B.queue>0 then
        local oldest
        for slot=1,B.SLOTS do local a=B.active[slot];if a and(not oldest or a.at<oldest.at)then oldest=a end end
        if oldest then
            local seen=now-oldest.at-(oldest.animate and B.FADE_IN or 0)
            if oldest.hold-seen>1 then oldest.hold=math.max(0,seen)+1 end
        end
    end
    if B.root and not busy and #B.queue==0 then B.root:SetScript("OnUpdate",nil);B.running=false end
end
-- data: kind (K, D, A, W, L), name, classFile, kills, deaths, assists, duelWins, duelLosses, tag, preview.
function B.Push(data)
    if type(data)~="table"or not KIND[data.kind]then return false end
    local s=settings()
    if not data.preview and(not s.banner or not s[KIND[data.kind].switch])then return false end
    if not ensureRoot()then return false end
    if #B.queue>=B.MAX_QUEUE then table.remove(B.queue,1)end
    B.queue[#B.queue+1]=data
    if not B.running then B.running=true;B.root:SetScript("OnUpdate",onUpdate)end
    B.Tick(A.Clock())
    return true
end
-- Applies size, style and position after a settings change.
function B.Apply()
    if not B.root then return end
    place()
    local style=settings().style
    for slot,f in pairs(B.rows)do
        layoutRow(f,style)
        local a=B.active[slot];if a then fill(f,a.data,style)end
    end
    if B.mover then B.mover:SetAllPoints(B.root)end
end

-- Moving: a visible handle over the first banner place; the new place is saved when the drag ends.
function B.IsUnlocked()return B.unlocked==true end
function B.Unlock()
    local root=ensureRoot();if not root then return false end
    if not B.mover then
        local m=CreateFrame("Frame",nil,root)
        m:SetAllPoints(root);try(m,"SetFrameLevel",50)
        m.bg=m:CreateTexture(nil,"OVERLAY");m.bg:SetAllPoints(m);tint(m.bg,"SetColorTexture","chipOnBg",.92)
        m.edge=m:CreateTexture(nil,"OVERLAY");m.edge:SetPoint("BOTTOMLEFT");m.edge:SetPoint("BOTTOMRIGHT");m.edge:SetHeight(2);tint(m.edge,"SetColorTexture","gold",1)
        m.text=text(m,"GameFontNormal","heading","chipOnText");m.text:SetPoint("CENTER");try(m.text,"SetJustifyH","CENTER")
        m.text:SetText(Z.T("Drag to move the banner"))
        try(m,"EnableMouse",true);try(m,"RegisterForDrag","LeftButton")
        m:SetScript("OnDragStart",function()try(root,"SetMovable",true);try(root,"StartMoving")end)
        m:SetScript("OnDragStop",function()
            try(root,"StopMovingOrSizing")
            local okRoot,x,y=pcall(root.GetCenter,root);local okParent,px,py=pcall(UIParent.GetCenter,UIParent)
            local scale=settings().scale
            if okRoot and okParent and A.Safe(x,y,px,py)and type(x)=="number"and type(px)=="number"then
                Z.Rivalry.SetPosition(x*scale-px,y*scale-py)
            else place()end
        end)
        B.mover=m
    end
    B.unlocked=true;B.mover:Show();layer()
    return true
end
function B.Lock()
    B.unlocked=false
    if B.mover then B.mover:Hide()end
    if B.root then try(B.root,"SetMovable",false)end
    layer()
    return true
end
return B
