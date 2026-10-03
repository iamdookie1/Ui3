# Ui3

A Roblox UI library that combines **Obsidian's layout and API** with **Syde's look**: a very dark theme, a pink accent and smooth, exponential animations.

If you've used Obsidian (or Linoria), you already know how to use this. Most scripts carry over with few or no changes.

## Features

- Sidebar tabs, groupboxes in two columns, and **big groupboxes** that span both columns
- Toggles, checkboxes, buttons (with sub-buttons and double-click confirm), labels, dividers, sliders, dropdowns (single, multi, searchable, player and team lists), text inputs
- Color pickers and keybind pickers that attach to toggles and labels
- Big groupbox only: progress bars, stat cards and a log console
- Notifications and tooltips
- A built-in **settings panel** (gear icon, top right) with menu keybind, DPI scale, accent color, configs and unload
- **Configs** that save, load and **autoload**, applied as each element is created, so they work even if your script creates elements late
- **DPI scaling** from 50% to 200%, saved in configs
- While you drag a slider, color picker or the window, every other element ignores hovers and clicks
- Theme changes (like the accent color) update the whole UI live

## Quick start

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui3/main/Ui.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
	Title = "My Script",
	Footer = "v1.0",
	Icon = "sparkles", -- lucide icon name or an asset id
})

local Main = Window:AddTab("Main", "user", "Everything important")
local Box = Main:AddLeftGroupbox("Combat", "swords")

Box:AddToggle("AutoParry", {
	Text = "Auto parry",
	Default = false,
	Callback = function(Value)
		print("Auto parry:", Value)
	end,
})
```

> While this is still on the development branch, replace `main` in the URL with `ccr-26bcb4bb-7izgsr`.

To see every element in action, run the example script:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui3/main/Example.lua"))()
```

Press **RightControl** to hide or show the menu. You can change this key in settings.

## Reading values

Every element with an index is stored in `Library.Toggles` (toggles and checkboxes) or `Library.Options` (everything else). These tables are also in `getgenv()` as `Toggles` and `Options`.

```lua
print(Toggles.AutoParry.Value)

Toggles.AutoParry:OnChanged(function(Value)
	print("changed to", Value)
end)

Toggles.AutoParry:SetValue(true)
```

The recommended pattern is to build the UI first and hook up `OnChanged` afterwards, like in Obsidian.

## Window

```lua
local Window = Library:CreateWindow({
	Title = "Ui3",
	Footer = "",
	Icon = nil,                 -- lucide name or asset id
	Size = UDim2.fromOffset(720, 560),
	Center = true,
	Position = nil,             -- used when Center = false
	AutoShow = true,
	Resizable = true,
	SidebarWidth = 190,
	CornerRadius = 10,
	ToggleKeybind = Enum.KeyCode.RightControl,
	DPIScale = nil,             -- starting DPI in percent, e.g. 125
	ShowSettings = true,        -- the gear icon and settings panel
	ConfigFolder = nil,         -- defaults to "Ui3/<Title>"
	AutoLoad = true,            -- load the autoload config on start
	Font = nil,                 -- Font or Enum.Font
})

Window:SetTitle("New title")
Window:SetFooter("New footer")
Window:OpenSettings()
Window:CloseSettings()
```

## Tabs and groupboxes

```lua
local Tab = Window:AddTab("Main", "user", "Optional description shown in the top bar")
-- or Window:AddTab({ Name = "Main", Icon = "user", Description = "..." })

local Left = Tab:AddLeftGroupbox("Left", "boxes")
local Right = Tab:AddRightGroupbox("Right", "palette")

local Box = Tab:AddGroupbox({
	Side = "Left",          -- "Left" or "Right"
	Name = "Groupbox",
	Description = "Optional",
	IconName = "boxes",
})

-- Spans both columns. Groupboxes added after it start a new row below it.
local Big = Tab:AddBigGroupbox({ Name = "Overview", Description = "Optional", IconName = "gauge" })
-- or Tab:AddBigGroupbox("Overview", "gauge")
```

