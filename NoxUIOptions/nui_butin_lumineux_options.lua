if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI.RegisterModule then return end

    local function BuildPage(_, parent, offset)
        local W = NoxUI.Widgets
        local y, height = offset, 0
        _, height = W:Spacer(parent, y, 20)
        y = y - height
        _, height = W:SectionHeader(parent, "OBJETS DE QUÊTE", y)
        y = y - height
        _, height = W:DualRow(parent, y,
            { type = "toggle", text = "Afficher les lueurs des objets de quête",
              tooltip = "Maintient les lueurs après les changements graphiques. La désactivation prend effet après redémarrage du jeu.",
              getValue = function()
                  return NoxUI.ButinLumineux and NoxUI.ButinLumineux.IsEnabled()
              end,
              setValue = function(value)
                  if NoxUI.ButinLumineux then NoxUI.ButinLumineux.SetEnabled(value) end
              end,
              disabled = function() return not NoxUI.ButinLumineux end,
              disabledTooltip = "Le module de lueurs n'est pas chargé." },
            NoxUI.BlankRowCfg())
        y = y - height
        return math.abs(y)
    end

    NoxUI:RegisterModule("NoxUIButinLumineux", {
        title = "Lueurs de butin",
        description = "Visibilité des objets de quête dans le monde.",
        searchTerms = "butin quete lueur objets loot sparkle",
        pages = { "Lueurs" },
        buildPage = BuildPage,
    })
end)

if IsLoggedIn() then init:GetScript("OnEvent")(init) end
