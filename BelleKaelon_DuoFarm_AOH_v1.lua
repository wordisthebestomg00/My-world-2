-- BelleState Utility Hub | BelleKaelonR v3.2 — adaptive rapid hits
-- Experimental Age of Heroes client UI.
-- Tested only by static inspection: client-side controls for attach, burst punching,
-- saved teleports, local TK, emergency return, aura, hover and speed. Server-authoritative
-- abilities, damage, XP and persistence across game sessions are NOT guaranteed.
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
    punchInterval = 0.04, rapid = true, punches = 0, nextPunch = 0,
    attackMode = "AUTO", burstSize = 100, burstRemaining = 0, burstRunning = false,
    visualUntil = 0, visualSide = 1, effectiveHits = "unknown",
    observedDamage = 0, lastTargetHumanoid=nil, lastTargetHealth=nil,
    autoMethod=1, autoSince=0, autoAttemptCount=0, autoDamageAtStart=0,
    autoFound=false, autoActiveName="unknown", maxInputRate=.035,
    status = "Select a consenting player to start",
    attachStatus = "OFF", punchStatus = "OFF",
    compact = false, page = "Farming", minimized = false,
    antiGrab=false, multiGrab=false, infiniteGrab=false, held={},
    tankHold=false,
    slots={},lastPosition=nil, autoEscape=false,healthThreshold=.20,lastEscape=0,
    aura=false, flight=false, speedBurst=false, highlight=nil,
    flightMover=nil, speedHum=nil, speedBaseline=nil,
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
        LayoutOrder=order,Size=UDim2.fromOffset(270,310)
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
    "Local physics props • client authority dependent.",C.purple,"✦",1,"BETA")
text(telekinesis,"Anti Grab (self)",13,88,173,25,11,C.text,false)
local antiGrabBtn,renderAnti=toggle(telekinesis,88,C.purple)
text(telekinesis,"Multi Grab (up to 3 props)",13,122,173,25,10,C.text,false)
local multiGrabBtn,renderMulti=toggle(telekinesis,122,C.purple)
text(telekinesis,"Infinite Hold",13,156,173,25,11,C.text,false)
local infiniteGrabBtn,renderInfinite=toggle(telekinesis,156,C.purple)
local grabBtn=button(telekinesis,"GRAB PROPS",12,195,116,29,C.navy,C.purple)
local dropBtn=button(telekinesis,"RELEASE",140,195,118,29,C.navy,C.purple)
text(telekinesis,"Co-op Hold (SELF to selected)",13,192,172,25,10,C.text,false)
local tankHoldBtn,renderTankHold=toggle(telekinesis,191,C.green)
grabBtn.Position=UDim2.fromOffset(12,230)
dropBtn.Position=UDim2.new(1,-130,0,230)
grabBtn.Text="GRAB PROPS"
dropBtn.Text="RELEASE"
local tkStatus=text(telekinesis,"Co-op hold uses your own avatar.",13,271,241,22,10,C.muted,false)

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
    "Save locations first • client travel may be corrected.",C.blue,"◎",3,"BETA")
local slotButtons={}
for i,slot in ipairs({"Safe Zone","Quest Area","Boss Spawn","Training Area"}) do
    local y=83+(i-1)*35
    text(teleportCard,slot,12,y,133,25,10,C.text,false)
    local save=button(teleportCard,"SAVE",0,y,43,27,C.navy,C.blue)
    save.Position=UDim2.new(1,-102,0,y)
    local go=button(teleportCard,"GO",0,y,43,27,C.blue,C.blue)
    go.Position=UDim2.new(1,-52,0,y)
    table.insert(slotButtons,{name=slot,save=save,go=go})
end
local returnBtn=button(teleportCard,"RETURN TO PREVIOUS",12,224,246,30,C.navy,C.blue)
returnBtn.Size=UDim2.new(1,-24,0,30)

local combatCard=card("Combat","Combat",
    "Tool activation, bounded bursts and archived remote fallback.",C.red,"✊",4,"READY")
