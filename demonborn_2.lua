-- recovered from github.com/toeerolo-z/newworld
-- file: demonborn_2.lua | commit: 31ae910 | date: 2026-07-14 | 133,605 bytes


repeat task.wait() until game:IsLoaded()
task.wait(1)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- kill any previous instance before starting
if getgenv()._ZHUnload then pcall(getgenv()._ZHUnload); getgenv()._ZHUnload=nil end
pcall(function() local RS=game:GetService("RunService")
    for _,n in ipairs({"DBFly","DBSpeed","DBServerESP"}) do
        RS:UnbindFromRenderStep(n)
    end
end)

local RS  = game:GetService("RunService")
local PS  = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LT  = game:GetService("Lighting")
local HS  = game:GetService("HttpService")
local TP  = game:GetService("TeleportService")
local Cam = workspace.CurrentCamera
local LP  = PS.LocalPlayer

local function getChar() return LP.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- Shared container for ESP highlights — we own them, so corpses can't keep them
local _espHLContainer = Instance.new("Folder")
_espHLContainer.Name = "DBEspHighlights"
_espHLContainer.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local S = {
    speed=100, infJumpH=50, flySpeed=100, tweenSpeed=100,
    aimbotFOV=45, aimbotSens=1, aimbotX=0, aimbotY=0,
    aimbotMode="Toggle", aimbotActive=false, aimbotEnabled=false,
    aimbotMethod="Camera", targetPlayers=true, visibleOnly=false, teamCheck=false,
    brightness=2, freeCamSens=0.3, freeCamSpeed=0.5, fovVal=70,
    espDist=1000, espFontSize=14, tracerThick=2,
    espRainbow=false, hlFillTrans=0.5, hlOutlineTrans=0, espAntiLag=true,
}
_wFPS = 60

local _macSrc = game:HttpGet("https://raw.githubusercontent.com/troidnox/sorrynol/refs/heads/main/zeree")
local _macFn, _macErr = loadstring(_macSrc)
assert(_macFn, "[ZeroHub] MacLib syntax error: " .. tostring(_macErr))
local MacLib = _macFn()
assert(MacLib, "[ZeroHub] MacLib returned nil — runtime error during load")

local Window = MacLib:Window({
    Title    = "<font color=\"rgb(178,120,255)\">Zero</font> <font color=\"rgb(138,79,255)\">Hub</font>",
    Subtitle = "Demon Born  |  V.2.1",
    Image    = "rbxassetid://83109184888967",
    Size     = UDim2.fromOffset(980, 760),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = false,
    Keybind  = Enum.KeyCode.F5,
    AcrylicBlur = false,
})

local Opt = {}
local Tog = {}

local _cleanupFns = {}
local function onUnload(fn) table.insert(_cleanupFns, fn) end
Window.onUnloaded(function()
    for _, fn in ipairs(_cleanupFns) do pcall(fn) end
    getgenv()._ZHUnload=nil
end)
getgenv()._ZHUnload=function() Window:Unload() end

local function notify(msg, dur)
    task.defer(function()
        pcall(function() Window:Notify({ Title="Demon Born", Description=msg, Lifetime=dur or 3 }) end)
    end)
end
local TabGroup = Window:TabGroup()
local Tabs = {}
Tabs.Game      = TabGroup:Tab({ Name="Main",       Image="swords"             })
Tabs.Character = TabGroup:Tab({ Name="Character",  Image="person-standing"    })
Tabs.Visuals   = TabGroup:Tab({ Name="Visuals",    Image="scan-eye"           })
Tabs.World     = TabGroup:Tab({ Name="World",      Image="map"                })
Tabs.Nav       = TabGroup:Tab({ Name="Navigation", Image="navigation"         })
Tabs.Misc      = TabGroup:Tab({ Name="Misc",       Image="layers"             })
Tabs.Stats     = TabGroup:Tab({ Name="Stats",      Image="activity"           })
Tabs.Settings  = TabGroup:Tab({ Name="Settings",   Image="sliders-horizontal" })

local GameL   = Tabs.Game:Section({ Side="Left",  Name="Player Farm",    Image="users"             })
local GameL2  = Tabs.Game:Section({ Side="Left",  Name="Mob Farm",       Image="swords"            })
local GameL3  = Tabs.Game:Section({ Side="Left",  Name="Exploits",       Image="zap"               })
local GameL4  = Tabs.Game:Section({ Side="Left",  Name="Events",         Image="trophy"            })
local GameR   = Tabs.Game:Section({ Side="Right", Name="Farm Config",    Image="settings"          })
local GameR_Combat = Tabs.Game:Section({ Side="Right", Name="Combat",     Image="swords"            })
local GameR2  = Tabs.Game:Section({ Side="Right", Name="Ownership",     Image="shield"            })
local CharL   = Tabs.Character:Section({ Side="Left",  Name="Movement",  Image="move"              })
local CharL2  = Tabs.Character:Section({ Side="Left",  Name="Morphs",    Image="user"              })
local CharR   = Tabs.Character:Section({ Side="Right", Name="Utility",   Image="wrench"            })
local CharR3  = Tabs.Character:Section({ Side="Right", Name="Aimbot",    Image="crosshair"         })
local VizL    = Tabs.Visuals:Section({ Side="Left",  Name="Player ESP",  Image="user"              })
local VizL2   = Tabs.Visuals:Section({ Side="Left",  Name="Mob ESP",     Image="swords"            })
local VizL3   = Tabs.Visuals:Section({ Side="Left",  Name="NPC ESP",     Image="user-round"        })
local VizL4   = Tabs.Visuals:Section({ Side="Left",  Name="Cup ESP",     Image="trophy"            })
local VizR    = Tabs.Visuals:Section({ Side="Right", Name="ESP Config",  Image="settings"          })
local WorldL2 = Tabs.World:Section({ Side="Left",  Name="Camera",       Image="camera"            })
local WorldL3 = Tabs.World:Section({ Side="Left",  Name="Server",       Image="server"            })
local WorldR  = Tabs.World:Section({ Side="Right", Name="Visual FX",    Image="sparkle"           })
local WorldR2 = Tabs.World:Section({ Side="Right", Name="FPS Boost",    Image="zap"               })
local WorldR3 = Tabs.World:Section({ Side="Right", Name="Tools",        Image="wrench"            })
local NavL    = Tabs.Nav:Section({ Side="Left",  Name="Teleport",       Image="navigation"        })
local NavL2   = Tabs.Nav:Section({ Side="Left",  Name="Safety",         Image="sparkles"          })
local NavR    = Tabs.Nav:Section({ Side="Right", Name="Attach",         Image="anchor"            })
local NavR2   = Tabs.Nav:Section({ Side="Right", Name="Attach Config",  Image="settings"          })
local MiscL   = Tabs.Misc:Section({ Side="Left",  Name="Cosmetic",         Image="palette"      })
local MiscR   = Tabs.Misc:Section({ Side="Right", Name="Status",           Image="shield-check" })
local SettL   = Tabs.Settings:Section({ Side="Left",  Name="Interface", Image="layout-dashboard"  })
local SettR   = Tabs.Settings:Section({ Side="Right", Name="Keybinds",  Image="keyboard"          })

-- ── Mob folder resolver (this game uses workspace.Instances.Server) ──────────
local function _getMobFolder()
    local inst = workspace:FindFirstChild("Instances")
    if not inst then return nil end
    return inst:FindFirstChild("Server")
end
local function _getNPCFolder()
    local inst = workspace:FindFirstChild("Instances")
    if not inst then return nil end
    return inst:FindFirstChild("NPCs")
end

getgenv()._ZHBoxes = getgenv()._ZHBoxes or {}


-- Direct TP (no smoothing)
local function tweenTo(cf, cancelCheck)
    local hrp=getHRP(); if not hrp then return end
    hrp.AssemblyLinearVelocity=Vector3.zero
    hrp.CFrame=cf
    return true
end
local function tweenToMob(cf, cancelCheck)
    local hrp=getHRP(); if not hrp then return end
    hrp.AssemblyLinearVelocity=Vector3.zero
    hrp.CFrame=cf
end

local function _getStatus() local c=getChar(); if not c then return end; return c:FindFirstChild("Status") end

local function serverHop()
    local placeId=game.PlaceId
    local ok,res=pcall(function() return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..tostring(placeId).."/servers/Public?sortOrder=Asc&limit=100")) end)
    if ok and res then for _,s in ipairs(res.data or {}) do if s.id~=game.JobId and s.playing<s.maxPlayers then pcall(function() TP:TeleportToPlaceInstance(placeId, s.id, LP) end); return end end end
    pcall(function() TP:TeleportToPlaceInstance(placeId, game.JobId, LP) end)
end

notify("Demon Born loaded", 4)


