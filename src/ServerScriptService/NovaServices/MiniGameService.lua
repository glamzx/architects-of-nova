-- MiniGameService: repairs are short skill games tied to the fault (pipes, wires, tune, timing, budget).
-- The server issues a one-time token, the client plays, the server checks the token + minimum time.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local MG = {}
local remote: RemoteEvent
local pending: { [Player]: any } = {}

function MG.busy(player) return pending[player] ~= nil end

-- opts: { class, spot (Instance), titleKey, deadline, min, timeout }
function MG.start(player: Player, kind: string, opts, onSuccess)
	local p = pending[player]
	if p and os.clock() < p.expires then return false end
	local id = HttpService:GenerateGUID(false)
	local easy = opts.class ~= nil and player:GetAttribute("Class") == opts.class
	pending[player] = { id = id, kind = kind, t0 = os.clock(), min = opts.min or 2, expires = os.clock() + (opts.timeout or 45), onSuccess = onSuccess, spot = opts.spot }
	remote:FireClient(player, { type = "start", id = id, kind = kind, easy = easy, titleKey = opts.titleKey, deadline = opts.deadline,
		seed = math.random(1, 1000000), spotPos = opts.spot and opts.spot:IsA("BasePart") and opts.spot.Position or nil })
	return true
end

-- someone else fixed it / the event ended: close everyone's game on that spot
function MG.cancelSpot(spot)
	for plr, p in pending do
		if p.spot == spot then
			pending[plr] = nil
			remote:FireClient(plr, { type = "close", id = p.id })
		end
	end
end

function MG.debugWin(player)
	local p = pending[player]
	if not p then return "no game" end
	pending[player] = nil
	remote:FireClient(player, { type = "close", id = p.id })
	task.spawn(p.onSuccess, player)
	return "won " .. p.kind
end

function MG.init()
	local remotes = RS.Nova.Remotes
	remote = remotes:FindFirstChild("MiniGame") :: RemoteEvent
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "MiniGame"
		remote.Parent = remotes
	end
	remote.OnServerEvent:Connect(function(player, msg)
		if typeof(msg) ~= "table" then return end
		local p = pending[player]
		if not p or msg.id ~= p.id then return end
		if msg.type == "cancel" then pending[player] = nil return end
		if msg.type == "done" then
			if os.clock() - p.t0 < p.min or os.clock() > p.expires then return end
			pending[player] = nil
			task.spawn(p.onSuccess, player)
			local ok, Progress = pcall(require, script.Parent.ProgressService)
			if ok and Progress.questEvent then Progress.questEvent(player, "minigame") end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) pending[plr] = nil end)
end

return MG
