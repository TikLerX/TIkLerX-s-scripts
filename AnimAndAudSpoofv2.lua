local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AnimationWatcher"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.6, 0.2)
frame.Position = UDim2.fromScale(0.2, 0.05)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.2
frame.Parent = gui
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local animLabel = Instance.new("TextButton")
animLabel.Size = UDim2.fromScale(1, 0.4)
animLabel.Position = UDim2.fromScale(0, 0)
animLabel.BackgroundTransparency = 1
animLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
animLabel.TextScaled = true
animLabel.Font = Enum.Font.GothamBold
animLabel.Text = "AnimationId: —"
animLabel.Parent = frame

local soundLabel = Instance.new("TextButton")
soundLabel.Size = UDim2.fromScale(1, 0.4)
soundLabel.Position = UDim2.fromScale(0, 0.4)
soundLabel.BackgroundTransparency = 1
soundLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
soundLabel.TextScaled = true
soundLabel.Font = Enum.Font.GothamBold
soundLabel.Text = "SoundId: —"
soundLabel.Parent = frame

local downloadBtn = Instance.new("TextButton")
downloadBtn.Size = UDim2.fromScale(1, 0.2)
downloadBtn.Position = UDim2.fromScale(0, 0.8)
downloadBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
downloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
downloadBtn.TextScaled = true
downloadBtn.Font = Enum.Font.GothamBold
downloadBtn.Text = "⬇️ Download Animation"
downloadBtn.BorderSizePixel = 0
downloadBtn.Parent = frame
Instance.new("UICorner", downloadBtn).CornerRadius = UDim.new(0, 8)

local downloadSoundBtn = Instance.new("TextButton")
downloadSoundBtn.Size = UDim2.fromScale(1, 0.15)
downloadSoundBtn.Position = UDim2.fromScale(0, 1.05)
downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
downloadSoundBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
downloadSoundBtn.TextScaled = true
downloadSoundBtn.Font = Enum.Font.GothamBold
downloadSoundBtn.Text = "⬇️ Download Audio"
downloadSoundBtn.BorderSizePixel = 0
downloadSoundBtn.Parent = frame
Instance.new("UICorner", downloadSoundBtn).CornerRadius = UDim.new(0, 8)

local currentTrack = nil
local currentAnimId = nil
local currentSoundId = nil
local currentAudioPlayer = nil
local hookedSounds = {}

local ignoredAnimations = { "walk", "run", "idle", "jump", "fall", "swim", "sit", "climb" }

local function isIgnoredAnimation(track)
	if not track.Animation or not track.Animation.AnimationId then return true end
	local name = track.Name:lower()
	for _, kw in ipairs(ignoredAnimations) do
		if name:find(kw) then return true end
	end
	return false
end

local function cframeToXML(cf)
	local x, y, z,
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22 = cf:GetComponents()
	return string.format(
		"<X>%f</X><Y>%f</Y><Z>%f</Z>" ..
		"<R00>%f</R00><R01>%f</R01><R02>%f</R02>" ..
		"<R10>%f</R10><R11>%f</R11><R12>%f</R12>" ..
		"<R20>%f</R20><R21>%f</R21><R22>%f</R22>",
		x, y, z,
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22
	)
end

local function buildJointTree(character)
	local joints   = {}
	local childOf  = {}
	local isPart1  = {}

	for _, desc in pairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part0 and desc.Part1 then
			local p0 = desc.Part0
			local p1 = desc.Part1
			if p0:IsDescendantOf(character) and p1:IsDescendantOf(character) then
				joints[p1.Name]  = desc
				childOf[p1.Name] = p0.Name
				isPart1[p1.Name] = true
			end
		end
	end

	local children = {}
	for part1, part0 in pairs(childOf) do
		if not children[part0] then children[part0] = {} end
		table.insert(children[part0], part1)
	end

	local rootName = "HumanoidRootPart"
	for _, desc in pairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part0 and not isPart1[desc.Part0.Name] then
			rootName = desc.Part0.Name
			break
		end
	end

	return joints, children, rootName
end

