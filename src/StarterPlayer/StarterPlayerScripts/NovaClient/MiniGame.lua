-- MiniGame (client): five short repair games, each tied to the fault. Big targets, bright colours, 6–20 s.
-- wires (electrical short) · pipes (coolant / fuel line) · tune (antenna noise) · timing (calibration) · budget (audit)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(RS.Nova.Shared.Config)

local MG = {}
local player = Players.LocalPlayer
local ctx, UI, COL, F
local remote
local gui, panel, body, titleL, instrL, factL, timerL, active = nil, nil, nil, nil, nil, nil, nil, nil
local conns = {}

local function clearConns() for _, c in conns do c:Disconnect() end conns = {} end
local function rng(seed) return Random.new(seed or os.clock() * 1000) end

local function freeze(on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		player:SetAttribute("CineFrozen", true)
		hum.WalkSpeed, hum.JumpHeight = 0, 0
	else
		player:SetAttribute("CineFrozen", nil)
		hum.WalkSpeed, hum.JumpHeight = 16, 7.2
	end
end

local function close(sendCancel)
	if not active then return end
	if sendCancel then remote:FireServer({ type = "cancel", id = active.id }) end
	active = nil
	clearConns()
	gui.Enabled = false
	freeze(false)
end

local function win()
	if not active or active.won then return end
	active.won = true
	ctx.audio.sfx("install", nil, 0.6)
	ctx.audio.sfx("go", nil, 0.4)
	local banner = UI.new("Frame", { BackgroundColor3 = COL.green, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 70), ZIndex = 20, Parent = body }, { UI.corner(16) })
	UI.text({ Text = string.upper(ctx.t("mg_fixed")), FontFace = F.title, TextSize = 32, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = banner })
	UI.pop(banner, 0.6)
	local id = active.id
	-- the server enforces a minimum play time; wait for it before reporting
	local wait = math.max(0.7, (active.t0 + 2.6) - os.clock())
	task.delay(wait, function()
		if active and active.id == id then
			remote:FireServer({ type = "done", id = id })
			close(false)
		end
	end)
end

local function wrong(obj)
	ctx.audio.sfx("hold", nil, 0.25)
	if obj then
		local p = obj.Position
		for k = 1, 3 do
			obj.Position = p + UDim2.fromOffset(k % 2 == 0 and -6 or 6, 0)
			task.wait(0.04)
		end
		obj.Position = p
	end
end

local function button(props, label, color)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = color or COL.panel2 }, { UI.corner(12) })
	for k, v in props do b[k] = v end
	if label then UI.text({ Text = label, FontFace = F.title, TextSize = 22, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = b }) end
	return b
end

------------------------------------------------------------------ wires
local WIRE_COLS = { Color3.fromRGB(240, 84, 84), Color3.fromRGB(246, 196, 72), Color3.fromRGB(80, 160, 255), Color3.fromRGB(88, 214, 141) }
local function gameWires(easy, r)
	local n = easy and 3 or 4
	local order = {}
	for i = 1, n do order[i] = i end
	for i = n, 2, -1 do local j = r:NextInteger(1, i) order[i], order[j] = order[j], order[i] end
	local W, H = 520, 280
	local gap = H / (n + 1)
	local left, right, done, sel = {}, {}, 0, nil
	local function line(a, b, col)
		local d = b - a
		local f = UI.new("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
			Size = UDim2.fromOffset(d.Magnitude, 8), Rotation = math.deg(math.atan2(d.Y, d.X)), ZIndex = 3, Parent = body }, { UI.corner(4) })
		return f
	end
	for i = 1, n do
		local y = gap * i
		local lb = button({ Position = UDim2.fromOffset(30, y - 24), Size = UDim2.fromOffset(70, 48), ZIndex = 4, Parent = body }, nil, WIRE_COLS[i])
		UI.stroke(COL.text, 0, 1).Parent = lb
		left[i] = { b = lb, pos = Vector2.new(100, y) }
		local c = order[i]
		local rb = button({ Position = UDim2.fromOffset(W - 100, y - 24), Size = UDim2.fromOffset(70, 48), ZIndex = 4, Parent = body }, nil, COL.panel2)
		UI.stroke(WIRE_COLS[c], 4, 0).Parent = rb
		UI.new("Frame", { BackgroundColor3 = WIRE_COLS[c], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), ZIndex = 5, Parent = rb }, { UI.corner(11) })
		right[i] = { b = rb, pos = Vector2.new(W - 100, y), color = c }
		table.insert(conns, lb.MouseButton1Click:Connect(function()
			if left[i].done then return end
			if sel then left[sel].b:FindFirstChildOfClass("UIStroke").Thickness = 0 end
			sel = i
			local st = lb:FindFirstChildOfClass("UIStroke")
			st.Thickness, st.Transparency = 4, 0
			ctx.audio.sfx("ui", nil, 0.3)
		end))
		table.insert(conns, rb.MouseButton1Click:Connect(function()
			if not sel or right[i].done then return end
			if right[i].color == sel then
				line(left[sel].pos, right[i].pos, WIRE_COLS[sel])
				left[sel].done, right[i].done = true, true
				left[sel].b:FindFirstChildOfClass("UIStroke").Thickness = 0
				sel = nil
				done += 1
				ctx.audio.sfx("click", nil, 0.4)
				if done >= n then win() end
			else
				task.spawn(wrong, rb)
			end
		end))
	end
