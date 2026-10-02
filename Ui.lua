--[[
    Ui3
    Obsidian's layout and API, dressed in Syde's colors and style.

    Supported so far:
        Library:CreateWindow
        Window:AddTab
        Tab:AddGroupbox / AddLeftGroupbox / AddRightGroupbox
        Groupbox:AddToggle / AddButton / AddLabel
        Toggle:AddColorPicker / Label:AddColorPicker
]]

local cloneref = (cloneref or clonereference or function(Object)
    return Object
end)

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer

local getgenv = getgenv or function()
    return shared
end
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
    return CoreGui
end

local Toggles = {}
local Options = {}

local Library = {
    Toggles = Toggles,
    Options = Options,

    Registry = setmetatable({}, { __mode = "k" }),
    Updaters = {},
    Signals = {},
    UnloadCallbacks = {},
    Tabs = {},

    ActiveTab = nil,
    OpenedMenu = nil,

    Toggled = false,
    Unloaded = false,

    ToggleKeybind = Enum.KeyCode.RightControl,
    CornerRadius = 8,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,

    --// Syde palette \\--
    Scheme = {
        BackgroundColor = Color3.fromRGB(17, 17, 17),
        ContainerColor = Color3.fromRGB(20, 20, 20),
        MainColor = Color3.fromRGB(24, 24, 24),
        SecondaryColor = Color3.fromRGB(29, 29, 29),
        AccentColor = Color3.fromRGB(255, 151, 227),
        OutlineColor = Color3.fromRGB(39, 39, 39),
        FontColor = Color3.fromRGB(255, 255, 255),
        Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),

        RedColor = Color3.fromRGB(255, 101, 104),
        DarkColor = Color3.fromRGB(0, 0, 0),
        WhiteColor = Color3.fromRGB(255, 255, 255),
    },

    --// Syde-style easing: long, smooth, exponential \\--
    TweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
    FastTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

local Assets = {
    Shadow = "rbxassetid://5554236805",
    SaturationMap = "rbxassetid://4155801252",
    Checkers = "rbxassetid://139785960036434",
}

--// Lucide icons (same module Obsidian uses) \\--
local Icons
pcall(function()
    Icons = loadstring(
        game:HttpGet("https://raw.githubusercontent.com/mstudio45/lucide-roblox-direct/refs/heads/main/source.lua")
    )()
end)

function Library:GetIcon(Icon)
    if Icon == nil then
        return nil
    end

    if tonumber(Icon) then
        return { Url = "rbxassetid://" .. tostring(Icon) }
    end

    if typeof(Icon) == "string" and Icon:match("^rbxasset") then
        return { Url = Icon }
    end

    if Icons then
        local Success, Result = pcall(Icons.GetAsset, Icon)
        if Success and Result then
            return Result
        end
    end

    return nil
end

local function ApplyIcon(Image, Icon)
    Image.Image = Icon.Url or ""
    Image.ImageRectOffset = Icon.ImageRectOffset or Vector2.zero
    Image.ImageRectSize = Icon.ImageRectSize or Vector2.zero
end

--// Instance creation + theme registry \\--
local ThemeProps = {
    BackgroundColor3 = true,
    BorderColor3 = true,
    TextColor3 = true,
    TextStrokeColor3 = true,
    PlaceholderColor3 = true,
    ImageColor3 = true,
    ScrollBarImageColor3 = true,
    Color = true,
    FontFace = true,
}

local Defaults = {
    Frame = { BorderSizePixel = 0 },
    ScrollingFrame = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
    },
    ImageLabel = { BackgroundTransparency = 1, BorderSizePixel = 0 },
    ImageButton = { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0 },
    TextLabel = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
        TextSize = 13,
    },
    TextButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = "Font",
        Text = "",
        TextColor3 = "FontColor",
        TextSize = 13,
    },
    TextBox = {
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        FontFace = "Font",
        PlaceholderColor3 = function()
            return Library.Scheme.FontColor:Lerp(Library.Scheme.BackgroundColor, 0.6)
        end,
        TextColor3 = "FontColor",
        TextSize = 13,
    },
}

local function Resolve(Value)
    if typeof(Value) == "function" then
        return Value()
    end
    return Library.Scheme[Value]
end

local function IsThemed(Property, Value)
    return ThemeProps[Property]
        and (typeof(Value) == "function" or (typeof(Value) == "string" and Library.Scheme[Value] ~= nil))
end

local function New(ClassName, Properties)
    local Object = Instance.new(ClassName)

    local Merged = {}
    for Key, Value in Defaults[ClassName] or {} do
        Merged[Key] = Value
    end
    for Key, Value in Properties or {} do
        Merged[Key] = Value
    end

    local Parent = Merged.Parent
    Merged.Parent = nil

    for Key, Value in Merged do
        if IsThemed(Key, Value) then
            Library.Registry[Object] = Library.Registry[Object] or {}
            Library.Registry[Object][Key] = Value
            Object[Key] = Resolve(Value)
        else
            Object[Key] = Value
        end
    end

    if Parent then
        Object.Parent = Parent
    end

    return Object
end

-- Rebinds a themed property (e.g. switch a stroke from "OutlineColor" to "AccentColor") and tweens to it.
local function SetThemed(Object, Property, Value, Info)
    Library.Registry[Object] = Library.Registry[Object] or {}
    Library.Registry[Object][Property] = Value

    if Info == false then
        Object[Property] = Resolve(Value)
    else
        TweenService:Create(Object, Info or Library.TweenInfo, { [Property] = Resolve(Value) }):Play()
    end
end

local function Tween(Object, Info, Goal)
    local T = TweenService:Create(Object, Info or Library.TweenInfo, Goal)
    T:Play()
    return T
end

local function Corner(Parent, Radius)
    return New("UICorner", {
        CornerRadius = typeof(Radius) == "UDim" and Radius or UDim.new(0, Radius or Library.CornerRadius),
        Parent = Parent,
    })
end

local function Stroke(Parent, ColorKey, Transparency)
    return New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = ColorKey or "OutlineColor",
        Transparency = Transparency or 0,
        Parent = Parent,
    })
end

