-- ExpeditionService: the crew boards the crew rocket, flies to a field location (cinematic),
-- completes co-op objectives there and flies back. Objectives are data (Data.Locations).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Locations = require(RS.Nova.Data.Locations)
local Story = require(RS.Nova.Data.Story)
local Remotes = RS.Nova.Remotes
local MiniGame = require(script.Parent:WaitForChild("MiniGameService"))

local E = {}
local Mission, Hangar, Heavy, Cutscenes, Progress
local holdStart: { [Player]: number } = {}
local conns = {}

local function lobby()
	local t = {}
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") ~= false then table.insert(t, p) end end
	return t
end

local function hrp(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end

local function unseat(p)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		local w = hum.SeatPart:FindFirstChild("SeatWeld")
		if w then w:Destroy() end
		hum.Sit = false
	end
end

-- crew capsule: each player takes a real seat (sitting pose), up to 4
local function seatCrew(p, cabin)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local seats = cabin:FindFirstChild("Seats")
	if seats then
		for i = 1, 4 do
			local chair = seats:FindFirstChild("Chair" .. i)
			local s = chair and chair:FindFirstChild("CrewSeat" .. i)
			if s and (not s.Occupant or s.Occupant == hum) then
				char:PivotTo(s.CFrame * CFrame.new(0, 2.6, 0))
				s:Sit(hum)
				return
			end
		end
	end
	char:PivotTo(cabin.Seat.CFrame * CFrame.new(0, 3, 0))
end

local function teleportAll(cf, spread)
	for _, p in lobby() do pcall(function() p:RequestStreamAroundAsync(cf.Position, 5) end) end
	for i, p in lobby() do
		local r = hrp(p)
		if r then
			unseat(p)
			r.AssemblyLinearVelocity = Vector3.zero
			p.Character:PivotTo(cf * CFrame.new(((i - 1) % 2) * spread - spread / 2, 3, math.floor((i - 1) / 2) * spread))
		end
	end
end

local function setAnchored(on)
	for _, p in lobby() do local r = hrp(p) if r then r.Anchored = on end end
end

local function setLocation(locId, gravity)
	for _, p in lobby() do
		p:SetAttribute("Location", locId)
		p:SetAttribute("Gravity", gravity)
	end
end

local function cueAll(msg) Remotes.Cue:FireAllClients(msg) end

local function addPrompt(part, key, objKey, hold)
	local pr = Instance.new("ProximityPrompt")
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.HoldDuration = hold or 0
	pr:SetAttribute("Key", key)
	if objKey then pr:SetAttribute("ObjectKey", objKey) end
	pr:SetAttribute("HoldBase", hold or 0)
	pr.Parent = part
	table.insert(conns, pr.PromptButtonHoldBegan:Connect(function(plr) holdStart[plr] = os.clock() end))
	return pr
end

local function holdOk(plr, base, cls, mul)
	if base <= 0 then return true end
	local m = (cls and plr:GetAttribute("Class") == cls) and (1 / (mul or 2)) or 1
	return holdStart[plr] ~= nil and os.clock() - holdStart[plr] >= base * m * 0.8
end

------------------------------------------------------------------ objective runners
local runners = {}
local function finish(obj)
	if obj.done then return end
	obj.done = true
	cueAll({ type = "toast", key = obj.def.key, status = "green", icon = "check" })
	Progress.awardAll(60, 8)
	Mission.broadcast()
end
local function progress(obj, n)
	obj.progress = n
	if n >= obj.total then finish(obj) else Mission.broadcast() end
end

local function spotList(loc, names)
	local t = {}
	for _, n in names do local s = loc.Spots:FindFirstChild(n) if s then table.insert(t, s) end end
	return t
end

-- drive the rover to a far marker: any player seated in a rover (driver or passenger) within 16 studs completes it
function runners.drive(obj, loc, ctx)
	local s = loc.Spots:FindFirstChild(obj.def.to or "RoverTarget")
	if not s then finish(obj) return end
	obj.total = 1
	s:SetAttribute("Need", true)
	local beam = Instance.new("Part")
	beam.Name = "DriveBeam"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(80, 3, 3)
	beam.CFrame = CFrame.new(s.Position + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Color = Color3.fromRGB(90, 210, 235)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Parent = loc
	if Mission.radioOnce then Mission.radioOnce("bip_drive") end
	task.spawn(function()
		while not obj.done and ctx.alive() do
			for _, p in lobby() do
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				local seat = hum and hum.SeatPart
				local m = seat and seat.Parent
				if m and m:GetAttribute("Buggy") and (seat.Position - s.Position).Magnitude < 16 then
					s:SetAttribute("Need", nil)
					s:SetAttribute("Done", true)
					cueAll({ type = "sfx", name = "fix", pos = s.Position })
					progress(obj, 1)
					break
				end
			end
			task.wait(0.3)
		end
		beam:Destroy()
	end)
end

-- repairs and alignments are mini-games: wires/pipes for repairs, signal tuning for antennas
function runners.repair(obj, loc)
	local spots = spotList(loc, obj.def.spots)
	obj.total = #spots
	local n = 0
	local kind = obj.def.game or (obj.def.type == "align" and "tune" or "wires")
	for _, s in spots do
		local pr = addPrompt(s, obj.def.type == "align" and "p_align" or "p_repair", obj.def.key, 0)
		pr:SetAttribute("FixClass", obj.def.class)
		s:SetAttribute("Need", true)
		local function complete()
			if s:GetAttribute("Done") then return end
			MiniGame.cancelSpot(s)
			s:SetAttribute("Done", true)
			s:SetAttribute("Need", nil)
			pr.Enabled = false
			cueAll({ type = "sfx", name = "fix", pos = s.Position })
			n += 1
			progress(obj, n)
		end
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if s:GetAttribute("Done") then return end
			MiniGame.start(plr, kind, { class = obj.def.class, spot = s, titleKey = obj.def.key, min = 2 }, complete)
		end))
	end
