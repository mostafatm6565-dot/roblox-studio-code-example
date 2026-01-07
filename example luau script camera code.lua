local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local CameraSystem = {}
CameraSystem.__index = CameraSystem

local CONFIG = {
	FOV_DEFAULT = 70,
	FOV_SPRINTING = 80,
	FOV_AIMING = 50,
	CAMERA_OFFSET = Vector3.new(2, 2, 8),
	SMOOTHING_FACTOR = 0.15,
	SHAKE_INTENSITY = 0.5,
	TILT_AMOUNT = 5,
	BOB_FREQUENCY = 8,
	BOB_AMPLITUDE = 0.08
}

function CameraSystem.new()
	local self = setmetatable({}, CameraSystem)
	
	self.currentFOV = CONFIG.FOV_DEFAULT
	self.targetFOV = CONFIG.FOV_DEFAULT
	self.cameraOffset = CONFIG.CAMERA_OFFSET
	self.targetOffset = CONFIG.CAMERA_OFFSET
	self.isSprinting = false
	self.isAiming = false
	self.shake = Vector3.new()
	self.tilt = 0
	self.bobTimer = 0
	self.lastPosition = rootPart.Position
	self.velocity = Vector3.new()
	
	self.keys = {
		[Enum.KeyCode.LeftShift] = false,
		[Enum.KeyCode.Q] = false
	}
	
	return self
end

function CameraSystem:UpdateInput()
	local movementInput = Vector3.new(
		(self.keys[Enum.KeyCode.D] and 1 or 0) - (self.keys[Enum.KeyCode.A] and 1 or 0),
		0,
		(self.keys[Enum.KeyCode.S] and 1 or 0) - (self.keys[Enum.KeyCode.W] and 1 or 0)
	)
	
	self.isSprinting = self.keys[Enum.KeyCode.LeftShift] and movementInput.Magnitude > 0
	self.isAiming = self.keys[Enum.KeyCode.Q]
	
	if self.isSprinting then
		self.targetFOV = CONFIG.FOV_SPRINTING
		humanoid.WalkSpeed = 24
	elseif self.isAiming then
		self.targetFOV = CONFIG.FOV_AIMING
		humanoid.WalkSpeed = 10
	else
		self.targetFOV = CONFIG.FOV_DEFAULT
		humanoid.WalkSpeed = 16
	end
	
	return movementInput
end

function CameraSystem:CalculateVelocity(deltaTime)
	local currentPosition = rootPart.Position
	local displacement = currentPosition - self.lastPosition
	self.velocity = displacement / deltaTime
	self.lastPosition = currentPosition
	
	return self.velocity.Magnitude
end

function CameraSystem:ApplyCameraShake(intensity)
	local random = Random.new()
	local shakeX = (random:NextNumber() - 0.5) * intensity
	local shakeY = (random:NextNumber() - 0.5) * intensity
	local shakeZ = (random:NextNumber() - 0.5) * intensity
	
	self.shake = Vector3.new(shakeX, shakeY, shakeZ)
	
	task.delay(0.1, function()
		self.shake = self.shake:Lerp(Vector3.new(), 0.5)
	end)
end

function CameraSystem:CalculateHeadBob(deltaTime, speed)
	if speed > 2 then
		self.bobTimer = self.bobTimer + deltaTime * CONFIG.BOB_FREQUENCY
		
		local bobX = math.sin(self.bobTimer) * CONFIG.BOB_AMPLITUDE
		local bobY = math.abs(math.cos(self.bobTimer * 2)) * CONFIG.BOB_AMPLITUDE
		
		return Vector3.new(bobX, bobY, 0)
	else
		self.bobTimer = 0
		return Vector3.new()
	end
end

function CameraSystem:CalculateTilt(movementInput)
	local targetTilt = -movementInput.X * CONFIG.TILT_AMOUNT
	self.tilt = self.tilt + (targetTilt - self.tilt) * CONFIG.SMOOTHING_FACTOR
	
	return self.tilt
end

function CameraSystem:SmoothFOVTransition(deltaTime)
	self.currentFOV = self.currentFOV + (self.targetFOV - self.currentFOV) * CONFIG.SMOOTHING_FACTOR
	camera.FieldOfView = self.currentFOV
end

function CameraSystem:UpdateCameraPosition(deltaTime)
	local speed = self:CalculateVelocity(deltaTime)
	local movementInput = self:UpdateInput()
	
	local headBob = self:CalculateHeadBob(deltaTime, speed)
	local tiltAngle = self:CalculateTilt(movementInput)
	
	local cameraPosition = rootPart.CFrame * CFrame.new(self.cameraOffset + headBob + self.shake)
	local lookAtPosition = rootPart.Position + Vector3.new(0, 2, 0)
	
	local cameraCFrame = CFrame.lookAt(cameraPosition.Position, lookAtPosition)
	cameraCFrame = cameraCFrame * CFrame.Angles(0, 0, math.rad(tiltAngle))
	
	camera.CFrame = camera.CFrame:Lerp(cameraCFrame, CONFIG.SMOOTHING_FACTOR)
end

function CameraSystem:Initialize()
	camera.CameraType = Enum.CameraType.Scriptable
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		self.keys[input.KeyCode] = true
		
		if input.KeyCode == Enum.KeyCode.Space and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			self:ApplyCameraShake(CONFIG.SHAKE_INTENSITY)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		self.keys[input.KeyCode] = false
	end)
	
	RunService.RenderStepped:Connect(function(deltaTime)
		self:SmoothFOVTransition(deltaTime)
		self:UpdateCameraPosition(deltaTime)
	end)
