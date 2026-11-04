-- Local notification cards. Dismissing a card never clears unread activity data.
local Z,U,T,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Theme,ZenialCommunity.Adapter
local frames,sequence,layingOut={},0,false
function U.LayoutNotices()
    if layingOut then return end;layingOut=true
    local active={};for _,f in ipairs(frames)do if f:IsShown()then active[#active+1]=f end end
    table.sort(active,function(a,b)return(a.noticeSequence or 0)>(b.noticeSequence or 0)end)
    local screen=UIParent:GetHeight();local top=math.min(240,math.floor(screen*.28));local y=top
    for i,f in ipairs(active)do
        local measured=A.Call(f.text.GetStringHeight,f.text)or 44
        local height=math.max(f.noticeMinHeight,math.ceil(measured)+54)
        if i>3 or y+height>screen-24 then f:Hide()
        else
            f:SetHeight(height);f.text:SetHeight(height-54)
            f:ClearAllPoints();f:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-20,-y);y=y+height+10
        end
    end
    layingOut=false
end
function U.NewNotice(name,width,height)
    local f=CreateFrame('Button',name,UIParent,BackdropTemplateMixin and'BackdropTemplate'or nil)
    width=340;f.noticeMinHeight=math.max(96,height)
    f:SetSize(width,f.noticeMinHeight);f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:RegisterForClicks('LeftButtonUp')
    if T then T.Panel(f,'inset')elseif f.SetBackdrop then
        f:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=16,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
        f:SetBackdropColor(.045,.031,.021,.99);f:SetBackdropBorderColor(.72,.49,.18,1)
    end
    local function text(font,x,y,w)
        local t=f:CreateFontString(nil,'OVERLAY',font);t:SetPoint('TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetJustifyV('TOP');t:SetWordWrap(true);return t
    end
    f.heading=text('GameFontNormal',16,-12,width-60);f.heading:SetHeight(18);f.heading:SetTextColor(1,.8,.27,1);f.heading:SetText(Z.T('New update'))
    f.text=text('GameFontHighlightSmall',16,-38,width-32);f.text:SetHeight(f.noticeMinHeight-54);f.text:SetTextColor(.96,.9,.76,1)
    local close=Z.UI.CloseButton(f,-6,-6,function()f:Hide()end,24);f.closeButton=close
    f:SetScript('OnShow',function(self)
        sequence=sequence+1;self.noticeSequence=sequence
        if not self.skipHistory and Z.Notifications then Z.Notifications.Log(self.heading:GetText(),self.text:GetText())end
        U.LayoutNotices()
    end)
    f:SetScript('OnHide',function(self)self.hovered=false;U.LayoutNotices()end)
    f:SetScript('OnEnter',function(self)self.hovered=true end)
    f:SetScript('OnLeave',function(self)self.hovered=false;if self.hideAt then self.hideAt=math.max(self.hideAt,A.Clock()+3)end end)
    frames[#frames+1]=f;f:Hide();return f
end
