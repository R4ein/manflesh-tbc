-- Shows the encounter window based on the zone the player is in. Initial scope:
-- entering a supported raid zone pops the TRASH PACKS assignments.

local _, ns = ...

-- in-game zone name (GetRealZoneText) -> our raid name in Data.lua
local ZONE_TO_RAID = {
    ["Serpentshrine Cavern"] = "Serpentshrine Cavern",
    ["The Eye"] = "Tempest Keep",
}

local TRASH_BOSS = "Trash packs"

local function update()
    local zone = GetRealZoneText()
    if not zone or zone == "" then return end
    local raid = ZONE_TO_RAID[zone]
    if raid then
        if ns.UI and ns.UI.ShowEncounter then ns.UI.ShowEncounter(raid, TRASH_BOSS) end
    else
        if ns.UI and ns.UI.HideEncounter then ns.UI.HideEncounter() end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", function()
    -- the zone string can lag by a frame on load-in, so re-check shortly after
    update()
    C_Timer.After(1, update)
end)
