if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local ticker, elapsed, absent = nil, 0, 0
local function minutes(key, default, minimum, maximum)
    local value = tonumber(NoxUIDB and NoxUIDB[key]) or default
    if value ~= value then value = default end
    return math.max(minimum, math.min(maximum, value))
end
local function stop()
    if ticker then ticker:Cancel(); ticker = nil end
    elapsed = 0
    absent = 0
    if NoxUI.Alerts then NoxUI.Alerts.Hide("noxbreak") end
end

local function tick()
    if not (NoxUIDB and NoxUIDB.noxBreakEnabled) then stop(); return end
    if UnitIsAFK and UnitIsAFK("player") then
        absent = absent + 10
        return
    end
    if absent >= minutes("noxBreakRestMinutes", 5, 1, 30) * 60 then elapsed = 0 end
    absent = 0
    elapsed = elapsed + 10
    local interval = minutes("noxBreakMinutes", 60, 15, 240)
    if elapsed < interval * 60 or InCombatLockdown() then return end
    local alerts = NoxUI.Alerts
    local line = alerts and alerts.Line("noxbreak")
    if line then
        local text = GetLocale and GetLocale() == "frFR" and "Une pause ?" or "Time for a break?"
        line.Show(text, 1, .82, .35)
        elapsed = 0
    end
end

function NoxUI.DelayBreakReminder()
    if not (NoxUIDB and NoxUIDB.noxBreakEnabled and ticker) then return end
    local interval = minutes("noxBreakMinutes", 60, 15, 240) * 60
    local delay = minutes("noxBreakDelayMinutes", 5, 1, 30) * 60
    elapsed = interval - delay
    if NoxUI.Alerts then NoxUI.Alerts.Hide("noxbreak") end
end

function NoxUI.ResetBreakReminder()
    if not (NoxUIDB and NoxUIDB.noxBreakEnabled and ticker) then return end
    elapsed, absent = 0, 0
    if NoxUI.Alerts then NoxUI.Alerts.Hide("noxbreak") end
end

function NoxUI.ApplyBreakReminder()
    stop()
    if NoxUIDB and NoxUIDB.noxBreakEnabled then ticker = C_Timer.NewTicker(10, tick) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() NoxUI.ApplyBreakReminder() end)
