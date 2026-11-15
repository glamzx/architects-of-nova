-- World: in-world screens and guidance. Stand monitor (what the spacecraft still needs), tutorial arrows,
-- emergency timers, field objective markers, location lighting, NASA live boards, Zero-G trainer,
-- Grok's shop, rank/achievement toasts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Remotes = RS.Nova.Remotes
local ModulesData = require(RS.Nova.Data.Modules)
local Launch = require(RS.Nova.Data.Launch)
local Missions = require(RS.Nova.Data.Missions)
local ProgressData = require(RS.Nova.Data.Progress)
local Config = require(RS.Nova.Shared.Config)

local W = {}
local player = Players.LocalPlayer
local ctx, UI, COL, F
local Citadel = workspace:WaitForChild("Citadel")
local state

------------------------------------------------------------------ lighting presets per location
local presets = {}
local function capture()
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	presets.hub = { exposure = Lighting.ExposureCompensation, ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		atmo = a and { Density = a.Density, Offset = a.Offset, Color = a.Color, Decay = a.Decay, Haze = a.Haze, Glare = a.Glare } or nil, tint = cc and cc.TintColor }
	-- realistic grading per world: airless bodies fade into black (hides the map edge without fake fog colour),
	-- Mars has its butterscotch dust haze, Europa a cold thin glow
	local vacuum = { Density = 0.3, Offset = 0, Color = Color3.fromRGB(12, 12, 14), Decay = Color3.fromRGB(0, 0, 0), Haze = 0, Glare = 0 }
	-- open space: a thin black veil so the other worlds (thousands of studs away) fade into the dark; stars stay visible
	local space = { Density = 0.2, Offset = 0, Color = Color3.fromRGB(4, 4, 6), Decay = Color3.fromRGB(0, 0, 0), Haze = 0, Glare = 0 }
	presets.orbit = { exposure = 0.4, ClockTime = 14, Brightness = 2.4, Ambient = Color3.fromRGB(40, 42, 48), OutdoorAmbient = Color3.fromRGB(70, 72, 82), atmo = space, tint = Color3.fromRGB(250, 250, 255) }
	presets.moon = { exposure = 0.2, ClockTime = 8.6, Brightness = 2.4, Ambient = Color3.fromRGB(26, 26, 30), OutdoorAmbient = Color3.fromRGB(46, 46, 52), atmo = vacuum, tint = Color3.fromRGB(246, 246, 250) }
	presets.mars = { exposure = 0.55, ClockTime = 15.6, Brightness = 2.1, Ambient = Color3.fromRGB(58, 42, 36), OutdoorAmbient = Color3.fromRGB(132, 92, 74),
		atmo = { Density = 0.42, Offset = 0.1, Color = Color3.fromRGB(196, 146, 112), Decay = Color3.fromRGB(128, 78, 54), Haze = 2, Glare = 0.15 }, tint = Color3.fromRGB(255, 240, 226) }
	presets.europa = { exposure = 0.6, ClockTime = 11, Brightness = 1.6, Ambient = Color3.fromRGB(40, 46, 58), OutdoorAmbient = Color3.fromRGB(86, 100, 120),
		atmo = { Density = 0.22, Offset = 0, Color = Color3.fromRGB(150, 168, 190), Decay = Color3.fromRGB(70, 86, 110), Haze = 0.6, Glare = 0 }, tint = Color3.fromRGB(238, 244, 255) }
	presets.asteroid = { exposure = 0.35, ClockTime = 13, Brightness = 2.2, Ambient = Color3.fromRGB(26, 26, 30), OutdoorAmbient = Color3.fromRGB(50, 50, 56), atmo = vacuum, tint = Color3.fromRGB(250, 248, 246) }
	presets.l2 = presets.orbit
end
local function applyPreset(id)
	ctx.audio.ambience(presets[id] and id or "hub")
	local p = presets[id] or presets.hub
	local t = TweenInfo.new(1.2)
	TweenService:Create(Lighting, t, { Brightness = p.Brightness, Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient }):Play()
	Lighting.ClockTime = p.ClockTime
	TweenService:Create(Lighting, t, { ExposureCompensation = p.exposure or presets.hub.exposure or 0 }):Play()
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a and p.atmo then TweenService:Create(a, t, p.atmo):Play() end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc and p.tint then TweenService:Create(cc, t, { TintColor = p.tint }):Play() end
end

------------------------------------------------------------------ stand monitor
local mon = {}
local function buildMonitor()
	local scr = Citadel.Hangar:WaitForChild("StandMonitor"):WaitForChild("Screen")
	local sg = UI.new("SurfaceGui", { Name = "StandMonitorGui", Face = Enum.NormalId.Front, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 80, Adornee = scr, Parent = ctx.gui })
	local bg = UI.new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(32) })
	mon.title = UI.label({ Text = "", TextColor3 = COL.text, TextSize = 24, Size = UDim2.new(1, 0, 0, 32), Parent = bg })
	UI.new("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 36), Size = UDim2.fromOffset(48, 3), Parent = bg })
	mon.name = UI.text({ FontFace = F.head, TextSize = 44, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 56), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bg })
	mon.slots = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(0.5, -16, 1, -200), Parent = bg }, { UI.list(Enum.FillDirection.Vertical, 8) })
	mon.tasks = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 16, 0, 120), Size = UDim2.new(0.5, -16, 1, -200), Parent = bg }, { UI.list(Enum.FillDirection.Vertical, 8) })
	mon.next = UI.text({ FontFace = F.head, TextSize = 34, TextColor3 = COL.text, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 56), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bg })
