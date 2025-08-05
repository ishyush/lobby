-- src/client/FarterController.client.luau
-- Handles Farter-specific logic and abilities
-- This script is active when the player's role is Farter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

	-- Listen for game state changes to create/destroy blame prompts
	local player = Players.LocalPlayer
	Remotes.GameStateChanged.OnClientEvent:Connect(function(newState)
		self:_onGameStateChanged(newState)
	end)
	
	return self
end

function FarterController:activate()
	self.isActive = true
	self.fartCount = 0
	print("FarterController activated")
end

function FarterController:deactivate()
	self.isActive = false
	print("FarterController deactivated")
end

function FarterController:onFartSuccess()
	self.fartCount = self.fartCount + 1
	print("Fart successful! Count:", self.fartCount, "/", self.maxFarts)
	
	-- Update UI if it exists
	if self.fartCountLabel then
		self.fartCountLabel.Text = "Farts: " .. self.fartCount .. "/" .. self.maxFarts
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