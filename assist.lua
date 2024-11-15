local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local spells = require('spells')

local assist = {}

local charLevel = mq.TLO.Me.Level()

-- Helper function: Check if we have enough mana to cast the spell
local function hasEnoughMana(spellName)
    return spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
end

function assist.assistRoutine()

    if not gui.botOn and not gui.assistMelee then
        return
    end

    -- Use reference location to find mobs within assist range
    local mobsInRange = utils.referenceLocation(gui.assistRange) or {}
    if #mobsInRange == 0 then
        return
    end

    -- Check if the main assist is a valid PC, is alive, and is in the same zone
    local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
    if mainAssistSpawn and mainAssistSpawn.Type() == "PC" and not mainAssistSpawn.Dead() then
        mq.cmdf("/assist %s", gui.mainAssist)
        mq.delay(200)  -- Short delay to allow the assist command to take effect
    else
        return
    end

    -- Re-check the target after assisting to confirm it's an NPC within range
    if not mq.TLO.Target() or mq.TLO.Target.Type() ~= "NPC" then
        return
    end

    if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Stick() == "OFF" and not mq.TLO.Target.Mezzed() then
        if gui.stickFront then
            mq.cmd('/nav stop')
            mq.delay(100)
            mq.cmdf("/stick front %d uw", gui.stickDistance)
            mq.delay(100)
        elseif gui.stickBehind then
            mq.cmd('/nav stop')
            mq.delay(100)
            mq.cmdf("/stick behind %d uw", gui.stickDistance)
            mq.delay(100)
        end

        while mq.TLO.Target() and mq.TLO.Target.Distance() > gui.stickDistance and mq.TLO.Stick() == "ON" do
            mq.delay(10)
        end

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange then
            mq.cmd("/squelch /attack on")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
                mq.cmd("/squelch /pet attack")
            end
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) then
            mq.cmd("/squelch /attack off")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
                mq.cmd("/squelch /pet back")
            end
        end
    end

    if mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and mq.TLO.Target.Dead() ~= ("true" or "nil") then

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange then
            mq.cmd("/squelch /attack on")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
                mq.cmd("/squelch /pet attack")
            end
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) then
            mq.cmd("/squelch /attack off")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
                mq.cmd("/squelch /pet back")
            end
        end

        local feignName = spells.findBestSpell("FeignDeath", charLevel)
        if gui.feignDeath then
            if mq.TLO.Target() and gui.feignDeath and charLevel >= 24 and mq.TLO.Me.PctAggro() >= 80 and mq.TLO.Target.Distance() <= gui.assistRange and hasEnoughMana(feignName) and mq.TLO.Me.SpellReady(10)() then
                mq.cmd('/stick off')
                mq.delay(100)
                mq.cmd("/cast 10")
                mq.delay(100)

                while mq.TLO.Me.Casting() do
                    mq.delay(10)
                end

                while mq.TLO.Target() and mq.TLO.Me.PctAggro() > 80 and mq.TLO.Target.AggroHolder() do
                    mq.delay(10)
                    if mq.TLO.Target() and mq.TLO.Me.PctAggro() < 80 then
                        mq.cmd("/stand")
                        mq.delay(100)
                        if gui.stickFront then
                            mq.cmdf("/stick front %d uw", gui.stickDistance)
                        elseif gui.stickBehind then
                            mq.cmdf("/stick behind %d uw", gui.stickDistance)
                        end
                        mq.delay(100)
                        mq.cmd("/attack on")
                        mq.delay(100)
                        if mq.TLO.Target() and gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
                            mq.cmd("/squelch /pet attack")
                        end
                    end
                end
            end
        end

        if mq.TLO.Target() and mq.TLO.Me.PctHPs() < 50 and mq.TLO.Me.SpellReady(1) and charLevel >= 8 then
            mq.cmd('/stick off')
            mq.delay(100)
            mq.cmd('/cast 1')
            mq.delay(100)

            while mq.TLO.Me.Casting() do
                mq.delay(10)
            end

            if gui.stickFront then
                mq.cmdf("/stick front %d uw", gui.stickDistance)
            elseif gui.stickBehind then
                mq.cmdf("/stick behind %d uw", gui.stickDistance)
            end
        end

        local tapName = spells.findBestSpell("LifeTap", charLevel)
        local snareName = spells.findBestSpell("Snare", charLevel)
        local fireName = spells.findBestSpell("FireDot", charLevel)
        local diseaseName = spells.findBestSpell("DiseaseDoT", charLevel)

        if mq.TLO.Me.SpellReady(1)() and charLevel >= 8 and mq.TLO.Me.PctHPs() < 50 and hasEnoughMana(tapName) then
            mq.cmd("/cast 1")
        elseif mq.TLO.Me.SpellReady(2)() and charLevel >= 11 and mq.TLO.Target.PctHPs() < 50 and (mq.TLO.Target.Fleeing() or mq.TLO.Me.PctAggro() < 100) and not mq.TLO.Target.Snared() and mq.TLO.Me.PctMana() > 10 and hasEnoughMana(snareName) then
            mq.cmd("/cast 2")
        elseif mq.TLO.Me.SpellReady(4)() and charLevel >= 5 and mq.TLO.Target.Named() and mq.TLO.Me.PctMana() > 30 and hasEnoughMana(fireName) then
            mq.cmd("/cast 4")
        elseif mq.TLO.Me.SpellReady(5)() and charLevel >= 28 and mq.TLO.Target.Named() and mq.TLO.Me.PctMana() > 30 and hasEnoughMana(diseaseName) then
            mq.cmd("/cast 5")
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.assistRange then
            local bash = "Bash"
            local slam = "Slam"

            if mq.TLO.Target() and mq.TLO.Me.AbilityReady(bash) and mq.TLO.Me.Secondary() ~= "0"  then
                mq.cmdf('/doability %s', bash)
            elseif mq.TLO.Target() and mq.TLO.Me.AbilityReady(slam) and mq.TLO.Me.Secondary() == "0" and mq.TLO.Me.Race() == "Ogre"  then
                mq.cmdf('/doability %s', slam)
            end
        end

        if mq.TLO.Target() and mq.TLO.Stick() == "ON" then
            local stickDistance = gui.stickDistance
            local lowerBound = stickDistance * 0.9
            local upperBound = stickDistance * 1.1
            local targetDistance = mq.TLO.Target.Distance()

            if targetDistance > upperBound then
                mq.cmdf("/stick moveback %s", stickDistance)
                mq.delay(100)
            elseif targetDistance < lowerBound then
                mq.cmdf("/stick moveback %s", stickDistance)
                mq.delay(100)
            end
        end

    mq.delay(50)
    end
end

return assist