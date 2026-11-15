-- Architects of Nova: client. Display only — renders server state, never decides game rules.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local Nova = RS:WaitForChild("Nova")
local Remotes = Nova:WaitForChild("Remotes")
local Config = require(Nova.Shared.Config)
local Strings = require(Nova.Shared.Strings)
local Resources = require(Nova.Shared.Resources)
local ModulesData = require(Nova.Data.Modules)
local Launch = require(Nova.Data.Launch)
local Missions = require(Nova.Data.Missions)
local UI = require(script:WaitForChild("NovaUI"))
local Audio = require(script:WaitForChild("Audio"))
local Movement = require(script:WaitForChild("Movement"))
local Cinema = require(script:WaitForChild("Cinema"))
local Menu = require(script:WaitForChild("Menu"))
local World = require(script:WaitForChild("World"))
local Hud = require(script:WaitForChild("Hud"))
local MiniGame = require(script:WaitForChild("MiniGame"))
local Book = require(script:WaitForChild("Book"))
local RocketLab = require(script:WaitForChild("RocketLab"))
local UIS = game:GetService("UserInputService")
local Citadel = workspace:WaitForChild("Citadel")

local new, text, icon, panel, button = UI.new, UI.text, UI.icon, UI.panel, UI.button
local caps, upper = UI.caps, UI.upper
local GuiService = game:GetService("GuiService")
local COL, F = Config.Colors, Config.Fonts
local GAUGE_ICON = { mass = "mass", power = "power", budget = "budget", data = "data", comms = "comms", time = "time" }
local ROLE = {}
for _, r in Config.Roles do ROLE[r.id] = r; ROLE[r.console] = r end

-- language: Russian when the player's locale is Russian, otherwise English (RU/EN toggle in the HUD)
local lang = "en"
pcall(function()
	local a, b = string.lower(player.LocaleId or ""), string.lower(LocalizationService.RobloxLocaleId or "")
	if string.sub(a, 1, 2) == "ru" or string.sub(b, 1, 2) == "ru" then lang = "ru" end
end)
local t = Strings.get(lang)
local state: any = nil
local refreshers: { () -> () } = {}
local function onLang(f) table.insert(refreshers, f) f() end
------------------------------------------------------------------ prompts: localized text from server attribute keys (Key / ObjectKey)
local promptSet = setmetatable({}, { __mode = "k" })
local function applyPrompt(p)
	local k = p:GetAttribute("Key")
	if typeof(k) == "string" then
		local a = t(k)
		if a ~= k and p.ActionText ~= a then p.ActionText = a end
	end
	local ok = p:GetAttribute("ObjectKey")
	local o = typeof(ok) == "string" and t(ok) or ""
	if p.ObjectText ~= o then p.ObjectText = o end
end
local function locPrompt(p)
	if promptSet[p] then return end
	promptSet[p] = true
	applyPrompt(p)
	p:GetAttributeChangedSignal("Key"):Connect(function() applyPrompt(p) end)
	p:GetAttributeChangedSignal("ObjectKey"):Connect(function() applyPrompt(p) end)
end
for _, d in workspace:GetDescendants() do if d:IsA("ProximityPrompt") then locPrompt(d) end end
workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then task.defer(locPrompt, d) end end)
table.insert(refreshers, function() for p in promptSet do if p.Parent then applyPrompt(p) end end end)

local gui = new("ScreenGui", { Name = "NovaHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local hudLayer = new("Frame", { Name = "HudLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local uiScale = new("UIScale", { Parent = gui })

------------------------------------------------------------------ layout grid
-- Everything is laid out on a base canvas of 1280 x 720 px (8 px grid) and scaled as one piece.
-- L holds the live metrics in canvas px: the top band (centred on Roblox's own top-bar buttons), the row below
-- it, and a left column that starts under the Roblox buttons so nothing ever sits beneath them.
local L = { scale = 1, w = 1280, h = 720, bandY = 16, below = 68, safeTop = 72, left = 16, right = 16, touch = false, gw = 92 }
local layoutFns = {}
local function onLayout(fn) table.insert(layoutFns, fn) fn(L) end
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	if vp.X < 2 or vp.Y < 2 then return end
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.6, 1.5)
	uiScale.Scale = s
	local tb = GuiService.TopbarInset
	local bandH = tb.Height > 0 and tb.Height or 58
	local rightEnd = (tb.Max.X > 0 and tb.Max.X <= vp.X) and tb.Max.X or vp.X
	L.scale, L.w, L.h = s, vp.X / s, vp.Y / s
	L.bandY = math.max(8, math.floor((bandH * 0.5 + 5) / s - 20 + 0.5))
	L.below = L.bandY + 52
	L.safeTop = math.max(L.below, math.floor(bandH / s + 0.5) + 8)
	L.left = 16
	L.right = math.floor((vp.X - rightEnd) / s + 0.5) + 16
	L.robloxRight = math.floor(math.max(tb.Min.X, 0) / s + 0.5)
	L.touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	-- gauge width: the centred gauge row must clear the Roblox buttons (left) and the icon bar (right, 272 px)
	local half = L.w / 2 - math.max(L.robloxRight + 8, 272 + L.right) - 8
	L.gw = math.clamp(math.floor((half * 2 - 5 * 6) / 6), 76, 96)
	for _, fn in layoutFns do fn(L) end
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(rescale)

-- top-right icon bar: book, quests, NASA file, settings (added by their modules) + RU/EN toggle
local iconBar = new("Frame", { Name = "IconBar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = hudLayer }, {
	UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
onLayout(function(l) iconBar.Position = UDim2.new(1, -l.right, 0, l.bandY) end)

------------------------------------------------------------------ gauges
type GaugeW = { root: Frame, fill: Frame, value: TextLabel, ic: ImageLabel, st: UIStroke, status: string, big: boolean }
local gaugeSets: { { [string]: GaugeW } } = {}
local redGauges: { GaugeW } = {}

local function fmt(key: string, g)
	if key == "time" then
		local rem = math.max(0, g.cap - g.used)
		return string.format("%d:%02d", rem // 60, rem % 60)
	elseif key == "budget" or key == "data" then
		return string.format("%d/%d", math.floor(g.used + 0.5), math.floor(g.cap + 0.5))
	end
	if g.cap >= 10 then return string.format("%.0f/%.0f", g.used, g.cap) end
	return string.format("%.1f/%.1f", g.used, g.cap)
end

local function makeGauge(parent, key, order, big)
	local root, st, ic, value, fill, bar
	if big then
		-- in-world resource terminal cell (grid sized): name label, big mono value, 6 px bar
		root = new("Frame", { Name = key, LayoutOrder = order, BackgroundColor3 = COL.bg, BorderSizePixel = 0, Parent = parent })
		st = UI.stroke(COL.line, 2, 0.8, true)
		st.Parent = root
		ic = icon(GAUGE_ICON[key], 30, COL.text, { Position = UDim2.fromOffset(14, 12), Parent = root })
		local nameL = UI.label({ Text = t("g_" .. key), TextSize = 16, TextColor3 = COL.dim, Position = UDim2.fromOffset(54, 12), Size = UDim2.new(1, -68, 0, 30), Parent = root })
		table.insert(refreshers, function() nameL.Text = caps(t("g_" .. key)) end)
		value = text({ FontFace = F.mono, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -22), Size = UDim2.new(1, -28, 0, 34), Parent = root })
		bar = new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.new(1, -28, 0, 6), Parent = root })
	else
		root = panel({ Name = key, LayoutOrder = order, Size = UDim2.fromOffset(L.gw, 40), Parent = parent })
		st = root:FindFirstChildOfClass("UIStroke")
		ic = icon(GAUGE_ICON[key], 14, COL.text, { Position = UDim2.fromOffset(8, 7), Parent = root })
		value = text({ FontFace = F.mono, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(26, 5), Size = UDim2.new(1, -34, 0, 18), Parent = root })
		bar = new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 29), Size = UDim2.new(1, -16, 0, 3), Parent = root })
	end
	fill = new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar })
	-- 10 % margin tick (the NASA margin rule)
	new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.new(0, big and 2 or 1, 1, big and 8 or 4), Position = UDim2.new(0.9, 0, 0, big and -4 or -2), Parent = bar })
	return { root = root, fill = fill, value = value, ic = ic, st = st, status = "green", big = big == true }
