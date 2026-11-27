-- Private social diary dialog. Reads the local diary, favorites, notes and the
-- existing contact history; nothing here sends data to other players.
local Z,U,A=ZenialCommunity,ZenialCommunity.UI,ZenialCommunity.Adapter
local H
local PAGE=25
local function tr(s,...)return Z.T(s,...)end
local function D()return Z.SocialDiary end
local MODES={D_ALL='All players',D_RATED='Rated',D_LOW='Poorly rated',D_FAVORITES='Favorites',D_NOTES='With note',D_KNOWN='Known'}
local SORTS={D_LAST='Last encounter',D_RATING='Rating',D_COUNT='Most encounters',D_NAME='Name'}
local MODE_IDS={D_ALL='ALL',D_RATED='RATED',D_LOW='LOW',D_FAVORITES='FAVORITES',D_NOTES='NOTES',D_KNOWN='KNOWN'}
local SORT_IDS={D_LAST='LAST',D_RATING='RATING',D_COUNT='COUNT',D_NAME='NAME'}
local STAR_GAP=2
-- Five stars as one text (gold = given, dim = open) for list rows and cards; only "n/5" when the icon
-- atlas is not available. Empty for an unrated player (stars nil).
function U.RatingMarkup(stars,size)
    if not Z.Logic.Int(stars,1,5)then return''end
    local T=Z.Theme;local cell=T and T.iconCells and T.iconCells.star
    if not cell or not(T.assets and T.assets.iconAtlas)then return stars..'/5'end
    size=size or 12;local col,line=cell%8,math.floor(cell/8);local out={}
    for i=1,5 do
        local r,g,b=T.PaletteColor(i<=stars and'gold'or'muted')
        out[i]=string.format('|T%s:%d:%d:0:0:512:256:%d:%d:%d:%d:%d:%d:%d|t',T.assets.iconAtlas,size,size,col*64,(col+1)*64,line*64,(line+1)*64,
            math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
    end
    return table.concat(out)
end
-- The rating of a player behind a character name, for applicant rows, cards and tooltips; nil when unrated.
-- low: 1-2 stars, a warning. markup: the stars as text (inline icons).
function U.PlayerRating(name,size)
    local D=Z.SocialDiary;if not D or not D.RatingInfo or not name then return nil end
    local stars,comment,low=D.RatingInfo(name);if not stars then return nil end
    return{stars=stars,comment=comment,low=low,markup=U.RatingMarkup(stars,size or 11)}
end
-- Behind a name in a list row: the stars and, for 1-2 stars, the red mark. plain: the same as plain text.
function U.RatingRowText(rating,plain)
    if not rating then return''end
    local mark=rating.low and(' '..tr('Poorly rated'))or''
    if plain then return' '..rating.stars..'/5'..mark end
    return' '..rating.markup..(rating.low and' '..Z.Kit.Paint('dangerText',tr('Poorly rated'))or'')
end
-- Display text of an applicant row: the name, the rating, then the rest ("tail": first line remainder and further lines).
function U.RatingDisplay(name,rating,tail)
    local K=Z.Kit;local first,rest=tail:match('^([^\n]*)\n?(.*)$')
    return K.Paint('text',name)..U.RatingRowText(rating)..K.Paint('text',first)..(rest~=''and'\n'..K.Paint('dim',rest)or'')
end
-- Hover text of a rating: the stars (with the warning mark), then the private comment.
function U.RatingTipText(rating)
    if not rating then return''end
    return rating.markup..(rating.low and'  '..tr('Poorly rated')or'')..(rating.comment~=''and'\n'..rating.comment or'')
end
-- Five clickable stars with a small remove symbol behind them. onPick(n) gets 1-5, or nil from the remove symbol.
function U.CreateRatingStars(parent,size,onPick)
    local K,T=Z.Kit,Z.Theme;local w=CreateFrame('Frame',nil,parent);w.buttons={}
    w:SetSize(5*(size+STAR_GAP)+size,size)
    for i=1,5 do
        local b=CreateFrame('Button',nil,w);b:SetSize(size,size);b:SetPoint('TOPLEFT',w,'TOPLEFT',(i-1)*(size+STAR_GAP),0)
        b.star=K.Icon(b,'star',size-2,'muted');b.star:SetPoint('CENTER')
        b:SetScript('OnClick',function()onPick(i)end);w.buttons[i]=b
    end
    w.clear=K.IconButton(w,'close',size,function()onPick(nil)end,tr('Remove rating'))
    w.clear:SetPoint('TOPLEFT',w,'TOPLEFT',5*(size+STAR_GAP),0);w.clear:Hide()
    function w:SetValue(stars,editable)
        w.value=stars
        for i,b in ipairs(w.buttons)do
            b:SetEnabled(editable==true);T.Tint(b.star,'SetVertexColor',stars and i<=stars and'gold'or editable and'dim'or'disabledText')
        end
        w.clear:SetShown(stars~=nil and editable==true)
    end
    return w
end
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
    U.socialDiaryNoteBinding=false;U.socialDiaryNoteOwner=key;U.socialDiaryNoteError=nil
end
-- The private note saves itself while typing, like the note on the contact sheet. A text the note store
-- rejects stays in the field and is reported once; the saved note is untouched.
function U.AutoSaveSocialDiaryNote()
    local key=U.socialDiaryNoteOwner;if not key or D().readOnly then return nil end
    local text=U.socialDiaryNote:GetText();local ok,why=Z.Social.Note(key,text)
    if ok then U.NoteSaved(key,text)
    elseif U.socialDiaryNoteError~=why then U.Message(tr(why))end
    U.socialDiaryNoteError=not ok and why or nil
    U.RefreshSocialDiary()
    return ok,why
end
-- A private note was saved somewhere (diary field or rating card): the contact sheet and the diary field of
-- the same player show the saved text, never an older one.
function U.NoteSaved(key,text)
    if U.noteDrafts then U.noteDrafts[key]=nil end
    if U.memberNoteOwner==key and U.memberPrivateNote then
        U.memberNoteBinding=true;U.memberPrivateNote:SetText(text);U.memberNoteBinding=false
    end
    if U.socialDiaryNoteOwner==key and U.socialDiaryNote and U.socialDiaryNote:GetText()~=text then bindNote(key)end
end
function U.RefreshSocialDiary()
    if not U.socialDiary then return end
    local diary=D();local rows=U.SocialDiaryRows();local items={};local K=Z.Kit
    local maxPage=math.max(1,math.ceil(#rows/PAGE));U.socialDiaryPage=math.max(1,math.min(U.socialDiaryPage or 1,maxPage))
    for i=(U.socialDiaryPage-1)*PAGE+1,math.min(U.socialDiaryPage*PAGE,#rows)do local r=rows[i]
        local marks={};if r.known then marks[#marks+1]=tr('Known')end;if r.favorite then marks[#marks+1]=tr('Favorite')end;if r.note~=''then marks[#marks+1]=tr('With note')end
        -- Visual weighting only (display): bright name, marks in dimmed gold, receding meta lines.
        local markText=#marks>0 and(' · '..table.concat(marks,', '))or'';local lastLabel=tr('Last encounter')..': '
        -- Name in the class colour, the stars right behind it; "n/5" stays in the plain text.
        local hex=Z.Theme.ClassColorHex(r.classFile)
        local name=hex and('|cff'..hex..r.target..'|r')or K.Paint('text',r.target)
        local stars=r.rating and(' '..U.RatingMarkup(r.rating,12))or''
        items[#items+1]={text=r.target..(r.rating and(' '..r.rating..'/5')or'')..markText..'\n'..lastLabel..when(r.last)..'\n'..tr('%d encounters',r.count),
            display=name..stars..(markText~=''and K.Paint('goldDim',markText)or'')..'\n'..K.Fact(lastLabel,when(r.last),'textSoft')..'\n'..K.Paint('dim',tr('%d encounters',r.count)),
            -- Three fixed lines: a long first line is cut off instead of pushing the count out of the row.
            noWrap=true,height=58,selected=r.key==U.socialDiaryKey,click=function()U.SelectSocialDiary(r.key,r.target)end}
    end
    -- An empty, unfiltered list explains where its entries come from (the hint is translated by the list).
    local unfiltered=U.socialDiarySearch:GetText()==''and(MODE_IDS[U.socialDiaryMode:GetText()]or'ALL')=='ALL'
    U.SetEmptyHint(U.socialDiaryList,unfiltered and'Players you were in a group with appear here automatically.'or nil,unfiltered and'members'or nil)
    H.rows(U.socialDiaryList,items,58)
    U.socialDiaryCount:SetText(tr('Players')..' ('..#rows..') · '..U.socialDiaryPage..'/'..maxPage..(diary.readOnly and(' · '..tr('The social diary uses a newer format.'))or''))
    U.socialDiaryPrev:SetEnabled(U.socialDiaryPage>1);U.socialDiaryNext:SetEnabled(U.socialDiaryPage<maxPage)
    local key=U.socialDiaryKey;local r=selectedRow(rows)
    local target=r and r.target or U.socialDiaryTarget
    local p=key and diary.Get(key)
    -- The right column is a block of facts about the selected player, not a list: flat rows without cells.
    -- item.text stays the data contract; display dims labels and brightens values.
    local details={}
    local function fact(text,display,height)details[#details+1]={text=text,display=display,flat=true,textInset=0,height=height}end
    if not key then
        local hint=tr('Select a player.');fact(hint,K.Paint('muted',hint),48)
    else
        local name=target or key
        local meta=(p and p.level and(' · '..tr('Level')..' '..p.level)or'')..(p and p.classFile and(' · '..Z.Locale.Class(nil,p.classFile))or'')
        details[1]={text=name..meta,display=K.Paint('text',name)..(meta~=''and K.Paint('dim',meta)or''),section=true,textInset=0,height=34}
        local first,last,count=tr('First contact')..': ',tr('Last encounter')..': ',tr('%d encounters',p and p.count or 0)
        fact(first..when(p and p.first)..'\n'..last..when(p and p.last)..'\n'..count,
            K.Fact(first,when(p and p.first))..'\n'..K.Fact(last,when(p and p.last))..'\n'..K.Paint('dim',count),58)
        local timeline=diary.Timeline(key)
        if #timeline==0 then local none=tr('No recorded encounters.');fact(none,K.Paint('muted',none),36)end
        for _,e in ipairs(timeline)do
            local head=when(e.at)..(e.zone~=''and(' · '..e.zone)or'')
            fact(head..'\n'..e.text,K.Paint('dim',head)..'\n'..K.Paint('textSoft',e.text),40)
        end
    end
    -- Private marks of the selected player: the rating, the known chip, the favourite star and the self-saving note.
    local editable=key~=nil and not diary.readOnly
    local known,favorite=key~=nil and diary.IsKnown(key),key~=nil and Z.Social.IsFavorite(key)
    U.socialDiaryKnown:SetEnabled(editable);U.socialDiaryKnown:SetChecked(known)
    U.socialDiaryFavorite:SetEnabled(editable);U.socialDiaryFavorite.zenialSelected=favorite
    U.socialDiaryStars:SetValue(key and diary.Rating(key)or nil,editable)
    Z.Theme.Tint(U.socialDiaryFavorite.zenialStar,'SetVertexColor',favorite and'gold'or editable and'dim'or'disabledText')
    U.socialDiaryNote:SetEnabled(editable)
    U.socialDiaryRemove:SetEnabled(p~=nil and not diary.readOnly)
    if U.socialDiaryNoteOwner~=key then bindNote(key)end
    local note=U.socialDiaryNote:GetText()
    U.socialDiaryNoteSaved:SetShown(key~=nil and note~=''and note==Z.Social.GetNote(key))
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
        -- A player the current filter hides would not be found in the list: show everybody then.
        local function find()local rows=U.SocialDiaryRows();for i,r in ipairs(rows)do if r.key==key then return i end end end
        local at=find();if not at and U.socialDiaryMode:GetText()~='D_ALL'then U.socialDiaryMode:SetText('D_ALL');at=find()end
        if at then U.socialDiaryPage=math.floor((at-1)/PAGE)+1 end
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
    H=helpers;local diary=D();local K,T=Z.Kit,Z.Theme
    local f=H.panel(U.frame);U.socialDiary=f;f:ClearAllPoints();f:SetPoint('CENTER',U.frame,'CENTER',90,0);f:SetSize(650,550)
    local title=H.label(f,'Social diary',16,-18,400,'GameFontNormalLarge')
    -- Dialog head: the title in a band with a close symbol; the privacy line sits right-aligned in the band.
    K.DialogHeader(f,title,function()f:Hide()end)
    local privacy=H.label(f,'Private and local. Never shared.',330,-22,304)
    privacy:ClearAllPoints();privacy:SetPoint('TOPRIGHT',f,'TOPRIGHT',-44,-16);privacy:SetWidth(260);privacy:SetJustifyH('RIGHT')
    T.Font(privacy,'caption','dim')
    local function reset()U.socialDiaryPage=1;U.RefreshSocialDiary()end
    U.socialDiarySearch=H.edit(f,'Search',16,-56,200,64);U.socialDiarySearch:SetScript('OnTextChanged',reset)
    U.socialDiaryMode=H.selector(f,'Filter',226,-56,190,{'D_ALL','D_RATED','D_LOW','D_FAVORITES','D_NOTES','D_KNOWN'},reset,function(v)return tr(MODES[v]or v)end)
    U.socialDiarySort=H.selector(f,'Sort',426,-56,208,{'D_LAST','D_RATING','D_COUNT','D_NAME'},reset,function(v)return tr(SORTS[v]or v)end)
    U.socialDiaryCount=H.label(f,'',16,-110,618);T.Font(U.socialDiaryCount,'caption','dim')
    -- Left: the players (a list). Right: the selected player's facts (a block), then your private marks.
    U.socialDiaryList=H.list(f,16,-130,252,370);U.socialDiaryDetails=K.InfoBlock(H.list(f,290,-130,344,172))
    U.socialDiaryNote=H.edit(f,'Private comment',290,-346,344,500,true);U.socialDiaryNote:SetHeight(56)
    -- The multi-line box has no visible field of its own in the client: draw one.
    T.FieldBackground(U.socialDiaryNote)
    U.socialDiaryNote:SetScript('OnTextChanged',function()
        if U.socialDiaryNoteOwner and not U.socialDiaryNoteBinding then U.AutoSaveSocialDiaryNote()end
    end)
    -- Quiet "saved" tick right behind the caption of the note.
    local caption=U.socialDiaryNote.caption;local captionWidth=A.Call(caption.GetStringWidth,caption)
    captionWidth=type(captionWidth)=='number'and captionWidth>0 and captionWidth or #tr('Private comment')*6
    U.socialDiaryNoteSaved=K.Icon(f,'check',12,'success');U.socialDiaryNoteSaved:SetPoint('TOPLEFT',f,'TOPLEFT',290+math.min(200,math.ceil(captionWidth))+6,-347);U.socialDiaryNoteSaved:Hide()
    local function tooltip(control,text)
        if not(GameTooltip and control.HookScript)then return end
        control:HookScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetText(tr(text(self)));GameTooltip:Show()end)
        control:HookScript('OnLeave',function()GameTooltip:Hide()end)
    end
    -- Rating: caption and five stars at the left of the marks row.
    local ratingCaption=H.label(f,'Rating',290,-316,54);T.Font(ratingCaption,'caption','dim')
    U.socialDiaryStars=U.CreateRatingStars(f,22,function(stars)
        local key=U.socialDiaryKey;if not key then return end
        local ok,why=diary.SetRating(key,U.socialDiaryTarget,stars);if not ok then U.Message(tr(why))end;U.RefreshSocialDiary()
    end)
    U.socialDiaryStars:SetPoint('TOPLEFT',f,'TOPLEFT',346,-312)
    -- Known: a two-state chip. Favourite: an icon-only star (same as on the contact sheet).
    U.socialDiaryKnown=T.Chip(f,tr('Known'),90,22,function()
        local key=U.socialDiaryKey;if not key then return end
        local ok,why=diary.SetKnown(key,U.socialDiaryTarget,not diary.IsKnown(key));if not ok then U.Message(tr(why))end;U.RefreshSocialDiary()
    end)
    U.socialDiaryKnown:SetPoint('TOPLEFT',f,'TOPLEFT',512,-310)
    tooltip(U.socialDiaryKnown,function()return U.socialDiaryKey and diary.IsKnown(U.socialDiaryKey)and'Remove known mark'or'Mark as known'end)
    U.socialDiaryFavorite=H.button(f,'',608,-308,26,function()
        local key=U.socialDiaryKey;if not key then return end
        local value,why=Z.Social.ToggleFavorite(key);if value==nil then U.Message(tr(why))end;U.RefreshSocialDiary()
    end,'ghost')
    U.socialDiaryFavorite:SetHeight(26)
    U.socialDiaryFavorite.zenialStar=K.Icon(U.socialDiaryFavorite,'star',16,'muted');U.socialDiaryFavorite.zenialStar:SetPoint('CENTER')
    tooltip(U.socialDiaryFavorite,function(self)return self.zenialSelected and'Remove favorite'or'Favorite'end)
    -- Removing the diary row sits with the player's details, away from Close.
    U.socialDiaryRemove=H.button(f,tr('Remove from diary'),444,-446,190,function()
        local key=U.socialDiaryKey;if key and diary.Forget(key)then U.Message(tr('Diary entries removed.'))end;U.RefreshSocialDiary()
    end,'danger')
    U.socialDiaryPrev=H.button(f,tr('Previous'),16,-512,80,function()U.socialDiaryPage=U.socialDiaryPage-1;U.RefreshSocialDiary()end)
    U.socialDiaryNext=H.button(f,tr('Next'),104,-512,80,function()U.socialDiaryPage=U.socialDiaryPage+1;U.RefreshSocialDiary()end)
    H.button(f,tr('Close'),460,-512,174,function()f:Hide()end)
    H.makeModal(f);f:Hide()
end
return U
