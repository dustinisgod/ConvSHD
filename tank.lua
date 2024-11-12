local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local nav = require('nav')

local tank = {}
local stickDistance = 10
local charLevel = mq.TLO.Me.Level()

local function buildMobQueue(range)
    local zoneName = mq.TLO.Zone.ShortName() or "UnknownZone"
    local ignoreList = utils.tankConfig[zoneName] or {} -- Zone-specific ignore list
    local globalIgnoreList = utils.tankConfig.globalIgnoreList or {} -- Global ignore list

    local mobs = mq.getFilteredSpawns(function(spawn)
        local mobName = spawn.CleanName()
        -- Check if mob is in the ignore list for the zone or the global ignore list
        -- Ensure mob is within range, alive, not ignored, and in line of sight
        return spawn.Type() == "NPC" and 
               spawn.Distance() <= range and 
               not spawn.Dead() and 
               spawn.LineOfSight() and  -- Ensure mob is in line of sight
               not ignoreList[mobName] and 
               not globalIgnoreList[mobName]
    end)

    -- Sort mobs by priority: named mobs first, then by level (descending)
    table.sort(mobs, function(a, b)
        if a.Named() ~= b.Named() then
            return a.Named() -- prioritize named mobs
        else
            return a.Level() > b.Level() -- then by level, descending
        end
    end)

    return mobs
end

function tank.tankRoutine()
    if not gui.botOn and not gui.tankMelee then return end

    -- Main loop to continue until no targets are left in the queue
    while true do
        local mobsInRange = buildMobQueue(gui.tankRange)
        if #mobsInRange == 0 then
            mq.cmd("/squelch /attack off") -- Stop attacking if no more targets
            return
        end

        local target = table.remove(mobsInRange, 1) -- Highest priority target

        -- Engage target if valid
        if target and target.Distance() <= gui.tankRange and (not mq.TLO.Target() or mq.TLO.Target.ID() ~= target.ID()) then
            mq.cmdf("/target id %d", target.ID())
            mq.delay(200) -- Short delay to allow the target command to take effect
        end

        -- Stick to target if not already sticking
        if mq.TLO.Stick.Active() == false then
            mq.cmd('/nav stop')
            mq.delay(100)
            mq.cmdf("/stick front %d uw", stickDistance)
            mq.delay(100)
        end

        -- Attack target if not already attacking
        if not mq.TLO.Me.Combat() then
            mq.cmd("/squelch /attack on")
        end

        -- Combat loop
        while mq.TLO.Me.CombatState() == "COMBAT" and target and target.ID() == mq.TLO.Target.ID() and not target.Dead() do
            -- Rebuild mob queue to monitor new spawns entering range
            mobsInRange = buildMobQueue(gui.tankRange)


            if mq.TLO.Target() and mq.TLO.Me.PctAggro() < 100 then
                if nav.campLocation then
                    -- Retrieve player and camp coordinates
                    local playerX, playerY = mq.TLO.Me.X(), mq.TLO.Me.Y()
                    local campX = tonumber(nav.campLocation.x) or 0
                    local campY = tonumber(nav.campLocation.y) or 0
                    local campZ = tonumber(nav.campLocation.z) or 0
            
                    -- Calculate distance to camp
                    local distanceToCamp = math.sqrt((playerX - campX)^2 + (playerY - campY)^2)
            
                    -- Navigate back to camp if beyond threshold
                    if gui.returnToCamp and distanceToCamp > 100 then
                        mq.cmd("/squelch /attack off")
                        mq.delay(100)
                        mq.cmd("/stick off")
                        mq.delay(100)
                        mq.cmdf("/nav loc %f %f %f", campY, campX, campZ)
                        while mq.TLO.Navigation.Active() do
                            mq.delay(50)
                        end
                        return
                    end
                end
            end

            -- Run abilities and spells if within range and target alive
            if target.Distance() <= gui.tankRange then
                -- Ability: Taunt
                if mq.TLO.Me.AbilityReady("Taunt") and mq.TLO.Me.PctAggro() < 100 then
                    mq.cmd("/doability Taunt")
                end
                
                -- Ability: Bash or Slam
                if mq.TLO.Me.AbilityReady("Bash") and mq.TLO.Me.Secondary() ~= "0" then
                    mq.cmd("/doability Bash")
                elseif mq.TLO.Me.AbilityReady("Slam") and mq.TLO.Me.Secondary() == "0" and mq.TLO.Me.Race() == "Ogre" then
                    mq.cmd("/doability Slam")
                end

                -- Cast spells based on conditions
                if mq.TLO.Me.SpellReady(1) and charLevel >= 8 and mq.TLO.Me.PctHPs() < 50 then
                    mq.cmd("/cast 1")
                elseif mq.TLO.Me.SpellReady(2) and charLevel >= 11 and target.PctHPs() < 50 and target.Fleeing() and not mq.TLO.Target.Snared() then
                    mq.cmd("/cast 2")
                elseif mq.TLO.Me.SpellReady(3) and charLevel >= 33 and mq.TLO.Me.PctAggro() < 100 then
                    mq.cmd("/cast 3")
                end
            end
            
            mq.delay(50) -- Yield time for the loop
        end
    end
end

return tank