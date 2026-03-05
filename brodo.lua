-- Prevent the script from running twice
if getgenv().ReplayScriptExecuted then 
    warn("Replay script is already running!")
    return 
end
getgenv().ReplayScriptExecuted = true

local runService = game:GetService('RunService')
local players = game:GetService('Players')
local userInputService = game:GetService('UserInputService')
local starterGui = game:GetService("StarterGui")

local localPlayer = players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local targetName = ""

-- The Keybinds
local bindKeyRecord = {Enum.KeyCode.LeftControl, Enum.KeyCode.Y} 
local bindKeyPlay = {Enum.KeyCode.LeftControl, Enum.KeyCode.Z} 

-- // 1. Maid Class (Memory Manager)
local Maid = {}
Maid.__index = Maid

do
    Maid.ClassName = "Maid"
    function Maid.new() return setmetatable({ _tasks = {} }, Maid) end
    function Maid:GiveTask(task)
        local taskId = #self._tasks+1
        self._tasks[taskId] = task
        return taskId
    end
    function Maid:DoCleaning()
        for index, task in pairs(self._tasks) do
            if typeof(task) == "RBXScriptConnection" then task:Disconnect()
            elseif type(task) == "function" then task()
            elseif typeof(task) == 'table' and task.Remove then task:Remove()
            elseif typeof(task) == "Instance" then task:Destroy() end
            self._tasks[index] = nil
        end
    end
end

local maid = Maid.new()
local isRecording = false

local playerCF = {}
local playerAnims = {}
local playerEvents = {}

local recordStartTime = 0

-- // 2. Asset Sniffer
local cachedIgnisVFX = nil

local function startAssetSniffer()
    local thrownFolder = workspace:WaitForChild("Thrown", 5)
    if not thrownFolder then return end

    thrownFolder.ChildAdded:Connect(function(newObject)
        if cachedIgnisVFX then return end
        
        if newObject.Name == "BurnSpell" then
            cachedIgnisVFX = newObject:Clone()
            local safeStorage = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            cachedIgnisVFX.Parent = safeStorage
            
            if cachedIgnisVFX:FindFirstChild("Flames") then
                cachedIgnisVFX.Flames.Enabled = false
            end
            
            starterGui:SetCore("SendNotification", {
                Title = "VFX Cached!",
                Text = "Successfully sniffed and stored Ignis VFX.",
                Duration = 3
            })
        end
    end)
end

startAssetSniffer()

-- // 3. Executor-Ready GUI Setup
local recordLabel = nil
if Drawing then
    recordLabel = Drawing.new('Text')
    recordLabel.Visible = false 
    recordLabel.Size = 30
    recordLabel.Color = Color3.fromHex('ffffff')
    recordLabel.Transparency = 1
    recordLabel.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, 50)
    recordLabel.Center = true
end

local function createTargetNameGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TargetNameGui"
    
    local safeGuiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    gui.Parent = safeGuiParent
    
    local targetFrame = Instance.new("Frame")
    targetFrame.Size = UDim2.new(0, 300, 0, 150)
    targetFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
    targetFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    targetFrame.BorderSizePixel = 0
    targetFrame.Parent = gui
    
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Text = "Enter target username:"
    targetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Size = UDim2.new(1, 0, 0, 40)
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.TextSize = 16
    targetLabel.Parent = targetFrame
    
    local targetInput = Instance.new("TextBox")
    targetInput.Size = UDim2.new(0, 200, 0, 40)
    targetInput.Position = UDim2.new(0.5, -100, 0, 50)
    targetInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    targetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetInput.Font = Enum.Font.Gotham
    targetInput.TextSize = 14
    targetInput.Parent = targetFrame
    
    local okButton = Instance.new("TextButton")
    okButton.Text = "Lock Target"
    okButton.Size = UDim2.new(0, 100, 0, 40)
    okButton.Position = UDim2.new(0.5, -50, 0, 100)
    okButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    okButton.Font = Enum.Font.GothamBold
    okButton.TextSize = 14
    okButton.Parent = targetFrame
    
    okButton.MouseButton1Click:Connect(function()
        targetName = targetInput.Text
        gui:Destroy() 
        
        starterGui:SetCore("SendNotification", {
            Title = "Target Locked",
            Text = "Target: " .. targetName .. "\nCtrl+Y = Record\nCtrl+Z = Play",
            Duration = 5
        })
    end)
end

createTargetNameGui()

-- // 4. VFX Function
local function playFakeIgnis(targetChar)
    if not cachedIgnisVFX then return end

    local burnSpell = cachedIgnisVFX:Clone()
    local rightArm = targetChar:FindFirstChild("Right Arm")
    if not rightArm then return end

    local weld = Instance.new("Weld")
    weld.Part0 = rightArm
    weld.Part1 = burnSpell
    weld.C1 = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.pi)
    weld.Parent = burnSpell

    burnSpell.Parent = targetChar
    
    burnSpell.PointLight.Enabled = true
    burnSpell.SpotLight.Enabled = true
    burnSpell.SpotLight.Color = Color3.fromRGB(255, 128, 43)
    burnSpell.PointLight.Color = Color3.fromRGB(255, 128, 43)
    
    local mainIgnis = burnSpell:FindFirstChild("Flames")
    if mainIgnis then mainIgnis.Enabled = true end
    if burnSpell:FindFirstChild("Hit") then burnSpell.Hit:Play() end

    task.delay(2, function()
        if mainIgnis then mainIgnis.Enabled = false end
        burnSpell.PointLight.Enabled = false
        burnSpell.SpotLight.Enabled = false
        task.wait(1.5)
        if burnSpell then burnSpell:Destroy() end
    end)
end

