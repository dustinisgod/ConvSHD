local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local nav = require('nav')
local spells = require('spells')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local tank = {}
local charLevel = mq.TLO.Me.Level()
local charName = mq.TLO.Me.Name()

local function buildMobQueue(range)
    debugPrint("Building mob queue with range:", range)
    local zoneName = mq.TLO.Zone.ShortName() or "UnknownZone"
    local ignoreList = utils.tankConfig[zoneName] or {}
    local globalIgnoreList = utils.tankConfig.globalIgnoreList or {}

    -- Filter mobs within range and not ignored
    local mobs = mq.getFilteredSpawns(function(spawn)
        local mobName = spawn.CleanName() or ""
        local isPlayerPet = spawn.Owner() and spawn.Owner.Type() == "PC"
        local isIgnored = ignoreList[mobName] or globalIgnoreList[mobName]

        return spawn.Type() == "NPC" and
               (spawn.Distance() or math.huge) <= range and
               not isPlayerPet and
               not spawn.Dead() and
               spawn.LineOfSight() and
               not isIgnored
    end)

    -- Sort mobs by priority: PctHPs (ascending), Named, then Level (descending)
    table.sort(mobs, function(a, b)
        local aPctHPs = a.PctHPs() or 100
        local bPctHPs = b.PctHPs() or 100
        local aNamed = a.Named() or false
        local bNamed = b.Named() or false
        local aLevel = a.Level() or 0
        local bLevel = b.Level() or 0

        if aPctHPs ~= bPctHPs then
            return aPctHPs < bPctHPs -- prioritize lower HP percentage
        elseif aNamed ~= bNamed then
            return aNamed -- prioritize named mobs
        else
            return aLevel > bLevel -- then by level, descending
        end
    end)

    debugPrint("Mob queue built with", #mobs, "mobs in range")
    return mobs
end

local function hasEnoughMana(spellName)
    local manaCheck = spellName and mq.TLO.Me.CurrentMana() >= mq.TLO.Spell(spellName).Mana()
    debugPrint("Checking mana for spell:", spellName, "Has enough mana:", manaCheck)
    return manaCheck
end

local function inRange(spellName)
    local rangeCheck = false

    if mq.TLO.Target() and spellName then
        local targetDistance = mq.TLO.Target.Distance()
        local spellRange = mq.TLO.Spell(spellName) and mq.TLO.Spell(spellName).Range()

        if targetDistance and spellRange then
            rangeCheck = targetDistance <= spellRange
        else
            debugPrint("DEBUG: Target distance or spell range is nil for spell:", spellName)
        end
    else
        if not mq.TLO.Target() then
            debugPrint("DEBUG: No target available for range check.")
        end
        if not spellName then
            debugPrint("DEBUG: Spell name is nil.")
        end
    end

    debugPrint("DEBUG: Checking range for spell:", spellName, "In range:", tostring(rangeCheck))
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
            debugPrint("DEBUG: Spell is active on the target.")
            if mq.TLO.Target.Buff(spellName).Caster() == charName then
                debugPrint("DEBUG: Spell is active on the target and was cast by the character.")
                return true -- Spell is active on the target
            else
                debugPrint("DEBUG: Spell is active on the target but was not cast by the character.")
                return false
            end
        else
            debugPrint("DEBUG: Spell is not active on the target.")
            return false
        end
    end
end

function tank.tankRoutine()
    if not gui.botOn and not gui.tankOn then
        debugPrint("Bot or melee mode is off; exiting combat loop.")
        mq.cmd("/squelch /attack off")
        mq.delay(100)
        mq.cmd("/squelch /stick off")
        mq.delay(100)
        if mq.TLO.Navigation.Active() then
            debugPrint("Stopping navigation.")
            mq.cmd("/squelch /nav stop")
        end
        return
    end

    local stickDistance = gui.stickDistance
    local lowerBound = stickDistance * 0.9
    local upperBound = stickDistance * 1.1

    while true do
        if not gui.botOn and not gui.tankOn then
            debugPrint("Bot or melee mode is off; exiting combat loop.")
            mq.cmd("/squelch /attack off")
            mq.delay(100)
            mq.cmd("/squelch /stick off")
            mq.delay(100)
            if mq.TLO.Navigation.Active() then
                debugPrint("Stopping navigation.")
                mq.cmd("/squelch /nav stop")
            end
            return
        end

        local nearbyNPCs = mq.TLO.SpawnCount(string.format('npc radius %d los', gui.tankRange))() or 0
        local mobsInRange = {}

        if nearbyNPCs > 0 then
            debugPrint("Nearby NPCs:", nearbyNPCs)
        mobsInRange = buildMobQueue(gui.tankRange)
        end

        if #mobsInRange == 0 then
            debugPrint("No mobs in range.")

            if gui.travelTank then
                debugPrint("Travel mode is enabled.")
                if mq.TLO.Navigation.Paused() then
                    debugPrint("Resuming navigation.")
                    mq.cmd("/squelch /nav pause")
                    mq.delay(100)
                end
            end

            if mq.TLO.Me.Combat() then
                debugPrint("Exiting combat mode.")
                mq.cmd("/squelch /attack off")
                mq.delay(100)
                if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and mq.TLO.Me.Pet.Combat() then
                    debugPrint("Calling pet back.")
                    mq.cmd("/squelch /pet back off")
                    mq.delay(100)
                end
                return
            end

            return
        end

        local target = table.remove(mobsInRange, 1)
        debugPrint("Target:", target)

        if target and target.Distance() ~= nil and target.Distance() <= gui.tankRange and (not mq.TLO.Target() or mq.TLO.Target.ID() ~= target.ID()) and target.LineOfSight() then
            mq.cmdf("/target id %d", target.ID())
            mq.delay(300)
            debugPrint("Target set to:", target.CleanName())
        end

        if not mq.TLO.Target() or (mq.TLO.Target() and mq.TLO.Target.ID() ~= target.ID()) then
            debugPrint("No target selected; exiting combat loop.")
            return
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Stick.Active() then
         debugPrint("Not stuck to target; initiating stick command.")
            if mq.TLO.Navigation.Active() and not mq.TLO.Navigation.Paused() then
                if not gui.travelTank then
                    debugPrint("Stopping navigation.")
                    if mq.TLO.Navigation.Active() then
                        debugPrint("Stopping navigation.")
                        mq.cmd("/squelch /nav stop")
                    end
                elseif gui.travelTank then
                    debugPrint("Pausing navigation.")
                    mq.cmd('/nav pause')
                end
                mq.delay(100, function() return not mq.TLO.Navigation.Active() end)
            end
            
            debugPrint("Stick distance:", stickDistance)
            mq.cmdf("/stick front %d uw", stickDistance)
            mq.delay(100, function() return mq.TLO.Stick.Active() end)
        end

        if mq.TLO.Target() and mq.TLO.Me.Combat() ~= nil and not mq.TLO.Me.Combat() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() ~= nil and mq.TLO.Target.LineOfSight() then
            debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
            mq.cmd("/squelch /attack on")
            mq.delay(100)
            if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and not mq.TLO.Me.Pet.Combat() and mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                debugPrint("Sending pet to attack.")
                mq.cmd("/squelch /pet attack")
                mq.delay(100)
            end
        end

        while mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and not mq.TLO.Target.Dead() do
            debugPrint("Combat state: ", mq.TLO.Me.CombatState())

            if gui.travelTank then
                debugPrint("Travel mode is enabled.")
                if mq.TLO.Navigation.Active() and not mq.TLO.Navigation.Paused() then
                    debugPrint("Pausing navigation.")
                    mq.cmd("/squelch /nav pause")
                end
            end

            if not gui.botOn and not gui.tankOn then
                debugPrint("Bot or melee mode is off; exiting combat loop.")
                mq.cmd("/squelch /attack off")
                mq.delay(100)
                mq.cmd("/squelch /stick off")
                mq.delay(100)
                if mq.TLO.Navigation.Active() then
                    debugPrint("Stopping navigation.")
                    mq.cmd("/squelch /nav stop")
                end
                return
            end

            if mq.TLO.Target() and target and (mq.TLO.Target.ID() ~= target.ID() or mq.TLO.Target.Type() ~= "NPC") then
                debugPrint("Target is not an NPC or has changed; exiting combat loop.")
                mq.cmdf("/target id %d", target.ID())
                mq.delay(200)
            end

            if mq.TLO.Target() and not mq.TLO.Target.Dead() and not mq.TLO.Stick.Active() and mq.TLO.Target.Distance() <= gui.tankRange then
                debugPrint("Not stuck to target; initiating stick command.")
                mq.cmdf("/stick front %d uw", stickDistance)
                mq.delay(100, function() return mq.TLO.Stick.Active() end)
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() and not mq.TLO.Me.Combat() then
                debugPrint("Starting attack on target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /attack on")
                mq.delay(100)
                if gui.usePet and mq.TLO.Me.Pet() ~= 'NO PET' and not mq.TLO.Me.Pet.Combat() and mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and  mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                    debugPrint("Sending pet to attack.")
                    mq.cmd("/squelch /pet attack")
                elseif mq.TLO.Target() and gui.petOn and mq.TLO.Me.Pet() ~= 'NO PET' and mq.TLO.Me.Pet.Combat() and (mq.TLO.Target.Mezzed() or mq.TLO.Pet.Distance() > gui.tankRange) then
                    debugPrint("Setting pet target to:", mq.TLO.Target.CleanName())
                    mq.cmd("/squelch /pet back off")
                end
            end

            if mq.TLO.Target() and not utils.FacingTarget() and not mq.TLO.Target.Dead() and mq.TLO.Target.LineOfSight() then
                debugPrint("Facing target:", mq.TLO.Target.CleanName())
                mq.cmd("/squelch /face fast")
                mq.delay(100)
            end

            if mq.TLO.Target() and mq.TLO.Target.Distance() ~= nil and mq.TLO.Target.Distance() <= gui.tankRange and mq.TLO.Target.LineOfSight() then
                debugPrint("Checking abilities.")
                if mq.TLO.Target() and mq.TLO.Me.AbilityReady("Taunt")() and mq.TLO.Me.PctAggro() < 100 then
                    debugPrint("Using Taunt ability.")
                    mq.cmd("/doability Taunt")
                    mq.delay(100)
                end

                if mq.TLO.Target() and mq.TLO.Me.AbilityReady("Bash")() and mq.TLO.Me.Secondary() ~= "0" then
                    debugPrint("Using Bash ability.")
                    mq.cmd("/doability Bash")
                    mq.delay(100)
                elseif mq.TLO.Target() and mq.TLO.Me.AbilityReady("Slam")() and mq.TLO.Me.Secondary() == "0" and mq.TLO.Me.Race() == "Ogre" then
                    debugPrint("Using Slam ability.")
                    mq.cmd("/doability Slam")
                    mq.delay(100)
                end

                local spellsToCast = {
                    {name = "LifeTap", spell = spells.findBestSpell("LifeTap", charLevel), slot = 1, cond = charLevel >= 8 and mq.TLO.Me.PctHPs() < 30},
                    {name = "Snare", spell = spells.findBestSpell("Snare", charLevel), slot = 2, cond = charLevel >= 11 and mq.TLO.Target() and (mq.TLO.Target.Fleeing() or mq.TLO.Me.PctAggro() < 100) and not mq.TLO.Target.Snared() and mq.TLO.Me.PctMana() >= 20},
                    {name = "HateIncrease", spell = spells.findBestSpell("HateIncrease", charLevel), slot = 3, cond = charLevel >= 33 and mq.TLO.Target() and mq.TLO.Me.PctAggro() < 100},
                    {name = "FireDot", spell = spells.findBestSpell("FireDot", charLevel), slot = 4, cond = charLevel >= 5 and mq.TLO.Target() and ((mq.TLO.Me.PctMana() > 60 and mq.TLO.Target.PctHPs() > 60) or (mq.TLO.Target.Named() and mq.TLO.Me.PctMana() > 20))},
                    {name = "DiseaseDoT", spell = spells.findBestSpell("DiseaseDoT", charLevel), slot = 5, cond = charLevel >= 28 and mq.TLO.Target() and ((mq.TLO.Me.PctMana() > 60 and mq.TLO.Target.PctHPs() > 60) or (mq.TLO.Target.Named() and mq.TLO.Me.PctMana() > 20))},
                }

                for _, spellInfo in ipairs(spellsToCast) do
                    local spellName, spell, slot, condition = spellInfo.name, spellInfo.spell, spellInfo.slot, spellInfo.cond
                    if mq.TLO.Target() and spell and condition and mq.TLO.Me.SpellReady(slot)() and hasEnoughMana(spell) and inRange(spell) and not currentlyActive(spell) then
                        debugPrint("Casting spell:", spellName, "on slot", slot)
                        mq.cmdf("/squelch /stick off")
                        mq.delay(100)
                        if not mq.TLO.Me.Moving() then
                            mq.cmdf("/cast %d", slot)
                            mq.delay(100)
                        end

                        while mq.TLO.Me.Casting() do
                            if mq.TLO.Target() and not mq.TLO.Target.LineOfSight() then
                                debugPrint("Interrupting spell cast.")
                                mq.cmd("/squelch /stopcast")
                                mq.delay(100)
                                break
                            elseif not mq.TLO.Target() or target and target.Dead() then
                                debugPrint("Target is dead; exiting combat loop.")
                                mq.cmd("/squelch /stopcast")
                                break
                            end
                            mq.delay(10)
                        end
                    else
                        debugPrint("Spell not ready or not in range:", spellName)
                    end
                end
            end

            local lastStickDistance = nil

            if target and mq.TLO.Target() and mq.TLO.Stick.Active() then
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

            if target and target.Dead() then
                debugPrint("Target is dead; exiting combat loop.")
                break
            end

            mq.delay(50)
        end
        mq.delay(50)
    end
end

return tank