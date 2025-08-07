-- src/client/EffectsController.client.luau
-- Handles all sensory feedback including visual and audio effects
-- This includes fart sounds, spider-sense effects, and other visual feedback

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

-- Track the local player's role so we can decide whether to show directional cues
local localPlayer = Players.LocalPlayer

-- Forward declaration (assigned further down)

local EffectsController = {}
EffectsController.__index = EffectsController

-- Cartoon puff sprite sets (replace with custom assets when available)
local FART_SPRITE_SETS: {{string}} = {
	{ "rbxassetid://241629037", "rbxassetid://241629037", "rbxassetid://241629037" },
	{ "rbxassetid://241629037", "rbxassetid://241629037" },
	{ "rbxassetid://241629037" },
}

local function chooseSpriteSet(): {string}
	return FART_SPRITE_SETS[math.random(1, #FART_SPRITE_SETS)]
end

function EffectsController.new()
	local self = setmetatable({}, EffectsController)
	
	self.activeEffects = {}
	self.playerRole = nil -- updated via RoleAssigned remote
	self.speakerActive = false -- if true, mute spider-sense cues
	
	return self
end

function EffectsController:onFartBroadcast(position)
	print("Playing fart effect at position:", position)
	-- Play directional fart sound (muted if speaker active)
	if not self.speakerActive then
		self:playFartSound(position)
	end
	-- Create fart cloud visual & prompt
	self:createFartCloudEffect(position)
	-- For every player except the farter, create an immediate spider-sense highlight unless masked by speaker
	if self.playerRole ~= "Farter" and not self.speakerActive then
		self:createSpiderSenseEffect(position)
	end
end

function EffectsController:playFartSound(position)
	-- Create a sound at the fart position
	local sound = Instance.new("Sound")
	sound.SoundId = Settings.FartSoundId
	sound.Volume = 0.8
	sound.PlaybackSpeed = math.random(80, 120) / 100 -- Slight pitch variation
	sound.Parent = workspace
	
	-- Position the sound at the fart location
	local soundPart = Instance.new("Part")
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Position = position
	soundPart.Parent = workspace
	sound.Parent = soundPart
	
	-- Play the sound
	sound:Play()
	
	-- Clean up after sound finishes
	sound.Ended:Connect(function()
		soundPart:Destroy()
	end)
	
	-- Fallback cleanup in case sound doesn't play
	spawn(function()
		wait(5)
		if soundPart and soundPart.Parent then
			soundPart:Destroy()
		end
	end)
end

function EffectsController:createSpiderSenseEffect(fartPosition)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	
	local playerPosition = character.HumanoidRootPart.Position
	local direction = (fartPosition - playerPosition).Unit
	
	-- Create spider-sense border effect
	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	-- Create border frame
	local borderFrame = Instance.new("Frame")
	borderFrame.Name = "SpiderSenseBorder"
	borderFrame.Size = UDim2.new(1, 0, 1, 0)
	borderFrame.Position = UDim2.new(0, 0, 0, 0)
	borderFrame.BackgroundTransparency = 1
	borderFrame.Parent = screenGui
	
	-- Create border effect based on direction
	local borderThickness = 10
	local borderColor = Color3.fromRGB(255, 255, 0)
	
	-- Determine which side of the screen to highlight based on direction
	local camera = workspace.CurrentCamera
	local screenPoint = camera:WorldToScreenPoint(fartPosition)
	local screenSize = camera.ViewportSize
	
	local leftBorder = Instance.new("Frame")
	leftBorder.Size = UDim2.new(0, borderThickness, 1, 0)
	leftBorder.Position = UDim2.new(0, 0, 0, 0)
	leftBorder.BackgroundColor3 = borderColor
	leftBorder.Parent = borderFrame
	
	local rightBorder = Instance.new("Frame")
	rightBorder.Size = UDim2.new(0, borderThickness, 1, 0)
	rightBorder.Position = UDim2.new(1, -borderThickness, 0, 0)
	rightBorder.BackgroundColor3 = borderColor
	rightBorder.Parent = borderFrame
	
	local topBorder = Instance.new("Frame")
	topBorder.Size = UDim2.new(1, 0, 0, borderThickness)
	topBorder.Position = UDim2.new(0, 0, 0, 0)
	topBorder.BackgroundColor3 = borderColor
	topBorder.Parent = borderFrame
	
	local bottomBorder = Instance.new("Frame")
	bottomBorder.Size = UDim2.new(1, 0, 0, borderThickness)
	bottomBorder.Position = UDim2.new(0, 0, 1, -borderThickness)
	bottomBorder.BackgroundColor3 = borderColor
	bottomBorder.Parent = borderFrame
	
	-- Determine which border to highlight based on direction
	local highlightBorder = nil
	if screenPoint.X < screenSize.X * 0.3 then
		highlightBorder = leftBorder
	elseif screenPoint.X > screenSize.X * 0.7 then
		highlightBorder = rightBorder
	elseif screenPoint.Y < screenSize.Y * 0.3 then
		highlightBorder = topBorder
	elseif screenPoint.Y > screenSize.Y * 0.7 then
		highlightBorder = bottomBorder
	end
	
	-- Animate the highlight
	if highlightBorder then
		local tween = TweenService:Create(highlightBorder, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 0.3
		})
		tween:Play()
		
		-- Reverse the animation
		spawn(function()
			wait(0.5)
			local reverseTween = TweenService:Create(highlightBorder, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 1
			})
			reverseTween:Play()
			
			-- Clean up after animation
			reverseTween.Completed:Connect(function()
				borderFrame:Destroy()
			end)
		end)
	else
		-- Clean up if no specific border to highlight
		spawn(function()
			wait(1)
			borderFrame:Destroy()
		end)
	end
