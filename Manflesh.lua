local addonName, ns = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            ns.InitDB()
            ns.Print("loaded. |cffffd100/mf|r to open.")
        end
    elseif event == "PLAYER_LOGIN" then
        ns.Comm.Init()
        -- announce a little after login so guild/group + addon comms are ready
        C_Timer.After(8, function()
            ns.Comm.SendHello()
            ns.Comm.VerifyRosters()
        end)
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == ns.PREFIX then
            ns.Comm.OnAddonMessage(arg2, arg4)
        end
    end
end)

SLASH_MANFLESH1 = "/mf"
SLASH_MANFLESH2 = "/manflesh"
SlashCmdList["MANFLESH"] = function(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = input:match("^(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        ns.UI.ToggleMain()
    elseif cmd == "import" then
        ns.UI.ShowImport()
    elseif cmd == "export" then
        ns.UI.ShowExport()
    elseif cmd == "sync" or cmd == "scan" then
        ns.Comm.SendHello()
        ns.Comm.VerifyRosters()
        ns.Print("Scanning guild/group for shared rosters...")
    elseif cmd == "id" or cmd == "get" then
        ns.UI.ShowManualImport()
    elseif cmd == "roster" then
        local sub, id = rest:match("^(%S*)%s*(.*)$")
        sub = (sub or ""):lower()
        id = (id or ""):gsub("%s+$", "")
        if sub == "remove" or sub == "delete" then
            if id == "" then
                ns.Print("Usage: |cffffd100/mf roster remove <id>|r")
            else
                ns.UI.RequestRemoveRoster(id)
            end
        elseif sub == "list" then
            ns.UI.ListRostersToChat()
        else
            ns.Print("Usage: |cffffd100/mf roster list|r or |cffffd100/mf roster remove <id>|r")
        end
    else
        ns.Print("Commands: |cffffd100/mf|r, |cffffd100import|r, |cffffd100id|r, |cffffd100sync|r, |cffffd100export|r, |cffffd100roster list|r, |cffffd100roster remove <id>|r")
    end
end
