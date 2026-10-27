--[[
    Velvet  ·  ui v2
    A regular Roblox UI library: sidebar tabs, two-column sections and the usual elements,
    dressed in a frosted navy-to-rose glass theme.

    local Velvet = loadstring(game:HttpGet("<raw url to ui v2/ui.lua>"))()

    local Window = Velvet:CreateWindow({
        Title = "Velvet",
        Subtitle = "Hub",
        Footer = "v2.0",
        Keybind = Enum.KeyCode.RightShift,
    })

    local Main = Window:AddTab("Main", { Description = "General features", Icon = 0 }) -- Icon: optional asset id
    local Section = Main:AddSection("Movement", "Left")

    Section:AddToggle("Fly", { Text = "Fly", Description = "Toggle flight", Default = false, Callback = print })
    Section:AddSlider("Speed", { Text = "Speed", Min = 0, Max = 100, Default = 16 })
    Section:AddDropdown("Mode", { Text = "Mode", Values = { "A", "B" }, Default = "A" })
    Section:AddButton({ Text = "Reset", Callback = function() end })

    Velvet:Notify({ Title = "Loaded", Text = "Have fun.", Duration = 4 })

    Elements: AddToggle, AddButton, AddSlider, AddDropdown, AddInput, AddKeybind,
              AddColorPicker, AddLabel, AddParagraph, AddDivider
    Every element with a flag is stored in Velvet.Flags[flag] with .Value, :Set(v) and :OnChanged(fn).
    Configs: Velvet:SaveConfig(name), Velvet:LoadConfig(name), Velvet:ListConfigs()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Velvet = {
    Flags = {},
    ConfigFolder = "Velvet",
    _connections = {},
    _popup = nil,
}

--// Theme (sampled from the reference) \\--

local rgb = Color3.fromRGB
local Theme = {
    -- window backdrop: navy bottom-left, mauve above, rose haze in the top right
    Navy = rgb(22, 32, 50),
    NavyMid = rgb(40, 46, 66),
    Mauve = rgb(148, 130, 156),
    Haze = rgb(240, 196, 216),

    Sidebar = rgb(17, 24, 38),
    Section = rgb(22, 29, 44),
    Field = rgb(30, 37, 52),
    FieldHover = rgb(42, 49, 66),
    Track = rgb(78, 78, 98),
    Popup = rgb(26, 32, 47),

    Pink = rgb(234, 146, 194),
    PinkDeep = rgb(212, 128, 178),
    PinkLight = rgb(246, 196, 218),
    PinkMauve = rgb(178, 140, 182),

    Text = rgb(246, 244, 250),
    Sub = rgb(196, 192, 208),
    Muted = rgb(140, 138, 156),
    Dark = rgb(30, 16, 34),
    White = rgb(255, 255, 255),
}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local Fonts = {
    Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
    Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
    SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
    Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
}

--// Helpers \\--

local function create(class, props)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.FontFace = Fonts.Medium
        inst.TextColor3 = Theme.Text
        inst.TextSize = 14
        if not inst:IsA("TextBox") then
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
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function pill(parent)
    return create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

local function stroke(parent, transparency, color, thickness)
    return create("UIStroke", {
        Color = color or Theme.White,
        Transparency = transparency or 0.88,
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

local function hlist(parent, gap)
    return create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function gradient(parent, a, b, rotation)
    parent.BackgroundColor3 = Theme.White
    return create("UIGradient", {
        Color = ColorSequence.new(a, b),
        Rotation = rotation or 0,
        Parent = parent,
    })
end

local function pinkFill(parent, rotation)
    return gradient(parent, Theme.Pink, Theme.PinkDeep, rotation)
end

local function tween(object, duration, goal, style, direction)
    local t = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        goal
    )
    t:Play()
    return t
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Velvet._connections, c)
    return c
end

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then
        return
    end
    task.spawn(function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[Velvet] " .. tostring(err))
        end
    end, ...)
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function within(gui, point)
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

-- Down-pointing chevron from two bars; rotate the holder to point elsewhere.
local function chevron(parent, size, color)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    for _, side in ipairs({ -1, 1 }) do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, side * size * 0.17, 0.5, 0),
            Size = UDim2.fromOffset(math.floor(size * 0.55), 2),
            Rotation = side * -45,
            BackgroundColor3 = color or Theme.Sub,
            Parent = holder,
        })
        pill(bar)
    end
    return holder
end

local function nextOrder(owner)
    owner._n = (owner._n or 0) + 1
    return owner._n
end

local function colorToHex(color)
    return string.format("%02X%02X%02X", color.R * 255 + 0.5, color.G * 255 + 0.5, color.B * 255 + 0.5)
end

local function hexToColor(hex)
    hex = tostring(hex):gsub("#", "")
    if #hex ~= 6 then
        return nil
    end
    local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then
        return nil
    end
    return rgb(r, g, b)
end

--// Flags \\--

local function register(flag, element)
    element._listeners = {}

    function element:OnChanged(fn)
        table.insert(self._listeners, fn)
        return self
    end

    function element:_fire(...)
        safeCall(self.Callback, ...)
        for _, fn in ipairs(self._listeners) do
            safeCall(fn, ...)
        end
    end

    if flag then
        Velvet.Flags[flag] = element
    end
    return element