end

-- Internal: spawn one sprite puff layer and animate it
function EffectsController:_spawnSpritePuff(root: BasePart, layerIndex: number)
	local frames = chooseSpriteSet()
	local life = 1.1 + math.random() * 0.3
	local fps = 10 + math.random(0, 5)
	local startSizePx = 90 + math.random(0, 40)
	local endSizePx = startSizePx + 80 + math.random(0, 50)
	local startTransparency = 0.05
	local endTransparency = 1
	local rotationSpeed = (math.random() < 0.5 and -1 or 1) * (15 + math.random() * 30)
	local startRotation = math.random(-15, 15)
	local offsetStuds = Vector3.new((math.random() - 0.5) * 0.8, (math.random() - 0.5) * 0.3, (math.random() - 0.5) * 0.8)

	local gui = Instance.new("BillboardGui")
	gui.Name = "FartPuffLayer" .. tostring(layerIndex)
	gui.Size = UDim2.fromOffset(startSizePx, startSizePx)
	gui.StudsOffset = offsetStuds
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = root

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = frames[1]
	img.ImageColor3 = Color3.fromRGB(140 + math.random(0,25), 255, 140 + math.random(0,25))
	img.ImageTransparency = startTransparency
	img.Rotation = startRotation
	img.Parent = gui

	-- animate scale
	TweenService:Create(gui, TweenInfo.new(life * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(endSizePx, endSizePx)
	}):Play()
	-- animate fade
	TweenService:Create(img, TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		ImageTransparency = endTransparency
	}):Play()

	-- frame cycling and rotation drift
	local running = true
	local hbConn
	local frameIdx = 1
	local frameAccumulator = 0
	hbConn = RunService.Heartbeat:Connect(function(dt)
		if not running then return end
		-- rotate slowly
		img.Rotation += rotationSpeed * dt
		-- cycle frames
		frameAccumulator += dt
		if frameAccumulator >= (1 / fps) then
			frameAccumulator -= (1 / fps)
			frameIdx += 1
			if frameIdx > #frames then frameIdx = 1 end
			img.Image = frames[frameIdx]
		end
	end)

	-- cleanup
	spawn(function()
		wait(life)
		running = false
		if hbConn then hbConn:Disconnect() end
		if gui then gui:Destroy() end
	end)
end

