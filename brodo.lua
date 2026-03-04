if (_G.replayScriptRan) then return end
_G.replayScriptRan = true

local runService = game:GetService('RunService')
local players = game:GetService('Players')
local userInputService = game:GetService('UserInputService')
local starterGui = game:GetService("StarterGui")

local localPlayer = players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

-- Target variable moved up here so both the GUI and the Playback function can access it safely
local targetName = "" 

-- // 1. GUI Setup (Modern gethui() protection)
local function createTargetNameGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TargetNameGui"
    
    -- Modern UI protection for Volt/others
    local safeGuiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    gui.Parent = safeGuiParent
    
    local targetFrame = Instance.new("Frame")
    local targetLabel = Instance.new("TextLabel")
    local targetInput = Instance.new("TextBox")
    local okButton = Instance.new("TextButton")
    
    targetFrame.Name = "TargetFrame"
    targetFrame.Parent = gui
    targetFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    targetFrame.Size = UDim2.new(0, 300, 0, 200)
    
    targetLabel.Name = "TargetLabel"
    targetLabel.Parent = targetFrame
    targetLabel.Position = UDim2.new(0, 0, 0, 20)
    targetLabel.Size = UDim2.new(0, 300, 0, 40)
    targetLabel.Text = "Enter target name:"
    targetLabel.TextScaled = true
    
    targetInput.Name = "TargetInput"
    targetInput.Parent = targetFrame
    targetInput.Position = UDim2.new(0, 0, 0, 80)
    targetInput.Size = UDim2.new(0, 200, 0, 40)
    
    okButton.Name = "OkButton"
    okButton.Parent = targetFrame
    okButton.Position = UDim2.new(0, 50, 0, 140)
    okButton.Size = UDim2.new(0, 100, 0, 40)
    okButton.Text = "OK"
    
    okButton.MouseButton1Click:Connect(function()
        targetName = targetInput.Text
        targetFrame.Visible = false
        
        starterGui:SetCore("SendNotification", {
            Title = "Target Set",
            Text = "Target is now: " .. targetName,
            Duration = 3
        })
    end)
end

createTargetNameGui()


-- // 2. Maid Class & Variables
local bindKey = {Enum.KeyCode.LeftControl, Enum.KeyCode.Y} 
local bindKey2 = {Enum.KeyCode.LeftControl, Enum.KeyCode.Z} 

local Maid = {}
do
    Maid.ClassName = "Maid"

    function Maid.new()
        return setmetatable({ _tasks = {} }, Maid)
    end

    function Maid.isMaid(value)
        return type(value) == "table" and value.ClassName == "Maid"
    end

    function Maid.__index(self, index)
        if Maid[index] then
            return Maid[index]
        else
            return self._tasks[index]
        end
    end

    function Maid:__newindex(index, newTask)
        if Maid[index] ~= nil then error(("'%s' is reserved"):format(tostring(index)), 2) end
        local tasks = self._tasks
        local oldTask = tasks[index]
        if oldTask == newTask then return end

        tasks[index] = newTask
        if oldTask then
            if type(oldTask) == "function" then oldTask()
            elseif typeof(oldTask) == "RBXScriptConnection" then oldTask:Disconnect()
            elseif typeof(oldTask) == 'table' then oldTask:Remove()
            elseif oldTask.Destroy then oldTask:Destroy() end
        end
    end

    function Maid:GiveTask(task)
        if not task then error("Task cannot be false or nil", 2) end
        local taskId = #self._tasks+1
        self[taskId] = task
        if typeof(task) == 'table' and not task.Remove then
            warn("[Maid.GiveTask] - Gave table task without .Remove\n\n" .. debug.traceback())
        end
        return taskId
    end

    function Maid:DoCleaning()
        local tasks = self._tasks
        for index, task in pairs(tasks) do
            if typeof(task) == "RBXScriptConnection" then
                tasks[index] = nil
                task:Disconnect()
            end
        end

        local index, task = next(tasks)
        while task ~= nil do
            tasks[index] = nil
            if type(task) == "function" then task()
            elseif typeof(task) == "RBXScriptConnection" then task:Disconnect()
            elseif typeof(task) == 'table' then task:Remove()
            elseif task.Destroy then task:Destroy() end
            index, task = next(tasks)
        end
    end

    Maid.Destroy = Maid.DoCleaning
end

local maid = Maid.new()
local isRecording = false
local frameRate = 60
local playerCF = {}
local playerAnims = {}