end

local function gaugeSet(parent, big)
	local set = {}
	for i, k in Resources.ORDER do set[k] = makeGauge(parent, k, i, big) end
	table.insert(gaugeSets, set)
	return set
end

local gaugeBar = new("Frame", { Name = "Gauges", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(6 * 96 + 30, 40), Parent = hudLayer }, {
	UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local hudGauges = gaugeSet(gaugeBar)
onLayout(function(l)
	gaugeBar.Position = UDim2.new(0.5, 0, 0, l.bandY)
	gaugeBar.Size = UDim2.fromOffset(6 * l.gw + 30, 40)
	for _, w in hudGauges do w.root.Size = UDim2.fromOffset(l.gw, 40) end
end)

local GAUGE_TI = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
local function updateGauges()
	if not state or not state.gauges then return end
	table.clear(redGauges)
	for _, set in gaugeSets do
		for k, w in set do
			local g = state.gauges[k]
			local s = state.statuses[k] or "green"
			if g then
				local r = g.cap > 0 and math.clamp(g.used / g.cap, 0, 1) or (g.used > 0 and 1 or 0)
				TweenService:Create(w.fill, GAUGE_TI, { Size = UDim2.new(r, 0, 1, 0) }):Play()
				w.value.Text = fmt(k, g)
				w.status = s
				-- nominal = white; caution = yellow; fault = red (pulses)
				local c = (s == "red" and COL.red) or (s == "yellow" and COL.yellow) or COL.text
				w.fill.BackgroundColor3 = c
				w.fill.BackgroundTransparency = 0
				w.ic.ImageColor3 = c
				w.value.TextColor3 = c
				if s == "red" then
					table.insert(redGauges, w)
				else
					w.st.Color = COL.line
					w.st.Transparency = w.big and 0.8 or COL.lineT
				end
			end
		end
	end
end

local FLASH_TI = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function flashGauges(keys)
	for _, set in gaugeSets do
		for _, k in keys do
			local w = set[k]
			if w and w.status ~= "red" then
				w.st.Transparency = 0
				TweenService:Create(w.st, FLASH_TI, { Transparency = w.big and 0.8 or COL.lineT }):Play()
			end
		end
	end
end

------------------------------------------------------------------ mission header + phase steps (top-left, under the Roblox buttons)
local header = panel({ Name = "MissionHeader", Size = UDim2.fromOffset(290, 68), Parent = hudLayer })
onLayout(function(l) header.Position = UDim2.fromOffset(l.left, l.safeTop) end)
local mIdBox = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(32, 20), Parent = header }, { UI.corner(2), UI.stroke(COL.line, 1, 0.55) })
local mId = text({ FontFace = F.mono, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = mIdBox })
local mTitle = text({ FontFace = F.head, TextSize = 16, Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -150, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
local phaseName = UI.label({ Text = "", TextColor3 = COL.accent, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(90, 20), Parent = header })
local PHASES = { { "Briefing", "info" }, { "Build", "carry" }, { "Launch", "rocket" }, { "Ops", "headset" }, { "Debrief", "task" } }
-- 5 cells x 50 px + 4 gaps x 4 px = 266 px = header width 290 - 2 x 12 padding
local stepRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 38), Size = UDim2.fromOffset(266, 20), Parent = header }, {
	UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local steps = {}
for i, ph in PHASES do
	local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 20), LayoutOrder = i, Parent = stepRow })
	local ic = icon(ph[2], 14, COL.mute, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Parent = cell })
	local bar = new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.8, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 2), Parent = cell })
	steps[ph[1]] = { ic = ic, bar = bar, idx = i }
end

local function updateHeader()
	if not state then return end
	local m = Missions.byId[state.missionId]
	mId.Text = state.missionId
	mTitle.Text = m and upper(t(m.titleKey)) or ""
	local cur = 0
	for _, s in steps do if PHASES[s.idx][1] == state.phase then cur = s.idx end end
	for _, s in steps do
		local active, done = s.idx == cur, s.idx < cur
		s.ic.ImageColor3 = active and COL.text or (done and COL.dim or COL.mute)
		UI.setIcon(s.ic, done and "check" or PHASES[s.idx][2])
		s.bar.BackgroundColor3 = active and COL.accent or COL.line
		s.bar.BackgroundTransparency = active and 0 or (done and 0.2 or 0.8)
	end
	header.Visible = state.phase ~= "Hub"
	gaugeBar.Visible = state.phase == "Build" or state.phase == "Launch" or state.phase == "Ops"
	phaseName.Text = caps(t("phase_" .. state.phase))
end

------------------------------------------------------------------ task tracker (right, under the icon bar)
local tracker = panel({ Name = "Tasks", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(296, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = hudLayer })
onLayout(function(l) tracker.Position = UDim2.new(1, -l.right, 0, l.below) end)
UI.pad(12, 16, 12, 16).Parent = tracker
UI.list(Enum.FillDirection.Vertical, 8).Parent = tracker
local trHead = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = -2, Parent = tracker })
local trTitle = UI.label({ Text = "", Size = UDim2.new(1, -60, 1, 0), Parent = trHead })
local trCount = text({ FontFace = F.mono, TextSize = 12, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 16), Parent = trHead })
UI.rule({ LayoutOrder = -1, Parent = tracker })
local trRows = {}
local lastTaskDone = {}
local trExpanded = false
UIS.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.T then trExpanded = not trExpanded if state then task.defer(function() updateTracker() end) end end
end)

local function tag(parent, str, col)
	local f = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Parent = parent }, {
		UI.corner(2), UI.stroke(col, 1, 0.4), UI.pad(0, 6, 0, 6) })
	UI.label({ Text = str, TextSize = 9, TextColor3 = col, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), Parent = f })
	return f
end

