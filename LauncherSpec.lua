-- Entry points of the standalone Community window (/zenial).
local _, ns = ...
ns.LauncherSpec = {
    minimapPrimary = true,
    openMain = function()
        local handler = _G.SlashCmdList and _G.SlashCmdList.ZENIALCOMMUNITY
        if type(handler) == "function" then handler("") end
    end,
    minimapStatus = function()
        local community = _G.ZenialCommunity
        local unread = community and community.UI and community.UI.unreadTotal or 0
        if unread > 0 then return community.T("%d unread updates", unread) end
    end,
    openSettings = function()
        local frame = _G.ZenialCommunityFrame
        if frame and frame.IsShown and frame:IsShown() then return end
        local handler = _G.SlashCmdList and _G.SlashCmdList.ZENIALCOMMUNITY
        if type(handler) == "function" then handler("") end
    end,
}
