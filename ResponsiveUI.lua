-- Width determines font/control scale; available height determines list length.
-- Keep headers fixed and move existing footer actions as a single group.
local Z,U=ZenialCommunity,ZenialCommunity.UI
local records,containers,listSet,pageSet,groups
local function overlap(a,b)return a.x<b.x+b.w and b.x<a.x+a.w end
local function height(f)
    if pageSet[f]then return f:GetHeight()end
    if f.GetNumPoints and f:GetNumPoints()==2 then
        local p,relative,_,_,y=f:GetPoint(1);local q,other,_,_,bottom=f:GetPoint(2)
        if relative and p=='TOPLEFT'and q=='BOTTOMRIGHT'and relative==other and relative~=f then return math.max(1,height(relative)+y-bottom)end
    end
    return f:GetHeight()
end
local function width(f)
    if f.GetNumPoints and f:GetNumPoints()==2 then
        local p,relative,_,x=f:GetPoint(1);local q,other,_,right=f:GetPoint(2)
        if relative and p=='TOPLEFT'and(q=='BOTTOMRIGHT'or q=='TOPRIGHT')and relative==other and relative~=f then return math.max(1,width(relative)+right-x)end
    end
    return f:GetWidth()
end
local function route(f)
    local current=f;local depth=0
    while current and depth<24 do
        if current.zenialOwnLayout or listSet[current]or current==U.memberProfileScroll or current==U.memberCategoryFrame then return nil end
        if current.GetFrameStrata and current:GetFrameStrata()=='TOOLTIP'then return nil end
        if pageSet[current]then return current end
        current=current.GetParent and current:GetParent();depth=depth+1
    end
