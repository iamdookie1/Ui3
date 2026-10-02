--[[
    Ui3
    Obsidian's layout and API, dressed in Syde's colors and style.

    Supported so far:
        Library:CreateWindow
        Window:AddTab
        Tab:AddGroupbox / AddLeftGroupbox / AddRightGroupbox
        Groupbox:AddToggle / AddButton / AddLabel / AddDivider / AddSlider / AddDropdown
        Toggle:AddColorPicker / Label:AddColorPicker
]]

local cloneref = (cloneref or clonereference or function(Object)
    return Object
end)

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))
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

    -- Strong keys on purpose: a weak table lets Roblox collect the Lua handle of an
    -- instance we no longer reference (e.g. icons), which silently drops it from theming.
    Registry = {},
    Updaters = {},
    Signals = {},
    UnloadCallbacks = {},
    Tabs = {},

    ActiveTab = nil,
    OpenedPopup = nil,

    Toggled = false,
    Unloaded = false,

    ToggleKeybind = Enum.KeyCode.RightControl,
    CornerRadius = 8,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,

    --// Syde palette, pushed darker \\--
    Scheme = {
        BackgroundColor = Color3.fromRGB(9, 9, 9),
        ContainerColor = Color3.fromRGB(11, 11, 11),
        MainColor = Color3.fromRGB(14, 14, 14),
        SecondaryColor = Color3.fromRGB(19, 19, 19),
        AccentColor = Color3.fromRGB(255, 151, 227),
        OutlineColor = Color3.fromRGB(28, 28, 28),
        FontColor = Color3.fromRGB(255, 255, 255),
        Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),

        RedColor = Color3.fromRGB(255, 101, 104),
        DarkColor = Color3.fromRGB(0, 0, 0),
        WhiteColor = Color3.fromRGB(255, 255, 255),
    },

    --// Syde-style easing: long, smooth, exponential \\--
    TweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
    FastTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    DragTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

local Assets = {
    Shadow = "rbxassetid://5554236805",
    SaturationMap = "rbxassetid://4155801252",
    Checkers = "rbxassetid://139785960036434",
}

--// Lucide icons (same module Obsidian uses; sprites are 24x24, so never draw them larger) \\--
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
        return { Url = "rbxassetid://" .. tostring(Icon), Custom = true }
    end

    if typeof(Icon) == "string" and Icon:match("^rbxasset") then
        return { Url = Icon, Custom = true }
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

local function Register(Object, Property, Value)
    if not Library.Registry[Object] then
        Library.Registry[Object] = {}
        Object.Destroying:Connect(function()
            Library.Registry[Object] = nil
        end)
    end
    Library.Registry[Object][Property] = Value
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
            Register(Object, Key, Value)
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
    Register(Object, Property, Value)

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

-- Crisp replacement for image glows: a soft top-to-bottom sheen on accent fills.
local function Sheen(Parent)
    return New("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
        Rotation = 90,
        Parent = Parent,
    })
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

local function IsArray(Table)
    local Count = 0
    for Key in Table do
        if typeof(Key) ~= "number" then
            return false
        end
        Count += 1
    end
    return Count == #Table
end

-- Mouse position in the same space as AbsolutePosition (our ScreenGui respects the inset).
local function GetMousePosition()
    return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
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

local function GetScreenSize()
    local Size = ScreenGui.AbsoluteSize
    if Size.X < 2 or Size.Y < 2 then
        Size = workspace.CurrentCamera.ViewportSize
    end
    return Size
end

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

--// Popups (color pickers, dropdowns): live in the ScreenGui so groupboxes never clip them \\--
local function CloseOpenedPopup()
    if Library.OpenedPopup then
        Library.OpenedPopup:Close()
    end
end

function Library:CreatePopup(Holder, Settings)
    Settings = Settings or {}

    local Popup = {
        Holder = Holder,
        IsOpen = false,
        OnOpen = nil,
        OnClose = nil,
    }

    local Shadow = New("ImageLabel", {
        Image = Assets.Shadow,
        ImageColor3 = "DarkColor",
        ImageTransparency = 0.3,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(23, 23, 277, 277),
        Visible = false,
        ZIndex = 49,
        Parent = ScreenGui,
    })

    local Frame = New("Frame", {
        AutomaticSize = Settings.AutoHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        BackgroundColor3 = "MainColor",
        ClipsDescendants = not Settings.AutoHeight,
        Size = UDim2.fromOffset(Settings.Width or 200, 0),
        Visible = false,
        ZIndex = 50,
        Parent = ScreenGui,
    })
    Corner(Frame, 8)
    Stroke(Frame)
    local Scale = New("UIScale", { Parent = Frame })

    Popup.Frame = Frame

    local Follow

    local function Reposition()
        if not Holder.Parent or not Library.Toggled then
            Popup:Close()
            return
        end

        local Screen = GetScreenSize()
        local Width = Settings.GetWidth and Settings.GetWidth() or Frame.Size.X.Offset
        if Width ~= Frame.Size.X.Offset then
            Frame.Size = UDim2.fromOffset(Width, Frame.Size.Y.Offset)
        end

        local Size = Frame.AbsoluteSize / math.max(Scale.Scale, 0.01)
        local HolderPos, HolderSize = Holder.AbsolutePosition, Holder.AbsoluteSize

        local X = Settings.Align == "Right" and (HolderPos.X + HolderSize.X - Size.X) or HolderPos.X
        local Y = HolderPos.Y + HolderSize.Y + 6
        X = math.clamp(X, 6, math.max(6, Screen.X - Size.X - 6))
        if Y + Size.Y > Screen.Y - 6 then
            Y = HolderPos.Y - Size.Y - 6
        end
        X, Y = math.floor(X + 0.5), math.floor(Y + 0.5)

        Frame.Position = UDim2.fromOffset(X, Y)
        Shadow.Position = UDim2.fromOffset(X - 22, Y - 22)
        Shadow.Size = UDim2.fromOffset(Size.X + 44, Size.Y + 44)
    end
    Popup.Reposition = Reposition

    function Popup:Open()
        if Popup.IsOpen then
            return
        end
        CloseOpenedPopup()
        Library.OpenedPopup = Popup
        Popup.IsOpen = true

        Frame.Visible = true
        Shadow.Visible = true
        Scale.Scale = 0.95
        Tween(Scale, Library.TweenInfo, { Scale = 1 })

        if Popup.OnOpen then
            Popup.OnOpen()
        end
        Reposition()
        if Popup.IsOpen then
            Follow = RunService.RenderStepped:Connect(Reposition)
        end
    end

    function Popup:Close()
        if not Popup.IsOpen then
            return
        end
        Popup.IsOpen = false

        if Follow then
            Follow:Disconnect()
            Follow = nil
        end
        Frame.Visible = false
        Shadow.Visible = false
        if Library.OpenedPopup == Popup then
            Library.OpenedPopup = nil
        end

        if Popup.OnClose then
            Popup.OnClose()
        end
    end

    function Popup:Toggle()
        if Popup.IsOpen then
            Popup:Close()
        else
            Popup:Open()
        end
    end

    return Popup
