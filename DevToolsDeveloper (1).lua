--[[
    AimbotTest DevTools - Developer Edition
    สำหรับ Roblox Studio / เกมที่คุณเป็นผู้พัฒนาเท่านั้น
    ติดตั้งเป็น LocalScript ใน StarterPlayer > StarterPlayerScripts

    ฟีเจอร์:
    - UI แท็บ Dashboard / Players / Visual / Settings
    - หน้าต่างลากย้ายได้, RightShift ซ่อน/แสดง, ปุ่มลอย
    - รายชื่อผู้เล่นและข้อมูลตัวละครที่มองเห็นได้ตามปกติ
    - FPS counter แบบประมาณค่า
    - ลดเอฟเฟกต์/เงาแบบชั่วคราวและคืนค่าเดิม
    - ขนาด UI, HUD toggle, Cleanup ด้วย End
    - ไม่รวม aimbot, aim assist, wallhack หรือ ESP สำหรับติดตามผู้เล่น
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
if not player then
    warn("[DevTools] ต้องติดตั้งเป็น LocalScript ใน StarterPlayerScripts")
    return
end

local connections = {}
local alive = true
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local C = {
    bg = Color3.fromRGB(15, 16, 23),
    panel = Color3.fromRGB(24, 26, 36),
    panel2 = Color3.fromRGB(32, 34, 47),
    line = Color3.fromRGB(52, 55, 73),
    text = Color3.fromRGB(243, 244, 250),
    muted = Color3.fromRGB(157, 162, 181),
    accent = Color3.fromRGB(124, 98, 255),
    green = Color3.fromRGB(84, 220, 148),
    yellow = Color3.fromRGB(245, 190, 82),
    red = Color3.fromRGB(240, 92, 110),
}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, r)
    make("UICorner", {CornerRadius = UDim.new(0, r or 10)}, obj)
end
local function stroke(obj, color)
    make("UIStroke", {Color = color or C.line, Thickness = 1, Transparency = 0.1}, obj)
end
local function label(parent, text, pos, size, textSize, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1, Position = pos, Size = size,
        Font = font or Enum.Font.Gotham, Text = text, TextSize = textSize or 13,
        TextColor3 = color or C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true,
    }, parent)
end
local function button(parent, text, pos, size, color)
    local b = make("TextButton", {
        Position = pos, Size = size, BackgroundColor3 = color or C.accent,
        BorderSizePixel = 0, AutoButtonColor = true, Text = text,
        Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = C.text,
    }, parent)
    corner(b, 8)
    return b
end

local playerGui = player:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("DevToolsDeveloperUI")
if existing then existing:Destroy() end

local gui = make("ScreenGui", {
    Name = "DevToolsDeveloperUI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local main = make("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 460),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, gui)
corner(main, 15); stroke(main)

local uiScale = make("UIScale", {Scale = 1}, main)
local function fit()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    uiScale.Scale = math.clamp(math.min((v.X - 24) / 700, (v.Y - 24) / 460), 0.55, 1)
end
local function watchCamera()
    local camera = workspace.CurrentCamera
    if camera then
        connect(camera:GetPropertyChangedSignal("ViewportSize"), fit)
        fit()
    end
end
watchCamera()
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)

