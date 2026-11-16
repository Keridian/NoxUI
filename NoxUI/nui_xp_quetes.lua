if NUI_CLIENT_BLOQUE or not NoxUI then return end

function NoxUI.AddQuestXPTooltip(addDoubleLine, addLine, current, maximum)
    if not IsShiftKeyDown() then
        addLine("Maintiens Maj pour afficher l’XP des quêtes.", .72, .76, .80)
        return
    end
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetQuestIDForLogIndex
        and (log.ReadyForTurnIn or log.IsComplete) and GetQuestLogRewardXP) then
        addLine("XP des quêtes indisponible.", .72, .76, .80)
        return
    end
    local ready, total = 0, 0
    local isReady = log.ReadyForTurnIn or log.IsComplete
    for index = 1, log.GetNumQuestLogEntries() do
        local id = log.GetQuestIDForLogIndex(index)
        if id and id > 0 then
            local xp = GetQuestLogRewardXP(id)
            if type(xp) == "number" and not (issecretvalue and issecretvalue(xp)) and xp > 0 then
                total = total + xp
                if isReady(id) then ready = ready + xp end
            end
        end
    end
    local fmt = BreakUpLargeNumbers or tostring
    addDoubleLine("XP des quêtes prêtes à rendre", fmt(ready), .72, .76, .80, 1, 1, 1)
    addDoubleLine("XP connue du journal", fmt(total), .72, .76, .80, 1, 1, 1)
    if maximum > current then
        if ready >= maximum - current then
            addLine("Les quêtes prêtes suffisent pour le prochain niveau.", .55, .87, .58)
        elseif total >= maximum - current then
            addLine("Le total du journal suffit pour le prochain niveau.", .72, .76, .80)
        end
    end
end

local watcher = CreateFrame("Frame")
local active, refresh, shifted
function NoxUI.WatchQuestXPTooltip(owner, render)
    active, refresh, shifted = owner, render, IsShiftKeyDown()
    watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
end

function NoxUI.StopQuestXPTooltip(owner)
    if active ~= owner then return end
    active, refresh = nil, nil
    watcher:UnregisterEvent("MODIFIER_STATE_CHANGED")
end

watcher:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if not active then return end
    if not active:IsVisible() or not active:IsMouseOver() then
        NoxUI.StopQuestXPTooltip(active)
        return
    end
    local down = IsShiftKeyDown()
    if down ~= shifted then
        shifted = down
        refresh(active)
    end
end)
