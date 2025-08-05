-- src/client/EffectsController.client.luau
-- Handles all sensory feedback including visual and audio effects
-- This includes fart sounds, spider-sense effects, and other visual feedback

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

-- Track the local player's role so we can decide whether to show directional cues
local localPlayer = Players.LocalPlayer

-- Forward declaration (assigned further down)

local EffectsController = {}
EffectsController.__index = EffectsController

function EffectsController.new()
	local self = setmetatable({}, EffectsController)
	
	self.activeEffects = {}
	self.playerRole = nil -- updated via RoleAssigned remote
	
	return self
end

function EffectsController:onFartBroadcast(position)
	print("Playing fart effect at position:", position)
	-- Play directional fart sound
	self:playFartSound(position)
	-- Create fart cloud visual & prompt
	self:createFartCloudEffect(position)
	-- For every player except the farter, create an immediate spider-sense highlight
	if self.playerRole ~= "Farter" then
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

-- Creates an expanding fart cloud dome (10x10 studs) and attaches a ProximityPrompt
function EffectsController:createFartCloudEffect(position)
	local Settings = require(ReplicatedStorage.Shared.Settings)
	-- Part to represent cloud collision (client-side visual)
	local cloudPart = Instance.new("Part")
	cloudPart.Anchored = true
	cloudPart.CanCollide = false
	cloudPart.CanQuery = false
	cloudPart.Transparency = 0.4 -- semi-visible
	cloudPart.Color = Color3.fromRGB(120,255,120)
	cloudPart.Material = Enum.Material.Neon
	cloudPart.Shape = Enum.PartType.Ball
	cloudPart.Size = Vector3.new(0,0,0)
	cloudPart.Position = position
	cloudPart.Name = "FartCloud"
	cloudPart.Parent = workspace

	-- Explosion tween to size 10x10x10
	local targetSize = Vector3.new(Settings.FartCloudRadius*2, Settings.FartCloudRadius*2, Settings.FartCloudRadius*2)
	local tween = TweenService:Create(cloudPart, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = targetSize})
	tween:Play()

	-- Optional greenish smoke particles for visual flair
	self:createFartParticles(position)

	-- ProximityPrompt for starting investigation (non-farters)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Investigate"
	prompt.ObjectText = "Fart Cloud"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = cloudPart

	prompt.Triggered:Connect(function(player)
		-- Only local player should fire the remote to reduce duplicate network calls
		if player ~= Players.LocalPlayer then return end
		local Remotes = require(ReplicatedStorage.Remotes.Remotes)
		Remotes.StartInvestigation:FireServer()
	end)

	-- Cleanup after cloud duration
	spawn(function()
		wait(Settings.FartCloudDuration)
		if cloudPart.Parent then
			cloudPart:Destroy()
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
	particleEmitter.Lifetime = NumberRange.new(2, 4)
	particleEmitter.Rate = 150
	particleEmitter.Speed = NumberRange.new(5, 15)
	particleEmitter.SpreadAngle = Vector2.new(180, 180)
	particleEmitter.Transparency = NumberSequence.new(0, 1)
	particleEmitter.Size = NumberSequence.new(0.5, 2)
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(100,255,100))
	
	-- Start emitting
	particleEmitter.Enabled = true
	
	-- Stop emitting after a short time
	spawn(function()
		wait(1)
		particleEmitter.Enabled = false
		
		-- Clean up after particles finish
		wait(4)
		particlePart:Destroy()
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