end
runners.align = runners.repair

local function spawnPickup(loc, pos, item, objKey)
	local tpl = game:GetService("ServerStorage").Nova.Items:FindFirstChild(item)
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
	m:PivotTo(CFrame.new(pos + Vector3.new(0, 1.2, 0)))
	m.Parent = loc
	local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	local pr = addPrompt(root, "p_pickup", objKey)
	table.insert(conns, pr.Triggered:Connect(function(plr)
		if Hangar.carriedId(plr) or plr:GetAttribute("HeavyHold") then return end
		m:Destroy()
		Hangar.giveCarried(plr, "item:" .. item)
	end))
	return m
end

function runners.scan(obj, loc, ctx)
	local spots = spotList(loc, obj.def.spots)
	obj.total = #spots
	local n = 0
	for _, s in spots do
		local pr = addPrompt(s, "p_scan", obj.def.key, obj.def.hold)
		pr:SetAttribute("OnlyClass", obj.def.class)
		pr:SetAttribute("FixClass", obj.def.class)
		s:SetAttribute("Hidden", true)
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if s:GetAttribute("Done") then return end
			-- only the Scientist sees through the shadow (anyone, if no Scientist is in the crew)
			local sci = false
			for _, p in lobby() do if p:GetAttribute("Class") == obj.def.class then sci = true end end
			if sci and plr:GetAttribute("Class") ~= obj.def.class then return end
			if not holdOk(plr, obj.def.hold, obj.def.class, 2) then return end
			s:SetAttribute("Done", true)
			s:SetAttribute("Hidden", nil)
			pr.Enabled = false
			if plr:GetAttribute("Class") == "scientist" then Progress.award(plr, 30, 10) end
			spawnPickup(loc, s.Position, "sample", "o_samples")
			cueAll({ type = "sfx", name = "scan", pos = s.Position })
			n += 1
			progress(obj, n)
		end))
	end
end

