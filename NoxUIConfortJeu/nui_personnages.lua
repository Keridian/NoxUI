if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local events = CreateFrame("Frame")
local pending
local mailboxOpen
local professionsDirty = true
-- Recipe subclass order: leatherworking, tailoring, engineering, blacksmithing,
-- cooking, alchemy, first aid, enchanting, fishing.
local recipeProfessions = { 165, 197, 202, 164, 185, 171, 129, 333, 356 }

local function Snapshot()
    pending = nil
    local character = NoxUI.CharData("nuiCharacterOverview", true)
    if not character then return end
    character.money = GetMoney()
    character.rested = GetXPExhaustion() or 0
    local free = 0
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    character.free = free
    character.updated = time()

    if not professionsDirty and character.professions then return character end
    local professions = {}
    local slots = { GetProfessions() }
    for index = 1, 5 do
        if slots[index] then
            local name, _, rank, _, _, _, skill = GetProfessionInfo(slots[index])
            if skill and rank then professions[skill] = { name = name, rank = rank } end
        end
    end
    character.professions = professions
    professionsDirty = false
    return character
end

local function RecordMail()
    local _, total = GetInboxNumItems()
    if type(total) ~= "number" or (issecretvalue and issecretvalue(total)) then return end
    local character = NoxUI.CharData("nuiCharacterOverview", true)
    if character then
        character.mail = total
        character.mailAt = time()
    end
end

local function RecordRecipes()
    local api = C_TradeSkillUI
    if not (api and api.GetBaseProfessionInfo and api.GetRecipeInfo) then return end
    if (api.IsTradeSkillLinked and api.IsTradeSkillLinked())
        or (api.IsTradeSkillGuild and api.IsTradeSkillGuild())
        or (api.IsTradeSkillReady and not api.IsTradeSkillReady()) then return end
    local profession = api.GetBaseProfessionInfo()
    local skill = profession and profession.professionID
    local allRecipes = api.GetAllRecipeIDs
    local listRecipes = allRecipes or api.GetFilteredRecipeIDs
    local ids = skill and listRecipes and listRecipes()
    if not ids or #ids == 0 then return end
    local character = Snapshot()
    if not (character and character.professions[skill]) then return end
    character.recipes = character.recipes or {}
    local recipes = not allRecipes and character.recipes[skill] or {}
    recipes = recipes or {}
    for _, id in ipairs(ids) do
        local recipe = api.GetRecipeInfo(id)
        if recipe and recipe.name then
            if recipe.learned or allRecipes then
                recipes[recipe.name] = recipes[recipe.name] or recipe.learned == true
            end
        end
    end
    character.recipes[skill] = recipes
end

function NoxUI.CharacterOverview()
    Snapshot()
    local rows = {}
    local roster = NoxUI.Chars() or {}
    local guid = NoxUI.CharGUID()
    local current = roster[guid]
    for key, entry in pairs(roster) do
        if entry.name and entry.nuiCharacterOverview
            and (key == guid or (current and entry.realm == current.realm)) then
            rows[#rows + 1] = { name = entry.name, current = key == guid, data = entry.nuiCharacterOverview }
        end
    end
    table.sort(rows, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.name < b.name
    end)
    return rows
end

local function ScheduleSnapshot()
    if pending then return end
    pending = true
    C_Timer.After(0, Snapshot)
end

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION",
    "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_LOGOUT",
    "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "TRADE_SKILL_LIST_UPDATE",
}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" then
        mailboxOpen = true
    elseif event == "MAIL_CLOSED" then
        mailboxOpen = nil
    elseif event == "MAIL_INBOX_UPDATE" then
        if mailboxOpen then RecordMail() end
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        RecordRecipes()
    elseif event == "PLAYER_LOGOUT" then
        Snapshot()
    else
        if event == "SKILL_LINES_CHANGED" then professionsDirty = true end
        ScheduleSnapshot()
    end
end)

local skillPattern
do
    local fmt = ITEM_MIN_SKILL or ITEM_REQ_SKILL
    if type(fmt) == "string" then
        local escaped = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
        local pattern, substitutions = escaped:gsub("%%s", "(.+)")
        local converted, numbers = pattern:gsub("%%d", "(%%d+)")
        if substitutions == 1 and numbers == 1 then skillPattern = "^" .. converted .. "$" end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip or not NoxUIDB or not NoxUIDB.nuiAltRecipeTips or InCombatLockdown() then return end
        if not data or not data.id or (issecretvalue and issecretvalue(data.id)) then return end
        local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(data.id)
        local skill = class == Enum.ItemClass.Recipe and recipeProfessions[subclass]
        if not skill then return end

        local name, professionName, rank
        for i = 1, tooltip:NumLines() do
            local line = _G["GameTooltipTextLeft" .. i]
            local value = line and NoxUI.PlainString(line:GetText())
            if value and i == 1 then name = value:match("^[^:]+:%s*(.+)$") or value end
            if value and skillPattern and not rank then
                professionName, rank = value:match(skillPattern)
                rank = tonumber(rank)
            end
        end
        if not name then return end
        local roster = NoxUI.Chars() or {}
        local guid = NoxUI.CharGUID()
        local current = roster[guid]
        if not current then return end
        local matches = {}
        for key, entry in pairs(roster) do
            local snapshot = entry.nuiCharacterOverview
            local profession = snapshot and snapshot.professions and snapshot.professions[skill]
            if key ~= guid and entry.name and entry.realm == current.realm
                and entry.faction == current.faction and profession then
                local book = snapshot.recipes and snapshot.recipes[skill]
                local learned = book and book[name]
                local status
                if learned then
                    status = NoxUI.L("Recipe already learned")
                elseif rank and profession.name == professionName and profession.rank < rank then
                    status = NoxUI.Lf("Profession skill missing: %d", rank - profession.rank)
                elseif rank and profession.name == professionName and learned == false then
                    status = NoxUI.L("Profession skill reached")
                elseif rank and profession.name == professionName then
                    status = NoxUI.L("Profession skill reached, recipe unverified")
                end
                if status then matches[entry.name] = status end
            end
        end
        local names = {}
        for character in pairs(matches) do names[#names + 1] = character end
        table.sort(names)
        for _, character in ipairs(names) do
            tooltip:AddDoubleLine(character, matches[character], .72, .76, .80, .88, .90, .93)
        end
    end)
end
