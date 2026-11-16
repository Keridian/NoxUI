if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local requests = CreateFrame("Frame")
local modes = {
    DUEL_REQUESTED = "blockStrangerDuels",
    RESURRECT_REQUEST = "acceptSafeResurrection",
    CONFIRM_SUMMON = "acceptSafeSummon",
}

local function IsLeatrixHandling(key)
    return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
        and type(LeaPlusDB) == "table" and LeaPlusDB[key] == "On"
end

local function IsKnownPlayer(name)
    if C_FriendList and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name) then
        return true
    end
    if not IsInGuild() then return false end
    local short = Ambiguate(name, "short")
    for index = 1, GetNumGuildMembers() do
        local member = NoxUI.PlainString(GetGuildRosterInfo(index))
        if member and Ambiguate(member, "short") == short then return true end
    end
    return false
end

local function Resurrect(name)
    if not (name and AcceptResurrect and UnitExists(name)) then return end
    local fighting = UnitAffectingCombat(name)
    if (issecretvalue and issecretvalue(fighting)) or fighting ~= false then return end
    AcceptResurrect()
end

function NoxUI.SyncForeverRequests()
    for event, setting in pairs(modes) do
        if NoxUIDB and NoxUIDB[setting] == true then
            requests:RegisterEvent(event)
        else
            requests:UnregisterEvent(event)
        end
    end
end

requests:RegisterEvent("PLAYER_LOGIN")
requests:SetScript("OnEvent", function(self, event, source)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        NoxUI.SyncForeverRequests()
        return
    end
    if InCombatLockdown() or IsShiftKeyDown() then return end
    local name = NoxUI.PlainString(source)
    if event == "DUEL_REQUESTED" and not IsLeatrixHandling("NoDuelRequests") then
        if name and CancelDuel and not IsKnownPlayer(name) then
            CancelDuel()
            if StaticPopup_Hide then StaticPopup_Hide("DUEL_REQUESTED") end
        end
    elseif event == "RESURRECT_REQUEST" and not IsLeatrixHandling("AutoAcceptRes") then
        Resurrect(name)
    elseif event == "CONFIRM_SUMMON" and not IsLeatrixHandling("AutoAcceptSummon") then
        local confirm = C_SummonInfo and C_SummonInfo.ConfirmSummon
        if confirm then confirm() end
    end
end)
