-- NovaUI: the one visual system (SpaceX / NASA style) used by every client screen.
-- Black panels, white type, ONE red accent (COL.accent), 1 px hairlines, 2-4 px corners, condensed tracked caps
-- for labels, a clean grotesk for reading, mono for numbers, 8 px grid. No glows, no gradients, no bouncy motion.
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Nova.Shared.Config)
local COL, F = Config.Colors, Config.Fonts

local UI = {}
UI.COL, UI.F = COL, F
UI.GRID = 8

------------------------------------------------------------------ instances
-- corners: callers may still ask for big radii; they are clamped to 2-4 px, except a square element whose
-- radius is half its side (a dot / knob), which stays a circle.
local wantR = setmetatable({}, { __mode = "k" })
local function fitCorner(c, o)
	local r = wantR[c]
	if not r then return end
	wantR[c] = nil
	local s = o.Size
	if s.X.Scale == 0 and s.Y.Scale == 0 and s.X.Offset > 0 and s.X.Offset == s.Y.Offset and r * 2 >= s.X.Offset - 1 then
		c.CornerRadius = UDim.new(0.5, 0)
	end
end

function UI.new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	if children then
		for _, c in children do
			c.Parent = o
			if wantR[c] then fitCorner(c, o) end
		end
	end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local new = UI.new

local function radius(r)
	if r >= 14 then return 4 elseif r >= 8 then return 3 end
	return math.clamp(r, 0, 2)
end
function UI.corner(r, parent)
	r = r or 4
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius(r))
	wantR[c] = r
	if parent then c.Parent = parent fitCorner(c, parent) end
	return c
end
-- strokes are always 1 px unless a caller explicitly keeps its thickness (game pieces, world screens)
function UI.stroke(c, th, tr, keep)
	return new("UIStroke", { Color = c or COL.line, Thickness = keep and (th or 1) or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
function UI.pad(t, r, b, l) return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t), PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t) }) end
function UI.list(dir, gap, halign, valign)
	return new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left, VerticalAlignment = valign or Enum.VerticalAlignment.Top })
end

