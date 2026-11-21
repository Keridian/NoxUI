if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  Nameplates_Options\GeneralPage_Options.lua
--  Nameplates options: the General page, shown as the Extras tab
--  (BuildGeneralPage). Definitions only; the shared helpers come from
--  ns._NPO_OptEnv (filled by nui_plaques_noms_options.lua).
-------------------------------------------------------------------------------
local ns = NoxUI._ModuleNS["NoxUIBarresNoms"]
if not ns then return end  -- module disabled: no options page

-- The options page frame pool (NoxUI_FramePool.lua): frames made under a
-- pooled page part are handed back to the page's next build.
local CreateFrame = NoxUI._Pool.CreateFrame

---------------------------------------------------------------------------
--  General page (Spacing, Extra Aura Options, Extras); two-column DualRow layout where possible
---------------------------------------------------------------------------
local function BuildGeneralPage(pageName, parent, yOffset)
    local env = ns._NPO_OptEnv
    local DB, DBVal, defaults, GetNPOptOutline = env.DB, env.DBVal, env.defaults, env.GetNPOptOutline
    local npDispelGlowDesc, npPandemicGlowDesc, pcall, PP = env.npDispelGlowDesc, env.npPandemicGlowDesc, env.pcall, env.PP
    local RefreshAllAuras, SECTION_AURA, SECTION_ENEMY_NP, SECTION_MISC = env.RefreshAllAuras, env.SECTION_AURA, env.SECTION_ENEMY_NP, env.SECTION_MISC
    local SearchWords, SliderLabel, UpdatePreview = env.SearchWords, env.SliderLabel, env.UpdatePreview
    local W = NoxUI.Widgets
    local y = yOffset
    local _, h

    -- No preview on General tab
    NoxUI:ClearContentHeader()

    -- Enable per-row center divider for the dual-column layout
    parent._showRowDivider = true

    -----------------------------------------------------------------------
    --  FRIENDLY NAMEPLATES
    -----------------------------------------------------------------------

    _, h = W:SectionHeader(parent, "REPÈRES SOCIAUX", y); y = y - h
    local function markerOption(key, label, description)
        return { type = "toggle", text = label, tooltip = description,
            getValue = function() return DBVal(key) ~= false end,
            setValue = function(value)
                DB()[key] = value
                if ns.RefreshSocialMarkers then ns.RefreshSocialMarkers() end
            end }
    end
    _, h = W:DualRow(parent, y,
        markerOption("socialMarkerGroup", "Losange bleu pour le groupe", "Affiche un losange au dessus du nom des membres du groupe."),
        markerOption("socialMarkerRaid", "Carré rouge pour le raid", "Affiche un carré au dessus du nom des membres du raid.")); y = y - h
    _, h = W:DualRow(parent, y,
        markerOption("socialMarkerGuild", "Rond doré pour la guilde", "Affiche un rond au dessus du nom des membres de votre guilde."),
        NoxUI.BlankRowCfg()); y = y - h
    local function nameColorOption(key, label, description)
        return { type = "toggle", text = label, tooltip = description,
            getValue = function() return DBVal(key) == true end,
            setValue = function(value)
                DB()[key] = value
                if ns.RefreshSocialMarkers then ns.RefreshSocialMarkers() end
            end }
    end
    _, h = W:DualRow(parent, y,
        nameColorOption("colorGroupNames", "Noms bleus pour le groupe et le raid",
            "Colore les noms des membres de votre groupe ou raid. Cette couleur est prioritaire sur la couleur de guilde."),
        nameColorOption("colorGuildNames", "Noms dorés pour la guilde",
            "Colore les noms des membres de votre guilde.")); y = y - h
    _, h = W:SectionHeader(parent, SECTION_FRIENDLY, y); y = y - h

    local function friendlyPlayersOff() return DBVal("showFriendlyPlayers") == false end
    local function friendlyPlateOff() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end
    local function nameOnlyOff() return friendlyPlayersOff() or DBVal("friendlyNameOnly") == false end
    -- Title renders INLINE with the name (one string, takes the name's own font/size/color); only the guild line below is styled by the size/color/bracket controls, so those gate on a mode that includes guild.
    local function subtitleGuildOff()
        local m = DBVal("friendlyBelowName") or "none"
        return friendlyPlayersOff() or (m ~= "guild" and m ~= "both")
    end

    local friendlyRow
    _, h = W:DualRow(parent, y,
        { type="toggle", text="Show NoxUI Friendly Player Nameplates",
          tooltip="When disabled, NoxUI relinquishes full control of friendly player nameplates to Blizzard. Use Blizzard's own Nameplate settings (Esc > Options > Nameplates) to control them.",
          getValue=function() return DBVal("showFriendlyPlayers") ~= false end,
          setValue=function(v)
            DB().showFriendlyPlayers = v
            do
                if v then
                    -- Enabling: re-assert every friendly-player CVar that SetupAuraCVars sets on load (it skips these while the toggle is off) -- runtime is the only restore path short of /reload.
                    local p = DB()
                    local nameOnly = (p and p.friendlyNameOnly ~= false)
                    local classColor = (p and p.classColorFriendly ~= false)
                    -- One of only two places NoxUI is allowed to force friendly plates visible; also clears any follower-dungeon capture.
                    if ns.ForceFriendlyPlayerCVarsOn then
                        ns.ForceFriendlyPlayerCVarsOn()
                    end
                    pcall(NoxUI.SetCVar, "UnitNameFriendlyPlayerName", 1, "NoxUIBarresNoms")
                    pcall(NoxUI.SetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits", nameOnly and 1 or 0, "NoxUIBarresNoms")
                    pcall(NoxUI.SetCVar, "ShowClassColorInFriendlyNameplate", classColor and 1 or 0, "NoxUIBarresNoms")
                    pcall(NoxUI.SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", ns.FriendlyNameClassCVar(p), "NoxUIBarresNoms")
                else
                    -- Disabling: reset the three CVars NoxUI uniquely manages (name-only override + class color) to Blizzard defaults for a clean slate; visibility CVars stay untouched so Blizzard's panel keeps the user's values.
                    if GetCVarDefault then
                        for _, cvar in ipairs({
                            "nameplateShowOnlyNameForFriendlyPlayerUnits",
                            "ShowClassColorInFriendlyNameplate",
                            "nameplateUseClassColorForFriendlyPlayerUnitNames",
                        }) do
                            local d = GetCVarDefault(cvar)
                            if d ~= nil then pcall(NoxUI.SetCVar, cvar, d, "NoxUIBarresNoms") end
                        end
                    end
                end
            end
            if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
            -- Re-assert stacking after friendly CVar changes (Blizzard can reset the stacking bitfield as a side effect).
            ns.RefreshStackingMotion()
            NoxUI:RefreshPage()
          end },
        { type="toggle", text="Make Friendly Nameplates Name Only",
          tooltip="Hide friendly player health bars and instead only see their names.\n\nRequires 'Simplified Friendly Nameplates' to be disabled in Blizzard's Nameplate settings (Esc > Options > Nameplates).",
          getValue=function() return DBVal("friendlyNameOnly") ~= false end,
          setValue=function(v)
            DB().friendlyNameOnly = v
            pcall(NoxUI.SetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits", v and 1 or 0, "NoxUIBarresNoms")
            -- Turning name-only ON means the user wants to SEE friendly plates -- the second sanctioned force-visible point.
            if v and ns.ForceFriendlyPlayerCVarsOn then
                ns.ForceFriendlyPlayerCVarsOn()
            end
            if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
            NoxUI:RefreshPage()
          end,
          disabled = friendlyPlayersOff,
          disabledTooltip = "Show NoxUI Friendly Player Nameplates" });  friendlyRow = _; y = y - h

    ---------------------------------------------------------------
    --  Friendly Player cog popup (size, health text, class colours, target border)
    ---------------------------------------------------------------
    if not NoxUI._prebuilding then
        NoxUI.BuildInlineCog(friendlyRow._leftRegion, {
            chain = false,
            disabled = friendlyPlateOff,
            disabledTooltip = "Requires Name Only setting to be disabled", rawTooltip = true,
            title = "Friendly Nameplate Settings",
            rows = {
                { type = "slider", label = "Distance", min = -50, max = 50, step = 1,
                  get = function() return DBVal("friendlyPlateYOffset") or 0 end,
                  set = function(v) DB().friendlyPlateYOffset = v; if ns.RefreshFriendlyPlateYOffset then ns.RefreshFriendlyPlateYOffset() end end },
                { type = "slider", label = "Height", min = 6, max = 40, step = 1,
                  get = function() return DBVal("friendlyHealthBarHeight") or defaults.friendlyHealthBarHeight end,
                  set = function(v) DB().friendlyHealthBarHeight = v; if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end end },
                { type = "slider", label = "Width", min = 80, max = 250, step = 1,
                  get = function() return DBVal("friendlyHealthBarWidth") or defaults.friendlyHealthBarWidth end,
                  set = function(v) DB().friendlyHealthBarWidth = v; if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end end },
                { type = "slider", label = "Name Size", min = 6, max = 30, step = 1,
                  get = function() return DBVal("friendlyNameTextSize") or defaults.friendlyNameTextSize end,
                  set = function(v) DB().friendlyNameTextSize = v; if ns.RefreshFriendlyNameTextSize then ns.RefreshFriendlyNameTextSize() end end },
                { type = "toggle", label = "Show Health Percent",
                  get = function() local db = DB(); return not (db and db.friendlyHideHealthText) end,
                  set = function(v)
                    DB().friendlyHideHealthText = not v
                    if ns.RefreshFriendlyHealthText then ns.RefreshFriendlyHealthText() end
                  end },
                { type = "toggle", label = "Class Colored Health Bar",
                  get = function() return DBVal("classColorFriendly") ~= false end,
                  set = function(v)
                    DB().classColorFriendly = v and true or false
                    -- Blizzard's instance plates colour their names by this CVar.
                    if not InCombatLockdown() then
                        pcall(NoxUI.SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", ns.FriendlyNameClassCVar(DB()), "NoxUIBarresNoms")
                    end
                    ns.RefreshAllSettings()
                  end },
                { type = "colorpicker", label = "Health Bar Color",
                  tooltip = "Health bar color for friendly players when Class Colored Health Bar is off.",
                  disabled = function() return DBVal("classColorFriendly") ~= false end,
                  disabledTooltip = "Class Colored Health Bar", requireState = "disabled",
                  get = function()
                    local c = DBVal("friendlyBarColor") or defaults.friendlyBarColor
                    return c.r, c.g, c.b
                  end,
                  set = function(r, g, b)
                    DB().friendlyBarColor = { r = r, g = g, b = b }
                    ns.RefreshFriendlyColors()
                  end },
                { type = "toggle", label = "Class Colored Names",
                  get = function() return DBVal("friendlyNameClassColor") == true end,
                  set = function(v)
                    DB().friendlyNameClassColor = v and true or false
                    if not InCombatLockdown() then
                        pcall(NoxUI.SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", ns.FriendlyNameClassCVar(DB()), "NoxUIBarresNoms")
                    end
                    ns.RefreshFriendlyColors()
                  end },
                { type = "toggle", label = "Target Border Effects",
                  tooltip = "Also applies the target Border Color and Border Size effects to friendly nameplates.",
                  -- Borders stand down under the stock styles.
                  disabled = function()
                    return NoxUI.BlizzStyle.Get("nameplates")
                        or not (ns.GetTargetGlowBorderColor() or ns.GetTargetGlowBorderSize())
                  end,
                  disabledTooltip = function()
                    if NoxUI.BlizzStyle.Get("nameplates") then
                        return NoxUI.BlizzStyle.Label("nameplates")
                    end
                    return "This option requires the Border Color or Border Size target effect."
                  end,
                  rawTooltip = function() return not NoxUI.BlizzStyle.Get("nameplates") end,
                  requireState = "disabled",
                  get = function() return DBVal("friendlyTargetBorderFx") == true end,
                  set = function(v)
                    DB().friendlyTargetBorderFx = v
                    -- Applies to (or restores) the friendly target now.
                    for _, fp in pairs(ns.friendlyPlates) do fp:ApplyTarget() end
                    UpdatePreview()
                  end },
            },
        })
    end

    ---------------------------------------------------------------
    --  Name Only inline swatches (White + Class Color) mirror the Target Arrows double-swatch pattern: classColorFriendly picks the active swatch (inactive dims); neither opens a picker (White fixed, Class = player's class color). Both gray out when Name Only is off.
    ---------------------------------------------------------------
    if not NoxUI._prebuilding then
        local rightRgn = friendlyRow._rightRegion
        local whiteSwatch, updateWhite, classSwatch, updateClass
        local function refreshNameSwatches()
            if updateWhite then updateWhite() end
            if updateClass then updateClass() end
            local off = nameOnlyOff()
            local useClass = DBVal("classColorFriendly") ~= false
            whiteSwatch:SetAlpha(off and 0.15 or (useClass and 0.3 or 1))
            classSwatch:SetAlpha(off and 0.15 or (useClass and 1 or 0.3))
            whiteSwatch:SetMouseClickEnabled(not off)
            classSwatch:SetMouseClickEnabled(not off)
        end
        local function ApplyClassColored(useClass)
            DB().classColorFriendly = useClass and true or false
            pcall(NoxUI.SetCVar, "ShowClassColorInFriendlyNameplate", useClass and 1 or 0, "NoxUIBarresNoms")
            pcall(NoxUI.SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", ns.FriendlyNameClassCVar(DB()), "NoxUIBarresNoms")
            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
            refreshNameSwatches()
        end
        -- White swatch: fixed white, not editable; clicking only selects the non-class-colored mode (default OnClick picker replaced below).
        whiteSwatch, updateWhite = NoxUI.BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
            function() return 1, 1, 1 end,
            function() end, nil, 20)
        PP.Point(whiteSwatch, "RIGHT", rightRgn._control, "LEFT", -8, 0)
        whiteSwatch:SetScript("OnClick", function()
            if nameOnlyOff() then return end
            ApplyClassColored(false)
        end)
        whiteSwatch:SetScript("OnEnter", function() NoxUI.ShowWidgetTooltip(whiteSwatch, "White") end)
        whiteSwatch:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        -- Class color swatch: player's class color; selects class-colored mode.
        classSwatch, updateClass = NoxUI.BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
            function()
                local _, ct = UnitClass("player")
                local cc = ct and C_ClassColor and C_ClassColor.GetClassColor(ct)
                if cc then return cc.r, cc.g, cc.b end
                return 1, 1, 1
            end,
            function() end, nil, 20)
        PP.Point(classSwatch, "RIGHT", whiteSwatch, "LEFT", -8, 0)
        rightRgn._lastInline = classSwatch
        classSwatch:SetScript("OnClick", function()
            if nameOnlyOff() then return end
            ApplyClassColored(true)
        end)
        classSwatch:SetScript("OnEnter", function() NoxUI.ShowWidgetTooltip(classSwatch, "Class Color") end)
        classSwatch:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        NoxUI.RegisterWidgetRefresh(refreshNameSwatches)
        refreshNameSwatches()
    end

    ---------------------------------------------------------------
    --  Subtitle Text: title renders inline with the name, guild sits on its own line below. The colour pair styles ONLY the guild line -- the inline title is part of the name string, using its colour.
    ---------------------------------------------------------------
    -- Custom/Class pair follows the multiSwatch convention: clicking the INACTIVE custom swatch only selects custom mode (click again to open the picker); the inactive swatch dims, both grey out together.
    local function MakeGuildColorSwatches()
        return {
            { tooltip = "Custom Color", hasAlpha = false,
              getValue = function()
                  local c = DBVal("friendlyBelowNameColor") or defaults.friendlyBelowNameColor
                  return c.r, c.g, c.b
              end,
              setValue = function(r, g, b)
                  DB().friendlyBelowNameColor = { r = r, g = g, b = b }
                  if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
              end,
              onClick = function(self)
                  if DBVal("friendlyBelowNameClassColor") == true then
                      DB().friendlyBelowNameClassColor = false
                      if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
                      NoxUI:RefreshPage()
                      return
                  end
                  if self._eabOrigClick then self._eabOrigClick(self) end
              end,
              refreshAlpha = function()
                  if subtitleGuildOff() then return 0.15 end
                  return (DBVal("friendlyBelowNameClassColor") == true) and 0.3 or 1
              end },
            { tooltip = "Class Color", hasAlpha = false,
              getValue = function()
                  local _, ct = UnitClass("player")
                  local cc = ct and C_ClassColor and C_ClassColor.GetClassColor(ct)
                  if cc then return cc.r, cc.g, cc.b end
                  return 1, 1, 1
              end,
              setValue = function() end,
              onClick = function()
                  DB().friendlyBelowNameClassColor = true
                  if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
                  NoxUI:RefreshPage()
              end,
              refreshAlpha = function()
                  if subtitleGuildOff() then return 0.15 end
                  return (DBVal("friendlyBelowNameClassColor") == true) and 1 or 0.3
              end },
        }
    end

    local subtitleRow
    subtitleRow, h = W:DualRow(parent, y,
        { type="dropdown", text="Subtitle Text",
          tooltip="Show the player's title inline with their name, and/or their guild on a line below it, on friendly nameplates.",
          disabled=friendlyPlayersOff,
          disabledTooltip="Show NoxUI Friendly Player Nameplates",
          values={ none="None", title="Player Title", guild="Guild Name", both="Title & Guild" },
          order={ "none", "title", "guild", "both" },
          getValue=function() return DBVal("friendlyBelowName") or "none" end,
          setValue=function(v)
            DB().friendlyBelowName = v
            if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
            NoxUI:RefreshPage()
          end },
        { type="multiSwatch", text="Guild Text Color",
          disabled=subtitleGuildOff,
          disabledTooltip=function()
              if friendlyPlayersOff() then return "Show NoxUI Friendly Player Nameplates" end
              return "This option requires Subtitle Text to include the Guild Name"
          end,
          rawTooltip=function() return not friendlyPlayersOff() end,
          swatches = MakeGuildColorSwatches() });  y = y - h

    -- Subtitle Text inline cog: Name Text Settings, headed by the friendly Name
    -- Format (a friendly player's name, in both modes), so the cog opens
    -- whenever friendly players show and the guild row carries the guild
    -- requirement itself.
    if not NoxUI._prebuilding then
        NoxUI.BuildInlineCog(subtitleRow._leftRegion, {
            chain = false,
            disabled = friendlyPlayersOff,
            disabledTooltip = "Show NoxUI Friendly Player Nameplates",
            title = "Name Text Settings",
            rows = {
                -- WoW Forever names it for players, as Forever Essentials' Name
                -- Format section does (it only ever shaped players' names).
                NoxUI.NameFormatCogRow(
                    function() return DBVal("friendlyNameFormat") end,
                    function(v)
                        DB().friendlyNameFormat = v
                        ns.NP_SyncFriendlyNameFormat()
                    end,
                    NoxUI.IS_FOREVER == true and { label = "Player Name Format",
                        tooltip = "Friendly player names on nameplates, in both modes." } or nil),
                { type = "toggle", label = "Show Level",
                  get = function() return DBVal("friendlyShowLevel") == true end,
                  set = function(v)
                    DB().friendlyShowLevel = v and true or false
                    if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
                  end },
                { type = "toggle", label = "Color Level by Difficulty",
                  disabled = function() return DBVal("friendlyShowLevel") ~= true end,
                  disabledTooltip = "This option requires Show Level",
                  rawTooltip = true,
                  get = function() return DBVal("friendlyLevelDiffColor") == true end,
                  set = function(v)
                    DB().friendlyLevelDiffColor = v and true or false
                    if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
                  end },
                { type = "toggle", label = "Show <> Around Guild",
                  disabled = subtitleGuildOff,
                  disabledTooltip = "This option requires Subtitle Text to include the Guild Name",
                  rawTooltip = true,
                  get = function() return DBVal("friendlyBelowNameGuildBrackets") ~= false end,
                  set = function(v)
                    DB().friendlyBelowNameGuildBrackets = v and true or false
                    if ns.RefreshFriendlyBelowName then ns.RefreshFriendlyBelowName() end
                  end },
            },
        })
    end

    local npcRow
    npcRow, h = W:DualRow(parent, y,
        { type="toggle", text="Show Friendly NPC Nameplates",
          getValue=function() return DBVal("showFriendlyNPCs") == true end,
          setValue=function(v)
            DB().showFriendlyNPCs = v
            pcall(NoxUI.SetCVar, "nameplateShowFriendlyNPCs", v and 1 or 0, "NoxUIBarresNoms")
            pcall(NoxUI.SetCVar, "nameplateShowFriendlyNpcs", v and 1 or 0, "NoxUIBarresNoms")
            if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
            NoxUI:RefreshPage()
          end },
        { type="slider", text="Friendly Name Size", trackWidth=120,
          min=8, max=30, step=1,
          disabled=nameOnlyOff,
          disabledTooltip="Make Friendly Nameplates Name Only",
          getValue=function() return DBVal("friendlyNameSize") or defaults.friendlyNameSize end,
          setValue=function(v)
            DB().friendlyNameSize = v
            if ns.RefreshFriendlyNameSize then ns.RefreshFriendlyNameSize() end
          end,
          tooltip="Adjusts the size of friendly player names shown in Name Only mode. Default is 15." });  y = y - h

    -- Cog popup for NPC nameplate settings (Show NPC Titles)
    do
        local function npcOff() return DBVal("showFriendlyNPCs") ~= true end
        -- Every row here styles the name-only overlay, so the mode gate lives
        -- on the cog button; only the title rows need a gate of their own.
        local function npcCogOff() return npcOff() or nameOnlyOff() end
        local function titleOff() return DBVal("showNPCTitles") == false end
        -- The overlay's marker follows the Raid Marker element, as the friendly plates' does.
        local function markerOff() return (DBVal("raidMarkerPos") or defaults.raidMarkerPos) == "none" end

        local rgn = npcRow._leftRegion
        local btn = NoxUI.BuildInlineCog(rgn, {
            chain = false,
            disabled = npcCogOff,
            disabledTooltip = function()
                return npcOff() and "Requires Show Friendly NPC Nameplates to be enabled" or "Requires Name Only mode"
            end,
            rawTooltip = true,
            title = "Friendly NPC Settings",
            rows = {
                NoxUI.NameFormatCogRow(
                    function() return DBVal("friendlyNPCNameFormat") end,
                    function(v)
                        DB().friendlyNPCNameFormat = v
                        if ns.RefreshAllNPCOverlays then ns.RefreshAllNPCOverlays() end
                    end),
                { type = "toggle", label = "Show NPC Titles",
                  get = function() return DBVal("showNPCTitles") ~= false end,
                  set = function(v)
                    DB().showNPCTitles = v and true or false
                    if ns.RefreshAllNPCOverlays then ns.RefreshAllNPCOverlays() end
                  end },
                { type = "toggle", label = "Show Raid Marker",
                  get = function() return DBVal("showNPCRaidMarker") ~= false end,
                  set = function(v)
                    DB().showNPCRaidMarker = v and true or false
                    if ns.RefreshAllNPCOverlays then ns.RefreshAllNPCOverlays() end
                  end,
                  disabled = markerOff, disabledTooltip = "Raid Marker" },
                { type = "slider", label = "Name Size", min = 6, max = 30, step = 1,
                  get = function() return DBVal("friendlyNPCNameSize") or defaults.friendlyNPCNameSize end,
                  set = function(v)
                    DB().friendlyNPCNameSize = v
                    if ns.RefreshNPCOverlayStyle then ns.RefreshNPCOverlayStyle() end
                  end },
                { type = "slider", label = "Title Size", min = 6, max = 30, step = 1,
                  get = function() return DBVal("friendlyNPCTitleSize") or defaults.friendlyNPCTitleSize end,
                  set = function(v)
                    DB().friendlyNPCTitleSize = v
                    if ns.RefreshNPCOverlayStyle then ns.RefreshNPCOverlayStyle() end
                  end,
                  disabled = titleOff, disabledTooltip = "Show NPC Titles" },
                { type = "colorpicker", label = "Name Color",
                  get = function()
                    local c = DBVal("friendlyNPCNameColor") or defaults.friendlyNPCNameColor
                    return c.r, c.g, c.b
                  end,
                  set = function(r, g, b)
                    DB().friendlyNPCNameColor = { r = r, g = g, b = b }
                    if ns.RefreshNPCOverlayStyle then ns.RefreshNPCOverlayStyle() end
                  end },
                { type = "colorpicker", label = "Title Color", hasAlpha = true,
                  get = function()
                    local c = DBVal("friendlyNPCTitleColor") or defaults.friendlyNPCTitleColor
                    return c.r, c.g, c.b, c.a or 1
                  end,
                  set = function(r, g, b, a)
                    DB().friendlyNPCTitleColor = { r = r, g = g, b = b, a = a or 1 }
                    if ns.RefreshNPCOverlayStyle then ns.RefreshNPCOverlayStyle() end
                  end,
                  disabled = titleOff, disabledTooltip = "Show NPC Titles" },
            },
        })

        -- Inline swatch: friendly NPC bar & name color, full-plate mode only -- the exact complement of the cog beside it, which owns the name-only colors.
        local function npcColorOff() return npcOff() or friendlyPlateOff() end
        local npcSwatch, updateNpcSwatch
        local function refreshNpcSwatch()
            if updateNpcSwatch then updateNpcSwatch() end
            local off = npcColorOff()
            npcSwatch:SetAlpha(off and 0.3 or 1)
            npcSwatch:SetMouseClickEnabled(not off)
        end
        npcSwatch, updateNpcSwatch = NoxUI.BuildColorSwatch(rgn, rgn:GetFrameLevel() + 5,
            function() local c = DBVal("friendlyNPCColor") or defaults.friendlyNPCColor; return c.r, c.g, c.b end,
            function(r, g, b)
                DB().friendlyNPCColor = { r = r, g = g, b = b }
                ns.RefreshFriendlyColors()
                refreshNpcSwatch()
            end, nil, 20)
        PP.Point(npcSwatch, "RIGHT", btn or rgn._control, "LEFT", -8, 0)
        rgn._lastInline = npcSwatch
        local origNpcClick = npcSwatch:GetScript("OnClick")
        npcSwatch:SetScript("OnClick", function(self, ...)
            if npcColorOff() then return end
            if origNpcClick then origNpcClick(self, ...) end
        end)
        npcSwatch:SetScript("OnEnter", function(self)
            if npcOff() then
                NoxUI.ShowWidgetTooltip(self, "Requires Show Friendly NPC Nameplates to be enabled")
            elseif DBVal("friendlyNameOnly") ~= false then
                NoxUI.ShowWidgetTooltip(self, "Requires Name Only mode to be disabled")
            else
                NoxUI.ShowWidgetTooltip(self, "NPC Bar & Name Color")
            end
        end)
        npcSwatch:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        NoxUI.RegisterWidgetRefresh(refreshNpcSwatch)
        refreshNpcSwatch()
    end

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Friendly Names Not Clickable",
          tooltip="Make friendly player and NPC nameplates click-through so their names never block your mouse or cause accidental friendly targeting.\n\nUse this when friendly names get in the way of clicking the world or the enemy nameplates behind them.",
          getValue=function() return DBVal("friendlyClickThrough") == true end,
          setValue=function(v)
            DB().friendlyClickThrough = v
            if ns.UpdateFriendlyClickThrough then ns.UpdateFriendlyClickThrough() end
          end },
        { type="toggle", text="Show Enemy Pet Nameplates",
          getValue=function() return DBVal("showEnemyPets") == true end,
          setValue=function(v)
            DB().showEnemyPets = v
            pcall(NoxUI.SetCVar, "nameplateShowEnemyPets", v and 1 or 0, "NoxUIBarresNoms")
          end,
          tooltip="Toggle visibility of enemy pet nameplates." });  y = y - h

    -- Inline DIRECTIONS cog on Friendly Name Size: name-only vertical distance
    if not NoxUI._prebuilding then
        NoxUI.BuildInlineCog(npcRow._rightRegion, {
            disabled = nameOnlyOff,
            title = "Name Distance",
            rows = {
                { type = "slider", label = "Distance", min = -50, max = 50, step = 1,
                  get = function() return DBVal("friendlyNameOnlyYOffset") or defaults.friendlyNameOnlyYOffset end,
                  set = function(v)
                    DB().friendlyNameOnlyYOffset = v
                    if ns.RefreshFriendlyNameOnlyOffset then ns.RefreshFriendlyNameOnlyOffset() end
                  end },
            },
        })
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h

    -----------------------------------------------------------------------
    --  ENEMY NAMEPLATE SPACING
    -----------------------------------------------------------------------
    _, h = W:SectionHeader(parent, SECTION_ENEMY_NP, y);  y = y - h

    local stackingRow
    stackingRow, h = W:DualRow(parent, y,
        { type="dropdown", text="Stacking Nameplates",
          values={ __placeholder = "..." }, order={ "__placeholder" },
          getValue=function() return "__placeholder" end,
          setValue=function() end },
        { type="slider", text="Stacked Nameplate Spacing",
          trackWidth=130,
          min=50, max=200, step=5,
          getValue=function() return DBVal("stackSpacingScale") or defaults.stackSpacingScale end,
          setValue=function(v)
            DB().stackSpacingScale = v
            ns.RefreshStackingBounds()
          end,
          tooltip="Adjusts the vertical spacing between stacked nameplates. 100% = default, lower = tighter, higher = more spread." });  y = y - h

    -- Replace the placeholder dropdown with a multi-select checkbox dropdown; Enemy and Friendly stacking are independent toggles over the Midnight stacking bitfield. Friendly locks out while NoxUI isn't managing friendly plates (Blizzard owns that bit then).
    if not NoxUI._prebuilding then
        local leftRgn = stackingRow._leftRegion
        if leftRgn._control then leftRgn._control:Hide() end
        local stackItems = {
            { key = "enemy",    label = "Enemy Nameplates" },
            { key = "friendly", label = "Friendly Nameplates",
              lockedFn = function() return DBVal("showFriendlyPlayers") == false end },
        }
        local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
            leftRgn, 170, leftRgn:GetFrameLevel() + 2,
            stackItems,
            function(k)
                if k == "enemy" then return DBVal("stackingEnabled") ~= false end
                if k == "friendly" then return DBVal("stackingFriendly") == true end
                return false
            end,
            function(k, v)
                if k == "enemy" then DB().stackingEnabled = v
                elseif k == "friendly" then DB().stackingFriendly = v end
                ns.RefreshStackingMotion()
            end)
        PP.Point(cbDD, "RIGHT", leftRgn, "RIGHT", -20, 0)
        leftRgn._control = cbDD
        cbDD._ttText = "Choose which nameplates stack vertically instead of overlapping."
        NoxUI.RegisterWidgetRefresh(cbDDRefresh)
    end

    local hitboxRow
    hitboxRow, h = W:DualRow(parent, y,
        { type="slider", text="Hitbox Size X",
          min=50, max=250, step=5,
          getValue=function() return DBVal("hitboxScaleX") or defaults.hitboxScaleX end,
          setValue=function(v)
            DB().hitboxScaleX = v
            ns.RefreshHitboxSize()
          end,
          tooltip="Widens the clickable hitbox of enemy nameplates. 100% = matches bar width. Increase to make nameplates easier to click." },
        { type="slider", text="Hitbox Size Y",
          min=50, max=250, step=5,
          getValue=function() return DBVal("hitboxScaleY") or defaults.hitboxScaleY end,
          setValue=function(v)
            DB().hitboxScaleY = v
            ns.RefreshHitboxSize()
          end,
          tooltip="Increases the clickable hitbox height of enemy nameplates. 100% = matches bar height. Increase to make nameplates easier to click." });  y = y - h

    -- Eyeball toggle on Hitbox Size X: translucent overlay on real enemy nameplates marking the clickable area, for visual slider tuning; runtime-only, auto-hides when the panel closes. None in the search pre-build: it indexes nothing, and the row is a stand-in there.
    if not NoxUI._prebuilding then
        local EYE_VISIBLE   = NoxUI.EYE_VISIBLE_ICON
        local EYE_INVISIBLE = NoxUI.EYE_INVISIBLE_ICON
        local leftRgn = hitboxRow._leftRegion
        local eyeBtn = CreateFrame("Button", nil, leftRgn)
        eyeBtn:SetSize(26, 26)
        eyeBtn:SetPoint("RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
        eyeBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
        NoxUI.SetGlyphAlpha(eyeBtn, 0.4)
        leftRgn._lastInline = eyeBtn
        local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
        eyeTex:SetAllPoints()
        local function RefreshEyeIcon()
            eyeTex:SetTexture(ns._hitboxOverlayShown and EYE_INVISIBLE or EYE_VISIBLE)
        end
        RefreshEyeIcon()
        eyeBtn:SetScript("OnClick", function()
            if ns.SetHitboxOverlayShown then ns.SetHitboxOverlayShown(not ns._hitboxOverlayShown) end
            RefreshEyeIcon()
        end)
        eyeBtn:SetScript("OnEnter", function(self)
            NoxUI.SetGlyphAlpha(self, 0.7)
            NoxUI.ShowWidgetTooltip(self, "Show/Hide Hitbox Overlay", { width = 175 })
        end)
        eyeBtn:SetScript("OnLeave", function(self)
            NoxUI.SetGlyphAlpha(self, 0.4)
            NoxUI.HideWidgetTooltip()
        end)
        -- Auto-hide the overlay when the options panel closes (hook once).
        if not ns._hitboxOverlayCloseHook and NoxUI._mainFrame then
            ns._hitboxOverlayCloseHook = true
            NoxUI._mainFrame:HookScript("OnHide", function()
                if ns._hitboxOverlayShown and ns.SetHitboxOverlayShown then
                    ns.SetHitboxOverlayShown(false)
                end
            end)
        end
    end

    -- Stacking Speed | Top Screen Inset: CVars Blizzard restored in 12.1.5,
    -- so each slider exists only on a client that has its CVar. The client
    -- does not save either one across a game restart, so a slider keeps its
    -- value account-wide and the module writes it again at login
    -- (ns.KeepNameplateCVar); nothing is written until a slider moves. Speed
    -- reads as a percent of the client's own default; the inset as a percent
    -- of the screen's height (raw values if the client's default is not a
    -- fraction).
    do
        local function CVarDefault(name) return tonumber(C_CVar.GetCVarDefault(name)) end
        local cvarRows = {}
        if C_CVar.GetCVarInfo("nameplateMotionSpeed") then
            cvarRows[#cvarRows + 1] = { type="slider", text="Stacking Speed",
                min=25, max=400, step=5,
                getValue=function()
                    local def, cur = CVarDefault("nameplateMotionSpeed"), tonumber(GetCVar("nameplateMotionSpeed"))
                    if not (def and def > 0 and cur) then return 100 end
                    return math.floor(cur / def * 100 + 0.5)
                end,
                setValue=function(v)
                    if InCombatLockdown() then return end
                    local def = CVarDefault("nameplateMotionSpeed")
                    if not (def and def > 0) then return end
                    ns.KeepNameplateCVar("nameplateMotionSpeed", def * v / 100)
                end,
                tooltip="How fast stacked nameplates slide into place. 100% is Blizzard's default." }
        end
        if C_CVar.GetCVarInfo("nameplateTopInset") then
            local def = CVarDefault("nameplateTopInset")
            local frac = not def or def <= 1
            cvarRows[#cvarRows + 1] = { type="slider", text="Top Screen Inset",
                min=0, max=frac and 50 or math.max(100, math.ceil((def or 0) * 4)), step=1,
                getValue=function()
                    local cur = tonumber(GetCVar("nameplateTopInset")) or 0
                    if frac then return math.floor(cur * 100 + 0.5) end
                    return cur
                end,
                setValue=function(v)
                    if InCombatLockdown() then return end
                    ns.KeepNameplateCVar("nameplateTopInset", frac and v / 100 or v)
                end,
                tooltip="How far from the top of the screen nameplates stop. 0 lets them reach the edge." }
        end
        for i = 1, #cvarRows, 2 do
            _, h = W:DualRow(parent, y, cvarRows[i], cvarRows[i + 1] or NoxUI.BlankRowCfg());  y = y - h
        end
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h

    -----------------------------------------------------------------------
    --  EXTRA AURA OPTIONS
    -----------------------------------------------------------------------
    _, h = W:SectionHeader(parent, SECTION_AURA, y);  y = y - h

    local maxDbfOriginal = DBVal("maxDebuffs") or defaults.maxDebuffs
    local maxDbfPendingPopup
    local maxDbfCfg =
        { type="slider", text="Max Debuffs", min=1, max=10, step=1,
          getValue=function() return DBVal("maxDebuffs") or defaults.maxDebuffs end,
          setValue=function(v)
            DB().maxDebuffs = v
            -- 12.1 containers raise/lower the group's frame cap live via SetAuraGroupMaxFrameCount inside the reload's cfg pass.
            if ns.NPC_ReloadAll then
                ns.NPC_ReloadAll()
                return
            end
            -- Legacy pools are sized at plate creation: show the reload popup once after the slider drag ends (debounced).
            if v ~= maxDbfOriginal then
                if maxDbfPendingPopup then maxDbfPendingPopup:Cancel() end
                maxDbfPendingPopup = C_Timer.NewTimer(0.5, function()
                    maxDbfPendingPopup = nil
                    if (DB().maxDebuffs or defaults.maxDebuffs) ~= maxDbfOriginal then
                        NoxUI:ShowConfirmPopup({
                            title = "Reload Required",
                            message = "Changing Max Debuffs requires a UI reload to take effect.",
                            confirmText = "Reload Now",
                            cancelText = "Later",
                            reload    = true,
                        })
                    end
                end)
            end
          end,
          tooltip="Maximum number of debuff icons shown on enemy nameplates." }
    local debuffRow1
        debuffRow1, h = W:DualRow(parent, y, maxDbfCfg,
        { type="toggle", text="Show Buff / Debuff Tooltips",
          tooltip="Show the spell tooltip when you hover a buff or debuff icon on a nameplate.\n\nWhile the cursor is over an icon, the plate behind it will not highlight or take mouseover targeting.",
          getValue=function() return DBVal("showAuraTooltips") == true end,
          setValue=function(v)
            DB().showAuraTooltips = v
            if ns.NPC_ReloadAll then ns.NPC_ReloadAll() end
          end });  y = y - h

    local GO = NoxUI.GlowOptions

    -- --- Pandemic Glow -------------------------------------------------
    -- Style with its color swatches and cog, the preview in the right half.
    -- Not on WoW Forever, which has no pandemic window (ns.NP_PANDEMIC_NONE).
    if not ns.NP_PANDEMIC_NONE then
    local panDesc = npPandemicGlowDesc
    local panRow
    panRow, h = W:DualRow(parent, y,
        GO.DropdownSpec(panDesc, "Pandemic Glow Style",
            "Show a glow on your debuffs while they can be refreshed without losing any duration."),
        { type="label", text="Pandemic Glow Preview" });  y = y - h
    GO.AttachInline(panRow._leftRegion, panDesc)

    if not NoxUI._prebuilding then
        -- A pandemic debuff of the player's class (Rip, Moonfire, Festering
        -- Wound, Vampiric Touch / Shadow Word: Pain, Agony, Rupture), any of
        -- them otherwise; the first the client knows from a random start.
        local BY_CLASS = {
            DRUID = { 1079, 8921 }, DEATHKNIGHT = { 194310 }, PRIEST = { 34914, 589 },
            WARLOCK = { 980 }, ROGUE = { 1943 },
        }
        local pool = BY_CLASS[select(2, UnitClass("player"))] or { 1079, 8921, 194310, 34914, 980, 1943 }
        local icon = 136197
        local start = math.random(#pool)
        for i = 0, #pool - 1 do
            local info = C_Spell.GetSpellInfo(pool[(start + i - 1) % #pool + 1])
            if info and info.iconID then icon = info.iconID; break end
        end
        local rightRgn = panRow._rightRegion
        GO.BuildPreview(rightRgn, panDesc, { anchor = rightRgn, point = "RIGHT", relPoint = "RIGHT", x = -20, icon = icon })
        -- The preview's label dims with it while no glow is picked.
        local previewLabel = rightRgn._label
        local function DimPreviewLabel()
            previewLabel:SetAlpha(GO.Renders(panDesc) and 1 or 0.3)
        end
        NoxUI.RegisterWidgetRefresh(DimPreviewLabel)
        DimPreviewLabel()

        -- Apply to all: the CDM pandemic sync (only while that module is loaded).
        if NoxUI.ApplyPandemicGlowToAll then
            NoxUI.BuildSyncIcon({
                region = panRow._leftRegion,
                tooltip = "Apply this pandemic glow to all CDM bars and tracking bars. A surface that can't show a style uses its closest match.",
                isSynced = function()
                    return NoxUI.IsPandemicGlowSyncedToAll(
                        NoxUI.PandemicPayloadFromNameplate(DB()), { skipNameplates = true })
                end,
                onClick = function()
                    NoxUI.ApplyPandemicGlowToAll(
                        NoxUI.PandemicPayloadFromNameplate(DB()), { skipNameplates = true })
                    C_Timer.After(0, function() NoxUI:RefreshPage() end)
                end,
            })
        end
    end
    end -- not NP_PANDEMIC_NONE

    -- --- Dispellable Buff Glow ----------------------------------------
    local dispelDesc = npDispelGlowDesc
    local dispelGlowDropdown = GO.DropdownSpec(dispelDesc, "Dispel Glow Style")
    -- Enemy Buff Filter (replaces the retired Show All Enemy Buffs toggle;
    -- npEnemyBuffFilter, default "important", "showall" on WoW Forever; the
    -- old key is an inert orphan). UNION semantics: Important = important OR
    -- dispellable (two engine groups); Dispellable = dispellable only; Show
    -- All = every buff; the removed "all" value reads back as important.
    -- On retail, the cog's Dispellable By Me narrows "dispellable" in
    -- Important and Dispellable to the group's own dispels.
    -- The Dispel Glow never changes the filters -- it is just the style the
    -- dispellable group wears, so every shown dispellable buff glows when a
    -- style is set.
    local buffFilterDropdown = { type="dropdown", text="Enemy Buff Filter",
        tooltip = "Which enemy buffs show on nameplates. Important shows the buffs Blizzard flags for enemy nameplates plus anything dispellable; Only Dispellable shows just the buffs that can be dispelled, purged or soothed; Show All shows every buff. With a Dispel Glow style set, every dispellable buff shown glows.",
        values = { important = "Important", dispellable = "Only Dispellable", showall = "Show All" },
        order = { "important", "dispellable", "showall" },
        getValue = function()
            local m = DBVal("npEnemyBuffFilter")
            if m == "dispellable" or m == "showall" then return m end
            return "important"
        end,
        setValue = function(v)
            DB().npEnemyBuffFilter = v
            -- Applies live: RefreshAllAuras drives the container reload;
            -- its cfg pass re-drives both buff group filter strings and
            -- parks/unparks the plain remainder group.
            RefreshAllAuras()
            UpdatePreview()
            C_Timer.After(0, function() NoxUI:RefreshPage() end)
        end }
    local dispelGlowRow
    dispelGlowRow, h = W:DualRow(parent, y, buffFilterDropdown, dispelGlowDropdown);  y = y - h

    GO.AttachInline(dispelGlowRow._rightRegion, dispelDesc)

    -- "Dispellable By Me" (retail only, off by default): Important and Only Dispellable count only your group's dispels.
    if not NoxUI.IS_FOREVER then
        NoxUI.BuildInlineCog(dispelGlowRow._leftRegion, {
            disabled = function() return DBVal("npEnemyBuffFilter") == "showall" end,
            disabledTooltip = "Requires Enemy Buff Filter set to Important or Only Dispellable", rawTooltip = true,
            title = "Enemy Buff Filter",
            rows = {
                { type = "toggle", label = "Dispellable By Me",
                  tooltip = "With Important or Only Dispellable, count only the buffs you or your group can dispel, purge or soothe as dispellable, instead of every dispellable buff.",
                  get = function() return DBVal("npEnemyBuffDispelByMe") == true end,
                  set = function(v)
                      DB().npEnemyBuffDispelByMe = v or nil
                      RefreshAllAuras()
                      UpdatePreview()
                  end },
            },
        })
    end

    _, h = W:Spacer(parent, y, 20);  y = y - h

    -----------------------------------------------------------------------
    --  EXTRAS
    -----------------------------------------------------------------------
    _, h = W:SectionHeader(parent, SECTION_MISC, y);  y = y - h

    -- Row 1: Scale Nameplate on Cast | Hide Enemy Name While Casting
    local exCastRow
    exCastRow, h = W:DualRow(parent, y,
        { type="slider", text="Scale Nameplate On Cast",
          trackWidth=110,
          min=50, max=200, step=5,
          getValue=function() return DBVal("castScale") or defaults.castScale end,
          setValue=function(v)
            DB().castScale = v
          end,
          tooltip="Scales enemy nameplates while they are casting. 100% = no change." },
        { type="toggle", text="Hide Enemy Name While Casting",
          tooltip="Hide the enemy name text while that nameplate's cast bar is visible.",
          getValue=function() return DBVal("hideEnemyNameWhileCasting") == true end,
          setValue=function(v)
            DB().hideEnemyNameWhileCasting = v
            ns.RefreshAllSettings()
            UpdatePreview()
          end });  y = y - h
    -- "(Percent)" suffix on the cast scale slider
    if not NoxUI._prebuilding then
        local leftFrame = exCastRow._leftRegion
        if leftFrame then
            local suffixFS = leftFrame:CreateFontString(nil, "OVERLAY")
            suffixFS:SetFont(NoxUI.EXPRESSWAY, 11, GetNPOptOutline())
            suffixFS:SetTextColor(1, 1, 1, 0.35)
            local sliderLabel = SliderLabel(leftFrame, "Scale Nameplate On Cast")
            if sliderLabel then
                suffixFS:SetPoint("LEFT", sliderLabel, "RIGHT", 5, -1)
            else
                suffixFS:SetPoint("LEFT", leftFrame, "LEFT", 180, -1)
            end
            suffixFS:SetText(NoxUI.L("(Percent)"))
        end
    end

    -- Row 2: Name Raid Marker (target marker shown directly before the enemy name; size lives on inline cog) | Experimental: Cast Lockout as CC Icon.
    local nameRaidMarkerRow
    nameRaidMarkerRow, h = W:DualRow(parent, y,
        { type="toggle", text="Name Raid Marker",
          tooltip="Shows the target marker directly before the enemy name text. Uses its own size and does not use the Core Positions raid marker slot.",
          getValue=function() return DBVal("nameRaidMarkerEnabled") == true end,
          setValue=function(v)
            DB().nameRaidMarkerEnabled = v
            ns.RefreshAllSettings()
            UpdatePreview()
            NoxUI:RefreshPage()
          end },
        { type = "toggle", text = "Experimental: Cast Lockout as CC Icon",
          tooltip = "Show successful interrupt lockouts in the crowd-control icon slot.\n\nDue to addon restrictions, the duration shown is a generic 4 seconds for all classes, so it is not 100% accurate.",
          getValue = function() return DBVal("showCastLockoutAsCrowdControl") == true end,
          setValue = function(v)
              DB().showCastLockoutAsCrowdControl = v
              RefreshAllAuras()
          end });  y = y - h

    do
        local function nameRaidMarkerOff() return DBVal("nameRaidMarkerEnabled") ~= true end
        local rgn = nameRaidMarkerRow._leftRegion
        NoxUI.BuildInlineCog(rgn, {
            disabled = nameRaidMarkerOff,
            disabledTooltip = "Name Raid Marker",
            title = "Name Raid Marker",
            rows = {
                { type="slider", label="Size", min=6, max=32, step=1,
                  get=function() return DBVal("nameRaidMarkerSize") or defaults.nameRaidMarkerSize end,
                  set=function(v)
                    DB().nameRaidMarkerSize = v
                    ns.RefreshAllSettings()
                    UpdatePreview()
                  end },
            },
        })
    end

    -- Row 3: Out of Combat Opacity | Line of Sight Opacity
    _, h = W:DualRow(parent, y,
        { type="slider", text="Out of Combat Opacity",
          tooltip="Fades the nameplates of enemies that are not in combat with anyone, such as packs you have not pulled. Your target, and your focus while Keep Focus Full Opacity is on, are never faded by this. Multiplies with Non-Target Opacity. 100 = no fading.",
          min=0, max=100, step=1,
          getValue=function() return DBVal("outOfCombatAlpha") or 100 end,
          setValue=function(v)
            DB().outOfCombatAlpha = v
            if ns.NT_RefreshSetting then ns.NT_RefreshSetting() end
          end },
        -- Line of Sight Opacity: pure CVar passthrough (like Lag Tolerance). Nothing stored in our DB -- getValue reflects the live CVar, setValue only writes on slider move; combat-guarded, mirrors SetCVarSafe.
        { type="slider", text="Line of Sight Opacity",
          tooltip="Nameplates opacity for units that are out of line of sight. 0 = fully transparent, 1 = fully opaque.",
          min=0, max=1, step=0.01,
          getValue=function() return tonumber(GetCVar("nameplateOccludedAlphaMult")) or 0 end,
          setValue=function(v)
            if InCombatLockdown() then return end
            NoxUI.SetCVar("nameplateOccludedAlphaMult", v, "NoxUIBarresNoms")
          end });  y = y - h

    -- Row 4: Range Check (custom cutoff in the inline cog) | Out of Range Opacity
    local rangeCheckRow
    rangeCheckRow, h = W:DualRow(parent, y,
        { type="dropdown", text="Range Check",
          values={ disabled="Disabled", auto="Auto (Class/Spec)", custom="Custom" },
          order={ "disabled", "auto", "custom" },
          tooltip="Disabled runs no nameplate range checks. Auto uses your class and specialization's normal attack range. Custom uses the range set in the cog beside this option.",
          getValue=function() return DBVal("outOfRangeMode") or defaults.outOfRangeMode end,
          setValue=function(v)
            local prev = DBVal("outOfRangeMode") or defaults.outOfRangeMode
            local function ApplyMode(mode)
                DB().outOfRangeMode = mode
                if mode == "custom" and DB().outOfRangeCustomRange == nil then
                    DB().outOfRangeCustomRange = NoxUI.Range_GetAttackCutoff()
                end
                if ns.RangeText_Apply then ns.RangeText_Apply() end
                NoxUI:RefreshPage()
            end
            -- Performance confirm on the disabled -> enabled edge only:
            -- the sweep range-checks every visible nameplate continuously.
            if prev == "disabled" and v ~= "disabled" then
                NoxUI:ShowConfirmPopup({
                    title = "Out of Range Opacity",
                    message = "This feature runs continuous range checks against every visible enemy nameplate. It is one of the more expensive features in NoxUI and can measurably increase CPU usage in crowded areas.",
                    confirmText = "Enable",
                    cancelText = "Cancel",
                    onConfirm = function() ApplyMode(v) end,
                    onCancel = function() NoxUI:RefreshPage() end,
                })
                return
            end
            ApplyMode(v)
          end },
        { type="slider", text="Out of Range Opacity",
          tooltip="Opacity used for enemy nameplates outside the selected attack range.",
          min=0, max=100, step=1,
          disabled=function() return (DBVal("outOfRangeMode") or defaults.outOfRangeMode) == "disabled" end,
          disabledTooltip="Range Check: Auto or Custom",
          getValue=function() return DBVal("outOfRangeAlpha") or defaults.outOfRangeAlpha end,
          setValue=function(v)
            DB().outOfRangeAlpha = v
            if ns.RangeText_Apply then ns.RangeText_Apply() end
          end });  y = y - h

    -- Inline cog on Range Check: the custom cutoff lives here.
    do
        local function customOff()
            return (DBVal("outOfRangeMode") or defaults.outOfRangeMode) ~= "custom"
        end
        local rgn = rangeCheckRow._leftRegion
        NoxUI.BuildInlineCog(rgn, {
            disabled = customOff,
            disabledTooltip = "Range Check: Custom",
            title = "Range Check",
            rows = {
                { type="slider", label="Custom Range", min=5, max=50, step=5,
                  tooltip="Attack-range cutoff used by Out of Range Opacity. Five-yard steps match the available fallback range checks.",
                  disabled=customOff,
                  disabledTooltip="Range Check: Custom",
                  get=function()
                      return DBVal("outOfRangeCustomRange") or NoxUI.Range_GetAttackCutoff()
                  end,
                  set=function(v)
                    DB().outOfRangeCustomRange = v
                    if ns.RangeText_Apply then ns.RangeText_Apply() end
                  end },
            },
        })
    end

    -- Row 5: Execute Pulse Glow | Hide Enemy Nameplates out of Combat
    _, h = W:DualRow(parent, y,
        { type="toggle", text="Execute Pulse Glow",
          tooltip="Pulses a red glow on enemy nameplates below 30% health.",
          getValue=function() return DBVal("lowHpGlow") == true end,
          setValue=function(v)
            DB().lowHpGlow = v
            ns.RefreshAllSettings()
          end },
        { type="toggle", text="Hide Enemy Nameplates out of Combat",
          tooltip="Hide enemy nameplates while you are out of combat; they return the moment combat starts. Drives the same game setting as the Show Enemy Name Plates keybind.",
          getValue=function() return DBVal("hideEnemyPlatesOOC") == true end,
          setValue=function(v)
            DB().hideEnemyPlatesOOC = v
            if ns.ApplyOOCPlates then ns.ApplyOOCPlates() end
          end });  y = y - h

    -- Row 6: Minor Enemy Scale | Non-Elite Enemy Scale. Global Search also finds
    -- both by the section and the row they are known under.
    local function TypeScaleCfg(label, key, tip)
        SearchWords(label, SECTION_MISC, tip, "TARGET AND FOCUS EFFECTS", "Scale Target Nameplate")
        return { type="slider", text=label, tooltip=tip, trackWidth=110, min=25, max=125, step=5,
            getValue=function() return DBVal(key) or defaults[key] end,
            setValue=function(v)
                DB()[key] = v
                if ns.NP_RefreshTypeScaleSetting then ns.NP_RefreshTypeScaleSetting() end
            end }
    end
    _, h = W:DualRow(parent, y,
        TypeScaleCfg("Minor Enemy Scale (Percent)", "minorEnemyScale",
            "Scales the nameplates of minor and trivial enemies; 100% = no change."),
        TypeScaleCfg("Non-Elite Enemy Scale (Percent)", "nonEliteEnemyScale",
            "Scales the nameplates of non-elite enemies in dungeons only; 100% = no change."));  y = y - h

    -- Row 7: Show Enemy Pet Nameplates | the class option, if any. Hide Copies
    -- of Blood Plague (Blood Death Knight only) and Show Sunder Armor (WoW Forever
    -- warriors only) are not built at all for anyone else -- each only affects
    -- that class's debuff.
    local classCfg
    do
        local _, classFile = UnitClass("player")
        local specIdx = C_SpecializationInfo.GetSpecialization()
        local specID = specIdx and C_SpecializationInfo.GetSpecializationInfo(specIdx)
        if classFile == "DEATHKNIGHT" and specID == 250 then
            classCfg = { type="toggle", text="Hide Copies of Blood Plague",
                  tooltip="Shows a single Blood Plague debuff on enemy nameplates instead of one per copy (Blood Boil from weapon copies).",
                  getValue=function() return DBVal("hideBloodPlagueCopies") ~= false end,
                  setValue=function(v)
                    DB().hideBloodPlagueCopies = v
                    if ns.NPC_ReloadAll then ns.NPC_ReloadAll() end
                  end }
        elseif NoxUI.IS_FOREVER and classFile == "WARRIOR" then
            classCfg = { type="toggle", text="Show Sunder Armor",
                  tooltip="Shows Sunder Armor and its stacks on enemy nameplates, including stacks applied by other warriors.",
                  getValue=function() return DBVal("showSunderArmor") == true end,
                  setValue=function(v)
                    DB().showSunderArmor = v
                    if ns.NPC_ReloadAll then ns.NPC_ReloadAll() end
                  end }
        end
    end
    local petsCfg =
        { type="toggle", text="Show Enemy Pet Nameplates",
          getValue=function() return DBVal("showEnemyPets") == true end,
          setValue=function(v)
            DB().showEnemyPets = v
            pcall(NoxUI.SetCVar, "nameplateShowEnemyPets", v and 1 or 0, "NoxUIBarresNoms")
          end,
          tooltip="Toggle visibility of enemy pet nameplates." }
    -- (also found by the section name it is known under)
    SearchWords(petsCfg.text, SECTION_MISC, petsCfg.tooltip, "OTHER NAMEPLATES")
    _, h = W:DualRow(parent, y, petsCfg, classCfg or NoxUI.BlankRowCfg());  y = y - h

    return math.abs(y)
end

-- Used by nui_plaques_noms_options.lua
ns.NPO_BuildGeneralPage = BuildGeneralPage
