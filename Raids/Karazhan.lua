local _, ns = ...

ns.RegisterRaid({
    id = "kara",
    name = "Karazhan",
    zoneName = "Karazhan",
    bosses = {
        "Attumen the Huntsman",
        "Moroes",
        "Maiden of Virtue",
        "Opera Hall",        -- ENCOUNTER_START fires "Opera Hall" regardless of which
                             -- opera performance is active (Oz / Big Bad Wolf / R&J)
        "The Curator",
        "Terestian Illhoof",
        "Shade of Aran",
        "Netherspite",
        "Chess Event",
        "Prince Malchezaar",
        "Nightbane",
        "Trash packs",
    },
})
