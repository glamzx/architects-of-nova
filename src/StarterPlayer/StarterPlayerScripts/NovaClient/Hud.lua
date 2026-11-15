-- Hud: launch readiness poll (GO / NO-GO), contextual module inspect card, settings panel, NASA mission file,
-- post-mission quiz, "your job" role card. Same visual system as the rest of the HUD (NovaUI).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local ModulesData = require(RS.Nova.Data.Modules)
local PartInfo = require(RS.Nova.Data.PartInfo)
local Config = require(RS.Nova.Shared.Config)
local NasaFiles = require(RS.Nova.Data.NasaFiles)
local RoleLines = require(RS.Nova.Data.RoleLines)
local Remotes = RS.Nova.Remotes

local Hud = {}
local player = Players.LocalPlayer
local ctx, UI, COL, F
local fileP, fileBtn
local function isRu() return ctx.lang and ctx.lang() == "ru" or ctx.t("on") == "ВКЛ" end
local function li() return isRu() and 1 or 2 end

------------------------------------------------------------------ launch readiness poll (right, vertically centred)
local pollP, pollRows, pollVerdict, pollVerdictL, pollTitle, pollNote, pollToken = nil, nil, nil, nil, nil, nil, 0
local function buildPoll()
	pollP = UI.panel({ Name = "ReadinessPoll", AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(432, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 20, Parent = ctx.gui })
	ctx.onLayout(function(l) pollP.Position = UDim2.new(1, -l.right, 0.5, 0) end)
	UI.pad(16, 16, 16, 16).Parent = pollP
	UI.list(Enum.FillDirection.Vertical, 8).Parent = pollP
	pollTitle = UI.label({ Text = "", TextColor3 = COL.accent, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0, ZIndex = 21, Parent = pollP })
	UI.rule({ LayoutOrder = 1, ZIndex = 21, Parent = pollP })
	pollRows = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 21, Parent = pollP }, { UI.list(Enum.FillDirection.Vertical, 4) })
	pollVerdict = UI.new("Frame", { BackgroundColor3 = COL.green, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Visible = false, ZIndex = 21, Parent = pollP }, { UI.corner(3) })
	pollVerdictL = UI.text({ Name = "T", FontFace = F.head, TextSize = 18, TextColor3 = COL.dark, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = pollVerdict })
	pollNote = UI.text({ FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4, ZIndex = 21, Parent = pollP })
end

local function pollRow(item, order)
	local col = item.go and COL.green or (item.optional and COL.yellow or COL.red)
	local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 21, Parent = pollRows })
	UI.pad(4, 0, 4, 0).Parent = r
	UI.list(Enum.FillDirection.Vertical, 2).Parent = r
	local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, ZIndex = 21, Parent = r })
	UI.icon(item.icon or "info", 16, col, { Position = UDim2.fromOffset(0, 4), ZIndex = 22, Parent = top })
	UI.label({ Text = ctx.t(item.st), TextColor3 = COL.text, TextSize = 12, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -120, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22, Parent = top })
	local pill = UI.new("Frame", { BackgroundColor3 = col, BackgroundTransparency = item.go and 1 or 0, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(84, 20), ZIndex = 22, Parent = top }, { UI.corner(2) })
	UI.stroke(col, 1, 0).Parent = pill
	UI.label({ Text = item.go and ctx.t("ui_go") or (item.optional and ctx.t("poll_optional") or ctx.t("ui_nogo")), TextSize = 10, TextColor3 = item.go and col or COL.dark,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = pill })
	if not item.go then
		-- explanation column, indented to the label (28 px)
		local sub = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 21, Parent = r }, {
			UI.pad(0, 0, 0, 28), UI.list(Enum.FillDirection.Vertical, 2) })
		if item.why then
			local txt = ctx.t(item.why)
			if item.args then local ok, f = pcall(string.format, txt, table.unpack(item.args)) if ok then txt = f end end
			if item.whyList then
				local names = {}
				for _, k in item.whyList do table.insert(names, ctx.t("g_" .. k)) end
				txt = txt .. " " .. table.concat(names, ", ")
			end
			if item.hint then txt = txt .. "  ·  " .. ctx.t(item.hint) end
			UI.text({ Text = txt, FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, ZIndex = 22, Parent = sub })
		end
		if item.fix then
			UI.text({ Text = ctx.t("poll_fix") .. " " .. ctx.t(item.fix), FontFace = F.bodyBold, TextSize = 13, TextColor3 = COL.text, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, ZIndex = 22, Parent = sub })
		end
	end
	UI.rule({ LayoutOrder = 9, ZIndex = 21, BackgroundTransparency = 0.92, Parent = r })
	UI.pop(r, 0.98)
