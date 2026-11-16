if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  NoxUI_VideoGuides.lua
--
--  Reusable VIDEO GUIDE popup engine: announcement-quality popups whose body
--  is a pre-selected read-only URL box (the only keystroke a user needs is
--  Ctrl+C) plus a single Okay button. Each guide brings its own unique top
--  art via an `art` callback drawing into the engine's header band.
--
--  API (NoxUI.VideoGuides):
--    Register(id, def) -- def = { title, blurb, url, footnote?, eyebrow?,
--                        accent?, height?, art = function(popup, ctx) }
--    Show(id)          -- show unconditionally (future section icons call this)
--    FireOnce(id)      -- first time ever: stamps seen + shows, returns true
--                        (callers use true to swallow the triggering click)
--    HasSeen(id)       -- reads the per-account seen map
--
--  Seen map: NoxUIDB.videoGuidesSeen[id] = true (per account, one flat
--  key for all guides forever). The shell (dimmer/popup/chrome) is built once
--  and reused; per-guide art containers are built once and swapped. Zero cost
--  at load: nothing is created until the first Show.
--
--  Guide #1 (settings_overrides) registers at the bottom of this file and is
--  fired by the spec-override toolbar glyph's first-ever click.
-------------------------------------------------------------------------------

local NoxUI = _G.NoxUI
if not NoxUI then return end

-- Suite-only: guides describe suite surfaces. Trigger sites nil-guard on
-- NoxUI.VideoGuides so standalone builds degrade to normal clicks.
local NUI_MODULE_HOTE = ...
local IS_STANDALONE = type(NUI_MODULE_HOTE) == "string" and NUI_MODULE_HOTE:find("Standalone") ~= nil
if IS_STANDALONE then return end

local PP = NoxUI.PanelPP
local MakeBorder = NoxUI.MakeBorder

-- The override system's gold (used by guide art, exposed via ctx).
local GOLD = { r = 1, g = 0.82, b = 0.30 }

local POPUP_W, POPUP_H = 470, 368
local ART_H = 88

local guides = {}      -- id -> def
local artFrames = {}   -- id -> built art container (band frame)

local function MarkSeen(id)
    if not NoxUIDB then NoxUIDB = {} end
    if not NoxUIDB.videoGuidesSeen then NoxUIDB.videoGuidesSeen = {} end
    NoxUIDB.videoGuidesSeen[id] = true
end

local function HasSeen(id)
    return (NoxUIDB and NoxUIDB.videoGuidesSeen
        and NoxUIDB.videoGuidesSeen[id]) or false
end