end

--// Tooltips \\--
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.XY,
    BackgroundColor3 = "MainColor",
    BackgroundTransparency = 0,
    Text = "",
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
    ZIndex = 100,
    Parent = ScreenGui,
})
Corner(TooltipLabel, 6)
Stroke(TooltipLabel)
Padding(TooltipLabel, 5, 5, 8, 8)
New("UISizeConstraint", { MaxSize = Vector2.new(260, math.huge), Parent = TooltipLabel })

local HoveredTooltip = nil

function Library:AddTooltip(Text, DisabledText, HoverInstance)
    local Tooltip = {
        Text = Text,
        DisabledText = DisabledText,
        Disabled = false,
    }

    local function Current()
        if Tooltip.Disabled then
            return Tooltip.DisabledText
        end
        return Tooltip.Text
    end

    HoverInstance.MouseEnter:Connect(function()
        local Str = Current()
        if typeof(Str) ~= "string" or Str == "" then
            return
        end
        HoveredTooltip = Tooltip
        TooltipLabel.Text = Str
        TooltipLabel.Visible = true
    end)

    HoverInstance.MouseLeave:Connect(function()
        if HoveredTooltip == Tooltip then
            HoveredTooltip = nil
            TooltipLabel.Visible = false
        end
    end)

    return Tooltip
end

Library:GiveSignal(RunService.RenderStepped:Connect(function()
    if not TooltipLabel.Visible then
        return
    end
    if not Library.Toggled then
        TooltipLabel.Visible = false
        HoveredTooltip = nil
        return
    end
    local Mouse = GetMousePosition()
    TooltipLabel.Position = UDim2.fromOffset(math.floor(Mouse.X + 14), math.floor(Mouse.Y + 14))
end))

--// Global input \\--
Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, Processed)
    if IsClick(Input) and Library.OpenedPopup then
        local Popup = Library.OpenedPopup
        local Position = Vector2.new(Input.Position.X, Input.Position.Y)
        if not IsInside(Popup.Frame, Position) and not IsInside(Popup.Holder, Position) then
            Popup:Close()
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
        Size = UDim2.fromOffset(720, 560),
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
    },
    Toggle = {
        Text = "Toggle",
        Default = false,
        Disabled = false,
        Visible = true,
        Risky = false,
        Callback = function() end,
    },
    ColorPicker = {
        Default = Color3.new(1, 1, 1),
        Callback = function() end,
    },
    Slider = {
        Text = "Slider",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Prefix = "",
        Suffix = "",
        Compact = false,
        HideMax = false,
        Disabled = false,
        Visible = true,
        Callback = function() end,
    },
    Dropdown = {
        Values = {},
        DisabledValues = {},
        Multi = false,
        AllowNull = false,
        Searchable = false,
        MaxVisibleDropdownItems = 8,
        Disabled = false,
        Visible = true,
        Callback = function() end,
    },
}

--// Elements shared by every container (groupboxes for now) \\--
local Funcs = {}

function Funcs:AddColorPicker(Idx, Info)
    Info = Library:Validate(Info, Templates.ColorPicker)

    local ParentObj = self
    local AddonHolder = ParentObj.TextLabel
    assert(AddonHolder, "AddColorPicker must be called on a toggle or a label")

    local ColorPicker = {
        Value = Info.Default,
        Transparency = Info.Transparency or 0,
        Title = Info.Title,
        Callback = Info.Callback,
        Changed = Info.Changed,
        Type = "ColorPicker",
    }
    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

    --// Swatch: checkers underneath, color on top \\--
    local Holder = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(18, 18),
        Parent = AddonHolder,
    })

    local Checkers = New("ImageLabel", {
        Image = Assets.Checkers,
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(1, 1),
        TileSize = UDim2.fromOffset(9, 9),
        Visible = Info.Transparency ~= nil,
        Parent = Holder,
    })
    Corner(Checkers, 5)

    local Swatch = New("Frame", {
        BackgroundColor3 = ColorPicker.Value,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
        Parent = Holder,
    })
    Corner(Swatch, 5)
    local SwatchStroke = New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = ColorPicker.Value:Lerp(Color3.new(0, 0, 0), 0.45),
        Parent = Swatch,
    })

    --// Popup \\--
    local MapSize = Library.IsMobile and 150 or 180
    local BarWidth = 12
    local MenuWidth = MapSize + (BarWidth + 8) * (Info.Transparency and 2 or 1) + 20

    local Popup = Library:CreatePopup(Holder, { Width = MenuWidth, Align = "Right", AutoHeight = true })
    local Menu = Popup.Frame
    Padding(Menu, 10)
    List(Menu, 8)

    if typeof(ColorPicker.Title) == "string" then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            Text = ColorPicker.Title,
            TextSize = 13,
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
        Size = UDim2.new(1, 0, 0, 26),
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

        Swatch.BackgroundColor3 = ColorPicker.Value
        Swatch.BackgroundTransparency = ColorPicker.Transparency
        SwatchStroke.Color = ColorPicker.Value:Lerp(Color3.new(0, 0, 0), 0.45)

        SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
        SatVibCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
        HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue)

        if AlphaColor then
            AlphaColor.BackgroundColor3 = ColorPicker.Value
            AlphaCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency)
        end

        if not HexBox:IsFocused() then
            HexBox.Text = "#" .. ColorPicker.Value:ToHex():upper()
        end
        if not RgbBox:IsFocused() then
            RgbBox.Text = string.format(
                "%d, %d, %d",
                math.floor(ColorPicker.Value.R * 255 + 0.5),
                math.floor(ColorPicker.Value.G * 255 + 0.5),
                math.floor(ColorPicker.Value.B * 255 + 0.5)
            )
        end
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
            ColorPicker:SetValueRGB(HSV, Transparency)
            return
        end
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = HSV[1], HSV[2], HSV[3]
        ColorPicker.Transparency = Transparency or ColorPicker.Transparency
        ColorPicker:Update()
    end

    local function SetSatVib(Position)
        local Pos, Size = SatVibMap.AbsolutePosition, SatVibMap.AbsoluteSize
        ColorPicker.Sat = math.clamp((Position.X - Pos.X) / Size.X, 0, 1)
        ColorPicker.Vib = 1 - math.clamp((Position.Y - Pos.Y) / Size.Y, 0, 1)
        ColorPicker:Update()
    end
    TrackDrag(SatVibMap, SetSatVib, SetSatVib)

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

    HexBox.FocusLost:Connect(function()
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

    ColorPicker.Popup = Popup

    Holder.MouseButton1Click:Connect(function()
        Popup:Toggle()
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
        Data.Visible = Params.Visible ~= false
        Data.Idx = typeof(Second) == "table" and First or nil
    else
        Data.Text = First or ""
        Data.DoesWrap = Second or false
        Data.Visible = true
    end

    local Groupbox = self
    local Label = {
        Text = Data.Text,
        Visible = Data.Visible,
        Addons = {},
        Type = "Label",
    }

    local TextLabel = New("TextLabel", {
        AutomaticSize = Data.DoesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Size = UDim2.new(1, 0, 0, 18),
        Text = Label.Text,
        TextTransparency = 0.35,
        TextWrapped = Data.DoesWrap,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Data.DoesWrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        Visible = Label.Visible,
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
        Label.Visible = Visible
        TextLabel.Visible = Visible
    end

    setmetatable(Label, { __index = Funcs })

    if Data.Idx then
        Options[Data.Idx] = Label
    end

    return Label
end

function Funcs:AddDivider(Text)
    if typeof(Text) == "table" then
        Text = Text.Text
    end

    local Holder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Text and 14 or 6),
        Parent = self.Container,
    })

    if Text then
        List(Holder, 8, {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        })
        New("Frame", { BackgroundColor3 = "OutlineColor", Size = UDim2.new(1, 0, 0, 1), Parent = Holder })
        local Label = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 1,
            Size = UDim2.fromOffset(0, 14),
            Text = Text,
            TextSize = 12,
            TextTransparency = 0.5,
            Parent = Holder,
        })
        New("UIFlexItem", { FlexMode = Enum.UIFlexMode.None, Parent = Label })
        New("Frame", { BackgroundColor3 = "OutlineColor", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 1), Parent = Holder })
    else
        New("Frame", {
            BackgroundColor3 = "OutlineColor",
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.new(1, 0, 0, 1),
            Parent = Holder,
        })
    end

    return Holder
