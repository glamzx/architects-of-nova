-- Cinema: cold open, hologram dialogue + subtitles, team votes, launch and flight cinematics.
-- Camera work is client-side; timing comes from the server so the whole crew stays in sync.
-- Visual style: black surfaces, white text, one red accent, 1px lines, small radius, tracked uppercase labels.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Remotes = RS.Nova.Remotes
local Locations = require(RS.Nova.Data.Locations)

local C = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local ctx, UI, COL, F
local ACC, WHITE, DIM, LINE, FL
local BLACK = Color3.new(0, 0, 0)
local FX
pcall(function() FX = require(RS:WaitForChild("NovaFX", 3)) end)

local layer, bars, fade, dlg, dlgIc, dlgWho, dlgTag, dlgLine, dlgBar, voteP
local capLbl, capRule, capScrim, bigLbl, titleF, titleLbl, titleRule, tagLbl
local activeShots = 0
local SPEAKER = {
	kade = { icon = "commander" },
	vex = { icon = "warning" },
	bip = { icon = "spark" },
	echo = { icon = "data" },
}
local DLG_FREE = 118   -- px above the screen bottom in free play (clears the carry chip / co-op panel)

-- wide tracking for condensed uppercase labels (thin spaces between letters)
local function spaced(s)
	local ok, res = pcall(function()
		local out = {}
		for _, c in utf8.codes(s) do out[#out + 1] = utf8.char(c) end
		return table.concat(out, "\u{2009}")
	end)
	return ok and res or s
end

local frozen = nil
local function controls(on)
	-- freeze the character during cinematics (works with or without the default PlayerModule)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local ps = player:FindFirstChild("PlayerScripts")
	local pmod = ps and ps:FindFirstChild("PlayerModule")
	if pmod then pcall(function() local c = require(pmod):GetControls() if on then c:Enable() else c:Disable() end end) end
	if hum then
		if not on then
			frozen = { hum.WalkSpeed, hum.JumpHeight }
			hum.WalkSpeed, hum.JumpHeight = 0, 0
			player:SetAttribute("CineFrozen", true)
		else
			if frozen then hum.WalkSpeed, hum.JumpHeight = 16, 7.2 end
			frozen = nil
			player:SetAttribute("CineFrozen", nil)
		end
	end
end

local placeDialog
function C.lock()
	activeShots += 1
	if activeShots == 1 then
		controls(false)
		cam.CameraType = Enum.CameraType.Scriptable
		ctx.setHudHidden(true)
		TweenService:Create(bars[1], TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
		TweenService:Create(bars[2], TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
		placeDialog()
	end
end
function C.unlock()
	activeShots = math.max(0, activeShots - 1)
	if activeShots == 0 then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		controls(true)
		ctx.setHudHidden(false)
		TweenService:Create(bars[1], TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		TweenService:Create(bars[2], TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		placeDialog()
	end
end
function C.locked() return activeShots > 0 end

------------------------------------------------------------------ captions
-- caption(text, color, size): sentences sit in the lower third over a soft scrim; big numbers sit in the centre.
-- Only two colours: white, or the red accent.
local function caption(text, color, size)
	local big = (size or 30) >= 60
	local col = (color == ACC) and ACC or WHITE
	local lbl = big and bigLbl or capLbl
	lbl.Text = text or ""
	lbl.TextColor3 = col
	if big then lbl.TextSize = size end
	lbl.TextTransparency = 1
	TweenService:Create(lbl, TweenInfo.new(0.45), { TextTransparency = 0 }):Play()
	local st = lbl:FindFirstChildOfClass("UIStroke")
	if st then TweenService:Create(st, TweenInfo.new(0.45), { Transparency = 0.55 }):Play() end
	if not big then
		TweenService:Create(capRule, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(capScrim, TweenInfo.new(0.45), { BackgroundTransparency = 0 }):Play()
	end
end
local function captionOut()
	for _, lbl in { capLbl, bigLbl } do
		TweenService:Create(lbl, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		local st = lbl:FindFirstChildOfClass("UIStroke")
		if st then TweenService:Create(st, TweenInfo.new(0.45), { Transparency = 1 }):Play() end
	end
	TweenService:Create(capRule, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(capScrim, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end
local function fadeTo(a, t)
	TweenService:Create(fade, TweenInfo.new(t or 0.5), { BackgroundTransparency = 1 - a }):Play()
end
local function titleIn(title, tag)
	titleLbl.Text = spaced(string.upper(title or ""))
	tagLbl.Text = tag or ""
	titleF.Visible = true
	titleLbl.TextTransparency, tagLbl.TextTransparency, titleRule.BackgroundTransparency = 1, 1, 1
	titleRule.Size = UDim2.fromOffset(0, 2)
	TweenService:Create(titleLbl, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
	TweenService:Create(titleRule, TweenInfo.new(0.9, Enum.EasingStyle.Quart), { BackgroundTransparency = 0, Size = UDim2.fromOffset(72, 2) }):Play()
	task.delay(0.8, function() TweenService:Create(tagLbl, TweenInfo.new(0.8), { TextTransparency = 0.1 }):Play() end)
end
local function titleOut()
	if not titleF or not titleF.Visible then return end
	TweenService:Create(titleLbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(tagLbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(titleRule, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	task.delay(0.45, function() titleF.Visible = false end)
end

-- moves the camera from cf0 to cf1 over t seconds (cinematic ease)
local function shot(cf0, cf1, t, fov)
	cam.CFrame = cf0
	if fov then cam.FieldOfView = fov end
	TweenService:Create(cam, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cf1 }):Play()
end

local function shake(t, amp)
	if ctx and ctx.audio.settings.shake == false then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t0
		if k > t then conn:Disconnect() return end
		local a = (amp or 0.4) * (1 - k / t)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end)
end

-- follows a model with the camera for t seconds
local function track(getPos, offset, t)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > t then conn:Disconnect() return end
		local p = getPos()
		if p then cam.CFrame = CFrame.lookAt(p + offset, p) end
	end)
end

------------------------------------------------------------------ UI
local function buildUI()
	layer = UI.new("ScreenGui", { Name = "NovaCinema", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player.PlayerGui })
	bars = {
		UI.new("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), ZIndex = 2, Parent = layer }),
		UI.new("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 2, Parent = layer }),
	}
	fade = UI.new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = layer })
	local s = UI.new("UIScale", { Parent = layer })
	local function rescale() local vp = cam.ViewportSize s.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.72, 1.25) end
	rescale()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- captions: lower-third sentence over a soft dark scrim, plus a centred label for big numbers
	capScrim = UI.new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.89, 0), Size = UDim2.new(1, 0, 0, 190), ZIndex = 6, Parent = layer }, {
		UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 0.35) }) }),
	})
	capLbl = UI.text({ FontFace = F.bodyBold or F.body, TextSize = 30, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Bottom, TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.89, -30), Size = UDim2.new(0.74, 0, 0, 100), TextTransparency = 1, ZIndex = 7, Parent = layer })
	UI.new("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 1, Parent = capLbl })
	capRule = UI.new("Frame", { BackgroundColor3 = ACC, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.89, -138), Size = UDim2.fromOffset(40, 2), ZIndex = 7, Parent = layer })
	bigLbl = UI.text({ FontFace = FL, TextSize = 96, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(0.8, 0, 0, 130), TextTransparency = 1, ZIndex = 7, Parent = layer })
	UI.new("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 1, Parent = bigLbl })
	-- title card (end of the cold open)
	titleF = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.9, 0, 0, 150), Visible = false, ZIndex = 8, Parent = layer })
	-- soft dark band behind the title so it reads over any background
	local scrimG = UI.new("CanvasGroup", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.new(1.15, 0, 0, 230), ZIndex = 7, Parent = titleF }, {
		UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	UI.new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = scrimG }, {
		UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	titleLbl = UI.text({ FontFace = FL, TextSize = 50, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 64), ZIndex = 8, Parent = titleF })
	UI.new("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 0.6, Parent = titleLbl })
	titleRule = UI.new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(72, 2), ZIndex = 8, Parent = titleF })
	tagLbl = UI.text({ FontFace = F.body, TextSize = 21, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 28), ZIndex = 8, Parent = titleF })
	UI.new("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 0.6, Parent = tagLbl })

	-- subtitle box: speaker label, the line, a thin red timer line. Always drawn above bars, fades and HUD.
	dlg = UI.new("Frame", { Name = "Subtitle", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -DLG_FREE), Size = UDim2.new(0.62, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false, ZIndex = 10, Parent = layer }, {
		UI.corner(3), UI.new("UISizeConstraint", { MinSize = Vector2.new(540, 0), MaxSize = Vector2.new(900, 600) }),
	})
	UI.stroke(LINE, 1, 0.78).Parent = dlg
	local body = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10, Parent = dlg }, {
		UI.pad(14, 22, 18, 22), UI.list(Enum.FillDirection.Vertical, 9),
	})
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, ZIndex = 10, Parent = body })
	UI.new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 6), ZIndex = 11, Parent = head })
	dlgIc = UI.icon("commander", 18, WHITE, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), ZIndex = 11, Parent = head })
	dlgWho = UI.text({ FontFace = FL, TextSize = 13, TextColor3 = WHITE, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -200, 1, 0), ZIndex = 11, Parent = head })
	dlgTag = UI.text({ FontFace = FL, TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 160, 1, 0), ZIndex = 11, Parent = head })
	UI.new("Frame", { BackgroundColor3 = LINE, BackgroundTransparency = 0.86, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, ZIndex = 10, Parent = body })
	dlgLine = UI.text({ FontFace = F.bodyBold or F.body, TextSize = 24, TextColor3 = WHITE, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 30), LineHeight = 1.08, LayoutOrder = 3, ZIndex = 10, Parent = body })
	dlgBar = UI.new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2), ZIndex = 12, Parent = dlg })

	voteP = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(904, 556), BackgroundColor3 = BLACK, BackgroundTransparency = 0.04,
		BorderSizePixel = 0, Visible = false, ZIndex = 12, Parent = layer }, { UI.corner(4) })
	UI.stroke(LINE, 1, 0.8).Parent = voteP
