-- src/client/SnifferController.client.luau
-- Handles Sniffer-specific logic and abilities
-- This script is active when the player's role is Sniffer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

local SnifferController = {}
SnifferController.__index = SnifferController

function SnifferController.new()
	local self = setmetatable({}, SnifferController)
	
	self.isActive = false
	self.canSniff = false -- becomes true during Investigation
	self.sniffCooldown = 3 -- seconds between sniffs
	self.lastSniffTime = 0
	
	return self
end

function SnifferController:activate()
	self.isActive = true
	print("SnifferController activated")
end

function SnifferController:deactivate()
	self.isActive = false
	self.canSniff = false
	print("SnifferController deactivated")
end

function SnifferController:enableSniffing()
	if not self.isActive then return end
	self.canSniff = true
	print("Sniffing enabled – creating prompts")
	self:_createSniffPrompts()
end

function SnifferController:disableSniffing()
	self.canSniff = false
	print("Sniffing disabled – removing prompts")
	self:_destroySniffPrompts()
end

function SnifferController:onSniffResult(targetPlayer, isSmelly)
	local resultText = isSmelly and "SMELLY!" or "Clean"
	local resultColor = isSmelly and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
	
	print("Sniff result for", targetPlayer.Name, ":", resultText)
	
	-- Show result UI
	self:showSniffResult(targetPlayer.Name, resultText, resultColor)
	
	-- Play sound effect
	self:playSniffSound(isSmelly)
end

function SnifferController:showSniffResult(playerName, result, color)
	-- Create result display
	local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "SniffResultFrame"
	resultFrame.Size = UDim2.new(0, 300, 0, 60)
	resultFrame.Position = UDim2.new(0.5, -150, 0.5, -30)
	resultFrame.BackgroundColor3 = color
	resultFrame.BackgroundTransparency = 0.2
	resultFrame.Parent = screenGui
	
	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(1, 0, 1, 0)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = playerName .. " is " .. result
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.TextScaled = true
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.Parent = resultFrame
	
	-- Auto-destroy after duration
	spawn(function()
		wait(Settings.SniffEffectDuration)
		resultFrame:Destroy()
	end)
end

function SnifferController:playSniffSound(isSmelly)
	-- Play different sounds based on result
	local soundId = isSmelly and "rbxassetid://9048370935" or "rbxassetid://9048370936" -- Placeholder IDs
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Parent = workspace
	
	sound:Play()
	
	-- Clean up sound after playing
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function SnifferController:handlePlayerClick(player)
	if not self.canSniff or not self.isActive then
		return
	end
	
	local currentTime = tick()
	if currentTime - self.lastSniffTime < self.sniffCooldown then
		print("Sniff on cooldown")
		return
	end
	
	-- Call server to sniff player
	local success, result = pcall(function()
		return Remotes.SniffPlayer:InvokeServer(player)
	end)

	if success then
		self.lastSniffTime = currentTime
		self:onSniffResult(player, result)
	else
		print("Failed to sniff player:", result)
	end
end

-- ProximityPrompt based sniffing -----------------------------------------

function SnifferController:_createSniffPrompts()
    local localPlayer = Players.LocalPlayer

    local function addPromptToCharacter(char, targetPlayer)
        if not self.canSniff then return end
        if char and char:FindFirstChild("HumanoidRootPart") then
            local existing = char.HumanoidRootPart:FindFirstChild("SniffPrompt")
            if existing then existing:Destroy() end

            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "SniffPrompt"
            prompt.ActionText = "Sniff"
            prompt.ObjectText = targetPlayer.Name
            prompt.KeyboardKeyCode = Enum.KeyCode.E
            prompt.HoldDuration = 1.0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = 8
            prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
            prompt.Parent = char.HumanoidRootPart

            prompt.Triggered:Connect(function(player)
                if player ~= localPlayer then return end
                self:handlePlayerClick(targetPlayer)
            end)
        end
    end

    -- helper to attach for current + future spawns
    local function attachLifecycle(plr: Player)
        if plr == localPlayer then return end
        addPromptToCharacter(plr.Character, plr)
        plr.CharacterAdded:Connect(function(char)
            addPromptToCharacter(char, plr)
        end)
    end

    -- existing players
    for _, p in ipairs(Players:GetPlayers()) do
        attachLifecycle(p)
    end

    -- future players
    Players.PlayerAdded:Connect(attachLifecycle)
end

function SnifferController:_destroySniffPrompts()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local prompt = p.Character.HumanoidRootPart:FindFirstChild("SniffPrompt")
            if prompt then prompt:Destroy() end
        end
    end
end

function SnifferController:createSniffUI()
	-- Create sniff instruction UI
	local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	local sniffFrame = Instance.new("Frame")
	sniffFrame.Name = "SniffFrame"
	sniffFrame.Size = UDim2.new(0, 250, 0, 50)
	sniffFrame.Position = UDim2.new(0, 20, 0, 140)
	sniffFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	sniffFrame.BackgroundTransparency = 0.3
	sniffFrame.Parent = screenGui
	
	local sniffLabel = Instance.new("TextLabel")
	sniffLabel.Name = "SniffLabel"
	sniffLabel.Size = UDim2.new(1, 0, 1, 0)
	sniffLabel.BackgroundTransparency = 1
	sniffLabel.Text = "Hold E near players to sniff them!"
	sniffLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	sniffLabel.TextScaled = true
	sniffLabel.Font = Enum.Font.GothamBold
	sniffLabel.Parent = sniffFrame
	
	self.sniffFrame = sniffFrame
end

function SnifferController:destroySniffUI()
	if self.sniffFrame then
		self.sniffFrame:Destroy()
		self.sniffFrame = nil
	end
end

-- Initialize the SnifferController
local snifferController = SnifferController.new()

-- Listen for role assignment
Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
	if role == "Sniffer" then
		snifferController:activate()
		snifferController:createSniffUI()
		-- prompts will be created during Investigation
	else
		snifferController:deactivate()
		snifferController:destroySniffUI()
	end
end)

-- Listen for game state changes
Remotes.GameStateChanged.OnClientEvent:Connect(function(newState)
	if newState == "Investigation" then
		snifferController:enableSniffing()
	else
		snifferController:disableSniffing()
	end
end) 