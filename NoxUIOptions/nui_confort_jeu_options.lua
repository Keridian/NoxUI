if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_confort_jeu_options.lua
--  Registers the Quality of Life sidebar addon with its two tabs:
--    * Quality of Life -- general QoL features (built by parent general options)
--    * Cursor          -- cursor skin (built by nui_confort_jeu_curseur_options.lua)
-------------------------------------------------------------------------------
-- Page names are DEEP-LINK IDENTIFIERS, not just tab labels: every
-- NavigateToElementSettings tuple (_ELEMENT_SETTINGS_MAP, What's New nav)
-- and every GetActivePage() comparison carries them as strings and fails
-- SILENTLY on a mismatch. Renaming one means updating every consumer.
if not NoxUI._ModuleNS["NoxUIConfortJeu"] then return end  -- module disabled: no options page

-- Page reuse: frames this file builds go through the options frame pool
-- (NoxUI_FramePool.lua), which hands a kept page its previous build's
-- frames back reset to new; on any other parent it is the plain CreateFrame.
local CreateFrame = NoxUI._Pool.CreateFrame

local PAGE_CHARACTERS = "Character Overview"
local PAGE_QOL      = "QoL"
local PAGE_CURSOR   = "Cursor"
local PAGE_UPGCALC  = "Upgrader"
local PAGE_SHIFTER  = "Shifter"
local PAGE_MOVEMENT = "MoveAlert"
local PAGE_RAIDTOOLS = "Raid Tools"

-------------------------------------------------------------------------------
--  Hide Item Transforms picker popup
--  Item checklist styled after the spec-assign popup: dimmed backdrop, one
--  column per category, Check/Uncheck All links and a green Apply button.
--  Edits are staged and only written on Apply; clicking outside or pressing
--  Escape discards them. Item data comes from NoxUI.HideTransformsData
--  (owned by the runtime in NoxUIConfortJeu.lua).
-------------------------------------------------------------------------------
local transformsPopup
local transformsStaged = {}

local function ShowTransformsPopup()
    local data = NoxUI.HideTransformsData
    if not data then return end

    if not transformsPopup then
        local FONT = NoxUI._font or "Interface\\AddOns\\NoxUI\\media\\fonts\\Expressway.ttf"
        local EG = NoxUI.NOX_GREEN or { r = 0.05, g = 0.82, b = 0.62 }
        local PP = NoxUI.PanelPP
        local COL_W, COL_GAP = 190, 12
        local CONTENT_LEFT, CONTENT_RIGHT, CONTENT_TOP = 41, 36, 118
        local HDR_H, ROW_H = 30, 26
        local numCols = #data.order

        -- Group items per category; the tallest column drives the popup height.
        local catItems = {}
        for _, item in ipairs(data.items) do
            catItems[item.cat] = catItems[item.cat] or {}
            catItems[item.cat][#catItems[item.cat] + 1] = item
        end
        local maxRows = 0
        for _, cat in ipairs(data.order) do
            local n = catItems[cat] and #catItems[cat] or 0
            if n > maxRows then maxRows = n end
        end

        local POPUP_W = CONTENT_LEFT + CONTENT_RIGHT + numCols * COL_W + (numCols - 1) * COL_GAP
        local POPUP_H = CONTENT_TOP + HDR_H + 4 + maxRows * ROW_H + 24 + 39 + 38
        local ppScale = NoxUI.GetPopupScale() or 1

        local dimmer = CreateFrame("Frame", nil, UIParent)
        dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
        dimmer:SetAllPoints(UIParent)
        dimmer:EnableMouse(true)
        dimmer:EnableMouseWheel(true)
        dimmer:SetScript("OnMouseWheel", function() end)
        dimmer:Hide()
        dimmer:SetScale(ppScale)
        local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
        dimTex:SetAllPoints()
        dimTex:SetColorTexture(0, 0, 0, 0.25)

        local popup = CreateFrame("Frame", nil, dimmer)
        popup:SetScale(NoxUI.PopupBump(1))
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(dimmer:GetFrameLevel() + 10)
        popup:SetSize(POPUP_W, POPUP_H)
        popup:SetPoint("CENTER", NoxUI._mainFrame or UIParent, "CENTER", 0, 0)
        popup:EnableMouse(true)
        local pf = NoxUI._popupFrames
        if pf then pf[#pf + 1] = { popup = popup, dimmer = dimmer } end

        local bg = popup:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.077, 0.068, 0.058, 1)
        NoxUI.MakeRoundedBorder(popup, 1, 1, 1, 0.15, bg)

        local title = popup:CreateFontString(nil, "OVERLAY")
        title:SetFont(FONT, 22, "")
        title:SetTextColor(1, 1, 1, 1)
        title:SetPoint("TOP", popup, "TOP", 0, -32)
        title:SetText(NoxUI.L("Hide Item Transforms"))

        local sub = popup:CreateFontString(nil, "OVERLAY")
        sub:SetFont(FONT, 14, "")
        sub:SetTextColor(1, 1, 1, 0.45)
        sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
        sub:SetText(NoxUI.L("Checked transforms are removed automatically when applied to you."))

        local rows = {}
        local function RefreshRows()
            for _, row in ipairs(rows) do
                if transformsStaged[row._key] then
                    row._check:Show()
                    row._boxBorder:SetColor(EG.r, EG.g, EG.b, 0.8)
                else
                    row._check:Hide()
                    row._boxBorder:SetColor(0.4, 0.4, 0.4, 0.6)
                end
            end
        end
        popup._refreshRows = RefreshRows

        -- Check All / Uncheck All links
        local function SetAll(v)
            for _, item in ipairs(data.items) do transformsStaged[item.key] = v end
            RefreshRows()
        end
        local checkAllBtn = CreateFrame("Button", nil, popup)
        checkAllBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
        local checkAllLbl = checkAllBtn:CreateFontString(nil, "OVERLAY")
        checkAllLbl:SetFont(FONT, 14, "")
        checkAllLbl:SetText(NoxUI.L("Check All"))
        checkAllLbl:SetTextColor(1, 1, 1, 0.45)
        checkAllLbl:SetPoint("CENTER")
        checkAllBtn:SetSize(checkAllLbl:GetStringWidth() + 4, 20)
        checkAllBtn:SetPoint("TOPLEFT", popup, "TOPLEFT", CONTENT_LEFT, -(CONTENT_TOP - 22))
        checkAllBtn:SetScript("OnEnter", function() checkAllLbl:SetTextColor(1, 1, 1, 0.80) end)
        checkAllBtn:SetScript("OnLeave", function() checkAllLbl:SetTextColor(1, 1, 1, 0.45) end)
        checkAllBtn:SetScript("OnClick", function() SetAll(true) end)

        local linkDivider = popup:CreateTexture(nil, "OVERLAY", nil, 7)
        linkDivider:SetColorTexture(1, 1, 1, 0.18)
        if linkDivider.SetSnapToPixelGrid then linkDivider:SetSnapToPixelGrid(false); linkDivider:SetTexelSnappingBias(0) end
        linkDivider:SetPoint("LEFT", checkAllBtn, "RIGHT", 10, 0)
        linkDivider:SetWidth(1)
        linkDivider:SetHeight(12)

        local uncheckAllBtn = CreateFrame("Button", nil, popup)
        uncheckAllBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
        local uncheckAllLbl = uncheckAllBtn:CreateFontString(nil, "OVERLAY")
        uncheckAllLbl:SetFont(FONT, 14, "")
        uncheckAllLbl:SetText(NoxUI.L("Uncheck All"))
        uncheckAllLbl:SetTextColor(1, 1, 1, 0.45)
        uncheckAllLbl:SetPoint("CENTER")
        uncheckAllBtn:SetSize(uncheckAllLbl:GetStringWidth() + 4, 20)
        uncheckAllBtn:SetPoint("LEFT", checkAllBtn, "RIGHT", 20, 0)
        uncheckAllBtn:SetScript("OnEnter", function() uncheckAllLbl:SetTextColor(1, 1, 1, 0.80) end)
        uncheckAllBtn:SetScript("OnLeave", function() uncheckAllLbl:SetTextColor(1, 1, 1, 0.45) end)
        uncheckAllBtn:SetScript("OnClick", function() SetAll(false) end)

        -- Category columns
        for colIdx, cat in ipairs(data.order) do
            local colX = CONTENT_LEFT + (colIdx - 1) * (COL_W + COL_GAP)
            local hdr = popup:CreateFontString(nil, "OVERLAY")
            hdr:SetFont(FONT, 17, "")
            hdr:SetTextColor(1, 1, 1, 0.7)
            hdr:SetPoint("TOPLEFT", popup, "TOPLEFT", colX + 4, -(CONTENT_TOP + 8))
            hdr:SetText(NoxUI.L(data.labels[cat] or cat))

            local items = catItems[cat] or {}
            for i, item in ipairs(items) do
                local row = CreateFrame("Button", nil, popup)
                row:SetSize(COL_W, ROW_H)
                row:SetPoint("TOPLEFT", popup, "TOPLEFT", colX, -(CONTENT_TOP + HDR_H + 4 + (i - 1) * ROW_H))
                row._key = item.key

                local box = CreateFrame("Frame", nil, row)
                box:SetSize(18, 18)
                box:SetPoint("LEFT", row, "LEFT", 4, 0)
                box:SetFrameLevel(row:GetFrameLevel() + 1)
                local boxBg = box:CreateTexture(nil, "BACKGROUND")
                boxBg:SetAllPoints()
                boxBg:SetColorTexture(0.114, 0.106, 0.099, 1)
                row._boxBorder = NoxUI.MakeRoundedBorder(box, 0.4, 0.4, 0.4, 0.6, boxBg)
                local check = box:CreateTexture(nil, "ARTWORK")
                check:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
                check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
                check:SetColorTexture(EG.r, EG.g, EG.b, 1)
                NoxUI.RoundBody(box, check, 1)
                row._check = check

                local lbl = row:CreateFontString(nil, "OVERLAY")
                lbl:SetFont(FONT, 13, "")
                lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
                lbl:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetWordWrap(false)
                lbl:SetTextColor(1, 1, 1, 0.65)
                lbl:SetText(NoxUI.L(item.label))

                row:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 0.95) end)
                row:SetScript("OnLeave", function() lbl:SetTextColor(1, 1, 1, 0.65) end)
                row:SetScript("OnClick", function()
                    transformsStaged[item.key] = not transformsStaged[item.key]
                    RefreshRows()
                end)
                rows[#rows + 1] = row
            end
        end

        -- Apply button (green, spec-popup style)
        local applyBtn = CreateFrame("Button", nil, popup)
        applyBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
        applyBtn:SetSize(200, 39)
        applyBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 38)
        local applyBg = applyBtn:CreateTexture(nil, "BACKGROUND")
        applyBg:SetAllPoints()
        applyBg:SetColorTexture(0.077, 0.068, 0.058, 0.92)
        local applyBrd = NoxUI.MakeRoundedBorder(applyBtn, EG.r, EG.g, EG.b, 0.9, applyBg)
        local applyLbl = applyBtn:CreateFontString(nil, "OVERLAY")
        applyLbl:SetFont(FONT, 16, "")
        applyLbl:SetPoint("CENTER")
        applyLbl:SetText(NoxUI.L("Apply"))
        applyLbl:SetTextColor(EG.r, EG.g, EG.b, 0.9)
        applyBtn:SetScript("OnEnter", function()
            applyLbl:SetTextColor(EG.r, EG.g, EG.b, 1)
            applyBrd:SetColor(EG.r, EG.g, EG.b, 1)
        end)
        applyBtn:SetScript("OnLeave", function()
            applyLbl:SetTextColor(EG.r, EG.g, EG.b, 0.9)
            applyBrd:SetColor(EG.r, EG.g, EG.b, 0.9)
        end)
        applyBtn:SetScript("OnClick", function()
            if not NoxUIDB then NoxUIDB = {} end
            NoxUIDB.hideTransformItems = NoxUIDB.hideTransformItems or {}
            local t = NoxUIDB.hideTransformItems
            for _, item in ipairs(data.items) do
                local staged = transformsStaged[item.key] and true or false
                if staged == (not item.defaultOff) then
                    t[item.key] = nil       -- matches the per-key default
                else
                    t[item.key] = staged    -- stored deviations only
                end
            end
            if NoxUI._applyHideTransforms then NoxUI._applyHideTransforms() end
            dimmer:Hide()
        end)

        -- Click outside or Escape discards staged edits
        dimmer:SetScript("OnMouseDown", function(self)
            if not popup:IsMouseOver() then self:Hide() end
        end)
        NoxUI.PopupTakeKeys(popup, dimmer)
        popup:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                dimmer:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        popup._dimmer = dimmer
        transformsPopup = popup
    end

    -- Seed the staged state from the saved settings, then show
    for _, item in ipairs(data.items) do
        transformsStaged[item.key] = NoxUI.GetHideTransformItem(item.key) and true or false
    end
    transformsPopup._refreshRows()
    transformsPopup._dimmer:Show()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI or not NoxUI.RegisterModule then return end

    ---------------------------------------------------------------------------
    --  QoL Features page
    ---------------------------------------------------------------------------
    -- The Macro Factory card: open or closed for the session (closed at its
    -- start), the section name its header carries in search (set by each
    -- build), and its glyph, the Potion macro's icon.
    local macroFactoryOpen = {}
    local macroFactorySection
    local function MacroFactoryGlyph(hdr)
        local PP = NoxUI.PanelPP
        local icon = hdr:CreateTexture(nil, "ARTWORK")
        PP.Size(icon, 22, 22)
        PP.Point(icon, "LEFT", hdr, "LEFT", 17, 0)
        icon:SetTexture("Interface\\Icons\\inv_potion_54")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- Deep-link pre-hook: a jump to the card's own search entry opens the card
    -- first, so the jump lands on the open factory (a jump to any other row of
    -- the page leaves the card as it is).
    do
        local origNav = NoxUI.NavigateToElementSettings
        function NoxUI:NavigateToElementSettings(moduleName, pageName, sectionName, preSelectFn, highlightText)
            -- The original refuses in combat: no page state changes then.
            if InCombatLockdown() then
                return origNav(self, moduleName, pageName, sectionName, preSelectFn, highlightText)
            end
            if moduleName == "NoxUIConfortJeu" and pageName == PAGE_QOL and sectionName ~= nil
               and sectionName == macroFactorySection and not macroFactoryOpen.macroFactory then
                macroFactoryOpen.macroFactory = true
                NoxUI:InvalidatePageCache()
            end
            return origNav(self, moduleName, pageName, sectionName, preSelectFn, highlightText)
        end
    end

    local function BuildQoLPage(pageName, parent, yOffset)
        local W = NoxUI.Widgets
        local y = yOffset
        local _, h, hdr
        local PP = NoxUI.PanelPP

        parent._showRowDivider = true

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -- The Macro Factory sits in an expandable card (the patch notes' card),
        -- closed at the start of every session: its section is built only while
        -- the card is open, and a closed card parks the section an earlier build
        -- left. The card's header is a search entry (a jump to it opens the card,
        -- see the pre-hook below), but the factory's own rows stay out of the
        -- index, and the hidden search pre-build builds the header only: it never
        -- builds the section and never parks the one on screen. WoW Forever's
        -- factory has its own item macros, plus Warlock and Mage sets instead of spec sets.
        if NoxUI.BuildMacroFactory then
            local prebuilding = NoxUI._prebuilding
            local mfDesc = NoxUI.IS_FOREVER
                and NoxUI.L("Ready-made macros for food, drink, healthstones, potions and trinkets, plus Warlock stones and Mage gems")
                or NoxUI.L("Ready-made macros for potions, food, trinkets and focus, plus a set for your spec")
            local mfTile = { key = "macroFactory", display = "Macro Factory",
                desc = mfDesc,
                buildContent = function(_, cy)
                    if prebuilding then return cy end
                    NoxUI._searchIndexSuppress = true
                    local mfH = NoxUI.BuildMacroFactory(parent, cy, PP)
                    NoxUI._searchIndexSuppress = nil
                    return cy - mfH
                end }
            macroFactorySection = mfTile.display .. " " .. mfTile.desc
            y = NoxUI.BuildModuleCard(parent, y, W, mfTile, {
                enabled = true, expanded = macroFactoryOpen, descW = 560,
                glyph = MacroFactoryGlyph })
            if not macroFactoryOpen.macroFactory and not prebuilding then
                NoxUI.ParkMacroFactory()
            end
        end

        if NoxUI.SyncAuctionSale then
            _, h = W:SectionHeader(parent, "Auction House", y); y = y - h
            _, h = W:DualRow(parent, y,
                { type="toggle", text="Auction Sale Sound",
                  getValue=function() return NoxUIDB.nuiAuctionSaleSound == true end,
                  setValue=function(v) NoxUIDB.nuiAuctionSaleSound = v; NoxUI.SyncAuctionSale() end },
                { type="dropdown", text="Auction Sound Channel",
                  values={ Master=NoxUI.L("Master"), SFX=NoxUI.L("Sound Effects") },
                  order={ "Master", "SFX" },
                  getValue=function() return NoxUIDB.nuiAuctionSaleChannel or "Master" end,
                  setValue=function(v) NoxUIDB.nuiAuctionSaleChannel = v end })
            y = y - h
            _, h = W:WideButton(parent, "Preview Auction Sound", y, NoxUI.PreviewAuctionSale)
            y = y - h
        end

        if NoxUI.SyncSupplyWarnings then
            local function supplyThreshold(key, label, fallback, maxValue)
                return { type="slider", text=label, min=1, max=maxValue, step=1,
                    getValue=function() return NoxUIDB[key] or fallback end,
                    setValue=function(value)
                        NoxUIDB[key] = value
                        NoxUI.SyncSupplyWarnings()
                    end }
            end
            _, h = W:SectionHeader(parent, "Supplies", y); y = y - h
            _, h = W:DualRow(parent, y,
                { type="toggle", text="Low Supply Warnings",
                  tooltip="Warns once when ammunition or a supported spell reagent falls below its threshold.",
                  getValue=function() return NoxUIDB.supplyWarnings == true end,
                  setValue=function(value)
                      NoxUIDB.supplyWarnings = value
                      NoxUI.SyncSupplyWarnings()
                  end },
                NoxUI.BlankRowCfg())
            y = y - h
            _, h = W:DualRow(parent, y,
                supplyThreshold("supplyAmmoThreshold", "Ammunition Threshold", 200, 1000),
                supplyThreshold("supplyReagentThreshold", "Spell Reagent Threshold", 3, 50))
            y = y - h
        end

        ---------------------------------------------------------------------------
        --  GENERAL
        ---------------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "GENERAL", y);  y = y - h

        if NoxUI.SetBuffThanksEnabled then
            _, h = W:DualRow(parent, y,
                { type = "toggle", text = "Remercier pour les buffs reçus",
                  tooltip = "Envoie un merci hors combat. Langue du destinataire si disponible, anglais par défaut.",
                  getValue = function() return NoxUIDB.buffThanksEnabled == true end,
                  setValue = NoxUI.SetBuffThanksEnabled },
                NoxUI.BlankRowCfg())
            y = y - h
        end

        if NoxUI.SyncForeverRequests then
            local function requestToggle(key, label, tooltip)
                return { type = "toggle", text = label, tooltip = tooltip,
                    getValue = function() return NoxUIDB[key] == true end,
                    setValue = function(value)
                        NoxUIDB[key] = value
                        NoxUI.SyncForeverRequests()
                    end }
            end
            _, h = W:DualRow(parent, y,
                requestToggle("blockStrangerDuels", "Refuser les duels d’inconnus",
                    "Garde les demandes des amis et de la guilde. Maintiens Maj pour traiter la demande manuellement."),
                requestToggle("acceptSafeResurrection", "Accepter les résurrections hors combat",
                    "Accepte si le lanceur est identifiable et hors combat. Maintiens Maj pour décider toi-même."))
            y = y - h
            _, h = W:DualRow(parent, y,
                requestToggle("acceptSafeSummon", "Accepter les invocations hors combat",
                    "Accepte automatiquement le déplacement proposé. Maintiens Maj pour confirmer manuellement."),
                NoxUI.BlankRowCfg())
            y = y - h
        end

        -- Row 1: Hide Blizzard Elements (checklist + Loot Rolls Window cog) |
        -- Skip Cinematics (+ cog). Each checklist row reads and writes its own
        -- saved key, as its toggle did. Party Panel is the same key and apply
        -- as the Raid Frames toggle (NoxUI_BlizzardParty.lua). The talking
        -- head, banner and toast rows are retail only: their runtime blocks do
        -- not exist on WoW Forever.
        do
            local HBE_LABEL = "Hide Blizzard Elements"
            local function QDB()
                if not NoxUIDB then NoxUIDB = {} end
                return NoxUIDB
            end
            -- The toast rows share the hideAlertToasts switch: a kind hides while
            -- the switch is on and its own key allows it (Loot unset = on, the
            -- others unset = off), the runtime's KindHidden rule.
            local TOAST_KEYS = { "hideAlertToastsLoot", "hideAlertToastsAchievements", "hideAlertToastsHousing" }
            local function ToastHidden(key)
                local db = NoxUIDB
                if not (db and db.hideAlertToasts) then return false end
                local v = db[key]
                if v == nil then return key == "hideAlertToastsLoot" end
                return v
            end
            local function SetToast(key, v)
                local db = QDB()
                if v and not db.hideAlertToasts then
                    -- The switch goes on for this kind alone.
                    db.hideAlertToasts = true
                    for i = 1, #TOAST_KEYS do db[TOAST_KEYS[i]] = false end
                end
                db[key] = v and true or false
                if not v then
                    local any = false
                    for i = 1, #TOAST_KEYS do
                        if ToastHidden(TOAST_KEYS[i]) then any = true end
                    end
                    if not any then db.hideAlertToasts = false end
                end
                if NoxUI._applyHideAlertToasts then NoxUI._applyHideAlertToasts() end
            end
            local function Toast(key, label, alias)
                return { key = key, label = label, alias = alias,
                    read = function() return ToastHidden(key) end,
                    write = function(v) SetToast(key, v) end }
            end

            -- alias: the row's old label, kept as search text.
            local RETAIL = not NoxUI.IS_FOREVER
            local items = {}
            items[#items + 1] = { key = "hideBlizzardPartyFrame", label = "Party Panel (Sidebar)",
                alias = "Hide Blizzard Party Panel",
                tooltip = "Hides the collapsed Blizzard party/raid sidebar panel on the side of the screen.",
                read = function() return NoxUIDB and NoxUIDB.hideBlizzardPartyFrame or false end,
                write = function(v)
                    QDB().hideBlizzardPartyFrame = v
                    NoxUI._applyHideBlizzardPartyFrame()
                end }
            if RETAIL then
                items[#items + 1] = { key = "hideTalkingHead", label = "Talking Head",
                    alias = "Hide Talking Head",
                    tooltip = "Hides the large NPC dialogue popup that appears during quests and dungeons.",
                    read = function() return NoxUIDB and NoxUIDB.hideTalkingHead or false end,
                    write = function(v)
                        QDB().hideTalkingHead = v
                        NoxUI._applyHideTalkingHead()
                    end }
                items[#items + 1] = { key = "muteTalkingHead", label = "Talking Head Audio",
                    alias = "Mute Talking Head",
                    tooltip = "Silences the talking head's voice lines.",
                    read = function() return NoxUIDB and NoxUIDB.muteTalkingHead == true end,
                    write = function(v)
                        QDB().muteTalkingHead = v
                        NoxUI._applyHideTalkingHead()
                    end }
            end
            items[#items + 1] = { key = "hideTutorials", label = "Tutorial Popups",
                alias = "Hide Tutorial Pop-ups",
                tooltip = "Hides Blizzard's tutorial UI: the yellow HelpTip bubbles and the glowing (i) help-plate buttons on the spellbook, talents, map, collections, and other panels.",
                read = function() return NoxUIDB and NoxUIDB.hideTutorials or false end,
                write = function(v)
                    QDB().hideTutorials = v
                    if NoxUI._applyHideTutorials then NoxUI._applyHideTutorials() end
                end }
            items[#items + 1] = { key = "hideErrorMessages", label = "Error Messages",
                alias = "Hide Error Messages",
                tooltip = "Hides most red error messages (such as 'Not enough rage' or 'Ability is not ready yet'). Important errors like a full bag or quest log are still shown.",
                read = function() return NoxUIDB and NoxUIDB.hideErrorMessages or false end,
                write = function(v)
                    QDB().hideErrorMessages = v
                    -- Turning it off takes effect at the next reload; the apply
                    -- returns true while one is due.
                    if NoxUI._applyHideErrorMessages and NoxUI._applyHideErrorMessages() then
                        NoxUI:ShowConfirmPopup({
                            title       = "Reload Required",
                            message     = "Hidden error messages come back after a UI reload.",
                            confirmText = "Reload Now",
                            cancelText  = "Later",
                            reload      = true,
                        })
                    end
                end }
            items[#items + 1] = { key = "hideLootHistory", label = "Group Loot Rolls Window",
                alias = "Hide Loot Rolls Window",
                tooltip = "Hides Blizzard's \"Loot Rolls\" window -- the running list of dropped items showing who rolled what and who won. Use the cog to let it appear briefly and close itself instead. The Need/Greed roll popups themselves are not affected.",
                read = function() return NoxUIDB and NoxUIDB.hideLootHistory or false end,
                write = function(v)
                    QDB().hideLootHistory = v
                    if NoxUI._applyHideLootHistory then NoxUI._applyHideLootHistory() end
                    NoxUI:RefreshPage()  -- the Loot Rolls Window cog follows
                end }
            if RETAIL then
                items[#items + 1] = { key = "hideBanners", label = "Top Screen Banners",
                    alias = "Hide Banners",
                    tooltip = "Hides the big banners at the top of the screen.",
                    read = function() return NoxUIDB and NoxUIDB.hideBanners or false end,
                    write = function(v)
                        QDB().hideBanners = v
                        if NoxUI._applyHideBanners then NoxUI._applyHideBanners() end
                    end }
            end
            -- The same NoxUIDB.suppressErrors key and scriptErrors CVar as
            -- Global Settings > Developer, applied on login by the parent.
            items[#items + 1] = { key = "suppressErrors", label = "Lua Errors",
                alias = "Suppress Lua Errors",
                tooltip = "Hides the Lua error popup. The same setting as Global Settings > Developer.",
                read = function() return not (NoxUIDB and NoxUIDB.suppressErrors == false) end,
                write = function(v)
                    QDB().suppressErrors = v
                    if not InCombatLockdown() then NoxUI.SetCVar("scriptErrors", v and "0" or "1") end
                end }
            if RETAIL then
                items[#items + 1] = Toast("hideAlertToastsLoot", "Loot Toasts", "Hide Alert Toasts")
                items[#items + 1] = Toast("hideAlertToastsAchievements", "Achievement Toasts")
                items[#items + 1] = Toast("hideAlertToastsHousing", "Housing Toasts")
            end

            -- Global search sees row labels and tooltips only, so this row's
            -- entry, registered before the row (the index keeps the first one),
            -- carries the checklist's names as search text; it is never shown.
            if NoxUI._RegisterSearchEntry then
                local words = {}
                local function Word(s)
                    if not s then return end
                    words[#words + 1] = s
                    local loc = NoxUI.L(s)
                    if loc ~= s then words[#words + 1] = loc end
                end
                for i = 1, #items do
                    Word(items[i].label)
                    Word(items[i].alias)
                end
                local labelLoc = NoxUI.L(HBE_LABEL)
                NoxUI._RegisterSearchEntry(HBE_LABEL, labelLoc ~= HBE_LABEL and labelLoc or nil,
                    table.concat(words, " "), NoxUI._buildingModule, NoxUI._buildingPage,
                    parent._currentSection and parent._currentSection._sectionName)
            end

            local row1
            row1, h = W:DualRow(parent, y,
                { type="label", text=HBE_LABEL,
                  tooltip="Choose which Blizzard elements to hide." },
                { type="toggle", text="Skip Cinematics",
                  tooltip="When you press Escape or Space during a cinematic, the confirmation prompt is automatically accepted.",
                  getValue=function()
                      return NoxUIDB and NoxUIDB.skipCinematics or false
                  end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.skipCinematics = v
                      NoxUI:RefreshPage()
                  end }
            );  y = y - h

            do
                local leftRgn = row1._leftRegion
                if not NoxUI._prebuilding then
                    local byKey = {}
                    for i = 1, #items do byKey[items[i].key] = items[i] end
                    local hbeDD, hbeDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                        leftRgn, 210, leftRgn:GetFrameLevel() + 2, items,
                        function(key) return byKey[key].read() end,
                        function(key, v) byKey[key].write(v) end)
                    PP.Point(hbeDD, "RIGHT", leftRgn, "RIGHT", -20, 0)
                    leftRgn._control = hbeDD
                    leftRgn._lastInline = nil
                    NoxUI.RegisterWidgetRefresh(hbeDDRefresh)
                end

                -- Loot Rolls Window cog (mode + auto-close delay), left of the list
                local function lootHistOff()
                    return not (NoxUIDB and NoxUIDB.hideLootHistory)
                end
                -- The delay only means anything in auto-close mode.
                local function delayOff()
                    return lootHistOff()
                        or (NoxUIDB and NoxUIDB.lootHistoryMode) ~= "autoclose"
                end
                NoxUI.BuildInlineCog(leftRgn, {
                    title = "Loot Rolls Window Settings",
                    minWidth = 300,
                    rows = {
                        { type="dropdown", label="Mode",
                          values={ hide = "Hide Completely", autoclose = "Close After Delay" },
                          order={ "hide", "autoclose" },
                          get=function() return (NoxUIDB and NoxUIDB.lootHistoryMode) or "hide" end,
                          set=function(v)
                            QDB().lootHistoryMode = v
                            if NoxUI._applyHideLootHistory then NoxUI._applyHideLootHistory() end
                          end },
                        { type="slider", label="Close After (sec)",
                          min=1, max=30, step=1,
                          disabled=delayOff,
                          get=function()
                            return (NoxUIDB and NoxUIDB.lootHistoryDelay) or 5
                          end,
                          set=function(v)
                            QDB().lootHistoryDelay = v
                            if NoxUI._applyHideLootHistory then NoxUI._applyHideLootHistory() end
                          end },
                    },
                    gap = 9, disabled = lootHistOff, disabledTooltip = "Group Loot Rolls Window",
                })

                -- Cog on Skip Cinematics (right region)
                local function cinematicsOff()
                    return not (NoxUIDB and NoxUIDB.skipCinematics)
                end
                NoxUI.BuildInlineCog(row1._rightRegion, {
                    title = "Cinematic Settings",
                    rows = {
                        { type="toggle", label="Automatically Skip If Possible",
                          get=function()
                              return NoxUIDB and NoxUIDB.skipCinematicsAuto or false
                          end,
                          set=function(v)
                              if not NoxUIDB then NoxUIDB = {} end
                              NoxUIDB.skipCinematicsAuto = v
                          end },
                    },
                    gap = 9, disabled = cinematicsOff, disabledTooltip = "Skip Cinematics",
                })
            end
        end

        local row2
        row2, h = W:DualRow(parent, y,
            { type="toggle", text="Quick Loot",
              tooltip="Speeds up looting when the game is using automatic loot. Manual looting remains available according to the game settings and modifier key.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.quickLoot or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.quickLoot = v
                  if NoxUI._applyQuickLoot then NoxUI._applyQuickLoot() end
              end },
            { type="toggle", text="Auto-Fill Delete Confirmation",
              tooltip="Automatically types DELETE when throwing away a valuable item. Also allows you to press enter to accept the deletion.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.autoFillDelete or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoFillDelete = v
                  NoxUI:RefreshPage()
              end }
        );  y = y - h

        -- Auto Repair | Auto Sell Junk
        local repairRow
        repairRow, h = W:DualRow(parent, y,
            { type="toggle", text="Auto Repair",
              tooltip="Automatically repair all gear when visiting a repair vendor.",
              getValue=function()
                  if not NoxUIDB then return true end
                  return NoxUIDB.autoRepair ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoRepair = v
                  NoxUI:RefreshPage()
              end },
            { type="toggle", text="Auto Sell Junk",
              tooltip="Automatically sell all junk items when visiting a vendor.",
              getValue=function()
                  if not NoxUIDB then return true end
                  return NoxUIDB.autoSellJunk ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoSellJunk = v
              end }
        );  y = y - h

        -- Cog on Auto Repair (left region)
        do
            local leftRgn = repairRow._leftRegion
            local function repairOff()
                return not (NoxUIDB and NoxUIDB.autoRepair ~= false)
            end

            NoxUI.BuildInlineCog(leftRgn, {
                title = "Auto Repair Settings",
                rows = {
                    { type="toggle", label="Use Guild Bank Funds",
                      get=function()
                          if not NoxUIDB then return true end
                          return NoxUIDB.autoRepairGuild ~= false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoRepairGuild = v
                      end },
                    -- Off (default) = short text "12o 34a"; on = coin icons.
                    { type="toggle", label="Coin Icons",
                      get=function()
                          return NoxUIDB and NoxUIDB.repairCoinIcons == true
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.repairCoinIcons = v
                      end },
                },
                gap = 9, disabled = repairOff, disabledTooltip = "Auto Repair",
            })
        end

        -- Hide Item Transforms (+ picker cog) | Auto Select Single Gossip (+ cog)
        local transformRow
        transformRow, h = W:DualRow(parent, y,
            { type="toggle", text="Hide Item Transforms (ex: Chef's Hat)",
              tooltip="Automatically removes cosmetic transforms when they are applied to you, such as profession gear, holiday costumes, toys and consumables. Use the cog to pick exactly which transforms are removed. Transforms applied during combat are removed when combat ends.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.hideTransforms or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.hideTransforms = v
                  if NoxUI._applyHideTransforms then
                      NoxUI._applyHideTransforms()
                  end
                  NoxUI:RefreshPage()  -- update the picker cog disabled state
              end },
            { type="toggle", text="Auto Select Single Gossip",
              tooltip="Picks an NPC's only dialog option for you.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.autoGossip or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoGossip = v
                  if NoxUI._applyAutoGossip then NoxUI._applyAutoGossip() end
                  NoxUI:RefreshPage()
              end }
        );  y = y - h

        -- Inline picker cog on Hide Item Transforms (left slot): opens the item
        -- checklist popup. Dimmed and inert while the toggle is off, mirroring
        -- the resource-bar spec-picker button.
        do
            local rgn = transformRow._leftRegion
            local function hitOff()
                return not (NoxUIDB and NoxUIDB.hideTransforms)
            end
            NoxUI.BuildInlineCog(rgn, {
                gap = 9, tip = NoxUI.L("Choose which transforms are removed"),
                disabled = hitOff, disabledTooltip = "Hide Item Transforms",
                show = function() ShowTransformsPopup() end,
            })
        end

        -- Cog on Auto Select Single Gossip (right slot)
        do
            local rightRgn = transformRow._rightRegion
            local function gossipOff()
                return not (NoxUIDB and NoxUIDB.autoGossip)
            end

            NoxUI.BuildInlineCog(rightRgn, {
                title = "Auto Gossip Settings",
                rows = {
                    { type="toggle", label="Hold Shift to Skip",
                      get=function()
                          if not NoxUIDB then return true end
                          return NoxUIDB.autoGossipShiftSkip ~= false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoGossipShiftSkip = v
                      end },
                    { type="toggle", label="Disable in Instances",
                      get=function()
                          if not NoxUIDB then return true end
                          return NoxUIDB.autoGossipDisableInstance ~= false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoGossipDisableInstance = v
                      end },
                    { type="toggle", label="Ignore Low Level Quests",
                      get=function()
                          return NoxUIDB and NoxUIDB.autoGossipIgnoreTrivial or false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoGossipIgnoreTrivial = v
                      end },
                },
                gap = 9, disabled = gossipOff, disabledTooltip = "Auto Select Single Gossip",
            })
        end

        -- Type /cd to open Blizzard CDM | AH Current Expansion Only. The AH
        -- filter is not offered on WoW Forever (its runtime block does not
        -- exist there), so that slot is blank there.
        _, h = W:DualRow(parent, y,
            -- Cooldown Manager registers /cd at load from this key, so a change reloads
            { type="toggle", text="Type /cd to open Blizzard CDM",
              tooltip="Lets /cd open or close Blizzard's Cooldown Manager settings.",
              disabled=function() return not NoxUI._ModuleNS["NoxUIGestionRecharges"] end,
              disabledTooltip="Cooldown Manager",
              getValue=function()
                  return NoxUIDB and NoxUIDB.blizzCDMSlash == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.blizzCDMSlash = v and true or nil
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "The /cd change applies after a UI reload.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end },
            NoxUI.IS_FOREVER and NoxUI.BlankRowCfg() or
            { type="toggle", text="AH Current Expansion Only",
              tooltip="Automatically enables the 'Current Expansion Only' filter whenever you open the Auction House.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.ahCurrentExpansion or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.ahCurrentExpansion = v
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        ---------------------------------------------------------------------------
        --  EXTRAS
        ---------------------------------------------------------------------------
        hdr, h = W:SectionHeader(parent, "EXTRAS", y);  y = y - h
        -- The FPS Counter is the section's first mover, so the header's button
        -- takes it; the button explains itself while the counter is off.
        NoxUI.BuildSectionUnlockJump(hdr, { key = "EUI_FPS",
            disabled = function() return not NoxUI.QoLExtrasGet("showFPS") end,
            disabledTooltip = "Show FPS Counter" })

        -- Row 1: Show FPS Counter (left, with cog+swatch) | FPS Toggle Keybind (right)
        local fpsRow
        fpsRow, h = W:DualRow(parent, y,
            { type="toggle", text="Show FPS Counter",
              getValue=function()
                return NoxUI.QoLExtrasGet("showFPS") or false
              end,
              setValue=function(v)
                NoxUI.QoLExtrasSet("showFPS", v)
                if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                NoxUI:RefreshPage()
              end },
            { type="label", text="FPS Toggle Keybind" }
        );  y = y - h

        -- Inline cog + color swatches on the FPS toggle (left region)
        do
            local leftRgn = fpsRow._leftRegion
            local function fpsOff()
                return not NoxUI.QoLExtrasGet("showFPS")
            end

            -- Inline class + custom colour swatches, the same convention as the
            -- Secondary Stats row: the active mode renders at full alpha, the
            -- other dimmed, each with a naming tooltip.
            local function fpsMode()
                -- No mode saved: custom -- the look before the mode existed,
                -- which is white until a colour is actually picked.
                return NoxUI.QoLExtrasGet("fpsColorMode") or "custom"
            end
            local fpsUpdateState   -- forward: swatches reference it from OnClick
            local function fpsSetMode(v)
                NoxUI.QoLExtrasSet("fpsColorMode", v)
                if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                if fpsUpdateState then fpsUpdateState() end
            end

            local fpsSwGet = function()
                local c = NoxUI.QoLExtrasGet("fpsColor")
                if c then return c.r, c.g, c.b, c.a end
                return 1, 1, 1, 1
            end
            local fpsSwSet = function(r, g, b, a)
                NoxUI.QoLExtrasSet("fpsColor", { r = r, g = g, b = b, a = a })
                NoxUI.QoLExtrasSet("fpsColorMode", "custom")
                if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                if fpsUpdateState then fpsUpdateState() end
            end

            NoxUI.BuildInlineCog(leftRgn, {
                title = "FPS Counter Settings",
                rows = {
                    { type="toggle", label="Attach to Secondary Stats",
                      disabled=function()
                        return not NoxUI.QoLExtrasGet("showSecondaryStats")
                      end,
                      disabledTooltip="Secondary Stat Display",
                      get=function()
                        return NoxUI.QoLExtrasGet("fpsAttachToStats") or false
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsAttachToStats", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                    -- Attached rows take the Secondary Stats font size, so this
                    -- has nothing to drive while the readout lives over there.
                    { type="slider", label="Text Size",
                      min=8, max=30, step=1,
                      disabled=function()
                        return NoxUI._fpsAttachedToStats
                            and NoxUI._fpsAttachedToStats() or false
                      end,
                      disabledTooltip="Attach to Secondary Stats",
                      requireState="disabled",
                      get=function()
                        return NoxUI.QoLExtrasGet("fpsTextSize") or 12
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsTextSize", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                    { type="toggle", label="Show Local MS",
                      get=function()
                        local sl = NoxUI.QoLExtrasGet("fpsShowLocalMS")
                        if sl == nil then return true end
                        return sl
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsShowLocalMS", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                    { type="toggle", label="Show World MS",
                      get=function()
                        return NoxUI.QoLExtrasGet("fpsShowWorldMS") or false
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsShowWorldMS", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                    { type="toggle", label="Hide Local/World Label",
                      get=function()
                        return NoxUI.QoLExtrasGet("fpsHideLabel") or false
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsHideLabel", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                    { type="slider", label="Update Interval", min=1, max=5, step=1,
                      get=function()
                        return NoxUI.QoLExtrasGet("fpsUpdateInterval") or 3
                      end,
                      set=function(v)
                        NoxUI.QoLExtrasSet("fpsUpdateInterval", v)
                        if NoxUI._applyFPSDisplay then NoxUI._applyFPSDisplay() end
                      end },
                },
                gap = 9, disabled = fpsOff, disabledTooltip = "Show FPS Counter",
            })

            if not NoxUI._prebuilding then
                -- Custom swatch (nearest the cog): a click switches to custom
                -- mode first; a second click opens the picker.
                local fpsSwatch, fpsUpdateSwatch = NoxUI.BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, fpsSwGet, fpsSwSet, true, 20)
                do
                    local openPicker = fpsSwatch:GetScript("OnClick")
                    fpsSwatch:SetScript("OnClick", function(self)
                        if fpsMode() ~= "custom" then fpsSetMode("custom") return end
                        if openPicker then openPicker(self) end
                    end)
                end
                PP.Point(fpsSwatch, "RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
                leftRgn._lastInline = fpsSwatch

                -- Class-colour swatch: live player class colour.
                local fpsClassSw, fpsUpdClass = NoxUI.BuildColorSwatch(
                    leftRgn, leftRgn:GetFrameLevel() + 5,
                    function()
                        local cc = NoxUI.GetClassColor(select(2, UnitClass("player")))
                        if cc then return cc.r, cc.g, cc.b end
                        return 1, 1, 1
                    end,
                    function() end, nil, 20)
                fpsClassSw:SetScript("OnClick", function() fpsSetMode("class") end)
                PP.Point(fpsClassSw, "RIGHT", leftRgn._lastInline, "LEFT", -8, 0)
                leftRgn._lastInline = fpsClassSw

                local fpsTips = { { fpsClassSw, "Class Color" }, { fpsSwatch, "Custom Color" } }
                for _, e in ipairs(fpsTips) do
                    e[1]:HookScript("OnEnter", function() NoxUI.ShowWidgetTooltip(e[1], e[2]) end)
                    e[1]:HookScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
                end

                -- Blocking overlays while Show FPS Counter is off (shown from the
                -- single refresh below, like the swatch alphas).
                local fpsBlocks = {}
                for _, e in ipairs(fpsTips) do
                    local sw = e[1]
                    local block = CreateFrame("Frame", nil, sw)
                    block:SetAllPoints()
                    block:SetFrameLevel(sw:GetFrameLevel() + 10)
                    block:EnableMouse(true)
                    block:SetScript("OnEnter", function()
                        NoxUI.ShowWidgetTooltip(sw, NoxUI.DisabledTooltip("Show FPS Counter"))
                    end)
                    block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
                    fpsBlocks[#fpsBlocks + 1] = block
                end

                -- While the counter is off both swatches dim flat; while on, the
                -- active mode is bright and the other dimmed. One refresh owns
                -- both, plus the swatch fills (class color changes, custom picks).
                fpsUpdateState = function()
                    if fpsUpdateSwatch then fpsUpdateSwatch() end
                    if fpsUpdClass then fpsUpdClass() end
                    local off = fpsOff()
                    for _, block in ipairs(fpsBlocks) do block:SetShown(off) end
                    local m = not off and fpsMode() or nil
                    fpsClassSw:SetAlpha(m == "class" and 1 or 0.3)
                    fpsSwatch:SetAlpha(m == "custom" and 1 or 0.3)
                end
                NoxUI.RegisterWidgetRefresh(fpsUpdateState)
                fpsUpdateState()
            end
        end

        -- FPS Toggle Keybind (built into right region of fpsRow)
        if not NoxUI._prebuilding then
            local rightRgn = fpsRow._rightRegion
            local kbBtn, refresh = NoxUI.BuildKeybindButton(rightRgn, {
                w = 140, h = 30, font = 13,
                get = function() return NoxUIDB and NoxUIDB.fpsToggleKey end,
                set = function(fullKey)
                    if not NoxUIDB then NoxUIDB = {} end
                    local bindBtn = _G["EUI_FPSBindBtn"]
                    if not fullKey then
                        if NoxUIDB.fpsToggleKey and bindBtn then ClearOverrideBindings(bindBtn) end
                    elseif bindBtn then
                        -- Binding refused in combat: keep the old key.
                        if InCombatLockdown() then return end
                        ClearOverrideBindings(bindBtn)
                        SetOverrideBindingClick(bindBtn, true, fullKey, "EUI_FPSBindBtn")
                    end
                    NoxUIDB.fpsToggleKey = fullKey
                end,
            })
            PP.Point(kbBtn, "RIGHT", rightRgn, "RIGHT", -20, 0)
            NoxUI.RegisterWidgetRefresh(refresh)
        end

        -- Row 2: Low Durability Warning (left, with cog+eye+swatch) | Disable Right Click Targeting (right)
        local durWarnRow
        durWarnRow, h = W:DualRow(parent, y,
            { type="toggle", text="Low Durability Warning",
              tooltip="Flashes a warning on screen when any equipped item drops below the configured durability threshold. Only triggers out of combat.",
              getValue=function()
                return NoxUIDB and NoxUIDB.repairWarning ~= false
              end,
              setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.repairWarning = v
                if NoxUI._syncDurWarnEvents then NoxUI._syncDurWarnEvents() end
                if not v and NoxUI._durWarnHidePreview then
                    NoxUI._durWarnHidePreview()
                end
                NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Disable Right Click",
              tooltip="Suppresses right click targeting. Enemies applies everywhere. Allies In Combat only suppresses friendly targets while you are in combat, so you can still right click vendors and NPCs out of combat.\n\nNote: while this is active, holding Left+Right click to move forward won't work if your cursor is over a suppressed nameplate/unit, since this feature has to take over the right mouse button entirely to block targeting.",
              values={ ["_placeholder"]="..." }, order={ "_placeholder" },
              getValue=function() return "_placeholder" end,
              setValue=function() end }
        );  y = y - h

        -- Right slot: multi-select dropdown (Enemies / Allies In Combat).
        -- The backend stays two independent booleans; the dropdown is purely a
        -- front-end grouping, so existing disableRightClickTarget users are kept
        -- exactly as-is and Allies is additive (defaults off).
        if not NoxUI._prebuilding then
            local rcRgn = durWarnRow._rightRegion
            if rcRgn._control then rcRgn._control:Hide() end
            local rcItems = {
                { key = "enemy", label = "Enemies" },
                { key = "ally",  label = "Allies In Combat" },
            }
            local rcCB, rcCBRefresh = NoxUI.BuildVisOptsCBDropdown(
                rcRgn, 200, rcRgn:GetFrameLevel() + 2,
                rcItems,
                function(k)
                    if not NoxUIDB then return false end
                    if k == "enemy" then return NoxUIDB.disableRightClickTarget or false end
                    return NoxUIDB.disableRightClickTargetAllyCombat or false
                end,
                function(k, v)
                    if not NoxUIDB then NoxUIDB = {} end
                    if k == "enemy" then
                        NoxUIDB.disableRightClickTarget = v
                    else
                        NoxUIDB.disableRightClickTargetAllyCombat = v
                    end
                    if NoxUI._applyRightClickTarget then NoxUI._applyRightClickTarget() end
                end)
            PP.Point(rcCB, "RIGHT", rcRgn, "RIGHT", -20, 0)
            rcRgn._control = rcCB
            rcRgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(rcCBRefresh)
        end

        -- Inline: eyeball | color swatch | cog on the durability warning toggle
        do
            local leftRgn = durWarnRow._leftRegion
            local function durOff()
                return NoxUIDB and NoxUIDB.repairWarning == false
            end

            -- Cog popup for durability settings (rightmost inline, closest to toggle)
            NoxUI.BuildInlineCog(leftRgn, {
                title = "Durability Settings",
                rows = {
                    { type="slider", label="Text Size",
                      min=10, max=50, step=1,
                      get=function()
                        return (NoxUIDB and NoxUIDB.durWarnTextSize) or 30
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.durWarnTextSize = v
                        if NoxUI._durWarnApplySettings then NoxUI._durWarnApplySettings() end
                      end },
                    { type="slider", label="Y-Offset",
                      min=-600, max=600, step=1,
                      get=function()
                        return NoxUIDB and NoxUIDB.durWarnYOffset or 250
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.durWarnYOffset = v
                        NoxUIDB.durWarnPos = nil  -- clear custom pos so slider always takes effect
                        if NoxUI._durWarnPreview then NoxUI._durWarnPreview() end
                      end },
                    { type="slider", label="Repair %",
                      min=5, max=100, step=1,
                      get=function()
                        return NoxUIDB and NoxUIDB.durWarnThreshold or 40
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.durWarnThreshold = v
                      end },
                    NoxUI.IS_FOREVER and { type="toggle", label="Ignore Thrown Weapons",
                      tooltip="Thrown weapons lose durability with every throw.",
                      get=function()
                        return NoxUIDB and NoxUIDB.durWarnIgnoreThrown ~= false
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.durWarnIgnoreThrown = v
                        if NoxUI._syncDurWarnEvents then NoxUI._syncDurWarnEvents() end
                      end } or nil,
                },
                gap = 9, disabled = durOff, disabledTooltip = "Low Durability Warning",
            })

            if not NoxUI._prebuilding then
                -- Color swatch (left of the cog)
                local durSwGet = function()
                    local c = NoxUIDB and NoxUIDB.durWarnColor
                    if c then return c.r, c.g, c.b end
                    return 1, 0.27, 0.27
                end
                local durSwSet = function(r, g, b)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.durWarnColor = { r = r, g = g, b = b }
                    if NoxUI._applyDurWarn then NoxUI._applyDurWarn() end
                end
                local durSwatch, durUpdateSwatch = NoxUI.BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, durSwGet, durSwSet, nil, 20)
                PP.Point(durSwatch, "RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
                leftRgn._lastInline = durSwatch

                -- Disabled overlay for swatch when durability warning is off
                local durSwBlock = CreateFrame("Frame", nil, durSwatch)
                durSwBlock:SetAllPoints()
                durSwBlock:SetFrameLevel(durSwatch:GetFrameLevel() + 10)
                durSwBlock:EnableMouse(true)
                durSwBlock:SetScript("OnEnter", function()
                    NoxUI.ShowWidgetTooltip(durSwatch, NoxUI.DisabledTooltip("Low Durability Warning"))
                end)
                durSwBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

                NoxUI.RegisterWidgetRefresh(function()
                    local off = durOff()
                    if off then
                        durSwatch:SetAlpha(0.3)
                        durSwBlock:Show()
                    else
                        durSwatch:SetAlpha(1)
                        durSwBlock:Hide()
                    end
                    durUpdateSwatch()
                end)
                local durInitOff = durOff()
                durSwatch:SetAlpha(durInitOff and 0.3 or 1)
                if durInitOff then durSwBlock:Show() else durSwBlock:Hide() end

                -- Eye icon to toggle durability warning preview (left of swatch)
                local EYE_VISIBLE   = NoxUI.EYE_VISIBLE_ICON
                local EYE_INVISIBLE = NoxUI.EYE_INVISIBLE_ICON
                local durPreviewShown = false
                local eyeBtn = CreateFrame("Button", nil, leftRgn)
                eyeBtn:SetSize(26, 26)
                eyeBtn:SetPoint("RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
                leftRgn._lastInline = eyeBtn
                eyeBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
                NoxUI.SetGlyphAlpha(eyeBtn, durOff() and 0.15 or 0.4)
                local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
                eyeTex:SetAllPoints()
                local function RefreshDurEye()
                    if durPreviewShown then
                        eyeTex:SetTexture(EYE_INVISIBLE)
                    else
                        eyeTex:SetTexture(EYE_VISIBLE)
                    end
                end
                RefreshDurEye()
                eyeBtn:SetScript("OnEnter", function(self)
                    NoxUI.SetGlyphAlpha(self, 0.7)
                    NoxUI.ShowWidgetTooltip(self, "Preview durability warning")
                end)
                eyeBtn:SetScript("OnLeave", function(self)
                    NoxUI.HideWidgetTooltip()
                    NoxUI.SetGlyphAlpha(self, 0.4)
                end)
                eyeBtn:SetScript("OnClick", function(self)
                    durPreviewShown = not durPreviewShown
                    RefreshDurEye()
                    if durPreviewShown then
                        if NoxUI._applyDurWarn then NoxUI._applyDurWarn() end
                        if NoxUI._durWarnPreview then
                            NoxUI._durWarnPreview()
                        end
                    else
                        if NoxUI._durWarnHidePreview then
                            NoxUI._durWarnHidePreview()
                        end
                    end
                end)

                -- Blocking overlay for eye when durability warning is off
                local eyeBlock = CreateFrame("Frame", nil, eyeBtn)
                eyeBlock:SetAllPoints()
                eyeBlock:SetFrameLevel(eyeBtn:GetFrameLevel() + 10)
                eyeBlock:EnableMouse(true)
                eyeBlock:SetScript("OnEnter", function()
                    NoxUI.ShowWidgetTooltip(eyeBtn, NoxUI.DisabledTooltip("Low Durability Warning"))
                end)
                eyeBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

                NoxUI.RegisterWidgetRefresh(function()
                    local off = durOff()
                    if off then
                        durPreviewShown = false
                        RefreshDurEye()
                        NoxUI.SetGlyphAlpha(eyeBtn, 0.15)
                        eyeBlock:Show()
                    else
                        NoxUI.SetGlyphAlpha(eyeBtn, 0.4)
                        eyeBlock:Hide()
                    end
                end)
                local eyeInitOff = durOff()
                NoxUI.SetGlyphAlpha(eyeBtn, eyeInitOff and 0.15 or 0.4)
                if eyeInitOff then eyeBlock:Show() else eyeBlock:Hide() end
            end
        end

        -- Row 3: Secondary Stat Display (left, with cog+swatches) | Guild Chat Privacy (right)
        local row4
        row4, h = W:DualRow(parent, y,
            { type="toggle", text="Secondary Stat Display",
              tooltip=NoxUI.IS_FOREVER
                  and "Displays your character stats at the top left of the screen."
                  or "Displays secondary stat percentages (Crit, Haste, Mastery, Vers) at the top left of the screen.",
              getValue=function()
                return NoxUI.QoLExtrasGet("showSecondaryStats") or false
              end,
              setValue=function(v)
                NoxUI.QoLExtrasSet("showSecondaryStats", v)
                -- Turning the block off has to release an attached FPS readout
                -- back to its own frame, so route through the shared apply.
                if NoxUI._applyFPSDisplay then
                    NoxUI._applyFPSDisplay()
                elseif NoxUI._applySecondaryStats then
                    NoxUI._applySecondaryStats()
                end
                NoxUI:RefreshPage()
              end },
            { type="toggle", text="Guild Chat Privacy Cover",
              tooltip="Displays a spoiler tag over guild chat in the communities window that you can click to hide",
              getValue=function()
                return NoxUIDB and NoxUIDB.guildChatPrivacy or false
              end,
              setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.guildChatPrivacy = v
                if NoxUI._applyGuildChatPrivacy then NoxUI._applyGuildChatPrivacy() end
              end }
        );  y = y - h

        -- Inline cog + color swatches on Secondary Stat Display (left region)
        do
            local leftRgn = row4._leftRegion
            local function statsOff()
                return not NoxUI.QoLExtrasGet("showSecondaryStats")
            end

            -- Cog popup: stat visibility/order + tertiary swatch pair + Scale
            local function tsMode()
                local m = NoxUI.QoLExtrasGet("tertiaryStatsColorMode")
                if m then return m end
                -- No mode saved: an old profile with a stored color was using it.
                return NoxUI.QoLExtrasGet("tertiaryStatsColor") and "custom" or "class"
            end
            local function tsSetMode(v)
                NoxUI.QoLExtrasSet("tertiaryStatsColorMode", v)
                if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
            end
            local STAT_LABELS = {
                crit = "Crit", haste = "Haste", mastery = "Mastery", vers = "Versatility",
                leech = "Leech", avoidance = "Avoidance", speed = "Speed",
            }
            local TERTIARY_STATS = { leech = true, avoidance = true, speed = true }
            local DEFAULT_STAT_ORDER = {
                "crit", "haste", "mastery", "vers", "leech", "avoidance", "speed",
            }
            local function StatItems()
                local order = NoxUI._secondaryStatsOrder
                    and NoxUI._secondaryStatsOrder() or DEFAULT_STAT_ORDER
                local items = {}
                for _, key in ipairs(order) do
                    items[#items + 1] = { key = key, label = STAT_LABELS[key] }
                end
                return items
            end
            -- Key stays `coloredPercentages`: it is the shipped setting
            -- name, and renaming it would drop everyone's saved choice.
            local coloredRow = { type = "toggle", label = "Colored Values",
                get = function()
                    return NoxUI.QoLExtrasGet("coloredPercentages") or false
                end,
                set = function(v)
                    NoxUI.QoLExtrasSet("coloredPercentages", v)
                    if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                end }
            local abbreviateRow = { type = "toggle", label = "Abbreviate Stat Labels",
                get = function()
                    return NoxUI.QoLExtrasGet("secondaryStatsAbbreviateLabels") or false
                end,
                set = function(v)
                    NoxUI.QoLExtrasSet("secondaryStatsAbbreviateLabels", v)
                    if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                end }
            local scaleRow = { type = "slider", label = "Scale", min = 50, max = 200, step = 5,
                get = function()
                    local pos = NoxUI.QoLExtrasGet("secondaryStatsPos")
                    return math.floor(((pos and pos.scale) or 1.0) * 100 + 0.5)
                end,
                set = function(v)
                    -- Shallow-copy so we never mutate the shared account-wide
                    -- fallback table in place; the write lands per-profile.
                    local prev = NoxUI.QoLExtrasGet("secondaryStatsPos")
                    local newPos = {}
                    if prev then for pk, pv in pairs(prev) do newPos[pk] = pv end end
                    newPos.scale = v / 100
                    NoxUI.QoLExtrasSet("secondaryStatsPos", newPos)
                    if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                end }
            local cogRows, cogBtn, cogShow
            if NoxUI.IS_FOREVER then
                -- WoW Forever has no ratings or tertiaries: its stat catalog is
                -- picked in the grouped Choose Stats window
                -- (nui_confort_jeu_statistique_selection.lua) and the shown stats ordered here.
                local FV_STAT = NoxUI._ModuleNS["NoxUIConfortJeu"].FvStats.byKey
                cogRows = {
                    coloredRow,
                    abbreviateRow,
                    { type = "button", label = "Choose Stats...",
                      action = function()
                          -- The window takes the cog popup's place under the cog.
                          cogShow._popupFrame:Hide()
                          NoxUI._ShowStatPicker(cogBtn)
                      end },
                    { type = "reorder", label = "Reorder Shown Stats", maxVisible = 12,
                      items = function()
                          local hidden = NoxUI.QoLExtrasGet("secondaryStatsHidden")
                          local items = {}
                          for _, key in ipairs(NoxUI._secondaryStatsOrder()) do
                              if not (type(hidden) == "table" and hidden[key]) then
                                  items[#items + 1] = { key = key, label = NoxUI.L(FV_STAT[key].label) }
                              end
                          end
                          return items
                      end,
                      -- The hidden stats follow the shown ones, in their saved order.
                      set = function(keys)
                          local order, seen = {}, {}
                          for _, key in ipairs(keys) do
                              order[#order + 1] = key
                              seen[key] = true
                          end
                          for _, key in ipairs(NoxUI._secondaryStatsOrder()) do
                              if not seen[key] then order[#order + 1] = key end
                          end
                          NoxUI.QoLExtrasSet("secondaryStatsOrder", order)
                          NoxUI._applySecondaryStats()
                      end },
                    scaleRow,
                }
            else
                cogRows = {
                    coloredRow,
                    abbreviateRow,
                    { type = "toggle", label = "Show Raw Rating",
                      get = function()
                          return NoxUI.QoLExtrasGet("showSecondaryStatsRaw") or false
                      end,
                      set = function(v)
                          NoxUI.QoLExtrasSet("showSecondaryStatsRaw", v)
                          if v then NoxUI.QoLExtrasSet("showSecondaryStatsBoth", false) end
                          if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                      end },
                    { type = "toggle", label = "Show % and Raw",
                      get = function()
                          return NoxUI.QoLExtrasGet("showSecondaryStatsBoth") or false
                      end,
                      set = function(v)
                          NoxUI.QoLExtrasSet("showSecondaryStatsBoth", v)
                          if v then NoxUI.QoLExtrasSet("showSecondaryStatsRaw", false) end
                          if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                      end },
                    { type = "reordercheck", label = "Stats to Show",
                      items = StatItems,
                      hint = "Drag to Reorder",
                      get = function(key)
                          local hidden = NoxUI.QoLExtrasGet("secondaryStatsHidden")
                          return not (type(hidden) == "table" and hidden[key])
                      end,
                      set = function(key, shown)
                          local old = NoxUI.QoLExtrasGet("secondaryStatsHidden")
                          local hidden = {}
                          if type(old) == "table" then
                              for k, v in pairs(old) do hidden[k] = v end
                          end
                          if shown then
                              -- Tertiaries default off, so false is the explicit
                              -- per-profile override that keeps one checked.
                              if TERTIARY_STATS[key] then
                                  hidden[key] = false
                              else
                                  hidden[key] = nil
                              end
                          else
                              hidden[key] = true
                          end
                          NoxUI.QoLExtrasSet("secondaryStatsHidden", hidden)
                          if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                      end,
                      setOrder = function(keys)
                          local order = {}
                          for i, key in ipairs(keys) do order[i] = key end
                          NoxUI.QoLExtrasSet("secondaryStatsOrder", order)
                          if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                      end },
                    -- Class / custom swatch pair, the same convention as the
                    -- minimap border row: the active mode at full alpha, a
                    -- naming tooltip on each swatch.
                    { type = "multiswatch", label = "Tertiary Label Color",
                      disabled = function()
                          local hidden = NoxUI.QoLExtrasGet("secondaryStatsHidden")
                          return type(hidden) == "table"
                              and hidden.leech and hidden.avoidance and hidden.speed
                      end,
                      disabledTooltip = "a tertiary stat in Stats to Show",
                      swatches = {
                          { tooltip = "Class Color",
                            getValue = function()
                                local cc = NoxUI.GetClassColor(select(2, UnitClass("player")))
                                if cc then return cc.r, cc.g, cc.b end
                                return 1, 1, 1
                            end,
                            onClick = function() tsSetMode("class") end,
                            refreshAlpha = function() return tsMode() == "class" and 1 or 0.3 end },
                          { tooltip = "Custom Color",
                            getValue = function()
                                local c = NoxUI.QoLExtrasGet("tertiaryStatsColor")
                                if c then return c.r, c.g, c.b end
                                return 1, 1, 1
                            end,
                            setValue = function(r, g, b)
                                NoxUI.QoLExtrasSet("tertiaryStatsColor", { r = r, g = g, b = b })
                                NoxUI.QoLExtrasSet("tertiaryStatsColorMode", "custom")
                                if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                            end,
                            -- First click switches to custom; a second opens the picker.
                            onClick = function(self, ...)
                                if tsMode() ~= "custom" then tsSetMode("custom") return end
                                if self._eabOrigClick then self._eabOrigClick(self, ...) end
                            end,
                            refreshAlpha = function() return tsMode() == "custom" and 1 or 0.3 end },
                      } },
                    scaleRow,
                }
            end
            cogBtn, cogShow = NoxUI.BuildInlineCog(leftRgn, {
                title = "Secondary Stats Settings",
                rows = cogRows,
                disabled = statsOff, disabledTooltip = "Secondary Stat Display",
            })

            if not NoxUI._prebuilding then
                -- Inline default + class + custom colour swatches, following the
                -- minimap border's swatch-row convention: the active mode renders
                -- at full alpha, the others dimmed, each with a naming tooltip.
                local function ssMode()
                    local m = NoxUI.QoLExtrasGet("secondaryStatsColorMode")
                    if m then return m end
                    -- No mode saved: a stored color was in use, otherwise class
                    -- color -- the pre-mode default look.
                    return NoxUI.QoLExtrasGet("secondaryStatsColor") and "custom" or "class"
                end
                local ssUpdateState   -- forward: swatches reference it from OnClick
                local function ssSetMode(v)
                    NoxUI.QoLExtrasSet("secondaryStatsColorMode", v)
                    if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                    if ssUpdateState then ssUpdateState() end
                end

                -- Custom swatch (nearest the cog): stored custom colour. A
                -- click switches to custom mode first; a second click opens the
                -- picker (same two-step as the minimap border swatches).
                local ssCustom, ssUpdCustom = NoxUI.BuildColorSwatch(
                    leftRgn, leftRgn:GetFrameLevel() + 5,
                    function()
                        local c = NoxUI.QoLExtrasGet("secondaryStatsColor")
                        if c then return c.r, c.g, c.b end
                        return 1, 1, 1
                    end,
                    function(r, g, b)
                        NoxUI.QoLExtrasSet("secondaryStatsColor", { r = r, g = g, b = b })
                        NoxUI.QoLExtrasSet("secondaryStatsColorMode", "custom")
                        if NoxUI._applySecondaryStats then NoxUI._applySecondaryStats() end
                        if ssUpdateState then ssUpdateState() end
                    end, nil, 20)
                do
                    local openPicker = ssCustom:GetScript("OnClick")
                    ssCustom:SetScript("OnClick", function(self)
                        if ssMode() ~= "custom" then ssSetMode("custom") return end
                        if openPicker then openPicker(self) end
                    end)
                end
                PP.Point(ssCustom, "RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
                leftRgn._lastInline = ssCustom

                -- Class-colour swatch: live player class colour.
                local ssClass, ssUpdClass = NoxUI.BuildColorSwatch(
                    leftRgn, leftRgn:GetFrameLevel() + 5,
                    function()
                        local cc = NoxUI.GetClassColor(select(2, UnitClass("player")))
                        if cc then return cc.r, cc.g, cc.b end
                        return 1, 1, 1
                    end,
                    function() end, nil, 20)
                ssClass:SetScript("OnClick", function() ssSetMode("class") end)
                PP.Point(ssClass, "RIGHT", leftRgn._lastInline, "LEFT", -8, 0)
                leftRgn._lastInline = ssClass

                -- Multicolored swatch (outermost): the per-stat palette, previewed
                -- by its first hue (crit gold).
                local ssMulti, ssUpdMulti = NoxUI.BuildColorSwatch(
                    leftRgn, leftRgn:GetFrameLevel() + 5,
                    function() return 1, 209 / 255, 0 end,
                    function() end, nil, 20)
                ssMulti:SetScript("OnClick", function() ssSetMode("palette") end)
                PP.Point(ssMulti, "RIGHT", leftRgn._lastInline, "LEFT", -8, 0)
                leftRgn._lastInline = ssMulti

                local ssTips = { { ssMulti, "Multicolored" }, { ssClass, "Class Color" }, { ssCustom, "Custom Color" } }
                for _, e in ipairs(ssTips) do
                    e[1]:HookScript("OnEnter", function() NoxUI.ShowWidgetTooltip(e[1], e[2]) end)
                    e[1]:HookScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
                end

                -- Blocking overlays while Secondary Stat Display is off (shown from
                -- the single refresh below, like the swatch alphas).
                local ssBlocks = {}
                for _, e in ipairs(ssTips) do
                    local sw = e[1]
                    local block = CreateFrame("Frame", nil, sw)
                    block:SetAllPoints()
                    block:SetFrameLevel(sw:GetFrameLevel() + 10)
                    block:EnableMouse(true)
                    block:SetScript("OnEnter", function()
                        NoxUI.ShowWidgetTooltip(sw, NoxUI.DisabledTooltip("Secondary Stat Display"))
                    end)
                    block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
                    ssBlocks[#ssBlocks + 1] = block
                end

                -- While the display is off every swatch dims flat; while on, the
                -- active mode is bright and the others dimmed. One refresh owns
                -- both, plus the swatch fills (class color changes, custom picks).
                ssUpdateState = function()
                    if ssUpdCustom then ssUpdCustom() end
                    if ssUpdClass then ssUpdClass() end
                    if ssUpdMulti then ssUpdMulti() end
                    local off = statsOff()
                    for _, block in ipairs(ssBlocks) do block:SetShown(off) end
                    local m = not off and ssMode() or nil
                    ssMulti:SetAlpha(m == "palette" and 1 or 0.3)
                    ssClass:SetAlpha(m == "class" and 1 or 0.3)
                    ssCustom:SetAlpha(m == "custom" and 1 or 0.3)
                end
                NoxUI.RegisterWidgetRefresh(ssUpdateState)
                ssUpdateState()
            end
        end

        -- Row 4: Rested Indicator (left; mirrored in the Unit Frames player
        -- EXTRAS, NoxUI.RestedIndicatorCfg) |
        local restedRow
        restedRow, h = W:DualRow(parent, y,
            NoxUI.RestedIndicatorCfg(),
            { type="toggle", text="Target Distance (Range) Text",
              tooltip="Shows the approximate distance to your current target as movable on-screen text (default 30-35). Use the cog for format, alignment, and text size; use Unlock Mode to position or Anchor to your Player Frame.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.targetDistanceEnabled or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.targetDistanceEnabled = v
                  if NoxUI._applyTargetDistance then NoxUI._applyTargetDistance() end
                  NoxUI:RefreshPage()
              end }
        );  y = y - h

        -- Inline cog on Rested Indicator (left region): Animated, Size, X/Y offsets
        NoxUI.BuildRestedIndicatorCog(restedRow._leftRegion)

        -- Target Distance settings cog (right slot of the Rested row)
        do
            local rgn = restedRow._rightRegion
            local function tdOff()
                return not (NoxUIDB and NoxUIDB.targetDistanceEnabled)
            end

            local tdFormatValues = {
                range = "Range (30-35)",
                plus  = "Lower Bound (30+)",
                min   = "Minimum (30)",
            }
            local tdFormatOrder = { "range", "plus", "min" }
            local tdAlignValues = {
                LEFT   = "Left",
                CENTER = "Center",
                RIGHT  = "Right",
            }
            local tdAlignOrder = { "LEFT", "CENTER", "RIGHT" }

            NoxUI.BuildInlineCog(rgn, {
                title = "Target Distance Settings",
                minWidth = 280,
                rows = {
                    { type="dropdown", label="Format",
                      values=tdFormatValues, order=tdFormatOrder,
                      get=function()
                        local f = NoxUIDB and NoxUIDB.targetDistanceFormat
                        if f == "plus" or f == "min" or f == "range" then return f end
                        return "range"
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.targetDistanceFormat = v
                        if NoxUI._applyTargetDistanceFrame then NoxUI._applyTargetDistanceFrame() end
                      end },
                    { type="dropdown", label="Text Align",
                      values=tdAlignValues, order=tdAlignOrder,
                      get=function()
                        local a = NoxUIDB and NoxUIDB.targetDistanceAlign
                        if a == "LEFT" or a == "CENTER" or a == "RIGHT" then return a end
                        return "CENTER"
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.targetDistanceAlign = v
                        if NoxUI._applyTargetDistanceFrame then NoxUI._applyTargetDistanceFrame() end
                      end },
                    { type="slider", label="Text Size",
                      min=10, max=48, step=1,
                      get=function()
                        return (NoxUIDB and NoxUIDB.targetDistanceTextSize) or 18
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.targetDistanceTextSize = v
                        if NoxUI._applyTargetDistanceFrame then NoxUI._applyTargetDistanceFrame() end
                      end },
                    { type="dropdown", label="Frame Strata",
                      tooltip="Controls the order that overlapping elements display in. Set higher to show above other elements.",
                      values = NoxUI.FRAME_STRATA_LABELS,
                      order = NoxUI.FRAME_STRATA_ORDER_BASE,
                      get=function()
                        return (NoxUIDB and NoxUIDB.targetDistanceStrata) or "HIGH"
                      end,
                      set=function(v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB.targetDistanceStrata = v
                        if NoxUI._applyTargetDistanceFrame then NoxUI._applyTargetDistanceFrame() end
                      end },
                },
                footer = { unlockKey = "EUI_TargetDistance" },
                gap = 9, disabled = tdOff, disabledTooltip = "Target Distance (Range) Text",
            })
        end

        -- Row 5: Environment Ping keybind (left) | Show Coordinates on Map (+ cog)
        local pingRow
        pingRow, h = W:DualRow(parent, y,
            { type="label", text="Environment Ping" },
            { type="toggle", text="Show Coordinates on Map",
              tooltip="Displays cursor and player coordinates at the bottom of the world map.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.mapCoords or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.mapCoords = v
                  if NoxUI._applyMapCoords then NoxUI._applyMapCoords() end
                  NoxUI:RefreshPage()
              end }
        );  y = y - h
        -- Cog on Show Coordinates on Map (right region)
        do
            local function coordsOff()
                return not (NoxUIDB and NoxUIDB.mapCoords)
            end
            NoxUI.BuildInlineCog(pingRow._rightRegion, {
                title = "Map Coordinates Settings",
                rows = {
                    { type = "slider", label = "Text Size", min = 8, max = 24, step = 1,
                      get = function()
                          return (NoxUIDB and NoxUIDB.mapCoordsTextSize) or 12
                      end,
                      set = function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.mapCoordsTextSize = v
                          if NoxUI._applyMapCoords then NoxUI._applyMapCoords() end
                      end },
                },
                gap = 9, disabled = coordsOff, disabledTooltip = "Show Coordinates on Map",
            })
        end
        if not NoxUI._prebuilding then
            local rgn = pingRow._leftRegion
            local kbBtn, refresh = NoxUI.BuildKeybindButton(rgn, {
                w = 140, h = 30, font = 13, mouse = true,
                get = function() return NoxUIDB.envPingKey end,
                set = function(v)
                    -- The hold key cannot be the button it claims.
                    local base = v and v:match("[^%-]+$")
                    if base == "BUTTON1" or base == "BUTTON2" then return end
                    NoxUIDB.envPingKey = v
                    if NoxUI._applyEnvPing then NoxUI._applyEnvPing() end
                end,
                tooltip = "While held, left-clicking the world sends a ping that ignores units and only targets the environment.\n\nLeft-click to set a keybind.\nRight-click to unbind.",
            })
            PP.Point(kbBtn, "RIGHT", rgn, "RIGHT", -20, 0)
            NoxUI.RegisterWidgetRefresh(refresh)
        end

        -- Auto-Accept Resurrection: right of Row 6, or its own row on WoW Forever.
        local resCfg = { type="toggle", text="Auto-Accept Resurrection",
            tooltip="Automatically accepts resurrections from players who are out of combat, such as raid resses after a wipe. Use the cog to also accept combat resurrections.",
            getValue=function()
                return NoxUIDB and NoxUIDB.autoAcceptRes or false
            end,
            setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.autoAcceptRes = v
                if NoxUI._applyAutoAcceptRes then NoxUI._applyAutoAcceptRes() end
                NoxUI:RefreshPage()
            end }
        local function BuildResCog(rgn)
            NoxUI.BuildInlineCog(rgn, {
                title = "Auto-Accept Resurrection",
                rows = {
                    { type="toggle", label="Accept Combat Resurrections",
                      get=function()
                          return NoxUIDB and NoxUIDB.autoAcceptResCombat or false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoAcceptResCombat = v
                      end },
                },
                gap = 9,
                disabled = function() return not (NoxUIDB and NoxUIDB.autoAcceptRes) end,
                disabledTooltip = "Auto-Accept Resurrection",
            })
        end

        -- Row 6: Transparent World Map Sidebars (left) | Auto-Accept Resurrection. Not offered
        -- on WoW Forever: Forever Essentials has its own map background option there.
        if not NoxUI.IS_FOREVER then
            local sidebarsRow
            sidebarsRow, h = W:DualRow(parent, y,
                { type="toggle", text="Transparent World Map Sidebars",
                  tooltip="Clears the black bars beside the maximized map.",
                  getValue=function()
                      return NoxUIDB and NoxUIDB.mapSidebarsClear or false
                  end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.mapSidebarsClear = v
                      if NoxUI._applyMapSidebars then NoxUI._applyMapSidebars() end
                      NoxUI:RefreshPage()
                  end },
                resCfg
            );  y = y - h
            BuildResCog(sidebarsRow._rightRegion)
            -- Cog on Transparent World Map Sidebars (left region)
            do
                local function sidebarsOff()
                    return not (NoxUIDB and NoxUIDB.mapSidebarsClear)
                end
                NoxUI.BuildInlineCog(sidebarsRow._leftRegion, {
                    title = "World Map Sidebars Settings",
                    rows = {
                        { type = "slider", label = "Opacity", min = 0, max = 100, step = 5,
                          get = function()
                              return (NoxUIDB and NoxUIDB.mapSidebarsOpacity) or 0
                          end,
                          set = function(v)
                              if not NoxUIDB then NoxUIDB = {} end
                              NoxUIDB.mapSidebarsOpacity = v
                              if NoxUI._applyMapSidebars then NoxUI._applyMapSidebars() end
                          end },
                        { type = "toggle", label = "Click Through",
                          tooltip = "Lets clicks and camera turns pass through.",
                          get = function()
                              return not (NoxUIDB and NoxUIDB.mapSidebarsClickThrough == false)
                          end,
                          set = function(v)
                              if not NoxUIDB then NoxUIDB = {} end
                              -- Stored only when off: unset reads as on.
                              if v then
                                  NoxUIDB.mapSidebarsClickThrough = nil
                              else
                                  NoxUIDB.mapSidebarsClickThrough = false
                              end
                              if NoxUI._applyMapSidebars then NoxUI._applyMapSidebars() end
                          end },
                    },
                    gap = 9, disabled = sidebarsOff, disabledTooltip = "Transparent World Map Sidebars",
                })
            end
        else
            local resRow
            resRow, h = W:DualRow(parent, y, resCfg, NoxUI.BlankRowCfg());  y = y - h
            BuildResCog(resRow._leftRegion)
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        ---------------------------------------------------------------------------
        --  CROSSHAIR
        ---------------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "CROSSHAIR", y);  y = y - h

        -- Crosshair: per-profile live in the QoL DB (_ECL_AceDB.profile),
        -- with the account-wide NoxUIDB root as the inherited default.
        local function cdb() return _G._ECL_AceDB and _G._ECL_AceDB.profile end
        local function cget(k)
            local p = cdb()
            if p and p[k] ~= nil then return p[k] end
            return NoxUIDB and NoxUIDB[k]
        end
        local function cset(k, v) local p = cdb(); if p then p[k] = v end end
        local function crosshairOff()
            return (cget("crosshairSize") or "None") == "None"
        end

        -- True when the effective thickness is custom (would display as
        -- "Custom" if enabled) -- i.e. H/V widths differ or don't match a preset.
        -- Checked regardless of None so a saved custom config can be restored.
        local function crosshairIsCustom()
            local P = NoxUI.CROSSHAIR_PRESETS
            local s = cget("crosshairSize")
            local sizeForBase = (s and s ~= "None" and s) or "Normal"
            local base = (P and (P[sizeForBase] or P.Normal)) or { width = 2 }
            local hw = cget("crosshairHWidth") or base.width
            local vw = cget("crosshairVWidth") or base.width
            if hw ~= vw then return true end
            if P then
                for _, p in pairs(P) do if p.width == hw then return false end end
            end
            return true
        end

        -- Row 1: Character Crosshair (left: dropdown + cog + swatch) | Visibility
        local crosshairRow
        crosshairRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Character Crosshair",
              tooltip="Displays a crosshair at the center of the screen.",
              -- "Custom" is only selectable when a custom thickness is
              -- stored (re-evaluated each time the menu opens); otherwise it's
              -- greyed, since picking it would just produce a preset look.
              itemDisabled=function(v) return v == "custom" and not crosshairIsCustom() end,
			  itemDisabledTooltip=function(v)
				if v == "custom" then return "This option requires a custom thickness to be set." end
      		  end,
              -- The shown value is derived from the actual thickness: a preset name
              -- when the width matches one, otherwise "Custom". "Custom" is also
              -- selectable -- picking it re-enables using the user's stored values
              values={ ["None"]="None", ["Thin"]="Thin", ["Normal"]="Normal", ["Thick"]="Thick", ["custom"]="Custom" },
              order={ "None", "Thin", "Normal", "Thick", "custom" },
              getValue=function()
                local size = cget("crosshairSize") or "None"
                if size == "None" then return "None" end
                local P = NoxUI.CROSSHAIR_PRESETS
                local base = (P and (P[size] or P.Normal)) or { width = 2 }
                local hw = cget("crosshairHWidth") or base.width
                local vw = cget("crosshairVWidth") or base.width
                if hw == vw and P then
                    for name, p in pairs(P) do
                        if p.width == hw then return name end
                    end
                end
                return "custom"
              end,
              setValue=function(v)
                local p = cdb()
                if not p then return end
                p.crosshairSize = v
                -- Presets exist mainly for backwards compatibility. They stamp
                -- only the thickness baseline so Thin/Normal/Thick stay distinct
                -- and the cog reflects them. Length is not touched: it defaults
                -- to the preset length (40) only while unset, and once a user
                -- customises it, it persists across preset changes.
                local preset = NoxUI.CROSSHAIR_PRESETS and NoxUI.CROSSHAIR_PRESETS[v]
                if preset then
                    p.crosshairHWidth = preset.width
                    p.crosshairVWidth = preset.width
                end
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
                NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Visibility",
              tooltip="Choose when the crosshair is shown.",
              disabled=function() return crosshairOff() end,
              disabledTooltip="Enable the crosshair to set its visibility.", rawTooltip=true,
              -- Real control is a multi-select checkbox dropdown injected below;
              -- this placeholder just provides the labelled right-region slot.
              values={ ["_placeholder"]="..." }, order={ "_placeholder" },
              getValue=function() return "_placeholder" end,
              setValue=function() end }
        );  y = y - h

        -- Visibility: multi-select checkbox dropdown (Always / Combat / Instances),
        -- backed by the single crosshairVisibility string for backwards compat:
        --   always | combat | instances | instances_combat
        -- "Always" is the base state. Picking it
        -- clears the others; clearing both reverts to it.
        if not NoxUI._prebuilding then
            local visRgn = crosshairRow._rightRegion
            if visRgn._control then visRgn._control:Hide() end

            local function curVis() return cget("crosshairVisibility") or "always" end
            local visItems = {
                { key = "always",    label = "Always",
                  tooltip = "Always show the crosshair." },
                { key = "combat",    label = "Combat",
                  tooltip = "Show only while in combat. Combine with Instances to show only during instanced combat." },
                { key = "instances", label = "Instances",
                  tooltip = "Show only while in a dungeon, raid, arena or battleground. Combine with Combat to show only during instanced combat." },
            }
            local visCB, visCBRefresh = NoxUI.BuildVisOptsCBDropdown(
                visRgn, 200, visRgn:GetFrameLevel() + 2,
                visItems,
                function(k)
                    local v = curVis()
                    if k == "always"    then return v == "always" end
                    if k == "combat"    then return v == "combat" or v == "instances_combat" end
                    return v == "instances" or v == "instances_combat"
                end,
                function(k, on)
                    local v = curVis()
                    local combat    = (v == "combat" or v == "instances_combat")
                    local instances = (v == "instances" or v == "instances_combat")
                    if k == "always" then
                        if not on then return end  -- can't un-pick the base state directly
                        combat, instances = false, false
                    elseif k == "combat" then
                        combat = on
                    else
                        instances = on
                    end
                    local nv = "always"
                    if combat and instances then nv = "instances_combat"
                    elseif combat then nv = "combat"
                    elseif instances then nv = "instances" end
                    cset("crosshairVisibility", nv)
                    if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
                end)
            PP.Point(visCB, "RIGHT", visRgn, "RIGHT", -20, 0)
            visRgn._control = visCB
            visRgn._lastInline = nil

            -- Disabled overlay: grey + block when the crosshair is off, matching
            -- the placeholder's disabled state.
            local visBlock = CreateFrame("Frame", nil, visCB)
            visBlock:SetAllPoints()
            visBlock:SetFrameLevel(visCB:GetFrameLevel() + 20)
            visBlock:EnableMouse(true)
            visBlock:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(visCB, "Enable the crosshair to set its visibility.")
            end)
            visBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            local function visUpdateDisabled()
                if crosshairOff() then
                    visCB:SetAlpha(0.4); visBlock:Show()
                else
                    visCB:SetAlpha(1); visBlock:Hide()
                end
            end
            NoxUI.RegisterWidgetRefresh(visCBRefresh)
            NoxUI.RegisterWidgetRefresh(visUpdateDisabled)
            visUpdateDisabled()
        end

        -- Inline cog on the crosshair dropdown (left region) for expanded options
        do
            local leftRgn = crosshairRow._leftRegion
            local function chCogOff() return crosshairOff() end
            local function presetThick()
                local s = cget("crosshairSize")
                local P = NoxUI.CROSSHAIR_PRESETS
                local p = P and (P[s] or P.Normal)
                return (p and p.width) or 2
            end
            local function applyCH()
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
            end
            local function dbset(k, v)
                cset(k, v)
                applyCH()
            end
            -- Re-resolve the size dropdown's label so it shows "Custom" (or snaps
            -- back to a preset) live when the thickness is changed in this cog.
            local function refreshSizeLabel()
                local ctrl = crosshairRow._leftRegion and crosshairRow._leftRegion._control
                if ctrl and ctrl._refreshLabel then ctrl._refreshLabel() end
            end

            local chCogRows = {
                    { type="slider", label="H Length", min=1, max=500, step=1,
                      get=function() return cget("crosshairHLength") or 40 end,
                      set=function(v) dbset("crosshairHLength", v) end },
                    { type="slider", label="H Width", min=1, max=20, step=1,
                      get=function() return cget("crosshairHWidth") or presetThick() end,
                      set=function(v) dbset("crosshairHWidth", v); refreshSizeLabel() end },
                    { type="slider", label="V Length", min=1, max=500, step=1,
                      get=function() return cget("crosshairVLength") or 40 end,
                      set=function(v) dbset("crosshairVLength", v) end },
                    { type="slider", label="V Width", min=1, max=20, step=1,
                      get=function() return cget("crosshairVWidth") or presetThick() end,
                      set=function(v) dbset("crosshairVWidth", v); refreshSizeLabel() end },
                    { type="slider", label="Border", min=0, max=5, step=1,
                      get=function() return cget("crosshairBorderSize") or 0 end,
                      set=function(v) dbset("crosshairBorderSize", v) end },
                    { type="colorpicker", label="Border Color", hasAlpha=true,
                      get=function()
                          local bc = cget("crosshairBorderColor")
                          if bc then return bc.r, bc.g, bc.b, bc.a end
                          return 0, 0, 0, 1
                      end,
                      set=function(r, g, b, a)
                          cset("crosshairBorderColor", { r = r, g = g, b = b, a = a or 1 })
                          applyCH()
                      end },
                    { type="slider", label="X Offset", min=-200, max=200, step=1,
                      get=function() return cget("crosshairXOffset") or 0 end,
                      set=function(v) dbset("crosshairXOffset", v) end },
                    { type="slider", label="Y Offset", min=-200, max=200, step=1,
                      get=function() return cget("crosshairYOffset") or 0 end,
                      set=function(v) dbset("crosshairYOffset", v) end },
                    { type="dropdown", label="Frame Strata",
                      tooltip="Controls the order that overlapping elements display in. Set higher to show above other elements.",
                      values = NoxUI.FRAME_STRATA_LABELS,
                      order = NoxUI.FRAME_STRATA_ORDER_BASE,
                      get=function() return cget("crosshairStrata") or "MEDIUM" end,
                      set=function(v) dbset("crosshairStrata", v) end },
            }
            -- Holy Paladin uses a 40yd out-of-range cutoff by default; let
            -- paladins opt into a melee (5yd) cutoff. Shown only for Paladins.
            if select(2, UnitClass("player")) == "PALADIN" then
                chCogRows[#chCogRows + 1] = {
                    type="toggle", label="Show Melee Range for Hpal",
                    get=function() return cget("crosshairHpalMelee") == true end,
                    set=function(v)
                        cset("crosshairHpalMelee", v)
                        if NoxUI._RefreshCrosshairCutoffRange then NoxUI._RefreshCrosshairCutoffRange() end
                        applyCH()
                    end,
                }
            end

            NoxUI.BuildInlineCog(leftRgn, {
                title = "Crosshair Options",
                rows = chCogRows,
                gap = 9, disabled = chCogOff, disabledTooltip = "Character Crosshair",
            })
        end

        -- Inline color swatch on the crosshair dropdown (left region)
        if not NoxUI._prebuilding then
            local leftRgn = crosshairRow._leftRegion

            local chSwGet = function()
                local c = cget("crosshairColor")
                if c then return c.r, c.g, c.b, c.a end
                return 1, 1, 1, 0.75
            end
            local chSwSet = function(r, g, b, a)
                cset("crosshairColor", { r = r, g = g, b = b, a = a or 1 })
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
            end
            local chSwatch, chUpdateSwatch = NoxUI.BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, chSwGet, chSwSet, true, 20)
            PP.Point(chSwatch, "RIGHT", leftRgn._lastInline or leftRgn._control, "LEFT", -8, 0)
            leftRgn._lastInline = chSwatch

            local chSwBlock = CreateFrame("Frame", nil, chSwatch)
            chSwBlock:SetAllPoints()
            chSwBlock:SetFrameLevel(chSwatch:GetFrameLevel() + 10)
            chSwBlock:EnableMouse(true)
            chSwBlock:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(chSwatch, NoxUI.DisabledTooltip("Character Crosshair"))
            end)
            chSwBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

            NoxUI.RegisterWidgetRefresh(function()
                local off = crosshairOff()
                if off then
                    chSwatch:SetAlpha(0.3)
                    chSwBlock:Show()
                else
                    chSwatch:SetAlpha(1)
                    chSwBlock:Hide()
                end
                chUpdateSwatch()
            end)
            local chInitOff = crosshairOff()
            chSwatch:SetAlpha(chInitOff and 0.3 or 1)
            if chInitOff then chSwBlock:Show() else chSwBlock:Hide() end
        end

        -- Color Out of Range (toggle + inline color picker)
        local meleeRow
        meleeRow, h = W:DualRow(parent, y,
            { type="toggle", text="Color Out of Range",
              tooltip=function()
                  local s = NoxUI.L("Changes the crosshair color when your current target is out of range.")
                  if NoxUI._getCrosshairCutoffRange then
                      local range = NoxUI._getCrosshairCutoffRange()
                      s = s .. " " .. NoxUI.Lf("Currently active range cutoff: %1$syd.", range)
                  end
                  return s
              end,
              disabled=function() return crosshairOff() end,
              disabledTooltip="Enable the crosshair to use this option.", rawTooltip=true,
              getValue=function() return cget("crosshairMeleeColorEnabled") == true end,
              setValue=function(v)
                cset("crosshairMeleeColorEnabled", v)
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
                NoxUI:RefreshPage()
              end },
            { type="label", text="" }
        );  y = y - h
        -- Inline color swatch (disabled when toggle is off or crosshair is None)
        if not NoxUI._prebuilding then
            local leftRgn = meleeRow._leftRegion
            local function meleeOff()
                return crosshairOff() or cget("crosshairMeleeColorEnabled") ~= true
            end
            local mcGet = function()
                local c = cget("crosshairMeleeColor")
                if c then return c.r, c.g, c.b, c.a end
                return 1, 0, 0, 1
            end
            local mcSet = function(r, g, b, a)
                cset("crosshairMeleeColor", { r = r, g = g, b = b, a = a or 1 })
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
            end
            local mcSwatch, mcUpdate = NoxUI.BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, mcGet, mcSet, true, 20)
            PP.Point(mcSwatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            leftRgn._lastInline = mcSwatch

            local mcBlock = CreateFrame("Frame", nil, mcSwatch)
            mcBlock:SetAllPoints()
            mcBlock:SetFrameLevel(mcSwatch:GetFrameLevel() + 10)
            mcBlock:EnableMouse(true)
            mcBlock:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(mcSwatch, NoxUI.DisabledTooltip("Color Out of Range"))
            end)
            mcBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            NoxUI.RegisterWidgetRefresh(function()
                local off = meleeOff()
                mcSwatch:SetAlpha(off and 0.3 or 1)
                if off then mcBlock:Show() else mcBlock:Hide() end
                mcUpdate()
            end)
            local mcInitOff = meleeOff()
            mcSwatch:SetAlpha(mcInitOff and 0.3 or 1)
            if mcInitOff then mcBlock:Show() else mcBlock:Hide() end
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        ---------------------------------------------------------------------------
        --  GROUP FINDER (INSTANCES on WoW Forever)
        ---------------------------------------------------------------------------
        _, h = W:SectionHeader(parent, NoxUI.IS_FOREVER and "INSTANCES" or "GROUP FINDER", y);  y = y - h

        -- Auto Insert Keystone | Announce Instance Reset, then Quick Signup |
        -- Persistent Signup Note, which Group Finder's settings page mirrors (the
        -- same account-wide switches). WoW Forever has no keystones and no premade
        -- group list, so only Announce Instance Reset is built there.
        local autoKeyCfg = { type="toggle", text="Auto Insert Keystone",
              tooltip="Automatically inserts your key into the Font of Power.",
              getValue=function()
                  if not NoxUIDB then return true end
                  return NoxUIDB.autoInsertKeystone ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoInsertKeystone = v
              end }
        local announceCfg = { type="toggle", text="Announce Instance Reset",
              tooltip="After a successful instance reset, automatically announces it in party or raid chat so your group knows they can re-enter.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.instanceResetAnnounce or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.instanceResetAnnounce = v
                  if NoxUI._applyInstanceResetAnnounce then
                      NoxUI._applyInstanceResetAnnounce()
                  end
              end }
        local quickCfg = { type="toggle", text="Quick Signup",
              tooltip="Double-click a group listing to instantly sign up without pressing the Sign Up button. Hold Shift to keep the dialog open, e.g. to type a signup note.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.quickSignup or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.quickSignup = v
                  NoxUI._applyQuickSignup()
              end }
        local persistCfg = { type="toggle", text="Persistent Signup Note",
              tooltip="Keeps a saved signup note you can copy into the Sign Up dialog with the Copy button.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.persistSignupNote or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.persistSignupNote = v
                  NoxUI._applyPersistSignupNote()
                  NoxUI:RefreshPage()
              end }
        local noteRow
        if NoxUI.IS_FOREVER then
            _, h = W:DualRow(parent, y, announceCfg, NoxUI.BlankRowCfg());  y = y - h
        else
            _, h = W:DualRow(parent, y, autoKeyCfg, announceCfg);  y = y - h
            noteRow, h = W:DualRow(parent, y, quickCfg, persistCfg);  y = y - h
        end

        if noteRow then
            local rightRgn = noteRow._rightRegion
            local function persistOff()
                return not (NoxUIDB and NoxUIDB.persistSignupNote)
            end

            NoxUI.BuildInlineCog(rightRgn, {
                gap = 9, tip = "Edit the saved signup note.",
                disabled = persistOff, disabledTooltip = "Persistent Signup Note",
                show = function()
                    NoxUI:ShowInputPopup({
                        title="Signup Note",
                        message="Saved between reloads and relogs. In Group Finder, choose Copy, press Ctrl+C, then Ctrl+V.",
                        placeholder="Enter signup note...",
                        initialText=NoxUI.GetPersistentSignupNote(),
                        maxLetters=63,
                        inputHeight=70,
                        multiline=true,
                        showCount=true,
                        allowEmpty=true,
                        confirmText="Save",
                        onConfirm=function(note)
                            NoxUI.SetPersistentSignupNote(note or "")
                        end,
                    })
                end,
            })
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        ---------------------------------------------------------------------------
        --  UI
        ---------------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "UI", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Hide Screenshot Status",
              tooltip="Hides the 'Screenshot saved' notification that appears on screen after taking a screenshot.",
              getValue=function()
                  if not NoxUIDB then return true end
                  return NoxUIDB.hideScreenshotStatus ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.hideScreenshotStatus = v
                  if NoxUI._applyScreenshotStatus then
                      NoxUI._applyScreenshotStatus()
                  end
              end },
            { type="toggle", text="Train All Button",
              tooltip="Adds a 'Train All' button next to the Train button at profession trainers, allowing you to learn all available skills with one click.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.trainAllButton or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.trainAllButton = v
                  if NoxUI._applyTrainAllButton then
                      NoxUI._applyTrainAllButton()
                  end
              end }
        );  y = y - h

        -- Auto Unwrap Collections | Auto Open Containers
        local autoOpenContainerRow
        autoOpenContainerRow, h = W:DualRow(parent, y,
            { type="toggle", text="Auto Unwrap Collections",
              tooltip="Automatically dismisses the 'new mount/pet/toy' fanfare notification when you receive one, so you don't have to click through the collections journal.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.autoUnwrapCollections or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoUnwrapCollections = v
                  if NoxUI._applyAutoUnwrap then
                      NoxUI._applyAutoUnwrap()
                  end
              end },
            { type="toggle", text="Auto Open Containers",
              tooltip="Automatically opens bags, boxes and parcels in your inventory when they are added to your bags.\n\nContainers received from the mailbox are held until you close the mailbox, so opening them cannot collide with mail still delivering items.",
              getValue=function()
                  if not NoxUIDB then return false end
                  return NoxUIDB.autoOpenContainers == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.autoOpenContainers = v
                  if NoxUI._applyAutoOpenContainers then
                      NoxUI._applyAutoOpenContainers()
                  end
                  NoxUI:RefreshPage()
              end }
        );  y = y - h

        -- Cog on Auto Open Containers (right region)
        do
            local rightRgn = autoOpenContainerRow._rightRegion
            local function autoOpenContainerOff()
                return not (NoxUIDB and NoxUIDB.autoOpenContainers == true)
            end

            NoxUI.BuildInlineCog(rightRgn, {
                title = "Auto Open Containers Settings",
                rows = {
                    { type="toggle", label="Exclude Warbound Containers",
                      get=function()
                          if not NoxUIDB then return true end
                          return NoxUIDB.autoOpenContainersExcludeWarbound ~= false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoOpenContainersExcludeWarbound = v
                      end },
                    { type="toggle", label="Hold Capped Artisan Payouts",
                      tooltip="Keeps Artisan's Consortium Payouts closed while Shard of Dundun is at its maximum, then resumes automatic opening after you spend shards.",
                      get=function()
                          return NoxUIDB
                              and NoxUIDB.autoOpenContainersHoldCappedArtisanPayouts == true
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.autoOpenContainersHoldCappedArtisanPayouts = v
                          if NoxUI._applyAutoOpenContainers then
                              NoxUI._applyAutoOpenContainers()
                          end
                      end },
                },
                gap = 9, disabled = autoOpenContainerOff, disabledTooltip = "Auto Open Containers",
            })
        end

        -- Bonus Roll Confirmation. Not offered on WoW Forever: no bonus rolls
        -- there, so the row is not built and the runtime block does not exist.
        if not NoxUI.IS_FOREVER then
        local bonusRollRow
        local function bonusRollConflict()
            return C_AddOns.IsAddOnLoaded("BonusRollConfirm")
        end
        bonusRollRow, h = W:DualRow(parent, y,
            { type="toggle", text=NoxUI.L("Bonus Roll Confirmation"),
              tooltip=NoxUI.L("Asks before spending a bonus roll and shows your loot specialization. Use the cog to also confirm Pass."),
              disabled=bonusRollConflict,
              disabledTooltip=NoxUI.L("BonusRollConfirm is loaded and handles confirmation. Disable that addon and reload to use this feature."),
              rawTooltip=true,
              getValue=function()
                  return NoxUIDB and NoxUIDB.bonusRollConfirmation == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.bonusRollConfirmation = v
                  if NoxUI._applyBonusRollConfirmation then NoxUI._applyBonusRollConfirmation() end
                  NoxUI:RefreshPage()
              end },
            NoxUI.BlankRowCfg()
        );  y = y - h
        do
            NoxUI.BuildInlineCog(bonusRollRow._leftRegion, {
                title = NoxUI.L("Bonus Roll Settings"),
                rows = {
                    { type="toggle", label=NoxUI.L("Only Confirm Roll"),
                      tooltip=NoxUI.L("Pass immediately without confirmation. Turn off to confirm both Roll and Pass."),
                      get=function()
                          return not NoxUIDB or NoxUIDB.bonusRollOnly ~= false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.bonusRollOnly = v
                          if NoxUI._applyBonusRollConfirmation then NoxUI._applyBonusRollConfirmation() end
                      end },
                },
                gap = 9,
                disabled = function()
                    return bonusRollConflict() or not (NoxUIDB and NoxUIDB.bonusRollConfirmation)
                end,
                disabledTooltip = NoxUI.L("Bonus Roll Confirmation"),
            })
        end
        end -- not IS_FOREVER

        -- Keys, Logs & Brez sections live at the bottom of this page (the
        -- separate tab was retired to keep the tab bar at five pages).
        if _G._EUI_BuildAutoLoggingPage then
            _, h = W:Spacer(parent, y, 16);  y = y - h
            local alH = _G._EUI_BuildAutoLoggingPage(pageName, parent, y)
            if alH then y = y - alH end
        end

        return math.abs(y)
    end

    local function BuildCharacters(parent, y)
        local W = NoxUI.Widgets
        local _, h = W:SectionHeader(parent, "Character Overview", y)
        y = y - h
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Recipes for Other Characters",
              tooltip="To record learned recipes, open each profession once on each character.",
              getValue=function() return NoxUIDB.nuiAltRecipeTips == true end,
              setValue=function(v) NoxUIDB.nuiAltRecipeTips = v end },
            { type="button", text="Refresh Character Overview", onClick=function() NoxUI:RefreshPage(true) end })
        y = y - h - 12
        if NoxUI._prebuilding then return math.abs(y) end
        local function PutRow(values, highlighted)
            local row = CreateFrame("Frame", nil, parent)
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", 0, y)
            row:SetHeight(30)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(.12, .15, .18, highlighted and .85 or .36)
            local weights = { .28, .19, .14, .16, .23 }
            local cells = {}
            for i, value in ipairs(values) do
                local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetJustifyH(i == 1 and "LEFT" or "CENTER")
                label:SetWordWrap(false)
                label:SetText(value)
                if highlighted then label:SetTextColor(.72, .76, .80) end
                cells[i] = label
            end
            local function Layout(_, width)
                local x = 0
                for i, label in ipairs(cells) do
                    label:ClearAllPoints()
                    label:SetPoint("LEFT", row, "LEFT", x + 8, 0)
                    label:SetWidth(math.max(1, width * weights[i] - 16))
                    x = x + width * weights[i]
                end
            end
            row:SetScript("OnSizeChanged", Layout)
            Layout(row, row:GetWidth())
            y = y - 32
        end
        PutRow({ NoxUI.L("Character"), NoxUI.L("Gold"), NoxUI.L("Free Bag Slots"),
            NoxUI.L("Rested XP"), NoxUI.L("Last Mail Check") }, true)
        for _, row in ipairs(NoxUI.CharacterOverview()) do
            local data = row.data
            local mail = data.mailAt and (tostring(data.mail) .. "  ·  " .. date("%d/%m", data.mailAt))
                or NoxUI.L("Mailbox not checked")
            PutRow({ row.name, C_CurrencyInfo.GetCoinTextureString(data.money or 0),
                tostring(data.free or 0), tostring(data.rested or 0), mail }, row.current)
        end
        return math.abs(y)
    end

    local pages = { PAGE_QOL, PAGE_RAIDTOOLS, PAGE_CURSOR, PAGE_SHIFTER, PAGE_MOVEMENT }
    -- No item upgrade system on WoW Forever: the Upgrader tab is not offered there
    -- (its resident file returns at load, so the page builder never exists either).
    if not NoxUI.IS_FOREVER then pages[#pages + 1] = PAGE_UPGCALC end
    if NoxUI.CharacterOverview then pages[#pages + 1] = PAGE_CHARACTERS end
    local searchTerms = { "brez", "bres", "battle res", "combat res", "cursor", "macro", "fps", "logging", "combat log", "warcraft logs", "upgrade", "ilvl", "item level", "crest", "upgrade calculator", "upgrade tooltips", "tooltip", "shifter", "move", "drag", "position", "demodal", "drift", "combat alert", "enter combat", "leave combat", "in combat", "combat text", "combat notification", "transform", "transforms", "costume", "disguise", "chef's hat", "noggenfogger", "target distance", "distance to target", "range text", "yard", "yards", "movement", "mobility", "gap closer", "blink", "gateway", "warlock gateway", "control shard", "time spiral", "free movement", "raid tools", "raid", "pull timer", "pull", "ready check", "role check", "raid marker", "target marker", "world marker", "flare", "disband", "convert to raid", "countdown" }
    -- Terms for features WoW Forever does not have (the Battle Res indicator)
    -- are dropped there, so a sidebar search for them does not list this
    -- module; retail keeps the full list.
    if NoxUI.IS_FOREVER then
        local foreverDrop = { ["brez"] = true, ["bres"] = true, ["battle res"] = true, ["combat res"] = true }
        for i = #searchTerms, 1, -1 do
            if foreverDrop[searchTerms[i]] then table.remove(searchTerms, i) end
        end
    end
    NoxUI:RegisterModule("NoxUIConfortJeu", {
        title       = "Quality of Life",
        description = "Quality of life features and custom cursor.",
        pages       = pages,
        searchTerms = searchTerms,
        buildPage   = function(pageName, parent, yOffset)
            -- The Raid Tools settings preview ends when any OTHER QoL page
            -- builds (the CDM tracking-bars placeholder arrangement); window
            -- close and module switches are handled in the Raid Tools options
            -- file. Global Search's hidden pre-build never touches it.
            if pageName ~= PAGE_RAIDTOOLS and not NoxUI._prebuilding
               and _G._EUI_RaidTools_Preview then
                _G._EUI_RaidTools_Preview(false)
            end
            if pageName == PAGE_CHARACTERS then return BuildCharacters(parent, yOffset) end
            if pageName == PAGE_QOL then
                return BuildQoLPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_CURSOR and _G._EBS_BuildCursorPage then
                return _G._EBS_BuildCursorPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_UPGCALC and _G._EUI_BuildUpgradeCalcPage then
                return _G._EUI_BuildUpgradeCalcPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_SHIFTER and _G._EUI_BuildShifterPage then
                return _G._EUI_BuildShifterPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_MOVEMENT and _G._EUI_BuildMovementAlertPage then
                return _G._EUI_BuildMovementAlertPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_RAIDTOOLS and _G._EUI_BuildRaidToolsPage then
                return _G._EUI_BuildRaidToolsPage(pageName, parent, yOffset)
            end
        end,
        -- Cached pages are restored WITHOUT a rebuild, so buildPage never runs
        -- on the warm path -- reopening the window onto Raid Tools would leave
        -- its settings preview off without this (the CDM tracking-bars
        -- arrangement: mirror the flag on BOTH paths).
        onPageCacheRestore = function(pageName)
            if NoxUI._prebuilding then return end
            if _G._EUI_RaidTools_Preview then
                _G._EUI_RaidTools_Preview(pageName == PAGE_RAIDTOOLS)
            end
        end,
        resetScope = "account",
        onReset = function()
            if NoxUIDB then
                NoxUIDB.hideBlizzardPartyFrame = false
                NoxUIDB.quickLoot = false
                NoxUIDB.autoGossip = false
                NoxUIDB.autoGossipShiftSkip = nil
                NoxUIDB.autoGossipDisableInstance = nil
                NoxUIDB.autoGossipIgnoreTrivial = nil
                NoxUIDB.skipCinematics = false
                NoxUIDB.skipCinematicsAuto = false
                NoxUIDB.autoFillDelete = false
                NoxUIDB.autoInsertKeystone = false
                NoxUIDB.instanceResetAnnounce = false
                NoxUIDB.instanceResetAnnounceMsg = ""
                NoxUIDB.quickSignup = false
                NoxUIDB.persistSignupNote = false
                NoxUIDB.signupNote = nil
                NoxUIDB.ahCurrentExpansion = false
                NoxUIDB.hideTalkingHead = false
                NoxUIDB.muteTalkingHead = nil
                NoxUIDB.hideScreenshotStatus = false
                NoxUIDB.trainAllButton = false
                NoxUIDB.autoUnwrapCollections = false
                NoxUIDB.autoOpenContainers = false
                NoxUIDB.bonusRollConfirmation = false
                NoxUIDB.bonusRollOnly = true
                NoxUIDB.autoOpenContainersExcludeWarbound = true
                NoxUIDB.autoOpenContainersHoldCappedArtisanPayouts = false
                NoxUIDB.autoRepairGuild = false
                -- Low Durability Warning settings (its on/off switch is in the
                -- Global Settings reset).
                NoxUIDB.nuiAuctionSaleSound = nil
                NoxUIDB.nuiAuctionSaleChannel = nil
                NoxUIDB.nuiAltRecipeTips = nil
                if NoxUI.SyncAuctionSale then NoxUI.SyncAuctionSale() end
                NoxUIDB.supplyWarnings = nil
                NoxUIDB.supplyAmmoThreshold = nil
                NoxUIDB.supplyReagentThreshold = nil
                if NoxUI.SyncSupplyWarnings then NoxUI.SyncSupplyWarnings() end
                NoxUIDB.durWarnThreshold = nil
                NoxUIDB.durWarnTextSize = nil
                NoxUIDB.durWarnColor = nil
                NoxUIDB.durWarnYOffset = nil
                NoxUIDB.durWarnPos = nil
                NoxUIDB.durWarnIgnoreThrown = nil
                NoxUIDB.shifterEnabled = false
                NoxUIDB.shifterPositions = nil
                NoxUIDB.hideErrorMessages = false
                NoxUIDB.hideTutorials = false
                -- Hands the tutorial CVars back before the reset's reload.
                if NoxUI._applyHideTutorials then NoxUI._applyHideTutorials() end
                NoxUIDB.hideLootHistory = false
                NoxUIDB.lootHistoryMode = nil
                NoxUIDB.lootHistoryDelay = nil
                if NoxUI._applyHideLootHistory then NoxUI._applyHideLootHistory() end
                -- Talking Head does not exist on WoW Forever.
                if NoxUI._applyHideTalkingHead then NoxUI._applyHideTalkingHead() end
                NoxUIDB.hideBanners = false
                NoxUIDB.hideAlertToasts = false
                NoxUIDB.hideAlertToastsLoot = nil
                NoxUIDB.hideAlertToastsAchievements = nil
                NoxUIDB.hideAlertToastsHousing = nil
                NoxUIDB.announceGroupDeaths = false
                NoxUIDB.groupDeathTextSize = nil
                NoxUIDB.groupDeathAlertPos = nil
                NoxUIDB.groupDeathSound = nil      -- legacy boolean (pre-dropdown)
                NoxUIDB.groupDeathSoundKey = nil
                NoxUIDB.combatAlertEnabled = false
                NoxUIDB.combatAlertMode = nil
                NoxUIDB.combatAlertTextSize = nil
                NoxUIDB.combatAlertPos = nil
                NoxUIDB.combatAlertEnterText = nil
                NoxUIDB.combatAlertLeaveText = nil
                NoxUIDB.combatAlertEnterColor = nil
                NoxUIDB.combatAlertLeaveColor = nil
                NoxUIDB.combatAlertEnterUseClassColor = nil
                NoxUIDB.combatAlertLeaveUseClassColor = nil
                NoxUIDB.alertsPos = nil
                NoxUIDB.potionAlertEnabled = false
                NoxUIDB.potionAlertText = nil
                NoxUIDB.potionAlertTextSize = nil
                NoxUIDB.potionAlertColor = nil
                NoxUIDB.potionAlertUseClassColor = nil
                NoxUIDB.talentAlertEnabled = false
                NoxUIDB.talentAlertText = nil
                NoxUIDB.talentAlertTextSize = nil
                NoxUIDB.talentAlertColor = nil
                NoxUIDB.talentAlertUseClassColor = nil
                NoxUIDB.targetDistanceEnabled = false
                NoxUIDB.targetDistanceFormat = nil
                NoxUIDB.targetDistanceAlign = nil
                NoxUIDB.targetDistanceAttach = nil
                NoxUIDB.targetDistanceOffsetX = nil
                NoxUIDB.targetDistanceOffsetY = nil
                NoxUIDB.targetDistanceTextSize = nil
                NoxUIDB.targetDistancePos = nil
                NoxUIDB.mapSidebarsClear = nil
                NoxUIDB.mapSidebarsOpacity = nil
                NoxUIDB.mapSidebarsClickThrough = nil
                NoxUIDB.autoAcceptRes = nil
                NoxUIDB.autoAcceptResCombat = nil
                if NoxUIDB.unlockAnchors then
                    NoxUIDB.unlockAnchors.EUI_TargetDistance = nil
                    NoxUIDB.unlockAnchors.EUI_CombatAlert = nil
                    NoxUIDB.unlockAnchors.EUI_BattleRes = nil
                    NoxUIDB.unlockAnchors.EUI_Bloodlust = nil
                end
                NoxUIDB.hideTransforms = false
                NoxUIDB.hideTransformItems = nil
                -- The /keys popup, LFG Reminder, /way and /euipaste sections (the reset reloads).
                NoxUIDB.keystonePopup = nil
                NoxUIDB.teleportPrompt = nil
                NoxUIDB.waypointCmd = nil
                NoxUIDB.pasteCommands = nil
            end
            NoxUIDB.autoLogging = nil
            if _G._EUI_ResetUpgradeCalc then _G._EUI_ResetUpgradeCalc() end
            if _G._EBS_ResetCursor then _G._EBS_ResetCursor() end
            -- Battle Res and Bloodlust do not exist on WoW Forever.
            if _G._EUI_BattleRes_Reset then _G._EUI_BattleRes_Reset() end
            NoxUI._applyHideBlizzardPartyFrame()
            if NoxUI._applyBonusRollConfirmation then NoxUI._applyBonusRollConfirmation() end
            if NoxUI._applyHideErrorMessages then NoxUI._applyHideErrorMessages() end
            if NoxUI._applyAnnounceGroupDeaths then NoxUI._applyAnnounceGroupDeaths() end
            if NoxUI._applyCombatAlert then NoxUI._applyCombatAlert() end
            if NoxUI._applyPotionAlert then NoxUI._applyPotionAlert() end
            if NoxUI._applyTalentAlert then NoxUI._applyTalentAlert() end
            if NoxUI._applyTargetDistance then NoxUI._applyTargetDistance() end
            if NoxUI._applyHideTransforms then NoxUI._applyHideTransforms() end
            if NoxUI._applyQuickSignup then NoxUI._applyQuickSignup() end
            if NoxUI._applyPersistSignupNote then NoxUI._applyPersistSignupNote() end
            if NoxUI._applyQuickLoot then NoxUI._applyQuickLoot() end
            if NoxUI._applyAutoGossip then NoxUI._applyAutoGossip() end
            if NoxUI._applyInstanceResetAnnounce then NoxUI._applyInstanceResetAnnounce() end
            if NoxUI._applyAutoOpenContainers then NoxUI._applyAutoOpenContainers() end
            if NoxUI._ShutdownShifter then NoxUI._ShutdownShifter() end
            if _G._EUI_AutoLogging_Check then _G._EUI_AutoLogging_Check() end
            NoxUI:InvalidatePageCache()
        end,
        -- Tears down Duration Warning, Raid Tools, and Movement Alert
        -- previews on module switch (Movement Alert also stops its ticker).
        onModuleLeave = function()
            if NoxUI._durWarnHidePreview then NoxUI._durWarnHidePreview() end
            if _G._EUI_RaidTools_Preview then _G._EUI_RaidTools_Preview(false) end
            if NoxUI._MovementAlertPreview then NoxUI._MovementAlertPreview(false) end
        end,
    })

    SLASH_EQOL1 = "/qol"
    SlashCmdList.EQOL = function()
        if InCombatLockdown and InCombatLockdown() then return end
        NoxUI:ShowModule("NoxUIConfortJeu")
    end
end)
-- LoadOnDemand: this addon loads after PLAYER_LOGIN, so the event above will never fire; run the init now.
if IsLoggedIn() then initFrame:GetScript("OnEvent")(initFrame) end
