local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer and localPlayer:GetMouse()
local camera = workspace.CurrentCamera

local enabled = false
local killed = false
local toggleKey = Enum.KeyCode.Y
local killKey = Enum.KeyCode.P
local aimRadius = 180
local minAimRadius = 40
local maxAimRadius = 1000
local espEnabled = true
local DEBUG_LOGS = false

local inputConnection
local aimConnection
local killScript
local uiConnection
local playerAddedConnection
local playerRemovingConnection

local currentTargetPlayer = nil
local currentTargetPart = nil
local currentTargetPosition = nil
local currentCandidateCount = 0

local oldIndex
local oldNamecall
local getNamecallMethod = getnamecallmethod or get_namecall_method
local safeNewCClosure = newcclosure or function(fn) return fn end
local canCheckCaller = type(checkcaller) == "function"

local lastRaycastLogAt = 0
local lastMouseLogAt = 0
local quickShotGui
local radiusValueLabel
local radiusFill
local stateLabel
local espToggleButton
local targetEspGui
local espEntries = {}

local function safeTostring(value)
    local ok, result = pcall(tostring, value)
    return ok and result or "<invalid>"
end

local function concatArgs(...)
    local args = table.pack(...)
    for i = 1, args.n do
        args[i] = safeTostring(args[i])
    end
    return table.concat(args, " ")
end

local function log(...)
    print("[QuickShotFPS]", concatArgs(...))
end

local function problem(...)
    warn("[QuickShotFPS] " .. concatArgs(...))
end

local function stage(name, ...)
    if DEBUG_LOGS then
        log("stage=", name, ...)
    end
end

local function notify(title, text)
    local ok = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2.5,
        })
    end)
    if not ok then
        log(title, text)
    end
end

local function shouldSkipCaller()
    return canCheckCaller and checkcaller()
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function updateUi()
    if radiusValueLabel then
        radiusValueLabel.Text = tostring(math.floor(aimRadius))
    end

    if stateLabel then
        stateLabel.Text = enabled and "ON" or "OFF"
        stateLabel.TextColor3 = enabled and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(255, 170, 170)
    end

    if radiusFill then
        local alpha = (aimRadius - minAimRadius) / (maxAimRadius - minAimRadius)
        radiusFill.Size = UDim2.new(alpha, 0, 1, 0)
    end

    if espToggleButton then
        espToggleButton.Text = espEnabled and "ESP ON" or "ESP OFF"
        espToggleButton.BackgroundColor3 = espEnabled and Color3.fromRGB(95, 34, 34) or Color3.fromRGB(25, 31, 42)
        espToggleButton.TextColor3 = espEnabled and Color3.fromRGB(255, 222, 222) or Color3.fromRGB(235, 241, 255)
    end

end

local function createButton(parent, text, size, position)
    local button = Instance.new("TextButton")
    button.Name = text .. "Button"
    button.Parent = parent
    button.Size = size
    button.Position = position
    button.AutoButtonColor = true
    button.BackgroundColor3 = Color3.fromRGB(25, 31, 42)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(235, 241, 255)
    button.TextSize = 12

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

