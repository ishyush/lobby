-- src/client/VotingUI.client.luau
-- Manages the voting interface and vote casting functionality
-- Displays all active players and allows the local player to vote

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

local VotingUI = {}
VotingUI.__index = VotingUI

function VotingUI.new()
	local self = setmetatable({}, VotingUI)
	
	self.isActive = false
	self.voteFrame = nil
	self.countdownLabel = nil
	self.voteButtons = {}
	self.selectedPlayer = nil
	self.voteStartTime = 0
	
	return self
end

function VotingUI:activate()
	self.isActive = true
	self.voteStartTime = tick()
	self.selectedPlayer = nil
	
	self:createVotingInterface()
	print("VotingUI activated")
end

function VotingUI:deactivate()
	self.isActive = false
	self:destroyVotingInterface()
	print("VotingUI deactivated")
end

function VotingUI:createVotingInterface()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gameUI = playerGui:FindFirstChild("GameUI")
	
	if not gameUI then return end
	
	-- Create main voting frame
	local voteFrame = Instance.new("Frame")
	voteFrame.Name = "VotingFrame"
	voteFrame.Size = UDim2.new(0, 500, 0, 400)
	voteFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
	voteFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	voteFrame.BackgroundTransparency = 0.1
	voteFrame.BorderSizePixel = 2
	voteFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	voteFrame.Parent = gameUI
	
	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "VotingTitle"
	titleLabel.Size = UDim2.new(1, 0, 0, 60)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "VOTE FOR THE FARTER!"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = voteFrame
	
	-- Create countdown label
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(1, 0, 0, 40)
	countdownLabel.Position = UDim2.new(0, 0, 0, 60)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "Time remaining: " .. Settings.VotingDuration .. "s"
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	countdownLabel.TextScaled = true
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Parent = voteFrame
	
	-- Create player list frame (with layout to avoid overlap)
	local playerListFrame = Instance.new("ScrollingFrame")
	playerListFrame.Name = "PlayerListFrame"
	playerListFrame.Size = UDim2.new(1, -20, 1, -220)
	playerListFrame.Position = UDim2.new(0, 10, 0, 150)
	playerListFrame.BackgroundTransparency = 1
	playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerListFrame.ScrollBarThickness = 6
	playerListFrame.Parent = voteFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0,5)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = playerListFrame
	
	-- Create instruction label
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "InstructionLabel"
	instructionLabel.Size = UDim2.new(1, 0, 0, 30)
	instructionLabel.Position = UDim2.new(0, 0, 0, 100)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Click on a player to vote for them"
	instructionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.Gotham
	instructionLabel.Parent = voteFrame
	
	-- Add voting buttons for each player
	local players = Players:GetPlayers()
	local buttonHeight = 50
	local spacing = 5
	local totalHeight = 0
	
	for i, targetPlayer in pairs(players) do
		if targetPlayer ~= player then
			local voteButton = Instance.new("TextButton")
			voteButton.Name = "VoteButton_" .. targetPlayer.Name
			voteButton.Size = UDim2.new(1, -10, 0, buttonHeight)
			voteButton.LayoutOrder = i
			voteButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			voteButton.BorderSizePixel = 1
			voteButton.BorderColor3 = Color3.fromRGB(150, 150, 150)
			voteButton.Text = targetPlayer.Name
			voteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			voteButton.TextScaled = true
			voteButton.Font = Enum.Font.GothamBold
			voteButton.Parent = playerListFrame
			
			-- Store button reference
			self.voteButtons[targetPlayer] = voteButton
			
			-- Handle button click
			voteButton.MouseButton1Click:Connect(function()
				self:selectPlayer(targetPlayer)
			end)
			
			-- Handle button hover
			voteButton.MouseEnter:Connect(function()
				if self.selectedPlayer ~= targetPlayer then
					TweenService:Create(voteButton, TweenInfo.new(0.2), {
						BackgroundColor3 = Color3.fromRGB(150, 150, 150)
					}):Play()
				end
			end)
			
			voteButton.MouseLeave:Connect(function()
				if self.selectedPlayer ~= targetPlayer then
					TweenService:Create(voteButton, TweenInfo.new(0.2), {
						BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					}):Play()
				end
			end)
			
			-- Update canvas size later through layout absolute content size
		end
	end
	
	-- Auto-update canvas size when content changes
	playerListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		playerListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)
	
	-- Create confirm vote button
	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "ConfirmVoteButton"
	confirmButton.Size = UDim2.new(0, 150, 0, 40)
	confirmButton.Position = UDim2.new(0.5, -75, 1, -50)
	confirmButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
	confirmButton.BorderSizePixel = 0
	confirmButton.Text = "CONFIRM VOTE"
	confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmButton.TextScaled = true
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.Parent = voteFrame
	
	-- Handle confirm button click
	confirmButton.MouseButton1Click:Connect(function()
		self:confirmVote()
	end)
	
	-- Start countdown
	self:startCountdown(countdownLabel)
	
	-- Store references
	self.voteFrame = voteFrame
	self.countdownLabel = countdownLabel
