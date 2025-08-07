-- src/server/GameManager.server.luau
-- The authoritative game loop and state controller for "Who Farted?"
-- This is the brain of the server that manages the entire game flow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
print("Settings loaded - MinPlayers:", Settings.MinPlayers)
local Remotes = require(ReplicatedStorage.Remotes.Remotes)

-- Game state enum
local GameState = {
	LOBBY = "Lobby",
	MINGLE = "Mingle",
	FARTING = "Farting",
	INVESTIGATION = "Investigation",
	VOTING = "Voting",
	ROUND_END = "RoundEnd"
}

-- Role enum
local Role = {
	FARTER = "Farter",
	SNIFFER = "Sniffer",
	INNOCENT = "Innocent"
}

local GameManager = {}
GameManager.__index = GameManager

function GameManager.new()
	local self = setmetatable({}, GameManager)
	
	self.currentState = GameState.LOBBY
	self.players = {}
	self.roles = {}
	self.fartCount = 0
	self.votes = {}
	-- Blame-spray data (reset every round)
	self.sprayedPlayers = {}
	self.sprayUsed = false
	self.roundActive = false
	self.stateStartTime = 0
	self.activeFartClouds = {}
	-- Smelly system
	self.smellyPlayers = {} -- [Player] = true if currently smelly
	self.lastFartTime = nil -- last fart timestamp for the farter
	self.farterPlayer = nil
	self.votingScheduled = false
	
	-- Bind remote events
	self:bindRemotes()
	
	return self
end

function GameManager:bindRemotes()
	-- Handle fart actions from Farter
	Remotes.FartAction.OnServerEvent:Connect(function(player)
		if self.currentState == GameState.FARTING and self.roles[player] == Role.FARTER then
			self:handleFart(player)
		end
	end)
	
	-- Handle sniff attempts from Sniffer
	Remotes.SniffPlayer.OnServerInvoke = function(player, targetPlayer)
		if self.roles[player] == Role.SNIFFER then
			return self:handleSniff(player, targetPlayer)
		end
		return false
	end
	
	-- Handle votes from all players
	Remotes.CastVote.OnServerEvent:Connect(function(player, targetPlayer)
		if self.currentState == GameState.VOTING then
			self:handleVote(player, targetPlayer)
		end
	end)

	-- Handle blame spray activation from Farter
	Remotes.BlameSpray.OnServerEvent:Connect(function(player, targetPlayer)
		if self.currentState == GameState.MINGLE then
			self:handleBlameSpray(player, targetPlayer)
		end
	end)

	-- Handle investigation trigger from players
	Remotes.StartInvestigation.OnServerEvent:Connect(function(player)
		self:handleStartInvestigation(player)
	end)

	-- Speaker toggle from farter
	Remotes.ToggleSpeaker.OnServerEvent:Connect(function(player)
		if self.roles[player] == Role.FARTER then
			self.speakerActive = not self.speakerActive
			Remotes.SpeakerStateChanged:FireAllClients(self.speakerActive)
		end
	end)

	-- Task complete request (placeholder: accept and broadcast progress)
	Remotes.TaskCompleteRequest.OnServerEvent:Connect(function(player, taskId)
		-- TODO: validate tasks by location/interaction; for now broadcast incremental progress
		Remotes.TaskProgressUpdated:FireAllClients(player, taskId)
	end)

	-- Investigation chat relay (server-authoritative broadcast only during Investigation)
	Remotes.InvestigationChatMessage.OnServerEvent:Connect(function(player, message)
		if self.currentState ~= GameState.INVESTIGATION then return end
		if type(message) ~= "string" then return end
		message = string.sub(message, 1, 140)
		for _, p in ipairs(Players:GetPlayers()) do
			Remotes.InvestigationChatMessage:FireClient(p, player, message)
		end
	end)
end

function GameManager:start()
	-- Start the game loop
	spawn(function()
		while true do
			self:waitForPlayers()
			self:startRound()
			self:runGameLoop()
			self:endRound()
		end
	end)
end

