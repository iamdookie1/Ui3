--[[
    Velvet  ·  ui v2
    A frosted-glass interface with a rose accent: sidebar navigation, a profile chip,
    big page headers, glass panels and a status bar with a split action button.

    Usage:
        local Velvet = loadstring(game:HttpGet("<raw url to ui v2/ui.lua>"))()

        local Window = Velvet:CreateWindow({
            Title = "Velvet",
            Subtitle = "Control Center",
            Tier = "Premium",
            Build = "Build 2.0.0",
            Keybind = Enum.KeyCode.RightShift,
        })

        local Home = Window:AddPage("Home", { Description = "Everything at a glance." })
        local Panel = Home:AddPanel({ Title = "Movement", Description = "Tune how you move.", Tag = "Core" })

        Panel:AddSegmented("Mode", { Text = "Mode", Values = { "Walk", "Glide", "Sprint" } })
        Panel:AddStepper("Speed", { Text = "Speed", Min = 0, Max = 100, Step = 2, Default = 16 })

        Window:SetAction({ Text = "Launch", Callback = function() end })
        Window:SetStatus("Ready", "good")

        print(Velvet.Values.Speed.Value)

    Elements (on panels and accordions):
        AddSegmented  AddStepper  AddChips   AddRadio   AddRange   AddLevel
        AddSwatches   AddField    AddHoldAction         AddMeter   AddNote
        AddAccordion

    Every element with an id lives in Velvet.Values[id] and has :Set(value), :OnChange(fn)
    and .Value.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Velvet = {
    Values = {},
    Palette = "Rose",
    PaletteOrder = { "Rose", "Lilac", "Peach", "Mint" },
    Palettes = {
        Rose = {
            Main = Color3.fromRGB(240, 150, 200),
            Deep = Color3.fromRGB(198, 102, 166),
            Soft = Color3.fromRGB(255, 196, 228),
            Glow = Color3.fromRGB(214, 128, 192),
        },
        Lilac = {
            Main = Color3.fromRGB(182, 158, 255),
            Deep = Color3.fromRGB(128, 100, 226),
            Soft = Color3.fromRGB(218, 206, 255),
            Glow = Color3.fromRGB(150, 122, 240),
        },
        Peach = {
            Main = Color3.fromRGB(255, 176, 138),
            Deep = Color3.fromRGB(226, 120, 98),
            Soft = Color3.fromRGB(255, 214, 192),
            Glow = Color3.fromRGB(238, 142, 112),
        },
        Mint = {
            Main = Color3.fromRGB(132, 228, 194),
            Deep = Color3.fromRGB(70, 176, 150),
            Soft = Color3.fromRGB(196, 248, 228),
            Glow = Color3.fromRGB(96, 206, 170),
        },
    },

    _painters = {},
    _connections = {},
    _windows = {},
}

--// Colors and type \\--

local C = {
    Base = Color3.fromRGB(21, 17, 29),
    BaseHigh = Color3.fromRGB(38, 29, 48),
    Glass = Color3.fromRGB(56, 46, 70),
    GlassDeep = Color3.fromRGB(30, 25, 40),
    Line = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(246, 240, 250),
    Sub = Color3.fromRGB(200, 188, 212),
    Muted = Color3.fromRGB(146, 134, 160),
    Good = Color3.fromRGB(122, 222, 152),
    Warn = Color3.fromRGB(255, 198, 112),
    Bad = Color3.fromRGB(255, 112, 134),
}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
    Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
    Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
    SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
    Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
}

local function pal()
    return Velvet.Palettes[Velvet.Palette]
end

--// Building blocks \\--

local function create(class, props)
    local inst = Instance.new(class)

    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.FontFace = Fonts.Medium
        inst.TextColor3 = C.Text
        inst.TextSize = 14
        if inst:IsA("TextLabel") then
            inst.BackgroundTransparency = 1
        end
        if inst:IsA("TextButton") then
            inst.AutoButtonColor = false
            inst.Text = ""
        end
    end
    if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        inst.BackgroundTransparency = 1
    end

    local parent = props.Parent
    props.Parent = nil
    for key, value in pairs(props) do
        inst[key] = value
    end
    inst.Parent = parent

    return inst
end

local function corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function round(parent)
    return create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

local function stroke(parent, transparency, color, thickness)
    return create("UIStroke", {
        Color = color or C.Line,
        Transparency = transparency or 0.9,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, top, right, bottom, left)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        PaddingLeft = UDim.new(0, left or right or top or 0),
        Parent = parent,
    })
end

local function vlist(parent, gap)
    return create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function hlist(parent, gap, valign)
    return create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = valign or Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function tween(object, duration, goal, style, direction)
    local t = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        goal
    )
    t:Play()
    return t
end

local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(Velvet._connections, connection)
    return connection
end

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then
        return
    end
    task.spawn(function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[Velvet] callback error: " .. tostring(err))
        end
    end, ...)
end

-- Anything that depends on the palette is wrapped in a painter, so switching palettes repaints it.
local function paint(fn)
    table.insert(Velvet._painters, fn)
    fn()
end

local function accentGradient(parent, rotation)
    parent.BackgroundColor3 = Color3.new(1, 1, 1)
    local gradient = create("UIGradient", { Rotation = rotation or 0, Parent = parent })
    paint(function()
        local p = pal()
        gradient.Color = ColorSequence.new(p.Main, p.Deep)
    end)
    return gradient
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- A chevron built from two bars. Rotation 0 points down, -90 points right, 180 points up.
local function chevron(parent, size, rotation, color)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Rotation = rotation or 0,
        Parent = parent,
    })
    local bars = {}
    for i, side in ipairs({ -1, 1 }) do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, side * size * 0.17, 0.5, 0),
            Size = UDim2.fromOffset(math.floor(size * 0.55), 2),
            Rotation = side * -45,
            BackgroundColor3 = color or C.Text,
            Parent = holder,
        })
        round(bar)
        bars[i] = bar
    end
    return holder, bars
end

local function monogram(parent, text, size)
    local badge = create("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.3,
        Parent = parent,
    })
    corner(badge, math.floor(size * 0.3))
    local label = create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        Text = string.upper(string.sub(text or "?", 1, 1)),
        FontFace = Fonts.Bold,
        TextSize = math.floor(size * 0.5),
        TextColor3 = C.Sub,
        Parent = badge,
    })
    return badge, label
end

local function nextOrder(container)
    container._n = (container._n or 0) + 1
    return container._n
end

--// Value objects \\--

local function register(id, element)
    element._listeners = {}

    function element:OnChange(fn)
        table.insert(self._listeners, fn)
        return self
    end

    function element:_emit(...)
        safeCall(self.Callback, ...)
        for _, fn in ipairs(self._listeners) do
            safeCall(fn, ...)
        end
    end

    if id ~= nil then
        Velvet.Values[id] = element
    end
    return element
end

--// Element layouts \\--