local header = make("Frame", {
    Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 70),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
corner(header, 15)
make("Frame", {Position = UDim2.new(0,0,1,-14), Size = UDim2.new(1,0,0,14),
    BackgroundColor3 = C.panel, BorderSizePixel = 0}, header)
label(header, "AIMBOTTEST  /  DEVTOOLS", UDim2.fromOffset(22, 11), UDim2.new(1,-100,0,27), 19, C.text, Enum.Font.GothamBold)
label(header, "Developer diagnostics • Local UI", UDim2.fromOffset(23, 39), UDim2.new(1,-100,0,18), 11, C.muted)
local closeBtn = button(header, "×", UDim2.new(1,-52,0,17), UDim2.fromOffset(34,34), C.bg)
closeBtn.TextSize = 20

local sidebar = make("Frame", {
    Position = UDim2.fromOffset(14, 82), Size = UDim2.new(0, 154, 1, -98),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
corner(sidebar, 12); stroke(sidebar)
local content = make("Frame", {
    Position = UDim2.fromOffset(180, 82), Size = UDim2.new(1,-194,1,-98),
    BackgroundTransparency = 1,
}, main)

local pageNames = {"Dashboard", "Players", "Visual", "Settings"}
local pageIcons = {"⌂", "♙", "◈", "⚙"}
local pages, navButtons = {}, {}
local currentPage = "Dashboard"

for _, name in ipairs(pageNames) do
    local page = make("ScrollingFrame", {
        Name = name, Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, content)
    make("UIPadding", {PaddingRight = UDim.new(0,5), PaddingBottom = UDim.new(0,8)}, page)
    make("UIListLayout", {Padding = UDim.new(0,10), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    pages[name] = page
    page.Visible = name == currentPage
end

local function navSelect(name)
    currentPage = name
    for pageName, page in pairs(pages) do page.Visible = pageName == name end
    for pageName, b in pairs(navButtons) do
        b.BackgroundColor3 = pageName == name and C.accent or C.panel
        b.TextColor3 = pageName == name and C.text or C.muted
    end
end

for i, name in ipairs(pageNames) do
    local b = button(sidebar, pageIcons[i] .. "   " .. name,
        UDim2.fromOffset(9, 14 + (i-1)*46), UDim2.new(1,-18,0,38), name == currentPage and C.accent or C.panel)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = name == currentPage and C.text or C.muted
    b.Text = "   " .. pageIcons[i] .. "   " .. name
    navButtons[name] = b
    connect(b.MouseButton1Click, function() navSelect(name) end)
end
label(sidebar, "DEV BUILD  •  v3", UDim2.fromOffset(12, 1), UDim2.new(1,-24,0,12), 9, C.muted)

local function card(parent, height)
    local f = make("Frame", {Size = UDim2.new(1,0,0,height), BackgroundColor3 = C.panel,
        BorderSizePixel = 0}, parent)
    corner(f, 11); stroke(f)
    return f
end
local function heading(parent, text)
    return label(parent, text, UDim2.fromOffset(14,8), UDim2.new(1,-28,0,22), 14, C.text, Enum.Font.GothamSemibold)
end

-- Dashboard
local welcome = card(pages.Dashboard, 82)
heading(welcome, "Overview")
label(welcome, "สถานะเครื่องมือและข้อมูลพื้นฐานของเซิร์ฟเวอร์", UDim2.fromOffset(14,33), UDim2.new(1,-28,0,28), 11, C.muted)
local stats = card(pages.Dashboard, 100)
heading(stats, "Live diagnostics")
local playerStat = label(stats, "PLAYERS     -- / --", UDim2.fromOffset(14,34), UDim2.new(0.5,-14,0,22), 14, C.text, Enum.Font.GothamBold)
local fpsStat = label(stats, "FPS     --", UDim2.new(0.5,0,0,34), UDim2.new(0.5,-14,0,22), 14, C.text, Enum.Font.GothamBold)
local pingStat = label(stats, "CLIENT     Running", UDim2.fromOffset(14,63), UDim2.new(1,-28,0,20), 11, C.green)
local quick = card(pages.Dashboard, 94)
heading(quick, "Quick actions")
local showHudBtn = button(quick, "ซ่อน HUD", UDim2.fromOffset(14,42), UDim2.new(0.33,-14,0,32), C.panel2)
local graphicsBtn = button(quick, "ลดกราฟิก", UDim2.new(0.33,3,0,42), UDim2.new(0.33,-12,0,32), C.accent)
local resetBtn = button(quick, "คืนค่า UI", UDim2.new(0.66,3,0,42), UDim2.new(0.34,-17,0,32), C.panel2)

-- Players page
local playerInfo = card(pages.Players, 72)
heading(playerInfo, "Player inspector")
label(playerInfo, "แสดงข้อมูลทั่วไปของผู้เล่นและตัวละครที่โหลดแล้ว", UDim2.fromOffset(14,34), UDim2.new(1,-28,0,25), 11, C.muted)
local playerListCard = card(pages.Players, 270)
heading(playerListCard, "Players in server")
local playerList = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12,35), Size = UDim2.new(1,-24,1,-45),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, playerListCard)
make("UIListLayout", {Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder}, playerList)
make("UIPadding", {PaddingRight = UDim.new(0,4), PaddingBottom = UDim.new(0,4)}, playerList)

-- Visual page
local hudCard = card(pages.Visual, 86)
heading(hudCard, "HUD")
label(hudCard, "แสดงหรือซ่อนตัวนับจำนวนผู้เล่นด้านบนจอ", UDim2.fromOffset(14,34), UDim2.new(1,-150,0,34), 11, C.muted)
local hudToggle = button(hudCard, "ON", UDim2.new(1,-90,0,29), UDim2.fromOffset(72,30), C.accent)
local gfxCard = card(pages.Visual, 115)
heading(gfxCard, "Graphics optimization")
label(gfxCard, "ปิด PostEffects และเงาชั่วคราวในเครื่องผู้เล่น\nกดปุ่มเดิมอีกครั้งเพื่อคืนค่าที่บันทึกไว้", UDim2.fromOffset(14,35), UDim2.new(1,-160,0,48), 11, C.muted)
local gfxToggle = button(gfxCard, "ลดกราฟิก", UDim2.new(1,-130,0,43), UDim2.fromOffset(112,32), C.accent)
local note = card(pages.Visual, 65)
label(note, "หมายเหตุ: การตั้งค่านี้เป็น Local-only และไม่เปลี่ยนสถานะเซิร์ฟเวอร์", UDim2.fromOffset(14,10), UDim2.new(1,-28,1,-20), 11, C.muted)

-- Settings page
local scaleCard = card(pages.Settings, 100)
heading(scaleCard, "Interface scale")
label(scaleCard, "ปรับขนาดหน้าต่าง", UDim2.fromOffset(14,37), UDim2.new(0.45,0,0,25), 12, C.muted)
local scaleSmall = button(scaleCard, "เล็ก", UDim2.new(0.48,0,0,36), UDim2.new(0.15,-5,0,32), C.panel2)
local scaleNormal = button(scaleCard, "ปกติ", UDim2.new(0.65,0,0,36), UDim2.new(0.15,-5,0,32), C.accent)
local scaleLarge = button(scaleCard, "ใหญ่", UDim2.new(0.82,0,0,36), UDim2.new(0.15,-10,0,32), C.panel2)
local keysCard = card(pages.Settings, 104)
heading(keysCard, "Keyboard shortcuts")
label(keysCard, "RightShift  —  ซ่อน/แสดงเมนู\nEnd  —  ปิด UI และยกเลิก connections\nปุ่ม ☰  —  เปิดเมนูจากปุ่มลอย", UDim2.fromOffset(14,35), UDim2.new(1,-28,0,58), 11, C.muted)
local about = card(pages.Settings, 65)
label(about, "Developer UI • ไม่มีการส่งข้อมูลออกนอกเกม", UDim2.fromOffset(14,10), UDim2.new(1,-28,1,-20), 11, C.green)

-- Floating control and HUD
local floating = button(gui, "☰", UDim2.new(0,14,0.5,-22), UDim2.fromOffset(44,44), C.panel)
floating.TextSize = 19; stroke(floating, C.accent)
local hud = make("Frame", {Name = "PlayerCountHUD", AnchorPoint = Vector2.new(0.5,0),
    Position = UDim2.new(0.5,0,0,12), Size = UDim2.fromOffset(190,34),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0}, gui)
corner(hud, 10); stroke(hud)
local hudText = label(hud, "PLAYERS  0 / 0", UDim2.fromScale(0,0), UDim2.fromScale(1,1), 12, C.text, Enum.Font.GothamSemibold)
hudText.TextXAlignment = Enum.TextXAlignment.Center

local hudEnabled = true
local function updatePlayers()
    local list = Players:GetPlayers()
    playerStat.Text = string.format("PLAYERS     %d / %d", #list, Players.MaxPlayers)
    hudText.Text = string.format("PLAYERS  %d / %d", #list, Players.MaxPlayers)
    hud.Visible = hudEnabled
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, p in ipairs(list) do
        local row = make("Frame", {Size = UDim2.new(1,-2,0,55), BackgroundColor3 = C.panel2, BorderSizePixel = 0}, playerList)
        corner(row, 8)
        local nameText = label(row, p.DisplayName .. "  (@" .. p.Name .. ")", UDim2.fromOffset(10,5), UDim2.new(1,-20,0,20), 12, C.text, Enum.Font.GothamSemibold)
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local hp = hum and string.format("HP %.0f / %.0f", hum.Health, hum.MaxHealth) or "Character not loaded"
        label(row, hp, UDim2.fromOffset(10,28), UDim2.new(1,-20,0,18), 10, C.muted)
    end
end
updatePlayers()
connect(Players.PlayerAdded, updatePlayers)
connect(Players.PlayerRemoving, function() task.defer(updatePlayers) end)

local function setHud(on)
    hudEnabled = on
    hud.Visible = on
    hudToggle.Text = on and "ON" or "OFF"
    showHudBtn.Text = on and "ซ่อน HUD" or "แสดง HUD"
end
connect(hudToggle.MouseButton1Click, function() setHud(not hudEnabled) end)
connect(showHudBtn.MouseButton1Click, function() setHud(not hudEnabled) end)

-- Graphics backup / restore
local graphicsBackup
local graphicsActive = false
local function restoreGraphics()
    if not graphicsActive or not graphicsBackup then return end
    pcall(function() Lighting.GlobalShadows = graphicsBackup.shadows end)
    pcall(function() Lighting.FogEnd = graphicsBackup.fogEnd end)
    for _, item in ipairs(graphicsBackup.effects) do
        if item.instance and item.instance.Parent then
            pcall(function() item.instance.Enabled = item.enabled end)
        end
    end
    graphicsBackup = nil
    graphicsActive = false
    gfxToggle.Text = "ลดกราฟิก"
    graphicsBtn.Text = "ลดกราฟิก"
    pingStat.Text = "CLIENT     Graphics restored"
end
local function toggleGraphics()
    if graphicsActive then
        restoreGraphics()
        return
    end
    graphicsBackup = {shadows = Lighting.GlobalShadows, fogEnd = Lighting.FogEnd, effects = {}}
    for _, item in ipairs(Lighting:GetChildren()) do
        if item:IsA("PostEffect") then
            table.insert(graphicsBackup.effects, {instance = item, enabled = item.Enabled})
            item.Enabled = false
        end
    end
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    graphicsActive = true
    gfxToggle.Text = "คืนค่ากราฟิก"
    graphicsBtn.Text = "คืนค่ากราฟิก"
    pingStat.Text = "CLIENT     Graphics reduced"
end
connect(gfxToggle.MouseButton1Click, toggleGraphics)
connect(graphicsBtn.MouseButton1Click, toggleGraphics)

local function setScale(value)
    uiScale.Scale = value
end
connect(scaleSmall.MouseButton1Click, function() setScale(0.85) end)
connect(scaleNormal.MouseButton1Click, function() setScale(1) end)
connect(scaleLarge.MouseButton1Click, function() setScale(1.08) end)
connect(resetBtn.MouseButton1Click, function()
    setScale(1)
    navSelect("Dashboard")
    setHud(true)
    pingStat.Text = "CLIENT     Settings reset"
end)

local menuOpen = true
local function setMenu(open)
    menuOpen = open
    main.Visible = open
end
connect(closeBtn.MouseButton1Click, function() setMenu(false) end)
connect(floating.MouseButton1Click, function() setMenu(not menuOpen) end)
connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setMenu(not menuOpen)
    elseif input.KeyCode == Enum.KeyCode.End then
        if graphicsActive then restoreGraphics() end
        alive = false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        gui:Destroy()
    end
end)

-- Drag by header
do
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragInput, dragStart, startPos = true, input, input.Position, main.Position
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragInput = false, nil
        end
    end)
end

-- Approximate FPS meter (client frame rate)
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    if not alive then return end
    frames += 1
    elapsed += dt
    if elapsed >= 1 then
        local fps = math.floor(frames / elapsed + 0.5)
        fpsStat.Text = "FPS     " .. tostring(fps)
        frames, elapsed = 0, 0
    end
end)

print("[DevTools] Developer Edition loaded")
