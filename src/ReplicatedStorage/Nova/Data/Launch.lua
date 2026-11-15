--!strict
-- Rockets and orbits: pure data.
-- capacityKg per orbit: the farther the orbit, the less a rocket can lift
-- (GEO and deep space carry far less than LEO). Game-scale numbers for a rideshare slot.

-- Orbits / destinations. solarFactor = sunlight vs Earth (1/r^2): Mars ~0.43, Jupiter ~0.037.
-- copies = identical spacecraft launched together (swarm). flags drive ops checks.
local Orbits = {
	LEO400 = { id = "LEO400", nameKey = "orbit_leo400", altitudeKm = 400, periodMin = 92, eclipseFrac = 0.38, linkNeed = 0.8 },
	SSO600 = { id = "SSO600", nameKey = "orbit_sso600", altitudeKm = 600, periodMin = 97, eclipseFrac = 0.35, linkNeed = 1.0 },
	GEO = { id = "GEO", nameKey = "orbit_geo", altitudeKm = 35786, periodMin = 1436, eclipseFrac = 0.01, linkNeed = 4.0 },
	LEO_SWARM = { id = "LEO_SWARM", nameKey = "orbit_swarm", altitudeKm = 550, periodMin = 95, eclipseFrac = 0.37, linkNeed = 1.0, copies = 3, debris = true },
	LUNAR_POLAR = { id = "LUNAR_POLAR", nameKey = "orbit_lunar_polar", altitudeKm = 50, periodMin = 113, eclipseFrac = 0.3, linkNeed = 2.5, polar = true, dark = true },
	LUNAR_EQ = { id = "LUNAR_EQ", nameKey = "orbit_lunar_eq", altitudeKm = 50, periodMin = 113, eclipseFrac = 0.3, linkNeed = 2.5, dark = true },
	MARS = { id = "MARS", nameKey = "orbit_mars", altitudeKm = 0, periodMin = 1477, eclipseFrac = 0.5, linkNeed = 3.0, solarFactor = 0.43, surface = true, dust = true, delayMin = 12 },
	L2 = { id = "L2", nameKey = "orbit_l2", altitudeKm = 1500000, periodMin = 262800, eclipseFrac = 0, linkNeed = 3.0, deploy = true },
	EUROPA_DIRECT = { id = "EUROPA_DIRECT", nameKey = "orbit_europa_direct", altitudeKm = 25, periodMin = 5000, eclipseFrac = 0.1, linkNeed = 5.0, solarFactor = 0.037, radiation = true, delayMin = 45 },
	EUROPA_GA = { id = "EUROPA_GA", nameKey = "orbit_europa_ga", altitudeKm = 25, periodMin = 5000, eclipseFrac = 0.1, linkNeed = 5.0, solarFactor = 0.037, radiation = true, delayMin = 45, slow = true },
	ASTEROID = { id = "ASTEROID", nameKey = "orbit_asteroid", altitudeKm = 11000000, periodMin = 0, eclipseFrac = 0, linkNeed = 3.0, solarFactor = 0.8, storm = true, needPush = 2 },
	ASTEROID_EARLY = { id = "ASTEROID_EARLY", nameKey = "orbit_asteroid_early", altitudeKm = 20000000, periodMin = 0, eclipseFrac = 0, linkNeed = 3.5, solarFactor = 0.7, storm = true, needPush = 1, timeMul = 0.6 },
}

-- fairing = biggest module size that fits under the nose cone
local Rockets = {
	kestrel = { id = "kestrel", nameKey = "rocket_kestrel", cost = 20, fairing = 1, capacityKg = { LEO400 = 3.0, SSO600 = 2.4, GEO = 0 }, pad = "PadA" },
	heron = { id = "heron", nameKey = "rocket_heron", cost = 40, fairing = 1, capacityKg = { LEO400 = 6.0, SSO600 = 5.0, GEO = 1.0 }, pad = "PadB" },
	condor = { id = "condor", nameKey = "rocket_condor", cost = 60, fairing = 1, pad = "PadA",
		capacityKg = { LEO400 = 40, LEO_SWARM = 40, GEO = 14, LUNAR_POLAR = 18, LUNAR_EQ = 19, MARS = 12, L2 = 14, EUROPA_DIRECT = 6, EUROPA_GA = 12, ASTEROID = 14, ASTEROID_EARLY = 12 } },
	titan = { id = "titan", nameKey = "rocket_titan", cost = 110, fairing = 2, pad = "PadB",
		capacityKg = { LEO400 = 90, LEO_SWARM = 90, GEO = 30, LUNAR_POLAR = 38, LUNAR_EQ = 40, MARS = 26, L2 = 30, EUROPA_DIRECT = 16, EUROPA_GA = 26, ASTEROID = 30, ASTEROID_EARLY = 26 } },
}

local Frames = {
	-- CubeSat 101: 3U = 10x10x34 cm, legacy limit 1.33 kg per U (4 kg for 3U)
	cubesat3u = {
		id = "cubesat3u",
		massKg = 0.4,
		cost = 10,
		maxMassKg = 4.0,
		-- every part has its own place (kids see where it goes; no "anything anywhere")
		slots = {
			{ id = "top", accepts = { antenna = true }, icon = "comms", label = { "АНТЕННА", "ANTENNA" } },
			{ id = "side", accepts = { panel = true }, icon = "panel", label = { "СОЛНЕЧНЫЕ ПАНЕЛИ", "SOLAR PANELS" } },
			{ id = "u3", accepts = { computer = true }, icon = "computer", label = { "КОМПЬЮТЕР", "COMPUTER" } },
			{ id = "u2", accepts = { battery = true }, icon = "battery", label = { "БАТАРЕЯ", "BATTERY" } },
			{ id = "u1", accepts = { instrument = true }, icon = "instrument", label = { "ПРИБОР", "INSTRUMENT" } },
		},
	},
	-- Probe bus for interplanetary missions
	probe = {
		id = "probe",
		massKg = 4.0,
		cost = 20,
		maxMassKg = 30,
		slots = {
			{ id = "top", accepts = { antenna = true }, icon = "comms", label = { "АНТЕННА", "ANTENNA" } },
			{ id = "side", accepts = { panel = true }, icon = "panel", label = { "СОЛНЕЧНЫЕ ПАНЕЛИ", "SOLAR PANELS" } },
			{ id = "b1", accepts = { computer = true }, icon = "computer", label = { "КОМПЬЮТЕР", "COMPUTER" } },
			{ id = "b2", accepts = { battery = true, rtg = true }, icon = "battery", label = { "ПИТАНИЕ", "POWER" } },
			{ id = "b3", accepts = { instrument = true }, icon = "instrument", label = { "ПРИБОР", "INSTRUMENT" } },
			{ id = "b4", accepts = { shield = true }, icon = "lock", label = { "ЗАЩИТА", "SHIELD" } },
			{ id = "bottom", accepts = { edl = true, payload = true }, icon = "target", label = { "ПОСАДКА / ГРУЗ", "LANDING / PAYLOAD" } },
		},
	},
}

return { orbits = Orbits, rockets = Rockets, frames = Frames }
