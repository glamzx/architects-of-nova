-- Parts encyclopedia: simple explanations for ages 6–12, a real NASA example, a fun fact and the source.
-- Each text: { ru, en }. Shown on the inspect card (rack) and in the Parts Book (key B).
local function t(ru, en) return { ru, en } end
local P = {}
P.obc = { what = t("Мозг корабля: управляет всеми системами и говорит с Землёй.", "The ship's brain: it runs every system and talks to Earth."),
	real = t("У кубсатов компьютер — плата размером с ладонь.", "A CubeSat's computer is a board the size of your hand."),
	fact = t("У компьютера «Аполлона-11» было около 4 КБ памяти — меньше, чем одна фотография в телефоне.", "Apollo 11's computer had about 4 KB of memory, less than one phone photo."), src = "NASA · Apollo Guidance Computer" }
P.obc_hard = { what = t("Компьютер с защитой от радиации: космические частицы не собьют его с толку.", "A radiation-proof computer: space particles can't confuse it."),
	real = t("Марсоходы Curiosity и Perseverance думают процессором RAD750.", "The Curiosity and Perseverance rovers think with a RAD750 processor."),
	fact = t("Одна частица может перевернуть 0 в 1 в памяти. Такие чипы это выдерживают.", "One particle can flip a 0 into a 1 in memory. These chips survive it."), src = "NASA · Mars 2020 rover brains" }
P.vex_unit = { what = t("Дешёвый блок без испытаний. Никто не знает, выдержит ли он космос.", "A cheap, untested unit. Nobody knows if it survives space."),
	real = t("NASA трясёт, греет и морозит каждую деталь в вакуумных камерах до полёта.", "NASA shakes, heats and freezes every part in vacuum chambers before flight."),
	fact = t("Испытания — это половина работы инженера.", "Testing is half of an engineer's job."), src = "NASA Goddard · environmental testing" }
P.battery_s = { what = t("Хранит энергию на время, когда корабль в тени Земли.", "Stores energy for when the ship is in Earth's shadow."),
	real = t("Такие же литий-ионные батареи, как в телефоне.", "Lithium-ion cells, like the ones in your phone."),
	fact = t("На МКС старые батареи заменили литий-ионными во время выходов в космос (2017–2021).", "Astronauts swapped the ISS batteries for lithium-ion ones on spacewalks (2017–2021)."), src = "NASA · ISS power system" }
P.battery_l = { what = t("Батарея побольше: хватит на длинную тень или на прибор пожаднее.", "A bigger battery for a longer shadow or a hungrier instrument."),
	real = t("Ватт-час — это мера энергии: 40 Вт·ч хватит лампочке на 4 Вт на 10 часов.", "Watt-hours = how much energy: 40 Wh runs a 4 W bulb for 10 hours."),
	fact = t("Батареи тяжёлые, поэтому инженеры считают каждую.", "Batteries are heavy, so engineers count every one."), src = "NASA CubeSat 101" }
P.battery_xl = { what = t("Огромный запас энергии для долгой ночи.", "A huge energy store for a long night."),
	real = t("Ночь на Марсе длится около 12 часов — солнечным машинам нужны большие батареи.", "A night on Mars lasts about 12 hours, so solar machines need big batteries."),
	fact = t("На холоде батареи быстро садятся, поэтому их греют.", "Cold drains batteries, so spacecraft keep them warm."), src = "NASA · Mars facts" }
P.panel_body = { what = t("Солнечные элементы прямо на корпусе. Просто и без движущихся частей.", "Solar cells right on the body. Simple, with no moving parts."),
	real = t("Многие кубсаты покрыты солнечными элементами со всех сторон.", "Many CubeSats are covered in solar cells on every side."),
	fact = t("Космические солнечные элементы превращают около 30% света в электричество.", "Space solar cells turn about 30% of sunlight into electricity."), src = "NASA CubeSat 101" }
P.panel_wing = { what = t("Крылья раскрываются после старта и дают больше энергии.", "Wings that unfold after launch for more power."),
	real = t("У зонда Juno три солнечные панели длиной почти по 9 метров.", "The Juno probe has three solar arrays almost 9 metres long each."),
	fact = t("Каждый шарнир — риск: если не раскроется, энергии не будет.", "Every hinge is a risk: if it doesn't open, there is no power."), src = "NASA · Juno spacecraft" }
P.panel_array = { what = t("Большая солнечная батарея для голодных приборов.", "A large solar array for power-hungry instruments."),
	real = t("Размах панелей МКС — больше футбольного поля.", "The ISS solar arrays span wider than a football field."),
	fact = t("Чем дальше от Солнца, тем меньше энергии: вдвое дальше — вчетверо меньше.", "The farther from the Sun, the less power: twice as far, a quarter of the light."), src = "NASA · ISS facts" }
