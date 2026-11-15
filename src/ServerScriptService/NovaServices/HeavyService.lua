-- HeavyService: two-person carrying. A heavy part is a crate with two handles.
-- Both holders move it together; walking out of step breaks the balance and the crate falls.
-- Solo: BIP-7 grabs the other handle (slower, but always possible).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS.Nova.Remotes

local H = {}
local Mission, Progress
local crates = {}
local holding: { [Player]: any } = {}

local function part(parent, size, cf, color, mat, name)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Name = name or "Part"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lobbyCount()
	local n = 0
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") ~= false then n += 1 end end
	return n
end

local function setMove(player, heavy)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum:SetAttribute("Heavy", heavy)
	hum.WalkSpeed = heavy and 11 or 16
	hum.JumpHeight = heavy and 0 or 7.2
	player:SetAttribute("HeavyHold", heavy or nil)
end

local function release(c, side)
	local p = c.holders[side]
	if p and p ~= "BIP" then
		holding[p] = nil
		setMove(p, false)
	end
	c.holders[side] = nil
	c.model:SetAttribute("Holder" .. side, nil)
end

function H.release(player)
	local c = holding[player]
	if not c then return false end
	for side, p in c.holders do if p == player then release(c, side) end end
	if c.holders.A == "BIP" or c.holders.B == "BIP" then
		if not ((c.holders.A and c.holders.A ~= "BIP") or (c.holders.B and c.holders.B ~= "BIP")) then
			c.holders.A, c.holders.B = nil, nil
			c.model:SetAttribute("HolderA", nil)
			c.model:SetAttribute("HolderB", nil)
		end
	end
	return true
end

local function ground(c)
	local pos = c.body.Position
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { c.model }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	local y = hit and hit.Position.Y or pos.Y - 1
	local _, ry = c.body.CFrame:ToOrientation()
	c.model:PivotTo(CFrame.new(pos.X, y + c.body.Size.Y / 2 + 0.05, pos.Z) * CFrame.Angles(0, ry, 0))
end

local function drop(c)
	local who = {}
	for side, p in c.holders do
		if p ~= "BIP" then table.insert(who, p) end
		release(c, side)
	end
	c.dropT = os.clock()
	ground(c)
	for _, p in who do Remotes.Cue:FireClient(p, { type = "toast", key = "heavy_drop", status = "red", icon = "carry" }) end
	Remotes.Cue:FireAllClients({ type = "sfx", name = "drop", pos = c.body.Position })
end

-- Creates a heavy crate. opts: { payload, label, length, check = function(mid) -> boolean }
function H.spawn(cf, opts)
	if Mission and Mission.radioOnce and Mission.state.phase == "Build" then Mission.radioOnce("bip_heavy") end
	local L = opts.length or 6
	local m = Instance.new("Model")
	m.Name = "HeavyCrate"
	local body = part(m, Vector3.new(L, 2.4, 2.8), cf, Color3.fromRGB(150, 150, 154), Enum.Material.Metal, "Body")
	body.MaterialVariant = "NovaWallPanel"
	part(m, Vector3.new(L + 0.1, 0.5, 2.9), cf * CFrame.new(0, 0.6, 0), Color3.fromRGB(214, 138, 58), Enum.Material.Metal, "Band").MaterialVariant = "NovaHazard"
	local hA = part(m, Vector3.new(0.5, 0.5, 2.2), cf * CFrame.new(-L / 2 - 0.4, 0.4, 0), Color3.fromRGB(240, 196, 80), Enum.Material.Metal, "HandleA")
	local hB = part(m, Vector3.new(0.5, 0.5, 2.2), cf * CFrame.new(L / 2 + 0.4, 0.4, 0), Color3.fromRGB(240, 196, 80), Enum.Material.Metal, "HandleB")
	m.PrimaryPart = body
	for _, p in m:GetChildren() do
		if p ~= body then
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = p
		end
		p.CanCollide = (p == body)
	end
	if opts.visual then
		local v = opts.visual:Clone()
		local _, size = v:GetBoundingBox()
		local s = math.min(1, (L - 0.5) / math.max(size.X, size.Z, 0.1), 2.2 / math.max(size.Y, 0.1))
		if s < 1 then v:ScaleTo(s) end
		for _, d in v:GetDescendants() do if d:IsA("BasePart") then d.Anchored = false d.CanCollide = false d.Massless = true end end
		v:PivotTo(cf * CFrame.new(0, 1.2 + 0.2, 0))
		for _, d in v:GetDescendants() do
			if d:IsA("BasePart") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = d
				w.Parent = d
			end
		end
		v.Parent = m
	end
	m:SetAttribute("Heavy", true)
	m:SetAttribute("Label", opts.label)
	m.Parent = opts.parent or workspace
	local c = { model = m, body = body, holders = {}, length = L, opts = opts, bad = 0, soloT = nil }
	for _, side in { "A", "B" } do
		local h = side == "A" and hA or hB
		local pr = Instance.new("ProximityPrompt")
		pr.MaxActivationDistance = 7
		pr.RequiresLineOfSight = false
		pr.HoldDuration = 0
		pr:SetAttribute("Key", "p_grab")
		pr:SetAttribute("ObjectKey", opts.label)
		pr.Parent = h
		pr.Triggered:Connect(function(plr)
			if holding[plr] or c.holders[side] or plr:GetAttribute("Carrying") then return end
			if c.dropT and os.clock() - c.dropT < 1.0 then return end
			c.holders[side] = plr
			holding[plr] = c
			m:SetAttribute("Holder" .. side, plr.UserId)
			setMove(plr, true)
			c.soloT = os.clock()
		end)
	end
	table.insert(crates, c)
	return c
