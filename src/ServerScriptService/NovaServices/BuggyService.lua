-- BuggyService: drivable 4-seat rovers (one driver + 3 passengers). Parked buggies are anchored; when someone
-- takes the driver seat the chassis is unanchored, its physics is handed to the driver's client (NovaClient.Buggy
-- drives it with a LinearVelocity + AlignOrientation hover-suspension), and it parks again when the driver leaves.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local B = {}
local Mission

local function seatPrompt(seat, text)
	local pr = seat:FindFirstChild("SitPrompt") or Instance.new("ProximityPrompt")
	pr.Name = "SitPrompt"
	pr.ActionText = text
	pr.ObjectText = "Nova rover" -- fallback; client localises from ObjectKey
	pr:SetAttribute("ObjectKey", "obj_rover")
	pr:SetAttribute("Key", text == "Drive" and "p_drive" or "p_ride")
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr.Parent = seat
	pr.Triggered:Connect(function(plr)
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if not hum or seat.Occupant or hum.SeatPart or hum.Health <= 0 then return end
		if plr:GetAttribute("CineFrozen") then return end
		seat:Sit(hum)
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function() pr.Enabled = seat.Occupant == nil end)
end

local function park(m)
	local ch = m.PrimaryPart
	local lv, ao = ch:FindFirstChild("Move"), ch:FindFirstChild("Upright")
	if lv then lv.VectorVelocity = Vector3.zero lv.Enabled = false end
	if ao then ao.Enabled = false end
	ch.AssemblyLinearVelocity, ch.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	-- settle upright on the ground
	local cf = ch.CFrame
	local look = cf.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { m }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ex, p.Character) end end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	local y = hit and (hit.Position.Y + 2.6) or cf.Position.Y
	ch.Anchored = true
	m:PivotTo(CFrame.lookAt(Vector3.new(cf.X, y, cf.Z), Vector3.new(cf.X, y, cf.Z) + look.Unit))
	m:SetAttribute("Driver", nil)
end

function B.setup(m)
	if m:GetAttribute("BuggyReady") then return end
	m:SetAttribute("BuggyReady", true)
	CollectionService:AddTag(m, "NovaBuggy")
	m:SetAttribute("Home", m:GetPivot())
	local ch = m.PrimaryPart
	ch.Anchored = true
	local drv = m:FindFirstChild("DriverSeat")
	seatPrompt(drv, "Drive")
	for i = 1, 3 do local s = m:FindFirstChild("Seat" .. i) if s then seatPrompt(s, "Ride") end end
	local token = 0
	drv:GetPropertyChangedSignal("Occupant"):Connect(function()
		token += 1
		local my = token
		local hum = drv.Occupant
		local plr = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if plr then
			ch.Anchored = false
			local ao = ch:FindFirstChild("Upright")
			if ao then ao.CFrame = CFrame.lookAt(Vector3.zero, ch.CFrame.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.0001)) ao.Enabled = true end
			local lv = ch:FindFirstChild("Move")
			if lv then lv.VectorVelocity = Vector3.zero lv.Enabled = true end
			pcall(function() ch:SetNetworkOwner(plr) end)
			m:SetAttribute("Driver", plr.UserId)
		else
			-- coast for a moment, then park
			local lv = ch:FindFirstChild("Move")
			if lv then lv.VectorVelocity = Vector3.new(0, lv.VectorVelocity.Y, 0) end
			task.delay(0.8, function() if my == token and not drv.Occupant then park(m) end end)
		end
	end)
end

function B.init(mission)
	Mission = mission
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Buggy") then B.setup(d) end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("Buggy") then task.defer(B.setup, d) end
	end)
	-- safety: anything that falls off the world goes home
	task.spawn(function()
		while true do
			task.wait(2)
			for _, m in CollectionService:GetTagged("NovaBuggy") do
				local ch = m.PrimaryPart
				if ch and (ch.Position.Y < -300 or ch.Position.Magnitude > 20000) then
					local drv = m:FindFirstChild("DriverSeat")
					if drv and drv.Occupant then drv.Occupant.Sit = false end
					ch.Anchored = true
					m:PivotTo(m:GetAttribute("Home"))
				end
			end
		end
	end)
end

return B
