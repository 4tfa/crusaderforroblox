local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local mt = getrawmetatable(game)
local oldnamecall = mt.__namecall
local oldindex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if not checkcaller() then
        if method == "FireServer" or method == "InvokeServer" then
            local remoteName = tostring(self)
            
            if remoteName:find("Honeypot") or remoteName:find("ReplicateBan") or 
               remoteName:find("ReplicateLog") or remoteName:find("SpeedExceedsLimit") or
               remoteName:find("ForeignInstanceDetected") or remoteName:find("ForeignUIDetected") or
               remoteName:find("RageRemote") or remoteName:find("UnknownHighlight") or
               remoteName:find("FetchLogs") then
                return wait(9e9)
            end
        end
    end
    
    return oldnamecall(self, ...)
end)

mt.__index = newcclosure(function(self, key)
    if not checkcaller() then
        if key == "PreciseMenu" or key == "CrusaderGUI" then
            return nil
        end
    end
    return oldindex(self, key)
end)

setreadonly(mt, true)

local Config = {
    Aimbot = {
        Active = false,
        Key1 = "Right Mouse",
        Key2 = "Left Mouse",
        TargetPart = "Head",
        FOVSize = 10,
        Sensitivity1 = 4,
        Sensitivity2 = 4,
        DrawFOV = false,
        FOVColor = Color3.fromRGB(225, 37, 37)
    },
    ESP = {
        Box = false,
        BoxType = "2D",
        HealthBar = false,
        Line = false,
        LinePosition = "Up",
        HealthText = false,
        Distance = false,
        OperatorName = false,
        Bone = false,
        BoneColor = Color3.fromRGB(255, 255, 255),
        VisibleCheck = false,
        DeadCheck = false,
        Name = false,
        Head = false,
        TeamCheck = false,
        MaxDistance = 500
    },
    Misc = {
        Crosshair = false,
        HitDamageEffect = false,
        Radar = false,
        GadgetESP = false,
        GadgetColor = Color3.fromRGB(0, 150, 255)
    }
}

local ESPObjects = {}
local GadgetESPObjects = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 50
FOVCircle.Radius = 100
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = Config.Aimbot.FOVColor
FOVCircle.Transparency = 1
FOVCircle.ZIndex = 999
FOVCircle.Position = Vector2.new(0, 0)

local CrosshairLines = {}
for i = 1, 4 do
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Transparency = 1
    line.Visible = false
    line.ZIndex = 999
    line.From = Vector2.new(0, 0)
    line.To = Vector2.new(0, 0)
    CrosshairLines[i] = line
end

local RadarFrame = Drawing.new("Square")
RadarFrame.Visible = false
RadarFrame.Color = Color3.fromRGB(30, 30, 30)
RadarFrame.Filled = true
RadarFrame.Thickness = 1
RadarFrame.Transparency = 0.7
RadarFrame.ZIndex = 1
RadarFrame.Size = Vector2.new(200, 200)
RadarFrame.Position = Vector2.new(50, 50)

local RadarBorder = Drawing.new("Square")
RadarBorder.Visible = false
RadarBorder.Color = Color3.fromRGB(225, 37, 37)
RadarBorder.Filled = false
RadarBorder.Thickness = 2
RadarBorder.Transparency = 1
RadarBorder.ZIndex = 2
RadarBorder.Size = Vector2.new(200, 200)
RadarBorder.Position = Vector2.new(50, 50)

local RadarDots = {}

local function IsAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    return humanoid and rootPart and humanoid.Health > 0
end

local function IsTeamMate(player)
    if not LocalPlayer.Team or not player.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function IsVisible(targetChar)
    if not targetChar or not targetChar.PrimaryPart then return false end
    if not LocalPlayer.Character then return false end
    local origin = Camera.CFrame.Position
    local targetPos = targetChar.PrimaryPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, (targetPos - origin), rayParams)
    return result == nil
end

local function WorldToViewportPoint(position)
    local vec, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(vec.X, vec.Y), onScreen, vec.Z
end

local function GetClosestPlayerToCursor()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end
    
    local closestPlayer = nil
    local shortestDistance = Config.Aimbot.FOVSize * 8
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Config.ESP.TeamCheck and IsTeamMate(player) then continue end
            local char = player.Character
            local targetPart = char:FindFirstChild(Config.Aimbot.TargetPart)
            if not targetPart then
                if Config.Aimbot.TargetPart == "Neck" then
                    targetPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                elseif Config.Aimbot.TargetPart == "Chest" then
                    targetPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                else
                    targetPart = char:FindFirstChild("Head")
                end
            end
            if not targetPart then continue end
            if Config.ESP.VisibleCheck and not IsVisible(char) then continue end

            local screenPos, onScreen = WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end

local function Aimbot()
    if not Config.Aimbot.Active then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local key1Pressed = false
    local key2Pressed = false
    
    if Config.Aimbot.Key1 == "Right Mouse" then
        key1Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif Config.Aimbot.Key1 == "Left Mouse" then
        key1Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    else
        local keyEnum = Enum.KeyCode[Config.Aimbot.Key1:gsub(" ", "")]
        if keyEnum then
            key1Pressed = UserInputService:IsKeyDown(keyEnum)
        end
    end
    
    if Config.Aimbot.Key2 == "Right Mouse" then
        key2Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif Config.Aimbot.Key2 == "Left Mouse" then
        key2Pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    else
        local keyEnum = Enum.KeyCode[Config.Aimbot.Key2:gsub(" ", "")]
        if keyEnum then
            key2Pressed = UserInputService:IsKeyDown(keyEnum)
        end
    end
    
    if not key1Pressed and not key2Pressed then return end
    
    local rawSens = key1Pressed and Config.Aimbot.Sensitivity1 or Config.Aimbot.Sensitivity2
    local sensitivity
    
    if rawSens == 1 then sensitivity = 1.0
    elseif rawSens == 2 then sensitivity = 0.45
    elseif rawSens == 3 then sensitivity = 0.25
    elseif rawSens == 4 then sensitivity = 0.18
    elseif rawSens == 5 then sensitivity = 0.13
    elseif rawSens == 6 then sensitivity = 0.10
    elseif rawSens == 7 then sensitivity = 0.08
    elseif rawSens == 8 then sensitivity = 0.06
    elseif rawSens == 9 then sensitivity = 0.045
    else sensitivity = 0.03 end
    
    local targetPlayer = GetClosestPlayerToCursor()
    
    if targetPlayer and targetPlayer.Character then
        local targetPart = targetPlayer.Character:FindFirstChild(Config.Aimbot.TargetPart)
        if not targetPart then
            if Config.Aimbot.TargetPart == "Neck" then
                targetPart = targetPlayer.Character:FindFirstChild("UpperTorso") or targetPlayer.Character:FindFirstChild("Torso")
            elseif Config.Aimbot.TargetPart == "Chest" then
                targetPart = targetPlayer.Character:FindFirstChild("UpperTorso") or targetPlayer.Character:FindFirstChild("Torso")
            else
                targetPart = targetPlayer.Character:FindFirstChild("Head")
            end
        end
        if targetPart then
            local targetPos = targetPart.Position
            local camCFrame = Camera.CFrame
            local targetCFrame = CFrame.new(camCFrame.Position, targetPos)
            Camera.CFrame = camCFrame:Lerp(targetCFrame, sensitivity)
        end
    end
end

local function CreateESP(player)
    if ESPObjects[player] then return end
    
    pcall(function()
        local esp = {
            Box = Drawing.new("Square"),
            Circle = Drawing.new("Circle"),
            HealthBar = Drawing.new("Square"),
            HealthBarBG = Drawing.new("Square"),
            Line = Drawing.new("Line"),
            Name = Drawing.new("Text"),
            Distance = Drawing.new("Text"),
            HealthText = Drawing.new("Text"),
            OperatorName = Drawing.new("Text"),
            Head = Drawing.new("Circle"),
            Bone = {}
        }
        
        esp.Box.Visible = false
        esp.Box.Color = Color3.fromRGB(255, 255, 255)
        esp.Box.Thickness = 2
        esp.Box.Filled = false
        esp.Box.Transparency = 1
        esp.Box.ZIndex = 2
        esp.Box.Size = Vector2.new(100, 100)
        esp.Box.Position = Vector2.new(0, 0)
        
        esp.Circle.Visible = false
        esp.Circle.Color = Color3.fromRGB(255, 255, 255)
        esp.Circle.Thickness = 2
        esp.Circle.NumSides = 30
        esp.Circle.Filled = false
        esp.Circle.Transparency = 1
        esp.Circle.ZIndex = 2
        esp.Circle.Radius = 50
        esp.Circle.Position = Vector2.new(0, 0)
        
        esp.HealthBar.Visible = false
        esp.HealthBar.Filled = true
        esp.HealthBar.Thickness = 1
        esp.HealthBar.Transparency = 1
        esp.HealthBar.ZIndex = 2
        esp.HealthBar.Size = Vector2.new(2, 100)
        esp.HealthBar.Position = Vector2.new(0, 0)
        esp.HealthBar.Color = Color3.fromRGB(0, 255, 0)
        
        esp.HealthBarBG.Visible = false
        esp.HealthBarBG.Color = Color3.fromRGB(0, 0, 0)
        esp.HealthBarBG.Filled = false
        esp.HealthBarBG.Thickness = 3
        esp.HealthBarBG.Transparency = 1
        esp.HealthBarBG.ZIndex = 1
        esp.HealthBarBG.Size = Vector2.new(2, 100)
        esp.HealthBarBG.Position = Vector2.new(0, 0)
        
        esp.Line.Visible = false
        esp.Line.Color = Color3.fromRGB(255, 255, 255)
        esp.Line.Thickness = 2
        esp.Line.Transparency = 1
        esp.Line.ZIndex = 2
        esp.Line.From = Vector2.new(0, 0)
        esp.Line.To = Vector2.new(0, 0)
        
        esp.Name.Visible = false
        esp.Name.Color = Color3.fromRGB(255, 255, 255)
        esp.Name.Size = 14
        esp.Name.Center = true
        esp.Name.Outline = true
        esp.Name.Font = 2
        esp.Name.Transparency = 1
        esp.Name.ZIndex = 2
        esp.Name.Position = Vector2.new(0, 0)
        esp.Name.Text = ""
        
        esp.Distance.Visible = false
        esp.Distance.Color = Color3.fromRGB(255, 255, 255)
        esp.Distance.Size = 13
        esp.Distance.Center = true
        esp.Distance.Outline = true
        esp.Distance.Font = 2
        esp.Distance.Transparency = 1
        esp.Distance.ZIndex = 2
        esp.Distance.Position = Vector2.new(0, 0)
        esp.Distance.Text = ""
        
        esp.HealthText.Visible = false
        esp.HealthText.Color = Color3.fromRGB(255, 255, 255)
        esp.HealthText.Size = 13
        esp.HealthText.Center = true
        esp.HealthText.Outline = true
        esp.HealthText.Font = 2
        esp.HealthText.Transparency = 1
        esp.HealthText.ZIndex = 2
        esp.HealthText.Position = Vector2.new(0, 0)
        esp.HealthText.Text = ""
        
        esp.OperatorName.Visible = false
        esp.OperatorName.Color = Color3.fromRGB(255, 255, 255)
        esp.OperatorName.Size = 13
        esp.OperatorName.Center = true
        esp.OperatorName.Outline = true
        esp.OperatorName.Font = 2
        esp.OperatorName.Transparency = 1
        esp.OperatorName.ZIndex = 2
        esp.OperatorName.Position = Vector2.new(0, 0)
        esp.OperatorName.Text = ""
        
        esp.Head.Visible = false
        esp.Head.Color = Color3.fromRGB(255, 255, 255)
        esp.Head.Thickness = 2
        esp.Head.NumSides = 30
        esp.Head.Filled = false
        esp.Head.Transparency = 1
        esp.Head.ZIndex = 2
        esp.Head.Radius = 10
        esp.Head.Position = Vector2.new(0, 0)
        
        for i = 1, 15 do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = Config.ESP.BoneColor
            line.Thickness = 2
            line.Transparency = 1
            line.ZIndex = 2
            line.From = Vector2.new(0, 0)
            line.To = Vector2.new(0, 0)
            table.insert(esp.Bone, line)
        end
        
        ESPObjects[player] = esp
        print("[ESP] Created ESP for: " .. player.Name)
    end)