function updateTracker()
	if not state or not state.tasks or state.phase == "Hub" or state.phase == "Field" or state.phase == "Board" or state.phase == "Flight" or state.phase == "Prep" then tracker.Visible = false return end
	tracker.Visible = true
	for _, r in trRows do r:Destroy() end
	table.clear(trRows)
	local done, nextTask = 0, nil
	for _, task_ in state.tasks do
		if task_.done then done += 1 elseif not nextTask then nextTask = task_ end
	end
	trCount.Text = string.format("%d/%d", done, #state.tasks)
	trTitle.Text = caps(t("tasks_title")) .. "   T"
	if not trExpanded then
		-- compact: only the next step (the full checklist is on the stand monitor in the hangar)
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = tracker })
		if nextTask then
			icon(nextTask.icon or "info", 16, COL.text, { Position = UDim2.fromOffset(0, 4), Parent = row })
			text({ Text = t(nextTask.key), TextSize = 15, FontFace = F.bodyBold, Size = UDim2.new(1, nextTask.extra and -76 or -24, 1, 0), Position = UDim2.fromOffset(24, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
			if nextTask.extra then tag(row, t(nextTask.rehearse and "rehearse_tag" or "extra_tag"), COL.dim) end
		else
			icon("check", 16, COL.green, { Position = UDim2.fromOffset(0, 4), Parent = row })
			text({ Text = t("mon_ok"), TextSize = 15, FontFace = F.bodyBold, TextColor3 = COL.green, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(24, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		end
		table.insert(trRows, row)
		return
	end
	for i, task_ in state.tasks do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = tracker })
		local box = new("Frame", { BackgroundColor3 = COL.text, BackgroundTransparency = task_.done and 0 or 1, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 5), Parent = row }, { UI.corner(2) })
		if task_.done then icon("check", 10, COL.dark, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = box })
		else UI.stroke(COL.line, 1, 0.5).Parent = box end
		icon(task_.icon or "info", 14, task_.done and COL.mute or COL.text, { Position = UDim2.fromOffset(22, 5), Parent = row })
		text({ Text = t(task_.key), TextSize = 14, FontFace = task_.done and F.body or F.bodyBold, TextColor3 = task_.done and COL.dim or COL.text,
			Size = UDim2.new(1, task_.extra and -96 or -44, 1, 0), Position = UDim2.fromOffset(44, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		if task_.extra then tag(row, t(task_.rehearse and "rehearse_tag" or "extra_tag"), COL.dim) end
		if task_.done and not lastTaskDone[task_.key] then UI.pop(row, 0.96) end
		lastTaskDone[task_.key] = task_.done
		table.insert(trRows, row)
	end
end

------------------------------------------------------------------ role badge + language toggle + carried part
local roleBadge = panel({ Name = "RoleBadge", Size = UDim2.fromOffset(240, 48), Parent = hudLayer })
local roleMark = new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(2, 24), Parent = roleBadge }) -- role colour: a small marker only
local roleIc = icon("headset", 18, COL.text, { Position = UDim2.fromOffset(16, 15), Parent = roleBadge })
local roleLbl = UI.label({ Text = "", TextSize = 10, Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -58, 0, 14), Parent = roleBadge })
local roleName = text({ FontFace = F.head, TextSize = 16, Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -58, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = roleBadge })
onLayout(function(l)
	if l.touch then
		-- phones: the thumbstick owns the bottom-left corner, so the badge stacks under the mission header
		roleBadge.AnchorPoint = Vector2.zero
		roleBadge.Position = UDim2.fromOffset(l.left, l.safeTop + 76)
	else
		roleBadge.AnchorPoint = Vector2.new(0, 1)
		roleBadge.Position = UDim2.new(0, l.left, 1, -72)
	end
end)

local langBtn = new("TextButton", { Name = "LangToggle", AutoButtonColor = false, Text = "", BorderSizePixel = 0, BackgroundColor3 = COL.panel, BackgroundTransparency = COL.panelT,
	Size = UDim2.fromOffset(72, 40), LayoutOrder = 9, Parent = iconBar }, { UI.corner(4), UI.stroke(COL.line, 1, COL.lineT) })
local langPill = new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(32, 32), Parent = langBtn }, { UI.corner(2) })
local langRU = text({ Text = "RU", FontFace = F.display, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(32, 32), ZIndex = 2, Parent = langBtn })
local langEN = text({ Text = "EN", FontFace = F.display, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(36, 4), Size = UDim2.fromOffset(32, 32), ZIndex = 2, Parent = langBtn })

local carryChip = panel({ Name = "Carry", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = hudLayer })
UI.pad(0, 16, 0, 14).Parent = carryChip
local carryRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = carryChip }, {
	UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
local carryLbl = UI.label({ Text = "", TextSize = 11, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), LayoutOrder = 1, Parent = carryRow })
UI.rule({ Size = UDim2.fromOffset(1, 16), LayoutOrder = 2, Parent = carryRow })
local carryIc = icon("info", 16, COL.text, { LayoutOrder = 3, Parent = carryRow })
local carryText = text({ FontFace = F.bodyBold, TextSize = 15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), LayoutOrder = 4, Parent = carryRow })

------------------------------------------------------------------ banner + toasts
local banner = new("Frame", { Name = "Banner", BackgroundColor3 = COL.bg, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(0, 56), AutomaticSize = Enum.AutomaticSize.X, Parent = hudLayer }, { UI.corner(4), UI.pad(0, 32, 0, 32) })
local bannerText = text({ FontFace = F.head, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 56), TextTransparency = 1, Parent = banner })
local bannerLine = new("Frame", { BackgroundColor3 = COL.accent, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(0, 2), Parent = banner })
local bannerToken = 0
local BAN_IN = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BAN_OUT = TweenInfo.new(0.45)
local function showBanner(str, color)
	bannerToken += 1
	local my = bannerToken
	bannerText.Text = caps(str)
	bannerText.TextColor3 = COL.text
	bannerText.TextTransparency = 0
	banner.BackgroundTransparency = 0.25
	-- the line carries the meaning: green = good, red/yellow = problem, anything else = the accent
	bannerLine.BackgroundColor3 = (color == COL.green or color == COL.red or color == COL.yellow) and color or COL.accent
	bannerLine.BackgroundTransparency = 0
	bannerLine.Size = UDim2.fromOffset(0, 2)
	TweenService:Create(bannerLine, BAN_IN, { Size = UDim2.new(1, 0, 0, 2) }):Play()
	UI.pop(banner, 0.98)
	task.delay(2.6, function()
		if my ~= bannerToken then return end
		TweenService:Create(bannerText, BAN_OUT, { TextTransparency = 1 }):Play()
		TweenService:Create(banner, BAN_OUT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(bannerLine, BAN_OUT, { BackgroundTransparency = 1 }):Play()
	end)
end

local toastList = new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(416, 240), Parent = gui }, {
	UI.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
})
local toastN = 0
local FADE = TweenInfo.new(0.35)
local function toast(iconName, str, status)
	toastN += 1
	local c = (status == "green" or status == "red" or status == "yellow") and COL[status] or COL.text
	local f = panel({ Name = "Toast", Size = UDim2.fromOffset(400, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = toastN, Parent = toastList })
	new("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 2, 1, -20), Parent = f })
	icon(iconName or "info", 16, c, { Position = UDim2.fromOffset(16, 14), Parent = f })
	local lbl = text({ Text = str, FontFace = F.bodyBold, TextSize = 15, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(44, 0), Parent = f })
	UI.pad(12, 0, 12, 0).Parent = f
	lbl.Position = UDim2.fromOffset(44, 0)
	UI.pop(f, 0.97)
	task.delay(4.2, function()
		if not f.Parent then return end
		for _, d in f:GetDescendants() do
			if d:IsA("TextLabel") then TweenService:Create(d, FADE, { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then TweenService:Create(d, FADE, { ImageTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then TweenService:Create(d, FADE, { Transparency = 1 }):Play()
			elseif d:IsA("Frame") then TweenService:Create(d, FADE, { BackgroundTransparency = 1 }):Play() end
		end
		TweenService:Create(f, FADE, { BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		f:Destroy()
	end)
	-- at most 4 on screen: drop the oldest
	local n = 0
	for _, c2 in toastList:GetChildren() do if c2:IsA("Frame") then n += 1 end end
	while n > 4 do
		local oldest, lo = nil, math.huge
		for _, c2 in toastList:GetChildren() do if c2:IsA("Frame") and c2.LayoutOrder < lo then oldest, lo = c2, c2.LayoutOrder end end
		if not oldest then break end
		oldest:Destroy()
		n -= 1
	end
end

------------------------------------------------------------------ co-op interaction widget (bottom-centre, during ops / rehearsal)
-- 4 chips x 100 px + 3 gaps x 8 px = 424 px = widget 456 - 2 x 16 padding
local coop = panel({ Name = "Coop", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(456, 88), Visible = false, Parent = hudLayer })
local coopTitle = UI.label({ Text = "", TextColor3 = COL.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 16), Parent = coop })
local coopRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 36), Parent = coop }, {
	UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local KIND_KEY = { press = "ev_contact_wait", sync = "ev_deploy_wait", sequence = "ev_edl_wait", relay = "ev_relay_wait" }
local function updateCoop()
	local w = state and state.waiting
	coop.Visible = w ~= nil
	if not w then return end
	for _, c in coopRow:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	coopTitle.Text = caps((w.rehearsal and (t("p_rehearse") .. " · ") or "") .. t(KIND_KEY[w.kind] or "ev_contact_wait"))
	for i, name in w.consoles do
		local r = ROLE[name]
		local pressed = table.find(w.pressed or {}, name) ~= nil
		local isNext = (w.kind == "sequence" and i == w.step) or (w.kind == "relay" and w.lit == name)
		local chip = new("Frame", { BackgroundColor3 = pressed and COL.text or COL.panel, BackgroundTransparency = pressed and 0 or 0.1, Size = UDim2.fromOffset(100, 40), LayoutOrder = i, Parent = coopRow }, { UI.corner(3) })
		UI.stroke(isNext and COL.accent or COL.line, 1, isNext and 0 or (pressed and 1 or 0.6)).Parent = chip
		new("Frame", { BackgroundColor3 = r and r.color or COL.text, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(2, 20), Parent = chip })
		local fg = pressed and COL.dark or COL.text
		local x = 10
		if w.kind == "sequence" then text({ Text = tostring(i), FontFace = F.mono, TextSize = 12, TextColor3 = isNext and COL.accent or (pressed and COL.dark or COL.dim), Size = UDim2.fromOffset(12, 40), Position = UDim2.fromOffset(10, 0), Parent = chip }) x = 24 end
		icon(pressed and "check" or (r and r.icon or "info"), 16, fg, { Position = UDim2.fromOffset(x, 12), Parent = chip })
		text({ Text = t(name), FontFace = F.bodyBold, TextSize = 13, TextColor3 = fg, Size = UDim2.new(1, -(x + 24), 1, 0), Position = UDim2.fromOffset(x + 22, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip })
	end
end

------------------------------------------------------------------ briefing: mission card
local briefCard = panel({ Name = "Brief", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(576, 128), Visible = false, Parent = hudLayer })
onLayout(function(l) briefCard.Position = UDim2.new(0.5, 0, 0, l.below) end)
local bcId = UI.label({ Text = "", TextColor3 = COL.accent, TextSize = 11, Size = UDim2.new(1, -168, 0, 16), Position = UDim2.fromOffset(24, 16), Parent = briefCard })
local bcTitle = text({ FontFace = F.head, TextSize = 28, Size = UDim2.new(1, -168, 0, 36), Position = UDim2.fromOffset(24, 34), TextTruncate = Enum.TextTruncate.AtEnd, Parent = briefCard })
local bcBrief = text({ FontFace = F.body, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -168, 0, 40), Position = UDim2.fromOffset(24, 74), Parent = briefCard })
UI.rule({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -136, 0, 16), Size = UDim2.new(0, 1, 1, -32), Parent = briefCard })
local bcPic = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(104, 96), Parent = briefCard })
icon("orbit", 48, COL.text, { Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Parent = bcPic })
local bcOrbit = text({ FontFace = F.mono, TextSize = 11, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 60), Parent = bcPic })
local briefToken = 0
local function showBriefing(missionId)
	local m = Missions.byId[missionId]
	if not m then return end
	briefToken += 1
	local my = briefToken
	local o = Launch.orbits[m.orbit]
	bcId.Text = caps(missionId .. "  ·  " .. t("phase_Briefing"))
	bcTitle.Text = upper(t(m.titleKey))
	bcBrief.Text = t(m.briefKey)
	bcOrbit.Text = o and t(o.nameKey) or ""
	briefCard.Visible = true
	UI.pop(briefCard, 0.97)
	task.delay(4.5, function() if my == briefToken then briefCard.Visible = false end end)
end

------------------------------------------------------------------ overlays: shared dim layer
local dim = new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Parent = gui })
local function overlay(w, h)
	local p = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), ZIndex = 21, Visible = false, Parent = gui })
	p.BackgroundColor3 = COL.bg
	p.BackgroundTransparency = 0.04
	return p
