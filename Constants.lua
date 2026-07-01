local _, ns = ...

ns.ADDON = "Manflesh"
ns.VERSION = "0.1.0"

-- addon-message channel prefix (also the SendAddonMessage / registered prefix)
ns.PREFIX = "Manflesh"
-- chat message prefix (for notifications)
ns.MSG_PREFIX = "|cff66ccffManflesh:|r|cFFFFFFFF "

-- shared textures
ns.TEX_ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

-- 25-man grid geometry (5 groups of 5 in a 2-column layout)
local HEADER_H, PLAYER_H, BOX_PAD, VGAP = 18, 18, 6, 8
local BOX_H = HEADER_H + 5 * PLAYER_H + BOX_PAD
ns.UI_SIZES = {
    ROW_HEIGHT = 20,
    BOX_W = 212,
    BOX_GAP = 14,
    PLAYER_H = PLAYER_H,
    HEADER_H = HEADER_H,
    BOX_PAD = BOX_PAD,
    VGAP = VGAP,
    BOX_H = BOX_H,
    GRID_H = 3 * BOX_H + 2 * VGAP,
}
