local env = select(2, ...)
local CallbackRegistry = env.modules:Import("packages\\callback-registry")
local Settings_Schema = env.modules:Await("@\\Settings\\Schema")
local Setting = env.modules:New("@\\Settings")

function Setting.GetNoxOptions()
    return Settings_Schema.SCHEMA, env.modules:Import("@\\Settings\\Enum").WidgetType,
        env.Config.DBGlobal, CallbackRegistry
end

function Setting.OpenSettingsUI()
    if NoxUI and NoxUI.NavigateToElementSettings then
        NoxUI:NavigateToElementSettings("NoxUIWaypointUI", "Général")
    end
end

