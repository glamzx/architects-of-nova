-- CutsceneService: server-timed cinematics and hologram dialogues with team votes.
-- Clients render the camera work; the server keeps everyone in sync and applies vote results.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS.Nova.Remotes

local C = {}
local Mission
local votes: { [Player]: number } = {}
local voting = nil :: any
local LINE_TIME = 3.2
local VOTE_TIME = 20

local function holo(who)
	local h = workspace.Citadel.Atrium:FindFirstChild("Hologram")
	if h then h:SetAttribute("Speaker", who) end
end

-- Plays a named cinematic on every client and waits for its duration
function C.play(name, data, duration)
	Remotes.Cue:FireAllClients({ type = "cutscene", name = name, data = data or {}, duration = duration })
	task.wait(duration)
end

local function lobbyPlayers()
	local list = {}
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") ~= false then table.insert(list, p) end end
	return list
end

function C.vote(v)
	votes = {}
	voting = v
	Remotes.Cue:FireAllClients({ type = "vote", key = v.key, options = v.options, time = VOTE_TIME })
	local t0 = os.clock()
	while os.clock() - t0 < VOTE_TIME do
		local n = 0
		for _ in votes do n += 1 end
		if n >= #lobbyPlayers() and n > 0 then break end
		task.wait(0.2)
	end
	voting = nil
	local count = {}
	for _, choice in votes do count[choice] = (count[choice] or 0) + 1 end
	local best, bestN, tie = 1, -1, false
	for i = 1, #v.options do
		local n = count[i] or 0
		if n > bestN then best, bestN, tie = i, n, false elseif n == bestN and n > 0 then tie = true end
	end
	local byCommander = false
	if tie then
		-- the Commander has the casting vote
		for p, choice in votes do
			if Mission.state.roles[tostring(p.UserId)] == "commander" and (count[choice] or 0) == bestN then best, byCommander = choice, true end
		end
	end
	Remotes.Cue:FireAllClients({ type = "voteResult", key = v.key, choice = best, optionKey = v.options[best].key, byCommander = byCommander, counts = count })
	task.wait(2.2)
	return best, v.options[best]
end

-- Runs a list of story steps (lines and votes). onChoice(option) applies consequences.
local StringsMod = require(game:GetService("ReplicatedStorage").Nova.Shared.Strings)
function C.lineTime(key)
	local n = 0
	for _, l in { "ru", "en" } do
		local txt = StringsMod[l] and StringsMod[l][key]
		if txt then n = math.max(n, utf8.len(txt) or #txt) end
	end
	return math.clamp(1.4 + n * 0.05, 3.2, 6.5)
end

function C.dialogue(steps, onChoice, opts)
	opts = opts or {}
	Remotes.Cue:FireAllClients({ type = "dialogStart", where = opts.where or "hologram" })
	for _, st in steps or {} do
		if st.vote then
			holo("kade")
			local _, opt = C.vote(st.vote)
			if onChoice then onChoice(opt) end
		else
			holo(st.who)
			local lt = C.lineTime(st.key)
			Remotes.Cue:FireAllClients({ type = "dialog", who = st.who, key = st.key, time = lt })
			task.wait(lt)
		end
	end
	holo("kade")
	Remotes.Cue:FireAllClients({ type = "dialogEnd" })
	task.wait(0.4)
end

function C.init(mission)
	Mission = mission
	Remotes.Vote.OnServerEvent:Connect(function(player, choice)
		if voting and typeof(choice) == "number" and voting.options[choice] then
			votes[player] = choice
			Remotes.Cue:FireAllClients({ type = "voteCast", userId = player.UserId, choice = choice })
		end
	end)
end

return C
