if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_confort_jeu_alertes_options.lua
--  ALERTS section: Combat Alert, Potion Ready Alert, Unspent Talents Alert and
--  Announce Group Deaths. The first three share one movable anchor (Unlock Mode:
--  Alerts) and have their own text, size and color; their runtime is
--  NoxUIConfortJeu_Alerts.lua. Group Deaths keeps its own overlay (NoxUIConfortJeu.lua).
-------------------------------------------------------------------------------

if not NoxUI._ModuleNS["NoxUIConfortJeu"] then return end  -- module disabled: no options page

-- Text, size, color and class-color rows for the Potion / Talent alerts
-- (keys: <prefix>Text / TextSize / Color / UseClassColor; defaults come from
-- the alert itself so the swatch always shows the real default).
local function AlertCogRows(prefix, applyFrame, preview)
    local D = (NoxUI.Alerts and NoxUI.Alerts.DEFAULTS[prefix])
        or { text = "", color = { r = 1, g = 1, b = 1 } }
    local function db(k) return NoxUIDB and NoxUIDB[prefix .. k] end
    local function put(k, v)
        if not NoxUIDB then NoxUIDB = {} end
        NoxUIDB[prefix .. k] = v
    end
    return {
        { type="input", label="Text", inputWidth=130,
          get=function() return db("Text") or D.text end,
          set=function(v) put("Text", v); if NoxUI[preview] then NoxUI[preview]() end end },
        { type="slider", label="Text Size", min=14, max=64, step=1,
          get=function() return db("TextSize") or 22 end,
          set=function(v)
            put("TextSize", v)
            if NoxUI[applyFrame] then NoxUI[applyFrame]() end
            if NoxUI[preview] then NoxUI[preview]() end
          end },
        { type="colorpicker", label="Color",
          disabled=function() return db("UseClassColor") end,
          disabledTooltip="Disable Class Color to pick a custom color.", rawTooltip=true,
          get=function()
            local c = db("Color") or D.color
            return c.r, c.g, c.b
          end,
          set=function(r, g, b)
            put("Color", { r=r, g=g, b=b })
            if NoxUI[preview] then NoxUI[preview]() end
          end },
        { type="toggle", label="Class Color",
          get=function() return db("UseClassColor") end,
          set=function(v) put("UseClassColor", v); if NoxUI[preview] then NoxUI[preview]() end end },
    }
end

