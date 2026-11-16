if NUI_CLIENT_BLOQUE or not NoxUI or not NoxUI.IS_FOREVER then return end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI.RegisterModule then return end

    local function BuildPage(page, parent, y)
        local rows = NoxUI.NativeSettingsRows(parent, y)
        if page == "ForeverMaps" then
            rows.Header("ForeverMaps")
            local function toggle(key, label)
                rows.Add({ type = "toggle", text = label,
                    getValue = function() return not NoxUIDB or NoxUIDB[key] ~= false end,
                    setValue = function(v)
                        NoxUIDB = NoxUIDB or {}
                        NoxUIDB[key] = v
                        NoxUI:ShowConfirmPopup({title="Cartographie NoxUI", message="Recharge l’interface pour appliquer ce réglage.",
                            confirmText="Recharger", cancelText="Plus tard", reload=true})
                    end })
            end
            toggle("noxForeverMapsSkin", "Habillage NoxUI de ForeverMaps")
            toggle("noxForeverMapsButton", "Bouton Carte du monde dans ForeverMaps")
            return rows.Finish()
        end
        local api = _G.OpenMap
        if not api or not api.GetNoxOptions then return rows.Finish() end
        local function build(group, path)
            local keys = {}
            for key in pairs(group.args or {}) do keys[#keys+1] = key end
            table.sort(keys, function(a,b)
                local x, z = group.args[a].order or 100, group.args[b].order or 100
                if x == z then return a < b end
                return x < z
            end)
            for _, key in ipairs(keys) do
                local opt = group.args[key]
                local info = {unpack(path)}
                info[#info+1], info.type, info.option = key, opt.type, opt
                local hidden = opt.hidden
                if type(hidden) == "function" then hidden = hidden(info) end
                if not hidden then
                    local name = type(opt.name) == "function" and opt.name(info) or opt.name
                    if opt.type == "header" or opt.type == "group" then
                        rows.Header(name)
                        if opt.type == "group" then build(opt, info) end
                    elseif opt.get and opt.set or opt.type == "execute" then
                        local cfg = { text = name, tooltip = type(opt.desc) == "string" and opt.desc or nil,
                            disabled = function()
                                if type(opt.disabled) == "function" then return opt.disabled(info) end
                                return opt.disabled == true
                            end,
                            getValue = function() return opt.get(info) end,
                            setValue = function(...) opt.set(info, ...); rows.Refresh() end }
                        if opt.type == "toggle" then cfg.type = "toggle"
                        elseif opt.type == "range" then cfg.type = "slider"; cfg.min, cfg.max, cfg.step = opt.min, opt.max, opt.step
                        elseif opt.type == "select" then cfg.type = "dropdown"; cfg.values, cfg.order = opt.values, opt.sorting
                        elseif opt.type == "color" then cfg.type = "colorpicker"; cfg.hasAlpha = opt.hasAlpha
                        elseif opt.type == "execute" then cfg.type = "button"; cfg.onClick = function() opt.func(info); rows.Refresh() end end
                        if cfg.type then rows.Add(cfg) end
                    end
                end
            end
        end
        build(api.GetNoxOptions(), {})
        return rows.Finish()
    end

    NoxUI:RegisterModule("NoxUIOpenmap", {
        title = "Carte du monde",
        description = "Carte continue et réglages OpenMap pour WoW Forever.",
        searchTerms = "carte monde openmap zones donjons exploration waypoint guidage destination",
        pages = { "Carte du monde", "ForeverMaps" },
        buildPage = BuildPage,
    })
end)

if IsLoggedIn() then init:GetScript("OnEvent")(init) end
