-- src/client/MenuUI.client.luau
--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

-- Theme palette (fresh, modern, playful green)
local Palette = {
    bgDark = Color3.fromRGB(22, 30, 24),
    bgMid = Color3.fromRGB(28, 40, 32),
    surface = Color3.fromRGB(36, 50, 40),
    surfaceAlt = Color3.fromRGB(42, 60, 48),
    primary = Color3.fromRGB(92, 214, 136),
    primaryDark = Color3.fromRGB(48, 148, 98),
    accent = Color3.fromRGB(202, 255, 120),
    text = Color3.fromRGB(240, 252, 240),
    textMuted = Color3.fromRGB(210, 230, 210),
}

-- UI Factory helpers
local function create(instanceClass: string, props: {[string]: any}?, children: {Instance}?)
    local inst = Instance.new(instanceClass)
    if props then
        for key, value in props do
            (inst :: any)[key] = value
        end
    end
    if children then
        for _, child in children do
            child.Parent = inst
        end
    end
    return inst
end

local function UDim2FromScale(x: number, y: number)
    return UDim2.fromScale(x, y)
end

local function UDim2FromOffset(x: number, y: number)
    return UDim2.fromOffset(x, y)
end

local function makeHoverTween(button: GuiButton)
    -- Only adjust visual opacity; do NOT move Position because many buttons are laid out
    -- after creation (e.g., via UIListLayout or manual position changes). Capturing and
    -- tweening Position here causes the control to jump. Keep the effect subtle and safe.
    local normal = { BackgroundTransparency = 0.1 }
    local hover = { BackgroundTransparency = 0.06 }
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), hover):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), normal):Play()
    end)
end

local function makeHoverOpacityTween(button: GuiButton)
    local normal = { BackgroundTransparency = 0.12 }
    local hover = { BackgroundTransparency = 0.06 }
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), hover):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), normal):Play()
    end)
end

local function applyGradient(target: GuiObject, colorA: Color3, colorB: Color3)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB),
    })
    gradient.Rotation = 12
    gradient.Parent = target
    return gradient
end

local function showToast(parentGui: ScreenGui, text: string, seconds: number?)
    local label = create("TextLabel", {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.25,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = text,
        Font = Enum.Font.Gotham,
        TextScaled = true,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.05),
        Size = UDim2.fromScale(0.5, 0.07),
        ZIndex = 10,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        create("UIStroke", { Thickness = 1, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7 }),
    })
    label.Parent = parentGui
    label.TextTransparency = 1
    TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()
    task.delay(seconds or 2.0, function()
        if label then
            TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
            task.delay(0.22, function()
                if label then label:Destroy() end
            end)
        end
    end)
end

-- Blur setup
local function ensureMenuBlur(): BlurEffect
    local blur = Lighting:FindFirstChildOfClass("BlurEffect")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Size = 0
        blur.Parent = Lighting
    end
    TweenService:Create(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 18 }):Play()
    return blur
end

local function fadeOutBlur()
    local blur = Lighting:FindFirstChildOfClass("BlurEffect")
    if blur then
        TweenService:Create(blur, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 }):Play()
        task.delay(0.35, function()
            blur:Destroy()
        end)
    end
end

-- Root ScreenGui
local screen = create("ScreenGui", {
    Name = "MainMenu",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 1,
}, {})
screen.Parent = PlayerGui

-- Background frame for subtle vignette
local bg = create("Frame", {
    BackgroundColor3 = Palette.bgDark,
    BackgroundTransparency = 0.25,
    Size = UDim2.fromScale(1, 1),
    ClipsDescendants = true,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 0) }),
})
bg.Parent = screen

-- Subtle moving gradient overlay
local gradientOverlay = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
    (function()
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Palette.bgMid),
            ColorSequenceKeypoint.new(1, Palette.surface),
        })
        g.Rotation = 30
        return g
    end)(),
})
gradientOverlay.Parent = bg

task.defer(function()
    local rotation = 30
    while gradientOverlay.Parent do
        rotation += 10
        TweenService:Create(gradientOverlay.UIGradient, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = rotation % 360 }):Play()
        task.wait(3.5)
    end
