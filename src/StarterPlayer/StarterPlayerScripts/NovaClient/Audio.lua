-- Audio: music, ambience beds and sound effects. All assets are licensed for use in Roblox experiences
-- (APM Music, Pro Sound Effects and DistroKid via the Creator Store).
-- Music = short story cues (Earth cold open, briefing, Vex, launch, warp, victory) + long calm ambient playlists
-- for the Citadel and every world: low volume, slow crossfades, quiet gaps between tracks.
-- Three SoundGroups (NovaMusic / NovaSFX / NovaAmbience) follow the Settings sliders.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local A = {}
A.settings = { music = 0.8, sfx = 0.9, ambience = 0.7, shake = true }

-- story cues; loop = false plays once and then leaves a quiet moment
local MUSIC = {
	intro = { id = 9043165226, vol = 0.5, loop = false, fade = 1.5 },       -- Rising Anguish 30 A (APM): piano, solo cello, sad strings
	hope = { id = 1835239066, vol = 0.4, loop = false, fade = 2.5 },        -- Hope Amidst Desolation 30B, strings (APM): Citadel reveal
	menu = { id = 1845667093, vol = 0.3, fade = 2 },                       -- A Secret Tale (APM)
	briefing = { id = 9044748817, vol = 0.2, fade = 2.5 },                 -- Dignity (i) (APM): quiet, measured theme under Kade
	tension = { id = 1848159364, vol = 0.26, fade = 2 },                   -- Darkness On The Edge Of Time (APM): Admiral Vex
	urgent = { id = 1845350706, vol = 0.3, fade = 1 },                     -- Panic Stations (APM): emergencies
	launch = { id = 1846428560, vol = 0.36, fade = 1.2 },                  -- Forces Of Nature (APM)
	warp = { id = 1843084049, vol = 0.32, fade = 0.8 },                    -- Feel The Rush Rise (APM)
	victory = { id = 76713806494480, vol = 0.42, loop = false, fade = 1.2 }, -- Victorious Journey (APM): mission success
	-- ambient beds (long, calm tracks with silence between them)
	hub = { list = { 9046399990, 107517918824877, 78834201319459 }, vol = 0.17 }, -- Elixir / Oshara Dawn (light) / Peaceful Mind (APM), 2-4 min each
}
local FIELD = {
	moon = { 9042042581, 9046399990 },        -- Eternal Ice (c) / Elixir (APM)
	mars = { 1838926651, 9046399990 },        -- Natural Planet / Elixir (APM)
	europa = { 9042042581, 78834201319459 },  -- Eternal Ice (c) / Peaceful Mind (APM)
	asteroid = { 107517918824877, 9042042581 }, -- Oshara Dawn (light) / Eternal Ice (c)
	orbit = { 107517918824877, 9042042581 },
	l2 = { 107517918824877, 9042042581 },
}
local FIELD_VOL = 0.16
local GAP_MIN, GAP_MAX = 18, 40             -- seconds of quiet between ambient tracks

local AMBIENCE = {
	hub = { id = 1843828165, vol = 0.18 },      -- Low Drone 1 (APM): station hum
	cabin = { id = 9119132176, vol = 0.45 },    -- Shuttle craft interior (Pro Sound Effects)
	orbit = { id = 1843770583, vol = 0.3 },     -- Low Drone 45 (APM): vacuum, suit hum
	moon = { id = 1843770583, vol = 0.3 },
	asteroid = { id = 1843770583, vol = 0.3 },
	l2 = { id = 1843721458, vol = 0.3 },        -- Low Drone 22 (APM)
	mars = { id = 9125742262, vol = 0.4 },      -- airy wind (Pro Sound Effects)
	europa = { id = 1843721458, vol = 0.32 },
}

