if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local ticker, elapsed = nil, 0
local function stop()
    if ticker then ticker:Cancel(); ticker = nil end
    elapsed = 0
    if NoxUI.Alerts then NoxUI.Alerts.Hide("noxbreak") end
end

local function tick()
    if not (NoxUIDB and NoxUIDB.noxBreakEnabled) then stop(); return end
    if UnitIsAFK and UnitIsAFK("player") then return end
    elapsed = elapsed + 10
    local minutes = tonumber(NoxUIDB.noxBreakMinutes) or 60
    minutes = math.max(15, math.min(240, minutes))
    if elapsed < minutes * 60 or InCombatLockdown() then return end
    local alerts = NoxUI.Alerts
    local line = alerts and alerts.Line("noxbreak")
    if line then
        local text = GetLocale and GetLocale() == "frFR" and "Une pause ?" or "Time for a break?"
        line.Show(text, 1, .82, .35)
        elapsed = 0
    end
end

function NoxUI.ApplyBreakReminder()
    stop()
    if NoxUIDB and NoxUIDB.noxBreakEnabled then ticker = C_Timer.NewTicker(10, tick) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() NoxUI.ApplyBreakReminder() end)
