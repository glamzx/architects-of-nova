-- LiveDataService: real NASA data in the hub.
-- DONKI solar flares (last 30 days) set the "space weather" and how often emergencies happen.
-- NeoWs lists today's real near-Earth asteroids on the Archive threat board.
local HttpService = game:GetService("HttpService")
local L = {}
local KEY = "DEMO_KEY" -- public NASA demo key (rate-limited); replace with your own api.nasa.gov key

local function get(url)
	local ok, res = pcall(function() return HttpService:GetAsync(url) end)
	if not ok then return nil end
	local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
	return ok2 and data or nil
end

local function flareScore(cls)
	local letter, num = string.match(cls or "", "^(%a)([%d%.]+)")
	local base = ({ A = 0, B = 0.5, C = 1, M = 2, X = 3 })[letter or "A"] or 0
	return base + (tonumber(num) or 0) / 10, letter
end

function L.refresh()
	local now = os.time()
	local start = os.date("!%Y-%m-%d", now - 30 * 86400)
	local stop = os.date("!%Y-%m-%d", now)
	local flares = get(("https://api.nasa.gov/DONKI/FLR?startDate=%s&endDate=%s&api_key=%s"):format(start, stop, KEY))
	local best, bestCls, count = -1, nil, 0
	if typeof(flares) == "table" then
		for _, f in flares do
			count += 1
			local s = flareScore(f.classType)
			if s > best then best, bestCls = s, f.classType end
		end
	end
	workspace:SetAttribute("SpaceWeather", bestCls or "C1.0")
	workspace:SetAttribute("FlareCount", count)
	workspace:SetAttribute("StormLevel", bestCls and math.clamp(math.floor(best), 0, 3) or 1)
	workspace:SetAttribute("WeatherLive", bestCls ~= nil)
	local feed = get(("https://api.nasa.gov/neo/rest/v1/feed?start_date=%s&end_date=%s&api_key=%s"):format(stop, stop, KEY))
	local list = {}
	if typeof(feed) == "table" and feed.near_earth_objects then
		for _, day in feed.near_earth_objects do
			for _, neo in day do
				local ca = neo.close_approach_data and neo.close_approach_data[1]
				table.insert(list, {
					name = neo.name,
					km = ca and tonumber(ca.miss_distance.kilometers) or 0,
					d = neo.estimated_diameter and math.floor((neo.estimated_diameter.meters.estimated_diameter_max or 0)) or 0,
					hazard = neo.is_potentially_hazardous_asteroid,
				})
			end
		end
		table.sort(list, function(a, b) return a.km < b.km end)
	end
	if #list == 0 then
		list = { { name = "(99942) Apophis", km = 31600, d = 370, hazard = true, offline = true } }
	end
	local top = {}
	for i = 1, math.min(3, #list) do top[i] = list[i] end
	workspace:SetAttribute("Threats", HttpService:JSONEncode(top))
end

function L.init()
	task.spawn(function()
		while true do
			L.refresh()
			task.wait(1800)
		end
	end)
end

return L
