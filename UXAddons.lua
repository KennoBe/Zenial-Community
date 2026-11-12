local Z = ZenialCommunity
local U = Z.UI
local S = U.Shared
local tr = S.tr
local ADDON_PAGE, ADDON_CATALOG, updateNavPath = S.ADDON_PAGE, S.ADDON_CATALOG, S.updateNavPath

local function addonCall(method, ...)
    local fn = C_AddOns and C_AddOns[method]
    if type(fn) ~= 'function' then
        return false
    end
    return pcall(fn, ...)
end
local function addonExists(entry)
    local ok, exists = addonCall('DoesAddOnExist', entry.addon)
    if ok then
        return exists == true
    end
    return _G.ZenialAddonPanels and _G.ZenialAddonPanels[entry.addon] ~= nil
end
local function addonState(entry)
    if not addonExists(entry) then
        return { kind = 'missing', text = tr('Nicht installiert') }
    end
    local version = ''
    local versionOK, value = addonCall('GetAddOnMetadata', entry.addon, 'Version')
    if versionOK and type(value) == 'string' then
        version = value
    end
    local enabledOK, enabledState = addonCall('GetAddOnEnableState', entry.addon)
    if enabledOK and tonumber(enabledState) == 0 then
        return { kind = 'disabled', text = tr('Installiert, aber deaktiviert'), version = version }
    end
    local infoOK, _, _, _, loadable, reason = addonCall('GetAddOnInfo', entry.addon)
    if infoOK and loadable == false then
        return { kind = 'unavailable', text = tr('Nicht ladbar') .. (type(reason) == 'string' and reason ~= '' and ': ' .. reason or ''), version = version }
    end
    local loadedOK, loadedOrLoading, loaded = addonCall('IsAddOnLoaded', entry.addon)
    if loadedOK and loadedOrLoading and not loaded then
        return { kind = 'loading', text = tr('Wird geladen'), version = version }
    end
    if loadedOK and not loaded then
        return { kind = 'reload', text = tr('Installiert · nach /reload verfügbar'), version = version }
    end
    local provider = _G.ZenialAddonPanels and _G.ZenialAddonPanels[entry.addon]
    if type(provider) == 'table' and provider.apiVersion == 1 and type(provider.CreatePanel) == 'function' then
        return { kind = 'ready', text = tr('Installiert und geladen'), version = version, provider = provider }
    end
    return { kind = 'legacy', text = tr('Installiert · Update für Einbettung erforderlich'), version = version }
end
U.GetAddonState = addonState
function U.HideAddonPanels()
    for _, cached in pairs(U.addonPanels or {}) do
        cached.frame:Hide()
    end