Tog.Fly = CharL:Toggle({
    Name="Fly", Default=false, Keybind=Enum.KeyCode.Y,
    Callback=function(p)
        if p then
            RS:BindToRenderStep("DBFly",Enum.RenderPriority.Input.Value,function(dt)
                local c=getChar(); if not c then return end
                local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
                if not getgenv()._DB_flyFrame then getgenv()._DB_flyFrame=hrp.CFrame end
                local frame=getgenv()._DB_flyFrame; local cf=Cam.CFrame; local mv=Vector3.zero
                local fmode=Opt.FlyMode and Opt.FlyMode.Value or "MoveDirection"
                if fmode=="MoveDirection" then
                    local fwd=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z).Unit; local rgt=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z).Unit
                    if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+fwd end; if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-fwd end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-rgt end; if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+rgt end
                else
                    local hum=c:FindFirstChildOfClass("Humanoid")
                    if hum and hum.MoveDirection.Magnitude>0 then
                        local fwd2=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z).Unit; local rgt2=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z).Unit
                        mv=mv+fwd2*hum.MoveDirection:Dot(fwd2)+rgt2*hum.MoveDirection:Dot(rgt2)
                    end
                end
                if UIS:IsKeyDown(Enum.KeyCode.Space)       then mv=mv+Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
                if mv.Magnitude>0 then frame=frame+mv.Unit*S.flySpeed*dt end
                local fwd3=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)
                if fwd3.Magnitude>0 then frame=CFrame.new(frame.Position,frame.Position+fwd3.Unit) end
                getgenv()._DB_flyFrame=frame; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.CFrame=frame
            end)
        else RS:UnbindFromRenderStep("DBFly"); getgenv()._DB_flyFrame=nil end
    end
}, "Fly")
Opt.FlySpeed = CharL:Slider({ Name="Fly Speed", Default=100, Minimum=0, Maximum=5000, Precision=0, Callback=function(v) S.flySpeed=v end }, "FlySpeed")
Opt.FlyMode  = CharL:Dropdown({ Name="Fly Mode", Options={"MoveDirection","Camera LookVector"}, Default=1, Multi=false, Callback=function() end }, "FlyMode")
CharL:Divider()
Tog.Speedhack = CharL:Toggle({
    Name="Speedhack", Default=false, Keybind=Enum.KeyCode.N,
    Callback=function(p)
        if p then RS:BindToRenderStep("DBSpeed",Enum.RenderPriority.Input.Value,function(dt)
            local c=getChar(); if not c then return end; local hum=c:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
            local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            if hum.MoveDirection.Magnitude>0 then hrp.CFrame=hrp.CFrame+hum.MoveDirection*S.speed*dt end
        end) else RS:UnbindFromRenderStep("DBSpeed") end
    end
}, "Speedhack")
Opt.SpeedhackSpeed = CharL:Slider({ Name="Speed", Default=100, Minimum=0, Maximum=5000, Precision=0, Callback=function(v) S.speed=v end }, "SpeedhackSpeed")
local ijConn=nil
Tog.InfiniteJump = CharL:Toggle({
    Name="Infinite Jump", Default=false, Keybind=Enum.KeyCode.H,
    Callback=function(p)
        if ijConn then ijConn:Disconnect(); ijConn=nil end
        if p then ijConn=UIS.InputBegan:Connect(function(input,gpe)
            if gpe or input.KeyCode~=Enum.KeyCode.Space then return end
            local hrp=getHRP(); if not hrp then return end
            hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,S.infJumpH,hrp.AssemblyLinearVelocity.Z)
        end) end
    end
}, "InfiniteJump")
Opt.InfiniteJumpHeight = CharL:Slider({ Name="Jump Height", Default=50, Minimum=0, Maximum=1000, Precision=0, Callback=function(v) S.infJumpH=v end }, "InfiniteJumpHeight")
local noclipConn=nil
Tog.Noclip = CharL:Toggle({
    Name="Noclip", Default=false, Keybind=Enum.KeyCode.T,
    Callback=function(p)
        if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
        if not p then return end
        local cached={}; local lastChar=nil
        noclipConn=RS.Heartbeat:Connect(function()
            local c=getChar()
            if c~=lastChar then cached={}; lastChar=c; if c then for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then cached[#cached+1]=d end end end end
            for _,part in ipairs(cached) do if part.Parent then part.CanCollide=false end end
        end)
    end
}, "Noclip")
CharL:Divider()
local MORPHS={
    ["Goku"]       ={hair=96778240725860, shirt=18642081551,    pants=13980707182   },
    ["Naruto"]     ={hair=129818847988995,shirt=6469644436,     pants=2733834231    },
    ["Gojo"]       ={hair=132501783778842,shirt=73084050138865, pants=15312673306   },
    ["Toji"]       ={hair=135664715112347,shirt=121088463088431,pants=16149857407   },
    ["Aizen"]      ={hair=117644781784979,shirt=87853669951881, pants=118029167731205},
    ["Guts"]       ={hair=117337600216775,shirt=13381096342,    pants=13381103162   },
    ["Vasto Lorde"]={hair=107798985962651,shirt=15549196125,    pants=15886594659   },
    ["Luffy"]      ={hair=103832443149308,shirt=8483860912,     pants=6274345723    },
    ["Zero Two"]   ={hair=93023559996037, shirt=6392201226,     pants=5896597102    },
    ["Yoruichi"]   ={hair=80207230854028, face=82588218846528,  shirt=18842292222,  pants=79431307149311},
}
local function clearMorph(char) for _,v in ipairs(char:GetChildren()) do if v:IsA("Accessory") or v:IsA("Hat") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then pcall(function() v:Destroy() end) end end end
local function addHair(char,id)
    local head=char:FindFirstChild("Head"); if not head then return end
    pcall(function()
        local objs=game:GetObjects("rbxassetid://"..tostring(id)); if not objs or not objs[1] then return end
        local acc=objs[1]; if not (acc:IsA("Accessory") or acc:IsA("Hat")) then return end
        local handle=acc:FindFirstChild("Handle"); if not handle then return end
        local headAtt=head:FindFirstChild("HairAttachment") or head:FindFirstChild("HatAttachment")
        local handleAtt=handle:FindFirstChild("HairAttachment") or handle:FindFirstChild("HatAttachment") or handle:FindFirstChild("BodyFrontAttachment")
        if headAtt and handleAtt then handle.CFrame=head.CFrame*headAtt.CFrame*handleAtt.CFrame:Inverse()
        else handle.CFrame=head.CFrame*CFrame.new(0,head.Size.Y*0.5+handle.Size.Y*0.3,0) end
        local wc=Instance.new("WeldConstraint"); wc.Part0=head; wc.Part1=handle; wc.Parent=handle
        handle.Anchored=false; acc.Parent=char
    end)
end
local function applyMorph(name)
    local char=LP.Character; if not char then return end
    local def=MORPHS[name]; clearMorph(char)
    local head=char:FindFirstChild("Head")
    if head then
        for _,v in ipairs(head:GetChildren()) do if v:IsA("Decal") then v:Destroy() end end
        if def and def.face then head.Transparency=0; local d=Instance.new("Decal"); d.Texture="rbxassetid://"..tostring(def.face); d.Face=Enum.NormalId.Front; d.Parent=head else head.Transparency=def and 1 or 0 end
    end
    if not def then return end
    if def.shirt then local s=char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt",char); s.ShirtTemplate="rbxassetid://"..tostring(def.shirt) end
    if def.pants then local p=char:FindFirstChildOfClass("Pants") or Instance.new("Pants",char); p.PantsTemplate="rbxassetid://"..tostring(def.pants) end
    addHair(char,def.hair)
end
local morphNames={"None"}; for k in pairs(MORPHS) do table.insert(morphNames,k) end; table.sort(morphNames)
Opt.MorphSelect = CharL2:Dropdown({ Name="Morph", Search=true, Options=morphNames, Default=1, Multi=false, Callback=function(v) local sel=type(v)=="table" and next(v) or v; task.spawn(function() applyMorph(sel~="None" and sel or nil) end) end }, "MorphSelect")
Opt.MorphSelect.IgnoreConfig = true
CharL2:Button({ Name="Reset Morph", Callback=function() Opt.MorphSelect:UpdateSelection(1); task.spawn(function() applyMorph(nil) end) end })
CharL2:Divider()
CharR:Button({ Name="Kill Self", Callback=function() local hum=getHum(); if hum then hum.Health=0 end end })
CharR:Divider()
local noAnimsThread=nil; local forcedTracks={}; local origTracks={}
Tog.NoAnims = CharR:Toggle({
    Name="No Anims", Default=false,
    Callback=function(p)
        if noAnimsThread then task.cancel(noAnimsThread); noAnimsThread=nil end
        if p then
            local c=getChar(); if not c then return end; local hum=c:FindFirstChildOfClass("Humanoid"); if not hum then return end
            local anim=hum:FindFirstChildOfClass("Animator"); if not anim then return end
            local dummy=Instance.new("Animation"); dummy.AnimationId="rbxassetid://109212722752"
            noAnimsThread=task.spawn(function()
                while Tog.NoAnims and Tog.NoAnims.State and hum and hum.Parent do
                    for _,track in ipairs(anim:GetPlayingAnimationTracks()) do if track.Animation.AnimationId~=dummy.AnimationId then if not table.find(origTracks,track) then table.insert(origTracks,track) end; pcall(function() track:Stop(); task.defer(track.Destroy,track) end) end end
                    local found=false; for _,track in ipairs(anim:GetPlayingAnimationTracks()) do if track.Animation.AnimationId==dummy.AnimationId then found=true end end
                    if not found then local t=anim:LoadAnimation(dummy); table.insert(forcedTracks,t); t.Priority=Enum.AnimationPriority.Core; t:AdjustSpeed(0); t:Play() end
                    task.wait(0.1)
                end
            end)
        else
            for _,track in pairs(forcedTracks) do pcall(function() track:Stop(); track:Destroy() end) end; forcedTracks={}
            for _,track in pairs(origTracks) do pcall(function() track:Play() end) end; origTracks={}
        end
    end
}, "NoAnims")
;(function()
    local _animSpeedConn=nil; local _animSpeed=1
    local function applyAnimSpeed(speed)
        pcall(function() local char=getChar(); if not char then return end; local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end; local anim=hum:FindFirstChildOfClass("Animator"); if not anim then return end; for _,track in ipairs(anim:GetPlayingAnimationTracks()) do pcall(function() track:AdjustSpeed(speed) end) end end)
    end
    Tog.AnimSpeed = CharR:Toggle({ Name="Anim Speed", Default=false, Callback=function(p) if _animSpeedConn then _animSpeedConn:Disconnect(); _animSpeedConn=nil end; if p then _animSpeedConn=RS.Heartbeat:Connect(function() applyAnimSpeed(_animSpeed) end) else applyAnimSpeed(1) end end }, "AnimSpeed")
    Opt.AnimSpeedSlider = CharR:Slider({ Name="Speed", Default=1, Minimum=0.1, Maximum=200, Precision=1, Callback=function(v) _animSpeed=v end }, "AnimSpeedSlider")
    onUnload(function() if _animSpeedConn then _animSpeedConn:Disconnect(); _animSpeedConn=nil end; applyAnimSpeed(1) end)
end)()
CharR:Divider()
local afkConn=nil; local _afkLoop=false
Tog.AntiAFK = CharR:Toggle({ Name="Anti AFK", Default=true, Callback=function(p)
    if afkConn then afkConn:Disconnect(); afkConn=nil end
    _afkLoop=p
    if not p then return end
    local function nudge()
        pcall(function()
            local VU=game:GetService("VirtualUser")
            VU:Button2Down(Vector2.zero,workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VU:Button2Up(Vector2.zero,workspace.CurrentCamera.CFrame)
        end)
    end

    afkConn=LP.Idled:Connect(nudge)

    task.spawn(function()
        while _afkLoop do task.wait(240); if _afkLoop then nudge() end end
    end)
end }, "AntiAFK")
CharR:Divider()
CharR:Label({ Text="RakNet" })
CharR:Label({ Text="<font color=\"rgb(255,220,0)\">TURN ON RAKNET IN YOUR EXECUTOR SETTINGS</font>" })
Tog.RaknetDesync = CharR:Toggle({ Name="Raknet Desync", Default=false, Risky=true,
    Callback=function(p)
        local rn=getgenv().raknet
        if p then
            if not rn or not rn.add_send_hook then notify("raknet not available",3); Tog.RaknetDesync:UpdateState(false); return end
            if shared._zh_desync then pcall(function() rn.remove_send_hook(shared._zh_desync) end) end
            local packets_sent=0; local last_t1=nil
            local function on_send(packet)
                pcall(function()
                    local data=packet.AsBuffer; local pos=0
                    local function ru8()  local v=buffer.readu8(data,pos);  pos=pos+1; return v end
                    local function ru32() local v=buffer.readu32(data,pos); pos=pos+4; return v end
                    local function ru64() local l=ru32(); local h=ru32(); return h*4294967296+l end
                    local id=ru8(); if id~=0x1B then return end
                    local t1=ru64(); local t2=ru64(); local wid=ru8()
                    if wid~=0x85 then return end
                    packets_sent=packets_sent+1
                    local forced_t1=t1
                    if last_t1 and packets_sent%10~=0 then forced_t1=last_t1-1 end
                    last_t1=t1
                    local w=buffer.create(buffer.len(data)); local wp=0
                    local function wu8(v)  buffer.writeu8(w,wp,v);  wp=wp+1 end
                    local function wu32(v) buffer.writeu32(w,wp,v); wp=wp+4 end
                    local function wu64(v) wu32(bit32.band(v,0xFFFFFFFF)); wu32(bit32.rshift(v,32)) end
                    wu8(0x1B); wu64(forced_t1); wu64(t2); wu8(wid)
                    for i=pos,buffer.len(data)-1 do wu8(buffer.readu8(data,i)) end
                    rn.send(buffer.create(wp),packet.Priority,packet.Reliability,packet.OrderingChannel)
                    packet:Block()
                end)
            end
            shared._zh_desync=on_send; rn.add_send_hook(on_send); notify("Desync ON",2)
        else
            if shared._zh_desync and rn and rn.remove_send_hook then pcall(function() rn.remove_send_hook(shared._zh_desync) end); shared._zh_desync=nil end
            notify("Desync OFF",2)
        end
    end }, "RaknetDesync")
Tog.GodMode = CharR:Toggle({ Name="God Mode (Needs Raknet)", Default=false, Risky=true,
    Callback=function(v)
        if not v then return end
        local rn=getgenv().raknet
        if not rn or not rn.add_send_hook then notify("raknet not available",3); Tog.GodMode:UpdateState(false); return end
        if not (checkcaller and newcclosure and hookmetamethod) then notify("executor missing required functions",3); Tog.GodMode:UpdateState(false); return end
        pcall(function()
            rn.add_send_hook(function(packet)
                if packet.PacketId==0x1B then local d=packet.AsBuffer; buffer.writeu32(d,1,0xFFFFFFFF); packet:SetData(d) end
            end)
            if replicatesignal and LP.Kill then pcall(function() replicatesignal(LP.Kill) end) end
            local Enabled=true; local DesyncTypes={}
            local downpart=Instance.new("Part",workspace); downpart.Size=Vector3.new(2,1,2); downpart.CanCollide=true; downpart.Material=Enum.Material.ForceField; downpart.Anchored=true
            local mouse=LP:GetMouse()
            mouse.Button1Down:Connect(function() Enabled=not Enabled end)
            mouse.Button1Up:Connect(function() Enabled=not Enabled end)
            RS.Heartbeat:Connect(function()
                if Enabled and LP.Character then
                    local rt=LP.Character:FindFirstChild("HumanoidRootPart"); if not rt then return end
                    DesyncTypes[1]=rt.CFrame; DesyncTypes[2]=rt.AssemblyLinearVelocity
                    rt.CFrame=rt.CFrame+Vector3.new(0,1000,0); downpart.CFrame=rt.CFrame+Vector3.new(0,-2,0)
                    rt.AssemblyLinearVelocity=Vector3.new(1,1,1); RS.RenderStepped:Wait()
                    rt.CFrame=DesyncTypes[1]; rt.AssemblyLinearVelocity=DesyncTypes[2]
                end
            end)
            local hook; hook=hookmetamethod(game,"__index",newcclosure(function(self,key)
                if Enabled and not checkcaller() and key=="CFrame" and LP.Character then
                    local hum=LP.Character:FindFirstChild("Humanoid")
                    if hum and hum.Health>0 and self==LP.Character:FindFirstChild("HumanoidRootPart") then
                        return DesyncTypes[1] or CFrame.new()
                    end
                end
                return hook(self,key)
            end))
            notify("God Mode ON",3)
        end)
    end }, "GodMode")
CharR:Divider()
local _noSlowConn=nil
Tog.NoStun = MiscR:Toggle({ Name="No Stun", Default=false, Callback=function(p) if _noSlowConn then _noSlowConn:Disconnect(); _noSlowConn=nil end; if not p then return end; _noSlowConn=RS.Heartbeat:Connect(function() pcall(function() local s=_getStatus(); if not s then return end; for _,v in ipairs(s:GetChildren()) do local n=v.Name:lower(); if n:find("slow") or n:find("stun") or n:find("freeze") or n:find("root") or n:find("immobil") or n:find("paraly") or n:find("stop") or n:find("bind") or n:find("snare") then pcall(function() v:Destroy() end) end end; local char=LP.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum and hum.WalkSpeed<16 then hum.WalkSpeed=16 end end) end) end }, "NoStun")
onUnload(function() if _noSlowConn then _noSlowConn:Disconnect() end end)

-- ── Cosmetic (Israel Mode + Zero Hub Mode) ───────────────────────────────────
do
    local _israelAddedConn=nil
    local ISRAEL_IMG="rbxassetid://12814915326"
    local function applyIsrael(obj)
        pcall(function()
            if obj:IsA("BasePart") then
                obj.Material=Enum.Material.SmoothPlastic; obj.Color=Color3.new(1,1,1)
                for _,face in ipairs(Enum.NormalId:GetEnumItems()) do
                    local existing=false
                    for _,child in pairs(obj:GetChildren()) do
                        if child:IsA("SurfaceGui") and child.Face==face and child:GetAttribute("IsraelTexture") then
                            existing=true; break
                        end
                    end
                    if not existing then
                        local sg=Instance.new("SurfaceGui"); sg.Face=face
                        sg:SetAttribute("IsraelTexture",true)
                        local img=Instance.new("ImageLabel")
                        img.Image=ISRAEL_IMG; img.Size=UDim2.new(1,0,1,0)
                        img.BackgroundTransparency=1; img.ScaleType=Enum.ScaleType.Stretch
                        img.Parent=sg
                        sg.Parent=obj
                    end
                end
            end
        end)
    end
    local function applyToAll()
        local count=0
        for _,v in pairs(workspace:GetDescendants()) do
            applyIsrael(v)
            count=count+1; if count%50==0 then task.wait() end
        end
    end
    Tog.IsraelMode = MiscL:Toggle({ Name="Israel Mode", Default=false,
        Callback=function(p)
            if _israelAddedConn then _israelAddedConn:Disconnect(); _israelAddedConn=nil end
            if not p then return end
            task.spawn(applyToAll)
            _israelAddedConn=workspace.DescendantAdded:Connect(function(v)
                task.defer(function() applyIsrael(v) end)
            end)
            task.spawn(function()
                while Tog.IsraelMode and Tog.IsraelMode.State do
                    applyToAll(); task.wait(5)
                end
            end)
            notify("Israel Mode applied",3)
        end }, "IsraelMode")
    onUnload(function() if _israelAddedConn then _israelAddedConn:Disconnect() end end)
end
do
    local _zhAddedConn=nil
    local ZH_TEXTURE="rbxassetid://83109184888967"
    local function applyZHTexture(obj)
        pcall(function()
            if obj:IsA("BasePart") then
                for _,face in ipairs(Enum.NormalId:GetEnumItems()) do
                    local existing=false
                    for _,child in pairs(obj:GetChildren()) do
                        if (child:IsA("Decal") or child:IsA("Texture")) and child.Face==face and child:GetAttribute("ZHTexture") then
                            existing=true; break
                        end
                    end
                    if not existing then
                        local d=Instance.new("Decal")
                        d.Texture=ZH_TEXTURE; d.Face=face
                        d:SetAttribute("ZHTexture",true); d.Parent=obj
                    end
                end
            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj.Image=ZH_TEXTURE
            end
        end)
    end
    local function applyToAll() for _,v in pairs(workspace:GetDescendants()) do applyZHTexture(v) end end
    Tog.ZeroHubTexture = MiscL:Toggle({ Name="Zero Hub Mode", Default=false,
        Callback=function(p)
            if _zhAddedConn then _zhAddedConn:Disconnect(); _zhAddedConn=nil end
            if not p then return end
            applyToAll()
            _zhAddedConn=workspace.DescendantAdded:Connect(function(v)
                task.defer(function() applyZHTexture(v) end)
            end)
            task.spawn(function()
                while Tog.ZeroHubTexture and Tog.ZeroHubTexture.State do
                    applyToAll(); task.wait(5)
                end
            end)
            notify("Zero Hub Mode applied",3)
        end }, "ZeroHubTexture")
    onUnload(function() if _zhAddedConn then _zhAddedConn:Disconnect() end end)
end
;(function()
    local _tpDeathConn=nil; local _tpDeathPos=nil
    Tog.TPOnDeath = NavL2:Toggle({ Name="TP Back on Death", Default=false, Callback=function(p)
        if _tpDeathConn then _tpDeathConn:Disconnect(); _tpDeathConn=nil end; if not p then return end
        local function hookChar(char) if not char then return end; local hum=char:WaitForChild("Humanoid",5); if not hum then return end; local hrp=char:WaitForChild("HumanoidRootPart",5); if not hrp then return end; local saveConn=RS.Heartbeat:Connect(function() if hum.Health>0 then _tpDeathPos=hrp.CFrame end end); hum.Died:Connect(function() saveConn:Disconnect(); if not _tpDeathPos then return end; local savedCF=_tpDeathPos; local newChar=LP.CharacterAdded:Wait(); local newHRP=newChar:WaitForChild("HumanoidRootPart",5); if newHRP and Tog.TPOnDeath and Tog.TPOnDeath.State then newHRP.CFrame=savedCF end end) end
        hookChar(LP.Character); _tpDeathConn=LP.CharacterAdded:Connect(function(char) task.wait(0.1); hookChar(char) end)
    end }, "TPOnDeath")
    onUnload(function() if _tpDeathConn then pcall(function() _tpDeathConn:Disconnect() end) end end)
end)()
NavL2:Divider()
local aimbotConn=nil; local fovCircle=nil; local aimKeyType="MB2"
local function getFOVScale() return Cam.ViewportSize.Y/2/math.tan(math.rad(Cam.FieldOfView/2)) end
local function getAimTargets() local list={}; if S.targetPlayers then for _,plr in ipairs(PS:GetPlayers()) do if plr~=LP and plr.Character then if not S.teamCheck or not LP.Team or plr.Team~=LP.Team then table.insert(list,plr.Character) end end end end; return list end
local function getAimPart(char) local v=Opt.AimPart and Opt.AimPart.Value or "Head"; if v=="Head" then return char:FindFirstChild("Head") end; if v=="Torso" then return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") end; if v=="Random" then local parts={}; for _,n in ipairs({"Head","HumanoidRootPart","Torso"}) do local p=char:FindFirstChild(n); if p then table.insert(parts,p) end end; return #parts>0 and parts[math.random(1,#parts)] or nil end; return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") end
local function isVisible(part) if not S.visibleOnly then return true end; local c=getChar(); if not c then return false end; local origin=Cam.CFrame.Position; local params=RaycastParams.new(); params.FilterDescendantsInstances={c}; params.FilterType=Enum.RaycastFilterType.Exclude; local result=workspace:Raycast(origin,(part.Position-origin),params); if not result then return true end; return result.Instance and result.Instance:IsDescendantOf(part.Parent) end
UIS.InputBegan:Connect(function(inp,gpe) if gpe then return end; local n=inp.UserInputType==Enum.UserInputType.MouseButton1 and "MB1" or inp.UserInputType==Enum.UserInputType.MouseButton2 and "MB2" or inp.KeyCode.Name; if n==aimKeyType and S.aimbotMode=="Hold" then S.aimbotActive=true end end)
UIS.InputEnded:Connect(function(inp) local n=inp.UserInputType==Enum.UserInputType.MouseButton1 and "MB1" or inp.UserInputType==Enum.UserInputType.MouseButton2 and "MB2" or inp.KeyCode.Name; if n==aimKeyType and S.aimbotMode=="Hold" then S.aimbotActive=false end end)
Opt.AimbotMode   = CharR3:Dropdown({ Name="Aimbot Mode",   Options={"Toggle","Hold","Always"}, Default=1, Multi=false, Callback=function(v) S.aimbotMode=type(v)=="table" and next(v) or v; if S.aimbotMode=="Always" then S.aimbotActive=true elseif S.aimbotMode~="Hold" then S.aimbotActive=false end end }, "AimbotMode")
Opt.AimbotMethod = CharR3:Dropdown({ Name="Aimbot Method", Options={"Camera","mousemoverel"},   Default=1, Multi=false, Callback=function(v) S.aimbotMethod=type(v)=="table" and next(v) or v end }, "AimbotMethod")
Opt.AimPart      = CharR3:Dropdown({ Name="Aim Part",      Options={"Head","Torso","Random"},   Default=1, Multi=false, Callback=function() end }, "AimPart")
Opt.AimbotKeybind = CharR3:Keybind({ Name="Aimbot Keybind", Default=Enum.KeyCode.Unknown, onBinded=function(bind) aimKeyType=tostring(bind.Name) end }, "AimbotKeybind")
Tog.Aimbot = CharR3:Toggle({
    Name="Aimbot", Default=false,
    Callback=function(p)
        S.aimbotEnabled=p; if aimbotConn then aimbotConn:Disconnect(); aimbotConn=nil end
        if not p then S.aimbotActive=false; return end
        if S.aimbotMode=="Always" then S.aimbotActive=true end
        local accum=Vector2.zero
        aimbotConn=RS.RenderStepped:Connect(function()
            if not S.aimbotActive then return end
            local vpSize=Cam.ViewportSize; local cx=vpSize.X/2+S.aimbotX; local cy=vpSize.Y/2+S.aimbotY
            local fovPx=math.tan(math.rad(S.aimbotFOV/2))*getFOVScale(); local best,bestDist=nil,fovPx
            for _,char in ipairs(getAimTargets()) do
                local part=getAimPart(char); if not part then continue end
                local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
                if not isVisible(part) then continue end
                local sp,onScreen=Cam:WorldToViewportPoint(part.Position); if not onScreen then continue end
                local d=((sp.X-cx)^2+(sp.Y-cy)^2)^0.5; if d<bestDist then bestDist=d; best=part end
            end
            if best then
                local target=best.Position
                if S.aimbotX~=0 or S.aimbotY~=0 then local v=Cam:WorldToViewportPoint(target); local shifted=Vector2.new(v.X+S.aimbotX,v.Y+S.aimbotY); local ray=Cam:ViewportPointToRay(shifted.X,shifted.Y); target=ray.Origin+ray.Direction*100 end
                if S.aimbotMethod=="Camera" then local t=math.clamp(S.aimbotSens*0.1,0.01,1); local lv=Cam.CFrame.LookVector:Lerp((target-Cam.CFrame.Position).Unit,t); Cam.CFrame=CFrame.new(Cam.CFrame.Position,Cam.CFrame.Position+lv)
                else local sp2=Cam:WorldToViewportPoint(target); local mouse=UIS:GetMouseLocation(); accum=accum+(Vector2.new(sp2.X,sp2.Y)-mouse)*S.aimbotSens; local cap=10; local clamped=Vector2.new(math.clamp(accum.X,-cap,cap),math.clamp(accum.Y,-cap,cap)); pcall(function() mousemoverel(clamped.X,clamped.Y) end); accum=accum-clamped end
            end
        end)
    end
}, "Aimbot")
Tog.AimbotPlayers = CharR3:Toggle({ Name="Target Players", Default=true,  Callback=function(p) S.targetPlayers=p end }, "AimbotPlayers")
Tog.VisibleOnly   = CharR3:Toggle({ Name="Visible Only",   Default=false, Callback=function(p) S.visibleOnly=p   end }, "VisibleOnly")
Tog.TeamCheck     = CharR3:Toggle({ Name="Team Check",     Default=false, Callback=function(p) S.teamCheck=p     end }, "TeamCheck")
CharR3:Divider()
Opt.AimbotSens    = CharR3:Slider({ Name="Lock Strength",  Default=1,     Minimum=0.1, Maximum=5,   Precision=2, Callback=function(v) S.aimbotSens=v end }, "AimbotSens")
Opt.AimbotXOffset = CharR3:Slider({ Name="X Offset",       Default=0,     Minimum=-300, Maximum=300, Precision=0, Callback=function(v) S.aimbotX=v end }, "AimbotXOffset")
Opt.AimbotYOffset = CharR3:Slider({ Name="Y Offset",       Default=0,     Minimum=-300, Maximum=300, Precision=0, Callback=function(v) S.aimbotY=v end }, "AimbotYOffset")
Tog.ShowFOV = CharR3:Toggle({ Name="Show FOV", Default=false, Callback=function(p) if p then if not fovCircle then fovCircle=Drawing.new("Circle"); fovCircle.Thickness=1; fovCircle.NumSides=100; fovCircle.Filled=false; fovCircle.Color=Color3.fromRGB(255,255,255) end; fovCircle.Radius=S.aimbotFOV*getFOVScale(); fovCircle.Position=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2); fovCircle.Visible=true elseif fovCircle then fovCircle.Visible=false end end }, "ShowFOV")
Opt.AimbotFOV = CharR3:Slider({ Name="Lock FOV", Default=45, Minimum=1, Maximum=120, Precision=0, Callback=function(v) S.aimbotFOV=v; if fovCircle and fovCircle.Visible then fovCircle.Radius=v*getFOVScale() end end }, "AimbotFOV")

