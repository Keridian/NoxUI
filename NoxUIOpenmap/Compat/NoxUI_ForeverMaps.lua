if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

-- Habillage complémentaire : aucun fichier ni réglage de ForeverMaps n'est modifié.
local _, ns = ...
local frames = {
    ForeverMapsRouteMap = true,
    ForeverMapsRecorder = true,
    ForeverMapsRoadRecorder = true,
    ForeverMapsSetup = true,
    ForeverMapsColors = true,
    ForeverMapsIgnoreList = true,
    ForeverMapsPrompt = true,
    ForeverMapsConfirm = true,
}
local skinned = setmetatable({}, { __mode = "k" })

local function Setting(key)
    return not NoxUIDB or NoxUIDB[key] ~= false
end

local function Notify(message)
    if NoxUI.PrintError then NoxUI.PrintError(message) else print("NoxUI : " .. message) end
end

local function OpenWorldMap(routeFrame)
    if InCombatLockdown() then Notify("La carte du monde ne peut pas être ouverte pendant le combat."); return end
    local openMap = _G.OpenMap
    if not openMap or type(openMap.GetModule) ~= "function" then
        Notify("Le module NoxUI Openmap n'est pas chargé.")
        return
    end
    local ok, world = pcall(openMap.GetModule, openMap, "worldmap")
    if not ok or not world or not world.enabled then
        Notify("Activez la carte OpenMap dans ses réglages, puis rechargez l'interface.")
        return
    end
    if not _G.WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    end
    if not _G.WorldMapFrame or type(ToggleWorldMap) ~= "function" then
        Notify("La carte du monde du jeu n'est pas disponible.")
        return
    end
    if not WorldMapFrame:IsShown() then
        local opened = pcall(ToggleWorldMap)
        if not opened or not WorldMapFrame:IsShown() then
            Notify("La carte du monde n'a pas pu être ouverte.")
            return
        end
    end
    if routeFrame and routeFrame:IsShown() then routeFrame:Hide() end
end

local function SetPanelTint(panel, r, g, b, a)
    if panel and panel.SetVertexColor then pcall(panel.SetVertexColor, panel, r, g, b, a) end
end

local function Skin(frame, isRouteMap)
    if skinned[frame] or not Setting("noxForeverMapsSkin") then return end
    if InCombatLockdown() then return end
    skinned[frame] = true
    -- On ne touche ni au canevas des cartes ni aux éléments interactifs.
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetAllPoints(frame)
    background:SetColorTexture(0.035, 0.04, 0.05, 0.98)
    SetPanelTint(frame.Bg, 0.10, 0.11, 0.13, 1)
    SetPanelTint(frame.Background, 0.10, 0.11, 0.13, 1)
    if frame.NineSlice and frame.NineSlice.Hide then frame.NineSlice:Hide() end
    local header = frame:CreateTexture(nil, "ARTWORK", nil, -5)
    header:SetColorTexture(0.035, 0.04, 0.05, 0.98)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    header:SetHeight(25)
    local function line(pointA, pointB, vertical)
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetColorTexture(0.4, 0, 0, 1)
        tex:SetPoint(pointA, frame, pointA)
        tex:SetPoint(pointB, frame, pointB)
        if vertical then tex:SetWidth(1) else tex:SetHeight(1) end
    end
    line("TOPLEFT", "TOPRIGHT", false)
    line("BOTTOMLEFT", "BOTTOMRIGHT", false)
    line("TOPLEFT", "BOTTOMLEFT", true)
    line("TOPRIGHT", "BOTTOMRIGHT", true)
    local divider = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    divider:SetColorTexture(0.4, 0, 0, 1)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -26)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -26)
    divider:SetHeight(1)
    local title = frame.TitleText or frame.title or (frame.TitleContainer and frame.TitleContainer.TitleText)
    if title and title.SetTextColor then title:SetTextColor(0.85, 0.89, 0.91, 1) end
    if isRouteMap then
        for _, key in ipairs({ "PortraitContainer", "portrait", "Portrait", "PortraitFrame" }) do
            local portrait = frame[key]
            if portrait and portrait.Hide then portrait:Hide() end
        end
    elseif frame.SetPortraitToAsset then
        pcall(frame.SetPortraitToAsset, frame, "Interface\\AddOns\\NoxUI\\media\\logo-full.tga")
    end
end

