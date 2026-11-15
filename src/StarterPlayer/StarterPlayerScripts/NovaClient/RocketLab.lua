-- RocketLab (client): stack 1–3 stages from engines and tanks and see real rocket science work.
-- Lift-off needs thrust > weight (TWR); reaching a target needs enough delta-v (Tsiolkovsky rocket equation).
-- Kids discover by themselves why real rockets have stages. Inspired by building games like Space Engineers.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Config = require(RS.Nova.Shared.Config)

local R = {}
local player = Players.LocalPlayer
local ctx, UI, COL, F
local gui, panel, canvas, stageUI, twrL, twrBar, dvL, dvBar, needMark, resultL, lessonL, levelBtns
local G0 = 9.81
local ENGINES = {
	spark = { thrust = 250, mass = 1.0, isp = 300, key = "lab_e_spark", col = Color3.fromRGB(255, 176, 72) },
	big = { thrust = 900, mass = 3.0, isp = 310, key = "lab_e_big", col = Color3.fromRGB(240, 84, 84) },
	vac = { thrust = 120, mass = 0.6, isp = 380, key = "lab_e_vac", col = Color3.fromRGB(96, 206, 216) },
}
local ENGINE_ORDER = { "spark", "big", "vac" }
local TANK = { big = { fuel = 18, dry = 1.0 }, small = { fuel = 6, dry = 0.4 } }
local LEVELS = {
	{ key = "lab_l1", payload = 0.5, need = 9.0 },
	{ key = "lab_l2", payload = 2.0, need = 11.2 },
	{ key = "lab_l3", payload = 3.0, need = 11.6 },
}
local level = 1
local stages = { { engine = "big", n = 1, big = 2, small = 0 } }
local busy = false
local lessonIdx = 1
local LESSONS = { "lab_t1", "lab_t2", "lab_t3", "lab_t4", "lab_t5" }

local function compute()
	local lv = LEVELS[level]
	local above = lv.payload
	local res = { dv = {}, total = 0, stageMass = {} }
	for i = #stages, 1, -1 do
		local s = stages[i]
		local e = ENGINES[s.engine]
		local dry = e.mass * s.n + s.big * TANK.big.dry + s.small * TANK.small.dry
		local fuel = s.big * TANK.big.fuel + s.small * TANK.small.fuel
		local m0 = above + dry + fuel
		local m1 = m0 - fuel
		local dv = (fuel > 0 and s.n > 0) and (e.isp * G0 * math.log(m0 / m1) / 1000) or 0
		res.dv[i] = dv
		res.total += dv
		res.stageMass[i] = dry + fuel
		above = m0
	end
	res.m0 = above
	local s1 = stages[1]
	res.twr = (ENGINES[s1.engine].thrust * s1.n) / (res.m0 * G0)
	return res
end

local function drawRocket(res)
	for _, c in canvas:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local W, H = 200, 470
	local scale = math.min(1, 360 / math.max(1, res.m0 ^ 0.6 * 10))
	local y = H - 18
	local rocket = UI.new("Frame", { Name = "Rocket", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	for i, s in stages do
		local e = ENGINES[s.engine]
		local w = 46 + math.min(5, s.n) * 10
		-- engines
		for k = 1, math.min(5, s.n) do
			local ex = W / 2 - (math.min(5, s.n) * 14) / 2 + (k - 1) * 14 + 7
			UI.new("Frame", { BackgroundColor3 = e.col, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(ex, y), Size = UDim2.fromOffset(12, 14), Parent = rocket }, { UI.corner(3) })
		end
		y -= 14
		-- tanks
		local th = math.max(10, (s.big * 22 + s.small * 9) * scale)
		local tank = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(226, 228, 232), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(W / 2, y), Size = UDim2.fromOffset(w, th), Parent = rocket }, { UI.corner(6) })
		UI.new("Frame", { BackgroundColor3 = e.col, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 4), Parent = tank })
		UI.text({ Text = tostring(i), FontFace = F.title, TextSize = 14, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = tank })
		y -= th + 2
	end
	-- payload + nose
	UI.new("Frame", { BackgroundColor3 = COL.amber, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(W / 2, y), Size = UDim2.fromOffset(40, 16), Parent = rocket }, { UI.corner(4) })
	UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(200, 204, 212), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(W / 2, y - 16), Size = UDim2.fromOffset(26, 22), Parent = rocket }, { UI.corner(13) })
	return rocket
end

