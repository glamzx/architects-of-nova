-- ProgressService: XP and CML ranks, credits, achievements, Grok's cosmetics, Zero-G trainer records,
-- and the class spacesuit look. Profiles persist in a DataStore when available (falls back to session memory).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Progress = require(RS.Nova.Data.Progress)
local Classes = require(RS.Nova.Data.Classes)
-- suit builder (shared with the Outfitter preview); if it ever fails to load, a minimal built-in suit keeps the game running
local okKit, SuitKit = pcall(function() return require(RS.Nova.Data.Progress:WaitForChild("SuitKit", 10)) end)
if not okKit or type(SuitKit) ~= "table" then
	warn("[ProgressService] SuitKit unavailable: " .. tostring(SuitKit))
	local byId = {}
	for _, it in Progress.outfit or {} do byId[it.id] = it end
	SuitKit = { SLOTS = { "suit", "helmet", "visor", "patch" }, DEFAULT = { suit = "suit_white", helmet = "helmet_bubble", visor = "visor_std", patch = "patch_blue" } }
	function SuitKit.item(id) return id and byId[id] or nil end
	function SuitKit.resolve(equip) return { suit = byId[equip and equip.suit or ""] or byId.suit_white } end
	SuitKit.build = nil
end
local Remotes = RS.Nova.Remotes

local P = {}
local Mission
local profiles: { [Player]: any } = {}
local store
pcall(function() store = game:GetService("DataStoreService"):GetDataStore("NovaProfile_v1") end)

local function default()
	return { xp = 0, credits = 30, ach = {}, owned = {}, equip = { suit = "suit_white", helmet = "helmet_bubble", visor = "visor_std", patch = "patch_blue" }, trainerBest = nil, items = {}, codes = {}, lastDaily = "", streak = 0, quests = nil }
end

local function shopItem(id)
	for _, it in Progress.shop do if it.id == id then return it end end
	return SuitKit.item(id) -- spacesuit outfitter items (Progress.outfit)
end
-- free (price 0) items are always owned
local function owns(pr, it) return it.price == 0 or (pr.owned and pr.owned[it.id] == true) end

local function rankOf(xp)
	local r = 1
	for i, rk in Progress.ranks do if xp >= rk.xp then r = i end end
	return r
end

function P.profile(player) return profiles[player] end

function P.push(player)
	local pr = profiles[player]
	if not pr then return end
	Remotes.Cue:FireClient(player, { type = "profile", profile = pr, rank = rankOf(pr.xp) })
end

local function save(player)
	local pr = profiles[player]
	if store and pr then pcall(function() store:SetAsync("u" .. player.UserId, pr) end) end
end

-- client settings (volumes, camera shake): validated, stored in the profile, saved with it
function P.setSettings(player, data)
	local pr = profiles[player]
	if not pr or typeof(data) ~= "table" then return end
	local clean = {}
	for _, k in { "music", "sfx", "ambience" } do
		if typeof(data[k]) == "number" then clean[k] = math.clamp(data[k], 0, 1) end
	end
	if typeof(data.shake) == "boolean" then clean.shake = data.shake end
	pr.settings = clean
end

function P.award(player, xp, credits)
	local pr = profiles[player]
	if not pr then return end
	local before = rankOf(pr.xp)
	pr.xp += xp or 0
	pr.credits += credits or 0
	if rankOf(pr.xp) > before then
		Remotes.Cue:FireClient(player, { type = "rankUp", rank = rankOf(pr.xp) })
	end
	P.push(player)
end

function P.achieve(player, id)
	local pr = profiles[player]
	local a = Progress.achievements[id]
	if not pr or not a or pr.ach[id] then return end
	pr.ach[id] = true
	Remotes.Cue:FireClient(player, { type = "achievement", id = id, key = a.key, icon = a.icon })
	P.award(player, a.xp, 10)
end

function P.achieveAll(id)
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") then P.achieve(p, id) end end
end

function P.awardAll(xp, credits)
	for _, p in Players:GetPlayers() do if p:GetAttribute("InLobby") then P.award(p, xp, credits) end end
end

------------------------------------------------------------------ spacesuit look
-- Built by Data.Progress.SuitKit (shared with the Outfitter preview): suit colour, helmet style, visor tint,
-- shoulder patch from profile.equip; attr EVA = full suit (body shell in the suit colour, gloves, boots, helmet lamps).
function P.setEVA(player, on)
	player:SetAttribute("EVA", on and true or nil)
	P.applySuit(player)
end

