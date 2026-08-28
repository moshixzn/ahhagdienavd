-- Shard | WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local RS              = game:GetService("ReplicatedStorage")
local player          = players.LocalPlayer

-- // State
local State = {
    AutoSteal            = false,
    EggNameFilter        = "",         -- blank = steal any egg name
    SpeedBoost           = 50,
    GlideSpeed           = 20,
    RarityFilter         = "Any",
    RareHunter           = false,
    RareTier             = "Rare",
    StealOnce            = false,
    AutoHop              = false,
    MaxHops              = 10,
    HopDelay             = 30,
    HopCount             = 0,
    AutoHatch            = false,
    HatchOnce            = false,
    EggESP               = false,
    AutoEquipBest        = false,
    AutoSell             = false,
    SellRarities         = {},
    AutoSellEggs         = false,
    EggSellRarities      = {},
    AutoClaim            = false,
    ClaimInterval        = 5,
    AutoUpgrade          = false,
    UpgradeInterval      = 5,
    AutoTreadmill        = false,
    AutoUpgradeTreadmill = false,
    AntiCheat            = false,
}

local Rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}

local Threads    = {}
local ESPObjects = {}   -- { egg = Model, label = DrawingText }

-- // Core Helpers -------------------------------------------------------

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(pos)
    local root = getRootPart()
    if root then root.CFrame = CFrame.new(pos) end
end

