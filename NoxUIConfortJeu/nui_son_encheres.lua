if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local sold = Enum.AuctionHouseNotification and Enum.AuctionHouseNotification.AuctionSold
if sold == nil then return end

local events = CreateFrame("Frame")
local lastSale
local auctionEvents = { "AUCTION_HOUSE_SHOW_NOTIFICATION", "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION" }

local saleSound = "Interface\\AddOns\\NoxUI\\media\\sounds\\Kaching.ogg"

local function SaleChannel()
    return NoxUIDB and NoxUIDB.nuiAuctionSaleChannel == "SFX" and "SFX" or "Master"
end

function NoxUI.PreviewAuctionSale()
    local channel = SaleChannel()
    if channel == "SFX" and GetCVarBool
        and (not GetCVarBool("Sound_EnableSFX") or tonumber(GetCVar("Sound_SFXVolume")) == 0) then
        channel = "Master"
        DEFAULT_CHAT_FRAME:AddMessage(NoxUI.L("Sound effects are muted. Playing the preview on the main channel."))
    end
    if not PlaySoundFile(saleSound, channel) then
        DEFAULT_CHAT_FRAME:AddMessage(NoxUI.L("The sale sound could not play. Check the game audio settings."))
    end
end

function NoxUI.SyncAuctionSale()
    for _, event in ipairs(auctionEvents) do
        if NoxUIDB and NoxUIDB.nuiAuctionSaleSound then
            events:RegisterEvent(event)
        else
            events:UnregisterEvent(event)
        end
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, notification)
    if event == "PLAYER_LOGIN" then
        events:UnregisterEvent(event)
        NoxUI.SyncAuctionSale()
        return
    end
    if (issecretvalue and issecretvalue(notification)) or notification ~= sold then return end
    local now = GetTime()
    if lastSale and now - lastSale < 1.5 then return end
    lastSale = now
    PlaySoundFile(saleSound, SaleChannel())
end)
