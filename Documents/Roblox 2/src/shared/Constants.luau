-- src/shared/Constants.luau
--!strict

local Constants = {}

Constants.GAME_TITLE = "Who Farted?"

-- The main game place/experience ID to teleport into (public and private)
Constants.MAIN_GAME_PLACE_ID = 137444158445740

-- Lobby constraints
Constants.LOBBY_MAX_PLAYERS = 20
Constants.LOBBY_MEMORYSTORE_KEY = "WhoFarted:Lobbies"
Constants.LOBBY_TTL_SECONDS = 60 * 15 -- keep entries alive for up to 15 minutes without updates

-- Networking
Constants.REMOTES_FOLDER_NAME = "Remotes"

-- VC flow
Constants.VC_ACTIVE_KEY = "WhoFarted:VC:Active"
Constants.VC_ACTIVE_TTL_SECONDS = 60 * 10

return Constants


