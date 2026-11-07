-- BelleKaelon Rogue | Age of Heroes DUO FARM v1 (experimental)
-- Standalone executor-ready Luau; no HTTP, remote loader, or file permissions.
-- Roles: HOST earns the kill XP; TANK cooperates by returning to a farm spot.
-- Sources: historical AOH 'tank farm' pattern; archived AOH Events.Punch arguments.
-- WARNING: unverified against the live game. May violate experience rules.
-- Only target a consenting friend/alternate account; run separately on both clients.

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.BelleKaelonDuo and type(env.BelleKaelonDuo.Shutdown) == "function" then
    pcall(env.BelleKaelonDuo.Shutdown)
end

local S = {
    running = false, closed = false, runId = 0,
    profile = "FLASH", role = "HOST", targetLevel = 7000,
    attackInterval = 0.48, farmSpot = nil, safeSpot = nil,
    lowHpLimit = 0.20, safetyEnabled = true,
    partner = nil, status = "Ready: configure both accounts",
    punchCount = 0, progressKnown = false,
}
local C = {
    bg = Color3.fromRGB(15, 15, 31), panel = Color3.fromRGB(27, 24, 49),
    violet = Color3.fromRGB(164, 101, 255), cyan = Color3.fromRGB(72, 213, 242),
    white = Color3.fromRGB(240, 238, 255), muted = Color3.fromRGB(164, 160, 191),
    green = Color3.fromRGB(70, 225, 155), red = Color3.fromRGB(245, 95, 129)
}
local function inst(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end
local function corner(obj, radius)
    inst("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, obj)
end
local function setStatus(message)
    S.status = message
    print("[BelleKaelon Duo] " .. message)
end
local function getBody(plr)
    local ch = plr and plr.Character
    if not ch then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 then return ch, hum, root end
    return nil
end
local function findPartner(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil, "Enter your partner's ROBLOX username" end
    local exact = Players:FindFirstChild(name)
    if exact and exact ~= LocalPlayer then return exact end
    local found
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Name:lower() == name:lower() then return player end
        if player ~= LocalPlayer and player.Name:lower():sub(1, #name) == name:lower() then
            if found then return nil, "Username prefix ambiguous; type full username" end
            found = player
        end
    end
    if found then return found end
    return nil, "Partner is not present in this server"
end
local function getPunch()
    local folder = ReplicatedStorage:FindFirstChild("Events")
    local remote = folder and folder:FindFirstChild("Punch")
    if remote and remote:IsA("RemoteEvent") then return remote end
    return nil
end
local function getLevel()
    local candidates = {}
    for _, name in ipairs({"leaderstats", "Stats", "Data", "PlayerData", "DataFolder"}) do
        local folder = LocalPlayer:FindFirstChild(name)
        if folder then table.insert(candidates, folder) end
    end
    table.insert(candidates, LocalPlayer)
    for _, holder in ipairs(candidates) do
        if holder then
            for _, obj in ipairs(holder:GetChildren()) do
                local n = obj.Name:lower()
                if n == "level" or n == "lvl" or n == "levels" then
                    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                        return math.floor(obj.Value), "stat"
                    end
                end
            end
            for _, attr in ipairs({"Level", "Lvl", "level", "LEVEL"}) do
                local value = holder:GetAttribute(attr)
                if type(value) == "number" and value >= 0 then return math.floor(value), "attr" end
            end
        end
    end
    -- Only read a UI label explicitly named for levels; don't confuse it with XP or stats.
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local scanned = 0
        for _, obj in ipairs(pg:GetDescendants()) do
            scanned = scanned + 1
            if scanned > 3000 then break end
            if obj:IsA("TextLabel") then
                local name = obj.Name:lower()
                if name == "level" or name == "levellabel" or name == "lvl" or name == "leveltext" then
                    local text = obj.Text:gsub(",", "")
                    local numeric = text:match("[Ll][Vv][Ll]?%s*:?%s*(%d+)")
                        or text:match("[Ll]evel%s*:?%s*(%d+)")
                        or text:match("^%s*(%d+)%s*$")
                    if numeric then return tonumber(numeric), "hud" end
                end
            end
        end
    end
    return nil, "unknown"
end
local function hasForceField(ch)
    return ch and ch:FindFirstChildOfClass("ForceField") ~= nil
end
local function closeFarm()
    S.running = false
    S.runId = S.runId + 1
end
local ui = inst("ScreenGui", {
    Name = "BelleKaelonDuoFarm", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 809, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})
local parentOk = pcall(function()
    if type(gethui) == "function" then ui.Parent = gethui() else ui.Parent = game:GetService("CoreGui") end
end)
if not parentOk or not ui.Parent then
    ui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local rootGui = inst("Frame", {
    Size = UDim2.fromOffset(342, 470), Position = UDim2.new(.5, -171, .5, -235),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true
}, ui)
corner(rootGui, 14)
inst("UIStroke", {Color = C.violet, Thickness = 1.4, Transparency = .15}, rootGui)

local header = inst("Frame", {Size = UDim2.new(1,0,0,52), BackgroundColor3 = C.panel,
    BorderSizePixel = 0, Active = true}, rootGui)
corner(header, 14)
inst("TextLabel", {Text = "BELLEKAELON  /  DUO FARM", Font = Enum.Font.GothamBold,
    TextSize = 16, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1,-54,0,23), BackgroundTransparency = 1}, header)
inst("TextLabel", {Text = "Age of Heroes  |  Flash + Kaella", Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1,-54,0,18), BackgroundTransparency = 1}, header)
local x = inst("TextButton", {Text = "×", TextSize = 23, Font = Enum.Font.GothamBold,
    TextColor3 = C.white, BackgroundColor3 = Color3.fromRGB(93,38,68),
    Size = UDim2.fromOffset(29,28), Position = UDim2.new(1,-36,0,11), BorderSizePixel = 0}, header)
corner(x, 7)

local scroll = inst("ScrollingFrame", {
    Position = UDim2.fromOffset(11, 60), Size = UDim2.new(1,-22,1,-70),
    CanvasSize = UDim2.fromScale(0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, ScrollBarThickness = 4, ScrollBarImageColor3 = C.violet,
    BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y
}, rootGui)
inst("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)}, scroll)

local function label(text, size, color, height)
    return inst("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = size or 12,
        TextColor3 = color or C.white, BackgroundTransparency = 1,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -4, 0, height or 22)
    }, scroll)
end
local function rowButtons(left, right, leftCB, rightCB)
    local row = inst("Frame", {Size = UDim2.new(1,-2,0,36), BackgroundTransparency = 1}, scroll)
    local a = inst("TextButton", {Text = left, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = C.white, BackgroundColor3 = C.panel, Size = UDim2.new(.49,0,1,0), BorderSizePixel = 0}, row)
    local b = inst("TextButton", {Text = right, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = C.white, BackgroundColor3 = C.panel, Size = UDim2.new(.49,0,1,0),
        Position = UDim2.new(.51,0,0,0), BorderSizePixel = 0}, row)
    corner(a,8); corner(b,8)
    if leftCB then a.MouseButton1Click:Connect(function() leftCB(a,b) end) end
    if rightCB then b.MouseButton1Click:Connect(function() rightCB(a,b) end) end
    return a,b
end
local function input(placeholder, initial)
    local box = inst("TextBox", {Text = initial or "", PlaceholderText = placeholder,
        ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.white, PlaceholderColor3 = C.muted, BackgroundColor3 = C.panel,
        Size = UDim2.new(1,-2,0,36), BorderSizePixel=0}, scroll)
    corner(box,8)
    inst("UIPadding", {PaddingLeft = UDim.new(0,9), PaddingRight = UDim.new(0,9)}, box)
    return box
end
local function wideButton(text, bg, cb)
    local b = inst("TextButton", {Text=text, Font=Enum.Font.GothamBold, TextSize=13,
        TextColor3=C.white, BackgroundColor3=bg, BorderSizePixel=0,
        Size=UDim2.new(1,-2,0,38)}, scroll)
    corner(b,8)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

label("CHARACTER / TARGET LEVEL", 12, C.cyan, 19)
local profileA, profileB = rowButtons("FLASH  →  7000", "KAELLA  →  6000",
    function() S.profile="FLASH"; S.targetLevel=7000; setStatus("Flash profile selected") end,
    function() S.profile="KAELLA"; S.targetLevel=6000; setStatus("Kaella profile selected") end)
label("Choose the profile for THIS client. Set role separately.", 11, C.muted, 20)
label("DUO ROLE", 12, C.cyan, 18)
local hostButton, tankButton = rowButtons("HOST  /  Attacker", "TANK  /  Partner",
    function() S.role="HOST"; setStatus("HOST: move to partner and punch") end,
    function() S.role="TANK"; setStatus("TANK: return to this farm spot after death") end)
label("PARTNER ROBLOX USERNAME (must be in your server)", 11, C.muted, 20)
local partnerInput = input("Exact account username (not display name)", "")
label("HOST follows and attacks selected partner only. TANK holds your farm position.", 11, C.muted, 36)
label("OPTIONS", 12, C.cyan, 18)
local safetyButton, spotButton = rowButtons("Host safety: ON", "Save safe spot",
    function(btn)
        S.safetyEnabled = not S.safetyEnabled
        btn.Text = "Host safety: " .. (S.safetyEnabled and "ON" or "OFF")
    end,
    function()
        local _,_,rp = getBody(LocalPlayer)
        if rp then S.safeSpot = rp.CFrame; setStatus("Safe spot saved at current position")
        else setStatus("Unable to save: your character is not alive") end
    end)
local anchorButton = wideButton("Set / Update tank farm spot here", C.panel, function()
    local _,_,rp = getBody(LocalPlayer)
    if rp then S.farmSpot = rp.CFrame; setStatus("Tank farm spot saved")
    else setStatus("Cannot save farm spot: not alive") end
end)
label("Target XP levels are NOT awarded by this script. The server decides XP.", 10, C.muted, 30)
local levelLabel = label("Your level: scanning...", 12, C.white, 20)
local settingsLabel = label("Selected: FLASH | HOST | Goal: 7000", 11, C.cyan, 20)
local statusLabel = label("Ready", 11, C.white, 44)
local startButton, stopButton = rowButtons("▶ START FARM", "■ STOP",
    function() end,
    function() closeFarm(); setStatus("Stopped manually") end)
startButton.BackgroundColor3 = Color3.fromRGB(33,119,93)
stopButton.BackgroundColor3 = Color3.fromRGB(126,43,69)
wideButton("Close / remove hub", Color3.fromRGB(67,47,79), function() S.Shutdown() end)

-- The host only attacks a selected, present partner. No KillAll/other-player target fallback.
local function hostLoop(token, friend)
    local punch = getPunch()
    if not punch then setStatus("MISSING remote: ReplicatedStorage.Events.Punch (game updated?)"); closeFarm(); return end
    setStatus("HOST running; follow partner and attack after ForceField clears")
    local sequence, lastAttack, lastMove = 1, 0, 0
    while S.running and not S.closed and S.runId == token do
        task.wait(0.10)
        if not friend.Parent then setStatus("Partner left; stopping"); closeFarm(); break end
        local localChar, me, myRoot = getBody(LocalPlayer)
        local friendChar, theirHum, theirRoot = getBody(friend)
        if localChar and me and myRoot then
            if S.safetyEnabled and (me.Health / math.max(me.MaxHealth,1)) < S.lowHpLimit then
                if S.safeSpot then
                    pcall(function() myRoot.CFrame = S.safeSpot end)
                    setStatus("HOST low HP: retreating to saved safe spot")
                else
                    setStatus("HOST low HP: paused (save a safe spot)")
                end
                repeat task.wait(.65) until not S.running or S.runId ~= token
                    or me.Health <= 0 or (me.Health / math.max(me.MaxHealth,1)) >= .55
            elseif friendChar and theirHum and theirRoot and not hasForceField(friendChar) then
                local now = os.clock()
                if now - lastMove >= .18 then
                    lastMove = now
                    local newPos = theirRoot.Position + theirRoot.CFrame.LookVector * 2.6
                    pcall(function()
                        myRoot.AssemblyLinearVelocity = Vector3.zero
                        myRoot.CFrame = CFrame.lookAt(newPos, theirRoot.Position)
                    end)
                end
                if now - lastAttack >= S.attackInterval then
                    lastAttack = now
                    local ok, err = pcall(function() punch:FireServer(0, 0.18, sequence) end)
                    if ok then S.punchCount = S.punchCount + 1
                    else setStatus("Punch call error: " .. tostring(err):sub(1,90)) end
                    sequence = sequence % 5 + 1
                end
            end
        end
    end
end

-- TANK does not attack. It returns to a fixed spot after dying/being knocked away.
local function tankLoop(token, friend)
    if not S.farmSpot then
        local _,_,rp = getBody(LocalPlayer)
        if rp then S.farmSpot = rp.CFrame end
    end
    if not S.farmSpot then setStatus("Stand somewhere alive to set the farm spot"); closeFarm(); return end
    setStatus("TANK active: holding farm spot; HOST should target your username")
    while S.running and not S.closed and S.runId == token do
        task.wait(.5)
        if not friend.Parent then setStatus("Partner left; stopping"); closeFarm(); break end
        local _,hum,rp = getBody(LocalPlayer)
        if hum and rp and S.farmSpot then
            if (rp.Position - S.farmSpot.Position).Magnitude > 3 then
                pcall(function()
                    rp.AssemblyLinearVelocity = Vector3.zero
                    rp.CFrame = S.farmSpot
                end)
            end
        end
    end
end

local function startFarm()
    if S.running then setStatus("Already running; STOP first to change roles"); return end
    local friend, err = findPartner(partnerInput.Text)
    if not friend then setStatus(err); return end
    if friend == LocalPlayer then setStatus("Cannot select yourself"); return end
    S.partner = friend
    local level = getLevel()
    if level and level >= S.targetLevel then
        setStatus("Already at goal level " .. tostring(S.targetLevel) .. "; not starting")
        return
    end
    if not level then setStatus("WARNING: level unreadable; auto-stop cannot be guaranteed") end
    if S.role == "HOST" and not getPunch() then
        setStatus("Punch RemoteEvent not found: old game API may be outdated")
        return
    end
    if S.role == "TANK" and not S.farmSpot then
        local _,_,rp = getBody(LocalPlayer)
        if rp then S.farmSpot = rp.CFrame end
    end
    S.running = true
    S.punchCount = 0
    S.runId = S.runId + 1
    local token = S.runId
    task.spawn(function()
        if S.role == "HOST" then hostLoop(token,friend) else tankLoop(token,friend) end
    end)
end
startButton.MouseButton1Click:Connect(startFarm)

function S.Shutdown()
    if S.closed then return end
    closeFarm()
    S.closed = true
    pcall(function() ui:Destroy() end)
    env.BelleKaelonDuo = nil
end
x.MouseButton1Click:Connect(S.Shutdown)
env.BelleKaelonDuo = S

-- Touch+mouse drag support, intentionally only when interacting with the header.
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=inp.Position; startPos=rootGui.Position
        inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging=false end end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not dragging or not dragStart or not startPos or S.closed then return end
    if inp.UserInputType ~= Enum.UserInputType.Touch and inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta=inp.Position-dragStart
    rootGui.Position=UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X,
        startPos.Y.Scale, startPos.Y.Offset+delta.Y)
end)

