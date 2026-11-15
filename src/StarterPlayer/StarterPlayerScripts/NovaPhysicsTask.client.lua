-- NovaPhysicsTask: interactive physics check at the launch area ("Thrust check").
-- Players build the weight formula W = m x g from buttons, compute the rocket's weight,
-- then compare it with engine thrust to give the GO. Bilingual (RU first, EN below). Client-only UI;
-- the server script NovaPhysicsTaskServer rewards the first completion per player.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local Citadel = workspace:WaitForChild("Citadel")
local folder = Citadel:WaitForChild("PhysicsTask", 60)
if not folder then return end
local screenPart = folder:WaitForChild("Screen", 30)
local promptPart = folder:WaitForChild("PromptAnchor", 30)
if not (screenPart and promptPart) then return end
local doneEvent = RS:WaitForChild("NovaPhysicsTaskDone", 30)

local FX
pcall(function() FX = require(RS:WaitForChild("NovaFX", 5)) end)

------------------------------------------------------------------ style (SpaceX / NASA: black, white, one red accent)
local BLACK = Color3.fromRGB(8, 9, 11)
local PANEL = Color3.fromRGB(16, 17, 20)
local LINE = Color3.fromRGB(70, 72, 78)
local WHITE = Color3.fromRGB(240, 241, 243)
local DIM = Color3.fromRGB(150, 153, 160)
local RED = Color3.fromRGB(224, 60, 49)
local GREEN = Color3.fromRGB(80, 200, 120)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local FONT_B = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local FONT_L = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Light)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	for _, c in children or {} do c.Parent = o end
	return o
end
local function stroke(color, t) return new("UIStroke", { Color = color or LINE, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 3) }) end
local function text(props)
	local t = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = WHITE, FontFace = FONT, TextSize = 18, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 24) })
	for k, v in props do t[k] = v end
	return t
end

------------------------------------------------------------------ texts (RU / EN)
local T = {
	title = { "ПРОВЕРКА ТЯГИ", "THRUST CHECK" },
	step = { "ШАГ %d / 3", "STEP %d / 3" },
	s1 = { "Ракета взлетит, только если двигатели толкают вверх сильнее, чем планета тянет её вниз. Сначала найдём вес ракеты. Собери формулу веса из кнопок.",
		"The rocket lifts off only if the engines push up harder than the planet pulls it down. First find the rocket's weight. Build the weight formula from the buttons." },
	s2 = { "Масса ракеты m = 50 000 кг. На Земле g = 9,8 Н на каждый килограмм. Сколько весит ракета?",
		"Rocket mass m = 50,000 kg. On Earth g = 9.8 N for every kilogram. How much does the rocket weigh?" },
	s3 = { "Двигатели дают тягу F = 600 000 Н. Вес ракеты W = 490 000 Н. Можно давать команду на старт?",
		"The engines give thrust F = 600,000 N. Rocket weight W = 490,000 N. Can we give the GO for launch?" },
	hint = { "ПОДСКАЗКА", "HINT" },
	h1 = { "Вес — это сила, с которой планета тянет ракету вниз. Чем больше масса m, тем больше вес: удвоишь массу — удвоится и вес. Каждый килограмм на Земле тянет вниз с силой g = 9,8 Н, на Луне всего 1,6 Н. Какое действие связывает массу и g так, чтобы вес рос вместе с массой?",
		"Weight is the force with which the planet pulls the rocket down. More mass m means more weight: double the mass and the weight doubles too. On Earth each kilogram is pulled with g = 9.8 N, on the Moon only 1.6 N. Which operation links mass and g so that weight grows together with mass?" },
	h2 = { "Используй свою формулу: W = m × g. Подставь числа: 50 000 × 9,8. Подсказка: 50 000 × 10 = 500 000, значит ответ чуть меньше.",
		"Use your formula: W = m × g. Plug in the numbers: 50,000 × 9.8. Tip: 50,000 × 10 = 500,000, so the answer is a bit less." },
	h3 = { "Сравни две силы. Если сила вверх (тяга F) больше силы вниз (вес W), ракета поднимается.",
		"Compare the two forces. If the upward force (thrust F) is bigger than the downward force (weight W), the rocket rises." },
	clear = { "СТЕРЕТЬ", "CLEAR" },
	check = { "ПРОВЕРИТЬ", "CHECK" },
	close = { "ЗАКРЫТЬ", "CLOSE" },
	ok1 = { "Верно! Вес W = m × g — масса, умноженная на ускорение свободного падения.", "Correct! Weight W = m × g: mass times gravitational acceleration." },
	ok2 = { "Верно! 50 000 × 9,8 = 490 000 Н.", "Correct! 50,000 × 9.8 = 490,000 N." },
	go = { "GO ДЛЯ СТАРТА! Тяга 600 000 Н больше веса 490 000 Н — ракета взлетит.", "GO FOR LAUNCH! Thrust 600,000 N is greater than weight 490,000 N — the rocket will lift off." },
	bad_vt = { "Скорость и время не меняют вес, пока ракета стоит на площадке. Вес зависит от массы и от планеты.", "Speed and time don't change the weight while the rocket stands on the pad. Weight depends on mass and on the planet." },
	bad_op = { "Почти! Проверь действие: если массу удвоить, вес тоже должен удвоиться. Сложение или деление так не делают.", "Almost! Check the operation: if the mass doubles, the weight must double too. Adding or dividing doesn't do that." },
	bad_short = { "Формуле нужны три части: величина, действие, величина.", "The formula needs three parts: quantity, operation, quantity." },
	bad2 = { "Не то. Нужно умножить массу на g, а не сложить или разделить.", "Not quite. Multiply the mass by g — don't add or divide." },
	bad3 = { "Посмотри ещё раз: 600 000 больше, чем 490 000. Сила вверх побеждает.", "Look again: 600,000 is more than 490,000. The upward force wins." },
	yes = { "ДА, ТЯГА БОЛЬШЕ ВЕСА", "YES, THRUST > WEIGHT" },
	no = { "НЕТ, РАКЕТА СЛИШКОМ ТЯЖЁЛАЯ", "NO, THE ROCKET IS TOO HEAVY" },
	prompt = { "Расчёт тяги", "Thrust check" },
	reward = { "Задание выполнено: +%d кредитов", "Task complete: +%d credits" },
	m = { "масса", "mass" }, g = { "притяжение", "gravity" }, v = { "скорость", "speed" }, t = { "время", "time" },
}
local function ru(k) return T[k][1] end
local function en(k) return T[k][2] end

