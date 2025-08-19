-- src/server/LobbyManager.server.luau
--!strict

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService") :: any
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

export type Lobby = {
    lobbyId: string,
    hostUserId: number,
    hostName: string,
    createdAt: number,
    players: {number},
    starting: boolean?,
    fill: boolean?,
}

local PRIVATE_SERVER_RESERVATION: {[string]: string} = {}

-- Accessors guarded for Studio where MemoryStore APIs may be unavailable
local function safeGetSortedMap(key: string)
    local okMethod, fn = pcall(function()
        return (MemoryStoreService :: any).GetSortedMap
    end)
    if not okMethod or typeof(fn) ~= "function" then
        return nil
    end
    local ok, map = pcall(function()
        return (fn :: any)(MemoryStoreService, key)
    end)
    if ok then return map else return nil end
end

local function safeGetMap(key: string)
    local okMethod, fn = pcall(function()
        return (MemoryStoreService :: any).GetMap
    end)
    if not okMethod or typeof(fn) ~= "function" then
        return nil
    end
    local ok, map = pcall(function()
        return (fn :: any)(MemoryStoreService, key)
    end)
    if ok then return map else return nil end
end

local lobbyIndexDict = safeGetSortedMap(Constants.LOBBY_MEMORYSTORE_KEY .. ":Index")
local lobbyStore = safeGetMap(Constants.LOBBY_MEMORYSTORE_KEY .. ":Store")
local vcStore = safeGetMap(Constants.VC_ACTIVE_KEY)

-- Fallback in-memory storage for Studio when MemoryStore isn't available
local fallbackStore: {[string]: Lobby} = {}
local fallbackIndex: {[string]: number} = {}

local function now(): number
    return os.clock()
end

local function newLobbyId(): string
    return ("L-%d-%d"):format(os.time(), math.random(100000, 999999))
end

local function toSummary(lobby: Lobby)
    return {
        lobbyId = lobby.lobbyId,
        hostUserId = lobby.hostUserId,
        hostName = lobby.hostName,
        playerCount = #lobby.players,
        maxPlayers = Constants.LOBBY_MAX_PLAYERS,
        createdAt = lobby.createdAt,
        fill = lobby.fill == nil and true or lobby.fill,
    }
end

local function publishLobbyUpdate(lobby: Lobby)
    Net.LobbyUpdated:FireAllClients(toSummary(lobby))
end

local function readLobby(lobbyId: string): Lobby?
    local ok, value = pcall(function()
        return lobbyStore and lobbyStore:GetAsync(lobbyId) or nil
    end)
    if ok and value ~= nil then
        return value :: any
    end
    return fallbackStore[lobbyId]
end

local function writeLobby(lobby: Lobby)
    pcall(function()
        if lobbyStore then
            lobbyStore:SetAsync(lobby.lobbyId, lobby, Constants.LOBBY_TTL_SECONDS)
        end
    end)
    pcall(function()
        if lobbyIndexDict then
            lobbyIndexDict:SetAsync(lobby.lobbyId, now(), Constants.LOBBY_TTL_SECONDS)
        end
    end)
    -- Mirror to fallback for Studio testing
    fallbackStore[lobby.lobbyId] = lobby
    fallbackIndex[lobby.lobbyId] = now()
    publishLobbyUpdate(lobby)
end

local function deleteLobby(lobbyId: string)
    pcall(function()
        if lobbyStore then
            lobbyStore:RemoveAsync(lobbyId)
        end
    end)
    pcall(function()
        if lobbyIndexDict then
            lobbyIndexDict:RemoveAsync(lobbyId)
        end
    end)
    fallbackStore[lobbyId] = nil
    fallbackIndex[lobbyId] = nil :: any
    Net.LobbyUpdated:FireAllClients({ lobbyId = lobbyId, deleted = true })
end

local function ensurePlayerInLobby(lobby: Lobby, userId: number): boolean
    for _, id in lobby.players do
        if id == userId then
            return true
        end
    end
    return false
end

local function removePlayerFromLobby(lobby: Lobby, userId: number)
    local result = {}
    for _, id in lobby.players do
        if id ~= userId then
            table.insert(result, id)
        end
    end
    lobby.players = result
end

-- Remote: CreatePrivateLobby
Net.CreatePrivateLobby.OnServerInvoke = function(player: Player)
    -- Best-effort: don't block creation in Studio where MemoryStore may be unavailable.
    local lobby: Lobby = {
        lobbyId = newLobbyId(),
        hostUserId = player.UserId,
        hostName = player.DisplayName ~= "" and player.DisplayName or player.Name,
        createdAt = now(),
        players = { player.UserId },
        starting = false,
        fill = true,
    }
    -- Persist and publish; if MemoryStore fails (e.g., Studio), still return a summary so
    -- the client transitions into the manage page. Join list may not update until store works.
    pcall(function()
        writeLobby(lobby)
    end)
    return toSummary(lobby)
