if NUI_CLIENT_BLOQUE then return end
if not (NoxUI and NoxUI.IS_FOREVER) then return end

local _, ns = ...
local feature = ns.Feature("phaseGroupe", { enabled = true })

local function InCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    if not UnitAffectingCombat then return false end
    local ok, value = pcall(UnitAffectingCombat, "player")
    if not ok or (issecretvalue and issecretvalue(value)) then return true end
    return not not value
end

local function InTransit()
    return (IsFlying and IsFlying()) or (IsFalling and IsFalling())
        or (UnitOnTaxi and UnitOnTaxi("player"))
end

local function Notify(message)
    if NoxUI.Print then NoxUI.Print(message) else print("NoxUI : " .. message) end
end

local function RequestRefresh()
    if not (IsInGroup and IsInGroup()) then
        Notify("Vous devez être en groupe pour demander un changement de phase.")
        return
    end
    if InCombat() then
        Notify("La demande sera possible après le combat.")
        return
    end
    if InTransit() then
        Notify("Posez vous avant de demander un changement de phase.")
        return
    end
    local api = C_PlayerInteractionManager and C_PlayerInteractionManager.ShardTransferConfirm
    if type(api) ~= "function" then
        Notify("Le rafraîchissement de phase n'est pas disponible sur ce client.")
        return
    end
    local ok, result = pcall(api)
    if not ok or result == false then
        Notify("Le jeu n'a pas accepté la demande de rafraîchissement.")
        return
    end
    Notify("Tentative de rafraîchissement effectuée. Le jeu décide si un transfert est disponible.")
end

local function RefreshBar()
    local bars = NoxUI._ModuleNS and NoxUI._ModuleNS.NoxUIBarresDonnees
    if bars and bars.RefreshPhaseGroupe then bars.RefreshPhaseGroupe() end
end

NoxUI._PhaseGroupe = {
    Get = feature.Get,
    IsAvailable = function() return feature.Enabled() and IsInGroup and IsInGroup() end,
    RequestRefresh = RequestRefresh,
    SetEnabled = function(value)
        feature.Cfg().enabled = value and true or false
        RefreshBar()
    end,
    Apply = RefreshBar,
    Reset = RefreshBar,
}
