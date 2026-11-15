-- DroidService: BIP-7 teaches by action. It flies to the next thing to do and highlights it.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local ModulesData = require(RS.Nova.Data.Modules)

local Citadel = workspace:WaitForChild("Citadel")
local D = {}
local Mission, Hangar

local droid: Model
local highlight: Highlight
local targetPos = Vector3.new(4, 6, 14)
local targetInst: Instance? = nil

-- Which rack bay holds a category
local function bayFor(category: string)
	local racks = Mission.mission().racks or ModulesData.racks
	for i, rack in racks do
		if rack.category == category then
			return Citadel.Hangar.RackBays:FindFirstChild("Bay" .. i)
		end
	end
	return nil
end

local function padFor(category: string)
	local frame = Hangar.frame()
	if not frame then return nil end
	local map = { antenna = "top", panel = "side", edl = "bottom", payload = "bottom" }
	local slot = map[category]
	if not slot then
		for _, s in { "u1", "u2", "u3", "b1", "b2", "b3", "b4" } do
			if not Mission.state.installed[s] then slot = s break end
		end
	end
	return slot and frame.Pads:FindFirstChild("Post_" .. slot)
end

local REQUIRED = { "computer", "battery", "panel", "antenna" }

local function pickTarget(): (Instance?, Vector3?)
	local st = Mission.state
	if st.phase == "Hub" or st.phase == "Briefing" then
		return Citadel.Atrium.Hologram, Vector3.new(8, 2, 4)
	elseif st.phase == "Build" then
		-- someone carrying? point at the matching pad
		for _, p in game:GetService("Players"):GetPlayers() do
			local id = p:GetAttribute("Carrying")
			if id and ModulesData.defs[id] then
				local pad = padFor(ModulesData.defs[id].category)
				if pad then return pad, Vector3.new(0, 4, 0) end
			end
		end
		-- first unfinished task that needs a module category -> that rack
		local have = {}
		for _, id in st.installed do
			local m = ModulesData.defs[id]
			if m then have[m.category] = true end
		end
		local needs = {}
		for _, t in Mission.mission().tasks or {} do
			if t.cond and t.cond.cat then table.insert(needs, t.cond.cat) end
		end
		if #needs == 0 then needs = REQUIRED end
		for _, cat in needs do
			if not have[cat] then
				local bay = bayFor(cat)
				if bay then return bay, Vector3.new(0, 6, 0) end
			end
		end
		if Mission.activeRehearsal() then
			return Citadel.Control.BigScreen, Vector3.new(-10, -2, 0)
		end
		return Citadel.Hangar.LaunchConsole, Vector3.new(0, 7, 0)
	elseif st.phase == "Launch" then
		return nil, Vector3.new(10, 12, -140)
	elseif st.phase == "Prep" then
		local prep = Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad") and Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("Prep")
		if prep then
			for _, s in prep.Spots:GetChildren() do
				if s:GetAttribute("Need") then return s, Vector3.new(0, 5, 0) end
			end
			local cart = prep.Spots:FindFirstChild("KitCart")
			if cart then return cart, Vector3.new(0, 5, 0) end
		end
	elseif st.phase == "Board" then
		local pad = Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad")
		local zone = pad and pad:FindFirstChild("BoardZone")
		if zone then return zone, Vector3.new(0, 7, 0) end
	elseif st.phase == "Field" and st.field then
		local loc = workspace:FindFirstChild("Locations") and workspace.Locations:FindFirstChild(st.field.location)
		if loc and st.field.site == "B" and loc:FindFirstChild("SiteB") then loc = loc.SiteB end
		if loc then
			if loc.Lander:GetAttribute("Need") then return loc.Lander, Vector3.new(0, 8, 0) end
			local p1 = game:GetService("Players"):GetPlayers()[1]
			local hrp = p1 and p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
			local best, bd = nil, math.huge
			for _, s in loc.Spots:GetChildren() do
				if s:GetAttribute("Need") and not s:GetAttribute("Hidden") then
					local d = hrp and (s.Position - hrp.Position).Magnitude or 0
					if d < bd then best, bd = s, d end
				end
			end
			if best then return best, Vector3.new(0, 6, 0) end
			if hrp then return nil, hrp.Position + Vector3.new(3, 5, 3) end
		end
	elseif st.phase == "Flight" then
		return nil, Vector3.new(0, -200, 0)
	elseif st.phase == "Ops" then
		if st.waiting then
			local target = st.waiting.lit or (st.waiting.kind == "sequence" and st.waiting.consoles[st.waiting.step]) or st.waiting.consoles[1]
			local c = Citadel.Control.Consoles:FindFirstChild(target)
			if c then return c, Vector3.new(0, 6, 0) end
		end
		return Citadel.Control.BigScreen, Vector3.new(-8, 0, 0)
	elseif st.phase == "Debrief" then
		return Citadel.Atrium.Hologram, Vector3.new(0, 4, 5)
	end
	return nil, nil
end

local function instPos(inst: Instance): Vector3
	if inst:IsA("Model") then
		return inst:GetBoundingBox().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return Vector3.zero
end

function D.init(mission, hangar)
	Mission, Hangar = mission, hangar
	droid = Citadel:WaitForChild("BIP7")
	highlight = Instance.new("Highlight")
	highlight.Name = "BIPHighlight"
	highlight.FillTransparency = 0.85
	highlight.FillColor = Color3.fromRGB(0, 210, 255)
	highlight.OutlineColor = Color3.fromRGB(0, 230, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Citadel

	task.spawn(function()
		while true do
			local inst, offset = pickTarget()
			targetInst = inst
			if inst then
				targetPos = instPos(inst) + (offset or Vector3.zero)
			elseif offset then
				targetPos = offset
			end
			highlight.Adornee = (inst and inst ~= Citadel.Atrium.Hologram) and inst or nil
			task.wait(0.4)
		end
	end)

	local SKINS = { bip_gold = Color3.fromRGB(230, 186, 80), bip_violet = Color3.fromRGB(160, 120, 230) }
	workspace:GetAttributeChangedSignal("BipSkin"):Connect(function()
		local c = SKINS[workspace:GetAttribute("BipSkin")]
		local tgt = droid:FindFirstChild("Accent") or droid:FindFirstChild("Body")
		if c and tgt then tgt.Color = c end
	end)
	local pos = droid:GetPivot().Position
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		local goal = targetPos + Vector3.new(0, math.sin(t * 2.2) * 0.5, 0)
		if (goal - pos).Magnitude > 300 then pos = goal end -- teleport with the crew between locations
		pos = pos:Lerp(goal, math.clamp(dt * 2.5, 0, 1))
		local look = targetInst and instPos(targetInst) or (pos + Vector3.new(0, 0, 1))
		local flat = Vector3.new(look.X, pos.Y, look.Z)
		if (flat - pos).Magnitude < 0.5 then flat = pos + Vector3.new(0, 0, 1) end
		droid:PivotTo(CFrame.lookAt(pos, flat))
	end)
end

return D