end
local function setZ(root, z) for _, d in root:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = z end end end
local function closeButton(parent)
	return button({ name = "Close", style = "secondary", icon = "cross", text = "", size = UDim2.fromOffset(40, 40), anchor = Vector2.new(1, 0), position = UDim2.new(1, -24, 0, 24), parent = parent })
end

------------------------------------------------------------------ mission select
-- 4 cards x 188 px + 3 gaps x 8 px = 776 px = panel 840 - 2 x 32 padding
local sel = overlay(840, 496)
sel.Name = "MissionSelect"
local selKick = UI.label({ Text = "", TextColor3 = COL.accent, TextSize = 11, Position = UDim2.fromOffset(32, 28), Size = UDim2.fromOffset(500, 16), Parent = sel })
local selTitle = text({ FontFace = F.head, TextSize = 24, Position = UDim2.fromOffset(32, 44), Size = UDim2.fromOffset(600, 30), Parent = sel })
local selClose = closeButton(sel)
local selGrid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 96), Size = UDim2.new(1, -64, 1, -128), Parent = sel }, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(188, 180), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left }),
})
local function closeSel() sel.Visible = false; dim.Visible = false end
selClose.MouseButton1Click:Connect(closeSel)
local function showSelect()
	for _, c in selGrid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	selKick.Text = caps(t("game_title"))
	selTitle.Text = caps(t("missions"))
	for i, id in Missions.order do
		local m = Missions.byId[id]
		local unlocked = state and (m.order or 0) <= (state.unlocked or 0)
		local stars = state and state.completed and state.completed[id] or 0
		local card = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = COL.panel, BackgroundTransparency = unlocked and 0 or 0.4, BorderSizePixel = 0, LayoutOrder = i, Parent = selGrid }, { UI.corner(3) })
		local cst = UI.stroke(COL.line, 1, unlocked and 0.7 or 0.9)
		cst.Parent = card
		text({ Text = id, FontFace = F.mono, TextSize = 12, TextColor3 = unlocked and COL.text or COL.mute, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(60, 16), Parent = card })
		if m.final then UI.label({ Text = "Final", TextSize = 10, TextColor3 = COL.accent, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(80, 16), Parent = card }) end
		icon(unlocked and (m.final and "target" or "rocket") or "lock", 40, unlocked and COL.text or COL.mute, { Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), Parent = card })
		text({ Text = upper(t(m.titleKey)), FontFace = F.head, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = unlocked and COL.text or COL.mute,
			Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 40), Parent = card })
		local srow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 16), Parent = card }, { UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
		if unlocked then for s = 1, 3 do icon(s <= stars and "star" or "star_o", 16, s <= stars and COL.text or COL.mute, { LayoutOrder = s, Parent = srow }) end
		else UI.label({ Text = t("locked"), TextSize = 11, TextColor3 = COL.mute, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = srow }) end
		if unlocked then
			card.MouseEnter:Connect(function() cst.Transparency = 0 end)
			card.MouseLeave:Connect(function() cst.Transparency = 0.7 end)
			card.MouseButton1Click:Connect(function() Remotes.Request:FireServer({ action = "start", missionId = id }); closeSel() end)
		end
	end
	setZ(sel, 22)
	dim.Visible = true
	sel.Visible = true
	UI.pop(sel, 0.98)
end

------------------------------------------------------------------ debrief / flight report
local deb = overlay(904, 568)
deb.Name = "Debrief"
local debKicker = UI.label({ Text = "", TextSize = 11, Position = UDim2.fromOffset(32, 28), Size = UDim2.new(1, -240, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = deb })
local debTitle = text({ FontFace = F.head, TextSize = 32, Position = UDim2.fromOffset(32, 46), Size = UDim2.new(1, -240, 0, 40), Parent = deb })
local debStars = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 0, 36), Size = UDim2.fromOffset(160, 40), Parent = deb }, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
UI.rule({ Position = UDim2.fromOffset(32, 96), Size = UDim2.new(1, -64, 0, 1), Parent = deb })
local debBody = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 112), Size = UDim2.new(1, -64, 1, -200), Parent = deb }, { UI.list(Enum.FillDirection.Vertical, 8) })
local debButtons = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, -64, 0, 48), Parent = deb }, { UI.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

local function section(parent, key, order)
	return UI.label({ Text = t(key), TextSize = 11, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = order, Parent = parent })
end
local lastDebrief: any = nil
local function showDebrief(d)
	if state and state.phase ~= "Debrief" then return end -- team already moved on
	lastDebrief = d
	for _, c in debBody:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for _, c in debButtons:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for _, c in debStars:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local m = Missions.byId[d.missionId]
	debKicker.Text = caps(t("debrief_title") .. "  ·  " .. d.missionId .. "  " .. t(m.titleKey) .. "  ·  " .. t("attempt") .. " " .. tostring(d.attempt or 1))
	debTitle.Text = upper(t(d.win and "res_win" or "res_more"))
	debTitle.TextColor3 = COL.text
	if d.win then for s = 1, 3 do icon(s <= d.stars and "star" or "star_o", 32, s <= d.stars and COL.text or COL.mute, { LayoutOrder = s, Parent = debStars }) end end
	-- chain of causes
	section(debBody, "why", 1)
	local chain = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100), LayoutOrder = 2, Parent = debBody }, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local n = #d.chain
	local w = math.min(144, math.floor((840 - (n - 1) * 32) / math.max(n, 1)))
	for i, c in d.chain do
		local col = c.ok and COL.green or (c.cascade and COL.mute or COL.red)
		local card = new("Frame", { BackgroundColor3 = COL.panel, BackgroundTransparency = c.cascade and 0.5 or 0, Size = UDim2.fromOffset(w, 96), LayoutOrder = i * 2, Parent = chain }, { UI.corner(3) })
		UI.stroke(col, 1, c.cascade and 0.5 or 0.2).Parent = card
		new("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Parent = card })
		icon(c.icon, 20, col, { Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), Parent = card })
		text({ Text = t(c.key), FontFace = F.bodyBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = c.cascade and COL.dim or COL.text, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 40), Parent = card })
		if i < n then icon("arrow", 16, COL.mute, { LayoutOrder = i * 2 + 1, Parent = chain }) end
	end
	-- new tasks instead of "mission lost"
	if d.newTasks and #d.newTasks > 0 then
		section(debBody, "new_tasks", 3)
		local nt = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = debBody }, { UI.list(Enum.FillDirection.Horizontal, 8) })
		for i, tk in d.newTasks do
			local row = new("Frame", { BackgroundColor3 = COL.panel, BackgroundTransparency = 0, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = nt }, { UI.corner(3), UI.pad(0, 16, 0, 12) })
			UI.stroke(COL.line, 1, 0.55).Parent = row
			local inner = new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), Parent = row }, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
			icon(tk.icon or "task", 16, COL.text, { LayoutOrder = 1, Parent = inner })
			text({ Text = t(tk.key), FontFace = F.bodyBold, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), LayoutOrder = 2, Parent = inner })
		end
	end
	-- hints (the third is a real NASA case: it carries the accent)
	section(debBody, "hints", 5)
	local hr = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 6, Parent = debBody }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	local hw = math.floor((840 - 16) / 3)
	for i, key in d.hints do
		local nasa = i == 3
		local card = new("Frame", { BackgroundColor3 = COL.panel, Size = UDim2.fromOffset(hw, 72), LayoutOrder = i, Parent = hr }, { UI.corner(3) })
		UI.stroke(nasa and COL.accent or COL.line, 1, nasa and 0.2 or 0.7).Parent = card
		icon(nasa and "star" or "info", 16, nasa and COL.accent or COL.dim, { Position = UDim2.fromOffset(14, 14), Parent = card })
		if nasa then UI.label({ Text = "NASA", TextSize = 10, TextColor3 = COL.accent, Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(28, 14), Parent = card }) end
		text({ Text = t(key), FontFace = F.bodyBold, TextSize = 13, TextWrapped = true, Size = UDim2.new(1, -56, 1, -16), Position = UDim2.fromOffset(44, 8), Parent = card })
	end
	-- memory core reward
	if d.core then
		local rc = ({ common = COL.text, rare = COL.cyan, legendary = COL.yellow })[d.core.rarity] or COL.text
		local core = new("Frame", { BackgroundColor3 = COL.panel, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 7, Parent = debBody }, { UI.corner(3) })
		UI.stroke(rc, 1, 0.4).Parent = core
		icon("spark", 16, rc, { Position = UDim2.fromOffset(14, 12), Parent = core })
		UI.label({ Text = t("rarity_" .. d.core.rarity), TextSize = 11, TextColor3 = rc, Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(150, 40), Parent = core })
		text({ Text = t(d.core.key), FontFace = F.bodyBold, TextSize = 14, Size = UDim2.new(1, -208, 1, 0), Position = UDim2.fromOffset(196, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = core })
	end
	-- actions
	local function act(name, action)
		Remotes.Request:FireServer({ action = action })
		deb.Visible = false; dim.Visible = false
	end
	if d.win then
		if d.nextId then
			local b = button({ name = "NextBtn", style = "primary", icon = "arrow", text = t("btn_next"), size = UDim2.fromOffset(264, 48), order = 1, parent = debButtons })
			b.MouseButton1Click:Connect(function() act("next", "next") end)
		end
		local h = button({ name = "HubBtn", style = d.nextId and "secondary" or "primary", icon = "home", text = t("btn_hub"), size = UDim2.fromOffset(232, 48), order = 2, parent = debButtons })
		h.MouseButton1Click:Connect(function() act("hub", "hub") end)
	else
		local r = button({ name = "RetryBtn", style = "primary", icon = "retry", text = t("btn_retry"), size = UDim2.fromOffset(264, 48), order = 1, parent = debButtons })
		r.MouseButton1Click:Connect(function() act("retry", "retry") end)
		local h = button({ name = "HubBtn", style = "secondary", icon = "home", text = t("btn_hub"), size = UDim2.fromOffset(232, 48), order = 2, parent = debButtons })
		h.MouseButton1Click:Connect(function() act("hub", "hub") end)
	end
	setZ(deb, 22)
	dim.Visible = true
	deb.Visible = true
	UI.pop(deb, 0.98)
end

------------------------------------------------------------------ memory core popup + ending
local function showCore(missionId)
	local m = Missions.byId[missionId]
	if not m or not m.core then return end
	toast("spark", t(m.core.key), m.core.rarity == "legendary" and "yellow" or "cyan")
end

local ending = overlay(824, 568)
ending.Name = "Ending"
local function showEnding(which)
	if typeof(which) == "boolean" then which = which and "reconcile" or "lesson" end
	local good = which ~= "lesson"
	Audio.music("victory")
	for _, c in ending:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	icon(good and "star" or "check", 48, COL.text, { Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), Parent = ending })
	UI.label({ Text = t("campaign_done"), TextSize = 11, TextColor3 = COL.accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 16), Parent = ending })
	text({ Text = upper(t("end_" .. which .. "_title")), FontFace = F.head, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 40), Parent = ending })
	text({ Text = t("end_" .. which .. "_text"), FontFace = F.body, TextSize = 18, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.fromOffset(64, 172), Size = UDim2.new(1, -128, 0, 48), Parent = ending })
	UI.rule({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.fromOffset(64, 1), Parent = ending })
	UI.label({ Text = t("credits"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 252), Size = UDim2.new(1, 0, 0, 16), Parent = ending })
	text({ Text = t("credits_body"), FontFace = F.body, TextSize = 14, TextColor3 = COL.text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Position = UDim2.fromOffset(64, 276), Size = UDim2.new(1, -128, 0, 176), Parent = ending })
	local b = button({ name = "EndBtn", style = "primary", icon = "home", text = t("btn_hub"), size = UDim2.fromOffset(264, 48), anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -32), parent = ending })
	b.MouseButton1Click:Connect(function() ending.Visible = false; dim.Visible = false end)
	deb.Visible = false
	setZ(ending, 24)
	dim.Visible = true
	ending.Visible = true
	UI.pop(ending, 0.98)
