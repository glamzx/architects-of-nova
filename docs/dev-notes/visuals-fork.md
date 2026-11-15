# Visuals fork — what it changed in "Nova" (no edits to the main session's scripts)

- Lighting: this Studio build hides Lighting.Technology; Future = LightingStyle.Realistic + PrioritizeLightingQuality=true (set).
- User's VFX pack: moved Workspace.VFX -> ReplicatedStorage.NovaVFX/{Rings,Swirls,Blasts,Electric,Beams,Spheres,Misc}. No scripts inside (checked).
- ReplicatedStorage.NovaFX (client module): ring, blast, swirl, sparks, launch, install, warp(camera,t)->stop, glitch.
- StarterPlayerScripts.NovaAmbientFX: hologram halo rings + Kade/Vex talking animations on Atrium.Hologram.Figure
  (Speaker attr "vex" -> red + glitch flicker), urgent-spot sparks + rotating red beacon, launch shockwaves, install flash,
  location weather by player position (Mars dust, Moon/asteroid/Europa motes, Europa geyser swirls on Vent1..3).
- Hologram.Figure = R15 rig (neon, transparent). Anim ids on attributes AnimKade=97884548250165, AnimVex=86213192564416.
  Extra generated anims (for Movement): carry-walk 137701869047989, console-press 136797773743052.
- MaterialVariants added: NovaHullTiles (rocket/ring hull), NovaGoldFoil (MLI, mirrors), NovaCarbon (bands, fins), NovaSolarCell (panels).
- World: outdoor planters removed (containers/pylons instead), PathArches, RingStation (sky), Citadel.Bounds (south wall z=-214),
  rocket detailing (bells, interstage, grid fins, roundel, umbilicals, LOX steam), FacadeDeco (bilingual zone signs, roof greebles),
  HubDeco emblem in atrium floor + market awnings/lamps/shelves, CameraPoints for cutscenes.
## Pass 2 (models, per main-session request)
- ModuleModels replaced with AI-generated textured meshes (PrimaryPart Root, names kept; old versions in ServerStorage.Nova.ModuleModelsOld):
  obc, obc_hard, battery_s/l/xl, rtg, camera, rad_sensor, neutron_spec, radar, vault, vex_unit, mirror_fold, mirror_solid,
  antenna_uhf (pivot at base), antenna_s (base), hga (base), edl_kit, edl_crane, impactor_s, impactor_l.
  Panels (panel_body/wing/array/giant) stay procedural (slot geometry) + hinges/struts/edge frames; probe frame + thrusters/star tracker; cubesat feet.
- Items replaced: sample, beacon, navbeacon (old in ServerStorage.Nova.ItemsOld).
- BIP7: mesh drone; Body (invisible root, PrimaryPart), Accent (plain colour disc under belly), Eye (+PointLight), HoverGlow. Front = -Z.
- Market.Stall: generated Booth + Grok (alien merchant); Counter kept (now invisible, still collides). Old placeholder parts removed.
- Hologram.Figure = generated Kade avatar (R15+, glass holo). Block rig backup at ServerStorage.Nova.FigureBlockBackup.
  Added Hologram.EmitterRing; NovaAmbientFX adds rising scanlines + flicker.
- Locations: Decor boulders/silhouettes -> Terrain (Slate/Sandstone/Glacier/Basalt) + horizon crater-rim ring beyond Bounds;
  mars Rock blocks -> Terrain; orbit: DishVisual1-3 + poles -> RelayDish meshes, centre box/mast -> RelayCore mesh (box kept as invisible RelayCollider).
- Hub: Citadel.Horizon (colony skylines on plateaus + cliff ring), rack shelf boxes -> small crate meshes.
- Generated source models parked in ServerStorage.Nova.Props.

## Pass 3
- Locations.<id>.SiteB.Decor in all 6 worlds: terrain boulders inside SiteB (≥14 studs from SiteB Spots/Lander/Spawn), horizon ring beyond SiteB.Bounds,
  solar wings/truss/edge lights on orbit/l2 decks, outpost kit (mast+beacon+crates) near each SiteB Lander. Site A horizon rings end ≤370 studs
  from the A centre, so they never reach the SiteB zones (origin+700 Z, ±130). Terrain Sand colour (lunar grey) left as set by the main session.

## Pass 4 (kid-friendly readability, 6–12)
- Market.Stall.Booth = new generated spare-parts kiosk (food booth parked at ServerStorage.Nova.Props.BoothFood, source Prop_kiosk).
  Added Stall.SpareSign ("GROK'S SPARES / PARTS • UPGRADES • SKINS", lit), VisorRack (3 helmets with coloured visors),
  SkinDisplay (3 BIP-7 clones on neon pedestals + "BIP-7 SKINS" tag, x≈11–16), PartsBin ("DRONE PARTS", gears/props/motors; walls collide).
  Counter and Grok untouched.
