-- src/client/SoundDetectionSystem.client.luau
--!strict
-- SOUND DETECTION SYSTEM (Spider-Sense) – adapted for "Who Farted?"
-- Shows directional UI arrows for notable sounds (e.g. farts, explosions) while filtering mundane noises.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Settings)

-- Extract numeric id part from the sound asset url
local TARGET_ID = Settings.FartSoundId:match("%d+")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Create/hook ScreenGui once
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoundDetectionUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Container for arrows
local arrowContainer = Instance.new("Frame")
arrowContainer.Size = UDim2.new(1, 0, 1, 0)
arrowContainer.BackgroundTransparency = 1
arrowContainer.Parent = screenGui

-- Tracking tables
local soundSources: {[string]: {sound: Sound, position: Vector3}} = {}
local arrows: {[string]: Frame} = {}

local CONFIG = {
	MIN_DISTANCE = 5,
	MAX_DISTANCE = 100,
	MIN_ARROW_SIZE = 30,
	MAX_ARROW_SIZE = 80,
	ARROW_OFFSET = 100,
	FADE_SPEED = 0.25,
}

local BLACKLISTED_SOUNDS: {[string]: boolean} = {
	Running = true, Landing = true, Jumping = true, FreeFalling = true,
	Flying = true, Swimming = true, Climbing = true, GettingUp = true,
	walk = true, run = true, jump = true, footstep = true, footsteps = true,
	["rbxasset://sounds/action_footsteps_plastic.mp3"] = true,
	["rbxasset://sounds/action_jump.mp3"] = true,
	["rbxasset://sounds/action_jump_land.mp3"] = true,
	["rbxasset://sounds/impact_water_low.mp3"] = true,
	["rbxasset://sounds/action_swim.mp3"] = true,
	["rbxasset://sounds/action_falling.mp3"] = true,
	["rbxasset://sounds/action_get_up.mp3"] = true,
	["rbxasset://sounds/uuhhh.mp3"] = true,
}

local function shouldFilterSound(sound: Sound): boolean
	local soundNameLower = sound.Name:lower()
	for blacklisted, _ in pairs(BLACKLISTED_SOUNDS) do
		if soundNameLower:find(blacklisted:lower(), 1, true) then
			return true
		end
	end
	if sound.SoundId ~= "" and BLACKLISTED_SOUNDS[sound.SoundId] then
		return true
	end
	if sound.Parent and (sound.Parent.Name == "HumanoidRootPart" or sound.Parent:IsA("Humanoid")) then
		return true
	end
	if sound.Volume < 0.1 then
		return true
	end
	return false
end

local function createArrow(): Frame
	local arrowFrame = Instance.new("Frame")
	arrowFrame.Size = UDim2.fromOffset(50, 50)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)

	local arrowImage = Instance.new("ImageLabel")
	arrowImage.Size = UDim2.fromScale(1, 1)
	arrowImage.BackgroundTransparency = 1
	arrowImage.Image = "rbxassetid://6034684930" -- red arrow icon
	arrowImage.ImageColor3 = Color3.new(1, 0.2, 0.2)
	arrowImage.Parent = arrowFrame

	arrowFrame.Parent = arrowContainer
	return arrowFrame
end

local function calculateArrowPosition(soundPos: Vector3, charPos: Vector3)
	local dir = (soundPos - charPos).Unit
	local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)

	local forward = Vector2.new(camera.CFrame.LookVector.X, camera.CFrame.LookVector.Z).Unit
	local right = Vector2.new(camera.CFrame.RightVector.X, camera.CFrame.RightVector.Z).Unit
	local sound2D = Vector2.new(dir.X, dir.Z).Unit

	local angle = math.atan2(sound2D:Dot(right), sound2D:Dot(forward))
	local radius = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)/2 - CONFIG.ARROW_OFFSET
	local x = screenCenter.X + math.sin(angle)*radius
	local y = screenCenter.Y - math.cos(angle)*radius

	return Vector2.new(x, y), math.deg(angle)
end

local function updateArrow(sourceId: string, soundPos: Vector3, active: boolean)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dist = (soundPos - hrp.Position).Magnitude
	if dist < CONFIG.MIN_DISTANCE or dist > CONFIG.MAX_DISTANCE or not active then
		local arrow = arrows[sourceId]
		if arrow then
			local fade = TweenService:Create(arrow, TweenInfo.new(CONFIG.FADE_SPEED), {BackgroundTransparency = 1, Size = UDim2.fromOffset(0,0)})
			fade:Play()
			fade.Completed:Connect(function()
				arrow:Destroy(); arrows[sourceId]=nil
			end)
		end
		return
	end

	if not arrows[sourceId] then arrows[sourceId] = createArrow() end
	local arrow = arrows[sourceId]

	local pos2D, rot = calculateArrowPosition(soundPos, hrp.Position)
	local ratio = 1 - ((dist - CONFIG.MIN_DISTANCE)/(CONFIG.MAX_DISTANCE - CONFIG.MIN_DISTANCE))
	local size = CONFIG.MIN_ARROW_SIZE + (CONFIG.MAX_ARROW_SIZE - CONFIG.MIN_ARROW_SIZE)*ratio

	arrow.Position = UDim2.fromOffset(pos2D.X, pos2D.Y)
	arrow.Size = UDim2.fromOffset(size, size)
	arrow.Rotation = rot

	-- Update transparency based on distance
	local targetTransparency = 0.2 + (1 - ratio) * 0.5
	local imageLabel = arrow:FindFirstChild("ImageLabel")
	if imageLabel and imageLabel:IsA("ImageLabel") then
		imageLabel.ImageTransparency = targetTransparency
	else
		for _, child in pairs(arrow:GetDescendants()) do
			if child:IsA("Frame") then
				child.BackgroundTransparency = targetTransparency
			end
		end
	end
end

local function monitorSounds()
	local current: {[string]: {sound: Sound, position: Vector3}} = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Sound") and obj.IsPlaying then
			-- Only process fart sounds (by asset id)
			local idDigits = obj.SoundId and obj.SoundId:match("%d+") or ""
			if idDigits ~= TARGET_ID then
				continue
			end

			-- Filter out obvious movement/ambient sounds
			if shouldFilterSound(obj) then
				continue
			end
			local parent = obj.Parent
			if parent and not parent:IsA("BasePart") then
				if parent:IsA("Model") then
					parent = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
				end
			end
			if not parent or not parent:IsA("BasePart") then continue end
			local pos = parent.Position
			local id = string.format("%s_%s_%d", tostring(obj), obj.Name, parent:GetDebugId())
			current[id] = {sound=obj, position=pos}
		end
	end

	for id, _ in pairs(soundSources) do
		if not current[id] then
			soundSources[id] = nil
			updateArrow(id, Vector3.zero, false)
		end
	end
	for id, data in pairs(current) do
		soundSources[id] = data
		updateArrow(id, data.position, true)
	end
end

RunService.Heartbeat:Connect(monitorSounds)

player.CharacterRemoving:Connect(function()
	for _, arrow in pairs(arrows) do arrow:Destroy() end
	soundSources = {}; arrows = {}
end) 