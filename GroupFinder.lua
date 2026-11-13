local Z,L,A=ZenialCommunity,ZenialCommunity.Logic,ZenialCommunity.Adapter
local G={}
Z.GroupFinder=G
-- Existing finder catalog.
local PVP={"Open World PvP","Warsong Gulch","Arathi Basin","Alterac Valley"}
local DUNGEONS={
    "Hall of Thanes","Ruins of Lordaeron","Excavation Site","City of Dalaran","The Drowned City","Krol'dok","Alcaz Prison","Blackmaw Hold","Shaper's Terrace",
    "Ragefire Chasm","Wailing Caverns","The Deadmines","Shadowfang Keep","Blackfathom Deeps","The Stockade","Gnomeregan","Razorfen Kraul",
    "Scarlet Monastery: Graveyard","Scarlet Monastery: Library","Scarlet Monastery: Armory","Scarlet Monastery: Cathedral","Razorfen Downs",
    "Uldaman","Zul'Farrak","Maraudon","Sunken Temple","Blackrock Depths","Dire Maul East","Dire Maul North","Dire Maul West",
    "Lower Blackrock Spire","Scholomance","Stratholme: Main Gate","Stratholme: Service Gate","Upper Blackrock Spire",
}
local RAIDS={"Deepgrove Tomb","Mount Hyjal Summit","Onyxia's Lair","Molten Core","Blackwing Lair","Zul'Gurub","Ruins of Ahn'Qiraj","Temple of Ahn'Qiraj","Naxxramas"}
G.Activities={PVP=PVP,DUNGEON=DUNGEONS,RAID=RAIDS}
function G.ActivityKind(value)
    value=L.ActivityID(value);for kind,entries in pairs(G.Activities)do for _,activity in ipairs(entries)do if value==activity then return kind end end end;return "CUSTOM"
end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function validTemplate(row)
    return type(row)=="table"and(row.mode=="LFG"or row.mode=="LFM")and L.Text(row.activity,64)and L.Int(row.min,1,100)and L.Int(row.max,row.min,100)
        and L.Int(row.size or 5,2,40)and L.Int(row.tank or 0,0,10)and L.Int(row.healer or 0,0,15)and L.Int(row.dd or 0,0,40)
        and(row.tank or 0)+(row.healer or 0)+(row.dd or 0)<=(row.size or 5)and L.Text(row.note or"",96,true)and L.Int(row.duration or 60,1,1440)
end
function G.Initialize()
    local out={};local n=0;for name,row in pairs(type(Z.db.groupTemplates)=="table"and Z.db.groupTemplates or{})do if n<20 and L.Text(name,64)and validTemplate(row)then out[name]=row;n=n+1 end end;Z.db.groupTemplates=out
end
function G.SaveTemplate(name,group,duration)
    if not L.Text(name,64)or type(group)~="table"then return nil,"Template is invalid."end
    if not Z.db.groupTemplates[name]and count(Z.db.groupTemplates)>=20 then return nil,"A maximum of 20 group templates is allowed."end
    Z.db.groupTemplates[name]={mode=group.mode,activity=group.activity,min=group.min,max=group.max,size=group.size,tank=group.tank,healer=group.healer,dd=group.dd,note=group.note,duration=math.max(1,math.min(1440,tonumber(duration)or 60))};return true
end
function G.DeleteTemplate(name)
    if type(name)~="string"or not Z.db.groupTemplates[name]then return nil,"Choose a template first."end
    Z.db.groupTemplates[name]=nil
    return true
end
function G.FromTemplate(name)
    local row=Z.db.groupTemplates[name];if not row then return nil end;local out={};for k,v in pairs(row)do out[k]=v end;out.id=nil;out.start=A.Now();out.expires=A.Now()+(out.duration or 60)*60;out.templateName=name;out.templateDuration=out.duration;out.duration=nil;return out
end
function G.Matches(group,level,role,available)
    if type(group)~="table"then return false end
    if level and(level<group.min or level>group.max)then return false end
    role=L.Role(role);if role=="TANK"and(group.tank or 0)<1 then return false end;if role=="HEALER"and(group.healer or 0)<1 then return false end;if role=="DAMAGER"and(group.dd or 0)<1 then return false end
    if available and available~="AVAILABLE"then return false end
    return true
end
return G
