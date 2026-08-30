-- ╔══════════════════════════════════════════════════════════╗
-- ║         BerriHub StrikeBorn — v3 Adaptive Parry         ║
-- ╚══════════════════════════════════════════════════════════╝
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenSvc   = game:GetService("TweenService")
local player     = players.LocalPlayer

-- ══════════════════════════════════════════════════════════════
-- CONSTANTS
-- ══════════════════════════════════════════════════════════════
local HIST_MAX    = 40      -- rolling interval history per enemy
local DECAY       = 0.88    -- per-step weight decay (older = lighter)
local CONF_THRESH = 0.62    -- min confidence to switch response
local SHIFT_SENS  = 0.30    -- variance spike that resets confidence
local WIN_MIN     = 0.05
local WIN_MAX     = 0.48
local PARRY_CD    = 0.18    -- global parry cooldown (prevent double-fire)
local PHASE_WIN   = 1.8     -- seconds window to detect attack phase

-- ══════════════════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════════════════
local State = {
    AutoParry=false, ParryOnHit=false, ParryOnProj=false,
    PerfectParry=false, PPWindow=0.12,
    ParryRelease=true, ReleaseDelay=0.22, AutoReParry=true,
    RageParry=false, RageRate=0.04,
    ParryOnCombo=false, ComboThreshold=2,
    AutoCounter=false, CounterDelay=0.10,
    StaminaGuard=false, StaminaMin=20, StaminaMax=80,
    M1Parry=false, GBProtect=false, GBWindow=0.08,
    Adaptive=false, AdaptTiming=true, AdaptResponse=true,
    FrameParry=false,
    ESP=false, ProxRange=15,
    ParryCount=0, PerfectCount=0, CounterCount=0,
    DodgeCount=0, SessionStart=os.clock(),
}

-- ══════════════════════════════════════════════════════════════
-- ADAPTIVE ENGINE v3
-- ══════════════════════════════════════════════════════════════
local AdaptDB = {}
-- phases: "opener"=first hit of a string, "combo"=rapid follow-ups, "finisher"=slowdown after combo
-- response matrix per phase per dominant type
local RESPONSE_MATRIX = {
    m1    = { opener="parry",   combo="parry",   finisher="counter" },
    proj  = { opener="dodge",   combo="dodge",   finisher="parry"   },
    combo = { opener="parry",   combo="counter", finisher="dodge"   },
    unknown={ opener="parry",   combo="parry",   finisher="parry"   },
}

local function getDB(name)
    if not AdaptDB[name] then
        AdaptDB[name] = {
            -- timing
            lastHit=nil, intervals={}, weights={},
            avgInterval=nil, variance=nil, prevVariance=nil,
            tunedWindow=State.PPWindow, erratic=false,
            -- type
            types={m1=0,proj=0,combo=0}, typeTotal=0,
            dominant="unknown", confidence=0,
            -- phase
            hitTimes={}, phase="opener",
            -- meta
            totalHits=0, shiftDetected=false,
        }
    end
    return AdaptDB[name]
end

