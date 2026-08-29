-- Shard Hub | Steal an Egg | Auto Steal Free
-- Instant TP to egg → grab → infinite-yield walk TP back to base
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local Workspace  = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")

local player = players.LocalPlayer

-- ═══════════════════════════════════════════════════════
--  CONSTANTS
-- ═══════════════════════════════════════════════════════
local K = {}
local M = {}
local T = {}
local A = {}

K.Rarities = {
    "Common","Uncommon","Rare","Epic","Legendary",
    "Mythic","Cosmic","Secret","Divine","Eternal",
}

-- infinite-yield walk TP speed (studs per 0.08 s = 562.5 studs/s)
K.WALK_SPEED   = 562.5
K.WALK_STEP    = 45      -- studs moved per tick
K.WALK_TICK    = 0.08    -- seconds per tick
K.REACH_DIST   = 8       -- studs — close enough to base
K.GRAB_TIMEOUT = 8       -- seconds — abort if egg gone

-- ═══════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════
local State = {
    Unloaded        = false,
    AutoStealFree   = false,
    AreaFocus       = {},
    RarityFilter    = {},
    ManualBase      = nil,   -- Vector3 set by "Set Base Here"
    AntiCheat       = false,
    HumReady        = false,
    SpeedChanger    = false,
    SpeedValue      = 60,
    -- Pets tab
    AutoPutEggs     = false,  -- places all inventory eggs onto the player's base plot
    PutEggsDelay    = 0.4,    -- seconds between each place attempt
}

local Threads = {}
local Conns   = {}

local function alive()
    return not State.Unloaded
end

-- ═══════════════════════════════════════════════════════
--  NOTIFY
-- ═══════════════════════════════════════════════════════
local function notify(title, content, dur)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = dur or 4 })
    end)
end

-- ═══════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════
local function root()
    local ch = player.Character
    return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

local function hum()
    local ch = player.Character
    return ch and ch:FindFirstChildWhichIsA("Humanoid") or nil
end

local function charReady()
    local h = hum()
    return root() ~= nil and h ~= nil and h.Health > 0
end