end

function Funcs:AddToggle(Idx, Info)
    Info = Library:Validate(Info, Templates.Toggle)

    local Groupbox = self

    local Toggle = {
        Text = Info.Text,
        Value = Info.Default,
        Callback = Info.Callback,
        Changed = Info.Changed,

        Risky = Info.Risky,
        Disabled = Info.Disabled,
        Visible = Info.Visible,

        Addons = {},
        Type = "Toggle",
    }

    local Button = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Visible = Toggle.Visible,
        Parent = Groupbox.Container,
    })

    local Label = New("TextLabel", {
        Size = UDim2.new(1, -44, 1, 0),
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

    -- Obsidian switch with a Syde accent fill.
    local Switch = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = "SecondaryColor",
        Position = UDim2.new(1, 0, 0, 1),
        Size = UDim2.fromOffset(34, 18),
        Parent = Button,
    })
    Corner(Switch, UDim.new(1, 0))
    Padding(Switch, 3)
    local SwitchStroke = Stroke(Switch)
    Sheen(Switch)

    local Ball = New("Frame", {
        BackgroundColor3 = "FontColor",
        BackgroundTransparency = 0.5,
        Size = UDim2.fromOffset(12, 12),
        Parent = Switch,
    })
    Corner(Ball, UDim.new(1, 0))

    Toggle.TextLabel = Label
    Toggle.Container = Groupbox.Container

    if Info.Tooltip or Info.DisabledTooltip then
        Toggle.TooltipTable = Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Button)
    end

    function Toggle:Display(Instant)
        local TweenData = if Instant then false else Library.TweenInfo
        local On = Toggle.Value
        local Offset = On and 1 or 0

        SetThemed(Switch, "BackgroundColor3", On and "AccentColor" or "SecondaryColor", TweenData)
        SetThemed(SwitchStroke, "Color", On and "AccentColor" or "OutlineColor", TweenData)

        local BallGoal = {
            AnchorPoint = Vector2.new(Offset, 0),
            Position = UDim2.fromScale(Offset, 0),
            BackgroundTransparency = On and 0 or 0.5,
        }
        local LabelGoal = { TextTransparency = Toggle.Disabled and 0.8 or (On and 0 or 0.4) }

        if Instant then
            for Key, Value in BallGoal do
                Ball[Key] = Value
            end
            Label.TextTransparency = LabelGoal.TextTransparency
        else
            Tween(Ball, Library.TweenInfo, BallGoal)
            Tween(Label, Library.FastTweenInfo, LabelGoal)
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
        if Toggle.TooltipTable then
            Toggle.TooltipTable.Disabled = Disabled
        end
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

    Button.Active = not Toggle.Disabled
    if Toggle.TooltipTable then
        Toggle.TooltipTable.Disabled = Toggle.Disabled
    end
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
            Data.Tooltip = Params.Tooltip
            Data.DisabledTooltip = Params.DisabledTooltip
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
            Armed = false,
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
            TextTransparency = 0.4,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
            Parent = Base,
        })

        Button.Base = Base
        Button.Label = Label

        if Data.Tooltip or Data.DisabledTooltip then
            Button.TooltipTable = Library:AddTooltip(Data.Tooltip, Data.DisabledTooltip, Base)
        end

        local function ResetText()
            Button.Armed = false
            Label.Text = Button.Text
            SetThemed(Label, "TextColor3", Button.Risky and "RedColor" or "FontColor", false)
        end

        function Button:SetText(Text)
            Button.Text = Text
            if not Button.Armed then
                Label.Text = Text
            end
        end

        function Button:SetDisabled(Disabled)
            Button.Disabled = Disabled
            Base.Active = not Disabled
            Label.TextTransparency = Disabled and 0.8 or 0.4
            BaseStroke.Transparency = Disabled and 0.5 or 0
            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Disabled
            end
            if Disabled and Button.Armed then
                ResetText()
            end
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
                return Library.Scheme.SecondaryColor:Lerp(Library.Scheme.FontColor, 0.04)
            end, Library.FastTweenInfo)
        end)
        Base.MouseLeave:Connect(function()
            if Button.Disabled then
                return
            end
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
            SetThemed(Base, "BackgroundColor3", "SecondaryColor", Library.FastTweenInfo)
        end)

        -- Syde-style press: accent ripple + stroke flash. Not themed: it only lives for 0.6s.
        local function Ripple(Position)
            local Circle = Instance.new("Frame")
            Circle.AnchorPoint = Vector2.new(0.5, 0.5)
            Circle.BackgroundColor3 = Library.Scheme.AccentColor
            Circle.BackgroundTransparency = 0.8
            Circle.BorderSizePixel = 0
            Circle.Position =
                UDim2.fromOffset(Position.X - Base.AbsolutePosition.X, Position.Y - Base.AbsolutePosition.Y)
            Circle.Size = UDim2.fromOffset(0, 0)
            Circle.ZIndex = 1
            Corner(Circle, UDim.new(1, 0))
            Circle.Parent = Base

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

        local ArmId = 0
        Base.MouseButton1Click:Connect(function()
            if Button.Disabled then
                return
            end

            if Button.DoubleClick then
                if Button.Armed then
                    ResetText()
                    Flash()
                    Library:SafeCallback(Button.Func)
                    return
                end

                Button.Armed = true
                ArmId += 1
                local MyId = ArmId
                Label.Text = "Are you sure?"
                SetThemed(Label, "TextColor3", "AccentColor", false)

                task.delay(1.5, function()
                    if Button.Armed and ArmId == MyId then
                        ResetText()
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
        Size = UDim2.new(1, 0, 0, 28),
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

function Funcs:AddSlider(Idx, Info)
    Info = Library:Validate(Info, Templates.Slider)
    assert(Info.Max > Info.Min, "Slider Max must be greater than Min")

    local Groupbox = self

    local Slider = {
        Text = Info.Text,
        Value = Info.Default,
        Min = Info.Min,
        Max = Info.Max,
        Rounding = Info.Rounding,
        Prefix = Info.Prefix,
        Suffix = Info.Suffix,
        Compact = Info.Compact,
        HideMax = Info.HideMax,

        Callback = Info.Callback,
        Changed = Info.Changed,

        Disabled = Info.Disabled,
        Visible = Info.Visible,
        Type = "Slider",
    }

    local Holder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        Visible = Slider.Visible,
        Parent = Groupbox.Container,
    })

    local Label = New("TextLabel", {
        Size = UDim2.new(1, -90, 0, 16),
        Text = Slider.Text,
        TextTransparency = 0.4,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })

    -- Click the value to type an exact number.
    local ValueBox = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(90, 16),
        Text = "",
        TextSize = 12,
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Holder,
    })

    local Bar = New("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 16),
        Parent = Holder,
    })

    local Track = New("Frame", {
        BackgroundColor3 = "SecondaryColor",
        Position = UDim2.fromOffset(0, 5),
        Size = UDim2.new(1, 0, 0, 6),
        Parent = Bar,
    })
    Corner(Track, UDim.new(1, 0))
    local TrackStroke = Stroke(Track)

    local Fill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(0, 1),
        Parent = Track,
    })
    Corner(Fill, UDim.new(1, 0))
    Sheen(Fill)

    local Knob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(12, 12),
        ZIndex = 2,
        Parent = Track,
    })
    Corner(Knob, UDim.new(1, 0))
    local KnobStroke = New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = "AccentColor",
        Thickness = 2,
        Parent = Knob,
    })

    Slider.TextLabel = Label

    if Info.Tooltip or Info.DisabledTooltip then
        Slider.TooltipTable = Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Holder)
    end

    local function Round(Value)
        local Mult = 10 ^ Slider.Rounding
        return math.floor(Value * Mult + 0.5) / Mult
    end

    local function FormatNumber(Value)
        return string.format("%." .. math.max(0, Slider.Rounding) .. "f", Value)
    end

    local function GetDisplayText()
        if Info.FormatDisplayValue then
            local Custom = Info.FormatDisplayValue(Slider, Slider.Value)
            if Custom ~= nil then
                return tostring(Custom)
            end
        end

        local Value = Slider.Prefix .. FormatNumber(Slider.Value) .. Slider.Suffix
        if Slider.HideMax or Slider.Compact then
            return Value
        end
        return Value .. " / " .. Slider.Prefix .. FormatNumber(Slider.Max) .. Slider.Suffix
    end

    local Dragging = false

    function Slider:Display(Instant)
        local Text = GetDisplayText()
        if Slider.Compact then
            Label.Text = Slider.Text .. ": " .. Text
            ValueBox.Visible = false
            Label.Size = UDim2.new(1, 0, 0, 16)
        else
            Label.Text = Slider.Text
            ValueBox.Visible = true
            Label.Size = UDim2.new(1, -90, 0, 16)
            if not ValueBox:IsFocused() then
                ValueBox.Text = Text
            end
        end

        local Alpha = (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
        local TweenData = if Instant then nil elseif Dragging then Library.DragTweenInfo else Library.TweenInfo
        if TweenData then
            Tween(Fill, TweenData, { Size = UDim2.fromScale(Alpha, 1) })
            Tween(Knob, TweenData, { Position = UDim2.fromScale(Alpha, 0.5) })
        else
            Fill.Size = UDim2.fromScale(Alpha, 1)
            Knob.Position = UDim2.fromScale(Alpha, 0.5)
        end
    end

    function Slider:OnChanged(Func)
        Slider.Changed = Func
    end

    function Slider:RunChanged()
        Library:SafeCallback(Slider.Callback, Slider.Value)
        Library:SafeCallback(Slider.Changed, Slider.Value)
    end

    function Slider:SetValue(Value)
        local Num = tonumber(Value)
        if not Num then
            Slider:Display(true)
            return
        end

        Num = math.clamp(Round(Num), Slider.Min, Slider.Max)
        if Num == Slider.Value then
            Slider:Display(true)
            return
        end

        Slider.Value = Num
        Slider:Display()
        Slider:RunChanged()
    end

    function Slider:SetMin(Value)
        assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")
        Slider.Min = Value
        if Slider.Value < Value then
            Slider:SetValue(Value)
        else
            Slider:Display()
        end
    end

    function Slider:SetMax(Value)
        assert(Value > Slider.Min, "Max value cannot be less than the current min value.")
        Slider.Max = Value
        if Slider.Value > Value then
            Slider:SetValue(Value)
        else
            Slider:Display()
        end
    end

    function Slider:SetText(Text)
        Slider.Text = Text
        Slider:Display(true)
    end

    function Slider:SetPrefix(Prefix)
        Slider.Prefix = Prefix
        Slider:Display(true)
    end

    function Slider:SetSuffix(Suffix)
        Slider.Suffix = Suffix
        Slider:Display(true)
    end

    function Slider:SetDisabled(Disabled)
        Slider.Disabled = Disabled
        Bar.Active = not Disabled
        ValueBox.TextEditable = not Disabled
        Label.TextTransparency = Disabled and 0.8 or 0.4
        ValueBox.TextTransparency = Disabled and 0.8 or 0.4
        Fill.BackgroundTransparency = Disabled and 0.6 or 0
        Knob.BackgroundTransparency = Disabled and 0.6 or 0
        KnobStroke.Transparency = Disabled and 0.6 or 0
        TrackStroke.Transparency = Disabled and 0.5 or 0
        if Slider.TooltipTable then
            Slider.TooltipTable.Disabled = Disabled
        end
    end

    function Slider:SetVisible(Visible)
        Slider.Visible = Visible
        Holder.Visible = Visible
    end

    local function SetFromPosition(Position)
        if Slider.Disabled then
            return
        end
        local Alpha = math.clamp((Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * Alpha)
    end

    TrackDrag(Bar, function(Position)
        if Slider.Disabled then
            return
        end
        Dragging = true
        Tween(Knob, Library.FastTweenInfo, { Size = UDim2.fromOffset(14, 14) })
        SetFromPosition(Position)
    end, SetFromPosition, function()
        Dragging = false
        Tween(Knob, Library.FastTweenInfo, { Size = UDim2.fromOffset(12, 12) })
    end)

    Holder.MouseEnter:Connect(function()
        if not Slider.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.1 })
            Tween(ValueBox, Library.FastTweenInfo, { TextTransparency = 0.1 })
        end
    end)
    Holder.MouseLeave:Connect(function()
        if not Slider.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
            Tween(ValueBox, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    ValueBox.Focused:Connect(function()
        ValueBox.Text = FormatNumber(Slider.Value)
    end)
    ValueBox.FocusLost:Connect(function()
        local Num = tonumber((ValueBox.Text:gsub("[^%d%.%-]", "")))
        if Num and not Slider.Disabled then
            Slider:SetValue(Num)
        end
        Slider:Display(true)
    end)

    Slider.Value = math.clamp(Round(tonumber(Slider.Value) or Slider.Min), Slider.Min, Slider.Max)
    Slider:SetDisabled(Slider.Disabled)
    Slider:Display(true)

    setmetatable(Slider, { __index = Funcs })

    Options[Idx] = Slider
    return Slider
end

local function GetPlayerNames(ExcludeLocalPlayer)
    local Names = {}
    for _, Player in Players:GetPlayers() do
        if not (ExcludeLocalPlayer and Player == LocalPlayer) then
            table.insert(Names, Player.Name)
        end
    end
    table.sort(Names, function(A, B)
        return A:lower() < B:lower()
    end)
    return Names
end

local function GetTeamNames()
    local Names = {}
    local Teams = game:FindFirstChildOfClass("Teams")
    if Teams then
        for _, Team in Teams:GetTeams() do
            table.insert(Names, Team.Name)
        end
    end
    table.sort(Names)
    return Names
end

function Funcs:AddDropdown(Idx, Info)
    Info = Library:Validate(Info, Templates.Dropdown)

    if Info.SpecialType == "Player" then
        Info.Values = GetPlayerNames(Info.ExcludeLocalPlayer)
        Info.AllowNull = true
    elseif Info.SpecialType == "Team" then
        Info.Values = GetTeamNames()
        Info.AllowNull = true
    end

    local Groupbox = self
    local RowHeight = 26
    local RowGap = 2

    local Dropdown = {
        Text = Info.Text,
        Values = Info.Values,
        DisabledValues = Info.DisabledValues,
        Value = Info.Multi and {} or nil,
        Multi = Info.Multi,
        AllowNull = Info.AllowNull,
        SpecialType = Info.SpecialType,

        Callback = Info.Callback,
        Changed = Info.Changed,

        Disabled = Info.Disabled,
        Visible = Info.Visible,
        Type = "Dropdown",
    }

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Visible = Dropdown.Visible,
        Parent = Groupbox.Container,
    })
    List(Holder, 5)

    local Label = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        Text = Dropdown.Text or "",
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = Dropdown.Text ~= nil,
        Parent = Holder,
    })

    local Box = New("TextButton", {
        BackgroundColor3 = "SecondaryColor",
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 30),
        Parent = Holder,
    })
    Corner(Box, 6)
    local BoxStroke = Stroke(Box)

    local DisplayLabel = New("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Text = "",
        TextTransparency = 0.2,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Box,
    })

    local Arrow
    local ChevronIcon = Library:GetIcon("chevron-down")
    if ChevronIcon then
        Arrow = New("ImageLabel", {
            AnchorPoint = Vector2.new(1, 0),
            ImageColor3 = "FontColor",
            ImageTransparency = 0.4,
            Position = UDim2.new(1, -8, 0, 7),
            Size = UDim2.fromOffset(16, 16),
            Parent = Box,
        })
        ApplyIcon(Arrow, ChevronIcon)
    else
        Arrow = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 7),
            Size = UDim2.fromOffset(16, 16),
            Text = "v",
            TextTransparency = 0.4,
            Parent = Box,
        })
    end
    local ArrowIsImage = ChevronIcon ~= nil

    Dropdown.TextLabel = Label

    if Info.Tooltip or Info.DisabledTooltip then
        Dropdown.TooltipTable = Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Box)
    end

    --// Popup list \\--
    local Popup = Library:CreatePopup(Box, {
        Align = "Left",
        GetWidth = function()
            return math.floor(Box.AbsoluteSize.X + 0.5)
        end,
    })
    local Menu = Popup.Frame
    Padding(Menu, 4)
    List(Menu, 4)
    Dropdown.Popup = Popup

    local SearchBox
    if Info.Searchable then
        SearchBox = New("TextBox", {
            BackgroundColor3 = "SecondaryColor",
            PlaceholderText = "Search...",
            Size = UDim2.new(1, 0, 0, RowHeight),
            Text = "",
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 51,
            Parent = Menu,
        })
        Corner(SearchBox, 5)
        Padding(SearchBox, 0, 0, 8, 8)
        local SearchStroke = Stroke(SearchBox)
        SearchBox.Focused:Connect(function()
            SetThemed(SearchStroke, "Color", "AccentColor")
        end)
        SearchBox.FocusLost:Connect(function()
            SetThemed(SearchStroke, "Color", "OutlineColor")
        end)
    end

    local ListFrame = New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        LayoutOrder = 1,
        ScrollBarImageColor3 = "AccentColor",
        ScrollBarImageTransparency = 0.3,
        ScrollBarThickness = 2,
        Size = UDim2.new(1, 0, 0, RowHeight),
        ZIndex = 51,
        Parent = Menu,
    })
    List(ListFrame, RowGap)

    local EmptyLabel = New("TextLabel", {
        LayoutOrder = 999999,
        Size = UDim2.new(1, 0, 0, RowHeight),
        Text = "No values",
        TextSize = 12,
        TextTransparency = 0.6,
        Visible = false,
        ZIndex = 52,
        Parent = ListFrame,
    })

    local Rows = {}

    local function IsDictionary()
        return not IsArray(Dropdown.Values)
    end

    local function ValueExists(Value)
        if Value == nil then
            return false
        end
        if IsDictionary() then
            return Dropdown.Values[Value] ~= nil
        end
        return table.find(Dropdown.Values, Value) ~= nil
    end

    local function GetLabel(Value)
        local Raw = if IsDictionary() then Dropdown.Values[Value] else Value
        if Info.FormatDisplayValue then
            local Formatted = Info.FormatDisplayValue(Raw)
            if Formatted ~= nil then
                return tostring(Formatted)
            end
        end
        return tostring(Raw)
    end

    local function IsValueDisabled(Value)
        if table.find(Dropdown.DisabledValues, Value) then
            return true
        end
        if IsDictionary() and table.find(Dropdown.DisabledValues, Dropdown.Values[Value]) then
            return true
        end
        return false
    end

    local function IsSelected(Value)
        if Dropdown.Multi then
            return Dropdown.Value[Value] == true
        end
        return Dropdown.Value == Value
    end

    -- Values in display order (dictionaries are sorted by label so the order is stable).
    local function OrderedValues()
        local Ordered = {}
        if IsDictionary() then
            for Key in Dropdown.Values do
                table.insert(Ordered, Key)
            end
            table.sort(Ordered, function(A, B)
                return GetLabel(A):lower() < GetLabel(B):lower()
            end)
        else
            for _, Value in Dropdown.Values do
                table.insert(Ordered, Value)
            end
        end
        return Ordered
    end

    local function Resize()
        local VisibleCount = 0
        for _, Row in Rows do
            if Row.Button.Visible then
                VisibleCount += 1
            end
        end
        EmptyLabel.Visible = VisibleCount == 0

        local Shown = math.clamp(VisibleCount, 1, Info.MaxVisibleDropdownItems)
        local ListHeight = Shown * RowHeight + (Shown - 1) * RowGap
        ListFrame.Size = UDim2.new(1, 0, 0, ListHeight)

        local Height = ListHeight + 8 + (SearchBox and RowHeight + 4 or 0)
        Menu.Size = UDim2.new(0, Menu.Size.X.Offset, 0, Height)
    end

    local function ApplySearch()
        local Query = SearchBox and SearchBox.Text:lower() or ""
        for _, Row in Rows do
            Row.Button.Visible = Query == "" or Row.Label:lower():find(Query, 1, true) ~= nil
        end
        Resize()
    end

    function Dropdown:Display()
        local Parts = {}
        for _, Value in OrderedValues() do
            if IsSelected(Value) then
                table.insert(Parts, GetLabel(Value))
            end
        end

        local Text = table.concat(Parts, ", ")
        DisplayLabel.Text = Text == "" and "None" or Text
        DisplayLabel.TextTransparency = Dropdown.Disabled and 0.8 or (Text == "" and 0.6 or 0.2)
    end

    local function UpdateRows()
        for _, Row in Rows do
            Row.Update()
        end
    end

    function Dropdown:RunChanged()
        Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
        Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
    end

    local function BuildRows()
        for _, Row in Rows do
            Row.Button:Destroy()
        end
        table.clear(Rows)

        for Order, Value in OrderedValues() do
            local Row = {
                Value = Value,
                Label = GetLabel(Value),
            }

            local Button = New("TextButton", {
                BackgroundColor3 = "SecondaryColor",
                BackgroundTransparency = 1,
                LayoutOrder = Order,
                Size = UDim2.new(1, 0, 0, RowHeight),
                ZIndex = 52,
                Parent = ListFrame,
            })
            Corner(Button, 5)

            local Bar = New("Frame", {
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 7),
                Size = UDim2.fromOffset(2, 12),
                ZIndex = 53,
                Parent = Button,
            })
            Corner(Bar, UDim.new(1, 0))

            local Text = New("TextLabel", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, Dropdown.Multi and -36 or -16, 1, 0),
                Text = Row.Label,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 53,
                Parent = Button,
            })

            local Check, CheckStroke
            if Dropdown.Multi then
                Check = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundColor3 = "SecondaryColor",
                    Position = UDim2.new(1, -8, 0, 6),
                    Size = UDim2.fromOffset(14, 14),
                    ZIndex = 53,
                    Parent = Button,
                })
                Corner(Check, 4)
                CheckStroke = Stroke(Check)
                Sheen(Check)
            end

            Row.Button = Button

            function Row.Update()
                local Selected = IsSelected(Value)
                local ValueDisabled = IsValueDisabled(Value)

                SetThemed(Text, "TextColor3", Selected and "AccentColor" or "FontColor", Library.FastTweenInfo)
                Tween(Text, Library.FastTweenInfo, {
                    TextTransparency = ValueDisabled and 0.75 or (Selected and 0 or 0.35),
                })
                Tween(Bar, Library.FastTweenInfo, { BackgroundTransparency = Selected and 0 or 1 })

                if Check then
                    SetThemed(Check, "BackgroundColor3", Selected and "AccentColor" or "SecondaryColor", Library.FastTweenInfo)
                    SetThemed(CheckStroke, "Color", Selected and "AccentColor" or "OutlineColor", Library.FastTweenInfo)
                end
            end

            Button.MouseEnter:Connect(function()
                if not IsValueDisabled(Value) then
                    Tween(Button, Library.FastTweenInfo, { BackgroundTransparency = 0 })
                end
            end)
            Button.MouseLeave:Connect(function()
                Tween(Button, Library.FastTweenInfo, { BackgroundTransparency = 1 })
            end)

            Button.MouseButton1Click:Connect(function()
                if Dropdown.Disabled or IsValueDisabled(Value) then
                    return
                end

                if Dropdown.Multi then
                    Dropdown.Value[Value] = (not Dropdown.Value[Value]) or nil
                else
                    if Dropdown.Value == Value then
                        if not Dropdown.AllowNull then
                            Popup:Close()
                            return
                        end
                        Dropdown.Value = nil
                    else
                        Dropdown.Value = Value
                    end
                end

                Dropdown:Display()
                UpdateRows()
                Dropdown:RunChanged()

                if not Dropdown.Multi then
                    Popup:Close()
                end
            end)

            Row.Update()
            table.insert(Rows, Row)
        end

        ApplySearch()
    end

    function Dropdown:GetActiveValues(ReturnCount)
        local Active = {}
        if Dropdown.Multi then
            for Value in Dropdown.Value do
                table.insert(Active, Value)
            end
        elseif Dropdown.Value ~= nil then
            table.insert(Active, Dropdown.Value)
        end
        return ReturnCount == true and #Active or Active
    end

    function Dropdown:OnChanged(Func)
        Dropdown.Changed = Func
    end

    function Dropdown:SetValue(Value)
        if Dropdown.Multi then
            local Set = {}
            if typeof(Value) == "string" or typeof(Value) == "number" then
                if ValueExists(Value) then
                    Set[Value] = true
                end
            elseif typeof(Value) == "table" then
                for Key, Active in Value do
                    if typeof(Active) == "boolean" then
                        if Active and ValueExists(Key) then
                            Set[Key] = true
                        end
                    elseif ValueExists(Active) then
                        Set[Active] = true
                    end
                end
            end
            Dropdown.Value = Set
        else
            if ValueExists(Value) then
                Dropdown.Value = Value
            elseif Value == nil then
                Dropdown.Value = nil
            end
        end

        Dropdown:Display()
        UpdateRows()
        Dropdown:RunChanged()
    end

    local function PruneSelection()
        local Changed = false
        if Dropdown.Multi then
            for Value in Dropdown.Value do
                if not ValueExists(Value) then
                    Dropdown.Value[Value] = nil
                    Changed = true
                end
            end
        elseif Dropdown.Value ~= nil and not ValueExists(Dropdown.Value) then
            Dropdown.Value = nil
            Changed = true
        end
        return Changed
    end

    function Dropdown:SetValues(Values)
        Dropdown.Values = Values or {}
        local Changed = PruneSelection()
        BuildRows()
        Dropdown:Display()
        if Changed then
            Dropdown:RunChanged()
        end
    end

    function Dropdown:AddValues(Values)
        if typeof(Values) == "string" then
            Values = { Values }
        end
        if typeof(Values) ~= "table" then
            return
        end

        if IsDictionary() and not IsArray(Values) then
            for Key, Value in Values do
                Dropdown.Values[Key] = Value
            end
        else
            for _, Value in Values do
                if not table.find(Dropdown.Values, Value) then
                    table.insert(Dropdown.Values, Value)
                end
            end
        end

        BuildRows()
        Dropdown:Display()
    end

    function Dropdown:SetDisabledValues(DisabledValues)
        Dropdown.DisabledValues = DisabledValues or {}
        UpdateRows()
    end

    function Dropdown:AddDisabledValues(DisabledValues)
        for _, Value in DisabledValues do
            table.insert(Dropdown.DisabledValues, Value)
        end
        UpdateRows()
    end

    function Dropdown:SetText(Text)
        Dropdown.Text = Text
        Label.Text = Text or ""
        Label.Visible = Text ~= nil
    end

    function Dropdown:SetDisabled(Disabled)
        Dropdown.Disabled = Disabled
        Box.Active = not Disabled
        Label.TextTransparency = Disabled and 0.8 or 0.4
        BoxStroke.Transparency = Disabled and 0.5 or 0
        if ArrowIsImage then
            Arrow.ImageTransparency = Disabled and 0.8 or 0.4
        else
            Arrow.TextTransparency = Disabled and 0.8 or 0.4
        end
        if Dropdown.TooltipTable then
            Dropdown.TooltipTable.Disabled = Disabled
        end
        if Disabled then
            Popup:Close()
        end
        Dropdown:Display()
    end

    function Dropdown:SetVisible(Visible)
        Dropdown.Visible = Visible
        Holder.Visible = Visible
        if not Visible then
            Popup:Close()
        end
    end

    Popup.OnOpen = function()
        SetThemed(BoxStroke, "Color", "AccentColor", Library.FastTweenInfo)
        Tween(Arrow, Library.TweenInfo, { Rotation = 180 })
        Resize()
    end
    Popup.OnClose = function()
        SetThemed(BoxStroke, "Color", "OutlineColor", Library.FastTweenInfo)
        Tween(Arrow, Library.TweenInfo, { Rotation = 0 })
        if SearchBox and SearchBox.Text ~= "" then
            SearchBox.Text = ""
        end
    end

    if SearchBox then
        SearchBox:GetPropertyChangedSignal("Text"):Connect(ApplySearch)
    end

    Box.MouseEnter:Connect(function()
        if not Dropdown.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.1 })
        end
    end)
    Box.MouseLeave:Connect(function()
        if not Dropdown.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    Box.MouseButton1Click:Connect(function()
        if Dropdown.Disabled then
            return
        end
        Popup:Toggle()
    end)

    --// Default value \\--
    local function ResolveDefault(Default)
        if typeof(Default) == "number" and not IsDictionary() and Dropdown.Values[Default] ~= nil then
            return Dropdown.Values[Default]
        end
        return Default
    end

    if Info.Default ~= nil then
        if Dropdown.Multi then
            local DefaultList = typeof(Info.Default) == "table" and Info.Default or { Info.Default }
            for Key, Value in DefaultList do
                if typeof(Value) == "boolean" then
                    if Value and ValueExists(Key) then
                        Dropdown.Value[Key] = true
                    end
                else
                    local Resolved = ResolveDefault(Value)
                    if ValueExists(Resolved) then
                        Dropdown.Value[Resolved] = true
                    end
                end
            end
        else
            local Resolved = ResolveDefault(Info.Default)
            if ValueExists(Resolved) then
                Dropdown.Value = Resolved
            end
        end
    end

    BuildRows()
    Dropdown:SetDisabled(Dropdown.Disabled)

    --// Live player / team lists \\--
    if Dropdown.SpecialType == "Player" then
        local function Refresh()
            Dropdown:SetValues(GetPlayerNames(Info.ExcludeLocalPlayer))
        end
        Library:GiveSignal(Players.PlayerAdded:Connect(Refresh))
        Library:GiveSignal(Players.PlayerRemoving:Connect(function()
            task.defer(Refresh)
        end))
    elseif Dropdown.SpecialType == "Team" then
        local Teams = game:FindFirstChildOfClass("Teams")
        if Teams then
            local function Refresh()
                task.defer(function()
                    Dropdown:SetValues(GetTeamNames())
                end)
            end
            Library:GiveSignal(Teams.ChildAdded:Connect(Refresh))
            Library:GiveSignal(Teams.ChildRemoved:Connect(Refresh))
        end
    end

    setmetatable(Dropdown, { __index = Funcs })

    Options[Idx] = Dropdown
    return Dropdown
end

--// Window \\--
function Library:Toggle(Value)
    local Window = Library.Window
    if not Window or Library.Unloaded then
        return
    end

    if Value == nil then
        Value = not Library.Toggled
    end
    Library.Toggled = Value

    if Value then
        Window.Root.Visible = true
        Window.Scale.Scale = 0.96
        Tween(Window.Scale, Library.TweenInfo, { Scale = 1 })
    else
        CloseOpenedPopup()
        TooltipLabel.Visible = false
        local T = Tween(Window.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.96 })
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
    CloseOpenedPopup()
    Library.Unloaded = true
    Library.Toggled = false

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
    table.clear(Library.Registry)
    table.clear(Library.Updaters)
    ScreenGui:Destroy()
