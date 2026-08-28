local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DISCORD = "https://discord.gg/XcqwDDm3j"
local ACCENT = Color3.fromRGB(108, 140, 255)
local ACCENT2 = Color3.fromRGB(168, 116, 255)

local function hiddenHost()
    local h
    pcall(function()
        h = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
    end)
    return h or game:GetService("CoreGui")
end

local function randName(len)
    local set = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local t = {}
    for i = 1, len do
        local j = math.random(1, #set)
        t[i] = set:sub(j, j)
    end
    return table.concat(t)
end

local function make(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            o[k] = v
        end
    end
    for _, c in ipairs(children or {}) do
        c.Parent = o
    end
    o.Parent = props.Parent
    return o
end

local function tween(o, props, time, style, dir)
    local info = TweenInfo.new(
        time or 0.2,
        style or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(o, info, props)
    t:Play()
    return t
end

local function copyLink(text)
    local fns = {}
    if type(setclipboard) == "function" then
        fns[#fns + 1] = setclipboard
    end
    if type(toclipboard) == "function" then
        fns[#fns + 1] = toclipboard
    end
    if type(set_clipboard) == "function" then
        fns[#fns + 1] = set_clipboard
    end
    for _, fn in ipairs(fns) do
        if pcall(fn, text) then
            return true
        end
    end
    return false
end

local BROWSER_CMDS = {
    'start chrome "%s"',
    'cmd /c start chrome "%s"',
    'cmd /c start msedge "%s"',
    'cmd /c start "" "%s"',
}

local function shellOpen(url)
    local exec = shell_execute or shellexecute or shell_exec
    if type(exec) ~= "function" then
        return false
    end
    for _, fmt in ipairs(BROWSER_CMDS) do
        if pcall(exec, string.format(fmt, url)) then
            return true
        end
    end
    return false
end

local function openBrowser(url)
    if shellOpen(url) then
        return true
    end
    local direct = {}
    if type(openlink) == "function" then
        direct[#direct + 1] = openlink
    end
    if type(open_link) == "function" then
        direct[#direct + 1] = open_link
    end
    if type(openurl) == "function" then
        direct[#direct + 1] = openurl
    end
    for _, fn in ipairs(direct) do
        if pcall(fn, url) then
            return true
        end
    end
    local ok = pcall(function()
        game:GetService("GuiService"):OpenBrowserWindow(url)
    end)
    return ok
end

local env = getgenv and getgenv() or nil
if env and typeof(env.__shard_loader) == "Instance" then
    pcall(function()
        env.__shard_loader:Destroy()
    end)
end

math.randomseed(tick() % 1 * 1e7 + tick())

local LP = Players.LocalPlayer

local screen = make("ScreenGui", {
    Name = randName(math.random(9, 14)),
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = hiddenHost(),
})

if env then
    env.__shard_loader = screen
end

local backdrop = make("Frame", {
    Name = "Backdrop",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(2, 3, 6),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = screen,
}, {
    make("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 0.22),
        }),
    }),
})

local holderScale = make("UIScale", { Scale = 0.86 })

local holder = make("Frame", {
    Name = "Holder",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(500, 344),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = screen,
}, { holderScale })

local glowOuter = make("UIStroke", { Color = ACCENT, Thickness = 8, Transparency = 1 })
local glowInner = make("UIStroke", { Color = ACCENT2, Thickness = 2, Transparency = 1 })

make("Frame", {
    Name = "GlowFar",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 30, 1, 30),
    BackgroundTransparency = 1,
    ZIndex = 1,
    Parent = holder,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 34) }),
    glowOuter,
})

make("Frame", {
    Name = "GlowNear",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 8, 1, 8),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = holder,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 24) }),
    glowInner,
})

local cardStroke = make("UIStroke", {
    Color = Color3.fromRGB(48, 53, 70),
    Thickness = 1.5,
    Transparency = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

local card = make("Frame", {
    Name = "Card",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(14, 15, 21),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
    Parent = holder,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 20) }),
    cardStroke,
    make("UIGradient", {
        Rotation = 118,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 31, 44)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 16, 23)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 10, 14)),
        }),
    }),
})

local aura = make("Frame", {
    Name = "Aura",
    Size = UDim2.new(1, 0, 0, 150),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = card,
}, {
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(ACCENT2, ACCENT),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.86),
            NumberSequenceKeypoint.new(0.4, 0.95),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }),
})

local shardLayer = make("Frame", {
    Name = "Shards",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 4,
    Parent = card,
})

