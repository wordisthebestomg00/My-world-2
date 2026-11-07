-- BelleState Utility Hub | BelleKaelonR v2.1 — Rapid Punch
-- Experimental Age of Heroes client UI.
-- Only two controls are implemented: persistent attach to a selected partner,
-- and a continuous punch loop. All other cards are visual placeholders.
-- Punch uses an archived Events.Punch signature; server decides hit/rewards.
-- Use only with a consenting training partner. No cooldown bypass or remote loader.

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
if not LP then return end

local env = (type(getgenv) == "function" and getgenv()) or _G
for _, key in ipairs({"BelleStateUtilityHub", "BelleKaelonDuo"}) do
    local old = env[key]
    if type(old) == "table" and type(old.Shutdown) == "function" then
        pcall(old.Shutdown)
    end
end

local S = {
    closed = false, attach = false, punch = false, persist = true,
    targetId = nil, targetName = nil, distance = 3.4,
    punchInterval = 0.10, rapid = true, punches = 0, nextPunch = 0,
    status = "Select a consenting player to start",
    attachStatus = "OFF", punchStatus = "OFF",
    compact = false, page = "Farming", minimized = false,
}
env.BelleStateUtilityHub = S

local C = {
    bg = Color3.fromRGB(9,13,31),
    panel = Color3.fromRGB(15,21,43),
    tile = Color3.fromRGB(22,27,53),
    navy = Color3.fromRGB(12,17,38),
    line = Color3.fromRGB(62,71,119),
    text = Color3.fromRGB(247,245,255),
    muted = Color3.fromRGB(172,180,210),
    purple = Color3.fromRGB(171,77,255),
    green = Color3.fromRGB(42,243,126),
    blue = Color3.fromRGB(40,188,255),
    red = Color3.fromRGB(255,83,112),
    gold = Color3.fromRGB(255,202,68),
}
local function make(class, p, parent)
    local o = Instance.new(class)
    for k,v in pairs(p or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function round(o, r)
    make("UICorner",{CornerRadius=UDim.new(0,r or 10)},o)
end
local function edge(o,color,thickness,transparency)
    make("UIStroke",{Color=color,Thickness=thickness or 1,Transparency=transparency or 0},o)
end
local function text(parent,t,x,y,w,h,size,color,bold)
    return make("TextLabel", {
        BackgroundTransparency=1,Text=t,TextColor3=color or C.text,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h)
    },parent)
end
local function button(parent,t,x,y,w,h,color,accent)
    local b=make("TextButton",{
        BackgroundColor3=color or C.tile,BorderSizePixel=0,
        Text=t,TextColor3=C.text,Font=Enum.Font.GothamBold,
        TextSize=12,AutoButtonColor=true,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h)
    },parent)
    round(b,8)
    edge(b,accent or C.line,1,0.30)
    return b
end
local function note(t)
    S.status=t
    print("[BelleState] "..t)
end

local function body(player)
    local ch=player and player.Character
    if not ch then return nil end
    local h=ch:FindFirstChildOfClass("Humanoid")
    local root=ch:FindFirstChild("HumanoidRootPart")
    if not h or not root or h.Health<=0 then return nil end
    return ch,h,root
end
local function target()
    if not S.targetName or not S.targetId then return nil end
    local player=Players:GetPlayerByUserId(S.targetId)
    if not player then
        player=Players:FindFirstChild(S.targetName)
        if player and player.UserId~=S.targetId then return nil end
    end
    if player==LP then return nil end
    return player
end
local function punchRemote()
    local e=RS:FindFirstChild("Events")
    local p=e and e:FindFirstChild("Punch")
    return p and p:IsA("RemoteEvent") and p or nil
end

