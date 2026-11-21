if NUI_CLIENT_BLOQUE then return end if (select(2, ...)).slcInert then return end



SimpleLootCouncil = SimpleLootCouncil or {}
local addon = SimpleLootCouncil
local T = addon.Locale.Text

local UI = addon.UI or {}
addon.UI = UI

local Options = {}
UI.Options = Options

local MODULE = "NoxUIConseilButin"


local function PageShown()
    return NoxUI:IsShown() and NoxUI:GetActiveModule() == MODULE
end



function Options:Toggle()
    if PageShown() then
        NoxUI:Hide()
        return
    end
    if InCombatLockdown() then
        addon.Chat.Print(T["the settings cannot open during combat."])
        return
    end
    NoxUI:ShowModule(MODULE)
end


function Options:Refresh()
    addon.Callbacks:Invalidate("options")
end

function Options:Init()


    Options.view = addon.Callbacks:RegisterView("options", {
        shown = PageShown,
        paint = function()
            NoxUI:RefreshPage()
        end,
    })
    NoxUI:RegisterOnShow(function() addon.Callbacks:PaintNow("options") end)

    addon.Log:I("UI", "options ready (NoxUI page)")
end
