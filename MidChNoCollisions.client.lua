-- MidChNoCollisions.client.lua
-- 1) Target: workspace.NPCVehicles
-- 2) All BasePart descendants: CanCollide = false, collision group = Default (no custom group)
-- 3) Track added descendants + periodic safety reconciliation
-- 4) Minimal runtime overhead (no expensive loops per frame)

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local workspace = game:GetService("Workspace")

local NPCVehicles = workspace:WaitForChild("NPCVehicles", 10)
if not NPCVehicles then
	warn("MidChNoCollisions: NPCVehicles not found in workspace")
	return
end

-- Inform the player that the script is running
StarterGui:SetCore("SendNotification", {
	Title = "MidChNoCollisions",
	Text = "Script is now active - NPC vehicle collisions disabled.",
	Duration = 5
})

local CLEAN_GROUP_NAME = "Default"

local function applyPartSettings(part)
	if not part or not part:IsA("BasePart") then
		return
	end

	-- make non-collidable
	part.CanCollide = false

	-- assign default collision group
	-- if this fails, skip but do not error.
	local success, err = pcall(function()
		PhysicsService:SetPartCollisionGroup(part, CLEAN_GROUP_NAME)
	end)
	if not success then
		warn("MidChNoCollisions: could not set collision group for", part:GetFullName(), err)
	end
end

local function applyToAllParts(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			applyPartSettings(descendant)
		end
	end
end

-- Handle managed additions under NPCVehicles
NPCVehicles.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		applyPartSettings(descendant)
	end
end)

-- Watch for any model parent changes into NPCVehicles
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant:IsDescendantOf(NPCVehicles) then
		applyPartSettings(descendant)
	end
end)

-- Initial pass
applyToAllParts(NPCVehicles)

-- Safety loop every 5 minutes
spawn(function()
	while true do
		wait(300) -- 5 minutes

		if not NPCVehicles or not NPCVehicles.Parent then
			NPCVehicles = workspace:FindFirstChild("NPCVehicles")
			if not NPCVehicles then
				warn("MidChNoCollisions: NPCVehicles missing during safety check")
				continue
			end
		end

		applyToAllParts(NPCVehicles)
	end
end)
