--// AUTO FARM PRO - DEPTH INCREMENTAL UI UPDATE
--// LocalScript / executor-compatible client script
--// Flight movement loop retained from the original uploaded script.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- SETTINGS
local farmSpeed = 40
local flightSpeed = 55
local walkSpeed = 32
local MIN_SPEED, MAX_SPEED, SPEED_STEP = 10, 200, 5
local MAX_FLIGHT_SPEED = 250

local waypoints = {}
local running, flying, noclip = false, false, false
local infiniteJump, autoFarm = false, false
local movementMode = "Teleport" -- "Teleport" or "Walk"
local destroyed = false

local character, humanoid, rootPart
local currentTween, flightVelocity, flightGyro, flightConnection, noclipConnection
local originalCollision = {}
local connections = {}
local historyRefresh

local function updateCharacter()
    character = player.Character
    if not character then return end
    humanoid = character:FindFirstChildOfClass("Humanoid")
    rootPart = character:FindFirstChild("HumanoidRootPart")
end

updateCharacter()
player.CharacterAdded:Connect(function()
    task.wait(0.8)
    updateCharacter()
    if humanoid then humanoid.WalkSpeed = walkSpeed end
end)

local function track(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmPro"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

local function outline(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(70, 90, 130)
    s.Thickness = thickness or 1
    s.Parent = obj
end

local function label(parent, text, size, pos, fontSize)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Size, x.Position = size, pos
    x.Text = text
    x.TextColor3 = Color3.fromRGB(235, 240, 255)
    x.Font = Enum.Font.GothamBold
    x.TextSize = fontSize or 12
    x.TextWrapped = true
    x.Parent = parent
    return x
end

local function button(parent, text, height, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, height or 34)
    b.BackgroundColor3 = color or Color3.fromRGB(43, 54, 77)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(245, 248, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = true
    b.Parent = parent
    round(b, 8)
    return b
end

local toast = label(gui, "", UDim2.fromOffset(280, 36), UDim2.new(0.5, -140, 0.9, 0), 12)
toast.BackgroundColor3 = Color3.fromRGB(25, 38, 55)
toast.BackgroundTransparency = 0.05
toast.Visible = false
toast.ZIndex = 30
round(toast, 8)
local toastToken = 0
local function notify(msg)
    toastToken += 1
    local token = toastToken
    toast.Text = msg
    toast.Visible = true
    task.delay(2.5, function()
        if toastToken == token and toast.Parent then toast.Visible = false end
    end)
end

-- MAIN PANEL
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 300, 0.78, 0)
main.Position = UDim2.new(0.5, -150, 0.11, 0)
main.BackgroundColor3 = Color3.fromRGB(17, 21, 32)
main.BorderSizePixel = 0
main.Parent = gui
round(main, 12)
outline(main, Color3.fromRGB(65, 85, 125), 1.4)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(25, 32, 48)
header.BorderSizePixel = 0
header.Parent = main
round(header, 10)
label(header, "AUTO FARM PRO", UDim2.new(1, -112, 1, 0), UDim2.fromOffset(12, 0), 14).TextXAlignment = Enum.TextXAlignment.Left

local lockButton = Instance.new("TextButton")
lockButton.Size = UDim2.fromOffset(34, 28)
lockButton.Position = UDim2.new(1, -78, 0, 7)
lockButton.Text = "🔓"
lockButton.TextSize = 15
lockButton.Parent = header
round(lockButton, 7)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(34, 28)
closeButton.Position = UDim2.new(1, -39, 0, 7)
closeButton.Text = "×"
closeButton.TextSize = 20
closeButton.BackgroundColor3 = Color3.fromRGB(130, 43, 49)
closeButton.TextColor3 = Color3.new(1,1,1)
closeButton.Parent = header
round(closeButton, 7)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -14, 1, -52)
scroll.Position = UDim2.fromOffset(7, 47)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = main

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 7)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = scroll

local mainPad = Instance.new("UIPadding")
mainPad.PaddingTop = UDim.new(0, 3)
mainPad.PaddingBottom = UDim.new(0, 2)
mainPad.PaddingLeft = UDim.new(0, 2)
mainPad.PaddingRight = UDim.new(0, 2)
mainPad.Parent = scroll

local function fitMainToContent()
    task.defer(function()
        if not main or not main.Parent then return end
        local maxHeight = math.max(260, gui.AbsoluteSize.Y * 0.78)
        local contentHeight = mainLayout.AbsoluteContentSize.Y + 10
        local scrollHeight = math.min(contentHeight, maxHeight - 52)
        scroll.Size = UDim2.new(1, -14, 0, scrollHeight)
        main.Size = UDim2.fromOffset(300, scrollHeight + 52)
    end)