local gui=make("ScreenGui",{
    Name="BelleStateUtilityHub",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=799,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
local ok=pcall(function()
    if type(gethui)=="function" then gui.Parent=gethui()
    else gui.Parent=game:GetService("CoreGui") end
end)
if not ok or not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end

local shadow=make("Frame",{
    BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,
    BorderSizePixel=0,Size=UDim2.fromOffset(1050,634),
    Position=UDim2.fromOffset(0,0)
},gui)
round(shadow,22)
local root=make("Frame",{
    Name="Hub",BackgroundColor3=C.bg,BorderSizePixel=0,
    Active=true,ClipsDescendants=true,
    Size=UDim2.fromOffset(1050,634)
},gui)
round(root,19)
edge(root,C.purple,1.6,.12)
make("UIGradient",{
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(17,20,52)),
        ColorSequenceKeypoint.new(1,C.bg)}),
    Rotation=85
},root)

local header=make("Frame",{
    Name="DragHandle",Active=true,BackgroundColor3=C.navy,
    BorderSizePixel=0,Size=UDim2.fromOffset(1050,92)
},root)
round(header,18)
text(header,"◈",18,17,63,54,49,C.purple,true)
local mainTitle=text(header,"BelleState Utility Hub",92,13,475,43,28,C.text,true)
local subTitle=text(header,"Age of Heroes • BelleKaelonR",95,56,465,22,14,C.muted,false)
local hpDisplay=text(header,"♥ Health: --/--",650,17,198,25,13,C.green,true)
local activeDisplay=text(header,"● Online  |  2 active modules",650,47,250,23,12,C.blue,true)
local minimize=button(header,"−",968,21,30,31,C.panel,C.line)
local close=button(header,"×",1003,21,30,31,C.panel,C.red)

local sidebar=make("Frame",{
    BackgroundColor3=C.navy,BackgroundTransparency=.25,BorderSizePixel=0,
    Position=UDim2.fromOffset(10,102),Size=UDim2.fromOffset(156,486)
},root)
round(sidebar,12)
edge(sidebar,C.line,1,.55)

local content=make("ScrollingFrame",{
    BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(176,102),Size=UDim2.fromOffset(864,486),
    ScrollBarThickness=4,ScrollBarImageColor3=C.purple,
    CanvasSize=UDim2.fromOffset(0,0),
    ScrollingDirection=Enum.ScrollingDirection.Y
},root)
local layout=make("UIGridLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    CellSize=UDim2.fromOffset(270,225),
    CellPadding=UDim2.fromOffset(10,10),
    HorizontalAlignment=Enum.HorizontalAlignment.Center
},content)
local footer=make("Frame",{
    BackgroundColor3=C.navy,BorderSizePixel=0,
    Position=UDim2.fromOffset(10,592),Size=UDim2.fromOffset(1030,34)
},root)
round(footer,8)
edge(footer,C.line,1,.55)
local footerText=text(footer,"◆ BelleState Hub   |   Attach: OFF   |   Punch: OFF",10,5,730,24,11,C.muted,true)
local footerStatus=text(footer,"Experimental build",740,5,285,24,11,C.muted,false)
footerStatus.TextXAlignment=Enum.TextXAlignment.Right

local cards={}
local function card(key,title,desc,color,icon,order,tag)
    local f=make("Frame",{
        Name=key,BackgroundColor3=C.panel,BorderSizePixel=0,
        LayoutOrder=order,Size=UDim2.fromOffset(270,225)
    },content)
    round(f,13);edge(f,color,1.5,.12)
    make("UIGradient",{
        Color=ColorSequence.new(C.tile,C.panel),Rotation=90
    },f)
    text(f,icon,13,11,34,38,29,color,true)
    text(f,title,52,12,178,25,18,C.text,true)
    text(f,desc,52,38,195,35,10,C.muted,false)
    local badge=text(f,tag or "SOON",208,11,55,20,10,tag=="READY" and C.green or C.muted,true)
    badge.TextXAlignment=Enum.TextXAlignment.Right
    local line=make("Frame",{
        BackgroundColor3=color,BackgroundTransparency=.65,BorderSizePixel=0,
        Position=UDim2.fromOffset(10,77),Size=UDim2.new(1,-20,0,1)
    },f)
    cards[key]={frame=f,color=color,badge=badge,line=line}
    return f
