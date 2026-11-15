-- NovaAmbientFX: idle and event visuals from the VFX library (cosmetic only, client-side).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local FX = require(RS:WaitForChild("NovaFX"))
local lib = RS:WaitForChild("NovaVFX")
local Remotes = RS:WaitForChild("Nova"):WaitForChild("Remotes")
local Citadel = workspace:WaitForChild("Citadel")
local holder = workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
holder.Name = "ClientFX"
holder.Parent = workspace

local function meshFrom(group, name)
	local f = lib:FindFirstChild(group)
	local src = f and f:FindFirstChild(name)
	if not src then return nil end
	local p = (src:IsA("BasePart") and src or src:FindFirstChildWhichIsA("BasePart", true)):Clone()
	for _, ch in p:GetChildren() do if not (ch:IsA("Decal") or ch:IsA("Texture")) then ch:Destroy() end end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	if p:IsA("MeshPart") then p.TextureID = "" end
	p.Material = Enum.Material.Neon
	p.Parent = holder
	return p
end

------------------------------------------------------------------ hologram: spinning halo rings
local holo = Citadel:WaitForChild("Atrium"):WaitForChild("Hologram")
local proj = holo:WaitForChild("Projector")
local HOLO = Color3.fromRGB(130, 210, 230)
local VEX = Color3.fromRGB(236, 86, 86)
local rings = {}
for i, spec in { { "Rings", "Ring", 7.5, 2.6 }, { "Rings", "Meshes/EyeRing", 5.2, 6.5 }, { "Swirls", "Swirl", 6, 10.5 } } do
	local p = meshFrom(spec[1], spec[2])
	if p then
		p.Color = HOLO
		p.Transparency = 0.72
		if spec[2] == "Meshes/EyeRing" then p.Size = Vector3.new(spec[3], spec[3], 0.2) else p.Size = Vector3.new(spec[3], 0.25, spec[3]) end
		table.insert(rings, { part = p, h = spec[4], spin = (i % 2 == 0) and -0.8 or 0.5, eye = spec[2] == "Meshes/EyeRing" })
	end
end
local figureParts = {}
local function refreshFigure()
	table.clear(figureParts)
	local fig = holo:FindFirstChild("Figure")
	if fig then for _, d in fig:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then table.insert(figureParts, d) end end end
end
refreshFigure()
holo.DescendantAdded:Connect(function() task.defer(refreshFigure) end)
local function speakerColor()
	return (holo:GetAttribute("Speaker") == "vex") and VEX or HOLO
end
local lastSpeaker = nil
local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local base = proj.Position
	local col = speakerColor()
	for _, r in rings do
		local cf = CFrame.new(base + Vector3.new(0, r.h + math.sin(t * 1.3 + r.h) * 0.15, 0))
		if r.eye then
			r.part.CFrame = cf * CFrame.Angles(0, t * r.spin, 0)
		else
			r.part.CFrame = cf * CFrame.Angles(0, t * r.spin, 0)
		end
		r.part.Color = col
	end
	local sp = holo:GetAttribute("Speaker")
	if sp ~= lastSpeaker then
		lastSpeaker = sp
		for _, p in figureParts do
			TweenService:Create(p, TweenInfo.new(0.35), { Color = col }):Play()
		end
		if sp == "vex" then FX.glitch(base + Vector3.new(0, 7, 0), 0.5) end
	end
end)
-- Vex transmissions flicker
task.spawn(function()
	while true do
		task.wait(0.6 + math.random() * 0.8)
		if holo:GetAttribute("Speaker") == "vex" then
			FX.glitch(proj.Position + Vector3.new(math.random(-1, 1), 6 + math.random() * 3, math.random(-1, 1)), 0.25)
			for _, p in figureParts do p.Transparency = 0.6 end
			task.wait(0.06)
			for _, p in figureParts do p.Transparency = 0 end
		end
	end
end)

------------------------------------------------------------------ emergencies: sparks + rotating warning light
local spots = Citadel:FindFirstChild("UrgentSpots")
local beacons = {}
local function beaconFor(spot)
	if beacons[spot] then return beacons[spot] end
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(0.8, 0.8, 0.8)
	b.Material = Enum.Material.Neon
	b.Color = Color3.fromRGB(240, 70, 60)
	b.Anchored, b.CanCollide, b.CanQuery, b.CastShadow = true, false, false, false
	b.CFrame = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + 1.2, 0)
	local l = Instance.new("SpotLight")
	l.Color = Color3.fromRGB(255, 60, 50)
	l.Range = 26
	l.Brightness = 6
	l.Angle = 50
	l.Face = Enum.NormalId.Front
	l.Parent = b
	b.Parent = holder
	beacons[spot] = b
	return b