end

------------------------------------------------------------------ world UI: resource terminal, rocket check, mission screen, consoles, racks, pads
-- in-world screens follow the same system: black, white type, hairlines (2 px here: they are read from a distance)
local function worldBoard()
	-- live resource gauges on a floor-standing terminal next to the stand (a real object, not a floating board)
	local term = Citadel.Hangar:WaitForChild("ResourceTerminal", 10)
	local scr = term and term:WaitForChild("Screen", 5)
	if not scr then return end
	local sg = new("SurfaceGui", { Name = "ResourceTerminalGui", Face = Enum.NormalId.Front, LightInfluence = 0.15, Brightness = 1.4, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 48, Adornee = scr, Parent = gui })
	local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(16) })
	local head = UI.label({ Text = "", TextColor3 = COL.text, TextSize = 16, Size = UDim2.new(1, -24, 0, 20), Parent = bg })
	onLang(function() head.Text = caps(t("term_title")) end)
	new("Frame", { BackgroundColor3 = COL.green, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 5), Size = UDim2.fromOffset(10, 10), Parent = bg }, { UI.corner(5) })
	new("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(32, 2), Parent = bg })
	local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), Parent = bg }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0.333, -8), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	gaugeSet(grid, true)
end

local launchUI: any = {}
local function launchScreen()
	local scr = Citadel.Hangar.LaunchConsole:WaitForChild("Screen")
	local sg = new("SurfaceGui", { Name = "RocketCheck", Face = Enum.NormalId.Front, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 70, Adornee = scr, Parent = gui })
	local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(20) })
	launchUI.rocketIc = icon("rocket", 32, COL.text, { Position = UDim2.fromOffset(0, 2), Parent = bg })
	launchUI.rocket = text({ FontFace = F.head, TextSize = 34, Position = UDim2.fromOffset(46, -4), Size = UDim2.new(1, -46, 0, 40), Parent = bg })
	launchUI.orbit = text({ FontFace = F.body, TextSize = 20, TextColor3 = COL.dim, Position = UDim2.fromOffset(46, 38), Size = UDim2.new(1, -46, 0, 24), Parent = bg })
	new("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(40, 2), Parent = bg })
	local bar = new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.85, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 124), Parent = bg })
	launchUI.fill = new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.new(0.5, 0, 1, 0), Parent = bar })
	new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 16), Position = UDim2.new(0.8, -1, 0, -8), Parent = bar })
	launchUI.arrow = icon("arrow", 24, COL.text, { Rotation = 90, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Parent = bar })
	launchUI.value = text({ FontFace = F.mono, TextSize = 26, Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 30), Parent = bg })
	launchUI.fair = text({ FontFace = F.bodyBold, TextSize = 18, TextColor3 = COL.red, Position = UDim2.fromOffset(0, 192), Size = UDim2.new(1, 0, 0, 24), Parent = bg })
	launchUI.keys = text({ FontFace = F.mono, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), Text = "", Parent = bg })
