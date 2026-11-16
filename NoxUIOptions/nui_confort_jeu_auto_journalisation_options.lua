if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_confort_jeu_auto_journalisation_options.lua
--  Options page for the Auto Combat Logging feature.
-------------------------------------------------------------------------------

-- Must match TRIGGER_DEFAULTS in the runtime.
if not NoxUI._ModuleNS["NoxUIConfortJeu"] then return end  -- module disabled: no options page

local TRIGGER_DEFAULTS = {
    logMythic   = true,
    logHeroic   = true,
    logNormal   = true,
    logLFR      = true,
    log5pp      = true,
    logArena    = true,
    logScenario = false,
    logRBG      = false,
    logBlitz    = false,
    delaystop   = true,
}

local TRIGGER_ITEMS = {
    { key = "logMythic",   label = "Mythic Raid" },
    { key = "logHeroic",   label = "Heroic Raid" },
    { key = "logNormal",   label = "Normal Raid" },
    { key = "logLFR",      label = "LFR" },
    { key = "log5pp",      label = "Mythic+ Dungeons" },
    { key = "logArena",    label = "Arena" },
    { key = "logScenario", label = "Scenarios" },
    { key = "logRBG",      label = "Rated Battlegrounds" },
    { key = "logBlitz",    label = "Battleground Blitz" },
}
-- WoW Forever: every raid instance logs on the Raids trigger (the Normal Raid
-- key and its default) and every dungeon on the Dungeons trigger (a key only
-- that client offers, off until the player turns it on). The retail
-- difficulty, Mythic+, arena, scenario and rated battleground rows have
-- nothing to match there.
if NoxUI.IS_FOREVER then
    TRIGGER_ITEMS = {
        { key = "logNormal",  label = "Raids" },
        { key = "logDungeon", label = "Dungeons" },
    }
end

local function Cfg()
    if not NoxUIDB then return {} end
    NoxUIDB.autoLogging = NoxUIDB.autoLogging or {}
    return NoxUIDB.autoLogging
end

local function Recheck()
    if _G._EUI_AutoLogging_Check then _G._EUI_AutoLogging_Check() end
end

local function KeysCfg()
    if not NoxUIDB then return {} end
    NoxUIDB.keystonePopup = NoxUIDB.keystonePopup or {}
    return NoxUIDB.keystonePopup
end

local function TeleCfg()
    if not NoxUIDB then return {} end
    NoxUIDB.teleportPrompt = NoxUIDB.teleportPrompt or {}
    return NoxUIDB.teleportPrompt
end

-- Read-only: the /way table appears on the first write, so viewing the page
-- saves nothing.
local NO_WAY_CFG = {}
local function WayCfg()
    return NoxUIDB and NoxUIDB.waypointCmd or NO_WAY_CFG
end

local function SetWay(key, value)
    if not NoxUIDB then return end
    NoxUIDB.waypointCmd = NoxUIDB.waypointCmd or {}
    NoxUIDB.waypointCmd[key] = value
end

