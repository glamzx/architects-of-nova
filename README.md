# Architects of Nova

**Кооперативная игра Roblox о проектировании космических миссий — NASA Space Apps Challenge 2026 (трек «Space Mission Design Game»).**
**A co-op Roblox game about designing space missions — NASA Space Apps Challenge 2026 ("Space Mission Design Game" track).**

▶ Играть / Play: https://www.roblox.com/games/81057006386585

---

## Русский

### Об игре
Architects of Nova — кооперативная игра для детей 6–12 лет (и взрослых тоже). Команда игроков проектирует космическую миссию:
собирает спутник или зонд из настоящих модулей (питание, связь, приборы, двигатели), укладывается в массу, бюджет и
обтекатель ракеты, проходит предстартовую проверку и запускает ракету. Затем экипаж летит на поле: Луна, Марс, Европа,
астероид, орбитальная станция и точка Лагранжа L2.

- **Кампания M0–M6** — сюжет «Затмение» (The Blackout), по 2 полевые площадки в каждом мире, голосование команды.
- **Хаб «Цитадель»** — ангар со стеллажами модулей, стартовые площадки, рынок, атриум с голограммой, тренажёр невесомости.
- **Классы с перками** — командир, инженер, учёный; совместная переноска тяжёлых модулей.
- **Запуски ракет** — кинематографичные старты с огнём двигателей, дымом и полётом экипажа к полевым площадкам.
- **Срочные задачи** — поломки в хабе с таймером (охлаждение, питание, антенна, калибровка, бюджет).
- **Интерактивная задача по физике** — у стартовой площадки нужно собрать кнопками правильную формулу
  (вес ракеты W = m · g) и сравнить её с тягой двигателей, с подсказкой для тех, кто думает.
- **Магазин снаряжения** — цвета скафандров и шлемы за кредиты.
- **Факты NASA** — каждая миссия опирается на реальные проекты NASA (источники в `docs/NASA_SOURCES.md`).

### Как открыть
1. **Полный файл места:** откройте `ArchitectsOfNova.rbxl` (в корне репозитория) в Roblox Studio — там все модели,
   террейн, освещение и скрипты.
2. **Только скрипты (Rojo):** `rojo serve default.project.json` и подключитесь плагином Rojo в Studio.
   Скрипты лежат в `src/` по сервисам Roblox.

### Структура
```
src/              скрипты по сервисам Roblox (Rojo: *.server.lua, *.client.lua, *.lua)
tools/            вспомогательные скрипты разработки (не нужны в игре)
docs/             источники NASA, план, атлас кампании, презентация, скриншоты, заметки разработки
default.project.json  проект Rojo
```

### Авторы и ресурсы
- 3D-модели частично сгенерированы ИИ-ассистентом Roblox Studio (генерация мешей и материалов).
- Звуки окружения — Pro Sound Effects из Roblox Creator Store (бесплатные).
- Оригинальная космическая история; без чужих брендов и символики.

---

## English

### About
Architects of Nova is a co-op game for ages 6–12 (and grown-ups). The crew designs a space mission: builds a satellite or
probe from real subsystems (power, comms, instruments, propulsion), fits mass, budget and the rocket fairing, passes a
launch-readiness poll and launches the rocket. Then the crew flies to field sites: the Moon, Mars, Europa, an asteroid,
an orbital station and the L2 Lagrange point.

- **Campaign M0–M6** — story "The Blackout", two field sites per world, team voting.
- **Citadel hub** — hangar with module racks, launch pads, market, hologram atrium, zero-G trainer.
- **Classes with perks** — commander, engineer, scientist; co-op heavy carry.
- **Rocket launches** — cinematic lift-offs with engine fire, smoke and crew flights to the field sites.
- **Urgent tasks** — timed breakdowns around the hub (coolant, power, antenna, calibration, budget).
- **Interactive physics task** — at the launch area players build the right formula with buttons
  (rocket weight W = m · g) and compare it with engine thrust, with a hint for thinking players.
- **Outfitter shop** — spacesuit colours and helmets for credits.
- **NASA facts** — every mission is based on real NASA missions (sources in `docs/NASA_SOURCES.md`).

### How to open
1. **Full place file:** open `ArchitectsOfNova.rbxl` (repo root) in Roblox Studio — all models, terrain, lighting and scripts.
2. **Scripts only (Rojo):** `rojo serve default.project.json` and connect with the Rojo plugin in Studio.
   Scripts live in `src/`, one folder per Roblox service.

### Structure
```
src/              scripts per Roblox service (Rojo: *.server.lua, *.client.lua, *.lua)
tools/            development helpers (not used at runtime)
docs/             NASA sources, plan, campaign atlas, presentation, screenshots, dev notes
default.project.json  Rojo project
```

### Credits
- Some 3D models were generated with the Roblox Studio AI assistant (mesh and material generation).
- Ambient sounds: Pro Sound Effects on the Roblox Creator Store (free).
- Original space story; no third-party brands or symbols.