local function createUi()
    local existing = CoreGui:FindFirstChild("QuickShotFPS_UI")
    if existing then
        existing:Destroy()
    end

    quickShotGui = Instance.new("ScreenGui")
    quickShotGui.Name = "QuickShotFPS_UI"
    quickShotGui.ResetOnSpawn = false
    quickShotGui.IgnoreGuiInset = false
    quickShotGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    quickShotGui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Parent = quickShotGui
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -16, 0, 16)
    frame.Size = UDim2.new(0, 168, 0, 118)
    frame.BackgroundColor3 = Color3.fromRGB(13, 17, 24)
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel = 0

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(58, 71, 96)
    stroke.Transparency = 0.18
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = frame
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 10, 0, 8)
    title.Size = UDim2.new(1, -20, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = "QuickShot"
    title.TextColor3 = Color3.fromRGB(241, 245, 255)
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left

    stateLabel = Instance.new("TextLabel")
    stateLabel.Name = "State"
    stateLabel.Parent = frame
    stateLabel.BackgroundTransparency = 1
    stateLabel.Position = UDim2.new(1, -52, 0, 8)
    stateLabel.Size = UDim2.new(0, 42, 0, 18)
    stateLabel.Font = Enum.Font.GothamBold
    stateLabel.TextSize = 12
    stateLabel.TextXAlignment = Enum.TextXAlignment.Right

    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Name = "RadiusLabel"
    radiusLabel.Parent = frame
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Position = UDim2.new(0, 10, 0, 30)
    radiusLabel.Size = UDim2.new(0, 60, 0, 14)
    radiusLabel.Font = Enum.Font.GothamSemibold
    radiusLabel.Text = "Radius"
    radiusLabel.TextColor3 = Color3.fromRGB(190, 201, 224)
    radiusLabel.TextSize = 11
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left

    radiusValueLabel = Instance.new("TextLabel")
    radiusValueLabel.Name = "RadiusValue"
    radiusValueLabel.Parent = frame
    radiusValueLabel.BackgroundTransparency = 1
    radiusValueLabel.Position = UDim2.new(1, -42, 0, 29)
    radiusValueLabel.Size = UDim2.new(0, 32, 0, 16)
    radiusValueLabel.Font = Enum.Font.GothamBold
    radiusValueLabel.TextColor3 = Color3.fromRGB(238, 243, 255)
    radiusValueLabel.TextSize = 12
    radiusValueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local barBack = Instance.new("Frame")
    barBack.Name = "RadiusBarBack"
    barBack.Parent = frame
    barBack.Position = UDim2.new(0, 10, 0, 50)
    barBack.Size = UDim2.new(1, -20, 0, 8)
    barBack.BackgroundColor3 = Color3.fromRGB(28, 35, 49)
    barBack.BorderSizePixel = 0

    local barBackCorner = Instance.new("UICorner")
    barBackCorner.CornerRadius = UDim.new(1, 0)
    barBackCorner.Parent = barBack

    radiusFill = Instance.new("Frame")
    radiusFill.Name = "RadiusFill"
    radiusFill.Parent = barBack
    radiusFill.Size = UDim2.new(0.5, 0, 1, 0)
    radiusFill.BackgroundColor3 = Color3.fromRGB(111, 217, 255)
    radiusFill.BorderSizePixel = 0

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(1, 0)
    barFillCorner.Parent = radiusFill

    local minusButton = createButton(frame, "-", UDim2.new(0, 26, 0, 22), UDim2.new(0, 10, 0, 62))
    local plusButton = createButton(frame, "+", UDim2.new(0, 26, 0, 22), UDim2.new(1, -36, 0, 62))

    espToggleButton = createButton(frame, "ESP ON", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 88))
    espToggleButton.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        updateUi()
    end)

    local stepLabel = Instance.new("TextLabel")
    stepLabel.Name = "Hint"
    stepLabel.Parent = frame
    stepLabel.BackgroundTransparency = 1
    stepLabel.Position = UDim2.new(0, 42, 0, 64)
    stepLabel.Size = UDim2.new(1, -84, 0, 18)
    stepLabel.Font = Enum.Font.Gotham
    stepLabel.Text = "Y toggle  P kill"
    stepLabel.TextColor3 = Color3.fromRGB(150, 162, 188)
    stepLabel.TextSize = 10

    local function setRadiusFromAlpha(alpha)
        aimRadius = clamp(minAimRadius + (maxAimRadius - minAimRadius) * alpha, minAimRadius, maxAimRadius)
        updateUi()
    end

    minusButton.MouseButton1Click:Connect(function()
        aimRadius = clamp(aimRadius - 15, minAimRadius, maxAimRadius)
        updateUi()
    end)

    plusButton.MouseButton1Click:Connect(function()
        aimRadius = clamp(aimRadius + 15, minAimRadius, maxAimRadius)
        updateUi()
    end)

    local draggingBar = false
    local function applyBarInput(x)
        local alpha = clamp((x - barBack.AbsolutePosition.X) / math.max(barBack.AbsoluteSize.X, 1), 0, 1)
        setRadiusFromAlpha(alpha)
    end

    barBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingBar = true
            applyBarInput(input.Position.X)
        end
    end)

    barBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingBar = false
        end
    end)

    uiConnection = UserInputService.InputChanged:Connect(function(input)
        if draggingBar and input.UserInputType == Enum.UserInputType.MouseMovement then
            applyBarInput(input.Position.X)
        end
    end)

    updateUi()
