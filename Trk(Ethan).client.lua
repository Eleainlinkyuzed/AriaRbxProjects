-- Command WalkFling Script
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local flingSpeed = 10000
local flingActive = false
local RunService = game:GetService("RunService")

-- Listen for chat commands
player.Chatted:Connect(function(msg)
    if msg:lower() == "/trkstart" then 
        if not flingActive then
            flingActive = true
            print("WalkFling Activated!")
            
            -- Start fling loop
            spawn(function()
                while flingActive do
                    local character = player.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    
                    if character and character.Parent and root and root.Parent then
                        local vel = root.Velocity
                        local movel = 0.1
                        
                        -- Apply extreme velocity to fling others via collision
                        root.Velocity = vel * flingSpeed + Vector3.new(0, flingSpeed, 0)
                        
                        RunService.RenderStepped:Wait()
                        -- Restore velocity so local player doesn't get flung
                        if character and character.Parent and root and root.Parent then
                            root.Velocity = vel
                        end
                        
                        RunService.Stepped:Wait()
                        -- Add slight alternating movement to keep momentum
                        if character and character.Parent and root and root.Parent then
                            root.Velocity = vel + Vector3.new(0, movel, 0)
                            movel = movel * -1
                        end
                    end
                    
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    elseif msg:lower() == "/trkstop" then 
        flingActive = false
        print("WalkFling Deactivated!")
    end
end)