end
task.spawn(function()
	while true do
		task.wait(0.35)
		spots = spots or Citadel:FindFirstChild("UrgentSpots")
		if spots then
			for _, spot in spots:GetChildren() do
				if spot:IsA("BasePart") then
					local on = spot:GetAttribute("Urgent") ~= nil or spot:GetAttribute("Broken") == true
					local b = beacons[spot]
					if on then
						b = beaconFor(spot)
						b.Transparency = 0
						b.CFrame = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + 1.2, 0) * CFrame.Angles(0, os.clock() * 6, 0)
						if math.random() < 0.6 then FX.sparks(spot, 0.35) end
					elseif b then
						b.Transparency = 1
						b.SpotLight.Enabled = false
					end
					if b then b.SpotLight.Enabled = on end
				end
			end
		end
	end
end)

------------------------------------------------------------------ events from the game
local launchPads = Citadel.Hangar:WaitForChild("LaunchArea")
local lastPhase = nil
Remotes.State.OnClientEvent:Connect(function(s)
	if typeof(s) ~= "table" then return end
	if s.phase == "Launch" and lastPhase ~= "Launch" then
		-- shockwave rings at the selected pad
		local padName = (s.rocketId == "heron" or s.rocketId == "titan") and "PadB" or "PadA"
		local pad = launchPads:FindFirstChild(padName)
		local plinth = pad and pad:FindFirstChild("Plinth")
		if plinth then task.delay(1.1, function() FX.launch(plinth.Position + Vector3.new(0, 1, 0)) end) end
	end
	lastPhase = s.phase
end)
Remotes.Cue.OnClientEvent:Connect(function(c)
	if typeof(c) ~= "table" then return end
	if c.type == "sfx" and c.name == "install" then
		local frame = Citadel.Hangar:FindFirstChild("Frame")
		if frame then
			local cf = frame:GetBoundingBox()
			FX.install(cf.Position, Color3.fromRGB(255, 190, 110))
		end
	end
end)

------------------------------------------------------------------ rocket engines: layered launch plume (client)
-- Any Model named "Rocket" under LaunchArea (or tagged "NovaRocket") that gets LaunchT0 (server time) + LaunchDur:
-- flame on every engine bell from LaunchT0-0.4, pad smoke/dust/flash, follows the model while the client flies it.
local CollectionService = game:GetService("CollectionService")
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local function nsk(t)
	local k = {}
	for _, v in t do table.insert(k, NumberSequenceKeypoint.new(v[1], v[2])) end
	return NumberSequence.new(k)
end
local function csk(a, b) return ColorSequence.new(a, b) end
local function halfExtents(p)
	local cf, s = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hy = math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
	local hx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
	return hx, hy
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

local flames = {}
local function stopFlame(model)
	local f = flames[model]
	if not f then return end
	flames[model] = nil
	if f.conn then f.conn:Disconnect() end
	for _, e in f.emitters do e.Enabled = false end
	for _, b in f.beams do b.Enabled = false end
	for _, l in f.lights do l.Enabled = false end
	task.delay(8, function() for _, x in f.trash do x:Destroy() end end)
end

local function engineParts(model)
	local list, boosters = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Bell" or d:GetAttribute("Engine") then table.insert(list, d)
			elseif d.Name == "Booster" then table.insert(boosters, d) end
		end
	end
	if #list > 7 then
		local pick, step = {}, #list / 7
		for i = 1, 7 do table.insert(pick, list[math.floor((i - 1) * step) + 1]) end
		list = pick
	end
	for _, b in boosters do table.insert(list, b) end
	local noz = model:FindFirstChild("Nozzle", true)
	if #list == 0 and noz then list = { noz } end
	return list, noz
end

