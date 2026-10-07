--[[
    Ui3
    Obsidian's layout and API, dressed in Syde's colors and style.

    Supported so far:
        Library:CreateWindow / Library:Notify
        Window:AddTab
        Tab:AddGroupbox / AddLeftGroupbox / AddRightGroupbox / AddBigGroupbox
        Groupbox:AddToggle / AddCheckbox / AddButton / AddLabel / AddDivider
                 AddSlider / AddDropdown / AddInput
        Big groupbox only: AddProgressBar / AddStatCards / AddLog
        Toggle + Label addons: AddColorPicker / AddKeyPicker
        Built-in settings panel (gear icon): menu keybind, accent, configs, unload
]]

local cloneref = (cloneref or clonereference or function(Object)
    return Object
end)

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local GuiService = cloneref(game:GetService("GuiService"))
local HttpService = cloneref(game:GetService("HttpService"))
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
    ScrollFrames = {},
    Tabs = {},

    ActiveTab = nil,
    OpenedPopup = nil,

    -- Set while the pointer is dragging something (slider, color map, window...).
    -- Everything else ignores hovers and clicks until it's released.
    Dragging = nil,
    LastDragEnd = 0,
    LastKeyPick = 0,

    -- Config system
    ConfigFolder = "Ui3",
    IgnoreIndexes = {},
    PendingConfig = {},

    Toggled = false,
    Unloaded = false,
    ForceCheckbox = false,

    ToggleKeybind = Enum.KeyCode.RightControl,
    CornerRadius = 8,

    -- DPI scaling (like Obsidian): every top level piece of UI has a UIScale in Library.Scales.
    DPIScale = 1,
    Scales = {},
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,

    --// Syde palette, pushed darker \\--
    Scheme = {
        BackgroundColor = Color3.fromRGB(9, 9, 9),
        ContainerColor = Color3.fromRGB(11, 11, 11),
        MainColor = Color3.fromRGB(14, 14, 14),
        SecondaryColor = Color3.fromRGB(19, 19, 19),
        -- Fixed monochrome accent: it breathes between AccentDark and AccentLight (see AccentAnimation).
        AccentColor = Color3.fromRGB(200, 200, 200),
        AccentDark = Color3.fromRGB(135, 135, 135),
        AccentLight = Color3.fromRGB(240, 240, 240),
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
        TextSize = 14,
    },
    TextButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = "Font",
        Text = "",
        TextColor3 = "FontColor",
        TextSize = 14,
    },
    TextBox = {
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        FontFace = "Font",
        PlaceholderColor3 = function()
            return Library.Scheme.FontColor:Lerp(Library.Scheme.BackgroundColor, 0.6)
        end,
        TextColor3 = "FontColor",
        TextSize = 14,
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

local function MakeLine(Props)
    Props.BackgroundColor3 = "OutlineColor"
    return New("Frame", Props)
end

local function SemiBold()
    return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.SemiBold)
end

local function Bold()
    return Font.new(Library.Scheme.Font.Family, Enum.FontWeight.Bold)
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

-- The accent is part of the theme and can't be changed; kept so old scripts don't error.
function Library:SetAccent()
    warn("[Ui3] The accent color is fixed (animated black and white) and can't be changed.")
end

-- Pushes a new accent shade to everything bound to "AccentColor", without rerunning element updaters.
local function ApplyAccent(Color)
    Library.Scheme.AccentColor = Color
    for Object, Properties in Library.Registry do
        for Property, Value in Properties do
            if Value == "AccentColor" then
                Object[Property] = Color
            end
        end
    end
end
Library.ApplyAccent = ApplyAccent

--// Animated theme: the accent slowly breathes between grey and soft white \\--
Library.AccentAnimation = {
    Enabled = true,
    Period = 3.5, -- seconds for a full grey -> white -> grey cycle
    Rate = 30, -- updates per second
}

do
    local LastStep = 0
    Library:GiveSignal(RunService.Heartbeat:Connect(function()
        local Animation = Library.AccentAnimation
        if not Animation.Enabled or Library.Unloaded then
            return
        end

        local Now = os.clock()
        if Now - LastStep < 1 / Animation.Rate then
            return
        end
        LastStep = Now

        local Alpha = (math.sin(Now / Animation.Period * math.pi * 2) + 1) / 2
        ApplyAccent(Library.Scheme.AccentDark:Lerp(Library.Scheme.AccentLight, Alpha))
    end))
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

-- False while something is being dragged (and for a moment after), so releasing a
-- drag over a button or toggle never clicks it.
function Library:CanInteract()
    return Library.Dragging == nil and (os.clock() - Library.LastDragEnd) > 0.12
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

local function RegisterScroll(Frame)
    table.insert(Library.ScrollFrames, Frame)
    return Frame
end

local function NewScale(Parent)
    local Scale = New("UIScale", { Scale = Library.DPIScale, Parent = Parent })
    table.insert(Library.Scales, Scale)
    return Scale
end

-- Accepts 100, "100%" or "100".
function Library:SetDPIScale(Percent)
    if typeof(Percent) == "string" then
        Percent = tonumber((Percent:gsub("%%", "")))
    end
    Percent = math.clamp(tonumber(Percent) or 100, 25, 300)
    Library.DPIScale = Percent / 100

    for _, Scale in Library.Scales do
        Scale.Scale = Library.DPIScale
    end

    if Library.OpenedPopup then
        Library.OpenedPopup.Reposition()
    end
    if Library.Window and Library.Window.FitToScreen then
        Library.Window.FitToScreen()
    end
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

--// Tooltips \\--
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.XY,
    BackgroundColor3 = "MainColor",
    BackgroundTransparency = 0,
    Text = "",
    TextSize = 13,
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
NewScale(TooltipLabel)

local HoveredTooltip = nil

local function HideTooltip()
    HoveredTooltip = nil
    TooltipLabel.Visible = false
end

-- Hover effects go through here so nothing lights up while something else is being dragged.
local function OnHover(Object, Enter, Leave)
    Object.MouseEnter:Connect(function()
        if Library.Dragging then
            return
        end
        Enter()
    end)
    Object.MouseLeave:Connect(Leave)
end

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

    OnHover(HoverInstance, function()
        local Str = Current()
        if typeof(Str) ~= "string" or Str == "" then
            return
        end
        HoveredTooltip = Tooltip
        TooltipLabel.Text = Str
        TooltipLabel.Visible = true
    end, function()
        if HoveredTooltip == Tooltip then
            HideTooltip()
        end
    end)

    return Tooltip
end

Library:GiveSignal(RunService.RenderStepped:Connect(function()
    if not TooltipLabel.Visible then
        return
    end
    if not Library.Toggled or Library.Dragging then
        HideTooltip()
        return
    end
    local Mouse = GetMousePosition()
    TooltipLabel.Position = UDim2.fromOffset(math.floor(Mouse.X + 14), math.floor(Mouse.Y + 14))
end))

--// Dragging \\--
local function SetScrolling(Enabled)
    for _, Frame in Library.ScrollFrames do
        Frame.ScrollingEnabled = Enabled
    end
end

-- Generic press-and-drag helper (mouse + touch). While a drag is live, Library.Dragging
-- is set, every scrolling frame is frozen, and other elements ignore hover/click.
local function TrackDrag(Handle, OnStart, OnMove, OnEnd)
    local Pressed = false
    local Moved = false
    local StartPosition

    Handle.InputBegan:Connect(function(Input)
        if not IsClick(Input) or Library.Dragging or Pressed then
            return
        end

        Pressed = true
        Moved = false
        StartPosition = Input.Position
        SetScrolling(false)

        if OnStart then
            OnStart(Input.Position)
        end

        local Ended
        Ended = Input.Changed:Connect(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end
            Ended:Disconnect()
            Pressed = false

            if Moved then
                Library.LastDragEnd = os.clock()
            end
            if Library.Dragging == Handle then
                Library.Dragging = nil
            end
            SetScrolling(true)

            if OnEnd then
                OnEnd()
            end
        end)
    end)

    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if not Pressed or not IsMove(Input) then
            return
        end

        if not Moved then
            local Delta = Input.Position - StartPosition
            if math.abs(Delta.X) + math.abs(Delta.Y) >= 3 then
                Moved = true
                Library.Dragging = Handle
                HideTooltip()
            end
        end

        OnMove(Input.Position)
    end))
end

--// Popups (color pickers, dropdowns, key modes): live in the ScreenGui so groupboxes never clip them \\--
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
    local Scale = NewScale(Frame)

    Popup.Frame = Frame

    local Follow

    local function Reposition()
        if not Holder.Parent or not Library.Toggled then
            Popup:Close()
            return
        end

        local Screen = GetScreenSize()
        -- GetWidth returns on-screen pixels; the frame's own size is in unscaled units.
        local Width = Settings.GetWidth and math.floor(Settings.GetWidth() / Library.DPIScale + 0.5)
            or Frame.Size.X.Offset
        if Width ~= Frame.Size.X.Offset then
            Frame.Size = UDim2.fromOffset(Width, Frame.Size.Y.Offset)
        end

        -- On-screen size once the open animation finishes.
        local Size = Frame.AbsoluteSize / math.max(Scale.Scale, 0.01) * Library.DPIScale
        local HolderPos, HolderSize = Holder.AbsolutePosition, Holder.AbsoluteSize

        local X = if Settings.Align == "Right" then HolderPos.X + HolderSize.X - Size.X else HolderPos.X
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
        Scale.Scale = Library.DPIScale * 0.95
        Tween(Scale, Library.TweenInfo, { Scale = Library.DPIScale })

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