function GameManager:waitForPlayers()
	print("[Lobby] Waiting for players to join...")

	-- Wait until at least one player joins the server
	while #Players:GetPlayers() == 0 do
		wait(0.5)
	end

	print("[Lobby] First player detected. Starting 20-second lobby countdown…")
	local lobbyCountdown = 20

	-- 20-second lobby countdown – additional players can still join during this time
	for i = lobbyCountdown, 1, -1 do
		-- Broadcast countdown to all clients
		for _, p in pairs(Players:GetPlayers()) do
			Remotes.LobbyCountdown:FireClient(p, i)
		end
		wait(1)
	end
	-- Notify clients that countdown is over (0 seconds)
	for _, p in pairs(Players:GetPlayers()) do
		Remotes.LobbyCountdown:FireClient(p, 0)
	end

	-- After countdown, ensure minimum-player requirement is met
	while #Players:GetPlayers() < Settings.MinPlayers do
		print("[Lobby] Not enough players yet (" .. #Players:GetPlayers() .. "/" .. Settings.MinPlayers .. "). Continuing to wait…")
		wait(1)
	end

	print("[Lobby] Minimum players reached. Starting game!")
end

function GameManager:startRound()
	self.roundActive = true
	self.fartCount = 0
	self.votes = {}
	self.speakerActive = false
	self.votingScheduled = false
	
	-- Only assign roles if they haven't been assigned yet
	if not self.rolesAssigned then
		self:assignRoles()
		self.rolesAssigned = true
		
		-- Notify all players of their roles
		for player, role in pairs(self.roles) do
			Remotes.RoleAssigned:FireClient(player, role)
		end
	end
	
	self.sprayedPlayers = {}
	self.sprayUsed = false
	self.activeFartClouds = {}
	self.smellyPlayers = {}
	self.lastFartTime = nil -- farter should not be smelly before first fart
	self:changeState(GameState.MINGLE)
end

function GameManager:assignRoles()
	local players = Players:GetPlayers()
	local playerCount = #players
	
	-- Shuffle players for random role assignment
	local shuffledPlayers = {}
	for i = 1, playerCount do
		shuffledPlayers[i] = players[i]
	end
	
	-- Fisher-Yates shuffle
	for i = playerCount, 2, -1 do
		local j = math.random(i)
		shuffledPlayers[i], shuffledPlayers[j] = shuffledPlayers[j], shuffledPlayers[i]
	end
	
	-- Assign roles
	self.roles[shuffledPlayers[1]] = Role.FARTER
	self.farterPlayer = shuffledPlayers[1]
	self.roles[shuffledPlayers[2]] = Role.SNIFFER
	
	-- Rest are innocent
	for i = 3, playerCount do
		self.roles[shuffledPlayers[i]] = Role.INNOCENT
	end
	
	print("Roles assigned - Farter:", shuffledPlayers[1].Name, "Sniffer:", shuffledPlayers[2].Name)
end

function GameManager:runGameLoop()
	-- Initial mingle
	self:changeState(GameState.MINGLE)
	wait(Settings.MingleDuration)

	-- Farting window
	self:changeState(GameState.FARTING)
	wait(Settings.FartWindowDuration)

	-- Return to mingle awaiting investigation trigger
	self:changeState(GameState.MINGLE)

	-- Wait for either investigation to start or timeout
	local mingleStart = tick()
	while tick() - mingleStart < Settings.InvestigationDuration do
		if self.currentState == GameState.INVESTIGATION then
			break
		end
		wait(0.5)
	end

	-- If investigation never started, proceed straight to voting
	if self.currentState == GameState.MINGLE then
		self:changeState(GameState.VOTING)
	else
		-- Investigation started by player, give it its full duration
		wait(Settings.InvestigationDuration)
		self:changeState(GameState.VOTING)
	end

	-- Voting duration
	wait(Settings.VotingDuration)

	-- Process votes
	self:processVoting()
end

function GameManager:changeState(newState)
	if self.currentState == newState then
		return
	end
	self.currentState = newState
	self.stateStartTime = tick()
	
	print("Game state changed to:", newState)
	
	-- Broadcast state change to all clients
	for _, player in pairs(Players:GetPlayers()) do
		Remotes.GameStateChanged:FireClient(player, newState)
	end
end

function GameManager:_markSmelly(player)
	self.smellyPlayers[player] = true
end

function GameManager:_clearSmelly(player)
	self.smellyPlayers[player] = nil
end

function GameManager:_refreshSmellyTimeout()
	-- Clears ALL smelly flags if farter has not farted for configured decay window
	spawn(function()
		local snapshot = self.lastFartTime
		local SettingsModule = require(ReplicatedStorage.Shared.Settings)
		wait(SettingsModule.SmellyDecaySeconds)
		-- If lastFartTime unchanged and still earlier than now-decay, clear everyone
		if self.lastFartTime == snapshot then
			for plr, _ in pairs(self.smellyPlayers) do
				self.smellyPlayers[plr] = nil
			end
		end
	end)
end

function GameManager:handleFart(player)
	if self.fartCount >= Settings.FartsToWin then
		return -- Already won
	end
	
	self.fartCount = self.fartCount + 1
	self.lastFartTime = tick()
	print("Fart detected! Count:", self.fartCount)
	
	-- Broadcast fart to all clients with position
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local position = character.HumanoidRootPart.Position
		Remotes.FartBroadcast:FireAllClients(position)

		-- Record cloud for investigation validation
		table.insert(self.activeFartClouds, {position = position, created = tick()})
		-- Cleanup after duration
		local SettingsModule = require(ReplicatedStorage.Shared.Settings)
		spawn(function()
			wait(SettingsModule.FartCloudDuration)
			-- Remove expired cloud from list
			for i=#self.activeFartClouds,1,-1 do
				if self.activeFartClouds[i] and self.activeFartClouds[i].position == position then
					table.remove(self.activeFartClouds, i)
					break
				end
			end
		end)
	end
	
	-- Apply smelly to players within fart radius (including farter)
	local fartRadius = Settings.SmellyRadius or Settings.FartCloudRadius
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and character and character:FindFirstChild("HumanoidRootPart") then
			local dist = (p.Character.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude
			if dist <= fartRadius then
				self:_markSmelly(p)
			end
		end
	end
	-- Explicitly mark farter as smelly after fart
	self:_markSmelly(player)
	
	-- Start 60s smelly decay timer relative to this fart
	self:_refreshSmellyTimeout()
	
	-- Schedule voting UI about ~45s after fart (only once per round)
	if not self.votingScheduled then
		self.votingScheduled = true
		spawn(function()
			wait(45)
			if self.roundActive and self.currentState ~= GameState.VOTING and self.currentState ~= GameState.ROUND_END then
				self:changeState(GameState.VOTING)
			end
		end)
	end
	
	-- Check win condition
	if self.fartCount >= Settings.FartsToWin then
		self:endRoundWithWinner(Role.FARTER)
	end
end

function GameManager:handleSniff(player, targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		return false
	end
	
	-- A player is smelly if marked by spray or within fart radius recently
	local sprayed = self.sprayedPlayers[targetPlayer] ~= nil and tick() < self.sprayedPlayers[targetPlayer]
	local smelly = self.smellyPlayers[targetPlayer] == true
	return sprayed or smelly
end

function GameManager:handleVote(player, targetPlayer)
	if not targetPlayer or not self.roles[targetPlayer] then
		return
	end
	
	-- Record the vote
	self.votes[player] = targetPlayer
	print(player.Name, "voted for", targetPlayer.Name)
	-- No live vote count broadcast for anonymity
end

function GameManager:processVoting()
	-- Count votes
	local voteCounts = {}
	for voter, target in pairs(self.votes) do
		voteCounts[target] = (voteCounts[target] or 0) + 1
	end
	
	-- Find most voted player
	local mostVoted = nil
	local maxVotes = 0
	
	for player, votes in pairs(voteCounts) do
		if votes > maxVotes then
			maxVotes = votes
			mostVoted = player
		end
	end
	
	-- Eject the most voted player
	if mostVoted then
		self:ejectPlayer(mostVoted)
		
		-- Check if Farter was ejected
		if self.roles[mostVoted] == Role.FARTER then
			self:endRoundWithWinner(Role.INNOCENT)
		else
			-- Farter wins if they weren't caught
			self:endRoundWithWinner(Role.FARTER)
		end
	else
		-- No votes cast, Farter wins by default
		self:endRoundWithWinner(Role.FARTER)
	end
end

function GameManager:ejectPlayer(player)
	print("Ejecting player:", player.Name)
	Remotes.PlayerVotedOut:FireAllClients(player)
	
	-- Kick the player from the game
	player:Kick("You were voted out!")
end

function GameManager:endRoundWithWinner(winningRole)
	print("Round ended! Winner:", winningRole)
	
	-- Broadcast winner to all remaining players
	for _, player in pairs(Players:GetPlayers()) do
		Remotes.GameStateChanged:FireClient(player, GameState.ROUND_END, winningRole)
	end
	
	wait(5) -- Brief pause before next round
end

function GameManager:endRound()
	self.roundActive = false
	-- Keep roles persistent across rounds
	self.votes = {}
	self.fartCount = 0
	self.smellyPlayers = {}
	self.lastFartTime = nil
	self.sprayedPlayers = {}
	self.votingScheduled = false
end

-- Handle the single-use blame spray ability
function GameManager:handleBlameSpray(player, targetPlayer)
	if self.sprayUsed then
		return -- Already used this round
	end
	if self.roles[player] ~= Role.FARTER then
		return -- Only Farter can spray
	end
	if not targetPlayer or not targetPlayer.Parent then
		return
	end

	self.sprayUsed = true
	-- mark sprayed with expiration timestamp
	local SettingsModule = require(ReplicatedStorage.Shared.Settings)
	self.sprayedPlayers[targetPlayer] = tick() + SettingsModule.SmellyDecaySeconds
	print("Blame spray applied to", targetPlayer.Name)

	-- Optional: Notify sprayed player (client-side effect could be added)
end

-- Validate and start Investigation phase if conditions met
function GameManager:handleStartInvestigation(player)
	-- Investigation can only begin from Mingle state after at least one fart cloud exists
	if self.currentState ~= GameState.MINGLE then
		return
	end

	-- Ensure there is an active cloud to investigate
	if #self.activeFartClouds == 0 then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local pos = character.HumanoidRootPart.Position

	-- Check distance to any active cloud
	local SettingsModule = require(ReplicatedStorage.Shared.Settings)
	for _, cloud in ipairs(self.activeFartClouds) do
		if (cloud.position - pos).Magnitude <= SettingsModule.FartCloudRadius then
			-- Transition to Investigation state and broadcast starter
			self:changeState(GameState.INVESTIGATION)
			for _, p in ipairs(Players:GetPlayers()) do
				Remotes.InvestigationStarted:FireClient(p, player)
			end
			return
		end
	end
end

-- Creates and equips a single-use spray Tool for the Farter
function GameManager:giveFarterSprayTool()
	local farterPlayer
	for player, role in pairs(self.roles) do
		if role == Role.FARTER then
			farterPlayer = player
			break
		end
	end
	if not farterPlayer then return end

	-- Remove any existing spray tool first
	local existing = farterPlayer.Backpack:FindFirstChild("BlameSpray")
	if existing then
		existing:Destroy()
	end
	if farterPlayer.Character then
		existing = farterPlayer.Character:FindFirstChild("BlameSpray")
		if existing then existing:Destroy() end
	end

	-- Create tool instance
	local tool = Instance.new("Tool")
	tool.Name = "BlameSpray"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("Uses", 1)

	tool.Parent = farterPlayer:WaitForChild("Backpack")
end

-- Initialize and start the game manager
local gameManager = GameManager.new()
gameManager:start()

print("GameManager initialized and started!") 