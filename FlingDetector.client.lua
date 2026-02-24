-- Standalone Fling Detector
-- Made by Aria (extracted from AVA)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local detectorActive = false
local detectorConnection = nil
local threshold = 1500 -- velocity-change threshold to consider a fling

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 2})
    end)
end

local function highlightPlayer(targetCharacter, colorType)
    if not targetCharacter or not targetCharacter.Parent then return end

    local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Remove existing highlight
    local existing = targetCharacter:FindFirstChild("FlingHighlight")
    if existing then
        existing:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "FlingHighlight"
    highlight.Adornee = targetCharacter
    highlight.OutlineTransparency = 0
    highlight.FillTransparency = 0.7

    if colorType == "red" then
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
    else
        highlight.OutlineColor = Color3.fromRGB(0, 0, 255)
        highlight.FillColor = Color3.fromRGB(0, 0, 255)
    end

    highlight.Parent = targetCharacter
end

local function cleanupPlayer(playerObj)
    if not playerObj or not playerObj.Character then return end
    local h = playerObj.Character:FindFirstChild("FlingHighlight")
    if h then h:Destroy() end
end

local function startDetector()
    if detectorActive then return end
    detectorActive = true
    notify("Fling Detector", "On")
    print("Fling Detector Activated - Monitoring for flingers!")

    local playerData = {}

    detectorConnection = RunService.Heartbeat:Connect(function()
        if not detectorActive then return end

        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == player then
                -- skip local player
                if playerData[pl] then
                    playerData[pl] = nil
                end
            else
                local char = pl.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp or not hrp.Parent then
                    if playerData[pl] then
                        cleanupPlayer(pl)
                        playerData[pl] = nil
                    end
                else
                    -- init data
                    if not playerData[pl] then
                        playerData[pl] = { lastVelocity = hrp.Velocity, isFlinging = false }
                    end

                    local data = playerData[pl]
                    local curVel = hrp.Velocity
                    local velChange = (curVel - data.lastVelocity).Magnitude

                    if velChange > threshold then
                        if not data.isFlinging then
                            data.isFlinging = true
                            highlightPlayer(char, "red")
                            print("FLINGER ACTIVE: " .. pl.Name .. " (vel change: " .. math.floor(velChange) .. ")")
                        end
                    else
                        if data.isFlinging and curVel.Magnitude < 100 then
                            data.isFlinging = false
                            highlightPlayer(char, "blue")
                            print("FLINGER MARKED DANGEROUS: " .. pl.Name)
                        end
                    end

                    data.lastVelocity = curVel
                end
            end
        end
    end)
end

local function stopDetector()
    if not detectorActive then
        notify("Fling Detector", "Not active")
        return
    end
    detectorActive = false
    if detectorConnection then
        detectorConnection:Disconnect()
        detectorConnection = nil
    end

    -- remove highlights
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and pl.Character then
            local h = pl.Character:FindFirstChild("FlingHighlight")
            if h then h:Destroy() end
        end
    end

    notify("Fling Detector", "Off")
    print("Fling Detector Deactivated!")
end

-- Chat commands: /detectorstart and /detectorstop
player.Chatted:Connect(function(msg)
    local m = msg:lower()
    if m == "/detectorstart" then
        startDetector()
    elseif m == "/detectorstop" then
        stopDetector()
    end
end)

print("Standalone Fling Detector loaded. Use /detectorstart and /detectorstop.")
