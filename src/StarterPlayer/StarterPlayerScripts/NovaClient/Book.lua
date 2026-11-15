-- Book (client): Parts Book collection (25 parts, unlocked by picking them up) + Rockets with capacity per orbit.
-- Every entry: what it does, a real NASA example, a fun fact, the source. Key B.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Config = require(RS.Nova.Shared.Config)
local Launch = require(RS.Nova.Data.Launch)
local PartInfo = require(RS.Nova.Data.PartInfo)
local ModulesData = require(RS.Nova.Data.Modules)

local B = {}
local player = Players.LocalPlayer
local ctx, UI, COL, F
local panel, grid, detail, countL, barFill, tabParts, tabRockets, btn
local profile
local tab = "parts"
local selected
local ORDER = { "obc", "obc_hard", "vex_unit", "battery_s", "battery_l", "battery_xl", "panel_body", "panel_wing", "panel_array", "panel_giant",
	"rtg", "antenna_uhf", "antenna_s", "hga", "camera", "rad_sensor", "neutron_spec", "radar", "mirror_fold", "mirror_solid", "vault", "edl_kit", "edl_crane", "impactor_s", "impactor_l" }
local ROCKETS = { "kestrel", "heron", "condor", "titan" }
local ORBITS = { { "LEO400", "orbit_leo400" }, { "GEO", "orbit_geo" }, { "LUNAR_POLAR", "orbit_lunar_polar" }, { "MARS", "orbit_mars" }, { "EUROPA_DIRECT", "orbit_europa_direct" } }

local function L() return ctx.t("on") == "ВКЛ" and 1 or 2 end
local function seen(id) return profile and profile.seen and profile.seen[id] end

local function section(parent, titleKey, body, order, col)
	if not body then return end
	UI.text({ Text = string.upper(ctx.t(titleKey)), FontFace = F.display, TextSize = 10, TextColor3 = col or COL.amber, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = order, Parent = parent })
	UI.text({ Text = body, FontFace = F.body, TextSize = 15, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order + 1, Parent = parent })
end

local function statRow(parent, iconName, label, value, col, order)
	local r = UI.new("Frame", { BackgroundColor3 = COL.panel2, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Parent = parent }, { UI.corner(6) })
	UI.icon(iconName, 14, col, { Position = UDim2.fromOffset(8, 5), Parent = r })
	UI.text({ Text = label, FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0.6, -28, 1, 0), Parent = r })
	UI.text({ Text = value, FontFace = F.mono, TextSize = 13, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -8, 1, 0), Parent = r })
end