end
local function row(parent, iconName, txt, col, sub)
	local f = UI.new("Frame", { BackgroundColor3 = COL.bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56), Parent = parent }, { UI.corner(4) })
	UI.stroke(col, 2, col == COL.text and 0.75 or 0.3, true).Parent = f
	UI.new("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(0, 4, 1, -24), Parent = f })
	UI.icon(iconName, 30, col, { Position = UDim2.fromOffset(18, 13), Parent = f })
	UI.text({ Text = txt, FontFace = F.bodyBold, TextSize = 24, Position = UDim2.fromOffset(62, sub and 4 or 0), Size = UDim2.new(1, -74, 0, sub and 28 or 56), TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
	if sub then UI.label({ Text = sub, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.fromOffset(62, 32), Size = UDim2.new(1, -74, 0, 20), Parent = f }) end
end
local SLOT_LABEL = { top = "comms", side = "panel", bottom = "target" }
local function updateMonitor()
	if not mon.title or not state then return end
	local m = Missions.byId[state.missionId]
	mon.title.Text = UI.caps(ctx.t("mon_title"))
	mon.name.Text = state.missionId .. "  ·  " .. UI.upper(ctx.t(m.titleKey))
	for _, c in mon.slots:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	for _, c in mon.tasks:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local frame = Launch.frames[state.frame or m.frame]
	for _, s in frame.slots do
		local id = state.installed[s.id]
		if id then
			local d = ModulesData.defs[id]
			row(mon.slots, Config.CategoryIcon[d.category] or "info", ctx.t(d.nameKey), COL.green, s.id)
		else
			local cats = {}
			for cat in s.accepts do table.insert(cats, ctx.t("cat_" .. cat)) end
			row(mon.slots, SLOT_LABEL[s.id] or "computer", ctx.t("mon_need") .. ": " .. table.concat(cats, " / "), COL.text, s.id)
		end
	end
	local nextKey
	for _, tk in state.tasks or {} do
		row(mon.tasks, tk.done and "check" or tk.icon, ctx.t(tk.key), tk.done and COL.green or COL.text, tk.extra and ctx.t("extra_tag") or nil)
		if not tk.done and not nextKey then nextKey = tk.key end
	end
	mon.next.Text = nextKey and UI.upper(ctx.t("mon_next") .. ": " .. ctx.t(nextKey)) or UI.upper(ctx.t("mon_ok"))
	mon.next.TextColor3 = nextKey and COL.text or COL.green
end

------------------------------------------------------------------ guidance arrow (tutorial / urgent / field)
-- Screen-space guide: a chevron that orbits the player's character on screen and points where to go,
-- with the distance in metres. Nothing floats over world objects.
local guideGui, guideRoot, guideDisc, guideStroke, guideArrow, guideDist, hint
local function buildArrow()
	guideGui = Instance.new("ScreenGui")
	guideGui.Name = "NovaGuide"
	guideGui.IgnoreGuiInset = true
	guideGui.ResetOnSpawn = false
	guideGui.DisplayOrder = -1
	guideGui.Parent = player:WaitForChild("PlayerGui")
	guideRoot = UI.new("Frame", { Name = "Guide", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(48, 48), Visible = false, Parent = guideGui })
	guideDisc = UI.new("Frame", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Parent = guideRoot }, { UI.corner(20) })
	guideStroke = UI.stroke(COL.text, 1, 0.1)
	guideStroke.Parent = guideDisc
	guideArrow = UI.icon("arrow", 22, COL.text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = guideDisc })
	guideDist = UI.text({ FontFace = F.mono, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(80, 14), TextStrokeTransparency = 0.6, Parent = guideRoot })
	hint = UI.panel({ Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = ctx.hudLayer or ctx.gui })
	UI.pad(0, 16, 0, 14).Parent = hint
	local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = hint }, { UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	W.hintIcon = UI.icon("target", 16, COL.text, { LayoutOrder = 1, Parent = r })
	W.hintText = UI.text({ FontFace = F.bodyBold, TextSize = 15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), LayoutOrder = 2, Parent = r })
end

local guideTarget, guideKey, guideColor = nil, nil, nil
local function setGuide(pos, key, color)
	guideTarget, guideKey, guideColor = pos, key, color or COL.amber
end

local function posOf(inst)
	if not inst then return nil end
	if inst:IsA("Model") then return inst:GetBoundingBox().Position end
	if inst:IsA("BasePart") then return inst.Position end
	return nil
end