end)

-- Title container
local title = create("TextLabel", {
    Name = "Title",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.28),
    Size = UDim2.fromOffset(0, 0),
    BackgroundTransparency = 1,
    Text = Constants.GAME_TITLE,
    TextColor3 = Palette.text,
    TextStrokeColor3 = Palette.primaryDark,
    TextStrokeTransparency = 0.75,
    TextSize = 72,
    Font = Enum.Font.FredokaOne,
    RichText = true,
})
title.Parent = screen

-- Title gradient + playful "puffs"
applyGradient(title, Palette.accent, Palette.primary)

local puffsFolder = create("Folder", { Name = "TitlePuffs" }, {})
puffsFolder.Parent = screen

local function spawnTitlePuff()
    local puff = create("Frame", {
        BackgroundColor3 = Palette.accent,
        BackgroundTransparency = 0.8,
        Size = UDim2.fromOffset(12, 8),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = title.Position + UDim2.fromOffset(math.random(-120, 120), -50 + math.random(-10, 10)),
        ZIndex = 0,
    }, {
        create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    puff.Parent = puffsFolder
    local goal1 = { Size = UDim2.fromOffset(56, 36), BackgroundTransparency = 1, Position = puff.Position - UDim2.fromOffset(0, math.random(14, 28)) }
    TweenService:Create(puff, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal1):Play()
    task.delay(1.15, function()
        if puff then puff:Destroy() end
    end)
end

task.defer(function()
    while screen.Parent do
        spawnTitlePuff()
        task.wait(1.6 + math.random() * 0.8)
    end
end)

-- Title animated pulse
do
    title.TextTransparency = 1
    title.TextScaled = false
    TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    task.defer(function()
        while title.Parent do
            TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextSize = 74 }):Play()
            task.wait(1.2)
            TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextSize = 72 }):Play()
            task.wait(1.2)
        end
    end)
end

-- Buttons container
local buttonContainer = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.6),
    Size = UDim2.fromScale(0.5, 0.32),
    BackgroundTransparency = 1,
}, {
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 16),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }),
})
buttonContainer.Parent = screen

local function primaryButton(text: string): TextButton
    local btn = create("TextButton", {
        Text = text,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromScale(0.6, 0.22),
        BackgroundColor3 = Palette.primary,
        BackgroundTransparency = 0.1,
        TextColor3 = Color3.fromRGB(20, 30, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 28,
        AutoButtonColor = false,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 14) }),
        create("UIStroke", { Thickness = 2, Color = Palette.primaryDark, Transparency = 0.4 }),
    })
    makeHoverTween(btn)
    applyGradient(btn, Palette.primary, Palette.accent)
    return btn
end

local function primaryStaticButton(text: string, size: UDim2?): TextButton
    local btn = create("TextButton", {
        Text = text,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = size or UDim2.fromOffset(240, 48),
        BackgroundColor3 = Color3.fromRGB(255, 200, 60),
        BackgroundTransparency = 0.12,
        TextColor3 = Color3.new(0, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        AutoButtonColor = false,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(0, 0, 0), Transparency = 0.85 }),
    })
    makeHoverOpacityTween(btn)
    return btn
end

local function smallButton(text: string): TextButton
    local btn = create("TextButton", {
        Text = text,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(120, 36),
        BackgroundColor3 = Color3.fromRGB(210, 210, 220),
        BackgroundTransparency = 0.12,
        TextColor3 = Color3.fromRGB(20, 20, 22),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        AutoButtonColor = false,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 10) }),
        create("UIStroke", { Thickness = 1, Color = Color3.fromRGB(0, 0, 0), Transparency = 0.9 }),
    })
    makeHoverOpacityTween(btn)
    return btn
end

local playButton = primaryButton("Play")
playButton.Parent = buttonContainer

local vcButton = primaryButton("Join VC Lobby")
vcButton.Parent = buttonContainer

local privateButton = primaryButton("Private Lobbies")
privateButton.Parent = buttonContainer