P.panel_giant = { what = t("Гигантские крылья для работы далеко от Солнца.", "Giant wings for working far from the Sun."),
	real = t("Размах панелей Europa Clipper — около 30 метров, как баскетбольная площадка.", "Europa Clipper's arrays span about 30 metres, as long as a basketball court."),
	fact = t("У Юпитера света примерно в 25 раз меньше, чем у Земли.", "At Jupiter there is about 25 times less sunlight than at Earth."), src = "NASA · Europa Clipper" }
P.rtg = { what = t("Делает электричество из тепла плутония. Работает в темноте и в пыли.", "Makes electricity from plutonium's heat. Works in the dark and in dust."),
	real = t("Такой источник питает марсоход Perseverance.", "One powers the Perseverance rover."),
	fact = t("РИТЭГи «Вояджеров» работают больше 45 лет.", "The Voyagers' RTGs have worked for more than 45 years."), src = "NASA · Radioisotope Power Systems" }
P.antenna_uhf = { what = t("Маленькая антенна-штырь для разговора с ближними станциями.", "A small whip antenna to talk to nearby stations."),
	real = t("Марсоходы шлют данные по UHF через спутники на орбите Марса.", "Mars rovers send data over UHF through orbiters around Mars."),
	fact = t("Радиоволны летят со скоростью света: до Луны чуть больше секунды.", "Radio waves travel at light speed: a bit over one second to the Moon."), src = "NASA · Mars Relay Network" }
P.antenna_s = { what = t("Средняя антенна (S-диапазон): связь быстрее и дальше.", "An S-band antenna: faster, longer-range talk."),
	real = t("Многие миссии NASA получают команды именно в S-диапазоне.", "Many NASA missions receive their commands on S-band."),
	fact = t("Больше данных — больше энергии на передатчик.", "More data needs more power for the transmitter."), src = "NASA SCaN" }
P.hga = { what = t("Тарелка, которую надо навести на Землю. Шлёт много данных очень далеко.", "A dish that must point at Earth. It sends lots of data very far."),
	real = t("Тарелка «Вояджера» — 3,7 метра, а антенны сети DSN на Земле — до 70 метров.", "Voyager's dish is 3.7 m wide; Deep Space Network dishes on Earth reach 70 m."),
	fact = t("Чем больше тарелка, тем тише сигнал она может услышать.", "The bigger the dish, the fainter the signal it can hear."), src = "NASA · Deep Space Network" }
P.camera = { what = t("Фотографирует. Но ей нужен свет!", "Takes pictures. But it needs light!"),
	real = t("У марсохода Perseverance 23 камеры.", "The Perseverance rover has 23 cameras."),
	fact = t("Фото — это данные: одна картинка может весить мегабайты.", "Photos are data: one picture can be megabytes."), src = "NASA · Perseverance cameras" }
P.rad_sensor = { what = t("Измеряет радиацию от солнечных бурь.", "Measures radiation from solar storms."),
	real = t("Прибор RAD на Curiosity мерил радиацию по пути к Марсу.", "The RAD instrument on Curiosity measured radiation on the way to Mars."),
	fact = t("Эти данные помогают защитить будущих астронавтов.", "This data helps protect future astronauts."), src = "NASA · Curiosity RAD" }
P.neutron_spec = { what = t("Находит спрятанную воду, считая нейтроны. Видит даже в темноте.", "Finds hidden water by counting neutrons. It works even in the dark."),
	real = t("Lunar Prospector (1998) так нашёл признаки льда на полюсах Луны.", "Lunar Prospector (1998) used one to find signs of ice at the Moon's poles."),
	fact = t("Вода тормозит нейтроны. Где их мало — там прячется вода.", "Water slows neutrons down. Where there are few, water is hiding."), src = "NASA · Lunar Prospector" }
P.radar = { what = t("Посылает радиоволны и ловит эхо. Видит сквозь лёд и облака.", "Sends radio waves and catches the echo. Sees through ice and clouds."),
	real = t("Радар REASON на Europa Clipper заглянет в ледяной панцирь Европы.", "The REASON radar on Europa Clipper will look inside Europa's ice shell."),
	fact = t("Летучие мыши тоже «видят» эхом, только звуком.", "Bats also 'see' with echoes, using sound."), src = "NASA · Europa Clipper REASON" }
P.mirror_fold = { what = t("Огромное зеркало, сложенное, чтобы влезть в ракету.", "A huge mirror folded to fit inside the rocket."),
	real = t("Зеркало JWST — 6,5 м из 18 сегментов, оно раскрылось уже в космосе.", "JWST's 6.5 m mirror has 18 segments and unfolded in space."),
	fact = t("При раскрытии «Уэбба» 344 шага должны были пройти без единой ошибки.", "Webb had 344 steps that all had to work perfectly."), src = "NASA · Webb deployment" }