-- Label on the left, control on the right.
local function inlineRow(container, text, description, controlWidth)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(container),
        Parent = container.Holder,
    })
    hlist(row, 12)

    local left = create("Frame", {
        Size = UDim2.new(1, -controlWidth - 12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = row,
    })
    vlist(left, 1)

    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = text or "",
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = left,
    })
    if description then
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = description,
            TextSize = 13,
            TextColor3 = C.Muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = left,
        })
    end

    local slot = create("Frame", {
        Size = UDim2.fromOffset(controlWidth, 32),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = row,
    })

    return row, slot
end

-- Label (and an optional live readout) on top, control underneath.
local function stackBlock(container, text, description, withReadout)
    local block = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(container),
        Parent = container.Holder,
    })
    vlist(block, 8)

    local readout
    if text or withReadout then
        local head = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = block,
        })
        vlist(head, 1)

        local titleRow = create("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = head,
        })
        create("TextLabel", {
            Size = UDim2.new(1, withReadout and -90 or 0, 1, 0),
            Text = text or "",
            FontFace = Fonts.SemiBold,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = titleRow,
        })
        if withReadout then
            readout = create("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 90, 1, 0),
                FontFace = Fonts.Bold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = titleRow,
            })
            paint(function()
                readout.TextColor3 = pal().Soft
            end)
        end
        if description then
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Text = description,
                TextSize = 13,
                TextColor3 = C.Muted,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
                Parent = head,
            })
        end
    end

    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = block,
    })

    return block, body, readout
end

local function well(parent, props)
    local frame = create("Frame", props)
    frame.BackgroundColor3 = C.GlassDeep
    frame.BackgroundTransparency = 0.35
    corner(frame, 10)
    stroke(frame, 0.92)
    return frame
end

--// Elements \\--

local Elements = {}
Elements.__index = Elements

function Elements:AddSegmented(id, o)
    o = o or {}
    local values = o.Values or { "One", "Two" }
    local count = #values
    local element = register(id, {
        Type = "Segmented",
        Value = table.find(values, o.Default) and o.Default or values[1],
        Callback = o.Callback,
    })

    local _, body = stackBlock(self, o.Text, o.Description)
    local track = well(body, { Size = UDim2.new(1, 0, 0, 36), Parent = body })
    padding(track, 3)

    local knob = create("Frame", { Size = UDim2.fromScale(1 / count, 1), Parent = track })
    corner(knob, 8)
    accentGradient(knob, 90)

    local buttons = {}
    for i, value in ipairs(values) do
        local button = create("TextButton", {
            Position = UDim2.fromScale((i - 1) / count, 0),
            Size = UDim2.fromScale(1 / count, 1),
            BackgroundTransparency = 1,
            Text = tostring(value),
            FontFace = Fonts.SemiBold,
            TextSize = 14,
            ZIndex = 2,
            Parent = track,
        })
        buttons[i] = button
        connect(button.MouseButton1Click, function()
            element:Set(value)
        end)
    end

    function element:Set(value, silent)
        local index = table.find(values, value)
        if not index then
            return
        end
        self.Value = value
        tween(knob, 0.35, { Position = UDim2.fromScale((index - 1) / count, 0) })
        for i, button in ipairs(buttons) do
            tween(button, 0.2, { TextColor3 = i == index and C.Text or C.Muted })
        end
        if not silent then
            self:_emit(value)
        end
    end

    local start = table.find(values, element.Value)
    knob.Position = UDim2.fromScale((start - 1) / count, 0)
    for i, button in ipairs(buttons) do
        button.TextColor3 = i == start and C.Text or C.Muted
    end

    return element
end

function Elements:AddStepper(id, o)
    o = o or {}
    local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
    local decimals = #(tostring(step):match("%.(%d+)") or "")
    local format = "%." .. decimals .. "f"
    local element = register(id, { Type = "Stepper", Value = min, Callback = o.Callback })

    local _, slot = inlineRow(self, o.Text, o.Description, 132)
    local box = well(slot, { Size = UDim2.fromScale(1, 1), Parent = slot })

    local readout = create("TextLabel", {
        Position = UDim2.fromOffset(32, 0),
        Size = UDim2.new(1, -64, 1, 0),
        FontFace = Fonts.Bold,
        TextSize = 15,
        Parent = box,
    })

    local function sideButton(text, anchorX)
        local button = create("TextButton", {
            AnchorPoint = Vector2.new(anchorX, 0.5),
            Position = UDim2.new(anchorX, anchorX == 0 and 3 or -3, 0.5, 0),
            Size = UDim2.fromOffset(26, 26),
            BackgroundColor3 = C.Glass,
            BackgroundTransparency = 0.4,
            Text = text,
            FontFace = Fonts.Bold,
            TextSize = 17,
            TextColor3 = C.Sub,
            Parent = box,
        })
        corner(button, 8)
        connect(button.MouseEnter, function()
            tween(button, 0.15, { TextColor3 = pal().Soft, BackgroundTransparency = 0.15 })
        end)
        connect(button.MouseLeave, function()
            tween(button, 0.15, { TextColor3 = C.Sub, BackgroundTransparency = 0.4 })
        end)
        return button
    end

    local minus = sideButton("-", 0)
    local plus = sideButton("+", 1)

    function element:Set(value, silent)
        value = math.clamp(tonumber(value) or min, min, max)
        value = math.floor((value - min) / step + 0.5) * step + min
        value = math.clamp(tonumber(string.format(format, value)), min, max)
        local changed = value ~= self.Value
        self.Value = value
        readout.Text = string.format(format, value) .. (o.Suffix or "")
        if changed and not silent then
            self:_emit(value)
        end
    end

    -- Press once to nudge, hold to keep going.
    local holding
    local function bindHold(button, direction)
        connect(button.MouseButton1Down, function()
            local token = {}
            holding = token
            element:Set(element.Value + direction * step)
            task.delay(0.35, function()
                while holding == token do
                    element:Set(element.Value + direction * step)
                    task.wait(0.06)
                end
            end)
        end)
        connect(button.MouseButton1Up, function()
            holding = nil
        end)
        connect(button.MouseLeave, function()
            holding = nil
        end)
    end
    bindHold(minus, -1)
    bindHold(plus, 1)
    connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            holding = nil
        end
    end)

    element:Set(o.Default or min, true)
    return element
end

