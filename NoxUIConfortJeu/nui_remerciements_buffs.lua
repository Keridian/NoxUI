if NUI_CLIENT_BLOQUE or not (NoxUI and NoxUI.IS_FOREVER) then return end

local french = {
    "Merci pour {buff}, {joueur} ! Mon espérance de vie vient de dépasser celle d'un murloc asthmatique.",
    "{joueur}, merci pour {buff} ! Mon plan reste de foncer dans le tas, mais maintenant c'est une stratégie.",
    "Merci pour {buff}, {joueur} ! Mon esprit de résurrection venait justement de poser ses congés.",
    "{joueur}, merci pour {buff} ! Je vais peut-être enfin tuer un sanglier sans appeler des renforts.",
    "Merci pour {buff}, {joueur} ! Même mon soigneur vient d'arrêter de pleurer.",
    "{joueur}, merci pour {buff} ! C'est plus fiable qu'une invention gnome. Bon, la barre était basse.",
    "Merci pour {buff}, {joueur} ! Leroy Jenkins aurait adoré. Mon groupe, probablement moins.",
    "{joueur}, merci pour {buff} ! Mon armure te remercie. Le réparateur, beaucoup moins.",
    "Merci pour {buff}, {joueur} ! Je suis désormais dangereux. Enfin, surtout pour moi-même.",
    "{joueur}, merci pour {buff} ! Si je meurs quand même, on dira que c'était un problème de latence.",
}
local english = {
    "Thanks for {buff}, {joueur}! My life expectancy just surpassed that of an asthmatic murloc.",
    "Thanks for {buff}, {joueur}! My plan is still to charge blindly, but now it's called strategy.",
    "Thanks for {buff}, {joueur}! My ghost had just booked a well-deserved vacation.",
    "Thanks for {buff}, {joueur}! I might finally defeat a boar without calling for backup.",
    "Thanks for {buff}, {joueur}! Even my healer has stopped crying. That's a first.",
    "Thanks for {buff}, {joueur}! More reliable than gnomish engineering. Admittedly, a low bar.",
    "Thanks for {buff}, {joueur}! Leeroy Jenkins would approve. My party? Not so much.",
    "Thanks for {buff}, {joueur}! My armor thanks you. The repair vendor definitely doesn't.",
    "Thanks for {buff}, {joueur}! I'm officially dangerous now. Mostly to myself, but still.",
    "Thanks for {buff}, {joueur}! If I die anyway, we're blaming lag. That's the official story.",
}
local spanish = {
    "¡Gracias por {buff}, {joueur}! Mi esperanza de vida ya supera la de un múrloc con asma.",
    "¡Gracias por {buff}, {joueur}! Mi plan sigue siendo lanzarme a lo loco, pero ahora lo llamo estrategia.",
    "¡Gracias por {buff}, {joueur}! Mi fantasma acababa de reservar unas merecidas vacaciones.",
    "¡Gracias por {buff}, {joueur}! Quizá por fin pueda matar a un jabalí sin pedir refuerzos.",
    "¡Gracias por {buff}, {joueur}! Hasta mi sanador ha dejado de llorar. Eso es nuevo.",
    "¡Gracias por {buff}, {joueur}! Más fiable que la ingeniería gnómica. Tampoco era muy difícil.",
    "¡Gracias por {buff}, {joueur}! Leeroy Jenkins estaría orgulloso. Mi grupo, no tanto.",
    "¡Gracias por {buff}, {joueur}! Mi armadura te lo agradece. El herrero acaba de perder un cliente.",
    "¡Gracias por {buff}, {joueur}! Ahora soy peligroso. Sobre todo para mí mismo, pero algo es algo.",
    "¡Gracias por {buff}, {joueur}! Si muero igualmente, diremos que fue culpa del lag. Versión oficial.",
}
local messages = {
    enUS = english,
    enGB = english,
    frFR = french,
    esES = spanish,
    esMX = spanish,
    deDE = { "Danke, {joueur}, für {buff}!" },
    itIT = { "Grazie, {joueur}, per {buff}!" },
    ptBR = { "Valeu, {joueur}, por {buff}!" },
    ruRU = { "{joueur}, спасибо за {buff}!" },
    koKR = { "{joueur}님, {buff} 효과 감사합니다!" },
    zhCN = { "{joueur}，谢谢你施放{buff}！" },
    zhTW = { "{joueur}，謝謝你施放{buff}！" },
}
local events = CreateFrame("Frame")
local function CanRead(value)
    return not (issecretvalue and issecretvalue(value))
end

function NoxUI.SetBuffThanksEnabled(enabled)
    if not NoxUIDB then return end
    NoxUIDB.buffThanksEnabled = enabled == true
    if enabled then
        events:RegisterUnitEvent("UNIT_AURA", "player")
    else
        events:UnregisterEvent("UNIT_AURA")
    end
end