end
function U.CreateResponsiveLayout()
    records,containers,listSet,pageSet={},{},{},{}
    for _,page in ipairs(U.pages)do pageSet[page]=true end
    for _,item in ipairs(U.layoutWidgets or{})do if item.kind=='list'then listSet[item.frame]=true end end
    for _,item in ipairs(U.layoutWidgets or{})do
        local f=item.frame;local parent=f:GetParent();local page=route(parent)
        if page then
            local anchor,relative,rpoint,x,y=f:GetPoint(1)
            if anchor=='TOPLEFT'and rpoint=='TOPLEFT'and type(x)=='number'and type(y)=='number'and y<=0 then
                records[#records+1]={f=f,parent=parent,page=page,kind=item.kind,x=x,y=-y,w=item.kind=='list'and f.width+24 or f:GetWidth(),baseWidth=width(parent),h=item.kind=='label'and math.min(64,f:GetHeight())or f:GetHeight()}
                local node=parent
                while node and node~=page do
                    local p,ref,_,_,top=node:GetPoint(1)
                    if node.GetNumPoints and node:GetNumPoints()==1 and p=='TOPLEFT'and node:GetParent()==page and node:GetHeight()>=360 then containers[node]={page=page,top=-top}end
                    node=node:GetParent()
                end
            end
        end
    end
    -- Widget relationships never change after construction. Resolve footer and
    -- list overlaps once instead of allocating/scanning all pages on each pixel.
    groups={}
    for _,r in ipairs(records)do
        local g=groups[r.parent];if not g then g={items={},lists={},page=r.page};groups[r.parent]=g end
        g.items[#g.items+1]=r;if r.kind=='list'then g.lists[#g.lists+1]=r end
    end
    for _,g in pairs(groups)do
        g.footerEnd=0
        for _,r in ipairs(g.items)do
            for _,l in ipairs(g.lists)do if overlap(r,l)and(not r.lastList or l.y+l.h>r.lastList.y+r.lastList.h)then r.lastList=l end end
            local l=r.lastList
            r.footer=r.kind~='list'and(not l and r.y>=330 or l and r.y>=l.y+l.h or r.y>=330 and(r.kind=='button'or r.kind=='check'))
            if r.footer and(r.kind=='button'or r.kind=='check')then g.footerEnd=math.max(g.footerEnd,r.y+r.h)end
        end
    end
    U.responsiveLists=listSet
end
function U.ApplyResponsiveLayout(activePage)
    if not records or U.responsiveUpdating then return end;U.responsiveUpdating=true
    for f,spec in pairs(containers)do if not activePage or spec.page==activePage then f:SetHeight(math.max(360,spec.page:GetHeight()-spec.top-12));f:SetWidth(spec.page:GetWidth())end end
    for parent,g in pairs(groups)do if not activePage or g.page==activePage then
        local h=height(parent);local footerEnd=g.footerEnd
        local shift=footerEnd>0 and h-12-footerEnd or 0
        for _,r in ipairs(g.items)do
            local previousWidth,previousHeight=r.f:GetWidth(),r.f:GetHeight()
            local horizontal=width(parent)/r.baseWidth
            local compactPage=({members=1,craft=2,groups=3,quests=4,trade=5})[U.compactArea or''];local compact=compactPage and r.page==U.pages[compactPage]
            if not compact then
                local selector=U.layoutSelectors and U.layoutSelectors[r.f]
                if selector then selector:SetWidth(r.w*horizontal)elseif r.kind~='check'then r.f:SetWidth(r.w*horizontal)end
                r.f:ClearAllPoints();r.f:SetPoint('TOPLEFT',r.x*horizontal,-r.y)
                if r.kind=='list'then r.f.width=r.f:GetWidth()-24;r.f.child:SetWidth(r.f.width)end
            end
            if compact then -- The explicit compact detail layout owns these controls.
            elseif r.kind=='list'then
                local lowest=r.lastList
                if lowest==r then
                    local bottom=h-12
                    for _,other in ipairs(g.items)do if other.footer and overlap(r,other)then bottom=math.min(bottom,other.y+shift-6)end end
                    local newHeight=math.max(r.h,math.floor(bottom-r.y))
                    r.f:SetHeight(newHeight);r.f.height=newHeight
                end
            elseif r.footer and footerEnd>0 then
                r.f:ClearAllPoints();r.f:SetPoint('TOPLEFT',r.x*horizontal,-(r.y+shift))
            end
            if not compact and r.kind=='list'and r.f.zenialRender and(previousWidth~=r.f:GetWidth()or previousHeight~=r.f:GetHeight())then r.f.zenialRender()end
        end
    end end
    if U.compactArea=='craft'and(not activePage or activePage==U.pages[2])then
        if U.LayoutCraftOrderForm then U.LayoutCraftOrderForm()end
        local parent=U.craftSearchFrame;local h=parent:GetHeight()
        local recipeHeight=math.max(70,math.min(100,h-290));U.professionRecipeList:SetHeight(recipeHeight);U.professionRecipeList.height=recipeHeight
        local titleY=145+recipeHeight;U.craftDetailMaterialsTitle:ClearAllPoints();U.craftDetailMaterialsTitle:SetPoint('TOPLEFT',495,-titleY)
        U.craftDetailMaterials:ClearAllPoints();U.craftDetailMaterials:SetPoint('TOPLEFT',495,-(titleY+22));U.craftDetailMaterials:SetHeight(65);U.craftDetailMaterials.height=65
        U.craftDetailMaterialState:ClearAllPoints();U.craftDetailMaterialState:SetPoint('TOPLEFT',0,-(titleY+91))
        U.craftDetailCrafts:ClearAllPoints();U.craftDetailCrafts:SetPoint('TOPLEFT',0,-(h-48))
        U.craftDetailSaveList:ClearAllPoints();U.craftDetailSaveList:SetPoint('TOPLEFT',100,-(h-48))
        U.craftDetailOffers:ClearAllPoints();U.craftDetailOffers:SetPoint('TOPLEFT',236,-(h-48))
        for _,f in ipairs({U.craftFavorite,U.professionWhisper,U.craftOrderRequest})do local _,_,_,x=f:GetPoint(1);f:ClearAllPoints();f:SetPoint('TOPLEFT',x,-(h-12))end
    end
    if U.RefreshMemberCategories and(not activePage or activePage==U.pages[1])then U.RefreshMemberCategories()end
    if U.RefreshMembersPageLayout and(not activePage or activePage==U.pages[1])then
        -- Responsive layout restores the list's base anchor and height; reapply
        -- the advanced-filter offset without restoring hidden compact controls.
        U.memberLayoutOffset = 0
        U.RefreshMembersPageLayout()
    end
    if U.LayoutHomeWishes and(not activePage or activePage==U.pages[9])then U.LayoutHomeWishes()end
    if U.LayoutPvPHelp and(not activePage or activePage==U.pages[3])then U.LayoutPvPHelp()end
    if U.LayoutProfileCharacters and(not activePage or activePage==U.pages[6])then U.LayoutProfileCharacters()end
    U.responsiveUpdating=false
end
return U