end

function H.destroy(c)
	for side in c.holders do release(c, side) end
	c.model:Destroy()
	local i = table.find(crates, c)
	if i then table.remove(crates, i) end
end

function H.clearAll()
	for i = #crates, 1, -1 do H.destroy(crates[i]) end
end

local function handPos(p)
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	return (hrp.CFrame * CFrame.new(0, 0.2, -1.4)).Position, hrp
end

local acc = 0
function H.init(mission, progress)
	Mission, Progress = mission, progress
	Players.PlayerRemoving:Connect(function(p) if holding[p] then H.release(p) end end)
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		for i = #crates, 1, -1 do
			local c = crates[i]
			if not c.model.Parent then table.remove(crates, i) continue end
			local a, b = c.holders.A, c.holders.B
			-- solo: BIP-7 takes the free handle after a moment
			if (a and not b or b and not a) and lobbyCount() <= 1 and c.soloT and os.clock() - c.soloT > 1.2 then
				local side = a and "B" or "A"
				c.holders[side] = "BIP"
				c.model:SetAttribute("Holder" .. side, -1)
				a, b = c.holders.A, c.holders.B
			end
			if a and b then
				local human = (a ~= "BIP") and a or b
				local pa, hrpA = handPos(human)
				if not pa then drop(c) continue end
				local pb
				local other = (human == a) and b or a
				if other == "BIP" then
					pb = (hrpA.CFrame * CFrame.new(0, 0.2, -1.4 - c.length - 1.2)).Position
				else
					pb = handPos(other)
					if not pb then drop(c) continue end
				end
				local dir = pb - pa
				local flat = Vector3.new(dir.X, 0, dir.Z)
				local dist = flat.Magnitude
				if dist < 0.1 then flat = Vector3.new(1, 0, 0) dist = 0.1 end
				local mid = (pa + pb) / 2
				local ideal = c.length + 1.2
				local hd = math.abs(pa.Y - pb.Y)
				local bal = 1 - math.clamp(math.abs(dist - ideal) / 5 + hd / 5, 0, 1)
				c.model:SetAttribute("Balance", bal)
				local roll = math.clamp((pb.Y - pa.Y) / 4, -0.5, 0.5) + (1 - bal) * math.sin(os.clock() * 9) * 0.12
				local cf = CFrame.lookAt(mid, mid + flat.Unit) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(roll, 0, 0)
				c.model:PivotTo(cf)
				if bal < 0.22 then c.bad += dt else c.bad = math.max(0, c.bad - dt) end
				if c.bad > 1.1 then c.bad = 0 drop(c) continue end
				if acc > 0.2 and c.opts.check and c.opts.check(mid, c) then
					local holders = {}
					for _, p in c.holders do if p ~= "BIP" then table.insert(holders, p) end end
					H.destroy(c)
					for _, p in holders do Progress.achieve(p, "heavy") if Progress.questEvent then Progress.questEvent(p, "heavy") end end
				end
			else
				c.model:SetAttribute("Balance", nil)
			end
		end
		if acc > 0.2 then acc = 0 end
	end)
end

return H