local function Padding(Parent, Top, Bottom, Left, Right)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, Top or 0),
        PaddingBottom = UDim.new(0, Bottom or Top or 0),
        PaddingLeft = UDim.new(0, Left or Top or 0),
        PaddingRight = UDim.new(0, Right or Left or Top or 0),
        Parent = Parent,
    })
end

local function List(Parent, Gap, Properties)
    local Props = {
        Padding = UDim.new(0, Gap or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Parent,
    }
    for Key, Value in Properties or {} do
        Props[Key] = Value
    end
    return New("UIListLayout", Props)
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
    return Signal
end

function Library:SafeCallback(Func, ...)
    if typeof(Func) ~= "function" then
        return
    end

    local Success, Error = pcall(Func, ...)
    if not Success then
        warn("[Ui3] Callback error: " .. tostring(Error))
    end
end

function Library:Validate(Info, Template)
    Info = typeof(Info) == "table" and Info or {}
    for Key, Value in Template do
        if Info[Key] == nil then
            Info[Key] = Value
        end
    end
    return Info
end

function Library:UpdateColorsUsingRegistry()
    for Object, Properties in Library.Registry do
        for Property, Value in Properties do
            Object[Property] = Resolve(Value)
        end
    end

    for _, Updater in Library.Updaters do
        Updater()
    end
end

function Library:SetAccent(Color)
    Library.Scheme.AccentColor = Color
    Library:UpdateColorsUsingRegistry()
end

function Library:SetFont(FontFace)
    if typeof(FontFace) == "EnumItem" then
        FontFace = Font.fromEnum(FontFace)
    end
    Library.Scheme.Font = FontFace
    Library:UpdateColorsUsingRegistry()
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadCallbacks, Callback)
end

local function IsClick(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(Input)
    return Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsInside(Object, Position)
    local Pos, Size = Object.AbsolutePosition, Object.AbsoluteSize
    return Position.X >= Pos.X and Position.X <= Pos.X + Size.X and Position.Y >= Pos.Y and Position.Y <= Pos.Y + Size.Y
end

--// ScreenGui \\--
local ScreenGui = New("ScreenGui", {
    Name = "Ui3",
    DisplayOrder = 999,
    IgnoreGuiInset = false,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(protectgui, ScreenGui)
if not pcall(function()
    ScreenGui.Parent = gethui()
end) or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
Library.ScreenGui = ScreenGui

-- Generic press-and-drag helper (mouse + touch).
local function TrackDrag(Handle, OnStart, OnMove, OnEnd)
    local Dragging = false

    Handle.InputBegan:Connect(function(Input)
        if not IsClick(Input) then
            return
        end
        Dragging = true
        if OnStart then
            OnStart(Input.Position)
        end

        local Ended
        Ended = Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false
                Ended:Disconnect()
                if OnEnd then
                    OnEnd()
                end
            end
        end)
    end)

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if Dragging and IsMove(Input) then
            OnMove(Input.Position)
        end
    end))
end

local function CloseOpenedMenu()
    if Library.OpenedMenu then
        Library.OpenedMenu:Close()
    end
end

Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, Processed)
    if IsClick(Input) and Library.OpenedMenu then
        local Menu = Library.OpenedMenu
        local Position = Vector2.new(Input.Position.X, Input.Position.Y)
        if not IsInside(Menu.Frame, Position) and not IsInside(Menu.Holder, Position) then
            Menu:Close()
        end
    end

    if Processed then
        return
    end

    if Input.KeyCode == Library.ToggleKeybind and Library.Window then
        Library:Toggle()
    end
end))

--// Element templates \\--
local Templates = {
    Window = {
        Title = "Ui3",
        Footer = "",
        Icon = nil,
        Size = UDim2.fromOffset(720, 560),
        Position = nil,
        Center = true,
        AutoShow = true,
        Resizable = true,
        SidebarWidth = 190,
        CornerRadius = 10,
        ToggleKeybind = Enum.KeyCode.RightControl,
    },
    Groupbox = {
        Side = "Left",
        Name = "Groupbox",
        Description = nil,
        IconName = nil,
    },
    Toggle = {
        Text = "Toggle",
        Default = false,
        Tooltip = nil,
        Disabled = false,
        Visible = true,
        Risky = false,
        Callback = function() end,
    },
    ColorPicker = {
        Default = Color3.new(1, 1, 1),
        Title = nil,
        Transparency = nil,
        Callback = function() end,
    },
}

--// Elements shared by every container (groupboxes for now) \\--
local Funcs = {}

