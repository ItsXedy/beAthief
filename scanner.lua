-- Services
local CoreGui = game:GetService("CoreGui")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")

-- Clean up old instances from previous runs
if CoreGui:FindFirstChild("RarityScanner") then
    CoreGui.RarityScanner:Destroy()
end

-- ==========================================
-- 1. CLEANUP ROUTINE: DELETE ANNOYING BUTTONS
-- ==========================================
local function cleanupButtons()
    local bases = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Bases")
    if bases then
        for _, child in ipairs(bases:GetChildren()) do
            if child:FindFirstChild("Buttons") then
                child.Buttons:Destroy()
            end
        end
    end
end

pcall(cleanupButtons)

-- ==========================================
-- 2. CREATE ULTRA-COMPACT UI WITH DRAG SUPPORT
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RarityScanner"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 220)
MainFrame.Position = UDim2.new(0.02, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

-- Smooth Dragging Implementation
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- Title / Header Bar
local Header = Instance.new("TextButton")
Header.Size = UDim2.new(1, 0, 0, 28)
Header.Position = UDim2.new(0, 0, 0, 0)
Header.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Header.TextColor3 = Color3.fromRGB(200, 200, 200)
Header.TextSize = 13
Header.Font = Enum.Font.SourceSansBold
Header.Text = " 🔍 RARITY SCANNER [-]"
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 6)
HeaderCorner.Parent = Header

-- Content Container
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -28)
ContentFrame.Position = UDim2.new(0, 0, 0, 28)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- Scrolling Results Window
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(0, 244, 0, 140)
ScrollFrame.Position = UDim2.new(0, 8, 0, 8)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
ScrollFrame.Parent = ContentFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ScrollFrame

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end)

-- Debugger / Error Box
local ErrorLog = Instance.new("TextLabel")
ErrorLog.Size = UDim2.new(0, 244, 0, 32)
ErrorLog.Position = UDim2.new(0, 8, 0, 154)
ErrorLog.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ErrorLog.TextColor3 = Color3.fromRGB(240, 80, 80)
ErrorLog.TextSize = 10
ErrorLog.Font = Enum.Font.Code
ErrorLog.TextWrapped = true
ErrorLog.TextXAlignment = Enum.TextXAlignment.Left
ErrorLog.TextYAlignment = Enum.TextYAlignment.Top
ErrorLog.Text = "Status: Active (Auto-Scanning)"
ErrorLog.Parent = ContentFrame

local ErrorCorner = Instance.new("UICorner")
ErrorCorner.CornerRadius = UDim.new(0, 4)
ErrorCorner.Parent = ErrorLog

-- Collapse/Expand Logic
local isCollapsed = false
Header.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    if isCollapsed then
        ContentFrame.Visible = false
        MainFrame.Size = UDim2.new(0, 260, 0, 28)
        Header.Text = " 🔍 RARITY SCANNER [+]"
    else
        MainFrame.Size = UDim2.new(0, 260, 0, 220)
        ContentFrame.Visible = true
        Header.Text = " 🔍 RARITY SCANNER [-]"
    end
end)

ScriptContext.Error:Connect(function(message)
    ErrorLog.Text = "ERR: " .. tostring(message)
end)

-- ==========================================
-- 3. BACKGROUND TARGETED SCANNER SYSTEM
-- ==========================================
local textKeywords = {"secret", "mythical", "godly", "celestial"}
local objectKeywords = {"secretgradient", "mythicgradient", "godlyrarity", "celestialrarity"}