end
mainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitMainToContent)

-- Each category is a vertical expandable row; arrow opens its details.
local function makeSection(titleText)
    local section = Instance.new("Frame")
    section.BackgroundTransparency = 1
    section.Size = UDim2.new(1, 0, 0, 38)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = scroll

    local head = Instance.new("TextButton")
    head.Size = UDim2.new(1, 0, 0, 38)
    head.BackgroundColor3 = Color3.fromRGB(32, 42, 62)
    head.Text = "›   " .. titleText
    head.TextColor3 = Color3.fromRGB(245, 248, 255)
    head.Font = Enum.Font.GothamBold
    head.TextSize = 13
    head.TextXAlignment = Enum.TextXAlignment.Left
    head.Parent = section
    round(head, 8)

    local details = Instance.new("Frame")
    details.Size = UDim2.new(1, 0, 0, 0)
    details.Position = UDim2.fromOffset(0, 42)
    details.BackgroundTransparency = 1
    details.Visible = false
    details.AutomaticSize = Enum.AutomaticSize.Y
    details.Parent = section

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = details

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.PaddingLeft = UDim.new(0, 3)
    pad.PaddingRight = UDim.new(0, 3)
    pad.Parent = details

    local opened = false
    local function resizeSection()
        section.Size = UDim2.new(1, 0, 0, opened and (42 + layout.AbsoluteContentSize.Y + 6) or 38)
        task.defer(function()
            if section.Parent then
                section.Size = UDim2.new(1, 0, 0, opened and (42 + layout.AbsoluteContentSize.Y + 6) or 38)
                task.defer(function()
                    if main and main.Parent then
                        local maxHeight = math.max(260, gui.AbsoluteSize.Y * 0.78)
                        local contentHeight = mainLayout.AbsoluteContentSize.Y + 10
                        local scrollHeight = math.min(contentHeight, maxHeight - 52)
                        scroll.Size = UDim2.new(1, -14, 0, scrollHeight)
                        main.Size = UDim2.fromOffset(300, scrollHeight + 52)
                    end
                end)
            end
        end)
    end
    head.MouseButton1Click:Connect(function()
        opened = not opened
        details.Visible = opened
        head.Text = (opened and "⌄   " or "›   ") .. titleText
        resizeSection()
    end)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if opened then resizeSection() end
    end)

    return details
end

local function addButton(parent, text, callback, color)
    local b = button(parent, text, 35, color)
    b.MouseButton1Click:Connect(callback)
    return b
end

-- SIDE HISTORY PANEL (separate from main menu)
local history = Instance.new("Frame")
history.Name = "LocationHistory"
history.Size = UDim2.fromOffset(205, 250)
history.Position = UDim2.new(0.5, -365, 0.28, 0)
history.BackgroundColor3 = Color3.fromRGB(18, 24, 37)
history.BorderSizePixel = 0
history.Visible = false
history.Parent = gui
round(history, 10)
outline(history)

local historyHeader = Instance.new("TextButton")
historyHeader.Size = UDim2.new(1, -12, 0, 30)
historyHeader.Position = UDim2.fromOffset(6, 4)
historyHeader.BackgroundColor3 = Color3.fromRGB(27, 37, 55)
historyHeader.Text = "SAVED LOCATIONS  •  DRAG"
historyHeader.TextColor3 = Color3.fromRGB(235, 240, 255)
historyHeader.Font = Enum.Font.GothamBold
historyHeader.TextSize = 11
historyHeader.Parent = history
round(historyHeader, 7)
local historyScroll = Instance.new("ScrollingFrame")
historyScroll.Size = UDim2.new(1, -12, 1, -46)
historyScroll.Position = UDim2.fromOffset(6, 40)
historyScroll.BackgroundTransparency = 1
historyScroll.BorderSizePixel = 0
historyScroll.ScrollBarThickness = 4
historyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
historyScroll.Parent = history
local historyLayout = Instance.new("UIListLayout")
historyLayout.Padding = UDim.new(0, 4)
historyLayout.Parent = historyScroll

