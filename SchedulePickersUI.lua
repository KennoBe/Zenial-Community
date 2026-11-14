local Z,U,T,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.ScheduleTime,ZenialCommunity.Adapter
local function tr(s)return Z.T(s)end
function U.AutofillGroupNeeds()
    local size=tonumber(U.groupFields.size:GetText());if not Z.Logic.Int(size,2,40)then return end
    local state=A.GroupState();local tank,heal,dd=state.tank,state.healer,state.dd
    local assigned=A.Call(UnitGroupRolesAssigned,'player');local preferred=Z.Logic.Role(Z.db.roles)
    if assigned~='TANK'and assigned~='HEALER'and assigned~='DAMAGER'and preferred then
        if preferred=='TANK'then tank=tank+1 elseif preferred=='HEALER'then heal=heal+1 else dd=dd+1 end
    end
    -- Tanks and healers a group of this size usually takes (5: 1/1, 10: 2/2, 20: 2/4, 40: 4/8). PvP is usually
    -- played with one tank (the flag carrier), whatever the size.
    local pvp=U.groupKind and U.groupKind:GetText()=='PVP'
    local needTank=pvp and 1 or size>=40 and 4 or size>=10 and 2 or 1;local needHeal=size>=40 and 8 or size>=20 and 4 or size>=10 and 2 or 1
    local unknown=math.max(0,state.total-tank-heal-dd);local remaining=math.max(0,size-state.total);local wantedTank=math.min(remaining,math.max(0,needTank-tank));local wantedHeal=math.min(remaining-wantedTank,math.max(0,needHeal-heal));U.groupAutofilling=true;U.groupNeedsAuto=true
    U.groupFields.tank:SetText(tostring(wantedTank));U.groupFields.healer:SetText(tostring(wantedHeal))
    U.groupFields.dd:SetText(tostring(math.max(0,remaining-wantedTank-wantedHeal)));U.groupAutofilling=false
    U.groupHave:SetText(state.total==1 and tr('Solo')or Z.T('%d players in your group',state.total));if unknown>0 then U.groupHave:SetText(U.groupHave:GetText()..'\n'..Z.T('%d group roles unknown; check the needed roles.',unknown))end
    U.CaptureGroupDraft()
