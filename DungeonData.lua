-- Native Blizzard file references and entrance facts derived from OpenMap.
-- See NOTICE.txt. Textures are read from the user's installation.
local Z,A=ZenialCommunity,ZenialCommunity.Adapter
local D={};Z.DungeonData=D
local floors={
	[33] = { -- Shadowfang Keep
		{ tiles = { 448226, 448230, 448231, 448232, 448233, 448234, 448235, 448236, 448237, 448227, 448228, 448229 }, name = "The Courtyard" },
		{ tiles = { 448238, 448242, 448243, 448244, 448245, 448246, 448247, 448248, 448249, 448239, 448240, 448241 }, name = "Dining Hall" },
		{ tiles = { 448250, 448254, 448255, 448256, 448257, 448258, 448259, 448260, 448261, 448251, 448252, 448253 }, name = "The Vacant Den" },
		{ tiles = { 448262, 448266, 448267, 448268, 448269, 448270, 448271, 448272, 448273, 448263, 448264, 448265 }, name = "Lower Observatory" },
		{ tiles = { 448274, 448278, 448279, 448280, 448281, 448282, 448283, 448284, 448285, 448275, 448276, 448277 }, name = "Upper Observatory" },
		{ tiles = { 448286, 448290, 448291, 448292, 448293, 448294, 448295, 448296, 448297, 448287, 448288, 448289 }, name = "Lord Godfrey's Chamber" },
		{ tiles = { 448298, 448302, 448303, 448304, 448305, 448306, 448307, 448308, 448309, 448299, 448300, 448301 }, name = "The Wall Walk" },
	},
	[34] = { -- Stormwind Stockade
		{ tiles = { 455959, 455963, 455964, 455965, 455966, 455967, 455968, 455969, 455970, 455960, 455961, 455962 } },
	},
	[36] = { -- Deadmines
		{ tiles = { 449591, 449595, 449596, 449597, 449598, 449599, 449600, 449601, 449602, 449592, 449593, 449594 }, name = "The Deadmines" },
		{ tiles = { 449603, 449607, 449608, 449609, 449610, 449611, 449612, 449613, 449614, 449604, 449605, 449606 }, name = "Ironclad Cove" },
	},
	[43] = { -- Wailing Caverns
		{ tiles = { 448454, 448458, 448459, 448460, 448461, 448462, 448463, 448464, 448465, 448455, 448456, 448457 } },
	},
	[47] = { -- Razorfen Kraul
		{ tiles = { 448106, 448110, 448111, 448112, 448113, 448114, 448115, 448116, 448117, 448107, 448108, 448109 } },
	},
	[48] = { -- Blackfathom Deeps
		{ tiles = { 447578, 447582, 447583, 447584, 447585, 447586, 447587, 447588, 447589, 447579, 447580, 447581 }, name = "The Pool of Ask'Ar" },
		{ tiles = { 447590, 447594, 447595, 447596, 447597, 447598, 447599, 447600, 447601, 447591, 447592, 447593 }, name = "Moonshrine Sanctum" },
		{ tiles = { 447602, 447606, 447607, 447608, 447609, 447610, 447611, 447612, 447613, 447603, 447604, 447605 }, name = "The Forgotten Pool" },
	},
	[70] = { -- Uldaman
		{ tiles = { 448430, 448434, 448435, 448436, 448437, 448438, 448439, 448440, 448441, 448431, 448432, 448433 }, name = "Hall of the Keepers" },
		{ tiles = { 448442, 448446, 448447, 448448, 448449, 448450, 448451, 448452, 448453, 448443, 448444, 448445 }, name = "Khaz'Goroth's Seat" },
	},
	[90] = { -- Gnomeregan
		{ tiles = { 449580, 449584, 449585, 449586, 449587, 449588, 449589, 449590, 449627, 449581, 449582, 449583 }, name = "The Hall of Gears" },
		{ tiles = { 449628, 449632, 449633, 449634, 449635, 449636, 449637, 449638, 449639, 449629, 449630, 449631 }, name = "The Dormitory" },
		{ tiles = { 449640, 449644, 449645, 449646, 449647, 449648, 449649, 449650, 449651, 449641, 449642, 449643 }, name = "Launch Bay" },
		{ tiles = { 449652, 449656, 449657, 449658, 449659, 449660, 449661, 449662, 449663, 449653, 449654, 449655 }, name = "Tinkers' Court" },
	},
	[109] = { -- Sunken Temple
		{ tiles = { 452514, 452518, 452519, 452520, 452521, 452522, 452523, 452524, 452525, 452515, 452516, 452517 } },
	},
	[129] = { -- Razorfen Downs
		{ tiles = { 448094, 448098, 448099, 448100, 448101, 448102, 448103, 448104, 448105, 448095, 448096, 448097 } },
	},
	[189] = { -- Scarlet Monastery
		{ tiles = { 449760, 449764, 449765, 449766, 449767, 449768, 449769, 449770, 449771, 449761, 449762, 449763 }, name = "Graveyard" },
		{ tiles = { 449772, 449776, 449777, 449778, 449779, 449780, 449781, 449782, 449783, 449773, 449774, 449775 }, name = "Library" },
		{ tiles = { 449784, 449788, 449789, 449790, 449791, 449792, 449793, 449794, 449795, 449785, 449786, 449787 }, name = "Armory" },
		{ tiles = { 449796, 449800, 449801, 449802, 449803, 449804, 449805, 449806, 449807, 449797, 449798, 449799 }, name = "Cathedral" },
	},
	[209] = { -- Zul'Farrak
		{ tiles = { 449820, 449824, 449825, 449826, 449827, 449828, 449829, 449830, 449831, 449821, 449822, 449823 } },
	},
	[229] = { -- Blackrock Spire
		{ tiles = { 447662, 447666, 447667, 447668, 447669, 447670, 447671, 447672, 447673, 447663, 447664, 447665 }, name = "Tazz'Alor", wing = "Lower Blackrock Spire" },
		{ tiles = { 447674, 447678, 447679, 447680, 447681, 447682, 447683, 447684, 447685, 447675, 447676, 447677 }, name = "Skitterweb Tunnels", wing = "Lower Blackrock Spire" },
		{ tiles = { 447686, 447690, 447691, 447692, 447693, 447694, 447695, 447696, 447697, 447687, 447688, 447689 }, name = "Hordemar City", wing = "Lower Blackrock Spire" },
		{ tiles = { 447698, 447702, 447703, 447704, 447705, 447706, 447707, 447708, 447709, 447699, 447700, 447701 }, name = "Hall of Blackhand", wing = "Lower Blackrock Spire" },
		{ tiles = { 447710, 447714, 447715, 447716, 447717, 447718, 447719, 447720, 447721, 447711, 447712, 447713 }, name = "Halycon's Lair", wing = "Lower Blackrock Spire" },
		{ tiles = { 447722, 447726, 447727, 447728, 447729, 447730, 447731, 447732, 447733, 447723, 447724, 447725 }, name = "Chamber of Battle", wing = "Lower Blackrock Spire" },
		{ tiles = { 447734, 447738, 447739, 447740, 447741, 447742, 447743, 447744, 447745, 447735, 447736, 447737 }, wing = "Upper Blackrock Spire" },
	},
	[230] = { -- Blackrock Depths
		{ tiles = { 447638, 447642, 447643, 447644, 447645, 447646, 447647, 447648, 447649, 447639, 447640, 447641 }, name = "Detention Block" },
		{ tiles = { 447650, 447654, 447655, 447656, 447657, 447658, 447659, 447660, 447661, 447651, 447652, 447653 }, name = "Shadowforge City" },
	},
	[249] = { -- Onyxia's Lair
		{ tiles = { 448070, 448074, 448075, 448076, 448077, 448078, 448079, 448080, 448081, 448071, 448072, 448073 } },
	},
	[289] = { -- Scholomance
		{ tiles = { 448178, 448182, 448183, 448184, 448185, 448186, 448187, 448188, 448189, 448179, 448180, 448181 }, name = "The Reliquary" },
		{ tiles = { 448190, 448194, 448195, 448196, 448197, 448198, 448199, 448200, 448201, 448191, 448192, 448193 }, name = "Chamber of Summoning" },
		{ tiles = { 448202, 448206, 448207, 448208, 448209, 448210, 448211, 448212, 448213, 448203, 448204, 448205 }, name = "The Upper Study" },
		{ tiles = { 448214, 448218, 448219, 448220, 448221, 448222, 448223, 448224, 448225, 448215, 448216, 448217 }, name = "Headmaster's Study" },
	},
	[309] = { -- Zul'Gurub
		{ tiles = { 515607, 515611, 515612, 515613, 515614, 515615, 515616, 515617, 515618, 515608, 515609, 515610 } },
	},
	[329] = { -- Stratholme
		{ tiles = { 448322, 448326, 448327, 448328, 448329, 448330, 448331, 448332, 448333, 448323, 448324, 448325 }, name = "Crusader's Square", wing = "Stratholme - Main Gate" },
		{ tiles = { 448334, 448338, 448339, 448340, 448341, 448342, 448343, 448344, 448345, 448335, 448336, 448337 }, name = "The Gauntlet", wing = "Stratholme - Service Entrance" },
	},
	[349] = { -- Maraudon
		{ tiles = { 449676, 449680, 449681, 449682, 449683, 449684, 449685, 449686, 449687, 449677, 449678, 449679 }, name = "Caverns of Maraudon" },
		{ tiles = { 449688, 449692, 449693, 449694, 449695, 449696, 449697, 449698, 449699, 449689, 449690, 449691 }, name = "Zaetar's Grave" },
	},
	[389] = { -- Ragefire Chasm
		{ tiles = { 449736, 449740, 449741, 449742, 449743, 449744, 449745, 449746, 449747, 449737, 449738, 449739 } },
	},
	[409] = { -- Molten Core
		{ tiles = { 448058, 448062, 448063, 448064, 448065, 448066, 448067, 448068, 448069, 448059, 448060, 448061 } },
	},
	[429] = { -- Dire Maul
		{ tiles = { 449508, 449512, 449513, 449514, 449515, 449516, 449517, 449518, 449519, 449509, 449510, 449511 }, name = "Gordok Commons", wing = "Dire Maul - North" },
		{ tiles = { 449520, 449524, 449525, 449526, 449527, 449528, 449529, 449530, 449531, 449521, 449522, 449523 }, name = "Capital Gardens", wing = "Dire Maul - West" },
		{ tiles = { 449532, 449536, 449537, 449538, 449539, 449540, 449541, 449542, 449543, 449533, 449534, 449535 }, name = "Court of the Highborne", wing = "Dire Maul - West" },
		{ tiles = { 449544, 449548, 449549, 449550, 449551, 449552, 449553, 449554, 449555, 449545, 449546, 449547 }, name = "Prison of Immol'Thar", wing = "Dire Maul - West" },
		{ tiles = { 449556, 449560, 449561, 449562, 449563, 449564, 449565, 449566, 449567, 449557, 449558, 449559 }, name = "Warpwood Quarter", wing = "Dire Maul - East" },
		{ tiles = { 449568, 449572, 449573, 449574, 449575, 449576, 449577, 449578, 449579, 449569, 449570, 449571 }, name = "The Shrine of Eldretharr", wing = "Dire Maul - East" },
	},
	[469] = { -- Blackwing Lair
		{ tiles = { 447770, 447774, 447775, 447776, 447777, 447778, 447779, 447780, 447781, 447771, 447772, 447773 }, name = "Dragonmaw Garrison" },
		{ tiles = { 447782, 447786, 447787, 447788, 447789, 447790, 447791, 447792, 447793, 447783, 447784, 447785 }, name = "Halls of Strife" },
		{ tiles = { 447794, 447798, 447799, 447800, 447801, 447802, 447803, 447804, 447805, 447795, 447796, 447797 }, name = "Crimson Laboratories" },
		{ tiles = { 447806, 447810, 447811, 447812, 447813, 447814, 447815, 447816, 447817, 447807, 447808, 447809 }, name = "Nefarian's Lair" },
	},
	[509] = { -- Ruins of Ahn'Qiraj
		{ tiles = { 449748, 449752, 449753, 449754, 449755, 449756, 449757, 449758, 449759, 449749, 449750, 449751 } },
	},
	[531] = { -- Ahn'Qiraj Temple
		{ tiles = { 450110, 450114, 450115, 450116, 450117, 450118, 450119, 450120, 450121, 450111, 450112, 450113 }, name = "The Hive Undergrounds" },
		{ tiles = { 450122, 450126, 450127, 450128, 450129, 450130, 450131, 450132, 450133, 450123, 450124, 450125 }, name = "The Temple Gates" },
		{ tiles = { 450134, 450138, 450139, 450140, 450141, 450142, 450143, 450144, 450145, 450135, 450136, 450137 }, name = "Vault of C'Thun" },
	},
}