function runners.deliver(obj, loc, ctx)
	obj.total = obj.def.count or 1
	local item = "item:" .. obj.def.item
	local depot = loc.Spots:FindFirstChild(obj.def.from)
	if depot then
		local pr = addPrompt(depot, "p_take", obj.def.key)
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if obj.done or Hangar.carriedId(plr) or plr:GetAttribute("HeavyHold") then return end
			Hangar.giveCarried(plr, item)
		end))
	end
	local targets = {}
	local single = loc.Spots:FindFirstChild(obj.def.to)
	if single then table.insert(targets, single)
	else for i = 1, obj.total do local t = loc.Spots:FindFirstChild(obj.def.to .. i) if t then table.insert(targets, t) end end end
	for _, t in targets do t:SetAttribute("Need", true) end
	local n = 0
	task.spawn(function()
		while not obj.done and ctx.alive() do
			task.wait(0.25)
			for _, p in lobby() do
				if Hangar.carriedId(p) == item then
					local r = hrp(p)
					for _, t in targets do
						if r and not (t:GetAttribute("Done") and #targets > 1) and (r.Position - t.Position).Magnitude < 9 then
							Hangar.takeAway(p)
							if #targets > 1 then
								t:SetAttribute("Done", true)
								t:SetAttribute("Need", nil)
								local tpl = game:GetService("ServerStorage").Nova.Items:FindFirstChild(obj.def.item)
								if tpl then local m = tpl:Clone() for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end m:PivotTo(t.CFrame + Vector3.new(0, 1.5, 0)) m.Parent = loc end
							end
							cueAll({ type = "sfx", name = "install", pos = t.Position })
							n += 1
							progress(obj, n)
							if #targets == 1 and n >= obj.total then t:SetAttribute("Need", nil) end
							break
						end
					end
				end
			end
		end
	end)
end

function runners.heavy(obj, loc)
	obj.total = 1
	local from = loc.Spots:FindFirstChild(obj.def.from)
	local to = loc.Spots:FindFirstChild(obj.def.to)
	to:SetAttribute("Need", true)
	local cf = from.CFrame * CFrame.new(0, from.Size.Y / 2 + 1.3, 0)
	Heavy.spawn(cf, { label = obj.def.key, length = 6, parent = loc, visual = game:GetService("ServerStorage").Nova.ModuleModels:FindFirstChild("rtg"),
		check = function(mid)
			if (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(to.Position.X, 0, to.Position.Z)).Magnitude < 10 then
				to:SetAttribute("Need", nil)
				to:SetAttribute("Done", true)
				progress(obj, 1)
				return true
			end
			return false
		end })
end

function runners.timed(obj, loc, ctx)
	local spots = spotList(loc, obj.def.spots)
	obj.total = #spots
	local n = 0
	for i, s in spots do
		local pr = addPrompt(s, "p_sample", obj.def.key)
		pr.Enabled = false
		s:SetAttribute("Need", true)
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if s:GetAttribute("Done") or not s:GetAttribute("Active") then return end
			s:SetAttribute("Done", true)
			s:SetAttribute("Need", nil)
			pr.Enabled = false
			n += 1
			progress(obj, n)
		end))
		task.spawn(function()
			task.wait(i * 3)
			while ctx.alive() and not s:GetAttribute("Done") do
				s:SetAttribute("Active", true)
				pr.Enabled = true
				task.wait(obj.def.active)
				s:SetAttribute("Active", nil)
				pr.Enabled = false
				task.wait(obj.def.period - obj.def.active)
			end
			s:SetAttribute("Active", nil)
		end)
	end
end

function runners.sync(obj, loc)
	local spots = spotList(loc, obj.def.spots)
	obj.total = 1
	local presses = {}
	for _, s in spots do
		local pr = addPrompt(s, "p_activate", obj.def.key)
		s:SetAttribute("Need", true)
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if obj.done then return end
			local now = os.clock()
			presses[s.Name] = now
			s:SetAttribute("Pressed", now)
			local need = math.min(#spots, math.max(1, #lobby()))
			local c = 0
			for _, t in presses do if now - t <= obj.def.window then c += 1 end end
			cueAll({ type = "sfx", name = "click", pos = s.Position })
			if c >= need then
				for _, sp in spots do sp:SetAttribute("Need", nil) sp:SetAttribute("Done", true) end
				for _, p in lobby() do Progress.achieve(p, "sync") end
				progress(obj, 1)
			end
		end))
	end
end

function runners.sequence(obj, loc)
	local spots = spotList(loc, obj.def.spots)
	obj.total = #spots
	local step = 1
	for i, s in spots do
		s:SetAttribute("Order", i)
		s:SetAttribute("Need", true)
		local pr = addPrompt(s, "p_activate", obj.def.key)
		table.insert(conns, pr.Triggered:Connect(function(plr)
			if obj.done or s:GetAttribute("Done") then return end
			if i == step then
				s:SetAttribute("Done", true)
				s:SetAttribute("Need", nil)
				step += 1
				progress(obj, step - 1)
			else
				-- wrong order: all latches snap back
				for _, sp in spots do sp:SetAttribute("Done", nil) sp:SetAttribute("Need", true) end
				step = 1
				progress(obj, 0)
				cueAll({ type = "toast", key = "rehearsal_fail", status = "red", icon = "lock" })
			end
		end))
	end
