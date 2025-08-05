-- src/shared/Settings.luau
-- Central configuration module for "Who Farted?" game
-- Contains all core game variables for easy tuning

local Settings = {
	-- Game timing durations (in seconds)
	MingleDuration = 30,
	FartWindowDuration = 10,
	InvestigationDuration = 45,
	VotingDuration = 30,
	
	-- Player requirements
	MinPlayers = 3,
	MaxPlayers = 12,
	
	-- Win conditions
	FartsToWin = 5,
	
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
	FartCloudRadius = 5, -- 10 stud diameter
	FartCloudDuration = 25, -- seconds cloud persists and investigation can be started
	-- Ability cooldowns
	FartCooldown = 20,
}

return Settings 