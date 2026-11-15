-- CinemaIntro: the cold open of "The Blackout". A short client-only 3D film far above the map (y = 9000):
-- the Sun erupts, a plasma wave crosses space and slams into Earth, the sky blazes with aurora fire,
-- city lights go out wave by wave, satellites spark and go dark, then silence.
-- Everything is created locally and destroyed afterwards. One clock drives it, so Skip can stop it on any frame.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local I = {}
I.LENGTH = 27.6

local O = Vector3.new(0, 9000, 0) -- Earth centre
local ER = 60                       -- Earth radius (studs)
local SUN_D, SUN_R = 1500, 150 -- particles stop drawing beyond ~1000 studs, so the Sun shot stays close
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local EARTH_MESH, EARTH_TEX = "rbxassetid://453515873", "rbxassetid://453515908"

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
local function cs(...)
	local a, k = { ... }, {}
	for i = 1, #a, 2 do table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1])) end
	return ColorSequence.new(k)
end
local function ns(...)
	local a, k = { ... }, {}
	for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(k)
end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function seg(t, a, b) return clamp01((t - a) / (b - a)) end
local function smooth(x) x = clamp01(x) return x * x * (3 - 2 * x) end
local function lerp(a, b, k) return a + (b - a) * k end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Neon
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
local function ball(parent, d, color, mat, tr, pos)
	return part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = color, Material = mat or Enum.Material.Neon, Transparency = tr or 0, CFrame = CFrame.new(pos) })
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission, e.LightInfluence = 1, 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end
-- soft round glow behind a sphere: concentric circles on a billboard (the sphere hides the middle)
local function halo(adornee, studs, color, alphas)
	local bb = Instance.new("BillboardGui")
	bb.Adornee, bb.Size, bb.LightInfluence, bb.MaxDistance = adornee, UDim2.fromScale(studs, studs), 0, 1e6
	local frames = {}
	for i, a in alphas do
		local k = 1 - (i - 1) / #alphas * 0.62
		local fr = Instance.new("Frame")
		fr.AnchorPoint, fr.Position, fr.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(k, k)
		fr.BackgroundColor3, fr.BackgroundTransparency, fr.BorderSizePixel = color, a, 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = fr
		fr.Parent = bb
		frames[i] = { fr, a }
	end
	bb.Parent = adornee
	return frames
end
local function setHalo(frames, k, color)
	for _, fr in frames do
		fr[1].BackgroundTransparency = 1 - (1 - fr[2]) * k
		if color then fr[1].BackgroundColor3 = color end
	end
end

