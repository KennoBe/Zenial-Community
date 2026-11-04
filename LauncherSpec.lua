-- Entry points of the standalone Community window (/zenial).
local _, ns = ...
ns.LauncherSpec = {
    openSettings = function()
        local frame = _G.ZenialCommunityFrame
        if frame and frame.IsShown and frame:IsShown() then return end
        local handler = _G.SlashCmdList and _G.SlashCmdList.ZENIALCOMMUNITY
        if type(handler) == "function" then handler("") end
    end,
}
