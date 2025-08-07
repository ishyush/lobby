-- src/remotes/Remotes.luau
-- Centralized remote events and functions for "Who Farted?" game
-- This module ensures remotes are SINGLETONS shared by server and clients.
-- Remotes are created ONCE by the server; clients will simply WaitForChild.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Guarantee a folder to hold all remotes exists
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Helper to retrieve or create a remote instance
local function getRemote(remoteClass: string, name: string)
	if RunService:IsServer() then
		-- Server: create once, or return existing
		local remote = remotesFolder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(remoteClass)
			remote.Name = name
			remote.Parent = remotesFolder
		end
		return remote
	else
		-- Client: wait for the server-created remote to be present
		return remotesFolder:WaitForChild(name) :: any
	end
end

local Remotes = {
	-- Game State Management
	GameStateChanged = getRemote("RemoteEvent", "GameStateChanged"),

	-- Lobby Countdown Broadcast
	LobbyCountdown = getRemote("RemoteEvent", "LobbyCountdown"),

	-- Role Assignment
	RoleAssigned = getRemote("RemoteEvent", "RoleAssigned"),

	-- Fart Mechanics
	FartAction = getRemote("RemoteEvent", "FartAction"),
	FartBroadcast = getRemote("RemoteEvent", "FartBroadcast"),
	-- Blame Spray (Farter ability)
	BlameSpray = getRemote("RemoteEvent", "BlameSpray"),

	-- Sniffer Ability
	SniffPlayer = getRemote("RemoteFunction", "SniffPlayer"),

	-- Investigation Trigger
	StartInvestigation = getRemote("RemoteEvent", "StartInvestigation"),
	InvestigationStarted = getRemote("RemoteEvent", "InvestigationStarted"),
	InvestigationChatMessage = getRemote("RemoteEvent", "InvestigationChatMessage"),

	-- Voting System
	CastVote = getRemote("RemoteEvent", "CastVote"),
	PlayerVotedOut = getRemote("RemoteEvent", "PlayerVotedOut"),
	VoteCountsUpdated = getRemote("RemoteEvent", "VoteCountsUpdated"),

	-- Environment / Systems
	SpeakerStateChanged = getRemote("RemoteEvent", "SpeakerStateChanged"),
	ToggleSpeaker = getRemote("RemoteEvent", "ToggleSpeaker"),

	-- Tasks
	TaskCompleteRequest = getRemote("RemoteEvent", "TaskCompleteRequest"),
	TaskProgressUpdated = getRemote("RemoteEvent", "TaskProgressUpdated"),
}

return Remotes 