------------------------------------------------------------------ lighting (client-local, restored afterwards)
local saved
local function lightSave()
	saved = { props = {}, fx = {} }
	for _, k in { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" } do
		pcall(function() saved.props[k] = Lighting[k] end)
	end
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") then saved.fx[c] = { Density = c.Density, Haze = c.Haze, Glare = c.Glare }
		elseif c:IsA("BloomEffect") then saved.fx[c] = { Intensity = c.Intensity, Size = c.Size, Threshold = c.Threshold }
		elseif c:IsA("DepthOfFieldEffect") or c:IsA("SunRaysEffect") or c:IsA("BlurEffect") then saved.fx[c] = { Enabled = c.Enabled }
		elseif c:IsA("ColorCorrectionEffect") then saved.fx[c] = { Contrast = c.Contrast, Saturation = c.Saturation, Brightness = c.Brightness, TintColor = c.TintColor } end
	end
end
local SPACE = { Ambient = c3(4, 5, 8), OutdoorAmbient = c3(8, 9, 12), Brightness = 3, ExposureCompensation = 0, EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0 }
local FXSET = {
	Atmosphere = { Density = 0, Haze = 0, Glare = 0 },
	BloomEffect = { Intensity = 1.1, Size = 36, Threshold = 0.85 },
	DepthOfFieldEffect = { Enabled = false }, SunRaysEffect = { Enabled = false }, BlurEffect = { Enabled = false },
	ColorCorrectionEffect = { Contrast = 0.08, Saturation = 0.06, Brightness = 0, TintColor = Color3.new(1, 1, 1) },
}
local function setIf(inst, k, v) if inst[k] ~= v then inst[k] = v end end
local function lightApply()
	for k, v in SPACE do pcall(setIf, Lighting, k, v) end
	for inst in saved.fx do
		local set = inst.Parent and FXSET[inst.ClassName]
		if set then for k, v in set do setIf(inst, k, v) end end
	end
end
local function lightRestore()
	if not saved then return end
	for k, v in saved.props do pcall(function() Lighting[k] = v end) end
	for inst, vals in saved.fx do if inst.Parent then for k, v in vals do inst[k] = v end end end
	saved = nil
end

------------------------------------------------------------------ the scene
local function satellite(parent, s)
	local m = { s = s }
	m.body = part(parent, { Size = Vector3.new(1.4, 1.4, 2.2) * s, Color = c3(206, 200, 188), Material = Enum.Material.Metal })
	m.p1 = part(parent, { Size = Vector3.new(4.6, 0.12, 1.7) * s, Color = c3(38, 66, 130), Material = Enum.Material.SmoothPlastic, Reflectance = 0.25 })
	m.p2 = part(parent, { Size = Vector3.new(4.6, 0.12, 1.7) * s, Color = c3(38, 66, 130), Material = Enum.Material.SmoothPlastic, Reflectance = 0.25 })
	m.dish = part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.2, 1.2) * s, Color = c3(230, 230, 230), Material = Enum.Material.SmoothPlastic })
	m.blink = part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4 * s, Color = c3(255, 70, 60) })
	m.fx = emitter(m.body, { Texture = SPARK, Rate = 0, Color = cs(0, c3(255, 255, 255), 0.4, c3(160, 210, 255), 1, c3(255, 150, 70)),
		Size = ns(0, 0.9 * s, 1, 0), Lifetime = NumberRange.new(0.3, 0.9), Speed = NumberRange.new(6 * s, 20 * s), SpreadAngle = Vector2.new(180, 180), Drag = 2 })
	m.light = Instance.new("PointLight")
	m.light.Color, m.light.Range, m.light.Brightness = c3(170, 210, 255), 14 * s, 0
	m.light.Parent = m.body
	return m
end
local function placeSat(m, cf)
	local s = m.s
	m.body.CFrame = cf
	m.p1.CFrame = cf * CFrame.new(3.1 * s, 0, 0)
	m.p2.CFrame = cf * CFrame.new(-3.1 * s, 0, 0)
	m.dish.CFrame = cf * CFrame.new(0, 0, -1.25 * s) * CFrame.Angles(0, math.rad(90), 0)
	m.blink.CFrame = cf * CFrame.new(0, 0.85 * s, 0.8 * s)
end

