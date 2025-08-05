-- src/client/GameController.client.luau
-- Main entry point for the client
-- Listens to the server and delegates tasks to other client-side modules

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

local GameController = {}
GameController.__index = GameController

function GameController.new()
	local self = setmetatable({}, GameController)
	
	self.currentState = "Lobby"
	self.playerRole = nil
	self.stateStartTime = 0
	self.uiElements = {}
	
	-- Initialize UI
	self:createUI()
	
	-- Bind remote events
	self:bindRemotes()
	
	return self
end

function GameController:createUI()
	-- Create main game UI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Game state display
	local stateFrame = Instance.new("Frame")
	stateFrame.Name = "StateFrame"
	stateFrame.Size = UDim2.new(0, 300, 0, 50)
	stateFrame.Position = UDim2.new(0.5, -150, 0, 20)
	stateFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stateFrame.BackgroundTransparency = 0.5
	stateFrame.Parent = screenGui
	
	local stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "StateLabel"
	stateLabel.Size = UDim2.new(1, 0, 1, 0)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Text = "Waiting for players..."
	stateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	stateLabel.TextScaled = true
	stateLabel.Font = Enum.Font.GothamBold
	stateLabel.Parent = stateFrame
	
	-- Role display
	local roleFrame = Instance.new("Frame")
	roleFrame.Name = "RoleFrame"
	roleFrame.Size = UDim2.new(0, 200, 0, 40)
	roleFrame.Position = UDim2.new(0, 20, 0, 20)
	roleFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	roleFrame.BackgroundTransparency = 0.5
	roleFrame.Visible = false
	roleFrame.Parent = screenGui
	
	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "RoleLabel"
	roleLabel.Size = UDim2.new(1, 0, 1, 0)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = ""
	roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	roleLabel.TextScaled = true
	roleLabel.Font = Enum.Font.GothamBold
	roleLabel.Parent = roleFrame
	
	-- Store UI elements
	self.uiElements.screenGui = screenGui
	self.uiElements.stateLabel = stateLabel
	self.uiElements.roleFrame = roleFrame
	self.uiElements.roleLabel = roleLabel
end

function GameController:bindRemotes()
	-- Listen for game state changes (may include winnerRole for RoundEnd)
	Remotes.GameStateChanged.OnClientEvent:Connect(function(newState, winnerRole)
		self:onGameStateChanged(newState, winnerRole)
	end)
	
	-- Listen for role assignment
	Remotes.RoleAssigned.OnClientEvent:Connect(function(role)
		self:onRoleAssigned(role)
	end)
	
	-- Listen for fart broadcasts
	Remotes.FartBroadcast.OnClientEvent:Connect(function(position)
		self:onFartBroadcast(position)
	end)

	-- Listen for lobby countdown updates
	Remotes.LobbyCountdown.OnClientEvent:Connect(function(secondsRemaining)
		self:onLobbyCountdown(secondsRemaining)
	end)
	
	-- Listen for player ejection
	Remotes.PlayerVotedOut.OnClientEvent:Connect(function(player)
		self:onPlayerVotedOut(player)
	end)
end

function GameController:onGameStateChanged(newState, winnerRole)
	self.currentState = newState
	self.stateStartTime = tick()
	
	print("Client received state change:", newState)
	
	-- Round end is handled differently
	if newState == "RoundEnd" then
		-- Clear any leftover phase-specific UI
		self:disableAllPhases()

		-- Show winner message
		self:showRoundResult(winnerRole)

		-- Update state label
		if self.uiElements.stateLabel then
			self.uiElements.stateLabel.Text = "Round End"
		end

		return -- Skip the rest of the phase handling
	end

	-- Update UI
	if self.uiElements.stateLabel then
		self.uiElements.stateLabel.Text = newState
		print("Updated state label to:", newState)
	end

	-- Start phase timer
	self:startPhaseTimer(newState)

	-- Handle state-specific logic
	if newState == "Farting" then
		print("Enabling farting phase")
		self:enableFartingPhase()
	elseif newState == "Investigation" then
		print("Enabling investigation phase")
		self:enableInvestigationPhase()
	elseif newState == "Voting" then
		print("Enabling voting phase")
		self:disableAllPhases()
		self:enableVotingPhase()
	elseif newState == "Mingle" then
		print("Enabling mingle phase")
		self:disableAllPhases()
		self:enableMinglePhase()
	else
		print("Disabling all phases")
		self:disableAllPhases()
	end

	print("Game state changed to:", newState)