local urgentNow = {}
local function computeGuide()
	if not state then return setGuide(nil) end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- emergencies first
	for spot, u in urgentNow do
		if u.field then return setGuide(u.pos, "tut_fix", COL.red) end
		local s = Citadel:FindFirstChild("UrgentSpots") and Citadel.UrgentSpots:FindFirstChild(spot)
		if s then return setGuide(s.Position, "tut_fix", COL.red) end
	end
	if state.phase == "Prep" then
		local prep = Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad") and Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("Prep")
		if prep then
			local carrying = player:GetAttribute("Carrying")
			if carrying == "item:beacon" then
				local h = prep.Spots:FindFirstChild("CargoHatch")
				return setGuide(h and h.Position, "o_kit", COL.amber)
			end
			local best, bd = nil, math.huge
			for _, s in prep.Spots:GetChildren() do
				if s:GetAttribute("Need") or (s.Name == "KitCart" and state.field and state.field.objectives and #state.field.objectives > 1 and not state.field.objectives[2].done) then
					local d = hrp and (s.Position - hrp.Position).Magnitude or 0
					if d < bd and s.Name ~= "CargoHatch" then best, bd = s, d end
				end
			end
			return setGuide(best and best.Position, "prep_rocket", COL.amber)
		end
	end
	if state.phase == "Board" then
		local z = Citadel.Hangar.LaunchArea:FindFirstChild("CrewPad") and Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("BoardZone")
		return setGuide(z and z.Position, "go_rocket", COL.cyan)
	end
	if state.phase == "Field" and state.field then
		local loc = workspace:FindFirstChild("Locations") and workspace.Locations:FindFirstChild(state.field.location)
		if loc and state.field.site == "B" and loc:FindFirstChild("SiteB") then loc = loc.SiteB end
		if not loc or not loc:FindFirstChild("Spots") then return setGuide(nil) end
		local lander = loc:FindFirstChild("Lander")
		if state.field.allDone then return setGuide(lander and lander.Position, "go_lander", COL.cyan) end
		local best, bd = nil, math.huge
		for _, s in loc.Spots:GetChildren() do
			if s:GetAttribute("Need") and not (s:GetAttribute("Hidden") and player:GetAttribute("Class") ~= "scientist") then
				local d = hrp and (s.Position - hrp.Position).Magnitude or 0
				if d < bd then best, bd = s, d end
			end
		end
		return setGuide(best and best.Position, nil, COL.cyan)
	end
	if state.phase == "Hub" or state.phase == "Briefing" then
		return setGuide(state.phase == "Hub" and Citadel.Atrium.Hologram.Projector.Position or nil, "tut_brief")
	end
	if state.phase == "Build" then
		-- after a NO-GO the arrow leads straight to the fix
		if state.fixTarget == "console" and not player:GetAttribute("Carrying") then
			return setGuide(Citadel.Hangar.LaunchConsole.Desk.Position, "fix_console", COL.red)
		end
		if state.fixCat and not player:GetAttribute("Carrying") then
			for _, bay in Citadel.Hangar.RackBays:GetChildren() do
				if bay:GetAttribute("Category") == state.fixCat then return setGuide(posOf(bay.Back), "fix_rack", COL.red) end
			end
		end
		local carrying = player:GetAttribute("Carrying")
		local frame = Citadel.Hangar:FindFirstChild("Frame")
		if carrying and frame and ModulesData.defs[carrying] then
			local cat = ModulesData.defs[carrying].category
			local fdef = Launch.frames[state.frame]
			for _, s in fdef.slots do
				if s.accepts[cat] and not state.installed[s.id] then
					local post = frame.Pads:FindFirstChild("Post_" .. s.id)
					if post then return setGuide(post.Position, "tut_place") end
				end
			end
		end
		for _, tk in state.tasks do
			if not tk.done and tk.cat then
				for _, bay in Citadel.Hangar.RackBays:GetChildren() do
					if bay:GetAttribute("Category") == tk.cat then return setGuide(posOf(bay.Back), "tut_take") end
				end
			end
		end
		return setGuide(Citadel.Hangar.LaunchConsole.Desk.Position, "tut_launch")
	end
	if state.phase == "Ops" and state.waiting then
		local c = Citadel.Control.Consoles:FindFirstChild(state.waiting.lit or state.waiting.consoles[1])
		return setGuide(c and posOf(c.Desk), "tut_control", COL.cyan)
	end
	if state.phase == "Launch" or state.phase == "Ops" then
		return setGuide(Citadel.Control.BigScreen.Position - Vector3.new(14, 6, 0), "tut_control", COL.cyan)
	end
	setGuide(nil)
end

------------------------------------------------------------------ urgent HUD (top-centre, under the assembly bar)
local urgentBar, urgentText, urgentTime, urgentIc, urgentSt
local function buildUrgent()
	urgentBar = UI.panel({ Name = "Urgent", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(464, 48), Visible = false, Parent = ctx.gui })
	ctx.onLayout(function(l) urgentBar.Position = UDim2.new(0.5, 0, 0, l.below + 48) end)
	urgentBar.BackgroundColor3 = COL.bg
	urgentBar.BackgroundTransparency = 0.08
	urgentSt = urgentBar:FindFirstChildOfClass("UIStroke")
	urgentSt.Color, urgentSt.Transparency = COL.red, 0.1
	UI.new("Frame", { BackgroundColor3 = COL.red, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = urgentBar }, { UI.corner(2) })
	urgentIc = UI.icon("warning", 20, COL.red, { Position = UDim2.fromOffset(20, 14), Parent = urgentBar })
	urgentText = UI.text({ FontFace = F.bodyBold, TextSize = 15, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -132, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = urgentBar })
	urgentTime = UI.text({ FontFace = F.mono, TextSize = 24, TextColor3 = COL.red, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(64, 48), Parent = urgentBar })
end

------------------------------------------------------------------ field HUD (right, same place as the task list)
local fieldP
local function updateField()
	if not fieldP then
		fieldP = UI.panel({ Name = "Field", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(296, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = ctx.hudLayer or ctx.gui })
		ctx.onLayout(function(l) fieldP.Position = UDim2.new(1, -l.right, 0, l.below) end)
		UI.pad(12, 16, 12, 16).Parent = fieldP
		UI.list(Enum.FillDirection.Vertical, 8).Parent = fieldP
	end
	local f = state and state.field
	fieldP.Visible = f ~= nil and (state.phase == "Field" or state.phase == "Prep") and not ctx.locked()
	if not fieldP.Visible then return end
	for _, c in fieldP:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	UI.label({ Text = ctx.t(f.nameKey), TextSize = 11, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = -2, Parent = fieldP })
	UI.rule({ LayoutOrder = -1, Parent = fieldP })
	for i, o in f.objectives do
		local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, Parent = fieldP })
		local box = UI.new("Frame", { BackgroundColor3 = COL.text, BackgroundTransparency = o.done and 0 or 1, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 5), Parent = r }, { UI.corner(2) })
		if o.done then UI.icon("check", 10, COL.dark, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = box }) else UI.stroke(COL.line, 1, 0.5).Parent = box end
		UI.icon(o.icon, 14, o.done and COL.mute or COL.text, { Position = UDim2.fromOffset(22, 5), Parent = r })
		UI.text({ Text = ctx.t(o.key), FontFace = o.done and F.body or F.bodyBold, TextSize = 14,
			TextColor3 = o.done and COL.dim or COL.text, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, (o.total > 1 and not o.done) and -92 or -44, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
		if o.total > 1 and not o.done then
			UI.text({ Text = string.format("%d/%d", o.progress, o.total), FontFace = F.mono, TextSize = 12, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 24), Parent = r })
		end
	end
	if f.allDone then
		UI.text({ Text = ctx.t("go_lander"), FontFace = F.bodyBold, TextSize = 14, TextColor3 = COL.green, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 99, Parent = fieldP })
	end
end

------------------------------------------------------------------ boards: NASA DONKI + NeoWs
local function boards()
	local bd = Citadel:WaitForChild("Boards")
	local ws = bd:WaitForChild("WeatherScreen")
	local sg = UI.new("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, Adornee = ws, Parent = ctx.gui })
	local bg = UI.new("Frame", { BackgroundColor3 = COL.bg, Size = UDim2.fromScale(1, 1), Parent = sg }, { UI.pad(20) })
	local h = UI.text({ FontFace = F.display, TextSize = 20, TextColor3 = COL.amber, Size = UDim2.new(1, 0, 0, 26), Parent = bg })
	local big = UI.text({ FontFace = F.mono, TextSize = 96, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 110), Parent = bg })
	local sub = UI.text({ FontFace = F.title, TextSize = 30, Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 36), Parent = bg })
	local src = UI.text({ FontFace = F.body, TextSize = 18, TextColor3 = COL.dim, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 24), Parent = bg })
	local ts = bd:WaitForChild("ThreatScreen")
	local sg2 = UI.new("SurfaceGui", { Face = Enum.NormalId.Right, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, Adornee = ts, Parent = ctx.gui })
	local bg2 = UI.new("Frame", { BackgroundColor3 = COL.bg, Size = UDim2.fromScale(1, 1), Parent = sg2 }, { UI.pad(24) })
	local h2 = UI.text({ FontFace = F.display, TextSize = 22, TextColor3 = COL.red, Size = UDim2.new(1, 0, 0, 30), Parent = bg2 })
	local list2 = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -80), Parent = bg2 }, { UI.list(Enum.FillDirection.Vertical, 12) })
	local src2 = UI.text({ FontFace = F.body, TextSize = 18, TextColor3 = COL.dim, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 24), Parent = bg2 })
	local function refresh()
		h.Text = string.upper(ctx.t("weather"))
		local w = workspace:GetAttribute("SpaceWeather") or "—"
		local lvl = workspace:GetAttribute("StormLevel") or 0
		big.Text = w
		big.TextColor3 = lvl >= 3 and COL.red or (lvl >= 2 and COL.yellow or COL.green)
		sub.Text = ctx.t(lvl >= 2 and "weather_storm" or "weather_calm") .. " · " .. tostring(workspace:GetAttribute("FlareCount") or 0) .. " ×"
		src.Text = ctx.t("weather_src") .. ((workspace:GetAttribute("WeatherLive") == false) and " (offline)" or "")
		h2.Text = string.upper(ctx.t("threats"))
		for _, c in list2:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
		local ok, threats = pcall(function() return HttpService:JSONDecode(workspace:GetAttribute("Threats") or "[]") end)
		if ok then
			for i, th in threats do
				local f = UI.new("Frame", { BackgroundColor3 = COL.panel2, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = i, Parent = list2 }, { UI.corner(12) })
				UI.icon(th.hazard and "warning" or "orbit", 40, th.hazard and COL.red or COL.cyan, { Position = UDim2.fromOffset(16, 26), Parent = f })
				UI.text({ Text = th.name, FontFace = F.title, TextSize = 30, Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -84, 0, 36), Parent = f })
				UI.text({ Text = string.format("%s km  ·  ~%d m", tostring(math.floor((th.km or 0) / 1000) * 1000):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""), th.d or 0), FontFace = F.mono, TextSize = 24, TextColor3 = COL.dim, Position = UDim2.fromOffset(72, 48), Size = UDim2.new(1, -84, 0, 30), Parent = f })
			end
		end
		src2.Text = ctx.t("threats_src")
	end
	refresh()
	workspace:GetAttributeChangedSignal("Threats"):Connect(refresh)
	workspace:GetAttributeChangedSignal("SpaceWeather"):Connect(refresh)
	table.insert(ctx.refreshers, refresh)
