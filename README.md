# Convergence Shadow Knight Bot Command Guide

### Start Script
- Command: `/lua run ConvSHD`
- Description: Starts the Lua script Convergence Shadow Knight.

## General Bot Commands
These commands control general bot functionality, allowing you to start, stop, or save configurations.

### Toggle Bot On/Off
- Command: `/ConvSHD Bot on/off`
- Description: Enables or disables the bot for automated functions.

### Toggle Exit
- Command: `/ConvSHD Exit`
- Description: Closes the bot and script.

### Save Settings
- Command: `/ConvSHD Save`
- Description: Saves the current settings, preserving any configuration changes.

---

### Set Assist Parameters
- Command: `/ConvSHD Assist <name> <range> <percent>`
- Description: Sets the main assist name, assist range, and assist health percentage.

---

## Camp and Navigation
These commands control camping behavior and movement options.

### Set Camp Location
- Command: `/ConvSHD CampHere on/off/<distance>`
- Description: Sets the current location as the designated camp location, enables or disables return to camp, or sets a camp distance.
- Usage: `/ConvSHD CampHere 50` sets a 50-unit radius camp.

### Toggle Chase Mode
- Command: `/ConvSHD Chase <target> <distance>` or `/ConvSHD Chase on/off`
- Description: Sets a target and distance for the bot to chase, or toggles chase mode.
- Example: `/ConvSHD Chase John 30` will set the character John as the chase target at a distance of 30.
- Example: `/ConvSHD Chase off` will turn chasing off.

---

## Combat and Assist Commands
These commands control combat behaviors, including melee assistance and target positioning.

### Set Assist Melee
- Command: `/ConvSHD AssistMelee on/off`
- Description: Enables or disables melee assistance.

### Set Tank Melee
- Command: `/ConvSHD TankMelee on/off`
- Description: Enables or disables tank melee mode, which is incompatible with assist melee.

### Set Use Pet
- Command: `/ConvSHD Pet on/off`
- Description: Toggles pet usage.

### Set Buffs On
- Command: `/ConvSHD BuffsOn on/off`
- Description: Enables or disables buffs.

### Toggle Feign Death
- Command: `/ConvSHD FeignDeath on/off`
- Description: Enables or disables feign death functionality.

### Set Tank Range
- Command: `/ConvSHD Tank <range>`
- Description: Defines the tank's engagement range.

### Toggle Sit to Meditate
- Command: `/ConvSHD SitMed on/off`
- Description: Enables or disables sitting to meditate.

### Set Stick Position (Front/Behind)
- Command: `/ConvSHD Melee front/behind <distance>`
- Description: Configures the bot to stick to the front or back of the target and specifies a stick distance.
- Example: `/ConvSHD Melee front 10`

### Set Switch With Main Assist
- Command: `/ConvSHD SwitchWithMA on/off`
- Description: Enables or disables switching targets with the main assist.

---

## Pulling and Mob Control
These commands manage mob pulling and control within the camp area.

### Tank Ignore List Control
- Command: `/ConvSHD TankIgnore zone/global add/remove`
- Description: Adds or removes the target to/from the tank ignore list, either zone-specific or global.