function Elements:AddChips(id, o)
    o = o or {}
    local values = o.Values or {}
    local multi = o.Multi ~= false
    local selected = {}
    local element = register(id, { Type = "Chips", Value = multi and {} or nil, Callback = o.Callback })

    local _, body = stackBlock(self, o.Text, o.Description)
    local flow = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Parent = body,
    })

    local chips = {}
    local function refresh(chip)
        local on = selected[chip.Value] == true
        chip.Gradient.Enabled = on
        tween(chip.Button, 0.2, {
            BackgroundColor3 = on and Color3.new(1, 1, 1) or C.Glass,
            BackgroundTransparency = on and 0 or 0.45,
            TextColor3 = on and C.Text or C.Sub,
        })
        tween(chip.Stroke, 0.2, { Transparency = on and 1 or 0.88 })
    end

    -- Chips size themselves to their text, then get laid out in wrapping rows here.
    local queued = false
    local function reflow()
        queued = false
        local width = flow.AbsoluteSize.X
        if width <= 0 or #chips == 0 then
            return
        end
        local scale = chips[1].Button.AbsoluteSize.Y / 30
        local x, row = 0, 0
        for _, chip in ipairs(chips) do
            local w = chip.Button.AbsoluteSize.X
            if x > 0 and x + w > width then
                row += 1
                x = 0
            end
            chip.Button.Position = UDim2.new(x / width, 0, 0, row * 38)
            x += w + 8 * scale
        end
        flow.Size = UDim2.new(1, 0, 0, row * 38 + 30)
    end
    local function queueReflow()
        if not queued then
            queued = true
            task.defer(reflow)
        end
    end

    for _, value in ipairs(values) do
        local button = create("TextButton", {
            Size = UDim2.fromOffset(0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = C.Glass,
            BackgroundTransparency = 0.45,
            Text = tostring(value),
            FontFace = Fonts.SemiBold,
            TextSize = 14,
            TextColor3 = C.Sub,
            Parent = flow,
        })
        round(button)
        padding(button, 0, 14, 0, 14)
        local chip = {
            Value = value,
            Button = button,
            Stroke = stroke(button, 0.88),
            Gradient = accentGradient(button, 0),
        }
        button.BackgroundColor3 = C.Glass
        chip.Gradient.Enabled = false
        table.insert(chips, chip)

        connect(button.MouseButton1Click, function()
            if multi then
                selected[value] = not selected[value] or nil
                local list = {}
                for _, v in ipairs(values) do
                    if selected[v] then
                        table.insert(list, v)
                    end
                end
                element:Set(list)
            else
                element:Set(value)
            end
        end)
        connect(button:GetPropertyChangedSignal("AbsoluteSize"), queueReflow)
    end
    connect(flow:GetPropertyChangedSignal("AbsoluteSize"), queueReflow)

    function element:Set(value, silent)
        table.clear(selected)
        if multi then
            local list = {}
            for _, v in ipairs(typeof(value) == "table" and value or {}) do
                if table.find(values, v) then
                    selected[v] = true
                    table.insert(list, v)
                end
            end
            self.Value = list
        else
            if table.find(values, value) then
                selected[value] = true
                self.Value = value
            else
                self.Value = nil
            end
        end
        for _, chip in ipairs(chips) do
            refresh(chip)
        end
        if not silent then
            self:_emit(self.Value)
        end
    end

    element:Set(o.Default or (not multi and values[1]) or {}, true)
    queueReflow()
    return element
end

function Elements:AddRadio(id, o)
    o = o or {}
    local options = {}
    for _, item in ipairs(o.Values or {}) do
        if typeof(item) == "table" then
            table.insert(options, { Text = item.Text or item[1], Description = item.Description or item[2] })
        else
            table.insert(options, { Text = tostring(item) })
        end
    end

    local element = register(id, { Type = "Radio", Value = nil, Callback = o.Callback })
    local _, body = stackBlock(self, o.Text, o.Description)
    vlist(body, 6)

    local rows = {}
    for i, option in ipairs(options) do
        local button = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.GlassDeep,
            BackgroundTransparency = 0.45,
            LayoutOrder = i,
            Parent = body,
        })
        corner(button, 10)
        padding(button, 9, 12, 9, 12)
        local outline = stroke(button, 0.92)

        local ring = create("Frame", {
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Parent = button,
        })
        round(ring)
        local ringStroke = stroke(ring, 0.5, C.Sub, 1.5)
        local dot = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 0),
            Parent = ring,
        })
        round(dot)
        accentGradient(dot, 45)

        local text = create("Frame", {
            Position = UDim2.fromOffset(30, 0),
            Size = UDim2.new(1, -30, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = button,
        })
        vlist(text, 1)
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            Text = option.Text,
            FontFace = Fonts.SemiBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = text,
        })
        if option.Description then
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Text = option.Description,
                TextSize = 13,
                TextColor3 = C.Muted,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
                Parent = text,
            })
        end

        rows[i] = { Option = option, Outline = outline, RingStroke = ringStroke, Dot = dot }
        connect(button.MouseButton1Click, function()
            element:Set(option.Text)
        end)
    end

    local function refresh()
        for _, row in ipairs(rows) do
            local on = row.Option.Text == element.Value
            tween(row.Dot, 0.3, { Size = on and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
            row.Outline.Color = on and pal().Main or C.Line
            row.Outline.Transparency = on and 0.45 or 0.92
            row.RingStroke.Color = on and pal().Main or C.Sub
        end
    end
    paint(refresh)

    function element:Set(value, silent)
        for _, option in ipairs(options) do
            if option.Text == value then
                self.Value = value
                refresh()
                if not silent then
                    self:_emit(value)
                end
                return
            end
        end
    end

    element:Set(o.Default or (options[1] and options[1].Text), true)
    return element
end

function Elements:AddRange(id, o)
    o = o or {}
    local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
    local suffix = o.Suffix or ""
    local default = o.Default or { min, max }
    local element = register(id, { Type = "Range", Value = { default[1], default[2] }, Callback = o.Callback })

    local _, body, readout = stackBlock(self, o.Text, o.Description, true)
    local area = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Active = true,
        Parent = body,
    })
    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(1, -16, 0, 6),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.2,
        Parent = area,
    })
    round(track)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), Parent = track })
    round(fill)
    accentGradient(fill, 0)

    local function knob()
        local k = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 2,
            Parent = track,
        })
        round(k)
        local s = stroke(k, 0, nil, 3)
        paint(function()
            s.Color = pal().Main
        end)
        return k
    end
    local low, high = knob(), knob()

    local function alpha(value)
        return max == min and 0 or (value - min) / (max - min)
    end
    local function snap(value)
        value = math.floor((value - min) / step + 0.5) * step + min
        return math.clamp(value, min, max)
    end

    function element:Set(value, silent)
        local a = snap(tonumber(value[1]) or min)
        local b = snap(tonumber(value[2]) or max)
        if a > b then
            a, b = b, a
        end
        local changed = a ~= self.Value[1] or b ~= self.Value[2]
        self.Value = { a, b }
        low.Position = UDim2.fromScale(alpha(a), 0.5)
        high.Position = UDim2.fromScale(alpha(b), 0.5)
        fill.Position = UDim2.fromScale(alpha(a), 0)
        fill.Size = UDim2.fromScale(alpha(b) - alpha(a), 1)
        readout.Text = string.format("%s%s  to  %s%s", tostring(a), suffix, tostring(b), suffix)
        if changed and not silent then
            self:_emit(a, b)
        end
    end

    local dragging
    local function valueAt(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        return min + (max - min) * a
    end
    local function update(x)
        local v = snap(valueAt(x))
        if dragging == "low" then
            element:Set({ math.min(v, element.Value[2]), element.Value[2] })
        else
            element:Set({ element.Value[1], math.max(v, element.Value[1]) })
        end
    end

    connect(area.InputBegan, function(input)
        if not isPress(input) then
            return
        end
        local v = valueAt(input.Position.X)
        local dLow, dHigh = math.abs(v - element.Value[1]), math.abs(v - element.Value[2])
        if dLow == dHigh then
            dragging = v < element.Value[1] and "low" or "high"
        else
            dragging = dLow < dHigh and "low" or "high"
        end
        update(input.Position.X)
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and isMove(input) then
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            dragging = nil
        end
    end)

    element.Value = { nil, nil }
    element:Set(default, true)
    return element
end

function Elements:AddLevel(id, o)
    o = o or {}
    local count = math.clamp(o.Max or 5, 2, 12)
    local element = register(id, { Type = "Level", Value = 0, Callback = o.Callback })

    local _, slot = inlineRow(self, o.Text, o.Description, 30 + count * 16)
    hlist(slot, 4)

    local pips = {}
    local hovered = 0

    local function refresh()
        for i, pip in ipairs(pips) do
            local on = i <= element.Value
            local preview = not on and i <= hovered
            pip.Gradient.Enabled = on
            pip.Bar.BackgroundColor3 = on and Color3.new(1, 1, 1) or (preview and pal().Glow or C.GlassDeep)
            pip.Bar.BackgroundTransparency = on and 0 or (preview and 0.5 or 0.2)
        end
    end
    paint(refresh)

    for i = 1, count do
        local hit = create("TextButton", {
            Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Parent = slot,
        })
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = C.GlassDeep,
            Parent = hit,
        })
        round(bar)
        local gradient = accentGradient(bar, 0)
        pips[i] = { Bar = bar, Gradient = gradient }

        connect(hit.MouseEnter, function()
            hovered = i
            refresh()
        end)
        connect(hit.MouseLeave, function()
            if hovered == i then
                hovered = 0
                refresh()
            end
        end)
        connect(hit.MouseButton1Click, function()
            if i == element.Value and o.AllowZero then
                element:Set(0)
            else
                element:Set(i)
            end
        end)
    end

    function element:Set(value, silent)
        value = math.clamp(math.floor(tonumber(value) or 0), 0, count)
        local changed = value ~= self.Value
        self.Value = value
        refresh()
        if changed and not silent then
            self:_emit(value)
        end
    end

    element:Set(o.Default or 0, true)
    return element