end

-- Display round winner message
function GameController:showRoundResult(winnerRole)
    local screenGui = self.uiElements.screenGui
    if not screenGui then return end

    -- Remove existing result label if present
    if self.uiElements.roundResultLabel then
        self.uiElements.roundResultLabel:Destroy()
        self.uiElements.roundResultLabel = nil
    end

    local resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "RoundResultLabel"
    resultLabel.Size = UDim2.new(0, 450, 0, 80)
    resultLabel.Position = UDim2.new(0.5, -225, 0.5, -40)
    resultLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    resultLabel.BackgroundTransparency = 0.4
    resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    resultLabel.TextScaled = true
    resultLabel.Font = Enum.Font.GothamBold

    if winnerRole == "Farter" then
        resultLabel.Text = "The Farter got away! Farter wins!"
        resultLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    else
        resultLabel.Text = "The Farter was caught! Everyone else wins!"
        resultLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
    end

    resultLabel.Parent = screenGui

    self.uiElements.roundResultLabel = resultLabel

    -- Auto-destroy after 5 seconds
    spawn(function()
        wait(5)
        if resultLabel and resultLabel.Parent then
            resultLabel:Destroy()
            self.uiElements.roundResultLabel = nil
        end
    end)
end

-- Simplified to avoid duplicate voting UI (handled by VotingUI module)
function GameController:enableVotingPhase()
    -- VotingUI module handles the voting interface; we only need to clear other phase UI.
    -- Additional logic can be added here if needed (e.g., ambient sounds).
end

function GameController:onRoleAssigned(role)
	self.playerRole = role
	
	-- Update role display
	self.uiElements.roleLabel.Text = "Role: " .. role
	self.uiElements.roleFrame.Visible = true
	
	-- Set role-specific color
	local roleColors = {
		Farter = Color3.fromRGB(255, 0, 0),
		Sniffer = Color3.fromRGB(0, 255, 0),
		Innocent = Color3.fromRGB(0, 0, 255)
	}
	
	self.uiElements.roleLabel.TextColor3 = roleColors[role] or Color3.fromRGB(255, 255, 255)
	
	print("Assigned role:", role)
end

function GameController:onFartBroadcast(position)
	-- This will be handled by EffectsController
	print("Fart broadcast received at position:", position)
end

function GameController:onPlayerVotedOut(player)
	print("Player voted out:", player.Name)
	
	-- Show ejection message
	local message = Instance.new("Message")
	message.Text = player.Name .. " was voted out!"
	message.Parent = workspace
	
	wait(3)
	message:Destroy()
end

