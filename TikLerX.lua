--// Preventing Multiple Processes

pcall(function()
	getgenv().Aimbot.Functions:Exit()
end)

--// Environment

getgenv().Aimbot = {}
local Environment = getgenv().Aimbot

--// Services

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Camera = game:GetService("Workspace").CurrentCamera

--// Variables

local LocalPlayer = Players.LocalPlayer
local Title = "TikLerX Developer"
local FileNames = {"Aimbot", "Configuration.json", "Drawing.json"}
local Typing, Running, Animation, RequiredDistance, ServiceConnections = false, false, nil, 2000, {}

--// Support Functions

local mousemoverel = mousemoverel or (Input and Input.MouseMove)
local queueonteleport = queue_on_teleport or (syn and syn.queue_on_teleport)

--// Script Settings

Environment.Settings = {
	SendNotifications = false,
	SaveSettings = true,
	ReloadOnTeleport = true,
	Enabled = true,
	TeamCheck = false,
	AliveCheck = true,
	WallCheck = false,
	Sensitivity = 0,
	ThirdPerson = false,
	ThirdPersonSensitivity = 3,
	TriggerKey = "MouseButton2",
	Toggle = false,
	LockPart = "Head"
}

Environment.FOVSettings = {
	Enabled = true,
	Visible = false,
	Amount = 90,
	Color = "255, 255, 255",
	LockedColor = "255, 70, 70",
	Transparency = 1,
	Sides = 60,
	Thickness = 1,
	Filled = false
}

Environment.FOVCircle = Drawing.new("Circle")
Environment.Locked = nil

--// Chams Settings

Environment.ChamsSettings = {
	Enabled = false,
	FillColor = Color3.fromRGB(255, 0, 0),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.5,
	OutlineTransparency = 0,
	TeamCheck = false,
}

local ChamsHighlights = {}

--// Core Functions

local function Encode(Table)
	if Table and type(Table) == "table" then
		return HttpService:JSONEncode(Table)
	end
end

local function Decode(String)
	if String and type(String) == "string" then
		return HttpService:JSONDecode(String)
	end
end

local function GetColor(Color)
	local R = tonumber(string.match(Color, "([%d]+)[%s]*,[%s]*[%d]+[%s]*,[%s]*[%d]+"))
	local G = tonumber(string.match(Color, "[%d]+[%s]*,[%s]*([%d]+)[%s]*,[%s]*[%d]+"))
	local B = tonumber(string.match(Color, "[%d]+[%s]*,[%s]*[%d]+[%s]*,[%s]*([%d]+)"))
	return Color3.fromRGB(R, G, B)
end

local function SendNotification(TitleArg, DescriptionArg, DurationArg)
	if Environment.Settings.SendNotifications then
		StarterGui:SetCore("SendNotification", {
			Title = TitleArg,
			Text = DescriptionArg,
			Duration = DurationArg
		})
	end
end

--// Chams Functions

local function CreateChams(player)
	if player == LocalPlayer then return end
	if ChamsHighlights[player] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Environment.ChamsSettings.FillColor
	highlight.OutlineColor = Environment.ChamsSettings.OutlineColor
	highlight.FillTransparency = Environment.ChamsSettings.FillTransparency
	highlight.OutlineTransparency = Environment.ChamsSettings.OutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = Environment.ChamsSettings.Enabled

	if player.Character then
		highlight.Parent = player.Character
	end

	ChamsHighlights[player] = highlight

	player.CharacterAdded:Connect(function(char)
		highlight.Parent = char
	end)
end

local function RemoveChams(player)
	if ChamsHighlights[player] then
		ChamsHighlights[player]:Destroy()
		ChamsHighlights[player] = nil
	end
end

local function UpdateAllChams()
	for player, highlight in pairs(ChamsHighlights) do
		local isTeammate = player.Team == LocalPlayer.Team
		if Environment.ChamsSettings.TeamCheck and isTeammate then
			highlight.Enabled = false
		else
			highlight.Enabled = Environment.ChamsSettings.Enabled
		end
		highlight.FillColor = Environment.ChamsSettings.FillColor
		highlight.OutlineColor = Environment.ChamsSettings.OutlineColor
		highlight.FillTransparency = Environment.ChamsSettings.FillTransparency
		highlight.OutlineTransparency = Environment.ChamsSettings.OutlineTransparency
	end
