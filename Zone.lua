-- Zone-triggered encounter window.
-- Zone data (zoneName field) lives in each Raids\*.lua. This file reads
-- ns.RAIDS at load time to build the zone lookup — no separate registry needed.
--
-- Flow:
--   enter tracked zone  -> show Trash packs assignments
--   ENCOUNTER_START     -> show boss assignments (or "No Tasks Assigned")
--   ENCOUNTER_END       -> fall back to Trash packs
--   leave tracked zone  -> close the encounter window

local _, ns = ...

local TRASH_BOSS = "Trash packs"

-- Build zoneName -> raid def map from all registered raids.
-- Raids\*.lua loads before Zone.lua so ns.RAIDS is already populated.
local zoneMap = {}
for _, raid in ipairs(ns.RAIDS) do
    if raid.zoneName then
        zoneMap[raid.zoneName] = raid
    end
end

local currentRaid = nil  -- raid def we're currently inside
local currentBoss = nil  -- boss name while an encounter is active; nil = trash

local function showForCurrentState()
    if not currentRaid then
        if ns.UI and ns.UI.HideEncounter then ns.UI.HideEncounter() end
        return
    end
    local boss = currentBoss or TRASH_BOSS
    if ns.UI and ns.UI.ShowEncounter then
        ns.UI.ShowEncounter(currentRaid.name, boss)
    end
end

local function onZoneChanged()
    local zone = GetRealZoneText()
    local raid = zone and zoneMap[zone]
    if raid then
        if currentRaid ~= raid then
            currentRaid = raid
            currentBoss = nil
        end
        showForCurrentState()
    else
        currentRaid = nil
        currentBoss = nil
        if ns.UI and ns.UI.HideEncounter then ns.UI.HideEncounter() end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        onZoneChanged()
        -- zone text can lag by a frame on load-in
        C_Timer.After(1, onZoneChanged)

    elseif event == "ENCOUNTER_START" then
        if not currentRaid then return end
        local _, encounterName = ...
        -- optional encounters table in raid def lets you alias ENCOUNTER_START
        -- names if they ever diverge from the boss names used in assignments
        currentBoss = (currentRaid.encounters and currentRaid.encounters[encounterName])
                      or encounterName
        showForCurrentState()

    elseif event == "ENCOUNTER_END" then
        if not currentRaid then return end
        currentBoss = nil
        showForCurrentState()
    end
end)