function P.applySuit(player)
	local char = player.Character
	if not char then return end
	local pr = profiles[player] or default()
	local cls = Classes.byId[player:GetAttribute("Class") or ""]
	local ok, err = false, "no SuitKit"
	if SuitKit.build then
		ok, err = pcall(SuitKit.build, char, SuitKit.resolve(pr.equip), { eva = player:GetAttribute("EVA") == true, roleCol = cls and cls.color, lights = true })
		if not ok then -- retry with the free default look
			warn("[ProgressService] suit: " .. tostring(err))
			ok, err = pcall(SuitKit.build, char, SuitKit.resolve(nil), { eva = player:GetAttribute("EVA") == true, roleCol = cls and cls.color })
		end
	end
	if not ok then -- last resort: the original simple suit (glass bubble + chest plate)
		pcall(function()
			local old = char:FindFirstChild("NovaSuit")
			if old then old:Destroy() end
			local head = char:FindFirstChild("Head")
			local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			if not head or not torso then return end
			local f = Instance.new("Folder")
			f.Name = "NovaSuit"
			f.Parent = char
			local function piece(size, cf, color, mat, shape, tr, to)
				local p = Instance.new("Part")
				if shape then p.Shape = shape end
				p.Size, p.CFrame, p.Color, p.Material, p.Transparency = size, cf, color, mat, tr or 0
				p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
				p.Parent = f
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1, w.Parent = to, p, p
			end
			local look = SuitKit.resolve(pr.equip)
			local col = look.suit and look.suit.color or Color3.fromRGB(234, 235, 230)
			piece(Vector3.new(2.15, 2.15, 2.15), head.CFrame, Color3.fromRGB(180, 210, 230), Enum.Material.Glass, Enum.PartType.Ball, 0.72, head)
			piece(Vector3.new(1.5, 1.7, 0.7), torso.CFrame * CFrame.new(0, 0.05, 0.75), Color3.fromRGB(210, 210, 214), Enum.Material.Metal, nil, 0, torso)
			piece(Vector3.new(1.75, 1.2, 0.18), torso.CFrame * CFrame.new(0, 0.2, -0.52), col, Enum.Material.SmoothPlastic, nil, 0, torso)
		end)
	end
	P.push(player)
end

------------------------------------------------------------------ shop & trainer
-------------------------------------------------- items, daily reward, daily quests, codes
-- Parts Book: a part is discovered the first time you pick it up; every 5 new parts pay credits
function P.discover(player, id)
	local pr = profiles[player]
	if not pr or typeof(id) ~= "string" then return end
	pr.seen = pr.seen or {}
	if pr.seen[id] then return end
	pr.seen[id] = true
	local n = 0
	for _ in pr.seen do n += 1 end
	local reward = (n % 5 == 0) and 20 or 0
	pr.credits += reward
	Remotes.Cue:FireClient(player, { type = "discover", id = id, count = n, reward = reward })
	P.push(player)
end
-- Rocket Lab: each level pays once
function P.labDone(player, level)
	local pr = profiles[player]
	if not pr or typeof(level) ~= "number" or level < 1 or level > 3 then return 0 end
	pr.lab = pr.lab or {}
	if pr.lab[tostring(level)] then return 0 end
	pr.lab[tostring(level)] = true
	local reward = ({ 40, 60, 80 })[level]
	pr.credits += reward
	pr.xp += 50
	P.push(player)
	save(player)
	return reward
end
-- Mission quiz: one bonus per mission
function P.quiz(player, missionId)
	local pr = profiles[player]
	if not pr or typeof(missionId) ~= "string" then return 0 end
	pr.quiz = pr.quiz or {}
	if pr.quiz[missionId] then return 0 end
	pr.quiz[missionId] = true
	pr.credits += 15
	P.push(player)
	return 15
end

function P.hasItem(player, id) local pr = profiles[player] return pr and ((pr.items and (pr.items[id] or 0) > 0) or (pr.owned and pr.owned[id])) or false end
function P.useItem(player, id)
	local pr = profiles[player]
	if not pr or not pr.items or (pr.items[id] or 0) <= 0 then return false end
	pr.items[id] -= 1
	P.push(player)
	return true