end
local function row(parent,label,y,shade)
    text(parent,label,13,y,168,25,11,shade or C.text,false)
    make("Frame",{
        BackgroundColor3=C.line,BackgroundTransparency=.72,
        BorderSizePixel=0,Position=UDim2.fromOffset(12,y+27),
        Size=UDim2.new(1,-24,0,1)
    },parent)
end
local function toggle(parent,y,onColor)
    local b=button(parent,"OFF",202,y,55,26,C.tile,onColor)
    local function render(on)
        b.Text=on and "ON" or "OFF"
        b.BackgroundColor3=on and onColor or C.navy
        return b
    end
    render(false)
    return b,render
end

local telekinesis=card("Telekinesis","Telekinesis",
    "Control, hold and manipulate objects with your mind.",C.purple,"✦",1,"SOON")
row(telekinesis,"Anti Grab",91,C.muted)
row(telekinesis,"Multi Grab",129,C.muted)
row(telekinesis,"Infinite Grab",167,C.muted)
text(telekinesis,"Planned module",160,196,100,18,9,C.muted,false)

local attachCard=card("Farming","Attach System",
    "Persistent target following across character respawns.",C.green,"↗",2,"READY")
local playerButton=button(attachCard,"Select player  ▾",12,84,246,31,C.navy,C.green)
local attachText=text(attachCard,"Infinite Attach Loop",13,126,173,24,11,C.text,false)
local attachToggle,renderAttach=toggle(attachCard,123,C.green)
text(attachCard,"Continue after death / respawn",13,160,176,25,10,C.text,false)
local persistToggle,renderPersist=toggle(attachCard,157,C.green)
local attachStatus=text(attachCard,"Status: OFF",13,196,245,23,10,C.muted,false)
renderPersist(true)

local teleportCard=card("Teleport","Teleport",
    "Waypoints and travel tools for your own world.",C.blue,"◎",3,"SOON")
row(teleportCard,"Safe Zone",91,C.muted)
row(teleportCard,"Quest Area",129,C.muted)
row(teleportCard,"Training Area",167,C.muted)
text(teleportCard,"Planned module",160,196,100,18,9,C.muted,false)

local combatCard=card("Combat","Combat",
    "Continuous punch attempts at a selected partner.",C.red,"✊",4,"READY")
text(combatCard,"Infinite Punch",13,91,178,23,12,C.text,false)
local punchToggle,renderPunch=toggle(combatCard,87,C.red)
text(combatCard,"Punch Interval",13,127,113,22,11,C.muted,false)
local minus=button(combatCard,"−",126,124,31,26,C.navy,C.red)
local intervalLabel=text(combatCard,"0.10s",162,127,51,20,11,C.text,true)
intervalLabel.TextXAlignment=Enum.TextXAlignment.Center
local plus=button(combatCard,"+",220,124,31,26,C.navy,C.red)
local rapidButton=button(combatCard,"Rapid: ON",13,158,110,26,C.red,C.red)
text(combatCard,"Server validates hits",130,161,127,22,10,C.muted,false)
local punchStatus=text(combatCard,"Punches sent: 0",13,195,245,23,10,C.muted,false)

local safetyCard=card("Safety","Safety",
    "Health monitoring and defensive presets.",C.gold,"⬡",5,"SOON")
row(safetyCard,"Emergency Escape",91,C.muted)
row(safetyCard,"Safe Return",129,C.muted)
row(safetyCard,"Health Threshold",167,C.muted)
text(safetyCard,"Planned module",160,196,100,18,9,C.muted,false)

local allCard=card("All","All Abilities",
    "Master controls for the full BelleState build.",C.purple,"◆",6,"SOON")
row(allCard,"Aura Sense",91,C.muted)
row(allCard,"Flight Assist",129,C.muted)
row(allCard,"Speed Burst",167,C.muted)
text(allCard,"Planned module",160,196,100,18,9,C.muted,false)

