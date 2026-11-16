if NUI_CLIENT_BLOQUE then return end

local _, ns = ...
local EAB, internals = ns.EAB, ns._internals
local groups = {}

local function Masque()
    return LibStub and LibStub("Masque", true)
end

function ns.CanUseMasque(key)
    local bar = ns.BAR_LOOKUP[key]
    return bar and not bar.isStance and not bar.isPetBar and not bar.visibilityOnly
        and ns.AB_Style() == "eui" and Masque() ~= nil
end

function ns.MasqueOwnsBar(key)
    local entry = groups[key]
    return entry and next(entry.buttons) ~= nil
end

function ns.SyncMasqueBar(key)
    if InCombatLockdown() then return end
    local skin = EAB.db.profile.bars[key]
    local entry = groups[key]
    if not (skin and skin.useMasque and ns.CanUseMasque(key)) then
        if entry then
            for button in pairs(entry.buttons) do entry.group:RemoveButton(button) end
            wipe(entry.buttons)
        end
        return
    end
    local buttons = ns.barButtons[key]
    if not buttons then return end
    if not entry then
        local info = ns.BAR_LOOKUP[key]
        local group = Masque():Group("NoxUI", NoxUI.L(info.label), "NoxUIActionBars_" .. key)
        if not group then return end
        entry = { group = group, buttons = {} }
        groups[key] = entry
    end
    local present = {}
    for _, button in ipairs(buttons) do
        local icon = button.icon or button.Icon
        if icon then
            present[button] = true
            if not entry.buttons[button] then
                internals.ApplyButtonBorders(button, false, 0, 0, 0, 0, 0, 0)
                internals.ApplyShapeToButton(button, "none", false, 0, 0, 0, 0, 0, 0)
                local regions = { Icon = icon, Normal = button.NormalTexture or button:GetNormalTexture() }
                entry.group:AddButton(button, regions, "Action", true)
                entry.buttons[button] = true
            end
        end
    end
    for button in pairs(entry.buttons) do
        if not present[button] then
            entry.group:RemoveButton(button)
            entry.buttons[button] = nil
        end
    end
end

function ns.ReskinMasqueBars()
    if InCombatLockdown() then return end
    for _, entry in pairs(groups) do
        if next(entry.buttons) then entry.group:ReSkin() end
    end
end