onUnload(function()
    RS:UnbindFromRenderStep("DBSpeed")
    RS:UnbindFromRenderStep("DBFly")
    getgenv()._DB_flyFrame=nil

    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    local c=getChar(); if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end end end

    if ijConn then ijConn:Disconnect() end
    if afkConn then afkConn:Disconnect() end; _afkLoop=false

    if aimbotConn then aimbotConn:Disconnect() end
    if fovCircle then pcall(function() fovCircle:Remove() end) end

    if noAnimsThread then task.cancel(noAnimsThread); noAnimsThread=nil end
    for _,t in pairs(forcedTracks) do pcall(function() t:Stop(); t:Destroy() end) end; forcedTracks={}
    for _,t in pairs(origTracks) do pcall(function() t:Play() end) end; origTracks={}

    _autoRespLoop=false

    if getgenv()._ZHCrosshair then for _,d in ipairs(getgenv()._ZHCrosshair) do pcall(function() d:Remove() end) end; getgenv()._ZHCrosshair=nil end
end)


local farmState = { plrs=false, plrTarget="", mobs=false, mobTargets={}, croc=false }
local _farmMode="Behind"; local _farmOffX=0; local _farmOffY=0; local _farmOffZ=6.5
local function _calcFarmPos(rp)
    local mp=rp.Position
    local flatLook=Vector3.new(rp.CFrame.LookVector.X,0,rp.CFrame.LookVector.Z).Unit
    local flatRight=Vector3.new(rp.CFrame.RightVector.X,0,rp.CFrame.RightVector.Z).Unit
    local base
    if     _farmMode=="Above"    then base=mp+Vector3.new(0,_farmOffZ,0)
    elseif _farmMode=="Below"    then base=mp+Vector3.new(0,-_farmOffZ,0)
    elseif _farmMode=="In Front" then base=mp+flatLook*_farmOffZ
    else                              base=mp-flatLook*_farmOffZ end
    return base+flatRight*_farmOffX+Vector3.new(0,_farmOffY,0)
end
local farmConns={}
getgenv()._DB_autoM1=false
getgenv()._DB_combatLoopsStarted=false

-- ── Auto M1 — uses ActionStart + CombatHits packet vuln (server applies damage to whatever we put in the targets array) ────
local _DB_PacketsCache=nil
local _DB_autoM1Range=100
local function _DB_getPackets()
    if _DB_PacketsCache then return _DB_PacketsCache end
    local ok,result=pcall(function()
        local rf=game:GetService("ReplicatedFirst"):WaitForChild("Files",5)
        local loader=rf and rf:WaitForChild("Loader",5)
        local fw=loader and require(loader.Framework)
        return fw and fw.Cache:GetGlobalReplicated("Client","Packets")
    end)
    if ok and result and result.Inputs then _DB_PacketsCache=result end
    return _DB_PacketsCache
end
local function _DB_gatherTargets(range)
    local targets={}
    local myChar=LP.Character
    local myRoot=myChar and (myChar.PrimaryPart or myChar:FindFirstChild("HumanoidRootPart"))
    if not myRoot then return targets end
    local mobFolder=_getMobFolder()
    if mobFolder then
        for _,mob in ipairs(mobFolder:GetChildren()) do
            if mob:IsA("Model") then
                local hum=mob:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health>0 then
                    local pp=mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart")
                    if pp and (pp.Position-myRoot.Position).Magnitude<=range then
                        table.insert(targets,mob)
                    end
                end
            end
        end
    end
    for _,plr in ipairs(PS:GetPlayers()) do
        if plr~=LP then
            local c=plr.Character
            local hum=c and c:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local pp=c.PrimaryPart or c:FindFirstChild("HumanoidRootPart")
                if pp and (pp.Position-myRoot.Position).Magnitude<=range then
                    table.insert(targets,c)
                end
            end
        end
    end
    return targets
end
local function _DB_fireM1()
    local P=_DB_getPackets(); if not P then return end
    local guid=string.format("M1_%08X",math.random(0,0xFFFFFFFF))
    local now=workspace:GetServerTimeNow()
    pcall(function() P.Inputs.ActionStart:Fire({"M1",guid,"Forward",now}) end)
    local targets=_DB_gatherTargets(_DB_autoM1Range)
    if #targets>0 then
        pcall(function() P.Inputs.CombatHits:Fire({"M1",guid,now,targets}) end)
    end
end

-- re-enable combat after respawn if farm is active
LP.CharacterAdded:Connect(function()
    task.wait(2)
    if farmState.mobs or farmState.plrs or farmState.croc then
        enableFarmCombat()
    end
end)
if not getgenv()._DB_combatLoopsStarted then
    getgenv()._DB_combatLoopsStarted=true
    task.spawn(function() while true do task.wait(0.15); if getgenv()._DB_autoM1 then _DB_fireM1() end end end)
end
local function enableFarmCombat()
    getgenv()._DB_autoM1=true
end
local function disableFarmCombat()
    getgenv()._DB_autoM1=false
end

local function getMobType(mob)
    local ht=mob:GetAttribute("HollowType"); if ht and ht~="" then return tostring(ht) end
    return mob.Name:match("^(.-)_[^_]+$") or mob.Name
end

local function makeFarmLoop(targetFn, activeKey, killWait)
    local lastTgt=nil; local killCooldown=0; killWait=killWait or 3
    local inPosition=false; local tweening=false
    return RS.Heartbeat:Connect(function()
        if not farmState[activeKey] then return end
        local c=getChar(); if not c then lastTgt=nil; return end
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.RootPart then lastTgt=nil; return end
        if hum.Health<=0 then lastTgt=nil; killCooldown=0; inPosition=false; tweening=false; disableFarmCombat(); return end
        local hrp=hum.RootPart; hum.Health=hum.MaxHealth
        local tHum=lastTgt and lastTgt:FindFirstChildOfClass("Humanoid")
        local mobDied=lastTgt and (not lastTgt.Parent or not tHum or tHum.Health<=0)
        if not lastTgt or mobDied then
            if mobDied and killCooldown==0 then killCooldown=tick() end
            if killCooldown>0 and tick()-killCooldown<killWait then disableFarmCombat(); return end
            killCooldown=0; lastTgt=targetFn(); inPosition=false; tweening=false
        end
        if not lastTgt then inPosition=false; tweening=false; disableFarmCombat(); pcall(function() if sethiddenproperty then sethiddenproperty(hrp,"PhysicsRepRootPart",nil) end end); return end
        local rp=lastTgt:FindFirstChild("HumanoidRootPart"); if not rp then return end
        local targetPos=_calcFarmPos(rp)
        local dist=(hrp.Position-targetPos).Magnitude
        local offsetDist=(_farmOffX^2+_farmOffY^2+_farmOffZ^2)^0.5
        if dist>offsetDist+8 then
            inPosition=false; disableFarmCombat()
            if not tweening then
                tweening=true
                task.spawn(function()
                    tweenTo(CFrame.lookAt(_calcFarmPos(rp),rp.Position),function() return not farmState[activeKey] end)
                    tweening=false
                end)
            end
        else
            tweening=false
            if not inPosition then
                inPosition=true
                pcall(function() if sethiddenproperty then sethiddenproperty(hrp,"PhysicsRepRootPart",rp) end end)
            end
            enableFarmCombat()
            hrp.AssemblyLinearVelocity=Vector3.zero
            hrp.AssemblyAngularVelocity=Vector3.zero
            hrp.CFrame=CFrame.lookAt(targetPos,rp.Position)
        end
    end)
end

local function nearestPlayer()
    local hrp=getHRP(); if not hrp then return end
    local best,bestD=nil,math.huge
    for _,plr in ipairs(PS:GetPlayers()) do
        if plr==LP then continue end
        if farmState.plrTarget~="" and plr.Name~=farmState.plrTarget then continue end
        local c=plr.Character; if not c then continue end
        local r=c:FindFirstChild("HumanoidRootPart"); local h=c:FindFirstChildOfClass("Humanoid")
        if not (r and h and h.Health>0) then continue end
        local d=(r.Position-hrp.Position).Magnitude; if d<bestD then best=c; bestD=d end
    end
    return best
end
local function nearestMob()
    local hrp=getHRP(); if not hrp then return end
    local ents=_getMobFolder(); if not ents then return end
    local best,bestD=nil,math.huge
    local useFilter=next(farmState.mobTargets)~=nil and not farmState.mobTargets["Nearest Mob"]
    for _,mob in ipairs(ents:GetChildren()) do
        if mob==LP.Character then continue end
        if PS:GetPlayerFromCharacter(mob) then continue end
        if mob:GetAttribute("TrainingDummy") then continue end
        local r=mob:FindFirstChild("HumanoidRootPart"); local h=mob:FindFirstChildOfClass("Humanoid")
        if not (r and h and h.Health>0) then continue end
        if useFilter and not farmState.mobTargets[getMobType(mob)] then continue end
        local d=(r.Position-hrp.Position).Magnitude; if d<bestD then best=mob; bestD=d end
    end
    return best
end


;(function()
    local function buildPlrList()
        local list={"Any (Closest)"}
        for _,plr in ipairs(PS:GetPlayers()) do if plr~=LP then table.insert(list,plr.Name) end end
        return list
    end
    Opt.PlrSelect = GameL:Dropdown({
        Name="Target Player", Search=true, Options=buildPlrList(), Default=1, Multi=false,
        Callback=function(v)
            local sel=type(v)=="table" and next(v) or v
            farmState.plrTarget=tostring(sel or "")
        end
    }, "PlrSelect")
    Opt.PlrSelect.IgnoreConfig = true
    GameL:Button({ Name="Refresh Players", Callback=function()
        pcall(function() Opt.PlrSelect:ClearOptions(); Opt.PlrSelect:InsertOptions(buildPlrList()) end)
    end})
end)()
Tog.AutoFarmPlrs = GameL:Toggle({
    Name="Farm Players", Default=false, Keybind=Enum.KeyCode.Unknown,
    Callback=function(p)
        farmState.plrs=p
        if farmConns.plrs then farmConns.plrs:Disconnect(); farmConns.plrs=nil end
        if p then farmConns.plrs=makeFarmLoop(nearestPlayer,"plrs") else disableFarmCombat() end
    end
}, "AutoFarmPlrs")

local function scanMobList()
    local list={"Nearest Mob"}; local seen={}
    local ents=_getMobFolder()
    if ents then
        for _,mob in ipairs(ents:GetChildren()) do
            if PS:GetPlayerFromCharacter(mob) or mob==LP.Character then continue end
            if mob:GetAttribute("TrainingDummy") then continue end
            local h=mob:FindFirstChildOfClass("Humanoid"); if not (h and h.Health>0) then continue end
            local t=getMobType(mob); if not seen[t] then table.insert(list,t); seen[t]=true end
        end
        table.sort(list, function(a,b)
            if a=="Nearest Mob" then return true end; if b=="Nearest Mob" then return false end; return a<b
        end)
    end
    return list
end
Opt.MobSelect = GameL2:Dropdown({
    Name="Target Mob", Search=true, Options=scanMobList(), Default={"Nearest Mob"}, Multi=true,
    Callback=function(v) farmState.mobTargets=(type(v)=="table") and v or {} end
}, "MobSelect")
GameL2:Button({ Name="Refresh Mobs", Callback=function()
    pcall(function() Opt.MobSelect:ClearOptions(); Opt.MobSelect:InsertOptions(scanMobList()) end)
end})
Tog.AutoFarmMobs = GameL2:Toggle({
    Name="Mob Farm", Default=false, Keybind=Enum.KeyCode.Unknown,
    Callback=function(p)
        farmState.mobs=p
        if farmConns.mobs then farmConns.mobs:Disconnect(); farmConns.mobs=nil end
        if not p then disableFarmCombat(); return end
        local lastTgt,killCooldown,tweening,lastMobType,mobInPosition=nil,0,false,nil,false
        farmConns.mobs=RS.Heartbeat:Connect(function()
            if not farmState.mobs then return end
            local c=getChar(); if not c then lastTgt=nil; tweening=false; return end
            local hum=c:FindFirstChildOfClass("Humanoid"); local hrp=hum and hum.RootPart
            if not hum or not hrp then lastTgt=nil; tweening=false; return end
            if hum.Health<=0 then lastTgt=nil; killCooldown=0; tweening=false; mobInPosition=false; disableFarmCombat(); return end
            local tHum=lastTgt and lastTgt:FindFirstChildOfClass("Humanoid")
            local mobDied=lastTgt and (not lastTgt.Parent or not tHum or tHum.Health<=0)
            if not lastTgt or mobDied then
                if mobDied then

                    if lastTgt then lastMobType=getMobType(lastTgt) end
                    if killCooldown==0 then killCooldown=tick() end
                end
                if killCooldown>0 and tick()-killCooldown<4 then
                    disableFarmCombat()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    return
                end
                killCooldown=0

                local nextTgt = nil
                if lastMobType then
                    local ents=_getMobFolder()
                    if ents then
                        local hrpPos=hrp.Position; local best,bestD=nil,math.huge
                        for _,mob in ipairs(ents:GetChildren()) do
                            if mob==LP.Character or PS:GetPlayerFromCharacter(mob) then continue end
                            if mob:GetAttribute("TrainingDummy") then continue end
                            local r=mob:FindFirstChild("HumanoidRootPart"); local h=mob:FindFirstChildOfClass("Humanoid")
                            if not (r and h and h.Health>0) then continue end
                            if getMobType(mob)==lastMobType then
                                local d=(r.Position-hrpPos).Magnitude
                                if d<bestD then best=mob; bestD=d end
                            end
                        end
                        nextTgt=best
                    end
                end
                lastTgt = nextTgt or nearestMob()
                tweening=false; mobInPosition=false
            end
            if not lastTgt then tweening=false; disableFarmCombat(); return end
            local rp=lastTgt:FindFirstChild("HumanoidRootPart"); if not rp then return end
            local mp=rp.Position
            local flatLook=Vector3.new(rp.CFrame.LookVector.X,0,rp.CFrame.LookVector.Z).Unit
            local flatRight=Vector3.new(rp.CFrame.RightVector.X,0,rp.CFrame.RightVector.Z).Unit
            local base
            if     _farmMode=="Above"    then base=mp+Vector3.new(0,_farmOffZ,0)
            elseif _farmMode=="Below"    then base=mp+Vector3.new(0,-_farmOffZ,0)
            elseif _farmMode=="In Front" then base=mp+flatLook*_farmOffZ
            else                              base=mp-flatLook*_farmOffZ end
            local targetPos=CFrame.new(base+flatRight*_farmOffX+Vector3.new(0,_farmOffY,0))
            local dist=(hrp.Position-targetPos.Position).Magnitude
            local offsetDist=(_farmOffX^2+_farmOffY^2+_farmOffZ^2)^0.5
            local tweenThresh=offsetDist+8
            if dist>tweenThresh then
                disableFarmCombat(); mobInPosition=false
                if not tweening then
                    tweening=true; local snapMob=rp.Position
                    task.spawn(function()
                        pcall(function() tweenToMob(targetPos,function() return not farmState.mobs or (rp.Position-snapMob).Magnitude>3 end) end)
                        tweening=false
                    end)
                end
            else
                tweening=false
                if not mobInPosition then mobInPosition=true end
                pcall(function() if sethiddenproperty then sethiddenproperty(hrp,"PhysicsRepRootPart",rp) end end)
                enableFarmCombat()
                hrp.AssemblyLinearVelocity=Vector3.zero
                hrp.AssemblyAngularVelocity=Vector3.zero
                hrp.CFrame=CFrame.lookAt(targetPos.Position,rp.Position)
            end
        end)
    end
}, "AutoFarmMobs")


