local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Config = {
    Aimbot = {
        Active = false,
        Key1 = Enum.UserInputType.MouseButton2,
        Key2 = Enum.UserInputType.MouseButton1,
        TargetPart = "Head",
        FOVSize = 10,
        Sensitivity1 = 4,
        Sensitivity2 = 4,
        DrawFOV = false
    },
    ESP = {
        Box = false,
        HealthBar = false,
        Line = false,
        LinePosition = "Up",
        HealthText = false,
        Distance = false,
        OperatorName = false,
        Bone = false,
        VisibleCheck = false,
        Name = false,
        Head = false,
        TeamCheck = false,
        MaxDistance = 500
    },
    Misc = {
        Crosshair = false
    },
    Rage = {
        RageBot = false,
        AntiAim = false,
        ThirdPerson = false,
        ThirdPersonDistance = 10,
        NoRecoil = false,
        NoSpread = false
    }
}

local ESPObjects = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 50
FOVCircle.Radius = 100
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(225, 37, 37)
FOVCircle.Transparency = 1

local CrosshairLines = {}
for i = 1, 4 do
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Transparency = 1
    line.Visible = false
    CrosshairLines[i] = line
end

local function IsAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    return humanoid and rootPart and humanoid.Health > 0
end

local function IsTeamMate(player)
    return player.Team == LocalPlayer.Team
end

local function IsVisible(targetChar)
    local origin = Camera.CFrame.Position
    local targetPos = targetChar.PrimaryPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, (targetPos - origin), rayParams)
    return result == nil
end

local function WorldToViewportPoint(position)
    local vec, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(vec.X, vec.Y), onScreen, vec.Z
end

local function GetClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = Config.Aimbot.FOVSize * 8
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Config.ESP.TeamCheck and IsTeamMate(player) then continue end
            local char = player.Character
            local targetPart = char:FindFirstChild(Config.Aimbot.TargetPart) or char:FindFirstChild("Head")
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

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()

    if not checkcaller() and method == "FireServer" then
        if self.Name == "Hit" and Config.SilentAim then
            local targetPlayer = GetClosestPlayerToCursor()
            if targetPlayer then
                local targetPart = targetPlayer.Character:FindFirstChild(Config.Aimbot.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
                if targetPart then
                    if args[2] and typeof(args[2]) == "Vector3" then
                        args[2] = targetPart.Position
                    end
                    if args[1] then
                        args[1] = targetPart
                    end
                end
            end
        end
    end

    return oldNamecall(self, unpack(args))
end)