end

local function RemoveESP(player)
    if not ESPObjects[player] then return end
    pcall(function()
        local esp = ESPObjects[player]
        esp.Box:Remove()
        esp.Circle:Remove()
        esp.HealthBar:Remove()
        esp.HealthBarBG:Remove()
        esp.Line:Remove()
        esp.Name:Remove()
        esp.Distance:Remove()
        esp.HealthText:Remove()
        esp.OperatorName:Remove()
        esp.Head:Remove()
        for _, line in pairs(esp.Bone) do
            line:Remove()
        end
    end)
    ESPObjects[player] = nil
end

local function GetBoundingBox(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local validPoints = false

    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local coreParts
    
    if isR15 then
        coreParts = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"}
    else
        coreParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    end
    
    for _, partName in pairs(coreParts) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local corners = {
                Vector3.new(-part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(-part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(-part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
                Vector3.new(part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
                Vector3.new(-part.Size.X/2, part.Size.Y/2, part.Size.Z/2),
                Vector3.new(part.Size.X/2, part.Size.Y/2, part.Size.Z/2)
            }
            
            for _, corner in pairs(corners) do
                local worldPos = part.CFrame * corner
                local screenPos, onScreen = WorldToViewportPoint(worldPos)
                
                if onScreen then
                    validPoints = true
                    minX = math.min(minX, screenPos.X)
                    minY = math.min(minY, screenPos.Y)
                    maxX = math.max(maxX, screenPos.X)
                    maxY = math.max(maxY, screenPos.Y)
                end
            end
        end
    end
    
    if not validPoints then return nil end
    
    return {
        X = minX,
        Y = minY,
        Width = maxX - minX,
        Height = maxY - minY
    }
end

local function UpdateESP()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        for player, esp in pairs(ESPObjects) do
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
        end
        return
    end
    
    for player, esp in pairs(ESPObjects) do
        if player == LocalPlayer or not player or not player.Parent or not Players:FindFirstChild(player.Name) or not IsAlive(player) then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        if Config.ESP.TeamCheck and IsTeamMate(player) then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        local char = player.Character
        if not char then continue end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if not rootPart or not humanoid then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        if Config.ESP.DeadCheck and humanoid.Health <= 0 then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
        
        if distance > Config.ESP.MaxDistance then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        if Config.ESP.VisibleCheck and not IsVisible(char) then
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        local box = GetBoundingBox(char)
        
        if box then
            if Config.ESP.Box then
                if Config.ESP.BoxType == "Circle" then
                    esp.Box.Visible = false
                    local leftLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftFoot")
                    local rightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightFoot")
                    if leftLeg and rightLeg then
                        local leftPos = leftLeg.Position
                        local rightPos = rightLeg.Position
                        local feetPos = (leftPos + rightPos) / 2
                        local feetScreen, onScreen = WorldToViewportPoint(feetPos)
                        if onScreen then
                            esp.Circle.Position = Vector2.new(feetScreen.X, feetScreen.Y)
                            esp.Circle.Radius = box.Width / 2
                            esp.Circle.Visible = true
                        else
                            esp.Circle.Visible = false
                        end
                    else
                        esp.Circle.Visible = false
                    end
                else
                    esp.Circle.Visible = false
                    esp.Box.Size = Vector2.new(box.Width, box.Height)
                    esp.Box.Position = Vector2.new(box.X, box.Y)
                    esp.Box.Visible = true
                end
            else
                esp.Box.Visible = false
                esp.Circle.Visible = false
            end
            
            if Config.ESP.HealthBar then
                local healthPercent = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                local barHeight = math.max(box.Height * healthPercent, 1)
                esp.HealthBar.Size = Vector2.new(2, barHeight)
                esp.HealthBar.Position = Vector2.new(box.X - 6, box.Y + (box.Height - barHeight))
                esp.HealthBar.Color = Color3.fromRGB(0, 255, 0)
                esp.HealthBar.Visible = true
                esp.HealthBarBG.Visible = false
            else
                esp.HealthBar.Visible = false
                esp.HealthBarBG.Visible = false
            end
            
            if Config.ESP.Line then
                local fromY = Config.ESP.LinePosition == "Up" and 0 or (Config.ESP.LinePosition == "Center" and Camera.ViewportSize.Y / 2 or Camera.ViewportSize.Y)
                esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, fromY)
                esp.Line.To = Vector2.new(box.X + box.Width / 2, box.Y + box.Height)
                esp.Line.Visible = true
            else
                esp.Line.Visible = false
            end
            
            if Config.ESP.Name then
                esp.Name.Text = player.Name
                esp.Name.Position = Vector2.new(box.X + box.Width / 2, box.Y - 18)
                esp.Name.Visible = true
            else
                esp.Name.Visible = false
            end
            
            if Config.ESP.Distance then
                esp.Distance.Text = string.format("%d studs", math.floor(distance))
                esp.Distance.Position = Vector2.new(box.X + box.Width / 2, box.Y + box.Height + 5)
                esp.Distance.Visible = true
            else
                esp.Distance.Visible = false
            end
            
            if Config.ESP.OperatorName then
                local operatorName = player.DisplayName
                pcall(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local GameReplicated = ReplicatedStorage:FindFirstChild("GameReplicated")
                    if GameReplicated then
                        local Operators = GameReplicated:FindFirstChild("Operators")
                        if Operators then
                            for _, operator in pairs(Operators:GetChildren()) do
                                local charValue = operator:FindFirstChild("Character")
                                if charValue then
                                    if charValue:IsA("ObjectValue") and charValue.Value == char then
                                        operatorName = operator.Name
                                        break
                                    elseif charValue:IsA("StringValue") and charValue.Value == char.Name then
                                        operatorName = operator.Name
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)
                esp.OperatorName.Text = operatorName
                esp.OperatorName.Position = Vector2.new(box.X + box.Width / 2, box.Y + box.Height + 20)
                esp.OperatorName.Visible = true
            else
                esp.OperatorName.Visible = false
            end
            
            if Config.ESP.HealthText then
                local currentHealth = math.floor(math.clamp(humanoid.Health, 0, humanoid.MaxHealth))
                esp.HealthText.Text = string.format("%d HP", currentHealth)
                esp.HealthText.Position = Vector2.new(box.X - 22, box.Y)
                esp.HealthText.Visible = true
            else
                esp.HealthText.Visible = false
            end
            
            if Config.ESP.Head then
                local head = char:FindFirstChild("Head")
                if head then
                    local headScreen2, onScreen2 = WorldToViewportPoint(head.Position)
                    if onScreen2 then
                        esp.Head.Position = headScreen2
                        local topPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2, 0))
                        local bottomPos = Camera:WorldToViewportPoint(head.Position - Vector3.new(0, head.Size.Y / 2, 0))
                        esp.Head.Radius = math.abs(topPos.Y - bottomPos.Y) / 2
                        esp.Head.Visible = true
                    else
                        esp.Head.Visible = false
                    end
                else
                    esp.Head.Visible = false
                end
            else
                esp.Head.Visible = false
            end
            
            if Config.ESP.Bone then
                local isR15 = char:FindFirstChild("UpperTorso") ~= nil
                local bones
                
                if isR15 then
                    bones = {
                        {"Head", "UpperTorso"},
                        {"UpperTorso", "LeftUpperArm"},
                        {"UpperTorso", "RightUpperArm"},
                        {"UpperTorso", "LowerTorso"},
                        {"LeftUpperArm", "LeftLowerArm"},
                        {"LeftLowerArm", "LeftHand"},
                        {"RightUpperArm", "RightLowerArm"},
                        {"RightLowerArm", "RightHand"},
                        {"LowerTorso", "LeftUpperLeg"},
                        {"LowerTorso", "RightUpperLeg"},
                        {"LeftUpperLeg", "LeftLowerLeg"},
                        {"LeftLowerLeg", "LeftFoot"},
                        {"RightUpperLeg", "RightLowerLeg"},
                        {"RightLowerLeg", "RightFoot"}
                    }
                else
                    bones = {
                        {"Head", "Torso"},
                        {"Torso", "Left Arm"},
                        {"Torso", "Right Arm"},
                        {"Torso", "Left Leg"},
                        {"Torso", "Right Leg"}
                    }
                end
                
                for _, line in pairs(esp.Bone) do line.Visible = false end
                
                for i, bone in pairs(bones) do
                    local part1 = char:FindFirstChild(bone[1])
                    local part2 = char:FindFirstChild(bone[2])
                    if part1 and part2 and part1:IsA("BasePart") and part2:IsA("BasePart") and esp.Bone[i] then
                        local pos1, onScreen1 = WorldToViewportPoint(part1.Position)
                        local pos2, onScreen2 = WorldToViewportPoint(part2.Position)
                        if onScreen1 and onScreen2 then
                            esp.Bone[i].From = pos1
                            esp.Bone[i].To = pos2
                            esp.Bone[i].Color = Config.ESP.BoneColor
                            esp.Bone[i].Visible = true
                        end
                    end
                end
            else
                for _, line in pairs(esp.Bone) do line.Visible = false end
            end
        else
            esp.Box.Visible = false
            esp.Circle.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.OperatorName.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
        end
    end
end

local function CreateGadgetESP(gadget)
    if GadgetESPObjects[gadget] then return end
    
    pcall(function()
        local esp = {
            Box = Drawing.new("Square"),
            Text = Drawing.new("Text")
        }
        
        esp.Box.Visible = false
        esp.Box.Color = Config.Misc.GadgetColor
        esp.Box.Thickness = 2
        esp.Box.Filled = false
        esp.Box.Transparency = 1
        esp.Box.ZIndex = 2
        esp.Box.Size = Vector2.new(30, 30)
        esp.Box.Position = Vector2.new(0, 0)
        
        esp.Text.Visible = false
        esp.Text.Color = Config.Misc.GadgetColor
        esp.Text.Size = 13
        esp.Text.Center = true
        esp.Text.Outline = true
        esp.Text.Font = 2
        esp.Text.Transparency = 1
        esp.Text.ZIndex = 2
        esp.Text.Position = Vector2.new(0, 0)
        esp.Text.Text = ""
        
        GadgetESPObjects[gadget] = esp
    end)
end

local function RemoveGadgetESP(gadget)
    if not GadgetESPObjects[gadget] then return end
    pcall(function()
        local esp = GadgetESPObjects[gadget]
        esp.Box:Remove()
        esp.Text:Remove()
    end)
    GadgetESPObjects[gadget] = nil
end

local function UpdateGadgetESP()
    if not Config.Misc.GadgetESP then
        for gadget, esp in pairs(GadgetESPObjects) do
            esp.Box.Visible = false
            esp.Text.Visible = false
        end
        return
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local gadgetsFolder = Workspace:FindFirstChild("Gadgets")
    if not gadgetsFolder then return end
    
    for _, gadget in pairs(gadgetsFolder:GetChildren()) do
        if gadget:IsA("Model") and gadget.PrimaryPart then
            if not GadgetESPObjects[gadget] then
                CreateGadgetESP(gadget)
            end
            
            local esp = GadgetESPObjects[gadget]
            local pos = gadget.PrimaryPart.Position
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
            
            if distance > Config.ESP.MaxDistance then
                esp.Box.Visible = false
                esp.Text.Visible = false
                continue
            end
            
            local screenPos, onScreen = WorldToViewportPoint(pos)
            if onScreen then
                esp.Box.Size = Vector2.new(30, 30)
                esp.Box.Position = Vector2.new(screenPos.X - 15, screenPos.Y - 15)
                esp.Box.Color = Config.Misc.GadgetColor
                esp.Box.Visible = true
                
                esp.Text.Text = string.format("%s [%d]", gadget.Name, math.floor(distance))
                esp.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                esp.Text.Color = Config.Misc.GadgetColor
                esp.Text.Visible = true
            else
                esp.Box.Visible = false
                esp.Text.Visible = false
            end
        end
    end
    
    for gadget, esp in pairs(GadgetESPObjects) do
        if not gadget or not gadget.Parent then
            RemoveGadgetESP(gadget)
        end
    end
end

local function UpdateFOVCircle()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = center
    FOVCircle.Radius = Config.Aimbot.FOVSize * 8
    FOVCircle.Color = Config.Aimbot.FOVColor
    FOVCircle.Visible = Config.Aimbot.DrawFOV
end

local function UpdateCrosshair()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local size = 10
    local gap = 3
    
    CrosshairLines[1].From = Vector2.new(center.X, center.Y - gap)
    CrosshairLines[1].To = Vector2.new(center.X, center.Y - gap - size)
    
    CrosshairLines[2].From = Vector2.new(center.X, center.Y + gap)
    CrosshairLines[2].To = Vector2.new(center.X, center.Y + gap + size)
    
    CrosshairLines[3].From = Vector2.new(center.X - gap, center.Y)
    CrosshairLines[3].To = Vector2.new(center.X - gap - size, center.Y)
    
    CrosshairLines[4].From = Vector2.new(center.X + gap, center.Y)
    CrosshairLines[4].To = Vector2.new(center.X + gap + size, center.Y)
    
    for _, line in pairs(CrosshairLines) do
        line.Visible = Config.Misc.Crosshair
    end
end

local function UpdateRadar()
    if not Config.Misc.Radar then
        RadarFrame.Visible = false
        RadarBorder.Visible = false
        for _, dot in pairs(RadarDots) do
            dot.Visible = false
        end
        return
    end
    
    RadarFrame.Visible = true
    RadarBorder.Visible = true
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        for _, dot in pairs(RadarDots) do
            dot.Visible = false
        end
        return
    end
    
    local radarCenter = Vector2.new(150, 150)
    local radarSize = 200
    local radarRange = 200
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    local myLook = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
    
    local dotIndex = 1
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local theirPos = player.Character.HumanoidRootPart.Position
            local offset = theirPos - myPos
            local distance = offset.Magnitude
            
            if distance <= radarRange then
                local relativeX = offset.X
                local relativeZ = offset.Z
                
                local angle = math.atan2(myLook.X, myLook.Z)
                local cos = math.cos(angle)
                local sin = math.sin(angle)
                
                local rotatedX = relativeX * cos - relativeZ * sin
                local rotatedZ = relativeX * sin + relativeZ * cos
                
                local radarX = radarCenter.X + (rotatedX / radarRange) * (radarSize / 2)
                local radarY = radarCenter.Y - (rotatedZ / radarRange) * (radarSize / 2)
                
                if not RadarDots[dotIndex] then
                    local dot = Drawing.new("Circle")
                    dot.Filled = true
                    dot.Thickness = 1
                    dot.NumSides = 12
                    dot.Radius = 3
                    dot.Transparency = 1
                    dot.ZIndex = 3
                    RadarDots[dotIndex] = dot
                end
                
                local dot = RadarDots[dotIndex]
                dot.Position = Vector2.new(radarX, radarY)
                dot.Color = Config.ESP.TeamCheck and IsTeamMate(player) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(225, 37, 37)
                dot.Visible = true
                dotIndex = dotIndex + 1
            end
        end
    end
    
    for i = dotIndex, #RadarDots do
        RadarDots[i].Visible = false
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PreciseMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 567, 0, 430)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Active = false
MainFrame.Draggable = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 85, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 6)
SidebarCorner.Parent = Sidebar