local recordLabel = Drawing.new('Text')
recordLabel.Visible = false -- Changed default to false so it only shows when recording
recordLabel.Size = 30
recordLabel.Color = Color3.fromHex('ffffff')
recordLabel.Transparency = 1
recordLabel.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, 50)
recordLabel.Center = true

local function reverseTable(t)
    local newT = {}
    for i = #t, 1, -1 do
        table.insert(newT, t[i])
    end
    return newT
end


-- // 3. Core Logic (Record and Play)
local function startRecording()
    table.clear(playerAnims)
    table.clear(playerCF)

    local rootPart = character.HumanoidRootPart
    local humanoid = character.Humanoid
    
    local startedAt = tick()
    local lastRanAt = 0

    maid:GiveTask(runService.Heartbeat:Connect(function()
        if (tick() - lastRanAt < 1/frameRate) then return end
        lastRanAt = tick()
        table.insert(playerCF, rootPart.CFrame)
    end))

    for _, animTrack in next, humanoid:GetPlayingAnimationTracks() do
        task.spawn(function()
            local animData = {
                animation = animTrack.Animation.AnimationId,
                startedAt = 0,
                position = animTrack.TimePosition,
                looped = animTrack.Looped,
                speed = animTrack.Speed,
                priority = animTrack.Priority,
                weightTarget = animTrack.WeightTarget
            }

            animTrack.Stopped:Wait()
            animData.stoppedAt = tick() - startedAt
            table.insert(playerAnims, animData)
        end)
    end
    
    maid:GiveTask(humanoid.Animator.AnimationPlayed:Connect(function(animTrack)
        task.wait()
        local animData = {
            animation = animTrack.Animation.AnimationId,
            startedAt = tick() - startedAt,
            looped = animTrack.Looped,
            speed = animTrack.Speed,
            priority = animTrack.Priority,
            weightTarget = animTrack.WeightTarget
        }

        animTrack.Stopped:Wait()
        animData.stoppedAt = tick() - startedAt
        table.insert(playerAnims, animData)
    end))
end

local function playRecord()
    local realPlayerCF = reverseTable(playerCF)
    local targetPlayer = players:FindFirstChild(targetName)
    local targetChar = targetPlayer and targetPlayer.Character

    if (not targetChar) then
        starterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Target '"..targetName.."' not found!",
            Duration = 3
        })
        return
    end

    targetChar.Archivable = true
    local newCharacter = targetChar:Clone()

    for i, v in next, newCharacter:GetDescendants() do
        if (v:IsA('LuaSourceContainer')) then
            v:Destroy()
        end
    end

    local fakeCharRoot = newCharacter.HumanoidRootPart
    local fakeCharHumanoid = newCharacter.Humanoid

    fakeCharRoot.Anchored = true
    fakeCharRoot.CFrame = table.remove(realPlayerCF)
    newCharacter.Parent = workspace

    local lastRanAt = 0

    maid:GiveTask(runService.Heartbeat:Connect(function()
        if (tick() - lastRanAt < 1/frameRate) then return end
        lastRanAt = tick()
        local cf = table.remove(realPlayerCF)
        if (not cf) then return maid:Destroy() end
        fakeCharRoot.CFrame = cf
    end))

    for i, v in next, playerAnims do
        local animInstance = Instance.new('Animation')
        animInstance.AnimationId = v.animation

        task.delay(v.startedAt, function()
            local anim = newCharacter.Humanoid.Animator:LoadAnimation(animInstance)
            anim.Priority = v.priority
            anim.Looped = v.looped
            anim.TimePosition = v.position or 0

            anim:Play(nil, v.weightTarget, v.speed)
            task.wait(v.stoppedAt - v.startedAt)
            anim:Stop()
            animInstance:Destroy()
        end)
    end
end

local function toggleRecord()
    if (isRecording) then
        maid:DoCleaning()
        recordLabel.Visible = false
    else
        recordLabel.Visible = true
        recordLabel.Text = 'Recording...'
        startRecording()
    end
    isRecording = not isRecording
end

local function isKeyComboPressed(comboTable)
    for _, key in next, comboTable do
        if (not userInputService:IsKeyDown(key)) then
            return false
        end
    end
    return true
end

local function onInputBegan(inputObject, gpe)
    if (inputObject.KeyCode == Enum.KeyCode.Unknown) then return end

    if (isKeyComboPressed(bindKey)) then
        toggleRecord()
    elseif (isKeyComboPressed(bindKey2)) then
        playRecord()
    end
end

userInputService.InputBegan:Connect(onInputBegan)