end

--// Popups (dropdown lists, color pickers) \\--

local function closePopup()
    local popup = Velvet._popup
    if popup then
        Velvet._popup = nil
        popup.Close()
    end
end

local function openPopup(popup)
    closePopup()
    Velvet._popup = popup
end

connect(UserInputService.InputBegan, function(input)
    local popup = Velvet._popup
    if popup and isPress(input) then
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if not within(popup.Frame, point) and not within(popup.Owner, point) then
            closePopup()
        end
    end
end)

--// Rows \\--

-- A row in a section: text on the left, an optional control on the right.
-- Rows get a hairline on top, except the first one and the one after a divider.
local function makeRow(section, text, description, controlWidth)
    local noLine = section._noLine or (section._n or 0) == 0
    section._noLine = false

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(section),
        Parent = section.Holder,
    })

    if not noLine then
        create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.White,
            BackgroundTransparency = 0.94,
            Parent = row,
        })
    end

    local textBox = create("Frame", {
        Size = UDim2.new(1, controlWidth and -(controlWidth + 12) or 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = row,
    })
    padding(textBox, description and 6 or 11, 0, description and 7 or 11, 0)
    vlist(textBox, 1)

    local title = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = text or "",
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        Parent = textBox,
    })
    local desc
    if description then
        desc = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = description,
            TextSize = 13,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = textBox,
        })
    end

    local slot
    if controlWidth then
        slot = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.fromScale(1, 0.5),
            Size = UDim2.fromOffset(controlWidth, 30),
            BackgroundTransparency = 1,
            Parent = row,
        })
    end

    return row, slot, title, desc
end

local function field(parent, props)
    local frame = create(props.Class or "Frame", {
        Size = props.Size,
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        BackgroundColor3 = Theme.Field,
        BackgroundTransparency = 0.2,
        Parent = parent,
    })
    corner(frame, 8)
    local s = stroke(frame, 0.88)
    return frame, s
end

--// Elements \\--

local Section = {}
Section.__index = Section