end



local function SaveSettings()
	if Environment.Settings.SaveSettings then
		if isfile(Title.."/"..FileNames[1].."/"..FileNames[2]) then
			writefile(Title.."/"..FileNames[1].."/"..FileNames[2], Encode(Environment.Settings))
		end
		if isfile(Title.."/"..FileNames[1].."/"..FileNames[3]) then
			writefile(Title.."/"..FileNames[1].."/"..FileNames[3], Encode(Environment.FOVSettings))
		end
	end
end

if Environment.Settings.SaveSettings then
	if not isfolder(Title) then makefolder(Title) end
	if not isfolder(Title.."/"..FileNames[1]) then makefolder(Title.."/"..FileNames[1]) end

	if not isfile(Title.."/"..FileNames[1].."/"..FileNames[2]) then
		writefile(Title.."/"..FileNames[1].."/"..FileNames[2], Encode(Environment.Settings))
	else
		Environment.Settings = Decode(readfile(Title.."/"..FileNames[1].."/"..FileNames[2]))
	end

	if not isfile(Title.."/"..FileNames[1].."/"..FileNames[3]) then
		writefile(Title.."/"..FileNames[1].."/"..FileNames[3], Encode(Environment.FOVSettings))
	else
		Environment.FOVSettings = Decode(readfile(Title.."/"..FileNames[1].."/"..FileNames[3]))
	end

	coroutine.wrap(function()
		while wait(10) and Environment.Settings.SaveSettings do
			SaveSettings()
		end
	end)()
else
	if isfolder(Title) then delfolder(Title) end
end

--// Get Closest Player

local function GetClosestPlayer()
	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000

		for _, v in next, Players:GetPlayers() do
			if v ~= LocalPlayer then
				if v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
					if Environment.Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
					if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
					if Environment.Settings.WallCheck and #(Camera:GetPartsObscuringTarget({v.Character[Environment.Settings.LockPart].Position}, v.Character:GetDescendants())) > 0 then continue end

					local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
					local Distance = (Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2.new(Vector.X, Vector.Y)).Magnitude

					if Distance < RequiredDistance and OnScreen then
						RequiredDistance = Distance
						Environment.Locked = v
					end
				end
			end
		end
	elseif (Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2.new(Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position).X, Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position).Y)).Magnitude > RequiredDistance then
		Environment.Locked = nil
		if Animation then Animation:Cancel() end
		Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
	end
end

--// Typing Check

ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
	Typing = true
end)

ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
	Typing = false
end)

--// Support Check

if not Drawing or not getgenv then
	SendNotification(Title, "Your exploit does not support this script", 3); return
end

--// Load Rayfield

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "TikLerX's script",
	Icon = 0,
	LoadingTitle = "TikLerX's script",
	LoadingSubtitle = "Loading GUI...",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = false,
	},
	Discord = {
		Enabled = false,
	},
	KeySystem = false,
})

--// ─── TAB: Aimbot ─────────────────────────────────────────────

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

AimbotTab:CreateToggle({
	Name = "Enabled",
	CurrentValue = Environment.Settings.Enabled,
	Flag = "Enabled",
	Callback = function(Value)
		Environment.Settings.Enabled = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "Toggle Mode (Hold = Off)",
	CurrentValue = Environment.Settings.Toggle,
	Flag = "Toggle",
	Callback = function(Value)
		Environment.Settings.Toggle = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "Team Check",
	CurrentValue = Environment.Settings.TeamCheck,
	Flag = "TeamCheck",
	Callback = function(Value)
		Environment.Settings.TeamCheck = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "Alive Check",
	CurrentValue = Environment.Settings.AliveCheck,
	Flag = "AliveCheck",
	Callback = function(Value)
		Environment.Settings.AliveCheck = Value
	end,
})

AimbotTab:CreateToggle({
	Name = "Wall Check (Laggy)",
	CurrentValue = Environment.Settings.WallCheck,
	Flag = "WallCheck",
	Callback = function(Value)
		Environment.Settings.WallCheck = Value
	end,
})

AimbotTab:CreateSlider({
	Name = "Sensitivity (0 = instant)",
	Range = {0, 2},
	Increment = 0.05,
	Suffix = "s",
	CurrentValue = Environment.Settings.Sensitivity,
	Flag = "Sensitivity",
	Callback = function(Value)
		Environment.Settings.Sensitivity = Value
	end,
})

