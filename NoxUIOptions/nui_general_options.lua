if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  nui_general_options.lua -- Global Settings module (CVar-based settings
--  shared by all NoxUI addons).
--
--  Default-application policy: EUI preferred defaults apply ONLY while
--  C_CVar.GetCVarInfo shows the CVar still at Blizzard's default (untouched
--  by player/other addon). Widgets always read the live CVar to stay in sync.
-------------------------------------------------------------------------------
local ADDON_NAME = ...

-- Options page pool (NoxUI_FramePool.lua): frames made here on a pool
-- host are reset and dressed again by the next build instead of made anew;
-- elsewhere this is CreateFrame.
local CreateFrame = NoxUI._Pool.CreateFrame

-------------------------------------------------------------------------------
--  Page / section names
-------------------------------------------------------------------------------
local PAGE_GENERAL      = "General"
local PAGE_FONTS       = "Fonts"     -- centralized fonts page; body lives in nui_polices_options.lua
local PAGE_TEXTURES    = "Textures"  -- centralized textures page; body lives in nui_textures_options.lua
local PAGE_GLOWS       = "Glows"     -- centralized glow page; body lives in nui_lueurs_options.lua
local PAGE_GAMEPAD     = "Gamepad"   -- controller settings page; body lives in nui_manette_options.lua
local PAGE_STYLE       = "Style"     -- per-module NoxUI / Blizzard Style page; body lives in nui_style_options.lua
local PAGE_COLORS      = "Colors"    -- the color half of the old "Fonts & Colors" page
local PAGE_NUMBERS     = "Numbers"   -- Number Format page; body lives in nui_nombre_format_options.lua
local PAGE_PROFILES    = "Profiles"
local PAGE_WHATSNEW    = "Patch Notes"

-- Profiles/Patch Notes/nui Legends are their own sidebar pages, not tabs under Global Settings. Keys match the sidebar buttons in NoxUI_Panel.lua.
local PROFILES_KEY     = "_EUIProfiles"
local PATCHNOTES_KEY   = "_EUIPatchNotes"

-- Standalone single-module builds rename the host addon to contain "Standalone". The What's New tab is suite-only, so it is never added to the page list there.
local IS_STANDALONE = type(ADDON_NAME) == "string" and ADDON_NAME:find("Standalone") ~= nil

-------------------------------------------------------------------------------
--  Shared CDM spell-layout export flow (full-profile AND per-addon export).
--  Asks to bundle the CDM spell layout (bar assignments + per-spell settings);
--  Yes opens the spec picker, then calls exportFn(includeCDM, cdmSpecs).
--  Exports ONLY on explicit "No" or a completed picker pick -- escaping
--  either popup produces NO export.
-------------------------------------------------------------------------------
function NoxUI.RunCDMSpellExportFlow(activeName, exportFn)
    local function pickThenExport()
        local specs = {}
        local sp = NoxUIDB and NoxUIDB.spellAssignments
            and NoxUIDB.spellAssignments.profiles
            and NoxUIDB.spellAssignments.profiles[activeName]
            and NoxUIDB.spellAssignments.profiles[activeName].specProfiles
        local n = NoxUI.IS_FOREVER and 0 or ((GetNumSpecializations and GetNumSpecializations()) or 0)
        for i = 1, n do
            local specID = GetSpecializationInfo and GetSpecializationInfo(i)
            if specID then
                local key = tostring(specID)
                local d = sp and sp[key]
                specs[#specs + 1] = {
                    key = key,
                    checked = (d and type(d.barSpells) == "table" and next(d.barSpells) ~= nil) and true or false,
                }
            end
        end
        -- WoW Forever: one row, the store key the player's class uses.
        if NoxUI.IS_FOREVER then
            local id = NoxUI.ForeverClassSpec(nil, NoxUI.SpecHasStringEntry, sp or {}, true)
            if id then
                local key = tostring(id)
                local d = sp and sp[key]
                specs[1] = {
                    key = key,
                    checked = (d and type(d.barSpells) == "table" and next(d.barSpells) ~= nil) and true or false,
                }
            end
        end
        NoxUI:ShowCDMSpecPickerPopup({
            title         = NoxUI.L("Export CDM Spells"),
            foreverAllKeys = true,
            subtitle      = NoxUI.L("This can't change which spells the user tracks in Blizzard's CDM.\nIt's recommended to also share your Blizzard CDM layout for any spec you choose here."),
            subtitleColor = { 1, 0.82, 0.2 },
            subtitleAtBottom = true,
            confirmText   = NoxUI.L("Export"),
            specs         = specs,
            onConfirm     = function(selectedSpecs) exportFn(true, selectedSpecs) end,
            onCancel      = function() end,  -- cancel / Esc / click-off: just close, NO export
        })
    end
    NoxUI:ShowConfirmPopup({
        title       = NoxUI.L("Include CDM Spell Layout?"),
        message     = NoxUI.L("Include your Cooldown Manager spell layout (which spells sit on which bars) plus all per-spell settings for any specs you choose."),
        confirmText = NoxUI.L("Yes"),
        cancelText  = NoxUI.L("No"),
        onConfirm   = function() pickThenExport() end,
        onCancel    = function() exportFn(false, nil) end,  -- "No": export WITHOUT layout
        onDismiss   = function() end,  -- Esc / click-off: just close, NO export
    })
end

-- Language-picker font: each entry is entirely one script (the CJK stock fonts
-- also cover the trailing "(Korean)"-style Latin text), so a plain per-entry
-- font from the locale system's own glyph table beats a multi-script family.
local function LP_FontFor(locale)
    local fn = NoxUI.LocaleGlyphFont
    return (fn and fn(locale)) or (NoxUI.MEDIA_PATH .. "fonts\\Expressway.TTF")
end

-------------------------------------------------------------------------------
--  Patch-notes content for the What's New page (newest first). Entry `nav`
--  deep-links via NavigateToElementSettings(module, page, section, preSelect, highlight).
-------------------------------------------------------------------------------
NoxUI._WHATSNEW_PATCHES = {
    {
        version = "0.2.3.6",
        features = {
            { module = "Dialogues de quête", title = "Corrections des quêtes", desc = "Les quêtes échouées peuvent être reprises. Les icônes et la difficulté des quêtes se mettent à jour et les évaluateurs d’objets sont enregistrés." },
            { module = "Carte du monde", title = "Protection des réglages", desc = "La carte ignore les vues invalides et retire les valeurs numériques non valides avant sauvegarde." },
            { module = "Carte du monde", title = "Partage de position", desc = "Une position en attente ne sera plus envoyée après la désactivation du partage." },
            { module = "Noms des personnages", title = "Plaques réutilisées", desc = "Les noms flottants vérifient leur association au personnage avant de réutiliser une plaque." },
        },
    },
    {
        version = "0.2.3.5",
        features = {
            { module = "Carte du monde", title = "Raccourci M", desc = "Le raccourci utilise la commande native de la carte et conserve OpenMap comme vue par défaut." },
            { module = "Canaux et messages", title = "Journal de combat détachable", desc = "L’habillage suit l’onglet pendant le déplacement et se resynchronise après réduction, restauration ou raccrochage." },
            { module = "Combat", title = "Retour aux chiffres flottants du jeu", desc = "Les animations de texte de combat ajoutées au dessus des cadres du joueur et de la cible ont été retirées." },
            { module = "Interface", title = "Suppression du mode festif", desc = "La page Ambiance de groupe, ses commandes, ses déclenchements et ses conditions de visibilité ont été retirés." },
            { module = "Menus", title = "Retrait des renvois promotionnels", desc = "Les guides YouTube et les renvois promotionnels hérités ont été retirés. L’import et l’export de profils restent accessibles." },
        },
    },
    {
        version = "0.2.3.4",
        features = {
            { module = "Temps de recharge", title = "Orientation des barres de suivi", desc = "L’aperçu et la barre suivent le même axe, même avec une ancienne configuration. Le réglage indique si les icônes sont réparties en lignes ou en colonnes." },
            { module = "Cadres de groupe et de raid", title = "Aperçus et navigation", desc = "Les aperçus Raid et Équipe sont ancrés au bord de la fenêtre pour dégager le menu latéral." },
            { module = "Première configuration", title = "Aperçu et validation du style", desc = "Les libellés du choix de style sont traduits en français. Le clic sélectionne un aperçu et le bouton Appliquer le style valide le choix." },
        },
    },
    {
        version = "0.2.3.3",
        features = {
            { module = "Interface", title = "Position des boutons du menu de jeu", desc = "Les boutons suivants sont décalés dès le premier affichage du menu." },
            { module = "Carte du monde", title = "Plafond d’images conservé", desc = "OpenMap garde le plafond choisi, y compris lorsqu’il est désactivé." },
            { module = "Dialogues de quête", title = "Restaurer la caméra", desc = "La fermeture du dialogue retrouve le zoom initial. La prise en charge de DynamicCam attend son chargement et restitue son contrôle en fin de dialogue." },
            { module = "Fenêtres du jeu", title = "Contrôler les achats par lots", desc = "Le prix, la quantité et la disponibilité sont vérifiés avant chaque envoi au marchand." },
            { module = "Confort de jeu", title = "Remerciements avec le nom complet", desc = "Sur WoW Forever, le chuchotement et l’échange de langue exigent le prénom et le nom du destinataire. La réception du remerciement pour Bénédiction des rois a été confirmée en jeu." },
            { module = "Carte du monde", title = "Onglets en haut de la carte", desc = "Les boutons OpenMap, Routes, 2D et 3D remplacent les anciens onglets en haut de la carte." },
        },
    },
    {
        version = "0.2.3",
        features = {
            { module = "Carte du monde", title = "OpenMap par défaut", desc = "Le raccourci de la carte ouvre OpenMap. Les boutons Routes, 2D et 3D donnent accès aux itinéraires et aux vues aériennes de Forever Maps." },
            { module = "Journal des donjons", title = "Habillage NoxUI", desc = "DungeonJournal adopte des panneaux ardoise et des boutons plats. Les instances conservent leurs accents sur le bandeau, les titres et les sélections." },
            { module = "Confort de jeu", title = "Alertes de ravitaillement", desc = "Des seuils réglables signalent le manque de munitions et de composants de sorts pris en charge. La durabilité conserve son réglage dédié." },
            { module = "Marchand", title = "Confirmation des achats en quantité", desc = "Maj et clic ouvre le sélecteur. Le total est affiché avant validation et l’offre est vérifiée à nouveau au moment de l’achat." },
            { module = "Personnages", title = "Vue du compte et suivi des recettes", desc = "Consulte l’or, les places libres, l’XP de repos et le dernier relevé du courrier. Les infobulles de recettes utilisent les métiers relevés sur tes autres personnages." },
            { module = "Hôtel des ventes", title = "Son de vente et aperçu", desc = "Le son de caisse NoxUI dispose d’un canal réglable. L’aperçu utilise le canal principal si les effets sonores sont coupés." },
            { module = "Inventaire", title = "Quantités entre personnages", desc = "Les infobulles peuvent inclure les objets relevés dans les sacs, la banque, le courrier et les enchères. Les sources distantes gardent leurs dates d’expiration." },
            { module = "Placement", title = "Accès direct aux réglages", desc = "Alt et clic droit sur un élément en mode Placement ouvre sa page de réglages." },
            { module = "Confort de jeu", title = "Demandes en jeu", desc = "Des options séparées permettent de refuser les duels d’inconnus et de gérer les invitations à une résurrection ou à une invocation hors combat. Maj rend la main." },
            { module = "Interface", title = "Formes des boutons et redimensionnement du chat", desc = "Les barres d’action disposent de réglages de forme et de bordure appliqués aux boutons. Le chat peut s’agrandir vers le haut en gardant son bord inférieur en place." },
        },
    },
    {
        version = "0.2.2",
        features = {
            { module = "Confort de jeu", title = "Remerciements de buffs", desc = "Trente formules en français, anglais et espagnol. Le mode Auto utilise la langue du destinataire si NoxUI la reçoit, et l’anglais par défaut." },
            { module = "Interface", title = "Navigation et traductions", desc = "Plus de place dans la liste latérale, nouveau pictogramme Placement et traductions du chat et de l’alerte Leatrix Plus." },
            { module = "Campement", title = "Déployer le sac de couchage", desc = "La feuille du campement utilise le sac de couchage depuis l’inventaire." },
        },
    },
    {
        version = "0.2.1",
        features = {
            { module = "Installation", title = "Installateurs synchronisés", desc = "Les éditions Windows et Linux embarquent le même contenu NoxUI." },
            { module = "Cartes", title = "OpenMap et guidage", desc = "OpenMap passe en 0.8.9 et le calcul de l’heure d’arrivée est déclaré correctement dans Waypoint UI." },
            { module = "Interface", title = "Lisibilité et confort", desc = "Commandes plus lisibles, voile de furtivité et protection des objets épinglés lors des ventes automatiques." },
        },
    },
    {
        version = "0.2.0",
        features = {
            { module = "Interface", title = "Navigation et identité NoxUI", desc = "Menus réorganisés et francisés, accès rapides à l’interface, aux graphismes, aux profils et au placement. Les liens promotionnels, les guides vidéo hérités et la page Légendes ont été retirés." },
            { module = "Interface", title = "Habillage ardoise et rouge", desc = "Nouveaux fonds et pictogrammes NoxUI. Les icônes de navigation et de métiers utilisent des tons argentés pour rester lisibles en jeu." },
            { module = "Placement", title = "Mode déverrouillage", desc = "Animation d’entrée avec le logo NoxUI, bandeau sans cadenas hérité, aide revue et grille ardoise." },
            { module = "Graphismes", title = "Réglages avancés et optimisation", desc = "Accès direct depuis le menu NoxUI aux réglages de netteté, végétation, distance de vue, détails du monde, luminosité et contraste." },
            { module = "Minicarte", title = "Minicarte carrée et raccourcis", desc = "Disposition carrée native avec restauration de la disposition précédente, accès aux options des addons via le N de NoxUI et menu de téléportation inspiré de Vista. Les destinations sont filtrées selon les objets, jouets et sorts connus du personnage." },
            { module = "Cartographie", title = "OpenMap et ForeverMaps", desc = "OpenMap rejoint la suite. ForeverMaps reçoit un habillage NoxUI et un bouton Carte du monde en haut à gauche qui ouvre OpenMap. La carte ForeverMaps reste fournie par son addon." },
            { module = "Guidage", title = "Waypoint UI intégré", desc = "Repères et navigation disponibles dans Guidage et destinations, avec onglets et contrôles NoxUI pour les préférences, les points de passage, la carte, la navigation, l’apparence et l’audio." },
            { module = "Quêtes", title = "Dialogue UI intégré", desc = "Dialogue avec les PNJ et lecture des livres dans NoxUIDialogueUI. Les réglages sont regroupés dans les onglets Apparence, Caméra, Contrôles, Jeu et Accessibilité. La caméra peut se rapprocher pendant les dialogues et restaurer le zoom à leur fermeture." },
            { module = "Options", title = "Réglages natifs", desc = "Les panneaux imbriqués de Dialogue UI, Waypoint UI et OpenMap sont remplacés par des contrôles NoxUI. Les entrées individuelles des modules intégrés sont retirées des options de WoW." },
            { module = "Alertes", title = "Annonces animées", desc = "Alertes facultatives pour les zones, les niveaux, les hauts faits, les quêtes acceptées ou rendues, les messages de boss, les scénarios terminés et certaines créatures rares vaincues. Les annonces du jeu restent actives." },
            { module = "Butin", title = "Lueurs et flux de butin", desc = "Interrupteur NoxUI pour les lueurs des objets de quête. Les filtres du flux de butin pour les objets, l’argent, la réputation et les monnaies sont francisés." },
            { module = "Inventaire", title = "Objets de quête et matériaux", desc = "Aura dorée et Q ardoise sur les objets de quête. L’infobulle peut donner le nom de la quête si le client fournit ce lien. Un compteur peut suivre un matériau choisi à partir de son identifiant ou d’un lien d’objet." },
            { module = "Groupe", title = "Phase et marqueurs sociaux", desc = "La demande de synchronisation de phase rejoint la barre de plugins. Les noms peuvent afficher un losange bleu pour le groupe, un rond doré pour la guilde et un carré rouge pour le raid, avec réglages séparés." },
            { module = "Barre de plugins", title = "Noms, icônes et lisibilité", desc = "Terminologie française, icônes retravaillées pour le micro menu et les métiers, et ombres sous les icônes et les textes." },
            { module = "Addons externes", title = "Habillages compatibles", desc = "Premiers habillages NoxUI pour AtlasLoot, Questie, Hekili, Auctionator et Syndicator, appliqués à leurs surfaces prises en charge." },
        },
    },
    {
        version = "0.1.8",
        features = {
            { module = "Groupe", title = "Bouton de phase", desc = "En groupe, demandez au jeu de rafraîchir votre phase depuis un bouton déplaçable." },
        },
    },
    {
        version = "0.1.7",
        features = {
            { module = "Interface", title = "Visuels NoxUI", desc = "De nouveaux pictogrammes rejoignent les menus et les modules." },
            { module = "Classes", title = "Emblèmes de classe", desc = "Les emblèmes disponibles ont été adaptés au panneau NoxUI." },
        },
        fixes = {
            { module = "Interface", text = "Le chemin des emblèmes de classe a été corrigé." },
        },
    },
    {
        version = "0.1.6",
        fixes = {
            { module = "Profils", text = "Un import en cours est annulé lorsqu'une nouvelle demande le remplace." },
        },
    },
    {
        version = "0.1.5",
        features = {
            { module = "NoxUI", title = "Identité et accès", desc = "La commande /nui ouvre les options de NoxUI." },
            { module = "NoxUI", title = "Modules en français", desc = "Les modules ont été renommés avec une migration des clés de profil." },
            { module = "Graphismes", title = "Réglages avancés", desc = "Ajustez la végétation, la distance de vue et les détails du monde." },
        },
        fixes = {
            { module = "Traductions", text = "Le chargement des langues reçoit uniquement le nom du personnage." },
            { module = "Raid", text = "L'affichage des noms utilise uniquement le nom de l'unité." },
            { module = "Profils", text = "Certaines données de profil mal formées ou trop imbriquées sont refusées." },
        },
    },
}