local entrances={
    [33]={name="Shadowfang Keep",continent=0,worldX=-231.0,worldY=1571.6},
    [34]={name="Stormwind Stockade",continent=0,worldX=-8762.4,worldY=848.0},
    [36]={name="Deadmines",continent=0,worldX=-11207.8,worldY=1681.2},
    [43]={name="Wailing Caverns",continent=1,worldX=-751.1,worldY=-2209.2},
    [47]={name="Razorfen Kraul",continent=1,worldX=-4459.4,worldY=-1660.2},
    [48]={name="Blackfathom Deeps",continent=1,worldX=4249.1,worldY=748.4},
    [70]={name="Uldaman",continent=0,worldX=-6060.2,worldY=-2955.0},
    [90]={name="Gnomeregan",continent=0,worldX=-5162.7,worldY=931.6},
    [109]={name="Sunken Temple",continent=0,worldX=-10170.1,worldY=-3996.0},
    [129]={name="Razorfen Downs",continent=1,worldX=-4662.9,worldY=-2535.9},
    [189]={name="Scarlet Monastery - Graveyard",continent=0,worldX=2892.2,worldY=-811.3},
    [209]={name="Zul'Farrak",continent=1,worldX=-6790.6,worldY=-2891.3},
    [229]={name="Lower Blackrock Spire",continent=0,worldX=-7522.5,worldY=-1233.0},
    [409]={name="Molten Core",continent=0,worldX=-7522.5,worldY=-1233.0},
    [469]={name="Blackwing Lair",continent=0,worldX=-7522.5,worldY=-1233.0},
    [230]={name="Blackrock Depths",continent=0,worldX=-7178.1,worldY=-928.6},
    [249]={name="Onyxia's Lair",continent=1,worldX=-4753.3,worldY=-3752.4},
    [289]={name="Scholomance",continent=0,worldX=1274.8,worldY=-2552.6},
    [309]={name="Zul'Gurub",continent=0,worldX=-11916.1,worldY=-1224.6},
    [329]={name="Stratholme",continent=0,worldX=3392.3,worldY=-3378.5},
    [349]={name="Maraudon",continent=1,worldX=-1432.7,worldY=2925.0},
    [389]={name="Ragefire Chasm",continent=1,worldX=1816.8,worldY=-4423.4},
    [429]={name="Dire Maul - East",continent=1,worldX=-3908.0,worldY=1130.0},
    [509]={name="Ruins of Ahn'Qiraj",continent=1,worldX=-8114.5,worldY=1526.4},
    [531]={name="Ahn'Qiraj Temple",continent=1,worldX=-8114.5,worldY=1526.4},
    [2959]={name="City of Dalaran",mapID=1416,x=0.085,y=0.593},
    [2998]={name="Excavation Site: Wetlands",mapID=1437,x=0.478,y=0.562},
    [2999]={name="Ruins of Lordaeron",mapID=1458,x=0.725,y=0.114},
    [3065]={name="The Hall of Thanes",mapID=1455,x=0.277,y=0.479},
}
function D.Name(id)
    local name=A.Call(GetRealZoneText,id)
    return A.Safe(name)and type(name)=='string'and name~=''and name or entrances[id]and entrances[id].name
