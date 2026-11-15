# Architects of Nova — NASA data, sources and judging-criteria audit

NASA Space Apps Challenge 2026 · Challenge: **Space Mission Design Game** · Roblox experience "Nova" (placeId 81057006386585)

Use this file for the **References** field on the project submission page. The submission rules require every external
resource (code, text, images, music) to be listed there.

## 1. Where official NASA sources are used in the game

| NASA source (official) | What the game takes from it | Where it lives in the place (Roblox instance) |
|---|---|---|
| **api.nasa.gov · DONKI** (live API, `https://api.nasa.gov/DONKI/FLR`) | Solar flares of the last 30 days → storm level, story premise, "Space weather" board | `ServerScriptService.NovaServices.LiveDataService` → workspace attrs `SpaceWeather`, `FlareCount`, `StormLevel`; board in `StarterPlayerScripts.NovaClient.World` (`boards()`); urgent-event pacing in `UrgentService` |
| **api.nasa.gov · Asteroids NeoWs** (live API, `https://api.nasa.gov/neo/rest/v1/feed`) | Today's real close-approach asteroids → "Threat board" in the hub, finale context | `LiveDataService` → workspace attr `Threats`; `World.boards()` |
| **CubeSat 101** (NASA CSLI) | 1U = 10 cm / ~1.33 kg, mass & power margin rule (≥10 %) | `ReplicatedStorage.Nova.Data.Launch` (frame `cubesat3u`), `Data.Missions.M0`, `Shared.Resources` (margin), poll check `MissionService.readinessPoll`, debrief lesson `nasa_cubesat101` |
| **Design and Develop Science Missions** (nasa.gov PDF) | Mission segments (launch / space / ground / users) → 4 crew roles and the Build → Launch → Ops → Debrief loop | `Data.Classes`, `MissionService` phases |
| **Concept Maturity Levels** (JPL) | CML-1…CML-5 ranks | `Data.Progress.ranks`, profile chip in `World` |
| **Mission Design Lab** (Goddard) | Subsystems: power, comms, data, computer, protection | `Data.Modules` categories, rack bays in `HangarService` |
| **GMAT / NASA Mission Viz** | Orbit choices and their properties (period, eclipse fraction, polar coverage, push needed) | `Data.Launch.orbits` |
| **A Learning Game About Telescopes** (Webb) | Goal → instrument logic, folding mirror vs fairing | `Data.Missions.M4`, `Data.Modules` (mirror_fold / mirror_solid) |
| **ISS facts** | ~90-min orbit with up to ~1/3 in shadow → battery check | `MissionService` `checks.battery`, lesson `nasa_iss_orbit` |
| **TDRS / SCaN, DSN** | GEO relay vs swarm, deep-space link budget, light-time delay | `Data.Missions.M1/M5`, lessons `nasa_tdrs`, `nasa_geo`, `nasa_dsn` |
| **LCROSS, LRO (Diviner), Lunar Prospector** | Water ice in permanently shadowed craters (~−240 °C); camera blind in shadow → neutron spectrometer | `Data.Missions.M2`, `Data.Locations.M2` (site B "crater floor"), lessons `nasa_lcross`, `nasa_lro` |
| **Mars 2020 Perseverance** | 3–22 min signal delay, EDL order (shield → parachute → sky crane), sample tubes | `Data.Missions.M3`, `Data.Locations.M3` (site B sample cache), lesson `nasa_percy` |
| **James Webb Space Telescope** | 6.5 m / 18-segment folding mirror, 5-layer sunshield, L2 at 1.5 M km | `Data.Missions.M4`, `Data.Locations.M4` (site B mirror deck), lessons `nasa_jwst*` |
| **Europa Clipper, Juno** | Sunlight ≈ 1/25 at Jupiter (1/r²), radiation vault, REASON radar | `Shared.Resources` (1/r² solar power), `Data.Missions.M5`, `Data.Locations.M5`, lessons `nasa_clipper`, `nasa_juno` |
| **DART, Planetary Defense (PDCO)** | Kinetic impact, earlier intercept needs less push; Dimorphos orbit −32 min | `Data.Missions.M6`, `checks.impact`, lesson `nasa_dart` |
| **NASA Go/No-Go launch poll** (launch-control practice) | Launch Readiness Poll before every launch, one NO-GO holds the count | `MissionService.readinessPoll` + `NovaClient.Hud` (poll panel, note `nasa_poll`) |

In-game, every mission has a **NASA mission file** (button "NASA" top-right, key **N**): three real facts with their NASA
source. Data: `ReplicatedStorage.Nova.Data.NasaFiles`. After each flight the report shows a NASA lesson (`hints[3]`).

### 1b. Learning content added for ages 6–12 (Parts Book, Rocket Lab, quizzes)

