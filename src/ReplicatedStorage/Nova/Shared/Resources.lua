--!strict
-- Pure resource math shared by server (authoritative) and client (display only).
local Data = script.Parent.Parent.Data
local ModulesData = require(Data.Modules)
local Launch = require(Data.Launch)

local Resources = {}

Resources.ORDER = { "mass", "power", "budget", "data", "comms", "time" }

export type Gauge = { used: number, cap: number }

function Resources.status(g: Gauge, margin: number): string
	if g.cap <= 0 then
		return if g.used > 0 then "red" else "green"
	end
	local r = g.used / g.cap
	if r > 1 + 1e-6 then
		return "red"
	elseif r > 1 - margin + 1e-6 then
		return "yellow"
	end
	return "green"
end

function Resources.buildTime(mission: any, orbitId: string?)
	local orbit = Launch.orbits[orbitId or mission.orbit]
	return math.floor(mission.buildTimeSec * (orbit and orbit.timeMul or 1))
end

-- installed: { [slotId]: moduleId }; orbitId = chosen orbit (missions may offer several)
function Resources.compute(mission: any, installed: { [string]: string }, rocketId: string?, elapsed: number, orbitId: string?, opts: any?)
	opts = opts or {}
	local frame = Launch.frames[mission.frame]
	local orbit = Launch.orbits[orbitId or mission.orbit]
	local rocket = rocketId and Launch.rockets[rocketId] or nil
	local copies = orbit.copies or 1
	local solar = orbit.solarFactor or 1

	local mass, cost = frame.massKg, frame.cost
	local gen, use, wh, link, down, data, sci = 0, 0, 0, 0, 0, 0, 0
	local info = { hasComputer = false, hasBattery = false, radHard = false, count = 0, categories = {} :: { [string]: number },
		darkOK = false, shields = false, edl = 0, push = 0, hinges = false, vex = false, maxSize = 1, rtgW = 0, hasInstrument = false }
	for _, modId in installed do
		local m = ModulesData.defs[modId]
		if m then
			info.count += 1
			info.categories[m.category] = (info.categories[m.category] or 0) + 1
			mass += m.massKg
			cost += m.cost
			gen += (m.powerGenW or 0) * solar -- sunlight falls off as 1/r^2
			gen += m.rtgW or 0 -- RTG does not care about the Sun
			info.rtgW += m.rtgW or 0
			use += m.powerUseW or 0
			wh += m.batteryWh or 0
			link += m.link or 0
			down += m.downlinkMB or 0
			data += m.dataMB or 0
			sci += m.science or 0
			if m.category == "computer" then info.hasComputer = true end
			if m.category == "battery" then info.hasBattery = true end
			if m.radHard then info.radHard = true end
			if m.category == "instrument" then info.hasInstrument = true end
			if m.darkOK then info.darkOK = true end
			if m.shields then info.shields = true end
			if m.hinges then info.hinges = true end
			if m.vex then info.vex = true end
			info.edl = math.max(info.edl, m.edl or 0)
			info.push += m.push or 0
			info.maxSize = math.max(info.maxSize, m.size or 1)
		end
	end
	-- swarm: identical copies of the spacecraft fly together
	mass *= copies
	cost *= copies
	if rocket then cost += rocket.cost end
	cost += opts.extraCost or 0 -- penalties from missed emergencies

	-- In shadow only batteries (or an RTG) work: without a battery the orbit-average solar power shrinks
	local solarPart = gen - info.rtgW
	local powerCap = if info.hasBattery then gen else solarPart * (1 - orbit.eclipseFrac) + info.rtgW

	local gauges: { [string]: Gauge } = {
		mass = { used = mass / copies, cap = frame.maxMassKg }, -- per spacecraft; rocket check uses the total
		power = { used = use, cap = powerCap },
		budget = { used = cost, cap = mission.budget },
		data = { used = data, cap = down },
		comms = { used = orbit.linkNeed, cap = link },
		time = { used = math.min(elapsed, Resources.buildTime(mission, orbit.id) * (opts.timeMul or 1) * 1.2), cap = math.floor(Resources.buildTime(mission, orbit.id) * (opts.timeMul or 1)) },
	}
	info.copies = copies
	info.orbit = orbit.id
	info.fairing = rocket and rocket.fairing or 1
	info.batteryWh = wh
	info.science = sci
	info.massKg = mass
	info.rocketCapacity = if rocket then (rocket.capacityKg[orbit.id] or 0) else 0 -- capacity for the CHOSEN orbit
	info.powerGen = gen
	return gauges, info
end

return Resources