-- Finds the closest interior area using AssemblyCenterOfMass vectors from ExitDoors
local function getNamedLocation(entity)
    if not entity then return "Unknown Location" end
    
    local entityPart = entity:IsA("Model") and (entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart")) or entity:IsA("BasePart") and entity
    if not entityPart then return "Map" end
    
    local entityPos = entityPart.Position
    local basesFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Bases")
    if not basesFolder then return "Map Root" end
    
    local closestZoneText = "Unknown Area"
    local shortestDistance = math.huge
    
    -- Scan through all available tycoon room branches
    for _, roomFolder in ipairs(basesFolder:GetChildren()) do
        if string.find(roomFolder.Name, "_Interior") then
            local baseNumber = string.match(roomFolder.Name, "^(%d+)_")
            local exitDoor = roomFolder:FindFirstChild("ExitDoor")
            
            if exitDoor and exitDoor:IsA("BasePart") then
                -- Target precisely utilizing AssemblyCenterOfMass position vectors
                local doorPos = exitDoor.AssemblyCenterOfMass
                
                -- Strict 3D distance check against the definitive floor threshold coordinate
                local distance = (entityPos - doorPos).Magnitude
                
                if distance < shortestDistance then
                    shortestDistance = distance
                    
                    -- Extract display text dynamically using corresponding External display sign layout
                    local exteriorFolder = basesFolder:FindFirstChild(baseNumber .. "_Exterior")
                    local textLabel = exteriorFolder 
                        and exteriorFolder:FindFirstChild("SignOnTop") 
                        and exteriorFolder.SignOnTop:FindFirstChild("SurfaceGui") 
                        and exteriorFolder.SignOnTop.SurfaceGui:FindFirstChild("TextLabel")
                    
                    if textLabel and textLabel:IsA("TextLabel") and textLabel.Text ~= "" then
                        closestZoneText = textLabel.Text
                    else
                        closestZoneText = "Base " .. tostring(baseNumber)
                    end
                end
            end
        end
    end
    
    return closestZoneText
end

local function checkLabelRarity(label)
    if not label or not label:IsA("TextLabel") then return false, nil end
    
    for _, child in ipairs(label:GetChildren()) do
        local childNameLower = string.lower(child.Name)
        for _, objKeyword in ipairs(objectKeywords) do
            if string.find(childNameLower, objKeyword) then
                return true, child.Name
            end
        end
    end
    
    local textLower = string.lower(label.Text)
    for _, textKeyword in ipairs(textKeywords) do
        if string.find(textLower, textKeyword) then
            return true, label.Text
        end
    end
    
    return false, nil
end

local function updateList()
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local foundAny = false

    local function addToList(titleText, locText, color)
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, 0, 0, 34)
        item.BackgroundColor3 = color or Color3.fromRGB(45, 45, 45)
        item.BorderSizePixel = 0
        item.Parent = ScrollFrame
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = item
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -6, 0, 18)
        title.Position = UDim2.new(0, 6, 0, 1)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.Font = Enum.Font.SourceSansBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = titleText
        title.Parent = item
        
        local subtitle = Instance.new("TextLabel")
        subtitle.Size = UDim2.new(1, -6, 0, 14)
        subtitle.Position = UDim2.new(0, 6, 0, 17)
        subtitle.BackgroundTransparency = 1
        subtitle.TextColor3 = Color3.fromRGB(190, 190, 180)
        subtitle.TextSize = 10
        subtitle.Font = Enum.Font.SourceSansItalic
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.Text = "📍 Location: " .. locText
        subtitle.Parent = item
    end

    -- Process Entities Folder
    local entitiesFolder = workspace:FindFirstChild("EntitiesFolder")
    if entitiesFolder then
        for _, entity in ipairs(entitiesFolder:GetChildren()) do
            local rarityLabel = entity:FindFirstChild("Nametag") 
                and entity.Nametag:FindFirstChild("EntityBillboardTemplate") 
                and entity.Nametag.EntityBillboardTemplate:FindFirstChild("RarityLabel")
            
            if rarityLabel then
                local isRare, detectionSource = checkLabelRarity(rarityLabel)
                if isRare then
                    local zoneDescriptor = getNamedLocation(entity)
                    
                    -- Give Celestial a fancy distinct color if detected to make it pop!
                    local rowColor = Color3.fromRGB(140, 40, 40)
                    if string.find(string.lower(detectionSource), "celestial") then
                        rowColor = Color3.fromRGB(70, 40, 150) -- Deep Royal Purple/Blue
                    end
                    
                    addToList(entity.Name .. " [" .. detectionSource .. "]", zoneDescriptor, rowColor)
                    foundAny = true
                end
            end
        end
    end
    
    if not foundAny then
        local emptyItem = Instance.new("TextLabel")
        emptyItem.Size = UDim2.new(1, 0, 0, 22)
        emptyItem.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        emptyItem.TextColor3 = Color3.fromRGB(160, 160, 160)
        emptyItem.TextSize = 11
        emptyItem.Font = Enum.Font.SourceSans
        emptyItem.Text = " No rare entities found."
        emptyItem.TextXAlignment = Enum.TextXAlignment.Left
        emptyItem.Parent = ScrollFrame
        
        local emptyCorner = Instance.new("UICorner")
        emptyCorner.CornerRadius = UDim.new(0, 4)
        emptyCorner.Parent = emptyItem
    end
end

-- Execution Loop
task.spawn(function()
    while task.wait(1) do
        pcall(cleanupButtons)
        pcall(updateList)
    end
end)
