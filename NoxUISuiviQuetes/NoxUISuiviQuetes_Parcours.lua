if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local french = GetLocale and GetLocale() == "frFR"
BINDING_HEADER_NOXUI_QUEST_CYCLE = "NoxUI"
BINDING_NAME_NOXUI_QUEST_NEXT = french and "Quête suivie suivante" or "Next tracked quest"
BINDING_NAME_NOXUI_QUEST_PREVIOUS = french and "Quête suivie précédente" or "Previous tracked quest"

function NoxUI.CycleTrackedQuest(direction)
    if InCombatLockdown() or not (C_QuestLog and C_QuestLog.GetNumQuestWatches
        and C_QuestLog.GetQuestIDForQuestWatchIndex and C_SuperTrack
        and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.SetSuperTrackedQuestID) then return end
    local total = C_QuestLog.GetNumQuestWatches()
    if type(total) ~= "number" or (issecretvalue and issecretvalue(total)) or total < 1 then return end
    local ids, current = {}, C_SuperTrack.GetSuperTrackedQuestID()
    if issecretvalue and issecretvalue(current) then current = nil end
    for index = 1, total do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if type(id) == "number" and not (issecretvalue and issecretvalue(id)) and id > 0 then
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then return end
    local step = direction == -1 and -1 or 1
    local currentIndex = step == 1 and 0 or 1
    for index, id in ipairs(ids) do
        if id == current then currentIndex = index; break end
    end
    local nextIndex = ((currentIndex - 1 + step) % #ids) + 1
    C_SuperTrack.SetSuperTrackedQuestID(ids[nextIndex])
end
