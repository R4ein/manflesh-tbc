local _, ns = ...
ns.UI = ns.UI or {}
local UI = ns.UI
local Core = ns.Core

local ROW_HIGHLIGHT = ns.TEX_ROW_HIGHLIGHT

-- 25-man grid geometry (defined in Constants.lua)
local S = ns.UI_SIZES
local ROW_HEIGHT = S.ROW_HEIGHT
local BOX_W, BOX_GAP = S.BOX_W, S.BOX_GAP
local PLAYER_H = S.PLAYER_H
local HEADER_H = S.HEADER_H
local BOX_PAD = S.BOX_PAD
local BOX_H = S.BOX_H
local VGAP = S.VGAP
local GRID_H = S.GRID_H

local function SetRowHighlight(row, enabled)
    row:SetHighlightTexture(ROW_HIGHLIGHT, "ADD")
    local tex = row:GetHighlightTexture()
    if tex then tex:SetAlpha(enabled and 1 or 0) end
end

local CLASS_ICON_TEX = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROLE_ICON_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_TCOORDS = {
    TANK   = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DPS    = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local function SetClassIcon(tex, class)
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c then
        tex:SetTexture(CLASS_ICON_TEX)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        tex:Show()
    else
        tex:Hide()
    end
end

local function SetRoleIcon(tex, role)
    local c = ROLE_TCOORDS[role]
    if c then
        tex:SetTexture(ROLE_ICON_TEX)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        tex:Show()
    else
        tex:Hide()
    end
end

local function SetSpecIcon(tex, spec, class)
    local path = ns.SpecIcon(spec, class)
    if path then
        tex:SetTexture(path)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:Show()
    else
        tex:Hide()
    end
end

-- edit wrappers: mutate locally, then broadcast to the guild
local function editAddAssignment(roster, player, record)
    Core.AddAssignmentRecord(roster, player, record)
    ns.Comm.Broadcast(roster, "addAssign", { player = player, record = record })
end
local function editRemoveAssignment(roster, player, uid)
    Core.RemoveAssignmentByUID(roster, player, uid)
    ns.Comm.Broadcast(roster, "delAssign", { player = player, uid = uid })
end
local function editSetClass(roster, player, class)
    Core.SetClass(roster, player, class)
    ns.Comm.Broadcast(roster, "setClass", { player = player, class = class })
end
local function editSetRole(roster, player, role)
    Core.SetRole(roster, player, role)
    ns.Comm.Broadcast(roster, "setRole", { player = player, role = role })
end
local function editSetSpec(roster, player, spec)
    Core.SetSpec(roster, player, spec)
    ns.Comm.Broadcast(roster, "setSpec", { player = player, spec = spec })
end
local function editSetSlots(roster, entries)
    Core.SetSlots(roster, entries)
    ns.Comm.Broadcast(roster, "setSlots", { entries = entries })
end
local function editRename(roster, oldName, newName)
    Core.RenamePlayer(roster, oldName, newName)
    ns.Comm.Broadcast(roster, "rename", { old = oldName, new = newName })
end
local function editSetLock(roster, locked)
    Core.SetLock(roster, locked, ns.MyName())
    ns.Comm.Broadcast(roster, "setLock", { locked = locked, by = ns.MyName() })
end
local function editGrant(roster, name)
    Core.GrantEditor(roster, name, name)
    ns.Comm.Broadcast(roster, "grantEditor", { name = ns.NormName(name), display = name })
end
local function editRevoke(roster, name)
    Core.RevokeEditor(roster, name)
    ns.Comm.Broadcast(roster, "revokeEditor", { name = ns.NormName(name) })
end

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function CreatePanel(name, w, h, parent)
    local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetBackdrop(BACKDROP)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    return f
end

local function AddTitle(frame, text)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", 0, -16)
    fs:SetText(text)
    return fs
end

local function AddCloseButton(frame)
    local b = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    b:SetPoint("TOPRIGHT", -4, -4)
    return b
end

local function AddButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function AddLabel(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function AddDivider(parent, width, x, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.18)
    t:SetSize(width, 1)
    t:SetPoint("TOPLEFT", x, y)
    return t
end

local function MakeDropdown(name, parent, width)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    if UIDropDownMenu_JustifyText then UIDropDownMenu_JustifyText(dd, "LEFT") end
    return dd
end

local function SetDropdownItems(dd, items, current, placeholder, onSelect)
    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, it in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = it.text
            info.value = it.value
            info.checked = (not it.disabled and current ~= nil and it.value == current)
            info.disabled = it.disabled or false
            info.notCheckable = it.disabled or false
            info.func = function()
                if it.disabled then return end
                UIDropDownMenu_SetSelectedValue(dd, it.value)
                UIDropDownMenu_SetText(dd, it.text)
                if onSelect then onSelect(it.value, it.text) end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local shownText
    for _, it in ipairs(items) do
        if it.value == current then shownText = it.text break end
    end
    if current ~= nil then UIDropDownMenu_SetSelectedValue(dd, current) end
    UIDropDownMenu_SetText(dd, shownText or placeholder or "")
end

local function CreateScrollList(name, parent, width, height)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scroll:SetSize(width, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll.rows = {}
    return scroll
end

local function ColorName(name, class)
    local r, g, b = ns.ClassColor(class)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, name)
end

-- Main window

local mainFrame, rosterDD, infoText, statusText, exportBtn, rhExportBtn, lockBtn
local rosterScroll, groupBoxes, slotRows, backupHeader, backupRows, backupZone
local dragGhost, dragDriver, dragState

local function PermLabel(roster)
    if ns.IsCreator(roster) then
        return "|cff00ff00OWNER|r"
    elseif ns.CanEdit(roster) then
        return "|cff66ccffEDITOR|r"
    end
    return "|cffff8080READ-ONLY|r"
end

local function MakePlayerRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(PLAYER_H)
    row:EnableMouse(true)
    SetRowHighlight(row, true)
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(14, 14)
    row.classIcon:SetPoint("LEFT", 2, 0)
    row.specIcon = row:CreateTexture(nil, "ARTWORK")
    row.specIcon:SetSize(14, 14)
    row.specIcon:SetPoint("LEFT", 18, 0)
    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(14, 14)
    row.roleIcon:SetPoint("LEFT", 34, 0)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.right:SetPoint("RIGHT", -2, 0)
    row.right:SetJustifyH("RIGHT")
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.left:SetPoint("LEFT", 52, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    return row
end

local function SetRowIcons(row, p)
    if p then
        SetClassIcon(row.classIcon, p.class)
        SetSpecIcon(row.specIcon, p.spec, p.class)
        SetRoleIcon(row.roleIcon, p.role)
    else
        row.classIcon:Hide()
        row.specIcon:Hide()
        row.roleIcon:Hide()
    end
end

local function BuildGroupBox(parent, g)
    local col = (g - 1) % 2
    local gridRow = math.floor((g - 1) / 2)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("TOPLEFT", col * (BOX_W + BOX_GAP), -gridRow * (BOX_H + VGAP))
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.45)
    box:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
    box:EnableMouse(false)
    local hdr = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOP", 0, -4)
    hdr:SetText(("|cffffd100Group %d|r"):format(g))
    for k = 1, 5 do
        local slot = (g - 1) * 5 + k
        local row = MakePlayerRow(box)
        row:SetWidth(BOX_W - 10)
        row:SetPoint("TOPLEFT", 5, -(HEADER_H + (k - 1) * PLAYER_H))
        row.slot = slot
        slotRows[slot] = row
    end
    return box
end

-- Manual drag-and-drop. WoW's OnReceiveDrag is unreliable for custom frames, so we
-- track the cursor ourselves: press a player, a tag follows the cursor, and on release
-- we hit-test which cell / the backup area is under the pointer.

local function frameAtCursor(frames)
    local cx, cy = GetCursorPosition()
    for _, f in pairs(frames) do
        if f and f:IsVisible() then
            local scale = f:GetEffectiveScale()
            if scale and scale > 0 then
                local x, y = cx / scale, cy / scale
                local l, b, w, h = f:GetRect()
                if l and x >= l and x <= l + w and y >= b and y <= b + h then
                    return f
                end
            end
        end
    end
    return nil
end

local function dropTarget()
    local f = frameAtCursor(slotRows)
    if f and f.slot then return { kind = "slot", slot = f.slot } end
    if backupZone and frameAtCursor({ backupZone }) then return { kind = "backup" } end
    return nil
end

local function applyDrop(roster, sp, target)
    if not target then return end
    if target.kind == "backup" then
        if sp.backup then return end
        editSetSlots(roster, { { name = sp.name, backup = true } })
    else
        local S = target.slot
        local occ = ns.PlayerBySlot(roster, S)
        if occ and occ.name == sp.name then return end
        local entries = {}
        if sp.backup then
            entries[#entries + 1] = { name = sp.name, slot = S, backup = false }
            if occ then entries[#entries + 1] = { name = occ.name, backup = true } end
        else
            local from = sp.slot
            entries[#entries + 1] = { name = sp.name, slot = S, backup = false }
            if occ then entries[#entries + 1] = { name = occ.name, slot = from, backup = false } end
        end
        editSetSlots(roster, entries)
    end
end

local function finishDrag()
    local st = dragState
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    if dragGhost then dragGhost:Hide() end
    if not st then return end
    local roster = ns.GetRosterByID(st.rid) or ns.GetActiveRoster()
    if not roster then return end
    if not st.moved then
        UI.ShowPlayer(roster.id, st.name) -- a click, not a drag
        return
    end
    if not st.canEdit then return end
    local sp = ns.FindPlayer(roster, st.name)
    if not sp then return end
    applyDrop(roster, sp, dropTarget())
    if UI.RefreshMain then UI.RefreshMain() end
end

local function ensureDragWidgets()
    if dragGhost then return end
    dragGhost = CreateFrame("Frame", nil, UIParent)
    dragGhost:SetFrameStrata("TOOLTIP")
    dragGhost:SetSize(170, 20)
    dragGhost:EnableMouse(false)
    local bg = dragGhost:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)
    dragGhost.text = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragGhost.text:SetPoint("LEFT", 5, 0)
    dragGhost:Hide()

    dragDriver = CreateFrame("Frame")
    dragDriver:Hide()
    dragDriver:SetScript("OnUpdate", function()
        if not dragState then dragDriver:Hide() return end
        if not IsMouseButtonDown("LeftButton") then
            finishDrag()
            return
        end
        local cx, cy = GetCursorPosition()
        if not dragState.moved then
            local dx, dy = cx - dragState.startX, cy - dragState.startY
            if (dx * dx + dy * dy) > 36 then
                dragState.moved = true
                if dragState.canEdit then
                    dragGhost.text:SetText(ColorName(dragState.name, dragState.class))
                    dragGhost:Show()
                end
            end
        end
        if dragState.moved and dragState.canEdit then
            local s = UIParent:GetEffectiveScale()
            dragGhost:ClearAllPoints()
            dragGhost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx / s + 14, cy / s)
        end
    end)
end

local function beginDrag(row)
    if not row.player then return end
    local roster = ns.GetActiveRoster()
    if not roster then return end
    ensureDragWidgets()
    local cx, cy = GetCursorPosition()
    dragState = {
        rid = roster.id,
        name = row.player.name,
        class = row.player.class,
        startX = cx, startY = cy,
        moved = false,
        canEdit = ns.CanEdit(roster),
    }
    dragDriver:Show()
end

local function RefreshMain()
    if not mainFrame then return end
    local roster = ns.GetActiveRoster()

    local list = ns.GetRosterList()
    local items = {}
    for _, r in ipairs(list) do
        local title = (r.event and r.event.title) or r.id
        if r.isDuplicate then title = title .. " (dup)" end
        if r.removed then title = "|cffff6060[X]|r " .. title end
        if roster and r.id == roster.id then title = title .. "  |cff00ff00(active)|r" end
        items[#items + 1] = { value = r.id, text = title }
    end
    SetDropdownItems(rosterDD, items, roster and roster.id, "No roster", function(id)
        ns.SetActiveRoster(id)
        RefreshMain()
    end)

    if not roster then
        infoText:SetText("|cffaaaaaaNo roster. Import one from Raid-Helper JSON, or pull one from the guild by ID.|r")
        statusText:SetText("")
        exportBtn:Disable()
        rhExportBtn:Disable()
        lockBtn:Disable()
        lockBtn:SetText("Mark Complete")
        for _, box in ipairs(groupBoxes) do box:Hide() end
        if backupHeader then backupHeader:Hide() end
        if backupZone then backupZone:Hide() end
        for _, r in ipairs(backupRows) do r:Hide() end
        rosterScroll.child:SetHeight(1)
        return
    end

    local ev = roster.event or {}
    local when = ev.date or ""
    if ev.time and ev.time ~= "" then when = when .. " " .. ev.time end
    local lines = {
        ("|cff00ff00[ACTIVE]|r |cffffd100%s|r  |cffaaaaaa%s|r"):format(ev.title or roster.id, when),
        ("In-game creator: |cffffffff%s|r   Discord: |cffffffff%s|r"):format(roster.creator or "?", ev.creatorDiscord ~= "" and ev.creatorDiscord or "?"),
        ("Channel: |cffffffff%s|r"):format(ev.channelName ~= "" and ev.channelName or "?"),
        ("ID: |cffffffff%s|r   %s%s"):format(roster.id, roster.isDuplicate and "|cffff8080[DUPLICATE]|r " or "", PermLabel(roster)),
    }
    if ns.IsLocked(roster) then
        lines[#lines + 1] = ("|cffffd100[FINALIZED]|r |cffaaaaaaread-only%s|r"):format(roster.lockedBy and (" \194\183 marked by " .. roster.lockedBy) or "")
    end
    if roster.removed then
        lines[#lines + 1] = ("|cffff6060[REMOVED BY CREATOR %s] Use Remove to delete this copy.|r"):format(roster.removedBy or "?")
    end
    infoText:SetText(table.concat(lines, "\n"))

    local backupCount = 0
    for _, p in ipairs(roster.players) do
        if ns.IsBackupPlayer(p) then backupCount = backupCount + 1 end
    end
    statusText:SetText(("%d raid + %d backup"):format(#roster.players - backupCount, backupCount))

    if ns.IsCreator(roster) then exportBtn:Enable() else exportBtn:Disable() end
    if ns.IsCreator(roster) then rhExportBtn:Enable() else rhExportBtn:Disable() end

    if ns.IsLocked(roster) then
        lockBtn:SetText("Reopen")
        if ns.IsCreator(roster) then lockBtn:Enable() else lockBtn:Disable() end
    else
        lockBtn:SetText("Mark Complete")
        if ns.CanManage(roster) then lockBtn:Enable() else lockBtn:Disable() end
    end

    ns.EnsureSlots(roster)
    local canEdit = ns.CanEdit(roster)

    local bySlot = {}
    local backups = {}
    for _, p in ipairs(roster.players) do
        if ns.IsBackupPlayer(p) then
            backups[#backups + 1] = p
        elseif p.slot then
            bySlot[p.slot] = p
        end
    end
    table.sort(backups, function(a, b)
        local pa, pb = a.position or 9999, b.position or 9999
        if pa == pb then return (a.name or "") < (b.name or "") end
        return pa < pb
    end)

    local function showTip(self, p)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ColorName(p.name, p.class))
        local specPart = (p.spec and p.spec ~= "") and (p.spec .. " ") or ""
        GameTooltip:AddLine(("%s%s / %s"):format(specPart, ns.ClassDisplay(p.class), ns.RoleDisplay(p.role)), .7, .7, .7)
        local al = ns.GetAssignmentsSorted(roster, p.name)
        if #al == 0 then
            GameTooltip:AddLine("No assignments", .6, .6, .6)
        else
            local lastWhere
            for _, a in ipairs(al) do
                local where = (a.raid or "") .. " / " .. (a.boss or "")
                if where ~= lastWhere then
                    GameTooltip:AddLine(where, 1, .82, 0)
                    lastWhere = where
                end
                GameTooltip:AddLine("    " .. (a.display or ""), 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end

    for _, box in ipairs(groupBoxes) do box:Show() end

    for slot = 1, 25 do
        local row = slotRows[slot]
        local p = bySlot[slot]
        row.player = p
        SetRowIcons(row, p)
        local tex = row:GetHighlightTexture()
        if p then
            local n = #ns.GetAssignmentsSorted(roster, p.name)
            row.left:SetText(ColorName(p.name, p.class))
            row.right:SetText(n > 0 and ("|cff66ccff[%d]|r"):format(n) or "")
            if tex then tex:SetAlpha(1) end
        else
            row.left:SetText("|cff555555\226\128\148|r")
            row.right:SetText("")
            if tex then tex:SetAlpha(0) end
        end

        row:SetScript("OnEnter", function(self)
            if self.player then showTip(self, self.player) end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", nil)
        row:SetScript("OnMouseDown", function(self) beginDrag(self) end)
    end

    local child = rosterScroll.child
    local areaTop = GRID_H + 10
    backupHeader:ClearAllPoints()
    backupHeader:SetPoint("TOPLEFT", 2, -areaTop)
    backupHeader:SetText(#backups > 0
        and "|cffff8080Backup (position 26+)|r"
        or "|cffff8080Backup|r  |cff888888(drag a player here to bench)|r")
    backupHeader:Show()

    local listH = math.max(#backups, 1) * PLAYER_H
    backupZone:ClearAllPoints()
    backupZone:SetPoint("TOPLEFT", 0, -(areaTop + HEADER_H))
    backupZone:SetSize(child:GetWidth(), listH + 6)
    backupZone:Show()

    local rowW = child:GetWidth() - 12
    for i, p in ipairs(backups) do
        local row = backupRows[i]
        if not row then
            row = MakePlayerRow(child)
            backupRows[i] = row
        end
        row:SetWidth(rowW)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -(areaTop + HEADER_H + (i - 1) * PLAYER_H))
        row.player = p
        row.slot = nil
        SetRowIcons(row, p)
        local n = #ns.GetAssignmentsSorted(roster, p.name)
        local specTxt = (p.spec and p.spec ~= "") and p.spec or ns.ClassDisplay(p.class)
        row.left:SetText(("%d. %s  |cffaaaaaa%s|r"):format(p.position or (25 + i), ColorName(p.name, p.class), specTxt))
        row.right:SetText(n > 0 and ("|cff66ccff[%d]|r"):format(n) or "")
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", function(self) showTip(self, self.player) end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseDown", function(self) beginDrag(self) end)
        row:Show()
    end
    for i = #backups + 1, #backupRows do backupRows[i]:Hide() end
    child:SetHeight(areaTop + HEADER_H + listH + 10)
end
UI.RefreshMain = RefreshMain

local function CreateMainFrame()
    if mainFrame then return end
    mainFrame = CreatePanel("ManfleshFrame", 492, 720)
    mainFrame:SetPoint("CENTER")
    AddTitle(mainFrame, "Manflesh")
    AddCloseButton(mainFrame)

    AddLabel(mainFrame, "Active roster (only this one is used)", 18, -40)
    rosterDD = MakeDropdown("ManfleshRosterDD", mainFrame, 250)
    rosterDD:SetPoint("TOPLEFT", 4, -52)

    local delBtn = AddButton(mainFrame, "Remove", 80, 20)
    delBtn:SetPoint("TOPRIGHT", -16, -52)
    delBtn:SetScript("OnClick", function()
        local r = ns.GetActiveRoster()
        if r then UI.RequestRemoveRoster(r.id) end
    end)

    infoText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 18, -82)
    infoText:SetWidth(456)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")

    local importBtn = AddButton(mainFrame, "Import JSON", 130)
    importBtn:SetPoint("TOPLEFT", 16, -150)
    importBtn:SetScript("OnClick", function() UI.ShowImport() end)

    local byIdBtn = AddButton(mainFrame, "Get by ID", 120)
    byIdBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    byIdBtn:SetScript("OnClick", function() UI.ShowManualImport() end)

    local syncBtn = AddButton(mainFrame, "Scan", 70)
    syncBtn:SetPoint("LEFT", byIdBtn, "RIGHT", 8, 0)
    syncBtn:SetScript("OnClick", function()
        ns.Comm.SendHello()
        ns.Comm.VerifyRosters()
        ns.Print("Scanning guild/group for shared rosters...")
    end)

    exportBtn = AddButton(mainFrame, "Export to Sheets", 150)
    exportBtn:SetPoint("TOPLEFT", 16, -178)
    exportBtn:SetScript("OnClick", function() UI.ShowExport() end)

    rhExportBtn = AddButton(mainFrame, "Export to Raid-Helper", 160)
    rhExportBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    rhExportBtn:SetScript("OnClick", function() UI.ShowRaidPlanExport() end)

    lockBtn = AddButton(mainFrame, "Mark Complete", 120)
    lockBtn:SetPoint("LEFT", rhExportBtn, "RIGHT", 8, 0)
    lockBtn:SetScript("OnClick", function() UI.ToggleLock() end)

    statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("TOPRIGHT", -20, -156)

    AddLabel(mainFrame, "Click to edit \194\183 drag to swap slots or bench \194\183 hover to preview:", 18, -208)
    rosterScroll = CreateScrollList("ManfleshRosterScroll", mainFrame, 440, 474)
    rosterScroll:SetPoint("TOPLEFT", 18, -226)

    local child = rosterScroll.child
    child:SetWidth(440)
    groupBoxes = {}
    slotRows = {}
    backupRows = {}
    for g = 1, 5 do
        groupBoxes[g] = BuildGroupBox(child, g)
    end
    backupHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backupHeader:SetText("|cffff8080Backup (position 26+)|r")
    backupHeader:Hide()

    backupZone = CreateFrame("Frame", nil, child, "BackdropTemplate")
    backupZone:EnableMouse(false)
    backupZone:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    backupZone:SetBackdropColor(0.15, 0.05, 0.05, 0.4)
    backupZone:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.7)
    backupZone:Hide()
end

function UI.ToggleMain()
    CreateMainFrame()
    if mainFrame:IsShown() then mainFrame:Hide() else RefreshMain() mainFrame:Show() end
end

function UI.ShowMain()
    CreateMainFrame()
    RefreshMain()
    mainFrame:Show()
end

-- Import (JSON paste) popup

local importFrame, importEdit

local function HandleParsedRoster(roster)
    if ns.GetRosterByID(roster.id) then
        StaticPopup_Show("MANFLESH_DUPLICATE", roster.id, nil, roster)
    else
        ns.StoreRoster(roster)
        ns.SetActiveRoster(roster.id)
        ns.Print(("Imported |cff00ff00%d|r players for '%s'. You are the creator."):format(#roster.players, (roster.event and roster.event.title) or roster.id))
        UI.ShowMain()
    end
end

local function CreateImportFrame()
    if importFrame then return end
    importFrame = CreatePanel("ManfleshImportFrame", 460, 420)
    importFrame:SetPoint("CENTER")
    AddTitle(importFrame, "Import Raid-Helper JSON")
    AddCloseButton(importFrame)
    AddLabel(importFrame, "Open the event JSON on raid-helper.xyz, copy it, paste below, then Import.", 20, -42)

    local scroll = CreateFrame("ScrollFrame", "ManfleshImportScroll", importFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -62)
    scroll:SetSize(404, 300)

    local box = CreateFrame("Frame", nil, importFrame, "BackdropTemplate")
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
    box:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 24, -6)

    importEdit = CreateFrame("EditBox", nil, scroll)
    importEdit:SetMultiLine(true)
    importEdit:SetMaxLetters(0)
    importEdit:SetFontObject(ChatFontNormal)
    importEdit:SetWidth(390)
    importEdit:SetHeight(600)
    importEdit:SetAutoFocus(false)
    importEdit:EnableMouse(true)
    importEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(importEdit)

    local importBtn = AddButton(importFrame, "Import", 120)
    importBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    importBtn:SetScript("OnClick", function()
        local roster, err = ns.ParseRosterJSON(importEdit:GetText())
        if roster then
            importEdit:SetText("")
            importFrame:Hide()
            HandleParsedRoster(roster)
        else
            ns.Print("|cffff5555" .. tostring(err) .. "|r")
        end
    end)

    local clearBtn = AddButton(importFrame, "Clear", 100)
    clearBtn:SetPoint("BOTTOMLEFT", 20, 16)
    clearBtn:SetScript("OnClick", function() importEdit:SetText("") importEdit:SetFocus() end)
end

function UI.ShowImport()
    CreateImportFrame()
    importFrame:Show()
    importEdit:SetFocus()
end

-- Manual import by roster ID

local manualFrame, manualEdit

local function CreateManualFrame()
    if manualFrame then return end
    manualFrame = CreatePanel("ManfleshManualFrame", 420, 170)
    manualFrame:SetPoint("CENTER")
    AddTitle(manualFrame, "Get roster by ID")
    AddCloseButton(manualFrame)
    AddLabel(manualFrame, "Enter a roster ID. If someone in your guild, party, or raid is\nonline, has it, and your name is in it, it will be sent to you.", 22, -44)

    manualEdit = CreateFrame("EditBox", "ManfleshManualEdit", manualFrame, "InputBoxTemplate")
    manualEdit:SetSize(360, 24)
    manualEdit:SetPoint("TOPLEFT", 30, -88)
    manualEdit:SetAutoFocus(true)
    manualEdit:SetMaxLetters(64)
    manualEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local reqBtn = AddButton(manualFrame, "Request", 120)
    reqBtn:SetPoint("BOTTOM", 0, 18)
    reqBtn:SetScript("OnClick", function()
        local id = manualEdit:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        if id == "" then return end
        ns.Comm.RequestByID(id)
        ns.Print(("Requested roster |cffffd100%s|r from nearby holders..."):format(id))
        manualFrame:Hide()
    end)
end

function UI.ShowManualImport()
    CreateManualFrame()
    manualEdit:SetText("")
    manualFrame:Show()
    manualEdit:SetFocus()
end

-- Export popup

local exportFrame, exportEdit

local function CreateExportFrame()
    if exportFrame then return end
    exportFrame = CreatePanel("ManfleshExportFrame", 560, 440)
    exportFrame:SetPoint("CENTER")
    AddTitle(exportFrame, "Export to Google Sheets")
    AddCloseButton(exportFrame)
    AddLabel(exportFrame, "Press Ctrl+C to copy, then paste into Google Sheets (it splits into columns).", 20, -42)

    local scroll = CreateFrame("ScrollFrame", "ManfleshExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -62)
    scroll:SetSize(504, 320)

    local box = CreateFrame("Frame", nil, exportFrame, "BackdropTemplate")
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
    box:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 24, -6)

    exportEdit = CreateFrame("EditBox", nil, scroll)
    exportEdit:SetMultiLine(true)
    exportEdit:SetMaxLetters(0)
    exportEdit:SetFontObject(ChatFontNormal)
    exportEdit:SetWidth(490)
    exportEdit:SetHeight(640)
    exportEdit:SetAutoFocus(false)
    exportEdit:EnableMouse(true)
    exportEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- keep it effectively read-only: typing restores the generated text
    exportEdit:SetScript("OnChar", function(self) self:SetText(self.payload or "") self:HighlightText() end)
    scroll:SetScrollChild(exportEdit)

    local selectBtn = AddButton(exportFrame, "Select all", 120)
    selectBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    selectBtn:SetScript("OnClick", function() exportEdit:SetFocus() exportEdit:HighlightText() end)
end

function UI.ShowExport()
    local roster = ns.GetActiveRoster()
    if not roster then ns.Print("No roster selected.") return end
    if not ns.IsCreator(roster) then
        ns.Print("|cffff5555Only the roster creator can export.|r")
        return
    end
    CreateExportFrame()
    local tsv = ns.BuildExportTSV(roster)
    exportEdit.payload = tsv
    exportEdit:SetText(tsv)
    exportFrame:Show()
    exportEdit:SetFocus()
    exportEdit:HighlightText()
end

-- Raid-Helper comp ("raidplan") export: a curl PATCH (or raw JSON) for copy-paste.
local rhFrame, rhEdit, rhHint, rhCurl, rhRoster

local function RefreshRaidPlanText()
    if not rhFrame or not rhRoster then return end
    local txt = rhCurl and ns.BuildRaidPlanCurl(rhRoster) or ns.BuildRaidPlanJSON(rhRoster)
    rhEdit.payload = txt
    rhEdit:SetText(txt)
    rhEdit:SetFocus()
    rhEdit:HighlightText()
end

local function CreateRaidPlanFrame()
    if rhFrame then return end
    rhFrame = CreatePanel("ManfleshRaidPlanFrame", 640, 470)
    rhFrame:SetPoint("CENTER")
    AddTitle(rhFrame, "Export to Raid-Helper (raidplan)")
    AddCloseButton(rhFrame)

    rhHint = rhFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rhHint:SetPoint("TOPLEFT", 20, -42)
    rhHint:SetWidth(600)
    rhHint:SetJustifyH("LEFT")
    rhHint:SetText("Replace |cffffd100<YOUR_RAIDHELPER_API_KEY>|r with your server's API key (Discord: /apikey), then run the command. It PATCHes the event's raidplan. Assignments are not included.")

    local scroll = CreateFrame("ScrollFrame", "ManfleshRaidPlanScroll", rhFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -78)
    scroll:SetSize(584, 320)

    local box = CreateFrame("Frame", nil, rhFrame, "BackdropTemplate")
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
    box:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 24, -6)

    rhEdit = CreateFrame("EditBox", nil, scroll)
    rhEdit:SetMultiLine(true)
    rhEdit:SetMaxLetters(0)
    rhEdit:SetFontObject(ChatFontNormal)
    rhEdit:SetWidth(570)
    rhEdit:SetHeight(640)
    rhEdit:SetAutoFocus(false)
    rhEdit:EnableMouse(true)
    rhEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    rhEdit:SetScript("OnChar", function(self) self:SetText(self.payload or "") self:HighlightText() end)
    scroll:SetScrollChild(rhEdit)

    local selectBtn = AddButton(rhFrame, "Select all", 110)
    selectBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    selectBtn:SetScript("OnClick", function() rhEdit:SetFocus() rhEdit:HighlightText() end)

    local toggleBtn = AddButton(rhFrame, "Show raw JSON", 150)
    toggleBtn:SetPoint("BOTTOMLEFT", 20, 16)
    toggleBtn:SetScript("OnClick", function()
        rhCurl = not rhCurl
        toggleBtn:SetText(rhCurl and "Show raw JSON" or "Show curl command")
        RefreshRaidPlanText()
    end)
end

function UI.ShowRaidPlanExport()
    local roster = ns.GetActiveRoster()
    if not roster then ns.Print("No roster selected.") return end
    if not ns.IsCreator(roster) then
        ns.Print("|cffff5555Only the roster creator can export.|r")
        return
    end
    CreateRaidPlanFrame()
    rhRoster = roster
    rhCurl = true
    RefreshRaidPlanText()
    rhFrame:Show()
end

-- Player editor + assignment builder

local playerFrame, pNameText, pPermText
local pClassDD, pSpecDD, pRoleDD, pRenameEdit, pRenameBtn, pEditorBtn
local pAssignScroll
local pRaidDD, pBossDD, pTypeDD, pMarkDD, pTargetDD, pTextEdit, pAddBtn
local addLabel, raidLabel, bossLabel, typeLabel, detailsLabel, renameLabel, specLabel
local builderState = {}
local editWidgets = {} -- shown only when the user can edit

local function ctxRoster() return ns.GetRosterByID(builderState.rid) end
local function ctxPlayer() return ns.FindPlayer(ctxRoster(), builderState.name) end

local function RefreshAssignmentList()
    local roster = ctxRoster()
    local canEdit = ns.CanEdit(roster)
    local list = ns.GetAssignmentsSorted(roster, builderState.name)
    local child = pAssignScroll.child
    local rows = pAssignScroll.rows
    local width = pAssignScroll:GetWidth()

    for i, a in ipairs(list) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, child)
            row:SetSize(width, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 2, 0)
            row.text:SetPoint("RIGHT", -24, 0)
            row.text:SetJustifyH("LEFT")
            row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.del:SetSize(20, 20)
            row.del:SetPoint("RIGHT", 0, 0)
            rows[i] = row
        end
        local uid = a.uid
        row.del:SetScript("OnClick", function()
            local r = ctxRoster()
            editRemoveAssignment(r, builderState.name, uid)
            RefreshAssignmentList()
            RefreshMain()
        end)
        if canEdit then row.del:Show() else row.del:Hide() end

        local where = (a.raid or "")
        if a.boss and a.boss ~= "" then where = where .. " / " .. a.boss end
        row.text:SetText(("|cffffd100%s|r  %s"):format(where, a.display or ""))
        row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(#list * ROW_HEIGHT, 1))
end

local function UpdateDetailWidgets()
    pMarkDD:Hide() pTargetDD:Hide() pTextEdit:Hide() detailsLabel:Hide()
    local def = builderState.typeId and ns.ASSIGN_DEFS[builderState.typeId]
    if not def or not def.input then return end
    detailsLabel:Show()
    if def.input == "mark" then
        local items = {}
        for _, m in ipairs(ns.MARK_LIST) do items[#items + 1] = { value = m, text = ns.MarkMenuText(m) } end
        SetDropdownItems(pMarkDD, items, builderState.mark, "Pick marker", function(v) builderState.mark = v end)
        pMarkDD:Show()
    elseif def.input == "target" then
        local items = {}
        for _, nm in ipairs(ns.GetOtherPlayerNames(ctxRoster(), builderState.name)) do items[#items + 1] = { value = nm, text = nm } end
        SetDropdownItems(pTargetDD, items, builderState.target, "Pick player", function(v) builderState.target = v end)
        pTargetDD:Show()
    elseif def.input == "text" then
        pTextEdit:SetText(builderState.text or "")
        pTextEdit:Show()
    end
end

local function RefreshTypeDropdown()
    local p = ctxPlayer()
    if not p then return end
    local items = { { value = "", text = "Pick an assignment", disabled = true } }
    for _, t in ipairs(ns.GetAssignmentTypes(p.role, p.class)) do
        items[#items + 1] = { value = t.id, text = t.label }
    end
    local valid = builderState.typeId and ns.ASSIGN_DEFS[builderState.typeId]
    if not valid then
        builderState.typeId = nil
        builderState.mark, builderState.text, builderState.target = nil, nil, nil
    end
    SetDropdownItems(pTypeDD, items, builderState.typeId, "Pick an assignment", function(v)
        if not v or v == "" or not ns.ASSIGN_DEFS[v] then
            builderState.typeId = nil
            builderState.mark, builderState.text, builderState.target = nil, nil, nil
            UIDropDownMenu_SetSelectedValue(pTypeDD, nil)
            UIDropDownMenu_SetText(pTypeDD, "Pick an assignment")
            UpdateDetailWidgets()
            return
        end
        builderState.typeId = v
        builderState.mark, builderState.text, builderState.target = nil, nil, nil
        UpdateDetailWidgets()
    end)
    UpdateDetailWidgets()
end

local function RefreshRoleDropdown()
    local p = ctxPlayer()
    if not p then return end
    local items = {}
    if ns.DPS_ONLY[p.class] then
        items[#items + 1] = { value = "DPS", text = ns.RoleDisplay("DPS") }
    else
        for _, ro in ipairs(ns.ROLE_LIST) do items[#items + 1] = { value = ro, text = ns.RoleDisplay(ro) } end
    end
    SetDropdownItems(pRoleDD, items, p.role, nil, function(v)
        editSetRole(ctxRoster(), builderState.name, v)
        RefreshMain()
        RefreshTypeDropdown()
    end)
end

local function RefreshSpecDropdown()
    local p = ctxPlayer()
    if not p then return end
    local items = {}
    for _, s in ipairs(ns.SPECS[p.class] or {}) do items[#items + 1] = { value = s, text = s } end
    SetDropdownItems(pSpecDD, items, p.spec, "Pick spec", function(v)
        editSetSpec(ctxRoster(), builderState.name, v)
        RefreshMain()
    end)
end

local function PopulateBossDropdown()
    local raid = builderState.raid and ns.GetRaidByName(builderState.raid)
    local items = {}
    if raid then for _, boss in ipairs(raid.bosses) do items[#items + 1] = { value = boss, text = boss } end end
    SetDropdownItems(pBossDD, items, builderState.boss, "Pick boss", function(v) builderState.boss = v end)
end

local function RefreshEditorButton()
    local roster = ctxRoster()
    local p = ctxPlayer()
    if not p then pEditorBtn:Hide() return end
    if ns.IsCreator(roster) and not ns.IsCreatorName(roster, p.name) then
        pEditorBtn:Show()
        if ns.IsEditorName(roster, p.name) then
            pEditorBtn:SetText("Revoke Editor")
        else
            pEditorBtn:SetText("Grant Editor")
        end
    else
        pEditorBtn:Hide()
    end
end

local function SetEditMode(canEdit)
    for _, w in ipairs(editWidgets) do
        if canEdit then w:Show() else w:Hide() end
    end
    if canEdit then
        UIDropDownMenu_EnableDropDown(pClassDD)
        UIDropDownMenu_EnableDropDown(pSpecDD)
        UIDropDownMenu_EnableDropDown(pRoleDD)
    else
        UIDropDownMenu_DisableDropDown(pClassDD)
        UIDropDownMenu_DisableDropDown(pSpecDD)
        UIDropDownMenu_DisableDropDown(pRoleDD)
    end
end

local function CreatePlayerFrame()
    if playerFrame then return end
    playerFrame = CreatePanel("ManfleshPlayerFrame", 440, 610)
    playerFrame:SetPoint("CENTER", 230, 0)
    AddCloseButton(playerFrame)

    pNameText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pNameText:SetPoint("TOP", 0, -16)
    pPermText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pPermText:SetPoint("TOP", 0, -38)

    AddLabel(playerFrame, "Class", 24, -58)
    pClassDD = MakeDropdown("ManfleshClassDD", playerFrame, 130)
    pClassDD:SetPoint("TOPLEFT", 8, -70)
    AddLabel(playerFrame, "Role", 244, -58)
    pRoleDD = MakeDropdown("ManfleshRoleDD", playerFrame, 110)
    pRoleDD:SetPoint("TOPLEFT", 228, -70)

    specLabel = AddLabel(playerFrame, "Spec", 24, -104)
    pSpecDD = MakeDropdown("ManfleshSpecDD", playerFrame, 200)
    pSpecDD:SetPoint("TOPLEFT", 8, -116)

    renameLabel = AddLabel(playerFrame, "Rename player", 24, -150)
    pRenameEdit = CreateFrame("EditBox", "ManfleshRenameEdit", playerFrame, "InputBoxTemplate")
    pRenameEdit:SetSize(220, 22)
    pRenameEdit:SetPoint("TOPLEFT", 30, -164)
    pRenameEdit:SetAutoFocus(false)
    pRenameEdit:SetMaxLetters(48)
    pRenameEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pRenameBtn = AddButton(playerFrame, "Rename", 90)
    pRenameBtn:SetPoint("LEFT", pRenameEdit, "RIGHT", 8, 0)
    pRenameBtn:SetScript("OnClick", function()
        local roster = ctxRoster()
        local newName = pRenameEdit:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        if newName == "" or newName == builderState.name then return end
        editRename(roster, builderState.name, newName)
        builderState.name = newName
        UI.ShowPlayer(roster.id, newName)
        RefreshMain()
    end)

    AddDivider(playerFrame, 396, 22, -194)
    AddLabel(playerFrame, "Current assignments", 24, -202)
    pAssignScroll = CreateScrollList("ManfleshAssignScroll", playerFrame, 380, 90)
    pAssignScroll:SetPoint("TOPLEFT", 22, -218)
    AddDivider(playerFrame, 396, 22, -314)

    addLabel = AddLabel(playerFrame, "ADD ASSIGNMENT", 24, -324, "GameFontNormal")
    raidLabel = AddLabel(playerFrame, "Raid", 24, -346)
    pRaidDD = MakeDropdown("ManfleshRaidDD", playerFrame, 150)
    pRaidDD:SetPoint("TOPLEFT", 8, -358)
    bossLabel = AddLabel(playerFrame, "Boss", 244, -346)
    pBossDD = MakeDropdown("ManfleshBossDD", playerFrame, 150)
    pBossDD:SetPoint("TOPLEFT", 228, -358)
    typeLabel = AddLabel(playerFrame, "Assignment", 24, -394)
    pTypeDD = MakeDropdown("ManfleshTypeDD", playerFrame, 190)
    pTypeDD:SetPoint("TOPLEFT", 8, -406)
    detailsLabel = AddLabel(playerFrame, "Details", 244, -394)
    pMarkDD = MakeDropdown("ManfleshMarkDD", playerFrame, 150)
    pMarkDD:SetPoint("TOPLEFT", 228, -406)
    pTargetDD = MakeDropdown("ManfleshTargetDD", playerFrame, 150)
    pTargetDD:SetPoint("TOPLEFT", 228, -406)
    pTextEdit = CreateFrame("EditBox", "ManfleshTextEdit", playerFrame, "InputBoxTemplate")
    pTextEdit:SetSize(170, 20)
    pTextEdit:SetPoint("TOPLEFT", 250, -410)
    pTextEdit:SetAutoFocus(false)
    pTextEdit:SetMaxLetters(255)
    pTextEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pTextEdit:SetScript("OnTextChanged", function(self) builderState.text = self:GetText() end)

    pAddBtn = AddButton(playerFrame, "Add Assignment", 160)
    pAddBtn:SetPoint("TOPLEFT", 30, -448)
    pAddBtn:SetScript("OnClick", function()
        local roster = ctxRoster()
        if not builderState.raid then ns.Print("|cffff5555Pick a raid.|r") return end
        if not builderState.boss then ns.Print("|cffff5555Pick a boss.|r") return end
        if not builderState.typeId or not ns.ASSIGN_DEFS[builderState.typeId] then
            ns.Print("|cffff5555Pick an assignment.|r")
            return
        end
        local record, err = ns.BuildAssignmentRecord(builderState)
        if not record then ns.Print("|cffff5555" .. tostring(err) .. "|r") return end
        record.raid = builderState.raid
        record.boss = builderState.boss
        editAddAssignment(roster, builderState.name, record)
        ns.Print(("Added assignment for |cffffd100%s|r."):format(builderState.name))
        builderState.typeId = nil
        builderState.mark, builderState.text, builderState.target = nil, nil, nil
        RefreshTypeDropdown()
        RefreshAssignmentList()
        RefreshMain()
    end)

    pEditorBtn = AddButton(playerFrame, "Grant Editor", 160)
    pEditorBtn:SetPoint("BOTTOM", 0, 18)
    pEditorBtn:SetScript("OnClick", function()
        local roster = ctxRoster()
        local p = ctxPlayer()
        if not p then return end
        if ns.IsEditorName(roster, p.name) then editRevoke(roster, p.name) else editGrant(roster, p.name) end
        RefreshEditorButton()
    end)

    editWidgets = {
        renameLabel, pRenameEdit, pRenameBtn,
        addLabel, raidLabel, pRaidDD, bossLabel, pBossDD,
        typeLabel, pTypeDD, pAddBtn,
    }
end

function UI.ShowPlayer(rid, name)
    CreatePlayerFrame()
    local roster = ns.GetRosterByID(rid)
    if not roster then return end
    local p = ns.FindPlayer(roster, name)
    if not p then return end

    builderState = { rid = rid, name = name }
    local canEdit = ns.CanEdit(roster)

    pNameText:SetText(ColorName(name, p.class))
    pPermText:SetText(canEdit and "|cff00ff00You can edit this roster|r" or "|cffff8080Read-only|r")

    local classItems = {}
    for _, c in ipairs(ns.CLASS_LIST) do classItems[#classItems + 1] = { value = c, text = ns.ClassDisplay(c) } end
    SetDropdownItems(pClassDD, classItems, p.class, nil, function(v)
        editSetClass(ctxRoster(), name, v)
        pNameText:SetText(ColorName(name, v))
        RefreshMain()
        RefreshRoleDropdown()
        RefreshSpecDropdown()
        RefreshTypeDropdown()
    end)

    RefreshRoleDropdown()
    RefreshSpecDropdown()

    pRenameEdit:SetText(name)

    local raidItems = {}
    for _, raid in ipairs(ns.RAIDS) do raidItems[#raidItems + 1] = { value = raid.name, text = raid.name } end
    SetDropdownItems(pRaidDD, raidItems, builderState.raid, "Pick raid", function(v)
        builderState.raid = v
        builderState.boss = nil
        PopulateBossDropdown()
    end)
    PopulateBossDropdown()
    RefreshTypeDropdown()
    RefreshAssignmentList()
    RefreshEditorButton()
    SetEditMode(canEdit)

    playerFrame:Show()
end

function UI.OnDataChanged(rid)
    RefreshMain()
    if playerFrame and playerFrame:IsShown() and builderState.rid == rid then
        local roster = ns.GetRosterByID(rid)
        if roster and ns.FindPlayer(roster, builderState.name) then
            UI.ShowPlayer(rid, builderState.name)
        else
            playerFrame:Hide()
        end
    end
end

-- Encounter window (zone/boss-triggered assignment reminder)

local encFrame, encTitle, encScroll

-- The roster entry whose name matches my character, in the given roster.
local function MyEntryName(roster)
    if not roster then return nil end
    local me = ns.NormName(ns.MyName())
    for _, p in ipairs(roster.players) do
        if ns.NormName(p.name) == me then return p.name end
    end
    return nil
end

local function SaveEncPos()
    if not encFrame or not ns.UIDB then return end
    local point, _, relPoint, x, y = encFrame:GetPoint()
    ns.UIDB.encPos = { point = point, rel = relPoint, x = x, y = y }
end

local function RestoreEncPos()
    encFrame:ClearAllPoints()
    local p = ns.UIDB and ns.UIDB.encPos
    if p and p.point then
        encFrame:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
    else
        encFrame:SetPoint("CENTER", 360, 120)
    end
end

local function CreateEncounterFrame()
    if encFrame then return end
    encFrame = CreatePanel("ManfleshEncounterFrame", 300, 210)
    encFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveEncPos()
    end)
    RestoreEncPos()
    AddCloseButton(encFrame)
    encTitle = encFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    encTitle:SetPoint("TOP", 0, -14)
    encTitle:SetWidth(260)
    encTitle:SetJustifyH("CENTER")
    encScroll = CreateScrollList("ManfleshEncounterScroll", encFrame, 256, 150)
    encScroll:SetPoint("TOPLEFT", 16, -40)
end

local function EncounterRow(i, child, width)
    local row = encScroll.rows[i]
    if not row then
        row = CreateFrame("Frame", nil, child)
        row:SetSize(width, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 2, 0)
        row.text:SetPoint("RIGHT", -2, 0)
        row.text:SetJustifyH("LEFT")
        encScroll.rows[i] = row
    end
    return row
end

function UI.ShowEncounter(raidName, bossName)
    CreateEncounterFrame()
    encTitle:SetText(("|cffffd100%s|r\n%s"):format(raidName, bossName))

    local child, width = encScroll.child, encScroll:GetWidth()
    local roster = ns.GetActiveRoster()
    local mine = {}
    if roster then
        local pname = MyEntryName(roster)
        if pname then
            for _, a in ipairs(ns.GetAssignmentsSorted(roster, pname)) do
                if a.raid == raidName and a.boss == bossName then
                    mine[#mine + 1] = a
                end
            end
        end
    end

    local count
    if #mine == 0 then
        local row = EncounterRow(1, child, width)
        row.text:SetText("|cff888888No Tasks Assigned.|r")
        row:Show()
        count = 1
    else
        for i, a in ipairs(mine) do
            local row = EncounterRow(i, child, width)
            row.text:SetText("• " .. (a.display or ""))
            row:Show()
        end
        count = #mine
    end
    for i = count + 1, #encScroll.rows do encScroll.rows[i]:Hide() end
    child:SetHeight(math.max(count * ROW_HEIGHT, 1))

    encFrame:Show()
end

function UI.HideEncounter()
    if encFrame then encFrame:Hide() end
end

-- Static popups

StaticPopupDialogs["MANFLESH_DUPLICATE"] = {
    text = "A roster with ID %s already exists.\n\nGet the latest copy from its creator, or create an independent duplicate with a new ID?",
    button1 = "Get from creator",
    button2 = "Cancel",
    button3 = "Create duplicate",
    OnAccept = function(_, data)
        ns.Comm.RequestByID(data.id)
        ns.Print(("Requesting roster |cffffd100%s|r from its creator..."):format(data.id))
    end,
    OnAlt = function(_, data)
        ns.MakeDuplicate(data)
        ns.StoreRoster(data)
        ns.SetActiveRoster(data.id)
        ns.Print(("Created duplicate roster |cffffd100%s|r."):format(data.id))
        UI.ShowMain()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["MANFLESH_GETOFFER"] = {
    text = "%s shared the roster '%s' which includes you.\nImport it? (read-only unless you are an editor)",
    button1 = "Import",
    button2 = "No",
    OnAccept = function(self)
        local data = self.data
        if data then
            ns.Comm.Send("GET " .. data.id, "WHISPER", data.sender)
            ns.Print(("Fetching roster from |cff66ccff%s|r..."):format(data.sender))
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function UI.PromptGetRoster(info, sender)
    local dlg = StaticPopup_Show("MANFLESH_GETOFFER", sender, info.title or info.id)
    if dlg then dlg.data = { id = info.id, sender = sender } end
end

-- Remove a roster locally; if we created it, tell holders so they can remove theirs.
local function DoRemoveRoster(roster)
    if not roster then return end
    local title = (roster.event and roster.event.title) or roster.id
    if ns.IsCreator(roster) and not roster.removed then
        ns.Comm.BroadcastDeletion(roster)
    end
    ns.DeleteRoster(roster.id)
    ns.Print(("Removed roster |cffffd100%s|r."):format(title))
    RefreshMain()
end
UI.DoRemoveRoster = DoRemoveRoster

StaticPopupDialogs["MANFLESH_CONFIRM_REMOVE"] = {
    text = "Remove roster '%s' (ID %s) from your addon?\nThis cannot be undone. If you created it, holders in your guild/group will be asked to remove their copy too.",
    button1 = "Remove",
    button2 = "Cancel",
    OnAccept = function(self)
        local r = ns.GetRosterByID(self.data)
        if r then DoRemoveRoster(r) end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["MANFLESH_FINALIZE"] = {
    text = "Finalize this roster?\nIt becomes read-only for everyone (editors included). Only the owner can reopen it.",
    button1 = "Finalize",
    button2 = "Cancel",
    OnAccept = function()
        local r = ns.GetActiveRoster()
        if r and ns.CanManage(r) and not ns.IsLocked(r) then
            editSetLock(r, true)
            UI.RefreshMain()
            ns.Print("|cffffd100Roster finalized|r (read-only).")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["MANFLESH_REOPEN"] = {
    text = "Reopen this roster for editing?\nEditors will be able to make changes again.",
    button1 = "Reopen",
    button2 = "Cancel",
    OnAccept = function()
        local r = ns.GetActiveRoster()
        if r and ns.IsCreator(r) and ns.IsLocked(r) then
            editSetLock(r, false)
            UI.RefreshMain()
            ns.Print("|cff00ff00Roster reopened|r for editing.")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function UI.ToggleLock()
    local roster = ns.GetActiveRoster()
    if not roster then return end
    if ns.IsLocked(roster) then
        if not ns.IsCreator(roster) then
            ns.Print("|cffff5555Only the owner can reopen a finalized roster.|r")
            return
        end
        StaticPopup_Show("MANFLESH_REOPEN")
    else
        if not ns.CanManage(roster) then
            ns.Print("|cffff5555You can't finalize this roster.|r")
            return
        end
        StaticPopup_Show("MANFLESH_FINALIZE")
    end
end

function UI.RequestRemoveRoster(id)
    local roster = ns.GetRosterByID(id)
    if not roster then
        ns.Print(("No roster with ID |cffffd100%s|r."):format(tostring(id)))
        return
    end
    local title = (roster.event and roster.event.title) or roster.id
    local dlg = StaticPopup_Show("MANFLESH_CONFIRM_REMOVE", title, roster.id)
    if dlg then dlg.data = roster.id end
end

function UI.ListRostersToChat()
    local list = ns.GetRosterList()
    if #list == 0 then ns.Print("No rosters.") return end
    ns.Print("Rosters:")
    for _, r in ipairs(list) do
        local title = (r.event and r.event.title) or r.id
        ns.Print(("  |cffffd100%s|r  |cffaaaaaa%s|r%s%s"):format(
            title, r.id,
            r.isDuplicate and " (dup)" or "",
            r.removed and " |cffff6060(removed by creator)|r" or ""))
    end
end