-- string = built-in sound; table = { id, vol, twoD (ignore position), len (seconds before it fades/ends), fade, fadeIn }
local SFX = {
	click = "rbxasset://sounds/electronicpingshort.wav",
	ui = "rbxasset://sounds/electronicpingshort.wav",
	install = "rbxasset://sounds/snap.mp3",
	drop = "rbxasset://sounds/clickfast.wav",
	fix = "rbxasset://sounds/electronicpingshort.wav",
	scan = "rbxasset://sounds/electronicpingshort.wav",
	poll = "rbxasset://sounds/electronicpingshort.wav",
	achievement = "rbxasset://sounds/electronicpingshort.wav",
	go = "rbxassetid://9043344871",
	hold = "rbxassetid://9075074819",
	door = "rbxassetid://9043344871",
	alarm = "rbxassetid://9075074819",
	-- launches and flights (Pro Sound Effects)
	rocket = { id = 9125975400, twoD = true, len = 11, fade = 2.5 },               -- Spaceship Blast Off: big low-end roar
	rumble = { id = 9119413402, twoD = true, len = 7, fade = 2.5, fadeIn = 0.8 },  -- rocket engine: thunderous rumble + crackle
	swoosh = { id = 9114340009, twoD = true, len = 3.2, fade = 1.4 },              -- energy pass-by: whoosh into the jump
	warp = { id = 9119437475, twoD = true, len = 6, fade = 1.5, fadeIn = 0.5 },    -- travelling tone into a wormhole: tunnel hum
	-- cold open: the solar storm (Pro Sound Effects)
	storm = { id = 9114223123, twoD = true, len = 30, fade = 3, fadeIn = 3 },     -- deep booms, long rumbling decay
	plasma = { id = 9114340009, twoD = true, len = 8, fade = 2 },                  -- pulsing, staticky energy pass-by
	crackle = { id = 9116277954, twoD = true, len = 3 },                           -- quick electrical burst
	crackle2 = { id = 9116274992, twoD = true, len = 5 },                          -- longer electrical crackle
	impact = { id = 9116282646, twoD = true, len = 11, fade = 3 },                 -- massive crack + rolling decay
	thump = { id = 9113552058, twoD = true, len = 4 },                             -- deep resonant boom
}
local PITCH = { poll = 1.25, go = 1.0, hold = 0.9, ui = 1.4 }

local function group(name)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = SoundService
	return g
end
local gMusic, gSfx, gAmb = group("NovaMusic"), group("NovaSFX"), group("NovaAmbience")

function A.apply()
	gMusic.Volume = A.settings.music
	gSfx.Volume = A.settings.sfx
	gAmb.Volume = A.settings.ambience
end
A.apply()

local function newSound(id, grp, looped)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = 0
	s.Looped = looped
	s.SoundGroup = grp
	s.Parent = SoundService
	return s
end
local function fadeOut(s, t)
	if not s or not s.Parent then return end
	TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = 0 }):Play()
	task.delay(t + 0.1, function() s:Destroy() end)
end
local function fadeIn(s, vol, t)
	TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Volume = vol }):Play()
end