end

-- the subtitle box sits just above the bottom letterbox bar in cinematics, above the HUD's bottom row in free play
function placeDialog()
	if not dlg then return end
	if activeShots > 0 then
		dlg.Position = UDim2.new(0.5, 0, 0.89, -14)
	else
		dlg.Position = UDim2.new(0.5, 0, 1, -DLG_FREE)
	end
end

local typing = 0
local function typewriter(lbl, text)
	typing += 1
	local my = typing
	lbl.Text = text
	lbl.MaxVisibleGraphemes = 0
	task.spawn(function()
		local n = utf8.len(text) or #text
		local i = 0
		while i < n do
			if my ~= typing then return end
			i = math.min(n, i + 2)
			lbl.MaxVisibleGraphemes = i
			task.wait(0.022)
		end
		lbl.MaxVisibleGraphemes = -1
	end)
end

local holoMode, dialogActive, radioMode = false, false, false
-- hologram position (tolerates the projector being rebuilt or not streamed in yet)
local function holoPos()
	local atr = workspace:FindFirstChild("Citadel") and workspace.Citadel:FindFirstChild("Atrium")
	local holo = atr and atr:FindFirstChild("Hologram")
	local pr = holo and holo:FindFirstChild("Projector")
	if pr and pr:IsA("BasePart") then return pr.Position end
	if holo then return holo:GetPivot().Position end
	return Vector3.new(0, 0, 0)
