local mq = require('mq')
local gui = require('gui')
local utils = require('utils')

local assist = {}

local charLevel = mq.TLO.Me.Level()

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

        if gui.feignDeath then
            if mq.TLO.Target() and gui.feignDeath and charLevel >= 24 and mq.TLO.Me.PctAggro() >= 80 and mq.TLO.Target.Distance() <= gui.assistRange then
                mq.cmd('/stick off')
                mq.delay(100)
                mq.cmd("/cast 8")
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
                        if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' then
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

        if mq.TLO.Target() and mq.TLO.Target.PctHPs() < 50 and mq.TLO.Me.SpellReady(2) and charLevel >= 11 and mq.TLO.Target.Fleeing() and not mq.TLO.Target.Snared() then
            mq.cmd('/cast 2')
        end

        if mq.TLO.Target() and mq.TLO.Me.PctAggro() < 100 and mq.TLO.Me.SpellReady(3) and charLevel >= 33 then
            mq.cmd('/cast 3')
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