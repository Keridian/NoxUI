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
    local id = NoxUIDB and NoxUIDB.noxTrackedMaterial
    if type(id) ~= "number" or id <= 0 then counter:Hide(); return end
    local getName = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not getName or not getCount then counter:Hide(); return end
    local name = getName(id)
    text:SetText(("%s  ·  %d"):format(name or ("Objet " .. id), getCount(id) or 0))
    counter:Show()
end
counter:RegisterEvent("PLAYER_LOGIN")
counter:RegisterEvent("BAG_UPDATE_DELAYED")
counter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
counter:SetScript("OnEvent", Update)
NoxUI.RefreshTrackedMaterial = Update
