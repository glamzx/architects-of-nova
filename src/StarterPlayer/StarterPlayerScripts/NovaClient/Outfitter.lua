-- Outfitter: spacesuit customisation (suit colour, helmet style, visor tint, shoulder patch).
-- Live try-on of the player's own avatar in a ViewportFrame (drag to turn, base / space look); buy and put on via
-- Remotes.Shop ("buy" / "equip" / "profile"). ProgressService checks credits and rebuilds the real suit with the same
-- builder (Data.Progress.SuitKit), so the preview matches what everyone sees.
-- API: Outfitter.init(ctx) sets ctx.openOutfitter(); Outfitter.open(), Outfitter.close(), Outfitter.isOpen().
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local Nova = RS:WaitForChild("Nova")
local Remotes = Nova:WaitForChild("Remotes")
local Progress = require(Nova.Data.Progress)
local SuitKit = require(Nova.Data.Progress:WaitForChild("SuitKit"))
local Classes = require(Nova.Data.Classes)

local O = {}
local player = Players.LocalPlayer
local ctx
local profile
local opened = false

-- style: black, white type, one red accent, 1 px lines, small radius, condensed uppercase labels
local C = {
	panel = Color3.fromRGB(6, 6, 8),
	card = Color3.fromRGB(14, 14, 17),
	cardHover = Color3.fromRGB(24, 24, 28),
	white = Color3.fromRGB(244, 244, 242),
	dim = Color3.fromRGB(146, 148, 154),
	faint = Color3.fromRGB(86, 88, 94),
	line = Color3.fromRGB(255, 255, 255),
	red = Color3.fromRGB(224, 60, 49),
	black = Color3.fromRGB(0, 0, 0),
}
local FL = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local FLR = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Regular)
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FM = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local Z = 60

local ITEMS = { suit = {}, helmet = {}, visor = {}, patch = {} }
for _, it in Progress.outfit do if ITEMS[it.slot] then table.insert(ITEMS[it.slot], it) end end
local TABS = { { slot = "suit", key = "of_tab_suit" }, { slot = "helmet", key = "of_tab_helmet" }, { slot = "visor", key = "of_tab_visor" }, { slot = "patch", key = "of_tab_patch" } }

------------------------------------------------------------------ helpers
local function t(k) return ctx and ctx.t(k) or k end
-- UTF-8 aware upper case (Cyrillic too) and wide letter tracking for display labels
local function upper(s)
	local out = {}
	for _, c in utf8.codes(s) do
		if c >= 0x430 and c <= 0x44F then c -= 0x20 elseif c == 0x451 then c = 0x401 elseif c >= 97 and c <= 122 then c -= 32 end
		table.insert(out, utf8.char(c))
	end
	return table.concat(out)
end
local function track(s)
	local out = {}
	for _, c in utf8.codes(s) do table.insert(out, utf8.char(c)) end
	return table.concat(out, utf8.char(0x200A))
