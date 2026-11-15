-- Movement: sprint with stamina, procedural carry/press/lean layered on top of Roblox's default R15
-- locomotion (legs keep walking), heavy-carry balance bar, Q to drop, per-location gravity, class-aware holds.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS.Nova.Remotes

local M = {}
local player = Players.LocalPlayer
local ctx
local stamina = 1
local sprinting = false
local reachT = -10 -- os.clock() of the last prompt press (local arm reach)

local WALK, SPRINT, CARRY = 16, 23, 13

-- per-character procedural layer state
local rigs = {} -- [Model] = { motors = {...}, carry = 0, lean = 0, roll = 0, yaw = nil }

local function motorsOf(char)
	local function m(part, name)
		local p = char:FindFirstChild(part)
		return p and p:FindFirstChild(name)
	end
	return {
		rs = m("RightUpperArm", "RightShoulder"), ls = m("LeftUpperArm", "LeftShoulder"),
		re = m("RightLowerArm", "RightElbow"), le = m("LeftLowerArm", "LeftElbow"),
		root = m("LowerTorso", "Root"), waist = m("UpperTorso", "Waist"),
	}
end

local function rigFor(char)
	local r = rigs[char]
	if r and r.motors.rs and r.motors.rs.Parent then return r end
	r = { motors = motorsOf(char), carry = 0, lean = 0, roll = 0, yaw = nil }
	rigs[char] = r
	char.AncestryChanged:Connect(function(_, parent) if not parent then rigs[char] = nil end end)
	return r
end

local CARRY_SH = CFrame.Angles(math.rad(72), 0, 0)
local CARRY_EL = CFrame.Angles(math.rad(22), 0, 0)
local REACH_SH = CFrame.Angles(math.rad(80), 0, math.rad(-8))

-- runs after the Animator has written Motor6D.Transform this frame
local function procedural(dt)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local r = rigFor(char)
			local mo = r.motors
			-- carry pose (anything carried or a heavy crate end)
			local carrying = plr:GetAttribute("Carrying") ~= nil or plr:GetAttribute("HeavyHold") == true
			r.carry += ((carrying and 1 or 0) - r.carry) * math.clamp(dt * 10, 0, 1)
			if r.carry > 0.01 then
				for _, k in { "rs", "ls" } do
					local mt = mo[k]
					if mt then mt.Transform = mt.Transform:Lerp(CARRY_SH, r.carry) end
				end
				for _, k in { "re", "le" } do
					local mt = mo[k]
					if mt then mt.Transform = mt.Transform:Lerp(CARRY_EL, r.carry) end
				end
			end
			-- local prompt reach (right arm), only when hands are free
			if plr == player and r.carry < 0.5 then
				local t = os.clock() - reachT
				if t < 0.45 and mo.rs then
					local a = math.sin(math.clamp(t / 0.45, 0, 1) * math.pi)
					mo.rs.Transform = mo.rs.Transform:Lerp(REACH_SH, a)
				end
			end
			-- body lean: forward with speed, roll into turns
			local v = hrp.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)
			local speed = flat.Magnitude
			local yaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
			local turn = 0
			if r.yaw then
				local d = (yaw - r.yaw + math.pi) % (2 * math.pi) - math.pi
				turn = d / math.max(dt, 1 / 240)
			end
			r.yaw = yaw
			local onGround = hum.FloorMaterial ~= Enum.Material.Air
			local leanGoal = onGround and math.clamp((speed - 10) / 14, 0, 1) * math.rad(9) * (1 - r.carry * 0.7) or 0
			local rollGoal = onGround and math.clamp(-turn * speed * 0.0016, -math.rad(7), math.rad(7)) or 0
			r.lean += (leanGoal - r.lean) * math.clamp(dt * 6, 0, 1)
			r.roll += (rollGoal - r.roll) * math.clamp(dt * 5, 0, 1)
			if mo.root and (math.abs(r.lean) > 1e-3 or math.abs(r.roll) > 1e-3) then
				mo.root.Transform = mo.root.Transform * CFrame.Angles(-r.lean, 0, r.roll)
			end
		end
	end
end

local function setupCharacter(char)
	stamina = 1
	rigs[char] = nil
	-- stop any leftover tracks from older builds (looped console-press etc.)
	local hum = char:WaitForChild("Humanoid", 5)
	local animator = hum and hum:WaitForChild("Animator", 5)
	if animator then
		task.delay(1, function()
			for _, t in animator:GetPlayingAnimationTracks() do
				local id = t.Animation and t.Animation.AnimationId or ""
				if id:find("136797773743052") or id:find("137701869047989") then t:Stop(0) end
			end
		end)
	end
end

