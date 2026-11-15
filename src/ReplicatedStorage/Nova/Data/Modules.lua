--!strict
-- Module catalog: pure data. New modules = new rows, no code changes.
-- Units: massKg, powerGenW (orbit-average), powerUseW, cost (credits),
-- batteryWh, link (comms strength, compared with orbit need),
-- downlinkMB / dataMB (per orbit), science (points), radHard (survives flares).
-- Numbers are simplified from NASA CubeSat 101 (CSLI) typical ranges.

export type ModuleDef = {
	id: string,
	category: string, -- panel | battery | antenna | instrument | computer
	nameKey: string,
	massKg: number,
	cost: number,
	powerGenW: number?,
	powerUseW: number?,
	batteryWh: number?,
	link: number?,
	downlinkMB: number?,
	dataMB: number?,
	science: number?,
	radHard: boolean?,
	color: Color3,
}

local Modules: { [string]: ModuleDef } = {
	panel_body = { id = "panel_body", category = "panel", nameKey = "mod_panel_body", massKg = 0.2, cost = 8, powerGenW = 2.2, color = Color3.fromRGB(40, 70, 160) },
	panel_wing = { id = "panel_wing", category = "panel", nameKey = "mod_panel_wing", massKg = 0.6, cost = 18, powerGenW = 5.0, color = Color3.fromRGB(30, 90, 200) },
	battery_s = { id = "battery_s", category = "battery", nameKey = "mod_battery_s", massKg = 0.3, cost = 6, batteryWh = 20, color = Color3.fromRGB(60, 200, 110) },
	battery_l = { id = "battery_l", category = "battery", nameKey = "mod_battery_l", massKg = 0.7, cost = 12, batteryWh = 40, color = Color3.fromRGB(40, 160, 90) },
	antenna_uhf = { id = "antenna_uhf", category = "antenna", nameKey = "mod_antenna_uhf", massKg = 0.1, cost = 5, powerUseW = 1.0, link = 1.0, downlinkMB = 5, color = Color3.fromRGB(220, 220, 230) },
	antenna_s = { id = "antenna_s", category = "antenna", nameKey = "mod_antenna_s", massKg = 0.3, cost = 15, powerUseW = 2.0, link = 2.5, downlinkMB = 40, color = Color3.fromRGB(255, 200, 80) },
	camera = { id = "camera", category = "instrument", nameKey = "mod_camera", massKg = 0.9, cost = 15, powerUseW = 1.5, dataMB = 30, science = 2, color = Color3.fromRGB(200, 80, 255) },
	rad_sensor = { id = "rad_sensor", category = "instrument", nameKey = "mod_rad_sensor", massKg = 0.3, cost = 10, powerUseW = 0.8, dataMB = 4, science = 1, color = Color3.fromRGB(255, 90, 140) },
	obc = { id = "obc", category = "computer", nameKey = "mod_obc", massKg = 0.15, cost = 10, powerUseW = 0.4, color = Color3.fromRGB(0, 200, 255) },
	obc_hard = { id = "obc_hard", category = "computer", nameKey = "mod_obc_hard", massKg = 0.3, cost = 20, powerUseW = 0.6, radHard = true, color = Color3.fromRGB(0, 140, 255) },

	-- Probe-class modules (M1-M6). Same units; bigger numbers.
	panel_array = { id = "panel_array", heavy = true, category = "panel", nameKey = "mod_panel_array", massKg = 3.0, cost = 30, powerGenW = 14, color = Color3.fromRGB(36, 70, 150) },
	panel_giant = { id = "panel_giant", heavy = true, category = "panel", nameKey = "mod_panel_giant", massKg = 8.0, cost = 60, powerGenW = 120, color = Color3.fromRGB(28, 60, 140) }, -- Europa Clipper: ~30 m wings
	rtg = { id = "rtg", heavy = true, category = "rtg", nameKey = "mod_rtg", massKg = 5.0, cost = 70, rtgW = 8, color = Color3.fromRGB(150, 150, 160) }, -- Perseverance MMRTG ~110 W
	battery_xl = { id = "battery_xl", category = "battery", nameKey = "mod_battery_xl", massKg = 2.0, cost = 15, batteryWh = 120, color = Color3.fromRGB(40, 150, 90) },
	hga = { id = "hga", heavy = true, category = "antenna", nameKey = "mod_hga", massKg = 2.5, cost = 35, powerUseW = 3.0, link = 6.0, downlinkMB = 200, color = Color3.fromRGB(235, 235, 235) },
	neutron_spec = { id = "neutron_spec", category = "instrument", nameKey = "mod_neutron_spec", massKg = 2.0, cost = 30, powerUseW = 2.0, dataMB = 20, science = 3, darkOK = true, color = Color3.fromRGB(120, 200, 255) }, -- LRO LEND
	radar = { id = "radar", category = "instrument", nameKey = "mod_radar", massKg = 3.5, cost = 45, powerUseW = 6.0, dataMB = 80, science = 4, darkOK = true, color = Color3.fromRGB(255, 160, 80) }, -- Mini-RF
	mirror_fold = { id = "mirror_fold", heavy = true, category = "instrument", nameKey = "mod_mirror_fold", massKg = 6.0, cost = 60, powerUseW = 4.0, dataMB = 60, science = 6, hinges = true, color = Color3.fromRGB(230, 180, 60) }, -- JWST 18 segments
	mirror_solid = { id = "mirror_solid", heavy = true, category = "instrument", nameKey = "mod_mirror_solid", massKg = 7.0, cost = 50, powerUseW = 4.0, dataMB = 80, science = 8, size = 2, color = Color3.fromRGB(210, 160, 50) },
	vault = { id = "vault", heavy = true, category = "shield", nameKey = "mod_vault", massKg = 4.0, cost = 25, shields = true, color = Color3.fromRGB(120, 120, 128) }, -- Juno titanium vault
	edl_kit = { id = "edl_kit", heavy = true, category = "edl", nameKey = "mod_edl_kit", massKg = 6.0, cost = 30, edl = 1, color = Color3.fromRGB(190, 120, 70) },
	edl_crane = { id = "edl_crane", heavy = true, category = "edl", nameKey = "mod_edl_crane", massKg = 9.0, cost = 55, edl = 2, color = Color3.fromRGB(200, 140, 70) }, -- sky crane
	impactor_s = { id = "impactor_s", heavy = true, category = "payload", nameKey = "mod_impactor_s", massKg = 6.0, cost = 25, push = 1, color = Color3.fromRGB(110, 110, 116) },
	impactor_l = { id = "impactor_l", heavy = true, category = "payload", nameKey = "mod_impactor_l", massKg = 12.0, cost = 40, push = 2, color = Color3.fromRGB(90, 90, 96) }, -- DART ~570 kg
	vex_unit = { id = "vex_unit", category = "computer", nameKey = "mod_vex_unit", massKg = 0.1, cost = 2, powerUseW = 0.2, vex = true, color = Color3.fromRGB(200, 40, 70) }, -- Vex's cheap part: hidden risk
}

-- Default rack layout (M0). Missions may override with mission.racks.
local Racks = {
	{ category = "computer", ids = { "obc", "obc_hard" } },
	{ category = "battery", ids = { "battery_s", "battery_l" } },
	{ category = "panel", ids = { "panel_body", "panel_wing" } },
	{ category = "antenna", ids = { "antenna_uhf", "antenna_s" } },
	{ category = "instrument", ids = { "rad_sensor", "camera" } },
}

return { defs = Modules, racks = Racks }