text(combatCard,"Infinite Punch",13,91,178,23,12,C.text,false)
local punchToggle,renderPunch=toggle(combatCard,87,C.red)
text(combatCard,"Punch Interval",13,127,113,22,11,C.muted,false)
local minus=button(combatCard,"−",126,124,31,26,C.navy,C.red)
local intervalLabel=text(combatCard,"0.04s",162,127,51,20,11,C.text,true)
intervalLabel.TextXAlignment=Enum.TextXAlignment.Center
local plus=button(combatCard,"+",220,124,31,26,C.navy,C.red)
local rapidButton=button(combatCard,"Rapid: ON",13,157,109,26,C.red,C.red)
local attackModeBtn=button(combatCard,"Mode: AUTO",130,157,128,26,C.navy,C.red)
local burstChoice=button(combatCard,"100 punches",13,193,105,26,C.navy,C.red)
local burstGo=button(combatCard,"RUN BURST",126,193,132,26,C.red,C.red)
local punchStatus=text(combatCard,"Attempts: 0",13,234,245,22,10,C.muted,false)
local diagnosticBtn=button(combatCard,"CHECK PUNCH SETUP",13,271,244,28,C.navy,C.red)
diagnosticBtn.Size=UDim2.new(1,-26,0,28)

local safetyCard=card("Safety","Safety",
    "Auto-return to your saved Safe Zone at low health.",C.gold,"⬡",5,"BETA")
text(safetyCard,"Emergency Escape",13,88,170,25,11,C.text,false)
local escapeBtn,renderEscape=toggle(safetyCard,88,C.gold)
text(safetyCard,"Health Threshold",13,132,112,25,10,C.text,false)
local hpMinus=button(safetyCard,"−",129,129,30,27,C.navy,C.gold)
local hpThreshold=text(safetyCard,"20%",165,134,45,20,11,C.gold,true)
local hpPlus=button(safetyCard,"+",215,129,30,27,C.navy,C.gold)
local safetyReturn=button(safetyCard,"SAFE RETURN NOW",12,179,246,30,C.navy,C.gold)
safetyReturn.Size=UDim2.new(1,-24,0,30)
local safetyStatus=text(safetyCard,"Save a Safe Zone in Teleport first.",13,233,245,22,10,C.muted,false)

local allCard=card("All","All Abilities",
    "Client-only aura, hover and speed movement.",C.purple,"◆",6,"BETA")
text(allCard,"Aura Sense (target highlight)",13,88,171,25,10,C.text,false)
local auraBtn,renderAura=toggle(allCard,88,C.purple)
text(allCard,"Flight Assist (self hover)",13,126,172,25,10,C.text,false)
local flightBtn,renderFlight=toggle(allCard,126,C.purple)
text(allCard,"Speed Burst (self movement)",13,164,172,25,10,C.text,false)
local speedBtn,renderSpeed=toggle(allCard,164,C.purple)
local abilityStatus=text(allCard,"Client effects • server may override.",13,234,242,22,10,C.muted,false)

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
    S.lastTargetHumanoid=nil;S.lastTargetHealth=nil;S.observedDamage=0
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
    renderTankHold(S.tankHold)
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
        S.tankHold=false
        renderTankHold(false)
        S.attachStatus="OFF"
        note("Attach stopped")
    end
    refreshButtons()
