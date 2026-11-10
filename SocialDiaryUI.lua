-- Private social diary dialog. Reads the local diary, favorites, notes and the
-- existing contact history; nothing here sends data to other players.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local H
local PAGE=25
local function tr(s,...)return Z.T(s,...)end
local function D()return Z.SocialDiary end
local MODES={D_ALL='All players',D_KNOWN='Known',D_FAVORITES='Favorites',D_NOTES='With note',D_GROUPED='Grouped together'}
local SORTS={D_LAST='Last encounter',D_COUNT='Most encounters',D_NAME='Name'}
local MODE_IDS={D_ALL='ALL',D_KNOWN='KNOWN',D_FAVORITES='FAVORITES',D_NOTES='NOTES',D_GROUPED='GROUPED'}
local SORT_IDS={D_LAST='LAST',D_COUNT='COUNT',D_NAME='NAME'}
local SOURCE_LABELS={target='Target',mouseover='Mouseover',nameplate='Nameplates',group='Group'}
local function when(at)return at and Z.ScheduleTime.Format(at)or tr('Never observed')end
function U.SocialDiaryRows()
    return D().List({query=U.socialDiarySearch:GetText(),mode=MODE_IDS[U.socialDiaryMode:GetText()]or'ALL',sort=SORT_IDS[U.socialDiarySort:GetText()]or'LAST'})
end
local function selectedRow(rows)
    for _,r in ipairs(rows)do if r.key==U.socialDiaryKey then return r end end
end
local function bindNote(key)
    U.socialDiaryNoteBinding=true
    U.socialDiaryNote:SetText(key and Z.Social.GetNote(key)or'')
    U.socialDiaryNoteBinding=false;U.socialDiaryNoteOwner=key