end

local function createEspEntry(player)
    if not targetEspGui or espEntries[player] then
        return espEntries[player]
    end

    local box = Instance.new("Frame")
    box.Name = player.Name .. "_Box"
    box.Parent = targetEspGui
    box.Visible = false
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(255, 255, 255)
    boxStroke.Thickness = 1.5
    boxStroke.Parent = box

    local info = Instance.new("TextLabel")
    info.Name = player.Name .. "_Info"
    info.Parent = targetEspGui
    info.Visible = false
    info.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
    info.BackgroundTransparency = 1
    info.BorderSizePixel = 0
    info.Size = UDim2.new(0, 170, 0, 34)
    info.Font = Enum.Font.GothamMedium
    info.TextColor3 = Color3.fromRGB(244, 247, 255)
    info.TextSize = 12
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Center

    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 8)
    infoCorner.Parent = info

    local infoStroke = Instance.new("UIStroke")
    infoStroke.Color = Color3.fromRGB(255, 255, 255)
    infoStroke.Thickness = 1
    infoStroke.Transparency = 0.35
    infoStroke.Parent = info

    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name .. "_Highlight"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.78
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = CoreGui

    local entry = {
        box = box,
        boxStroke = boxStroke,
        info = info,
        infoStroke = infoStroke,
        highlight = highlight,
    }
    espEntries[player] = entry
    return entry
end

local function destroyEspEntry(player)
    local entry = espEntries[player]
    if not entry then
        return
    end

    if entry.box then
        entry.box:Destroy()
    end
    if entry.info then
        entry.info:Destroy()
    end
    if entry.highlight then
        entry.highlight:Destroy()
    end
    espEntries[player] = nil
end

local function createEspUi()
    if targetEspGui then
        targetEspGui:Destroy()
    end

    targetEspGui = Instance.new("ScreenGui")
    targetEspGui.Name = "QuickShotFPS_TargetESP"
    targetEspGui.ResetOnSpawn = false
    targetEspGui.IgnoreGuiInset = true
    targetEspGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    targetEspGui.Parent = CoreGui

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createEspEntry(player)
        end
    end
end

local function hideAllEsp()
    for _, entry in pairs(espEntries) do
        entry.box.Visible = false
        entry.info.Visible = false
        entry.highlight.Enabled = false
        entry.highlight.Adornee = nil
    end
end

local function isBasePart(instance)
    local className = instance and instance.ClassName
    return className == "Part"
        or className == "MeshPart"
        or className == "WedgePart"
        or className == "CornerWedgePart"
        or className == "TrussPart"
        or className == "SpawnLocation"
        or className == "Seat"
        or className == "VehicleSeat"
        or className == "UnionOperation"
        or className == "NegateOperation"
end

local function getChildrenSafe(instance)
    local ok, children = pcall(function()
        return instance:GetChildren()
    end)
    if not ok then
        return {}
    end
    return children
end

