if NUI_CLIENT_BLOQUE then return end if (select(2, ...)).slcInert then return end



SimpleLootCouncil = SimpleLootCouncil or {}
local addon = SimpleLootCouncil

addon.CombatQueue = NoxUI.NewCombatQueue(CreateFrame("Frame"))