local function build(f, r, u)
	local sc = { f = f, r = r, u = u }
	local root = Instance.new("Folder")
	root.Name = "NovaIntroScene"
	sc.root = root
	local rng = Random.new(2089)
	local S = O + f * SUN_D
	sc.S = S
	sc.P = S - f * SUN_R -- flare point, facing Earth

	-- stars
	local stars = Instance.new("Folder")
	stars.Name = "Stars"
	for _ = 1, 460 do
		local d = rng:NextUnitVector()
		local tint = rng:NextNumber()
		part(stars, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(4, 10), Transparency = rng:NextNumber(0, 0.45),
			Color = tint < 0.15 and c3(190, 210, 255) or (tint > 0.9 and c3(255, 228, 190) or c3(245, 245, 250)), CFrame = CFrame.new(O + f * 700 + d * 3000) })
	end
	stars.Parent = root

	-- the Sun: hot core, boiling surface, corona rim, glow, prominences
	sc.sun = ball(root, SUN_R * 2, c3(215, 84, 14), nil, 0, S)
	sc.corona = ball(root, SUN_R * 2.04, c3(255, 120, 30), Enum.Material.ForceField, 0, S)
	local function sunFx(rate, color, tr, size)
		emitter(sc.sun, { Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Texture = FIRE, Rate = rate, Color = color, Transparency = tr, Size = size, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(4, 16),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25) })
	end
	sunFx(160, cs(0, c3(255, 120, 30), 1, c3(200, 40, 10)), ns(0, 1, 0.3, 0.6, 1, 1), ns(0, 20, 1, 45))          -- flames on the limb
	sunFx(220, cs(0, c3(255, 230, 150), 1, c3(255, 230, 150)), ns(0, 1, 0.4, 0.45, 1, 1), ns(0, 8, 0.5, 22, 1, 10)) -- boiling granules
	local holder = part(root, { Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(S) })
	sc.proms = {}
	for i, a in { 0.35, 1.9, 3.4, 4.95 } do
		local function n(x) return (r * math.cos(x) + u * math.sin(x)).Unit end
		local n0, n1 = n(a - 0.09), n(a + 0.09)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = holder, holder
		a0.WorldCFrame = CFrame.fromMatrix(S + n0 * SUN_R * 0.98, n0, n0:Cross(f).Unit)
		a1.WorldCFrame = CFrame.fromMatrix(S + n1 * SUN_R * 0.98, n1, n1:Cross(f).Unit)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.CurveSize0, b.CurveSize1 = 90 + i * 10, -(90 + i * 10)
		b.Width0, b.Width1, b.FaceCamera, b.Segments, b.LightEmission, b.LightInfluence = 12, 12, true, 24, 1, 0
		b.Color = cs(0, c3(255, 120, 40), 0.5, c3(255, 210, 120), 1, c3(255, 120, 40))
		b.Transparency = ns(0, 0.5, 0.5, 0.1, 1, 0.5)
		b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = SMOKE, Enum.TextureMode.Wrap, 50, 0.4
		b.Parent = holder
		sc.proms[i] = b
	end
	-- flare + coronal mass ejection
	sc.flare = ball(root, 10, c3(255, 250, 225), nil, 1, sc.P)
	sc.cme = ball(root, 40, c3(255, 130, 40), Enum.Material.ForceField, 1, sc.P)
	sc.burstPart = part(root, { Transparency = 1, Size = Vector3.new(50, 50, 2), CFrame = CFrame.lookAt(sc.P, sc.P - f) })
	sc.burst = emitter(sc.burstPart, { Texture = SPARK, Rate = 0, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(38, 38),
		Speed = NumberRange.new(120, 320), Lifetime = NumberRange.new(1.4, 2.6), Size = ns(0, 6, 1, 1.5), Color = cs(0, c3(255, 245, 200), 0.5, c3(255, 150, 50), 1, c3(220, 60, 20)),
		Transparency = ns(0, 0, 0.7, 0.3, 1, 1), Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2.4, 1, 2.4) })

	-- the plasma wave (shell + sparks thrown ahead of it)
	sc.wave = ball(root, 1000, c3(255, 110, 40), Enum.Material.ForceField, 1, O + f * 2000)
	sc.plate = part(root, { Transparency = 1, Size = Vector3.new(900, 900, 4), CFrame = CFrame.new(O + f * 2000) })
	sc.plateFx = emitter(sc.plate, { Texture = SPARK, Rate = 260, Enabled = false, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(6, 6),
		Speed = NumberRange.new(260, 420), Lifetime = NumberRange.new(1.2, 2.2), Size = ns(0, 14, 1, 4), Color = cs(0, c3(255, 230, 170), 1, c3(255, 110, 40)),
		Transparency = ns(0, 0.1, 1, 1), Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2.8, 1, 2.8) })

	-- Earth: textured globe (blue ball underneath in case the texture is slow), atmosphere rim, fire layers
	sc.ocean = ball(root, ER * 1.99, c3(24, 62, 128), Enum.Material.SmoothPlastic, 0, O)
	sc.earth = part(root, { Size = Vector3.one * 2, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.fromMatrix(O, r, u) * CFrame.Angles(math.rad(-18), math.rad(140), 0) })
	sc.mesh = Instance.new("SpecialMesh")
	sc.mesh.MeshType, sc.mesh.MeshId, sc.mesh.TextureId, sc.mesh.Scale = Enum.MeshType.FileMesh, EARTH_MESH, EARTH_TEX, Vector3.one * ER
	sc.mesh.Parent = sc.earth
	-- night side: an opaque dark dome of thin panels (this place's sky light would otherwise light the night side),
	-- softened near the terminator; city lights sit just above it
	local dome = Instance.new("Folder")
	dome.Name = "Night"
	local na = -f
	local e1 = na:Cross(u).Magnitude > 0.1 and na:Cross(u).Unit or r
	local e2 = na:Cross(e1).Unit
	local DR = ER + 0.14
	for band = 0, 9 do
		local th0, th1 = math.rad(band * 9.5), math.rad((band + 1) * 9.5)
		local thc = (th0 + th1) / 2
		local n = math.max(6, math.floor(40 * math.sin(thc) + 0.5))
		local tr = band <= 7 and 0 or (band == 8 and 0.35 or 0.7)
		for k = 0, n - 1 do
			local ph = (k + 0.5) / n * math.pi * 2
			local d = (na * math.cos(thc) + (e1 * math.cos(ph) + e2 * math.sin(ph)) * math.sin(thc)).Unit
			local tph = (e2 * math.cos(ph) - e1 * math.sin(ph)).Unit
			local w = DR * math.sin(thc) * (math.pi * 2 / n) * 1.12 + 0.3
			local h = DR * (th1 - th0) * 1.12
			part(dome, { Size = Vector3.new(w, 0.1, h), Color = c3(3, 4, 7), Material = Enum.Material.SmoothPlastic, Transparency = tr, CFrame = CFrame.fromMatrix(O + d * DR, tph, d) })
		end
	end
	dome.Parent = root
	sc.atmo = ball(root, ER * 2.07, c3(90, 160, 255), Enum.Material.ForceField, 0.1, O)
	sc.burn = ball(root, ER * 2.14, c3(255, 80, 30), Enum.Material.ForceField, 1, O)
	sc.fireShell = ball(root, ER * 2.2, c3(0, 0, 0), nil, 1, O) -- outside every ForceField shell (they hide particles behind them)
	sc.fire = emitter(sc.fireShell, { Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Texture = FIRE, Rate = 0, Color = cs(0, c3(255, 225, 140), 0.45, c3(255, 100, 35), 1, c3(170, 25, 12)), Size = ns(0, 4, 0.4, 9, 1, 2),
		Transparency = ns(0, 0.25, 0.7, 0.6, 1, 1), Lifetime = NumberRange.new(0.7, 1.5), Speed = NumberRange.new(2, 7), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40) })
	sc.bow = ball(root, ER * 3.1, c3(255, 140, 60), Enum.Material.ForceField, 1, O + f * 18)
	sc.hit = ball(root, 10, c3(255, 245, 220), nil, 1, O + f * ER)

	-- aurora crowns over both poles (outside the shells so nothing hides the particles)
	sc.aurora = {}
	for _, pole in { 1, -1 } do
		local disc = part(root, { Shape = Enum.PartType.Cylinder, Transparency = 1, Size = Vector3.new(2, ER * 1.05, ER * 1.05), CFrame = CFrame.fromMatrix(O + u * pole * (ER * 1.08), u * pole, r) })
		table.insert(sc.aurora, emitter(disc, { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Right,
			Texture = FIRE, Rate = 0, Color = cs(0, c3(255, 90, 40), 0.5, c3(255, 175, 70), 1, c3(200, 40, 20)), Size = ns(0, 3, 0.5, 6.5, 1, 0),
			Transparency = ns(0, 1, 0.2, 0.3, 1, 1), Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(25, 25),
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 1.2, 1, 1.2) }))
	end

	-- city lights on the night side (clusters), each with its own switch-off time
	local cityF = Instance.new("Folder")
	cityF.Name = "Cities"
	sc.lights = {}
	local lo, hi = math.huge, -math.huge
	for _ = 1, 34 do
		local c
		repeat c = rng:NextUnitVector() until c:Dot(f) < -0.18 and math.abs(c:Dot(u)) < 0.8
		local tA = c:Cross(u)
		tA = tA.Magnitude > 0.01 and tA.Unit or r
		local tB = c:Cross(tA).Unit
		for _ = 1, rng:NextInteger(5, 12) do
			local n = (c + tA * rng:NextNumber(-0.07, 0.07) + tB * rng:NextNumber(-0.05, 0.05)).Unit
			local p = part(cityF, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.45, 0.95), Color = c3(255, 200, 125), CFrame = CFrame.new(O + n * (ER + 0.7)) })
			local x = n:Dot(r)
			lo, hi = math.min(lo, x), math.max(hi, x)
			table.insert(sc.lights, { p = p, x = x, seed = rng:NextNumber(0, 10), on = true })
		end
	end
	for _, L in sc.lights do L.off = 20.8 + (L.x - lo) / math.max(hi - lo, 0.01) * 3.4 + math.noise(L.seed) * 0.4 end
	cityF.Parent = root

	-- satellites: six on orbits (die after the impact), one close to the camera in the last shot
	local satF = Instance.new("Folder")
	satF.Name = "Satellites"
	sc.sats = {}
	local dies = { 14.0, 14.45, 14.9, 15.4, 16.0, 16.6 }
	for i = 1, 6 do
		local axis = (u * rng:NextNumber(-0.6, 0.6) + r * rng:NextNumber(-1, 1) + f * rng:NextNumber(-1, 1)).Unit
		local A = axis:Cross(u)
		A = A.Magnitude > 0.05 and A.Unit or r
		local B = axis:Cross(A).Unit
		table.insert(sc.sats, { m = satellite(satF, 1), A = A, B = B, R = ER * rng:NextNumber(1.42, 1.75), th = rng:NextNumber(0, math.pi * 2), w = rng:NextNumber(0.12, 0.24) * (i % 2 == 0 and 1 or -1), die = dies[i], spin = 0 })
	end
	sc.near = { m = satellite(satF, 1.7), die = 21.0, spin = 0 }
	satF.Parent = root
	return sc
