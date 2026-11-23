if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    and C_Container and C_Container.GetContainerItemQuestInfo
    and C_QuestLog and C_QuestLog.GetTitleForQuestID then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if not (NoxUIDB and NoxUIDB.noxItemQuestTitle) or InCombatLockdown() then return end
        if tooltip ~= GameTooltip then return end
        local info = tooltip.processingInfo
        if not info or info.getterName ~= "GetBagItem" or not info.getterArgs then return end
        local bag, slot = unpack(info.getterArgs)
        if type(bag) ~= "number" or type(slot) ~= "number" then return end
        local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
        local title = quest and quest.questID and C_QuestLog.GetTitleForQuestID(quest.questID)
        if not title or title == "" then return end
        for i = 1, tooltip:NumLines() do
            local line = _G["GameTooltipTextLeft" .. i]
            local text = line and line:GetText()
            if type(text) == "string" and text:find(title, 1, true) then return end
        end
        tooltip:AddLine("Quête : " .. title, 1, .82, .35, true)
        if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.questID) then
            local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(quest.questID)
            local status = ready and QUEST_WATCH_QUEST_READY or QUEST_TOOLTIP_ACTIVE
            if type(status) == "string" and status ~= "" then
                tooltip:AddLine(status, .35, .85, .35, true)
            end
        end
        if NoxUIDB.noxItemQuestOpen and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest.questID)
            and C_Map and C_Map.OpenWorldMap and QuestMapFrame_ShowQuestDetails then
            local label = GetLocale and GetLocale() == "frFR" and "Ctrl clic : afficher la quête" or "Ctrl click: show quest"
            tooltip:AddLine(label, .65, .75, .85, true)
        end
    end)
end

if hooksecurefunc and type(DressUpItemLocation) == "function" then
    hooksecurefunc("DressUpItemLocation", function(location)
        if not (NoxUIDB and NoxUIDB.noxItemQuestOpen) or InCombatLockdown() then return end
        if type(location) ~= "table" or type(location.bagID) ~= "number" or type(location.slotIndex) ~= "number"
            or not (C_Container and C_Container.GetContainerItemQuestInfo and C_QuestLog
                and C_QuestLog.GetLogIndexForQuestID and C_Map and C_Map.OpenWorldMap
                and QuestMapFrame_ShowQuestDetails and GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()) then return end
        local info = GameTooltip.processingInfo
        if not (info and info.getterName == "GetBagItem" and info.getterArgs
            and info.getterArgs[1] == location.bagID and info.getterArgs[2] == location.slotIndex) then return end
        local quest = C_Container.GetContainerItemQuestInfo(location.bagID, location.slotIndex)
        local id = quest and quest.questID
        if not id or not C_QuestLog.GetLogIndexForQuestID(id) then return end
        C_Map.OpenWorldMap()
        QuestMapFrame_ShowQuestDetails(id)
    end)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if not (NoxUIDB and NoxUIDB.noxItemReagents) or InCombatLockdown() then return end
        if not (tooltip and tooltip.GetItem and tooltip.AddDoubleLine and C_Item
            and C_Item.GetItemSpell and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return end
        local _, link = tooltip:GetItem()
        local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if not itemID then return end
        if C_Item.GetItemInfoInstant then
            local itemOK, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
            if itemOK and classID == 8 then return end
        end
        local ok, _, spellID = pcall(C_Item.GetItemSpell, itemID)
        if not ok or type(spellID) ~= "number" then return end
        local loaded, recipe = pcall(C_TradeSkillUI.GetRecipeSchematic, spellID, false)
        if not loaded or type(recipe) ~= "table" or type(recipe.reagentSlotSchematics) ~= "table" then return end
        local lines, maxCraft, hasAlternatives = {}, nil, false
        for _, slot in ipairs(recipe.reagentSlotSchematics) do
            if type(slot) == "table" and slot.required then
                if type(slot.reagents) ~= "table" or #slot.reagents == 0 then return end
                if #slot.reagents > 1 then hasAlternatives = true end
                local slotCraft = 0
                for index, reagent in ipairs(slot.reagents) do
                if type(reagent) ~= "table" then return end
                local name, count
                if type(reagent.itemID) == "number" then
                    name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(reagent.itemID)
                    count = C_Item.GetItemCount and C_Item.GetItemCount(reagent.itemID)
                    if not name and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(reagent.itemID)
                        if tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate() end
                    end
                elseif type(reagent.currencyID) == "number" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                    local currency = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                    if type(currency) == "table" then name, count = currency.name, currency.quantity end
                end
                local quantity = type(slot.quantityRequired) == "number" and slot.quantityRequired or 1
                if type(name) == "string" and type(count) == "number" and quantity > 0 then
                    local prefix = index > 1 and ((OR or "ou") .. " ") or ""
                    lines[#lines + 1] = { prefix .. name, count, quantity }
                    slotCraft = math.max(slotCraft, math.floor(count / quantity))
                else
                    return
                end
                end
                maxCraft = maxCraft and math.min(maxCraft, slotCraft) or slotCraft
            end
        end
        if #lines == 0 then return end
        tooltip:AddLine("Matériaux nécessaires", 1, .82, .35)
        for _, line in ipairs(lines) do
            local r, g, b = 1, 1, 1
            if line[2] < line[3] then r, g, b = 1, .35, .35 end
            tooltip:AddDoubleLine(line[1], line[2] .. " / " .. line[3], r, g, b, r, g, b)
        end
        if maxCraft and maxCraft > 1 and not hasAlternatives then
            local label = GetLocale and GetLocale() == "frFR" and "Fabrications possibles" or "Possible crafts"
            tooltip:AddDoubleLine(label, tostring(maxCraft), 1, .82, .35, 1, .82, .35)
        end
        if IsShiftKeyDown and IsShiftKeyDown() and type(recipe.outputItemID) == "number"
            and C_Item.GetItemNameByID then
            local result = C_Item.GetItemNameByID(recipe.outputItemID)
            if type(result) == "string" and result ~= "" then
                local label = GetLocale and GetLocale() == "frFR" and "Objet obtenu" or "Result"
                tooltip:AddDoubleLine(label, result, 1, .82, .35, 1, 1, 1)
            elseif C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(recipe.outputItemID)
                if tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate() end
            end
        end
    end)
end

local counter = CreateFrame("Frame", nil, UIParent)
counter:SetSize(260, 30)
counter:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 125)
counter:Hide()
local bg = counter:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(.055, .07, .09, .95)
local text = counter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("LEFT", 10, 0)
text:SetPoint("RIGHT", -10, 0)
text:SetTextColor(.72, .76, .80)
local function Update()
    local db = NoxUIDB
    local ids = db and db.noxTrackedMaterials
    if type(ids) ~= "table" then ids = db and { db.noxTrackedMaterial } or {} end
    local getName = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not getName or not getCount then counter:Hide(); return end
    local lines, seen = {}, {}
    for _, id in ipairs(ids) do
        if type(id) == "number" and id > 0 and not seen[id] and #lines < 6 then
            seen[id] = true
            local name = getName(id)
            lines[#lines + 1] = ("%s  ·  %d"):format(name or ("Objet " .. id), getCount(id) or 0)
        end
    end
    if #lines == 0 then counter:Hide(); return end
    counter:SetHeight(math.max(30, #lines * 18 + 12))
    text:SetText(table.concat(lines, "\n"))
    counter:Show()
end
counter:RegisterEvent("PLAYER_LOGIN")
counter:RegisterEvent("BAG_UPDATE_DELAYED")
counter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
counter:SetScript("OnEvent", Update)
NoxUI.RefreshTrackedMaterial = Update