_G._EUI_BuildAlertsSection = function(parent, yOffset, W, PP)
    local y = yOffset
    local _, h, hdr

    hdr, h = W:SectionHeader(parent, "ALERTS", y); y = y - h
    -- One anchor carries the Combat, Potion Ready and Unspent Talents alerts,
    -- each with its own enable, so the button has no single requirement.
    NoxUI.BuildSectionUnlockJump(hdr, { key = "EUI_CombatAlert" })

    local row1
    row1, h = W:DualRow(parent, y,
        { type="toggle", text="Combat Alert",
          tooltip="Shows a large on-screen text when you enter and/or leave combat (e.g. \"+Combat\" / \"-Combat\"). Use the cog to set the display text, size, colors and which transitions are shown; use Unlock Mode to reposition the alert.",
          getValue=function()
              return NoxUIDB and NoxUIDB.combatAlertEnabled or false
          end,
          setValue=function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.combatAlertEnabled = v
              if NoxUI._applyCombatAlert then NoxUI._applyCombatAlert() end
              NoxUI:RefreshPage()
          end },
        { type="toggle", text="Potion Ready Alert",
          tooltip="Shows on-screen text when a potion you used is off cooldown again. Use the cog to set the text, size and color; use Unlock Mode to reposition the alerts.",
          getValue=function()
              return NoxUIDB and NoxUIDB.potionAlertEnabled or false
          end,
          setValue=function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.potionAlertEnabled = v
              if NoxUI._applyPotionAlert then NoxUI._applyPotionAlert() end
              NoxUI:RefreshPage()
          end }
    );  y = y - h

    local row2
    row2, h = W:DualRow(parent, y,
        { type="toggle", text="Unspent Talents Alert",
          tooltip="Shows on-screen text while you have unspent talent points. It stays up until you spend them or open your talents, and returns after a level-up. Use the cog to set the text, size and color; use Unlock Mode to reposition the alerts.",
          getValue=function()
              return NoxUIDB and NoxUIDB.talentAlertEnabled or false
          end,
          setValue=function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.talentAlertEnabled = v
              if NoxUI._applyTalentAlert then NoxUI._applyTalentAlert() end
              NoxUI:RefreshPage()
          end },
        { type="toggle", text="Announce Group Deaths",
          tooltip="Shows a large on-screen alert (e.g. \"Player DIED!\") whenever a party or raid member dies, so you immediately notice deaths during dungeons and raids. Use Unlock Mode to reposition the alert.",
          getValue=function()
              return NoxUIDB and NoxUIDB.announceGroupDeaths or false
          end,
          setValue=function(v)
              if not NoxUIDB then NoxUIDB = {} end
              NoxUIDB.announceGroupDeaths = v
              if NoxUI._applyAnnounceGroupDeaths then NoxUI._applyAnnounceGroupDeaths() end
              NoxUI:RefreshPage()
          end }
    );  y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Annonce de changement de zone",
          tooltip="Affiche le nom de la nouvelle zone dans les alertes NoxUI. Les annonces du jeu restent actives.",
          getValue=function() return NoxUIDB and NoxUIDB.noxZoneAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxZoneAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end },
        { type="toggle", text="Annonce de passage de niveau",
          tooltip="Affiche le nouveau niveau dans les alertes NoxUI. Les annonces du jeu restent actives.",
          getValue=function() return NoxUIDB and NoxUIDB.noxLevelAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxLevelAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Annonce de haut fait",
          tooltip="Affiche le nom du haut fait dans les alertes NoxUI. Les annonces du jeu restent actives.",
          getValue=function() return NoxUIDB and NoxUIDB.noxAchievementAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxAchievementAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end }, nil
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Annonce de quête terminée",
          tooltip="Affiche une alerte lorsqu'une quête est rendue. Les annonces du jeu restent actives.",
          getValue=function() return NoxUIDB and NoxUIDB.noxQuestAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxQuestAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end },
        { type="toggle", text="Messages des boss",
          tooltip="Affiche les messages de boss dans les alertes NoxUI. Les messages du jeu restent actifs.",
          getValue=function() return NoxUIDB and NoxUIDB.noxBossAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxBossAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Annonce de quête acceptée",
          tooltip="Affiche une alerte lorsqu'une quête est acceptée. Les annonces du jeu restent actives.",
          getValue=function() return NoxUIDB and NoxUIDB.noxQuestAccept or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxQuestAccept = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end }, nil
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type="toggle", text="Annonce de scénario terminé",
          tooltip="Affiche une alerte quand le client signale la fin d'un scénario.",
          getValue=function() return NoxUIDB and NoxUIDB.noxScenarioAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxScenarioAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end },
        { type="toggle", text="Annonce de créature rare vaincue",
          tooltip="Signale la mort d’une créature rare ciblée quand le journal de combat attribue la victoire au groupe.",
          getValue=function() return NoxUIDB and NoxUIDB.noxRareAlert or false end,
          setValue=function(v)
              NoxUIDB = NoxUIDB or {}; NoxUIDB.noxRareAlert = v
              if NoxUI._noxApplyProgressAlerts then NoxUI._noxApplyProgressAlerts() end
          end }
    ); y = y - h

    if NoxUI.IS_FOREVER then
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Rappel de pause",
              tooltip = "Affiche un rappel après la durée choisie. Le compteur se suspend pendant une absence et le rappel attend la fin du combat.",
              getValue = function() return NoxUIDB and NoxUIDB.noxBreakEnabled or false end,
              setValue = function(value)
                  NoxUIDB = NoxUIDB or {}; NoxUIDB.noxBreakEnabled = value
                  if NoxUI.ApplyBreakReminder then NoxUI.ApplyBreakReminder() end
              end },
            { type = "slider", text = "Délai entre les rappels", min = 15, max = 240, step = 5,
              getValue = function() return NoxUIDB and NoxUIDB.noxBreakMinutes or 60 end,
              setValue = function(value)
                  NoxUIDB = NoxUIDB or {}; NoxUIDB.noxBreakMinutes = value
                  if NoxUI.ApplyBreakReminder then NoxUI.ApplyBreakReminder() end
              end })
        y = y - h
        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Durée minimale de pause", min = 1, max = 30, step = 1,
              tooltip = "Après cette durée en absence, le délai du prochain rappel repart de zéro.",
              getValue = function() return NoxUIDB and NoxUIDB.noxBreakRestMinutes or 5 end,
              setValue = function(value) NoxUIDB = NoxUIDB or {}; NoxUIDB.noxBreakRestMinutes = value end },
            { type = "slider", text = "Durée du report", min = 1, max = 30, step = 1,
              tooltip = "Délai appliqué au prochain rappel lorsque tu choisis de le reporter.",
              getValue = function() return NoxUIDB and NoxUIDB.noxBreakDelayMinutes or 5 end,
              setValue = function(value) NoxUIDB = NoxUIDB or {}; NoxUIDB.noxBreakDelayMinutes = value end })
        y = y - h
        _, h = W:WideDualButton(parent, "Reporter le rappel", "Recommencer le délai", y,
            function() if NoxUI.DelayBreakReminder then NoxUI.DelayBreakReminder() end end,
            function() if NoxUI.ResetBreakReminder then NoxUI.ResetBreakReminder() end end)
        y = y - h
        _, h = W:SectionHeader(parent, "OBJETS ET MATÉRIAUX", y)
        y = y - h
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Nom de la quête dans l’infobulle",
              getValue = function() return NoxUIDB and NoxUIDB.noxItemQuestTitle or false end,
              setValue = function(value)
                  NoxUIDB = NoxUIDB or {}
                  NoxUIDB.noxItemQuestTitle = value
              end },
            { type = "input", text = "Matériaux épinglés",
              inputStyle = "popup", placeholder = "Identifiants ou liens d’objets",
              tooltip = "Saisis jusqu’à six identifiants ou liens d’objets, séparés par des virgules. Vide le champ pour retirer le compteur.",
              getValue = function()
                  local db = NoxUIDB
                  if db and type(db.noxTrackedMaterials) == "table" then
                      local values = {}
                      for _, id in ipairs(db.noxTrackedMaterials) do values[#values + 1] = tostring(id) end
                      return table.concat(values, ", ")
                  end
                  return tostring(db and db.noxTrackedMaterial or "")
              end,
              setValue = function(value)
                  if type(value) ~= "string" then return end
                  local ids, seen = {}, {}
                  value = value:gsub("|c%x%x%x%x%x%x%x%x(|Hitem:[^|]+|h%[[^%]]+%]|h)|r", "%1")
                  value = value:gsub("|Hitem:(%d+)[^|]*|h%[[^%]]+%]|h", "%1")
                  for part in (value .. ","):gmatch("(.-),") do
                      local token = part:match("^%s*(.-)%s*$")
                      if token ~= "" then
                          local id = token:match("^%d+$") and tonumber(token)
                          if not id or id <= 0 or id > 2147483647 then return end
                          if not seen[id] then ids[#ids + 1] = id; seen[id] = true end
                          if #ids > 6 then return end
                      end
                  end
                  NoxUIDB = NoxUIDB or {}
                  NoxUIDB.noxTrackedMaterials = ids
                  NoxUIDB.noxTrackedMaterial = ids[1]
                  if NoxUI.RefreshTrackedMaterial then NoxUI.RefreshTrackedMaterial() end
              end })
        y = y - h
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Matériaux nécessaires dans l’infobulle",
              tooltip = "Affiche les matériaux connus pour les objets combinables lorsque le jeu fournit leurs données.",
              getValue = function() return NoxUIDB and NoxUIDB.noxItemReagents or false end,
              setValue = function(value) NoxUIDB = NoxUIDB or {}; NoxUIDB.noxItemReagents = value end },
            { type = "toggle", text = "Ouvrir la quête depuis l’objet",
              tooltip = "Un Ctrl clic sur un objet de quête dans le sac ouvre sa quête si elle figure dans le journal.",
              getValue = function() return NoxUIDB and NoxUIDB.noxItemQuestOpen or false end,
              setValue = function(value) NoxUIDB = NoxUIDB or {}; NoxUIDB.noxItemQuestOpen = value end })
        y = y - h
    end

    -- Inline cog (text, size, colors, mode) on the Combat Alert toggle.
    do
        local leftRgn = row1._leftRegion
        local function caOff()
            return not (NoxUIDB and NoxUIDB.combatAlertEnabled)
        end
        local function enterClassOn()
            return NoxUIDB and NoxUIDB.combatAlertEnterUseClassColor
        end
        local function leaveClassOn()
            return NoxUIDB and NoxUIDB.combatAlertLeaveUseClassColor
        end

        local caModeValues = {
            both  = "Enter & Leave",
            enter = "Enter Only",
            leave = "Leave Only",
        }
        local caModeOrder = { "both", "enter", "leave" }

        NoxUI.BuildInlineCog(leftRgn, {
            title = "Combat Alert Settings",
            minWidth = 300,
            rows = {
                { type="dropdown", label="Show On",
                  values=caModeValues, order=caModeOrder,
                  get=function() return (NoxUIDB and NoxUIDB.combatAlertMode) or "both" end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertMode = v
                  end },
                { type="slider", label="Text Size",
                  min=14, max=64, step=1,
                  get=function()
                    return (NoxUIDB and NoxUIDB.combatAlertTextSize) or 22
                  end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertTextSize = v
                    if NoxUI._applyCombatAlertFrame then NoxUI._applyCombatAlertFrame() end
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("enter") end
                  end },
                { type="input", label="Enter Text", inputWidth=90,
                  get=function()
                    return (NoxUIDB and NoxUIDB.combatAlertEnterText) or "+Combat"
                  end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertEnterText = v
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("enter") end
                  end },
                { type="colorpicker", label="Enter Color",
                  disabled=enterClassOn,
                  disabledTooltip="Disable Class Color to pick a custom color.", rawTooltip=true,
                  get=function()
                    local c = (NoxUIDB and NoxUIDB.combatAlertEnterColor) or { r=1.00, g=1.00, b=1.00 }
                    return c.r, c.g, c.b
                  end,
                  set=function(r, g, b)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertEnterColor = { r=r, g=g, b=b }
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("enter") end
                  end },
                { type="toggle", label="Enter Class Color",
                  get=function() return enterClassOn() end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertEnterUseClassColor = v
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("enter") end
                  end },
                { type="input", label="Leave Text", inputWidth=90,
                  get=function()
                    return (NoxUIDB and NoxUIDB.combatAlertLeaveText) or "-Combat"
                  end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertLeaveText = v
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("leave") end
                  end },
                { type="colorpicker", label="Leave Color",
                  disabled=leaveClassOn,
                  disabledTooltip="Disable Class Color to pick a custom color.", rawTooltip=true,
                  get=function()
                    local c = (NoxUIDB and NoxUIDB.combatAlertLeaveColor) or { r=1.00, g=1.00, b=1.00 }
                    return c.r, c.g, c.b
                  end,
                  set=function(r, g, b)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertLeaveColor = { r=r, g=g, b=b }
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("leave") end
                  end },
                { type="toggle", label="Leave Class Color",
                  get=function() return leaveClassOn() end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.combatAlertLeaveUseClassColor = v
                    if NoxUI._combatAlertPreview then NoxUI._combatAlertPreview("leave") end
                  end },
            },
            footer = { unlockKey = "EUI_CombatAlert" },
            gap = 9, disabled = caOff, disabledTooltip = "Combat Alert",
        })
    end


    do
        NoxUI.BuildInlineCog(row1._rightRegion, {
            title = "Potion Ready Alert Settings",
            minWidth = 300,
            rows = AlertCogRows("potionAlert", "_potionAlertFrame", "_potionAlertPreview"),
            footer = { unlockKey = "EUI_CombatAlert" },
            gap = 9,
            disabled = function() return not (NoxUIDB and NoxUIDB.potionAlertEnabled) end,
            disabledTooltip = "Potion Ready Alert",
        })
        NoxUI.BuildInlineCog(row2._leftRegion, {
            title = "Unspent Talents Alert Settings",
            minWidth = 300,
            rows = AlertCogRows("talentAlert", "_talentAlertFrame", "_talentAlertPreview"),
            footer = { unlockKey = "EUI_CombatAlert" },
            gap = 9,
            disabled = function() return not (NoxUIDB and NoxUIDB.talentAlertEnabled) end,
            disabledTooltip = "Unspent Talents Alert",
        })

        -- Inline cog (Text Size, Sound) on the Announce Group Deaths toggle
        local function deathOff()
            return not (NoxUIDB and NoxUIDB.announceGroupDeaths)
        end

        -- Sound dropdown: the group death sounds with a click-to-preview
        -- speaker icon on each row.
        local gdSoundValues, gdSoundOrder = NoxUI.BuildSoundDropdownValues()

        NoxUI.BuildInlineCog(row2._rightRegion, {
            title = "Group Death Alert Settings",
            rows = {
                { type="slider", label="Text Size",
                  min=14, max=64, step=1,
                  get=function()
                    return (NoxUIDB and NoxUIDB.groupDeathTextSize) or 34
                  end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.groupDeathTextSize = v
                    if NoxUI._applyGroupDeathAlert then NoxUI._applyGroupDeathAlert() end
                    if NoxUI._groupDeathShowVisual then NoxUI._groupDeathShowVisual() end
                  end },
                { type="dropdown", label="Sound",
                  values=gdSoundValues, order=gdSoundOrder,
                  get=function()
                    return (NoxUIDB and NoxUIDB.groupDeathSoundKey) or "none"
                  end,
                  set=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.groupDeathSoundKey = v
                    if v ~= "none" and NoxUI._groupDeathPlaySound then
                        NoxUI._groupDeathPlaySound()
                    end
                  end },
            },
            gap = 9, disabled = deathOff, disabledTooltip = "Announce Group Deaths",
        })
    end

    _, h = W:Spacer(parent, y, 20); y = y - h

    return math.abs(y - yOffset)
end