end
local function holoCamera()
	local h = holoPos()
	local target = h + Vector3.new(0, 8, 0)
	shot(CFrame.lookAt(h + Vector3.new(12, 10, 24), target), CFrame.lookAt(h + Vector3.new(6, 9.5, 17), target), 7, 50)
end

function C.dialogStart(where)
	dialogActive = true
	if where == "hologram" then
		holoMode = true
		C.lock()
		holoCamera()
		-- music: calm theme under a briefing, the triumphant cue for the story beat after a successful mission
		local st = ctx.state and ctx.state()
		ctx.audio.music((st and st.phase == "Briefing") and "briefing" or "victory")
	end
	placeDialog()
end

function C.dialog(who, key, time)
	local sp = SPEAKER[who] or SPEAKER.kade
	UI.setIcon(dlgIc, sp.icon)
	dlgIc.ImageColor3 = (who == "vex") and ACC or WHITE
	dlgWho.Text = spaced(string.upper(ctx.t("who_" .. who)))
	dlgWho.TextColor3 = (who == "vex") and ACC or WHITE
	dlgTag.Text = spaced(string.upper(ctx.t(holoMode and "cine_tag_holo" or (radioMode and "cine_tag_radio" or "cine_tag_comms"))))
	typewriter(dlgLine, ctx.t(key))
	placeDialog()
	dlg.Visible = true
	UI.pop(dlg, 0.97)
	dlgBar.Size = UDim2.new(0, 0, 0, 2)
	TweenService:Create(dlgBar, TweenInfo.new(math.max(0.5, (time or 3) - 0.1), Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 0, 2) }):Play()
	ctx.audio.sfx("click", nil, 0.2)
	if who == "vex" and holoMode and ctx.audio.currentMusic() ~= "victory" then ctx.audio.music("tension") end
	if holoMode then
		local h = holoPos()
		local target = h + Vector3.new(0, 8, 0)
		local side = (who == "vex") and -1 or 1
		shot(cam.CFrame, CFrame.lookAt(h + Vector3.new(7 * side, 9.4, 16), target), 2.5)
	end
end

