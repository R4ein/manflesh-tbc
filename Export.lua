local _, ns = ...

local HEADER = { "Player", "Class", "Spec", "Role", "Raid", "Boss", "Assignment" }

-- Tab/newline separated so it splits into columns/rows when pasted into Sheets.
function ns.BuildExportTSV(roster)
    roster = roster or ns.GetActiveRoster()
    if not roster then return "" end

    local lines = {}
    local ev = roster.event or {}
    lines[#lines + 1] = table.concat({ "Event", ev.title or "", ev.date or "", ev.time or "" }, "\t")
    lines[#lines + 1] = table.concat({ "Roster ID", roster.id or "", "Creator", roster.creator or "" }, "\t")
    lines[#lines + 1] = ""
    lines[#lines + 1] = table.concat(HEADER, "\t")

    for _, p in ipairs(roster.players or {}) do
        local class = ns.ClassDisplay(p.class)
        local spec = (p.spec and p.spec ~= "") and p.spec or ""
        local role = ns.RoleDisplay(p.role)
        local list = ns.GetAssignmentsSorted(roster, p.name)
        if #list > 0 then
            for _, a in ipairs(list) do
                lines[#lines + 1] = table.concat({
                    p.name, class, spec, role, a.raid or "", a.boss or "", a.display or "",
                }, "\t")
            end
        else
            lines[#lines + 1] = table.concat({ p.name, class, spec, role, "", "", "" }, "\t")
        end
    end

    return table.concat(lines, "\n")
end

-- The comp id is the original event id (duplicates keep the source event's id),
-- since that is the comp the raidplan API edits.
local function compId(roster)
    return (roster.event and roster.event.eventId) or roster.id
end

-- Builds a Raid-Helper comp ("raidplan") object matching the /api/v4/comps/ID
-- shape. Only placed raid members (slots 1-25) are exported; backups are skipped
-- and assignments are intentionally left out.
function ns.BuildRaidPlanComp(roster)
    roster = roster or ns.GetActiveRoster()
    if not roster then return nil end
    ns.EnsureSlots(roster)

    local slots = {}
    for slot = 1, 25 do
        local p = ns.PlayerBySlot(roster, slot)
        if p and not ns.IsBackupPlayer(p) then
            local cls = ns.RHExportClass(p.class)
            local spc = ns.RHExportSpec(p.class, p.spec)
            slots[#slots + 1] = {
                name = p.name,
                id = p.userId or "",
                className = cls and cls.name or ns.ClassDisplay(p.class),
                specName = spc and spc[1] or (p.spec or ""),
                classEmoteId = cls and cls.emote or "",
                specEmoteId = spc and spc[2] or "",
                color = cls and cls.color or "#FFFFFF",
                isConfirmed = "unconfirmed",
                groupNumber = math.floor((slot - 1) / 5) + 1,
                slotNumber = ((slot - 1) % 5) + 1,
            }
        end
    end

    local groups = {}
    for g = 1, 5 do groups[g] = { name = "Group " .. g, position = g } end

    return {
        id = compId(roster),
        title = "Composition Tool",
        groupCount = 5,
        slotCount = 5,
        showRoles = true,
        showClasses = false,
        dividers = {},
        groups = groups,
        slots = slots,
    }
end

function ns.BuildRaidPlanJSON(roster)
    local comp = ns.BuildRaidPlanComp(roster)
    if not comp then return "" end
    return ns.JSON.encode(comp)
end

-- A ready-to-run curl that PATCHes the comp. The API key value is left as a
-- placeholder so the sensitive token never lives in the addon/clipboard.
function ns.BuildRaidPlanCurl(roster)
    roster = roster or ns.GetActiveRoster()
    if not roster then return "" end
    local json = ns.BuildRaidPlanJSON(roster)
    local safe = json:gsub("'", "'\\''")
    return table.concat({
        ("curl -X PATCH \"https://raid-helper.xyz/api/v4/comps/%s\" \\"):format(compId(roster)),
        "  -H \"Authorization: <YOUR_RAIDHELPER_API_KEY>\" \\",
        "  -H \"Content-Type: application/json\" \\",
        "  --data-raw '" .. safe .. "'",
    }, "\n")
end