------------------------------------------------------------------ type
-- string.upper only knows ASCII: this one also handles Cyrillic (а-я, ё)
function UI.upper(s)
	s = tostring(s or "")
	local out = {}
	local ok = pcall(function()
		for _, c in utf8.codes(s) do
			if c >= 0x430 and c <= 0x44F then c -= 0x20 elseif c == 0x451 then c = 0x401 elseif c >= 97 and c <= 122 then c -= 32 end
			out[#out + 1] = utf8.char(c)
		end
	end)
	return ok and table.concat(out) or string.upper(s)
end
-- tracked caps for labels: uppercase + a hair space between letters (Roblox has no letter-spacing property)
local HAIR = utf8.char(0x200A)
local capsCache, capsN = {}, 0
function UI.caps(s)
	s = tostring(s or "")
	local hit = capsCache[s]
	if hit then return hit end
	local up = UI.upper(s)
	local parts = {}
	local ok = pcall(function() for _, c in utf8.codes(up) do parts[#parts + 1] = utf8.char(c) end end)
	local res = ok and table.concat(parts, HAIR) or up
	capsN += 1
	if capsN > 600 then capsCache, capsN = {}, 0 end
	capsCache[s] = res
	return res
end

-- text with explicit font face; size in px (the ScreenGui UIScale does the scaling)
function UI.text(props)
	local d = { BackgroundTransparency = 1, FontFace = F.body, TextColor3 = COL.text, TextSize = 16, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
	for k, v in props do d[k] = v end
	return new("TextLabel", d)
end
-- small tracked caps label (kickers, section titles, units); props.Text is raw text
function UI.label(props)
	local d = { BackgroundTransparency = 1, FontFace = F.display, TextColor3 = COL.dim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
	for k, v in props do d[k] = v end
	d.Text = UI.caps(props.Text or "")
	return new("TextLabel", d)
end
-- 1 px hairline
function UI.rule(props)
	local d = { BackgroundColor3 = COL.line, BackgroundTransparency = COL.lineT, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }
	for k, v in props do d[k] = v end
	return new("Frame", d)
end

------------------------------------------------------------------ icons
function UI.icon(name, size, color, props)
	local d = { BackgroundTransparency = 1, Image = Config.IconSheet.image, ImageRectSize = Vector2.new(128, 128), ImageRectOffset = Config.iconRect(name),
		Size = UDim2.fromOffset(size, size), ImageColor3 = color or COL.text, ScaleType = Enum.ScaleType.Fit }
	if props then for k, v in props do d[k] = v end end
	return new("ImageLabel", d)
end
function UI.setIcon(img, name) img.ImageRectOffset = Config.iconRect(name) end

------------------------------------------------------------------ surfaces
-- panel: black, slightly translucent, 1 px hairline, 4 px corners
function UI.panel(props, _radius)
	local d = { BackgroundColor3 = COL.panel, BackgroundTransparency = COL.panelT, BorderSizePixel = 0 }
	for k, v in props do d[k] = v end
	local f = new("Frame", d)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = f
	UI.stroke(COL.line, 1, COL.lineT).Parent = f
	return f
end
-- flat design: no drop shadows (kept so old callers do not break)
function UI.shadow() end

------------------------------------------------------------------ buttons
local QUICK = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STYLE = {
	primary = { bg = COL.text, bgT = 0, fg = COL.dark, st = COL.text, stT = 1, hbg = Color3.fromRGB(255, 255, 255), hbgT = 0, hstT = 1 },
	accent = { bg = COL.accent, bgT = 0, fg = Color3.fromRGB(255, 255, 255), st = COL.accent, stT = 1, hbg = Color3.fromRGB(240, 82, 70), hbgT = 0, hstT = 1 },
	secondary = { bg = COL.panel, bgT = 0.08, fg = COL.text, st = COL.line, stT = 0.6, hbg = Color3.fromRGB(40, 41, 45), hbgT = 0.05, hstT = 0 },
	ghost = { bg = COL.panel, bgT = 1, fg = COL.dim, st = COL.line, stT = 1, hbg = COL.panel, hbgT = 0.6, hstT = 0.6, hfg = COL.text },
}
UI.BUTTON = STYLE
-- button: icon + tracked caps label. style = "primary" (white) | "accent" (red, rare) | "secondary" (outline) | "ghost"
function UI.button(props)
	local s = STYLE[props.style or "primary"] or STYLE.primary
	local z = props.z or 1
	local b = new("TextButton", { Name = props.name or "Button", AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		BackgroundColor3 = s.bg, BackgroundTransparency = s.bgT,
		Size = props.size or UDim2.fromOffset(240, 48), Position = props.position or UDim2.new(), AnchorPoint = props.anchor or Vector2.zero,
		LayoutOrder = props.order or 0, ZIndex = z, Parent = props.parent })
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius(props.radius or 4))
	c.Parent = b
	local st = UI.stroke(s.st, 1, s.stT)
	st.Parent = b
	local scale = new("UIScale", { Parent = b })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = b }, {
		UI.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local ic
	if props.icon then ic = UI.icon(props.icon, props.iconSize or 16, s.fg, { LayoutOrder = 1, ZIndex = z + 2, Parent = row }) end
	local lbl
	if props.text and props.text ~= "" then
		lbl = UI.text({ Text = props.raw and props.text or UI.caps(props.text), FontFace = props.font or F.display, TextSize = props.textSize or 15, TextColor3 = s.fg,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, ZIndex = z + 2, Parent = row })
	end
	local function paint(h)
		TweenService:Create(b, QUICK, { BackgroundColor3 = h and s.hbg or s.bg, BackgroundTransparency = h and s.hbgT or s.bgT }):Play()
		st.Transparency = h and s.hstT or s.stT
		if s.hfg then
			if lbl then lbl.TextColor3 = h and s.hfg or s.fg end
			if ic then ic.ImageColor3 = h and s.hfg or s.fg end
		end
	end
	b.MouseEnter:Connect(function() paint(true) end)
	b.MouseLeave:Connect(function() paint(false) scale.Scale = 1 end)
	b.MouseButton1Down:Connect(function() scale.Scale = 0.98 end)
	b.MouseButton1Up:Connect(function() scale.Scale = 1 end)
	return b, lbl, ic
end

-- square icon button for the HUD bar (40 x 40): black, hairline, white icon, optional hotkey hint
function UI.iconButton(p)
	local z = p.z or 1
	local b = new("TextButton", { Name = p.name or "IconButton", Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		BackgroundColor3 = COL.panel, BackgroundTransparency = COL.panelT, Size = p.size or UDim2.fromOffset(40, 40),
		Position = p.position or UDim2.new(), AnchorPoint = p.anchor or Vector2.zero, LayoutOrder = p.order or 0, ZIndex = z, Parent = p.parent })
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	local st = UI.stroke(COL.line, 1, COL.lineT)
	st.Parent = b
	local ic
	if p.icon then
		ic = UI.icon(p.icon, p.iconSize or 18, p.color or COL.text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z + 1, Parent = b })
	elseif p.glyph then
		ic = UI.text({ Text = p.glyph, FontFace = F.body, TextSize = p.glyphSize or 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = b })
	end
	if p.key then
		UI.text({ Name = "Key", Text = p.key, FontFace = F.mono, TextSize = 9, TextColor3 = COL.mute, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Bottom,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -2), Size = UDim2.fromOffset(12, 10), ZIndex = z + 1, Parent = b })
	end
	b.MouseEnter:Connect(function() st.Transparency = 0.35 end)
	b.MouseLeave:Connect(function() st.Transparency = COL.lineT end)
	return b, ic, st
end

-- selectable chip / tab (on = white fill + black text, off = hairline outline)
function UI.setOn(btn, lbl, on)
	btn.BackgroundColor3 = on and COL.text or COL.panel
	btn.BackgroundTransparency = on and 0 or 0.08
	local st = btn:FindFirstChildOfClass("UIStroke")
	if st then st.Transparency = on and 1 or 0.6 end
	if lbl then lbl.TextColor3 = on and COL.dark or COL.text end
end
function UI.chipButton(p)
	local b = new("TextButton", { Name = p.name or "Chip", Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = COL.panel, BackgroundTransparency = 0.08,
		Size = p.size or UDim2.fromOffset(112, 36), Position = p.position or UDim2.new(), AnchorPoint = p.anchor or Vector2.zero, LayoutOrder = p.order or 0, ZIndex = p.z or 1, Parent = p.parent })
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = b
	UI.stroke(COL.line, 1, 0.6).Parent = b
	local l = UI.text({ Text = UI.caps(p.text or ""), FontFace = F.display, TextSize = p.textSize or 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = (p.z or 1) + 1, Parent = b })
	UI.setOn(b, l, p.on == true)
	return b, l
end

------------------------------------------------------------------ motion
-- quick, precise appear (no overshoot); cancels a running one so tweens never pile up
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local popping = setmetatable({}, { __mode = "k" })
function UI.pop(obj, from)
	local s = obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = obj })
	local prev = popping[obj]
	if prev then prev:Cancel() end
	s.Scale = math.max(from or 0.97, 0.96)
	local tw = TweenService:Create(s, POP, { Scale = 1 })
	popping[obj] = tw
	tw:Play()
end

-- one UIScale per ScreenGui: the layout is designed on a base canvas (default 1280 x 720)
function UI.autoScale(screenGui, baseW, baseH, lo, hi, onChange)
	local cam = workspace.CurrentCamera
	local s = new("UIScale", { Parent = screenGui })
	local function apply()
		local vp = cam.ViewportSize
		s.Scale = math.clamp(math.min(vp.X / (baseW or 1280), vp.Y / (baseH or 720)), lo or 0.6, hi or 1.5)
		if onChange then onChange(s.Scale, vp) end
	end
	apply()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	return s, apply
end

return UI
