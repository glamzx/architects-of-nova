-- HangarService: racks, carrying modules by hand, installing into frame slots, rockets.
-- Server-authoritative: clients only trigger ProximityPrompts; every rule is checked here.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Nova = RS.Nova
local ModulesData = require(Nova.Data.Modules)
local Launch = require(Nova.Data.Launch)
local Classes = require(Nova.Data.Classes)

local Hangar = workspace:WaitForChild("Citadel"):WaitForChild("Hangar")
local ModelsFolder = SS.Nova.ModuleModels
local FramesFolder = SS.Nova.Frames

local H = {}
local Mission, Heavy, Progress -- injected
local ItemsFolder = SS.Nova:FindFirstChild("Items")
local groundItems = {}
local frameModel: Model? = nil
local frameId: string? = nil
local installedModels: { [string]: Model } = {}
local carried: { [Player]: { id: string, model: Model } } = {}
local rocketHome: { [string]: CFrame } = {}
local buildRacks -- forward declaration (defined in the racks section)
local racksFor: string? = nil

local function prompt(parent: Instance, key: string, objectKey: string?, dist: number?, keyCode: Enum.KeyCode?)
	local p = Instance.new("ProximityPrompt")
	p.MaxActivationDistance = dist or 6
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.ActionText = key
	p:SetAttribute("Key", key)
	if objectKey then p:SetAttribute("ObjectKey", objectKey) end
	if keyCode then p.KeyboardKeyCode = keyCode end
	p.Parent = parent
	return p
end

local function setModelPhysics(m: Model, anchored: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
		end
	end
end

local function weldAll(m: Model)
	local root = m.PrimaryPart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

local function fitScale(m: Model, maxSize: number)
	local _, size = m:GetBoundingBox()
	local s = math.min(1, maxSize / math.max(size.X, size.Y, size.Z))
	if s < 1 then m:ScaleTo(s) end
end

local function toast(player: Player, key: string, status: string, icon: string?)
	Mission.cue({ type = "toast", key = key, status = status, icon = icon }, player)
end

------------------------------------------------------------------ carrying
local function dropCarried(player: Player)
	local c = carried[player]
	if c then
		c.model:Destroy()
		carried[player] = nil
	end
	player:SetAttribute("Carrying", nil)
end

local function templateFor(id: string)
	if id:sub(1, 5) == "item:" then
		return ItemsFolder and ItemsFolder:FindFirstChild(id:sub(6))
	end
	return ModelsFolder:FindFirstChild(id)
end

local function giveCarried(player: Player, id: string)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or player:GetAttribute("HeavyHold") then return end
	dropCarried(player)
	local tpl = templateFor(id)
	if not tpl then return end
	local m = tpl:Clone()
	fitScale(m, 3.2)
	setModelPhysics(m, false)
	m:PivotTo(hrp.CFrame * CFrame.new(0, 0.6, -2.4))
	weldAll(m)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hrp
	w.Part1 = m.PrimaryPart
	w.Parent = m.PrimaryPart
	m.Name = "Carried"
	m.Parent = char
	carried[player] = { id = id, model = m }
	if Progress and Progress.discover and id:sub(1, 5) ~= "item:" then Progress.discover(player, id) end
	player:SetAttribute("Carrying", id)
end

H.giveCarried = giveCarried
function H.carriedId(player: Player): string?
	return carried[player] and carried[player].id or nil
end
function H.takeAway(player: Player)
	dropCarried(player)
end

-- Class rule: if someone in the lobby owns this category, only they install it.
local function ownerClass(category: string): string?
	for id, c in Classes.byId do if c.installs[category] then return id end end
	return nil
end
local function classPresent(cls: string)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InLobby") ~= false and p:GetAttribute("Class") == cls then return true end
	end
	return false
end
function H.allowed(player: Player, category: string): (boolean, string?)
	local owner = ownerClass(category)
	if not owner or player:GetAttribute("Class") == owner then return true end
	if classPresent(owner) then return false, owner end
	return true, "bip"
end

-- Q: put the carried item on the floor; anyone can pick it up again
function H.drop(player: Player)
	local c = carried[player]
	if not c then return false end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local id = c.id
	dropCarried(player)
	if not hrp then return true end
	local tpl = templateFor(id)
	local m = tpl:Clone()
	fitScale(m, 3.0)
	setModelPhysics(m, true)
	local _, size = m:GetBoundingBox()
	local pos = (hrp.CFrame * CFrame.new(0, 0, -3)).Position
	local ray = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0))
	local y = ray and ray.Position.Y or pos.Y - 3
	m:PivotTo(CFrame.new(pos.X, y + size.Y / 2 + 0.1, pos.Z))
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.CanCollide = false d.CanQuery = true end end
	m.Name = "Ground_" .. id
	m.Parent = workspace
	local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
	local pr = prompt(root, "p_pickup", (ModulesData.defs[id] and ModulesData.defs[id].nameKey) or id, 7)
	pr.Triggered:Connect(function(plr)
		if carried[plr] or plr:GetAttribute("HeavyHold") then return end
		m:Destroy()
		giveCarried(plr, id)
	end)
	table.insert(groundItems, m)
	Mission.cue({ type = "sfx", name = "drop" }, player)
	return true
