-- MissionService: authoritative campaign + mission state machine.
-- Hub -> Briefing (hologram cutscene + team vote) -> Build (urgent problems, heavy co-op parts)
-- -> Launch (cinematic) -> Ops (co-op consoles) -> [Board -> Flight -> Field -> Flight] -> Debrief.
-- There is no "mission lost": failures add extra tasks; the team improves the ship and tries again.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Nova = RS.Nova
local Remotes = Nova.Remotes
local Missions = require(Nova.Data.Missions)
local Launch = require(Nova.Data.Launch)
local Story = require(Nova.Data.Story)
local Classes = require(Nova.Data.Classes)
local ProgressData = require(Nova.Data.Progress)
local Resources = require(Nova.Shared.Resources)

local Citadel = workspace:WaitForChild("Citadel")

local M = {}
local Hangar, Consoles, Cutscenes, Urgent, Expedition, Progress, Lobby, Heavy -- injected

M.state = {
	missionId = "M0", phase = "Hub",
	installed = {} :: { [string]: string },
	rocketId = "kestrel", orbitId = "LEO400", orbitTouched = false,
	buildStart = 0, frozenElapsed = 0, goal = "Atrium",
	ops = {} :: { any }, waiting = nil :: any,
	roles = {} :: { [string]: string },
	launch = nil :: any, launched = false,
	eventsOk = {} :: { [string]: boolean },
	extra = {} :: { any }, rehearsed = {} :: { [string]: boolean }, fixed = {} :: { [string]: boolean },
	attempt = 1, penalty = 0, reserveUsed = false,
	flags = {} :: { [string]: boolean }, rackOverride = nil :: any,
	unlocked = 0, completed = {} :: { [string]: number }, cores = {} :: { [string]: boolean },
	usedVex = false, diffId = "cadet", diff = ProgressData.difficulty.cadet,
	field = nil :: any, boarded = 0, cinematic = false,
}
local S = M.state
local gauges, info = {}, {}

function M.mission() return Missions.byId[S.missionId] end
local function orbit() return Launch.orbits[S.orbitId] or Launch.orbits[M.mission().orbit] end
local function elapsed()
	if S.phase == "Build" then return os.clock() - S.buildStart end
	return S.frozenElapsed or 0
end
local function margin() return math.max(M.mission().marginRule or 0.1, S.diff.margin or 0.1) end

function M.setDifficulty(id)
	if ProgressData.difficulty[id] then S.diffId, S.diff = id, ProgressData.difficulty[id] end
end

function M.recompute()
	gauges, info = Resources.compute(M.mission(), S.installed, S.rocketId, elapsed(), S.orbitId, { extraCost = S.penalty, timeMul = S.diff.timeMul })
	return gauges, info
end
function M.info() return info end
local function statuses()
	local st = {}
	for k, g in gauges do st[k] = Resources.status(g, margin()) end
	return st
end

------------------------------------------------------------------ tasks
local function evalCond(cond, st)
	if not cond then return false end
	local o = orbit()
	if cond.cat and not (info.categories and (info.categories[cond.cat] or 0) > 0) then return false end
	if cond.notRed and st[cond.notRed] == "red" then return false end
	if cond.green then for _, k in cond.green do if st[k] ~= "green" then return false end end end
	if cond.launched and not S.launched then return false end
	if cond.event and not S.eventsOk[cond.event] then return false end
	if cond.chooseOrbit and not (S.orbitTouched or S.launched) then return false end
	if cond.flag then
		if cond.flag == "rtg" then if (info.rtgW or 0) <= 0 then return false end
		elseif not info[cond.flag] then return false end
	end
	if cond.orbitFlag and not o[cond.orbitFlag] then return false end
	if cond.anyFlag then
		local any = false
		for _, f in cond.anyFlag do if info[f] then any = true end end
		if not any then return false end
	end
	if cond.noFlag and info[cond.noFlag] then return false end
	if cond.rehearse and not S.rehearsed[cond.rehearse] then return false end
	if cond.pushEnough and (info.push or 0) < (o.needPush or 0) then return false end
	if cond.fixedSpot and not S.fixed[cond.fixedSpot] then return false end
	if cond.moduleId then
		local has = false
		for _, id in S.installed do if id == cond.moduleId then has = true end end
		if not has then return false end
	end
	return true
end

