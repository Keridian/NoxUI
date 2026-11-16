if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI.RegisterModule then return end

    local pages = { "Apparence", "Caméra", "Contrôles", "Jeu", "Accessibilité" }
    local function BuildPage(page, parent, y)
        local api = _G.DialogueUIAPI
        if not api or not api.GetNoxOptions then return math.abs(y) end
        local schema, get, set, bindings = api.GetNoxOptions()
        local rows = NoxUI.NativeSettingsRows(parent, y)
        local last
        for _, opt in ipairs(schema[pages[page] or 1].options) do
            local function matches(key, expected)
                local value = get(key)
                if type(expected) ~= "table" then return value == expected end
                for _, v in ipairs(expected) do if value == v then return true end end
                return false
            end
            local visible = true
            if opt.requiredParentValueAnd then
                for key, expected in pairs(opt.requiredParentValueAnd) do
                    if not matches(key, expected) then visible = false end
                end
            elseif opt.requiredParentValueOr then
                visible = false
                for key, expected in pairs(opt.requiredParentValueOr) do
                    if matches(key, expected) then visible = true end
                end
            elseif opt.requireSameParentValue then
                visible = last
            end
            last = visible and (opt.requiredParentValueAnd or opt.requiredParentValueOr or opt.requireSameParentValue) and true or false
            if visible and (not opt.validationFunc or opt.validationFunc()) then
                if opt.type == "Subheader" then
                    rows.Header(opt.name)
                elseif opt.type == "Custom" and opt.onClickFunc then
                    rows.Add({ type = "button", text = opt.name, tooltip = opt.description,
                        onClick = function() opt.onClickFunc(); rows.Refresh() end })
                elseif opt.type == "Keybinding" and bindings then
                    rows.Add({ type = "input", text = opt.name, inputStyle = "popup",
                        tooltip = "Saisis une touche, par exemple F8. Vide le champ pour retirer le raccourci.",
                        getValue = function() return bindings:GetBindingKey(opt.action) or "" end,
                        setValue = function(value)
                            if InCombatLockdown() then return end
                            local key = value:match("^%s*(.-)%s*$"):upper()
                            if key == "" then key = nil end
                            bindings:CheckAndSetBindingKey(opt.action, key, false)
                            rows.Refresh()
                        end })
                elseif opt.dbKey and (opt.type == "Checkbox" or opt.choices) then
                    local cfg = {
                        text = opt.name, tooltip = opt.description,
                        getValue = function() return get(opt.dbKey) end,
                        setValue = function(v) set(opt.dbKey, v, true); rows.Refresh() end,
                    }
                    if opt.type == "Checkbox" then
                        cfg.type = "toggle"
                        if opt.alwaysOn then cfg.getValue = function() return true end; cfg.disabled = function() return true end end
                    else
                        cfg.type = "dropdown"
                        cfg.values, cfg.order = {}, {}
                        local choices = type(opt.choices) == "function" and opt.choices(opt.dbKey) or opt.choices
                        for _, choice in ipairs(choices or {}) do
                            if choice.dbValue ~= nil then
                                cfg.order[#cfg.order+1] = choice.dbValue
                                cfg.values[choice.dbValue] = choice.valueText or (type(choice.tooltip) == "string" and choice.tooltip) or tostring(choice.dbValue)
                            end
                        end
                    end
                    rows.Add(cfg)
                end
            end
        end
        return rows.Finish()
    end

    NoxUI:RegisterModule("NoxUIDialogueUI", {
        title = "Dialogues de quête",
        description = "Dialogue avec les PNJ, présentation des quêtes et lecture.",
        searchTerms = "dialogue PNJ quête livre",
        pages = { "Dialogues" },
        buildPage = BuildPage,
    })
end)

if IsLoggedIn() then init:GetScript("OnEvent")(init) end
