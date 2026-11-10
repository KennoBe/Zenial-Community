local Z,U,C=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.SocialCategories
local H
local function tr(s)return Z.T(s)end
-- One private-category toggle: a chip (CheckButton with chip art) so it keeps the checkbox API
-- (SetChecked/GetChecked/Click/SetEnabled, .text); a plain checkbox when the chip skin is not loaded.
function U.NewCategoryChip(parent, id, helpers)
    local tag = id
    local function toggled(self)
        local ok, why = C.Set(U.memberKey, tag, self:GetChecked() == true)
        if not ok then
            U.Message(tr(why))
        end
        U.Refresh()
    end
    if Z.Theme and Z.Theme.Chip then
        return Z.Theme.Chip(parent, C.Label(id), 100, 22, toggled)
    end
    return (helpers or H).checkbox(parent, C.Label(id), 0, 0, 128, toggled)
end
function U.SyncCategoryControls()
    if not U.memberCategoryScroll then return end
    local signature={};for _,id in ipairs(C.ORDER)do signature[#signature+1]=id..':'..C.Label(id)end;signature=table.concat(signature,'\0')
    if U.categoryDefinitionSignature~=signature then
        U.categoryDefinitionSignature=signature
        local options={'ALL','FAVORITES','MY_GUILD'};for _,id in ipairs(C.ORDER)do options[#options+1]=id end
        U.memberFavoriteFilter:SetOptions(options,U.memberFavoriteFilter:GetText())
        for _,check in pairs(U.categoryChecks)do check:Hide();check.text:Hide()end
        for _,id in ipairs(C.ORDER)do local tag=id;local check=U.categoryChecks[id]
            if not check then check=U.NewCategoryChip(U.memberCategoryScroll.child,id);U.categoryChecks[id]=check
            else check:SetParent(U.memberCategoryScroll.child);if not check.zenialChipFill then check.text:SetParent(U.memberCategoryScroll.child)end end
            check.text:SetText(C.Label(id));check:Show();check.text:Show()
        end
    end
    U.memberCategoryFilter:SetShown(false)
end
function U.RefreshCategorySettings()
    if not U.categorySettings then return end
    local items={};local valid=false
    for _,d in ipairs(C.store.definitions)do local id=d.id;valid=valid or id==U.categoryEditID
        items[#items+1]={text=d.name,selected=id==U.categoryEditID,height=34,click=function()
            U.categoryEditID=id;U.categoryName:SetText(C.Label(id));U.categoryDeleteConfirm:Hide();U.RefreshCategorySettings()
        end}
    end
    if not valid then U.categoryEditID=nil end
    H.rows(U.categorySettingsList,items,34)
    U.categoryRename:SetEnabled(not C.readOnly and U.categoryEditID~=nil)
    U.categoryDelete:SetEnabled(not C.readOnly and U.categoryEditID~=nil)
    U.categoryAdd:SetEnabled(not C.readOnly and #C.ORDER<C.MAX_CATEGORIES)
end
function U.CreateCategorySettings(helpers)
    H=helpers;U.memberCategoryFilter:SetShown(false)
    local filter=U.memberFavoriteFilter;filter.caption:SetText(tr('Member filter'))
    filter:SetFormatter(function(id)return id=='ALL'and tr('All')or id=='FAVORITES'and tr('Favorites')or id=='MY_GUILD'and tr('My guild')or C.Label(id)end);filter:SetOptions({'ALL','FAVORITES','MY_GUILD'},'ALL');filter:SetPopupWidth(270)
    filter.button:ClearAllPoints();filter.button:SetPoint('TOPLEFT',530,-17);filter:SetWidth(180)
    filter.caption:ClearAllPoints();filter.caption:SetPoint('TOPLEFT',530,0)
    -- Fit the combined filter in the original single header row.
    local controls={{U.memberSearch,0,120},{U.memberStatus,130,105},{U.memberClass,245,120},{U.memberProfession,375,145},{U.memberSort,720,130}}
    for _,spec in ipairs(controls)do local f,x,w=spec[1],spec[2],spec[3];local widget=f.button or f
        f.caption:ClearAllPoints();f.caption:SetPoint('TOPLEFT',x,0);f.caption:SetWidth(w)
        widget:ClearAllPoints();widget:SetPoint('TOPLEFT',x,-17);if f.button then f:SetWidth(w)else f:SetWidth(w)end
    end
    U.memberCategoryScroll=H.list(U.memberCategoryFrame,0,-4,256,88)
    if Z.Theme then Z.Theme.AttachScrollWheel(U.memberCategoryScroll,32)end
    U.SyncCategoryControls()
    local f=H.panel(U.frame);U.categorySettings=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,450)
    H.label(f,'Private contact categories',16,-18,618,'GameFontNormalLarge')
    U.categorySettingsList=H.list(f,16,-62,594,202)
    U.categoryName=H.edit(f,'Category name',16,-284,618,32)
    U.categoryRename=H.button(f,tr('Rename'),16,-350,196,function()
        local ok,why=C.Rename(U.categoryEditID,U.categoryName:GetText());if not ok then U.Message(tr(why))else U.SyncCategoryControls();U.RefreshCategorySettings();U.Refresh()end
    end)
    U.categoryAdd=H.button(f,tr('Add category'),224,-350,196,function()
        local id,why=C.Add(U.categoryName:GetText());if not id then U.Message(tr(why))else U.categoryEditID=id;U.SyncCategoryControls();U.RefreshCategorySettings();U.Refresh()end
    end,'primary')
    U.categoryDelete=H.button(f,tr('Delete category'),432,-350,202,function()U.categoryDeleteConfirm:Show()end,'danger')
    U.categoryDeleteConfirm=H.button(f,tr('Remove category and its marks'),16,-390,410,function()
        local ok,why=C.Remove(U.categoryEditID);if not ok then U.Message(tr(why))else U.categoryEditID=nil;U.categoryName:SetText('');U.SyncCategoryControls();U.RefreshCategorySettings();U.Refresh()end
        U.categoryDeleteConfirm:Hide()
    end,'danger');U.categoryDeleteConfirm:Hide()
    H.button(f,tr('Close'),438,-400,196,function()f:Hide()end)
    H.makeModal(f);f:Hide()
    H.button(U.settingsDataFrame,tr('Private contact categories'),430,-52,410,function()U.categoryDeleteConfirm:Hide();U.RefreshCategorySettings();f:Show()end)
end
return U
