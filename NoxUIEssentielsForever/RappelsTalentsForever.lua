if NUI_CLIENT_BLOQUE then return end
local _, ns = ...
local _, class = UnitClass("player")
local reminders = {}
ns.ForeverTalentReminders = reminders

local activities = { party = true, raid = true, pvp = true, arena = true }
local prefix = "NOXTALENTS1:"
local limit = 32

local function Config(create)
    return NoxUI.CharData("foreverTalentReminders", create)
end

function reminders.List(activity)
    local cfg = Config(false)
    return cfg and cfg[activity] or {}
end

function reminders.Add(activity, id)
    if not activities[activity] or type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > 99999999 then return end
    local spells = reminders.List(activity)
    for _, existing in ipairs(spells) do
        if existing == id then return true end
    end
    if #spells >= limit then return end
    local cfg = Config(true)
    if not cfg then return end
    spells[#spells + 1] = id
    cfg[activity] = spells
    return true
end

function reminders.Remove(activity, index)
    local spells = reminders.List(activity)
    if spells[index] then table.remove(spells, index) end
end

function reminders.Export(activity)
    local spells = reminders.List(activity)
    if activities[activity] and #spells > 0 then
        return prefix .. class .. ":" .. activity .. ":" .. table.concat(spells, ",")
    end
end

function reminders.Import(text)
    if type(text) ~= "string" or #text > 400 then return end
    local sourceClass, activity, payload = text:match("^%s*" .. prefix .. "([A-Z]+):([a-z]+):([%d,]+)%s*$")
    if sourceClass ~= class or not activities[activity] then return end
    local merged, seen = {}, {}
    for _, id in ipairs(reminders.List(activity)) do
        merged[#merged + 1], seen[id] = id, true
    end
    for entry in (payload .. ","):gmatch("(.-),") do
        local id = tonumber(entry)
        if not id or id < 1 or id > 99999999 or #entry > 8 then return end
        if not seen[id] then
            merged[#merged + 1], seen[id] = id, true
            if #merged > limit then return end
        end
    end
    local cfg = Config(true)
    if not cfg then return end
    cfg[activity] = merged
    return activity
end

local previousActivity, previousInstance
function reminders.CheckArrival()
    local _, activity = IsInInstance()
    local _, _, _, _, _, _, _, instance = GetInstanceInfo()
    if activity == previousActivity and instance == previousInstance then return end
    previousActivity, previousInstance = activity, instance
    if not activities[activity] then return end
    local missing = {}
    for _, id in ipairs(reminders.List(activity)) do
        local known = IsPlayerSpell and IsPlayerSpell(id)
        if not (issecretvalue and issecretvalue(known)) and known ~= true then
            if IsSpellKnown then known = IsSpellKnown(id) end
            if not (issecretvalue and issecretvalue(known)) and known == false then
                local name = C_Spell.GetSpellName(id)
                if not (issecretvalue and issecretvalue(name)) and type(name) == "string" then
                    missing[#missing + 1] = name
                end
            end
        end
    end
    if #missing > 0 then
        UIErrorsFrame:AddMessage("Talents manquants : " .. table.concat(missing, ", "), 1, 0.78, 0.25)
    end
end

-- The equipment feature checks once its specialization decision has settled.
if not ns.ForeverEquipment then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", reminders.CheckArrival)
end
