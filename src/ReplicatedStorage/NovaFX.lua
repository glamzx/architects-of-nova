-- NovaFX: client-side visual effects built from the VFX mesh library (ReplicatedStorage.NovaVFX).
-- Purely cosmetic: nothing here touches game state. Safe to call from any LocalScript.
--   FX.ring(pos, color, radius, time)           ground shockwave ring
--   FX.blast(pos, color, size, time)            bright expanding burst
--   FX.swirl(cf, color, size, time, spins)      rotating swirl (holograms, portals)
--   FX.sparks(part, time)                       electric crackle on a part (emergencies)
--   FX.launch(pos)                              rocket ignition: rings + flash + dust
--   FX.install(pos, color)                      module snaps in: small ring + flash
--   FX.warp(camera, time)                       hyperspace tunnel around the camera
--   FX.glitch(pos, time)                        red glitch (Vex transmissions)
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local lib = RS:WaitForChild("NovaVFX")

local FX = {}
local holder = workspace:FindFirstChild("ClientFX")
if not holder then
	holder = Instance.new("Folder")
	holder.Name = "ClientFX"
	holder.Parent = workspace
end

local function firstPart(inst)
	if inst:IsA("BasePart") then return inst end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

-- clone a mesh from a group; prefer a named one
local function pick(group, name)
	local f = lib:FindFirstChild(group)
	if not f then return nil end
	local src = name and f:FindFirstChild(name) or f:GetChildren()[math.random(1, #f:GetChildren())]
	if not src then return nil end
	local p = firstPart(src)
	if not p then return nil end
	local c = p:Clone()
	for _, ch in c:GetChildren() do
		if not (ch:IsA("Decal") or ch:IsA("Texture") or ch:IsA("SpecialMesh") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
	end
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.Parent = holder
	return c
end

local function fade(part, t, toSize, toCF)
	local goal = { Transparency = 1 }
	if toSize then goal.Size = toSize end
	if toCF then goal.CFrame = toCF end
	TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal):Play()
	for _, d in part:GetChildren() do
		if d:IsA("Decal") or d:IsA("Texture") then TweenService:Create(d, TweenInfo.new(t), { Transparency = 1 }):Play() end
	end
	Debris:AddItem(part, t + 0.1)
end

local function tint(part, color, mat)
	part.Color = color
	part.Material = mat or Enum.Material.Neon
	if part:IsA("MeshPart") then part.TextureID = "" end
end

function FX.ring(pos, color, radius, t)
	local p = pick("Rings", "Shockwave") or pick("Rings")
	if not p then return end
	radius = radius or 12
	t = t or 0.9
	tint(p, color or Color3.fromRGB(255, 190, 110))
	p.Transparency = 0.15
	p.Size = Vector3.new(1, 0.2, 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
	fade(p, t, Vector3.new(radius * 2, 0.6, radius * 2))
end

function FX.blast(pos, color, size, t)
	local p = pick("Blasts", "FancySphere") or pick("Blasts")
	if not p then return end
	size = size or 10
	t = t or 0.6
	tint(p, color or Color3.fromRGB(255, 220, 170))
	p.Transparency = 0.1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	fade(p, t, Vector3.new(size, size, size))
end

function FX.swirl(cf, color, size, t, spins)
	local p = pick("Swirls", "Swirl") or pick("Swirls")
	if not p then return end
	size = size or 8
	t = t or 2
	tint(p, color or Color3.fromRGB(120, 210, 230))
	p.Transparency = 0.35
	p.Size = Vector3.new(size, size * 0.3, size)
	p.CFrame = cf
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a) if p.Parent then p.CFrame = cf * CFrame.Angles(0, a, 0) end end)
	TweenService:Create(v, TweenInfo.new(t, Enum.EasingStyle.Linear), { Value = math.pi * 2 * (spins or 1) }):Play()
	fade(p, t)
	Debris:AddItem(v, t + 0.1)
end

function FX.sparks(part, t)
	t = t or 0.5
	local p = pick("Electric", "ThunderSpark") or pick("Electric")
	if not p then return end
	tint(p, Color3.fromRGB(150, 210, 255))
	p.Transparency = 0.1
	local s = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	p.Size = Vector3.new(s, s, s) * 0.8
	p.CFrame = part.CFrame * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	fade(p, t, p.Size * 1.3)
end

function FX.install(pos, color)
	FX.ring(pos, color or Color3.fromRGB(255, 190, 110), 5, 0.6)
	FX.blast(pos, Color3.fromRGB(255, 240, 220), 4, 0.35)
end

function FX.launch(pos)
	for i = 0, 3 do
		task.delay(i * 0.25, function() FX.ring(pos, Color3.fromRGB(255, 200, 150), 18 + i * 10, 1.4) end)
	end
	FX.blast(pos + Vector3.new(0, 3, 0), Color3.fromRGB(255, 210, 160), 22, 0.8)
	local dust = pick("Swirls", "Tornado")
	if dust then
		tint(dust, Color3.fromRGB(190, 180, 170), Enum.Material.SmoothPlastic)
		dust.Transparency = 0.5
		dust.Size = Vector3.new(10, 6, 10)
		dust.CFrame = CFrame.new(pos)
		fade(dust, 3, Vector3.new(70, 12, 70))
	end
end

function FX.glitch(pos, t)
	local p = pick("Electric", "Glitch") or pick("Electric")
	if not p then return end
	tint(p, Color3.fromRGB(236, 80, 80))
	p.Transparency = 0.2
	p.Size = Vector3.new(6, 9, 6)
	p.CFrame = CFrame.new(pos)
	fade(p, t or 0.4, p.Size * 1.2)
end

-- Hyperspace tunnel: streaking stars + a spinning swirl tube around the camera. Returns a stop function.
function FX.warp(camera, t)
	local parts = {}
	local alive = true
	local tube = pick("Swirls", "Tornado")
	if tube then
		tint(tube, Color3.fromRGB(150, 190, 255))
		tube.Transparency = 0.6
		tube.Size = Vector3.new(60, 260, 60)
		table.insert(parts, tube)
	end
	local streaks = {}
	for i = 1, 70 do
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CastShadow = false
		s.Material = Enum.Material.Neon
		s.Color = (i % 4 == 0) and Color3.fromRGB(255, 210, 160) or Color3.fromRGB(200, 220, 255)
		s.Size = Vector3.new(0.15, 0.15, math.random(8, 22))
		s.Parent = holder
		streaks[i] = { part = s, a = math.random() * math.pi * 2, r = math.random(6, 26), z = math.random(-160, 0) }
		table.insert(parts, s)
	end
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not alive then return end
		local cf = camera.CFrame
		if tube then tube.CFrame = cf * CFrame.new(0, 0, -60) * CFrame.Angles(math.rad(90), os.clock() * 2, 0) end
		for _, st in streaks do
			st.z += dt * 260
			if st.z > 10 then st.z = -160 end
			st.part.CFrame = cf * CFrame.new(math.cos(st.a) * st.r, math.sin(st.a) * st.r, st.z)
		end
	end)
	local function stop()
		if not alive then return end
		alive = false
		conn:Disconnect()
		for _, p in parts do fade(p, 0.4) end
	end
	if t then task.delay(t, stop) end
	return stop
end

return FX
