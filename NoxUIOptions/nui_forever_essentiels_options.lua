if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_forever_essentiels_options.lua
--  Registers the Forever Essentials sidebar addon (WoW Forever only) with its
--  tabs:
--    * General -- quality of life features (built by nui_forever_essentiels_general_options.lua)
--    * Travel -- flight timer (built by nui_forever_essentiels_voyage_options.lua)
--    * Threat -- threat meter (built by nui_forever_essentiels_menace_options.lua)
--    * Loot   -- loot feed (built by nui_forever_essentiels_butin_options.lua)
--    * Macros -- macro manager (built by nui_forever_essentiels_macros_options.lua)
-------------------------------------------------------------------------------
-- Page names are DEEP-LINK IDENTIFIERS: every NavigateToElementSettings tuple
-- and What's New nav carries them as strings and fails SILENTLY on a mismatch.
if not NoxUI._ModuleNS["NoxUIEssentielsForever"] then return end  -- module disabled: no options page

local forever = NoxUI._ModuleNS.NoxUIEssentielsForever
local PAGE_GENERAL = "General"
local W = NoxUI.Widgets
local mod = NoxUI._ModuleNS.NoxUIEssentielsForever
local activity = "default"
local activities = {
    default = "Tenues par défaut", none = "Monde ouvert",
    party = "Donjon", raid = "Raid", pvp = "Champ de bataille", arena = "Arène",
}

function mod.BuildForeverEquipment(parent, y)
    local gear = mod.ForeverEquipment
    local _, height = W:SectionHeader(parent, "Règle de l’activité", y)
    y = y - height
    local values, order = gear.List()
    local function SetChoice(group, label)
        return {
            type = "dropdown", text = label, values = values, order = order,
            tooltip = activity ~= "default" and "Sans tenue spécifique, la tenue par défaut de cette spécialisation s’applique." or nil,
            getValue = function()
                local id = tostring(gear.Get(activity, group) or "none")
                return values[id] and id or "none"
            end,
            setValue = function(key) gear.Set(activity, group, tonumber(key)) end,
        }
    end
    _, height = W:DualRow(parent, y,
        { type = "dropdown", text = "Activité", values = activities,
          order = { "default", "none", "party", "raid", "pvp", "arena" },
          getValue = function() return activity end,
          setValue = function(key) activity = key; NoxUI:RefreshPage() end },
        NoxUI.BlankRowCfg())
    y = y - height
    if gear.HasDualSpec() and activity ~= "default" then
        _, height = W:DualRow(parent, y,
            { type = "dropdown", text = "Spécialisation à l’arrivée",
              tooltip = "Choisit les talents à l’entrée dans cette activité, puis applique la tenue associée.",
              values = { none = "Garder la spécialisation active", ["1"] = "Principale", ["2"] = "Secondaire" },
              order = { "none", "1", "2" },
              getValue = function() return tostring(gear.GetSpecialization(activity) or "none") end,
              setValue = function(key) gear.SetSpecialization(activity, tonumber(key)) end },
            NoxUI.BlankRowCfg())
        y = y - height
    end
    _, height = W:SectionHeader(parent, "Tenues à équiper", y)
    y = y - height
    _, height = W:DualRow(parent, y, SetChoice(1, "Tenue principale"),
        gear.HasDualSpec() and SetChoice(2, "Tenue secondaire") or NoxUI.BlankRowCfg())
    y = y - height
    _, height = W:DualRow(parent, y,
        { type = "button", text = "Appliquer à mon activité actuelle",
          tooltip = "Utilise l’activité dans laquelle tu joues en ce moment.",
          onClick = gear.Apply }, NoxUI.BlankRowCfg())
    return math.abs(y - height)
end

local PAGE_TRAVEL  = "Travel"
local PAGE_THREAT  = "Threat"
local PAGE_LOOT    = "Loot"
local PAGE_MACROS  = "Macros"

