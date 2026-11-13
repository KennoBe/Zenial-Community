local Z,U=ZenialCommunity,ZenialCommunity.UI
local H
function U.RefreshProfessionHistory()
    if not U.professionHistory then return end
    local items={}
    for _,p in ipairs(Z.db.professions or{})do
        local name=Z.Logic.ProfessionName(p.name);local s=Z.db.recipeStates[name];local at=s and s.at or Z.db.recipeScans[name]
        local when=at and at>0 and date('%d.%m.%Y %H:%M',at)or Z.T('Not scanned yet')
        items[#items+1]={text=Z.T(name)..' · '..when..'\n'..(s and Z.T('%d recipes · %s',s.count,Z.T(s.complete and'Complete'or'Partial'))or Z.T('Not scanned yet')),height=42,click=function()if U.OpenHistory()then U.historyKind:SetText('CRAFT');U.historySearch:SetText(name);U.RefreshHistory()end end}
    end
    if Z.Kit then for _,item in ipairs(items)do item.display=Z.Kit.Lines(item.text)end end
    H.rows(U.professionHistory,items,42)
end
function U.CreateProfessionHistory(helpers)
    H=helpers;U.craftScanFeedback:SetHeight(42);H.label(U.craftMineFrame,'Recipe updates by profession',12,-336,792,'GameFontNormal')
    U.professionHistory=H.list(U.craftMineFrame,12,-366,792,64);U.RefreshProfessionHistory()
end
return U
