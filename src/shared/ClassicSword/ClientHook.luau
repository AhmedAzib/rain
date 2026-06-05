local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FireEffects = require(script.Parent.FireEffects)

local ClientHook = {}

local hookedTools: { [Tool]: boolean } = {}

local function isClassicSwordTool(tool: Tool): boolean
	local name = string.lower(tool.Name)
	return string.find(name, "classic", 1, true) ~= nil and string.find(name, "sword", 1, true) ~= nil
end

local function isEquipped(tool: Tool): boolean
	local parent = tool.Parent
	return parent ~= nil and parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") ~= nil
end

local function onEquipped(tool: Tool)
	local ok, err = pcall(function()
		FireEffects.apply(tool)
	end)
	if not ok then
		warn("[ClassicSword] Fire apply failed:", err)
	end
end

local function onUnequipped(tool: Tool)
	pcall(function()
		FireEffects.clear(tool)
	end)
end

local function hookTool(tool: Tool)
	if not isClassicSwordTool(tool) then
		return
	end
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true

	tool.Equipped:Connect(function()
		onEquipped(tool)
	end)

	tool.Unequipped:Connect(function()
		onUnequipped(tool)
	end)

	if isEquipped(tool) then
		onEquipped(tool)
	end
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(hookTool, child)
		end
	end)
end

function ClientHook.start()
	local player = Players.LocalPlayer
	local backpack = player:WaitForChild("Backpack")

	watchContainer(backpack)

	player.CharacterAdded:Connect(function(character)
		watchContainer(character)
	end)

	if player.Character then
		watchContainer(player.Character)
	end
end

return ClientHook
