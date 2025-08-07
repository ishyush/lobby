-- src/server/MapLoader.server.luau
-- Loads the school map for the "Who Farted?" game
-- This script creates the map geometry when the server starts

-- Load the map when the server starts
-- For now, we'll create a simple map directly in the script
-- In a real implementation, you would load the map from the maps directory

local function createSimpleMap()
	-- Create the main school building
	local school = Instance.new("Model")
	school.Name = "School"
	school.Parent = workspace
	
	-- Raise offset to avoid z-fighting with studio floor
	local yOffset = 3
	
	-- Create floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(100, 1, 100)
	floor.Position = Vector3.new(0, yOffset - 0.5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(200, 200, 200)
	floor.Parent = school
	
	-- Create walls
	local walls = {
		-- North wall
		{Position = Vector3.new(0, yOffset + 10, -50), Size = Vector3.new(100, 20, 2)},
		-- South wall
		{Position = Vector3.new(0, yOffset + 10, 50), Size = Vector3.new(100, 20, 2)},
		-- East wall
		{Position = Vector3.new(50, yOffset + 10, 0), Size = Vector3.new(2, 20, 100)},
		-- West wall
		{Position = Vector3.new(-50, yOffset + 10, 0), Size = Vector3.new(2, 20, 100)},
	}
	
	for i, wallData in pairs(walls) do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Size = wallData.Size
		wall.Position = wallData.Position
		wall.Anchored = true
		wall.Material = Enum.Material.Brick
		wall.Color = Color3.fromRGB(150, 150, 150)
		wall.Parent = school
	end
	
	-- Create spawn points (raised)
	local spawnPoints = {
		Vector3.new(-30, yOffset + 5, -30),
		Vector3.new(-20, yOffset + 5, -30),
		Vector3.new(-10, yOffset + 5, -30),
		Vector3.new(10, yOffset + 5, -30),
		Vector3.new(20, yOffset + 5, -30),
		Vector3.new(30, yOffset + 5, -30),
		Vector3.new(-30, yOffset + 5, 30),
		Vector3.new(-20, yOffset + 5, 30),
		Vector3.new(-10, yOffset + 5, 30),
		Vector3.new(10, yOffset + 5, 30),
		Vector3.new(20, yOffset + 5, 30),
		Vector3.new(30, yOffset + 5, 30),
	}
	
	for i, spawnPos in pairs(spawnPoints) do
		local spawnPoint = Instance.new("SpawnLocation")
		spawnPoint.Name = "SpawnPoint" .. i
		spawnPoint.Size = Vector3.new(6, 1, 6)
		spawnPoint.Position = spawnPos
		spawnPoint.Anchored = true
		spawnPoint.Material = Enum.Material.Neon
		spawnPoint.Color = Color3.fromRGB(0, 255, 0)
		spawnPoint.Parent = school
	end
	
	return school
end

local schoolMap = createSimpleMap()

print("Map loaded successfully!")

print("Map loaded successfully!") 