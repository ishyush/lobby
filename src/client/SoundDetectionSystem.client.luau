-- SOUND DETECTION SYSTEM (Spider-Sense) - DEBUG VERSION
-- Script Type: LocalScript
-- Location: StarterPlayer > StarterPlayerScripts
-- Name: SoundDetectionSystem

print("SoundDetectionSystem script started!")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
wait(1) -- Give everything time to load
print("PlayerGui found:", playerGui)

local camera = workspace.CurrentCamera

-- Create the UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoundDetectionUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
print("SoundDetectionUI created:", screenGui.Parent)

-- Container for all arrows
local arrowContainer = Instance.new("Frame")
arrowContainer.Size = UDim2.new(1, 0, 1, 0)
arrowContainer.BackgroundTransparency = 1
arrowContainer.Parent = screenGui

-- Table to track active sound sources
local soundSources = {}
local arrows = {}

-- Configuration
local CONFIG = {
    MIN_DISTANCE = 15,     -- Sounds closer than this won't show arrows (increased from 5)
    MAX_DISTANCE = 100,    -- Maximum detection range
    MIN_ARROW_SIZE = 30,   -- Smallest arrow size (pixels)
    MAX_ARROW_SIZE = 80,   -- Largest arrow size (pixels)
    ARROW_OFFSET = 100,    -- Distance from center of screen
    FADE_SPEED = 0.2,      -- How quickly arrows appear/disappear
    UPDATE_RATE = 0.03,    -- How often to update arrow positions
}

-- Blacklisted sound names and IDs that shouldn't trigger arrows
local BLACKLISTED_SOUNDS = {
    -- Common Roblox movement sound names
    ["Running"] = true,
    ["Landing"] = true,
    ["Jumping"] = true,
    ["FreeFalling"] = true,
    ["Flying"] = true,
    ["Swimming"] = true,
    ["Climbing"] = true,
    ["GettingUp"] = true,
    ["walk"] = true,
    ["run"] = true,
    ["jump"] = true,
    ["footstep"] = true,
    ["footsteps"] = true,
    
    -- Common Roblox movement sound IDs
    ["rbxasset://sounds/action_footsteps_plastic.mp3"] = true,
    ["rbxasset://sounds/action_jump.mp3"] = true,
    ["rbxasset://sounds/action_jump_land.mp3"] = true,
    ["rbxasset://sounds/impact_water_low.mp3"] = true,
    ["rbxasset://sounds/action_swim.mp3"] = true,
    ["rbxasset://sounds/action_falling.mp3"] = true,
    ["rbxasset://sounds/action_get_up.mp3"] = true,
    ["rbxasset://sounds/uuhhh.mp3"] = true, -- Death sound
}

-- Function to check if a sound should be filtered
local function shouldFilterSound(sound)
    -- Check sound name (case insensitive)
    local soundNameLower = sound.Name:lower()
    for blacklistedName, _ in pairs(BLACKLISTED_SOUNDS) do
        if soundNameLower:find(blacklistedName:lower()) then
            return true
        end
    end
    
    -- Check exact sound ID
    if sound.SoundId and BLACKLISTED_SOUNDS[sound.SoundId] then
        return true
    end
    
    -- Check if sound is inside a character's HumanoidRootPart (common for movement sounds)
    if sound.Parent and sound.Parent.Name == "HumanoidRootPart" then
        return true
    end
    
    -- Check if sound is inside a Humanoid (also common for movement sounds)
    if sound.Parent and sound.Parent:IsA("Humanoid") then
        return true
    end
    
    -- Additional check: filter sounds that are too quiet (often ambient/movement)
    if sound.Volume < 0.1 then
        return true
    end
    
    return false
end