-- radio line: same subtitle box, auto-hides, never locks the camera (BIP-7 tips during play).
-- Lines that arrive during a dialogue wait until it ends, so they are never lost or cut short.
local radioToken, pendingRadio = 0, nil
function C.radio(who, key, time)
	if dialogActive then pendingRadio = { who, key, time, os.clock() } return end
	radioToken += 1
	local tok = radioToken
	local txt = ctx.t(key)
	local show = math.max(time or 4, 1.8 + (utf8.len(txt) or #txt) * 0.055)
	radioMode = true
	C.dialog(who, key, show)
	radioMode = false
	task.delay(show, function()
		if tok == radioToken and not dialogActive then dlg.Visible = false end
	end)
end

function C.dialogEnd()
	dialogActive = false
	dlg.Visible = false
	if holoMode then
		holoMode = false
		C.unlock()
	end
	ctx.audio.music(ctx.defaultMusic())
	local p = pendingRadio
	pendingRadio = nil
	if p and os.clock() - p[4] < 15 then task.delay(0.8, function() if not dialogActive then C.radio(p[1], p[2], p[3]) end end) end
end

------------------------------------------------------------------ team vote
local voteCards, voteTimer, voteCounts = {}, nil, {}
local VoteInfo = require(RS.Nova.Data.VoteInfo)
local VoteArt = require(script.Parent:WaitForChild("VoteArt"))
local voteStops = {}
local function stopVoteArt()
	for _, f in voteStops do pcall(f) end
	voteStops = {}
end
-- Team vote: two big cards, each with a live 3D preview of the option, pros/cons and one line about
-- what it means, so every player understands what they choose.
function C.vote(c)
	stopVoteArt()
	for _, ch in voteP:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	voteCards, voteCounts = {}, {}
	local li = ctx.t("on") == "ВКЛ" and 1 or 2
	local TONE = { good = WHITE, warn = ACC, info = DIM }
	voteP.Size = UDim2.fromOffset(904, 556)
	voteP.Position = UDim2.fromScale(0.5, 0.5)
	UI.new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(6, 6), ZIndex = 13, Parent = voteP })
	UI.text({ Text = spaced(string.upper(ctx.t("vote"))), FontFace = FL, TextSize = 12, TextColor3 = WHITE, Position = UDim2.fromOffset(42, 20), Size = UDim2.fromOffset(400, 18), ZIndex = 13, Parent = voteP })
	UI.text({ Text = ctx.t(c.key), FontFace = F.title, TextSize = 28, TextColor3 = WHITE, TextWrapped = true, Position = UDim2.fromOffset(28, 44), Size = UDim2.new(1, -56, 0, 36), ZIndex = 13, Parent = voteP })
	UI.new("Frame", { BackgroundColor3 = LINE, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(28, 86), Size = UDim2.new(1, -56, 0, 1), ZIndex = 13, Parent = voteP })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 100), Size = UDim2.new(1, -48, 0, 404), ZIndex = 13, Parent = voteP }, { UI.list(Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center) })
	for i, opt in c.options do
		local info = VoteInfo[opt.key] or {}
		local b = UI.new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(12, 12, 14), BorderSizePixel = 0, Size = UDim2.fromOffset(418, 404), LayoutOrder = i, ZIndex = 13, Parent = row }, { UI.corner(3) })
		local st = UI.stroke(LINE, 1, 0.8)
		st.Parent = b
		local sc = UI.new("UIScale", { Parent = b })
		local vf = UI.new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(5, 5, 7), BorderSizePixel = 0, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 0, 200), ZIndex = 14, Parent = b }, { UI.corner(2) })
		table.insert(voteStops, VoteArt.mount(vf, info.art))
		local key = UI.new("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 14), ZIndex = 16, Parent = b }, { UI.corner(2) })
		UI.stroke(LINE, 1, 0.35).Parent = key
		UI.text({ Text = tostring(i), FontFace = FL, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 17, Parent = key })
		local cnt = UI.text({ Text = "", FontFace = FL, TextSize = 16, TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -112, 0, 18), Size = UDim2.fromOffset(96, 22), ZIndex = 16, Parent = b })
		UI.text({ Text = ctx.t(opt.key), FontFace = F.title, TextSize = 21, TextColor3 = WHITE, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(18, 214), Size = UDim2.new(1, -36, 0, 50), ZIndex = 14, Parent = b })
		local tags = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 268), Size = UDim2.new(1, -36, 0, 92), ZIndex = 14, Parent = b }, { UI.list(Enum.FillDirection.Vertical, 6) })
		for k, tg in info.tags or {} do
			local tone = TONE[tg[2]] or WHITE
			local tr = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = k, ZIndex = 14, Parent = tags })
			UI.icon(tg[1], 16, tone, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), ZIndex = 15, Parent = tr })
			UI.text({ Text = tg[3][li], FontFace = F.body, TextSize = 15, TextColor3 = (tone == ACC) and ACC or WHITE, TextWrapped = true, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0), ZIndex = 14, Parent = tr })
		end
		if info.line then
			UI.new("Frame", { BackgroundColor3 = LINE, BackgroundTransparency = 0.88, BorderSizePixel = 0, Position = UDim2.new(0, 18, 1, -48), Size = UDim2.new(1, -36, 0, 1), ZIndex = 14, Parent = b })
			UI.text({ Text = info.line[li], FontFace = F.body, TextSize = 14, TextColor3 = DIM, TextWrapped = true, Position = UDim2.new(0, 18, 1, -40), Size = UDim2.new(1, -36, 0, 32), ZIndex = 14, Parent = b })
		end
		b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.015 }):Play() if st.Color ~= ACC then st.Transparency = 0.45 end end)
		b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() if st.Color ~= ACC then st.Transparency = 0.8 end end)
		b.MouseButton1Click:Connect(function() Remotes.Vote:FireServer(i) ctx.audio.sfx("click") end)
		voteCards[i] = { button = b, stroke = st, count = cnt }
	end
	UI.text({ Text = ctx.t("cine_vote_hint"), FontFace = F.body, TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 28, 1, -42), Size = UDim2.new(1, -56, 0, 16), ZIndex = 13, Parent = voteP })
	UI.new("Frame", { BackgroundColor3 = LINE, BackgroundTransparency = 0.88, BorderSizePixel = 0, Position = UDim2.new(0, 28, 1, -18), Size = UDim2.new(1, -56, 0, 2), ZIndex = 13, Parent = voteP })
	voteTimer = UI.new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, Position = UDim2.new(0, 28, 1, -18), Size = UDim2.new(1, -56, 0, 2), ZIndex = 14, Parent = voteP })
	TweenService:Create(voteTimer, TweenInfo.new(c.time or 12, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
	voteP.Visible = true
	UI.pop(voteP, 0.94)
	dlg.Visible = false
end

function C.voteCast(c)
	voteCounts[c.userId] = c.choice
	local n = {}
	for _, ch in voteCounts do n[ch] = (n[ch] or 0) + 1 end
	for i, card in voteCards do
		card.count.Text = n[i] and spaced(string.rep("●", n[i])) or ""
		if c.userId == player.UserId then
			card.stroke.Color = (i == c.choice) and ACC or LINE
			card.stroke.Transparency = (i == c.choice) and 0 or 0.8
		end
	end
end

function C.voteResult(c)
	for i, card in voteCards do
		local win = i == c.choice
		card.button.BackgroundColor3 = win and Color3.fromRGB(24, 24, 26) or Color3.fromRGB(8, 8, 9)
		card.stroke.Color = win and ACC or LINE
		card.stroke.Transparency = win and 0 or 0.92
	end
	ctx.toast("check", ctx.t("vote_result") .. ": " .. ctx.t(c.optionKey) .. (c.byCommander and (" · " .. ctx.t("tie_break")) or ""), "green")
	task.delay(1.8, function() voteP.Visible = false stopVoteArt() end)
end

UIS.InputBegan:Connect(function(input, gp)
	if gp or not voteP or not voteP.Visible then return end
	if input.KeyCode == Enum.KeyCode.One then Remotes.Vote:FireServer(1) end
	if input.KeyCode == Enum.KeyCode.Two then Remotes.Vote:FireServer(2) end
end)

------------------------------------------------------------------ cinematics
local function rocketPart(padPos)
	local la = workspace.Citadel.Hangar.LaunchArea
	local best, bd = nil, math.huge
	for _, pad in la:GetChildren() do
		local r = pad:FindFirstChild("Rocket")
		if r and r.PrimaryPart then
			local d = (r.PrimaryPart.Position - padPos).Magnitude
			if d < bd then best, bd = r, d end
		end
	end
	return best
end

-- Local, frame-perfect rocket climb driven by the server's ignition time (LaunchT0 attribute).
local function flyLocal(model, t0, dur, height)
	if typeof(model) ~= "Instance" or not t0 then return end
	local home = model:GetPivot()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not model.Parent or model:GetAttribute("LaunchT0") ~= t0 then conn:Disconnect() return end
		local t = workspace:GetServerTimeNow() - t0
		if t < 0 then return end
		local a = math.clamp(t / dur, 0, 1)
		local h = height * a * a * (0.55 + 0.45 * a)
		local pitch = math.rad(12) * math.max(0, a - 0.3) ^ 1.4
		model:PivotTo((home + Vector3.new(0, h, 0)) * CFrame.Angles(pitch, 0, 0))
		if a >= 1 then conn:Disconnect() end
	end)
end

-- engine sound for a launch: rumble swells in, then the big low roar at ignition
local function launchSound(delayRoar, vol)
	ctx.audio.sfx("rumble", nil, 0.75 * (vol or 1), { len = 6.5 })
	task.delay(delayRoar or 0.4, function() ctx.audio.sfx("rocket", nil, vol or 1) end)
end
-- the hyperspace tube: a whoosh into the jump and the tunnel hum for its length
local function warpSound(len, vol)
	ctx.audio.sfx("swoosh", nil, 0.75 * (vol or 1))
	ctx.audio.sfx("warp", nil, 0.65 * (vol or 1), { len = math.max(0.8, len - 1.1), fade = 1.1 })
end

function C.probeLaunch(data)
	local pad = data.pad or Vector3.new(-20, 0, -182)
	flyLocal(data.rocket, data.t0, data.dur or 6, 900)
	C.lock()
	ctx.audio.music("launch")
	shot(CFrame.lookAt(pad + Vector3.new(26, 4, 30), pad + Vector3.new(0, 18, 0)), CFrame.lookAt(pad + Vector3.new(22, 6, 26), pad + Vector3.new(0, 20, 0)), 3, 55)
	for i, n in { "3", "2", "1" } do
		task.delay((i - 1) * 0.9, function() caption(n, WHITE, 96) ctx.audio.sfx("click", nil, 0.4) end)
	end
	task.delay(2.4, function() launchSound(0.4, 1) end)
	task.delay(2.8, function()
		captionOut()
		if FX then FX.launch(pad + Vector3.new(0, 2, 0)) end
		shake(4, 0.6)
	end)
	task.delay(3.6, function()
		local r = (typeof(data.rocket) == "Instance" and data.rocket) or rocketPart(pad)
		track(function() return r and r.PrimaryPart and r.PrimaryPart.Position end, Vector3.new(40, -14, 46), 6)
	end)
	task.delay(9.6, function() C.unlock() end)
end

local function warpShot(t, where)
	cam.CFrame = CFrame.lookAt(where, where + Vector3.new(0, 0.2, -1))
	cam.FieldOfView = 85
	local stop = FX and FX.warp(cam, t)
	TweenService:Create(cam, TweenInfo.new(t), { FieldOfView = 100 }):Play()
	return stop
end

------------------------------------------------------------------ lander ship helpers
-- The lander on each landing pad is an anchored server model; cutscenes move it locally (client only) and put it
-- back afterwards. Characters are hidden locally while "aboard" so nobody is seen standing outside a flying ship.
local function shipAt(locId, site)
	local loc = workspace:FindFirstChild("Locations") and workspace.Locations:FindFirstChild(locId or "")
	local root = loc and (site == "B" and loc:FindFirstChild("SiteB") or loc)
	return root and root:WaitForChild("LanderShip", 2)
end

local function shipFX(ship, on)
	local nz = ship and ship:FindFirstChild("Nozzle")
	local att = nz and nz:FindFirstChild("Exhaust")
	if not att then return end
	for _, e in att:GetChildren() do if e:GetAttribute("CineFX") then e:Destroy() end end
	if not on then return end
	local core = Instance.new("ParticleEmitter")
	core.Texture = "rbxasset://textures/particles/fire_main.dds"
	core.Color = ColorSequence.new(Color3.fromRGB(255, 244, 220), Color3.fromRGB(255, 150, 60))
	core.LightEmission = 1
	core.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) })
	core.Lifetime = NumberRange.new(0.18, 0.3)
	core.Rate = 160
	core.Speed = NumberRange.new(22, 30)
	core.EmissionDirection = Enum.NormalId.Bottom
	core.SpreadAngle = Vector2.new(5, 5)
	core:SetAttribute("CineFX", true)
	core.Parent = att
	local plume = core:Clone()
	plume.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(200, 70, 30))
	plume.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 1.2) })
	plume.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	plume.Lifetime = NumberRange.new(0.3, 0.5)
	plume.Rate = 90
	plume.Speed = NumberRange.new(14, 20)
	plume.SpreadAngle = Vector2.new(12, 12)
	plume.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 26
	light.Brightness = 4
	light:SetAttribute("CineFX", true)
	light.Parent = att