GameR:Label({ Text="Position" })
Opt.FarmMode    = GameR:Dropdown({ Name="Position", Options={"Above","Below","In Front","Behind"}, Default=4, Multi=false, Callback=function(v) _farmMode=type(v)=="table" and next(v) or v end }, "FarmMode")
Opt.FarmOffsetX = GameR:Slider({ Name="X Offset", Default=0,   Minimum=-50, Maximum=50, Precision=1, Callback=function(v) _farmOffX=v end }, "FarmOffsetX")
Opt.FarmOffsetY = GameR:Slider({ Name="Y Offset", Default=0,   Minimum=-50, Maximum=50, Precision=1, Callback=function(v) _farmOffY=v end }, "FarmOffsetY")
Opt.FarmOffsetZ = GameR:Slider({ Name="Z Offset", Default=6.5, Minimum=0,   Maximum=50, Precision=1, Callback=function(v) _farmOffZ=v end }, "FarmOffsetZ")


onUnload(function()
    getgenv()._DB_autoM1=false
    for _,conn in pairs(farmConns) do if conn then conn:Disconnect() end end
end)


-- ── Mob Tools (Insta Kill, Bring, Freeze) ────────────────────────────────────
do
    local _bringConn=nil; local _bringRange=100
    local _freezeRange=100; local _frozenParts={}; local _freezeConn2=nil
    local _ikConn=nil; local _ikRange=100; local _ikThreshold=0

    -- INSTA KILL
    local function startIK()
        if _ikConn then _ikConn:Disconnect() end
        _ikConn=RS.Heartbeat:Connect(function()
            local hrp=getHRP(); if not hrp then return end
            pcall(function() sethiddenproperty(LP,"MaxSimulationRadius",math.huge); sethiddenproperty(LP,"SimulationRadius",math.huge) end)
            local folder=_getMobFolder(); if not folder then return end
            local destroyY=workspace.FallenPartsDestroyHeight
            for _,mob in ipairs(folder:GetChildren()) do
                if not mob:IsA("Model") then continue end
                if PS:GetPlayerFromCharacter(mob) then continue end
                local pp=mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart"); if not pp then continue end
                local hum=mob:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
                if pp.Position.Y<=destroyY then continue end
                if _ikThreshold>0 and hum.Health>_ikThreshold then continue end
                if (pp.Position-hrp.Position).Magnitude>_ikRange then continue end
                pcall(function() hum.Health=0; mob:PivotTo(CFrame.new(pp.Position.X,destroyY-100,pp.Position.Z)) end)
            end
        end)
    end
    local function stopIK() if _ikConn then _ikConn:Disconnect(); _ikConn=nil end end
    do
        local _gmConn=nil
        Tog.GodMode = GameL3:Toggle({ Name="Godmode", Default=false,
            Callback=function(p)
                if _gmConn then _gmConn:Disconnect(); _gmConn=nil end
                if not p then
                    pcall(function() LP:SetAttribute("SafeZone", nil) end)
                    return
                end
                _gmConn=RS.Heartbeat:Connect(function()
                    if LP:GetAttribute("SafeZone")~=true then
                        pcall(function() LP:SetAttribute("SafeZone", true) end)
                    end
                end)
            end }, "GodMode")
        onUnload(function()
            if _gmConn then _gmConn:Disconnect() end
            pcall(function() LP:SetAttribute("SafeZone", nil) end)
        end)
    end
    do
        local _stamConn=nil; local _origStamina=nil
        Tog.InfStamina = GameL3:Toggle({ Name="Infinite Stamina", Default=false,
            Callback=function(p)
                if _stamConn then _stamConn:Disconnect(); _stamConn=nil end
                if not p then
                    if _origStamina~=nil then pcall(function() LP:SetAttribute("Stamina", _origStamina) end); _origStamina=nil end
                    return
                end
                _origStamina = LP:GetAttribute("Stamina")
                _stamConn=RS.Heartbeat:Connect(function()
                    local max = LP:GetAttribute("StaminaMax") or 100
                    if LP:GetAttribute("Stamina") ~= max then
                        pcall(function() LP:SetAttribute("Stamina", max) end)
                    end
                end)
            end }, "InfStamina")
        onUnload(function()
            if _stamConn then _stamConn:Disconnect() end
            if _origStamina~=nil then pcall(function() LP:SetAttribute("Stamina", _origStamina) end) end
        end)
    end
    GameL3:Divider()
    GameL3:Label({ Text="THESE REQUIRE NETWORK OWNERSHIP, TURN ON NETWORK OWNERSHIP TO VIEW IF YOU OWN" })
    GameL3:Divider()
    Tog.InstaKill = GameL3:Toggle({ Name="Insta Kill", Default=false,
        Callback=function(p) if p then startIK() else stopIK() end end }, "InstaKill")
    Opt.IKThreshold = GameL3:Slider({ Name="HP Threshold", Default=0, Minimum=0, Maximum=1000000, Precision=0,
        Callback=function(v) _ikThreshold=v end }, "IKThreshold")
    Opt.IKRange = GameL3:Slider({ Name="Range", Default=100, Minimum=10, Maximum=10000, Precision=0,
        Callback=function(v) _ikRange=v end }, "IKRange")
    GameL3:Divider()

    -- BRING MOBS
    local function stopBringMobs() if _bringConn then _bringConn:Disconnect(); _bringConn=nil end end
    local function startBringMobs()
        stopBringMobs()
        _bringConn=RS.Heartbeat:Connect(function()
            local hrp=getHRP(); if not hrp then return end
            pcall(function() sethiddenproperty(LP,"MaxSimulationRadius",math.huge); sethiddenproperty(LP,"SimulationRadius",math.huge) end)
            local folder=_getMobFolder(); if not folder then return end
            for _,mob in ipairs(folder:GetChildren()) do
                if not mob:IsA("Model") then continue end
                if PS:GetPlayerFromCharacter(mob) then continue end
                local pp=mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart"); if not pp then continue end
                if not mob:FindFirstChildOfClass("Humanoid") then continue end
                if (pp.Position-hrp.Position).Magnitude>_bringRange then continue end
                pcall(function() mob:PivotTo(CFrame.new(hrp.Position+Vector3.new(0,0,-5))) end)
            end
        end)
    end
    Tog.BringMobEnabled = GameL3:Toggle({ Name="Bring Mobs", Default=false,
        Callback=function(p) if p then startBringMobs() else stopBringMobs() end end }, "BringMobEnabled")
    Opt.BringRange = GameL3:Slider({ Name="Bring Range", Default=100, Minimum=10, Maximum=10000, Precision=0,
        Callback=function(v) _bringRange=v end }, "BringRange")
    GameL3:Divider()

    -- FREEZE MOBS
    local function freezeRoot(v)
        if not v:IsA("BasePart") then return end
        local myChar=getChar(); if myChar and v:IsDescendantOf(myChar) then return end
        local folder=_getMobFolder()
        if not folder or not v:IsDescendantOf(folder) then return end
        if PS:GetPlayerFromCharacter(v.Parent) then return end
        if not v.Parent:FindFirstChildOfClass("Humanoid") then return end
        if v:FindFirstChild("xDBFreeze") then return end
        local myHRP=getHRP()
        if myHRP and (v.Position-myHRP.Position).Magnitude>_freezeRange then return end
        local frozenCF=v.CFrame
        local tag=Instance.new("StringValue"); tag.Name="xDBFreeze"; tag.Parent=v
        local conn=RS.Heartbeat:Connect(function()
            if not v or not v.Parent then conn:Disconnect(); return end
            if not tag.Parent then conn:Disconnect(); return end
            v.AssemblyLinearVelocity=Vector3.zero; v.AssemblyAngularVelocity=Vector3.zero; v.CFrame=frozenCF
        end)
        table.insert(_frozenParts,{conn=conn,tag=tag})
    end
    local function stopFreezeMob()
        for _,d in ipairs(_frozenParts) do pcall(function() if d.conn then d.conn:Disconnect() end; if d.tag and d.tag.Parent then d.tag:Destroy() end end) end
        _frozenParts={}
        if _freezeConn2 then _freezeConn2:Disconnect(); _freezeConn2=nil end
    end
    local function startFreezeMob()
        stopFreezeMob()
        local folder=_getMobFolder()
        if folder then for _,model in ipairs(folder:GetChildren()) do if PS:GetPlayerFromCharacter(model) then continue end; local hrp=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart"); if hrp then freezeRoot(hrp) end end end
        _freezeConn2=workspace.DescendantAdded:Connect(function(v)
            if v:IsA("BasePart") then local folder2=_getMobFolder(); if folder2 and v:IsDescendantOf(folder2) then freezeRoot(v) end end
        end)
    end
    Tog.FreezeMobEnabled = GameL3:Toggle({ Name="Freeze Mobs", Default=false,
        Callback=function(p) if p then startFreezeMob() else stopFreezeMob() end end }, "FreezeMobEnabled")
    Opt.FreezeRange = GameL3:Slider({ Name="Freeze Range", Default=100, Minimum=10, Maximum=10000, Precision=0,
        Callback=function(v) _freezeRange=v; if Tog.FreezeMobEnabled and Tog.FreezeMobEnabled.State then startFreezeMob() end end }, "FreezeRange")

    onUnload(function() stopIK(); stopBringMobs(); stopFreezeMob() end)
end


-- ── Events: World Cup Farm ───────────────────────────────────────────────────
do
    local _wcfRunning=false
    Tog.WorldCupFarm = GameL4:Toggle({ Name="World Cup Farm", Default=false,
        Callback=function(p)
            if not p then _wcfRunning=false; return end
            if _wcfRunning then return end
            _wcfRunning=true
            task.spawn(function()
                while _wcfRunning do
                    local map=workspace:FindFirstChild("Map")
                    local ec=map and map:FindFirstChild("EventCollectibles")
                    local trophies=ec and ec:FindFirstChild("CupTrophies")
                    if not trophies then task.wait(1); continue end
                    local kids=trophies:GetChildren()
                    if #kids==0 then task.wait(1); continue end
                    for _,trophy in ipairs(kids) do
                        if not _wcfRunning then break end
                        if not trophy.Parent then continue end
                        local cf
                        if trophy:IsA("Model") then cf=trophy:GetPivot()
                        elseif trophy:IsA("BasePart") then cf=trophy.CFrame end
                        if not cf then continue end
                        local hrp=getHRP()
                        if hrp then hrp.AssemblyLinearVelocity=Vector3.zero; hrp.CFrame=cf+Vector3.new(0,3,0) end
                        task.wait(0.5)
                        if not trophy.Parent then continue end
                        local root=trophy:FindFirstChild("Root")
                        local prompt=root and root:FindFirstChild("EventCollectPrompt")
                        if prompt and prompt:IsA("ProximityPrompt") and fireproximityprompt then
                            pcall(function() fireproximityprompt(prompt) end)
                        end
                        task.wait(0.1)
                    end
                    task.wait(0.3)
                end
            end)
        end }, "WorldCupFarm")
    onUnload(function() _wcfRunning=false end)
end


;(function()
local espEnabled=false; local espColor=Color3.fromRGB(255,255,255)
local espActive={}; local espConns={}
local _plrESP={components={["Box 2D"]=true,["Text"]=true,["HP Bar"]=true},showName=true,showHP=true,showDist=true}

local function removeESP(char)
    local d=espActive[char]; if not d then return end
    pcall(function() if d.txt    then d.txt:Remove()    end end)
    pcall(function() if d.box    then d.box:Remove()    end end)
    pcall(function() if d.hpFill then d.hpFill:Remove() end end)
    pcall(function() if d.hpBack then d.hpBack:Remove() end end)
    pcall(function() if d.tracer then d.tracer:Remove() end end)
    pcall(function() if d.dot    then d.dot:Remove()    end end)
    pcall(function() if d.hl     then d.hl:Destroy()    end end)
    if d.rname   then pcall(function() RS:UnbindFromRenderStep(d.rname) end) end
    if d.ancConn then pcall(function() d.ancConn:Disconnect() end) end
    if d.dieConn then pcall(function() d.dieConn:Disconnect() end) end
    espActive[char]=nil
end
local function addESP(char,plr)
    if not char or espActive[char] then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); local hrp=char:FindFirstChild("HumanoidRootPart"); local head=char:FindFirstChild("Head")
    if not (hum and hrp and head) then return end
    local txt=Drawing.new("Text"); txt.Center=true; txt.Outline=true; txt.Visible=false; txt.Size=14
    local box=Drawing.new("Square"); box.Filled=false; box.Thickness=1.5; box.Visible=false
    local hpFill=Drawing.new("Square"); hpFill.Filled=true; hpFill.Visible=false
    local hpBack=Drawing.new("Square"); hpBack.Filled=false; hpBack.Thickness=1; hpBack.Color=Color3.new(0,0,0); hpBack.Visible=false
    local tracer=Drawing.new("Line"); tracer.Thickness=1; tracer.Visible=false
    local dot=Drawing.new("Circle"); dot.Radius=4; dot.Filled=true; dot.Visible=false; dot.Thickness=1
    local hl=Instance.new("Highlight"); hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.Enabled=false; hl.Parent=_espHLContainer; hl.Adornee=char
    local rname="ZH_ESP_"..char:GetDebugId()
    RS:BindToRenderStep(rname, Enum.RenderPriority.Camera.Value+1, function()
        if not (espEnabled and char and char.Parent) then removeESP(char); return end
        if plr and plr.Character and plr.Character ~= char then removeESP(char); return end
        local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
        local dist=(hrp.Position-myHRP.Position).Magnitude
        if dist>(S.espDist or 1000) then
            txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return
        end
        if S.espAntiLag and _wFPS<30 then
            txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return
        end
        local col=espColor or Color3.new(1,1,1)
        local comps=_plrESP.components or {}
        local sv,onS=Cam:WorldToViewportPoint(hrp.Position); local hv,onH=Cam:WorldToViewportPoint(head.Position)
        if not onS then txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return end
        local scale=math.clamp(1/(sv.Z*0.04),0.5,3)
        local bw=35*scale; local bh=70*scale; local bx=sv.X-bw/2; local by=sv.Y-bh/2
        local hpPct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
        local hpCol=Color3.fromHSV(hpPct*0.33,1,1)
        if comps["Box 2D"] then box.Position=Vector2.new(bx,by); box.Size=Vector2.new(bw,bh); box.Color=col; box.Visible=true else box.Visible=false end
        if comps["HP Bar"] then
            local barW=6; local barX=bx-barW-3
            hpBack.Position=Vector2.new(barX-1,by-1); hpBack.Size=Vector2.new(barW+2,bh+2); hpBack.Visible=true
            hpFill.Position=Vector2.new(barX,by+bh*(1-hpPct)); hpFill.Size=Vector2.new(barW,bh*hpPct); hpFill.Color=hpCol; hpFill.Visible=true
        else hpFill.Visible=false; hpBack.Visible=false end
        if comps["Text"] then
            local parts={}; local name=(plr and plr.DisplayName) or char.Name
            if _plrESP.showName then table.insert(parts,name) end
            if _plrESP.showHP   then table.insert(parts,string.format("[%d/%d]",hum.Health,hum.MaxHealth)) end
            if _plrESP.showDist then table.insert(parts,string.format("[%.0fm]",dist)) end
            txt.Text=table.concat(parts," "); txt.Color=col; txt.Size=S.espFontSize or 14
            txt.Position=Vector2.new(sv.X,by-(S.espFontSize or 14)-2); txt.Visible=#parts>0
        else txt.Visible=false end
        if comps["Tracer"] then tracer.From=Vector2.new(sv.X,sv.Y); tracer.To=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y); tracer.Color=col; tracer.Thickness=S.tracerThick or 1; tracer.Visible=true else tracer.Visible=false end
        if comps["Head Dot"] and onH then dot.Position=Vector2.new(hv.X,hv.Y); dot.Color=col; dot.Visible=true else dot.Visible=false end
        hl.Enabled=comps["Highlight"] and espEnabled; hl.FillColor=col; hl.OutlineColor=col
        hl.FillTransparency=S.hlFillTrans or 0.5; hl.OutlineTransparency=S.hlOutlineTrans or 0
    end)
    espActive[char]={txt=txt,box=box,hpFill=hpFill,hpBack=hpBack,tracer=tracer,dot=dot,hl=hl,rname=rname,
        ancConn=char.AncestryChanged:Connect(function(_,p) if not p then removeESP(char) end end),
        dieConn=hum.Died:Connect(function() task.wait(3); removeESP(char) end)}
