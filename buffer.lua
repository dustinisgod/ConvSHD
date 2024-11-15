local mq = require('mq')
local spells = require('spells')
local utils = require('utils')
local gui = require('gui')
local tank = require('tank')

local buffer = {}
buffer.buffQueue = {}

local charLevel = mq.TLO.Me.Level()

-- Helper function: Pre-cast checks for combat, movement, and casting status
local function preCastChecks()
    return not (mq.TLO.Me.Moving() or mq.TLO.Me.Combat() or mq.TLO.Me.Casting())
end

-- Helper function: Check if we have enough mana to cast the spell
local function hasEnoughMana(spellName)
    return spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
end

-- Function to handle the heal routine and return
local function handleTankRoutineAndReturn()
    tank.tankRoutine()
    return true
end

function buffer.buffRoutine()
    if not gui.botOn and gui.buffsOn then return end

    if not preCastChecks() then
        return
    end

    if mq.TLO.Me.PctMana() < 20 then
        return
    end

    local spellTypes = {}

    -- Determine which buffs to apply based on the player's level and GUI settings
    if gui.buffsOn and charLevel >= 39 then
        table.insert(spellTypes, "AggroMultiplier")
    end
    if gui.buffsOn and charLevel >= 22 then
        table.insert(spellTypes, "LifeStealBuff")
    end
    if gui.buffsOn and charLevel >= 16 then
        table.insert(spellTypes, "AtkBuff")
    end

    -- Process each spell type for self-buffing only
    for _, spellType in ipairs(spellTypes) do
        if not gui.botOn then return end

        local bestSpell = spells.findBestSpell(spellType, charLevel)
        if bestSpell then
            buffer.buffQueue = {}

            -- Define specific slots for each spell type
            local spellSlot
            if spellType == "AggroMultiplier" then
                spellSlot = 7
            elseif spellType == "LifeStealBuff" then
                spellSlot = 6
            elseif spellType == "AtkBuff" then
                spellSlot = 8
            else
                spellSlot = 10 -- Default slot for unspecified cases
            end

            -- Check if the spell is already memorized in the slot, load if necessary
            if mq.TLO.Me.Gem(spellSlot).Name() ~= bestSpell then
                spells.loadAndMemorizeSpell(spellType, charLevel, spellSlot)
            end

            -- Check if the buff is missing and if it stacks on the player
            if not mq.TLO.Me.Buff(bestSpell)() and mq.TLO.Spell(bestSpell).Stacks() then
                table.insert(buffer.buffQueue, {spell = bestSpell, spellType = spellType, slot = spellSlot})
            end

            -- Process the buff queue
            buffer.processBuffQueue()
        end
    end
end

function buffer.processBuffQueue()
    while #buffer.buffQueue > 0 do
        if not gui.botOn and gui.buffsOn then
            return
        end

        if not preCastChecks() then
            return
        end

        if not handleTankRoutineAndReturn() then
            return
        end

        if mq.TLO.Me.PctMana() < 20 then
            return
        end

        local buffTask = table.remove(buffer.buffQueue, 1)
        local maxReadyAttempts = 20
        local readyAttempt = 0

        -- Target self if casting AggroMultiplier
        if buffTask.spellType == "AggroMultiplier" then
            mq.cmd("/target myself")
            mq.delay(100)
        end

        -- Ensure spell is ready before proceeding
        while not mq.TLO.Me.SpellReady(buffTask.spell)() and readyAttempt < maxReadyAttempts do
            if not gui.botOn then return end
            readyAttempt = readyAttempt + 1
            mq.delay(1000)
        end

        if not mq.TLO.Me.SpellReady(buffTask.spell)() then
            break
        end

        if not hasEnoughMana(buffTask.spell) then
            return
        end

        mq.cmdf('/cast %d', buffTask.slot)
        mq.delay(500)  -- Allow time for casting to start

        -- Wait for casting to complete, or stop if conditions are met
        while mq.TLO.Me.Casting() do
            mq.delay(50)
        end

        -- Reinsert into the queue if the buff was not applied successfully
        if not mq.TLO.Me.Buff(buffTask.spell)() then
            table.insert(buffer.buffQueue, buffTask)
        end

        mq.delay(100)
    end
end

return buffer