- Barrels/crates removed from Citadel.Props; new Citadel.Supplies: LOX (blue) / LH2 (orange) tanks at PadA/PadB, O₂ (white) + H₂O (blue)
  at the crew pad, spare-part crates (wrench icon) + yellow battery packs (lightning) in hangar corners, 2 delivery crates by hangar door.
  Only "Body"/"Box" parts collide.
- UrgentSpots: *Prop models rebuilt (names kept, spot parts untouched): CoolantProp = blue pipes + red valve wheels + tank + "COOLANT";
  PowerPanelProp = cabinet with yellow lightning door, warning sign, cables, "POWER"; RoofAntennaProp = dish on mast + comms box, "ANTENNA";
  CalibBenchProp = bench + camera instrument + checkerboard target, "CALIBRATION"; AuditDeskProp = wooden desk, terminal (budget icon),
  papers, red chair, "BUDGET DESK". All non-colliding.
- Frames.probe: silver rails, white back + side panels with ribs, small gold MLI patches only, white base deck, gussets, dark adapter +
  orange/white docking ring, "NOVA-PROBE" plates (front bottom + back). Pads/Post_*/PadGlow/Root/Slots unchanged. Backup Props.probe_backup.
- Frames.cubesat3u: blue solar cells on the back (one per U), white end cap, orange U bands, whip antenna, "NOVA-CUBE 3U" plate.
- Hub: HubDeco containers -> coloured corrugated "NOVA CARGO" containers; HubDetail.RoofUnit got a fan. RackBays Spot1/Spot2 plinths left as-is (main's).

- Main session (after Pass 4): cut door holes in Control/Archive .Detail.Lining, set thin transparent strips (incl. FacadeDeco) CanCollide=false.
  Keep new decor strips non-colliding and clear of doorways.

## Pass 5 (world around the citadel, "make it alive")
- Rockets: LaunchArea.PadA/PadB/CrewPad.Rocket each got a generated mesh in child model "MeshBody". Old parts kept but invisible
  (OrigTransparency attr), Body = PrimaryPart, Nozzle + Exhaust, pivots unchanged. Old Bell -> "OldBell"; invisible "EngineMark"
  parts (attr Engine=true) at the real engine bells. Mesh sources: ServerStorage.Nova.Props.Prop_rocket_*.
- Client flame (NovaAmbientFX "rocket engines"): watches Models named "Rocket" under LaunchArea + tag "NovaRocket". From LaunchT0-0.4 to
  LaunchT0+LaunchDur: per engine core Beam + outer Beam + fire particles + smoke trail; PointLight flicker; pad smoke ring (8 dirs),
  steam column, dust, ground flash; fades with altitude; stops on LaunchT0=nil. Server emitter in HangarService ~477 can be removed.
- Citadel.Horizon colony skylines parked in ServerStorage.Nova.HorizonOld. New Citadel.Outskirts (all CanCollide=false, outside Bounds):
  Refinery x2 (smoke) SW + Pipeline to the west wall, SolarFarm W (60 panels), CargoYard E (2 cranes + container stacks), LandingPads N
  (3 pads + shuttles + floodlights), Greenhouses NE, IceMining NW, CommDishes SE, LaunchComplex2 S (tower + rocket), Crystals (10, lit).
- Ground: hub terrain (±600) Basalt->Limestone (140,133,121), Rock->Ground (136,128,116), Salt/Ground patches. Asteroid world keeps
  Basalt/NovaAsteroidRock (materials checked: Limestone/Ground/Salt/Pavement not used in any field world).
  Citadel.Ground tiles: Concrete checker (116/106 grey) instead of dark NovaFloorPlate. Citadel.GroundDeco: tile seams + ring road
  (asphalt band |x| or |z| 156..176, yellow edges, white dashes).
- Citadel.PlazaDeco: Garden NW (2 greenhouses, solar trees), PowerYard SW (8 solar trees, battery bank), Masts (blinking Beacon),
  Pylons, ServiceYard SE (containers, WorkPiece + WorkMat).
- Life (tag "NovaLife", ModelStreamingMode Atomic, animated client-side in NovaAmbientFX "colony life"): Citadel.Life = R15 workers
  (attr NovaNPC = welder/scanner/carrier/checker; carriers walk PathA<->PathB), robot arm (Arm), 4 drones (Drone, Center, Radius, Speed),
  3 rovers on the ring road (Rover="ring", Lane 161), 2 rovers outside the walls (Rover="path", P1/P2). Verified in Play: anims play, rovers/drones move.
- Field sites: Locations.<id>.Decor.Camp and SiteB.Decor.Camp: habitats, rovers, crates, masts, floodlights, solar trees, ice rig
  (europa), crystals (asteroid), workers + a drone per site; ≥14 studs + radius from Spots/Lander/Spawn, inside Bounds, non-colliding.
- Worker/prop builder: ServerStorage.Nova.LifeKit (ModuleScript, Edit-time helper only, not required at runtime).

## Pass 5b (after main's LanderShip + terrain carve)
- Camps re-checked: items <14 studs from Spawn/Lander/Spots, <20 from a LanderShip, or in its +Z ramp corridor (|x|<12, z<40) removed
  (moon.B 3, asteroid.B 2). Mars SiteB and Moon SiteB camps rebuilt on the carved floors (13 and 10 items) + terrain boulders
  only on the rim (Mars r 98–112, Moon r 64–76, ≥22 studs + size from every key point).
- Cleared terrain over Moon A Scan3 (was 4.4 studs under) and lowered the ridge over Europa B Capsule spot (ground now y=2).
- Raycast check over all 86 Spawn/Lander/Spot points: remaining overlaps are ≤2 studs (parts resting slightly sunk), listed to main.
  Moon A Scan2 still has terrain ~2 studs above its centre.

## Pass 6 (adult SpaceX/NASA look, walk-in domes, M1 fixes, sounds)
- Shop: Market.Stall.Outfitter = "SUIT SUPPLY / Colony outfitter" booth: white panels with seams, brushed-metal sides, black
  fascia (Neon black so it stays matte) + thin red #E03C31 line, warm work SpotLights, visible counter matching the invisible
  Counter collider, helmet shelf (12 helmets, dark visors), 3 suit mannequins on plinths (one in a dark-glass case), white supply
  cases, quartermaster (dark coverall, red chest line, tablet, NovaLife "scanner"). Counter untouched (prompt still on it).
  Booth/Grok/SpareSign/VisorRack/SkinDisplay/PartsBin parked in ServerStorage.Nova.ShopOld. UI strings still say "Grok's shop".
- Domes: PlazaDeco.Garden.WalkDome x2 (R 17 and 14, ~18/15 studs tall): colliding glass panels on a frame, white ribs, low base
  wall, airlock vestibule facing the hub with "HYDROPONICS 1/2" sign, concrete floor, planter beds (centre aisle 6 wide),
  grow-light bars, a tree, warm top light. Old mesh greenhouses parked in ShopOld. Garden scanner now works inside dome 1.
- Colliders: invisible "Collider" boxes on field-camp habitats/rovers/ice rigs/crates/crystals, trunk colliders on solar trees,
  robot arm; containers, battery bank, pylons, workpiece, mast/flood poles and the outfitter walls now CanCollide.
- Orbit: 6 coplanar deck parts lifted by 0.04–0.08 (graph colouring) to stop z-fighting. RelayDish1-3 were floating 15 studs above
  the deck -> Decor.DishMast1-3 (white tube, flange, red band, 3 struts, collides) from deck y=601 to the dish mount.
  orbit.SiteB.Props.Mast x2 (main's, 30-long horizontal rods at y 602.6, z 664–694) sit partly outside SiteB bounds (z 690–710).
- Sounds (63 loops, all ProSoundEffects, verified loaded): refinery 9112838943, pipes/cranes/ice rigs 9112839913, domes/habitats/
  greenhouses 9117728939, shuttles 9117729244, rovers 9125767459 (x1.35), dishes/battery 9125784811, hologram 9119997638 ("HoloHum"),
  drones 9119997818 (x1.8), welders 9119992841, robot arm 9118329245. InverseTapered 6..24–80, Volume 0.12–0.4.
  NovaAmbientFX routes Sounds named AmbientLoop/HoloHum into SoundService "Ambience" group at runtime (none exists in Edit).
- Studio viewport stopped rendering screenshots mid-pass (blank frames); dome interior/rotation verified by geometry only.

- After agents-protocol.md: world signs made bilingual (Outfitter fascia "SUIT SUPPLY · СКАФАНДРЫ", sub-label, terminal;
  domes "ГИДРОПОНИКА n · HYDROPONICS"). The booth model Market.Stall.Outfitter is world decor (visuals fork); the Outfitter
  agent owns the shop scripts/UI. No save_place from this session any more (main saves).

- Not possible via MCP: running Studio plugins (F3X, Archimedes, GapFill, Moon Animator, AutoScale) — their effects were reproduced in code.