Icons are [lucide](https://lucide.dev/) names, or a Roblox asset id for a custom image. Lucide icons are tinted with the accent color.

## Elements

All of these work in normal groupboxes, big groupboxes and the settings panel.

### Toggle / Checkbox

```lua
Box:AddToggle("MyToggle", {
	Text = "This is a toggle",
	Default = false,
	Tooltip = "Shown on hover",
	DisabledTooltip = "Shown on hover while disabled",
	Disabled = false,
	Visible = true,
	Risky = false,          -- red text
	Callback = function(Value) end,
})

Box:AddCheckbox("MyCheckbox", { Text = "This is a checkbox", Default = true })
```

Methods: `SetValue`, `OnChanged`, `SetText`, `SetDisabled`, `SetVisible`.
Set `Library.ForceCheckbox = true` to turn every toggle into a checkbox.

### Button

```lua
local Button = Box:AddButton({
	Text = "Button",
	Func = function() print("clicked") end,
	DoubleClick = false,    -- true asks "Are you sure?" first
	Tooltip = nil,
	Risky = false,
	Disabled = false,
})

-- A sub button sits next to the first one
Button:AddButton({ Text = "Sub button", Func = function() end })

-- Short form
Box:AddButton("Text", function() end)
```

Methods: `SetText`, `SetDisabled`, `SetVisible`.

### Label and divider

```lua
local Label = Box:AddLabel("Some text")
Box:AddLabel("Long text that wraps onto several lines", true)
Box:AddLabel("LabelIdx", { Text = "With an index", DoesWrap = false })

Box:AddDivider()
Box:AddDivider("With text")
```

Label methods: `SetText`, `SetVisible`. Labels can hold color pickers and keybinds.

### Slider

```lua
Box:AddSlider("MySlider", {
	Text = "Walk speed",
	Default = 16,
	Min = 0,
	Max = 200,
	Rounding = 0,           -- decimal places
	Prefix = "",
	Suffix = " studs",
	Compact = false,        -- shows "Text: value" on one line
	HideMax = false,        -- hides "/ max"
	FormatDisplayValue = function(Slider, Value)
		-- return a string to override the text, or nil for the default
	end,
	Callback = function(Value) end,
})
```

Click the number on the right to type an exact value.
Methods: `SetValue`, `SetMin`, `SetMax`, `SetText`, `SetPrefix`, `SetSuffix`, `SetDisabled`, `SetVisible`, `OnChanged`.

### Dropdown

```lua
Box:AddDropdown("MyDropdown", {
	Text = "A dropdown",
	Values = { "One", "Two", "Three" },
	Default = 1,            -- index or value
	Multi = false,          -- true: Value becomes { [value] = true }
	AllowNull = false,      -- clicking the selected value clears it
	Searchable = false,     -- adds a search box
	MaxVisibleDropdownItems = 8,
	DisabledValues = {},    -- shown but can't be picked
	FormatDisplayValue = function(Value) return Value end,
	Callback = function(Value) end,
})

-- Dictionary values: keys go in .Value, values are the labels shown
Box:AddDropdown("Weapon", {
	Values = { item01 = "Excalibur", item02 = "Wooden Club" },
	Default = "item01",
})

-- Fills itself with players (or teams) and stays up to date
Box:AddDropdown("Target", { SpecialType = "Player", ExcludeLocalPlayer = true, Text = "Target" })
Box:AddDropdown("Team", { SpecialType = "Team", Text = "Team" })
```

Methods: `SetValue`, `SetValues`, `AddValues`, `GetActiveValues(ReturnCount)`, `SetDisabledValues`, `AddDisabledValues`, `SetText`, `SetDisabled`, `SetVisible`, `OnChanged`.

### Input

```lua
Box:AddInput("MyInput", {
	Text = "Display name",
	Default = "",
	Placeholder = "Type something...",
	Numeric = false,        -- numbers only
	Finished = false,       -- only fires when Enter is pressed
	ClearTextOnFocus = false,
	MaxLength = nil,
	Callback = function(Value) end,
})
```

Methods: `SetValue`, `SetText`, `SetDisabled`, `SetVisible`, `OnChanged`.

### Color picker

Attach it to a toggle or a label. Calls can be chained.

```lua
Box:AddToggle("ESP", { Text = "ESP" })
	:AddColorPicker("ESPColor", {
		Default = Color3.fromRGB(255, 151, 227),
		Title = "ESP color",
		Transparency = 0,   -- set to a number to show the transparency bar
		Callback = function(Color, Transparency) end,
	})

Box:AddLabel("Outline"):AddColorPicker("OutlineColor", { Default = Color3.new(1, 1, 1) })
```

Methods: `SetValueRGB(Color, Transparency)`, `SetValue({ H, S, V }, Transparency)`, `OnChanged`.
The picker also has hex and RGB boxes for typing exact colors.

### Keybind picker

Attach it to a toggle or a label. Click it to bind a new key (Escape or Backspace clears it), and right-click it to choose the mode.

```lua
Box:AddToggle("Fly", { Text = "Fly" })
	:AddKeyPicker("FlyKey", {
		Default = "F",          -- KeyCode name, or "MB1" / "MB2" / "MB3"
		Mode = "Toggle",        -- "Toggle", "Hold" or "Always"
		SyncToggleState = true, -- pressing the key flips the toggle
		NoMode = false,         -- true hides the mode menu
		Text = "Fly",
		Callback = function(State) end,        -- state changed
		ChangedCallback = function(NewKey) end, -- key rebound
	})

print(Options.FlyKey:GetState())
```

Methods: `GetState`, `SetValue({ Key, Mode })`, `OnChanged`, `OnClick`.

## Big groupbox elements

These can only be added to a groupbox made with `Tab:AddBigGroupbox`.

```lua
local Big = Tab:AddBigGroupbox("Overview", "gauge")

local Stats = Big:AddStatCards("Stats", {
	Cards = {
		{ Title = "Kills", Value = 0, Icon = "swords" },
		{ Title = "Coins", Value = 1250, Icon = "coins" },
	},
})
Stats:SetValue("Kills", 5)
print(Stats:GetValue("Coins"))

local Progress = Big:AddProgressBar("Progress", {
	Text = "Auto farm",
	Default = 35,
	Max = 100,
	Percent = true,     -- false shows "35 / 100" plus Suffix
	Rounding = 0,
	Suffix = "",
})
Progress:SetValue(60)

local Log = Big:AddLog("Log", {
	Text = nil,         -- optional title above the console
	Height = 150,
	MaxLines = 200,
	Timestamps = true,
})
Log:Log("Hello")
Log:Log("Accent line", Library.Scheme.AccentColor)
Log:Clear()
```

## Notifications

```lua
Library:Notify("Short message", 3)

local Notification = Library:Notify({
	Title = "Saved",
	Description = "Your config was saved.",
	Time = 4,
	Icon = "check",     -- lucide name, defaults to a bell
})

Notification:SetTitle("New title")
Notification:SetDescription("New text")
Notification:Destroy()
```

## Settings panel

The gear icon in the top right opens a panel that every script gets for free:

- **Menu:** menu keybind, DPI scale and accent color
- **Configs:** create, load, overwrite, delete, refresh, set autoload, reset autoload
- **Script:** unload

You can add your own sections to it:

```lua
local Extra = Window:AddSettingsGroupbox("My settings", "wrench")
Extra:AddToggle("Watermark", { Text = "Show watermark" })
```

## Configs

Configs are JSON files saved in `Ui3/<window title>/configs/`, or in the folder you pass as `ConfigFolder`. They store toggles, checkboxes, sliders, dropdowns, color pickers, keybinds, inputs, and the menu keybind, DPI and accent from settings.

Autoload applies saved values the moment each element is created. That way it works even if your script creates elements after a wait. Loading a value runs that element's callback, so features turn back on.

You normally do all of this from the settings panel, but it can also be scripted:

```lua
Library:SaveConfig("legit")
Library:LoadConfig("legit")
Library:DeleteConfig("legit")
print(Library:GetConfigs())

Library:SetAutoloadConfig("legit")
Library:ClearAutoloadConfig()
print(Library:GetAutoloadConfig())

-- Don't save these elements
Library:SetIgnoreIndexes({ "MyInput", "Target" })
```

Each of these returns `success, errorMessage`. Configs need an executor with file functions (`writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`). If those are missing, the settings panel says so.

## Theme, DPI and other library functions

```lua
Library:SetAccent(Color3.fromRGB(88, 141, 255))   -- recolors the whole UI live
Library:SetFont(Enum.Font.Gotham)
Library:SetDPIScale(125)                           -- 50 to 200, like Obsidian

Library:Toggle()        -- show or hide the window
Library:Toggle(true)

Library:OnUnload(function() print("bye") end)
Library:Unload()
```

The colors live in `Library.Scheme`:

| Key | Default | Used for |
| --- | --- | --- |
| `BackgroundColor` | `9, 9, 9` | Window, sidebar, settings panel |
| `ContainerColor` | `11, 11, 11` | Tab content area |
| `MainColor` | `14, 14, 14` | Groupboxes, popups, notifications |
| `SecondaryColor` | `19, 19, 19` | Buttons, inputs, tracks |
| `OutlineColor` | `28, 28, 28` | Borders and lines |
| `AccentColor` | `255, 151, 227` | Accent (Syde pink) |
| `FontColor` | `255, 255, 255` | Text |
| `RedColor` | `255, 101, 104` | Risky elements |

After changing values in `Library.Scheme` directly, call `Library:UpdateColorsUsingRegistry()` to apply them.

## Credits

- Layout and API based on [Obsidian](https://github.com/deividcomsono/Obsidian) by deivid
- Theme and style based on [Syde](https://github.com/essencejs/syde)
- Icons from [lucide](https://lucide.dev/) via [lucide-roblox-direct](https://github.com/mstudio45/lucide-roblox-direct)
