-- src/shared/Net.luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

-- Create remotes container if needed (works in both server and client thanks to Rojo mapping)
local function getOrCreateFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("Folder") then
        return existing
    end
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local remotesFolder = getOrCreateFolder(ReplicatedStorage, Constants.REMOTES_FOLDER_NAME)

-- Helper to get-or-create a RemoteEvent
local function getRemoteEvent(name: string): RemoteEvent
    local existing = remotesFolder:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then
        return existing
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

-- Helper to get-or-create a RemoteFunction
local function getRemoteFunction(name: string): RemoteFunction
    local existing = remotesFolder:FindFirstChild(name)
    if existing and existing:IsA("RemoteFunction") then
        return existing
    end
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local Net = {}

-- Events
Net.MenuReady = getRemoteEvent("MenuReady")
Net.TeleportToPublicRequested = getRemoteEvent("TeleportToPublicRequested")
Net.TeleportToVCRequested = getRemoteEvent("TeleportToVCRequested")

-- Lobby lifecycle
Net.CreatePrivateLobby = getRemoteFunction("CreatePrivateLobby")
Net.ListPrivateLobbies = getRemoteFunction("ListPrivateLobbies")
Net.JoinPrivateLobby = getRemoteFunction("JoinPrivateLobby")
Net.LeavePrivateLobby = getRemoteFunction("LeavePrivateLobby")
Net.KickFromLobby = getRemoteFunction("KickFromLobby")
Net.StartLobbyGame = getRemoteFunction("StartLobbyGame")
Net.GetLobbyState = getRemoteFunction("GetLobbyState")
Net.SetLobbyFillMode = getRemoteFunction("SetLobbyFillMode")

-- Push updates to lobby members
Net.LobbyUpdated = getRemoteEvent("LobbyUpdated")
Net.LobbyCountdown = getRemoteEvent("LobbyCountdown")

return Net


