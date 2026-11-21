if NUI_CLIENT_BLOQUE then return end

local _, ns = ...
local spec, sets = C_SpecializationInfo, C_EquipmentSet
if not (spec and spec.GetActiveSpecGroup and sets and sets.GetEquipmentSetInfo
    and sets.GetEquipmentSetIDs and sets.UseEquipmentSet) then return end

local function Config(create)
    return NoxUI.CharData("foreverEquipmentRules", create)
end

local gear = {}
ns.ForeverEquipment = gear

function gear.Get(activity, group)
    local cfg = Config(false)
    local rules = cfg and cfg[activity]
    return rules and rules[group]
end

function gear.Set(activity, group, id)
    local cfg = Config(true)
    if not cfg then return end
    cfg[activity] = cfg[activity] or {}
    cfg[activity][group] = id
end

function gear.GetSpecialization(activity)
    local cfg = Config(false)
    local rules = cfg and cfg[activity]
    return rules and rules.specialization
end

function gear.SetSpecialization(activity, group)
    local cfg = Config(true)
    if not cfg then return end
    cfg[activity] = cfg[activity] or {}
    cfg[activity].specialization = group
end

function gear.HasDualSpec()
    return spec.SetActiveSpecGroup and GetNumSpecGroups and GetNumSpecGroups() == 2
end

function gear.List()
    local values, order = { none = NoxUI.L("None") }, { "none" }
    for _, id in ipairs(sets.GetEquipmentSetIDs() or {}) do
        local name = sets.GetEquipmentSetInfo(id)
        if name then
            local key = tostring(id)
            values[key] = name
            order[#order + 1] = key
        end
    end
    return values, order
end

local waiting, scheduled, previousActivity, previousGroup, previousInstance
local chooseSpec, pendingSpec

local function CheckTalentReminders()
    local reminders = ns.ForeverTalentReminders
    if reminders then reminders.CheckArrival() end
end

local Schedule
local function Apply()
    scheduled = false
    local _, activity = IsInInstance()
    activity = activity or "none"
    local group = spec.GetActiveSpecGroup()
    if (issecretvalue and issecretvalue(group)) or (group ~= 1 and group ~= 2) then return end

    local _, _, _, _, _, _, _, instance = GetInstanceInfo()
    local arrived = activity ~= previousActivity or instance ~= previousInstance
    if arrived then chooseSpec = true end
    if arrived or group ~= previousGroup then
        previousActivity, previousGroup, previousInstance = activity, group, instance
        waiting = true
    end
    if pendingSpec then
        if group ~= pendingSpec.group then return end
        pendingSpec = nil
    end
    if not waiting then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
    waiting = false

    if chooseSpec then
        chooseSpec = false
        local wanted = gear.GetSpecialization(activity)
        if wanted and wanted ~= group and gear.HasDualSpec() then
            local request = { group = wanted }
            pendingSpec = request
            local ok, result = pcall(spec.SetActiveSpecGroup, wanted)
            if not ok or result == false then
                pendingSpec = nil
                NoxUI.PrintError("Le jeu a refusé le changement de spécialisation.")
                CheckTalentReminders()
                return
            end
            waiting = true
            Schedule()
            C_Timer.After(12, function()
                if pendingSpec ~= request then return end
                local active = spec.GetActiveSpecGroup()
                if not (issecretvalue and issecretvalue(active)) and active == request.group then
                    Schedule()
                    return
                end
                pendingSpec = nil
                waiting = chooseSpec
                NoxUI.PrintError("Le changement de spécialisation n’a pas été confirmé.")
                if chooseSpec then gear.Apply() else CheckTalentReminders() end
            end)
            return
        end
    end

    CheckTalentReminders()
    local id = gear.Get(activity, group) or gear.Get("default", group)
    if not id then return end
    local name, _, _, equipped, _, _, _, missing = sets.GetEquipmentSetInfo(id)
    if equipped then return end
    if not name or (missing and missing > 0) then
        NoxUI.PrintError("Tenue automatique indisponible. Vérifie les pièces et la tenue choisie.")
        return
    end
    local ok, result = pcall(EquipmentManager_EquipSet or sets.UseEquipmentSet, id)
    if not ok or result == false then
        NoxUI.PrintError("Le jeu a refusé le changement de tenue.")
    end
end

Schedule = function()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0, Apply)
end

function gear.Apply()
    waiting, chooseSpec = true, true
    Schedule()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", Schedule)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