end
-- Co-op hold applies to the account executing this script, never an
-- unwilling target. Run it on the TANK account with attacker selected.
tankHoldBtn.Activated:Connect(function()
    if S.tankHold then
        setAttach(false)
        tkStatus.Text="Co-op hold released"
        return
    end
    if not target() then
        tkStatus.Text="Select attacker on TANK client first"
        note("Co-op hold: select your attacker in the TANK client's player menu")
        return
    end
    S.tankHold=true
    setAttach(true)
    if not S.attach then S.tankHold=false end
    renderTankHold(S.tankHold)
    tkStatus.Text=S.tankHold and "YOUR avatar held to attacker until RELEASE" or "Hold unavailable"
    note("Co-op tank hold "..(S.tankHold and "ON" or "OFF").."; release on this client")
end)
local function setPunch(enabled)
    if enabled then
        if not target() then
            note("Choose a consenting training partner first")
            S.punch=false;refreshButtons();return
        end
        if S.attackMode=="REMOTE" and not punchRemote() then
            note("Archived Punch remote missing. Try AUTO with equipped Fists Tool.")
            S.punch=false;refreshButtons();return
        end
        S.punch=true
        S.nextPunch=0
        S.autoMethod=1
        S.autoFound=false
        S.autoSince=os.clock()
        S.autoAttemptCount=0
        S.autoDamageAtStart=S.observedDamage
        note("Adaptive rapid punch at "..string.format("%.2f",S.punchInterval).."s; server hit validation applies")
    else
        S.punch=false;S.punchStatus="OFF"
        S.burstRunning=false;S.burstRemaining=0
        burstGo.Text="RUN BURST"
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
    -- Schedules up to 25 input actions/sec; actual hits are game-server authoritative.
    S.punchInterval=math.clamp(math.floor(value*100+.5)/100,0.04,0.80)
    S.rapid=isRapid==true
    intervalLabel.Text=string.format("%.2fs",S.punchInterval)
    rapidButton.Text=S.rapid and "Rapid: ON" or "Rapid: OFF"
    rapidButton.BackgroundColor3=S.rapid and C.red or C.navy
    if S.punch then S.nextPunch=os.clock()+S.punchInterval end
