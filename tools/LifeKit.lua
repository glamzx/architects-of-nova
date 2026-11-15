local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Props = game.ServerStorage.Nova.Props
local K = {}
local SUITS = {
	{ Color3.fromRGB(240, 130, 40), Color3.fromRGB(60, 64, 72) },
	{ Color3.fromRGB(235, 235, 240), Color3.fromRGB(60, 120, 200) },
	{ Color3.fromRGB(80, 170, 220), Color3.fromRGB(50, 54, 62) },
	{ Color3.fromRGB(250, 200, 60), Color3.fromRGB(60, 64, 72) },
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(196, 140, 100), Color3.fromRGB(141, 95, 64), Color3.fromRGB(255, 214, 180) }
local function weldTo(part, host, offset)
	part.Anchored = false; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.Massless = true
	part.CFrame = host.CFrame * offset
	local w = Instance.new("WeldConstraint"); w.Part0 = host; w.Part1 = part; w.Parent = part
	part.Parent = host.Parent
	return part
end
local function part(size, color, mat, shape)
	local p = Instance.new("Part"); if shape then p.Shape = shape end
	p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
function K.worker(parent, pos, yaw, role, seed, attrs)
	local rng = Random.new(seed or 1)
	local suit = SUITS[rng:NextInteger(1, #SUITS)]
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = SKIN[rng:NextInteger(1, #SKIN)]
	d.TorsoColor, d.LeftArmColor, d.RightArmColor = suit[1], suit[1], suit[1]
	d.LeftLegColor, d.RightLegColor = suit[2], suit[2]
	local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	m.Name = "Worker"
	for _, x in m:GetDescendants() do if x:IsA("Script") or x:IsA("LocalScript") then x:Destroy() end end
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, x in m:GetDescendants() do if x:IsA("BasePart") then x.CanCollide = false; x.CanQuery = false; x.CanTouch = false end end
	m.HumanoidRootPart.Anchored = true
	local head = m.Head
	local helmet = part(Vector3.new(1.45, 1.05, 1.45), Color3.fromRGB(245, 245, 245), nil, Enum.PartType.Ball); helmet.Name = "Helmet"
	weldTo(helmet, head, CFrame.new(0, 0.32, 0.02))
	local brim = part(Vector3.new(0.12, 1.55, 1.55), Color3.fromRGB(245, 245, 245), nil, Enum.PartType.Cylinder); brim.Name = "Brim"
	weldTo(brim, head, CFrame.new(0, 0.12, -0.1) * CFrame.Angles(0, 0, math.rad(90)))
	local band = part(Vector3.new(2.05, 0.22, 1.08), Color3.fromRGB(220, 225, 230), Enum.Material.SmoothPlastic); band.Name = "ReflectStripe"; band.Reflectance = 0.4
	weldTo(band, m.UpperTorso, CFrame.new(0, -0.15, 0))
	local pack = part(Vector3.new(1.3, 1.4, 0.5), Color3.fromRGB(70, 74, 82)); pack.Name = "Pack"
	weldTo(pack, m.UpperTorso, CFrame.new(0, 0.1, 0.75))
	if role == "welder" then
		local torch = part(Vector3.new(0.25, 0.25, 1.4), Color3.fromRGB(60, 60, 66), Enum.Material.Metal); torch.Name = "Torch"
		weldTo(torch, m.RightHand, CFrame.new(0, -0.2, -0.6))
		local tip = Instance.new("Attachment"); tip.Name = "SparkTip"; tip.Position = Vector3.new(0, 0, -0.75); tip.Parent = torch
		local visor = part(Vector3.new(1.1, 0.6, 0.15), Color3.fromRGB(40, 40, 46), Enum.Material.Glass); visor.Name = "WeldMask"
		weldTo(visor, head, CFrame.new(0, 0.05, -0.62))
	elseif role == "scanner" then
		local tab = part(Vector3.new(1.0, 0.7, 0.1), Color3.fromRGB(30, 34, 42)); tab.Name = "Tablet"
		weldTo(tab, m.LeftHand, CFrame.new(0.2, -0.1, -0.45) * CFrame.Angles(math.rad(-50), 0, 0))
		local scr = part(Vector3.new(0.85, 0.55, 0.02), Color3.fromRGB(96, 206, 216), Enum.Material.Neon); scr.Name = "Screen"
		weldTo(scr, tab, CFrame.new(0, 0, -0.06))
	elseif role == "carrier" then
		local crate = part(Vector3.new(1.8, 1.4, 1.4), Color3.fromRGB(60, 130, 210)); crate.Name = "Crate"
		weldTo(crate, m.UpperTorso, CFrame.new(0, -0.4, -1.2))
		local stripe = part(Vector3.new(1.82, 0.25, 1.42), Color3.fromRGB(250, 200, 60)); weldTo(stripe, crate, CFrame.new())
	elseif role == "checker" then
		local wr = part(Vector3.new(0.2, 1.1, 0.2), Color3.fromRGB(180, 182, 190), Enum.Material.Metal); wr.Name = "Wrench"
		weldTo(wr, m.RightHand, CFrame.new(0, -0.5, 0))
	end
	-- stand on pos (feet at pos.Y)
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, pos.Y - (cf.Position.Y - sz.Y / 2), 0))
	m:SetAttribute("NovaNPC", role)
	for k, v in attrs or {} do m:SetAttribute(k, v) end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CS:AddTag(m, "NovaLife")
	m.Parent = parent
	return m
end
function K.prop(name, parent, pos, height, yaw, attrs)
	local m = Props[name]:Clone()
	local cf, sz = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * (height / sz.Y))
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(pos.X, pos.Y + sz.Y / 2, pos.Z) - cf.Position))
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end end
	-- pivot at the model centre for client animation
	local root = Instance.new("Part"); root.Name = "LifeRoot"; root.Transparency = 1; root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Anchored = true; root.CanCollide = false; root.CanQuery = false; root.CanTouch = false
	cf, sz = m:GetBoundingBox(); root.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(yaw or 0), 0); root.Parent = m
	m.PrimaryPart = root
	for k, v in attrs or {} do m:SetAttribute(k, v) end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if attrs then CS:AddTag(m, "NovaLife") end
	m.Parent = parent
	return m
end
return K
