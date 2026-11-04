-- Only preferences are shared. Profiles, quests, professions and transaction
-- history remain character data; old per-character values are preserved.
local Z,L=ZenialCommunity,ZenialCommunity.Logic
local S={};Z.AccountPreferences=S
local function account()
    if type(ZenialCommunityDB)~='table'or Z.offlineOnly then return end
    local root=ZenialCommunityDB;root.account=type(root.account)=='table'and root.account or{}
    root.account.preferences=type(root.account.preferences)=='table'and root.account.preferences or{}
    return root.account.preferences
end
local function transfer(dst,src)
    for _,name in ipairs({'visible','shareProfessions','minimapHidden'})do if type(src[name])=='boolean'then dst[name]=src[name]end end
    if type(src.scale)=='number'and src.scale>=.65 and src.scale<=1.4 then dst.scale=src.scale end
    if type(src.minimapAngle)=='number'and src.minimapAngle>=-360 and src.minimapAngle<=360 then dst.minimapAngle=src.minimapAngle end
    if src.position==false then dst.position=nil
    elseif type(src.position)=='table'and L.Int(src.position.x,-10000,10000)and L.Int(src.position.y,-10000,10000)then dst.position={x=src.position.x,y=src.position.y}end
end
function S.Apply(db)
    local p=account();if not p then return end
    if not p.initialized then transfer(p,db);p.initialized=true end
    transfer(db,p)
end
function S.Save()
    local p=account();if not p or not Z.db then return end
    transfer(p,Z.db);if not Z.db.position then p.position=false end
    if Z.uiCharacter then p.mapMembers=Z.uiCharacter.mapMembers~=false;p.mapGuildOnly=Z.uiCharacter.mapGuildOnly==true;p.memberStatus=Z.uiCharacter.memberStatus end
    if Z.PvPHelp and Z.PvPHelp.store then p.pvpReceive=Z.PvPHelp.store.receive==true;p.pvpScope=Z.PvPHelp.store.scope end
end
function S.ApplyViews()
    local p=account();if not p then return end
    if Z.uiCharacter then if type(p.mapMembers)=='boolean'then Z.uiCharacter.mapMembers=p.mapMembers end;if type(p.mapGuildOnly)=='boolean'then Z.uiCharacter.mapGuildOnly=p.mapGuildOnly end;if p.memberStatus=='ALL'or p.memberStatus=='ONLINE'then Z.uiCharacter.memberStatus=p.memberStatus end end
    if Z.PvPHelp and Z.PvPHelp.store then if type(p.pvpReceive)=='boolean'then Z.PvPHelp.store.receive=p.pvpReceive end;if p.pvpScope=='all'or p.pvpScope=='zone'then Z.PvPHelp.store.scope=p.pvpScope end end
end
local frame=CreateFrame('Frame');frame:RegisterEvent('PLAYER_LOGOUT');frame:SetScript('OnEvent',S.Save)
