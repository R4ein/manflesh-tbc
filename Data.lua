local _, ns = ...

ns.CLASS_LIST = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

ns.CLASS_DISPLAY = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local FALLBACK_CLASS_COLOR = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 }, SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.41, 0.80, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 },
}

function ns.ClassDisplay(class)
    return ns.CLASS_DISPLAY[class] or class or "?"
end

function ns.ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then
        return c.r, c.g, c.b
    end
    local f = FALLBACK_CLASS_COLOR[class]
    if f then
        return f[1], f[2], f[3]
    end
    return 1, 1, 1
end

ns.ROLE_LIST = { "TANK", "HEALER", "DPS" }
ns.ROLE_DISPLAY = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }

function ns.RoleDisplay(role)
    return ns.ROLE_DISPLAY[role] or role or "?"
end

-- Classes that can only ever be DPS (no tank/heal trees worth raiding in TBC).
ns.DPS_ONLY = { HUNTER = true, ROGUE = true, MAGE = true, WARLOCK = true }

-- Talent specs per class (TBC).
ns.SPECS = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE   = { "Assassination", "Combat", "Subtlety" },
    PRIEST  = { "Discipline", "Holy", "Shadow" },
    SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
    MAGE    = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID   = { "Balance", "Feral", "Restoration" },
}

-- Spec name (normalized) -> a representative TBC ability/spell icon.
local SPEC_ICONS = {
    -- Warrior
    arms = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    fury = "Interface\\Icons\\Ability_Warrior_InnerRage",
    protection = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    -- Paladin
    holy = "Interface\\Icons\\Spell_Holy_HolyBolt",
    protectionpaladin = "Interface\\Icons\\Spell_Holy_DevotionAura",
    retribution = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    -- Hunter
    beastmastery = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    marksmanship = "Interface\\Icons\\Ability_Marksmanship",
    survival = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
    -- Rogue
    assassination = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    combat = "Interface\\Icons\\Ability_BackStab",
    subtlety = "Interface\\Icons\\Ability_Stealth",
    -- Priest
    discipline = "Interface\\Icons\\Spell_Holy_WordFortitude",
    holypriest = "Interface\\Icons\\Spell_Holy_HolyNova",
    shadow = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    -- Shaman
    elemental = "Interface\\Icons\\Spell_Nature_Lightning",
    enhancement = "Interface\\Icons\\Spell_Nature_LightningShield",
    restoration = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    -- Mage
    arcane = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    fire = "Interface\\Icons\\Spell_Fire_FireBolt02",
    frost = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    -- Warlock
    affliction = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    demonology = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    destruction = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    -- Druid
    balance = "Interface\\Icons\\Spell_Nature_StarFall",
    feral = "Interface\\Icons\\Ability_Druid_CatForm",
    restorationdruid = "Interface\\Icons\\Spell_Nature_HealingTouch",
}

-- Variants/aliases for spec names that Raid-Helper may use.
local SPEC_ICON_ALIASES = {
    feralcombat = "feral",
    feraltank = "feral",
    guardian = "feral",
    beast = "beastmastery",
    bm = "beastmastery",
    resto = "restoration",
    prot = "protection",
    ret = "retribution",
    disc = "discipline",
    destro = "destruction",
    affli = "affliction",
    demo = "demonology",
}

local function normSpec(spec)
    return (spec:lower():gsub("[^%a]", ""))
end

-- class lets us disambiguate shared spec names (Holy, Protection, Restoration).
function ns.SpecIcon(spec, class)
    if not spec or spec == "" then return nil end
    local key = normSpec(spec)
    key = SPEC_ICON_ALIASES[key] or key
    if class == "PALADIN" and key == "protection" then key = "protectionpaladin" end
    if class == "PRIEST" and key == "holy" then key = "holypriest" end
    if class == "DRUID" and key == "restoration" then key = "restorationdruid" end
    return SPEC_ICONS[key]
end

ns.MARK_LIST = { "skull", "cross", "diamond", "triangle", "moon", "star" }
ns.MARK_DISPLAY = {
    skull = "Skull", cross = "Cross", diamond = "Diamond",
    triangle = "Triangle", moon = "Moon", star = "Star",
}
-- maps to RaidTargetingIcon_<n> (1 star 2 circle 3 diamond 4 triangle 5 moon 6 square 7 cross 8 skull)
ns.MARK_ICON_INDEX = {
    star = 1, diamond = 3, triangle = 4, moon = 5, cross = 7, skull = 8,
}

function ns.MarkDisplay(mark)
    return ns.MARK_DISPLAY[mark] or mark or "?"
end

function ns.MarkIcon(mark, size)
    local idx = ns.MARK_ICON_INDEX[mark]
    if not idx then return "" end
    size = size or 14
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d:%d|t"):format(idx, size, size)
end