end

local _hue=0
local mobESPColor2=Color3.fromRGB(255,100,100); local npcESPColor2=Color3.fromRGB(100,220,255)
local _mobESP2={components={["Box 2D"]=true,["Text"]=true,["HP Bar"]=true},showName=true,showHP=true,showDist=true,rainbow=false}
local _npcESP2={components={["Box 2D"]=true,["Text"]=true,["HP Bar"]=true},showName=true,showHP=true,showDist=true,rainbow=false}
RS.Heartbeat:Connect(function(dt)
    _hue=(_hue+dt*0.25)%1; local rc=Color3.fromHSV(_hue,1,1)
    if S.espRainbow     then espColor=rc      end
    if _mobESP2.rainbow then mobESPColor2=rc  end
    if _npcESP2.rainbow then npcESPColor2=rc  end
end)


Tog.PlayerESPEnabled = VizL:Toggle({
    Name="Player ESP", Default=false,
    Callback=function(p)
        espEnabled=p
        if p then
            local function hook(plr)
                if plr==LP then return end
                if plr.Character then task.spawn(addESP,plr.Character,plr) end
                table.insert(espConns,plr.CharacterAdded:Connect(function(c) task.wait(0.25); addESP(c,plr) end))
            end
            for _,plr in ipairs(PS:GetPlayers()) do hook(plr) end
            table.insert(espConns,PS.PlayerAdded:Connect(hook))
            table.insert(espConns,PS.PlayerRemoving:Connect(function(plr) if plr.Character then removeESP(plr.Character) end end))
        else
            for _,conn in ipairs(espConns) do pcall(function() conn:Disconnect() end) end
            espConns={}
            local _eList={}; for c in pairs(espActive) do _eList[#_eList+1]=c end; for _,c in ipairs(_eList) do removeESP(c) end
        end
    end
}, "PlayerESPEnabled")
Opt.ESPColor = VizL:Colorpicker({ Name="ESP Color", Default=Color3.fromRGB(255,255,255), Alpha=0, Callback=function(col) espColor=col end }, "ESPColor")
Tog.ESPRainbow  = VizL:Toggle({ Name="Rainbow",  Default=false, Callback=function(p) S.espRainbow=p  end }, "ESPRainbow")
Tog.ESPShowName = VizL:Toggle({ Name="Name",     Default=true,  Callback=function(p) _plrESP.showName=p end }, "ESPShowName")
Tog.ESPShowHP   = VizL:Toggle({ Name="Health",   Default=true,  Callback=function(p) _plrESP.showHP=p   end }, "ESPShowHP")
Tog.ESPShowDist = VizL:Toggle({ Name="Distance", Default=true,  Callback=function(p) _plrESP.showDist=p end }, "ESPShowDist")
Opt.PlrESPComponents = VizL:Dropdown({
    Name="Components", Multi=true, Default={"Text","Box 2D","HP Bar"}, Options={"Text","Highlight","Tracer","Box 2D","HP Bar","Head Dot"},
    Callback=function(v) _plrESP.components=v end
}, "PlrESPComponents")
VizL:Divider()


VizR:Label({ Text="Range" })
Opt.ESPDist     = VizR:Slider({ Name="Max Distance",  Default=1000, Minimum=0, Maximum=10000, Precision=0, Callback=function(v) S.espDist=v     end }, "ESPDist")
Opt.ESPFontSize = VizR:Slider({ Name="Font Size",      Default=14,   Minimum=8, Maximum=32,   Precision=0, Callback=function(v) S.espFontSize=v end }, "ESPFontSize")
VizR:Divider()
VizR:Label({ Text="Highlight" })
Opt.HLFillTrans    = VizR:Slider({ Name="Fill Trans",    Default=0.5, Minimum=0, Maximum=1, Precision=2, Callback=function(v) S.hlFillTrans=v    end }, "HLFillTrans")
Opt.HLOutlineTrans = VizR:Slider({ Name="Outline Trans", Default=0,   Minimum=0, Maximum=1, Precision=2, Callback=function(v) S.hlOutlineTrans=v end }, "HLOutlineTrans")
VizR:Divider()
VizR:Label({ Text="Tracer" })
Opt.TracerThick = VizR:Slider({ Name="Tracer Width", Default=1, Minimum=1, Maximum=5, Precision=1, Callback=function(v) S.tracerThick=v end }, "TracerThick")
VizR:Divider()
VizR:Label({ Text="Anti-Lag" })
Tog.ESPThrottle = VizR:Toggle({ Name="FPS Guard", Default=true, Callback=function(p) S.espAntiLag=p end }, "ESP_Throttle")
VizR:Label({ Text="Disables ESP when FPS < 30" })


local _mobESPActive={}; local _mobESPEnabled=false
local function removeMobESP(mob)
    local d=_mobESPActive[mob]; if not d then return end
    pcall(function() if d.txt    then d.txt:Remove()    end end)
    pcall(function() if d.box    then d.box:Remove()    end end)
    pcall(function() if d.hpFill then d.hpFill:Remove() end end)
    pcall(function() if d.hpBack then d.hpBack:Remove() end end)
    pcall(function() if d.tracer then d.tracer:Remove() end end)
    pcall(function() if d.dot    then d.dot:Remove()    end end)
    pcall(function() if d.hl     then d.hl:Destroy()    end end)
    if d.conn    then pcall(function() d.conn:Disconnect()    end) end
    if d.ancConn then pcall(function() d.ancConn:Disconnect() end) end
    _mobESPActive[mob]=nil
end
local function getMobType2(mob)
    local ht=mob:GetAttribute("HollowType"); if ht and ht~="" then return tostring(ht) end
    return mob.Name:match("^(.-)_[^_]+$") or mob.Name
end
local function addMobESP(mob)
    if not mob or _mobESPActive[mob] then return end
    local hum=mob:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hrp=mob:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local head=mob:FindFirstChild("Head")
    local txt=Drawing.new("Text"); txt.Center=true; txt.Outline=true; txt.Visible=false; txt.Size=14
    local box=Drawing.new("Square"); box.Filled=false; box.Thickness=1.5; box.Visible=false
    local hpFill=Drawing.new("Square"); hpFill.Filled=true; hpFill.Visible=false
    local hpBack=Drawing.new("Square"); hpBack.Filled=false; hpBack.Thickness=1; hpBack.Color=Color3.new(0,0,0); hpBack.Visible=false
    local tracer=Drawing.new("Line"); tracer.Thickness=1; tracer.Visible=false
    local dot=Drawing.new("Circle"); dot.Radius=4; dot.Filled=true; dot.Visible=false; dot.Thickness=1
    local hl=Instance.new("Highlight"); hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.Enabled=false; hl.Parent=_espHLContainer; hl.Adornee=mob
    local conn=RS.Heartbeat:Connect(function()
        if not (_mobESPEnabled and mob and mob.Parent) then removeMobESP(mob); return end
        local myHRP=getHRP(); if not myHRP then return end
        local col=mobESPColor2; local dist=(hrp.Position-myHRP.Position).Magnitude
        local comps=_mobESP2.components or {}
        if dist>(S.espDist or 1000) then txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return end
        local sv,onS=Cam:WorldToViewportPoint(hrp.Position); local hv,onH=head and Cam:WorldToViewportPoint(head.Position)
        if not onS then txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return end
        local scale=math.clamp(1/(sv.Z*0.04),0.5,3); local bw=35*scale; local bh=70*scale; local bx=sv.X-bw/2; local by=sv.Y-bh/2
        local hpPct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1); local hpCol=Color3.fromHSV(hpPct*0.33,1,1)
        if comps["Box 2D"] then box.Position=Vector2.new(bx,by); box.Size=Vector2.new(bw,bh); box.Color=col; box.Visible=true else box.Visible=false end
        if comps["HP Bar"] then local barW=6; local barX=bx-barW-3; hpBack.Position=Vector2.new(barX-1,by-1); hpBack.Size=Vector2.new(barW+2,bh+2); hpBack.Visible=true; hpFill.Position=Vector2.new(barX,by+bh*(1-hpPct)); hpFill.Size=Vector2.new(barW,bh*hpPct); hpFill.Color=hpCol; hpFill.Visible=true else hpFill.Visible=false; hpBack.Visible=false end
        if comps["Text"] then local parts={}; if _mobESP2.showName then table.insert(parts,getMobType2(mob)) end; if _mobESP2.showHP then table.insert(parts,string.format("[%d/%d]",hum.Health,hum.MaxHealth)) end; if _mobESP2.showDist then table.insert(parts,string.format("[%.0fm]",dist)) end; txt.Text=table.concat(parts," "); txt.Color=col; txt.Size=S.espFontSize or 14; txt.Position=Vector2.new(sv.X,by-(S.espFontSize or 14)-2); txt.Visible=#parts>0 else txt.Visible=false end
        if comps["Tracer"] then tracer.From=Vector2.new(sv.X,sv.Y); tracer.To=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y); tracer.Color=col; tracer.Thickness=S.tracerThick or 1; tracer.Visible=true else tracer.Visible=false end
        if comps["Head Dot"] and onH and head then dot.Position=Vector2.new(hv.X,hv.Y); dot.Color=col; dot.Visible=true else dot.Visible=false end
        hl.Enabled=comps["Highlight"] and _mobESPEnabled or false; hl.FillColor=col; hl.OutlineColor=col; hl.FillTransparency=S.hlFillTrans or 0.5; hl.OutlineTransparency=S.hlOutlineTrans or 0
    end)
    _mobESPActive[mob]={txt=txt,box=box,hpFill=hpFill,hpBack=hpBack,tracer=tracer,dot=dot,hl=hl,conn=conn,
        ancConn=mob.AncestryChanged:Connect(function(_,p) if not p then removeMobESP(mob) end end)}
end
local function scanMobESP2() local living=_getMobFolder(); if not living then return end; for _,m in ipairs(living:GetChildren()) do if m:IsA("Model") and not PS:GetPlayerFromCharacter(m) then addMobESP(m) end end end
local function stopMobESP() _mobESPEnabled=false; for mob in pairs(_mobESPActive) do removeMobESP(mob) end end

Tog.MobESPEnabled = VizL2:Toggle({
    Name="Mob ESP", Default=false,
    Callback=function(p)
        _mobESPEnabled=p
        if p then scanMobESP2(); task.spawn(function() while _mobESPEnabled do task.wait(3); scanMobESP2() end end)
        else stopMobESP() end
    end
}, "MobESPEnabled")
Opt.MobESPColor2 = VizL2:Colorpicker({ Name="Mob Color", Default=Color3.fromRGB(255,100,100), Alpha=0, Callback=function(c) mobESPColor2=c end }, "MobESPColor2")
Tog.MobESPRainbow2 = VizL2:Toggle({ Name="Rainbow",  Default=false, Callback=function(p) _mobESP2.rainbow=p  end }, "MobESPRainbow2")
Tog.MobESPShowName = VizL2:Toggle({ Name="Name",     Default=true,  Callback=function(p) _mobESP2.showName=p end }, "MobESPShowName")
Tog.MobESPShowHP   = VizL2:Toggle({ Name="Health",   Default=true,  Callback=function(p) _mobESP2.showHP=p   end }, "MobESPShowHP")
Tog.MobESPShowDist = VizL2:Toggle({ Name="Distance", Default=true,  Callback=function(p) _mobESP2.showDist=p end }, "MobESPShowDist")
Opt.MobESPComponents = VizL2:Dropdown({ Name="Components", Multi=true, Default={"Text","Box 2D","HP Bar"}, Options={"Text","Highlight","Tracer","Box 2D","HP Bar","Head Dot"}, Callback=function(v) _mobESP2.components=v end }, "MobESPComponents")
onUnload(function() stopMobESP() end)
VizL2:Divider()

-- ── NPC ESP (workspace.Instances.NPCs) ───────────────────────────────────────
local _npcESPActive={}; local _npcESPEnabled=false
local function removeNPCESP(npc)
    local d=_npcESPActive[npc]; if not d then return end
    pcall(function() if d.txt    then d.txt:Remove()    end end)
    pcall(function() if d.box    then d.box:Remove()    end end)
    pcall(function() if d.hpFill then d.hpFill:Remove() end end)
    pcall(function() if d.hpBack then d.hpBack:Remove() end end)
    pcall(function() if d.tracer then d.tracer:Remove() end end)
    pcall(function() if d.dot    then d.dot:Remove()    end end)
    pcall(function() if d.hl     then d.hl:Destroy()    end end)
    if d.conn    then pcall(function() d.conn:Disconnect()    end) end
    if d.ancConn then pcall(function() d.ancConn:Disconnect() end) end
    _npcESPActive[npc]=nil
end
local function getNPCName(npc)
    local nm=npc:GetAttribute("DisplayName") or npc:GetAttribute("Name")
    if nm and nm~="" then return tostring(nm) end
    return npc.Name
end
local function addNPCESP(npc)
    if not npc or _npcESPActive[npc] then return end
    local hum=npc:FindFirstChildOfClass("Humanoid")
    local hrp=npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end
    local head=npc:FindFirstChild("Head") or hrp
    local txt=Drawing.new("Text"); txt.Center=true; txt.Outline=true; txt.Visible=false; txt.Size=14
    local box=Drawing.new("Square"); box.Filled=false; box.Thickness=1.5; box.Visible=false
    local hpFill=Drawing.new("Square"); hpFill.Filled=true; hpFill.Visible=false
    local hpBack=Drawing.new("Square"); hpBack.Filled=false; hpBack.Thickness=1; hpBack.Color=Color3.new(0,0,0); hpBack.Visible=false
    local tracer=Drawing.new("Line"); tracer.Thickness=1; tracer.Visible=false
    local dot=Drawing.new("Circle"); dot.Radius=4; dot.Filled=true; dot.Visible=false; dot.Thickness=1
    local hl=Instance.new("Highlight"); hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.Enabled=false; hl.Parent=_espHLContainer; hl.Adornee=npc
    local conn=RS.Heartbeat:Connect(function()
        if not (_npcESPEnabled and npc and npc.Parent) then removeNPCESP(npc); return end
        local myHRP=getHRP(); if not myHRP then return end
        local col=npcESPColor2; local dist=(hrp.Position-myHRP.Position).Magnitude
        local comps=_npcESP2.components or {}
        if dist>(S.espDist or 1000) then txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return end
        local sv,onS=Cam:WorldToViewportPoint(hrp.Position); local hv,onH=head and Cam:WorldToViewportPoint(head.Position)
        if not onS then txt.Visible=false; box.Visible=false; hpFill.Visible=false; hpBack.Visible=false; tracer.Visible=false; dot.Visible=false; hl.Enabled=false; return end
        local scale=math.clamp(1/(sv.Z*0.04),0.5,3); local bw=35*scale; local bh=70*scale; local bx=sv.X-bw/2; local by=sv.Y-bh/2
        local hpPct=hum and math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1) or 1; local hpCol=Color3.fromHSV(hpPct*0.33,1,1)
        if comps["Box 2D"] then box.Position=Vector2.new(bx,by); box.Size=Vector2.new(bw,bh); box.Color=col; box.Visible=true else box.Visible=false end
        if comps["HP Bar"] and hum then local barW=6; local barX=bx-barW-3; hpBack.Position=Vector2.new(barX-1,by-1); hpBack.Size=Vector2.new(barW+2,bh+2); hpBack.Visible=true; hpFill.Position=Vector2.new(barX,by+bh*(1-hpPct)); hpFill.Size=Vector2.new(barW,bh*hpPct); hpFill.Color=hpCol; hpFill.Visible=true else hpFill.Visible=false; hpBack.Visible=false end
        if comps["Text"] then local parts={}; if _npcESP2.showName then table.insert(parts,getNPCName(npc)) end; if _npcESP2.showHP and hum then table.insert(parts,string.format("[%d/%d]",hum.Health,hum.MaxHealth)) end; if _npcESP2.showDist then table.insert(parts,string.format("[%.0fm]",dist)) end; txt.Text=table.concat(parts," "); txt.Color=col; txt.Size=S.espFontSize or 14; txt.Position=Vector2.new(sv.X,by-(S.espFontSize or 14)-2); txt.Visible=#parts>0 else txt.Visible=false end
        if comps["Tracer"] then tracer.From=Vector2.new(sv.X,sv.Y); tracer.To=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y); tracer.Color=col; tracer.Thickness=S.tracerThick or 1; tracer.Visible=true else tracer.Visible=false end
        if comps["Head Dot"] and onH and head then dot.Position=Vector2.new(hv.X,hv.Y); dot.Color=col; dot.Visible=true else dot.Visible=false end
        hl.Enabled=comps["Highlight"] and _npcESPEnabled or false; hl.FillColor=col; hl.OutlineColor=col; hl.FillTransparency=S.hlFillTrans or 0.5; hl.OutlineTransparency=S.hlOutlineTrans or 0
    end)
    _npcESPActive[npc]={txt=txt,box=box,hpFill=hpFill,hpBack=hpBack,tracer=tracer,dot=dot,hl=hl,conn=conn,
        ancConn=npc.AncestryChanged:Connect(function(_,p) if not p then removeNPCESP(npc) end end)}