local SidebarCover = Instance.new("Frame")
SidebarCover.Size = UDim2.new(0, 10, 1, 0)
SidebarCover.Position = UDim2.new(1, -10, 0, 0)
SidebarCover.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
SidebarCover.BorderSizePixel = 0
SidebarCover.Parent = Sidebar

local TopIconHolder = Instance.new("Frame")
TopIconHolder.Size = UDim2.new(0, 48, 0, 48)
TopIconHolder.Position = UDim2.new(0.5, -24, 0, 14)
TopIconHolder.BackgroundTransparency = 1
TopIconHolder.Parent = Sidebar

local function createTopSpike(size, pos, rot)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos
    f.Rotation = rot or 0
    f.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    f.BorderSizePixel = 0
    f.Parent = TopIconHolder
    return f
end

createTopSpike(UDim2.new(0, 2, 0, 28), UDim2.new(0.5, -1, 0, -2))
createTopSpike(UDim2.new(0, 2, 0, 18), UDim2.new(0.5, -10, 0, 6), -40)
createTopSpike(UDim2.new(0, 2, 0, 12), UDim2.new(0.5, -18, 0, 10), -65)
createTopSpike(UDim2.new(0, 2, 0, 18), UDim2.new(0.5, 8, 0, 6), 40)
createTopSpike(UDim2.new(0, 2, 0, 12), UDim2.new(0.5, 16, 0, 10), 65)

local TopCenterHub = Instance.new("Frame")
TopCenterHub.Size = UDim2.new(0, 8, 0, 8)
TopCenterHub.Position = UDim2.new(0.5, -4, 0, 16)
TopCenterHub.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
TopCenterHub.BorderSizePixel = 0
TopCenterHub.Parent = TopIconHolder
Instance.new("UICorner", TopCenterHub).CornerRadius = UDim.new(1, 0)

local BottomLogoHolder = Instance.new("Frame")
BottomLogoHolder.Size = UDim2.new(0, 48, 0, 48)
BottomLogoHolder.Position = UDim2.new(0.5, -24, 1, -62)
BottomLogoHolder.BackgroundTransparency = 1
BottomLogoHolder.Parent = Sidebar

createTopSpike(UDim2.new(0, 2, 0, 32), UDim2.new(0.5, -1, 0, 8)).Parent = BottomLogoHolder
local function createWingSpike(size, pos, rot)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos
    f.Rotation = rot
    f.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    f.BorderSizePixel = 0
    f.Parent = BottomLogoHolder
    return f
