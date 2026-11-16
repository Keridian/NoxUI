if NUI_CLIENT_BLOQUE then return end

local _, ns = ...
local F = ns.Feature("effetFurtivite", { enabled = true })
NoxUI._EffetFurtivite = F

local _, class = UnitClass("player")
local supported = class == "DRUID" or class == "ROGUE"
local rogueAuras = { 1784, 11327, 115192, 185422, 51713 }
local druidAuras = { 5215, 6298 }
local events = CreateFrame("Frame")
local vignette, texture
local opacity, opening, target = 0, 0, 0

local function IsActive()
    local stealth = IsStealthed and IsStealthed()
    if not (issecretvalue and issecretvalue(stealth)) and stealth == true then
        return true
    end
    local getAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not getAura then return false end
    for _, spellID in ipairs(class == "ROGUE" and rogueAuras or druidAuras) do
        local aura = getAura(spellID)
        if not (issecretvalue and issecretvalue(aura)) and aura then return true end
    end
    return false
end

local function Ease(value)
    return value * value * (3 - 2 * value)
end

local function Resize()
    texture:SetSize(vignette:GetWidth(), vignette:GetHeight() * (2 - Ease(opening)))
end

local function Step(self, elapsed)
    if target == 1 then
        opacity = math.min(1, opacity + elapsed / 0.6)
        opening = opacity
        Resize()
    else
        opacity = math.max(0, opacity - elapsed / 0.8)
    end
    self:SetAlpha(0.6 * Ease(opacity))
    if opacity == target then
        self:SetScript("OnUpdate", nil)
        if opacity == 0 then self:Hide() end
    end
end

local function Refresh()
    target = F.Enabled() and IsActive() and 1 or 0
    if target == 1 and not vignette then
        vignette = CreateFrame("Frame", nil, UIParent)
        vignette:SetAllPoints(UIParent)
        vignette:SetFrameStrata("BACKGROUND")
        vignette:EnableMouse(false)
        vignette:Hide()
        texture = vignette:CreateTexture(nil, "BACKGROUND")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\AddOns\NoxUIEssentielsForever\Media\nui_voile_furtivite.tga]])
        vignette:SetScript("OnSizeChanged", Resize)
    end
    if not vignette then return end
    if target == 1 and not vignette:IsShown() then
        opening = 0
        Resize()
        vignette:SetAlpha(0)
        vignette:Show()
    end
    if opacity ~= target then vignette:SetScript("OnUpdate", Step) end
end

function F.Apply()
    if not supported then return end
    events:UnregisterAllEvents()
    if F.Enabled() then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("UPDATE_STEALTH")
        events:RegisterUnitEvent("UNIT_AURA", "player")
    end
    Refresh()
end

events:SetScript("OnEvent", Refresh)
F.Start(F.Apply)
