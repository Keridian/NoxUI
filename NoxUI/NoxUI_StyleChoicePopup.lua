if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  NoxUI_StyleChoicePopup.lua
--
local NoxUI = _G.NoxUI
if not NoxUI then return end
local NUI_MODULE_HOTE = ...
local IS_STANDALONE = type(NUI_MODULE_HOTE) == "string" and NUI_MODULE_HOTE:find("Standalone") ~= nil
if IS_STANDALONE then return end

local PP = NoxUI.PanelPP
local MakeBorder = NoxUI.MakeBorder
local NOX_GREEN = NoxUI.NOX_GREEN

local function Stamp()
    if not NoxUIDB then NoxUIDB = {} end
    NoxUIDB.styleChoicePending = nil
end

-- Conflict-check handoff: while the picker is due this session the auto
-- addon-conflict check (NoxUI.lua) holds on _styleChoicePending, armed
-- at the parent's ADDON_LOADED below; every close that does not reload runs
-- it here (a reload's next session runs its own).
local function Release()
    if not NoxUI._styleChoicePending then return end
    NoxUI._styleChoicePending = nil
    if NoxUIDB and NoxUIDB.firstInstallPopupShown and NoxUI._RunConflictCheck then
        C_Timer.After(0.3, NoxUI._RunConflictCheck)
    end
end

-- Every loaded module to one look: the flags ride the Style page's own
-- registry (LoadOnDemand options), so one code path owns what "all modules"
-- means. False when the options addon cannot load. The module picker runs it
-- too on WoW Forever (NoxUI_FirstInstall.lua), as its reload's
-- pre-reload work. The caller reloads.
local function ApplyLook(styleKey)
    if not NoxUI.EnsureOptionsLoaded() then return false end
    local BS = NoxUI.BlizzStyle
    if not (BS and BS.ApplyAll) then return false end
    BS.ApplyAll(styleKey)
    return true
end
NoxUI.ApplyFirstInstallLook = ApplyLook

local function ShowStyleChoicePopup()
    if not (PP and MakeBorder and NOX_GREEN and NoxUI.BuildStyleCards) then
        Release()
        return
    end
    local FONT = NoxUI._font or NoxUI.EXPRESSWAY
        or "Interface\\AddOns\\NoxUI\\media\\fonts\\Expressway.ttf"
    local EG = NOX_GREEN
    -- Wide enough for the card row (four cards on the WoW Forever client).
    local POPUP_W, POPUP_H = math.max(700, NoxUI.STYLE_CARDS_W + 32), 508
    -- The DEFAULT card: NoxUI, or on the WoW Forever client WoW
    -- Forever, the look a fresh install there starts on.
    local defaultKey = NoxUI.IS_FOREVER and "forever" or "eui"
    -- Preserve mixed styles until the player confirms a selection.
    local rendered = NoxUI.RenderedLook()
    local activeKey = rendered
    if activeKey == nil then activeKey = defaultKey elseif activeKey == false then activeKey = nil end
    local KeepLook
    local selectedKey = activeKey
    -- Escape keeps whatever renders: it never writes.
    local dimmer, popup = NoxUI.BuildPopupShell("EUIStyleChoice", {
        w = POPUP_W, h = POPUP_H, bump = 1.15, dimAlpha = 0.45,
        onEscape = function() KeepLook() end,
    })

    local eyebrow = popup:CreateFontString(nil, "OVERLAY")
    eyebrow:SetFont(FONT, 13, "")
    eyebrow:SetTextColor(EG.r, EG.g, EG.b, 0.9)
    PP.Point(eyebrow, "TOP", popup, "TOP", 0, -26)
    eyebrow:SetText(NoxUI.L("CHOOSE YOUR LOOK"))

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 26, "")
    title:SetTextColor(1, 1, 1, 1)
    PP.Point(title, "TOP", eyebrow, "BOTTOM", 0, -6)
    title:SetText(NoxUI.L("How should NoxUI look?"))

    local desc = popup:CreateFontString(nil, "OVERLAY")
    desc:SetFont(FONT, 14, "")
    desc:SetTextColor(1, 1, 1, 0.5)
    desc:SetWidth(POPUP_W - 90)
    desc:SetJustifyH("CENTER")
    desc:SetWordWrap(true)
    PP.Point(desc, "TOP", title, "BOTTOM", 0, -10)
    desc:SetText(NoxUI.L("Select a style to preview it, then confirm your choice."))

    KeepLook = function()
        Stamp()
        dimmer:Hide()
        Release()
    end

    local cards
    local function UpdateSelection()
        for key, card in pairs(cards or {}) do
            card:SetState(key == selectedKey, true, key == selectedKey and "Selected" or "Preview", true)
        end
    end

    cards = NoxUI.BuildStyleCards(popup, -138, {
        buttonText = "Preview",
        defaultKey = defaultKey,
        onPick = function(styleKey)
            selectedKey = styleKey
            UpdateSelection()
        end,
    })
    UpdateSelection()

    local cancel = NoxUI.MakeActionButton(popup, FONT, NoxUI.L("Keep current style"),
        EG.r, EG.g, EG.b, { w = 180, secondary = true })
    PP.Point(cancel, "BOTTOMRIGHT", popup, "BOTTOM", -6, 14)
    cancel:SetScript("OnClick", KeepLook)

    local confirm = NoxUI.MakeActionButton(popup, FONT, NoxUI.L("Apply style"),
        EG.r, EG.g, EG.b, { w = 180 })
    PP.Point(confirm, "BOTTOMLEFT", popup, "BOTTOM", 6, 14)
    confirm:SetScript("OnClick", function()
        if not selectedKey then return end
        if selectedKey == activeKey then
            KeepLook()
        elseif ApplyLook(selectedKey) then
            Stamp()
            ReloadUI()
        else
            NoxUI.Print(NoxUI.L("Enable NoxUIOptions to change the style."))
        end
    end)

    dimmer:Show()
end

NoxUI.ShowStyleChoicePopup = ShowStyleChoicePopup

-------------------------------------------------------------------------------
--  Trigger: the login after the module picker's reload, once.
-------------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName ~= "NoxUI" then return end
        self:UnregisterEvent("ADDON_LOADED")
        -- Arm the conflict-check hold on the same conditions the login
        -- branch shows under (the first-install loader, earlier in the TOC,
        -- has already raised _firstInstallPending by now).
        if NoxUIDB and NoxUIDB.styleChoicePending
            and not NoxUI._firstInstallPending then
            NoxUI._styleChoicePending = true
        end
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (NoxUIDB and NoxUIDB.styleChoicePending) then return end
    -- The picker itself is still due this session: it reloads, and its
    -- close path re-arms the stamp for the login after.
    if NoxUI._firstInstallPending then return end
    -- A registered external installer owns the first-run experience.
    if NoxUI._externalInstaller then Stamp(); Release(); return end
    local function TryShow()
        if not (NoxUIDB and NoxUIDB.styleChoicePending) then
            Release()
            return
        end
        ShowStyleChoicePopup()
    end
    C_Timer.After(0.8, TryShow)
end)
