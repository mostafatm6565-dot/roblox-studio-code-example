-- Gravity Ball Launcher Demo Script 
--pls i need this skill role 

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Ball template
local BallTemplate = Instance.new("Part")
BallTemplate.Shape = Enum.PartType.Ball
BallTemplate.Size = Vector3.new(2,2,2)
BallTemplate.Anchored = false
BallTemplate.CanCollide = true
BallTemplate.Material = Enum.Material.Neon
BallTemplate.Color = Color3.fromRGB(255, 0, 0)

-- Launcher part
local Launcher = Instance.new("Part")
Launcher.Size = Vector3.new(4,1,4)
Launcher.Anchored = true
Launcher.Position = Vector3.new(0,5,0)
Launcher.Name = "Launcher"
Launcher.Material = Enum.Material.Metal
Launcher.Parent = Workspace

-- Remote for firing balls
local FireEvent = Instance.new("RemoteEvent")
FireEvent.Name = "FireBall"
FireEvent.Parent = ReplicatedStorage

-- Table to keep track of active balls
local ActiveBalls = {}

-- Function to create a new ball
local function createBall(position, direction)
	local ball = BallTemplate:Clone()
	ball.Position = position
	ball.Velocity = direction * 50
	ball.Parent = Workspace
	table.insert(ActiveBalls, ball)
end

-- Function to remove old balls
local function cleanupBalls()
	for i = #ActiveBalls, 1, -1 do
		local ball = ActiveBalls[i]
		if not ball or not ball.Parent then
			table.remove(ActiveBalls, i)
		elseif ball.Position.Y < -10 then
			ball:Destroy()
			table.remove(ActiveBalls, i)
		end
	end
end

-- Function to handle firing from a player
local function onFire(player)
	if not player.Character then return end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local launchPos = Launcher.Position + Vector3.new(0, 3, 0)
	local direction = (root.Position - launchPos).Unit
	createBall(launchPos, direction)
end

-- Connect the remote event
FireEvent.OnServerEvent:Connect(onFire)

-- Function to allow click detection for demo
local ClickDetector = Instance.new("ClickDetector")
ClickDetector.MaxActivationDistance = 20
ClickDetector.Parent = Launcher

ClickDetector.MouseClick:Connect(function(player)
	FireEvent:FireServer(player)
end)

-- Update loop for balls
RunService.Heartbeat:Connect(function(deltaTime)
	cleanupBalls()
	-- Apply simple gravity
	for _, ball in ipairs(ActiveBalls) do
		if ball and ball.Parent then
			ball.Velocity = ball.Velocity + Vector3.new(0, -196.2*deltaTime, 0)
		end
	end
end)

-- Simple demo: spawn multiple balls automatically
local spawnTimer = 0
RunService.Heartbeat:Connect(function(deltaTime)
	spawnTimer = spawnTimer + deltaTime
	if spawnTimer >= 2 then
		local randomDir = Vector3.new(math.random(-10,10), math.random(5,15), math.random(-10,10)).Unit
		createBall(Launcher.Position + Vector3.new(0,3,0), randomDir)
		spawnTimer = 0
	end
end)

-- Add a simple visual effect to balls
local function addTrail(ball)
	local trail = Instance.new("Trail")
	trail.Attachment0 = Instance.new("Attachment", ball)
	trail.Attachment1 = Instance.new("Attachment", ball)
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(ball.Color)
	trail.Parent = ball
end

-- Connect trail for new balls
RunService.Heartbeat:Connect(function()
	for _, ball in ipairs(ActiveBalls) do
		if ball and not ball:FindFirstChild("Trail") then
			addTrail(ball)
		end
	end
end)

-- Function to apply random spin to balls
local function applySpin(ball)
	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.AngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * 5
	bodyAngularVelocity.MaxTorque = Vector3.new(400000,400000,400000)
	bodyAngularVelocity.Parent = ball
end

-- Connect spin to new balls
RunService.Heartbeat:Connect(function()
	for _, ball in ipairs(ActiveBalls) do
		if ball and not ball:FindFirstChild("BodyAngularVelocity") then
			applySpin(ball)
		end
	end
end)