local shards = {}
for i = 1, 10 do
    local edge = math.random(5, 15)
    shards[i] = make("Frame", {
        Name = "Shard",
        Size = UDim2.fromOffset(edge, edge),
        Position = UDim2.fromScale(math.random() * 0.94, math.random() * 0.94),
        Rotation = math.random(0, 180),
        BackgroundColor3 = i % 2 == 0 and ACCENT2 or ACCENT,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = shardLayer,
    }, {
        make("UICorner", { CornerRadius = UDim.new(0, 2) }),
    })
end

local rail = make("Frame", {
    Name = "Rail",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 0, 0.5, 0),
    Size = UDim2.new(0, 3, 1, -80),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = card,
}, {
    make("UICorner", { CornerRadius = UDim.new(1, 0) }),
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(ACCENT2, ACCENT) }),
})

local barGradient = make("UIGradient", {
    Color = ColorSequence.new(ACCENT, ACCENT2),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.06),
        NumberSequenceKeypoint.new(1, 1),
    }),
})

local bar = make("Frame", {
    Name = "Bar",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    Size = UDim2.new(1, -70, 0, 2),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 7,
    Parent = card,
}, { barGradient })

local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 88),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local avatarStroke = make("UIStroke", {
    Color = ACCENT,
    Thickness = 1.5,
    Transparency = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

local avatar = make("ImageLabel", {
    Name = "Avatar",
    Position = UDim2.new(0, 26, 0, 25),
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = Color3.fromRGB(24, 26, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LP.UserId) .. "&w=48&h=48",
    ImageTransparency = 1,
    ZIndex = 7,
    Parent = header,
}, {
    make("UICorner", { CornerRadius = UDim.new(1, 0) }),
    avatarStroke,
})

local brand = make("TextLabel", {
    Name = "Brand",
    Position = UDim2.new(0, 78, 0, 24),
    Size = UDim2.new(0, 260, 0, 24),
    BackgroundTransparency = 1,
    RichText = true,
    Text = 'SHARD<font color="#A874FF">HUB</font>',
    Font = Enum.Font.GothamBlack,
    TextSize = 23,
    TextColor3 = Color3.fromRGB(242, 245, 252),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTransparency = 1,
    ZIndex = 7,
    Parent = header,
})

local userLine = make("TextLabel", {
    Name = "User",
    Position = UDim2.new(0, 79, 0, 48),
    Size = UDim2.new(0, 260, 0, 16),
    BackgroundTransparency = 1,
    Text = "@" .. LP.Name,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(112, 120, 142),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTransparency = 1,
    ZIndex = 7,
    Parent = header,
})

local close = make("TextButton", {
    Name = "Close",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -26, 0, 45),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Color3.fromRGB(28, 31, 42),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(128, 136, 156),
    TextTransparency = 1,
    ZIndex = 8,
    Parent = header,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 9) }),
})

local divTop = make("Frame", {
    Name = "DividerTop",
    Position = UDim2.new(0, 26, 0, 88),
    Size = UDim2.new(1, -52, 0, 1),
    BackgroundColor3 = Color3.fromRGB(36, 40, 53),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = card,
})

local headline = make("TextLabel", {
    Name = "Headline",
    Position = UDim2.new(0, 27, 0, 112),
    Size = UDim2.new(1, -54, 0, 58),
    BackgroundTransparency = 1,
    RichText = true,
    Text = 'Join our Discord to get the script, it is still <font color="#6C8CFF">keyless</font>.',
    Font = Enum.Font.GothamMedium,
    TextSize = 19,
    LineHeight = 1.22,
    TextColor3 = Color3.fromRGB(186, 194, 212),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    TextTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local btnWrap = make("Frame", {
    Name = "ButtonWrap",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 190),
    Size = UDim2.fromOffset(444, 52),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local btnGlowStroke = make("UIStroke", { Color = ACCENT, Thickness = 7, Transparency = 1 })

make("Frame", {
    Name = "ButtonGlow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 8, 1, 8),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = btnWrap,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 17) }),
    btnGlowStroke,
})

local btnStroke = make("UIStroke", {
    Color = ACCENT2:Lerp(Color3.new(1, 1, 1), 0.35),
    Thickness = 1,
    Transparency = 1,
})

local btnGradient = make("UIGradient", {
    Rotation = 20,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ACCENT2),
        ColorSequenceKeypoint.new(0.5, ACCENT),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 96, 214)),
    }),
})

local sheenGradient = make("UIGradient", {
    Rotation = 22,
    Offset = Vector2.new(-1, 0),
    Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.42, 1),
        NumberSequenceKeypoint.new(0.5, 0.58),
        NumberSequenceKeypoint.new(0.58, 1),
        NumberSequenceKeypoint.new(1, 1),
    }),
})

local sheen = make("Frame", {
    Name = "Sheen",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 8,
}, { sheenGradient })

