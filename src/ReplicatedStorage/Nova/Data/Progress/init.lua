-- Gamification: concept-maturity ranks (JPL CML), achievements, Grok's shop, spacesuit outfitter.
return {
	ranks = { -- XP thresholds
		{ key = "rank_1", xp = 0 }, { key = "rank_2", xp = 400 }, { key = "rank_3", xp = 1200 }, { key = "rank_4", xp = 2400 }, { key = "rank_5", xp = 4000 },
	},
	achievements = {
		first_contact = { key = "ach_first_contact", icon = "headset", xp = 100 },
		margin = { key = "ach_margin", icon = "check", xp = 100 },
		sync = { key = "ach_sync", icon = "spark", xp = 100 },
		heavy = { key = "ach_heavy", icon = "carry", xp = 100 },
		firefighter = { key = "ach_firefighter", icon = "warning", xp = 150 },
		no_vex = { key = "ach_no_vex", icon = "lock", xp = 200 },
		scientist = { key = "ach_scientist", icon = "scientist", xp = 150 },
		legend = { key = "ach_legend", icon = "star", xp = 200 },
		explorer = { key = "ach_explorer", icon = "orbit", xp = 150 },
		trainer = { key = "ach_trainer", icon = "rocket", xp = 100 },
		campaign = { key = "ach_campaign", icon = "home", xp = 500 },
	},
	shop = {
		{ id = "bip_gold", key = "shop_bip_gold", slot = "bip", color = Color3.fromRGB(230, 186, 80), price = 120 },
		{ id = "bip_violet", key = "shop_bip_violet", slot = "bip", color = Color3.fromRGB(160, 120, 230), price = 100 },
		-- useful items: credits buy real help in missions (never pay-to-win: everything is earned by playing)
		{ id = "kit_repair", key = "shop_kit_repair", desc = "shop_kit_repair_d", slot = "consumable", icon = "warning", color = Color3.fromRGB(240, 120, 60), price = 30 },
		{ id = "kit_grant", key = "shop_kit_grant", desc = "shop_kit_grant_d", slot = "consumable", icon = "budget", color = Color3.fromRGB(246, 196, 72), price = 40 },
		{ id = "bip_turbo", key = "shop_bip_turbo", desc = "shop_bip_turbo_d", slot = "upgrade", icon = "spark", color = Color3.fromRGB(96, 206, 216), price = 150 },
	},
	-- Spacesuit outfitter (NovaClient.Outfitter + ProgressService/SuitKit). Credits are earned by playing only.
	-- slot: suit (suit colour) | helmet (style) | visor (tint) | patch (shoulder patch). price 0 = free default, always owned.
	-- key/fact = StringsShop keys. Old ids kept so saved profiles keep what they bought (suit_navy -> suit_cobalt).
	outfit = {
		{ id = "suit_white", slot = "suit", key = "of_suit_white", fact = "of_suit_white_f", color = Color3.fromRGB(234, 235, 230), price = 0 },
		{ id = "suit_amber", slot = "suit", key = "of_suit_amber", fact = "of_suit_amber_f", color = Color3.fromRGB(236, 112, 38), price = 40 },
		{ id = "suit_mint", slot = "suit", key = "of_suit_mint", fact = "of_suit_mint_f", color = Color3.fromRGB(112, 204, 178), price = 50 },
		{ id = "suit_cobalt", slot = "suit", key = "of_suit_cobalt", fact = "of_suit_cobalt_f", color = Color3.fromRGB(40, 86, 178), price = 60 },
		{ id = "suit_red", slot = "suit", key = "of_suit_red", fact = "of_suit_red_f", color = Color3.fromRGB(204, 48, 40), price = 60 },
		{ id = "suit_black", slot = "suit", key = "of_suit_black", fact = "of_suit_black_f", color = Color3.fromRGB(46, 48, 54), price = 80 },
		{ id = "suit_silver", slot = "suit", key = "of_suit_silver", fact = "of_suit_silver_f", color = Color3.fromRGB(184, 190, 198), mat = "Foil", refl = 0.12, price = 100 },
		{ id = "suit_gold", slot = "suit", key = "of_suit_gold", fact = "of_suit_gold_f", color = Color3.fromRGB(218, 170, 70), mat = "Foil", refl = 0.12, price = 150 },

		{ id = "helmet_bubble", slot = "helmet", style = "bubble", key = "of_helmet_bubble", fact = "of_helmet_bubble_f", price = 0,
			visor = { color = Color3.fromRGB(180, 210, 230), tr = 0.72, refl = 0.05 } },
		{ id = "helmet_eva", slot = "helmet", style = "eva", cover = true, key = "of_helmet_eva", fact = "of_helmet_eva_f", price = 80,
			visor = { color = Color3.fromRGB(222, 166, 58), tr = 0.22, refl = 0.35 } },
		{ id = "helmet_sport", slot = "helmet", style = "sport", cover = true, key = "of_helmet_sport", fact = "of_helmet_sport_f", price = 100,
			visor = { color = Color3.fromRGB(34, 38, 46), tr = 0.3, refl = 0.25 } },
		{ id = "helmet_pro", slot = "helmet", style = "pro", cover = true, key = "of_helmet_pro", fact = "of_helmet_pro_f", price = 150,
			visor = { color = Color3.fromRGB(64, 72, 86), tr = 0.25, refl = 0.45 } },

		{ id = "visor_std", slot = "visor", key = "of_visor_std", fact = "of_visor_std_f", color = Color3.fromRGB(150, 170, 186), price = 0 },
		{ id = "visor_teal", slot = "visor", key = "of_visor_teal", fact = "of_visor_teal_f", color = Color3.fromRGB(80, 190, 204), tr = 0.35, refl = 0.3, price = 40 },
		{ id = "visor_gold", slot = "visor", key = "of_visor_gold", fact = "of_visor_gold_f", color = Color3.fromRGB(222, 166, 58), tr = 0.22, refl = 0.35, price = 50 },
		{ id = "visor_mirror", slot = "visor", key = "of_visor_mirror", fact = "of_visor_mirror_f", color = Color3.fromRGB(196, 202, 212), tr = 0.18, refl = 0.6, price = 60 },

		{ id = "patch_blue", slot = "patch", key = "of_patch_blue", fact = "of_patch_blue_f", color = Color3.fromRGB(36, 70, 150), price = 0 },
		{ id = "patch_red", slot = "patch", key = "of_patch_red", fact = "of_patch_red_f", color = Color3.fromRGB(224, 60, 49), price = 30 },
		{ id = "patch_mint", slot = "patch", key = "of_patch_mint", fact = "of_patch_mint_f", color = Color3.fromRGB(96, 196, 170), price = 30 },
		{ id = "patch_gold", slot = "patch", key = "of_patch_gold", fact = "of_patch_gold_f", color = Color3.fromRGB(214, 168, 64), price = 50 },
	},
	-- daily quests (3 per day, from this pool); progress comes from real play
	quests = {
		{ id = "fix", key = "q_fix", need = 2, reward = 30, icon = "warning" },
		{ id = "minigame", key = "q_minigame", need = 3, reward = 25, icon = "spark" },
		{ id = "launch", key = "q_launch", need = 1, reward = 30, icon = "rocket" },
		{ id = "site", key = "q_site", need = 2, reward = 40, icon = "orbit" },
		{ id = "heavy", key = "q_heavy", need = 1, reward = 25, icon = "carry" },
		{ id = "mission", key = "q_mission", need = 1, reward = 50, icon = "star" },
	},
	codes = { NOVA2026 = { credits = 100 }, SPACEAPPS = { credits = 75 }, MARGIN = { item = "kit_repair", n = 2 }, BIP7 = { item = "bip_violet" } },
	daily = { 20, 25, 30, 35, 50 },
	difficulty = {
		cadet = { key = "diff_cadet", timeMul = 1.5, urgentEvery = 240, urgentFirst = 150, urgentMax = 2, margin = 0.10 },
		pilot = { key = "diff_pilot", timeMul = 1.0, urgentEvery = 170, urgentFirst = 110, urgentMax = 3, margin = 0.10 },
		master = { key = "diff_master", timeMul = 0.75, urgentEvery = 110, urgentFirst = 75, urgentMax = 5, margin = 0.15 },
	},
}
