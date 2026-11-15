# Architects of Nova — status (Roblox Studio "Nova", placeId 81057006386585)

Saved to Roblox, version 76 (15 Nov). Campaign M0–M6, story v2 "The Blackout", 2 field sites per world.

## Pass v60–v76 (main session)
- Emergencies: Data.Progress.difficulty urgentFirst/urgentEvery/urgentMax (cadet 150/240/2, M0 max 1); rest counts from the end of the last one.
- Votes: Data.VoteInfo (tags + line per option) + client NovaClient.VoteArt (ViewportFrame 3D previews); models in ReplicatedStorage.Nova.VoteModels. VOTE_TIME 20.
- Quiz closes when the phase leaves Debrief (Hud lastPhase / State remote).
- Crew capsule rebuilt (Citadel.CrewCabin, Seats/Chair1..4/CrewSeatN, real Seat:Sit); ExpeditionService seatCrew/unseat; EVA suit
  (ProgressService.setEVA / evaShell, attr EVA) from Board until back home.
- LanderShip model on all 12 pads (template ServerStorage.Nova.Props.LanderShip); old LanderCraft parked in ServerStorage.Nova.LanderCraftOld.
  Cinema: shipLand/shipLift/hideCrew; arrival touchdown, landerHop (server wait 4.6 + 4.4), returnFlight liftoff.
- Terrain: Mars SiteB was buried (carved r140, floor y≈-14), Moon SiteB floor y≈-35, Moon A Scan1/2 cleared (Scan2 raised 2.1).
- Buggies: NovaServices.BuggyService + NovaClient.Buggy (LinearVelocity/AlignOrientation hover suspension, Motor6D wheel spin); template
  Props.NovaBuggy; Citadel.MotorPool (3) + Locations.<moon|mars|europa|asteroid>.NovaRover; objective type "drive" (Spots.RoverTarget) in M2/M3 site A.
- Data.RoleLines + Cue roleBrief (Build start, site A arrival) → Hud "Your job" card.
- Debug: ("demo","M1".."M6") runs prep → board → flight → sites → return → report → next mission.
- Server rocket flame removed from HangarService (client flame in NovaAmbientFX).
Plan artifact (campaign atlas): https://claude.ai/artifact/KHzLptCJQuQTNVunJ4r6vK (copy: <project>/plan/nova-atlas.html)
NASA sources + judging audit: <project>/docs/NASA_SOURCES.md
Parallel author: fork session (visuals) owns NovaFX/NovaVFX/NovaAmbientFX, HubDeco/PathArches/RingStation/FacadeDeco, hologram figure,
and was asked for: BIP-7 model (keep Body/Eye, add Accent), Grok + stall (keep Market.Stall.Counter), hologram polish,
ModuleModels/Frames/Items detail (keep names + PrimaryPart Root, Pads/Post_*), remove meaningless cubes, horizon dressing, SiteB Decor.

## Flow
Intro (new cold-open captions) -> menu/lobby -> Lobby start triggers MissionService.coldOpen (alarm + auto M0 briefing) ->
Briefing (hologram, vote) -> Build (resource terminal on the floor, rack signs, inspect card, BIP-7 radio, screen-space guide arrow)
-> F at launch console = Launch Readiness Poll (GO/NO-GO; NO-GO explains fix and blocks) -> Launch (client-side smooth climb from
LaunchT0) -> Ops -> [M1–M6: Prep (fuel + field kit at CrewPad.Prep) -> Board -> Flight -> Site A -> lander hop -> Site B -> return]
-> story dialogue -> report.

## New in this pass
- Movement: generated looped anims removed (the "hand moving" bug was the looped console-press track at Action2);
  procedural carry/reach/lean on Motor6D.Transform in Stepped (visible for all players), default R15 locomotion.
- MissionService.readinessPoll / tryLaunch / doLaunch; M.radio / radioOnce; coldOpen. HangarService.launchRocket returns (model, t0).
- Client modules: Hud (poll, inspect card, settings with volumes/shake/lang saved to profile, NASA mission file key N).
  Audio has SoundGroups Music/SFX/Ambience + per-location ambience. World: screen guide, alarm cue, Prep guide, exposure per world.
- Data: Story (site lines), Locations (siteB per mission), NasaFiles, StringsStory (all new text RU/EN).
- Geometry: Locations.<id>.SiteB at origin +700 Z; Hangar.ResourceTerminal; RackBays.BayN.Sign; CrewPad.Prep.
- Lighting regraded (exposure 0.9, softer contrast, -12% saturation, haze hides edges); 487 harsh neon parts toned down.

## Debug (Studio only)
ServerStorage.Nova.Debug:Invoke("lobby","engineer") / ("start","M2") / ("build") / ("install",slot,mod) / ("launch") (goes through the poll)
/ ("expedition","M3") / ("field") completes current site (also Prep) / ("board") / ("lander","mars") / ("state").

## Not verified
Real multiplayer (2+ humans), lobby teleport in the published game, all six SiteB areas in play (orbit + moon tested).