end
local function cap(k) return track(upper(t(k))) end

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	if children then for _, c in children do c.Parent = o end end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 3) }) end
local function stroke(tr, col) return new("UIStroke", { Color = col or C.line, Thickness = 1, Transparency = tr or 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function text(props)
	local d = { BackgroundTransparency = 1, FontFace = FB, TextColor3 = C.white, TextSize = 15, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = Z + 2 }
	for k, v in props do d[k] = v end
	return new("TextLabel", d)
end
local function hline(parent, x, y, w)
	return new("Frame", { BackgroundColor3 = C.line, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 1), ZIndex = Z + 1, Parent = parent })
end

local function owns(it) return it.price == 0 or (profile and profile.owned and profile.owned[it.id] == true) or false end
local function equippedId(slot) return SuitKit.resolve(profile and profile.equip)[slot].id end
local function credits() return profile and profile.credits or 0 end
local function classColor()
	local c = Classes.byId[player:GetAttribute("Class") or ""]
	return c and c.color or nil
end

------------------------------------------------------------------ state + widgets
local root, panel, pscale, titleLbl, subLbl, credTag, creditsLbl, escLbl
local vpHolder, vp, world, cam, previewLbl, hintLbl, flash
local modeBtns = {}
local tabBtns = {}
local grid, nameLbl, priceLbl, factLbl, statusLbl, actBtn, actLbl, actStroke, resetBtn, resetLbl
local tab = "suit"
local sel = {}
local previewEva = true
local model, stage
local center, dist = Vector3.zero, 12
local yaw, dragging, lastX, lastDrag = 0, false, 0, 0
local renderConn
local busy = false
local statusToken = 0

local render -- forward

local function setStatus(s, col)
	statusToken += 1
	local my = statusToken
	statusLbl.Text = s or ""
	statusLbl.TextColor3 = col or C.dim
	if s and s ~= "" then
		task.delay(4, function() if statusToken == my and statusLbl then statusLbl.Text = "" end end)
	end
end

------------------------------------------------------------------ live preview (own avatar clone)
local DEFAULT_IDLE = "rbxassetid://507766666"
local function rebuildSuit()
	if not model then return end
	local ok, err = pcall(SuitKit.build, model, SuitKit.resolve(sel), { eva = previewEva, roleCol = classColor(), lights = false })
	if not ok then warn("[Outfitter] preview suit: " .. tostring(err)) end
end

local function frameCamera()
	if not model then return end
	local cf, size = model:GetBoundingBox()
	center = cf.Position
	local h = math.max(size.Y, size.X * 0.95)
	dist = (h * 0.5) / math.tan(math.rad(cam.FieldOfView * 0.5)) * 1.16
	if stage then stage:Destroy() end
	stage = Instance.new("Model")
	stage.Name = "Stage"
	local floorY = cf.Position.Y - size.Y * 0.5
	local function disc(d, th, col, y)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.Size = Vector3.new(th, d, d)
		p.CFrame = CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = col
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = stage
	end
	disc(4.6, 0.08, Color3.fromRGB(16, 16, 19), floorY - 0.04)
	disc(4.9, 0.04, Color3.fromRGB(70, 72, 78), floorY - 0.08)
	disc(0.9, 0.02, C.red, floorY + 0.005)
	stage.Parent = world
end

local function setupPreview()
	if model then model:Destroy() model = nil end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	-- the avatar's own idle animation (animation packs), read before scripts are stripped
	local idleId = DEFAULT_IDLE
	pcall(function()
		local a = char:FindFirstChild("Animate")
		local anim = a and a:FindFirstChild("idle") and a.idle:FindFirstChildOfClass("Animation")
		if anim and anim.AnimationId ~= "" then idleId = anim.AnimationId end
	end)
	local was = char.Archivable
	char.Archivable = true
	local ok, c = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not c then return end
	local suit = c:FindFirstChild("NovaSuit")
	if suit then suit:Destroy() end
	for _, d in c:GetDescendants() do
		if d.Parent and (d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Light") or (d:IsA("Constraint") and not d:IsA("WeldConstraint"))) then
			d:Destroy()
		end
	end
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			local tt = d:GetAttribute("SuitT")
			if tt ~= nil then d.Transparency = tt d:SetAttribute("SuitT", nil) end
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
		end
	end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	hrp.Transparency = 1
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
	end
	c:PivotTo(CFrame.new(0, 0, 0))
	c.Parent = world
	model = c
	if hum then
		pcall(function()
			local animator = hum:FindFirstChildOfClass("Animator") or new("Animator", { Parent = hum })
			for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0) end
			local a = new("Animation", { AnimationId = idleId })
			local tr = animator:LoadAnimation(a)
			tr.Looped = true
			tr:Play(0)
		end)
	end
	rebuildSuit()
	frameCamera()
end

local function step(dt)
	if not opened or not cam then return end
	if not dragging and os.clock() - lastDrag > 1.6 then yaw += dt * 0.4 end
	local off = CFrame.Angles(0, yaw, 0) * Vector3.new(0, dist * 0.1, -dist)
	cam.CFrame = CFrame.lookAt(center + off, center)
	vp.LightDirection = cam.CFrame:VectorToWorldSpace(Vector3.new(0.5, -0.75, -1).Unit)
end

------------------------------------------------------------------ cards
local function stateText(it)
	if equippedId(it.slot) == it.id then return upper(t("of_equipped")), C.white, true end
	if owns(it) then return upper(t(it.price == 0 and "of_free" or "of_owned")), C.dim, false end
	return it.price .. " ₵", C.white, false
end

local function select(it)
	if sel[it.slot] == it.id then return end
	sel[it.slot] = it.id
	ctx.audio.sfx("click", nil, 0.25)
	setStatus("")
	render()
	rebuildSuit()
end

local function card(it, x, y, w, h, opts)
	opts = opts or {}
	local selected = sel[it.slot] == it.id
	local b = new("TextButton", { Name = it.id, AutoButtonColor = false, Text = "", BackgroundColor3 = C.card, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = Z + 2, Parent = grid }, { corner(3) })
	local st = stroke(selected and 0.05 or 0.86)
	st.Parent = b
	b.MouseEnter:Connect(function() b.BackgroundColor3 = C.cardHover if not selected then st.Transparency = 0.6 end end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = C.card if not selected then st.Transparency = 0.86 end end)
	b.MouseButton1Click:Connect(function() select(it) end)
	-- state line: price / owned / wearing (with the red dot)
	local s, col, eq = stateText(it)
	local row = new("Frame", { BackgroundTransparency = 1, Position = opts.statePos or UDim2.new(0, 0, 1, -24), Size = opts.stateSize or UDim2.new(1, 0, 0, 14), ZIndex = Z + 3, Parent = b }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = opts.left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if eq then new("Frame", { BackgroundColor3 = C.red, BorderSizePixel = 0, Size = UDim2.fromOffset(5, 5), LayoutOrder = 1, ZIndex = Z + 3, Parent = row }, { corner(3) }) end
	text({ Text = s, FontFace = eq and FL or FM, TextSize = 12, TextColor3 = col, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), LayoutOrder = 2,
		ZIndex = Z + 3, Parent = row })
	return b, selected
end

local function nameOn(b, it, y)
	text({ Text = track(upper(t(it.key))), FontFace = FL, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 6, 0, y), Size = UDim2.new(1, -12, 0, 16), ZIndex = Z + 3, Parent = b })
