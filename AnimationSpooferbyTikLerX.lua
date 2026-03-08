local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AnimationWatcher"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.6, 0.15)
frame.Position = UDim2.fromScale(0.2, 0.05)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.2
frame.Parent = gui
frame.BorderSizePixel = 0

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local animLabel = Instance.new("TextButton")
animLabel.Size = UDim2.fromScale(1, 0.5)
animLabel.Position = UDim2.fromScale(0, 0)
animLabel.BackgroundTransparency = 1
animLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
animLabel.TextScaled = true
animLabel.Font = Enum.Font.GothamBold
animLabel.Text = "AnimationId: —"
animLabel.Parent = frame

local soundLabel = Instance.new("TextButton")
soundLabel.Size = UDim2.fromScale(1, 0.5)
soundLabel.Position = UDim2.fromScale(0, 0.5)
soundLabel.BackgroundTransparency = 1
soundLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
soundLabel.TextScaled = true
soundLabel.Font = Enum.Font.GothamBold
soundLabel.Text = "SoundId: —"
soundLabel.Parent = frame

local ignoredAnimations = {
	"walk", "run", "idle", "jump", "fall", "swim", "sit", "climb"
}

local function isIgnoredAnimation(track)
	if not track.Animation or not track.Animation.AnimationId then return true end
	local name = track.Name:lower()
	for _, keyword in ipairs(ignoredAnimations) do
		if name:find(keyword) then
			return true
		end
	end
	return false
end

local hookedSounds = {}

local function displaySound(soundId)
	if soundId and soundId ~= "" then
		soundLabel.Text = "SoundId:\n" .. soundId
	end
end

local function hookSound(sound)
	if not sound:IsA("Sound") then return end
	if hookedSounds[sound] then return end
	
	hookedSounds[sound] = true
	
	pcall(function()
		local oldPlay = sound.Play
		sound.Play = function(self, ...)
			displaySound(self.SoundId)
			return oldPlay(self, ...)
		end
	end)
	
	pcall(function()
		sound.Played:Connect(function()
			displaySound(sound.SoundId)
		end)
	end)
	
	pcall(function()
		sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
			if sound.IsPlaying then
				displaySound(sound.SoundId)
			end
		end)
	end)
	
	pcall(function()
		sound.Destroying:Connect(function()
			hookedSounds[sound] = nil
		end)
	end)
end

local function hookContainer(container)
	if not container then return end
	
	pcall(function()
		for _, desc in ipairs(container:GetDescendants()) do
			task.spawn(function()
				hookSound(desc)
			end)
		end
	end)
	
	pcall(function()
		container.DescendantAdded:Connect(function(desc)
			task.spawn(function()
				hookSound(desc)
			end)
		end)
	end)
end

local function hookCharacter(character)
	if not character then return end
	
	pcall(function()
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			local animator = humanoid:WaitForChild("Animator", 5)
			if animator then
				animator.AnimationPlayed:Connect(function(track)
					if track.Animation and track.Animation.AnimationId ~= "" and not isIgnoredAnimation(track) then
						animLabel.Text = "AnimationId:\n" .. track.Animation.AnimationId
					end
				end)
			end
		end
	end)
	
	hookContainer(character)
end

task.spawn(function()
	hookContainer(game.Workspace)
end)

task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if playerGui then
		hookContainer(playerGui)
	end
end)

task.spawn(function()
	local repStorage = game:GetService("ReplicatedStorage")
	hookContainer(repStorage)
end)

task.spawn(function()
	local soundService = game:GetService("SoundService")
	hookContainer(soundService)
end)

if player.Character then
	task.spawn(function()
		hookCharacter(player.Character)
	end)
end

player.CharacterAdded:Connect(function(character)
	task.spawn(function()
		hookCharacter(character)
	end)
end)

animLabel.MouseButton1Click:Connect(function()
	local text = animLabel.Text
	local id = text:match("rbxassetid://(%d+)") or text:match("(%d+)")
	if id then
		local fullId = "rbxassetid://" .. id
		pcall(function()
			setclipboard(fullId)
		end)
	end
end)

soundLabel.MouseButton1Click:Connect(function()
	local text = soundLabel.Text
	local id = text:match("rbxassetid://(%d+)") or text:match("(%d+)")
	if id then
		local fullId = "rbxassetid://" .. id
		pcall(function()
			setclipboard(fullId)
		end)
	end
end)