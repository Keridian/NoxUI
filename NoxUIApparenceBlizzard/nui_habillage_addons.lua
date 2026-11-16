if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

local _, ns = ...
local styled = setmetatable({}, { __mode = "k" })
local panels = setmetatable({}, { __mode = "k" })
local syndicatorCanvas
local known = {
    ["AtlasLoot_GUI-Frame"] = "atlas",
    AtlasLootPVPSidePanel = "panel",
    Questie_HeaderFrame = "accent",
    QuestieProfilerFrame = "panel",
    QuestieTrackerQuestTooltip = "panel",
}
local auctionTabs = { "Shopping", "Auctionator", "Cancelling", "Selling" }
local auctionPanels = {
    "AuctionatorShoppingFrame", "AuctionatorConfigFrame", "AuctionatorCancellingFrame",
    "AuctionatorSellingFrame", "AuctionatorShoppingTabItemFrame", "AuctionatorItemHistoryFrame",
    "AuctionatorExportListFrame", "AuctionatorImportListFrame",
}

local function TintText(text)
    if text and text.SetTextColor then text:SetTextColor(.72, .76, .80, 1) end
end

local function Accent(frame, point, r, g, b)
    local line = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    line:SetPoint(point .. "LEFT", 1, 0)
    line:SetPoint(point .. "RIGHT", -1, 0)
    line:SetHeight(2)
    line:SetColorTexture(r, g, b, 1)
end

local function Skin(frame, style)
    if not frame or styled[frame] or not frame.CreateTexture then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    styled[frame] = true
    if style == "panel" or style == "atlas" then
        if frame.SetBackdropColor then frame:SetBackdropColor(.055, .068, .084, .98) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(.35, .40, .45, 1) end
        for _, key in ipairs({ "Bg", "Background" }) do
            local region = frame[key]
            if region and region.SetVertexColor then region:SetVertexColor(.32, .37, .43) end
        end
        TintText(frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText))
        if style == "atlas" and frame.titleFrame then TintText(frame.titleFrame.text) end
    end
    if style == "icon" then
        Accent(frame, "TOP", .72, .76, .80)
        Accent(frame, "BOTTOM", .59, .17, .20)
    else
        Accent(frame, "TOP", .49, .19, .22)
        if style == "tab" then TintText(frame.GetFontString and frame:GetFontString()) end
    end
end

local journalHooked
local journalPalette = {
    frame = { .035, .042, .052, .99 },
    content = { .067, .078, .094, .96 },
    border = { .31, .36, .41, 1 },
    header = { .090, .103, .121, 1 },
    left = { .050, .060, .074, .96 },
    right = { .059, .069, .084, .96 },
    row = { .084, .096, .112, .96 },
    lootRow = { .078, .090, .106, .96 },
    text = { .88, .91, .94 },
    muted = { 184 / 255, 195 / 255, 204 / 255 },
}
local journalAccent = { .78, .35, .38 }
local dungeonAccents = {
    ["The Deadmines"] = { .78, .62, .39 },
    ["The Stockade"] = { .69, .75, .84 },
    ["Excavation Site: Wetlands"] = { .79, .65, .46 },
    ["Razorfen Kraul"] = { .80, .51, .63 },
    ["Razorfen Downs"] = { .62, .73, .56 },
    ["Scarlet Monastery: Graveyard"] = { .79, .57, .58 },
    ["Scarlet Monastery: Library"] = { .85, .59, .45 },
    ["Scarlet Monastery: Armory"] = { .88, .48, .45 },
    ["Scarlet Monastery: Cathedral"] = { .94, .62, .60 },
    ["Uldaman"] = { .82, .61, .40 },
    ["Zul'Farrak"] = { .90, .74, .46 },
    ["The Drowned City"] = { .45, .76, .82 },
    ["Krol'dok Stronghold"] = { .81, .51, .42 },
    ["Alcaz Prison"] = { .53, .77, .66 },
    ["Blackmaw Hold"] = { .77, .57, .69 },
    ["Shaper's Terrace"] = { .73, .82, .54 },
    ["Sunken Temple"] = { .47, .79, .66 },
    ["Scholomance"] = { .76, .69, .91 },
    ["Maraudon"] = { .85, .57, .78 },
    ["Dire Maul: East"] = { .60, .78, .54 },
    ["Dire Maul: West"] = { .65, .71, .93 },
    ["Dire Maul: North"] = { .85, .67, .43 },
    ["Stratholme: Living"] = { .92, .66, .46 },
    ["Stratholme: Undead"] = { .58, .77, .75 },
    ["Blackrock Depths"] = { .95, .54, .39 },
    ["Upper Blackrock Spire"] = { .88, .47, .54 },
    ["Lower Blackrock Spire"] = { .76, .60, .47 },
    ["Onyxia Attunement"] = { .79, .56, .92 },
    ["Onyxia's Lair"] = { .79, .56, .92 },
    ["Molten Core"] = { .95, .57, .34 },
    ["Blackwing Lair"] = { .82, .53, .69 },
    ["Zul'Gurub"] = { .58, .79, .48 },
    ["Ruins of Ahn'Qiraj"] = { .87, .73, .45 },
    ["Temple of Ahn'Qiraj"] = { .78, .61, .50 },
    ["Naxxramas"] = { .56, .76, .86 },
    ["Barrow Deeps"] = { .53, .72, .91 },
    ["Hyjal Summit"] = { .67, .82, .53 },
}
local solid = "Interface\\Buttons\\WHITE8X8"