end

local function dustPuff(pos, color, t)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.new(8, 1, 8)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(200, 196, 190))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 14) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.6, 2.6)
	e.Rate = 90
	e.Speed = NumberRange.new(10, 18)
	e.Drag = 2.2
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, -3, 0)
	e.Parent = p
	task.delay(t or 1.4, function() e.Enabled = false end)
	game:GetService("Debris"):AddItem(p, (t or 1.4) + 3)
end

local DUST = { moon = Color3.fromRGB(196, 196, 200), mars = Color3.fromRGB(200, 120, 80), europa = Color3.fromRGB(220, 232, 240), asteroid = Color3.fromRGB(150, 140, 130) }

-- move the ship from a to b over t seconds (client only)
local function shipMove(ship, a, b, t, style, dir)
	local v = Instance.new("CFrameValue")
	v.Value = a
	ship:PivotTo(a)
	local conn = v.Changed:Connect(function(cf) if ship.Parent then ship:PivotTo(cf) end end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = b })
	tw:Play()
	tw.Completed:Once(function() conn:Disconnect() v:Destroy() end)
	return tw
end

local hiddenChars = false
local function hideCrew(on)
	hiddenChars = on
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		if ch then for _, d in ch:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end end end
	end
end
RunService.RenderStepped:Connect(function()
	-- keep characters hidden while a ship cutscene runs (animations reset the modifier on some rigs)
	if not hiddenChars then return end
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		if ch then for _, d in ch:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end end end
	end
end)

