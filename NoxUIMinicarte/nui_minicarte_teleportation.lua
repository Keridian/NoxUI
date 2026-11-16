if NUI_CLIENT_BLOQUE then return end
local _, ns = ...
if not (NoxUI and NoxUI.IS_FOREVER and ns._internals and ns._internals.EBS) then return end
local EBS = ns._internals.EBS
local ids = {
    556, 18960, 193753, 50977, 126892, 193759, 3561, 3562, 3565, 32271,
    33690, 88342, 132621, 176248, 281403, 3567, 3566, 3563, 35715, 49358,
    88344, 132627, 176242, 281404, 53140, 224869, 1259190, 1259194, 446540, 446534,
    395277, 395289, 344587, 344597, 281400, 281402, 224871, 176246, 176244, 132620,
    132626, 88345, 88346, 53142, 49360, 35717, 33691, 32267, 32272, 32266,
    10059, 11416, 11419, 11417, 11420, 11418, 131204, 131205, 131206, 131222,
    131225, 131228, 131229, 131231, 131232, 159895, 159896, 159897, 159898, 159899,
    159900, 159902, 373262, 393764, 393766, 424153, 424163, 410078, 410080, 424142,
    445424, 424187, 467553, 410071, 445418, 424167, 410074, 373274, 354464, 354468,
    354462, 354466, 354465, 354469, 354463, 354467, 367416, 373190, 373191, 373192,
    393256, 393276, 393262, 393279, 393267, 393273, 393283, 393222, 424197, 432254,
    432257, 432258, 445444, 445414, 445443, 445440, 445269, 445441, 1216786, 445416,
    445417, 1237215, 1226482, 1239155, 1254400, 1254572, 1254551, 1254563, 1254559, 1254555,
    1254557,
}
local toys = {
    110560, 140192, 162973, 163045, 165669, 165670, 166747, 168907, 172179, 180290,
    182773, 183716, 184353, 188952, 190196, 190237, 200630, 206195, 208704, 209035,
    212337, 228940, 87215, 168807, 168808, 198156, 236687, 246565, 245970, 193588,
    265100, 257736, 263933, 264367, 48933, 112059, 172924, 221966, 18986, 30544,
    18984, 30542, 205255, 243056,
}
local items = {
    6948, 234389, 234390,
}
local page = 1
local PAGE_SIZE = 8
local trigger, menu
local function infoSort(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, data = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(data) == 'table' then return data.name, data.iconID end
    end
    if GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, id)
        if ok then return name, icon end
    end
end
local function sortConnu(id)
    local f = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell or IsSpellKnown
    if not f then return false end
    local ok, connu = pcall(f, id)
    return ok and connu == true