function ns.MarkMenuText(mark)
    return ns.MarkIcon(mark) .. " " .. ns.MarkDisplay(mark)
end

ns.RAIDS = {
    {
        id = "ssc",
        name = "Serpentshrine Cavern",
        bosses = {
            "Hydross", "Lurker", "Leotheras", "Morogrim",
            "Karathress", "Vashj", "Trash packs",
        },
    },
    {
        id = "tk",
        name = "Tempest Keep",
        bosses = {
            "A'lar", "Solarian", "Void Reaver", "Kael'Thas", "Trash packs",
        },
    },
}

function ns.GetRaidByName(name)
    for _, r in ipairs(ns.RAIDS) do
        if r.name == name then return r end
    end
    return nil
end

ns.RH_CLASS_MAP = {
    Warrior = "WARRIOR", Paladin = "PALADIN", Hunter = "HUNTER",
    Rogue = "ROGUE", Priest = "PRIEST", Shaman = "SHAMAN",
    Mage = "MAGE", Warlock = "WARLOCK", Druid = "DRUID",
}

-- generic role-only signups: class is a sensible default the user can override
ns.RH_GENERIC = {
    Tank = { class = "WARRIOR", role = "TANK" },
    Healer = { class = "PRIEST", role = "HEALER" },
    Melee = { class = "WARRIOR", role = "DPS" },
    Ranged = { class = "MAGE", role = "DPS" },
}

ns.RH_SKIP = {
    Absence = true, Bench = true, Late = true, Tentative = true,
}

ns.RH_ROLE_MAP = {
    Tanks = "TANK", Healers = "HEALER", Melee = "DPS", Ranged = "DPS",
}

-- Raid-Helper "wowtbc" comp-tool template: class/spec -> name + Discord emote id
-- + class color, used to build a comp ("raidplan") payload for the comp API.
ns.RH_CLASS_EXPORT = {
    WARRIOR = { name = "Warrior", emote = "579532030153588739", color = "#C69B6D" },
    PALADIN = { name = "Paladin", emote = "579532029906124840", color = "#F48CBA" },
    HUNTER  = { name = "Hunter",  emote = "579532029880827924", color = "#AAD372" },
    ROGUE   = { name = "Rogue",   emote = "579532030086217748", color = "#FFF468" },
    PRIEST  = { name = "Priest",  emote = "579532029901799437", color = "#FFFFFF" },
    SHAMAN  = { name = "Shaman",  emote = "579532030056857600", color = "#0070DD" },
    MAGE    = { name = "Mage",    emote = "579532030161977355", color = "#3FC7EB" },
    WARLOCK = { name = "Warlock", emote = "579532029851336716", color = "#8788EE" },
    DRUID   = { name = "Druid",   emote = "579532029675438081", color = "#FF7C0A" },
}

-- our spec display name -> Raid-Helper comp spec { name, emote }. Note the template
-- suffixes shared names (Holy1 = pala, Restoration1 = shaman, Beastmastery = no space).
ns.RH_SPEC_EXPORT = {
    WARRIOR = { ["Arms"] = { "Arms", "637564445031399474" }, ["Fury"] = { "Fury", "637564445215948810" }, ["Protection"] = { "Protection", "637564444834136065" } },
    PALADIN = { ["Holy"] = { "Holy1", "637564297622454272" }, ["Protection"] = { "Protection1", "637564297647489034" }, ["Retribution"] = { "Retribution", "637564297953673216" } },
    HUNTER  = { ["Beast Mastery"] = { "Beastmastery", "637564202021814277" }, ["Marksmanship"] = { "Marksmanship", "637564202084466708" }, ["Survival"] = { "Survival", "637564202130866186" } },
    ROGUE   = { ["Assassination"] = { "Assassination", "637564351707873324" }, ["Combat"] = { "Combat", "637564352333086720" }, ["Subtlety"] = { "Subtlety", "637564352169508892" } },
    PRIEST  = { ["Discipline"] = { "Discipline", "637564323442720768" }, ["Holy"] = { "Holy", "637564323530539019" }, ["Shadow"] = { "Shadow", "637564323291725825" } },
    SHAMAN  = { ["Elemental"] = { "Elemental", "637564379595931649" }, ["Enhancement"] = { "Enhancement", "637564379772223489" }, ["Restoration"] = { "Restoration1", "637564379847458846" } },
    MAGE    = { ["Arcane"] = { "Arcane", "637564231545389056" }, ["Fire"] = { "Fire", "637564231239073802" }, ["Frost"] = { "Frost", "637564231469891594" } },
    WARLOCK = { ["Affliction"] = { "Affliction", "637564406984867861" }, ["Demonology"] = { "Demonology", "637564407001513984" }, ["Destruction"] = { "Destruction", "637564406682877964" } },
    DRUID   = { ["Balance"] = { "Balance", "637564171994529798" }, ["Feral"] = { "Feral", "637564172061900820" }, ["Restoration"] = { "Restoration", "637564172007112723" } },
}