| NASA source | What the game teaches with it | Where it lives |
|---|---|---|
| **NASA Glenn · Beginner's Guide to Rockets** (grc.nasa.gov/www/k-12/rocket) | Thrust vs weight (TWR > 1 to lift off), rocket equation (Tsiolkovsky), why rockets use stages, ~90 % of launch mass is propellant | `StarterPlayerScripts.NovaClient.RocketLab` (stage builder, 3 levels: low orbit / Moon / Mars), lessons `lab_t1..t5` |
| **NASA · Rockets Educator Guide** (nasa.gov/stem) | Kid-level rocketry explanations used for the Rocket Lab wording | `RocketLab`, `Shared.StringsStory` |
| **NASA Launch Services Program, Pegasus; Atlas V (Mars 2020 launch); Space Launch System (Artemis I)** | Our four rockets explained through real NASA launchers, capacity per orbit | `Data.PartInfo` (`rocket_*`), Parts Book → Rockets tab |
| **Apollo Guidance Computer; Mars 2020 RAD750 rover computer; NASA environmental testing (Goddard)** | Computers, radiation-hardening, why untested parts are risky | `Data.PartInfo` (obc, obc_hard, vex_unit) |
| **ISS power system (lithium-ion batteries), ISS solar arrays, Juno solar arrays, Europa Clipper arrays, Radioisotope Power Systems (Perseverance MMRTG, Voyager)** | Batteries, solar power and the 1/r² law, RTGs | `Data.PartInfo` (battery_*, panel_*, rtg) |
| **Mars Relay Network, SCaN, Deep Space Network, Voyager high-gain antenna** | Antennas, light-speed delay, dish size | `Data.PartInfo` (antenna_uhf, antenna_s, hga) |
| **Perseverance cameras, Curiosity RAD, Lunar Prospector neutron spectrometer, Europa Clipper REASON radar** | Instruments and what each can "see" | `Data.PartInfo` (camera, rad_sensor, neutron_spec, radar) |
| **JWST deployment (344 single-point steps), Hubble mirror, Juno radiation vault** | Folding vs solid mirrors, radiation shielding | `Data.PartInfo` (mirror_fold, mirror_solid, vault) |
| **Mars 2020 EDL (parachute 21.5 m, heat shield ~1300 °C), Sky crane** | Landing on Mars | `Data.PartInfo` (edl_kit, edl_crane) |
| **DART mission and results (≈570 kg, ≈6 km/s, orbit −32 min)** | Planetary defense | `Data.PartInfo` (impactor_*) |
| **NASA Space Place** (spaceplace.nasa.gov) | Reading level and kid-friendly framing | All learning texts |

Every part card in the **Parts Book** (key **B**, or the PARTS BOOK kiosk in the Academy archive) shows: what it does,
a real NASA example, a fun fact and its source. Parts unlock when you pick them up (collection, +20 credits per 5 parts).
After every successful mission a **one-question quiz** from `Data.NasaFiles` (field `quiz`) checks what the mission taught (+15 credits).

## 2. Educational design (required by the challenge's "Educational value" section)

- Concepts are taught **by doing**: margin, eclipse batteries, link budget, launch-vehicle capacity, fairing size, 1/r² power.
- The **Launch Readiness Poll** explains *why* a design is NO-GO and how to fix it, before launch (no blind failures).
- The **module inspect card** shows mass / power / data / cost and the effect on the rocket load when you look at a part.
- **BIP-7 radio** gives step-by-step tips for solo players; M0 is a full tutorial with the on-screen guide arrow.
- The **flight report** explains the failure chain, adds recovery tasks (no "mission lost"), and links a NASA lesson.
- **Two sites per world** (12 field sites) turn each real mission fact into a hands-on task (e.g. ice in eternal shadow).
- **Rocket Lab** (Space Engineers-style building, simplified for kids): stack 1–3 stages; real TWR and delta-v math show why one stage can't reach orbit (max ≈ 6 km/s vs 9 km/s needed) and why Mars needs three.
- **Parts Book** collection: 25 parts + 4 rockets with simple explanations and real NASA examples.
- **Repair mini-games** each end with a NASA fact (ISS cables, ammonia cooling loops, DSN, calibration, budget caps).
- **Quick quiz** after each mission (7 questions, one per chapter).

## 3. Judging criteria (official Judging & Awards Guide, each scored 1–5) → how the game answers them

| Criterion | Official wording (short) | Evidence in the game |
|---|---|---|
| **Impact** | addresses a problem, inspires a broad audience | Roblox reaches tens of millions of teens; free co-op game teaching full mission design; RU + EN |
| **Creativity** | original, novel concept | Original space-opera story ("The Blackout") with mystery, rival, rescue; co-op 3D hangar build + GO/NO-GO poll + field expeditions — not a calculator |
| **Validity** | grounded in science, feasible, usable | Honest simplified physics (margin, eclipse, 1/r², light delay, capacity per orbit); runs today in Roblox; tutorial, settings, guidance |
| **Relevance** | fully addresses the challenge; NASA data is core | Every challenge item covered: objective → requirements → spacecraft → instruments → launcher & orbit → budget, mass, power, comms, data, time → simulation → report; up to 4 players with roles; live DONKI + NeoWs |
| **Presentation** | clear, engaging storytelling | Cinematic cold open, hologram cutscenes with votes, 30-s demo + slides plan |

## 4. Other credits (not NASA)

- Music: APM Music, licensed for Roblox experiences (in-game only). **For the 30-second demo video use your own or royalty-free music**, or confirm the licence, because the rules forbid copyrighted material without permission.
- Sounds: Pro Sound Effects (Roblox library), Roblox built-in sounds.
- Sky: SpaceEngine export (Roblox Creator Store, asset 13724383744).
- 3D models and materials: Roblox Studio AI generation + hand-built parts.
- Educational game. Not endorsed by NASA. No NASA logo is used.
