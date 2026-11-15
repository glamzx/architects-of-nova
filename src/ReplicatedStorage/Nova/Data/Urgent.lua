-- Urgent problems during Build: fix before the timer ends or an extra task appears.
-- spot = name of a part in Workspace.Citadel.UrgentSpots. class = who fixes fastest (x2); others slower (x0.5).
return {
	{ id = "coolant", key = "u_coolant", icon = "warning", spot = "Coolant", class = "engineer", hold = 3, timer = 35, penaltyBudget = 10 },
	{ id = "sparks", key = "u_sparks", icon = "power", spot = "PowerPanel", class = "engineer", hold = 3, timer = 35, penaltyBudget = 10 },
	{ id = "noise", key = "u_noise", icon = "comms", spot = "RoofAntenna", class = "comms", hold = 3, timer = 35, penaltyBudget = 8 },
	{ id = "calib", key = "u_calib", icon = "instrument", spot = "CalibBench", class = "scientist", hold = 3, timer = 35, penaltyBudget = 8 },
	{ id = "audit", key = "u_audit", icon = "budget", spot = "AuditDesk", class = "commander", hold = 3, timer = 35, penaltyBudget = 15 },
}
