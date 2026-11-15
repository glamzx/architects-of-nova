-- RoleLines: a personal job for every role in every mission (shown as a "Your job" card at Build start and on
-- arrival at the first landing site). Each line points at a real mechanic of that role.
return {
	M0 = {
		build = {
			commander = { "Решаешь ты: GO или NO-GO. Перед стартом проверь опрос у пульта запуска.", "You call GO or NO-GO. Check the poll at the launch console before liftoff." },
			engineer = { "«Искра» крошечная: не больше 3 кг. Следи, чтобы масса не ушла в красную зону, а батарея была заряжена!", "Spark is tiny: 3 kg max. Keep the mass bar out of the red and the battery charged!" },
			scientist = { "Поставь прибор, который выбрала команда. Без него буря останется загадкой.", "Fit the instrument the team voted for. Without it the storm stays a mystery." },
			comms = { "Ты слышишь беду первым: тревога приходит тебе на 5 секунд раньше. Предупреждай!", "You hear trouble first: alarms reach you 5 seconds early. Warn the crew!" },
		},
	},
	M1 = {
		build = {
			commander = { "Один большой спутник или рой? При ничьей решает твой голос.", "One big satellite or a swarm? Your vote breaks a tie." },
			engineer = { "Чем выше орбита, тем мощнее нужна ракета. Следи за полоской нагрузки ракеты.", "A higher orbit needs a stronger rocket. Watch the rocket load bar." },
			scientist = { "Все данные должны успеть уйти на Землю. Лишний прибор — и полоска данных краснеет.", "Data must fit the link. One instrument too many and the data bar turns red." },
			comms = { "Это твоя миссия: антенны и связь. Сеть услышат все колонии — или никто.", "This one is yours: antennas and the link. Every colony hears the network — or none do." },
		},
		field = {
			commander = { "Разделитесь: двое на тарелки, двое на ретранслятор.", "Split up: two on the dishes, two on the relay." },
			engineer = { "На второй точке сломана солнечная панель станции. Почини её, пока станция не замёрзла.", "At the second site the station's solar array is broken. Fix it before the station freezes." },
			scientist = { "Помоги включить ретранслятор: жмите с командой в одну секунду.", "Help switch on the relay: press with the crew in the same second." },
			comms = { "Тарелки твои: ты наводишь их вдвое быстрее. Потом скачай журнал «Нова-1» — это улика!", "The dishes are yours: you align them twice as fast. Then download Nova-1's log — it's evidence!" },
		},
	},
	M2 = {
		build = {
			commander = { "Камера или нейтронный сканер? В вечной тени работает только один. Решай.", "A camera or a neutron scanner? In eternal shadow only one works. Make the call." },
			engineer = { "В кратере −240 °C и темно. Возьми батарею побольше.", "It's −240 °C and dark in the crater. Bring a bigger battery." },
			scientist = { "Только ты умеешь читать нейтронный сканер. Найди лёд!", "Only you can read the neutron scanner. Find the ice!" },
			comms = { "Со дна кратера Земли не видно. Поставь хорошую антенну, иначе мы тебя не услышим.", "Earth is out of sight from the crater floor. Fit a good antenna or we won't hear you." },
		},
		field = {
			commander = { "Учёный — сканировать, остальные — носить пробы. Потом все в ровер!", "Scientist scans, everyone else carries samples. Then all into the rover!" },
			engineer = { "Обогреватель замёрз. Почини его, пока батареи не сели.", "The heater froze. Fix it before the batteries die." },
			scientist = { "Сканируй грунт: лёд видит только твой прибор.", "Scan the ground: only your instrument can see the ice." },
			comms = { "Садись за руль ровера и доставь его к маяку на краю кратера.", "Take the rover's wheel and drive it to the beacon on the crater rim." },
		},
	},
	M3 = {
		build = {
			commander = { "Дельта или равнина? Наука или безопасность — команда ждёт тебя.", "Delta or plain? Science or safety — the crew is waiting for you." },
			engineer = { "Щит, парашют, кран — строго по порядку. Ровер сядет сам, без пилота.", "Shield, parachute, crane — strictly in order. The landing is fully automatic." },
			scientist = { "Марс прячет тайны в древних камнях. Нужен прибор для образцов.", "Mars hides its secrets in ancient rocks. You'll need a sampling instrument." },
			comms = { "Сигнал до Марса идёт до 22 минут. Подсказать посадке оттуда не сможем.", "A signal takes up to 22 minutes to Mars. Nobody can steer the landing from here." },
		},
		field = {
			commander = { "Завоет сирена — веди всех в укрытие. Пыльная буря не ждёт.", "When the siren howls, lead everyone to the shelter. Dust storms don't wait." },
			engineer = { "Пыль засыпала панели. Чисть их точно в такт.", "Dust buried the panels. Clean them right on the beat." },
			scientist = { "РИТЭГ тяжёлый — несите его к роверу вдвоём.", "The RTG is heavy — carry it to the rover together." },
			comms = { "На гребне — сигнал. Гони туда ровер!", "There's a signal on the ridge. Drive the rover there!" },
		},
	},
	M4 = {
		build = {
			commander = { "Векс советует цельное зеркало. Кому веришь: команде или Вексу?", "Vex says take a solid mirror. Who do you trust: your crew or Vex?" },
			engineer = { "Нос ракеты не резиновый: складное зеркало влезет, огромное — может и нет.", "The rocket's nose has limits: a folding mirror fits, a giant one might not." },
			scientist = { "18 частей зеркала должны встать идеально. Настройкой руководишь ты.", "18 segments must line up perfectly. You lead the alignment." },
			comms = { "До L2 полтора миллиона километров. Большая антенна должна достать до дома.", "L2 is 1.5 million km away. The big dish must reach home." },
		},
		field = {
			commander = { "Замки — строго по порядку. Считай вслух!", "Release the latches strictly in order. Count out loud!" },
			engineer = { "В солнечном щите дыра. Залатай её — ты чинишь вдвое быстрее.", "There's a hole in the sunshield. Patch it — you repair twice as fast." },
			scientist = { "Дальше — палуба зеркала. Готовься выравнивать сегменты.", "The mirror deck is next. Get ready to align the segments." },
			comms = { "Держи всех на связи: замки открываются только по команде.", "Keep everyone talking: the latches open only on your call." },
		},
	},
	M5 = {
		build = {
			commander = { "Прямо или гравманёвр? Время против бюджета — выбирай с умом.", "Direct or gravity assist? Time against budget — choose wisely." },
			engineer = { "Солнца в 25 раз меньше, а радиация жжёт микросхемы. Нужны большие панели и сейф!", "25 times less sunlight and radiation fries chips. Big panels and a vault!" },
			scientist = { "Подо льдом может быть океан. Радар заглянет сквозь лёд.", "There may be an ocean under the ice. A radar can look through it." },
			comms = { "Юпитер далеко, связь медленная. Каждый байт на счету.", "Jupiter is far and the link is slow. Every byte counts." },
		},
		field = {
			commander = { "Гейзеры бьют по расписанию. Рассчитай момент!", "The geysers erupt on schedule. Time the run!" },
			engineer = { "На второй точке — капсула «Нова-1». Почини её и скачай журнал.", "At the second site: Nova-1's capsule. Fix it and download its log." },
			scientist = { "Возьми пробы гейзеров — вдруг в них есть жизнь.", "Sample the geysers — maybe life is hiding in them." },
			comms = { "На ледяном гребне наведи радар и найди капсулу «Нова-1».", "On the ice ridge, aim the radar and find Nova-1's capsule." },
		},
	},
	M6 = {
		build = {
			commander = { "Векс предлагает дешёвый блок наведения. Судьба Земли — твоё решение.", "Vex offers a cheap guidance unit. Earth's fate is your decision." },
			engineer = { "Тяжелее ударник — сильнее толчок. Но ракета должна его поднять.", "A heavier impactor pushes harder. But the rocket must lift it." },
			scientist = { "Чем раньше удар, тем меньше нужен толчок. Так сработал DART.", "Hit earlier and you need a smaller push. That's how DART worked." },
			comms = { "Блок Векса шлёт странные сигналы. Слушай внимательно.", "Vex's unit sends strange signals. Listen closely." },
		},
		field = {
			commander = { "Четыре капсулы — одна секунда. Обратный отсчёт за тобой.", "Four capsules, one second. You give the countdown." },
			engineer = { "Сначала маяки. Ставь мягко: гравитации почти нет.", "Beacons first. Place them gently: there's almost no gravity." },
			scientist = { "Эреб — это куча камней. Смотри под ноги.", "Erebus is a rubble pile. Watch your step." },
			comms = { "Настрой наведение — это твоя работа. Потом будим спящих разом.", "Align the guidance — that's your job. Then we wake the sleepers together." },
		},
	},
}