-- Creates an expanding fart cloud dome built from spherical cloud blobs and attaches a ProximityPrompt
function EffectsController:createFartCloudEffect(position)
	local Settings = require(ReplicatedStorage.Shared.Settings)
	
	-- Invisible root part for prompt and timing
	local cloudRoot = Instance.new("Part")
	cloudRoot.Anchored = true
	cloudRoot.CanCollide = false
	cloudRoot.CanQuery = false
	cloudRoot.Transparency = 1
	cloudRoot.Position = position
	cloudRoot.Name = "FartCloudRoot"
	cloudRoot.Parent = workspace

	-- Build a cloud-like dome from multiple sphere blobs (front-facing bias)
	local blobs = {}
	local radius = Settings.FartCloudRadius
	local numRings = 3
	local blobsPerRing = {4, 6, 8}
	local ringHeights = {0.2, 0.6, 1.0} -- normalized height multiplier
	for r = 1, numRings do
		local ring = Instance.new("Folder")
		ring.Name = "Ring" .. r
		ring.Parent = cloudRoot
		local ringRadius = (radius * 0.4) + (r-1) * (radius * 0.22)
		for i = 1, blobsPerRing[r] do
			local angle = (i / blobsPerRing[r]) * math.pi * 2
			local blob = Instance.new("Part")
			blob.Name = "CloudBlob"
			blob.Shape = Enum.PartType.Ball
			blob.Anchored = true
			blob.CanCollide = false
			blob.Color = Color3.fromRGB(160, 255, 160)
			blob.Material = Enum.Material.Neon
			blob.Transparency = 0.3
			local baseSize = radius * 0.7 + math.random() * (radius * 0.3)
			blob.Size = Vector3.new(baseSize, baseSize, baseSize)
			local offset = Vector3.new(math.cos(angle) * ringRadius, ringHeights[r] * radius * 0.5, math.sin(angle) * ringRadius)
			blob.CFrame = CFrame.new(position + offset)
			blob.Parent = ring
			table.insert(blobs, blob)
		end
	end

	-- Center dome cap
	for i=1,3 do
		local cap = Instance.new("Part")
		cap.Name = "CloudCap"
		cap.Shape = Enum.PartType.Ball
		cap.Anchored = true
		cap.CanCollide = false
		cap.Color = Color3.fromRGB(160, 255, 160)
		cap.Material = Enum.Material.Neon
		cap.Transparency = 0.25
		local size = radius * (0.9 + math.random() * 0.2)
		cap.Size = Vector3.new(size, size, size)
		cap.CFrame = CFrame.new(position + Vector3.new((math.random()-0.5)*radius*0.2, radius*0.5 + math.random()*radius*0.2, (math.random()-0.5)*radius*0.2))
		cap.Parent = cloudRoot
		table.insert(blobs, cap)
	end

	-- Animate slight growth and fade
	for _, blob in ipairs(blobs) do
		local targetSize = blob.Size * 1.25
		TweenService:Create(blob, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = targetSize
		}):Play()
	end

	-- Subtle particles for extra depth
	self:createFartParticles(position)

	-- ProximityPrompt for starting investigation (non-farters)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Investigate"
	prompt.ObjectText = "Fart Cloud"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.2
	prompt.RequiresLineOfSight = false
	prompt.Parent = cloudRoot

	prompt.Triggered:Connect(function(player)
		if player ~= Players.LocalPlayer then return end
		local Remotes = require(ReplicatedStorage.Remotes.Remotes)
		Remotes.StartInvestigation:FireServer()
	end)

	-- Fade out over the lifetime and cleanup
	spawn(function()
		local lifetime = Settings.FartCloudDuration
		local steps = 20
		for s = 1, steps do
			local alpha = s/steps
			for _, blob in ipairs(blobs) do
				if blob and blob.Parent then
					blob.Transparency = 0.25 + alpha * 0.7
				end
			end
			wait(lifetime/steps)
		end
		if cloudRoot and cloudRoot.Parent then
			cloudRoot:Destroy()
		end
	end)
end