--// Notifications \\--
-- Same card language as groupboxes: icon + title header, optional description, and a slim
-- accent timer track like the slider's. They slide in from the right and follow the DPI scale.
local NotifyHolder = New("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -14, 1, -14),
    Size = UDim2.new(0, 250, 1, -28),
    ZIndex = 200,
    Parent = ScreenGui,
})
List(NotifyHolder, 8, {
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
})
NewScale(NotifyHolder)

local NotifyCount = 0
local SlideOffset = 290

function Library:Notify(Info, Time)
    if typeof(Info) ~= "table" then
        Info = { Title = tostring(Info), Time = Time }
    end
    local Duration = tonumber(Info.Time or Time) or 4

    NotifyCount += 1

    -- Holder keeps the list slot; Slider is what moves in and out.
    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = NotifyCount,
        Size = UDim2.fromScale(1, 0),
        ZIndex = 200,
        Parent = NotifyHolder,
    })

    local Slider = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SlideOffset, 0),
        Size = UDim2.fromScale(1, 0),
        ZIndex = 200,
        Parent = Holder,
    })

    local Shadow = New("ImageLabel", {
        Image = Assets.Shadow,
        ImageColor3 = "DarkColor",
        ImageTransparency = 0.35,
        Position = UDim2.fromOffset(-18, -18),
        ScaleType = Enum.ScaleType.Slice,
        Size = UDim2.fromOffset(286, 80),
        SliceCenter = Rect.new(23, 23, 277, 277),
        ZIndex = 200,
        Parent = Slider,
    })

    local Card = New("TextButton", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        Size = UDim2.fromScale(1, 0),
        ZIndex = 201,
        Parent = Slider,
    })
    Corner(Card, Library.CornerRadius)
    Stroke(Card)
    Padding(Card, 8, 9, 10, 10)
    List(Card, 6)

    -- Shadow follows the card's real height (unscaled units).
    local function SizeShadow()
        local Height = Card.AbsoluteSize.Y / math.max(Library.DPIScale, 0.01)
        Shadow.Size = UDim2.fromOffset(250 + 36, math.floor(Height + 36))
    end
    Card:GetPropertyChangedSignal("AbsoluteSize"):Connect(SizeShadow)

    --// Header: icon, title, close \--
    local Header = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        ZIndex = 202,
        Parent = Card,
    })

    local IconData = Library:GetIcon(Info.Icon or "bell")
    local TitleX = 0
    if IconData then
        local Icon = New("ImageLabel", {
            ImageColor3 = IconData.Custom and "WhiteColor" or "AccentColor",
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 202,
            Parent = Header,
        })
        ApplyIcon(Icon, IconData)
        TitleX = 22
    end

    local Title = New("TextLabel", {
        FontFace = SemiBold,
        Position = UDim2.fromOffset(TitleX, 0),
        Size = UDim2.new(1, -TitleX - 20, 1, 0),
        Text = Info.Title or "Notification",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
        Parent = Header,
    })

    local Close = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 203,
        Parent = Header,
    })
    local CloseIcon = Library:GetIcon("x")
    local CloseGlyph
    if CloseIcon then
        CloseGlyph = New("ImageLabel", {
            ImageColor3 = "FontColor",
            ImageTransparency = 0.6,
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = 203,
            Parent = Close,
        })
        ApplyIcon(CloseGlyph, CloseIcon)
    else
        Close.Text = "x"
        Close.TextTransparency = 0.6
    end

    --// Body \--
    local Description
    if Info.Description and Info.Description ~= "" then
        Description = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            Size = UDim2.fromScale(1, 0),
            Text = Info.Description,
            TextSize = 12,
            TextTransparency = 0.4,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202,
            Parent = Card,
        })
    end

    --// Timer: slider-style track \--
    local Track = New("Frame", {
        BackgroundColor3 = "SecondaryColor",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 3),
        ZIndex = 202,
        Parent = Card,
    })
    Corner(Track, UDim.new(1, 0))

    local Fill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 203,
        Parent = Track,
    })
    Corner(Fill, UDim.new(1, 0))
    Sheen(Fill)

    local Notification = { Destroyed = false }

    function Notification:Destroy()
        if Notification.Destroyed then
            return
        end
        Notification.Destroyed = true
        local Out = Tween(Slider, Library.TweenInfo, { Position = UDim2.fromOffset(SlideOffset, 0) })
        Out.Completed:Connect(function()
            Holder:Destroy()
        end)
    end

    function Notification:SetTitle(Text)
        Title.Text = Text
    end

    function Notification:SetDescription(Text)
        if Description then
            Description.Text = Text
        end
    end

    OnHover(Close, function()
        if CloseGlyph then
            Tween(CloseGlyph, Library.FastTweenInfo, { ImageTransparency = 0.1 })
        end
    end, function()
        if CloseGlyph then
            Tween(CloseGlyph, Library.FastTweenInfo, { ImageTransparency = 0.6 })
        end
    end)
    Close.MouseButton1Click:Connect(function()
        Notification:Destroy()
    end)
    Card.MouseButton1Click:Connect(function()
        Notification:Destroy()
    end)

    SizeShadow()
    Tween(Slider, Library.TweenInfo, { Position = UDim2.fromOffset(0, 0) })
    Tween(Fill, TweenInfo.new(Duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
    task.delay(Duration, function()
        Notification:Destroy()
    end)

    return Notification
end

--// Global input \\--
Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, Processed)
    if IsClick(Input) and Library.OpenedPopup then
        local Popup = Library.OpenedPopup
        local Position = Vector2.new(Input.Position.X, Input.Position.Y)
        if not IsInside(Popup.Frame, Position) and not IsInside(Popup.Holder, Position) then
            Popup:Close()
        end
    end

    if Processed or Library.PickingKey or os.clock() - Library.LastKeyPick < 0.05 then
        return
    end

    if Library.ToggleKeybind and Input.KeyCode == Library.ToggleKeybind and Library.Window then
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
        ShowSettings = true,
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
    KeyPicker = {
        Default = "None",
        Mode = "Toggle",
        Text = "Keybind",
        SyncToggleState = false,
        NoMode = false,
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
    Input = {
        Text = "Input",
        Default = "",
        Placeholder = "",
        Numeric = false,
        Finished = false,
        ClearTextOnFocus = false,
        Disabled = false,
        Visible = true,
        Callback = function() end,
    },
    ProgressBar = {
        Text = "Progress",
        Default = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "",
        Percent = true,
    },
    StatCards = {
        Cards = {},
    },
    Log = {
        Text = nil,
        Height = 150,
        MaxLines = 200,
        Timestamps = true,
    },
}

-- Registers an element and applies any value waiting for it from the autoload config,
-- so autoload works no matter when (or how late) the element is created.
local function RegisterElement(Idx, Element, IsToggle)
    if Idx == nil then
        return
    end

    if IsToggle then
        Toggles[Idx] = Element
    else
        Options[Idx] = Element
    end

    local Pending = Library.PendingConfig[Idx]
    if Pending then
        Library.PendingConfig[Idx] = nil
        Library:ApplyConfigEntry(Pending)
    end
end

--// Elements shared by every container \\--
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
            TextSize = 13,
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
        if not Library:CanInteract() then
            return
        end
        Popup:Toggle()
    end)

    ColorPicker:Display()

    if ParentObj.Addons then
        table.insert(ParentObj.Addons, ColorPicker)
    end
    RegisterElement(Idx, ColorPicker)

    return self
end

local function KeyFromInput(Input)
    local Type = Input.UserInputType
    if Type == Enum.UserInputType.MouseButton1 then
        return "MB1"
    elseif Type == Enum.UserInputType.MouseButton2 then
        return "MB2"
    elseif Type == Enum.UserInputType.MouseButton3 then
        return "MB3"
    elseif Type == Enum.UserInputType.Keyboard then
        return Input.KeyCode.Name
    end
    return nil
end

