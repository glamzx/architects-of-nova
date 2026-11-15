-- LobbyService: main menu flow. Create a lobby (6-digit code) or join by code.
-- Published game: each lobby is a reserved server (TeleportService + MemoryStore code map).
-- Studio / fallback: the current server is the lobby (code still shown and checked).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local RS = game:GetService("ReplicatedStorage")
local Classes = require(RS.Nova.Data.Classes)
local Remotes = RS.Nova.Remotes

local L = {}
local Mission, Progress
local MAX = 4
L.lobby = nil :: any -- { code, host, difficulty, started }

local codeMap
pcall(function() codeMap = game:GetService("MemoryStoreService"):GetSortedMap("NovaLobbyCodes") end)

local function newCode()
	return string.format("%06d", math.random(0, 999999))
end

local function canTeleport()
	return not RunService:IsStudio() and game.PlaceId ~= 0 and game.PrivateServerId == "" and codeMap ~= nil
end

local function makeLocal(player, difficulty, code)
	L.lobby = { code = code or newCode(), host = player and player.UserId or 0, difficulty = difficulty or "cadet", started = false }
	Mission.setDifficulty(L.lobby.difficulty)
	Mission.broadcast()
	return { status = "ok", code = L.lobby.code }
end

function L.members()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InLobby") then
			table.insert(list, { userId = p.UserId, name = p.DisplayName, class = Mission.state.roles[tostring(p.UserId)] })
		end
	end
	return list
end

local function inCount()
	local n = 0
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") then n += 1 end end
	return n
end

local handlers = {}
function handlers.create(player, difficulty)
	if typeof(difficulty) ~= "string" or not ({ cadet = 1, pilot = 1, master = 1 })[difficulty] then difficulty = "cadet" end
	if L.lobby then
		player:SetAttribute("InLobby", true)
		Mission.broadcast()
		return { status = "ok", code = L.lobby.code }
	end
	if canTeleport() then
		local ok, res = pcall(function()
			local access = TeleportService:ReserveServer(game.PlaceId)
			local code
			for _ = 1, 8 do
				code = newCode()
				local existing = codeMap:GetAsync(code)
				if not existing then break end
			end
			codeMap:SetAsync(code, access, 6 * 3600)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = access
			opts:SetTeleportData({ code = code, difficulty = difficulty })
			TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
			return code
		end)
		if ok then return { status = "teleporting", code = res } end
	end
	player:SetAttribute("InLobby", true)
	return makeLocal(player, difficulty)
end

function handlers.join(player, code)
	if typeof(code) ~= "string" or not code:match("^%d%d%d%d%d%d$") then return { status = "error", key = "err_code" } end
	if L.lobby and L.lobby.code == code then
		if inCount() >= MAX and not player:GetAttribute("InLobby") then return { status = "error", key = "err_full" } end
		player:SetAttribute("InLobby", true)
		Mission.broadcast()
		return { status = "ok", code = code }
	end
	if canTeleport() then
		local ok, access = pcall(function() return codeMap:GetAsync(code) end)
		if ok and access then
			local tok = pcall(function()
				local opts = Instance.new("TeleportOptions")
				opts.ReservedServerAccessCode = access
				opts:SetTeleportData({ code = code })
				TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
			end)
			return tok and { status = "teleporting" } or { status = "error", key = "err_teleport" }
		end
	end
	return { status = "error", key = "err_code" }
end

function handlers.pickClass(player, classId)
	if not player:GetAttribute("InLobby") or typeof(classId) ~= "string" or not Classes.byId[classId] then return { status = "error" } end
	for uid, c in Mission.state.roles do
		if c == classId and uid ~= tostring(player.UserId) then
			local other = Players:GetPlayerByUserId(tonumber(uid))
			if other and other:GetAttribute("InLobby") then return { status = "error", key = "taken" } end
		end
	end
	Mission.state.roles[tostring(player.UserId)] = classId
	player:SetAttribute("Class", classId)
	Progress.applySuit(player)
	Mission.broadcast()
	return { status = "ok" }
end

function handlers.start(player)
	if not L.lobby or not player:GetAttribute("InLobby") then return { status = "error" } end
	if not Mission.state.roles[tostring(player.UserId)] then return { status = "error", key = "pick_class" } end
	L.lobby.started = true
	Mission.broadcast()
	task.delay(2.5, function() if Mission.coldOpen then Mission.coldOpen() end end)
	return { status = "ok" }
end

function handlers.state(player)
	return { lobby = L.lobby, members = L.members(), inLobby = player:GetAttribute("InLobby") == true }
end

function L.snapshot()
	if not L.lobby then return nil end
	return { code = L.lobby.code, started = L.lobby.started, difficulty = L.lobby.difficulty, host = L.lobby.host, members = L.members() }
end

function L.init(mission, progress)
	Mission, Progress = mission, progress
	Remotes.Lobby.OnServerInvoke = function(player, action, arg)
		local h = handlers[action]
		if not h then return { status = "error" } end
		return h(player, arg)
	end
	Players.PlayerAdded:Connect(function(p)
		-- arriving into a reserved server: the teleport data carries the lobby code
		local data = p:GetJoinData() and p:GetJoinData().TeleportData
		if typeof(data) == "table" and typeof(data.code) == "string" then
			if not L.lobby then makeLocal(p, data.difficulty, data.code) end
			p:SetAttribute("InLobby", true)
			Mission.broadcast()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if L.lobby and L.lobby.host == p.UserId then
			for _, o in Players:GetPlayers() do if o ~= p and o:GetAttribute("InLobby") then L.lobby.host = o.UserId break end end
		end
		task.defer(function() Mission.broadcast() end)
	end)
end

return L
