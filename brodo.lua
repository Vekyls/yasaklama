
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

-- The Keybinds: Ctrl+Q to Record, Ctrl+E to Play
local bindKeyRecord = {Enum.KeyCode.LeftControl, Enum.KeyCode.Y} 
local bindKeyPlay = {Enum.KeyCode.LeftControl, Enum.KeyCode.Z} 

-- // 1. Maid Class (Memory Manager)
local Maid = {}
Maid.__index = Maid

do
    Maid.ClassName = "Maid"
    
    function Maid.new() 
        return setmetatable({ _tasks = {} }, Maid) 
    end
    
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
local recordStartTime = 0

-- // 2. Executor-Ready GUI Setup
local function createTargetNameGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TargetNameGui"
    
    -- Modern Executor GUI Protection (Hides it from Anti-Cheats)
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
            Text = "Target: " .. targetName .. "\nCtrl+Q to Record\nCtrl+E to Play",
            Duration = 5
        })
    end)
end

createTargetNameGui()

-- // 3. Core Logic (Lerping & Recording)
local function startRecording()
    table.clear(playerAnims)
    table.clear(playerCF)
    
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    
    recordStartTime = tick()

    maid:GiveTask(runService.PostSimulation:Connect(function()
        table.insert(playerCF, {
            time = tick() - recordStartTime,
            cframe = rootPart.CFrame
        })
    end))

    maid:GiveTask(humanoid.Animator.AnimationPlayed:Connect(function(animTrack)
        local animData = {
            animationId = animTrack.Animation.AnimationId,
            startedAt = tick() - recordStartTime,
            looped = animTrack.Looped,
            speed = animTrack.Speed,
            priority = animTrack.Priority,
            weightTarget = animTrack.WeightTarget
        }

        animTrack.Stopped:Wait()
        animData.stoppedAt = tick() - recordStartTime
        table.insert(playerAnims, animData)
    end))
    
    starterGui:SetCore("SendNotification", {Title = "Status", Text = "Recording Started...", Duration = 2})
end

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
    local currentIndex = 1
    local loadedAnimations = {}

    maid:GiveTask(runService.PostSimulation:Connect(function()
        local elapsedTime = tick() - playbackStartTime
        local currentFrame = playerCF[currentIndex]
        local nextFrame = playerCF[currentIndex + 1]

        if not currentFrame then return end

        while nextFrame and elapsedTime >= nextFrame.time do
            currentIndex = currentIndex + 1
            currentFrame = playerCF[currentIndex]
            nextFrame = playerCF[currentIndex + 1]
        end

        if nextFrame then
            local timeDiff = nextFrame.time - currentFrame.time
            local timePassed = elapsedTime - currentFrame.time
            local alpha = math.clamp(timePassed / timeDiff, 0, 1)
            
            fakeCharRoot.CFrame = currentFrame.cframe:Lerp(nextFrame.cframe, alpha)
        else
            fakeCharRoot.CFrame = currentFrame.cframe
        end
    end))

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

-- // 4. Input Handling
local function isKeyComboPressed(comboTable)
    for _, key in ipairs(comboTable) do
        if not userInputService:IsKeyDown(key) then return false end
    end
    return true
end

-- Hook into user input safely
local inputConnection = userInputService.InputBegan:Connect(function(inputObject, gpe)
    if gpe or inputObject.KeyCode == Enum.KeyCode.Unknown then return end

    if isKeyComboPressed(bindKeyRecord) then
        if isRecording then
            maid:DoCleaning() 
            starterGui:SetCore("SendNotification", {Title = "Status", Text = "Recording Stopped.", Duration = 2})
        else
            maid:DoCleaning() 
            startRecording()
        end
        isRecording = not isRecording

    elseif isKeyComboPressed(bindKeyPlay) and not isRecording then
        maid:DoCleaning() 
        playRecord()
    end
end)

-- Give the input listener to a master cleanup task if needed later
getgenv().ReplayScriptConnection = inputConnection