function Funcs:AddKeyPicker(Idx, Info)
    Info = Library:Validate(Info, Templates.KeyPicker)

    local ParentObj = self
    local AddonHolder = ParentObj.TextLabel
    assert(AddonHolder, "AddKeyPicker must be called on a toggle or a label")

    local KeyPicker = {
        Value = Info.Default,
        Mode = Info.Mode,
        Text = Info.Text,
        Toggled = false,
        Holding = false,
        Picking = false,
        SyncToggleState = Info.SyncToggleState,

        Callback = Info.Callback,
        ChangedCallback = Info.ChangedCallback,
        Changed = nil,
        Clicked = nil,
        Type = "KeyPicker",
    }

    if KeyPicker.SyncToggleState and ParentObj.Type == "Toggle" then
        KeyPicker.Toggled = ParentObj.Value
    end

    local Button = New("TextButton", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = "SecondaryColor",
        Size = UDim2.fromOffset(0, 18),
        Text = "",
        TextSize = 12,
        TextTransparency = 0.25,
        Parent = AddonHolder,
    })
    Corner(Button, 5)
    Padding(Button, 0, 0, 7, 7)
    local ButtonStroke = Stroke(Button)

    function KeyPicker:Display()
        Button.Text = KeyPicker.Picking and "..." or tostring(KeyPicker.Value)
    end

    function KeyPicker:GetState()
        if KeyPicker.Mode == "Always" then
            return true
        elseif KeyPicker.Mode == "Hold" then
            return KeyPicker.Holding
        end
        return KeyPicker.Toggled
    end

    function KeyPicker:OnChanged(Func)
        KeyPicker.Changed = Func
    end

    function KeyPicker:OnClick(Func)
        KeyPicker.Clicked = Func
    end

    function KeyPicker:SetValue(Data)
        local Key, Mode
        if typeof(Data) == "table" then
            Key, Mode = Data[1], Data[2]
        else
            Key = Data
        end

        local OldKey = KeyPicker.Value
        KeyPicker.Value = Key or KeyPicker.Value
        if Mode == "Toggle" or Mode == "Hold" or Mode == "Always" then
            KeyPicker.Mode = Mode
        end
        KeyPicker:Display()

        if KeyPicker.Value ~= OldKey then
            Library:SafeCallback(KeyPicker.ChangedCallback, KeyPicker.Value)
            Library:SafeCallback(KeyPicker.Changed, KeyPicker.Value)
        end
    end

    local function SetPicking(Picking)
        KeyPicker.Picking = Picking
        if Picking then
            Library.PickingKey = KeyPicker
        elseif Library.PickingKey == KeyPicker then
            Library.PickingKey = nil
        end
        SetThemed(ButtonStroke, "Color", Picking and "AccentColor" or "OutlineColor", Library.FastTweenInfo)
        KeyPicker:Display()
    end

    -- Mode menu (right click)
    local ModePopup
    if not Info.NoMode then
        ModePopup = Library:CreatePopup(Button, { Width = 96, Align = "Right", AutoHeight = true })
        Padding(ModePopup.Frame, 4)
        List(ModePopup.Frame, 2)

        local ModeButtons = {}
        local function RefreshModes()
            for Mode, ModeButton in ModeButtons do
                SetThemed(ModeButton, "TextColor3", KeyPicker.Mode == Mode and "AccentColor" or "FontColor", false)
                ModeButton.TextTransparency = KeyPicker.Mode == Mode and 0 or 0.4
            end
        end

        for Order, Mode in { "Toggle", "Hold", "Always" } do
            local ModeButton = New("TextButton", {
                BackgroundColor3 = "SecondaryColor",
                BackgroundTransparency = 1,
                LayoutOrder = Order,
                Size = UDim2.new(1, 0, 0, 24),
                Text = Mode,
                TextSize = 13,
                ZIndex = 52,
                Parent = ModePopup.Frame,
            })
            Corner(ModeButton, 5)
            OnHover(ModeButton, function()
                Tween(ModeButton, Library.FastTweenInfo, { BackgroundTransparency = 0 })
            end, function()
                Tween(ModeButton, Library.FastTweenInfo, { BackgroundTransparency = 1 })
            end)
            ModeButton.MouseButton1Click:Connect(function()
                KeyPicker.Mode = Mode
                KeyPicker.Holding = false
                RefreshModes()
                ModePopup:Close()
            end)
            ModeButtons[Mode] = ModeButton
        end

        ModePopup.OnOpen = RefreshModes
    end

    Button.MouseButton1Click:Connect(function()
        if not Library:CanInteract() then
            return
        end
        SetPicking(true)
    end)

    Button.MouseButton2Click:Connect(function()
        if ModePopup and Library:CanInteract() then
            ModePopup:Toggle()
        end
    end)

    local function SetState(State)
        Library:SafeCallback(KeyPicker.Callback, State)
    end

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, Processed)
        if KeyPicker.Picking then
            local Key = KeyFromInput(Input)
            if not Key then
                return
            end
            if Key == "Escape" or Key == "Backspace" then
                Key = "None"
            end

            Library.LastKeyPick = os.clock()
            SetPicking(false)
            KeyPicker:SetValue({ Key })
            return
        end

        if KeyPicker.Value == "None" or Library.Unloaded then
            return
        end
        -- Another picker is listening for a new key, or one just finished: this press isn't a trigger.
        if Library.PickingKey or os.clock() - Library.LastKeyPick < 0.05 then
            return
        end
        if Processed and Input.UserInputType == Enum.UserInputType.Keyboard then
            return
        end
        if KeyFromInput(Input) ~= KeyPicker.Value then
            return
        end

        Library:SafeCallback(KeyPicker.Clicked)

        if KeyPicker.Mode == "Toggle" then
            KeyPicker.Toggled = not KeyPicker.Toggled
            if KeyPicker.SyncToggleState and ParentObj.Type == "Toggle" then
                ParentObj:SetValue(KeyPicker.Toggled)
            end
            SetState(KeyPicker.Toggled)
        elseif KeyPicker.Mode == "Hold" then
            KeyPicker.Holding = true
            SetState(true)
        end
    end))

    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if KeyPicker.Mode == "Hold" and KeyPicker.Holding and KeyFromInput(Input) == KeyPicker.Value then
            KeyPicker.Holding = false
            SetState(false)
        end
    end))

    KeyPicker:Display()

    if ParentObj.Addons then
        table.insert(ParentObj.Addons, KeyPicker)
    end
    RegisterElement(Idx, KeyPicker)

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
        MakeLine({ Size = UDim2.new(1, 0, 0, 1), Parent = Holder })
        local Label = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 1,
            Size = UDim2.fromOffset(0, 14),
            Text = Text,
            TextSize = 13,
            TextTransparency = 0.5,
            Parent = Holder,
        })
        New("UIFlexItem", { FlexMode = Enum.UIFlexMode.None, Parent = Label })
        MakeLine({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 1), Parent = Holder })
    else
        MakeLine({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 1), Parent = Holder })
    end

    return Holder
end