local function refreshHistory()
    for _, child in ipairs(historyScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    if #waypoints == 0 then
        local empty = label(historyScroll, "No saved locations yet", UDim2.new(1, -4, 0, 32), UDim2.new(), 11)
        empty.TextColor3 = Color3.fromRGB(170, 180, 200)
        return
    end
    for i, pos in ipairs(waypoints) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 48)
        row.BackgroundColor3 = Color3.fromRGB(35, 45, 64)
        row.BorderSizePixel = 0
        row.Parent = historyScroll
        round(row, 6)
        local info = label(row,
            string.format("#%d  X %.1f | Y %.1f | Z %.1f", i, pos.X, pos.Y, pos.Z),
            UDim2.new(1, -42, 1, 0), UDim2.fromOffset(6, 0), 9)
        info.TextXAlignment = Enum.TextXAlignment.Left
        local del = Instance.new("TextButton")
        del.Size = UDim2.fromOffset(30, 30)
        del.Position = UDim2.new(1, -34, 0.5, -15)
        del.Text = "×"
        del.TextColor3 = Color3.new(1,1,1)
        del.BackgroundColor3 = Color3.fromRGB(130, 43, 49)
        del.Parent = row
        round(del, 6)
        del.MouseButton1Click:Connect(function()
            table.remove(waypoints, i)
            refreshHistory()
            notify("Location removed")
        end)
    end
end
historyRefresh = refreshHistory