-- // 5. Core Logic (Recording)
local function startRecording()
    table.clear(playerAnims)
    table.clear(playerCF)
    table.clear(playerEvents)
    
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    
    recordStartTime = tick()

    -- 5a. Record Movement
    maid:GiveTask(runService.PostSimulation:Connect(function()
        table.insert(playerCF, {
            time = tick() - recordStartTime,
            cframe = rootPart.CFrame
        })
    end))

    -- 5b. Record Animations
    -- FIX: Was using animTrack.Stopped:Wait() which races if the anim stops
    -- before the yield is reached. Using :Connect() is instant and safe.
    maid:GiveTask(humanoid.Animator.AnimationPlayed:Connect(function(animTrack)
        local animData = {
            animationId = animTrack.Animation.AnimationId,
            startedAt = tick() - recordStartTime,
            looped = animTrack.Looped,
            speed = animTrack.Speed,
            priority = animTrack.Priority,
            weightTarget = animTrack.WeightTarget
        }

        local stopConn
        stopConn = animTrack.Stopped:Connect(function()
            stopConn:Disconnect()
            animData.stoppedAt = tick() - recordStartTime
            table.insert(playerAnims, animData)
        end)
    end))

    -- 5c. Record Spell Events
    maid:GiveTask(character.ChildAdded:Connect(function(child)
        if child.Name == "ActiveCast" then
            table.insert(playerEvents, {
                time = tick() - recordStartTime,
                type = "Ignis"
            })
        end
    end))
end

-- // 6. Core Logic (Playback)
local function playRecord()
    local targetPlayer = players:FindFirstChild(targetName)
    local targetChar = targetPlayer and targetPlayer.Character

    if not targetChar then
        starterGui:SetCore("SendNotification", {Title = "Error", Text = "Target '"..targetName.."' not found!", Duration = 3})
        return
    end

    targetChar.Archivable = true
    local newCharacter = targetChar:Clone()
    maid:GiveTask(newCharacter)

    for _, v in pairs(newCharacter:GetDescendants()) do
        if v:IsA('LuaSourceContainer') then v:Destroy() end
    end

    local fakeCharRoot = newCharacter:WaitForChild("HumanoidRootPart")
    local fakeCharHumanoid = newCharacter:WaitForChild("Humanoid")
    local fakeAnimator = fakeCharHumanoid:WaitForChild("Animator")
    
    fakeCharRoot.Anchored = true
    newCharacter.Parent = workspace

    local playbackStartTime = tick()
    local currentCFIndex = 1
    local currentEventIndex = 1
    local loadedAnimations = {}
    local totalFrames = #playerCF -- Cache length so we don't recount every frame

    -- Playback Loop
    maid:GiveTask(runService.PostSimulation:Connect(function()
        local elapsedTime = tick() - playbackStartTime
        
        -- A. Handle Movement
        -- FIX: Added nil guard on currentFrame so advancing past the last
        -- recorded frame can't index into a nil CFrame and error out.
        if currentCFIndex <= totalFrames then
            while currentCFIndex < totalFrames and elapsedTime >= playerCF[currentCFIndex + 1].time do
                currentCFIndex = currentCFIndex + 1
            end

            local currentFrame = playerCF[currentCFIndex]
            local nextFrame = playerCF[currentCFIndex + 1]

            if nextFrame then
                local timeDiff = nextFrame.time - currentFrame.time
                local alpha = math.clamp((elapsedTime - currentFrame.time) / timeDiff, 0, 1)
                fakeCharRoot.CFrame = currentFrame.cframe:Lerp(nextFrame.cframe, alpha)
            else
                -- Holds the very last recorded position instead of freezing at second-to-last
                fakeCharRoot.CFrame = currentFrame.cframe
            end
        end

        -- B. Handle Events
        local nextEvent = playerEvents[currentEventIndex]
        while nextEvent and elapsedTime >= nextEvent.time do
            if nextEvent.type == "Ignis" then
                playFakeIgnis(newCharacter)
            end
            currentEventIndex = currentEventIndex + 1
            nextEvent = playerEvents[currentEventIndex]
        end
    end))

    -- Playback Animations
    for _, animData in ipairs(playerAnims) do
        task.delay(animData.startedAt, function()
            if not loadedAnimations[animData.animationId] then
                local animInstance = Instance.new('Animation')
                animInstance.AnimationId = animData.animationId
                loadedAnimations[animData.animationId] = fakeAnimator:LoadAnimation(animInstance)
            end

            local anim = loadedAnimations[animData.animationId]
            anim.Priority = animData.priority
            anim.Looped = animData.looped
            anim:Play(nil, animData.weightTarget, animData.speed)

            task.wait(animData.stoppedAt - animData.startedAt)
            anim:Stop()
        end)
    end
end

-- // 7. Input Handling
local function isKeyComboPressed(comboTable)
    for _, key in ipairs(comboTable) do
        if not userInputService:IsKeyDown(key) then return false end
    end
    return true
end

local inputConnection = userInputService.InputBegan:Connect(function(inputObject, gpe)
    if gpe or inputObject.KeyCode == Enum.KeyCode.Unknown then return end

    if isKeyComboPressed(bindKeyRecord) then
        if isRecording then
            maid:DoCleaning() 
            if recordLabel then recordLabel.Visible = false end
        else
            maid:DoCleaning() 
            if recordLabel then 
                recordLabel.Visible = true 
                recordLabel.Text = 'Recording...'
            end
            startRecording()
        end
        isRecording = not isRecording

    elseif isKeyComboPressed(bindKeyPlay) and not isRecording then
        maid:DoCleaning() 
        playRecord()
    end
end)

getgenv().ReplayScriptConnection = inputConnection
