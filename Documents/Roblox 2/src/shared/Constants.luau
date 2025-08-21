-- src/shared/Constants.luau
--!strict

local Constants = {}

Constants.GAME_TITLE = "Who Farted?"

-- The main game place/experience ID to teleport into (public and private)
Constants.MAIN_GAME_PLACE_ID = 125356266609970

-- Lobby constraints
Constants.LOBBY_MAX_PLAYERS = 20
Constants.LOBBY_MEMORYSTORE_KEY = "WhoFarted:Lobbies"
Constants.LOBBY_TTL_SECONDS = 60 * 15 -- keep entries alive for up to 15 minutes without updates

-- Networking
Constants.REMOTES_FOLDER_NAME = "Remotes"

-- VC flow
Constants.VC_ACTIVE_KEY = "WhoFarted:VC:Active"
Constants.VC_ACTIVE_TTL_SECONDS = 60 * 10

-- Menu place configuration and camera animation
-- Set true in your lobby/menu place to enable the in-world camera fly-through background
Constants.IS_MENU_PLACE = true

-- Menu camera path (hallway fly-through)
Constants.MENU_CAMERA_START = Vector3.new(-4739.3466796875, -2109.341552734375, -1581.9036865234375)
Constants.MENU_CAMERA_END = Vector3.new(-4403.02392578125, -2101.785400390625, -1582.146728515625)
Constants.MENU_CAMERA_SPEED_STUDS_PER_SEC = 8 -- lower is slower
Constants.MENU_CAMERA_PAUSE_SECONDS = 5
Constants.MENU_CAMERA_FOV = 70

return Constants


