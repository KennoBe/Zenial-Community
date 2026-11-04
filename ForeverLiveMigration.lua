local Z=ZenialCommunity
local function copy(value,seen)
    if type(value)~='table'then return value end
    seen=seen or{};if seen[value]then return seen[value]end
    local result={};seen[value]=result
    for key,item in pairs(value)do result[key]=copy(item,seen)end
    return result
end

-- Run before any legacy character migration can reintroduce beta profiles.
-- The old root stays recoverable but no active reader traverses this backup.
function Z.MigrateForeverLive(root)
    if root.foreverLiveVersion~=nil then
        -- Accept the shared export preferences saved by the first local preview.
        local companion=root.companion
        if root.foreverLiveVersion==1 and root.foreverLiveBackup and type(companion)=='table'and companion.version==1 and type(companion.shared)=='table'and companion.characters==nil then companion.characters={}end
        return
    end
    local backup={};local populated=false
    for key,value in pairs(root)do backup[key]=value;populated=true end
    local account=type(root.account)=='table'and root.account or{}
    local ui=type(root.ui)=='table'and root.ui or{}
    local companion=type(root.companion)=='table'and root.companion or{}
    local preferences=type(account.preferences)=='table'and copy(account.preferences)or{}
    local profiles=type(root.characters)=='table'and root.characters or{}
    local sourceKey=account.mainKey
    if type(profiles[sourceKey])~='table'then
        local keys={};for key,value in pairs(profiles)do if type(key)=='string'and type(value)=='table'then keys[#keys+1]=key end end
        table.sort(keys);sourceKey=keys[1]
    end
    local profile=profiles[sourceKey]or{}
    for _,name in ipairs({'visible','shareProfessions','scale','minimapAngle','minimapHidden','position'})do
        if preferences[name]==nil then preferences[name]=copy(profile[name])end
    end
    local view=type(ui.characters)=='table'and ui.characters[sourceKey]or{}
    view=type(view)=='table'and view or{}
    for _,name in ipairs({'mapMembers','mapGuildOnly','memberStatus'})do
        if preferences[name]==nil then preferences[name]=copy(view[name])end
    end
    local pvp=type(root.pvpHelp)=='table'and root.pvpHelp[sourceKey]or{}
    if type(pvp)=='table'then
        if preferences.pvpReceive==nil then preferences.pvpReceive=pvp.receive end
        if preferences.pvpScope==nil then preferences.pvpScope=pvp.scope end
    end
    preferences.initialized=true
    local shared=copy(companion.shared)
    if type(shared)~='table'then
        for _,settings in pairs(type(companion.characters)=='table'and companion.characters or{})do
            if type(settings)=='table'and settings.enabled==true then shared=copy(settings);break end
        end
    end
    for key in pairs(root)do root[key]=nil end
    root.foreverLiveVersion=1
    if populated then root.foreverLiveBackup=backup end
    root.account={preferences=preferences}
    root.ui={window=copy(ui.window),showAddonManager=ui.showAddonManager}
    if shared then
        shared.sessionSequence=0
        root.companion={version=1,shared=shared,characters={}}
    end
end