local function getRootPart(character)
    if not character then
        return nil
    end

    local children = getChildrenSafe(character)
    local fallback = nil

    for i = 1, #children do
        local child = children[i]
        if child.Name == "Head" then
            return child
        end
        if child.Name == "HumanoidRootPart" then
            fallback = fallback or child
        elseif child.Name == "UpperTorso" then
            fallback = fallback or child
        elseif child.Name == "LowerTorso" then
            fallback = fallback or child
        elseif not fallback and isBasePart(child) then
            fallback = child
        end
    end

    return fallback
end

local function getHumanoid(character)
    local children = getChildrenSafe(character)
    for i = 1, #children do
        local child = children[i]
        if child.ClassName == "Humanoid" then
            return child
        end
    end
    return nil
end

local function isValidTarget(player)
    if not player or player == localPlayer then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    local humanoid = getHumanoid(character)
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    return getRootPart(character) ~= nil
end

local function updateAllEsp()
    if not espEnabled or not targetEspGui then
        hideAllEsp()
        return
    end

    local activeCamera = workspace.CurrentCamera or camera
    if not activeCamera then
        hideAllEsp()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local entry = createEspEntry(player)
            local character = player.Character
            local root = character and getRootPart(character)
            local humanoid = character and getHumanoid(character)

            if not entry or not character or not root or not humanoid or humanoid.Health <= 0 then
                if entry then
                    entry.box.Visible = false
                    entry.info.Visible = false
                    entry.highlight.Enabled = false
                    entry.highlight.Adornee = nil
                end
            else
                local isCurrentTarget = player == currentTargetPlayer and enabled
                local accent = isCurrentTarget and Color3.fromRGB(255, 92, 92) or Color3.fromRGB(255, 255, 255)
                local fill = isCurrentTarget and Color3.fromRGB(255, 74, 74) or Color3.fromRGB(255, 255, 255)

                entry.highlight.Adornee = character
                entry.highlight.Enabled = true
                entry.highlight.FillColor = fill
                entry.highlight.FillTransparency = isCurrentTarget and 0.74 or 0.88
                entry.highlight.OutlineColor = accent

                local head = character:FindFirstChild("Head")
                local headPosition = head and head.Position or (root.Position + Vector3.new(0, 2.6, 0))
                local upperPosition = root.Position + Vector3.new(0, 2.85, 0)
                local feetPosition = root.Position - Vector3.new(0, 3.4, 0)
                local headPoint, headVisible = activeCamera:WorldToViewportPoint(headPosition)
                local upperPoint, upperVisible = activeCamera:WorldToViewportPoint(upperPosition)
                local feetPoint, feetVisible = activeCamera:WorldToViewportPoint(feetPosition)
                local rootPoint, rootVisible = activeCamera:WorldToViewportPoint(root.Position)

                if headVisible and upperVisible and feetVisible and rootVisible and rootPoint.Z > 0 then
                    local height = math.max(math.abs(feetPoint.Y - headPoint.Y), 48)
                    local shoulderWidth = math.abs(upperPoint.Y - rootPoint.Y) * 1.65
                    local width = math.max(math.min(height * 0.68, shoulderWidth), 26)
                    local minX = rootPoint.X - width / 2
                    local minY = headPoint.Y - 3
                    local distance = math.floor((root.Position - activeCamera.CFrame.Position).Magnitude + 0.5)
                    local health = math.floor(humanoid.Health + 0.5)

                    entry.box.Visible = true
                    entry.box.Position = UDim2.fromOffset(minX, minY)
                    entry.box.Size = UDim2.fromOffset(width, height)
                    entry.boxStroke.Color = accent

                    entry.info.Visible = true
                    entry.info.Position = UDim2.fromOffset(minX, math.max(minY - 34, 6))
                    entry.info.TextColor3 = accent
                    entry.infoStroke.Color = accent
                    entry.info.Text = string.format("%s%s   HP %d   %dm", isCurrentTarget and "TARGET  " or "", player.Name, health, distance)
                else
                    entry.box.Visible = false
                    entry.info.Visible = false
                end
            end
        end
    end
end