local function refresh()
	local res = compute()
	local lv = LEVELS[level]
	for i, ui in stageUI do
		local s = stages[i]
		ui.frame.Visible = s ~= nil
		if s then
			ui.n.Text = tostring(s.n)
			ui.big.Text = tostring(s.big)
			ui.small.Text = tostring(s.small)
			ui.eng.Text = ctx.t(ENGINES[s.engine].key)
			ui.eng.BackgroundColor3 = ENGINES[s.engine].col
			ui.dv.Text = string.format("%.1f km/s", res.dv[i] or 0)
		end
	end
	twrL.Text = string.format(ctx.t("lab_twr"), res.twr)
	twrBar.Size = UDim2.fromScale(math.clamp(res.twr / 3, 0, 1), 1)
	twrBar.BackgroundColor3 = res.twr >= 1.2 and COL.green or (res.twr >= 1 and COL.yellow or COL.red)
	dvL.Text = string.format(ctx.t("lab_dv"), res.total, lv.need)
	dvBar.Size = UDim2.fromScale(math.clamp(res.total / (lv.need * 1.3), 0, 1), 1)
	dvBar.BackgroundColor3 = res.total >= lv.need and COL.green or COL.amber
	needMark.Position = UDim2.new(1 / 1.3, -1, 0, -4)
	for i, b in levelBtns do b.BackgroundColor3 = (i == level) and COL.amber or COL.panel2 end
	drawRocket(res)
	return res
end

local function testLaunch()
	if busy then return end
	busy = true
	local res = refresh()
	local lv = LEVELS[level]
	local rocket = canvas:FindFirstChild("Rocket")
	resultL.TextColor3 = COL.text
	if res.twr < 1.05 then
		resultL.Text = ctx.t("lab_heavy")
		resultL.TextColor3 = COL.red
		ctx.audio.sfx("hold", nil, 0.4)
		for k = 1, 6 do rocket.Position = UDim2.fromOffset(k % 2 == 0 and -4 or 4, 0) task.wait(0.05) end
		rocket.Position = UDim2.fromOffset(0, 0)
		busy = false
		return
	end
	ctx.audio.sfx("rocket", nil, 0.5)
	local frac = math.clamp(res.total / lv.need, 0, 1)
	local up = -380 * frac
	TweenService:Create(rocket, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(0, up) }):Play()
	task.wait(2.3)
	if res.total >= lv.need then
		resultL.Text = ctx.t("lab_ok")
		resultL.TextColor3 = COL.green
		ctx.audio.sfx("go", nil, 0.5)
		RS.Nova.Remotes.Request:FireServer({ action = "lab", level = level })
	else
		resultL.Text = string.format(ctx.t("lab_short"), lv.need - res.total)
		resultL.TextColor3 = COL.amber
		ctx.audio.sfx("hold", nil, 0.3)
		TweenService:Create(rocket, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(0, 0) }):Play()
		task.wait(1.4)
	end
	task.wait(1.2)
	rocket.Position = UDim2.fromOffset(0, 0)
	busy = false
end

