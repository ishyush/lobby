-- src/shared/Settings.luau
-- Central configuration module for "Who Farted?" game
-- Contains all core game variables for easy tuning

local Settings = {
	-- Game timing durations (in seconds)
	MingleDuration = 15, -- initial lock period
	FartWindowDuration = 10, -- fart action window when bar appears
	InvestigationDuration = 45,
	VotingDuration = 10,
	
	-- Player requirements
	MinPlayers = 3,
	MaxPlayers = 12,
	
	-- Win conditions
	FartsToWin = 10,
	
	-- Role counts
	SnifferCount = 1,
	
	-- Visual and audio settings
	FartSoundId = "rbxassetid://8551016315", -- Updated sound ID as requested
	SniffEffectDuration = 2,
	VoteEffectDuration = 1,
	
	-- UI settings
	UIFadeTime = 0.3,
	CountdownUpdateInterval = 0.1,
	-- Fart cloud settings
	FartCloudRadius = 5, -- 10 stud diameter (investigation radius)
	FartCloudDuration = 25, -- seconds cloud persists and investigation can be started
	-- Ability cooldowns
	FartCooldown = 20,
	
	-- Smelly logic
	SmellyDecaySeconds = 60,
	SmellyRadius = 7,
}

return Settings 