local function Aimbot()
    if not Config.Aimbot.Active then return end
    
    local key1Pressed = UserInputService:IsMouseButtonPressed(Config.Aimbot.Key1)
    local key2Pressed = UserInputService:IsMouseButtonPressed(Config.Aimbot.Key2)
    
    if not key1Pressed and not key2Pressed then return end
    
    local rawSens = key1Pressed and Config.Aimbot.Sensitivity1 or Config.Aimbot.Sensitivity2
    local sensitivity
    
    if rawSens == 1 then
        sensitivity = 1.0
    elseif rawSens == 2 then
        sensitivity = 0.45
    elseif rawSens == 3 then
        sensitivity = 0.25
    elseif rawSens == 4 then
        sensitivity = 0.18
    elseif rawSens == 5 then
        sensitivity = 0.13
    elseif rawSens == 6 then
        sensitivity = 0.10
    elseif rawSens == 7 then
        sensitivity = 0.08
    elseif rawSens == 8 then
        sensitivity = 0.06
    elseif rawSens == 9 then
        sensitivity = 0.045
    else
        sensitivity = 0.03
    end
    
    local targetPlayer = GetClosestPlayerToCursor()
    
    if targetPlayer then
        local targetPart = targetPlayer.Character:FindFirstChild(Config.Aimbot.TargetPart) or targetPlayer.Character:FindFirstChild("Head")
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
    
    local esp = {
        Box = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        HealthBarBG = Drawing.new("Square"),
        Line = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthText = Drawing.new("Text"),
        Head = Drawing.new("Circle"),
        Bone = {}
    }
    
    esp.Box.Visible = false
    esp.Box.Color = Color3.fromRGB(255, 255, 255)
    esp.Box.Thickness = 2
    esp.Box.Filled = false
    esp.Box.Transparency = 1
    
    esp.HealthBar.Visible = false
    esp.HealthBar.Filled = true
    esp.HealthBar.Thickness = 1
    esp.HealthBar.Transparency = 1
    
    esp.HealthBarBG.Visible = false
    esp.HealthBarBG.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthBarBG.Filled = false
    esp.HealthBarBG.Thickness = 3
    esp.HealthBarBG.Transparency = 1
    
    esp.Line.Visible = false
    esp.Line.Color = Color3.fromRGB(255, 255, 255)
    esp.Line.Thickness = 2
    esp.Line.Transparency = 1
    
    esp.Name.Visible = false
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Font = 2
    
    esp.Distance.Visible = false
    esp.Distance.Color = Color3.fromRGB(255, 255, 255)
    esp.Distance.Size = 13
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Font = 2
    
    esp.HealthText.Visible = false
    esp.HealthText.Color = Color3.fromRGB(255, 255, 255)
    esp.HealthText.Size = 13
    esp.HealthText.Center = true
    esp.HealthText.Outline = true
    esp.HealthText.Font = 2
    
    esp.Head.Visible = false
    esp.Head.Color = Color3.fromRGB(255, 255, 255)
    esp.Head.Thickness = 2
    esp.Head.NumSides = 30
    esp.Head.Filled = false
    esp.Head.Transparency = 1
    
    for i = 1, 15 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Thickness = 2
        line.Transparency = 1
        table.insert(esp.Bone, line)
    end
    
    ESPObjects[player] = esp
end

local function RemoveESP(player)
    if not ESPObjects[player] then return end
    local esp = ESPObjects[player]
    esp.Box:Remove()
    esp.HealthBar:Remove()
    esp.HealthBarBG:Remove()
    esp.Line:Remove()
    esp.Name:Remove()
    esp.Distance:Remove()
    esp.HealthText:Remove()
    esp.Head:Remove()
    for _, line in pairs(esp.Bone) do
        line:Remove()
    end
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
    
    if not validPoints then
        return nil
    end
    
    return {
        X = minX,
        Y = minY,
        Width = maxX - minX,
        Height = maxY - minY
    }
end

local function UpdateESP()
    for player, esp in pairs(ESPObjects) do
        if player == LocalPlayer or not player or not player.Parent or not Players:FindFirstChild(player.Name) or not IsAlive(player) then
            esp.Box.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        if Config.ESP.TeamCheck and IsTeamMate(player) then
            esp.Box.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
            continue
        end
        
        local char = player.Character
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if rootPart and humanoid then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            
            if distance > Config.ESP.MaxDistance then
                esp.Box.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarBG.Visible = false
                esp.Line.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthText.Visible = false
                esp.Head.Visible = false
                for _, line in pairs(esp.Bone) do line.Visible = false end
                continue
            end
            
            if Config.ESP.VisibleCheck and not IsVisible(char) then
                esp.Box.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarBG.Visible = false
                esp.Line.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthText.Visible = false
                esp.Head.Visible = false
                for _, line in pairs(esp.Bone) do line.Visible = false end
                continue
            end
            
            local box = GetBoundingBox(char)
            
            if box then
                if Config.ESP.Box then
                    esp.Box.Size = Vector2.new(box.Width, box.Height)
                    esp.Box.Position = Vector2.new(box.X, box.Y)
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
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
                            {"Torso", "Left Arm"},
                            {"Torso", "Right Arm"},
                            {"Torso", "Left Leg"},
                            {"Torso", "Right Leg"},
                            {"Head", "Torso"}
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
                                esp.Bone[i].Visible = true
                            end
                        end
                    end
                else
                    for _, line in pairs(esp.Bone) do line.Visible = false end
                end
            else
                esp.Box.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarBG.Visible = false
                esp.Line.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthText.Visible = false
                esp.Head.Visible = false
                for _, line in pairs(esp.Bone) do line.Visible = false end
            end
        else
            esp.Box.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarBG.Visible = false
            esp.Line.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.HealthText.Visible = false
            esp.Head.Visible = false
            for _, line in pairs(esp.Bone) do line.Visible = false end
        end
    end
