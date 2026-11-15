-- VoteArt: small 3D previews for team-vote options, rendered in a ViewportFrame on each vote card,
-- so a kid sees WHAT each option is (dark icy crater vs sunlit rim, one big satellite vs a swarm...).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local A = {}

local rgb = Color3.fromRGB
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local NEON, SMOOTH, SLATE, METAL = Enum.Material.Neon, Enum.Material.SmoothPlastic, Enum.Material.Slate, Enum.Material.Metal

local function part(parent, size, cf, color, mat, shape, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CastShadow = true, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or SMOOTH
	if shape then p.Shape = shape end
	p.Transparency = tr or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function circle(parent, radius, n, thick, color, cf, tr)
	cf = cf or CFrame.new()
	local seg = 2 * math.pi * radius / n * 1.05
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		part(parent, Vector3.new(thick, thick, seg), cf * CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))), color, NEON, nil, tr)
	end
end

local function dotted(parent, pts, color, size)
	for _, p in pts do part(parent, Vector3.one * (size or 0.35), CFrame.new(p), color, NEON, BALL) end
end

local function bezier(p0, p1, p2, p3, n)
	local out = {}
	for i = 0, n do
		local t = i / n
		local u = 1 - t
		out[#out + 1] = p0 * u ^ 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ^ 3
	end
	return out
end

local function satellite(parent, cf, s)
	s = s or 1
	part(parent, Vector3.new(1.2, 1.2, 1.2) * s, cf, rgb(225, 228, 235), METAL)
	part(parent, Vector3.new(0.9, 0.9, 1.25) * s, cf, rgb(214, 170, 60), Enum.Material.Foil)
	for side = -1, 1, 2 do
		part(parent, Vector3.new(2.4, 0.08, 0.9) * s, cf * CFrame.new(side * 1.9 * s, 0, 0), rgb(40, 80, 170), Enum.Material.Glass)
		part(parent, Vector3.new(0.7, 0.1, 0.1) * s, cf * CFrame.new(side * 0.8 * s, 0, 0), rgb(160, 160, 170), METAL)
	end
	part(parent, Vector3.new(0.12, 0.9, 0.9) * s, cf * CFrame.new(0, 0.7 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(240, 240, 240), SMOOTH, CYL)
end

local function earth(parent, r, cf)
	cf = cf or CFrame.new()
	local e = part(parent, Vector3.one * r * 2, cf, rgb(40, 110, 200), SMOOTH, BALL)
	-- continents: flattened green blobs on the surface
	local rnd = Random.new(7)
	for _ = 1, 9 do
		local d = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.7, 0.7), rnd:NextNumber(-1, 1)).Unit
		local s = r * rnd:NextNumber(0.7, 1.0)
		part(parent, Vector3.one * s, cf * CFrame.new(d * (r + 0.06 * r - s / 2)), rgb(76, 156, 84), SMOOTH, BALL)
	end
	part(parent, Vector3.one * r * 2.08, cf, rgb(255, 255, 255), SMOOTH, BALL, 0.82)
	return e
end

local function figure(parent, cf, color, glow)
	part(parent, Vector3.new(0.7, 1.6, 0.7), cf * CFrame.new(-0.4, 0.8, 0), color, SMOOTH)
	part(parent, Vector3.new(0.7, 1.6, 0.7), cf * CFrame.new(0.4, 0.8, 0), color, SMOOTH)
	part(parent, Vector3.new(1.7, 1.8, 0.9), cf * CFrame.new(0, 2.5, 0), color, SMOOTH)
	part(parent, Vector3.new(1.2, 0.3, 0.95), cf * CFrame.new(0, 2.9, 0), glow, NEON)
	part(parent, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 3.95, 0), color, SMOOTH, BALL)
	part(parent, Vector3.new(0.9, 0.3, 0.2), cf * CFrame.new(0, 4.0, -0.55), glow, NEON)
	part(parent, Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(-1.1, 2.4, 0), color, SMOOTH)
end

local SCENES = {}

