-- ConsoleService: co-op interactions at the 4 mission-control consoles.
-- Kinds (data-driven, from mission events):
--   press    : any listed console
--   sync     : distinct consoles pressed within `window` seconds (count scales with player count)
--   sequence : consoles in exact order (a wrong console fails)
--   relay    : consoles light one after another; each must be pressed while lit
-- If nobody touches a console before the timeout, BIP-7 covers it (solo-friendly).
local Players = game:GetService("Players")

local Citadel = workspace:WaitForChild("Citadel")
local C = {}
local Mission
local consoles: { [string]: { prompt: ProximityPrompt, glow: BasePart?, baseColor: Color3? } } = {}
local active: any = nil

function C.busy()
	return active ~= nil
end

local function setPrompts()
	local reh = Mission.activeRehearsal()
	for name, c in consoles do
		local on, key = false, "p_console"
		if active then
			if active.def.kind == "relay" then
				on = active.lit == name
			else
				on = table.find(active.def.consoles, name) ~= nil
			end
		elseif reh then
			on, key = true, "p_rehearse"
		end
		c.prompt.Enabled = on
		if c.prompt:GetAttribute("Key") ~= key then c.prompt:SetAttribute("Key", key) end
		if c.glow then c.glow.Transparency = on and 0.05 or 0.55 end
	end
end

local function publish()
	if active then
		local pressed = {}
		local now = os.clock()
		for nm, t in active.presses do
			if active.def.kind ~= "sync" or now - t <= (active.def.window or 2) then table.insert(pressed, nm) end
		end
		Mission.state.waiting = { kind = active.def.kind, consoles = active.def.consoles, lit = active.lit, pressed = pressed, step = active.step, window = active.def.window, rehearsal = active.rehearsal }
	else
		Mission.state.waiting = nil
	end
	setPrompts()
	Mission.broadcast()
end

local function finish(result: boolean)
	if active and not active.done then
		active.done = true
		active.result = result
	end
end

function C.press(player: Player, name: string)
	if not active then
		if Mission.activeRehearsal() then Mission.startRehearsal(player) end
		return
	end
	local def = active.def
	if not table.find(def.consoles, name) or active.done then return end
	local now = os.clock()
	active.touched = true
	if def.kind == "press" then
		active.presses[name] = now
		finish(true)
	elseif def.kind == "sync" then
		active.presses[name] = now
		local need = math.min(#def.consoles, math.max(1, #Players:GetPlayers()))
		local n = 0
		for _, t in active.presses do
			if now - t <= (def.window or 2) then n += 1 end
		end
		if n >= need then finish(true) end
	elseif def.kind == "sequence" then
		if name == def.consoles[active.step] then
			active.presses[name] = now
			active.step += 1
			if active.step > #def.consoles then finish(true) end
		else
			finish(false) -- wrong order: the programmed sequence breaks
		end
	elseif def.kind == "relay" then
		if name == active.lit then
			active.presses[name] = now
			active.hit = true
		end
	end
	publish()
end

-- Runs one interaction; yields. Returns (success, coveredByBip)
function C.run(def, opts)
	opts = opts or {}
	active = { def = def, presses = {}, step = 1, startT = os.clock(), touched = false, done = false, rehearsal = opts.rehearsal }
	local timeout = def.timeout or 30
	local byBip = false
	publish()
	if def.kind == "relay" then
		local ok = true
		for i, name in def.consoles do
			if not active then return false, false end
			active.lit, active.hit, active.step = name, false, i
			publish()
			local t0 = os.clock()
			local win = if i == 1 then timeout else (def.window or 5)
			while active and not active.hit and os.clock() - t0 < win do task.wait(0.1) end
			if not active then return false, false end
			if not active.hit then
				if i == 1 and not opts.noBip then
					byBip = true -- nobody came: BIP-7 runs the whole handover
					break
				end
				ok = false
				break
			end
		end
		active = nil
		publish()
		return ok, byBip
	end
	while active and not active.done and os.clock() - active.startT < timeout do
		task.wait(0.1)
		if active and active.def.kind == "sync" then publish() end
	end
	if not active then return false, false end
	local result = active.result
	if not active.done then
		if not active.touched and not opts.noBip then
			result, byBip = true, true
		else
			result = false
		end
	end
	active = nil
	publish()
	return result == true, byBip
end

function C.cancel()
	if active then
		active.done = true
		active = nil
		publish()
	end
end

function C.init(mission)
	Mission = mission
	for _, m in Citadel.Control.Consoles:GetChildren() do
		local btn = m:FindFirstChild("Button")
		if not btn then continue end
		for _, old in btn:GetChildren() do if old:IsA("ProximityPrompt") then old:Destroy() end end
		local p = Instance.new("ProximityPrompt")
		p.Name = "ConsolePrompt"
		p.MaxActivationDistance = 8
		p.RequiresLineOfSight = false
		p.HoldDuration = 0
		p.Enabled = false
		p:SetAttribute("Key", "p_console")
		p:SetAttribute("ObjectKey", m.Name)
		p.Parent = btn
		local name = m.Name
		p.Triggered:Connect(function(plr) C.press(plr, name) end)
		consoles[name] = { prompt = p, glow = m:FindFirstChild("Glow") }
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			setPrompts()
		end
	end)
end

return C
