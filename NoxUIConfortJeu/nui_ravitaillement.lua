if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local events = CreateFrame("Frame")
local subscriptions = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "GET_ITEM_INFO_RECEIVED" }
local low = {}
local waitingForItem = {}
local lastAmmoType
local pending
local reagents = {
    { 17030, 20608 },                         -- Reincarnation
    { 17031, 3561, 3562, 3563, 3565, 3566, 3567 },
    { 17032, 10059, 11416, 11417, 11418, 11419, 11420 },
    { 17020, 23028 },
    { 5140, 1856, 1857 },
    { 17033, 19752 },
    { 17028, 21562, 21564 },
    { 17029, 27683 },
    { 17021, 21849 },
    { 17026, 21850 },
    { 6265, 697, 712, 691 },
}
-- Rebirth ranks use different seeds. Only the highest known rank is tracked.
local rebirth = {
    { 17038, 20748 }, { 17037, 20747 }, { 17036, 20742 },
    { 17035, 20739 }, { 17034, 20484 },
}

local function CheckStock(key, name, count, threshold)
    if count >= threshold then
        low[key] = nil
    elseif name and not low[key] then
        low[key] = true
        local message = NoxUI.Lf("Low supplies: %s (%d left)", name, count)
        DEFAULT_CHAT_FRAME:AddMessage(message, .95, .73, .42)
        if UIErrorsFrame then UIErrorsFrame:AddMessage(message, .95, .73, .42) end
    end
end

local function CheckAmmo(threshold)
    local weapon = GetInventoryItemID("player", GetInventorySlotInfo("RangedSlot"))
    local class, subclass
    if weapon then
        local _, _, _, _, _, itemClass, itemSubclass = C_Item.GetItemInfoInstant(weapon)
        class, subclass = itemClass, itemSubclass
    end
    local ammoType
    if class == Enum.ItemClass.Weapon then
        local weaponTypes = Enum.ItemWeaponSubclass
        if subclass == weaponTypes.Bows or subclass == weaponTypes.Crossbow then ammoType = 2 end
        if subclass == weaponTypes.Guns then ammoType = 3 end
    end
    if ammoType ~= lastAmmoType then
        low.ammo = nil
        lastAmmoType = ammoType
    end
    if not ammoType then return end
    local count = 0
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemID(bag, slot)
            if item then
                local _, _, _, _, _, itemClass, itemSubclass = C_Item.GetItemInfoInstant(item)
                if itemClass == Enum.ItemClass.Projectile and itemSubclass == ammoType then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    count = count + (info and info.stackCount or 0)
                end
            end
        end
    end
    local label = ammoType == 2 and "Arrows" or "Bullets"
    CheckStock("ammo", NoxUI.L(label), count, threshold)
end

local function CheckReagent(item, threshold)
    local name = C_Item.GetItemNameByID(item)
    if not name and not waitingForItem[item] then
        waitingForItem[item] = true
        C_Item.RequestLoadItemDataByID(item)
    end
    CheckStock(item, name, C_Item.GetItemCount(item), threshold)
end

local function Refresh()
    pending = nil
    local db = NoxUIDB
    if not (db and db.supplyWarnings) then return end
    CheckAmmo(db.supplyAmmoThreshold or 200)
    local knows = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not knows then return end
    local threshold = db.supplyReagentThreshold or 3
    for _, entry in ipairs(reagents) do
        for index = 2, #entry do
            if knows(entry[index]) then
                CheckReagent(entry[1], threshold)
                break
            end
        end
    end
    for _, entry in ipairs(rebirth) do
        if knows(entry[2]) then
            CheckReagent(entry[1], threshold)
            break
        end
    end
end

local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, Refresh)
end

function NoxUI.SyncSupplyWarnings()
    if NoxUIDB and NoxUIDB.supplyWarnings then
        for _, event in ipairs(subscriptions) do events:RegisterEvent(event) end
        Schedule()
    else
        events:UnregisterAllEvents()
        wipe(low)
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, item, success)
    if event == "PLAYER_LOGIN" then
        events:UnregisterEvent(event)
        NoxUI.SyncSupplyWarnings()
    elseif event ~= "GET_ITEM_INFO_RECEIVED" or (success and waitingForItem[item]) then
        Schedule()
    end
end)
