-- NovaPhysicsTaskServer: rewards the first "Thrust check" (W = m x g) completion per player per server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local ev = RS:FindFirstChild("NovaPhysicsTaskDone") or Instance.new("RemoteEvent")
ev.Name = "NovaPhysicsTaskDone"
ev.Parent = RS

local REWARD = 25
local done = {}

local function giveCredits(player, amount)
	local ok, Progress = pcall(function()
		local mod = SSS:FindFirstChild("NovaServices") and SSS.NovaServices:FindFirstChild("ProgressService")
		return mod and require(mod)
	end)
	if not ok or type(Progress) ~= "table" then return false end
	-- ProgressService.award(player, xp, credits)
	if type(Progress.award) == "function" then
		return (pcall(Progress.award, player, 40, amount))
	end
	return false
end

ev.OnServerEvent:Connect(function(player, kind)
	if kind ~= "thrust_check" or done[player] then return end
	done[player] = true
	player:SetAttribute("PhysicsThrustCheck", true)
	local paid = giveCredits(player, REWARD)
	ev:FireClient(player, "reward", paid and REWARD or 0)
end)

Players.PlayerRemoving:Connect(function(p) done[p] = nil end)