local pages={
    {"✦","Telekinesis"},{"♧","Farming"},{"◎","Teleport"},
    {"✊","Combat"},{"⬡","Safety"},{"◆","All"},
}
local navButtons={}
for i,entry in ipairs(pages) do
    local b=button(sidebar,entry[1].."  "..entry[2],9,11+(i-1)*66,138,56,C.tile,C.line)
    b.TextXAlignment=Enum.TextXAlignment.Left
    navButtons[entry[2]]=b
end
local overlay=make("Frame",{
    Visible=false,Active=true,BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=.24,BorderSizePixel=0,
    Size=UDim2.fromScale(1,1),ZIndex=20
},root)
local chooser=make("Frame",{
    BackgroundColor3=C.panel,BorderSizePixel=0,Size=UDim2.fromOffset(320,350),
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),ZIndex=21
},overlay)
round(chooser,13);edge(chooser,C.green,1.5,0)
local chooserTitle=text(chooser,"Select training partner",15,12,250,29,17,C.text,true)
chooserTitle.ZIndex=22
local pickerClose=button(chooser,"×",277,12,30,30,C.navy,C.red)
pickerClose.ZIndex=23
local pickerList=make("ScrollingFrame",{
    BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(10,55),
    Size=UDim2.fromOffset(300,284),CanvasSize=UDim2.fromOffset(0,0),
    ScrollBarThickness=4,ScrollBarImageColor3=C.green,ZIndex=22
},chooser)
local pickerLayout=make("UIListLayout",{
    Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder
},pickerList)
pickerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    pickerList.CanvasSize=UDim2.fromOffset(0,pickerLayout.AbsoluteContentSize.Y+10)
end)
local function choosePlayer(plr)
    if not plr or plr==LP then return end
    S.targetId=plr.UserId;S.targetName=plr.Name
    playerButton.Text=plr.DisplayName.."  ▾"
    note("Target selected: @"..plr.Name)
    overlay.Visible=false
end
local function openPicker()
    for _,node in ipairs(pickerList:GetChildren()) do
        if node:IsA("TextButton") or node:IsA("TextLabel") then node:Destroy() end
    end
    local others={}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LP then table.insert(others,plr) end
    end
    table.sort(others,function(a,b) return a.Name:lower()<b.Name:lower() end)
    if #others==0 then
        local no=text(pickerList,"No other players in this server.",8,8,280,40,12,C.muted,false)
        no.ZIndex=23
    else
        for i,plr in ipairs(others) do
            local item=button(pickerList,plr.DisplayName.."  (@"..plr.Name..")",
                0,0,292,36,C.navy,C.line)
            item.LayoutOrder=i
            item.ZIndex=23
            item.Activated:Connect(function() choosePlayer(plr) end)
        end
    end
    overlay.Visible=true
end
playerButton.Activated:Connect(openPicker)
pickerClose.Activated:Connect(function() overlay.Visible=false end)

local function refreshButtons()
    renderAttach(S.attach)
    renderPersist(S.persist)
    renderPunch(S.punch)
end
local function setAttach(enabled)
    if enabled then
        if not target() then
            note("Choose a player in the same server first")
            S.attach=false;refreshButtons();return
        end
        S.attach=true
        note("Attach loop enabled; will reacquire after respawns")
    else
        S.attach=false
        S.attachStatus="OFF"
        note("Attach stopped")
    end
    refreshButtons()
end
local function setPunch(enabled)
    if enabled then
        if not target() then
            note("Choose a consenting training partner first")
            S.punch=false;refreshButtons();return
        end
        if not punchRemote() then
            note("Punch RemoteEvent missing; old Age of Heroes API may have changed")
            S.punch=false;refreshButtons();return
        end
        S.punch=true
        S.nextPunch=0
        note("Rapid punch enabled at "..string.format("%.2f",S.punchInterval).."s; server cooldowns still apply")
    else
        S.punch=false;S.punchStatus="OFF"
        note("Infinite Punch stopped")
    end
    refreshButtons()