end
function D.Entrance(id)
    local e=entrances[id];if not e then return end
    if e.mapID then return{mapID=e.mapID,x=e.x,y=e.y}end
    if not CreateVector2D then return end
    local mapID,p=A.Call(C_Map and C_Map.GetMapPosFromWorldPos,e.continent,CreateVector2D(e.worldX,e.worldY),e.continent==0 and 1415 or 1414)
    if not A.PublicTable(p)then return end
    local x,y;if type(p.GetXY)=='function'then x,y=A.Call(p.GetXY,p)else x,y=p.x,p.y end
    if A.Safe(mapID,x,y)and type(mapID)=='number'and type(x)=='number'and type(y)=='number'and x>=0 and y>=0 and x<=1 and y<=1 then return{mapID=mapID,x=x,y=y}end
end
function D.Current()
    if type(GetInstanceInfo)~='function'then return end
    local ok,name,kind,_,_,_,_,_,id=pcall(GetInstanceInfo)
    if ok and A.Safe(name,kind,id)and(kind=='party'or kind=='raid'or kind=='scenario')and type(id)=='number'and id>0 and id<10000 then
        return{id=id,name=A.Safe(name)and type(name)=='string'and name or D.Name(id),entrance=D.Entrance(id)}
    end
end
function D.MapID(id,floor)return floors[id]and 800000+id*20+(floor or 1)-1 end
function D.Art(mapID)
    if mapID<800000 or mapID>=900000 then return end
    local id=math.floor((mapID-800000)/20);local floor=(mapID-800000)%20+1
    local f=floors[id]and floors[id][floor];if not f then return end
    local de=type(GetLocale)=='function'and GetLocale():sub(1,2)=='de'
    return{available=true,mapID=mapID,instanceID=id,floor=floor,mapType=4,name=(D.Name(id)or tostring(id))..' · '..(de and'Ebene 'or'Floor ')..floor,width=1002,height=668,tileWidth=256,tileHeight=256,files=Z.CompanionProtocol.Array(f.tiles)}
end
function D.MapIDs()
    local ids={};for id,list in pairs(floors)do for i=1,#list do ids[#ids+1]=D.MapID(id,i)end end;table.sort(ids);return ids
end
