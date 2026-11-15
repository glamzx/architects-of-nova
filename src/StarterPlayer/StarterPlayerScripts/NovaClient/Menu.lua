-- Menu: main menu (create lobby / join by 6-digit code / difficulty / language), then lobby screen
-- with crew list and class selection. Closes when the lobby starts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = RS.Nova.Remotes
local Classes = require(RS.Nova.Data.Classes)

local Menu = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local ctx, UI, COL, F
local root, mainP, joinP, lobbyP, codeBox, statusLbl, difficulty
local open = false
local orbitConn

local function setStatus(key, col)
	statusLbl.Text = key and ctx.t(key) or ""
	statusLbl.TextColor3 = col or COL.dim
end

local function orbitCamera(on)
	if orbitConn then orbitConn:Disconnect() orbitConn = nil end
	if on then
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		orbitConn = RunService.RenderStepped:Connect(function()
			local a = (os.clock() - t0) * 0.05
			cam.CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * 120, 55, math.sin(a) * 120 - 30), Vector3.new(0, 8, -30))
		end)
	end
end

local function clear(p) for _, c in p:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end end

local function chipRow(parent, y, options, current, onPick)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, y), Size = UDim2.new(1, -72, 0, 40), Parent = parent }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	local btns = {}
	for i, o in options do
		local b = UI.new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = o.id == current and COL.amber or COL.panel2, Size = UDim2.fromOffset(112, 40), LayoutOrder = i, Parent = row }, { UI.corner(10) })
		local l = UI.text({ Text = ctx.t(o.key), FontFace = F.bodyBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = o.id == current and COL.dark or COL.text, Size = UDim2.fromScale(1, 1), Parent = b })
		btns[o.id] = { b = b, l = l }
		b.MouseButton1Click:Connect(function()
			for id, x in btns do x.b.BackgroundColor3 = id == o.id and COL.amber or COL.panel2 x.l.TextColor3 = id == o.id and COL.dark or COL.text end
			ctx.audio.sfx("click", nil, 0.3)
			onPick(o.id)
		end)
	end
end

local function showMain()
	clear(mainP)
	mainP.Visible, joinP.Visible, lobbyP.Visible = true, false, false
	UI.text({ Text = "NASA SPACE APPS 2026", FontFace = F.display, TextSize = 11, TextColor3 = COL.amber, Position = UDim2.fromOffset(36, 30), Size = UDim2.fromOffset(400, 14), Parent = mainP })
	UI.text({ Text = ctx.t("game_title"), FontFace = F.display, TextSize = 30, TextWrapped = true, Position = UDim2.fromOffset(36, 50), Size = UDim2.new(1, -72, 0, 80), Parent = mainP })
	UI.text({ Text = ctx.t("intro_tag"), FontFace = F.body, TextSize = 18, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 128), Size = UDim2.new(1, -72, 0, 22), Parent = mainP })
	UI.text({ Text = string.upper(ctx.t("menu_difficulty")), FontFace = F.display, TextSize = 11, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 176), Size = UDim2.fromOffset(300, 14), Parent = mainP })
	chipRow(mainP, 196, { { id = "cadet", key = "diff_cadet" }, { id = "pilot", key = "diff_pilot" }, { id = "master", key = "diff_master" } }, difficulty, function(id) difficulty = id end)
	local create = UI.button({ name = "Create", style = "primary", icon = "rocket", text = ctx.t("menu_create"), size = UDim2.new(1, -72, 0, 56), position = UDim2.fromOffset(36, 262), parent = mainP })
	local join = UI.button({ name = "Join", style = "secondary", icon = "headset", text = ctx.t("menu_join"), size = UDim2.new(1, -72, 0, 56), position = UDim2.fromOffset(36, 330), parent = mainP })
	local lang = UI.button({ name = "Lang", style = "ghost", text = "RU / EN", size = UDim2.fromOffset(140, 40), position = UDim2.fromOffset(36, 404), parent = mainP })
	statusLbl = UI.text({ FontFace = F.bodyBold, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.fromOffset(190, 404), Size = UDim2.new(1, -226, 0, 40), Parent = mainP })
	create.MouseButton1Click:Connect(function()
		ctx.audio.sfx("click")
		setStatus("creating")
		local res = Remotes.Lobby:InvokeServer("create", difficulty)
		if res.status == "ok" then Menu.refresh() elseif res.status == "teleporting" then setStatus("joining") else setStatus(res.key or "err_teleport", COL.red) end
	end)
	join.MouseButton1Click:Connect(function() ctx.audio.sfx("click") Menu.showJoin() end)
	lang.MouseButton1Click:Connect(function() ctx.toggleLang() showMain() end)
end

