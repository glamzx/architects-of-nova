-- Visual system shared by all UI: palette, fonts, icon sheet. No emoji anywhere.
local Config = {}

Config.Colors = {
	-- one accent (SpaceX / NASA red), used sparingly: active state, launch-critical, faults
	accent = Color3.fromRGB(224, 60, 49),
	-- statuses (one meaning everywhere); muted, never neon
	green = Color3.fromRGB(92, 196, 128),
	yellow = Color3.fromRGB(240, 178, 62),
	red = Color3.fromRGB(224, 60, 49),
	-- legacy accent names are neutral now (one-accent rule): amber = white, cyan / violet = cool grey
	amber = Color3.fromRGB(242, 242, 242),
	cyan = Color3.fromRGB(178, 188, 200),
	violet = Color3.fromRGB(178, 188, 200),
	-- surfaces: black panels, white type
	bg = Color3.fromRGB(0, 0, 0),
	panel = Color3.fromRGB(6, 7, 8),
	panel2 = Color3.fromRGB(22, 23, 26),
	track = Color3.fromRGB(52, 53, 58),
	line = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(242, 242, 242),
	dim = Color3.fromRGB(146, 148, 156),
	mute = Color3.fromRGB(92, 94, 100),
	dark = Color3.fromRGB(0, 0, 0),
	-- alphas: HUD panels are black and slightly translucent, strokes are 1 px hairlines
	panelT = 0.12,
	lineT = 0.84,
}

-- condensed display face for tracked caps labels / headings, clean grotesk for reading, mono for numbers
Config.Fonts = {
	display = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	head = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold),
	title = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	bodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold),
	mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
}

-- Custom line-icon sheet (assets/ui/nova_icons.png in the repo), 8 x 4 cells of 128 px
Config.IconSheet = {
	image = "rbxassetid://118530024993608",
	cell = 128,
	cols = 8,
	names = { "mass", "power", "budget", "data", "comms", "time", "computer", "battery",
		"panel", "instrument", "orbit", "shadow", "flare", "rocket", "star", "star_o",
		"check", "cross", "arrow", "warning", "commander", "engineer", "scientist", "headset",
		"carry", "task", "retry", "home", "target", "lock", "info", "spark" },
}

Config.CategoryIcon = {
	panel = "panel", battery = "battery", antenna = "comms", instrument = "instrument", computer = "computer",
	rtg = "power", shield = "lock", edl = "target", payload = "target",
}

Config.Roles = {
	{ id = "commander", icon = "commander", color = Color3.fromRGB(246, 196, 72), console = "CommanderConsole" },
	{ id = "engineer", icon = "engineer", color = Color3.fromRGB(255, 150, 80), console = "EngineerConsole" },
	{ id = "scientist", icon = "scientist", color = Color3.fromRGB(170, 140, 230), console = "ScientistConsole" },
	{ id = "comms", icon = "headset", color = Color3.fromRGB(96, 206, 216), console = "AntennaConsole" },
}

Config.MarginRule = 0.10

local index = {}
for i, n in Config.IconSheet.names do index[n] = i - 1 end
-- ImageRectOffset for an icon name
function Config.iconRect(name: string): Vector2
	local i = index[name] or index.info
	local c = Config.IconSheet.cell
	return Vector2.new((i % Config.IconSheet.cols) * c, (i // Config.IconSheet.cols) * c)
end

return Config