local function writePoseTree(lines, partName, poseMap, children, refCounter)
	local ref = "POSE" .. refCounter[1]
	refCounter[1] = refCounter[1] + 1
	local cf = poseMap[partName] or CFrame.new()
	table.insert(lines, '<Item class="Pose" referent="' .. ref .. '">')
	table.insert(lines, '<Properties>')
	table.insert(lines, '<string name="Name">' .. partName .. '</string>')
	table.insert(lines, '<CoordinateFrame name="CFrame">' .. cframeToXML(cf) .. '</CoordinateFrame>')
	table.insert(lines, '<token name="EasingDirection">0</token>')
	table.insert(lines, '<token name="EasingStyle">0</token>')
	table.insert(lines, '<float name="Weight">1</float>')
	table.insert(lines, '</Properties>')
	if children[partName] then
		for _, childName in ipairs(children[partName]) do
			writePoseTree(lines, childName, poseMap, children, refCounter)
		end
	end
	table.insert(lines, '</Item>')
end

local function buildRbxmx(keyframesData, animName, looped, jointChildren, rootName)
	local lines = {}
	local refCounter = {1}
	print("Building .rbxmx | Root: " .. rootName .. " | Keyframes: " .. #keyframesData)
	table.insert(lines, '<?xml version="1.0" encoding="utf-8"?>')
	table.insert(lines, '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
	table.insert(lines, '<Item class="KeyframeSequence" referent="RBX0">')
	table.insert(lines, '<Properties>')
	table.insert(lines, '<bool name="Loop">' .. tostring(looped) .. '</bool>')
	table.insert(lines, '<string name="Name">' .. animName .. '</string>')
	table.insert(lines, '<token name="Priority">2</token>')
	table.insert(lines, '</Properties>')
	for i, kfData in ipairs(keyframesData) do
		table.insert(lines, '<Item class="Keyframe" referent="KF' .. i .. '">')
		table.insert(lines, '<Properties>')
		table.insert(lines, '<string name="Name">Keyframe</string>')
		table.insert(lines, '<float name="Time">' .. kfData.time .. '</float>')
		table.insert(lines, '</Properties>')
		writePoseTree(lines, rootName, kfData.poses, jointChildren, refCounter)
		table.insert(lines, '</Item>')
	end
	table.insert(lines, '</Item>')
	table.insert(lines, '</roblox>')
	return table.concat(lines, "\n")
end

local function sampleAnimation(track, animId, character)
	local id = animId:match("%d+") or "unknown"
	local joints, jointChildren, rootName = buildJointTree(character)
	local jointCount = 0
	for _ in pairs(joints) do jointCount = jointCount + 1 end
	if jointCount == 0 then
		print("❌ No Motor6D joints found")
		return nil
	end
	print("Root: " .. rootName .. " | Joints: " .. jointCount .. " | Waiting for loop start...")

	local duration = track.Length > 0 and track.Length or 3
	local sampleRate = 1 / 30

	local syncTimeout = duration + 1
	local syncStart = tick()
	local lastT = track.TimePosition
	local synced = false

	while tick() - syncStart < syncTimeout do
		task.wait()
		local t = track.TimePosition
		if lastT > (duration * 0.8) and t < sampleRate * 2 then
			synced = true
			break
		end
		if t < sampleRate then
			synced = true
			break
		end
		lastT = t
	end

	if synced then
		print("✅ Synced to loop start")
	else
		print("⚠️ Sync timeout — capturing from current position")
	end

	local keyframesData = {}
	local done = false
	local prevT = -1
	local loopCount = 0
	local firstPoses = nil

	local connection = game:GetService("RunService").RenderStepped:Connect(function()
		if done then return end
		if not track.IsPlaying then
			done = true
			return
		end

		local t = track.TimePosition

		if prevT >= 0 and t < prevT - (duration * 0.5) then
			loopCount = loopCount + 1
			if loopCount >= 1 then
				done = true
				return
			end
		end
		prevT = t

		if loopCount == 0 then
			local poses = {}
			poses[rootName] = CFrame.new()
			for partName, joint in pairs(joints) do
				local ok, cf = pcall(function() return joint.Transform end)
				poses[partName] = ok and cf or CFrame.new()
			end
			if not firstPoses and t < sampleRate * 2 then
				firstPoses = poses
			end
			table.insert(keyframesData, { time = t, poses = poses })
		end
	end)

	local waitStart = tick()
	while not done and tick() - waitStart < duration * 2 + 2 do
		task.wait(0.05)
	end
	connection:Disconnect()

	if #keyframesData == 0 then
		print("❌ No keyframes captured")
		return nil
	end

	local offset = keyframesData[1].time
	for _, kf in ipairs(keyframesData) do
		kf.time = math.max(0, kf.time - offset)
	end

	local loopStartPoses = firstPoses or keyframesData[1].poses
	table.insert(keyframesData, {
		time = duration,
		poses = loopStartPoses
	})

	local deduped = {}
	local lastTime = -1
	for _, kf in ipairs(keyframesData) do
		if kf.time - lastTime > 0.001 then
			table.insert(deduped, kf)
			lastTime = kf.time
		end
	end

	print("✅ Captured " .. #deduped .. " keyframes (loop-synced, seamless)")
	return deduped, id, jointChildren, rootName
end

local function downloadAnimation(animId, track)
	if not animId then
		print("❌ No animation detected yet")
		return
	end
	local id = animId:match("%d+") or "unknown"
	downloadBtn.Text = "⏳ Downloading..."
	downloadBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	task.spawn(function()
		local ok1, result = pcall(function()
			return game:GetService("InsertService"):LoadAsset(tonumber(id))
		end)
		if ok1 and result then
			local seq = result:FindFirstChildWhichIsA("KeyframeSequence", true)
			local target = seq or result
			local ok2, serialized = pcall(function() return serializeplaceormodel(target) end)
			if ok2 then
				writefile(id .. ".rbxmx", serialized)
				print("✅ Saved via InsertService: " .. id .. ".rbxmx")
				downloadBtn.Text = "✅ Saved: " .. id .. ".rbxmx"
				downloadBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
				result:Destroy()
				return
			end
			result:Destroy()
		end
		local ok3, seq2 = pcall(function() return game:GetObjects(animId)[1] end)
		if ok3 and seq2 then
			local ok4, serialized2 = pcall(function() return serializeplaceormodel(seq2) end)
			if ok4 then
				writefile(id .. ".rbxmx", serialized2)
				print("✅ Saved via GetObjects: " .. id .. ".rbxmx")
				downloadBtn.Text = "✅ Saved: " .. id .. ".rbxmx"
				downloadBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
				return
			end
		end
		print("⚠️ Public methods failed — sampling live animation...")
		if track and track.IsPlaying then
			local character = player.Character
			local keyframesData, animName, jointChildren, rootName =
				sampleAnimation(track, animId, character)
			if keyframesData then
				local xml = buildRbxmx(keyframesData, animName, track.Looped, jointChildren, rootName)
				local filename = id .. "_sampled.rbxmx"
				writefile(filename, xml)
				print("✅ Saved via sampling: " .. filename)
				downloadBtn.Text = "✅ Saved: " .. filename
				downloadBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
				return
			end
		else
			print("❌ Track not playing! Trigger the animation first, then click Download")
			downloadBtn.Text = "❌ Play anim first!"
			downloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			return
		end
		print("❌ All methods failed")
		downloadBtn.Text = "❌ Failed"
		downloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end)
end

local function displaySound(soundId, audioPlayerObj)
	if soundId and soundId ~= "" then
		currentSoundId = soundId
		currentAudioPlayer = audioPlayerObj or nil
		soundLabel.Text = "SoundId:\n" .. soundId
	end
end

local assetFuncs = {
	"getsynasset", "fisynasset", "getcustomasset",
	"getasset", "readasset", "get_syn_asset"
}

local function tryGetCachedAsset(id)
	for _, fname in ipairs(assetFuncs) do
		if getgenv()[fname] then
			local ok, path = pcall(getgenv()[fname], "rbxassetid://" .. id)
			if ok and path and path ~= "" then
				local ok2, data = pcall(readfile, path)
				if ok2 and data and #data > 100 then
					return data
				end
			end
		end
	end
	return nil
end

local function autoCapture(obj)
	if not (obj:IsA("AudioPlayer") or obj:IsA("Sound")) then return end
	task.spawn(function()
		task.wait(0.1)
		local id
		if obj:IsA("AudioPlayer") then
			id = obj.AssetId:match("%d+")
		else
			id = obj.SoundId:match("%d+")
		end
		if not id or id == "" then return end

		for _ = 1, 10 do
			local data = tryGetCachedAsset(id)
			if data then
				local filename = id .. ".mp3"
				writefile(filename, data)
				print("✅ Auto-captured audio: " .. filename)
				downloadSoundBtn.Text = "✅ Auto-saved: " .. id
				downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
				return
			end
			task.wait(0.3)
		end
	end)
end

local function hookAudioObject(obj)
	if hookedSounds[obj] then return end

	if obj:IsA("Sound") then
		hookedSounds[obj] = true
		if obj.IsPlaying and obj.SoundId ~= "" then
			displaySound(obj.SoundId)
		end
		pcall(function()
			obj:GetPropertyChangedSignal("IsPlaying"):Connect(function()
				if obj.IsPlaying and obj.SoundId ~= "" then
					displaySound(obj.SoundId)
					autoCapture(obj)
				end
			end)
		end)
		pcall(function()
			obj.Destroying:Connect(function() hookedSounds[obj] = nil end)
		end)

	elseif obj:IsA("AudioPlayer") then
		local isOurs = false
		local current = obj.Parent
		while current do
			if tostring(current.Name) == tostring(player.UserId) then
				isOurs = true
				break
			end
			current = current.Parent
		end
		if not isOurs then return end

		hookedSounds[obj] = true
		if obj.AssetId ~= "" then
			displaySound(obj.AssetId, obj)
			autoCapture(obj)
		end
		pcall(function()
			obj:GetPropertyChangedSignal("AssetId"):Connect(function()
				if obj.AssetId ~= "" then
					displaySound(obj.AssetId, obj)
					autoCapture(obj)
				end
			end)
		end)
		pcall(function()
			obj.Destroying:Connect(function() hookedSounds[obj] = nil end)
		end)
	end
end

local function hookContainer(container)
	if not container then return end
	pcall(function()
		for _, desc in ipairs(container:GetDescendants()) do
			hookAudioObject(desc)
		end
	end)
	pcall(function()
		container.DescendantAdded:Connect(function(desc)
			hookAudioObject(desc)
		end)
	end)
end

local function hookCharacter(character, trackAnimations)
	if not character then return end
	if trackAnimations then
		pcall(function()
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				local animator = humanoid:WaitForChild("Animator", 5)
				if animator then
					animator.AnimationPlayed:Connect(function(aTrack)
						if aTrack.Animation and aTrack.Animation.AnimationId ~= ""
							and not isIgnoredAnimation(aTrack) then
							currentTrack = aTrack
							currentAnimId = aTrack.Animation.AnimationId
							animLabel.Text = "AnimationId:\n" .. currentAnimId
							downloadBtn.Text = "⬇️ Download Animation"
							downloadBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
						end
					end)
				end
			end
		end)
	end
	hookContainer(character)
end

task.spawn(function() hookContainer(game.Workspace) end)
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui", 10)
	if pg then hookContainer(pg) end
end)
task.spawn(function() hookContainer(game:GetService("ReplicatedStorage")) end)
task.spawn(function()
	local ss = game:GetService("SoundService")
	hookContainer(ss)
	ss.DescendantAdded:Connect(function(desc)
		hookAudioObject(desc)
		autoCapture(desc)
	end)
end)
task.spawn(function()
	workspace.DescendantAdded:Connect(function(desc)
		autoCapture(desc)
	end)
end)

if player.Character then
	task.spawn(function() hookCharacter(player.Character, true) end)
end
player.CharacterAdded:Connect(function(character)
	task.spawn(function() hookCharacter(character, true) end)
end)

local function hookOtherPlayer(p)
	if p.Character then
		task.spawn(function() hookCharacter(p.Character, false) end)
	end
	p.CharacterAdded:Connect(function(character)
		task.spawn(function() hookCharacter(character, false) end)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= player then hookOtherPlayer(p) end
end
Players.PlayerAdded:Connect(function(p)
	if p ~= player then hookOtherPlayer(p) end
end)

downloadSoundBtn.MouseButton1Click:Connect(function()
	local text = soundLabel.Text
	local id = text:match("rbxassetid://(%d+)") or text:match("(%d+)")
	if not id then
		print("❌ No sound detected yet")
		return
	end

	downloadSoundBtn.Text = "⏳ Capturing..."
	downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

	task.spawn(function()
		local filename = id .. ".mp3"
		local assetUri = "rbxassetid://" .. id

		local data1 = tryGetCachedAsset(id)
		if data1 then
			writefile(filename, data1)
			print("✅ Saved from cache: " .. filename)
			downloadSoundBtn.Text = "✅ Saved: " .. filename
			downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
			return
		end

		if currentAudioPlayer and currentAudioPlayer.Parent then
			local cachedId = currentAudioPlayer.AssetId:match("%d+")
			if cachedId then
				local data2 = tryGetCachedAsset(cachedId)
				if data2 then
					writefile(filename, data2)
					print("✅ Saved from AudioPlayer cache: " .. filename)
					downloadSoundBtn.Text = "✅ Saved: " .. filename
					downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
					return
				end
			end
		end

		local tempSound = Instance.new("Sound")
		tempSound.SoundId = assetUri
		tempSound.Volume = 0
		tempSound.Parent = game:GetService("SoundService")
		tempSound:Play()
		task.wait(2.5)

		local data3 = tryGetCachedAsset(id)
		if data3 then
			writefile(filename, data3)
			tempSound:Destroy()
			print("✅ Saved after force-play: " .. filename)
			downloadSoundBtn.Text = "✅ Saved: " .. filename
			downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
			return
		end

		local ok4 = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({tempSound})
		end)
		if ok4 then
			local data4 = tryGetCachedAsset(id)
			if data4 then
				writefile(filename, data4)
				tempSound:Destroy()
				print("✅ Saved after PreloadAsync: " .. filename)
				downloadSoundBtn.Text = "✅ Saved: " .. filename
				downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
				return
			end
		end
		tempSound:Destroy()

		local httpFunc = request or http_request or (syn and syn.request) or nil
		if httpFunc then
			local ok5, result5 = pcall(function()
				local res = httpFunc({
					Url = "https://assetdelivery.roblox.com/v2/assetId/" .. id,
					Method = "GET",
					Headers = {
						["Roblox-Place-Id"] = tostring(game.PlaceId),
						["Roblox-Game-Id"]  = tostring(game.GameId),
					}
				})
				if res.StatusCode == 200 then
					local json = game:GetService("HttpService"):JSONDecode(res.Body)
					local loc = json.locations and json.locations[1] and json.locations[1].location
					if loc then
						local audio = httpFunc({ Url = loc, Method = "GET" })
						if audio.StatusCode == 200 and #audio.Body > 100 then
							return audio.Body
						end
					end
				end
			end)
			if ok5 and result5 and #result5 > 100 then
				writefile(filename, result5)
				print("✅ Saved via request(): " .. filename)
				downloadSoundBtn.Text = "✅ Saved: " .. filename
				downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
				return
			end

			local ok6, result6 = pcall(function()
				local res = httpFunc({
					Url = "https://assetdelivery.roblox.com/v1/asset/?id=" .. id,
					Method = "GET",
					Headers = { ["Roblox-Place-Id"] = tostring(game.PlaceId) }
				})
				if res.StatusCode == 200 and #res.Body > 100 then
					return res.Body
				end
			end)
			if ok6 and result6 and #result6 > 100 then
				writefile(filename, result6)
				print("✅ Saved via v1 delivery: " .. filename)
				downloadSoundBtn.Text = "✅ Saved: " .. filename
				downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
				return
			end
		end

		print("❌ Audio is fully encrypted — use VB-Cable + Audacity to record it")
		downloadSoundBtn.Text = "❌ Use loopback recorder"
		downloadSoundBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end)
end)

animLabel.MouseButton1Click:Connect(function()
	local text = animLabel.Text
	local id = text:match("rbxassetid://(%d+)") or text:match("(%d+)")
	if id then
		pcall(function() setclipboard("rbxassetid://" .. id) end)
		print("📋 Copied: rbxassetid://" .. id)
	end
end)

soundLabel.MouseButton1Click:Connect(function()
	local text = soundLabel.Text
	local id = text:match("rbxassetid://(%d+)") or text:match("(%d+)")
	if id then
		pcall(function() setclipboard("rbxassetid://" .. id) end)
		print("📋 Copied: rbxassetid://" .. id)
	end
end)

downloadBtn.MouseButton1Click:Connect(function()
	downloadAnimation(currentAnimId, currentTrack)
end)