end

local function suitCard(it, x, y)
	local b = card(it, x, y, 120, 112)
	local sw = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = it.color, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(92, 40), ZIndex = Z + 3, Parent = b }, { corner(2), stroke(0.82) })
	if it.mat == "Foil" then
		new("UIGradient", { Rotation = 25, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)), ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 130, 130)) }), Parent = sw })
	else
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196)), Parent = sw })
	end
	nameOn(b, it, 62)
end

local function visorCard(it, x, y)
	local b = card(it, x, y, 120, 150)
	local col = it.color
	local disc = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(64, 64), ZIndex = Z + 3, Parent = b }, { corner(32), stroke(0.7) })
	new("UIGradient", { Rotation = 125, Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.45), col:Lerp(Color3.new(0, 0, 0), 0.35)), Parent = disc })
	new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(18, 8),
		Rotation = -30, ZIndex = Z + 4, Parent = disc }, { corner(4) })
	nameOn(b, it, 94)
end

local function patchCard(it, x, y)
	local b = card(it, x, y, 120, 150)
	local rim = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(240, 240, 236), BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(64, 64), ZIndex = Z + 3, Parent = b }, { corner(32) })
	local disc = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = it.color, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(54, 54), ZIndex = Z + 4, Parent = rim }, { corner(27) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(245, 245, 242), BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, -4),
		Size = UDim2.fromOffset(13, 13), Rotation = 45, ZIndex = Z + 5, Parent = disc })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = it.id == "patch_red" and Color3.fromRGB(245, 245, 242) or C.red, BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.fromOffset(34, 4), Rotation = -12, ZIndex = Z + 5, Parent = disc })
	nameOn(b, it, 94)
end

local function helmetThumb(parent, it)
	local v = new("ViewportFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(104, 104), Ambient = Color3.fromRGB(150, 150, 158),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(0.7, -0.8, 0.6), ZIndex = Z + 3, Parent = parent })
	local m = Instance.new("Model")
	local head = new("Part", { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.18, 1.18, 1.18), Color = Color3.fromRGB(78, 80, 86),
		Material = Enum.Material.SmoothPlastic, Anchored = true, CFrame = CFrame.new(), Parent = m })
	local f = new("Folder", { Parent = m })
	pcall(SuitKit.helmet, f, head, { helmet = it, visor = SuitKit.item(sel.visor) or SuitKit.item("visor_std"), suit = SuitKit.item(sel.suit) or SuitKit.item("suit_white") })
	m.Parent = v
	local c = new("Camera", { FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(-3.3, 1.2, -5.6), Vector3.new(0, 0.02, 0)), Parent = v })
	v.CurrentCamera = c