local function JournalBackdrop(frame)
    local current = frame:GetBackdrop()
    if not current then return end
    frame:SetBackdrop({ bgFile = solid, edgeFile = solid, edgeSize = 1, insets = current.insets })
end

local function JournalButton(button)
    if not button then return end
    if button.Left then button.Left:Hide() end
    if button.Middle then button.Middle:Hide() end
    if button.Right then button.Right:Hide() end
    button:SetNormalTexture(solid)
    button:GetNormalTexture():SetVertexColor(.13, .15, .18)
    button:SetPushedTexture(solid)
    button:GetPushedTexture():SetVertexColor(.26, .29, .33)
    button:SetDisabledTexture(solid)
    button:GetDisabledTexture():SetVertexColor(.20, .23, .27)
    button:SetHighlightTexture(solid, "ADD")
    button:GetHighlightTexture():SetVertexColor(.15, .17, .20, .45)
end

local journalParchments = {
    "homeParchment", "contentParchment", "headerParchment", "leftParchment",
    "rightParchment", "questLeftParchment", "questRightParchment",
}

local function SkinDungeonJournal()
    if journalHooked then return end
    local journal = _G.ForeverDungeonJournalFrame
    local addon = _G.ForeverDungeonJournal_NS
    if not (journal and journal.mainTitle and journal.questRightPanel and addon and addon.THEMES) then return end

    -- Replace individual entries: several dungeon wings share the same upstream table.
    local function SetPalette(key, original)
        local accent = dungeonAccents[key] or (original and original.title) or journalAccent
        local theme = {}
        for field, value in pairs(original or {}) do theme[field] = value end
        for field, value in pairs(journalPalette) do theme[field] = value end
        local r, g, b = unpack(accent)
        theme.title = accent
        theme.border = { .10 + r * .46, .10 + g * .46, .10 + b * .46, 1 }
        theme.rowSelected = { .07 + r * .27, .07 + g * .27, .07 + b * .27, 1 }
        addon.THEMES[key] = theme
    end
    for key, theme in pairs(addon.THEMES) do SetPalette(key, theme) end
    for key in pairs(addon.DB or {}) do
        if not addon.THEMES[key] then SetPalette(key) end
    end

    local panelsByRole = {
        contentPanel = "content", headerPanel = "header", homePanel = "content",
        leftPanel = "left", rightPanel = "right",
        questLeftPanel = "left", questRightPanel = "right",
    }
    JournalBackdrop(journal)
    for key in pairs(panelsByRole) do
        if journal[key] then JournalBackdrop(journal[key]) end
    end
    if journal.searchEditBox then
        JournalBackdrop(journal.searchEditBox)
        journal.searchEditBox:SetBackdropColor(.055, .064, .078, 1)
        journal.searchEditBox:SetBackdropBorderColor(unpack(journalPalette.border))
    end
    for _, key in ipairs({ "backButton", "bossesTab", "questsTab", "mapTab", "dungeonRouteButton" }) do
        JournalButton(journal[key])
    end
    journal:SetBackdropColor(unpack(journalPalette.frame))
    journal:SetBackdropBorderColor(unpack(journalPalette.border))
    journal.topStrip:SetColorTexture(unpack(journalPalette.header))
    journal.topStripLine:SetColorTexture(unpack(journalPalette.border))
    journal.topStripBottomLine:SetHeight(2)
    journal.mainTitle:SetTextColor(unpack(journalPalette.text))
    journal.homeTitle:SetTextColor(unpack(journalPalette.text))
    TintText(journal.homeSubtitle)

    local queued
    local function ApplySurfaces()
        queued = nil
        if InCombatLockdown() or (NoxUI.BlizzWindowSkinsKilled and NoxUI.BlizzWindowSkinsKilled()) then return end
        local key = addon.GetSelectedDungeon and addon.GetSelectedDungeon()
        local theme = journal.currentView == "dungeon" and addon.THEMES[key]
        local accent = theme and theme.title or journalAccent
        local r, g, b = unpack(accent)
        journal.topStripBottomLine:SetColorTexture(r, g, b, 1)
        journal.topStrip:SetColorTexture(.045 + r * .085, .052 + g * .085, .065 + b * .085, 1)
        for field, role in pairs(panelsByRole) do
            local panel = journal[field]
            if panel then
                panel:SetBackdropColor(unpack(journalPalette[role]))
                panel:SetBackdropBorderColor(unpack(theme and theme.border or journalPalette.border))
            end
        end
        journal.dungeonTitle:SetTextColor(r, g, b)
        TintText(journal.dungeonMeta)
        if journal.questHeaderSeparator then
            journal.questHeaderSeparator:SetColorTexture(r, g, b, .9)
        end
        for _, key in ipairs(journalParchments) do
            if journal[key] then journal[key]:SetAlpha(0) end
        end
    end
    -- ApplyTheme recolors these surfaces after it redraws the window backdrop.
    local function ScheduleSurfaces()
        if queued then return end
        queued = true
        C_Timer.After(0, ApplySurfaces)
    end
    hooksecurefunc(journal, "SetBackdropColor", ScheduleSurfaces)
    journal:HookScript("OnShow", ScheduleSurfaces)
    journal.homePanel:HookScript("OnShow", ScheduleSurfaces)
    journal.contentPanel:HookScript("OnShow", ScheduleSurfaces)
    journalHooked = true
    ApplySurfaces()