-- touchdown: the lander comes down onto its pad with engine fire and a dust cloud
local function shipLand(ship, t, locId)
	if not ship then return end
	local home = ship:GetPivot()
	shipFX(ship, true)
	ctx.audio.sfx("rumble", nil, 0.42, { len = t - 0.6, fade = 0.9, fadeIn = 0.4 })
	shipMove(ship, home * CFrame.new(0, 70, 0) * CFrame.Angles(math.rad(6), 0, math.rad(-4)), home, t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(t * 0.7, function() dustPuff(home.Position, DUST[locId], t * 0.4) end)
	task.delay(t * 0.68, function() ctx.audio.sfx("thump", nil, 0.45) end)
	task.delay(t + 0.15, function() shipFX(ship, false) ship:PivotTo(home) end)
end

-- liftoff: the lander climbs away; returns a function that puts it back on the pad
local function shipLift(ship, t, locId)
	if not ship then return function() end end
	local home = ship:GetPivot()
	shipFX(ship, true)
	dustPuff(home.Position, DUST[locId], 1.2)
	shipMove(ship, home, home * CFrame.new(0, 110, 0) * CFrame.Angles(math.rad(-8), 0, 0), t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	return function() shipFX(ship, false) ship:PivotTo(home) end
end

function C.crewFlight(data)
	local dest = data.dest
	local locDef
	for _, l in Locations do if l.id == dest then locDef = l end end
	local loc = workspace.Locations:FindFirstChild(dest)
	ctx.audio.ambience("cabin")
	flyLocal(data.model, data.t0, data.dur or 7, 1200)
	C.lock()
	ctx.audio.music("launch")
	-- 1: inside the capsule
	local cab = workspace.Citadel.CrewCabin
	local cc = cab.Seat.Position
	-- the crew in their seats, seen from the console; a slow push-in while the countdown runs
	shot(CFrame.lookAt(cc + Vector3.new(0.6, 7.4, -6.3), cc + Vector3.new(0, 2.6, 1.4)), CFrame.lookAt(cc + Vector3.new(0.3, 7.0, -5.9), cc + Vector3.new(0, 2.6, 1.4)), 3.2, 72)
	caption(spaced(string.upper(ctx.t("countdown"))), ACC, 24)
	for i, n in { "3", "2", "1" } do task.delay(0.6 + (i - 1) * 0.8, function() captionOut() caption(n, WHITE, 90) shake(0.4, 0.15) end) end
	-- 2: liftoff outside
	task.delay(3.2, function()
		captionOut()
		local pad = data.rocket or Vector3.new(74, 0, -184)
		local rk = (typeof(data.model) == "Instance" and data.model) or workspace.Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("Rocket")
		local base = rk and rk:GetPivot().Position or pad
		-- clear line of sight from the runway side (the old angle looked through the hangar truss)
		shot(CFrame.lookAt(base + Vector3.new(36, -13, 62), base + Vector3.new(0, 5, 0)), CFrame.lookAt(base + Vector3.new(32, -9, 56), base + Vector3.new(0, 27, 0)), 2.5, 55)
		task.delay(1.4, function() launchSound(0.6, 1) end)
		task.delay(2.2, function() if FX then FX.launch(pad + Vector3.new(0, 2, 0)) end shake(3, 0.7) end)
		task.delay(2.5, function()
			local r = (typeof(data.model) == "Instance" and data.model) or workspace.Citadel.Hangar.LaunchArea.CrewPad:FindFirstChild("Rocket")
			track(function() return r and r:GetPivot().Position end, Vector3.new(36, -18, 60), 3.8)
		end)
	end)
	-- 3: hyperspace jump
	task.delay(9.5, function()
		ctx.audio.music("warp")
		warpSound(5.4, 1)
		fadeTo(1, 0.15)
		task.wait(0.2)
		fadeTo(0, 0.4)
		caption(spaced(string.upper(ctx.t("flight_jump"))), WHITE, 26)
		warpShot(5.2, Vector3.new(0, 3000, 0))
		task.delay(2.5, captionOut)
	end)
	-- 4: approach + descent over the destination
	task.delay(15, function()
		fadeTo(1, 0.15)
		task.wait(0.2)
		fadeTo(0, 0.5)
		local sp = loc and loc:FindFirstChild("Spawn")
		local o = sp and sp.Position or (locDef and locDef.origin) or Vector3.zero
		caption(locDef and spaced(string.upper(ctx.t(locDef.nameKey))) or "", WHITE, 26)
		local ship = shipAt(dest, "A")
		if ship then
			hideCrew(true)
			local pad = ship:GetPivot().Position
			local side = (o - pad) * Vector3.new(1, 0, 1)
			side = side.Magnitude > 1 and side.Unit or Vector3.new(0, 0, 1)
			local right = side:Cross(Vector3.yAxis)
			shot(CFrame.lookAt(pad + side * 46 + right * 24 + Vector3.new(0, 26, 0), pad + Vector3.new(0, 22, 0)), CFrame.lookAt(pad + side * 34 + right * 16 + Vector3.new(0, 7, 0), pad + Vector3.new(0, 5, 0)), 4.4, 55)
			shipLand(ship, 3.8, dest)
			task.delay(2.6, function() shake(0.8, 0.25) end)
		else
			shot(CFrame.lookAt(o + Vector3.new(-160, 140, 160), o), CFrame.lookAt(o + Vector3.new(-40, 40, 50), o), 4.5, 60)
		end
		task.delay(3, captionOut)
	end)
	task.delay(19.6, function()
		fadeTo(1, 0.4)
		task.wait(0.6)
		hideCrew(false)
		C.unlock()
		fadeTo(0, 0.8)
		ctx.audio.music(ctx.defaultMusic())
	end)
end

-- short hop of the lander between the two sites of one world (server teleports at +4.6 s, site B starts at +9 s)
function C.landerHop(data)
	C.lock()
	hideCrew(true)
	local locId = data.loc
	local shipA = shipAt(locId, "A")
	local restoreA = function() end
	ctx.audio.sfx("rumble", nil, 0.55, { len = 2.8, fade = 1 })
	if shipA then
		local pad = shipA:GetPivot().Position
		local look = shipA:GetPivot().LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1)
		shot(CFrame.lookAt(pad - look * 40 + Vector3.new(14, 8, 0), pad + Vector3.new(0, 10, 0)), CFrame.lookAt(pad - look * 46 + Vector3.new(16, 10, 0), pad + Vector3.new(0, 40, 0)), 3.2, 55)
		ctx.audio.sfx("rocket", nil, 0.45, { len = 2.6, fade = 1.2 })
		restoreA = shipLift(shipA, 3.2, locId)
		shake(0.8, 0.2)
	end
	task.wait(3.0)
	warpSound(2.6, 0.7)
	fadeTo(1, 0.4)
	task.wait(0.4)
	restoreA()
	caption(spaced(string.upper(ctx.t("site_hop"))) .. "   ·   " .. ctx.t(data.nameKey or ""), WHITE, 24)
	task.wait(1.6)
	captionOut()
	local shipB = shipAt(locId, "B")
	if shipB then
		local pad = shipB:GetPivot().Position
		local look = shipB:GetPivot().LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1)
		local right = look:Cross(Vector3.yAxis)
		shot(CFrame.lookAt(pad - look * 36 + right * 18 + Vector3.new(0, 20, 0), pad + Vector3.new(0, 18, 0)), CFrame.lookAt(pad - look * 30 + right * 14 + Vector3.new(0, 6, 0), pad + Vector3.new(0, 4, 0)), 3.2, 55)
		shipLand(shipB, 3.0, locId)
	end
	fadeTo(0, 0.5)
	task.wait(3.1)
	fadeTo(1, 0.3)
	task.wait(0.35)
	hideCrew(false)
	C.unlock()
	fadeTo(0, 0.6)
