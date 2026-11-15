-- Field locations reached by the crew rocket. Objectives are data; ExpeditionService runs them.
-- Objective types: repair (hold E), align (hold E, comms x2), scan (scientist reveals), deliver (carry light item),
-- heavy (two-person carry), timed (press while active), sync (several spots within a window), sequence (spots in order), shelter.
return {
	M1 = { id = "orbit", nameKey = "loc_orbit", origin = Vector3.new(5000, 600, 0), lighting = "orbit", gravity = 196.2,
		siteB = { nameKey = "loc_orbit_b", objectives = {
			{ id = "array", type = "repair", key = "o_orbit_array", icon = "panel", spots = { "Array1", "Array2" }, hold = 4, class = "engineer", game = "pipes" },
			{ id = "log", type = "align", key = "o_log", icon = "data", spots = { "LogTerminal" }, hold = 4, class = "comms" },
		} },
		objectives = {
			{ id = "dish", type = "align", key = "o_align", icon = "comms", spots = { "Dish1", "Dish2", "Dish3" }, hold = 4, class = "comms" },
			{ id = "relay", type = "sync", key = "o_relay", icon = "spark", spots = { "RelayA", "RelayB" }, window = 2.5 },
		} },
	M2 = { id = "moon", nameKey = "loc_moon", origin = Vector3.new(-5000, 0, 0), lighting = "moon", gravity = 70,
		siteB = { nameKey = "loc_moon_b", objectives = {
			{ id = "icescan", type = "scan", key = "o_ice_scan", icon = "instrument", spots = { "IceScan1", "IceScan2", "IceScan3" }, hold = 2.5, class = "scientist" },
			{ id = "drill", type = "repair", key = "o_ice_drill", icon = "target", spots = { "Drill" }, hold = 5, class = "engineer", game = "timing" },
		} },
		objectives = {
			{ id = "scan", type = "scan", key = "o_scan", icon = "instrument", spots = { "Scan1", "Scan2", "Scan3" }, hold = 2.5, class = "scientist" },
			{ id = "samples", type = "deliver", key = "o_samples", icon = "carry", item = "sample", from = "Samples", to = "Lander", count = 3 },
			{ id = "heater", type = "repair", key = "o_heater", icon = "power", spots = { "Heater" }, hold = 4, class = "engineer", game = "wires" },
			{ id = "drive", type = "drive", key = "o_drive_moon", icon = "target", to = "RoverTarget" },
		} },
	M3 = { id = "mars", nameKey = "loc_mars", origin = Vector3.new(0, 0, 5000), lighting = "mars", gravity = 120,
		siteB = { nameKey = "loc_mars_b", objectives = {
			{ id = "cache", type = "deliver", key = "o_mars_cache", icon = "carry", item = "sample", from = "TubeRack", to = "Cache", count = 2 },
			{ id = "hab", type = "repair", key = "o_mars_hab", icon = "power", spots = { "HabPower1", "HabPower2" }, hold = 4, class = "engineer", game = "wires" },
		} },
		objectives = {
			{ id = "panels", type = "repair", key = "o_panels", icon = "panel", spots = { "Panel1", "Panel2", "Panel3" }, hold = 3, class = "engineer", game = "timing" },
			{ id = "rtg", type = "heavy", key = "o_rtg", icon = "power", from = "Cargo", to = "Rover" },
			{ id = "storm", type = "shelter", key = "o_storm", icon = "shadow", spot = "Shelter", timer = 30 },
			{ id = "drive", type = "drive", key = "o_drive_mars", icon = "target", to = "RoverTarget" },
		} },
	M4 = { id = "l2", nameKey = "loc_l2", origin = Vector3.new(5000, 600, 5000), lighting = "orbit", gravity = 60,
		siteB = { nameKey = "loc_l2_b", objectives = {
			{ id = "mirror", type = "sync", key = "o_l2_mirror", icon = "spark", spots = { "Seg1", "Seg2", "Seg3" }, window = 2.5 },
			{ id = "guider", type = "align", key = "o_l2_guider", icon = "target", spots = { "Guider" }, hold = 4, class = "comms" },
		} },
		objectives = {
			{ id = "latches", type = "sequence", key = "o_latches", icon = "lock", spots = { "Latch1", "Latch2", "Latch3", "Latch4" } },
			{ id = "patch", type = "repair", key = "o_patch", icon = "warning", spots = { "Patch" }, hold = 4, class = "engineer", game = "timing" },
			{ id = "deploy", type = "sync", key = "o_deploy", icon = "spark", spots = { "DeployA", "DeployB", "DeployC" }, window = 2 },
		} },
	M5 = { id = "europa", nameKey = "loc_europa", origin = Vector3.new(-5000, 0, 5000), lighting = "europa", gravity = 50,
		siteB = { nameKey = "loc_europa_b", objectives = {
			{ id = "radar", type = "align", key = "o_europa_radar", icon = "comms", spots = { "Radar1", "Radar2" }, hold = 4, class = "comms" },
			{ id = "capsule", type = "repair", key = "o_europa_capsule", icon = "data", spots = { "Capsule" }, hold = 5, class = "engineer", game = "pipes" },
		} },
		objectives = {
			{ id = "vents", type = "timed", key = "o_vents", icon = "data", spots = { "Vent1", "Vent2", "Vent3" }, period = 14, active = 6 },
			{ id = "beacon", type = "deliver", key = "o_beacon", icon = "comms", item = "beacon", from = "Depot", to = "RelayPad", count = 1 },
			{ id = "radiation", type = "shelter", key = "o_radiation", icon = "warning", spot = "Shelter", timer = 30 },
		} },
	M6 = { id = "asteroid", nameKey = "loc_asteroid", origin = Vector3.new(0, 0, -5000), lighting = "asteroid", gravity = 30,
		siteB = { nameKey = "loc_asteroid_b", objectives = {
			{ id = "shelter", type = "repair", key = "o_ast_power", icon = "power", spots = { "ShelterPower" }, hold = 4, class = "engineer", game = "wires" },
			{ id = "wake", type = "sync", key = "o_ast_wake", icon = "spark", spots = { "Pod1", "Pod2", "Pod3", "Pod4" }, window = 2.5 },
		} },
		objectives = {
			{ id = "beacons", type = "deliver", key = "o_navbeacons", icon = "target", item = "navbeacon", from = "Depot", to = "Mark", count = 3 },
			{ id = "guidance", type = "align", key = "o_guidance", icon = "target", spots = { "Guidance" }, hold = 5, class = "comms" },
			{ id = "final", type = "sync", key = "o_final", icon = "flare", spots = { "Sync1", "Sync2", "Sync3", "Sync4" }, window = 2.5 },
		} },
}