------------------------------------------------------------------ music
local musicSlot = { name = nil, key = nil, token = 0, current = nil }
local ambSlot = { name = nil }
local lastPick = {}
local function pick(list, key)
	if #list == 1 then return list[1] end
	local id
	repeat id = list[math.random(#list)] until id ~= lastPick[key]
	lastPick[key] = id
	return id
end

-- ambient playlist: one calm track, fade out near its end, a quiet gap, then the next one
local function runPlaylist(tok, list, vol, key)
	task.spawn(function()
		local first = true
		while musicSlot.token == tok do
			local s = newSound(pick(list, key), gMusic, false)
			s:Play()
			fadeIn(s, vol, first and 3 or 5)
			first = false
			musicSlot.current = s
			local t0 = os.clock()
			while musicSlot.token == tok and s.Parent do
				local loaded = s.IsLoaded and s.TimeLength > 0
				if loaded and s.TimePosition >= s.TimeLength - 5 then break end
				if loaded and not s.IsPlaying and os.clock() - t0 > 3 then break end
				if not loaded and os.clock() - t0 > 12 then break end -- failed to load: skip it
				if os.clock() - t0 > 900 then break end
				task.wait(0.5)
			end
			if musicSlot.token ~= tok then return end
			fadeOut(s, 5)
			if musicSlot.current == s then musicSlot.current = nil end
			local gap, tw = math.random(GAP_MIN, GAP_MAX), os.clock()
			while musicSlot.token == tok and os.clock() - tw < gap do task.wait(0.5) end
		end
	end)
end

local function resolve(name)
	if name == "field" then
		local loc = ambSlot.name
		return "field:" .. tostring(loc), { list = FIELD[loc] or FIELD.moon, vol = FIELD_VOL }
	end
	return name, name and MUSIC[name]
end

-- music(name): crossfade to a cue or playlist. music(nil, t) fades to silence.
function A.music(name, fadeTime)
	local key, def = resolve(name)
	if key == musicSlot.key then return end
	musicSlot.key, musicSlot.name = key, name
	musicSlot.token += 1
	local tok = musicSlot.token
	fadeOut(musicSlot.current, fadeTime or (def and def.list and 3.5) or 1.8)
	musicSlot.current = nil
	if not def then return end
	if def.list then
		runPlaylist(tok, def.list, def.vol, key)
	else
		local s = newSound(def.id, gMusic, def.loop ~= false)
		s:Play()
		fadeIn(s, def.vol, def.fade or 1.6)
		musicSlot.current = s
	end
end
function A.currentMusic() return musicSlot.name end

function A.ambience(name)
	if name == ambSlot.name then return end
	ambSlot.name = name
	local old = ambSlot.current
	fadeOut(old, 2.5)
	ambSlot.current = nil
	local def = AMBIENCE[name]
	if def then
		local s = newSound(def.id, gAmb, true)
		s:Play()
		fadeIn(s, def.vol, 2.5)
		ambSlot.current = s
	end
	-- the field playlist follows the world the crew is on
	if musicSlot.name == "field" and name ~= "cabin" then A.music("field") end
end

------------------------------------------------------------------ effects
function A.sfx(name, pos, vol, opts)
	local def = SFX[name]
	if not def then return end
	if type(def) == "string" then def = { url = def } end
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = def.url or ("rbxassetid://" .. def.id)
	local target = vol or def.vol or 0.5
	local fi = opts.fadeIn or def.fadeIn
	s.Volume = fi and 0 or target
	s.PlaybackSpeed = opts.speed or PITCH[name] or 1
	s.SoundGroup = gSfx
	local holder = s
	if pos and not def.twoD then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = workspace.Terrain
		s.RollOffMaxDistance = 160
		s.Parent = att
		holder = att
	else
		s.Parent = SoundService
	end
	s:Play()
	if fi then fadeIn(s, target, fi) end
	local len, fo = opts.len or def.len or 10, opts.fade or def.fade
	task.delay(len, function()
		if not s.Parent then return end
		if fo then
			TweenService:Create(s, TweenInfo.new(fo), { Volume = 0 }):Play()
			task.delay(fo + 0.05, function() holder:Destroy() end)
		else
			holder:Destroy()
		end
	end)
	s.Ended:Connect(function() holder:Destroy() end)
	return s
end

-- fade out and remove a sound returned by A.sfx
function A.stopSfx(s, t)
	if not s or not s.Parent then return end
	local holder = s.Parent:IsA("Attachment") and s.Parent or s
	TweenService:Create(s, TweenInfo.new(t or 0.6), { Volume = 0 }):Play()
	task.delay((t or 0.6) + 0.05, function() holder:Destroy() end)
end

-- all asset ids (used by the load check in Studio)
function A.allIds()
	local ids = {}
	for _, d in MUSIC do if d.id then table.insert(ids, d.id) end for _, id in d.list or {} do table.insert(ids, id) end end
	for _, l in FIELD do for _, id in l do table.insert(ids, id) end end
	for _, d in AMBIENCE do table.insert(ids, d.id) end
	for _, d in SFX do if type(d) == "table" then table.insert(ids, d.id) end end
	return ids
end

return A
