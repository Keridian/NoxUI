if NUI_CLIENT_BLOQUE then return end

-- Disposition carrée native de NoxUI, inspirée de la minicarte Vista de
-- Horizon Suite. Le code d'origine est distribué sous licence MIT ; voir
-- LICENSE_HORIZON_SUITE.txt. Aucun module Horizon n'est requis ici.
local _, ns = ...

local preset = {
    enabled = true,
    useBlizzardStyle = false,
    useClassicStyle = false,
    useForeverStyle = false,
    shape = "square",
    mapSize = 200,
    borderSize = 1,
    borderTexture = "solid",
    borderR = 1, borderG = 1, borderB = 1, borderA = 0.15,
    borderUseClassColor = false,
    useClassColor = false,
    coordsMode = "always",
    coordsPosition = "belowMap",
    coordsBelowOffsetX = 65,
    coordsBelowOffsetY = 0,
    coordPrecision = 1,
    locationMode = "inside",
    locationPosition = "belowMap",
    locationOffsetX = 0,
    locationOffsetY = -17,
    clockMode = "inside",
    clockPosition = "belowMap",
    clockOffsetX = -65,
    clockOffsetY = 0,
    zoomResetSeconds = 5,
}

-- Le cliché est limité aux champs modifiés : placement, boutons, filtres et
-- autres préférences continuent de vivre dans le profil existant.
function ns.ApplySquareLayout(settings)
    if type(settings) ~= "table" then return false end
    if not settings._noxSquarePrevious then
        local before = { values = {}, present = {} }
        for key in pairs(preset) do
            local value = rawget(settings, key)
            if value ~= nil then before.present[key] = true; before.values[key] = value end
        end
        local color = rawget(settings, "borderColor")
        if color ~= nil then before.present.borderColor = true; before.values.borderColor = color end
        settings._noxSquarePrevious = before
    end
    for key, value in pairs(preset) do settings[key] = value end
    settings.borderColor = { r = 1, g = 1, b = 1 }
    return true
end

function ns.RestoreSquareLayout(settings)
    if type(settings) ~= "table" then return false end
    local before = rawget(settings, "_noxSquarePrevious")
    if type(before) ~= "table" or type(before.present) ~= "table" or type(before.values) ~= "table" then return false end
    for key in pairs(preset) do
        if before.present[key] then settings[key] = before.values[key] else settings[key] = nil end
    end
    if before.present.borderColor then settings.borderColor = before.values.borderColor else settings.borderColor = nil end
    settings._noxSquarePrevious = nil
    return true
end

-- Compatibilité facultative : l'intégration fonctionne sans Horizon Suite.
-- Quand Vista est présent, seul ce module est arrêté avant le rechargement.
function ns.ReleaseHorizonVista(horizon)
    if not horizon then return true end
    if type(horizon.IsModuleEnabled) ~= "function" then return false end
    local ok, active = pcall(horizon.IsModuleEnabled, horizon, "vista")
    if not ok then return false end
    if not active then return true end
    if type(horizon.DisableModule) ~= "function" then return false end
    local disabled = pcall(horizon.DisableModule, horizon, "vista")
    local checked, stillActive = pcall(horizon.IsModuleEnabled, horizon, "vista")
    return disabled and checked and not stillActive
end