local function AddButton(frame)
    if frame._noxOpenMapButton or not Setting("noxForeverMapsButton") then return end
    if InCombatLockdown() then return end
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(124, 21)
    local inset = Setting("noxForeverMapsSkin") and 9 or 60
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -3)
    button:SetFrameLevel(math.max(frame:GetFrameLevel(), frame.TitleContainer and frame.TitleContainer:GetFrameLevel() or 0) + 2)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(button)
    fill:SetColorTexture(0.12, 0.15, 0.18, 1)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(0.72, 0.76, 0.80, 0.15)
    local underline = button:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    underline:SetHeight(1)
    underline:SetColorTexture(0.4, 0, 0, 1)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER")
    label:SetText("Carte du monde")
    label:SetTextColor(0.72, 0.76, 0.80, 1)
    button:SetScript("OnClick", function() OpenWorldMap(frame) end)
    button:SetScript("OnEnter", function(self)
        label:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Ouvrir OpenMap", 0.72, 0.76, 0.80)
        GameTooltip:AddLine("Ouvre la carte du monde de NoxUI.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() label:SetTextColor(0.72, 0.76, 0.80, 1); GameTooltip:Hide() end)
    frame._noxOpenMapButton = button
end

local function Apply(name)
    local frame = _G[name]
    if not frame then return end
    local isRouteMap = name == "ForeverMapsRouteMap"
    Skin(frame, isRouteMap)
    if isRouteMap then AddButton(frame) end
end

function ns.RefreshForeverMapsAppearance()
    for name in pairs(frames) do Apply(name) end
end

-- Les fenêtres ForeverMaps sont construites à la demande. Le crochet ne
-- retient que leurs noms connus et ne modifie pas leur création ni leur retour.
if hooksecurefunc and C_Timer and C_Timer.After then
    hooksecurefunc("CreateFrame", function(_, name)
        if type(name) == "string" and frames[name] then
            C_Timer.After(0, function() Apply(name) end)
        end
    end)
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function() ns.RefreshForeverMapsAppearance() end)
if IsLoggedIn and IsLoggedIn() then ns.RefreshForeverMapsAppearance() end

local function WorldModule()
    local addon = _G.OpenMap
    return addon and addon.GetModule and addon:GetModule("worldmap")
end

local function AerialCommand()
    return SlashCmdList and SlashCmdList.FOREVERMAPS3D
end

local aerialView
local routesOpenedFromWorld
local routeHooks = setmetatable({}, { __mode = "k" })
local function ReturnToOpenMap()
    local command, settings = AerialCommand(), _G.ForeverMaps3DDB
    if command and (aerialView or (settings and settings.view == "aerial")) then command("view map") end
    if aerialView then
        local world = WorldModule()
        if world and world.SetExternalMapView then world.SetExternalMapView(false) end
        aerialView = nil
    end
end

local function SelectMapView(mode)
    if InCombatLockdown() then return end
    local map = WorldMapFrame
    if mode == "routes" then
        local toggle = _G.ForeverMaps_ToggleRouteMap
        if not toggle then return end
        local routeMap = _G.ForeverMapsRouteMap
        if not routeMap or not routeMap:IsShown() then toggle() end
        routeMap = _G.ForeverMapsRouteMap
        if routeMap and routeMap:IsShown() then
            if not routeHooks[routeMap] then
                routeHooks[routeMap] = true
                routeMap:HookScript("OnHide", function()
                    if routesOpenedFromWorld ~= routeMap then return end
                    routesOpenedFromWorld = nil
                    C_Timer.After(0, function()
                        if not InCombatLockdown() and not routeMap:IsShown() and not map:IsShown() then
                            OpenWorldMap()
                        end
                    end)
                end)
            end
            routesOpenedFromWorld = routeMap
            HideUIPanel(map)
        end
    elseif mode == "map" then
        ReturnToOpenMap()
    else
        local command, world = AerialCommand(), WorldModule()
        if not (command and world and world.SetExternalMapView) then return end
        if _G.ForeverMaps3DDB and ForeverMaps3DDB.enabled == false then command("on") end
        world.SetExternalMapView(true)
        aerialView = mode
        command("view " .. mode)
    end
end

local strip
local controls = {
    { "map", "OpenMap", 78, "Carte du monde OpenMap" },
    { "routes", "Forever Maps", 100, "Carte et itinéraires Forever Maps" },
    { "aerial", "2D", 40, "Vue aérienne Forever Maps" },
    { "3d", "3D", 40, "Vue en relief Forever Maps" },
}

local nativeTabs
local function FindNativeTabs(frame, depth)
    if not frame or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= strip and child.GetTabButton and child.Refresh then
            local flat, tilt = child:GetTabButton(2), child:GetTabButton(3)
            if flat and tilt and flat.GetText and tilt.GetText
                and flat:GetText() == "2D" and tilt:GetText() == "3D" then
                return child
            end
        end
        if depth > 0 then
            local found = FindNativeTabs(child, depth - 1)
            if found then return found end
        end
    end
end

local function ReplaceNativeTabs(map)
    local world = WorldModule()
    if not AerialCommand() or not world or not world.enabled or InCombatLockdown() then return end
    if nativeTabs then return end
    nativeTabs = FindNativeTabs(map, 2)
    if not nativeTabs then return end
    -- The checkboxes and zone label still use the native strip for their layout.
    nativeTabs:SetAlpha(0)
    nativeTabs:EnableMouse(false)
    for i = 1, 3 do
        local button = nativeTabs:GetTabButton(i)
        if button then button:EnableMouse(false) end
    end
    local function MatchNativePosition()
        strip:ClearAllPoints()
        if nativeTabs:IsShown() then
            strip:SetPoint("TOPLEFT", nativeTabs, "TOPLEFT")
        else
            strip:SetPoint("TOP", map.ScrollContainer or map, "TOP", 0, 0)
        end
    end
    nativeTabs:HookScript("OnShow", MatchNativePosition)
    nativeTabs:HookScript("OnHide", MatchNativePosition)
    MatchNativePosition()
end

local function LayoutMapControls()
    if not strip then return end
    ReplaceNativeTabs(WorldMapFrame)
    local world = WorldModule()
    if not world or not world.enabled then strip:Hide(); return end
    local routes = type(_G.ForeverMaps_ToggleRouteMap) == "function"
    local aerial = type(AerialCommand()) == "function"
    local offset = 0
    for i, spec in ipairs(controls) do
        local mode, width = spec[1], spec[3]
        local button = strip[i]
        local available = mode == "map" or (mode == "routes" and routes)
            or ((mode == "aerial" or mode == "3d") and aerial)
        button:SetShown(available)
        if available then
            button:ClearAllPoints()
            button:SetPoint("LEFT", strip, "LEFT", offset, 0)
            offset = offset + width + 3
        end
    end
    strip:SetWidth(math.max(1, offset - 3))
    strip:SetShown(routes or aerial)
end

local function InstallMapControls()
    if strip or InCombatLockdown() or not WorldMapFrame then return end
    local map = WorldMapFrame
    strip = CreateFrame("Frame", nil, map)
    strip:SetSize(1, 22)
    strip:SetPoint("TOP", map.ScrollContainer or map, "TOP", 0, 0)
    strip:SetFrameStrata("HIGH")
    strip:SetFrameLevel(map:GetFrameLevel() + 12)
    for i, spec in ipairs(controls) do
        local mode, label, width, description = unpack(spec)
        local button = CreateFrame("Button", nil, strip)
        button:SetSize(width, 22)
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(.08, .10, .13, .96)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(.72, .76, .80, .20)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(label)
        text:SetTextColor(.72, .76, .80)
        button:SetScript("OnClick", function() SelectMapView(mode) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(description)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        strip[i] = button
    end
    local function OnMapShown()
        if not InCombatLockdown() then
            local routeMap = _G.ForeverMapsRouteMap
            routesOpenedFromWorld = nil
            if routeMap and routeMap:IsShown() then routeMap:Hide() end
            ReturnToOpenMap()
        end
        LayoutMapControls()
        C_Timer.After(0, LayoutMapControls)
    end
    map:HookScript("OnShow", OnMapShown)
    map:HookScript("OnHide", function()
        if not InCombatLockdown() then ReturnToOpenMap() end
    end)
    if map:IsShown() then
        OnMapShown()
    else
        LayoutMapControls()
    end
end

local keyOwner = CreateFrame("Frame")
local bindingPending, updatingBindings, bindingSignature
local function SyncMapBindings()
    if InCombatLockdown() then bindingPending = true; return end
    bindingPending = nil
    local world = WorldModule()
    local enabled = world and (world.enabled or (world.PadViewOn and world.PadViewOn()))
    local keys = enabled and { GetBindingKey("TOGGLEWORLDMAP") } or {}
    -- Version 2.1.10 and later can assign M to the route map in the saved bindings.
    -- Claim that default key for OpenMap for this session without editing the binding set.
    if enabled and GetBindingAction("M") == "FOREVERMAPS_TOGGLEMAP" then
        keys[#keys + 1] = "M"
    end
    local signature = table.concat(keys, " ")
    if signature == bindingSignature then return end
    bindingSignature, updatingBindings = signature, true
    ClearOverrideBindings(keyOwner)
    -- Forever Maps uses non-priority overrides of the same base shortcuts.
    for _, key in ipairs(keys) do
        SetOverrideBinding(keyOwner, true, key, "TOGGLEWORLDMAP")
    end
    updatingBindings = nil
end

keyOwner:RegisterEvent("PLAYER_LOGIN")
keyOwner:RegisterEvent("UPDATE_BINDINGS")
keyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
keyOwner:RegisterEvent("ADDON_LOADED")
keyOwner:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
keyOwner:SetScript("OnEvent", function(_, event, addon)
    if event == "UPDATE_BINDINGS" then
        if not updatingBindings then SyncMapBindings() end
    elseif event == "ADDON_LOADED" then
        if addon == "Blizzard_WorldMap" or addon == "ForeverMaps" or addon == "ForeverMaps3D" then
            C_Timer.After(0, function()
                SyncMapBindings()
                InstallMapControls()
                LayoutMapControls()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bindingPending then SyncMapBindings() end
        if aerialView and WorldMapFrame and not WorldMapFrame:IsShown() then ReturnToOpenMap() end
        InstallMapControls()
    else
        C_Timer.After(0, function()
            SyncMapBindings()
            InstallMapControls()
        end)
    end
end)
if IsLoggedIn and IsLoggedIn() then
    C_Timer.After(0, function()
        SyncMapBindings()
        InstallMapControls()
    end)
end
