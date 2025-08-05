-- maps/School/Map.luau
-- Simple school map for "Who Farted?" game
-- Creates basic school geometry with rooms and hallways

local Map = {}

function Map.create()
	-- Create the main school building
	local school = Instance.new("Model")
	school.Name = "School"
	school.Parent = workspace
	
	-- Create floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(100, 1, 100)
	floor.Position = Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(200, 200, 200)
	floor.Parent = school
	
	-- Create walls
	local walls = {
		-- North wall
		{Position = Vector3.new(0, 10, -50), Size = Vector3.new(100, 20, 2)},
		-- South wall
		{Position = Vector3.new(0, 10, 50), Size = Vector3.new(100, 20, 2)},
		-- East wall
		{Position = Vector3.new(50, 10, 0), Size = Vector3.new(2, 20, 100)},
		-- West wall
		{Position = Vector3.new(-50, 10, 0), Size = Vector3.new(2, 20, 100)},
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
	
	-- Create interior walls for rooms
	local interiorWalls = {
		-- Classroom 1 (top left)
		{Position = Vector3.new(-25, 10, -25), Size = Vector3.new(40, 20, 2)},
		{Position = Vector3.new(-45, 10, -15), Size = Vector3.new(2, 20, 20)},
		
		-- Classroom 2 (top right)
		{Position = Vector3.new(25, 10, -25), Size = Vector3.new(40, 20, 2)},
		{Position = Vector3.new(45, 10, -15), Size = Vector3.new(2, 20, 20)},
		
		-- Classroom 3 (bottom left)
		{Position = Vector3.new(-25, 10, 25), Size = Vector3.new(40, 20, 2)},
		{Position = Vector3.new(-45, 10, 15), Size = Vector3.new(2, 20, 20)},
		
		-- Classroom 4 (bottom right)
		{Position = Vector3.new(25, 10, 25), Size = Vector3.new(40, 20, 2)},
		{Position = Vector3.new(45, 10, 15), Size = Vector3.new(2, 20, 20)},
		
		-- Central hallway dividers
		{Position = Vector3.new(-15, 10, 0), Size = Vector3.new(2, 20, 100)},
		{Position = Vector3.new(15, 10, 0), Size = Vector3.new(2, 20, 100)},
	}
	
	for i, wallData in pairs(interiorWalls) do
		local wall = Instance.new("Part")
		wall.Name = "InteriorWall" .. i
		wall.Size = wallData.Size
		wall.Position = wallData.Position
		wall.Anchored = true
		wall.Material = Enum.Material.Brick
		wall.Color = Color3.fromRGB(120, 120, 120)
		wall.Parent = school
	end
	
	-- Create doors (openings)
	local doors = {
		-- Classroom 1 door
		{Position = Vector3.new(-25, 5, -15), Size = Vector3.new(6, 10, 2)},
		-- Classroom 2 door
		{Position = Vector3.new(25, 5, -15), Size = Vector3.new(6, 10, 2)},
		-- Classroom 3 door
		{Position = Vector3.new(-25, 5, 15), Size = Vector3.new(6, 10, 2)},
		-- Classroom 4 door
		{Position = Vector3.new(25, 5, 15), Size = Vector3.new(6, 10, 2)},
	}
	
	for i, doorData in pairs(doors) do
		local door = Instance.new("Part")
		door.Name = "Door" .. i
		door.Size = doorData.Size
		door.Position = doorData.Position
		door.Anchored = true
		door.Material = Enum.Material.Wood
		door.Color = Color3.fromRGB(139, 69, 19)
		door.Parent = school
	end
	
	-- Create some furniture (desks and chairs)
	local desks = {
		-- Classroom 1 desks
		{Position = Vector3.new(-35, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-30, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-25, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-20, 1, -20), Size = Vector3.new(4, 2, 2)},
		
		-- Classroom 2 desks
		{Position = Vector3.new(20, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(25, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(30, 1, -20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(35, 1, -20), Size = Vector3.new(4, 2, 2)},
		
		-- Classroom 3 desks
		{Position = Vector3.new(-35, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-30, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-25, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(-20, 1, 20), Size = Vector3.new(4, 2, 2)},
		
		-- Classroom 4 desks
		{Position = Vector3.new(20, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(25, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(30, 1, 20), Size = Vector3.new(4, 2, 2)},
		{Position = Vector3.new(35, 1, 20), Size = Vector3.new(4, 2, 2)},
	}
	
	for i, deskData in pairs(desks) do
		local desk = Instance.new("Part")
		desk.Name = "Desk" .. i
		desk.Size = deskData.Size
		desk.Position = deskData.Position
		desk.Anchored = true
		desk.Material = Enum.Material.Wood
		desk.Color = Color3.fromRGB(160, 82, 45)
		desk.Parent = school
	end
	
	-- Create spawn points
	local spawnPoints = {
		Vector3.new(-30, 5, -30),
		Vector3.new(-20, 5, -30),
		Vector3.new(-10, 5, -30),
		Vector3.new(10, 5, -30),
		Vector3.new(20, 5, -30),
		Vector3.new(30, 5, -30),
		Vector3.new(-30, 5, 30),
		Vector3.new(-20, 5, 30),
		Vector3.new(-10, 5, 30),
		Vector3.new(10, 5, 30),
		Vector3.new(20, 5, 30),
		Vector3.new(30, 5, 30),
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
	
	-- Create lighting
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(100, 100, 100)
	lighting.Brightness = 2
	lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
	
	-- Create ceiling lights
	local lights = {
		{Position = Vector3.new(-25, 19, -25)},
		{Position = Vector3.new(25, 19, -25)},
		{Position = Vector3.new(-25, 19, 25)},
		{Position = Vector3.new(25, 19, 25)},
		{Position = Vector3.new(0, 19, 0)},
	}
	
	for i, lightData in pairs(lights) do
		local light = Instance.new("PointLight")
		light.Name = "Light" .. i
		light.Position = lightData.Position
		light.Range = 30
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Parent = school
	end
	
	print("School map created successfully!")
	return school
end

return Map 