local function showDetail()
	for _, c in detail:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local l = L()
	if not selected then
		UI.text({ Text = ctx.t("book_pick"), FontFace = F.body, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 20), Parent = detail })
		return
	end
	if tab == "parts" then
		local id = selected
		local d = ModulesData.defs[id]
		local info = PartInfo[id]
		if not seen(id) then
			UI.text({ Text = "?", FontFace = F.title, TextSize = 60, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1, Parent = detail })
			UI.text({ Text = ctx.t("book_locked"), FontFace = F.bodyBold, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2, Parent = detail })
			return
		end
		UI.text({ Text = string.upper(ctx.t("cat_" .. d.category)), FontFace = F.display, TextSize = 10, TextColor3 = COL.cyan, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0, Parent = detail })
		UI.text({ Text = ctx.t(d.nameKey), FontFace = F.title, TextSize = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1, Parent = detail })
		local stats = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = detail }, { UI.list(Enum.FillDirection.Vertical, 3) })
		local o = 0
		local function s(i, k, v, c) o += 1 statRow(stats, i, ctx.t(k), v, c, o) end
		s("mass", "g_mass", string.format("%.2g kg", d.massKg), COL.text)
		s("budget", "g_budget", tostring(d.cost) .. " ¢", COL.yellow)
		if d.powerGenW then s("power", "i_gen", string.format("+%g W", d.powerGenW), COL.green) end
		if d.rtgW then s("power", "i_rtg", string.format("+%g W", d.rtgW), COL.green) end
		if d.powerUseW then s("power", "i_use", string.format("-%g W", d.powerUseW), COL.amber) end
		if d.batteryWh then s("battery", "i_store", string.format("%g Wh", d.batteryWh), COL.green) end
		if d.link then s("comms", "g_comms", string.format("%g", d.link), COL.cyan) end
		if d.dataMB then s("data", "g_data", string.format("%g MB", d.dataMB), COL.violet) end
		if info then
			section(detail, "book_what", info.what[l], 10)
			section(detail, "book_real", info.real[l], 12, COL.cyan)
			section(detail, "book_fact", info.fact[l], 14, COL.green)
			UI.text({ Text = "↳ " .. info.src, FontFace = F.mono, TextSize = 12, TextColor3 = COL.dim, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 20, Parent = detail })
		end
	else
		local rid = selected
		local r = Launch.rockets[rid]
		local info = PartInfo["rocket_" .. rid]
		UI.text({ Text = string.upper(ctx.t("book_rocket")), FontFace = F.display, TextSize = 10, TextColor3 = COL.cyan, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0, Parent = detail })
		UI.text({ Text = ctx.t(r.nameKey), FontFace = F.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1, Parent = detail })
		local stats = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = detail }, { UI.list(Enum.FillDirection.Vertical, 3) })
		statRow(stats, "budget", ctx.t("g_budget"), tostring(r.cost) .. " ¢", COL.yellow, 1)
		statRow(stats, "rocket", ctx.t("book_fairing"), tostring(r.fairing), COL.text, 2)
		for i, ob in ORBITS do
			local cap = r.capacityKg[ob[1]]
			statRow(stats, "orbit", ctx.t(ob[2]), cap and cap > 0 and (cap .. " kg") or "—", cap and cap > 0 and COL.green or COL.dim, 2 + i)
		end
		if info then
			section(detail, "book_what", info.what[l], 10)
			section(detail, "book_real", info.real[l], 12, COL.cyan)
			section(detail, "book_fact", info.fact[l], 14, COL.green)
			UI.text({ Text = "↳ " .. info.src, FontFace = F.mono, TextSize = 12, TextColor3 = COL.dim, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 20, Parent = detail })
		end
	end
end

local function render()
	if not panel or not panel.Visible then return end
	for _, c in grid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local n = 0
	for _, id in ORDER do if seen(id) then n += 1 end end
	countL.Text = string.format(ctx.t("book_count"), n, #ORDER)
	barFill.Size = UDim2.fromScale(n / #ORDER, 1)
	tabParts.BackgroundColor3 = tab == "parts" and COL.amber or COL.panel2
	tabRockets.BackgroundColor3 = tab == "rockets" and COL.amber or COL.panel2
	local list = tab == "parts" and ORDER or ROCKETS
	for i, id in list do
		local isSeen = tab == "rockets" or seen(id)
		local d = tab == "parts" and ModulesData.defs[id] or nil
		local card = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = (selected == id) and COL.panel or COL.panel2, LayoutOrder = i, Parent = grid }, { UI.corner(10) })
		UI.stroke(selected == id and COL.amber or COL.line, selected == id and 2 or 1, selected == id and 0 or 0.85).Parent = card
		local iconName = tab == "parts" and (Config.CategoryIcon[d.category] or "info") or "rocket"
		local col = isSeen and (d and d.color or COL.amber) or COL.dim
		if isSeen then
			UI.icon(iconName, 30, col, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = card })
			local name = tab == "parts" and ctx.t(d.nameKey) or ctx.t(Launch.rockets[id].nameKey)
			UI.text({ Text = name, FontFace = F.bodyBold, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 42), Size = UDim2.new(1, -8, 0, 30), Parent = card })
		else
			UI.text({ Text = "?", FontFace = F.title, TextSize = 30, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), Parent = card })
			UI.icon(iconName, 16, COL.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Parent = card })
		end
		card.MouseButton1Click:Connect(function() selected = id ctx.audio.sfx("ui", nil, 0.3) render() end)
	end
	showDetail()
end

function B.toggle()
	if not panel then return end
	panel.Visible = not panel.Visible
	if panel.Visible then UI.pop(panel, 0.95) render() end
end

