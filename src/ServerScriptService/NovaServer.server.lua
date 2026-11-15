-- Architects of Nova: server bootstrap. All game rules live in NovaServices (server-authoritative).
local Services = script.Parent:WaitForChild("NovaServices")
local Mission = require(Services.MissionService)
local Hangar = require(Services.HangarService)
local Droid = require(Services.DroidService)
local Consoles = require(Services.ConsoleService)
local Archive = require(Services.ArchiveService)
local Lobby = require(Services.LobbyService)
local Progress = require(Services.ProgressService)
local Cutscenes = require(Services.CutsceneService)
local Urgent = require(Services.UrgentService)
local Heavy = require(Services.HeavyService)
local Expedition = require(Services.ExpeditionService)
local LiveData = require(Services.LiveDataService)
local MiniGame = require(Services.MiniGameService)
MiniGame.init()
local Buggy = require(Services.BuggyService)

Mission.init({ Hangar = Hangar, Consoles = Consoles, Cutscenes = Cutscenes, Urgent = Urgent, Expedition = Expedition, Progress = Progress, Lobby = Lobby, Heavy = Heavy })
Progress.init(Mission)
Lobby.init(Mission, Progress)
Cutscenes.init(Mission)
Heavy.init(Mission, Progress)
Hangar.init(Mission, Heavy, Progress)
Consoles.init(Mission)
Urgent.init(Mission, Progress)
Expedition.init(Mission, Hangar, Heavy, Cutscenes, Progress)
Droid.init(Mission, Hangar)
Archive.init(Mission)
LiveData.init()
Buggy.init(Mission)
Mission.broadcast()