-- Built as the tail of the Quality of Life page (chained from BuildQoLPage),
-- not as its own tab. Lays out from yOffset and returns the height used,
-- like every other section builder.
local function BuildAutoLoggingPage(pageName, parent, yOffset)
    local W  = NoxUI.Widgets
    local PP = NoxUI.PanelPP
    local y  = yOffset
    local _, h

    parent._showRowDivider = true

    ---------------------------------------------------------------------------
    --  KEYSTONE CHECK POPUP (no keystones on WoW Forever: the section and the
    --  /keys file behind it do not exist there)
    ---------------------------------------------------------------------------
    if not NoxUI.IS_FOREVER then
    _, h = W:SectionHeader(parent, "KEYSTONE CHECK POPUP", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Enable /keys Popup (or /ekeys)",
          tooltip = "Shows a popup with party and guild keystones when typing /keys.",
          -- DependentSetValue: the Window Scale row below is hidden while the
          -- popup is off; the flip forces the full rebuild.
          setValue = NoxUI.DependentSetValue(
              function() return KeysCfg().enabled ~= false end,
              function(v)
                  KeysCfg().enabled = v
                  NoxUI:RefreshPage()
                  NoxUI:ShowConfirmPopup({
                      title = "Reload Required",
                      message = "Changing the /keys popup requires a reload to update slash command registration.",
                      confirmText = "Reload",
                      cancelText = "Later",
                      reload    = true,
                  })
              end),
          getValue = function() return KeysCfg().enabled ~= false end },
        { type    = "slider",
          text    = "Text Size",
          min     = 8, max = 16, step = 1,
          disabled = function() return KeysCfg().enabled == false end,
          disabledTooltip = "/keys Popup",
          tooltip = "Font size for keystone entries in the popup (does not affect the header).",
          getValue = function() return KeysCfg().textSize or 11 end,
          setValue = function(v)
              KeysCfg().textSize = v
              if _G._EUI_RefreshKeystonePopup then _G._EUI_RefreshKeystonePopup() end
          end }
    ); y = y - h

    -- Window Scale row: HIDDEN entirely while the /keys popup is off.
    if KeysCfg().enabled ~= false then
    _, h = W:DualRow(parent, y,
        { type    = "slider",
          text    = "Window Scale",
          min     = 50, max = 150, step = 5,
          tooltip = "Scale of the /keys popup window.",
          getValue = function() return math.floor((KeysCfg().scale or 1.05) * 100 + 0.5) end,
          setValue = function(v)
              KeysCfg().scale = v / 100
              local popup = _G.EUIKeysPopup
              if popup then popup:SetScale(v / 100) end
          end },
        { type = "label", text = "" }
    ); y = y - h
    end   -- close /keys popup hidden-while-disabled gate

    _, h = W:Spacer(parent, y, 20); y = y - h
    end -- not IS_FOREVER

    ---------------------------------------------------------------------------
    --  LFG REMINDER (no dungeon teleports on WoW Forever: the section and the
    --  reminder runtime behind it do not exist there)
    ---------------------------------------------------------------------------
    if not NoxUI.IS_FOREVER then
    _, h = W:SectionHeader(parent, "LFG REMINDER", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Enable LFG Reminder",
          tooltip = "When you join a Group Finder group for a dungeon that has a teleport, shows a small movable popup with the dungeon name and a one-click teleport button. It hides when you enter the dungeon, leave the group, or enter combat.",
          getValue = function() return TeleCfg().enabled ~= false end,
          -- DependentSetValue: the Show 'Disable Feature' Text row below is
          -- hidden while the reminder is off; the flip forces the rebuild.
          setValue = NoxUI.DependentSetValue(
              function() return TeleCfg().enabled ~= false end,
              function(v)
                  TeleCfg().enabled = v
                  NoxUI:RefreshPage()
                  -- Applies live in both directions: enable builds the popup and
                  -- registers events, disable hides and unregisters.
                  if _G._EUI_ApplyTeleportPrompt then _G._EUI_ApplyTeleportPrompt() end
              end) },
        { type    = "slider",
          text    = "Window Scale",
          min     = 50, max = 150, step = 5,
          disabled = function() return TeleCfg().enabled == false end,
          disabledTooltip = "LFG Reminder",
          tooltip = "Scale of the LFG Reminder popup window.",
          getValue = function() return math.floor((TeleCfg().scale or 1.05) * 100 + 0.5) end,
          setValue = function(v)
              TeleCfg().scale = v / 100
              if _G._EUI_RefreshTeleportPrompt then _G._EUI_RefreshTeleportPrompt() end
          end }
    ); y = y - h

    -- Show 'Disable Feature' Text row: HIDDEN while the reminder is off.
    if TeleCfg().enabled ~= false then
    _, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Show 'Disable Feature' Text",
          tooltip = "Shows the 'Disable Feature' text below the teleport button. When off, the text is hidden and the window is 20px shorter.",
          getValue = function() return TeleCfg().showDisable ~= false end,
          setValue = function(v)
              TeleCfg().showDisable = v
              if _G._EUI_RefreshTeleportPrompt then _G._EUI_RefreshTeleportPrompt() end
          end },
        { type = "label", text = "" }
    ); y = y - h
    end   -- close LFG Reminder hidden-while-disabled gate

    _, h = W:Spacer(parent, y, 20); y = y - h
    end -- not IS_FOREVER

    ---------------------------------------------------------------------------
    --  WAYPOINT COMMAND (/way, runtime in NoxUIConfortJeu_Waypoint.lua)
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "WAYPOINT COMMAND", y); y = y - h

    local wayRow
    wayRow, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Enable /way Command",
          tooltip = "Adds /way, which prints a map pin link.",
          -- Off by default.
          getValue = function() return WayCfg().enabled == true end,
          setValue = function(v)
              SetWay("enabled", v or nil)
              NoxUI:RefreshPage()
              NoxUI:ShowConfirmPopup({
                  title = "Reload Required",
                  message = "Changing the /way command requires a reload to update slash command registration.",
                  confirmText = "Reload",
                  cancelText = "Later",
                  reload    = true,
              })
          end },
        { type    = "toggle",
          text    = "Enable /euipaste Command",
          tooltip = "Adds /euipaste (and /paste when no other addon uses it): paste a list of /way or /euiway waypoint lines and run them at once. Other lines are skipped.",
          getValue = function() return NoxUIDB and NoxUIDB.pasteCommands == true end,
          setValue = function(v)
              if not NoxUIDB then return end
              NoxUIDB.pasteCommands = v or nil
              NoxUI:RefreshPage()
              NoxUI:ShowConfirmPopup({
                  title = "Reload Required",
                  message = "Changing the /euipaste command requires a reload to update slash command registration.",
                  confirmText = "Reload",
                  cancelText = "Later",
                  reload    = true,
              })
          end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type    = "labeledButton",
          text    = "Action Bar Macro",
          buttonText = "Create Macro",
          width   = 130,
          tooltip = "Creates an account macro named EUI_Paste that opens the waypoint paste window and puts it on your cursor. Click an action bar slot to place it.",
          -- The runtime exists only after a reload with the command enabled.
          disabled = function() return not NoxUI._createPasteMacro end,
          disabledTooltip = "Enable /euipaste Command",
          onClick = function()
              if NoxUI._createPasteMacro then NoxUI._createPasteMacro() end
          end },
        NoxUI.BlankRowCfg()
    ); y = y - h

    -- The arrival message for hand-placed pins (off by default). The runtime
    -- reads it live and listens for arrivals only while it or a /way list
    -- needs them, so a change re-syncs that listener.
    NoxUI.BuildInlineCog(wayRow._leftRegion, {
        title = "/way Command",
        disabled = function() return WayCfg().enabled ~= true end,
        disabledTooltip = "Enable /way Command",
        rows = {
            { type="toggle", label="Hand-Placed Pin Arrival",
              tooltip="Also announces arrival at pins you place.",
              get=function() return WayCfg().manualArrival == true end,
              set=function(v)
                  SetWay("manualArrival", v or nil)
                  local sync = NoxUI._ModuleNS["NoxUIConfortJeu"].WaypointArrivalSync
                  if sync then sync() end
              end },
        },
    })

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  AUTO COMBAT LOGGING
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "AUTO COMBAT LOGGING", y); y = y - h

    local trigRow, trigH = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Enable Auto Logging",
          tooltip = "Automatically starts and stops combat logging when entering or leaving a loggable instance.",
          getValue = function() return Cfg().enabled == true end,
          -- DependentSetValue: the Warcraft Recorder row below is hidden
          -- while auto logging is off; the flip forces the full rebuild.
          setValue = NoxUI.DependentSetValue(
              function() return Cfg().enabled == true end,
              function(v)
                  Cfg().enabled = v or nil
                  Recheck()
                  NoxUI:RefreshPage()
              end) },
        { type    = "dropdown", text = "Auto-Log Triggers",
          values  = { __placeholder = "..." }, order = { "__placeholder" },
          getValue = function() return "__placeholder" end,
          setValue = function() end }
    ); y = y - trigH

    -- Replace dummy dropdown with a checkbox dropdown.
    do
        local rightRgn = trigRow._rightRegion
        if rightRgn._control then rightRgn._control:Hide() end

        local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
            rightRgn,
            210,
            rightRgn:GetFrameLevel() + 2,
            TRIGGER_ITEMS,
            function(k)
                local v = Cfg()[k]
                if v == nil then return TRIGGER_DEFAULTS[k] end
                return v
            end,
            function(k, v) Cfg()[k] = v; Recheck() end
        )
        PP.Point(cbDD, "RIGHT", rightRgn, "RIGHT", -20, 0)
        rightRgn._control = cbDD
        rightRgn._lastInline = nil

        NoxUI.RegisterWidgetRefresh(cbDDRefresh)

        -- Gray + block the triggers dropdown (and its label) while Auto
        -- Logging is off; the CB dropdown has no native disabled handling.
        local function UpdateTrigDisabled()
            local off = Cfg().enabled ~= true
            cbDD:SetAlpha(off and 0.3 or 1)
            cbDD:EnableMouse(not off)
            if rightRgn._label then rightRgn._label:SetAlpha(off and 0.3 or 1) end
        end
        UpdateTrigDisabled()
        NoxUI.RegisterWidgetRefresh(UpdateTrigDisabled)
    end

    -- Warcraft Recorder row: HIDDEN entirely while Auto Logging is off.
    if Cfg().enabled == true then
    _, h = W:DualRow(parent, y,
        { type    = "toggle",
          text    = "Warcraft Recorder Compatibility",
          tooltip = "Delays stopping combat logging by 30 seconds after leaving an instance. Recommended for Warcraft Recorder compatibility.",
          getValue = function()
              local v = Cfg().delaystop
              if v == nil then return TRIGGER_DEFAULTS.delaystop end
              return v
          end,
          setValue = function(v)
              Cfg().delaystop = v
          end },
        { type    = "toggle",
          text    = "Chat Notification",
          tooltip = "Prints a chat message when auto logging starts or stops.",
          getValue = function() return Cfg().notify == true end,
          setValue = function(v)
              Cfg().notify = v or nil
          end }
    ); y = y - h
    end   -- close Auto Logging hidden-while-disabled gate

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  ALERTS (Combat Alert, Potion Ready, Unspent Talents; one shared anchor)
    ---------------------------------------------------------------------------
    if _G._EUI_BuildAlertsSection then
        local alertsH = _G._EUI_BuildAlertsSection(parent, y, W, NoxUI.PP)
        y = y - alertsH
    end

    ---------------------------------------------------------------------------
    --  BATTLE RES (no shared battle res charges on WoW Forever: the indicator
    --  runtime builds nothing there and the section is not built)
    ---------------------------------------------------------------------------
    if _G._EUI_BuildBattleResSection and not NoxUI.IS_FOREVER then
        local brezH = _G._EUI_BuildBattleResSection(parent, y, W, NoxUI.PanelPP)
        y = y - brezH
    end

    ---------------------------------------------------------------------------
    --  BLOODLUST TRACKER (no raid-wide lust on WoW Forever: the tracker
    --  runtime returns at load there and the section is not built)
    ---------------------------------------------------------------------------
    if _G._EUI_BuildBloodlustSection and not NoxUI.IS_FOREVER then
        local lustH = _G._EUI_BuildBloodlustSection(parent, y, W, NoxUI.PanelPP)
        y = y - lustH
    end

    return math.abs(y - yOffset)
end

_G._EUI_BuildAutoLoggingPage = BuildAutoLoggingPage
