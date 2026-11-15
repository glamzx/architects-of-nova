-- UrgentService: timed emergencies during Build. Run to the spot, press E and win the repair mini-game.
-- Pacing (Data.Progress.difficulty): first after urgentFirst s, then urgentEvery s counted from the END of the
-- previous emergency, at most urgentMax per mission (1 in the M0 tutorial). Only one emergency at a time.
-- The matching class fixes twice as fast. A miss costs budget and adds an extra task.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Urgent = require(RS.Nova.Data.Urgent)
local Classes = require(RS.Nova.Data.Classes)
local Remotes = RS.Nova.Remotes
local MiniGame = require(script.Parent:WaitForChild("MiniGameService"))
local GAME = { coolant = "pipes", sparks = "wires", noise = "tune", calib = "timing", audit = "budget" }

local U = {}
local Mission, Progress
local active: { [string]: any } = {}
local holdStart: { [Player]: number } = {}
local runToken = 0
local fixes = 0

local function spots() return workspace.Citadel:FindFirstChild("UrgentSpots") end

local function classPresent(cls)
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") ~= false and p:GetAttribute("Class") == cls then return true end end
	return false
end

local function prompt(spot)
	local pr = spot:FindFirstChild("FixPrompt")
	if not pr then
		pr = Instance.new("ProximityPrompt")
		pr.Name = "FixPrompt"
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr.Enabled = false
		pr:SetAttribute("Key", "p_fix")
		pr.Parent = spot
		pr.Triggered:Connect(function(plr) U.open(plr, spot) end)
	end
	return pr
end

-- walking up and pressing E opens the repair mini-game for this fault (the matching class gets an easier version)
function U.open(plr, spot)
	local def = active[spot.Name]
	if not def then return end
	MiniGame.start(plr, GAME[def.id] or "wires", { class = def.class, spot = spot, titleKey = def.key, deadline = spot:GetAttribute("Deadline"), min = 2.5 }, function(p) U.fix(p, spot) end)
end

function U.fix(plr, spot)
	local def = active[spot.Name]
	if not def then return end
	MiniGame.cancelSpot(spot)
	active[spot.Name] = nil
	spot:SetAttribute("Urgent", nil)
	spot:SetAttribute("Deadline", nil)
	spot:SetAttribute("Broken", nil)
	prompt(spot).Enabled = false
	Mission.state.fixed[spot.Name] = true
	fixes += 1
	Remotes.Cue:FireAllClients({ type = "urgentEnd", spot = spot.Name, ok = true })
	Progress.award(plr, 40, 5)
	if Progress.questEvent then Progress.questEvent(plr, "fix") end
	if fixes >= 3 then Progress.achieveAll("firefighter") end
	Mission.broadcast()
end