-- Right-pointing solid triangle: collapse the right edge of a color texture
-- to its vertical midpoint. Vertex indices: 1=UpperLeft, 2=LowerLeft,
-- 3=UpperRight, 4=LowerRight. Positive y offset is up.
local function MakeTriangle(parent, w, h, r, g, b, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(r, g, b, a or 1)
    PP.Size(t, w, h)
    t:SetVertexOffset(3, 0, -h / 2)
    t:SetVertexOffset(4, 0, h / 2)
    return t
end

-- Square play badge: dark chip, colored border (matches whatever art it sits
-- beside), white triangle nudged right for optical centering.
local function MakePlayBadge(parent, size, color)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetFrameLevel(parent:GetFrameLevel() + 3)
    PP.Size(badge, size, size)
    local chip = badge:CreateTexture(nil, "BACKGROUND")
    chip:SetAllPoints()
    chip:SetColorTexture(0.062, 0.050, 0.039, 0.95)
    MakeBorder(badge, color.r, color.g, color.b, 0.85, PP)
    local tri = MakeTriangle(badge, math.floor(size * 0.36), math.floor(size * 0.42), 1, 1, 1, 0.95)
    PP.Point(tri, "CENTER", badge, "CENTER", size * 0.05, 0)
    return badge
end

-------------------------------------------------------------------------------
--  Tutorial tips: small one-time play badges attached beside UI entry points
--  (nav rows, section headers). Clicking one opens its video guide and
--  retires the badge FOREVER (per account); until then it always shows.
--  Visual: a 16px play icon in the suite accent -- present but never in the way.
-------------------------------------------------------------------------------
local liveTips = {}   -- tipId -> tip frame (RefreshTips re-evaluates these)

local function TipSeen(id)
    return (NoxUIDB and NoxUIDB.tutorialTipsSeen
        and NoxUIDB.tutorialTipsSeen[id]) or false
end

local function MarkTipSeen(id)
    if not NoxUIDB then NoxUIDB = {} end
    if not NoxUIDB.tutorialTipsSeen then NoxUIDB.tutorialTipsSeen = {} end
    NoxUIDB.tutorialTipsSeen[id] = true
end

-------------------------------------------------------------------------------
--  Shell: built once, reused for every guide. `ui` holds every retintable /
--  retextable piece; `cur` is the accent table the hover closures read (the
--  shell outlives any single guide, so closures must never capture r,g,b).
-------------------------------------------------------------------------------
local ui        -- nil until first Show
local cur = { r = 0, g = 0, b = 0 }
local FONT

local function Dismiss()
    if not ui then return end
    ui.eb:ClearFocus()
    ui.dimmer:Hide()
    -- Per-guide dismiss hook (def.onDismiss): announcement guides use it to
    -- release the login popup chain (conflict check handoff). Runs on every
    -- close path: Okay, Escape, Enter, and outside click all land here.
    local cb = ui._onDismiss
    if cb then ui._onDismiss = nil; cb() end
end

local function BuildShell()
    if ui then return end
    FONT = NoxUI._font or ("Interface\\AddOns\\NoxUI\\media\\fonts\\Expressway.ttf")
    ui = {}

    -- Dimmer: eats stray clicks/wheel; clicking anywhere outside the panel
    -- closes the guide (the popup itself is mouse-enabled, so clicks over it
    -- never reach this handler). No bump: Show() scales both frames per open
    -- (the outline refits on show). Escape closes (the
    -- EditBox path handles it while focused; this covers an unfocused box).
    local dimmer, popup = NoxUI.BuildPopupShell("EUIVideoGuide", {
        w = POPUP_W, h = POPUP_H, onDimmerDown = Dismiss, onEscape = Dismiss,
    })
    ui.dimmer = dimmer
    ui.popup = popup

    -- Art band: full-bleed dark well flush to the top edge, accent rule
    -- underneath. Per-guide art containers are children created in SetGuide.
    local well = popup:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetColorTexture(0.056, 0.045, 0.034, 1)
    PP.Point(well, "TOPLEFT", popup, "TOPLEFT", 0, 0)
    PP.Point(well, "TOPRIGHT", popup, "TOPRIGHT", 0, 0)
    well:SetHeight(ART_H)
    -- The popup's shape: the well's top corners follow the round outline.
    well:AddMaskTexture(popup._brd.bodyMask)
    ui.well = well
    local rule = popup:CreateTexture(nil, "BACKGROUND", nil, 2)
    PP.Point(rule, "TOPLEFT", popup, "TOPLEFT", 0, -ART_H)
    PP.Point(rule, "TOPRIGHT", popup, "TOPRIGHT", 0, -ART_H)
    rule:SetHeight(1)
    ui.rule = rule

    -- Eyebrow: play triangle + "VIDEO GUIDE"
    local eyebrow = popup:CreateFontString(nil, "OVERLAY")
    eyebrow:SetFont(FONT, 13, "")
    PP.Point(eyebrow, "TOP", popup, "TOP", 0, -(ART_H + 16))
    ui.eyebrow = eyebrow
    local tri = MakeTriangle(popup, 9, 10, 1, 1, 1, 0.9)
    PP.Point(tri, "RIGHT", eyebrow, "LEFT", -7, 0)
    ui.tri = tri

    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 25, "")
    title:SetTextColor(1, 1, 1, 1)
    PP.Point(title, "TOP", eyebrow, "BOTTOM", 0, -6)
    ui.title = title

    -- Blurb
    local blurb = popup:CreateFontString(nil, "OVERLAY")
    blurb:SetFont(FONT, 14, "")
    blurb:SetTextColor(1, 1, 1, 0.55)
    blurb:SetWidth(POPUP_W - 80)
    blurb:SetJustifyH("CENTER")
    blurb:SetWordWrap(true)
    PP.Point(blurb, "TOP", title, "BOTTOM", 0, -12)
    ui.blurb = blurb

    -- Optional bullet rows between the blurb and the URL well (def.bullets =
    -- up to two arrays of short labels; announcement guides list their hero
    -- topics here). Hidden and skipped by anchoring for plain guides.
    local bulletRow1 = popup:CreateFontString(nil, "OVERLAY")
    bulletRow1:SetFont(FONT, 13, "")
    bulletRow1:SetTextColor(1, 1, 1, 0.72)
    bulletRow1:SetJustifyH("CENTER")
    PP.Point(bulletRow1, "TOP", blurb, "BOTTOM", 0, -14)
    bulletRow1:Hide()
    ui.bulletRow1 = bulletRow1
    local bulletRow2 = popup:CreateFontString(nil, "OVERLAY")
    bulletRow2:SetFont(FONT, 13, "")
    bulletRow2:SetTextColor(1, 1, 1, 0.72)
    bulletRow2:SetJustifyH("CENTER")
    PP.Point(bulletRow2, "TOP", bulletRow1, "BOTTOM", 0, -8)
    bulletRow2:Hide()
    ui.bulletRow2 = bulletRow2

    -- URL well + read-only EditBox (always-selected; Ctrl+C is the point)
    local urlWell = CreateFrame("Frame", nil, popup)
    urlWell:SetFrameLevel(popup:GetFrameLevel() + 2)
    PP.Size(urlWell, 350, 34)
    PP.Point(urlWell, "TOP", blurb, "BOTTOM", 0, -18)
    local wbg = urlWell:CreateTexture(nil, "BACKGROUND")
    wbg:SetAllPoints()
    wbg:SetColorTexture(0.045, 0.035, 0.027, 1)
    -- Neutral border (never accent-tinted): the link-blue text carries the
    -- "this is the link" read on its own.
    ui.urlBrd = NoxUI.MakeRoundedBorder(urlWell, 1, 1, 1, 0.22, wbg)
    ui.urlWell = urlWell

    -- Hint under the well (also doubles as the Ctrl+C confirmation line)
    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 11, "")
    hint:SetTextColor(1, 1, 1, 0.45)
    PP.Point(hint, "TOP", urlWell, "BOTTOM", 0, -8)
    ui.hint = hint

    local eb = CreateFrame("EditBox", nil, urlWell)
    eb:SetAllPoints(urlWell)
    eb:SetMultiLine(false)
    eb:SetAutoFocus(false)
    eb:SetFont(FONT, 13, "")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(12, 12, 0, 0)
    eb:SetTextColor(0.55, 0.75, 1.0, 1)   -- link blue
    eb:SetScript("OnMouseUp", function(self)
        C_Timer.After(0, function() self:SetFocus(); self:HighlightText() end)
    end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- Read-only: typing/paste/cut restore the URL and re-select.
    eb:SetScript("OnChar", function(self)
        self:SetText(self._readOnly or ""); self:HighlightText()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(self._readOnly or ""); self:HighlightText() end
    end)
    eb:SetScript("OnEscapePressed", function(self) Dismiss() end)
    eb:SetScript("OnEnterPressed", function(self) Dismiss() end)
    eb:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown() then
            hint:SetText("Link copied - paste it into your browser")
            hint:SetTextColor(cur.r, cur.g, cur.b, 0.9)
        end
    end)
    ui.eb = eb

    -- Single centered Okay button (accent primary)
    local okBtn = CreateFrame("Button", nil, popup)
    okBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
    PP.Size(okBtn, 160, 36)
    PP.Point(okBtn, "BOTTOM", popup, "BOTTOM", 0, 42)
    local okBg = okBtn:CreateTexture(nil, "BACKGROUND")
    okBg:SetAllPoints()
    okBg:SetColorTexture(0.077, 0.068, 0.058, 0.92)
    ui.okBrd = NoxUI.MakeRoundedBorder(okBtn, 1, 1, 1, 0.9, okBg)
    local okLbl = okBtn:CreateFontString(nil, "OVERLAY")
    okLbl:SetFont(FONT, 15, "")
    PP.Point(okLbl, "CENTER", okBtn, "CENTER", 0, 0)
    okLbl:SetText("Okay")
    ui.okLbl = okLbl
    ui.okBtn = okBtn
    okBtn:SetScript("OnEnter", function()
        okLbl:SetTextColor(cur.r, cur.g, cur.b, 1)
        ui.okBrd:SetColor(cur.r, cur.g, cur.b, 1)
    end)
    okBtn:SetScript("OnLeave", function()
        okLbl:SetTextColor(cur.r, cur.g, cur.b, 0.9)
        ui.okBrd:SetColor(cur.r, cur.g, cur.b, 0.9)
    end)
    okBtn:SetScript("OnClick", function() Dismiss() end)

    -- Footnote
    local footnote = popup:CreateFontString(nil, "OVERLAY")
    footnote:SetFont(FONT, 12, "")
    footnote:SetTextColor(1, 1, 1, 0.35)
    footnote:SetWidth(POPUP_W - 80)
    footnote:SetJustifyH("CENTER")
    PP.Point(footnote, "BOTTOM", popup, "BOTTOM", 0, 16)
    ui.footnote = footnote
