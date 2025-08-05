-- src/shared/Hello.luau
-- Shared utility module for "Who Farted?" game
-- This module can be used for shared functions between client and server

local Hello = {}

function Hello.sayHello()
	print("Welcome to Who Farted? - The ultimate social deduction game!")
end

function Hello.getGameInfo()
	return {
		name = "Who Farted?",
		version = "1.0.0",
		description = "A hilarious social deduction game where players try to identify the mysterious farter!"
	}
end

return Hello