-- craters --------------------------------------------------------------------------------------
local function craterBase(root, rimLit)
	part(root, Vector3.new(60, 1, 60), CFrame.new(0, -0.6, 0), rgb(120, 122, 130), SLATE)
	part(root, Vector3.new(0.4, 15, 15), CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 32, 40), SLATE, CYL)
	local n = 22
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 8.2, 0.9, math.sin(a) * 8.2)
		local sunSide = math.cos(a - math.rad(200)) -- sun comes from the back-left
		local col = rgb(70, 72, 82)
		if rimLit then col = sunSide > 0.2 and rgb(222, 214, 196) or rgb(84, 84, 92) end
		part(root, Vector3.new(2.6, 2.4, 2.2), CFrame.lookAt(pos, pos + Vector3.new(pos.X, 0, pos.Z)) * CFrame.Angles(math.rad(-28), 0, 0), col, SLATE)
	end
end

SCENES.crater_dark = function(root, vf)
	craterBase(root, false)
	-- ice glints in eternal shadow
	local rnd = Random.new(3)
	for _ = 1, 16 do
		local a, r = rnd:NextNumber(0, math.pi * 2), rnd:NextNumber(0, 5.5)
		part(root, Vector3.new(0.5, rnd:NextNumber(0.4, 1.1), 0.5), CFrame.new(math.cos(a) * r, 0.3, math.sin(a) * r) * CFrame.Angles(rnd:NextNumber(-0.5, 0.5), rnd:NextNumber(0, 3), rnd:NextNumber(-0.5, 0.5)), rgb(160, 225, 255), Enum.Material.Ice)
	end
	part(root, Vector3.new(0.12, 11, 11), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(90, 150, 210), NEON, CYL, 0.9)
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(40, 50, 80), rgb(120, 130, 160), Vector3.new(0.2, -0.3, 1)
	return CFrame.lookAt(Vector3.new(0, 15, 19), Vector3.new(0, -1, 0)), function(t, r) r:PivotTo(CFrame.Angles(0, t * 0.15, 0)) end
end

SCENES.crater_lit = function(root, vf)
	craterBase(root, true)
	-- solar mast on the sunlit rim
	local base = Vector3.new(math.cos(math.rad(200)) * 8.4, 2.1, math.sin(math.rad(200)) * 8.4)
	part(root, Vector3.new(0.3, 4, 0.3), CFrame.new(base + Vector3.new(0, 2, 0)), rgb(220, 220, 225), METAL)
	part(root, Vector3.new(3.4, 0.1, 2.2), CFrame.new(base + Vector3.new(0, 4.1, 0)) * CFrame.Angles(math.rad(35), math.rad(20), 0), rgb(40, 80, 170), Enum.Material.Glass)
	part(root, Vector3.one * 3.2, CFrame.new(-18, 9, -20), rgb(255, 230, 150), NEON, BALL)
	-- a little ice deep in the middle
	for i = 1, 4 do part(root, Vector3.new(0.4, 0.6, 0.4), CFrame.new(math.cos(i * 1.6) * 1.5, 0.25, math.sin(i * 1.6) * 1.5), rgb(160, 225, 255), Enum.Material.Ice) end
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(70, 72, 90), rgb(255, 240, 210), Vector3.new(0.8, -0.35, 0.5)
	return CFrame.lookAt(Vector3.new(0, 15, 19), Vector3.new(0, -1, 0)), function(t, r) r:PivotTo(CFrame.Angles(0, math.sin(t * 0.4) * 0.25, 0)) end
end