-- Studio-only debug hook for fast QA: ServerStorage.Nova.Debug:Invoke(cmd, ...)
if game:GetService("RunService"):IsStudio() then
	local SS = game:GetService("ServerStorage")
	local bf = SS.Nova:FindFirstChild("Debug") or Instance.new("BindableFunction")
	bf.Name = "Debug"
	bf.Parent = SS.Nova
	bf.OnInvoke = function(cmd, a, b)
		local S = Mission.state
		local p1 = game:GetService("Players"):GetPlayers()[1]
		if cmd == "unlockAll" then S.unlocked = 99 Mission.broadcast()
		elseif cmd == "mgwin" then return MiniGame.debugWin(p1)
		elseif cmd == "lobby" then p1:SetAttribute("InLobby", true) Lobby.lobby = Lobby.lobby or { code = "123456", host = p1.UserId, difficulty = "pilot", started = true } S.roles[tostring(p1.UserId)] = a or "commander" p1:SetAttribute("Class", a or "commander") Progress.applySuit(p1) Mission.broadcast()
		elseif cmd == "start" then S.phase = "Hub" Mission.startMission(a)
		elseif cmd == "build" then Mission.startBuild()
		elseif cmd == "install" then S.installed[a] = b Hangar.prepare(Mission.mission()) Mission.onLoadoutChanged()
		elseif cmd == "clear" then table.clear(S.installed) Mission.onLoadoutChanged()
		elseif cmd == "rocket" then S.rocketId = a Mission.onLoadoutChanged()
		elseif cmd == "orbit" then S.orbitId = a S.orbitTouched = true Mission.onLoadoutChanged()
		elseif cmd == "launch" then Mission.tryLaunch(p1)
		elseif cmd == "press" then Consoles.press(p1, a)
		elseif cmd == "urgent" then Urgent.debugTrigger(a)
		elseif cmd == "auto" then
			local w = S.waiting
			if w then
				local target = w.lit or (w.kind == "sequence" and w.consoles[w.step]) or w.consoles[1]
				Consoles.press(p1, target)
			end
		elseif cmd == "request" then Mission.onRequest(p1, { action = a, missionId = b })
		elseif cmd == "field" then
			-- complete all field objectives instantly (QA)
			if S.field then for _, o in S.field.objectives do o.done = true o.hiddenUntil = nil end Mission.broadcast() end
		elseif cmd == "expedition" then
			S.missionId = a
			task.spawn(function() Expedition.run(a) Mission.setPhase("Hub", "Atrium") end)
		elseif cmd == "demo" then
			-- Studio demo: crew rocket prep -> boarding -> flight cutscene -> site A -> lander hop -> site B ->
			-- return flight -> story + report -> "next mission" briefing. Tasks finish by themselves after a short look.
			local id = a or "M1"
			task.spawn(function()
				local function waitFor(fn, t)
					local t0 = os.clock()
					while not fn() and os.clock() - t0 < (t or 60) do task.wait(0.2) end
					return fn()
				end
				local function finishField(delay)
					task.wait(delay)
					if S.field then for _, o in S.field.objectives do o.done = true o.hiddenUntil = nil end Mission.broadcast() end
				end
				S.unlocked = math.max(S.unlocked, 99)
				Urgent.reset()
				Hangar.clearAll()
				S.phase, S.missionId, S.ops, S.extra, S.attempt = "Ops", id, {}, {}, 1
				task.spawn(function()
					if waitFor(function() return S.phase == "Prep" end, 10) then finishField(5) end
					if waitFor(function() return S.phase == "Board" end, 30) then
						task.wait(4)
						local zone = workspace.Citadel.Hangar.LaunchArea.CrewPad.BoardZone
						if p1.Character then p1.Character:PivotTo(zone.CFrame + Vector3.new(0, 3, 0)) end
					end
					if waitFor(function() return S.phase == "Field" and S.field and S.field.site == "A" end, 60) then finishField(10) end
					if waitFor(function() return S.field and S.field.site == "B" end, 15) then finishField(10) end
					if waitFor(function() return S.field and S.field.allDone end, 15) then
						task.wait(3)
						for _, d in workspace.Locations:GetDescendants() do
							if d.Name == "Lander" and d:GetAttribute("Need") and p1.Character then p1.Character:PivotTo(d.CFrame + Vector3.new(0, 4, 0)) end
						end
					end
				end)
				Expedition.run(id)
				Mission.debrief({ statuses = { mass = "green", time = "green", power = "green", budget = "green", data = "green", comms = "green" } })
				task.wait(15)
				if S.phase == "Debrief" then Mission.onRequest(p1, { action = "next" }) end
			end)
		elseif cmd == "board" then
			local zone = workspace.Citadel.Hangar.LaunchArea.CrewPad.BoardZone
			p1.Character:PivotTo(zone.CFrame + Vector3.new(0, 3, 0))
		elseif cmd == "lander" then
			local loc = workspace.Locations:FindFirstChild(a)
			if loc then p1.Character:PivotTo(loc.Lander.CFrame + Vector3.new(0, 4, 0)) end
		end
		local snap = Mission.snapshot()
		local tasks = {}
		for _, t in snap.tasks do table.insert(tasks, (t.done and "+" or "-") .. t.key .. (t.extra and "*" or "")) end
		local ops = {}
		for _, e in snap.ops do table.insert(ops, e.id .. (e.ok and ":ok" or ":X")) end
		local st = {}
		for k, v in snap.statuses do table.insert(st, k .. "=" .. v) end
		local fo = {}
		if snap.field then for _, o in snap.field.objectives do table.insert(fo, o.key .. (o.done and ":ok" or (":" .. o.progress .. "/" .. o.total))) end end
		return string.format("%s %s | mass %.1f/%.1f | %s | tasks %s | ops %s | wait %s | field %s | flags %s", snap.missionId, snap.phase, snap.massKg or 0, snap.rocketCapacity or 0,
			table.concat(st, ","), table.concat(tasks, " "), table.concat(ops, " "), snap.waiting and snap.waiting.kind or "-", table.concat(fo, " "),
			(function() local f = {} for k in snap.flags do table.insert(f, k) end return table.concat(f, ",") end)())
	end
end
print("[Nova] server ready")