end

------------------------------------------------------------------ pipes (rotate tiles to connect ▶ inlet to outlet ▶)
local function gamePipes(easy, r)
	local cols, rows = easy and 3 or 4, 3
	local size = 78
	local ox = (520 - cols * size) / 2
	local oy = (280 - rows * size) / 2
	-- random monotone path from the left edge to the right edge
	local path, req = {}, {}
	local row = r:NextInteger(1, rows)
	local startRow = row
	local prevDir = 3 -- entered from the west
	for c = 1, cols do
		table.insert(path, { c = c, r = row, enter = prevDir })
		-- maybe move vertically inside this column before going east
		if c < cols and r:NextNumber() < 0.55 then
			local dir = (row == 1) and 1 or ((row == rows) and -1 or (r:NextNumber() < 0.5 and -1 or 1))
			path[#path].exit = dir == 1 and 2 or 0
			row += dir
			table.insert(path, { c = c, r = row, enter = dir == 1 and 0 or 2 })
		end
		path[#path].exit = path[#path].exit or 1
		prevDir = 3
	end
	local endRow = row
	local onPath = {}
	for _, p in path do
		local key = p.c .. ":" .. p.r
		local set = { [p.enter] = true, [p.exit] = true }
		local straight = (p.enter + 2) % 4 == p.exit
		onPath[key] = { straight = straight, set = set }
	end
	local tiles = {}
	local function conns4(straight, rot)
		local base = straight and { 1, 3 } or { 0, 1 }
		local s = {}
		for _, d in base do s[(d + rot) % 4] = true end
		return s
	end
	local function same(a, b) for d = 0, 3 do if (a[d] or false) ~= (b[d] or false) then return false end end return true end
	local function solved()
		for key, need in onPath do
			local t = tiles[key]
			if not same(conns4(t.straight, t.rot), need.set) then return false end
		end
		return true
	end
	local water = Color3.fromRGB(80, 170, 255)
	local function paint()
		for key, t in tiles do
			local ok = onPath[key] and same(conns4(t.straight, t.rot), onPath[key].set)
			for _, bar in t.bars do bar.BackgroundColor3 = ok and water or Color3.fromRGB(170, 176, 188) end
		end
	end
	for c = 1, cols do
		for rr = 1, rows do
			local key = c .. ":" .. rr
			local straight
			if onPath[key] then straight = onPath[key].straight else straight = r:NextNumber() < 0.5 end
			local b = button({ Position = UDim2.fromOffset(ox + (c - 1) * size + 3, oy + (rr - 1) * size + 3), Size = UDim2.fromOffset(size - 6, size - 6), ZIndex = 3, Parent = body }, nil, COL.panel2)
			local holder = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = b })
			local bars = {}
			local base = straight and { 1, 3 } or { 0, 1 }
			table.insert(bars, UI.new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 5, Parent = holder }, { UI.corner(9) }))
			for _, d in base do
				local horiz = d == 1 or d == 3
				local pos = ({ [0] = UDim2.new(0.5, 0, 0.25, 0), [1] = UDim2.new(0.75, 0, 0.5, 0), [2] = UDim2.new(0.5, 0, 0.75, 0), [3] = UDim2.new(0.25, 0, 0.5, 0) })[d]
				table.insert(bars, UI.new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = horiz and UDim2.new(0.5, 0, 0, 14) or UDim2.new(0, 14, 0.5, 0), ZIndex = 5, Parent = holder }))
			end
			local rot = r:NextInteger(0, 3)
			tiles[key] = { straight = straight, rot = rot, holder = holder, bars = bars }
			holder.Rotation = rot * 90
			table.insert(conns, b.MouseButton1Click:Connect(function()
				if active and active.won then return end
				local t = tiles[key]
				t.rot = (t.rot + 1) % 4
				TweenService:Create(holder, TweenInfo.new(0.12), { Rotation = t.rot * 90 }):Play()
				ctx.audio.sfx("ui", nil, 0.25)
				paint()
				if solved() then win() end
			end))
		end
	end
	-- make sure it doesn't start solved
	if solved() then local k = next(onPath) tiles[k].rot = (tiles[k].rot + 1) % 4 tiles[k].holder.Rotation = tiles[k].rot * 90 end
	paint()
	UI.icon("arrow", 34, water, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(ox - 2, oy + (startRow - 0.5) * size), ZIndex = 4, Parent = body })
	UI.icon("arrow", 34, water, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(ox + cols * size + 2, oy + (endRow - 0.5) * size), ZIndex = 4, Parent = body })