end

function runners.shelter(obj, loc, ctx)
	obj.total = 1
	obj.hiddenUntil = true
	local spot = loc.Spots:FindFirstChild(obj.def.spot)
	task.spawn(function()
		task.wait(28)
		if not ctx.alive() then return end
		obj.hiddenUntil = nil
		local deadline = workspace:GetServerTimeNow() + obj.def.timer * (Mission.state.diff.timeMul or 1)
		spot:SetAttribute("Need", true)
		cueAll({ type = "urgent", spot = "field:" .. obj.def.spot, key = obj.def.key, icon = obj.def.icon, deadline = deadline, field = true, pos = spot.Position })
		Mission.broadcast()
		while ctx.alive() and workspace:GetServerTimeNow() < deadline do
			local all = true
			for _, p in lobby() do
				local r = hrp(p)
				if not r or (r.Position - spot.Position).Magnitude > 16 then all = false end
			end
			if all then break end
			task.wait(0.25)
		end
		spot:SetAttribute("Need", nil)
		local ok = true
		for _, p in lobby() do local r = hrp(p) if not r or (r.Position - spot.Position).Magnitude > 16 then ok = false end end
		cueAll({ type = "urgentEnd", spot = "field:" .. obj.def.spot, ok = ok })
		cueAll({ type = "toast", key = ok and "shelter_ok" or "shelter_fail", status = ok and "green" or "red", icon = obj.def.icon })
		if ok then
			finish(obj)
		else
			-- missed: an extra repair appears instead of a game over
			obj.def = { id = obj.def.id, type = "repair", key = "rt_urgent", icon = "warning", spots = { obj.def.spot }, hold = 4, class = "engineer" }
			obj.done = false
			spot:SetAttribute("Done", nil)
			runners.repair(obj, loc)
			Mission.broadcast()
		end
	end)
end

------------------------------------------------------------------ flow
function E.has(missionId) return Locations[missionId] ~= nil end

function E.snapshot()
	local f = Mission.state.field
	if not f then return nil end
	local objs = {}
	for _, o in f.objectives do
		if not o.hiddenUntil then
			table.insert(objs, { key = o.def.key, icon = o.def.icon, done = o.done, progress = o.progress or 0, total = o.total or 1, type = o.def.type })
		end
	end
	return { location = f.location, site = f.site, nameKey = f.nameKey, objectives = objs, allDone = f.allDone }
end

local function boardAll(timeout)
	local zone = workspace.Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad") and workspace.Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("BoardZone")
	local cabin = workspace.Citadel:FindFirstChild("CrewCabin")
	local t0 = os.clock()
	local boarded = {}
	while os.clock() - t0 < timeout do
		local all = true
		for _, p in lobby() do
			local r = hrp(p)
			if r and zone and not boarded[p] and (r.Position - zone.Position).Magnitude < 9 then
				boarded[p] = true
				p:SetAttribute("Boarded", true)
				if cabin then seatCrew(p, cabin) end
				cueAll({ type = "sfx", name = "door" })
			end
			if not boarded[p] then all = false end
		end
		Mission.state.boarded = 0
		for _ in boarded do Mission.state.boarded += 1 end
		Mission.broadcast()
		if all and next(boarded) then break end
		task.wait(0.3)
	end
	-- whoever did not make it in time is put in a seat too, so the whole crew flies together
	for _, p in lobby() do
		if not boarded[p] and cabin and p.Character then seatCrew(p, cabin) end
		p:SetAttribute("Boarded", nil)
	end
end