local function findRemote(...)
    local patterns = {...}
    for _, desc in ipairs(RS:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local n = desc.Name:lower()
            for _, pat in ipairs(patterns) do
                if n:find(pat:lower(), 1, true) then return desc end
            end
        end
    end
end

-- findEggs: now respects EggNameFilter.
-- If EggNameFilter is non-empty, only return eggs whose name contains
-- the filter string (case-insensitive). Blank = return all eggs.
local function findEggs()
    local eggs   = {}
    local filter = State.EggNameFilter:lower()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("egg", 1, true) then
            if filter == "" or obj.Name:lower():find(filter, 1, true) then
                eggs[#eggs + 1] = obj
            end
        end
    end
    return eggs
end

local function rarityMatches(name, rarity)
    if rarity == "Any" then return true end
    return name:lower():find(rarity:lower(), 1, true) ~= nil
end

local function tryInteractEgg(egg)
    for _, pp in ipairs(egg:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            pcall(function() if fireproximityprompt then fireproximityprompt(pp) end end)
        end
    end
    for _, cd in ipairs(egg:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(function() if fireclickdetector then fireclickdetector(cd) end end)
        end
    end
    for _, re in ipairs(egg:GetDescendants()) do
        if re:IsA("RemoteEvent") then
            pcall(function() re:FireServer(egg) end)
        end
    end
    local remote = findRemote("steal","grab","collect","pick","take","snatch","egg")
    if remote then
        pcall(function() remote:FireServer(egg) end)
        pcall(function() remote:FireServer(egg.Name) end)
        pcall(function() remote:FireServer() end)
    end
end

local function killThread(name)
    if Threads[name] then
        pcall(task.cancel, Threads[name])
        Threads[name] = nil
    end
end

-- // Anti-Cheat Bypass --------------------------------------------------

local function applyACBypass()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    pcall(function()
        hum:Destroy()
        local newHum = Instance.new("Humanoid")
        newHum.Parent = char
    end)
end

local function startACLoop()
    killThread("ac")
    Threads["ac"] = task.spawn(function()
        applyACBypass()
        local conn
        conn = player.CharacterAdded:Connect(function()
            if State.AntiCheat then
                task.wait(0.5)
                applyACBypass()
            else
                conn:Disconnect()
            end
        end)
        while State.AntiCheat do task.wait(5) end
        pcall(function() conn:Disconnect() end)
    end)
end

-- // Drawing-Based ESP --------------------------------------------------

local Camera = workspace.CurrentCamera

local function worldToScreen(pos)
    local screenPos, inView = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), inView and screenPos.Z > 0
end

local function newDrawingText()
    local ok, obj = pcall(Drawing.new, "Text")
    if not ok then return nil end
    obj.Visible      = false
    obj.Size         = 14
    obj.Center       = true
    obj.Outline      = true
    obj.OutlineColor = Color3.fromRGB(0, 0, 0)
    obj.Color        = Color3.fromRGB(255, 220, 50)
    obj.Font         = Drawing.Fonts.UI
    return obj
end

local function syncESPObjects()
    -- prune destroyed eggs
    for i = #ESPObjects, 1, -1 do
        local entry = ESPObjects[i]
        if not entry.egg or not entry.egg.Parent then
            pcall(function() entry.label:Remove() end)
            table.remove(ESPObjects, i)
        end
    end

    if not State.EggESP then
        for _, e in ipairs(ESPObjects) do
            pcall(function() e.label.Visible = false end)
        end
        return
    end

    local eggs    = findEggs()
    local tracked = {}
    for _, e in ipairs(ESPObjects) do tracked[e.egg] = e end

    for _, egg in ipairs(eggs) do
        if not tracked[egg] then
            local lbl = newDrawingText()
            if lbl then
                ESPObjects[#ESPObjects + 1] = { egg = egg, label = lbl }
                tracked[egg] = ESPObjects[#ESPObjects]
            end
        end
        local entry = tracked[egg]
        if entry then
            local part = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
            if part then
                local screenPos, onScreen = worldToScreen(part.Position + Vector3.new(0, 3.5, 0))
                entry.label.Visible  = onScreen
                entry.label.Position = screenPos
                entry.label.Text     = egg.Name
            else
                entry.label.Visible = false
            end
        end
    end
end

local function startESPLoop()
    killThread("esp")
    Threads["esp"] = task.spawn(function()
        local conn = RunService.RenderStepped:Connect(function()
            pcall(syncESPObjects)
        end)
        while State.EggESP do task.wait(0.5) end
        pcall(function() conn:Disconnect() end)
        for _, e in ipairs(ESPObjects) do
            pcall(function() e.label:Remove() end)
        end
        ESPObjects = {}
    end)
end

-- // Auto Steal (fixed) ------------------------------------------------
-- Fixes:
--   1. EggNameFilter is respected via findEggs() (already filtered there)
--   2. StealOnce now properly exits the OUTER while-loop, not just the
--      inner for-loop, so the script stops polling after one steal.
--   3. Added a small loop between teleport and interact so the server
--      has time to register proximity before FireServer is called.

local function startStealLoop()
    killThread("steal")
    Threads["steal"] = task.spawn(function()
        while State.AutoSteal do
            local stoleThisCycle = false

            for _, egg in ipairs(findEggs()) do
                if not State.AutoSteal then break end

                if rarityMatches(egg.Name, State.RarityFilter) then
                    local part = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
                    if part then
                        -- Teleport close to the egg
                        teleportTo(part.Position + Vector3.new(0, 3, 0))

                        -- Boost walk speed
                        local hum = getHumanoid()
                        if hum then hum.WalkSpeed = State.SpeedBoost end

                        -- Brief settle so proximity checks fire server-side
                        task.wait(0.3)

                        tryInteractEgg(egg)
                        stoleThisCycle = true

                        -- If steal-once: mark done, break inner loop
                        if State.StealOnce then
                            State.AutoSteal = false  -- stops the outer while too
                            break
                        end
                    end
                end
                task.wait(0.1)
            end

            -- Only wait for next cycle if we're still running
            if State.AutoSteal then
                task.wait(0.8)
            end
        end
    end)
end

-- // Other Feature Loops ------------------------------------------------

local function startHatchLoop()
    killThread("hatch")
    Threads["hatch"] = task.spawn(function()
        local hatched = false
        while State.AutoHatch do
            if not (State.HatchOnce and hatched) then
                local remote = findRemote("hatch","open","crack","incubat")
                if remote then
                    pcall(function() remote:FireServer() end)
                    hatched = true
                end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local txt = (obj.ActionText .. obj.ObjectText):lower()
                        if txt:find("hatch", 1, true) or txt:find("open", 1, true) then
                            pcall(function() if fireproximityprompt then fireproximityprompt(obj) end end)
                            hatched = true
                        end
                    end
                end
            end
            task.wait(1.5)
        end
    end)
end

local function startClaimLoop()
    killThread("claim")
    Threads["claim"] = task.spawn(function()
        while State.AutoClaim do
            local remote = findRemote("claim","reward","daily","bonus","chest")
            if remote then pcall(function() remote:FireServer() end) end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local txt = (obj.ActionText .. obj.ObjectText):lower()
                    if txt:find("claim",1,true) or txt:find("reward",1,true) or txt:find("collect",1,true) then
                        pcall(function() if fireproximityprompt then fireproximityprompt(obj) end end)
                    end
                end
            end
            task.wait(State.ClaimInterval)
        end
    end)
end

local function startUpgradeLoop()
    killThread("upgrade")
    Threads["upgrade"] = task.spawn(function()
        while State.AutoUpgrade do
            local remote = findRemote("upgrade","levelup","stat","improve","boost")
            if remote then
                pcall(function() remote:FireServer() end)
                pcall(function() remote:FireServer(1) end)
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local txt = (obj.ActionText .. obj.ObjectText):lower()
                    if txt:find("upgrade",1,true) or txt:find("level",1,true) then
                        pcall(function() if fireproximityprompt then fireproximityprompt(obj) end end)
                    end
                end
            end
            task.wait(State.UpgradeInterval)
        end
    end)
end

local function startTreadmillLoop()
    killThread("treadmill")
    Threads["treadmill"] = task.spawn(function()
        while State.AutoTreadmill do
            local treadmill = workspace:FindFirstChild("Treadmill", true)
                           or workspace:FindFirstChild("treadmill", true)
            if treadmill then
                local part = treadmill.PrimaryPart or treadmill:FindFirstChildOfClass("BasePart")
                if part then
                    teleportTo(part.Position + Vector3.new(0, 3, 0))
                    for _, pp in ipairs(treadmill:GetDescendants()) do
                        if pp:IsA("ProximityPrompt") then
                            pcall(function() if fireproximityprompt then fireproximityprompt(pp) end end)
                        end
                    end
                end
            end
            if State.AutoUpgradeTreadmill then
                local remote = findRemote("treadmill","treadup","upgradetread")
                if remote then pcall(function() remote:FireServer() end) end
            end
            task.wait(0.8)
        end
    end)
end

local function startEquipLoop()
    killThread("equip")
    Threads["equip"] = task.spawn(function()
        while State.AutoEquipBest do
            local remote = findRemote("equipbest","equip","bestpet")
            if remote then
                pcall(function() remote:FireServer() end)
                pcall(function() remote:FireServer("best") end)
            end
            task.wait(3)
        end
    end)
end

local function startSellLoop()
    killThread("sell")
    Threads["sell"] = task.spawn(function()
        while State.AutoSell do
            local remote = findRemote("sellpet","sell","sellall")
            if remote then
                pcall(function() remote:FireServer(State.SellRarities) end)
                pcall(function() remote:FireServer() end)
            end
            task.wait(2.5)
        end
    end)
end

local function startSellEggLoop()
    killThread("sellegg")
    Threads["sellegg"] = task.spawn(function()
        while State.AutoSellEggs do
            local remote = findRemote("sellegg","sell","sellall")
            if remote then
                pcall(function() remote:FireServer(State.EggSellRarities) end)
                pcall(function() remote:FireServer() end)
            end
            task.wait(2.5)
        end
    end)
end

-- // Window -------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title  = "Shard",
    Icon   = "solar:folder-2-bold-duotone",
    Folder = "Shard",
    NewElements = true,
    OpenButton = {
        Title        = "Shard",
        Enabled      = true,
        Draggable    = true,
        OnlyMobile   = false,
        CornerRadius = UDim.new(1, 0),
        Color = ColorSequence.new(
            Color3.fromHex("#FF6B35"),
            Color3.fromHex("#FFD700")
        ),
    },
})

-- ==================== FARM TAB ====================
local FarmSection = Window:Section({ Title = "Farm" })

-- ---- Anti-Cheat Bypass ----
local ACTab = FarmSection:Tab({
    Title = "Anti-Cheat Bypass",
    Icon  = "solar:shield-bold",
})

ACTab:Toggle({
    Title    = "Enable AC Bypass",
    Desc     = "Destroys & recreates Humanoid to drop AC hooks",
    Callback = function(v)
        State.AntiCheat = v
        if v then startACLoop() else killThread("ac") end
    end,
})
ACTab:Space()
ACTab:Button({
    Title    = "Apply Bypass Now",
    Icon     = "solar:shield-bold",
    Color    = Color3.fromHex("#FF6B35"),
    Callback = function()
        applyACBypass()
        WindUI:Notify({ Title = "AC Bypass", Content = "Humanoid replaced successfully.", Duration = 3 })
    end,
})

-- ---- Auto Steal ----
local StealTab = FarmSection:Tab({
    Title = "Auto Steal",
    Icon  = "solar:cursor-square-bold",
})

StealTab:Toggle({
    Title    = "Enable Auto Steal",
    Desc     = "Automatically steals eggs nearby",
    Callback = function(v)
        State.AutoSteal = v
        if v then startStealLoop() end
    end,
})
StealTab:Space()
-- Egg Name Filter — new addition
StealTab:Input({
    Title       = "Egg Name Filter",
    Desc        = "Only steal eggs whose name contains this (blank = any)",
    Placeholder = "e.g. Golden Egg",
    Callback    = function(v)
        State.EggNameFilter = v or ""
    end,
})
StealTab:Space()
StealTab:Slider({
    Title     = "Speed Boost",
    Desc      = "WalkSpeed while stealing",
    IsTooltip = true,
    Step      = 1,
    Value     = { Min = 16, Max = 500, Default = 50 },
    Callback  = function(v) State.SpeedBoost = v end,
})
StealTab:Space()
StealTab:Slider({
    Title     = "Glide Speed",
    Desc      = "Speed when gliding to egg",
    IsTooltip = true,
    Step      = 1,
    Value     = { Min = 1, Max = 200, Default = 20 },
    Callback  = function(v) State.GlideSpeed = v end,
})
StealTab:Space()
StealTab:Dropdown({
    Title    = "Egg Rarity Filter",
    Desc     = "Only steal eggs of this rarity",
    Values   = {"Any","Common","Uncommon","Rare","Epic","Legendary","Mythic"},
    Value    = 1,
    Callback = function(v) State.RarityFilter = v end,
})
StealTab:Space()
StealTab:Toggle({
    Title    = "Rare Egg Hunter",
    Desc     = "Only target rare+ eggs",
    Callback = function(v) State.RareHunter = v end,
})
StealTab:Space()
StealTab:Dropdown({
    Title    = "Rare Tier",
    Desc     = "Minimum rarity to hunt",
    Values   = Rarities,
    Value    = 3,
    Callback = function(v) State.RareTier = v end,
})
StealTab:Space()
StealTab:Toggle({
    Title    = "Steal Once",
    Desc     = "Stop after stealing one egg",
    Callback = function(v) State.StealOnce = v end,
})

-- ---- Server Hop ----
local HopTab = FarmSection:Tab({
    Title = "Server Hop",
    Icon  = "solar:square-transfer-horizontal-bold",
})

HopTab:Toggle({
    Title    = "Enable Auto Server Hop",
    Desc     = "Hops servers automatically",
    Callback = function(v)
        State.AutoHop  = v
        State.HopCount = 0
        if v then
            killThread("hop")
            Threads["hop"] = task.spawn(function()
                local placeId = game.PlaceId
                while State.AutoHop and State.HopCount < State.MaxHops do
                    task.wait(State.HopDelay)
                    State.HopCount += 1
                    TeleportService:Teleport(placeId, player)
                end
                State.AutoHop = false
            end)
        else
            killThread("hop")
        end
    end,
})
HopTab:Space()
HopTab:Slider({
    Title     = "Max Hops",
    IsTooltip = true, Step = 1,
    Value     = { Min = 1, Max = 50, Default = 10 },
    Callback  = function(v) State.MaxHops = v end,
})
HopTab:Space()
HopTab:Slider({
    Title     = "Check Delay (s)",
    IsTooltip = true, Step = 1,
    Value     = { Min = 5, Max = 120, Default = 30 },
    Callback  = function(v) State.HopDelay = v end,
})
HopTab:Space()
HopTab:Button({
    Title    = "Server Hop Now",
    Icon     = "solar:square-transfer-horizontal-bold",
    Color    = Color3.fromHex("#FF6B35"),
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end,
})
HopTab:Space()
HopTab:Button({
    Title    = "Recall to Spawn",
    Icon     = "solar:home-2-bold",
    Callback = function()
        local spawn = workspace:FindFirstChild("SpawnLocation")
        teleportTo(spawn and spawn.Position + Vector3.new(0, 5, 0) or Vector3.new(0, 10, 0))
    end,
})

-- ---- Hatch & ESP ----
local HatchTab = FarmSection:Tab({
    Title = "Hatch & ESP",
    Icon  = "solar:info-square-bold",
})

HatchTab:Toggle({
    Title    = "Enable Auto Hatch",
    Desc     = "Automatically hatches eggs",
    Callback = function(v)
        State.AutoHatch = v
        if v then startHatchLoop() end
    end,
})
HatchTab:Space()
HatchTab:Toggle({
    Title    = "Hatch Once",
    Desc     = "Hatch only one egg",
    Callback = function(v) State.HatchOnce = v end,
})
HatchTab:Space()
HatchTab:Toggle({
    Title    = "Enable Egg ESP",
    Desc     = "Drawing-based ESP — labels track eggs through walls",
    Callback = function(v)
        State.EggESP = v
        if v then startESPLoop() else killThread("esp") end
    end,
})

-- ==================== PETS TAB ====================
local PetsSection = Window:Section({ Title = "Pets" })

local EquipTab = PetsSection:Tab({
    Title = "Equip & Sell",
    Icon  = "solar:check-square-bold",
})

EquipTab:Toggle({
    Title    = "Enable Auto Equip Best",
    Desc     = "Automatically equips your best pet",
    Callback = function(v)
        State.AutoEquipBest = v
        if v then startEquipLoop() end
    end,
})
EquipTab:Space()
EquipTab:Button({
    Title    = "Equip Best Now",
    Color    = Color3.fromHex("#30FF6A"),
    Callback = function()
        local remote = findRemote("equipbest","equip","bestpet")
        if remote then
            pcall(function() remote:FireServer() end)
            pcall(function() remote:FireServer("best") end)
        end
    end,
})
EquipTab:Space()
EquipTab:Toggle({
    Title    = "Enable Auto Sell",
    Desc     = "Auto sells pets by rarity",
    Callback = function(v)
        State.AutoSell = v
        if v then startSellLoop() end
    end,
})
EquipTab:Space()
EquipTab:Dropdown({
    Title     = "Rarities to Sell",
    Desc      = "Which rarities to auto sell",
    Values    = Rarities,
    Multi     = true,
    AllowNone = true,
    Callback  = function(v) State.SellRarities = v end,
})
EquipTab:Space()
EquipTab:Button({
    Title    = "Sell Inventory Now",
    Color    = Color3.fromHex("#FF4830"),
    Callback = function()
        local remote = findRemote("sellpet","sell","sellall")
        if remote then
            pcall(function() remote:FireServer(State.SellRarities) end)
            pcall(function() remote:FireServer() end)
        end
    end,
})
EquipTab:Space()
EquipTab:Toggle({
    Title    = "Enable Auto Sell Eggs",
    Desc     = "Auto sells eggs by rarity",
    Callback = function(v)
        State.AutoSellEggs = v
        if v then startSellEggLoop() end
    end,
})
EquipTab:Space()
EquipTab:Dropdown({
    Title     = "Egg Rarities to Sell",
    Values    = Rarities,
    Multi     = true,
    AllowNone = true,
    Callback  = function(v) State.EggSellRarities = v end,
})
EquipTab:Space()
EquipTab:Button({
    Title    = "Sell All Eggs Now",
    Color    = Color3.fromHex("#FF4830"),
    Callback = function()
        local remote = findRemote("sellegg","sell","sellall")
        if remote then
            pcall(function() remote:FireServer(State.EggSellRarities) end)
            pcall(function() remote:FireServer() end)
        end
    end,
})

-- Visual Pet
local VisualTab = PetsSection:Tab({
    Title = "Visual Pet",
    Icon  = "solar:home-2-bold",
})

local petName     = "PetName"
local petMutation = "None"
local petSize     = 1

VisualTab:Input({
    Title       = "Pet",
    Desc        = "Pet name to spawn visually",
    Placeholder = "e.g. Dragon",
    Callback    = function(v) petName = v end,
})
VisualTab:Space()
VisualTab:Input({
    Title       = "Mutation",
    Placeholder = "e.g. Golden",
    Callback    = function(v) petMutation = v end,
})
VisualTab:Space()
VisualTab:Slider({
    Title     = "Size",
    IsTooltip = true, Step = 1,
    Value     = { Min = 1, Max = 10, Default = 1 },
    Callback  = function(v) petSize = v end,
})
VisualTab:Space()
VisualTab:Button({
    Title    = "Add to Inventory",
    Color    = Color3.fromHex("#305dff"),
    Callback = function()
        local remote = findRemote("addpet","givepet","spawnpet")
        if remote then pcall(function() remote:FireServer(petName, petMutation, petSize) end) end
    end,
})
VisualTab:Space()
VisualTab:Button({
    Title    = "Equip Pet",
    Color    = Color3.fromHex("#30FF6A"),
    Callback = function()
        local remote = findRemote("equippet","equip","selectpet")
        if remote then pcall(function() remote:FireServer(petName) end) end
    end,
})
VisualTab:Space()
VisualTab:Button({
    Title    = "Unequip Pet",
    Callback = function()
        local remote = findRemote("unequip","removepet","deselect")
        if remote then pcall(function() remote:FireServer() end) end
    end,
})
VisualTab:Space()
VisualTab:Button({
    Title    = "Remove All Pets",
    Color    = Color3.fromHex("#FF4830"),
    Callback = function()
        local remote = findRemote("removeall","clearinventory","deleteall")
        if remote then pcall(function() remote:FireServer() end) end
    end,
})

-- ==================== UPGRADES TAB ====================
local UpgradesSection = Window:Section({ Title = "Upgrades" })

local ClaimTab = UpgradesSection:Tab({
    Title = "Claim & Upgrade",
    Icon  = "solar:file-text-bold",
})

ClaimTab:Toggle({
    Title    = "Enable Auto Claim",
    Desc     = "Automatically claims rewards",
    Callback = function(v)
        State.AutoClaim = v
        if v then startClaimLoop() end
    end,
})
ClaimTab:Space()
ClaimTab:Slider({
    Title     = "Claim Interval (s)",
    IsTooltip = true, Step = 1,
    Value     = { Min = 1, Max = 60, Default = 5 },
    Callback  = function(v) State.ClaimInterval = v end,
})
ClaimTab:Space()
ClaimTab:Button({
    Title    = "Claim Now",
    Color    = Color3.fromHex("#30FF6A"),
    Callback = function()
        local remote = findRemote("claim","reward","daily","bonus")
        if remote then pcall(function() remote:FireServer() end) end
    end,
})
ClaimTab:Space()
ClaimTab:Toggle({
    Title    = "Enable Auto Upgrade",
    Desc     = "Automatically upgrades stats",
    Callback = function(v)
        State.AutoUpgrade = v
        if v then startUpgradeLoop() end
    end,
})
ClaimTab:Space()
ClaimTab:Slider({
    Title     = "Upgrade Interval (s)",
    IsTooltip = true, Step = 1,
    Value     = { Min = 1, Max = 60, Default = 5 },
    Callback  = function(v) State.UpgradeInterval = v end,
})
ClaimTab:Space()
ClaimTab:Button({
    Title    = "Upgrade Now",
    Color    = Color3.fromHex("#305dff"),
    Callback = function()
        local remote = findRemote("upgrade","levelup","stat")
        if remote then
            pcall(function() remote:FireServer() end)
            pcall(function() remote:FireServer(1) end)
        end
    end,
})

-- Treadmill
local TreadTab = UpgradesSection:Tab({
    Title = "Treadmill",
    Icon  = "solar:square-transfer-horizontal-bold",
})

TreadTab:Toggle({
    Title    = "Enable Auto Treadmill",
    Desc     = "Teleports to treadmill and runs",
    Callback = function(v)
        State.AutoTreadmill = v
        if v then startTreadmillLoop() end
    end,
})
TreadTab:Space()
TreadTab:Toggle({
    Title    = "Auto-Upgrade Treadmill",
    Desc     = "Upgrades treadmill automatically",
    Callback = function(v) State.AutoUpgradeTreadmill = v end,
})
TreadTab:Space()
TreadTab:Button({
    Title    = "Go to Treadmill",
    Color    = Color3.fromHex("#305dff"),
    Callback = function()
        local t = workspace:FindFirstChild("Treadmill", true)
               or workspace:FindFirstChild("treadmill", true)
        if t then
            local part = t.PrimaryPart or t:FindFirstChildOfClass("BasePart")
            if part then teleportTo(part.Position + Vector3.new(0, 3, 0)) end
        else
            WindUI:Notify({ Title = "Treadmill", Content = "Not found in workspace.", Duration = 3 })
        end
    end,
})

-- ==================== SETTINGS TAB ====================
local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon  = "solar:info-square-bold",
})

SettingsTab:Section({ Title = "Configuration" })

SettingsTab:Slider({
    Title     = "Walk Speed",
    IsTooltip = true, Step = 1,
    Value     = { Min = 16, Max = 500, Default = 16 },
    Callback  = function(v)
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = v end
    end,
})
SettingsTab:Space()
SettingsTab:Slider({
    Title     = "Jump Power",
    IsTooltip = true, Step = 1,
    Value     = { Min = 50, Max = 500, Default = 50 },
    Callback  = function(v)
        local hum = getHumanoid()
        if hum then hum.JumpPower = v end
    end,
})
SettingsTab:Space()
SettingsTab:Button({
    Title    = "Destroy Hub",
    Color    = Color3.fromHex("#FF4830"),
    Icon     = "solar:info-square-bold",
    Callback = function()
        for name in pairs(Threads) do killThread(name) end
        for _, e in ipairs(ESPObjects) do
            pcall(function() e.label:Remove() end)
        end
        ESPObjects = {}
        Window:Destroy()
    end,
})

WindUI:Notify({
    Title    = "Shard",
    Content  = "Loaded successfully! 🥚",
    Duration = 5,
})
