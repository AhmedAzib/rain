-- Even fire coat on blade — only while player walks (no sideways trail)
local RunService = game:GetService("RunService")

local FireEffects = {}

local FX_PREFIX = "CSFire_"

local GRIP_SKIP = 0.32
local BLADE_SEGMENTS = 12
local RADIAL_OFFSET = 0.14

local FLAME_SIZE_MIN = 1.85
local FLAME_SIZE_MAX = 2.45
local FLAME_HEAT = 7

local MOVE_THRESHOLD = 0.12

local GRIP_ONLY_NAMES: { [string]: boolean } = {
	grip = true,
	hilt = true,
	pommel = true,
}

local FIRE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 130)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 175, 45)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 40, 0)),
})

type SwordFireVisuals = {
	flames: { Fire },
	coats: { ParticleEmitter },
	lights: { PointLight },
}

local motionByTool: { [Tool]: RBXScriptConnection } = {}

local function isFx(inst: Instance): boolean
	return string.sub(inst.Name, 1, #FX_PREFIX) == FX_PREFIX
end

local function getAllBaseParts(tool: Tool): { BasePart }
	local list: { BasePart } = {}
	for _, desc in tool:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(list, desc)
		end
	end
	return list
end

local function isGripOnlyPart(part: BasePart, allParts: { BasePart }): boolean
	if #allParts <= 1 then
		return false
	end

	local lower = string.lower(part.Name)
	if GRIP_ONLY_NAMES[lower] then
		return true
	end

	if lower == "handle" then
		for _, other in allParts do
			if other ~= part then
				local oLower = string.lower(other.Name)
				if oLower ~= "handle" and not GRIP_ONLY_NAMES[oLower] then
					return true
				end
			end
		end
	end

	return false
end

local function getMeshLength(part: BasePart): number
	local size = part.Size
	local length = math.max(size.X, size.Y, size.Z)

	local special = part:FindFirstChildOfClass("SpecialMesh")
	if special then
		local scale = special.Scale
		length *= math.max(scale.X, scale.Y, scale.Z)
	end

	return length
end

local function getBladeAxis(part: BasePart): Vector3
	local size = part.Size
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.new(0, 1, 0)
	end
	if size.Z >= size.X then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end

local function getRadialOffsets(axis: Vector3): { Vector3 }
	if math.abs(axis.Y) > 0.9 then
		return {
			Vector3.new(RADIAL_OFFSET, 0, 0),
			Vector3.new(-RADIAL_OFFSET, 0, 0),
			Vector3.new(0, 0, RADIAL_OFFSET),
			Vector3.new(0, 0, -RADIAL_OFFSET),
		}
	end
	if math.abs(axis.Z) > 0.9 then
		return {
			Vector3.new(RADIAL_OFFSET, 0, 0),
			Vector3.new(-RADIAL_OFFSET, 0, 0),
			Vector3.new(0, RADIAL_OFFSET, 0),
			Vector3.new(0, -RADIAL_OFFSET, 0),
		}
	end
	return {
		Vector3.new(0, RADIAL_OFFSET, 0),
		Vector3.new(0, -RADIAL_OFFSET, 0),
		Vector3.new(0, 0, RADIAL_OFFSET),
		Vector3.new(0, 0, -RADIAL_OFFSET),
	}
end

local function createRealFlame(parent: Instance): Fire
	local flame = Instance.new("Fire")
	flame.Name = FX_PREFIX .. "Flame"
	flame.Size = 0
	flame.Heat = FLAME_HEAT
	flame.Color = Color3.fromRGB(255, 170, 60)
	flame.SecondaryColor = Color3.fromRGB(255, 50, 0)
	flame.Parent = parent
	return flame
end

local function createSymmetricCoat(parent: Instance): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = FX_PREFIX .. "Coat"
	particles.Texture = "rbxasset://textures/particles/fire_main.dds"
	particles.Enabled = false
	particles.Rate = 12
	particles.Lifetime = NumberRange.new(0.12, 0.28)
	particles.Speed = NumberRange.new(0, 0.12)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Drag = 4
	particles.LightEmission = 1
	particles.LightInfluence = 0
	particles.LockedToPart = true
	particles.VelocityInheritance = 0
	particles.Acceleration = Vector3.new(0, 0.35, 0)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Color = FIRE_COLOR
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(0.45, 0.26),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Parent = parent
	return particles
end

local function addSymmetricPoint(
	part: BasePart,
	position: Vector3,
	axis: Vector3,
	visuals: SwordFireVisuals
)
	local center = Instance.new("Attachment")
	center.Name = FX_PREFIX .. "AuraAtt"
	center.Position = position
	center.Parent = part

	table.insert(visuals.flames, createRealFlame(center))
	table.insert(visuals.coats, createSymmetricCoat(center))

	for _, offset in getRadialOffsets(axis) do
		local ring = Instance.new("Attachment")
		ring.Name = FX_PREFIX .. "AuraRing"
		ring.Position = position + offset
		ring.Parent = part
		table.insert(visuals.coats, createSymmetricCoat(ring))
	end
end

local function applyBladeFire(part: BasePart, gripSkip: number, visuals: SwordFireVisuals)
	local axis = getBladeAxis(part)
	local length = getMeshLength(part)
	local half = length / 2

	for i = 0, BLADE_SEGMENTS - 1 do
		local t = gripSkip + (1 - gripSkip) * (i / math.max(BLADE_SEGMENTS - 1, 1))
		addSymmetricPoint(part, axis * (-half + t * length), axis, visuals)
	end

	local light = Instance.new("PointLight")
	light.Name = FX_PREFIX .. "Light"
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Brightness = 0
	light.Range = 8
	light.Parent = part
	table.insert(visuals.lights, light)
end

local function applyMetalPartFire(part: BasePart, visuals: SwordFireVisuals)
	local length = getMeshLength(part)
	local thickness = math.min(part.Size.X, part.Size.Y, part.Size.Z)

	if length > thickness * 1.8 then
		applyBladeFire(part, 0.05, visuals)
		return
	end

	table.insert(visuals.flames, createRealFlame(part))
	table.insert(visuals.coats, createSymmetricCoat(part))

	local light = Instance.new("PointLight")
	light.Name = FX_PREFIX .. "Light"
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Brightness = 0
	light.Range = 7
	light.Parent = part
	table.insert(visuals.lights, light)
end

local function isPlayerMoving(character: Model): (boolean, number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, 0
	end

	local moveAmount = humanoid.MoveDirection.Magnitude
	if moveAmount > MOVE_THRESHOLD then
		return true, math.clamp(moveAmount, 0, 1)
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local speed = root.AssemblyLinearVelocity.Magnitude
		if speed > 2.5 then
			return true, math.clamp(speed / 16, 0, 1)
		end
	end

	return false, 0
end

local function setFireActive(visuals: SwordFireVisuals, active: boolean, moveScale: number)
	local flameSize = FLAME_SIZE_MIN + (FLAME_SIZE_MAX - FLAME_SIZE_MIN) * moveScale
	local coatRate = 10 + 8 * moveScale

	for _, flame in visuals.flames do
		if flame.Parent then
			flame.Size = if active then flameSize else 0
		end
	end

	for _, coat in visuals.coats do
		if coat.Parent then
			coat.Enabled = active
			if active then
				coat.Rate = coatRate
			end
		end
	end

	for _, light in visuals.lights do
		if light.Parent then
			light.Brightness = if active then 0.85 + 0.45 * moveScale else 0
		end
	end
end

local function stopMotionFire(tool: Tool)
	local conn = motionByTool[tool]
	if conn then
		conn:Disconnect()
		motionByTool[tool] = nil
	end
end

local function startMotionFire(tool: Tool, visuals: SwordFireVisuals)
	stopMotionFire(tool)
	setFireActive(visuals, false, 0)

	motionByTool[tool] = RunService.Heartbeat:Connect(function()
		if not tool.Parent or not tool.Parent:IsA("Model") then
			stopMotionFire(tool)
			return
		end

		local moving, moveScale = isPlayerMoving(tool.Parent)
		setFireActive(visuals, moving, moveScale)
	end)
end

function FireEffects.clear(tool: Tool)
	stopMotionFire(tool)

	for _, inst in tool:GetDescendants() do
		if isFx(inst) then
			inst:Destroy()
		end
	end
end

function FireEffects.apply(tool: Tool)
	FireEffects.clear(tool)

	local allParts = getAllBaseParts(tool)
	if #allParts == 0 then
		return
	end

	local metalParts: { BasePart } = {}
	for _, part in allParts do
		if not isGripOnlyPart(part, allParts) then
			table.insert(metalParts, part)
		end
	end

	if #metalParts == 0 then
		metalParts = allParts
	end

	local visuals: SwordFireVisuals = {
		flames = {},
		coats = {},
		lights = {},
	}

	if #allParts == 1 then
		applyBladeFire(allParts[1], GRIP_SKIP, visuals)
	else
		for _, part in metalParts do
			applyMetalPartFire(part, visuals)
		end
	end

	startMotionFire(tool, visuals)
end

return FireEffects
