-- src/client/FarterController.client.luau
-- Handles Farter-specific logic and abilities
-- This script is active when the player's role is Farter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

local FarterController = {}
FarterController.__index = FarterController

function FarterController.new()
	local self = setmetatable({}, FarterController)
	
	self.isActive = false
	self.fartCount = 0
	self.maxFarts = Settings.FartsToWin
	self.sprayUses = 0
	self.sprayUsed = false
	self.speakerActive = false

	-- Listen for game state changes to create/destroy blame prompts
	local player = Players.LocalPlayer
	Remotes.GameStateChanged.OnClientEvent:Connect(function(newState)
		self:_onGameStateChanged(newState)
	end)
	
	-- Increment farter UI when a fart broadcast occurs and this client is farter
	Remotes.FartBroadcast.OnClientEvent:Connect(function()
		if self.isActive then
			self:onFartSuccess()
		end
	end)

	-- Speaker state from server
	Remotes.SpeakerStateChanged.OnClientEvent:Connect(function(isActive)
		self.speakerActive = isActive and true or false
		if self.speakerButton then
			self:_updateSpeakerButtonVisual()
		end
	end)
	
	return self
end

function FarterController:activate()
	self.isActive = true
	self.fartCount = 0
	print("FarterController activated")
	self:_createSpeakerButton()
end

function FarterController:deactivate()
	self.isActive = false
	print("FarterController deactivated")
	self:_destroySpeakerButton()
end

function FarterController:onFartSuccess()
	self.fartCount = self.fartCount + 1
	print("Fart successful! Count:", self.fartCount, "/", self.maxFarts)
	
	-- Update UI if it exists
	if self.fartCountLabel then
		self.fartCountLabel.Text = "Farts: " .. self.fartCount .. "/" .. self.maxFarts
		-- pop animation
		local uiScale = self.fartCountLabel.Parent:FindFirstChild("UIScale") or Instance.new("UIScale")
		uiScale.Parent = self.fartCountLabel.Parent
		uiScale.Scale = 1
		TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
		spawn(function()
			wait(0.15)
			TweenService:Create(uiScale, TweenInfo.new(0.12), {Scale = 1}):Play()
		end)
		print("Updated fart count display to:", self.fartCount, "/", self.maxFarts)
	end
	
	-- Check win condition
	if self.fartCount >= self.maxFarts then
		print("Farter has reached maximum farts!")
	end
end

function FarterController:createFartUI()
	-- Create fart count display
	local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	local fartCountFrame = Instance.new("Frame")
	fartCountFrame.Name = "FartCountFrame"
	fartCountFrame.Size = UDim2.new(0, 200, 0, 40)
	fartCountFrame.Position = UDim2.new(0, 20, 0, 80)
	fartCountFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	fartCountFrame.BackgroundTransparency = 0.3
	fartCountFrame.Parent = screenGui
	
	local fartCountLabel = Instance.new("TextLabel")
	fartCountLabel.Name = "FartCountLabel"
	fartCountLabel.Size = UDim2.new(1, 0, 1, 0)
	fartCountLabel.BackgroundTransparency = 1
	fartCountLabel.Text = "Farts: 0/" .. self.maxFarts
	fartCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	fartCountLabel.TextScaled = true
	fartCountLabel.Font = Enum.Font.GothamBold
	fartCountLabel.Parent = fartCountFrame
	
	self.fartCountLabel = fartCountLabel
end

function FarterController:destroyFartUI()
	if self.fartCountLabel then
		self.fartCountLabel.Parent:Destroy()
		self.fartCountLabel = nil
	end
end

-- Speaker UI ---------------------------------------------------------------
function FarterController:_createSpeakerButton()
	if not self.isActive then return end
	local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	self:_destroySpeakerButton()
	local button = Instance.new("TextButton")
	button.Name = "SpeakerButton"
	button.Size = UDim2.new(0, 140, 0, 40)
	button.Position = UDim2.new(1, -160, 1, -60)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Text = "Speaker: OFF"
	button.Font = Enum.Font.GothamBold
	button.Parent = screenGui
	self.speakerButton = button
	
	button.MouseButton1Click:Connect(function()
		Remotes.ToggleSpeaker:FireServer()
	end)
	
	self:_updateSpeakerButtonVisual()
end

function FarterController:_destroySpeakerButton()
	if self.speakerButton then
		self.speakerButton:Destroy()
		self.speakerButton = nil
	end