-- orbits ---------------------------------------------------------------------------------------
SCENES.geo = function(root, vf)
	local spin = Instance.new("Model") spin.Name = "Spin" spin.Parent = root
	earth(spin, 3.4)
	part(spin, Vector3.new(0.5, 0.5, 0.5), CFrame.new(3.5, 0, 0), rgb(255, 180, 60), NEON, BALL)
	circle(root, 9.5, 50, 0.14, rgb(110, 210, 255), nil, 0.25)
	satellite(spin, CFrame.new(9.5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.2)
	part(spin, Vector3.new(5.9, 0.06, 0.06), CFrame.new(6.5, 0, 0), rgb(255, 180, 60), NEON, nil, 0.4)
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(70, 80, 110), rgb(255, 255, 255), Vector3.new(-1, -0.4, -0.6)
	spin.WorldPivot = CFrame.new()
	return CFrame.lookAt(Vector3.new(0, 13, 24), Vector3.new(0, -1, 0)), function(t, r) spin:PivotTo(CFrame.Angles(0, -t * 0.5, 0)) end
end

SCENES.swarm = function(root, vf)
	local planet = Instance.new("Model") planet.Name = "Planet" planet.Parent = root
	earth(planet, 4)
	planet.WorldPivot = CFrame.new()
	circle(root, 6.5, 40, 0.12, rgb(110, 210, 255), nil, 0.3)
	local sats = {}
	for i = 1, 3 do
		local m = Instance.new("Model") m.Parent = root
		satellite(m, CFrame.new(), 0.55)
		m.WorldPivot = CFrame.new()
		sats[i] = m
	end
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(70, 80, 110), rgb(255, 255, 255), Vector3.new(-1, -0.4, -0.6)
	return CFrame.lookAt(Vector3.new(0, 10, 17), Vector3.new(0, -0.5, 0)), function(t)
		planet:PivotTo(CFrame.Angles(0, -t * 0.15, 0))
		for i, m in sats do
			local a = t * 1.1 + i * math.pi * 2 / 3
			m:PivotTo(CFrame.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5) * CFrame.Angles(0, -a, 0))
		end
	end
end

-- Mars landing sites --------------------------------------------------------------------------
local MARS, MARS_D = rgb(196, 108, 64), rgb(150, 74, 44)
local function lander(parent, cf)
	part(parent, Vector3.new(2, 1.2, 2), cf * CFrame.new(0, 1.4, 0), rgb(235, 235, 240), METAL)
	part(parent, Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(0, 2.25, 0), rgb(214, 170, 60), Enum.Material.Foil)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		part(parent, Vector3.new(0.18, 1.6, 0.18), cf * CFrame.new(math.cos(a) * 1.3, 0.7, math.sin(a) * 1.3) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4), rgb(160, 160, 170), METAL)
	end
end

SCENES.delta = function(root, vf)
	part(root, Vector3.new(40, 1, 40), CFrame.new(0, -0.5, 0), MARS, Enum.Material.Sand)
	part(root, Vector3.new(40, 6, 8), CFrame.new(0, 2.5, -12), MARS_D, Enum.Material.Rock)
	part(root, Vector3.new(14, 4, 5), CFrame.new(-11, 1.5, -7.5) * CFrame.Angles(0, 0.3, 0), MARS_D, Enum.Material.Rock)
	-- fan of dry river channels spreading from the cliff
	local rnd = Random.new(11)
	for k = -3, 3 do
		local pts = bezier(Vector3.new(k * 0.5, 0.05, -8), Vector3.new(k * 1.2, 0.05, -4), Vector3.new(k * 2.4, 0.05, 0), Vector3.new(k * 3.6 + rnd:NextNumber(-1, 1), 0.05, 7), 10)
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			part(root, Vector3.new(0.7, 0.12, (b - a).Magnitude + 0.2), CFrame.lookAt((a + b) / 2, b), rgb(110, 60, 40), Enum.Material.Sand)
		end
	end
	for _ = 1, 22 do
		part(root, Vector3.one * rnd:NextNumber(0.5, 1.6), CFrame.new(rnd:NextNumber(-14, 14), 0.2, rnd:NextNumber(-6, 10)), rgb(120, 70, 50), Enum.Material.Rock, BALL)
	end
	for _ = 1, 3 do part(root, Vector3.new(0.5, 0.5, 0.5), CFrame.new(rnd:NextNumber(-6, 6), 0.6, rnd:NextNumber(-4, 6)), rgb(120, 230, 255), NEON, BALL) end
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(110, 80, 70), rgb(255, 220, 190), Vector3.new(0.6, -0.6, 0.4)
	return CFrame.lookAt(Vector3.new(0, 13, 20), Vector3.new(0, 0, -1)), function(t, r) r:PivotTo(CFrame.Angles(0, math.sin(t * 0.35) * 0.2, 0)) end
end