-- Toggles and checkboxes share everything except the visual on the right/left.
local function BuildToggle(Groupbox, Idx, Info, Variant)
    Info = Library:Validate(Info, Templates.Toggle)

    local Toggle = {
        Text = Info.Text,
        Value = Info.Default,
        Callback = Info.Callback,
        Changed = Info.Changed,

        Risky = Info.Risky,
        Disabled = Info.Disabled,
        Visible = Info.Visible,

        Addons = {},
        Variant = Variant,
        Type = "Toggle",
    }

    local IsCheckbox = Variant == "Checkbox"

    local Button = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Visible = Toggle.Visible,
        Parent = Groupbox.Container,
    })

    local Label = New("TextLabel", {
        Position = UDim2.fromOffset(IsCheckbox and 28 or 0, 0),
        Size = UDim2.new(1, IsCheckbox and -28 or -44, 1, 0),
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

    local Box, BoxStroke, Ball, Check
    if IsCheckbox then
        -- Syde-style checkbox: accent fill + check mark.
        Box = New("Frame", {
            BackgroundColor3 = "SecondaryColor",
            Position = UDim2.fromOffset(0, 1),
            Size = UDim2.fromOffset(18, 18),
            Parent = Button,
        })
        Corner(Box, 5)
        BoxStroke = Stroke(Box)
        Sheen(Box)

        local CheckIcon = Library:GetIcon("check")
        if CheckIcon then
            Check = New("ImageLabel", {
                ImageColor3 = "BackgroundColor",
                ImageTransparency = 1,
                Position = UDim2.fromOffset(2, 2),
                Size = UDim2.fromOffset(14, 14),
                Parent = Box,
            })
            ApplyIcon(Check, CheckIcon)
        else
            Check = New("TextLabel", {
                Size = UDim2.fromScale(1, 1),
                Text = "✓",
                TextColor3 = "BackgroundColor",
                TextSize = 14,
                TextTransparency = 1,
                Parent = Box,
            })
        end
    else
        -- Obsidian switch with a Syde accent fill.
        Box = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = "SecondaryColor",
            Position = UDim2.new(1, 0, 0, 1),
            Size = UDim2.fromOffset(34, 18),
            Parent = Button,
        })
        Corner(Box, UDim.new(1, 0))
        Padding(Box, 3)
        BoxStroke = Stroke(Box)
        Sheen(Box)

        Ball = New("Frame", {
            BackgroundColor3 = "FontColor",
            BackgroundTransparency = 0.5,
            Size = UDim2.fromOffset(12, 12),
            Parent = Box,
        })
        Corner(Ball, UDim.new(1, 0))
    end

    Toggle.TextLabel = Label
    Toggle.Container = Groupbox.Container

    if Info.Tooltip or Info.DisabledTooltip then
        Toggle.TooltipTable = Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Button)
    end

    function Toggle:Display(Instant)
        local TweenData = if Instant then false else Library.TweenInfo
        local On = Toggle.Value

        SetThemed(Box, "BackgroundColor3", On and "AccentColor" or "SecondaryColor", TweenData)
        SetThemed(BoxStroke, "Color", On and "AccentColor" or "OutlineColor", TweenData)

        local Goals = {}
        if Ball then
            local Offset = On and 1 or 0
            -- Dark knob on the light accent track, light knob on the dark off track.
            SetThemed(Ball, "BackgroundColor3", On and "BackgroundColor" or "FontColor", TweenData)
            Goals[Ball] = {
                AnchorPoint = Vector2.new(Offset, 0),
                Position = UDim2.fromScale(Offset, 0),
                BackgroundTransparency = On and 0 or 0.5,
            }
        else
            Goals[Check] = Check:IsA("ImageLabel") and { ImageTransparency = On and 0 or 1 }
                or { TextTransparency = On and 0 or 1 }
        end
        Goals[Label] = { TextTransparency = Toggle.Disabled and 0.8 or (On and 0 or 0.4) }

        for Object, Goal in Goals do
            if Instant then
                for Key, Value in Goal do
                    Object[Key] = Value
                end
            else
                Tween(Object, Object == Label and Library.FastTweenInfo or Library.TweenInfo, Goal)
            end
        end

        Box.BackgroundTransparency = Toggle.Disabled and 0.6 or 0
        BoxStroke.Transparency = Toggle.Disabled and 0.6 or 0
    end

    function Toggle:OnChanged(Func)
        Toggle.Changed = Func
    end

    function Toggle:SetValue(Value)
        Toggle.Value = not not Value
        Toggle:Display()

        for _, Addon in Toggle.Addons do
            if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                Addon.Toggled = Toggle.Value
            end
        end

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

    OnHover(Button, function()
        if not Toggle.Disabled and not Toggle.Value then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.15 })
        end
    end, function()
        if not Toggle.Disabled and not Toggle.Value then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    Button.MouseButton1Click:Connect(function()
        if Toggle.Disabled or not Library:CanInteract() then
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

    RegisterElement(Idx, Toggle, true)
    return Toggle
end

function Funcs:AddToggle(Idx, Info)
    return BuildToggle(self, Idx, Info, Library.ForceCheckbox and "Checkbox" or "Switch")
end

function Funcs:AddCheckbox(Idx, Info)
    return BuildToggle(self, Idx, Info, "Checkbox")
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

        OnHover(Base, function()
            if Button.Disabled then
                return
            end
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0 })
            SetThemed(Base, "BackgroundColor3", function()
                return Library.Scheme.SecondaryColor:Lerp(Library.Scheme.FontColor, 0.04)
            end, Library.FastTweenInfo)
        end, function()
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
            Circle.Position = UDim2.fromOffset(
                (Position.X - Base.AbsolutePosition.X) / Library.DPIScale,
                (Position.Y - Base.AbsolutePosition.Y) / Library.DPIScale
            )
            Circle.Size = UDim2.fromOffset(0, 0)
            Circle.ZIndex = 1
            Corner(Circle, UDim.new(1, 0))
            Circle.Parent = Base

            local Diameter = math.max(Base.AbsoluteSize.X, Base.AbsoluteSize.Y) / Library.DPIScale * 2.2
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
            if IsClick(Input) and not Button.Disabled and Library:CanInteract() then
                Ripple(Input.Position)
            end
        end)

        local ArmId = 0
        Base.MouseButton1Click:Connect(function()
            if Button.Disabled or not Library:CanInteract() then
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

function Funcs:AddInput(Idx, Info)
    Info = Library:Validate(Info, Templates.Input)

    local Groupbox = self

    local Input = {
        Text = Info.Text,
        Value = "",
        Numeric = Info.Numeric,
        Finished = Info.Finished,
        MaxLength = Info.MaxLength,

        Callback = Info.Callback,
        Changed = Info.Changed,

        Disabled = Info.Disabled,
        Visible = Info.Visible,
        Type = "Input",
    }

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Visible = Input.Visible,
        Parent = Groupbox.Container,
    })
    List(Holder, 5)

    local Label = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        Text = Input.Text or "",
        TextTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = Input.Text ~= nil and Input.Text ~= "",
        Parent = Holder,
    })

    local Box = New("TextBox", {
        BackgroundColor3 = "SecondaryColor",
        ClearTextOnFocus = Info.ClearTextOnFocus,
        LayoutOrder = 1,
        PlaceholderText = Info.Placeholder,
        Size = UDim2.new(1, 0, 0, 30),
        Text = "",
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    Corner(Box, 6)
    Padding(Box, 0, 0, 10, 10)
    local BoxStroke = Stroke(Box)

    Input.TextLabel = Label
    Input.TextBox = Box

    if Info.Tooltip or Info.DisabledTooltip then
        Input.TooltipTable = Library:AddTooltip(Info.Tooltip, Info.DisabledTooltip, Box)
    end

    local function Clean(Text)
        Text = tostring(Text or "")
        if Input.Numeric then
            Text = Text:gsub("[^%d%.%-]", "")
        end
        if Input.MaxLength and #Text > Input.MaxLength then
            Text = Text:sub(1, Input.MaxLength)
        end
        return Text
    end

    function Input:OnChanged(Func)
        Input.Changed = Func
    end

    function Input:SetValue(Text)
        Text = Clean(Text)
        if Box.Text ~= Text then
            Box.Text = Text
        end
        if Text == Input.Value then
            return
        end
        Input.Value = Text
        Library:SafeCallback(Input.Callback, Input.Value)
        Library:SafeCallback(Input.Changed, Input.Value)
    end

    function Input:SetText(Text)
        Input.Text = Text
        Label.Text = Text or ""
        Label.Visible = Text ~= nil and Text ~= ""
    end

    function Input:SetDisabled(Disabled)
        Input.Disabled = Disabled
        Box.TextEditable = not Disabled
        Box.TextTransparency = Disabled and 0.7 or 0
        Label.TextTransparency = Disabled and 0.8 or 0.4
        BoxStroke.Transparency = Disabled and 0.5 or 0
        if Input.TooltipTable then
            Input.TooltipTable.Disabled = Disabled
        end
    end

    function Input:SetVisible(Visible)
        Input.Visible = Visible
        Holder.Visible = Visible
    end

    Box:GetPropertyChangedSignal("Text"):Connect(function()
        local Cleaned = Clean(Box.Text)
        if Cleaned ~= Box.Text then
            Box.Text = Cleaned
            return
        end
        if not Input.Finished then
            Input:SetValue(Cleaned)
        end
    end)

    Box.Focused:Connect(function()
        SetThemed(BoxStroke, "Color", "AccentColor", Library.FastTweenInfo)
    end)
    Box.FocusLost:Connect(function(EnterPressed)
        SetThemed(BoxStroke, "Color", "OutlineColor", Library.FastTweenInfo)
        if Input.Finished then
            if EnterPressed then
                Input:SetValue(Box.Text)
            else
                Box.Text = Input.Value
            end
        end
    end)

    -- Set the default without firing callbacks, like every other element.
    Input.Value = Clean(Info.Default)
    Box.Text = Input.Value
    Input:SetDisabled(Input.Disabled)

    setmetatable(Input, { __index = Funcs })

    RegisterElement(Idx, Input)
    return Input
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
        TextSize = 13,
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
        Tween(Label, Library.FastTweenInfo, { TextTransparency = 0 })
        SetFromPosition(Position)
    end, SetFromPosition, function()
        Dragging = false
        Tween(Knob, Library.FastTweenInfo, { Size = UDim2.fromOffset(12, 12) })
        if not Slider.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    OnHover(Holder, function()
        if not Slider.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.1 })
            Tween(ValueBox, Library.FastTweenInfo, { TextTransparency = 0.1 })
        end
    end, function()
        if not Slider.Disabled and not Dragging then
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

    RegisterElement(Idx, Slider)
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
            TextSize = 13,
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

    local ListFrame = RegisterScroll(New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        LayoutOrder = 1,
        ScrollBarImageColor3 = "AccentColor",
        ScrollBarImageTransparency = 0.3,
        ScrollBarThickness = 2,
        Size = UDim2.new(1, 0, 0, RowHeight),
        ZIndex = 51,
        Parent = Menu,
    }))
    List(ListFrame, RowGap)

    local EmptyLabel = New("TextLabel", {
        LayoutOrder = 999999,
        Size = UDim2.new(1, 0, 0, RowHeight),
        Text = "No values",
        TextSize = 13,
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
                TextSize = 13,
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

            OnHover(Button, function()
                if not IsValueDisabled(Value) then
                    Tween(Button, Library.FastTweenInfo, { BackgroundTransparency = 0 })
                end
            end, function()
                Tween(Button, Library.FastTweenInfo, { BackgroundTransparency = 1 })
            end)

            Button.MouseButton1Click:Connect(function()
                if Dropdown.Disabled or IsValueDisabled(Value) or not Library:CanInteract() then
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

    OnHover(Box, function()
        if not Dropdown.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.1 })
        end
    end, function()
        if not Dropdown.Disabled then
            Tween(Label, Library.FastTweenInfo, { TextTransparency = 0.4 })
        end
    end)

    Box.MouseButton1Click:Connect(function()
        if Dropdown.Disabled or not Library:CanInteract() then
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

    RegisterElement(Idx, Dropdown)
    return Dropdown
end

--// Big groupbox only elements \\--
local function RequireBig(Groupbox, Name)
    assert(Groupbox.IsBig, Name .. " can only be added to a big groupbox (Tab:AddBigGroupbox)")
end

function Funcs:AddProgressBar(Idx, Info)
    RequireBig(self, "AddProgressBar")
    Info = Library:Validate(Info, Templates.ProgressBar)

    local ProgressBar = {
        Text = Info.Text,
        Value = 0,
        Max = Info.Max,
        Rounding = Info.Rounding,
        Suffix = Info.Suffix,
        Percent = Info.Percent,
        Changed = nil,
        Type = "ProgressBar",
    }

    local Holder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        Parent = self.Container,
    })

    local Label = New("TextLabel", {
        Size = UDim2.new(1, -110, 0, 16),
        Text = ProgressBar.Text,
        TextTransparency = 0.3,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })

    local ValueLabel = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        FontFace = SemiBold,
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(110, 16),
        Text = "",
        TextColor3 = "AccentColor",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Holder,
    })

    local Track = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = "SecondaryColor",
        ClipsDescendants = true,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 12),
        Parent = Holder,
    })
    Corner(Track, UDim.new(1, 0))
    Stroke(Track)

    local Fill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(0, 1),
        Parent = Track,
    })
    Corner(Fill, UDim.new(1, 0))
    Sheen(Fill)

    ProgressBar.TextLabel = Label

    local function Round(Value)
        local Mult = 10 ^ ProgressBar.Rounding
        return math.floor(Value * Mult + 0.5) / Mult
    end

    function ProgressBar:Display(Instant)
        local Alpha = ProgressBar.Max > 0 and math.clamp(ProgressBar.Value / ProgressBar.Max, 0, 1) or 0
        if ProgressBar.Percent then
            ValueLabel.Text = string.format("%d%%", math.floor(Alpha * 100 + 0.5))
        else
            local Format = "%." .. ProgressBar.Rounding .. "f"
            ValueLabel.Text = string.format(Format, ProgressBar.Value)
                .. " / "
                .. string.format(Format, ProgressBar.Max)
                .. ProgressBar.Suffix
        end

        if Instant then
            Fill.Size = UDim2.fromScale(Alpha, 1)
        else
            Tween(Fill, Library.TweenInfo, { Size = UDim2.fromScale(Alpha, 1) })
        end
    end

    function ProgressBar:SetValue(Value)
        ProgressBar.Value = math.clamp(Round(tonumber(Value) or 0), 0, ProgressBar.Max)
        ProgressBar:Display()
        Library:SafeCallback(ProgressBar.Changed, ProgressBar.Value)
    end

    function ProgressBar:SetMax(Max)
        ProgressBar.Max = math.max(Max, 0)
        ProgressBar.Value = math.min(ProgressBar.Value, ProgressBar.Max)
        ProgressBar:Display()
    end

    function ProgressBar:SetText(Text)
        ProgressBar.Text = Text
        Label.Text = Text
    end

    function ProgressBar:OnChanged(Func)
        ProgressBar.Changed = Func
    end

    ProgressBar.Value = math.clamp(Round(Info.Default), 0, ProgressBar.Max)
    ProgressBar:Display(true)

    if Idx then
        Options[Idx] = ProgressBar
    end
    return ProgressBar