end
local function updateLaunch()
	if not state or not launchUI.fill then return end
	local r = Launch.rockets[state.rocketId]
	local o = Launch.orbits[state.orbitId]
	launchUI.rocket.Text = r and upper(t(r.nameKey)) or ""
	launchUI.orbit.Text = o and t(o.nameKey) or ""
	local cap, mass = state.rocketCapacity or 0, state.massKg or 0
	local frac = cap > 0 and math.clamp(mass / cap * 0.8, 0, 1) or 1
	local col = mass > cap and COL.red or (mass > cap * 0.9 and COL.yellow or COL.text)
	launchUI.fill.Size = UDim2.new(frac, 0, 1, 0)
	launchUI.fill.BackgroundColor3 = col
	launchUI.arrow.Position = UDim2.new(frac, 0, 0, -6)
	launchUI.arrow.ImageColor3 = col
	launchUI.value.Text = string.format("%.1f / %.1f %s", mass, cap, t("u_kg"))
	launchUI.value.TextColor3 = col
	local fits = (state.maxSize or 1) <= (state.fairing or 1)
	launchUI.fair.Text = fits and "" or t("fairing_fail")
	launchUI.keys.Text = ((#(state.orbits or {}) > 1) and "E  " .. t("p_rocket") .. "    G  " .. t("p_orbit") or "E  " .. t("p_rocket")) .. "    F  " .. t("p_launch")
end

local bigUI: any = {}
local function bigScreen()
	local scr = Citadel.Control:WaitForChild("BigScreen")
	local sg = new("SurfaceGui", { Name = "MissionScreen", Face = Enum.NormalId.Left, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 32, Adornee = scr, Parent = gui })
	local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(32) })
	local orb = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 360), Position = UDim2.fromOffset(8, 32), Parent = bg })
	new("Frame", { BackgroundColor3 = Color3.fromRGB(28, 30, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), Parent = orb }, { UI.corner(200), UI.stroke(COL.line, 2, 0.5, true) })
	new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), Parent = orb }, { UI.corner(200), UI.stroke(COL.line, 2, 0.6, true) })
	bigUI.sat = new("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Parent = orb })
	bigUI.kicker = UI.label({ Text = "", TextColor3 = COL.accent, TextSize = 22, Position = UDim2.fromOffset(416, 32), Size = UDim2.new(1, -424, 0, 28), Parent = bg })
	bigUI.title = text({ FontFace = F.head, TextSize = 54, Position = UDim2.fromOffset(416, 64), Size = UDim2.new(1, -424, 0, 64), Parent = bg })
	bigUI.events = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(416, 152), Size = UDim2.new(1, -424, 0, 112), Parent = bg }, { UI.list(Enum.FillDirection.Horizontal, 16) })
	bigUI.wait = text({ FontFace = F.head, TextSize = 36, TextColor3 = COL.text, Position = UDim2.fromOffset(416, 296), Size = UDim2.new(1, -424, 0, 44), Parent = bg })
end
local function updateBig()
	if not state or not bigUI.events then return end
	local m = Missions.byId[state.missionId]
	bigUI.kicker.Text = caps(state.missionId .. "  ·  " .. t("phase_" .. state.phase))
	bigUI.title.Text = m and upper(t(m.titleKey)) or ""
	for _, c in bigUI.events:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	for i, e in state.ops or {} do
		local col = e.ok and COL.green or (e.cascade and COL.mute or COL.red)
		local f = new("Frame", { BackgroundColor3 = COL.bg, Size = UDim2.fromOffset(112, 112), LayoutOrder = i, Parent = bigUI.events }, { UI.corner(4), UI.stroke(col, 3, 0.2, true) })
		icon(e.icon, 56, col, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = f })
	end
	bigUI.wait.Text = state.waiting and upper(t(KIND_KEY[state.waiting.kind] or "ev_contact_wait")) or ""
end

local consoleUI = {}
local function consoleScreens()
	for _, m in Citadel.Control.Consoles:GetChildren() do
		local scr = m:FindFirstChild("Screen")
		local r = ROLE[m.Name]
		if scr and r then
			local sg = new("SurfaceGui", { Face = Enum.NormalId.Back, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, Adornee = scr, Parent = gui })
			local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg })
			local ring = new("Frame", { BackgroundColor3 = COL.bg, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(80, 80), Parent = bg }, { UI.corner(40) })
			local rst = UI.stroke(COL.line, 2, 0.5, true)
			rst.Parent = ring
			icon(r.icon, 44, COL.text, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ring })
			new("Frame", { BackgroundColor3 = r.color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102), Size = UDim2.fromOffset(32, 3), Parent = bg }) -- role colour marker
			local name = text({ FontFace = F.head, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 34), Parent = bg })
			local st = UI.label({ Text = "", TextSize = 16, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 148), Size = UDim2.new(1, 0, 0, 22), Parent = bg })
			consoleUI[m.Name] = { name = name, st = st, ring = ring, rst = rst, id = r.id }
		end
	end
end
local function updateConsoles()
	for cname, c in consoleUI do
		c.name.Text = upper(t("role_" .. c.id))
		local w = state and state.waiting
		local active = w and table.find(w.consoles, cname) and (w.kind ~= "relay" or w.lit == cname)
		local pressed = w and table.find(w.pressed or {}, cname)
		c.st.Text = pressed and "" or (active and caps(t("now")) or (state and state.rehearsal and caps(t("p_rehearse")) or ""))
		c.st.TextColor3 = active and COL.accent or COL.dim
		c.rst.Color = active and COL.accent or COL.line
		c.rst.Transparency = active and 0 or 0.5
	end
end

local rackGuis = {}
local function rackLabels()
	for _, g in rackGuis do g:Destroy() end
	rackGuis = {}
	for _, bay in Citadel.Hangar.RackBays:GetChildren() do
		local lk = bay:GetAttribute("LabelKey")
		local cat = bay:GetAttribute("Category")
		local sign = bay:FindFirstChild("Sign")
		if lk and sign then
			local sg = new("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0.35, Brightness = 1.2, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, Adornee = sign, Parent = gui })
			local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg })
			new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0), Parent = bg })
			icon(Config.CategoryIcon[cat] or "info", 56, COL.text, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 28, 0.5, 0), Parent = bg })
			local l = text({ FontFace = F.head, TextSize = 44, TextColor3 = COL.text, Position = UDim2.fromOffset(108, 0), Size = UDim2.new(1, -250, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bg })
			text({ Text = (bay.Name:gsub("Bay", "B-0")), FontFace = F.mono, TextSize = 28, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 120, 1, 0), Parent = bg })
			local function setL() l.Text = upper(t(lk)) end
			table.insert(refreshers, setL)
			setL()
			table.insert(rackGuis, sg)
		end
	end
