if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-- Patch Notes and EUI Legends page builders; their content tables stay in nui_general_options.lua.

-- Options page pool (NoxUI_FramePool.lua): frames made here on a pool
-- host are reset and dressed again by the next build instead of made anew;
-- elsewhere this is CreateFrame.
local CreateFrame = NoxUI._Pool.CreateFrame
local PoolKeep, PoolGen = NoxUI._Pool.Keep, NoxUI._Pool.Gen

-- An accent-coloured piece repaints itself (paint(r, g, b)) when the accent
-- changes. Keyed by the piece: the page pool forgets the entry when it resets
-- it, and the kept Legends page registers each piece once.
local function OnAccent(obj, paint)
    NoxUI.RegAccent({ type = "callback", obj = obj, fn = paint })
end

-------------------------------------------------------------------------------
--  What's New page -- one expandable card per patch (the shared module card),
--  newest first. A card's header counts the patch's major features,
--  additional features and bug fixes; open, it shows the three tiers: hero
--  cards (2/row), small clickable listings, fix lines. Content:
--  NoxUI._WHATSNEW_PATCHES (newest first). Entry `nav` deep-links via
--  NavigateToElementSettings (opens page, pulses control); no `nav` = static
--  non-clickable card. File-scope fn so it adds no locals/upvalues to the
--  deferred options closure. whatsNewOpen: the open cards by version, for the
--  session (the newest starts open).
-------------------------------------------------------------------------------
local whatsNewOpen = {}
local NOTES_ICON = "Interface\\AddOns\\NoxUI\\media\\icons\\sidebar\\notes-off.png"
function NoxUI._BuildWhatsNewPage(pageName, parent, yOffset)
    local PP  = NoxUI.PanelPP
    local EG  = NoxUI.NOX_GREEN
    local PAD = NoxUI.CONTENT_PAD
    local W   = NoxUI.Widgets
    local MakeFont   = NoxUI.MakeFont
    local MakeBorder = NoxUI.MakeBorder

    -- This page is a free-form feed, not a DualRow split layout.
    parent._showRowDivider = nil

    local y = yOffset
    local totalW = parent:GetWidth() - PAD * 2
    local CARD_GAP = 14

    -- Display prefix: "Module: " on every entry, and "WoW Forever - " in the
    -- Forever theme's bronze ahead of it on entries flagged `forever = true`
    -- (changes that apply on WoW Forever only), "Retail - " in blue on entries
    -- flagged `retail = true` (changes that apply on retail only), shown on
    -- WoW Forever alone, or the game patch in violet on entries that apply
    -- from one retail patch on (`patch = "12.1.5"`), so the note text itself
    -- never has to say where it applies. Sorting stays by module, so a
    -- module's lines sit together whatever their tag.
    local FOREVER_TAG = "|cffdca77f" .. NoxUI.L("WoW Forever") .. "|r - "
    local RETAIL_TAG = NoxUI.IS_FOREVER and ("|cff74b9ff" .. NoxUI.L("Retail") .. "|r - ") or nil
    local function PrefixOf(e)
        local tag = (e.forever and FOREVER_TAG) or (e.retail and RETAIL_TAG)
            or (e.patch and ("|cffa88bff" .. e.patch .. "|r - ")) or ""
        return tag .. ((e.module and NoxUI.L(e.module) .. ": ") or "")
    end
    -- Display title: "Module: Title" (see PrefixOf).
    local function TitleOf(e)
        return PrefixOf(e) .. (NoxUI.L(e.title) or "")
    end

    -- Stable sort by module display name; preserves authored order per module.
    local function SortByModule(list)
        local idx = {}
        for i, e in ipairs(list) do idx[i] = { e, i } end
        table.sort(idx, function(a, b)
            local am, bm = a[1].module or "", b[1].module or ""
            if am ~= bm then
                -- Localization always closes the list.
                if am == "Localization" or bm == "Localization" then return bm == "Localization" end
                return am < bm
            end
            return a[2] < b[2]
        end)
        local out = {}
        for i = 1, #idx do out[i] = idx[i][1] end
        return out
    end

    -- An entry's nav target: its nav while the nav's module is registered, else nil.
    -- A module that is off (or not on this client) has no page to open, and the
    -- nav's preSelect may call that module's own setters; such a card renders static.
    local function NavTarget(nav)
        if nav and nav.module and NoxUI:GetModuleTitle(nav.module) then return nav end
    end

    -- Deep-link to a setting (opens the page; highlights the control if mapped).
    local function GoTo(nav)
        nav = NavTarget(nav)
        if nav then
            NoxUI:NavigateToElementSettings(nav.module, nav.page, nav.section, nav.preSelect, nav.highlight)
        end
    end

    -- Tier 1: clickable hero card -- dark fill, faint border, green top accent, title + wrapping description, hover lift.
    local function MakeHeroCard(x, cy, w, hgt, entry)
        local card = CreateFrame("Button", nil, parent)
        PP.Size(card, w, hgt)
        PP.Point(card, "TOPLEFT", parent, "TOPLEFT", x, cy)
        card:SetFrameLevel(parent:GetFrameLevel() + 2)

        local brd = NoxUI.MakeRoundedCard(card, 0.12, 0.50, 2)
        local bg, accent = brd.bg, brd.accent

        accent:SetColorTexture(EG.r, EG.g, EG.b, 0.6)
        OnAccent(accent, function(r, g, b) accent:SetColorTexture(r, g, b, 0.6) end)

        local titleFs = MakeFont(card, 14, nil, EG.r, EG.g, EG.b, 0.9)
        OnAccent(titleFs, function(r, g, b) titleFs:SetTextColor(r, g, b, 0.9) end)
        PP.Point(titleFs, "TOPLEFT", card, "TOPLEFT", 16, -14)
        PP.Point(titleFs, "RIGHT", card, "RIGHT", -16, 0)
        titleFs:SetJustifyH("LEFT"); titleFs:SetWordWrap(false)
        titleFs:SetText(TitleOf(entry))

        local descFs = MakeFont(card, 12, nil, 1, 1, 1, 0.45)
        PP.Point(descFs, "TOPLEFT", titleFs, "BOTTOMLEFT", 0, -7)
        PP.Point(descFs, "RIGHT", card, "RIGHT", -16, 0)
        descFs:SetJustifyH("LEFT"); descFs:SetJustifyV("TOP"); descFs:SetWordWrap(true)
        descFs:SetText(NoxUI.L(entry.desc) or "")

        -- Clickable only with a nav target. No nav renders a static card: no hover lift, no click, mouse disabled so nothing invites a dead click.
        if entry.onClick or NavTarget(entry.nav) then
            card:SetScript("OnEnter", function()
                bg:SetColorTexture(0.119, 0.111, 0.104, 0.50); brd:SetColor(1, 1, 1, 0.22)
                titleFs:SetAlpha(1)
            end)
            card:SetScript("OnLeave", function()
                bg:SetColorTexture(0.077, 0.068, 0.058, 0.50); brd:SetColor(1, 1, 1, 0.12)
                titleFs:SetAlpha(0.9)
            end)
            card:SetScript("OnClick", function()
            if entry.onClick then entry.onClick() else GoTo(entry.nav) end
        end)
        else
            card:EnableMouse(false)
        end
    end

    -- Tier 1b: full-width banner hero (entry.banner = true), styled after our
    -- own announcement popups: solid fill, white 1px border, green top accent, eyebrow
    -- + large centered title/description, plus mirrored mini bar-chart art flanking the
    -- text (cost stepping down left, fps stepping up right). Takes a whole row; height
    -- follows description. Static unless the entry carries a nav.
    local function MakeBannerCard(x, cy, w, entry)
        local card = CreateFrame("Button", nil, parent)
        -- Width set FIRST (height provisional): description anchors L+R to the card, so a width-0 card would truncate it to one line instead of wrapping.
        PP.Size(card, w, 100)
        PP.Point(card, "TOPLEFT", parent, "TOPLEFT", x, cy)
        card:SetFrameLevel(parent:GetFrameLevel() + 2)

        local brd = NoxUI.MakeRoundedCard(card, 0.15, 0.92, 2)
        local bg, accent = brd.bg, brd.accent

        -- Per-entry accent (entry.accent = {r,g,b}); the theme accent otherwise.
        local ac = entry.accent or EG
        -- Only the theme accent follows accent changes; a per-entry one is fixed.
        local function OnBannerAccent(obj, paint)
            if not entry.accent then OnAccent(obj, paint) end
        end
        accent:SetColorTexture(ac.r, ac.g, ac.b, 0.9)
        OnBannerAccent(accent, function(r, g, b) accent:SetColorTexture(r, g, b, 0.9) end)

        -- Flanking decorative bar-charts: dim white steps, accent "now" bar, faint baseline.
        -- They are the performance banner's art; a banner that carries its own
        -- logo (entry.logo) keeps its flanks clean instead.
        local BAR_W, BAR_GAP2 = 8, 4
        local function MakeChart(anchorSide, inset, heights, alphas)
            local groupW = #heights * BAR_W + (#heights - 1) * BAR_GAP2
            local base = card:CreateTexture(nil, "ARTWORK")
            base:SetColorTexture(1, 1, 1, 0.12)
            PP.Size(base, groupW, 1)
            if anchorSide == "LEFT" then
                PP.Point(base, "LEFT", card, "LEFT", inset, -12)
            else
                PP.Point(base, "RIGHT", card, "RIGHT", -inset, -12)
            end
            if PP.DisablePixelSnap then PP.DisablePixelSnap(base) end
            for i = 1, #heights do
                local bar = card:CreateTexture(nil, "ARTWORK")
                local a = alphas[i]
                if a == "green" then
                    bar:SetColorTexture(ac.r, ac.g, ac.b, 0.9)
                    OnBannerAccent(bar, function(r, g, b) bar:SetColorTexture(r, g, b, 0.9) end)
                else
                    bar:SetColorTexture(1, 1, 1, a)
                end
                PP.Size(bar, BAR_W, heights[i])
                PP.Point(bar, "BOTTOMLEFT", base, "TOPLEFT", (i - 1) * (BAR_W + BAR_GAP2), 1)
                if PP.DisablePixelSnap then PP.DisablePixelSnap(bar) end
            end
        end
        if not entry.logo then
            -- Left: cost falling to a low accent bar. Right: fps rising to a tall one.
            MakeChart("LEFT",  36, { 34, 26, 19, 13, 8 },  { 0.28, 0.23, 0.18, 0.14, "green" })
            MakeChart("RIGHT", 36, { 8, 13, 19, 26, 34 },  { 0.14, 0.18, 0.23, 0.28, "green" })
        end

        local eyebrow = MakeFont(card, 11, nil, ac.r, ac.g, ac.b, 0.9)
        OnBannerAccent(eyebrow, function(r, g, b) eyebrow:SetTextColor(r, g, b, 0.9) end)
        PP.Point(eyebrow, "TOP", card, "TOP", 0, -18)
        eyebrow:SetJustifyH("CENTER"); eyebrow:SetWordWrap(false)
        eyebrow:SetText(NoxUI.L(entry.eyebrow or "SPECIAL UPDATE"))

        -- Headline: banner titles stand alone (no "Module:" prefix), rendered
        -- LARGE like popup headlines -- or a logo texture stands in for the
        -- title (entry.logo = { path, coords = {l,r,t,b}, w, h }), the way the
        -- Forever launch popup uses the Forever wordmark as its headline.
        local headline, headH
        if entry.logo then
            local lg = card:CreateTexture(nil, "ARTWORK")
            lg:SetTexture(entry.logo.path)
            local c = entry.logo.coords
            if c then lg:SetTexCoord(c[1], c[2], c[3], c[4]) end
            PP.Size(lg, entry.logo.w or 250, entry.logo.h or 100)
            PP.Point(lg, "TOP", eyebrow, "BOTTOM", 0, -8)
            headline, headH = lg, entry.logo.h or 100
        else
            local titleFs = MakeFont(card, 24, nil, 1, 1, 1, 1)
            PP.Point(titleFs, "TOP", eyebrow, "BOTTOM", 0, -8)
            titleFs:SetJustifyH("CENTER"); titleFs:SetWordWrap(false)
            titleFs:SetText(NoxUI.L(entry.title) or "")
            headline, headH = titleFs, 24
        end

        local descFs = MakeFont(card, 13, nil, 1, 1, 1, 0.5)
        PP.Point(descFs, "TOP", headline, "BOTTOM", 0, -10)
        PP.Point(descFs, "LEFT", card, "LEFT", 110, 0)
        PP.Point(descFs, "RIGHT", card, "RIGHT", -110, 0)
        descFs:SetJustifyH("CENTER"); descFs:SetJustifyV("TOP"); descFs:SetWordWrap(true)
        descFs:SetText(NoxUI.L(entry.desc) or "")

        local dh = math.ceil(descFs:GetStringHeight() or 14)
        local bh = 18 + 11 + 8 + headH + 10 + dh + 28
        PP.Size(card, w, bh)

        if entry.onClick or NavTarget(entry.nav) then
            card:SetScript("OnEnter", function()
                brd:SetColor(1, 1, 1, 0.30)
                descFs:SetAlpha(0.65)
            end)
            card:SetScript("OnLeave", function()
                brd:SetColor(1, 1, 1, 0.15)
                descFs:SetAlpha(0.5)
            end)
            card:SetScript("OnClick", function()
            if entry.onClick then entry.onClick() else GoTo(entry.nav) end
        end)
        else
            card:EnableMouse(false)
        end
        return bh
    end

    -- Tier 1a: full-width VIDEO banner (entry.videoBanner = true) -- the biggest
    -- card the page renders: launch-video callouts. Same announcement chrome as
    -- the banner hero but taller type, a 3px accent, a play badge, mirrored
    -- play-glyph streams, and a read-only URL box that pre-selects itself so
    -- Ctrl+C is the only keystroke a user needs. URL: entry.url.
    local function MakeVideoBannerCard(x, cy, w, entry)
        local card = CreateFrame("Frame", nil, parent)
        -- Width FIRST (height provisional): the desc anchors L+R to the card.
        PP.Size(card, w, 200)
        PP.Point(card, "TOPLEFT", parent, "TOPLEFT", x, cy)
        card:SetFrameLevel(parent:GetFrameLevel() + 2)

        local brd = NoxUI.MakeRoundedCard(card, 0.18, 0.95, 3)
        local bg, accent = brd.bg, brd.accent

        accent:SetColorTexture(EG.r, EG.g, EG.b, 0.9)
        OnAccent(accent, function(r, g, b) accent:SetColorTexture(r, g, b, 0.9) end)

        -- Right-pointing play triangle: collapse the right edge of a color
        -- texture to its vertical midpoint (vertex 3 = UpperRight, 4 = LowerRight).
        local function Tri(host, pw, ph, r, g, b, a)
            local t = host:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(r, g, b, a or 1)
            PP.Size(t, pw, ph)
            t:SetVertexOffset(3, 0, -ph / 2)
            t:SetVertexOffset(4, 0, ph / 2)
            return t
        end

        -- Mirrored flanking streams: three play glyphs swelling toward the text.
        local defs = { { 16, 0.10 }, { 22, 0.16 }, { 28, 0.24 } }  -- outermost -> innermost
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local off = 40
            for i = 1, 3 do
                local sz, a = defs[i][1], defs[i][2]
                local t = Tri(card, math.floor(sz * 0.8), sz, EG.r, EG.g, EG.b, a)
                OnAccent(t, function(r, g, b) t:SetColorTexture(r, g, b, a) end)
                if side == "LEFT" then
                    PP.Point(t, "LEFT", card, "LEFT", off, 0)
                else
                    PP.Point(t, "RIGHT", card, "RIGHT", -off, 0)
                end
                off = off + math.floor(sz * 0.8) + 10
            end
        end

        local eyebrow = MakeFont(card, 12, nil, EG.r, EG.g, EG.b, 0.95)
        OnAccent(eyebrow, function(r, g, b) eyebrow:SetTextColor(r, g, b, 0.95) end)
        PP.Point(eyebrow, "TOP", card, "TOP", 0, -22)
        eyebrow:SetJustifyH("CENTER"); eyebrow:SetWordWrap(false)
        eyebrow:SetText(NoxUI.L(entry.eyebrow or "WATCH FIRST"))

        local titleFs = MakeFont(card, 30, nil, 1, 1, 1, 1)
        PP.Point(titleFs, "TOP", eyebrow, "BOTTOM", 0, -8)
        titleFs:SetJustifyH("CENTER"); titleFs:SetWordWrap(false)
        titleFs:SetText(NoxUI.L(entry.title) or "")

        local descFs = MakeFont(card, 13, nil, 1, 1, 1, 0.55)
        PP.Point(descFs, "TOP", titleFs, "BOTTOM", 0, -10)
        PP.Point(descFs, "LEFT", card, "LEFT", 120, 0)
        PP.Point(descFs, "RIGHT", card, "RIGHT", -120, 0)
        descFs:SetJustifyH("CENTER"); descFs:SetJustifyV("TOP"); descFs:SetWordWrap(true)
        descFs:SetText(NoxUI.L(entry.desc) or "")

        local url = entry.url or ""
        local FONT = NoxUI._font or ("Interface\\AddOns\\NoxUI\\media\\fonts\\Expressway.ttf")

        local urlWell = CreateFrame("Frame", nil, card)
        urlWell:SetFrameLevel(card:GetFrameLevel() + 2)
        PP.Size(urlWell, 400, 36)
        PP.Point(urlWell, "TOP", descFs, "BOTTOM", 0, -16)
        local wbg = urlWell:CreateTexture(nil, "BACKGROUND")
        wbg:SetAllPoints()
        wbg:SetColorTexture(0.045, 0.035, 0.027, 1)
        -- Neutral border: the link-blue text carries the "this is the link" read.
        NoxUI.MakeRoundedBorder(urlWell, 1, 1, 1, 0.22, wbg)

        -- Play badge standing left of the URL well (announcement-popup chip).
        local badge = CreateFrame("Frame", nil, card)
        badge:SetFrameLevel(card:GetFrameLevel() + 3)
        PP.Size(badge, 44, 44)
        PP.Point(badge, "RIGHT", urlWell, "LEFT", -16, 0)
        local chip = badge:CreateTexture(nil, "BACKGROUND")
        chip:SetAllPoints()
        chip:SetColorTexture(0.062, 0.050, 0.039, 0.95)
        local badgeBrd = MakeBorder(badge, EG.r, EG.g, EG.b, 0.85, PP)
        OnAccent(badge, function(r, g, b) badgeBrd:SetColor(r, g, b, 0.85) end)
        local btri = Tri(badge, 16, 18, 1, 1, 1, 0.95)
        PP.Point(btri, "CENTER", badge, "CENTER", 2, 0)

        -- Hint under the well; doubles as the Ctrl+C confirmation line.
        local hintFs = MakeFont(card, 11, nil, 1, 1, 1, 0.45)
        PP.Point(hintFs, "TOP", urlWell, "BOTTOM", 0, -8)
        hintFs:SetJustifyH("CENTER")
        hintFs:SetText(NoxUI.L("Click the link, then Ctrl+C to copy it"))

        local eb = CreateFrame("EditBox", nil, urlWell)
        eb:SetAllPoints(urlWell)
        eb:SetMultiLine(false)
        eb:SetAutoFocus(false)
        eb:SetFont(FONT, 13, "")
        eb:SetJustifyH("CENTER")
        eb:SetTextInsets(12, 12, 0, 0)
        eb:SetTextColor(0.55, 0.75, 1.0, 1)   -- link blue
        eb._readOnly = url
        eb:SetText(url)
        eb:SetCursorPosition(0)
        eb:SetScript("OnMouseUp", function(self)
            -- Next frame, unless a rebuild dressed the box again or put it
            -- away by then: a box put away (or under a card put away) is
            -- hidden, and a hidden box must not take the keyboard.
            local gen = PoolGen(self)
            C_Timer.After(0, function()
                if PoolGen(self) ~= gen or not self:IsVisible() then return end
                self:SetFocus(); self:HighlightText()
            end)
        end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- Read-only: typing/paste/cut restore the URL and re-select.
        eb:SetScript("OnChar", function(self)
            self:SetText(self._readOnly or ""); self:HighlightText()
        end)
        eb:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(self._readOnly or ""); self:HighlightText() end
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnKeyDown", function(self, key)
            if key == "C" and IsControlKeyDown() then
                hintFs:SetText(NoxUI.L("Link copied - paste it into your browser"))
                hintFs:SetTextColor(EG.r, EG.g, EG.b, 0.9)
                OnAccent(hintFs, function(r, g, b) hintFs:SetTextColor(r, g, b, 0.9) end)
            end
        end)

        local dh = math.ceil(descFs:GetStringHeight() or 14)
        local bh = 22 + 12 + 8 + 30 + 10 + dh + 16 + 36 + 8 + 11 + 22
        PP.Size(card, w, bh)
        return bh
    end

    -- Tier 2: clickable small listing -- title + subtitle, no card chrome, faint row highlight on hover.
    local function MakeListing(x, cy, w, entry)
        local ROW_H = 48
        local row = CreateFrame("Button", nil, parent)
        PP.Size(row, w, ROW_H)
        PP.Point(row, "TOPLEFT", parent, "TOPLEFT", x, cy)
        row:SetFrameLevel(parent:GetFrameLevel() + 2)

        local hov = row:CreateTexture(nil, "BACKGROUND")
        hov:SetAllPoints()
        hov:SetColorTexture(1, 1, 1, 0.07)
        hov:SetAlpha(0)

        local titleFs = MakeFont(row, 13, nil, 1, 1, 1, 0.9)
        PP.Point(titleFs, "TOPLEFT", row, "TOPLEFT", 6, -5)
        titleFs:SetJustifyH("LEFT"); titleFs:SetWordWrap(false)
        titleFs:SetText(TitleOf(entry))

        local subFs = MakeFont(row, 11, nil, 1, 1, 1, 0.4)
        PP.Point(subFs, "TOPLEFT", titleFs, "BOTTOMLEFT", 0, -4)
        PP.Point(subFs, "RIGHT", row, "RIGHT", -10, 0)
        subFs:SetJustifyH("LEFT"); subFs:SetWordWrap(false)
        subFs:SetText(NoxUI.L(entry.desc) or "")

        -- Clickable only with a nav target (see MakeHeroCard); else static.
        if entry.onClick or NavTarget(entry.nav) then
            row:SetScript("OnEnter", function()
                hov:SetAlpha(1); titleFs:SetAlpha(1)
            end)
            row:SetScript("OnLeave", function()
                hov:SetAlpha(0); titleFs:SetAlpha(0.9)
            end)
            row:SetScript("OnClick", function()
            if entry.onClick then entry.onClick() else GoTo(entry.nav) end
        end)
        else
            row:EnableMouse(false)
        end
        return ROW_H
    end

    -- Tier 3: a plain bug-fix line (bullet + wrapping text, not clickable),
    -- drawn on `host` (above the patch card's fill) from x to the card's inset.
    local function MakeFixLine(host, x, rightInset, cy, text)
        local dot = MakeFont(host, 12, nil, EG.r, EG.g, EG.b, 0.55)
        OnAccent(dot, function(r, g, b) dot:SetTextColor(r, g, b, 0.55) end)
        PP.Point(dot, "TOPLEFT", parent, "TOPLEFT", x + 2, cy - 1)
        dot:SetText("\226\128\162")  -- bullet glyph (ASCII-safe UTF-8 escape)
        local fs = MakeFont(host, 12, nil, 1, 1, 1, 0.5)
        PP.Point(fs, "TOPLEFT", parent, "TOPLEFT", x + 18, cy)
        PP.Point(fs, "RIGHT", parent, "RIGHT", -rightInset, 0)
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        fs:SetText(text or "")
        local th = fs:GetStringHeight() or 14
        return math.max(22, math.ceil(th) + 8)
    end

    local function MakeThanksLine(host, x, cy)
        local text = NoxUI.L("Thank you to all of our %s!") or "Thank you to all of our %s!"
        local label = MakeFont(host, 12, nil, 1, 1, 1, 0.5)
        PP.Point(label, "TOPLEFT", parent, "TOPLEFT", x, cy)
        label:SetText(text:format(NoxUI.L("contributors")))
        return 22
    end

    -- A tier's title (already localized) inside a patch card: the section label
    -- colour and a faint rule under it, inset with the card's content.
    local function TierHeader(host, x, cy, w, text)
        local ts = NoxUI.TEXT_SECTION
        local label = MakeFont(host, 12, nil, ts.r, ts.g, ts.b, ts.a)
        PP.Point(label, "TOPLEFT", parent, "TOPLEFT", x, cy - 16)
        label:SetText(text)
        local rule = host:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(1, 1, 1, 0.07)
        PP.Size(rule, w, 1)
        PP.Point(rule, "TOPLEFT", parent, "TOPLEFT", x, cy - 34)
        if PP.DisablePixelSnap then PP.DisablePixelSnap(rule) end
        return 40
    end

    local patches = NoxUI._WHATSNEW_PATCHES or {}
    y = y - 20
    local hasLinks = false
    for _, patch in ipairs(patches) do
        for _, entries in ipairs({patch.heroes or {}, patch.features or {}}) do
            for _, entry in ipairs(entries) do
                if entry.onClick or NavTarget(entry.nav) then
                    hasLinks = true
                    break
                end
            end
            if hasLinks then break end
        end
        if hasLinks then break end
    end
    local hint
    if hasLinks then
        hint = MakeFont(parent, 14, nil, 1, 1, 1, 0.5)
        PP.Point(hint, "TOP", parent, "TOP", 0, y)
        hint:SetJustifyH("CENTER")
        hint:SetText(NoxUI.L("Click any new feature to go directly to the setting"))
    end

    -- "New Patch Reminder Dot" opt-out for the pulsing sidebar dot shown when the account version increases (Patch Notes button in NoxUI.lua).
    do
        local BOX = 14
        local row = CreateFrame("Button", nil, parent)
        row:SetFrameLevel(parent:GetFrameLevel() + 2)
        local box = CreateFrame("Frame", nil, row)
        PP.Size(box, BOX, BOX)
        PP.Point(box, "LEFT", row, "LEFT", 0, 0)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetColorTexture(0.103, 0.095, 0.088, 1)
        local boxBrd = NoxUI.MakeRoundedBorder(box, 1, 1, 1, 0.25, boxBg)
        local check = box:CreateTexture(nil, "ARTWORK")
        PP.Point(check, "TOPLEFT", box, "TOPLEFT", 3, -3)
        PP.Point(check, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
        NoxUI.RoundBody(box, check, 1)
        local lbl = MakeFont(row, 12, nil, 1, 1, 1, 0.5)
        PP.Point(lbl, "LEFT", box, "RIGHT", 7, 0)
        lbl:SetText(NoxUI.L("New Patch Reminder Dot"))
        row:SetSize(BOX + 10 + (lbl:GetStringWidth() or 130), 20)
        PP.Point(row, "TOPRIGHT", parent, "TOPRIGHT", -PAD, y + 2)
        local function Paint()
            local on = not (NoxUIDB and NoxUIDB.patchDotDisabled)
            check:SetShown(on)
            check:SetColorTexture(EG.r, EG.g, EG.b, 1)
            if on then
                boxBrd:SetColor(EG.r, EG.g, EG.b, 0.85)
            else
                boxBrd:SetColor(1, 1, 1, 0.25)
            end
        end
        Paint()
        OnAccent(check, function() Paint() end)
        row:SetScript("OnClick", function()
            if not NoxUIDB then NoxUIDB = {} end
            NoxUIDB.patchDotDisabled = (not NoxUIDB.patchDotDisabled) and true or nil
            Paint()
            if NoxUI._UpdatePatchDot then NoxUI._UpdatePatchDot() end
        end)
        row:SetScript("OnEnter", function(self)
            lbl:SetAlpha(0.85)
            NoxUI.ShowWidgetTooltip(self, NoxUI.L("Show a pulsing dot on the Patch Notes button whenever NoxUI updates to a new version."))
        end)
        row:SetScript("OnLeave", function()
            lbl:SetAlpha(0.5)
            NoxUI.HideWidgetTooltip()
        end)
    end

    if #patches == 0 then
        local none = MakeFont(parent, 13, nil, 1, 1, 1, 0.5)
        PP.Point(none, "TOPLEFT", parent, "TOPLEFT", PAD, y - 24)
        none:SetText(NoxUI.L("No patch notes yet."))
        return math.abs(y) + 60
    end

    y = y - (hint and math.ceil(hint:GetStringHeight() or 14) or 0) - 20

    -- A patch card's content sits inset from the card's edges.
    local INSET = 16
    local innerX, innerW = PAD + INSET, totalW - INSET * 2

    -- One patch's tiers inside its open card, from cy down; returns the new cy.
    -- Text goes on a holder above the card's fill (frames already sit above it).
    local function BuildPatchContent(patch, cy)
        -- A "mini" patch is bugfix-only: just a `fixes` tier.
        local isMini = patch.mini
        local host = CreateFrame("Frame", nil, parent)
        host:SetAllPoints(parent)
        host:SetFrameLevel(parent:GetFrameLevel() + 2)
        cy = cy - 6

        -- Tier 1: hero cards, two per row, AUTHORED order (not module-sorted like features/fixes) -- reorder entries in _WHATSNEW_PATCHES to reorder cards.
        local heroes = patch.heroes or {}
        if #heroes > 0 then
            local cardW = math.floor((innerW - CARD_GAP) / 2)
            local CARD_H = 96
            -- Column state: heroes flow 2/row in authored order; a `banner` hero takes a full row, breaking then resuming the flow.
            local col = 0
            for _, hero in ipairs(heroes) do
                if hero.videoBanner then
                    if col == 1 then cy = cy - CARD_H - CARD_GAP; col = 0 end
                    local bh = MakeVideoBannerCard(innerX, cy, innerW, hero)
                    cy = cy - bh - CARD_GAP
                elseif hero.banner then
                    if col == 1 then cy = cy - CARD_H - CARD_GAP; col = 0 end
                    local bh = MakeBannerCard(innerX, cy, innerW, hero)
                    cy = cy - bh - CARD_GAP
                else
                    local cx = innerX + col * (cardW + CARD_GAP)
                    MakeHeroCard(cx, cy, cardW, CARD_H, hero)
                    col = col + 1
                    if col == 2 then cy = cy - CARD_H - CARD_GAP; col = 0 end
                end
            end
            if col == 1 then cy = cy - CARD_H - CARD_GAP end
            cy = cy + CARD_GAP - 4
        end

        -- Tier 2: small listings.
        local feats = SortByModule(patch.features or {})
        if #feats > 0 then
            cy = cy - TierHeader(host, innerX, cy, innerW, NoxUI.L("ADDITIONAL FEATURES"))
            cy = cy - 5  -- extra spacing below the divider
            for _, f in ipairs(feats) do
                local rh = MakeListing(innerX, cy, innerW, f); cy = cy - rh
            end
            cy = cy - 6
        end

        -- Tier 3: bug-fix lines. Full patches get a "BUG FIXES" header; a fixes-only mini patch drops it (the whole block is fixes), but a mini that also lists features keeps it so the fixes do not run on under them.
        local fixes = SortByModule(patch.fixes or {})
        if #fixes > 0 then
            if not isMini or #feats > 0 then
                cy = cy - TierHeader(host, innerX, cy, innerW, NoxUI.L("BUG FIXES"))
                cy = cy - 10  -- extra spacing below the divider
            end
            for _, fx in ipairs(fixes) do
                local fh = MakeFixLine(host, innerX, PAD + INSET, cy, PrefixOf(fx) .. (NoxUI.L(fx.text) or "")); cy = cy - fh
            end
        end
        if patch.thanks then
            cy = cy - 8
            cy = cy - MakeThanksLine(host, innerX, cy)
        end
        return cy - 4
    end

    -- One card per patch, newest first: the newest starts open. Show only the
    -- newest MAX_PATCHES entries; older ones may stay in the data table unshown.
    local MAX_PATCHES = 10
    local shown = math.min(#patches, MAX_PATCHES)
    local newestKey = patches[1].version or 1
    if whatsNewOpen[newestKey] == nil then whatsNewOpen[newestKey] = true end
    for pi = 1, shown do
        local patch = patches[pi]
        -- Header counts: hero cards (a launch-video banner is no feature), listings, fix lines.
        local heroN = 0
        for _, hero in ipairs(patch.heroes or {}) do
            if not hero.videoBanner then heroN = heroN + 1 end
        end
        local featN, fixN = #(patch.features or {}), #(patch.fixes or {})
        local parts = {}
        if patch.mini then parts[#parts + 1] = NoxUI.L("Mini Patch") end
        if heroN > 0 then parts[#parts + 1] = NoxUI.L("Major Features") .. ": " .. heroN end
        if featN > 0 then parts[#parts + 1] = NoxUI.L("Additional Features") .. ": " .. featN end
        if fixN > 0 then parts[#parts + 1] = NoxUI.L("Bug Fixes") .. ": " .. fixN end
        local tile = { key = patch.version or pi, display = "NoxUI " .. (patch.version or ""),
            desc = table.concat(parts, "    "),
            buildContent = function(_, cy) return BuildPatchContent(patch, cy) end }
        local newest = pi == 1
        y = NoxUI.BuildModuleCard(parent, y, W, tile, {
            enabled = true, expanded = whatsNewOpen, descW = 560, noSearch = true,
            glyph = function(hdr)
                local icon = hdr:CreateTexture(nil, "ARTWORK")
                PP.Size(icon, 28, 20)
                PP.Point(icon, "LEFT", hdr, "LEFT", 14, 0)
                icon:SetTexture(NOTES_ICON)
                if PP.DisablePixelSnap then PP.DisablePixelSnap(icon) end
                if newest then
                    icon:SetVertexColor(EG.r, EG.g, EG.b, 0.9)
                    OnAccent(icon, function(r, g, b) icon:SetVertexColor(r, g, b, 0.9) end)
                else
                    icon:SetVertexColor(1, 1, 1, 0.45)
                end
            end })
        -- "Latest" beside the newest card's title (its description hangs off the title).
        if newest then
            local _, title = tile._descFS:GetPoint(1)
            if title then
                local tag = MakeFont(tile._hdr, 11, nil, EG.r, EG.g, EG.b, 0.9)
                OnAccent(tag, function(r, g, b) tag:SetTextColor(r, g, b, 0.9) end)
                PP.Point(tag, "LEFT", title, "RIGHT", 10, 0)
                tag:SetText(NoxUI.L("Latest"))
            end
        end
    end

    return math.abs(y) + 20
end