function EffectsController:createFartParticles(position)
	-- Create a simple particle effect at the fart position
	local particlePart = Instance.new("Part")
	particlePart.Anchored = true
	particlePart.CanCollide = false
	particlePart.Transparency = 1
	particlePart.Position = position
	particlePart.Parent = workspace
	
	-- Create particle emitter
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Parent = particlePart
	
	-- Configure particle properties
	particleEmitter.Texture = "rbxassetid://241629037" -- Smoke texture
	particleEmitter.Lifetime = NumberRange.new(0.8, 1.4)
	particleEmitter.Rate = 120
	particleEmitter.Speed = NumberRange.new(6, 14)
	particleEmitter.SpreadAngle = Vector2.new(180, 180)
	particleEmitter.Transparency = NumberSequence.new(0.2, 1)
	particleEmitter.Size = NumberSequence.new(0.5, 1.6)
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(120,255,120))
	
	-- Start emitting
	particleEmitter.Enabled = true
	
	-- Stop emitting quickly; let particles dissipate
	spawn(function()
		wait(0.25)
		particleEmitter.Enabled = false
		-- Clean up after particles finish
		wait(1.6)
		if particlePart then particlePart:Destroy() end
	end)
end

function EffectsController:onPlayerVotedOut(player)
	print("Creating ejection effect for:", player.Name)
	
	-- Create dramatic ejection effect
	self:createEjectionEffect(player)
end

function EffectsController:createEjectionEffect(player)
	local character = player.Character
	if not character then return end
	
	-- Create dramatic camera shake effect for all players
	local camera = workspace.CurrentCamera
	if camera then
		spawn(function()
			local originalCFrame = camera.CFrame
			local shakeDuration = 2
			local shakeIntensity = 0.5
			local startTime = tick()
			
			while tick() - startTime < shakeDuration do
				local shakeOffset = Vector3.new(
					math.random(-shakeIntensity, shakeIntensity),
					math.random(-shakeIntensity, shakeIntensity),
					math.random(-shakeIntensity, shakeIntensity)
				)
				camera.CFrame = originalCFrame * CFrame.new(shakeOffset)
				wait(0.05)
			end
			
			camera.CFrame = originalCFrame
		end)
	end
	
	-- Create explosion effect at player position
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		self:createExplosionEffect(rootPart.Position)
	end
end

function EffectsController:createExplosionEffect(position)
	-- Create explosion particles
	local explosionPart = Instance.new("Part")
	explosionPart.Anchored = true
	explosionPart.CanCollide = false
	explosionPart.Transparency = 1
	explosionPart.Position = position
	explosionPart.Parent = workspace
	
	-- Create explosion particle emitter
	local explosionEmitter = Instance.new("ParticleEmitter")
	explosionEmitter.Parent = explosionPart
	
	-- Configure explosion properties
	explosionEmitter.Texture = "rbxassetid://241629037"
	explosionEmitter.Lifetime = NumberRange.new(1, 3)
	explosionEmitter.Rate = 100
	explosionEmitter.Speed = NumberRange.new(20, 50)
	explosionEmitter.SpreadAngle = Vector2.new(360, 360)
	explosionEmitter.Transparency = NumberSequence.new(0, 1)
	explosionEmitter.Size = NumberSequence.new(1, 5)
	explosionEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
	
	-- Start explosion
	explosionEmitter.Enabled = true
	
	-- Clean up
	spawn(function()
		wait(0.5)
		explosionEmitter.Enabled = false
		wait(3)
		explosionPart:Destroy()
	end)
end

-- Initialize the EffectsController
local effectsController = EffectsController.new()
_G.__EffectsControllerInstance = effectsController

-- Listen for fart broadcasts
Remotes.FartBroadcast.OnClientEvent:Connect(function(position)
	effectsController:onFartBroadcast(position)
end)

-- Listen for player ejection
Remotes.PlayerVotedOut.OnClientEvent:Connect(function(player)
	effectsController:onPlayerVotedOut(player)
end) 

-- Listen for role assignment so we know if local player is the Farter
Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
	effectsController.playerRole = role
end)

-- Speaker masking toggle (if a map speaker system is active, this can be driven from server)
Remotes.SpeakerStateChanged.OnClientEvent:Connect(function(isActive)
	effectsController.speakerActive = isActive and true or false
end) 