end
local function today() return os.date("!%Y%m%d") end
local function rollQuests(pr)
	if pr.quests and pr.quests.day == today() then return end
	local pool = table.clone(Progress.quests)
	local list = {}
	for _ = 1, 3 do
		local k = math.random(1, #pool)
		local q = table.remove(pool, k)
		table.insert(list, { id = q.id, key = q.key, need = q.need, have = 0, reward = q.reward, icon = q.icon, done = false })
	end
	pr.quests = { day = today(), list = list }
end
function P.questEvent(player, id, n)
	local pr = profiles[player]
	if not pr then return end
	rollQuests(pr)
	for _, q in pr.quests.list do
		if q.id == id and not q.done then
			q.have = math.min(q.need, q.have + (n or 1))
			if q.have >= q.need then
				q.done = true
				pr.credits += q.reward
				Remotes.Cue:FireClient(player, { type = "questDone", key = q.key, reward = q.reward })
			end
			P.push(player)
		end
	end
end
function P.questAll(id, n)
	for _, pl in Players:GetPlayers() do if pl:GetAttribute("InLobby") ~= false then P.questEvent(pl, id, n) end end
end
local function daily(player, pr)
	local d = today()
	if pr.lastDaily == d then return end
	local yesterday = os.date("!%Y%m%d", os.time() - 86400)
	pr.streak = (pr.lastDaily == yesterday) and math.min((pr.streak or 0) + 1, #Progress.daily) or 1 -- missing a day never takes anything away
	pr.lastDaily = d
	local gain = Progress.daily[pr.streak] or Progress.daily[1]
	pr.credits += gain
	task.delay(6, function() Remotes.Cue:FireClient(player, { type = "daily", day = pr.streak, reward = gain }) end)
end
function P.redeem(player, code)
	local pr = profiles[player]
	if not pr or typeof(code) ~= "string" then return { status = "error" } end
	code = string.upper(string.gsub(code, "%s", ""))
	local c = Progress.codes[code]
	pr.codes = pr.codes or {}
	if not c then return { status = "error", key = "code_bad" } end
	if pr.codes[code] then return { status = "error", key = "code_used" } end
	pr.codes[code] = true
	if c.credits then pr.credits += c.credits end
	if c.item then
		local it = shopItem(c.item)
		if it and it.slot == "consumable" then pr.items = pr.items or {} pr.items[c.item] = (pr.items[c.item] or 0) + (c.n or 1)
		elseif it then pr.owned[c.item] = true end
	end
	P.push(player)
	save(player)
	return { status = "ok", credits = c.credits, item = c.item }
end

local function shopHandler(player, action, id)
	local pr = profiles[player]
	if action == "code" then return P.redeem(player, id) end
	if action == "profile" then -- Outfitter asks for the current profile when it opens
		if not pr then return { status = "error" } end
		return { status = "ok", profile = pr, rank = rankOf(pr.xp) }
	end
	if typeof(id) ~= "string" then return { status = "error" } end
	local it = shopItem(id)
	if not pr or not it then return { status = "error" } end
	pr.items = pr.items or {}
	pr.owned = pr.owned or {}
	pr.equip = pr.equip or {}
	if action == "buy" and it.slot == "consumable" then
		if pr.credits < it.price then return { status = "error", key = "credits_c" } end
		pr.credits -= it.price
		pr.items[id] = (pr.items[id] or 0) + 1
		P.push(player)
		save(player)
		return { status = "ok" }
	end
	if action == "code" then return P.redeem(player, id) end
	if action == "buy" then
		if owns(pr, it) then
			if it.slot == "upgrade" then return { status = "ok", credits = pr.credits } end
			pr.equip[it.slot] = id -- already yours: buying again just puts it on
		else
			if pr.credits < it.price then return { status = "error", key = "credits_c", need = it.price - pr.credits } end
			pr.credits -= it.price
			pr.owned[id] = true
			if it.slot ~= "upgrade" then pr.equip[it.slot] = id end
		end
	elseif action == "equip" then
		if not owns(pr, it) or it.slot == "upgrade" or it.slot == "consumable" then return { status = "error" } end
		pr.equip[it.slot] = id
	else
		return { status = "error" }
	end
	if it.slot == "bip" then workspace:SetAttribute("BipSkin", id) end
	P.applySuit(player)
	save(player)
	return { status = "ok", credits = pr.credits }
end

function P.init(mission)
	Mission = mission
	Remotes.Shop.OnServerInvoke = shopHandler
	Remotes.Trainer.OnServerEvent:Connect(function(player, t)
		if typeof(t) ~= "number" or t < 8 or t > 600 then return end
		local pr = profiles[player]
		if not pr then return end
		if not pr.trainerBest or t < pr.trainerBest then pr.trainerBest = math.floor(t * 100) / 100 end
		P.achieve(player, "trainer")
		P.push(player)
	end)
	local function added(p)
		local pr = default()
		if store then
			local ok, data = pcall(function() return store:GetAsync("u" .. p.UserId) end)
			if ok and typeof(data) == "table" then
				for k, v in data do pr[k] = v end
			end
		end
		profiles[p] = pr
		pr.items = pr.items or {}
		-- outfitter v1: white suit is the new free default (old free amber stays owned as NASA orange); navy -> cobalt
		pr.owned = pr.owned or {}
		pr.equip = pr.equip or {}
		if not pr.outfitV then
			if pr.equip.suit == nil or pr.equip.suit == "suit_amber" then pr.equip.suit = "suit_white" end
			if pr.owned.suit_navy then pr.owned.suit_cobalt = true end
			if pr.equip.suit == "suit_navy" then pr.equip.suit = "suit_cobalt" end
			pr.outfitV = 1
		end
		for _, slot in SuitKit.SLOTS do
			local it = SuitKit.item(pr.equip[slot])
			if not it or it.slot ~= slot or not owns(pr, it) then pr.equip[slot] = SuitKit.DEFAULT[slot] end
		end
		rollQuests(pr)
		daily(p, pr)
		if typeof(pr.settings) == "table" then pcall(function() p:SetAttribute("Settings", game:GetService("HttpService"):JSONEncode(pr.settings)) end) end
		P.push(p)
		p.CharacterAdded:Connect(function()
			task.wait(0.6)
			P.applySuit(p)
		end)
		if p.Character then P.applySuit(p) end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do task.spawn(added, p) end
	Players.PlayerRemoving:Connect(function(p) save(p) profiles[p] = nil end)
	game:BindToClose(function() for p in profiles do save(p) end end)
end

return P
