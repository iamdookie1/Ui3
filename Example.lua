-- Ui3 example: Obsidian-style API with the Syde theme.
-- Swap the branch name for "main" once this is merged.

local repo = "https://raw.githubusercontent.com/iamdookie1/Ui3/ccr-26bcb4bb-7izgsr/"
local Library = loadstring(game:HttpGet(repo .. "Ui.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
	Title = "Ui3",
	Footer = "version: example",
	Icon = "sparkles", -- lucide icon name or an asset id
	Center = true,
	AutoShow = true,
	Resizable = true,
	ToggleKeybind = Enum.KeyCode.RightControl,
	-- DPIScale = 100, -- starting DPI in percent; players can change it in settings (saved in configs)
})

-- Window:AddTab(Name, Icon, Description)
-- Icons come from https://lucide.dev/
local Tabs = {
	Main = Window:AddTab("Main", "user", "Toggles, buttons, sliders and dropdowns"),
	Dashboard = Window:AddTab("Dashboard", "layout-dashboard", "Big groupboxes"),
	Visuals = Window:AddTab("Visuals", "eye", "Color pickers on labels"),
}

-- Menu keybind, DPI scale, configs (save / load / autoload) and Unload are already
-- in the settings panel: the gear icon in the top right corner. Nothing to build here.

--// Main tab \\--
local LeftGroupBox = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Groupbox",
	Description = "boxes",
	IconName = "boxes",
})

-- Groupbox:AddToggle(Index, Options)
LeftGroupBox:AddToggle("MyToggle", {
	Text = "This is a toggle",
	Default = true,
	Risky = false,

	Callback = function(Value)
		print("[cb] MyToggle changed to:", Value)
	end,
})
	:AddColorPicker("ColorPicker1", {
		Default = Color3.new(1, 0, 0),
		Title = "Some color1",
		Transparency = 0, -- enables the transparency bar

		Callback = function(Value, Transparency)
			print("[cb] Color changed!", Value, Transparency)
		end,
	})
	:AddColorPicker("ColorPicker2", {
		Default = Color3.new(0, 1, 0),
		Title = "Some color2",

		Callback = function(Value)
			print("[cb] Color changed!", Value)
		end,
	})

LeftGroupBox:AddToggle("RiskyToggle", {
	Text = "Risky toggle",
	Default = false,
	Risky = true,
})

LeftGroupBox:AddToggle("DisabledToggle", {
	Text = "Disabled toggle",
	Default = false,
	Disabled = true,
})

-- Recommended way to listen for changes:
Toggles.MyToggle:OnChanged(function()
	print("MyToggle changed to:", Toggles.MyToggle.Value)
end)

-- Groupbox:AddButton(Options)
local MyButton = LeftGroupBox:AddButton({
	Text = "Button",
	Func = function()
		print("You clicked a button!")
	end,
	DoubleClick = false,
})

-- Calling :AddButton on a button adds a sub button next to it
MyButton:AddButton({
	Text = "Sub button",
	Func = function()
		print("You clicked a sub button!")
	end,
	DoubleClick = true, -- click twice to confirm
})

LeftGroupBox:AddButton({
	Text = "Risky button",
	Risky = true,
	Func = function()
		print("Risky button pressed")
	end,
})

LeftGroupBox:AddDivider()

-- Groupbox:AddSlider(Index, Options)
LeftGroupBox:AddSlider("MySlider", {
	Text = "This is my slider!",
	Default = 0,
	Min = 0,
	Max = 5,
	Rounding = 1, -- decimal places
	Compact = false, -- true hides the separate value text

	Tooltip = "Click the number on the right to type a value",

	Callback = function(Value)
		print("[cb] MySlider was changed! New value:", Value)
	end,
})

LeftGroupBox:AddSlider("WalkSpeed", {
	Text = "Walk speed",
	Default = 16,
	Min = 0,
	Max = 200,
	Rounding = 0,
	Suffix = " studs",
	HideMax = true,
})