end

--- Populates the shared shell for one guide: texts, accent retints, art swap.
local function SetGuide(id, def)
    local accent = def.accent or NoxUI.NOX_GREEN or { r = 0.05, g = 0.83, b = 0.62 }
    cur.r, cur.g, cur.b = accent.r, accent.g, accent.b

    -- Per-guide geometry, RESET to the defaults every call (the shell is
    -- shared, so a big announcement guide must not leak its size into the
    -- next plain guide). Width-dependent pieces re-measure here too.
    local w = def.width or POPUP_W
    local artH = def.artHeight or ART_H
    -- Per-guide vertical rhythm (def.gaps): every inter-element gap resets to
    -- the compact build-time default when unspecified, so plain guides keep
    -- their exact original layout and big announcements can breathe.
    local gaps = def.gaps or {}
    local gEyebrow  = gaps.eyebrow or 16
    local gTitle    = gaps.title or 6
    local gBlurb    = gaps.blurb or 12
    local gBullets  = gaps.bullets or 14
    local gBRows    = gaps.bulletRows or 8
    local gUrl      = gaps.url
    local gHint     = gaps.hint or 8
    PP.Size(ui.popup, w, def.height or POPUP_H)
    ui.well:SetHeight(artH)
    ui.rule:ClearAllPoints()
    PP.Point(ui.rule, "TOPLEFT", ui.popup, "TOPLEFT", 0, -artH)
    PP.Point(ui.rule, "TOPRIGHT", ui.popup, "TOPRIGHT", 0, -artH)
    ui.eyebrow:ClearAllPoints()
    PP.Point(ui.eyebrow, "TOP", ui.popup, "TOP", 0, -(artH + gEyebrow))
    ui.title:ClearAllPoints()
    PP.Point(ui.title, "TOP", ui.eyebrow, "BOTTOM", 0, -gTitle)
    ui.blurb:ClearAllPoints()
    PP.Point(ui.blurb, "TOP", ui.title, "BOTTOM", 0, -gBlurb)
    ui.bulletRow1:ClearAllPoints()
    PP.Point(ui.bulletRow1, "TOP", ui.blurb, "BOTTOM", 0, -gBullets)
    ui.bulletRow2:ClearAllPoints()
    PP.Point(ui.bulletRow2, "TOP", ui.bulletRow1, "BOTTOM", 0, -gBRows)
    ui.hint:ClearAllPoints()
    PP.Point(ui.hint, "TOP", ui.urlWell, "BOTTOM", 0, -gHint)
    ui.okBtn:ClearAllPoints()
    PP.Point(ui.okBtn, "BOTTOM", ui.popup, "BOTTOM", 0, gaps.button or 42)
    ui.footnote:ClearAllPoints()
    PP.Point(ui.footnote, "BOTTOM", ui.popup, "BOTTOM", 0, gaps.footnote or 16)
    ui.blurb:SetWidth(w - 80)
    ui.footnote:SetWidth(w - 80)
    PP.Size(ui.urlWell, def.urlWidth or 350, 34)
    ui.okLbl:SetText(NoxUI.L(def.okText or "Okay"))
    ui._onDismiss = def.onDismiss

    -- Bullet rows: accent-dotted short labels, up to two centered lines; the
    -- URL well re-anchors below them when present, back onto the blurb when not.
    ui.urlWell:ClearAllPoints()
    if def.bullets and def.bullets[1] then
        local hex = string.format("%02x%02x%02x",
            math.floor(accent.r * 255 + 0.5), math.floor(accent.g * 255 + 0.5), math.floor(accent.b * 255 + 0.5))
        local function Line(items)
            local parts = {}
            for i = 1, #items do
                parts[i] = "|cff" .. hex .. "\226\128\162|r " .. items[i]
            end
            return table.concat(parts, "    ")
        end
        ui.bulletRow1:SetText(Line(def.bullets[1]))
        ui.bulletRow1:Show()
        if def.bullets[2] then
            ui.bulletRow2:SetText(Line(def.bullets[2]))
            ui.bulletRow2:Show()
            PP.Point(ui.urlWell, "TOP", ui.bulletRow2, "BOTTOM", 0, -(gUrl or 16))
        else
            ui.bulletRow2:Hide()
            PP.Point(ui.urlWell, "TOP", ui.bulletRow1, "BOTTOM", 0, -(gUrl or 16))
        end
    else
        ui.bulletRow1:Hide()
        ui.bulletRow2:Hide()
        PP.Point(ui.urlWell, "TOP", ui.blurb, "BOTTOM", 0, -(gUrl or 18))
    end

    ui.eyebrow:SetText(NoxUI.L(def.eyebrow or "VIDEO GUIDE"))
    ui.eyebrow:SetTextColor(accent.r, accent.g, accent.b, 0.9)
    ui.tri:SetColorTexture(accent.r, accent.g, accent.b, 0.9)
    ui.rule:SetColorTexture(accent.r, accent.g, accent.b, 0.35)
    ui.title:SetText(NoxUI.L(def.title or ""))
    ui.blurb:SetText(NoxUI.L(def.blurb or ""))
    ui.hint:SetText(NoxUI.L("Ctrl+C to copy, Escape to close"))
    ui.hint:SetTextColor(1, 1, 1, 0.45)
    ui.okLbl:SetTextColor(accent.r, accent.g, accent.b, 0.9)
    ui.okBrd:SetColor(accent.r, accent.g, accent.b, 0.9)
    ui.footnote:SetText(NoxUI.L(def.footnote or ""))

    local hasURL = type(def.url) == "string" and def.url ~= ""
    ui.urlWell:SetShown(hasURL)
    ui.hint:SetShown(hasURL)
    ui.eb._readOnly = def.url or ""
    ui.eb:SetText(def.url or "")
    ui.eb:SetCursorPosition(0)

    -- Art swap: hide every built band, then build-once-and-show this one.
    for _, band in pairs(artFrames) do band:Hide() end
    if def.art then
        local band = artFrames[id]
        if not band then
            band = CreateFrame("Frame", nil, ui.popup)
            band:SetFrameLevel(ui.popup:GetFrameLevel() + 1)
            -- 2-unit inset keeps child-frame art off the popup's 1px border.
            PP.Point(band, "TOPLEFT", ui.popup, "TOPLEFT", 2, -2)
            PP.Point(band, "TOPRIGHT", ui.popup, "TOPRIGHT", -2, -2)
            band:SetHeight(artH - 2)
            artFrames[id] = band
            local ctx = {
                band = band,
                W = w - 4,
                H = artH - 2,
                PP = PP,
                MakeBorder = MakeBorder,
                FONT = FONT,
                accent = { r = accent.r, g = accent.g, b = accent.b },
                GOLD = GOLD,
                MakeTriangle = MakeTriangle,
                MakePlayBadge = function(parent, size, color)
                    return MakePlayBadge(parent, size, color or accent)
                end,
            }
            -- Art failures must never break the popup: plain well on error.
            local ok = pcall(def.art, ui.popup, ctx)
            if not ok then band:Hide() end
        end
        band:Show()
    end