local function GetGift(aura)
    if not CanRead(aura) or type(aura) ~= "table" then return end
    local helpful, duration = aura.isHelpful, aura.duration
    if not CanRead(helpful) or helpful ~= true
        or not CanRead(duration) or type(duration) ~= "number" or duration < 120 then return end
    local unit = NoxUI.PlainString(aura.sourceUnit)
    local spell = NoxUI.PlainString(aura.name)
    if not unit or not spell then return end
    local player, self = UnitIsPlayer(unit), UnitIsUnit(unit, "player")
    if not CanRead(player) or not player or not CanRead(self) or self then return end
    local name, surname
    if UnitNameUnmodified then
        name, surname = UnitNameUnmodified(unit)
    else
        name, surname = UnitName(unit)
    end
    name = NoxUI.PlainString(name)
    surname = NoxUI.PlainString(surname)
    if not name or name == UNKNOWNOBJECT or not surname or surname == UNKNOWNOBJECT then return end
    local displayName = NoxUI.WithSurname(name, surname, true)
    if displayName == name then return end
    local spellID = aura.spellId
    if not CanRead(spellID) or type(spellID) ~= "number" or spellID < 1 then spellID = nil end
    return displayName, spell, spellID
end

local prefix = "NUIBuffThanks"
local chat = C_ChatInfo
local locale = GetLocale()
local pending, lastReply, lastChoice = {}, {}, {}
local sequence, ignoreUntil = 0, 0
local registered

local function SafeSpell(value)
    value = NoxUI.PlainString(value)
    if value and #value <= 160 and not value:find("[|%c]") then return value end
end

local function Reply(id, language, translatedSpell)
    local gift = pending[id]
    if not gift then return end
    pending[id] = nil
    if not (NoxUIDB and NoxUIDB.buffThanksEnabled) or InCombatLockdown() then return end
    local send = chat and chat.SendChatMessage or SendChatMessage
    if not send then return end
    local list = messages[language] or english
    local previous = lastChoice[list]
    local index = math.random(#list - (previous and #list > 1 and 1 or 0))
    if previous and #list > 1 and index >= previous then index = index + 1 end
    lastChoice[list] = index
    local text = list[index]:gsub("{(%a+)}", { joueur = gift.recipient, buff = translatedSpell or gift.spell })
    send(text, "WHISPER", nil, gift.recipient)
end

local function OnAddonMessage(incomingPrefix, payload, channel, sender)
    if not CanRead(incomingPrefix) or incomingPrefix ~= prefix
        or not CanRead(channel) or channel ~= "WHISPER" or InCombatLockdown() then return end
    payload, sender = NoxUI.PlainString(payload), NoxUI.PlainString(sender)
    if not payload or not sender then return end
    local id, spellID = payload:match("^Q:(%d+):(%d+)$")
    if id then
        local separator = Constants and Constants.CharacterNameSeparatorConsts
            and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
        if not sender:find(separator, 1, true) or #id > 9 or #spellID > 10 or not messages[locale] then return end
        local getSpell = C_Spell and C_Spell.GetSpellName
        local spell = getSpell and SafeSpell(getSpell(tonumber(spellID)))
        chat.SendAddonMessage(prefix, "A:" .. id .. ":" .. locale .. ":" .. (spell or ""), "WHISPER", sender)
        return
    end
    local token, language, spell = payload:match("^A:(%d+):(%a%a%u%u):(.*)$")
    local gift = token and pending[token]
    spell = SafeSpell(spell)
    -- The sender may include a realm suffix on the addon channel.
    if gift and (sender == gift.recipient or sender:match("^(.*)%-[^%s%-]+$") == gift.recipient)
        and messages[language] then
        Reply(token, language, spell)
    end
end

local function QueueReply(recipient, spell, spellID)
    sequence = sequence % 999999999 + 1
    local id = tostring(sequence)
    pending[id] = { recipient = recipient, spell = spell }
    if not registered or not spellID then
        Reply(id, "enUS")
        return
    end
    chat.SendAddonMessage(prefix, "Q:" .. id .. ":" .. spellID, "WHISPER", recipient)
    C_Timer.After(2, function() Reply(id, "enUS") end)
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, arg1, update, channel, sender)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        if chat and chat.RegisterAddonMessagePrefix and chat.SendAddonMessage then
            registered = chat.RegisterAddonMessagePrefix(prefix)
            if registered then self:RegisterEvent("CHAT_MSG_ADDON") end
        end
        NoxUI.SetBuffThanksEnabled(NoxUIDB and NoxUIDB.buffThanksEnabled == true)
        return
    end
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(arg1, update, channel, sender)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        wipe(pending)
        ignoreUntil = GetTime() + 2
        return
    end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    local now = GetTime()
    if not send or InCombatLockdown() or now < ignoreUntil
        or not CanRead(update) or type(update) ~= "table" then return end
    local full, added = update.isFullUpdate, update.addedAuras
    if not CanRead(full) or full or not CanRead(added) or type(added) ~= "table" then return end
    for _, aura in ipairs(added) do
        local name, spell, spellID = GetGift(aura)
        if name and not (lastReply[name] and now - lastReply[name] < 60) then
            for previous, timestamp in pairs(lastReply) do
                if now - timestamp >= 60 then lastReply[previous] = nil end
            end
            lastReply[name] = now
            QueueReply(name, spell, spellID)
        end
    end
end)