end

------------------------------------------------------------------ per-frame state
local function update(sc, t, dt)
	local f, r, u = sc.f, sc.r, sc.u
	-- prominences breathe
	for i, b in sc.proms do
		local w = 12 * (0.8 + 0.2 * math.sin(t * 1.3 + i * 1.7))
		b.Width0, b.Width1 = w, w
	end
	-- flare flash
	if t >= 4.2 and t <= 5.8 then
		local k = smooth(seg(t, 4.2, 5.2))
		sc.flare.Size = Vector3.one * lerp(6, 230, k)
		sc.flare.Transparency = seg(t, 4.45, 5.8)
	else
		sc.flare.Transparency = 1
	end
	-- coronal mass ejection bubble leaving the Sun
	if t >= 4.3 and t <= 7.6 then
		local k = seg(t, 4.3, 7.4)
		local rad = lerp(20, 130, k ^ 0.8)
		sc.cme.Size = Vector3.one * rad * 2
		sc.cme.CFrame = CFrame.new(sc.P - f * (rad * 0.9 + lerp(0, 60, k)))
		sc.cme.Transparency = lerp(0.05, 0.45, k)
	else
		sc.cme.Transparency = 1
	end
	sc.burst.Rate = (t >= 4.2 and t <= 7.2) and 150 or 0
	-- the wave crossing to Earth
	local k = seg(t, 7.4, 13.6)
	local front = t <= 13.6 and lerp(1200, ER, k ^ 1.25) or (ER - (t - 13.6) * 300)
	local R = lerp(420, 1000, k)
	sc.wave.Size = Vector3.one * R * 2
	sc.wave.CFrame = CFrame.new(O + f * (front + R))
	local wt = 1 - 0.82 * seg(t, 7.4, 8.3)
	if t > 13.6 then wt = lerp(wt, 1, seg(t, 13.6, 14.3)) end
	sc.wave.Transparency = (t < 7.4 or t > 14.3) and 1 or wt
	sc.plate.CFrame = CFrame.lookAt(O + f * front, O + f * (front - 10))
	sc.plateFx.Enabled = t >= 7.4 and t <= 13.5

	-- impact and burning sky
	local burn = smooth(seg(t, 13.6, 14.8)) * (1 - 0.72 * smooth(seg(t, 24.6, 27.2)))
	local hot = smooth(seg(t, 13.6, 14.3))
	sc.atmo.Color = c3(90, 160, 255):Lerp(c3(255, 110, 45), hot)
	sc.burn.Transparency = 1 - 0.72 * burn * (0.85 + 0.15 * math.sin(t * 6.3))
	sc.fire.Rate = t < 13.6 and 0 or (1100 * (1 - seg(t, 13.6, 15.5)) + 650 * burn) * (1 - seg(t, 24.6, 27))
	sc.mesh.VertexColor = Vector3.new(1, lerp(1, 0.8, burn), lerp(1, 0.68, burn))
	for _, e in sc.aurora do e.Rate = 260 * burn end
	local bs = smooth(seg(t, 13.25, 13.7)) * (1 - smooth(seg(t, 14.1, 14.9))) -- brief: it would hide the fire particles
	sc.bow.Transparency = 1 - 0.65 * bs * (0.75 + 0.25 * math.sin(t * 15))
	if t >= 13.6 and t <= 14.8 then
		local hk = seg(t, 13.6, 14.8)
		sc.hit.Size = Vector3.one * lerp(10, 180, hk ^ 0.5)
		sc.hit.Transparency = lerp(0.25, 1, hk)
	else
		sc.hit.Transparency = 1
	end

	-- city lights: a power surge at the impact, then they go out wave by wave
	for i, L in sc.lights do
		local on
		if t >= L.off then on = false
		elseif t >= L.off - 0.45 then on = math.floor(t * 22 + i * 1.7) % 3 ~= 0
		elseif t >= 13.7 and t <= 14.4 then on = math.floor(t * 18 + L.seed * 7) % 2 == 0
		else on = true end
		if on ~= L.on then L.on = on L.p.Transparency = on and 0 or 1 end
	end

	-- satellites
	local function satState(s, cf)
		local alive = t < s.die
		if not alive then s.spin += dt * 1.4 end
		placeSat(s.m, cf * CFrame.Angles(s.spin * 0.7, s.spin, s.spin * 0.3))
		s.m.blink.Transparency = (alive and (t * 1.3 + s.m.s) % 1 < 0.18) and 0 or 1
		if not alive and not s.dead then
			s.dead = true
			s.m.fx:Emit(70)
			for _, p in { s.m.p1, s.m.p2 } do p.Color, p.Reflectance = c3(34, 26, 24), 0 end
			s.m.body.Color = c3(70, 64, 60)
		end
		s.m.light.Brightness = (t >= s.die and t < s.die + 0.6) and 7 * (1 - seg(t, s.die, s.die + 0.6)) or 0
	end
	for _, s in sc.sats do
		local th = s.th + s.w * t
		local pos = O + (s.A * math.cos(th) + s.B * math.sin(th)) * s.R
		satState(s, CFrame.lookAt(pos, O, u))
	end
	local nk = seg(t, 19.6, 27.6)
	local npos = O - f * 118 + r * lerp(-34, 30, nk) + u * lerp(30, 20, nk)
	satState(sc.near, CFrame.lookAt(npos, O, u) * CFrame.Angles(0.3, 0.8, 0))