local function getMousePosition()
    if mouse and typeof(mouse.X) == "number" and typeof(mouse.Y) == "number" then
        return Vector2.new(mouse.X, mouse.Y)
    end

    local location = UserInputService:GetMouseLocation()
    return Vector2.new(location.X, location.Y)
end

local function getClosestTargetToMouse()
    local activeCamera = workspace.CurrentCamera or camera
    if not activeCamera then
        return nil, nil, 0
    end
    camera = activeCamera

    local mousePos = getMousePosition()
    local playersList = Players:GetPlayers()
    local bestPlayer = nil
    local bestPart = nil
    local bestDistance = math.huge
    local candidateCount = 0

    for i = 1, #playersList do
        local player = playersList[i]
        if isValidTarget(player) then
            local root = getRootPart(player.Character)
            if root then
                candidateCount = candidateCount + 1
                local ok, viewportPoint = pcall(function()
                    return activeCamera:WorldToViewportPoint(root.Position)
                end)
                if ok and viewportPoint and viewportPoint.Z > 0 then
                    local screenPos = Vector2.new(viewportPoint.X, viewportPoint.Y)
                    local distance = (screenPos - mousePos).Magnitude
                    if distance <= aimRadius and distance < bestDistance then
                        bestDistance = distance
                        bestPlayer = player
                        bestPart = root
                    end
                end
            end
        end
    end

    return bestPlayer, bestPart, candidateCount
end

local function refreshAimCache()
    if killed or not enabled then
        currentTargetPlayer = nil
        currentTargetPart = nil
        currentTargetPosition = nil
        currentCandidateCount = 0
        return
    end

    local ok, bestPlayer, bestPart, candidateCount = pcall(getClosestTargetToMouse)
    if not ok then
        currentTargetPlayer = nil
        currentTargetPart = nil
        currentTargetPosition = nil
        currentCandidateCount = 0
        problem("aim cache refresh error:", bestPlayer)
        hideAllEsp()
        return
    end

    currentTargetPlayer = bestPlayer
    currentTargetPart = bestPart
    currentTargetPosition = bestPart and bestPart.Position or nil
    currentCandidateCount = candidateCount
end

local function logCurrentTarget(prefix)
    if DEBUG_LOGS then
        log(prefix, "candidates=", currentCandidateCount, "target=", currentTargetPlayer and currentTargetPlayer.Name or "nil", "part=", currentTargetPart and currentTargetPart.Name or "nil", "pos=", currentTargetPosition and safeTostring(currentTargetPosition) or "nil")
    end
end

local function shouldLogThrottle(lastAt)
    local now = os.clock()
    if now - lastAt >= 0.35 then
        return true, now
    end
    return false, lastAt
end

killScript = function()
    if killed then
        return
    end

    killed = true
    enabled = false
    currentTargetPlayer = nil
    currentTargetPart = nil
    currentTargetPosition = nil
    currentCandidateCount = 0

    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end

    if uiConnection then
        uiConnection:Disconnect()
        uiConnection = nil
    end

    if quickShotGui then
        quickShotGui:Destroy()
        quickShotGui = nil
    end

    if targetEspGui then
        targetEspGui:Destroy()
        targetEspGui = nil
    end

    if playerAddedConnection then
        playerAddedConnection:Disconnect()
        playerAddedConnection = nil
    end

    if playerRemovingConnection then
        playerRemovingConnection:Disconnect()
        playerRemovingConnection = nil
    end

    for player, _ in pairs(espEntries) do
        destroyEspEntry(player)
    end

    log("QuickShotFPS disabled", "Script killed")
    notify("QuickShotFPS", "Killed")
end

print("[QuickShotFPS] -- NEW SESSION -- v2")
stage("boot", "player=", localPlayer and localPlayer.Name or "nil")
stage("boot", "mouse=", mouse and "ok" or "nil")
stage("boot", "camera=", camera and "ok" or "nil")
stage("boot", "hookmetamethod=", safeTostring(hookmetamethod))
stage("boot", "getnamecallmethod=", safeTostring(getNamecallMethod))
stage("boot", "checkcaller=", safeTostring(checkcaller))
createUi()
createEspUi()
playerAddedConnection = Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        createEspEntry(player)
    end