end

-- Remote: ListPrivateLobbies
Net.ListPrivateLobbies.OnServerInvoke = function(player: Player)
    local entries = {}
    local pageSize = 100
    local ok, pages = pcall(function()
        return lobbyIndexDict and lobbyIndexDict:GetRangeAsync(Enum.SortDirection.Ascending, pageSize) or {}
    end)
    if ok then
        for _, kv in pages do
            local lobbyId = kv.key
            local lobby = readLobby(lobbyId)
            if lobby then
                table.insert(entries, toSummary(lobby))
            end
        end
        return entries
    end
    -- Fallback listing from in-memory store (Studio)
    local sortable: {{ id: string, t: number }} = {}
    for id, t in fallbackIndex do
        table.insert(sortable, { id = id, t = t })
    end
    table.sort(sortable, function(a, b)
        return a.t < b.t
    end)
    local count = 0
    for _, item in sortable do
        local lobby = fallbackStore[item.id]
        if lobby then
            table.insert(entries, toSummary(lobby))
            count += 1
            if count >= pageSize then break end
        end
    end
    return entries
end

-- Remote: JoinPrivateLobby(lobbyId)
Net.JoinPrivateLobby.OnServerInvoke = function(player: Player, lobbyId: string)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { error = "LobbyNotFound" }
    end
    if lobby.starting then
        return { error = "Starting" }
    end
    if #lobby.players >= Constants.LOBBY_MAX_PLAYERS then
        return { error = "LobbyFull" }
    end
    if not ensurePlayerInLobby(lobby, player.UserId) then
        table.insert(lobby.players, player.UserId)
        writeLobby(lobby)
    end
    -- Return enriched state to the caller so clients can render immediately
    local enriched = toSummary(lobby)
    local members = {}
    for _, userId in lobby.players do
        local name = (function()
            local plr = Players:GetPlayerByUserId(userId)
            if plr then
                return (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            end
            local ok, resolvedName = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            if ok then return resolvedName end
            return ("User %d"):format(userId)
        end)()
        table.insert(members, { userId = userId, name = name })
    end
    enriched.members = members
    enriched.isHost = lobby.hostUserId == player.UserId
    enriched.hostUserId = lobby.hostUserId
    return enriched
end

-- Remote: LeavePrivateLobby(lobbyId)
Net.LeavePrivateLobby.OnServerInvoke = function(player: Player, lobbyId: string)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { ok = true }
    end
    removePlayerFromLobby(lobby, player.UserId)
    if #lobby.players == 0 or lobby.hostUserId == player.UserId then
        deleteLobby(lobby.lobbyId)
        return { ok = true }
    else
        writeLobby(lobby)
        return toSummary(lobby)
    end
end

-- Remote: KickFromLobby(lobbyId, userId)
Net.KickFromLobby.OnServerInvoke = function(player: Player, lobbyId: string, targetUserId: number)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { error = "LobbyNotFound" }
    end
    if lobby.hostUserId ~= player.UserId then
        return { error = "NotHost" }
    end
    removePlayerFromLobby(lobby, targetUserId)
    writeLobby(lobby)
    return toSummary(lobby)
end

-- Helper to resolve Players array to instances and names
local function resolvePlayersByUserId(userIds: {number}): {Player}
    local result: {Player} = {}
    for _, userId in userIds do
        local plr = Players:GetPlayerByUserId(userId)
        if plr then
            table.insert(result, plr)
        end
    end
    return result
end

-- Remote: StartLobbyGame(lobbyId)
Net.StartLobbyGame.OnServerInvoke = function(player: Player, lobbyId: string)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { error = "LobbyNotFound" }
    end
    if lobby.hostUserId ~= player.UserId then
        return { error = "NotHost" }
    end

    local playersToTeleport = resolvePlayersByUserId(lobby.players)
    if #playersToTeleport == 0 then
        deleteLobby(lobby.lobbyId)
        return { error = "NoPlayers" }
    end

    -- Start 20-second countdown
    lobby.starting = true
    writeLobby(lobby)
    for remaining = 20, 1, -1 do
        Net.LobbyCountdown:FireAllClients(lobby.lobbyId, remaining)
        task.wait(1)
        -- If lobby was deleted during countdown, abort
        if not readLobby(lobby.lobbyId) then
            return { error = "Aborted" }
        end
    end

    local placeId = Constants.MAIN_GAME_PLACE_ID

    local accessCode: string
    local ok, result = pcall(function()
        return TeleportService:ReserveServer(placeId)
    end)
    if not ok then
        return { error = "ReserveFailed" }
    end
    accessCode = result
    PRIVATE_SERVER_RESERVATION[lobby.lobbyId] = accessCode

    local teleportData = {
        lobbyId = lobby.lobbyId,
        hostUserId = lobby.hostUserId,
        isPrivate = true,
        fill = lobby.fill == nil and true or lobby.fill,
    }

    pcall(function()
        TeleportService:TeleportToPrivateServer(placeId, accessCode, playersToTeleport, nil, teleportData)
    end)

    deleteLobby(lobby.lobbyId)
    return { ok = true }
end

-- Remote: GetLobbyState(lobbyId)
Net.GetLobbyState.OnServerInvoke = function(player: Player, lobbyId: string)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { error = "LobbyNotFound" }
    end
    -- Enrich with player names for UI
    local members = {}
    for _, userId in lobby.players do
        local name = (function()
            local plr = Players:GetPlayerByUserId(userId)
            if plr then
                return (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            end
            local ok, resolvedName = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            if ok then return resolvedName end
            return ("User %d"):format(userId)
        end)()
        table.insert(members, { userId = userId, name = name })
    end
    local summary = toSummary(lobby)
    summary.members = members
    summary.isHost = lobby.hostUserId == player.UserId
    summary.hostUserId = lobby.hostUserId
    return summary
end

-- Remote: SetLobbyFillMode(lobbyId, fill:boolean)
Net.SetLobbyFillMode.OnServerInvoke = function(player: Player, lobbyId: string, fill: boolean)
    local lobby = readLobby(lobbyId)
    if not lobby then
        return { error = "LobbyNotFound" }
    end
    if lobby.hostUserId ~= player.UserId then
        return { error = "NotHost" }
    end
    lobby.fill = fill
    writeLobby(lobby)
    return toSummary(lobby)
end

-- Public matchmaking: simple forward to random public server
Net.TeleportToPublicRequested.OnServerEvent:Connect(function(player: Player)
    local ok, err = pcall(function()
        TeleportService:TeleportAsync(Constants.MAIN_GAME_PLACE_ID, { player })
    end)
    if not ok then
        warn("Teleport failed for", player, err)
    end
end)

-- VC teleport: try to place in an existing reserved VC private server, otherwise create one
local function getActiveVCReservation(): string?
    if not vcStore then return nil end
    local ok, code = pcall(function()
        return vcStore:GetAsync("reservation")
    end)
    if ok then
        return code
    end
    return nil
end

local function setActiveVCReservation(code: string)
    pcall(function()
        if vcStore then
            vcStore:SetAsync("reservation", code, Constants.VC_ACTIVE_TTL_SECONDS)
        end
    end)
end

local function clearActiveVCReservation()
    pcall(function()
        if vcStore then
            vcStore:RemoveAsync("reservation")
        end
    end)
end

Net.TeleportToVCRequested.OnServerEvent:Connect(function(player: Player)
    local placeId = Constants.MAIN_GAME_PLACE_ID
    local accessCode = getActiveVCReservation()
    if not accessCode then
        local ok, codeOrErr = pcall(function()
            return TeleportService:ReserveServer(placeId)
        end)
        if not ok then
            warn("Reserve VC failed", codeOrErr)
            return
        end
        accessCode = codeOrErr :: string
        setActiveVCReservation(accessCode)
    end

    local okTeleport, errTeleport = pcall(function()
        TeleportService:TeleportToPrivateServer(placeId, accessCode :: string, { player }, nil, { isVC = true })
    end)
    if not okTeleport then
        warn("Teleport VC failed", errTeleport)
    end
end)

-- Clean-up: If a player leaves, remove from any lobby they're in
Players.PlayerRemoving:Connect(function(player: Player)
    local pageSize = 100
    local ok, pages = pcall(function()
        return lobbyIndexDict:GetRangeAsync(Enum.SortDirection.Ascending, pageSize)
    end)
    if ok then
        for _, kv in pages do
            local lobbyId = kv.key
            local lobby = readLobby(lobbyId)
            if lobby then
                local before = #lobby.players
                removePlayerFromLobby(lobby, player.UserId)
                if #lobby.players == 0 or lobby.hostUserId == player.UserId then
                    deleteLobby(lobby.lobbyId)
                elseif #lobby.players ~= before then
                    writeLobby(lobby)
                end
            end
        end
    end
    -- Fallback cleanup in Studio
    for _, lobby in fallbackStore do
        if lobby then
            local before = #lobby.players
            removePlayerFromLobby(lobby, player.UserId)
            if #lobby.players == 0 or lobby.hostUserId == player.UserId then
                deleteLobby(lobby.lobbyId)
            elseif #lobby.players ~= before then
                writeLobby(lobby)
            end
        end
    end
end)