function Funcs:AddColorPicker(Idx, Info)
    Info = Library:Validate(Info, Templates.ColorPicker)

    local ParentObj = self
    local AddonHolder = ParentObj.TextLabel

    local ColorPicker = {
        Value = Info.Default,
        Transparency = Info.Transparency or 0,
        Title = Info.Title,
        Callback = Info.Callback,
        Changed = nil,
        Type = "ColorPicker",
    }
    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

    --// Swatch \\--
    local Holder = New("TextButton", {
        BackgroundColor3 = ColorPicker.Value,
        Size = UDim2.fromOffset(18, 18),
        Parent = AddonHolder,
    })
    Corner(Holder, 5)
    local HolderStroke = Stroke(Holder)
    HolderStroke.Color = ColorPicker.Value:Lerp(Color3.new(0, 0, 0), 0.4)
    Library.Registry[HolderStroke] = nil

    local HolderCheckers = New("ImageLabel", {
        Image = Assets.Checkers,
        ImageTransparency = 1 - ColorPicker.Transparency,
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(1, 1),
        TileSize = UDim2.fromOffset(9, 9),
        ZIndex = 0,
        Parent = Holder,
    })
    Corner(HolderCheckers, 5)

    --// Popup menu \\--
    local MapSize = Library.IsMobile and 140 or 180
    local BarWidth = 14
    local MenuWidth = MapSize + (BarWidth + 8) * (Info.Transparency and 2 or 1) + 20

    local MenuShadow = New("ImageLabel", {
        Image = Assets.Shadow,
        ImageColor3 = "DarkColor",
        ImageTransparency = 0.4,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(23, 23, 277, 277),
        Visible = false,
        ZIndex = 49,
        Parent = ScreenGui,
    })

    local Menu = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        Size = UDim2.fromOffset(MenuWidth, 0),
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    })
    Corner(Menu, Library.CornerRadius)
    Stroke(Menu)
    Padding(Menu, 10)
    List(Menu, 8)
    local MenuScale = New("UIScale", { Parent = Menu })

    if typeof(ColorPicker.Title) == "string" then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            Text = ColorPicker.Title,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 51,
            Parent = Menu,
        })
    end

    local Row = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, MapSize),
        ZIndex = 51,
        Parent = Menu,
    })
    List(Row, 8, { FillDirection = Enum.FillDirection.Horizontal })

    local SatVibMap = New("ImageButton", {
        BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1),
        BackgroundTransparency = 0,
        Image = Assets.SaturationMap,
        Size = UDim2.fromOffset(MapSize, MapSize),
        ZIndex = 51,
        Parent = Row,
    })
    Corner(SatVibMap, 6)

    local SatVibCursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 52,
        Parent = SatVibMap,
    })
    Corner(SatVibCursor, UDim.new(1, 0))
    New("UIStroke", { Color = "DarkColor", Thickness = 1.5, Parent = SatVibCursor })

    local HueSequence = {}
    for Hue = 0, 1, 0.1 do
        table.insert(HueSequence, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
    end

    local HueBar = New("TextButton", {
        BackgroundColor3 = "WhiteColor",
        Size = UDim2.fromOffset(BarWidth, MapSize),
        ZIndex = 51,
        Parent = Row,
    })
    Corner(HueBar, UDim.new(1, 0))
    New("UIGradient", { Color = ColorSequence.new(HueSequence), Rotation = 90, Parent = HueBar })

    local HueCursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Size = UDim2.new(1, 4, 0, 4),
        ZIndex = 52,
        Parent = HueBar,
    })
    Corner(HueCursor, UDim.new(1, 0))
    New("UIStroke", { Color = "DarkColor", Parent = HueCursor })

    local AlphaBar, AlphaColor, AlphaCursor
    if Info.Transparency then
        AlphaBar = New("ImageButton", {
            Image = Assets.Checkers,
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromOffset(BarWidth, MapSize),
            TileSize = UDim2.fromOffset(8, 8),
            ZIndex = 51,
            Parent = Row,
        })
        Corner(AlphaBar, UDim.new(1, 0))

        AlphaColor = New("Frame", {
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 51,
            Parent = AlphaBar,
        })
        Corner(AlphaColor, UDim.new(1, 0))
        New("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = AlphaColor,
        })

        AlphaCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            Size = UDim2.new(1, 4, 0, 4),
            ZIndex = 52,
            Parent = AlphaBar,
        })
        Corner(AlphaCursor, UDim.new(1, 0))
        New("UIStroke", { Color = "DarkColor", Parent = AlphaCursor })
    end

    local InputRow = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 24),
        ZIndex = 51,
        Parent = Menu,
    })
    List(InputRow, 8, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
    })

    local function MakeBox(Placeholder)
        local Box = New("TextBox", {
            BackgroundColor3 = "SecondaryColor",
            PlaceholderText = Placeholder,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextSize = 12,
            ZIndex = 51,
            Parent = InputRow,
        })
        Corner(Box, 6)
        local BoxStroke = Stroke(Box)
        Box.Focused:Connect(function()
            SetThemed(BoxStroke, "Color", "AccentColor")
        end)
        Box.FocusLost:Connect(function()
            SetThemed(BoxStroke, "Color", "OutlineColor")
        end)
        return Box
    end

    local HexBox = MakeBox("#FFFFFF")
    local RgbBox = MakeBox("255, 255, 255")

    --// Logic \\--
    function ColorPicker:Display()
        ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)

        Holder.BackgroundColor3 = ColorPicker.Value
        HolderStroke.Color = ColorPicker.Value:Lerp(Color3.new(0, 0, 0), 0.4)
        HolderCheckers.ImageTransparency = 1 - ColorPicker.Transparency
        Holder.BackgroundTransparency = ColorPicker.Transparency

        SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
        SatVibCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
        HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue)

        if AlphaColor then
            AlphaColor.BackgroundColor3 = ColorPicker.Value
            AlphaCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency)
        end

        HexBox.Text = "#" .. ColorPicker.Value:ToHex():upper()
        RgbBox.Text = string.format(
            "%d, %d, %d",
            math.floor(ColorPicker.Value.R * 255 + 0.5),
            math.floor(ColorPicker.Value.G * 255 + 0.5),
            math.floor(ColorPicker.Value.B * 255 + 0.5)
        )
    end

    function ColorPicker:Update()
        ColorPicker:Display()
        Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency)
        Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency)
    end

    function ColorPicker:OnChanged(Func)
        ColorPicker.Changed = Func
    end

    function ColorPicker:SetHSVFromRGB(Color)
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
    end

    function ColorPicker:SetValueRGB(Color, Transparency)
        ColorPicker:SetHSVFromRGB(Color)
        ColorPicker.Transparency = Transparency or ColorPicker.Transparency
        ColorPicker:Update()
    end

    function ColorPicker:SetValue(HSV, Transparency)
        if typeof(HSV) == "Color3" then
            return ColorPicker:SetValueRGB(HSV, Transparency)
        end
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = HSV[1], HSV[2], HSV[3]
        ColorPicker.Transparency = Transparency or ColorPicker.Transparency
        ColorPicker:Update()
    end

    TrackDrag(SatVibMap, function(Position)
        local Pos, Size = SatVibMap.AbsolutePosition, SatVibMap.AbsoluteSize
        ColorPicker.Sat = math.clamp((Position.X - Pos.X) / Size.X, 0, 1)
        ColorPicker.Vib = 1 - math.clamp((Position.Y - Pos.Y) / Size.Y, 0, 1)
        ColorPicker:Update()
    end, function(Position)
        local Pos, Size = SatVibMap.AbsolutePosition, SatVibMap.AbsoluteSize
        ColorPicker.Sat = math.clamp((Position.X - Pos.X) / Size.X, 0, 1)
        ColorPicker.Vib = 1 - math.clamp((Position.Y - Pos.Y) / Size.Y, 0, 1)
        ColorPicker:Update()
    end)

    local function SetHue(Position)
        ColorPicker.Hue = math.clamp((Position.Y - HueBar.AbsolutePosition.Y) / HueBar.AbsoluteSize.Y, 0, 1)
        ColorPicker:Update()
    end
    TrackDrag(HueBar, SetHue, SetHue)

    if AlphaBar then
        local function SetAlpha(Position)
            ColorPicker.Transparency =
                math.clamp((Position.Y - AlphaBar.AbsolutePosition.Y) / AlphaBar.AbsoluteSize.Y, 0, 1)
            ColorPicker:Update()
        end
        TrackDrag(AlphaBar, SetAlpha, SetAlpha)
    end

    HexBox.FocusLost:Connect(function(Enter)
        local Success, Color = pcall(Color3.fromHex, HexBox.Text)
        if Success and typeof(Color) == "Color3" then
            ColorPicker:SetValueRGB(Color)
        else
            ColorPicker:Display()
        end
    end)

    RgbBox.FocusLost:Connect(function()
        local R, G, B = RgbBox.Text:match("(%d+)%D+(%d+)%D+(%d+)")
        if R and G and B then
            ColorPicker:SetValueRGB(
                Color3.fromRGB(math.clamp(tonumber(R), 0, 255), math.clamp(tonumber(G), 0, 255), math.clamp(tonumber(B), 0, 255))
            )
        else
            ColorPicker:Display()
        end
    end)

    --// Open / close \\--
    local MenuObject = { Frame = Menu, Holder = Holder }
    local Follow

    local function Reposition()
        local Viewport = workspace.CurrentCamera.ViewportSize
        local X = Holder.AbsolutePosition.X + Holder.AbsoluteSize.X - Menu.AbsoluteSize.X
        local Y = Holder.AbsolutePosition.Y + Holder.AbsoluteSize.Y + 6
        X = math.clamp(X, 4, math.max(4, Viewport.X - Menu.AbsoluteSize.X - 4))
        if Y + Menu.AbsoluteSize.Y > Viewport.Y - 4 then
            Y = Holder.AbsolutePosition.Y - Menu.AbsoluteSize.Y - 6
        end
        Menu.Position = UDim2.fromOffset(X, Y)
        MenuShadow.Position = UDim2.fromOffset(X - 16, Y - 16)
        MenuShadow.Size = UDim2.fromOffset(Menu.AbsoluteSize.X + 32, Menu.AbsoluteSize.Y + 32)
    end

    function MenuObject:Close()
        if Follow then
            Follow:Disconnect()
            Follow = nil
        end
        Menu.Visible = false
        MenuShadow.Visible = false
        if Library.OpenedMenu == MenuObject then
            Library.OpenedMenu = nil
        end
    end

    function MenuObject:Open()
        CloseOpenedMenu()
        Library.OpenedMenu = MenuObject

        Menu.Visible = true
        MenuShadow.Visible = true
        Reposition()
        MenuScale.Scale = 0.92
        Tween(MenuScale, Library.TweenInfo, { Scale = 1 })

        Follow = RunService.RenderStepped:Connect(Reposition)
    end

    ColorPicker.Menu = MenuObject

    Holder.MouseButton1Click:Connect(function()
        if Menu.Visible then
            MenuObject:Close()
        else
            MenuObject:Open()
        end
    end)

    ColorPicker:Display()

    Options[Idx] = ColorPicker
    if ParentObj.Addons then
        table.insert(ParentObj.Addons, ColorPicker)
    end

    return self