local topLine = make("Frame", {
    Name = "TopLine",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 1),
    Size = UDim2.new(1, -28, 0, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 9,
}, {
    make("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }),
})

local btnLabel = make("TextLabel", {
    Name = "Label",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "GET KEYLESS SCRIPT",
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextTransparency = 1,
    ZIndex = 10,
})

local button = make("TextButton", {
    Name = "Action",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    ClipsDescendants = true,
    Text = "",
    ZIndex = 7,
    Parent = btnWrap,
}, {
    make("UICorner", { CornerRadius = UDim.new(0, 14) }),
    btnGradient,
    btnStroke,
    sheen,
    topLine,
    btnLabel,
})

local link = make("TextLabel", {
    Name = "Link",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 256),
    Size = UDim2.new(0, 340, 0, 16),
    BackgroundTransparency = 1,
    Text = "discord.gg/XcqwDDm3j",
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(108, 116, 138),
    TextTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local divBottom = make("Frame", {
    Name = "DividerBottom",
    Position = UDim2.new(0, 26, 0, 294),
    Size = UDim2.new(1, -52, 0, 1),
    BackgroundColor3 = Color3.fromRGB(30, 33, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = card,
})

local footer = make("TextLabel", {
    Name = "Footer",
    Position = UDim2.new(0, 27, 0, 310),
    Size = UDim2.new(1, -150, 0, 16),
    BackgroundTransparency = 1,
    Text = "Shard Hub \u{00B7} Steal an Egg",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(84, 91, 108),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local status = make("TextLabel", {
    Name = "Status",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -40, 0, 310),
    Size = UDim2.new(0, 140, 0, 16),
    BackgroundTransparency = 1,
    Text = "READY",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(100, 108, 128),
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTransparency = 1,
    ZIndex = 6,
    Parent = card,
})

local dot = make("Frame", {
    Name = "Dot",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -27, 0, 318),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = ACCENT,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = card,
}, {
    make("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

local running = true
local closing = false
local busy = false

local function fitScale()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return math.max(0.6, math.min(1, (vp.X - 56) / 500, (vp.Y - 56) / 344))
end

local baseScale = fitScale()

local reveal = {
    { bar, "BackgroundTransparency", 0 },
    { rail, "BackgroundTransparency", 0.15 },
    { avatar, "BackgroundTransparency", 0 },
    { avatar, "ImageTransparency", 0 },
    { avatarStroke, "Transparency", 0.35 },
    { brand, "TextTransparency", 0 },
    { userLine, "TextTransparency", 0 },
    { close, "BackgroundTransparency", 0 },
    { close, "TextTransparency", 0 },
    { divTop, "BackgroundTransparency", 0.4 },
    { headline, "TextTransparency", 0 },
    { button, "BackgroundTransparency", 0 },
    { btnStroke, "Transparency", 0.45 },
    { topLine, "BackgroundTransparency", 0 },
    { btnLabel, "TextTransparency", 0 },
    { btnGlowStroke, "Transparency", 0.88 },
    { link, "TextTransparency", 0 },
    { divBottom, "BackgroundTransparency", 0.45 },
    { footer, "TextTransparency", 0 },
    { status, "TextTransparency", 0 },
    { dot, "BackgroundTransparency", 0 },
}

local function sweep()
    sheenGradient.Offset = Vector2.new(-1, 0)
    tween(sheenGradient, { Offset = Vector2.new(1, 0) }, 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function dismiss()
    if closing then
        return
    end
    closing = true
    running = false
    tween(backdrop, { BackgroundTransparency = 1 }, 0.3)
    tween(holderScale, { Scale = baseScale * 0.92 }, 0.32)
    for _, d in ipairs(holder:GetDescendants()) do
        if d:IsA("ImageLabel") then
            tween(d, { ImageTransparency = 1, BackgroundTransparency = 1 }, 0.24)
        elseif d:IsA("TextLabel") or d:IsA("TextButton") then
            tween(d, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.24)
        elseif d:IsA("Frame") then
            tween(d, { BackgroundTransparency = 1 }, 0.24)
        elseif d:IsA("UIStroke") then
            tween(d, { Transparency = 1 }, 0.24)
        end
    end
    task.delay(0.38, function()
        if env and env.__shard_loader == screen then
            env.__shard_loader = nil
        end
        screen:Destroy()
    end)
end

holderScale.Scale = baseScale * 0.86

tween(backdrop, { BackgroundTransparency = 0.48 }, 0.45)
tween(holderScale, { Scale = baseScale }, 0.62, Enum.EasingStyle.Back)
tween(card, { BackgroundTransparency = 0 }, 0.4)
tween(cardStroke, { Transparency = 0.1 }, 0.5)
tween(aura, { BackgroundTransparency = 0 }, 0.75)
tween(glowOuter, { Transparency = 0.92 }, 0.75)
tween(glowInner, { Transparency = 0.72 }, 0.75)

for i, s in ipairs(reveal) do
    task.delay(0.08 + i * 0.022, function()
        if not closing then
            tween(s[1], { [s[2]] = s[3] }, 0.35)
        end
    end)
end

task.delay(0.72, sweep)

task.spawn(function()
    for i, s in ipairs(shards) do
        task.delay(0.4 + i * 0.05, function()
            if not closing then
                tween(s, { BackgroundTransparency = 0.9 }, 1.1)
            end
        end)
    end
    while running do
        for _, s in ipairs(shards) do
            tween(s, {
                Position = UDim2.fromScale(math.random() * 0.94, math.random() * 0.94),
                Rotation = s.Rotation + math.random(-120, 120),
            }, math.random(42, 72) / 10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        end
        task.wait(4.6)
    end
end)

task.spawn(function()
    while running do
        task.wait(2)
        if not running then
            break
        end
        tween(glowOuter, { Transparency = 0.84 }, 1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        tween(glowInner, { Transparency = 0.58 }, 1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(1.8)
        if not running then
            break
        end
        tween(glowOuter, { Transparency = 0.93 }, 1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        tween(glowInner, { Transparency = 0.74 }, 1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    end
end)

task.spawn(function()
    while running do
        task.wait(2.8)
        if not running then
            break
        end
        barGradient.Offset = Vector2.new(-1, 0)
        tween(barGradient, { Offset = Vector2.new(1, 0) }, 2.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    end
end)

task.spawn(function()
    while running do
        task.wait(1.2)
        if not running then
            break
        end
        tween(dot, { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 0.4 }, 0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(0.6)
        if not running then
            break
        end
        tween(dot, { Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 0 }, 0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    end
end)

local dragging = false
local dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = holder.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging or closing then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        holder.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + d.X,
            startPos.Y.Scale,
            startPos.Y.Offset + d.Y
        )
    end
end)

button.MouseEnter:Connect(function()
    if closing then
        return
    end
    tween(btnWrap, { Size = UDim2.fromOffset(452, 54) }, 0.18)
    tween(btnGlowStroke, { Transparency = 0.66 }, 0.18)
    tween(btnStroke, { Transparency = 0.2 }, 0.18)
    sweep()
end)

button.MouseLeave:Connect(function()
    if closing then
        return
    end
    tween(btnWrap, { Size = UDim2.fromOffset(444, 52) }, 0.22)
    tween(btnGlowStroke, { Transparency = 0.88 }, 0.22)
    tween(btnStroke, { Transparency = 0.45 }, 0.22)
end)

button.MouseButton1Down:Connect(function()
    tween(btnWrap, { Size = UDim2.fromOffset(434, 49) }, 0.09)
end)

button.MouseButton1Up:Connect(function()
    tween(btnWrap, { Size = UDim2.fromOffset(452, 54) }, 0.2, Enum.EasingStyle.Back)
end)

close.MouseEnter:Connect(function()
    tween(close, {
        BackgroundColor3 = Color3.fromRGB(198, 68, 92),
        TextColor3 = Color3.fromRGB(255, 255, 255),
    }, 0.16)
end)

close.MouseLeave:Connect(function()
    tween(close, {
        BackgroundColor3 = Color3.fromRGB(28, 31, 42),
        TextColor3 = Color3.fromRGB(128, 136, 156),
    }, 0.2)
end)

close.MouseButton1Click:Connect(dismiss)

button.MouseButton1Click:Connect(function()
    if busy or closing then
        return
    end
    busy = true

    local copied = copyLink(DISCORD)
    local opened = openBrowser(DISCORD)

    local label = "LINK COPIED"
    local mark = "COPIED"
    if opened then
        label = "OPENING DISCORD"
        mark = "BROWSER"
    elseif not copied then
        label = "COPY IT BELOW"
        mark = "MANUAL"
    end

    btnLabel.Text = label
    status.Text = mark
    sweep()
    tween(status, { TextColor3 = ACCENT }, 0.2)
    tween(link, { TextColor3 = ACCENT, TextTransparency = 0 }, 0.25)
    tween(btnGlowStroke, { Transparency = 0.5 }, 0.2)

    task.delay(2.8, function()
        if closing then
            return
        end
        btnLabel.Text = "GET KEYLESS SCRIPT"
        status.Text = "READY"
        tween(status, { TextColor3 = Color3.fromRGB(100, 108, 128) }, 0.3)
        tween(link, { TextColor3 = Color3.fromRGB(108, 116, 138) }, 0.3)
        tween(btnGlowStroke, { Transparency = 0.88 }, 0.3)
        busy = false
    end)
end)
