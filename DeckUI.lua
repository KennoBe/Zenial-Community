-- Zenial Deck dialog: fills the five favourite slots and shows the state of the automatic keys (DeckBindings.lua).
-- A window of its own like the Companion dialog, built from the current kit (UIKit.lua) and the helpers of UX.lua.
local Z,A,L=ZenialCommunity,ZenialCommunity.Adapter,ZenialCommunity.Logic
local D,K,T=Z.Deck,Z.Kit,Z.Theme
local DK={};Z.DeckUI=DK
local NAME,WIDTH,HEIGHT,PAD='ZenialDeckDialog',700,580,16
local ROW_TOP,ROW_STEP,ROW_HEIGHT=202,56,50
local function tr(...)return Z.T(...)end
local function text(parent,role,x,y,w,h,colorKey,wrap)
    local fs=K.Text(parent,'',role,colorKey);fs:SetPoint('TOPLEFT',x,y);fs:SetSize(w,h);fs:SetJustifyH('LEFT');fs:SetJustifyV('TOP')
    if wrap==false and fs.SetWordWrap then pcall(fs.SetWordWrap,fs,false)end
    return fs
end
local function plain(value)return(tostring(value or''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''))end
local function exportOn()local C=Z.Companion;return C and C.settings and C.settings.enabled==true or false end
-- Favourites that are known contacts, by name.
local function favorites()
    local out={};local social=Z.Social;local list=social and social.store and social.store.favorites
    if type(list)~='table'or not Z.db or not Z.db.contacts then return out end
    for key in pairs(list)do
        local contact=Z.db.contacts[key]
        if contact and type(contact.target)=='string'and contact.target~=''then out[#out+1]={key=key,name=contact.target}end
    end
    table.sort(out,function(a,b)
        local x,y=a.name:lower(),b.name:lower();if x~=y then return x<y end;return a.key<b.key
    end)
    return out
end
local function keyLine(map,slot)
    local parts={}
    for _,spec in ipairs({{'whisper','Whisper'},{'invite','Invite'},{'profile','Profile'}})do
        local entry=map['slot'..slot..'_'..spec[1]];local key=entry and entry.key
        parts[#parts+1]=K.Fact(tr(spec[2])..': ',key or tr('no key'),key and'text'or'muted')
    end
    return table.concat(parts,K.Paint('dim',' · '))
end
local function nameText(slot)
    if not slot then return K.Paint('muted',tr('not assigned'))end
    local hex=T.ClassColorHex and T.ClassColorHex(slot.classFile)
    if hex then return'|cff'..hex..slot.target..'|r'end
    return K.Paint('text',slot.target)
end
local function resetSelector(selector,enabled)
    selector.value='';selector.button:SetText(tr('Choose favorite'))
    selector.button:SetEnabled(enabled)
end

local function message(value)
    if DK.frame then DK.message=value;DK.frame.message:SetText(value and K.Paint('warning',value)or'')end
end
local function slotChanged(index,key)
    local ok,why=D.SetSlot(index,key)
    message(not ok and tr(why or'Deck unavailable.')or nil)
    DK.Refresh()
end
local function useTarget(index)
    local key,name,realm=A.UnitIdentity('target')
    if not key or not Z.me then message(tr('Target a player first.'));return end
    local scoped=name and L.ScopeKey(name,realm,Z.me.faction)
    if not(scoped and Z.db and Z.db.contacts[scoped])then scoped=Z.ResolvePeerKey(name)end
    if not scoped or not Z.db.contacts[scoped]then message(tr('The target is not a known contact.'));return end
    slotChanged(index,scoped)
end

local function build()
    local f=CreateFrame('Frame',NAME,UIParent,BackdropTemplateMixin and'BackdropTemplate'or nil);DK.frame=f
    f:SetSize(WIDTH,HEIGHT);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(300);f:SetToplevel(true)
    f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton')
    local height=A and A.Call and A.Call(UIParent.GetHeight,UIParent)or UIParent:GetHeight()
    if type(height)=='number'and height>0 and height<HEIGHT+20 then f:SetScale(math.max(.65,height/(HEIGHT+40)))end
    f:SetScript('OnDragStart',function(self)self:StartMoving()end);f:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
    if T then T.Shell(f)end
    local S=Z.UI.Shared
    K.DialogHeader(f,S.label(f,'Zenial Deck',PAD,-18,WIDTH-2*PAD,'GameFontNormalLarge'),function()f:Hide()end)

    -- State: switch, two facts, hints (warning colour).
    f.auto=S.checkbox(f,'Assign keys automatically',PAD,-54,420,function(self)
        local store=D.Init();if store then store.auto=self:GetChecked()==true;D.Request()end
        DK.Refresh()
    end)
    f.facts=text(f,'body',PAD,-84,WIDTH-2*PAD,30)
    f.hints=text(f,'caption',PAD,-116,WIDTH-2*PAD,44)

    local header=K.SectionHeader(f,tr('Favorite slots'));header:SetPoint('TOPLEFT',PAD,-164);header:SetWidth(WIDTH-2*PAD);f.sectionHeader=header
    f.noFavorites=text(f,'caption',PAD,-184,WIDTH-2*PAD,14,'dim',false)

    -- Slots: plate, "Slot N", name, three keys, favourite choice, target, clear.
    f.rows={}
    for index=1,D.SLOTS do
        local top=ROW_TOP+(index-1)*ROW_STEP;local row={}
        row.plate=K.Plate(f,'surface');row.plate:Place(PAD,top,WIDTH-2*PAD,ROW_HEIGHT)
        row.label=text(f,'caption',PAD+8,-(top+11),48,14,'dim',false);row.label:SetText(tr('Slot %d',index))
        row.name=text(f,'heading',PAD+60,-(top+8),190,16,nil,false)
        row.keys=text(f,'caption',PAD+60,-(top+32),WIDTH-2*PAD-70,14,nil,false)
        local right=WIDTH-PAD-8
        row.clear=S.button(f,'Clear',right-80,-(top+6),80,function()slotChanged(index,nil)end)
        row.target=S.button(f,'Use target',right-80-8-140,-(top+6),140,function()useTarget(index)end)
        local selectorX=right-80-8-140-8-170
        row.selector=S.selector(f,'',selectorX,-(top+6)+17,170,{},function(value)
            resetSelector(row.selector,true);slotChanged(index,value)
        end,function(value)local c=Z.db and Z.db.contacts[value];return c and c.target or tostring(value)end)
        row.selector:SetPopupWidth(220)
        f.rows[index]=row
    end
    f.message=text(f,'caption',PAD,-484,WIDTH-2*PAD,14,'warning',false)
    f.note=text(f,'caption',PAD,-504,WIDTH-2*PAD,28)
    f.note:SetText(tr('You can also set the keys yourself in the key bindings under "Zenial Community".'))
    f.close=S.button(f,'Close',WIDTH-PAD-125,-540,125,function()f:Hide()end)

    f:SetScript('OnShow',function()DK.Refresh()end)
    f:SetScript('OnUpdate',function(self,elapsed)
        self.tick=(self.tick or 0)+(elapsed or 0);if self.tick<.5 then return end;self.tick=0;DK.Refresh()
    end)
    UISpecialFrames=UISpecialFrames or{}
    local registered=false;for _,name in ipairs(UISpecialFrames)do if name==NAME then registered=true end end
    if not registered then UISpecialFrames[#UISpecialFrames+1]=NAME end
    f:Hide()
    return f
end

function DK.Refresh()
    local f=DK.frame;if not f or not f:IsShown()then return end
    local store=D.Init();local available=store~=nil and D.Available()
    f.auto:SetChecked(store and store.auto==true or false);f.auto:SetEnabled(store~=nil)
    local assigned,map=0,{}
    for _,entry in ipairs(D.Effective())do map[entry.id]=entry;if entry.key then assigned=assigned+1 end end
    local auto=store and store.auto==true
    f.facts:SetText(K.Fact(tr('Automatic keys')..': ',tr(auto and'on'or'off'),auto and'success'or'textSoft')..'\n'
        ..K.Fact(tr('Actions assigned')..': ',tr('%d of %d',assigned,#D.ACTIONS)))
    local hints={}
    if not available then hints[#hints+1]=tr('ZENIAL Deck is not available.')end
    if store and not exportOn()then hints[#hints+1]=tr('The Companion export is off, so no keys are assigned.')end
    if D.pending then hints[#hints+1]=tr('Waiting for the end of combat.')end
    if D.state and D.state.exhausted then hints[#hints+1]=tr('No free key combination is left. Assign the remaining actions under Key Bindings.')end
    for index,hint in ipairs(hints)do hints[index]=K.Paint('warning',hint)end
    f.hints:SetText(table.concat(hints,'\n'))

    local list=favorites();local signature={}
    for _,entry in ipairs(list)do signature[#signature+1]=entry.key..'='..entry.name end
    signature=table.concat(signature,'\0')
    f.noFavorites:SetText(#list==0 and K.Paint('dim',tr('Mark fellow players as favorites (star) to pick them here.'))or'')
    local slots={};for _,slot in ipairs(D.Slots())do slots[slot.index]=slot end
    for index,row in ipairs(f.rows)do
        local slot=slots[index]
        row.name:SetText(nameText(slot));row.keys:SetText(keyLine(map,index))
        if row.signature~=signature then
            local options={};for _,entry in ipairs(list)do options[#options+1]=entry.key end
            row.selector:SetOptions(options,'');row.signature=signature
        end
        resetSelector(row.selector,store~=nil and #list>0)
        row.target:SetEnabled(store~=nil);row.clear:SetEnabled(slot~=nil)
    end
    f.message:SetText(DK.message and K.Paint('warning',DK.message)or'')
end

function DK.Show()
    if not D or not Z.UI or not Z.UI.Shared or not K then return end
    if not DK.frame then build()end
    DK.message=nil;DK.frame:SetFrameStrata('FULLSCREEN_DIALOG');DK.frame:SetFrameLevel(300);DK.frame:Show()
    if DK.frame.Raise then DK.frame:Raise()end
    DK.Refresh()
end
return DK