AimbotTab:CreateDropdown({
	Name = "Lock Part",
	Options = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"},
	CurrentOption = {Environment.Settings.LockPart},
	MultipleOptions = false,
	Flag = "LockPart",
	Callback = function(Option)
		Environment.Settings.LockPart = Option[1]
	end,
})

AimbotTab:CreateDropdown({
	Name = "Trigger Key",
	Options = {"MouseButton2", "MouseButton1", "E", "Q", "F", "V", "X", "Z", "C", "LeftAlt", "RightAlt", "LeftControl", "RightControl", "LeftShift", "RightShift"},
	CurrentOption = {Environment.Settings.TriggerKey},
	MultipleOptions = false,
	Flag = "TriggerKey",
	Callback = function(Option)
		Environment.Settings.TriggerKey = Option[1]
	end,
})

--// ─── TAB: FOV ─────────────────────────────────────────────

local FOVTab = Window:CreateTab("FOV Circle", 4483362458)

FOVTab:CreateToggle({
	Name = "FOV Enabled",
	CurrentValue = Environment.FOVSettings.Enabled,
	Flag = "FOVEnabled",
	Callback = function(Value)
		Environment.FOVSettings.Enabled = Value
	end,
})

FOVTab:CreateToggle({
	Name = "FOV Visible",
	CurrentValue = Environment.FOVSettings.Visible,
	Flag = "FOVVisible",
	Callback = function(Value)
		Environment.FOVSettings.Visible = Value
	end,
})

FOVTab:CreateToggle({
	Name = "FOV Filled",
	CurrentValue = Environment.FOVSettings.Filled,
	Flag = "FOVFilled",
	Callback = function(Value)
		Environment.FOVSettings.Filled = Value
	end,
})

FOVTab:CreateSlider({
	Name = "FOV Amount",
	Range = {10, 800},
	Increment = 5,
	Suffix = "px",
	CurrentValue = Environment.FOVSettings.Amount,
	Flag = "FOVAmount",
	Callback = function(Value)
		Environment.FOVSettings.Amount = Value
	end,
})

FOVTab:CreateSlider({
	Name = "FOV Thickness",
	Range = {1, 5},
	Increment = 1,
	Suffix = "",
	CurrentValue = Environment.FOVSettings.Thickness,
	Flag = "FOVThickness",
	Callback = function(Value)
		Environment.FOVSettings.Thickness = Value
	end,
})

FOVTab:CreateSlider({
	Name = "FOV Sides (Smoothness)",
	Range = {3, 100},
	Increment = 1,
	Suffix = "",
	CurrentValue = Environment.FOVSettings.Sides,
	Flag = "FOVSides",
	Callback = function(Value)
		Environment.FOVSettings.Sides = Value
	end,
})

FOVTab:CreateSlider({
	Name = "FOV Transparency",
	Range = {0, 1},
	Increment = 0.05,
	Suffix = "",
	CurrentValue = Environment.FOVSettings.Transparency,
	Flag = "FOVTransparency",
	Callback = function(Value)
		Environment.FOVSettings.Transparency = Value
	end,
})

--// ─── TAB: Chams (ESP) ───────────────────────────────────────

local ChamsTab = Window:CreateTab("Chams", 4483362458)

ChamsTab:CreateToggle({
	Name = "Enable Chams",
	CurrentValue = Environment.ChamsSettings.Enabled,
	Flag = "ChamsEnabled",
	Callback = function(Value)
		Environment.ChamsSettings.Enabled = Value
		UpdateAllChams()
	end,
})

ChamsTab:CreateToggle({
	Name = "Team Check (hide teammates)",
	CurrentValue = Environment.ChamsSettings.TeamCheck,
	Flag = "ChamsTeamCheck",
	Callback = function(Value)
		Environment.ChamsSettings.TeamCheck = Value
		UpdateAllChams()
	end,
})

ChamsTab:CreateLabel("Fill Color")