end
function U.RefreshSocialDiary()
    if not U.socialDiary then return end
    local diary=D();local rows=U.SocialDiaryRows();local items={}
    local maxPage=math.max(1,math.ceil(#rows/PAGE));U.socialDiaryPage=math.max(1,math.min(U.socialDiaryPage or 1,maxPage))
    U.socialDiaryEnabled:SetChecked(diary.Enabled())
    for id,check in pairs(U.socialDiarySources)do check:SetChecked(diary.SourceEnabled(id));check:SetEnabled(diary.Enabled())end
    for i=(U.socialDiaryPage-1)*PAGE+1,math.min(U.socialDiaryPage*PAGE,#rows)do local r=rows[i]
        local marks={};if r.known then marks[#marks+1]=tr('Known')end;if r.favorite then marks[#marks+1]=tr('Favorite')end;if r.note~=''then marks[#marks+1]=tr('With note')end
        items[#items+1]={text=r.target..(#marks>0 and(' · '..table.concat(marks,', '))or'')..'\n'..tr('Last encounter')..': '..when(r.last)..'\n'..tr('%d encounters',r.count),
            height=58,selected=r.key==U.socialDiaryKey,click=function()U.SelectSocialDiary(r.key,r.target)end}
    end
    H.rows(U.socialDiaryList,items,58)
    U.socialDiaryCount:SetText(tr('Players')..' ('..#rows..') · '..U.socialDiaryPage..'/'..maxPage..(diary.readOnly and(' · '..tr('The social diary uses a newer format.'))or''))
    U.socialDiaryPrev:SetEnabled(U.socialDiaryPage>1);U.socialDiaryNext:SetEnabled(U.socialDiaryPage<maxPage)
    local key=U.socialDiaryKey;local r=selectedRow(rows)
    local target=r and r.target or U.socialDiaryTarget
    local p=key and diary.Get(key)
    local details={}
    if not key then
        details[1]={text=tr(diary.Enabled()and'Select a player.'or'Automatic recording is off. Known players, favorites and notes are still listed.'),height=48}
    else
        local favorite=Z.Social.IsFavorite(key);local known=diary.IsKnown(key)
        details[#details+1]={text=(target or key)..(p and p.level and(' · '..tr('Level')..' '..p.level)or'')..(p and p.classFile and(' · '..Z.Locale.Class(nil,p.classFile))or''),height=40}
        details[#details+1]={text=tr('First contact')..': '..when(p and p.first)..'\n'..tr('Last encounter')..': '..when(p and p.last)..'\n'..tr('%d encounters',p and p.count or 0),height=58}
        local timeline=diary.Timeline(key)
        if #timeline==0 then details[#details+1]={text=tr('No recorded encounters.'),height=36}end
        for _,e in ipairs(timeline)do details[#details+1]={text=when(e.at)..(e.zone~=''and(' · '..e.zone)or'')..'\n'..e.text,height=40}end
        U.socialDiaryKnown:SetText(tr(known and'Remove known mark'or'Mark as known'))
        U.socialDiaryFavorite:SetText(tr(favorite and'Remove favorite'or'Add favorite'))
    end
    for _,b in ipairs({U.socialDiaryKnown,U.socialDiaryFavorite,U.socialDiaryNoteSave})do b:SetEnabled(key~=nil and not diary.readOnly)end
    U.socialDiaryRemove:SetEnabled(p~=nil and not diary.readOnly)
    if U.socialDiaryNoteOwner~=key then bindNote(key)end
    H.rows(U.socialDiaryDetails,details,40)
end
function U.SelectSocialDiary(key,target)
    U.socialDiaryKey,U.socialDiaryTarget=key,target;bindNote(key);U.RefreshSocialDiary()
end
-- Opens the dialog, optionally focused on one player. The player does not
-- need a diary row: favorites, notes and the known mark work regardless.
function U.OpenSocialDiary(key,target)
    U.Create();if not U.frame:IsShown()then U.frame:Show()end
    if U.Navigation.UnsavedInput()then return U.Navigation.Fail('unsaved-input')end
    U.CloseDialogs()
    if key and(key==Z.me.key or Z.db.blocked[key]or not Z.Logic.ValidIdentityKey(key))then key,target=nil,nil end
    U.socialDiaryPage=1;U.socialDiarySearch:SetText('')
    U.socialDiaryKey,U.socialDiaryTarget=key,key and(target or D().DisplayTarget(key))or nil
    if key then
        local rows=U.SocialDiaryRows();for i,r in ipairs(rows)do if r.key==key then U.socialDiaryPage=math.floor((i-1)/PAGE)+1;break end end
    end
    bindNote(key);U.RefreshSocialDiary();U.socialDiary:Show()
    return true
end
function U.OpenSocialDiaryForUnit(unit)
    local key,target
    if A.Call(UnitIsPlayer,unit)==true then
        local scoped,full,realm=A.UnitIdentity(unit)
        if scoped then key=Z.Logic.ScopeKey(full,realm,A.Call(UnitFactionGroup,unit)or Z.me.faction)or scoped;target=full end
    end
    U.OpenSocialDiary(key,target)
end
function U.CreateSocialDiary(helpers)
    H=helpers;local diary=D()
    local f=H.panel(U.frame);U.socialDiary=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,550)
    H.label(f,'Social diary',16,-18,400,'GameFontNormalLarge')
    H.label(f,'Private and local. Never shared.',330,-22,304)
    U.socialDiaryEnabled=H.checkbox(f,tr('Record encounters automatically'),16,-48,618,function(self)
        local ok,why=diary.SetEnabled(self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshSocialDiary()
    end)
    U.socialDiarySources={}
    for i,id in ipairs(diary.SOURCES)do local source=id
        U.socialDiarySources[id]=H.checkbox(f,tr(SOURCE_LABELS[id]),16+(i-1)*154,-74,150,function(self)
            local ok,why=diary.SetSource(source,self:GetChecked()==true);if not ok then U.Message(tr(why))end;U.RefreshSocialDiary()
        end)
    end
    local function reset()U.socialDiaryPage=1;U.RefreshSocialDiary()end
    U.socialDiarySearch=H.edit(f,'Search',16,-104,200,64);U.socialDiarySearch:SetScript('OnTextChanged',reset)
    U.socialDiaryMode=H.selector(f,'Filter',226,-104,190,{'D_ALL','D_KNOWN','D_FAVORITES','D_NOTES','D_GROUPED'},reset,function(v)return tr(MODES[v]or v)end)
    U.socialDiarySort=H.selector(f,'Sort',426,-104,208,{'D_LAST','D_COUNT','D_NAME'},reset,function(v)return tr(SORTS[v]or v)end)
    U.socialDiaryCount=H.label(f,'',16,-158,618)
    U.socialDiaryList=H.list(f,16,-178,252,322);U.socialDiaryDetails=H.list(f,290,-178,344,196)
    U.socialDiaryNote=H.edit(f,'Private note',290,-382,344,500,true);U.socialDiaryNote:SetHeight(40)
    U.socialDiaryKnown=H.button(f,tr('Mark as known'),290,-446,110,function()
        local key=U.socialDiaryKey;if not key then return end
        local ok,why=diary.SetKnown(key,U.socialDiaryTarget,not diary.IsKnown(key));if not ok then U.Message(tr(why))end;U.RefreshSocialDiary()
    end)
    U.socialDiaryFavorite=H.button(f,tr('Add favorite'),408,-446,110,function()
        local key=U.socialDiaryKey;if not key then return end
        local value,why=Z.Social.ToggleFavorite(key);if value==nil then U.Message(tr(why))end;U.RefreshSocialDiary()
    end)
    U.socialDiaryNoteSave=H.button(f,tr('Save note'),526,-446,108,function()
        local key=U.socialDiaryKey;if not key then return end
        local saved=Z.Social.GetNote(key)
        local draft=U.noteDrafts and U.noteDrafts[key]
        if draft~=nil and draft~=saved and draft~=U.socialDiaryNote:GetText() then U.Message(tr('A private note draft is open in the members page. Save it there first.'));return end
        local ok,why=Z.Social.Note(key,U.socialDiaryNote:GetText())
        if ok and U.noteDrafts and U.noteDrafts[key]==U.socialDiaryNote:GetText() then U.noteDrafts[key]=nil end
        if not ok then U.Message(tr(why))else U.Message(tr('Note saved.'))end
        U.socialDiaryNoteOwner=nil;U.RefreshSocialDiary()
    end)
    U.socialDiaryPrev=H.button(f,tr('Previous'),16,-512,80,function()U.socialDiaryPage=U.socialDiaryPage-1;U.RefreshSocialDiary()end)
    U.socialDiaryNext=H.button(f,tr('Next'),104,-512,80,function()U.socialDiaryPage=U.socialDiaryPage+1;U.RefreshSocialDiary()end)
    U.socialDiaryRemove=H.button(f,tr('Remove from diary'),290,-512,160,function()
        local key=U.socialDiaryKey;if key and diary.Forget(key)then U.Message(tr('Diary entries removed.'))end;U.RefreshSocialDiary()
    end,'danger')
    H.button(f,tr('Close'),460,-512,174,function()f:Hide()end)
    H.makeModal(f);f:Hide()
end
return U