function GameController:enableFartingPhase()
	-- Only enable for Farter
	if self.playerRole == "Farter" then
		-- Create fart button
		local fartButton = Instance.new("TextButton")
		fartButton.Name = "FartButton"
		fartButton.Size = UDim2.new(0, 150, 0, 50)
		fartButton.Position = UDim2.new(0.5, -75, 0.8, 0)
		fartButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		fartButton.Text = "FART!"
		fartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		fartButton.TextScaled = true
		fartButton.Font = Enum.Font.GothamBold
		fartButton.Parent = self.uiElements.screenGui
		
		-- Create countdown bar
		local countdownFrame = Instance.new("Frame")
		countdownFrame.Name = "CountdownFrame"
		countdownFrame.Size = UDim2.new(0, 300, 0, 20)
		countdownFrame.Position = UDim2.new(0.5, -150, 0.7, 0)
		countdownFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		countdownFrame.Parent = self.uiElements.screenGui
		
		local countdownBar = Instance.new("Frame")
		countdownBar.Name = "CountdownBar"
		countdownBar.Size = UDim2.new(1, 0, 1, 0)
		countdownBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
		countdownBar.Parent = countdownFrame
		
		-- Create timer label
		local timerLabel = Instance.new("TextLabel")
		timerLabel.Name = "TimerLabel"
		timerLabel.Size = UDim2.new(0, 100, 0, 30)
		timerLabel.Position = UDim2.new(0.5, -50, 0.6, 0)
		timerLabel.BackgroundTransparency = 1
		timerLabel.Text = "10"
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
		timerLabel.TextScaled = true
		timerLabel.Font = Enum.Font.GothamBold
		timerLabel.Parent = self.uiElements.screenGui
		
		-- Handle fart button click
		local Settings = require(ReplicatedStorage.Shared.Settings)
		fartButton.MouseButton1Click:Connect(function()
			if fartButton:GetAttribute("OnCooldown") then return end
			Remotes.FartAction:FireServer()
			fartButton:SetAttribute("OnCooldown", true)
			fartButton.BackgroundColor3 = Color3.fromRGB(100,100,100)
			local cooldown = Settings.FartCooldown
			spawn(function()
				local start = tick()
				while tick() - start < cooldown and fartButton.Parent do
					local remaining = cooldown - (tick()-start)
					fartButton.Text = "FART ("..math.ceil(remaining)..")"
					wait(0.1)
				end
				if fartButton.Parent then
					fartButton:SetAttribute("OnCooldown", false)
					fartButton.BackgroundColor3 = Color3.fromRGB(255,0,0)
					fartButton.Text = "FART!"
				end
			end)
		end)
		
		-- Store references BEFORE starting countdown
		self.uiElements.fartButton = fartButton
		self.uiElements.countdownFrame = countdownFrame
		self.uiElements.timerLabel = timerLabel

		-- Start countdown
		spawn(function()
			local startTime = tick()
			while tick() - startTime < Settings.FartWindowDuration and countdownFrame.Parent do
				local elapsed = tick() - startTime
				local remaining = Settings.FartWindowDuration - elapsed
				countdownBar.Size = UDim2.new(remaining / Settings.FartWindowDuration, 0, 1, 0)
				timerLabel.Text = math.max(0, math.ceil(remaining))
				wait(0.1)
			end
			-- Automatically clear UI if countdown reaches 0 and farter didn't use it
			self:clearFartUI()
		end)
	end
end

function GameController:enableInvestigationPhase()
	-- Only enable for Sniffer
	if self.playerRole == "Sniffer" then
		-- Create sniff instruction
		local sniffLabel = Instance.new("TextLabel")
		sniffLabel.Name = "SniffLabel"
		sniffLabel.Size = UDim2.new(0, 300, 0, 50)
		sniffLabel.Position = UDim2.new(0.5, -150, 0.75, 0)
		sniffLabel.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		sniffLabel.BackgroundTransparency = 0.5
		sniffLabel.Text = "Click on players to sniff them!"
		sniffLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		sniffLabel.TextScaled = true
		sniffLabel.Font = Enum.Font.GothamBold
		sniffLabel.Parent = self.uiElements.screenGui
		
		self.uiElements.sniffLabel = sniffLabel
	end
end

function GameController:enableMinglePhase()
	-- Create mingle instruction
	local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("GameUI")
	if not screenGui then return end
	
	-- Remove any existing mingle UI
	if self.uiElements.mingleLabel then
		self.uiElements.mingleLabel:Destroy()
	end
	
	local mingleLabel = Instance.new("TextLabel")
	mingleLabel.Name = "MingleLabel"
	mingleLabel.Size = UDim2.new(0, 300, 0, 50)
	mingleLabel.Position = UDim2.new(0.5, -150, 0.8, 0)
	mingleLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
	mingleLabel.BackgroundTransparency = 0.5
	mingleLabel.Text = "Mingle with other players!"
	mingleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	mingleLabel.TextScaled = true
	mingleLabel.Font = Enum.Font.GothamBold
	mingleLabel.Parent = screenGui
	
	self.uiElements.mingleLabel = mingleLabel
end

