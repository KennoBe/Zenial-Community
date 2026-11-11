-- Shared native form geometry. Existing domain validation and publish actions
-- remain authoritative; changing steps only changes the visible dialog body.
local Z,U=ZenialCommunity,ZenialCommunity.UI
local H
local function tr(s)return Z.T(s)end
local function place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y);if w then f:SetWidth(w)end;if h then f:SetHeight(h)end
end
local function field(f,x,y,w,multi)
    place(f.caption,x,y,w,28);if f.caption.SetWordWrap then f.caption:SetWordWrap(true)end
    if f.button then f:SetWidth(w);place(f.button,x,y-32,w,26)
    else place(f,x,y-32,w,multi and 54 or 26)end
end
local function tabOrder(fields)
    for i,f in ipairs(fields)do f:SetScript('OnTabPressed',function(self)
        local step=type(IsShiftKeyDown)=='function'and IsShiftKeyDown()and-1 or 1
        for distance=1,#fields do local target=fields[((i-1+distance*step)%#fields)+1]
            if target:IsVisible()then self:ClearFocus();target:SetFocus();return end
        end
    end)end
end
local function clearInputs(fields)for _,f in ipairs(fields)do f:ClearFocus()end end
local function activityInputs()
    local fields={U.groupCustom,U.groupActivitySearch,U.groupTemplateDuration,U.groupTemplateName,U.questPickerSearch,U.questDuration,U.scheduledActivity,U.scheduledDay,U.scheduledTime,U.scheduledDuration,U.scheduledNote}
    for _,group in ipairs({U.groupFields,U.questFields,U.scheduledSlots})do for _,f in pairs(group)do fields[#fields+1]=f end end
    return fields
end
local function center(f,height)
    f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,height)
end
local function showSelection(shown)
    for _,f in ipairs({U.creatorTitle,U.creatorWhen,U.creatorKind,U.creatorGoal,U.creatorText,U.creatorTemplate,U.creatorHint,U.creatorContinue,U.creatorCancel})do H.showControl(f,shown)end
end
function U.CaptureScheduledDraft()
    if not U.scheduledDate or U.activityStepBody~=U.scheduledEditor then return end
    local d={editID=U.scheduledEditingID or'',revision=U.scheduledEditingRevision or 0,activity=U.scheduledActivity:GetText(),date=U.scheduledDate:GetText(),clock=U.scheduledClock:GetText(),duration=U.scheduledDuration:GetText(),organizerRole=U.scheduledOrganizerRole:GetText(),note=U.scheduledNote:GetText()}
    for role,f in pairs(U.scheduledSlots)do d[role]=f:GetText()end
    Z.UIState.ActivityInput('scheduled',d)
end
function U.ShowActivityStep(step,body)
    if U.activityChanging then return end;U.activityChanging=true;if U.calendarPicker then U.calendarPicker:Hide()end;U.CloseDropdowns();clearInputs(activityInputs())
    if step==1 then U.CaptureScheduledDraft();U.groupEditing,U.questEditing=false,false end
    U.activityStepBody=body;U.activityStep=step
    for _,f in ipairs({U.groupForm,U.questForm,U.scheduledEditor})do f:SetShown(step==2 and f==body)end
    showSelection(step==1)
    center(U.activityCreator,step==1 and 380 or 440)
    if step==1 then U.creatorTitle:SetText(tr('Create activity')..' · '..tr('1/2 · Activity'));U.ConfigureActivityCreator()
    else body.formTitle:SetText(tr(body.formName)..' · '..tr(body.editorContext or(U.creatorFlow and '2/2 · Details'or'Details')))end
    U.activityCreator:Show();if U.Navigation then U.Navigation.Pristine('activityCreator') end;U.activityChanging=false
end
function U.BackActivityStep()
    if U.creatorFlow then U.ShowActivityStep(1)else U.activityCreator:Hide()end
end
function U.ConfigureScheduledActivity(kind,activity)
    activity=activity or U.scheduledActivity:GetText();if U.scheduledSearch then U.scheduledSearch:SetText('')end
    kind=kind or ((activity=='Questing'or activity=='Level together')and'QUEST'or Z.GroupFinder.ActivityKind(activity))
    U.scheduledKind:SetText(kind)
    local options=Z.GroupFinder.Activities[kind]or(kind=='QUEST'and{'Questing','Level together'}or{})
    U.scheduledGoal:SetOptions(options,activity)
    H.showControl(U.scheduledGoal,kind~='CUSTOM');H.showControl(U.scheduledActivity,kind=='CUSTOM')
    if kind~='CUSTOM'then U.scheduledActivity:SetText(U.scheduledGoal:GetText())end