end

------------------------------------------------------------------ tune (move the slider until the signal is clean)
local function gameTune(easy, r)
	local target = r:NextNumber(0.15, 0.85)
	local tol = easy and 0.07 or 0.045
	local f = (target > 0.5) and 0.1 or 0.9
	local bars = {}
	local scope = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 14, 20), Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(480, 150), ZIndex = 3, Parent = body }, { UI.corner(12) })
	for i = 1, 40 do
		bars[i] = UI.new("Frame", { BackgroundColor3 = COL.cyan, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8 + (i - 1) * 11.6, 0.5, 0), Size = UDim2.fromOffset(7, 20), ZIndex = 4, Parent = scope }, { UI.corner(3) })
	end
	local meter = {}
	for i = 1, 5 do
		meter[i] = UI.new("Frame", { BackgroundColor3 = COL.panel2, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(410 + (i - 1) * 16, 150), Size = UDim2.fromOffset(12, 10 + i * 9), ZIndex = 5, Parent = body }, { UI.corner(3) })
	end
	local track = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(20, 200), Size = UDim2.fromOffset(370, 18), ZIndex = 3, Parent = body }, { UI.corner(9) })
	local knob = UI.new("Frame", { BackgroundColor3 = COL.amber, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(f, 0.5), Size = UDim2.fromOffset(36, 36), ZIndex = 4, Parent = track }, { UI.corner(18) })
	local lockL = UI.text({ Text = "", FontFace = F.title, TextSize = 18, TextColor3 = COL.green, Position = UDim2.fromOffset(20, 236), Size = UDim2.fromOffset(480, 30), ZIndex = 3, Parent = body })
	local dragging, lockT = false, 0
	local function setFromX(x) f = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) end
	table.insert(conns, track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true setFromX(i.Position.X) end
	end))
	table.insert(conns, UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setFromX(i.Position.X) end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not active or active.won then return end
		if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then f = math.clamp(f - dt * 0.35, 0, 1) end
		if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then f = math.clamp(f + dt * 0.35, 0, 1) end
		knob.Position = UDim2.fromScale(f, 0.5)
		local err = math.abs(f - target)
		local clean = math.clamp(1 - err * 3.2, 0, 1)
		local t = os.clock()
		for i, b in bars do
			local wave = math.sin(i * 0.45 + t * 6) * 0.5 + 0.5
			local noise = (math.random() - 0.5) * (1 - clean) * 2
			b.Size = UDim2.fromOffset(7, math.clamp(10 + (wave * clean + math.abs(noise)) * 110, 6, 140))
			b.BackgroundColor3 = clean > 0.85 and COL.green or (clean > 0.5 and COL.cyan or Color3.fromRGB(140, 150, 170))
		end
		local lit = math.floor(clean * 5 + 0.5)
		for i, m in meter do m.BackgroundColor3 = (i <= lit) and COL.green or COL.panel2 end
		if err <= tol then
			lockT += dt
			lockL.Text = string.upper(ctx.t("mg_lock")) .. string.rep(" ·", math.floor(lockT / 0.4) + 1)
			if lockT >= 1.2 then win() end
		else
			lockT = 0
			lockL.Text = ""
		end
	end))
end