end

function Elements:AddSwatches(id, o)
    o = o or {}
    local colors = o.Colors
        or {
            Color3.fromRGB(240, 150, 200),
            Color3.fromRGB(182, 158, 255),
            Color3.fromRGB(120, 190, 255),
            Color3.fromRGB(132, 228, 194),
            Color3.fromRGB(255, 214, 120),
            Color3.fromRGB(255, 140, 120),
            Color3.fromRGB(245, 245, 250),
        }
    local element = register(id, { Type = "Swatches", Value = colors[1], Callback = o.Callback })

    local _, body = stackBlock(self, o.Text, o.Description)
    local strip = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Parent = body,
    })
    hlist(strip, 10)

    local dots = {}
    for i, color in ipairs(colors) do
        local hit = create("TextButton", {
            Size = UDim2.fromOffset(30, 30),
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Parent = strip,
        })
        local dot = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(22, 22),
            BackgroundColor3 = color,
            Parent = hit,
        })
        round(dot)
        local ring = stroke(dot, 1, Color3.new(1, 1, 1), 2)
        dots[i] = { Color = color, Dot = dot, Ring = ring }
        connect(hit.MouseButton1Click, function()
            element:Set(color)
        end)
    end

    function element:Set(color, silent)
        if typeof(color) ~= "Color3" then
            return
        end
        self.Value = color
        for _, entry in ipairs(dots) do
            local on = entry.Color == color
            tween(entry.Dot, 0.25, { Size = on and UDim2.fromOffset(26, 26) or UDim2.fromOffset(22, 22) })
            tween(entry.Ring, 0.25, { Transparency = on and 0.1 or 1 })
        end
        if not silent then
            self:_emit(color)
        end
    end

    element:Set(o.Default or colors[1], true)
    return element
end

function Elements:AddField(id, o)
    o = o or {}
    local element = register(id, { Type = "Field", Value = o.Default or "", Callback = o.Callback })

    local _, body = stackBlock(self, o.Text, o.Description)
    local box = well(body, { Size = UDim2.new(1, 0, 0, 38), Parent = body })
    local outline = box:FindFirstChildOfClass("UIStroke")

    local input = create("TextBox", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -56, 1, 0),
        BackgroundTransparency = 1,
        Text = element.Value,
        PlaceholderText = o.Placeholder or "Type here...",
        PlaceholderColor3 = C.Muted,
        ClearTextOnFocus = false,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = box,
    })

    local submit = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(30, 28),
        Parent = box,
    })
    corner(submit, 8)
    accentGradient(submit, 90)
    chevron(submit, 14, -90, C.Text)

    local function commit()
        local text = input.Text
        element.Value = text
        element:_emit(text)
        if o.ClearOnSubmit then
            input.Text = ""
        end
    end

    connect(submit.MouseButton1Click, commit)
    connect(input.Focused, function()
        outline.Color = pal().Main
        tween(outline, 0.2, { Transparency = 0.4 })
    end)
    connect(input.FocusLost, function(enter)
        tween(outline, 0.2, { Transparency = 0.92 })
        outline.Color = C.Line
        if enter then
            commit()
        end
    end)

    function element:Set(text, silent)
        input.Text = tostring(text or "")
        self.Value = input.Text
        if not silent then
            self:_emit(self.Value)
        end
    end

    return element
end

function Elements:AddHoldAction(o)
    o = o or {}
    local duration = o.Duration or 1

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.35,
        ClipsDescendants = true,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    corner(button, 11)
    local outline = stroke(button, 0.9)

    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), Parent = button })
    corner(fill, 11)
    accentGradient(fill, 0)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Text = o.Text or "Hold to confirm",
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = button,
    })
    local hint = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 0),
        Size = UDim2.new(0, 90, 1, 0),
        Text = "HOLD",
        FontFace = Fonts.Bold,
        TextSize = 11,
        TextColor3 = C.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 2,
        Parent = button,
    })

    local token
    local progress
    local function release()
        token = nil
        if progress then
            progress:Cancel()
        end
        tween(fill, 0.3, { Size = UDim2.fromScale(0, 1) })
        hint.Text = "HOLD"
    end

    connect(button.MouseButton1Down, function()
        local mine = {}
        token = mine
        hint.Text = "KEEP HOLDING"
        progress = tween(fill, duration * (1 - fill.Size.X.Scale), { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
        task.delay(duration, function()
            if token ~= mine then
                return
            end
            token = nil
            hint.Text = "DONE"
            safeCall(o.Callback)
            task.wait(0.6)
            if token == nil then
                release()
            end
        end)
    end)
    connect(button.MouseButton1Up, function()
        if token then
            release()
        end
    end)
    connect(button.MouseLeave, function()
        tween(outline, 0.2, { Transparency = 0.9 })
        if token then
            release()
        end
    end)
    connect(button.MouseEnter, function()
        outline.Color = pal().Main
        tween(outline, 0.2, { Transparency = 0.5 })
    end)

    return {
        SetText = function(_, text)
            label.Text = text
        end,
    }
end

function Elements:AddMeter(id, o)
    o = o or {}
    local maxValue = o.Max or 100
    local ticks = o.Ticks or 24
    local element = register(id, { Type = "Meter", Value = 0 })

    local _, body, readout = stackBlock(self, o.Text, o.Description, true)
    local strip = create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Parent = body,
    })
    hlist(strip, 3)

    local bars = {}
    for i = 1, ticks do
        local bar = create("Frame", {
            Size = UDim2.new(1 / ticks, -3 * (ticks - 1) / ticks, 1, 0),
            BackgroundColor3 = C.GlassDeep,
            LayoutOrder = i,
            Parent = strip,
        })
        corner(bar, 3)
        bars[i] = bar
    end

    local function refresh()
        local lit = math.floor(element.Value / maxValue * ticks + 0.5)
        local p = pal()
        for i, bar in ipairs(bars) do
            local on = i <= lit
            tween(bar, 0.25, {
                BackgroundColor3 = on and p.Main:Lerp(p.Deep, (i - 1) / math.max(ticks - 1, 1)) or C.GlassDeep,
                BackgroundTransparency = on and 0 or 0.25,
            })
        end
        if o.Format then
            readout.Text = o.Format(element.Value, maxValue)
        else
            readout.Text = math.floor(element.Value / maxValue * 100 + 0.5) .. "%"
        end
    end
    paint(refresh)

    function element:Set(value)
        self.Value = math.clamp(tonumber(value) or 0, 0, maxValue)
        refresh()
        self:_emit(self.Value)
    end

    element:Set(o.Default or 0)
    return element