end

------------------------------------------------------------------ Zero-G trainer (client time trial)
local function trainer()
	local T = Citadel:WaitForChild("Trainer")
	local start = T:WaitForChild("StartPad")
	local rings = T:WaitForChild("Rings")
	local hud = UI.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(260, 54), Visible = false, Parent = ctx.gui }, 14)
	local lbl = UI.text({ FontFace = F.mono, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = hud })
	local running, t0, nextRing = false, 0, 1
	RunService.Heartbeat:Connect(function()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		if not running and (hrp.Position - start.Position).Magnitude < 4 and (not state or state.phase == "Hub" or state.phase == "Debrief") then
			running, t0, nextRing = true, os.clock(), 1
			ctx.toast("rocket", ctx.t("trainer_start"), "cyan")
		end
		if running then
			local r = rings:FindFirstChild("Ring" .. nextRing)
			local core = r and r:FindFirstChild("Core")
			if core and (hrp.Position - core.Position).Magnitude < 4.5 then
				ctx.audio.sfx("click", core.Position, 0.5)
				nextRing += 1
				if nextRing > #rings:GetChildren() then
					running = false
					local tt = os.clock() - t0
					Remotes.Trainer:FireServer(tt)
					ctx.toast("star", string.format("%s %.2f", ctx.t("trainer_time"), tt), "green")
				end
			end
			if os.clock() - t0 > 120 or (hrp.Position - T.Zone.Position).Magnitude > 60 then running = false end
			hud.Visible = running
			lbl.Text = string.format("%s  %.1f  ·  %d/%d", ctx.t("trainer_time"), os.clock() - t0, nextRing - 1, #rings:GetChildren())
		else
			hud.Visible = false
		end
	end)
end

------------------------------------------------------------------ Grok's shop (+ the spacesuit workshop entry)
local shopP
local profile
local function showShop()
	if not shopP then
		shopP = UI.panel({ Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(776, 584), Visible = false, ZIndex = 21, Parent = ctx.gui })
		shopP.BackgroundColor3 = COL.bg
		shopP.BackgroundTransparency = 0.04
	end
	for _, c in shopP:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	UI.label({ Text = ctx.t("p_trade"), TextColor3 = COL.accent, TextSize = 11, Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(420, 16), ZIndex = 22, Parent = shopP })
	UI.text({ Text = UI.caps(ctx.t("shop")), FontFace = F.head, TextSize = 24, Position = UDim2.fromOffset(24, 40), Size = UDim2.fromOffset(440, 30), ZIndex = 22, Parent = shopP })
	UI.text({ Text = ctx.t("grok_hi"), FontFace = F.body, TextSize = 14, TextColor3 = COL.dim, Position = UDim2.fromOffset(24, 70), Size = UDim2.fromOffset(480, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = shopP })
	UI.text({ Text = string.format("%d ₵", profile and profile.credits or 0), FontFace = F.mono, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -80, 0, 30), Size = UDim2.fromOffset(160, 28), ZIndex = 22, Parent = shopP })
	local close = UI.button({ name = "Close", style = "secondary", icon = "cross", text = "", size = UDim2.fromOffset(40, 40), anchor = Vector2.new(1, 0), position = UDim2.new(1, -24, 0, 24), z = 22, parent = shopP })
	close.MouseButton1Click:Connect(function() shopP.Visible = false end)
	UI.rule({ Position = UDim2.fromOffset(24, 100), Size = UDim2.new(1, -48, 0, 1), ZIndex = 22, Parent = shopP })
	-- spacesuit workshop (NovaClient.Outfitter sets ctx.openOutfitter)
	local suit = UI.new("Frame", { Name = "Spacesuit", BackgroundColor3 = COL.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 116), Size = UDim2.new(1, -48, 0, 64), ZIndex = 22, Parent = shopP }, { UI.corner(3) })
	UI.stroke(COL.line, 1, 0.6).Parent = suit
	UI.new("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(2, 32), ZIndex = 23, Parent = suit })
	UI.icon("commander", 24, COL.text, { Position = UDim2.fromOffset(20, 20), ZIndex = 23, Parent = suit })
	local function tk(a, b) local v = ctx.t(a) if v == a then v = ctx.t(b) end return v end
	UI.label({ Text = tk("of_menu", "ui_suit"), TextColor3 = COL.text, TextSize = 15, Position = UDim2.fromOffset(60, 12), Size = UDim2.new(1, -224, 0, 20), ZIndex = 23, Parent = suit })
	UI.text({ Text = tk("of_menu_d", "ui_suit_sub"), FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, Position = UDim2.fromOffset(60, 34), Size = UDim2.new(1, -224, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23, Parent = suit })
	local open = UI.button({ name = "OpenSuit", style = "primary", icon = "arrow", text = ctx.t("ui_open"), size = UDim2.fromOffset(144, 40), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -12, 0.5, 0), z = 23, parent = suit })
	open.MouseButton1Click:Connect(function()
		if ctx.openOutfitter then
			shopP.Visible = false
			ctx.openOutfitter()
		else
			ctx.toast("info", ctx.t("ui_suit_soon"), "cyan")
		end
	end)
	-- items: 4 columns x 176 px + 3 gaps x 8 px = 728 px = panel 776 - 2 x 24
	local grid = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 196), Size = UDim2.new(1, -40, 1, -220), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = COL.dim, ZIndex = 22, Parent = shopP }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(176, 176), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, it in ProgressData.shop do
		local useful = it.slot == "consumable" or it.slot == "upgrade"
		local count = profile and profile.items and profile.items[it.id] or 0
		local owned = profile and profile.owned and profile.owned[it.id] and it.slot ~= "consumable"
		local equipped = profile and profile.equip and profile.equip[it.slot] == it.id
		local card = UI.new("Frame", { BackgroundColor3 = COL.panel, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22, Parent = grid }, { UI.corner(3) })
		UI.stroke(COL.line, 1, equipped and 0 or 0.75).Parent = card
		if it.icon then
			UI.icon(it.icon, 32, COL.text, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), ZIndex = 23, Parent = card })
		else
			UI.new("Frame", { BackgroundColor3 = it.color or COL.text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(32, 32), ZIndex = 23, Parent = card }, { UI.corner(16), UI.stroke(COL.line, 1, 0.6) })
		end
		UI.text({ Text = ctx.t(it.key), FontFace = F.bodyBold, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 20), ZIndex = 23, Parent = card })
		if useful then
			UI.text({ Text = ctx.t(it.desc) .. (it.slot == "consumable" and ("\n" .. ctx.t("have") .. ": " .. count) or ""), FontFace = F.body, TextSize = 12, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(10, 78), Size = UDim2.new(1, -20, 0, 40), ZIndex = 23, Parent = card })
		end
		local b = UI.button({ name = "Buy", style = owned and "secondary" or "primary", text = owned and ctx.t((it.slot == "upgrade" or equipped) and "owned" or "equip") or (it.price .. " ₵"), textSize = 14,
			size = UDim2.new(1, -20, 0, 36), position = UDim2.new(0, 10, 1, -46), z = 23, parent = card })
		b.MouseButton1Click:Connect(function()
			if owned and it.slot == "upgrade" then return end
			local res = Remotes.Shop:InvokeServer(owned and "equip" or "buy", it.id)
			if not res or res.status ~= "ok" then ctx.toast("budget", ctx.t("credits_c"), "red") else ctx.audio.sfx("install") task.delay(0.3, function() if shopP.Visible then showShop() end end) end
		end)
	end
	shopP.Visible = true
	UI.pop(shopP, 0.98)
