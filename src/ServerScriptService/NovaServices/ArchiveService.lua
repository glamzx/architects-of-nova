-- ArchiveService: Pioneers' Archive. Each completed mission unlocks a memory core
-- (a real NASA fact) with a rarity. Exhibits are generated from mission data.
local RS = game:GetService("ReplicatedStorage")
local Missions = require(RS.Nova.Data.Missions)

local Citadel = workspace:WaitForChild("Citadel")
local A = {}
local Mission

local RARITY = {
	common = Color3.fromRGB(205, 210, 220),
	rare = Color3.fromRGB(110, 200, 220),
	legendary = Color3.fromRGB(255, 190, 80),
}

local function part(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	if shape then p.Shape = shape end
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function A.init(mission)
	Mission = mission
	local arch = Citadel.Archive
	local old = arch:FindFirstChild("Exhibits")
	if old then
		for _, c in old:GetChildren() do
			if c.Name ~= "ECHO" then c:Destroy() end
		end
	end
	local folder = old or Instance.new("Model")
	folder.Name = "Exhibits"
	folder.Parent = arch
	local cores = {}
	local n = #Missions.order
	for i, id in Missions.order do
		local m = Missions.byId[id]
		local a = math.rad(-70 + (i - 1) * (140 / math.max(n - 1, 1)))
		local pos = Vector3.new(-105 - math.cos(a) * 17, 0, math.sin(a) * 17)
		local ped = part(folder, Vector3.new(3, 4, 3), CFrame.lookAt(pos + Vector3.new(0, 2, 0), Vector3.new(-105, 2, 0)), Color3.fromRGB(80, 78, 88), Enum.Material.Metal)
		ped.MaterialVariant = "NovaTitanium"
		ped.Name = "Core_" .. id
		local col = RARITY[(m.core and m.core.rarity) or "common"]
		local ring = part(folder, Vector3.new(0.15, 3.3, 3.3), CFrame.new(pos + Vector3.new(0, 4.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.CanCollide = false
		local orb = part(folder, Vector3.new(1.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 5.8, 0)), col, Enum.Material.Neon, Enum.PartType.Ball)
		orb.CanCollide = false
		local shell = part(folder, Vector3.new(2.4, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 5.8, 0)), col, Enum.Material.ForceField, Enum.PartType.Ball)
		shell.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = col
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = orb
		local pr = Instance.new("ProximityPrompt")
		pr.MaxActivationDistance = 7
		pr.RequiresLineOfSight = false
		pr.ActionText = "Core"
		pr:SetAttribute("Key", "p_archive")
		pr:SetAttribute("ObjectKey", m.titleKey)
		pr.Parent = ped
		pr.Triggered:Connect(function(plr)
			if Mission.state.cores[id] then
				Mission.cue({ type = "core", missionId = id }, plr)
			else
				Mission.cue({ type = "toast", key = "core_locked", status = "yellow", icon = "lock" }, plr)
			end
		end)
		cores[id] = { orb = orb, ring = ring, shell = shell, light = light }
	end
	-- unlocked cores glow, locked ones are dim glass
	task.spawn(function()
		local t = 0
		while true do
			task.wait(0.1)
			t += 0.1
			for id, c in cores do
				local on = Mission.state.cores[id] == true
				c.orb.Material = on and Enum.Material.Neon or Enum.Material.Glass
				c.orb.Transparency = on and 0 or 0.6
				c.shell.Transparency = on and 0.2 or 0.9
				c.light.Enabled = on
				c.ring.Transparency = on and 0.2 or 0.8
				local base = c.ring.Position + Vector3.new(0, 1.75 + math.sin(t * 2 + #id) * 0.2, 0)
				c.orb.CFrame = CFrame.new(base) * CFrame.Angles(0, t, 0)
				c.shell.CFrame = c.orb.CFrame
			end
		end
	end)
end

return A
