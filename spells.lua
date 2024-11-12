mq = require('mq')

local spells = {
    Lifetap = {
        {level = 60, name = "Drain Soul"},
        {level = 57, name = "Drain Spirit"},
        {level = 51, name = "Siphon Life"},
        {level = 15, name = "Lifespike"},
        {level = 8, name = "Lifetap"}
    },
    Snare = {
        {level = 11, name = "Clinging Darkness"}
    },
    HateIncrease = {
        {level = 53, name = "Terror of Death"},
        {level = 42, name = "Terror of Shadows"},
        {level = 33, name = "Terror of Darkness"}
    },
    LifeStealBuff = {
        {level = 55, name = "Shroud of Undeath"},
        {level = 22, name = "Vampiric Embrace"}
    },
    AggroMultiplier = {
        {level = 60, name = "Voice of Terris"},
        {level = 55, name = "Voice of Death"},
        {level = 46, name = "Voice of Shadows"},
        {level = 39, name = "Voice of Darkness"}
    },
    AtkBuff = {
        {level = 16, name = "Grim Aura"}
    },
    PetHasteBuff = {
        {level = 59, name = "Augment Death"}
    },
    FeignDeath = {
        {level = 60, name = "Death Peace"},
        {level = 24, name = "Feign Death"}
    },
    SummonPet = {
        {level = 58, name = "Cackling Bones"},
        {level = 52, name = "Malignant Dead"},
        {level = 46, name = "Summon Dead"},
        {level = 38, name = "Animate Dead"},
        {level = 30, name = "Restless Bones"},
        {level = 22, name = "Convoke Shadow"},
        {level = 14, name = "Bone Walk"},
        {level = 7, name = "Leering Corpse"}
    }
}

-- Function to find the best spell for a given type and level
function spells.findBestSpell(spellType, charLevel)
    local spells = spells[spellType]

    if not spells then
        return nil -- Return nil if the spell type doesn't exist
    end

    -- Special case for BuffACHP at level 60, preferring "Blessing of Aegolism" if available
    if spellType == "FeignDeath" and charLevel == 60 then
        if mq.TLO.Me.Book('Death Peace')() then
            return "Death Peace"
        else
            return "Feign Death" -- Fallback to "Aegolism" if "Blessing of Aegolism" is not in the spellbook
        end
    end

    -- Special case for BuffACHP at level 60, preferring "Blessing of Aegolism" if available
    if spellType == "Lifetap" and charLevel == 60 then
        if mq.TLO.Me.Book('Drain Soul')() then
            return "Drain Soul"
        else
            return "Drain Spirit" -- Fallback to "Aegolism" if "Blessing of Aegolism" is not in the spellbook
        end
    end

    -- Special case for BuffACHP at level 60, preferring "Blessing of Aegolism" if available
    if spellType == "AggroMultiplier" and charLevel == 60 then
        if mq.TLO.Me.Book('Voice of Terris ')() then
            return "Voice of Terris"
        else
            return "Voice of Death" -- Fallback to "Aegolism" if "Blessing of Aegolism" is not in the spellbook
        end
    end

    -- General spell search for other types and levels
    for _, spell in ipairs(spells) do
        if charLevel >= spell.level then
            return spell.name
        end
    end
    

    return nil
end

function spells.loadDefaultSpells(charLevel)
    local defaultSpells = {}

    if charLevel >= 8 then
        defaultSpells[1] = spells.findBestSpell("Lifetap", charLevel)
    end
    if charLevel >= 11 then
        defaultSpells[2] = spells.findBestSpell("Snare", charLevel)
    end
    if charLevel >= 33 then
        defaultSpells[3] = spells.findBestSpell("HateIncrease", charLevel)
    end
    if charLevel >= 22 then
        defaultSpells[4] = spells.findBestSpell("LifeStealBuff", charLevel)
    end
    if charLevel >= 39 then
        defaultSpells[5] = spells.findBestSpell("AggroMultiplier", charLevel)
    end
    if charLevel >= 16 then
        defaultSpells[6] = spells.findBestSpell("AtkBuff", charLevel)
    end
    if charLevel >= 59 then
        defaultSpells[7] = spells.findBestSpell("PetHasteBuff", charLevel)
    end
    if charLevel >= 24 then
        defaultSpells[8] = spells.findBestSpell("FeignDeath", charLevel)
    end
    return defaultSpells
end

-- Function to memorize spells in the correct slots with delay
function spells.memorizeSpells(spells)
    for slot, spellName in pairs(spells) do
        if spellName then
            -- Check if the spell is already in the correct slot
            if mq.TLO.Me.Gem(slot)() == spellName then
                printf(string.format("Spell %s is already memorized in slot %d", spellName, slot))
            else
                -- Clear the slot first to avoid conflicts
                mq.cmdf('/mem "" %d', slot)
                mq.delay(500)  -- Short delay to allow the slot to clear

                -- Issue the /mem command to memorize the spell in the slot
                mq.cmdf('/mem "%s" %d', spellName, slot)
                mq.delay(1000)  -- Initial delay to allow the memorization command to take effect

                -- Loop to check if the spell is correctly memorized
                local maxAttempts = 10
                local attempt = 0
                while mq.TLO.Me.Gem(slot)() ~= spellName and attempt < maxAttempts do
                    mq.delay(500)  -- Check every 0.5 seconds
                    attempt = attempt + 1
                end

                -- Check if memorization was successful
                if mq.TLO.Me.Gem(slot)() ~= spellName then
                    printf(string.format("Failed to memorize spell: %s in slot %d", spellName, slot))
                else
                    printf(string.format("Successfully memorized %s in slot %d", spellName, slot))
                end
            end
        end
    end
end

function spells.loadAndMemorizeSpell(spellType, level, spellSlot)

    local bestSpell = spells.findBestSpell(spellType, level)

    if not bestSpell then
        printf("No spell found for type: " .. spellType .. " at level: " .. level)
        return
    end

    -- Check if the spell is already in the correct spell gem slot
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Spell " .. bestSpell .. " is already memorized in slot " .. spellSlot)
        return true
    end

    -- Memorize the spell in the correct slot
    mq.cmdf('/mem "%s" %d', bestSpell, spellSlot)

    -- Add a delay to wait for the spell to be memorized
    local maxAttempts = 10
    local attempt = 0
    while mq.TLO.Me.Gem(spellSlot).Name() ~= bestSpell and attempt < maxAttempts do
        mq.delay(2000) -- Wait 2 seconds before checking again
        attempt = attempt + 1
    end

    -- Check if the spell is now memorized correctly
    if mq.TLO.Me.Gem(spellSlot).Name() == bestSpell then
        printf("Successfully memorized spell " .. bestSpell .. " in slot " .. spellSlot)
        return true
    else
        printf("Failed to memorize spell " .. bestSpell .. " in slot " .. spellSlot)
        return false
    end
end

function spells.startup(charLevel)

    local defaultSpells = spells.loadDefaultSpells(charLevel)

    spells.memorizeSpells(defaultSpells)
end

return spells