end

------------------------------------------------------------------ profile chip + toasts for rank & achievements
local profChip, profRank, profXp, profCred
local function buildProfile()
	profChip = UI.panel({ Name = "Profile", Size = UDim2.fromOffset(240, 48), Parent = ctx.hudLayer or ctx.gui })
	ctx.onLayout(function(l)
		if l.touch then
			profChip.AnchorPoint = Vector2.zero
			profChip.Position = UDim2.fromOffset(l.left, l.safeTop + 132)
		else
			profChip.AnchorPoint = Vector2.new(0, 1)
			profChip.Position = UDim2.new(0, l.left, 1, -16)
		end
	end)
	profRank = UI.text({ FontFace = F.bodyBold, TextSize = 14, Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -112, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, Parent = profChip })
	profCred = UI.text({ FontFace = F.mono, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 6), Size = UDim2.fromOffset(92, 22), Parent = profChip })
	local track = UI.new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 2), Parent = profChip })
	profXp = UI.new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track })
end
local currentRank = 1
local function updateProfile()
	if not profile or not profChip then return end
	local ranks = ProgressData.ranks
	local r = math.clamp(currentRank, 1, #ranks)
	local cur, nxt = ranks[r].xp, ranks[r + 1] and ranks[r + 1].xp or ranks[r].xp + 1
	profRank.Text = ctx.t(ranks[r].key)
	profCred.Text = (profile.credits or 0) .. " ₵"
	profXp.Size = UDim2.fromScale(math.clamp(((profile.xp or 0) - cur) / math.max(1, nxt - cur), 0, 1), 1)
end

local FADE = TweenInfo.new(0.4)
local function bigToast(iconName, kicker, title, col)
	local f = UI.panel({ Name = "BigToast", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(424, 72), ZIndex = 15, Parent = ctx.gui })
	local lay = ctx.layout or { below = 68 }
	f.Position = UDim2.new(0.5, 0, 0, lay.below + 104)
	f.BackgroundColor3 = COL.bg
	f.BackgroundTransparency = 0.08
	local c = (col == COL.green or col == COL.red or col == COL.yellow) and col or COL.accent
	UI.new("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(2, 40), ZIndex = 16, Parent = f })
	UI.icon(iconName, 28, COL.text, { Position = UDim2.fromOffset(22, 22), ZIndex = 17, Parent = f })
	UI.label({ Text = kicker, TextColor3 = c, TextSize = 11, Position = UDim2.fromOffset(68, 14), Size = UDim2.new(1, -84, 0, 16), ZIndex = 16, Parent = f })
	UI.text({ Text = UI.upper(title), FontFace = F.head, TextSize = 20, Position = UDim2.fromOffset(68, 32), Size = UDim2.new(1, -84, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 16, Parent = f })
	UI.pop(f, 0.97)
	ctx.audio.sfx("achievement", nil, 0.6)
	task.delay(3.6, function()
		if not f.Parent then return end
		TweenService:Create(f, FADE, { BackgroundTransparency = 1 }):Play()
		for _, d in f:GetDescendants() do
			if d:IsA("TextLabel") then TweenService:Create(d, FADE, { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then TweenService:Create(d, FADE, { ImageTransparency = 1 }):Play()
			elseif d:IsA("Frame") then TweenService:Create(d, FADE, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then TweenService:Create(d, FADE, { Transparency = 1 }):Play() end
		end
		task.wait(0.45)
		f:Destroy()
	end)
end

------------------------------------------------------------------ daily quests panel, pings, repair kit
local questBtn, questP
local function showQuests()
	if not questP then return end
	for _, c in questP:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	UI.label({ Text = ctx.t("quests"), TextSize = 11, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = -2, ZIndex = 16, Parent = questP })
	UI.rule({ LayoutOrder = -1, ZIndex = 16, Parent = questP })
	local list = profile and profile.quests and profile.quests.list or {}
	for i, q in list do
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = i, ZIndex = 16, Parent = questP })
		UI.icon(q.done and "check" or q.icon, 16, q.done and COL.green or COL.text, { Position = UDim2.fromOffset(0, 4), ZIndex = 17, Parent = row })
		UI.text({ Text = ctx.t(q.key), FontFace = F.bodyBold, TextSize = 14, TextColor3 = q.done and COL.dim or COL.text, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -100, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 17, Parent = row })
		UI.text({ Text = "+" .. q.reward .. " ₵", FontFace = F.mono, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(68, 24), ZIndex = 17, Parent = row })
		local tr = UI.new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromOffset(28, 32), Size = UDim2.new(1, -100, 0, 2), ZIndex = 17, Parent = row })
		UI.new("Frame", { BackgroundColor3 = q.done and COL.green or COL.text, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(q.have / math.max(1, q.need), 0, 1), 1), ZIndex = 18, Parent = tr })
		UI.text({ Text = q.have .. "/" .. q.need, FontFace = F.mono, TextSize = 11, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 24), Size = UDim2.fromOffset(68, 18), ZIndex = 17, Parent = row })
	end