function M.init(c)
	ctx = c
	if player.Character then task.spawn(setupCharacter, player.Character) end
	player.CharacterAdded:Connect(setupCharacter)

	-- stamina bar + balance bar
	local UI, COL, F = ctx.UI, ctx.COL, ctx.F
	local bar = UI.new("Frame", { Name = "Stamina", BackgroundColor3 = COL.panel, BackgroundTransparency = 0.2, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Size = UDim2.fromOffset(220, 6), Visible = false, Parent = ctx.gui }, { UI.corner(3) })
	local fill = UI.new("Frame", { BackgroundColor3 = COL.cyan, Size = UDim2.fromScale(1, 1), Parent = bar }, { UI.corner(3) })
	local bal = UI.panel({ Name = "Balance", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(340, 64), Visible = false, Parent = ctx.gui }, 14)
	local balLbl = UI.text({ FontFace = F.display, TextSize = 11, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 8), Parent = bal })
	local track = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 45, 56), Size = UDim2.new(1, -40, 0, 10), Position = UDim2.fromOffset(20, 34), Parent = bal }, { UI.corner(5) })
	UI.new("Frame", { BackgroundColor3 = COL.green, BackgroundTransparency = 0.6, Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.fromScale(0.35, 0), Parent = track }, { UI.corner(5) })
	local needle = UI.new("Frame", { BackgroundColor3 = COL.text, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 22), Position = UDim2.fromScale(0.5, 0.5), Parent = track }, { UI.corner(3) })

	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then sprinting = true end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then Remotes.Request:FireServer({ action = "drop" }) end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then sprinting = false end
	end)

	PPS.PromptTriggered:Connect(function() reachT = os.clock() end)
	-- class-aware hold time (the matching class works twice as fast) + class-only prompts
	PPS.PromptShown:Connect(function(prompt)
		local base = prompt:GetAttribute("HoldBase")
		local cls = prompt:GetAttribute("FixClass")
		if base and base > 0 then
			prompt.HoldDuration = (cls and player:GetAttribute("Class") == cls) and base * 0.5 or base
		end
		local only = prompt:GetAttribute("OnlyClass")
		if only then
			local present = false
			for _, p in Players:GetPlayers() do if p:GetAttribute("Class") == only then present = true end end
			if present and player:GetAttribute("Class") ~= only then prompt.Enabled = false end
		end
	end)

	RunService.Stepped:Connect(function(_, dt) procedural(dt) end)

	local cam = workspace.CurrentCamera
	local baseFov = 70
	local crateCache, crateT = nil, 0
	local function findCrate()
		if crateCache and crateCache.Parent and (crateCache:GetAttribute("HolderA") == player.UserId or crateCache:GetAttribute("HolderB") == player.UserId) then return crateCache end
		if os.clock() - crateT < 0.5 then return nil end
		crateT = os.clock()
		crateCache = nil
		for _, root in { workspace.Citadel:FindFirstChild("Hangar"), workspace:FindFirstChild("Locations") } do
			if root then
				for _, d in root:GetDescendants() do
					if d.Name == "HeavyCrate" and (d:GetAttribute("HolderA") == player.UserId or d:GetAttribute("HolderB") == player.UserId) then crateCache = d return d end
				end
			end
		end
		return nil
	end

	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local heavy = player:GetAttribute("HeavyHold")
		local carrying = player:GetAttribute("Carrying") ~= nil
		local moving = hum.MoveDirection.Magnitude > 0.1
		local canSprint = sprinting and moving and not heavy and not carrying and stamina > 0.05 and not ctx.locked()
		if canSprint then stamina = math.max(0, stamina - dt * 0.2) else stamina = math.min(1, stamina + dt * (moving and 0.12 or 0.22)) end
		if not heavy and not player:GetAttribute("CineFrozen") then
			local goal = canSprint and SPRINT or (carrying and CARRY or WALK)
			hum.WalkSpeed = hum.WalkSpeed + (goal - hum.WalkSpeed) * math.clamp(dt * 8, 0, 1)
		end
		if not ctx.locked() then
			cam.FieldOfView = cam.FieldOfView + ((canSprint and baseFov + 6 or baseFov) - cam.FieldOfView) * math.clamp(dt * 5, 0, 1)
		end
		bar.Visible = stamina < 0.99
		fill.Size = UDim2.fromScale(stamina, 1)
		fill.BackgroundColor3 = stamina < 0.25 and COL.red or COL.cyan
		-- gravity: location attribute, trainer zone overrides
		local g = player:GetAttribute("Gravity") or 196.2
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local trainer = workspace.Citadel:FindFirstChild("Trainer")
		if hrp and trainer and trainer:FindFirstChild("Zone") then
			local z = trainer.Zone
			local rel = z.CFrame:PointToObjectSpace(hrp.Position)
			if math.abs(rel.X) < z.Size.X / 2 and math.abs(rel.Z) < z.Size.Z / 2 and math.abs(rel.Y) < z.Size.Y / 2 then g = 32 end
		end
		if math.abs(workspace.Gravity - g) > 0.5 then workspace.Gravity = g end
		-- heavy carry balance
		if heavy then
			local crate = findCrate()
			local b = crate and crate:GetAttribute("Balance")
			bal.Visible = true
			if b then
				balLbl.Text = string.upper(ctx.t("heavy_balance"))
				local off = (1 - b) * 0.5 * (math.sin(os.clock() * 3) >= 0 and 1 or -1)
				needle.Position = UDim2.fromScale(0.5 + off, 0.5)
				needle.BackgroundColor3 = b > 0.5 and COL.green or (b > 0.25 and COL.yellow or COL.red)
			else
				balLbl.Text = string.upper(ctx.t("heavy_need"))
				needle.Position = UDim2.fromScale(0.5, 0.5)
				needle.BackgroundColor3 = COL.dim
			end
		else
			bal.Visible = false
		end
	end)
end

return M
