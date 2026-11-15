-- Buggy (client): drives the rover you sit in as driver (hover-suspension: 4 ground probes set the height and
-- tilt, throttle/steer from the VehicleSeat), and spins/steers the wheels of every rover for everyone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local B = {}
local player = Players.LocalPlayer
local RIDE, MAXV, REV, ACC, TURN = 2.6, 50, 20, 1.7, 1.9
local st = { model = nil, speed = 0, yaw = 0 }
local spin = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function excludeList(m)
	local ex = { m }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ex, p.Character) end end
	for _, b in CollectionService:GetTagged("NovaBuggy") do table.insert(ex, b) end
	return ex
end

local function myBuggy()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		local m = seat.Parent
		if m and m:GetAttribute("Buggy") and m:GetAttribute("Driver") == player.UserId then return m, seat end
	end
	return nil
end

local function drive(dt)
	local m, seat = myBuggy()
	if not m then st.model = nil return end
	local ch = m.PrimaryPart
	local lv, ao = ch:FindFirstChild("Move"), ch:FindFirstChild("Upright")
	if not (lv and ao) or ch.Anchored then return end
	local cf = ch.CFrame
	if st.model ~= m then
		st.model = m
		st.speed = 0
		local lk = cf.LookVector
		st.yaw = math.atan2(-lk.X, -lk.Z)
	end
	if player:GetAttribute("CineFrozen") then st.speed = 0 end
	local thr, steer = seat.ThrottleFloat, seat.SteerFloat
	local target = thr > 0 and thr * MAXV or thr * REV
	st.speed += (target - st.speed) * math.clamp(dt * (thr == 0 and 1.1 or ACC), 0, 1)
	local turn = TURN * math.clamp(math.abs(st.speed) / 14, 0, 1)
	st.yaw -= steer * turn * dt * (st.speed >= 0 and 1 or -1)
	local fwd = Vector3.new(-math.sin(st.yaw), 0, -math.cos(st.yaw))
	local right = fwd:Cross(Vector3.yAxis)
	params.FilterDescendantsInstances = excludeList(m)
	local pos = cf.Position
	local pts, cnt, sumY = {}, 0, 0
	for i, o in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local p = pos + right * (o[1] * 2.8) + fwd * (o[2] * 4.0)
		local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -18, 0), params)
		pts[i] = hit and hit.Position
		if hit then cnt += 1 sumY += hit.Position.Y end
	end
	local up, vy = Vector3.yAxis, nil
	if cnt >= 2 then
		local gy = sumY / cnt
		vy = math.clamp((gy + RIDE - pos.Y) * 9, -45, 32)
		if pts[1] and pts[2] and pts[3] and pts[4] then
			local along = (pts[1] + pts[2]) / 2 - (pts[3] + pts[4]) / 2
			local side = (pts[1] + pts[3]) / 2 - (pts[2] + pts[4]) / 2
			local n = side:Cross(along)
			if n.Magnitude > 0.01 then
				n = n.Unit
				if n.Y < 0 then n = -n end
				if n.Y > 0.6 then up = n end
			end
		end
	else
		vy = math.max(ch.AssemblyLinearVelocity.Y - workspace.Gravity * dt, -90)
	end
	-- don't push into walls forever: lose speed when blocked
	local ahead = workspace:Raycast(pos + Vector3.new(0, 0.5, 0), fwd * math.sign(st.speed) * 7, params)
	if ahead and math.abs(st.speed) > 4 then st.speed *= 0.5 end
	lv.VectorVelocity = fwd * st.speed + Vector3.new(0, vy, 0)
	local f2 = (fwd - up * fwd:Dot(up)).Unit
	ao.CFrame = CFrame.lookAt(Vector3.zero, f2, up)
end

local function wheels(dt)
	for _, m in CollectionService:GetTagged("NovaBuggy") do
		local ch = m.PrimaryPart
		if ch then
			local v = ch.AssemblyLinearVelocity:Dot(ch.CFrame.LookVector)
			spin[m] = ((spin[m] or 0) + v * dt / 1.6) % (math.pi * 2)
			local drv = m:FindFirstChild("DriverSeat")
			local steer = drv and drv.SteerFloat or 0
			for _, mo in ch:GetChildren() do
				if mo:IsA("Motor6D") and mo.Name == "Axle" then
					local front = mo.C0.Position.Z < 0
					mo.Transform = CFrame.Angles(0, front and -steer * 0.45 or 0, 0) * CFrame.Angles(spin[m], 0, 0)
				end
			end
			local beacon = m:FindFirstChild("Beacon")
			if beacon then beacon.Transparency = (m:GetAttribute("Driver") and (os.clock() % 0.8 < 0.4)) and 0 or 0.6 end
		end
	end
end

function B.init()
	RunService.Heartbeat:Connect(function(dt) pcall(drive, dt) end)
	RunService.Stepped:Connect(function(_, dt) pcall(wheels, dt) end)
end

return B