function Section:AddToggle(flag, o)
    o = o or {}
    local element = register(flag, { Type = "Toggle", Value = false, Callback = o.Callback })

    local row, slot = makeRow(self, o.Text, o.Description, 42)
    local hit = create("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = Theme.Track,
        Parent = slot,
    })
    pill(track)
    local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = track })
    pill(fill)
    pinkFill(fill, 0)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Theme.White,
        ZIndex = 2,
        Parent = track,
    })
    pill(knob)

    function element:Set(value, silent)
        value = value and true or false
        local changed = value ~= self.Value
        self.Value = value
        tween(fill, 0.25, { BackgroundTransparency = value and 0 or 1 })
        tween(knob, 0.3, { Position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        if changed and not silent then
            self:_fire(value)
        end
    end

    connect(hit.MouseButton1Click, function()
        element:Set(not element.Value)
    end)

    element:Set(o.Default, true)
    if o.Default then
        element:_fire(true)
    end
    return element
end

function Section:AddButton(o)
    if typeof(o) == "string" then
        o = { Text = o }
    end
    o = o or {}

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    local button, outline = field(holder, {
        Class = "TextButton",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 34),
    })
    button.Text = o.Text or "Button"
    button.FontFace = Fonts.SemiBold
    button.TextSize = 15

    if o.Primary then
        gradient(button, Theme.PinkLight, Theme.Pink, 0)
        button.BackgroundTransparency = 0
        outline.Transparency = 0.7
    end

    connect(button.MouseEnter, function()
        if not o.Primary then
            tween(button, 0.15, { BackgroundColor3 = Theme.FieldHover })
        end
        tween(outline, 0.15, { Transparency = 0.6 })
    end)
    connect(button.MouseLeave, function()
        if not o.Primary then
            tween(button, 0.15, { BackgroundColor3 = Theme.Field })
        end
        tween(outline, 0.15, { Transparency = o.Primary and 0.7 or 0.88 })
    end)
    connect(button.MouseButton1Click, function()
        local s = create("UIScale", { Scale = 0.97, Parent = button })
        tween(s, 0.25, { Scale = 1 }).Completed:Connect(function()
            s:Destroy()
        end)
        safeCall(o.Callback)
    end)

    -- a button breaks the list, so the next row needs no hairline
    self._noLine = true

    return {
        SetText = function(_, text)
            button.Text = text
        end,
    }
end

function Section:AddSlider(flag, o)
    o = o or {}
    local min, max = o.Min or 0, o.Max or 100
    local rounding = o.Rounding or 0
    local element = register(flag, { Type = "Slider", Value = min, Callback = o.Callback })

    local first = (self._n or 0) == 0 or self._noLine
    self._noLine = false
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    if not first then
        create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.White,
            BackgroundTransparency = 0.94,
            Parent = holder,
        })
    end
    local inner = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder,
    })
    padding(inner, 10, 0, 12, 0)
    vlist(inner, 9)

    local top = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = inner })
    create("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Text = o.Text or "Slider",
        FontFace = Fonts.SemiBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = top,
    })
    local readout = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 80, 1, 0),
        TextSize = 14,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = top,
    })

    local area = create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Active = true,
        LayoutOrder = 2,
        Parent = inner,
    })
    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 7, 0.5, 0),
        Size = UDim2.new(1, -14, 0, 6),
        BackgroundColor3 = Theme.Track,
        BackgroundTransparency = 0.3,
        Parent = area,
    })
    pill(track)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), Parent = track })
    pill(fill)
    pinkFill(fill, 0)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.White,
        Parent = track,
    })
    pill(knob)

    function element:Set(value, silent)
        value = math.clamp(tonumber(value) or min, min, max)
        local m = 10 ^ rounding
        value = math.floor(value * m + 0.5) / m
        local changed = value ~= self.Value
        self.Value = value
        local a = max == min and 0 or (value - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        readout.Text = string.format("%." .. rounding .. "f", value) .. (o.Suffix or "")
        if changed and not silent then
            self:_fire(value)
        end
    end

    local dragging = false
    local function update(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        element:Set(min + (max - min) * a)
    end
    connect(area.InputBegan, function(input)
        if isPress(input) then
            dragging = true
            tween(knob, 0.15, { Size = UDim2.fromOffset(18, 18) })
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and isMove(input) then
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and isPress(input) then
            dragging = false
            tween(knob, 0.15, { Size = UDim2.fromOffset(14, 14) })
        end
    end)

    element.Value = nil
    element:Set(o.Default or min, true)
    return element
end

function Section:AddDropdown(flag, o)
    o = o or {}
    local multi = o.Multi == true
    local values = o.Values or {}
    local section = self
    local element = register(flag, { Type = "Dropdown", Value = multi and {} or nil, Callback = o.Callback, Multi = multi })

    local _, slot = makeRow(self, o.Text, o.Description, o.Width or 170)
    local box, outline = field(slot, { Class = "TextButton", Size = UDim2.fromScale(1, 1) })
    local shown = create("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -36, 1, 0),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = box,
    })
    local arrowHolder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Parent = box,
    })
    local arrow = chevron(arrowHolder, 12, Theme.Sub)

    local listFrame, rows

    local function display()
        if multi then
            local list = element.Value
            shown.Text = #list == 0 and "None" or table.concat(list, ", ")
            shown.TextColor3 = #list == 0 and Theme.Muted or Theme.Text
        else
            shown.Text = element.Value ~= nil and tostring(element.Value) or "Select..."
            shown.TextColor3 = element.Value ~= nil and Theme.Text or Theme.Muted
        end
    end

    local function isSelected(value)
        if multi then
            return table.find(element.Value, value) ~= nil
        end
        return element.Value == value
    end

    local function paintRows()
        if not rows then
            return
        end
        for value, r in pairs(rows) do
            local on = isSelected(value)
            r.Button.BackgroundTransparency = on and 0.1 or 1
            r.Button.TextColor3 = on and Theme.Text or Theme.Sub
            r.Dot.Visible = on
        end
    end

    function element:Set(value, silent)
        if multi then
            local list = {}
            for _, v in ipairs(values) do
                if typeof(value) == "table" and table.find(value, v) then
                    table.insert(list, v)
                end
            end
            self.Value = list
        else
            self.Value = table.find(values, value) and value or nil
        end
        display()
        paintRows()
        if not silent then
            self:_fire(self.Value)
        end
    end

    function element:SetValues(newValues)
        values = newValues or {}
        closePopup()
        self:Set(self.Value, true)
    end

    local function open()
        local window = section.Window
        local root = window.Root
        local scale = window.Scale.Scale
        local rel = (box.AbsolutePosition - root.AbsolutePosition) / scale
        local width = box.AbsoluteSize.X / scale
        local height = math.min(#values * 30 + 10, 210)

        local y = rel.Y + 34
        if y + height > root.AbsoluteSize.Y / scale - 10 then
            y = rel.Y - height - 4
        end

        listFrame = create("ScrollingFrame", {
            Position = UDim2.fromOffset(rel.X, y),
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = Theme.Popup,
            BackgroundTransparency = 0.02,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Pink,
            ZIndex = 50,
            Parent = window.Overlay,
        })
        corner(listFrame, 9)
        stroke(listFrame, 0.82)
        padding(listFrame, 5)
        vlist(listFrame, 2)

        rows = {}
        for i, value in ipairs(values) do
            local item = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Theme.FieldHover,
                BackgroundTransparency = 1,
                Text = tostring(value),
                TextSize = 14,
                TextColor3 = Theme.Sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = i,
                ZIndex = 51,
                Parent = listFrame,
            })
            corner(item, 6)
            padding(item, 0, 10, 0, 16)
            local dot = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, -9, 0.5, 0),
                Size = UDim2.fromOffset(4, 14),
                ZIndex = 52,
                Parent = item,
            })
            pill(dot)
            pinkFill(dot, 90)
            rows[value] = { Button = item, Dot = dot }

            connect(item.MouseEnter, function()
                if not isSelected(value) then
                    item.BackgroundTransparency = 0.5
                end
            end)
            connect(item.MouseLeave, function()
                if not isSelected(value) then
                    item.BackgroundTransparency = 1
                end
            end)
            connect(item.MouseButton1Click, function()
                if multi then
                    local list = table.clone(element.Value)
                    local index = table.find(list, value)
                    if index then
                        table.remove(list, index)
                    else
                        table.insert(list, value)
                    end
                    element:Set(list)
                else
                    element:Set(value)
                    closePopup()
                end
            end)
        end
        paintRows()

        tween(arrow, 0.2, { Rotation = 180 })
        outline.Transparency = 0.6
        openPopup({
            Frame = listFrame,
            Owner = box,
            Close = function()
                tween(arrow, 0.2, { Rotation = 0 })
                outline.Transparency = 0.88
                if listFrame then
                    listFrame:Destroy()
                end
                listFrame, rows = nil, nil
            end,
        })
    end

    connect(box.MouseButton1Click, function()
        if listFrame then
            closePopup()
        else
            open()
        end
    end)

    element:Set(o.Default, true)
    return element