local function startFlame(model, t0, dur)
	stopFlame(model)
	local list, noz = engineParts(model)
	if #list == 0 then return end
	local f = { emitters = {}, beams = {}, lights = {}, trash = {}, engines = {} }
	flames[model] = f
	local scale = 1 / math.sqrt(#list)
	local lowest = math.huge
	for _, p in list do
		local hx, hy = halfExtents(p)
		local w = math.clamp(hx * 2, 1, 6)
		local pos = p.Position - Vector3.new(0, hy, 0)
		lowest = math.min(lowest, pos.Y)
		local a0 = Instance.new("Attachment"); a0.Name = "FlameAtt"; a0.Parent = p
		a0.WorldCFrame = CFrame.new(pos) * CFrame.Angles(math.pi, 0, 0) -- +Y points down: emitters use Top
		local L = w * 3.6
		local a1 = Instance.new("Attachment"); a1.Name = "FlameEnd"; a1.Parent = p; a1.WorldPosition = pos - Vector3.new(0, L, 0)
		local a2 = Instance.new("Attachment"); a2.Name = "FlameEnd2"; a2.Parent = p; a2.WorldPosition = pos - Vector3.new(0, L * 1.9, 0)
		table.insert(f.trash, a0); table.insert(f.trash, a1); table.insert(f.trash, a2)
		local core = Instance.new("Beam")
		core.Attachment0, core.Attachment1 = a0, a1
		core.Width0, core.Width1 = w * 0.85, w * 0.2
		core.Color = csk(Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 190, 90))
		core.Transparency = nsk({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } })
		core.LightEmission, core.LightInfluence, core.Brightness = 1, 0, 2.2
		core.FaceCamera, core.Segments = true, 12
		core.Parent = p
		local outer = Instance.new("Beam")
		outer.Attachment0, outer.Attachment1 = a0, a2
		outer.Width0, outer.Width1 = w * 1.25, w * 0.9
		outer.Color = csk(Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 60, 20))
		outer.Transparency = nsk({ { 0, 0.3 }, { 0.5, 0.55 }, { 1, 1 } })
		outer.LightEmission, outer.LightInfluence, outer.Brightness = 1, 0, 1.6
		outer.FaceCamera, outer.Segments = true, 12
		outer.Parent = p
		table.insert(f.beams, core); table.insert(f.beams, outer)
		table.insert(f.trash, core); table.insert(f.trash, outer)
		local plume = emitter(a0, {
			Texture = FIRE, EmissionDirection = Enum.NormalId.Top, LightEmission = 1, LightInfluence = 0,
			Color = csk(Color3.fromRGB(255, 215, 140), Color3.fromRGB(255, 80, 25)),
			Size = nsk({ { 0, w * 1.0 }, { 1, w * 2.4 } }), Transparency = nsk({ { 0, 0.05 }, { 0.7, 0.4 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(45, 70), SpreadAngle = Vector2.new(5, 5),
			Rate = 90 * scale, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180), ZOffset = 1,
		})
		local trail = emitter(a0, {
			Texture = SMOKE, EmissionDirection = Enum.NormalId.Top, LightEmission = 0.1, LightInfluence = 1,
			Color = csk(Color3.fromRGB(196, 192, 186), Color3.fromRGB(140, 136, 130)),
			Size = nsk({ { 0, w * 1.2 }, { 1, w * 5 } }), Transparency = nsk({ { 0, 0.6 }, { 1, 1 } }),
			Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(10, 10), Drag = 0.6,
			Rate = 10 * scale, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25),
		})
		table.insert(f.emitters, plume); table.insert(f.emitters, trail)
		table.insert(f.engines, { a0 = a0, a1 = a1, a2 = a2, L = L, w = w, plume = plume, base = 90 * scale })
	end
	local lightHost = noz or list[1]
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 170, 90); light.Range = 60; light.Brightness = 5; light.Shadows = true
	light.Parent = lightHost
	table.insert(f.lights, light); table.insert(f.trash, light)
	-- pad: smoke clouds rolling out, dust, steam column, ground flash
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { model, holder }
	local base = Vector3.new(lightHost.Position.X, lowest, lightHost.Position.Z)
	local hit = workspace:Raycast(base, Vector3.new(0, -40, 0), params)
	local groundY = hit and hit.Position.Y or (lowest - 2)
	local gp = Instance.new("Part"); gp.Name = "PadFX"; gp.Anchored = true; gp.CanCollide = false; gp.CanQuery = false; gp.CanTouch = false
	gp.Transparency = 1; gp.Size = Vector3.new(1, 1, 1); gp.CFrame = CFrame.new(base.X, groundY + 1, base.Z); gp.Parent = holder
	table.insert(f.trash, gp)
	local ground = {}
	for i = 0, 7 do
		local att = Instance.new("Attachment"); att.Parent = gp
		att.CFrame = CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.Angles(math.rad(-80), 0, 0)
		local e = emitter(att, {
			Texture = SMOKE, EmissionDirection = Enum.NormalId.Top, LightEmission = 0.05, LightInfluence = 1,
			Color = csk(Color3.fromRGB(188, 184, 178), Color3.fromRGB(138, 134, 128)),
			Size = nsk({ { 0, 6 }, { 0.4, 16 }, { 1, 28 } }), Transparency = nsk({ { 0, 0.5 }, { 0.6, 0.7 }, { 1, 1 } }),
			Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(24, 40), SpreadAngle = Vector2.new(22, 8), Drag = 1.4,
			Rate = 12, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30), Acceleration = Vector3.new(0, 1.5, 0),
		})
		table.insert(ground, { e = e, base = 7 }); table.insert(f.emitters, e)
	end
	local steam = emitter(gp, {
		Texture = SMOKE, EmissionDirection = Enum.NormalId.Top, LightInfluence = 1,
		Color = csk(Color3.fromRGB(200, 198, 194), Color3.fromRGB(160, 158, 154)),
		Size = nsk({ { 0, 8 }, { 1, 30 } }), Transparency = nsk({ { 0, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(30, 30), Rate = 16,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
	})
	local dust = emitter(gp, {
		Texture = SMOKE, EmissionDirection = Enum.NormalId.Top, LightInfluence = 1,
		Color = csk(Color3.fromRGB(196, 176, 150), Color3.fromRGB(150, 134, 116)),
		Size = nsk({ { 0, 2 }, { 1, 7 } }), Transparency = nsk({ { 0, 0.2 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(50, 75), SpreadAngle = Vector2.new(88, 88), Rate = 40,
		Acceleration = Vector3.new(0, -20, 0), Drag = 1,
	})
	table.insert(ground, { e = steam, base = 8 }); table.insert(ground, { e = dust, base = 40 })
	table.insert(f.emitters, steam); table.insert(f.emitters, dust)
	local flash = Instance.new("PointLight"); flash.Color = Color3.fromRGB(255, 160, 80); flash.Range = 55; flash.Brightness = 4; flash.Parent = gp
	table.insert(f.lights, flash)
	f.conn = RunService.RenderStepped:Connect(function()
		if not model.Parent or model:GetAttribute("LaunchT0") ~= t0 then stopFlame(model) return end
		local t = workspace:GetServerTimeNow() - t0
		if t > dur then stopFlame(model) return end
		local pre = t < 0
		local n = math.noise(os.clock() * 9, 0.3)
		for _, e in f.engines do
			local k = (pre and 0.45 or 1) * (0.92 + 0.16 * n)
			local dir = e.a0.WorldCFrame.UpVector
			e.a1.WorldPosition = e.a0.WorldPosition + dir * e.L * k
			e.a2.WorldPosition = e.a0.WorldPosition + dir * e.L * 1.9 * k
			e.plume.Rate = e.base * (pre and 0.5 or 1)
		end
		light.Brightness = (pre and 2.5 or 5) + 2 * n
		local height = math.max(0, lightHost.Position.Y - groundY)
		local g = pre and 0.6 or math.clamp(1 - height / 90, 0, 1)
		for _, x in ground do x.e.Rate = x.base * g end
		flash.Brightness = 4 * g + 1.5 * n * g
	end)
end

local function watchRocket(model)
	if not model:IsA("Model") or model:GetAttribute("_FlameWatch") then return end
	model:SetAttribute("_FlameWatch", true)
	local function check()
		local t0, dur = model:GetAttribute("LaunchT0"), model:GetAttribute("LaunchDur")
		if not t0 then stopFlame(model) return end
		dur = dur or 7
		task.spawn(function()
			while workspace:GetServerTimeNow() < t0 - 0.4 do
				if model:GetAttribute("LaunchT0") ~= t0 then return end
				task.wait()
			end
			if model:GetAttribute("LaunchT0") == t0 and workspace:GetServerTimeNow() < t0 + dur then startFlame(model, t0, dur) end
		end)
	end
	model:GetAttributeChangedSignal("LaunchT0"):Connect(check)
	check()
end
for _, d in launchPads:GetDescendants() do if d.Name == "Rocket" then watchRocket(d) end end
launchPads.DescendantAdded:Connect(function(d) if d.Name == "Rocket" then task.defer(watchRocket, d) end end)
for _, m in CollectionService:GetTagged("NovaRocket") do watchRocket(m) end
CollectionService:GetInstanceAddedSignal("NovaRocket"):Connect(watchRocket)

------------------------------------------------------------------ colony life: workers, robot arms, drones, rovers (tag "NovaLife")
-- Purely cosmetic and local: server places the models, every client animates its own copy.
do
	local CS = game:GetService("CollectionService")
	local ANIM = { idle = "rbxassetid://507766388", walk = "rbxassetid://507777826", press = "rbxassetid://136797773743052", carry = "rbxassetid://137701869047989" }
	local items = {}
	local function play(model, id, speed)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = hum
		local a = Instance.new("Animation"); a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok and tr then tr.Looped = true; tr:Play(0.3, 1, speed or 1); return tr end
	end
	local function sparks(att)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 140, 40))
		e.LightEmission = 1; e.LightInfluence = 0
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.02) })
		e.Lifetime = NumberRange.new(0.2, 0.5); e.Speed = NumberRange.new(6, 14); e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -35, 0); e.Rate = 0; e.Parent = att
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(170, 210, 255); l.Range = 9; l.Brightness = 0; l.Parent = att
		return e, l
	end
	local function add(m)
		if items[m] or not m:IsA("Model") then return end
		local it = { m = m, t0 = math.random() * 10 }
		local role = m:GetAttribute("NovaNPC")
		local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
		if not root then return end
		it.home = m:GetPivot()
		if role == "welder" then
			play(m, ANIM.press, 0.8)
			local tip = m:FindFirstChild("SparkTip", true)
			if tip then it.sp, it.light = sparks(tip) end
		elseif role == "checker" then play(m, ANIM.press, 0.6)
		elseif role == "scanner" then play(m, ANIM.idle, 1)
		elseif role == "carrier" then
			it.a, it.b = m:GetAttribute("PathA"), m:GetAttribute("PathB")
			if it.a and it.b then play(m, ANIM.carry, 1) else play(m, ANIM.idle, 1) end
			it.y = it.home.Position.Y - (it.a and it.a.Y or 0)
		elseif m:GetAttribute("Rover") then
			local cf, sz = m:GetBoundingBox()
			it.lift = it.home.Position.Y - (cf.Position.Y - sz.Y / 2)
		end
		items[m] = it
	end
	local function remove(m) items[m] = nil end
	for _, m in CS:GetTagged("NovaLife") do add(m) end
	CS:GetInstanceAddedSignal("NovaLife"):Connect(add)
	CS:GetInstanceRemovedSignal("NovaLife"):Connect(remove)
	local function ringPoint(s, L)
		-- clockwise square loop of half-size L, s in [0,1)
		local per = 8 * L
		local d = (s % 1) * per
		local seg = math.floor(d / (2 * L)); local f = d - seg * 2 * L
		if seg == 0 then return Vector3.new(-L + f, 0, -L), Vector3.new(1, 0, 0)
		elseif seg == 1 then return Vector3.new(L, 0, -L + f), Vector3.new(0, 0, 1)
		elseif seg == 2 then return Vector3.new(L - f, 0, L), Vector3.new(-1, 0, 0)
		else return Vector3.new(-L, 0, L - f), Vector3.new(0, 0, -1) end
	end
	local beacons = {}
	local plaza = Citadel:FindFirstChild("PlazaDeco")
	if plaza then for _, d in plaza:GetDescendants() do if d.Name == "Beacon" and d:IsA("BasePart") then table.insert(beacons, d) end end end
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for m, it in items do
			if not m.Parent then items[m] = nil continue end
			local t = now + it.t0
			local role = m:GetAttribute("NovaNPC")
			if role == "welder" and it.sp then
				local on = (t % 3.2) < 2.2
				if on and math.random() < 0.6 then it.sp:Emit(math.random(2, 6)) end
				it.light.Brightness = on and (2 + math.random() * 3) or 0
			elseif role == "scanner" then
				m:PivotTo(it.home * CFrame.Angles(0, math.sin(t * 0.5) * 0.45, 0))
			elseif role == "carrier" and it.a and it.b then
				local dist = (it.b - it.a).Magnitude
				local period = dist / 5 * 2 + 3
				local u = (t % period) / period
				local p, dir
				if u < 0.5 then
					local k = math.clamp((u * period - 0.75) / (dist / 5), 0, 1)
					p, dir = it.a:Lerp(it.b, k), (it.b - it.a)
				else
					local k = math.clamp(((u - 0.5) * period - 0.75) / (dist / 5), 0, 1)
					p, dir = it.b:Lerp(it.a, k), (it.a - it.b)
				end
				local pos = Vector3.new(p.X, p.Y + it.y, p.Z)
				m:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dir.X, 0, dir.Z)))
			elseif m:GetAttribute("Arm") then
				m:PivotTo(it.home * CFrame.Angles(0, math.sin(t * 0.7) * 0.6, 0))
			elseif m:GetAttribute("Drone") then
				local c, r, sp = m:GetAttribute("Center"), m:GetAttribute("Radius") or 30, m:GetAttribute("Speed") or 0.15
				local a = t * sp * math.pi * 2 / 6
				local pos = c + Vector3.new(math.cos(a) * r, math.sin(t * 1.3) * 1.2, math.sin(a) * r)
				local tang = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(sp)
				m:PivotTo(CFrame.lookAt(pos, pos + tang) * CFrame.Angles(math.rad(-8), 0, math.sin(t * 2) * 0.05))
			elseif m:GetAttribute("Rover") == "ring" then
				local L = m:GetAttribute("Lane") or 161
				local s = (t * (m:GetAttribute("Speed") or 12)) / (8 * L) + (m:GetAttribute("Phase") or 0)
				local p, dir = ringPoint(s, L)
				local pos = Vector3.new(p.X, it.home.Position.Y, p.Z)
				m:PivotTo(CFrame.lookAt(pos, pos + dir))
			elseif m:GetAttribute("Rover") == "path" then
				local p1, p2 = m:GetAttribute("P1"), m:GetAttribute("P2")
				if p1 and p2 then
					local dist = (p2 - p1).Magnitude
					local u = ((t * (m:GetAttribute("Speed") or 10)) / dist + (m:GetAttribute("Phase") or 0) * 2) % 2
					local a, b = p1, p2
					if u > 1 then a, b, u = p2, p1, u - 1 end
					local p = a:Lerp(b, u)
					local pos = Vector3.new(p.X, p.Y + (it.lift or 0), p.Z)
					m:PivotTo(CFrame.lookAt(pos, pos + (b - a) * Vector3.new(1, 0, 1)))
				end
			end
		end
		local blink = (now % 1.6) < 0.25
		for _, b in beacons do b.Transparency = blink and 0 or 0.7 end
	end)
