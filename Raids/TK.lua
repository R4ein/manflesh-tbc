local _, ns = ...

ns.RegisterRaid({
    id = "tk",
    name = "Tempest Keep",
    zoneName = "The Eye",  -- GetRealZoneText() inside the instance (differs from raid name)
    bosses = {
        "Al'ar",
        "Void Reaver",
        "High Astromancer Solarian",
        "Kael'thas Sunstrider",
        "Trash packs",
    },
})