-- Create an arrow UI element
local function createArrow()
    local arrowFrame = Instance.new("Frame")
    arrowFrame.Size = UDim2.new(0, 50, 0, 50)
    arrowFrame.BackgroundTransparency = 1
    arrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    
    -- Create arrow shape using ImageLabel (triangle)
    local arrowImage = Instance.new("ImageLabel")
    arrowImage.Size = UDim2.new(1, 0, 1, 0)
    arrowImage.BackgroundTransparency = 1
    arrowImage.Image = "rbxassetid://6034684930" -- Arrow icon
    arrowImage.ImageColor3 = Color3.new(1, 0.2, 0.2) -- Red color
    arrowImage.Parent = arrowFrame
    
    -- Alternative: Create arrow using frames (if image doesn't work)
    if not arrowImage.Image or arrowImage.Image == "" then
        arrowImage:Destroy()
        
        -- Main triangle body
        local triangle = Instance.new("Frame")
        triangle.Size = UDim2.new(0.6, 0, 1, 0)
        triangle.Position = UDim2.new(0.2, 0, 0, 0)
        triangle.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
        triangle.BorderSizePixel = 0
        triangle.Parent = arrowFrame
        
        -- Triangle point (using rotation)
        local point1 = Instance.new("Frame")
        point1.Size = UDim2.new(0.7, 0, 0.7, 0)
        point1.Position = UDim2.new(-0.1, 0, -0.1, 0)
        point1.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
        point1.BorderSizePixel = 0
        point1.Rotation = 45
        point1.Parent = triangle
        
        local point2 = Instance.new("Frame")
        point2.Size = UDim2.new(0.7, 0, 0.7, 0)
        point2.Position = UDim2.new(0.4, 0, -0.1, 0)
        point2.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
        point2.BorderSizePixel = 0
        point2.Rotation = 45
        point2.Parent = triangle
    end
    
    arrowFrame.Parent = arrowContainer
    return arrowFrame
end

-- Calculate screen position for arrow based on sound direction
local function calculateArrowPosition(soundPosition, characterPosition)
    -- Get direction vector from character to sound
    local direction = (soundPosition - characterPosition).Unit
    
    -- Convert 3D direction to 2D screen space
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    -- Get camera look direction
    local cameraLook = camera.CFrame.LookVector
    local cameraRight = camera.CFrame.RightVector
    local cameraUp = camera.CFrame.UpVector
    
    -- Calculate angle relative to camera
    local forward = Vector2.new(cameraLook.X, cameraLook.Z).Unit
    local right = Vector2.new(cameraRight.X, cameraRight.Z).Unit
    
    local soundDir2D = Vector2.new(direction.X, direction.Z).Unit
    
    -- Calculate angle using dot product and cross product
    local dotForward = soundDir2D:Dot(forward)
    local dotRight = soundDir2D:Dot(right)
    
    local angle = math.atan2(dotRight, dotForward)
    
    -- Position arrow on screen edge
    local radius = math.min(camera.ViewportSize.X, camera.ViewportSize.Y) / 2 - CONFIG.ARROW_OFFSET
    local x = screenCenter.X + math.sin(angle) * radius
    local y = screenCenter.Y - math.cos(angle) * radius
    
    -- Calculate rotation for arrow to point at sound
    local rotation = math.deg(angle)
    
    return Vector2.new(x, y), rotation
end

-- Update or create arrow for a sound source
local function updateArrow(sourceId, soundPosition, isActive)
    print("updateArrow called for:", sourceId, "Active:", isActive)
    
    local character = player.Character
    if not character then 
        print("No character found")
        return 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        print("No HumanoidRootPart found")
        return 
    end
    
    local distance = (soundPosition - humanoidRootPart.Position).Magnitude
    print("Distance to sound:", distance)
    
    -- Check if sound is within range
    if distance < CONFIG.MIN_DISTANCE then
        print("Sound too close:", distance, "<", CONFIG.MIN_DISTANCE)
        -- Fade out and remove arrow code here...
        if arrows[sourceId] then
            local arrow = arrows[sourceId]
            if arrow.Parent then
                local imageLabel = arrow:FindFirstChild("ImageLabel")
                if imageLabel then
                    local fadeOut = TweenService:Create(imageLabel, TweenInfo.new(CONFIG.FADE_SPEED), {
                        ImageTransparency = 1
                    })
                    fadeOut:Play()
                    fadeOut.Completed:Connect(function()
                        if arrow.Parent then
                            arrow:Destroy()
                        end
                        arrows[sourceId] = nil
                    end)
                else
                    for _, child in pairs(arrow:GetDescendants()) do
                        if child:IsA("Frame") then
                            TweenService:Create(child, TweenInfo.new(CONFIG.FADE_SPEED), {
                                BackgroundTransparency = 1
                            }):Play()
                        end
                    end
                    task.wait(CONFIG.FADE_SPEED)
                    if arrow.Parent then
                        arrow:Destroy()
                    end
                    arrows[sourceId] = nil
                end
            end
        end
        return
    elseif distance > CONFIG.MAX_DISTANCE then
        print("Sound too far:", distance, ">", CONFIG.MAX_DISTANCE)
        return
    elseif not isActive then
        print("Sound not active")
        return
    end
    
    -- Create arrow if it doesn't exist
    if not arrows[sourceId] then
        arrows[sourceId] = createArrow()
        print("Created arrow for:", sourceId)
        print("Arrow parent:", arrows[sourceId].Parent)
    end
    
    local arrow = arrows[sourceId]
    
    -- Make sure arrow is visible
    arrow.Visible = true
    
    -- Calculate position and rotation
    local screenPos, rotation = calculateArrowPosition(soundPosition, humanoidRootPart.Position)
    
    -- Calculate size based on distance (closer = bigger)
    local distanceRatio = 1 - ((distance - CONFIG.MIN_DISTANCE) / (CONFIG.MAX_DISTANCE - CONFIG.MIN_DISTANCE))
    local arrowSize = CONFIG.MIN_ARROW_SIZE + (CONFIG.MAX_ARROW_SIZE - CONFIG.MIN_ARROW_SIZE) * distanceRatio
    
    -- Update arrow properties
    arrow.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
    arrow.Size = UDim2.new(0, arrowSize, 0, arrowSize)
    arrow.Rotation = rotation
    arrow.ZIndex = 10 + math.floor(distance) -- Ensure arrows don't overlap in Z order
    
    -- Debug position
    print(string.format("Arrow %s at screen pos: %.1f, %.1f | Rotation: %.1f", 
        sourceId:sub(1, 20), screenPos.X, screenPos.Y, rotation))
    
    -- Update transparency based on distance
    local targetTransparency = 0.2 + (1 - distanceRatio) * 0.5
    if arrow:FindFirstChild("ImageLabel") then
        arrow.ImageLabel.ImageTransparency = targetTransparency
    else
        for _, child in pairs(arrow:GetDescendants()) do
            if child:IsA("Frame") then
                child.BackgroundTransparency = targetTransparency
            end
        end
    end
end

-- Monitor sound sources in the game
local function monitorSounds()
    print("Monitoring sounds...")
    
    -- Create a temporary table to track current sounds
    local currentSounds = {}
    
    -- Check for ANY playing sounds in the workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Sound") and obj.IsPlaying then
            print("Found playing sound:", obj.Name, "at", obj.Parent)
            
            -- Filter out movement/footstep sounds
            if shouldFilterSound(obj) then
                print("Filtered out:", obj.Name)
                continue -- Skip this sound
            end
            
            print("Sound passed filter:", obj.Name)
            
            -- Skip if sound has no parent with a position
            local parent = obj.Parent
            if not parent or not parent:IsA("BasePart") then
                -- Try to find a part in the parent model
                if parent and parent:IsA("Model") then
                    local primaryPart = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        parent = primaryPart
                    else
                        print("No part found for position")
                        continue -- Skip this sound if no position available
                    end
                else
                    print("Parent is not a part or model")
                    continue
                end
            end
            
            -- Get position after confirming parent exists
            local position = parent.Position
            print("Sound position:", position)
            
            -- Create unique ID using sound instance hash and position
            local sourceId = string.format("%s_%s_%.1f_%.1f_%.1f", 
                tostring(obj):match("([x%w]+)$") or tostring(obj),
                obj.Name,
                position.X,
                position.Y,
                position.Z
            )
            print("Created sourceId:", sourceId)
            
            -- Add to current sounds
            currentSounds[sourceId] = {
                sound = obj,
                position = position,
                type = obj.Name -- Store the sound name for reference
            }
        end
    end
    
    -- Remove arrows for sounds that stopped playing
    for sourceId, data in pairs(soundSources) do
        if not currentSounds[sourceId] then
            soundSources[sourceId] = nil
            if arrows[sourceId] then
                updateArrow(sourceId, Vector3.new(0, 0, 0), false)
            end
        end
    end
    
    -- Add new sounds and update existing ones
    for sourceId, data in pairs(currentSounds) do
        soundSources[sourceId] = data
        updateArrow(sourceId, data.position, true)
    end
    
    -- Debug: Print active sound count and arrow count
    local soundCount = 0
    local arrowCount = 0
    for _ in pairs(soundSources) do
        soundCount = soundCount + 1
    end
    for _ in pairs(arrows) do
        arrowCount = arrowCount + 1
    end
    if soundCount > 0 then
        print(string.format("Active sounds: %d, Active arrows: %d", soundCount, arrowCount))
    end
end

-- Main update loop
RunService.Heartbeat:Connect(function()
    monitorSounds()
end)

-- Clean up on character death/respawn
player.CharacterRemoving:Connect(function()
    for _, arrow in pairs(arrows) do
        arrow:Destroy()
    end
    arrows = {}
    soundSources = {}
end)

print("SoundDetectionSystem fully loaded!")