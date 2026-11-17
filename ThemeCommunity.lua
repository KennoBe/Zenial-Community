-- Community-only theme data layered on the shared Theme (_dev/shared/Theme.lua): navigation icons and
-- profession table. Loaded after ThemeKit.lua; skin, tokens and kit come from _dev/shared.
local _, private = ...
local Z = ZenialCommunity
local T = Z and Z.Theme
if type(T) ~= "table" or type(T.assets) ~= "table" or type(private) ~= "table" then return end

local icons = T.assets.icons
for key, path in pairs({
    members = "Interface\\Icons\\INV_Misc_GroupLooking",
    crafting = "Interface\\Icons\\Trade_BlackSmithing",
    groups = "Interface\\LFGFrame\\UI-LFG-PORTRAIT",
    quests = "Interface\\GossipFrame\\AvailableQuestIcon",
    trade = "Interface\\Icons\\INV_Misc_Coin_01",
    profile = "Interface\\Icons\\INV_Misc_GroupLooking",
}) do icons[key] = path end

T.assets.professions = {
    ["Alchemie"]="Interface\\Icons\\Trade_Alchemy", ["Alchimie"]="Interface\\Icons\\Trade_Alchemy", ["Alchemy"]="Interface\\Icons\\Trade_Alchemy",
    ["Schmiedekunst"]="Interface\\Icons\\Trade_BlackSmithing", ["Blacksmithing"]="Interface\\Icons\\Trade_BlackSmithing",
    ["Verzauberkunst"]="Interface\\Icons\\Trade_Engraving", ["Enchanting"]="Interface\\Icons\\Trade_Engraving",
    ["Ingenieurskunst"]="Interface\\Icons\\Trade_Engineering", ["Engineering"]="Interface\\Icons\\Trade_Engineering",
    ["Kräuterkunde"]="Interface\\Icons\\Trade_Herbalism", ["Herbalism"]="Interface\\Icons\\Trade_Herbalism",
    ["Lederverarbeitung"]="Interface\\Icons\\Trade_LeatherWorking", ["Leatherworking"]="Interface\\Icons\\Trade_LeatherWorking",
    ["Bergbau"]="Interface\\Icons\\Trade_Mining", ["Mining"]="Interface\\Icons\\Trade_Mining",
    ["Kürschnerei"]="Interface\\Icons\\INV_Misc_Pelt_Wolf_01", ["Skinning"]="Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    ["Schneiderei"]="Interface\\Icons\\Trade_Tailoring", ["Tailoring"]="Interface\\Icons\\Trade_Tailoring",
    ["Kochkunst"]="Interface\\Icons\\INV_Misc_Food_15",["Kochen"]="Interface\\Icons\\INV_Misc_Food_15", ["Cooking"]="Interface\\Icons\\INV_Misc_Food_15",
    ["Erste Hilfe"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice", ["First Aid"]="Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Angeln"]="Interface\\Icons\\Trade_Fishing", ["Fishing"]="Interface\\Icons\\Trade_Fishing",
}

function T.ProfessionIcon(name) return name and T.assets.professions[name] or nil end

Z.Kit = private.Kit
Z.ThemeTokensLoaded = private.ThemeTokensLoaded
Z.ThemeCommunityLoaded = true
