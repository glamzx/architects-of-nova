-- Character classes = the 4 NASA mission roles. Each class owns module categories it installs
-- (others can do it only if nobody with that class is in the lobby — then BIP-7 helps, slower).
return {
	order = { "commander", "engineer", "scientist", "comms" },
	byId = {
		commander = { id = "commander", icon = "commander", color = Color3.fromRGB(246, 196, 72), console = "CommanderConsole",
			installs = { edl = true, payload = true }, launches = true, tiebreak = true,
			perkKey = "perk_commander", descKeys = { "cls_commander_1", "cls_commander_2", "cls_commander_3" } },
		engineer = { id = "engineer", icon = "engineer", color = Color3.fromRGB(255, 150, 80), console = "EngineerConsole",
			installs = { panel = true, battery = true, rtg = true, computer = true, shield = true }, repairMul = 2,
			perkKey = "perk_engineer", descKeys = { "cls_engineer_1", "cls_engineer_2", "cls_engineer_3" } },
		scientist = { id = "scientist", icon = "scientist", color = Color3.fromRGB(170, 140, 230), console = "ScientistConsole",
			installs = { instrument = true }, scanner = true, rareBonus = true,
			perkKey = "perk_scientist", descKeys = { "cls_scientist_1", "cls_scientist_2", "cls_scientist_3" } },
		comms = { id = "comms", icon = "headset", color = Color3.fromRGB(96, 206, 216), console = "AntennaConsole",
			installs = { antenna = true }, chooseRocket = true, earlyWarning = 5, alignMul = 2,
			perkKey = "perk_comms", descKeys = { "cls_comms_1", "cls_comms_2", "cls_comms_3" } },
	},
}
