local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local spells = require('spells')
local nav = require('nav')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local assist = {}
local charName = mq.TLO.Me.Name()
local charLevel = mq.TLO.Me.Level()

local function hasEnoughMana(spellName)
    local manaCheck = spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
    debugPrint("Checking mana for spell:", spellName, "Has enough mana:", manaCheck)
    return manaCheck
end

local function inRange(spellName)
    local rangeCheck = mq.TLO.Target() and spellName and mq.TLO.Target.Distance() <= mq.TLO.Spell(spellName).Range() or false
    debugPrint("Checking range for spell:", spellName, "In range:", rangeCheck)
    return rangeCheck
end

local function currentlyActive(spell)
    if not mq.TLO.Target() then
        print("No target selected.")
        return false -- No target to check
    end

    local spellName = mq.TLO.Spell(spell).Name()
    if not spellName then
        print("Spell not found:", spell)
        return false -- Spell doesn't exist or was not found
    end

    -- Safely get the buff count with a default of 0 if nil
    local buffCount = mq.TLO.Target.BuffCount() or 0
    for i = 1, buffCount do
        if mq.TLO.Target.Buff(i).Name() == spellName then
            if mq.TLO.Target.Buff(spellName).Caster() == charName then
                return true -- Spell is active on the target
            else
                return false
            end
        else
            return false
        end
    end
end