end

function H.onTake(player: Player, id: string, spot: BasePart?)
	if Mission.state.phase ~= "Build" then
		toast(player, "go_briefing", "yellow")
		return
	end
	local c = carried[player]
	if c and c.id == id then
		dropCarried(player) -- put it back on the rack
		return
	end
	local def = ModulesData.defs[id]
	if def and def.heavy and spot then
		if Progress and Progress.discover then Progress.discover(player, id) end
		H.spawnHeavy(id, spot)
		return
	end
	giveCarried(player, id)
end

------------------------------------------------------------------ slots
local function slotDef(slotId: string)
	if not frameId then return nil end
	for _, s in Launch.frames[frameId].slots do
		if s.id == slotId then return s end
	end
	return nil
end

local function padPrompt(slotId: string): ProximityPrompt?
	if not frameModel then return nil end
	local post = frameModel.Pads:FindFirstChild("Post_" .. slotId)
	return post and post:FindFirstChild("SlotPrompt") :: ProximityPrompt?
end

local function beamToBoard(slotId: string, color: Color3)
	if not frameModel then return end
	local post = frameModel.Pads:FindFirstChild("Post_" .. slotId)
	local term = Hangar:FindFirstChild("ResourceTerminal")
	local anchor = term and term:FindFirstChild("Screen") or Hangar:FindFirstChild("HoloAnchor")
	if not post or not anchor then return end
	local a1 = anchor:FindFirstChild("BeamTo") or Instance.new("Attachment")
	a1.Name = "BeamTo"
	a1.Parent = anchor
	local b = Instance.new("Beam")
	b.Attachment0 = post.BeamFrom
	b.Attachment1 = a1
	b.Width0, b.Width1 = 0.6, 2.5
	b.LightEmission = 1
	b.FaceCamera = true
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new(0.2)
	b.TextureSpeed = 2
	b.Parent = post
	Debris:AddItem(b, 1.6)
end

local function placeModel(slotId: string, id: string, fromCF: CFrame?)
	if not frameModel then return end
	local anchor = frameModel.Slots:FindFirstChild(slotId)
	local m = ModelsFolder[id]:Clone()
	setModelPhysics(m, true)
	m.Name = "Installed_" .. slotId
	local target = anchor.CFrame
	if fromCF then
		m:PivotTo(fromCF)
		m.Parent = frameModel
		local v = Instance.new("CFrameValue")
		v.Value = fromCF
		v.Changed:Connect(function(cf) m:PivotTo(cf) end)
		local tw = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = target })
		tw.Completed:Connect(function() v:Destroy() end)
		tw:Play()
	else
		m:PivotTo(target)
		m.Parent = frameModel
	end
	installedModels[slotId] = m
end

function H.onPad(player: Player, slotId: string)
	if Mission.state.phase ~= "Build" then return end
	local def = slotDef(slotId)
	if not def then return end
	local installed = Mission.state.installed
	local c = carried[player]
	if installed[slotId] then
		if c then
			toast(player, "slot_busy", "yellow")
			return
		end
		-- remove: module goes back into the player's hands
		local id = installed[slotId]
		installed[slotId] = nil
		if installedModels[slotId] then installedModels[slotId]:Destroy() end
		installedModels[slotId] = nil
		local pp = padPrompt(slotId)
		if pp then pp:SetAttribute("Key", "p_place") pp:SetAttribute("ObjectKey", nil) end
		giveCarried(player, id)
		Mission.onLoadoutChanged()
		return
	end
	if not c then return end
	local mod = ModulesData.defs[c.id]
	if not mod then return end
	if not def.accepts[mod.category] then
		toast(player, "slot_wrong", "red", mod.category)
		return
	end
	local ok, who = H.allowed(player, mod.category)
	if not ok then
		Mission.cue({ type = "toast", key = "only_class", status = "yellow", icon = Classes.byId[who].icon, extraKey = "role_" .. who }, player)
		return
	end
	if who == "bip" then toast(player, "bip_helps", "cyan", "spark") end
	local fromCF = c.model:GetPivot()
	local id = c.id
	dropCarried(player)
	H.installModule(slotId, id, fromCF)