SCENES.plain = function(root, vf)
	part(root, Vector3.new(40, 1, 40), CFrame.new(0, -0.5, 0), MARS, Enum.Material.Sand)
	circle(root, 4, 36, 0.18, rgb(255, 255, 255), CFrame.new(0, 0.05, 0), 0.1)
	circle(root, 2, 24, 0.18, rgb(255, 180, 60), CFrame.new(0, 0.05, 0), 0.1)
	lander(root, CFrame.new(0, 0, 0))
	local rnd = Random.new(5)
	for _ = 1, 6 do part(root, Vector3.one * rnd:NextNumber(0.3, 0.6), CFrame.new(rnd:NextNumber(-14, 14), 0.1, rnd:NextNumber(-8, 10)), rgb(130, 76, 52), Enum.Material.Rock, BALL) end
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(110, 80, 70), rgb(255, 220, 190), Vector3.new(0.6, -0.6, 0.4)
	return CFrame.lookAt(Vector3.new(0, 12, 18), Vector3.new(0, 0, 0)), function(t, r) r:PivotTo(CFrame.Angles(0, t * 0.2, 0)) end
end

-- routes to Jupiter ---------------------------------------------------------------------------
local function solar(root)
	part(root, Vector3.one * 3, CFrame.new(-14, 0, 0), rgb(255, 214, 110), NEON, BALL)
	local e = earth(root, 0.8, CFrame.new(-8, 0, 3))
	local j = part(root, Vector3.one * 4.4, CFrame.new(12, 0, -2), rgb(214, 160, 110), SMOOTH, BALL)
	for k = -2, 2 do
		local y = k * 0.75
		local d = 2 * math.sqrt(2.2 ^ 2 - y ^ 2) + 0.12
		part(root, Vector3.new(0.3, d, d), CFrame.new(12, y, -2) * CFrame.Angles(0, 0, math.pi / 2), k % 2 == 0 and rgb(176, 112, 74) or rgb(236, 204, 166), SMOOTH, CYL)
	end
	return e, j
end