local GOAL_TASKS = {
	goal_camera = { id = "goal", key = "t_goal_camera", icon = "instrument", cond = { moduleId = "camera" } },
	goal_rad = { id = "goal", key = "t_goal_rad", icon = "instrument", cond = { moduleId = "rad_sensor" } },
}

local function taskList()
	local st = statuses()
	local list = {}
	for _, t in M.mission().tasks or {} do
		table.insert(list, { id = t.id, key = t.key, icon = t.icon, done = evalCond(t.cond, st), cat = t.cond and t.cond.cat })
	end
	for f, t in GOAL_TASKS do
		if S.flags[f] and S.missionId == "M0" then table.insert(list, { id = t.id, key = t.key, icon = t.icon, done = evalCond(t.cond, st), goal = true }) end
	end
	for i, t in S.extra do
		table.insert(list, { id = "x" .. i, key = t.key, icon = t.icon, done = evalCond(t.cond, st), extra = true, rehearse = t.cond.rehearse })
	end
	return list
end

function M.addExtra(t)
	for _, e in S.extra do if e.cause == t.cause then return end end
	table.insert(S.extra, t)
	M.broadcast()
end

function M.activeRehearsal(): string?
	if S.phase ~= "Build" then return nil end
	for _, t in S.extra do
		if t.cond.rehearse and not S.rehearsed[t.cond.rehearse] then return t.cond.rehearse end
	end
	return nil
end

------------------------------------------------------------------ snapshot / broadcast
function M.snapshot()
	M.recompute()
	local m = M.mission()
	return {
		missionId = S.missionId, phase = S.phase, installed = S.installed,
		rocketId = S.rocketId, orbitId = S.orbitId, rockets = m.rockets, orbits = m.orbits or { m.orbit },
		gauges = gauges, statuses = statuses(), massKg = info.massKg, rocketCapacity = info.rocketCapacity,
		fairing = info.fairing, maxSize = info.maxSize, goal = S.goal, ops = S.ops, waiting = S.waiting,
		roles = S.roles, tasks = taskList(), rehearsal = M.activeRehearsal(), attempt = S.attempt,
		unlocked = S.unlocked, completed = S.completed, cores = S.cores, flags = S.flags,
		frame = m.frame, penalty = S.penalty, reserveUsed = S.reserveUsed, diff = S.diffId,
		lobby = Lobby and Lobby.snapshot() or nil, field = Expedition and Expedition.snapshot() or nil,
		boarded = S.boarded, tutorial = ((Missions.byId[S.missionId] or {}).order or 0) <= 2, firstMission = (S.missionId == "M0"),
		fixCat = S.fixCat, fixTarget = S.fixTarget,
	}
end

local pending = false
function M.broadcast()
	if pending then return end
	pending = true
	task.defer(function()
		pending = false
		Remotes.State:FireAllClients(M.snapshot())
	end)
end

function M.cue(msg, player: Player?)
	if player then Remotes.Cue:FireClient(player, msg) else Remotes.Cue:FireAllClients(msg) end
end

-- BIP-7 / crew radio: a subtitle line that never locks the camera
function M.radio(key: string, who: string?)
	M.cue({ type = "radio", who = who or "bip", key = key, time = 4 })
end
function M.radioOnce(key: string, who: string?)
	S.barks = S.barks or {}
	if S.barks[key] then return end
	S.barks[key] = true
	M.radio(key, who)
end

-- Cold open: the first time a crew starts, an alarm sounds and Kade's distress call begins M0 by itself
function M.coldOpen()
	if S.coldOpened or S.unlocked > 0 or S.phase ~= "Hub" then return end
	S.coldOpened = true
	M.cue({ type = "alarm" })
	M.cue({ type = "banner", key = "incoming", color = "red" })
	task.delay(4.5, function()
		if S.phase == "Hub" then M.startMission("M0") end
	end)
end

function M.setPhase(phase: string, goal: string?)
	S.phase = phase
	if goal then S.goal = goal end
	M.broadcast()
end
local setPhase = M.setPhase

local function lobbyPlayers()
	local t = {}
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") ~= false then table.insert(t, p) end end
	return t
end
local function classPresent(cls)
	for _, p in lobbyPlayers() do if p:GetAttribute("Class") == cls then return true end end
	return false
end