end
createWingSpike(UDim2.new(0, 2, 0, 20), UDim2.new(0.5, -10, 0, 10), -35)
createWingSpike(UDim2.new(0, 2, 0, 14), UDim2.new(0.5, -18, 0, 13), -60)
createWingSpike(UDim2.new(0, 2, 0, 10), UDim2.new(0.5, -24, 0, 17), -80)
createWingSpike(UDim2.new(0, 2, 0, 20), UDim2.new(0.5, 8, 0, 10), 35)
createWingSpike(UDim2.new(0, 2, 0, 14), UDim2.new(0.5, 16, 0, 13), 60)
createWingSpike(UDim2.new(0, 2, 0, 10), UDim2.new(0.5, 22, 0, 17), 80)

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -105, 1, -20)
Container.Position = UDim2.new(0, 95, 0, 10)
Container.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
Container.BorderSizePixel = 0
Container.Parent = MainFrame

local ContainerCorner = Instance.new("UICorner")
ContainerCorner.CornerRadius = UDim.new(0, 6)
ContainerCorner.Parent = Container

local PanelTitle = Instance.new("TextLabel")
PanelTitle.Size = UDim2.new(1, 0, 0, 30)
PanelTitle.Position = UDim2.new(0, 0, 0, 15)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "Aim Settings"
PanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelTitle.TextSize = 15
PanelTitle.Font = Enum.Font.Code
PanelTitle.Parent = Container

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -40, 1, -65)
ContentArea.Position = UDim2.new(0, 20, 0, 55)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.Parent = Container

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(0, 110, 0, 0)
DropdownList.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
DropdownList.BorderSizePixel = 0
DropdownList.Visible = false
DropdownList.ZIndex = 10
DropdownList.Parent = ScreenGui

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 4)
DropdownCorner.Parent = DropdownList

local ColorPickerMenu = Instance.new("Frame")
ColorPickerMenu.Size = UDim2.new(0, 200, 0, 140)
ColorPickerMenu.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
ColorPickerMenu.BorderSizePixel = 0
ColorPickerMenu.Visible = false
ColorPickerMenu.ZIndex = 20
ColorPickerMenu.Parent = ScreenGui

local ColorCorner = Instance.new("UICorner")
ColorCorner.CornerRadius = UDim.new(0, 6)
ColorCorner.Parent = ColorPickerMenu

local activeDropdownConnection = nil

local function closeDropdown()
    if DropdownList.Visible then
        DropdownList.Visible = false
        if activeDropdownConnection then
            activeDropdownConnection:Disconnect()
            activeDropdownConnection = nil
        end
    end
end

local function closeColorPicker()
    ColorPickerMenu.Visible = false
end

local function openDropdown(button, options, callback)
    closeDropdown()
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    DropdownList.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
    DropdownList.Size = UDim2.new(0, absSize.X, 0, #options * 26)
    
    for _, child in ipairs(DropdownList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 26)
        optBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 26)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = "  " .. opt
        optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        optBtn.TextSize = 12
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.Font = Enum.Font.Code
        optBtn.ZIndex = 11
        optBtn.Parent = DropdownList
        
        optBtn.MouseButton1Click:Connect(function()
            callback(opt)
            closeDropdown()
        end)
    end
    
    DropdownList.Visible = true
    activeDropdownConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.wait()
            local pos = input.Position
            local dPos = DropdownList.AbsolutePosition
            local dSize = DropdownList.AbsoluteSize
            local bPos = button.AbsolutePosition
            local bSize = button.AbsoluteSize
            
            local insideDropdown = pos.X >= dPos.X and pos.X <= dPos.X + dSize.X and pos.Y >= dPos.Y and pos.Y <= dPos.Y + dSize.Y
            local insideButton = pos.X >= bPos.X and pos.X <= bPos.X + bSize.X and pos.Y >= bPos.Y and pos.Y <= bPos.Y + bSize.Y
            
            if not insideDropdown and not insideButton then
                closeDropdown()
            end
        end
    end)
end

local function HSVToRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return Color3.fromRGB(r * 255, g * 255, b * 255)
end

local function RGBToHSV(color)
    local r, g, b = color.R, color.G, color.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v
    v = max
    local d = max - min
    if max == 0 then s = 0 else s = d / max end
    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d
            if g < b then h = h + 6 end
        elseif max == g then
            h = (b - r) / d + 2
        elseif max == b then
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, v
end

