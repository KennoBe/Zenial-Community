local Z,U,N=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Notifications
local H
function U.RefreshNotificationInbox()
    if not U.notificationBell then return end
    local unread=N.RecentUnread();U.notificationBellCount:SetText(unread>0 and tostring(unread)or'');U.notificationBellBadge:SetShown(unread>0)
    if not U.notificationInbox:IsShown()then return end
    local rows={}
    for _,item in ipairs(N.Recent())do local stored=item
        local civil=Z.ScheduleTime.Local(item.at)or Z.ScheduleTime.UTC(item.at)
        local stamp=civil and string.format('%02d:%02d',civil.hour,civil.min)or''
        rows[#rows+1]={text=stamp..' · '..item.text,noWrap=true,height=30,click=function()
            U.notificationInbox:Hide()
            if stored.entry then U.OpenUpdate(stored.entry)
            elseif N.cardActions and N.cardActions[stored.logID]then N.cardActions[stored.logID]()end
        end}
    end
    U.notificationInboxCount:SetText(Z.T('Last %d notifications',#rows))
    if #rows==0 then rows={{text=Z.T('No notifications yet.'),height=30}}end
    H.rows(U.notificationInboxList,rows,30)
end
function U.CreateNotificationInbox(helpers)
    H=helpers
    local bell=H.button(U.frame,'',0,0,34,function()
        if U.notificationInbox:IsShown()then U.notificationInbox:Hide();return end
        U.CloseDialogs();U.CloseDropdowns();N.ReadRecent();U.notificationInbox:Show();U.RefreshNotificationInbox()
    end);U.notificationBell=bell;bell:ClearAllPoints();bell:SetPoint('TOPRIGHT',U.frame,'TOPRIGHT',-344,-20);bell:SetHeight(30)
    local icon=bell:CreateTexture(nil,'ARTWORK');icon:SetSize(22,22);icon:SetPoint('CENTER');icon:SetTexture('Interface\\AddOns\\ZenialCommunity\\Media\\Bell.tga')
    local badge=CreateFrame('Frame',nil,bell,BackdropTemplateMixin and'BackdropTemplate'or nil);U.notificationBellBadge=badge;badge:SetSize(20,16);badge:SetPoint('TOPRIGHT',5,4);Z.Theme.Panel(badge,'inset')
    U.notificationBellCount=badge:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');U.notificationBellCount:SetAllPoints();U.notificationBellCount:SetJustifyH('CENTER')
    bell:SetScript('OnEnter',function()if GameTooltip then GameTooltip:SetOwner(bell,'ANCHOR_BOTTOM');GameTooltip:AddLine(Z.T('Notifications'));GameTooltip:Show()end end)
    bell:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
    local popup=H.panel(U.frame);U.notificationInbox=popup;popup:ClearAllPoints();popup:SetPoint('TOPRIGHT',U.frame,'TOPRIGHT',-30,-65);popup:SetSize(650,350)
    H.label(popup,'Notifications',16,-16,450,'GameFontNormalLarge')
    H.button(popup,Z.T('Close'),524,-12,110,function()popup:Hide()end)
    U.notificationInboxList=H.list(popup,16,-52,618,260);U.notificationInboxCount=H.label(popup,'',16,-326,618)
    H.makeModal(popup);popup:Hide();U.RefreshNotificationInbox()
end
return U