-- Item quality dropdown values and order from Poor up to last, each in its
-- colour (the General and Loot pages).
_G._EUI_ItemQualityValues = function(last)
    local values, order = {}, {}
    for q = Enum.ItemQuality.Poor, last do
        local key, color = tostring(q), ITEM_QUALITY_COLORS[q]
        local label = _G["ITEM_QUALITY" .. q .. "_DESC"] or key
        values[key] = color and (color.hex .. label .. "|r") or label
        order[#order + 1] = key
    end
    return values, order
end

-- Page reuse: a frame this file builds goes through the options frame pool
-- (NoxUI_FramePool.lua, the options addon's first file), which hands a
-- kept page its previous build's frames back reset to new; on any other
-- parent it is the plain CreateFrame. The buildPage below only hands each
-- tab to its own page file.
local CreateFrame = NoxUI._Pool.CreateFrame

local talentActivity = "party"

local function TalentChoices(activity, reminders)
    local configID, _, trees = NoxUI.ForeverTalentTrees()
    local values, order, selected = { none = "Choisir un talent…" }, { "none" }, {}
    for _, id in ipairs(reminders.List(activity)) do selected[id] = true end
    if not configID or not trees then return values, order end

    for _, tree in ipairs(trees) do
        local branch = {}
        for _, nodeID in ipairs(tree.nodes) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            for _, entryID in ipairs(node and node.entryIDs or {}) do
                local entry = C_Traits.GetEntryInfo(configID, entryID)
                local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                local id = definition and definition.spellID
                if id and not selected[id] then
                    local name = C_Spell.GetSpellName(id)
                    if name then
                        local key = tostring(id)
                        selected[id] = true
                        values[key] = tree.name .. " · " .. name
                        branch[#branch + 1] = key
                    end
                end
            end
        end
        table.sort(branch, function(a, b)
            if values[a] == values[b] then return tonumber(a) < tonumber(b) end
            return values[a] < values[b]
        end)
        for _, key in ipairs(branch) do order[#order + 1] = key end
    end
    return values, order
end

local function BuildForeverTalents(parent, y)
    local reminders = forever.ForeverTalentReminders
    local W = NoxUI.Widgets
    local _, h = W:SectionHeader(parent, "Rappels de talents", y)
    y = y - h
    local values, order = TalentChoices(talentActivity, reminders)
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Activité",
          values = { party = "Donjon", raid = "Raid", pvp = "Champ de bataille", arena = "Arène" },
          order = { "party", "raid", "pvp", "arena" },
          getValue = function() return talentActivity end,
          setValue = function(key) talentActivity = key; NoxUI:RefreshPage() end },
        { type = "dropdown", text = "Ajouter un talent", values = values, order = order,
          disabled = function() return #order == 1 end,
          disabledTooltip = "Aucun talent supplémentaire disponible dans les arbres du personnage.",
          getValue = function() return "none" end,
          setValue = function(key)
              local id = tonumber(key)
              if not id then return end
              if reminders.Add(talentActivity, id) then
                  NoxUI:RefreshPage()
              else
                  NoxUI.PrintError("La liste de rappels est pleine.")
              end
          end })
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Exporter les rappels",
          disabled = function() return #reminders.List(talentActivity) == 0 end,
          onClick = function()
              local code = reminders.Export(talentActivity)
              if code then NoxUI:ShowExportPopup(code) end
          end },
        { type = "button", text = "Importer des rappels",
          onClick = function()
              NoxUI:ShowInputPopup({
                  title = "Importer des rappels",
                  message = "Colle un code de partage de ta classe.",
                  confirmText = "Importer",
                  onConfirm = function(value)
                      local activity = reminders.Import(value)
                      if not activity then
                          NoxUI.PrintError("Code invalide, autre classe ou liste pleine.")
                          return
                      end
                      talentActivity = activity
                      NoxUI:RefreshPage()
                  end,
              })
          end })
    y = y - h
    local active = reminders.List(talentActivity)
    if #active > 0 then
        _, h = W:SectionHeader(parent, "Rappels actifs", y)
        y = y - h
    end
    for index, id in ipairs(active) do
        local rowIndex = index
        _, h = W:DualRow(parent, y,
            { type = "label", text = C_Spell.GetSpellName(id) or tostring(id) },
            { type = "button", text = "Retirer ce rappel",
              onClick = function()
                  reminders.Remove(talentActivity, rowIndex)
                  NoxUI:RefreshPage()
              end })
        y = y - h
    end
    return math.abs(y)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local pages = { PAGE_GENERAL, PAGE_TRAVEL, PAGE_THREAT, PAGE_LOOT, PAGE_MACROS, "Campement" }
    if forever.ForeverEquipment then pages[#pages + 1] = "Tenues" end
    if forever.ForeverTalentReminders then pages[#pages + 1] = "Talents" end
    NoxUI:RegisterModule("NoxUIEssentielsForever", {
        title       = "Forever Essentials",
        description = "Essential tools for WoW Forever.",
        pages       = pages,
        searchTerms = { "tenues", "spécialisation", "rappels de talents", "partager un talent", "campement", "feu de camp", "repos", "flight timer", "flight path", "threat", "threat meter", "aggro", "loot", "loot feed", "reputation", "currency", "uprank", "spell rank", "junk", "junk items", "macro", "macros", "macro manager", "simplified stats", "item stats", "stat colors", "tooltip stats", "world map", "map", "reveal", "unexplored", "fog of war", "fishing skill", "quest reward", "quest rewards", "sell value", "boat", "zeppelin", "zone exit", "dungeon entrance", "instance" },
        buildPage   = function(pageName, parent, yOffset)
            if pageName == "Tenues" and forever.ForeverEquipment then
                return forever.BuildForeverEquipment(parent, yOffset)
            end
            if pageName == "Talents" and forever.ForeverTalentReminders then
                return BuildForeverTalents(parent, yOffset)
            end
            if pageName == "Campement" then
                local camp = NoxUI.Campement
                if not camp then return math.abs(yOffset) end
                local W = NoxUI.Widgets
                local _, header = W:SectionHeader(parent, "CAMPEMENT", yOffset)
                local _, height = W:DualRow(parent, yOffset-header,
                    { type="toggle", text="Afficher le campement",
                      tooltip="Affiche la feuille lorsque le jeu signale le feu ou le repos. Fais glisser la feuille centrale pour la déplacer.",
                      getValue=camp.Enabled, setValue=camp.SetEnabled },
                    { type="button", text="Afficher ou masquer l’aperçu", onClick=camp.Preview })
                local _, progressHeight = W:DualRow(parent, yOffset-header-height,
                    { type="toggle", text="Compte à rebours du sac de couchage",
                      tooltip="Affiche les charges de repos et le temps estimé avant trois charges au dessus de la feuille.",
                      getValue=camp.ShowSleepProgress, setValue=camp.SetShowSleepProgress },
                    NoxUI.BlankRowCfg())
                return math.abs(yOffset-header-height-progressHeight)
            end
            if pageName == PAGE_GENERAL and _G._EUI_BuildForeverGeneralPage then
                return _G._EUI_BuildForeverGeneralPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_TRAVEL and _G._EUI_BuildFlightTimerPage then
                return _G._EUI_BuildFlightTimerPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_THREAT and _G._EUI_BuildThreatMeterPage then
                return _G._EUI_BuildThreatMeterPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_LOOT and _G._EUI_BuildLootFeedPage then
                return _G._EUI_BuildLootFeedPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_MACROS and _G._EUI_BuildForeverMacrosPage then
                return _G._EUI_BuildForeverMacrosPage(pageName, parent, yOffset)
            end
        end,
        -- The Travel, Threat, Loot and Macros headers live in the content header; declaring a
        -- page's builder makes a cached page whose header was dropped rebuild with it.
        getHeaderBuilder = function(pageName)
            if pageName == PAGE_TRAVEL then return _G._EUI_TravelHeaderBuilder end
            if pageName == PAGE_THREAT then return _G._EUI_ThreatHeaderBuilder end
            if pageName == PAGE_LOOT then return _G._EUI_LootHeaderBuilder end
            if pageName == PAGE_MACROS and NoxUI._MacroManager.Enabled() then return _G._EUI_MacrosHeaderBuilder end
        end,
        resetScope = "account",
        onReset = function()
            if NoxUIDB then
                if NoxUI.Campement then NoxUI.Campement.Reset() end
                NoxUIDB.phaseGroupe = nil
                if NoxUI._PhaseGroupe then NoxUI._PhaseGroupe.Reset() end
                NoxUIDB.flightTimer = nil
                NoxUIDB.threatMeter = nil
                NoxUIDB.lootFeed = nil
                NoxUI.ClearCharField("lootFeedHistory")
                -- the roster's spellUprank, the ranks each character has had, is not a setting: it stays, so the
                -- option turned on again swaps only ranks learned since
                NoxUIDB.spellUprank = nil
                NoxUIDB.junkList = nil
                NoxUIDB.junkListExcluded = nil
                NoxUIDB.simplifiedStats = nil
                NoxUIDB.activeForm = nil
                NoxUIDB.classicSpellbook = nil
                NoxUIDB.classicTalents = nil
                NoxUIDB.macroManager = nil
                NoxUIDB.questRewards = nil
                NoxUIDB.zoneLevels = nil
                -- The per-character favorites are the player's picks: only the switch resets.
                if NoxUIDB.petSummon then NoxUIDB.petSummon.enabled = nil end
                -- The CVars a session holds stay recorded, so Apply can give them back.
                local fi = NoxUIDB.fishing
                NoxUIDB.fishing = fi and fi.held and { held = fi.held } or nil
                NoxUIDB.mapTravel = nil
                -- The game's mapFade from before stays, so Apply can give it back.
                local mf = NoxUIDB.worldMapFade
                NoxUIDB.worldMapFade = mf and mf.mapFadeWas ~= nil and { mapFadeWas = mf.mapFadeWas } or nil
                NoxUIDB.gatherSkill = nil
                if NoxUIDB.unlockAnchors then
                    NoxUIDB.unlockAnchors.EUI_FlightTimer = nil
                    NoxUIDB.unlockAnchors.EUI_ThreatMeter = nil
                    NoxUIDB.unlockAnchors.EUI_LootFeed = nil
                    NoxUIDB.unlockAnchors.EUI_JunkList = nil
                    NoxUIDB.unlockAnchors.EUI_ActiveForm = nil
                end
            end
            local FT = NoxUI._FlightTimer
            if FT then
                FT.Apply()
                FT.ApplyStyle()
                FT.ApplyPosition()
            end
            local TM = NoxUI._ThreatMeter
            if TM then
                TM.Apply()
                TM.ApplyStyle()
                TM.ApplyPosition()
            end
            local LF = NoxUI._LootFeed
            if LF then
                LF.Apply()
                LF.ApplyStyle()
                LF.ApplyPosition()
            end
            if NoxUI._SpellUprank then NoxUI._SpellUprank.Apply() end
            if NoxUI._JunkItems then NoxUI._JunkItems.Apply() end
            if NoxUI._ActiveForm then NoxUI._ActiveForm.Apply() end
            if NoxUI._ClassicSpellbook then NoxUI._ClassicSpellbook.Apply() end
            if NoxUI._ClassicTalents then NoxUI._ClassicTalents.Apply() end
            if NoxUI._QuestRewards then NoxUI._QuestRewards.Apply() end
            if NoxUI._ZoneLevels then NoxUI._ZoneLevels.Apply() end
            if NoxUI._PetSummon then NoxUI._PetSummon.Apply() end
            if NoxUI._Fishing then NoxUI._Fishing.Apply() end
            if NoxUI._MapTravel then NoxUI._MapTravel.Apply() end
            if NoxUI._MapFade then NoxUI._MapFade.Apply() end
            if NoxUI._GatherSkill then NoxUI._GatherSkill.Apply() end
            NoxUI:InvalidatePageCache()
        end,
    })
end)
-- LoadOnDemand: this addon loads after PLAYER_LOGIN, so the event above will never fire; run the init now.
if IsLoggedIn() then initFrame:GetScript("OnEvent")(initFrame) end
