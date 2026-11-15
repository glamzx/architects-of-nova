-- VoteInfo: what each team-vote option means, shown on the vote cards with a 3D preview (client VoteArt).
-- tags: icon (Config.IconSheet), tone good / warn / info, text {ru, en}. line: one short consequence.
local G, W, I = "good", "warn", "info"
return {
	v_m0_a = { art = "camera", tags = {
		{ "instrument", G, { "Снимки бури своими глазами", "Pictures of the storm" } },
		{ "data", W, { "Много данных: нужна хорошая связь", "Lots of data: needs a good link" } } },
		line = { "Как камеры марсохода Perseverance.", "Like the cameras on the Perseverance rover." } },
	v_m0_b = { art = "rad_sensor", tags = {
		{ "flare", G, { "Измеряет частицы бури", "Measures storm particles" } },
		{ "power", G, { "Мало энергии и данных", "Low power, little data" } } },
		line = { "Цифры вместо картинок, как прибор RAD на Curiosity.", "Numbers instead of pictures, like RAD on Curiosity." } },

	v_m1_a = { art = "geo", tags = {
		{ "orbit", I, { "Высоко: 36 000 км", "High up: 36,000 km" } },
		{ "comms", G, { "Один спутник видит полпланеты", "One satellite sees half the planet" } },
		{ "rocket", W, { "Нужна мощная ракета", "Needs a strong rocket" } } },
		line = { "Как спутники NASA TDRS: висит над одной точкой.", "Like NASA's TDRS: hangs over one spot." } },
	v_m1_b = { art = "swarm", tags = {
		{ "orbit", I, { "Низко: 400 км", "Low: 400 km" } },
		{ "check", G, { "Один сломался: двое работают", "One breaks, two keep working" } },
		{ "budget", W, { "Три спутника: больше деталей", "Three craft: more parts" } } },
		line = { "Низкая орбита: хватит ракеты попроще.", "Low orbit: a smaller rocket will do." } },

	v_m2_a = { art = "crater_dark", tags = {
		{ "target", G, { "Больше льда: LCROSS нашёл тут воду", "More ice: LCROSS found water here" } },
		{ "shadow", W, { "Вечная тень, −240 °C", "Eternal shadow, −240 °C" } },
		{ "panel", W, { "Нет солнца для панелей", "No sunlight for solar panels" } } },
		line = { "Камера в темноте слепа: нужен нейтронный сканер.", "Cameras are blind in the dark: bring a neutron scanner." } },
	v_m2_b = { art = "crater_lit", tags = {
		{ "panel", G, { "Край кратера почти всегда на солнце", "The rim is almost always sunlit" } },
		{ "target", W, { "Льда меньше, он глубже", "Less ice, deeper down" } },
		{ "star", I, { "Район посадок программы Artemis", "An Artemis landing region" } } },
		line = { "Солнце на краю, лёд на дне.", "Sun on the rim, ice at the bottom." } },

	v_m3_a = { art = "delta", tags = {
		{ "instrument", G, { "Древняя река: больше науки", "Ancient river: more science" } },
		{ "warning", W, { "Камни и обрывы: посадка сложнее", "Rocks and cliffs: harder landing" } } },
		line = { "Perseverance сел в дельту кратера Езеро.", "Perseverance landed in Jezero crater's delta." } },
	v_m3_b = { art = "plain", tags = {
		{ "check", G, { "Ровно и безопасно", "Flat and safe" } },
		{ "instrument", W, { "Мало интересных камней", "Few interesting rocks" } } },
		line = { "Спокойная посадка, но до науки далеко.", "An easy landing, but science is far away." } },

	v_m4_a = { art = "mirror_fold", tags = {
		{ "rocket", G, { "Складывается и влезает в ракету", "Folds up to fit the rocket" } },
		{ "time", W, { "Раскрывать по шагам", "Must unfold step by step" } } },
		line = { "Как у телескопа Уэбба: 18 сегментов.", "Like the Webb telescope: 18 segments." } },
	v_m4_b = { art = "mirror_solid", tags = {
		{ "check", G, { "Цельное, ничего не раскрывать", "One piece, nothing to unfold" } },
		{ "warning", W, { "Огромное: может не влезть", "Huge: may not fit the rocket" } } },
		line = { "Зеркало «Хаббла» — 2,4 м: больше в ракету не влезает.", "Hubble's mirror is 2.4 m: bigger won't fit." } },

	v_m5_a = { art = "route_direct", tags = {
		{ "time", G, { "Быстрее", "Faster" } },
		{ "rocket", W, { "Нужна очень мощная ракета", "Needs a very strong rocket" } } },
		line = { "Прямо к Юпитеру.", "Straight to Jupiter." } },
	v_m5_b = { art = "route_ga", tags = {
		{ "budget", G, { "Дешевле: планета разгоняет бесплатно", "Cheaper: a planet speeds you up for free" } },
		{ "time", W, { "Дольше в пути", "Takes longer" } } },
		line = { "Europa Clipper разгоняется у Марса и Земли.", "Europa Clipper swings past Mars and Earth." } },

	v_m6_a = { art = "obc_hard", tags = {
		{ "lock", G, { "Проверенный блок", "A tested unit" } },
		{ "budget", W, { "Дороже", "Costs more" } } },
		line = { "NASA проверяет каждую деталь перед полётом.", "NASA tests every part before flight." } },
	v_m6_b = { art = "vex_unit", tags = {
		{ "budget", G, { "Дёшево", "Cheap" } },
		{ "warning", W, { "Его никто не проверял", "Nobody has tested it" } } },
		line = { "Сэкономим… если повезёт.", "We save money… if we're lucky." } },

	v_fin_a = { art = "hand", tags = {
		{ "commander", G, { "Векс может стать союзником", "Vex could become an ally" } } },
		line = { "Даже соперник может научиться.", "Even a rival can learn." } },
	v_fin_b = { art = "court", tags = {
		{ "lock", I, { "Академия решит по правилам", "The Academy decides by the rules" } } },
		line = { "Справедливо, но Векс останется один.", "Fair, but Vex stays alone." } },
}
