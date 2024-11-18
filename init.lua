local mq = require('mq')
local utils = require('utils')
local commands = require('commands')
local gui = require('gui')
local nav = require('nav')
local spells = require('spells')
local tank = require('tank')
local assist = require('assist')

local class = mq.TLO.Me.Class()
if class ~= "Shadow Knight" then
    print("This script is only for ShadowKnights.")
    mq.exit()
end

local currentLevel = mq.TLO.Me.Level()

utils.PluginCheck()

mq.cmd('/assist off')

if mq.TLO.Me.Pet() ~= "NO PET" then
    mq.cmd("/pet hold")
end

mq.imgui.init('controlGUI', gui.controlGUI)

commands.init()
commands.initALL()

spells.startup(currentLevel)

local startupRun = false

local function checkBotOn(currentLevel)
    if gui.botOn and not startupRun then
        spells.startup(currentLevel)
        startupRun = true
    elseif not gui.botOn and startupRun then
        startupRun = false
    end
end

local toggleboton = gui.botOn or false

local function returnChaseToggle()
    if gui.botOn and gui.returnToCamp and not toggleboton then
        if nav.campLocation == nil then
            nav.setCamp()
            toggleboton = true
        end
    elseif not gui.botOn and toggleboton then
        nav.clearCamp()
        toggleboton = false
    end
end

utils.loadTankConfig()

while gui.controlGUI do

    returnChaseToggle()

    if gui.botOn then

        utils.monitorNav()

        if gui.sitMed then
            utils.sitMed()
        end

        if gui.tankOn then
            tank.tankRoutine()
        elseif gui.assistOn then
            assist.assistRoutine()
        end

        if gui.buffsOn and mq.TLO.Me.CombatState ~= "COMBAT" then
            utils.monitorBuffs()
        end

        if gui.usePet and mq.TLO.Me.CombatState ~= "COMBAT" then
            utils.monitorPet()
        end

        local newLevel = mq.TLO.Me.Level()
        if newLevel ~= currentLevel then
            printf(string.format("Level has changed from %d to %d. Updating spells.", currentLevel, newLevel))
            spells.startup(newLevel)
            currentLevel = newLevel
        end
    end

    mq.doevents()
    mq.delay(100)
end