------------------------------------------------------------------ timing (stop the marker in the green zone)
local function gameTiming(easy, r)
	local need = easy and 2 or 3
	local hits = 0
	local barW = 460
	local bar = UI.new("Frame", { BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(30, 70), Size = UDim2.fromOffset(barW, 46), ZIndex = 3, Parent = body }, { UI.corner(12) })
	local zone = UI.new("Frame", { BackgroundColor3 = COL.green, Size = UDim2.fromOffset(90, 46), ZIndex = 4, Parent = bar }, { UI.corner(12) })
	local marker = UI.new("Frame", { BackgroundColor3 = COL.text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 64), ZIndex = 5, Parent = bar }, { UI.corner(5) })
	local dots = {}
	for i = 1, need do dots[i] = UI.new("Frame", { BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(260 - need * 18 + (i - 1) * 36, 140), Size = UDim2.fromOffset(24, 24), ZIndex = 3, Parent = body }, { UI.corner(12) }) end
	local stop = button({ Position = UDim2.fromOffset(185, 190), Size = UDim2.fromOffset(150, 60), ZIndex = 3, Parent = body }, string.upper(ctx.t("mg_stop")), COL.amber)
	local x, dir, speed = 0, 1, easy and 0.55 or 0.75
	local zw = easy and 110 or 90
	local function newZone()
		zone.Size = UDim2.fromOffset(zw, 46)
		zone.Position = UDim2.fromOffset(r:NextInteger(20, barW - zw - 20), 0)
	end
	newZone()
	local function press()
		if not active or active.won then return end
		local px = x * barW
		local z0 = zone.Position.X.Offset
		if px >= z0 and px <= z0 + zw then
			hits += 1
			dots[hits].BackgroundColor3 = COL.green
			ctx.audio.sfx("click", nil, 0.4)
			if hits >= need then win() return end
			zw = math.max(56, zw - 18)
			speed += 0.18
			newZone()
		else
			task.spawn(wrong, bar)
		end
	end
	table.insert(conns, stop.MouseButton1Click:Connect(press))
	table.insert(conns, UIS.InputBegan:Connect(function(i, gp)
		if i.KeyCode == Enum.KeyCode.Space or i.KeyCode == Enum.KeyCode.E then press() end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not active or active.won then return end
		x += dir * dt * speed
		if x >= 1 then x, dir = 1, -1 elseif x <= 0 then x, dir = 0, 1 end
		marker.Position = UDim2.new(x, 0, 0.5, 0)
	end))
end

------------------------------------------------------------------ budget (good enough AND cheapest)
local ROUNDS = {
	{ need = "20 Wh", icon = "battery", cards = { { "20 Wh", 12, true }, { "20 Wh", 30 }, { "10 Wh", 6, false, true } }, name = "mg_battery" },
	{ need = "6 W", icon = "panel", cards = { { "8 W", 10, true }, { "8 W", 25 }, { "4 W", 5, false, true } }, name = "mg_panel" },
	{ need = "2 ⟶", icon = "comms", cards = { { "3", 9, true }, { "3", 20 }, { "1", 4, false, true } }, name = "mg_antenna" },
	{ need = "50 MB", icon = "data", cards = { { "60 MB", 9, true }, { "60 MB", 18 }, { "40 MB", 6, false, true } }, name = "mg_recorder" },
}
local function gameBudget(easy, r)
	local total = easy and 2 or 3
	local pool = table.clone(ROUNDS)
	for i = #pool, 2, -1 do local j = r:NextInteger(1, i) pool[i], pool[j] = pool[j], pool[i] end
	local round = 0
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = body })
	local function show()
		round += 1
		for _, c in holder:GetChildren() do c:Destroy() end
		local R = pool[round]
		UI.text({ Text = ctx.t(R.name) .. " · " .. ctx.t("mg_need") .. ": " .. R.need .. "   (" .. round .. "/" .. total .. ")", FontFace = F.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6), ZIndex = 4, Parent = holder })
		local cards = table.clone(R.cards)
		for i = #cards, 2, -1 do local j = r:NextInteger(1, i) cards[i], cards[j] = cards[j], cards[i] end
		for i, c in cards do
			local b = button({ Position = UDim2.fromOffset(20 + (i - 1) * 165, 56), Size = UDim2.fromOffset(150, 200), ZIndex = 4, Parent = holder }, nil, COL.panel2)
			UI.stroke(COL.line, 1, 0.8).Parent = b
			UI.icon(R.icon, 54, COL.amber, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), ZIndex = 5, Parent = b })
			UI.text({ Text = c[1], FontFace = F.title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 30), ZIndex = 5, Parent = b })
			local price = UI.new("Frame", { BackgroundColor3 = COL.yellow, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(100, 40), ZIndex = 5, Parent = b }, { UI.corner(10) })
			UI.text({ Text = c[2] .. " ¢", FontFace = F.title, TextSize = 22, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = price })
			table.insert(conns, b.MouseButton1Click:Connect(function()
				if not active or active.won then return end
				if c[3] then
					ctx.audio.sfx("click", nil, 0.4)
					if round >= total then win() else show() end
				else
					local tip = UI.text({ Text = ctx.t(c[4] and "mg_toosmall" or "mg_toodear"), FontFace = F.bodyBold, TextSize = 15, TextColor3 = COL.red, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
						Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 22), ZIndex = 6, Parent = b })
					task.spawn(wrong, b)
					task.delay(1.4, function() if tip.Parent then tip:Destroy() end end)
				end
			end))
		end
	end
	show()
