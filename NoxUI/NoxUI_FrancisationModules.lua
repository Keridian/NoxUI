if NUI_CLIENT_BLOQUE then return end
local moduleNames = {
    ["NoxUIActionBars"] = "NoxUIBarresAction",
    ["NoxUIAuraBuffReminders"] = "NoxUIRappelsAuras",
    ["NoxUIBags"] = "NoxUISacs",
    ["NoxUIBlizzardSkin"] = "NoxUIApparenceBlizzard",
    ["NoxUIChat"] = "NoxUIDiscussion",
    ["NoxUICooldownManager"] = "NoxUIGestionRecharges",
    ["NoxUIDamageMeters"] = "NoxUICompteurDegats",
    ["NoxUIDataBars"] = "NoxUIBarresDonnees",
    ["NoxUIForeverEssentials"] = "NoxUIEssentielsForever",
    ["NoxUIFriends"] = "NoxUIAmis",
    ["NoxUIGroupFinder"] = "NoxUIRechercheGroupe",
    ["NoxUILoadoutManager"] = "NoxUIGestionEquipements",
    ["NoxUILocales"] = "NoxUILangues",
    ["NoxUIMinimap"] = "NoxUIMinicarte",
    ["NoxUIMythicTimer"] = "NoxUIChronometreMythique",
    ["NoxUINameplates"] = "NoxUIBarresNoms",
    ["NoxUIQoL"] = "NoxUIConfortJeu",
    ["NoxUIQuestTracker"] = "NoxUISuiviQuetes",
    ["NoxUIQuickdraw"] = "NoxUISelectionRapide",
    ["NoxUIRaidFrames"] = "NoxUICadresRaid",
    ["NoxUIResourceBars"] = "NoxUIBarresRessources",
    ["NoxUISimpleLootCouncil"] = "NoxUIConseilButin",
    ["NoxUIUnitFrames"] = "NoxUICadresUnite",
}

-- Existing database globals keep their names; this translates their folder keys.
NoxUIFrancisationModules = moduleNames
local function translateSavedTree(root)
    if type(root) ~= "table" then return end
    local seen = {}
    local pending = { root }
    while #pending > 0 do
        local data = table.remove(pending)
        if not seen[data] then
            seen[data] = true
            local aliases = {}
            for key, value in pairs(data) do
                local renamed = type(key) == "string" and moduleNames[key]
                if renamed and data[renamed] == nil then aliases[#aliases + 1] = { key, renamed, value } end
                if type(value) == "table" then
                    pending[#pending + 1] = value
                elseif type(value) == "string" and (key == "o" or key == "folder" or key == "hostAddon" or key == "addon" or key == "module") and moduleNames[value] then
                    data[key] = moduleNames[value]
                end
            end
            for _, entry in ipairs(aliases) do
                data[entry[2]] = entry[3]
                data[entry[1]] = nil
            end
        end
    end
end
NoxUIFrancisationMigrerDonnees = translateSavedTree
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "NoxUI" then return end
    translateSavedTree(NoxUIDB)
    self:UnregisterEvent("ADDON_LOADED")
end)
