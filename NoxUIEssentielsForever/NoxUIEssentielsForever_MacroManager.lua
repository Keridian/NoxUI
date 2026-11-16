if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
if not (NoxUI and NoxUI.IS_FOREVER) then return end
-------------------------------------------------------------------------------
--  NoxUIEssentielsForever_MacroManager.lua  (WoW Forever only)
--  The Macro Manager's switch and /euimacros. The editor is the "Macros" page
--  of the Forever Essentials options (nui_forever_essentiels_macros_options.lua,
--  its model nui_forever_essentiels_macro_modele_options.lua), built with the
--  panel. NoxUIDB.macroManager holds only the switch: the game's macro
--  text is the macro.
-------------------------------------------------------------------------------
local _, module = ...

local F = module.Feature("macroManager", { enabled = false })

-- /euimacros opens the page; registered at the first enable.
local slashDone
local function Apply()
    if slashDone or not F.Enabled() then return end
    slashDone = true
    SLASH_EUIMACROS1 = "/nuimacros"
    SlashCmdList.EUIMACROS = function()
        if F.Enabled() and not InCombatLockdown() then
            NoxUI:NavigateToElementSettings("NoxUIEssentielsForever", "Macros")
        end
    end
end

-- Options-page entry points.
NoxUI._MacroManager = { Enabled = F.Enabled, Cfg = F.Cfg, Apply = Apply }

F.Start(Apply)