end

function Elements:AddNote(text, kind)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 0.86,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    corner(frame, 10)
    padding(frame, 10, 12, 10, 18)

    local bar = create("Frame", {
        Position = UDim2.new(0, -10, 0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        Parent = frame,
    })
    round(bar)

    local label = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = text or "",
        TextSize = 13,
        TextColor3 = C.Sub,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })

    paint(function()
        local color = (kind == "warn" and C.Warn) or (kind == "danger" and C.Bad) or pal().Main
        frame.BackgroundColor3 = color
        bar.BackgroundColor3 = color
    end)

    return {
        SetText = function(_, value)
            label.Text = value
        end,
    }
end

function Elements:AddAccordion(o)
    if typeof(o) == "string" then
        o = { Title = o }
    end
    o = o or {}

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    vlist(holder, 10)

    local header = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.35,
        LayoutOrder = 1,
        Parent = holder,
    })
    corner(header, 10)
    stroke(header, 0.92)
    create("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Text = o.Title or "More",
        FontFace = Fonts.SemiBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    -- A plus that folds into a minus when open.
    local sign = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        Parent = header,
    })
    local bars = {}
    for i, rotation in ipairs({ 0, 90 }) do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 0, 0, 2),
            Rotation = rotation,
            Parent = sign,
        })
        round(bar)
        bars[i] = bar
    end
    paint(function()
        for _, bar in ipairs(bars) do
            bar.BackgroundColor3 = pal().Soft
        end
    end)

    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        LayoutOrder = 2,
        Parent = holder,
    })
    padding(body, 2, 4, 4, 10)
    vlist(body, 12)

    local section = setmetatable({ Holder = body, _n = 0 }, Elements)
    local open = false

    function section:SetOpen(value)
        open = value and true or false
        body.Visible = open
        tween(bars[2], 0.3, { Rotation = open and 0 or 90 })
    end

    connect(header.MouseButton1Click, function()
        section:SetOpen(not open)
    end)
    section:SetOpen(o.Open)

    return section
end

--// Panels and pages \\--

local Host = {}
Host.__index = Host

function Host:AddPanel(o)
    if typeof(o) == "string" then
        o = { Title = o }
    end
    o = o or {}

    local panel = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.5,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    corner(panel, 16)
    stroke(panel, 0.88)
    padding(panel, 16, 16, 16, 16)
    vlist(panel, 14)

    local head = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Parent = panel,
    })
    local titles = create("Frame", {
        Size = UDim2.new(1, o.Tag and -90 or 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = head,
    })
    vlist(titles, 2)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        Text = o.Title or "Panel",
        FontFace = Fonts.Bold,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = titles,
    })
    if o.Description then
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = o.Description,
            TextSize = 13,
            TextColor3 = C.Muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = titles,
        })
    end
    if o.Tag then
        local tag = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = o.Tag,
            FontFace = Fonts.Bold,
            TextSize = 12,
            Parent = head,
        })
        corner(tag, 6)
        padding(tag, 0, 9, 0, 9)
        tag.BackgroundTransparency = 0
        accentGradient(tag, 0)
    end

    -- Elements go straight into the panel, below the header.
    return setmetatable({ Holder = panel, _n = 0 }, Elements)
end