end

local function Show(id)
    local def = guides[id]
    if not def then return false end
    -- The trigger's widget tooltip is still on screen at click time.
    NoxUI.HideWidgetTooltip()
    BuildShell()
    local ppScale = (NoxUI.GetPopupScale()) or 1
    ui.dimmer:SetScale(ppScale)
    ui.popup:SetScale(NoxUI.PopupBump(1.15))
    SetGuide(id, def)
    ui.dimmer:Show()
    -- A guide opened over another resizes and moves these without a new show.
    ui.urlBrd:Fit(); ui.okBrd:Fit()
    -- Pre-select the URL so the only keystroke needed is Ctrl+C.
    local eb = ui.eb
    if def.url and def.url ~= "" then
        C_Timer.After(0, function()
            if ui.urlWell:IsVisible() then eb:SetFocus(); eb:HighlightText() end
        end)
    end
    return true
end

--- Attaches a one-time tutorial tip badge to a region. tipId doubles as the
--- guide id shown on click (override via opts.guide). opts: point/relPoint/
--- x/y (default: inside the region's right edge), size (16), tooltip.
--- Idempotent per tipId; never builds a retired tip. Returns the tip frame.
local function AttachTip(region, tipId, opts)
    if not region or not tipId then return nil end
    local existing = liveTips[tipId]
    if existing then
        existing:SetShown(not TipSeen(tipId))
        return existing
    end
    if TipSeen(tipId) then return nil end
    opts = opts or {}
    local size = opts.size or 16

    local tip = CreateFrame("Button", nil, region)
    tip:SetFrameLevel(region:GetFrameLevel() + 5)
    PP.Size(tip, size, size)
    PP.Point(tip, opts.point or "RIGHT", region, opts.relPoint or "RIGHT",
        opts.x or -10, opts.y or 0)
    -- Bare accent-tinted play icon -- no chip background, no border. The
    -- button itself stays full-size as the click/hover target. RegAccent
    -- keeps the tint live when the accent color changes (dedupes by obj).
    local icon = tip:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\NoxUI\\media\\icons\\play.png")
    local EG = NoxUI.NOX_GREEN
    if EG then
        icon:SetVertexColor(EG.r, EG.g, EG.b, 1)
        NoxUI.RegAccent({ type = "vertex", obj = icon })
    else
        icon:SetVertexColor(1, 1, 1, 0.9)
    end

    -- Deliberately STATIC (no pulse): the badge stays on the UI until
    -- clicked, so it must read as a quiet help affordance the user consults
    -- on their own time -- never as a notification begging for a click.
    -- Slightly dimmed idle, full brightness on hover.
    tip:SetAlpha(0.8)

    local tipText = opts.tooltip or "Video Guide"
    tip:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        if NoxUI.ShowWidgetTooltip then
            NoxUI.ShowWidgetTooltip(self, (NoxUI.L(tipText)) or tipText)
        end
    end)
    tip:SetScript("OnLeave", function(self)
        NoxUI.HideWidgetTooltip()
        self:SetAlpha(0.8)
    end)
    tip:RegisterForClicks("LeftButtonUp")
    tip:SetScript("OnClick", function(self)
        -- One shot: retire forever, then open the guide.
        MarkTipSeen(tipId)
        NoxUI.HideWidgetTooltip()
        self:Hide()
        Show(opts.guide or tipId)
    end)

    liveTips[tipId] = tip
    return tip