end

function FarterController:_updateSpeakerButtonVisual()
	if not self.speakerButton then return end
	if self.speakerActive then
		self.speakerButton.Text = "Speaker: ON"
		TweenService:Create(self.speakerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 160, 0)}):Play()
		-- pulse icon/text color
		spawn(function()
			for i=1,4 do
				if not self.speakerButton then break end
				TweenService:Create(self.speakerButton, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(200, 255, 200)}):Play()
				wait(0.15)
				TweenService:Create(self.speakerButton, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
				wait(0.15)
			end
		end)
	else
		self.speakerButton.Text = "Speaker: OFF"
		TweenService:Create(self.speakerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
	end
end

-- Called whenever server broadcasts a game state change
function FarterController:_onGameStateChanged(newState: string)
	-- Only care if this client is the Farter
	if not self.isActive then return end

	if newState == "Mingle" then
		-- Only create prompts if ability unused this round
		if not self.sprayUsed then
			self:_createSprayPrompts()
		end
	else
		-- Destroy prompts when leaving mingle
		self:_destroySprayPrompts()
	end
end

-- (Deprecated) hookSprayTool removed – ability now handled directly via prompts
function FarterController:hookSprayTool() end

-- Create ProximityPrompts on other players for blame spray
function FarterController:_createSprayPrompts()
	local localPlayer = Players.LocalPlayer
	local function addPromptToCharacter(char, targetPlayer)
		if char and char:FindFirstChild("HumanoidRootPart") then
			local existing = char.HumanoidRootPart:FindFirstChild("BlamePrompt")
			if existing then existing:Destroy() end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BlamePrompt"
			prompt.ActionText = "Blame"
			prompt.ObjectText = targetPlayer.Name
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 1.2
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 8 -- make it a bit more forgiving
			-- Ensure prompt is visible even if another prompt is active
			prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
			prompt.Parent = char.HumanoidRootPart

			prompt.Triggered:Connect(function(player)
				if player ~= localPlayer then return end
				if self.sprayUsed then return end
				self.sprayUsed = true
				Remotes.BlameSpray:FireServer(targetPlayer)
				-- Destroy local spray tool
				local toolInstance = localPlayer.Backpack:FindFirstChild("BlameSpray") or (localPlayer.Character and localPlayer.Character:FindFirstChild("BlameSpray"))
				if toolInstance then toolInstance:Destroy() end
				-- Remove all prompts after use
				for _,p in ipairs(Players:GetPlayers()) do
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						local bp = p.Character.HumanoidRootPart:FindFirstChild("BlamePrompt")
						if bp then bp:Destroy() end
					end
				end
			end)
		end
	end

	-- Helper to attach prompt both for current character and future spawns
	local function attachPromptLifecycle(player: Player)
		if player == localPlayer then return end

		-- Immediately attempt for current character (if it exists)
		addPromptToCharacter(player.Character, player)

		-- Ensure we re-add the prompt whenever this player respawns
		player.CharacterAdded:Connect(function(char)
			addPromptToCharacter(char, player)
		end)
	end

	-- Attach for all players currently in the game
	for _, p in ipairs(Players:GetPlayers()) do
		attachPromptLifecycle(p)
	end

	-- Attach for any players who join later
	Players.PlayerAdded:Connect(function(p)
		attachPromptLifecycle(p)
	end)
end

-- Destroy all blame prompts from players
function FarterController:_destroySprayPrompts()
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local bp = p.Character.HumanoidRootPart:FindFirstChild("BlamePrompt")
			if bp then bp:Destroy() end
		end
	end
end

-- Fart cooldown gate
function FarterController:canFart()
	local current = tick()
	return (self.lastFartTime == nil) or (current - self.lastFartTime >= Settings.FartCooldown)
end

function FarterController:recordFart()
	self.lastFartTime = tick()
end

-- Initialize the FarterController
local farterController = FarterController.new()

-- Listen for role assignment
Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
	if role == "Farter" then
		farterController:activate()
		farterController:createFartUI()
	else
		farterController:deactivate()
		farterController:destroyFartUI()
	end
end)

-- Listen for role assignment to reset fart count
Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
	if role == "Farter" then
		farterController.fartCount = 0
		farterController.sprayUsed = false
		if farterController.fartCountLabel then
			farterController.fartCountLabel.Text = "Farts: 0/" .. farterController.maxFarts
		end
	end
end) 