local function trigger(def)
	local spot = spots() and spots():FindFirstChild(def.spot)
	if not spot or active[def.spot] then return end
	-- Comms sees threats 5 s earlier
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Class") == "comms" then Remotes.Cue:FireClient(p, { type = "toast", key = def.key, status = "yellow", icon = "headset" }) end
	end
	if classPresent("comms") then task.wait(5) end
	if Mission.state.phase ~= "Build" then return end
	local deadline = workspace:GetServerTimeNow() + def.timer * (Mission.state.diff.timeMul or 1)
	active[def.spot] = def
	Mission.state.fixed[def.spot] = nil
	spot:SetAttribute("Urgent", def.id)
	spot:SetAttribute("Deadline", deadline)
	spot:SetAttribute("HoldBase", def.hold)
	spot:SetAttribute("FixClass", def.class)
	local pr = prompt(spot)
	pr.HoldDuration = 0
	pr:SetAttribute("ObjectKey", def.key)
	pr.Enabled = true
	Remotes.Cue:FireAllClients({ type = "urgent", spot = def.spot, key = def.key, icon = def.icon, deadline = deadline, class = def.class })
	if Mission and Mission.radioOnce then Mission.radioOnce("bip_urgent") end
	while active[def.spot] == def and workspace:GetServerTimeNow() < deadline do task.wait(0.25) end
	if active[def.spot] == def and not Mission.state.bipSaved then
		-- BIP-7 Turbo (bought with credits) saves one missed emergency per mission
		for _, p in Players:GetPlayers() do
			if Progress.hasItem and Progress.hasItem(p, "bip_turbo") then
				Mission.state.bipSaved = true
				Remotes.Cue:FireAllClients({ type = "toast", key = "bip_saved", status = "green", icon = "spark" })
				U.fix(p, spot)
				return
			end
		end
	end
	if active[def.spot] == def then
		-- missed: penalty + extra task, the spot stays broken until fixed
		active[def.spot] = { id = def.id, key = def.key, class = def.class, hold = def.hold, broken = true }
		MiniGame.cancelSpot(spot)
		spot:SetAttribute("Deadline", nil)
		spot:SetAttribute("Broken", true)
		Mission.state.penalty += def.penaltyBudget
		Mission.addExtra({ key = def.key, icon = def.icon, cond = { fixedSpot = def.spot }, cause = "urgent_" .. def.spot })
		Remotes.Cue:FireAllClients({ type = "urgentEnd", spot = def.spot, ok = false })
		Mission.onLoadoutChanged()
	end
end

function U.start()
	runToken += 1
	local my = runToken
	task.spawn(function()
		local diff = Mission.state.diff or {}
		local maxCount = diff.urgentMax or 2
		local firstWait = diff.urgentFirst or 150
		if Mission.state.missionId == "M0" then maxCount, firstWait = math.min(maxCount, 1), math.max(firstWait, 180) end
		local function busy()
			for _, d in active do if not d.broken then return true end end
			return false
		end
		local count, first = 0, true
		while runToken == my and count < maxCount do
			local storm = math.clamp(workspace:GetAttribute("StormLevel") or 0, 0, 3)
			local every = (diff.urgentEvery or 240) * (1 - 0.05 * storm)
			task.wait(first and firstWait or every + math.random(-15, 15))
			first = false
			if runToken ~= my or Mission.state.phase ~= "Build" then break end
			local pool = {}
			for _, d in Urgent do if not active[d.spot] then table.insert(pool, d) end end
			if #pool > 0 and not busy() then
				count += 1
				task.spawn(trigger, pool[math.random(1, #pool)])
				-- rest time starts only after this emergency is fixed or missed
				task.wait(6)
				while runToken == my and busy() do task.wait(1) end
			end
		end
	end)
end

function U.stop()
	runToken += 1
	for name, def in active do
		if not def.broken then
			local spot = spots() and spots():FindFirstChild(name)
			if spot then spot:SetAttribute("Urgent", nil) spot:SetAttribute("Deadline", nil) prompt(spot).Enabled = false end
			active[name] = nil
			Remotes.Cue:FireAllClients({ type = "urgentEnd", spot = name, ok = true, silent = true })
		end
	end
end

function U.reset()
	U.stop()
	for name in active do
		local spot = spots() and spots():FindFirstChild(name)
		if spot then spot:SetAttribute("Broken", nil) spot:SetAttribute("Urgent", nil) prompt(spot).Enabled = false end
	end
	active = {}
	fixes = 0
end

-- repair kit: instantly fixes the emergency that runs out first
function U.useKit(plr)
	local best, bt = nil, math.huge
	for name, def in active do
		local spot = spots() and spots():FindFirstChild(name)
		local d = spot and (spot:GetAttribute("Deadline") or 1e12)
		if spot and d < bt then best, bt = spot, d end
	end
	if not best then return false end
	U.fix(plr, best)
	return true
end
function U.anyActive() return next(active) ~= nil end

function U.debugTrigger(id)
	for _, d in Urgent do if d.id == id then task.spawn(trigger, d) end end
end

function U.init(mission, progress)
	Mission, Progress = mission, progress
	local sp = spots()
	if sp then for _, s in sp:GetChildren() do prompt(s) end end
end

return U