-- Private lobby modal
local lobbyModal = create("Frame", {
    Name = "LobbyModal",
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(0.8, 0.8),
    BackgroundColor3 = Palette.surface,
    BackgroundTransparency = 0.1,
    ClipsDescendants = true,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 12) }),
    create("UIStroke", { Thickness = 2, Color = Palette.primaryDark, Transparency = 0.6 }),
})
lobbyModal.Parent = screen

local lobbyTabs = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ClipsDescendants = true,
}, {
    create("UIPageLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        EasingStyle = Enum.EasingStyle.Quad,
        EasingDirection = Enum.EasingDirection.Out,
        TweenTime = 0,
        Padding = UDim.new(0, 0),
        Animated = false,
        Circular = false,
    }),
})
lobbyTabs.Parent = lobbyModal

-- Pages: Hub, Create, Join, Manage
local hubPage = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Hub" }, {})
local createPage = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Create" }, {})
local joinPage = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Join" }, {})
local managePage = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Name = "Manage" }, {})

hubPage.Parent = lobbyTabs
createPage.Parent = lobbyTabs
joinPage.Parent = lobbyTabs
managePage.Parent = lobbyTabs

local pageLayout = lobbyTabs.UIPageLayout :: UIPageLayout
pageLayout:JumpTo(hubPage)

local function showModal()
    -- Hide main menu elements to avoid overlap
    title.Visible = false
    buttonContainer.Visible = false
    lobbyModal.Visible = true
    lobbyModal.BackgroundTransparency = 1
    TweenService:Create(lobbyModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.1 }):Play()
end

local function hideModal()
    TweenService:Create(lobbyModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
    task.delay(0.22, function()
        lobbyModal.Visible = false
        -- Restore main menu elements
        title.Visible = true
        buttonContainer.Visible = true
    end)
end

-- Hub page content
local hubButtons = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6) }, {
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 16), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),
})
hubButtons.Parent = hubPage

local createLobbyBtn = primaryButton("Create Private Lobby")
createLobbyBtn.Parent = hubButtons

local joinLobbyBtn = primaryButton("Join Private Lobby")
joinLobbyBtn.Parent = hubButtons

local closeModalBtn = primaryButton("Back to Main Menu")
closeModalBtn.Parent = hubButtons

-- Create page content
local createInfo = create("TextLabel", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.1),
    Size = UDim2.fromScale(0.9, 0.1),
    Text = "Create a private lobby below! Friends can join you through the \"Join Private Lobby\" tab.",
    TextColor3 = Palette.text,
    Font = Enum.Font.Gotham,
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
})
createInfo.Parent = createPage

-- Use the primary green style for consistency with the rest of the UI
local confirmCreateBtn = primaryButton("Create Lobby")
confirmCreateBtn.Size = UDim2.fromOffset(240, 48)
confirmCreateBtn.AnchorPoint = Vector2.new(0.5, 1)
confirmCreateBtn.Position = UDim2.fromScale(0.5, 0.9)
confirmCreateBtn.Parent = createPage

local backFromCreateBtn = smallButton("Back")
backFromCreateBtn.AnchorPoint = Vector2.new(0, 1)
backFromCreateBtn.Position = UDim2.fromScale(0.05, 0.95)
backFromCreateBtn.Size = UDim2.fromOffset(120, 36)
backFromCreateBtn.Parent = createPage

-- Avatar mugshot + display name
local avatarContainer = create("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.34),
    Size = UDim2.fromScale(0.3, 0.28),
}, {})
avatarContainer.Parent = createPage

local avatarImage = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.45),
    Size = UDim2.fromOffset(128, 128),
    BackgroundTransparency = 1,
    Image = "rbxassetid://0",
}, {
    create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.2 }),
})
avatarImage.Parent = avatarContainer

local displayNameLabel = create("TextLabel", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.82),
    Size = UDim2.fromScale(1, 0.2),
    Text = Players.LocalPlayer.DisplayName ~= "" and Players.LocalPlayer.DisplayName or Players.LocalPlayer.Name,
    Font = Enum.Font.GothamBold,
    TextScaled = true,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextXAlignment = Enum.TextXAlignment.Center,
}, {})
displayNameLabel.Parent = avatarContainer