end

function Section:AddInput(flag, o)
    o = o or {}
    local element = register(flag, { Type = "Input", Value = o.Default or "", Callback = o.Callback })

    local _, slot = makeRow(self, o.Text, o.Description, o.Width or 170)
    local box, outline = field(slot, { Size = UDim2.fromScale(1, 1) })
    local input = create("TextBox", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Text = element.Value,
        PlaceholderText = o.Placeholder or "Type here...",
        PlaceholderColor3 = Theme.Muted,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = box,
    })

    function element:Set(text, silent)
        text = tostring(text or "")
        if o.Numeric then
            text = text:gsub("[^%d%.%-]", "")
        end
        input.Text = text
        self.Value = text
        if not silent then
            self:_fire(text)
        end
    end

    connect(input.Focused, function()
        outline.Color = Theme.Pink
        tween(outline, 0.15, { Transparency = 0.3 })
    end)
    connect(input.FocusLost, function(enter)
        outline.Color = Theme.White
        tween(outline, 0.15, { Transparency = 0.88 })
        if enter or not o.Finished then
            element:Set(input.Text)
        end
    end)

    return element
end

function Section:AddKeybind(flag, o)
    o = o or {}
    local element = register(flag, { Type = "Keybind", Value = nil, Callback = o.Callback })

    local _, slot = makeRow(self, o.Text, o.Description, 90)
    local box, outline = field(slot, { Class = "TextButton", Size = UDim2.fromScale(1, 1) })
    box.FontFace = Fonts.SemiBold
    box.TextSize = 13

    local listening = false
    local function display()
        if listening then
            box.Text = "..."
        else
            box.Text = element.Value and element.Value.Name or "None"
        end
    end

    function element:Set(key, silent)
        if typeof(key) == "string" then
            local ok, found = pcall(function()
                return Enum.KeyCode[key]
            end)
            if not ok then
                ok, found = pcall(function()
                    return Enum.UserInputType[key]
                end)
            end
            key = ok and found or nil
        end
        self.Value = key
        display()
        if not silent then
            safeCall(o.ChangedCallback, key)
        end
    end

    connect(box.MouseButton1Click, function()
        listening = true
        outline.Color = Theme.Pink
        outline.Transparency = 0.3
        display()
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if listening then
            local key
            if input.UserInputType == Enum.UserInputType.Keyboard then
                key = input.KeyCode
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                key = Enum.UserInputType.MouseButton2
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                key = Enum.UserInputType.MouseButton3
            else
                return
            end
            listening = false
            outline.Color = Theme.White
            outline.Transparency = 0.88
            if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
                key = nil
            end
            element:Set(key)
            return
        end
        if processed or not element.Value then
            return
        end
        if input.KeyCode == element.Value or input.UserInputType == element.Value then
            element:_fire(element.Value)
        end
    end)

    element:Set(o.Default, true)
    return element
end

