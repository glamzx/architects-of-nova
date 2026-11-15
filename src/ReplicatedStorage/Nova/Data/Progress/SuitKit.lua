-- SuitKit: builds the Nova spacesuit look on an R15 character. Shared by ProgressService (real avatars, replicated)
-- and NovaClient.Outfitter (cloned avatar in a ViewportFrame, try-on before buying). Every size comes from the
-- avatar's own part sizes, so the suit fits any R15 body and head.
local Progress = require(script.Parent)

local K = {}
K.SLOTS = { "suit", "helmet", "visor", "patch" }
K.DEFAULT = { suit = "suit_white", helmet = "helmet_bubble", visor = "visor_std", patch = "patch_blue" }

local byId = {}
for _, it in Progress.outfit do byId[it.id] = it end
K.byId = byId
function K.item(id) return id and byId[id] or nil end

-- equip table (profile.equip) -> one item per slot, falling back to the free default
function K.resolve(equip)
	local look = {}
	for slot, def in K.DEFAULT do
		local it = equip and byId[equip[slot] or ""]
		if not it or it.slot ~= slot then it = byId[def] end
		look[slot] = it
	end
	return look
end

------------------------------------------------------------------ helpers
local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end
local function piece(parent, size, cf, color, mat, shape, tr)
	local p = Instance.new("Part")
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Transparency = tr or 0
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- ellipsoid (non-uniform sphere) via SpecialMesh
local function ellip(parent, size, cf, color, mat, tr, refl)
	local p = piece(parent, size, cf, color, mat, nil, tr)
	p.Reflectance = refl or 0
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
K.lum = lum

------------------------------------------------------------------ accessories
-- EVA hides hats/back items (keeps hair + face); hard helmets also hide hair and hats on the head.
local KEEP_EVA = { [Enum.AccessoryType.Hair] = true, [Enum.AccessoryType.Face] = true, [Enum.AccessoryType.Eyebrow] = true, [Enum.AccessoryType.Eyelash] = true }
local KEEP_HELMET = { [Enum.AccessoryType.Face] = true, [Enum.AccessoryType.Eyebrow] = true, [Enum.AccessoryType.Eyelash] = true }
local HEAD_ATT = { HatAttachment = true, HairAttachment = true, FaceFrontAttachment = true, FaceCenterAttachment = true }
function K.hideAccessories(char, hideBody, hideHead)
	local head = char:FindFirstChild("Head")
	for _, a in char:GetChildren() do
		if a:IsA("Accessory") then
			local h = a:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				local okT, at = pcall(function() return a.AccessoryType end)
				if not okT then at = nil end
				local onHead = false
				local w = h:FindFirstChild("AccessoryWeld")
				if w and w:IsA("JointInstance") and head and (w.Part0 == head or w.Part1 == head) then onHead = true end
				local att = h:FindFirstChildOfClass("Attachment")
				if att and HEAD_ATT[att.Name] then onHead = true end
				local hide = (hideBody and not (at and KEEP_EVA[at])) or (hideHead and onHead and not (at and KEEP_HELMET[at]))
				local saved = h:GetAttribute("SuitT")
				if hide then
					if saved == nil then h:SetAttribute("SuitT", h.Transparency) end
					h.Transparency = 1
				elseif saved ~= nil then
					h.Transparency = saved
					h:SetAttribute("SuitT", nil)
				end
			end
		end
	end
end