end

--- Re-evaluates every attached tip (the /euivideos reset brings retired ones back).
local function RefreshTips()
    for id, tip in pairs(liveTips) do
        tip:SetShown(not TipSeen(id))
    end
end

NoxUI.VideoGuides = {
    Register = function(id, def) guides[id] = def end,
    Show = Show,
    HasSeen = HasSeen,
    -- Stamps BEFORE showing: a crash/reload mid-popup can never re-fire a
    -- once-ever guide (it stays reachable via Show).
    FireOnce = function(id)
        if HasSeen(id) then return false end
        if not guides[id] then return false end
        MarkSeen(id)
        return Show(id)
    end,
    AttachTip = AttachTip,
    RefreshTips = RefreshTips,
    TipsEnabled = function() return true end,   -- tips always show until clicked
}

-- Reset command: clears the seen state for every video guide popup and every
-- tutorial tip badge, so all of them show again as if never clicked. Live
-- badges on the current UI reappear immediately.
SLASH_EUIVIDEOS1 = "/euivideos"
SlashCmdList["EUIVIDEOS"] = function()
    if NoxUIDB then
        NoxUIDB.videoGuidesSeen = nil
        NoxUIDB.tutorialTipsSeen = nil
    end
    RefreshTips()
    print(NoxUI.L("|cff00ff98NoxUI:|r Video guides and tutorial tips reset. Badges are back; one-time popups will fire again."))
