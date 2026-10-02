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
})

-- Window:AddTab(Name, Icon, Description)
-- Icons come from https://lucide.dev/
local Tabs = {
	Main = Window:AddTab("Main", "user", "Toggles, buttons and colors"),
	Visuals = Window:AddTab("Visuals", "eye", "Color pickers on labels"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings", "Menu options"),
}

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

--// UI Settings tab \\--
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddLabel("Menu accent"):AddColorPicker("MenuAccent", {
	Default = Library.Scheme.AccentColor,
	Title = "Accent color",
	Callback = function(Value)
		Library:SetAccent(Value) -- recolors the whole UI live
	end,
})

MenuGroup:AddLabel("Press RightControl to hide/show the menu", true)

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		Library:Unload()
	end,
})

Library:OnUnload(function()
	print("Unloaded!")
end)