function assist.assistRoutine()

    if not gui.botOn and not gui.assistOn then
        return
    end

    -- Use reference location to find mobs within assist range
    local mobsInRange = utils.referenceLocation(gui.assistRange) or {}
    if #mobsInRange == 0 then
        return
    end

    local stickDistance = gui.stickDistance
    local lowerBound = stickDistance * 0.5
    local upperBound = stickDistance * 1.1

    -- Check if the main assist is a valid PC, is alive, and is in the same zone
    local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
    if mainAssistSpawn and mainAssistSpawn.Type() == "PC" and not mainAssistSpawn.Dead() then
        mq.cmdf("/assist %s", gui.mainAssist)
        mq.delay(200)  -- Short delay to allow the assist command to take effect
    else
        return
    end

    -- Re-check the target after assisting to confirm it's an NPC within range
    if not mq.TLO.Target() or (mq.TLO.Target() and  mq.TLO.Target.Type() ~= "NPC") then
        return
    end

    if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and not mq.TLO.Stick.Active() and not mq.TLO.Target.Mezzed() then
        if gui.stickFront then
            if mq.TLO.Navigation.Active() then
                mq.cmd('/nav stop')
                mq.delay(100)
            end
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick front %d uw", gui.stickDistance)
            mq.delay(100)
        elseif gui.stickBehind then
            if mq.TLO.Navigation.Active() then
                mq.cmd('/nav stop')
                mq.delay(100)
            end
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick behind %d uw", gui.stickDistance)
            mq.delay(100)
        elseif gui.stickSide then
            if mq.TLO.Navigation.Active() then
                mq.cmd('/nav stop')
                mq.delay(100)
            end
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick pin %d uw", gui.stickDistance)
            mq.delay(100)
        end

        while mq.TLO.Target() and mq.TLO.Target.Distance() > gui.stickDistance and mq.TLO.Stick() == "ON" do
            mq.delay(10)
        end

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange then
            mq.cmd("/squelch /attack on")
            mq.delay(100)
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) then
            mq.cmd("/squelch /attack off")
            mq.delay(100)
        end
    end

    while mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and not mq.TLO.Target.Dead() do

        if not gui.botOn and not gui.assistOn then
            return
        end

        if gui.switchWithMA then
            mq.cmd("/squelch /assist %s", gui.mainAssist)
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Me.Combat() then
            debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
            mq.cmd("/squelch /attack on")
            mq.delay(100)
        end

        if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and not mq.TLO.Target.Mezzed() and gui.usePet and mq.TLO.Pet.IsSummoned() then
            debugPrint("DEBUG: Target is below assist percent and within assist range. - pet")
            mq.cmd("/squelch /pet attack")
            debugPrint("DEBUG: Pet attack is on.")
        elseif mq.TLO.Target() and gui.usePet and mq.TLO.Pet.IsSummoned() and mq.TLO.Me.Pet.Combat() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Pet.Distance() > gui.assistRange) then
            debugPrint("DEBUG: Target is mezzed, above assist percent, or out of assist range.")
            mq.cmd("/squelch /pet back off")
        end

        if mq.TLO.Target() and not utils.FacingTarget() and not mq.TLO.Target.Dead() and mq.TLO.Target.LineOfSight() then
            debugPrint("Facing target:", mq.TLO.Target.CleanName())
            mq.cmd("/squelch /face fast")
            mq.delay(100)
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Target.LineOfSight() then

            if mq.TLO.Target() and mq.TLO.Me.AbilityReady("Bash")() and mq.TLO.Me.Inventory('Offhand').Type() == "Shield" then
                debugPrint("Using Bash ability.")
                mq.cmd("/doability Bash")
                mq.delay(100)
            elseif mq.TLO.Target() and mq.TLO.Me.AbilityReady("Slam")() and mq.TLO.Me.Inventory('Offhand').Type() ~= "Shield" and mq.TLO.Me.Race() == "Ogre" then
                debugPrint("Using Slam ability.")
                mq.cmd("/doability Slam")
                mq.delay(100)
            end

            local spellsToCast = {
                {name = "LifeTap", spell = spells.findBestSpell("LifeTap", charLevel), slot = 1, cond = charLevel >= 8 and mq.TLO.Me.PctHPs() < 50},
                {name = "Snare", spell = spells.findBestSpell("Snare", charLevel), slot = 2, cond = charLevel >= 11 and mq.TLO.Target() and (mq.TLO.Target.PctHPs() or 0) < 50 and (mq.TLO.Target.Fleeing() or (mq.TLO.Me.PctAggro() or 100) < 100) and not mq.TLO.Target.Snared()},
                {name = "FireDot", spell = spells.findBestSpell("FireDot", charLevel), slot = 4, cond = charLevel >= 5 and mq.TLO.Target.Named()},
                {name = "DiseaseDoT", spell = spells.findBestSpell("DiseaseDoT", charLevel), slot = 5, cond = charLevel >= 28 and mq.TLO.Target.Named()}
            }

            for _, spellInfo in ipairs(spellsToCast) do
                local spellName, spell, slot, condition = spellInfo.name, spellInfo.spell, spellInfo.slot, spellInfo.cond
                if mq.TLO.Target() and spell and condition and mq.TLO.Me.SpellReady(slot)() and hasEnoughMana(spell) and inRange(spell) and not currentlyActive(spell) then
                    mq.cmdf("/squelch /stick off")
                    mq.delay(100)
                    debugPrint("Casting spell:", spellName, "on slot", slot)
                    mq.cmdf("/cast %d", slot)
                    mq.delay(100)
                end
                while mq.TLO.Me.Casting() do
                    mq.delay(10)
                end
            end
        end

        local lastStickDistance = nil

        if mq.TLO.Target() and mq.TLO.Stick() == "ON" then
            local stickDistance = gui.stickDistance -- current GUI stick distance
            local lowerBound = stickDistance * 0.9
            local upperBound = stickDistance * 1.1
            local targetDistance = mq.TLO.Target.Distance()
            
            -- Check if stickDistance has changed
            if lastStickDistance and lastStickDistance ~= stickDistance then
                lastStickDistance = stickDistance
                mq.cmdf("/squelch /stick moveback %s", stickDistance)
            end
    
            -- Check if the target distance is out of bounds and adjust as necessary
            if mq.TLO.Target() and not mq.TLO.Target.Dead() then
                if mq.TLO.Target() and targetDistance > upperBound then
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                    mq.delay(100)
                elseif mq.TLO.Target() and targetDistance < lowerBound then
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                    mq.delay(100)
                end
            end
        end

        if mq.TLO.Me.Combat() and not mq.TLO.Stick() then
            mq.cmd("/squelch /attack off")
        end

        if mq.TLO.Target() and mq.TLO.Target.Dead() or not mq.TLO.Target() then
            mq.cmd("/squelch /attack off")
            return
        end

        mq.delay(100)
    end
end

return assist