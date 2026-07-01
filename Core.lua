-- Saved variables, multi-roster model, import, permissions, and the low-level
-- mutators shared by the local UI and the sync layer.

local _, ns = ...
ns.Core = ns.Core or {}
local Core = ns.Core

local function msg(text)
    SendSystemMessage(ns.MSG_PREFIX .. ns.SanitizeString(text))
end
ns.Print = msg

-- Remove null terminators and control characters
function ns.SanitizeString(text)
    if type(text) ~= "string" then
        text = tostring(text)
    end
    -- %c matches all control characters (ASCII 0-31 and 127)
    text = text:gsub("%c", "")
    return text
end

function ns.MyName()
    local n = UnitName("player")
    return n or "Unknown"
end

-- key for matching names across clients: lowercase, realm stripped
function ns.NormName(name)
    if not name or name == "" then return "" end
    name = tostring(name):gsub("%-.*$", "")
    return name:lower()
end

local uidCounter = 0
function ns.NewUID()
    uidCounter = uidCounter + 1
    return ("%x%x%x"):format(math.floor(GetTime() * 1000) % 0xffffff, math.random(0, 0xffff), uidCounter % 0xffff)
end

local RAND_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"
function ns.RandomString(len)
    local out = {}
    for i = 1, len do
        local idx = math.random(1, #RAND_CHARS)
        out[i] = RAND_CHARS:sub(idx, idx)
    end
    return table.concat(out)
end

function ns.InitDB()
    ManfleshDB = ManfleshDB or {}
    ManfleshDB.rosters = ManfleshDB.rosters or {}
    if ManfleshDB.activeRosterID == nil then ManfleshDB.activeRosterID = false end
    ns.DB = ManfleshDB

    -- per-character UI state (window positions, etc.)
    ManfleshUIDB = ManfleshUIDB or {}
    ns.UIDB = ManfleshUIDB
end

function ns.GetAllRosters()
    return ns.DB.rosters
end

function ns.GetRosterByID(id)
    if not id then return nil end
    return ns.DB.rosters[id]
end

function ns.GetRosterList()
    local list = {}
    for _, r in pairs(ns.DB.rosters) do
        list[#list + 1] = r
    end
    table.sort(list, function(a, b)
        local ta = (a.event and a.event.title) or a.id or ""
        local tb = (b.event and b.event.title) or b.id or ""
        if ta == tb then return (a.id or "") < (b.id or "") end
        return ta < tb
    end)
    return list
end

function ns.GetActiveRoster()
    return ns.GetRosterByID(ns.DB.activeRosterID)
end

function ns.SetActiveRoster(id)
    ns.DB.activeRosterID = id or false
end

function ns.StoreRoster(roster)
    ns.DB.rosters[roster.id] = roster
    return roster
end

function ns.DeleteRoster(id)
    ns.DB.rosters[id] = nil
    if ns.DB.activeRosterID == id then
        ns.DB.activeRosterID = false
        local list = ns.GetRosterList()
        if list[1] then ns.DB.activeRosterID = list[1].id end
    end
end

function ns.IsCreatorName(roster, name)
    return roster and ns.NormName(roster.creator) == ns.NormName(name)
end

function ns.IsEditorName(roster, name)
    if not roster or not roster.editors then return false end
    return roster.editors[ns.NormName(name)] ~= nil
end

function ns.CanEditName(roster, name)
    return ns.IsCreatorName(roster, name) or ns.IsEditorName(roster, name)
end

function ns.IsLocked(roster) return roster and roster.locked == true end

function ns.IsCreator(roster) return ns.IsCreatorName(roster, ns.MyName()) end

-- owner/editor, ignoring lock state (used to decide who may toggle "complete")
function ns.CanManage(roster) return ns.CanEditName(roster, ns.MyName()) end

-- owner/editor AND the roster is not finalized: gates all content editing
function ns.CanEdit(roster) return ns.CanManage(roster) and not ns.IsLocked(roster) end

function ns.RosterHasPlayer(roster, name)
    if not roster or not roster.players then return false end
    local n = ns.NormName(name)
    for _, p in ipairs(roster.players) do
        if ns.NormName(p.name) == n then return true end
    end
    return false
end

function ns.FindPlayer(roster, name)
    if not roster then return nil end
    for i, p in ipairs(roster.players) do
        if p.name == name then return p, i end
    end
    return nil
end

function ns.GetOtherPlayerNames(roster, excludeName)
    local names = {}
    if not roster then return names end
    for _, p in ipairs(roster.players) do
        if p.name ~= excludeName then names[#names + 1] = p.name end
    end
    return names
end

function ns.PlayerBySlot(roster, slot)
    if not roster then return nil end
    for _, p in ipairs(roster.players) do
        if p.slot == slot then return p end
    end
    return nil
end

-- p.backup is the authoritative flag once a roster is created; position is only
-- consulted when a player has no placement yet (EnsureSlots).
function ns.IsBackupPlayer(p)
    return p ~= nil and p.backup == true
end

-- Fill in placement only for players that don't have one yet, so manual moves
-- (drag-and-drop) and synced layouts are preserved across refreshes.
function ns.EnsureSlots(roster)
    if not roster or not roster.players then return end
    local used = {}
    for _, p in ipairs(roster.players) do
        if p.backup == true then
            p.slot = nil
        elseif type(p.slot) == "number" and p.slot >= 1 and p.slot <= 25 then
            p.backup = false
            used[p.slot] = true
        end
    end
    for _, p in ipairs(roster.players) do
        local placed = (p.backup == true) or (type(p.slot) == "number" and p.slot >= 1 and p.slot <= 25)
        if not placed then
            local pos = p.position
            if type(pos) == "number" and pos >= 26 then
                p.backup, p.slot = true, nil
            elseif type(pos) == "number" and pos >= 1 and pos <= 25 and not used[pos] then
                p.backup, p.slot = false, pos
                used[pos] = true
            else
                local free
                for s = 1, 25 do if not used[s] then free = s break end end
                if free then
                    p.backup, p.slot = false, free
                    used[free] = true
                else
                    p.backup, p.slot = true, nil
                end
            end
        end
    end
end

function ns.MakeDuplicate(roster)
    local baseId = (roster.event and roster.event.eventId) or roster.id
    roster.id = baseId .. "-" .. ns.RandomString(6)
    roster.isDuplicate = true
    roster.creator = ns.MyName()
    roster.editors = {}
    roster.rev = 1
    return roster
end

-- Mutators have no sync side effects and are idempotent where possible, so the
-- sync layer can replay them safely.

function Core.AddAssignmentRecord(roster, playerName, record)
    if not roster or not record then return false end
    local list = roster.assignments[playerName]
    if not list then list = {}; roster.assignments[playerName] = list end
    for _, rec in ipairs(list) do
        if rec.uid and rec.uid == record.uid then return false end
    end
    list[#list + 1] = record
    return true
end

function Core.RemoveAssignmentByUID(roster, playerName, uid)
    local list = roster and roster.assignments[playerName]
    if not list then return false end
    for i, rec in ipairs(list) do
        if rec.uid == uid then
            table.remove(list, i)
            return true
        end
    end
    return false
end

function Core.SetClass(roster, playerName, class)
    local p = ns.FindPlayer(roster, playerName)
    if not p then return false end
    if p.class ~= class then p.spec = nil end -- old spec no longer applies
    p.class = class
    if ns.DPS_ONLY[class] then p.role = "DPS" end
    return true
end

function Core.SetRole(roster, playerName, role)
    local p = ns.FindPlayer(roster, playerName)
    if not p then return false end
    if ns.DPS_ONLY[p.class] then role = "DPS" end -- locked classes stay DPS
    p.role = role
    return true
end

function Core.SetSpec(roster, playerName, spec)
    local p = ns.FindPlayer(roster, playerName)
    if p then p.spec = spec return true end
    return false
end

function Core.SetSlots(roster, entries)
    if not roster or type(entries) ~= "table" then return false end
    for _, e in ipairs(entries) do
        local p = ns.FindPlayer(roster, e.name)
        if p then
            if e.backup == true then
                p.backup, p.slot = true, nil
            elseif e.backup == false then
                p.backup, p.slot = false, e.slot
            else
                p.slot = e.slot
            end
        end
    end
    return true
end

function Core.SetLock(roster, locked, by)
    if not roster then return false end
    roster.locked = locked and true or false
    roster.lockedBy = locked and (by or "?") or nil
    return true
end

function Core.RenamePlayer(roster, oldName, newName)
    if not roster or not newName or newName == "" then return false end
    local p = ns.FindPlayer(roster, oldName)
    if not p then return false end
    p.name = newName
    if roster.assignments[oldName] then
        roster.assignments[newName] = roster.assignments[oldName]
        roster.assignments[oldName] = nil
    end
    -- keep an editor grant attached to the renamed entry
    local oldKey, newKey = ns.NormName(oldName), ns.NormName(newName)
    if roster.editors[oldKey] and oldKey ~= newKey then
        roster.editors[newKey] = newName
        roster.editors[oldKey] = nil
    end
    return true
end

function Core.GrantEditor(roster, name, displayName)
    if not roster then return false end
    roster.editors[ns.NormName(name)] = displayName or name
    return true
end

function Core.RevokeEditor(roster, name)
    if not roster then return false end
    roster.editors[ns.NormName(name)] = nil
    return true
end

function ns.BuildAssignmentRecord(input)
    local def = ns.ASSIGN_DEFS[input.typeId]
    if not def then return nil, "Unknown assignment type" end
    if def.input == "mark" and not input.mark then
        return nil, "Pick a marker first."
    elseif def.input == "text" and (not input.text or input.text:match("^%s*$")) then
        return nil, "Enter the custom text first."
    elseif def.input == "target" and not input.target then
        return nil, "Pick a target player first."
    end

    local record = {
        uid = ns.NewUID(),
        raid = input.raid,
        boss = input.boss,
        typeId = input.typeId,
        mark = input.mark,
        text = input.text and input.text:sub(1, 255) or nil,
        target = input.target,
    }
    record.display = def.build(record)
    return record
end

function ns.GetAssignmentsSorted(roster, playerName)
    local list = roster and roster.assignments[playerName] or {}
    local copy = {}
    for i, rec in ipairs(list) do copy[i] = rec end
    table.sort(copy, function(a, b)
        if (a.raid or "") ~= (b.raid or "") then return (a.raid or "") < (b.raid or "") end
        return (a.boss or "") < (b.boss or "")
    end)
    return copy
end