task.defer(function()
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok then
        avatarImage.Image = content
    end
end)

-- Join page content
local listContainer = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.8) }, {})
listContainer.Parent = joinPage

local scrolling = create("ScrollingFrame", {
    BackgroundTransparency = 0.1,
    BackgroundColor3 = Palette.surfaceAlt,
    Size = UDim2.fromScale(1, 1),
    CanvasSize = UDim2.new(),
    ScrollBarThickness = 6,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 12) }),
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) }),
})
scrolling.Parent = listContainer

local backFromJoinBtn = smallButton("Back")
backFromJoinBtn.AnchorPoint = Vector2.new(0, 1)
backFromJoinBtn.Position = UDim2.fromScale(0.05, 0.95)
backFromJoinBtn.Size = UDim2.fromOffset(120, 36)
backFromJoinBtn.Parent = joinPage

-- Global UI state shared across pages
local currentLobbyId: string? = nil

local function lobbyRow(item: { [string]: any }): Frame
    local row = create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.08, BackgroundColor3 = Palette.surface }, {
        create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center }),
    })
    local nameLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = string.format("%s's Lobby", item.hostName or "Host"),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Palette.text,
        Size = UDim2.fromScale(0.6, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    nameLabel.Parent = row
    local countLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = string.format("%d/%d", item.playerCount or 0, item.maxPlayers or 20),
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Palette.textMuted,
        Size = UDim2.fromOffset(80, 24),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    countLabel.Parent = row
    local joinBtn = primaryButton("Join")
    joinBtn.Size = UDim2.fromOffset(120, 36)
    joinBtn.Parent = row
    joinBtn.MouseButton1Click:Connect(function()
        local result = Net.JoinPrivateLobby:InvokeServer(item.lobbyId)
        if (result :: any).error == nil then
            currentLobbyId = (result :: any).lobbyId
            pageLayout:JumpTo(managePage)
            -- Render immediately from server-enriched summary if provided
            renderManageFromState(result)
            -- Retry a few times to overcome any eventual consistency
            for i = 1, 5 do
                task.delay(0.2 * i, function()
                    if currentLobbyId == (result :: any).lobbyId and lobbyModal.Visible and pageLayout.CurrentPage == managePage then
                        refreshManagePage()
                    end
                end)
            end
        end
    end)
    return row
end

-- Manage page content
local manageTitle = create("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.9, 0.12), Text = "Lobby", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Palette.text, TextXAlignment = Enum.TextXAlignment.Center })
manageTitle.Parent = managePage

local memberList = create("ScrollingFrame", { BackgroundTransparency = 0.08, BackgroundColor3 = Palette.surfaceAlt, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.9, 0.6), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6, ZIndex = 1 }, {
    create("UICorner", { CornerRadius = UDim.new(0, 12) }),
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) }),
})
memberList.Parent = managePage

local actionRow = create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.9, 0.12), ZIndex = 2 }, {
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center })
})
actionRow.Parent = managePage

-- Hidden container for host-only controls when viewer is not the host
local hiddenHostControls = Instance.new("Folder")
hiddenHostControls.Name = "HiddenHostControls"
hiddenHostControls.Parent = managePage

local startBtn = primaryButton("Start Game")
startBtn.Size = UDim2.fromOffset(180, 48)
startBtn.Parent = actionRow
startBtn.Visible = false

local leaveBtn = smallButton("Leave Lobby")
leaveBtn.Size = UDim2.fromOffset(180, 48)
leaveBtn.Parent = actionRow
leaveBtn.ZIndex = 3

-- Removed back button on manage screen; players should leave the lobby explicitly

local currentFill: boolean = true
local fillButtonsReady = false
local fillContainer: Frame = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 48) }, {
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center })
})
fillContainer.Parent = actionRow
fillContainer.Visible = false

