if NUI_CLIENT_BLOQUE or not NoxUI.IS_FOREVER then return end
local _, ns = ...
local K = ns.BlockKit

local function ReadTrees(group)
    local spec, traits = C_SpecializationInfo, C_Traits
    if not (spec and traits and spec.GetCombatConfigIDForSpecGroup
            and traits.GetConfigInfo and traits.GetGroupDisplayInfoByTreeID
            and traits.GetGroupCurrencyInfo) then return end
    local configID = spec.GetCombatConfigIDForSpecGroup(group)
    local config = configID and traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return end

    local ids, trees, ordered = {}, {}, {}
    for _, display in ipairs(traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
        if display.groupID and display.displayName then
            local entry = { name = display.displayName, order = display.orderIndex or 0, spent = 0 }
            ids[#ids + 1] = display.groupID
            trees[display.groupID] = entry
            ordered[#ordered + 1] = entry
        end
    end
    if #ordered == 0 then return end
    for _, record in ipairs(traits.GetGroupCurrencyInfo(configID, ids) or {}) do
        local entry = trees[record.traitNodeGroupID]
        local currency = record.currencyInfos and record.currencyInfos[1]
        if entry and currency and type(currency.spent) == "number" then
            entry.spent = currency.spent
        end
    end
    table.sort(ordered, function(a, b) return a.order < b.order end)

    local lead, best, points = nil, 0, {}
    for i, entry in ipairs(ordered) do
        points[i] = tostring(entry.spent)
        if entry.spent > best then lead, best = entry.name, entry.spent end
    end
    return lead, table.concat(points, " / ")
end

local function GroupCount()
    if not GetNumSpecGroups then return 1 end
    return GetNumSpecGroups() == 2 and 2 or 1
end

local function GroupDetails(group)
    local ok, name, points = pcall(ReadTrees, group)
    return (ok and name) or NoxUI.L(group == 2 and "Secondary Spec" or "Primary Spec"), ok and points or nil
end

local function SwitchGroup(group, active)
    local spec = C_SpecializationInfo
    if not spec or not spec.SetActiveSpecGroup or group == active or group > GroupCount() then return end
    if InCombatLockdown() then
        NoxUI.PrintError(NoxUI.L("Cannot change specialization during combat."))
        return
    end
    local ok, accepted = pcall(spec.SetActiveSpecGroup, group)
    if not ok or accepted == false then
        NoxUI.PrintError(NoxUI.L("The game refused the specialization change."))
    end
end

ns.BlockFactories.dualspec = function(blockCfg, slot, content, barCtx)
    local inst = { cfg = blockCfg, slot = slot, content = content, ctx = barCtx }
    inst.key = K.InstKey(barCtx, blockCfg)
    inst.events = { "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_REGEN_ENABLED" }

    local button = CreateFrame("Button", nil, content)
    button:SetAllPoints()
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    K.AttachTextOffset(inst, label)
    local active = 1

    local function ShowTooltip()
        ns.Tip_Begin(button)
        ns.Tip_AddLine(NoxUI.L("Dual Specialization"))
        local count = GroupCount()
        for group = 1, count do
            local name, points = GroupDetails(group)
            if group == active then name = name .. " (" .. NoxUI.L("Active Spec") .. ")" end
            ns.Tip_AddDouble(name, points or "")
        end
        if count == 2 and C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup then
            ns.Tip_AddLine(NoxUI.L("Shift + left click: primary specialization"))
            ns.Tip_AddLine(NoxUI.L("Shift + right click: secondary specialization"))
        end
        ns.Tip_Show()
    end

    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() ns.Tip_Hide(button) end)
    button:SetScript("OnClick", function(_, mouseButton)
        if IsShiftKeyDown() then SwitchGroup(mouseButton == "LeftButton" and 1 or 2, active) end
    end)

    function inst:Refresh()
        local spec = C_SpecializationInfo
        active = (spec and spec.GetActiveSpecGroup and spec.GetActiveSpecGroup()) or 1
        local name = GroupDetails(active)
        label:SetText(name)
        local fontSize = math.max(9, math.floor(K.CONTENT_BASE * 0.43 + 0.5))
        ns.SetFont(label, fontSize, barCtx.cfg)
        label:SetTextColor(K.BlockColorOf(blockCfg))
        if not InCombatLockdown() then
            local height = barCtx.GetThickness()
            if barCtx.IsVertical() then
                local width = K.VSlotW(inst)
                ns.SetWrappedText(label, math.max(10, width - 8), "CENTER")
                content:SetSize(width, math.max(height, label:GetStringHeight() + 8))
            else
                ns.ResetInlineText(label, "CENTER")
                content:SetSize(math.max(24, label:GetStringWidth() + 8), height)
            end
            K.MaybeRelayout(inst)
        end
        if ns.Tip_IsOwned(button) then ShowTooltip() end
    end

    inst.eventFrame = K.MakeEventFrame(inst, function(self) self:Refresh() end)
    function inst:Enable()
        content:Show()
        K.RegisterInstEvents(self)
    end
    function inst:Disable()
        K.UnregisterInstEvents(self)
        ns.Tip_Hide(button)
        content:Hide()
    end
    function inst:GetAutoLength()
        if barCtx.IsVertical() then return math.max(24, content:GetHeight()) end
        return math.max(24, content:GetWidth())
    end
    function inst:Destroy()
        self._dead = true
        self:Disable()
    end
    return inst
end