end
local function buildQuests()
	questBtn = UI.iconButton({ name = "QuestButton", icon = "task", order = 2, parent = ctx.iconBar or ctx.hudLayer or ctx.gui })
	local badge = UI.new("Frame", { Name = "Count", BackgroundColor3 = COL.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(28, 12), ZIndex = 3, Visible = false, Parent = questBtn }, { UI.corner(2), UI.stroke(COL.line, 1, 0.6) })
	local qlbl = UI.text({ Text = "", FontFace = F.mono, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = badge })
	questP = UI.panel({ Name = "Quests", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(328, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 15, Parent = ctx.gui })
	questP.BackgroundColor3 = COL.bg
	questP.BackgroundTransparency = 0.04
	ctx.onLayout(function(l) questP.Position = UDim2.new(1, -l.right, 0, l.below) end)
	UI.pad(12, 16, 12, 16).Parent = questP
	UI.list(Enum.FillDirection.Vertical, 8).Parent = questP
	questBtn.MouseButton1Click:Connect(function() questP.Visible = not questP.Visible if questP.Visible then showQuests() end end)
	task.spawn(function()
		while questBtn.Parent do
			local list = profile and profile.quests and profile.quests.list or {}
			local d = 0
			for _, q in list do if q.done then d += 1 end end
			qlbl.Text = d .. "/" .. #list
			badge.Visible = #list > 0
			task.wait(1)
		end
	end)
end
local function pingAt(pos, name, kind)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.Transparency, a.Size = true, false, false, 1, Vector3.new(1, 1, 1)
	a.CFrame = CFrame.new(pos)
	a.Parent = workspace:FindFirstChild("ClientFX") or workspace
	local bb = UI.new("BillboardGui", { Size = UDim2.fromOffset(160, 56), StudsOffsetWorldSpace = Vector3.new(0, 3, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = a, Parent = ctx.gui })
	UI.new("Frame", { BackgroundColor3 = COL.accent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(12, 12), Parent = bb }, { UI.corner(6) })
	UI.text({ Text = (name or "") .. ": " .. ctx.t("ping_help"), FontFace = F.bodyBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Size = UDim2.new(1, 0, 0, 22), Parent = bb })
	ctx.audio.sfx("poll", pos, 0.6)
	task.delay(6, function() bb:Destroy() a:Destroy() end)
end

------------------------------------------------------------------ public
function W.onState(s)
	local prev = state
	state = s
	updateMonitor()
	updateField()
	if prev and prev.phase ~= s.phase then urgentNow = {} end
end

------------------------------------------------------------------ fault sounds: each emergency sounds different, comes from its spot
-- (louder as you get closer), with a short sting at the start and a tick in the last 10 seconds. No endless alarm music.
local FAULT_SOUND = {
	coolant = { loop = "rbxassetid://9125742262", speed = 2.3, vol = 0.55, sting = 1.25 },  -- hissing leak
	sparks = { loop = "rbxassetid://91611143129889", speed = 1, vol = 0.5, sting = 0.85 },  -- crackling short circuit
	noise = { loop = "rbxassetid://74991546350354", speed = 1, vol = 0.45, sting = 1.5 },   -- radio static
	calib = { beep = "rbxassetid://72469458991898", every = 1.1, vol = 0.45, sting = 1.1 }, -- calibration error beeps
	audit = { beep = "rbxassetid://9075074819", every = 2.2, speed = 1.35, vol = 0.3, sting = 0.7 }, -- office klaxon
}
local faultSounds = {}
local function stopFaultSound(spot)
	local f = faultSounds[spot]
	if not f then return end
	faultSounds[spot] = nil
	f.alive = false
	if f.att then f.att:Destroy() end
	if not next(faultSounds) then
		local g = game:GetService("SoundService"):FindFirstChild("NovaMusic")
		if g then TweenService:Create(g, TweenInfo.new(1), { Volume = ctx.audio.settings.music }):Play() end
	end
end
local function startFaultSound(c)
	stopFaultSound(c.spot)
	local id = c.field and "field" or nil
	for _, d in require(RS.Nova.Data.Urgent) do if d.spot == c.spot then id = d.id end end
	local def = FAULT_SOUND[id] or FAULT_SOUND.calib
	local pos = c.pos
	if not pos then
		local s = Citadel:FindFirstChild("UrgentSpots") and Citadel.UrgentSpots:FindFirstChild(c.spot)
		pos = s and s.Position
	end
	-- short sting, pitched per fault so every emergency is recognisable by ear
	local sting = ctx.audio.sfx("alarm", nil, 0.35)
	if sting then sting.PlaybackSpeed = def.sting end
	-- duck the music instead of switching to an endless alarm track
	local g = game:GetService("SoundService"):FindFirstChild("NovaMusic")
	if g then TweenService:Create(g, TweenInfo.new(0.6), { Volume = ctx.audio.settings.music * 0.45 }):Play() end
	local f = { alive = true }
	faultSounds[c.spot] = f
	if pos then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = workspace.Terrain
		f.att = att
		if def.loop then
			local s = Instance.new("Sound")
			s.SoundId = def.loop
			s.Looped = true
			s.Volume = def.vol
			s.PlaybackSpeed = def.speed or 1
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 8
			s.RollOffMaxDistance = 90
			s.SoundGroup = game:GetService("SoundService"):FindFirstChild("NovaSFX")
			s.Parent = att
			s:Play()
		end
	end
	task.spawn(function()
		local lastTick = -1
		while f.alive do
			if def.beep and f.att then
				local s = Instance.new("Sound")
				s.SoundId = def.beep
				s.Volume = def.vol
				s.PlaybackSpeed = def.speed or 1
				s.RollOffMaxDistance = 90
				s.SoundGroup = game:GetService("SoundService"):FindFirstChild("NovaSFX")
				s.Parent = f.att
				s:Play()
				s.Ended:Connect(function() s:Destroy() end)
			end
			local u = urgentNow[c.spot]
			if u and u.deadline then
				local rem = math.ceil(u.deadline - workspace:GetServerTimeNow())
				if rem <= 10 and rem > 0 and rem ~= lastTick then lastTick = rem ctx.audio.sfx("click", nil, 0.3) end
			end
			task.wait(def.every or 0.5)
		end
	end)
end

function W.onCue(c)
	if c.type == "urgent" then
		urgentNow[c.spot] = { deadline = c.deadline, key = c.key, icon = c.icon, field = c.field, pos = c.pos }
		startFaultSound(c)
	elseif c.type == "urgentEnd" then
		urgentNow[c.spot] = nil
		stopFaultSound(c.spot)
		if not c.silent then
			ctx.toast(c.ok and "check" or "warning", ctx.t(c.ok and "u_fixed" or "u_failed"), c.ok and "green" or "red")
			ctx.audio.sfx(c.ok and "go" or "hold", nil, 0.4)
		end
	elseif c.type == "profile" then
		profile = c.profile
		currentRank = c.rank or currentRank
		updateProfile()
		if shopP and shopP.Visible then showShop() end
	elseif c.type == "rankUp" then
		currentRank = c.rank
		bigToast("star", ctx.t("rank_up"), ctx.t(ProgressData.ranks[c.rank].key), COL.violet)
		updateProfile()
	elseif c.type == "achievement" then
		bigToast(c.icon or "star", ctx.t("achievement"), ctx.t(c.key), COL.yellow)
	elseif c.type == "alarm" then
		-- cold open: siren + red pulse over the whole Citadel
		ctx.audio.sfx("alarm", nil, 0.6)
		ctx.audio.music("urgent")
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			local base = cc.TintColor
			task.spawn(function()
				for _ = 1, 4 do
					TweenService:Create(cc, TweenInfo.new(0.3), { TintColor = Color3.fromRGB(255, 160, 150) }):Play()
					task.wait(0.45)
					TweenService:Create(cc, TweenInfo.new(0.5), { TintColor = base }):Play()
					task.wait(0.6)
				end
			end)
		end
	elseif c.type == "daily" then
		bigToast("star", ctx.t("daily_title"), string.format(ctx.t("daily_text"), c.day or 1, c.reward or 0), COL.yellow)
		ctx.audio.sfx("go", nil, 0.5)
	elseif c.type == "questDone" then
		bigToast("task", ctx.t("quest_done"), ctx.t(c.key) .. "  +" .. (c.reward or 0) .. " ₵", COL.amber)
		if questP and questP.Visible then task.delay(0.2, showQuests) end
	elseif c.type == "ping" then
		pingAt(c.pos, c.name, c.kind)
	elseif c.type == "sfx" then
		ctx.audio.sfx(c.name, c.pos)
	end
end

function W.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	capture()
	ctx.audio.ambience("hub")
	task.spawn(buildMonitor) -- never block init on a streamed-in model
	buildArrow()
	buildUrgent()
	buildProfile()
	buildQuests()
	task.spawn(boards)
	task.spawn(trainer)
	-- Grok's shop (local prompt: opens UI only; purchases are validated by the server)
	task.spawn(function()
		local counter = Citadel:WaitForChild("Market"):WaitForChild("Stall"):WaitForChild("Counter")
		local pr = Instance.new("ProximityPrompt")
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "p_trade")
		pr.ActionText = ctx.t("shop")
		pr.Parent = counter
		pr.Triggered:Connect(showShop)
		table.insert(ctx.refreshers, function() pr.ActionText = ctx.t("shop") pr.ObjectText = "" end)
	end)
	game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
		if gp or ctx.locked() or ctx.menuOpen() then return end
		if inp.KeyCode == Enum.KeyCode.V then
			local cam = workspace.CurrentCamera
			local m = game:GetService("UserInputService"):GetMouseLocation()
			local ray = cam:ViewportPointToRay(m.X, m.Y)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { player.Character }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
			if hit then Remotes.Request:FireServer({ action = "ping", pos = hit.Position }) end
		elseif inp.KeyCode == Enum.KeyCode.R and next(urgentNow) and profile and profile.items and (profile.items.kit_repair or 0) > 0 then
			Remotes.Request:FireServer({ action = "kit" })
		end
	end)
	player:GetAttributeChangedSignal("Location"):Connect(function() applyPreset(player:GetAttribute("Location") or "hub") end)
	-- europa geysers erupt (visual) when their spot is Active
	RunService.Heartbeat:Connect(function()
		local loc = workspace:FindFirstChild("Locations")
		local eu = loc and loc:FindFirstChild("europa")
		if eu and eu:FindFirstChild("Spots") then
			for _, s in eu.Spots:GetChildren() do
				local pe = s:FindFirstChild("Plume")
				if pe then pe.Enabled = s:GetAttribute("Active") == true end
			end
		end
	end)
	local tick = 0
	RunService.RenderStepped:Connect(function(dt)
		tick += dt
		if tick > 0.25 then
			tick = 0
			computeGuide()
			if fieldP and state then
				local want = state.field ~= nil and (state.phase == "Field" or state.phase == "Prep") and not ctx.locked()
				if want ~= fieldP.Visible then updateField() end
			end
		 end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local show = guideTarget ~= nil and hrp ~= nil and not ctx.locked() and not ctx.menuOpen()
		hint.Visible = show and guideKey ~= nil and state ~= nil and (state.tutorial or next(urgentNow) ~= nil or state.fixCat ~= nil or state.fixTarget ~= nil)
		if show then
			local cam = workspace.CurrentCamera
			local flat = Vector3.new(guideTarget.X - hrp.Position.X, 0, guideTarget.Z - hrp.Position.Z)
			local dist = flat.Magnitude
			local near = dist < 7 and math.abs(guideTarget.Y - hrp.Position.Y) < 10
			guideRoot.Visible = not near
			if not near then
				local rel = cam.CFrame:VectorToObjectSpace(flat)
				local ang = math.atan2(rel.X, -rel.Z)
				local sp = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 0.6, 0))
				local vp = cam.ViewportSize
				local radius = math.clamp(vp.Y * 0.11, 64, 110)
				local x = math.clamp(sp.X + math.sin(ang) * radius, 40, vp.X - 40)
				local y = math.clamp(sp.Y - math.cos(ang) * radius, 40, vp.Y - 60)
				local cur = guideRoot.Position
				local nx = cur.X.Offset + (x - cur.X.Offset) * math.clamp(dt * 14, 0, 1)
				local ny = cur.Y.Offset + (y - cur.Y.Offset) * math.clamp(dt * 14, 0, 1)
				guideRoot.Position = UDim2.fromOffset(nx, ny)
				guideArrow.Rotation = math.deg(ang) - 90
				local pulse = 1 + math.sin(os.clock() * 5) * 0.06
				guideDisc.Size = UDim2.fromOffset(44 * pulse, 44 * pulse)
				guideArrow.ImageColor3 = guideColor
				guideStroke.Color = guideColor
				guideDist.Text = string.format("%d m", math.floor(dist * 0.28 + 0.5))
				guideDist.TextColor3 = guideColor
			end
			if guideKey then W.hintText.Text = ctx.t(guideKey) W.hintIcon.ImageColor3 = guideColor end
		else
			guideRoot.Visible = false
		end
		-- urgent countdown
		local soon, soonU = math.huge, nil
		for _, u in urgentNow do
			if u.deadline and u.deadline < soon then soon, soonU = u.deadline, u end
		end
		urgentBar.Visible = soonU ~= nil and not ctx.locked()
		if soonU then
			local rem = math.max(0, soon - workspace:GetServerTimeNow())
			local kits = profile and profile.items and profile.items.kit_repair or 0
			urgentText.Text = string.upper(ctx.t("urgent")) .. " · " .. ctx.t(soonU.key) .. (kits > 0 and ("   [" .. ctx.t("kit_hint") .. " ×" .. kits .. "]") or "")
			urgentTime.Text = string.format("%d", math.ceil(rem))
			UI.setIcon(urgentIc, soonU.icon or "warning")
			urgentBar:FindFirstChildOfClass("UIStroke").Transparency = 0.1 + (math.sin(os.clock() * 8) + 1) * 0.3
		end
	end)
end

return W