end


local function UpdateFOVCircle()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = center
    FOVCircle.Radius = Config.Aimbot.FOVSize * 10
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PreciseMenu"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if ScreenGui.Parent ~= CoreGui then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 567, 0, 430)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 85, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 6)
SidebarCorner.Parent = Sidebar

local SidebarCover = Instance.new("Frame")
SidebarCover.Size = UDim2.new(0, 10, 1, 0)
SidebarCover.Position = UDim2.new(1, -10, 0, 0)
SidebarCover.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
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
    Box.TextSize = 11
    Box.Font = Enum.Font.Code
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
    Box.TextSize = 11
    Box.Font = Enum.Font.Code
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
    
    createToggleDropdown("Aimbot Keys", false, "Right Mouse", "Left Mouse", 
        {"Right Mouse", "Left Mouse", "Middle Mouse", "Shift", "Ctrl"}, 32,
        function(key)
            if key == "Right Mouse" then Config.Aimbot.Key1 = Enum.UserInputType.MouseButton2
            elseif key == "Left Mouse" then Config.Aimbot.Key1 = Enum.UserInputType.MouseButton1
            elseif key == "Middle Mouse" then Config.Aimbot.Key1 = Enum.UserInputType.MouseButton3
            elseif key == "Shift" then Config.Aimbot.Key1 = Enum.KeyCode.LeftShift
            elseif key == "Ctrl" then Config.Aimbot.Key1 = Enum.KeyCode.LeftControl
            end
        end,
        function(key)
            if key == "Right Mouse" then Config.Aimbot.Key2 = Enum.UserInputType.MouseButton2
            elseif key == "Left Mouse" then Config.Aimbot.Key2 = Enum.UserInputType.MouseButton1
            elseif key == "Middle Mouse" then Config.Aimbot.Key2 = Enum.UserInputType.MouseButton3
            elseif key == "Shift" then Config.Aimbot.Key2 = Enum.KeyCode.LeftShift
            elseif key == "Ctrl" then Config.Aimbot.Key2 = Enum.KeyCode.LeftControl
            end
        end)
    
    createToggle("Draw Fov", Config.Aimbot.DrawFOV, 64, function(val) Config.Aimbot.DrawFOV = val end)
    
    createToggleDropdown("Mark Target", false, "Head", "Neck", 
        {"Head", "Neck", "Torso", "HumanoidRootPart"}, 96,
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
        Box1.TextSize = 11
        Box1.Font = Enum.Font.Code
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
        Box2.TextSize = 11
        Box2.Font = Enum.Font.Code
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

    createDoubleToggle("ESP Box", Config.ESP.Box, "Player Health Bar", Config.ESP.HealthBar, 0, 
        function(val) Config.ESP.Box = val end,
        function(val) Config.ESP.HealthBar = val end)
    
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
    Box1.TextSize = 11
    Box1.Font = Enum.Font.Code
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

    local Box2 = Instance.new("TextButton")
    Box2.Size = UDim2.new(0, 16, 0, 16)
    Box2.Position = UDim2.new(0, 180, 0, 6)
    Box2.BackgroundColor3 = Config.ESP.HealthText and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
    Box2.BorderSizePixel = 0
    Box2.Text = Config.ESP.HealthText and "✓" or ""
    Box2.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box2.TextSize = 11
    Box2.Font = Enum.Font.Code
    Box2.Parent = Row
    Instance.new("UICorner", Box2).CornerRadius = UDim.new(0, 3)

    local Label2 = Instance.new("TextLabel")
    Label2.Size = UDim2.new(0, 140, 1, 0)
    Label2.Position = UDim2.new(0, 204, 0, 0)
    Label2.BackgroundTransparency = 1
    Label2.Text = "Player Health Text"
    Label2.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label2.TextSize = 12
    Label2.TextXAlignment = Enum.TextXAlignment.Left
    Label2.Font = Enum.Font.Code
    Label2.Parent = Row

    Box1.MouseButton1Click:Connect(function()
        Config.ESP.Line = not Config.ESP.Line
        Box1.BackgroundColor3 = Config.ESP.Line and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box1.Text = Config.ESP.Line and "✓" or ""
    end)
    
    Box2.MouseButton1Click:Connect(function()
        Config.ESP.HealthText = not Config.ESP.HealthText
        Box2.BackgroundColor3 = Config.ESP.HealthText and Color3.fromRGB(225, 37, 37) or Color3.fromRGB(42, 42, 42)
        Box2.Text = Config.ESP.HealthText and "✓" or ""
    end)

    createDoubleToggle("Player Distance", Config.ESP.Distance, "Operator Name", Config.ESP.OperatorName, 64,
        function(val) Config.ESP.Distance = val end,
        function(val) Config.ESP.OperatorName = val end)
    
    createDoubleToggle("Player Bone", Config.ESP.Bone, "Visible Check(Test)", Config.ESP.VisibleCheck, 96,
        function(val) Config.ESP.Bone = val end,
        function(val) Config.ESP.VisibleCheck = val end)
    
    createToggle("Player Name", Config.ESP.Name, 128, function(val) Config.ESP.Name = val end)
    createToggle("Player Head", Config.ESP.Head, 160, function(val) Config.ESP.Head = val end)
    createToggle("Player Team Check", Config.ESP.TeamCheck, 192, function(val) Config.ESP.TeamCheck = val end)
    
    createSlider("Maximum Esp Distance", Config.ESP.MaxDistance, 1, 850, 224, function(val) Config.ESP.MaxDistance = val end)
end

local function loadMiscTab()
    PanelTitle.Text = "Misc Settings"
    for _, child in ipairs(ContentArea:GetChildren()) do child:Destroy() end
    createToggle("Crosshair", Config.Misc.Crosshair, 0, function(val) Config.Misc.Crosshair = val end)
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
        if not MainFrame.Visible then closeDropdown() end
    end
end)

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
        
        if player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Died:Connect(function()
                    if ESPObjects[player] then
                        local esp = ESPObjects[player]
                        esp.Box.Visible = false
                        esp.HealthBar.Visible = false
                        esp.HealthBarBG.Visible = false
                        esp.Line.Visible = false
                        esp.Name.Visible = false
                        esp.Distance.Visible = false
                        esp.HealthText.Visible = false
                        esp.Head.Visible = false
                        for _, line in pairs(esp.Bone) do line.Visible = false end
                    end
                end)
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
    
    player.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.Died:Connect(function()
                if ESPObjects[player] then
                    local esp = ESPObjects[player]
                    esp.Box.Visible = false
                    esp.HealthBar.Visible = false
                    esp.HealthBarBG.Visible = false
                    esp.Line.Visible = false
                    esp.Name.Visible = false
                    esp.Distance.Visible = false
                    esp.HealthText.Visible = false
                    esp.Head.Visible = false
                    for _, line in pairs(esp.Bone) do line.Visible = false end
                end
            end)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

RunService.RenderStepped:Connect(function()
    task.wait()
    
    for player, esp in pairs(ESPObjects) do
        if not player or not player.Parent or not Players:FindFirstChild(player.Name) then
            RemoveESP(player)
        end
    end
    
    UpdateESP()
    UpdateFOVCircle()
    UpdateCrosshair()
    Aimbot()
end)

print("whjte")