end

local ParticleEffectSystem = {}
ParticleEffectSystem.__index = ParticleEffectSystem

function ParticleEffectSystem.new(parent)
	local self = setmetatable({}, ParticleEffectSystem)
	
	self.parent = parent
	self.activeEffects = {}
	self.effectPool = {}
	
	return self
end

function ParticleEffectSystem:CreateParticle(properties)
	local particle = Instance.new("Part")
	particle.Size = properties.size or Vector3.new(0.5, 0.5, 0.5)
	particle.Position = properties.position or Vector3.new()
	particle.Anchored = true
	particle.CanCollide = false
	particle.Material = properties.material or Enum.Material.Neon
	particle.Color = properties.color or Color3.fromRGB(255, 255, 255)
	particle.Transparency = properties.transparency or 0
	particle.Parent = self.parent
	
	return particle
end

function ParticleEffectSystem:EmitBurst(position, count, lifetime)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local radius = math.random(2, 5)
		
		local offsetX = math.cos(angle) * radius
		local offsetZ = math.sin(angle) * radius
		local particlePos = position + Vector3.new(offsetX, math.random(0, 2), offsetZ)
		
		local particle = self:CreateParticle({
			position = particlePos,
			size = Vector3.new(0.3, 0.3, 0.3),
			color = Color3.fromHSV(math.random(), 1, 1),
			transparency = 0.3
		})
		
		table.insert(self.activeEffects, particle)
		
		local tweenInfo = TweenInfo.new(
			lifetime or 1,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		
		local tween = TweenService:Create(particle, tweenInfo, {
			Position = particlePos + Vector3.new(0, 5, 0),
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1)
		})
		
		tween:Play()
		
		tween.Completed:Connect(function()
			particle:Destroy()
			local index = table.find(self.activeEffects, particle)
			if index then
				table.remove(self.activeEffects, index)
			end
		end)
	end
end

function ParticleEffectSystem:Cleanup()
	for _, effect in ipairs(self.activeEffects) do
		if effect and effect.Parent then
			effect:Destroy()
		end
	end
	self.activeEffects = {}
end

local MovementTracker = {}
MovementTracker.__index = MovementTracker

function MovementTracker.new(humanoidRootPart)
	local self = setmetatable({}, MovementTracker)
	
	self.rootPart = humanoidRootPart
	self.positionHistory = {}
	self.maxHistorySize = 60
	self.distanceTraveled = 0
	
	return self
end

function MovementTracker:RecordPosition()
	local currentPos = self.rootPart.Position
	
	table.insert(self.positionHistory, {
		position = currentPos,
		timestamp = tick()
	})
	
	if #self.positionHistory > self.maxHistorySize then
		table.remove(self.positionHistory, 1)
	end
	
	if #self.positionHistory > 1 then
		local lastPos = self.positionHistory[#self.positionHistory - 1].position
		self.distanceTraveled = self.distanceTraveled + (currentPos - lastPos).Magnitude
	end
end

function MovementTracker:GetAverageSpeed(timeWindow)
	if #self.positionHistory < 2 then return 0 end
	
	local currentTime = tick()
	local relevantPositions = {}
	
	for i = #self.positionHistory, 1, -1 do
		local entry = self.positionHistory[i]
		if currentTime - entry.timestamp <= timeWindow then
			table.insert(relevantPositions, entry.position)
		else
			break
		end
	end
	
	if #relevantPositions < 2 then return 0 end
	
	local totalDistance = 0
	for i = 2, #relevantPositions do
		totalDistance = totalDistance + (relevantPositions[i] - relevantPositions[i-1]).Magnitude
	end
	
	return totalDistance / timeWindow
end

function MovementTracker:GetTotalDistance()
	return self.distanceTraveled
end

function MovementTracker:PredictNextPosition(deltaTime)
	if #self.positionHistory < 2 then
		return self.rootPart.Position
	end
	
	local recentPositions = {}
	for i = math.max(1, #self.positionHistory - 5), #self.positionHistory do
		table.insert(recentPositions, self.positionHistory[i].position)
	end
	
	local avgVelocity = Vector3.new()
	for i = 2, #recentPositions do
		avgVelocity = avgVelocity + (recentPositions[i] - recentPositions[i-1])
	end
	avgVelocity = avgVelocity / (#recentPositions - 1)
	
	return self.rootPart.Position + (avgVelocity * deltaTime * 60)
end

local cameraSystem = CameraSystem.new()
cameraSystem:Initialize()

local particleSystem = ParticleEffectSystem.new(workspace)
local movementTracker = MovementTracker.new(rootPart)

local lastParticleTime = 0
local particleInterval = 3

RunService.Heartbeat:Connect(function(deltaTime)
	movementTracker:RecordPosition()
	
	local currentTime = tick()
	local avgSpeed = movementTracker:GetAverageSpeed(1)
	
	if avgSpeed > 15 and currentTime - lastParticleTime >= particleInterval then
		particleSystem:EmitBurst(rootPart.Position, 12, 1.5)
		lastParticleTime = currentTime
	end
end)

player.CharacterRemoving:Connect(function()
	particleSystem:Cleanup()
end)