end
minus.Activated:Connect(function()
    setPunchInterval(S.punchInterval+0.01,false)
end)
plus.Activated:Connect(function()
    setPunchInterval(S.punchInterval-0.01,false)
end)
rapidButton.Activated:Connect(function()
    setPunchInterval(S.rapid and 0.30 or 0.04,not S.rapid)
end)
local modes={"AUTO","MOBILE","TOOL","INPUT","REMOTE"}
attackModeBtn.Activated:Connect(function()
    local i=table.find(modes,S.attackMode) or 1
    S.attackMode=modes[(i%#modes)+1]
    attackModeBtn.Text="Mode: "..S.attackMode
    note("Attack mode: "..S.attackMode.." (no guaranteed damage)")
end)
local sizes={100,250,500,1000}
burstChoice.Activated:Connect(function()
    local i=table.find(sizes,S.burstSize) or 1
    S.burstSize=sizes[(i%#sizes)+1]
    burstChoice.Text=tostring(S.burstSize).." punches"
end)
burstGo.Activated:Connect(function()
    if S.burstRunning then
        S.burstRunning=false
        S.burstRemaining=0
        setPunch(false)
        burstGo.Text="RUN BURST"
        note("Burst cancelled")
        return
    end
    -- A burst is a count of attempts, not 100-1000 punches per second.
    S.burstRunning=true
    S.burstRemaining=S.burstSize
    S.nextPunch=0
    setPunch(true)
    if not S.punch then
        S.burstRunning=false
        S.burstRemaining=0
    else
        burstGo.Text="STOP BURST"
        note("Starting "..S.burstSize.." punch attempts at "..string.format("%.2f",S.punchInterval).." sec intervals")
    end
end)

local function activePunchTool()
    local ch=LP.Character
    if not ch then return nil end
    for _,tool in ipairs(ch:GetChildren()) do
        local name=tool.Name:lower()
        if tool:IsA("Tool") and tool.Enabled and
           (name:find("punch") or name:find("fist") or
            name:find("hand") or name:find("combat") or
            name:find("melee") or name:find("attack")) then
            return tool
        end
    end
    return nil
end


diagnosticBtn.Activated:Connect(function()
    local ch=LP.Character
    local backpack=LP:FindFirstChildOfClass("Backpack")
    local equipped={}
    local stored={}
    if ch then
        for _,item in ipairs(ch:GetChildren()) do
            if item:IsA("Tool") then table.insert(equipped,item.Name) end
        end
    end
    if backpack then
        for _,item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then table.insert(stored,item.Name) end
        end
    end
    local p=punchRemote()
    local x=string.format("Remote: %s | Equipped: %s | Backpack: %s | Mode: %s | Target: %s",
        p and "PRESENT (signature unverified)" or "MISSING",
        #equipped>0 and table.concat(equipped,",") or "none",
        #stored>0 and table.concat(stored,",") or "none",
        S.attackMode,
        S.targetName or "none")
    S.punchStatus=x
    punchStatus.Text="Diagnostic printed to executor console"
    note(x)
end)

-- Prefer actual game input over an archived RemoteEvent whose arguments are
-- not confirmed. A client-side success is not proof of a server-recognized hit.
local function getAttackButton()
    local playerGui=LP:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local choices={}
    for _,node in ipairs(playerGui:GetDescendants()) do
        if node:IsA("GuiButton") and node.Visible and node.AbsoluteSize.X>18
            and node.AbsoluteSize.Y>18 and not node:IsDescendantOf(gui) then
            local identifier=(node.Name.." "..node.Text):lower()
            if identifier:find("punch",1,true) or identifier:find("attack",1,true)
                or identifier:find("fist",1,true) or identifier:find("fight",1,true)
                or identifier:find("combat",1,true) or identifier:find("m1",1,true) then
                table.insert(choices,node)
            end
        end
    end
    table.sort(choices,function(a,b)
        local aa=a.AbsolutePosition.X+a.AbsoluteSize.X*.5
        local bb=b.AbsolutePosition.X+b.AbsoluteSize.X*.5
        return aa>bb
    end)
    return choices[1]
end

local function sendVirtualClick(position)
    local ok,manager=pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if not ok or not manager then return false,"VirtualInputManager unavailable" end
    local x=math.floor(position.X)
    local y=math.floor(position.Y)
    local success,reason=pcall(function()
        manager:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(.016)
        manager:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    return success,success and "VirtualInput" or tostring(reason)
end

local function sendExecutorClick()
    local clicker=(type(mouse1click)=="function" and mouse1click)
        or (type(env.mouse1click)=="function" and env.mouse1click)
    if clicker then
        local ok,err=pcall(clicker)
        return ok,ok and "mouse1click" or tostring(err)
    end
    local press=(type(mouse1press)=="function" and mouse1press)
        or (type(env.mouse1press)=="function" and env.mouse1press)
    local release=(type(mouse1release)=="function" and mouse1release)
        or (type(env.mouse1release)=="function" and env.mouse1release)
    if press and release then
        local ok,err=pcall(function() press();task.wait(.016);release() end)
        return ok,ok and "mouse1press/release" or tostring(err)
    end
    return false,"Executor click functions unavailable"
end

local function attackByMethod(mode,sequence)
    if mode=="TOOL" then
        local tool=activePunchTool()
        if not tool then return false,"No equipped punch Tool" end
        local ok,err=pcall(function() tool:Activate() end)
        return ok,ok and "Equipped punch Tool" or tostring(err)
    elseif mode=="INPUT" then
        return sendExecutorClick()
    elseif mode=="MOBILE" then
        local button=getAttackButton()
        if button then
            local center=button.AbsolutePosition+button.AbsoluteSize*.5
            local ok,reason=sendVirtualClick(center)
            if ok then return true,"Game mobile attack button" end
            -- Some executors expose firesignal; this does not guarantee
            -- the game engine will treat it as physical user input.
            local fire=type(firesignal)=="function" and firesignal or
                (type(env.firesignal)=="function" and env.firesignal)
            if fire then
                local signaled=pcall(function() fire(button.Activated) end)
                if signaled then return true,"Mobile button Activated signal" end
            end
            return false,reason
        end
        return false,"Game attack button not found"
    elseif mode=="REMOTE" then
        local remote=punchRemote()
        if not remote then return false,"Archived Punch remote missing" end
        local ok,err=pcall(function() remote:FireServer(0,0.18,sequence) end)
        return ok,ok and "Archived remote (unverified)" or tostring(err)
    end
    return false,"Unsupported mode"
end

local automaticMethods=UIS.TouchEnabled
    and {"MOBILE","INPUT","TOOL","REMOTE"}
    or {"INPUT","TOOL","MOBILE","REMOTE"}

local function tryAttack(sequence)
    if S.attackMode=="AUTO" then
        local mode=automaticMethods[S.autoMethod] or automaticMethods[1]
        S.autoActiveName=mode
        local ok,detail=attackByMethod(mode,sequence)
        S.autoAttemptCount=S.autoAttemptCount+1
        -- Advance immediately when the input API is inaccessible.
        if not ok then
            S.autoMethod=S.autoMethod%#automaticMethods+1
            S.autoSince=os.clock()
            S.autoAttemptCount=0
            S.autoDamageAtStart=S.observedDamage
            return false,mode..": "..detail
        end
        return true,mode..": "..detail
    end
    S.autoActiveName=S.attackMode
    return attackByMethod(S.attackMode,sequence)
end

local function updateObservedDamage(targetHumanoid)
    if not targetHumanoid then
        S.lastTargetHumanoid=nil
        S.lastTargetHealth=nil
        return
    end
    if targetHumanoid~=S.lastTargetHumanoid then
        S.lastTargetHumanoid=targetHumanoid
        S.lastTargetHealth=targetHumanoid.Health
        return
    end
    if S.lastTargetHealth and targetHumanoid.Health<S.lastTargetHealth then
        S.observedDamage=S.observedDamage+(S.lastTargetHealth-targetHumanoid.Health)
        if S.attackMode=="AUTO" then
            S.autoFound=true
        end
    end
    S.lastTargetHealth=targetHumanoid.Health
end

local function updateAutoSelection()
    if S.attackMode~="AUTO" or S.autoFound or not S.punch then return end
    if S.autoAttemptCount>=8 and os.clock()-S.autoSince>1.4 then
        if S.observedDamage>S.autoDamageAtStart then
            S.autoFound=true
            return
        end
        S.autoMethod=S.autoMethod%#automaticMethods+1
        S.autoSince=os.clock()
        S.autoAttemptCount=0
        S.autoDamageAtStart=S.observedDamage
        note("No observed HP loss; testing "..automaticMethods[S.autoMethod].." input")
    end
end


-- Client-side beta modules. These are not claims of game-specific authority.
local function getMyRoot()
    local ch,h,r=body(LP)
    return ch,h,r
end
local function saveSlot(name)
    local ch,h,r=getMyRoot()
    if not r then note("Cannot save while respawning"); return end
    S.slots[name]=r.CFrame
    note("Saved "..name.." at your present location")
end
local function travelTo(cf,label)
    if typeof(cf)~="CFrame" then note("Location not saved yet");return false end
    local ch,h,r=getMyRoot()
    if not r then note("Cannot travel while respawning");return false end
    S.lastPosition=r.CFrame
    local ok=pcall(function()
        r.AssemblyLinearVelocity=Vector3.zero
        r.CFrame=cf
    end)
    if ok then note("Travel requested: "..(label or "waypoint").."; server may correct position") end
    return ok
end
for _,item in ipairs(slotButtons) do
    item.save.Activated:Connect(function() saveSlot(item.name) end)
    item.go.Activated:Connect(function()
        travelTo(S.slots[item.name],item.name)
    end)
end
returnBtn.Activated:Connect(function()
    travelTo(S.lastPosition,"previous position")
end)
escapeBtn.Activated:Connect(function()
    S.autoEscape=not S.autoEscape
    renderEscape(S.autoEscape)
    safetyStatus.Text=S.autoEscape and "Auto escape armed" or "Auto escape OFF"
    if S.autoEscape and not S.slots["Safe Zone"] then
        note("Set Safe Zone in Teleport before enabling emergency escape")
    end
end)
hpMinus.Activated:Connect(function()
    S.healthThreshold=math.max(.10,S.healthThreshold-.05)
    hpThreshold.Text=math.floor(S.healthThreshold*100+.5).."%"
end)
hpPlus.Activated:Connect(function()
    S.healthThreshold=math.min(.80,S.healthThreshold+.05)
    hpThreshold.Text=math.floor(S.healthThreshold*100+.5).."%"
end)
safetyReturn.Activated:Connect(function()
    travelTo(S.slots["Safe Zone"],"Safe Zone")
end)

local function clearHeld()
    for _,record in ipairs(S.held) do
        for _,inst in ipairs(record.instances) do
            pcall(function() inst:Destroy() end)
        end
    end
    table.clear(S.held)
    if tkStatus then tkStatus.Text="Released locally held props" end
end
local function eligibleProp(part,ch)
    if not part or not part:IsA("BasePart") or part.Anchored or part.Locked then return false end
    if part:IsDescendantOf(ch) then return false end
    local m=part:FindFirstAncestorOfClass("Model")
    if m and (m:FindFirstChildOfClass("Humanoid")
        or Players:GetPlayerFromCharacter(m)) then return false end
    if part.AssemblyMass>550 then return false end
    for _,record in ipairs(S.held) do
        if record.part==part then return false end
    end
    return true
end
local function grabNearby()
    local ch,h,r=getMyRoot()
    if not r then note("Wait for respawn before grabbing");return end
    if not S.multiGrab then clearHeld() end
    local desired=S.multiGrab and 3 or 1
    local count=0
    local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(r.Position,32) end)
    if not ok then note("Nearby prop query unavailable");return end
    table.sort(parts,function(a,b)
        return (a.Position-r.Position).Magnitude<(b.Position-r.Position).Magnitude
    end)
    for _,part in ipairs(parts) do
        if #S.held>=desired then break end
        if eligibleProp(part,ch) then
            local num=#S.held+1
            local ok2=pcall(function()
                local a=Instance.new("Attachment")
                a.Name="BelleState_PropHold"
                a.Parent=part
                local b=Instance.new("Attachment")
                b.Name="BelleState_RootTarget"
                b.Position=Vector3.new((num-2)*3.5,1.5,-6)
                b.Parent=r
                local ap=Instance.new("AlignPosition")
                ap.Name="BelleState_LocalTK"
                ap.Attachment0=a
                ap.Attachment1=b
                ap.MaxForce=300000
                ap.Responsiveness=35
                ap.RigidityEnabled=false
                ap.Parent=part
                table.insert(S.held,{part=part,instances={ap,a,b}})
            end)
            if ok2 then count=count+1 end
        end
    end
    tkStatus.Text="Local props held: "..#S.held.." (replication unverified)"
    note("Attempted grab of "..count.." nearby props; depends on physics ownership")
    if count>0 and not S.infiniteGrab then
        task.delay(5,function()
            if not S.closed and not S.infiniteGrab then clearHeld() end
        end)
    end
end
antiGrabBtn.Activated:Connect(function()
    S.antiGrab=not S.antiGrab
    renderAnti(S.antiGrab)
    note("Best-effort self anti-grab "..(S.antiGrab and "ON" or "OFF"))
end)
multiGrabBtn.Activated:Connect(function()
    S.multiGrab=not S.multiGrab
    renderMulti(S.multiGrab)
    if not S.multiGrab and #S.held>1 then clearHeld() end
end)
infiniteGrabBtn.Activated:Connect(function()
    S.infiniteGrab=not S.infiniteGrab
    renderInfinite(S.infiniteGrab)
    if not S.infiniteGrab then clearHeld() end
end)
grabBtn.Activated:Connect(grabNearby)
dropBtn.Activated:Connect(function()
    clearHeld()
    if S.tankHold then
        setAttach(false)
        renderTankHold(false)
        tkStatus.Text="Co-op hold released"
    end
end)

local function removeHighlight()
    if S.highlight then pcall(function() S.highlight:Destroy() end) end
    S.highlight=nil
end
auraBtn.Activated:Connect(function()
    S.aura=not S.aura
    renderAura(S.aura)
    if not S.aura then removeHighlight() end
    note("Aura Sense "..(S.aura and "ON" or "OFF").." (visual only)")
end)
flightBtn.Activated:Connect(function()
    S.flight=not S.flight
    renderFlight(S.flight)
    if not S.flight and S.flightMover then
        pcall(function() S.flightMover:Destroy() end)
        S.flightMover=nil
    end
    note("Flight Assist "..(S.flight and "ON" or "OFF").." (local hover)")
end)
speedBtn.Activated:Connect(function()
    S.speedBurst=not S.speedBurst
    renderSpeed(S.speedBurst)
    if not S.speedBurst and S.speedHum then
        pcall(function()
            if S.speedHum.Parent and S.speedBaseline then
                S.speedHum.WalkSpeed=S.speedBaseline
            end
        end)
    end
    note("Speed Burst "..(S.speedBurst and "ON" or "OFF").." (server may override)")
end)

task.spawn(function()
    local antiTick=0
    while not S.closed do
        task.wait(.18)
        local ch,h,r=getMyRoot()
        if h and r then
            if S.autoEscape and h.MaxHealth>0 and
                h.Health/h.MaxHealth<=S.healthThreshold and
                os.clock()-S.lastEscape>=5 and
                S.slots["Safe Zone"] then
                S.lastEscape=os.clock()
                travelTo(S.slots["Safe Zone"],"Low-health escape")
                safetyStatus.Text="Emergency return attempted"
            end
            if S.antiGrab and os.clock()-antiTick>=.5 then
                antiTick=os.clock()
                -- Only target obvious grab constraints on your own rig.
                for _,obj in ipairs(ch:GetDescendants()) do
                    if (obj:IsA("AlignPosition") or obj:IsA("BodyPosition")
                        or obj:IsA("WeldConstraint")) and
                        obj.Name:lower():find("grab") and
                        not obj.Name:find("BelleState_") then
                        pcall(function() obj:Destroy() end)
                    end
                end
                if h.PlatformStand then
                    pcall(function() h.PlatformStand=false end)
                end
            end
            if S.speedBurst then
                if S.speedHum~=h then
                    S.speedHum=h
                    S.speedBaseline=h.WalkSpeed
                end
                if h.WalkSpeed<32 then
                    pcall(function() h.WalkSpeed=32 end)
                end
            end
            if S.flight then
                if not S.flightMover or S.flightMover.Parent~=r then
                    if S.flightMover then pcall(function() S.flightMover:Destroy() end) end
                    local bv=Instance.new("BodyVelocity")
                    bv.Name="BelleState_LocalHover"
                    bv.MaxForce=Vector3.new(1e5,1e5,1e5)
                    bv.P=1800
                    bv.Parent=r
                    S.flightMover=bv
                end
                S.flightMover.Velocity=h.MoveDirection*38
            end
        elseif S.flightMover then
            pcall(function() S.flightMover:Destroy() end)
            S.flightMover=nil
        end
        if S.aura then
            local p=target()
            if p and p.Character then
                if not S.highlight or S.highlight.Adornee~=p.Character then
                    removeHighlight()
                    local hi=Instance.new("Highlight")
                    hi.Name="BelleState_Aura"
                    hi.FillColor=C.purple
                    hi.OutlineColor=C.blue
                    hi.FillTransparency=.65
                    hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                    hi.Adornee=p.Character
                    hi.Parent=gui
                    S.highlight=hi
                end
            else
                removeHighlight()
            end
        end
        if #S.held>0 then
            local missing=false
            for _,v in ipairs(S.held) do
                if not v.part.Parent then missing=true;break end
            end
            if missing then clearHeld() end
        end
    end
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
    layout.CellSize=UDim2.fromOffset(cardW,mobile and 314 or 310)
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

local poseConnection
function S.Shutdown()
    if S.closed then return end
    S.attach=false;S.punch=false;S.closed=true
    clearHeld()
    removeHighlight()
    if poseConnection then pcall(function() poseConnection:Disconnect() end) end
    if S.flightMover then pcall(function() S.flightMover:Destroy() end) end
    if S.speedHum and S.speedBaseline then
        pcall(function() if S.speedHum.Parent then S.speedHum.WalkSpeed=S.speedBaseline end end)
    end
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
        task.wait(.01)
        if S.punch then
            local other=target()
            local ch,h,r=body(LP)
            local tc,th,tr=body(other)
            updateObservedDamage(th)
            if not other then S.punchStatus="Waiting for selected target"
            elseif not ch then S.punchStatus="Waiting for your respawn"
            elseif not tc then S.punchStatus="Waiting for target respawn"
            elseif tc:FindFirstChildOfClass("ForceField") then
                S.punchStatus="Waiting for spawn protection"
            elseif (r.Position-tr.Position).Magnitude>10 then
                S.punchStatus="Out of range (enable Attach)"
            else
                updateAutoSelection()
                if os.clock()>=S.nextPunch then
                    S.nextPunch=os.clock()+S.punchInterval
                    local attacked,method=tryAttack(sequence)
                    if attacked then
                        S.punches=S.punches+1
                        sequence=sequence%5+1
                        S.visualUntil=os.clock()+.09
                        S.visualSide=-S.visualSide
                        S.punchStatus="Attempt: "..method
                        if S.burstRunning then
                            S.burstRemaining=S.burstRemaining-1
                            if S.burstRemaining<=0 then
                                S.burstRunning=false
                                S.punch=false
                                burstGo.Text="RUN BURST"
                                refreshButtons()
                                note("Burst complete: "..S.burstSize..
                                    " inputs; observed HP loss "..math.floor(S.observedDamage))
                            end
                        end
                    else
                        S.punchStatus=method
                        S.nextPunch=os.clock()+.20
                    end
                end
            end
        end
    end
end)

-- Client-side animated punch feedback: this does not change real damage.
-- PreSimulation is used after Animator pose evaluation; supports both classic
-- Motor6D rigs and newer avatar AnimationConstraint rigs where available.
local poseCharacter,poseLeft,poseRight,wasPosing
poseConnection=RunService.PreSimulation:Connect(function()
    if S.closed then return end
    local ch=LP.Character
    if ch~=poseCharacter then
        poseCharacter=ch
        poseLeft,poseRight=nil,nil
        wasPosing=false
        if ch then
            for _,joint in ipairs(ch:GetDescendants()) do
                local isJoint=joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")
                if isJoint then
                    if joint.Name=="LeftShoulder" or joint.Name=="Left Shoulder" then
                        poseLeft=joint
                    elseif joint.Name=="RightShoulder" or joint.Name=="Right Shoulder" then
                        poseRight=joint
                    end
                end
            end
        end
    end
    local posing=(S.punch and os.clock()<S.visualUntil)
    if posing or wasPosing then
        local poseLeftArm=posing and S.visualSide<0
        local poseRightArm=posing and S.visualSide>0
        if poseLeft then
            pcall(function()
                poseLeft.Transform=poseLeftArm
                    and CFrame.Angles(-1.15,0,-.27) or CFrame.new()
            end)
        end
        if poseRight then
            pcall(function()
                poseRight.Transform=poseRightArm
                    and CFrame.Angles(-1.15,0,.27) or CFrame.new()
            end)
        end
    end
    wasPosing=posing
end)

task.spawn(function()
    while not S.closed do
        local _,h=body(LP)
        if h then
            hpDisplay.Text=string.format("♥ Health: %d/%d",
                math.floor(h.Health),math.floor(h.MaxHealth))
        else hpDisplay.Text="♥ Health: respawning" end
        attachStatus.Text="Status: "..S.attachStatus
        punchStatus.Text=string.format("Calls: %d | HP loss: %.0f | %s%s", S.punches, S.observedDamage, S.autoActiveName, S.burstRunning and (" | "..S.burstRemaining.." left") or "")
        -- Health readings are collected in the combat loop (10ms polling).
        footerText.Text=string.format("◆ BelleState Hub   |   Attach: %s   |   Punch: %s",
            S.attach and "ON" or "OFF",S.punch and "ON" or "OFF")
        footerStatus.Text=S.status
        task.wait(.35)
    end
end)
note("BelleState v3.2 loaded. Adaptive input and damage monitoring ready.")