function Host:AddColumns()
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    hlist(row, 12, Enum.VerticalAlignment.Top)

    local function column(order)
        local frame = create("Frame", {
            Size = UDim2.new(0.5, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = row,
        })
        vlist(frame, 12)
        return setmetatable({ Holder = frame, _n = 0 }, Host)
    end

    return { Left = column(1), Right = column(2) }
end

--// Window \\--

local function mount(gui)
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then
        gui.Parent = hui
        return
    end
    if not pcall(function()
        gui.Parent = CoreGui
    end) then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local Window = {}
Window.__index = Window

function Velvet:CreateWindow(o)
    o = o or {}
    local title = o.Title or "Velvet"
    local win = setmetatable({
        Title = title,
        Pages = {},
        Visible = true,
        Keybind = o.Keybind or Enum.KeyCode.RightShift,
    }, Window)

    local gui = create("ScreenGui", {
        Name = "Velvet_" .. tostring(math.random(1e5, 1e6)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 60,
    })
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        elseif protectgui then
            protectgui(gui)
        end
    end)
    mount(gui)
    win.Gui = gui

    local size = o.Size or UDim2.fromOffset(900, 580)
    local root = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.04,
        ClipsDescendants = true,
        Parent = gui,
    })
    corner(root, 22)
    stroke(root, 0.84)
    local scale = create("UIScale", { Scale = 1, Parent = root })
    win.Root = root
    win.Scale = scale

    -- Plum base that warms toward the accent in the top right corner.
    local backdrop = create("UIGradient", { Rotation = 35, Parent = root })
    paint(function()
        local glow = pal().Glow
        backdrop.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.Base),
            ColorSequenceKeypoint.new(0.5, C.BaseHigh),
            ColorSequenceKeypoint.new(1, C.BaseHigh:Lerp(glow, 0.45)),
        })
    end)

    -- Soft glow: stacked translucent circles read as one blurred light.
    local glowLayer = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = root,
    })
    local function glowAt(position, sizes)
        for _, diameter in ipairs(sizes) do
            local circle = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = position,
                Size = UDim2.fromOffset(diameter, diameter),
                BackgroundTransparency = 0.93,
                Parent = glowLayer,
            })
            round(circle)
            paint(function()
                circle.BackgroundColor3 = pal().Glow
            end)
        end
    end
    glowAt(UDim2.new(1, -120, 0, 40), { 620, 480, 360, 240, 140 })
    glowAt(UDim2.new(0.55, 0, 1, 40), { 420, 280, 160 })

    -- Sidebar
    local sidebar = create("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(0, 200, 1, -24),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.35,
        Parent = root,
    })
    corner(sidebar, 18)
    stroke(sidebar, 0.9)

    local brand = create("Frame", {
        Position = UDim2.fromOffset(16, 18),
        Size = UDim2.new(1, -32, 0, 44),
        BackgroundTransparency = 1,
        Active = true,
        Parent = sidebar,
    })
    local logo = create("Frame", { Size = UDim2.fromOffset(42, 42), Parent = brand })
    corner(logo, 12)
    accentGradient(logo, 45)
    if o.Logo then
        create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(26, 26),
            Image = tonumber(o.Logo) and ("rbxassetid://" .. o.Logo) or o.Logo,
            Parent = logo,
        })
    else
        create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(title, 1, 1)),
            FontFace = Fonts.Bold,
            TextSize = 24,
            Parent = logo,
        })
    end
    create("TextLabel", {
        Position = UDim2.fromOffset(54, 1),
        Size = UDim2.new(1, -54, 0, 24),
        Text = title,
        FontFace = Fonts.Bold,
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = brand,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(54, 24),
        Size = UDim2.new(1, -54, 0, 18),
        Text = o.Subtitle or "Control Center",
        TextSize = 14,
        TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = brand,
    })

    local nav = create("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 84),
        Size = UDim2.new(1, -20, 1, -84 - 132),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = sidebar,
    })
    vlist(nav, 6)
    win.Nav = nav

    local foot = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -14),
        Size = UDim2.new(1, -28, 0, 112),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = o.Build or "Build 2.0.0",
        TextSize = 14,
        TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = foot,
    })
    local liveDot = create("Frame", {
        Position = UDim2.fromOffset(3, 31),
        Size = UDim2.fromOffset(9, 9),
        BackgroundColor3 = C.Good,
        Parent = foot,
    })
    round(liveDot)
    win.LiveText = create("TextLabel", {
        Position = UDim2.fromOffset(20, 26),
        Size = UDim2.new(1, -20, 0, 18),
        Text = o.Connection or "Online",
        TextSize = 14,
        TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = foot,
    })
    win.LiveDot = liveDot

    local hide = create("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.4,
        Text = "Hide  ·  " .. win.Keybind.Name,
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextColor3 = C.Sub,
        Parent = foot,
    })
    corner(hide, 13)
    local hideStroke = stroke(hide, 0.88)
    connect(hide.MouseEnter, function()
        tween(hide, 0.2, { BackgroundTransparency = 0.2, TextColor3 = C.Text })
        tween(hideStroke, 0.2, { Transparency = 0.75 })
    end)
    connect(hide.MouseLeave, function()
        tween(hide, 0.2, { BackgroundTransparency = 0.4, TextColor3 = C.Sub })
        tween(hideStroke, 0.2, { Transparency = 0.88 })
    end)
    connect(hide.MouseButton1Click, function()
        win:SetVisible(false)
    end)
    win.HideButton = hide

    -- Main column
    local main = create("Frame", {
        Position = UDim2.fromOffset(226, 12),
        Size = UDim2.new(1, -238, 1, -24),
        BackgroundTransparency = 1,
        Parent = root,
    })

    local topbar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Active = true,
        Parent = main,
    })

    local crumbs = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.35,
        Parent = topbar,
    })
    corner(crumbs, 11)
    stroke(crumbs, 0.9)
    padding(crumbs, 0, 14, 0, 14)
    hlist(crumbs, 8)
    create("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = title,
        TextSize = 14,
        TextColor3 = C.Muted,
        LayoutOrder = 1,
        Parent = crumbs,
    })
    local crumbArrow = create("Frame", {
        Size = UDim2.fromOffset(10, 38),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = crumbs,
    })
    chevron(crumbArrow, 10, -90, C.Muted)
    win.CrumbLabel = create("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = "",
        FontFace = Fonts.SemiBold,
        TextSize = 14,
        LayoutOrder = 3,
        Parent = crumbs,
    })

    -- Profile chip
    local profile = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(0, 50),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.45,
        Parent = topbar,
    })
    corner(profile, 16)
    stroke(profile, 0.86)
    padding(profile, 0, 16, 0, 6)
    hlist(profile, 10)

    local avatar = create("ImageLabel", {
        Size = UDim2.fromOffset(38, 38),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0,
        Image = o.Avatar
            or (LocalPlayer and ("rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150") or ""),
        LayoutOrder = 1,
        Parent = profile,
    })
    round(avatar)
    local avatarRing = stroke(avatar, 0, nil, 2)
    paint(function()
        avatarRing.Color = pal().Main
    end)

    local who = create("Frame", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = profile,
    })
    vlist(who, 0).VerticalAlignment = Enum.VerticalAlignment.Center
    create("TextLabel", {
        Size = UDim2.fromOffset(0, 19),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = o.User or (LocalPlayer and LocalPlayer.DisplayName) or "Guest",
        FontFace = Fonts.Bold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = who,
    })
    local tier = create("TextLabel", {
        Size = UDim2.fromOffset(0, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        Text = o.Tier or "Member",
        FontFace = Fonts.SemiBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        Parent = who,
    })
    paint(function()
        tier.TextColor3 = pal().Main
    end)

    -- Palette switcher: a little sun that cycles the accent.
    local sun = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(42, 42),
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 0.45,
        Parent = topbar,
    })
    corner(sun, 13)
    stroke(sun, 0.86)
    local sunParts = {}
    local core = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        Parent = sun,
    })
    round(core)
    local coreStroke = stroke(core, 0, nil, 2)
    local rays = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(22, 22),
        BackgroundTransparency = 1,
        Parent = sun,
    })
    for i = 0, 7 do
        local spoke = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Rotation = i * 45,
            Parent = rays,
        })
        local ray = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(2, 4),
            Parent = spoke,
        })
        round(ray)
        table.insert(sunParts, ray)
    end
    paint(function()
        coreStroke.Color = pal().Soft
        for _, ray in ipairs(sunParts) do
            ray.BackgroundColor3 = pal().Soft
        end
    end)
    connect(sun.MouseButton1Click, function()
        local index = table.find(Velvet.PaletteOrder, Velvet.Palette) or 0
        local name = Velvet.PaletteOrder[index % #Velvet.PaletteOrder + 1]
        Velvet:SetPalette(name)
        tween(rays, 0.6, { Rotation = rays.Rotation + 90 }, Enum.EasingStyle.Back)
        Velvet:Toast({ Title = "Palette", Text = name .. " is now active.", Duration = 2 })
    end)

    -- Keep the sun just left of the profile chip, whatever the name length.
    local function placeSun()
        local width = profile.AbsoluteSize.X / math.max(scale.Scale, 0.01)
        sun.Position = UDim2.new(1, -width - 12, 0.5, 0)
    end
    connect(profile:GetPropertyChangedSignal("AbsoluteSize"), placeSun)
    task.defer(placeSun)

    -- Page header
    win.HeaderTitle = create("TextLabel", {
        Position = UDim2.fromOffset(4, 62),
        Size = UDim2.new(1, -8, 0, 38),
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = 34,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main,
    })
    win.HeaderSub = create("TextLabel", {
        Position = UDim2.fromOffset(5, 100),
        Size = UDim2.new(1, -8, 0, 20),
        Text = "",
        TextSize = 15,
        TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = main,
    })

    win.PageHolder = create("Frame", {
        Position = UDim2.fromOffset(0, 134),
        Size = UDim2.new(1, 0, 1, -134 - 66),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main,
    })

    -- Status bar
    local status = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = C.GlassDeep,
        BackgroundTransparency = 0.35,
        Parent = main,
    })
    corner(status, 16)
    stroke(status, 0.9)
    win.StatusBar = status

    local pulse = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(26, 28),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = C.Good,
        Parent = status,
    })
    round(pulse)
    local pulseRing = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.Good,
        BackgroundTransparency = 0.4,
        Parent = pulse,
    })
    round(pulseRing)
    win.StatusDot = pulse
    win.StatusRing = pulseRing
    task.spawn(function()
        while gui.Parent do
            pulseRing.Size = UDim2.fromScale(1, 1)
            pulseRing.BackgroundTransparency = 0.35
            tween(pulseRing, 1.4, { Size = UDim2.fromScale(2.6, 2.6), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
            task.wait(1.6)
        end
    end)

    win.StatusText = create("TextLabel", {
        Position = UDim2.fromOffset(44, 0),
        Size = UDim2.new(0.5, -44, 1, 0),
        Text = "Status: Ready",
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = status,
    })

    local stats = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.new(0, 140, 1, 0),
        Text = "",
        TextSize = 13,
        TextColor3 = C.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = status,
    })
    win.Stats = stats
    local frames, clock = 0, os.clock()
    connect(RunService.RenderStepped, function()
        frames += 1
        local now = os.clock()
        if now - clock >= 1 then
            stats.Text = string.format("%d fps  ·  %s", frames / (now - clock), os.date("%H:%M"))
            frames, clock = 0, now
        end
    end)

    -- Dragging from the top bar or the brand block.
    local dragStart, startPos
    local function beginDrag(input)
        if isPress(input) then
            dragStart = input.Position
            startPos = root.Position
        end
    end
    connect(topbar.InputBegan, beginDrag)
    connect(brand.InputBegan, beginDrag)
    connect(UserInputService.InputChanged, function(input)
        if dragStart and isMove(input) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            dragStart = nil
        end
    end)

    -- Floating bubble to bring the window back (handy without a keyboard).
    local bubble = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(46, 46),
        Text = string.upper(string.sub(title, 1, 1)),
        FontFace = Fonts.Bold,
        TextSize = 22,
        Visible = false,
        Parent = gui,
    })
    corner(bubble, 15)
    accentGradient(bubble, 45)
    stroke(bubble, 0.7)
    connect(bubble.MouseButton1Click, function()
        win:SetVisible(true)
    end)
    win.Bubble = bubble

    connect(UserInputService.InputBegan, function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == win.Keybind then
            win:SetVisible(not win.Visible)
        end
    end)

    -- Toast stack lives on the same ScreenGui.
    if not Velvet._toastHolder or not Velvet._toastHolder.Parent then
        local holder = create("Frame", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 300, 1, -40),
            BackgroundTransparency = 1,
            Parent = gui,
        })
        vlist(holder, 8).VerticalAlignment = Enum.VerticalAlignment.Bottom
        Velvet._toastHolder = holder
    end

    table.insert(Velvet._windows, win)

    -- Open with a small settle.
    scale.Scale = 0.92
    tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

    return win
