-- NASA mission files: the real science behind every mission, with the official source for each fact.
-- Shown in-game (Hud "NASA file", key N) and listed in docs/NASA_SOURCES.md.
local F = {}
F.M0 = {
	analog = { "CubeSat · кубсаты NASA CSLI", "CubeSat · NASA CubeSat Launch Initiative" },
	facts = {
		{ "1U кубсат — куб 10 см и около 1,33 кг. Запас по массе и энергии нужен с первого дня.", "A 1U CubeSat is a 10 cm cube of about 1.33 kg. Mass and power margin matter from day one.", "NASA CubeSat 101 (CSLI)" },
		{ "Низкая орбита: виток около 90 минут, до трети из них — в тени Земли. Там работают только батареи.", "Low orbit: one lap takes about 90 minutes and up to a third is in Earth's shadow. Only batteries work there.", "NASA · ISS facts" },
		{ "Солнечные бури реальны: NASA следит за вспышками в базе DONKI. Доска в Цитадели показывает живые данные.", "Solar storms are real: NASA tracks flares in the DONKI database. The Citadel board shows live data.", "api.nasa.gov · DONKI" },
	},
	sources = { "nasa.gov/.../nasa_csli_cubesat_101_508.pdf", "nasa.gov/international-space-station", "kauai.ccmc.gsfc.nasa.gov/DONKI" },
}
F.M1 = {
	analog = { "Связь: TDRS, сеть SCaN", "Comms: TDRS, the SCaN network" },
	facts = {
		{ "Геостационарная орбита — 35 786 км: спутник «висит» над одной точкой, но ему нужна большая антенна.", "GEO is 35,786 km up: the satellite hovers over one spot, but needs a big antenna.", "NASA SCaN" },
		{ "Рой из нескольких дешёвых спутников даёт ту же связь с низкой орбиты. Правильных ответов несколько.", "A swarm of cheap satellites in low orbit can give the same coverage. There is more than one right answer.", "NASA Mission Design Lab" },
		{ "Каждая подсистема — питание, связь, данные — влияет на другие. Это и есть системная инженерия.", "Every subsystem (power, comms, data) affects the others. That is systems engineering.", "NASA · Design and Develop Science Missions" },
	},
	sources = { "nasa.gov/communicating-with-missions", "etd.gsfc.nasa.gov/.../mission-design-lab", "nasa.gov/.../250323-design-and-develop-science-mission.pdf" },
}
F.M2 = {
	analog = { "LCROSS · LRO · Lunar Prospector", "LCROSS · LRO · Lunar Prospector" },
	facts = {
		{ "В 2009 году LCROSS врезался в кратер Кабеус и нашёл водяной лёд.", "In 2009 LCROSS struck Cabeus crater and found water ice.", "NASA · LCROSS" },
		{ "В вечной тени полюсов около −240 °C (прибор Diviner на LRO). Камера там слепа — нужен нейтронный сканер.", "Polar craters in eternal shadow reach about −240 °C (LRO Diviner). A camera is blind there, a neutron spectrometer is not.", "NASA · LRO" },
		{ "Вода на Луне — это топливо и воздух для будущих баз программы Artemis.", "Lunar water means fuel and air for future Artemis bases.", "NASA · Artemis" },
	},
	sources = { "science.nasa.gov/mission/lcross", "science.nasa.gov/mission/lro", "nasa.gov/humans-in-space/artemis" },
}
F.M3 = {
	analog = { "Perseverance · Ingenuity", "Perseverance · Ingenuity" },
	facts = {
		{ "Сигнал до Марса идёт от 3 до 22 минут. Посадка длится около 7 минут, поэтому аппарат садится сам.", "Signals take 3 to 22 minutes to reach Mars. Landing takes about 7 minutes, so it must be automatic.", "NASA · Mars 2020" },
		{ "Perseverance сел в кратер Езеро в 2021 году на «небесном кране»: щит, парашют, двигатели, кран — строго по порядку.", "Perseverance landed in Jezero crater in 2021 with a sky crane: shield, parachute, engines, crane, in strict order.", "NASA · Perseverance EDL" },
		{ "Ровер оставил пробирки с образцами для будущей доставки на Землю.", "The rover left sealed sample tubes for a future return to Earth.", "NASA · Mars Sample Return" },
	},
	sources = { "science.nasa.gov/mission/mars-2020-perseverance", "mars.nasa.gov/mars2020/timeline/landing", "science.nasa.gov/mission/mars-sample-return" },
}
F.M4 = {
	analog = { "Телескоп Джеймса Уэбба (JWST)", "James Webb Space Telescope (JWST)" },
	facts = {
		{ "Зеркало JWST — 6,5 м из 18 золотых сегментов. Оно не влезало в ракету, поэтому складывалось.", "JWST's 6.5 m mirror has 18 gold segments. It didn't fit in the rocket, so it folded.", "NASA · Webb" },
		{ "Пятислойный солнечный щит размером с теннисный корт держит телескоп очень холодным.", "A five-layer sunshield the size of a tennis court keeps the telescope very cold.", "NASA · Webb sunshield" },
		{ "Точка L2 — 1,5 млн км от Земли: Солнце, Земля и Луна всегда с одной стороны.", "L2 is 1.5 million km from Earth: Sun, Earth and Moon always stay on one side.", "NASA · Webb orbit" },
	},
	sources = { "science.nasa.gov/mission/webb", "science.nasa.gov/mission/webb/sunshield", "science.nasa.gov/mission/webb/orbit" },
}
F.M5 = {
	analog = { "Europa Clipper · Juno", "Europa Clipper · Juno" },
	facts = {
		{ "У Юпитера света примерно в 25 раз меньше, поэтому у Europa Clipper огромные солнечные панели.", "At Jupiter sunlight is about 25 times weaker, so Europa Clipper has huge solar arrays.", "NASA · Europa Clipper" },
		{ "Радиация Юпитера жжёт электронику: её прячут в бронированный «сейф».", "Jupiter's radiation fries electronics, so they hide inside an armored vault.", "NASA · Europa Clipper vault" },
		{ "Радар REASON заглядывает под лёд Европы, где может быть солёный океан.", "The REASON radar looks under Europa's ice, where a salty ocean may hide.", "NASA · REASON instrument" },
	},
	sources = { "science.nasa.gov/mission/europa-clipper", "europa.nasa.gov/spacecraft/meet-europa-clipper", "europa.nasa.gov/spacecraft/instruments/reason" },
}
F.M6 = {
	analog = { "DART · планетарная защита", "DART · planetary defense" },
	facts = {
		{ "В 2022 году аппарат DART врезался в астероид Диморф и сократил его виток на 32 минуты.", "In 2022 DART hit the asteroid Dimorphos and shortened its orbit by 32 minutes.", "NASA · DART" },
		{ "Чем раньше удар, тем меньше нужен толчок: время — главный ресурс защиты.", "The earlier the hit, the smaller the push needed: time is defense's key resource.", "NASA Planetary Defense (PDCO)" },
		{ "NASA ведёт каталог сближающихся астероидов NeoWs. Доска угроз в Цитадели берёт данные оттуда.", "NASA keeps the NeoWs catalog of close-approaching asteroids. The Citadel threat board uses it.", "api.nasa.gov · NeoWs" },
	},
	sources = { "science.nasa.gov/mission/dart", "science.nasa.gov/planetary-defense", "api.nasa.gov (Asteroids - NeoWs)" },
}
-- one quick question per mission (first option is the right one; the client shuffles)
F.M0.quiz = { q = { "Какого размера кубсат 1U?", "How big is a 1U CubeSat?" }, a = { { "Куб 10 см", "A 10 cm cube" }, { "Куб 1 метр", "A 1 metre cube" }, { "Как автомобиль", "As big as a car" } } }
F.M1.quiz = { q = { "Почему спутник на геостационаре висит над одной точкой?", "Why does a GEO satellite stay over one spot?" }, a = { { "Он делает виток за сутки — вместе с Землёй", "It circles once a day, as fast as Earth turns" }, { "Он привязан к башне", "It is tied to a tower" }, { "Он совсем не двигается", "It doesn't move at all" } } }
F.M2.quiz = { q = { "Почему лёд ищут в тёмных кратерах?", "Why look for ice in dark craters?" }, a = { { "Туда не светит Солнце, и лёд не тает", "Sunlight never gets there, so ice doesn't melt" }, { "В кратерах теплее", "Craters are warmer" }, { "Лёд любит камни", "Ice likes rocks" } } }
F.M3.quiz = { q = { "Почему посадочный модуль на Марсе садится сам?", "Why does a Mars lander land by itself?" }, a = { { "Сигнал с Земли идёт несколько минут", "Signals from Earth take minutes to arrive" }, { "На Марсе нет воздуха", "Mars has no air" }, { "Так быстрее", "It's faster" } } }
F.M4.quiz = { q = { "Почему зеркало JWST складывали?", "Why did JWST's mirror fold?" }, a = { { "Оно не влезало в ракету", "It was too big for the rocket" }, { "Чтобы красиво выглядело", "To look cool" }, { "Чтобы не замёрзло", "To keep it warm" } } }
F.M5.quiz = { q = { "Зачем Europa Clipper огромные солнечные панели?", "Why does Europa Clipper have huge solar arrays?" }, a = { { "У Юпитера свет в ~25 раз слабее", "Sunlight at Jupiter is about 25 times weaker" }, { "У Юпитера очень жарко", "Jupiter is very hot" }, { "Панели защищают от камней", "Panels protect from rocks" } } }
F.M6.quiz = { q = { "Как DART сдвинул астероид?", "How did DART move the asteroid?" }, a = { { "Врезался и толкнул его", "It crashed into it to push it" }, { "Потянул тросом", "It pulled it with a rope" }, { "Взорвал его", "It blew it up" } } }
-- extra NASA learning sources (shown in the Rocket Lab and the Parts Book)
F.sources = {
	"NASA Glenn Research Center · Beginner's Guide to Rockets (grc.nasa.gov/www/k-12/rocket)",
	"NASA · Rockets Educator Guide (nasa.gov/stem)",
	"NASA Space Place · space.nasa.gov (for kids)",
	"NASA CubeSat 101 (CSLI)", "NASA Launch Services Program", "NASA · Space Launch System",
}
return F
