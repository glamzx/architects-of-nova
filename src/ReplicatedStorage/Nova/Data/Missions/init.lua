--!strict
-- Mission index. Each child ModuleScript (M0, M1, ...) returns one mission table.
-- Adding a mission = adding a data module; the systems (hangar, launch, ops, debrief) stay the same.
local Missions = {}
local order = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		local m = require(child) :: any
		Missions[m.id] = m
		table.insert(order, m.id)
	end
end
table.sort(order)
return { byId = Missions, order = order }