end

local GAMES = { wires = gameWires, pipes = gamePipes, tune = gameTune, timing = gameTiming, budget = gameBudget }
local ICON = { wires = "power", pipes = "warning", tune = "comms", timing = "instrument", budget = "budget" }

------------------------------------------------------------------ frame
local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "NovaMiniGame"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale") scale.Parent = gui
	local function rescale() local vp = workspace.CurrentCamera.ViewportSize scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 720), 0.65, 1.3) end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	panel = UI.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 480), Parent = gui }, 22)
	local st = panel:FindFirstChildOfClass("UIStroke") st.Color, st.Transparency, st.Thickness = COL.amber, 0.2, 2
	local chip = UI.new("Frame", { BackgroundColor3 = COL.amber, Position = UDim2.fromOffset(20, 18), Size = UDim2.fromOffset(46, 46), Parent = panel }, { UI.corner(12) })
	MG.icon = UI.icon("warning", 28, COL.dark, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = chip })
	titleL = UI.text({ FontFace = F.title, TextSize = 22, Position = UDim2.fromOffset(78, 14), Size = UDim2.new(1, -170, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel })
	instrL = UI.text({ FontFace = F.bodyBold, TextSize = 16, TextColor3 = COL.amber, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(78, 44), Size = UDim2.new(1, -150, 0, 40), Parent = panel })
	timerL = UI.text({ FontFace = F.mono, TextSize = 26, TextColor3 = COL.red, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 20), Size = UDim2.fromOffset(70, 32), Parent = panel })
	local x = UI.new("ImageButton", { BackgroundTransparency = 1, Image = Config.IconSheet.image, ImageRectSize = Vector2.new(128, 128), ImageRectOffset = Config.iconRect("cross"), ImageColor3 = COL.dim,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 22), Size = UDim2.fromOffset(28, 28), Parent = panel })
	x.MouseButton1Click:Connect(function() close(true) end)
	body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 96), Size = UDim2.fromOffset(520, 290), Parent = panel })
	factL = UI.text({ FontFace = F.body, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -14), Size = UDim2.new(1, -44, 0, 54), Parent = panel })
end

local function open(msg)
	if active then close(true) end
	for _, c in body:GetChildren() do c:Destroy() end
	active = { id = msg.id, kind = msg.kind, t0 = os.clock(), deadline = msg.deadline, spotPos = msg.spotPos }
	titleL.Text = msg.titleKey and ctx.t(msg.titleKey) or ""
	instrL.Text = ctx.t("mg_" .. msg.kind) .. (msg.easy and ("  ·  " .. ctx.t("mg_easy")) or "")
	factL.Text = ctx.t("mgf_" .. msg.kind)
	UI.setIcon(MG.icon, ICON[msg.kind] or "warning")
	gui.Enabled = true
	UI.pop(panel, 0.92)
	freeze(true)
	ctx.audio.sfx("ui", nil, 0.4)
	local game = GAMES[msg.kind] or gameWires
	game(msg.easy == true, rng(msg.seed))
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not active then return end
		if active.deadline then
			local rem = active.deadline - workspace:GetServerTimeNow()
			timerL.Text = rem > 0 and tostring(math.ceil(rem)) or ""
			if rem <= -0.5 and not active.won then close(true) return end
		else
			timerL.Text = ""
		end
		if ctx.locked() then close(true) end
	end))
	table.insert(conns, UIS.InputBegan:Connect(function(i)
		if i.KeyCode == Enum.KeyCode.Escape then close(true) end
	end))
end

function MG.isOpen() return active ~= nil end

function MG.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	build()
	remote = RS.Nova.Remotes:WaitForChild("MiniGame")
	remote.OnClientEvent:Connect(function(msg)
		if typeof(msg) ~= "table" then return end
		if msg.type == "start" then open(msg)
		elseif msg.type == "close" and active and active.id == msg.id then close(false) end
	end)
	player.CharacterAdded:Connect(function() close(true) end)
end

return MG