end
attachToggle.Activated:Connect(function() setAttach(not S.attach) end)
persistToggle.Activated:Connect(function()
    S.persist=not S.persist
    note(S.persist and "Respawn continuation ON" or "Respawn continuation OFF")
    refreshButtons()
end)
punchToggle.Activated:Connect(function() setPunch(not S.punch) end)
local function setPunchInterval(value, isRapid)
    -- Hard cap: no more than ~14 client calls/sec; actual damage is server-authoritative.
    S.punchInterval=math.clamp(math.floor(value*100+.5)/100,0.07,0.80)
    S.rapid=isRapid==true
    intervalLabel.Text=string.format("%.2fs",S.punchInterval)
    rapidButton.Text=S.rapid and "Rapid: ON" or "Rapid: OFF"
    rapidButton.BackgroundColor3=S.rapid and C.red or C.navy
    if S.punch then S.nextPunch=os.clock()+S.punchInterval end
end
minus.Activated:Connect(function()
    setPunchInterval(S.punchInterval+0.02,false)
end)
plus.Activated:Connect(function()
    setPunchInterval(S.punchInterval-0.02,false)
end)
rapidButton.Activated:Connect(function()
    setPunchInterval(S.rapid and 0.30 or 0.10,not S.rapid)
end)

local float=button(gui,"◆",18,118,52,52,C.panel,C.purple)
float.TextSize=23
float.Visible=false
local screenW,screenH=1100,700
local mobile=false
local firstLayout=true
local function clampPosition(x,y,w,h)
    return math.clamp(x,0,math.max(0,screenW-w)),
        math.clamp(y,0,math.max(0,screenH-h))
end
local function applyPage()
    for name,b in pairs(navButtons) do
        local active=(S.page==name)
        b.BackgroundColor3=active and Color3.fromRGB(65,34,104) or C.tile
    end
    for name,record in pairs(cards) do
        record.frame.Visible=(not mobile) or S.page=="All" or S.page==name
    end
    content.CanvasPosition=Vector2.new(0,0)
end
for name,b in pairs(navButtons) do
    b.Activated:Connect(function()
        S.page=name
        applyPage()
        if name~="Farming" and name~="Combat" then
            note(name.." controls are coming in a later build")
        end
    end)