------------------------------------------------------------------ campaign flow
function M.openMissions(player: Player)
	if S.phase ~= "Hub" then return end
	M.cue({ type = "missionSelect" }, player)
end

local function applyChoice(opt)
	if not opt then return end
	if opt.flag then S.flags[opt.flag] = true end
	if opt.orbit then S.orbitId = opt.orbit S.orbitTouched = true end
	if opt.rack then S.rackOverride = opt.rack end
	if opt.flag == "accept_vex" then S.usedVex = true end
	M.broadcast()
end

function M.startMission(missionId: string)
	local m = Missions.byId[missionId]
	if not m or (m.order or 0) > S.unlocked or S.phase ~= "Hub" then return end
	S.missionId = missionId
	S.orbitId = m.orbit
	S.rocketId = m.rockets[1]
	S.orbitTouched, S.extra, S.rehearsed, S.fixed = false, {}, {}, {}
	S.attempt, S.ops, S.eventsOk, S.penalty, S.reserveUsed = 1, {}, {}, 0, false
	S.rackOverride = nil
	S.barks = {}
	S.grantUsed, S.bipSaved = false, false
	for k in S.flags do if k:sub(1, 5) == "goal_" then S.flags[k] = nil end end
	Hangar.clearAll()
	Urgent.reset()
	for _, p in lobbyPlayers() do if p:GetAttribute("EVA") and Progress.setEVA then Progress.setEVA(p, false) end end
	setPhase("Briefing", "Atrium")
	task.spawn(function()
		M.cue({ type = "briefing", missionId = missionId })
		task.wait(2.5)
		local story = Story[missionId]
		Cutscenes.dialogue(story and story.brief or {}, applyChoice, { where = "hologram" })
		if S.phase == "Briefing" and S.missionId == missionId then M.startBuild() end
	end)
end

function M.startBuild()
	S.buildStart = os.clock()
	S.frozenElapsed, S.ops, S.eventsOk, S.waiting, S.launch, S.launched = 0, {}, {}, nil, nil, false
	S.fixCat, S.fixTarget = nil, nil
	Consoles.cancel()
	Hangar.prepare(M.mission())
	Hangar.resetRocket()
	setPhase("Build", "Hangar")
	M.cue({ type = "banner", key = "go_hangar", color = "amber" })
	-- every role gets its own job for this mission
	local mid = S.missionId
	task.delay(3.5, function()
		if S.phase ~= "Build" or S.missionId ~= mid then return end
		for _, p in lobbyPlayers() do Remotes.Cue:FireClient(p, { type = "roleBrief", missionId = mid, part = "build" }) end
	end)
	-- a mission grant (bought with credits) adds budget once per mission
	if not S.grantUsed then
		for _, p in lobbyPlayers() do
			if Progress.useItem and Progress.useItem(p, "kit_grant") then
				S.grantUsed = true
				S.penalty -= 15
				M.cue({ type = "toast", key = "grant_used", status = "green", icon = "budget" })
				M.onLoadoutChanged()
				break
			end
		end
	end
	Urgent.start()
end

function M.onLoadoutChanged()
	local before = gauges
	M.recompute()
	local changed = {}
	for k, g in gauges do
		local b = before[k]
		if not b or math.abs(b.used - g.used) > 1e-6 or math.abs(b.cap - g.cap) > 1e-6 then table.insert(changed, k) end
	end
	M.broadcast()
	if #changed > 0 then M.cue({ type = "flash", gauges = changed }) end
	if S.phase == "Build" and (info.count or 0) > 0 then
		local st = statuses()
		M.radioOnce("bip_first")
		local anyRed = false
		for k, v in st do if v == "red" and k ~= "comms" and k ~= "time" then anyRed = true end end
		if st.power == "green" and (info.count or 0) >= 2 then M.radioOnce("bip_power") end
		local _, allGo = M.readinessPoll()
		if allGo and S.fixCat then S.fixCat, S.fixTarget = nil, nil end
		if allGo then M.radioOnce("bip_ready") elseif anyRed and (info.count or 0) >= 3 then M.radioOnce("bip_red") end
	end
end

------------------------------------------------------------------ launch
local function chooser(player)
	-- Comms picks rocket and orbit when there is one in the crew
	if classPresent("comms") and player:GetAttribute("Class") ~= "comms" then
		M.cue({ type = "toast", key = "only_class", status = "yellow", icon = "headset", extraKey = "role_comms" }, player)
		return false
	end
	return true
