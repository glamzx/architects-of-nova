-- M0 "Spark": first CubeSat. Teaches budget + the 10% margin rule (NASA CubeSat 101).
-- Pure data: the generic MissionService runs it.
return {
	id = "M0",
	order = 0,
	titleKey = "m0_title",
	briefKey = "m0_brief", -- one hologram phrase, <= 7 words
	dialogue = { { who = "kade", key = "d_m0_1" }, { who = "bip", key = "d_m0_2" } },
	targetIcon = "cubesat",
	frame = "cubesat3u",
	orbit = "LEO400",
	orbits = { "LEO400" },
	rockets = { "kestrel", "heron" },
	core = { key = "core_m0", rarity = "common" },
	-- Objective tracker (cond is checked by the server)
	tasks = {
		{ id = "computer", key = "t_computer", icon = "computer", cond = { cat = "computer" } },
		{ id = "power", key = "t_power", icon = "panel", cond = { cat = "panel" } },
		{ id = "antenna", key = "t_antenna", icon = "comms", cond = { cat = "antenna" } },
		{ id = "launch", key = "t_launch", icon = "rocket", cond = { launched = true } },
		{ id = "contact", key = "t_contact", icon = "headset", cond = { event = "contact" } },
	},
	-- No "mission lost": every failure cause adds an extra task for the next attempt
	recovery = {
		computer = { key = "rt_computer", icon = "computer", cond = { cat = "computer" } },
		battery = { key = "rt_battery", icon = "battery", cond = { cat = "battery" } },
		margin = { key = "rt_margin", icon = "warning", cond = { green = { "mass", "power", "comms" } } },
		comms = { key = "rt_comms", icon = "comms", cond = { notRed = "comms" } },
		data = { key = "rt_data", icon = "data", cond = { notRed = "data" } },
		budget = { key = "rt_budget", icon = "budget", cond = { notRed = "budget" } },
		time = { key = "rt_time", icon = "time", cond = { notRed = "time" } },
	},
	budget = 100, -- credits for modules + frame + rocket
	buildTimeSec = 300, -- launch window
	marginRule = 0.10, -- below 10% margin = yellow, events may break the system

	-- Operations timeline. check = rule in MissionService.checks
	events = {
		{ id = "insertion", icon = "orbit", check = "computer", failKey = "ev_nobrain", okKey = "ev_insertion" },
		{ id = "eclipse", icon = "shadow", check = "battery", failKey = "ev_eclipse_fail", okKey = "ev_eclipse_ok" },
		{ id = "flare", icon = "flare", check = "margin", failKey = "ev_flare_fail", okKey = "ev_flare_ok" },
		{ id = "contact", icon = "comms", check = "comms", interactive = { kind = "press", consoles = { "AntennaConsole" }, timeout = 30, waitKey = "ev_contact_wait" }, failKey = "ev_contact_fail", okKey = "ev_contact_ok", objective = true },
		{ id = "downlink", icon = "data", check = "data", failKey = "ev_data_fail", okKey = "ev_data_ok", science = true },
	},

	-- Debrief hints: one per failure cause; nasa = real NASA case with a similar fate
	hints = {
		computer = { key = "hint_computer", nasa = "nasa_cubesat_silent" },
		battery = { key = "hint_battery", nasa = "nasa_opportunity" },
		margin = { key = "hint_margin", nasa = "nasa_cubesat101" },
		comms = { key = "hint_comms", nasa = "nasa_cubesat_silent" },
		data = { key = "hint_data", nasa = "nasa_kepler" },
		budget = { key = "hint_budget", nasa = "nasa_cubesat101" },
		time = { key = "hint_time", nasa = "nasa_iss_orbit" },
		success = { key = "hint_success", nasa = "nasa_iss_orbit" },
	},
}