end

function Window:AddPage(name, o)
    o = o or {}
    local page = setmetatable({ Name = name, Description = o.Description or "", _n = 0 }, Host)

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        LayoutOrder = #self.Pages + 1,
        Parent = self.Nav,
    })
    corner(button, 13)

    local hover = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.Glass,
        BackgroundTransparency = 1,
        Parent = button,
    })
    corner(hover, 13)

    local fill = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = button,
    })
    corner(fill, 13)
    accentGradient(fill, 0)
    local fillStroke = stroke(fill, 1, C.Line)

    local icon, iconText
    if o.Icon then
        icon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            Image = tonumber(o.Icon) and ("rbxassetid://" .. o.Icon) or o.Icon,
            ImageColor3 = C.Sub,
            ZIndex = 2,
            Parent = button,
        })
    else
        icon, iconText = monogram(button, name, 24)
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.Position = UDim2.new(0, 12, 0.5, 0)
        icon.ZIndex = 2
        iconText.ZIndex = 2
    end

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -56, 1, 0),
        Text = name,
        FontFace = Fonts.SemiBold,
        TextSize = 16,
        TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = button,
    })

    local scroller = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        Parent = self.PageHolder,
    })
    paint(function()
        scroller.ScrollBarImageColor3 = pal().Main
    end)
    padding(scroller, 0, 10, 6, 0)
    vlist(scroller, 12)

    page.Holder = scroller
    page.Button = button

    function page:_setActive(active)
        tween(fill, 0.3, { BackgroundTransparency = active and 0.12 or 1 })
        tween(fillStroke, 0.3, { Transparency = active and 0.7 or 1 })
        tween(label, 0.3, { TextColor3 = active and C.Text or C.Sub })
        if iconText then
            tween(icon, 0.3, { BackgroundColor3 = active and Color3.new(1, 1, 1) or C.Glass, BackgroundTransparency = active and 0.7 or 0.3 })
            tween(iconText, 0.3, { TextColor3 = active and C.Text or C.Sub })
        else
            tween(icon, 0.3, { ImageColor3 = active and C.Text or C.Sub })
        end
    end

    connect(button.MouseEnter, function()
        if self.ActivePage ~= page then
            tween(hover, 0.2, { BackgroundTransparency = 0.6 })
        end
    end)
    connect(button.MouseLeave, function()
        tween(hover, 0.2, { BackgroundTransparency = 1 })
    end)
    connect(button.MouseButton1Click, function()
        tween(hover, 0.2, { BackgroundTransparency = 1 })
        self:SelectPage(page)
    end)

    table.insert(self.Pages, page)
    if not self.ActivePage then
        self:SelectPage(page)
    end
    return page
end

function Window:SelectPage(page)
    if self.ActivePage == page then
        return
    end
    if self.ActivePage then
        self.ActivePage:_setActive(false)
        self.ActivePage.Holder.Visible = false
    end
    self.ActivePage = page
    page:_setActive(true)

    local holder = page.Holder
    holder.Visible = true
    holder.Position = UDim2.fromOffset(0, 14)
    tween(holder, 0.45, { Position = UDim2.fromOffset(0, 0) })

    self.CrumbLabel.Text = page.Name
    self.HeaderTitle.Text = page.Name
    self.HeaderSub.Text = page.Description
    self.HeaderTitle.TextTransparency = 1
    self.HeaderSub.TextTransparency = 1
    tween(self.HeaderTitle, 0.4, { TextTransparency = 0 })
    tween(self.HeaderSub, 0.5, { TextTransparency = 0 })
