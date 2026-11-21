if NUI_CLIENT_BLOQUE then return end

local _, ns = ...
local timer = NoxUI.NextSwingTimer
if not timer then return end

local overlays = {}

local function IsNextSwing(button)
    local slot = button.action
    if issecretvalue and issecretvalue(slot) then return false end
    if not slot then slot = button:GetAttribute("action") end
    if issecretvalue and issecretvalue(slot) then return false end
    if type(slot) ~= "number" or slot <= 0 then return false end
    local actionType, id = GetActionInfo(slot)
    if issecretvalue and issecretvalue(actionType) then return false end
    return actionType == "spell" and timer.Matches(id)
end

local function Refresh()
    local startTime, duration = timer.Get()
    for _, buttons in pairs(ns.barButtons or {}) do
        for _, button in ipairs(buttons) do
            local overlay = overlays[button]
            local matches = IsNextSwing(button)
            if matches and not overlay and not InCombatLockdown() then
                overlay = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                overlay:SetAllPoints(button.icon or button.Icon or button)
                overlay:SetHideCountdownNumbers(true)
                overlay:SetDrawEdge(false)
                overlays[button] = overlay
            end
            if overlay then
                if matches and startTime then
                    overlay:SetCooldown(startTime, duration)
                    overlay:Show()
                else
                    overlay:Hide()
                end
            end
        end
    end
end

timer.Subscribe(Refresh)
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", Refresh)
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