end

-------------------------------------------------------------------------------
--  Guide #1: Settings Overrides
--  Fired by the spec-override toolbar glyph's first-ever click (see the
--  OnClick in nui_specialisation_exceptions_fenetres.lua / SpecOverrides_SetupButton).
--  Guide #4 (override_default_edit) shares its art: the one-time warning
--  fired by the first BASE edit of a setting that has an override.
-------------------------------------------------------------------------------
do
    local MODERN_SPRITE = "Interface\\AddOns\\NoxUI\\media\\icons\\class-full\\modern.tga"
    local ART_COORDS = {
        { 0, 0.125, 0, 0.125 },         -- WARRIOR
        { 0, 0.125, 0.25, 0.375 },      -- PALADIN
        { 0.125, 0.25, 0.25, 0.375 },   -- DEATHKNIGHT
    }

    -- Shared art: ghost card behind a gold override-group card (tank class
    -- glyphs + gold name line) with a play badge beside it. Each guide id builds
    -- its own band from this, so both popups read as the same system.
    local function OverridesArt(popup, ctx)
        local PPx, band = ctx.PP, ctx.band
        -- Ghost card behind (the layered-overrides read).
        local ghost = CreateFrame("Frame", nil, band)
        ghost:SetFrameLevel(band:GetFrameLevel() + 1)
        PPx.Size(ghost, 150, 52)
        PPx.Point(ghost, "CENTER", band, "CENTER", -39, -6)
        local gbg = ghost:CreateTexture(nil, "BACKGROUND")
        gbg:SetAllPoints()
        gbg:SetColorTexture(0.104, 0.096, 0.089, 1)
        ctx.MakeBorder(ghost, 1, 1, 1, 0.08, PPx)

        -- Gold override-group card (tank class glyphs + gold name line).
        local card = CreateFrame("Frame", nil, band)
        card:SetFrameLevel(band:GetFrameLevel() + 2)
        PPx.Size(card, 150, 52)
        PPx.Point(card, "CENTER", band, "CENTER", -31, 2)
        local cbg = card:CreateTexture(nil, "BACKGROUND")
        cbg:SetAllPoints()
        cbg:SetColorTexture(0.121, 0.113, 0.106, 1)
        ctx.MakeBorder(card, ctx.GOLD.r, ctx.GOLD.g, ctx.GOLD.b, 0.85, PPx)

        local ICON, GAP = 20, 8
        local rowW = #ART_COORDS * ICON + (#ART_COORDS - 1) * GAP
        for k, c in ipairs(ART_COORDS) do
            local tex = card:CreateTexture(nil, "ARTWORK")
            PPx.Size(tex, ICON, ICON)
            PPx.Point(tex, "LEFT", card, "LEFT",
                (150 - rowW) / 2 + (k - 1) * (ICON + GAP), 5)
            tex:SetTexture(MODERN_SPRITE)
            tex:SetTexCoord(c[1], c[2], c[3], c[4])
        end
        local line = card:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(ctx.GOLD.r, ctx.GOLD.g, ctx.GOLD.b, 0.75)
        PPx.Size(line, 56, 3)
        PPx.Point(line, "BOTTOM", card, "BOTTOM", 0, 6)

    end

    ---------------------------------------------------------------------------
    --  Guide #4: base edit of an overridden setting (one-time warning)
    --  Fired from NoxUI._NotifySettingWrite (nui_specialisation_exceptions_session.lua)
    --  the first time a Default Editing Mode edit lands on a gold-marked slot.
    --  Gold accent = the override system's own color; taller shell for the
    --  longer warning blurb (the OK button is bottom-anchored, so the extra
    --  height opens up between the URL hint and the button).
    ---------------------------------------------------------------------------
    NoxUI.VideoGuides.Register("override_default_edit", {
        eyebrow  = "OVERRIDES WARNING",
        accent   = GOLD,
        title    = "This Setting Has Overrides",
        blurb    = "You changed the default value of a setting that has overrides. Overrides keep their own values, so this change will not reach the specs or conditions they cover. To change it for an override, pick that override from the class glyph beside the module search bar and edit it there.",
        footnote = "Gold border settings have overrides. Hover info icon for details.",
        okText   = "I Understand",
        height   = 420,
        art      = OverridesArt,
    })