end

function C.returnFlight(data)
	C.lock()
	hideCrew(true)
	ctx.audio.music("launch")
	local ship = shipAt(data.from, data.site or "A")
	local restore = function() end
	launchSound(0.3, 0.75)
	if ship then
		local pad = ship:GetPivot().Position
		local look = ship:GetPivot().LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1)
		shot(CFrame.lookAt(pad - look * 42 + Vector3.new(-14, 6, 0), pad + Vector3.new(0, 10, 0)), CFrame.lookAt(pad - look * 50 + Vector3.new(-16, 9, 0), pad + Vector3.new(0, 46, 0)), 3, 55)
		restore = shipLift(ship, 3, data.from)
		shake(0.8, 0.2)
	end
	task.delay(2.8, function()
		warpSound(4.4, 1)
		fadeTo(1, 0.15)
		task.wait(0.2)
		restore()
		fadeTo(0, 0.4)
		ctx.audio.music("warp")
		caption(spaced(string.upper(ctx.t("flight_return"))), WHITE, 24)
		warpShot(4.2, Vector3.new(0, 3500, 0))
		task.delay(2.2, captionOut)
	end)
	task.delay(7.2, function()
		fadeTo(1, 0.15)
		task.wait(0.2)
		fadeTo(0, 0.5)
		shot(CFrame.lookAt(Vector3.new(120, 160, 220), Vector3.new(0, 0, -40)), CFrame.lookAt(Vector3.new(40, 50, 80), Vector3.new(0, 4, 0)), 3.4, 60)
	end)
	task.delay(10.8, function()
		fadeTo(1, 0.3)
		task.wait(0.5)
		hideCrew(false)
		C.unlock()
		fadeTo(0, 0.7)
		ctx.audio.music(ctx.defaultMusic())
	end)
