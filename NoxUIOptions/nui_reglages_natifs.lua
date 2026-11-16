if NUI_CLIENT_BLOQUE or not NoxUI then return end

function NoxUI.NativeSettingsRows(parent, y)
    local W = NoxUI.Widgets
    local pending
    local function flush()
        if not pending then return end
        local _, height = W:DualRow(parent, y, pending, nil)
        y, pending = y - height, nil
    end
    return {
        Add = function(cfg)
            if cfg.type == "colorpicker" then
                cfg = { type = "multiSwatch", text = cfg.text, tooltip = cfg.tooltip,
                    disabled = cfg.disabled, swatches = { cfg } }
            end
            if not pending then pending = cfg; return end
            local _, height = W:DualRow(parent, y, pending, cfg)
            y, pending = y - height, nil
        end,
        Header = function(title)
            if type(title) ~= "string" or title == "" then return end
            flush()
            local _, height = W:SectionHeader(parent, title, y)
            y = y - height
        end,
        Finish = function()
            flush()
            return math.abs(y)
        end,
        Refresh = function()
            C_Timer.After(0, function() NoxUI:RefreshPage(true) end)
        end,
    }
end
