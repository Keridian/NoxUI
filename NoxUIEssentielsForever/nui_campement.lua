if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local nearby, cooldown = 1283391, 1308027
local bagItem, bagSpell, bagBuff = 211527, 429961, 429959
local bagPosition
local resting = {1229739, 1289723}
local bonuses = {
    {1230587,"Puits de mana"}, {1230172,"Meule"}, {1230653,"Luth enchanté"},
    {1230124,"Premiers soins"}, {1230098,"Bocal à poisson"}, {1229513,"Encens"},
    {1229487,"Tente"}, {1230164,"Magnétite"}, {1229519,"Chaise"}, {1229718,"Bannière"},
}
local texture = "Interface\\AddOns\\NoxUIEssentielsForever\\Media\\nui_feuille_camp.tga"
local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
frame:SetSize(94, 160)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:Hide()
-- The item button protects its parent. Hide securely when combat begins;
-- the normal visibility checks resume on PLAYER_REGEN_ENABLED.
frame:SetAttribute("_onstate-campcombat", [[
    if newstate == "combat" then self:Hide() end
]])
RegisterStateDriver(frame, "campcombat", "[combat] combat; peaceful")
local preview, expanded, showBonuses, showRest
local campPosition, dragging
local fireSpells = {1307227, 1307252, 1307237}
local function db()
    NoxUIDB = NoxUIDB or {}
    NoxUIDB.campement = NoxUIDB.campement or {}
    return NoxUIDB.campement
end
local function position()
    if InCombatLockdown() then return end
    frame:ClearAllPoints()
    local cfg = db()
    frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -150)
end
local function leaf(w,h,x,y,side,caption,template)
    local b = CreateFrame("Button",nil,frame,template)
    b:SetSize(w,h)
    b:SetPoint("CENTER", frame, "CENTER", x,y)
    local art = b:CreateTexture(nil,"BACKGROUND")
    art:SetTexture(texture)
    if side then
        art:SetSize(h,w)
        art:SetPoint("CENTER")
        art:SetRotation(side * math.pi / 2)
    else
        art:SetAllPoints()
    end
    local label = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetPoint("CENTER",0,-2)
    label:SetTextColor(.72,.76,.80)
    label:SetText(caption)
    return b,label
end
local main, status = leaf(94,160,0,0,nil,"Campement")
local restStatus = main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
restStatus:SetPoint("BOTTOM", main, "TOP", 0, 5)
restStatus:SetTextColor(.72, .76, .80)
restStatus:SetShadowOffset(1, -1)
restStatus:SetText("Repos en cours")
restStatus:Hide()
local bonusButton = leaf(108,49,-91,-17,1,"Bonus")
local restButton = leaf(108,49,91,30,-1,"Repos")
local bagButton, bagLabel = leaf(124,49,91,-84,-1,"Sac de couchage","SecureActionButtonTemplate")
bagButton:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
bagButton:SetAttribute("item1", "item:" .. bagItem)
local settings = leaf(108,49,91,-27,-1,"Réglages")
local detail = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
detail:SetPoint("TOP",restButton,"BOTTOM",0,-4)
detail:SetTextColor(.72,.76,.80)
local tokens = {}
for i=1,#bonuses do
    local token,label = leaf(118,40,-196,0,1,"")
    tokens[i] = {token,label}
end

local function aura(id)
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return end
    local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID,id)
    if ok and not (issecretvalue and issecretvalue(data)) then return data end
end
local function remaining(data)
    local t = data and data.expirationTime
    if (issecretvalue and issecretvalue(t)) or type(t) ~= "number" or t <= 0 then return end
    return math.max(0, math.ceil(t - GetTime()))
end
local function clock(seconds)
    return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end
local function playerPosition()
    if not UnitPosition then return end
    local y, x, _, instance = UnitPosition("player")
    if issecretvalue and (issecretvalue(y) or issecretvalue(x) or issecretvalue(instance)) then return end
    if type(y) == "number" and type(x) == "number" then return y, x, instance end
end

local function nearPosition(spot)
    if not spot then return false end
    local y, x, instance = playerPosition()
    return y ~= nil and instance == spot.instance
        and (x-spot.x)^2 + (y-spot.y)^2 <= 12^2 and GetTime() < spot.expires
end

local function rememberPosition()
    local y,x,instance = playerPosition()
    if y then return { y=y, x=x, instance=instance, expires=GetTime()+120 } end
end

local function bagOwned()
    local count = C_Item and C_Item.GetItemCount
    local quantity = count and count(bagItem)
    return not (issecretvalue and issecretvalue(quantity))
        and type(quantity) == "number" and quantity > 0
end

local function bagCooldown()
    local get = C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if not get then return end
    local start, duration = get(bagItem)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return end
    if type(start) == "number" and start > 0 and type(duration) == "number" then
        local seconds = math.ceil(start + duration - GetTime())
        if seconds > 0 then return seconds end
    end
end

local function bagStacks()
    local buff = aura(bagBuff)
    local stacks = buff and buff.applications
    if issecretvalue and issecretvalue(stacks) then return end
    return type(stacks) == "number" and stacks or 0
end