end

function H.installModule(slotId: string, id: string, fromCF: CFrame?)
	local mod = ModulesData.defs[id]
	Mission.state.installed[slotId] = id
	placeModel(slotId, id, fromCF)
	local pp = padPrompt(slotId)
	if pp then pp:SetAttribute("Key", "p_remove") pp:SetAttribute("ObjectKey", mod.nameKey) end
	beamToBoard(slotId, mod.color)
	Mission.cue({ type = "sfx", name = "install" })
	Mission.onLoadoutChanged(id)
end

-- Heavy modules arrive as a two-handle crate in front of the rack
local heavyOut: { [string]: any } = {}
function H.spawnHeavy(id: string, spot: BasePart)
	if heavyOut[id] and heavyOut[id].model.Parent then return end
	local def = ModulesData.defs[id]
	local toward = Vector3.new(0, spot.Position.Y, -100) - spot.Position
	local flat = Vector3.new(toward.X, 0, toward.Z).Unit
	local pos = spot.Position + flat * 10
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(ignore, pl.Character) end end
	table.insert(ignore, workspace.Citadel:FindFirstChild("BIP7"))
	params.FilterDescendantsInstances = ignore
	local ray = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	local y = (ray and ray.Position.Y or 0.4) + 1.25
	local cf = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + flat) * CFrame.Angles(0, math.rad(90), 0)
	heavyOut[id] = Heavy.spawn(cf, {
		label = def.nameKey, length = 6, parent = Hangar, visual = ModelsFolder[id],
		check = function(mid, crate)
			if Mission.state.phase ~= "Build" or not frameModel then return false end
			for _, post in frameModel.Pads:GetChildren() do
				if post.Name:sub(1, 5) == "Post_" then
					local slotId = post:GetAttribute("SlotId")
					local sd = slotDef(slotId)
					if sd and sd.accepts[def.category] and not Mission.state.installed[slotId] and (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(post.Position.X, 0, post.Position.Z)).Magnitude < 9 then
						H.installModule(slotId, id, crate.body.CFrame)
						heavyOut[id] = nil
						return true
					end
				end
			end
			return false
		end,
	})
end

------------------------------------------------------------------ frame lifecycle
function H.prepare(mission)
	buildRacks(mission)
	if frameModel and frameId == mission.frame then
		return -- keep current loadout (fast rebuild after failure)
	end
	if frameModel then frameModel:Destroy() end
	frameId = mission.frame
	frameModel = FramesFolder[frameId]:Clone()
	frameModel:PivotTo(Hangar.Stand.FrameAnchor.CFrame)
	frameModel.Name = "Frame"
	frameModel.Parent = Hangar
	for _, post in frameModel.Pads:GetChildren() do
		local slotId = post:GetAttribute("SlotId")
		if post.Name:sub(1, 5) == "Post_" then
			local p = prompt(post, "p_place", nil, 6)
			p.Name = "SlotPrompt"
			p:SetAttribute("SlotId", slotId)
			p.Triggered:Connect(function(plr) H.onPad(plr, slotId) end)
		end
	end
	for slotId, id in Mission.state.installed do
		placeModel(slotId, id)
	end
end

function H.clearAll()
	for _, m in installedModels do m:Destroy() end
	installedModels = {}
	for _, g in groundItems do if g.Parent then g:Destroy() end end
	groundItems = {}
	if Heavy then Heavy.clearAll() end
	heavyOut = {}
	table.clear(Mission.state.installed)
	if frameModel then frameModel:Destroy() end
	frameModel, frameId = nil, nil
	for p in carried do dropCarried(p) end
end

function H.dropAll()
	for p in carried do dropCarried(p) end
end

function H.frame()
	return frameModel
end