-- Read actual server-controlled level if possible; never fabricate progress.
task.spawn(function()
    while not S.closed do
        local level, source = getLevel()
        if level then
            S.progressKnown = true
            levelLabel.Text = string.format("Level: %d / %d  [%s]", level, S.targetLevel, source)
            if S.running and level >= S.targetLevel then
                closeFarm()
                setStatus("GOAL REACHED! Stopped at level " .. tostring(level))
            end
        else
            S.progressKnown = false
            levelLabel.Text = "Level: UNKNOWN | automatic goal-stop not available"
        end
        settingsLabel.Text = string.format("Profile: %s | Role: %s | Goal: %d", S.profile, S.role, S.targetLevel)
        statusLabel.Text = (S.running and "● RUNNING" or "○ STOPPED") .. "   |   Punches: " .. S.punchCount
            .. "\n" .. S.status
        hostButton.BackgroundColor3 = S.role == "HOST" and C.violet or C.panel
        tankButton.BackgroundColor3 = S.role == "TANK" and C.violet or C.panel
        profileA.BackgroundColor3 = S.profile == "FLASH" and Color3.fromRGB(55,90,171) or C.panel
        profileB.BackgroundColor3 = S.profile == "KAELLA" and Color3.fromRGB(55,90,171) or C.panel
        task.wait(.8)
    end
end)

setStatus("Loaded; choose HOST/TANK and partner username. Never run on strangers.")