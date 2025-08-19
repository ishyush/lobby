-- src/server/Bootstrap.server.luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require to ensure remotes are created on server startup
require(ReplicatedStorage.Shared.Net)

-- Do not require `LobbyManager` here; it's a Script and runs automatically.


