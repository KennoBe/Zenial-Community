local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local S={open=false,generation=0,state="closed",due=nil,retries=0,lastMessage=""}
Z.ProfessionScan=S

local function sameRecipes(a,b,profession)
    local left,right={},{}
    for _,r in ipairs(a or{})do if L.ProfessionName(r.profession)==profession then left[r.id]=(r.itemID or 0).."\0"..(r.name or"").."\0"..(r.itemName or"").."\0"..(r.materials or"")end end
    for _,r in ipairs(b or{})do if L.ProfessionName(r.profession)==profession then right[r.id]=(r.itemID or 0).."\0"..(r.name or"").."\0"..(r.itemName or"").."\0"..(r.materials or"")end end
    for id,value in pairs(left)do if right[id]~=value then return false end end
    for id,value in pairs(right)do if left[id]~=value then return false end end
    return true
end
function S.Initialize()
    Z.db.recipeStates=type(Z.db.recipeStates)=="table"and Z.db.recipeStates or{}
    S.open=false;S.generation=0;S.state="closed";S.due=nil;S.retries=0;S.lastMessage=""
    S.professionDue=A.Clock()+.5;S.professionRetries=0;S.emptyProfessions=false;S.emptyRecipes=nil;S.professionsKnown=false
end
function S.ApplyProfessions(professions)
    if type(professions)~="table"then return false end
    local names,ids={},{};for _,p in ipairs(professions)do
        if not L.ValidProfession(p)or ids[p.id]then return false end
        ids[p.id]=true;p.name=L.ProfessionNameByID(p.id)or L.ProfessionName(p.name);names[p.name]=true
    end
    local function signature(rows)
        local values={};for _,p in ipairs(rows or{})do values[#values+1]=table.concat({p.id,p.name,p.rank,p.max},":")end;table.sort(values);return table.concat(values,";")
    end
    local changed=signature(Z.db.professions)~=signature(professions)
    local recipes={};for _,r in ipairs(Z.db.recipes or{})do if names[L.ProfessionName(r.profession)]then recipes[#recipes+1]=r else changed=true end end
    for _,states in ipairs({Z.db.recipeStates,Z.db.recipeScans})do for name in pairs(states)do if not names[L.ProfessionName(name)]then states[name]=nil;changed=true end end end
    Z.db.professions=professions;Z.db.recipes=recipes;S.professionsKnown=true
    local covered=0;for name in pairs(names)do if Z.db.recipeStates[name]and Z.db.recipeStates[name].complete then covered=covered+1 end end
    Z.db.recipeComplete=#professions>0 and covered==#professions
    if changed then
        if Z.RecipeSearch then Z.RecipeSearch.RefreshOwn()end
        Z.db.recipeRev=math.min(Z.db.recipeRev+1,2147483646);L.Touch(Z.db)
        if Z.Network3 then Z.Network3.nextPresence=0 end
        Z.Publish();Z.MarkDirty("profession")
    end
    return true,changed
end
function S.RefreshProfessions(confirmEmpty)
    local professions,message=A.ScanProfessions()
    if not professions then S.emptyProfessions=false;return nil,message end
    if #professions==0 and #(Z.db.professions or{})>0 and not confirmEmpty then
        S.emptyProfessions=S.emptyProfessions or A.Clock()
        if A.Clock()<S.emptyProfessions+1.5 then S.professionDue=S.emptyProfessions+1.5;return nil,"Profession data is not ready yet."end
    end
    S.emptyProfessions=false;S.professionRetries=0
    local ok,changed=S.ApplyProfessions(professions);return ok,message,changed
end
function S.Schedule(delay)
    if not S.open then return false end
    S.generation=S.generation+1;S.state="waiting";S.due=A.Clock()+(delay or.6);S.retries=0;return true
end
function S.OnEvent(event)
    S.professionDue=A.Clock()+.5;S.professionRetries=0
    S.emptyRecipes=nil
    if event=="TRADE_SKILL_SHOW"then S.open=true;S.Schedule(.5)
    elseif event=="TRADE_SKILL_CLOSE"then S.open=false;S.generation=S.generation+1;S.state="closed";S.due=nil
    elseif S.open then S.Schedule(event=="TRADE_SKILL_DATA_SOURCE_CHANGING"and 1 or .6)end
end
function S.Commit(recipes,profession,complete,message)
    profession=L.ProfessionName(profession);if not L.Text(profession,64)or type(recipes)~="table"then return nil,"Ungültige Scandaten."end
    if S.professionsKnown then
        local learned=false;for _,p in ipairs(Z.db.professions)do if L.ProfessionName(p.name)==profession then learned=true end end
        if not learned then return nil,"This profession is no longer learned."end
    end
    local merged=L.MergeRecipes(Z.db.recipes,recipes,profession,not complete,complete==true);if not merged then return nil,"Keine gültigen Rezepte erkannt."end
    local changed=not sameRecipes(Z.db.recipes,merged,profession);local now=A.Now();local state=Z.db.recipeStates[profession]or{};local previousComplete=state.complete;local previousCount=state.count
    state.complete=complete==true;state.at=now;state.count=#recipes;state.message=message or""
    if complete then state.fullAt=now end
    Z.db.recipeStates[profession]=state;Z.db.recipeScans[profession]=now;Z.db.recipeScan=now
    if changed then Z.db.recipes=merged;if Z.RecipeSearch then Z.RecipeSearch.RefreshOwn()end;Z.db.recipeRev=math.min((Z.db.recipeRev or 1)+1,2147483646);L.Touch(Z.db);if Z.Items then Z.Items.SeedRecipes(merged)end;if Z.Network3 then Z.Network3.nextPresence=0 end;Z.Publish()end
    local covered,total=0,#(Z.db.professions or{})
    for _,p in ipairs(Z.db.professions or{})do local row=Z.db.recipeStates[L.ProfessionName(p.name)];if row and row.complete then covered=covered+1 end end
    Z.db.recipeComplete=total>0 and covered>=total
    if Z.History and Z.History.store and now>0 then
        local id='recipes:'..profession:sub(1,24);local rows=Z.History.byContent['craft:'..Z.me.key..':'..id]or{};local last=rows[#rows]
        if changed or previousComplete~=state.complete or previousCount~=state.count or not last or now-last.at>=60 then
            local content=profession..': '..#recipes..' '..Z.T('recipes')..' · '..Z.T(complete and'Complete'or'Partial')
            Z.History.Record('craft',complete and'recipe_scanned'or'recipe_partial',id,content:sub(1,96))
        end
    end
    S.state=complete and"complete"or"partial";S.lastMessage=Z.T(complete and"Complete: %s"or"Partial scan: %s",message or"")
    if Z.MarkDirty then Z.MarkDirty("profession")end
    return true,S.lastMessage,changed
end
function S.Run(generation)
    if not S.open or generation~=S.generation then return false end
    S.RefreshProfessions()
    local recipes,message,profession,complete=A.ScanRecipes()
    if not recipes then
        S.retries=S.retries+1
        if S.retries<=3 and S.open then S.state="waiting";S.due=A.Clock()+1.5 else S.state="partial";S.due=nil;S.lastMessage=message or"Berufsdaten noch unvollständig.";if Z.MarkDirty then Z.MarkDirty("profession")end end
        return false
    end
    if complete and #recipes==0 and S.emptyRecipes~=profession then S.emptyRecipes=profession;S.due=A.Clock()+1.5;S.state="waiting";return false end
    S.emptyRecipes=nil;S.due=nil;local ok,status,changed=S.Commit(recipes,profession,complete,message)
    if not ok then S.state="partial";S.lastMessage=status;if Z.MarkDirty then Z.MarkDirty("profession")end end
    return ok,status,changed
end
function S.Tick()
    if S.professionDue and A.Clock()>=S.professionDue then
        S.professionDue=nil;local ok=S.RefreshProfessions()
        if not ok and not S.professionDue then S.emptyProfessions=false;S.professionRetries=S.professionRetries+1;if S.professionRetries<=3 then S.professionDue=A.Clock()+1.5 end end
    end
    if S.due and A.Clock()>=S.due then local generation=S.generation;S.due=nil;S.state="scanning";S.Run(generation)end
end
function S.Request()
    if not S.open then S.state="closed";S.lastMessage="Öffne zuerst dein eigenes WoW-Berufsfenster.";return nil,S.lastMessage end
    S.Schedule(0);S.Tick();return S.state=="complete"or S.state=="partial",S.lastMessage
end
function S.Status()
    return{state=S.state,message=S.lastMessage,open=S.open,states=Z.db and Z.db.recipeStates or{}}
end
return S