end
local function disponible()
    local entries = {}
    local countFn = GetItemCount or (C_Item and C_Item.GetItemCount)
    local itemFn = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if countFn and itemFn then
        for _, id in ipairs(items) do
            local ok, count = pcall(countFn, id)
            if ok and type(count) == 'number' and count > 0 then
                local okInfo, name, _, _, _, _, _, _, _, _, icon = pcall(itemFn, id)
                if okInfo and name then
                    entries[#entries + 1] = { type='item', id=id, name=name, icon=icon }
                elseif C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                end
            end
        end
    end
    if PlayerHasToy and C_ToyBox and C_ToyBox.GetToyInfo then
        for _, id in ipairs(toys) do
            local ok, has = pcall(PlayerHasToy, id)
            if ok and has then
                local okInfo, _, name, icon = pcall(C_ToyBox.GetToyInfo, id)
                if okInfo and type(name) == 'string' and name ~= '' then
                    entries[#entries + 1] = { type='toy', id=id, name=name, icon=icon }
                end
            end
        end
    end
    for _, id in ipairs(ids) do
        if sortConnu(id) then
            local name, icon = infoSort(id)
            if name then entries[#entries + 1] = { type='spell', id=id, name=name, icon=icon } end
        end
    end
    return entries
end
ns.TeleportationsDisponibles = disponible
local function construireMenu()
    if InCombatLockdown() then return end
    if not menu then
        menu = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
        menu:SetFrameStrata('DIALOG')
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=1 })
        menu:SetBackdropColor(.035,.045,.055,.97)
        menu:SetBackdropBorderColor(.4,0,0,1)
        menu.rows = {}
        menu:Hide()
        menu:RegisterEvent('PLAYER_REGEN_ENABLED')
        menu:SetScript('OnEvent', function(self) if self:IsShown() then self:Hide() end end)
    end
    local entries = disponible()
    local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
    page = math.min(math.max(page, 1), pages)
    local shown = math.min(PAGE_SIZE, #entries - (page-1)*PAGE_SIZE)
    for i=1,shown do
        local entry = entries[(page-1)*PAGE_SIZE+i]
        local row = menu.rows[i]
        if not row then
            row = CreateFrame('Button', nil, menu, 'SecureActionButtonTemplate')
            row:SetHeight(27)
            row:RegisterForClicks('LeftButtonUp', 'LeftButtonDown')
            row.icon = row:CreateTexture(nil, 'ARTWORK')
            row.icon:SetSize(21,21)
            row.icon:SetPoint('LEFT', 4, 0)
            row.text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
            row.text:SetPoint('LEFT', row.icon, 'RIGHT', 6, 0)
            row.text:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
            row.text:SetJustifyH('LEFT')
            row:SetScript('PostClick', function() if not InCombatLockdown() then menu:Hide() end end)
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', menu, 'TOPLEFT', 4, -4 - (i-1)*27)
        row:SetPoint('TOPRIGHT', menu, 'TOPRIGHT', -4, -4 - (i-1)*27)
        row.icon:SetTexture(entry.icon or 134414)
        row.text:SetText(entry.name)
        row:SetAttribute('type', entry.type)
        row:SetAttribute('item', entry.type == 'item' and entry.name or nil)
        row:SetAttribute('spell', entry.type == 'spell' and entry.id or nil)
        row:SetAttribute('toy', entry.type == 'toy' and entry.id or nil)
        row:Show()
    end
    for i=shown+1,#menu.rows do menu.rows[i]:Hide() end
    if not menu.empty then
        menu.empty = menu:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        menu.empty:SetPoint('CENTER')
        menu.empty:SetText('Aucune téléportation disponible')
    end
    menu.empty:SetShown(#entries == 0)
    if not menu.prev then
        menu.prev = CreateFrame('Button', nil, menu, 'UIPanelButtonTemplate')
        menu.prev:SetSize(55, 22)
        menu.prev:SetPoint('BOTTOMLEFT', menu, 'BOTTOMLEFT', 5, 4)
        menu.prev:SetText('Préc.')
        menu.prev:SetScript('OnClick', function() if not InCombatLockdown() and page > 1 then page = page-1; construireMenu() end end)
        menu.next = CreateFrame('Button', nil, menu, 'UIPanelButtonTemplate')
        menu.next:SetSize(55, 22)
        menu.next:SetPoint('BOTTOMRIGHT', menu, 'BOTTOMRIGHT', -5, 4)
        menu.next:SetText('Suiv.')
        menu.next:SetScript('OnClick', function() if not InCombatLockdown() then page = page+1; construireMenu() end end)
        menu.pageLabel = menu:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        menu.pageLabel:SetPoint('BOTTOM', menu, 'BOTTOM', 0, 9)
    end
    menu.prev:SetEnabled(page > 1)
    menu.next:SetEnabled(page < pages)
    menu.pageLabel:SetText(page .. ' / ' .. pages)
    menu:SetSize(220, math.max(35, shown*27+8)+28)
    menu:ClearAllPoints()
    menu:SetPoint('TOPRIGHT', trigger, 'BOTTOMRIGHT', 0, -4)
    menu:Show()
end
local function initialiser()
    if not Minimap or InCombatLockdown() then return end
    local m = EBS.db and EBS.db.profile and EBS.db.profile.minimap
    if not m or m.enabled == false or m.teleportShortcut ~= true then return end
    if trigger then return end
    trigger = CreateFrame('Button', 'NoxUIMinicarteTeleportation', UIParent)
    trigger:SetSize(24,24)
    trigger:SetPoint('BOTTOMRIGHT', Minimap, 'BOTTOMRIGHT', -3, 3)
    trigger:SetFrameStrata('HIGH')
    local icon = trigger:CreateTexture(nil, 'ARTWORK')
    icon:SetAllPoints()
    icon:SetTexture(134414)
    trigger:SetScript('OnClick', function()
        if InCombatLockdown() then return end
        if menu and menu:IsShown() then menu:Hide() else page = 1; construireMenu() end
    end)
    trigger:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetText('Téléportation')
        GameTooltip:AddLine('Ouvrir les raccourcis disponibles hors combat.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    trigger:SetScript('OnLeave', function() GameTooltip:Hide() end)
end
local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', initialiser)