-- detect phase from recent hit pattern
local function detectPhase(db)
    local now = os.clock()
    -- prune hitTimes to PHASE_WIN
    local pruned = {}
    for _,t in ipairs(db.hitTimes) do if now-t < PHASE_WIN then pruned[#pruned+1]=t end end
    db.hitTimes = pruned
    local n = #pruned
    if n == 0 then return "opener" end
    -- rapid succession = combo; slowing down after 3+ = finisher
    if n >= 3 then
        local recent = pruned[n] - pruned[n-2]
        if recent < 0.6 then return "combo" end
        if recent > 1.2 then return "finisher" end
    end
    return n == 1 and "opener" or "combo"
end

local function adaptRecord(name, atype)
    local db  = getDB(name)
    local now = os.clock()
    db.totalHits = db.totalHits + 1
    table.insert(db.hitTimes, now)

    -- ── phase ──
    db.phase = detectPhase(db)

    -- ── timing ──
    if db.lastHit then
        local gap = now - db.lastHit
        if gap > 0.04 and gap < 7 then
            table.insert(db.intervals, gap)
            table.insert(db.weights,   1.0)
            if #db.intervals > HIST_MAX then
                table.remove(db.intervals,1); table.remove(db.weights,1)
            end
            -- decay weighting
            local wsum,wval = 0,0
            for i=#db.weights,1,-1 do
                db.weights[i] = DECAY^(#db.weights-i)
                wsum = wsum + db.weights[i]
                wval = wval + db.intervals[i]*db.weights[i]
            end
            db.avgInterval = wsum>0 and (wval/wsum) or gap

            -- variance
            local vsum=0
            for i,v in ipairs(db.intervals) do
                vsum = vsum + db.weights[i]*(v-db.avgInterval)^2
            end
            local newVar = wsum>0 and (vsum/wsum) or 0

            -- pattern shift detection — sudden variance spike resets confidence
            if db.prevVariance and newVar > db.prevVariance*2.2 and newVar > SHIFT_SENS then
                db.confidence   = db.confidence * 0.4  -- erode, don't zero
                db.shiftDetected= true
            else
                db.shiftDetected= false
            end
            db.prevVariance = newVar
            db.variance     = newVar
            db.erratic      = newVar > 0.12

            -- tune window
            local norm = math.clamp((db.avgInterval-0.22)/(3.0-0.22),0,1)
            local base  = WIN_MIN + norm*(WIN_MAX-WIN_MIN)
            -- erratic buffer + finisher bonus (finishers are slower, wider window ok)
            local bonus = (db.erratic and 0.05 or 0) + (db.phase=="finisher" and 0.03 or 0)
            db.tunedWindow = math.clamp(base+bonus, WIN_MIN, WIN_MAX)
        end
    end
    db.lastHit = now

    -- ── type ──
    if atype and db.types[atype] then
        db.types[atype] = db.types[atype]+1
        db.typeTotal    = db.typeTotal+1
    end
    local best,bestN="unknown",-1
    for t,n in pairs(db.types) do if n>bestN then best,bestN=t,n end end
    db.dominant   = bestN>0 and best or "unknown"
    -- confidence grows with sample size, eroded on shift
    db.confidence = db.typeTotal>0 and math.min(1, (bestN/db.typeTotal)*(1-1/(db.typeTotal+1))) or 0
end

local function adaptedWindow(name)
    local db=AdaptDB[name]
    return (db and State.AdaptTiming and db.tunedWindow) or State.PPWindow
end

local function adaptedResponse(name)
    if not State.AdaptResponse then return "parry" end
    local db=AdaptDB[name]
    if not db or db.confidence < CONF_THRESH then return "parry" end
    local mat = RESPONSE_MATRIX[db.dominant] or RESPONSE_MATRIX["unknown"]
    return mat[db.phase] or "parry"
end

-- ══════════════════════════════════════════════════════════════
-- FRAME PARRY DB
-- animId → { frames={parryAt=number, label=string}, ... }
-- multiple parry points per animation supported
-- ══════════════════════════════════════════════════════════════
local FrameDB     = {}   -- { [animId] = { frames={...}, label="" } }
local LoggedAnims = {}
local PreviewTrack= nil
local makerAnimId = ""
local makerLabel  = ""
local makerParryAt= 0.20

local function frameDBAddFrame(animId, parryAt, label)
    if not FrameDB[animId] then
        FrameDB[animId] = { frames={}, label=label or animId }
    end
    -- dedupe within 0.05s
    for _,f in ipairs(FrameDB[animId].frames) do
        if math.abs(f.parryAt - parryAt) < 0.05 then f.parryAt=parryAt; return end
    end
    table.insert(FrameDB[animId].frames, { parryAt=parryAt, label=label or ("frame@"..parryAt) })
    table.sort(FrameDB[animId].frames, function(a,b) return a.parryAt<b.parryAt end)
end

local function frameDBExport()
    local out = {}
    for id, entry in pairs(FrameDB) do
        local frames={}
        for _,f in ipairs(entry.frames) do
            frames[#frames+1] = f.parryAt
        end
        out[#out+1] = id.."=["..table.concat(frames,",").."]"
    end
    return table.concat(out, ";")
end

local function frameDBImport(str)
    for pair in str:gmatch("[^;]+") do
        local id, rest = pair:match("^(%d+)=%[(.-)%]$")
        if id and rest then
            for ts in rest:gmatch("[^,]+") do
                local t = tonumber(ts)
                if t then frameDBAddFrame(id, t) end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════
local Threads     = {}
local ESPObjects  = {}
local ComboLog    = {}
local isParrying  = false
local lastParryT  = 0
local Camera      = workspace.CurrentCamera

-- Delta-safe thread management via kill flags (task.cancel not supported)
local KillFlags = {}
local function killThread(n)
    KillFlags[n] = true
    Threads[n]   = nil
    task.delay(0.15, function() KillFlags[n] = nil end)
end
local function alive(n) return not KillFlags[n] end
local function findRemote(...)
    local pats={...}
    for _,d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local low=d.Name:lower()
            for _,p in ipairs(pats) do if low:find(p,1,true) then return d end end
        end
    end
end
local function getRoot(p) local c=(p or player).Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p)  local c=(p or player).Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getStamina()
    local c=player.Character; if not c then return 100 end
    for _,n in ipairs({"Stamina","Guard","Parry","BlockStamina","Energy"}) do
        local v=c:FindFirstChild(n); if v and v:IsA("NumberValue") then return v.Value end
        local a=c:GetAttribute(n); if a then return a end
    end; return 100
end
local function nearestEnemy()
    local root=getRoot(player); if not root then return nil,math.huge end
    local cl,cd=nil,math.huge
    for _,p in ipairs(players:GetPlayers()) do
        if p~=player and p.Character then
            local er=p.Character:FindFirstChild("HumanoidRootPart")
            if er then local d=(er.Position-root.Position).Magnitude
                if d<cd then cl,cd=p,d end end
        end
    end; return cl,cd
end
local function nearestEnemyDist() local _,d=nearestEnemy(); return d end

-- ══════════════════════════════════════════════════════════════
-- ACTIONS
-- ══════════════════════════════════════════════════════════════
local function engageParry()
    local now=os.clock()
    if isParrying or (now-lastParryT)<PARRY_CD then return end
    isParrying=true; lastParryT=now; State.ParryCount+=1
    local rem=findRemote("parry","deflect","block","guard","counter","reflect","dodge")
    if rem then
        pcall(function() rem:FireServer() end)
        pcall(function() rem:FireServer(true) end)
        pcall(function() rem:FireServer("parry") end)
        pcall(function() rem:FireServer(1) end)
    end
end
local function releaseParry()
    if not isParrying then return end; isParrying=false
    local rem=findRemote("parry","deflect","block","guard","counter","reflect","dodge")
    if rem then
        pcall(function() rem:FireServer(false) end)
        pcall(function() rem:FireServer(0) end)
    end
end
local function doDodge()
    State.DodgeCount+=1
    local rem=findRemote("dodge","roll","evade","dash","sidestep")
    if rem then pcall(function() rem:FireServer() end) end
end
local function doCounter()
    State.CounterCount+=1
    local rem=findRemote("counter","retaliate","punish","revenge","riposte")
    if rem then pcall(function() rem:FireServer() end); pcall(function() rem:FireServer(true) end) end
end

local function adaptiveRespond(name, window)
    local resp=adaptedResponse(name)
    if resp=="dodge" then
        doDodge()
    elseif resp=="counter" then
        engageParry()
        task.delay(window or State.ReleaseDelay,function()
            releaseParry(); task.delay(State.CounterDelay,doCounter)
        end)
    else
        engageParry()
        if State.ParryRelease then
            task.delay(window or State.ReleaseDelay,function()
                releaseParry()
                if State.AutoReParry and (State.AutoParry or State.ParryOnProj) then
                    task.delay(0.05,engageParry)
                end
            end)
        end
    end
end

local function parryThenRelease(name)
    if nearestEnemyDist()>State.ProxRange then return end
    if State.Adaptive and name then
        adaptiveRespond(name, adaptedWindow(name))
    else
        engageParry()
        if State.ParryRelease then
            task.delay(State.ReleaseDelay,function()
                releaseParry()
                if State.AutoReParry and (State.AutoParry or State.ParryOnProj) then
                    task.delay(0.05,engageParry)
                end
            end)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- FRAME PARRY ENGINE
-- per-track goroutine; supports multiple parry frames per anim
-- ══════════════════════════════════════════════════════════════
local function startFrameParry()
    killThread("frame")
    Threads["frame"]=task.spawn(function()
            local _tname="frame"
        local watching = {}  -- trackRef → {nextIdx=int}
        while (not KillFlags[_tname]) and (State.FrameParry) do
            if nearestEnemyDist() <= State.ProxRange then
                for _,p in ipairs(players:GetPlayers()) do
                    if p~=player and p.Character then
                        local hum=getHum(p)
                        local animator=hum and hum:FindFirstChildOfClass("Animator")
                        if animator then
                            for _,tr in ipairs(animator:GetPlayingAnimationTracks()) do
                                local id=(tr.Animation.AnimationId:match("%d+") or "")
                                local entry=FrameDB[id]
                                if entry and #entry.frames>0 then
                                    if not watching[tr] then
                                        watching[tr]={nextIdx=1}
                                        -- spawn dedicated watcher per track
                                        task.spawn(function()
                                            local state=watching[tr]
                                            while tr and tr.IsPlaying and State.FrameParry do
                                                local idx=state.nextIdx
                                                if idx > #entry.frames then
                                                    task.wait(0.05); break
                                                end
                                                local target=entry.frames[idx].parryAt
                                                if tr.TimePosition >= target then
                                                    local en,_=nearestEnemy()
                                                    parryThenRelease(en and en.Name)
                                                    state.nextIdx=idx+1
                                                end
                                                task.wait(0.01)
                                            end
                                            watching[tr]=nil
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                -- clean dead tracks
                for tr in pairs(watching) do
                    if not(tr and tr.IsPlaying) then watching[tr]=nil end
                end
            end
            task.wait(0.05)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- ANIMATION LOGGER (live ScreenGui list)
-- ══════════════════════════════════════════════════════════════
local logGui = Instance.new("ScreenGui")
logGui.Name="BerriAnimLog"; logGui.ResetOnSpawn=false
logGui.IgnoreGuiInset=true; logGui.ZIndexBehavior=Enum.ZIndexBehavior.Global
logGui.Enabled=false; pcall(function() logGui.Parent = game:GetService("CoreGui") end)

local logFrame=Instance.new("Frame")
logFrame.Size=UDim2.new(0,310,0,340); logFrame.Position=UDim2.new(1,-320,0.5,-170)
logFrame.BackgroundColor3=Color3.fromRGB(14,14,14)
logFrame.BackgroundTransparency=0.15; logFrame.BorderSizePixel=0; logFrame.Parent=logGui
Instance.new("UICorner",logFrame).CornerRadius=UDim.new(0,10)

local logTitle=Instance.new("TextLabel")
logTitle.Size=UDim2.new(1,0,0,28); logTitle.BackgroundTransparency=1
logTitle.Text="📋 Anim Logger"; logTitle.TextColor3=Color3.fromRGB(255,180,80)
logTitle.Font=Enum.Font.GothamBold; logTitle.TextSize=14; logTitle.Parent=logFrame

local logScroll=Instance.new("ScrollingFrame")
logScroll.Size=UDim2.new(1,-8,1,-36); logScroll.Position=UDim2.new(0,4,0,30)
logScroll.BackgroundTransparency=1; logScroll.ScrollBarThickness=4
logScroll.CanvasSize=UDim2.new(0,0,0,0); logScroll.Parent=logFrame
local logList=Instance.new("UIListLayout")
logList.SortOrder=Enum.SortOrder.LayoutOrder; logList.Padding=UDim.new(0,3)
logList.Parent=logScroll

local function refreshLogGui()
    -- clear
    for _,c in ipairs(logScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    refreshAnimLog and refreshAnimLog()
    if #LoggedAnims==0 then
        local lbl=Instance.new("TextLabel")
        lbl.Size=UDim2.new(1,0,0,22); lbl.BackgroundTransparency=1
        lbl.Text="No anims detected."; lbl.TextColor3=Color3.fromRGB(180,180,180)
        lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.Parent=logScroll
        return
    end
    for i,entry in ipairs(LoggedAnims) do
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,42); row.BackgroundColor3=Color3.fromRGB(25,25,25)
        row.BackgroundTransparency=0.3; row.BorderSizePixel=0; row.LayoutOrder=i; row.Parent=logScroll
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

        local saved=FrameDB[entry.id] and " ✓" or ""
        local info=Instance.new("TextLabel")
        info.Size=UDim2.new(1,-70,1,0); info.Position=UDim2.new(0,6,0,0)
        info.BackgroundTransparency=1
        info.Text=string.format("%s%s\nID:%s  %.2fs", entry.name, saved, entry.id, entry.pos)
        info.TextColor3=Color3.fromRGB(220,220,220); info.Font=Enum.Font.GothamBold
        info.TextSize=11; info.TextXAlignment=Enum.TextXAlignment.Left
        info.TextYAlignment=Enum.TextYAlignment.Center; info.Parent=row

        -- "→ Maker" button per row
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(0,58,0,28); btn.Position=UDim2.new(1,-64,0.5,-14)
        btn.BackgroundColor3=Color3.fromRGB(48,93,255)
        btn.Text="→ Make"; btn.TextColor3=Color3.fromRGB(255,255,255)
        btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.Parent=row
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
        btn.MouseButton1Click:Connect(function()
            makerAnimId=entry.id; makerLabel=entry.name
            WindUI:Notify({Title="Anim Logger",Content="Loaded "..entry.id.." → Maker",Duration=2})
        end)
    end
    -- resize canvas
    logScroll.CanvasSize=UDim2.new(0,0,0,logList.AbsoluteContentSize.Y+6)
end

local logRunning=false
local function refreshAnimLog()
    local seen={}; LoggedAnims={}
    for _,p in ipairs(players:GetPlayers()) do
        if p~=player and p.Character then
            local hum=getHum(p)
            local anim=hum and hum:FindFirstChildOfClass("Animator")
            if anim then
                for _,tr in ipairs(anim:GetPlayingAnimationTracks()) do
                    local id=tr.Animation.AnimationId:match("%d+") or tr.Animation.AnimationId
                    if not seen[id] then
                        seen[id]=true
                        table.insert(LoggedAnims,{id=id,name=tr.Name,
                            pos=tr.TimePosition,enemy=p.Name,track=tr})
                    end
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- STANDARD LOOPS
-- ══════════════════════════════════════════════════════════════
local function startThreatWatch()
    killThread("threat")
    Threads["threat"]=task.spawn(function()
            local _tname="threat"
        while (not KillFlags[_tname]) and (State.ParryOnProj) do
            local root=getRoot(player)
            if root then
                for _,obj in ipairs(workspace:GetDescendants()) do
                    local n=obj.Name:lower()
                    if n:find("attack",1,true) or n:find("proj",1,true) or n:find("hitbox",1,true)
                    or n:find("slash",1,true) or n:find("blast",1,true) or n:find("strike",1,true) then
                        local part=obj:IsA("BasePart") and obj
                            or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")))
                        if part and (part.Position-root.Position).Magnitude<20 then
                            local en,_=nearestEnemy()
                            if State.Adaptive and en then adaptRecord(en.Name,"proj") end
                            parryThenRelease(en and en.Name)
                        end
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end

local function startOnHit()
    killThread("onhit")
    Threads["onhit"]=task.spawn(function()
            local _tname="onhit"
        local function attach(char)
            local hum=char:WaitForChild("Humanoid",10); if not hum then return end
            local prev=hum.Health
            local conn=hum.HealthChanged:Connect(function(hp)
                if hp<prev and State.ParryOnHit and nearestEnemyDist()<=State.ProxRange then
                    local en,_=nearestEnemy()
                    if State.Adaptive and en then
                        local db=AdaptDB[en.Name]
                        adaptRecord(en.Name,(db and db.dominant~="unknown") and db.dominant or "m1")
                    end
                    parryThenRelease(en and en.Name)
                end
                prev=hp
            end)
            while (not KillFlags[_tname]) and (State.ParryOnHit) and hum.Parent do task.wait(0.1) end
            pcall(conn.Disconnect,conn)
        end
        attach(player.Character or player.CharacterAdded:Wait())
        local respawn=player.CharacterAdded:Connect(function(c) attach(c) end)
        while (not KillFlags[_tname]) and (State.ParryOnHit) do task.wait(0.5) end
        pcall(respawn.Disconnect,respawn)
    end)
end

local function startComboWatch()
    killThread("combo")
    Threads["combo"]=task.spawn(function()
            local _tname="combo"
        local function attach(char)
            local hum=char:WaitForChild("Humanoid",10); if not hum then return end
            local prev=hum.Health
            local conn=hum.HealthChanged:Connect(function(hp)
                if hp<prev and State.ParryOnCombo and nearestEnemyDist()<=State.ProxRange then
                    local t=os.clock(); ComboLog.__g=ComboLog.__g or {}
                    table.insert(ComboLog.__g,t)
                    local pruned={}
                    for _,v in ipairs(ComboLog.__g) do if t-v<1.5 then pruned[#pruned+1]=v end end
                    ComboLog.__g=pruned
                    if #pruned>=State.ComboThreshold then
                        local en,_=nearestEnemy()
                        if State.Adaptive and en then adaptRecord(en.Name,"combo") end
                        parryThenRelease(en and en.Name); ComboLog.__g={}
                    end
                end
                prev=hp
            end)
            while (not KillFlags[_tname]) and (State.ParryOnCombo) and hum.Parent do task.wait(0.1) end
            pcall(conn.Disconnect,conn)
        end
        attach(player.Character or player.CharacterAdded:Wait())
        local respawn=player.CharacterAdded:Connect(function(c) attach(c) end)
        while (not KillFlags[_tname]) and (State.ParryOnCombo) do task.wait(0.5) end
        pcall(respawn.Disconnect,respawn)
    end)
end

local function startStaminaLoop()
    killThread("stamina")
    Threads["stamina"]=task.spawn(function()
            local _tname="stamina"
        while (not KillFlags[_tname]) and (State.StaminaGuard) do
            local s=getStamina()
            if s<=State.StaminaMin and isParrying then releaseParry()
            elseif s>=State.StaminaMax and not isParrying
                   and (State.AutoParry or State.ParryOnProj) then engageParry() end
            task.wait(0.1)
        end
    end)
end

local function startGBProtect()
    killThread("gb")
    Threads["gb"]=task.spawn(function()
            local _tname="gb"
        local gbRem
        while (not KillFlags[_tname]) and (State.GBProtect) do
            gbRem=gbRem or findRemote("guardbreak","gb","breakguard","parrybreak","break")
            if gbRem then
                local conn=gbRem.OnClientEvent:Connect(function()
                    if not(State.GBProtect and isParrying) then return end
                    releaseParry()
                    task.delay(State.GBWindow+0.05,function()
                        if State.GBProtect and (State.AutoParry or State.ParryOnProj) then engageParry() end
                    end)
                end)
                while (not KillFlags[_tname]) and (State.GBProtect) do task.wait(1) end
                pcall(conn.Disconnect,conn); break
            end; task.wait(1)
        end
    end)
end

local function startRageParry()
    killThread("rage")
    Threads["rage"]=task.spawn(function()
            local _tname="rage"
        while (not KillFlags[_tname]) and (State.RageParry) do
            engageParry(); task.wait(State.RageRate)
            releaseParry(); task.wait(State.RageRate)
        end; releaseParry()
    end)
end

local function startM1Parry()
    killThread("m1")
    Threads["m1"]=task.spawn(function()
            local _tname="m1"
        while (not KillFlags[_tname]) and (State.M1Parry) do
            local root=getRoot(player)
            if root then
                for _,p in ipairs(players:GetPlayers()) do
                    if p~=player and p.Character then
                        local er=getRoot(p)
                        if er and (er.Position-root.Position).Magnitude<=State.ProxRange then
                            local hum=getHum(p)
                            local anim=hum and hum:FindFirstChildOfClass("Animator")
                            if anim then
                                for _,tr in ipairs(anim:GetPlayingAnimationTracks()) do
                                    local n=tr.Name:lower()
                                    if n:find("attack",1,true) or n:find("punch",1,true)
                                    or n:find("swing",1,true) or n:find("m1",1,true)
                                    or n:find("slash",1,true) or n:find("strike",1,true) then
                                        if State.Adaptive then adaptRecord(p.Name,"m1") end
                                        parryThenRelease(p.Name); break
                                    end
                                end
                            end
                        end
                    end
                end
            end; task.wait(0.05)
        end
    end)
end

local function startPerfectParry()
    killThread("perfect")
    Threads["perfect"]=task.spawn(function()
            local _tname="perfect"
        while (not KillFlags[_tname]) and (State.PerfectParry) do
            local root=getRoot(player)
            if root then
                for _,obj in ipairs(workspace:GetDescendants()) do
                    local n=obj.Name:lower()
                    if n:find("attack",1,true) or n:find("proj",1,true)
                    or n:find("hitbox",1,true) or n:find("strike",1,true) then
                        local part=obj:IsA("BasePart") and obj
                            or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")))
                        if part then
                            local speed=part.AssemblyLinearVelocity.Magnitude
                            local dist=(part.Position-root.Position).Magnitude
                            if speed>1 then
                                local eta=dist/speed
                                local en,_=nearestEnemy()
                                local win=(State.Adaptive and en) and adaptedWindow(en.Name) or State.PPWindow
                                if eta<=win and eta>0 then
                                    task.delay(math.max(0,eta-0.05),function()
                                        if State.PerfectParry then
                                            engageParry(); State.PerfectCount+=1
                                            task.delay(0.15,releaseParry)
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end; task.wait(0.05)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════════════════════════
local function clearESP()
    for _,e in ipairs(ESPObjects) do pcall(function() e.bill:Destroy() end) end; ESPObjects={}
end
local function startESPLoop()
    killThread("esp")
    Threads["esp"]=task.spawn(function()
            local _tname="esp"
        while (not KillFlags[_tname]) and (State.ESP) do
            clearESP()
            local root=getRoot(player)
            for _,p in ipairs(players:GetPlayers()) do
                if p~=player and p.Character then
                    local er=getRoot(p)
                    if er and root then
                        local dist=(er.Position-root.Position).Magnitude
                        local threat=dist<15 and "CLOSE" or dist<35 and "MID" or "FAR"
                        local col=dist<15 and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,220,255)
                        local db=AdaptDB[p.Name]
                        local adapt=""
                        if db and State.Adaptive then
                            local conf=math.floor((db.confidence or 0)*100)
                            local win=string.format("%.2f",db.tunedWindow or State.PPWindow)
                            local errat=db.erratic and "⚡" or "〰"
                            local shift=db.shiftDetected and " ⚠" or ""
                            adapt=string.format("\n%s%s [%s %d%% w:%ss | %s]",
                                errat,shift,db.dominant,conf,win,db.phase or "?")
                        end
                        local bb=Instance.new("BillboardGui")
                        bb.Size=UDim2.new(0,175,0,State.Adaptive and 58 or 40)
                        bb.StudsOffset=Vector3.new(0,5.5,0)
                        bb.AlwaysOnTop=true; bb.Adornee=er; bb.Parent=workspace
                        local lbl=Instance.new("TextLabel")
                        lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
                        lbl.Text=p.Name.." | "..threat.." | "..math.floor(dist).."st"..adapt
                        lbl.TextColor3=col; lbl.TextStrokeTransparency=0
                        lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11; lbl.Parent=bb
                        ESPObjects[#ESPObjects+1]={bill=bb}
                    end
                end
            end; task.wait(0.8)
        end; clearESP()
    end)
end

-- ══════════════════════════════════════════════════════════════
-- HUD
-- ══════════════════════════════════════════════════════════════
local hudGui=Instance.new("ScreenGui")
hudGui.Name="BerriSBHUD"; hudGui.ResetOnSpawn=false
hudGui.IgnoreGuiInset=true; hudGui.ZIndexBehavior=Enum.ZIndexBehavior.Global
pcall(function() hudGui.Parent = game:GetService("CoreGui") end)

local hudFrame=Instance.new("Frame")
hudFrame.Size=UDim2.new(0,200,0,88); hudFrame.Position=UDim2.new(0,8,1,-98)
hudFrame.BackgroundColor3=Color3.fromRGB(12,12,12)
hudFrame.BackgroundTransparency=0.28; hudFrame.BorderSizePixel=0; hudFrame.Parent=hudGui
Instance.new("UICorner",hudFrame).CornerRadius=UDim.new(0,8)

local hudLabel=Instance.new("TextLabel")
hudLabel.Size=UDim2.new(1,-8,1,-6); hudLabel.Position=UDim2.new(0,6,0,4)
hudLabel.BackgroundTransparency=1; hudLabel.TextColor3=Color3.fromRGB(255,180,80)
hudLabel.Font=Enum.Font.GothamBold; hudLabel.TextSize=11
hudLabel.TextXAlignment=Enum.TextXAlignment.Left
hudLabel.TextYAlignment=Enum.TextYAlignment.Top; hudLabel.Parent=hudFrame

RunService.RenderStepped:Connect(function()
    local e=math.floor(os.clock()-State.SessionStart)
    local en,_=nearestEnemy()
    local aline=""
    if State.Adaptive and en then
        local db=AdaptDB[en.Name]
        if db and db.avgInterval then
            local conf=math.floor((db.confidence or 0)*100)
            aline=string.format("\n%s [%s|%d%%|%s|%.2fs]",
                en.Name,db.dominant,conf,db.phase or "?",db.tunedWindow or State.PPWindow)
        end
    end
    hudLabel.Text=string.format(
        "Berri SB v3\nParry:%d Perf:%d\nCtr:%d Dge:%d %02d:%02d%s",
        State.ParryCount,State.PerfectCount,
        State.CounterCount,State.DodgeCount,
        math.floor(e/60),e%60,aline)
end)

-- ══════════════════════════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════════════════════════
local Window=WindUI:CreateWindow({
    Title="Berri Hub | StrikeBorn v3", Icon="solar:shield-bold-duotone",
    Folder="BerriSB", NewElements=true,
    OpenButton={
        Title="Berri SB", Enabled=true, Draggable=true, OnlyMobile=false,
        CornerRadius=UDim.new(1,0),
        Color=ColorSequence.new(Color3.fromHex("#FF8C00"),Color3.fromHex("#FF3CAC")),
    },
})

-- ── ADAPTIVE ──────────────────────────────────────────────────
local AdaptSec=Window:Section({Title="Adaptive"})
local AdaptTab=AdaptSec:Tab({Title="Adaptive Engine",Icon="solar:cpu-bold"})

AdaptTab:Toggle({Title="Enable Adaptive Mode",
    Desc="Phase-aware state machine: opener/combo/finisher × type = response",
    Callback=function(v) State.Adaptive=v end})
AdaptTab:Space()
AdaptTab:Toggle({Title="Adaptive Timing",
    Desc="Weighted decay avg + variance; erratic attackers get buffer; finishers widen",
    Callback=function(v) State.AdaptTiming=v end})
AdaptTab:Space()
AdaptTab:Toggle({Title="Adaptive Response",
    Desc="Switches parry/dodge/counter when confidence ≥62%; resets on pattern shift",
    Callback=function(v) State.AdaptResponse=v end})
AdaptTab:Space()
AdaptTab:Button({Title="Reset All Data",Color=Color3.fromHex("#FF4830"),
    Callback=function() AdaptDB={}
        WindUI:Notify({Title="Adaptive",Content="All enemy data cleared.",Duration=2}) end})
AdaptTab:Space()
AdaptTab:Button({Title="Reset Nearest Enemy",
    Callback=function()
        local en,_=nearestEnemy()
        if en then AdaptDB[en.Name]=nil
            WindUI:Notify({Title="Adaptive",Content="Cleared: "..en.Name,Duration=2})
        else WindUI:Notify({Title="Adaptive",Content="No enemy nearby.",Duration=2}) end
    end})

-- ── CORE PARRY ────────────────────────────────────────────────
local ParrySec=Window:Section({Title="Auto Parry"})
local CoreTab=ParrySec:Tab({Title="Core Parry",Icon="solar:shield-bold"})

CoreTab:Toggle({Title="Auto Parry (always on)",
    Callback=function(v) State.AutoParry=v; if v then engageParry() else releaseParry() end end})
CoreTab:Space()
CoreTab:Toggle({Title="Parry On Hit",
    Callback=function(v) State.ParryOnHit=v; if v then startOnHit() else killThread("onhit") end end})
CoreTab:Space()
CoreTab:Toggle({Title="Parry On Projectile",
    Callback=function(v) State.ParryOnProj=v; if v then startThreatWatch() else killThread("threat") end end})
CoreTab:Space()
CoreTab:Button({Title="Parry Now",Color=Color3.fromHex("#FF8C00"),Callback=engageParry})
CoreTab:Space()
CoreTab:Button({Title="Release Now",Color=Color3.fromHex("#FF4830"),Callback=releaseParry})

local TimingTab=ParrySec:Tab({Title="Timing",Icon="solar:clock-bold"})
TimingTab:Toggle({Title="Auto Release",Callback=function(v) State.ParryRelease=v end})
TimingTab:Space()
TimingTab:Slider({Title="Release Delay (s)",IsTooltip=true,Step=0.05,
    Value={Min=0.05,Max=2.0,Default=0.22},Callback=function(v) State.ReleaseDelay=v end})
TimingTab:Space()
TimingTab:Toggle({Title="Auto Re-Parry",Callback=function(v) State.AutoReParry=v end})
TimingTab:Space()
TimingTab:Toggle({Title="Perfect Parry",
    Callback=function(v) State.PerfectParry=v; if v then startPerfectParry() else killThread("perfect") end end})
TimingTab:Space()
TimingTab:Slider({Title="Perfect Window (s)",Desc="Per-enemy override when Adaptive is on",
    IsTooltip=true,Step=0.01,Value={Min=0.05,Max=0.5,Default=0.12},
    Callback=function(v) State.PPWindow=v end})

local RageTab=ParrySec:Tab({Title="Rage Parry",Icon="solar:danger-bold"})
RageTab:Toggle({Title="Enable Rage Parry",
    Callback=function(v) State.RageParry=v; if v then startRageParry() else killThread("rage") end end})
RageTab:Space()
RageTab:Slider({Title="Rage Rate (s)",IsTooltip=true,Step=0.01,
    Value={Min=0.01,Max=0.2,Default=0.04},Callback=function(v) State.RageRate=v end})

-- ── ADVANCED ──────────────────────────────────────────────────
local AdvSec=Window:Section({Title="Advanced"})
local ComboTab=AdvSec:Tab({Title="Combo & M1",Icon="solar:fire-bold"})
ComboTab:Toggle({Title="Parry On Combo",
    Callback=function(v) State.ParryOnCombo=v; if v then startComboWatch() else killThread("combo") end end})
ComboTab:Space()
ComboTab:Slider({Title="Combo Threshold",IsTooltip=true,Step=1,
    Value={Min=1,Max=5,Default=2},Callback=function(v) State.ComboThreshold=v end})
ComboTab:Space()
ComboTab:Toggle({Title="M1 Parry",
    Callback=function(v) State.M1Parry=v; if v then startM1Parry() else killThread("m1") end end})

local GBTab=AdvSec:Tab({Title="Break Protect",Icon="solar:shield-cross-bold"})
GBTab:Toggle({Title="Parry Break Protection",
    Callback=function(v) State.GBProtect=v; if v then startGBProtect() else killThread("gb") end end})
GBTab:Space()
GBTab:Slider({Title="Release Window (s)",IsTooltip=true,Step=0.01,
    Value={Min=0.02,Max=0.3,Default=0.08},Callback=function(v) State.GBWindow=v end})

local CtrTab=AdvSec:Tab({Title="Counter",Icon="solar:restart-bold"})
CtrTab:Toggle({Title="Auto Counter",Callback=function(v) State.AutoCounter=v end})
CtrTab:Space()
CtrTab:Slider({Title="Counter Delay (s)",IsTooltip=true,Step=0.01,
    Value={Min=0.0,Max=0.5,Default=0.10},Callback=function(v) State.CounterDelay=v end})

-- ── STAMINA ───────────────────────────────────────────────────
local StamSec=Window:Section({Title="Stamina"})
local StamTab=StamSec:Tab({Title="Stamina Guard",Icon="solar:battery-full-bold"})
StamTab:Toggle({Title="Enable Stamina Guard",
    Callback=function(v) State.StaminaGuard=v; if v then startStaminaLoop() else killThread("stamina") end end})
StamTab:Space()
StamTab:Slider({Title="Unblock Below",IsTooltip=true,Step=1,
    Value={Min=0,Max=50,Default=20},Callback=function(v) State.StaminaMin=v end})
StamTab:Space()
StamTab:Slider({Title="Re-Parry Above",IsTooltip=true,Step=1,
    Value={Min=50,Max=100,Default=80},Callback=function(v) State.StaminaMax=v end})

-- ── FRAME PARRY ───────────────────────────────────────────────
local FrameSec=Window:Section({Title="Frame Parry"})

-- Auto Parry (frame engine)
local FAutoTab=FrameSec:Tab({Title="Auto Parry",Icon="solar:play-bold"})
FAutoTab:Toggle({Title="Enable Frame Parry",
    Desc="Fires parry at saved frame timestamps when enemy plays a known anim",
    Callback=function(v)
        State.FrameParry=v
        if v then startFrameParry() else killThread("frame") end
    end})
FAutoTab:Space()
FAutoTab:Label({Title="Only fires within Proximity Range. Supports multiple frames per anim."})

-- Parry Maker
local FMakerTab=FrameSec:Tab({Title="Parry Maker",Icon="solar:pen-bold"})

FMakerTab:Input({Title="Animation ID",Placeholder="e.g. 123456789",
    Callback=function(v) makerAnimId=v:match("%d+") or v end})
FMakerTab:Space()
FMakerTab:Slider({Title="Parry At (seconds)",IsTooltip=true,Step=0.01,
    Value={Min=0.0,Max=5.0,Default=0.20},
    Callback=function(v) makerParryAt=v end})
FMakerTab:Space()
FMakerTab:Input({Title="Label (optional)",Placeholder="e.g. Heavy Slash",
    Callback=function(v) makerLabel=v end})
FMakerTab:Space()
FMakerTab:Button({Title="Preview Animation",Color=Color3.fromHex("#305dff"),
    Callback=function()
        if makerAnimId=="" then
            WindUI:Notify({Title="Parry Maker",Content="Enter an Animation ID first.",Duration=2}); return
        end
        local char=player.Character; if not char then return end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local anim=Instance.new("Animation")
        anim.AnimationId="rbxassetid://"..makerAnimId
        if PreviewTrack then pcall(function() PreviewTrack:Stop() end) end
        PreviewTrack=hum:LoadAnimation(anim); PreviewTrack:Play()
        WindUI:Notify({Title="Parry Maker",Content="Playing "..makerAnimId,Duration=3})
    end})
FMakerTab:Space()
FMakerTab:Button({Title="📍 Mark Frame NOW",Color=Color3.fromHex("#FF8C00"),
    Desc="Captures preview TimePosition as parry frame",
    Callback=function()
        if PreviewTrack and PreviewTrack.IsPlaying then
            makerParryAt=math.floor(PreviewTrack.TimePosition*100)/100
            WindUI:Notify({Title="Parry Maker",
                Content="Captured at "..makerParryAt.."s — click Add Frame.",Duration=3})
        else
            WindUI:Notify({Title="Parry Maker",Content="No preview playing.",Duration=2})
        end
    end})
FMakerTab:Space()
FMakerTab:Button({Title="Stop Preview",
    Callback=function()
        if PreviewTrack then pcall(function() PreviewTrack:Stop() end); PreviewTrack=nil end
    end})
FMakerTab:Space()
FMakerTab:Button({Title="Add Frame to Anim",Color=Color3.fromHex("#30FF6A"),
    Desc="Supports multiple frames per animation ID",
    Callback=function()
        if makerAnimId=="" then
            WindUI:Notify({Title="Parry Maker",Content="No Animation ID.",Duration=2}); return
        end
        frameDBAddFrame(makerAnimId, makerParryAt, makerLabel~="" and makerLabel or nil)
        local count=#FrameDB[makerAnimId].frames
        WindUI:Notify({Title="Parry Maker",
            Content="Added "..makerParryAt.."s → "..makerAnimId.." ("..count.." frames total)",Duration=3})
    end})
FMakerTab:Space()
FMakerTab:Button({Title="Clear This Anim",Color=Color3.fromHex("#FF4830"),
    Callback=function()
        if FrameDB[makerAnimId] then FrameDB[makerAnimId]=nil
            WindUI:Notify({Title="Parry Maker",Content="Deleted "..makerAnimId,Duration=2}) end
    end})
FMakerTab:Space()
FMakerTab:Button({Title="Clear All Frames",Color=Color3.fromHex("#FF4830"),
    Callback=function() FrameDB={}
        WindUI:Notify({Title="Parry Maker",Content="All frames cleared.",Duration=2}) end})
FMakerTab:Space()
FMakerTab:Button({Title="Export FrameDB (Notify)",
    Callback=function()
        local s=frameDBExport()
        if s=="" then WindUI:Notify({Title="Export",Content="FrameDB is empty.",Duration=2}); return end
        WindUI:Notify({Title="FrameDB Export",Content=s,Duration=8})
    end})
FMakerTab:Space()
FMakerTab:Input({Title="Import FrameDB",Placeholder="Paste export string here",
    Callback=function(v)
        frameDBImport(v)
        WindUI:Notify({Title="Import",Content="FrameDB imported.",Duration=2})
    end})

-- Anim Logger
local FLogTab=FrameSec:Tab({Title="Anim Logger",Icon="solar:list-bold"})

FLogTab:Toggle({Title="Enable Anim Logger",
    Desc="Live scrolling list of all anims playing on nearby enemies",
    Callback=function(v)
        logRunning=v; logGui.Enabled=v
        if v then
            killThread("animlog")
            Threads["animlog"]=task.spawn(function()
            local _tname="animlog"
                while (not KillFlags[_tname]) and (logRunning) do
                    refreshAnimLog(); refreshLogGui(); task.wait(0.3)
                end
                logGui.Enabled=false
            end)
        else killThread("animlog"); LoggedAnims={}; logGui.Enabled=false end
    end})
FLogTab:Space()
FLogTab:Label({Title="Logger panel appears on the right side of the screen."})
FLogTab:Space()
FLogTab:Button({Title="Send Top Anim → Maker",
    Callback=function()
        if #LoggedAnims>0 then
            makerAnimId=LoggedAnims[1].id; makerLabel=LoggedAnims[1].name
            WindUI:Notify({Title="Logger",Content="Loaded "..makerAnimId.." → Maker",Duration=2})
        else WindUI:Notify({Title="Logger",Content="Log empty.",Duration=2}) end
    end})
FLogTab:Space()
FLogTab:Button({Title="Clear Log",
    Callback=function() LoggedAnims={}; refreshLogGui() end})

-- ── VISUAL ────────────────────────────────────────────────────
local VisSec=Window:Section({Title="Visual"})
local ESPTab=VisSec:Tab({Title="Threat ESP",Icon="solar:eye-bold"})
ESPTab:Toggle({Title="Enable Threat ESP",
    Desc="Shows distance, threat, adaptive profile (type/confidence/phase/erratic)",
    Callback=function(v) State.ESP=v; if v then startESPLoop() else killThread("esp"); clearESP() end end})

-- ── SETTINGS ──────────────────────────────────────────────────
local SetTab=Window:Tab({Title="Settings",Icon="solar:settings-bold"})
SetTab:Section({Title="Session"})
SetTab:Slider({Title="Proximity Range (studs)",IsTooltip=true,Step=1,
    Value={Min=5,Max=50,Default=15},Callback=function(v) State.ProxRange=v end})
SetTab:Space()
SetTab:Slider({Title="Parry Cooldown (s)",IsTooltip=true,Step=0.01,
    Value={Min=0.05,Max=0.5,Default=0.18},
    Callback=function(v)
        -- reassign the upvalue via a wrapper since PARRY_CD is local const
        -- store in State for runtime access
        State._parryCd=v
    end})
SetTab:Space()
SetTab:Button({Title="Reset Stats",
    Callback=function()
        State.ParryCount=0; State.PerfectCount=0
        State.CounterCount=0; State.DodgeCount=0; State.SessionStart=os.clock()
        WindUI:Notify({Title="Berri SB",Content="Stats reset.",Duration=2})
    end})
SetTab:Space()
SetTab:Button({Title="Stop All",Color=Color3.fromHex("#FF4830"),
    Callback=function()
        for _,k in ipairs({"AutoParry","ParryOnHit","ParryOnProj","PerfectParry",
            "RageParry","ParryOnCombo","M1Parry","GBProtect","AutoCounter",
            "StaminaGuard","ESP","Adaptive","FrameParry"}) do State[k]=false end
        logRunning=false; logGui.Enabled=false
        for n in pairs(Threads) do killThread(n) end
        releaseParry(); clearESP()
        WindUI:Notify({Title="Berri SB",Content="All stopped.",Duration=3})
    end})
SetTab:Space()
SetTab:Button({Title="Destroy Hub",Color=Color3.fromHex("#FF4830"),Icon="solar:close-bold",
    Callback=function()
        for n in pairs(Threads) do killThread(n) end
        releaseParry(); clearESP()
        local hud=game:GetService("CoreGui"):FindFirstChild("BerriSBHUD")
        if hud then hud:Destroy() end
        logGui:Destroy(); Window:Destroy()
    end})

WindUI:Notify({Title="Berri Hub | SB v3",Content="Adaptive + Frame Parry loaded! ⚔️",Duration=5})