ChamsTab:CreateSlider({
	Name = "Fill Red",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 255,
	Flag = "ChamsFillR",
	Callback = function(Value)
		local c = Environment.ChamsSettings.FillColor
		Environment.ChamsSettings.FillColor = Color3.fromRGB(Value, c.G * 255, c.B * 255)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Fill Green",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 0,
	Flag = "ChamsFillG",
	Callback = function(Value)
		local c = Environment.ChamsSettings.FillColor
		Environment.ChamsSettings.FillColor = Color3.fromRGB(c.R * 255, Value, c.B * 255)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Fill Blue",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 0,
	Flag = "ChamsFillB",
	Callback = function(Value)
		local c = Environment.ChamsSettings.FillColor
		Environment.ChamsSettings.FillColor = Color3.fromRGB(c.R * 255, c.G * 255, Value)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Fill Transparency",
	Range = {0, 100},
	Increment = 1,
	Suffix = "%",
	CurrentValue = 50,
	Flag = "ChamsFillTransparency",
	Callback = function(Value)
		Environment.ChamsSettings.FillTransparency = Value / 100
		UpdateAllChams()
	end,
})

ChamsTab:CreateLabel("Outline Color")

ChamsTab:CreateSlider({
	Name = "Outline Red",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 255,
	Flag = "ChamsOutlineR",
	Callback = function(Value)
		local c = Environment.ChamsSettings.OutlineColor
		Environment.ChamsSettings.OutlineColor = Color3.fromRGB(Value, c.G * 255, c.B * 255)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Outline Green",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 255,
	Flag = "ChamsOutlineG",
	Callback = function(Value)
		local c = Environment.ChamsSettings.OutlineColor
		Environment.ChamsSettings.OutlineColor = Color3.fromRGB(c.R * 255, Value, c.B * 255)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Outline Blue",
	Range = {0, 255},
	Increment = 1,
	Suffix = "",
	CurrentValue = 255,
	Flag = "ChamsOutlineB",
	Callback = function(Value)
		local c = Environment.ChamsSettings.OutlineColor
		Environment.ChamsSettings.OutlineColor = Color3.fromRGB(c.R * 255, c.G * 255, Value)
		UpdateAllChams()
	end,
})

ChamsTab:CreateSlider({
	Name = "Outline Transparency",
	Range = {0, 100},
	Increment = 1,
	Suffix = "%",
	CurrentValue = 0,
	Flag = "ChamsOutlineTransparency",
	Callback = function(Value)
		Environment.ChamsSettings.OutlineTransparency = Value / 100
		UpdateAllChams()
	end,
})

-- Init chams for existing players
for _, player in ipairs(Players:GetPlayers()) do
	CreateChams(player)
end

Players.PlayerAdded:Connect(CreateChams)
Players.PlayerRemoving:Connect(RemoveChams)

--// ─── TAB: Misc ─────────────────────────────────────────────

local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateToggle({
	Name = "Send Notifications",
	CurrentValue = Environment.Settings.SendNotifications,
	Flag = "SendNotifications",
	Callback = function(Value)
		Environment.Settings.SendNotifications = Value
	end,
})

MiscTab:CreateToggle({
	Name = "Save Settings",
	CurrentValue = Environment.Settings.SaveSettings,
	Flag = "SaveSettings",
	Callback = function(Value)
		Environment.Settings.SaveSettings = Value
	end,
})

MiscTab:CreateToggle({
	Name = "Reload On Teleport",
	CurrentValue = Environment.Settings.ReloadOnTeleport,
	Flag = "ReloadOnTeleport",
	Callback = function(Value)
		Environment.Settings.ReloadOnTeleport = Value
	end,
})

MiscTab:CreateButton({
	Name = "Save Settings Now",
	Callback = function()
		SaveSettings()
		Rayfield:Notify({
			Title = "Saved",
			Content = "Settings saved successfully.",
			Duration = 3,
		})
	end,
})

MiscTab:CreateButton({
	Name = "Reset Settings",
	Callback = function()
		Environment.Functions:ResetSettings()
		Rayfield:Notify({
			Title = "Reset",
			Content = "Settings have been reset to default.",
			Duration = 3,
		})
	end,
})

MiscTab:CreateButton({
	Name = "Restart Script",
	Callback = function()
		Environment.Functions:Restart()
		Rayfield:Notify({
			Title = "Restarted",
			Content = "Script connections restarted.",
			Duration = 3,
		})
	end,
})

MiscTab:CreateLabel("Press CTRL to show/hide this GUI")

--// ─── GUI Toggle with CTRL ─────────────────────────────────

local GUIVisible = true

ServiceConnections.GUIToggleConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then return end
	if Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.RightControl then
		GUIVisible = not GUIVisible
		Rayfield:SetWindowVisibility(GUIVisible)
	end