end

------------------------------------------------------------------ object ambience: route prop loops into the Ambience volume group
task.spawn(function()
	local SS = game:GetService("SoundService")
	local grp = SS:FindFirstChild("Ambience", true)
	local t = 0
	while not grp and t < 30 do task.wait(1); t += 1; grp = SS:FindFirstChild("Ambience", true) end
	if not (grp and grp:IsA("SoundGroup")) then return end
	local function route(s) if s:IsA("Sound") and (s.Name == "AmbientLoop" or s.Name == "HoloHum") then s.SoundGroup = grp end end
	for _, d in workspace:GetDescendants() do route(d) end
	workspace.DescendantAdded:Connect(route)
end)

------------------------------------------------------------------ hologram character: talking animations per speaker
task.spawn(function()
	local rig = holo:WaitForChild("Figure", 10)
	local hum = rig and rig:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for who, attr in { kade = "AnimKade", vex = "AnimVex" } do
		local id = rig:GetAttribute(attr)
		if id then
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
			if ok then tr.Looped = true tracks[who] = tr end
		end
	end
	local current
	local function play(who)
		local tr = tracks[who] or tracks.kade
		if tr == current then return end
		if current then current:Stop(0.4) end
		current = tr
		if tr then tr:Play(0.4) end
	end
	play("kade")
	holo:GetAttributeChangedSignal("Speaker"):Connect(function()
		play(holo:GetAttribute("Speaker") == "vex" and "vex" or "kade")
	end)
end)

