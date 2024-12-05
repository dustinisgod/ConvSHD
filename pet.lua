local mq = require('mq')
local gui = require('gui')
local spells = require('spells')
local utils = require('utils')
local tank = require('tank')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local pet = {}
local charLevel = mq.TLO.Me.Level()

-- Function to handle the heal routine and return
local function handleTankRoutineAndReturn()
    debugPrint("Handling tank routine and return")
    tank.tankRoutine()
    utils.monitorNav()
    return true
end

function pet.petRoutine()
    -- Check if pet usage is enabled in GUI and if the character doesn't have a pet summoned
    if gui.usePet and mq.TLO.Me.Pet() == "NO PET" and charLevel >= 7 then
        -- Ensure pet summon spell is loaded
        local petSpellSlot = 9 -- Arbitrary slot for pet summon spell
        local petSpellName = spells.findBestSpell("SummonPet", charLevel)
        
        -- Only proceed if petSpellName is valid
        if petSpellName and mq.TLO.Me.Gem(petSpellSlot).Name() ~= petSpellName then
            spells.loadAndMemorizeSpell("SummonPet", charLevel, petSpellSlot)
        end

        -- Ensure spell is ready before proceeding
        if petSpellName then
            local maxReadyAttempts = 20
            local readyAttempt = 0
            while not mq.TLO.Me.SpellReady(petSpellName)() and readyAttempt < maxReadyAttempts do
                if not handleTankRoutineAndReturn() then
                    debugPrint("Tank routine failed")
                    return
                end
                if not gui.botOn then return end
                readyAttempt = readyAttempt + 1
                mq.delay(1000)
            end

            -- Summon pet if the spell is ready
            if mq.TLO.Me.SpellReady(petSpellName)() then
                mq.cmdf('/cast %d', petSpellSlot)
                mq.delay(100) -- Small delay for casting to start
                while mq.TLO.Me.Casting() do
                    mq.delay(50) -- Wait until casting is complete
                end
                mq.delay(100)
            end
            if mq.TLO.Me.Pet() ~= "NO PET" then
                mq.cmd("/pet hold on")
            end
        end
    end

    -- If character level is 59+ and pet exists, check and cast "Augment Death" if not present
    if gui.usePet and charLevel >= 59 and mq.TLO.Me.Pet() ~= "NO PET" and not mq.TLO.Me.Pet.Buff("Augment Death")() then
        -- Ensure "Augment Death" spell is loaded
        local buffSpellSlot = 9 -- Arbitrary slot for the pet buff spell
        local buffSpellName = spells.findBestSpell("PetHasteBuff", charLevel)
        
        -- Only proceed if buffSpellName is valid
        if buffSpellName and mq.TLO.Me.Gem(buffSpellSlot).Name() ~= buffSpellName then
            spells.loadAndMemorizeSpell("PetHasteBuff", charLevel, buffSpellSlot)
        end

        -- Ensure spell is ready before proceeding
        if buffSpellName then
            local maxReadyAttempts = 20
            local readyAttempt = 0
            while not mq.TLO.Me.SpellReady(buffSpellName)() and readyAttempt < maxReadyAttempts do
                if not gui.botOn then return end
                readyAttempt = readyAttempt + 1
                mq.delay(1000)
            end

            -- Cast "Augment Death" on pet if the spell is ready
            if mq.TLO.Me.SpellReady(buffSpellName)() then
                mq.cmdf('/cast %d', buffSpellSlot)
                mq.delay(100) -- Small delay for casting to start
                while mq.TLO.Me.Casting() do
                    mq.delay(50) -- Wait until casting is complete
                end
            end
        end
    end
end

return pet