end

function Hud.poll(c)
	if not pollP then return end
	pollToken += 1
	local token = pollToken
	for _, ch in pollRows:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
	pollTitle.Text = UI.caps(ctx.t("poll_title"))
	pollNote.Text = ctx.t("nasa_poll")
	pollVerdict.Visible = false
	pollP.Visible = true
	UI.pop(pollP, 0.98)
	ctx.audio.sfx("ui", nil, 0.4)
	task.spawn(function()
		for i, item in c.items or {} do
			task.wait(0.45)
			if token ~= pollToken then return end
			pollRow(item, i)
			ctx.audio.sfx(item.go and "poll" or "hold", nil, item.go and 0.35 or 0.25)
		end
		task.wait(0.4)
		if token ~= pollToken then return end
		pollVerdict.Visible = true
		pollVerdict.BackgroundColor3 = c.go and COL.green or COL.red
		pollVerdictL.TextColor3 = c.go and COL.dark or Color3.new(1, 1, 1)
		pollVerdictL.Text = UI.caps(ctx.t(c.go and "poll_go" or "poll_hold"))
		UI.pop(pollVerdict, 0.97)
		ctx.audio.sfx(c.go and "go" or "hold", nil, 0.5)
		task.wait(c.go and 2.2 or 11)
		if token ~= pollToken then return end
		pollP.Visible = false
	end)
end
function Hud.hidePoll() pollToken += 1 if pollP then pollP.Visible = false end end