function E.run(missionId)
	local data = Locations[missionId]
	local loc = workspace.Locations:FindFirstChild(data.id)
	if not data or not loc then return end
	-- 0) the crew prepares its own rocket: fuel it and load the field kit (BIP-7 helps when you are alone)
	local prep = workspace.Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("Prep")
	if prep then
		local alive = true
		local pctx = { alive = function() return alive end }
		Mission.state.field = { location = "hub", site = "prep", nameKey = "prep_title", objectives = {} }
		Mission.setPhase("Prep", "Hangar")
		cueAll({ type = "banner", key = "prep_rocket", color = "amber" })
		if Mission.radio then Mission.radio("bip_prep") end
		local PREP = {
			{ id = "fuel", type = "repair", key = "o_fuel", icon = "power", spots = { "FuelPort" }, hold = 4, class = "engineer", game = "pipes" },
			{ id = "kit", type = "deliver", key = "o_kit", icon = "carry", item = "beacon", from = "KitCart", to = "CargoHatch", count = 1 },
		}
		for _, def in PREP do
			local obj = { def = def, done = false, progress = 0, total = 1 }
			table.insert(Mission.state.field.objectives, obj)
			runners[def.type](obj, prep, pctx)
		end
		Mission.broadcast()
		local t0 = os.clock()
		while os.clock() - t0 < 150 do
			local all = true
			for _, o in Mission.state.field.objectives do if not o.done then all = false end end
			if all then break end
			task.wait(0.4)
		end
		alive = false
		for _, p in lobby() do Hangar.takeAway(p) end
		E.cleanup(prep)
		Mission.state.field = nil
		cueAll({ type = "toast", key = "prep_done", status = "green", icon = "rocket" })
	end
	-- 1) boarding
	Mission.setPhase("Board", "Hangar")
	-- the crew suits up: full spacesuits for the flight and the field (they come off back home)
	for _, p in lobby() do if Progress.setEVA then Progress.setEVA(p, true) end end
	cueAll({ type = "banner", key = "go_rocket", color = "amber" })
	boardAll(55)
	-- 2) flight cinematic; teleport during the warp
	Mission.setPhase("Flight", nil)
	setAnchored(true)
	-- stream the destination in early so the arrival shot (lander touchdown) has everything loaded
	for _, p in lobby() do task.spawn(function() pcall(function() p:RequestStreamAroundAsync(loc.Spawn.Position, 12) end) end) end
	local crew = workspace.Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad")
	local crewRocket, crewT0 = E.launchCrewRocket(5.5, 7)
	cueAll({ type = "cutscene", name = "crewFlight", data = { dest = data.id, rocket = crew and crew:GetPivot().Position, model = crewRocket, t0 = crewT0, dur = 7 }, duration = 22 })
	task.wait(17)
	teleportAll(loc.Spawn.CFrame, 5)
	setLocation(data.id, data.gravity)
	task.wait(5)
	setAnchored(false)
	E.resetCrewRocket()
	-- 3) field objectives: site A, then (if the world has one) a lander hop to site B
	local alive = true
	local ctx = { alive = function() return alive and Mission.state.phase == "Field" end }
	local function runSite(root, objectives, nameKey, siteTag, lines)
		Mission.state.field = { location = data.id, site = siteTag, nameKey = nameKey, objectives = {} }
		if Mission.state.phase ~= "Field" then Mission.setPhase("Field", "Field") end
		if lines then task.spawn(Cutscenes.dialogue, lines, nil, { where = "field" }) end
		if siteTag == "A" then
			task.delay(7, function()
				if Mission.state.phase ~= "Field" then return end
				for _, p in lobby() do Remotes.Cue:FireClient(p, { type = "roleBrief", missionId = missionId, part = "field" }) end
			end)
		end
		for _, def in objectives do
			local obj = { def = def, done = false, progress = 0, total = 1 }
			table.insert(Mission.state.field.objectives, obj)
			runners[def.type](obj, root, ctx)
		end
		Mission.broadcast()
		local spawnY = root.Spawn.Position.Y
		while true do
			local all = true
			for _, o in Mission.state.field.objectives do if not o.done then all = false end end
			if all then break end
			-- safety: anyone who falls off the map is put back at the landing site
			for _, p in lobby() do
				local r = hrp(p)
				if r and r.Position.Y < spawnY - 70 then
					r.AssemblyLinearVelocity = Vector3.zero
					p.Character:PivotTo(root.Spawn.CFrame + Vector3.new(0, 4, 0))
				end
			end
			task.wait(0.5)
		end
	end
	local story = Story[missionId]
	runSite(loc, data.objectives, data.nameKey, "A", story and story.field)
	if Progress.questAll then Progress.questAll("site") end
	local locA = loc
	local site = data.siteB and loc:FindFirstChild("SiteB")
	if site and site:FindFirstChild("Spawn") then
		cueAll({ type = "banner", key = "site_next", color = "cyan" })
		for _, p in lobby() do task.spawn(function() pcall(function() p:RequestStreamAroundAsync(site.Spawn.Position, 8) end) end) end
		task.wait(2)
		-- lander lifts off at A, fade, lands at B (client cutscene); teleport happens in the black
		cueAll({ type = "cutscene", name = "landerHop", data = { nameKey = data.siteB.nameKey, loc = data.id }, duration = 9 })
		task.wait(4.6)
		teleportAll(site.Spawn.CFrame, 5)
		task.wait(4.4)
		runSite(site, data.siteB.objectives, data.siteB.nameKey, "B", story and story.site)
		if Progress.questAll then Progress.questAll("site") end
		loc = site
	end
	Mission.state.field.allDone = true
	Progress.achieveAll("explorer")
	cueAll({ type = "banner", key = "field_done", color = "green" })
	loc.Lander:SetAttribute("Need", true)
	Mission.broadcast()
	-- 4) back to the lander, then home
	local t0 = os.clock()
	while os.clock() - t0 < 45 do
		local all = true
		for _, p in lobby() do local r = hrp(p) if not r or (r.Position - loc.Lander.Position).Magnitude > 14 then all = false end end
		if all then break end
		task.wait(0.3)
	end
	loc.Lander:SetAttribute("Need", nil)
	alive = false
	Mission.setPhase("Flight", nil)
	setAnchored(true)
	cueAll({ type = "cutscene", name = "returnFlight", data = { from = data.id, site = (loc ~= locA) and "B" or "A" }, duration = 12 })
	task.wait(8)
	for _, p in lobby() do Hangar.takeAway(p) Heavy.release(p) end
	teleportAll(workspace.Citadel.Atrium.Spawn.CFrame, 5)
	setLocation("hub", 196.2)
	for _, p in lobby() do if Progress.setEVA then Progress.setEVA(p, false) end end
	task.wait(4)
	setAnchored(false)
	E.cleanup(loc)
	if locA ~= loc then E.cleanup(locA) end
	Mission.state.field = nil