end

local SLOT_ICON = { top = "comms", side = "panel", bottom = "target" }
local updateAssembly
local padGlows = {}
local slotHints = {}
-- every slot has its own part type: a label over each mounting post says what goes there; the matching one lights
-- up (accent) while you carry that part, installed ones turn green
local function slotDefOf(sid)
	local fdef = state and state.frame and Launch.frames[state.frame]
	if fdef then for _, sl in fdef.slots do if sl.id == sid then return sl end end end
	return nil
end
local function hookFrame(frame)
	for _, bb in slotHints do bb:Destroy() end -- labels of a previous Frame model
	padGlows = {}
	slotHints = {}
	for _, p in frame:WaitForChild("Pads"):GetChildren() do
		local sid = p:GetAttribute("SlotId")
		if p.Name == "PadGlow" then
			padGlows[sid] = padGlows[sid] or {}
			table.insert(padGlows[sid], p)
		elseif p.Name:sub(1, 5) == "Post_" then
			local bb = new("BillboardGui", { Name = "SlotHint", Size = UDim2.fromOffset(184, 40), StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0), LightInfluence = 0, MaxDistance = 70, AlwaysOnTop = true, Adornee = p, Enabled = false, Parent = gui })
			bb:SetAttribute("SlotId", sid)
			table.insert(slotHints, bb)
			local c = new("Frame", { Name = "Card", BackgroundColor3 = COL.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = bb }, { UI.corner(4) })
			new("UIStroke", { Name = "Stroke", Color = COL.line, Transparency = 0.6, Thickness = 1, Parent = c })
			icon(SLOT_ICON[sid] or "computer", 18, COL.text, { Name = "Icon", Position = UDim2.fromOffset(12, 11), Parent = c })
			text({ Name = "Label", Text = "", FontFace = F.display, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = c })
		end
	end
end
local function updatePads()
	if not state then return end
	for sid, list in padGlows do for _, g in list do g.Color = state.installed[sid] and COL.green or COL.text end end
	local carrying = player:GetAttribute("Carrying")
	local d = carrying and ModulesData.defs[carrying]
	local building = state.phase == "Build"
	local li = (lang == "ru") and 1 or 2
	for _, bb in slotHints do
		local sid = bb:GetAttribute("SlotId")
		local sl = slotDefOf(sid)
		local done = state.installed[sid] ~= nil
		local match = d and sl and sl.accepts[d.category] and not done
		bb.Enabled = building and sl ~= nil
		local c = bb:FindFirstChild("Card")
		if c and sl then
			local lb, ic, st = c:FindFirstChild("Label"), c:FindFirstChild("Icon"), c:FindFirstChild("Stroke")
			local name = sl.label and sl.label[li] or sid
			if lb then lb.Text = caps(name) end
			if ic then UI.setIcon(ic, done and "check" or (sl.icon or SLOT_ICON[sid] or "computer")) end
			local col = done and COL.green or (match and COL.accent or COL.text)
			if lb then lb.TextColor3 = col end
			if ic then ic.ImageColor3 = col end
			if st then st.Color = col st.Transparency = match and 0 or 0.6 st.Thickness = match and 2 or 1 end
			bb.Size = match and UDim2.fromOffset(208, 44) or UDim2.fromOffset(184, 40)
			c.BackgroundTransparency = (d and not match and not done) and 0.45 or 0.12
		end
	end
	if updateAssembly then updateAssembly() end
end

-- assembly progress (top-centre, under the gauges): one segment per part the mission needs, filled when installed.
-- 420 px bar: title 16..136, segments 136..340 (204 px), count 348..404
local ASM_SEG_W = 204
local asm = panel({ Name = "Assembly", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 40), Visible = false, Parent = hudLayer })
onLayout(function(l) asm.Position = UDim2.new(0.5, 0, 0, l.below) end)
local asmTitle = UI.label({ Text = "", TextColor3 = COL.text, TextSize = 12, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(112, 40), Parent = asm })
local asmCount = text({ Text = "", FontFace = F.mono, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(56, 40), Parent = asm })
local asmSegs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(136, 8), Size = UDim2.fromOffset(ASM_SEG_W, 24), Parent = asm }, {
	UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
updateAssembly = function()
	if not state then return end
	local m = Missions.byId[state.missionId]
	asm.Visible = state.phase == "Build" and m ~= nil
	if not asm.Visible then return end
	local groups = {}
	if m.racks and #m.racks > 0 then
		for _, r in m.racks do table.insert(groups, { ids = r.ids, cat = r.category }) end
	else
		for _, tk in state.tasks or {} do if tk.cat then table.insert(groups, { cat = tk.cat }) end end
	end
	local done = 0
	for _, g in groups do
		for _, id in state.installed do
			local dd = ModulesData.defs[id]
			if (g.ids and table.find(g.ids, id)) or (not g.ids and dd and dd.category == g.cat) then g.done = true end
		end
		if g.done then done += 1 end
	end
	for _, ch in asmSegs:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	local n = math.max(1, #groups)
	local w = math.floor((ASM_SEG_W - 4 * (n - 1)) / n)
	for k, g in groups do
		local seg = new("Frame", { LayoutOrder = k, Size = UDim2.fromOffset(w, 24), BackgroundColor3 = g.done and COL.text or COL.line, BackgroundTransparency = g.done and 0 or 0.9, BorderSizePixel = 0, Parent = asmSegs }, { UI.corner(2) })
		icon(Config.CategoryIcon[g.cat] or "computer", 14, g.done and COL.dark or COL.dim, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = seg })
	end
	asmTitle.Text = caps(t("ui_assembly"))
	asmCount.Text = done .. "/" .. #groups
	asmCount.TextColor3 = (done == #groups and #groups > 0) and COL.green or COL.text
end

if Citadel.Hangar:FindFirstChild("Frame") then hookFrame(Citadel.Hangar.Frame) end
-- the Frame model is (re)built when Build starts (and may stream in late): re-hook its slot labels every time
Citadel.Hangar.ChildAdded:Connect(function(c) if c.Name == "Frame" then task.defer(function() hookFrame(c) updatePads() end) end end)

------------------------------------------------------------------ per-frame: guide paths, red gauge pulse, satellite
-- only the active path animates; the others are set once when the goal changes (no per-frame work for them)
local paths = Citadel:WaitForChild("Paths")
local clock = 0
local lastGoal, activeChevrons = nil, {}
local function setGoal(goal)
	lastGoal = goal
	table.clear(activeChevrons)
	for _, m in paths:GetChildren() do
		local active = (m.Name == goal)
		for _, ch in m:GetChildren() do
			if ch.Name == "Chevron" then
				if active then table.insert(activeChevrons, ch) else ch.Transparency = 0.9 end
			elseif ch.Name == "Edge" then
				ch.Transparency = active and 0.1 or 0.7
			end
		end
	end
end
paths.ChildAdded:Connect(function() lastGoal = nil end)
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local goal = state and state.goal or ""
	if goal ~= lastGoal then setGoal(goal) end
	for _, ch in activeChevrons do
		local i = ch:GetAttribute("Index") or 0
		ch.Transparency = 0.85 - ((math.sin(clock * 5 - i * 0.7) + 1) / 2) * 0.75
	end
	if #redGauges > 0 then
		local pulse = (math.sin(clock * 6) + 1) / 2
		for _, w in redGauges do
			w.fill.BackgroundTransparency = pulse * 0.5
			w.st.Color = COL.red
			w.st.Transparency = 0.15 + pulse * 0.5
		end
	end
	if bigUI.sat then
		local on = state ~= nil and (state.phase == "Ops" or state.phase == "Debrief")
		bigUI.sat.Visible = on
		if on then
			local a = clock * 0.6
			bigUI.sat.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.43, 0.5 + math.sin(a) * 0.43)
		end
	end
end)