------------------------------------------------------------------ inspect card (shown while a rack "Take" prompt is shown)
local card, cardName, cardCat, cardIc, cardStats, cardEffect, cardFlags
local MG_whatL, MG_realL, MG_moreL
local function buildCard()
	card = UI.panel({ Name = "InspectCard", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(304, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = ctx.gui })
	ctx.onLayout(function(l) card.Position = UDim2.new(1, -l.right, 1, l.touch and -176 or -16) end)
	UI.pad(16, 16, 16, 16).Parent = card
	UI.list(Enum.FillDirection.Vertical, 8).Parent = card
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = card })
	cardIc = UI.icon("info", 24, COL.text, { Position = UDim2.fromOffset(0, 8), Parent = head })
	cardCat = UI.label({ Text = "", TextSize = 10, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 0, 14), Parent = head })
	cardName = UI.text({ FontFace = F.head, TextSize = 18, Position = UDim2.fromOffset(36, 14), Size = UDim2.new(1, -36, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = head })
	UI.rule({ LayoutOrder = 2, Parent = card })
	cardStats = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = card }, {
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 24), CellPadding = UDim2.fromOffset(8, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	cardFlags = UI.text({ FontFace = F.bodyBold, TextSize = 13, TextColor3 = COL.yellow, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 4, Parent = card })
	cardEffect = UI.text({ FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 5, Parent = card })
	MG_whatL = UI.text({ FontFace = F.body, TextSize = 14, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 6, Parent = card })
	MG_realL = UI.text({ FontFace = F.body, TextSize = 13, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 7, Parent = card })
	MG_moreL = UI.label({ Text = "", TextSize = 10, TextColor3 = COL.mute, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 8, Parent = card })
end
local function stat(iconName, label, value, col, order)
	local f = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Parent = cardStats })
	UI.rule({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundTransparency = 0.9, Parent = f })
	UI.icon(iconName, 12, col, { Position = UDim2.fromOffset(0, 6), Parent = f })
	UI.text({ Text = label, FontFace = F.body, TextSize = 12, TextColor3 = COL.dim, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.55, -18, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
	UI.text({ Text = value, FontFace = F.mono, TextSize = 12, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.55, 0), Size = UDim2.new(0.45, 0, 1, 0), Parent = f })
end
local cardPrompt
local function showCard(id, prompt)
	local d = ModulesData.defs[id]
	if not d or not card then return end
	cardPrompt = prompt
	for _, c in cardStats:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	cardName.Text = UI.upper(ctx.t(d.nameKey))
	cardCat.Text = UI.caps(ctx.t("cat_" .. d.category))
	UI.setIcon(cardIc, Config.CategoryIcon[d.category] or "info")
	local u = function(k) return ctx.t(k) end
	local o = 0
	local function add(i, l, v, c) o += 1 stat(i, l, v, c, o) end
	add("mass", ctx.t("g_mass"), string.format("%.1f %s", d.massKg, u("u_kg")), COL.text)
	add("budget", ctx.t("g_budget"), tostring(d.cost) .. " ₵", COL.text)
	if d.powerGenW then add("power", ctx.t("i_gen"), string.format("+%g %s", d.powerGenW, u("u_w")), COL.green) end
	if d.rtgW then add("power", ctx.t("i_rtg"), string.format("+%g %s", d.rtgW, u("u_w")), COL.green) end
	if d.powerUseW then add("power", ctx.t("i_use"), string.format("-%g %s", d.powerUseW, u("u_w")), COL.yellow) end
	if d.batteryWh then add("battery", ctx.t("i_store"), string.format("%g %s", d.batteryWh, u("u_wh")), COL.text) end
	if d.link then add("comms", ctx.t("g_comms"), string.format("%g", d.link), COL.text) end
	if d.dataMB then add("data", ctx.t("g_data"), string.format("%g %s", d.dataMB, u("u_mb")), COL.text) end
	local flags = {}
	if d.radHard or d.shields then table.insert(flags, ctx.t("i_radhard")) end
	if d.darkOK then table.insert(flags, ctx.t("i_dark")) end
	if d.heavy then table.insert(flags, ctx.t("i_heavy")) end
	if d.vex then table.insert(flags, ctx.t("i_vex")) end
	cardFlags.Text = table.concat(flags, "  ·  ")
	cardFlags.Visible = #flags > 0
	cardFlags.TextColor3 = d.vex and COL.red or COL.yellow
	local st = ctx.state()
	if st and st.rocketCapacity then
		local after = (st.massKg or 0) + d.massKg
		cardEffect.Text = string.format(ctx.t("i_effect"), st.massKg or 0, after, st.rocketCapacity)
		cardEffect.TextColor3 = after > st.rocketCapacity and COL.red or COL.dim
		cardEffect.Visible = true
	else
		cardEffect.Text = ""
		cardEffect.Visible = false
	end
	local info = PartInfo[id]
	MG_whatL.Text = info and info.what[li()] or ""
	MG_whatL.Visible = info ~= nil
	MG_realL.Text = info and ("NASA: " .. info.real[li()]) or ""
	MG_realL.Visible = info ~= nil
	MG_moreL.Text = UI.caps(ctx.t("book_more"))
	card.Visible = not ctx.locked()
	UI.pop(card, 0.98)
end

------------------------------------------------------------------ settings
local setP, gear
local function slider(parent, key, labelKey, order)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = parent })
	local lbl = UI.text({ FontFace = F.bodyBold, TextSize = 15, Size = UDim2.new(1, -64, 0, 20), Parent = row })
	local val = UI.text({ FontFace = F.mono, TextSize = 13, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(64, 20), Parent = row })
	-- 24 px tall hit area, 2 px visible track
	local track = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 20), Parent = row })
	local line = UI.new("Frame", { BackgroundColor3 = COL.line, BackgroundTransparency = 0.8, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), Parent = track })
	local fill = UI.new("Frame", { BackgroundColor3 = COL.text, BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 1), Parent = line })
	local knob = UI.new("Frame", { BackgroundColor3 = COL.text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = track }, { UI.corner(6) })
	local function refresh()
		local v = ctx.audio.settings[key] or 0
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		val.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
		lbl.Text = ctx.t(labelKey)
	end
	local dragging = false
	local function setFrom(x)
		local v = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		ctx.audio.settings[key] = math.floor(v * 20 + 0.5) / 20
		ctx.audio.apply()
		refresh()
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true setFrom(i.Position.X) end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setFrom(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Hud.save()
		end
	end)
	table.insert(ctx.refreshers, refresh)
	refresh()