end

function E.cleanup(loc)
	for _, c in conns do c:Disconnect() end
	conns = {}
	Heavy.clearAll()
	for _, d in loc:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			-- rover seat prompts belong to the rover, keep them
			local keep, p = false, d.Parent
			while p and p ~= loc do if p:GetAttribute("Buggy") then keep = true break end p = p.Parent end
			if not keep then d:Destroy() end
		end
	end
	-- rovers go back to their parking spot for the next crew
	for _, m in loc:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("Buggy") and typeof(m:GetAttribute("Home")) == "CFrame" and m.PrimaryPart then
			for _, st in m:GetDescendants() do if (st:IsA("Seat") or st:IsA("VehicleSeat")) and st.Occupant then st.Occupant.Sit = false end end
			m.PrimaryPart.Anchored = true
			m:PivotTo(m:GetAttribute("Home"))
		end
	end
	for _, s in loc.Spots:GetChildren() do
		for _, a in { "Done", "Need", "Active", "Hidden", "Pressed", "Order" } do s:SetAttribute(a, nil) end
	end
	for _, m in loc:GetChildren() do
		if m:IsA("Model") and (m.Name == "sample" or m.Name == "beacon" or m.Name == "navbeacon") then m:Destroy() end
	end
end

------------------------------------------------------------------ crew rocket
local crewHome
function E.launchCrewRocket(ignite: number?, dur: number?)
	local pad = workspace.Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad")
	local r = pad and pad:FindFirstChild("Rocket")
	if not r then return nil, 0 end
	crewHome = crewHome or r:GetPivot()
	ignite, dur = ignite or 5.5, dur or 7
	local t0 = workspace:GetServerTimeNow() + ignite
	r:SetAttribute("LaunchT0", t0)
	r:SetAttribute("LaunchDur", dur)
	task.delay(ignite + dur + 0.2, function()
		if r:GetAttribute("LaunchT0") == t0 then r:PivotTo(crewHome + Vector3.new(0, 1200, 0)) end
	end)
	return r, t0
end
function E.resetCrewRocket()
	local pad = workspace.Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad")
	local r = pad and pad:FindFirstChild("Rocket")
	if r and crewHome then r:SetAttribute("LaunchT0", nil) r:PivotTo(crewHome) end
end

function E.init(mission, hangar, heavy, cutscenes, progress)
	Mission, Hangar, Heavy, Cutscenes, Progress = mission, hangar, heavy, cutscenes, progress
end

return E