end

local function helmetCard(it, x, y)
	local b = card(it, x, y, 252, 112, { left = true, statePos = UDim2.fromOffset(118, 62), stateSize = UDim2.new(1, -126, 0, 14) })
	helmetThumb(b, it)
	text({ Text = track(upper(t(it.key))), FontFace = FL, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(118, 32),
		Size = UDim2.new(1, -126, 0, 20), ZIndex = Z + 3, Parent = b })
end

------------------------------------------------------------------ render
local function refreshModes()
	for _, m in modeBtns do
		local on = m.eva == previewEva
		m.btn.BackgroundTransparency = on and 0 or 1
		m.label.TextColor3 = on and C.black or C.dim
		m.label.Text = cap(m.key)
	end
end

local function refreshTexts()
	titleLbl.Text = cap("of_title")
	subLbl.Text = t("of_sub")
	credTag.Text = cap("of_credits")
	previewLbl.Text = cap("of_preview")
	hintLbl.Text = upper(t("of_drag"))
	escLbl.Text = t("of_esc")
	resetLbl.Text = cap("of_reset")
	for slot, tb in tabBtns do tb.label.Text = cap(tb.key) end
	refreshModes()
end

local function differs()
	if not profile then return false end
	local look = SuitKit.resolve(profile.equip)
	for _, s in SuitKit.SLOTS do if sel[s] ~= look[s].id then return true end end
	return false
end

local function setAction(style, label)
	actLbl.Text = label
	if style == "buy" then
		actBtn.BackgroundColor3, actBtn.BackgroundTransparency, actStroke.Transparency, actLbl.TextColor3 = C.red, 0, 1, C.white
	elseif style == "equip" then
		actBtn.BackgroundColor3, actBtn.BackgroundTransparency, actStroke.Transparency, actLbl.TextColor3 = C.white, 0, 1, C.black
	else -- disabled
		actBtn.BackgroundColor3, actBtn.BackgroundTransparency, actStroke.Transparency, actLbl.TextColor3 = C.panel, 0, 0.8, C.dim
	end
	actBtn.Active = style ~= "off"
end