local function Update()
    if InCombatLockdown() then return end
    local cfg = db()
    local rest = aura(resting[1]) or aura(resting[2])
    local recharge = aura(cooldown)
    local nearBag = nearPosition(bagPosition)
    if not nearBag then bagPosition = nil end
    if not nearPosition(campPosition) then campPosition = nil end
    local visible = preview or (cfg.enabled ~= false and (rest or aura(nearby) or campPosition or nearBag))
    if not visible then
        if dragging then frame:StopMovingOrSizing(); dragging = nil end
        frame:Hide()
        expanded, showBonuses, showRest = nil,nil,nil
        return
    end
    local seconds = preview and 38 or remaining(rest)
    status:SetText(seconds and (clock(seconds).."\nCampement") or "Campement")
    restStatus:SetShown(not not (rest or preview))
    frame:Show()
    bonusButton:SetShown(expanded == true)
    restButton:SetShown(expanded == true)
    settings:SetShown(expanded == true)
    local owned = bagOwned()
    local action = expanded and owned and not preview and "item" or nil
    if bagButton:GetAttribute("type1") ~= action then
        bagButton:SetAttribute("type1", action)
    end
    bagButton:SetShown(expanded == true and not not (preview or nearBag or owned))
    local stacks = preview and 2 or bagStacks()
    bagLabel:SetText("Sac de couchage" .. (stacks and ("\nRepos : %d/3"):format(stacks) or ""))
    detail:SetShown(expanded == true and showRest == true and (not (rest or preview) or recharge ~= nil))
    local delay = remaining(recharge)
    detail:SetText(delay and ("Recharge : "..clock(delay)) or "Assieds toi près du feu")
    local labels = {}
    if expanded and showBonuses then
        if preview then labels = {"Tente","Meule","Puits de mana"}
        else
            for _, entry in ipairs(bonuses) do
                if aura(entry[1]) then labels[#labels+1] = entry[2] end
            end
            if #labels == 0 then labels[1] = "Aucun bonus actif" end
        end
    end
    for i, entry in ipairs(tokens) do
        local button,label = entry[1],entry[2]
        button:SetShown(labels[i] ~= nil)
        if labels[i] then
            label:SetText(labels[i])
            local column = math.floor((i-1)/5)
            local row = (i-1)%5
            button:ClearAllPoints()
            button:SetPoint("CENTER",frame,"CENTER",-201-column*120,62-row*41)
        end
    end
end
-- A world tooltip is the fallback when the client does not send the proximity aura.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip, data)
        if tooltip ~= GameTooltip or InCombatLockdown() or db().enabled == false then return end
        local line = data and data.lines and data.lines[1]
        local name = line and line.leftText
        if (issecretvalue and issecretvalue(name)) or type(name) ~= "string" then return end
        local matched = (GetLocale() == "frFR" and name == "Feu de camp")
            or (GetLocale() == "enUS" and name == "Campfire")
        if not matched and C_Spell and C_Spell.GetSpellName then
            for _, id in ipairs(fireSpells) do
                if name == C_Spell.GetSpellName(id) then matched = true; break end
            end
        end
        local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(bagItem)
        if name == itemName or name == "Sac de couchage douillet" or name == "Cozy Sleeping Bag" then
            bagPosition = rememberPosition()
        elseif matched then
            campPosition = rememberPosition()
        else
            return
        end
        Update()
    end)
end
main:SetScript("OnClick",function() expanded = not expanded; Update() end)
bonusButton:SetScript("OnClick",function() showBonuses = not showBonuses; Update() end)
restButton:SetScript("OnClick",function() showRest = not showRest; Update() end)
settings:SetScript("OnClick",function()
    if NoxUI.NavigateToElementSettings then NoxUI:NavigateToElementSettings("NoxUIEssentielsForever","Campement") end
end)
bagButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sac de couchage")
    local stacks = bagStacks()
    if stacks then GameTooltip:AddLine(("Bien reposé : %d/3"):format(stacks), .72,.76,.80) end
    local owned = bagOwned()
    local delay = owned and bagCooldown()
    if preview then GameTooltip:AddLine("Aperçu du raccourci.", .72,.76,.80)
    elseif delay then GameTooltip:AddLine("Recharge : "..clock(delay), .72,.76,.80)
    elseif owned then GameTooltip:AddLine("Clic gauche pour déployer le sac.", .72,.76,.80, true)
    else GameTooltip:AddLine("Installe toi dans le sac déployé pour te reposer.", .72,.76,.80, true) end
    GameTooltip:Show()
end)
bagButton:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    dragging = true
    frame:StartMoving()
end)
main:SetScript("OnDragStop", function()
    if not dragging or InCombatLockdown() then return end
    dragging = nil
    frame:StopMovingOrSizing()
    local x,y = frame:GetCenter()
    local u,v = UIParent:GetCenter()
    if x and u then db().x,db().y = x-u,y-v; position() end
end)
local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA","player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
events:RegisterEvent("BAG_UPDATE_DELAYED")
for _, name in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(name) end
events:SetScript("OnEvent",function(_,event,_,_,spellID)
    if event == "PLAYER_REGEN_DISABLED" then
        expanded, showBonuses, showRest = nil,nil,nil
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if dragging then frame:StopMovingOrSizing(); dragging = nil end
        position()
    end
    if event == "PLAYER_ENTERING_WORLD" then campPosition, bagPosition = nil,nil; position() end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and not (issecretvalue and issecretvalue(spellID))
        and spellID == bagSpell then bagPosition = rememberPosition() end
    Update()
end)
local elapsed = 0
frame:SetScript("OnUpdate",function(_,dt)
    elapsed = elapsed + dt
    if elapsed >= .25 then elapsed = 0; Update() end
end)
NoxUI.Campement = {
    Enabled = function() return db().enabled ~= false end,
    SetEnabled = function(value) db().enabled = value; Update() end,
    Preview = function()
        preview = not preview
        if preview then expanded, showBonuses = true,true end
        position()
        Update()
    end,
    Reset = function() NoxUIDB.campement = nil; position(); Update() end,
}