end

function Funcs:AddLabel(...)
    local Data = {}
    local First, Second = select(1, ...), select(2, ...)

    if typeof(First) == "table" or typeof(Second) == "table" then
        local Params = typeof(First) == "table" and First or Second
        Data.Text = Params.Text or ""
        Data.DoesWrap = Params.DoesWrap or false
        Data.Idx = typeof(Second) == "table" and First or nil
    else
        Data.Text = First or ""
        Data.DoesWrap = Second or false
    end

    local Groupbox = self
    local Label = {
        Text = Data.Text,
        Addons = {},
        Type = "Label",
    }

    local TextLabel = New("TextLabel", {
        AutomaticSize = Data.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Size = UDim2.new(1, 0, 0, 18),
        Text = Label.Text,
        TextTransparency = 0.3,
        TextWrapped = Data.DoesWrap,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Data.DoesWrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        Parent = Groupbox.Container,
    })
    List(TextLabel, 6, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    Label.TextLabel = TextLabel

    function Label:SetText(Text)
        Label.Text = Text
        TextLabel.Text = Text
    end

    function Label:SetVisible(Visible)
        TextLabel.Visible = Visible
    end

    setmetatable(Label, { __index = Funcs })

    if Data.Idx then
        Options[Data.Idx] = Label
    end

    return Label
end

function Funcs:AddToggle(Idx, Info)
    Info = Library:Validate(Info, Templates.Toggle)

    local Groupbox = self

    local Toggle = {
        Text = Info.Text,
        Value = Info.Default,
        Callback = Info.Callback,
        Changed = nil,

        Risky = Info.Risky,
        Disabled = Info.Disabled,
        Visible = Info.Visible,

        Addons = {},
        Type = "Toggle",
    }

    local Button = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Visible = Toggle.Visible,
        Parent = Groupbox.Container,
    })

    local Label = New("TextLabel", {
        Size = UDim2.new(1, -42, 1, 0),
        Text = Toggle.Text,
        TextColor3 = Toggle.Risky and "RedColor" or "FontColor",
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Button,
    })
    List(Label, 6, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    -- Obsidian switch, Syde glow underneath it.
    local Switch = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = "SecondaryColor",
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        ZIndex = 2,
        Parent = Button,
    })
    Corner(Switch, UDim.new(1, 0))
    Padding(Switch, 3)
    local SwitchStroke = Stroke(Switch)

    local SwitchGlow = New("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Image = Assets.Shadow,
        ImageColor3 = "AccentColor",
        ImageTransparency = 1,
        Position = UDim2.new(1, 12, 0.5, 0),
        ScaleType = Enum.ScaleType.Slice,
        Size = UDim2.fromOffset(34 + 24, 18 + 24),
        SliceCenter = Rect.new(23, 23, 277, 277),
        ZIndex = 1,
        Parent = Button,
    })

    local Ball = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "FontColor",
        BackgroundTransparency = 0.5,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 3,
        Parent = Switch,
    })
    Corner(Ball, UDim.new(1, 0))

    Toggle.TextLabel = Label
    Toggle.Container = Groupbox.Container

    function Toggle:Display(Instant)
        local Info = if Instant then false else Library.TweenInfo
        local On = Toggle.Value
        local Offset = On and 1 or 0

        SetThemed(Switch, "BackgroundColor3", On and "AccentColor" or "SecondaryColor", Info)
        SetThemed(SwitchStroke, "Color", On and "AccentColor" or "OutlineColor", Info)

        local Goals = {
            Ball = { AnchorPoint = Vector2.new(Offset, 0.5), Position = UDim2.fromScale(Offset, 0.5), BackgroundTransparency = On and 0 or 0.5 },
            Glow = { ImageTransparency = On and 0.6 or 1 },
            Label = { TextTransparency = Toggle.Disabled and 0.8 or (On and 0 or 0.4) },
        }

        if Instant then
            for Key, Value in Goals.Ball do
                Ball[Key] = Value
            end
            SwitchGlow.ImageTransparency = Goals.Glow.ImageTransparency
            Label.TextTransparency = Goals.Label.TextTransparency
        else
            Tween(Ball, Library.TweenInfo, Goals.Ball)
            Tween(SwitchGlow, Library.TweenInfo, Goals.Glow)
            Tween(Label, Library.FastTweenInfo, Goals.Label)
        end

        Switch.BackgroundTransparency = Toggle.Disabled and 0.6 or 0
        SwitchStroke.Transparency = Toggle.Disabled and 0.6 or 0
    end

    function Toggle:OnChanged(Func)
        Toggle.Changed = Func
    end

    function Toggle:SetValue(Value)
        Toggle.Value = not not Value
        Toggle:Display()
        Library:SafeCallback(Toggle.Callback, Toggle.Value)
        Library:SafeCallback(Toggle.Changed, Toggle.Value)
    end

    function Toggle:SetText(Text)
        Toggle.Text = Text
        Label.Text = Text
    end

    function Toggle:SetDisabled(Disabled)
        Toggle.Disabled = Disabled
        Button.Active = not Disabled
        Toggle:Display()
    end

    function Toggle:SetVisible(Visible)
        Toggle.Visible = Visible
        Button.Visible = Visible
    end

    Button.MouseEnter:Connect(function()
        if not Toggle.Disabled and not Toggle.Value then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.15 })
        end
    end)
    Button.MouseLeave:Connect(function()
        if not Toggle.Disabled and not Toggle.Value then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    Button.MouseButton1Click:Connect(function()
        if Toggle.Disabled then
            return
        end
        Toggle:SetValue(not Toggle.Value)
    end)

    table.insert(Library.Updaters, function()
        Toggle:Display(true)
    end)

    Toggle:Display(true)

    setmetatable(Toggle, { __index = Funcs })

    Toggles[Idx] = Toggle
    return Toggle
end

function Funcs:AddButton(...)
    local function GetInfo(...)
        local Data = {}
        local First, Second = select(1, ...), select(2, ...)

        if typeof(First) == "table" or typeof(Second) == "table" then
            local Params = typeof(First) == "table" and First or Second
            Data.Text = Params.Text or ""
            Data.Func = Params.Func or Params.Callback or function() end
            Data.DoubleClick = Params.DoubleClick or false
            Data.Risky = Params.Risky or false
            Data.Disabled = Params.Disabled or false
            Data.Visible = Params.Visible ~= false
            Data.Idx = typeof(Second) == "table" and First or nil
        else
            Data.Text = First or ""
            Data.Func = Second or function() end
            Data.DoubleClick = false
            Data.Risky = false
            Data.Disabled = false
            Data.Visible = true
        end

        return Data
    end

    local function CreateButton(Data, Holder)
        local Button = {
            Text = Data.Text,
            Func = Data.Func,
            DoubleClick = Data.DoubleClick,
            Risky = Data.Risky,
            Disabled = Data.Disabled,
            Visible = Data.Visible,
            Locked = false,
            Type = "Button",
        }

        local Base = New("TextButton", {
            BackgroundColor3 = "SecondaryColor",
            ClipsDescendants = true,
            Size = UDim2.fromScale(1, 1),
            Visible = Button.Visible,
            Parent = Holder,
        })
        Corner(Base, 6)
        local BaseStroke = Stroke(Base)

        local Label = New("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            Text = Button.Text,
            TextColor3 = Button.Risky and "RedColor" or "FontColor",
            TextTransparency = Button.Disabled and 0.8 or 0.4,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Base,
        })

        Button.Base = Base
        Button.Label = Label

        function Button:SetText(Text)
            Button.Text = Text
            Label.Text = Text
        end

        function Button:SetDisabled(Disabled)
            Button.Disabled = Disabled
            Base.Active = not Disabled
            Label.TextTransparency = Disabled and 0.8 or 0.4
            BaseStroke.Transparency = Disabled and 0.5 or 0
        end

        function Button:SetVisible(Visible)
            Button.Visible = Visible
            Base.Visible = Visible
        end

        Base.MouseEnter:Connect(function()
            if Button.Disabled then
                return
            end
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0 })
            SetThemed(Base, "BackgroundColor3", function()
                return Library.Scheme.SecondaryColor:Lerp(Library.Scheme.FontColor, 0.05)
            end, Library.FastTweenInfo)
        end)
        Base.MouseLeave:Connect(function()
            if Button.Disabled then
                return
            end
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
            SetThemed(Base, "BackgroundColor3", "SecondaryColor", Library.FastTweenInfo)
        end)

        -- Syde-style press: accent ripple + stroke flash.
        local function Ripple(Position)
            local Circle = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 0.75,
                Position = UDim2.fromOffset(Position.X - Base.AbsolutePosition.X, Position.Y - Base.AbsolutePosition.Y),
                Size = UDim2.fromOffset(0, 0),
                ZIndex = 0,
                Parent = Base,
            })
            Corner(Circle, UDim.new(1, 0))
            local Diameter = math.max(Base.AbsoluteSize.X, Base.AbsoluteSize.Y) * 2.2
            Tween(Circle, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {
                Size = UDim2.fromOffset(Diameter, Diameter),
                BackgroundTransparency = 1,
            })
            task.delay(0.6, function()
                Circle:Destroy()
            end)
        end

        local function Flash()
            SetThemed(BaseStroke, "Color", "AccentColor", Library.FastTweenInfo)
            task.delay(0.35, function()
                SetThemed(BaseStroke, "Color", "OutlineColor", Library.TweenInfo)
            end)
        end

        Base.InputBegan:Connect(function(Input)
            if IsClick(Input) and not Button.Disabled then
                Ripple(Input.Position)
            end
        end)

        Base.MouseButton1Click:Connect(function()
            if Button.Disabled or Button.Locked then
                return
            end

            if Button.DoubleClick then
                if Button.Armed then
                    Button.Armed = false
                    Label.Text = Button.Text
                    SetThemed(Label, "TextColor3", Button.Risky and "RedColor" or "FontColor", false)
                    Flash()
                    Library:SafeCallback(Button.Func)
                    return
                end

                Button.Armed = true
                Label.Text = "Are you sure?"
                SetThemed(Label, "TextColor3", "AccentColor", false)

                task.delay(1, function()
                    if Button.Armed then
                        Button.Armed = false
                        Label.Text = Button.Text
                        SetThemed(Label, "TextColor3", Button.Risky and "RedColor" or "FontColor", false)
                    end
                end)
                return
            end

            Flash()
            Library:SafeCallback(Button.Func)
        end)

        Button:SetDisabled(Button.Disabled)
        return Button
    end

    local Data = GetInfo(...)
    local Groupbox = self

    local Holder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
        Parent = Groupbox.Container,
    })
    List(Holder, 8, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
    })

    local Button = CreateButton(Data, Holder)
    Button.Holder = Holder

    -- Sub buttons sit next to the main one, like Obsidian.
    function Button:AddButton(...)
        local SubData = GetInfo(...)
        local SubButton = CreateButton(SubData, Holder)
        Button.SubButton = SubButton
        if SubData.Idx then
            Options[SubData.Idx] = SubButton
        end
        return SubButton
    end

    if Data.Idx then
        Options[Data.Idx] = Button
    end

    return Button