end

------------------------------------------------------------------ cold open
-- 1) CinemaIntro: Earth and the solar storm (3D, ~27 s)  2) the Citadel still has power  3) title card.
local function makeSkip()
	local b = UI.new("TextButton", { Name = "Skip", AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -22), Size = UDim2.fromOffset(180, 36),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 14, Parent = layer }, { UI.corner(2) })
	local st = UI.stroke(LINE, 1, 0.6)
	st.Parent = b
	UI.text({ Text = spaced(string.upper(ctx.t("cine_skip"))) .. "   ›", FontFace = FL, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = b })
	b.MouseEnter:Connect(function() st.Color, st.Transparency = ACC, 0 end)
	b.MouseLeave:Connect(function() st.Color, st.Transparency = LINE, 0.6 end)
	return b
end

function C.intro(onDone)
	C.lock()
	fadeTo(1, 0)
	local skip = makeSkip()
	local done, ctl = false, nil
	local function finish()
		if done then return end
		done = true
		if ctl then ctl.stop() ctl = nil end
		skip:Destroy()
		captionOut()
		titleOut()
		fadeTo(1, 0.4)
		task.wait(0.5)
		C.unlock()
		fadeTo(0, 0.8)
		if onDone then onDone() end
	end
	skip.MouseButton1Click:Connect(function() pcall(function() ctx.audio.sfx("click", nil, 0.3) end) task.spawn(finish) end)
	-- watchdog: whatever happens, the cold open always ends and hands over to the menu
	task.delay(55, function() if not done then finish() end end)
	local citadelBody
	local function citadel()
		local ok, err = pcall(citadelBody)
		if not ok then warn("[Cinema] intro tail: " .. tostring(err)) finish() end
	end
	citadelBody = function()
		if done then return end
		ctx.audio.music("hope")
		-- descend toward the Citadel: it still has power
		shot(CFrame.lookAt(Vector3.new(-260, 240, 300), Vector3.new(0, 0, -40)), CFrame.lookAt(Vector3.new(-60, 60, 90), Vector3.new(0, 8, -20)), 9, 60)
		fadeTo(0, 1.4)
		task.wait(1)
		if done then return end
		caption(ctx.t("cine_7"), WHITE, 30)
		task.wait(3.8)
		if done then return end
		captionOut()
		task.wait(0.5)
		if done then return end
		fadeTo(1, 0.35)
		task.wait(0.4)
		shot(CFrame.lookAt(Vector3.new(0, 14, 40), Vector3.new(0, 10, 0)), CFrame.lookAt(Vector3.new(0, 11, 26), Vector3.new(0, 9, 0)), 6, 55)
		fadeTo(0, 0.6)
		titleIn(ctx.t("game_title"), ctx.t("intro_tag"))
		task.wait(4.8)
		finish()
	end
	local ok, Intro = pcall(function() return require(script.Parent:WaitForChild("CinemaIntro", 5)) end)
	if ok and Intro then
		local ok2, res = pcall(Intro.play, {
			cam = cam, t = ctx.t, caption = caption, captionOut = captionOut, fadeTo = fadeTo, audio = ctx.audio, F = F, accent = ACC, spaced = spaced,
			shakeOK = function() return ctx.audio.settings.shake ~= false end,
			onDone = function() if not done then task.spawn(citadel) end end,
		})
		if ok2 then
			ctl = res
			fadeTo(0, 1.4)
		else
			warn("[Cinema] intro failed: " .. tostring(res))
			task.spawn(citadel)
		end
	else
		task.spawn(citadel)
	end
end

function C.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	ACC = COL.accent or Color3.fromRGB(224, 60, 49)
	WHITE = COL.text or Color3.new(1, 1, 1)
	DIM = COL.dim or Color3.fromRGB(150, 150, 150)
	LINE = COL.line or Color3.new(1, 1, 1)
	FL = F.label or F.display
	buildUI()
end

return C
