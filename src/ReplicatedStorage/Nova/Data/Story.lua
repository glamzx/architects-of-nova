-- Story v2 "The Blackout": hologram cutscenes, team votes and their consequences.
-- Step: { who = speaker, key = line } | { vote = { key, options = { { key, flag?, orbit?, rack? } } } }
-- Speakers: kade (mentor), vex (antagonist), bip (droid), echo (archive AI).
-- brief = before the build, field = landing at site A, site = arrival at site B, win/final = after the mission.
return {
	M0 = {
		brief = {
			{ who = "kade", key = "s_m0_b1" }, { who = "kade", key = "s_m0_b2" }, { who = "kade", key = "s_m0_b3" },
			{ who = "kade", key = "s_m0_b4" }, { who = "bip", key = "s_m0_b5" },
			{ vote = { key = "v_m0", options = { { key = "v_m0_a", flag = "goal_camera" }, { key = "v_m0_b", flag = "goal_rad" } } } },
		},
		win = { { who = "kade", key = "s_m0_w1" }, { who = "echo", key = "s_m0_w2" }, { who = "vex", key = "s_m0_w3" }, { who = "kade", key = "s_m0_w4" } },
	},
	M1 = {
		brief = {
			{ who = "kade", key = "s_m1_b1" }, { who = "kade", key = "s_m1_b2" }, { who = "vex", key = "s_m1_b3" },
			{ vote = { key = "v_m1", options = { { key = "v_m1_a", orbit = "GEO" }, { key = "v_m1_b", orbit = "LEO_SWARM" } } } },
		},
		field = { { who = "kade", key = "s_m1_f1" }, { who = "bip", key = "s_m1_f2" } },
		site = { { who = "echo", key = "s_m1_f3" } },
		win = { { who = "kade", key = "s_m1_w1" }, { who = "echo", key = "s_m1_w2" }, { who = "vex", key = "s_m1_w3" } },
	},
	M2 = {
		brief = {
			{ who = "echo", key = "s_m2_b1" }, { who = "echo", key = "s_m2_b2" }, { who = "kade", key = "s_m2_b3" },
			{ vote = { key = "v_m2", options = { { key = "v_m2_a", flag = "target_cabeus" }, { key = "v_m2_b", flag = "target_shackleton" } } } },
		},
		field = { { who = "kade", key = "s_m2_f1" }, { who = "echo", key = "s_m2_f2" } },
		site = { { who = "bip", key = "s_m2_s1" }, { who = "echo", key = "s_m2_s2" } },
		win = { { who = "echo", key = "s_m2_w1" }, { who = "echo", key = "s_m2_w2" }, { who = "kade", key = "s_m2_w3" } },
	},
	M3 = {
		brief = {
			{ who = "kade", key = "s_m3_b1" }, { who = "bip", key = "s_m3_b2" },
			{ vote = { key = "v_m3", options = { { key = "v_m3_a", flag = "site_delta" }, { key = "v_m3_b", flag = "site_plain" } } } },
		},
		field = { { who = "kade", key = "s_m3_f1" }, { who = "bip", key = "s_m3_f2" } },
		site = { { who = "echo", key = "s_m3_s1" }, { who = "kade", key = "s_m3_s2" } },
		win = { { who = "echo", key = "s_m3_w1" }, { who = "kade", key = "s_m3_w2" } },
	},
	M4 = {
		brief = {
			{ who = "kade", key = "s_m4_b1" }, { who = "echo", key = "s_m4_b2" }, { who = "vex", key = "s_m4_b3" },
			{ vote = { key = "v_m4", options = { { key = "v_m4_a", flag = "own_mirror" }, { key = "v_m4_b", flag = "vex_mirror" } } } },
		},
		field = { { who = "kade", key = "s_m4_f1" } },
		site = { { who = "kade", key = "s_m4_s1" } },
		win = { { who = "echo", key = "s_m4_w1" }, { who = "kade", key = "s_m4_w2" }, { who = "vex", key = "s_m4_w3" }, { who = "kade", key = "s_m4_w4" } },
	},
	M5 = {
		brief = {
			{ who = "echo", key = "s_m5_b1" }, { who = "kade", key = "s_m5_b2" }, { who = "kade", key = "s_m5_b3" },
			{ vote = { key = "v_m5", options = { { key = "v_m5_a", orbit = "EUROPA_DIRECT" }, { key = "v_m5_b", orbit = "EUROPA_GA" } } } },
		},
		field = { { who = "kade", key = "s_m5_f1" } },
		site = { { who = "echo", key = "s_m5_s1" }, { who = "bip", key = "s_m5_s2" } },
		win = { { who = "echo", key = "s_m5_w1" }, { who = "kade", key = "s_m5_w2" } },
	},
	M6 = {
		brief = {
			{ who = "kade", key = "s_m6_b1" }, { who = "vex", key = "s_m6_b2" }, { who = "bip", key = "s_m6_b3" },
			{ vote = { key = "v_m6", options = { { key = "v_m6_a", flag = "refuse_vex", rack = { bay = 1, ids = { "obc", "obc_hard" } } }, { key = "v_m6_b", flag = "accept_vex", rack = { bay = 1, ids = { "obc", "vex_unit" } } } } } },
		},
		field = { { who = "kade", key = "s_m6_f1" }, { who = "bip", key = "s_m6_f2" } },
		site = { { who = "echo", key = "s_m6_s1" }, { who = "kade", key = "s_m6_s2" } },
		final = {
			{ who = "kade", key = "s_fin_1" }, { who = "echo", key = "s_fin_2" }, { who = "vex", key = "s_fin_3" }, { who = "kade", key = "s_fin_4" }, { who = "vex", key = "s_fin_5" },
			{ vote = { key = "v_fin", options = { { key = "v_fin_a", flag = "reconcile" }, { key = "v_fin_b", flag = "tribunal" } } } },
		},
	},
}
