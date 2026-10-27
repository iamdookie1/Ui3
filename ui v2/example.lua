-- Velvet (ui v2) example: every element once.
local Velvet = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui3/ccr-b876c2c8-jpnoy1/ui%20v2/ui.lua"))()

local Window = Velvet:CreateWindow({
    Title = "Velvet",
    Subtitle = "Hub",
    Footer = "v2.0",
    Keybind = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab("Main", { Description = "Movement and player options." })
local Visuals = Window:AddTab("Visuals", { Description = "Colors and overlays." })
local Settings = Window:AddTab("Settings", { Description = "Menu and config options." })

--// Main \\--
local Movement = Main:AddSection("Movement", "Left")
Movement:AddToggle("Fly", { Text = "Fly", Description = "Toggle flight mode", Default = false })
Movement:AddToggle("Noclip", { Text = "Noclip", Description = "Walk through objects", Default = true })
Movement:AddSlider("WalkSpeed", { Text = "Walk speed", Min = 16, Max = 200, Default = 16 })
Movement:AddSlider("JumpPower", { Text = "Jump power", Min = 0, Max = 150, Default = 50, Rounding = 1 })
Movement:AddKeybind("FlyKey", {
    Text = "Fly key",
    Default = Enum.KeyCode.F,
    Callback = function()
        Velvet.Flags.Fly:Set(not Velvet.Flags.Fly.Value)
    end,
})

local Player = Main:AddSection("Player", "Right")
Player:AddDropdown("Team", { Text = "Team", Values = { "Red", "Blue", "Green" }, Default = "Red" })
Player:AddDropdown("Extras", { Text = "Extras", Values = { "Shield", "Boost", "Glide", "Dash" }, Multi = true })
Player:AddInput("Nickname", { Text = "Nickname", Placeholder = "Enter a name" })
Player:AddDivider("Actions")
Player:AddButton({ Text = "Respawn", Callback = function() print("respawn") end })
Player:AddButton({ Text = "Apply", Primary = true, Callback = function()
    Velvet:Notify({ Title = "Applied", Text = "Your settings are active.", Duration = 3 })
end })

--// Visuals \\--
local Esp = Visuals:AddSection("Overlay", "Left")
Esp:AddToggle("Esp", { Text = "ESP", Description = "Show player outlines" })
Esp:AddColorPicker("EspColor", { Text = "Outline color", Default = Color3.fromRGB(234, 146, 194) })
Esp:AddSlider("EspRange", { Text = "Range", Min = 50, Max = 2000, Default = 500, Suffix = " studs" })

local Info = Visuals:AddSection("Info", "Right")
Info:AddParagraph({ Title = "Tip", Text = "Colors update live while you drag the picker." })
Info:AddLabel("Press RightShift to hide the menu.")

--// Settings \\--
local Menu = Settings:AddSection("Menu", "Left")
Menu:AddKeybind("MenuKey", {
    Text = "Menu key",
    Default = Enum.KeyCode.RightShift,
    ChangedCallback = function(key)
        if key then
            Window:SetKeybind(key)
        end
    end,
})
Menu:AddButton({ Text = "Unload", Callback = function() Velvet:Unload() end })

local Configs = Settings:AddSection("Configs", "Right")
Configs:AddInput("ConfigName", { Text = "Name", Placeholder = "default" })
Configs:AddButton({ Text = "Save", Primary = true, Callback = function()
    local name = Velvet.Flags.ConfigName.Value ~= "" and Velvet.Flags.ConfigName.Value or "default"
    local ok, err = Velvet:SaveConfig(name)
    Velvet:Notify({ Title = ok and "Saved" or "Couldn't save", Text = ok and name or err })
end })
Configs:AddButton({ Text = "Load", Callback = function()
    local name = Velvet.Flags.ConfigName.Value ~= "" and Velvet.Flags.ConfigName.Value or "default"
    local ok, err = Velvet:LoadConfig(name)
    Velvet:Notify({ Title = ok and "Loaded" or "Couldn't load", Text = ok and name or err })
end })

Velvet.Flags.WalkSpeed:OnChanged(function(value)
    print("walk speed:", value)
end)

Velvet:Notify({ Title = "Velvet loaded", Text = "Welcome back!", Duration = 4 })