end

local function Even(Number)
    Number = math.floor(Number + 0.5)
    return Number - Number % 2
end

function Library:CreateWindow(WindowInfo)
    WindowInfo = Library:Validate(WindowInfo, Templates.Window)

    Library.CornerRadius = WindowInfo.CornerRadius
    Library.ToggleKeybind = WindowInfo.ToggleKeybind
    if WindowInfo.Font then
        Library:SetFont(WindowInfo.Font)
    end

    local SidebarWidth = WindowInfo.SidebarWidth
    local Screen = GetScreenSize()

    -- Even sizes + a centre anchor at whole pixels keeps every edge (and all text) on the pixel grid.
    local Width = Even(math.min(WindowInfo.Size.X.Offset, Screen.X - 32))
    local Height = Even(math.min(WindowInfo.Size.Y.Offset, Screen.Y - 32))

    local Window = {
        Tabs = {},
    }

    local StartPosition
    if WindowInfo.Position and not WindowInfo.Center then
        local Pos = WindowInfo.Position
        StartPosition = UDim2.new(Pos.X.Scale, Pos.X.Offset + Width / 2, Pos.Y.Scale, Pos.Y.Offset + Height / 2)
    else
        StartPosition = UDim2.fromOffset(math.floor(Screen.X / 2), math.floor(Screen.Y / 2))
    end

    --// Root holds the shadow + main frame so both move together \\--
    local Root = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = StartPosition,
        Size = UDim2.fromOffset(Width, Height),
        Visible = false,
        Parent = ScreenGui,
    })
    local Scale = New("UIScale", { Parent = Root })

    New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Image = Assets.Shadow,
        ImageColor3 = "DarkColor",
        ImageTransparency = 0.25,
        Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Slice,
        Size = UDim2.new(1, 60, 1, 60),
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
            ImageColor3 = WindowIcon.Custom and "WhiteColor" or "AccentColor",
            Size = UDim2.fromOffset(24, 24),
            Parent = TitleHolder,
        })
        ApplyIcon(IconImage, WindowIcon)
    end

    local TitleLabel = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = function()
            return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.Bold)
        end,
        LayoutOrder = 1,
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
    List(TabInfo, 2, { VerticalAlignment = Enum.VerticalAlignment.Center })

    local TabInfoTitle = New("TextLabel", {
        FontFace = function()
            return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.SemiBold)
        end,
        Size = UDim2.new(1, 0, 0, 16),
        Text = "",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabInfo,
    })
    local TabInfoDescription = New("TextLabel", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 14),
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
        local StartInput, StartPos
        TrackDrag(TopBar, function(Position)
            StartInput = Position
            StartPos = Root.Position
        end, function(Position)
            local Delta = Position - StartInput
            Tween(Root, Library.DragTweenInfo, {
                Position = UDim2.new(
                    StartPos.X.Scale,
                    math.floor(StartPos.X.Offset + Delta.X),
                    StartPos.Y.Scale,
                    math.floor(StartPos.Y.Offset + Delta.Y)
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
        local ResizeIcon = Library:GetIcon("move-diagonal-2")
        if ResizeIcon then
            local GripIcon = New("ImageLabel", {
                ImageColor3 = "FontColor",
                ImageTransparency = 0.6,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 5,
                Parent = Grip,
            })
            ApplyIcon(GripIcon, ResizeIcon)
        end

        local StartInput, StartSize, StartPos
        TrackDrag(Grip, function(Position)
            StartInput = Position
            StartSize = Vector2.new(Root.Size.X.Offset, Root.Size.Y.Offset)
            StartPos = Root.Position
        end, function(Position)
            local Delta = Position - StartInput
            local Bounds = GetScreenSize()
            local NewX = Even(math.clamp(StartSize.X + Delta.X, SidebarWidth + 320, Bounds.X))
            local NewY = Even(math.clamp(StartSize.Y + Delta.Y, 300, Bounds.Y))

            -- Root is anchored at its centre; shift it by half the growth so the top-left stays put.
            Root.Size = UDim2.fromOffset(NewX, NewY)
            Root.Position = StartPos + UDim2.fromOffset((NewX - StartSize.X) / 2, (NewY - StartSize.Y) / 2)
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
            BackgroundColor3 = "SecondaryColor",
            BackgroundTransparency = 1,
            LayoutOrder = #Window.Tabs,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = Sidebar,
        })
        Corner(TabButton, 8)
        local ButtonStroke = Stroke(TabButton, "OutlineColor", 1)

        local Indicator = New("Frame", {
            BackgroundColor3 = "AccentColor",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.fromOffset(3, 0),
            ZIndex = 2,
            Parent = TabButton,
        })
        Corner(Indicator, UDim.new(1, 0))
        Sheen(Indicator)

        local TabIcon
        local IconData = Library:GetIcon(Icon)
        if IconData then
            TabIcon = New("ImageLabel", {
                ImageColor3 = IconData.Custom and "WhiteColor" or "AccentColor",
                ImageTransparency = 0.5,
                Position = UDim2.fromOffset(12, 9),
                Size = UDim2.fromOffset(18, 18),
                ZIndex = 2,
                Parent = TabButton,
            })
            ApplyIcon(TabIcon, IconData)
        end

        local TabLabel = New("TextLabel", {
            Position = UDim2.fromOffset(TabIcon and 40 or 14, 0),
            Size = UDim2.new(1, TabIcon and -48 or -22, 1, 0),
            Text = Name,
            TextSize = 13,
            TextTransparency = 0.5,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = TabButton,
        })

        --// Tab page: two scrolling columns, like Obsidian \\--
        local Page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = Container,
        })

        local function MakeSide(IsLeft)
            local Side = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarImageColor3 = "AccentColor",
                ScrollBarImageTransparency = 0.4,
                ScrollBarThickness = 2,
                Size = UDim2.fromScale(0.5, 1),
                Parent = Page,
            })
            List(Side, 10)
            Padding(Side, 10, 10, IsLeft and 10 or 5, IsLeft and 5 or 10)
            return Side
        end

        local Left = MakeSide(true)
        local Right = MakeSide(false)

        -- Whole-pixel column widths; a 50% split of an odd width puts the right column on a half pixel.
        local function LayoutSides()
            local Total = Root.Size.X.Offset - SidebarWidth - 1
            local Half = math.floor(Total / 2)
            Left.Size = UDim2.new(0, Half, 1, 0)
            Right.Position = UDim2.fromOffset(Half, 0)
            Right.Size = UDim2.new(0, Total - Half, 1, 0)
        end
        LayoutSides()
        Library:GiveSignal(Root:GetPropertyChangedSignal("Size"):Connect(LayoutSides))

        Tab.Button = TabButton
        Tab.Container = Page
        Tab.Sides = { Left, Right }

        function Tab:SetSelected(Selected)
            local TweenData = Library.TweenInfo
            Tween(TabButton, TweenData, { BackgroundTransparency = Selected and 0 or 1 })
            Tween(ButtonStroke, TweenData, { Transparency = Selected and 0 or 1 })
            Tween(TabLabel, TweenData, { TextTransparency = Selected and 0 or 0.5 })
            Tween(Indicator, TweenData, {
                BackgroundTransparency = Selected and 0 or 1,
                Position = UDim2.fromOffset(0, Selected and 9 or 18),
                Size = UDim2.fromOffset(3, Selected and 18 or 0),
            })
            if TabIcon then
                Tween(TabIcon, TweenData, { ImageTransparency = Selected and 0 or 0.5 })
            end
        end

        function Tab:Show()
            if Library.ActiveTab == Tab then
                return
            end
            CloseOpenedPopup()

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
            Page.Position = UDim2.fromOffset(0, 14)
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
                    ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
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
            List(BoxContainer, 9)
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