end

local auctionStyled = setmetatable({}, { __mode = "k" })
local auctionInsetKeys = {
    "Inset", "BagInset", "CurrentPricesInset", "HistoricalPriceInset",
    "ShoppingResultsInset", "ResultsInset", "ListInset", "ItemListInset",
}
local auctionButtonKeys = {
    "BackButton", "BuyButton", "CancelButton", "ContinueButton", "AcceptButton",
    "PostButton", "SkipButton", "PrevButton", "MaxButton", "SearchButton",
    "AddButton", "DeleteButton", "ImportButton", "ExportButton",
}
local auctionAuxTabs = { "CurrentPricesTab", "PriceHistoryTab", "YourHistoryTab" }

local function SkinAuctionControls(frame, skin, depth)
    if depth > 6 or not frame.GetChildren or frame:IsForbidden() then return end
    for _, key in ipairs(auctionInsetKeys) do
        local inset = frame[key]
        if inset and inset:IsObjectType("Frame") and not auctionStyled[inset] then
            skin.Inset(inset)
            auctionStyled[inset] = true
        end
    end
    for _, key in ipairs(auctionButtonKeys) do
        local button = frame[key]
        if button and button:IsObjectType("Button") and not auctionStyled[button] then
            skin.Button(button)
            skin.StateButtonLabel(button)
            auctionStyled[button] = true
        end
    end
    for _, key in ipairs(auctionAuxTabs) do
        local tab = frame[key]
        if tab and not auctionStyled[tab] then
            skin.Tab(tab, { darkActive = true })
            auctionStyled[tab] = true
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetObjectType() == "EditBox" and not auctionStyled[child] then
            skin.EditBox(child)
            auctionStyled[child] = true
        end
        -- ScrollBox contents are recycled item rows with their own state and art.
        if not (child.ScrollTarget or child.GetView or child == frame.ScrollBox) then
            SkinAuctionControls(child, skin, depth + 1)
        end
    end
end

local auctionTabPanels = {
    Shopping = "AuctionatorShoppingFrame", Auctionator = "AuctionatorConfigFrame",
    Cancelling = "AuctionatorCancellingFrame", Selling = "AuctionatorSellingFrame",
}
local function SyncAuctionTabs()
    local skin = ns.WSkin
    if not skin then return end
    for _, key in ipairs(auctionTabs) do
        local tab, panel = _G["AuctionatorTabs_" .. key], _G[auctionTabPanels[key]]
        if tab and auctionStyled[tab] and panel then skin.SetTabSelection(tab, panel:IsShown()) end
    end
end

local function SkinAuctionator()
    local skin = ns.WSkin
    if not (skin and _G.Auctionator) then return end
    for _, name in ipairs(auctionPanels) do
        local frame = _G[name]
        if frame and not auctionStyled[frame] then
            Skin(frame, name:find("TabItemFrame") and "panel" or "accent")
            if frame.NineSlice then skin.FadeNineSlice(frame.NineSlice) end
            skin.CommonChrome(frame, nil, true)
            skin.ScrollBarsIn(frame)
            SkinAuctionControls(frame, skin, 0)
            auctionStyled[frame] = true
            frame:HookScript("OnShow", function()
                if InCombatLockdown() or (NoxUI.BlizzWindowSkinsKilled and NoxUI.BlizzWindowSkinsKilled()) then return end
                SkinAuctionControls(frame, skin, 0)
                SyncAuctionTabs()
            end)
            frame:HookScript("OnHide", SyncAuctionTabs)
        end
    end
    local changed
    for _, key in ipairs(auctionTabs) do
        local tab = _G["AuctionatorTabs_" .. key]
        if tab and not auctionStyled[tab] then
            skin.Tab(tab, { darkActive = true })
            auctionStyled[tab] = true
            changed = true
        end
    end
    if changed then SyncAuctionTabs() end