end
function U.RefreshAddonAvailability()
    if not U.addonSelector or not U.tabs then
        return 0
    end
    local count, first = 0, nil
    local selectedExists = ADDON_CATALOG[U.addonIndex or 0] ~= nil
    for i, entry in ipairs(ADDON_CATALOG) do
        local exists = addonExists(entry)
        if exists then
            count = count + 1
            first = first or i
        end
    end
    U.addonAvailableCount = count
    if count == 0 then
        U.HideAddonPanels()
        U.addonIndex = nil
    elseif not selectedExists then
        U.HideAddonPanels()
        U.addonIndex = first
    end
    if U.addonSelector then
        local options = {}
        for _, entry in ipairs(ADDON_CATALOG) do options[#options + 1] = entry.addon end
        U.addonSelector:SetOptions(options, ADDON_CATALOG[U.addonIndex or first or 1] and ADDON_CATALOG[U.addonIndex or first or 1].addon)
    end
    if U.settingsAddon then
        U.settingsAddon:SetEnabled(count > 0)
    end
    if U.LayoutMainTabs then
        U.LayoutMainTabs()
    end
    updateNavPath()
    return count
end
function U.RefreshAddonManager()
    if not U.addonHost then
        return
    end
    if U.RefreshAddonAvailability() == 0 then
        return
    end
    local entry = ADDON_CATALOG[U.addonIndex or 1]
    if not entry then
        return
    end
    local state = addonState(entry)
    U.addonCurrentState = state
    U.addonDescription:SetText(tr(entry.description))
    U.addonStatus:SetText(
        '|cffffd36b'
            .. tr(state.text)
            .. '|r'
            .. (state.version and state.version ~= '' and ' · ' .. tr('Version') .. ' ' .. state.version or '')
    )
    U.addonDescription:SetShown(state.kind ~= 'ready')
    U.addonStatus:Show()
    U.addonAction:Hide()
    U.addonAction:SetEnabled(true)
    if state.kind == 'ready' then
        for name, cached in pairs(U.addonPanels) do
            if name ~= entry.addon then
                cached.frame:Hide()
            end
        end
        local cached = U.addonPanels[entry.addon]
        if not cached then
            local ok, frame, refresh = pcall(state.provider.CreatePanel, U.addonHost)
            if ok and frame then
                cached = { frame = frame, refresh = type(refresh) == 'function' and refresh or function() end }
                U.addonPanels[entry.addon] = cached
            else
                U.addonStatus:SetText('|cffff5555' .. tr('Embedded interface could not be created.') .. '|r')
                U.addonStatus:Show()
            end
        end
        if cached then
            cached.frame:ClearAllPoints()
            cached.frame:SetAllPoints(U.addonHost)
            cached.frame:SetFrameStrata(U.frame:GetFrameStrata())
            cached.frame:SetFrameLevel(U.addonHost:GetFrameLevel() + 1)
            cached.frame:Show()
            local refreshed = pcall(cached.refresh)
            if not refreshed then
                U.addonStatus:SetText('|cffff5555' .. tr('Embedded interface could not be created.') .. '|r')
                U.addonStatus:Show()
            end
        end
    else
        U.HideAddonPanels()
    end
    if U.addonSelector then U.addonSelector:SetText(entry.addon) end
    if state.kind == 'legacy' and type(SlashCmdList[entry.slash]) == 'function' then
        U.addonAction:SetText(tr('Open addon window'))
        U.addonAction:SetScript('OnClick', function()
            SlashCmdList[entry.slash]('')
        end)
        U.addonAction:Show()
    elseif state.kind == 'disabled' then
        U.addonAction:SetText(tr('Enable in AddOns menu'))
        U.addonAction:SetEnabled(false)
        U.addonAction:Show()
    elseif state.kind == 'reload' then
        U.addonAction:SetText(tr('/reload required'))
        U.addonAction:SetEnabled(false)
        U.addonAction:Show()
    end
end
function U.SetAddonView(index)
    if U.addonIndex ~= index then
        U.HideAddonPanels()
    end
    U.addonIndex = index
    updateNavPath()
    U.RefreshAddonManager()
end
-- Opens the Community window on the embedded manager page of a ready catalog addon (never toggles it
-- closed). Returns false when the addon is not in the catalog or not ready so the caller can fall back.
function U.OpenAddonManager(addon)
    local ok, handled = pcall(function()
        local index
        for i, entry in ipairs(ADDON_CATALOG) do
            if entry.addon == addon then
                if addonState(entry).kind ~= 'ready' then
                    return false
                end
                index = i
                break
            end
        end
        if not index then
            return false
        end
        if not Z.db and type(Z.Initialize) == 'function' then
            Z.Initialize()
        end
        if not Z.db then
            return false
        end
        U.Create()
        if not U.frame then
            return false
        end
        if not U.frame:IsShown() then
            U.frame:Show()
        end
        if U.Navigation.UnsavedInput() then
            U.Navigation.Fail('unsaved-input')
            return true
        end
        U.Page(ADDON_PAGE)
        U.SetAddonView(index)
        return true
    end)
    return ok and handled == true
end
Z.OpenAddonManager = U.OpenAddonManager