-- WAYPOINTS + MODE
local waypointSection = makeSection("WAYPOINTS / LOCATION HISTORY")
addButton(waypointSection, "+ SAVE CURRENT LOCATION", function()
    updateCharacter()
    if not rootPart then notify("Character not found") return end
    table.insert(waypoints, rootPart.Position)
    refreshHistory()
    notify("Saved location #" .. #waypoints)
end, Color3.fromRGB(42, 100, 76))

local historyToggle
historyToggle = addButton(waypointSection, "OPEN / CLOSE LOCATION HISTORY", function()
    history.Visible = not history.Visible
    if history.Visible then refreshHistory() end
end)

local teleportModeButton, walkModeButton
local function setMovementMode(mode)
    movementMode = mode
    teleportModeButton.BackgroundColor3 = mode == "Teleport" and Color3.fromRGB(38, 115, 75) or Color3.fromRGB(43, 54, 77)
    walkModeButton.BackgroundColor3 = mode == "Walk" and Color3.fromRGB(38, 115, 75) or Color3.fromRGB(43, 54, 77)
    notify("Movement mode: " .. mode)
end
teleportModeButton = addButton(waypointSection, "TELEPORT (INSTANT)", function() setMovementMode("Teleport") end)
walkModeButton = addButton(waypointSection, "WALK TO TARGET", function() setMovementMode("Walk") end)
teleportModeButton.BackgroundColor3 = Color3.fromRGB(38, 115, 75)

local function stopFarm()
    running = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function moveToPosition(position, speed)
    updateCharacter()
    if not rootPart or not humanoid then return false end
    if movementMode == "Teleport" then
        rootPart.CFrame = CFrame.new(position)
        return true
    end

    local distance = (rootPart.Position - position).Magnitude
    humanoid.WalkSpeed = speed or walkSpeed
    humanoid:MoveTo(position)
    local started = os.clock()
    while running and os.clock() - started < math.max(distance / math.max(walkSpeed, 1) + 3, 5) do
        if not rootPart or (rootPart.Position - position).Magnitude < 4 then return true end
        task.wait(0.12)
    end
    return rootPart and (rootPart.Position - position).Magnitude < 6
end

local startWaypointFarm
local startButton = addButton(waypointSection, "START WAYPOINT FARM", function()
    if running then notify("Already running") return end
    updateCharacter()
    if not rootPart or #waypoints == 0 then notify("Save at least one location first") return end
    if flying then notify("Turn off flight before farming") return end
    running = true
    task.spawn(function()
        while running and not destroyed do
            for _, pos in ipairs(waypoints) do
                if not running or destroyed then break end
                moveToPosition(pos, farmSpeed)
                task.wait(0.15)
            end
            task.wait(0.1)
        end
    end)
end, Color3.fromRGB(38, 115, 75))
addButton(waypointSection, "STOP WAYPOINT FARM", stopFarm, Color3.fromRGB(130, 43, 49))

-- FLIGHT (original movement loop retained)
local flightSection = makeSection("FLIGHT")
local flightToggle
flightToggle = addButton(flightSection, "FLIGHT: OFF", function()
    if flying then
        flying = false
        if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
        if flightVelocity then flightVelocity:Destroy(); flightVelocity = nil end
        if flightGyro then flightGyro:Destroy(); flightGyro = nil end
        if humanoid then humanoid.AutoRotate = true end
        flightToggle.Text = "FLIGHT: OFF"
        flightToggle.BackgroundColor3 = Color3.fromRGB(130, 43, 49)
        return
    end
    updateCharacter()
    if not rootPart or not humanoid then notify("Character not found"); return end
    if running then stopFarm() end
    flying = true
    humanoid.AutoRotate = false
    flightVelocity = Instance.new("BodyVelocity")
    flightVelocity.Name = "AF_FlightVelocity"
    flightVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flightVelocity.P = 15000
    flightVelocity.Velocity = Vector3.zero
    flightVelocity.Parent = rootPart
    flightGyro = Instance.new("BodyGyro")
    flightGyro.Name = "AF_FlightGyro"
    flightGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flightGyro.P = 12000
    flightGyro.D = 700
    flightGyro.CFrame = rootPart.CFrame
    flightGyro.Parent = rootPart
    flightConnection = RunService.Heartbeat:Connect(function()
        if not flying or not rootPart or not humanoid then
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local cameraCF = camera.CFrame
        local moveDirection = humanoid.MoveDirection

        -- Camera's horizontal forward and right directions
        local flatForward = Vector3.new(
            cameraCF.LookVector.X,
            0,
            cameraCF.LookVector.Z
        )

        if flatForward.Magnitude < 0.001 then
            flatForward = Vector3.new(
                rootPart.CFrame.LookVector.X,
                0,
                rootPart.CFrame.LookVector.Z
            )
        end

        flatForward = flatForward.Unit

        local flatRight = Vector3.new(
            cameraCF.RightVector.X,
            0,
            cameraCF.RightVector.Z
        )

        if flatRight.Magnitude < 0.001 then
            flatRight = Vector3.new(1, 0, 0)
        end

        flatRight = flatRight.Unit

        -- Convert joystick movement into camera-relative inputs
        local forwardInput = moveDirection:Dot(flatForward)
        local rightInput = moveDirection:Dot(flatRight)

        local direction =
            cameraCF.LookVector * forwardInput
            + flatRight * rightInput

        -- No joystick input = hover in place
        if direction.Magnitude > 0.05 then
            flightVelocity.Velocity = direction.Unit * flightSpeed
        else
            flightVelocity.Velocity = Vector3.zero
        end

        -- Face camera's horizontal direction
        local faceDirection = flatForward
        flightGyro.CFrame = CFrame.lookAt(
            rootPart.Position,
            rootPart.Position + faceDirection
        )
    end)

    flightToggle.Text = "FLIGHT: ON"
    flightToggle.BackgroundColor3 = Color3.fromRGB(38, 115, 75)
end, Color3.fromRGB(130, 43, 49))

addButton(flightSection, "FLIGHT SPEED +", function()
    flightSpeed = math.min(MAX_FLIGHT_SPEED, flightSpeed + SPEED_STEP)
    notify("Flight speed: " .. flightSpeed)
end)
addButton(flightSection, "FLIGHT SPEED -", function()
    flightSpeed = math.max(MIN_SPEED, flightSpeed - SPEED_STEP)
    notify("Flight speed: " .. flightSpeed)
end)

-- MOVEMENT / NOCLIP / JUMP / WALK SPEED
local movementSection = makeSection("MOVEMENT / NOCLIP / JUMP")
local noclipButton
noclipButton = addButton(movementSection, "WALL PASS: OFF", function()
    if noclip then
        noclip = false
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        for part, old in pairs(originalCollision) do
            if part and part.Parent then part.CanCollide = old end
        end
        table.clear(originalCollision)
        noclipButton.Text = "WALL PASS: OFF"
        noclipButton.BackgroundColor3 = Color3.fromRGB(43, 54, 77)
    else
        updateCharacter()
        if not character then notify("Character not found"); return end
        noclip = true
        noclipConnection = RunService.Stepped:Connect(function()
            updateCharacter()
            if not noclip or not character then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if originalCollision[part] == nil then originalCollision[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        end)
        noclipButton.Text = "WALL PASS: ON"
        noclipButton.BackgroundColor3 = Color3.fromRGB(38, 115, 75)
    end
end)
noclipButton.Size = UDim2.new(1, 0, 0, 52)
noclipButton.TextSize = 17

local jumpButton
jumpButton = addButton(movementSection, "INFINITE JUMP: OFF", function()
    infiniteJump = not infiniteJump
    jumpButton.Text = infiniteJump and "INFINITE JUMP: ON" or "INFINITE JUMP: OFF"
    jumpButton.BackgroundColor3 = infiniteJump and Color3.fromRGB(38, 115, 75) or Color3.fromRGB(43, 54, 77)
end)
track(UserInputService.JumpRequest, function()
    if infiniteJump and not destroyed then
        updateCharacter()
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

addButton(movementSection, "WALK SPEED +", function()
    walkSpeed = math.min(MAX_SPEED, walkSpeed + SPEED_STEP)
    updateCharacter()
    if humanoid then humanoid.WalkSpeed = walkSpeed end
    notify("Walk speed: " .. walkSpeed)
end)
addButton(movementSection, "WALK SPEED -", function()
    walkSpeed = math.max(MIN_SPEED, walkSpeed - SPEED_STEP)
    updateCharacter()
    if humanoid then humanoid.WalkSpeed = walkSpeed end
    notify("Walk speed: " .. walkSpeed)
end)

-- DEPTH INCREMENTAL: detect the large circular yellow reward pad dynamically.
-- The detector intentionally rejects small yellow props and narrow decorations.
local function getPadMetrics(part)
    local size = part.Size
    local axes = {
        {vertical = math.abs(part.CFrame.RightVector.Y), thickness = size.X, width = size.Y, depth = size.Z},
        {vertical = math.abs(part.CFrame.UpVector.Y), thickness = size.Y, width = size.X, depth = size.Z},
        {vertical = math.abs(part.CFrame.LookVector.Y), thickness = size.Z, width = size.X, depth = size.Y},
    }
    local best = axes[1]
    for i = 2, #axes do
        if axes[i].vertical > best.vertical then best = axes[i] end
    end
    return best.width, best.depth, best.thickness, best.vertical
end

local function isYellowRewardPad(part)
    if not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then return false end
    if character and part:IsDescendantOf(character) then return false end
    if part.Transparency > 0.35 then return false end

    local c = part.Color
    local brightYellow = c.R >= 0.78 and c.G >= 0.62 and c.B <= 0.38
        and (c.R - c.B) >= 0.42 and (c.G - c.B) >= 0.28
    if not brightYellow then return false end

    local width, depth, thickness, verticalAlignment = getPadMetrics(part)
    local wide = math.max(width, depth)
    local narrow = math.min(width, depth)
    if wide < 12 or wide > 180 or narrow < 12 then return false end
    local roundFootprint = narrow / wide >= 0.72
    local flatDisc = thickness <= narrow * 0.32 and verticalAlignment >= 0.72
    if not roundFootprint or not flatDisc then return false end

    local isDisc = false
    pcall(function() isDisc = part:IsA("Part") and part.Shape == Enum.PartType.Cylinder end)
    local isMeshLike = part:IsA("MeshPart") or part:IsA("UnionOperation")
    return isDisc or isMeshLike or roundFootprint
end

local function findYellowTarget()
    updateCharacter()
    if not rootPart then return nil end
    local best, bestScore = nil, -math.huge
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("BasePart") and isYellowRewardPad(item) then
            local width, depth = getPadMetrics(item)
            local area = width * depth
            local distance = (item.Position - rootPart.Position).Magnitude
            -- Large circular pads score higher; distance breaks close ties.
            local score = area - distance * 0.18
            if item:IsA("Part") and item.Shape == Enum.PartType.Cylinder then score += 900 end
            if score > bestScore then best, bestScore = item, score end
        end
    end
    return best
end

local autoSection = makeSection("AUTO FARM - YELLOW REWARD PAD")
local targetStatus = label(autoSection, "Target: scanning for the large yellow circle", UDim2.new(1, 0, 0, 30), UDim2.new(), 10)
targetStatus.TextXAlignment = Enum.TextXAlignment.Left
local autoButton
autoButton = addButton(autoSection, "AUTO FARM: OFF", function()
    autoFarm = not autoFarm
    autoButton.Text = autoFarm and "AUTO FARM: ON" or "AUTO FARM: OFF"
    autoButton.BackgroundColor3 = autoFarm and Color3.fromRGB(38, 115, 75) or Color3.fromRGB(43, 54, 77)

    if autoFarm then
        task.spawn(function()
            while autoFarm and not destroyed do
                updateCharacter()
                if not rootPart or not humanoid then
                    targetStatus.Text = "Target: character not found"
                    task.wait(0.15)
                else
                    local target = findYellowTarget()
                    if target and target.Parent then
                        local _, _, thickness = getPadMetrics(target)
                        local destination = target.Position + Vector3.new(0, thickness / 2 + 2.5, 0)
                        targetStatus.Text = "Target: large yellow circle locked"

                        -- Record each newly discovered pad location in the history list.
                        local lastSaved = waypoints[#waypoints]
                        if not lastSaved or (lastSaved - target.Position).Magnitude > 8 then
                            table.insert(waypoints, target.Position)
                            if #waypoints > 100 then table.remove(waypoints, 1) end
                            if history.Visible then refreshHistory() end
                        end

                        if movementMode == "Teleport" then
                            if (rootPart.Position - destination).Magnitude > 3 then
                                rootPart.CFrame = CFrame.new(destination)
                            end
                        else
                            humanoid.WalkSpeed = walkSpeed
                            humanoid:MoveTo(destination)
                        end
                        -- Re-scan rapidly: the pad may disappear and respawn elsewhere.
                        -- Do not wait on the old instance for several seconds.
                        task.wait(0.09)
                    else
                        targetStatus.Text = "Target: waiting for the yellow circle"
                        task.wait(0.12)
                    end
                end
            end
        end)
    else
        targetStatus.Text = "Target: auto farm stopped"
    end
end, Color3.fromRGB(43, 54, 77))
autoButton.Size = UDim2.new(1, 0, 0, 48)
autoButton.TextSize = 15

-- TELEPORT TO PLAYER ONCE PER PRESS
local playerSection = makeSection("TELEPORT TO PLAYER")
local userBox = Instance.new("TextBox")
userBox.Size = UDim2.new(1, 0, 0, 36)
userBox.BackgroundColor3 = Color3.fromRGB(30, 39, 57)
userBox.PlaceholderText = "Enter player username"
userBox.Text = ""
userBox.TextColor3 = Color3.new(1,1,1)
userBox.PlaceholderColor3 = Color3.fromRGB(160, 170, 190)
userBox.Font = Enum.Font.Gotham
userBox.TextSize = 13
userBox.ClearTextOnFocus = false
userBox.Parent = playerSection
round(userBox, 7)

addButton(playerSection, "TELEPORT TO PLAYER", function()
    local query = string.lower((userBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if query == "" then notify("Enter a username first"); return end
    local targetPlayer
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == query or string.lower(p.DisplayName) == query then
            targetPlayer = p
            break
        end
    end
    if not targetPlayer then notify("Player not found in this server"); return end
    updateCharacter()
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then notify("Character not ready"); return end
    rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
    notify("Teleported to " .. targetPlayer.Name)
end)

-- DRAG WINDOW
local locked = false
local dragging, dragStart, startPos = false, nil, nil
track(lockButton.MouseButton1Click, function()
    locked = not locked
    lockButton.Text = locked and "🔒" or "🔓"
end)
track(header.InputBegan, function(input)
    if locked then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
track(UserInputService.InputChanged, function(input)
    if dragging and not locked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
track(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- The location-history window can be moved independently from the main menu.
local historyDragging, historyDragStart, historyStartPos = false, nil, nil
track(historyHeader.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        historyDragging = true
        historyDragStart = input.Position
        historyStartPos = history.Position
    end
end)
track(UserInputService.InputChanged, function(input)
    if historyDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - historyDragStart
        history.Position = UDim2.new(historyStartPos.X.Scale, historyStartPos.X.Offset + delta.X, historyStartPos.Y.Scale, historyStartPos.Y.Offset + delta.Y)
    end
end)
track(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then historyDragging = false end
end)

-- Minimize / restore
local mini = Instance.new("TextButton")
mini.Size = UDim2.fromOffset(50, 50)
mini.Position = UDim2.new(1, -68, 0.18, 0)
mini.Text = "AF"
mini.TextColor3 = Color3.new(1,1,1)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 17
mini.BackgroundColor3 = Color3.fromRGB(25, 35, 55)
mini.Visible = false
mini.Parent = gui
round(mini, 12)
outline(mini, Color3.fromRGB(80, 125, 190), 2)

track(closeButton.MouseButton1Click, function()
    main.Visible = false
    mini.Visible = true
end)
track(mini.MouseButton1Click, function()
    mini.Visible = false
    main.Visible = true
end)

-- Cleanup
track(player.CharacterRemoving, function()
    if flying then
        flying = false
        if flightConnection then flightConnection:Disconnect(); flightConnection = nil end
        if flightVelocity then flightVelocity:Destroy(); flightVelocity = nil end
        if flightGyro then flightGyro:Destroy(); flightGyro = nil end
    end
end)

fitMainToContent()
notify("AUTO FARM PRO loaded")