end
local function redraw()
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize or Vector2.new(1100,700)
    screenW,screenH=vp.X,vp.Y
    mobile=vp.X<780
    local width=mobile and math.max(270,math.min(430,vp.X-18))
        or math.min(1050,vp.X-24)
    local height=mobile and math.max(325,math.min(580,vp.Y-24))
        or math.min(634,vp.Y-24)
    root.Size=UDim2.fromOffset(width,height)
    shadow.Size=UDim2.fromOffset(width,height)
    header.Size=UDim2.fromOffset(width,92)
    local sideWidth=mobile and 68 or 156
    sidebar.Size=UDim2.fromOffset(sideWidth,height-148)
    content.Position=UDim2.fromOffset(sideWidth+20,102)
    local cw=width-sideWidth-31
    local ch=height-148
    content.Size=UDim2.fromOffset(cw,ch)
    footer.Position=UDim2.fromOffset(10,height-39)
    footer.Size=UDim2.fromOffset(width-20,32)
    local cols=mobile and 1 or 3
    local cardW=math.max(180,math.floor((cw-20-(cols-1)*10)/cols))
    layout.CellSize=UDim2.fromOffset(cardW,mobile and 229 or 225)
    layout.CellPadding=UDim2.fromOffset(10,10)
    for _,record in pairs(cards) do
        local f=record.frame
        -- Child elements use proportional right-alignment for touch targets.
        for _,child in ipairs(f:GetChildren()) do
            if child:IsA("TextButton") and child~=playerButton
                and child~=minus and child~=plus then
                if child.Position.X.Offset==202 then
                    child.Position=UDim2.new(1,-68,0,child.Position.Y.Offset)
                end
            end
        end
        if f==attachCard then
            playerButton.Size=UDim2.new(1,-24,0,31)
        end
    end
    for i,entry in ipairs(pages) do
        local b=navButtons[entry[2]]
        b.Position=UDim2.fromOffset(8,10+(i-1)*66)
        b.Size=UDim2.fromOffset(sideWidth-16,54)
        b.Text=mobile and entry[1] or entry[1].."  "..entry[2]
        b.TextXAlignment=mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        b.TextSize=mobile and 22 or 12
    end
    mainTitle.Position=UDim2.fromOffset(mobile and 62 or 92,15)
    mainTitle.Size=UDim2.fromOffset(mobile and width-130 or 480,37)
    mainTitle.TextSize=mobile and 18 or 28
    subTitle.Position=UDim2.fromOffset(mobile and 64 or 95,55)
    subTitle.Size=UDim2.fromOffset(mobile and width-132 or 460,20)
    subTitle.TextSize=mobile and 10 or 14
    hpDisplay.Visible=not mobile
    activeDisplay.Visible=not mobile
    minimize.Position=UDim2.fromOffset(width-80,20)
    close.Position=UDim2.fromOffset(width-44,20)
    footerText.Size=UDim2.fromOffset(mobile and width-20 or 690,24)
    footerText.TextSize=mobile and 9 or 11
    footerStatus.Visible=not mobile
    if not firstLayout then
        local x,y=clampPosition(root.Position.X.Offset,root.Position.Y.Offset,width,height)
        root.Position=UDim2.fromOffset(x,y)
    else
        root.Position=UDim2.fromOffset(math.max(0,(vp.X-width)/2),math.max(0,(vp.Y-height)/2))
        firstLayout=false
    end
    shadow.Position=root.Position+UDim2.fromOffset(5,6)
    chooser.Size=UDim2.fromOffset(math.min(320,width-32),math.min(350,height-40))
    pickerList.Size=UDim2.new(1,-20,1,-66)
    pickerClose.Position=UDim2.new(1,-43,0,12)
    float.Position=UDim2.fromOffset(screenW-65,screenH-82)
    applyPage()
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    content.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+14)
end)
local cam=workspace.CurrentCamera
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(redraw) end
redraw()

-- Drag the hub by its title bar (mouse or mobile touch), clamped on-screen.
local dragging=false
local dragInput=nil
local dragAt=nil
local dragOrigin=nil
header.InputBegan:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.Touch
        and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    dragging=true;dragInput=input;dragAt=input.Position;dragOrigin=root.Position
    input.Changed:Connect(function()
        if input.UserInputState==Enum.UserInputState.End then dragging=false end
    end)
end)
UIS.InputChanged:Connect(function(input)
    if not dragging or S.closed or not dragAt then return end
    if dragInput.UserInputType==Enum.UserInputType.Touch then
        if input~=dragInput then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    local delta=input.Position-dragAt
    local x,y=clampPosition(dragOrigin.X.Offset+delta.X,
        dragOrigin.Y.Offset+delta.Y,root.AbsoluteSize.X,root.AbsoluteSize.Y)
    root.Position=UDim2.fromOffset(x,y)
    shadow.Position=UDim2.fromOffset(x+5,y+6)
end)

local floatDrag=false
local floatFrom=nil
local floatStart=nil
local floatMoved=false
float.InputBegan:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.Touch and
        input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    floatDrag=true;floatFrom=input.Position;floatStart=float.Position;floatMoved=false
    input.Changed:Connect(function()
        if input.UserInputState==Enum.UserInputState.End then floatDrag=false end
    end)