------------------------------------------------------------------ field locations: weather and ambience (cosmetic, by player position)
task.spawn(function()
	local okL, Locations = pcall(require, RS.Nova.Data:WaitForChild("Locations", 10))
	if not okL or not Locations then return end
	local player = game:GetService("Players").LocalPlayer
	local cam = workspace.CurrentCamera
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CastShadow, anchor.Transparency = true, false, false, false, 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = holder
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local function emitter(props)
		local pe = Instance.new("ParticleEmitter")
		for k, v in props do pe[k] = v end
		pe.Enabled = false
		pe.Parent = att
		return pe
	end
	local SM = "rbxasset://textures/particles/smoke_main.dds"
	local SP = "rbxasset://textures/particles/sparkles_main.dds"
	local fx = {
		mars = emitter({ Texture = SM, Color = ColorSequence.new(Color3.fromRGB(196, 120, 76)), Size = NumberSequence.new(6, 14),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(3, 5), Rate = 40, Speed = NumberRange.new(18, 30), SpreadAngle = Vector2.new(30, 60), EmissionDirection = Enum.NormalId.Right }),
		moon = emitter({ Texture = SP, Color = ColorSequence.new(Color3.fromRGB(200, 210, 230)), Size = NumberSequence.new(0.15),
			Transparency = NumberSequence.new(0.5), Lifetime = NumberRange.new(4, 6), Rate = 12, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180) }),
		asteroid = emitter({ Texture = SP, Color = ColorSequence.new(Color3.fromRGB(230, 200, 160)), Size = NumberSequence.new(0.25),
			Transparency = NumberSequence.new(0.3), Lifetime = NumberRange.new(5, 8), Rate = 18, Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180) }),
		europa = emitter({ Texture = SP, Color = ColorSequence.new(Color3.fromRGB(200, 230, 255)), Size = NumberSequence.new(0.2),
			Transparency = NumberSequence.new(0.35), Lifetime = NumberRange.new(4, 6), Rate = 25, Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0, -2, 0), SpreadAngle = Vector2.new(180, 180) }),
	}
	local vents = {}
	local lastGeyser = {}
	while true do
		task.wait(0.25)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local here = nil
		if hrp then
			for _, loc in Locations do
				if typeof(loc) == "table" and loc.origin and (hrp.Position - loc.origin).Magnitude < 700 then here = loc.id end
			end
		end
		anchor.CFrame = cam.CFrame * CFrame.new(-25, 0, -10)
		for id, pe in fx do pe.Enabled = (id == here) end
		-- Eurydice geysers: swirl column when a vent erupts
		if here == "europa" then
			local L = workspace:FindFirstChild("Locations")
			local eu = L and L:FindFirstChild("europa")
			if eu then
				for _, v in eu:GetDescendants() do
					if v:IsA("BasePart") and v.Name:match("^Vent%d$") then
						local active = v:GetAttribute("Active") == true
						if not active then
							for _, pe in v:GetDescendants() do if pe:IsA("ParticleEmitter") and pe.Enabled then active = true end end
						end
						if active and (not lastGeyser[v] or os.clock() - lastGeyser[v] > 1.2) then
							lastGeyser[v] = os.clock()
							FX.swirl(CFrame.new(v.Position + Vector3.new(0, 6, 0)), Color3.fromRGB(210, 235, 255), 7, 1.6, 1.5)
							FX.ring(v.Position, Color3.fromRGB(200, 230, 255), 6, 0.8)
						end
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------ hologram polish: rising scanlines + subtle flicker
task.spawn(function()
	local lines = {}
	for i = 1, 3 do
		local p = meshFrom("Rings", "Ring")
		if p then
			p.Transparency = 0.8
			p.Size = Vector3.new(4.2, 0.08, 4.2)
			lines[i] = p
		end
	end
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local base = proj.Position.Y + 1
		local col = (holo:GetAttribute("Speaker") == "vex") and Color3.fromRGB(236, 86, 86) or Color3.fromRGB(130, 210, 230)
		for i, p in lines do
			local k = ((os.clock() - t0) * 0.35 + i / 3) % 1
			p.CFrame = CFrame.new(proj.Position.X, base + k * 8.5, proj.Position.Z)
			p.Transparency = 0.65 + k * 0.33
			p.Color = col
		end
	end)
	while true do
		task.wait(2 + math.random() * 3)
		local parts = figureParts
		for _, p in parts do p.LocalTransparencyModifier = 0.5 end
		task.wait(0.05)
		for _, p in parts do p.LocalTransparencyModifier = 0 end
	end
end)