local function smallBtn(parent, text, x, y, cb, col)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = col or COL.panel2, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(30, 30), Parent = parent }, { UI.corner(8) })
	UI.text({ Text = text, FontFace = F.title, TextSize = 18, TextColor3 = COL.text, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = b })
	b.MouseButton1Click:Connect(function() if not busy then cb() ctx.audio.sfx("ui", nil, 0.25) refresh() end end)
	return b
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "NovaRocketLab"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local sc = Instance.new("UIScale") sc.Parent = gui
	local function rescale() local vp = workspace.CurrentCamera.ViewportSize sc.Scale = math.clamp(math.min(vp.X / 1080, vp.Y / 680), 0.6, 1.25) end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	panel = UI.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(980, 600), Parent = gui }, 20)
	panel.BackgroundColor3 = COL.bg
	panel.BackgroundTransparency = 0
	local title = UI.text({ FontFace = F.display, TextSize = 16, TextColor3 = COL.cyan, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(600, 24), Parent = panel })
	local sub = UI.text({ FontFace = F.body, TextSize = 14, TextColor3 = COL.dim, Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(700, 20), Parent = panel })
	table.insert(ctx.refreshers, function() title.Text = string.upper(ctx.t("lab_title")) sub.Text = ctx.t("lab_sub") end)
	local close = UI.new("ImageButton", { BackgroundTransparency = 1, Image = Config.IconSheet.image, ImageRectSize = Vector2.new(128, 128), ImageRectOffset = Config.iconRect("cross"), ImageColor3 = COL.dim,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(28, 28), Parent = panel })
	close.MouseButton1Click:Connect(function() R.close() end)
	-- rocket drawing with an "orbit" line at the top
	canvas = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(8, 12, 22), Position = UDim2.fromOffset(24, 80), Size = UDim2.fromOffset(200, 470), ClipsDescendants = true, Parent = panel }, { UI.corner(12) })
	local orbitLine = UI.new("Frame", { BackgroundColor3 = COL.green, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 2), ZIndex = 2, Parent = canvas })
	local ol = UI.text({ FontFace = F.mono, TextSize = 11, TextColor3 = COL.green, Position = UDim2.fromOffset(6, 42), Size = UDim2.fromOffset(190, 16), ZIndex = 2, Parent = canvas })
	table.insert(ctx.refreshers, function() ol.Text = ctx.t(LEVELS[level].key) end)
	-- levels
	levelBtns = {}
	for i, lv in LEVELS do
		local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(244 + (i - 1) * 170, 80), Size = UDim2.fromOffset(160, 40), Parent = panel }, { UI.corner(10) })
		local l = UI.text({ FontFace = F.title, TextSize = 14, TextColor3 = COL.text, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Size = UDim2.fromScale(1, 1), Parent = b })
		table.insert(ctx.refreshers, function() l.Text = ctx.t(lv.key) end)
		b.MouseButton1Click:Connect(function() if busy then return end level = i resultL.Text = "" for _, f in ctx.refreshers do pcall(f) end refresh() end)
		levelBtns[i] = b
	end
	-- stage editors (3 columns)
	stageUI = {}
	for i = 1, 3 do
		local f = UI.new("Frame", { BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(244 + (i - 1) * 170, 134), Size = UDim2.fromOffset(160, 250), Parent = panel }, { UI.corner(12) })
		local head = UI.text({ FontFace = F.display, TextSize = 11, TextColor3 = COL.amber, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(140, 16), Parent = f })
		table.insert(ctx.refreshers, function() head.Text = string.upper(ctx.t("lab_stage")) .. " " .. i end)
		local eng = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.amber, Position = UDim2.fromOffset(10, 30), Size = UDim2.fromOffset(140, 30), Parent = f }, { UI.corner(8) })
		local engL = UI.text({ FontFace = F.title, TextSize = 13, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = eng })
		eng.MouseButton1Click:Connect(function()
			if busy or not stages[i] then return end
			local k = table.find(ENGINE_ORDER, stages[i].engine)
			stages[i].engine = ENGINE_ORDER[k % #ENGINE_ORDER + 1]
			ctx.audio.sfx("ui", nil, 0.25)
			refresh()
		end)
		local function row(y, labelKey, field, max)
			local l = UI.text({ FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(140, 16), Parent = f })
			table.insert(ctx.refreshers, function() l.Text = ctx.t(labelKey) end)
			smallBtn(f, "−", 12, y + 18, function() stages[i][field] = math.max(field == "n" and 1 or 0, stages[i][field] - 1) end)
			local v = UI.text({ FontFace = F.mono, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(46, y + 18), Size = UDim2.fromOffset(66, 30), Parent = f })
			smallBtn(f, "+", 118, y + 18, function() stages[i][field] = math.min(max, stages[i][field] + 1) end)
			return v
		end
		local n = row(66, "lab_engines", "n", 5)
		local big = row(118, "lab_bigtank", "big", 8)
		local small = row(170, "lab_smalltank", "small", 8)
		local dv = UI.text({ FontFace = F.mono, TextSize = 14, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 222), Size = UDim2.new(1, 0, 0, 20), Parent = f })
		stageUI[i] = { frame = f, n = n, big = big, small = small, eng = engL, dv = dv }
	end
	local addB = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(244, 394), Size = UDim2.fromOffset(245, 34), Parent = panel }, { UI.corner(10) })
	local addL = UI.text({ FontFace = F.title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = addB })
	local remB = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(499, 394), Size = UDim2.fromOffset(245, 34), Parent = panel }, { UI.corner(10) })
	local remL = UI.text({ FontFace = F.title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = remB })
	table.insert(ctx.refreshers, function() addL.Text = "+ " .. ctx.t("lab_addstage") remL.Text = "− " .. ctx.t("lab_remstage") end)
	addB.MouseButton1Click:Connect(function() if busy or #stages >= 3 then return end table.insert(stages, { engine = "vac", n = 1, big = 0, small = 2 }) refresh() end)
	remB.MouseButton1Click:Connect(function() if busy or #stages <= 1 then return end table.remove(stages) refresh() end)
	-- meters
	twrL = UI.text({ FontFace = F.bodyBold, TextSize = 15, Position = UDim2.fromOffset(760, 134), Size = UDim2.fromOffset(200, 40), TextWrapped = true, Parent = panel })
	local tb = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 45, 56), Position = UDim2.fromOffset(760, 178), Size = UDim2.fromOffset(200, 12), Parent = panel }, { UI.corner(6) })
	twrBar = UI.new("Frame", { BackgroundColor3 = COL.green, Size = UDim2.fromScale(0.5, 1), Parent = tb }, { UI.corner(6) })
	UI.new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Position = UDim2.new(1 / 3, -1, 0, -4), Size = UDim2.fromOffset(2, 20), Parent = tb })
	dvL = UI.text({ FontFace = F.bodyBold, TextSize = 15, Position = UDim2.fromOffset(760, 206), Size = UDim2.fromOffset(200, 40), TextWrapped = true, Parent = panel })
	local db = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 45, 56), Position = UDim2.fromOffset(760, 250), Size = UDim2.fromOffset(200, 12), Parent = panel }, { UI.corner(6) })
	dvBar = UI.new("Frame", { BackgroundColor3 = COL.amber, Size = UDim2.fromScale(0.5, 1), Parent = db }, { UI.corner(6) })
	needMark = UI.new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.fromOffset(2, 20), Parent = db })
	local go = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.amber, Position = UDim2.fromOffset(760, 280), Size = UDim2.fromOffset(200, 54), Parent = panel }, { UI.corner(12) })
	local goL = UI.text({ FontFace = F.title, TextSize = 18, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = go })
	table.insert(ctx.refreshers, function() goL.Text = string.upper(ctx.t("lab_test")) end)
	go.MouseButton1Click:Connect(function() task.spawn(testLaunch) end)
	resultL = UI.text({ Text = "", FontFace = F.bodyBold, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(760, 344), Size = UDim2.fromOffset(200, 84), Parent = panel })
	-- lesson strip (real rocket science in kid words) + source
	local lesson = UI.new("Frame", { BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.2, Position = UDim2.fromOffset(244, 440), Size = UDim2.fromOffset(716, 110), Parent = panel }, { UI.corner(12) })
	UI.icon("info", 22, COL.cyan, { Position = UDim2.fromOffset(14, 14), Parent = lesson })
	lessonL = UI.text({ FontFace = F.body, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(46, 12), Size = UDim2.new(1, -150, 1, -36), Parent = lesson })
	local srcL = UI.text({ Text = "↳ NASA Glenn · Beginner's Guide to Rockets", FontFace = F.mono, TextSize = 11, TextColor3 = COL.dim, Position = UDim2.new(0, 46, 1, -22), Size = UDim2.new(1, -60, 0, 16), Parent = lesson })
	local nextB = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.cyan, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(90, 34), Parent = lesson }, { UI.corner(8) })
	local nextL = UI.text({ FontFace = F.title, TextSize = 14, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = nextB })
	local function showLesson() lessonL.Text = ctx.t(LESSONS[lessonIdx]) end
	nextB.MouseButton1Click:Connect(function() lessonIdx = lessonIdx % #LESSONS + 1 showLesson() ctx.audio.sfx("ui", nil, 0.25) end)
	table.insert(ctx.refreshers, function() nextL.Text = ctx.t("lab_next") showLesson() if gui.Enabled then refresh() end end)
end

function R.open()
	if not gui then return end
	gui.Enabled = true
	UI.pop(panel, 0.95)
	for _, f in ctx.refreshers do pcall(f) end
	refresh()
	player:SetAttribute("CineFrozen", true)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = 0 end
end
function R.close()
	if not gui then return end
	gui.Enabled = false
	player:SetAttribute("CineFrozen", nil)
end
function R.isOpen() return gui and gui.Enabled end

function R.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	build()
	UIS.InputBegan:Connect(function(i) if i.KeyCode == Enum.KeyCode.Escape and gui.Enabled then R.close() end end)
	-- physical Rocket Lab kiosk in the Academy archive
	task.spawn(function()
		local kiosk = workspace:WaitForChild("Citadel"):WaitForChild("Archive"):WaitForChild("RocketLab", 30)
		local screen = kiosk and kiosk:FindFirstChild("Screen")
		if not screen then return end
		local pr = Instance.new("ProximityPrompt")
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "lab_open")
		pr.ActionText = ctx.t("lab_open")
		pr.Parent = screen
		pr.Triggered:Connect(R.open)
		table.insert(ctx.refreshers, function() pr.ActionText = ctx.t("lab_open") pr.ObjectText = "" end)
	end)
end

return R