function GameController:startPhaseTimer(phase)
	-- Get duration for the phase
	local duration = 0
	if phase == "Mingle" then
		duration = Settings.MingleDuration
	elseif phase == "Farting" then
		duration = Settings.FartWindowDuration
	elseif phase == "Investigation" then
		duration = Settings.InvestigationDuration
	elseif phase == "Voting" then
		duration = Settings.VotingDuration
	end
	
	if duration > 0 then
		-- Create or update phase timer
		if not self.uiElements.phaseTimer then
			local phaseTimer = Instance.new("TextLabel")
			phaseTimer.Name = "PhaseTimer"
			phaseTimer.Size = UDim2.new(0, 200, 0, 40)
			phaseTimer.Position = UDim2.new(0.5, -100, 0.1, 0)
			phaseTimer.BackgroundTransparency = 1
			phaseTimer.Text = phase .. ": " .. duration .. "s"
			phaseTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
			phaseTimer.TextScaled = true
			phaseTimer.Font = Enum.Font.GothamBold
			phaseTimer.Parent = self.uiElements.screenGui
			
			self.uiElements.phaseTimer = phaseTimer
		end
		
		-- Start countdown
		spawn(function()
			local startTime = tick()
			while tick() - startTime < duration do
				local remaining = duration - (tick() - startTime)
				if self.uiElements.phaseTimer then
					self.uiElements.phaseTimer.Text = phase .. ": " .. math.ceil(remaining) .. "s"
				end
				wait(0.1)
			end
		end)
	end
end

function GameController:disableAllPhases()
	-- Remove all phase-specific UI elements
	if self.uiElements.fartButton then
		self.uiElements.fartButton:Destroy()
		self.uiElements.fartButton = nil
	end
	
	if self.uiElements.countdownFrame then
		self.uiElements.countdownFrame:Destroy()
		self.uiElements.countdownFrame = nil
	end
	
	if self.uiElements.timerLabel then
		self.uiElements.timerLabel:Destroy()
		self.uiElements.timerLabel = nil
	end
	
	if self.uiElements.sniffLabel then
		self.uiElements.sniffLabel:Destroy()
		self.uiElements.sniffLabel = nil
	end
	
	if self.uiElements.votingFrame then
		self.uiElements.votingFrame:Destroy()
		self.uiElements.votingFrame = nil
	end
	
	if self.uiElements.mingleLabel then
		self.uiElements.mingleLabel:Destroy()
		self.uiElements.mingleLabel = nil
	end
	
	if self.uiElements.phaseTimer then
		self.uiElements.phaseTimer:Destroy()
		self.uiElements.phaseTimer = nil
	end

	if self.uiElements.lobbyCountdownLabel then
		self.uiElements.lobbyCountdownLabel:Destroy()
		self.uiElements.lobbyCountdownLabel = nil
	end
end

-- Display or update the lobby countdown label
function GameController:onLobbyCountdown(secondsRemaining)
	local screenGui = self.uiElements.screenGui
	if not screenGui then return end

	-- Create label if it doesn't exist
	if not self.uiElements.lobbyCountdownLabel then
		local lbl = Instance.new("TextLabel")
		lbl.Name = "LobbyCountdownLabel"
		lbl.Size = UDim2.new(0, 260, 0, 40)
		lbl.Position = UDim2.new(0.5, -130, 0, 70)
		lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		lbl.BackgroundTransparency = 0.5
		lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.Parent = screenGui

		self.uiElements.lobbyCountdownLabel = lbl
	end

	-- Update text
	if self.uiElements.lobbyCountdownLabel then
		if secondsRemaining > 0 then
			self.uiElements.lobbyCountdownLabel.Text = "Game starts in " .. secondsRemaining .. "s"
		else
			self.uiElements.lobbyCountdownLabel:Destroy()
			self.uiElements.lobbyCountdownLabel = nil
		end
	end
end

-- Initialize the game controller
local gameController = GameController.new() 

function GameController:clearFartUI()
	if self.uiElements.fartButton then
		self.uiElements.fartButton:Destroy()
		self.uiElements.fartButton = nil
	end
	if self.uiElements.countdownFrame then
		self.uiElements.countdownFrame:Destroy()
		self.uiElements.countdownFrame = nil
	end
	if self.uiElements.timerLabel then
		self.uiElements.timerLabel:Destroy()
		self.uiElements.timerLabel = nil
	end
end 