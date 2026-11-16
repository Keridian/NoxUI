if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI.RegisterModule then return end

    local pages = { "Général", "Points de passage", "Carte", "Navigation", "Apparence", "Audio", "Extensions", "À propos" }
    local function BuildPage(page, parent, y)
        local api = _G.WaypointUIAPI
        if not api or not api.GetNoxOptions then return math.abs(y) end
        local schema, kind, db, events = api.GetNoxOptions()
        local rows = NoxUI.NativeSettingsRows(parent, y)
        local function resolve(value)
            if type(value) == "function" then return value() end
            return value
        end
        local function build(list)
            for _, opt in ipairs(list or {}) do
                if not opt.showWhen or opt.showWhen() then
                    local t, key = opt.widgetType, opt.key
                    if opt.children then
                        if opt.widgetName then rows.Header(opt.widgetName) end
                        build(opt.children)
                    elseif key or t == kind.Button then
                        local cfg = { text = opt.widgetName or opt.widgetButton_text or "Type de guidage",
                            tooltip = opt.widgetDescription and opt.widgetDescription.description,
                            disabled = opt.disableWhen,
                            getValue = function() return db:GetVariable(key) end,
                            setValue = function(v)
                                if v ~= nil then db:SetVariable(key, v) end
                                events.Trigger("Setting.Refresh")
                                if opt.set then opt.set(nil, v, true) end
                                rows.Refresh()
                            end }
                        if t == kind.CheckButton then cfg.type = "toggle"
                        elseif t == kind.Range then
                            cfg.type = "slider"
                            cfg.min, cfg.max, cfg.step = resolve(opt.widgetRange_min), resolve(opt.widgetRange_max), resolve(opt.widgetRange_step)
                        elseif t == kind.SelectionMenu then
                            cfg.type = "dropdown"
                            cfg.values = resolve(opt.widgetSelectionMenu_data) or {}
                            cfg.order = {}
                            for i in ipairs(cfg.values) do cfg.order[#cfg.order+1] = i end
                            local get, set = cfg.getValue, cfg.setValue
                            if opt.widgetSelectionMenu_get then cfg.getValue = function() return opt.widgetSelectionMenu_get(get()) end end
                            if opt.widgetSelectionMenu_set then cfg.setValue = function(v) set(opt.widgetSelectionMenu_set(v)) end end
                        elseif t == kind.Input then cfg.type = "input"; cfg.inputStyle = "popup"
                        elseif t == kind.ColorInput then
                            local get, set = cfg.getValue, cfg.setValue
                            cfg.type = "colorpicker"
                            cfg.getValue = function() local c = get() or {}; return c.r or 1, c.g or 1, c.b or 1 end
                            cfg.setValue = function(r,g,b) set({r=r,g=g,b=b}) end
                        elseif t == kind.Button and opt.set then
                            cfg.type = "button"
                            cfg.text = opt.widgetButton_text or cfg.text
                            cfg.onClick = function() opt.set(); rows.Refresh() end
                        end
                        if cfg.type then rows.Add(cfg) end
                    end
                end
            end
        end
        local tab = schema[pages[page] or 1]
        if tab and (not tab.showWhen or tab.showWhen()) then build(tab.children) end
        return rows.Finish()
    end

    NoxUI:RegisterModule("NoxUIWaypointUI", {
        title = "Guidage et destinations",
        description = "Repères de destination et navigation dans le monde.",
        searchTerms = "waypoint navigation guidage destination trajet",
        pages = { "Guidage" },
        buildPage = BuildPage,
    })
end)

if IsLoggedIn() then init:GetScript("OnEvent")(init) end