end
local function toggle(parent, labelKey, get, set, order)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order, Parent = parent })
	local lbl = UI.text({ FontFace = F.bodyBold, TextSize = 15, Size = UDim2.new(1, -88, 1, 0), Parent = row })
	local b, t = UI.chipButton({ text = "", size = UDim2.fromOffset(80, 32), anchor = Vector2.new(1, 0.5), position = UDim2.new(1, 0, 0.5, 0), parent = row })
	local function refresh()
		lbl.Text = ctx.t(labelKey)
		local v = get()
		t.Text = UI.caps(typeof(v) == "string" and v or (v and ctx.t("on") or ctx.t("off")))
		UI.setOn(b, t, v == true or typeof(v) == "string")
	end
	b.MouseButton1Click:Connect(function() set() refresh() ctx.audio.sfx("ui", nil, 0.4) Hud.save() end)
	table.insert(ctx.refreshers, refresh)
	refresh()
end
local function buildSettings()
	gear = UI.iconButton({ name = "SettingsButton", glyph = "⚙", glyphSize = 20, order = 4, parent = ctx.iconBar or ctx.gui })
	setP = UI.panel({ Name = "Settings", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(424, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 30, Parent = ctx.gui })
	setP.BackgroundColor3 = COL.bg
	setP.BackgroundTransparency = 0.04
	UI.pad(24, 24, 24, 24).Parent = setP
	UI.list(Enum.FillDirection.Vertical, 16).Parent = setP
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = -1, Parent = setP })
	local title = UI.text({ FontFace = F.head, TextSize = 20, Size = UDim2.new(1, -48, 1, 0), Parent = head })
	local close = UI.button({ name = "Close", style = "secondary", icon = "cross", text = "", size = UDim2.fromOffset(32, 32), anchor = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0), parent = head })
	UI.rule({ LayoutOrder = 0, Parent = setP }).LayoutOrder = 0
	table.insert(ctx.refreshers, function() title.Text = UI.caps(ctx.t("settings")) end)
	slider(setP, "music", "set_music", 1)
	slider(setP, "sfx", "set_sfx", 2)
	slider(setP, "ambience", "set_ambience", 3)
	toggle(setP, "set_shake", function() return ctx.audio.settings.shake ~= false end, function() ctx.audio.settings.shake = not (ctx.audio.settings.shake ~= false) end, 4)
	toggle(setP, "set_lang", function() return ctx.t("lang") end, function() ctx.toggleLang() end, 5)
	-- promo codes (free credits/items for events like Space Apps; never sold)
	local codeRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 6, Parent = setP })
	local box = UI.new("TextBox", { Text = "", PlaceholderText = "", ClearTextOnFocus = false, FontFace = F.mono, TextSize = 15, TextColor3 = COL.text, PlaceholderColor3 = COL.mute,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = COL.panel, BorderSizePixel = 0, Size = UDim2.new(1, -96, 1, 0), Parent = codeRow }, { UI.corner(3), UI.pad(0, 12, 0, 12), UI.stroke(COL.line, 1, 0.6) })
	local ok, okL = UI.button({ name = "CodeOk", style = "primary", text = "OK", size = UDim2.fromOffset(88, 40), anchor = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0), parent = codeRow })
	table.insert(ctx.refreshers, function() box.PlaceholderText = ctx.t("code_enter") if okL then okL.Text = UI.caps(ctx.t("code")) end end)
	ok.MouseButton1Click:Connect(function()
		local res = RS.Nova.Remotes.Shop:InvokeServer("code", box.Text)
		if res and res.status == "ok" then
			ctx.toast("star", ctx.t("code_ok") .. (res.credits and ("  +" .. res.credits .. " ₵") or ""), "green")
			ctx.audio.sfx("go", nil, 0.5)
			box.Text = ""
		else
			ctx.toast("cross", ctx.t(res and res.key or "code_bad"), "red")
		end
	end)
	UI.rule({ LayoutOrder = 8, Parent = setP })
	UI.text({ Text = "", Name = "Credits", FontFace = F.body, TextSize = 12, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 9, Parent = setP })
	table.insert(ctx.refreshers, function() setP.Credits.Text = ctx.t("set_credits") end)
	for _, d in setP:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 31 end end
	local function toggleOpen() setP.Visible = not setP.Visible if setP.Visible then UI.pop(setP, 0.98) end ctx.audio.sfx("ui", nil, 0.4) end
	gear.MouseButton1Click:Connect(toggleOpen)
	close.MouseButton1Click:Connect(toggleOpen)
	UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.Escape and setP.Visible then setP.Visible = false end
	end)