end
local function scanNPCESP() local folder=_getNPCFolder(); if not folder then return end; for _,m in ipairs(folder:GetChildren()) do if m:IsA("Model") and not PS:GetPlayerFromCharacter(m) then addNPCESP(m) end end end
local function stopNPCESP() _npcESPEnabled=false; for npc in pairs(_npcESPActive) do removeNPCESP(npc) end end

Tog.NPCESPEnabled = VizL3:Toggle({
    Name="NPC ESP", Default=false,
    Callback=function(p)
        _npcESPEnabled=p
        if p then scanNPCESP(); task.spawn(function() while _npcESPEnabled do task.wait(3); scanNPCESP() end end)
        else stopNPCESP() end
    end
}, "NPCESPEnabled")
Opt.NPCESPColor    = VizL3:Colorpicker({ Name="NPC Color", Default=Color3.fromRGB(100,220,255), Alpha=0, Callback=function(c) npcESPColor2=c end }, "NPCESPColor")
Tog.NPCESPRainbow  = VizL3:Toggle({ Name="Rainbow",  Default=false, Callback=function(p) _npcESP2.rainbow=p  end }, "NPCESPRainbow")
Tog.NPCESPShowName = VizL3:Toggle({ Name="Name",     Default=true,  Callback=function(p) _npcESP2.showName=p end }, "NPCESPShowName")
Tog.NPCESPShowHP   = VizL3:Toggle({ Name="Health",   Default=true,  Callback=function(p) _npcESP2.showHP=p   end }, "NPCESPShowHP")
Tog.NPCESPShowDist = VizL3:Toggle({ Name="Distance", Default=true,  Callback=function(p) _npcESP2.showDist=p end }, "NPCESPShowDist")
Opt.NPCESPComponents = VizL3:Dropdown({ Name="Components", Multi=true, Default={"Text","Box 2D","HP Bar"}, Options={"Text","Highlight","Tracer","Box 2D","HP Bar","Head Dot"}, Callback=function(v) _npcESP2.components=v end }, "NPCESPComponents")
onUnload(function() stopNPCESP() end)
VizL3:Divider()

-- ── Cup ESP (workspace.Map.EventCollectibles.CupTrophies) ────────────────────
local cupESPColor=Color3.fromRGB(255,215,0)
local _cupESP={components={["Box 2D"]=true,["Text"]=true,["Highlight"]=true},showName=true,showDist=true,rainbow=false}
local _cupESPActive={}; local _cupESPEnabled=false
RS.Heartbeat:Connect(function(dt) if _cupESP.rainbow then cupESPColor=Color3.fromHSV(_hue,1,1) end end)
local function _getCupFolder()
    local map=workspace:FindFirstChild("Map"); if not map then return nil end
    local ec=map:FindFirstChild("EventCollectibles"); if not ec then return nil end
    return ec:FindFirstChild("CupTrophies")
end
local function removeCupESP(trophy)
    local d=_cupESPActive[trophy]; if not d then return end
    pcall(function() if d.txt then d.txt:Remove() end end)
    pcall(function() if d.box then d.box:Remove() end end)
    pcall(function() if d.hl  then d.hl:Destroy()  end end)
    if d.conn    then pcall(function() d.conn:Disconnect()    end) end
    if d.ancConn then pcall(function() d.ancConn:Disconnect() end) end
    _cupESPActive[trophy]=nil
end
local function addCupESP(trophy)
    if not trophy or _cupESPActive[trophy] then return end
    local root=trophy:FindFirstChild("Root") or trophy.PrimaryPart or trophy:FindFirstChildWhichIsA("BasePart",true)
    if not root then return end
    local txt=Drawing.new("Text"); txt.Center=true; txt.Outline=true; txt.Visible=false; txt.Size=14
    local box=Drawing.new("Square"); box.Filled=false; box.Thickness=1.5; box.Visible=false
    local hl=Instance.new("Highlight"); hl.FillTransparency=0.4; hl.OutlineTransparency=0; hl.Enabled=false; hl.Parent=_espHLContainer; hl.Adornee=trophy
    local conn=RS.Heartbeat:Connect(function()
        if not (_cupESPEnabled and trophy and trophy.Parent) then removeCupESP(trophy); return end
        local myHRP=getHRP(); if not myHRP then return end
        local rp=trophy:FindFirstChild("Root") or trophy.PrimaryPart or trophy:FindFirstChildWhichIsA("BasePart",true)
        if not rp then return end
        local col=cupESPColor; local dist=(rp.Position-myHRP.Position).Magnitude
        local comps=_cupESP.components or {}
        if dist>(S.espDist or 1000) then txt.Visible=false; box.Visible=false; hl.Enabled=false; return end
        local sv,onS=Cam:WorldToViewportPoint(rp.Position)
        if not onS then txt.Visible=false; box.Visible=false; hl.Enabled=false; return end
        local scale=math.clamp(1/(sv.Z*0.04),0.5,3); local bw=30*scale; local bh=50*scale; local bx=sv.X-bw/2; local by=sv.Y-bh/2
        if comps["Box 2D"] then box.Position=Vector2.new(bx,by); box.Size=Vector2.new(bw,bh); box.Color=col; box.Visible=true else box.Visible=false end
        if comps["Text"] then
            local parts={}
            if _cupESP.showName then table.insert(parts,"🏆 Cup") end
            if _cupESP.showDist then table.insert(parts,string.format("[%.0fm]",dist)) end
            txt.Text=table.concat(parts," "); txt.Color=col; txt.Size=S.espFontSize or 14
            txt.Position=Vector2.new(sv.X,by-(S.espFontSize or 14)-2); txt.Visible=#parts>0
        else txt.Visible=false end
        hl.Enabled=comps["Highlight"] and _cupESPEnabled or false; hl.FillColor=col; hl.OutlineColor=col
    end)
    _cupESPActive[trophy]={txt=txt,box=box,hl=hl,conn=conn,
        ancConn=trophy.AncestryChanged:Connect(function(_,p) if not p then removeCupESP(trophy) end end)}
end
local function scanCupESP() local folder=_getCupFolder(); if not folder then return end; for _,t in ipairs(folder:GetChildren()) do addCupESP(t) end end
local function stopCupESP() _cupESPEnabled=false; for t in pairs(_cupESPActive) do removeCupESP(t) end end

Tog.CupESPEnabled = VizL4:Toggle({
    Name="Cup ESP", Default=false,
    Callback=function(p)
        _cupESPEnabled=p
        if p then scanCupESP(); task.spawn(function() while _cupESPEnabled do task.wait(2); scanCupESP() end end)
        else stopCupESP() end
    end
}, "CupESPEnabled")
Opt.CupESPColor    = VizL4:Colorpicker({ Name="Cup Color", Default=Color3.fromRGB(255,215,0), Alpha=0, Callback=function(c) cupESPColor=c end }, "CupESPColor")
Tog.CupESPRainbow  = VizL4:Toggle({ Name="Rainbow",  Default=false, Callback=function(p) _cupESP.rainbow=p end }, "CupESPRainbow")
Tog.CupESPShowName = VizL4:Toggle({ Name="Name",     Default=true,  Callback=function(p) _cupESP.showName=p end }, "CupESPShowName")
Tog.CupESPShowDist = VizL4:Toggle({ Name="Distance", Default=true,  Callback=function(p) _cupESP.showDist=p end }, "CupESPShowDist")
Opt.CupESPComponents = VizL4:Dropdown({ Name="Components", Multi=true, Default={"Text","Box 2D","Highlight"}, Options={"Text","Highlight","Box 2D"}, Callback=function(v) _cupESP.components=v end }, "CupESPComponents")
onUnload(function() stopCupESP() end)
VizL4:Divider()


end)()


;(function()
local _wFrameTimer=tick(); local _wFrames=0; _wFPS=60; local _wPingTimer=0; local _wPing=0
RS.RenderStepped:Connect(function()
    _wFrames=_wFrames+1; local now=tick()
    if now-_wFrameTimer>=1 then _wFPS=_wFrames; _wFrames=0; _wFrameTimer=now end
    if now-_wPingTimer>=1 then pcall(function() _wPing=math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end); _wPingTimer=now end
end)
onUnload(function()
    local _el={}; for c in pairs(espActive) do _el[#_el+1]=c end; for _,c in ipairs(_el) do removeESP(c) end
end)


local specTarget=nil; local specConn=nil
local function buildSpecList()
    local list={"--"}; for _,plr in ipairs(PS:GetPlayers()) do if plr~=LP then table.insert(list,plr.Name) end end; return list
end
Opt.SpectatePlayers = WorldL2:Dropdown({ Name="Spectate Player", Search=true, Options=buildSpecList(), Default=1, Multi=false, Callback=function(v) specTarget=type(v)=="table" and next(v) or v end }, "SpectatePlayers")
WorldL2:Button({ Name="Spectate / Stop", Callback=function()
    if specConn then pcall(function() specConn:Disconnect() end); specConn=nil
        local c=getChar(); Cam.CameraSubject=c and c:FindFirstChildOfClass("Humanoid") or c; Cam.CameraType=Enum.CameraType.Custom; return
    end
    local name=tostring(specTarget or ""); local plr=PS:FindFirstChild(name); local char=plr and plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    Cam.CameraSubject=hum; Cam.CameraType=Enum.CameraType.Custom
    specConn=plr.CharacterAdded:Connect(function(c) task.wait(0.5); local h=c:FindFirstChildOfClass("Humanoid"); if h then Cam.CameraSubject=h end end)
end})
local noFogConn=nil
Tog.NoFog = WorldL2:Toggle({
    Name="No Fog", Default=false,
    Callback=function(p)
        if noFogConn then noFogConn:Disconnect(); noFogConn=nil end
        local atmos=LT:FindFirstChildOfClass("Atmosphere")
        if p then
            LT.FogStart=1e9; LT.FogEnd=1e9
            if atmos then atmos.Density=0; atmos.Haze=0; atmos.Glare=0 end
            noFogConn=LT:GetPropertyChangedSignal("FogEnd"):Connect(function() if LT.FogEnd<1e8 then LT.FogStart=1e9; LT.FogEnd=1e9 end end)
        else
            LT.FogStart=0; LT.FogEnd=100000
            if atmos then atmos.Density=0.395; atmos.Haze=0; atmos.Glare=0 end
        end
    end
}, "NoFog")
Tog.NoAtmosphere = WorldL2:Toggle({
    Name="No Atmosphere", Default=false,
    Callback=function(p)
        pcall(function()
            local atmos=LT:FindFirstChildOfClass("Atmosphere"); if not atmos then return end
            if p then atmos.Density=0; atmos.Offset=0; atmos.Haze=0; atmos.Glare=0
            else atmos.Density=0.395; atmos.Offset=0; atmos.Haze=0; atmos.Glare=0 end
        end)
    end
}, "NoAtmosphere")
WorldL2:Divider()
local fbConn=nil
Tog.FullBright = WorldL2:Toggle({
    Name="FullBright", Default=false,
    Callback=function(p)
        if fbConn then fbConn:Disconnect(); fbConn=nil end
        if p then fbConn=RS.RenderStepped:Connect(function() LT.Brightness=S.brightness; LT.ClockTime=14; LT.FogEnd=100000; LT.GlobalShadows=false; LT.OutdoorAmbient=Color3.fromRGB(128,128,128) end)
        else LT.Brightness=1; LT.ClockTime=14; LT.FogEnd=1000000; LT.GlobalShadows=true end
    end
}, "FullBright")
Opt.Brightness = WorldL2:Slider({ Name="Brightness", Default=2, Minimum=0, Maximum=10, Precision=1, Callback=function(v) S.brightness=v end }, "Brightness")
WorldL2:Divider()
local _ambientConn=nil; local _ambientColor=Color3.fromRGB(128,128,128)
Tog.CustomAmbient = WorldL2:Toggle({
    Name="World Ambient", Default=false,
    Callback=function(p)
        if _ambientConn then _ambientConn:Disconnect(); _ambientConn=nil end
        if p then _ambientConn=RS.RenderStepped:Connect(function() LT.Ambient=_ambientColor; LT.OutdoorAmbient=_ambientColor end)
        else LT.Ambient=Color3.fromRGB(0,0,0); LT.OutdoorAmbient=Color3.fromRGB(128,128,128) end
    end
}, "CustomAmbient")
Opt.WorldAmbient = WorldL2:Colorpicker({ Name="Ambient Color", Default=Color3.fromRGB(128,128,128), Alpha=0, Callback=function(v) _ambientColor=v end }, "WorldAmbient")
WorldL2:Divider()
local freecamConns={}; local _fcPitch=0; local _fcYaw=0; local _fcPos=Vector3.zero
Tog.Freecam = WorldL2:Toggle({
    Name="Free Cam", Default=false,
    Callback=function(p)
        for _,c in ipairs(freecamConns) do pcall(function() c:Disconnect() end) end; freecamConns={}
        UIS.MouseBehavior=Enum.MouseBehavior.Default
        if not p then Cam.CameraType=Enum.CameraType.Custom; return end
        local cf=Cam.CFrame; _fcPos=cf.Position
        _fcYaw=math.atan2(-cf.LookVector.X,-cf.LookVector.Z)
        _fcPitch=math.asin(math.clamp(cf.LookVector.Y,-1,1))
        Cam.CameraType=Enum.CameraType.Scriptable
        local rmb=false
        table.insert(freecamConns,UIS.InputBegan:Connect(function(inp,gpe) if gpe then return end; if inp.UserInputType==Enum.UserInputType.MouseButton2 then rmb=true end end))
        table.insert(freecamConns,UIS.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton2 then rmb=false; UIS.MouseBehavior=Enum.MouseBehavior.Default end end))
        table.insert(freecamConns,RS.RenderStepped:Connect(function(dt)
            if rmb then local d=UIS:GetMouseDelta(); _fcYaw=_fcYaw-d.X*S.freeCamSens*0.003; _fcPitch=math.clamp(_fcPitch-d.Y*S.freeCamSens*0.003,-1.55,1.55); UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
            else UIS.MouseBehavior=Enum.MouseBehavior.Default end
            local rot=CFrame.fromEulerAnglesYXZ(_fcPitch,_fcYaw,0)
            local spd=S.freeCamSpeed*dt*20*(UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
            if UIS:IsKeyDown(Enum.KeyCode.W)           then _fcPos=_fcPos+rot.LookVector*spd  end
            if UIS:IsKeyDown(Enum.KeyCode.S)           then _fcPos=_fcPos-rot.LookVector*spd  end
            if UIS:IsKeyDown(Enum.KeyCode.A)           then _fcPos=_fcPos-rot.RightVector*spd end
            if UIS:IsKeyDown(Enum.KeyCode.D)           then _fcPos=_fcPos+rot.RightVector*spd end
            if UIS:IsKeyDown(Enum.KeyCode.Space)       then _fcPos=_fcPos+Vector3.yAxis*spd   end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then _fcPos=_fcPos-Vector3.yAxis*spd   end
            Cam.CFrame=CFrame.new(_fcPos)*rot
        end))
    end
}, "Freecam")
Opt.FreeCamSens  = WorldL2:Slider({ Name="Look Sensitivity", Default=0.3, Minimum=0.1, Maximum=5,  Precision=1, Callback=function(v) S.freeCamSens=v  end }, "FreeCamSens")
Opt.FreeCamSpeed = WorldL2:Slider({ Name="Move Speed",       Default=0.5, Minimum=0.1, Maximum=50, Precision=1, Callback=function(v) S.freeCamSpeed=v end }, "FreeCamSpeed")

Tog.FOVChanger = WorldR:Toggle({ Name="Custom FOV", Default=false, Callback=function(p) if p then Cam.FieldOfView=S.fovVal else Cam.FieldOfView=70 end end }, "FOVChanger")
Opt.FOV = WorldR:Slider({ Name="Camera FOV", Default=70, Minimum=0, Maximum=120, Precision=1, Callback=function(v) S.fovVal=v; if Tog.FOVChanger and Tog.FOVChanger.State then Cam.FieldOfView=v end end }, "FOV")
local _cursorConn=nil; local _cursorDot=nil; local _cursorRing=nil
Tog.CustomCursor = WorldR:Toggle({
    Name="Dot Cursor", Default=false,
    Callback=function(p)
        if _cursorConn then _cursorConn:Disconnect(); _cursorConn=nil end
        if _cursorDot  then _cursorDot:Remove();  _cursorDot=nil   end
        if _cursorRing then _cursorRing:Remove(); _cursorRing=nil  end
        game:GetService("UserInputService").MouseIconEnabled=not p
        if not p then return end
        _cursorDot=Drawing.new("Circle"); _cursorDot.Radius=6; _cursorDot.Filled=true; _cursorDot.Visible=true; _cursorDot.Color=Color3.new(1,1,1); _cursorDot.Transparency=1; _cursorDot.Thickness=1
        _cursorRing=Drawing.new("Circle"); _cursorRing.Radius=10; _cursorRing.Filled=false; _cursorRing.Visible=true; _cursorRing.Color=Color3.new(1,1,1); _cursorRing.Transparency=0.8; _cursorRing.Thickness=1.5
        _cursorConn=RS.RenderStepped:Connect(function()
            local mp=game:GetService("UserInputService"):GetMouseLocation()
            _cursorDot.Position=mp; _cursorRing.Position=mp
            local curCol=espColor or Color3.new(1,1,1)
            _cursorDot.Color=curCol; _cursorRing.Color=curCol
        end)
    end
}, "CustomCursor")
Tog.CursorFilled = WorldR:Toggle({ Name="Cursor Dot Filled", Default=true, Callback=function(p) if _cursorDot then _cursorDot.Filled=p end end }, "CursorFilled")
Opt.CursorSize     = WorldR:Slider({ Name="Cursor Size",  Default=6,  Minimum=1, Maximum=20, Precision=0, Callback=function(v) if _cursorDot  then _cursorDot.Radius=v  end end }, "CursorSize")
Opt.CursorRingSize = WorldR:Slider({ Name="Ring Size",    Default=10, Minimum=0, Maximum=30, Precision=0, Callback=function(v) if _cursorRing then _cursorRing.Radius=v end end }, "CursorRingSize")
WorldR:Divider()
Tog.CustomCrosshair = WorldR:Toggle({
    Name="Crosshair", Default=false,
    Callback=function(p)
        if p then
            if not getgenv()._ZHCrosshair then
                local d=Drawing.new("Square"); d.Size=Vector2.new(14,14); d.Position=Vector2.new(Cam.ViewportSize.X/2-7,Cam.ViewportSize.Y/2-7); d.Color=Color3.new(1,1,1); d.Transparency=1; d.Filled=false; d.Thickness=1; d.Visible=true
                local d2=Drawing.new("Line"); d2.From=Vector2.new(Cam.ViewportSize.X/2-6,Cam.ViewportSize.Y/2); d2.To=Vector2.new(Cam.ViewportSize.X/2+6,Cam.ViewportSize.Y/2); d2.Color=Color3.new(1,1,1); d2.Thickness=1; d2.Visible=true
                local d3=Drawing.new("Line"); d3.From=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2-6); d3.To=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2+6); d3.Color=Color3.new(1,1,1); d3.Thickness=1; d3.Visible=true
                getgenv()._ZHCrosshair={d,d2,d3}
            end
        else
            if getgenv()._ZHCrosshair then for _,d in ipairs(getgenv()._ZHCrosshair) do pcall(function() d:Remove() end) end; getgenv()._ZHCrosshair=nil end
        end
    end
}, "CustomCrosshair")