end

--// Window \\--
function Library:Toggle(Value)
    local Window = Library.Window
    if not Window then
        return
    end

    if Value == nil then
        Value = not Library.Toggled
    end
    Library.Toggled = Value

    if Value then
        Window.Root.Visible = true
        Window.Scale.Scale = 0.94
        Tween(Window.Scale, Library.TweenInfo, { Scale = 1 })
    else
        CloseOpenedMenu()
        local T = Tween(Window.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.94 })
        T.Completed:Connect(function()
            if not Library.Toggled then
                Window.Root.Visible = false
            end
        end)
    end
end

function Library:Unload()
    if Library.Unloaded then
        return
    end
    Library.Unloaded = true
    CloseOpenedMenu()

    for _, Signal in Library.Signals do
        pcall(function()
            Signal:Disconnect()
        end)
    end

    for _, Callback in Library.UnloadCallbacks do
        Library:SafeCallback(Callback)
    end

    table.clear(Toggles)
    table.clear(Options)
    ScreenGui:Destroy()
end

function Library:CreateWindow(WindowInfo)
    WindowInfo = Library:Validate(WindowInfo, Templates.Window)

    Library.CornerRadius = WindowInfo.CornerRadius
    Library.ToggleKeybind = WindowInfo.ToggleKeybind
    if WindowInfo.Font then
        Library:SetFont(WindowInfo.Font)
    end

    local SidebarWidth = WindowInfo.SidebarWidth
    local Viewport = workspace.CurrentCamera.ViewportSize
    local Size = UDim2.fromOffset(
        math.min(WindowInfo.Size.X.Offset, Viewport.X - 32),
        math.min(WindowInfo.Size.Y.Offset, Viewport.Y - 32)
    )

    local Window = {
        Tabs = {},
    }

    --// Root holds the shadow + main frame so both move together \\--
    local Root = New("Frame", {
        AnchorPoint = WindowInfo.Center and Vector2.new(0.5, 0.5) or Vector2.zero,
        BackgroundTransparency = 1,
        Position = WindowInfo.Position or (WindowInfo.Center and UDim2.fromScale(0.5, 0.5) or UDim2.fromOffset(40, 40)),
        Size = Size,
        Visible = false,
        Parent = ScreenGui,
    })
    local Scale = New("UIScale", { Parent = Root })

    New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = Assets.Shadow,
        ImageColor3 = "DarkColor",
        ImageTransparency = 0.35,
        Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Slice,
        Size = UDim2.new(1, 50, 1, 50),
        SliceCenter = Rect.new(23, 23, 277, 277),
        ZIndex = 0,
        Parent = Root,
    })

    local Main = New("Frame", {
        BackgroundColor3 = "BackgroundColor",
        ClipsDescendants = true,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        Parent = Root,
    })
    Corner(Main, WindowInfo.CornerRadius)
    Stroke(Main)

    -- A visible Modal button frees the mouse in first person while the UI is open.
    New("TextButton", {
        BackgroundTransparency = 1,
        Modal = true,
        Size = UDim2.fromOffset(0, 0),
        Parent = Main,
    })

    local function Line(Props)
        Props.BackgroundColor3 = "OutlineColor"
        Props.Parent = Props.Parent or Main
        return New("Frame", Props)
    end

    --// Top bar \\--
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        Parent = Main,
    })
    Line({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 1) })

    local TitleHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SidebarWidth, 1, 0),
        Parent = TopBar,
    })
    List(TitleHolder, 8, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    local WindowIcon = Library:GetIcon(WindowInfo.Icon)
    if WindowIcon then
        local IconImage = New("ImageLabel", {
            ImageColor3 = (tonumber(WindowInfo.Icon) and "WhiteColor") or "AccentColor",
            Size = UDim2.fromOffset(26, 26),
            Parent = TitleHolder,
        })
        ApplyIcon(IconImage, WindowIcon)
    end

    local TitleLabel = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = function()
            return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.Bold)
        end,
        Size = UDim2.fromOffset(0, 20),
        Text = WindowInfo.Title,
        TextSize = 18,
        Parent = TitleHolder,
    })

    -- Current tab info (where Obsidian puts its tab title/description).
    local TabInfo = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SidebarWidth + 1, 0),
        Size = UDim2.new(1, -SidebarWidth - 1 - 16, 1, 0),
        Parent = TopBar,
    })
    Padding(TabInfo, 0, 0, 14, 0)
    List(TabInfo, 1, { VerticalAlignment = Enum.VerticalAlignment.Center })

    local TabInfoTitle = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromScale(1, 0),
        Text = "",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabInfo,
    })
    local TabInfoDescription = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Size = UDim2.fromScale(1, 0),
        Text = "",
        TextSize = 12,
        TextTransparency = 0.5,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = TabInfo,
    })

    --// Sidebar + divider \\--
    Line({ Position = UDim2.fromOffset(SidebarWidth, 49), Size = UDim2.new(0, 1, 1, -70) })

    local Sidebar = New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(0, SidebarWidth, 1, -70),
        Parent = Main,
    })
    List(Sidebar, 4)
    Padding(Sidebar, 8, 8, 10, 10)

    --// Content container \\--
    local Container = New("Frame", {
        BackgroundColor3 = "ContainerColor",
        ClipsDescendants = true,
        Position = UDim2.fromOffset(SidebarWidth + 1, 49),
        Size = UDim2.new(1, -SidebarWidth - 1, 1, -70),
        Parent = Main,
    })

    --// Bottom bar \\--
    Line({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 1) })

    local BottomBar = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 20),
        Parent = Main,
    })

    local FooterLabel = New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        Text = WindowInfo.Footer,
        TextSize = 12,
        TextTransparency = 0.5,
        Parent = BottomBar,
    })

    --// Dragging (smoothed, Syde-style) \\--
    do
        local StartInput, StartPosition
        TrackDrag(TopBar, function(Position)
            StartInput = Position
            StartPosition = Root.Position
        end, function(Position)
            local Delta = Position - StartInput
            Tween(Root, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    StartPosition.X.Scale,
                    StartPosition.X.Offset + Delta.X,
                    StartPosition.Y.Scale,
                    StartPosition.Y.Offset + Delta.Y
                ),
            })
        end)
    end

    --// Resizing \\--
    if WindowInfo.Resizable then
        local Grip = New("TextButton", {
            AnchorPoint = Vector2.new(1, 1),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -2, 1, -2),
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 5,
            Parent = Main,
        })
        local GripIcon = New("ImageLabel", {
            ImageColor3 = "FontColor",
            ImageTransparency = 0.6,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 5,
            Parent = Grip,
        })
        local ResizeIcon = Library:GetIcon("move-diagonal-2")
        if ResizeIcon then
            ApplyIcon(GripIcon, ResizeIcon)
        else
            GripIcon.Visible = false
            New("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "◢", TextTransparency = 0.6, ZIndex = 5, Parent = Grip })
        end

        local StartInput, StartSize, StartPosition
        TrackDrag(Grip, function(Position)
            StartInput = Position
            StartSize = Root.AbsoluteSize / Scale.Scale
            StartPosition = Root.Position
        end, function(Position)
            local Delta = Position - StartInput
            local Vp = workspace.CurrentCamera.ViewportSize
            local NewX = math.clamp(StartSize.X + Delta.X, SidebarWidth + 320, Vp.X)
            local NewY = math.clamp(StartSize.Y + Delta.Y, 300, Vp.Y)

            -- Root may be anchored at its centre; shift it so the top-left corner stays put.
            local Anchor = Root.AnchorPoint
            Root.Size = UDim2.fromOffset(NewX, NewY)
            Root.Position = StartPosition
                + UDim2.fromOffset((NewX - StartSize.X) * Anchor.X, (NewY - StartSize.Y) * Anchor.Y)
        end)
    end

    Window.Root = Root
    Window.Main = Main
    Window.Scale = Scale
    Window.Container = Container
    Library.Window = Window

    function Window:SetTitle(Text)
        TitleLabel.Text = Text
    end
    Window.ChangeTitle = Window.SetTitle

    function Window:SetFooter(Text)
        FooterLabel.Text = Text
    end

    --// Tabs \\--
    function Window:AddTab(...)
        local Name, Icon, Description
        if select("#", ...) == 1 and typeof((...)) == "table" then
            local Data = ...
            Name, Icon, Description = Data.Name or "Tab", Data.Icon, Data.Description
        else
            Name, Icon, Description = ...
        end

        local Tab = {
            Name = Name,
            Description = Description,
            Groupboxes = {},
            Window = Window,
        }

        local TabButton = New("TextButton", {
            BackgroundColor3 = "MainColor",
            BackgroundTransparency = 1,
            LayoutOrder = #Window.Tabs,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = Sidebar,
        })
        Corner(TabButton, 8)
        local ButtonStroke = Stroke(TabButton, "OutlineColor", 1)

        local Indicator = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = "AccentColor",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            ZIndex = 3,
            Parent = TabButton,
        })
        Corner(Indicator, UDim.new(1, 0))

        local IndicatorGlow = New("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Image = Assets.Shadow,
            ImageColor3 = "AccentColor",
            ImageTransparency = 1,
            Position = UDim2.new(0, 1, 0.5, 0),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromOffset(30, 44),
            SliceCenter = Rect.new(23, 23, 277, 277),
            ZIndex = 2,
            Parent = TabButton,
        })

        local Content = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 3,
            Parent = TabButton,
        })
        Padding(Content, 10, 10, 14, 10)

        local TabIcon
        local IconData = Library:GetIcon(Icon)
        if IconData then
            TabIcon = New("ImageLabel", {
                ImageColor3 = "AccentColor",
                ImageTransparency = 0.5,
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                ZIndex = 3,
                Parent = Content,
            })
            ApplyIcon(TabIcon, IconData)
        end

        local TabLabel = New("TextLabel", {
            Position = UDim2.fromOffset(TabIcon and 28 or 0, 0),
            Size = UDim2.new(1, TabIcon and -28 or 0, 1, 0),
            Text = Name,
            TextSize = 14,
            TextTransparency = 0.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = Content,
        })

        --// Tab page: two scrolling columns, like Obsidian \\--
        local Page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = Container,
        })

        local function MakeSide(AnchorX)
            local Side = New("ScrollingFrame", {
                AnchorPoint = Vector2.new(AnchorX, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.fromScale(0, 0),
                Position = UDim2.fromScale(AnchorX, 0),
                ScrollBarImageColor3 = "AccentColor",
                ScrollBarImageTransparency = 0.4,
                ScrollBarThickness = 2,
                Size = UDim2.new(0.5, 0, 1, 0),
                Parent = Page,
            })
            List(Side, 10)
            Padding(Side, 10, 10, AnchorX == 0 and 10 or 5, AnchorX == 0 and 5 or 10)
            return Side
        end

        local Left = MakeSide(0)
        local Right = MakeSide(1)

        Tab.Button = TabButton
        Tab.Container = Page
        Tab.Sides = { Left, Right }

        function Tab:SetSelected(Selected)
            local Info = Library.TweenInfo
            Tween(TabButton, Info, { BackgroundTransparency = Selected and 0 or 1 })
            Tween(ButtonStroke, Info, { Transparency = Selected and 0 or 1 })
            Tween(TabLabel, Info, { TextTransparency = Selected and 0 or 0.5 })
            Tween(Indicator, Info, {
                BackgroundTransparency = Selected and 0 or 1,
                Size = UDim2.fromOffset(3, Selected and 18 or 0),
            })
            Tween(IndicatorGlow, Info, { ImageTransparency = Selected and 0.55 or 1 })
            if TabIcon then
                Tween(TabIcon, Info, { ImageTransparency = Selected and 0 or 0.5 })
            end
        end

        function Tab:Show()
            if Library.ActiveTab == Tab then
                return
            end
            CloseOpenedMenu()

            for _, Other in Window.Tabs do
                if Other ~= Tab then
                    Other.Container.Visible = false
                    Other:SetSelected(false)
                end
            end

            Library.ActiveTab = Tab
            Tab:SetSelected(true)

            TabInfoTitle.Text = Name
            TabInfoDescription.Text = Description or ""
            TabInfoDescription.Visible = Description ~= nil and Description ~= ""

            -- Syde-ish entrance: slide up into place.
            Page.Visible = true
            Page.Position = UDim2.fromOffset(0, 16)
            Tween(Page, Library.TweenInfo, { Position = UDim2.fromOffset(0, 0) })
        end

        TabButton.MouseEnter:Connect(function()
            if Library.ActiveTab ~= Tab then
                Tween(TabLabel, Library.FastTweenInfo, { TextTransparency = 0.25 })
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if Library.ActiveTab ~= Tab then
                Tween(TabLabel, Library.FastTweenInfo, { TextTransparency = 0.5 })
            end
        end)
        TabButton.MouseButton1Click:Connect(function()
            Tab:Show()
        end)

        --// Groupboxes \\--
        function Tab:AddGroupbox(Info)
            Info = Library:Validate(Info, Templates.Groupbox)

            local SideIndex = Info.Side
            if typeof(SideIndex) == "string" then
                SideIndex = SideIndex:lower() == "right" and 2 or 1
            end

            local Box = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = "MainColor",
                LayoutOrder = #Tab.Groupboxes,
                Size = UDim2.fromScale(1, 0),
                Parent = Tab.Sides[SideIndex] or Left,
            })
            Corner(Box, Library.CornerRadius)
            Stroke(Box)
            List(Box, 0)

            local Header = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 36),
                Parent = Box,
            })
            Padding(Header, 9, 9, 12, 12)

            local BoxIcon = Library:GetIcon(Info.IconName)
            if BoxIcon then
                local HeaderIcon = New("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    ImageColor3 = "AccentColor",
                    Position = UDim2.fromScale(0, 0.5),
                    Size = UDim2.fromOffset(18, 18),
                    Parent = Header,
                })
                ApplyIcon(HeaderIcon, BoxIcon)
            end

            local Texts = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(BoxIcon and 26 or 0, 0),
                Size = UDim2.new(1, BoxIcon and -26 or 0, 0, 0),
                Parent = Header,
            })
            List(Texts, 2)

            New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.Y,
                FontFace = function()
                    return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.SemiBold)
                end,
                Size = UDim2.new(1, 0, 0, 18),
                Text = Info.Name,
                TextSize = 14,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Texts,
            })

            if Info.Description then
                New("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = 1,
                    Size = UDim2.fromScale(1, 0),
                    Text = Info.Description,
                    TextSize = 12,
                    TextTransparency = 0.5,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Texts,
                })
            end

            Line({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 1), Parent = Box })

            local BoxContainer = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Size = UDim2.fromScale(1, 0),
                Parent = Box,
            })
            List(BoxContainer, 8)
            Padding(BoxContainer, 10, 12, 12, 12)

            local Groupbox = {
                Name = Info.Name,
                Holder = Box,
                Container = BoxContainer,
                Tab = Tab,
                Type = "Groupbox",
            }
            setmetatable(Groupbox, { __index = Funcs })

            table.insert(Tab.Groupboxes, Groupbox)
            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = "Left", Name = Name, IconName = IconName })
        end

        function Tab:AddRightGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = "Right", Name = Name, IconName = IconName })
        end

        table.insert(Window.Tabs, Tab)
        Library.Tabs[Name] = Tab

        if #Window.Tabs == 1 then
            Tab:Show()
        end

        return Tab
    end

    --// Mobile open/close button \\--
    if Library.IsMobile then
        local MobileButton = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromOffset(12, 12),
            Size = UDim2.fromOffset(76, 30),
            Text = "Toggle",
            Parent = ScreenGui,
        })
        Corner(MobileButton, 8)
        Stroke(MobileButton, "AccentColor")
        MobileButton.MouseButton1Click:Connect(function()
            Library:Toggle()
        end)
    end

    if WindowInfo.AutoShow then
        task.defer(Library.Toggle, Library, true)
    end

    return Window
end

pcall(function()
    getgenv().Library = Library
    getgenv().Toggles = Toggles
    getgenv().Options = Options
end)

return Library