end
local saveQueued = false
function Hud.save()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		if ctx.lang then ctx.audio.settings.lang = ctx.lang() end
		Remotes.Request:FireServer({ action = "settings", data = ctx.audio.settings })
	end)
end
function Hud.openSettings() if setP then setP.Visible = true UI.pop(setP, 0.98) end end
function Hud.setGearVisible(on) if gear then gear.Visible = on end if fileBtn then fileBtn.Visible = on end if not on and fileP then fileP.Visible = false end end

------------------------------------------------------------------ NASA mission file (optional learning, key N)
local function showFile()
	local st = ctx.state()
	local mid = st and st.missionId or "M0"
	local f = NasaFiles[mid]
	if not f or not fileP then return end
	for _, c in fileP:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local L = li()
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 0, Parent = fileP })
	UI.label({ Text = ctx.t("ui_nasa_file") .. "  ·  " .. mid, TextColor3 = COL.accent, TextSize = 12, Size = UDim2.new(1, -48, 0, 16), Parent = head })
	local close = UI.button({ name = "Close", style = "secondary", icon = "cross", text = "", size = UDim2.fromOffset(32, 32), anchor = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0), parent = head })
	close.MouseButton1Click:Connect(function() fileP.Visible = false end)
	UI.text({ Text = UI.upper(f.analog[L]), FontFace = F.head, TextSize = 22, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = fileP })
	UI.rule({ LayoutOrder = 2, Parent = fileP })
	for k, fact in f.facts do
		-- number box in a 40 px gutter, text column to its right
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 + k, Parent = fileP })
		local num = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 20), Parent = row }, { UI.corner(2), UI.stroke(COL.line, 1, 0.55) })
		UI.text({ Text = string.format("%02d", k), FontFace = F.mono, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = num })
		local col = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row }, { UI.list(Enum.FillDirection.Vertical, 4) })
		UI.text({ Text = fact[L], FontFace = F.bodyBold, TextSize = 15, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = col })
		UI.text({ Name = "Src", Text = fact[3], FontFace = F.mono, TextSize = 11, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = col })
	end
	UI.rule({ LayoutOrder = 8, Parent = fileP })
	UI.text({ Text = ctx.t("ui_sources") .. ":  " .. table.concat(f.sources, "  ·  "), FontFace = F.mono, TextSize = 11, TextColor3 = COL.dim, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 9, Parent = fileP })
	for _, d in fileP:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 26 end end
	fileP.Visible = true
	UI.pop(fileP, 0.98)
	ctx.audio.sfx("ui", nil, 0.4)
