if NUI_CLIENT_BLOQUE then return end
if not NoxUI or not NoxUI.IS_FOREVER then return end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI or not NoxUI.RegisterModule then return end
    -- Advanced graphics CVars are account client settings, not profile values.
    -- Reading the page never writes a CVar; unavailable values stay disabled.
    local function BuildAdvancedGraphicsPage(pageName, parent, yOffset)
        local W = NoxUI.Widgets
        local y, h = yOffset, 0
        local specs = {
            { name="groundEffectDensity", text="Végétation au sol", lo=0, hi=256, step=1,
              tip="Densité des détails au sol. Une valeur élevée peut réduire les performances." },
            { name="farclip", text="Distance de vue", lo=0, hi=10000, step=100,
              tip="Distance d'affichage du terrain. Une valeur élevée peut réduire les performances." },
            { name="lodObjectCullSize", text="Visibilité des petits objets", lo=0, hi=64, step=1,
              tip="Seuil de disparition des petits objets. Une valeur plus basse peut les conserver plus loin." },
            { name="lodObjectFadeScale", text="Détail des objets distants", lo=0, hi=400, step=1,
              tip="Distance de transition des niveaux de détail. Une valeur élevée peut réduire les performances." },
            { name="brightness", text="Luminosité", lo=0, hi=100, step=1,
              tip="Réglage personnel de luminosité du jeu." },
            { name="contrast", text="Contraste", lo=0, hi=100, step=1,
              tip="Réglage personnel de contraste du jeu." },
        }
        local hidden = { "ResampleAlwaysSharpen", "groundEffectDensity", "farclip", "lodObjectCullSize", "lodObjectFadeScale" }
        local extra = {
            { name="groundEffectDist", text="Distance de la végétation", lo=0, hi=1000, step=10,
              tip="Distance d'affichage des détails du sol. Les limites du client peuvent varier." },
            { name="groundEffectFade", text="Transition de la végétation", lo=0, hi=1000, step=10,
              tip="Distance de disparition progressive des détails du sol." },
            { name="doodadLodScale", text="Détail des petits décors", lo=0, hi=400, step=1,
              tip="Échelle des niveaux de détail des objets du décor." },
            { name="terrainLodDist", text="Détail du terrain distant", lo=0, hi=5000, step=10,
              tip="Distance de transition des niveaux de détail du terrain." },
            { name="wmoLodDist", text="Détail des grandes structures", lo=0, hi=2000, step=10,
              tip="Distance des niveaux de détail des grandes structures." },
            { name="weatherDensity", text="Densité météorologique", lo=0, hi=5, step=1,
              tip="Densité des effets de pluie, neige et météo selon le client." },
            { name="horizonStart", text="Début de l'horizon", lo=0, hi=10000, step=100,
              tip="Distance de début de la zone d'horizon." },
            { name="horizonClip", text="Limite de l'horizon", lo=0, hi=20000, step=100,
              tip="Distance limite de l'horizon. Peut affecter les performances." },
            { name="RAIDgroundEffectDist", text="Végétation en raid", lo=0, hi=1000, step=10,
              tip="Distance des détails du sol pour les réglages graphiques de raid lorsqu'ils sont utilisés." },
            { name="RAIDfarclip", text="Distance de vue en raid", lo=0, hi=10000, step=100,
              tip="Distance de vue des réglages graphiques de raid lorsqu'ils sont utilisés." },
        }
        local function read(name)
            if not C_CVar or not C_CVar.GetCVar then return nil end
            local ok, value = pcall(C_CVar.GetCVar, name)
            if ok and value ~= nil then return tostring(value) end
        end
        local function available(name) return read(name) ~= nil end
        local function write(name, value)
            if InCombatLockdown() then
                NoxUI.PrintError("Réglage impossible pendant le combat.")
                return false
            end
            if not available(name) or not C_CVar.SetCVar then
                NoxUI.PrintError("Réglage indisponible : " .. name)
                return false
            end
            local ok, result = pcall(C_CVar.SetCVar, name, tostring(value))
            if not ok or result == false then
                NoxUI.PrintError("Impossible de modifier : " .. name)
                return false
            end
            return true
        end
        local function slider(spec)
            local current = tonumber(read(spec.name))
            local lo = current and math.min(spec.lo, current) or spec.lo
            local hi = current and math.max(spec.hi, current) or spec.hi
            return { type="slider", text=spec.text, min=lo, max=hi, step=spec.step,
                tooltip=spec.tip .. " Valeur actuelle du jeu, appliquée au déplacement du curseur.",
                disabled=function() return not available(spec.name) end,
                disabledTooltip="Ce réglage n'est pas disponible dans ce client.",
                getValue=function() return tonumber(read(spec.name)) or lo end,
                setValue=function(v) write(spec.name, v) end }
        end
        _, h = W:Spacer(parent, y, 20); y = y - h
        if NoxUI._BuildGraphicsActions then
            y = NoxUI._BuildGraphicsActions(parent, y)
        end
        _, h = W:Spacer(parent, y, 20); y = y - h
        _, h = W:SectionHeader(parent, "GRAPHISMES AVANCÉS", y); y = y - h
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Renforcer la netteté",
              tooltip="Active la netteté au rééchantillonnage. Utilise le même réglage que les options générales.",
              disabled=function() return not available("ResampleAlwaysSharpen") end,
              disabledTooltip="Ce réglage n'est pas disponible dans ce client.",
              getValue=function() return read("ResampleAlwaysSharpen") == "1" end,
              setValue=function(v) write("ResampleAlwaysSharpen", v and "1" or "0") end },
            NoxUI.BlankRowCfg()); y = y - h
        for i = 1, #specs, 2 do
            _, h = W:DualRow(parent, y, slider(specs[i]), slider(specs[i + 1])); y = y - h
        end
        _, h = W:Spacer(parent, y, 20); y = y - h
        _, h = W:SectionHeader(parent, "DÉTAILS DU MONDE ET RAID", y); y = y - h
        for i = 1, #extra, 2 do
            _, h = W:DualRow(parent, y, slider(extra[i]), slider(extra[i + 1])); y = y - h
        end
        _, h = W:Spacer(parent, y, 20); y = y - h
        _, h = W:SectionHeader(parent, "VALEURS PAR DÉFAUT", y); y = y - h
        _, h = W:DualRow(parent, y,
            { type="button", text="Rétablir les cinq réglages", noCapture=true,
              onClick=function()
                if InCombatLockdown() then NoxUI.PrintError("Réinitialisation impossible pendant le combat."); return end
                local restored, skipped = 0, 0
                for _, name in ipairs(hidden) do
                    local ok, default = false, nil
                    if C_CVar and C_CVar.GetCVarDefault then ok, default = pcall(C_CVar.GetCVarDefault, name) end
                    if ok and default ~= nil and available(name) and write(name, default) then
                        restored = restored + 1
                    else
                        skipped = skipped + 1
                    end
                end
                print("NoxUI : " .. restored .. " réglage(s) rétabli(s), " .. skipped .. " indisponible(s).")
                NoxUI:RefreshPage()
              end },
            { type="button", text="Rétablir les détails du monde", noCapture=true,
              onClick=function()
                if InCombatLockdown() then NoxUI.PrintError("Réinitialisation impossible pendant le combat."); return end
                local restored, skipped = 0, 0
                for _, spec in ipairs(extra) do
                    local ok, default = false, nil
                    if C_CVar and C_CVar.GetCVarDefault then ok, default = pcall(C_CVar.GetCVarDefault, spec.name) end
                    if ok and default ~= nil and available(spec.name) and write(spec.name, default) then
                        restored = restored + 1
                    else
                        skipped = skipped + 1
                    end
                end
                print("NoxUI : " .. restored .. " réglage(s) rétabli(s), " .. skipped .. " indisponible(s).")
                NoxUI:RefreshPage()
              end }); y = y - h
        return math.abs(y)
    end


    NoxUI:RegisterModule("_NUIGraphismes", {
        title = "Graphismes et optimisation",
        description = "Réglages graphiques avancés et performances du jeu.",
        searchTerms = "graphismes optimisation fps vegetation nettete distance vue",
        pages = { "Graphismes avancés" },
        buildPage = BuildAdvancedGraphicsPage,
    })
end)

if IsLoggedIn() then init:GetScript("OnEvent")(init) end