-------------------------------------------------------------------------------
--  FCT font -- handled by NoxUI_Startup.lua which runs earlier.
-------------------------------------------------------------------------------

-- Wait for NoxUI to exist
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not NoxUI or not NoxUI.RegisterModule then return end
    local PP = NoxUI.PanelPP

    local GLOBAL_KEY = NoxUI.GLOBAL_KEY or "_EUIGlobal"
    local floor = math.floor
    local ceil  = math.ceil
    local max   = math.max

    ---------------------------------------------------------------------------
    --  CVar helpers
    ---------------------------------------------------------------------------
    local function GetCVarNum(cvar)
        return tonumber(GetCVar(cvar)) or 0
    end

    local function SetCVarSafe(cvar, value)
        if InCombatLockdown() then return end
        NoxUI.SetCVar(cvar, value)
    end

    -- Graphics and sound settings (Optimize My FPS and Graphics, its Restore and
    -- Increase Game Image Quality) are written as they are, not through
    -- NoxUI.SetCVar: Optimize keeps its own Restore, and Uninstall EUI
    -- never touches them.
    local function SetGfxCVar(cvar, value)
        if InCombatLockdown() then return end
        SetCVar(cvar, value)
    end

    --- Returns current, default as strings (nil-safe)
    local function CVarInfo(cvar)
        local cur, def = C_CVar.GetCVarInfo(cvar)
        return cur or "", def or ""
    end

    --- True while the CVar sits at Blizzard's built-in default (untouched by player or addon).
    local function IsAtBlizzardDefault(cvar)
        local cur, def = CVarInfo(cvar)
        return cur == def
    end

    ---------------------------------------------------------------------------
    --  EUI preferred defaults -- only applied when CVar == Blizzard default
    --
    --  { cvarName, euiPreferred }
    ---------------------------------------------------------------------------
    local EUI_DEFAULTS = {
        { "cameraDistanceMaxZoomFactor",                    "2.6" },
        { "ActionButtonUseKeyDown",                         "1"   },
    }

    --- Walk the table once at login and apply only where safe.
    local function ApplySmartDefaults()
        for _, entry in ipairs(EUI_DEFAULTS) do
            local cvar, preferred = entry[1], entry[2]
            if IsAtBlizzardDefault(cvar) then
                SetCVarSafe(cvar, preferred)
            end
        end
    end
    ApplySmartDefaults()

    -- Apply suppress lua errors on login (default: ON)
    if not NoxUIDB or NoxUIDB.suppressErrors ~= false then
        SetCVarSafe("scriptErrors", "0")
    end

    -- Optimized graphics settings are NOT re-applied on login: SetCVar already persists, so re-applying would override the user's manual adjustments.

        -------------------------------------------------------------------
        --  Optimized graphics CVar table + buttons (above all sections)
        -------------------------------------------------------------------
        local OPTIMIZED_CVARS = {
            { "graphicsShadowQuality",      "1" },
            { "graphicsLiquidDetail",       "0" },
            { "graphicsParticleDensity",    "5" },
            { "graphicsSSAO",              "0" },
            { "graphicsDepthEffects",       "0" },
            { "graphicsComputeEffects",     "0" },
            { "graphicsOutlineMode",        "0" },
            { "graphicsTextureResolution",  "2" },
            { "graphicsSpellDensity",       "0" },
            { "graphicsProjectedTextures",  "1" },
            { "graphicsViewDistance",        "0" },
            { "graphicsEnvironmentDetail",  "0" },
            { "graphicsGroundClutter",      "0" },
            { "RAIDsettingsEnabled",        "0" },
            { "ResampleAlwaysSharpen",      "1" },
            -- Reverb runs a full effect bus over the mix; disabling it trims audio DSP work and keeps spell/interrupt cues dry and crisp.
            { "Sound_EnableReverb",         "0" },
        }

        local function ApplyOptimizedGfx()
            -- Refused in combat, where SetGfxCVar writes nothing: a backup taken
            -- then would turn the card into Restore with nothing optimized.
            if InCombatLockdown() then return end
            if not NoxUIDB then NoxUIDB = {} end
            -- One-time store: only snapshot if no backup exists yet
            if not NoxUIDB.gfxBackup then
                local backup = {}
                for _, entry in ipairs(OPTIMIZED_CVARS) do
                    backup[entry[1]] = GetCVar(entry[1])
                end
                backup["Contrast"] = GetCVar("Contrast")
                NoxUIDB.gfxBackup = backup
            else
                -- Backfill CVars added to the list after the original snapshot so Restore covers them too.
                local backup = NoxUIDB.gfxBackup
                for _, entry in ipairs(OPTIMIZED_CVARS) do
                    if backup[entry[1]] == nil then
                        backup[entry[1]] = GetCVar(entry[1])
                    end
                end
            end
            for _, entry in ipairs(OPTIMIZED_CVARS) do
                SetGfxCVar(entry[1], entry[2])
            end
            local curContrast = tonumber(GetCVar("Contrast")) or 50
            if curContrast <= 55 then
                SetGfxCVar("Contrast", curContrast + 10)
            end
            local rl = NoxUI._widgetRefreshList
            if rl then for i = 1, #rl do rl[i]() end end
        end

        local function RestoreGfxSettings()
            if not NoxUIDB or not NoxUIDB.gfxBackup then return end
            if InCombatLockdown() then return end
            local backup = NoxUIDB.gfxBackup
            for _, entry in ipairs(OPTIMIZED_CVARS) do
                local saved = backup[entry[1]]
                if saved then SetGfxCVar(entry[1], saved) end
            end
            if backup["Contrast"] then SetGfxCVar("Contrast", backup["Contrast"]) end
            NoxUIDB.gfxBackup = nil
            local rl2 = NoxUI._widgetRefreshList
            if rl2 then for i = 1, #rl2 do rl2[i]() end end
        end

    NoxUI._GraphicsOptimization = { Apply = ApplyOptimizedGfx, Restore = RestoreGfxSettings }

    local function BuildGraphicsActions(parent, y)
        -------------------------------------------------------------------
        --  TOP SECTION: one row, Reset EUI Module Settings | Optimize My FPS
        --  and Graphics | Uninstall EUI. While a graphics backup exists the
        --  Optimize card restores it instead.
        -------------------------------------------------------------------
        local MEDIA_ICONS = "Interface\\AddOns\\NoxUI\\media\\icons\\"
        -- Red for stop (Reset ALL, Uninstall, Restore), NoxUI's own green
        -- (#0cd29d) for go (Optimize and its link): fixed, never the theme accent.
        local WARN = { r = 0.9, g = 0.3, b = 0.3 }
        local GO = { r = 184 / 255, g = 195 / 255, b = 204 / 255 }

        -- Reset ALL's wipe: every EUI addon back to its defaults.
        local function ResetAllNow()
            -- Nuclear wipe: same logic as the beta-exit popup
            local svNames = {
                "NoxUIActionBarsDB",
                "NoxUIAuraBuffRemindersDB",
                "NoxUICooldownManagerDB",
                "NoxUINameplatesDB",
                "NoxUIResourceBarsDB",
                "NoxUIUnitFramesDB",
            }
            for _, name in ipairs(svNames) do
                _G[name] = {}
            end
            -- Loadout Manager keeps a per-character store outside the profiles:
            -- this clears it for the character doing the reset.
            NoxUILoadoutManagerDB = nil
            -- Bags' offline bank keeps every character's saved bags and banks outside them too
            NoxUIBagsInventoryDB = nil
            local oldScale = NoxUIDB and NoxUIDB.ppUIScale
            local oldScaleAuto = NoxUIDB and NoxUIDB.ppUIScaleAuto
            -- Preserve friend group data across reset
            local oldGlobal = NoxUIDB and NoxUIDB.global
            local savedFriends
            if oldGlobal then
                savedFriends = {
                    friendGroups = oldGlobal.friendGroups,
                    friendGroupsByTag = oldGlobal.friendGroupsByTag,
                    friendGroupsTagMigrated = oldGlobal.friendGroupsTagMigrated,
                    friendAssignments = oldGlobal.friendAssignments,
                    friendGroupOrder = oldGlobal.friendGroupOrder,
                    friendGroupColors = oldGlobal.friendGroupColors,
                    friendNotes = oldGlobal.friendNotes,
                    friendFavCollapsed = oldGlobal.friendFavCollapsed,
                    friendPendingCollapsed = oldGlobal.friendPendingCollapsed,
                    friendUngroupedCollapsed = oldGlobal.friendUngroupedCollapsed,
                }
            end
            -- Preserve QoL settings (stored on NoxUIDB root)
            local qolKeys = {
                "autoOpenContainers", "autoSellJunk", "autoRepair",
                "autoRepairGuild", "hideScreenshotStatus", "autoUnwrapCollections",
                "trainAllButton", "ahCurrentExpansion", "quickLoot",
                "autoFillDelete", "skipCinematics", "skipCinematicsAuto",
                "bonusRollConfirmation", "bonusRollOnly",
                "autoInsertKeystone", "quickSignup",
                "persistSignupNote", "signupNote", "hideBlizzardPartyFrame",
                "instanceResetAnnounce", "instanceResetAnnounceMsg",
                "macroFactory",
            }
            local savedQoL = {}
            for _, k in ipairs(qolKeys) do
                if NoxUIDB[k] ~= nil then
                    savedQoL[k] = NoxUIDB[k]
                end
            end
            -- Game settings, not EUI ones: the record of the settings from
            -- before EUI (Uninstall EUI) and Optimize Graphics' Restore values.
            local oldRestore = NoxUIDB.restoreOnUninstall
            local oldGfx = NoxUIDB.gfxBackup
            _G["NoxUIDB"] = {}
            NoxUIDB = _G["NoxUIDB"]
            NoxUIDB.restoreOnUninstall = oldRestore
            NoxUIDB.gfxBackup = oldGfx
            if oldScale then NoxUIDB.ppUIScale = oldScale end
            if oldScaleAuto ~= nil then NoxUIDB.ppUIScaleAuto = oldScaleAuto end
            if savedFriends then
                if not NoxUIDB.global then NoxUIDB.global = {} end
                for k, v in pairs(savedFriends) do
                    NoxUIDB.global[k] = v
                end
            end
            for k, v in pairs(savedQoL) do
                NoxUIDB[k] = v
            end
        end

        -- Reset ALL: a typed confirm, then the wipe and a reload (the wipe runs
        -- as RequestReload's pre-reload work).
        local function ConfirmResetAll()
            NoxUI:ShowConfirmPopup({
                title         = "Reset ALL Settings",
                -- The wipe replaces the whole account store, profiles included.
                message       = "Are you sure you want to reset ALL EUI addon settings to their defaults? This deletes ALL of your profiles, not just the current one, and reloads your UI.",
                disclaimer    = "Every profile on this account is deleted. Export any profile you want to keep first.",
                typeToConfirm = "Confirm",
                confirmText   = "Reset All & Reload",
                cancelText    = "Cancel",
                onConfirm     = function()
                    NoxUI.RequestReload(NoxUI.L("Reset ALL Settings"),
                        NoxUI.L("Reload to finish resetting EUI."), ResetAllNow)
                end,
            })
        end

        -- Uninstall EUI is refused in combat (it reloads) and while Edit Mode is open (it
        -- saves its own copy of the layouts on exit, over the ones put back). True when
        -- it was refused.
        local function UninstallRefused()
            local msg
            if InCombatLockdown() then
                msg = NoxUI.L("Uninstalling reloads the UI and cannot run in combat. Leave combat and try again.")
            elseif NoxUI.EditModeOpen() then
                msg = NoxUI.L("Close Edit Mode first, then try again.")
            end
            if not msg then return false end
            NoxUI:ShowConfirmPopup({
                title       = NoxUI.L("Uninstall EUI"),
                message     = msg,
                confirmText = NoxUI.L("OK"),
                hideCancel  = true,
            })
            return true
        end

        -- Uninstall EUI: puts back the game settings NoxUI changed, turns it off for
        -- every character and reloads (NoxUI_Uninstall.lua). Profiles are kept. The
        -- reload is a RequestReload from onConfirm, not reload = true: the refusal is
        -- checked again there, and reload = true would reload even when it is refused.
        local function ConfirmUninstall()
            if UninstallRefused() then return end
            local message = NoxUI.L("Puts back the game settings EUI changed, such as nameplate, action bar, chat and tooltip options, and turns EUI off for every character, then reloads the UI.") .. "\n\n"
                .. NoxUI.L("Your profiles are kept, so you can turn EUI back on later in the AddOns list.")
            if NoxUIDB and NoxUIDB.gfxBackup then
                message = message .. "\n\n" .. NoxUI.L("Graphics changed by Optimize My FPS and Graphics stay as they are. To undo them, click Restore My Graphics Settings first.")
            end
            NoxUI:ShowConfirmPopup({
                title         = NoxUI.L("Uninstall EUI"),
                message       = message,
                disclaimer    = (not NoxUI.UninstallKnowsOriginals())
                    and NoxUI.L("EUI was installed before it kept a record of your original settings, so the settings it still manages go back to the game's defaults.")
                    or nil,
                confirmText   = NoxUI.L("Uninstall & Reload"),
                cancelText    = NoxUI.L("Cancel"),
                onConfirm     = function()
                    if UninstallRefused() then return end
                    NoxUI.RequestReload(NoxUI.L("Uninstall EUI"),
                        NoxUI.L("Reload to finish uninstalling EUI."), NoxUI.Uninstall)
                end,
            })
        end

        -- The first card's two forms: Optimize, or Restore while a backup exists
        -- (restore given: that form, else the current one).
        local function HasGfxBackup() return (NoxUIDB and NoxUIDB.gfxBackup) ~= nil end
        local function GfxCardContent(restore)
            if restore == nil then restore = HasGfxBackup() end
            if restore then
                return MEDIA_ICONS .. "undo.png", NoxUI.L("Restore My Graphics Settings"),
                    NoxUI.L("Put back your graphics from before optimizing.")
            end
            return MEDIA_ICONS .. "optimize.png", NoxUI.L("Optimize My FPS and Graphics"),
                NoxUI.L("Tune graphics for higher FPS and clarity.")
        end

        -- One row of plain text buttons: Reset ALL, then in the middle Optimize
        -- (a boxed button, with its "What Does This Do?" link under it) or
        -- Restore (plain and red like the others), then Uninstall.
        local GFX_GAP = 8

        -- "What Does This Do?": what Optimize changes. Built first, so the
        -- card's footer can take its measured height.
        local infoBtn = CreateFrame("Button", nil, parent)
        infoBtn:SetFrameLevel(parent:GetFrameLevel() + 5)
        local infoH
        do
            local EG = GO
            local infoFS = infoBtn:CreateFontString(nil, "OVERLAY")
            infoFS:SetFont(NoxUI.EXPRESSWAY, 12, NoxUI.GetFontOutlineFlag())
            infoFS:SetTextColor(EG.r, EG.g, EG.b, 0.70)
            infoFS:SetText(NoxUI.L("What Does This Do?"))
            infoFS:SetPoint("TOP")
            infoH = math.ceil(infoFS:GetStringHeight())
            infoBtn:SetSize(infoFS:GetStringWidth() + 10, infoH)
            infoBtn:SetScript("OnEnter", function() infoFS:SetTextColor(EG.r, EG.g, EG.b, 1) end)
            infoBtn:SetScript("OnLeave", function() infoFS:SetTextColor(EG.r, EG.g, EG.b, 0.70) end)
            -- Three parts, each its own translation.
            local CHANGES = "What we change:\n\n"
                .. "Shadow Quality - Fair (balanced quality/FPS)\n"
                .. "Liquid Detail - Disabled\n"
                .. "Particle Density - Set to Ultra (keeps important spell effects)\n"
                .. "SSAO (Ambient Occlusion) - Disabled\n"
                .. "Depth Effects - Disabled\n"
                .. "Compute Effects - Disabled\n"
                .. "Outline Mode - Disabled\n"
                .. "Texture Resolution - Set to High\n"
                .. "Spell Density - Set to Essential\n"
                .. "Projected Textures - Enabled (needed for ground effects)\n"
                .. "View Distance - Reduced to 1\n"
                .. "Environment Detail - Reduced to 1\n"
                .. "Ground Clutter - Reduced to 1\n"
                .. "Raid/Dungeon Settings - Uses same settings everywhere\n"
                .. "Resample Sharpening - Enabled (crisper image)\n"
                .. "Contrast - Boosted by +10 (if currently 55 or below)\n"
                .. "Enable Reverb - Disabled (spell and interrupt audio cues stay crisp)\n\n"
                .. "These settings prioritize frame rate and visual clarity over environmental detail. Textures stay high quality so your character and the world still look perfect."
            infoBtn:SetScript("OnClick", function()
                NoxUI:ShowInfoPopup({
                    title = "FPS & Graphics Optimization",
                    content = NoxUI.L("This feature optimizes your in-game graphics settings to give you the best combination of high FPS and visual clarity.")
                        .. "\n\n" .. NoxUI.L("After optimizing, the button changes to 'Restore My Graphics Settings', which reverts every change.")
                        .. "\n\n\n" .. NoxUI.L(CHANGES),
                })
            end)
        end

        -- "What Does This Do?" explains Optimize, so it and its gap exist only
        -- in the Optimize form: under Restore the row has no footer and the
        -- page below moves up. A click that changes the form rebuilds the
        -- page for it. Its text keeps one width for both forms.
        local showInfo = not HasGfxBackup()
        local gfxIcon, gfxTitle, gfxDesc = GfxCardContent()
        local _, altTitle, altDesc = GfxCardContent(showInfo)
        local actionSpecs = {
            -- A menu of ALL Settings and each module's own reset (NoxUI_Panel.lua).
            { icon = MEDIA_ICONS .. "sync.png", accent = WARN,
              title = NoxUI.L("Reset EUI Module Settings"),
              desc = NoxUI.L("Pick a module, or ALL, to return to defaults."),
              onClick = function(card) NoxUI._ShowModuleResetMenu(card, ConfirmResetAll) end },
            { icon = gfxIcon, title = gfxTitle, desc = gfxDesc,
              hero = showInfo, accent = showInfo and GO or WARN,
              sizeAlso = { altTitle, altDesc },
              onClick = function()
                  local had = HasGfxBackup()
                  if had then RestoreGfxSettings() else ApplyOptimizedGfx() end
                  if HasGfxBackup() ~= had then NoxUI:RefreshPage(true) end
              end },
            -- power.png's glyph fills its whole canvas: drawn smaller, it matches sync.png.
            { icon = MEDIA_ICONS .. "power.png", accent = WARN, iconSize = 22,
              title = NoxUI.L("Uninstall EUI"), desc = NoxUI.L("Revert EUI's changes and disable."),
              onClick = ConfirmUninstall },
        }
        local gfxCard
        for i, spec in ipairs(actionSpecs) do
            local cards
            y, cards = NoxUI.BuildActionCardRow(parent, y, { spec })
            if i == 2 then
                gfxCard = cards[1]
                infoBtn:SetParent(gfxCard)
                infoBtn:SetFrameLevel(gfxCard:GetFrameLevel() + 5)
                infoBtn:SetShown(showInfo)
                PP.Point(infoBtn, "TOP", gfxCard, "BOTTOM", 0, -GFX_GAP)
                if showInfo then y = y - GFX_GAP - infoH end
            end
            y = y - 10
        end
        NoxUI.RegisterWidgetRefresh(function() gfxCard:SetCardContent(GfxCardContent()) end)

        return y
    end
    NoxUI._BuildGraphicsActions = BuildGraphicsActions

    ---------------------------------------------------------------------------
    --  General page
    ---------------------------------------------------------------------------
    local function BuildGeneralPage(pageName, parent, yOffset)
        local W = NoxUI.Widgets
        local y = yOffset
        local _, h

        parent._showRowDivider = true

        _, h = W:Spacer(parent, y, 20);  y = y - h

        if not NoxUI.IS_FOREVER then
            y = BuildGraphicsActions(parent, y)
        end

        -------------------------------------------------------------------
        --  DISPLAY
        -------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "DISPLAY", y);  y = y - h

        local themeValues = {}
        for _, name in ipairs(NoxUI.THEME_ORDER) do
            themeValues[name] = name
        end

        -- Row 1: UI Accent Color | EUI Options Theme
        local themeRow
        themeRow, h = W:DualRow(parent, y,
            { type="multiSwatch", text="UI Accent Color",
              tooltip="Sets the accent color used across all NoxUI elements (tabs, glows, highlights, borders). Defaults to your theme color.",
              swatches = {
                { tooltip = "Class Color",
                  getValue = function()
                      local cr, cg, cb = NoxUI.GetPlayerClassColor()
                      return cr, cg, cb, 1
                  end,
                  setValue = function() end,
                  onClick = function()
                      -- Per-profile: set use-class, then re-resolve + apply live.
                      NoxUI.SetActiveProfileAccent(nil, true)
                      NoxUI.RefreshAccent()
                      NoxUI:RefreshPage()
                  end,
                  refreshAlpha = function()
                      return (select(1, NoxUI.GetActiveAccentState())) and 1 or 0.3
                  end },
                { tooltip = "Custom Color",
                  hasAlpha = false,
                  getValue = function()
                      local _, ca = NoxUI.GetActiveAccentState()
                      if ca then return ca.r, ca.g, ca.b, 1 end
                      return NoxUI.DEFAULT_ACCENT_R, NoxUI.DEFAULT_ACCENT_G, NoxUI.DEFAULT_ACCENT_B, 1
                  end,
                  setValue = function(r, g, b)
                      -- Persists per-profile (custom + useClass=false), applies live.
                      NoxUI.SetAccentColor(r, g, b)
                  end,
                  onClick = function(self)
                      if select(1, NoxUI.GetActiveAccentState()) then
                          -- Switch class -> custom: clear the per-profile class flag and re-resolve (profile custom -> global -> theme).
                          NoxUI.SetActiveProfileAccent(nil, false)
                          NoxUI.RefreshAccent()
                          NoxUI:RefreshPage()
                          return
                      end
                      if self._eabOrigClick then self._eabOrigClick(self) end
                  end,
                  refreshAlpha = function()
                      return (select(1, NoxUI.GetActiveAccentState())) and 0.3 or 1
                  end },
              } },
            { type="dropdown", text="EUI Options Theme",
              values=themeValues,
              order=NoxUI.THEME_ORDER,
              getValue=function()
                return NoxUI.GetActiveTheme()
              end,
              setValue=function(v)
                NoxUI.SetActiveTheme(v)
                -- Re-resolve the accent so the sidebar highlight tracks the theme.
                if NoxUI.RefreshAccent then
                    NoxUI.RefreshAccent()  -- ApplyAccentLive already refreshes the page
                else
                    NoxUI:RefreshPage()
                end
              end }
        );  y = y - h

        -- Inline color swatch on EUI Options Theme (right region)
        if not NoxUI._prebuilding then
            local rightRgn = themeRow._rightRegion
            local function isCustomColorOff()
                return NoxUI.GetActiveTheme() ~= "Custom Color"
            end

            local tcGet = function()
                local db = NoxUIDB
                local sa = db and db.accentColor
                if sa then return sa.r, sa.g, sa.b, 1 end
                return NoxUI.GetAccentColor()
            end
            local tcSet = function(r, g, b)
                if not NoxUIDB then NoxUIDB = {} end
                NoxUIDB.accentColor = { r = r, g = g, b = b }
                -- Only update the window background, not the accent color
                if NoxUI._applyBgTint then
                    NoxUI._applyBgTint(r, g, b)
                end
            end
            local tcSwatch, tcUpdateSwatch = NoxUI.BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5, tcGet, tcSet, nil, 20)
            PP.Point(tcSwatch, "RIGHT", rightRgn._control, "LEFT", -12, 0)
            rightRgn._lastInline = tcSwatch
            NoxUI.RegisterWidgetRefresh(function()
                local off = isCustomColorOff()
                tcSwatch:SetAlpha(off and 0.15 or 1)
                tcSwatch:EnableMouse(not off)
                tcUpdateSwatch()
            end)
            tcSwatch:SetAlpha(isCustomColorOff() and 0.15 or 1)
            tcSwatch:EnableMouse(not isCustomColorOff())
            tcSwatch:SetScript("OnEnter", function(self)
                if isCustomColorOff() then
                    NoxUI.ShowWidgetTooltip(self, "This option is only available for the Custom Color Theme")
                end
            end)
            tcSwatch:SetScript("OnLeave", function()
                NoxUI.HideWidgetTooltip()
            end)
        end

        -- EUI Options Language (Row 2's right slot): options-panel display language (auto-detects the client; untranslated text falls back to English).
        local langCfg
        do
            -- _noLoc: the language list itself is never translated, so a player who booted the wrong language can always read and change it.
            local langValues = {
                _noLoc = true,
                ["auto"] = { text = NoxUI.L("Automatic (Client)") },
                ["enUS"] = { text = "English" },
                ["deDE"] = { text = "Deutsch" },
                ["frFR"] = { text = "Français" },
                ["esES"] = { text = "Español (EU)" },
                ["esMX"] = { text = "Español (LatAm)" },
                ["itIT"] = { text = "Italiano" },
                ["ptBR"] = { text = "Português (BR)" },
                ["ruRU"] = { text = "Русский" },
                ["koKR"] = { text = "한국어 (Korean)" },
                ["zhCN"] = { text = "简体中文 (Simplified Chinese)" },
                ["zhTW"] = { text = "繁體中文 (Traditional Chinese)" },
            }
            local langOrder = { "auto", "enUS", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
            -- Pin each entry to the plain font its own script needs, independent
            -- of whichever display locale is currently active.
            for _, key in ipairs(langOrder) do
                langValues[key].font = LP_FontFor(key)
            end
            -- "auto"'s own text is translated, not a fixed native-script name, so
            -- its script follows the ACTIVE locale rather than its own key.
            langValues["auto"].font = LP_FontFor(NoxUI.LOCALE)

            local function LanguageReload()
                NoxUI:ShowConfirmPopup({
                    title       = "Reload Required",
                    message     = "Changing the language requires a UI reload.",
                    confirmText = "Reload Now",
                    cancelText  = "Later",
                    reload      = true,
                })
            end

            -- A non-English game client reads only its own translation file, its
            -- pair's and none other: NoxUILangues.toc tags each file with
            -- the client languages that load it (keep LANG_PAIR in step with its
            -- pairs). English clients read every file.
            local LANG_PAIR = { esMX = "esES", zhCN = "zhTW", zhTW = "zhCN" }
            local clientLocale = GetLocale()
            local function LanguageUnavailable(v)
                if v == "auto" or v == "enUS" or clientLocale == "enUS" or clientLocale == "enGB" then return false end
                if v == clientLocale or LANG_PAIR[clientLocale] == v then return false end
                return "Needs the game client set to English or to this language."
            end

            langCfg = { type="dropdown", text="EUI Options Language",
                tooltip="The display language for the NoxUI options panel. Auto follows your game client. Untranslated text falls back to English.",
                values=langValues, order=langOrder, disabledValues=LanguageUnavailable,
                getValue=function() return (NoxUIDB and NoxUIDB.displayLocale) or "auto" end,
                setValue=function(v)
                    if v == "auto" then v = nil end
                    if NoxUIDB then NoxUIDB.displayLocale = v end
                    LanguageReload()
                end }
        end

        -- Row 2: UI Scale | EUI Options Language
        _, h = W:DualRow(parent, y,
            { type="slider", text="UI Scale",
              min=0.40, max=1.00, step=0.01,
              tooltip="Sets the scale of the whole game UI. 0.53 = 0.5333 and 0.71 = 0.7111",
              tooltipOnControl=true,
              getValue=function()
                if NoxUI._uiScaleDragVal then
                    return NoxUI._uiScaleDragVal
                end
                return NoxUIDB and NoxUIDB.ppUIScale or NoxUI.PP.PixelBestSize()
              end,
              setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                -- Snap 0.53 to exact pixel-perfect 0.5333... (768/1440)
                if math.abs(v - 0.53) < 0.005 then v = 0.5333333333 end
                -- Snap 0.71 to exact pixel-perfect 0.7111... (768/1080)
                if math.abs(v - 0.71) < 0.005 then v = 0.7111111111 end
                NoxUI._uiScaleDragVal = v
                NoxUIDB.ppUIScaleAuto = false
                local mf = NoxUI._mainFrame
                local panelScaleBefore
                if mf then panelScaleBefore = mf:GetEffectiveScale() end
                NoxUI.PP.SetUIScale(v)
                if mf and panelScaleBefore then
                    local newEff = UIParent:GetEffectiveScale()
                    if newEff > 0 then mf:SetScale(panelScaleBefore / newEff) end
                end
                if not NoxUI._uiScaleCleanup then
                    NoxUI._uiScaleCleanup = true
                    C_Timer.After(0, function()
                        if not NoxUI._sliderDragging then
                            NoxUI._uiScaleDragVal = nil
                            NoxUI:ShowConfirmPopup({
                                title = "UI Scale Changed",
                                message = "Blizzard's Edit Mode snapping may not work correctly until you reload your UI.",
                                confirmText = "Reload Now",
                                cancelText = "Later",
                                reload    = true,
                            })
                        end
                        NoxUI._uiScaleCleanup = false
                    end)
                end
              end },
            langCfg
        );  y = y - h

        -- Row 3: EUI Buttons (merged button toggles) | Disable Sync Icons (+ cog)
        -- "EUI Buttons" merges the Pause Menu, Unlock Mode Menu and Minimap
        -- toggles into one checkbox-dropdown over the SAME backend variables: front-end grouping only, settings/defaults unchanged.
        local euiBtnItems = {
            { key = "pause",   label = "Hide Pause Menu Button",
              tooltip = "Hides the NoxUI button from the game's Escape/pause menu." },
            { key = "unlock",  label = "Hide Unlock Mode Menu Button",
              tooltip = "Hides the Unlock Mode button from the game's Escape/pause menu. You can still toggle Unlock Mode from the EUI options panel." },
            { key = "minimap", label = "Show Minimap Button" },
        }
        local euiBtnRow
        euiBtnRow, h = W:DualRow(parent, y,
            { type="dropdown", text="EUI Buttons",
              tooltip="Toggle NoxUI's optional buttons: the Escape menu buttons and the minimap button.",
              values={ ["_placeholder"]="..." }, order={ "_placeholder" },
              getValue=function() return "_placeholder" end,
              setValue=function() end },
            { type="toggle", text="Disable Sync Icons",
              tooltip="Hides the sync icons on the sidebar module list.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.hideSyncIcons or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.hideSyncIcons = v
                  if NoxUI._refreshAllSyncIcons then NoxUI._refreshAllSyncIcons() end
              end }
        );  y = y - h
        -- EUI Buttons checkbox-dropdown (left region)
        if not NoxUI._prebuilding then
            local rgn = euiBtnRow._leftRegion
            if rgn._control then rgn._control:Hide() end
            local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                rgn, 210, rgn:GetFrameLevel() + 2,
                euiBtnItems,
                function(k)
                    if k == "pause" then
                        return NoxUIDB and NoxUIDB.hideGameMenuButton or false
                    elseif k == "unlock" then
                        return not NoxUIDB or NoxUIDB.hideUnlockMenuButton ~= false
                    elseif k == "minimap" then
                        return not (NoxUIDB and NoxUIDB.showMinimapButton == false)
                    end
                    return false
                end,
                function(k, v)
                    if not NoxUIDB then NoxUIDB = {} end
                    if k == "pause" then
                        NoxUIDB.hideGameMenuButton = v
                    elseif k == "unlock" then
                        NoxUIDB.hideUnlockMenuButton = v
                    elseif k == "minimap" then
                        NoxUIDB.showMinimapButton = v
                        if v then NoxUI.ShowMinimapButton() else NoxUI.HideMinimapButton() end
                    end
                end)
            PP.Point(cbDD, "RIGHT", rgn, "RIGHT", -20, 0)
            rgn._control = cbDD
            rgn._lastInline = nil
            NoxUI.RegisterWidgetRefresh(cbDDRefresh)
        end
        -- Cog with "Only Hide Fully Synced" toggle on Disable Sync Icons (right region)
        do
            local rgn = euiBtnRow._rightRegion
            NoxUI.BuildInlineCog(rgn, {
                title = "Sync Icon Options",
                rows = {
                    { type="toggle", label="Only Hide Fully Synced",
                      get=function()
                          return NoxUIDB and NoxUIDB.hideSyncIconsOnlyFull or false
                      end,
                      set=function(v)
                          if not NoxUIDB then NoxUIDB = {} end
                          NoxUIDB.hideSyncIconsOnlyFull = v
                          if NoxUI._refreshAllSyncIcons then NoxUI._refreshAllSyncIcons() end
                      end },
                },
            })
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        _, h = W:SectionHeader(parent, "UNLOCK MODE", y);  y = y - h
        local pointAnchorRow
        pointAnchorRow, h = W:DualRow(parent, y,
            { type="toggle", text="Point Anchoring",
              tooltip="Show nine source points after clicking Anchor in Unlock Mode. Choose a source point, then a target point. Turning this off hides the handles and preserves saved point anchors.",
              getValue=function() return NoxUIDB and NoxUIDB.unlockPointHandles == true end,
              setValue=function(v)
                  NoxUI.SetPointAnchorHandles(v)
                  NoxUI:RefreshPage()
              end },
            { type="dropdown", text="Overlap Cycling",
              tooltip="Scroll with the chosen modifier to cycle overlapping frames in Unlock Mode.",
              values=NoxUI.UNLOCK_OVERLAP_LABELS,
              order={ "disabled", "scroll", "shiftscroll", "controlscroll", "altscroll" },
              getValue=function() return NoxUI.GetUnlockOverlapMethod() end,
              setValue=function(v)
                  NoxUIDB = NoxUIDB or {}
                  NoxUIDB.unlockOverlapMethod = v
                  if NoxUI.RefreshUnlockOverlapMethod then NoxUI.RefreshUnlockOverlapMethod() end
              end }); y = y - h
        if not NoxUI._prebuilding then
            NoxUI.BuildInlineSwatches(pointAnchorRow._leftRegion, {
                { tooltip="Connector Lines Color", hasAlpha=true,
                  getValue=function() return NoxUI.GetPointAnchorColor("line") end,
                  setValue=function(r,g,b,a) NoxUI.SetPointAnchorColor("line",r,g,b,a) end },
                { tooltip="Border Color", hasAlpha=true,
                  getValue=function() return NoxUI.GetPointAnchorColor("border") end,
                  setValue=function(r,g,b,a) NoxUI.SetPointAnchorColor("border",r,g,b,a) end },
                { tooltip="Point Color", hasAlpha=true,
                  getValue=function() return NoxUI.GetPointAnchorColor("point") end,
                  setValue=function(r,g,b,a) NoxUI.SetPointAnchorColor("point",r,g,b,a) end },
            }, {
                disabled=function() return not (NoxUIDB and NoxUIDB.unlockPointHandles == true) end,
                disabledTooltip="Point Anchoring",
            })
        end
        _, h = W:Spacer(parent, y, 20); y = y - h

        _, h = W:SectionHeader(parent, "COMBAT", y);  y = y - h

        _, h = W:DualRow(parent, y,
            { type="slider", text="Max Camera Distance",
              min=1, max=2.6, step=0.1,
              getValue=function() return GetCVarNum("cameraDistanceMaxZoomFactor") end,
              setValue=function(v)
                v = floor(v * 10 + 0.5) / 10
                SetCVarSafe("cameraDistanceMaxZoomFactor", v)
              end },
            { type="toggle", text="Increase Game Image Quality",
              tooltip="Enables sharpening to improve image clarity. Especially noticeable at lower render scales.",
              getValue=function() return GetCVarBool("ResampleAlwaysSharpen") end,
              setValue=function(v)
                SetGfxCVar("ResampleAlwaysSharpen", v and "1" or "0")
              end });  y = y - h

        _, h = W:DualRow(parent, y,
            { type="toggle", text="Cast Actions on Key Down",
              tooltip="Keybinds respond on key down instead of key up. This helps make your abilities feel more responsive.",
              getValue=function() return GetCVarBool("ActionButtonUseKeyDown") end,
              setValue=function(v)
                SetCVarSafe("ActionButtonUseKeyDown", v and "1" or "0")
                if _G._EAB_ApplyKeyDown then _G._EAB_ApplyKeyDown() end
              end },
            { type="slider", text="Lag Tolerance",
              tooltip="This is the Spell Queue Window, it helps with making sure you can't queue up too many spells at once which makes the game feel laggy. Recommended settings are generally a minimum of 200 + your local ping. If you are unsure of exactly what this setting does, leave it at 400.",
              min=0, max=400, step=1,
              getValue=function() return GetCVarNum("SpellQueueWindow") end,
              setValue=function(v)
                SetCVarSafe("SpellQueueWindow", v)
              end });  y = y - h

        local FCT_FONT_DIR = "Interface\\AddOns\\NoxUI\\media\\fonts\\"
        local fctFontValues = {
            ["default"]                                = { text = "Blizzard Default", font = "Fonts\\FRIZQT__.TTF" },
            [FCT_FONT_DIR .. "Expressway.TTF"]         = { text = "Expressway",            font = FCT_FONT_DIR .. "Expressway.TTF" },
            [FCT_FONT_DIR .. "Avant Garde Naowh.ttf"]        = { text = "Avant Garde",   font = FCT_FONT_DIR .. "Avant Garde Naowh.ttf" },
            [FCT_FONT_DIR .. "Arial Bold.TTF"]         = { text = "Arial Bold",            font = FCT_FONT_DIR .. "Arial Bold.TTF" },
            [FCT_FONT_DIR .. "Poppins.ttf"]            = { text = "Poppins",               font = FCT_FONT_DIR .. "Poppins.ttf" },
            [FCT_FONT_DIR .. "FiraSans Medium.ttf"]    = { text = "Fira Sans Medium",      font = FCT_FONT_DIR .. "FiraSans Medium.ttf" },
            [FCT_FONT_DIR .. "Expressway CAPS.ttf"]    = { text = "Expressway CAPS",       font = FCT_FONT_DIR .. "Expressway CAPS.ttf" },
            [FCT_FONT_DIR .. "Arial Narrow.ttf"]       = { text = "Arial Narrow",          font = FCT_FONT_DIR .. "Arial Narrow.ttf" },
            [FCT_FONT_DIR .. "Changa.ttf"]             = { text = "Changa",                font = FCT_FONT_DIR .. "Changa.ttf" },
            [FCT_FONT_DIR .. "Cinzel Decorative.ttf"]  = { text = "Cinzel Decorative",     font = FCT_FONT_DIR .. "Cinzel Decorative.ttf" },
            [FCT_FONT_DIR .. "Exo.otf"]                = { text = "Exo",                   font = FCT_FONT_DIR .. "Exo.otf" },
            [FCT_FONT_DIR .. "FiraSans Bold.ttf"]      = { text = "Fira Sans Bold",        font = FCT_FONT_DIR .. "FiraSans Bold.ttf" },
            [FCT_FONT_DIR .. "FiraSans Light.ttf"]     = { text = "Fira Sans Light",       font = FCT_FONT_DIR .. "FiraSans Light.ttf" },
            [FCT_FONT_DIR .. "Future X Black.otf"]     = { text = "Future X Black",        font = FCT_FONT_DIR .. "Future X Black.otf" },
            [FCT_FONT_DIR .. "Gotham Narrow Ultra.otf"] = { text = "Gotham Narrow Ultra",  font = FCT_FONT_DIR .. "Gotham Narrow Ultra.otf" },
            [FCT_FONT_DIR .. "Gotham Narrow.otf"]      = { text = "Gotham Narrow",         font = FCT_FONT_DIR .. "Gotham Narrow.otf" },
            [FCT_FONT_DIR .. "Russo One.ttf"]          = { text = "Russo One",             font = FCT_FONT_DIR .. "Russo One.ttf" },
            [FCT_FONT_DIR .. "Ubuntu.ttf"]             = { text = "Ubuntu",                font = FCT_FONT_DIR .. "Ubuntu.ttf" },
            [FCT_FONT_DIR .. "Homespun.ttf"]           = { text = "Homespun",              font = FCT_FONT_DIR .. "Homespun.ttf" },
            [FCT_FONT_DIR .. "HWT Artz.ttf"]           = { text = "HWT Artz",              font = FCT_FONT_DIR .. "HWT Artz.ttf" },
            ["Fonts\\FRIZQT__.TTF"]                    = { text = "Friz Quadrata",         font = "Fonts\\FRIZQT__.TTF" },
            ["Fonts\\ARIALN.TTF"]                      = { text = "Arial",                 font = "Fonts\\ARIALN.TTF" },
            ["Fonts\\MORPHEUS.TTF"]                    = { text = "Morpheus",              font = "Fonts\\MORPHEUS.TTF" },
            ["Fonts\\skurri.ttf"]                      = { text = "Skurri",                font = "Fonts\\skurri.ttf" },
        }
        local fctFontOrder = {
            "default",
            FCT_FONT_DIR .. "Expressway.TTF",
            FCT_FONT_DIR .. "Avant Garde Naowh.ttf",
            FCT_FONT_DIR .. "Arial Bold.TTF",
            FCT_FONT_DIR .. "Poppins.ttf",
            FCT_FONT_DIR .. "FiraSans Medium.ttf",
            FCT_FONT_DIR .. "Expressway CAPS.ttf",
            "---",
            FCT_FONT_DIR .. "Arial Narrow.ttf",
            FCT_FONT_DIR .. "Changa.ttf",
            FCT_FONT_DIR .. "Cinzel Decorative.ttf",
            FCT_FONT_DIR .. "Exo.otf",
            FCT_FONT_DIR .. "FiraSans Bold.ttf",
            FCT_FONT_DIR .. "FiraSans Light.ttf",
            FCT_FONT_DIR .. "Future X Black.otf",
            FCT_FONT_DIR .. "Gotham Narrow Ultra.otf",
            FCT_FONT_DIR .. "Gotham Narrow.otf",
            FCT_FONT_DIR .. "Russo One.ttf",
            FCT_FONT_DIR .. "Ubuntu.ttf",
            FCT_FONT_DIR .. "Homespun.ttf",
            FCT_FONT_DIR .. "HWT Artz.ttf",
            "Fonts\\FRIZQT__.TTF",
            "Fonts\\ARIALN.TTF",
            "Fonts\\MORPHEUS.TTF",
            "Fonts\\skurri.ttf",
        }
        for i = #fctFontOrder, 2, -1 do
            local k = fctFontOrder[i]
            if k ~= "---" and not NoxUI.CombatTextFontCoversLocale(k) then
                table.remove(fctFontOrder, i)
            end
        end
        if fctFontOrder[#fctFontOrder] == "---" then fctFontOrder[#fctFontOrder] = nil end
        NoxUI.AppendSharedMediaFonts(fctFontValues, fctFontOrder)

        -- Combat Text (checkbox dropdown + size cog) | Combat Text Font. The
        -- dropdown is a view over the floating combat text CVars the client
        -- has; each extra only applies while the item it refines is on (the
        -- damage extras under Damage, Absorb Shields under Healing, Others'
        -- Target Effects under Target Effects).
        local function DmgOff() return not GetCVarBool("floatingCombatTextCombatDamage_v2") end
        local function HealOff() return not GetCVarBool("floatingCombatTextCombatHealing_v2") end
        local function FxOff() return not GetCVarBool("floatingCombatTextSpellMechanics_v2") end
        local dmgTip = NoxUI.DisabledTooltip("Damage")
        local healTip = NoxUI.DisabledTooltip("Healing")
        local fxTip = NoxUI.DisabledTooltip("Target Effects")
        local COMBAT_TEXT = {}
        for _, item in ipairs({
            { key="floatingCombatTextCombatDamage_v2",            label="Damage" },
            { key="floatingCombatTextCombatLogPeriodicSpells_v2", label="Periodic Damage",
              lockedFn=DmgOff, lockedTooltip=dmgTip, excludeFromSummaryFn=DmgOff },
            { key="floatingCombatTextPetMeleeDamage_v2",          label="Pet Melee Damage",
              lockedFn=DmgOff, lockedTooltip=dmgTip, excludeFromSummaryFn=DmgOff },
            { key="floatingCombatTextPetSpellDamage_v2",          label="Pet Spell Damage",
              lockedFn=DmgOff, lockedTooltip=dmgTip, excludeFromSummaryFn=DmgOff },
            { key="floatingCombatTextCombatHealing_v2",           label="Healing" },
            { key="floatingCombatTextCombatHealingAbsorbTarget_v2", label="Absorb Shields",
              lockedFn=HealOff, lockedTooltip=healTip, excludeFromSummaryFn=HealOff },
            { key="floatingCombatTextSpellMechanics_v2",          label="Target Effects" },
            { key="floatingCombatTextSpellMechanicsOther_v2",     label="Others' Target Effects",
              lockedFn=FxOff, lockedTooltip=fxTip, excludeFromSummaryFn=FxOff },
        }) do
            if C_CVar.GetCVarInfo(item.key) then COMBAT_TEXT[#COMBAT_TEXT + 1] = item end
        end
        local combatTextRow
        combatTextRow, h = W:DualRow(parent, y,
            { type="label", text="Combat Text" },
            { type="dropdown", text="Combat Text Font",
              tooltip="WARNING: This feature requires you to re-log or restart WoW to take effect.",
              tooltipOpts={ color={1, 0.3, 0.3} },
              values = fctFontValues, order = fctFontOrder,
              getValue=function()
                local v = NoxUIDB and NoxUIDB.fctFont
                return v and NoxUI.CombatTextFontCoversLocale(v) and v or "default"
              end,
              setValue=function(v)
                if not NoxUIDB then NoxUIDB = {} end
                if v == "default" then
                    NoxUIDB.fctFont = nil
                    NoxUIDB.fctFontPath = nil
                    NoxUIDB.fctFontPathFor = nil
                else
                    NoxUIDB.fctFont = v
                    -- smf: keys cache their resolved path for the next login's
                    -- early window; see ApplyCombatTextFont in Startup.
                    local e = v:match("^smf:") and fctFontValues[v]
                    NoxUIDB.fctFontPath = e and e.font
                    NoxUIDB.fctFontPathFor = e and v
                end
                NoxUI:ShowConfirmPopup({
                    title   = "Logout Required",
                    message = "Combat text font changes require a logout to character select to take effect. This is a WoW engine limitation.",
                    confirmText = "Okay",
                    cancelText  = "Later",
                })
              end });  y = y - h
        do
            local rgn = combatTextRow._leftRegion
            if not NoxUI._prebuilding then
                local cbDD, cbDDRefresh = NoxUI.BuildVisOptsCBDropdown(
                    rgn, 210, rgn:GetFrameLevel() + 2, COMBAT_TEXT,
                    function(key) return GetCVarBool(key) end,
                    function(key, v) SetCVarSafe(key, v and "1" or "0") end)
                PP.Point(cbDD, "RIGHT", rgn, "RIGHT", -20, 0)
                rgn._control = cbDD
                rgn._lastInline = nil
                NoxUI.RegisterWidgetRefresh(cbDDRefresh)
            end
            NoxUI.BuildInlineCog(rgn, {
                title = "Combat Text Size",
                rows = {
                    { type="slider", label="Size", min=0.5, max=2.5, step=0.1,
                      get=function() return GetCVarNum("WorldTextScale_v2") end,
                      set=function(v)
                          v = floor(v * 10 + 0.5) / 10
                          SetCVarSafe("WorldTextScale_v2", v)
                      end },
                },
            })
        end

        -- Swiftmend Brightness Fix (Druid only): the right slot beside Round
        -- Timer Seconds Down, blank for every other class.
        local swiftmendCfg = NoxUI.BlankRowCfg()
        local _, playerClass = UnitClass("player")
        if playerClass == "DRUID" then
            swiftmendCfg = { type="toggle", text="Prevent Swiftmend Icon Dim",
                tooltip="Prevents Blizzard from dimming Swiftmend on action bars and CDM based on Efflorescence state.",
                getValue=function()
                    return not NoxUIDB or NoxUIDB.brightenSwiftmend ~= false
                end,
                setValue=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.brightenSwiftmend = v
                    if v then
                        if _G._EAB_ScanSwiftmend then _G._EAB_ScanSwiftmend() end
                        if _G._ECDM_ScanSwiftmend then _G._ECDM_ScanSwiftmend() end
                    end
                end }
        end

        -- Row 4: Round Timer Seconds Down | Prevent Swiftmend Icon Dim. Every
        -- timer keeps the formatter it was given (AuraKit reads the setting
        -- once), so a change waits for a reload.
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Round Timer Seconds Down",
              tooltip="Timer seconds round down like Blizzard's buff frame, so a timer reads 0 in its last second. Off, it reads 1 until it ends.",
              getValue=function()
                  return NoxUIDB and NoxUIDB.timerSecondsDown == true or false
              end,
              setValue=function(v)
                  if not NoxUIDB then NoxUIDB = {} end
                  NoxUIDB.timerSecondsDown = v or nil
                  NoxUI:ShowConfirmPopup({
                      title       = "Reload Required",
                      message     = "Changing how timers round requires a UI reload.",
                      confirmText = "Reload Now",
                      cancelText  = "Later",
                      reload      = true,
                  })
              end },
            swiftmendCfg
        ); y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -- The options search box: results picked often rank higher.
        _, h = W:SectionHeader(parent, "SEARCH", y);  y = y - h
        _, h = W:DualRow(parent, y,
            { type="toggle", text="Remember Picks",
              tooltip="Results you pick often rank higher in the search.",
              getValue=function() return NoxUI.SearchPicksOn() end,
              setValue=function(v)
                  NoxUI.SetSearchPicksOn(v)
                  NoxUI:RefreshPage()
              end },
            { type="labeledButton", text="Pick History", buttonText="Clear", width=90,
              tooltip="Forgets the results you have picked.",
              disabled=function() return not NoxUI.SearchPicksOn() end,
              disabledTooltip="Remember Picks",
              onClick=function()
                  NoxUI:ShowConfirmPopup({
                      title       = "Clear Pick History",
                      message     = "Forget every search result you have picked? Search ranking goes back to the default order.",
                      confirmText = "Clear",
                      cancelText  = "Cancel",
                      onConfirm   = function() NoxUI.ClearSearchPicks() end,
                  })
              end });  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -------------------------------------------------------------------
        --  DEVELOPER -- both toggles are duplicated in Quality of Life
        --  (Suppress Lua Errors) and Blizzard Skins+ (Spell ID on Tooltip):
        --  hidden here when BOTH modules are loaded, shown if either is missing so the settings stay reachable.
        -------------------------------------------------------------------
        local _devDupesAvailable = C_AddOns and C_AddOns.IsAddOnLoaded
            and C_AddOns.IsAddOnLoaded("NoxUIConfortJeu")
            and C_AddOns.IsAddOnLoaded("NoxUIApparenceBlizzard")
        if not _devDupesAvailable then
            _, h = W:SectionHeader(parent, "DEVELOPER", y);  y = y - h

            _, h = W:DualRow(parent, y,
                { type="toggle", text="Suppress Lua Errors",
                  getValue=function()
                    return not (NoxUIDB and NoxUIDB.suppressErrors == false)
                  end,
                  setValue=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.suppressErrors = v
                    SetCVarSafe("scriptErrors", v and "0" or "1")
                  end },
                { type="toggle", text="Spell ID on Tooltip",
                  getValue=function()
                    return NoxUI.SpellIDOn()
                  end,
                  setValue=function(v)
                    if not NoxUIDB then NoxUIDB = {} end
                    NoxUIDB.showSpellID = v
                    -- Engine-side combat aura-ID CVar rides this setting.
                    if NoxUI.SyncAuraSpellIDCVar then NoxUI.SyncAuraSpellIDCVar() end
                  end });  y = y - h

            _, h = W:Spacer(parent, y, 20);  y = y - h
        end

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Re-read live CVars on panel open: widgets call their getter on each build, so a rebuild picks up external changes (addons, /console).
    ---------------------------------------------------------------------------
    NoxUI:RegisterOnShow(function()
        if NoxUI:GetActiveModule() == GLOBAL_KEY then
            NoxUI:RefreshPage()
        end
    end)

    ---------------------------------------------------------------------------
    --  Enabled Addons page
    ---------------------------------------------------------------------------

    -- The profiles root (nui_profils_options.lua) sits on the scroll frame
    -- itself, beside the pages: when another page shows it is hidden and
    -- leaves the scroll frame, and nil marks it as needing a build before it
    -- shows again. The frame stays its builder's (options page pool): the
    -- next build parents it to the scroll frame again and dresses it again.
    local function CleanupProfilesRoot()
        local root = NoxUI._profilesRoot
        if root then
            root:Hide()
            root:SetParent(nil)
            NoxUI._profilesRoot = nil
        end
    end

    -- A profiles root build outside a page pass (a cached page shown again):
    -- the refreshers its previous build registered leave the live list first.
    local function RenderProfilesRoot()
        NoxUI._BeginRootRender("profilesRoot")
        _G._EUI_BuildProfilesPage(PAGE_PROFILES, nil, -6)
        NoxUI._EndRootRender("profilesRoot")
    end

    -- Profiles and Patch Notes are their own sidebar pages (registered below), so Global Settings owns General + Style + Fonts + Textures + Glows + Colors + Numbers (Style second, beside General), plus Gamepad while a module it configures is loaded.
    local globalPages = { PAGE_GENERAL, PAGE_STYLE, PAGE_COLORS, PAGE_FONTS, PAGE_NUMBERS, PAGE_TEXTURES, PAGE_GLOWS }
    if NoxUI.ModuleNS("NoxUIBarresAction") or NoxUI.ModuleNS("NoxUICadresUnite")
       or NoxUI.ModuleNS("NoxUIBarresRessources") then
        globalPages[#globalPages + 1] = PAGE_GAMEPAD
    end

    NoxUI:RegisterModule(GLOBAL_KEY, {
        title       = "Interface et préférences",
        description = "General options for all NoxUI addons.",
        pages       = globalPages,
        tabLabels   = {
            [PAGE_GENERAL] = "Préférences",
            [PAGE_STYLE] = "Habillage",
            [PAGE_COLORS] = "Palette",
            [PAGE_FONTS] = "Typographie",
            [PAGE_NUMBERS] = "Formats",
            [PAGE_TEXTURES] = "Surfaces",
            [PAGE_GLOWS] = "Effets",
            [PAGE_GAMEPAD] = "Manette",
        },
        buildPage   = function(pageName, parent, yOffset)
            -- CleanupProfilesRoot hides/nils the LIVE _profilesRoot, not anything scoped to this pageName. An off-screen search pre-build
            -- cycles pageName through PAGE_GENERAL/PAGE_FONTS/PAGE_TEXTURES/PAGE_COLORS regardless of what the player has open, so it would yank their real Profiles
            -- page away. This module's config.pages never includes PAGE_PROFILES anyway.
            if NoxUI._prebuilding then
                if pageName == PAGE_GENERAL then
                    return BuildGeneralPage(pageName, parent, yOffset)
                elseif pageName == PAGE_FONTS then
                    return _G._EUI_BuildFontsPage and _G._EUI_BuildFontsPage(pageName, parent, yOffset)
                elseif pageName == PAGE_TEXTURES then
                    return _G._EUI_BuildTexturesPage and _G._EUI_BuildTexturesPage(pageName, parent, yOffset)
                elseif pageName == PAGE_GLOWS then
                    return _G._EUI_BuildGlowsPage and _G._EUI_BuildGlowsPage(pageName, parent, yOffset)
                elseif pageName == PAGE_GAMEPAD then
                    return _G._EUI_BuildGamepadPage and _G._EUI_BuildGamepadPage(pageName, parent, yOffset)
                elseif pageName == PAGE_NUMBERS then
                    return _G._EUI_BuildNumberFormatPage and _G._EUI_BuildNumberFormatPage(pageName, parent, yOffset)
                elseif pageName == PAGE_STYLE then
                    return _G._EUI_BuildStylePage and _G._EUI_BuildStylePage(pageName, parent, yOffset)
                elseif pageName == PAGE_COLORS then
                    return _G._EUI_BuildColorsPage(pageName, parent, yOffset)
                elseif pageName == PAGE_WHATSNEW then
                    return NoxUI._BuildWhatsNewPage(pageName, parent, yOffset)
                end
                return
            end
            -- Clean up profiles root when switching to a non-Profiles tab
            if pageName ~= PAGE_PROFILES then
                CleanupProfilesRoot()
            end
            if pageName == PAGE_GENERAL then
                return BuildGeneralPage(pageName, parent, yOffset)
            elseif pageName == PAGE_FONTS then
                return _G._EUI_BuildFontsPage and _G._EUI_BuildFontsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_TEXTURES then
                return _G._EUI_BuildTexturesPage and _G._EUI_BuildTexturesPage(pageName, parent, yOffset)
            elseif pageName == PAGE_GLOWS then
                return _G._EUI_BuildGlowsPage and _G._EUI_BuildGlowsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_GAMEPAD then
                return _G._EUI_BuildGamepadPage and _G._EUI_BuildGamepadPage(pageName, parent, yOffset)
            elseif pageName == PAGE_NUMBERS then
                return _G._EUI_BuildNumberFormatPage and _G._EUI_BuildNumberFormatPage(pageName, parent, yOffset)
            elseif pageName == PAGE_STYLE then
                return _G._EUI_BuildStylePage and _G._EUI_BuildStylePage(pageName, parent, yOffset)
            elseif pageName == PAGE_COLORS then
                return _G._EUI_BuildColorsPage(pageName, parent, yOffset)
            elseif pageName == PAGE_PROFILES then
                return _G._EUI_BuildProfilesPage(pageName, parent, yOffset)
            elseif pageName == PAGE_WHATSNEW then
                return NoxUI._BuildWhatsNewPage(pageName, parent, yOffset)
            end
        end,
        -- Number Format: the value type picker and preview header, and one search
        -- pre-build per value type (each type's Precision row exists only under it).
        getHeaderBuilder = function(pageName)
            if pageName == PAGE_NUMBERS and _G._EUI_NumberFormatHeaderBuilder then
                return _G._EUI_NumberFormatHeaderBuilder()
            end
            return nil
        end,
        getPrebuildVariants = function(pageName)
            if pageName == PAGE_NUMBERS and _G._EUI_NumberFormatVariants then
                return _G._EUI_NumberFormatVariants()
            end
            return nil
        end,
        onPageCacheRestore = function(pageName)
            -- The cached header's preview may predate a profile switch.
            if pageName == PAGE_NUMBERS and _G._EUI_NumberFormatRefreshHeader then
                _G._EUI_NumberFormatRefreshHeader()
            end
            if pageName == PAGE_GLOWS then
                -- Glow sites bind per-bar and per-spec tables at build time (CDM bars,
                -- tracking bars); a spec swap or bar change behind a cached page would
                -- leave rows writing into stale tables. Rebuild on every return.
                C_Timer.After(0, function()
                    if NoxUI:GetActiveModule() == GLOBAL_KEY
                       and NoxUI:GetActivePage() == PAGE_GLOWS then
                        NoxUI:RefreshPage(true)
                    end
                end)
            end
            if pageName ~= PAGE_PROFILES then
                CleanupProfilesRoot()
            elseif pageName == PAGE_PROFILES and not NoxUI._profilesRoot then
                C_Timer.After(0, function()
                    if NoxUI:GetActiveModule() == GLOBAL_KEY
                       and NoxUI:GetActivePage() == pageName then
                        RenderProfilesRoot()
                    end
                end)
            end
        end,
        -- Reset EUI Module Settings: these settings sit on the account.
        resetScope  = "account",
        onReset     = function()
            -- Reset CVars to EUI preferred defaults (ignoring current state)
            for _, entry in ipairs(EUI_DEFAULTS) do
                SetCVarSafe(entry[1], entry[2])
            end
            -- Reset style/theme settings (accent color, custom theme, class-colored)
            NoxUI.ResetTheme()
            -- Reset all custom class, power, and resource colors to defaults
            if NoxUIDB then
                NoxUIDB.customColors = nil
            end
            -- Reset fonts to defaults
            if NoxUIDB then
                NoxUIDB.fonts = nil
            end
            NoxUI.InvalidateFontCache()
            NoxUI.ApplyColorsToOUF()
            -- Reset the active profile's Number Format to defaults
            NoxUI.ResetNumberFormat()
            -- Remember Picks off again, its pick history gone with it
            NoxUI.SetSearchPicksOn(false)
            -- Reset panel scale to 100%
            NoxUI:SetPanelScale(1.0)
            -- Reset right-click targeting to default (disabled = off)
            if NoxUIDB then
                NoxUIDB.disableRightClickTarget = false
                NoxUIDB.disableRightClickTargetAllyCombat = false
                -- FPS + Secondary Stats are per-profile now; turn them off for the active profile (QoLExtrasSet) so the visible widgets actually clear.
                if NoxUI.QoLExtrasSet then
                    NoxUI.QoLExtrasSet("showFPS", false)
                    NoxUI.QoLExtrasSet("showSecondaryStats", false)
                end
                NoxUIDB.guildChatPrivacy = false
                NoxUIDB.repairWarning = nil
                -- Reset UI scale so next reload re-snapshots from Blizzard default
                NoxUIDB.ppUIScale = nil
                NoxUIDB.ppUIScaleAuto = nil
                -- Developer settings defaults (Spell ID on Tooltip: unset = on)
                NoxUIDB.showSpellID = nil
                if NoxUI.SyncAuraSpellIDCVar then NoxUI.SyncAuraSpellIDCVar() end
                NoxUIDB.suppressErrors = true
                NoxUIDB.timerSecondsDown = nil
                -- Crosshair: the root is the inherited global default, reset here (per-profile overrides clear with the profile's own reset).
                -- Root off = profiles without an override inherit "None".
                NoxUIDB.crosshairSize = "None"
                if NoxUI._applyCrosshair then NoxUI._applyCrosshair() end
                -- Reset unlock mode layout data
                NoxUIDB.unlockAnchors = nil
                NoxUIDB.unlockWidthMatch = nil
                NoxUIDB.unlockHeightMatch = nil
                NoxUIDB.unlockWidthMatchExtra = nil
                NoxUIDB.unlockHeightMatchExtra = nil
                NoxUIDB.unlockPointHandles = nil
                NoxUIDB.unlockPointColors = nil
                -- QoL Features are NOT reset here; they have their own module reset
            end
            if NoxUI._applyRightClickTarget then
                NoxUI._applyRightClickTarget()
            end
            NoxUI._applyHideBlizzardPartyFrame()
            -- One call for both: the FPS readout may be drawn by the Secondary
            -- Stats block, so the two owners have to re-evaluate together.
            if NoxUI._applyFPSDisplay then
                NoxUI._applyFPSDisplay()
            elseif NoxUI._applySecondaryStats then
                NoxUI._applySecondaryStats()
            end
            if NoxUI._applyCrosshair then
                NoxUI._applyCrosshair()
            end
            if NoxUI._applyGuildChatPrivacy then
                NoxUI._applyGuildChatPrivacy()
            end
            -- Apply suppress errors default (on)
            SetCVarSafe("scriptErrors", "0")
            NoxUI:SelectPage(PAGE_GENERAL)
        end,
    })

    -- Profiles & Presets: its own sidebar module, reusing the profiles page builder; the profiles-root lifecycle rides the shared
    -- CleanupProfilesRoot hooks below (keyed to PROFILES_KEY). Second tab: the Overrides management list (built by nui_specialisation_exceptions_liste_page.lua).
    --
    -- ONE tab, TWO pages: "Spec Overrides" and "Conditional Overrides" stay completely separate page builders with their own stores, prune
    -- passes and row logic. The tab strip shows one "Overrides" entry and a centered segmented toggle picks the builder (the same control
    -- Raid Frames uses for Simple Setup / Custom Buff Display). The mode is runtime-only, defaulting to the spec list.
    local PAGE_OVERRIDES = "Overrides"

    -- Builds the centered mode toggle, returning the vertical space used. Plain local closure on purpose: no widget row, no capture config, no saved state.
    -- The shared segmented control draws it, so it looks like every other segment switch.
    local function BuildOverridesModeToggle(parent, y)
        -- Wider than the Raid Frames pair (162): "Conditional Overrides" is a longer label than "Custom Buff Display" and must not clip.
        local BTN_W, BTN_H = 180, 31
        local seg = NoxUI.BuildSegmentedControl({
            parent     = parent,
            keys       = { "spec", "cond" },
            labels     = { spec = "Spec Overrides", cond = "Conditional Overrides" },
            width      = BTN_W * 2,
            square     = true,
            height     = BTN_H,
            getChecked = function(key) return (NoxUI._overridesTabMode or "spec") == key end,
            onToggle   = function(key)
                if (NoxUI._overridesTabMode or "spec") == key then return end
                NoxUI._overridesTabMode = key
                -- Forced: the two builders render entirely different rows.
                NoxUI:RefreshPage(true)
            end,
        })
        seg:SetPoint("TOP", parent, "TOP", 0, y - 14)
        seg:SetFrameLevel(parent:GetFrameLevel() + 1)
        -- 14 above + 15 below the buttons.
        return BTN_H + 29
    end

    -- FULL EXPORT tab: a warning and one button, with its own exporter (NoxUI.ExportFullAccountData) sharing NO code path with the
    -- Profiles tab's export flow, so nothing here changes a normal profile string.
    local PAGE_FULLEXPORT = "Full Export"

    local function BuildFullExportPage(parent, yOffset)
        local PAD = NoxUI.CONTENT_PAD or 40
        local y = yOffset - 10
        local width = parent:GetWidth() - PAD * 2

        -- Warning card (red-bordered, full width).
        local warn = CreateFrame("Frame", nil, parent)
        warn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        warn:SetWidth(width)
        warn:SetFrameLevel(parent:GetFrameLevel() + 2)
        local wbg = NoxUI.SolidTex(warn, "BACKGROUND", 0.10, 0.04, 0.04, 0.55)
        wbg:SetAllPoints()
        NoxUI.MakeRoundedBorder(warn, 0.8, 0.2, 0.2, 0.55, wbg)
        local wtext = NoxUI.MakeFont(warn, 13, nil, 1, 0.55, 0.55, 1)
        wtext:SetPoint("TOPLEFT", warn, "TOPLEFT", 16, -14)
        wtext:SetWidth(width - 32)
        wtext:SetJustifyH("LEFT")
        wtext:SetSpacing(3)
        wtext:SetText(NoxUI.L("This export includes cross profile settings that will overwrite the importing user's settings including Quality of Life, Hovercast and more that should typically not be shared with standard profiles. THIS IS NOT RECOMMENDED for public sharing of profiles."))
        warn:SetHeight((wtext:GetStringHeight() or 40) + 28)
        y = y - warn:GetHeight() - 40

        -- Centered export button.
        local BTN_W, BTN_H = 300, 38
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("TOP", parent, "TOP", 0, y)
        btn:SetFrameLevel(parent:GetFrameLevel() + 5)
        local DARK_BG = NoxUI.DARK_BG
        local bbg = NoxUI.SolidTex(btn, "BACKGROUND", DARK_BG.r, DARK_BG.g, DARK_BG.b, 0.92)
        bbg:SetAllPoints()
        local EG = NoxUI.NOX_GREEN or { r = 0.05, g = 0.82, b = 0.62 }
        local bbrd = NoxUI.MakeRoundedBorder(btn, EG.r, EG.g, EG.b, 0.5, bbg)
        local blbl = NoxUI.MakeFont(btn, 13, nil, EG.r, EG.g, EG.b, 1)
        blbl:SetAlpha(0.8)
        blbl:SetPoint("CENTER")
        blbl:SetText(NoxUI.L("Export All Data with Profile"))
        btn:SetScript("OnEnter", function()
            blbl:SetAlpha(1)
            if bbrd and bbrd.SetColor then bbrd:SetColor(EG.r, EG.g, EG.b, 0.9) end
        end)
        btn:SetScript("OnLeave", function()
            blbl:SetAlpha(0.8)
            if bbrd and bbrd.SetColor then bbrd:SetColor(EG.r, EG.g, EG.b, 0.5) end
        end)
        btn:SetScript("OnClick", function()
            local str = NoxUI.ExportFullAccountData()
            if str then
                NoxUI:ShowExportPopup(str)
            else
                NoxUI:ShowInfoPopup({
                    title = NoxUI.L("Export Failed"),
                    content = NoxUI.L("Could not build the export string."),
                })
            end
        end)
        y = y - BTN_H - 20

        return -y + 40
    end

    -- Runs the toggle, then the selected mode's builder. Builders return total content height measured from the ORIGINAL page top (they
    -- accumulate from the startY handed in), so the toggle's space is already included.
    local function BuildOverridesPage(parent, yOffset)
        local y = yOffset - BuildOverridesModeToggle(parent, yOffset)
        if (NoxUI._overridesTabMode or "spec") == "cond" then
            if NoxUI.Conditions_BuildListPage then
                return NoxUI.Conditions_BuildListPage(parent, y)
            end
        elseif NoxUI.SpecOverrides_BuildListPage then
            return NoxUI.SpecOverrides_BuildListPage(parent, y)
        end
        return 200
    end
    NoxUI:RegisterModule(PROFILES_KEY, {
        title       = "Mes profils",
        description = "Import, export, and switch NoxUI profiles.",
        pages       = { PAGE_PROFILES, PAGE_OVERRIDES, PAGE_FULLEXPORT },
        tabLabels   = {
            [PAGE_PROFILES] = "Mes profils",
            [PAGE_OVERRIDES] = "Variantes",
            [PAGE_FULLEXPORT] = "Export complet",
        },
        buildPage   = function(pageName, parent, yOffset)
            -- _G._EUI_BuildProfilesPage bypasses `parent` and builds onto the live shared _scrollFrame, and first checks the active profile against the
            -- current spec -- it can call SwitchProfile/RefreshAllAddons and pop a "Reload Required" confirmation. None of that is safe from a
            -- hidden indexing pass, so skip PAGE_PROFILES; it indexes on the player's first visit.
            if NoxUI._prebuilding then
                if pageName == PAGE_OVERRIDES then
                    -- Index the spec list only: the conditional builder is not part of the hidden pre-build pass, and the toggle is chrome.
                    if NoxUI.SpecOverrides_BuildListPage then
                        return NoxUI.SpecOverrides_BuildListPage(parent, yOffset)
                    end
                    return 200
                end
                return
            end
            if pageName == PAGE_OVERRIDES then
                CleanupProfilesRoot()
                return BuildOverridesPage(parent, yOffset)
            end
            if pageName == PAGE_FULLEXPORT then
                CleanupProfilesRoot()
                return BuildFullExportPage(parent, yOffset)
            end
            return _G._EUI_BuildProfilesPage(pageName, parent, yOffset)
        end,
        onPageCacheRestore = function(pageName)
            if pageName == PAGE_FULLEXPORT then
                -- The Profiles page builds onto the SHARED profiles root, which outlives page switches, so a cached Full Export page would show
                -- profiles content layered over it. The page itself is static, so cleanup is enough -- no rebuild.
                CleanupProfilesRoot()
            elseif pageName == PAGE_OVERRIDES then
                CleanupProfilesRoot()
                -- The override list changes while the page is cached; rebuild.
                C_Timer.After(0, function()
                    if NoxUI:GetActiveModule() == PROFILES_KEY
                       and NoxUI:GetActivePage() == pageName then
                        NoxUI:RefreshPage(true)
                    end
                end)
            elseif not NoxUI._profilesRoot then
                C_Timer.After(0, function()
                    if NoxUI:GetActiveModule() == PROFILES_KEY
                       and NoxUI:GetActivePage() == pageName then
                        RenderProfilesRoot()
                    end
                end)
            else
                -- Shared root is alive but the Presets tab may have left its subpage showing; the Profiles tab lands on main. An active API
                -- import session wins -- re-enter instead of hiding its page.
                local s = NoxUI._apiImportSession
                if s and s.state ~= "done" then
                    if NoxUI._ProfilesConsumeApiImport then
                        NoxUI._ProfilesConsumeApiImport()
                    end
                elseif NoxUI._ProfilesResetToMain then
                    NoxUI._ProfilesResetToMain()
                end
            end
        end,
    })

    -- Patch notes are available in the full suite.
    if not IS_STANDALONE then
        NoxUI:RegisterModule(PATCHNOTES_KEY, {
            title       = "Nouveautés de NoxUI",
            description = NoxUI.L("What's new in NoxUI."),
            pages       = { PAGE_WHATSNEW },
            _searchPrebuild = false, -- a feed with no settings: the pass indexed nothing here
            buildPage   = function(pageName, parent, yOffset)
                return NoxUI._BuildWhatsNewPage(pageName, parent, yOffset)
            end,
        })
        -- Window Scale: the header's panel scale slider, left of the collapse box and
        -- centred on the close X. 5% steps from 75% to 200%: a drag shows its value
        -- live and applies on release, the mouse wheel steps one notch per tick, and
        -- every change glides with the track pinned (SetPanelScale), so the slider
        -- never slides out from under the cursor. Built on the first open.
        local scaleCtl, ScaleCtlRefresh
        local function BuildScaleControl()
            local ca = NoxUI._clickArea
            if scaleCtl or not ca then return end
            local MIN = NoxUI.PANEL_SCALE_MIN * 100
            local MAX = NoxUI.PANEL_SCALE_MAX * 100
            local STEP, TRACK_W, PCT_W = 5, 110, 40
            local ctl = CreateFrame("Frame", nil, ca)
            scaleCtl = ctl
            ctl:SetFrameLevel(ca:GetFrameLevel() + 20)
            ctl:SetHeight(24)
            ctl:SetPoint("RIGHT", ca, "TOPRIGHT", -110, -31)

            local pctFs = NoxUI.MakeFont(ctl, 13, nil, 1, 1, 1, 0.9)
            pctFs:SetWidth(PCT_W)
            pctFs:SetJustifyH("RIGHT")
            pctFs:SetPoint("RIGHT", ctl, "RIGHT", 0, 0)
            local function ShowPct(v)
                pctFs:SetText(string.format("%d%%", math.floor(v + 0.5)))
            end
            local function SavedPct()
                return ((NoxUIDB and NoxUIDB.panelScale) or 1) * 100
            end

            local pending   -- the dragged value, shown until the release applies it
            local track, valBox, refresh
            local function Apply(v)
                ShowPct(v)
                if math.abs(v - SavedPct()) < 0.01 then return end
                NoxUI:SetPanelScale(v / 100, track)
            end
            -- Panel chrome, not page content: the refresh the slider registers
            -- leaves the shown page's refresh list again (ScaleCtlRefresh and the
            -- accent callback below repaint it), so the page's first build
            -- registers what its later builds do.
            local pageRefresh = NoxUI._widgetRefreshList
            local pageRefreshN = #pageRefresh
            track, valBox, refresh = NoxUI.BuildSliderCore(ctl, TRACK_W, 4, 12, PCT_W, 20, 12, 0.5,
                MIN, MAX, STEP,
                function() return pending or SavedPct() end,
                function(v)
                    if NoxUI._sliderDragging then
                        pending = v
                        ShowPct(v)
                        return
                    end
                    pending = nil
                    Apply(v)
                end, true)
            for i = #pageRefresh, pageRefreshN + 1, -1 do pageRefresh[i] = nil end
            valBox:Hide()   -- the plain readout replaces the input box
            track:SetPoint("RIGHT", pctFs, "LEFT", -10, 0)

            local label = NoxUI.MakeFont(ctl, 13, nil, 1, 1, 1, 0.6)
            label:SetText(NoxUI.L("Window Scale"))
            label:SetPoint("RIGHT", track, "LEFT", -16, 0)
            -- The whole control takes the wheel; clicks off the track still reach the
            -- click area below (the window drag).
            ctl:SetWidth(PCT_W + 10 + TRACK_W + 16 + label:GetStringWidth())
            ctl:EnableMouseWheel(true)
            ctl:SetScript("OnMouseWheel", function(_, delta)
                if NoxUI._sliderDragging then return end
                if NoxUI:StepPanelScale(delta, track) then
                    ShowPct(SavedPct())
                    refresh()
                end
            end)

            ScaleCtlRefresh = function()
                pending = nil
                ShowPct(SavedPct())
                refresh()
            end
            ScaleCtlRefresh()
            -- Shift + mouse wheel elsewhere on the panel steps the scale too: the
            -- readout follows at once and an accent outline round the control (a
            -- padded host, our own frame) lights up and fades, so the change is easy
            -- to trace. Each step restarts the fade.
            local glowHost = CreateFrame("Frame", nil, ctl)
            glowHost:SetPoint("TOPLEFT", ctl, "TOPLEFT", -10, 6)
            glowHost:SetPoint("BOTTOMRIGHT", ctl, "BOTTOMRIGHT", 8, -6)
            local PlayGlow = NoxUI.MakeSettingGlow({ color = NoxUI.NOX_GREEN })
            NoxUI._FlashWindowScale = function()
                ScaleCtlRefresh()
                PlayGlow(glowHost)
            end
            NoxUI.RegAccent({ type = "callback", fn = function() refresh() end })
            -- Any scale change (this slider, Reset) lands here once its glide ends.
            if not NoxUI._onScaleChanged then NoxUI._onScaleChanged = {} end
            NoxUI._onScaleChanged[#NoxUI._onScaleChanged + 1] = function()
                if not NoxUI._sliderDragging then ScaleCtlRefresh() end
            end
        end
        local function ScaleCtlOnShow()
            if scaleCtl then ScaleCtlRefresh() else BuildScaleControl() end
        end
        NoxUI:RegisterOnShow(ScaleCtlOnShow)
        if NoxUI._mainFrame and NoxUI._mainFrame:IsShown() then ScaleCtlOnShow() end

    end

    -- Clean up profiles root when panel closes
    NoxUI:RegisterOnHide(function()
        CleanupProfilesRoot()
    end)

    -- Clean up profiles root when switching to any module other than Profiles
    if NoxUI.SelectModule then
        hooksecurefunc(NoxUI, "SelectModule", function(_, folderName)
            if folderName ~= PROFILES_KEY then
                CleanupProfilesRoot()
            end
        end)
    end

    -- HideAllChildren (every page switch) hides the profiles root too.
    NoxUI._AddScrollRootHider(CleanupProfilesRoot)
end)
-- LoadOnDemand: this addon loads after PLAYER_LOGIN, so the event above will never fire; run the init now.
if IsLoggedIn() then initFrame:GetScript("OnEvent")(initFrame) end