function ns.RHExportClass(class)
    return ns.RH_CLASS_EXPORT[class]
end

function ns.RHExportSpec(class, spec)
    local m = ns.RH_SPEC_EXPORT[class]
    if not m then return nil end
    if spec and m[spec] then return m[spec] end
    local first = ns.SPECS[class] and ns.SPECS[class][1]
    return first and m[first] or nil
end

-- each def: label, optional input ("mark" | "text" | "target"), and build(d)
ns.ASSIGN_DEFS = {
    dmg_mark        = { label = "Damage <mark>",          input = "mark", build = function(d) return "Damage {" .. ns.MarkDisplay(d.mark) .. "}" end },
    dmg_boss        = { label = "Damage BOSS",            build = function() return "Damage BOSS" end },
    interrupt_mark  = { label = "Interrupt <mark>",       input = "mark", build = function(d) return "Interrupt {" .. ns.MarkDisplay(d.mark) .. "}" end },
    interrupt_boss  = { label = "Interrupt BOSS",         build = function() return "Interrupt BOSS" end },
    aoe             = { label = "AOE",                    build = function() return "AOE" end },

    tank_mark       = { label = "Tank <mark>",            input = "mark", build = function(d) return "Tank {" .. ns.MarkDisplay(d.mark) .. "}" end },
    tank_boss       = { label = "Tank BOSS",              build = function() return "Tank BOSS" end },
    tank_adds       = { label = "Tank ADDS",              build = function() return "Tank ADDS" end },

    heal_mark       = { label = "Heal <mark>",            input = "mark", build = function(d) return "Heal {" .. ns.MarkDisplay(d.mark) .. "}" end },
    heal_main_tank  = { label = "Heal main tank",         build = function() return "Heal main tank" end },
    heal_off_tank   = { label = "Heal off tank",          build = function() return "Heal off tank" end },
    heal_raid       = { label = "Heal RAID",              build = function() return "Heal RAID" end },

    custom          = { label = "Custom text...",         input = "text", build = function(d) return d.text end },

    innervate       = { label = "Innervate <player>",     input = "target", build = function(d) return "Innervate " .. d.target end },
    bloodlust       = { label = "Bloodlust on encounter", build = function() return "Bloodlust on this encounter" end },
    misdirection    = { label = "Misdirection <player>",  input = "target", build = function(d) return "Misdirection " .. d.target end },
    imp_expose      = { label = "Improved Expose Armor",  build = function() return "Improved Expose Armor on target" end },
    sheep_mark      = { label = "Sheep <mark>",           input = "mark", build = function(d) return "Sheep {" .. ns.MarkDisplay(d.mark) .. "}" end },
    sheep_text      = { label = "Sheep <custom target>",  input = "text", build = function(d) return "Sheep " .. d.text end },
    banish_mark     = { label = "Banish <mark>",          input = "mark", build = function(d) return "Banish {" .. ns.MarkDisplay(d.mark) .. "}" end },
    banish_text     = { label = "Banish <custom target>", input = "text", build = function(d) return "Banish " .. d.text end },
}

ns.ROLE_ASSIGNS = {
    DPS    = { "dmg_mark", "dmg_boss", "interrupt_mark", "interrupt_boss", "aoe", "custom" },
    TANK   = { "tank_mark", "tank_boss", "tank_adds", "custom" },
    HEALER = { "heal_mark", "heal_main_tank", "heal_off_tank", "heal_raid", "custom" },
}

ns.CLASS_ASSIGNS = {
    DRUID   = { "innervate" },
    SHAMAN  = { "bloodlust" },
    HUNTER  = { "misdirection" },
    ROGUE   = { "imp_expose" },
    MAGE    = { "sheep_mark", "sheep_text" },
    WARLOCK = { "banish_mark", "banish_text" },
}

function ns.GetAssignmentTypes(role, class)
    local out = {}
    local roleList = ns.ROLE_ASSIGNS[role] or {}
    for _, id in ipairs(roleList) do
        out[#out + 1] = { id = id, label = ns.ASSIGN_DEFS[id].label, def = ns.ASSIGN_DEFS[id] }
    end
    local classList = ns.CLASS_ASSIGNS[class] or {}
    for _, id in ipairs(classList) do
        out[#out + 1] = { id = id, label = ns.ASSIGN_DEFS[id].label, def = ns.ASSIGN_DEFS[id] }
    end
    return out
end