end

function Funcs:AddStatCards(Idx, Info)
    RequireBig(self, "AddStatCards")
    Info = Library:Validate(Info, Templates.StatCards)

    local StatCards = {
        Cards = {},
        Type = "StatCards",
    }

    local Holder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 58),
        Parent = self.Container,
    })
    List(Holder, 8, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
    })

    function StatCards:AddCard(Card)
        local Frame = New("Frame", {
            BackgroundColor3 = "SecondaryColor",
            LayoutOrder = #StatCards.Cards + 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })
        Corner(Frame, 6)
        Stroke(Frame)
        Padding(Frame, 9, 9, 10, 10)

        local IconData = Library:GetIcon(Card.Icon)
        if IconData then
            local Icon = New("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0),
                ImageColor3 = IconData.Custom and "WhiteColor" or "AccentColor",
                ImageTransparency = 0.2,
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.fromOffset(16, 16),
                Parent = Frame,
            })
            ApplyIcon(Icon, IconData)
        end

        New("TextLabel", {
            Size = UDim2.new(1, IconData and -20 or 0, 0, 14),
            Text = Card.Title or "",
            TextSize = 12,
            TextTransparency = 0.5,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Frame,
        })

        local ValueLabel = New("TextLabel", {
            AnchorPoint = Vector2.new(0, 1),
            FontFace = Bold,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20),
            Text = tostring(Card.Value or ""),
            TextSize = 18,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Frame,
        })

        local Entry = { Title = Card.Title, Value = Card.Value, Label = ValueLabel, Frame = Frame }
        table.insert(StatCards.Cards, Entry)
        return Entry
    end

    function StatCards:SetValue(Title, Value)
        for _, Entry in StatCards.Cards do
            if Entry.Title == Title then
                Entry.Value = Value
                Entry.Label.Text = tostring(Value)
                return true
            end
        end
        return false
    end

    function StatCards:GetValue(Title)
        for _, Entry in StatCards.Cards do
            if Entry.Title == Title then
                return Entry.Value
            end
        end
        return nil
    end

    for _, Card in Info.Cards do
        StatCards:AddCard(Card)
    end

    if Idx then
        Options[Idx] = StatCards
    end
    return StatCards
end

function Funcs:AddLog(Idx, Info)
    RequireBig(self, "AddLog")
    Info = Library:Validate(Info, Templates.Log)

    local Log = {
        Lines = {},
        MaxLines = Info.MaxLines,
        Timestamps = Info.Timestamps,
        Type = "Log",
    }

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Parent = self.Container,
    })
    List(Holder, 5)

    if Info.Text then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            Text = Info.Text,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })
    end

    local Console = RegisterScroll(New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "SecondaryColor",
        BackgroundTransparency = 0,
        CanvasSize = UDim2.fromScale(0, 0),
        LayoutOrder = 1,
        ScrollBarImageColor3 = "AccentColor",
        ScrollBarImageTransparency = 0.4,
        ScrollBarThickness = 2,
        Size = UDim2.new(1, 0, 0, Info.Height),
        Parent = Holder,
    }))
    Corner(Console, 6)
    Stroke(Console)
    Padding(Console, 8, 8, 10, 10)
    List(Console, 2)

    local LineCount = 0

    local function ScrollToBottom()
        task.defer(function()
            Console.CanvasPosition = Vector2.new(0, math.max(0, Console.AbsoluteCanvasSize.Y - Console.AbsoluteWindowSize.Y))
        end)
    end

    function Log:Log(Text, Color)
        LineCount += 1
        local Stamp = ""
        if Log.Timestamps then
            Stamp = '<font transparency="0.5">[' .. os.date("%H:%M:%S") .. "]</font> "
        end

        local Line = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.Y,
            FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
            LayoutOrder = LineCount,
            Size = UDim2.fromScale(1, 0),
            Text = Stamp .. tostring(Text),
            TextColor3 = Color or "FontColor",
            TextSize = 13,
            TextTransparency = Color and 0 or 0.15,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Console,
        })
        table.insert(Log.Lines, Line)

        while #Log.Lines > Log.MaxLines do
            table.remove(Log.Lines, 1):Destroy()
        end

        ScrollToBottom()
        return Line
    end
    Log.Print = Log.Log

    function Log:Clear()
        for _, Line in Log.Lines do
            Line:Destroy()
        end
        table.clear(Log.Lines)
    end

    if Idx then
        Options[Idx] = Log
    end
    return Log
end

--// Groupboxes \\--
local function CreateGroupbox(Parent, Info, LayoutOrder, Tab, IsBig)
    local Box = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        LayoutOrder = LayoutOrder or 0,
        Size = UDim2.fromScale(1, 0),
        Parent = Parent,
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

    local BoxIcon = Library:GetIcon(Info.IconName or Info.Icon)
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
        FontFace = SemiBold,
        Size = UDim2.new(1, 0, 0, 18),
        Text = Info.Name or "Groupbox",
        TextSize = 15,
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
            TextSize = 13,
            TextTransparency = 0.5,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Texts,
        })
    end

    MakeLine({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 1), Parent = Box })

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
        IsBig = IsBig == true,
        Type = "Groupbox",
    }

    function Groupbox:SetVisible(Visible)
        Box.Visible = Visible
    end

    setmetatable(Groupbox, { __index = Funcs })
    return Groupbox
end

--// Config system \\--
local function HasFileSystem()
    return typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(isfile) == "function"
        and typeof(isfolder) == "function"
        and typeof(makefolder) == "function"
        and typeof(listfiles) == "function"
