if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_blizzard_apparence_options.lua
-------------------------------------------------------------------------------
local ns = NoxUI._ModuleNS["NoxUIApparenceBlizzard"]  -- module namespace (published by the module at its load)
if not ns then return end  -- module disabled: no options page
local PAGE_WINDOWSKINS   = "Blizzard Window Skins"
local PAGE_TOOLTIPS      = "Tooltips, Menus & Popups"
local PAGE_DRAGONRIDING  = "Dragon Riding"
local PAGE_CHATBUBBLES   = "Chat Bubbles"
-- A link tab: opens Quality of Life's Shifter (see pageLinks below).
local PAGE_WINDOWMOVER   = "Window Mover"
-- Display-only tab labels: the page names above stay the pages' identities
-- (nav links, Unlock Mode, saved state).
NoxUI.TAB_LABEL_OVERRIDES[PAGE_WINDOWSKINS] = "Window Skins"
NoxUI.TAB_LABEL_OVERRIDES[PAGE_TOOLTIPS] = "Tooltips & Menus"
NoxUI.TAB_LABEL_OVERRIDES[PAGE_DRAGONRIDING] = "Skyriding"
NoxUI.TAB_LABEL_OVERRIDES[PAGE_WINDOWMOVER] = "Window Mover"

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not NoxUI or not NoxUI.RegisterModule then return end
    -- Page reuse (NoxUI_FramePool.lua): a frame made under a page pool
    -- host comes from the pool and is dressed again by every later build; under
    -- any other parent it is a plain new frame.
    local CreateFrame = NoxUI._Pool.CreateFrame

    -- Border rows shared by the Tooltips page and the Loot Window card, over a key prefix's
    -- <prefix>Border* settings (drawn by _applyConfiguredBorder, nui_blizzard_apparence_infobulle_apparence.lua).
    -- The step the skin renders with: the stored label (an unknown one = thin); unset = the
    -- legacy numeric tooltipBorderSize for the tooltip, 1 otherwise.
    local function BorderStep(prefix)
        local key = NoxUIDB[prefix.."BorderThickness"]
        if key then return NoxUI.BORDER_STEP_OF_LABEL[key] or 1 end
        if prefix == "tooltip" then return NoxUIDB.tooltipBorderSize or 1 end
        return 1
    end
    -- Border Size in pixels over <prefix>BorderThickness (still a label) and its <prefix>BorderThicknessPx companion.
    -- The short track leaves room for the color swatches beside it.
    local function BorderSizeSlider(prefix, text, disabledFn, apply, disabledTooltip)
        return NoxUI.BorderPxSliderCfg{
            text = text, disabled = disabledFn, disabledTooltip = disabledTooltip, trackWidth = 120,
            getStep = function() return BorderStep(prefix) end,
            setStep = function(step) NoxUIDB[prefix.."BorderThickness"] = NoxUI.BORDER_LABEL_OF_STEP[step] or "thin" end,
            getTex = function() return NoxUIDB[prefix.."BorderTexture"] or "solid" end,
            getPx = function() return NoxUIDB[prefix.."BorderThicknessPx"] end,
            setPx = function(v) NoxUIDB[prefix.."BorderThicknessPx"] = v end,
            apply = apply,
        }
    end
    -- The registry sizeKey the skin passes beside the addonKey "blizzardSkin" (registered
    -- nowhere, so an UNSET offset resolves to 0/0, never to the global per-texture defaults).
    local function BorderSizeKey(prefix)
        return NoxUIDB[prefix.."BorderThickness"] or NoxUI.BORDER_LABEL_OF_STEP[BorderStep(prefix)] or "thin"
    end
    -- The Width Offset | Height Offset cfgs for a textured style; nil for a solid one (no offsets).
    local function BorderOffsetCfgs(prefix, disabledFn, apply, disabledTooltip)
        local tex = NoxUIDB[prefix.."BorderTexture"] or "solid"
        if tex == "" or tex == "solid" then return end
        return NoxUI.BorderOffsetRowCfgs{
            addonKey = "blizzardSkin", disabled = disabledFn, disabledTooltip = disabledTooltip,
            getTex = function() return NoxUIDB[prefix.."BorderTexture"] or "solid" end,
            getStep = function() return BorderStep(prefix) end,
            getSizeKey = function() return BorderSizeKey(prefix) end,
            getPx = function() return NoxUIDB[prefix.."BorderThicknessPx"] end,
            getX = function() return NoxUIDB[prefix.."BorderOffsetX"] end,
            setX = function(v) NoxUIDB[prefix.."BorderOffsetX"] = v end,
            getY = function() return NoxUIDB[prefix.."BorderOffsetY"] end,
            setY = function(v) NoxUIDB[prefix.."BorderOffsetY"] = v end,
            apply = apply,
        }
    end
    -- A Border Style dropdown whose first entry, Default, leaves <prefix>BorderTexture unset
    -- (the surface's own border): its values and order, and the write for a pick.
    local function DefaultableBorderValues()
        local values, order = NoxUI.GetBorderTextureDropdown()
        values.default = "Default"
        table.insert(order, 1, "default")
        return values, order
    end
    local function SetDefaultableBorderStyle(prefix, v)
        local db = NoxUIDB
        if v == "default" then
            db[prefix.."BorderTexture"] = nil
        else
            local c, b = NoxUI.GetBorderStyleSelectDefaults(v)
            db[prefix.."BorderTexture"] = v
            db[prefix.."BorderBehind"] = b
            db[prefix.."BorderColor"] = c
            -- Full opacity and the style's own size: the 18% default leaves textured art faded
            db[prefix.."BorderOpacity"] = 1
            local size = NoxUI.GetBorderDefaultSize(nil, v)
            if size then db[prefix.."BorderThickness"] = NoxUI.BORDER_LABEL_OF_STEP[size] end
        end
        db[prefix.."BorderOffsetX"] = nil
        db[prefix.."BorderOffsetY"] = nil
        if db[prefix.."BorderThicknessPx"] then db[prefix.."BorderThicknessPx"] = false end
    end
    -- A border row's inline controls: the Accent | Class | Custom color mode swatches left of
    -- its Border Size, and the Show Behind cog (allowBehind) left of its style. A cog built on
    -- the Border Size half before this call keeps its place beside the control: the swatches
    -- chain left of it. opts: apply = run after a pick (the Loot Window card's live refresh);
    -- quality = { key, tip } adds a Quality swatch whose own color is saved at key.
    local function AttachBorderControls(row, prefix, disabledFn, allowBehind, opts)
        local PP = NoxUI.PanelPP
        local apply = opts and opts.apply
        local left, right = row._leftRegion, row._rightRegion
        -- The offsets live in their own row below the style row (BorderOffsetCfgs); the cog
        -- keeps only Show Behind, so a surface without that option gets no cog at all.
        if allowBehind then
            local popupRows = {
                { type="toggle", label="Show Behind",
                  get=function() return NoxUIDB[prefix.."BorderBehind"] or false end,
                  set=function(v) NoxUIDB[prefix.."BorderBehind"]=v; if apply then apply() end end },
            }
            NoxUI.BuildInlineCog(left, {
                title = "Border Options", rows = popupRows,
                anchorTo = left._control,
                disabled = disabledFn,
                disabledTooltip = prefix == "tooltip" and "Reskin Tooltip" or "Reskin Popups and Menus",
            })
        end
        if NoxUI._prebuilding then return end

        -- A pickable swatch (Custom, Quality) opens its color picker on a click while its mode
        -- is the active one; colorKey is where it saves (default the Custom color).
        local function AddModeSwatch(anchor, mode, tip, getColor, pickable, colorKey)
            local sw, refresh=NoxUI.BuildColorSwatch(right,right:GetFrameLevel()+5,getColor,
                function(r,g,b,a)
                    NoxUIDB[colorKey or (prefix.."BorderColor")]={r=r,g=g,b=b}
                    NoxUIDB[prefix.."BorderOpacity"]=a
                    NoxUIDB[prefix.."BorderColorMode"]=mode
                    if apply then apply() end
                end,
                pickable,20)
            PP.Point(sw,"RIGHT",anchor,"LEFT",-8,0)
            local orig=sw:GetScript("OnClick")
            sw:SetScript("OnClick",function(self)
                if not pickable or (NoxUIDB[prefix.."BorderColorMode"] or "custom")~=mode then
                    NoxUIDB[prefix.."BorderColorMode"]=mode
                    if apply then apply() end
                    NoxUI:RefreshPage(); return
                end
                orig(self)
            end)
            sw:HookScript("OnEnter",function(self) NoxUI.ShowWidgetTooltip(self,tip) end)
            sw:HookScript("OnLeave",function() NoxUI.HideWidgetTooltip() end)
            -- Applied once at build time too -- widget refresh only fires
            -- on later changes, so without this every swatch opened lit.
            local function UpdSwatchState()
                local off=disabledFn and disabledFn(); local active=(NoxUIDB[prefix.."BorderColorMode"] or "custom")==mode
                sw:SetAlpha(off and .15 or (active and 1 or .3)); sw:EnableMouse(not off); refresh()
            end
            NoxUI.RegisterWidgetRefresh(UpdSwatchState)
            UpdSwatchState()
            return sw
        end
        local accent=AddModeSwatch(right._control,"accent","Accent Color",function() local c=NoxUI.NOX_GREEN; return c.r,c.g,c.b,1 end,false)
        local class=AddModeSwatch(accent,"class","Class Color",function() local _,k=UnitClass("player"); local c=RAID_CLASS_COLORS[k]; return c.r,c.g,c.b,1 end,false)
        local last=AddModeSwatch(class,"custom","Custom Color",function() local c=NoxUIDB[prefix.."BorderColor"] or {r=1,g=1,b=1}; return c.r,c.g,c.b,NoxUIDB[prefix.."BorderOpacity"] or NoxUI.RESKIN.BRD_ALPHA end,true)
        local q = opts and opts.quality
        if q then
            last=AddModeSwatch(last,"quality",q.tip,function() local c=NoxUIDB[q.key] or {r=1,g=1,b=1}; return c.r,c.g,c.b,NoxUIDB[prefix.."BorderOpacity"] or NoxUI.RESKIN.BRD_ALPHA end,true,q.key)
        end
        right._lastInline=last
    end

    -- Header builder for runtime-painted samples at their on-screen size: the panel's scale
    -- compensated, each shrunk only when wider than its column. cols = { { show, title } };
    -- show(header, place) builds or re-hangs a sample, place(root) runs before its paint and
    -- place(root, w, h) after it. Titled columns sit side by side, tops on one line under a
    -- small title (the Mythic+ Tools header previews' look); one untitled column centres.
    local PV_TITLE_H = 15
    local function SampleHeaderBuilder(cols)
        return function(header, hdrW)
            local building, H = true, 0
            local n = #cols
            local titled = cols[1].title ~= nil
            local titleH = titled and PV_TITLE_H or 0
            local st = {}
            local lblHost
            if titled then
                lblHost = CreateFrame("Frame", nil, header)
                lblHost:SetAllPoints(header)
                lblHost:SetFrameLevel(header:GetFrameLevel() + 3)
            end
            local function Layout()
                local s = UIParent:GetEffectiveScale() / header:GetEffectiveScale()
                local colW = ((building and hdrW or header:GetWidth()) - 2 * NoxUI.CONTENT_PAD) / n
                local maxH = 0
                for i = 1, n do
                    local c = st[i]
                    if c and c.w then
                        local fit = (c.w > 0) and math.min(1, colW / (c.w * s)) or 1
                        c.root:SetScale(s * fit)
                        maxH = math.max(maxH, c.h * s * fit)
                    end
                end
                local blockH = maxH + titleH
                for i = 1, n do
                    local c = st[i]
                    if c and c.w then
                        local root = c.root
                        root:ClearAllPoints()
                        if titled then
                            -- Offsets in the sample's own units, snapped to its physical pixels.
                            local hs = root:GetScale()
                            local onePx = NoxUI.PP.perfect / root:GetEffectiveScale()
                            local function Snap(v) return math.floor(v / onePx + 0.5) * onePx end
                            local cx = (-(n - 1) / 2 + (i - 1)) * colW
                            root:SetPoint("TOP", header, "CENTER", Snap(cx / hs), Snap((blockH / 2 - titleH) / hs))
                            c.fs:ClearAllPoints()
                            c.fs:SetPoint("BOTTOMLEFT", root, "TOPLEFT", 0, 3)
                            c.fs:Show()
                        else
                            root:SetPoint("CENTER", header, "CENTER", 0, 0)
                        end
                    end
                end
                H = math.max(80, math.ceil(blockH + 40))
                if not building and header:IsVisible() and math.abs(header:GetHeight() - H) > 1 then
                    NoxUI:SetContentHeaderHeightSilent(H)
                end
            end
            for i = 1, n do
                local c = { }
                st[i] = c
                if titled then
                    c.fs = NoxUI.MakeFont(lblHost, 11, nil, 1, 1, 1)
                    c.fs:SetAlpha(0.6)
                    c.fs:SetText(cols[i].title)
                    c.fs:Hide()
                end
                cols[i].show(header, function(root, w, h)
                    if not w then
                        root:SetScale(UIParent:GetEffectiveScale() / header:GetEffectiveScale())
                        return
                    end
                    c.root, c.w, c.h = root, w, h
                    Layout()
                end)
            end
            building = false
            return H
        end
    end
    -- Popups first, as the page's sections run.
    local TooltipHeaderBuilder = SampleHeaderBuilder({
        { title = NoxUI.L("Popups"), show = function(header, place)
            if NoxUI.ShowPopupPreview then NoxUI.ShowPopupPreview(header, place) end
        end },
        { title = NoxUI.L("Tooltip"), show = function(header, place)
            if NoxUI.ShowTooltipPreview then NoxUI.ShowTooltipPreview(header, place) end
        end },
    })
    local function TooltipPreviewRepaint()
        if NoxUI._repaintTooltipPreview then NoxUI._repaintTooltipPreview() end
    end
    local function PopupPreviewRepaint()
        if NoxUI._repaintPopupPreview then NoxUI._repaintPopupPreview() end
    end

    local function BuildTooltipsPage(pageName, parent, yOffset)
        if not NoxUIDB then NoxUIDB = {} end
        local W = NoxUI.Widgets
        local y = yOffset
        local _, h
        -- The border row helpers (BorderSizeSlider, BorderOffsetCfgs, AttachBorderControls) sit
        -- above this page, shared with the Loot Window card.
        -- Width Offset | Height Offset right below a Border Style row, only while its style is
        -- textured (a solid border has no offsets). Built in every pass so the y advance never differs.
        local function BorderOffsetRow(prefix, disabledFn, apply)
            local ocfgL, ocfgR = BorderOffsetCfgs(prefix, disabledFn, apply)
            if ocfgL then _, h = W:DualRow(parent, y, ocfgL, ocfgR); y = y - h end
        end

        -- The sample tooltip and popup head the page.
        if not NoxUI._prebuilding then
            NoxUI:SetContentHeader(TooltipHeaderBuilder)
        elseif NoxUI.ClearContentHeader then
            NoxUI:ClearContentHeader()
        end
        parent._showRowDivider = true

        _, h = W:Spacer(parent, y, 20);  y = y - h

        _, h = W:SectionHeader(parent, "BLIZZARD POPUPS & GAME MENU", y);  y = y - h

        local function popupOff() return NoxUIDB.reskinPopupsMenus == false end
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Reskin Popups and Menus",
              tooltip="Reskins Blizzard's right-click context menus and pop-ups.",
              getValue=function()
                  -- Seeded from the old master by the blizzskin_reskin_master_split_v1
                  -- migration; independent thereafter. Default on.
                  return not NoxUIDB or NoxUIDB.reskinPopupsMenus ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinPopupsMenus = v
                  -- Resurrect Accept Glow runs only under the reskin: sync a shown popup now
                  if NoxUI._EnsureResurrectGlow then NoxUI._EnsureResurrectGlow() end
                  NoxUI:RefreshPage()  -- update the border cog, swatch and glow disabled states
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Reskin setting requires a UI reload to fully apply.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end },
            { type="toggle", text="Resurrect Accept Glow",
              tooltip="Adds a glowing border around the Accept button of resurrection popups.",
              disabled=popupOff, disabledTooltip="Reskin Popups and Menus",
              getValue=function()
                  return NoxUIDB and NoxUIDB.resurrectAcceptGlow or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.resurrectAcceptGlow = v
                  if NoxUI._EnsureResurrectGlow then NoxUI._EnsureResurrectGlow() end
              end }
        );  y = y - h

        do
            local texValues,texOrder=NoxUI.GetBorderTextureDropdown()
            local outer
            outer,h=W:DualRow(parent,y,
                {type="dropdown",text="Border Style",disabled=popupOff,values=texValues,order=texOrder,getValue=function() return NoxUIDB.popupMenuBorderTexture or "solid" end,setValue=function(v) local c,b=NoxUI.GetBorderStyleSelectDefaults(v); NoxUIDB.popupMenuBorderTexture=v; NoxUIDB.popupMenuBorderOffsetX=nil; NoxUIDB.popupMenuBorderOffsetY=nil; NoxUIDB.popupMenuBorderBehind=b; NoxUIDB.popupMenuBorderColor=c; if NoxUIDB.popupMenuBorderThicknessPx then NoxUIDB.popupMenuBorderThicknessPx=false end; NoxUI:RefreshPage(true) end},
                BorderSizeSlider("popupMenu","Border Size",popupOff,PopupPreviewRepaint)); y=y-h
            AttachBorderControls(outer,"popupMenu",popupOff,true,{ apply = PopupPreviewRepaint })
            BorderOffsetRow("popupMenu",popupOff,PopupPreviewRepaint)
            local buttons
            buttons,h=W:DualRow(parent,y,
                {type="dropdown",text="Button Border Style",disabled=popupOff,values=texValues,order=texOrder,getValue=function() return NoxUIDB.popupMenuButtonBorderTexture or "solid" end,setValue=function(v) NoxUIDB.popupMenuButtonBorderTexture=v; local sc=NoxUI.GetBorderSelectColor(v); if sc then NoxUIDB.popupMenuButtonBorderColor=sc end; NoxUIDB.popupMenuButtonBorderOffsetX=nil; NoxUIDB.popupMenuButtonBorderOffsetY=nil; if NoxUIDB.popupMenuButtonBorderThicknessPx then NoxUIDB.popupMenuButtonBorderThicknessPx=false end; NoxUI:RefreshPage(true) end},
                BorderSizeSlider("popupMenuButton","Button Border Size",popupOff,PopupPreviewRepaint)); y=y-h
            AttachBorderControls(buttons,"popupMenuButton",popupOff,nil,{ apply = PopupPreviewRepaint })
            BorderOffsetRow("popupMenuButton",popupOff,PopupPreviewRepaint)
        end

        _,h=W:DualRow(parent,y,
            {type="colorpicker",text="Button Background",hasAlpha=true,disabled=popupOff,getValue=function() local c=NoxUIDB.popupMenuButtonBackgroundColor or {r=.1,g=.1,b=.1,a=.8}; return c.r,c.g,c.b,c.a end,setValue=function(r,g,b,a) NoxUIDB.popupMenuButtonBackgroundColor={r=r,g=g,b=b,a=a}; PopupPreviewRepaint() end},
            {type="multiSwatch",text="Element & Text Color",disabled=popupOff,swatches={
                -- Effective mode comes from the skin file's resolver: unset =
                -- native unless the legacy Accent Colored Elements opt-in is present.
                -- All four highlights read it so the default state is shown truthfully.
                {tooltip="Native Colors",hasAlpha=false,getValue=function() return 1,1,1 end,setValue=function() end,onClick=function() NoxUIDB.popupMenuButtonTextColorMode="native"; PopupPreviewRepaint(); NoxUI:RefreshPage() end,refreshAlpha=function() local m=NoxUI._getPopupMenuElementMode and NoxUI._getPopupMenuElementMode() or "native"; return m=="native" and 1 or .3 end},
                {tooltip="Accent Color",hasAlpha=false,getValue=function() local c=NoxUI.NOX_GREEN; return c.r,c.g,c.b end,setValue=function() end,onClick=function() NoxUIDB.popupMenuButtonTextColorMode="accent"; PopupPreviewRepaint(); NoxUI:RefreshPage() end,refreshAlpha=function() local m=NoxUI._getPopupMenuElementMode and NoxUI._getPopupMenuElementMode() or "native"; return m=="accent" and 1 or .3 end},
                {tooltip="Custom Color",hasAlpha=false,getValue=function() local c=NoxUIDB.popupMenuButtonTextColor or {r=1,g=1,b=1}; return c.r,c.g,c.b end,setValue=function(r,g,b) NoxUIDB.popupMenuButtonTextColorMode="custom"; NoxUIDB.popupMenuButtonTextColor={r=r,g=g,b=b}; PopupPreviewRepaint() end,onClick=function(self) local m=NoxUI._getPopupMenuElementMode and NoxUI._getPopupMenuElementMode() or "native"; if m~="custom" then NoxUIDB.popupMenuButtonTextColorMode="custom"; PopupPreviewRepaint(); NoxUI:RefreshPage(); return end self._eabOrigClick(self) end,refreshAlpha=function() local m=NoxUI._getPopupMenuElementMode and NoxUI._getPopupMenuElementMode() or "native"; return m=="custom" and 1 or .3 end},
                {tooltip="Class Color",hasAlpha=false,getValue=function() local _,k=UnitClass("player"); local c=RAID_CLASS_COLORS[k]; return c.r,c.g,c.b end,setValue=function() end,onClick=function() NoxUIDB.popupMenuButtonTextColorMode="class"; PopupPreviewRepaint(); NoxUI:RefreshPage() end,refreshAlpha=function() local m=NoxUI._getPopupMenuElementMode and NoxUI._getPopupMenuElementMode() or "native"; return m=="class" and 1 or .3 end},
            }}); y=y-h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Font Size Scale",
              tooltip="Scales the font size of reskinned Blizzard tooltips, menus, and popups.",
              min=0.7, max=1.5, step=0.05, format="%.0f%%",
              displayMul=100,
              getValue=function()
                  return NoxUIDB and NoxUIDB.tooltipFontScale or 1.0
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipFontScale = v
                  TooltipPreviewRepaint()
              end },
            { type="toggle", text="Enable Blizzard Pause Menu",
              tooltip="Reskins the Escape / Game Menu.",
              getValue=function()
                  -- Independent, default on (not tied to any master reskin toggle).
                  return not NoxUIDB or NoxUIDB.reskinGameMenu ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinGameMenu = v
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Changing the pause menu reskin requires a UI reload.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        local hdr
        hdr, h = W:SectionHeader(parent, "BLIZZARD TOOLTIP", y);  y = y - h

        -- "Reskin Tooltip" (customTooltips) is the master for this section: its
        -- reskin-driven sub-settings gray out (and stop applying) when it is off.
        -- Per-line tooltip content settings (titles, item level, M+ score, detailed
        -- tooltips) live in the Tooltip Extras checklist below it. Settings
        -- independent of the skin (Detailed Tooltips, Show Health Strip, Spell ID
        -- on Tooltip, Show Max Stack) stay editable with the reskin off.
        local function ttReskinOff()
            return NoxUIDB and NoxUIDB.customTooltips == false
        end

        -- The Move in Unlock Mode button on the tooltip's first section: its
        -- mover exists only while the fixed anchor is live (reskin on, Anchor
        -- to Cursor off), so the button greys out as the Growth Direction row does.
        NoxUI.BuildSectionUnlockJump(hdr, {
            key = "EUI_TooltipAnchor",
            disabled = function()
                return ttReskinOff() or (NoxUIDB and NoxUIDB.tooltipAnchorCursor and true or false)
            end,
            disabledTooltip = function()
                if ttReskinOff() then return "Reskin Tooltip" end
                return "This option does not apply while Anchor to Cursor is enabled"
            end })

        -- Show Health Strip works without the reskin as well; its cog restyles
        -- the reskinned bar, so the cog locks with the reskin off.
        local function stripHidden()
            return not (NoxUIDB and NoxUIDB.tooltipHideHealthStrip == false)
        end

        -- Reskin Tooltip | Show Tooltips
        local ttShowRow
        ttShowRow, h = W:DualRow(parent, y,
            { type="toggle", text="Reskin Tooltip",
              getValue=function()
                  return not NoxUIDB or NoxUIDB.customTooltips ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.customTooltips = v
                  if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end
                  NoxUI:RefreshPage()  -- gray/ungray the rest of the section now
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Reskin setting requires a UI reload to fully apply.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end },
            { type="dropdown", text="Show Tooltips",
              disabled=ttReskinOff, disabledTooltip="Reskin Tooltip",
              values={ always="Always", outOfCombat="Out of Combat", outOfBossCombat="Out of Boss Combat", never="Never" },
              order={ "always", "outOfCombat", "outOfBossCombat", "never" },
              getValue=function() return (NoxUIDB and NoxUIDB.tooltipShowMode) or "always" end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipShowMode = v
                  NoxUI:RefreshPage()  -- update the Use Modifier cog disabled state
              end }
        );  y = y - h

        -- Rounded Corners cog on Reskin Tooltip (left region): the game tooltip
        -- with a solid border only (tooltipRoundedCorners, on unless false); a
        -- textured style keeps its art, so the cog locks with one.
        do
            NoxUI.BuildInlineCog(ttShowRow._leftRegion, {
                gap = 9,
                disabled = function()
                    return ttReskinOff() or (NoxUIDB.tooltipBorderTexture or "solid") ~= "solid"
                end,
                disabledTooltip = function()
                    return ttReskinOff() and "Reskin Tooltip" or "This option only applies to the Solid border style"
                end,
                title = "Reskin Tooltip",
                rows = {
                    { type="toggle", label="Rounded Corners",
                      get=function() return NoxUIDB.tooltipRoundedCorners ~= false end,
                      set=function(v)
                          -- Stored only when off (on is the unset default).
                          if v then
                              NoxUIDB.tooltipRoundedCorners = nil
                          else
                              NoxUIDB.tooltipRoundedCorners = false
                          end
                          TooltipPreviewRepaint()
                      end },
                },
            })
        end

        -- "Use Modifier" cog on Show Tooltips (right region): while the chosen
        -- modifier is held, suppression is lifted so a hidden tooltip can be
        -- read on hover (e.g. peeking a spell in combat). Disabled (blocked +
        -- dimmed) when the reskin is off or the mode is "Always" (nothing hides).
        do
            local rightRgn = ttShowRow._rightRegion
            local function showModOff()
                if ttReskinOff() then return true end
                return ((NoxUIDB and NoxUIDB.tooltipShowMode) or "always") == "always"
            end
            NoxUI.BuildInlineCog(rightRgn, {
                gap = 9,
                disabled = showModOff,
                disabledTooltip = function()
                    return ttReskinOff() and "Reskin Tooltip" or "This option requires Show Tooltips to be set to hide tooltips"
                end,
                title = "Show Tooltips",
                rows = {
                    { type="dropdown", label="Peek Modifier",
                      values={ none="None", shift="Shift", control="Control", alt="Alt" },
                      order={ "none", "shift", "control", "alt" },
                      get=function() return (NoxUIDB and NoxUIDB.tooltipShowModifier) or "none" end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipShowModifier = v
                      end },
                },
            })
        end

        -- Anchor to Cursor | Growth Direction
        local ttAnchorRow
        ttAnchorRow, h = W:DualRow(parent, y,
            { type="toggle", text="Anchor to Cursor",
              disabled=ttReskinOff, disabledTooltip="Reskin Tooltip",
              getValue=function()
                  return NoxUIDB and NoxUIDB.tooltipAnchorCursor or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipAnchorCursor = v
                  if NoxUI._applyTooltipCursorAnchor then NoxUI._applyTooltipCursorAnchor() end
                  -- Re-park the fixed anchor (and seed it if this profile never
                  -- has) so turning the cursor mode off resumes cleanly.
                  if NoxUI._applyTooltipFixedAnchor then NoxUI._applyTooltipFixedAnchor() end
                  NoxUI:RefreshPage()  -- update the position cog + Growth Direction disabled states
              end },
            -- Default screen-anchored tooltip only (see ApplyGrowthDirection in
            -- nui_blizzard_apparence_infobulle_ancrage.lua): Blizzard picks the anchored corner
            -- dynamically from the tooltip's screen position; "Expand Up"/"Expand Down"
            -- force the vertical component of that corner. The cursor anchor re-points
            -- the tooltip itself, so this grays out while Anchor to Cursor is on.
            { type="dropdown", text="Growth Direction",
              disabled=function()
                  return ttReskinOff() or (NoxUIDB and NoxUIDB.tooltipAnchorCursor and true or false)
              end,
              disabledTooltip=function()
                  if ttReskinOff() then return "Reskin Tooltip" end
                  return "This option does not apply while Anchor to Cursor is enabled"
              end,
              values={ default="Default", up="Expand Up", down="Expand Down" },
              order={ "default", "up", "down" },
              getValue=function()
                  return (NoxUIDB and NoxUIDB.tooltipGrowthDirection) or "default"
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipGrowthDirection = v
              end }
        );  y = y - h

        -- Position control on Anchor to Cursor (left region): position + X/Y offset
        do
            local leftRgn = ttAnchorRow._leftRegion
            local function ttCursorOff()
                return not (NoxUIDB and NoxUIDB.tooltipAnchorCursor)
            end
            NoxUI.BuildInlineCog(leftRgn, {
                gap = 9,
                disabled = ttCursorOff,
                disabledTooltip = "Anchor to Cursor",
                title = "Cursor Tooltip Position",
                rows = {
                    { type="dropdown", label="Position",
                      values={ bottomright="Bottom Right", bottomleft="Bottom Left",
                               topright="Top Right", topleft="Top Left",
                               right="Right", left="Left", top="Top", bottom="Bottom",
                               center="Center" },
                      order={ "bottomright", "bottomleft", "topright", "topleft",
                              "right", "left", "top", "bottom", "center" },
                      get=function() return NoxUIDB and NoxUIDB.tooltipCursorPosition or "top" end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipCursorPosition = v
                      end },
                    { type="slider", label="Offset X", min=-100, max=100, step=1,
                      get=function() return (NoxUIDB and NoxUIDB.tooltipCursorOffsetX) or 0 end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipCursorOffsetX = v
                      end },
                    { type="slider", label="Offset Y", min=-100, max=100, step=1,
                      get=function() return (NoxUIDB and NoxUIDB.tooltipCursorOffsetY) or 0 end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipCursorOffsetY = v
                      end },
                },
            })
        end

        -- Tooltip Extras | Spell ID on Tooltip
        -- Tooltip Extras (left): the per-line tooltip content as one checklist,
        -- each entry on the key it has always used. It stays active with the
        -- reskin off because Detailed Tooltips (the UberTooltips CVar) works with
        -- the default Blizzard tooltip too; the reskin-driven entries lock instead.
        -- The Bags module's item counts (Bags is not loaded: nil).
        local function BagOffline()
            local bags = NoxUI._ModuleNS["NoxUISacs"]
            return bags and bags.Offline
        end
        local lockTip = NoxUI.DisabledTooltip("Reskin Tooltip")
        local ttExtraItems = {
            { key="tooltipPlayerTitles", label="Player Titles", lockedFn=ttReskinOff, lockedTooltip=lockTip },
            { key="tooltipItemLevel", label="Item Level", lockedFn=ttReskinOff, lockedTooltip=lockTip },
            { key="tooltipMythicScore", label="M+ Score", lockedFn=ttReskinOff, lockedTooltip=lockTip },
            { key="tooltipShowMount", label="Mount", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Adds the mount a player is riding to their tooltip, with a green check if you own it or a red X if you don't." },
            { key="tooltipShowGuildRank", label="Guild Rank", lockedFn=ttReskinOff, lockedTooltip=lockTip },
            { key="tooltipShowTarget", label="Unit Target", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Adds a Targeting line showing who the hovered player or NPC is targeting, in green when it's you." },
            { key="tooltipLevelColor", label="Level Difficulty Color", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Colors the level number from gray (trivial) to red (much higher than you)." },
            { key="tooltipClassLineColor", label="Class Colored Spec", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Colors a player's spec and class line in their class color." },
            { key="tooltipFactionColor", label="Faction Color", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Colors the Alliance and Horde line in blue and red." },
            { key="tooltipGuildmateColor", label="Highlight Guildmates", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Colors the guild name (and rank, if shown) of members of your own guild in your guild chat color." },
            { key="tooltipCompactLevel", label="Compact Level Line", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Shortens the level line to the level and race, or level, rank and type for NPCs (\"90 Tauren\", \"90 Elite Humanoid\")." },
            { key="tooltipAFKTag", label="Away Tag", lockedFn=ttReskinOff, lockedTooltip=lockTip,
              tooltip="Adds <Away> or <Busy> after the name of players who are away or busy." },
            -- Item Counts: how many of the item each character holds, read from
            -- the inventories the Bags module saves. The switch is that module's
            -- account-wide one (NoxUIDB.bagTooltipCounts, set through its
            -- own setter, which arms the saving and the tooltip lines), so it is
            -- locked while Bags is not loaded; it works with the reskin off.
            { key="bagTooltipCounts", label="Item Counts", lockedFn=function() return BagOffline() == nil end,
              lockedTooltip=NoxUI.DisabledTooltip("Bags"),
              tooltip=NoxUI.IS_FOREVER
                  and "Item tooltips list how many of that item each of your characters has in their bags and bank. Applies to all characters."
                  or "Item tooltips list how many of that item each of your characters has in their bags and bank, plus the warband bank. Applies to all characters." },
            { key="uber", label="Detailed Tooltips" },
        }
        -- Global search sees row labels and tooltips only, so this row's entry,
        -- registered before the row (the index keeps the first one), carries the
        -- checklist's names as search text, with the name Item Counts had on the
        -- Bags page; it is never shown.
        if NoxUI._RegisterSearchEntry then
            local words = {}
            local function Word(s)
                words[#words + 1] = s
                local loc = NoxUI.L(s)
                if loc ~= s then words[#words + 1] = loc end
            end
            for i = 1, #ttExtraItems do Word(ttExtraItems[i].label) end
            Word("Tooltip Item Counts")
            local label = "Tooltip Extras"
            local labelLoc = NoxUI.L(label)
            NoxUI._RegisterSearchEntry(label, labelLoc ~= label and labelLoc or nil,
                table.concat(words, " "), NoxUI._buildingModule, NoxUI._buildingPage,
                parent._currentSection and parent._currentSection._sectionName)
        end
        local ttExtrasRow
        ttExtrasRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Tooltip Extras",
              values={ __placeholder = "..." }, order={ "__placeholder" },
              getValue=function() return "__placeholder" end, setValue=function() end },
            -- Front-end duplicate of the toggle in Global Settings > Developer;
            -- same NoxUIDB.showSpellID key read by the tooltip logic in
            -- NoxUI.lua (no separate backend). Independent of the reskin.
            { type="toggle", text="Spell ID on Tooltip",
              getValue=function()
                  return NoxUI.SpellIDOn()
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showSpellID = v
                  if NoxUI.SyncAuraSpellIDCVar then NoxUI.SyncAuraSpellIDCVar() end
                  NoxUI:RefreshPage()  -- update the Use Modifier cog disabled state
              end }
        );  y = y - h

        if not NoxUI._prebuilding then
            local PP = NoxUI.PanelPP
            local lrgn = ttExtrasRow._leftRegion
            if lrgn._control then lrgn._control:Hide() end
            -- Unset value of each reskin-driven key ("uber" is the CVar entry).
            local EXTRA_DEFAULTS = {
                tooltipPlayerTitles = false, tooltipItemLevel = true, tooltipMythicScore = true,
                tooltipShowMount = false, tooltipShowGuildRank = false, tooltipShowTarget = false,
                tooltipLevelColor = false, tooltipClassLineColor = false, tooltipFactionColor = false,
                tooltipGuildmateColor = false, tooltipCompactLevel = false, tooltipAFKTag = false,
            }
            local extrasDD, extrasRefresh = NoxUI.BuildVisOptsCBDropdown(
                lrgn, 170, lrgn:GetFrameLevel() + 2, ttExtraItems,
                function(k)
                    if k == "uber" then return GetCVar("UberTooltips") == "1" end
                    if k == "bagTooltipCounts" then
                        local offline = BagOffline()
                        return offline and offline.CountsEnabled() or false
                    end
                    local v = NoxUIDB and NoxUIDB[k]
                    if v == nil then return EXTRA_DEFAULTS[k] end
                    return v and true or false
                end,
                function(k, v)
                    if not NoxUIDB then NoxUIDB = {} end
                    if k == "uber" then
                        -- Only enforced on login after the user has toggled it once.
                        NoxUIDB.uberTooltipsManual = true
                        NoxUIDB.uberTooltips = v
                        NoxUI.SetCVar("UberTooltips", v and "1" or "0", "NoxUIApparenceBlizzard")
                    elseif k == "bagTooltipCounts" then
                        local offline = BagOffline()
                        if offline then offline.Set(k, v) end
                    else
                        NoxUIDB[k] = v
                        TooltipPreviewRepaint()
                    end
                end)
            PP.Point(extrasDD, "RIGHT", lrgn, "RIGHT", -20, 0)
            lrgn._control = extrasDD
            lrgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(extrasRefresh)
        end

        -- "Use Modifier" cog on Spell ID on Tooltip (right region): the spell/item
        -- ID lines only show while the chosen modifier is held. Disabled (blocked +
        -- dimmed) when Spell ID on Tooltip is off, mirroring the cursor-position cog.
        do
            local rightRgn = ttExtrasRow._rightRegion
            local function sidOff()
                return not NoxUI.SpellIDOn()
            end
            NoxUI.BuildInlineCog(rightRgn, {
                gap = 9,
                disabled = sidOff,
                disabledTooltip = "Spell ID on Tooltip",
                title = "Spell ID",
                rows = {
                    { type="dropdown", label="Use Modifier",
                      values={ none="None", shift="Shift", control="Control", alt="Alt" },
                      order={ "none", "shift", "control", "alt" },
                      get=function() return (NoxUIDB and NoxUIDB.spellIDModifier) or "none" end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.spellIDModifier = v
                          -- Modifier choice gates the engine-side combat
                          -- aura-ID CVar (12.1; no-op on retail).
                          if NoxUI.SyncAuraSpellIDCVar then NoxUI.SyncAuraSpellIDCVar() end
                      end },
                    { type="toggle", label="Show Icon ID",
                      get=function() return not NoxUIDB or NoxUIDB.showIconID ~= false end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.showIconID = v
                      end },
                    { type="toggle", label="Show Item ID",
                      get=function() return not NoxUIDB or NoxUIDB.showItemID ~= false end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.showItemID = v
                      end },
                },
            })
        end

        -- Show Max Stack for Items | Show Player Buffs
        local ttStackRow
        ttStackRow, h = W:DualRow(parent, y,
            -- Independent of the reskin, so it is NOT gated by "Reskin
            -- Tooltip" -- like Spell ID on Tooltip.
            { type="toggle", text="Show Max Stack for Items",
              tooltip="Appends an item's max stack count on tooltip.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.showItemMaxStacks or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showItemMaxStacks = v
                  NoxUI:RefreshPage()  -- update the Use Modifier cog disabled state
              end },
            { type="toggle", text="Show Player Buffs",
              disabled=ttReskinOff, disabledTooltip="Reskin Tooltip",
              getValue=function()
                  return NoxUIDB and NoxUIDB.tooltipShowBuffs or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipShowBuffs = v
                  if NoxUI._applyTooltipBuffs then NoxUI._applyTooltipBuffs() end
                  NoxUI:RefreshPage()  -- update the position cog disabled state
              end }
        );  y = y - h

        -- "Use Modifier" cog on Show Max Stack for Items (left region): the Max
        -- Stack line only shows while the chosen modifier is held. Disabled
        -- (blocked + dimmed) when the toggle is off, mirroring the Spell ID cog.
        do
            local leftRgn = ttStackRow._leftRegion
            local function iStacksOff()
                return not (NoxUIDB and NoxUIDB.showItemMaxStacks)
            end
            NoxUI.BuildInlineCog(leftRgn, {
                gap = 9,
                disabled = iStacksOff,
                disabledTooltip = "Show Max Stack for Items",
                title = "Item Stacks",
                rows = {
                    { type="dropdown", label="Use Modifier",
                      values={ none="None", shift="Shift", control="Control", alt="Alt" },
                      order={ "none", "shift", "control", "alt" },
                      get=function() return (NoxUIDB and NoxUIDB.itemStackModifier) or "none" end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.itemStackModifier = v
                      end },
                },
            })
        end

        -- Tooltip Buffs cog on Show Player Buffs (right region)
        do
            local function ttBuffsOff()
                return ttReskinOff() or not (NoxUIDB and NoxUIDB.tooltipShowBuffs)
            end
            local function setBuffs(key, v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB[key] = v
                if NoxUI._applyTooltipBuffs then NoxUI._applyTooltipBuffs() end
            end
            NoxUI.BuildInlineCog(ttStackRow._rightRegion, {
                gap = 9,
                disabled = ttBuffsOff,
                disabledTooltip = function()
                    return ttReskinOff() and "Reskin Tooltip" or "Show Player Buffs"
                end,
                title = "Tooltip Buffs",
                rows = {
                    { type="dropdown", label="Position",
                      values={ bottom="Bottom", top="Top", left="Left", right="Right" },
                      order={ "bottom", "top", "left", "right" },
                      get=function() return NoxUIDB and NoxUIDB.tooltipBuffPosition or "bottom" end,
                      set=function(v) setBuffs("tooltipBuffPosition", v) end },
                    { type="slider", label="Icon Size", min=12, max=40, step=1,
                      get=function() return NoxUIDB and NoxUIDB.tooltipBuffSize or 20 end,
                      set=function(v) setBuffs("tooltipBuffSize", v) end },
                    { type="slider", label="Icons Per Row", min=1, max=16, step=1,
                      get=function() return NoxUIDB and NoxUIDB.tooltipBuffsPerRow or 8 end,
                      set=function(v) setBuffs("tooltipBuffsPerRow", v) end },
                    { type="slider", label="Offset X", min=-100, max=100, step=1,
                      get=function() return NoxUIDB and NoxUIDB.tooltipBuffOffsetX or 0 end,
                      set=function(v) setBuffs("tooltipBuffOffsetX", v) end },
                    { type="slider", label="Offset Y", min=-100, max=100, step=1,
                      get=function() return NoxUIDB and NoxUIDB.tooltipBuffOffsetY or 0 end,
                      set=function(v) setBuffs("tooltipBuffOffsetY", v) end },
                },
            })
        end

        -- Show Health Strip | Background
        -- Background, the unified tooltip background: controls BOTH the Blizzard
        -- tooltip reskin and the NoxUI custom tooltips (read live via
        -- NoxUI.GetTooltipBg). Defaults to the RESKIN palette (#111111 @ 92%);
        -- the next tooltip shown picks up changes, so no reload is needed. One
        -- setting, like Global Settings > Colors' Dark Mode Background: the opacity
        -- slider with its color as an inline swatch.
        local ttStripRow
        ttStripRow, h = W:DualRow(parent, y,
            { type="toggle", text="Show Health Strip",
              tooltip="Shows the health bar on the bottom of unit tooltips.",
              getValue=function() return not stripHidden() end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipHideHealthStrip = not v
                  if NoxUI._applyTooltipHealthStrip then NoxUI._applyTooltipHealthStrip() end
                  NoxUI:RefreshPage()  -- update the strip cog disabled state
              end },
            { type="slider", text="Background", min=0, max=100, step=1,
              tooltip="Color and opacity of the tooltip background.",
              tooltipOnControl="Background Opacity", trackWidth=120,
              disabled=ttReskinOff, disabledTooltip="Reskin Tooltip",
              getValue=function()
                  local a = (NoxUIDB and NoxUIDB.tooltipBgOpacity) or NoxUI.RESKIN.TT_ALPHA
                  return math.floor(a * 100 + 0.5)
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.tooltipBgOpacity = v / 100
                  if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end
              end }
        );  y = y - h

        do
            local leftRgn = ttStripRow._leftRegion
            -- Health strip texture dropdown: the shared bar catalogue behind a
            -- "Blizzard" entry (the unset default). The triple lives on ns so the
            -- SharedMedia appender, which registers by table identity, gets the same
            -- tables on every build.
            if not ns.ttStripTex then
                local tex, names, order = NoxUI.BuildBarTextureTables()
                ns.ttStripTex = { tex = tex, names = names, order = order }
            end
            local st = ns.ttStripTex
            NoxUI.AppendSharedMediaTextures(st.names, st.order, nil, st.tex)
            local stripTexValues, stripTexOrder = { blizzard = "Blizzard" }, { "blizzard" }
            for _, key in ipairs(st.order) do
                if key ~= "---" then
                    stripTexValues[key] = st.names[key] or key
                    stripTexOrder[#stripTexOrder + 1] = key
                end
            end
            stripTexValues._menuOpts = {
                itemHeight = 28,
                background = function(key)
                    if key == "blizzard" then return "Interface\\TargetingFrame\\UI-StatusBar" end
                    return NoxUI.ResolveTexturePath(st.tex, key, nil)
                end,
            }
            local function applyStripStyle()
                if NoxUI._applyTooltipHealthStripStyle then NoxUI._applyTooltipHealthStripStyle() end
            end
            NoxUI.BuildInlineCog(leftRgn, {
                gap = 9,
                disabled = function() return ttReskinOff() or stripHidden() end,
                disabledTooltip = function()
                    return ttReskinOff() and "Reskin Tooltip" or "Show Health Strip"
                end,
                title = "Health Strip",
                rows = {
                    { type="dropdown", label="Texture",
                      values=stripTexValues, order=stripTexOrder,
                      get=function()
                          return NoxUIDB and NoxUIDB.tooltipHealthStripTexture or "blizzard"
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipHealthStripTexture = (v ~= "blizzard") and v or nil
                          applyStripStyle()
                      end },
                    { type="slider", label="Height", min=1, max=8, step=1,
                      get=function()
                          return NoxUIDB and NoxUIDB.tooltipHealthStripHeight or 3
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.tooltipHealthStripHeight = (v ~= 3) and v or nil
                          applyStripStyle()
                      end },
                },
            })
        end
        if not NoxUI._prebuilding then
            NoxUI.BuildInlineSwatches(ttStripRow._rightRegion, {
                { tooltip = "Background Color",
                  getValue = function()
                      local c = NoxUIDB and NoxUIDB.tooltipBgColor
                      if c then return c.r, c.g, c.b, 1 end
                      local R = NoxUI.RESKIN
                      return R.BG_R, R.BG_G, R.BG_B, 1
                  end,
                  setValue = function(r, g, b)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.tooltipBgColor = { r = r, g = g, b = b }
                      if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end
                  end },
            }, { size = 20, disabled = ttReskinOff, disabledTooltip = "Reskin Tooltip" })
        end

        -- Border Style | Border Size
        do
            local texValues,texOrder=NoxUI.GetBorderTextureDropdown()
            local tooltipBorder
            tooltipBorder,h=W:DualRow(parent,y,
                {type="dropdown",text="Border Style",disabled=ttReskinOff,values=texValues,order=texOrder,getValue=function() return NoxUIDB.tooltipBorderTexture or "solid" end,setValue=function(v) local c,b=NoxUI.GetBorderStyleSelectDefaults(v); NoxUIDB.tooltipBorderTexture=v; NoxUIDB.tooltipBorderOffsetX=nil; NoxUIDB.tooltipBorderOffsetY=nil; NoxUIDB.tooltipBorderBehind=b; NoxUIDB.tooltipBorderColor=c; if NoxUIDB.tooltipBorderThicknessPx then NoxUIDB.tooltipBorderThicknessPx=false end; if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end; NoxUI:RefreshPage(true) end},
                BorderSizeSlider("tooltip","Border Size",ttReskinOff,function() if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end end)); y=y-h
            -- The engine aura tooltip follows the border only when synced (the sync repaints the preview too)
            local function TooltipBorderApply()
                if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() else TooltipPreviewRepaint() end
            end
            AttachBorderControls(tooltipBorder,"tooltip",ttReskinOff,true,{ apply = TooltipBorderApply })
            BorderOffsetRow("tooltip",ttReskinOff,TooltipBorderApply)
        end

        -----------------------------------------------------------------------
        --  Blizzard Bars, Popups & Buttons: on-screen elements that are not
        --  windows, so they get plain toggles here rather than cards on the
        --  Window Skins page.
        --
        --  EXACTLY TWO configs per DualRow below. W:DualRow takes a left and
        --  a right and SILENTLY DROPS a third -- a row shipped with three once
        --  rendered only two toggles and nothing errored.
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "BLIZZARD BARS, POPUPS & BUTTONS", y);  y = y - h

        -- The slot configs, laid out per client below: WoW Forever has no
        -- extra action button, so its toggle is not built there and the
        -- queue pair moves up a slot.
        local widgetCfg =
            { type="toggle", text="Reskin Widget Bars",
              tooltip="Restyles Blizzard's on-screen progress bars (event objectives, nameplate counters)",
              getValue=function()
                  return not NoxUIDB or NoxUIDB.reskinWidgetBars ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinWidgetBars = v and true or false
                  -- Reload-bound, like the window packs: turned OFF, the skin
                  -- registers no events at all rather than running and
                  -- returning early, so the decision is taken once at login.
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Widget bar reskin requires a UI reload to apply.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end }
        local extraCfg = not NoxUI.IS_FOREVER and
            { type="toggle", text="Reskin Extra Action Buttons",
              getValue=function()
                  -- DEFAULT OFF: opt-in, so nil reads as unchecked.
                  return NoxUIDB and NoxUIDB.reskinExtraActionButton == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinExtraActionButton = v and true or false
              end } or nil
        local queueCfg =
            { type="toggle", text="Reskin Queue Popup",
              tooltip="Reskins the dungeon and battleground queue accept popups and adds an accept countdown timer bar to the dungeon one.",
              getValue=function()
                  -- Independent, default on (not tied to any master reskin toggle).
                  return not NoxUIDB or NoxUIDB.reskinQueuePopup ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinQueuePopup = v
                  if not v and NoxUI.ShowConfirmPopup then
                      NoxUI:ShowConfirmPopup({
                          title       = "Reload Required",
                          message     = "Disabling queue popup reskin requires a UI reload to restore Blizzard's default style.",
                          confirmText = "Reload Now",
                          cancelText  = "Later",
                          reload      = true,
                      })
                  end
              end }
        local timerCfg =
            { type="toggle", text="Show Queue Timer",
              getValue=function()
                  return not NoxUIDB or NoxUIDB.showQueueTimer ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showQueueTimer = v
                  NoxUI:RefreshPage()  -- update the style cog + swatch disabled states
              end }

        local timerBarsCfg =
            { type="toggle", text="Reskin Timer Bars",
              tooltip="Restyles Blizzard's breath, fatigue and feign death bars",
              getValue=function()
                  -- DEFAULT OFF: opt-in, so nil reads as unchecked.
                  return NoxUIDB and NoxUIDB.reskinTimerBars == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.reskinTimerBars = v and true or false
                  if v and NoxUI._TimerBarsInstall then NoxUI._TimerBarsInstall() end
                  -- Shows or hides the TIMER BARS section below.
                  NoxUI:RefreshPage(true)
                  if not v then
                      NoxUI:ShowConfirmPopup({
                          title       = "Reload Required",
                          message     = "Disabling the timer bar reskin requires a UI reload to restore Blizzard's default style.",
                          confirmText = "Reload Now",
                          cancelText  = "Later",
                          reload      = true,
                      })
                  end
              end }

        -- The regions the inline controls below sit on, whichever slot their
        -- toggle took.
        local hudRow, queueRow, widgetRgn, queueRgn, timerRgn
        if extraCfg then
            hudRow, h = W:DualRow(parent, y, widgetCfg, extraCfg);  y = y - h
            queueRow, h = W:DualRow(parent, y, queueCfg, timerCfg);  y = y - h
            _, h = W:DualRow(parent, y, timerBarsCfg, NoxUI.BlankRowCfg());  y = y - h
            widgetRgn = hudRow and hudRow._leftRegion
            queueRgn = queueRow and queueRow._leftRegion
            timerRgn = queueRow and queueRow._rightRegion
        else
            hudRow, h = W:DualRow(parent, y, widgetCfg, queueCfg);  y = y - h
            queueRow, h = W:DualRow(parent, y, timerCfg, timerBarsCfg);  y = y - h
            widgetRgn = hudRow and hudRow._leftRegion
            queueRgn = hudRow and hudRow._rightRegion
            timerRgn = queueRow and queueRow._leftRegion
        end

        -- Minimum widget bar size (plate-hosted covers), a cog on "Reskin Widget
        -- Bars": the floor below which a shrunken nameplate's bar scales itself
        -- up. 0 = off (default, mirror Blizzard's rect exactly).
        if widgetRgn then
            local lrgn  = widgetRgn
            local function CogOff()
                -- Same default-on test the toggle itself uses: nil means on.
                return not (not NoxUIDB or NoxUIDB.reskinWidgetBars ~= false)
            end
            NoxUI.BuildInlineCog(lrgn, {
                anchorTo = lrgn._control,
                disabled = CogOff, disabledTooltip = "Reskin Widget Bars",
                tip = "Smallest on-screen size a reskinned bar is drawn at.\n\n" ..
                    "Widget bars on a nameplate inherit that nameplate's scale, so " ..
                    "they come out tiny on small units. Below this size the bar is " ..
                    "scaled up instead, text and all.\n\nSet to 0 to mirror " ..
                    "Blizzard's size exactly.",
                title = "Widget Bar Size",
                rows  = {
                    { type="slider", label="Minimum", min=0, max=24, step=1,
                      get=function()
                          local v = NoxUIDB and NoxUIDB.widgetBarMinSize
                          if type(v) == "number" then return v end
                          return 0
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.widgetBarMinSize = v
                          -- Live: the seam re-reads and books one refresh; nil
                          -- only while the reskin is off (cog greyed then).
                          if NoxUI._HUDWidgetSetMinSize then
                              NoxUI._HUDWidgetSetMinSize()
                          end
                      end },
                },
            })
        end

        -- Red "!" warning left of the Reskin Queue Popup toggle while a mover addon
        -- that conflicts with the reskin is loaded
        local _eqolLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EnhanceQoL")
        if _eqolLoaded and queueRgn and not NoxUI._prebuilding then
            local rgn = queueRgn
            local toggle = rgn._control
            if toggle then
                local fontPath = (NoxUI.GetFontPath()) or "Fonts\\FRIZQT__.TTF"
                local warnBtn = CreateFrame("Button", nil, rgn)
                warnBtn:SetSize(28, 28)
                warnBtn:SetPoint("RIGHT", toggle, "LEFT", -4, 0)
                warnBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
                local warnFS = warnBtn:CreateFontString(nil, "OVERLAY")
                warnFS:SetFont(fontPath, 28, "")
                warnFS:SetTextColor(1, 0.3, 0.3, 1)
                warnFS:SetText("!")
                warnFS:SetPoint("CENTER")
                warnBtn:SetScript("OnEnter", function(self)
                    NoxUI.ShowWidgetTooltip(self, "Enhance QoL's Mover may conflict with this reskin. The reskin is auto-disabled when its mover is active.")
                end)
                warnBtn:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            end
        end

        -- Style cog + countdown text color swatch (left of it) on the Show Queue Timer toggle.
        if timerRgn then
            local PP = NoxUI.PanelPP
            local QT = NoxUI.QUEUE_TIMER
            local function timerOff()
                return NoxUIDB and NoxUIDB.showQueueTimer == false
            end
            local function Get(key, default)
                return (NoxUIDB and NoxUIDB[key]) or default
            end
            local function Set(key, v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB[key] = v
                if NoxUI.RefreshQueueTimerStyle then NoxUI.RefreshQueueTimerStyle() end
            end

            NoxUI.BuildInlineCog(timerRgn, {
                disabled = timerOff,
                disabledTooltip = "Show Queue Timer",
                title = "Queue Timer Style",
                rows = {
                    { type="slider", label="Text Size", min=6, max=24, step=1,
                      get=function() return Get("queueTimerTextSize", QT.TEXT_SIZE) end,
                      set=function(v) Set("queueTimerTextSize", v) end },
                    { type="slider", label="Bar Height", min=4, max=24, step=1,
                      get=function() return Get("queueTimerBarHeight", QT.BAR_HEIGHT) end,
                      set=function(v) Set("queueTimerBarHeight", v) end },
                    { type="slider", label="Text Offset Y", min=-20, max=20, step=1,
                      tooltip="Moves the countdown number up or down relative to the bar.",
                      get=function() return Get("queueTimerTextOffsetY", QT.TEXT_OFFSET_Y) end,
                      set=function(v) Set("queueTimerTextOffsetY", v) end },
                },
            })

            if not NoxUI._prebuilding then
                local qtSwatch, qtSwatchRefresh = NoxUI.BuildColorSwatch(timerRgn,
                    timerRgn:GetFrameLevel() + 5,
                    function()
                        local c = NoxUIDB and NoxUIDB.queueTimerTextColor
                        return (c and c.r) or QT.TEXT_R, (c and c.g) or QT.TEXT_G, (c and c.b) or QT.TEXT_B
                    end,
                    function(r, g, b) Set("queueTimerTextColor", { r = r, g = g, b = b }) end,
                    false, 20)
                PP.Point(qtSwatch, "RIGHT", timerRgn._lastInline or timerRgn._control, "LEFT", -8, 0)
                timerRgn._lastInline = qtSwatch
                qtSwatch:HookScript("OnEnter", function(self)
                    NoxUI.ShowWidgetTooltip(self, "Countdown Text Color")
                end)
                qtSwatch:HookScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

                -- Called at build time too: the refresh list only runs on page show.
                local function UpdQueueTimerState()
                    local off = timerOff()
                    qtSwatch:SetAlpha(off and 0.15 or 1); qtSwatch:EnableMouse(not off)
                    qtSwatchRefresh()
                end
                NoxUI.RegisterWidgetRefresh(UpdQueueTimerState)
                UpdQueueTimerState()
            end
        end

        -----------------------------------------------------------------------
        --  Timer Bars: Blizzard's breath, fatigue and feign death bars
        --  (nui_blizzard_apparence_interface.lua). Shown only while "Reskin Timer Bars"
        --  (above) is on. Look settings apply live through
        --  NoxUI._TimerBarsRefresh; only turning it off needs a reload.
        -----------------------------------------------------------------------
        local TB = NoxUI.TIMER_BARS
        if TB and NoxUIDB.reskinTimerBars == true then
            local prefix = "timerBars"
            local function Get(key, default)
                local v = NoxUIDB[key]
                if v == nil then return default end
                return v
            end
            local function apply()
                if NoxUI._TimerBarsRefresh then NoxUI._TimerBarsRefresh() end
            end
            local function Set(key, v)
                NoxUIDB[key] = v
                apply()
            end
            local function GetColor(key, default)
                local c = NoxUIDB[key] or default
                return c.r, c.g, c.b, 1
            end
            local function SetColor(key)
                return function(r, g, b) Set(key, { r = r, g = g, b = b }) end
            end
            -- The Accent fill as the bar draws it (Window Skins' bar fill)
            local function AccentFill()
                local r, g, b = TB.AccentFill()
                return r, g, b, 1
            end
            local function typeColorsOn() return Get("timerBarsTypeColors", false) == true end
            local function textOff() return Get("timerBarsShowText", true) == false end
            local function borderOff() return not NoxUIDB[prefix.."BorderTexture"] end

            _, h = W:SectionHeader(parent, "TIMER BARS", y);  y = y - h

            -- Bar Texture: the shared bar catalogue. The triple lives on ns so the SharedMedia
            -- appender, which registers by table identity, gets the same tables on every
            -- build; the dropdown's own lists are made per build, so a texture another addon
            -- registers later is listed.
            if not ns.timerBarTex then
                local tex, names, order = NoxUI.BuildBarTextureTables()
                ns.timerBarTex = { tex = tex, names = names, order = order }
            end
            local barTex = ns.timerBarTex
            NoxUI.AppendSharedMediaTextures(barTex.names, barTex.order, nil, barTex.tex)
            local timerBarTexValues, timerBarTexOrder = {}, {}
            for _, key in ipairs(barTex.order) do
                if key ~= "---" then timerBarTexValues[key] = barTex.names[key] or key end
                timerBarTexOrder[#timerBarTexOrder + 1] = key
            end
            timerBarTexValues._menuOpts = {
                itemHeight = 28,
                background = function(key) return NoxUI.ResolveTexturePath(barTex.tex, key, nil) end,
            }

            -- Fill Color (opacity + Custom | Class | Accent) | Background (opacity + color)
            local colorRow
            colorRow, h = W:DualRow(parent, y,
                { type="slider", text="Fill Color", min=0, max=100, step=1, trackWidth=120,
                  tooltip="Opacity of the bar fill.",
                  getValue=function() return Get("timerBarsFillOpacity", TB.FILL_OPACITY) end,
                  setValue=function(v) Set("timerBarsFillOpacity", v) end },
                { type="slider", text="Background", min=0, max=100, step=1, trackWidth=120,
                  tooltip="Opacity of the bar background.",
                  getValue=function() return Get("timerBarsBgOpacity", 100) end,
                  setValue=function(v) Set("timerBarsBgOpacity", v) end }
            ); y = y - h
            if not NoxUI._prebuilding then
                local function FillMode() return Get("timerBarsFillMode", "accent") end
                local function ModeSwatch(mode, tip, getValue, setValue)
                    return { tooltip = tip,
                      disabled = typeColorsOn, disabledTooltip = "Color by Timer Type", requireState = "disabled",
                      getValue = getValue, setValue = setValue or function() end,
                      onClick = function(self)
                          if FillMode() ~= mode or not setValue then
                              Set("timerBarsFillMode", mode); NoxUI:RefreshPage()
                              return
                          end
                          if self._eabOrigClick then self._eabOrigClick(self) end
                      end,
                      refreshAlpha = function() return FillMode() == mode and 1 or 0.3 end }
                end
                NoxUI.BuildInlineSwatches(colorRow._leftRegion, {
                    ModeSwatch("custom", "Custom Color",
                        function() if NoxUIDB.timerBarsFillColor then return GetColor("timerBarsFillColor") end return AccentFill() end,
                        function(r, g, b)
                            NoxUIDB.timerBarsFillMode = "custom"
                            Set("timerBarsFillColor", { r = r, g = g, b = b })
                        end),
                    ModeSwatch("class", "Class Color", function()
                        local _, classFile = UnitClass("player")
                        local cc = classFile and NoxUI.GetClassColor(classFile)
                        if cc then return cc.r, cc.g, cc.b, 1 end
                        return 1, 1, 1, 1
                    end),
                    ModeSwatch("accent", "Accent Color", AccentFill),
                })
                NoxUI.BuildInlineSwatches(colorRow._rightRegion, {
                    { tooltip = "Background Color",
                      getValue = function() return GetColor("timerBarsBgColor", TB.BG) end,
                      setValue = SetColor("timerBarsBgColor") },
                })
            end

            -- Color by Timer Type (Breath | Fatigue | Feign Death) | Bar Texture
            local typeRow
            typeRow, h = W:DualRow(parent, y,
                { type="toggle", text="Color by Timer Type",
                  tooltip="Gives each timer its own fill color in place of the fill color above.",
                  getValue=typeColorsOn,
                  setValue=function(v) Set("timerBarsTypeColors", v and true or false); NoxUI:RefreshPage() end },
                { type="dropdown", text="Bar Texture",
                  values=timerBarTexValues, order=timerBarTexOrder,
                  getValue=function() return Get("timerBarsTexture", "none") end,
                  setValue=function(v) Set("timerBarsTexture", v) end }
            ); y = y - h
            if not NoxUI._prebuilding then
                local function TypeSwatch(tk, tip)
                    return { tooltip = tip,
                      disabled = function() return not typeColorsOn() end, disabledTooltip = "Color by Timer Type",
                      getValue = function() return GetColor("timerBars"..tk.."Color", TB.TYPE[tk]) end,
                      setValue = SetColor("timerBars"..tk.."Color") }
                end
                NoxUI.BuildInlineSwatches(typeRow._leftRegion, {
                    TypeSwatch("Breath", "Breath"),
                    TypeSwatch("Fatigue", "Fatigue"),
                    TypeSwatch("Feign", "Feign Death"),
                })
            end

            -- Width | Height, capped at Blizzard's timer frame (its size belongs to Edit Mode).
            _, h = W:DualRow(parent, y,
                { type="slider", text="Width", min=TB.MIN_W, max=TB.MAX_W, step=1,
                  getValue=function() return Get("timerBarsWidth", TB.WIDTH) end,
                  setValue=function(v) Set("timerBarsWidth", v) end },
                { type="slider", text="Height", min=TB.MIN_H, max=TB.MAX_H, step=1,
                  getValue=function() return Get("timerBarsHeight", TB.HEIGHT) end,
                  setValue=function(v) Set("timerBarsHeight", v) end }
            ); y = y - h

            -- Border Style | Border Size, as on the Loot Window card: Default keeps the 1px black edge.
            local bValues, bOrder = DefaultableBorderValues()
            local borderRow
            borderRow, h = W:DualRow(parent, y,
                { type="dropdown", text="Border Style",
                  values=bValues, order=bOrder,
                  getValue=function() return NoxUIDB[prefix.."BorderTexture"] or "default" end,
                  setValue=function(v)
                      SetDefaultableBorderStyle(prefix, v)
                      apply()
                      NoxUI:RefreshPage(true)
                  end },
                BorderSizeSlider(prefix, "Border Size", borderOff, apply, "Border Style")
            ); y = y - h
            -- Corner Radius (NoxUI_RoundedCorners.lua): the cog beside Border Size, the
            -- color swatches left of it. Only a picked Solid, Glow or Shadow style rounds.
            do
                NoxUI.BuildInlineCog(borderRow._rightRegion, {
                    title = "Corner Radius", tip = "Corner Radius",
                    disabled = function()
                        return borderOff() or not NoxUI.RoundedStyleOK(NoxUIDB[prefix.."BorderTexture"])
                    end,
                    disabledTooltip = "This option requires the Solid, Glow or Shadow border style.",
                    rows = NoxUI.RoundedCornerRows({
                        { type = "slider", label = "Corner Radius", min = 0, max = NoxUI.ROUNDED_MAX_RADIUS, step = 1,
                          get = function() return Get("timerBarsCornerRadius", 0) end,
                          set = function(v) Set("timerBarsCornerRadius", v) end },
                    }, function() return NoxUIDB.timerBarsCornerMask end,
                       function(v) Set("timerBarsCornerMask", v) end),
                })
            end
            AttachBorderControls(borderRow, prefix, borderOff, false, { apply = apply })
            local ocfgL, ocfgR = BorderOffsetCfgs(prefix, borderOff, apply, "Border Style")
            if ocfgL then _, h = W:DualRow(parent, y, ocfgL, ocfgR); y = y - h end

            -- Show Name (cog + color) | blank
            local nameRow
            nameRow, h = W:DualRow(parent, y,
                { type="toggle", text="Show Name",
                  getValue=function() return Get("timerBarsShowText", true) ~= false end,
                  setValue=function(v) Set("timerBarsShowText", v and true or false); NoxUI:RefreshPage() end },
                NoxUI.BlankRowCfg()
            ); y = y - h
            do
                NoxUI.BuildInlineCog(nameRow._leftRegion, {
                    title = "Name Text",
                    disabled = textOff, disabledTooltip = "Show Name",
                    rows = {
                        { type="slider", label="Text Size", min=6, max=24, step=1,
                          get=function() return Get("timerBarsTextSize", TB.TEXT_SIZE) end,
                          set=function(v) Set("timerBarsTextSize", v) end },
                        { type="slider", label="Text Offset X", min=-100, max=100, step=1,
                          get=function() return Get("timerBarsTextX", 0) end,
                          set=function(v) Set("timerBarsTextX", v) end },
                        { type="slider", label="Text Offset Y", min=-20, max=20, step=1,
                          get=function() return Get("timerBarsTextY", 0) end,
                          set=function(v) Set("timerBarsTextY", v) end },
                    },
                })
            end
            if not NoxUI._prebuilding then
                NoxUI.BuildInlineSwatches(nameRow._leftRegion, {
                    { tooltip = "Text Color",
                      getValue = function() return GetColor("timerBarsTextColor", { r = 1, g = 1, b = 1 }) end,
                      setValue = SetColor("timerBarsTextColor") },
                }, { disabled = textOff, disabledTooltip = "Show Name" })
            end
        end
        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Character Sheet card content (Blizzard Window Skins page). The style
    --  choice lives on the card header dropdown; everything here is the
    --  window's sub-settings, built as direct children of the page wrapper so
    --  inline search and nav deep-links still see them.
    ---------------------------------------------------------------------------
    -- Section headers inside window-skin cards: title indented 5px to sit
    -- with the card chrome (the divider stays full width).
    local function WSCardSection(parent, text, y)
        local W = NoxUI.Widgets
        local hf, h = W:SectionHeader(parent, text, y)
        if hf and hf._label then
            NoxUI.PanelPP.Point(hf._label, "BOTTOMLEFT", hf, "BOTTOMLEFT", 5, 8)
        end
        return hf, h
    end

    local function BuildCharacterSheetContent(parent, y)
        local W = NoxUI.Widgets
        local _, h
        local PP = NoxUI.PanelPP

        local function themedOff()
            return NoxUIDB and NoxUIDB.themedCharacterSheet == false
        end
        -- The card's Blizz Default, as the sheet runs it this session (the
        -- choice is latched at load; a change reloads).
        local stock = ns.CharSheetStock()
        -- Blizz Default only: "Blizzard UI Color" (on unless turned off)
        -- paints every stat category in Blizzard's yellow, so the colour
        -- swatches stand down while it is on. On WoW Forever Blizz Default
        -- keeps Blizzard's own stats list, colours included, so they always
        -- stand down.
        local function blizzColorsOn()
            return stock
                and (NoxUI.IS_FOREVER or not (NoxUIDB and NoxUIDB.charSheetBlizzColors == false))
        end

        local function AttachDisabledOverlay(target)
            if NoxUI._prebuilding then return end
            local block = CreateFrame("Frame", nil, target)
            block:SetAllPoints(target)
            block:SetFrameLevel(target:GetFrameLevel() + 10)
            block:EnableMouse(true)
            local bg = NoxUI.SolidTex(block, "BACKGROUND", 0, 0, 0, 0)
            bg:SetAllPoints()
            block:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(block, NoxUI.DisabledTooltip("Character Sheet"))
            end)
            block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            local function refresh()
                if themedOff() then block:Show(); target:SetAlpha(0.3)
                else block:Hide(); target:SetAlpha(1) end
            end
            NoxUI.RegisterWidgetRefresh(refresh); refresh()
        end

        -- Blizz Default keeps Blizzard's own character sheet with our stats
        -- section, slot text and socket strip: the gem icons and Icon Zoom
        -- are the NoxUI sheet's own, so Gems leaves the Item Details
        -- list and Icon Zoom greys out there.
        local function csGate(cfg)
            if stock then
                cfg.disabled        = function() return true end
                cfg.disabledTooltip = "Character Sheet: Blizz Default"
                cfg.requireState    = "disabled"
                cfg.rawTooltip      = nil
                cfg._blizzGated     = true
            end
            return cfg
        end

        ---------------------------------------------------------------------------
        --  CORE OPTIONS
        ---------------------------------------------------------------------------
        _, h = WSCardSection(parent, "CORE OPTIONS", y);  y = y - h

        -- Blizzard's own slot icons under Blizz Default (the inspect sheet
        -- keeps its stored zoom).
        local iconZoomCfg = csGate({ type="slider", text="Icon Zoom", min=0, max=0.20, step=0.01,
              tooltip="Crops the border of the equipment-slot item icons on the character and inspect sheets. 0 shows the full icon. Only affects the themed character sheet.",
              getValue=function() return (NoxUIDB and NoxUIDB.charSheetIconZoom) or 0.07 end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.charSheetIconZoom = v
                  if NoxUI._refreshCharSheetIconZoom then NoxUI._refreshCharSheetIconZoom() end
              end })

        if not NoxUI.IS_FOREVER then
            -- Mythic+ Rating | Item Details: a checkbox dropdown, a view over
            -- the item level, upgrade track and gem keys (each on unless
            -- false). The gem icons are the NoxUI sheet's own, so Blizz
            -- Default leaves Gems out of the list. Tertiary Stats only adds to
            -- Stat Letters, so it locks while that is off.
            local function statLettersOff()
                return not (NoxUIDB and NoxUIDB.charSheetItemStats == true)
            end
            local ITEM_DETAILS = {
                { key="showItemLevel",    label="Item Level",    refresh="_refreshItemLevelVisibility" },
                { key="showUpgradeTrack", label="Upgrade Track", refresh="_refreshUpgradeTrackVisibility" },
                { key="charSheetItemStats", label="Stat Letters", refresh="_refreshCharSheetSlotLabels", optIn=true },
                { key="charSheetItemStatsTertiary", label="Tertiary Stats", refresh="_refreshCharSheetSlotLabels", optIn=true,
                  lockedFn=statLettersOff, excludeFromSummaryFn=statLettersOff,
                  lockedTooltip=NoxUI.DisabledTooltip("Stat Letters") },
            }
            if not stock then
                ITEM_DETAILS[#ITEM_DETAILS + 1] = { key="showGems", label="Gems", refresh="_refreshGemsVisibility" }
            end
            local coreRow1
            coreRow1, h = W:DualRow(parent, y,
                { type="toggle", text="Mythic+ Rating",
                  tooltip="Display your Mythic+ rating above the item level on the character sheet.",
                  getValue=function() return NoxUIDB and NoxUIDB.showMythicRating or false end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.showMythicRating = v
                      if NoxUI._updateMythicRatingDisplay then NoxUI._updateMythicRatingDisplay() end
                  end },
                { type="label", text="Item Details", tooltip="Choose what shows on each equipped item." }
            );  y = y - h
            if not NoxUI._prebuilding then
                local rgn = coreRow1._rightRegion
                -- Keys are on unless false; an optIn key is off unless true.
                local refreshOf, optIn = {}, {}
                for _, item in ipairs(ITEM_DETAILS) do
                    refreshOf[item.key] = item.refresh
                    optIn[item.key] = item.optIn
                end
                local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                    rgn, 210, rgn:GetFrameLevel() + 2, ITEM_DETAILS,
                    function(key)
                        if optIn[key] then return NoxUIDB and NoxUIDB[key] == true or false end
                        return not (NoxUIDB and NoxUIDB[key] == false)
                    end,
                    function(key, v)
                        if not NoxUIDB then NoxUIDB = {} end
                        NoxUIDB[key] = v
                        local refresh = NoxUI[refreshOf[key]]
                        if refresh then refresh() end
                    end)
                PP.Point(cbDD, "RIGHT", rgn, "RIGHT", -20, 0)
                rgn._control = cbDD
                rgn._lastInline = nil
                NoxUI.RegisterWidgetRefresh(cbDDRefresh)
            end
            AttachDisabledOverlay(coreRow1)

            -- Socket Panel | Icon Zoom (greyed under Blizz Default). Both
            -- looks show the socket strip: under Blizz Default it hangs below
            -- Blizzard's sheet in its tab art
            -- (NoxUIApparenceBlizzard_SocketPanel.lua).
            local socketRow
            socketRow, h = W:DualRow(parent, y,
                { type="toggle", text="Socket Panel",
                  tooltip="Show a panel of equipped-gear sockets on the character sheet; click a socket to gem it.",
                  getValue=function() return NoxUIDB and NoxUIDB.charSheetSocketPanel ~= false end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.charSheetSocketPanel = v
                      if NoxUI._refreshCharSheetSocketPanel then NoxUI._refreshCharSheetSocketPanel() end
                      NoxUI:RefreshPage()
                  end },
                iconZoomCfg);  y = y - h
            AttachDisabledOverlay(socketRow)

            -- Inline cog on Socket Panel: stat letters on the gem icons (off
            -- unless turned on).
            do
                NoxUI.BuildInlineCog(socketRow._leftRegion, {
                    disabled = function() return NoxUIDB and NoxUIDB.charSheetSocketPanel == false end,
                    disabledTooltip = "Socket Panel",
                    title = "Socket Panel Settings",
                    rows = {
                        { type="toggle", label="Stat Letters",
                          tooltip="Shows each socketed gem's secondary stats as letters on its icon, largest first (C Crit, H Haste, M Mastery, V Versatility).",
                          get=function() return NoxUIDB and NoxUIDB.charSheetSocketPanelStats == true or false end,
                          set=function(v)
                              if not NoxUIDB then NoxUIDB = {} end
                              NoxUIDB.charSheetSocketPanelStats = v
                              if NoxUI._refreshCharSheetSocketPanel then NoxUI._refreshCharSheetSocketPanel() end
                          end },
                    },
                })
            end
        else
            -- WoW Forever has no Mythic+, item level text, upgrade tracks or
            -- sockets: the track key shows each item's main and secondary stat
            -- (or its armor when it has none) and each weapon's damage per
            -- second there. Icon Zoom greys out under Blizz Default.
            local statsRow
            statsRow, h = W:DualRow(parent, y,
                { type="toggle", text="Show Item Stats",
                  tooltip="Show each item's own stats, armor and weapon DPS. To hide enchantment bonuses beside the slots, set Enchants to None.",
                  getValue=function() return NoxUIDB and NoxUIDB.showUpgradeTrack ~= false end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.showUpgradeTrack = v
                      if NoxUI._refreshUpgradeTrackVisibility then NoxUI._refreshUpgradeTrackVisibility() end
                  end },
                iconZoomCfg);  y = y - h
            AttachDisabledOverlay(statsRow)
        end

        -- Enchants (this sheet and the inspect sheet): a view over the
        -- sheet's shown key (on unless false) and its names key; None leaves
        -- the names key as it was. WoW Forever's enchants carry no icon, so
        -- the middle mode is the plain name there and Text the colored one.
        -- The Text Size cog shows only while the enchants show as text.
        local function EnchantValues()
            if NoxUI.IS_FOREVER then
                return { none="None", icons="Text", text="Colored Text" }
            end
            return { none="None", icons="Icons + Hover", text="Text" }
        end
        local function EnchantMode(showKey, namesKey)
            if NoxUIDB and NoxUIDB[showKey] == false then return "none" end
            if NoxUIDB and NoxUIDB[namesKey] then return "text" end
            return "icons"
        end
        local function SetEnchantMode(showKey, namesKey, v)
            if not NoxUIDB then NoxUIDB = {} end
            NoxUIDB[showKey] = v ~= "none"
            if v ~= "none" then NoxUIDB[namesKey] = v == "text" end
        end
        local function EnchantTextShown(showKey, namesKey)
            local mode = EnchantMode(showKey, namesKey)
            return mode == "text" or (NoxUI.IS_FOREVER and mode == "icons")
        end

        local enchGemRow
        enchGemRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Enchants",
              tooltip="How enchants show beside each item.",
              values=EnchantValues(), order={ "none", "icons", "text" },
              getValue=function() return EnchantMode("showEnchants", "charSheetEnchantNames") end,
              setValue=function(v)
                  SetEnchantMode("showEnchants", "charSheetEnchantNames", v)
                  if NoxUI._refreshEnchantsVisibility then NoxUI._refreshEnchantsVisibility() end
                  if NoxUI._refreshCharSheetSlotLabels then NoxUI._refreshCharSheetSlotLabels() end
                  -- Shows or hides the Text Size cog
                  NoxUI:RefreshPage()
              end },
            { type="toggle", text="Show PvP Item Level",
              tooltip="Display your PvP item level above the Mythic+ rating on the character sheet.",
              getValue=function() return NoxUIDB and NoxUIDB.showPvpItemLevel or false end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showPvpItemLevel = v
                  if NoxUI._updatePvpIlvlDisplay then NoxUI._updatePvpIlvlDisplay() end
              end }
        );  y = y - h
        AttachDisabledOverlay(enchGemRow)

        do
            local cogBtn = NoxUI.BuildInlineCog(enchGemRow._leftRegion, {
                title = "Enchant Text",
                rows = {
                    { type="slider", label="Text Size", min=6, max=20, step=1,
                      get=function() return (NoxUIDB and NoxUIDB.charSheetEnchantSize) or 9 end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.charSheetEnchantSize = v
                          if NoxUI._refreshCharSheetSlotLabels then NoxUI._refreshCharSheetSlotLabels() end
                      end },
                },
            })
            if not NoxUI._prebuilding then
                local function UpdateCogVis()
                    cogBtn:SetShown(EnchantTextShown("showEnchants", "charSheetEnchantNames"))
                end
                NoxUI.RegisterWidgetRefresh(UpdateCogVis)
                UpdateCogVis()
            end
        end

        -- Durability | Season Panel. The panel greys out with the sheet off;
        -- durability stays live either way. The panel is retail only.
        local seasonCfg
        if not NoxUI.IS_FOREVER then
            seasonCfg = { type="toggle", text="Season Panel",
              tooltip="Show an Omnium Folio shortcut to the right of the socket panel during Midnight seasons. The cog adds a Great Vault shortcut.",
              disabled=themedOff, disabledTooltip="Character Sheet",
              getValue=function() return not (NoxUIDB and NoxUIDB.charSheetSeasonPanel == false) end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.charSheetSeasonPanel = v
                  if NoxUI._refreshCharSheetSocketPanel then NoxUI._refreshCharSheetSocketPanel() end
                  NoxUI:RefreshPage()
              end }
        end
        local durSeasonRow
        durSeasonRow, h = W:DualRow(parent, y,
            { type="toggle", text="Show Item Durability",
              tooltip="Show total equipped durability above the character model, colored from green to red.",
              getValue=function() return NoxUIDB and NoxUIDB.showCharSheetDurability or false end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showCharSheetDurability = v
                  if v then
                      if NoxUIDB.charSheetDurabilityLocation == nil then
                          NoxUIDB.charSheetDurabilityLocation = "model"
                      end
                      if NoxUIDB.charSheetDurabilityShowLabel == nil then
                          NoxUIDB.charSheetDurabilityShowLabel = true
                      end
                  end
                  if NoxUI._updateCharSheetDurability then NoxUI._updateCharSheetDurability() end
                  if NoxUI._updateScrollHeaderOffset then NoxUI._updateScrollHeaderOffset() end
                  NoxUI:RefreshPage()
              end },
            seasonCfg or NoxUI.BlankRowCfg()
        );  y = y - h

        do
            NoxUI.BuildInlineCog(durSeasonRow._leftRegion, {
                disabled = function() return not (NoxUIDB and NoxUIDB.showCharSheetDurability) end,
                disabledTooltip = "Show Item Durability",
                title = "Durability Settings",
                rows = {
                    { type="dropdown", label="Location",
                      values={ model="Above Model", header="Stats Header", footer="Frame Footer" },
                      order={ "model", "header", "footer" },
                      get=function()
                          return NoxUIDB and NoxUIDB.charSheetDurabilityLocation or "model"
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.charSheetDurabilityLocation = v
                          if NoxUI._updateCharSheetDurability then NoxUI._updateCharSheetDurability() end
                          if NoxUI._updateScrollHeaderOffset then NoxUI._updateScrollHeaderOffset() end
                      end },
                    { type="toggle", label="Show Label",
                      tooltip="Prefix the durability percent with \"Durability:\".",
                      get=function() return not NoxUIDB or NoxUIDB.charSheetDurabilityShowLabel ~= false end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.charSheetDurabilityShowLabel = v
                          if NoxUI._updateCharSheetDurability then NoxUI._updateCharSheetDurability() end
                      end },
                },
            })

            -- Inline cog on Season Panel: the Great Vault shortcut is its own opt-in.
            if seasonCfg then
                NoxUI.BuildInlineCog(durSeasonRow._rightRegion, {
                    disabled = function() return themedOff() or (NoxUIDB and NoxUIDB.charSheetSeasonPanel == false) end,
                    disabledTooltip = function() return themedOff() and "Character Sheet" or "Season Panel" end,
                    title = "Season Panel Settings",
                    rows = {
                        { type="toggle", label="Great Vault Shortcut",
                          tooltip="Add a Great Vault button to the Season Panel.",
                          get=function() return NoxUIDB and NoxUIDB.charSheetSeasonVault == true or false end,
                          set=function(v)
                              if not NoxUIDB then NoxUIDB = {} end
                              NoxUIDB.charSheetSeasonVault = v
                              if NoxUI._refreshCharSheetSocketPanel then NoxUI._refreshCharSheetSocketPanel() end
                          end },
                    },
                })
            end
        end

        _, h = W:Spacer(parent, y, 10);  y = y - h

        ---------------------------------------------------------------------------
        --  GEAR FLYOUT
        ---------------------------------------------------------------------------
        -- The popup of same-slot items from an equipped slot. Item levels and
        -- stat letters enhance Blizzard's own flyout, so they stay live with the
        -- sheet off; the slot arrows belong to the sheet and grey out with it.
        -- The sheet's own slot letters live under Item Details (Stat Letters,
        -- Tertiary Stats). All off unless turned on.
        _, h = WSCardSection(parent, "GEAR FLYOUT", y);  y = y - h

        local flyoutStatsCfg
        if not NoxUI.IS_FOREVER then
            flyoutStatsCfg = { type="toggle", text="Show Item Stats",
              tooltip="Shows each item's secondary stats as letters in the gear flyout, largest first (C Crit, H Haste, M Mastery, V Versatility), so items with the same icon are told apart.",
              getValue=function() return NoxUIDB and NoxUIDB.flyoutItemStats or false end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.flyoutItemStats = v
                  NoxUI:RefreshPage()
              end }
        end
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Item Levels",
              tooltip="Shows the item level on each item in the character sheet gear flyout (the popup of same-slot bag items that appears when hovering an equipped slot), coloured by quality.",
              getValue=function() return NoxUIDB and NoxUIDB.flyoutItemLevels or false end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.flyoutItemLevels = v
              end },
            flyoutStatsCfg or NoxUI.BlankRowCfg()
        );  y = y - h

        if not NoxUI.IS_FOREVER then
            _, h = W:DualRow(parent, y,
                { type="toggle", text="Tertiary Stat Letters",
                  tooltip="Adds Leech, Avoidance and Speed (L, A, S) in smaller letters behind the secondary stats in the gear flyout.",
                  disabled=function() return not (NoxUIDB and NoxUIDB.flyoutItemStats) end,
                  disabledTooltip="Show Item Stats",
                  getValue=function() return NoxUIDB and NoxUIDB.flyoutItemStatsTertiary == true or false end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.flyoutItemStatsTertiary = v
                  end },
                { type="toggle", text="Hide Slot Flyout Arrows",
                  tooltip="Hide the arrows beside equipment slots on the Equipment tab. The slot flyouts remain usable.",
                  disabled=themedOff, disabledTooltip="Character Sheet",
                  getValue=function() return NoxUIDB and NoxUIDB.charSheetHideSlotFlyoutArrows == true end,
                  setValue=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.charSheetHideSlotFlyoutArrows = v
                      if NoxUI._refreshCharSheetSlotFlyoutArrows then NoxUI._refreshCharSheetSlotFlyoutArrows() end
                  end }
            );  y = y - h
        end

        _, h = W:Spacer(parent, y, 10);  y = y - h

        ---------------------------------------------------------------------------
        --  STAT DISPLAY
        ---------------------------------------------------------------------------
        _, h = WSCardSection(parent, "STAT DISPLAY", y);  y = y - h

        -- Every control here is a view over the keys the sheet already reads
        -- (showStatCategory_*, the Secondary/Tertiary Raw and Both pairs, the
        -- highlight pair, showManaStat, showCrest_*, statCategoryColors):
        -- nothing new is stored and nothing is written until a control changes.
        -- key = the showStatCategory_ suffix, color = the statCategoryColors key.
        local STAT_SECTIONS = {
            { key = "Attributes",     label = "Attributes",      color = "Attributes",      def = { r = 0.047, g = 0.824, b = 0.616 } },
            { key = "SecondaryStats", label = "Secondary Stats", color = "Secondary Stats", def = { r = 0.471, g = 0.255, b = 0.784 } },
            { key = "Tertiary",       label = "Tertiary Stats",  color = "Tertiary Stats",  def = { r = 0.859, g = 0.325, b = 0.855 } },
            { key = "Attack",         label = "Attack",          color = "Attack",          def = { r = 1,     g = 0.353, b = 0.122 } },
            { key = "Defense",        label = "Defense",         color = "Defense",         def = { r = 0.247, g = 0.655, b = 1 } },
            { key = "Crests",         label = "Crests",          color = "Crests",          def = { r = 1,     g = 0.784, b = 0.341 } },
            { key = "PvP",            label = "PvP",             color = "PvP",             def = { r = 0.671, g = 0.431, b = 0.349 } },
        }
        -- Same test as the sheet's own UpdateStatCategoryVisibility
        local function SectionShown(key)
            return not (NoxUIDB and NoxUIDB["showStatCategory_" .. key] == false)
        end
        local function SecOrTerShown()
            return SectionShown("SecondaryStats") or SectionShown("Tertiary")
        end

        -- Stat Sections (checkbox dropdown + cog) | Show Diminishing Returns
        local sectionsRow
        sectionsRow, h = W:DualRow(parent, y,
            { type="label", text="Stat Sections" },
            { type="toggle", text="Show Diminishing Returns",
              tooltip="Adds diminishing returns info to Secondary and Tertiary stat tooltips.",
              getValue=function() return NoxUIDB and NoxUIDB.showAdjustedStats or false end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.showAdjustedStats = v
              end }
        );  y = y - h
        local leftRgn = sectionsRow._leftRegion
        if not NoxUI._prebuilding then
            -- Each section's colour swatch sits on its row of the dropdown; dimmed while
            -- Blizzard UI Color applies or the section is unchecked.
            local items = {}
            for i, sec in ipairs(STAT_SECTIONS) do
                local key, label, colorKey, def = sec.key, sec.label, sec.color, sec.def
                items[i] = { key = key, label = label, swatch = {
                    get = function()
                        local c = NoxUIDB and NoxUIDB.statCategoryColors and NoxUIDB.statCategoryColors[colorKey]
                        if c then return c.r, c.g, c.b, 1 end
                        return def.r, def.g, def.b, 1
                    end,
                    set = function(r, g, b)
                        if not NoxUIDB then NoxUIDB = {} end
                        if not NoxUIDB.statCategoryColors then NoxUIDB.statCategoryColors = {} end
                        if not NoxUIDB.statCategoryUseColor then NoxUIDB.statCategoryUseColor = {} end
                        NoxUIDB.statCategoryColors[colorKey] = { r = r, g = g, b = b }
                        NoxUIDB.statCategoryUseColor[colorKey] = true
                        if NoxUI._refreshCharacterSheetColors then NoxUI._refreshCharacterSheetColors() end
                    end,
                    disabled = function() return blizzColorsOn() or not SectionShown(key) end,
                    -- Two requirements with opposite wording: pre-wrapped, so raw.
                    disabledTooltip = function()
                        if blizzColorsOn() then
                            return not NoxUI.IS_FOREVER
                                and NoxUI.DisabledTooltip("Blizzard UI Color", "disabled") or nil
                        end
                        return NoxUI.DisabledTooltip(label)
                    end,
                    rawTooltip = true,
                } }
            end
            local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                leftRgn, 210, leftRgn:GetFrameLevel() + 2, items,
                SectionShown,
                function(key, v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB["showStatCategory_" .. key] = v
                    if NoxUI._updateStatCategoryVisibility then
                        NoxUI._updateStatCategoryVisibility()
                    end
                    local sf = CharacterFrame and NoxUI._GetFFD(CharacterFrame).scrollFrame
                    if sf then sf:SetVerticalScroll(0) end
                    NoxUI:RefreshPage()
                end)
            PP.Point(cbDD, "RIGHT", leftRgn, "RIGHT", -20, 0)
            leftRgn._control = cbDD
            leftRgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(cbDDRefresh)
        end
        do
            -- Cog: the per-section extras the old per-section rows held (outside the
            -- prebuild guard so the index pass sees its rows)
            local rows = {
                { type="toggle", label="Show Mana",
                  tooltip="Adds Mana to the Attributes section.",
                  disabled=function() return not SectionShown("Attributes") end,
                  disabledTooltip="Attributes",
                  get=function() return NoxUIDB and NoxUIDB.showManaStat == true end,
                  set=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.showManaStat = v
                      if NoxUI._refreshStatsVisibility then NoxUI._refreshStatsVisibility() end
                  end },
                { type="reordercheck", label="Crests", ddWidth=150,
                  disabled=function() return not SectionShown("Crests") end,
                  disabledTooltip="Crests",
                  items={
                      { key="Myth",       label="Myth",       fixed=true },
                      { key="Hero",       label="Hero",       fixed=true },
                      { key="Champion",   label="Champion",   fixed=true },
                      { key="Veteran",    label="Veteran",    fixed=true },
                      { key="Adventurer", label="Adventurer", fixed=true },
                  },
                  get=function(key) return not (NoxUIDB and NoxUIDB["showCrest_" .. key] == false) end,
                  set=function(key, v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB["showCrest_" .. key] = v
                      if NoxUI._refreshStatsVisibility then NoxUI._refreshStatsVisibility() end
                  end },
            }
            -- Blizz Default only (not WoW Forever, whose sheet has no
            -- NoxUI stats section): on unless turned off.
            if stock and not NoxUI.IS_FOREVER then
                rows[#rows + 1] = { type="toggle", label="Blizzard UI Color",
                  tooltip="Shows the item level and stat titles in Blizzard's yellow.",
                  get=function() return not (NoxUIDB and NoxUIDB.charSheetBlizzColors == false) end,
                  set=function(v)
                      if not NoxUIDB then NoxUIDB = {} end
                      NoxUIDB.charSheetBlizzColors = v
                      if NoxUI._refreshCharacterSheetColors then NoxUI._refreshCharacterSheetColors() end
                      NoxUI:RefreshPage()
                  end }
            end
            NoxUI.BuildInlineCog(leftRgn, {
                title = "Stat Section Settings", rows = rows,
                disabled = themedOff, disabledTooltip = "Character Sheet",
            })
        end
        AttachDisabledOverlay(sectionsRow)

        -- Secondary/Tertiary Text | Secondary/Tertiary Highlights (both write
        -- the Secondary and the Tertiary keys; the Secondary pair is shown)
        local stRow
        stRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Secondary/Tertiary Text",
              tooltip="How Secondary and Tertiary stat values are shown.",
              values={ pct="Percent", value="Value", both="Value (Percent)" },
              order={ "pct", "value", "both" },
              disabled=function() return not SecOrTerShown() end,
              disabledTooltip="Secondary Stats or Tertiary Stats",
              getValue=function()
                  -- Both wins over Raw, as on the sheet
                  if NoxUIDB and NoxUIDB.showSecondaryBoth then return "both" end
                  if NoxUIDB and NoxUIDB.showSecondaryRaw then return "value" end
                  return "pct"
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  local raw, both = v == "value", v == "both"
                  NoxUIDB.showSecondaryRaw, NoxUIDB.showSecondaryBoth = raw, both
                  NoxUIDB.showTertiaryRaw, NoxUIDB.showTertiaryBoth = raw, both
                  if NoxUI._refreshStatFormats then NoxUI._refreshStatFormats() end
              end },
            { type="toggle", text="Secondary/Tertiary Highlights",
              tooltip="Hovering a Secondary or Tertiary stat highlights the gear that has it.",
              disabled=function() return not SecOrTerShown() end,
              disabledTooltip="Secondary Stats or Tertiary Stats",
              getValue=function()
                  return NoxUIDB and (NoxUIDB.highlightSecondaryItems == true
                      or NoxUIDB.highlightTertiaryItems == true) or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.highlightSecondaryItems = v
                  NoxUIDB.highlightTertiaryItems = v
              end }
        );  y = y - h
        AttachDisabledOverlay(stRow)

        ---------------------------------------------------------------------------
        --  INSPECT SHEET
        ---------------------------------------------------------------------------
        _, h = WSCardSection(parent, "INSPECT SHEET", y);  y = y - h

        local themedInspectSheetRow
        themedInspectSheetRow, h = W:DualRow(parent, y,
            { type="toggle", text="Enable Inspect Sheet",
              tooltip="Applies NoxUI theme styling to the inspect sheet window.",
              getValue=function()
                  return not NoxUIDB or NoxUIDB.themedInspectSheet ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.themedInspectSheet = v
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Inspect Sheet theme setting requires a UI reload to fully apply.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
                  NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Enchants",
              tooltip="How enchants show beside each item.",
              values=EnchantValues(), order={ "none", "icons", "text" },
              disabled=function() return NoxUIDB and NoxUIDB.themedInspectSheet == false end,
              disabledTooltip="Inspect Sheet",
              getValue=function() return EnchantMode("inspectShowEnchants", "inspectEnchantNames") end,
              setValue=function(v)
                  SetEnchantMode("inspectShowEnchants", "inspectEnchantNames", v)
                  if NoxUI._refreshInspectSlotLabels then NoxUI._refreshInspectSlotLabels() end
                  -- Shows or hides the Text Size cog
                  NoxUI:RefreshPage()
              end }
        );  y = y - h

        -- Text Size (unset follows the character sheet's), shown only while
        -- the enchants show as text.
        do
            local cogBtn = NoxUI.BuildInlineCog(themedInspectSheetRow._rightRegion, {
                title = "Enchant Text",
                disabled = function() return NoxUIDB and NoxUIDB.themedInspectSheet == false end,
                disabledTooltip = "Inspect Sheet",
                rows = {
                    { type="slider", label="Text Size", min=6, max=20, step=1,
                      get=function()
                          return (NoxUIDB and (NoxUIDB.inspectEnchantSize or NoxUIDB.charSheetEnchantSize)) or 9
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.inspectEnchantSize = v
                          if NoxUI._refreshInspectSlotLabels then NoxUI._refreshInspectSlotLabels() end
                      end },
                },
            })
            if not NoxUI._prebuilding then
                local function UpdateCogVis()
                    cogBtn:SetShown(EnchantTextShown("inspectShowEnchants", "inspectEnchantNames"))
                end
                NoxUI.RegisterWidgetRefresh(UpdateCogVis)
                UpdateCogVis()
            end
        end

        local itemLevelInspectRow
        itemLevelInspectRow, h = W:DualRow(parent, y,
            { type="toggle", text="Item Level",
              tooltip="Toggle visibility of item level text on the inspect sheet.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.inspectShowItemLevel ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.inspectShowItemLevel = v
                  if NoxUI._refreshInspectItemLevelVisibility then
                      NoxUI._refreshInspectItemLevelVisibility()
                  end
              end },
            { type="toggle", text="Upgrade Track",
              tooltip="Toggle visibility of upgrade track text on the inspect sheet.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.inspectShowUpgradeTrack ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.inspectShowUpgradeTrack = v
                  if NoxUI._refreshInspectUpgradeTrackVisibility then
                      NoxUI._refreshInspectUpgradeTrackVisibility()
                  end
              end }
        );  y = y - h

        if not NoxUI._prebuilding then
            local function themedOff()
                return not (NoxUIDB and NoxUIDB.themedInspectSheet)
            end

            local itemLevelInspectBlock = CreateFrame("Frame", nil, itemLevelInspectRow)
            itemLevelInspectBlock:SetAllPoints(itemLevelInspectRow)
            itemLevelInspectBlock:SetFrameLevel(itemLevelInspectRow:GetFrameLevel() + 10)
            itemLevelInspectBlock:EnableMouse(true)
            local itemLevelInspectBg = NoxUI.SolidTex(itemLevelInspectBlock, "BACKGROUND", 0, 0, 0, 0)
            itemLevelInspectBg:SetAllPoints()
            itemLevelInspectBlock:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(itemLevelInspectBlock, NoxUI.DisabledTooltip("Inspect Sheet"))
            end)
            itemLevelInspectBlock:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

            NoxUI.RegisterWidgetRefresh(function()
                if themedOff() then
                    itemLevelInspectBlock:Show()
                    itemLevelInspectRow:SetAlpha(0.3)
                else
                    itemLevelInspectBlock:Hide()
                    itemLevelInspectRow:SetAlpha(1)
                end
            end)
            if themedOff() then itemLevelInspectBlock:Show() itemLevelInspectRow:SetAlpha(0.3) else itemLevelInspectBlock:Hide() itemLevelInspectRow:SetAlpha(1) end
        end

        return y
    end

    ---------------------------------------------------------------------------
    --  LFG Menu card content
    ---------------------------------------------------------------------------
    local function BuildLFGMenuContent(parent, y)
        local W = NoxUI.Widgets
        local _, h

        _, h = WSCardSection(parent, "QUALITY OF LIFE", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Remember Sign-Up Roles",
              tooltip="Remembers the Tank/Healer/DPS roles you last applied with and restores them the next time you sign up to a premade group (limited to roles your current spec can fill). Works with or without the reskin.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.lfgRememberRoles == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.lfgRememberRoles = v
                  if NoxUI._GroupFinder_RefreshQoL then NoxUI._GroupFinder_RefreshQoL() end
              end },
            { type="label", text="" }
        );  y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Friends List card content (WoW Forever only, where the Friends List
    --  module never loads): what that module offers retail's friends list,
    --  from the shared friends kit, and the custom friends list (its switch,
    --  Custom Friends List Tiles, and its Tile Height), on the card's own
    --  settings (NoxUIDB.friendsListCard through ns.FriendsCardGet / Set,
    --  in NoxUIApparenceBlizzard_FriendsForever.lua). The switch follows the
    --  card's look until picked (on while the card is skinned, off under
    --  Blizz Default); the tile settings grey out while neither the tiles on
    --  Blizzard's cards nor the custom list draws; auto-accept runs whatever
    --  the skin.
    ---------------------------------------------------------------------------
    local function BuildFriendsCardContent(parent, y)
        local W = NoxUI.Widgets
        local _, row, h
        local Kit = NoxUI.FriendsKit

        local CUSTOM = "Custom Friends List Tiles"
        local function customOff()
            return ns.FriendsCardGet("customTiles") ~= true
        end
        -- Blizz Default keeps Blizzard's cards, so only the custom list draws tiles there
        local function tilesOff()
            return NoxUI.GetBlizzWindowStyle("socialui") == "off" and customOff()
        end
        local function tileGate(cfg, off)
            cfg.disabled = off or tilesOff
            cfg.disabledTooltip = CUSTOM
            return cfg
        end

        _, h = WSCardSection(parent, "DISPLAY", y);  y = y - h

        -- Custom Friends List Tiles | Tile Height: the custom friends list
        -- (NoxUI_FriendsList.lua) and its own height
        local tileMin, tileMax = NoxUI.FriendsList.TileRange()
        row, h = W:DualRow(parent, y,
            { type="toggle", text=CUSTOM,
              tooltip="NoxUI's own friends list, with a tile height you choose and friend groups. Right click a friend to set its group.",
              getValue=function() return not customOff() end,
              setValue=function(v)
                  ns.FriendsCardSet("customTiles", v and true or false)
                  NoxUI:RefreshPage()  -- the tile settings' disabled state
              end },
            tileGate({ type="slider", text="Tile Height", min=tileMin, max=tileMax, step=1,
              tooltip="The height of each friend in the custom friends list. Shorter tiles show fewer lines.",
              getValue=function() return ns.FriendsCardGet("tileHeight") end,
              setValue=function(v) ns.FriendsCardSet("tileHeight", v) end }, customOff)
        );  y = y - h

        -- Tile Features | Class Icon Theme
        row, h = W:DualRow(parent, y,
            tileGate({ type="dropdown", text="Tile Features",
              values={ __placeholder="..." }, order={ "__placeholder" },
              getValue=function() return "__placeholder" end, setValue=function() end }),
            tileGate({ type="dropdown", text="Class Icon Theme",
              values = Kit.ICON_STYLE_VALUES,
              order  = Kit.ICON_STYLE_ORDER,
              getValue=function() return ns.FriendsCardGet("iconStyle") end,
              setValue=function(v) ns.FriendsCardSet("iconStyle", v) end })
        );  y = y - h

        -- Tile Features: one checkbox dropdown over the three tile switches,
        -- each still its own key, in place of the row's placeholder.
        if not NoxUI._prebuilding then
            local rgn = row._leftRegion
            if rgn._control then rgn._control:Hide() end
            local dd, refresh = NoxUI.BuildVisOptsCBDropdown(rgn, 220, rgn:GetFrameLevel() + 2,
                {
                    { key="factionBanners", label="Faction Banners" },
                    { key="showRegionIcons", label="Region Icons",
                      tooltip="Shows a map icon of the friend's region if they are not playing within your region" },
                    { key="classColorNames", label="Class Colored Names" },
                },
                function(key) return ns.FriendsCardGet(key) == true end,
                function(key, v) ns.FriendsCardSet(key, v and true or false) end,
                nil, nil, nil, nil, nil,
                { disabled = tilesOff, disabledTooltip = CUSTOM })
            NoxUI.PanelPP.Point(dd, "RIGHT", rgn, "RIGHT", -20, 0)
            rgn._control = dd
            rgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(refresh)
        end

        -- Auto-Accept Friend Invites
        row, h = W:DualRow(parent, y,
            { type="toggle", text="Auto-Accept Friend Invites",
              tooltip="Auto-accepts all group invites from people on your friends list",
              getValue=function() return ns.FriendsCardGet("autoAcceptFriendInvites") == true end,
              setValue=function(v)
                  ns.FriendsCardSet("autoAcceptFriendInvites", v)
                  NoxUI:RefreshPage()  -- the guildmate cog's disabled state
              end },
            NoxUI.BlankRowCfg()
        );  y = y - h

        -- Guildmates in a cog on Auto-Accept Friend Invites: it only extends
        -- that feature, so the cog blocks while the toggle is off.
        do
            NoxUI.BuildInlineCog(row._leftRegion, {
                title = "Auto Accept Settings",
                rows = {
                    { type="toggle", label="Accept Invites from Guildmates",
                      get=function() return ns.FriendsCardGet("autoAcceptGuildInvites") == true end,
                      set=function(v) ns.FriendsCardSet("autoAcceptGuildInvites", v) end },
                },
                disabled = function() return ns.FriendsCardGet("autoAcceptFriendInvites") ~= true end,
                disabledTooltip = "Auto-Accept Friend Invites",
            })
        end

        return y
    end

    local function BuildMerchantContent(parent, y)
        local W = NoxUI.Widgets
        local _, h

        local function themedOff()
            return NoxUIDB and NoxUIDB.reskinMerchant == false
        end

        local function AttachDisabledOverlay(target)
            if NoxUI._prebuilding then return end
            local block = CreateFrame("Frame", nil, target)
            block:SetAllPoints(target)
            block:SetFrameLevel(target:GetFrameLevel() + 10)
            block:EnableMouse(true)
            local bg = NoxUI.SolidTex(block, "BACKGROUND", 0, 0, 0, 0)
            bg:SetAllPoints()
            block:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(block, NoxUI.DisabledTooltip("Merchant"))
            end)
            block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            local function refresh()
                if themedOff() then block:Show(); target:SetAlpha(0.3)
                else block:Hide(); target:SetAlpha(1) end
            end
            NoxUI.RegisterWidgetRefresh(refresh); refresh()
        end

        _, h = WSCardSection(parent, "MERCHANT OPTIONS", y);  y = y - h

        local function merchantShowAsListOff()
            return NoxUIDB and NoxUIDB.merchantShowAsList == false
        end

        local row
        row, h = W:DualRow(parent, y,
            { type="toggle", text="Show As List",
              tooltip="Shows the items as a list instead of pages.",
              getValue=function()
                return NoxUIDB and NoxUIDB.merchantShowAsList == true
              end,
              setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                local previousValue = NoxUIDB.merchantShowAsList
                NoxUIDB.merchantShowAsList = v

                -- Enabling the setting breaks the UI immediately, a reload is required
                NoxUI:ShowConfirmPopup({
                    title       = "Reload Required",
                    message     = "Merchant Show As List setting requires a UI reload to fully apply.",
                    confirmText = "Reload Now",
                    cancelText  = "Cancel",
                    reload      = true,
                    onCancel    = function()
                        NoxUIDB.merchantShowAsList = previousValue;
                        NoxUI:RefreshPage()
                    end,
                })
              end },
            { type="slider", text="Row Height", min=24, max=40, step=1,
              disabled=merchantShowAsListOff, disabledTooltip="Show As List",
              getValue=function() return (NoxUIDB and NoxUIDB.merchantListRowHeight) or 32 end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.merchantListRowHeight = v
                  if NoxUI._Merchant_RefreshRowHeight then NoxUI._Merchant_RefreshRowHeight() end
              end }
        ); y = y - h
        AttachDisabledOverlay(row)

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Show Item Level",
              tooltip="Shows the item level on weapons and armor a vendor sells.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.merchantShowItemLevel == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.merchantShowItemLevel = v
                  if NoxUI._Merchant_RefreshItemLevels then NoxUI._Merchant_RefreshItemLevels() end
              end },
            { type="toggle", text="Bulk Buy",
              tooltip="Shift-click a vendor item to choose a quantity and review the total before buying.",
              disabled=function() return NoxUI.PadGamepadUI() end,
              disabledTooltip="This option does not work with the Gamepad interface style.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.merchantBulkBuy == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.merchantBulkBuy = v
                  if NoxUI._Merchant_RefreshBulkBuy then NoxUI._Merchant_RefreshBulkBuy() end
              end }
        ); y = y - h

        -- Expand Vendor UI: a bigger grid in the vendor window. The cog sets its
        -- size; 2 x 5 is Blizzard's own layout. Needs the Merchant skin (the
        -- card overlay) and is not used with Show As List.
        local function merchantShowAsListOn()
            return NoxUIDB and NoxUIDB.merchantShowAsList == true
        end
        local function BuildExpandCog(rgn)
            local function setSize(key, v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB[key] = v
                if NoxUI._Merchant_RefreshExpand then NoxUI._Merchant_RefreshExpand() end
            end
            NoxUI.BuildInlineCog(rgn, {
                title = "Expand Vendor UI Settings",
                rows = {
                    { type="slider", label="Vendor Columns", min=2, max=6, step=1,
                      get=function() return (NoxUIDB and NoxUIDB.merchantCols) or 2 end,
                      set=function(v) setSize("merchantCols", v) end },
                    { type="slider", label="Vendor Rows", min=5, max=10, step=1,
                      get=function() return (NoxUIDB and NoxUIDB.merchantRows) or 5 end,
                      set=function(v) setSize("merchantRows", v) end },
                },
                gap = 9,
                disabled = function()
                    return merchantShowAsListOn() or not (NoxUIDB and NoxUIDB.merchantExpand)
                end,
                disabledTooltip = function()
                    if merchantShowAsListOn() then return "This option does not work with Show As List." end
                    return "Expand Vendor UI"
                end,
            })
        end

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Expand Vendor UI",
              tooltip="Shows more vendor items at once, in the columns and rows set in the cog.",
              disabled=merchantShowAsListOn, disabledTooltip="This option does not work with Show As List.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.merchantExpand == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.merchantExpand = v
                  if NoxUI._Merchant_RefreshExpand then NoxUI._Merchant_RefreshExpand() end
                  NoxUI:RefreshPage()
              end },
            { type="toggle", text="Flag/Hide Owned Items",
              tooltip="Tints red the vendor items you already have (known recipes, mounts, pets, toys...) and, with Expand Vendor UI, adds a button that hides them.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.merchantMarkOwned == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.merchantMarkOwned = v
                  if NoxUI._Merchant_RefreshOwned then NoxUI._Merchant_RefreshOwned() end
              end }
        ); y = y - h
        BuildExpandCog(row._leftRegion)
        AttachDisabledOverlay(row)

        return y
    end

    ---------------------------------------------------------------------------
    --  Loot Window card: BORDER, an optional border in place of the window
    --  border (ApplyLootBorder, NoxUIApparenceBlizzard_WindowPacks.lua; Default
    --  leaves the setting unset), and ICON BORDER, the item icons' border in a
    --  picked style. The Tooltips page's border rows (the shared helpers above,
    --  under the "lootWindow" and "lootIcon" prefixes), plus a Quality color mode.
    ---------------------------------------------------------------------------
    local function BuildLootContent(parent, y)
        if not NoxUIDB then NoxUIDB = {} end
        local W = NoxUI.Widgets
        local _, h
        local prefix = "lootWindow"
        local iconPrefix = "lootIcon"

        local function lootOff()
            return NoxUI.GetBlizzWindowStyle("loot") == "off"
        end
        local function iconOff()
            return lootOff() or not NoxUIDB.lootIconBorder
        end
        local function refresh()
            if NoxUI._Loot_RefreshBorder then NoxUI._Loot_RefreshBorder() end
        end

        _, h = WSCardSection(parent, "BORDER", y);  y = y - h

        local texValues, texOrder = DefaultableBorderValues()

        local row
        row, h = W:DualRow(parent, y,
            { type="dropdown", text="Border Style",
              tooltip="Replaces the loot window's border. Default keeps the standard window border.",
              disabled=lootOff, disabledTooltip="Loot Window",
              values=texValues, order=texOrder,
              getValue=function()
                  return NoxUIDB and NoxUIDB[prefix.."BorderTexture"] or "default"
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  SetDefaultableBorderStyle(prefix, v)
                  refresh()
                  NoxUI:RefreshPage(true)
              end },
            BorderSizeSlider(prefix, "Border Size", lootOff, refresh, "Loot Window")
        ); y = y - h

        -- Accent | Class | Custom | Quality swatches beside Border Size, as on the Tooltips page.
        AttachBorderControls(row, prefix, lootOff, false, { apply = refresh,
            quality = { key = prefix.."BorderQualityColor",
                        tip = "Quality Color: the best item's, or this color for Poor and Common" } })

        -- Width | Height Offset, only for a textured style (art with built-in padding needs fitting).
        local ocfgL, ocfgR = BorderOffsetCfgs(prefix, lootOff, refresh, "Loot Window")
        if ocfgL then _, h = W:DualRow(parent, y, ocfgL, ocfgR); y = y - h end

        -- ICON BORDER: the item icons' quality border in a picked style and size (color stays the item quality).
        _, h = WSCardSection(parent, "ICON BORDER", y);  y = y - h

        local iconValues, iconOrder = NoxUI.GetBorderTextureDropdown()
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Icon Borders",
              tooltip="Draws the item icons' quality border in the style and size below.",
              disabled=lootOff, disabledTooltip="Loot Window",
              getValue=function() return NoxUIDB.lootIconBorder == true end,
              setValue=function(v)
                  NoxUIDB.lootIconBorder = v
                  refresh()
                  NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Icon Border Style",
              disabled=iconOff, disabledTooltip="Icon Borders",
              values=iconValues, order=iconOrder,
              getValue=function() return NoxUIDB[iconPrefix.."BorderTexture"] or "solid" end,
              setValue=function(v)
                  local db = NoxUIDB
                  db[iconPrefix.."BorderTexture"] = v
                  db[iconPrefix.."BorderOffsetX"] = nil
                  db[iconPrefix.."BorderOffsetY"] = nil
                  if db[iconPrefix.."BorderThicknessPx"] then db[iconPrefix.."BorderThicknessPx"] = false end
                  refresh()
                  NoxUI:RefreshPage(true)
              end }
        ); y = y - h

        local iconSize = BorderSizeSlider(iconPrefix, "Icon Border Size", iconOff, refresh, "Icon Borders")
        iconSize.trackWidth = nil  -- no swatches beside it: the full track
        -- Textured styles add the two offsets: Size | Width Offset, then Height Offset | blank.
        local icL, icR = BorderOffsetCfgs(iconPrefix, iconOff, refresh, "Icon Borders")
        if icL then
            _, h = W:DualRow(parent, y, iconSize, icL); y = y - h
            _, h = W:DualRow(parent, y, icR, NoxUI.BlankRowCfg()); y = y - h
        else
            _, h = W:DualRow(parent, y, iconSize, NoxUI.BlankRowCfg()); y = y - h
        end

        return y
    end

    local function BuildLootToastContent(parent, y)
        local W = NoxUI.Widgets
        local _, h

        _, h = WSCardSection(parent, "QUALITY OF LIFE", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Quality Strip",
              tooltip="Adds a strip down the left edge of a loot toast in the item's quality color. The flat skin drops Blizzard's quality ring around the icon, so this puts that rarity cue back.",
              getValue=function()
                  return not NoxUIDB or NoxUIDB.lootToastQualityStrip ~= false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.lootToastQualityStrip = v
                  if NoxUI._LootToast_Refresh then NoxUI._LootToast_Refresh() end
              end },
            { type="toggle", text="Gold Toast Strip",
              tooltip="Also show the strip on gold toasts, in the header's gold color. Gold has no rarity to signal, so this is off by default.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.lootToastQualityStripMoney == true
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.lootToastQualityStripMoney = v
                  if NoxUI._LootToast_Refresh then NoxUI._LootToast_Refresh() end
              end }
        ); y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Toast Scale",
              tooltip="Scales the loot and gold toasts.",
              min=0.5, max=1.5, step=0.05, format="%.0f%%",
              displayMul=100,
              getValue=function()
                  return NoxUIDB and NoxUIDB.lootToastScale or 1.0
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.lootToastScale = v
                  if NoxUI._LootToast_Refresh then NoxUI._LootToast_Refresh() end
              end },
            { type="label", text="" }
        ); y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Mail card, ALT LIST section: the Alt List beside Send Mail
    --  (NoxUIApparenceBlizzard_MailAlts.lua, ns.MailAlts), whatever the card's
    --  style. Sort, cap and minimum level ride the toggle's cog; Shown
    --  Characters lists every recorded character under its realm.
    ---------------------------------------------------------------------------
    local function BuildMailAltList(parent, y)
        local MA = ns.MailAlts
        if not MA then return y end
        local W = NoxUI.Widgets
        local _, row, h
        local REQ = "Show Alt List"
        local function On() return NoxUIDB and NoxUIDB.mailAltList == true end
        local function Off() return not On() end
        local function Get(key, default)
            local v = NoxUIDB and NoxUIDB[key]
            if v == nil then return default end
            return v
        end
        local function Set(key, v)
            if not NoxUIDB then NoxUIDB = {} end
            NoxUIDB[key] = v
            MA.Refresh()
        end
        -- Every recorded character, a header per realm (rebuilt on each open).
        local function Items()
            local items, lastRealm = {}, nil
            for _, e in ipairs(MA.Entries()) do
                if e.realm ~= lastRealm then
                    lastRealm = e.realm
                    items[#items + 1] = { isHeader = true, label = e.realm }
                end
                local c = NoxUI.GetClassColor(e.class)
                items[#items + 1] = {
                    key = e.guid,
                    label = NoxUI.HexColor(c.r, c.g, c.b) .. e.name .. "|r",
                    tooltip = MA.Describe(e),
                }
            end
            return items
        end

        _, h = WSCardSection(parent, "ALT LIST", y);  y = y - h

        row, h = W:DualRow(parent, y,
            { type="toggle", text="Show Alt List",
              tooltip=NoxUI.IS_FOREVER and "Lists your alts beside Send Mail; its tabs also list your guild and your friends."
                  or "Lists your alts beside Send Mail.",
              getValue=On,
              setValue=function(v)
                  Set("mailAltList", v)
                  NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Shown Characters",
              tooltip="Untick a character to leave it off the list.",
              disabled=Off, disabledTooltip=REQ,
              values={ __placeholder="..." }, order={ "__placeholder" },
              getValue=function() return "__placeholder" end, setValue=function() end }
        ); y = y - h

        do
            NoxUI.BuildInlineCog(row._leftRegion, {
                title = "Alt List",
                disabled = Off,
                disabledTooltip = REQ,
                rows = {
                    { type="dropdown", label="Sort By",
                      values={ recent="Last Played", level="Level", name="Name" },
                      order={ "recent", "level", "name" },
                      get=function() return Get("mailAltListSort", MA.DEFAULT_SORT) end,
                      set=function(v) Set("mailAltListSort", v) end },
                    { type="slider", label="Max Characters Shown", min=1, max=MA.MAX_ROWS, step=1,
                      get=function() return Get("mailAltListMax", MA.DEFAULT_MAX) end,
                      set=function(v) Set("mailAltListMax", v) end },
                    { type="slider", label="Minimum Level", min=1, max=GetMaxLevelForLatestExpansion(), step=1,
                      get=function() return Get("mailAltListMinLevel", MA.DEFAULT_MIN_LEVEL) end,
                      set=function(v) Set("mailAltListMinLevel", v) end },
                },
            })
        end
        if not NoxUI._prebuilding then
            -- Shown Characters: the checkbox dropdown in place of the row's
            -- placeholder; a long roster gets the search box.
            local rgn = row._rightRegion
            if rgn._control then rgn._control:Hide() end
            local dd, refresh = NoxUI.BuildVisOptsCBDropdown(rgn, 220, rgn:GetFrameLevel() + 2, Items,
                MA.IsShown, MA.SetShown, nil, 10, #MA.Entries() > 12, nil, nil,
                { disabled = Off, disabledTooltip = REQ, countLabel = true })
            NoxUI.PanelPP.Point(dd, "RIGHT", rgn, "RIGHT", -20, 0)
            rgn._control = dd
            rgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(refresh)
        end

        return y
    end

    ---------------------------------------------------------------------------
    --  Blizzard Window Skins page: one expandable card per reskinned window.
    --  Card headers are custom chrome, but every sub-setting ROW is a standard
    --  W: widget built as a direct child of the page wrapper, so inline search
    --  and nav deep-links keep working. Expand state is session-only; clicking
    --  a header rebuilds the page with that card open or closed.
    ---------------------------------------------------------------------------
    local WS_ARROW_DOWN = "Interface\\AddOns\\NoxUI\\media\\icons\\nui_fleche_bas3.png"
    local WS_ARROW_UP   = "Interface\\AddOns\\NoxUI\\media\\icons\\nui_fleche_haut3.png"
    local WS_CARD_INSET = 0    -- card edges align with the DualRow content width
    local WS_HEADER_H   = 54
    local WS_CARD_GAP   = 14

    local _wsExpanded = {}
    local _wsApplyAllStyle = "eui"  -- set-all dropdown pick (session-only)

    local function WSReloadPopup(message)
        NoxUI:ShowConfirmPopup({
            title       = "Reload Required",
            message     = message,
            confirmText = "Reload Now",
            cancelText  = "Later",
            reload      = true,
        })
    end

    -- Style vocabulary shared by the per-card dropdowns and the set-all row.
    local WS_STYLE_VALUES = { eui = "NoxUI", modern = "Modern", off = "Blizz Default" }
    local WS_STYLE_ORDER  = { "eui", "modern", "off" }
    -- The Character Sheet's own: its Blizz Default keeps Blizzard's sheet
    -- with the NoxUI stats, slot text and socket panel; Off leaves the
    -- sheet untouched.
    local WS_CHARSHEET_VALUES = { eui = "NoxUI", modern = "Modern", blizzard = "Blizz Default", off = "Off" }
    local WS_CHARSHEET_ORDER  = { "eui", "modern", "blizzard", "off" }

    -- Modern background color + opacity: ONE global setting for the Modern
    -- style, resolved by the window-skin engine and applied live to every
    -- window currently set to Modern.
    local function WSModernGet()
        if ns.WSkin and ns.WSkin.GetModernBG then
            return ns.WSkin.GetModernBG()
        end
        return 0.067, 0.067, 0.067, 0.97
    end
    local function WSModernSet(r, g, b, a)
        if not NoxUIDB then NoxUIDB = {} end
        NoxUIDB.blizzWindowModernDefault = { r = r, g = g, b = b, a = a }
        if NoxUI._WSkinRefreshStyles then NoxUI._WSkinRefreshStyles() end
    end

    -- Single Modern color swatch left of the set-all dropdown, greyed and
    -- blocked while isOff() (that dropdown is not on Modern). The picker
    -- carries the opacity slider; edits write the Modern preset directly, so
    -- windows already on Modern recolor immediately (no Apply to All).
    local function AttachModernSwatch(host, anchorTo, isOff)
        local swatch, updateSwatch = NoxUI.BuildColorSwatch(host, host:GetFrameLevel() + 5,
            function() return WSModernGet() end,
            function(r, g, b, a) WSModernSet(r, g, b, a) end,
            true, 20)
        NoxUI.PanelPP.Point(swatch, "RIGHT", anchorTo, "LEFT", -8, 0)
        swatch:HookScript("OnEnter", function(s)
            NoxUI.ShowWidgetTooltip(s, "Background color for the Modern style.")
        end)
        swatch:HookScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        local block = CreateFrame("Frame", nil, swatch)
        block:SetAllPoints()
        block:SetFrameLevel(swatch:GetFrameLevel() + 10)
        block:EnableMouse(true)
        block:SetScript("OnEnter", function()
            NoxUI.ShowWidgetTooltip(swatch, NoxUI.DisabledTooltip("This option requires the Modern style."))
        end)
        block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        local function Refresh()
            updateSwatch()
            local off = isOff()
            swatch:SetAlpha(off and 0.3 or 1)
            block:SetShown(off)
        end
        NoxUI.RegisterWidgetRefresh(Refresh)
        Refresh()
    end

    -- Global look settings (Global Options section): central tables, nil =
    -- defaults, resolved by the window-skin engine and applied live.
    local function WSLook(key)
        return NoxUIDB and NoxUIDB[key]
    end
    local function WSLookSet(key, field, v)
        if not NoxUIDB then NoxUIDB = {} end
        local t = NoxUIDB[key]
        if not t then t = {}; NoxUIDB[key] = t end
        t[field] = v
        if NoxUI._WSkinRefreshLooks then NoxUI._WSkinRefreshLooks() end
    end

    -- Inline accent|custom swatch pair on a DualRow region (the standard
    -- dual-swatch treatment): custom sits nearest the control, accent left of
    -- it; the active mode renders bright, the other dimmed.
    local function AttachLookSwatches(rgn, row, key)
        local PP = NoxUI.PanelPP
        local ctrl = rgn._control

        local customSwatch, updateCustom = NoxUI.BuildColorSwatch(
            rgn, row:GetFrameLevel() + 3,
            function()
                local c = WSLook(key)
                local col = c and c.color
                if col then return col.r or 1, col.g or 1, col.b or 1 end
                return 1, 1, 1
            end,
            function(r, g, b)
                WSLookSet(key, "color", { r = r, g = g, b = b })
                WSLookSet(key, "useCustom", true)
                NoxUI:RefreshPage()
            end,
            false, 20)
        PP.Point(customSwatch, "RIGHT", ctrl, "LEFT", -8, 0)
        local origClick = customSwatch:GetScript("OnClick")
        customSwatch:SetScript("OnClick", function(self, ...)
            local c = WSLook(key)
            if not (c and c.useCustom) then
                WSLookSet(key, "useCustom", true)
                NoxUI:RefreshPage()
                return
            end
            if origClick then origClick(self, ...) end
        end)
        customSwatch:SetScript("OnEnter", function()
            NoxUI.ShowWidgetTooltip(customSwatch, "Custom Color")
        end)
        customSwatch:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

        local accentSwatch, updateAccent = NoxUI.BuildColorSwatch(
            rgn, row:GetFrameLevel() + 3,
            function()
                return NoxUI.ResolveActiveAccent()
            end,
            function()
                WSLookSet(key, "useCustom", false)
                NoxUI:RefreshPage()
            end,
            false, 20)
        PP.Point(accentSwatch, "RIGHT", customSwatch, "LEFT", -8, 0)
        accentSwatch:SetScript("OnClick", function()
            WSLookSet(key, "useCustom", false)
            NoxUI:RefreshPage()
        end)
        accentSwatch:SetScript("OnEnter", function()
            NoxUI.ShowWidgetTooltip(accentSwatch, "Accent Color")
        end)
        accentSwatch:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
        rgn._lastInline = accentSwatch

        local function refreshPair()
            updateCustom(); updateAccent()
            local c = WSLook(key)
            local useCustom = c and c.useCustom
            customSwatch:SetAlpha(useCustom and 1 or 0.3)
            accentSwatch:SetAlpha(useCustom and 0.3 or 1)
        end
        NoxUI.RegisterWidgetRefresh(refreshPair)
        refreshPair()
    end

    local WINDOWS = {
        {
            key   = "charsheet",
            title = "Character Sheet",
            desc  = "Equipment panel with stat categories, item level, enchants, gems, and the inspect sheet.",
            reloadMsg = "Character Sheet theme setting requires a UI reload to fully apply.",
            styleValues = WS_CHARSHEET_VALUES,
            styleOrder  = WS_CHARSHEET_ORDER,
            -- What the set-all row's Blizz Default gives this card.
            blizzDefault = "blizzard",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.themedCharacterSheet = v
                NoxUIDB.themedInspectSheet = v
                -- Individual feature toggles retain their values.
            end,
            buildContent = BuildCharacterSheetContent,
        },
        {
            key   = "lfg",
            -- Forever's window is titled "Looking For Group"; the parens keep "lfg"
            -- searchable there (the card search indexes title + desc).
            title = NoxUI.IS_FOREVER and "Looking For Group (LFG)" or "LFG Menu",
            desc  = NoxUI.IS_FOREVER
                and "Looking For Group window: group listing, group browser and who list, plus the group tooltip."
                or "Group Finder and Premade Groups window, plus browsing quality-of-life extras.",
            reloadMsg = "Changing the Group Finder reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLFGMenu = v
            end,
            -- Its one extra (Remember Sign-Up Roles) hooks retail's premade sign-up
            -- dialog, which Forever does not have.
            buildContent = not NoxUI.IS_FOREVER and BuildLFGMenuContent or nil,
        },
        {
            key   = "legacysystem",
            title = "Progress Legacy",
            desc  = "Restyles the Progress Legacy window (reward track, challenges and the legacy tree) in the NoxUI style.",
            reloadMsg = "Changing the Progress Legacy reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLegacySystem = v
            end,
        },
        {
            key   = "greatvault",
            title = "Great Vault",
            desc  = "Weekly rewards window with custom tile backgrounds, progress colors, and completion states.",
            reloadMsg = "Changing the Great Vault reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinGreatVault = v
            end,
        },
        {
            key   = "adventureguide",
            title = "Adventure Guide",
            desc  = "Encounter Journal: instance select, boss details, loot lists, and the bottom nav tabs.",
            reloadMsg = "Changing the Adventure Guide reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinAdventureGuide = v
            end,
        },
        {
            key   = "collections",
            title = "Collections",
            desc  = "Mounts, pets, toys, heirlooms, appearances, and campsites.",
            reloadMsg = "Changing the Collections reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinCollections = v
            end,
        },
        {
            key   = "playerspells",
            title = "Talents & Spellbook",
            desc  = "The Player Spells window: talents, spec selection, and the spellbook.",
            reloadMsg = "Changing the Talents & Spellbook reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinPlayerSpells = v
            end,
        },
        {
            key   = "professionsbook",
            title = "Professions",
            desc  = "The professions overview book with squared icons and flat progress bars.",
            reloadMsg = "Changing the Professions reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinProfessionsBook = v
            end,
        },
        {
            key   = "professions",
            title = "Profession Crafting",
            desc  = "The profession crafting window: recipe list, schematic, specializations, and crafting orders.",
            reloadMsg = "Changing the Profession Crafting reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinProfessions = v
            end,
        },
        {
            key   = "worldmap",
            title = "Map & Quest Log",
            desc  = "The world map window chrome and the quest log side panel.",
            reloadMsg = "Changing the Map & Quest Log reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinWorldMap = v
            end,
        },
        {
            key   = "guild",
            title = "Guild & Communities",
            desc  = "The Guild & Communities window: roster, chat, and the community list.",
            reloadMsg = "Changing the Guild & Communities reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinGuild = v
            end,
        },
        {
            key   = "calendar",
            title = "Calendar",
            desc  = "The monthly calendar grid, event dialogs, and navigation arrows.",
            reloadMsg = "Changing the Calendar reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinCalendar = v
            end,
        },
        {
            key   = "achievements",
            title = "Achievements",
            desc  = "The achievement window: categories, rows, progress bars, and search.",
            reloadMsg = "Changing the Achievements reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinAchievements = v
            end,
        },
        {
            key   = "mail",
            title = "Mail",
            desc  = "The mailbox: inbox rows, send mail, open mail, and attachment slots.",
            reloadMsg = "Changing the Mail reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinMail = v
            end,
            buildContent = BuildMailAltList,
            searchText = { "Show Alt List", "Shown Characters" },
        },
        {
            key   = "catalyst",
            title = "Catalyst",
            desc  = "The item conversion window (catalyst and similar kiosks).",
            reloadMsg = "Changing the Catalyst reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinCatalyst = v
            end,
        },
        {
            key   = "socket",
            title = "Gem Socketing",
            desc  = "The gem socketing window with squared gem slots.",
            reloadMsg = "Changing the Gem Socketing reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinSocket = v
            end,
        },
        {
            key   = "itemupgrade",
            title = "Item Upgrades",
            desc  = "The item upgrade window: upgrade slot, track selector, cost, and the currency strip.",
            reloadMsg = "Changing the Item Upgrades reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinItemUpgrade = v
            end,
        },
        {
            key   = "loot",
            title = "Loot Window",
            desc  = "The loot window: item rows with squared icons, kept item quality colors.",
            reloadMsg = "Changing the Loot Window reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLoot = v
            end,
            buildContent = BuildLootContent,
        },
        {
            key   = "loottoast",
            title = "Loot Toasts",
            desc  = "The \"You received\" popups for loot, currency, and upgrades.",
            reloadMsg = "Changing the Loot Toasts reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLootToast = v
            end,
            buildContent = BuildLootToastContent,
        },
        {
            key   = "bnettoast",
            title = "Friend Notifications",
            desc  = "The Battle.net popup when a friend comes online or goes offline, plus broadcasts and invites.",
            reloadMsg = "Changing the Friend Notifications reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinBNetToast = v
            end,
        },
        {
            key   = "lootroll",
            title = "Loot Roll Popups",
            desc  = "The need / greed / pass roll popups, with a squared icon and a flat roll timer.",
            reloadMsg = "Changing the Loot Roll Popups reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLootRoll = v
            end,
        },
        {
            key   = "loothistory",
            title = "Loot Rolls Window",
            desc  = "The pending-rolls window: encounter picker, roll timer, and the result rows.",
            reloadMsg = "Changing the Loot Rolls Window reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinLootHistory = v
            end,
        },
        {
            key   = "groupinvite",
            title = "Group Invite Popup",
            desc  = "The \"you have been invited to a group\" dialogs, with your role and Accept / Decline.",
            reloadMsg = "Changing the Group Invite Popup reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinGroupInvite = v
            end,
        },
        {
            key   = "readycheck",
            title = "Ready Check",
            desc  = "The ready check prompt with its Yes / No buttons.",
            reloadMsg = "Changing the Ready Check reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinReadyCheck = v
            end,
        },
        {
            key   = "housing",
            title = "Housing Dashboard",
            desc  = "The housing dashboard window background, border, and title bar.",
            reloadMsg = "Changing the Housing Dashboard reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinHousing = v
            end,
        },
        {
            key   = "micromenu",
            title = "Micro Menu",
            desc  = "Flattens the micro menu buttons into the NoxUI style.",
            reloadMsg = "Changing the Micro Menu reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinMicroMenu = v
            end,
        },
        {
            key   = "bagbar",
            title = "Bag Bar",
            desc  = "Flattens the bag bar slot buttons into the NoxUI style.",
            reloadMsg = "Changing the Bag Bar reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinBagBar = v
            end,
        },
        {
            key   = "dressup",
            title = "Dressing Room",
            desc  = "The item preview / transmog dressing room window.",
            reloadMsg = "Changing the Dressing Room reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinDressUp = v
            end,
        },
        {
            key   = "transmog",
            title = "Transmogrifier",
            desc  = "The transmogrification window at the transmogrifier.",
            reloadMsg = "Changing the Transmogrifier reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinTransmog = v
            end,
        },
        {
            key   = "merchant",
            title = "Merchant",
            desc  = "The vendor window: item list, buyback, and bottom money bar.",
            reloadMsg = "Changing the Merchant reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinMerchant = v
            end,
            buildContent = BuildMerchantContent,
        },
        {
            key   = "auctionhouse",
            title = "Auction House",
            desc  = "The auction house: browse, sell, and my auctions views.",
            reloadMsg = "Changing the Auction House reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinAuctionHouse = v
            end,
        },
        {
            key   = "macros",
            title = "Macros",
            desc  = "The macro editor: tabs, icon grid, text well, and buttons.",
            reloadMsg = "Changing the Macros reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinMacros = v
            end,
        },
        {
            key   = "settings",
            title = "Options Panel",
            desc  = "Blizzard's options window chrome: frame, tabs, search, and category rail.",
            reloadMsg = "Changing the Options Panel reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinSettings = v
            end,
        },
        {
            key   = "addonlist",
            title = "AddOn List",
            desc  = "The addon manager: list rows, checkboxes, and buttons.",
            reloadMsg = "Changing the AddOn List reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinAddonList = v
            end,
        },
        {
            key   = "craftorders",
            title = "Crafting Orders",
            desc  = "The customer crafting orders window: browse, order form, and my orders.",
            reloadMsg = "Changing the Crafting Orders reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinCraftOrders = v
            end,
        },
        {
            key   = "trainer",
            title = "Trainer",
            desc  = "The class and profession trainer window: skill list, train button, and cost display.",
            reloadMsg = "Changing the Trainer reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinTrainer = v
            end,
        },
        {
            key   = "stable",
            title = "Pet Stable",
            desc  = "The hunter pet stable: pet model, XP bar, pet slots and the slot purchase row.",
            reloadMsg = "Changing the Pet Stable reskin requires a UI reload to fully swap between Blizzard and NoxUI styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinStable = v
            end,
        },
        {
            key   = "gossip",
            title = "Gossip",
            desc  = "The NPC dialog window: greeting text, gossip and quest options, and goodbye button.",
            reloadMsg = "Changing the Gossip reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinGossip = v
            end,
        },
        {
            key   = "quest",
            title = "Quest",
            desc  = "The NPC quest window: quest detail, progress, and reward panels plus the multi-quest greeting list.",
            reloadMsg = "Changing the Quest reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinQuest = v
            end,
        },
        {
            key   = "inspectrecipe",
            title = "Inspect Recipe",
            desc  = "The recipe preview window shown from a linked recipe or an inspected crafter.",
            reloadMsg = "Changing the Inspect Recipe reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinInspectRecipe = v
            end,
        },
        {
            key   = "delves",
            title = "Delves Companion",
            desc  = "Brann's configuration window: role and trinket slots, abilities, and the ability list.",
            reloadMsg = "Changing the Delves Companion reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinDelves = v
            end,
        },
        {
            key   = "socialui",
            title = "Friends List",
            -- Retail: the Friends List module repaints its window to this card
            -- live. WoW Forever: the card drives that client's friends packs
            -- and hosts the friend tiles and auto-accept the module gives retail.
            desc  = NoxUI.IS_FOREVER
                and "The Social window frame, border, title bar, Battle.net bar, search boxes, filter dropdowns and buttons, and the friend tiles with class icons, class-colored names and region icons. The side tab icons stay untouched."
                or "The friends window backdrop, frame border, tabs, search boxes, bottom buttons and close button. Friend entries stay untouched; Blizz Default keeps the Friends List module's own flat look.",
            reloadMsg = NoxUI.IS_FOREVER
                and "Changing the Friends List reskin requires a UI reload to fully swap between Blizzard and Nox styles."
                or nil,
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinSocialUI = v
            end,
            buildContent = NoxUI.IS_FOREVER and BuildFriendsCardContent or nil,
            searchText = NoxUI.IS_FOREVER and { "Custom Friends List Tiles", "Tile Height", "Tile Features" } or nil,
        },
        {
            key   = "queuestatus",
            title = "Queue Status",
            desc  = "The panel the minimap Group Finder eye shows on hover: queue titles, role icons and counts, and time in queue.",
            reloadMsg = "Changing the Queue Status reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinQueueStatus = v
            end,
        },
        {
            key   = "delvepicker",
            title = "Delve Tier Picker",
            desc  = "The delve difficulty window: tier dropdown, reward list and Enter button. The Map Properties row is left stock -- it is a Blizzard widget display and is not safe to restyle.",
            reloadMsg = "Changing the Delve Tier Picker reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinDelvePicker = v
            end,
        },
        {
            key   = "playerchoice",
            title = "Choice Windows",
            desc  = "Weekly and event choice windows such as Abundance harvests and \"how will you aid...\" pickers: option plates, headers, reward icons and buttons. Option artwork stays.",
            reloadMsg = "Changing the Choice Windows reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinPlayerChoice = v
            end,
        },
        {
            key   = "trade",
            title = "Trade",
            desc  = "The player-to-player trade window: frame, both item columns, the enchant slots, money rows and buttons. Item icons are squared and carry a rarity border. Both portraits are removed, as on every other window.",
            reloadMsg = "Changing the Trade reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinTrade = v
            end,
        },
        {
            key   = "flagcarrier",
            title = "Flag Carriers",
            desc  = "The battleground flag and orb carrier frames, dressed like NoxUI unit frames: health in the carrier's class color and power in its power color inside a thin black border, a square spec icon, a bordered trinket and cast bar, and the carrier's pet. The faction icon and the cast bar's fill stay as Blizzard draws them. To move them, turn on Move Flag Carriers in Unlock Mode on the Quality of Life Shifter page.",
            reloadMsg = "Changing the Flag Carriers reskin requires a UI reload to fully swap between Blizzard and Nox styles.",
            setEnabled = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.reskinFlagCarriers = v
            end,
        },
    }

    -- WoW Forever drops the cards for windows it does not skin or has no use
    -- for: the Delve Tier Picker and Housing Dashboard never load on that
    -- client, and the Great Vault has no content there. Retail drops the Bag
    -- Bar card (a Forever-only skin). Saved enable keys stay untouched.
    if NoxUI.IS_FOREVER then
        local foreverDropped = {
            greatvault = true,
            delvepicker = true, housing = true,
        }
        for i = #WINDOWS, 1, -1 do
            if foreverDropped[WINDOWS[i].key] then table.remove(WINDOWS, i) end
        end
    else
        -- The Bag Bar, Progress Legacy and Pet Stable skins exist only on
        -- Forever; drop their cards on retail.
        for i = #WINDOWS, 1, -1 do
            local key = WINDOWS[i].key
            if key == "bagbar" or key == "legacysystem" or key == "stable" then table.remove(WINDOWS, i) end
        end
    end

    local function WSGetStyle(win)
        return NoxUI.GetBlizzWindowStyle(win.key)
    end

    -- Window skins a module's Style page choice overrides: while that module
    -- renders a stock style its pack stands down, so the card's style
    -- dropdown is blocked and Apply to All leaves the card alone.
    local WS_STYLE_OWNERS = { socialui = "friends" }
    local function WSStyleOwned(win)
        local owner = WS_STYLE_OWNERS[win.key]
        return owner and NoxUI.BlizzStyle and NoxUI.BlizzStyle.Get(owner) or false
    end

    -- Applies a style to one window. Returns true when the change crosses the
    -- on/off boundary, or the character sheet's Blizz Default one (= needs a
    -- reload). suppressPopup lets Apply to All show one popup for the whole
    -- batch instead of one per window.
    local function WSSetStyle(win, style, suppressPopup)
        local old = WSGetStyle(win)
        if old == style then return false end
        if not NoxUIDB then NoxUIDB = {} end
        -- A pick here belongs to the whole UI's current look: the Style
        -- page's Apply to All saves it into that look's window slot when
        -- the look changes (NoxUI.SwapWindowSkinStyle).
        win.setEnabled(style ~= "off")
        if style ~= "off" then
            -- Remember which skin set this window uses; kept while "off" so
            -- re-enabling restores the same pick.
            if not NoxUIDB.blizzWindowSkinStyles then NoxUIDB.blizzWindowSkinStyles = {} end
            NoxUIDB.blizzWindowSkinStyles[win.key] = style
        end
        -- A card with no reloadMsg swaps live both ways (retail Friends List).
        local oldClass = (old == "off" and 0) or (old == "blizzard" and 1) or 2
        local newClass = (style == "off" and 0) or (style == "blizzard" and 1) or 2
        local crossed = win.reloadMsg ~= nil and oldClass ~= newClass
        -- eui<->modern applies live (shell backdrops swap in place).
        if NoxUI._WSkinRefreshStyles then NoxUI._WSkinRefreshStyles() end
        if crossed and not suppressPopup then
            WSReloadPopup(win.reloadMsg)
        end
        return crossed
    end

    -- A card's style as a dropdown row on another page (Action Bars' Menu,
    -- Bags & Rep Bars mirrors the Micro Menu and Bag Bar cards): the card's
    -- own list, read and write, reload popup included, greyed while window
    -- skins are off for the profile. nil for a card this client does not
    -- offer (the Bag Bar off WoW Forever).
    function NoxUI.WindowSkinStyleCfg(winKey, text, tooltip)
        local win
        for i = 1, #WINDOWS do
            if WINDOWS[i].key == winKey then win = WINDOWS[i]; break end
        end
        if not win then return nil end
        return { type = "dropdown", text = text, tooltip = tooltip,
            values = win.styleValues or WS_STYLE_VALUES, order = win.styleOrder or WS_STYLE_ORDER,
            disabled = NoxUI.BlizzWindowSkinsKilled, disabledTooltip = "Window Skins",
            getValue = function() return WSGetStyle(win) end,
            setValue = function(v)
                WSSetStyle(win, v)
                NoxUI:RefreshPage()
            end }
    end

    -- One expandable card: custom header (mini-window glyph + title + style
    -- dropdown + chevron) over a shared card background, with the window's
    -- rows below when expanded. Returns the new y cursor.
    local function BuildWindowCard(parent, y, win)
        local PP = NoxUI.PanelPP
        local EG = NoxUI.NOX_GREEN
        local L  = NoxUI.L
        local hasSettings = win.buildContent ~= nil
        local expanded = hasSettings and _wsExpanded[win.key]
        local cardTop = y
        local brd  -- whole-card border, created with the bg below (hover closure)

        -- Explicit size + single TOPLEFT anchor (the widget contract): inline
        -- search re-anchors and restores direct children through their FIRST
        -- point only, so a frame that gets its width from a second point
        -- collapses to zero width the first time a search is cleared.
        local cardW = parent:GetWidth() - (NoxUI.CONTENT_PAD - WS_CARD_INSET) * 2
        local hdr = CreateFrame("Button", nil, parent)
        PP.Size(hdr, cardW, WS_HEADER_H)
        PP.Point(hdr, "TOPLEFT", parent, "TOPLEFT", NoxUI.CONTENT_PAD - WS_CARD_INSET, y)
        hdr:SetFrameLevel(parent:GetFrameLevel() + 3)

        -- Search metadata: the header acts as its own section, so searching a
        -- window's title or description returns the card (style dropdown and
        -- all) as a result. Deep links are unaffected: they match the exact
        -- section names created inside buildContent, never this joined string.
        -- win.searchText: the labels of a card's own settings (the Mail card's
        -- Alt List), each a locale key, found while the card is closed.
        local extra, extraLoc = "", ""
        if win.searchText then
            for _, label in ipairs(win.searchText) do
                extra = extra .. " " .. label
                extraLoc = extraLoc .. " " .. L(label)
            end
        end
        local searchName = win.title .. " " .. (win.desc or "") .. extra
        hdr._isSectionHeader = true
        hdr._sectionName = searchName
        local searchNameLoc = L(win.title) .. " " .. L(win.desc or "") .. extraLoc
        if searchNameLoc ~= searchName then hdr._sectionNameLoc = searchNameLoc end

        -- Global (sidebar) search: the card header never goes through
        -- SectionHeader, so the index would otherwise have no entry for it --
        -- searching a window's title/description found it inline but not in
        -- the sidebar results. Register it with the same title + description
        -- keywords the inline pseudo-section matches (title as the display
        -- label, description via the tooltip field, which the fuzzy scorer
        -- also searches). section = the exact joined string stamped above, so
        -- a jump scrolls to and glows this header; the page's
        -- NavigateToElementSettings pre-hook expands the cards first.
        if NoxUI._RegisterSearchEntry then
            local titleLoc = L(win.title)
            local descSearch = win.desc or ""
            local descLoc = L(win.desc or "")
            if descLoc ~= descSearch then descSearch = descSearch .. " " .. descLoc end
            descSearch = descSearch .. extra
            if extraLoc ~= extra then descSearch = descSearch .. extraLoc end
            NoxUI._RegisterSearchEntry(win.title,
                titleLoc ~= win.title and titleLoc or nil,
                descSearch,
                NoxUI._buildingModule, NoxUI._buildingPage,
                searchName, nil, nil, true)
        end

        -- The index pass needs only the entry above and the card's rows, which
        -- build as their own job (one card per job, not the whole page at once).
        if NoxUI._prebuilding then
            if hasSettings and NoxUI._QueueIndexBuild then
                win._searchIndexed = true
                NoxUI._searchContext = win.title
                NoxUI._QueueIndexBuild(win.buildContent, y - WS_HEADER_H - 8)
                NoxUI._searchContext = nil
            end
            return y - WS_HEADER_H - WS_CARD_GAP
        end

        -- Hover wash (transparent when idle; the card bg below provides the fill)
        -- The header hover fill sits on the card (built below), inside its corners.
        local hbg

        -- Procedural mini-window glyph: a tiny framed "window" with a title
        -- bar. The bar lights up in accent while the reskin is enabled, but
        -- only on cards that actually have settings.
        local glyph = CreateFrame("Frame", nil, hdr)
        PP.Size(glyph, 22, 16)
        PP.Point(glyph, "LEFT", hdr, "LEFT", 16, 0)
        local glyphBrd = NoxUI.MakeBorder(glyph, 1, 1, 1, 0.35, PP)
        local glyphBar = glyph:CreateTexture(nil, "ARTWORK")
        glyphBar:SetHeight(4)
        PP.Point(glyphBar, "TOPLEFT", glyph, "TOPLEFT", 1, -1)
        PP.Point(glyphBar, "TOPRIGHT", glyph, "TOPRIGHT", -1, -1)
        if glyphBar.SetSnapToPixelGrid then glyphBar:SetSnapToPixelGrid(false); glyphBar:SetTexelSnappingBias(0) end

        local title = NoxUI.MakeFont(hdr, 14, nil, 1, 1, 1, 0.9)
        PP.Point(title, "TOPLEFT", hdr, "TOPLEFT", 50, -12)
        title:SetText(L(win.title))

        local desc = NoxUI.MakeFont(hdr, 11, nil, 1, 1, 1, 0.42)
        PP.Point(desc, "TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetWidth(590)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(false)
        desc:SetText(L(win.desc))

        -- Expand chevron only on cards that actually have settings; cards
        -- without any are not expandable at all.
        local chev
        if hasSettings then
            chev = hdr:CreateTexture(nil, "OVERLAY")
            PP.Size(chev, 16, 16)
            PP.Point(chev, "RIGHT", hdr, "RIGHT", -16, 0)
            chev:SetTexture(expanded and WS_ARROW_UP or WS_ARROW_DOWN)
            chev:SetAlpha(0.45)
            if expanded then chev:SetVertexColor(EG.r, EG.g, EG.b) end
        end

        -- Style dropdown: pick NoxUI / Modern / Blizz Default for this
        -- window without expanding the card (the card's own list, when it
        -- has one).
        local dd = NoxUI.BuildDropdownControl(hdr, 148, hdr:GetFrameLevel() + 2,
            win.styleValues or WS_STYLE_VALUES, win.styleOrder or WS_STYLE_ORDER,
            function() return WSGetStyle(win) end,
            function(v)
                WSSetStyle(win, v)
                NoxUI:RefreshPage()
            end)
        PP.Point(dd, "RIGHT", hdr, "RIGHT", -44, 0)
        local owner = WS_STYLE_OWNERS[win.key]
        if owner and NoxUI.BlizzStyle then NoxUI.BlizzStyle.BlockInline(owner, dd) end

        local strip  -- accent strip on the header's left edge (created with bg)
        local function RefreshCardState()
            local on = WSGetStyle(win) ~= "off"
            glyphBrd:SetColor(1, 1, 1, on and 0.4 or 0.2)
            -- Glyph title bar: accent is reserved for cards that have settings; windows
            -- without any keep a gray bar darker than the glyph border.
            if not hasSettings then
                glyphBar:SetColorTexture(1, 1, 1, 0.12)
            elseif on then
                glyphBar:SetColorTexture(EG.r, EG.g, EG.b, 0.85)
            else
                glyphBar:SetColorTexture(1, 1, 1, 0.2)
            end
            -- Accent edge marks cards that actually have settings; windows
            -- without any keep the faint neutral strip.
            if strip then
                if hasSettings then
                    strip:SetColorTexture(EG.r, EG.g, EG.b, 0.7)
                else
                    strip:SetColorTexture(1, 1, 1, 0.10)
                end
            end
            if dd._refreshLabel then dd._refreshLabel() end
        end

        local function ApplyHeaderHover()
            hbg:SetColorTexture(1, 1, 1, 0.05)
            title:SetAlpha(1)
            chev:SetAlpha(0.85)
            if brd then brd:SetColor(1, 1, 1, 0.22) end
        end
        local function ClearHeaderHover()
            -- Moving between the header and its dropdown fires OnLeave first;
            -- keep the row highlight while the pointer is still inside the header.
            if hdr:IsMouseOver() then return end
            hbg:SetColorTexture(0, 0, 0, 0)
            title:SetAlpha(0.9)
            chev:SetAlpha(0.45)
            if brd then brd:SetColor(1, 1, 1, expanded and 0.16 or 0.12) end
        end
        -- Cards without settings are inert: no hover wash, no click-to-expand.
        -- Their dropdown still works on its own.
        if hasSettings then
            hdr:SetScript("OnEnter", ApplyHeaderHover)
            hdr:SetScript("OnLeave", ClearHeaderHover)
            -- The dropdown keeps its own hover scripts; hook (not replace) so the
            -- full row highlight also holds while the pointer is on the dropdown.
            dd:HookScript("OnEnter", ApplyHeaderHover)
            dd:HookScript("OnLeave", ClearHeaderHover)
            hdr:SetScript("OnClick", function()
                _wsExpanded[win.key] = not _wsExpanded[win.key]
                NoxUI:RefreshPage(true)
            end)
        end

        y = y - WS_HEADER_H

        if expanded then
            -- Divider between the header and the card's settings
            local div = hdr:CreateTexture(nil, "ARTWORK")
            div:SetColorTexture(1, 1, 1, 0.07)
            div:SetHeight(1)
            PP.Point(div, "BOTTOMLEFT", hdr, "BOTTOMLEFT", 1, 0)
            PP.Point(div, "BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -1, 0)
            PP.DisablePixelSnap(div)

            y = y - 8
            NoxUI._searchContext = win.title
            y = win.buildContent(parent, y)
            NoxUI._searchContext = nil
            y = y - 8
        elseif hasSettings then
            -- A closed card's settings stay searchable: queued once a session
            -- from a live build (the pass skips a page already built).
            if NoxUI._QueueIndexBuild and not win._searchIndexed then
                win._searchIndexed = true
                NoxUI._searchContext = win.title
                NoxUI._QueueIndexBuild(win.buildContent, y)
                NoxUI._searchContext = nil
            end
        end

        -- Card background + border spanning the header and any expanded content. Child
        -- of the header, NOT the page wrapper: the inline search walks direct wrapper
        -- children, and as a header child the bg is never collected as a row, follows
        -- the header wherever the search re-flows it, and hides/shows with it for free.
        -- Explicitly sized because the header's own rect is the only anchor left.
        local bg = CreateFrame("Frame", nil, hdr)
        bg:SetFrameLevel(parent:GetFrameLevel())
        PP.Size(bg, cardW, cardTop - y)
        PP.Point(bg, "TOPLEFT", hdr, "TOPLEFT", 0, 0)
        brd = NoxUI.MakeRoundedCard(bg, expanded and 0.16 or 0.12)
        hbg = bg:CreateTexture(nil, "BACKGROUND", nil, 1)
        hbg:SetAllPoints(hdr)
        hbg:SetColorTexture(0, 0, 0, 0)
        brd:Clip(hbg)

        -- Header-height only: the strip marks the header, never the expanded
        -- settings block below it.
        strip = bg:CreateTexture(nil, "ARTWORK")
        brd:Clip(strip)
        strip:SetWidth(2)
        PP.Point(strip, "TOPLEFT", hdr, "TOPLEFT", 1, -1)
        PP.Point(strip, "BOTTOMLEFT", hdr, "BOTTOMLEFT", 1, 1)
        if strip.SetSnapToPixelGrid then strip:SetSnapToPixelGrid(false); strip:SetTexelSnappingBias(0) end

        NoxUI.RegisterWidgetRefresh(RefreshCardState)
        RefreshCardState()

        return y - WS_CARD_GAP
    end

    -- Per-profile master kill switch (the ONLY per-profile setting in this
    -- section): profile-root key disableWindowSkins, resolved live by
    -- NoxUI.BlizzWindowSkinsKilled(). Skins install at load, so every
    -- toggle shows the reload popup.
    local function WSKillSwitchSet(disabled)
        local prof = NoxUI.GetActiveProfileData()
        if not prof then return end
        prof.disableWindowSkins = disabled and true or nil
        -- Structural change (settings <-> hero takeover): force a rebuild,
        -- a plain refresh only re-reads widget values on the cached page.
        NoxUI:RefreshPage(true)
        WSReloadPopup(disabled
            and "Window skins are now disabled for this profile. A UI reload is required to restore the stock Blizzard windows."
            or "Window skins are now enabled for this profile. A UI reload is required to apply them.")
    end

    -- Feature hero shown INSTEAD of the page content while window skins are
    -- disabled for this profile: the intro popup's art (three mini windows,
    -- eyebrow, bullets) rebuilt inline, with one big Enable button.
    local function BuildWindowSkinsDisabledHero(parent, yOffset)
        local PP = NoxUI.PanelPP
        local EG = NoxUI.NOX_GREEN
        local L  = NoxUI.L
        local MakeBorder = NoxUI.MakeBorder
        local FONT = NoxUI._font or "Interface\\AddOns\\NoxUI\\media\\fonts\\Expressway.ttf"

        local HERO_H = 470
        local host = CreateFrame("Frame", nil, parent)
        PP.Size(host, parent:GetWidth() - NoxUI.CONTENT_PAD * 2, HERO_H)
        PP.Point(host, "TOPLEFT", parent, "TOPLEFT", NoxUI.CONTENT_PAD, yOffset - 24)

        -- Three mini Blizzard "windows" with colored title bars (the intro
        -- popup's header visual): center one scaled up with a resize grip.
        local CARD_W, CARD_H, CARD_GAP = 124, 52, 14
        local titleColors = {
            { EG.r, EG.g, EG.b },
            { 0.25, 0.50, 0.90 },
            { 0.64, 0.39, 0.93 },
        }
        for i = 1, 3 do
            local isCenter = (i == 2)
            local w = CARD_W
            local ch = isCenter and (CARD_H + 10) or CARD_H
            local card = CreateFrame("Frame", nil, host)
            card:SetFrameLevel(host:GetFrameLevel() + 1)
            PP.Size(card, w, ch)
            PP.Point(card, "CENTER", host, "TOP", (i - 2) * (CARD_W + CARD_GAP), -64)
            local cbg = card:CreateTexture(nil, "BACKGROUND")
            cbg:SetAllPoints()
            cbg:SetColorTexture(0.121, 0.113, 0.106, 1)
            local c = titleColors[i]
            local bar = card:CreateTexture(nil, "ARTWORK")
            bar:SetColorTexture(c[1], c[2], c[3], isCenter and 0.95 or 0.75)
            bar:SetHeight(8)
            PP.Point(bar, "TOPLEFT", card, "TOPLEFT", 1, -1)
            PP.Point(bar, "TOPRIGHT", card, "TOPRIGHT", -1, -1)
            if bar.SetSnapToPixelGrid then bar:SetSnapToPixelGrid(false); bar:SetTexelSnappingBias(0) end
            local dot = card:CreateTexture(nil, "OVERLAY")
            dot:SetColorTexture(0, 0, 0, 0.4)
            PP.Size(dot, 4, 4)
            PP.Point(dot, "RIGHT", bar, "RIGHT", -3, 0)
            local l1 = card:CreateTexture(nil, "ARTWORK")
            l1:SetColorTexture(1, 1, 1, isCenter and 0.42 or 0.32)
            PP.Size(l1, w - 26, 5)
            PP.Point(l1, "TOPLEFT", card, "TOPLEFT", 13, -18)
            local l2 = card:CreateTexture(nil, "ARTWORK")
            l2:SetColorTexture(1, 1, 1, 0.18)
            PP.Size(l2, w - 46, 5)
            PP.Point(l2, "TOPLEFT", l1, "BOTTOMLEFT", 0, -7)
            if isCenter then
                local l3 = card:CreateTexture(nil, "ARTWORK")
                l3:SetColorTexture(1, 1, 1, 0.14)
                PP.Size(l3, w - 66, 5)
                PP.Point(l3, "TOPLEFT", l2, "BOTTOMLEFT", 0, -7)
                local grip = card:CreateTexture(nil, "OVERLAY")
                grip:SetColorTexture(EG.r, EG.g, EG.b, 0.85)
                PP.Size(grip, 5, 5)
                PP.Point(grip, "BOTTOMRIGHT", card, "BOTTOMRIGHT", -2, 2)
            end
            MakeBorder(card, 1, 1, 1, isCenter and 0.16 or 0.10, PP)
        end

        local eyebrow = host:CreateFontString(nil, "OVERLAY")
        eyebrow:SetFont(FONT, 13, "")
        eyebrow:SetTextColor(EG.r, EG.g, EG.b, 0.9)
        PP.Point(eyebrow, "TOP", host, "TOP", 0, -122)
        eyebrow:SetText(L("NoxUI FEATURE"))

        local title = host:CreateFontString(nil, "OVERLAY")
        title:SetFont(FONT, 25, "")
        title:SetTextColor(1, 1, 1, 1)
        PP.Point(title, "TOP", eyebrow, "BOTTOM", 0, -6)
        title:SetText(L("Blizzard Window Skinning"))

        local desc = host:CreateFontString(nil, "OVERLAY")
        desc:SetFont(FONT, 15, "")
        desc:SetTextColor(1, 1, 1, 0.5)
        desc:SetWidth(430)
        desc:SetJustifyH("CENTER")
        desc:SetWordWrap(true)
        PP.Point(desc, "TOP", title, "BOTTOM", 0, -12)
        desc:SetText(L("Blizzard's windows match the NoxUI theme with a WoW 2.0 Dark Theme, from the Dungeon Journal to the Auction House and beyond."))

        local BULLETS = {
            "Every major Blizzard window themed to match NoxUI",
            "Recolor the theme to any color and opacity you like",
            "Scale any window larger or smaller with Shifter",
        }
        local prev
        for i, text in ipairs(BULLETS) do
            local bl = host:CreateFontString(nil, "OVERLAY")
            bl:SetFont(FONT, 14, "")
            bl:SetTextColor(1, 1, 1, 0.72)
            bl:SetJustifyH("LEFT")
            if i == 1 then
                PP.Point(bl, "TOP", host, "TOP", -20, -252)
                bl:SetPoint("LEFT", host, "CENTER", -160, 0)
            else
                PP.Point(bl, "TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
            end
            bl:SetText(L(text))
            local bdot = host:CreateTexture(nil, "OVERLAY")
            bdot:SetColorTexture(EG.r, EG.g, EG.b, 1)
            PP.Size(bdot, 5, 5)
            PP.Point(bdot, "RIGHT", bl, "LEFT", -10, 0)
            prev = bl
        end

        local enableBtn = CreateFrame("Button", nil, host)
        PP.Size(enableBtn, 220, 40)
        PP.Point(enableBtn, "TOP", host, "TOP", 0, -344)
        enableBtn:SetFrameLevel(host:GetFrameLevel() + 2)
        NoxUI.MakeStyledButton(enableBtn, "Enable Window Skins", 15,
            NoxUI.WB_COLOURS, function() WSKillSwitchSet(false) end)

        local footnote = host:CreateFontString(nil, "OVERLAY")
        footnote:SetFont(FONT, 12, "")
        footnote:SetTextColor(1, 1, 1, 0.35)
        PP.Point(footnote, "TOP", enableBtn, "BOTTOM", 0, -12)
        footnote:SetText(L("Window skins are currently disabled for this profile."))

        -- Builders return the page's total HEIGHT (positive), same as the
        -- normal page's math.abs(y) tail.
        return math.abs(yOffset - 24 - HERO_H)
    end

    ---------------------------------------------------------------------------
    --  THIRD-PARTY ADDONS section: addons that registered for NoxUI skinning
    --  via NoxUI.RegisterSkin (SkinAPI). Deliberately independent of
    --  the per-profile kill switch and of every per-window setting -- window
    --  styles only decide WHICH theme third-party skins get -- so it renders
    --  on both the normal page and the disabled hero. Hidden entirely when
    --  no addon has registered. Skins install at load: turning a toggle ON
    --  applies live when possible, turning OFF is reload-bound.
    ---------------------------------------------------------------------------
    local function BuildThirdPartySection(parent, y)
        local W = NoxUI.Widgets
        local list = ns.GetThirdPartySkinList and ns.GetThirdPartySkinList()
        if not list or #list == 0 then return y end

        local _, h
        _, h = W:Spacer(parent, y, 10); y = y - h
        _, h = W:SectionHeader(parent, "THIRD-PARTY ADDONS", y); y = y - h

        local function MasterOff()
            return (NoxUIDB and NoxUIDB.thirdPartySkinsOff) and true or false
        end
        local function TurnedOn()
            -- Live-apply any skins that can install right now; only removal
            -- needs the reload.
            local fired = ns.TryDispatchThirdPartySkins and ns.TryDispatchThirdPartySkins()
            NoxUI:RefreshPage()
            if not fired then
                WSReloadPopup("Some addon skins could not apply live. A UI reload will fully apply them.")
            end
        end

        local items = {}
        items[1] = { type = "toggle", text = "Skin Third-Party Addons",
            tooltip = "Master switch for skinning other addons that support the NoxUI skinning API.",
            getValue = function() return not MasterOff() end,
            setValue = function(v)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.thirdPartySkinsOff = (not v) and true or nil
                if v then
                    TurnedOn()
                else
                    NoxUI:RefreshPage()
                    WSReloadPopup("Removing third-party addon skins requires a UI reload.")
                end
            end }
        for _, info in ipairs(list) do
            local name = info.name
            items[#items + 1] = { type = "toggle", text = name,
                tooltip = "Skin " .. name .. " to match the NoxUI theme.",
                disabled = MasterOff,
                disabledTooltip = "Enable Skin Third-Party Addons",
                getValue = function()
                    local t = NoxUIDB and NoxUIDB.thirdPartySkinAddons
                    return not (t and t[name] == false)
                end,
                setValue = function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    local t = NoxUIDB.thirdPartySkinAddons
                    if not t then t = {}; NoxUIDB.thirdPartySkinAddons = t end
                    if v then t[name] = nil else t[name] = false end
                    if v then
                        TurnedOn()
                    else
                        WSReloadPopup("Removing " .. name .. "'s skin requires a UI reload.")
                    end
                end }
        end
        local h2
        for i = 1, #items, 2 do
            _, h2 = W:DualRow(parent, y, items[i], items[i + 1] or { type = "label", text = "" })
            y = y - h2
        end
        return y
    end

    local function BuildWindowSkinsPage(pageName, parent, yOffset)
        local W = NoxUI.Widgets
        local PP = NoxUI.PanelPP
        local L  = NoxUI.L
        local y = yOffset
        local _, h

        parent._showRowDivider = true

        -- Per-profile kill switch takeover: while window skins are disabled
        -- for this profile, hide every setting and show the feature hero.
        -- Third-party skinning is decoupled from the kill switch, so its
        -- section stays reachable below the hero.
        if NoxUI.BlizzWindowSkinsKilled and NoxUI.BlizzWindowSkinsKilled() then
            local heroH = BuildWindowSkinsDisabledHero(parent, yOffset)
            local y2 = BuildThirdPartySection(parent, -heroH)
            return math.abs(y2)
        end

        _, h = W:Spacer(parent, y, 14);  y = y - h

        -- Hosted on a sized frame (not a raw region on the wrapper) so the
        -- inline search hides it while filtering and restores it on clear;
        -- regions are invisible to the search and would float over results.
        local introHost = CreateFrame("Frame", nil, parent)
        PP.Size(introHost, parent:GetWidth() - NoxUI.CONTENT_PAD * 2, 20)
        PP.Point(introHost, "TOPLEFT", parent, "TOPLEFT", NoxUI.CONTENT_PAD, y)
        local intro = NoxUI.MakeFont(introHost, 13, nil, 1, 1, 1, 0.5)
        PP.Point(intro, "TOP", introHost, "TOP", 0, 0)
        intro:SetText(L("Pick a style for all reskinned Blizzard windows."))

        -- Per-profile master switch (top right; the only per-profile setting
        -- in this section). One step below Blizz Default: no-ops the whole
        -- window engine + CharacterSheet/Inspect + LFG skinning. Reload-bound.
        local disBtn = CreateFrame("Button", nil, introHost)
        PP.Size(disBtn, 160, 24)
        PP.Point(disBtn, "RIGHT", introHost, "RIGHT", 0, 0)
        disBtn:SetFrameLevel(introHost:GetFrameLevel() + 3)
        NoxUI.MakeStyledButton(disBtn, "Disable Window Skins", 11,
            NoxUI.WB_COLOURS, function() WSKillSwitchSet(true) end)
        disBtn:HookScript("OnEnter", function(s)
            NoxUI.ShowWidgetTooltip(s, L("Turns off ALL window skinning for this profile. Requires a reload."))
        end)
        disBtn:HookScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)

        y = y - 28

        -- Set-all row: pick a style, then push it to every window below. The
        -- swatch + cog edit the GLOBAL Modern background (windows without a
        -- per-window override follow it).
        local allDD = NoxUI.BuildDropdownControl(parent, 170, parent:GetFrameLevel() + 3,
            WS_STYLE_VALUES, WS_STYLE_ORDER,
            function() return _wsApplyAllStyle end,
            function(v)
                _wsApplyAllStyle = v
                NoxUI:RefreshPage()
            end)
        PP.Point(allDD, "TOPLEFT", parent, "TOP", -115, y)
        allDD._ttText = "Style to apply to every window below."
        AttachModernSwatch(parent, allDD, function() return _wsApplyAllStyle ~= "modern" end)

        local applyBtn = CreateFrame("Button", nil, parent)
        PP.Size(applyBtn, 110, 30)
        PP.Point(applyBtn, "LEFT", allDD, "RIGHT", 10, 0)
        applyBtn:SetFrameLevel(parent:GetFrameLevel() + 3)
        NoxUI.MakeStyledButton(applyBtn, "Apply to All", 12, NoxUI.WB_COLOURS, function()
            local crossed = false
            for _, win in ipairs(WINDOWS) do
                local style = (_wsApplyAllStyle == "off" and win.blizzDefault) or _wsApplyAllStyle
                if not WSStyleOwned(win) and WSSetStyle(win, style, true) then crossed = true end
            end
            NoxUI:RefreshPage()
            if crossed then
                WSReloadPopup("Changing window skin styles requires a UI reload to fully apply.")
            end
        end)
        y = y - 30 - 26

        -- GLOBAL OPTIONS: look settings shared by every reskinned window.
        _, h = W:SectionHeader(parent, "GLOBAL OPTIONS", y); y = y - h

        local gRow1
        gRow1, h = W:DualRow(parent, y,
            { type = "toggle", text = "Show Accent Bar",
              tooltip = "Accent bar on the active tab of reskinned windows.",
              getValue = function()
                  local c = WSLook("blizzWinAccentBar")
                  return not (c and c.enabled == false)
              end,
              setValue = function(v)
                  WSLookSet("blizzWinAccentBar", "enabled", v and true or false)
              end },
            { type = "slider", text = "Bar Fill Opacity",
              min = 10, max = 100, step = 1,
              getValue = function()
                  local c = WSLook("blizzWinBarFill")
                  return math.floor(((c and c.alpha) or 0.95) * 100 + 0.5)
              end,
              setValue = function(v) WSLookSet("blizzWinBarFill", "alpha", v / 100) end })
        if not NoxUI._prebuilding then
        AttachLookSwatches(gRow1._leftRegion, gRow1, "blizzWinAccentBar")
        AttachLookSwatches(gRow1._rightRegion, gRow1, "blizzWinBarFill")
        end
        y = y - h

        _, h = W:DualRow(parent, y,
            { type = "multiSwatch", text = "Link Color",
              swatches = {
                  { tooltip = "Accent Color",
                    getValue = function()
                        return NoxUI.ResolveActiveAccent()
                    end,
                    setValue = function() end,
                    onClick = function()
                        WSLookSet("blizzWinLinks", "useCustom", false)
                        NoxUI:RefreshPage()
                    end,
                    refreshAlpha = function()
                        local c = WSLook("blizzWinLinks")
                        return (c and c.useCustom) and 0.3 or 1
                    end },
                  { tooltip = "Custom Color",
                    getValue = function()
                        local c = WSLook("blizzWinLinks")
                        local col = c and c.color
                        if col then return col.r or 1, col.g or 1, col.b or 1 end
                        return 1, 1, 1
                    end,
                    setValue = function(r, g, b)
                        WSLookSet("blizzWinLinks", "color", { r = r, g = g, b = b })
                        WSLookSet("blizzWinLinks", "useCustom", true)
                        NoxUI:RefreshPage()
                    end,
                    onClick = function(self)
                        local c = WSLook("blizzWinLinks")
                        if not (c and c.useCustom) then
                            WSLookSet("blizzWinLinks", "useCustom", true)
                            NoxUI:RefreshPage()
                            return
                        end
                        if self._eabOrigClick then self._eabOrigClick(self) end
                    end,
                    refreshAlpha = function()
                        local c = WSLook("blizzWinLinks")
                        return (c and c.useCustom) and 1 or 0.3
                    end },
              } },
            { type = "label", text = "" })
        y = y - h

        -- Breathing room between the global settings and the window cards.
        y = y - 30

        -- Cards with their own settings content (buildContent) sit at the top of the
        -- list, keeping their relative order; plain style-only cards follow in theirs.
        -- WINDOWS itself stays in its defined order -- the apply-all and reset loops
        -- don't care, and new entries keep being added by category there.
        local ordered = {}
        for _, win in ipairs(WINDOWS) do
            if win.buildContent then ordered[#ordered + 1] = win end
        end
        for _, win in ipairs(WINDOWS) do
            if not win.buildContent then ordered[#ordered + 1] = win end
        end
        for _, win in ipairs(ordered) do
            y = BuildWindowCard(parent, y, win)
        end

        y = BuildThirdPartySection(parent, y)

        _, h = W:Spacer(parent, y, 20);  y = y - h
        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Dragon Riding page
    ---------------------------------------------------------------------------
    local function EDR_DB()
        return ns.edrDB and ns.edrDB.profile
    end
    local function EDR_Cfg(k) local p = EDR_DB(); return p and p[k] end
    local function EDR_Set(k, v) local p = EDR_DB(); if p then p[k] = v end end
    local function EDR_SetField(k, field, v)
        local t = EDR_Cfg(k); if t then t[field] = v end
    end
    local function EDR_Rebuild() if ns.edrRebuild then ns.edrRebuild() end
        NoxUI:RefreshPage()
    end
    local function EDR_Redraw() if ns.edrRedraw then ns.edrRedraw() end end

    -------------------------------------------------------------------
    --  Bar texture dropdown tables (shared media path, same as ERB)
    -------------------------------------------------------------------
    local EDR_BAR_TEXTURES = ns.EDR_BAR_TEXTURES
    local _, EDR_BAR_TEXTURE_NAMES, EDR_BAR_TEXTURE_ORDER =
        NoxUI.BuildBarTextureTables()

    -- Live sample bubble in the content header; sized to the bubble plus margin.
    local function ChatBubblesHeaderBuilder(header)
        local building = true
        local function HeightFor(bubbleH) return math.max(80, math.floor(bubbleH + 40)) end
        local bubble = NoxUI.ChatBubbles.ShowPreview(header, function(bubbleH)
            local want = HeightFor(bubbleH)
            if not building and header:IsVisible() and math.abs(header:GetHeight() - want) > 1 then
                NoxUI:SetContentHeaderHeightSilent(want)
            end
        end)
        building = false
        return HeightFor(bubble:GetHeight())
    end

    -- Sample Skyriding HUD in the content header, painted by the HUD's own
    -- passes (ns.EDR_ShowSample).
    local SkyridingHeaderBuilder = SampleHeaderBuilder({ { show = function(header, place)
        if ns.EDR_ShowSample then ns.EDR_ShowSample(header, place) end
    end } })

    local function BuildChatBubblesPage(pageName, parent, yOffset)
        local W  = NoxUI.Widgets
        local PP = NoxUI.PanelPP
        local y  = yOffset
        local _, h

        parent._showRowDivider = true
        if not NoxUI._prebuilding then
            NoxUI:SetContentHeader(ChatBubblesHeaderBuilder)
        elseif NoxUI.ClearContentHeader then
            NoxUI:ClearContentHeader()
        end


        local CBM = NoxUI.ChatBubbles
        -- Reads never create the profile table; writes do.
        local function BBDB() return CBM.DB(true) end
        -- Same defaults table the renderer reads, so a widget can never offer a value the
        -- bubble would not actually draw.
        local function CBVal(key)
            local db = CBM.DB(false)
            local v = db and db[key]
            if v ~= nil then return v end
            return CBM.Defaults()[key]
        end
        -- Structural write: can change whether we draw at all, or which of Blizzard's
        -- CVars we hold down, so it runs the renderer's full pass.
        local function CBSet(key, v)
            local db = BBDB()
            if not db then return end
            db[key] = v
            CBM.Refresh()
        end
        -- Appearance write: nothing here can move a channel or one of Blizzard's CVars, so
        -- it only re-styles what is already on screen. Worth the split because a slider
        -- fires this per STEP while it is dragged, and the full pass re-diffs every event
        -- registration and round-trips Blizzard's three switches every time.
        local function CBSetStyle(key, v)
            local db = BBDB()
            if not db then return end
            db[key] = v
            CBM.RefreshStyle()
        end
        local function CBColor(key)
            local c = CBVal(key)
            if not c then return 1, 1, 1, 1 end
            return c.r, c.g, c.b, c.a or 1
        end
        local function Off() return CBVal("enabled") ~= true end
        local GATE = "Enable Chat Bubbles Customization"
        -- The toggle's own label reads as an instruction; DisabledTooltip wraps whatever it
        -- is handed in "This option requires %1$s to be enabled", which needs a plain noun.
        local GATE_REQ = "Chat Bubbles"

        -- Red warning banner: NOT a section header for what follows -- our own bubbles
        -- never show inside instances, unconditionally, and that has to be visible before
        -- the player reads any option below it, not styled as their category label.
        -- Skipped while the search index prebuilds the page off screen: the banner carries
        -- no setting to index and parent:GetWidth() is not meaningful there. The height
        -- still comes off y in both passes, so everything below lands identically.
        if not NoxUI._prebuilding then
            local warnFrame = CreateFrame("Frame", nil, parent)
            PP.Size(warnFrame, parent:GetWidth() - NoxUI.CONTENT_PAD * 2, 30)
            PP.Point(warnFrame, "TOPLEFT", parent, "TOPLEFT", NoxUI.CONTENT_PAD, y)
            local warnFS = NoxUI.MakeFont(warnFrame, 14, "", 1, 0.25, 0.25, 1)
            warnFS:SetPoint("LEFT", warnFrame, "LEFT", 0, 0)
            warnFS:SetText(NoxUI.L("Only works outside of Instances"))
        end
        y = y - 30

        _, h = W:SectionHeader(parent, "DISPLAY", y);  y = y - h

        local channelsRow
        channelsRow, h = W:DualRow(parent, y,
            { type="toggle", text=GATE,
              getValue=function() return CBVal("enabled") == true end,
              setValue=function(v)
                if not v then
                    CBSet("enabled", false)
                    NoxUI:RefreshPage()
                    return
                end
                local message = "NoxUI restyles Blizzard's chat bubbles and turns on the switches it needs. Party and Raid keep your current setting, and everything is put back when you turn this off."
                NoxUI:ShowConfirmPopup({
                    title = GATE,
                    message = message,
                    confirmText = "Enable",
                    cancelText = "Cancel",
                    onConfirm = function()
                        CBSet("enabled", true)
                        NoxUI:RefreshPage()
                    end,
                    onCancel = function() NoxUI:RefreshPage() end,
                })
              end },
            { type="dropdown", text="Channels",
              tooltip="Choose which channels get a bubble.",
              disabled = Off, disabledTooltip = GATE_REQ,
              values={ __placeholder = "..." }, order={ "__placeholder" },
              getValue=function() return "__placeholder" end,
              setValue=function() end });  y = y - h

        if not NoxUI._prebuilding then
            local rgn = channelsRow._rightRegion
            if rgn._control then rgn._control:Hide() end
            local channelItems = {
                { key="say",   label="Say" },
                { key="yell",  label="Yell" },
                { key="party", label="Party", tooltip="Includes instance chat." },
                { key="raid",  label="Raid" },
                { key="npc",   label="NPCs" },
                { key="emote", label="Emotes" },
            }
            local chDD, chDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                rgn, 240, rgn:GetFrameLevel() + 2,
                channelItems,
                function(k) return CBVal(k) == true end,
                function(k, v) CBSet(k, v) end,
                nil, nil, nil, nil, nil, { disabled = Off, disabledTooltip = GATE_REQ })
            NoxUI.PanelPP.Point(chDD, "RIGHT", rgn, "RIGHT", -20, 0)
            rgn._control = chDD
            rgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(chDDRefresh)
        end

        -- Structural, not appearance: it decides which of Blizzard's switches we hold and at
        -- what value, so it takes the full pass. Half-empty right slot is allowed here because
        -- this is the last row of its section.
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Hide Chat Bubbles in Instances",
              getValue=function() return CBVal("hideInInstances") == true end,
              setValue=function(v) CBSet("hideInInstances", v) end,
              disabled = Off, disabledTooltip = GATE_REQ },
            { type="label", text="" });  y = y - h

        _, h = W:SectionHeader(parent, "APPEARANCE", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Padding", min=2, max=24, step=1,
              tooltip="Space between the text and the edge of the bubble.",
              getValue=function() return CBVal("padding") end,
              setValue=function(v) CBSetStyle("padding", v) end,
              disabled = Off, disabledTooltip = GATE_REQ },
            { type="slider", text="Maximum Width", min=120, max=500, step=10,
              getValue=function() return CBVal("maxWidth") end,
              setValue=function(v) CBSetStyle("maxWidth", v) end,
              disabled = Off, disabledTooltip = GATE_REQ });  y = y - h

        local fontValues, fontOrder = NoxUI.BuildFontDropdownData()
        local fontBorderRow
        fontBorderRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Font",
              values=fontValues, order=fontOrder,
              getValue=function() return CBVal("font") end,
              setValue=function(v) CBSetStyle("font", v) end,
              disabled = Off, disabledTooltip = GATE_REQ },
            { type="slider", text="Border", min=0, max=4, step=1,
              getValue=function() return CBVal("borderSize") end,
              setValue=function(v) CBSetStyle("borderSize", v) end,
              disabled = Off, disabledTooltip = GATE_REQ });  y = y - h

        do
            -- Built BEFORE the swatch on purpose: the cog sits beside the control, and
            -- BuildInlineSwatches chains _lastInline, so the swatch lands to its left.
            NoxUI.BuildInlineCog(fontBorderRow._leftRegion, {
                disabled = Off,
                disabledTooltip = GATE_REQ,
                title = "Font",
                rows = {
                    { type = "slider", label = "Font Size", min = 8, max = 24, step = 1,
                      get = function() return CBVal("fontSize") end,
                      set = function(v) CBSetStyle("fontSize", v) end },
                    { type = "dropdown", label = "Outline",
                      values = { __global = "NoxUI Global Outline", none = "Drop Shadow",
                                 outline = "Outline", thick = "Thick Outline" },
                      order = { "__global", "none", "outline", "thick" },
                      get = function() return CBVal("outline") end,
                      set = function(v) CBSetStyle("outline", v) end },
                    { type = "toggle", label = "Follow Blizzard Default Color",
                      get = function() return CBVal("followBlizzardColor") == true end,
                      set = function(v)
                          CBSetStyle("followBlizzardColor", v)
                          NoxUI:RefreshPage()
                      end },
                },
            })
        end
        if not NoxUI._prebuilding then
            -- BuildInlineSwatches, not a hand-rolled BuildColorSwatch: it is the house form for
            -- a swatch riding on a control half. It anchors through PP.Point, registers the
            -- swatch's refresh so a profile switch repaints it, and builds the greyed-out block
            -- plus tooltip from opts.disabled.
            NoxUI.BuildInlineSwatches(fontBorderRow._leftRegion, {
                { getValue = function() local r, g, b = CBColor("textColor"); return r, g, b, 1 end,
                  setValue = function(r, g, b) CBSetStyle("textColor", { r=r, g=g, b=b }) end,
                  -- Two reasons this swatch can be dead, so the tip is resolved per reason.
                  disabled = function() return Off() or CBVal("followBlizzardColor") == true end,
                  disabledTooltip = function()
                      return Off() and GATE_REQ or "Follow Blizzard Default Color"
                  end,
                  requireState = function() return Off() and "enabled" or "disabled" end },
            }, { disabled = Off, disabledTooltip = GATE_REQ })

            NoxUI.BuildInlineSwatches(fontBorderRow._rightRegion, {
                { getValue = function() return CBColor("borderColor") end,
                  setValue = function(r, g, b, a) CBSetStyle("borderColor", { r=r, g=g, b=b, a=a }) end,
                  hasAlpha = true },
            }, { disabled = Off, disabledTooltip = GATE_REQ })
        end

        local nameRow
        nameRow, h = W:DualRow(parent, y,
            { type="dropdown", text="Show Speaker Name",
              tooltip="Choose which channels show the speaker.",
              disabled = Off, disabledTooltip = GATE_REQ,
              values={ __placeholder = "..." }, order={ "__placeholder" },
              getValue=function() return "__placeholder" end,
              setValue=function() end },
            { type="slider", text="Vertical Offset", min=-80, max=80, step=2,
              getValue=function() return CBVal("offsetY") end,
              setValue=function(v) CBSetStyle("offsetY", v) end,
              disabled = Off, disabledTooltip = GATE_REQ });  y = y - h

        -- Same build as the Channels dropdown above.
        do
            local rgn = nameRow._leftRegion
            if not NoxUI._prebuilding then
                if rgn._control then rgn._control:Hide() end
                local nameItems = {
                    { key="say",   label="Say" },
                    { key="yell",  label="Yell" },
                    { key="party", label="Party" },
                    { key="raid",  label="Raid" },
                    { key="npc",   label="NPCs" },
                    { key="emote", label="Emotes" },
                }
                local nmDD, nmDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                    rgn, 240, rgn:GetFrameLevel() + 2,
                    nameItems,
                    function(k)
                        local t = CBVal("showName")
                        return type(t) == "table" and t[k] == true
                    end,
                    function(k, v)
                        local db = BBDB(); if not db then return end
                        if type(db.showName) ~= "table" then db.showName = {} end
                        db.showName[k] = v or nil
                        CBM.RefreshStyle()
                    end,
                    nil, nil, nil, nil, nil, { disabled = Off, disabledTooltip = GATE_REQ })
                NoxUI.PanelPP.Point(nmDD, "RIGHT", rgn, "RIGHT", -20, 0)
                rgn._control = nmDD
                rgn._lastInline = nil
                NoxUI.RegisterWidgetRefresh(nmDDRefresh)
            end

            NoxUI.BuildInlineCog(rgn, {
                disabled = Off,
                disabledTooltip = GATE_REQ,
                title = "Speaker Name",
                rows = {
                    { type = "dropdown", label = "Anchor",
                      values = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
                                 BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right" },
                      order = { "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
                      get = function() return CBVal("nameAnchor") end,
                      set = function(v) CBSetStyle("nameAnchor", v) end },
                    { type = "slider", label = "Font Size", min = 6, max = 24, step = 1,
                      get = function() return CBVal("nameFontSize") end,
                      set = function(v) CBSetStyle("nameFontSize", v) end },
                    { type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
                      get = function() return CBVal("nameOffsetX") end,
                      set = function(v) CBSetStyle("nameOffsetX", v) end },
                    { type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
                      get = function() return CBVal("nameOffsetY") end,
                      set = function(v) CBSetStyle("nameOffsetY", v) end },
                },
            })
        end

        -- Last row of the section, so the empty right slot is allowed.
        local bgRow
        bgRow, h = W:DualRow(parent, y,
            { type="toggle", text="Background",
              getValue=function() return CBVal("background") ~= false end,
              setValue=function(v) CBSetStyle("background", v); NoxUI:RefreshPage() end,
              disabled = Off, disabledTooltip = GATE_REQ },
            { type="label", text="" });  y = y - h

        -- Colour and opacity are one swatch but two stored keys, so the write goes straight
        -- to the DB rather than through CBSetStyle.
        if not NoxUI._prebuilding then
            NoxUI.BuildInlineSwatches(bgRow._leftRegion, {
                { getValue = function()
                      local r, g, b = CBColor("bgColor")
                      return r, g, b, CBVal("bgAlpha")
                  end,
                  setValue = function(r, g, b, a)
                      local db = BBDB(); if not db then return end
                      db.bgColor = { r=r, g=g, b=b }
                      db.bgAlpha = a
                      CBM.RefreshStyle()
                  end,
                  hasAlpha = true,
                  disabled = function() return Off() or CBVal("background") == false end,
                  disabledTooltip = function() return Off() and GATE_REQ or "Background" end },
            })
        end

        return math.abs(y)
    end

    local function BuildDragonRidingPage(pageName, parent, yOffset)
        local W = NoxUI.Widgets
        local y = yOffset
        local _, h

        parent._showRowDivider = true

        -- Append SharedMedia textures (safe to call multiple times)
        NoxUI.AppendSharedMediaTextures(
            EDR_BAR_TEXTURE_NAMES,
            EDR_BAR_TEXTURE_ORDER,
            nil,
            EDR_BAR_TEXTURES
        )
        local edrTexValues = {}
        local edrTexOrder  = {}
        for _, key in ipairs(EDR_BAR_TEXTURE_ORDER) do
            if key ~= "---" then
                edrTexValues[key] = EDR_BAR_TEXTURE_NAMES[key] or key
                edrTexOrder[#edrTexOrder + 1] = key
            end
        end
        edrTexValues._menuOpts = {
            itemHeight = 28,
            background = function(key) return EDR_BAR_TEXTURES[key] end,
        }

        local justifyValues = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
        local justifyOrder  = { "LEFT", "CENTER", "RIGHT" }

        -- The bar art is chosen on Global Settings > Style ("Skyriding HUD")
        -- and latched for the session like every other module's style, so
        -- the rows below are laid out for the look the HUD renders.
        local BS = NoxUI.BlizzStyle
        local edrStyle = BS.Active("dragonriding")

        -- The sample HUD heads the page while the bar is on; off, the page
        -- hides everything below its first row and shows no header either.
        if not NoxUI._prebuilding and EDR_Cfg("enabled") == true then
            NoxUI:SetContentHeader(SkyridingHeaderBuilder)
        elseif NoxUI.ClearContentHeader then
            NoxUI:ClearContentHeader()
        end

        -- The Move in Unlock Mode button on the bar's first section, built
        -- whatever Enable Skyriding Bar says: its disabled state explains itself.
        local hdr
        hdr, h = W:SectionHeader(parent, "GENERAL", y); y = y - h
        NoxUI.BuildSectionUnlockJump(hdr, { key = "EDR_Cluster",
            disabled = function() return EDR_Cfg("enabled") ~= true end,
            disabledTooltip = "Skyriding Bar" })
        y = BS.Note(parent, y, "dragonriding")
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Enable Skyriding Bar",
              getValue = function() return EDR_Cfg("enabled") == true end,
              -- DependentSetValue: everything below Row 1 is hidden while the
              -- bar is off; the flip forces the full rebuild.
              setValue = NoxUI.DependentSetValue(
                  function() return EDR_Cfg("enabled") == true end,
                  function(v) EDR_Set("enabled", v); EDR_Rebuild() end) },
            { type = "toggle", text = "Hide in Combat",
              disabled = function() return EDR_Cfg("enabled") ~= true end,
              disabledTooltip = "Skyriding Bar",
              getValue = function() return EDR_Cfg("hideInCombat") == true end,
              setValue = function(v) EDR_Set("hideInCombat", v); EDR_Rebuild() end }
        ); y = y - h

        -- Everything below Row 1 (the rest of GENERAL plus the LAYOUT and
        -- SPEED BAR sections) is HIDDEN entirely while the bar is off.
        if EDR_Cfg("enabled") == true then
        local function EDR_IsGems() return EDR_Cfg("vigorStyle") == "gems" end
        local function EDR_ShowSpeed() return EDR_Cfg("showSpeed") ~= false end
        local function EDR_ShowSW() return EDR_Cfg("showSecondWind") ~= false end
        local function EDR_WSOff() return EDR_Cfg("showWhirlingSurge") == false end
        -- The icon's automatic size, in the Icon Size slider's range.
        local function EDR_AutoIconSize()
            local v = math.floor(((ns.edrIconSize and ns.edrIconSize()) or 34) + 0.5)
            return math.max(16, math.min(80, v))
        end

        -- The parts the HUD shows. The speed bar's and Second Wind's own
        -- rows exist only while they are shown, so those two rebuild the page.
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = "Show Speed Bar",
              getValue = EDR_ShowSpeed,
              setValue = NoxUI.DependentSetValue(EDR_ShowSpeed,
                  function(v) EDR_Set("showSpeed", v); EDR_Rebuild() end) },
            { type = "toggle", text = "Show Second Wind",
              getValue = EDR_ShowSW,
              setValue = NoxUI.DependentSetValue(EDR_ShowSW,
                  function(v) EDR_Set("showSecondWind", v); EDR_Rebuild() end) }
        ); y = y - h
        local wsRow
        wsRow, h = W:DualRow(parent, y,
            { type = "toggle", text = "Show Whirling Surge",
              getValue = function() return not EDR_WSOff() end,
              setValue = function(v) EDR_Set("showWhirlingSurge", v); EDR_Rebuild() end },
            { type = "toggle", text = "Show Icon Cooldown Text",
              disabled = EDR_WSOff, disabledTooltip = "Show Whirling Surge",
              getValue = function() return EDR_Cfg("whirlingSurgeText") and EDR_Cfg("whirlingSurgeText").enabled ~= false end,
              setValue = function(v) EDR_SetField("whirlingSurgeText", "enabled", v); EDR_Redraw() end }
        ); y = y - h
        -- Icon size: automatic (as tall as the bars) while Auto Size is on;
        -- turning it off hands the slider the current automatic size.
        do
            NoxUI.BuildInlineCog(wsRow._leftRegion, {
                title = "Whirling Surge Icon",
                disabled = EDR_WSOff, disabledTooltip = "Show Whirling Surge",
                rows = {
                    { type = "toggle", label = "Auto Size",
                      tooltip = "Keeps the icon as tall as the bars.",
                      get = function() return EDR_Cfg("iconSize") == nil end,
                      set = function(v)
                          if v then
                              EDR_Set("iconSize", nil)
                          else
                              EDR_Set("iconSize", EDR_AutoIconSize())
                          end
                          EDR_Rebuild()
                      end },
                    { type = "slider", label = "Icon Size", min = 16, max = 80, step = 1,
                      disabled = function() return EDR_Cfg("iconSize") == nil end,
                      disabledTooltip = "Auto Size", requireState = "disabled",
                      get = function() return EDR_Cfg("iconSize") or EDR_AutoIconSize() end,
                      set = function(v) EDR_Set("iconSize", v); EDR_Rebuild() end },
                },
            })
        end
        -- Classic Gems replaces the charge row with Blizzard's original gems
        -- (the page rebuilds: the Charge row and the gem scale follow it).
        -- The cog holds the full-charge chime and, for the gems, their scale.
        local vigorRow
        vigorRow, h = W:DualRow(parent, y,
            { type = "dropdown", text = "Vigor Style",
              values = { bars = "Bars", gems = "Classic Gems" },
              order  = { "bars", "gems" },
              tooltip = "Classic Gems brings back Blizzard's original vigor display above the bars.",
              getValue = function() return EDR_Cfg("vigorStyle") or "bars" end,
              setValue = NoxUI.DependentSetValue(EDR_IsGems,
                  function(v) EDR_Set("vigorStyle", v); EDR_Rebuild() end) },
            { type = "slider", pixel = true, text = "Stack Spacing", min = 0, max = 10, step = 1,
              -- The gap between pips: nothing to space with no pip row shown.
              disabled = function() return EDR_IsGems() and not EDR_ShowSW() end,
              disabledTooltip = "This option requires the Bars vigor style or Show Second Wind",
              getValue = function() return EDR_Cfg("stackSpacing") end,
              setValue = function(v) EDR_Set("stackSpacing", v); EDR_Rebuild() end }
        ); y = y - h
        do
            local vigorRows = {
                { type = "toggle", label = "Play Sound on Full Charge",
                  tooltip = "Plays Blizzard's vigor chime each time a skyriding charge fills.",
                  get = function() return EDR_Cfg("chargeSound") == true end,
                  set = function(v) EDR_Set("chargeSound", v) end },
            }
            if EDR_IsGems() then
                vigorRows[2] = { type = "slider", label = "Gem Scale", min = 0.5, max = 2.0, step = 0.05,
                    get = function() return EDR_Cfg("classicScale") or 1 end,
                    set = function(v) EDR_Set("classicScale", v); EDR_Rebuild() end }
            end
            NoxUI.BuildInlineCog(vigorRow._leftRegion, { title = "Vigor", rows = vigorRows })
        end
        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Width", min = 80, max = 600, step = 1,
              getValue = function() return EDR_Cfg("width") end,
              setValue = function(v) EDR_Set("width", v); EDR_Rebuild() end },
            { type = "slider", pixel = true, text = "Element Spacing", min = 0, max = 12, step = 1,
              getValue = function() return EDR_Cfg("gap") end,
              setValue = function(v) EDR_Set("gap", v); EDR_Rebuild() end }
        ); y = y - h
        -- Border Size: the NoxUI border and its colour on the
        -- NoxUI look; under Classic WoW UI the slot sizes the vanilla
        -- frame, as the Resource Bars' Border Size does; Blizzard Style's
        -- panel has no size to set.
        local borderCfg
        if edrStyle == "classic" then
            borderCfg = BS.ClassicBorderSizeCfg(
                function() return EDR_Cfg("classicFrameSize") end,
                function(v) EDR_Set("classicFrameSize", v); EDR_Rebuild() end)
        else
            borderCfg = BS.Gate("dragonriding",
                { type = "slider", text = "Border Size", min = 0, max = 4, step = 1,
                  getValue = function() return EDR_Cfg("borderThickness") or 0 end,
                  setValue = function(v)
                      EDR_Set("borderThickness", v); EDR_Redraw()
                      NoxUI:RefreshPage()
                  end })
        end
        local borderRow
        borderRow, h = W:DualRow(parent, y, borderCfg,
            { type = "dropdown", text = "Bar Texture",
              values = edrTexValues, order = edrTexOrder,
              getValue = function() return EDR_Cfg("barTexture") or "none" end,
              setValue = function(v) EDR_Set("barTexture", v); EDR_Redraw() end }
        ); y = y - h
        if not NoxUI._prebuilding and edrStyle == "eui" then
            local rgn = borderRow._leftRegion
            local ctrl = rgn._control
            local swatch, updateSwatch = NoxUI.BuildColorSwatch(
                rgn, borderRow:GetFrameLevel() + 3,
                function() local t = EDR_Cfg("borderColor"); return t.r, t.g, t.b, t.a end,
                function(r, g, b, a) local p = EDR_Cfg("borderColor"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                true, 20)
            NoxUI.PanelPP.Point(swatch, "RIGHT", ctrl, "LEFT", -8, 0)
            rgn._lastInline = swatch
            -- No border to colour at size 0: dimmed and blocked.
            local block = CreateFrame("Frame", nil, swatch)
            block:SetAllPoints()
            block:SetFrameLevel(swatch:GetFrameLevel() + 10)
            block:EnableMouse(true)
            block:SetScript("OnEnter", function()
                NoxUI.ShowWidgetTooltip(swatch, NoxUI.DisabledTooltip("This option requires a Border Size above 0."))
            end)
            block:SetScript("OnLeave", function() NoxUI.HideWidgetTooltip() end)
            local function UpdateSwatchState()
                if (EDR_Cfg("borderThickness") or 0) == 0 then
                    swatch:SetAlpha(0.3); block:Show()
                else
                    swatch:SetAlpha(1); block:Hide()
                end
            end
            NoxUI.RegisterWidgetRefresh(function() updateSwatch(); UpdateSwatchState() end)
            UpdateSwatchState()
        end
        _, h = W:Spacer(parent, y, 20); y = y - h

        -- Charge and Second Wind rows, each only while its part is shown
        -- (Classic Gems replaces the charge row); no section without either.
        local showCharges, showSW = not EDR_IsGems(), EDR_ShowSW()
        if showCharges or showSW then
            _, h = W:SectionHeader(parent, "LAYOUT", y); y = y - h
            if showCharges then
                _, h = W:DualRow(parent, y,
                    { type = "slider", text = "Charge Height", min = 2, max = 24, step = 1,
                      getValue = function() return EDR_Cfg("skyridingHeight") end,
                      setValue = function(v) EDR_Set("skyridingHeight", v); EDR_Rebuild() end },
                    { type = "multiSwatch", text = "Charge Color",
                      swatches = {
                        { text = "Background",
                          getValue = function() local t = EDR_Cfg("skyridingBg"); return t.r, t.g, t.b, t.a end,
                          setValue = function(r, g, b, a) local p = EDR_Cfg("skyridingBg"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                          hasAlpha = true,
                          tooltip = "Background" },
                        { text = "Stacks",
                          getValue = function() local t = EDR_Cfg("skyridingFilled"); return t.r, t.g, t.b, t.a end,
                          setValue = function(r, g, b, a) local p = EDR_Cfg("skyridingFilled"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                          hasAlpha = true,
                          tooltip = "Charges" },
                      } }
                ); y = y - h
            end
            if showSW then
                _, h = W:DualRow(parent, y,
                    { type = "slider", text = "Second Wind Height", min = 2, max = 24, step = 1,
                      getValue = function() return EDR_Cfg("secondWindHeight") end,
                      setValue = function(v) EDR_Set("secondWindHeight", v); EDR_Rebuild() end },
                    { type = "multiSwatch", text = "Second Wind Color",
                      swatches = {
                        { text = "Background",
                          getValue = function() local t = EDR_Cfg("secondWindBg"); return t.r, t.g, t.b, t.a end,
                          setValue = function(r, g, b, a) local p = EDR_Cfg("secondWindBg"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                          hasAlpha = true,
                          tooltip = "Background" },
                        { text = "Second Wind",
                          getValue = function() local t = EDR_Cfg("secondWindFilled"); return t.r, t.g, t.b, t.a end,
                          setValue = function(r, g, b, a) local p = EDR_Cfg("secondWindFilled"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                          hasAlpha = true,
                          tooltip = "Second Wind" },
                      } }
                ); y = y - h
            end
            _, h = W:Spacer(parent, y, 20); y = y - h
        end

        -- The speed bar's own section only while the bar is shown.
        if EDR_ShowSpeed() then
        _, h = W:SectionHeader(parent, "SPEED BAR", y); y = y - h
        _, h = W:DualRow(parent, y,
            { type = "slider", text = "Height", min = 4, max = 40, step = 1,
              getValue = function() return EDR_Cfg("speedHeight") end,
              setValue = function(v) EDR_Set("speedHeight", v); EDR_Rebuild() end },
            { type = "toggle", text = "Thrill Color Change",
              getValue = function() return EDR_Cfg("thrillColorToggle") == true end,
              setValue = function(v) EDR_Set("thrillColorToggle", v); EDR_Redraw() end }
        ); y = y - h
        _, h = W:DualRow(parent, y,
            { type = "multiSwatch", text = "Speed Color",
              swatches = {
                { text = "Background",
                  getValue = function() local t = EDR_Cfg("speedBarBg"); return t.r, t.g, t.b, t.a end,
                  setValue = function(r, g, b, a) local p = EDR_Cfg("speedBarBg"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                  hasAlpha = true,
                  tooltip = "Background" },
                { text = "Speed",
                  getValue = function() local t = EDR_Cfg("normalColor"); return t.r, t.g, t.b, t.a end,
                  setValue = function(r, g, b, a) local p = EDR_Cfg("normalColor"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                  hasAlpha = true,
                  tooltip = "Speed" },
              } },
            { type = "multiSwatch", text = "Thrill Color",
              swatches = {
                { text = "Hash",
                  getValue = function() local t = EDR_Cfg("tickColor"); return t.r, t.g, t.b, t.a end,
                  setValue = function(r, g, b, a) local p = EDR_Cfg("tickColor"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                  hasAlpha = true,
                  tooltip = "Hash Marker" },
                { text = "Thrill",
                  getValue = function() local t = EDR_Cfg("thrillColor"); return t.r, t.g, t.b, t.a end,
                  setValue = function(r, g, b, a) local p = EDR_Cfg("thrillColor"); p.r, p.g, p.b, p.a = r, g, b, a; EDR_Redraw() end,
                  hasAlpha = true,
                  tooltip = "Thrill" },
              } }
        ); y = y - h
        local speedTextRow
        speedTextRow, h = W:DualRow(parent, y,
            { type = "toggle", text = "Show Speed Text",
              getValue = function() return EDR_Cfg("speedText") and EDR_Cfg("speedText").enabled ~= false end,
              setValue = function(v) EDR_SetField("speedText", "enabled", v); EDR_Redraw() end },
            { type = "dropdown", text = "Text Align",
              values = justifyValues, order = justifyOrder,
              getValue = function() return (EDR_Cfg("speedText") or {}).justify or "CENTER" end,
              setValue = function(v) EDR_SetField("speedText", "justify", v); EDR_Redraw() end }
        )
        do
        NoxUI.BuildInlineCog(speedTextRow._rightRegion, {
            title = "Speed Text Position",
            rows = {
                { type = "slider", label = "Size",     min = 6,    max = 32,  step = 1,
                  get = function() return (EDR_Cfg("speedText") or {}).size    or 12 end,
                  set = function(v) EDR_SetField("speedText", "size",    v); EDR_Redraw() end },
                { type = "slider", label = "Offset X", min = -200, max = 200, step = 1,
                  get = function() return (EDR_Cfg("speedText") or {}).offsetX or 0  end,
                  set = function(v) EDR_SetField("speedText", "offsetX", v); EDR_Redraw() end },
                { type = "slider", label = "Offset Y", min = -200, max = 200, step = 1,
                  get = function() return (EDR_Cfg("speedText") or {}).offsetY or 0  end,
                  set = function(v) EDR_SetField("speedText", "offsetY", v); EDR_Redraw() end },
            },
        })
        end
        y = y - h
        _, h = W:Spacer(parent, y, 20); y = y - h
        end -- Show Speed Bar
        end   -- close Dragon Riding hidden-while-disabled gate

        -- The wrapper is SetAllPoints-anchored, so SetHeight on it is inert;
        -- return the measured height so the scroll range is correct.
        return math.abs(y)
    end

    -- WoW Forever has no skyriding: the Dragon Riding tab is not registered there
    -- (its resident file returns at load, so the page would have no DB to read).
    -- Window Mover, right after Window Skins, links to Quality of Life's Shifter,
    -- so it is offered only while Quality of Life is loaded.
    local pages = NoxUI.IS_FOREVER and { PAGE_WINDOWSKINS, PAGE_TOOLTIPS, PAGE_CHATBUBBLES }
        or { PAGE_WINDOWSKINS, PAGE_TOOLTIPS, PAGE_CHATBUBBLES, PAGE_DRAGONRIDING }
    if NoxUI._ModuleNS["NoxUIConfortJeu"] then table.insert(pages, 2, PAGE_WINDOWMOVER) end
    -- Panel shown, or unfolded from its mini window (no page callback runs then): a shown
    -- sample catches up on writes it skipped while hidden (Unlock Mode, other pages). Each
    -- repaint checks that its own sample is the one on screen.
    local function CatchUpPreviews()
        TooltipPreviewRepaint()
        PopupPreviewRepaint()
        if ns.EDR_RepaintSample then ns.EDR_RepaintSample() end
    end
    NoxUI:RegisterOnShow(CatchUpPreviews)
    NoxUI:RegisterOnCollapse(function(on)
        if not on then CatchUpPreviews() end
    end)
    NoxUI:RegisterModule("NoxUIApparenceBlizzard", {
        title       = "Blizzard Skins+",
        description = NoxUI.IS_FOREVER and "Themed Blizzard frames: window skins, tooltips, menus, popups, chat bubbles."
            or "Themed Blizzard frames: window skins, tooltips, menus, popups, chat bubbles, Dragon Riding HUD.",
        searchTerms = "blizzard skin character sheet tooltip menu popup dragon riding skyriding window skins lfg group finder premade queue pause game menu great vault inspect collections mounts pets toys spellbook talents adventure guide encounter journal professions guild communities calendar achievements mail catalyst gem socket item upgrade upgrades crest loot window loot toast you received popup micro menu modern delves companion brann loot roll need greed pass disenchant loot rolls pending rolls group invite invited to a group role chat bubbles bubble speech balloon",
        pages       = pages,
        pageLinks   = { [PAGE_WINDOWMOVER] = { module = "NoxUIConfortJeu", page = "Shifter" } },
        buildPage   = function(pageName, parent, yOffset)
            if pageName == PAGE_WINDOWSKINS then
                return BuildWindowSkinsPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_TOOLTIPS then
                return BuildTooltipsPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_CHATBUBBLES then
                return BuildChatBubblesPage(pageName, parent, yOffset)
            end
            if pageName == PAGE_DRAGONRIDING then
                return BuildDragonRidingPage(pageName, parent, yOffset)
            end
        end,
        -- The Tooltips, Chat Bubbles and Skyriding previews live in the content header; a
        -- cached page whose header was dropped rebuilds with it.
        getHeaderBuilder = function(pageName)
            if pageName == PAGE_TOOLTIPS then return TooltipHeaderBuilder end
            if pageName == PAGE_CHATBUBBLES then return ChatBubblesHeaderBuilder end
            if pageName == PAGE_DRAGONRIDING and EDR_Cfg("enabled") == true then
                return SkyridingHeaderBuilder
            end
        end,
        -- A kept page shown again: its preview paints again (the Fonts and Textures pages,
        -- Unlock Mode and a profile switch write its keys from elsewhere).
        onPageCacheRestore = function(pageName)
            if pageName == PAGE_TOOLTIPS then TooltipPreviewRepaint(); PopupPreviewRepaint() end
            if pageName == PAGE_DRAGONRIDING and ns.EDR_RepaintSample then ns.EDR_RepaintSample() end
        end,
        resetScope = "account",
        onReset = function()
            if NoxUIDragonRidingDB then
                NoxUIDragonRidingDB.profiles = nil
                NoxUIDragonRidingDB.profileKeys = nil
            end
            -- Per-profile master kill switch: reset re-enables skins for the
            -- ACTIVE profile (other profiles keep their own choice).
            do
                local prof = NoxUI.GetActiveProfileData()
                if prof then prof.disableWindowSkins = nil end
                -- Per-profile Chat Bubbles; Refresh hands back any CVars it held.
                if prof then prof.chatBubbles = nil end
                if NoxUI.ChatBubbles then NoxUI.ChatBubbles.Refresh() end
            end
            if NoxUIDB then
                -- NOTE: these account-global keys also travel in profile exports via
                -- BLIZZ_SKIN_GLOBAL_KEYS in NoxUI_Profiles.lua (the "Window &
                -- Tooltip Skins" include). A new account-global setting on the Window
                -- Skins or Tooltips, Menus & Popups tab must be added to BOTH lists.
                NoxUIDB.thirdPartySkinsOff = nil
                NoxUIDB.thirdPartySkinAddons = nil
                NoxUIDB.customTooltips = nil
                NoxUIDB.reskinPopupsMenus = nil
                NoxUIDB.accentReskinElements = nil
                NoxUIDB.tooltipPlayerTitles = nil
                NoxUIDB.tooltipFontScale = nil
                NoxUIDB.tooltipRoundedCorners = nil
                NoxUIDB.tooltipMythicScore = nil
                NoxUIDB.tooltipAnchorCursor = nil
                NoxUIDB.tooltipCursorPosition = nil
                NoxUIDB.tooltipCursorOffsetX = nil
                NoxUIDB.tooltipCursorOffsetY = nil
                NoxUIDB.tooltipFixedPos = nil  -- stale key from the account-global build
                -- Per-profile fixed tooltip position: clearing it re-seeds from
                -- Blizzard's CURRENT Edit Mode spot on the next tooltip show.
                do
                    local prof = NoxUI.GetActiveProfileData()
                    if prof then prof.tooltipFixedPos = nil end
                end
                NoxUIDB.uberTooltips = nil
                NoxUIDB.uberTooltipsManual = nil
                NoxUIDB.tooltipHideHealthStrip = nil
                NoxUIDB.tooltipHealthStripTexture = nil
                NoxUIDB.tooltipHealthStripHeight = nil
                NoxUIDB.showItemMaxStacks = nil
                NoxUIDB.itemStackModifier = nil
                NoxUIDB.tooltipShowGuildRank = nil
                NoxUIDB.tooltipShowMount = nil
                NoxUIDB.tooltipShowTarget = nil
                NoxUIDB.tooltipLevelColor = nil
                NoxUIDB.tooltipClassLineColor = nil
                NoxUIDB.tooltipFactionColor = nil
                NoxUIDB.tooltipGuildmateColor = nil
                NoxUIDB.tooltipCompactLevel = nil
                NoxUIDB.tooltipAFKTag = nil
                -- Tooltip Extras' Item Counts: the Bags module's account-wide switch.
                -- Cleared here with its row, but never exported with the tooltip
                -- settings: turning it on makes Bags save inventories, which a
                -- shared profile must not switch on for another account.
                NoxUIDB.bagTooltipCounts = nil
                NoxUIDB.tooltipShowBuffs = nil
                NoxUIDB.tooltipBuffPosition = nil
                NoxUIDB.tooltipBuffSize = nil
                NoxUIDB.tooltipBuffsPerRow = nil
                NoxUIDB.tooltipBuffOffsetX = nil
                NoxUIDB.tooltipBuffOffsetY = nil
                if NoxUI._applyTooltipBuffs then NoxUI._applyTooltipBuffs() end
                NoxUIDB.reskinQueuePopup = nil
                NoxUIDB.resurrectAcceptGlow = nil
                -- Clear any glow on a currently visible popup (the setting
                -- just went nil = off; hooks stay installed but inert).
                if NoxUI._EnsureResurrectGlow then NoxUI._EnsureResurrectGlow() end
                NoxUIDB.reskinGameMenu = nil
                NoxUIDB.popupMenuButtonBackgroundColor=nil
                NoxUIDB.popupMenuButtonTextColorMode=nil
                NoxUIDB.popupMenuButtonTextColor=nil
                for _,prefix in ipairs({"popupMenu","popupMenuButton","tooltip","lootWindow","lootIcon","timerBars"}) do
                    for _,suffix in ipairs({"BorderTexture","BorderThickness","BorderThicknessPx","BorderColor","BorderColorMode","BorderOpacity","BorderOffsetX","BorderOffsetY","BorderShiftX","BorderShiftY","BorderBehind"}) do
                        NoxUIDB[prefix..suffix]=nil
                    end
                end
                -- Legacy numeric key the tooltip Border Size still falls back
                -- to when tooltipBorderThickness is unset.
                NoxUIDB.tooltipBorderSize = nil
                if NoxUI.SyncAuraTooltipSkin then NoxUI.SyncAuraTooltipSkin() end
                NoxUIDB.reskinGreatVault = nil
                NoxUIDB.reskinLFGMenu = nil
                NoxUIDB.showQueueTimer = nil
                NoxUIDB.queueTimerTextColor = nil
                NoxUIDB.queueTimerTextSize = nil
                NoxUIDB.queueTimerBarHeight = nil
                NoxUIDB.queueTimerTextOffsetY = nil
                NoxUIDB.blizzWindowSkinStyles = nil
                NoxUIDB.blizzWindowModernBG = nil
                NoxUIDB.blizzWindowModernDefault = nil
                NoxUIDB.blizzWinAccentBar = nil
                NoxUIDB.blizzWinBarFill = nil
                NoxUIDB.blizzWinLinks = nil
                NoxUIDB.reskinCollections = nil
                NoxUIDB.reskinPlayerSpells = nil
                NoxUIDB.reskinAdventureGuide = nil
                NoxUIDB.reskinProfessionsBook = nil
                NoxUIDB.reskinGuild = nil
                NoxUIDB.reskinCalendar = nil
                NoxUIDB.reskinAchievements = nil
                NoxUIDB.reskinMail = nil
                NoxUIDB.reskinCatalyst = nil
                NoxUIDB.reskinSocket = nil
                NoxUIDB.reskinItemUpgrade = nil
                NoxUIDB.reskinLoot = nil
                NoxUIDB.lootIconBorder = nil
                NoxUIDB.lootWindowBorderQualityColor = nil
                NoxUIDB.reskinLootToast = nil
                NoxUIDB.reskinBNetToast = nil
                NoxUIDB.lootToastQualityStrip = nil
                NoxUIDB.lootToastQualityStripMoney = nil
                NoxUIDB.lootToastScale = nil
                NoxUIDB.reskinLootRoll = nil
                NoxUIDB.reskinLootHistory = nil
                NoxUIDB.reskinGroupInvite = nil
                NoxUIDB.reskinReadyCheck = nil
                NoxUIDB.reskinMicroMenu = nil
                NoxUIDB.reskinBagBar = nil
                NoxUIDB.reskinLegacySystem = nil
                NoxUIDB.reskinHousing = nil
                NoxUIDB.reskinProfessions = nil
                NoxUIDB.reskinWorldMap = nil
                NoxUIDB.reskinDressUp = nil
                NoxUIDB.reskinTransmog = nil
                NoxUIDB.reskinMerchant = nil
                NoxUIDB.reskinAuctionHouse = nil
                NoxUIDB.reskinMacros = nil
                NoxUIDB.reskinSettings = nil
                NoxUIDB.reskinAddonList = nil
                NoxUIDB.reskinCraftOrders = nil
                NoxUIDB.reskinTrainer = nil
                NoxUIDB.reskinStable = nil
                NoxUIDB.reskinGossip = nil
                NoxUIDB.reskinQuest = nil
                NoxUIDB.reskinInspectRecipe = nil
                NoxUIDB.reskinDelves = nil
                NoxUIDB.reskinSocialUI = nil
                NoxUIDB.reskinQueueStatus = nil
                NoxUIDB.reskinDelvePicker = nil
                NoxUIDB.reskinPlayerChoice = nil
                NoxUIDB.reskinTrade = nil
                NoxUIDB.reskinFlagCarriers = nil
                NoxUIDB.windowSkinsStockSeeded = nil
                NoxUIDB.windowSkinStyleSlots = nil
                NoxUIDB.reskinWidgetBars = nil
                NoxUIDB.widgetBarMinSize = nil
                NoxUIDB.reskinExtraActionButton = nil
                NoxUIDB.reskinTimerBars = nil
                NoxUIDB.timerBarsTexture = nil
                NoxUIDB.timerBarsFillMode = nil
                NoxUIDB.timerBarsFillColor = nil
                NoxUIDB.timerBarsFillOpacity = nil
                NoxUIDB.timerBarsBgColor = nil
                NoxUIDB.timerBarsBgOpacity = nil
                NoxUIDB.timerBarsTypeColors = nil
                NoxUIDB.timerBarsBreathColor = nil
                NoxUIDB.timerBarsFatigueColor = nil
                NoxUIDB.timerBarsFeignColor = nil
                NoxUIDB.timerBarsShowText = nil
                NoxUIDB.timerBarsTextSize = nil
                NoxUIDB.timerBarsTextColor = nil
                NoxUIDB.timerBarsTextX = nil
                NoxUIDB.timerBarsTextY = nil
                NoxUIDB.timerBarsWidth = nil
                NoxUIDB.timerBarsHeight = nil
                NoxUIDB.timerBarsCornerRadius = nil
                NoxUIDB.timerBarsCornerMask = nil
                NoxUIDB.lfgRememberRoles = nil
                NoxUIDB.lfgSavedRoles = nil
                NoxUIDB.showMythicRating = nil
                NoxUIDB.showPvpItemLevel = nil
                NoxUIDB.charSheetSeasonPanel = nil
                NoxUIDB.charSheetSeasonVault = nil
                NoxUIDB.charSheetHideSlotFlyoutArrows = nil
                NoxUIDB.flyoutItemLevels = nil
                NoxUIDB.flyoutItemStats = nil
                NoxUIDB.charSheetItemStats = nil
                NoxUIDB.flyoutItemStatsTertiary = nil
                NoxUIDB.charSheetItemStatsTertiary = nil
                NoxUIDB.charSheetSocketPanelStats = nil
                NoxUIDB.showCharSheetDurability = nil
                NoxUIDB.charSheetDurabilityLocation = nil
                NoxUIDB.charSheetDurabilityShowLabel = nil
                NoxUIDB.showSecondaryRaw = nil
                NoxUIDB.showSecondaryBoth = nil
                NoxUIDB.showTertiaryRaw = nil
                NoxUIDB.showTertiaryBoth = nil
                NoxUIDB.showAdjustedStats = nil
                NoxUIDB.showManaStat = nil
                NoxUIDB.highlightSecondaryItems = nil
                NoxUIDB.highlightTertiaryItems = nil
                NoxUIDB.statCategoryColors = nil
                NoxUIDB.statSectionsOrder = nil
                NoxUIDB.charSheetCollapsedSections = nil
                NoxUIDB.charSheetBlizzColors = nil
                NoxUIDB.inspectEnchantNames = nil
                NoxUIDB.inspectEnchantSize = nil
                -- The rest of what the export bundle carries for these two tabs
                -- (BLIZZ_SKIN_GLOBAL_KEYS): card and tooltip settings, defaults too.
                for _, k in ipairs({
                    "themedCharacterSheet", "themedInspectSheet", "statCategoryUseColor",
                    "showItemLevel", "showUpgradeTrack", "showGems", "showEnchants",
                    "charSheetSocketPanel", "charSheetIconZoom", "charSheetEnchantNames",
                    "charSheetEnchantSize", "inspectShowEnchants", "inspectShowItemLevel",
                    "inspectShowUpgradeTrack", "merchantShowAsList", "merchantListRowHeight",
                    "merchantShowItemLevel", "merchantBulkBuy", "merchantExpand", "merchantCols", "merchantRows",
                    "merchantMarkOwned", "merchantHideKnown",
                    "tooltipItemLevel", "tooltipShowMode",
                    "tooltipShowModifier", "tooltipGrowthDirection", "tooltipBgColor",
                    "tooltipBgOpacity", "showSpellID", "spellIDModifier", "showIconID",
                    "showItemID", "friendsListCard",
                    "mailAltList", "mailAltListMax", "mailAltListMinLevel", "mailAltListSort",
                    "mailAltListTab",
                }) do NoxUIDB[k] = nil end
                -- Shown Characters (the roster itself is recorded data, not a setting)
                NoxUI.ClearCharField("mailAltHidden")
                NoxUIDB.characterFramePos = nil
                NoxUIDB.friendsFramePos = nil
            end
            if NoxUI._applyTooltipCursorAnchor then NoxUI._applyTooltipCursorAnchor() end
            if NoxUI._applyTooltipFixedAnchor then NoxUI._applyTooltipFixedAnchor() end
            if NoxUI._applyTooltipHealthStrip then NoxUI._applyTooltipHealthStrip() end
            if NoxUI._applyTooltipHealthStripStyle then NoxUI._applyTooltipHealthStripStyle() end
            if NoxUI._refreshCharSheetSocketPanel then NoxUI._refreshCharSheetSocketPanel() end
            if NoxUI._refreshCharSheetSlotFlyoutArrows then NoxUI._refreshCharSheetSlotFlyoutArrows() end
            if NoxUI._refreshStatFormats then NoxUI._refreshStatFormats() end
            if NoxUI._refreshCharSheetSlotLabels then NoxUI._refreshCharSheetSlotLabels() end
            if NoxUI._refreshInspectSlotLabels then NoxUI._refreshInspectSlotLabels() end
            -- WoW Forever's Friends List card (auto-accept and the tiles)
            if ns.FriendsCardRefresh then ns.FriendsCardRefresh() end
            -- The Mail card's Alt List (retail)
            if ns.MailAlts then ns.MailAlts.Refresh() end
        end,
    })

    -- Deep links (What's New, search) into the Window Skins page target rows
    -- that only exist while a card is expanded. Pre-hook: expand every card and
    -- drop the page cache so the nav's SelectPage cold-builds with all rows
    -- present before it resolves the section/highlight.
    local origNav = NoxUI.NavigateToElementSettings
    if origNav then
        function NoxUI:NavigateToElementSettings(moduleName, pageName, sectionName, preSelectFn, highlightText)
            -- The original refuses in combat: no page state changes then.
            if InCombatLockdown() then
                return origNav(self, moduleName, pageName, sectionName, preSelectFn, highlightText)
            end
            if moduleName == "NoxUIApparenceBlizzard" and pageName == PAGE_WINDOWSKINS
               and (sectionName or highlightText) then
                local changed = false
                for _, win in ipairs(WINDOWS) do
                    if not _wsExpanded[win.key] then
                        _wsExpanded[win.key] = true
                        changed = true
                    end
                end
                if changed and NoxUI.InvalidatePageCache then
                    NoxUI:InvalidatePageCache()
                end
            end
            return origNav(self, moduleName, pageName, sectionName, preSelectFn, highlightText)
        end
    end

    SLASH_EBSK1 = "/ebsk"
    SlashCmdList.EBSK = function()
        if InCombatLockdown and InCombatLockdown() then return end
        NoxUI:ShowModule("NoxUIApparenceBlizzard")
    end
end)
-- LoadOnDemand: this addon loads after PLAYER_LOGIN, so the event above will never fire; run the init now.
if IsLoggedIn() then initFrame:GetScript("OnEvent")(initFrame) end