------------------------------------------------------------------ racks
function buildRacks(mission)
	local racks = table.clone((mission and mission.racks) or ModulesData.racks)
	local ov = Mission.state.rackOverride
	if ov and racks[ov.bay] then
		racks[ov.bay] = { category = racks[ov.bay].category, labelKey = racks[ov.bay].labelKey, ids = ov.ids }
	end
	local key = (mission and mission.id or "default") .. (ov and table.concat(ov.ids, ",") or "")
	if racksFor == key then return end
	racksFor = key
	for i = 1, 5 do
		local bay = Hangar.RackBays:FindFirstChild("Bay" .. i)
		if not bay then continue end
		for _, c in bay:GetChildren() do
			if c.Name:sub(1, 8) == "Display_" then c:Destroy() end
		end
		for j = 1, 2 do
			local spot = bay:FindFirstChild("Spot" .. j)
			if spot then
				for _, pp in spot:GetChildren() do if pp:IsA("ProximityPrompt") then pp:Destroy() end end
				spot:SetAttribute("ModuleId", nil)
			end
		end
	end
	for i, rack in racks do
		local bay = Hangar.RackBays:FindFirstChild("Bay" .. i)
		if not bay then continue end
		bay:SetAttribute("Category", rack.category)
		bay:SetAttribute("LabelKey", rack.labelKey or ("cat_" .. rack.category))
		for j, id in rack.ids do
			local spot = bay:FindFirstChild("Spot" .. j)
			if not spot or not ModelsFolder:FindFirstChild(id) then continue end
			spot:SetAttribute("ModuleId", id)
			local disp = ModelsFolder[id]:Clone()
			fitScale(disp, 3.4)
			setModelPhysics(disp, true)
			local _, size = disp:GetBoundingBox()
			disp:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + size.Y / 2 + 0.4, 0))
			disp.Name = "Display_" .. id
			disp:SetAttribute("ModuleId", id)
			disp.Parent = bay
			local p = prompt(spot, "p_take", ModulesData.defs[id].nameKey, 8)
			p.Triggered:Connect(function(plr) H.onTake(plr, id, spot) end)
			if ModulesData.defs[id].heavy then spot:SetAttribute("Heavy", true) else spot:SetAttribute("Heavy", nil) end
		end
	end
end

------------------------------------------------------------------ rockets
local function rocketModel(rocketId: string): Model?
	local r = Launch.rockets[rocketId]
	local pad = Hangar.LaunchArea:FindFirstChild(r.pad)
	return pad and pad:FindFirstChild("Rocket") :: Model?
end

function H.showRocket(rocketId: string)
	for id, r in Launch.rockets do
		local pad = Hangar.LaunchArea:FindFirstChild(r.pad)
		if pad then
			pad.SelectRing.Transparency = (id == rocketId) and 0.1 or 0.85
		end
	end
end

function H.resetRocket()
	for id in Launch.rockets do
		local m = rocketModel(id)
		if m and rocketHome[id] then
			m:SetAttribute("LaunchT0", nil)
			m:SetAttribute("LaunchDur", nil)
			m:PivotTo(rocketHome[id])
			for _, d in m:GetDescendants() do
				if d:GetAttribute("LaunchFX") then d:Destroy() end
			end
		end
	end
	H.showRocket(Mission.state.rocketId)
end

-- The server only sets the ignition time and the final position; every client animates the climb
-- locally (smooth 60 fps, perfectly in sync with the countdown in the cinematic).
function H.launchRocket(rocketId: string, duration: number, ignite: number?)
	local m = rocketModel(rocketId)
	if not m then return nil, 0 end
	ignite = ignite or 2.8
	local t0 = workspace:GetServerTimeNow() + ignite
	m:SetAttribute("LaunchT0", t0)
	m:SetAttribute("LaunchDur", duration)
	-- engine fire is drawn on every client by NovaAmbientFX ("rocket engines") from LaunchT0/LaunchDur
	local home = rocketHome[rocketId]
	task.delay(ignite + duration + 0.2, function()
		if m:GetAttribute("LaunchT0") == t0 and home then m:PivotTo(home + Vector3.new(0, 900, 0)) end
	end)
	return m, t0
end

------------------------------------------------------------------ init
function H.init(mission, heavy, progress)
	Mission, Heavy, Progress = mission, heavy, progress
	buildRacks(nil)
	for id in Launch.rockets do
		local m = rocketModel(id)
		if m then
			for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
			rocketHome[id] = m:GetPivot()
		end
	end
	local lc = Hangar.LaunchConsole
	prompt(lc.RocketButton, "p_rocket", nil, 10, Enum.KeyCode.E).Triggered:Connect(function(plr) Mission.cycleRocket(plr) end)
	prompt(lc.LaunchButton, "p_launch", nil, 10, Enum.KeyCode.F).Triggered:Connect(function(plr) Mission.tryLaunch(plr) end)
	if lc:FindFirstChild("OrbitButton") then
		local op = prompt(lc.OrbitButton, "p_orbit", nil, 10, Enum.KeyCode.G)
		op.Name = "OrbitPrompt"
		op.Triggered:Connect(function(plr) Mission.cycleOrbit(plr) end)
		task.spawn(function()
			while true do
				task.wait(0.5)
				local m = Mission.mission()
				op.Enabled = (m.orbits ~= nil and #m.orbits > 1)
			end
		end)
	end
	H.showRocket(Mission.state.rocketId)
	Players.PlayerRemoving:Connect(dropCarried)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterRemoving:Connect(function() dropCarried(p) end)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterRemoving:Connect(function() dropCarried(p) end)
	end
end

return H