end
local function buildFile()
	fileBtn = UI.iconButton({ name = "NasaFileButton", icon = "info", key = "N", order = 3, parent = ctx.iconBar or ctx.gui })
	fileP = UI.panel({ Name = "NasaFile", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(584, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 25, Parent = ctx.gui })
	fileP.BackgroundColor3 = COL.bg
	fileP.BackgroundTransparency = 0.04
	UI.pad(24, 24, 24, 24).Parent = fileP
	UI.list(Enum.FillDirection.Vertical, 12).Parent = fileP
	fileBtn.MouseButton1Click:Connect(function() if fileP.Visible then fileP.Visible = false else showFile() end end)
	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == Enum.KeyCode.N and not ctx.locked() then if fileP.Visible then fileP.Visible = false else showFile() end end
		if inp.KeyCode == Enum.KeyCode.Escape then fileP.Visible = false end
	end)
	table.insert(ctx.refreshers, function() if fileP.Visible then showFile() end end)
end
function Hud.setFileVisible(on) if fileBtn then fileBtn.Visible = on end end

------------------------------------------------------------------ post-mission quiz (one question from the NASA file)
local quizP
local lastPhase = nil
local function closeQuiz()
	if quizP then quizP:Destroy() quizP = nil end
end
local function showQuiz(missionId)
	local f = NasaFiles[missionId]
	if not f or not f.quiz then return end
	-- only on the report screen: never carry the quiz into the next mission
	if lastPhase ~= "Debrief" then return end
	local L = li()
	if quizP then quizP:Destroy() end
	quizP = UI.panel({ Name = "Quiz", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 40, Parent = ctx.gui })
	quizP.BackgroundColor3 = COL.bg
	quizP.BackgroundTransparency = 0.02
	UI.pad(24, 24, 24, 24).Parent = quizP
	UI.list(Enum.FillDirection.Vertical, 8).Parent = quizP
	UI.label({ Text = ctx.t("quiz_title") .. "  ·  +15 ₵", TextColor3 = COL.accent, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0, ZIndex = 41, Parent = quizP })
	UI.text({ Text = f.quiz.q[L], FontFace = F.title, TextSize = 20, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, ZIndex = 41, Parent = quizP })
	UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 4), LayoutOrder = 2, ZIndex = 41, Parent = quizP })
	local idx = { 1, 2, 3 }
	for i = 3, 2, -1 do local j = math.random(1, i) idx[i], idx[j] = idx[j], idx[i] end
	local answered = false
	for order, k in idx do
		local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = COL.panel, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2 + order, ZIndex = 41, Parent = quizP }, { UI.corner(3) })
		local st = UI.stroke(COL.line, 1, 0.6)
		st.Parent = b
		UI.text({ Text = string.char(64 + order), FontFace = F.mono, TextSize = 13, TextColor3 = COL.dim, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(16, 44), ZIndex = 42, Parent = b })
		local l = UI.text({ Text = f.quiz.a[k][L], FontFace = F.bodyBold, TextSize = 15, TextWrapped = true, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 42, Parent = b })
		b.MouseEnter:Connect(function() if not answered then st.Transparency = 0 end end)
		b.MouseLeave:Connect(function() if not answered then st.Transparency = 0.6 end end)
		b.MouseButton1Click:Connect(function()
			if answered then return end
			answered = true
			local right = k == 1
			b.BackgroundColor3 = right and COL.green or COL.red
			st.Transparency = 1
			l.TextColor3 = right and COL.dark or Color3.new(1, 1, 1)
			RS.Nova.Remotes.Request:FireServer({ action = "quiz", missionId = missionId, choice = k })
			if not right then
				UI.text({ Text = ctx.t("quiz_right") .. " " .. f.quiz.a[1][L], FontFace = F.body, TextSize = 14, TextColor3 = COL.green, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 9, ZIndex = 41, Parent = quizP })
			end
			task.delay(3.5, function() if quizP then quizP:Destroy() quizP = nil end end)
		end)
	end
	UI.pop(quizP, 0.98)
end