end)
UIS.InputChanged:Connect(function(input)
    if not floatDrag or not floatFrom then return end
    if input.UserInputType~=Enum.UserInputType.Touch and
        input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-floatFrom
    if delta.Magnitude>5 then floatMoved=true end
    local x,y=clampPosition(floatStart.X.Offset+delta.X,
        floatStart.Y.Offset+delta.Y,52,52)
    float.Position=UDim2.fromOffset(x,y)
end)
local function setMinimized(value)
    S.minimized=value
    root.Visible=not value
    shadow.Visible=not value
    float.Visible=value
end
minimize.Activated:Connect(function() setMinimized(true) end)
float.Activated:Connect(function()
    if not floatMoved then setMinimized(false) end
end)

function S.Shutdown()
    if S.closed then return end
    S.attach=false;S.punch=false;S.closed=true
    pcall(function() gui:Destroy() end)
    if env.BelleStateUtilityHub==S then env.BelleStateUtilityHub=nil end
end
close.Activated:Connect(S.Shutdown)

local observedAlive=false
task.spawn(function()
    while not S.closed do
        task.wait(.12)
        local ch,hum,rootPart=body(LP)
        if S.attach then
            if not S.persist and observedAlive and not ch then
                setAttach(false)
                note("Attach stopped on death; enable 'Continue after death' to persist")
            else
                local other=target()
                local tCh,tHum,tRoot=body(other)
                if not other then S.attachStatus="Waiting for selected player"
                elseif not ch then S.attachStatus="Waiting for your respawn"
                elseif not tCh then S.attachStatus="Waiting for target respawn"
                else
                    local wanted=tRoot.CFrame*CFrame.new(0,.15,S.distance)
                    if (rootPart.Position-wanted.Position).Magnitude>.6 then
                        pcall(function()
                            rootPart.AssemblyLinearVelocity=Vector3.zero
                            rootPart.CFrame=CFrame.lookAt(wanted.Position,tRoot.Position)
                        end)
                    end
                    S.attachStatus="Following @"..other.Name
                end
            end
        end
        observedAlive=(ch~=nil)
    end
end)

task.spawn(function()
    local sequence=1
    while not S.closed do
        -- Fine-grained polling avoids an artificial 50ms wait between rapid attacks.
        task.wait(.02)
        if S.punch then
            local other=target()
            local c,h,r=body(LP)
            local tc,th,tr=body(other)
            if not other then S.punchStatus="Waiting for selected player"
            elseif not c then S.punchStatus="Waiting for your respawn"
            elseif not tc then S.punchStatus="Waiting for target respawn"
            elseif tc:FindFirstChildOfClass("ForceField") then
                S.punchStatus="Waiting for spawn protection"
            elseif (r.Position-tr.Position).Magnitude>9 then
                S.punchStatus="Out of range: move closer or enable Attach"
            else
                local now=os.clock()
                if now>=S.nextPunch then
                    local remote=punchRemote()
                    if not remote then
                        setPunch(false)
                        note("Archived Punch remote unavailable")
                    else
                        S.nextPunch=now+S.punchInterval
                        local fired,err=pcall(function()
                            remote:FireServer(0,0.18,sequence)
                        end)
                        if fired then
                            S.punches=S.punches+1
                            S.punchStatus="Attempt sent; server validates hits"
                            sequence=sequence%5+1
                        else
                            S.punchStatus="Punch error: "..tostring(err):sub(1,60)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while not S.closed do
        local _,h=body(LP)
        if h then
            hpDisplay.Text=string.format("♥ Health: %d/%d",
                math.floor(h.Health),math.floor(h.MaxHealth))
        else hpDisplay.Text="♥ Health: respawning" end
        attachStatus.Text="Status: "..S.attachStatus
        punchStatus.Text="Punch calls: "..S.punches.."  •  "..S.punchStatus
        footerText.Text=string.format("◆ BelleState Hub   |   Attach: %s   |   Punch: %s",
            S.attach and "ON" or "OFF",S.punch and "ON" or "OFF")
        footerStatus.Text=S.status
        task.wait(.35)
    end
end)
note("BelleState v2 loaded. Select a player, then enable Attach / Punch.")