end

-------------------------------------------------------------------------------
--  Guide #5: addons that need an update ("addon_update")
--
--  Shown by the options panel (NoxUI_Panel.lua), once per session, when
--  another addon tried to change NoxUI's own settings pages. Names those
--  addons and links the plugin guide for addon authors.
-------------------------------------------------------------------------------
-- ONE paste point for the plugin guide on GitHub.
NoxUI.PLUGINS_API_URL = ""

do
    local def = {
        url       = NoxUI.PLUGINS_API_URL,
        width     = 580,
        artHeight = 96,
        urlWidth  = 520,
        gaps = {
            eyebrow = 20, title = 8, blurb = 14,
            bullets = 18, bulletRows = 8, url = 20, hint = 8,
            button = 46, footnote = 18,
        },
        art = function(popup, ctx)
            local PPx, band = ctx.PP, ctx.band
            local EG = ctx.accent
            local function Box(w, h, x, y, edgeR, edgeG, edgeB, edgeA)
                local f = CreateFrame("Frame", nil, band)
                f:SetFrameLevel(band:GetFrameLevel() + 2)
                PPx.Size(f, w, h)
                PPx.Point(f, "CENTER", band, "CENTER", x, y)
                local bg = f:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.056, 0.045, 0.034, 1)
                ctx.MakeBorder(f, edgeR, edgeG, edgeB, edgeA, PPx)
                return f
            end
            local function Bar(parent, w, h, x, y, r, g, b, a)
                local t = parent:CreateTexture(nil, "ARTWORK")
                t:SetColorTexture(r, g, b, a)
                PPx.Size(t, w, h)
                PPx.Point(t, "TOPLEFT", parent, "TOPLEFT", x, y)
                return t
            end

            -- The addon (a settings cog) plugging into a section of its own,
            -- below NoxUI's own rows in a mini settings panel.
            local tile = Box(50, 50, -104, 0, EG.r, EG.g, EG.b, 0.85)
            local cog = tile:CreateTexture(nil, "ARTWORK")
            cog:SetTexture("Interface\\AddOns\\NoxUI\\media\\icons\\cogs.png")
            cog:SetVertexColor(1, 1, 1, 0.85)
            PPx.Size(cog, 26, 26)
            PPx.Point(cog, "CENTER", tile, "CENTER", 0, 0)

            local arrow = ctx.MakeTriangle(band, 10, 12, EG.r, EG.g, EG.b, 0.9)
            PPx.Point(arrow, "CENTER", band, "CENTER", -60, 0)

            local panel = Box(170, 66, 44, 0, 1, 1, 1, 0.18)
            for i = 1, 3 do Bar(panel, 40, 4, 8, -(10 + (i - 1) * 8), 1, 1, 1, 0.18) end
            local own = CreateFrame("Frame", nil, panel)
            own:SetFrameLevel(panel:GetFrameLevel() + 1)
            PPx.Size(own, 46, 14)
            PPx.Point(own, "TOPLEFT", panel, "TOPLEFT", 5, -42)
            ctx.MakeBorder(own, EG.r, EG.g, EG.b, 0.85, PPx)
            Bar(own, 30, 4, 8, -5, EG.r, EG.g, EG.b, 0.9)
            Bar(panel, 1, 54, 58, -6, 1, 1, 1, 0.10)
            Bar(panel, 88, 4, 68, -12, 1, 1, 1, 0.16)
            Bar(panel, 70, 4, 68, -22, 1, 1, 1, 0.16)
            Bar(panel, 80, 4, 68, -32, 1, 1, 1, 0.16)
            Bar(panel, 60, 4, 68, -47, EG.r, EG.g, EG.b, 0.35)
        end,
    }
    NoxUI.VideoGuides.Register("addon_update", def)

    --- names: the addons' titles, sorted. One per bullet row (titles run
    --- long); the second row sums up any past the first two.
    function NoxUI.VideoGuides.ShowAddonUpdate(names)
        local n = #names
        def.eyebrow  = NoxUI.L("ADDON COMPATIBILITY")
        def.title    = n == 1 and NoxUI.Lf("%1$s Issue", names[1]) or NoxUI.L("Some Addons Need an Update")
        def.blurb    = NoxUI.L("To keep its settings safe, NoxUI now gives other addons their own section in the panel instead of letting them change its pages. The addons below haven't caught up yet, so those changes are hidden until they're updated. Everything else works as usual.")
        def.footnote = NoxUI.L("Addon authors: this guide shows how to add your settings to NoxUI.")
        def.okText   = NoxUI.L("Got It")
        local rows = { { names[1] } }
        if n == 2 then
            rows[2] = { names[2] }
        elseif n > 2 then
            rows[2] = { NoxUI.Lf("%1$s and %2$d more", names[2], n - 2) }
        end
        def.bullets = rows
        def.height = n > 1 and 481 or 460
        return NoxUI.VideoGuides.Show("addon_update")
    end
end