LeftGroupBox:AddSlider("CustomSlider", {
	Text = "Custom display",
	Default = 0,
	Min = 0,
	Max = 5,
	Rounding = 0,
	FormatDisplayValue = function(Slider, Value)
		if Value == Slider.Max then
			return "Everything"
		end
		if Value == Slider.Min then
			return "Nothing"
		end
		-- return nil to use the normal formatting
	end,
})

Options.MySlider:OnChanged(function()
	print("MySlider was changed! New value:", Options.MySlider.Value)
end)
Options.MySlider:SetValue(3)

local RightGroupBox = Tabs.Main:AddRightGroupbox("Another groupbox", "palette")

RightGroupBox:AddToggle("ESP", {
	Text = "ESP",
	Default = false,
}):AddColorPicker("ESPColor", {
	Default = Color3.fromRGB(255, 151, 227),
	Title = "ESP color",
})

RightGroupBox:AddToggle("Tracers", {
	Text = "Tracers",
	Default = false,
})

RightGroupBox:AddButton("Old style button", function()
	print("Buttons also accept (Text, Func)")
end)

Options.ESPColor:OnChanged(function()
	print("ESP color is now", Options.ESPColor.Value)
end)

--// Dropdowns \\--
local DropdownGroupBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "Dropdowns",
	IconName = "list",
})

-- Groupbox:AddDropdown(Index, Options)
DropdownGroupBox:AddDropdown("MyDropdown", {
	Values = { "This", "is", "a", "dropdown" },
	Default = 1, -- index of the value, or the value itself
	Multi = false,

	Text = "A dropdown",
	Tooltip = "This is a tooltip",

	Callback = function(Value)
		print("[cb] Dropdown got changed. New value:", Value)
	end,
})

Options.MyDropdown:OnChanged(function()
	print("Dropdown got changed. New value:", Options.MyDropdown.Value)
end)
Options.MyDropdown:SetValue("This")

DropdownGroupBox:AddDropdown("MySearchableDropdown", {
	Values = { "Apple", "Banana", "Cherry", "Grape", "Lemon", "Mango", "Orange", "Peach", "Pear", "Plum" },
	Default = "Mango",
	Searchable = true, -- adds a search box
	Text = "A searchable dropdown",
})

DropdownGroupBox:AddDropdown("MyMultiDropdown", {
	Values = { "This", "is", "a", "dropdown" },
	Default = 1,
	Multi = true, -- Value becomes { [value] = true }

	Text = "A multi dropdown",

	Callback = function(Value)
		print("[cb] Multi dropdown got changed:")
		for Key, Selected in Value do
			print(Key, Selected)
		end
	end,
})

Options.MyMultiDropdown:SetValue({
	This = true,
	is = true,
})

-- Dictionary values: keys are what you get in .Value, values are the labels shown
DropdownGroupBox:AddDropdown("MyDictionaryDropdown", {
	Values = {
		item01 = "Excalibur",
		item05 = "Aegis Shield",
		item06 = "Wooden Club",
	},
	Default = "item01",
	DisabledValues = { "item05" }, -- shown but can't be picked
	Text = "A dictionary dropdown",
})

DropdownGroupBox:AddDropdown("MyPlayerDropdown", {
	SpecialType = "Player", -- fills itself with players and stays up to date
	ExcludeLocalPlayer = true,
	Text = "A player dropdown",

	Callback = function(Value)
		print("[cb] Player dropdown got changed:", Value)
	end,
})

DropdownGroupBox:AddDropdown("MyDisabledDropdown", {
	Values = { "Can't", "touch", "this" },
	Default = 1,
	Disabled = true,
	Text = "A disabled dropdown",
})

--// Visuals tab \\--
local ColorBox = Tabs.Visuals:AddLeftGroupbox("Colors", "brush")

ColorBox:AddLabel("Highlight color"):AddColorPicker("HighlightColor", {
	Default = Color3.fromRGB(88, 141, 255),
	Title = "Highlight color",
	Transparency = 0.25,
})

ColorBox:AddLabel("Outline color"):AddColorPicker("OutlineColor", {
	Default = Color3.fromRGB(255, 255, 255),
})