------------------------------------------------------------------ GUI
local gui = new("ScreenGui", { Name = "NovaPhysicsTask", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = gui })
local win = new("Frame", { BackgroundColor3 = BLACK, Size = UDim2.fromOffset(720, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui }, { stroke(LINE), corner(3) })
new("UIScale", { Name = "Scale", Parent = win })
new("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(0, 48, 0, 2), Position = UDim2.fromOffset(32, 30), Parent = win })
local title = text({ Text = ru("title") .. "   /   " .. en("title"), FontFace = FONT_B, TextSize = 15, Position = UDim2.fromOffset(32, 42), Size = UDim2.new(1, -200, 0, 20), Parent = win })
local stepLbl = text({ Text = "", FontFace = FONT_L, TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -232, 0, 44), Size = UDim2.fromOffset(200, 18), Parent = win })
new("Frame", { BackgroundColor3 = LINE, BorderSizePixel = 0, Size = UDim2.new(1, -64, 0, 1), Position = UDim2.fromOffset(32, 74), Parent = win })
local qRu = text({ TextSize = 19, Position = UDim2.fromOffset(32, 90), Size = UDim2.new(1, -64, 0, 76), Parent = win })
local qEn = text({ TextSize = 13, FontFace = FONT_L, TextColor3 = DIM, Position = UDim2.fromOffset(32, 168), Size = UDim2.new(1, -64, 0, 40), Parent = win })
local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 216), Size = UDim2.new(1, -64, 0, 230), Parent = win })
local feedback = text({ TextSize = 15, Position = UDim2.fromOffset(32, 452), Size = UDim2.new(1, -64, 0, 44), Text = "", Parent = win })
local hintBox = new("Frame", { BackgroundColor3 = PANEL, Visible = false, Position = UDim2.fromOffset(32, 216), Size = UDim2.new(1, -64, 0, 230), ZIndex = 5, Parent = win }, { stroke(LINE), corner(3) })
local hintRu = text({ TextSize = 16, Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 110), ZIndex = 6, Parent = hintBox })
local hintEn = text({ TextSize = 12, FontFace = FONT_L, TextColor3 = DIM, Position = UDim2.fromOffset(18, 152), Size = UDim2.new(1, -36, 0, 70), ZIndex = 6, Parent = hintBox })
text({ Text = ru("hint") .. "  /  " .. en("hint"), FontFace = FONT_B, TextSize = 12, TextColor3 = RED, Position = UDim2.fromOffset(18, 14), ZIndex = 6, Parent = hintBox })