end

------------------------------------------------------------------ play
-- env: cam, t(key), caption(text, color, size), captionOut(), fadeTo(a, t), audio, shakeOK(), F, accent, onDone()
function I.play(env)
	local cam = env.cam
	local A = env.audio
	local ACC = env.accent or c3(224, 60, 49)
	local f = Lighting:GetSunDirection()
	if f.Magnitude < 0.5 then f = Vector3.new(0.3, 0.8, -0.5).Unit end
	f = f.Unit
	local ref = math.abs(f.Y) > 0.92 and Vector3.xAxis or Vector3.yAxis
	local r = f:Cross(ref).Unit
	local u = r:Cross(f).Unit

	lightSave()
	local sc = build(f, r, u)
	sc.root.Parent = workspace
	local S = sc.S

	-- overlay: white flash between the letterbox bars + a small mission label in the top bar
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "NovaIntroFX", true, false, 21
	local flashF = Instance.new("Frame")
	flashF.BackgroundColor3, flashF.BackgroundTransparency, flashF.BorderSizePixel = Color3.new(1, 1, 1), 1, 0
	flashF.Position, flashF.Size = UDim2.fromScale(0, 0.11), UDim2.fromScale(1, 0.78)
	flashF.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.AnchorPoint, label.Position, label.Size = 1, Vector2.new(0, 0.5), UDim2.new(0, 48, 0.055, 0), UDim2.new(0.6, 0, 0, 18)
	label.FontFace = (env.F and (env.F.label or env.F.display)) or Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	label.TextSize, label.TextColor3, label.TextXAlignment, label.TextTransparency = 13, Color3.new(1, 1, 1), Enum.TextXAlignment.Left, 1
	label.Text = env.spaced and env.spaced(string.upper(env.t("cine_label"))) or string.upper(env.t("cine_label"))
	label.Parent = gui
	local dot = Instance.new("Frame")
	dot.AnchorPoint, dot.Position, dot.Size, dot.BackgroundColor3, dot.BorderSizePixel, dot.BackgroundTransparency = Vector2.new(0, 0.5), UDim2.new(0, 32, 0.055, 0), UDim2.fromOffset(7, 7), ACC, 0, 1
	dot.Parent = gui
	gui.Parent = pg
	local flashA, flashT0, flashDur = 0, -10, 1
	local function flash(a, d) flashA, flashT0, flashDur = a, nil, d end

	-- camera: four shots, eased
	local shots = {
		{ t0 = 0, t1 = 7.4, a = { S - f * 430 + r * 150 + u * 50, S + r * 45 }, b = { S - f * 360 + r * 120 + u * 40, S + r * 35 }, fov = { 48, 44 } },
		{ t0 = 7.4, t1 = 12.4, a = { O - f * 195 + r * 122 + u * 42, O + f * 900 + r * 60 }, b = { O - f * 165 + r * 102 + u * 34, O + f * 900 + r * 32 }, fov = { 62, 58 } },
		{ t0 = 12.4, t1 = 19.6, a = { O + r * 255 + u * 42 + f * 12, O + f * 14 }, b = { O + r * 205 - f * 95 + u * 72, O - f * 6 }, fov = { 54, 54 } },
		{ t0 = 19.6, t1 = 27.6, a = { O - f * 182 + r * 60 + u * 64, O - f * 15 + u * 4 }, b = { O - f * 150 + r * 36 + u * 46, O - f * 22 }, fov = { 50, 46 } },
	}
	local function camAt(t)
		local s = shots[#shots]
		for _, sh in shots do if t < sh.t1 then s = sh break end end
		local k = smooth(seg(t, s.t0, s.t1))
		return CFrame.lookAt(s.a[1]:Lerp(s.b[1], k), s.a[2]:Lerp(s.b[2], k), u), lerp(s.fov[1], s.fov[2], k)
	end
	local shakes = {}
	local function addShake(t0, dur, amp) table.insert(shakes, { t0, dur, amp }) end
	local function shakeAt(t)
		if env.shakeOK and not env.shakeOK() then return CFrame.identity end
		local a = 0
		for _, s in shakes do if t >= s[1] and t < s[1] + s[2] then a += s[3] * (1 - (t - s[1]) / s[2]) end end
		if a <= 0 then return CFrame.identity end
		return CFrame.Angles(math.noise(t * 17, 1.7) * a * 0.03, math.noise(t * 17, 9.1) * a * 0.03, math.noise(t * 9, 4.4) * a * 0.012)
	end

	local storm
	local function cap(key, color) env.caption(env.t(key), color, 30) end
	local events = {
		{ 0.05, function() A.music("intro") storm = A.sfx("storm", nil, 0.55) end },
		{ 0.6, function() game:GetService("TweenService"):Create(label, TweenInfo.new(1), { TextTransparency = 0.15 }):Play() dot.BackgroundTransparency = 0 end },
		{ 1.0, function() cap("cine_1") end },
		{ 3.9, env.captionOut },
		{ 4.2, function() A.sfx("thump", nil, 0.75) A.sfx("crackle2", nil, 0.45) sc.burst:Emit(260) addShake(4.2, 1.4, 0.6) flash(0.5, 0.9) end },
		{ 4.8, function() cap("cine_2") end },
		{ 7.25, env.captionOut },
		{ 7.5, function() A.sfx("plasma", nil, 0.75) end },
		{ 8.3, function() cap("cine_3") end },
		{ 11.0, function() A.sfx("plasma", nil, 0.5, { speed = 0.85 }) end },
		{ 11.9, env.captionOut },
		{ 13.6, function() A.sfx("impact", nil, 0.85) A.sfx("thump", nil, 0.9) addShake(13.6, 1.9, 1) flash(0.65, 1.2) end },
		{ 14.1, function() A.sfx("crackle", nil, 0.4) end },
		{ 14.6, function() cap("cine_4") end },
		{ 15.0, function() A.sfx("crackle", nil, 0.35, { speed = 1.1 }) end },
		{ 16.1, function() A.sfx("crackle2", nil, 0.3) end },
		{ 18.8, env.captionOut },
		{ 20.3, function() cap("cine_5") end },
		{ 21.0, function() A.sfx("crackle", nil, 0.35) addShake(21, 0.5, 0.2) end },
		{ 22.4, function() A.sfx("crackle", nil, 0.22, { speed = 0.9 }) end },
		{ 23.6, function() A.sfx("crackle", nil, 0.18, { speed = 0.8 }) end },
		{ 24.4, env.captionOut },
		{ 24.6, function() A.music(nil, 2.6) A.stopSfx(storm, 2.8) end },
		{ 25.2, function() cap("cine_6", ACC) end },
		{ 26.9, function() env.captionOut() env.fadeTo(1, 0.6) end },
	}

	local t0, last, ev, finished = os.clock(), os.clock(), 1, false
	local ctl = {}
	local function finish(natural)
		if finished then return end
		finished = true
		pcall(function() RunService:UnbindFromRenderStep("NovaIntro") end)
		pcall(function() A.stopSfx(storm, 0.5) end)
		pcall(function() sc.root:Destroy() end)
		pcall(function() gui:Destroy() end)
		pcall(lightRestore)
		if natural and env.onDone then task.spawn(env.onDone) end
	end
	RunService:BindToRenderStep("NovaIntro", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		local t, dt = now - t0, math.min(now - last, 0.1)
		last = now
		local dbg = workspace:GetAttribute("NovaIntroDebugT") -- Studio preview only: freezes the clock
		if typeof(dbg) == "number" then t = dbg end
		local ok, err = pcall(function()
			lightApply()
			cam.CameraType = Enum.CameraType.Scriptable
			local cf, fov = camAt(t)
			cam.CFrame = cf * shakeAt(t)
			cam.FieldOfView = fov
			update(sc, t, dt)
			if flashT0 == nil then flashT0 = now end
			flashF.BackgroundTransparency = 1 - flashA * (1 - seg(now, flashT0, flashT0 + flashDur))
			label.TextTransparency = t > 26.4 and lerp(0.15, 1, seg(t, 26.4, 27.2)) or label.TextTransparency
			while events[ev] and events[ev][1] <= t do
				local fn = events[ev][2]
				ev += 1
				task.spawn(fn)
			end
		end)
		if not ok then warn("[NovaIntro] " .. tostring(err)) finish(true) return end
		if t >= I.LENGTH then finish(true) end
	end)
	ctl.stop = function() finish(false) end
	return ctl
end

return I
