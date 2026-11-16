if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_confort_jeu_transformation_options.lua
--  Builds the "Shifter" page inside the Quality of Life module.
-------------------------------------------------------------------------------

-- "CharacterFrame" -> "Character", "AuctionHouseFrame" -> "Auction House", etc.
if not NoxUI._ModuleNS["NoxUIConfortJeu"] then return end  -- module disabled: no options page

-- Page reuse: frames this file builds go through the options frame pool
-- (NoxUI_FramePool.lua), which hands a kept page its previous build's
-- frames back reset to new; on any other parent it is the plain CreateFrame.
local CreateFrame = NoxUI._Pool.CreateFrame

local function PrettifyName(name)
    local pretty = name:gsub("Frame$", "")
    pretty = pretty:gsub("(%l)(%u)", "%1 %2")
                    :gsub("(%u)(%u%l)", "%1 %2")
    return pretty
end

_G._EUI_BuildShifterPage = function(pageName, parent, yOffset)
    local W = NoxUI.Widgets
    local y = yOffset
    local _, h, hdr

    -- Info text (top of page, matching bags pattern)
    do
        local fontPath = (NoxUI.GetFontPath())
            or "Fonts\\FRIZQT__.TTF"
        local infoFrame = CreateFrame("Frame", nil, parent)
        infoFrame:SetSize(parent:GetWidth(), 34)
        infoFrame:SetPoint("TOP", parent, "TOP", 0, y - 10)
        infoFrame._isSpacer = true
        local line1 = infoFrame:CreateFontString(nil, "OVERLAY")
        line1:SetFont(fontPath, 15, "")
        line1:SetTextColor(1, 1, 1, 0.75)
        line1:SetPoint("TOP", infoFrame, "TOP", 0, 0)
        line1:SetJustifyH("CENTER")
        line1:SetText(NoxUI.L("Shift + Left-Click Drag to permanently save a panel's position."))
        local line2 = infoFrame:CreateFontString(nil, "OVERLAY")
        line2:SetFont(fontPath, 15, "")
        line2:SetTextColor(1, 1, 1, 0.75)
        line2:SetPoint("TOP", line1, "BOTTOM", 0, -2)
        line2:SetJustifyH("CENTER")
        line2:SetText(NoxUI.L("Ctrl + Left-Click Drag for a temporary move that resets when the panel closes."))
        local line3 = infoFrame:CreateFontString(nil, "OVERLAY")
        line3:SetFont(fontPath, 15, "")
        line3:SetTextColor(1, 1, 1, 0.75)
        line3:SetPoint("TOP", line2, "BOTTOM", 0, -2)
        line3:SetJustifyH("CENTER")
        line3:SetText(NoxUI.L("Shift + Scroll to permanently zoom a panel. Ctrl + Scroll for a temporary zoom."))
        y = y - 70
    end

    -- Reset All button
    _, h = W:WideButton(parent, "Reset All Positions & Zoom", y,
        function()
            NoxUI:ShowConfirmPopup({
                title   = "Reset Shifter Positions & Zoom",
                message = "This will reset all saved panel positions and zoom levels and reload your UI.",
                confirmText = "Reset",
                cancelText  = "Cancel",
                reload = true,
                onConfirm = function()
                    if NoxUI._ResetShifterPositions then
                        NoxUI._ResetShifterPositions()
                    end
                end,
            })
        end
    );  y = y - h

    ---------------------------------------------------------------------------
    --  SHIFTER
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "SHIFTER", y);  y = y - h

    parent._showRowDivider = true

    -- Build dropdown values for Reset Specific Window (any window with a
    -- saved position OR a saved zoom)
    local ddValues = { [""] = "Choose Window..." }
    local ddOrder  = {}
    do
        local seen = {}
        local function collect(tbl)
            if not tbl then return end
            for name in pairs(tbl) do
                if not seen[name] then
                    seen[name] = true
                    ddValues[name] = PrettifyName(name)
                    ddOrder[#ddOrder + 1] = name
                end
            end
        end
        collect(NoxUIDB and NoxUIDB.shifterPositions)
        collect(NoxUIDB and NoxUIDB.shifterScales)
        table.sort(ddOrder, function(a, b)
            return ddValues[a] < ddValues[b]
        end)
    end

    -- Row 1: Enable Shifter | Reset Specific Window
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable Shifter",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterEnabled or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterEnabled = v
              if v and NoxUI._InitShifter then
                  NoxUI._InitShifter()
              elseif not v and NoxUI._ShutdownShifter then
                  NoxUI._ShutdownShifter()
              end
          end },
        { type = "dropdown", text = "Reset Specific Window",
          values = ddValues,
          order  = ddOrder,
          getValue = function() return "" end,
          setValue = function(frameName)
              if frameName == "" then return end
              local pretty = ddValues[frameName] or PrettifyName(frameName)
              NoxUI:ShowConfirmPopup({
                  title   = "Reset Window Position & Zoom",
                  message = NoxUI.Lf("Reset %1$s to its default position and zoom and reload your UI?", pretty),
                  confirmText = "Reset",
                  cancelText  = "Cancel",
                  reload = true,
                  onConfirm = function()
                      if NoxUIDB and NoxUIDB.shifterPositions then
                          NoxUIDB.shifterPositions[frameName] = nil
                      end
                      if NoxUIDB and NoxUIDB.shifterScales then
                          NoxUIDB.shifterScales[frameName] = nil
                      end
                  end,
              })
          end }
    );  y = y - h

    -- Row 2: Move windows without shift
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Move Windows Without Shift",
          tooltip = "When enabled, left-click dragging a window will save its position without needing to hold Shift. Ctrl+drag still does a temporary move.",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterNoShift or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterNoShift = v
          end },
        { type = "label", text = "" }
    );  y = y - h

    ---------------------------------------------------------------------------
    --  LOOT WINDOWS
    ---------------------------------------------------------------------------
    hdr, h = W:SectionHeader(parent, "LOOT WINDOWS", y);  y = y - h

    local function lootUnlockOff()
        return not (NoxUIDB and NoxUIDB.shifterLootUnlock)
    end
    -- One toggle adds all three loot movers, so the button takes the first.
    NoxUI.BuildSectionUnlockJump(hdr, { key = "EUI_BonusRoll", disabled = lootUnlockOff, disabledTooltip = "Move Loot Windows in Unlock Mode" })

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Move Loot Windows in Unlock Mode",
          tooltip = "Adds Bonus Roll, Group Loot, and Alert Toast movers to Unlock Mode.",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterLootUnlock or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterLootUnlock = v
              if v then
                  if NoxUI._InitShifterLootWindows then
                      NoxUI._InitShifterLootWindows()
                  end
              else
                  if NoxUI._DisableShifterLootWindows then
                      NoxUI._DisableShifterLootWindows()
                  end
              end
              NoxUI:RefreshPage()  -- update the overlay toggle disabled state
          end },
        { type = "toggle", text = "Hide Unlock Mode Overlays",
          tooltip = "Hides the loot window movers in Unlock Mode while keeping their saved positions applied.",
          disabled = lootUnlockOff, disabledTooltip = "Move Loot Windows in Unlock Mode",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterLootHideOverlays or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterLootHideOverlays = v
          end }
    );  y = y - h

    ---------------------------------------------------------------------------
    --  BLIZZARD TOP BAR EVENT TEXT
    ---------------------------------------------------------------------------
    hdr, h = W:SectionHeader(parent, "BLIZZARD TOP BAR EVENT TEXT", y);  y = y - h

    local function topBarUnlockOff()
        return not (NoxUIDB and NoxUIDB.shifterTopBarUnlock)
    end
    NoxUI.BuildSectionUnlockJump(hdr, { key = "EUI_TopBarEventText", disabled = topBarUnlockOff, disabledTooltip = "Move Top Bar Event Text in Unlock Mode" })

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Move Top Bar Event Text in Unlock Mode",
          tooltip = "Adds a mover for Blizzard's top-center event text and widgets (scenario, event, and encounter bars).",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterTopBarUnlock or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterTopBarUnlock = v
              if v then
                  if NoxUI._InitShifterTopBar then
                      NoxUI._InitShifterTopBar()
                  end
              else
                  if NoxUI._DisableShifterTopBar then
                      NoxUI._DisableShifterTopBar()
                  end
              end
              NoxUI:RefreshPage()  -- update the overlay toggle disabled state
          end },
        { type = "toggle", text = "Hide Unlock Mode Overlay",
          tooltip = "Hides the Top Bar Event Text mover in Unlock Mode while keeping its saved position applied.",
          disabled = topBarUnlockOff, disabledTooltip = "Move Top Bar Event Text in Unlock Mode",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterTopBarHideOverlay or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterTopBarHideOverlay = v
          end }
    );  y = y - h

    ---------------------------------------------------------------------------
    --  BATTLEGROUND FRAMES
    ---------------------------------------------------------------------------
    hdr, h = W:SectionHeader(parent, "BATTLEGROUND FRAMES", y);  y = y - h

    local function battlegroundUnlockOff()
        return not (NoxUIDB and NoxUIDB.shifterBattlegroundUnlock)
    end
    -- One toggle adds both battleground movers, so the button takes the flag carriers'.
    NoxUI.BuildSectionUnlockJump(hdr, { key = "EUI_FlagCarriers", disabled = battlegroundUnlockOff, disabledTooltip = "Move Battleground Frames in Unlock Mode" })

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Move Battleground Frames in Unlock Mode",
          tooltip = "Adds movers for the battleground flag carriers and the capture bar to Unlock Mode.",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterBattlegroundUnlock or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterBattlegroundUnlock = v
              if NoxUI._InitShifterLootWindows then
                  NoxUI._InitShifterLootWindows()
              end
              if NoxUI._SyncShifterCarriers then
                  NoxUI._SyncShifterCarriers()
              end
              NoxUI:RefreshPage()  -- update the overlay toggle disabled state
          end },
        { type = "toggle", text = "Hide Unlock Mode Overlays",
          tooltip = "Hides the battleground frame movers in Unlock Mode while keeping their saved positions applied.",
          disabled = battlegroundUnlockOff, disabledTooltip = "Move Battleground Frames in Unlock Mode",
          getValue = function()
              return NoxUIDB and NoxUIDB.shifterBattlegroundHideOverlays or false
          end,
          setValue = function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.shifterBattlegroundHideOverlays = v
          end }
    );  y = y - h

    return math.abs(y)
end