local function button(parentFrame, label, sub, size, pos, style)
	local b = new("TextButton", { AutoButtonColor = true, BackgroundColor3 = (style == "primary") and WHITE or PANEL, Text = "", Size = size, Position = pos, Parent = parentFrame }, { stroke(style == "primary" and WHITE or LINE), corner(3) })
	text({ Text = label, FontFace = (style == "symbol") and MONO or FONT_B, TextSize = (style == "symbol") and 26 or 14, TextColor3 = (style == "primary") and BLACK or WHITE,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.new(1, 0, sub and 0.66 or 1, 0), Parent = b })
	if sub then text({ Text = sub, FontFace = FONT_L, TextSize = 11, TextColor3 = (style == "primary") and Color3.fromRGB(60, 62, 68) or DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.35, 0), Parent = b }) end
	return b
end
local closeBtn = button(win, ru("close") .. " / " .. en("close"), nil, UDim2.fromOffset(170, 36), UDim2.new(1, -202, 1, -52), nil)
local hintBtn = button(win, ru("hint") .. " / " .. en("hint"), nil, UDim2.fromOffset(190, 36), UDim2.new(0, 32, 1, -52), nil)
gui.Parent = player:WaitForChild("PlayerGui")

local function say(sRu, sEn, color)
	feedback.Text = sRu .. "\n" .. sEn
	feedback.TextColor3 = color or WHITE
end
local function clearBody() for _, c in body:GetChildren() do c:Destroy() end feedback.Text = "" hintBox.Visible = false end

local step, completed = 1, false
local renderStep

------------------------------------------------------------------ step 1: build W = m x g
local function step1()
	stepLbl.Text = string.format(ru("step"), 1) .. "  ·  " .. string.format(en("step"), 1)
	qRu.Text, qEn.Text = ru("s1"), en("s1")
	clearBody()
	text({ Text = "W  =", FontFace = MONO, TextSize = 34, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(110, 50), TextYAlignment = Enum.TextYAlignment.Center, Parent = body })
	local slots, values = {}, {}
	for i = 1, 3 do
		slots[i] = new("Frame", { BackgroundColor3 = PANEL, Size = UDim2.fromOffset(84, 56), Position = UDim2.fromOffset(110 + (i - 1) * 96, 4), Parent = body }, { stroke(LINE), corner(3) })
		text({ Name = "V", Text = "", FontFace = MONO, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = slots[i] })
	end
	local function refresh()
		for i = 1, 3 do slots[i].V.Text = values[i] or "" ; slots[i]:FindFirstChildOfClass("UIStroke").Color = values[i] and WHITE or LINE end
	end
	local keys = {
		{ "m", ru("m") .. " · " .. en("m") }, { "g", ru("g") .. " · " .. en("g") }, { "v", ru("v") .. " · " .. en("v") }, { "t", ru("t") .. " · " .. en("t") },
		{ "×" }, { "÷" }, { "+" }, { "−" },
	}
	for i, k in keys do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		local b = button(body, k[1], k[2], UDim2.fromOffset(150, 52), UDim2.fromOffset(col * 162, 72 + row * 58), "symbol")
		b.Activated:Connect(function()
			if #values < 3 then table.insert(values, k[1]); refresh() end
		end)
	end
	local clr = button(body, ru("clear"), en("clear"), UDim2.fromOffset(150, 44), UDim2.fromOffset(0, 188), nil)
	clr.Activated:Connect(function() values = {}; refresh(); feedback.Text = "" end)
	local chk = button(body, ru("check"), en("check"), UDim2.fromOffset(150, 44), UDim2.fromOffset(486, 188), "primary")
	chk.Activated:Connect(function()
		if #values < 3 then say(ru("bad_short"), en("bad_short"), RED) return end
		local a, op, b = values[1], values[2], values[3]
		local quantities = { m = true, g = true, v = true, t = true }
		if not (quantities[a] and quantities[b]) or quantities[op] then say(ru("bad_short"), en("bad_short"), RED) return end
		if a == "v" or a == "t" or b == "v" or b == "t" then say(ru("bad_vt"), en("bad_vt"), RED) return end
		if op ~= "×" then say(ru("bad_op"), en("bad_op"), RED) return end
		if (a == "m" and b == "g") or (a == "g" and b == "m") then
			say(ru("ok1"), en("ok1"), GREEN)
			task.delay(1.6, function() if gui.Enabled and step == 1 then step = 2; renderStep() end end)
		else
			say(ru("bad_op"), en("bad_op"), RED)
		end
	end)
	hintRu.Text, hintEn.Text = ru("h1"), en("h1")