local function shake(duration)
	if Audio.settings.shake == false then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t1 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t1
		if k > duration or not hum.Parent then hum.CameraOffset = Vector3.zero conn:Disconnect() return end
		local amp = math.sin(k / duration * math.pi) * 0.5
		hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * amp
	end)
end

------------------------------------------------------------------ text refresh
local function refreshTexts()
	if state then
		local roleId = state.roles and state.roles[tostring(player.UserId)]
		local r = ROLE[roleId or "commander"]
		if r then
			roleMark.BackgroundColor3 = r.color
			UI.setIcon(roleIc, r.icon)
			roleName.Text = upper(t("role_" .. r.id))
		end
	end
	roleLbl.Text = caps(t("ui_your_role"))
	local ru = lang == "ru"
	langPill.Position = ru and UDim2.fromOffset(4, 4) or UDim2.fromOffset(36, 4)
	langRU.TextColor3 = ru and COL.dark or COL.dim
	langEN.TextColor3 = ru and COL.dim or COL.dark
	local carrying = player:GetAttribute("Carrying")
	local d = carrying and ModulesData.defs[carrying]
	carryChip.Visible = d ~= nil
	if d then
		carryLbl.Text = caps(t("ui_carrying"))
		carryText.Text = t(d.nameKey)
		UI.setIcon(carryIc, Config.CategoryIcon[d.category] or "info")
	end
	for _, f in refreshers do f() end
	updateHeader()
	updateTracker()
	updateCoop()
	updateLaunch()
	updateBig()
	updateConsoles()
	if updateAssembly then updateAssembly() end
	if lastDebrief and deb.Visible then showDebrief(lastDebrief) end
end
local function setLang(l)
	lang = l
	t = Strings.get(lang)
	player:SetAttribute("Lang", lang)
	refreshTexts()
end
player:SetAttribute("Lang", lang)
player:GetAttributeChangedSignal("Carrying"):Connect(function() refreshTexts() updatePads() end)
langBtn.MouseButton1Click:Connect(function()
	setLang(lang == "ru" and "en" or "ru")
	pcall(function() Audio.sfx("ui", nil, 0.4) end)
end)

------------------------------------------------------------------ remotes
Remotes.State.OnClientEvent:Connect(function(s)
	local prev = state
	state = s
	World.onState(s)
	Menu.refresh()
	if prev and prev.phase ~= s.phase and not Cinema.locked() then Audio.music(defaultMusic()) end
	updateGauges()
	updatePads()
	refreshTexts()
	if prev and prev.phase == "Debrief" and s.phase ~= "Debrief" then deb.Visible = false; if not ending.Visible then dim.Visible = false end end
	if rackDirty then rackDirty = false task.delay(0.3, rackLabels) end
end)

Remotes.Cue.OnClientEvent:Connect(function(c)
	World.onCue(c)
	if c.type == "banner" then showBanner(t(c.key), COL[c.color] or COL.text)
	elseif c.type == "toast" then toast(c.icon, t(c.key) .. (c.extraKey and (": " .. t(c.extraKey)) or ""), c.status or "cyan")
	elseif c.type == "dialogStart" then Cinema.dialogStart(c.where)
	elseif c.type == "dialog" then Cinema.dialog(c.who, c.key, c.time)
	elseif c.type == "dialogEnd" then Cinema.dialogEnd()
	elseif c.type == "vote" then Cinema.vote(c)
	elseif c.type == "voteCast" then Cinema.voteCast(c)
	elseif c.type == "voteResult" then Cinema.voteResult(c)
	elseif c.type == "cutscene" then if Cinema[c.name] then task.spawn(Cinema[c.name], c.data or {}) end
	elseif c.type == "event" then toast(c.icon, t(c.key), c.ok and "green" or "red")
	elseif c.type == "flash" then flashGauges(c.gauges)
	elseif c.type == "shake" then shake(c.duration or 2)
	elseif c.type == "briefing" then showBriefing(c.missionId)
	elseif c.type == "missionSelect" then showSelect()
	elseif c.type == "debrief" then task.delay(0.8, showDebrief, c)
	elseif c.type == "core" then showCore(c.missionId)
	elseif c.type == "ending" then showEnding(c.ending or c.good)
	elseif c.type == "rocketCheck" then if not c.ok then shake(0.6) end
	elseif c.type == "goNoGo" then Hud.poll(c)
	elseif c.type == "radio" then Cinema.radio(c.who, c.key, c.time)
	end
end)

------------------------------------------------------------------ ambient telemetry on control-room wall screens (props, purely visual)
-- monochrome bars; every fourth screen carries the accent. One shared loop updates all of them 4 times a second.
local wallBars = {}
local function wallScreens()
	local k = 0
	for _, p in Citadel.Control:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Screen") then
			k += 1
			local col = (k % 4 == 0) and COL.accent or COL.text
			local face = p.Position.Z > 0 and Enum.NormalId.Front or Enum.NormalId.Back
			local sg = new("SurfaceGui", { Face = face, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, Adornee = p, Parent = gui })
			local bg = new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(12) })
			UI.label({ Text = ({ "DSN-1", "ORB-2", "PWR-3", "SCI-4", "COM-5", "NAV-6" })[(k - 1) % 6 + 1], TextSize = 14, TextColor3 = col, Size = UDim2.new(1, 0, 0, 18), Parent = bg })
			new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.8, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 1), Parent = bg })
			local bars = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), Parent = bg }, {
				UI.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom),
			})
			for i = 1, 18 do
				local b = new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.new(0, 8, 0.5, 0), LayoutOrder = i, Parent = bars })
				table.insert(wallBars, { b = b, i = i, ph = k * 1.7 })
			end
		end
	end
	task.spawn(function()
		while gui.Parent do
			for _, e in wallBars do
				e.ph += 0.25
				e.b.Size = UDim2.new(0, 8, 0.25 + 0.7 * (math.sin(e.ph + e.i * 0.5) * 0.5 + 0.5) * (0.6 + 0.4 * math.random()), 0)
			end
			task.wait(0.25)
		end
	end)
end

------------------------------------------------------------------ modules context + boot
local hudHidden = false
function defaultMusic()
	if not state then return "hub" end
	if state.phase == "Ops" then return "tension" end
	if state.phase == "Field" then return "field" end
	return "hub"
end
local ctxObj = {
	UI = UI, COL = COL, F = F, gui = gui, hudLayer = hudLayer, iconBar = iconBar, refreshers = refreshers, audio = Audio,
	layout = L, onLayout = onLayout,
	t = function(k) return t(k) end,
	lang = function() return lang end,
	state = function() return state end,
	toast = function(i, s, st) toast(i, s, st) end,
	setHudHidden = function(on) hudHidden = on hudLayer.Visible = not on toastList.Visible = not on Hud.setGearVisible(not on) if on then Hud.hidePoll() end end,
	locked = function() return Cinema.locked() end,
	menuOpen = function() return Menu.isOpen() end,
	toggleLang = function() setLang(lang == "ru" and "en" or "ru") end,
	defaultMusic = function() return defaultMusic() end,
	onMenuClosed = function() refreshTexts() Audio.music("hub") end,
}
Cinema.init(ctxObj)
Movement.init(ctxObj)
World.init(ctxObj)
Menu.init(ctxObj)
Hud.init(ctxObj)
MiniGame.init(ctxObj)
ctxObj.openRocketLab = function() RocketLab.open() end
ctxObj.openBook = function() Book.toggle() end
Book.init(ctxObj)
RocketLab.init(ctxObj)
pcall(function() require(script:WaitForChild("Buggy")).init() end)
-- suit shop (NovaClient.Outfitter, owned by the Outfitter workstream): sets ctxObj.openOutfitter()
task.spawn(function() pcall(function() local m = script:WaitForChild("Outfitter", 30) if m then require(m).init(ctxObj) end end) end)
task.spawn(function()
	task.wait(1)
	-- players arriving through a lobby teleport skip the intro and land on the lobby screen
	if player:GetAttribute("InLobby") then Menu.open() else Cinema.intro(function() Menu.open() end) end
end)
task.spawn(function()
	worldBoard()
	launchScreen()
	bigScreen()
	consoleScreens()
	wallScreens()
	task.wait(2)
	rackLabels()
	refreshTexts()
end)