-- By default, move host-only controls out of layout so non-hosts see only the centered Leave button
startBtn.Parent = hiddenHostControls
fillContainer.Parent = hiddenHostControls
local fillBtn = smallButton("Fill")
fillBtn.Size = UDim2.fromOffset(120, 36)
fillBtn.Parent = fillContainer
local noFillBtn = smallButton("No Fill")
noFillBtn.Size = UDim2.fromOffset(120, 36)
noFillBtn.Parent = fillContainer

local function updateFillButtonStyles()
    if currentFill then
        fillBtn.BackgroundColor3 = Color3.fromRGB(120, 230, 160)
        noFillBtn.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
    else
        fillBtn.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
        noFillBtn.BackgroundColor3 = Color3.fromRGB(120, 230, 160)
    end
end
local countdownLabel = create("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromScale(0.9, 0.08), Text = "", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Palette.accent })
countdownLabel.Parent = managePage

-- Data refreshers
function refreshJoinList()
    for _, child in scrolling:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end
    local list = Net.ListPrivateLobbies:InvokeServer()
    for _, item in list do
        lobbyRow(item).Parent = scrolling
    end
end

local function renderManageFromState(state: any)
    manageTitle.Text = "Lobby"
    for _, child in memberList:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end
    if not state or (state :: any).error then
        startBtn.Visible = false
        fillContainer.Visible = false
        if startBtn.Parent ~= hiddenHostControls then startBtn.Parent = hiddenHostControls end
        if fillContainer.Parent ~= hiddenHostControls then fillContainer.Parent = hiddenHostControls end
        return
    end
    local isHost = (state :: any).isHost == true
    local hostUserId = (state :: any).hostUserId
    local members = (state :: any).members or {}
    currentFill = (state :: any).fill ~= false
    manageTitle.Text = string.format("%s's Lobby (%d/%d)", (state :: any).hostName or "Host", (state :: any).playerCount or 1, (state :: any).maxPlayers or 20)
    for _, member in members do
        local row = create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.08, BackgroundColor3 = Palette.surface }, {
            create("UICorner", { CornerRadius = UDim.new(0, 8) }),
            create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
            create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center }),
        })
        local isMemberHost = member.userId == hostUserId
        local nameLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Text = isMemberHost and (member.name .. "  (Host)") or member.name,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = isMemberHost and Color3.fromRGB(255, 230, 90) or Palette.text,
            Size = UDim2.fromScale(0.7, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        nameLabel.Parent = row
        if isHost and member.userId ~= Players.LocalPlayer.UserId then
            local kickBtn = smallButton("Kick")
            kickBtn.AnchorPoint = Vector2.new(1, 0.5)
            kickBtn.Position = UDim2.fromScale(0.98, 0.5)
            kickBtn.Size = UDim2.fromOffset(120, 36)
            kickBtn.Parent = row
            kickBtn.MouseButton1Click:Connect(function()
                Net.KickFromLobby:InvokeServer(currentLobbyId :: string, member.userId)
                refreshManagePage()
            end)
        end
        row.Parent = memberList
    end
    startBtn.Visible = isHost
    fillContainer.Visible = isHost
    if isHost then
        if startBtn.Parent ~= actionRow then startBtn.Parent = actionRow end
        if fillContainer.Parent ~= actionRow then fillContainer.Parent = actionRow end
    else
        if startBtn.Parent ~= hiddenHostControls then startBtn.Parent = hiddenHostControls end
        if fillContainer.Parent ~= hiddenHostControls then fillContainer.Parent = hiddenHostControls end
    end
    updateFillButtonStyles()
end

function refreshManagePage()
    if not currentLobbyId then return end
    local ok, state = pcall(function()
        return Net.GetLobbyState:InvokeServer(currentLobbyId :: string)
    end)
    if ok then
        renderManageFromState(state)
    else
        renderManageFromState(nil)
    end
end

-- Wiring
playButton.MouseButton1Click:Connect(function()
    if RunService:IsStudio() then
        showToast(screen, "Teleports are disabled in Studio. Test in a live server.", 2.2)
        return
    end
    local original = playButton.Text
    playButton.Text = "Joining Game..."
    playButton.Active = false
    Net.TeleportToPublicRequested:FireServer()
    task.delay(2.0, function()
        if playButton and playButton.Parent then
            playButton.Text = original
            playButton.Active = true
        end
    end)
end)

vcButton.MouseButton1Click:Connect(function()
    if RunService:IsStudio() then
        showToast(screen, "Teleports are disabled in Studio. Test in a live server.", 2.2)
        return
    end
    Net.TeleportToVCRequested:FireServer()
end)

privateButton.MouseButton1Click:Connect(function()
    showModal()
    pageLayout:JumpTo(hubPage)
end)

closeModalBtn.MouseButton1Click:Connect(function()
    hideModal()
end)

createLobbyBtn.MouseButton1Click:Connect(function()
    pageLayout:JumpTo(createPage)
end)

joinLobbyBtn.MouseButton1Click:Connect(function()
    pageLayout:JumpTo(joinPage)
    refreshJoinList()
end)

backFromCreateBtn.MouseButton1Click:Connect(function()
    pageLayout:JumpTo(hubPage)
end)

backFromJoinBtn.MouseButton1Click:Connect(function()
    pageLayout:JumpTo(hubPage)
end)

confirmCreateBtn.MouseButton1Click:Connect(function()
    if confirmCreateBtn.AutoButtonColor == false then
        -- Simple guard against double-click; we'll temporarily disable via Active property
    end
    confirmCreateBtn.Active = false
    local originalText = confirmCreateBtn.Text
    confirmCreateBtn.Text = "Creating..."
    local ok, result = pcall(function()
        return Net.CreatePrivateLobby:InvokeServer()
    end)
    confirmCreateBtn.Active = true
    confirmCreateBtn.Text = originalText
    if ok and (result :: any) and (result :: any).error == nil and (result :: any).lobbyId then
        currentLobbyId = (result :: any).lobbyId
        pageLayout:JumpTo(managePage)
        refreshManagePage()
        showToast(screen, "Private lobby created.", 1.6)
    else
        showToast(screen, "Failed to create lobby (server not ready).", 1.8)
    end
end)

startBtn.MouseButton1Click:Connect(function()
    if currentLobbyId then
        startBtn.Active = false
        local original = startBtn.Text
        startBtn.Text = "Starting..."
        local result = Net.StartLobbyGame:InvokeServer(currentLobbyId)
        if (result :: any).ok then
            -- Teleport will happen server-side
        else
            showToast(screen, "Unable to start lobby.", 1.6)
        end
        startBtn.Text = original
        startBtn.Active = true
    end
end)

leaveBtn.MouseButton1Click:Connect(function()
    if currentLobbyId then
        Net.LeavePrivateLobby:InvokeServer(currentLobbyId)
        currentLobbyId = nil
        pageLayout:JumpTo(hubPage)
    end
end)

-- removed undefined backToHubFromManage; leaving lobby is the way back

fillBtn.MouseButton1Click:Connect(function()
    if currentLobbyId then
        currentFill = true
        updateFillButtonStyles()
        Net.SetLobbyFillMode:InvokeServer(currentLobbyId, true)
    end
end)

noFillBtn.MouseButton1Click:Connect(function()
    if currentLobbyId then
        currentFill = false
        updateFillButtonStyles()
        Net.SetLobbyFillMode:InvokeServer(currentLobbyId, false)
    end
end)

-- Respond to live lobby updates by refreshing join list or manage page if visible
Net.LobbyUpdated.OnClientEvent:Connect(function(update)
    if lobbyModal.Visible then
        if pageLayout.CurrentPage == joinPage then
            refreshJoinList()
        elseif pageLayout.CurrentPage == managePage and currentLobbyId and update.lobbyId == currentLobbyId then
            refreshManagePage()
        end
    end
end)

Net.LobbyCountdown.OnClientEvent:Connect(function(lobbyId: string, remaining: number)
    if currentLobbyId == lobbyId and pageLayout.CurrentPage == managePage then
        countdownLabel.Text = string.format("Starting in %d...", remaining)
        if remaining <= 0 then
            countdownLabel.Text = "Teleporting..."
        end
    end
end)

-- Initial experience
ensureMenuBlur()
Net.MenuReady:FireServer()