P.mirror_solid = { what = t("Цельное зеркало: без шарниров, но нужен широкий нос ракеты.", "A one-piece mirror: no hinges, but it needs a wide rocket nose."),
	real = t("Зеркало «Хаббла» — цельное, 2,4 метра.", "Hubble's mirror is one piece, 2.4 metres wide."),
	fact = t("Зеркало «Хаббла» отполировано почти идеально.", "Hubble's mirror is polished almost perfectly smooth."), src = "NASA · Hubble" }
P.vault = { what = t("Титановый сейф, который прячет электронику от радиации.", "A titanium safe that hides electronics from radiation."),
	real = t("Сейф зонда Juno весит около 180 кг.", "The Juno probe's vault weighs about 180 kg."),
	fact = t("Радиация у Юпитера — одна из самых сильных в Солнечной системе.", "Jupiter's radiation is among the strongest in the Solar System."), src = "NASA · Juno radiation vault" }
P.edl_kit = { what = t("Теплозащитный щит и парашют, чтобы сесть на планету.", "A heat shield and a parachute for landing on a planet."),
	real = t("Парашют Perseverance был шириной 21,5 метра.", "Perseverance's parachute was 21.5 metres wide."),
	fact = t("При входе в атмосферу щит раскаляется до 1300 °C.", "On entry the heat shield gets as hot as 1300 °C."), src = "NASA · Mars 2020 EDL" }
P.edl_crane = { what = t("Небесный кран: опускает ровер на тросах и улетает.", "A sky crane lowers the rover on ropes, then flies away."),
	real = t("Так сели Curiosity (2012) и Perseverance (2021).", "Curiosity (2012) and Perseverance (2021) landed this way."),
	fact = t("Всё происходит само: сигнал до Земли идёт минуты.", "It all happens by itself: signals to Earth take minutes."), src = "NASA · Sky crane" }
P.impactor_s = { what = t("Тяжёлый снаряд, который толкает астероид ударом.", "A heavy impactor that pushes an asteroid by hitting it."),
	real = t("Аппарат DART весил около 570 кг.", "The DART spacecraft weighed about 570 kg."),
	fact = t("Толкать надо заранее: маленький толчок рано лучше большого поздно.", "Push early: a small nudge early beats a big one late."), src = "NASA · DART" }
P.impactor_l = { what = t("Снаряд побольше — толчок сильнее.", "A bigger impactor gives a stronger push."),
	real = t("DART врезался в Диморф на скорости около 6 км/с.", "DART hit Dimorphos at about 6 km per second."),
	fact = t("После удара виток Диморфа стал короче на 32 минуты.", "After the hit, Dimorphos' orbit got 32 minutes shorter."), src = "NASA · DART results" }
-- launch vehicles (our rockets are inspired by real ones)
P.rocket_kestrel = { what = t("Маленькая ракета для кубсатов на низкую орбиту.", "A small rocket for CubeSats to low orbit."),
	real = t("Похожа на ракеты, которыми NASA запускает маленькие спутники, например Pegasus.", "Like the small launchers NASA uses for little satellites, such as Pegasus."),
	fact = t("Чтобы не упасть с низкой орбиты, надо лететь около 7,8 км/с.", "To stay in low orbit you must fly about 7.8 km per second."), src = "NASA · Launch Services Program" }
P.rocket_heron = { what = t("Средняя ракета: груз потяжелее и орбита повыше.", "A medium rocket: a heavier load and a higher orbit."),
	real = t("Чем выше орбита, тем меньше груза поднимет та же ракета.", "The higher the orbit, the less cargo the same rocket can carry."),
	fact = t("Около 90% веса ракеты на старте — это топливо.", "About 90% of a rocket's launch weight is fuel."), src = "NASA Glenn · Beginner's Guide to Rockets" }
P.rocket_condor = { what = t("Тяжёлая ракета для полётов к другим планетам.", "A heavy rocket for flights to other planets."),
	real = t("Perseverance улетел к Марсу на ракете Atlas V.", "Perseverance flew to Mars on an Atlas V rocket."),
	fact = t("Ступени сбрасываются, когда пустеют, чтобы ракета стала легче.", "Stages drop off when empty so the rocket gets lighter."), src = "NASA · Mars 2020 launch" }
P.rocket_titan = { what = t("Сверхтяжёлая ракета для самых дальних миссий.", "A super-heavy rocket for the farthest missions."),
	real = t("Как SLS — ракета NASA, которая в 2022 году отправила «Артемиду-1» к Луне.", "Like SLS, the NASA rocket that sent Artemis I to the Moon in 2022."),
	fact = t("Тяга SLS на старте — около 39 000 кН: больше, чем у 30 огромных самолётов вместе.", "SLS makes about 39,000 kN of thrust at liftoff, more than 30 jumbo jets together."), src = "NASA · Space Launch System" }
return P