end

local StatusColors = { good = C.Good, warn = C.Warn, bad = C.Bad }

function Window:SetStatus(text, kind)
    local color = StatusColors[kind or "good"] or C.Good
    self.StatusText.Text = "Status: " .. tostring(text)
    tween(self.StatusDot, 0.3, { BackgroundColor3 = color })
    self.StatusRing.BackgroundColor3 = color
end

function Window:SetConnection(text, kind)
    self.LiveText.Text = tostring(text)
    tween(self.LiveDot, 0.3, { BackgroundColor3 = StatusColors[kind or "good"] or C.Good })
end

-- The big button on the status bar. Menu entries show up behind the chevron.
function Window:SetAction(o)
    if self.Action then
        self.Action:Destroy()
        self.Action = nil
    end
    if self.ActionMenu then
        self.ActionMenu:Destroy()
        self.ActionMenu = nil
    end
    if not o then
        self.Stats.Position = UDim2.new(1, -16, 0, 0)
        return
    end

    local hasMenu = typeof(o.Menu) == "table" and #o.Menu > 0
    local width = hasMenu and 196 or 156

    local action = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(width, 42),
        Parent = self.StatusBar,
    })
    corner(action, 12)
    accentGradient(action, 0)
    local glow = stroke(action, 0.6)
    self.Action = action
    self.Stats.Position = UDim2.new(1, -width - 24, 0, 0)

    local run = create("TextButton", {
        Size = UDim2.new(1, hasMenu and -44 or 0, 1, 0),
        BackgroundTransparency = 1,
        Text = o.Text or "Run",
        FontFace = Fonts.Bold,
        TextSize = 17,
        Parent = action,
    })
    connect(run.MouseEnter, function()
        tween(glow, 0.2, { Transparency = 0.2 })
    end)
    connect(run.MouseLeave, function()
        tween(glow, 0.2, { Transparency = 0.6 })
    end)
    connect(run.MouseButton1Click, function()
        local s = create("UIScale", { Parent = action })
        s.Scale = 0.95
        tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back).Completed:Connect(function()
            s:Destroy()
        end)
        safeCall(o.Callback)
    end)

    if not hasMenu then
        return
    end

    create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.new(0, 1, 0, 22),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.6,
        Parent = action,
    })
    local more = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 44, 1, 0),
        BackgroundTransparency = 1,
        Parent = action,
    })
    local arrow = chevron(more, 14, 0, C.Text)

    local menu = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -76),
        Size = UDim2.fromOffset(210, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.Base,
        BackgroundTransparency = 0.04,
        Visible = false,
        ZIndex = 20,
        Parent = self.Root,
    })
    corner(menu, 14)
    stroke(menu, 0.82)
    padding(menu, 6)
    vlist(menu, 2)
    self.ActionMenu = menu

    local function setMenu(open)
        menu.Visible = open
        tween(arrow, 0.25, { Rotation = open and 180 or 0 })
    end

    for i, entry in ipairs(o.Menu) do
        local item = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = C.Glass,
            BackgroundTransparency = 1,
            Text = entry.Text or ("Option " .. i),
            TextSize = 14,
            TextColor3 = C.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = i,
            ZIndex = 21,
            Parent = menu,
        })
        corner(item, 9)
        padding(item, 0, 10, 0, 10)
        connect(item.MouseEnter, function()
            tween(item, 0.15, { BackgroundTransparency = 0.4, TextColor3 = C.Text })
        end)
        connect(item.MouseLeave, function()
            tween(item, 0.15, { BackgroundTransparency = 1, TextColor3 = C.Sub })
        end)
        connect(item.MouseButton1Click, function()
            setMenu(false)
            safeCall(entry.Callback)
        end)
    end

    connect(more.MouseButton1Click, function()
        setMenu(not menu.Visible)
    end)
    -- Clicking anywhere outside closes it.
    connect(UserInputService.InputBegan, function(input)
        if not menu.Parent or not menu.Visible or not isPress(input) then
            return
        end
        local p = input.Position
        local function inside(gui)
            local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
            return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
        end
        if not inside(menu) and not inside(more) then
            setMenu(false)
        end
    end)
end

function Window:SetVisible(visible)
    self.Visible = visible
    self.Bubble.Visible = not visible
    if visible then
        self.Root.Visible = true
        self.Scale.Scale = 0.94
        tween(self.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    else
        if self.ActionMenu then
            self.ActionMenu.Visible = false
        end
        tween(self.Scale, 0.2, { Scale = 0.94 }).Completed:Connect(function()
            if not self.Visible then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:Toast(o)
    return Velvet:Toast(o)
end

function Window:Destroy()
    Velvet:Unload()
end

--// Toasts \\--

function Velvet:Toast(o)
    if typeof(o) == "string" then
        o = { Text = o }
    end
    o = o or {}
    local holder = self._toastHolder
    if not holder or not holder.Parent then
        return
    end
    local duration = o.Duration or 4

    local slot = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = math.floor(os.clock() * 1000),
        Parent = holder,
    })
    local card = create("Frame", {
        Position = UDim2.fromOffset(340, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.Base,
        BackgroundTransparency = 0.06,
        ClipsDescendants = true,
        Parent = slot,
    })
    corner(card, 14)
    stroke(card, 0.84)
    padding(card, 12, 14, 14, 30)

    local dot = create("Frame", {
        Position = UDim2.fromOffset(-17, 5),
        Size = UDim2.fromOffset(8, 8),
        Parent = card,
    })
    round(dot)
    accentGradient(dot, 45)

    local text = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    vlist(text, 2)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = o.Title or "Notice",
        FontFace = Fonts.Bold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = text,
    })
    if o.Text then
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = o.Text,
            TextSize = 13,
            TextColor3 = C.Sub,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = text,
        })
    end

    local timer = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, -30, 1, 14),
        Size = UDim2.new(1, 44, 0, 2),
        Parent = card,
    })
    accentGradient(timer, 0)

    tween(card, 0.45, { Position = UDim2.fromOffset(0, 0) })
    tween(timer, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        if not card.Parent then
            return
        end
        tween(card, 0.35, { Position = UDim2.fromOffset(340, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.36)
        slot:Destroy()
    end)
end

--// Palette + teardown \\--

function Velvet:SetPalette(name)
    if not self.Palettes[name] then
        return
    end
    self.Palette = name
    for _, painter in ipairs(self._painters) do
        pcall(painter)
    end
end

function Velvet:AddPalette(name, colors)
    self.Palettes[name] = colors
    if not table.find(self.PaletteOrder, name) then
        table.insert(self.PaletteOrder, name)
    end
end

function Velvet:Unload()
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
    table.clear(self._painters)
    for _, window in ipairs(self._windows) do
        if window.Gui then
            window.Gui:Destroy()
        end
    end
    table.clear(self._windows)
    self._toastHolder = nil
end

return Velvet