function render()
	if not root then return end
	creditsLbl.Text = string.format("%d ₵", credits())
	for slot, tb in tabBtns do
		local on = slot == tab
		tb.label.TextColor3 = on and C.white or C.dim
		tb.under.Visible = on
	end
	for _, c in grid:GetChildren() do c:Destroy() end
	local list = ITEMS[tab]
	for i, it in list do
		if tab == "suit" then suitCard(it, ((i - 1) % 4) * 132, ((i - 1) // 4) * 124)
		elseif tab == "helmet" then helmetCard(it, ((i - 1) % 2) * 264, ((i - 1) // 2) * 124)
		elseif tab == "visor" then visorCard(it, (i - 1) * 132, 0)
		else patchCard(it, (i - 1) * 132, 0) end
	end
	-- detail of the selected item in this tab
	local it = SuitKit.item(sel[tab]) or ITEMS[tab][1]
	nameLbl.Text = track(upper(t(it.key)))
	factLbl.Text = t(it.fact)
	local eq = equippedId(it.slot) == it.id
	local own = owns(it)
	if eq then
		priceLbl.Text, priceLbl.TextColor3 = upper(t("of_equipped")), C.white
		setAction("off", cap("of_equipped"))
	elseif own then
		priceLbl.Text, priceLbl.TextColor3 = upper(t(it.price == 0 and "of_free" or "of_owned")), C.dim
		setAction("equip", cap("of_equip"))
	elseif credits() >= it.price then
		priceLbl.Text, priceLbl.TextColor3 = it.price .. " ₵", C.white
		setAction("buy", cap("of_buy") .. "   " .. it.price .. " ₵")
	else
		priceLbl.Text, priceLbl.TextColor3 = it.price .. " ₵", C.dim
		setAction("off", upper(string.format(t("of_need"), it.price - credits())))
		if statusLbl.Text == "" then statusLbl.Text = t("of_earn") statusLbl.TextColor3 = C.dim end
	end
	resetBtn.Visible = differs()
end

------------------------------------------------------------------ actions
local function act()
	local it = SuitKit.item(sel[tab])
	if busy or not it or not profile then return end
	if equippedId(it.slot) == it.id then return end
	local own = owns(it)
	if not own and credits() < it.price then
		ctx.audio.sfx("hold", nil, 0.3)
		setStatus(t("of_earn"), C.dim)
		return
	end
	busy = true
	actLbl.Text = "..."
	local ok, res = pcall(function() return Remotes.Shop:InvokeServer(own and "equip" or "buy", it.id) end)
	busy = false
	if ok and typeof(res) == "table" and res.status == "ok" then
		profile.equip = profile.equip or {}
		profile.owned = profile.owned or {}
		profile.equip[it.slot] = it.id
		if not own then profile.owned[it.id] = true end
		if typeof(res.credits) == "number" then profile.credits = res.credits end
		ctx.audio.sfx("install")
		setStatus(t(own and "of_worn" or "of_bought"), C.white)
		flash.BackgroundTransparency = 0.6
		TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	else
		ctx.audio.sfx("hold", nil, 0.3)
		setStatus(t(typeof(res) == "table" and res.key == "credits_c" and "of_earn" or "of_error"), C.red)
	end
	render()
end

local function fetchProfile()
	task.spawn(function()
		local ok, res = pcall(function() return Remotes.Shop:InvokeServer("profile") end)
		if ok and typeof(res) == "table" and res.status == "ok" and typeof(res.profile) == "table" then
			local first = profile == nil
			profile = res.profile
			if opened then
				if first then
					local look = SuitKit.resolve(profile.equip)
					for _, s in SuitKit.SLOTS do sel[s] = look[s].id end
					rebuildSuit()
				end
				render()
			end
		end
	end)
end

------------------------------------------------------------------ build
local function build()
	root = new("Frame", { Name = "Outfitter", BackgroundColor3 = C.black, BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Visible = false, Active = true, ZIndex = Z, Parent = ctx.gui })
	panel = new("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1040, 624),
		BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ZIndex = Z + 1, Parent = root }, { corner(4), stroke(0.8) })
	pscale = new("UIScale", { Parent = panel })

	-- header: red tick, title, subtitle, credits, close
	new("Frame", { BackgroundColor3 = C.red, BorderSizePixel = 0, Position = UDim2.fromOffset(28, 24), Size = UDim2.fromOffset(3, 26), ZIndex = Z + 2, Parent = panel })
	titleLbl = text({ FontFace = FL, TextSize = 30, Position = UDim2.fromOffset(42, 18), Size = UDim2.fromOffset(520, 34), Parent = panel })
	subLbl = text({ TextSize = 15, TextColor3 = C.dim, Position = UDim2.fromOffset(42, 52), Size = UDim2.fromOffset(520, 18), Parent = panel })
	credTag = text({ FontFace = FL, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -300, 0, 22), Size = UDim2.fromOffset(212, 14), Parent = panel })
	creditsLbl = text({ FontFace = FM, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -300, 0, 38), Size = UDim2.fromOffset(212, 30), Parent = panel })
	new("Frame", { BackgroundColor3 = C.line, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.new(1, -76, 0, 22), Size = UDim2.fromOffset(1, 44), ZIndex = Z + 2, Parent = panel })
	local close = new("TextButton", { Name = "Close", Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, Position = UDim2.new(1, -64, 0, 26), Size = UDim2.fromOffset(36, 36),
		ZIndex = Z + 2, Parent = panel }, { corner(3) })
	local cst = stroke(0.75)
	cst.Parent = close
	for _, r in { 45, -45 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 2),
			Rotation = r, ZIndex = Z + 3, Parent = close })
	end
	close.MouseEnter:Connect(function() cst.Transparency = 0.1 cst.Color = C.red end)
	close.MouseLeave:Connect(function() cst.Transparency = 0.75 cst.Color = C.line end)
	close.MouseButton1Click:Connect(function() O.close() end)
	new("Frame", { BackgroundColor3 = C.line, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(28, 80), Size = UDim2.new(1, -56, 0, 1), ZIndex = Z + 1, Parent = panel })

	-- preview
	vpHolder = new("Frame", { Name = "Preview", Position = UDim2.fromOffset(28, 98), Size = UDim2.fromOffset(440, 494), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		ClipsDescendants = true, ZIndex = Z + 1, Parent = panel }, {
		corner(3), stroke(0.86),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(30, 31, 36), Color3.fromRGB(4, 4, 6)) }),
	})
	vp = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(116, 118, 126), LightColor = Color3.fromRGB(255, 252, 246),
		LightDirection = Vector3.new(-0.4, -1, -0.6), ZIndex = Z + 2, Parent = vpHolder })
	world = new("WorldModel", { Parent = vp })
	cam = new("Camera", { FieldOfView = 30, Parent = vp })
	vp.CurrentCamera = cam
	flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = Z + 3, Parent = vpHolder })
	new("Frame", { BackgroundColor3 = C.red, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 19), Size = UDim2.fromOffset(6, 6), ZIndex = Z + 4, Parent = vpHolder }, { corner(3) })
	previewLbl = text({ FontFace = FL, TextSize = 12, TextColor3 = C.white, Position = UDim2.fromOffset(28, 14), Size = UDim2.fromOffset(180, 16), ZIndex = Z + 4, Parent = vpHolder })
	hintLbl = text({ FontFace = FLR, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -236, 0, 14), Size = UDim2.fromOffset(220, 16),
		ZIndex = Z + 4, Parent = vpHolder })
	local seg = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(250, 34), BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.15, ZIndex = Z + 4, Parent = vpHolder }, { corner(3), stroke(0.7) })
	for i, m in { { eva = false, key = "of_mode_base" }, { eva = true, key = "of_mode_space" } } do
		local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.new((i - 1) * 0.5, 3, 0, 3),
			Size = UDim2.new(0.5, -6, 1, -6), ZIndex = Z + 5, Parent = seg }, { corner(2) })
		local l = text({ FontFace = FL, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = Z + 6, Parent = b })
		b.MouseButton1Click:Connect(function()
			if previewEva ~= m.eva then
				previewEva = m.eva
				ctx.audio.sfx("click", nil, 0.25)
				refreshModes()
				rebuildSuit()
			end
		end)
		table.insert(modeBtns, { btn = b, label = l, eva = m.eva, key = m.key })
	end
	vpHolder.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastX = i.Position.X
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			yaw -= (i.Position.X - lastX) * 0.012
			lastX = i.Position.X
			lastDrag = os.clock()
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then lastDrag = os.clock() end
			dragging = false
		end
	end)
	escLbl = text({ FontFace = FLR, TextSize = 12, TextColor3 = C.faint, Position = UDim2.fromOffset(28, 598), Size = UDim2.fromOffset(300, 16), Parent = panel })

	-- tabs
	local tabsF = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(496, 98), Size = UDim2.fromOffset(516, 38), ZIndex = Z + 1, Parent = panel })
	for i, tb in TABS do
		local b = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset((i - 1) * 129, 0), Size = UDim2.fromOffset(129, 38),
			ZIndex = Z + 2, Parent = tabsF })
		local l = text({ FontFace = FL, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 1, -4), ZIndex = Z + 3, Parent = b })
		local u = new("Frame", { BackgroundColor3 = C.red, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, -28, 0, 2),
			ZIndex = Z + 3, Parent = b })
		b.MouseEnter:Connect(function() if tab ~= tb.slot then l.TextColor3 = C.white end end)
		b.MouseLeave:Connect(function() if tab ~= tb.slot then l.TextColor3 = C.dim end end)
		b.MouseButton1Click:Connect(function()
			if tab ~= tb.slot then
				tab = tb.slot
				ctx.audio.sfx("click", nil, 0.25)
				setStatus("")
				render()
			end
		end)
		tabBtns[tb.slot] = { label = l, under = u, key = tb.key }
	end
	hline(panel, 496, 136, 516)
	grid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(496, 154), Size = UDim2.fromOffset(516, 236), ZIndex = Z + 1, Parent = panel })

	-- detail + actions
	hline(panel, 496, 404, 516)
	nameLbl = text({ FontFace = FL, TextSize = 24, Position = UDim2.fromOffset(496, 418), Size = UDim2.fromOffset(380, 30), Parent = panel })
	priceLbl = text({ FontFace = FM, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(876, 420), Size = UDim2.fromOffset(136, 26), Parent = panel })
	factLbl = text({ TextSize = 16, TextColor3 = C.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(496, 454), Size = UDim2.fromOffset(516, 42), Parent = panel })
	statusLbl = text({ TextSize = 14, TextColor3 = C.dim, Position = UDim2.fromOffset(496, 502), Size = UDim2.fromOffset(516, 18), Parent = panel })
	actBtn = new("TextButton", { Name = "Action", AutoButtonColor = false, Text = "", BackgroundColor3 = C.red, BorderSizePixel = 0, Position = UDim2.fromOffset(1012 - 250, 538),
		Size = UDim2.fromOffset(250, 54), ZIndex = Z + 2, Parent = panel }, { corner(3) })
	actStroke = stroke(1)
	actStroke.Parent = actBtn
	actLbl = text({ FontFace = FL, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = Z + 3, Parent = actBtn })
	local ascale = new("UIScale", { Parent = actBtn })
	actBtn.MouseEnter:Connect(function() if actBtn.Active then TweenService:Create(ascale, TweenInfo.new(0.1), { Scale = 1.02 }):Play() end end)
	actBtn.MouseLeave:Connect(function() TweenService:Create(ascale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	actBtn.MouseButton1Click:Connect(act)
	resetBtn = new("TextButton", { Name = "Reset", AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(496, 538), Size = UDim2.fromOffset(120, 54),
		ZIndex = Z + 2, Parent = panel }, { corner(3), stroke(0.78) })
	resetLbl = text({ FontFace = FL, TextSize = 14, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = Z + 3, Parent = resetBtn })
	resetBtn.MouseButton1Click:Connect(function()
		local look = SuitKit.resolve(profile and profile.equip)
		for _, s in SuitKit.SLOTS do sel[s] = look[s].id end
		ctx.audio.sfx("click", nil, 0.25)
		setStatus("")
		render()
		rebuildSuit()
	end)
	refreshTexts()
end

------------------------------------------------------------------ open / close
function O.open()
	if not ctx then return end
	if not root then build() end
	if opened then return end
	opened = true
	if not profile then fetchProfile() end
	local look = SuitKit.resolve(profile and profile.equip)
	for _, s in SuitKit.SLOTS do sel[s] = look[s].id end
	previewEva = true
	yaw = math.rad(-18)
	setStatus("")
	refreshTexts()
	render()
	root.Visible = true
	pscale.Scale = 0.97
	TweenService:Create(pscale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	setupPreview()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.RenderStepped:Connect(step)
	ctx.audio.sfx("click", nil, 0.3)
end

function O.close()
	if not opened then return end
	opened = false
	root.Visible = false
	dragging = false
	if renderConn then renderConn:Disconnect() renderConn = nil end
	if model then model:Destroy() model = nil end
	if stage then stage:Destroy() stage = nil end
end

function O.isOpen() return opened end

-- follow the shared UI theme when the main client provides it (accent #E03C31, Oswald labels)
local function adoptTheme()
	local COL, F = ctx.COL or {}, ctx.F or {}
	if typeof(COL.accent) == "Color3" then C.red = COL.accent end
	if typeof(COL.text) == "Color3" then C.white = COL.text end
	if typeof(COL.dim) == "Color3" then C.dim = COL.dim end
	if typeof(COL.panel2) == "Color3" then C.card = COL.panel2 C.cardHover = COL.panel2:Lerp(Color3.new(1, 1, 1), 0.06) end
	if typeof(F.head) == "Font" then FL = F.head end
	if typeof(F.display) == "Font" then FLR = F.display end
	if typeof(F.body) == "Font" then FB = F.body end
	if typeof(F.mono) == "Font" then FM = F.mono end
end

function O.init(c)
	ctx = c
	pcall(adoptTheme)
	ctx.openOutfitter = function() local ok, err = pcall(O.open) if not ok then warn("[Outfitter] " .. tostring(err)) end end
	ctx.closeOutfitter = function() pcall(O.close) end
	Remotes.Cue.OnClientEvent:Connect(function(cue)
		if typeof(cue) == "table" and cue.type == "profile" and typeof(cue.profile) == "table" then
			profile = cue.profile
			if opened then pcall(render) end
		end
	end)
	UIS.InputBegan:Connect(function(i)
		if opened and i.KeyCode == Enum.KeyCode.Escape then O.close() end
	end)
	if ctx.refreshers then
		table.insert(ctx.refreshers, function()
			if root then pcall(refreshTexts) if opened then pcall(render) end end
		end)
	end
	-- the avatar respawned while the panel is open: re-clone it
	player.CharacterAdded:Connect(function()
		if opened then task.delay(1, function() if opened then pcall(setupPreview) end end) end
	end)
	fetchProfile()
end

return O