Tog.AntiLag = WorldR2:Toggle({
    Name="Anti-Lag", Default=false,
    Callback=function(p)
        pcall(function() setfpscap(p and 0 or 60) end)
        local LT3=game:GetService("Lighting")
        if p then LT3.GlobalShadows=false; LT3.Brightness=2; for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then pcall(function() v.Enabled=false end) end end
        else LT3.GlobalShadows=true end
    end
}, "AntiLag")
Opt.AntiLagFPSCap = WorldR2:Slider({ Name="FPS Cap", Default=0, Minimum=0, Maximum=360, Precision=0, Callback=function(v) pcall(function() setfpscap(v==0 and math.huge or v) end) end }, "AntiLagFPSCap")
WorldR2:Button({ Name="Boost FPS", Callback=function()
    pcall(function()
        for _,v in ipairs(game:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled=false end
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then v.Enabled=false end
        end
        LT.GlobalShadows=false; LT.Brightness=5
    end)
end})
WorldR3:Button({ Name="Copy Coordinates", Callback=function()
    local hrp=getHRP(); if not hrp then return end
    local p=hrp.Position; local str=string.format("%.2f, %.2f, %.2f",p.X,p.Y,p.Z); setclipboard(str)
end})
local nearbyConn=nil; local nearbyTracked={}; local _nearbyTimer=0
Tog.NearbyNotifier = WorldR3:Toggle({
    Name="Nearby Alert", Default=false,
    Callback=function(p)
        if nearbyConn then nearbyConn:Disconnect(); nearbyConn=nil end; nearbyTracked={}
        if not p then return end
        nearbyConn=RS.Heartbeat:Connect(function()
            local now=tick(); if now-_nearbyTimer<0.5 then return end; _nearbyTimer=now
            local myHRP=getHRP(); if not myHRP then return end
            local dist=Opt.NearbyDist and Opt.NearbyDist.Value or 500
            for _,plr in ipairs(PS:GetPlayers()) do
                if plr~=LP and plr.Character then
                    local hrp=plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local mag=(myHRP.Position-hrp.Position).Magnitude; local id=plr.UserId
                        if mag<=dist and not nearbyTracked[id] then nearbyTracked[id]=true; notify(plr.Name.." is nearby ["..math.floor(mag).."m]",6)
                        elseif mag>dist and nearbyTracked[id] then nearbyTracked[id]=nil; notify(plr.Name.." left range",3) end
                    end
                end
            end
        end)
    end
}, "NearbyNotifier")
Opt.NearbyDist = WorldR3:Slider({ Name="Alert Range", Default=500, Minimum=0, Maximum=10000, Precision=0, Callback=function() end }, "NearbyDist")

onUnload(function()
    if _ambientConn then _ambientConn:Disconnect() end
    if noFogConn then noFogConn:Disconnect(); LT.FogStart=0; LT.FogEnd=100000 end
    if fbConn then fbConn:Disconnect(); LT.GlobalShadows=true; LT.Brightness=1 end
    if specConn then specConn:Disconnect() end
    if _cursorConn then _cursorConn:Disconnect() end
    if _cursorDot  then pcall(function() _cursorDot:Remove() end) end
    if _cursorRing then pcall(function() _cursorRing:Remove() end) end
    UIS.MouseIconEnabled=true
    for _,c in ipairs(freecamConns) do pcall(function() c:Disconnect() end) end
    Cam.FieldOfView=70; Cam.CameraType=Enum.CameraType.Custom; UIS.MouseBehavior=Enum.MouseBehavior.Default
end)


Opt.Coordinates = NavL:Input({ Name="Coordinates", Placeholder="X, Y, Z", AcceptedCharacters="All", Callback=function() end }, "Coordinates")
NavL:Button({ Name="Tween To", Callback=function()
    local v=Opt.Coordinates and Opt.Coordinates.Text or ""
    local x,y,z=v:match("([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
    if x then task.spawn(function() tweenTo(CFrame.new(tonumber(x),tonumber(y),tonumber(z))) end) end
end})
NavL:Button({ Name="Copy Position", Callback=function()
    local hrp=getHRP(); if hrp then setclipboard(tostring(hrp.Position)) end
end})
NavL:Divider()
local _savedPos=nil; local _autoTPConn=nil
NavL:Button({ Name="Save Position",   Callback=function() local hrp=getHRP(); if hrp then _savedPos=hrp.CFrame end end })
NavL:Button({ Name="TP to Position",  Callback=function() if not _savedPos then return end; task.spawn(function() tweenTo(_savedPos) end) end })
Opt.AutoTPHP = NavL:Slider({ Name="HP Threshold", Default=20, Minimum=1, Maximum=99, Precision=0, Callback=function() end }, "AutoTPHP")
local _autoTPing=false
Tog.AutoTPSafe = NavL:Toggle({ Name="Auto Retreat", Default=false, Callback=function(p) if _autoTPConn then _autoTPConn:Disconnect(); _autoTPConn=nil end; if not p then return end; _autoTPConn=RS.Heartbeat:Connect(function() if not _savedPos or _autoTPing then return end; local hum=getHum(); if not hum or hum.Health<=0 then return end; if (hum.Health/hum.MaxHealth*100)<=(Opt.AutoTPHP and Opt.AutoTPHP.Value or 20) then _autoTPing=true; task.spawn(function() tweenTo(_savedPos); _autoTPing=false end) end end) end }, "AutoTPSafe")
onUnload(function() if _autoTPConn then _autoTPConn:Disconnect() end end)
NavL:Divider()
local clickTPConn=nil
Tog.ClickTP = NavL:Toggle({
    Name="Click TP", Default=false,
    Callback=function(p)
        if clickTPConn then clickTPConn:Disconnect(); clickTPConn=nil end
        if p then clickTPConn=UIS.InputBegan:Connect(function(inp,gpe)
            if gpe or inp.UserInputType~=Enum.UserInputType.MouseButton2 then return end
            local ray=Cam:ScreenPointToRay(inp.Position.X,inp.Position.Y)
            local res=workspace:Raycast(ray.Origin,ray.Direction*2000)
            if res then task.spawn(function() tweenTo(CFrame.new(res.Position+Vector3.new(0,3,0))) end) end
        end) end
    end
}, "ClickTP")

NavL:Divider()
do
    local _npcSelected=nil
    local function listNPCs()
        local list={}
        local folder=_getNPCFolder()
        if folder then for _,m in ipairs(folder:GetChildren()) do if m:IsA("Model") then table.insert(list,m.Name) end end end
        table.sort(list)
        if #list==0 then list={"-- no NPCs found --"} end
        return list
    end
    Opt.NPCTarget = NavL:Dropdown({ Name="NPC", Options=listNPCs(), Default=1, Multi=false,
        Callback=function(v)
            local sel=type(v)=="table" and next(v) or v
            _npcSelected=(sel and sel~="-- no NPCs found --" and sel~="") and sel or nil
        end }, "NPCTarget")
    NavL:Button({ Name="Refresh NPCs", Callback=function() if Opt.NPCTarget then pcall(function() Opt.NPCTarget:ClearOptions(); Opt.NPCTarget:InsertOptions(listNPCs()) end); notify("NPC list refreshed",2) end end })
    NavL:Button({ Name="TP to NPC", Callback=function()
        if not _npcSelected then notify("Select an NPC first",2); return end
        local folder=_getNPCFolder(); if not folder then notify("workspace.Instances.NPCs not found",2); return end
        local npc=folder:FindFirstChild(_npcSelected); if not npc then notify("NPC missing",2); return end
        local targetCF
        if npc:IsA("BasePart") then
            targetCF=npc.CFrame+Vector3.new(0,3,2)
        elseif npc:IsA("Model") then
            targetCF=npc:GetPivot()+Vector3.new(0,3,2)
        else
            local pp=npc:FindFirstChildWhichIsA("BasePart",true)
            if pp then targetCF=pp.CFrame+Vector3.new(0,3,2) end
        end
        if not targetCF then notify("NPC unreachable",2); return end
        task.spawn(function() tweenTo(targetCF) end)
    end })
end
NavL:Divider()
do
    local _merchSelected=nil
    local function listMerchants()
        local list={}
        local folder=workspace:FindFirstChild("WorldMerchant")
        if folder then for _,m in ipairs(folder:GetChildren()) do table.insert(list,m.Name) end end
        table.sort(list)
        if #list==0 then list={"-- no merchants found --"} end
        return list
    end
    Opt.MerchantTarget = NavL:Dropdown({ Name="World Merchant", Options=listMerchants(), Default=1, Multi=false,
        Callback=function(v)
            local sel=type(v)=="table" and next(v) or v
            _merchSelected=(sel and sel~="-- no merchants found --" and sel~="") and sel or nil
        end }, "MerchantTarget")
    NavL:Button({ Name="Refresh Merchants", Callback=function() if Opt.MerchantTarget then pcall(function() Opt.MerchantTarget:ClearOptions(); Opt.MerchantTarget:InsertOptions(listMerchants()) end); notify("Merchant list refreshed",2) end end })
    NavL:Button({ Name="TP to Merchant", Callback=function()
        if not _merchSelected then notify("Select a merchant first",2); return end
        local folder=workspace:FindFirstChild("WorldMerchant"); if not folder then notify("workspace.WorldMerchant not found",2); return end
        local m=folder:FindFirstChild(_merchSelected); if not m then notify("Merchant missing",2); return end
        local targetCF
        if m:IsA("BasePart") then
            targetCF=m.CFrame+Vector3.new(0,3,2)
        elseif m:IsA("Model") then
            targetCF=m:GetPivot()+Vector3.new(0,3,2)
        else
            local pp=m:FindFirstChildWhichIsA("BasePart",true)
            if pp then targetCF=pp.CFrame+Vector3.new(0,3,2) end
        end
        if not targetCF then notify("Merchant unreachable",2); return end
        task.spawn(function() tweenTo(targetCF) end)
    end })
end
NavL:Divider()
do
    local _locSelected=nil
    local _locMap={}
    local function cleanName(n) return (n:gsub("^LocationMarker_",""):gsub("_"," ")) end
    local function buildLocList()
        _locMap={}; local names={}
        local folder=workspace:FindFirstChild("NavigationMarkers")
        if folder then
            local seen={}
            for _,m in ipairs(folder:GetChildren()) do
                if m:IsA("Attachment") then
                    local clean=cleanName(m.Name)
                    if not seen[clean] then
                        seen[clean]=true; _locMap[clean]=m
                        table.insert(names,clean)
                    end
                end
            end
        end
        table.sort(names)
        if #names==0 then names={"-- no locations found --"} end
        return names
    end
    Opt.LocationTarget = NavL:Dropdown({ Name="Location", Search=true, Options=buildLocList(), Default=1, Multi=false,
        Callback=function(v)
            local sel=type(v)=="table" and next(v) or v
            _locSelected=(sel and sel~="-- no locations found --" and sel~="") and sel or nil
        end }, "LocationTarget")
    NavL:Button({ Name="Refresh Locations", Callback=function()
        if Opt.LocationTarget then
            pcall(function() Opt.LocationTarget:ClearOptions(); Opt.LocationTarget:InsertOptions(buildLocList()) end)
            notify("Location list refreshed",2)
        end
    end })
    NavL:Button({ Name="TP to Location", Callback=function()
        if not _locSelected then notify("Select a location first",2); return end
        local att=_locMap[_locSelected]
        if not att or not att.Parent then
            buildLocList(); att=_locMap[_locSelected]
        end
        if not att or not att.Parent then notify("Location missing",2); return end
        local target=CFrame.new(att.WorldPosition+Vector3.new(0,3,0))
        task.spawn(function() tweenTo(target) end)
    end })
end


Tog.AttachNearby = NavR:Toggle({
    Name="Attach Nearby", Default=false,
    Callback=function(p)
        if not p then return end
        task.spawn(function()
            while Tog.AttachNearby and Tog.AttachNearby.State do
                local myHRP=getHRP(); if not myHRP then task.wait(0.1); continue end
                local range=Opt.MobsRange and Opt.MobsRange.Value or 1000
                local best,bestD=nil,range
                for _,plr in ipairs(PS:GetPlayers()) do
                    if plr~=LP and plr.Character then
                        local hrp=plr.Character:FindFirstChild("HumanoidRootPart"); local hum=plr.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health>0 then local d=(myHRP.Position-hrp.Position).Magnitude; if d<bestD then best=hrp; bestD=d end end
                    end
                end
                if best then
                    local offset=CFrame.new(0,Opt.MobsHeight and Opt.MobsHeight.Value or 0,Opt.MobsDistance and Opt.MobsDistance.Value or 0)
                    myHRP.CFrame=best.CFrame*offset; myHRP.AssemblyLinearVelocity=Vector3.zero
                end
                task.wait(0.1)
            end
        end)
    end
}, "AttachNearby")
NavR:Divider()
end)()
;(function()
    local function buildAttachPlrList() local l={"--"}; for _,p in ipairs(PS:GetPlayers()) do if p~=LP then table.insert(l,p.Name) end end; return l end
    Opt.AttachTargetPlayer = NavR:Dropdown({ Name="Attach Target", Search=true, Options=buildAttachPlrList(), Default=1, Multi=false, Callback=function() end }, "AttachTargetPlayer")
end)()
Tog.AttachSelected = NavR:Toggle({
    Name="Attach Player", Default=false,
    Callback=function(p)
        if not p then return end
        task.spawn(function()
            while Tog.AttachSelected and Tog.AttachSelected.State do
                local myHRP=getHRP(); if not myHRP then task.wait(); continue end
                local val=Opt.AttachTargetPlayer and Opt.AttachTargetPlayer.Value
                local plr=type(val)=="string" and PS:FindFirstChild(val) or val
                if plr and plr~=LP and plr.Character then
                    local hrp=plr.Character:FindFirstChild("HumanoidRootPart"); local hum=plr.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health>0 then
                        local offset=CFrame.new(0,Opt.MobsHeight and Opt.MobsHeight.Value or 0,Opt.MobsDistance and Opt.MobsDistance.Value or 0)
                        tweenTo(hrp.CFrame*offset)
end
                end
                task.wait()
            end
        end)
    end
}, "AttachSelected")
Opt.MobsRange    = NavR2:Slider({ Name="Range",    Default=1000, Minimum=0,   Maximum=10000, Precision=0, Callback=function() end }, "MobsRange")
Opt.MobsDistance = NavR2:Slider({ Name="Distance", Default=0,    Minimum=-50, Maximum=50,   Precision=0, Callback=function() end }, "MobsDistance")
Opt.MobsHeight   = NavR2:Slider({ Name="Height",   Default=0,    Minimum=-50, Maximum=50,   Precision=0, Callback=function() end }, "MobsHeight")
NavR2:Divider()


onUnload(function()
    if clickTPConn then clickTPConn:Disconnect() end
    if nearbyConn then nearbyConn:Disconnect() end
end)


-- ── Combat section (Auto M1 via packet vuln) ────────────────────────────────
Tog.AutoM1 = GameR_Combat:Toggle({ Name="Auto M1", Default=false,
    Callback=function(p) getgenv()._DB_autoM1=p end }, "AutoM1")
Opt.AutoM1Range = GameR_Combat:Slider({ Name="Range", Default=100, Minimum=10, Maximum=1000, Precision=0,
    Callback=function(v) _DB_autoM1Range=v end }, "AutoM1Range")


GameR2:Divider()
local _ownHighlights={}; local _ownVizConn=nil
local _ownedColor=Color3.fromRGB(0,255,0); local _notOwnedColor=Color3.fromRGB(255,0,0)
local function hasNetworkOwnership(part)
    if isnetworkowner then local ok,r=pcall(isnetworkowner,part); return ok and r end
    local ok,result=pcall(function()
        local myHRP2=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP2 then return false end
        local ok1,myId=pcall(gethiddenproperty,myHRP2,"NetworkOwnerV3"); local ok2,partId=pcall(gethiddenproperty,part,"NetworkOwnerV3")
        return ok1 and ok2 and myId~=nil and myId==partId
    end)
    return ok and result
end
local function updateOwnershipViz()
    for part,hl in pairs(_ownHighlights) do if not part or not part.Parent then pcall(function() hl:Destroy() end); _ownHighlights[part]=nil end end
    local ents=_getMobFolder(); if not ents then return end
    for _,model in ipairs(ents:GetChildren()) do
        if not model:IsA("Model") then continue end
        local hrp2=model:FindFirstChild("HumanoidRootPart"); if not hrp2 then continue end
        if not _ownHighlights[hrp2] then local hl2=Instance.new("Highlight",model); hl2.FillTransparency=0.7; _ownHighlights[hrp2]=hl2 end
        local hl2=_ownHighlights[hrp2]
        local owned=pcall(hasNetworkOwnership,hrp2) and hasNetworkOwnership(hrp2)
        hl2.FillColor=owned and _ownedColor or _notOwnedColor
        hl2.OutlineColor=hl2.FillColor
    end
end
Tog.ShowOwnership = GameR2:Toggle({
    Name="Show Ownership", Default=false,
    Callback=function(p)
        if p then
            if not _ownVizConn then _ownVizConn=RS.Heartbeat:Connect(function() if Tog.ShowOwnership and Tog.ShowOwnership.State then updateOwnershipViz() end end) end
        else
            if _ownVizConn then _ownVizConn:Disconnect(); _ownVizConn=nil end
            for _,hl2 in pairs(_ownHighlights) do pcall(function() hl2:Destroy() end) end; _ownHighlights={}
        end
    end
}, "ShowOwnership")
GameR2:Divider()
Opt.OwnedColor    = GameR2:Colorpicker({ Name="Owned Color",     Default=Color3.fromRGB(0,255,0), Alpha=0, Callback=function(c) _ownedColor=c    end }, "OwnedColor")
Opt.NotOwnedColor = GameR2:Colorpicker({ Name="Not Owned Color", Default=Color3.fromRGB(255,0,0), Alpha=0, Callback=function(c) _notOwnedColor=c end }, "NotOwnedColor")
onUnload(function()
    if _ownVizConn then _ownVizConn:Disconnect() end
    for _,hl2 in pairs(_ownHighlights) do pcall(function() hl2:Destroy() end) end
end)


WorldL3:Label({ Text="Job ID: "..tostring(game.JobId) })
WorldL3:Button({ Name="Copy Job ID", Callback=function()
    if setclipboard then setclipboard(tostring(game.JobId)); notify("Job ID copied",2) end
end})
WorldL3:Button({ Name="Server Hop", Callback=function() serverHop() end })
WorldL3:Button({ Name="Rejoin", Callback=function()
    pcall(function() TP:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
end})
WorldL3:Divider()
do
    local _hopConn=nil; local _hopRadius=20
    Tog.AutoHop = WorldL3:Toggle({ Name="Hop on Player Near", Default=false, Callback=function(p)
        if _hopConn then _hopConn:Disconnect(); _hopConn=nil end
        if not p then return end
        _hopConn=RS.Heartbeat:Connect(function()
            local char=LP.Character; if not char then return end
            local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            for _,plr in ipairs(PS:GetPlayers()) do
                if plr~=LP and plr.Character then
                    local orp=plr.Character:FindFirstChild("HumanoidRootPart")
                    if orp and (hrp.Position-orp.Position).Magnitude<=_hopRadius then
                        _hopConn:Disconnect(); _hopConn=nil
                        Tog.AutoHop:UpdateState(false)
                        serverHop(); return
                    end
                end
            end
        end)
    end }, "AutoHop")
    Opt.HopRadius = WorldL3:Slider({ Name="Radius", Default=20, Minimum=5, Maximum=150, Precision=0, Callback=function(v) _hopRadius=v end }, "HopRadius")
    onUnload(function() if _hopConn then _hopConn:Disconnect(); _hopConn=nil end end)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- STATS TAB
-- ══════════════════════════════════════════════════════════════════════════════
do
    local StatsL = Tabs.Stats:Section({Side="Left",  Name="Player Stats", Image="user"})
    local StatsR = Tabs.Stats:Section({Side="Right", Name="Attributes",   Image="list"})

    local USEFUL_ATTRS = {
        "Race","SubRace","Rank","ELO","Guild","Title","CurrentState","ZanpakutoState","Health","MaxHealth",
        "MissionExperience","RankExperience","Reiatsu","MaxReiatsu","Strength","Defense","Speed","Intelligence",
        "Hogyoku","HogyokuFragments","Prestige","KillStreak","Deaths","Kills","Wins","Losses",
        "Element","SubElement","ElementMastery","ElementLevel","RaidExperience","RaidLevel","RaidWins","RaidLosses",
        "RaidKills","RaidStreak","RaidRank","Division","Faction","VerifiedDevilHunter","CharacterName","InNoPvpZone","Loaded",
    }
    local _statsSelected=nil
    local _attrLabels={}
    local _statusLbl=StatsR:Label({ Text="" })
    local MAX_LABELS=40
    for i=1,MAX_LABELS do _attrLabels[i]=StatsR:Label({ Text="" }) end

    local function getEntityModel(name)
        local folder=_getMobFolder()
        if not folder then return nil end
        local ent=folder:FindFirstChild(name); if ent then return ent end
        for _,plr in ipairs(PS:GetPlayers()) do if plr.Name==name and plr.Character then local c=folder:FindFirstChild(plr.Character.Name); if c then return c end end end
        return nil
    end
    local function setLbl(lbl,txt) pcall(function() if lbl.UpdateName then lbl:UpdateName(txt) elseif lbl.SetText then lbl:SetText(txt) end end) end
    local function displayStats(name)
        for i=1,MAX_LABELS do setLbl(_attrLabels[i],""); pcall(function() _attrLabels[i]:SetVisibility(false) end) end
        setLbl(_statusLbl,"")
        if not name then return end
        local attrs={}
        local function mergeAttrs(obj) if obj then pcall(function() for k,v in pairs(obj:GetAttributes()) do attrs[k]=v end end) end end
        local plr=PS:FindFirstChild(name)
        if plr then
            mergeAttrs(plr)
            local char=plr.Character; if char then mergeAttrs(char); local hum=char:FindFirstChildOfClass("Humanoid"); if hum then mergeAttrs(hum) end end
            local ls=plr:FindFirstChild("leaderstats"); if ls then for _,v in ipairs(ls:GetChildren()) do if v:IsA("ValueBase") then attrs[v.Name]=v.Value end end end
        end
        local ent=getEntityModel(name); mergeAttrs(ent)
        if ent then local hum2=ent:FindFirstChildOfClass("Humanoid"); if hum2 then mergeAttrs(hum2) end end
        if not next(attrs) then setLbl(_statusLbl,"No attributes found for "..name); return end
        setLbl(_statusLbl,"Showing: "..name)
        local i=1
        for _,k in ipairs(USEFUL_ATTRS) do
            if i>MAX_LABELS then break end
            local v=attrs[k]
            if v~=nil and tostring(v)~="" then setLbl(_attrLabels[i],"<font color=\"rgb(180,130,240)\">"..k.."</font>  "..tostring(v)); pcall(function() _attrLabels[i]:SetVisibility(true) end); i=i+1 end
        end
        local usefulSet={}; for _,k in ipairs(USEFUL_ATTRS) do usefulSet[k]=true end
        local extras={}; for k in pairs(attrs) do if not usefulSet[k] then table.insert(extras,k) end end
        table.sort(extras)
        for _,k in ipairs(extras) do
            if i>MAX_LABELS then break end
            local v=attrs[k]
            if v~=nil and tostring(v)~="" then setLbl(_attrLabels[i],"<font color=\"rgb(140,140,180)\">"..k.."</font>  "..tostring(v)); pcall(function() _attrLabels[i]:SetVisibility(true) end); i=i+1 end
        end
        if i==1 then setLbl(_statusLbl,"No attributes found for "..name) end
    end
    local _attrConns={}
    local function rebindAttrWatcher(name)
        for _,c in ipairs(_attrConns) do pcall(function() c:Disconnect() end) end; _attrConns={}
        if not name then return end
        local function watchObj(obj) if not obj then return end; pcall(function() table.insert(_attrConns,obj.AttributeChanged:Connect(function() displayStats(name) end)) end) end
        local plr=PS:FindFirstChild(name)
        if plr then watchObj(plr); local char=plr.Character; if char then watchObj(char); local hum=char:FindFirstChildOfClass("Humanoid"); if hum then watchObj(hum) end end end
        local ent=getEntityModel(name); watchObj(ent); if ent then local hum2=ent:FindFirstChildOfClass("Humanoid"); if hum2 then watchObj(hum2) end end
    end
    local function getPlayerList()
        local list={"-- Select --",LP.Name}
        for _,plr in ipairs(PS:GetPlayers()) do if plr~=LP then table.insert(list,plr.Name) end end
        return list
    end
    Opt.StatsTarget = StatsL:Dropdown({ Name="Select Player", Options=getPlayerList(), Default=1, Multi=false,
        Callback=function(v)
            local sel=type(v)=="table" and next(v) or v
            _statsSelected=(sel~="-- Select --" and sel~="") and sel or nil
            displayStats(_statsSelected); rebindAttrWatcher(_statsSelected)
        end }, "StatsTarget")
    StatsL:Button({ Name="Refresh Stats", Callback=function() if not _statsSelected then notify("Select a player first",2); return end; displayStats(_statsSelected); notify("Refreshed: ".._statsSelected,2) end })
    StatsL:Button({ Name="Refresh Players", Callback=function() if Opt.StatsTarget then pcall(function() Opt.StatsTarget:ClearOptions(); Opt.StatsTarget:InsertOptions(getPlayerList()) end) end; notify("Player list refreshed",2) end })
    PS.PlayerAdded:Connect(function() task.defer(function() if Opt.StatsTarget then pcall(function() Opt.StatsTarget:ClearOptions(); Opt.StatsTarget:InsertOptions(getPlayerList()) end) end end) end)
    PS.PlayerRemoving:Connect(function() task.defer(function() if Opt.StatsTarget then pcall(function() Opt.StatsTarget:ClearOptions(); Opt.StatsTarget:InsertOptions(getPlayerList()) end) end end) end)
    onUnload(function() for _,c in ipairs(_attrConns) do pcall(function() c:Disconnect() end) end end)
end


SettL:Header({ Text="Interface" })
SettL:Button({ Name="Unload", Callback=function() Window:Unload() end })
SettL:Divider()
Tog.HideUI = SettL:Toggle({
    Name="Hide UI", Default=false,
    Callback=function(p)
        Window:SetState(not p)
    end
}, "HideUI")
SettL:Divider()
SettL:Slider({ Name="UI Transparency", Default=5, Minimum=0, Maximum=50, Precision=0,
    Callback=function(v) Window:SetTransparency(v / 100) end
})
SettL:Divider()

;(function()
    local _streamerConn=nil; local _streamerRespawnConn=nil
    local function hideChestNames()
        local di=workspace:FindFirstChild("DialogueInteractables"); if not di then return end
        for _,m in ipairs(di:GetChildren()) do
            pcall(function() m.ChestUI.Container.PlayerName.Visible=false end)
        end
    end
    Tog.StreamerMode = SettL:Toggle({
        Name="Streamer Mode", Default=false,
        Callback=function(p)
            if _streamerConn then _streamerConn:Disconnect(); _streamerConn=nil end
            if _streamerRespawnConn then _streamerRespawnConn:Disconnect(); _streamerRespawnConn=nil end
            local nameLabel=LP.PlayerGui:FindFirstChild("MainUI",true) and LP.PlayerGui.MainUI.HUDContainer.TopLeftDetailsContainer:FindFirstChild("PlayerName")
            if p then
                if nameLabel then nameLabel.Visible=false end
                hideChestNames()
                local di=workspace:FindFirstChild("DialogueInteractables")
                if di then
                    _streamerConn=di.DescendantAdded:Connect(function(d)
                        if d.Name=="PlayerName" then task.wait(); pcall(function() d.Visible=false end) end
                    end)
                end
                _streamerRespawnConn=LP.CharacterAdded:Connect(function(nc)
                    if nameLabel then nameLabel.Visible=false end
                end)
            else
                if nameLabel then nameLabel.Visible=true end
                local di=workspace:FindFirstChild("DialogueInteractables")
                if di then
                    for _,m in ipairs(di:GetChildren()) do
                        pcall(function() m.ChestUI.Container.PlayerName.Visible=true end)
                    end
                end
            end
        end
    }, "StreamerMode")
    onUnload(function()
        if _streamerConn then _streamerConn:Disconnect() end
        if _streamerRespawnConn then _streamerRespawnConn:Disconnect() end
    end)
end)()

SettL:Divider()
MacLib:SetFolder("ZeroHub/configs")
Tabs.Settings:InsertConfigSection("Left")

local SettR2 = Tabs.Settings:Section({ Side="Right", Name="Theme", Image="palette" })

SettR:Header({ Text="Controls" })
SettR:Keybind({ Name="Menu Toggle", Default=Enum.KeyCode.F5,
    onBinded=function(k) Window:SetKeybind(k) end
}, "KbMenu")

SettR2:Header({ Text="Theme" })
SettR2:Colorpicker({ Name="Accent Color", Default=Color3.fromRGB(138,79,255), Alpha=0,
    Callback=function(c)
        MacLib:SetAccent(c)
    end
}, "ThemeAccent")
MacLib.Options["ThemeAccent"].ThemeOnly = true
SettR2:Colorpicker({ Name="Background", Default=Color3.fromRGB(12,12,12), Alpha=0,
    Callback=function(c)
        MacLib:SetScheme("BackgroundColor", c)
    end
}, "ThemeBG")
MacLib.Options["ThemeBG"].ThemeOnly = true
SettR2:Colorpicker({ Name="Main Color", Default=Color3.fromRGB(24,24,24), Alpha=0,
    Callback=function(c)
        MacLib:SetScheme("MainColor", c)
    end
}, "ThemeMain")
MacLib.Options["ThemeMain"].ThemeOnly = true
SettR2:Colorpicker({ Name="Outline Color", Default=Color3.fromRGB(45,45,45), Alpha=0,
    Callback=function(c)
        MacLib:SetScheme("OutlineColor", c)
    end
}, "ThemeOutline")
MacLib.Options["ThemeOutline"].ThemeOnly = true


Window:SetTitleUpdater(function(c)
    local r, g, b = math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    local r2 = math.min(255, math.floor(r*1.6))
    local g2 = math.min(255, math.floor(g*1.6))
    local b2 = math.min(255, math.floor(b*1.6))
    local chars = {"Z","e","r","o"," ","H","u","b"}
    local result = ""
    for i, ch in ipairs(chars) do
        local t = (i-1)/(#chars-1)
        local cr = math.floor(r2 + (r-r2)*t)
        local cg = math.floor(g2 + (g-g2)*t)
        local cb = math.floor(b2 + (b-b2)*t)
        if ch == " " then result = result .. " "
        else result = result .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', cr, cg, cb, ch) end
    end
    Window:UpdateTitle(result)
end)


Tabs.Game:Select()
task.defer(function()
    task.wait(3)
    MacLib:LoadAutoLoadConfig()

    -- ── Community Config Sharing ──────────────────────────────────────────────
    do
        local _HS3=game:GetService("HttpService")
        local _req3=request or (syn and syn.request)
        local _CFGURL="https://configs-50ca3-default-rtdb.firebaseio.com/configs"
        local function _anonId()
            local n=0; for c in tostring(LP.UserId):gmatch(".") do n=(n*31+c:byte())%0xFFFFFF end
            return string.format("%06x",n)
        end
        -- wrap SaveConfig to auto-push to Firebase
        local _origSave=MacLib.SaveConfig
        MacLib.SaveConfig=function(self,Path)
            local ok,err=_origSave(self,Path)
            if ok and Path and _req3 and readfile and isfile then
                task.spawn(function()
                    pcall(function()
                        local fullPath=MacLib.Folder.."/settings/"..Path..".json"
                        if not isfile(fullPath) then return end
                        local raw=readfile(fullPath)
                        local anonId=_anonId()
                        local key=anonId.."_"..Path:gsub("[^%w_%-]","_")
                        local payload=_HS3:JSONEncode({name=Path,by=anonId,config=raw,timestamp=os.time()*1000})
                        pcall(_req3,{Url=_CFGURL.."/"..key..".json",Method="PUT",Headers={["Content-Type"]="application/json"},Body=payload})
                    end)
                end)
            end
            return ok,err
        end
    end
end)