end
function U.CreateSchedulePickers(H)
    local openGroup=U.OpenGroupEditor
    U.OpenGroupEditor=function(g)
        U.groupLoading=true;U.groupNeedsAuto=not g and not Z.UIState.Draft('group');openGroup(g);U.groupLoading=false
    end
    for _,key in ipairs({'tank','healer','dd'})do U.groupFields[key]:SetScript('OnTextChanged',function()
        if not U.groupLoading and not U.groupAutofilling then U.groupNeedsAuto=false end;U.CaptureGroupDraft()
    end)end
    U.groupFields.size:SetScript('OnTextChanged',function()
        if not U.groupLoading and not U.groupAutofilling then U.AutofillGroupNeeds()end;U.CaptureGroupDraft()
    end)
    for _,search in ipairs({U.groupActivitySearch,U.scheduledSearch})do
        local hint=H.label(search,'Search',6,-6,search:GetWidth()-12);Z.Theme.Tint(hint,'SetTextColor','muted')
        search:HookScript('OnTextChanged',function(self)hint:SetShown(self:GetText()=='')end)
    end
    local f=H.panel(U.scheduledEditor);U.calendarPicker=f;f:ClearAllPoints();f:SetPoint('TOPLEFT',U.scheduledDay,'BOTTOMLEFT',0,-5);f:SetSize(310,310)
    f:SetFrameStrata('TOOLTIP');f:EnableMouse(true);f:SetClampedToScreen(true)
    local title=H.label(f,'',58,-16,194,'GameFontNormal')
    local previous,nextButton
    local cells={};local todayButton
    local function civil(at)return U.scheduledClock:GetText()=='LOCAL'and T.Local(at)or T.UTC(at)end
    local function month(c)return c and c.year*12+c.month end
    local function render()
        local first={year=f.year,month=f.month,day=1,hour=0,min=0,sec=0};local at=T.Epoch(first);if not at then return end
        title:SetText(string.format('%04d – %02d',f.year,f.month))
        local start=at-((T.UTC(at).wday+5)%7)*86400;local current=civil(A.Now());local last=civil(A.Now()+Z.ScheduledGroups.HORIZON)
        previous:SetEnabled(current~=nil and month(first)>month(current));nextButton:SetEnabled(last~=nil and month(first)<month(last))
        local selected=U.scheduledDay:GetText()
        for i,b in ipairs(cells)do local c=T.UTC(start+(i-1)*86400)
            local value=c and string.format('%04d-%02d-%02d',c.year,c.month,c.day)
            b.value=value;b:SetText(c and tostring(c.day)or'')
            local minimum=current and T.Epoch({year=current.year,month=current.month,day=current.day,hour=0,min=0})
            local maximum=last and T.Epoch({year=last.year,month=last.month,day=last.day,hour=0,min=0})
            b:SetEnabled(c~=nil and c.month==f.month and minimum~=nil and maximum~=nil and start+(i-1)*86400>=minimum and start+(i-1)*86400<=maximum)
            if Z.Theme then Z.Theme.SetSelected(b,value==selected)end
        end
    end
    previous=H.button(f,'<',16,-12,32,function()f.month=f.month-1;if f.month<1 then f.month=12;f.year=f.year-1 end;render()end)
    nextButton=H.button(f,'>',262,-12,32,function()f.month=f.month+1;if f.month>12 then f.month=1;f.year=f.year+1 end;render()end)
    local weekdays=Z.Locale.isGerman and{'Mo','Di','Mi','Do','Fr','Sa','So'}or{'Mo','Tu','We','Th','Fr','Sa','Su'}
    for i,name in ipairs(weekdays)do H.label(f,name,16+(i-1)*40,-48,36)end
    for i=1,42 do cells[i]=H.button(f,'',16+((i-1)%7)*40,-74-math.floor((i-1)/7)*32,36,function(self)
        if self.value then U.scheduledDay:SetText(self.value);f:Hide()end
    end)end
    todayButton=H.button(f,tr('Today'),16,-270,134,function()local c=civil(A.Now());if c then U.scheduledDay:SetText(string.format('%04d-%02d-%02d',c.year,c.month,c.day));f:Hide()end end)
    H.button(f,tr('Close'),160,-270,134,function()f:Hide()end);f:Hide()
    U.scheduledDatePicker=H.button(U.scheduledEditor,'...',220,-138,26,function()
        U.CloseDropdowns();if f:IsShown()then f:Hide();return end
        local at=T.Parse(U.scheduledDay:GetText()..' 00:00','UTC');local c=at and T.UTC(at)or civil(A.Now())
        if not c then return end;f.year,f.month=c.year,c.month;render();f:Show()
    end)
    local times={};for hour=0,23 do for minute=0,45,15 do times[#times+1]=string.format('%02d:%02d',hour,minute)end end
    U.scheduledTimePicker=H.selector(U.scheduledEditor,'',428,-121,92,times,function(value)U.scheduledTime:SetText(value)end)
    U.scheduledTimePicker.caption:Hide();U.scheduledTimePicker.button:SetWidth(26);U.scheduledTimePicker.button:SetText('')
    local synchronize=U.scheduledTime:GetScript('OnTextChanged')
    U.scheduledTime:SetScript('OnTextChanged',function(self,...)
        synchronize(self,...);U.scheduledTimePicker:SetText(self:GetText());U.scheduledTimePicker.button:SetText('');f:Hide()
    end)
    U.scheduledTimePicker.button:HookScript('OnClick',function()f:Hide()end)
end
return U