function Menu.showJoin()
	clear(joinP)
	mainP.Visible, joinP.Visible, lobbyP.Visible = false, true, false
	UI.text({ Text = string.upper(ctx.t("menu_join")), FontFace = F.display, TextSize = 14, TextColor3 = COL.amber, Position = UDim2.fromOffset(36, 30), Size = UDim2.fromOffset(400, 18), Parent = joinP })
	local boxF = UI.new("Frame", { BackgroundColor3 = COL.panel2, Position = UDim2.fromOffset(36, 70), Size = UDim2.new(1, -72, 0, 84), Parent = joinP }, { UI.corner(14), UI.stroke(COL.amber, 1.5, 0.4) })
	codeBox = UI.new("TextBox", { BackgroundTransparency = 1, Text = "", PlaceholderText = "000000", PlaceholderColor3 = Color3.fromRGB(80, 86, 98), ClearTextOnFocus = false,
		FontFace = F.mono, TextSize = 52, TextColor3 = COL.text, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = boxF })
	codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = codeBox.Text:gsub("%D", ""):sub(1, 6)
		if digits ~= codeBox.Text then codeBox.Text = digits end
	end)
	UI.text({ Text = ctx.t("menu_code"), FontFace = F.body, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 160), Size = UDim2.fromOffset(300, 20), Parent = joinP })
	local go = UI.button({ name = "Go", style = "primary", icon = "arrow", text = ctx.t("menu_go"), size = UDim2.new(1, -72, 0, 56), position = UDim2.fromOffset(36, 200), parent = joinP })
	local back = UI.button({ name = "Back", style = "ghost", text = ctx.t("menu_back"), size = UDim2.fromOffset(140, 40), position = UDim2.fromOffset(36, 272), parent = joinP })
	statusLbl = UI.text({ FontFace = F.bodyBold, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.fromOffset(190, 272), Size = UDim2.new(1, -226, 0, 40), Parent = joinP })
	go.MouseButton1Click:Connect(function()
		ctx.audio.sfx("click")
		setStatus("joining")
		local res = Remotes.Lobby:InvokeServer("join", codeBox.Text)
		if res.status == "ok" then Menu.refresh() elseif res.status ~= "teleporting" then setStatus(res.key or "err_code", COL.red) end
	end)
	back.MouseButton1Click:Connect(showMain)
end

local function showLobby(st)
	clear(lobbyP)
	mainP.Visible, joinP.Visible, lobbyP.Visible = false, false, true
	local lobby = st.lobby
	UI.text({ Text = string.upper(ctx.t("lobby_code")), FontFace = F.display, TextSize = 11, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 28), Size = UDim2.fromOffset(300, 14), Parent = lobbyP })
	UI.text({ Text = lobby.code:sub(1, 3) .. " " .. lobby.code:sub(4, 6), FontFace = F.mono, TextSize = 46, TextColor3 = COL.amber, Position = UDim2.fromOffset(36, 44), Size = UDim2.fromOffset(300, 54), Parent = lobbyP })
	UI.text({ Text = ctx.t("diff_" .. (lobby.difficulty or "pilot")), FontFace = F.bodyBold, TextSize = 15, TextColor3 = COL.dim, Position = UDim2.fromOffset(250, 62), Size = UDim2.fromOffset(160, 20), Parent = lobbyP })
	-- crew list
	UI.text({ Text = string.upper(ctx.t("lobby_players")), FontFace = F.display, TextSize = 11, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 110), Size = UDim2.fromOffset(300, 14), Parent = lobbyP })
	local crew = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 130), Size = UDim2.new(1, -72, 0, 40), Parent = lobbyP }, { UI.list(Enum.FillDirection.Horizontal, 8) })
	local taken = {}
	for i, mem in lobby.members do
		local cls = mem.class and Classes.byId[mem.class]
		if cls then taken[mem.class] = mem.userId end
		local chip = UI.new("Frame", { BackgroundColor3 = cls and cls.color or COL.panel2, BackgroundTransparency = cls and 0.75 or 0, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = crew }, { UI.corner(18), UI.pad(0, 14, 0, 8) })
		local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, Parent = chip }, { UI.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		UI.icon(cls and cls.icon or "info", 18, cls and cls.color or COL.dim, { LayoutOrder = 1, Parent = r })
		UI.text({ Text = mem.name .. (mem.userId == player.UserId and (" · " .. ctx.t("you")) or ""), FontFace = F.bodyBold, TextSize = 15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), LayoutOrder = 2, Parent = r })
	end
	-- class cards
	UI.text({ Text = string.upper(ctx.t("pick_class")), FontFace = F.display, TextSize = 11, TextColor3 = COL.dim, Position = UDim2.fromOffset(36, 186), Size = UDim2.fromOffset(300, 14), Parent = lobbyP })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 206), Size = UDim2.new(1, -72, 0, 250), Parent = lobbyP }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(198, 246), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local mine = player:GetAttribute("Class")
	for i, id in Classes.order do
		local cls = Classes.byId[id]
		local takenBy = taken[id]
		local isMine = mine == id
		local free = not takenBy or isMine
		local card = UI.new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = isMine and Color3.fromRGB(44, 40, 30) or COL.panel2, LayoutOrder = i, Parent = grid }, { UI.corner(16) })
		local st = UI.stroke(cls.color, isMine and 2.5 or 1.2, isMine and 0 or (free and 0.5 or 0.9))
		st.Parent = card
		local sc = UI.new("UIScale", { Parent = card })
		local ring = UI.new("Frame", { BackgroundColor3 = cls.color, BackgroundTransparency = free and 0.8 or 0.93, Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, -32, 0, 18), Parent = card }, { UI.corner(32) })
		UI.icon(cls.icon, 36, free and cls.color or COL.dim, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = ring })
		UI.text({ Text = ctx.t("role_" .. id), FontFace = F.title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = free and COL.text or COL.dim, Position = UDim2.fromOffset(8, 90), Size = UDim2.new(1, -16, 0, 26), Parent = card })
		for k, dk in cls.descKeys do
			UI.text({ Text = "· " .. ctx.t(dk), FontFace = F.body, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, Position = UDim2.fromOffset(14, 118 + (k - 1) * 24), Size = UDim2.new(1, -28, 0, 22), Parent = card })
		end
		UI.text({ Text = takenBy and not isMine and ctx.t("taken") or ctx.t(cls.perkKey), FontFace = F.bodyBold, TextSize = 13, TextColor3 = takenBy and not isMine and COL.red or cls.color, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32), Parent = card })
		if free then
			card.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.03 }):Play() end)
			card.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
			card.MouseButton1Click:Connect(function()
				ctx.audio.sfx("click")
				Remotes.Lobby:InvokeServer("pickClass", id)
			end)
		end
	end
	UI.text({ Text = ctx.t("bip_covers"), FontFace = F.body, TextSize = 14, TextColor3 = COL.dim, Position = UDim2.new(0, 36, 1, -88), Size = UDim2.new(1, -330, 0, 20), Parent = lobbyP })
	local start = UI.button({ name = "Start", style = mine and "primary" or "secondary", icon = "rocket", text = ctx.t(mine and "lobby_start" or "pick_class"), size = UDim2.fromOffset(280, 56), anchor = Vector2.new(1, 1), position = UDim2.new(1, -36, 1, -26), parent = lobbyP })
	start.MouseButton1Click:Connect(function()
		if not player:GetAttribute("Class") then return end
		ctx.audio.sfx("click")
		Remotes.Lobby:InvokeServer("start")
	end)