function Section:AddColorPicker(flag, o)
    o = o or {}
    local section = self
    local element = register(flag, { Type = "ColorPicker", Value = o.Default or Theme.Pink, Callback = o.Callback })
    local h, s, v = element.Value:ToHSV()

    local _, slot = makeRow(self, o.Text, o.Description, 44)
    local swatch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(44, 24),
        BackgroundColor3 = element.Value,
        BackgroundTransparency = 0,
        Parent = slot,
    })
    corner(swatch, 7)
    stroke(swatch, 0.75)

    local popup, refreshPopup

    function element:Set(color, silent)
        if typeof(color) == "string" then
            color = hexToColor(color)
        end
        if typeof(color) ~= "Color3" then
            return
        end
        self.Value = color
        h, s, v = color:ToHSV()
        swatch.BackgroundColor3 = color
        if refreshPopup then
            refreshPopup()
        end
        if not silent then
            self:_fire(color)
        end
    end

    local function fromHSV()
        element.Value = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = element.Value
        if refreshPopup then
            refreshPopup()
        end
        element:_fire(element.Value)
    end

    local function open()
        local window = section.Window
        local root = window.Root
        local scale = window.Scale.Scale
        local rel = (swatch.AbsolutePosition - root.AbsolutePosition) / scale
        local width, height = 220, 230

        local x = rel.X + swatch.AbsoluteSize.X / scale - width
        local y = rel.Y + 30
        if y + height > root.AbsoluteSize.Y / scale - 10 then
            y = rel.Y - height - 6
        end

        popup = create("Frame", {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = Theme.Popup,
            BackgroundTransparency = 0.02,
            ZIndex = 50,
            Parent = window.Overlay,
        })
        corner(popup, 12)
        stroke(popup, 0.82)
        padding(popup, 12)

        -- Saturation / value square made from two gradient layers, no image assets needed.
        local map = create("Frame", {
            Size = UDim2.new(1, 0, 0, 140),
            ZIndex = 51,
            Parent = popup,
        })
        corner(map, 8)
        local whiteLayer = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.White,
            ZIndex = 52,
            Parent = map,
        })
        corner(whiteLayer, 8)
        create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteLayer })
        local blackLayer = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = rgb(0, 0, 0),
            ZIndex = 53,
            Parent = map,
        })
        corner(blackLayer, 8)
        create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackLayer })
        local cursor = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            ZIndex = 54,
            Parent = map,
        })
        pill(cursor)
        stroke(cursor, 0, Theme.White, 2)

        local hue = create("Frame", {
            Position = UDim2.fromOffset(0, 150),
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundColor3 = Theme.White,
            ZIndex = 51,
            Parent = popup,
        })
        pill(hue)
        local keys = {}
        for i = 0, 6 do
            table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
        end
        create("UIGradient", { Color = ColorSequence.new(keys), Parent = hue })
        local hueKnob = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(6, 16),
            BackgroundColor3 = Theme.White,
            ZIndex = 52,
            Parent = hue,
        })
        pill(hueKnob)
        stroke(hueKnob, 0.4, rgb(0, 0, 0))

        local bottom = create("Frame", {
            Position = UDim2.fromOffset(0, 176),
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            ZIndex = 51,
            Parent = popup,
        })
        local preview = create("Frame", { Size = UDim2.fromOffset(30, 30), ZIndex = 52, Parent = bottom })
        corner(preview, 8)
        stroke(preview, 0.75)
        local hexBox, hexOutline = field(bottom, {
            Position = UDim2.fromOffset(40, 0),
            Size = UDim2.new(1, -40, 1, 0),
        })
        hexBox.ZIndex = 52
        local hexInput = create("TextBox", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 1, 0),
            BackgroundTransparency = 1,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 53,
            Parent = hexBox,
        })

        refreshPopup = function()
            map.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.fromScale(s, 1 - v)
            hueKnob.Position = UDim2.fromScale(h, 0.5)
            preview.BackgroundColor3 = element.Value
            if not hexInput:IsFocused() then
                hexInput.Text = "#" .. colorToHex(element.Value)
            end
        end
        refreshPopup()

        local dragging
        local function update(position)
            if dragging == "map" then
                s = math.clamp((position.X - map.AbsolutePosition.X) / map.AbsoluteSize.X, 0, 1)
                v = 1 - math.clamp((position.Y - map.AbsolutePosition.Y) / map.AbsoluteSize.Y, 0, 1)
            elseif dragging == "hue" then
                h = math.clamp((position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
            end
            fromHSV()
        end

        local conns = {
            map.InputBegan:Connect(function(input)
                if isPress(input) then
                    dragging = "map"
                    update(input.Position)
                end
            end),
            hue.InputBegan:Connect(function(input)
                if isPress(input) then
                    dragging = "hue"
                    update(input.Position)
                end
            end),
            UserInputService.InputChanged:Connect(function(input)
                if dragging and isMove(input) then
                    update(input.Position)
                end
            end),
            UserInputService.InputEnded:Connect(function(input)
                if isPress(input) then
                    dragging = nil
                end
            end),
            hexInput.Focused:Connect(function()
                hexOutline.Transparency = 0.4
            end),
            hexInput.FocusLost:Connect(function()
                hexOutline.Transparency = 0.88
                local color = hexToColor(hexInput.Text)
                if color then
                    element:Set(color)
                elseif refreshPopup then
                    refreshPopup()
                end
            end),
        }

        openPopup({
            Frame = popup,
            Owner = swatch,
            Close = function()
                for _, c in ipairs(conns) do
                    c:Disconnect()
                end
                refreshPopup = nil
                if popup then
                    popup:Destroy()
                end
                popup = nil
            end,
        })
    end

    connect(swatch.MouseButton1Click, function()
        if popup then
            closePopup()
        else
            open()
        end
    end)

    return element
end

function Section:AddLabel(text)
    local _, _, title = makeRow(self, text, nil, nil)
    title.FontFace = Fonts.Medium
    title.TextColor3 = Theme.Sub
    title.TextWrapped = true
    title.TextTruncate = Enum.TextTruncate.None
    title.AutomaticSize = Enum.AutomaticSize.Y
    return {
        SetText = function(_, value)
            title.Text = value
        end,
    }
end

function Section:AddParagraph(o)
    o = o or {}
    local _, _, title, desc = makeRow(self, o.Title or "Paragraph", o.Text or "", nil)
    return {
        SetTitle = function(_, value)
            title.Text = value
        end,
        SetText = function(_, value)
            desc.Text = value
        end,
    }
end

function Section:AddDivider(text)
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self),
        Parent = self.Holder,
    })
    create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.86,
        Parent = holder,
    })
    if text then
        local label = create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 16),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.Section,
            BackgroundTransparency = 0,
            Text = string.upper(text),
            FontFace = Fonts.Bold,
            TextSize = 11,
            TextColor3 = Theme.Muted,
            Parent = holder,
        })
        corner(label, 4)
        padding(label, 0, 8, 0, 8)
    end
    self._noLine = true
    return holder