-- Setting values from code
Options.OutlineColor:SetValueRGB(Color3.fromRGB(255, 101, 104))

--// Dashboard tab: big groupboxes span both columns \\--
local Overview = Tabs.Dashboard:AddBigGroupbox({
	Name = "Overview",
	Description = "Big groupboxes take the full width and unlock extra elements",
	IconName = "gauge",
})

-- Big groupbox only: stat cards
local Stats = Overview:AddStatCards("Stats", {
	Cards = {
		{ Title = "Kills", Value = 0, Icon = "swords" },
		{ Title = "Coins", Value = 1250, Icon = "coins" },
		{ Title = "Session", Value = "0m", Icon = "clock" },
	},
})

-- Big groupbox only: progress bar
local Progress = Overview:AddProgressBar("FarmProgress", {
	Text = "Auto farm progress",
	Default = 35,
	Max = 100,
	Percent = true, -- false shows "35 / 100" (+ Suffix) instead
})

Overview:AddButton({
	Text = "Add 10% progress",
	Func = function()
		Progress:SetValue(Progress.Value + 10)
		Stats:SetValue("Kills", Stats:GetValue("Kills") + 1)
	end,
}):AddButton({
	Text = "Reset",
	Func = function()
		Progress:SetValue(0)
		Stats:SetValue("Kills", 0)
	end,
})

-- Normal groupboxes after a big one start a new row of columns below it
local Movement = Tabs.Dashboard:AddLeftGroupbox("Movement", "footprints")

Movement:AddCheckbox("InfiniteJump", {
	Text = "Infinite jump",
	Default = false,
})

Movement:AddToggle("Fly", {
	Text = "Fly",
	Default = false,
	Tooltip = "Right click the keybind to change its mode",
}):AddKeyPicker("FlyKey", {
	Default = "F",
	Mode = "Toggle", -- Toggle / Hold / Always
	SyncToggleState = true, -- pressing F flips the toggle
	Text = "Fly",
	Callback = function(State)
		print("[cb] Fly key state:", State)
	end,
	ChangedCallback = function(NewKey)
		print("[cb] Fly key changed to:", NewKey)
	end,
})

Movement:AddLabel("Sprint (hold)"):AddKeyPicker("SprintKey", {
	Default = "LeftShift",
	Mode = "Hold",
	Text = "Sprint",
})

local Misc = Tabs.Dashboard:AddRightGroupbox("Misc", "wand-sparkles")

Misc:AddInput("WebhookName", {
	Text = "Display name",
	Default = "",
	Placeholder = "Type something...",
	Finished = false, -- true = only fires when you press enter
	Callback = function(Value)
		print("[cb] Input changed:", Value)
	end,
})

Misc:AddInput("TargetFPS", {
	Text = "Target FPS",
	Default = "60",
	Numeric = true,
	Finished = true,
	MaxLength = 3,
})

Misc:AddButton({
	Text = "Send notification",
	Func = function()
		Library:Notify({
			Title = "Hello!",
			Description = "Notifications slide in from the bottom right.",
			Time = 4,
		})
	end,
})

local Console = Tabs.Dashboard:AddBigGroupbox("Console", "terminal")

-- Big groupbox only: log / console
local Log = Console:AddLog("Log", {
	Height = 140,
	MaxLines = 200,
	Timestamps = true,
})

Log:Log("Script loaded")
Log:Log("Custom colored line", Color3.fromRGB(150, 200, 255))
Log:Log("Errors can be red", Color3.fromRGB(255, 101, 104))

Console:AddButton({
	Text = "Log something",
	Func = function()
		Log:Log("Clicked at " .. os.date("%H:%M:%S"))
	end,
}):AddButton({
	Text = "Clear",
	Func = function()
		Log:Clear()
	end,
})

local StartTime = os.clock()
task.spawn(function()
	while not Library.Unloaded do
		Stats:SetValue("Session", math.floor((os.clock() - StartTime) / 60) .. "m")
		task.wait(5)
	end
end)

Library:OnUnload(function()
	print("Unloaded!")
end)