end

------------------------------------------------------------------ step 2: compute the weight
local function step2()
	stepLbl.Text = string.format(ru("step"), 2) .. "  ·  " .. string.format(en("step"), 2)
	qRu.Text, qEn.Text = ru("s2"), en("s2")
	clearBody()
	text({ Text = "W = m × g = 50 000 кг × 9,8 Н/кг = ?", FontFace = MONO, TextSize = 22, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 34), Parent = body })
	local options = { { "50 009,8 Н", false }, { "490 000 Н", true }, { "5 102 Н", false } }
	for i, o in options do
		local b = button(body, o[1], nil, UDim2.fromOffset(200, 64), UDim2.fromOffset((i - 1) * 216, 70), "symbol")
		b.Activated:Connect(function()
			if o[2] then
				say(ru("ok2"), en("ok2"), GREEN)
				task.delay(1.4, function() if gui.Enabled and step == 2 then step = 3; renderStep() end end)
			else say(ru("bad2"), en("bad2"), RED) end
		end)
	end
	hintRu.Text, hintEn.Text = ru("h2"), en("h2")
end

------------------------------------------------------------------ step 3: GO / NO-GO
local function lightTerminal(ok)
	local sg = screenPart:FindFirstChildOfClass("SurfaceGui")
	local lbl = sg and sg:FindFirstChild("Status", true)
	if lbl then lbl.Text = ok and "GO  ·  F > W" or "W = m × g ?"; lbl.TextColor3 = ok and GREEN or WHITE end
	local lamp = folder:FindFirstChild("Lamp")
	if lamp then lamp.Color = ok and GREEN or RED end
end
local function step3()
	stepLbl.Text = string.format(ru("step"), 3) .. "  ·  " .. string.format(en("step"), 3)
	qRu.Text, qEn.Text = ru("s3"), en("s3")
	clearBody()
	text({ Text = "F = 600 000 Н   ?   W = 490 000 Н", FontFace = MONO, TextSize = 22, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 34), Parent = body })
	local yes = button(body, ru("yes"), en("yes"), UDim2.fromOffset(318, 70), UDim2.fromOffset(0, 70), nil)
	local no = button(body, ru("no"), en("no"), UDim2.fromOffset(318, 70), UDim2.fromOffset(338, 70), nil)
	yes.Activated:Connect(function()
		say(ru("go"), en("go"), GREEN)
		lightTerminal(true)
		if not completed then
			completed = true
			if doneEvent then doneEvent:FireServer("thrust_check") end
			if FX then
				local pad = Citadel:FindFirstChild("Hangar") and Citadel.Hangar:FindFirstChild("LaunchArea") and Citadel.Hangar.LaunchArea:FindFirstChild("PadA")
				local plinth = pad and pad:FindFirstChild("Plinth")
				if plinth and FX.ring then pcall(FX.ring, plinth.Position + Vector3.new(0, 1, 0), GREEN, 18, 1.2) end
			end
		end
	end)
	no.Activated:Connect(function() say(ru("bad3"), en("bad3"), RED) end)
	hintRu.Text, hintEn.Text = ru("h3"), en("h3")
end

renderStep = function()
	if step == 1 then step1() elseif step == 2 then step2() else step3() end
end

hintBtn.Activated:Connect(function() hintBox.Visible = not hintBox.Visible end)
closeBtn.Activated:Connect(function() gui.Enabled = false end)

local function open()
	if completed then step = 3 end
	renderStep()
	gui.Enabled = true
	local target = math.min(1, (workspace.CurrentCamera.ViewportSize.Y - 40) / 560, (workspace.CurrentCamera.ViewportSize.X - 24) / 720)
	win.Scale.Scale = target * 0.96
	TweenService:Create(win.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Scale = target }):Play()
end

-- world prompt on the terminal (client-side, like the shop prompt)
local pr = Instance.new("ProximityPrompt")
pr.ActionText = ru("prompt") .. " / " .. en("prompt")
pr.ObjectText = "W = m × g"
pr.MaxActivationDistance = 10
pr.RequiresLineOfSight = false
pr.HoldDuration = 0
pr.Parent = promptPart
pr.Triggered:Connect(open)

if doneEvent then
	doneEvent.OnClientEvent:Connect(function(kind, amount)
		if kind == "reward" and amount and amount > 0 then
			say(string.format(ru("reward"), amount), string.format(en("reward"), amount), GREEN)
		end
	end)
end