end

local lastSig = ""
function Menu.refresh()
	if not open then return end
	local st = ctx.state()
	local inLobby = player:GetAttribute("InLobby")
	if st and st.lobby and inLobby then
		if st.lobby.started and player:GetAttribute("Class") then Menu.close() return end
		local sig = st.lobby.code .. tostring(player:GetAttribute("Class"))
		for _, mm in st.lobby.members do sig ..= tostring(mm.userId) .. tostring(mm.class) end
		if sig ~= lastSig or not lobbyP.Visible then lastSig = sig showLobby(st) end
	end
end

function Menu.open()
	open = true
	ctx.setHudHidden(true)
	root.Enabled = true
	orbitCamera(true)
	ctx.audio.music("hub")
	showMain()
	Menu.refresh()
end

function Menu.close()
	if not open then return end
	open = false
	root.Enabled = false
	orbitCamera(false)
	cam.CameraType = Enum.CameraType.Custom
	ctx.setHudHidden(false)
	ctx.onMenuClosed()
end

function Menu.isOpen() return open end

function Menu.init(c)
	ctx = c
	UI, COL, F = ctx.UI, ctx.COL, ctx.F
	difficulty = "cadet"
	root = UI.new("ScreenGui", { Name = "NovaMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, Enabled = true, Parent = player.PlayerGui })
	local s = UI.new("UIScale", { Parent = root })
	local function rescale() local vp = cam.ViewportSize s.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.72, 1.25) end
	rescale()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root }, {
		UI.new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.55, 0.75), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	mainP = UI.panel({ Position = UDim2.fromOffset(48, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(440, 470), Parent = root }, 22)
	mainP.Position = UDim2.new(0, 48, 0.5, 0)
	joinP = UI.panel({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 48, 0.5, 0), Size = UDim2.fromOffset(440, 330), Visible = false, Parent = root }, 22)
	lobbyP = UI.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(920, 560), Visible = false, Parent = root }, 22)
	lobbyP.BackgroundColor3 = COL.bg
	root.Enabled = false
	player:GetAttributeChangedSignal("InLobby"):Connect(Menu.refresh)
	player:GetAttributeChangedSignal("Class"):Connect(function() lastSig = "" Menu.refresh() end)
end

return Menu