end

--// Tabs and sections \\--

local Tab = {}
Tab.__index = Tab

function Tab:AddSection(name, side)
    if typeof(name) == "table" then
        side = name.Side
        name = name.Title or name.Name
    end
    local column = (side == "Right") and self.Right or self.Left

    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Section,
        BackgroundTransparency = 0.4,
        LayoutOrder = nextOrder(self),
        Parent = column,
    })
    corner(frame, 12)
    stroke(frame, 0.86)
    padding(frame, 12, 14, 8, 14)
    vlist(frame, 0)

    if name then
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 26),
            Text = name,
            FontFace = Fonts.Bold,
            TextSize = 17,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = 0,
            Parent = frame,
        })
    end

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = frame,
    })
    vlist(holder, 0)

    return setmetatable({ Holder = holder, Window = self.Window, _n = 0 }, Section)
end

function Tab:AddLeftSection(name)
    return self:AddSection(name, "Left")
end

function Tab:AddRightSection(name)
    return self:AddSection(name, "Right")
end

--// Window \\--

local Window = {}
Window.__index = Window

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

local function headerButton(parent, order)
    local button = create("TextButton", {
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Field,
        BackgroundTransparency = 0.45,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(button, 9)
    local s = stroke(button, 0.86)
    connect(button.MouseEnter, function()
        tween(button, 0.15, { BackgroundTransparency = 0.15 })
        tween(s, 0.15, { Transparency = 0.7 })
    end)
    connect(button.MouseLeave, function()
        tween(button, 0.15, { BackgroundTransparency = 0.45 })
        tween(s, 0.15, { Transparency = 0.86 })
    end)
    return button
end

function Velvet:CreateWindow(o)
    o = o or {}
    local title = o.Title or "Velvet"
    local win = setmetatable({
        Tabs = {},
        Visible = true,
        Keybind = o.Keybind or Enum.KeyCode.RightShift,
    }, Window)

    local gui = create("ScreenGui", {
        Name = "Velvet",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 60,
    })
    pcall(function()
        if protectgui then
            protectgui(gui)
        end
    end)
    mount(gui)
    win.Gui = gui
    self._gui = gui

    local root = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = o.Size or UDim2.fromOffset(820, 540),
        BackgroundColor3 = Theme.White,
        ClipsDescendants = true,
        Parent = gui,
    })
    corner(root, 16)
    stroke(root, 0.8)
    win.Root = root
    win.Scale = create("UIScale", { Parent = root })

    -- Backdrop: mauve on top fading to navy at the bottom...
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Mauve),
            ColorSequenceKeypoint.new(0.3, Theme.Mauve:Lerp(Theme.NavyMid, 0.55)),
            ColorSequenceKeypoint.new(0.6, Theme.NavyMid:Lerp(Theme.Navy, 0.4)),
            ColorSequenceKeypoint.new(1, Theme.Navy),
        }),
        Parent = root,
    })
    -- ...a rose haze sweeping in from the top right...
    local haze = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Haze,
        Parent = root,
    })
    corner(haze, 16)
    create("UIGradient", {
        Rotation = -40,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 1),
            NumberSequenceKeypoint.new(0.78, 0.72),
            NumberSequenceKeypoint.new(1, 0.08),
        }),
        Parent = haze,
    })
    -- ...and a navy wash on the left so the sidebar side stays dark.
    local wash = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Navy,
        Parent = root,
    })
    corner(wash, 16)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(0.45, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = wash,
    })

    -- Sidebar
    local sidebar = create("Frame", {
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(0, 190, 1, -16),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = 0.25,
        Parent = root,
    })
    corner(sidebar, 12)
    stroke(sidebar, 0.88)

    local brand = create("Frame", {
        Position = UDim2.fromOffset(16, 18),
        Size = UDim2.new(1, -32, 0, 40),
        BackgroundTransparency = 1,
        Active = true,
        Parent = sidebar,
    })
    local logo = create("Frame", { Size = UDim2.fromOffset(38, 38), Parent = brand })
    corner(logo, 10)
    gradient(logo, Theme.PinkLight, Theme.PinkDeep, 45)
    if o.Logo then
        create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(24, 24),
            Image = tonumber(o.Logo) and ("rbxassetid://" .. o.Logo) or o.Logo,
            Parent = logo,
        })
    else
        create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(title, 1, 1)),
            FontFace = Fonts.Bold,
            TextSize = 22,
            Parent = logo,
        })
    end
    create("TextLabel", {
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -48, 0, 22),
        Text = title,
        FontFace = Fonts.Bold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = brand,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(48, 21),
        Size = UDim2.new(1, -48, 0, 18),
        Text = o.Subtitle or "Hub",
        TextSize = 14,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = brand,
    })

    local tabList = create("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 76),
        Size = UDim2.new(1, -20, 1, -76 - 66),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        Parent = sidebar,
    })
    vlist(tabList, 5)
    win.TabList = tabList

    -- Footer: player + version
    local footer = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.new(1, -20, 0, 48),
        BackgroundColor3 = Theme.Field,
        BackgroundTransparency = 0.5,
        Parent = sidebar,
    })
    corner(footer, 10)
    stroke(footer, 0.9)
    local avatar = create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Field,
        BackgroundTransparency = 0,
        Image = LocalPlayer and ("rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150") or "",
        Parent = footer,
    })
    pill(avatar)
    stroke(avatar, 0.2, Theme.Pink, 1.5)
    create("TextLabel", {
        Position = UDim2.fromOffset(48, 7),
        Size = UDim2.new(1, -56, 0, 18),
        Text = LocalPlayer and LocalPlayer.DisplayName or "Player",
        FontFace = Fonts.SemiBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = footer,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(48, 24),
        Size = UDim2.new(1, -56, 0, 16),
        Text = o.Footer or "v2.0",
        TextSize = 12,
        TextColor3 = Theme.Pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = footer,
    })

    -- Main area
    local main = create("Frame", {
        Position = UDim2.fromOffset(212, 0),
        Size = UDim2.new(1, -212, 1, 0),
        BackgroundTransparency = 1,
        Parent = root,
    })

    local header = create("Frame", {
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.new(1, -14, 0, 56),
        BackgroundTransparency = 1,
        Active = true,
        Parent = main,
    })
    win.TabTitle = create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 32),
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = 30,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })
    win.TabDescription = create("TextLabel", {
        Position = UDim2.fromOffset(1, 34),
        Size = UDim2.new(1, -100, 0, 18),
        Text = "",
        TextSize = 15,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })

    local controls = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(76, 34),
        BackgroundTransparency = 1,
        Parent = header,
    })
    hlist(controls, 8)

    local minimize = headerButton(controls, 1)
    local dash = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(12, 2),
        BackgroundColor3 = Theme.Text,
        Parent = minimize,
    })
    pill(dash)
    connect(minimize.MouseButton1Click, function()
        win:SetVisible(false)
    end)

    local close = headerButton(controls, 2)
    for _, rotation in ipairs({ 45, -45 }) do
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(14, 2),
            Rotation = rotation,
            BackgroundColor3 = Theme.Text,
            Parent = close,
        })
        pill(bar)
    end
    connect(close.MouseButton1Click, function()
        Velvet:Unload()
    end)

    win.Content = create("Frame", {
        Position = UDim2.fromOffset(0, 86),
        Size = UDim2.new(1, -8, 1, -94),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = main,
    })

    -- Popups float above everything inside the window.
    win.Overlay = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = root,
    })

    -- Dragging from the header or the logo.
    local dragStart, startPos
    local function beginDrag(input)
        if isPress(input) then
            dragStart = input.Position
            startPos = root.Position
            closePopup()
        end
    end
    connect(header.InputBegan, beginDrag)
    connect(brand.InputBegan, beginDrag)
    connect(UserInputService.InputChanged, function(input)
        if dragStart and isMove(input) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if isPress(input) then
            dragStart = nil
        end
    end)

    -- Reopen button while hidden (needed on touch devices).
    local bubble = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(44, 44),
        Text = string.upper(string.sub(title, 1, 1)),
        FontFace = Fonts.Bold,
        TextSize = 20,
        Visible = false,
        Parent = gui,
    })
    bubble.BackgroundTransparency = 0
    corner(bubble, 12)
    gradient(bubble, Theme.PinkLight, Theme.PinkDeep, 45)
    stroke(bubble, 0.6)
    connect(bubble.MouseButton1Click, function()
        win:SetVisible(true)
    end)
    win.Bubble = bubble

    connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == win.Keybind then
            win:SetVisible(not win.Visible)
        end
    end)

    -- Notification stack
    local notes = create("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.new(0, 290, 1, -36),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    vlist(notes, 8).VerticalAlignment = Enum.VerticalAlignment.Bottom
    self._notes = notes

    win.Scale.Scale = 0.95
    tween(win.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

    return win
end

function Window:AddTab(name, o)
    o = o or {}
    local tab = setmetatable({ Name = name, Description = o.Description or "", Window = self, _n = 0 }, Tab)

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 1,
        LayoutOrder = #self.Tabs + 1,
        Parent = self.TabList,
    })
    corner(button, 10)
    local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = button })
    corner(fill, 10)
    gradient(fill, Theme.PinkLight, Theme.PinkMauve, 0)
    local fillStroke = stroke(fill, 1, Theme.White)

    local textX = 14
    local icon
    if o.Icon then
        icon = create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            Image = tonumber(o.Icon) and ("rbxassetid://" .. o.Icon) or o.Icon,
            ImageColor3 = Theme.Sub,
            ZIndex = 2,
            Parent = button,
        })
        textX = 42
    end
    local label = create("TextLabel", {
        Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.new(1, -textX - 8, 1, 0),
        Text = name,
        FontFace = Fonts.SemiBold,
        TextSize = 16,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = button,
    })

    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Pink,
        Visible = false,
        Parent = self.Content,
    })
    padding(page, 0, 8, 8, 0)
    hlist(page, 10).VerticalAlignment = Enum.VerticalAlignment.Top
    connect(page:GetPropertyChangedSignal("CanvasPosition"), closePopup)

    local function column(order)
        local frame = create("Frame", {
            Size = UDim2.new(0.5, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = page,
        })
        vlist(frame, 10)
        return frame
    end
    tab.Left = column(1)
    tab.Right = column(2)
    tab.Page = page

    function tab:_setActive(active)
        tween(fill, 0.25, { BackgroundTransparency = active and 0 or 1 })
        tween(fillStroke, 0.25, { Transparency = active and 0.6 or 1 })
        tween(label, 0.25, { TextColor3 = active and Theme.Dark or Theme.Sub })
        if icon then
            tween(icon, 0.25, { ImageColor3 = active and Theme.Dark or Theme.Sub })
        end
    end

    connect(button.MouseEnter, function()
        if self.ActiveTab ~= tab then
            tween(button, 0.15, { BackgroundTransparency = 0.93 })
            tween(label, 0.15, { TextColor3 = Theme.Text })
        end
    end)
    connect(button.MouseLeave, function()
        tween(button, 0.15, { BackgroundTransparency = 1 })
        if self.ActiveTab ~= tab then
            tween(label, 0.15, { TextColor3 = Theme.Sub })
        end
    end)
    connect(button.MouseButton1Click, function()
        button.BackgroundTransparency = 1
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:SelectTab(tab)
    end
    return tab
end

function Window:SelectTab(tab)
    if self.ActiveTab == tab then
        return
    end
    closePopup()
    if self.ActiveTab then
        self.ActiveTab:_setActive(false)
        self.ActiveTab.Page.Visible = false
    end
    self.ActiveTab = tab
    tab:_setActive(true)

    tab.Page.Visible = true
    tab.Page.Position = UDim2.fromOffset(0, 10)
    tween(tab.Page, 0.35, { Position = UDim2.fromOffset(0, 0) })

    self.TabTitle.Text = tab.Name
    self.TabDescription.Text = tab.Description
end

function Window:SetVisible(visible)
    self.Visible = visible
    self.Bubble.Visible = not visible
    closePopup()
    if visible then
        self.Root.Visible = true
        self.Scale.Scale = 0.95
        tween(self.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    else
        tween(self.Scale, 0.15, { Scale = 0.95 }).Completed:Connect(function()
            if not self.Visible then
                self.Root.Visible = false
            end
        end)
    end
end

function Window:SetKeybind(key)
    self.Keybind = key
end

--// Notifications \\--

function Velvet:Notify(o)
    if typeof(o) == "string" then
        o = { Text = o }
    end
    o = o or {}
    local holder = self._notes
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
        Position = UDim2.fromOffset(320, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Popup,
        BackgroundTransparency = 0.05,
        ClipsDescendants = true,
        Parent = slot,
    })
    corner(card, 12)
    stroke(card, 0.84)

    local body = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    padding(body, 12, 14, 14, 14)
    vlist(body, 3)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Text = o.Title or "Notification",
        FontFace = Fonts.Bold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = body,
    })
    if o.Text then
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = o.Text,
            TextSize = 13,
            TextColor3 = Theme.Sub,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            Parent = body,
        })
    end

    local timer = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2),
        Parent = card,
    })
    pinkFill(timer, 0)

    tween(card, 0.4, { Position = UDim2.fromOffset(0, 0) })
    tween(timer, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        if not card.Parent then
            return
        end
        tween(card, 0.3, { Position = UDim2.fromOffset(320, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.32)
        slot:Destroy()
    end)
end

--// Configs \\--

local function serialize(element)
    local value = element.Value
    if element.Type == "ColorPicker" then
        return colorToHex(value)
    elseif element.Type == "Keybind" then
        return value and value.Name or nil
    end
    return value
end

function Velvet:SaveConfig(name)
    if not writefile then
        return false, "writefile is not available"
    end
    local data = {}
    for flag, element in pairs(self.Flags) do
        data[flag] = serialize(element)
    end
    if isfolder and makefolder and not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
    writefile(self.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Velvet:LoadConfig(name)
    if not (readfile and isfile) then
        return false, "readfile is not available"
    end
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then
        return false, "no config named " .. name
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(path))
    if not ok then
        return false, "config is corrupted"
    end
    for flag, value in pairs(data) do
        local element = self.Flags[flag]
        if element and element.Set then
            element:Set(value)
        end
    end
    return true
end

function Velvet:ListConfigs()
    local list = {}
    if listfiles and isfolder and isfolder(self.ConfigFolder) then
        for _, file in ipairs(listfiles(self.ConfigFolder)) do
            local name = file:match("([^/\\]+)%.json$")
            if name then
                table.insert(list, name)
            end
        end
    end
    return list
end

--// Teardown \\--

function Velvet:Unload()
    closePopup()
    for _, c in ipairs(self._connections) do
        c:Disconnect()
    end
    table.clear(self._connections)
    if self._gui then
        self._gui:Destroy()
        self._gui = nil
    end
end

return Velvet