local function build()
	btn = UI.iconButton({ name = "BookButton", icon = "instrument", key = "B", order = 1, parent = ctx.iconBar or ctx.gui:FindFirstChild("HudLayer") or ctx.gui })
	btn.MouseButton1Click:Connect(B.toggle)
	panel = UI.panel({ Name = "PartsBook", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 560), Visible = false, ZIndex = 18, Parent = ctx.gui }, 18)
	panel.BackgroundColor3 = COL.bg
	panel.BackgroundTransparency = 0
	local title = UI.text({ FontFace = F.display, TextSize = 16, TextColor3 = COL.amber, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(420, 24), Parent = panel })
	table.insert(ctx.refreshers, function() title.Text = string.upper(ctx.t("book_title")) end)
	local close = UI.new("ImageButton", { BackgroundTransparency = 1, Image = Config.IconSheet.image, ImageRectSize = Vector2.new(128, 128), ImageRectOffset = Config.iconRect("cross"), ImageColor3 = COL.dim,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(28, 28), Parent = panel })
	close.MouseButton1Click:Connect(B.toggle)
	local function tabBtn(x, key, which)
		local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(x, 54), Size = UDim2.fromOffset(130, 34), Parent = panel }, { UI.corner(10) })
		local l = UI.text({ FontFace = F.title, TextSize = 15, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = b })
		table.insert(ctx.refreshers, function() l.Text = ctx.t(key) end)
		b.MouseButton1Click:Connect(function() tab = which selected = nil render() end)
		return b
	end
	tabParts = tabBtn(24, "book_parts", "parts")
	tabRockets = tabBtn(162, "book_rockets", "rockets")
	local lab = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.cyan, Position = UDim2.fromOffset(300, 54), Size = UDim2.fromOffset(170, 34), Parent = panel }, { UI.corner(10) })
	local labL = UI.text({ FontFace = F.title, TextSize = 15, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = lab })
	table.insert(ctx.refreshers, function() labL.Text = ctx.t("lab_open") end)
	lab.MouseButton1Click:Connect(function() panel.Visible = false if ctx.openRocketLab then ctx.openRocketLab() end end)
	countL = UI.text({ FontFace = F.mono, TextSize = 13, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(480, 56), Size = UDim2.fromOffset(80, 16), Parent = panel })
	local bar = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 45, 56), Position = UDim2.fromOffset(480, 76), Size = UDim2.fromOffset(80, 6), Parent = panel }, { UI.corner(3) })
	barFill = UI.new("Frame", { BackgroundColor3 = COL.green, Size = UDim2.fromScale(0, 1), Parent = bar }, { UI.corner(3) })
	grid = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 100), Size = UDim2.fromOffset(536, 440), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = panel }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(98, 84), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	detail = UI.new("ScrollingFrame", { BackgroundColor3 = COL.panel, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.fromOffset(576, 54), Size = UDim2.fromOffset(300, 486), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = panel }, {
		UI.corner(12), UI.pad(14, 14, 14, 14), UI.list(Enum.FillDirection.Vertical, 6) })
	table.insert(ctx.refreshers, render)
end

function B.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	build()
	RS.Nova.Remotes.Cue.OnClientEvent:Connect(function(msg)
		if typeof(msg) ~= "table" then return end
		if msg.type == "profile" then profile = msg.profile render()
		elseif msg.type == "discover" then
			local d = ModulesData.defs[msg.id]
			ctx.toast("instrument", ctx.t("book_new") .. ": " .. (d and ctx.t(d.nameKey) or msg.id) .. (msg.reward and msg.reward > 0 and ("  +" .. msg.reward .. " ¢") or ""), "green")
		end
	end)
	task.spawn(function()
		local k = workspace:WaitForChild("Citadel"):WaitForChild("Archive"):WaitForChild("PartsBook", 30)
		local screen = k and k:FindFirstChild("Screen")
		if not screen then return end
		local pr = Instance.new("ProximityPrompt")
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "book_btn")
		pr.ActionText = ctx.t("book_title")
		pr.Parent = screen
		pr.Triggered:Connect(function() if not panel.Visible then B.toggle() end end)
		table.insert(ctx.refreshers, function() pr.ActionText = ctx.t("book_title") pr.ObjectText = "" end)
	end)
	UIS.InputBegan:Connect(function(i, gp)
		if gp or ctx.locked() then return end
		if i.KeyCode == Enum.KeyCode.B then B.toggle() end
		if i.KeyCode == Enum.KeyCode.Escape and panel.Visible then panel.Visible = false end
	end)
end

return B