local function spawnLoop(fn)
    local th = task.spawn(function()
        xpcall(fn, function(err)
            warn("[ShardFree] " .. tostring(err) .. "\n" .. debug.traceback())
        end)
    end)
    Threads[#Threads + 1] = th
    return th
end

local function track(conn)
    Conns[#Conns + 1] = conn
    return conn
end

-- ═══════════════════════════════════════════════════════
--  HUMANOID UNLOCK (Anti-Cheat Bypass)
--  Destroys the old Humanoid and replaces it so the
--  server's WalkSpeed governor writes to a dead object
-- ═══════════════════════════════════════════════════════
K.HUM_COPY = {
    "RigType","HipHeight","JumpPower","JumpHeight","UseJumpPower","AutoRotate",
    "MaxSlopeAngle","DisplayDistanceType","NameDisplayDistance","HealthDisplayDistance",
    "AutomaticScalingEnabled","BreakJointsOnDeath","RequiresNeck","EvaluateStateMachine",
}

local function unlockHumanoid()
    local ch  = player.Character
    local old = ch and ch:FindFirstChildWhichIsA("Humanoid")
    if not ch or not old then return false end
    local props = {}
    for _, name in ipairs(K.HUM_COPY) do
        local ok, v = pcall(function() return old[name] end)
        if ok then props[name] = v end
    end
    local base = old.WalkSpeed
    pcall(function() old:Destroy() end)
    RunService.Heartbeat:Wait()
    local new = Instance.new("Humanoid")
    for name, v in pairs(props) do pcall(function() new[name] = v end) end
    new.Parent = ch
    RunService.Heartbeat:Wait()
    if new.Parent ~= ch then return false end
    new.WalkSpeed = base
    pcall(function() new:ChangeState(Enum.HumanoidStateType.Landed) end)
    local cam = Workspace.CurrentCamera
    if cam then pcall(function() cam.CameraSubject = new end) end
    State.HumReady = true
    return true
end

local function ensureUnlock()
    if State.AntiCheat and not State.HumReady and charReady() then
        return unlockHumanoid()
    end
    return State.HumReady
end

-- ═══════════════════════════════════════════════════════
--  NETWORKING
-- ═══════════════════════════════════════════════════════
local NET = RS:FindFirstChild("Packages")
NET = NET and NET:FindFirstChild("Networking") or nil

local R = {
    EggSnapshot = "RF/EggWorld/AskFieldEggSnapshot",
    EggCarry    = "RF/EggWorld/AskFieldEggCarry",
    EggPlace    = "RF/EggWorld/AskPlaceEgg",
    EggLive     = "RF/EggWorld/AskLiveSnapshot",
    WearTool    = "RF/EggWorld/AskWearTool",
    PlotState   = "RF/Homestead/AskState",
    SkipGrowth  = "RF/EggWorld/AskSkipGrowth",
    Hatch       = "RF/EggWorld/AskHatch",
    HatchFinish = "RF/EggWorld/AskFinishHatch",
}

local function net(name)
    return NET and NET:FindFirstChild(name) or nil
end

local function callNet(name, ...)
    local r = net(name)
    if not r then return nil end
    if r:IsA("RemoteFunction") then
        local ok, res = pcall(r.InvokeServer, r, ...)
        return ok and res or nil
    end
    local ok = pcall(r.FireServer, r, ...)
    return ok or nil
end

M.uidShape = {}
local function askUid(name, uid)
    local shape = M.uidShape[name]
    if shape ~= 2 then
        local res = callNet(name, { Uid = uid })
        if res ~= nil and res ~= false then M.uidShape[name] = 1; return true end
        if shape == 1 then return false end
    end
    local res = callNet(name, uid)
    if res ~= nil and res ~= false then M.uidShape[name] = 2; return true end
    return false
end

-- ═══════════════════════════════════════════════════════
--  AREAS + RARITIES
-- ═══════════════════════════════════════════════════════
A.areaLabel   = {}
A.areaRarity  = {}
A.areaTierName= {}
A.areaByLabel = {}
A.areaOrder   = {}

local function addArea(id, label, rank, tierName)
    if not id or A.areaLabel[id] then return end
    label = label or id
    A.areaLabel[id]   = label
    A.areaRarity[id]  = rank or 0
    A.areaTierName[id]= tierName
    A.areaByLabel[label] = id
    A.areaOrder[#A.areaOrder + 1] = id
end

local function sortAreas()
    table.sort(A.areaOrder, function(a, b)
        local ra, rb = A.areaRarity[a] or 0, A.areaRarity[b] or 0
        if ra == rb then return tostring(A.areaLabel[a]) < tostring(A.areaLabel[b]) end
        return ra < rb
    end)
end

local function areaLabels()
    local out = {}
    for _, id in ipairs(A.areaOrder) do out[#out + 1] = A.areaLabel[id] end
    return out
end

do
    local Data  = RS:FindFirstChild("Data")
    local m     = Data and Data:FindFirstChild("Areas")
    local ok, mod = pcall(function() return m and require(m) end)
    local dir   = ok and type(mod) == "table" and (mod.Directory or mod) or nil
    if type(dir) == "table" then
        for id, info in pairs(dir) do
            if type(id) == "string" and type(info) == "table" then
                local rank, tierName = 0, nil
                if type(info.Rarity) == "table" then
                    rank = tonumber(info.Rarity.RarityNumber) or 0
                    tierName = info.Rarity.DisplayName or info.Rarity._id
                end
                addArea(id, info.DisplayName or info.Name or id, rank, tierName)
            end
        end
    end
    if #A.areaOrder == 0 then
        local folder = Workspace:FindFirstChild("Areas") or Workspace:FindFirstChild("Islands")
        if folder then
            local rank = 0
            for _, a in ipairs(folder:GetChildren()) do
                rank = rank + 1
                addArea(a.Name, a.Name, rank, nil)
            end
        end
    end
    sortAreas()
end

local function asSet(list)
    local set, n = {}, 0
    if type(list) == "table" then
        for _, v in ipairs(list) do
            if type(v) == "string" and v ~= "" then
                set[v] = true; n = n + 1
            end
        end
    end
    return set, n
end

A.areaWanted,   A.areaWantedCount   = {}, 0
A.rarityWanted, A.rarityWantedCount = {}, 0

local function rebuildAreaSet()
    local labels = asSet(State.AreaFocus)
    local ids, n = {}, 0
    for label in pairs(labels) do
        local id = A.areaByLabel[label] or label
        ids[id] = true; n = n + 1
    end
    A.areaWanted, A.areaWantedCount = ids, n
end

local function rebuildRaritySet()
    A.rarityWanted, A.rarityWantedCount = asSet(State.RarityFilter)
end

K.rarityLadder = {}
for i, name in ipairs(K.Rarities) do K.rarityLadder[name] = i end

local function ladderOf(name)
    if type(name) ~= "string" then return 0 end
    return K.rarityLadder[name] or 0
end

local function rarityOf(rec)
    local v = rec.Rarity or rec.RarityName or rec.Tier or rec.RarityId
    if type(v) == "table" then v = v.DisplayName or v._id or v.Name or v.Id end
    return type(v) == "string" and v or nil
end

local function isMutated(rec)
    if rec.BaseMutation then return true end
    return type(rec.Mutations) == "table" and next(rec.Mutations) ~= nil
end

-- ═══════════════════════════════════════════════════════
--  EGG SLOTS
-- ═══════════════════════════════════════════════════════
M.slotsCache = nil

local function slots()
    if M.slotsCache and M.slotsCache.Parent then return M.slotsCache end
    M.slotsCache = Workspace:FindFirstChild("AreaEggSlotsClient")
    return M.slotsCache
end

local function eggModel(uid)
    local folder = slots()
    return folder and folder:FindFirstChild(uid) or nil
end

local function eggPart(uid)
    local mdl = eggModel(uid)
    if not mdl then return nil end
    return mdl.PrimaryPart or mdl:FindFirstChild("Hitbox") or mdl:FindFirstChildWhichIsA("BasePart")
end

local function eggPos(rec)
    local part = eggPart(rec.Uid)
    if part then return part.Position end
    local cf = rec.BoundsCFrame or rec.BottomCFrame
    return cf and cf.Position or nil
end

-- ═══════════════════════════════════════════════════════
--  EGG LIST
-- ═══════════════════════════════════════════════════════
M.eggList   = {}
M.eggListAt = 0
M.triedUids = {}
M.areaDirty = false

local function refreshEggs(force)
    if not force and tick() - M.eggListAt < 1.5 then return M.eggList end
    local snap = callNet(R.EggSnapshot)
    local recs = snap and snap.Records
    if type(recs) ~= "table" then return M.eggList end
    local list = {}
    for _, rec in pairs(recs) do
        if rec.State == "Slot" and rec.Uid then
            local pos = eggPos(rec)
            if pos then
                local id = rec.AreaId
                if id and not A.areaLabel[id] then
                    addArea(id, id, #A.areaOrder + 1, rarityOf(rec))
                    M.areaDirty = true
                end
                list[#list + 1] = {
                    uid     = rec.Uid,
                    area    = id,
                    label   = id and A.areaLabel[id] or "Unknown",
                    pos     = pos,
                    tier    = id and A.areaRarity[id] or 0,
                    rarity  = id and A.areaTierName[id] or rarityOf(rec),
                    mutated = isMutated(rec),
                    size    = rec.BoundsSize and rec.BoundsSize.Magnitude or 3,
                }
            end
        end
    end
    M.eggList   = list
    M.eggListAt = tick()
    return list
end

local function eligible(e)
    if M.triedUids[e.uid] and tick() - M.triedUids[e.uid] < 6 then return false end
    if A.areaWantedCount  > 0 and not A.areaWanted[e.area]    then return false end
    if A.rarityWantedCount > 0 and not A.rarityWanted[e.rarity] then return false end
    return true
end

local function pickEgg()
    local hrp = root()
    if not hrp then return nil end
    refreshEggs(false)
    local origin = hrp.Position
    local best, bestScore
    for i = 1, #M.eggList do
        local e = M.eggList[i]
        if eligible(e) then
            local d     = (e.pos - origin).Magnitude
            local tier  = e.tier > 0 and e.tier or ladderOf(e.rarity)
            local score = tier * 1e6 + (e.mutated and 4e5 or 0) - d
            if not bestScore or score > bestScore then
                best, bestScore = e, score
            end
        end
    end
    return best
end

local function livePos(e)
    local part = eggPart(e.uid)
    if part then e.pos = part.Position end
    return e.pos
end

local function eggAlive(uid)
    local folder = slots()
    if not folder then return true end
    return folder:FindFirstChild(uid) ~= nil
end

-- ═══════════════════════════════════════════════════════
--  INSTANT TELEPORT (to egg)
-- ═══════════════════════════════════════════════════════
local function instantTp(pos)
    local r = root()
    if r then
        pcall(function()
            r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        end)
    end
end

-- ═══════════════════════════════════════════════════════
--  INFINITE YIELD WALK TP (return to base)
--  Moves the HRP in fixed 45-stud steps every 0.08 s —
--  identical to infinite yield's tp-walk implementation.
--  Each step is small enough to stay under the AC delta
--  threshold, and it looks like actual movement.
-- ═══════════════════════════════════════════════════════
local function walkTpTo(targetPos, reachDist)
    reachDist = reachDist or K.REACH_DIST
    local r = root()
    if not r then return false end

    -- flat distance check (ignore Y)
    local function flatDist()
        local rr = root()
        if not rr then return 0 end
        return Vector3.new(
            targetPos.X - rr.Position.X, 0,
            targetPos.Z - rr.Position.Z
        ).Magnitude
    end

    if flatDist() <= reachDist then return true end

    local deadline = tick() + 30  -- max 30 seconds travel time

    while alive() and State.AutoStealFree do
        if tick() > deadline then break end

        local rr = root()
        local h  = hum()
        if not rr or not h or h.Health <= 0 then break end

        local remaining = flatDist()
        if remaining <= reachDist then return true end

        -- direction on XZ plane only
        local dir = Vector3.new(
            targetPos.X - rr.Position.X,
            0,
            targetPos.Z - rr.Position.Z
        ).Unit

        -- step size: full step or whatever's left
        local step = math.min(K.WALK_STEP, remaining)

        -- keep Y on ground (simple: preserve current Y)
        local newPos = Vector3.new(
            rr.Position.X + dir.X * step,
            rr.Position.Y,
            rr.Position.Z + dir.Z * step
        )

        pcall(function()
            rr.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
        end)

        task.wait(K.WALK_TICK)
    end

    return flatDist() <= reachDist + 4
end

-- ═══════════════════════════════════════════════════════
--  PLOT / BASE
-- ═══════════════════════════════════════════════════════
M.cachedSlot, M.cachedPlot = nil, nil

local function myPlot()
    if M.cachedPlot and M.cachedPlot.Parent then return M.cachedPlot end
    if not M.cachedSlot then
        local st = callNet(R.PlotState)
        if st and type(st.OwnersBySlot) == "table" then
            for slot, owner in pairs(st.OwnersBySlot) do
                if owner == player.UserId then
                    M.cachedSlot = slot; break
                end
            end
        end
    end
    local plots = Workspace:FindFirstChild("Plots")
    if M.cachedSlot and plots then
        M.cachedPlot = plots:FindFirstChild(tostring(M.cachedSlot))
    end
    return M.cachedPlot
end

local function plotPivot()
    local p = myPlot()
    if not p then return nil end
    local ok, pv = pcall(function() return p:GetPivot() end)
    return ok and pv or nil
end

local function resolveBase()
    -- manual pin takes priority
    if State.ManualBase then return State.ManualBase end
    local pv = plotPivot()
    return pv and pv.Position or nil
end

-- ═══════════════════════════════════════════════════════
--  PLACEMENT
-- ═══════════════════════════════════════════════════════
M.penCache   = nil
M.claimedCells = {}
M.placeShape = 0
M.placeProbes = 0

local function penPivot()
    if M.penCache then return M.penCache end
    local p = myPlot()
    if p then
        for _, d in ipairs(p:GetDescendants()) do
            if d.Name:lower():find("pen", 1, true) then
                if d:IsA("BasePart") then M.penCache = d.CFrame; return M.penCache end
                if d:IsA("Model") then
                    local ok, pv = pcall(function() return d:GetPivot() end)
                    if ok and pv then M.penCache = pv; return M.penCache end
                end
            end
        end
    end
    local base = plotPivot()
    if base then M.penCache = base * CFrame.new(0, 0, 15); return M.penCache end
    return nil
end

K.placeGrid = {}
for z = 0, 30, 5 do
    for x = -20, 20, 5 do
        K.placeGrid[#K.placeGrid + 1] = Vector2.new(x, z)
    end
end

local function cellKey(g) return g.X .. ":" .. g.Y end

local function usedSpots()
    local live = callNet(R.EggLive)
    local used = {}
    if type(live) == "table" then
        for _, entry in pairs(live) do
            if type(entry) == "table" and entry.OwnerUserId == player.UserId
                and type(entry.Records) == "table" then
                for _, rec in pairs(entry.Records) do
                    if rec.Placement and rec.Placement.LocalCFrame then
                        used[#used + 1] = rec.Placement.LocalCFrame.Position
                    end
                end
            end
        end
    end
    return used
end

local function freeCell(g, used)
    if M.claimedCells[cellKey(g)] then return false end
    for _, p in ipairs(used) do
        if math.abs(p.X - g.X) < 3.5 and math.abs(p.Z - g.Y) < 3.5 then return false end
    end
    return true
end

local function tryPlace(uid, cf)
    local r = net(R.EggPlace)
    if not r or not r:IsA("RemoteFunction") then return false end
    local function shot(n)
        if n == 1 then return r:InvokeServer({ Uid = uid, LocalCFrame = cf })
        elseif n == 2 then return r:InvokeServer({ Uid = uid, CFrame = cf })
        elseif n == 3 then return r:InvokeServer(uid, cf)
        end
        return r:InvokeServer({ Uid = uid, Placement = { LocalCFrame = cf } })
    end
    if M.placeShape > 0 then
        local ok, res = pcall(shot, M.placeShape)
        return ok and res == true
    end
    for n = 1, 4 do
        local ok, res = pcall(shot, n)
        if ok and res == true then M.placeShape = n; return true end
    end
    M.placeProbes = M.placeProbes + 1
    if M.placeProbes >= 3 then M.placeShape = 1 end
    return false
end

local function placeEgg(uid, maxTries)
    maxTries = maxTries or 14
    local used = usedSpots()
    local tries = 0
    for _, g in ipairs(K.placeGrid) do
        if freeCell(g, used) then
            tries = tries + 1
            if tryPlace(uid, CFrame.new(g.X, 0, g.Y)) then
                M.claimedCells[cellKey(g)] = true
                return true
            end
            if tries >= maxTries then break end
        end
    end
    return false
end

-- proximity prompts
local fireprompt = fireproximityprompt or (syn and syn.fireproximityprompt)

local function firePrompt(pp)
    if not fireprompt or not pp or not pp.Enabled then return false end
    pcall(function() pp.HoldDuration = 0 end)
    return pcall(fireprompt, pp)
end

local function inRange(pos, reach)
    local hrp = root()
    if not hrp or not pos then return false end
    local a = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
    local b = Vector3.new(pos.X, 0, pos.Z)
    return (a - b).Magnitude <= (reach or 12) + 8
end

local function promptsUnder(inst, words)
    local out = {}
    if not inst then return out end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local hay = (d.Name .. " " .. d.ActionText .. " " .. d.ObjectText):lower()
            if d.Parent then hay = hay .. " " .. d.Parent.Name:lower() end
            for _, w in ipairs(words) do
                if hay:find(w, 1, true) then out[#out + 1] = d; break end
            end
        end
    end
    return out
end

-- ═══════════════════════════════════════════════════════
--  GRAB
-- ═══════════════════════════════════════════════════════
local function holdingEgg()
    -- Requires BOTH "RUN!!" and "Drop" visible at the same time.
    -- Either one alone can appear in other game contexts; together they
    -- uniquely identify the egg-carrying state.
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end

    local function isVisible(obj)
        local node = obj
        while node and node ~= gui do
            if node:IsA("GuiObject") and not node.Visible then return false end
            node = node.Parent
        end
        return true
    end

    local hasRun, hasDrop = false, false
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("TextLabel") then
            local t = desc.Text
            if t:upper() == "RUN!!" and isVisible(desc) then hasRun  = true end
            if t:lower() == "drop"  and isVisible(desc) then hasDrop = true end
        end
        if hasRun and hasDrop then return true end
    end
    return false
end

local function grabEgg(uid)
    if callNet(R.EggCarry, { Uid = uid }) ~= true then return false end
    task.spawn(function()
        for _ = 1, 3 do
            if holdingEgg() then return end
            askUid(R.WearTool, uid)
            task.wait(0.15)
        end
    end)
    return true
end

-- ═══════════════════════════════════════════════════════
--  DELIVER (walk TP back to base then place)
-- ═══════════════════════════════════════════════════════
local function deliver(uid)
    local basePos = resolveBase()
    if not basePos then
        notify("Auto Steal Free", "No base set! Walk to your pen and tap Set Base Here.")
        return false
    end

    -- walk TP back to base
    walkTpTo(basePos, K.REACH_DIST)

    -- try remote place
    for _ = 1, 2 do
        if placeEgg(uid) then return true end
        task.wait(0.2)
    end

    -- fallback: proximity prompts
    for _, pp in ipairs(promptsUnder(myPlot(), { "place", "drop", "put" })) do
        if promptInRange and inRange(pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position, 12) then
            if firePrompt(pp) then task.wait(0.15); return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════
--  INSTANT PROX PROMPT — fires all nearby prompts on loop
--  Turns on/off with the drawing GUI Start/Stop button.
-- ═══════════════════════════════════════════════════════
local proxConn = nil

-- zero out all existing prompt hold durations on load
for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("ProximityPrompt") then
        pcall(function() v.HoldDuration = 0 end)
    end
end
-- also catch any that get added later
track(workspace.DescendantAdded:Connect(function(v)
    if v:IsA("ProximityPrompt") then
        pcall(function() v.HoldDuration = 0 end)
    end
end))

local function triggerNearbyPrompts()
    local ch  = player.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local range = 50
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local part = desc.Parent
            if part and part:IsA("BasePart") then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist <= range then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(desc)
                        end
                    end)
                end
            end
        end
    end
end

local function startProx()
    if proxConn then return end
    proxConn = RunService.Heartbeat:Connect(function()
        if State.AutoStealFree then
            triggerNearbyPrompts()
        end
    end)
end

local function stopProx()
    if proxConn then
        proxConn:Disconnect()
        proxConn = nil
    end
end
-- ═══════════════════════════════════════════════════════
spawnLoop(function()
    while alive() do
        RunService.Heartbeat:Wait()
        if State.SpeedChanger and State.HumReady then
            local h = hum()
            if h and h.Health > 0 then
                pcall(function()
                    if h.WalkSpeed ~= State.SpeedValue then
                        h.WalkSpeed = State.SpeedValue
                    end
                end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════
--  MAIN FREE STEAL LOOP — PASSIVE DETECTOR
--  No TP to egg. Watches for holdingEgg() becoming true
--  (a Tool appears in the character = egg grabbed).
--  The moment it fires → walkTpTo base immediately.
--  1.5 s cooldown prevents double-fire on same carry.
-- ═══════════════════════════════════════════════════════
M.carryingUid   = nil
local stealCooldown = false

spawnLoop(function()
    while alive() do
        RunService.Heartbeat:Wait()
        if State.AutoStealFree and charReady() then
            if holdingEgg() and not stealCooldown then
                stealCooldown = true
                local ok, err = pcall(function()
                    local basePos = resolveBase()
                    if not basePos then
                        notify("Auto Steal Free", "No base set! Walk to your pen and tap Set Base Here.")
                        return
                    end
                    -- walk TP to base
                    walkTpTo(basePos, K.REACH_DIST)
                    -- try remote place
                    for _ = 1, 2 do
                        if placeEgg(M.carryingUid or "") then break end
                        task.wait(0.2)
                    end
                    -- fallback proximity prompts
                    for _, pp in ipairs(promptsUnder(myPlot(), { "place", "drop", "put" })) do
                        local ppos = pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position
                        if inRange(ppos, 12) then
                            if firePrompt(pp) then task.wait(0.15); break end
                        end
                    end
                end)
                if not ok then
                    warn("[ShardFree] detect: " .. tostring(err))
                end
                -- cooldown so we don't retrigger on the same carry
                task.delay(1.5, function() stealCooldown = false end)
            end
        end
    end
end)

-- respawn
track(player.CharacterAdded:Connect(function(ch)
    State.HumReady  = false
    M.carryingUid   = nil
    M.cachedPlot    = nil
    M.penCache      = nil
    pcall(function() ch:WaitForChild("HumanoidRootPart", 10) end)
    task.wait(0.7)
    if State.AutoStealFree or State.SpeedChanger then
        ensureUnlock()
    end
end))

-- unload
local function unload()
    State.Unloaded      = false
    State.AutoStealFree = false
    State.SpeedChanger  = false
    State.AutoPutEggs   = false
    M.carryingUid       = nil
    if texConn then texConn:Disconnect(); texConn = nil end
    stopProx()
    if stealGui then pcall(function() stealGui:Destroy() end); stealGui = nil; updateBtn = nil end
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    for _, th in ipairs(Threads) do pcall(task.cancel, th) end
    Threads = {}
end

-- pickList helper
local function pickList(v)
    local out = {}
    if type(v) == "table" then
        for k, val in pairs(v) do
            if val == true then out[#out + 1] = k
            elseif type(val) == "string" then out[#out + 1] = val end
        end
    elseif type(v) == "string" then
        out[1] = v
    end
    return out
end

K.filterValues = {}
for _, r in ipairs(K.Rarities) do K.filterValues[#K.filterValues + 1] = r end

-- ═══════════════════════════════════════════════════════
--  AUTO PUT EGGS
--  Fetches every egg the player currently owns that is
--  in "Inventory" state (not already placed on a plot),
--  walks the player to their base, then calls placeEgg()
--  on each one in sequence using the existing grid placer.
--  Uses the same AskFieldEggSnapshot remote the steal loop
--  uses — we just filter for State == "Inventory" instead
--  of "Slot".
-- ═══════════════════════════════════════════════════════

local function getInventoryEggs()
    -- ── RF/PenRoster/AskLiveSnapshot ──────────────────────────────────
    -- Confirmed structure from remote dump:
    -- res = { [i] = { OwnerUserId = number, Records = { [guid] = { UID, OwnerUserId, ItemData, MoneyPerSecond, Seed } } } }
    -- The UID field inside each record is the egg uid to pass to AskPlaceEgg.
    local penRemote = NET and NET:FindFirstChild("RF/PenRoster/AskLiveSnapshot")
    if not penRemote then
        notify("Auto Put Eggs", "PenRoster remote not found.", 5)
        return {}
    end

    local ok, res = pcall(penRemote.InvokeServer, penRemote)
    if not ok or type(res) ~= "table" then
        notify("Auto Put Eggs", "PenRoster call failed: " .. tostring(res), 5)
        return {}
    end

    local found = {}
    local myId  = tostring(player.UserId)

    for _, entry in pairs(res) do
        if type(entry) == "table"
            and tostring(entry.OwnerUserId) == myId then
            local recs = entry.Records
            if type(recs) == "table" then
                for _, rec in pairs(recs) do
                    if type(rec) == "table" then
                        -- UID is the field confirmed from the dump
                        local uid = rec.UID or rec.Uid or rec.uid
                        if uid then
                            found[#found + 1] = { Uid = uid, _rec = rec }
                        end
                    end
                end
            end
            break  -- found our entry, no need to keep scanning
        end
    end

    notify("Put Eggs",
        string.format("Found %d eggs in your pen to place.", #found), 4)

    return found
end

local function autoPutEggsOnce()
    local basePos = resolveBase()
    if not basePos then
        notify("Auto Put Eggs", "No base set — walk to your pen and tap Set Base Here first.")
        return 0
    end

    local eggs = getInventoryEggs()
    if #eggs == 0 then
        notify("Auto Put Eggs", "No unplaced eggs found in your inventory.")
        return 0
    end

    -- Walk to base
    walkTpTo(basePos, K.REACH_DIST)
    task.wait(0.2)

    local placed = 0
    for _, rec in ipairs(eggs) do
        if not State.AutoPutEggs then break end

        local uid = rec.Uid
        M.claimedCells = {}  -- reset grid cache so each egg gets a fresh cell check

        local ok = false
        for attempt = 1, 3 do
            ok = placeEgg(uid, 14)
            if ok then break end
            task.wait(0.15)
        end

        if ok then
            placed = placed + 1
        else
            -- Proximity prompt fallback
            for _, pp in ipairs(promptsUnder(myPlot(), { "place", "drop", "put", "hatch" })) do
                local ppos = pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position
                if inRange(ppos, 14) then
                    if firePrompt(pp) then
                        placed = placed + 1
                        ok = true
                        break
                    end
                end
            end
        end

        task.wait(State.PutEggsDelay)
    end

    notify("Auto Put Eggs",
        string.format("Done — placed %d / %d eggs on your plot.", placed, #eggs))
    return placed
end

local function startAutoPutEggsLoop()
    spawnLoop(function()
        while alive() and State.AutoPutEggs do
            autoPutEggsOnce()
            -- Wait between full sweeps so we don't spam the server
            for _ = 1, 30 do
                if not State.AutoPutEggs then break end
                task.wait(0.5)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════
T.Window = WindUI:CreateWindow({
    Title       = "Steal an Egg",
    Icon        = "egg",
    Author      = "Shard Hub",
    Folder      = "ShardHubFree",
    Size        = UDim2.fromOffset(480, 380),
    Transparent = true,
    Theme       = "Dark",
    SideBarWidth = 180,
    HideSearchBar = true,
    NewElements = true,
    OpenButton  = {
        Enabled      = true,
        Title        = "Shard Free",
        Draggable    = true,
        OnlyMobile   = false,
        CornerRadius = UDim.new(0, 14),
        StrokeThickness = 2,
    },
})

local function showWindow()
    for _, m in ipairs({ "Open","Maximize","Unminimize","Show" }) do
        if pcall(function() T.Window[m](T.Window) end) then return true end
    end
    return pcall(function() T.Window:Minimize(false) end)
end

track(UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightControl then showWindow() end
end))

T.SecFarm = T.Window:Section({ Title = "AUTO STEAL FREE", Opened = true })
T.TabMain = T.SecFarm:Tab({ Title = "Auto Steal Free", Icon = "zap-off" })

-- ── Anti-Cheat Bypass ─────────────────────────────
T.TabMain:Section({ Title = "Anti-Cheat Bypass" })

T.TabMain:Toggle({
    Title = "Enable Anti-Cheat Bypass",
    Desc  = "Replaces the Humanoid so the server's WalkSpeed governor writes to a dead object",
    Value = false,
    Callback = function(v)
        State.AntiCheat = v
        if v then
            task.spawn(function()
                local ok = ensureUnlock()
                notify("Anti-Cheat", ok and "Humanoid replaced, bypass active." or "Already bypassed or not ready.")
            end)
        else
            State.HumReady = false
            notify("Anti-Cheat", "Bypass disabled.")
        end
    end,
})

T.TabMain:Toggle({
    Title = "Speed Changer",
    Desc  = "Locks WalkSpeed every frame. Requires Bypass active.",
    Value = false,
    Callback = function(v)
        State.SpeedChanger = v
        if v and not State.HumReady then
            notify("Speed", "Enable Anti-Cheat Bypass first!")
            return
        end
        if v then
            notify("Speed", "Speed locked to " .. State.SpeedValue .. " studs/s.")
        else
            local h = hum()
            if h then pcall(function() h.WalkSpeed = 16 end) end
            notify("Speed", "Speed restored.")
        end
    end,
})

T.TabMain:Slider({
    Title = "Walk Speed",
    Desc  = "Speed while moving. Requires Bypass active.",
    Step  = 1,
    Value = { Min = 16, Max = 500, Default = 60 },
    Callback = function(v)
        State.SpeedValue = v
        if State.SpeedChanger then
            local h = hum()
            if h then pcall(function() h.WalkSpeed = v end) end
        end
    end,
})

-- ── Base Location ─────────────────────────────────
T.TabMain:Section({ Title = "Base Location" })

T.TabMain:Button({
    Title = "Set Base Here",
    Desc  = "Walk to your pen then tap this. The script walks you back here after every steal.",
    Callback = function()
        local r = root()
        if r then
            State.ManualBase = r.Position
            notify("Base", string.format("Base pinned at (%.0f, %.0f, %.0f)",
                r.Position.X, r.Position.Y, r.Position.Z))
        else
            notify("Base", "No root part found.")
        end
    end,
})

T.TabMain:Button({
    Title = "Clear Base Pin",
    Desc  = "Go back to using the server plot location.",
    Callback = function()
        State.ManualBase = nil
        notify("Base", "Manual base cleared.")
    end,
})

-- ── Auto Steal Free ───────────────────────────────
T.TabMain:Section({ Title = "Auto Steal Free" })

local stealGui  = nil
local updateBtn = nil

local function setSteal(v)
    State.AutoStealFree = v
    if v then
        startProx()
        if not State.ManualBase then
            notify("Auto Steal Free", "Tip: walk to your pen and tap Set Base Here first!")
        end
    else
        stopProx()
        M.carryingUid = nil
        stealCooldown = false
    end
    if updateBtn then updateBtn() end
end

local function buildStealGui()
    if stealGui and stealGui.Parent then return end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "ShardStealGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 999
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = player.PlayerGui end
    stealGui = sg

    -- outer frame (draggable)
    local frame = Instance.new("Frame")
    frame.Size             = UDim2.fromOffset(160, 72)
    frame.Position         = UDim2.new(0.5, -80, 0.05, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BorderSizePixel  = 0
    frame.Active           = true
    frame.Draggable        = true
    frame.Parent           = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color     = Color3.fromRGB(80, 80, 80)
    stroke.Thickness  = 1

    -- title
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, -20, 0, 22)
    title.Position               = UDim2.new(0, 0, 0, 4)
    title.BackgroundTransparency = 1
    title.Text                   = "Auto Steal"
    title.TextColor3             = Color3.fromRGB(200, 200, 200)
    title.Font                   = Enum.Font.GothamBold
    title.TextSize               = 12
    title.Parent                 = frame

    -- close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size                   = UDim2.fromOffset(18, 18)
    closeBtn.Position               = UDim2.new(1, -20, 0, 3)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text                   = "✕"
    closeBtn.TextColor3             = Color3.fromRGB(160, 160, 160)
    closeBtn.Font                   = Enum.Font.Gotham
    closeBtn.TextSize               = 12
    closeBtn.BorderSizePixel        = 0
    closeBtn.Parent                 = frame
    closeBtn.MouseButton1Click:Connect(function()
        setSteal(false)
        sg:Destroy()
        stealGui  = nil
        updateBtn = nil
    end)

    -- start/stop button
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -20, 0, 30)
    btn.Position         = UDim2.new(0, 10, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    btn.Text             = "Start"
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 14
    btn.BorderSizePixel  = 0
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    -- updateBtn syncs button colour + text to current state
    updateBtn = function()
        local on = State.AutoStealFree
        btn.Text             = on and "Stop"                      or "Start"
        btn.BackgroundColor3 = on and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 180, 80)
    end
    updateBtn()  -- sync immediately

    btn.MouseButton1Click:Connect(function()
        setSteal(not State.AutoStealFree)
    end)
end

T.TabMain:Toggle({
    Title = "Enable Auto Steal Free",
    Desc  = "Opens the floating Start/Stop control and begins watching for egg carries",
    Value = false,
    Callback = function(v)
        if v then
            buildStealGui()
            setSteal(true)
        else
            setSteal(false)
            if stealGui then
                pcall(function() stealGui:Destroy() end)
                stealGui  = nil
                updateBtn = nil
            end
        end
    end,
})

T.TabMain:Dropdown({
    Title     = "Focus Area",
    Desc      = "Leave empty for all areas",
    Values    = areaLabels(),
    Value     = State.AreaFocus,
    Multi     = true,
    AllowNone = true,
    Callback  = function(v)
        State.AreaFocus = pickList(v)
        rebuildAreaSet()
    end,
})

T.TabMain:Dropdown({
    Title     = "Egg Rarity Filter",
    Desc      = "Leave empty for all rarities",
    Values    = K.filterValues,
    Value     = State.RarityFilter,
    Multi     = true,
    AllowNone = true,
    Callback  = function(v)
        State.RarityFilter = pickList(v)
        rebuildRaritySet()
    end,
})

-- ── Config ────────────────────────────────────────
T.SecSet  = T.Window:Section({ Title = "SETTINGS", Opened = true })
T.TabConf = T.SecSet:Tab({ Title = "Configuration", Icon = "settings" })

T.TabConf:Section({ Title = "Configuration" })

T.TabConf:Button({
    Title = "Show Window",
    Desc  = "Also bound to Right Control",
    Callback = function() showWindow() end,
})

T.TabConf:Button({
    Title = "Unload Script",
    Desc  = "Stops all loops and closes the window",
    Callback = function()
        unload()
        pcall(function() T.Window:Destroy() end)
    end,
})

-- ── Pets ──────────────────────────────────────────
T.SecPets  = T.Window:Section({ Title = "PETS", Opened = true })
T.TabPets  = T.SecPets:Tab({ Title = "Egg Management", Icon = "package" })

T.TabPets:Section({ Title = "Auto Put Eggs" })

T.TabPets:Toggle({
    Title = "Enable Auto Put Eggs",
    Desc  = "Continuously places all inventory eggs onto your base plot using the server remote. Loops until toggled off or inventory is empty.",
    Value = false,
    Callback = function(v)
        State.AutoPutEggs = v
        if v then
            -- Require a base — auto-detect plot or use manual pin
            local basePos = resolveBase()
            if not basePos then
                notify("Auto Put Eggs",
                    "⚠️ No base found — walk to your pen and tap Set Base Here first.")
            end
            startAutoPutEggsLoop()
            notify("Auto Put Eggs", "Started — placing inventory eggs on your plot.")
        else
            notify("Auto Put Eggs", "Stopped.")
        end
    end,
})

T.TabPets:Slider({
    Title = "Delay Between Eggs (s)",
    Desc  = "Time to wait between each egg placement. Lower = faster but more server load.",
    Step  = 0.05,
    Value = { Min = 0.1, Max = 3, Default = 0.4 },
    Callback = function(v)
        State.PutEggsDelay = v
    end,
})

T.TabPets:Button({
    Title = "Place All Eggs Now",
    Desc  = "Runs a single placement sweep immediately (does not need the toggle on).",
    Callback = function()
        spawnLoop(function()
            notify("Auto Put Eggs", "Running placement sweep...")
            autoPutEggsOnce()
        end)
    end,
})

T.TabPets:Button({
    Title    = "Set Base Here (Pets)",
    Desc     = "Pin your current position as the base for egg placement. Same pin used by Auto Steal.",
    Callback = function()
        local r = root()
        if r then
            State.ManualBase = r.Position
            notify("Base", string.format("Base pinned at (%.0f, %.0f, %.0f)",
                r.Position.X, r.Position.Y, r.Position.Z))
        else
            notify("Base", "No root part found.")
        end
    end,
})

T.TabPets:Section({ Title = "Debug" })

T.TabPets:Button({
    Title = "Dump Remote Data",
    Desc  = "Prints raw EggLive + EggSnapshot output to console so we can see the real data shape.",
    Callback = function()
        spawnLoop(function()
            notify("Debug", "Fetching remote data — check F9 console...", 4)

            -- Dump EggLive
            local live = callNet(R.EggLive)
            print("=== AskLiveSnapshot raw ===")
            print(typeof(live), live)
            if type(live) == "table" then
                for k, v in pairs(live) do
                    print("  KEY:", k, "TYPE:", typeof(v))
                    if type(v) == "table" then
                        for k2, v2 in pairs(v) do
                            print("    ", k2, "=", typeof(v2), tostring(v2):sub(1,80))
                        end
                    end
                end
            end

            -- Dump EggSnapshot
            local snap = callNet(R.EggSnapshot)
            print("=== AskFieldEggSnapshot raw ===")
            print(typeof(snap), snap)
            if type(snap) == "table" then
                local recs = snap.Records or snap.Eggs or snap
                if type(recs) == "table" then
                    local count = 0
                    for _, rec in pairs(recs) do
                        count = count + 1
                        if count <= 5 then  -- print first 5 only
                            print("  REC:", typeof(rec))
                            if type(rec) == "table" then
                                for k, v in pairs(rec) do
                                    print("    ", k, "=", tostring(v):sub(1,60))
                                end
                            end
                        end
                    end
                    print("  Total records:", count)
                end
            end

            notify("Debug", "Done — check F9 console for raw output.", 4)
        end)
    end,
})

-- ── Sky ───────────────────────────────────────────
local Lighting   = game:GetService("Lighting")
local skyboxId   = ""
local textureId  = ""
local texConn    = nil   -- DescendantAdded connection for live texture apply

local function applyTextureToAllSides(part)
    if not part:IsA("BasePart") then return end
    for _, ch in ipairs(part:GetChildren()) do
        if ch:IsA("Texture") then ch:Destroy() end
    end
    for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
        local tex     = Instance.new("Texture")
        tex.Texture   = textureId
        tex.Face      = face
        tex.Parent    = part
    end
end

local function removeSkybox()
    for _, ch in ipairs(Lighting:GetChildren()) do
        if ch:IsA("Sky") then ch:Destroy() end
    end
end

-- ── Sky UI ────────────────────────────────────────
T.SecSky     = T.Window:Section({ Title = "SKY", Opened = true })

-- Skybox tab
T.TabSkybox  = T.SecSky:Tab({ Title = "Skybox", Icon = "image" })

T.TabSkybox:Section({ Title = "Custom Skybox" })

T.TabSkybox:Input({
    Title       = "Skybox Asset ID",
    Desc        = "Enter the numeric asset ID — applied to all 6 faces",
    Placeholder = "e.g. 159304684",
    Callback    = function(v)
        skyboxId = "rbxassetid://" .. (v or "")
    end,
})

T.TabSkybox:Button({
    Title    = "Set Skybox",
    Desc     = "Applies the entered ID to a new Sky instance in Lighting",
    Color    = Color3.fromHex("#305dff"),
    Callback = function()
        if skyboxId == "" or skyboxId == "rbxassetid://" then
            notify("Skybox", "❌ Asset ID is empty — enter a number first.")
            return
        end
        removeSkybox()
        local sky        = Instance.new("Sky")
        sky.Name         = "CustomSkybox"
        sky.SkyboxBk     = skyboxId
        sky.SkyboxDn     = skyboxId
        sky.SkyboxFt     = skyboxId
        sky.SkyboxLf     = skyboxId
        sky.SkyboxRt     = skyboxId
        sky.SkyboxUp     = skyboxId
        sky.Parent       = Lighting
        notify("Skybox", "✅ Skybox set!")
    end,
})

T.TabSkybox:Button({
    Title    = "Remove Skybox",
    Desc     = "Deletes any custom Sky object from Lighting",
    Color    = Color3.fromHex("#FF4830"),
    Callback = function()
        removeSkybox()
        notify("Skybox", "Skybox removed.")
    end,
})

-- Textures tab
T.TabTex = T.SecSky:Tab({ Title = "Textures", Icon = "layers" })

T.TabTex:Section({ Title = "Workspace Texture" })

T.TabTex:Input({
    Title       = "Texture Asset ID",
    Desc        = "Enter the numeric asset ID to apply to every BasePart",
    Placeholder = "e.g. 1234567890",
    Callback    = function(v)
        textureId = "rbxassetid://" .. (v or "")
    end,
})

T.TabTex:Button({
    Title    = "Apply Texture",
    Desc     = "Applies the texture to all current and future BaseParts",
    Color    = Color3.fromHex("#305dff"),
    Callback = function()
        if textureId == "" or textureId == "rbxassetid://" then
            notify("Texture", "❌ Asset ID is empty — enter a number first.")
            return
        end
        -- Apply to all existing parts
        for _, part in ipairs(workspace:GetDescendants()) do
            pcall(applyTextureToAllSides, part)
        end
        -- Apply to any parts added later
        if texConn then texConn:Disconnect() end
        texConn = workspace.DescendantAdded:Connect(function(d)
            pcall(applyTextureToAllSides, d)
        end)
        notify("Texture", "✅ Texture applied to all parts!")
    end,
})

T.TabTex:Button({
    Title    = "Remove All Textures",
    Desc     = "Deletes every Texture instance from all BaseParts",
    Color    = Color3.fromHex("#FF4830"),
    Callback = function()
        if texConn then texConn:Disconnect(); texConn = nil end
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") then
                for _, ch in ipairs(part:GetChildren()) do
                    if ch:IsA("Texture") then ch:Destroy() end
                end
            end
        end
        notify("Texture", "All textures removed.")
    end,
})



-- ── Startup ───────────────────────────────────────
task.spawn(function()
    if not charReady() then
        player.CharacterAdded:Wait()
        task.wait(0.7)
    end
    refreshEggs(true)
    if #A.areaOrder > 0 then
        sortAreas()
        rebuildAreaSet()
    end
end)

if not NET then
    notify("Shard Free", "Packages.Networking missing — remote place may not work.", 8)
else
    notify("Shard Free", "Loaded! " .. #A.areaOrder .. " areas found.", 5)
end