end)
playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
    destroyEspEntry(player)
end)
notify("QuickShotFPS", "Loaded")

aimConnection = RunService.RenderStepped:Connect(function()
    refreshAimCache()
    updateAllEsp()
end)
stage("connections", "RenderStepped connected")

inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or killed then
        return
    end

    if input.KeyCode == toggleKey then
        enabled = not enabled
        if enabled then
            refreshAimCache()
            logCurrentTarget("toggle-enabled")
        else
            currentTargetPlayer = nil
            currentTargetPart = nil
            currentTargetPosition = nil
            currentCandidateCount = 0
        end
        updateUi()
        log(enabled and "Auto-target enabled" or "Auto-target disabled")
        notify("QuickShotFPS", enabled and "Enabled" or "Disabled")
    elseif input.KeyCode == killKey then
        killScript()
    end
end)
stage("connections", "InputBegan connected", "toggleKey=", tostring(toggleKey), "killKey=", tostring(killKey))

if not hookmetamethod then
    problem("Missing hookmetamethod. This rebuild requires hookmetamethod support.")
    return
end

stage("hook-index", "attempting mouse __index hook")
local indexOk, indexErr = pcall(function()
    oldIndex = hookmetamethod(game, "__index", safeNewCClosure(function(self, key)
        if killed or not enabled or shouldSkipCaller() then
            return oldIndex(self, key)
        end

        if self == mouse then
            if key == "Target" and currentTargetPart then
                local shouldLog, now = shouldLogThrottle(lastMouseLogAt)
                if shouldLog then
                    lastMouseLogAt = now
                end
                return currentTargetPart
            elseif key == "Hit" and typeof(currentTargetPosition) == "Vector3" then
                local shouldLog, now = shouldLogThrottle(lastMouseLogAt)
                if shouldLog then
                    lastMouseLogAt = now
                end
                return CFrame.new(currentTargetPosition)
            elseif key == "UnitRay" and typeof(currentTargetPosition) == "Vector3" then
                local activeCamera = workspace.CurrentCamera or camera
                if activeCamera then
                    local origin = activeCamera.CFrame.Position
                    local delta = currentTargetPosition - origin
                    if delta.Magnitude > 0.001 then
                        local shouldLog, now = shouldLogThrottle(lastMouseLogAt)
                        if shouldLog then
                            lastMouseLogAt = now
                        end
                        return Ray.new(origin, delta.Unit)
                    end
                end
            end
        end

        return oldIndex(self, key)
    end))
end)

if not indexOk then
    problem("Failed mouse __index hook:", indexErr)
    return
end
stage("hook-index", "success=true")

stage("hook-namecall", "attempting workspace Raycast hook")
local namecallOk, namecallErr = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", safeNewCClosure(function(self, ...)
        if killed or not enabled or shouldSkipCaller() then
            return oldNamecall(self, ...)
        end

        local method = getNamecallMethod and getNamecallMethod()
        if self == workspace and method == "Raycast" and typeof(currentTargetPosition) == "Vector3" then
            local args = {...}
            local origin = args[1]
            local direction = args[2]

            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                local desired = currentTargetPosition - origin
                if desired.Magnitude > 0.001 then
                    local rayLength = math.max(desired.Magnitude, direction.Magnitude)
                    local shouldLog, now = shouldLogThrottle(lastRaycastLogAt)
                    if shouldLog then
                        lastRaycastLogAt = now
                    end
                    args[2] = desired.Unit * rayLength
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end))
end)

if not namecallOk then
    problem("Failed workspace Raycast hook:", namecallErr)
    return
end
stage("hook-namecall", "success=true")

log("QuickShotFPS ready", "mode=mouse-spoof+raycast-spoof")
updateUi()