------------------------------------------------------------------ helmet
-- f: folder, head: BasePart to fit and weld to, look: resolved items, opts.lights: real lamps (server, in space)
function K.helmet(f, head, look, opts)
	opts = opts or {}
	local hs = head.Size
	local u = math.clamp(math.max(hs.X, hs.Y, hs.Z) / 1.18, 0.7, 2.4)
	local hc = head.CFrame
	local H = look.helmet
	local style = H.style or "bubble"
	local v = look.visor
	local vis = H.visor
	if v and v.id ~= "visor_std" then vis = { color = v.color, tr = v.tr or 0.3, refl = v.refl or 0.2 } end
	local white = Color3.fromRGB(236, 237, 233)
	local metal = Color3.fromRGB(196, 198, 204)
	local dark = Color3.fromRGB(38, 40, 46)
	local function W(p) weld(head, p) return p end
	local function at(x, y, z) return hc * CFrame.new(x * u, y * u, z * u) end

	-- neck ring (every style)
	local ring = W(piece(f, Vector3.new(0.26 * u, 1.92 * u, 1.56 * u), at(0, -0.8, 0.06) * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal))
	local rm = Instance.new("SpecialMesh")
	rm.MeshType = Enum.MeshType.Cylinder
	rm.Parent = ring


	if style == "bubble" then
		-- clear glass bubble: the whole face stays visible
		local tr = (v and v.id ~= "visor_std") and 0.6 or vis.tr
		W(ellip(f, Vector3.new(2.15, 2.15, 2.15) * u, at(0, 0.02, 0), vis.color, Enum.Material.Glass, tr, vis.refl))
		return
	end

	if style == "eva" or style == "pro" then
		-- EMU-style hard shell over the bubble, gold (or tinted) sun visor bulging out at the front
		local shellC = at(0, 0.08, 0.3)
		W(ellip(f, Vector3.new(2.3, 2.36, 2.42) * u, shellC, white, Enum.Material.SmoothPlastic))
		W(ellip(f, Vector3.new(1.72, 1.5, 1.66) * u, at(0, 0.04, -0.42), vis.color, Enum.Material.Glass, vis.tr, vis.refl))
		-- centre ridge and visor hinges
		W(ellip(f, Vector3.new(0.22, 2.4, 2.46) * u, shellC, metal, Enum.Material.SmoothPlastic))
		for _, sx in { -1, 1 } do
			W(piece(f, Vector3.new(0.14 * u, 0.56 * u, 0.56 * u), at(sx * 1.1, 0.06, 0.12), metal, Enum.Material.Metal, Enum.PartType.Cylinder))
			W(piece(f, Vector3.new(0.16 * u, 0.3 * u, 0.3 * u), at(sx * 1.13, 0.06, 0.12), dark, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
		end
		if style == "pro" then
			-- headlamps on both sides + helmet camera on the right + short antenna with the red tip
			for _, sx in { -1, 1 } do
				local tilt = CFrame.Angles(0, 0, math.rad(-sx * 24))
				local base = at(sx * 0.96, 0.66, -0.16) * tilt
				W(piece(f, Vector3.new(0.34, 0.3, 0.62) * u, base, Color3.fromRGB(70, 74, 82), Enum.Material.Metal))
				local lens = W(piece(f, Vector3.new(0.24 * u, 0.24 * u, 0.06 * u), base * CFrame.new(0, 0, -0.32 * u), Color3.fromRGB(255, 244, 220), opts.lights and Enum.Material.Neon or Enum.Material.Glass, nil, opts.lights and 0 or 0.1))
				if opts.lights then
					local sl = Instance.new("SpotLight")
					sl.Face = Enum.NormalId.Front
					sl.Brightness = 2
					sl.Range = 26
					sl.Angle = 50
					sl.Color = Color3.fromRGB(255, 244, 226)
					sl.Shadows = false
					sl.Parent = lens
				end
			end
			local cam = at(1.12, 0.22, -0.34)
			W(piece(f, Vector3.new(0.26, 0.24, 0.36) * u, cam, Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic))
			W(piece(f, Vector3.new(0.06 * u, 0.16 * u, 0.16 * u), cam * CFrame.new(0, 0, -0.2 * u) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(16, 18, 24), Enum.Material.Glass, Enum.PartType.Cylinder, 0.05))
			local ant = at(-0.62, 1.12, 0.62) * CFrame.Angles(math.rad(-14), 0, math.rad(10))
			W(piece(f, Vector3.new(0.05, 0.62, 0.05) * u, ant * CFrame.new(0, 0.31 * u, 0), metal, Enum.Material.Metal))
			W(ellip(f, Vector3.new(0.11, 0.11, 0.11) * u, ant * CFrame.new(0, 0.64 * u, 0), Color3.fromRGB(224, 60, 49), Enum.Material.SmoothPlastic))
		end
		return
	end

	if style == "sport" then
		-- light flight helmet: rounded shell, wide visor lens, stripe in the suit colour (red on light suits)
		local shellC = at(0, 0.08, 0.2)
		local sc = look.suit.color
		local stripe = lum(sc) > 0.7 and Color3.fromRGB(224, 60, 49) or sc
		W(ellip(f, Vector3.new(2.16, 2.26, 2.36) * u, shellC, white, Enum.Material.SmoothPlastic))
		W(ellip(f, Vector3.new(0.52, 2.29, 2.39) * u, shellC, stripe, Enum.Material.SmoothPlastic))
		W(ellip(f, Vector3.new(0.66, 2.275, 2.375) * u, shellC, dark, Enum.Material.SmoothPlastic))
		W(ellip(f, Vector3.new(1.86, 1.04, 0.62) * u, at(0, 0.06, -0.8), vis.color, Enum.Material.Glass, vis.tr, vis.refl))
		-- chin guard
		W(ellip(f, Vector3.new(1.5, 0.5, 0.5) * u, at(0, -0.62, -0.72), Color3.fromRGB(58, 62, 70), Enum.Material.SmoothPlastic))
		return
	end
end

------------------------------------------------------------------ EVA shell (full suit in space)
local EVA_SCALE = {
	UpperTorso = 1.07, LowerTorso = 1.07, LeftUpperArm = 1.1, RightUpperArm = 1.1, LeftLowerArm = 1.1, RightLowerArm = 1.1,
	LeftUpperLeg = 1.08, RightUpperLeg = 1.08, LeftLowerLeg = 1.08, RightLowerLeg = 1.08,
	LeftHand = 1.14, RightHand = 1.14, LeftFoot = 1.14, RightFoot = 1.14,
}
K.EVA_SCALE = EVA_SCALE
local function evaShell(char, f, look, roleCol)
	local suit = look.suit
	local base = suit.color
	local mat = Enum.Material[suit.mat or "Fabric"]
	local glove = base:Lerp(Color3.fromRGB(64, 66, 72), 0.35)
	local boot = lum(base) < 0.3 and Color3.fromRGB(26, 28, 32) or Color3.fromRGB(64, 68, 76)
	for name, k in EVA_SCALE do
		local bp = char:FindFirstChild(name)
		if bp and bp:IsA("MeshPart") then
			local s = bp:Clone()
			s:ClearAllChildren()
			s.Name = "EVA_" .. name
			s.Size = bp.Size * k
			s.CFrame = bp.CFrame
			pcall(function() s.TextureID = "" end)
			local hand, foot = name:find("Hand"), name:find("Foot")
			s.Color = foot and boot or (hand and glove or base)
			s.Material = (hand or foot) and Enum.Material.SmoothPlastic or mat
			s.Reflectance = (hand or foot) and 0 or (suit.refl or 0)
			s.Transparency = 0
			s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.Massless, s.CastShadow = false, false, false, false, true, true
			s.Parent = f
			weld(bp, s)
		end
	end
	local lt = char:FindFirstChild("LowerTorso")
	if lt then
		local belt = piece(f, Vector3.new(lt.Size.X * 1.14, 0.22, lt.Size.Z * 1.2), lt.CFrame * CFrame.new(0, lt.Size.Y * 0.28, 0), Color3.fromRGB(96, 100, 110), Enum.Material.Metal)
		weld(lt, belt)
	end
	for _, side in { "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg" } do
		local bp = char:FindFirstChild(side)
		if bp then
			local cuff = piece(f, Vector3.new(bp.Size.X * 1.18, 0.18, bp.Size.Z * 1.18), bp.CFrame * CFrame.new(0, side:find("Arm") and -bp.Size.Y * 0.38 or bp.Size.Y * 0.34, 0), roleCol, Enum.Material.SmoothPlastic)
			weld(bp, cuff)
		end
	end
end

------------------------------------------------------------------ whole suit
-- opts: eva (full suit for space), roleCol (class colour or nil), lights (real helmet lamps)
function K.build(char, look, opts)
	opts = opts or {}
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not head or not torso then return nil end
	local old = char:FindFirstChild("NovaSuit")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "NovaSuit"
	f.Parent = char
	local eva = opts.eva == true
	local suit = look.suit
	local suitCol = suit.color
	local cls = opts.roleCol
	K.hideAccessories(char, eva, look.helmet.cover == true)
	if eva then evaShell(char, f, look, cls or suitCol) end
	K.helmet(f, head, look, { lights = opts.lights and eva })
	-- life-support backpack + class lamp
	local ts = torso.Size
	local tk = eva and 1.07 or 1
	local tcf = torso.CFrame
	local pd = math.max(0.5, ts.Z * 0.7)
	local pack = piece(f, Vector3.new(ts.X * 0.77, ts.Y * 1.0, pd), tcf * CFrame.new(0, 0.05, ts.Z * 0.5 * tk + pd * 0.5 - 0.08), Color3.fromRGB(210, 210, 214), Enum.Material.Metal)
	pcall(function() pack.MaterialVariant = "NovaWallPanel" end)
	weld(torso, pack)
	local lamp = piece(f, Vector3.new(ts.X * 0.46, 0.12, 0.08), tcf * CFrame.new(0, ts.Y * 0.32, ts.Z * 0.5 * tk + pd - 0.06), cls or suitCol, Enum.Material.Neon)
	weld(torso, lamp)
	-- chest plate in the suit colour (a lighter panel on the EVA suit) with the class stripe
	local front = -(ts.Z * 0.5 * tk + 0.06)
	local plateCol = eva and suitCol:Lerp(Color3.new(1, 1, 1), lum(suitCol) > 0.7 and 0 or 0.12) or suitCol
	if eva and lum(suitCol) > 0.7 then plateCol = Color3.fromRGB(206, 208, 212) end
	local plate = piece(f, Vector3.new(ts.X * 0.9, ts.Y * 0.7, 0.18), tcf * CFrame.new(0, ts.Y * 0.12, front), plateCol, Enum.Material.SmoothPlastic)
	plate.Reflectance = suit.refl or 0
	weld(torso, plate)
	local stripe = piece(f, Vector3.new(ts.X * 0.905, 0.16, 0.2), tcf * CFrame.new(0, -ts.Y * 0.1, front - 0.01), cls or Color3.new(1, 1, 1), Enum.Material.Neon, nil, 0.1)
	weld(torso, stripe)
	-- arm bands + shoulder patch on the left arm
	for _, side in { "LeftUpperArm", "RightUpperArm" } do
		local arm = char:FindFirstChild(side)
		if arm then
			local k = eva and 1.16 or 1
			local bandCol = eva and (lum(suitCol) > 0.7 and Color3.fromRGB(150, 154, 162) or suitCol:Lerp(Color3.new(0, 0, 0), 0.25)) or suitCol
			local band = piece(f, Vector3.new(arm.Size.X * k + 0.08, 0.3, arm.Size.Z * k + 0.08), arm.CFrame * CFrame.new(0, arm.Size.Y * 0.18, 0), bandCol, Enum.Material.SmoothPlastic)
			weld(arm, band)
			if side == "LeftUpperArm" and look.patch then
				local ak = eva and 1.1 or 1
				local d = math.clamp(math.min(arm.Size.Y * 0.46, arm.Size.Z * 0.64), 0.3, 1.2)
				local x = -(arm.Size.X * 0.5 * ak) - 0.02
				local pcf = arm.CFrame * CFrame.new(x, -arm.Size.Y * 0.16, 0)
				local rim = piece(f, Vector3.new(0.05, d, d), pcf, Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
				weld(arm, rim)
				local disc = piece(f, Vector3.new(0.05, d * 0.84, d * 0.84), pcf * CFrame.new(-0.015, 0, 0), look.patch.color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
				weld(arm, disc)
				local star = piece(f, Vector3.new(0.05, d * 0.26, d * 0.26), pcf * CFrame.new(-0.03, d * 0.06, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(245, 245, 242), Enum.Material.SmoothPlastic)
				weld(arm, star)
				local swoosh = piece(f, Vector3.new(0.05, d * 0.08, d * 0.62), pcf * CFrame.new(-0.03, -d * 0.18, 0) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(224, 60, 49), Enum.Material.SmoothPlastic)
				if look.patch.id == "patch_red" then swoosh.Color = Color3.fromRGB(245, 245, 242) end
				weld(arm, swoosh)
			end
		end
	end
	return f
end

return K