local function openColorPicker(button, currentColor, callback)
    closeColorPicker()
    local absPos = button.AbsolutePosition
    ColorPickerMenu.Position = UDim2.new(0, absPos.X + 30, 0, absPos.Y)
    
    for _, child in ipairs(ColorPickerMenu:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            if child.Name ~= "UICorner" then
                child:Destroy()
            end
        end
    end
    
    local hue, sat, val = RGBToHSV(currentColor)
    
    local HueLabel = Instance.new("TextLabel")
    HueLabel.Size = UDim2.new(1, -20, 0, 15)
    HueLabel.Position = UDim2.new(0, 10, 0, 10)
    HueLabel.BackgroundTransparency = 1
    HueLabel.Text = "Hue: " .. math.floor(hue * 360)
    HueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    HueLabel.TextSize = 11
    HueLabel.Font = Enum.Font.Code
    HueLabel.TextXAlignment = Enum.TextXAlignment.Left
    HueLabel.ZIndex = 21
    HueLabel.Parent = ColorPickerMenu
    
    local HueSlider = Instance.new("Frame")
    HueSlider.Size = UDim2.new(1, -20, 0, 8)
    HueSlider.Position = UDim2.new(0, 10, 0, 28)
    HueSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    HueSlider.BorderSizePixel = 0
    HueSlider.ZIndex = 21
    HueSlider.Parent = ColorPickerMenu
    Instance.new("UICorner", HueSlider).CornerRadius = UDim.new(1, 0)
    
    local HueGradient = Instance.new("UIGradient")
    HueGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
    }
    HueGradient.Parent = HueSlider
    
    local HueButton = Instance.new("TextButton")
    HueButton.Size = UDim2.new(1, 0, 1, 0)
    HueButton.BackgroundTransparency = 1
    HueButton.Text = ""
    HueButton.ZIndex = 22
    HueButton.Parent = HueSlider
    
    local SatLabel = Instance.new("TextLabel")
    SatLabel.Size = UDim2.new(1, -20, 0, 15)
    SatLabel.Position = UDim2.new(0, 10, 0, 48)
    SatLabel.BackgroundTransparency = 1
    SatLabel.Text = "Saturation: " .. math.floor(sat * 100) .. "%"
    SatLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    SatLabel.TextSize = 11
    SatLabel.Font = Enum.Font.Code
    SatLabel.TextXAlignment = Enum.TextXAlignment.Left
    SatLabel.ZIndex = 21
    SatLabel.Parent = ColorPickerMenu
    
    local SatSlider = Instance.new("Frame")
    SatSlider.Size = UDim2.new(1, -20, 0, 8)
    SatSlider.Position = UDim2.new(0, 10, 0, 66)
    SatSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    SatSlider.BorderSizePixel = 0
    SatSlider.ZIndex = 21
    SatSlider.Parent = ColorPickerMenu
    Instance.new("UICorner", SatSlider).CornerRadius = UDim.new(1, 0)
    
    local SatGradient = Instance.new("UIGradient")
    SatGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, HSVToRGB(hue, 1, 1))
    }
    SatGradient.Parent = SatSlider
    
    local SatButton = Instance.new("TextButton")
    SatButton.Size = UDim2.new(1, 0, 1, 0)
    SatButton.BackgroundTransparency = 1
    SatButton.Text = ""
    SatButton.ZIndex = 22
    SatButton.Parent = SatSlider
    
    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(1, -20, 0, 15)
    ValLabel.Position = UDim2.new(0, 10, 0, 86)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = "Value: " .. math.floor(val * 100) .. "%"
    ValLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValLabel.TextSize = 11
    ValLabel.Font = Enum.Font.Code
    ValLabel.TextXAlignment = Enum.TextXAlignment.Left
    ValLabel.ZIndex = 21
    ValLabel.Parent = ColorPickerMenu
    
    local ValSlider = Instance.new("Frame")
    ValSlider.Size = UDim2.new(1, -20, 0, 8)
    ValSlider.Position = UDim2.new(0, 10, 0, 104)
    ValSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ValSlider.BorderSizePixel = 0
    ValSlider.ZIndex = 21
    ValSlider.Parent = ColorPickerMenu
    Instance.new("UICorner", ValSlider).CornerRadius = UDim.new(1, 0)
    
    local ValGradient = Instance.new("UIGradient")
    ValGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1, HSVToRGB(hue, sat, 1))
    }
    ValGradient.Parent = ValSlider
    
    local ValButton = Instance.new("TextButton")
    ValButton.Size = UDim2.new(1, 0, 1, 0)
    ValButton.BackgroundTransparency = 1
    ValButton.Text = ""
    ValButton.ZIndex = 22
    ValButton.Parent = ValSlider
    
    local function UpdateColor()
        local color = HSVToRGB(hue, sat, val)
        button.BackgroundColor3 = color
        SatGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, HSVToRGB(hue, 1, 1))
        }
        ValGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(1, HSVToRGB(hue, sat, 1))
        }
        callback(color)
    end
    
    local hDragging, sDragging, vDragging = false, false, false
    
    HueButton.MouseButton1Down:Connect(function() hDragging = true end)
    SatButton.MouseButton1Down:Connect(function() sDragging = true end)
    ValButton.MouseButton1Down:Connect(function() vDragging = true end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hDragging, sDragging, vDragging = false, false, false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if hDragging then
                local pos = math.clamp((input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X, 0, 1)
                hue = pos
                HueLabel.Text = "Hue: " .. math.floor(hue * 360)
                UpdateColor()
            elseif sDragging then
                local pos = math.clamp((input.Position.X - SatSlider.AbsolutePosition.X) / SatSlider.AbsoluteSize.X, 0, 1)
                sat = pos
                SatLabel.Text = "Saturation: " .. math.floor(sat * 100) .. "%"
                UpdateColor()
            elseif vDragging then
                local pos = math.clamp((input.Position.X - ValSlider.AbsolutePosition.X) / ValSlider.AbsoluteSize.X, 0, 1)
                val = pos
                ValLabel.Text = "Value: " .. math.floor(val * 100) .. "%"
                UpdateColor()
            end
        end
    end)
    
    ColorPickerMenu.Visible = true
end

local function createToggle(name, defaultState, yPos, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.Position = UDim2.new(0, 0, 0, yPos)
    Row.BackgroundTransparency = 1
    Row.Parent = ContentArea

    local Box = Instance.new("TextButton")
    Box.Size = UDim2.new(0, 16, 0, 16)
    Box.Position = UDim2.new(0, 0, 0, 6)
    Box.BackgroundColor3 = defaultState and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    Box.BorderSizePixel = 0
    Box.Text = defaultState and "✓" or ""
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 13
    Box.TextXAlignment = Enum.TextXAlignment.Center
    Box.TextYAlignment = Enum.TextYAlignment.Center
    Box.Font = Enum.Font.GothamBold
    Box.Parent = Row

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 3)
    BoxCorner.Parent = Box

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 180, 1, 0)
    Label.Position = UDim2.new(0, 26, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Code
    Label.Parent = Row

    local active = defaultState
    Box.MouseButton1Click:Connect(function()
        active = not active
        Box.BackgroundColor3 = active and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box.Text = active and "✓" or ""
        if callback then callback(active) end
    end)
    
    return Row
end

local function createToggleWithColorPicker(name, defaultState, defaultColor, yPos, toggleCallback, colorCallback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.Position = UDim2.new(0, 0, 0, yPos)
    Row.BackgroundTransparency = 1
    Row.Parent = ContentArea

    local Box = Instance.new("TextButton")
    Box.Size = UDim2.new(0, 16, 0, 16)
    Box.Position = UDim2.new(0, 0, 0, 6)
    Box.BackgroundColor3 = defaultState and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    Box.BorderSizePixel = 0
    Box.Text = defaultState and "✓" or ""
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 13
    Box.TextXAlignment = Enum.TextXAlignment.Center
    Box.TextYAlignment = Enum.TextYAlignment.Center
    Box.Font = Enum.Font.GothamBold
    Box.Parent = Row

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 3)
    BoxCorner.Parent = Box

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 140, 1, 0)
    Label.Position = UDim2.new(0, 26, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Code
    Label.Parent = Row
    
    local ColorBox = Instance.new("TextButton")
    ColorBox.Size = UDim2.new(0, 24, 0, 24)
    ColorBox.Position = UDim2.new(0, 355, 0, 2)
    ColorBox.BackgroundColor3 = defaultColor
    ColorBox.BorderSizePixel = 0
    ColorBox.Text = ""
    ColorBox.Parent = Row
    
    local ColorBoxCorner = Instance.new("UICorner")
    ColorBoxCorner.CornerRadius = UDim.new(0, 4)
    ColorBoxCorner.Parent = ColorBox
    
    ColorBox.MouseButton1Click:Connect(function()
        openColorPicker(ColorBox, ColorBox.BackgroundColor3, colorCallback)
    end)

    local active = defaultState
    Box.MouseButton1Click:Connect(function()
        active = not active
        Box.BackgroundColor3 = active and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box.Text = active and "✓" or ""
        if toggleCallback then toggleCallback(active) end
    end)
    
    return Row
end

local function createToggleDropdown(name, defaultState, option1, option2, optionsList, yPos, cb1, cb2, toggleCb)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.Position = UDim2.new(0, 0, 0, yPos)
    Row.BackgroundTransparency = 1
    Row.Parent = ContentArea

    local Box = Instance.new("TextButton")
    Box.Size = UDim2.new(0, 16, 0, 16)
    Box.Position = UDim2.new(0, 0, 0, 6)
    Box.BackgroundColor3 = defaultState and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    Box.BorderSizePixel = 0
    Box.Text = defaultState and "✓" or ""
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.TextSize = 13
    Box.TextXAlignment = Enum.TextXAlignment.Center
    Box.TextYAlignment = Enum.TextYAlignment.Center
    Box.Font = Enum.Font.GothamBold
    Box.Parent = Row

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 3)
    BoxCorner.Parent = Box

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0, 100, 1, 0)
    Label.Position = UDim2.new(0, 26, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.Code
    Label.Parent = Row

    local Drop1 = Instance.new("TextButton")
    Drop1.Size = UDim2.new(0, 100, 0, 26)
    Drop1.Position = UDim2.new(0, 145, 0, 1)
    Drop1.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    Drop1.BorderSizePixel = 0
    Drop1.Text = "  " .. option1
    Drop1.TextColor3 = Color3.fromRGB(220, 220, 220)
    Drop1.TextSize = 11
    Drop1.TextXAlignment = Enum.TextXAlignment.Left
    Drop1.Font = Enum.Font.Code
    Drop1.Parent = Row

    local Drop1Corner = Instance.new("UICorner")
    Drop1Corner.CornerRadius = UDim.new(0, 3)
    Drop1Corner.Parent = Drop1

    local Arrow1 = Instance.new("TextLabel")
    Arrow1.Size = UDim2.new(0, 20, 1, 0)
    Arrow1.Position = UDim2.new(1, -20, 0, 0)
    Arrow1.BackgroundTransparency = 1
    Arrow1.Text = "▼"
    Arrow1.TextColor3 = Color3.fromRGB(225, 37, 37)
    Arrow1.TextSize = 8
    Arrow1.Parent = Drop1

    local Drop2 = Instance.new("TextButton")
    Drop2.Size = UDim2.new(0, 100, 0, 26)
    Drop2.Position = UDim2.new(0, 250, 0, 1)
    Drop2.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    Drop2.BorderSizePixel = 0
    Drop2.Text = "  " .. option2
    Drop2.TextColor3 = Color3.fromRGB(220, 220, 220)
    Drop2.TextSize = 11
    Drop2.TextXAlignment = Enum.TextXAlignment.Left
    Drop2.Font = Enum.Font.Code
    Drop2.Parent = Row

    local Drop2Corner = Instance.new("UICorner")
    Drop2Corner.CornerRadius = UDim.new(0, 3)
    Drop2Corner.Parent = Drop2

    local Arrow2 = Instance.new("TextLabel")
    Arrow2.Size = UDim2.new(0, 20, 1, 0)
    Arrow2.Position = UDim2.new(1, -20, 0, 0)
    Arrow2.BackgroundTransparency = 1
    Arrow2.Text = "▼"
    Arrow2.TextColor3 = Color3.fromRGB(225, 37, 37)
    Arrow2.TextSize = 8
    Arrow2.Parent = Drop2

    Drop1.MouseButton1Click:Connect(function()
        openDropdown(Drop1, optionsList, function(selected)
            Drop1.Text = "  " .. selected
            if cb1 then cb1(selected) end
        end)
    end)

    Drop2.MouseButton1Click:Connect(function()
        openDropdown(Drop2, optionsList, function(selected)
            Drop2.Text = "  " .. selected
            if cb2 then cb2(selected) end
        end)
    end)

    local active = defaultState
    Box.MouseButton1Click:Connect(function()
        active = not active
        Box.BackgroundColor3 = active and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box.Text = active and "✓" or ""
        if toggleCb then toggleCb(active) end
    end)
end

local function createSlider(name, defaultValue, minValue, maxValue, yPos, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.Position = UDim2.new(0, 0, 0, yPos)
    Row.BackgroundTransparency = 1
    Row.Parent = ContentArea

    local SliderBg = Instance.new("Frame")
    SliderBg.Size = UDim2.new(0, 170, 0, 16)
    SliderBg.Position = UDim2.new(0, 0, 0, 6)
    SliderBg.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    SliderBg.BorderSizePixel = 0
    SliderBg.Parent = Row

    local SliderBgCorner = Instance.new("UICorner")
    SliderBgCorner.CornerRadius = UDim.new(0, 3)
    SliderBgCorner.Parent = SliderBg

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(math.clamp((defaultValue - minValue) / (maxValue - minValue), 0, 1), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    Fill.BorderSizePixel = 0
    Fill.Parent = SliderBg

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(0, 3)
    FillCorner.Parent = Fill

    local WhiteMarker = Instance.new("Frame")
    WhiteMarker.Size = UDim2.new(0, 2, 1, 0)
    WhiteMarker.Position = UDim2.new(1, -2, 0, 0)
    WhiteMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    WhiteMarker.BorderSizePixel = 0
    WhiteMarker.Parent = Fill

    local ValLabel = Instance.new("TextLabel")
    ValLabel.Size = UDim2.new(1, 0, 1, 0)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(defaultValue)
    ValLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValLabel.TextSize = 11
    ValLabel.Font = Enum.Font.Code
    ValLabel.Parent = SliderBg

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(0, 150, 0, 16)
    NameLabel.Position = UDim2.new(0, 182, 0, 6)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = name
    NameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    NameLabel.TextSize = 12
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Font = Enum.Font.Code
    NameLabel.Parent = Row

    local dragging = false
    local currentValue = defaultValue

    local function updateValue(input)
        local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
        currentValue = math.floor(minValue + ((maxValue - minValue) * pos))
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        ValLabel.Text = tostring(currentValue)
        if callback then callback(currentValue) end
    end

    SliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateValue(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateValue(input)
        end
    end)
end

local function loadAimTab()
    PanelTitle.Text = "Aim Settings"
    for _, child in ipairs(ContentArea:GetChildren()) do child:Destroy() end
    
    createToggle("Active Aimbot", Config.Aimbot.Active, 0, function(val) Config.Aimbot.Active = val end)
    
    createToggleDropdown("Aimbot Keys", false, Config.Aimbot.Key1, Config.Aimbot.Key2, 
        {"Right Mouse", "Left Mouse", "Q", "E", "X", "V", "LeftShift", "CapsLock"}, 32,
        function(key) Config.Aimbot.Key1 = key end,
        function(key) Config.Aimbot.Key2 = key end)
    
    createToggle("Draw Fov", Config.Aimbot.DrawFOV, 64, function(val) Config.Aimbot.DrawFOV = val end)
    
    createToggleDropdown("Mark Target", false, Config.Aimbot.TargetPart, Config.Aimbot.TargetPart, 
        {"Head", "Neck", "Chest"}, 96,
        function(part) Config.Aimbot.TargetPart = part end,
        function(part) Config.Aimbot.TargetPart = part end)
    
    createSlider("Fov Size", Config.Aimbot.FOVSize, 1, 100, 128, function(val) Config.Aimbot.FOVSize = val end)
    createSlider("Sensitivity", Config.Aimbot.Sensitivity1, 1, 10, 160, function(val) Config.Aimbot.Sensitivity1 = val end)
    createSlider("Sensitivity (Key 2)", Config.Aimbot.Sensitivity2, 1, 10, 192, function(val) Config.Aimbot.Sensitivity2 = val end)
end

local function loadEspTab()
    PanelTitle.Text = "ESP Settings"
    for _, child in ipairs(ContentArea:GetChildren()) do child:Destroy() end

    local function createDoubleToggle(name1, state1, name2, state2, yPos, cb1, cb2)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.Position = UDim2.new(0, 0, 0, yPos)
        Row.BackgroundTransparency = 1
        Row.Parent = ContentArea

        local Box1 = Instance.new("TextButton")
        Box1.Size = UDim2.new(0, 16, 0, 16)
        Box1.Position = UDim2.new(0, 0, 0, 6)
        Box1.BackgroundColor3 = state1 and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box1.BorderSizePixel = 0
        Box1.Text = state1 and "✓" or ""
        Box1.TextColor3 = Color3.fromRGB(255, 255, 255)
        Box1.TextSize = 13
        Box1.TextXAlignment = Enum.TextXAlignment.Center
        Box1.TextYAlignment = Enum.TextYAlignment.Center
        Box1.Font = Enum.Font.GothamBold
        Box1.Parent = Row
        Instance.new("UICorner", Box1).CornerRadius = UDim.new(0, 3)

        local Label1 = Instance.new("TextLabel")
        Label1.Size = UDim2.new(0, 130, 1, 0)
        Label1.Position = UDim2.new(0, 24, 0, 0)
        Label1.BackgroundTransparency = 1
        Label1.Text = name1
        Label1.TextColor3 = Color3.fromRGB(220, 220, 220)
        Label1.TextSize = 12
        Label1.TextXAlignment = Enum.TextXAlignment.Left
        Label1.Font = Enum.Font.Code
        Label1.Parent = Row

        local Box2 = Instance.new("TextButton")
        Box2.Size = UDim2.new(0, 16, 0, 16)
        Box2.Position = UDim2.new(0, 180, 0, 6)
        Box2.BackgroundColor3 = state2 and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box2.BorderSizePixel = 0
        Box2.Text = state2 and "✓" or ""
        Box2.TextColor3 = Color3.fromRGB(255, 255, 255)
        Box2.TextSize = 13
        Box2.TextXAlignment = Enum.TextXAlignment.Center
        Box2.TextYAlignment = Enum.TextYAlignment.Center
        Box2.Font = Enum.Font.GothamBold
        Box2.Parent = Row
        Instance.new("UICorner", Box2).CornerRadius = UDim.new(0, 3)

        local Label2 = Instance.new("TextLabel")
        Label2.Size = UDim2.new(0, 140, 1, 0)
        Label2.Position = UDim2.new(0, 204, 0, 0)
        Label2.BackgroundTransparency = 1
        Label2.Text = name2
        Label2.TextColor3 = Color3.fromRGB(220, 220, 220)
        Label2.TextSize = 12
        Label2.TextXAlignment = Enum.TextXAlignment.Left
        Label2.Font = Enum.Font.Code
        Label2.Parent = Row

        local act1, act2 = state1, state2
        Box1.MouseButton1Click:Connect(function()
            act1 = not act1
            Box1.BackgroundColor3 = act1 and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
            Box1.Text = act1 and "✓" or ""
            if cb1 then cb1(act1) end
        end)
        Box2.MouseButton1Click:Connect(function()
            act2 = not act2
            Box2.BackgroundColor3 = act2 and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
            Box2.Text = act2 and "✓" or ""
            if cb2 then cb2(act2) end
        end)
    end

    local Row0 = Instance.new("Frame")
    Row0.Size = UDim2.new(1, 0, 0, 28)
    Row0.Position = UDim2.new(0, 0, 0, 0)
    Row0.BackgroundTransparency = 1
    Row0.Parent = ContentArea

    local BoxToggle = Instance.new("TextButton")
    BoxToggle.Size = UDim2.new(0, 16, 0, 16)
    BoxToggle.Position = UDim2.new(0, 0, 0, 6)
    BoxToggle.BackgroundColor3 = Config.ESP.Box and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    BoxToggle.BorderSizePixel = 0
    BoxToggle.Text = Config.ESP.Box and "✓" or ""
    BoxToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    BoxToggle.TextSize = 13
    BoxToggle.TextXAlignment = Enum.TextXAlignment.Center
    BoxToggle.TextYAlignment = Enum.TextYAlignment.Center
    BoxToggle.Font = Enum.Font.GothamBold
    BoxToggle.Parent = Row0
    Instance.new("UICorner", BoxToggle).CornerRadius = UDim.new(0, 3)

    local BoxLabel = Instance.new("TextLabel")
    BoxLabel.Size = UDim2.new(0, 60, 1, 0)
    BoxLabel.Position = UDim2.new(0, 24, 0, 0)
    BoxLabel.BackgroundTransparency = 1
    BoxLabel.Text = "ESP Box"
    BoxLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    BoxLabel.TextSize = 12
    BoxLabel.TextXAlignment = Enum.TextXAlignment.Left
    BoxLabel.Font = Enum.Font.Code
    BoxLabel.Parent = Row0

    local BoxDrop = Instance.new("TextButton")
    BoxDrop.Size = UDim2.new(0, 90, 0, 26)
    BoxDrop.Position = UDim2.new(0, 85, 0, 1)
    BoxDrop.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    BoxDrop.BorderSizePixel = 0
    BoxDrop.Text = "  " .. Config.ESP.BoxType
    BoxDrop.TextColor3 = Color3.fromRGB(220, 220, 220)
    BoxDrop.TextSize = 11
    BoxDrop.TextXAlignment = Enum.TextXAlignment.Left
    BoxDrop.Font = Enum.Font.Code
    BoxDrop.Parent = Row0
    Instance.new("UICorner", BoxDrop).CornerRadius = UDim.new(0, 3)

    local BoxArrow = Instance.new("TextLabel")
    BoxArrow.Size = UDim2.new(0, 20, 1, 0)
    BoxArrow.Position = UDim2.new(1, -20, 0, 0)
    BoxArrow.BackgroundTransparency = 1
    BoxArrow.Text = "▼"
    BoxArrow.TextColor3 = Color3.fromRGB(225, 37, 37)
    BoxArrow.TextSize = 8
    BoxArrow.Parent = BoxDrop

    BoxDrop.MouseButton1Click:Connect(function()
        openDropdown(BoxDrop, {"2D", "Circle"}, function(selected)
            BoxDrop.Text = "  " .. selected
            Config.ESP.BoxType = selected
        end)
    end)

    local VisibleToggle = Instance.new("TextButton")
    VisibleToggle.Size = UDim2.new(0, 16, 0, 16)
    VisibleToggle.Position = UDim2.new(0, 180, 0, 6)
    VisibleToggle.BackgroundColor3 = Config.ESP.VisibleCheck and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    VisibleToggle.BorderSizePixel = 0
    VisibleToggle.Text = Config.ESP.VisibleCheck and "✓" or ""
    VisibleToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    VisibleToggle.TextSize = 13
    VisibleToggle.TextXAlignment = Enum.TextXAlignment.Center
    VisibleToggle.TextYAlignment = Enum.TextYAlignment.Center
    VisibleToggle.Font = Enum.Font.GothamBold
    VisibleToggle.Parent = Row0
    Instance.new("UICorner", VisibleToggle).CornerRadius = UDim.new(0, 3)

    local VisibleLabel = Instance.new("TextLabel")
    VisibleLabel.Size = UDim2.new(0, 140, 1, 0)
    VisibleLabel.Position = UDim2.new(0, 204, 0, 0)
    VisibleLabel.BackgroundTransparency = 1
    VisibleLabel.Text = "Visible Check(Test)"
    VisibleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    VisibleLabel.TextSize = 12
    VisibleLabel.TextXAlignment = Enum.TextXAlignment.Left
    VisibleLabel.Font = Enum.Font.Code
    VisibleLabel.Parent = Row0

    BoxToggle.MouseButton1Click:Connect(function()
        Config.ESP.Box = not Config.ESP.Box
        BoxToggle.BackgroundColor3 = Config.ESP.Box and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        BoxToggle.Text = Config.ESP.Box and "✓" or ""
    end)

    VisibleToggle.MouseButton1Click:Connect(function()
        Config.ESP.VisibleCheck = not Config.ESP.VisibleCheck
        VisibleToggle.BackgroundColor3 = Config.ESP.VisibleCheck and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        VisibleToggle.Text = Config.ESP.VisibleCheck and "✓" or ""
    end)

    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 28)
    Row.Position = UDim2.new(0, 0, 0, 32)
    Row.BackgroundTransparency = 1
    Row.Parent = ContentArea

    local Box1 = Instance.new("TextButton")
    Box1.Size = UDim2.new(0, 16, 0, 16)
    Box1.Position = UDim2.new(0, 0, 0, 6)
    Box1.BackgroundColor3 = Config.ESP.Line and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    Box1.BorderSizePixel = 0
    Box1.Text = Config.ESP.Line and "✓" or ""
    Box1.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box1.TextSize = 13
    Box1.TextXAlignment = Enum.TextXAlignment.Center
    Box1.TextYAlignment = Enum.TextYAlignment.Center
    Box1.Font = Enum.Font.GothamBold
    Box1.Parent = Row
    Instance.new("UICorner", Box1).CornerRadius = UDim.new(0, 3)

    local Label1 = Instance.new("TextLabel")
    Label1.Size = UDim2.new(0, 60, 1, 0)
    Label1.Position = UDim2.new(0, 24, 0, 0)
    Label1.BackgroundTransparency = 1
    Label1.Text = "ESP Line"
    Label1.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label1.TextSize = 12
    Label1.TextXAlignment = Enum.TextXAlignment.Left
    Label1.Font = Enum.Font.Code
    Label1.Parent = Row

    local Drop1 = Instance.new("TextButton")
    Drop1.Size = UDim2.new(0, 90, 0, 26)
    Drop1.Position = UDim2.new(0, 85, 0, 1)
    Drop1.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    Drop1.BorderSizePixel = 0
    Drop1.Text = "  " .. Config.ESP.LinePosition
    Drop1.TextColor3 = Color3.fromRGB(220, 220, 220)
    Drop1.TextSize = 11
    Drop1.TextXAlignment = Enum.TextXAlignment.Left
    Drop1.Font = Enum.Font.Code
    Drop1.Parent = Row
    Instance.new("UICorner", Drop1).CornerRadius = UDim.new(0, 3)

    local Arrow1 = Instance.new("TextLabel")
    Arrow1.Size = UDim2.new(0, 20, 1, 0)
    Arrow1.Position = UDim2.new(1, -20, 0, 0)
    Arrow1.BackgroundTransparency = 1
    Arrow1.Text = "▼"
    Arrow1.TextColor3 = Color3.fromRGB(225, 37, 37)
    Arrow1.TextSize = 8
    Arrow1.Parent = Drop1

    Drop1.MouseButton1Click:Connect(function()
        openDropdown(Drop1, {"Up", "Center", "Bottom"}, function(selected)
            Drop1.Text = "  " .. selected
            Config.ESP.LinePosition = selected
        end)
    end)

    local DeadToggle = Instance.new("TextButton")
    DeadToggle.Size = UDim2.new(0, 16, 0, 16)
    DeadToggle.Position = UDim2.new(0, 180, 0, 6)
    DeadToggle.BackgroundColor3 = Config.ESP.DeadCheck and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    DeadToggle.BorderSizePixel = 0
    DeadToggle.Text = Config.ESP.DeadCheck and "✓" or ""
    DeadToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    DeadToggle.TextSize = 13
    DeadToggle.TextXAlignment = Enum.TextXAlignment.Center
    DeadToggle.TextYAlignment = Enum.TextYAlignment.Center
    DeadToggle.Font = Enum.Font.GothamBold
    DeadToggle.Parent = Row
    Instance.new("UICorner", DeadToggle).CornerRadius = UDim.new(0, 3)

    local DeadLabel = Instance.new("TextLabel")
    DeadLabel.Size = UDim2.new(0, 140, 1, 0)
    DeadLabel.Position = UDim2.new(0, 204, 0, 0)
    DeadLabel.BackgroundTransparency = 1
    DeadLabel.Text = "Dead Check"
    DeadLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    DeadLabel.TextSize = 12
    DeadLabel.TextXAlignment = Enum.TextXAlignment.Left
    DeadLabel.Font = Enum.Font.Code
    DeadLabel.Parent = Row

    Box1.MouseButton1Click:Connect(function()
        Config.ESP.Line = not Config.ESP.Line
        Box1.BackgroundColor3 = Config.ESP.Line and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box1.Text = Config.ESP.Line and "✓" or ""
    end)
    
    DeadToggle.MouseButton1Click:Connect(function()
        Config.ESP.DeadCheck = not Config.ESP.DeadCheck
        DeadToggle.BackgroundColor3 = Config.ESP.DeadCheck and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        DeadToggle.Text = Config.ESP.DeadCheck and "✓" or ""
    end)

    createDoubleToggle("Player Health Bar", Config.ESP.HealthBar, "Player Name", Config.ESP.Name, 64,
        function(val) Config.ESP.HealthBar = val end,
        function(val) Config.ESP.Name = val end)
    
    createDoubleToggle("Player Health Text", Config.ESP.HealthText, "Player Head", Config.ESP.Head, 96,
        function(val) Config.ESP.HealthText = val end,
        function(val) Config.ESP.Head = val end)
    
    createDoubleToggle("Player Distance", Config.ESP.Distance, "Player Team Check", Config.ESP.TeamCheck, 128,
        function(val) Config.ESP.Distance = val end,
        function(val) Config.ESP.TeamCheck = val end)
    
    createDoubleToggle("Operator Name", Config.ESP.OperatorName, "Player Team Check", Config.ESP.TeamCheck, 160,
        function(val) Config.ESP.OperatorName = val end,
        function(val) Config.ESP.TeamCheck = val end)
    
    createToggle("Player Bone", Config.ESP.Bone, 192, function(val) Config.ESP.Bone = val end)
    
    createSlider("Maximum Esp Distance", Config.ESP.MaxDistance, 1, 850, 224, function(val) Config.ESP.MaxDistance = val end)
end

local function loadMiscTab()
    PanelTitle.Text = "Misc Settings"
    for _, child in ipairs(ContentArea:GetChildren()) do child:Destroy() end
    
    createToggle("Crosshair", Config.Misc.Crosshair, 0, function(val) Config.Misc.Crosshair = val end)
    createToggle("Hit Damage Effect", Config.Misc.HitDamageEffect, 32, function(val) Config.Misc.HitDamageEffect = val end)
    createToggle("Radar", Config.Misc.Radar, 64, function(val) Config.Misc.Radar = val end)
    
    createToggle("Gadget ESP (Testing Stage)", Config.Misc.GadgetESP, 96, function(val) Config.Misc.GadgetESP = val end)
end

local EspTabBtn = Instance.new("TextButton")
EspTabBtn.Size = UDim2.new(0, 65, 0, 55)
EspTabBtn.Position = UDim2.new(0.5, -32.5, 0, 80)
EspTabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
EspTabBtn.BorderSizePixel = 0
EspTabBtn.Text = ""
EspTabBtn.Parent = Sidebar
Instance.new("UICorner", EspTabBtn).CornerRadius = UDim.new(0, 6)

local AimIndicator = Instance.new("Frame")
AimIndicator.Size = UDim2.new(0, 4, 0, 30)
AimIndicator.Position = UDim2.new(0, -10, 0.5, -15)
AimIndicator.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
AimIndicator.BorderSizePixel = 0
AimIndicator.Parent = EspTabBtn
Instance.new("UICorner", AimIndicator).CornerRadius = UDim.new(0, 2)

local EspIconHolder = Instance.new("Frame")
EspIconHolder.Size = UDim2.new(0, 20, 0, 22)
EspIconHolder.Position = UDim2.new(0.5, -10, 0, 10)
EspIconHolder.BackgroundTransparency = 1
EspIconHolder.Parent = EspTabBtn

local EspPinBody = Instance.new("Frame")
EspPinBody.Size = UDim2.new(0, 14, 0, 14)
EspPinBody.Position = UDim2.new(0.5, -7, 0, 0)
EspPinBody.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
EspPinBody.BorderSizePixel = 0
EspPinBody.Parent = EspIconHolder
Instance.new("UICorner", EspPinBody).CornerRadius = UDim.new(1, 0)

local EspPinPoint = Instance.new("Frame")
EspPinPoint.Size = UDim2.new(0, 8, 0, 8)
EspPinPoint.Position = UDim2.new(0.5, -4, 0, 7)
EspPinPoint.Rotation = 45
EspPinPoint.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
EspPinPoint.BorderSizePixel = 0
EspPinPoint.Parent = EspIconHolder

local EspPinHole = Instance.new("Frame")
EspPinHole.Size = UDim2.new(0, 5, 0, 5)
EspPinHole.Position = UDim2.new(0.5, -2.5, 0, 2.5)
EspPinHole.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
EspPinHole.BorderSizePixel = 0
EspPinHole.Parent = EspIconHolder
Instance.new("UICorner", EspPinHole).CornerRadius = UDim.new(1, 0)

local EspLabel = Instance.new("TextLabel")
EspLabel.Size = UDim2.new(1, 0, 0, 14)
EspLabel.Position = UDim2.new(0, 0, 1, -16)
EspLabel.BackgroundTransparency = 1
EspLabel.Text = "ESP"
EspLabel.TextColor3 = Color3.fromRGB(225, 37, 37)
EspLabel.TextSize = 10
EspLabel.Font = Enum.Font.Code
EspLabel.Parent = EspTabBtn

local AimTabBtn = Instance.new("TextButton")
AimTabBtn.Size = UDim2.new(0, 65, 0, 55)
AimTabBtn.Position = UDim2.new(0.5, -32.5, 0, 145)
AimTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
AimTabBtn.BorderSizePixel = 0
AimTabBtn.Text = ""
AimTabBtn.Parent = Sidebar
Instance.new("UICorner", AimTabBtn).CornerRadius = UDim.new(0, 6)

local AimIconHolder = Instance.new("Frame")
AimIconHolder.Size = UDim2.new(0, 24, 0, 24)
AimIconHolder.Position = UDim2.new(0.5, -12, 0, 10)
AimIconHolder.BackgroundTransparency = 1
AimIconHolder.Parent = AimTabBtn

local AimV = Instance.new("Frame")
AimV.Size = UDim2.new(0, 2, 0, 24)
AimV.Position = UDim2.new(0.5, -1, 0, 0)
AimV.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
AimV.BorderSizePixel = 0
AimV.Parent = AimIconHolder

local AimH = Instance.new("Frame")
AimH.Size = UDim2.new(0, 24, 0, 2)
AimH.Position = UDim2.new(0, 0, 0.5, -1)
AimH.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
AimH.BorderSizePixel = 0
AimH.Parent = AimIconHolder

local AimC = Instance.new("Frame")
AimC.Size = UDim2.new(0, 8, 0, 8)
AimC.Position = UDim2.new(0.5, -4, 0.5, -4)
AimC.BackgroundTransparency = 1
AimC.Parent = AimIconHolder
Instance.new("UIStroke", AimC).Color = Color3.fromRGB(80, 80, 80)
Instance.new("UICorner", AimC).CornerRadius = UDim.new(1, 0)

local function createAimTick(size, pos)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    f.BorderSizePixel = 0
    f.Parent = AimIconHolder
    return f
end
createAimTick(UDim2.new(0, 6, 0, 2), UDim2.new(0.5, -3, 0, 2))
createAimTick(UDim2.new(0, 6, 0, 2), UDim2.new(0.5, -3, 1, -4))
createAimTick(UDim2.new(0, 2, 0, 6), UDim2.new(0, 2, 0.5, -3))
createAimTick(UDim2.new(0, 2, 0, 6), UDim2.new(1, -4, 0.5, -3))

local AimLabel = Instance.new("TextLabel")
AimLabel.Size = UDim2.new(1, 0, 0, 14)
AimLabel.Position = UDim2.new(0, 0, 1, -16)
AimLabel.BackgroundTransparency = 1
AimLabel.Text = "AIM"
AimLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
AimLabel.TextSize = 10
AimLabel.Font = Enum.Font.Code
AimLabel.Parent = AimTabBtn

local MiscTabBtn = Instance.new("TextButton")
MiscTabBtn.Size = UDim2.new(0, 65, 0, 55)
MiscTabBtn.Position = UDim2.new(0.5, -32.5, 0, 210)
MiscTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MiscTabBtn.BorderSizePixel = 0
MiscTabBtn.Text = ""
MiscTabBtn.Parent = Sidebar
Instance.new("UICorner", MiscTabBtn).CornerRadius = UDim.new(0, 6)

local MiscIconHolder = Instance.new("Frame")
MiscIconHolder.Size = UDim2.new(0, 22, 0, 22)
MiscIconHolder.Position = UDim2.new(0.5, -11, 0, 10)
MiscIconHolder.BackgroundTransparency = 1
MiscIconHolder.Parent = MiscTabBtn

local CrownBase = Instance.new("Frame")
CrownBase.Size = UDim2.new(0, 16, 0, 4)
CrownBase.Position = UDim2.new(0.5, -8, 0, 0)
CrownBase.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
CrownBase.BorderSizePixel = 0
CrownBase.Parent = MiscIconHolder
Instance.new("UICorner", CrownBase).CornerRadius = UDim.new(0, 1)

local CrownPointL = Instance.new("Frame")
CrownPointL.Size = UDim2.new(0, 3, 0, 7)
CrownPointL.Position = UDim2.new(0, 1, 0, -6)
CrownPointL.Rotation = -18
CrownPointL.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
CrownPointL.BorderSizePixel = 0
CrownPointL.Parent = CrownBase

local CrownPointM = Instance.new("Frame")
CrownPointM.Size = UDim2.new(0, 3, 0, 9)
CrownPointM.Position = UDim2.new(0.5, -1.5, 0, -8)
CrownPointM.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
CrownPointM.BorderSizePixel = 0
CrownPointM.Parent = CrownBase

local CrownPointR = Instance.new("Frame")
CrownPointR.Size = UDim2.new(0, 3, 0, 7)
CrownPointR.Position = UDim2.new(1, -4, 0, -6)
CrownPointR.Rotation = 18
CrownPointR.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
CrownPointR.BorderSizePixel = 0
CrownPointR.Parent = CrownBase

local SkullHead = Instance.new("Frame")
SkullHead.Size = UDim2.new(0, 16, 0, 13)
SkullHead.Position = UDim2.new(0.5, -8, 0, 5)
SkullHead.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
SkullHead.BorderSizePixel = 0
SkullHead.Parent = MiscIconHolder
Instance.new("UICorner", SkullHead).CornerRadius = UDim.new(0.4, 0)

local SkullJaw = Instance.new("Frame")
SkullJaw.Size = UDim2.new(0, 10, 0, 5)
SkullJaw.Position = UDim2.new(0.5, -5, 0, 16)
SkullJaw.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
SkullJaw.BorderSizePixel = 0
SkullJaw.Parent = MiscIconHolder
Instance.new("UICorner", SkullJaw).CornerRadius = UDim.new(0, 2)

local LeftEye = Instance.new("Frame")
LeftEye.Size = UDim2.new(0, 3, 0, 4)
LeftEye.Position = UDim2.new(0.5, -5, 0, 7)
LeftEye.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
LeftEye.BorderSizePixel = 0
LeftEye.Parent = MiscIconHolder
Instance.new("UICorner", LeftEye).CornerRadius = UDim.new(0, 1)

local RightEye = Instance.new("Frame")
RightEye.Size = UDim2.new(0, 3, 0, 4)
RightEye.Position = UDim2.new(0.5, 2, 0, 7)
RightEye.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
RightEye.BorderSizePixel = 0
RightEye.Parent = MiscIconHolder
Instance.new("UICorner", RightEye).CornerRadius = UDim.new(0, 1)

local Nose = Instance.new("Frame")
Nose.Size = UDim2.new(0, 2, 0, 3)
Nose.Position = UDim2.new(0.5, -1, 0, 11)
Nose.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Nose.BorderSizePixel = 0
Nose.Parent = MiscIconHolder

local MiscLabel = Instance.new("TextLabel")
MiscLabel.Size = UDim2.new(1, 0, 0, 14)
MiscLabel.Position = UDim2.new(0, 0, 1, -16)
MiscLabel.BackgroundTransparency = 1
MiscLabel.Text = "MISC"
MiscLabel.TextColor3 = Color3.fromRGB(55, 55, 55)
MiscLabel.TextSize = 10
MiscLabel.Font = Enum.Font.Code
MiscLabel.Parent = MiscTabBtn

EspTabBtn.MouseButton1Click:Connect(function()
    closeDropdown()
    closeColorPicker()
    EspTabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    EspLabel.TextColor3 = Color3.fromRGB(225, 37, 37)
    EspPinBody.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    EspPinPoint.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    AimIndicator.Parent = EspTabBtn
    
    AimTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    AimLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    AimV.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    AimH.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    AimC.UIStroke.Color = Color3.fromRGB(80, 80, 80)
    for _, child in ipairs(AimIconHolder:GetChildren()) do
        if child:IsA("Frame") and child ~= AimV and child ~= AimH and child ~= AimC then
            child.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end

    MiscTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    MiscLabel.TextColor3 = Color3.fromRGB(55, 55, 55)
    CrownBase.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointL.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointM.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointR.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    SkullHead.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    SkullJaw.BackgroundColor3 = Color3.fromRGB(55, 55, 55)

    loadEspTab()
end)

AimTabBtn.MouseButton1Click:Connect(function()
    closeDropdown()
    closeColorPicker()
    AimTabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    AimLabel.TextColor3 = Color3.fromRGB(225, 37, 37)
    AimV.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    AimH.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    AimC.UIStroke.Color = Color3.fromRGB(225, 37, 37)
    for _, child in ipairs(AimIconHolder:GetChildren()) do
        if child:IsA("Frame") and child ~= AimV and child ~= AimH and child ~= AimC then
            child.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
        end
    end
    AimIndicator.Parent = AimTabBtn
    
    EspTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    EspLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    EspPinBody.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    EspPinPoint.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

    MiscTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    MiscLabel.TextColor3 = Color3.fromRGB(55, 55, 55)
    CrownBase.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointL.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointM.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    CrownPointR.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    SkullHead.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    SkullJaw.BackgroundColor3 = Color3.fromRGB(55, 55, 55)

    loadAimTab()
end)

MiscTabBtn.MouseButton1Click:Connect(function()
    closeDropdown()
    closeColorPicker()
    MiscTabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    MiscLabel.TextColor3 = Color3.fromRGB(225, 37, 37)
    CrownBase.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    CrownPointL.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    CrownPointM.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    CrownPointR.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    SkullHead.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    SkullJaw.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
    AimIndicator.Parent = MiscTabBtn
    
    EspTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    EspLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    EspPinBody.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    EspPinPoint.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

    AimTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    AimLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    AimV.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    AimH.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    AimC.UIStroke.Color = Color3.fromRGB(80, 80, 80)
    for _, child in ipairs(AimIconHolder:GetChildren()) do
        if child:IsA("Frame") and child ~= AimV and child ~= AimH and child ~= AimC then
            child.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end

    loadMiscTab()
end)

loadEspTab()
EspTabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
EspLabel.TextColor3 = Color3.fromRGB(225, 37, 37)
EspPinBody.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
EspPinPoint.BackgroundColor3 = Color3.fromRGB(225, 37, 37)
AimIndicator.Parent = EspTabBtn
AimTabBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
AimLabel.TextColor3 = Color3.fromRGB(80, 80, 80)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        if not MainFrame.Visible then
            closeDropdown()
            closeColorPicker()
        end
    end
end)

print("[whjte] Crusader | Initializing...")

repeat task.wait() until LocalPlayer.Character
repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

task.spawn(function()
    task.wait(0.5)
    
    print("[whjte] Creating ESP for existing players...")
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            task.spawn(function()
                CreateESP(player)
            end)
        end
    end
    
    Players.PlayerAdded:Connect(function(player)
        task.wait(0.3)
        CreateESP(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        RemoveESP(player)
    end)
    
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] then
                CreateESP(player)
            end
        end
    end)
    
    print("[whjte] ESP initialized | " .. tostring(#Players:GetPlayers() - 1) .. " players")
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        for player, esp in pairs(ESPObjects) do
            if not player or not player.Parent or not Players:FindFirstChild(player.Name) then
                task.spawn(function()
                    RemoveESP(player)
                end)
            end
        end
        
        UpdateESP()
        UpdateGadgetESP()
        UpdateFOVCircle()
        UpdateCrosshair()
        UpdateRadar()
        Aimbot()
    end)
end)