end
function U.ApplyFormLayouts(helpers)
    H=helpers
    -- Activity selection and all three detail editors share one dialog host.
    center(U.activityCreator,380)
    field(U.creatorWhen,16,-66,300);field(U.creatorKind,334,-66,300)
    field(U.creatorGoal,16,-140,618);field(U.creatorText,16,-140,618)
    field(U.creatorTemplate,16,-206,618)
    U.creatorHint:SetWidth(618);U.creatorHint:SetHeight(42);U.creatorHint:SetWordWrap(true)
    place(U.creatorContinue,16,-324,294);place(U.creatorCancel,324,-324,310)
    U.creatorTitle:SetHeight(30)
    for _,f in ipairs({U.groupForm,U.questForm,U.scheduledEditor})do
        f:SetParent(U.activityCreator);f:SetFrameLevel(U.activityCreator:GetFrameLevel()+1)
        f:ClearAllPoints();f:SetPoint('TOPLEFT',0,0);f:SetSize(650,440)
        -- Opening is explicit below: native OnShow is deferred under a hidden
        -- parent, so it cannot be responsible for revealing the dialog host.
        f:SetScript('OnShow',nil)
        f:SetScript('OnHide',function(self)
            if not U.activityChanging and not U.activityClosing and U.activityStepBody==self then U.activityCreator:Hide()end
        end)
    end
    U.activityCreator:HookScript('OnHide',function()
        if U.activityClosing then return end;U.activityClosing=true;if U.calendarPicker then U.calendarPicker:Hide()end;if U.templateNameDialog then U.templateNameDialog:Hide()end;U.CloseDropdowns();U.CaptureScheduledDraft();clearInputs(activityInputs())
        for _,f in ipairs({U.groupForm,U.questForm,U.scheduledEditor})do f:Hide()end
        U.groupEditing,U.questEditing=false,false;U.creatorFlow=false;U.activityStepBody=nil;U.activityClosing=false;U.modalBlocker:Hide()
        Z.UIState.activityInputs={}
    end)
    U.groupForm.formTitle=H.label(U.groupForm,'Details',16,-18,618,'GameFontNormalLarge')
    U.questForm.formTitle=H.label(U.questForm,'Details',16,-18,618,'GameFontNormalLarge')
    U.scheduledEditor.formTitle=U.scheduledFormTitle;U.groupForm.formName='Group';U.questForm.formName='Quest assistance';U.scheduledEditor.formName='Scheduled event'
    -- Compact group composer: short numeric inputs sit beside their labels.
    local function inline(f,x,y,w,labelWidth)
        place(f.caption,x,y,labelWidth or 100,26);place(f,x+(labelWidth or 100),y+2,w,26)
    end
    local function activityHeader(kind,goal,custom,search,discard)
        field(kind,16,-62,180);field(goal,208,-62,426);field(custom,208,-62,426)
        place(kind.button,16,-92,180);place(goal.button,208,-92,426);place(custom,208,-92,426,26)
        goal.caption:SetWidth(90);custom.caption:SetWidth(90)
        place(search,300,-62,168,26);search.caption:Hide();place(discard,480,-62,154)
    end
    activityHeader(U.groupKind,U.groupActivity,U.groupCustom,U.groupActivitySearch,U.groupDiscard)
    U.groupFields.size.caption:SetText(tr('Group size'));inline(U.groupFields.size,16,-140,54,116);inline(U.groupFields.min,208,-140,54,56)
    U.groupFields.min.caption:SetText(tr('Level'));U.groupFields.max.caption:SetText('–');inline(U.groupFields.max,330,-140,54,26)
    for i,key in ipairs({'tank','healer','dd'})do inline(U.groupFields[key],16+(i-1)*208,-184,54,108)end
    field(U.groupFields.note,16,-228,618,true);place(U.groupFields.note,16,-258,618,54)
    U.groupFields.note.caption:SetWidth(180);place(U.groupNoteCount,208,-230,96,20)
    inline(U.groupTemplateDuration,350,-228,114,170)
    place(U.groupHaveCaption,16,-334,124,26);place(U.groupHave,142,-334,492,40)
    U.groupTemplateHint:Hide();U.groupFormPreview:Hide()
    place(U.groupFormBack,16,-396,196);place(U.groupTemplateSave,224,-396,196);place(U.groupSave,432,-396,202)
    U.templateNameDialog=H.panel(U.activityCreator);local naming=U.templateNameDialog;naming:ClearAllPoints();naming:SetPoint('CENTER');naming:SetSize(650,210)
    H.label(naming,'Save template',16,-18,618,'GameFontNormalLarge')
    U.groupTemplateName:SetParent(naming);U.groupTemplateName.caption:SetParent(naming);field(U.groupTemplateName,16,-66,618)
    H.button(naming,tr('Save template'),16,-164,294,function()if U.SaveGroupTemplate()then naming:Hide()end end,'primary')
    H.button(naming,tr('Cancel'),324,-164,310,function()naming:Hide()end)
    H.makeModal(naming);naming:SetFrameLevel(U.activityCreator:GetFrameLevel()+20);naming:Hide()
    U.groupTemplateSave:SetScript('OnClick',function()naming:Show();U.Navigation.Pristine('templateNameDialog')end)
    -- Quest requests use the same label and field baselines.
    U.questFormContent:ClearAllPoints();U.questFormContent:SetPoint('TOPLEFT',0,0);U.questFormContent:SetSize(650,440)
    U.questFormContent:SetFrameLevel(U.questForm:GetFrameLevel()+1)
    field(U.questPicker,16,-62,300);field(U.questPickerSearch,334,-62,300)
    field(U.questFields.title,16,-130,618)
    U.questFields.zone.caption:SetText(tr('Zone'));inline(U.questFields.zone,16,-202,180,56);inline(U.questFields.min,282,-202,54,56)
    U.questFields.min.caption:SetText(tr('Level'));U.questFields.max.caption:SetText('–');inline(U.questFields.max,408,-202,54,26)
    inline(U.questDuration,350,-246,114,170)
    field(U.questFields.note,16,-246,618,true);U.questFields.note.caption:SetWidth(180)
    place(U.questFields.note,16,-276,618,54);place(U.questNoteCount,208,-248,96,20);U.questFormPreview:Hide()
    place(U.questFormBack,16,-396,196);place(U.questDiscard,224,-396,196);place(U.questSave,432,-396,202)
    -- Scheduled groups use the same activity chooser as the first step.
    local kinds={'DUNGEON','RAID','PVP','QUEST','CUSTOM'}
    U.scheduledKind=H.selector(U.scheduledEditor,'Category',16,-62,196,kinds,function(kind)
        U.ConfigureScheduledActivity(kind,U.scheduledActivity:GetText())
    end,function(k)return tr(({DUNGEON='Dungeon',RAID='Raid',PVP='PvP',QUEST='Questing',CUSTOM='Other'})[k])end)
    U.scheduledGoal=H.selector(U.scheduledEditor,'Activity',224,-62,410,{},function(goal)U.scheduledActivity:SetText(goal)end,function(goal)return Z.Locale.Activity(goal)end)
    U.scheduledSearch=H.edit(U.scheduledEditor,'Search activity',300,-62,168,64)
    U.scheduledSearch:SetScript('OnTextChanged',function()
        local kind=U.scheduledKind:GetText();local choices=Z.GroupFinder.Activities[kind]or(kind=='QUEST'and{'Questing','Level together'}or{})
        local options={};local query=string.lower(U.scheduledSearch:GetText())
        for _,goal in ipairs(choices)do if query==''or string.lower(Z.Locale.Activity(goal)):find(query,1,true)then options[#options+1]=goal end end
        U.scheduledGoal:SetOptions(options,U.scheduledGoal:GetText());if #options>0 then U.scheduledActivity:SetText(U.scheduledGoal:GetText())end
    end)
    U.scheduledDiscard=H.button(U.scheduledEditor,tr('Discard draft'),480,-62,154,function()
        U.scheduledEditor:Hide();Z.UIState.Draft('scheduled',false)
    end,'danger')
    activityHeader(U.scheduledKind,U.scheduledGoal,U.scheduledActivity,U.scheduledSearch,U.scheduledDiscard)
    U.scheduledDay=H.edit(U.scheduledEditor,'Date (YYYY-MM-DD)',16,-130,196,10)
    U.scheduledTime=H.edit(U.scheduledEditor,'Time (HH:MM)',224,-130,196,5)
    local restoring=false
    local function compose()
        if restoring then return end;restoring=true;U.scheduledDate:SetText(U.scheduledDay:GetText()..' '..U.scheduledTime:GetText());restoring=false
    end
    U.scheduledDay:SetScript('OnTextChanged',compose);U.scheduledTime:SetScript('OnTextChanged',compose)
    U.scheduledDate:SetScript('OnTextChanged',function(self)
        if restoring then return end;restoring=true;local day,clock=self:GetText():match('^(%S+)%s+(%S+)$')
        U.scheduledDay:SetText(day or self:GetText());U.scheduledTime:SetText(clock or'');restoring=false
    end)
    H.showControl(U.scheduledDate,false);H.showControl(U.scheduledClock,false);H.showControl(U.scheduledOrganizerRole,false)
    U.scheduledDay.caption:SetText(tr('Date'));U.scheduledTime.caption:SetText(tr('Time'))
    inline(U.scheduledDay,16,-140,130,64);inline(U.scheduledTime,284,-140,68,64)
    U.scheduledNote.caption:SetText(tr('Comment (optional)'));U.groupFields.note.caption:SetText(tr('Comment (optional)'))
    for i,role in ipairs({'TANK','HEALER','DAMAGER'})do
        U.scheduledSlots[role].caption:SetText(tr(({TANK='Tank needed',HEALER='Healer needed',DAMAGER='Damage needed'})[role]))
        inline(U.scheduledSlots[role],16+(i-1)*208,-184,54,108)
    end
    field(U.scheduledNote,16,-228,618,true);place(U.scheduledNote,16,-258,618,54);U.scheduledNote.caption:SetWidth(180)
    U.scheduledNoteCount=H.label(U.scheduledEditor,'0 / 96',208,-230,96)
    U.scheduledNote:SetScript('OnTextChanged',function()U.scheduledNoteCount:SetText(#U.scheduledNote:GetText()..' / 96')end)
    inline(U.scheduledDuration,350,-228,114,170);place(U.scheduledEditorNotice,16,-330,618,54)
    place(U.scheduledBack,16,-396,196);place(U.scheduledSave,432,-396,202);U.scheduledSave:SetText(tr('Publish event'));U.scheduledEditorCancel:Hide()
    U.CreateSchedulePickers(H)
    -- Weekly review is another bounded dialog with the same footer.
    center(U.scheduledSeries,550);place(U.scheduledSeriesTitle,16,-18,618,36)
    place(U.scheduledSeriesRule,16,-60,618,40);field(U.scheduledSeriesCount,16,-112,196)
    place(U.scheduledSeriesPreviewButton,224,-144,196);place(U.scheduledTemplateDelete,432,-144,202)
    place(U.scheduledSeriesPreview,16,-202,594,260);U.scheduledSeriesPreview.height=260
    place(U.scheduledSeriesCreate,16,-512,294);place(U.scheduledSeriesCancel,324,-512,310)
    -- Wishes remain private and last until the local calendar day changes.
    center(U.homeWishPanel,440);U.sessionPlanFrame:ClearAllPoints();U.sessionPlanFrame:SetPoint('TOPLEFT',16,-18);U.sessionPlanFrame:SetSize(618,350)
    place(U.sessionState,0,-32,618,30)
    for i,row in ipairs(U.sessionRows)do local y=-80-(i-1)*78
        field(row.kind,0,y,210);field(row.target,226,y,392);field(row.text,226,y,392);row.hint:Hide()
    end
    H.showControl(U.sessionDuration,false)
    U.sessionSave:SetText(tr('Save wishes'));U.sessionEnd:SetText(tr('Clear wishes'))
    place(U.sessionSave,0,-302,294);place(U.sessionEnd,308,-302,310);place(U.sessionEditStatus,0,-338,618,28)
    place(U.homeWishClose,16,-392,618)
    -- Crafting and material forms keep the same field baselines and footer.
    center(U.craftOrderForm,580);place(U.craftOrderContextText,16,-48,618,40)
    field(U.craftOrderQuantity,16,-94,196);field(U.craftOrderTip,224,-94,196)
    place(U.craftOrderMaterials,438,-126);place(U.craftOrderMaterials.text,465,-130,169,36)
    field(U.craftMaterialCount,16,-168,196)
    U.craftYieldNote:SetText(tr('Craft count is the number of crafting operations.'))
    place(U.craftYieldNote,224,-172,410,54);place(U.craftIngredientTitle,16,-232,618,24)
    place(U.craftIngredientList,16,-256,594,100);U.craftIngredientList.height=100
    place(U.craftShoppingSave,16,-368,294);place(U.craftShoppingOpen,324,-368,310)
    field(U.craftOrderNote,16,-412,618,true)
    place(U.craftOrderSend,16,-534,294);place(U.craftOrderCancel,324,-534,310)
    center(U.materialOrderForm,330);place(U.materialOrderText,16,-50,618,80)
    field(U.materialOrderCount,16,-152,300);place(U.materialOrderSave,16,-278,294);place(U.materialOrderCancel,324,-278,310)
    -- Compact application forms follow the same label/input/action baselines.
    U.groupApplyNote.caption:SetText(tr('Message (optional)'))
    field(U.groupRole,0,0,125);field(U.groupApplyNote,140,0,270)
    place(U.groupApplicationSend,0,-78,196);place(U.groupApplicationCancel,212,-78,198)
    field(U.questHelpNote,0,0,410)
    place(U.questApplicationSend,0,-78,196);place(U.questApplicationCancel,212,-78,198)
    U.pvpCallNote.caption:SetText(tr('Wer greift dich an? Anzahl und Level (optional, z. B. 3× Level 60)'));field(U.pvpCallNote,0,-116,520,true)
    -- Inline trade/profile forms follow the same spacing within their page.
    field(U.offerKind,0,0,195);field(U.offerFields.name,210,0,420)
    field(U.offerFields.quantity,0,-68,110);field(U.offerFields.gold,124,-68,130)
    field(U.offerFields.silver,268,-68,100);field(U.offerFields.copper,382,-68,100)
    U.offerDuration.caption:SetText(tr('Offer expires (minutes)'));field(U.offerDuration,496,-68,134)
    field(U.offerFields.note,0,-140,630,true)
    place(U.offerSave,0,-248,196);place(U.offerDiscard,212,-248,196);place(U.offerSaveDraft,424,-248,206)
    U.tradeMinPrice.caption:SetText(tr('Min. unit price (gold)'));U.tradeMaxPrice.caption:SetText(tr('Max. unit price (gold)'))
    field(U.tradeMinPrice,0,-48,120);field(U.tradeMaxPrice,132,-48,120);field(U.tradeSort,264,-48,205)
    -- Keep the price-filter footer clear of the results table.
    place(U.offerCount,480,-80,360,20);place(U.offerList,0,-112,455,260);U.offerList.height=260
    place(U.offerDetail,480,-112,360,240)
    field(U.profileFields.community,0,-66,260);field(U.profileRole,280,-66,190)
    field(U.profileFields.note,0,-140,470,true)
    place(U.profileSave,0,-248,196);place(U.profileShow,212,-248,258)
    tabOrder({U.scheduledActivity,U.scheduledDay,U.scheduledTime,U.scheduledDuration,U.scheduledSlots.TANK,U.scheduledSlots.HEALER,U.scheduledSlots.DAMAGER,U.scheduledNote})
    tabOrder({U.groupCustom,U.groupActivitySearch,U.groupFields.min,U.groupFields.max,U.groupFields.size,U.groupFields.tank,U.groupFields.healer,U.groupFields.dd,U.groupFields.note,U.groupTemplateDuration,U.groupTemplateName})
    tabOrder({U.questPickerSearch,U.questFields.title,U.questFields.zone,U.questFields.min,U.questFields.max,U.questDuration,U.questFields.note})
    tabOrder({U.craftOrderQuantity,U.craftOrderTip,U.craftMaterialCount,U.craftOrderNote})
    tabOrder({U.sessionRows[1].text,U.sessionRows[2].text,U.sessionRows[3].text})
    U.homeWishPanel:HookScript('OnHide',function()clearInputs({U.sessionRows[1].text,U.sessionRows[2].text,U.sessionRows[3].text});U.CloseDropdowns()end)
    U.craftOrderForm:HookScript('OnHide',function()clearInputs({U.craftOrderQuantity,U.craftOrderTip,U.craftMaterialCount,U.craftOrderNote});U.CloseDropdowns()end)
    U.materialOrderForm:HookScript('OnHide',function()U.materialOrderCount:ClearFocus()end)
    for _,entry in ipairs({{'OpenGroupEditor',U.groupForm},{'OpenQuestEditor',U.questForm},{'OpenScheduledEditor',U.scheduledEditor}})do
        local open,body=U[entry[1]],entry[2]
        U[entry[1]]=function(record)
            open(record)
            U.ConfigureActivityEditor(body,record)
            U.ShowActivityStep(2,body)
            if U.Navigation then U.Navigation.Pristine('activityCreator');U.Navigation.Pristine('scheduledEditor') end
        end
    end
end
return U
