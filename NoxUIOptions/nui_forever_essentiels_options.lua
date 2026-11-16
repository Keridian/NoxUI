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

local PAGE_GENERAL = "General"
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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    NoxUI:RegisterModule("NoxUIEssentielsForever", {
        title       = "Forever Essentials",
        description = "Essential tools for WoW Forever.",
        pages       = { PAGE_GENERAL, PAGE_TRAVEL, PAGE_THREAT, PAGE_LOOT, PAGE_MACROS, "Campement" },
        searchTerms = { "campement", "feu de camp", "repos", "flight timer", "flight path", "threat", "threat meter", "aggro", "loot", "loot feed", "reputation", "currency", "uprank", "spell rank", "junk", "junk items", "macro", "macros", "macro manager", "simplified stats", "item stats", "stat colors", "tooltip stats", "world map", "map", "reveal", "unexplored", "fog of war", "fishing skill", "quest reward", "quest rewards", "sell value", "boat", "zeppelin", "zone exit", "dungeon entrance", "instance" },
        buildPage   = function(pageName, parent, yOffset)
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
                return math.abs(yOffset-header-height)
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