end
Library.HasFileSystem = HasFileSystem

local function SanitizeName(Name)
    Name = tostring(Name or "")
    Name = Name:gsub("[^%w%s%-_%.]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return Name
end

local function EnsureFolders()
    local Path = ""
    for _, Part in string.split(Library.ConfigFolder, "/") do
        Path = Path == "" and Part or (Path .. "/" .. Part)
        if not isfolder(Path) then
            makefolder(Path)
        end
    end
    local Configs = Library.ConfigFolder .. "/configs"
    if not isfolder(Configs) then
        makefolder(Configs)
    end
end

local function ConfigPath(Name)
    return Library.ConfigFolder .. "/configs/" .. Name .. ".json"
end

local function AutoloadPath()
    return Library.ConfigFolder .. "/autoload.txt"
end

function Library:SetIgnoreIndexes(Indexes)
    for _, Idx in Indexes do
        Library.IgnoreIndexes[Idx] = true
    end
end

function Library:SetConfigFolder(Folder)
    Library.ConfigFolder = tostring(Folder)
end

function Library:GetConfigData()
    local Objects = {}

    for Idx, Toggle in Toggles do
        if not Library.IgnoreIndexes[Idx] then
            table.insert(Objects, { type = "Toggle", idx = Idx, value = Toggle.Value })
        end
    end

    for Idx, Option in Options do
        if Library.IgnoreIndexes[Idx] then
            continue
        end

        if Option.Type == "Slider" then
            table.insert(Objects, { type = "Slider", idx = Idx, value = Option.Value })
        elseif Option.Type == "Dropdown" then
            local Value = Option.Value
            if Option.Multi then
                Value = Option:GetActiveValues()
            end
            table.insert(Objects, { type = "Dropdown", idx = Idx, value = Value, multi = Option.Multi })
        elseif Option.Type == "ColorPicker" then
            table.insert(Objects, {
                type = "ColorPicker",
                idx = Idx,
                value = Option.Value:ToHex(),
                transparency = Option.Transparency,
            })
        elseif Option.Type == "KeyPicker" then
            table.insert(Objects, { type = "KeyPicker", idx = Idx, key = Option.Value, mode = Option.Mode })
        elseif Option.Type == "Input" then
            table.insert(Objects, { type = "Input", idx = Idx, text = Option.Value })
        end
    end

    return { version = 1, objects = Objects }
end

function Library:ApplyConfigEntry(Entry)
    if typeof(Entry) ~= "table" or Entry.idx == nil then
        return false
    end

    local Object = if Entry.type == "Toggle" then Toggles[Entry.idx] else Options[Entry.idx]
    if not Object or Object.Type ~= Entry.type then
        return false
    end

    local Success, Error = pcall(function()
        if Entry.type == "Toggle" then
            Object:SetValue(Entry.value == true)
        elseif Entry.type == "Slider" then
            Object:SetValue(tonumber(Entry.value))
        elseif Entry.type == "Dropdown" then
            Object:SetValue(Entry.value)
        elseif Entry.type == "ColorPicker" then
            Object:SetValueRGB(Color3.fromHex(Entry.value), tonumber(Entry.transparency))
        elseif Entry.type == "KeyPicker" then
            Object:SetValue({ Entry.key, Entry.mode })
        elseif Entry.type == "Input" then
            Object:SetValue(Entry.text)
        end
    end)

    if not Success then
        warn("[Ui3] Failed to load '" .. tostring(Entry.idx) .. "': " .. tostring(Error))
    end
    return Success
end

function Library:SaveConfig(Name)
    if not HasFileSystem() then
        return false, "your executor doesn't support saving files"
    end
    Name = SanitizeName(Name)
    if Name == "" then
        return false, "invalid config name"
    end

    local Success, Encoded = pcall(function()
        return HttpService:JSONEncode(Library:GetConfigData())
    end)
    if not Success then
        return false, "failed to encode config"
    end

    local Wrote, Error = pcall(function()
        EnsureFolders()
        writefile(ConfigPath(Name), Encoded)
    end)
    if not Wrote then
        return false, tostring(Error)
    end
    return true
end

-- KeepPending: values for elements that don't exist yet are applied the moment they're created.
function Library:LoadConfig(Name, KeepPending)
    if not HasFileSystem() then
        return false, "your executor doesn't support files"
    end
    Name = SanitizeName(Name)
    local Path = ConfigPath(Name)
    if Name == "" or not isfile(Path) then
        return false, "config does not exist"
    end

    local Success, Decoded = pcall(function()
        return HttpService:JSONDecode(readfile(Path))
    end)
    if not Success or typeof(Decoded) ~= "table" or typeof(Decoded.objects) ~= "table" then
        return false, "config is corrupted"
    end

    for _, Entry in Decoded.objects do
        if typeof(Entry) ~= "table" or Entry.idx == nil then
            continue
        end
        local Exists = if Entry.type == "Toggle" then Toggles[Entry.idx] else Options[Entry.idx]
        if Exists then
            Library:ApplyConfigEntry(Entry)
        elseif KeepPending then
            Library.PendingConfig[Entry.idx] = Entry
        end
    end

    return true
end

function Library:DeleteConfig(Name)
    if not HasFileSystem() or typeof(delfile) ~= "function" then
        return false, "your executor doesn't support deleting files"
    end
    Name = SanitizeName(Name)
    local Path = ConfigPath(Name)
    if Name == "" or not isfile(Path) then
        return false, "config does not exist"
    end

    local Success, Error = pcall(delfile, Path)
    if not Success then
        return false, tostring(Error)
    end
    if Library:GetAutoloadConfig() == Name then
        Library:ClearAutoloadConfig()
    end
    return true
end

function Library:GetConfigs()
    if not HasFileSystem() then
        return {}
    end
    local Names = {}
    pcall(function()
        EnsureFolders()
        for _, File in listfiles(Library.ConfigFolder .. "/configs") do
            local Name = tostring(File):match("([^/\\]+)%.json$")
            if Name then
                table.insert(Names, Name)
            end
        end
    end)
    table.sort(Names, function(A, B)
        return A:lower() < B:lower()
    end)
    return Names
end

function Library:SetAutoloadConfig(Name)
    if not HasFileSystem() then
        return false, "your executor doesn't support files"
    end
    Name = SanitizeName(Name)
    if Name == "" or not isfile(ConfigPath(Name)) then
        return false, "config does not exist"
    end
    local Success, Error = pcall(function()
        EnsureFolders()
        writefile(AutoloadPath(), Name)
    end)
    if not Success then
        return false, tostring(Error)
    end
    return true
end

function Library:GetAutoloadConfig()
    if not HasFileSystem() then
        return nil
    end
    local Success, Name = pcall(function()
        if isfile(AutoloadPath()) then
            return SanitizeName(readfile(AutoloadPath()))
        end
        return nil
    end)
    if Success and Name and Name ~= "" then
        return Name
    end
    return nil
end

function Library:ClearAutoloadConfig()
    if not HasFileSystem() then
        return false
    end
    pcall(function()
        if typeof(delfile) == "function" and isfile(AutoloadPath()) then
            delfile(AutoloadPath())
        else
            writefile(AutoloadPath(), "")
        end
    end)
    return true
end

function Library:LoadAutoloadConfig()
    local Name = Library:GetAutoloadConfig()
    if not Name then
        return false, "no autoload config"
    end
    local Success, Error = Library:LoadConfig(Name, true)
    if Success then
        Library.LoadedAutoload = Name
    end
    return Success, Error
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
        Window.Scale.Scale = Library.DPIScale * 0.96
        Tween(Window.Scale, Library.TweenInfo, { Scale = Library.DPIScale })
    else
        CloseOpenedPopup()
        HideTooltip()
        local T = Tween(
            Window.Scale,
            TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Scale = Library.DPIScale * 0.96 }
        )
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
    table.clear(Library.ScrollFrames)
    table.clear(Library.PendingConfig)
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

    -- Each script gets its own config folder (override with ConfigFolder).
    Library.ConfigFolder = WindowInfo.ConfigFolder
        or ("Ui3/" .. (SanitizeName(WindowInfo.Title) ~= "" and SanitizeName(WindowInfo.Title) or "Default"))

    -- Read the autoload config now: every element created from here on picks up its saved value.
    if WindowInfo.AutoLoad ~= false then
        Library:LoadAutoloadConfig()
    end

    if WindowInfo.DPIScale then
        Library:SetDPIScale(WindowInfo.DPIScale)
    end

    local SidebarWidth = WindowInfo.SidebarWidth
    local Screen = GetScreenSize()

    -- Sizes are in unscaled units; on screen they're multiplied by the DPI scale.
    -- Even sizes + a centre anchor at whole pixels keeps every edge (and all text) on the pixel grid.
    local Width = Even(math.min(WindowInfo.Size.X.Offset, (Screen.X - 32) / Library.DPIScale))
    local Height = Even(math.min(WindowInfo.Size.Y.Offset, (Screen.Y - 32) / Library.DPIScale))

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
    local Scale = NewScale(Root)

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

    --// Top bar \\--
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        Parent = Main,
    })
    MakeLine({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 1), Parent = Main })

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
        FontFace = Bold,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 20),
        Text = WindowInfo.Title,
        TextSize = 19,
        Parent = TitleHolder,
    })

    -- Current tab info (where Obsidian puts its tab title/description).
    local TabInfo = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SidebarWidth + 1, 0),
        Size = UDim2.new(1, -SidebarWidth - 1 - 56, 1, 0),
        Parent = TopBar,
    })
    Padding(TabInfo, 0, 0, 14, 0)
    List(TabInfo, 2, { VerticalAlignment = Enum.VerticalAlignment.Center })

    local TabInfoTitle = New("TextLabel", {
        FontFace = SemiBold,
        Size = UDim2.new(1, 0, 0, 16),
        Text = "",
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabInfo,
    })
    local TabInfoDescription = New("TextLabel", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "",
        TextSize = 13,
        TextTransparency = 0.5,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = TabInfo,
    })

    --// Sidebar + divider \\--
    MakeLine({ Position = UDim2.fromOffset(SidebarWidth, 49), Size = UDim2.new(0, 1, 1, -70), Parent = Main })

    local Sidebar = RegisterScroll(New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(0, SidebarWidth, 1, -70),
        Parent = Main,
    }))
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
    MakeLine({
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -20),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Main,
    })

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
        TextSize = 13,
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
            local Dpi = Library.DPIScale
            local Delta = Position - StartInput
            local Bounds = GetScreenSize()
            local NewX = Even(math.clamp(StartSize.X + Delta.X / Dpi, SidebarWidth + 320, math.max(SidebarWidth + 320, Bounds.X / Dpi)))
            local NewY = Even(math.clamp(StartSize.Y + Delta.Y / Dpi, 300, math.max(300, Bounds.Y / Dpi)))

            -- Root is anchored at its centre; shift it by half the (on-screen) growth so the top-left stays put.
            Root.Size = UDim2.fromOffset(NewX, NewY)
            Root.Position = StartPos
                + UDim2.fromOffset(math.floor((NewX - StartSize.X) * Dpi / 2), math.floor((NewY - StartSize.Y) * Dpi / 2))
        end)
    end

    -- Keep the window on screen when the DPI scale grows.
    function Window.FitToScreen()
        local Bounds = GetScreenSize()
        local Dpi = Library.DPIScale
        local MaxX = math.max(SidebarWidth + 320, (Bounds.X - 16) / Dpi)
        local MaxY = math.max(300, (Bounds.Y - 16) / Dpi)
        if Root.Size.X.Offset > MaxX or Root.Size.Y.Offset > MaxY then
            Root.Size = UDim2.fromOffset(Even(math.min(Root.Size.X.Offset, MaxX)), Even(math.min(Root.Size.Y.Offset, MaxY)))
        end
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

    -- Width available to a tab page's content (container minus its 10px padding on both sides).
    local function ContentWidth()
        return Root.Size.X.Offset - SidebarWidth - 1 - 20
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
            TextSize = 14,
            TextTransparency = 0.5,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = TabButton,
        })

        --// Tab page \\--
        -- One scrolling page made of sections: rows of left/right columns, with big
        -- groupboxes spanning the full width between them, in the order they're added.
        local Page = RegisterScroll(New("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.fromScale(0, 0),
            ScrollBarImageColor3 = "AccentColor",
            ScrollBarImageTransparency = 0.4,
            ScrollBarThickness = 2,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = Container,
        }))
        Padding(Page, 10, 10, 10, 10)
        List(Page, 10)

        local SectionCount = 0
        local ColumnSections = {}
        local CurrentColumns = nil

        -- Whole-pixel column widths; a 50% split of an odd width puts the right column on a half pixel.
        local function LayoutColumns(Section)
            local Total = ContentWidth()
            local Half = math.floor((Total - 10) / 2)
            Section.Left.Size = UDim2.new(0, Half, 0, 0)
            Section.Right.Position = UDim2.fromOffset(Half + 10, 0)
            Section.Right.Size = UDim2.new(0, Total - Half - 10, 0, 0)
        end

        local function NewColumns()
            SectionCount += 1
            local Frame = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = SectionCount,
                Size = UDim2.fromScale(1, 0),
                Parent = Page,
            })

            local function Column()
                local Col = New("Frame", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Parent = Frame,
                })
                List(Col, 10)
                return Col
            end

            local Section = { Frame = Frame, Left = Column(), Right = Column() }
            LayoutColumns(Section)
            table.insert(ColumnSections, Section)
            return Section
        end

        Library:GiveSignal(Root:GetPropertyChangedSignal("Size"):Connect(function()
            for _, Section in ColumnSections do
                LayoutColumns(Section)
            end
        end))

        Tab.Button = TabButton
        Tab.Container = Page

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

        OnHover(TabButton, function()
            if Library.ActiveTab ~= Tab then
                Tween(TabLabel, Library.FastTweenInfo, { TextTransparency = 0.25 })
            end
        end, function()
            if Library.ActiveTab ~= Tab then
                Tween(TabLabel, Library.FastTweenInfo, { TextTransparency = 0.5 })
            end
        end)
        TabButton.MouseButton1Click:Connect(function()
            if Library:CanInteract() then
                Tab:Show()
            end
        end)

        --// Groupboxes \\--
        function Tab:AddGroupbox(Info)
            Info = Library:Validate(Info, Templates.Groupbox)

            local SideIndex = Info.Side
            if typeof(SideIndex) == "string" then
                SideIndex = SideIndex:lower() == "right" and 2 or 1
            end

            if not CurrentColumns then
                CurrentColumns = NewColumns()
            end
            local Column = SideIndex == 2 and CurrentColumns.Right or CurrentColumns.Left

            local Groupbox = CreateGroupbox(Column, Info, #Tab.Groupboxes, Tab, false)
            table.insert(Tab.Groupboxes, Groupbox)
            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = "Left", Name = Name, IconName = IconName })
        end

        function Tab:AddRightGroupbox(Name, IconName)
            return Tab:AddGroupbox({ Side = "Right", Name = Name, IconName = IconName })
        end

        -- Full width groupbox. Groupboxes added after it start a new row of columns below it.
        function Tab:AddBigGroupbox(Info, IconName)
            if typeof(Info) ~= "table" then
                Info = { Name = Info, IconName = IconName }
            end
            Info = Library:Validate(Info, Templates.Groupbox)

            SectionCount += 1
            CurrentColumns = nil

            local Groupbox = CreateGroupbox(Page, Info, SectionCount, Tab, true)
            table.insert(Tab.Groupboxes, Groupbox)
            return Groupbox
        end

        table.insert(Window.Tabs, Tab)
        Library.Tabs[Name] = Tab

        if #Window.Tabs == 1 then
            Tab:Show()
        end

        return Tab
    end

    --// Settings panel (gear, top right) \\--
    local PanelWidth = 280
    local SettingsOpen = false

    local SettingsButton = New("ImageButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = "SecondaryColor",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        Visible = WindowInfo.ShowSettings,
        ZIndex = 3,
        Parent = TopBar,
    })
    Corner(SettingsButton, 8)
    local SettingsStroke = Stroke(SettingsButton, "OutlineColor", 1)

    local GearIcon = Library:GetIcon("settings")
    local Gear
    if GearIcon then
        Gear = New("ImageLabel", {
            ImageColor3 = "FontColor",
            ImageTransparency = 0.4,
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 3,
            Parent = SettingsButton,
        })
        ApplyIcon(Gear, GearIcon)
    else
        Gear = New("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            Text = "⚙",
            TextSize = 17,
            TextTransparency = 0.4,
            ZIndex = 3,
            Parent = SettingsButton,
        })
    end

    local Overlay = New("TextButton", {
        BackgroundColor3 = "DarkColor",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -70),
        Visible = false,
        ZIndex = 8,
        Parent = Main,
    })

    local Panel = New("Frame", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.new(1, 0, 0, 49),
        Size = UDim2.new(0, PanelWidth, 1, -70),
        Visible = false,
        ZIndex = 9,
        Parent = Main,
    })
    MakeLine({ Size = UDim2.new(0, 1, 1, 0), ZIndex = 9, Parent = Panel })

    local PanelHeader = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 42),
        ZIndex = 9,
        Parent = Panel,
    })
    Padding(PanelHeader, 0, 0, 14, 10)
    New("TextLabel", {
        FontFace = SemiBold,
        Size = UDim2.new(1, -30, 1, 0),
        Text = "Settings",
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9,
        Parent = PanelHeader,
    })

    local CloseButton = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        Text = "",
        ZIndex = 9,
        Parent = PanelHeader,
    })
    local CloseIcon = Library:GetIcon("x")
    if CloseIcon then
        local CloseImage = New("ImageLabel", {
            ImageColor3 = "FontColor",
            ImageTransparency = 0.4,
            Position = UDim2.fromOffset(3, 3),
            Size = UDim2.fromOffset(18, 18),
            ZIndex = 9,
            Parent = CloseButton,
        })
        ApplyIcon(CloseImage, CloseIcon)
    else
        CloseButton.Text = "X"
    end

    MakeLine({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 1), ZIndex = 9, Parent = Panel })

    local PanelScroll = RegisterScroll(New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        Position = UDim2.fromOffset(1, 43),
        ScrollBarImageColor3 = "AccentColor",
        ScrollBarImageTransparency = 0.4,
        ScrollBarThickness = 2,
        Size = UDim2.new(1, -1, 1, -43),
        ZIndex = 9,
        Parent = Panel,
    }))
    Padding(PanelScroll, 10, 10, 10, 10)
    List(PanelScroll, 10)

    function Window:SetSettingsOpen(Open)
        if Open == SettingsOpen then
            return
        end
        SettingsOpen = Open
        CloseOpenedPopup()

        if Open then
            Panel.Visible = true
            Overlay.Visible = true
        end

        Tween(Panel, Library.TweenInfo, {
            Position = UDim2.new(1, Open and -PanelWidth or 0, 0, 49),
        })
        Tween(Gear, Library.TweenInfo, { Rotation = Open and 90 or 0 })
        Tween(SettingsButton, Library.FastTweenInfo, { BackgroundTransparency = Open and 0 or 1 })
        Tween(SettingsStroke, Library.FastTweenInfo, { Transparency = Open and 0 or 1 })
        local Fade = Tween(Overlay, Library.FastTweenInfo, { BackgroundTransparency = Open and 0.45 or 1 })

        if not Open then
            Fade.Completed:Connect(function()
                if not SettingsOpen then
                    Panel.Visible = false
                    Overlay.Visible = false
                end
            end)
        end
    end

    function Window:OpenSettings()
        Window:SetSettingsOpen(true)
    end

    function Window:CloseSettings()
        Window:SetSettingsOpen(false)
    end

    SettingsButton.MouseButton1Click:Connect(function()
        if Library:CanInteract() then
            Window:SetSettingsOpen(not SettingsOpen)
        end
    end)
    CloseButton.MouseButton1Click:Connect(function()
        Window:SetSettingsOpen(false)
    end)
    Overlay.MouseButton1Click:Connect(function()
        if Library:CanInteract() then
            Window:SetSettingsOpen(false)
        end
    end)
    OnHover(SettingsButton, function()
        if not SettingsOpen then
            Tween(Gear, Library.FastTweenInfo, Gear:IsA("ImageLabel") and { ImageTransparency = 0 } or { TextTransparency = 0 })
        end
    end, function()
        Tween(Gear, Library.FastTweenInfo, Gear:IsA("ImageLabel") and { ImageTransparency = 0.4 } or { TextTransparency = 0.4 })
    end)

    -- Settings sections are ordinary groupboxes, so they use the exact same elements.
    local SettingsSections = 0
    function Window:AddSettingsGroupbox(Info, IconName)
        if typeof(Info) ~= "table" then
            Info = { Name = Info, IconName = IconName }
        end
        SettingsSections += 1
        return CreateGroupbox(PanelScroll, Info, SettingsSections, nil, false)
    end

    local MenuBox = Window:AddSettingsGroupbox("Menu", "sliders-horizontal")

    MenuBox:AddLabel("Menu keybind"):AddKeyPicker("Ui3_MenuKeybind", {
        Default = Library.ToggleKeybind and Library.ToggleKeybind.Name or "RightControl",
        Text = "Menu keybind",
        NoMode = true,
        ChangedCallback = function(Key)
            local Success, KeyCode = pcall(function()
                return Enum.KeyCode[Key]
            end)
            if Success and KeyCode and Key ~= "None" then
                Library.ToggleKeybind = KeyCode
            else
                -- Never leave the menu without a keyboard key to open it.
                local Previous = Library.ToggleKeybind and Library.ToggleKeybind.Name or "RightControl"
                task.defer(function()
                    if Options.Ui3_MenuKeybind then
                        Options.Ui3_MenuKeybind:SetValue({ Previous })
                    end
                end)
                Library:Notify({ Title = "Invalid menu keybind", Description = "Pick a keyboard key.", Time = 3 })
            end
        end,
    })

    local DPIValues = { 50, 75, 90, 100, 110, 125, 150, 175, 200 }
    local CurrentDPI = math.floor(Library.DPIScale * 100 + 0.5)
    if not table.find(DPIValues, CurrentDPI) then
        table.insert(DPIValues, CurrentDPI)
        table.sort(DPIValues)
    end
    for Index, Value in DPIValues do
        DPIValues[Index] = Value .. "%"
    end

    MenuBox:AddDropdown("Ui3_DPI", {
        Text = "DPI scale",
        Values = DPIValues,
        Default = CurrentDPI .. "%",
        Callback = function(Value)
            if Value then
                Library:SetDPIScale(Value)
            end
        end,
    })

    local ConfigBox = Window:AddSettingsGroupbox("Configs", "folder")
    Library:SetIgnoreIndexes({ "Ui3_ConfigName", "Ui3_ConfigList" })

    if not HasFileSystem() then
        ConfigBox:AddLabel("Your executor doesn't support files, so configs can't be saved.", true)
    else
        local AutoloadLabel

        local function RefreshAutoloadLabel()
            AutoloadLabel:SetText("Autoload: " .. (Library:GetAutoloadConfig() or "none"))
        end

        local NameInput = ConfigBox:AddInput("Ui3_ConfigName", {
            Text = "Config name",
            Placeholder = "my config",
        })

        local ConfigList

        local function RefreshList(Select)
            ConfigList:SetValues(Library:GetConfigs())
            if Select then
                ConfigList:SetValue(Select)
            end
        end

        local function Report(Success, Error, Message)
            if Success then
                Library:Notify({ Title = Message, Time = 3 })
            else
                Library:Notify({ Title = "Config error", Description = tostring(Error), Time = 4 })
            end
        end

        ConfigBox:AddButton({
            Text = "Create config",
            Func = function()
                local Name = SanitizeName(NameInput.Value)
                if Name == "" then
                    Report(false, "Type a config name first.")
                    return
                end
                if table.find(Library:GetConfigs(), Name) then
                    Report(false, "'" .. Name .. "' already exists. Select it and press Overwrite.")
                    return
                end
                local Success, Error = Library:SaveConfig(Name)
                Report(Success, Error, "Created config '" .. Name .. "'")
                if Success then
                    NameInput:SetValue("")
                    RefreshList(Name)
                end
            end,
        })

        ConfigList = ConfigBox:AddDropdown("Ui3_ConfigList", {
            Text = "Configs",
            Values = Library:GetConfigs(),
            AllowNull = true,
        })

        local function Selected()
            local Name = ConfigList.Value
            if not Name then
                Report(false, "Select a config first.")
            end
            return Name
        end

        ConfigBox:AddButton({
            Text = "Load",
            Func = function()
                local Name = Selected()
                if Name then
                    local Success, Error = Library:LoadConfig(Name)
                    Report(Success, Error, "Loaded config '" .. Name .. "'")
                end
            end,
        }):AddButton({
            Text = "Overwrite",
            DoubleClick = true,
            Func = function()
                local Name = Selected()
                if Name then
                    local Success, Error = Library:SaveConfig(Name)
                    Report(Success, Error, "Overwrote config '" .. Name .. "'")
                end
            end,
        })

        ConfigBox:AddButton({
            Text = "Delete",
            Risky = true,
            DoubleClick = true,
            Func = function()
                local Name = Selected()
                if Name then
                    local Success, Error = Library:DeleteConfig(Name)
                    Report(Success, Error, "Deleted config '" .. Name .. "'")
                    RefreshList()
                    RefreshAutoloadLabel()
                end
            end,
        }):AddButton({
            Text = "Refresh",
            Func = function()
                RefreshList()
            end,
        })

        ConfigBox:AddButton({
            Text = "Set autoload",
            Func = function()
                local Name = Selected()
                if Name then
                    local Success, Error = Library:SetAutoloadConfig(Name)
                    Report(Success, Error, "'" .. Name .. "' will load automatically")
                    RefreshAutoloadLabel()
                end
            end,
        }):AddButton({
            Text = "Reset autoload",
            Func = function()
                Library:ClearAutoloadConfig()
                Report(true, nil, "Autoload cleared")
                RefreshAutoloadLabel()
            end,
        })

        AutoloadLabel = ConfigBox:AddLabel("Autoload: none", true)
        RefreshAutoloadLabel()

        if Library.LoadedAutoload then
            ConfigList:SetValue(Library.LoadedAutoload)
        end
    end

    local DangerBox = Window:AddSettingsGroupbox("Script", "power")
    DangerBox:AddButton({
        Text = "Unload",
        Risky = true,
        DoubleClick = true,
        Func = function()
            Library:Unload()
        end,
    })

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

    if Library.LoadedAutoload then
        task.defer(function()
            Library:Notify({ Title = "Loaded autoload config", Description = Library.LoadedAutoload, Time = 3 })
        end)
    end

    return Window
end

pcall(function()
    getgenv().Library = Library
    getgenv().Toggles = Toggles
    getgenv().Options = Options
end)

return Library