end

function M.cycleRocket(player)
	if S.phase ~= "Build" or (player and not chooser(player)) then return end
	local list = M.mission().rockets
	local idx = table.find(list, S.rocketId) or 0
	S.rocketId = list[(idx % #list) + 1]
	Hangar.showRocket(S.rocketId)
	M.onLoadoutChanged()
end

function M.cycleOrbit(player)
	if S.phase ~= "Build" or (player and not chooser(player)) then return end
	local list = M.mission().orbits or { M.mission().orbit }
	local idx = table.find(list, S.orbitId) or 0
	S.orbitId = list[(idx % #list) + 1]
	S.orbitTouched = true
	M.onLoadoutChanged()
end

-- Launch Readiness Poll (like NASA's Go/No-Go poll): every flight-control station reports GO or NO-GO
-- from the current design. Any NO-GO holds the countdown and explains the fix — no more blind launches.
local polling = false
local function doLaunch()
	Urgent.stop()
	S.frozenElapsed = elapsed()
	S.launch = { gauges = gauges, statuses = statuses(), info = info, orbit = orbit() }
	S.launched = true
	if info.vex then S.usedVex = true end
	Hangar.dropAll()
	for _, p in lobbyPlayers() do Heavy.release(p) end
	setPhase("Launch", "Control")
	M.cue({ type = "rocketCheck", ok = true })
	local allGreen = true
	for _, st in S.launch.statuses do if st ~= "green" then allGreen = false end end
	if allGreen then Progress.achieveAll("margin") end
	if Progress.questAll then Progress.questAll("launch") end
	local pad = Citadel.Hangar.LaunchArea:FindFirstChild(Launch.rockets[S.rocketId].pad)
	local rocket, t0 = Hangar.launchRocket(S.rocketId, 6, 2.8)
	M.cue({ type = "cutscene", name = "probeLaunch", data = { pad = pad and pad:GetPivot().Position, rocket = rocket, t0 = t0, dur = 6 }, duration = 10 })
	task.delay(10.5, function()
		if S.phase == "Launch" then M.startOps() end
	end)
end

function M.tryLaunch(player: Player)
	if S.phase ~= "Build" or polling then return end
	if classPresent("commander") and player:GetAttribute("Class") ~= "commander" then
		M.cue({ type = "toast", key = "only_class", status = "yellow", icon = "commander", extraKey = "role_commander" }, player)
		return
	end
	M.recompute()
	if info.count == 0 then
		M.cue({ type = "toast", key = "need_modules", status = "red", icon = "rocket" }, player)
		return
	end
	local items, allGo = M.readinessPoll()
	S.fixCat, S.fixTarget = nil, nil
	if not allGo then
		for _, it in items do if not it.go and not it.optional then S.fixCat, S.fixTarget = it.fixCat, it.fixTarget break end end
		M.broadcast()
	end
	polling = true
	M.cue({ type = "goNoGo", items = items, go = allGo })
	local dur = #items * 0.45 + 1.8
	if not allGo then
		if info.massKg > info.rocketCapacity or info.maxSize > info.fairing then M.cue({ type = "rocketCheck", ok = false }) end
		task.delay(dur, function() polling = false M.radio("bip_hold") end)
		return
	end
	task.delay(dur, function()
		polling = false
		if S.phase == "Build" then
			M.recompute()
			doLaunch()
		end
	end)
end

------------------------------------------------------------------ operations
local checks = {}
function checks.computer(ctx) return ctx.info.hasComputer end
function checks.battery(ctx)
	if (ctx.info.rtgW or 0) > 0 then return true end
	if not ctx.info.hasBattery then return false end
	local o = ctx.orbit
	local needWh = ctx.gauges.power.used * (math.min(o.periodMin, 120) / 60) * o.eclipseFrac
	return ctx.info.batteryWh >= needWh
end
function checks.margin(ctx)
	if ctx.info.radHard then return true end
	for _, k in { "mass", "power", "comms" } do if ctx.statuses[k] ~= "green" then return false end end
	return true
end
function checks.comms(ctx) return ctx.statuses.comms ~= "red" end
function checks.data(ctx) return ctx.statuses.data ~= "red" end
function checks.ice(ctx) return ctx.orbit.polar == true and ctx.info.darkOK == true end
function checks.edl(ctx)
	local bonus = S.flags.site_plain and 4 or 0
	local cap = ({ [1] = 20, [2] = 32 })[ctx.info.edl] or 0
	return ctx.info.edl >= 1 and ctx.info.massKg <= cap + bonus and ctx.interaction ~= false
end
function checks.dust(ctx)
	if (ctx.info.rtgW or 0) > 0 then return true end
	return ctx.statuses.power == "green" and ctx.info.hasBattery
end
function checks.deploy(ctx)
	if not ctx.info.hinges then return true end
	return ctx.interaction ~= false
end
function checks.radiation(ctx) return ctx.info.shields or ctx.info.radHard end
function checks.power(ctx) return ctx.statuses.power ~= "red" end
function checks.relay(ctx) return ctx.interaction ~= false and ctx.statuses.comms ~= "red" end
function checks.storm(ctx) return (not ctx.info.vex) and ctx.interaction ~= false end
function checks.impact(ctx) return (ctx.info.push or 0) >= (ctx.orbit.needPush or 0) end
function checks.interaction(ctx) return ctx.interaction ~= false end

local function causeOf(ev)
	if ev.cause then return ev.cause end
	if ev.check == "interaction" then return ev.id end
	return ev.check
end

local STATION = { computer = "st_guidance", battery = "st_power", power = "st_power", dust = "st_power", margin = "st_systems",
	comms = "st_comms", relay = "st_comms", data = "st_data", ice = "st_science", impact = "st_flight", edl = "st_flight",
	deploy = "st_systems", radiation = "st_systems", storm = "st_systems", interaction = "st_systems" }
function M.readinessPoll()
	local m = M.mission()
	local st = statuses()
	local o = orbit()
	local ctx = { info = info, gauges = gauges, statuses = st, orbit = o, interaction = true }
	local items, allGo = {}, true
	local function add(item)
		table.insert(items, item)
		if not item.go and not item.optional then allGo = false end
	end
	local r1 = function(x) return math.floor(x * 10 + 0.5) / 10 end
	-- every NO-GO says exactly what is wrong (with the real numbers) and which rack has the fix
	local heavyLV = info.massKg > info.rocketCapacity
	local lvGo = not heavyLV and info.maxSize <= info.fairing
	add({ st = "st_booster", icon = "rocket", go = lvGo,
		why = heavyLV and "why_mass" or "why_fairing", args = heavyLV and { r1(info.massKg), r1(info.rocketCapacity) } or { info.maxSize, info.fairing },
		fix = heavyLV and "poll_fix_mass" or "poll_fix_fairing", fixTarget = "console" })
	local detail = {}
	function detail.computer() return { why = "why_computer", fixCat = "computer" } end
	function detail.battery()
		local shadow = math.floor(o.periodMin * o.eclipseFrac + 0.5)
		if (info.rtgW or 0) <= 0 and not info.hasBattery then return { why = "why_nobattery", args = { shadow }, fixCat = "battery" } end
		local need = gauges.power.used * (math.min(o.periodMin, 120) / 60) * o.eclipseFrac
		return { why = "why_battery", args = { shadow, r1(need), r1(info.batteryWh or 0) }, fixCat = "battery" }
	end
	function detail.power() return { why = "why_power", args = { r1(gauges.power.used), r1(gauges.power.cap) }, fixCat = "panel" } end
	function detail.dust() return { why = "why_dust", fixCat = "panel" } end
	function detail.margin()
		local list = {}
		for _, k in { "mass", "power", "comms" } do if st[k] ~= "green" then table.insert(list, k) end end
		return { why = "why_margin", whyList = list, fixCat = (st.power ~= "green" and "panel") or (st.comms ~= "green" and "antenna") or nil }
	end
	function detail.comms() return { why = "why_comms", args = { r1(gauges.comms.cap), r1(gauges.comms.used) }, fixCat = "antenna" } end
	detail.relay = detail.comms
	function detail.data() return { why = "why_data", args = { r1(gauges.data.used), r1(gauges.data.cap) }, fixCat = "antenna" } end
	function detail.ice() return { why = "why_ice", fixCat = "instrument" } end
	function detail.edl() return { why = "why_edl", fixCat = "edl" } end
	function detail.radiation() return { why = "why_radiation", fixCat = "computer" } end
	function detail.storm() return { why = "why_vex", fixCat = "computer" } end
	function detail.impact() return { why = "why_push", args = { r1(info.push or 0), r1(o.needPush or 0) }, fixCat = "payload" } end
	local seen = {}
	for _, ev in m.events do
		if ev.onlyIf and not o[ev.onlyIf] then continue end
		local cause = causeOf(ev)
		if seen[cause] then continue end
		seen[cause] = true
		local ok
		if ev.science and not info.hasInstrument then ok = false else ok = checks[ev.check](ctx) and true or false end
		local h = m.hints and m.hints[cause]
		local r = m.recovery and m.recovery[cause]
		local item = { st = STATION[ev.check] or "st_systems", icon = ev.icon, go = ok, optional = ev.science == true,
			why = (h and h.key) or ev.failKey, fix = r and r.key or nil }
		if not ok then
			local d = detail[ev.check] and detail[ev.check]()
			if ev.science and not info.hasInstrument then d = { why = "why_science", fixCat = "instrument" } end
			if d then
				item.why, item.args, item.whyList, item.fixCat = d.why, d.args, d.whyList, d.fixCat
				item.hint = (h and h.key) or nil
			end
		end
		add(item)
	end
	if st.budget == "red" then add({ st = "st_budget", icon = "budget", go = false, optional = true, why = "why_budget", args = { math.floor(gauges.budget.used), math.floor(gauges.budget.cap) } }) end
	if st.time == "red" then add({ st = "st_schedule", icon = "time", go = false, optional = true, why = "c_time_over" }) end
	return items, allGo
end

function M.startOps()
	setPhase("Ops", "Control")
	M.cue({ type = "banner", key = "go_control", color = "cyan" })
	local mission = M.mission()
	local ctx = { info = S.launch.info, gauges = S.launch.gauges, statuses = S.launch.statuses, orbit = S.launch.orbit, broken = false }
	task.spawn(function()
		task.wait(3)
		for _, ev in mission.events do
			if S.phase ~= "Ops" then return end
			if ev.science and not ctx.info.hasInstrument then continue end
			if ev.onlyIf and not ctx.orbit[ev.onlyIf] then continue end
			if ctx.broken then
				table.insert(S.ops, { id = ev.id, icon = ev.icon, ok = false, key = "ev_down", cascade = true })
				M.broadcast()
				M.cue({ type = "event", icon = ev.icon, key = "ev_down", ok = false })
				task.wait(1.2)
				continue
			end
			ctx.interaction = nil
			local inter = ev.interactive
			if inter and (not inter.onlyIfFlag or ctx.info[inter.onlyIfFlag]) then
				for _, p in lobbyPlayers() do
					if p:GetAttribute("Class") == "comms" then M.cue({ type = "toast", key = inter.waitKey or "ev_contact_wait", status = "yellow", icon = "headset" }, p) end
				end
				if classPresent("comms") then task.wait(2) end
				M.cue({ type = "toast", key = inter.waitKey or "ev_contact_wait", status = "yellow", icon = ev.icon })
				local result, byBip = Consoles.run(inter)
				ctx.interaction = result
				if byBip then M.cue({ type = "toast", key = "bip_auto", status = "yellow", icon = "spark" }) end
				if result and not byBip and (inter.kind == "sync" or inter.kind == "relay" or inter.kind == "sequence") then Progress.achieveAll("sync") end
			end
			local ok = checks[ev.check](ctx)
			if not ok and not ev.science then ctx.broken = true end
			S.eventsOk[ev.id] = ok
			table.insert(S.ops, { id = ev.id, icon = ev.icon, check = causeOf(ev), ok = ok, key = ok and ev.okKey or ev.failKey, objective = ev.objective, science = ev.science })
			M.broadcast()
			M.cue({ type = "event", icon = ev.icon, key = ok and ev.okKey or ev.failKey, ok = ok })
			task.wait(2.6)
		end
		if S.phase ~= "Ops" then return end
		local win = true
		for _, e in S.ops do if not e.ok and not e.science then win = false end end
		if win and Expedition.has(mission.id) then
			Expedition.run(mission.id)
		end
		M.debrief(ctx)
	end)
end

------------------------------------------------------------------ debrief
function M.debrief(ctx)
	local mission = M.mission()
	local chain, causes = {}, {}
	local win = true
	for _, e in S.ops do
		table.insert(chain, { icon = e.icon, key = e.key, ok = e.ok, cascade = e.cascade })
		if not e.ok and not e.cascade then table.insert(causes, e.check) end
		if not e.ok and not e.science then win = false end
	end
	for _, k in { "budget", "time" } do
		if ctx.statuses[k] == "red" then
			table.insert(chain, { icon = k, key = k == "budget" and "c_budget_over" or "c_time_over", ok = false })
			table.insert(causes, k)
		end
	end
	local stars, newTasks = 0, {}
	if win then
		stars = 1
		local allGreen = true
		for _, st in ctx.statuses do if st ~= "green" then allGreen = false end end
		if allGreen then stars += 1 end
		for _, e in S.ops do if e.science and e.ok then stars += 1 end end
		stars = math.min(stars, 3)
		S.completed[mission.id] = math.max(S.completed[mission.id] or 0, stars)
		S.unlocked = math.max(S.unlocked, (mission.order or 0) + 1)
		if mission.core then S.cores[mission.id] = true end
		local sci = 0
		for _, e in S.ops do if e.science and e.ok then sci += 1 end end
		Progress.awardAll(stars * 100 + #S.extra * 50, stars * 20 + 10)
		if mission.id == "M0" then Progress.achieveAll("first_contact") end
		if Progress.questAll then Progress.questAll("mission") end
		if sci > 0 then for _, p in lobbyPlayers() do if p:GetAttribute("Class") == "scientist" then Progress.achieve(p, "scientist") end end end
		if mission.core and mission.core.rarity == "legendary" then Progress.achieveAll("legend") end
	else
		for _, c in causes do
			local r = mission.recovery and mission.recovery[c]
			local exists = false
			for _, t in S.extra do if t.cause == c then exists = true end end
			if r and not exists then
				table.insert(S.extra, { key = r.key, icon = r.icon, cond = r.cond, cause = c })
				table.insert(newTasks, { key = r.key, icon = r.icon })
				if r.cond.rehearse then S.rehearsed[r.cond.rehearse] = false end
			end
		end
		Progress.awardAll(40, 5)
	end
	local h1 = mission.hints[causes[1] or "success"] or mission.hints.success
	local h2 = causes[2] and mission.hints[causes[2]] or ((causes[1] ~= "margin") and mission.hints.margin or mission.hints.success)
	local hints = { h1.key, (h2 or h1).key, h1.nasa }
	local nextId
	for id, m in Missions.byId do if (m.order or 0) == (mission.order or 0) + 1 then nextId = id end end
	setPhase("Debrief", "Atrium")
	local story = Story[mission.id]
	if win and story then
		-- story beat at the hologram before the report
		if mission.final and story.final then
			Cutscenes.dialogue(story.final, applyChoice, { where = "hologram" })
		elseif story.win then
			Cutscenes.dialogue(story.win, nil, { where = "hologram" })
		end
	end
	M.cue({ type = "debrief", win = win, stars = stars, chain = chain, hints = hints, missionId = mission.id,
		newTasks = newTasks, attempt = S.attempt, core = win and mission.core or nil, nextId = win and nextId or nil, final = win and mission.final })
	if win and mission.final then
		if not S.usedVex then Progress.achieveAll("no_vex") end
		Progress.achieveAll("campaign")
		local ending = S.usedVex and "lesson" or (S.flags.tribunal and "tribunal" or "reconcile")
		task.delay(2, function() M.cue({ type = "ending", ending = ending }) end)
	end
end

local lastRequest = {}
function M.onRequest(player: Player, req)
	if typeof(req) ~= "table" or typeof(req.action) ~= "string" then return end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.3 then return end
	lastRequest[player] = now
	if req.action == "drop" then
		if not Heavy.release(player) then Hangar.drop(player) end
		return
	elseif req.action == "reserve" then
		-- Commander perk: emergency reserve once per mission
		if player:GetAttribute("Class") == "commander" and not S.reserveUsed and S.phase == "Build" then
			S.reserveUsed = true
			S.penalty -= 20
			M.cue({ type = "toast", key = "perk_commander", status = "green", icon = "budget" })
			M.onLoadoutChanged()
		end
		return
	elseif req.action == "kit" then
		if S.phase == "Build" and Urgent.anyActive() and Progress.useItem(player, "kit_repair") then
			Urgent.useKit(player)
			M.cue({ type = "toast", key = "kit_used", status = "green", icon = "warning" })
		end
		return
	elseif req.action == "ping" then
		if typeof(req.pos) == "Vector3" and (not player:GetAttribute("PingT") or os.clock() - player:GetAttribute("PingT") > 1.5) then
			player:SetAttribute("PingT", os.clock())
			M.cue({ type = "ping", pos = req.pos, name = player.DisplayName, userId = player.UserId, class = player:GetAttribute("Class"), kind = req.kind })
		end
		return
	elseif req.action == "lab" then
		local r = Progress.labDone and Progress.labDone(player, req.level) or 0
		if r > 0 then M.cue({ type = "labReward", reward = r, level = req.level }, player) end
		return
	elseif req.action == "quiz" then
		local NasaFiles = require(Nova.Data.NasaFiles)
		local f = typeof(req.missionId) == "string" and NasaFiles[req.missionId]
		if f and f.quiz and req.choice == 1 then
			local r = Progress.quiz(player, req.missionId)
			M.cue({ type = "quizResult", ok = true, reward = r }, player)
		else
			M.cue({ type = "quizResult", ok = false }, player)
		end
		return
	elseif req.action == "settings" then
		if Progress.setSettings then Progress.setSettings(player, req.data) end
		return
	elseif req.action == "start" then
		if Lobby.lobby and Lobby.lobby.started and typeof(req.missionId) == "string" then M.startMission(req.missionId) end
		return
	end
	if S.phase ~= "Debrief" then return end
	if req.action == "retry" then
		S.attempt += 1
		M.startBuild()
	elseif req.action == "next" then
		local nextId
		for id, m in Missions.byId do if (m.order or 0) == (M.mission().order or 0) + 1 then nextId = id end end
		Hangar.clearAll(); Hangar.resetRocket()
		setPhase("Hub", "Atrium")
		if nextId then M.startMission(nextId) end
	elseif req.action == "hub" then
		Hangar.clearAll(); Hangar.resetRocket()
		S.ops = {}
		setPhase("Hub", "Atrium")
	end
end

------------------------------------------------------------------ rehearsal at mission control
function M.startRehearsal(player: Player)
	local key = M.activeRehearsal()
	if not key or Consoles.busy() then return end
	local def
	for _, ev in M.mission().events do if ev.id == key then def = ev.interactive end end
	if not def then S.rehearsed[key] = true M.broadcast() return end
	M.cue({ type = "toast", key = def.waitKey or "p_rehearse", status = "yellow", icon = "task" })
	task.spawn(function()
		local result = Consoles.run(def, { rehearsal = true, noBip = true })
		if result then
			S.rehearsed[key] = true
			M.cue({ type = "toast", key = "rehearsal_ok", status = "green", icon = "check" })
		else
			M.cue({ type = "toast", key = "rehearsal_fail", status = "red", icon = "retry" })
		end
		M.broadcast()
	end)
end

------------------------------------------------------------------ init
function M.init(deps)
	Hangar, Consoles, Cutscenes, Urgent, Expedition, Progress, Lobby, Heavy =
		deps.Hangar, deps.Consoles, deps.Cutscenes, deps.Urgent, deps.Expedition, deps.Progress, deps.Lobby, deps.Heavy
	Remotes.Request.OnServerEvent:Connect(M.onRequest)
	Players.PlayerAdded:Connect(function(p)
		M.broadcast()
		p.CharacterAdded:Connect(function()
			task.wait(1)
			Remotes.State:FireClient(p, M.snapshot())
		end)
	end)
	Players.PlayerRemoving:Connect(function(p)
		S.roles[tostring(p.UserId)] = nil
		lastRequest[p] = nil
		M.broadcast()
	end)
	local proj = Citadel.Atrium.Hologram.Projector
	local pr = proj:FindFirstChild("BriefPrompt") or Instance.new("ProximityPrompt")
	pr.Name = "BriefPrompt"
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "p_brief")
	pr.Parent = proj
	pr.Triggered:Connect(M.openMissions)
	task.spawn(function()
		while true do
			task.wait(1)
			if S.phase == "Build" then M.broadcast() end
		end
	end)
	M.recompute()
end

return M
