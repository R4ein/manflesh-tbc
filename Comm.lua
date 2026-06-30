-- In-guild sync over addon messages. GUILD carries discovery + edit ops;
-- WHISPER carries bulk roster transfers. Anything bigger than one message is
-- JSON-encoded, chunked and reassembled.

local _, ns = ...
ns.Comm = ns.Comm or {}
local Comm = ns.Comm
local Core = ns.Core

ns.PREFIX = "Manflesh"

Comm.offers = {}
Comm.pendingManual = {}   -- ids we explicitly asked for (auto-accept the offer)
Comm.prompted = {}        -- ids already prompted about this session
Comm.fetching = {}        -- ids we've already sent a GET for
Comm.checking = {}        -- ids we've sent an existence check for
local transfers = {}

-- Broadcast channels available right now. GUILD covers guildmates; PARTY/RAID/
-- INSTANCE_CHAT let players who are grouped but NOT guilded (e.g. a cross-guild
-- raider listed in the roster) still discover and pull it.
local function availableChannels()
    local chans = {}
    if IsInGuild() then chans[#chans + 1] = "GUILD" end
    if IsInRaid() then
        chans[#chans + 1] = "RAID"
    elseif IsInGroup() then
        chans[#chans + 1] = "PARTY"
    end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        chans[#chans + 1] = "INSTANCE_CHAT"
    end
    return chans
end
ns.Comm.AvailableChannels = availableChannels

-- The server gives each prefix ~10 messages, regenerating ~1/sec, on
-- GUILD/PARTY/RAID (whispers are exempt); any message whose prefix+text exceeds
-- ~255 bytes disconnects the client. So we cap message size, pace sends, watch
-- the throttle return code (re-queue instead of dropping), and stay quiet right
-- after login.
local MAX_MSG = 240
local sendQueue = {}
local pump = CreateFrame("Frame")
local nextSendAt = 0

-- handles both old (boolean) and new (result-code, possibly as 2nd return) APIs
local function sendSucceeded(a, b)
    local E = Enum and Enum.SendAddonMessageResult
    if E then
        if a == E.Success or b == E.Success then return true end
        if a == E.AddonMessageThrottle or b == E.AddonMessageThrottle then return false end
    end
    if a == true or a == 0 then return true end
    if a == false or a == nil then return false end
    return true
end

pump:Hide()
pump:SetScript("OnUpdate", function()
    local now = GetTime()
    if now < nextSendAt then return end
    local item = sendQueue[1]
    if not item then pump:Hide() return end

    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        table.remove(sendQueue, 1)
        return
    end
    local a, b = C_ChatInfo.SendAddonMessage(ns.PREFIX, item.msg, item.channel, item.target)
    if sendSucceeded(a, b) then
        table.remove(sendQueue, 1)
        nextSendAt = now + 0.2
    else
        nextSendAt = now + 1.1
    end
    if #sendQueue == 0 then pump:Hide() end
end)

function Comm.QuietUntil(seconds)
    nextSendAt = math.max(nextSendAt, GetTime() + (seconds or 6))
end

function Comm.Send(msg, channel, target)
    if channel == "GUILD" and not IsInGuild() then return end
    if #msg > MAX_MSG then
        ns.Print("|cffff5555internal: dropped an oversized sync message.|r")
        return
    end
    sendQueue[#sendQueue + 1] = { msg = msg, channel = channel, target = target }
    pump:Show()
end

local CHUNK = 190

function Comm.SendBig(kind, tbl, channel, target)
    local data = ns.JSON.encode(tbl)
    local tid = ns.RandomString(6)
    local total = math.max(1, math.ceil(#data / CHUNK))
    Comm.Send("XHEAD " .. ns.JSON.encode({ tid = tid, total = total, kind = kind }), channel, target)
    for i = 1, total do
        local part = data:sub((i - 1) * CHUNK + 1, i * CHUNK)
        Comm.Send("XDATA " .. tid .. ":" .. i .. ":" .. part, channel, target)
    end
end

local function tryComplete(tid)
    local t = transfers[tid]
    if not t or not t.total or t.received < t.total then return end
    local ordered = {}
    for i = 1, t.total do
        if t.parts[i] == nil then return end
        ordered[i] = t.parts[i]
    end
    transfers[tid] = nil
    local obj = ns.JSON.decode(table.concat(ordered))
    if not obj then return end
    if t.kind == "roster" then
        Comm.OnRosterReceived(obj, t.sender)
    elseif t.kind == "op" then
        Comm.OnOpTable(obj, t.sender)
    end
end

-- pushes a permitted local mutation to everyone holding the roster
function Comm.Broadcast(roster, opType, fields)
    fields = fields or {}
    fields.type = opType
    fields.rid = roster.id
    roster.rev = (roster.rev or 0) + 1
    fields.rev = roster.rev
    for _, ch in ipairs(availableChannels()) do
        Comm.SendBig("op", fields, ch)
    end
end

-- creator-only announcement that a roster was removed
function Comm.BroadcastDeletion(roster)
    for _, ch in ipairs(availableChannels()) do
        Comm.Send("DEL " .. roster.id, ch)
    end
end

local function opAuthorized(roster, op, sender)
    if op.type == "setLock" then
        -- anyone with edit rights can finalize; only the creator can reopen
        if op.locked then return ns.CanEditName(roster, sender) end
        return ns.IsCreatorName(roster, sender)
    end
    if op.type == "grantEditor" or op.type == "revokeEditor" then
        return ns.IsCreatorName(roster, sender)
    end
    -- a finalized roster rejects all content edits regardless of sender
    if roster.locked then return false end
    return ns.CanEditName(roster, sender)
end

local function applyOp(roster, op)
    local t = op.type
    if t == "addAssign" then
        Core.AddAssignmentRecord(roster, op.player, op.record)
    elseif t == "delAssign" then
        Core.RemoveAssignmentByUID(roster, op.player, op.uid)
    elseif t == "setClass" then
        Core.SetClass(roster, op.player, op.class)
    elseif t == "setRole" then
        Core.SetRole(roster, op.player, op.role)
    elseif t == "setSpec" then
        Core.SetSpec(roster, op.player, op.spec)
    elseif t == "setSlots" then
        Core.SetSlots(roster, op.entries)
    elseif t == "setLock" then
        Core.SetLock(roster, op.locked, op.by)
    elseif t == "rename" then
        Core.RenamePlayer(roster, op.old, op.new)
    elseif t == "grantEditor" then
        Core.GrantEditor(roster, op.name, op.display)
    elseif t == "revokeEditor" then
        Core.RevokeEditor(roster, op.name)
    end
end

function Comm.OnOpTable(op, sender)
    if not op or not op.rid then return end
    local roster = ns.GetRosterByID(op.rid)
    if not roster then return end
    if not opAuthorized(roster, op, sender) then return end
    applyOp(roster, op)
    roster.rev = math.max(roster.rev or 0, op.rev or 0)
    if ns.UI and ns.UI.OnDataChanged then ns.UI.OnDataChanged(op.rid) end
end

function Comm.SendHello()
    for _, ch in ipairs(availableChannels()) do
        Comm.Send("HELLO", ch)
    end
end

function Comm.RequestByID(id)
    if not id or id == "" then return end
    local chans = availableChannels()
    if #chans == 0 then
        ns.Print("|cffff5555You must share a guild, party, or raid with a holder to fetch a roster.|r")
        return
    end
    Comm.pendingManual[id] = true
    for _, ch in ipairs(chans) do
        Comm.Send("FIND " .. id, ch)
    end
end

-- Ask each roster's creator (by whisper) whether it still exists. Catches a
-- deletion that was broadcast while we were offline. If the creator is offline
-- there is no reply, so nothing changes (the check just didn't complete).
function Comm.VerifyRosters()
    for _, r in pairs(ns.GetAllRosters()) do
        if not r.removed and not ns.IsCreator(r) and r.creator and r.creator ~= "" then
            Comm.checking[r.id] = true
            Comm.Send("EXISTS " .. r.id, "WHISPER", r.creator)
        end
    end
end

local function makeOffer(roster)
    local title = (roster.event and roster.event.title) or roster.id
    return ns.JSON.encode({
        id = roster.id,
        rev = roster.rev or 1,
        creator = roster.creator,
        title = title:sub(1, 90),
    })
end

local function onHello(sender)
    for _, r in pairs(ns.GetAllRosters()) do
        if not r.removed and ns.RosterHasPlayer(r, sender) then
            Comm.Send("OFFER " .. makeOffer(r), "WHISPER", sender)
        end
    end
end

local function onFind(id, sender)
    local r = ns.GetRosterByID(id)
    if r and not r.removed and ns.RosterHasPlayer(r, sender) then
        Comm.Send("OFFER " .. makeOffer(r), "WHISPER", sender)
    end
end

local function onGet(id, sender)
    local r = ns.GetRosterByID(id)
    if r and not r.removed and ns.RosterHasPlayer(r, sender) then
        Comm.SendBig("roster", r, "WHISPER", sender)
    end
end

-- Tombstone a held copy and tell the player via chat only (never a popup).
local function markRemoved(r, sender)
    if not r or r.removed then return end
    r.removed = true
    r.removedBy = sender
    Comm.checking[r.id] = nil
    local title = (r.event and r.event.title) or r.id
    ns.Print(("|cffff8080The creator (%s) removed roster '%s'.|r Delete your copy via the Manflesh window (Remove) or |cffffd100/mf roster remove %s|r."):format(
        sender or "?", title, r.id))
    if ns.UI and ns.UI.OnDataChanged then ns.UI.OnDataChanged(r.id) end
end

-- Live announcement from a creator who just removed the roster.
local function onDeleted(id, sender)
    if not id or id == "" then return end
    local r = ns.GetRosterByID(id)
    if not r then return end
    if not ns.IsCreatorName(r, sender) then return end
    if ns.IsCreator(r) then return end
    markRemoved(r, sender)
end

-- Someone (whispering the believed creator) asks if we still hold roster <id>.
local function onExists(id, sender)
    if not id or id == "" then return end
    local r = ns.GetRosterByID(id)
    if r and not r.removed and ns.IsCreator(r) then
        Comm.Send("HAVE " .. id, "WHISPER", sender)
    else
        Comm.Send("GONE " .. id, "WHISPER", sender)
    end
end

-- The believed creator confirmed they no longer hold it -> run the removal flow.
-- (If the creator is offline we simply get no reply and leave the roster as-is.)
local function onGone(id, sender)
    local r = ns.GetRosterByID(id)
    if not r or r.removed then return end
    if ns.IsCreator(r) then return end
    if not ns.IsCreatorName(r, sender) then return end -- only the creator's word counts
    markRemoved(r, sender)
end

local function onHave(id)
    Comm.checking[id] = nil -- still exists; nothing to do
end

local function onOffer(payload, sender)
    local info = ns.JSON.decode(payload)
    if not info or not info.id then return end
    Comm.offers[info.id] = { sender = sender, rev = info.rev, creator = info.creator, title = info.title }

    if Comm.pendingManual[info.id] then
        Comm.pendingManual[info.id] = nil
        Comm.fetching[info.id] = true
        Comm.Send("GET " .. info.id, "WHISPER", sender)
        return
    end

    local localRoster = ns.GetRosterByID(info.id)
    if localRoster and localRoster.removed then return end -- we tombstoned it; don't re-pull
    if not localRoster then
        if not Comm.prompted[info.id] then
            Comm.prompted[info.id] = true
            if ns.UI and ns.UI.PromptGetRoster then
                ns.UI.PromptGetRoster(info, sender)
            end
        end
    elseif (info.rev or 0) > (localRoster.rev or 0) and ns.CanEditName(localRoster, sender)
        and not Comm.fetching[info.id] then
        Comm.fetching[info.id] = true
        Comm.Send("GET " .. info.id, "WHISPER", sender)
    end
end

function Comm.OnRosterReceived(roster, sender)
    if type(roster) ~= "table" or not roster.id or type(roster.players) ~= "table" then return end
    -- accept only rosters that actually list us (matches the sharing rules)
    if not ns.RosterHasPlayer(roster, ns.MyName()) then return end

    local existing = ns.GetRosterByID(roster.id)
    if existing and (roster.rev or 0) < (existing.rev or 0) then
        return
    end
    local isNew = (existing == nil)

    roster.assignments = roster.assignments or {}
    roster.editors = roster.editors or {}
    ns.StoreRoster(roster)
    Comm.fetching[roster.id] = nil
    -- a freshly added roster becomes the active one (latest added is the default)
    if isNew or not ns.GetActiveRoster() then ns.SetActiveRoster(roster.id) end

    local title = (roster.event and roster.event.title) or roster.id
    ns.Print(("Received roster |cffffd100%s|r from |cff66ccff%s|r (read-only unless you're an editor)."):format(
        title, sender or "?"))
    if ns.UI and ns.UI.OnDataChanged then ns.UI.OnDataChanged(roster.id) end
end

function Comm.Init()
    if Comm.inited then return end
    Comm.inited = true
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
    end
    Comm.QuietUntil(6)
end

function Comm.OnAddonMessage(message, sender)
    if not message then return end
    if ns.NormName(sender) == ns.NormName(ns.MyName()) then return end

    local cmd, payload = message:match("^(%S+)%s?(.*)$")
    if not cmd then return end

    if cmd == "HELLO" then
        onHello(sender)
    elseif cmd == "FIND" then
        onFind(payload, sender)
    elseif cmd == "GET" then
        onGet(payload, sender)
    elseif cmd == "OFFER" then
        onOffer(payload, sender)
    elseif cmd == "DEL" then
        onDeleted(payload, sender)
    elseif cmd == "EXISTS" then
        onExists(payload, sender)
    elseif cmd == "HAVE" then
        onHave(payload)
    elseif cmd == "GONE" then
        onGone(payload, sender)
    elseif cmd == "XHEAD" then
        local head = ns.JSON.decode(payload)
        if head and head.tid then
            local t = transfers[head.tid] or { parts = {}, received = 0 }
            t.total = head.total
            t.kind = head.kind
            t.sender = sender
            transfers[head.tid] = t
            tryComplete(head.tid)
        end
    elseif cmd == "XDATA" then
        local tid, idx, data = payload:match("^(%w+):(%d+):(.*)$")
        if tid then
            local t = transfers[tid]
            if not t then
                t = { parts = {}, received = 0, sender = sender }
                transfers[tid] = t
            end
            idx = tonumber(idx)
            if t.parts[idx] == nil then
                t.parts[idx] = data
                t.received = t.received + 1
            end
            tryComplete(tid)
        end
    end
end
