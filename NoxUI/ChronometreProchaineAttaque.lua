local _, class = UnitClass("player")
local spells = NoxUI.FOREVER_NEXT_SWING and NoxUI.FOREVER_NEXT_SWING[class]
local mainHand = Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand
if not spells or mainHand == nil then return end

local listeners = {}
local startTime, duration = 0, 0
local timer = {}
NoxUI.NextSwingTimer = timer

function timer.Matches(id)
    if (issecretvalue and issecretvalue(id)) or type(id) ~= "number" then return false end
    local base = C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id)
    if issecretvalue and issecretvalue(base) then base = nil end
    for _, spell in ipairs(spells) do
        if id == spell or base == spell then return true end
    end
    return false
end

function timer.Get()
    if startTime + duration > GetTime() then return startTime, duration end
end

function timer.Subscribe(refresh)
    listeners[#listeners + 1] = refresh
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, swingDuration, swingType)
    if event == "PLAYER_SWING" then
        if issecretvalue and (issecretvalue(swingDuration) or issecretvalue(swingType)) then return end
        if swingType ~= mainHand or type(swingDuration) ~= "number" or swingDuration <= 0 then return end
        startTime, duration = GetTime(), swingDuration
    else
        startTime, duration = 0, 0
    end
    for _, refresh in ipairs(listeners) do refresh() end
end)
events:RegisterEvent("PLAYER_SWING")
events:RegisterEvent("PLAYER_LEAVE_COMBAT")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