local function routeScene(root, vf, pts, extra)
	local _ = solar(root)
	if extra then extra(root) end
	dotted(root, pts, rgb(120, 220, 255), 0.32)
	local probe = Instance.new("Model") probe.Parent = root
	satellite(probe, CFrame.new(), 0.35)
	probe.WorldPivot = CFrame.new()
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(60, 66, 90), rgb(255, 240, 220), Vector3.new(1, -0.3, 0)
	return CFrame.lookAt(Vector3.new(-1, 25, 21), Vector3.new(-1, -1, 1)), function(t)
		local k = (t * 0.18) % 1
		local idx = math.clamp(math.floor(k * (#pts - 1)) + 1, 1, #pts)
		probe:PivotTo(CFrame.new(pts[idx] + Vector3.new(0, 0.6, 0)))
	end
end

SCENES.route_direct = function(root, vf)
	return routeScene(root, vf, bezier(Vector3.new(-8, 0, 3), Vector3.new(-3, 0, 6), Vector3.new(5, 0, 4), Vector3.new(10, 0, -0.5), 26))
end

SCENES.route_ga = function(root, vf)
	local pts = {}
	for _, p in bezier(Vector3.new(-8, 0, 3), Vector3.new(-6, 0, 10), Vector3.new(0, 0, 9), Vector3.new(-2, 0, 4), 12) do pts[#pts + 1] = p end
	for _, p in bezier(Vector3.new(-2, 0, 4), Vector3.new(-5, 0, 0), Vector3.new(-10, 0, 6), Vector3.new(-7.5, 0, 5), 10) do pts[#pts + 1] = p end
	for _, p in bezier(Vector3.new(-7.5, 0, 5), Vector3.new(-2, 0, 11), Vector3.new(8, 0, 7), Vector3.new(10, 0, -0.5), 18) do pts[#pts + 1] = p end
	return routeScene(root, vf, pts, function(r)
		part(r, Vector3.one * 1.1, CFrame.new(-1.5, 0, 4.4), rgb(210, 100, 60), SMOOTH, BALL)
	end)
end

-- final choice --------------------------------------------------------------------------------
SCENES.hand = function(root, vf)
	part(root, Vector3.new(30, 1, 30), CFrame.new(0, -0.5, 0), rgb(40, 46, 60), METAL)
	circle(root, 6, 40, 0.15, rgb(110, 210, 255), CFrame.new(0, 0.05, 0), 0.2)
	figure(root, CFrame.new(-2.6, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), rgb(120, 200, 230), rgb(200, 250, 255))
	figure(root, CFrame.new(2.6, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), rgb(150, 50, 56), rgb(255, 110, 110))
	part(root, Vector3.new(4.2, 0.45, 0.45), CFrame.new(0, 2.7, 0), rgb(255, 230, 160), NEON)
	part(root, Vector3.one * 1.1, CFrame.new(0, 2.7, 0), rgb(255, 230, 160), NEON, BALL, 0.35)
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(80, 86, 110), rgb(255, 240, 220), Vector3.new(0.4, -0.6, -0.7)
	return CFrame.lookAt(Vector3.new(0, 6, 13), Vector3.new(0, 2.4, 0)), function(t, r) r:PivotTo(CFrame.Angles(0, math.sin(t * 0.5) * 0.35, 0)) end
end

SCENES.court = function(root, vf)
	part(root, Vector3.new(30, 1, 30), CFrame.new(0, -0.5, 0), rgb(40, 46, 60), METAL)
	part(root, Vector3.new(16, 0.8, 7), CFrame.new(0, 0.4, -5), rgb(210, 214, 222), SMOOTH)
	for x = -6, 6, 4 do part(root, Vector3.new(7, 0.9, 0.9), CFrame.new(x, 4.3, -6) * CFrame.Angles(0, 0, math.pi / 2), rgb(230, 232, 238), SMOOTH, CYL) end
	part(root, Vector3.new(16, 0.9, 4), CFrame.new(0, 8.2, -6), rgb(210, 214, 222), SMOOTH)
	part(root, Vector3.new(0.3, 2.6, 2.6), CFrame.new(0, 10, -6) * CFrame.Angles(0, math.pi / 2, math.pi / 2), rgb(110, 210, 255), NEON, CYL)
	figure(root, CFrame.new(0, 0, 2) * CFrame.Angles(0, math.pi, 0), rgb(150, 50, 56), rgb(255, 110, 110))
	circle(root, 2.4, 30, 0.15, rgb(110, 210, 255), CFrame.new(0, 0.05, 2), 0.1)
	vf.Ambient, vf.LightColor, vf.LightDirection = rgb(80, 86, 110), rgb(255, 240, 220), Vector3.new(0.4, -0.6, -0.7)
	return CFrame.lookAt(Vector3.new(0, 5.5, 15), Vector3.new(0, 4.2, -2)), function(t, r) r:PivotTo(CFrame.Angles(0, math.sin(t * 0.4) * 0.2, 0)) end
end

-- real game modules (camera, sensors, mirrors, computers) ------------------------------------
local function moduleScene(id)
	return function(root, vf)
		local src = RS.Nova:FindFirstChild("VoteModels") and RS.Nova.VoteModels:FindFirstChild(id)
		if not src then return nil end
		local m = src:Clone()
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
		m.Parent = root
		local cf, size = m:GetBoundingBox()
		local base = CFrame.new(-cf.Position) * m:GetPivot()
		m:PivotTo(base)
		local r = math.max(size.X, size.Y, size.Z)
		local glow = id == "vex_unit" and rgb(255, 120, 120) or rgb(255, 245, 230)
		vf.Ambient, vf.LightColor, vf.LightDirection = rgb(110, 115, 130), glow, Vector3.new(-0.6, -0.7, -0.5)
		return CFrame.lookAt(Vector3.new(r * 0.9, r * 0.55, r * 1.35), Vector3.zero), function(t) m:PivotTo(CFrame.Angles(0, t * 0.6, 0) * base) end
	end
end
for _, id in { "camera", "rad_sensor", "mirror_fold", "mirror_solid", "obc_hard", "vex_unit" } do SCENES[id] = moduleScene(id) end

-- mount a scene into a ViewportFrame; returns stop()
function A.mount(vf, art)
	local build = SCENES[art or ""]
	if not build then return function() end end
	local root = Instance.new("Model")
	root.Name = "Art"
	root.WorldPivot = CFrame.new()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	local ok, camCF, step = pcall(build, root, vf)
	if not ok or not camCF then root:Destroy() return function() end end
	cam.CFrame = camCF
	root.Parent = vf
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		if not vf.Parent then return end
		if step then pcall(step, os.clock() - t0, root) end
	end)
	return function() conn:Disconnect() end
end

A.SCENES = SCENES
return A