end

local function Refresh()
    if InCombatLockdown() or (NoxUI.BlizzWindowSkinsKilled and NoxUI.BlizzWindowSkinsKilled()) then return end
    SkinDungeonJournal()
    for name, style in pairs(known) do Skin(_G[name], style) end
    local journey = _G.QuestieJourneyFrame
    if journey then Skin(journey.frame, "panel"); TintText(journey.titletext) end
    SkinAuctionator()
    local hekili = _G.Hekili
    local displays = hekili and hekili.DB and hekili.DB.profile and hekili.DB.profile.displays
    if displays then
        for id in pairs(displays) do
            local display = _G["HekiliDisplay" .. id]
            for _, button in pairs(display and display.Buttons or {}) do Skin(button, "icon") end
        end
    end
    Skin(syndicatorCanvas, "accent")
    for frame in pairs(panels) do Skin(frame, "panel") end
end

local function FindSyndicatorCanvas()
    if syndicatorCanvas or not (_G.Syndicator and _G.Syndicator.OptionsCategory and EnumerateFrames) then return end
    local frame = EnumerateFrames()
    while frame do
        if not (frame.IsForbidden and frame:IsForbidden()) and frame.OnCommit and frame.OnDefault and frame.OnRefresh and frame.GetRegions then
            local first = frame:GetRegions()
            local title = first and first.GetText and first:GetText()
            if type(title) == "string" and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "Syndicator" then
                syndicatorCanvas = frame
                return
            end
        end
        frame = EnumerateFrames(frame)
    end
end

local questieHooked
local questieMarks = setmetatable({}, { __mode = "k" })

local function HookQuestieTitles()
    if questieHooked or not QuestieLoader or not QuestieLoader.ImportModule then return end
    local section = QuestieLoader:ImportModule("QuestSection")
    local pool = QuestieLoader:ImportModule("TrackerLinePool")
    if not (section and section.Draw and pool and pool.ForEachQuestTitleLine and pool.GetCurrentLine and pool.GetNextLine) then return end
    questieHooked = true
    hooksecurefunc(pool, "GetNextLine", function()
        local mark = questieMarks[pool.GetCurrentLine()]
        if mark then mark:Hide() end
    end)
    hooksecurefunc(section, "Draw", function()
        pool.ForEachQuestTitleLine(function(line)
            local quest, label = line.Quest, line.label
            local mark = questieMarks[line]
            local done
            if line:IsShown() and label and quest and quest.IsComplete
                and not (NoxUI.BlizzWindowSkinsKilled and NoxUI.BlizzWindowSkinsKilled()) then
                local state = quest:IsComplete()
                done = state == 1 or (state ~= -1 and quest.isComplete == true)
            end
            if not done then if mark then mark:Hide() end; return end
            local width = math.min(label:GetWidth(), label:GetUnboundedStringWidth())
            if width <= 0 then if mark then mark:Hide() end; return end
            if not mark then
                if InCombatLockdown() then return end
                mark = line:CreateTexture(nil, "OVERLAY", nil, 2)
                mark:SetTexture("Interface\\AddOns\\NoxUIApparenceBlizzard\\nui_trait_feutre.tga")
                mark:SetAlpha(.77)
                questieMarks[line] = mark
            end
            local _, size = label:GetFont()
            size = size or 12
            mark:ClearAllPoints()
            mark:SetPoint("LEFT", label, "TOPLEFT", -1, -size * .50)
            mark:SetSize(width + 2, math.max(5, size * .49))
            mark:Show()
        end)
    end)
end

local hookedSearch
local function Discover(_, event, addon)
    if event == "PLAYER_LOGIN" or addon == "Questie" then HookQuestieTitles() end
    if event == "PLAYER_LOGIN" or addon == "Syndicator" then FindSyndicatorCanvas() end
    local search = _G.Syndicator and _G.Syndicator.Search
    if search and search.GetSearchEverywhereInterface and not hookedSearch then
        -- The search widget exposes a skin callback but its frame has no global name.
        -- Existing consumers keep their own skin callback and receive the original frame.
        local original = search.GetSearchEverywhereInterface
        search.GetSearchEverywhereInterface = function(parent, skinner, ...)
            return original(parent, function(...)
                if skinner then skinner(...) end
                local first, second, third = ...
                local frame = first == "ButtonFrame" and second or second == "ButtonFrame" and third
                if frame then panels[frame] = true; Refresh() end
            end, ...)
        end
        hookedSearch = true
    end
    Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", Discover)
C_Timer.NewTicker(1, Refresh)