end

function VotingUI:selectPlayer(player)
	-- Deselect previous player
	if self.selectedPlayer and self.voteButtons[self.selectedPlayer] then
		local prevButton = self.voteButtons[self.selectedPlayer]
		TweenService:Create(prevButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		}):Play()
	end
	
	-- Select new player
	self.selectedPlayer = player
	
	if self.voteButtons[player] then
		local button = self.voteButtons[player]
		TweenService:Create(button, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		}):Play()
	end
	
	print("Selected player for vote:", player.Name)
end

function VotingUI:confirmVote()
	if not self.selectedPlayer then
		-- Show error message
		self:showMessage("Please select a player to vote for!", Color3.fromRGB(255, 0, 0))
		return
	end
	
	-- Send vote to server
	Remotes.CastVote:FireServer(self.selectedPlayer)
	
	-- Show confirmation
	self:showMessage("Vote cast for " .. self.selectedPlayer.Name .. "!", Color3.fromRGB(0, 255, 0))
	
	-- Disable all buttons
	for player, button in pairs(self.voteButtons) do
		button.Active = false
		if player == self.selectedPlayer then
			button.Text = "VOTED!"
			button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		else
			button.Text = "Vote Cast"
			button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
	end
	
	print("Vote confirmed for:", self.selectedPlayer.Name)
end

function VotingUI:showMessage(message, color)
	-- Create temporary message
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Size = UDim2.new(0, 300, 0, 50)
	messageLabel.Position = UDim2.new(0.5, -150, 0.8, 0)
	messageLabel.BackgroundColor3 = color
	messageLabel.BackgroundTransparency = 0.2
	messageLabel.Text = message
	messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	messageLabel.TextScaled = true
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.Parent = self.voteFrame
	
	-- Auto-destroy after 3 seconds
	spawn(function()
		wait(3)
		messageLabel:Destroy()
	end)
end

function VotingUI:startCountdown(countdownLabel)
	spawn(function()
		local startTime = tick()
		while self.isActive and tick() - startTime < Settings.VotingDuration do
			local remaining = Settings.VotingDuration - (tick() - startTime)
			countdownLabel.Text = "Time remaining: " .. math.ceil(remaining) .. "s"
			wait(0.1)
		end
		
		if self.isActive then
			countdownLabel.Text = "Time's up!"
		end
	end)
end

function VotingUI:destroyVotingInterface()
	if self.voteFrame then
		self.voteFrame:Destroy()
		self.voteFrame = nil
		self.countdownLabel = nil
		self.voteButtons = {}
	end
end

-- Initialize the VotingUI
local votingUI = VotingUI.new()

-- Listen for game state changes
Remotes.GameStateChanged.OnClientEvent:Connect(function(newState)
	if newState == "Voting" then
		votingUI:activate()
	else
		votingUI:deactivate()
	end
end) 