end)

--// ─── Main Loop ─────────────────────────────────────────────

local function Load()
	ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
		if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
			Environment.FOVCircle.Radius = Environment.FOVSettings.Amount
			Environment.FOVCircle.Thickness = Environment.FOVSettings.Thickness
			Environment.FOVCircle.Filled = Environment.FOVSettings.Filled
			Environment.FOVCircle.NumSides = Environment.FOVSettings.Sides
			Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
			Environment.FOVCircle.Transparency = Environment.FOVSettings.Transparency
			Environment.FOVCircle.Visible = Environment.FOVSettings.Visible
			Environment.FOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		else
			Environment.FOVCircle.Visible = false
		end

		if Running and Environment.Settings.Enabled then
			GetClosestPlayer()

			if Environment.Locked then
				if Environment.Settings.ThirdPerson then
					Environment.Settings.ThirdPersonSensitivity = math.clamp(Environment.Settings.ThirdPersonSensitivity, 0.1, 5)
					local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
					mousemoverel(
						(Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity,
						(Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity
					)
				else
					if Environment.Settings.Sensitivity > 0 then
						Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
							CFrame = CFrame.new(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
						})
						Animation:Play()
					else
						Camera.CFrame = CFrame.new(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
					end
				end

				Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.LockedColor)
			end
		end
	end)

	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
		if not Typing then
			pcall(function()
				if Input.KeyCode == Enum.KeyCode[Environment.Settings.TriggerKey] then
					if Environment.Settings.Toggle then
						Running = not Running
						if not Running then
							Environment.Locked = nil
							if Animation then Animation:Cancel() end
							Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
						end
					else
						Running = true
					end
				end
			end)

			pcall(function()
				if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
					if Environment.Settings.Toggle then
						Running = not Running
						if not Running then
							Environment.Locked = nil
							if Animation then Animation:Cancel() end
							Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
						end
					else
						Running = true
					end
				end
			end)
		end
	end)

	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
		if not Typing then
			pcall(function()
				if Input.KeyCode == Enum.KeyCode[Environment.Settings.TriggerKey] then
					if not Environment.Settings.Toggle then
						Running = false
						Environment.Locked = nil
						if Animation then Animation:Cancel() end
						Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
					end
				end
			end)

			pcall(function()
				if Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
					if not Environment.Settings.Toggle then
						Running = false
						Environment.Locked = nil
						if Animation then Animation:Cancel() end
						Environment.FOVCircle.Color = GetColor(Environment.FOVSettings.Color)
					end
				end
			end)
		end
	end)
end

--// Functions

Environment.Functions = {}

function Environment.Functions:Exit()
	SaveSettings()
	for _, v in next, ServiceConnections do
		v:Disconnect()
	end
	if Environment.FOVCircle.Remove then Environment.FOVCircle:Remove() end
	getgenv().Aimbot.Functions = nil
	getgenv().Aimbot = nil
end

function Environment.Functions:Restart()
	SaveSettings()
	for i, v in next, ServiceConnections do
		if i ~= "TypingStartedConnection" and i ~= "TypingEndedConnection" and i ~= "GUIToggleConnection" then
			v:Disconnect()
		end
	end
	Load()
end

function Environment.Functions:ResetSettings()
	Environment.Settings = {
		SendNotifications = false,
		SaveSettings = true,
		ReloadOnTeleport = true,
		Enabled = true,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		Sensitivity = 0,
		ThirdPerson = false,
		ThirdPersonSensitivity = 3,
		TriggerKey = "MouseButton2",
		Toggle = false,
		LockPart = "Head"
	}
	Environment.FOVSettings = {
		Enabled = true,
		Visible = false,
		Amount = 90,
		Color = "255, 255, 255",
		LockedColor = "255, 70, 70",
		Transparency = 1,
		Sides = 60,
		Thickness = 1,
		Filled = false
	}
end

--// Reload On Teleport

if Environment.Settings.ReloadOnTeleport then
	if queueonteleport then
		queueonteleport(game:HttpGet("https://raw.githubusercontent.com/Exunys/Aimbot-V2/main/Resources/Scripts/Main.lua"))
	else
		SendNotification(Title, "Your exploit does not support \"syn.queue_on_teleport()\"")
	end
end

--// Load

Load()