------------------------------------------------------------------ "your job" card: one personal task per role (top-centre)
local roleCard, roleToken = nil, 0
local function showRoleCard(missionId, part)
	local role = player:GetAttribute("Class")
	local set = RoleLines[missionId] and RoleLines[missionId][part]
	local line = set and role and set[role]
	if not line then return end
	local L = li()
	local col, icon = COL.text, "commander"
	for _, r in Config.Roles do if r.id == role then col, icon = r.color, r.icon end end
	if roleCard then roleCard:Destroy() end
	roleToken += 1
	local tok = roleToken
	roleCard = UI.panel({ Name = "RoleCard", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(560, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 30, Parent = ctx.hudLayer or ctx.gui })
	local lay = ctx.layout or { below = 68 }
	roleCard.Position = UDim2.new(0.5, 0, 0, lay.below + 104)
	UI.new("UIPadding", { PaddingBottom = UDim.new(0, 16), Parent = roleCard })
	UI.new("Frame", { Name = "Mark", BackgroundColor3 = col, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(2, 24), ZIndex = 31, Parent = roleCard }) -- role colour: small marker
	UI.icon(icon, 24, COL.text, { Position = UDim2.fromOffset(20, 16), ZIndex = 31, Parent = roleCard })
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(64, 16), Size = UDim2.new(1, -88, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 31, Parent = roleCard }, { UI.list(Enum.FillDirection.Vertical, 4) })
	UI.label({ Text = ctx.t("ui_your_job") .. "  ·  " .. ctx.t("role_" .. role), TextColor3 = COL.dim, TextSize = 11, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, ZIndex = 31, Parent = body })
	UI.text({ Text = line[L], FontFace = F.title, TextSize = 17, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2, ZIndex = 31, Parent = body })
	UI.pop(roleCard, 0.98)
	pcall(function() ctx.audio.sfx("click", nil, 0.5) end)
	task.delay(9, function() if tok == roleToken and roleCard then roleCard:Destroy() roleCard = nil end end)
end

function Hud.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	-- saved settings arrive as a player attribute (server copies them from the profile)
	local function loadSaved()
		local raw = player:GetAttribute("Settings")
		if typeof(raw) == "string" then
			local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and typeof(t) == "table" then
				for _, k in { "music", "sfx", "ambience" } do if typeof(t[k]) == "number" then ctx.audio.settings[k] = math.clamp(t[k], 0, 1) end end
				if typeof(t.shake) == "boolean" then ctx.audio.settings.shake = t.shake end
				ctx.audio.apply()
				if (t.lang == "ru" or t.lang == "en") and ctx.lang and ctx.lang() ~= t.lang then ctx.toggleLang() end
				for _, f in ctx.refreshers do pcall(f) end
			end
		end
	end
	buildPoll()
	buildCard()
	buildSettings()
	buildFile()
	loadSaved()
	player:GetAttributeChangedSignal("Settings"):Connect(loadSaved)
	RS.Nova.Remotes.Cue.OnClientEvent:Connect(function(msg)
		if typeof(msg) ~= "table" then return end
		if msg.type == "debrief" and msg.win then lastPhase = "Debrief" task.delay(6, function() showQuiz(msg.missionId) end)
		elseif msg.type == "briefing" or msg.type == "cutscene" then closeQuiz()
		elseif msg.type == "roleBrief" then showRoleCard(msg.missionId, msg.part)
		elseif msg.type == "quizResult" then
			ctx.toast(msg.ok and "check" or "info", ctx.t(msg.ok and "quiz_ok" or "quiz_no") .. ((msg.reward or 0) > 0 and ("  +" .. msg.reward .. " ₵") or ""), msg.ok and "green" or "yellow")
		elseif msg.type == "labReward" then
			ctx.toast("rocket", ctx.t("lab_reward") .. "  +" .. (msg.reward or 0) .. " ₵", "green")
		end
	end)
	RS.Nova.Remotes.State.OnClientEvent:Connect(function(st)
		if typeof(st) ~= "table" or typeof(st.phase) ~= "string" then return end
		lastPhase = st.phase
		if st.phase ~= "Debrief" then closeQuiz() end
	end)
	PPS.PromptShown:Connect(function(prompt)
		local holder = prompt.Parent
		local id = holder and holder:GetAttribute("ModuleId")
		if id and prompt:GetAttribute("Key") == "p_take" then showCard(id, prompt) end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		if prompt == cardPrompt and card then card.Visible = false cardPrompt = nil end
	end)
end

return Hud
