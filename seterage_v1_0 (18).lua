-- seterage v1.0 | MIT License | Copyright (c) 2026
-- Permission is granted to use, copy, modify and distribute this software.
-- Provided AS IS, without warranty. No game/runtime compatibility guarantee.
-- Open source, self-contained: no keys, downloads, telemetry or UI libraries.
-- Paste the WHOLE file into a compatible Roblox Lua execution environment.
-- This is not a Python script and is not a Roblox Studio LocalScript.
-- Auto skillchecks use visible UI rotation and simulated input; live-game unverified.
-- Normal uses measured offsets for the reported Goal/Line textures, or exposed zone geometry.
-- Measured via Roblox asset thumbnails: Goal 81439630577699 and Line 111710874697114.
-- Needle zero points up; white arc is about 104..114 degrees, ordinary arc 115..159.
-- Fast Vault experimentally requests sprint and adjusts one walking-vault animation and brief horizontal velocity.
-- Silent aim for Veil/pistol is not implemented; Hidden M2 remains camera Aim Lock.
-- Next-round panel shows explicit announcements only; it cannot predict hidden RNG.
-- Skill UI layout/angle reference: mycompiler.io/view/EFkMyDPCcgK (Rxmmy).
-- Event names are based on the publicly readable moz3hwolfv2/Violence-District
-- VD Source.lua reference. Current game protocol has not been verified.
-- Closing restores camera and removes overlays/connections.
-- Camera, ESP and perk adapters are experimental and require live-game checks.
-- Perk adapters are unverified against the live game: no data means unknown.
-- Stretch supports native ViewStretch and a legacy matrix mode; neither changes device resolution.
-- auto run(pc) holds native LeftShift while moving; mobile uses an observable Sprint toggle.
-- VD emotes use the native handler when present; the server decides access and original audio.
-- Named configs are stored as data in seterage_profiles.json, with legacy-file migration.
-- No new namecall hooks are installed. Legacy dispatcher, if present, is deactivated.
-- Moonwalk uses camera-relative movement and alternating yaw; live-game unverified.
-- Engine reference: create.roblox.com/docs/reference/engine/classes/Humanoid
-- Engine reference: create.roblox.com/docs/reference/engine/datatypes/CFrame

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "VD Helper must run on the client")

local env = (type(getgenv) == "function" and getgenv()) or _G
local key = "VD_HELPER_OPEN_V01"
local previous = env[key]
if type(previous) == "table" and type(previous.cleanup) == "function" then
    pcall(previous.cleanup)
end
local state = {
    alive = true, esp = false,
    trapMode="Perfect", showHiddenFov=false, showParryFov=false, showTargetLine=false,
    fastVault=false, spikeVault=false, vaultSpeedEnabled=false, vaultSpeedValue=1, shaders=false, shaderPreset="Soft", stretchMode="Auto", nextRound=false, nextRoundMap=false, nextRoundKiller=false, showNextHud=false, backgroundEnabled=false, backgroundImage="",
    moonForward=false,moonBackward=false,moonForwardBind=Enum.KeyCode.Unknown,moonBackwardBind=Enum.KeyCode.Unknown,
    emoteId="507770239",emoteLoop=false,emoteName="Wave",emoteBind=Enum.KeyCode.Unknown,
    noSlowdown=false,selfHealBind=Enum.KeyCode.Unknown,fullbright=false,killerWarn=false,antiAfk=false,maxZoom=false,
    espMeters={generators=true,pumpkins=true,windows=true,pallets=true,hooks=true,killerDistance=true,survivorDistance=true,killerHighlight=false},
    perf={worldProcessed=0,worldMaxBatch=0,skillSnapshots=0},
    autoRunPC=false,autoRunMobile=false,profileName="Default",profiles={},
    skillMode = "Perfect",
    collapsedGroups = {}, daggerSound = false, shotSound = false, misfireSound = false,
    soundOwnOnly = true,
    customSounds = {dagger={id="",volume=1,sources={},mode="BuiltIn",preset="Ping"},shot={id="",volume=1,sources={},mode="BuiltIn",preset="Ping"},misfire={id="",volume=1,sources={},mode="BuiltIn",preset="Ping"}},
    widgetPositions = {}, draggingWidget=false,
    espColors = {
        generators=Color3.fromRGB(255,220,80),pumpkins=Color3.fromRGB(255,145,45),
        windows=Color3.fromRGB(70,220,255),pallets=Color3.fromRGB(100,240,130),hooks=Color3.fromRGB(245,110,145),
        killerHighlight=Color3.fromRGB(255,70,90),killerDistance=Color3.fromRGB(255,90,100),
        survivorDistance=Color3.fromRGB(100,190,255),perks=Color3.fromRGB(240,243,250),
        stats=Color3.fromRGB(240,243,250),hiddenFov=Color3.fromRGB(100,220,255),
        parryFov=Color3.fromRGB(170,110,255),
    },
    menuBind = Enum.KeyCode.RightShift, autoLoad = true, autoSave = true,
    uiWidth = 540, uiHeight = 560, sideWidth = 108, uiTextScale = 1, uiRadius = 10,
    uiFont = "Gotham", uiTheme = "Graphite", showHints = true,
    uiAccentColor = Color3.fromRGB(139,92,246), menuX = 0.5, menuY = 0.5,

    espGenerators = false, espPumpkins = false, espWindows = false, espPallets = false, espHooks=false,
    espLabelsBelow=false,espGeneratorState=false,espPlayerState=false,
    killerDistance = false, survivorDistance = false, espRange = 500,

    crosshair = false, stats = false, parry = false,
    fastBreak = false, breakMultiplier = 3,
    antiKnock = false, antiBlind = false, hiddenAim = false,
    hiddenFov = 150, hiddenStrength = 18, hiddenBind = Enum.KeyCode.Unknown,

    crossSize = 12, crossColor = Color3.fromRGB(255, 255, 255),
    uiScale = 1, menuAlpha = 0, parryRadius = 12, faceSensitivity = 0.7,
    parryBind = Enum.KeyCode.Unknown, parryDelay = 0, parryCooldown = 0.2,
    parryInput = "MouseButton2",

    autoSkill = false, autoTrap = false,
    fov = false, targetFov = 90, stretch = false, aspect = "custom",
    stretchPower = 1.2, perks = false,
}
env[key] = state
state.isDowned=function(char)
    char=char or player.Character
    if not char then return false end
    local hum=char:FindFirstChildOfClass("Humanoid")
    for _,object in ipairs({char,hum})do
        if object then
            for _,name in ipairs({"Downed","IsDowned","Knocked","IsKnocked","KnockedDown","IsKnockedDown","Dying","IsDying","Crawling","Incapacitated"})do
                if object:GetAttribute(name)==true then return true end
                local value=object:FindFirstChild(name)
                if value and value:IsA("BoolValue")and value.Value then return true end
            end
            local status=object:GetAttribute("Status")or object:GetAttribute("State")or object:GetAttribute("HealthState")
            if status==nil then
                for _,name in ipairs({"Status","State","HealthState"})do
                    local value=object:FindFirstChild(name)
                    if value and value:IsA("StringValue")then status=value.Value;break end
                end
            end
            if type(status)=="string"and({downed=true,knocked=true,knockeddown=true,dying=true,crawling=true,incapacitated=true})[status:lower()]then return true end
        end
    end
    return false
end
-- Existing game parameters only. No guessed attributes are created.
do
local buckets={}
state.applyGameRate=function(bucket,object,names,factor,floorValue)
    if not object then return false end
    local entries=buckets[bucket];if not entries then entries={};buckets[bucket]=entries end
    local entry=entries[object]
    if not entry then
        for _,name in ipairs(names)do
            local value=object:GetAttribute(name)
            if type(value)=="number"and value>0 and value<1000 then entry={key=name,original=value};entries[object]=entry;break end
        end
    end
    if not entry then return false end
    local current=object:GetAttribute(entry.key)
    if type(current)~="number"or not(current>0 and current<1000)then return false end
    if entry.applied~=nil and current~=entry.applied then entry.original=current end
    local target=math.max(entry.original*factor,floorValue or 0)
    local ok=pcall(function()if current~=target then object:SetAttribute(entry.key,target)end end)
    if ok then
        entry.applied=target
        state.rateAdapters=state.rateAdapters or {};state.rateAdapters[bucket]={active=true,attribute=entry.key,base=entry.original,requested=target,readback=object:GetAttribute(entry.key)}
    end
    return ok
end
state.restoreGameRate=function(bucket,keep)
    local entries=buckets[bucket];if not entries then return end
    for object,entry in pairs(entries)do if object~=keep then
        pcall(function()if object:GetAttribute(entry.key)==entry.applied then object:SetAttribute(entry.key,entry.original)end end)
        entries[object]=nil
    end end
    if not keep and state.rateAdapters and state.rateAdapters[bucket]then state.rateAdapters[bucket].active=false end
end
end

local function bindLabel(code)
    return code == Enum.KeyCode.Unknown and "не назначен" or code.Name
end

local function mountOverlay(screen, order)
    screen.DisplayOrder = order
    local mounted = false
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and typeof(root) == "Instance" then
            mounted = pcall(function() screen.Parent = root end)
            if mounted then state.overlayMode = "gethui" end
        end
    end
    if not mounted then
        mounted = pcall(function() screen.Parent = game:GetService("CoreGui") end)
        if mounted then state.overlayMode = "CoreGui" end
    end
    if not mounted then screen.Parent = player:WaitForChild("PlayerGui");state.overlayMode = "PlayerGui" end
    -- Optional engine/executor capability; absence is harmless.
    pcall(function() screen.OnTopOfCoreBlur = true end)
end

local connections, highlights = {}, {}
local toggleButtons, parryConnections = {}, {}
local applyExtras, resetParry, refreshParryButtons, crossGui, resetFastBreak, resetExtensions, refreshExtensions, resetWorldEsp, tabBar, resetAudio, resetAvatar, isTrapContext
local collapsed = false
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function removeESP()
    for who, mark in pairs(highlights) do
        mark:Destroy()
        highlights[who] = nil
    end
end
local function isKiller(who)
    local team = who.Team
    if not team then return false end
    local name = string.lower(team.Name)
    return name == "killer" or name == "killers"
end
local function refreshESP()
    local keep = {}
    if state.esp then
        for _, who in ipairs(Players:GetPlayers()) do
            local char = who.Character
            if who ~= player and isKiller(who) and char and char.Parent then
                keep[who] = true
                local mark = highlights[who]
                if not mark or mark.Parent ~= char then
                    if mark then mark:Destroy() end
                    mark = Instance.new("Highlight")
                    mark.Name = "VDHelperKiller"
                    mark.Adornee = char
                    mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    mark.FillColor = state.espColors.killerHighlight
                    mark.OutlineColor = Color3.fromRGB(255, 235, 235)
                    mark.FillTransparency = 0.45
                    mark.Parent = char
                    highlights[who] = mark
                end
                mark.FillColor=state.espColors.killerHighlight
                mark.OutlineColor=state.espColors.killerHighlight
            end
        end
    end
    for who, mark in pairs(highlights) do
        if not keep[who] then mark:Destroy(); highlights[who] = nil end
    end
end

-- Deactivate any observer from earlier releases; this build installs no remote hooks.
local legacyDispatcher=env.VD_HELPER_DISPATCH_V01
if type(legacyDispatcher)=="table"then legacyDispatcher.active=nil end

local gui = Instance.new("ScreenGui")
gui.Name = "VDHelperOpen"
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
mountOverlay(gui, 2000000000)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.ZIndex = 10
panel.Size = UDim2.fromOffset(state.uiWidth, state.uiHeight)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = panel
local function fit()
    local size = gui.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then scale.Scale = state.uiScale; return end
    scale.Scale = math.min(state.uiScale, (size.X - 16) / state.uiWidth, (size.Y - 16) / (collapsed and 46 or state.uiHeight))
    scale.Scale = math.max(0.1, scale.Scale)
end
connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
task.defer(function() if state.alive then fit() end end)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

-- Keep the header fixed while settings scroll on small screens.
local content = Instance.new("ScrollingFrame")
content.Name = "Settings"
content.Position = UDim2.fromOffset(0, 46)
content.Size = UDim2.new(1, 0, 1, -52)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.CanvasSize = UDim2.fromOffset(0, 2300)
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel

local function label(text, y, height)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Position = UDim2.fromOffset(14, y)
    item.Size = UDim2.new(1, -28, 0, height)
    item.Font = Enum.Font.Gotham
    item.TextSize = 12
    item.TextColor3 = Color3.fromRGB(193, 201, 218)
    item.TextWrapped = true
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Text = text
    item.Parent = content
    return item
end
local title = label("seterage v1.0", 8, 32)
title.Parent = panel
title.Size = UDim2.new(1, -110, 0, 32)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Active = true

local function button(text, y, callback)
    local item = Instance.new("TextButton")
    item.Position = UDim2.fromOffset(14, y)
    item.Size = UDim2.new(1, -28, 0, 36)
    item.BackgroundColor3 = Color3.fromRGB(45, 53, 71)
    item.TextColor3 = Color3.fromRGB(242, 245, 255)
    item.Font = Enum.Font.Gotham
    item.TextSize = 12
    item.Text = text
    item.Parent = content
    local rounding = Instance.new("UICorner")
    rounding.CornerRadius = UDim.new(0, 7)
    rounding.Parent = item
    connect(item.Activated, callback)
    return item
end

local restoreCamera, updateOverlays
local perkBox
local status = label("Готов. Все функции выключены.", 864, 40)
-- Visible skillcheck UI adapter.
-- The 104..114 degree window is a reference assumption, not a live-game guarantee.
local virtualInput
pcall(function() virtualInput = game:GetService("VirtualInputManager") end)
local skillPanel, skillUsed = nil, false
local previousNeedle,previousGoal,skillSentAt=nil,nil,0
local pendingSkillReset=false
state.skillTrace={}
local skillTraceAt=0
local function traceSkill(event,needle,goal,extra,force)
    local now=os.clock()
    if not force and now-skillTraceAt<.08 then return end
    skillTraceAt=now
    local row={t=now,event=event,needle=needle and needle.Rotation%360 or nil,
        goal=goal and goal.Rotation%360 or nil,mode=state.skillMode,used=skillUsed,detail=extra}
    if needle and (needle:IsA("ImageLabel")or needle:IsA("ImageButton"))then row.lineImage=needle.Image end
    if goal and (goal:IsA("ImageLabel")or goal:IsA("ImageButton"))then row.goalImage=goal.Image end
    if needle and goal then row.relative=(needle.Rotation-goal.Rotation)%360 end
    local trace=state.skillTrace;trace[#trace+1]=row
    if #trace>240 then table.remove(trace,1)end
end
local function visibleUI(item)
    local node = item
    while node and node ~= player.PlayerGui do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return node == player.PlayerGui
end
-- Overlay rows can live in gethui/CoreGui as well as PlayerGui.
state.menuRowVisible=function(item)
    local node=item
    while node and node~=gui do
        if node:IsA("GuiObject")and not node.Visible then return false end
        node=node.Parent
    end
    return node==gui and state.menuVisible==true
end
-- Native dropdowns, shared by modes, profiles and emotes. No remote UI code.
do
local openControl
state.dropdown=function(y,caption,options,getValue,onPick,id)
    local control={}
    local popup=Instance.new("ScrollingFrame");popup.Name="DropdownList_"..id
    popup.BackgroundColor3=Color3.fromRGB(25,23,35);popup.BorderSizePixel=0
    popup.ScrollBarThickness=4;popup.ScrollingDirection=Enum.ScrollingDirection.Y
    popup.Visible=false;popup.ZIndex=60;popup.Parent=gui
    local choiceConnections={}
    local trigger
    function control:refresh()
        local value=getValue();local name=tostring(value)
        for _,option in ipairs(options())do if option.value==value then name=option.label;break end end
        trigger.Text=caption..": "..name.."  ▾"
    end
    function control:close()
        popup.Visible=false
        if openControl==self then openControl=nil;state.dropdownOpen=false end
    end
    function control:open()
        if openControl and openControl~=self then openControl:close()end
        for _,connection in ipairs(choiceConnections)do connection:Disconnect()end;choiceConnections={}
        for _,child in ipairs(popup:GetChildren())do child:Destroy()end
        local choices=options()
        for i,option in ipairs(choices)do
            local row=Instance.new("TextButton");row.Name="Option_"..tostring(i)
            row.Position=UDim2.fromOffset(4,4+(i-1)*34);row.Size=UDim2.new(1,-8,0,30)
            row.BackgroundColor3=option.value==getValue()and Color3.fromRGB(105,65,180)or Color3.fromRGB(35,32,46)
            row.TextColor3=Color3.fromRGB(240,235,250);row.TextSize=12;row.Font=Enum.Font.Gotham
            row.Text=option.label;row.TextWrapped=true;row.ZIndex=61;row.Parent=popup
            choiceConnections[#choiceConnections+1]=row.Activated:Connect(function()
                self:close();onPick(option.value);self:refresh()
                if state.applyStyle then state.applyStyle()end
            end)
        end
        local height=math.min(246,math.max(42,#choices*34+8))
        popup.Size=UDim2.fromOffset(280,height);popup.CanvasSize=UDim2.fromOffset(0,#choices*34+8)
        popup.CanvasPosition=Vector2.new(0,0);popup.Visible=true;openControl=self;state.dropdownOpen=true
    end
    trigger=button(caption,y,function()if popup.Visible then control:close()else control:open()end end)
    trigger.Name="Dropdown_"..id;control.button=trigger;control.popup=popup
    connect(RunService.RenderStepped,function()
        if not popup.Visible then return end
        if not state.menuVisible or not state.menuRowVisible(trigger)then control:close();return end
        local screen=gui.AbsoluteSize;local position=trigger.AbsolutePosition
        local width=math.min(math.max(trigger.AbsoluteSize.X,160),math.max(160,screen.X-12))
        local height=popup.Size.Y.Offset
        popup.Size=UDim2.fromOffset(width,height)
        popup.Position=UDim2.fromOffset(math.clamp(position.X,4,math.max(4,screen.X-width-4)),
            math.clamp(position.Y+trigger.AbsoluteSize.Y+4,4,math.max(4,screen.Y-height-4)))
    end)
    connect(Input.InputBegan,function(input)
        if not popup.Visible then return end
        if input.KeyCode==Enum.KeyCode.Escape then control:close();return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local point=input.Position
        local function inside(object)
            local pos,size=object.AbsolutePosition,object.AbsoluteSize
            return point.X>=pos.X and point.X<=pos.X+size.X and point.Y>=pos.Y and point.Y<=pos.Y+size.Y
        end
        if not inside(popup)and not inside(trigger)then control:close()end
    end)
    control:refresh();return control
end
end

local function sendSkillInput()
    if not virtualInput then error("VirtualInputManager unavailable") end
    if Input.TouchEnabled and not Input.KeyboardEnabled then
        local root = player.PlayerGui:FindFirstChild("Survivor-mob")
        local controls = root and root:FindFirstChild("Controls")
        local action = controls and controls:FindFirstChild("action")
        local target = action and action:FindFirstChild("check")
        if not target or not target:IsA("GuiObject") or not visibleUI(target) then
            error("Mobile skillcheck button unavailable")
        end
        local inset = game:GetService("GuiService"):GetGuiInset()
        local center = target.AbsolutePosition + target.AbsoluteSize / 2 + inset
        local ok, reason = pcall(function()
            virtualInput:SendTouchEvent(8822, 0, center.X, center.Y)
        end)
        pcall(function() virtualInput:SendTouchEvent(8822, 2, center.X, center.Y) end)
        if not ok then error(reason) end
    else
        local ok, reason = pcall(function()
            virtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        end)
        pcall(function() virtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
        if not ok then error(reason) end
    end
end
local function angleInside(value,first,last)
    return (value-first)%360 <= (last-first)%360
end
local zoneNodesCache=setmetatable({},{__mode="k"})
local function skillNodes(check)
    local cached=zoneNodesCache[check]
    if not cached then
        cached={dirty=true};zoneNodesCache[check]=cached
        pcall(function()connect(check.DescendantAdded,function()cached.dirty=true end)end)
        pcall(function()connect(check.DescendantRemoving,function()cached.dirty=true end)end)
    end
    if cached.dirty then cached.nodes=check:GetDescendants();cached.dirty=false end
    return cached.nodes
end
-- Read actual zone metadata/geometry. Unknown texture masks require a live UI report.
local function skillRange(check,goal,mode)
    local function numeric(object,name)
        local value=object:GetAttribute(name)
        if type(value)=="number"then return value end
        local child=object:FindFirstChild(name)
        if child and(child:IsA("NumberValue")or child:IsA("IntValue"))then return child.Value end
    end
    local function valid(first,last)
        if type(first)~="number"or type(last)~="number"or first~=first or last~=last then return end
        local width=(last-first)%360
        if width>0 and width<=180 then return first%360,last%360 end
    end
    local prefix=mode=="Normal"and "Normal"or "Perfect"
    for _,object in ipairs({goal,check})do
        for _,suffix in ipairs({"Offset",""})do
            local first,last=valid(numeric(object,prefix.."Start"..suffix),numeric(object,prefix.."End"..suffix))
            if first then state.skillZoneSource=prefix.." metadata";return first,last end
        end
    end
    local names=mode=="Normal"and {NormalZone=true,Normal=true,SuccessZone=true,GoodZone=true}
        or {PerfectZone=true,Perfect=true,GreatZone=true,WhiteZone=true}
    for _,object in ipairs(skillNodes(check))do if names[object.Name]and object:IsA("GuiObject")then
        local first,last=valid(numeric(object,"StartOffset"),numeric(object,"EndOffset"))
        if not first then
            local a,b=numeric(object,"StartAngle"),numeric(object,"EndAngle")
            if a and b then first,last=valid(a-goal.Rotation,b-goal.Rotation)end
        end
        if not first then
            local start,width=numeric(object,"ArcStart"),numeric(object,"ArcSize")
            if start and width then first,last=valid(start,start+width)end
        end
        if first then state.skillZoneSource=object.Name;return first,last end
    end end
    local image
    pcall(function()image=tostring(goal.Image):match("%d+")end)
    local line=check:FindFirstChild("Line")
    local reportedNeedle=false;pcall(function()reportedNeedle=tostring(line.Image):match("%d+")=="111710874697114"end)
    if reportedNeedle and image=="81439630577699"then
        state.skillZoneSource="reported generator texture 81439630577699"
        if mode=="Normal"then return 115,159 end
        return 104,114
    elseif reportedNeedle and(image=="114316304044552"or image=="136638024130510")then
        state.skillZoneSource="reported trap texture"
        if mode=="Normal"then return 115,131.5 end
        return 104,114
    end
    if mode=="Perfect"then state.skillZoneSource="legacy Perfect adapter";return 104,114 end
    state.skillZoneSource="unknown Normal mask"
end
state.resolveSkillRange=skillRange
local function linearZoneHit(check,mode)
    local size=check.AbsoluteSize
    if check:GetAttribute("Layout")~="Linear"and not(size.Y>0 and size.X>=size.Y*4)then return nil end
    local needle=check:FindFirstChild("Line")
    if not needle then return nil end
    local function hit(names)
        for _,object in ipairs(skillNodes(check))do if names[object.Name]and object:IsA("GuiObject")and visibleUI(object)then
            local p=needle.AbsolutePosition+needle.AbsoluteSize/2
            local center=object.AbsolutePosition+object.AbsoluteSize/2
            local angle=math.rad(-(object.AbsoluteRotation or object.Rotation or 0))
            local dx,dy=p.X-center.X,p.Y-center.Y
            local x,y=dx*math.cos(angle)-dy*math.sin(angle),dx*math.sin(angle)+dy*math.cos(angle)
            return math.abs(x)<=object.AbsoluteSize.X/2 and math.abs(y)<=object.AbsoluteSize.Y/2
        end end
    end
    local normal={NormalZone=true,Normal=true,SuccessZone=true,GoodZone=true}
    local perfect={PerfectZone=true,Perfect=true,GreatZone=true,WhiteZone=true}
    local result=hit(mode=="Normal"and normal or perfect)
    if result~=nil and mode=="Normal"and hit(perfect)==true then return false end
    return result
end
state.skillTargetAllowed=function(check,goal,relative)
    local linear=linearZoneHit(check,state.skillMode);if linear~=nil then state.skillZoneSource="linear GUI geometry";return linear end
    local first,last=skillRange(check,goal,state.skillMode)
    if not first then return false,"Normal: зона не распознана. Скопируй диагностику в Config."end
    if not angleInside(relative,first,last)then return false end
    if state.skillMode=="Normal"then
        local whiteStart,whiteEnd=skillRange(check,goal,"Perfect")
        if whiteStart and angleInside(relative,whiteStart,whiteEnd)then return false end
    end
    return true
end
connect(RunService.RenderStepped, function(dt)
    if not state.alive or not state.autoSkill or state.isDowned() or(isTrapContext and isTrapContext())then return end
    local prompt=player.PlayerGui:FindFirstChild("SkillCheckPromptGui")
    local check=prompt and prompt:FindFirstChild("Check")
    if not check or not check:IsA("GuiObject")or not visibleUI(check)then
        if skillPanel then traceSkill("closed",nil,nil,nil,true)end
        skillPanel,skillUsed,previousNeedle,previousGoal=nil,false,nil,nil
        pendingSkillReset=false
        return
    end
    if skillPanel~=check then skillPanel,skillUsed,previousNeedle,previousGoal=check,false,nil,nil;pendingSkillReset=false end
    local needle,goal=check:FindFirstChild("Line"),check:FindFirstChild("Goal")
    if not needle or not goal or not needle:IsA("GuiObject")or not goal:IsA("GuiObject")then return end
    local currentNeedle,currentGoal=needle.Rotation%360,goal.Rotation%360
    if skillUsed and previousNeedle and previousGoal and(dt or 0)<=.15 then
        -- A new check may reuse the same visible panel. Only a sharp reset or
        -- target jump rearms it; ordinary 359->0 wrap is a small signed delta.
        local needleJump=math.abs((currentNeedle-previousNeedle+180)%360-180)
        local goalJump=math.abs((currentGoal-previousGoal+180)%360-180)
        if not pendingSkillReset and (needleJump>=55 or goalJump>=12)then
            pendingSkillReset=true
            traceSkill("reset",needle,goal,nil,true)
        end
    end
    if skillUsed and pendingSkillReset and os.clock()-skillSentAt>=.04 then
        skillUsed=false;pendingSkillReset=false
        traceSkill("rearmed",needle,goal,nil,true)
    end
    previousNeedle,previousGoal=currentNeedle,currentGoal
    traceSkill("sample",needle,goal,state.skillZoneSource,false)
    if skillUsed or Input:GetFocusedTextBox()then return end
    local relative=(currentNeedle-currentGoal)%360
    local allowed,reason=state.skillTargetAllowed(check,goal,relative)
    if not allowed then if reason then status.Text=reason end;return end
    skillUsed=true;skillSentAt=os.clock()
    local ok=pcall(sendSkillInput)
    traceSkill("sent",needle,goal,ok and state.skillZoneSource or "input error",true)
    status.Text=ok and "Авто: нажатие отправлено; успех подтверждает игра."
        or "Авто: ввод недоступен. Отключи функцию и пройди проверку вручную."
end)

local function toggle(field, text, y)
    local item
    item = button(text, y, function()
        if field == "parry" and not state.parry and not virtualInput then
            status.Text = "Автопарирование: ввод недоступен в этой среде."
            return
        end
        state[field] = not state[field]
        if field == "parry" and resetParry then resetParry() end
        if field == "fastBreak" and not state.fastBreak and resetFastBreak then resetFastBreak() end
        if applyExtras then applyExtras() end
        if refreshExtensions then refreshExtensions() end
        item.Text = text
        item.BackgroundColor3 = state[field] and Color3.fromRGB(42, 104, 84)
            or Color3.fromRGB(45, 53, 71)
        if field == "esp" then refreshESP() end
        if (field == "fov" or field == "stretch") and not state[field] then
            restoreCamera(field)
        end
        if field == "perks" then updateOverlays() end
        status.Text = "Настройки применены."
    end)
    toggleButtons[field] = {button = item, text = text}
    return item
end
toggle("esp", "Подсветка киллера", 52)
toggle("autoSkill", "Авто скиллчеки", 96)
label("Выбирает зону скиллчека по режиму.", 182, 40)

-- Native projection plus an explicit legacy matrix path; camera writes run last.
local cameraOriginals=setmetatable({},{__mode="k"})
local function clearMatrix(cam,saved)
    if saved.matrix and cam.CFrame==saved.matrix then cam.CFrame=saved.base end
    saved.matrix,saved.base=nil,nil
end
restoreCamera=function(field)
    for cam,saved in pairs(cameraOriginals)do pcall(function()
        if not field or field=="fov"then if saved.fov~=nil then cam.FieldOfView=saved.fov;saved.fov=nil end end
        if not field or field=="stretch"then
            clearMatrix(cam,saved)
            if saved.mode~=nil then
                if saved.stretch~=nil then pcall(function()cam.ViewStretch=saved.stretch end)end
                cam.FieldOfViewMode=saved.mode;saved.mode,saved.stretch=nil,nil
            end
        end
    end)end
end
local unsupportedCamera
local function updateCamera()
    if not state.alive then return end
    local cam=Workspace.CurrentCamera;if not cam then return end
    -- Cameras replaced during respawn must not keep our projection override.
    for old,saved in pairs(cameraOriginals)do if old~=cam then
        pcall(function()clearMatrix(old,saved);if saved.fov then old.FieldOfView=saved.fov end
            if saved.stretch then old.ViewStretch=saved.stretch end;if saved.mode then old.FieldOfViewMode=saved.mode end end)
        cameraOriginals[old]=nil
    end end
    if not(state.fov or state.stretch)then return end
    local saved=cameraOriginals[cam];if not saved then saved={};cameraOriginals[cam]=saved end
    clearMatrix(cam,saved)
    if state.fov then if saved.fov==nil then saved.fov=cam.FieldOfView end;cam.FieldOfView=state.targetFov end
    if not state.stretch then return end
    local view=cam.ViewportSize;if view.X<=0 or view.Y<=0 then return end
    local target=state.aspect=="4:3"and 4/3 or(state.aspect=="16:10"and 16/10 or nil)
    local ratio=math.clamp(target and target/(view.X/view.Y)or 1/state.stretchPower,0.5,2)
    local nativeOk=false
    if state.stretchMode~="Matrix"and unsupportedCamera~=cam then
        nativeOk=pcall(function()
            local old=cam.ViewStretch;if type(old)~="number"then error("ViewStretch unavailable")end
            if saved.mode==nil then saved.mode=cam.FieldOfViewMode;saved.stretch=old end
            cam.FieldOfViewMode=Enum.FieldOfViewMode.Vertical;cam.ViewStretch=ratio
            if math.abs(cam.ViewStretch-ratio)>0.001 then error("ViewStretch write rejected")end
        end)
        if not nativeOk then unsupportedCamera=cam end
    end
    if nativeOk then state.cameraAdapter="Native";return end
    if state.stretchMode=="Native"then state.cameraAdapter="Unsupported";status.Text="Нативный растяг недоступен. Выбери «Матрица».";return end
    if saved.mode==nil then saved.mode=cam.FieldOfViewMode end
    pcall(function()if saved.stretch~=nil then cam.ViewStretch=saved.stretch end end)
    cam.FieldOfViewMode=Enum.FieldOfViewMode.Vertical
    local ok=pcall(function()
        local base=cam.CFrame
        local distortion=CFrame.new(0,0,0,ratio,0,0,0,1,0,0,0,1)
        cam.CFrame=base*distortion;saved.base=base;saved.matrix=cam.CFrame
    end)
    state.cameraAdapter=ok and "Matrix"or "Unsupported"
    if not ok then restoreCamera("stretch");status.Text="Растяг недоступен в этом клиенте."end
end
state.updateCamera=updateCamera
RunService:BindToRenderStep("VDHelperCameraPrepare",Enum.RenderPriority.Camera.Value-1,function()
    for cam,saved in pairs(cameraOriginals)do if saved.matrix then pcall(function()clearMatrix(cam,saved)end)end end
end)
RunService:BindToRenderStep("VDHelperCamera02",Enum.RenderPriority.Last.Value-1,updateCamera)

local numericControls, textControls = {}, {}
local activeSlider
local function numberInput(y,initial,low,high,setValue)
    local row=Instance.new("Frame")
    row.Name="Setting_"..y;row.Position=UDim2.fromOffset(14,y)
    row.Size=UDim2.new(1,-28,0,46);row.BackgroundTransparency=1;row.Parent=content
    local value=Instance.new("TextLabel")
    value.Name="SliderValue";value.Size=UDim2.new(1,0,0,18)
    value.BackgroundTransparency=1;value.TextXAlignment=Enum.TextXAlignment.Right
    value.Font=Enum.Font.RobotoMono;value.TextSize=11;value.TextColor3=Color3.fromRGB(180,180,195);value.Parent=row
    local track=Instance.new("Frame")
    track.Name="SliderTrack";track.Position=UDim2.fromOffset(0,27);track.Size=UDim2.new(1,0,0,4)
    track.BackgroundColor3=Color3.fromRGB(8,8,12);track.BorderSizePixel=0;track.Parent=row
    local fill=Instance.new("Frame")
    fill.Name="SliderFill";fill.Size=UDim2.new(0,0,1,0);fill.BackgroundColor3=Color3.fromRGB(139,92,246);fill.BorderSizePixel=0;fill.Parent=track
    local knob=Instance.new("Frame")
    knob.Name="SliderKnob";knob.AnchorPoint=Vector2.new(0.5,0.5);knob.Size=UDim2.fromOffset(10,10)
    knob.BackgroundColor3=Color3.fromRGB(180,150,255);knob.BorderSizePixel=0;knob.Parent=track
    for _,object in ipairs({track,fill,knob})do local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=object end
    local hit=Instance.new("TextButton")
    hit.Name="SliderHit";hit.BackgroundTransparency=1;hit.Text="";hit.TextSize=12;hit.Font=Enum.Font.Gotham
    hit.Position=UDim2.fromOffset(0,17);hit.Size=UDim2.new(1,0,0,26);hit.Parent=row
    local steps={[484]=0.01,[1244]=0.01,[1510]=0.01,[1740]=0.01,[1810]=0.1,[8120]=0.05,[8420]=0.05,[8720]=0.05}
    local step=steps[y]or 1
    local current=initial
    local function render()
        local ratio=(current-low)/(high-low)
        fill.Size=UDim2.new(ratio,0,1,0);knob.Position=UDim2.new(ratio,0,0.5,0)
        value.Text=step<1 and string.format("%.2f",current):gsub("0+$",""):gsub("%.$","")or tostring(math.floor(current+0.5))
    end
    local function set(v)
        current=math.clamp(math.floor((v-low)/step+0.5)*step+low,low,high)
        render();setValue(current)
    end
    local function drag(input)
        local width=track.AbsoluteSize.X
        if width<=0 then return end
        local ratio=math.clamp((input.Position.X-track.AbsolutePosition.X)/width,0,1)
        set(low+ratio*(high-low))
    end
    numericControls[y]={box=row,set=set,get=function()return current end,track=track}
    connect(hit.InputBegan,function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        activeSlider={input=input,drag=drag};drag(input)
    end)
    render()
    return row
end
connect(Input.InputChanged,function(input)
    if activeSlider and(input==activeSlider.input or input.UserInputType==Enum.UserInputType.MouseMovement)then activeSlider.drag(input)end
end)
connect(Input.InputEnded,function(input)
    if activeSlider and(input==activeSlider.input or input.UserInputType==Enum.UserInputType.MouseButton1)then activeSlider=nil end
end)

label("КАМЕРА", 230, 24)
toggle("fov", "FOV", 260)
label("Вертикальный FOV: от 40 до 120", 302, 24)
numberInput(330, 90, 40, 120, function(v) state.targetFov = v; updateCamera() end)
toggle("stretch", "Растяжение", 372)
do
local choice=state.dropdown(373,"Метод",function()return {{value="Auto",label="Авто"},{value="Native",label="Нативный"},{value="Matrix",label="Матрица"}}end,
    function()return state.stretchMode end,function(value)restoreCamera("stretch");unsupportedCamera=nil;state.stretchMode=value;updateCamera()end,"stretchMode")
state.refreshStretchUI=function()choice:refresh()end
end
local presetButton
presetButton = button("Пресет: свой", 414, function()
    state.aspect = state.aspect == "custom" and "4:3"
        or state.aspect == "4:3" and "16:10" or "custom"
    presetButton.Text = "Пресет: " .. (state.aspect == "custom" and "свой" or state.aspect)
    unsupportedCamera = nil
    updateCamera()
end)
label("Своя сила: 0.5-2.0; 1 = обычный вид", 456, 24)
numberInput(484, 1.2, 0.5, 2, function(v)
    state.stretchPower, state.aspect = v, "custom"
    presetButton.Text = "Пресет: свой"
    unsupportedCamera = nil
    updateCamera()
end)
label("Пресеты имитируют растянутые 4:3 и 16:10.\nИнтерфейс и разрешение экрана не меняются.", 522, 38)
toggle("perks", "Перки маньяка на экране", 686)
label("Только доступные клиенту данные.\nСкрытые перки и их эффекты не угадываются.", 730, 40)
label("Подсветка ищет команду Killer/Killers.\nАвто скиллчеки требуют проверки в игре.", 782, 60)

local function overlay(name, width, height, position, anchor)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.fromOffset(width, height)
    frame.Position = position
    frame.AnchorPoint = anchor
    frame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = frame
    return frame
end
local function overlayLabel(parent, text, y, height)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Position = UDim2.fromOffset(8, y)
    item.Size = UDim2.new(1, -16, 0, height)
    item.Font = Enum.Font.Gotham
    item.TextSize = 12
    item.TextColor3 = Color3.fromRGB(240, 243, 250)
    item.TextWrapped = true
    item.Text = text
    item.Parent = parent
    return item
end
perkBox = overlay("KillerPerks", 280, 184, UDim2.new(0, 12, 0, 12), Vector2.new(0, 0))
perkBox.ZIndex=20
local perkTitle=overlayLabel(perkBox, "Перки маньяка", 4, 24)
perkTitle.ZIndex=22;perkTitle.Font=Enum.Font.GothamBold
local perkScroll = Instance.new("ScrollingFrame")
perkScroll.Position = UDim2.fromOffset(8, 32)
perkScroll.Size = UDim2.new(1, -16, 1, -40)
perkScroll.BackgroundTransparency = 1
perkScroll.BorderSizePixel = 0
perkScroll.ScrollBarThickness = 3
perkScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
perkScroll.CanvasSize = UDim2.new()
perkScroll.ZIndex = 21
perkScroll.Parent = perkBox
local perkText = overlayLabel(perkScroll, "Нет доступных данных.", 0, 0)
perkText.Position = UDim2.fromOffset(0, 0)
perkText.Size = UDim2.new(1, -6, 0, 0)
perkText.AutomaticSize = Enum.AutomaticSize.Y
perkText.ZIndex = 22
perkText.TextXAlignment = Enum.TextXAlignment.Left
perkText.TextYAlignment = Enum.TextYAlignment.Top
local function equippedPerks(who)
    -- Conservative adapters only. Never enumerate shared perk definitions or
    -- inventories and present them as the killer's selected loadout.
    local entries, seen = {}, {}
    local function add(value, origin)
        if type(value) ~= "string" or value == "" then return end
        value = value:sub(1, 180)
        if not seen[value] and #entries < 12 then
            seen[value] = true
            table.insert(entries, value)
        end
    end
    for _, root in ipairs({who, who.Character}) do
        if root then
            for attribute, value in pairs(root:GetAttributes()) do
                if attribute:match("^EquippedPerk%d+$") or attribute:match("^Perk[1-4]$") then
                    add(value, "атрибут " .. attribute)
                elseif attribute == "EquippedPerks" and type(value) == "string" then
                    local ok,decoded=pcall(function()return game:GetService("HttpService"):JSONDecode(value)end)
                    if ok and type(decoded)=="table"then
                        local before=#entries
                        for _,entry in pairs(decoded)do
                            if type(entry)=="string"then add(entry,"EquippedPerks")
                            elseif type(entry)=="table"then add(entry.name or entry.Name or entry.perk or entry.PerkName,"EquippedPerks")end
                        end
                        if #entries==before then add(value,"EquippedPerks")end
                    else add(value, "атрибут EquippedPerks")end
                end
            end
            local roots = {root}
            local loadout = root:FindFirstChild("Loadout")
            if loadout then table.insert(roots, loadout) end
            for _, source in ipairs(roots) do
                for _, name in ipairs({"EquippedPerks", "ActivePerks"}) do
                    local container = source:FindFirstChild(name)
                    if container then
                        if container:IsA("StringValue") then add(container.Value, name) end
                        for _, item in ipairs(container:GetChildren()) do
                            if item:IsA("StringValue") then
                                add(item.Value, name)
                            elseif item:IsA("BoolValue") and item.Value then
                                add(item.Name, name)
                            elseif item:IsA("Folder") then
                                local value = item:GetAttribute("PerkName")
                                if value then add(value, name) end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(entries)
    return entries
end
state.perkDiagnostics=function()
    local result={}
    for _,who in ipairs(Players:GetPlayers())do if who~=player and isKiller(who)then
        local row={name=who.Name,team=who.Team and who.Team.Name,roots={}}
        for _,root in ipairs({who,who.Character})do if root then
            local entry={path=root:GetFullName(),attributes={},objects={}}
            for name,value in pairs(root:GetAttributes())do
                local key=name:lower()
                if key:find("perk",1,true)or key:find("loadout",1,true)then entry.attributes[name]=tostring(value)end
            end
            for _,item in ipairs(root:GetDescendants())do
                local key=item.Name:lower()
                if key:find("perk",1,true)or key:find("loadout",1,true)then
                    local itemInfo={path=item:GetFullName(),class=item.ClassName,attributes={}}
                    for name,value in pairs(item:GetAttributes())do itemInfo.attributes[name]=tostring(value)end
                    if item:IsA("StringValue")or item:IsA("IntValue")or item:IsA("NumberValue")or item:IsA("BoolValue")then itemInfo.value=tostring(item.Value)end
                    entry.objects[#entry.objects+1]=itemInfo
                    if #entry.objects>=40 then break end
                end
            end
            row.roots[#row.roots+1]=entry
        end end
        result[#result+1]=row
    end end
    return result
end
updateOverlays = function()
    perkBox.Visible = state.perks
    if not state.perks then return end
    local rows, killerCount = {}, 0
    for _, who in ipairs(Players:GetPlayers()) do
        if who ~= player and isKiller(who) then
            killerCount = killerCount + 1
            local values = equippedPerks(who)
            table.insert(rows, who.DisplayName .. " (@" .. who.Name .. ")")
            table.insert(rows, #values > 0 and table.concat(values, "\n") or "Нет данных о перках.")
        end
    end
    perkText.Text = killerCount > 0 and table.concat(rows, "\n\n") or "Киллер не найден."
end

local setMenuVisible
state.cleanup = function()
    if not state.alive then return end
    if state.flushConfig then pcall(state.flushConfig) end
    state.alive = false
    if state.resetVaultObserver then pcall(state.resetVaultObserver)end
    if state.resetSpikeVault then pcall(state.resetSpikeVault)end
    if state.resetUtilities then pcall(state.resetUtilities)end
    if state.resetSurvival then pcall(state.resetSurvival)end
    if state.resetSprint then pcall(state.resetSprint)end
    if state.resetPresentation then pcall(state.resetPresentation)end
    state.menuVisible = false
    for field in pairs(toggleButtons) do state[field] = false end
    state.capturingBind = nil
    -- One failed restoration must not prevent UI removal and disconnection.
    for _, restore in ipairs({resetFastBreak, resetExtensions, resetWorldEsp, resetParry, resetAudio, resetAvatar}) do
        if type(restore) == "function" then pcall(restore) end
    end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(removeESP)
    pcall(function() RunService:UnbindFromRenderStep("VDHelperCamera02") end)
    pcall(function() RunService:UnbindFromRenderStep("VDHelperCameraPrepare") end)
    pcall(restoreCamera)
    if crossGui then pcall(function() crossGui:Destroy() end) end
    pcall(function() gui:Destroy() end)
    if env[key] == state then env[key] = nil end
end
local close = button("X", 8, state.cleanup)
close.Parent = panel
close.Size = UDim2.fromOffset(32, 30)
close.Position = UDim2.new(1, -44, 0, 8)
close.ZIndex = 10
local function setCollapsed(value)
    collapsed = value
    panel.Size = UDim2.fromOffset(state.uiWidth, collapsed and 46 or state.uiHeight)
    content.Visible = not collapsed
    if tabBar then tabBar.Visible = not collapsed end
    if status.Parent == panel then status.Visible = not collapsed end
    fit()
end
setMenuVisible = function(visible)
    if not state.alive then return end
    state.menuVisible = visible
    panel.Visible = visible
    if visible then setCollapsed(false) end
    if state.updateLogo then state.updateLogo()end
end
state.menuVisible = true
connect(Input.InputBegan, function(input)
    if Input:GetFocusedTextBox() or state.capturingBind then return end
    if state.menuBind == Enum.KeyCode.Unknown or input.KeyCode ~= state.menuBind then return end
    -- Ignore gameProcessedEvent: the game may consume Shift for sprinting.
    setMenuVisible(not state.menuVisible)
end)
local mini = button("_", 8, function() setCollapsed(not collapsed) end)
mini.Parent = panel
mini.Size = UDim2.fromOffset(32, 30)
mini.Position = UDim2.new(1, -82, 0, 8)

local dragInput, dragStart, startPosition
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput, dragStart, startPosition = input, input.Position, panel.Position
    end
end)
connect(Input.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)
connect(Input.InputChanged, function(input)
    if not dragInput then return end
    if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        local size = gui.AbsoluteSize
        local half = panel.AbsoluteSize / 2
        local x = math.clamp(startPosition.X.Scale * size.X + startPosition.X.Offset + delta.X,
            half.X, math.max(half.X, size.X - half.X))
        local y = math.clamp(startPosition.Y.Scale * size.Y + startPosition.Y.Offset + delta.Y,
            half.Y, math.max(half.Y, size.Y - half.Y))
        panel.Position = UDim2.fromOffset(x, y)
        state.menuX, state.menuY = x / math.max(size.X,1), y / math.max(size.Y,1)
    end
end)
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    if state.esp then refreshESP() end
    if state.perks then updateOverlays() end
end)
connect(gui.Destroying, function()
    if state.alive then state.cleanup() end
end)


-- v0.4: local display settings and experimental animation-triggered parrying.
-- Attack assets were checked against Roblox's economy asset metadata.
-- Only verified VD attack/swing animations are included; new killers may be unsupported.
local floatingMenu = button("S", 0, function() if state.logoDragged then state.logoDragged=false;return end;setMenuVisible(not state.menuVisible) end)
floatingMenu.Parent = gui
floatingMenu.Position = UDim2.new(0, 10, 0.5, -24)
floatingMenu.Size = UDim2.fromOffset(48, 48)
local mobileParry = button("Парирование", 0, function()
    local entry = toggleButtons.parry
    if entry then
        -- Share the exact state transition used by keyboard/menu.
        state.setParry(not state.parry)
    end
end)
mobileParry.Parent = gui
mobileParry.Position = UDim2.new(0, 10, 0.5, 32)
mobileParry.Size = UDim2.fromOffset(110, 44)
mobileParry.Visible = Input.TouchEnabled

crossGui = Instance.new("ScreenGui")
crossGui.Name = "VDHelperCrosshair"
crossGui.ResetOnSpawn = false
crossGui.IgnoreGuiInset = true
crossGui.ScreenInsets = Enum.ScreenInsets.None
mountOverlay(crossGui, 1999999999)
local cross = Instance.new("Frame")
cross.Name = "Crosshair"
cross.BackgroundTransparency = 1
cross.Size = UDim2.fromOffset(1, 1)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Visible = false
cross.Parent = crossGui
local crossH, crossV = Instance.new("Frame"), Instance.new("Frame")
for _, part in ipairs({crossH, crossV}) do
    part.AnchorPoint = Vector2.new(0.5, 0.5)
    part.BorderSizePixel = 0
    part.Parent = cross
end
local meters = overlay("Performance", 180, 30, UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
local meterText = overlayLabel(meters, "FPS: — | Ping: —", 3, 24)
local function paintToggle(field)
    local entry = toggleButtons[field]
    if entry then
        entry.button.Text = entry.text
        entry.button.BackgroundColor3 = state[field] and Color3.fromRGB(42, 104, 84)
            or Color3.fromRGB(45, 53, 71)
    end
end
refreshParryButtons = function()
    paintToggle("parry")
    mobileParry.Text = "Парирование"
    mobileParry.BackgroundColor3 = state.parry and Color3.fromRGB(42, 104, 84)
        or Color3.fromRGB(45, 53, 71)
end
applyExtras = function()
    cross.Visible, meters.Visible = state.crosshair, state.stats
    crossH.Size = UDim2.fromOffset(state.crossSize * 2 + 1, 2)
    crossV.Size = UDim2.fromOffset(2, state.crossSize * 2 + 1)
    crossH.BackgroundColor3, crossV.BackgroundColor3 = state.crossColor, state.crossColor
    panel.BackgroundTransparency = state.menuAlpha
    refreshParryButtons()
    fit()
    if state.applyStyle then state.applyStyle() end
end
local frameCount, sampleTime = 0, 0
connect(RunService.RenderStepped, function(dt)
    if not state.stats then frameCount, sampleTime = 0, 0; return end
    frameCount, sampleTime = frameCount + 1, sampleTime + dt
    if sampleTime < 0.5 then return end
    local ping = "—"
    pcall(function()
        local value = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        if type(value) == "number" and value >= 0 then ping = tostring(math.floor(value + 0.5)) .. " ms" end
    end)
    meterText.Text = "FPS: " .. math.floor(frameCount / sampleTime + 0.5) .. " | Ping: " .. ping
    frameCount, sampleTime = 0, 0
end)

label("ПРИЦЕЛ И ИНТЕРФЕЙС", 920, 24)
toggle("crosshair", "Прицел", 950)
label("Размер прицела: 2–40 пикселей", 992, 24)
numberInput(1020, 12, 2, 40, function(v) state.crossSize = v; applyExtras() end)
local colorButton
colorButton=button("Цвет прицела",1062,function()if state.openColor then state.openColor("crosshair",colorButton)end end)
toggle("stats", "FPS / Ping", 1104)
label("Right Shift / VD — скрыть или показать меню.\nX скрывает меню. Выгрузка скрипта — в config.", 1286, 42)

local attackIds = {
    ["105374834496520"] = true, -- Jacket lunge
    ["117042998468241"] = true, -- Stalker lunge
    ["122812055447896"] = true, -- veil Lunge
    ["78935059863801"] = true, -- veil Swing
    ["74968262036854"] = true, -- HiddenAttack
    ["78432063483146"] = true, -- Abyss attack
    ["132817836308238"] = true, -- Attack-jeff
    ["133963973694098"] = true, -- Attack Stalker
    ["111920872708571"] = true, -- jacket hit
    ["82666958311998"] = true, -- AttackFrenzy-m
    ["139369275981139"] = true, -- Attack-jason
    ["135002183282873"] = true, -- Lunge sc
    ["121216847022485"] = true, -- Slash sc
    ["130593238885843"] = true, -- snake attack
    ["138720291317243"] = true, -- tony attack
}
local seenTracks = setmetatable({}, {__mode = "k"})
local watched = {}
local lastParry, parryEpoch = -math.huge, 0
local parryEvents={}
local nativeParryClient,nativeParryTool
local nativeScanAt,nativeScanning=0,false
local function findNativeParry()
    local char=player.Character
    local tool=char and char:FindFirstChild("Parrying Dagger")
    if nativeParryClient and nativeParryTool==tool and tool and tool.Parent==char then return end
    nativeParryClient,nativeParryTool=nil,nil
    if not tool or type(getgc)~="function"or nativeScanning or os.clock()<nativeScanAt then return end
    nativeScanAt=os.clock()+3;nativeScanning=true
    task.spawn(function()
        local ok,module=pcall(function()
            return require(game:GetService("ReplicatedStorage").Modules.Items.ParryingDagger.ParryClient)
        end)
        local found,objects=pcall(getgc,true)
        if ok and found and type(objects)=="table"then
            for _,candidate in ipairs(objects)do
                if type(candidate)=="table"and rawget(candidate,"tool")==tool and getmetatable(candidate)==module then
                    if state.alive and state.parry and player.Character==char and tool.Parent==char then
                        nativeParryClient,nativeParryTool=candidate,tool
                    end
                    break
                end
            end
        end
        nativeScanning=false
    end)
end
local function parryRecord(event,track,reason)
    local anim=track and track.Animation
    local row={t=os.clock(),event=event,reason=reason,animation=anim and anim.AnimationId,name=anim and anim.Name}
    parryEvents[#parryEvents+1]=row
    if #parryEvents>40 then table.remove(parryEvents,1)end
end
local function parryGeometry(distance, facing, radius, sensitivity)
    return distance > 0.001 and distance <= radius and facing >= sensitivity
end
local function canParry(who, track, observed)
    if not state.alive or not state.parry or not isKiller(who)then return false,"disabled or killer unrecognised"end
    if Input:GetFocusedTextBox()then return false,"text box focused"end
    if (not observed and not track.IsPlaying)or track.TimePosition > 0.6 then return false,"animation stopped or too late"end
    local own = player.Character
    local enemy = who.Character
    local ownRoot = own and own:FindFirstChild("HumanoidRootPart")
    local enemyRoot = enemy and enemy:FindFirstChild("HumanoidRootPart")
    local hum = own and own:FindFirstChildOfClass("Humanoid")
    local enemyHum = enemy and enemy:FindFirstChildOfClass("Humanoid")
    if not ownRoot or not enemyRoot or not hum or hum.Health <= 0
        or not enemyHum or enemyHum.Health <= 0 then return false,"missing character or health"end
    if own:GetAttribute("Downed") == true or own:GetAttribute("IsDown") == true then return false,"downed"end
    local delta = ownRoot.Position - enemyRoot.Position
    local distance = delta.Magnitude
    if distance < 0.001 then return false,"zero distance"end
    if not parryGeometry(distance, enemyRoot.CFrame.LookVector:Dot(delta / distance),
        state.parryRadius, state.faceSensitivity) then return false,"outside radius or facing threshold"end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {own, enemy}
    if Workspace:Raycast(ownRoot.Position, enemyRoot.Position - ownRoot.Position, params) then return false,"line of sight blocked"end
    return true
end
local function parryInput()
    if nativeParryClient and nativeParryTool and nativeParryTool.Parent==player.Character then
        local client=nativeParryClient
        if not client:CanUse()then error("dagger not ready")end
        task.spawn(function()
            local ok,err=pcall(function()client:Parry()end)
            if not ok then parryRecord("native error",nil,tostring(err))end
        end)
        return "game handler"
    end
    if not virtualInput then error("Input unavailable") end
    if Input.TouchEnabled and not Input.KeyboardEnabled then
        local root = player.PlayerGui:FindFirstChild("Survivor-mob")
        local controls = root and root:FindFirstChild("Controls")
        local target = controls and controls:FindFirstChild("Gui-mob")
        if not target or not target:IsA("GuiObject") or not visibleUI(target) then
            error("Parry button unavailable")
        end
        local inset = game:GetService("GuiService"):GetGuiInset()
        local point = target.AbsolutePosition + target.AbsoluteSize / 2 + inset
        local ok, reason = pcall(function() virtualInput:SendTouchEvent(8823, 0, point.X, point.Y) end)
        pcall(function() virtualInput:SendTouchEvent(8823, 2, point.X, point.Y) end)
        if not ok then error(reason) end
    else
        local configured=player:GetAttribute("kb_item")
        local inputName=type(configured)=="string"and configured~=""and configured or "MouseButton2"
        local mouseButtons={MouseButton1=0,MouseButton2=1,MouseButton3=2}
        local mouseButton=mouseButtons[inputName]
        if mouseButton~=nil then
            local point = Input:GetMouseLocation()
            local ok, reason = pcall(function() virtualInput:SendMouseButtonEvent(point.X, point.Y, mouseButton, true, game, 0) end)
            pcall(function() virtualInput:SendMouseButtonEvent(point.X, point.Y, mouseButton, false, game, 0) end)
            if not ok then error(reason) end
        else
            local keyCode = Enum.KeyCode[inputName]
            if not keyCode or keyCode==Enum.KeyCode.Unknown then error("Unknown item key: "..inputName)end
            local ok, reason = pcall(function() virtualInput:SendKeyEvent(true, keyCode, false, game) end)
            pcall(function() virtualInput:SendKeyEvent(false, keyCode, false, game) end)
            if not ok then error(reason) end
        end
    end
end
local function handleAttack(who,track,observed)
    if not state.parry or state.isDowned() or seenTracks[track]then return end
    local eligible,reason=canParry(who,track,observed)
    if not eligible then if observed then parryRecord("skipped",track,reason)end;return end
    local anim=track.Animation
    local id=anim and anim.AnimationId:match("%d+")
    local name=anim and tostring(anim.Name or ""):lower():gsub("[^a-z0-9]","")or ""
    if not(id and attackIds[id])and name~="basicattack"and name~="m1attack"and name~="m1"and name~="swing"then if observed then parryRecord("skipped",track,"unknown animation")end;return end
    if os.clock()-lastParry<state.parryCooldown then if observed then parryRecord("skipped",track,"cooldown")end;return end
    seenTracks[track]=true
    local ok,err=pcall(parryInput) -- Run in the animation callback, without task.delay(0).
    if ok then lastParry=os.clock()end
    parryRecord(ok and "input sent"or "input error",track,ok and(err or "virtual input")or tostring(err))
    status.Text=ok and "Парирование: ввод отправлен."or "Парирование: ввод недоступен."
end
local function clearParryConnections()
    for _, conn in pairs(parryConnections) do conn:Disconnect() end
    parryConnections, watched = {}, {}
end
local parryResultConnection
local function watchParryResult()
    if parryResultConnection then return end
    local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local items=remotes and remotes:FindFirstChild("Items")
    local dagger=items and items:FindFirstChild("Parrying Dagger")
    local result=dagger and dagger:FindFirstChild("parryResult")
    if result and result:IsA("RemoteEvent")then
        parryResultConnection=connect(result.OnClientEvent,function(success,cooldown,permanent,reset,character)
            if not state.parry or character~=player.Character then return end
            parryRecord("server result",nil,reset and "reset"or(success and "success"or "failed"))
        end)
    end
end
resetParry = function()
    parryEpoch = parryEpoch + 1
    seenTracks = setmetatable({}, {__mode = "k"})
    if not state.parry then clearParryConnections() end
end
local function watchKillers()
    if not state.parry then return end
    watchParryResult()
    findNativeParry()
    local keep = {}
    for _, who in ipairs(Players:GetPlayers()) do
        if who ~= player and isKiller(who) and who.Character then
            local hum = who.Character:FindFirstChildOfClass("Humanoid")
            local animator = hum and hum:FindFirstChildOfClass("Animator")
            if animator then
                keep[who] = animator
                if watched[who] ~= animator then
                    if parryConnections[who] then parryConnections[who]:Disconnect() end
                    watched[who] = animator
                    parryConnections[who] = animator.AnimationPlayed:Connect(function(track)
                        seenTracks[track] = nil -- The same AnimationTrack can be replayed.
                        handleAttack(who, track,true)
                    end)
                end
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    handleAttack(who, track)
                end
            end
        end
    end
    for who, conn in pairs(parryConnections) do
        if not keep[who] then conn:Disconnect(); parryConnections[who] = nil; watched[who] = nil end
    end
end
state.parryDiagnostics=function()
    local n=0;for _ in pairs(watched)do n=n+1 end
    local controls={};local root=player.PlayerGui:FindFirstChild("Survivor-mob")
    if root then for _,node in ipairs(root:GetDescendants())do
        if #controls>=30 then break end
        if node:IsA("GuiButton")then controls[#controls+1]={name=node.Name,visible=visibleUI(node),class=node.ClassName}end
    end end
    return {enabled=state.parry,watchedKillers=n,radius=state.parryRadius,faceSensitivity=state.faceSensitivity,
        input=player:GetAttribute("kb_item")or "MouseButton2",nativeHandler=nativeParryClient~=nil,
        touch=Input.TouchEnabled,keyboard=Input.KeyboardEnabled,controls=controls,events=parryEvents}
end
state.setParry = function(enabled)
    if enabled and not virtualInput then status.Text = "Парирование: ввод недоступен."; return end
    state.parry = enabled
    resetParry()
    refreshParryButtons()
    status.Text = enabled and "Автопарирование ВКЛ." or "Автопарирование ВЫКЛ."
    if state.applyStyle then state.applyStyle() end
end
label("АВТО ДАГГЕР / ПАРИРОВАНИЕ", 1340, 24)
toggle("parry", "Автопарирование", 1370)
toggle("showParryFov","Показывать радиус даггера",1371)
label("Расстояние до убийцы: 2–25 студов", 1412, 24)
numberInput(1440, 12, 2, 25, function(v) state.parryRadius = v end)
label("Направление взгляда убийцы: −1…1", 1482, 24)
numberInput(1510, 0.7, -1, 1, function(v) state.faceSensitivity = v end)
label("1 — смотрит точно на тебя; 0 — в твою сторону;\n−1 — срабатывает с любого направления.", 1552, 40)
local waitingBind = false
local bindButton
bindButton = button("Бинд авто парирования: не назначен", 1600, function()
    waitingBind = true
    state.capturingBind = "parry"
    bindButton.Text = "Клавиша; Backspace — убрать; Esc — отмена"
end)
local function textSetting(y, initial, accept)
    local box = Instance.new("TextBox")
    box.Name = "Setting_" .. tostring(y)
    box.Position = UDim2.fromOffset(14, y)
    box.Size = UDim2.new(1, -28, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(35,40,55)
    box.TextColor3 = Color3.fromRGB(242,245,255)
    box.Font, box.TextSize = Enum.Font.Gotham, 12
    box.ClearTextOnFocus, box.Text = false, initial
    box.Parent = content
    local current = initial
    textControls[y] = {box = box, set = function(v)
        local accepted = accept(v)
        if accepted then current = accepted; box.Text = accepted end
    end, sync = function(v) current = v; box.Text = v end}
    connect(box.FocusLost, function()
        local value = accept(box.Text)
        if value then current = value end
        box.Text = current
    end)
    return box
end
label("Пауза между попытками: 0.2–5 секунд", 1782, 24)
numberInput(1810, 0.2, 0.2, 5, function(v) state.parryCooldown = v end)
label("Только известные анимации атак; не все убийцы.\nНужен экипированный даггер. Проверь ввод в игре.", 1852, 44)
local function disableAll()
    if state.resetSpikeVault then state.resetSpikeVault()end
    if state.resetUtilities then state.resetUtilities()end
    if state.resetSurvival then state.resetSurvival()end
    if state.resetSprint then state.resetSprint()end
    if state.cancelWidgetDrag then state.cancelWidgetDrag()end
    if state.resetPresentation then state.resetPresentation()end
    if resetAvatar then resetAvatar()end
    if resetAudio then resetAudio()end
    if resetFastBreak then resetFastBreak() end
    if resetExtensions then resetExtensions() end
    if resetWorldEsp then resetWorldEsp() end
    state.capturingBind = nil
    for field in pairs(toggleButtons) do state[field] = false; paintToggle(field) end
    resetParry()
    removeESP()
    restoreCamera()
    updateOverlays()
    applyExtras()
    waitingBind = false
    bindButton.Text = "Бинд авто парирования: " .. bindLabel(state.parryBind)
    if refreshExtensions then refreshExtensions() end
    status.Text = "Все функции отключены. Камера восстановлена."
end
state.disableAll = disableAll
connect(Input.InputBegan, function(input, processed)
    if state.capturingBind == "menu" or (state.menuBind ~= Enum.KeyCode.Unknown and input.KeyCode == state.menuBind) or Input:GetFocusedTextBox() then return end
    if state.capturingBind and state.capturingBind ~= "parry" then return end
    if waitingBind then
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingBind = false
        elseif input.KeyCode == Enum.KeyCode.Backspace then
            state.parryBind, waitingBind = Enum.KeyCode.Unknown, false
        elseif input.KeyCode ~= Enum.KeyCode.Unknown
            and input.KeyCode ~= Enum.KeyCode.Space and input.KeyCode~=Enum.KeyCode.LeftShift and input.KeyCode~=state.emoteBind and input.KeyCode~=state.selfHealBind and input.KeyCode ~= state.menuBind and input.KeyCode ~= state.moonForwardBind and input.KeyCode ~= state.moonBackwardBind and input.KeyCode ~= state.hiddenBind
            and input.KeyCode.Name ~= state.parryInput then
            state.parryBind, waitingBind = input.KeyCode, false
        else
            status.Text = "Выбери другую клавишу: Space зарезервирован."
        end
        if not waitingBind then state.capturingBind = nil end
        bindButton.Text = waitingBind and "Другая клавиша; Backspace — убрать"
            or "Бинд авто парирования: " .. bindLabel(state.parryBind)
        return
    end
    if processed then return end
    if state.parryBind ~= Enum.KeyCode.Unknown and input.KeyCode == state.parryBind then
        state.setParry(not state.parry)
    end
end)
connect(RunService.Heartbeat, function()
    watchKillers()
end)
-- Keep unused scroll area out of the menu.
content.CanvasSize = UDim2.fromOffset(0, 2080)
applyExtras()


-- Fast Break Pallet uses the existing reported rate attribute plus known animations.
-- Client attribute readback does not prove a shorter server timer.
-- Metadata for 112166042383605: "Abyss break", VD group 8818124.
local breakAnimationIds = {["112166042383605"] = true}
local breakTracks = setmetatable({}, {__mode = "k"})
local breakAnimator, breakConnection
local function restoreBreakTracks()
    for track, saved in pairs(breakTracks) do
        pcall(function() track:AdjustSpeed(saved.original) end)
        breakTracks[track] = nil
    end
end
resetFastBreak = function()
    state.restoreGameRate("break")
    restoreBreakTracks()
    if breakConnection then breakConnection:Disconnect(); breakConnection = nil end
    breakAnimator = nil
end
local function isPalletBreak(track)
    local anim = track.Animation
    if not anim then return false end
    local id = anim.AnimationId:match("%d+")
    if id and breakAnimationIds[id] then return true end
    -- Conservative name adapter for killers whose asset IDs are not listed.
    local name = (anim.Name .. " " .. track.Name):lower():gsub("[^a-z]", "")
    local char=player.Character
    local action=char and tostring(char:GetAttribute("ActionState")or ""):lower()or ""
    return(action:find("break",1,true)and action:find("pallet",1,true)and name:find("break",1,true))~=nil
        or name:find("palletbreak",1,true) ~= nil
        or name:find("breakpallet",1,true) ~= nil
        or name:find("destroypallet",1,true) ~= nil
end
local function adjustBreakTrack(track)
    if not state.alive or not state.fastBreak or not isKiller(player)
        or not track.IsPlaying or not isPalletBreak(track) then return end
    local saved = breakTracks[track]
    if not saved then
        saved = {original = track.Speed}
        breakTracks[track] = saved
    end
    local target = saved.original * state.breakMultiplier
    if saved.applied == target then return end
    local ok = pcall(function() track:AdjustSpeed(target) end)
    if ok then
        saved.applied = target
        status.Text = "Fast Break Pallet: анимация ×" .. state.breakMultiplier
            .. "; время разрушения на сервере не проверено."
    else
        status.Text = "Fast Break Pallet: изменение анимации недоступно."
    end
end
local function updateFastBreak()
    if not state.fastBreak or not isKiller(player) then
        if breakAnimator or next(breakTracks) then resetFastBreak() end
        return
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not hum or hum.Health <= 0 then resetFastBreak(); return end
    state.restoreGameRate("break",char)
    state.applyGameRate("break",char,{"BreakSpeed","breakspeed","break_speed","breakSpeed"},state.breakMultiplier)
    if animator ~= breakAnimator then
        resetFastBreak()
        breakAnimator = animator
        if animator then
            breakConnection = animator.AnimationPlayed:Connect(function(track)
                local saved = breakTracks[track]
                if saved then
                    pcall(function() track:AdjustSpeed(saved.original) end)
                    breakTracks[track] = nil
                end
                adjustBreakTrack(track)
            end)
        end
    end
    state.applyGameRate("break",char,{"BreakSpeed","breakspeed","break_speed","breakSpeed"},state.breakMultiplier)
    if not animator then return end
    for track, saved in pairs(breakTracks) do
        if not track.IsPlaying then
            pcall(function() track:AdjustSpeed(saved.original) end)
            breakTracks[track] = nil
        end
    end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do adjustBreakTrack(track) end
end
label("КИЛЛЕР — РАЗРУШЕНИЕ ПАЛЕТ", 2090, 24)
toggle("fastBreak", "Fast Break Pallet", 2120)
label("Скорость: 1–10; ×1 не ускоряет", 2162, 30)
numberInput(2200, 3, 1, 10, function(v)
    state.breakMultiplier = v
    for track in pairs(breakTracks) do adjustBreakTrack(track) end
end)
label("Использует существующий параметр скорости и известные анимации. Серверный результат требует проверки.",2242,44)
label("Дополнительные ID анимаций разрушения палеты", 2312, 30)
textSetting(2350, "", function(value)
    local selected = {["112166042383605"] = true}
    if not value:match("^%s*$") then
        for token in value:gmatch("[^,]+") do
            local id = token:match("^%s*(%d+)%s*$")
            if not id then status.Text = "Нужны ID анимаций через запятую."; return end
            selected[id] = true
        end
    end
    resetFastBreak()
    breakAnimationIds = selected
    return value
end)
local breakElapsed = 0
connect(RunService.Heartbeat, function(dt)
    breakElapsed = breakElapsed + dt
    if breakElapsed < 0.1 then return end
    breakElapsed = 0
    updateFastBreak()
end)
content.CanvasSize = UDim2.fromOffset(0, 2400)
applyExtras()


-- v0.6: explicitly local status/visual helpers, M2 camera lock, JSON configs.
-- No invulnerability, slowdown removal, or projectile redirection is claimed here.
do
local Http = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local savedBlind = setmetatable({}, {__mode = "k"})
local ownedRoot,ownedCharacter
local healthySpeed=18
local controls
local function restoreKnock()
    if ownedRoot and ownedRoot.Parent and state.isDowned(ownedCharacter)then
        pcall(function()local v=ownedRoot.AssemblyLinearVelocity;ownedRoot.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)end)
    end
    ownedRoot,ownedCharacter=nil,nil
end
local function updateKnock()
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health>0 and not state.isDowned(char)and hum.WalkSpeed>=8 then healthySpeed=math.clamp(hum.WalkSpeed,8,32)end
    local blocked=char and(char:GetAttribute("Hooked")==true or char:GetAttribute("IsHooked")==true
        or char:GetAttribute("Carried")==true or char:GetAttribute("BeingCarried")==true)
    if not state.antiKnock or not char or not hum or hum.Health<=0 or not root or root.Anchored
        or not state.isDowned(char)or blocked or Input:GetFocusedTextBox()or state.capturingBind then restoreKnock();return end
    local direction=hum.MoveDirection or Vector3.new(0,0,0)
    if direction.Magnitude<0.05 then
        local cam=Workspace.CurrentCamera
        local move=Vector3.new(0,0,0)
        if Input.KeyboardEnabled then
            local x,z=0,0
            pcall(function()
                x=(Input:IsKeyDown(Enum.KeyCode.D)and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.A)and 1 or 0)
                z=(Input:IsKeyDown(Enum.KeyCode.S)and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.W)and 1 or 0)
            end)
            move=Vector3.new(x,0,z)
        elseif Input.TouchEnabled then
            if not controls then pcall(function()
                local scripts=player:FindFirstChild("PlayerScripts");local module=scripts and scripts:FindFirstChild("PlayerModule")
                if module then controls=require(module):GetControls()end
            end)end
            if controls then pcall(function()move=controls:GetMoveVector()end)end
        end
        if cam then
            local look=cam.CFrame.LookVector;local forward=Vector3.new(look.X,0,look.Z)
            if forward.Magnitude>0.01 then
                forward=forward/forward.Magnitude;local right=Vector3.new(-forward.Z,0,forward.X)
                direction=right*move.X-forward*move.Z
            end
        end
    end
    direction=Vector3.new(direction.X,0,direction.Z)
    if direction.Magnitude>1 then direction=direction/direction.Magnitude end
    local velocity=root.AssemblyLinearVelocity
    state.godRequestedSpeed=healthySpeed
    local ok=pcall(function()root.AssemblyLinearVelocity=Vector3.new(direction.X*healthySpeed,velocity.Y,direction.Z*healthySpeed)end)
    if ok then ownedRoot,ownedCharacter=root,char end
end
local function restoreBlind()
    for item, saved in pairs(savedBlind) do
        pcall(function() if item.Parent then item[saved.property] = saved.value end end)
        savedBlind[item] = nil
    end
end
local function updateBlind()
    if not state.antiBlind or not isKiller(player) then restoreBlind(); return end
    local roots = {player.PlayerGui, Lighting}
    local cam = Workspace.CurrentCamera
    if cam then roots[#roots+1] = cam end
    for _, root in ipairs(roots) do
        for _, item in ipairs(root:GetDescendants()) do
            local name = item.Name:lower():gsub("[^a-z]", "")
            local blind = name:find("blind",1,true) and not name:find("meter",1,true)
                and not name:find("progress",1,true) and not name:find("antiblind",1,true)
            if blind then
                local property
                if item:IsA("ScreenGui") or item:IsA("PostEffect") then property = "Enabled"
                elseif item:IsA("GuiObject") then property = "Visible" end
                if property and item[property] == true then
                    if not savedBlind[item] then savedBlind[item] = {property=property,value=true} end
                    item[property] = false
                end
            end
        end
    end
end
resetExtensions = function()
    restoreKnock(); restoreBlind()
    state.capturingBind = nil
end
local hiddenCircle = Instance.new("Frame")
hiddenCircle.Name = "HiddenM2Fov"
hiddenCircle.AnchorPoint = Vector2.new(0.5,0.5)
hiddenCircle.Position = UDim2.fromScale(0.5,0.5)
hiddenCircle.BackgroundTransparency = 1
hiddenCircle.Visible = false
hiddenCircle.Parent = crossGui
local circleCorner = Instance.new("UICorner");circleCorner.CornerRadius = UDim.new(1,0);circleCorner.Parent = hiddenCircle
local stroke = Instance.new("UIStroke");stroke.Thickness=1;stroke.Transparency=0.3;stroke.Color=Color3.fromRGB(100,220,255);stroke.Parent=hiddenCircle
state.hiddenCircle=hiddenCircle
local hiddenBindButton
refreshExtensions = function()
    if not state.antiKnock then restoreKnock() end
    if not state.antiBlind then restoreBlind() end
    hiddenCircle.Visible = state.hiddenAim and state.showHiddenFov and isKiller(player)
    hiddenCircle.Size = UDim2.fromOffset(state.hiddenFov*2, state.hiddenFov*2)
    stroke.Color=state.espColors.hiddenFov
    if hiddenBindButton and not state.capturingBind then
        hiddenBindButton.Text = "Бинд Hidden M2 Aim Lock: " .. bindLabel(state.hiddenBind)
    end
end
local function hiddenM2Active()
    if not isKiller(player) then return false end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not hum or hum.Health <= 0 or not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animation = track.Animation
        -- Roblox asset metadata: 98163597193511 = Hiddenm2, VD group 8818124.
        if track.IsPlaying and animation and animation.AnimationId:match("%d+") == "98163597193511" then return true end
    end
    return false
end
local function hiddenTarget(cam)
    local position=state.widgetPositions.hiddenFov or {0.5,0.5}
    local center=Vector2.new(cam.ViewportSize.X*position[1],cam.ViewportSize.Y*position[2])
    local best, bestDistance = nil, state.hiddenFov
    for _, who in ipairs(Players:GetPlayers()) do
        local team = who.Team and who.Team.Name:lower()
        if who ~= player and (team == "survivor" or team == "survivors") and who.Character then
            local char = who.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and hum and hum.Health > 0 and char:GetAttribute("Downed") ~= true
                and char:GetAttribute("Knocked") ~= true then
                local point, onScreen = cam:WorldToViewportPoint(root.Position)
                local distance = (Vector2.new(point.X,point.Y)-center).Magnitude
                if onScreen and point.Z > 0 and distance <= bestDistance then
                    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={player.Character, char}
                    if not Workspace:Raycast(cam.CFrame.Position,root.Position-cam.CFrame.Position,params) then
                        best,bestDistance=root,distance
                    end
                end
            end
        end
    end
    return best
end
connect(RunService.RenderStepped,function(dt)
    state.hiddenSelectedTarget=nil
    if not state.hiddenAim or state.draggingWidget or Input:GetFocusedTextBox() or state.capturingBind then return end
    if not hiddenM2Active() then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local target=hiddenTarget(cam)
    state.hiddenSelectedTarget=target
    if target and (target.Position-cam.CFrame.Position).Magnitude>0.01 then
        cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position,target.Position),math.clamp(dt*state.hiddenStrength,0,1))
    end
end)
local extensionElapsed=0
connect(RunService.Heartbeat,function(dt)
    extensionElapsed=extensionElapsed+dt
    if extensionElapsed<0.15 then return end
    extensionElapsed=0
    -- Isolate unsupported engine properties from other features.
    pcall(updateBlind)
    refreshExtensions()
end)
connect(RunService.Heartbeat,function()pcall(updateKnock)end)
label("ЛОКАЛЬНЫЕ ЭФФЕКТЫ",2410,24)
toggle("antiKnock","Режим бога (Anti Knock)",2440)
toggle("fastVault","Fast Vault · эксперимент",2490)
toggle("spikeVault","Перелаз через шипы · эксперимент",2493)
label("Эксперимент: спринт и движение при перелазе. Эффект не гарантирован.",2494,36)
toggle("vaultSpeedEnabled","Vault Speed",2495)
label("Скорость перелаза: 1–20",2496,24)
numberInput(2497,1,1,20,function(v)state.vaultSpeedValue=v;if state.updateVaultSpeed then state.updateVaultSpeed()end end)
do
local collection=game:GetService("CollectionService")
local installed
state.spikeVaultDiagnostics={installed=false}
state.resetSpikeVault=function()
    local entry=installed;installed=nil
    if entry then pcall(function()
        if entry.module.findNearestPoint==entry.wrapper then entry.module.findNearestPoint=entry.original end
    end)end
    state.spikeVaultDiagnostics.installed=false
end
local function installSpikeVault()
    if installed then return end
    local ok,module=pcall(function()return require(game:GetService("ReplicatedStorage").Modules.Survivors.SurvivorProximity)end)
    if not ok or type(module)~="table"or type(module.findNearestPoint)~="function"then
        state.spikeVaultDiagnostics.error="SurvivorProximity unavailable";return
    end
    local original=module.findNearestPoint
    local wrapper=function(self,tag,radius)
        if not state.alive or not state.spikeVault or tag~="VaultPoint"or isKiller(player)
            or not self.humanoidRootPart or type(radius)~="number"then
            return original(self,tag,radius)
        end
        local changed,seen={},{}
        for _,point in ipairs(collection:GetTagged("VaultPoint"))do
            if point:IsA("BasePart")and point.Parent and not seen[point.Parent]
                and (point.Position-self.humanoidRootPart.Position).Magnitude<=radius
                and collection:HasTag(point.Parent,"Blocked")then
                seen[point.Parent]=true
                local removed=pcall(function()collection:RemoveTag(point.Parent,"Blocked")end)
                if removed then changed[#changed+1]=point.Parent end
            end
        end
        local result=table.pack(pcall(original,self,tag,radius))
        for _,window in ipairs(changed)do pcall(function()
            if window.Parent and not collection:HasTag(window,"Blocked")then collection:AddTag(window,"Blocked")end
        end)end
        state.spikeVaultDiagnostics.lastBlocked=#changed
        if not result[1]then error(result[2],0)end
        return table.unpack(result,2,result.n)
    end
    local success,err=pcall(function()module.findNearestPoint=wrapper end)
    state.spikeVaultDiagnostics.installed=success
    state.spikeVaultDiagnostics.error=not success and tostring(err)or nil
    if success then installed={module=module,original=original,wrapper=wrapper}end
end
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    if state.alive and state.spikeVault then installSpikeVault()elseif installed then state.resetSpikeVault()end
end)
end
label("Движение в нокдауне. Предметы, ремонт и перелаз не разблокируются.",2482,44)
toggle("antiBlind","Anti Blind",2534)
label("Скрывает эффекты с именем Blind.\nЕсли VD использует другие имена, потребуется адаптация.",2576,44)
label("HIDDEN M2 AIM LOCK",2726,24)
toggle("hiddenAim","Hidden M2 Aim Lock",2756)
toggle("showHiddenFov","Показывать FOV M2",2757)
toggle("showTargetLine","Линия к цели M2",2979)
label("FOV-радиус: 35–400 пикселей",2798,24)
numberInput(2826,150,35,400,function(v)state.hiddenFov=v;refreshExtensions()end)
label("Скорость наведения: 1–40",2868,24)
numberInput(2896,18,1,40,function(v)state.hiddenStrength=v end)
hiddenBindButton=button("Бинд Hidden M2 Aim Lock: не назначен",2938,function()
    if waitingBind then waitingBind=false;bindButton.Text="Бинд авто парирования: "..bindLabel(state.parryBind) end
    state.capturingBind="hidden"
    hiddenBindButton.Text="Клавиша; Backspace — убрать; Esc — отмена"
end)
connect(Input.InputBegan,function(input,processed)
    if state.capturingBind=="menu" or (state.menuBind~=Enum.KeyCode.Unknown and input.KeyCode==state.menuBind) or Input:GetFocusedTextBox() then return end
    if state.capturingBind and state.capturingBind~="hidden"then return end
    if state.capturingBind=="hidden" then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        if input.KeyCode==Enum.KeyCode.Escape then state.capturingBind=nil
        elseif input.KeyCode==Enum.KeyCode.Backspace then
            state.hiddenBind=Enum.KeyCode.Unknown;state.capturingBind=nil
        elseif input.KeyCode~=Enum.KeyCode.Unknown and input.KeyCode~=Enum.KeyCode.Space and input.KeyCode~=Enum.KeyCode.LeftShift and input.KeyCode~=state.emoteBind and input.KeyCode~=state.selfHealBind
            and input.KeyCode~=state.menuBind and input.KeyCode~=state.moonForwardBind and input.KeyCode~=state.moonBackwardBind and input.KeyCode~=state.parryBind
            and input.KeyCode.Name~=state.parryInput then
            state.hiddenBind=input.KeyCode;state.capturingBind=nil
        else status.Text="Эта клавиша занята. Выбери другую." end
        refreshExtensions();return
    end
    if not processed and state.hiddenBind~=Enum.KeyCode.Unknown and input.KeyCode==state.hiddenBind then
        state.hiddenAim=not state.hiddenAim;paintToggle("hiddenAim");refreshExtensions()
        if state.applyStyle then state.applyStyle() end
    end
end)
label("Управляет камерой только во время известной M2-анимации.\nДругие способности и обычные атаки не включают наведение.",2980,44)
label("ПОКА НЕТ ПОДТВЕРЖДЁННОЙ РЕАЛИЗАЦИИ",3036,32)
label("No Slowdown и Silent Aim Twist of Fate требуют данных игры.\nОбычная скорость WalkSpeed не фиксируется.\nНастройки-заглушки для этих функций не добавлены.",3076,66)

-- JSON import/export: declarative values only; no Lua or external code execution.
local schemaNumbers={
    targetFov={40,120,330},stretchPower={0.5,2,484},
    crossSize={2,40,1020},uiScale={0.6,1.5},
    parryRadius={2,25,1440},faceSensitivity={-1,1,1510},parryDelay={0,0.5,1740},
    parryCooldown={0.2,5,1810},breakMultiplier={1,10,2200},
    hiddenFov={35,400,2826},hiddenStrength={1,40,2896},vaultSpeedValue={1,20,2497},
    espRange={10,1500,4320},
    uiWidth={420,1200},uiHeight={320,1000},sideWidth={88,160},
    uiTextScale={0.85,1.3},uiRadius={0,20},menuX={0,1},menuY={0,1},
}
local configBox
local function listIds(ids)
    local result={};for id in pairs(ids)do result[#result+1]=id end;table.sort(result);return result
end
local function exportConfig()
    local settings={}
    for field in pairs(toggleButtons)do settings[field]=state[field]end
    for field in pairs(schemaNumbers)do settings[field]=state[field]end
    settings.shaderPreset=state.shaderPreset;settings.stretchMode=state.stretchMode
    settings.aspect=state.aspect;settings.parryBind=state.parryBind.Name;settings.hiddenBind=state.hiddenBind.Name
    settings.parryInput=state.parryInput
    settings.fastVaultAdapter="sprint_v1"
    settings.skillMode=state.skillMode;settings.backgroundImage=state.backgroundImage
    settings.trapMode=state.trapMode
    settings.moonForwardBind=state.moonForwardBind.Name;settings.moonBackwardBind=state.moonBackwardBind.Name
    settings.emoteId=state.emoteId;settings.emoteLoop=state.emoteLoop
    settings.emoteName=state.emoteName;settings.emoteBind=state.emoteBind.Name;settings.selfHealBind=state.selfHealBind.Name
    settings.espMeters={};for id,value in pairs(state.espMeters)do settings.espMeters[id]=value end
    settings.soundOwnOnly=state.soundOwnOnly;settings.customSounds={}
    for id,sound in pairs(state.customSounds)do settings.customSounds[id]={id=sound.id,volume=sound.volume,sources=listIds(sound.sources),mode=sound.mode,preset=sound.preset}end
    settings.collapsedGroups={};for id,closed in pairs(state.collapsedGroups)do settings.collapsedGroups[id]=closed end
    settings.menuBind=state.menuBind.Name
    settings.widgetPositions={}
    for id,position in pairs(state.widgetPositions)do settings.widgetPositions[id]={position[1],position[2]}end
    settings.espColors={}
    for id,color in pairs(state.espColors)do settings.espColors[id]={color.R,color.G,color.B}end
    settings.autoLoad=state.autoLoad;settings.autoSave=state.autoSave;settings.showHints=state.showHints
    settings.uiFont=state.uiFont;settings.uiTheme=state.uiTheme
    settings.uiAccentColor={state.uiAccentColor.R,state.uiAccentColor.G,state.uiAccentColor.B}
    settings.crossColor={state.crossColor.R,state.crossColor.G,state.crossColor.B}
    settings.attackIds=listIds(attackIds);settings.breakAnimationIds=listIds(breakAnimationIds)
    local document={schema="VD_HELPER_CONFIG",version=1,settings=settings}
    return Http:JSONEncode(document),document
end
local function finite(v)return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function checkedKey(name,allowUnset)
    if type(name)~="string" then error("Имя клавиши должно быть строкой")end
    if allowUnset and (name=="Unknown"or name=="None"or name=="")then return Enum.KeyCode.Unknown end
    local ok,code=pcall(function()return Enum.KeyCode[name]end)
    if not ok or not code or code==Enum.KeyCode.Unknown or code==Enum.KeyCode.Space
        or code==Enum.KeyCode.LeftShift or code==Enum.KeyCode.Backspace or code==Enum.KeyCode.Escape
        then error("Недопустимый бинд: "..name)end
    return code
end
local function checkedIds(value)
    if type(value)~="table" or #value>128 then error("Неверный список ID")end
    local result={}
    for k,id in pairs(value)do
        if type(k)~="number" or k<1 or k>#value or k%1~=0 or type(id)~="string"
            or #id>20 or not id:match("^%d+$")then error("Неверный ID анимации")end
        result[id]=true
    end
    return result
end
local function validateConfig(text)
    if type(text)~="string" or #text>65536 then error("Конфиг слишком большой")end
    local decoded=Http:JSONDecode(text)
    if type(decoded)~="table" or decoded.schema~="VD_HELPER_CONFIG" or decoded.version~=1
        or type(decoded.settings)~="table"then error("Неизвестный формат конфига")end
    local source=decoded.settings
    local values={}
    for field in pairs(toggleButtons)do
        if source[field]~=nil then
            if type(source[field])~="boolean"then error("Нужен true/false: "..field)end
            values[field]=source[field]
        else values[field]=state[field] end
    end
    if source.fastVaultAdapter~="sprint_v1"then values.fastVault=false end
    for field,bounds in pairs(schemaNumbers)do
        local v=source[field]
        if v==nil then v=state[field]end
        if not finite(v)or v<bounds[1]or v>bounds[2]then error("Число вне диапазона: "..field)end
        values[field]=v
    end
    for _,field in ipairs({"aspect","parryBind","hiddenBind","parryInput","menuBind","uiFont","uiTheme","moonForwardBind","moonBackwardBind","emoteId","trapMode","backgroundImage","emoteName","emoteBind","selfHealBind"})do
        if source[field]~=nil and type(source[field])~="string"then error("Нужна строка: "..field)end
    end
    values.backgroundImage=source.backgroundImage or state.backgroundImage
    if #values.backgroundImage>240 or(values.backgroundImage~=""and not values.backgroundImage:match("^%d+$")and not values.backgroundImage:match("^rbxassetid://%d+$")and not values.backgroundImage:match("^local:[%w _%./%-]+$"))then error("Неверный фон")end
    if values.backgroundImage:sub(1,6)=="local:"and(values.backgroundImage:find("..",7,true)or values.backgroundImage:sub(7,7)=="/")then error("Неверный путь фона")end
    values.shaderPreset=source.shaderPreset or "Soft"
    if not ({Soft=true,Cinema=true,Cold=true,Warm=true,Noir=true,Vibrant=true,Night=true,Clear=true})[values.shaderPreset]then error("Неизвестный шейдер")end
    values.stretchMode=source.stretchMode or "Auto"
    if not ({Auto=true,Native=true,Matrix=true})[values.stretchMode]then error("Неизвестный растяг")end
    values.aspect=source.aspect or state.aspect
    if values.aspect~="custom"and values.aspect~="4:3"and values.aspect~="16:10"then error("Неверный формат экрана")end
    values.menuBind=checkedKey(source.menuBind or state.menuBind.Name,true)
    for _,field in ipairs({"autoLoad","autoSave","showHints"})do
        local v=source[field];if v==nil then v=state[field]end
        if type(v)~="boolean"then error("Нужен true/false: "..field)end
        values[field]=v
    end
    values.uiFont=source.uiFont or state.uiFont
    if not ({Gotham=true,SourceSans=true,Ubuntu=true,RobotoMono=true,Arial=true,Roboto=true,Oswald=true,FredokaOne=true,Nunito=true,TitilliumWeb=true,Code=true,Cartoon=true})[values.uiFont]then error("Неизвестный шрифт")end
    values.uiTheme=source.uiTheme or state.uiTheme
    if not ({Graphite=true,Midnight=true,Light=true})[values.uiTheme]then error("Неизвестная тема")end
    local accent=source.uiAccentColor
    if accent~=nil then
        if type(accent)~="table"or #accent~=3 then error("Неверный акцент")end
        for i=1,3 do if not finite(accent[i])or accent[i]<0 or accent[i]>1 then error("Неверный акцент")end end
        values.uiAccentColor=Color3.new(accent[1],accent[2],accent[3])
    else values.uiAccentColor=state.uiAccentColor end
    values.parryBind=checkedKey(source.parryBind or state.parryBind.Name,true)
    values.hiddenBind=checkedKey(source.hiddenBind or state.hiddenBind.Name,true)
    values.parryInput=source.parryInput or state.parryInput
    if values.parryInput~="MouseButton2"then checkedKey(values.parryInput)end
    if (values.parryBind~=Enum.KeyCode.Unknown and values.parryBind==values.hiddenBind)
        or values.parryInput==values.parryBind.Name
        or values.parryInput==values.hiddenBind.Name then error("Конфликт клавиш")end
    if values.menuBind~=Enum.KeyCode.Unknown and (values.menuBind==values.parryBind
        or values.menuBind==values.hiddenBind or values.menuBind.Name==values.parryInput)then error("Клавиша меню уже занята")end
    if source.crossColor~=nil then
        local c=source.crossColor
        if type(c)~="table"or #c~=3 then error("Неверный цвет")end
        for i=1,3 do if not finite(c[i])or c[i]<0 or c[i]>1 then error("Неверный цвет")end end
        values.crossColor=Color3.new(c[1],c[2],c[3])
    else values.crossColor=state.crossColor end
    if source.skillMode~=nil and type(source.skillMode)~="string"then error("Неверный режим скиллчека")end
    values.trapMode=source.trapMode or state.trapMode
    if values.trapMode~="Normal"and values.trapMode~="Perfect"then error("Неверный режим bear trap")end
    for _,field in ipairs({"emoteLoop"})do
        local value=source[field];if value==nil then value=state[field]end
        if type(value)~="boolean"then error("Неверное значение: "..field)end
        values[field]=value
    end
    values.emoteId=source.emoteId or state.emoteId
    if type(values.emoteId)~="string"or #values.emoteId>20 or not values.emoteId:match("^%d+$")then error("Неверный ID эмоции")end
    values.emoteName=source.emoteName or state.emoteName
    if #values.emoteName>100 or values.emoteName:find("[%z\1-\31]")then error("Неверная эмоция")end
    values.emoteBind=checkedKey(source.emoteBind or state.emoteBind.Name,true)
    values.selfHealBind=checkedKey(source.selfHealBind or state.selfHealBind.Name,true)
    values.moonForwardBind=checkedKey(source.moonForwardBind or state.moonForwardBind.Name,true)
    values.moonBackwardBind=checkedKey(source.moonBackwardBind or state.moonBackwardBind.Name,true)
    if values.moonForward and values.moonBackward then error("Moonwalk: выбери одно направление")end
    local assigned={}
    for _,code in ipairs({values.menuBind,values.parryBind,values.hiddenBind,values.moonForwardBind,values.moonBackwardBind,values.emoteBind,values.selfHealBind})do
        if code~=Enum.KeyCode.Unknown then
            if assigned[code]or code.Name==values.parryInput then error("Конфликт биндов")end
            assigned[code]=true
        end
    end
    values.skillMode=source.skillMode or state.skillMode
    if values.skillMode~="Normal"and values.skillMode~="Perfect"then error("Неверный режим скиллчека")end
    values.espMeters={}
    if source.espMeters~=nil and type(source.espMeters)~="table"then error("Неверная метровка")end
    for id,current in pairs(state.espMeters)do
        local value=source.espMeters and source.espMeters[id]
        if value==nil then value=current end
        if type(value)~="boolean"then error("Неверная метровка: "..id)end
        values.espMeters[id]=value
    end
    values.soundOwnOnly=source.soundOwnOnly
    if values.soundOwnOnly==nil then values.soundOwnOnly=state.soundOwnOnly end
    if type(values.soundOwnOnly)~="boolean"then error("Неверный фильтр звуков")end
    values.customSounds={}
    if source.customSounds~=nil and type(source.customSounds)~="table"then error("Неверные звуки")end
    for id,current in pairs(state.customSounds)do
        local sound=type(source.customSounds)=="table"and source.customSounds[id]or nil
        if sound~=nil then
            if type(sound)~="table"or type(sound.id)~="string"or #sound.id>20
                or(sound.id~=""and not sound.id:match("^%d+$"))or(sound.sources~=nil and type(sound.sources)~="table")or not finite(sound.volume)or sound.volume<0 or sound.volume>2 then error("Неверный звук: "..id)end
            if sound.mode~=nil and type(sound.mode)~="string"then error("Неверный режим звука")end
            local mode=sound.mode or(current.mode or "BuiltIn")
            if mode=="System"then mode="BuiltIn"elseif mode=="Both"then mode="Custom"end
            if mode~="BuiltIn"and mode~="Custom"then error("Неверный режим звука")end
            local preset=sound.preset or "Ping"
            if not ({Ping=true,High=true,Low=true,Snap=true,SnapHigh=true,Bass=true,BassLow=true,Splash=true,SplashHigh=true})[preset]then error("Неверный встроенный звук")end
            values.customSounds[id]={id=sound.id,volume=sound.volume,sources=checkedIds(sound.sources or {}),mode="BuiltIn",preset=preset}
        else values.customSounds[id]=current end
    end
    values.collapsedGroups={}
    if source.collapsedGroups~=nil and type(source.collapsedGroups)~="table"then error("Неверные группы")end
    local groups=source.collapsedGroups or state.collapsedGroups
    if type(groups)~="table"then error("Неверные группы")end
    for id,closed in pairs(groups)do
        local legacyAudio={audioSources=true,misfireAudio=true,shotAudio=true,daggerAudio=true}
        local key=legacyAudio[id]and "customAudio"or((id=="bearTrap"or id=="skillCalibration")and "skillchecks"or(id=="playerEsp"and "worldEsp"or id))
        if type(closed)~="boolean"then error("Неверная группа")end
        if key~="cosmetic"and key~="hudLayout"then
            if not state.groupIds or not state.groupIds[key]then error("Неверная группа")end
            values.collapsedGroups[key]=values.collapsedGroups[key]or closed
        end
    end
    values.espColors={}
    for id,current in pairs(state.espColors)do
        local c=type(source.espColors)=="table"and source.espColors[id]or nil
        if c~=nil then
            if type(c)~="table"or #c~=3 then error("Неверный цвет ESP: "..id)end
            for i=1,3 do if not finite(c[i])or c[i]<0 or c[i]>1 then error("Неверный цвет ESP: "..id)end end
            values.espColors[id]=Color3.new(c[1],c[2],c[3])
        else values.espColors[id]=current end
    end
    if source.espColors~=nil and type(source.espColors)~="table"then error("Неверные цвета ESP")end
    values.widgetPositions={}
    if source.widgetPositions~=nil and type(source.widgetPositions)~="table"then error("Неверные позиции виджетов")end
    local positions=source.widgetPositions or state.widgetPositions
    if type(positions)~="table"then error("Неверные позиции виджетов")end
    local allowedWidgets={performance=true,perks=true,crosshair=true,hiddenFov=true,menuButton=true,parryButton=true,panicButton=true,nextRoundHud=true}
    for id,position in pairs(positions)do
        if not allowedWidgets[id]or type(position)~="table"or #position~=2 then error("Неверная позиция виджета")end
        for i=1,2 do if not finite(position[i])or position[i]<0 or position[i]>1 then error("Виджет вне экрана")end end
        if id~="panicButton"then values.widgetPositions[id]={position[1],position[2]}end
    end
    -- Menu dimensions are now controlled only by corner dragging.
    values.uiScale=1;values.uiTextScale=1;values.uiRadius=10;values.parryDelay=0
    values.sideWidth=math.clamp(math.floor(values.uiWidth*0.2),96,128)
    values.attackIds=source.attackIds and checkedIds(source.attackIds)or attackIds
    values.breakAnimationIds=source.breakAnimationIds and checkedIds(source.breakAnimationIds)or breakAnimationIds
    return values
end
local function applyConfig(text)
    local ok,values=pcall(validateConfig,text)
    if not ok then return false,tostring(values)end
    disableAll()
    for field in pairs(schemaNumbers)do state[field]=values[field]end
    state.aspect=values.aspect;state.parryInput=values.parryInput;state.shaderPreset=values.shaderPreset;state.stretchMode=values.stretchMode
    state.trapMode=values.trapMode;state.moonForwardBind=values.moonForwardBind;state.moonBackwardBind=values.moonBackwardBind
    state.emoteId=values.emoteId;state.emoteLoop=values.emoteLoop;state.emoteName=values.emoteName;state.emoteBind=values.emoteBind;state.selfHealBind=values.selfHealBind
    state.skillMode=values.skillMode;state.customSounds=values.customSounds;state.soundOwnOnly=values.soundOwnOnly;state.collapsedGroups=values.collapsedGroups
    state.espColors=values.espColors;state.espMeters=values.espMeters;state.widgetPositions=values.widgetPositions
    for _,field in ipairs({"menuBind","autoLoad","autoSave","showHints","uiFont","uiTheme","uiAccentColor"})do state[field]=values[field]end
    state.parryBind=values.parryBind;state.hiddenBind=values.hiddenBind;state.crossColor=values.crossColor
    attackIds=values.attackIds;breakAnimationIds=values.breakAnimationIds
    -- Synchronize numeric control closures and visible values before enabling features.
    for field,bounds in pairs(schemaNumbers)do
        local control=numericControls[bounds[3]]
        if control then control.set(values[field])end
    end
    state.backgroundImage=values.backgroundImage;state.menuAlpha=0
    state.aspect=values.aspect -- The custom-stretch setter also sets aspect; restore the selected preset.
    for field in pairs(toggleButtons)do state[field]=values[field];paintToggle(field)end
    if state.parry and not virtualInput then state.parry=false;paintToggle("parry")end
    bindButton.Text="Бинд авто парирования: "..bindLabel(state.parryBind)
    presetButton.Text="Пресет: "..(state.aspect=="custom"and "свой"or state.aspect)
    colorButton.Text="Цвет прицела: из конфига"
    if textControls[2350]then textControls[2350].sync(table.concat(listIds(breakAnimationIds),","))end
    unsupportedCamera=nil
    updateCamera();refreshESP();updateOverlays();applyExtras();refreshExtensions()
    if state.refreshAvatarUI then state.refreshAvatarUI()end
    if state.refreshTrapUI then state.refreshTrapUI()end
    if state.refreshHealBind then state.refreshHealBind()end
    if state.refreshSkillUI then state.refreshSkillUI()end
    if state.refreshAudioUI then state.refreshAudioUI()end
    if state.refreshColorControls then state.refreshColorControls()end
    if state.refreshPresentation then state.refreshPresentation()end
    if state.refreshStretchUI then state.refreshStretchUI()end
    if state.applyHudPositions then state.applyHudPositions()end
    return true
end
state.exportConfig=exportConfig
state.importConfig=applyConfig
label("IMPORT / EXPORT CONFIG",3154,24)
configBox=Instance.new("TextBox")
configBox.Name="ConfigJSON"
state.presentDiagnostic=function(text)configBox.Text=text end
configBox.Position=UDim2.fromOffset(14,3188)
configBox.Size=UDim2.new(1,-28,0,112)
configBox.BackgroundColor3=Color3.fromRGB(35,40,55)
configBox.TextColor3=Color3.fromRGB(242,245,255)
configBox.Font=Enum.Font.Code;configBox.TextSize=11
configBox.MultiLine=true;configBox.ClearTextOnFocus=false
configBox.TextWrapped=true;configBox.TextXAlignment=Enum.TextXAlignment.Left
configBox.TextYAlignment=Enum.TextYAlignment.Top
configBox.PlaceholderText="Вставь JSON сюда для Import config"
configBox.Text="";configBox.Parent=content
button("Export config",3312,function()
    local ok,text=pcall(exportConfig)
    if ok then configBox.Text=text;status.Text="Конфиг выведен в поле. Можно скопировать."
    else status.Text="Экспорт не удался: "..tostring(text)end
end)
button("Скопировать config",3354,function()
    local ok,text=pcall(exportConfig)
    if not ok then status.Text="Не удалось сформировать конфиг.";return end
    configBox.Text=text
    local copier=type(setclipboard)=="function"and setclipboard or (type(toclipboard)=="function"and toclipboard)
    if copier and pcall(copier,text)then status.Text="Конфиг скопирован."
    else configBox:CaptureFocus();status.Text="Скопируй JSON из поля вручную."end
end)
button("Import config",3396,function()
    local ok,reason=applyConfig(configBox.Text)
    status.Text=ok and "Конфиг применён."or "Конфиг отклонён: "..tostring(reason)
end)
label("Импортируются только проверенные настройки JSON.\nФункции после импорта включаются по сохранённым значениям.",3438,44)
content.CanvasSize=UDim2.fromOffset(0,3544)
refreshExtensions()
end


-- Object ESP and player distance labels. Metric display uses Roblox's standard
-- 1 stud = 0.28 m; custom game-world scales may differ. Only replicated objects.
do
local profiles = {
    generators={field="espGenerators", title="Генератор", color=Color3.fromRGB(255,220,80)},
    pumpkins={field="espPumpkins", title="Тыква", color=Color3.fromRGB(255,145,45)},
    windows={field="espWindows", title="Окно", color=Color3.fromRGB(70,220,255)},
    pallets={field="espPallets", title="Палета", color=Color3.fromRGB(100,240,130)},
    hooks={field="espHooks",title="Повес",color=Color3.fromRGB(245,110,145)},
}
local candidates, objectMarks, playerMarks = {}, {}, {}
local addedConnection, removedConnection
local function hasObjectEsp()
    return state.espGenerators or state.espPumpkins or state.espWindows or state.espPallets or state.espHooks
end
local CollectionService
pcall(function()CollectionService=game:GetService("CollectionService")end)
local function cleanName(value)return tostring(value):lower():gsub("[^%w]","")end
local function tagged(item,tag)
    if not CollectionService then return false end
    local ok,result=pcall(function()return CollectionService:HasTag(item,tag)end)
    return ok and result
end
local function classify(item)
    if not item:IsA("Model")and not item:IsA("BasePart")then return nil end
    -- Ignore character accessories/tools and cosmetic assets.
    local parent=item.Parent
    while parent and parent~=Workspace do
        if parent:IsA("Tool")or parent:FindFirstChildOfClass("Humanoid")then return nil end
        parent=parent.Parent
    end
    local name=cleanName(item.Name)
    local kind=cleanName(item:GetAttribute("ObjectType")or item:GetAttribute("InteractionType")or "")
    if name:match("^generator%d*$")or name:match("^gen%d+$")or kind=="generator"then return "generators"end
    if name:match("^pumpkin%d*$")or name:match("^eventpumpkin%d*$")then return "pumpkins"end
    if name:match("^pallet%d*$")or name=="palletwrong"or name=="droppedpallet"or kind=="pallet"then return "pallets"end
    if name:match("^hook%d*$")or name=="meathook"or name=="sacrificehook"or name=="hangingspot"or kind=="hook"or tagged(item,"Hook")then return "hooks"end
    -- VD reports actual vaults under Map/resources/Windows. Generic "Window"
    -- models in houses are often decorative and must not be highlighted.
    local node=item.Parent;local inWindows,inResources=false,false;local windowFolder
    while node and node~=Workspace do
        local ancestor=cleanName(node.Name)
        if ancestor=="windows"then inWindows=true;windowFolder=node end
        if inWindows and(ancestor=="resources"or ancestor=="map")then inResources=true;break end
        node=node.Parent
    end
    local namedWindow=name:match("^window%d*$")or(item:IsA("BasePart")and name=="bottom"and item.Parent and cleanName(item.Parent.Name):find("window",1,true))
    -- Some maps place window models directly in Map. The observed vault
    -- trigger and its VaultPoint distinguish these from decorative windows.
    if item:IsA("Model")then
        local trigger=item:FindFirstChild("VaultTrigger")
        local mapNode=item.Parent
        while mapNode and mapNode~=Workspace and cleanName(mapNode.Name)~="map"do mapNode=mapNode.Parent end
        if mapNode and mapNode~=Workspace and trigger and trigger:IsA("BasePart")
            and(trigger:FindFirstChild("VaultPoint")or tagged(trigger,"VaultPoint"))then return "windows"end
    end
    -- Some maps use different names for models immediately inside Windows.
    local windowEntry=inResources and item.Parent==windowFolder and(item:IsA("Model")or namedWindow or name=="bottom")
    if(inResources and namedWindow)or windowEntry or name:match("^vault%d*$")or name=="vaultwindow"or name=="windowvault"
        or kind=="vault"or kind=="window"or item:GetAttribute("IsVault")==true or tagged(item,"Vault")or tagged(item,"Window")then return "windows"end
    local prompt=item:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt and item:IsA("Model")and(namedWindow or name:find("vault",1,true))then prompt=item:FindFirstChildWhichIsA("ProximityPrompt",true)end
    if not prompt and item:IsA("Model")and item.PrimaryPart then prompt=item.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")end
    if prompt then
        local action=cleanName(prompt.ActionText)
        if action=="vault"or action=="vaultwindow"then return "windows"end
        if action=="hook"or action=="hang"then return "hooks"end
    end
end
local function anchor(item)
    if item:IsA("BasePart")then return item end
    if item:IsA("Model")then
        if classify(item)=="windows"then local bottom=item:FindFirstChild("Bottom",true);if bottom and bottom:IsA("BasePart")then return bottom end end
        if classify(item)=="hooks"then local hit=item:FindFirstChild("HitBox",true);if hit and hit:IsA("BasePart")then return hit end end
        return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart",true)
    end
end
state.classifyObject=classify
state.objectAnchor=anchor
local function destroyMark(mark)
    if mark.labelGui then mark.labelGui:Destroy() end
    if mark.highlight then mark.highlight:Destroy() end
    if mark.windowBox then mark.windowBox:Destroy() end
end
local function clearObjects()
    for item,mark in pairs(objectMarks) do destroyMark(mark);objectMarks[item]=nil end
end
local function clearPlayers()
    for who,mark in pairs(playerMarks) do destroyMark(mark);playerMarks[who]=nil end
end
-- One shared, bounded world index. No periodic full-map GetDescendants scans.
local queue,head,tail={},1,0
local windowObservations,observedWindows={},setmetatable({},{__mode="k"})
local childBatches,waitingChildren={},0
local pending=setmetatable({},{__mode="k"})
local expanded=setmetatable({},{__mode="k"})
local attributeWatches={}
local tagConnections={}
local function ignored(item)
    if item==Workspace then return false end
    local node=item
    while node and node~=Workspace do
        if node.Name=="VDHelperDistance"or node.Name=="VDHelperObjectESP"or node.Name=="SeterageWorldESP"then return true end
        node=node.Parent
    end
    return item:IsA("Tool")or item:IsA("Accessory")or(item:IsA("Model")and item:FindFirstChildOfClass("Humanoid")~=nil)
end
local function enqueue(item)
    if not item or pending[item]or ignored(item)then return end
    tail=tail+1;queue[tail]=item;pending[item]=true
end
local function clearIndex()
    queue,head,tail={},1,0;childBatches,waitingChildren={},0
    windowObservations,observedWindows={},setmetatable({},{__mode="k"})
    pending=setmetatable({},{__mode="k"});expanded=setmetatable({},{__mode="k"})
    for item,connections in pairs(attributeWatches)do for _,connection in ipairs(connections)do connection:Disconnect()end;attributeWatches[item]=nil end
    for _,connection in ipairs(tagConnections)do connection:Disconnect()end;tagConnections={}
    state.perf.indexPending=0
end
resetWorldEsp=function()
    clearObjects();clearPlayers();candidates={};clearIndex()
    if addedConnection then addedConnection:Disconnect();addedConnection=nil end
    if removedConnection then removedConnection:Disconnect();removedConnection=nil end
end
local function register(item)
    local kind=classify(item)
    local objectName=cleanName(item.Name)
    if not observedWindows[item]and(objectName:find("window",1,true)or objectName:find("vault",1,true))and #windowObservations<40 then
        observedWindows[item]=true
        local ok,full=pcall(function()return item:GetFullName()end)
        windowObservations[#windowObservations+1]={path=ok and full or item.Name,class=item.ClassName,kind=kind or "unrecognised"}
    end
    if kind then
        local parent=item.Parent
        while parent and parent~=Workspace do
            if classify(parent)==kind then kind=nil;break end
            parent=parent.Parent
        end
    end
    candidates[item]=kind
    if not kind and objectMarks[item]then destroyMark(objectMarks[item]);objectMarks[item]=nil end
end
local function watchObjects()
    if addedConnection then return end
    enqueue(Workspace)
    addedConnection=Workspace.DescendantAdded:Connect(function(item)
        if ignored(item)then return end
        enqueue(item)
        local parent=item.Parent
        -- Only nearby parents need reevaluation for newly streamed prompts/anchors.
        for _=1,3 do if not parent or parent==Workspace then break end;enqueue(parent);parent=parent.Parent end
    end)
    removedConnection=Workspace.DescendantRemoving:Connect(function(item)
        candidates[item]=nil;pending[item]=nil;expanded[item]=nil
        if attributeWatches[item]then for _,connection in ipairs(attributeWatches[item])do connection:Disconnect()end;attributeWatches[item]=nil end
        local mark=objectMarks[item];if mark then destroyMark(mark);objectMarks[item]=nil end
    end)
    if CollectionService then for _,tag in ipairs({"Window","Vault","Hook","VaultPoint"})do
        pcall(function()tagConnections[#tagConnections+1]=CollectionService:GetInstanceAddedSignal(tag):Connect(enqueue)end)
        pcall(function()tagConnections[#tagConnections+1]=CollectionService:GetInstanceRemovedSignal(tag):Connect(enqueue)end)
        if tag=="VaultPoint"then
            for _,item in ipairs(CollectionService:GetTagged(tag))do enqueue(item.Parent)end
            pcall(function()tagConnections[#tagConnections+1]=CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)enqueue(item.Parent)end)end)
            pcall(function()tagConnections[#tagConnections+1]=CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item)enqueue(item.Parent)end)end)
        end
    end end
end
local function processIndex()
    local processed,work,start=0,0,os.clock()
    while(head<=tail or #childBatches>0)and work<96 and os.clock()-start<.001 do
        work=work+1
        local item
        if head<=tail then item=queue[head];queue[head]=nil;head=head+1
        else
            local batch=childBatches[#childBatches]
            enqueue(batch.children[batch.next]);batch.next=batch.next+1;waitingChildren=waitingChildren-1
            if batch.next>#batch.children then childBatches[#childBatches]=nil end
        end
        if item then
            pending[item]=nil
            if(item==Workspace or item.Parent)and not ignored(item)then
                processed=processed+1
                if item~=Workspace then
                    register(item)
                    if item:IsA("Model")and not attributeWatches[item]then
                        local connections={};attributeWatches[item]=connections
                        pcall(function()connections[#connections+1]=item.AttributeChanged:Connect(function()enqueue(item)end)end)
                        connections[#connections+1]=item:GetPropertyChangedSignal("Name"):Connect(function()enqueue(item)end)
                    end
                end
                if not expanded[item]then
                    expanded[item]=true;local children=item:GetChildren()
                    if #children>0 then childBatches[#childBatches+1]={children=children,next=1};waitingChildren=waitingChildren+#children end
                end
            end
        end
    end
    if head>tail then queue,head,tail={},1,0 end
    state.perf.worldProcessed=state.perf.worldProcessed+processed
    state.perf.worldMaxBatch=math.max(state.perf.worldMaxBatch,processed)
    state.perf.indexPending=math.max(0,tail-head+1)+waitingChildren
    state.perf.worldMaxWork=math.max(state.perf.worldMaxWork or 0,work)
end
state.getWindowAnchors=function()
    local result={}
    for item,kind in pairs(candidates)do if kind=="windows"and item.Parent then local part=anchor(item);if part then result[#result+1]=part end end end
    return result
end
state.getIndexedObjects=function()
    local result={};for item,kind in pairs(candidates)do if item.Parent then result[#result+1]={item=item,kind=kind,part=anchor(item)}end end;return result
end
state.windowEspDiagnostics=function()
    local details={enabled=state.espWindows,range=state.espRange,indexPending=state.perf.indexPending,
        seen=windowObservations,recognised=0,withAnchor=0,marked=0,samples={}}
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    for item,kind in pairs(candidates)do if kind=="windows"and item.Parent then
        details.recognised=details.recognised+1
        local part=anchor(item)
        if part then
            details.withAnchor=details.withAnchor+1
            if root and #details.samples<20 then
                local ok,full=pcall(function()return item:GetFullName()end)
                details.samples[#details.samples+1]={path=ok and full or item.Name,distance=(part.Position-root.Position).Magnitude*.28}
            end
        end
        if objectMarks[item]then details.marked=details.marked+1 end
    end end
    return details
end
local function createMark(part,color,object)
    local billboard=Instance.new("BillboardGui")
    billboard.Name="VDHelperDistance"
    billboard.Adornee=part
    billboard.AlwaysOnTop=true
    billboard.LightInfluence=0
    billboard.Size=UDim2.fromOffset(190,38)
    billboard.StudsOffsetWorldSpace=Vector3.new(0,3,0)
    billboard.Parent=part
    local text=Instance.new("TextLabel")
    text.Size=UDim2.fromScale(1,1)
    text.BackgroundTransparency=1
    text.Font=Enum.Font.GothamBold
    text.TextSize=12
    text.TextColor3=color
    text.TextStrokeColor3=Color3.fromRGB(0,0,0)
    text.TextStrokeTransparency=0.2
    text.TextWrapped=true
    text.Parent=billboard
    local mark={labelGui=billboard,text=text,anchor=part}
    if object then
        local h=Instance.new("Highlight")
        h.Name="VDHelperObjectESP"
        h.Adornee=object
        h.FillColor=color;h.OutlineColor=color
        h.FillTransparency=0.8
        h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent=object
        mark.highlight=h
    end
    return mark
end
local function metres(studs)return studs*0.28 end
local function showMark(mark,name,distance,kind,object)
    mark.labelGui.MaxDistance=state.espRange/0.28
    local humanoid=object and object:IsA("Model")and object:FindFirstChildOfClass("Humanoid")
    local head=humanoid and object:FindFirstChild("Head")
    if humanoid and head and head:IsA("BasePart")then
        local vertical
        if state.espLabelsBelow then
            vertical=-(humanoid.HipHeight+mark.anchor.Size.Y/2+.1)
        else
            vertical=head.Position.Y-mark.anchor.Position.Y+head.Size.Y/2+.1
        end
        mark.labelGui.StudsOffsetWorldSpace=Vector3.new(0,vertical,0)
    else
        local frame,size
        if object and object:IsA("Model")then
            local ok,a,b=pcall(function()return object:GetBoundingBox()end)
            if ok then frame,size=a,b end
        end
        if not frame then frame,size=mark.anchor.CFrame,mark.anchor.Size end
        local halfHeight=(math.abs(frame.RightVector.Y)*size.X+math.abs(frame.UpVector.Y)*size.Y+math.abs(frame.LookVector.Y)*size.Z)/2
        local offset=frame.Position-mark.anchor.Position
        local vertical=offset.Y+(halfHeight+.15)*(state.espLabelsBelow and -1 or 1)
        mark.labelGui.StudsOffsetWorldSpace=Vector3.new(offset.X,math.clamp(vertical,-3,3),offset.Z)
    end
    mark.text.Text=name..(state.espMeters[kind]and(" · ≈"..string.format("%.1f",distance).." м")or "")
end
label("ОБЪЕКТЫ НА КАРТЕ",4000,24)
toggle("espGenerators","ESP генераторов",4034)
toggle("espPumpkins","ESP тыкв",4076)
toggle("espWindows","ESP окон",4118)
toggle("espPallets","ESP палет",4160)
toggle("espHooks","ESP повесов",4180)
toggle("killerDistance","ESP киллера",4202)
toggle("survivorDistance","ESP сурвов",4244)
toggle("espGeneratorState","Состояние генераторов",4035.7)
toggle("espPlayerState","Состояние игроков",4245.7)
toggle("espLabelsBelow","Надписи снизу",4260)
state.metricOptions={}
for _,entry in ipairs({{"generators",4035.5},{"pumpkins",4077.5},{"windows",4119.5},{"pallets",4161.5},{"hooks",4181.5},
    {"killerDistance",4203.5},{"survivorDistance",4245.5},{"killerHighlight",53.5}})do
    local id=entry[1]
    local b=button("Показывать метры",entry[2],function()
        state.espMeters[id]=not state.espMeters[id]
        if state.renderSwitches then state.renderSwitches()end
    end)
    b.Name="Meters_"..id
    state.metricOptions[id]={button=b,text="Показывать метры"}
end
label("Дальность этих ESP: 10–1500 м",4286,26)
numberInput(4320,500,10,1500,function(v)state.espRange=v end)
label("Метры приблизительные: 1 студ = 0.28 м.\nОбъекты определяются по именам в загруженной карте.",4362,44)
local objectInfo=label("ESP объектов выключен.",4416,50)
objectInfo.Name="ESPObjectInfo"
local function updateWorldEsp()
    if not state.alive then return end
    local anyObjects=hasObjectEsp()
    if anyObjects or state.fastVault then watchObjects()
    elseif addedConnection then
        resetWorldEsp()
    end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local counts={generators=0,pumpkins=0,windows=0,pallets=0,hooks=0}
    local keep={}
    if anyObjects and root then
        for item,kind in pairs(candidates) do
            if not item.Parent or not item:IsDescendantOf(Workspace) then
                candidates[item]=nil
            else
                local profile=profiles[kind]
                if state[profile.field] then
                    local part=anchor(item)
                    if part and part.Parent then
                        local distance=metres((part.Position-root.Position).Magnitude)
                        if distance<=state.espRange then
                            keep[item]=true;counts[kind]=counts[kind]+1
                            local mark=objectMarks[item]
                            if mark and mark.anchor~=part then destroyMark(mark);mark=nil end
                            if not mark then
                                mark=createMark(part,state.espColors[kind],item);objectMarks[item]=mark
                                if kind=="windows"then
                                    local box=Instance.new("BoxHandleAdornment");box.Name="VDHelperWindowShape"
                                    box.Adornee=part;box.Size=part.Size;box.AlwaysOnTop=true;box.ZIndex=1;box.Transparency=.82
                                    box.Parent=part;mark.windowBox=box
                                end
                            end
                            mark.text.TextColor3=state.espColors[kind]
                            mark.highlight.FillColor=state.espColors[kind];mark.highlight.OutlineColor=state.espColors[kind]
                            if mark.windowBox then mark.windowBox.Color3=state.espColors[kind];mark.windowBox.Size=part.Size end
                            local title=profile.title
                            if kind=="generators"then
                                local progress=item:GetAttribute("RepairProgress")
                                if progress==nil then
                                    local value=item:FindFirstChild("RepairProgress")
                                    if value and(value:IsA("NumberValue")or value:IsA("IntValue"))then progress=value.Value end
                                end
                                if type(progress)=="number"and progress==progress and progress>=0 and progress<=100 then
                                    title=title.." · "..string.format("%.1f%%",progress)
                                else title=title.." · прогресс: —"end
                                if state.espGeneratorState then
                                    local broken=item:GetAttribute("Broken")
                                    if type(broken)~="boolean"then broken=item:GetAttribute("IsBroken")end
                                    local regressing=item:GetAttribute("Regressing")
                                    if broken==true then title=title.." · сломан"
                                    elseif broken==false then title=title.." · цел"
                                    elseif regressing==true then title=title.." · регресс"
                                    elseif regressing==false then title=title.." · без регресса"
                                    else title=title.." · состояние: —"end
                                end
                            end
                            showMark(mark,title,distance,kind,item)
                        end
                    end
                end
            end
        end
    end
    for item,mark in pairs(objectMarks)do if not keep[item]then destroyMark(mark);objectMarks[item]=nil end end
    local keepPlayers={}
    if root and (state.killerDistance or state.survivorDistance or(state.esp and state.espMeters.killerHighlight)) then
        for _,who in ipairs(Players:GetPlayers())do
            local team=who.Team and who.Team.Name:lower()
            local killer=isKiller(who)
            local survivor=team=="survivor"or team=="survivors"
            if who~=player and ((killer and(state.killerDistance or(state.esp and state.espMeters.killerHighlight)))or(survivor and state.survivorDistance))then
                local char=who.Character
                local target=char and char:FindFirstChild("HumanoidRootPart")
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if target and hum and hum.Health>0 then
                    local distance=metres((target.Position-root.Position).Magnitude)
                    if distance<=state.espRange then
                        keepPlayers[who]=true
                        local mark=playerMarks[who]
                        if mark and(mark.anchor~=target or(mark.highlight and mark.highlight.Adornee~=char))then destroyMark(mark);mark=nil end
                        if not mark then
                            mark=createMark(target,killer and(state.killerDistance and state.espColors.killerDistance or state.espColors.killerHighlight)or state.espColors.survivorDistance,char)
                            playerMarks[who]=mark
                        end
                        mark.text.TextColor3=killer and(state.killerDistance and state.espColors.killerDistance or state.espColors.killerHighlight)or state.espColors.survivorDistance
                        if mark.highlight then mark.highlight.FillColor=mark.text.TextColor3;mark.highlight.OutlineColor=mark.text.TextColor3 end
                        local title=(killer and "Киллер "or "Сурв ")..(who.DisplayName or who.Name)
                        if survivor and state.espPlayerState then
                            local condition="здоров"
                            if state.isDowned(char)or hum.Health<=50 then condition="нокнут"
                            elseif hum.Health<95 then condition="ранен"end
                            if char:GetAttribute("IsHooked")==true then condition="на крюке"
                            elseif char:GetAttribute("IsCarried")==true then condition="несут"end
                            title=title.." · "..condition
                        end
                        showMark(mark,title,distance,killer and(state.killerDistance and "killerDistance"or "killerHighlight")or "survivorDistance",char)
                    end
                end
            end
        end
    end
    for who,mark in pairs(playerMarks)do if not keepPlayers[who]then destroyMark(mark);playerMarks[who]=nil end end
    objectInfo.Text=anyObjects and string.format("Генераторы %d · тыквы %d\nОкна %d · палеты %d · повесы %d",counts.generators,counts.pumpkins,counts.windows,counts.pallets,counts.hooks)
        or "ESP объектов выключен."
end
local espElapsed=0
connect(RunService.Heartbeat,function(dt)
    if hasObjectEsp()or state.fastVault then watchObjects();processIndex()end
    espElapsed=espElapsed+dt
    if espElapsed<.2 then return end;espElapsed=0
    updateWorldEsp()
end)
end

button("Выгрузить скрипт",3560,state.cleanup)


-- UI preferences are always available, regardless of character, team or items.
do
local function redraw()if state.applyStyle then state.applyStyle()end end
local options={}
local function option(field,text,y)
    local b
    b=button(text,y,function()state[field]=not state[field];redraw()end)
    options[field]={button=b,text=text}
end
label("ИНТЕРФЕЙС",5000,24)
local menuBindButton
menuBindButton=button("Клавиша меню: "..bindLabel(state.menuBind),5036,function()
    waitingBind=false
    bindButton.Text="Бинд авто парирования: "..bindLabel(state.parryBind)
    state.capturingBind=nil;refreshExtensions()
    state.capturingBind="menu"
    menuBindButton.Text="Клавиша · Backspace убрать · Esc отмена"
end)
connect(Input.InputBegan,function(input)
    if state.capturingBind~="menu"or Input:GetFocusedTextBox()then return end
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    local key=input.KeyCode
    if key==Enum.KeyCode.Escape then state.capturingBind=nil
    elseif key==Enum.KeyCode.Backspace then state.menuBind=Enum.KeyCode.Unknown;state.capturingBind=nil
    elseif key~=Enum.KeyCode.Unknown and key~=Enum.KeyCode.Space and key~=Enum.KeyCode.LeftShift and key~=state.emoteBind and key~=state.selfHealBind and key~=state.parryBind
        and key~=state.hiddenBind and key~=state.moonForwardBind and key~=state.moonBackwardBind and key.Name~=state.parryInput then
        state.menuBind=key;state.capturingBind=nil
    else status.Text="Клавиша занята."end
    redraw()
end)
option("autoLoad","Автозагрузка",5078)
option("autoSave","Автосохранение",5120)
button("Сохранить config в файл",5162,function()
    if state.saveConfigFile then
        local ok,reason=state.saveConfigFile()
        status.Text=ok and "Конфиг сохранён."or tostring(reason)
    end
end)
button("Загрузить config из файла",5204,function()
    if state.loadConfigFile then
        local ok,reason=state.loadConfigFile()
        status.Text=ok and "Конфиг загружен."or tostring(reason)
    end
end)
local fonts={"Gotham","SourceSans","Ubuntu","RobotoMono","Arial","Roboto","Oswald","FredokaOne","Nunito","TitilliumWeb","Code","Cartoon"}
local fontButton
fontButton=button("Шрифт: Gotham",5256,function()
    local index=1;for i,name in ipairs(fonts)do if name==state.uiFont then index=i end end
    state.uiFont=fonts[index%#fonts+1];redraw()
end)
local themes={"Graphite","Midnight","Light"}
local themeButton
 themeButton=button("Тема: Graphite",5298,function()
    local index=1;for i,name in ipairs(themes)do if name==state.uiTheme then index=i end end
    state.uiTheme=themes[index%#themes+1];redraw()
end)
button("Переместить меню в центр",5732,function()state.menuX=0.5;state.menuY=0.5;redraw()end)
option("showHints","Краткие подсказки",5774)
local overlayInfo=label("Слой интерфейса: "..tostring(state.overlayMode),5816,26)
local fileInfo=label("Проверка сохранения…",5850,30)
state.fileInfo=fileInfo
state.uiOptions=options
state.refreshUiOptions=function()
    if state.capturingBind~="menu"then menuBindButton.Text="Клавиша меню: "..bindLabel(state.menuBind)end
    fontButton.Text="Шрифт: "..state.uiFont
    themeButton.Text="Тема: "..state.uiTheme
    for field,entry in pairs(options)do
        entry.button.Text=entry.text
    end
    overlayInfo.Text="Слой интерфейса: "..tostring(state.overlayMode)
end
end

-- Resize from any corner; dimensions are persisted, not edited as numbers.
do
local handles={}
local resize
local corners={{"NW",0,0},{"NE",1,0},{"SW",0,1},{"SE",1,1}}
for _,corner in ipairs(corners)do
    local h=Instance.new("TextButton")
    h.Name="Resize_"..corner[1]
    h.AnchorPoint=Vector2.new(0.5,0.5)
    h.Position=UDim2.new(corner[2],corner[2]==0 and 8 or -8,corner[3],corner[3]==0 and 8 or -8)
    h.Size=UDim2.fromOffset(18,18)
    h.BackgroundTransparency=1
    h.Text="•";h.TextSize=18;h.Font=Enum.Font.GothamBold
    h.ZIndex=30;h.Parent=panel;handles[#handles+1]=h
    connect(h.InputBegan,function(input)
        if collapsed or not state.menuVisible then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local screen=gui.AbsoluteSize
        if screen.X<=0 or screen.Y<=0 then return end
        local width,height=state.uiWidth*scale.Scale,state.uiHeight*scale.Scale
        local x,y=state.menuX*screen.X,state.menuY*screen.Y
        resize={input=input,start=input.Position,left=x-width/2,right=x+width/2,top=y-height/2,bottom=y+height/2,
            sx=corner[2],sy=corner[3],scale=scale.Scale}
        dragInput=nil;state.resizing=true
    end)
end
state.syncResizeHandles=function()
    for _,h in ipairs(handles)do
        h.Visible=not collapsed
        h.BackgroundTransparency=1;h.TextColor3=state.uiAccentColor
    end
end
connect(Input.InputChanged,function(input)
    if not resize then return end
    if not state.menuVisible then resize=nil;state.resizing=false;return end
    if input~=resize.input and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local screen=gui.AbsoluteSize
    if screen.X<=0 or screen.Y<=0 then return end
    local delta=input.Position-resize.start
    local l,r,t,b=resize.left,resize.right,resize.top,resize.bottom
    local minWidth=math.min(420*resize.scale,screen.X-16)
    local minHeight=math.min(320*resize.scale,screen.Y-16)
    if resize.sx==0 then l=math.clamp(l+delta.X,8,math.max(8,r-minWidth))
    else r=math.clamp(r+delta.X,math.min(screen.X-8,l+minWidth),screen.X-8)end
    if resize.sy==0 then t=math.clamp(t+delta.Y,8,math.max(8,b-minHeight))
    else b=math.clamp(b+delta.Y,math.min(screen.Y-8,t+minHeight),screen.Y-8)end
    state.uiWidth=math.clamp((r-l)/resize.scale,420,1200)
    state.uiHeight=math.clamp((b-t)/resize.scale,320,1000)
    state.menuX=(l+r)/2/screen.X;state.menuY=(t+b)/2/screen.Y
    state.applyStyle()
end)
connect(Input.InputEnded,function(input)
    if resize and(input==resize.input or input.UserInputType==Enum.UserInputType.MouseButton1)then
        resize=nil;state.resizing=false
    end
end)
end

-- The next-round card uses only values explicitly published by the game.
do
    local frame=overlay("NextRoundHud",240,70,UDim2.fromScale(.75,.18),Vector2.new(.5,.5))
    local content=overlayLabel(frame,"Киллер: нет данных\nКарта: нет данных",4,62)
    content.Name="NextRoundHudText";content.TextXAlignment=Enum.TextXAlignment.Left
    state.nextRoundHud=frame;state.nextRoundHudText=content
end

-- HUD drag is always available; a compact grip leaves the center of aim overlays clear.
do
local controllers={}
local moving
state.cancelWidgetDrag=function()moving=nil;state.draggingWidget=false end
pcall(function()connect(Input.WindowFocusReleased,state.cancelWidgetDrag)end)
local function createMover(target,id,titleText,enabled,default)
    local handle=Instance.new("Frame")
    handle.Name="MoveHUD_"..id
    handle.AnchorPoint=Vector2.new(0.5,0.5)
    handle.Active=true
    handle.BackgroundColor3=Color3.fromRGB(50,100,130)
    handle.BackgroundTransparency=0.8
    handle.ZIndex=id=="perks"and 23 or 5
    handle.Visible=false
    handle.Parent=target.Parent
    local outline=Instance.new("UIStroke");outline.Thickness=1;outline.Color=state.uiAccentColor;outline.Parent=handle
    local caption=Instance.new("TextLabel")
    caption.Name="MoveCaption"
    caption.BackgroundTransparency=1;caption.Position=UDim2.new(0,0,0,-18)
    caption.Size=UDim2.new(1,0,0,18);caption.Font=Enum.Font.GothamBold;caption.TextSize=11
    caption.TextColor3=Color3.fromRGB(220,240,255);caption.Text=titleText;caption.Parent=handle
    local controller={target=target,id=id,handle=handle,enabled=enabled,default=default,outline=outline}
    controllers[#controllers+1]=controller
    local function beginMove(input,origin)
        if not enabled()then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local root=target.Parent.AbsoluteSize
        if root.X<=0 or root.Y<=0 then return end
        local p=state.widgetPositions[id]or default
        moving={controller=controller,input=input,start=input.Position,x=p[1],y=p[2],moved=false,origin=origin}
        state.draggingWidget=true
        if id=="menuButton"then state.logoDragged=false end
    end
    connect(handle.InputBegan,function(input)beginMove(input,"handle")end)
    if id=="menuButton"then connect(target.InputBegan,function(input)beginMove(input,"button")end)end
end
createMover(meters,"performance","FPS / Ping",function()return state.stats end,{0.5,0.045})
createMover(perkBox,"perks","Перки",function()return state.perks end,{0.16,0.16})
createMover(cross,"crosshair","Прицел",function()return state.crosshair end,{0.5,0.5})
createMover(state.hiddenCircle,"hiddenFov","FOV Hidden M2",function()return state.hiddenAim and state.showHiddenFov and isKiller(player)end,{0.5,0.5})
createMover(floatingMenu,"menuButton","Меню",function()return true end,{0.035,0.5})
createMover(mobileParry,"parryButton","Парирование",function()return Input.TouchEnabled end,{0.07,0.59})
createMover(state.nextRoundHud,"nextRoundHud","Следующий раунд",function()return state.showNextHud or state.nextRound or state.nextRoundMap or state.nextRoundKiller end,{0.75,0.18})

state.applyHudPositions=function()
    if not state.alive then return end
    for _,c in ipairs(controllers)do
        local screen=c.target.Parent.AbsoluteSize
        if screen.X>0 and screen.Y>0 then
            local p=state.widgetPositions[c.id]or{c.default[1],c.default[2]}
            local width=math.max(c.target.AbsoluteSize.X,c.target.Size.X.Offset,1)
            local height=math.max(c.target.AbsoluteSize.Y,c.target.Size.Y.Offset,1)
            local halfX=math.min(width/2,screen.X/2)
            local halfY=math.min(height/2,screen.Y/2)
            p={math.clamp(p[1],halfX/screen.X,1-halfX/screen.X),math.clamp(p[2],halfY/screen.Y,1-halfY/screen.Y)}
            state.widgetPositions[c.id]=p
            c.target.AnchorPoint=Vector2.new(0.5,0.5)
            c.target.Position=UDim2.fromScale(p[1],p[2])
            c.handle.Position=c.target.Position
            c.handle.Size=UDim2.fromOffset(math.max(48,width),math.max(32,height))
        end
        c.handle.Visible=c.enabled()and c.target.Visible
        local compact=c.id=="hiddenFov"or c.id=="crosshair"
        c.handle.BackgroundTransparency=compact and 0.3 or 1
        c.outline.Enabled=moving~=nil and moving.controller==c
        local caption=c.handle:FindFirstChild("MoveCaption")
        if compact then
            local p=state.widgetPositions[c.id]or c.default
            local halfHeight=math.max(c.target.AbsoluteSize.Y,c.target.Size.Y.Offset)/2
            c.handle.Size=UDim2.fromOffset(24,16)
            c.handle.Position=UDim2.fromOffset(p[1]*screen.X,math.max(12,p[2]*screen.Y-halfHeight-12))
            if caption then caption.Position=UDim2.new(0,0,0,0);caption.Size=UDim2.fromScale(1,1);caption.Text="⋮";caption.Visible=true end
        elseif caption then caption.Visible=moving~=nil and moving.controller==c end
        c.outline.Color=state.uiAccentColor
    end
end
connect(Input.InputChanged,function(input)
    if not moving then return end
    if input~=moving.input and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local screen=moving.controller.target.Parent.AbsoluteSize
    if screen.X<=0 or screen.Y<=0 then return end
    local delta=input.Position-moving.start
    if delta.Magnitude>4 then
        moving.moved=true
        if moving.controller.id=="menuButton"then state.logoDragged=true end
    end
    state.widgetPositions[moving.controller.id]={math.clamp(moving.x+delta.X/screen.X,0,1),math.clamp(moving.y+delta.Y/screen.Y,0,1)}
    state.applyHudPositions()
end)
connect(Input.InputEnded,function(input)
    if moving and(input==moving.input or input.UserInputType==Enum.UserInputType.MouseButton1)then
        local finished=moving;moving=nil;state.draggingWidget=false
        if not finished.moved and finished.origin~="button"then
            local id=finished.controller.id
            if id=="menuButton"then setMenuVisible(not state.menuVisible)

            elseif id=="parryButton"then state.setParry(not state.parry)end
        end
    end
end)
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<0.1 then return end;elapsed=0
    state.applyHudPositions()
end)
end

-- Full HSV palette. Color buttons are adjacent to the feature they affect.
do
local specs={
    {"killerHighlight","Цвет подсветки",53},{"generators","Цвет генераторов",4035},
    {"hooks","Цвет повесов",4181},{"pumpkins","Цвет тыкв",4077},{"windows","Цвет окон",4119},{"pallets","Цвет палет",4161},
    {"killerDistance","Цвет дистанции киллера",4203},{"survivorDistance","Цвет дистанции сурвов",4245},
    {"perks","Цвет перков",687},{"stats","Цвет FPS / Ping",1105},
    {"hiddenFov","Цвет FOV M2",2758},{"parryFov","Цвет радиуса даггера",1372},
    {"accent","Цвет акцента меню",5340},
}
local controls={}
local function colorFor(id)
    if id=="crosshair"then return state.crossColor end
    if id=="accent"then return state.uiAccentColor end
    return state.espColors[id]
end
local popup=Instance.new("Frame");popup.Name="ColorPalette";popup.Size=UDim2.fromOffset(248,234)
popup.BackgroundColor3=Color3.fromRGB(21,20,30);popup.BorderSizePixel=0;popup.ZIndex=50
popup.Visible=false;popup.Parent=gui
local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,10);round.Parent=popup
local heading=Instance.new("TextLabel");heading.BackgroundTransparency=1;heading.Position=UDim2.fromOffset(12,4)
heading.Size=UDim2.fromOffset(184,28);heading.Text="Цвет";heading.TextSize=13;heading.Font=Enum.Font.Gotham
heading.TextColor3=Color3.new(1,1,1);heading.ZIndex=51;heading.Parent=popup
local close=Instance.new("TextButton");close.Name="ClosePalette";close.Text="×";close.TextSize=18
close.Position=UDim2.fromOffset(212,4);close.Size=UDim2.fromOffset(28,28);close.BackgroundTransparency=1;close.ZIndex=52;close.Parent=popup
connect(close.Activated,function()popup.Visible=false end)
local sv=Instance.new("TextButton");sv.Name="PaletteSV";sv.Text="";sv.AutoButtonColor=false;sv.BorderSizePixel=0
sv.Position=UDim2.fromOffset(12,38);sv.Size=UDim2.fromOffset(194,146);sv.ZIndex=51;sv.BackgroundColor3=Color3.new(1,1,1);sv.Parent=popup
local horizontal=Instance.new("UIGradient");horizontal.Parent=sv
local dark=Instance.new("Frame");dark.BackgroundColor3=Color3.new(0,0,0);dark.Size=UDim2.fromScale(1,1);dark.BorderSizePixel=0;dark.ZIndex=52;dark.Parent=sv
local vertical=Instance.new("UIGradient");vertical.Rotation=90
vertical.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)});vertical.Parent=dark
local hue=Instance.new("TextButton");hue.Name="PaletteHue";hue.Text="";hue.AutoButtonColor=false;hue.BackgroundColor3=Color3.new(1,1,1)
hue.Position=UDim2.fromOffset(218,38);hue.Size=UDim2.fromOffset(18,146);hue.BorderSizePixel=0;hue.ZIndex=51;hue.Parent=popup
local rainbow=Instance.new("UIGradient");rainbow.Rotation=90
local stops={};for i=0,6 do stops[#stops+1]=ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))end
rainbow.Color=ColorSequence.new(stops);rainbow.Parent=hue
local dot=Instance.new("Frame");dot.Name="PaletteCursor";dot.Size=UDim2.fromOffset(8,8);dot.AnchorPoint=Vector2.new(0.5,0.5)
dot.BackgroundTransparency=1;dot.ZIndex=53;dot.Parent=sv
local ring=Instance.new("UIStroke");ring.Color=Color3.new(1,1,1);ring.Thickness=2;ring.Parent=dot
local dotCorner=Instance.new("UICorner");dotCorner.CornerRadius=UDim.new(1,0);dotCorner.Parent=dot
local hueMark=Instance.new("Frame");hueMark.Size=UDim2.new(1,4,0,3);hueMark.Position=UDim2.fromOffset(-2,0)
hueMark.BackgroundColor3=Color3.new(1,1,1);hueMark.BorderSizePixel=0;hueMark.ZIndex=53;hueMark.Parent=hue
local preview=Instance.new("Frame");preview.Name="PalettePreview";preview.Position=UDim2.fromOffset(12,198)
preview.Size=UDim2.fromOffset(224,22);preview.BorderSizePixel=0;preview.ZIndex=51;preview.Parent=popup
local selected,h,saturation,value,drag,anchor=nil,0,1,1,nil,nil
local function redraw()
    horizontal.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromHSV(h,1,1))
    dot.Position=UDim2.fromScale(saturation,1-value);hueMark.Position=UDim2.new(0,-2,h,0)
    if selected then preview.BackgroundColor3=colorFor(selected)end
end
state.openColor=function(id,button)
    selected=id;anchor=button
    h,saturation,value=colorFor(id):ToHSV();heading.Text=controls[id]and controls[id].box.Text or "Палитра"
    popup.Visible=true;redraw()
end
local function change(point,kind)
    if not selected then return end
    if kind=="hue"then h=math.clamp((point.Y-hue.AbsolutePosition.Y)/math.max(hue.AbsoluteSize.Y,1),0,1)
    else saturation=math.clamp((point.X-sv.AbsolutePosition.X)/math.max(sv.AbsoluteSize.X,1),0,1)
        value=1-math.clamp((point.Y-sv.AbsolutePosition.Y)/math.max(sv.AbsoluteSize.Y,1),0,1)end
    local color=Color3.fromHSV(h,saturation,value)
    if selected=="crosshair"then state.crossColor=color
    elseif selected=="accent"then state.uiAccentColor=color else state.espColors[selected]=color end
    redraw();if state.applyEspColors then state.applyEspColors()end
    if selected=="accent"and state.applyStyle then state.applyStyle()end
    refreshESP()
end
local svHit=Instance.new("TextButton");svHit.Name="PaletteSVHit";svHit.Text="";svHit.BackgroundTransparency=1
svHit.AutoButtonColor=false;svHit.Position=sv.Position;svHit.Size=sv.Size;svHit.ZIndex=54;svHit.Parent=popup
local hueHit=Instance.new("TextButton");hueHit.Name="PaletteHueHit";hueHit.Text="";hueHit.BackgroundTransparency=1
hueHit.AutoButtonColor=false;hueHit.Position=hue.Position;hueHit.Size=hue.Size;hueHit.ZIndex=54;hueHit.Parent=popup
for _,entry in ipairs({{svHit,"sv"},{hueHit,"hue"}})do
    connect(entry[1].InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag={input=input,kind=entry[2]};change(input.Position,entry[2])
        end
    end)
end
connect(Input.InputChanged,function(input)
    if drag and(input==drag.input or input.UserInputType==Enum.UserInputType.MouseMovement)then change(input.Position,drag.kind)end
end)
connect(Input.InputEnded,function(input)if drag and(input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1)then drag=nil end end)
connect(RunService.RenderStepped,function()
    if not popup.Visible then return end
    if not state.menuVisible or not anchor or not state.menuRowVisible(anchor)then popup.Visible=false;drag=nil;return end
    local screen=gui.AbsoluteSize;local p=anchor.AbsolutePosition
    popup.Position=UDim2.fromOffset(math.clamp(p.X,4,math.max(4,screen.X-252)),math.clamp(p.Y+anchor.AbsoluteSize.Y+4,4,math.max(4,screen.Y-238)))
end)
for _,spec in ipairs(specs)do
    local id,name,y=spec[1],spec[2],spec[3];local b
    b=button(name,y,function()state.openColor(id,b)end);b.Name="ESPColor_"..id
    local swatch=Instance.new("Frame");swatch.Name="ColorPreview";swatch.BorderSizePixel=0;swatch.ZIndex=2
    swatch.Position=UDim2.new(1,-30,0.5,-8);swatch.Size=UDim2.fromOffset(16,16);swatch.Parent=b
    controls[id]={box=b,swatch=swatch}
end
do
    local swatch=Instance.new("Frame");swatch.Name="ColorPreview";swatch.BorderSizePixel=0;swatch.ZIndex=2
    swatch.Position=UDim2.new(1,-30,0.5,-8);swatch.Size=UDim2.fromOffset(16,16);swatch.Parent=colorButton
    controls.crosshair={box=colorButton,swatch=swatch}
end
state.refreshColorControls=function()
    for id,c in pairs(controls)do c.swatch.BackgroundColor3=colorFor(id)end
    if selected then h,saturation,value=colorFor(selected):ToHSV();redraw()end
end
state.applyEspColors=function()
    crossH.BackgroundColor3=state.crossColor;crossV.BackgroundColor3=state.crossColor
    meterText.TextColor3=state.espColors.stats
    for _,item in ipairs(perkBox:GetDescendants())do if item:IsA("TextLabel")then item.TextColor3=state.espColors.perks end end
    for _,mark in pairs(highlights)do mark.FillColor=state.espColors.killerHighlight;mark.OutlineColor=state.espColors.killerHighlight end
    for id,c in pairs(controls)do c.swatch.BackgroundColor3=colorFor(id)end
    refreshExtensions()
end
end

-- Compact boolean switches: purple on, black off.
do
local switches=setmetatable({},{__mode="k"})
local function render(button,text,enabled)
    local parts=switches[button]
    if not parts then
        local label=Instance.new("TextLabel");label.Name="SwitchLabel";label.BackgroundTransparency=1
        label.Position=UDim2.fromOffset(10,0);label.Size=UDim2.new(1,-62,1,0)
        label.TextXAlignment=Enum.TextXAlignment.Left;label.TextWrapped=true;label.Font=Enum.Font.Gotham;label.TextSize=12
        label.TextColor3=Color3.fromRGB(225,228,240);label.Parent=button
        local bar=Instance.new("Frame");bar.Name="SwitchTrack";bar.BorderSizePixel=0
        bar.AnchorPoint=Vector2.new(1,0.5);bar.Position=UDim2.new(1,-12,0.5,0);bar.Size=UDim2.fromOffset(36,20);bar.Parent=button
        local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=bar
        local thumb=Instance.new("Frame");thumb.Name="SwitchThumb";thumb.BorderSizePixel=0
        thumb.Size=UDim2.fromOffset(14,14);thumb.AnchorPoint=Vector2.new(0,0.5);thumb.Parent=bar
        local tc=Instance.new("UICorner");tc.CornerRadius=UDim.new(1,0);tc.Parent=thumb
        parts={bar=bar,thumb=thumb,label=label};switches[button]=parts
    end
    button.Text=text;button.TextTransparency=1;parts.label.Text=text;button.TextXAlignment=Enum.TextXAlignment.Left
    parts.bar.BackgroundColor3=enabled and state.uiAccentColor or Color3.fromRGB(55,58,72)
    parts.thumb.BackgroundColor3=enabled and Color3.fromRGB(255,255,255)or Color3.fromRGB(164,168,184)
    parts.thumb.Position=UDim2.new(0,enabled and 19 or 3,0.5,0)
end
state.renderSwitches=function()
    for field,entry in pairs(toggleButtons)do render(entry.button,entry.text,state[field])end
    for field,entry in pairs(state.uiOptions or {})do render(entry.button,entry.text,state[field])end
    for id,entry in pairs(state.metricOptions or {})do render(entry.button,entry.text,state.espMeters[id])end
    render(mobileParry,"Пари",state.parry)
end
end

-- Selected zone: submit on its first observed frame, without user timing offsets.
do
local modeButton=state.dropdown(7010,"Режим",function()return {{value="Normal",label="Normal"},{value="Perfect",label="Perfect"}}end,
    function()return state.skillMode end,function(value)state.skillMode=value end,"skillMode")
label("Normal — вход в обычную зону. Perfect — вход в белую.",7052,32)
state.refreshSkillUI=function()modeButton:refresh()end
end

-- Local custom event audio. No parry attempt is treated as a confirmed stun.
do
local SoundService=game:GetService("SoundService")
local folder=Instance.new("Folder");folder.Name="VDHelperAudio";folder.Parent=SoundService
local specs={
    {id="dagger",field="daggerSound",title="Звук стана даггером",y=8010},
    {id="shot",field="shotSound",title="Звук выстрела",y=8310},
    {id="misfire",field="misfireSound",title="Звук взрыва пистолета",y=8610},
}
local presets={
    Ping={name="Чистый сигнал",asset="rbxasset://sounds/electronicpingshort.wav",speed=1},
    High={name="Высокий сигнал",asset="rbxasset://sounds/electronicpingshort.wav",speed=1.55},
    Low={name="Низкий сигнал",asset="rbxasset://sounds/electronicpingshort.wav",speed=0.6},
    Snap={name="Щелчок",asset="rbxasset://sounds/snap.wav",speed=1},
    SnapHigh={name="Резкий щелчок",asset="rbxasset://sounds/snap.wav",speed=1.4},
    Bass={name="Бас",asset="rbxasset://sounds/bass.wav",speed=1},
    BassLow={name="Низкий бас",asset="rbxasset://sounds/bass.wav",speed=0.7},
    Splash={name="Всплеск",asset="rbxasset://sounds/impact_water.mp3",speed=1},
    SplashHigh={name="Быстрый всплеск",asset="rbxasset://sounds/impact_water.mp3",speed=1.4},
}
local presetOrder={"Ping","High","Low","Snap","SnapHigh","Bass","BassLow","Splash","SplashHigh"}
local active,watches,rootConnections,lastEvent={},{},{},{}
local recentSource,muted={},{}
local audioEvents={}
state.audioDiagnostics=function()
    return {daggerEnabled=state.daggerSound,ownOnly=state.soundOwnOnly,
        daggerPreset=state.customSounds.dagger.preset,daggerVolume=state.customSounds.dagger.volume,events=audioEvents}
end
local audioInfo=label("Автособытия зависят от звуков текущей версии VD.",8948,34)
local function destroyClip(sound)
    local entry=active[sound]
    if entry and entry.connection then entry.connection:Disconnect()end
    if entry and entry.loaded then entry.loaded:Disconnect()end
    active[sound]=nil
    pcall(function()sound:Stop();sound:Destroy()end)
end
local function play(id,preview)
    local config=state.customSounds[id]
    if not config then return false,"Неизвестное событие."end
    local count=0;for _ in pairs(active)do count=count+1 end
    if count>=8 then return false,"Слишком много звуков одновременно."end
    local sound=Instance.new("Sound");sound.Name="VDHelperCustomAudio"
    local preset=presets[config.preset or "Ping"]or presets.Ping
    local event={kind=preview and "preview"or "replacement",event=id,preset=config.preset,asset=preset.asset,volume=config.volume}
    audioEvents[#audioEvents+1]=event;if #audioEvents>30 then table.remove(audioEvents,1)end
    sound.SoundId=preset.asset
    sound.PlaybackSpeed=preset.speed
    sound.Volume=config.volume;sound.Looped=false
    sound.Parent=folder
    active[sound]={id=id}
    active[sound].connection=sound.Ended:Connect(function()destroyClip(sound)end)
    local ok=pcall(function()sound:Play()end)
    event.playCall=ok
    if not ok then destroyClip(sound);return false,"Звук недоступен."end
    task.delay(5,function()
        if state.alive and active[sound]and not sound.IsLoaded then
            event.loaded=false
            audioInfo.Text="Встроенный звук не загрузился."
            destroyClip(sound)
        end
    end)
    task.delay(20,function()if active[sound]then destroyClip(sound)end end)
    if preview then audioInfo.Text="Прослушивание: "..id end
    return true,nil,sound
end
state.previewSound=play
local function cleanName(value)return tostring(value or ""):lower():gsub("[^a-z]","")end
local function ownSource(sound)
    local char=player.Character
    if char and sound:IsDescendantOf(char)then return true end
    if sound:IsDescendantOf(player.PlayerGui)then return true end
    local owner=sound:GetAttribute("SourceUserId")
    return owner~=nil and owner==player.UserId
end
local function identify(sound)
    if sound.Name=="VDHelperCustomAudio"or sound:IsDescendantOf(folder)then return nil end
    if state.soundOwnOnly and not ownSource(sound)then return nil end
    local sourceId=tostring(sound.SoundId):match("%d+")
    for _,spec in ipairs(specs)do
        if state[spec.field]and sourceId and state.customSounds[spec.id].sources[sourceId]then return spec.id end
    end
    local name=cleanName(sound.Name)
    local context=name;local parent=sound.Parent
    for _=1,4 do if not parent then break end;context=context..cleanName(parent.Name);parent=parent.Parent end
    local gun=context:find("twistoffate",1,true)or context:find("revolver",1,true)or context:find("pistol",1,true)
    if state.misfireSound and(name=="twistoffatemisfire"or name=="pistolbackfire"or name=="gunexplode"
        or name=="revolvermisfire"or(gun and(name=="misfire"or name=="backfire"or name=="explode")))then return "misfire"end
    if state.shotSound and(name=="twistoffateshot"or name=="revolvershot"or name=="pistolshot"
        or(gun and(name=="gunshot"or name=="fire"or name=="shoot")))then return "shot"end
    if state.daggerSound and(name=="parrysuccess"or name=="daggerstun"or name=="parrystun"or name=="successfulparry")then return "dagger"end
end
local function restoreOriginal(sound)
    local entry=muted[sound]
    if not entry then return end
    for _,connection in ipairs(entry.connections)do connection:Disconnect()end
    pcall(function()sound.Volume=entry.volume end)
    muted[sound]=nil
end
local function muteOriginal(sound,id)
    if muted[sound]then return end
    local entry={volume=sound.Volume,id=id,connections={}};muted[sound]=entry
    entry.connections[1]=sound.Ended:Connect(function()restoreOriginal(sound)end)
    entry.connections[2]=sound.Stopped:Connect(function()restoreOriginal(sound)end)
    sound.Volume=0
end
local function stopWatch(sound)
    restoreOriginal(sound)
    if watches[sound]then watches[sound]:Disconnect();watches[sound]=nil end
end
local function watch(sound)
    if not sound:IsA("Sound")or watches[sound]or sound.Name=="VDHelperCustomAudio"or sound:IsDescendantOf(folder)then return end
    watches[sound]=sound.Played:Connect(function()
        if not state.alive then return end
        local id=identify(sound)
        if state.daggerSound then
            local ok,path=pcall(function()return sound:GetFullName()end)
            audioEvents[#audioEvents+1]={kind="gameSound",name=sound.Name,path=ok and path or sound.Name,
                asset=tostring(sound.SoundId),own=ownSource(sound),identified=id}
            if #audioEvents>30 then table.remove(audioEvents,1)end
        end
        if not id or os.clock()-(lastEvent[id]or -math.huge)<0.15 then return end
        lastEvent[id]=os.clock()
        recentSource[id]=tostring(sound.SoundId):match("%d+")
        local ok,reason,clip=play(id)
        if ok then
            if clip.IsLoaded then muteOriginal(sound,id)
            elseif active[clip]then
                active[clip].loaded=clip.Loaded:Connect(function()
                    if state.alive and sound.IsPlaying then muteOriginal(sound,id)end
                end)
            end
        end
        audioInfo.Text=ok and("Событие: "..id)or tostring(reason)
    end)
end
local function clearWatches()
    for sound in pairs(watches)do stopWatch(sound)end
    for _,connection in ipairs(rootConnections)do connection:Disconnect()end
    rootConnections={}
    for sound in pairs(muted)do restoreOriginal(sound)end
end
resetAudio=function()
    clearWatches()
    for sound in pairs(active)do destroyClip(sound)end
    if not state.alive then folder:Destroy()end
end
local function enabled()return state.daggerSound or state.shotSound or state.misfireSound end
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<0.3 then return end;elapsed=0
    if not enabled()then if #rootConnections>0 then clearWatches()end;return end
    if #rootConnections>0 then return end
    for _,root in ipairs({Workspace,SoundService,player.PlayerGui})do
        for _,item in ipairs(root:GetDescendants())do watch(item)end
        rootConnections[#rootConnections+1]=root.DescendantAdded:Connect(watch)
        rootConnections[#rootConnections+1]=root.DescendantRemoving:Connect(stopWatch)
    end
end)
local controls={}
for _,spec in ipairs(specs)do
    local id,y=spec.id,spec.y
    toggle(spec.field,spec.title,y)
    local presetButton=button("Встроенный: Чистый сигнал",y+36,function()
        local index=1
        for i,name in ipairs(presetOrder)do if name==state.customSounds[id].preset then index=i end end
        state.customSounds[id].preset=presetOrder[index%#presetOrder+1];state.refreshAudioUI()
    end)
    presetButton.Name="SoundPreset_"..id
    label("Громкость",y+84+14,24)
    local volumeY=y+110
    numberInput(volumeY,1,0,2,function(v)state.customSounds[id].volume=v end)
    local preview=button("Прослушать",y+154,function()
        local ok,reason=play(id,true);if not ok then status.Text=reason end
    end)
    preview.Name="SoundPreview_"..id
    label("ID исходного звука события — необязательно",y+196,24)
    local sourceY=y+224
    local source=textSetting(sourceY,"",function(value)
        local ids={}
        if not value:match("^%s*$")then for token in value:gmatch("[^,]+")do
            local number=token:match("^%s*(%d+)%s*$")
            if not number or #number>20 then status.Text="ID источников через запятую.";return end
            ids[number]=true
        end end
        state.customSounds[id].sources=ids;return value
    end)
    source.Name="SoundSource_"..id
    controls[id]={source=sourceY,volume=volumeY,preset=presetButton}
end
local ownButton=button("Только мои события",8904,function()
    state.soundOwnOnly=not state.soundOwnOnly;if state.applyStyle then state.applyStyle()end
end)
state.uiOptions.soundOwnOnly={button=ownButton,text="Только мои события"}
state.refreshAudioUI=function()
    for id,c in pairs(controls)do
        c.preset.Text="Встроенный: "..(presets[state.customSounds[id].preset or "Ping"]or presets.Ping).name
        local ids={};for value in pairs(state.customSounds[id].sources)do ids[#ids+1]=value end;table.sort(ids)
        textControls[c.source].sync(table.concat(ids,","))
        numericControls[c.volume].set(state.customSounds[id].volume)
    end
end
state.refreshAudioUI()
end

-- Header brand and movable launcher. The header mark moves the menu itself.
do
floatingMenu.Name="SeterageLauncher"
floatingMenu.Size=UDim2.fromOffset(48,48)
floatingMenu.Text=""
local launcherOutline=Instance.new("UIStroke");launcherOutline.Thickness=1;launcherOutline.Transparency=.65;launcherOutline.Parent=floatingMenu
local launcherMark=Instance.new("TextLabel");launcherMark.Name="LauncherMark"
launcherMark.BackgroundTransparency=1;launcherMark.Size=UDim2.fromScale(1,1)
launcherMark.Text="SETE\nRAGE";launcherMark.TextColor3=Color3.new(1,1,1)
launcherMark.Font=Enum.Font.GothamBlack;launcherMark.TextSize=13;launcherMark.Rotation=-15
launcherMark.ZIndex=floatingMenu.ZIndex+1;launcherMark.Parent=floatingMenu
local badge=Instance.new("Frame");badge.Name="SeterageBrand"
badge.Position=UDim2.fromOffset(14,8);badge.Size=UDim2.fromOffset(28,28)
badge.BorderSizePixel=0;badge.Active=true;badge.Parent=panel
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=badge
local mark=Instance.new("TextLabel");mark.Name="BrandGlyph";mark.BackgroundTransparency=1
mark.Size=UDim2.fromScale(1,1);mark.Text="S";mark.Font=Enum.Font.GothamBlack;mark.TextSize=19;mark.Parent=badge
local outline=Instance.new("UIStroke");outline.Thickness=1;outline.Transparency=0.4;outline.Color=Color3.fromRGB(190,160,255);outline.Parent=badge
local badgeGradient=Instance.new("UIGradient");badgeGradient.Rotation=45;badgeGradient.Parent=badge
connect(badge.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragInput,dragStart,startPosition=input,input.Position,panel.Position
    end
end)
state.updateLogo=function()
    local accent=state.uiAccentColor
    badge.BackgroundColor3=accent
    badgeGradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(135,125,185))
    mark.TextColor3=Color3.fromRGB(255,255,255);mark.Font=Enum.Font.GothamBlack
    floatingMenu.BackgroundColor3=Color3.fromRGB(16,16,21)
    launcherOutline.Color=Color3.fromRGB(135,135,145)
    floatingMenu.Visible=not state.menuVisible
    title.Position=UDim2.fromOffset(54,8);title.Size=UDim2.new(1,-150,0,32)
    if state.applyHudPositions then state.applyHudPositions()end
end
end

-- Bear-trap skillchecks: independent zone profiles; never guess an unknown ring.
do
local names={"BearTrapSkillCheckGui","BearTrapGui","TrapSkillCheckPromptGui","BearTrapEscapeGui"}
local function trapped()
    local char=player.Character
    if not char then return false end
    return char:GetAttribute("InBearTrap")==true or char:GetAttribute("BearTrapped")==true or char:GetAttribute("Trapped")==true
end
local function dedicated()
    for _,name in ipairs(names)do
        local root=player.PlayerGui:FindFirstChild(name)
        local check=root and root:FindFirstChild("Check",true)
        if check and check:IsA("GuiObject")and visibleUI(check)then return check end
    end
end
local function visibleSharedTrap()
    local gui=player.PlayerGui:FindFirstChild("SkillCheckPromptGui");local check=gui and gui:FindFirstChild("Check")
    local trap=check and check:FindFirstChild("TrapGoal");local goal=check and check:FindFirstChild("Goal")
    return check and trap and visibleUI(trap)and(not goal or not visibleUI(goal))and check or nil
end
isTrapContext=function()return trapped()or dedicated()~=nil or visibleSharedTrap()~=nil end
local function getCheck()
    local check=dedicated()or visibleSharedTrap()
    if check then return check end
    if trapped()then
        local gui=player.PlayerGui:FindFirstChild("SkillCheckPromptGui")
        check=gui and gui:FindFirstChild("Check")
        if check and check:IsA("GuiObject")and visibleUI(check)then return check end
    end
end
local function range(check,goal,mode)
    local prefix=mode=="Normal"and "Normal"or "Perfect"
    for _,object in ipairs({goal,check})do
        local first=object:GetAttribute("Trap"..prefix.."StartOffset")or object:GetAttribute(prefix.."StartOffset")
        local last=object:GetAttribute("Trap"..prefix.."EndOffset")or object:GetAttribute(prefix.."EndOffset")
        if type(first)=="number"and type(last)=="number"then
            local width=(last-first)%360
            if width>0 and width<=180 then return first%360,last%360 end
        end
    end
    return skillRange(check,goal,mode)
end
state.trapTargetAllowed=function(check,goal,relative)
    local first,last=range(check,goal,state.trapMode)
    if not first then return false,"Bear trap: границы выбранной зоны недоступны."end
    if not angleInside(relative,first,last)then return false end
    if state.trapMode=="Normal"then
        local a,b=range(check,goal,"Perfect")
        if a and angleInside(relative,a,b)then return false end
    end
    return true
end
local used,panelSeen=false,nil
connect(RunService.RenderStepped,function()
    if not state.autoTrap or state.isDowned() or Input:GetFocusedTextBox()then return end
    local check=getCheck()
    if not check then used,panelSeen=false,nil;return end
    if panelSeen~=check then panelSeen,used=check,false end
    if used then return end
    local needle=check:FindFirstChild("Line")
    local trapGoal=check:FindFirstChild("TrapGoal")
    local goal=trapGoal and visibleUI(trapGoal)and trapGoal or check:FindFirstChild("Goal")
    if not needle or not goal or not needle:IsA("GuiObject")or not goal:IsA("GuiObject")then return end
    local ok,reason=state.trapTargetAllowed(check,goal,(needle.Rotation-goal.Rotation)%360)
    if not ok then if reason then status.Text=reason end;return end
    used=true
    local sent=pcall(sendSkillInput)
    status.Text=sent and "Bear trap: нажатие отправлено."or "Bear trap: ввод недоступен."
end)
toggle("autoTrap","Авто bear trap",7400)
local mode=state.dropdown(7442,"Режим ловушки",function()return {{value="Normal",label="Normal"},{value="Perfect",label="Perfect"}}end,
    function()return state.trapMode end,function(value)state.trapMode=value end,"trapMode")
label("Normal / Perfect: нажатие при входе в выбранную зону.",7484,34)
state.refreshTrapUI=function()mode:refresh()end
end

-- Two independent moonwalk shortcuts; normal speed is left to the game.
do
local saved=setmetatable({},{__mode="k"})
local emoteTrack,emoteAnimation
local function stopMovement()
    for hum,autoRotate in pairs(saved)do
        pcall(function()hum.AutoRotate=autoRotate;hum:Move(Vector3.new(0,0,0),false)end)
        saved[hum]=nil
    end
end
local function stopEmote()
    local track=emoteTrack;emoteTrack=nil
    if track then pcall(function()track:Stop(0.1);track:Destroy()end)end
    if emoteAnimation then emoteAnimation:Destroy();emoteAnimation=nil end
end
resetAvatar=function()stopMovement();stopEmote()end
state.setMoonwalk=function(direction)
    state.moonForward=direction=="forward";state.moonBackward=direction=="backward"
    if not direction then stopMovement()end
    paintToggle("moonForward");paintToggle("moonBackward")
    if state.applyStyle then state.applyStyle()end
end
for _,entry in ipairs({{"moonForward","Moonwalk вперёд",9010,"forward"},{"moonBackward","Moonwalk назад",9052,"backward"}})do
    local field,text,y,direction=entry[1],entry[2],entry[3],entry[4]
    local b=button(text,y,function()if state[field]then state.setMoonwalk(nil)else state.setMoonwalk(direction)end end)
    toggleButtons[field]={button=b,text=text}
end
local forwardBind,backwardBind
local function beginCapture(which)
    waitingBind=false;state.capturingBind=nil;refreshExtensions()
    bindButton.Text="Бинд авто парирования: "..bindLabel(state.parryBind)
    state.capturingBind=which
    state.refreshAvatarUI()
end
forwardBind=button("Бинд вперёд: не назначен",9094,function()beginCapture("moonForward")end)
backwardBind=button("Бинд назад: не назначен",9136,function()beginCapture("moonBackward")end)
label("Повторное нажатие выключает. Направления не работают вместе.",9178,34)
connect(Input.InputBegan,function(input,processed)
    if Input:GetFocusedTextBox()then return end
    local capture=state.capturingBind
    if capture=="moonForward"or capture=="moonBackward"then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local key=input.KeyCode
        local other=capture=="moonForward"and state.moonBackwardBind or state.moonForwardBind
        if key==Enum.KeyCode.Escape then state.capturingBind=nil
        elseif key==Enum.KeyCode.Backspace then state[capture.."Bind"]=Enum.KeyCode.Unknown;state.capturingBind=nil
        elseif key~=Enum.KeyCode.Unknown and key~=Enum.KeyCode.Space and key~=Enum.KeyCode.LeftShift and key~=state.emoteBind and key~=state.selfHealBind and key~=state.menuBind and key~=state.parryBind
            and key~=state.hiddenBind and key~=other and key.Name~=state.parryInput then
            state[capture.."Bind"]=key;state.capturingBind=nil
        else status.Text="Клавиша уже занята."end
        state.refreshAvatarUI();return
    end
    if capture or processed then return end
    if state.moonForwardBind~=Enum.KeyCode.Unknown and input.KeyCode==state.moonForwardBind then
        if state.moonForward then state.setMoonwalk(nil)else state.setMoonwalk("forward")end
    elseif state.moonBackwardBind~=Enum.KeyCode.Unknown and input.KeyCode==state.moonBackwardBind then
        if state.moonBackward then state.setMoonwalk(nil)else state.setMoonwalk("backward")end
    end
end)
connect(RunService.Heartbeat,function()
    if not state.moonForward and not state.moonBackward then stopMovement();return end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not hum or not root or not cam or hum.Health<=0 or char:GetAttribute("Downed")==true
        or Input:GetFocusedTextBox()or state.capturingBind or isKiller(player)
        or state.isDowned(char)or char:GetAttribute("Vaulting")==true or char:GetAttribute("IsVaulting")==true then stopMovement();return end
    local currentAnimator=hum:FindFirstChildOfClass("Animator")
    if currentAnimator then for _,track in ipairs(currentAnimator:GetPlayingAnimationTracks())do
        local animation=track.Animation
        local id=animation and tostring(animation.AnimationId):match("%d+")
        local name=animation and(tostring(animation.Name).." "..tostring(track.Name)):lower()or ""
        if track.IsPlaying and(name:find("vault",1,true)or id=="83873880822918"or id=="136962284480779")then stopMovement();return end
    end end
    for old,value in pairs(saved)do if old~=hum then pcall(function()old.AutoRotate=value end);saved[old]=nil end end
    if saved[hum]==nil then saved[hum]=hum.AutoRotate end
    local look=cam.CFrame.LookVector
    local flat=Vector3.new(look.X,0,look.Z)
    if flat.Magnitude<0.001 then return end
    local direction=flat/flat.Magnitude*(state.moonForward and 1 or -1)
    hum.AutoRotate=false;hum:Move(direction,false)
    local sway=math.rad(math.sin(os.clock()*30)*35)
    local facing=direction*-1
    local rotated=Vector3.new(facing.X*math.cos(sway)-facing.Z*math.sin(sway),0,facing.X*math.sin(sway)+facing.Z*math.cos(sway))
    root.CFrame=CFrame.lookAt(root.Position,root.Position+rotated)
end)
-- VD catalog names + live client assets. Native handler owns original sound/timing.
-- Catalog reference: https://violencedistrictwiki.com/wiki/emotes/ (2026-09-25).
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local catalog={"The Dab","Backflip","Rampage","Source","24 Hour Cinderella","Wave","Applause","Schadenfreude",
    "CaliforniaGirls","Kyoufuu","Rambunctious","Floating Rest","Static","Arm Swing","Griddy","Mannrobics",
    "Tor Monitor Ketua","Quick Combo","Ghoul","Thriller","Christmas Spirit"}
local liveEmotes={}
local emoteSounds={}
local emoteCharacter
local emoteInfo=label("Оригинальный звук запускает игра. Доступ проверяет сервер.",9568,44)
emoteInfo.Name="EmoteInfo"
local function normalize(name)return tostring(name):lower():gsub("[^%w]","")end
local lastEmoteScan=-math.huge
local function scanEmotes()
    liveEmotes={};lastEmoteScan=os.clock()
    local canonical={};for _,name in ipairs(catalog)do canonical[normalize(name)]=name end
    local generic={animation=true,anim=true,animations=true,r6=true,r15=true,loop=true,main=true,intro=true}
    local emoteFolder=ReplicatedStorage:FindFirstChild("Emotes")
    if emoteFolder then for _,item in ipairs(emoteFolder:GetChildren())do
        local asset=item:GetAttribute("animationid")
        local id=asset and tostring(asset):match("%d+")
        if id and id~="0"then
            liveEmotes[normalize(item.Name)]={name=item.Name,asset=id,container=item,rigs={}}
        end
    end end
    for _,item in ipairs(ReplicatedStorage:GetDescendants())do
        if item:IsA("Animation")then
            local node=item.Parent;local root;local rig
            while node and node~=ReplicatedStorage do
                local name=normalize(node.Name)
                if name=="r6"or name=="r15"then rig=name:upper()end
                if node.Name:lower():find("emote",1,true)then root=node;break end
                node=node.Parent
            end
            if root then
                local name=item:GetAttribute("EmoteName");local container=item.Parent
                if type(name)~="string"or name==""then
                    node=item
                    while node and node~=root do
                        local key=normalize(node.Name)
                        if canonical[key]then name=canonical[key];container=node:IsA("Animation")and node.Parent or node;break end
                        if not generic[key]and(type(name)~="string"or name=="")then name=node.Name;container=node:IsA("Animation")and node.Parent or node end
                        node=node.Parent
                    end
                end
                if type(name)=="string"and #name>0 and #name<=100 then
                    if container==root then container=item end
                    local key=normalize(name);local record=liveEmotes[key]
                    if not record then record={name=name,animation=item,container=container,rigs={}};liveEmotes[key]=record
                    elseif not record.animation then record.animation=item end
                    if rig then record.rigs[rig]=item end
                end
            end
        end
    end
end
local function nativeRemote()
    local remotes=ReplicatedStorage:FindFirstChild("Remotes")
    local remote=remotes and remotes:FindFirstChild("EmoteHandler")
    if not remote then remote=ReplicatedStorage:FindFirstChild("EmoteHandler",true)end
    return remote and remote:IsA("RemoteEvent")and remote or nil
end
local requestSerial=0
local emoteObserver
state.emoteDiagnostics=function()
    local result={selected=state.emoteName,last=state.emoteLast,assets={}}
    local remote=nativeRemote()
    if remote then
        local names={};local node=remote
        while node and node~=ReplicatedStorage do table.insert(names,1,node.Name);node=node.Parent end
        result.remote=table.concat(names,"/")
    else result.remote="not found"end
    local count=0
    for _,record in pairs(liveEmotes)do
        count=count+1;if count>40 then break end
        result.assets[#result.assets+1]={name=record.name,asset=record.animation and record.animation.AnimationId or record.asset,
            r6=record.rigs.R6 and record.rigs.R6.AnimationId,r15=record.rigs.R15 and record.rigs.R15.AnimationId}
    end
    return result
end
local oldStopEmote=stopEmote
stopEmote=function()
    requestSerial=requestSerial+1
    if emoteObserver then emoteObserver:Disconnect();emoteObserver=nil end
    oldStopEmote();emoteCharacter=nil
    for _,sound in ipairs(emoteSounds)do pcall(function()sound:Stop();sound:Destroy()end)end
    emoteSounds={}
end
resetAvatar=function()stopMovement();stopEmote()end
state.playSelectedEmote=function(forceLocal)
    if not state.alive or Input:GetFocusedTextBox()then return false end
    stopEmote()
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local animator=hum and hum:FindFirstChildOfClass("Animator")
    if not hum or hum.Health<=0 then status.Text="Персонаж ещё не готов.";return false end
    if state.isDowned(char)then status.Text="В нокдауне доступно только движение.";return false end
    if os.clock()-lastEmoteScan>2 then scanEmotes()end
    local record=liveEmotes[normalize(state.emoteName)]
    local source=record and(record.rigs[hum.RigType==Enum.HumanoidRigType.R6 and "R6"or "R15"]or record.animation)
    local id=state.emoteName=="Custom ID"and state.emoteId or(source and tostring(source.AnimationId):match("%d+"))or(record and record.asset)
    if state.emoteName~="Custom ID"and forceLocal~=true then
        local remote=nativeRemote()
        if remote then
            local serial=requestSerial;local selected=state.emoteName
            state.emoteLast={name=selected,transport="native",status="request sent, not confirmed"}
            local confirmed=false;local observer
            if animator then observer=animator.AnimationPlayed:Connect(function(track)
                local animation=track.Animation
                if animation and((id and tostring(animation.AnimationId):match("%d+")==id)
                    or normalize(animation.Name)==normalize(selected)or normalize(track.Name)==normalize(selected))then
                    confirmed=true
                    if state.emoteLast and state.emoteLast.name==selected then state.emoteLast.status="matching animation observed";if state.alive then status.Text="Эмоция: анимация подтверждена."end end
                end
            end)end
            emoteObserver=observer
            local ok=pcall(function()remote:FireServer(record and record.name or selected)end)
            status.Text=ok and "Запрос эмоции отправлен; ожидание подтверждения."or "Игровой обработчик отклонил вызов."
            task.delay(2,function()
                if observer then observer:Disconnect();if emoteObserver==observer then emoteObserver=nil end end
                if not state.alive or serial~=requestSerial or selected~=state.emoteName or confirmed then return end
                if id then
                    state.playSelectedEmote(true)
                elseif state.emoteLast then
                    state.emoteLast.status=ok and "no matching animation; no local asset"or "remote error"
                    status.Text="Эмоция не подтверждена игрой; локальный ассет отсутствует."
                end
            end)
            return ok
        end
    end
    if not animator then status.Text="Animator недоступен.";return false end
    if not id then status.Text="Нет игрового EmoteHandler и доступного ассета этой эмоции.";return false end
    local animation=Instance.new("Animation");animation.AnimationId="rbxassetid://"..id
    local ok,track=pcall(function()return animator:LoadAnimation(animation)end)
    if not ok or not track then animation:Destroy();status.Text="Roblox не разрешил эту анимацию.";return false end
    state.emoteLast={name=state.emoteName,transport="local asset",status="loading",asset=id}
    emoteAnimation,emoteTrack=animation,track;emoteCharacter=char
    track.Priority=Enum.AnimationPriority.Action;track.Looped=state.emoteLoop
    local played=pcall(function()track:Play(0.1)end)
    if not played then stopEmote();status.Text="Не удалось запустить эмоцию.";return false end
    -- Use the soundtrack published with the selected emote.
    local hasSong=false
    if record and record.container then
        local song=record.container:GetAttribute("Song")
        local songId=song and tostring(song):match("%d+")
        if songId and songId~="0"then
            hasSong=true
            local sound=Instance.new("Sound");sound.Name="SeterageEmoteSound"
            sound.SoundId="rbxassetid://"..songId;sound.Volume=1;sound.Looped=state.emoteLoop
            sound.Parent=char:FindFirstChild("HumanoidRootPart")or char
            emoteSounds[#emoteSounds+1]=sound
            local offset=record.container:GetAttribute("SongStart")
            local function startSong()
                if not state.alive or emoteTrack~=track or not track.IsPlaying or not sound.Parent then return end
                pcall(function()
                    if type(offset)=="number"and offset>0 then sound.TimePosition=offset end
                    sound:Play()
                end)
            end
            if sound.IsLoaded then startSong()else
                local connection
                connection=sound.Loaded:Connect(function()connection:Disconnect();startSong()end)
            end
        end
    end
    if record and record.container and not hasSong then for _,source in ipairs(record.container:GetDescendants())do
        if source:IsA("Sound")then
            local sound=Instance.new("Sound");sound.Name="SeterageEmoteSound"
            sound.SoundId=source.SoundId;sound.Volume=source.Volume;sound.PlaybackSpeed=source.PlaybackSpeed
            sound.Looped=source.Looped;sound.Parent=char:FindFirstChild("HumanoidRootPart")or char
            emoteSounds[#emoteSounds+1]=sound
            local delay=source:GetAttribute("StartDelay");delay=type(delay)=="number"and math.clamp(delay,0,60)or 0
            task.delay(delay,function()if state.alive and emoteTrack==track and track.IsPlaying and sound.Parent then pcall(function()sound:Play()end)end end)
        end
    end end
    pcall(function()connect(track.Stopped,function()if emoteTrack==track then stopEmote()end end)end)
    state.emoteLast.status="local playback requested"
    status.Text="Локальная эмоция запущена; другим игрокам не гарантируется."
    task.delay(5,function()
        if state.alive and emoteTrack==track and track.Length==0 then stopEmote();status.Text="Roblox не загрузил эту анимацию."
            if state.emoteLast then state.emoteLast.status="asset loading rejected or timed out"end
        end
    end)
    return true
end
scanEmotes()
local emoteChoice=state.dropdown(9330,"Эмоция",function()
    local result,seen={},{}
    local function add(name,label)
        local key=normalize(name);if seen[key]then return end;seen[key]=true
        result[#result+1]={value=name,label=label or name}
    end
    for _,name in ipairs(catalog)do local live=liveEmotes[normalize(name)];add(live and live.name or name)end
    for _,record in pairs(liveEmotes)do add(record.name)end
    table.sort(result,function(a,b)return a.label:lower()<b.label:lower()end)
    add("Custom ID","По ID · локально")
    if not seen[normalize(state.emoteName)]then add(state.emoteName,state.emoteName.." · нет в каталоге")end
    return result
end,function()return state.emoteName end,function(value)stopEmote();state.emoteName=value;state.refreshAvatarUI()end,"emotes")
label("ID своей анимации — необязательно",9372,24)
local emoteBox=textSetting(9400,state.emoteId,function(value)
    local id=value:match("^%s*(%d+)%s*$")or value:match("^%s*rbxassetid://(%d+)%s*$")
    if not id or #id>20 then status.Text="Нужен ID анимации.";return end
    state.emoteId=id;state.emoteName="Custom ID";state.refreshAvatarUI();return id
end)
emoteBox.Name="EmoteAsset"
button("Проиграть эмоцию",9442,state.playSelectedEmote)
button("Проиграть локально",9443,function()state.playSelectedEmote(true)end)
button("Остановить локальную эмоцию",9484,function()stopEmote();status.Text="Игровую эмоцию останови штатно движением."end)
local loopButton=button("Повтор локальной эмоции",9526,function()
    state.emoteLoop=not state.emoteLoop;if emoteTrack then emoteTrack.Looped=state.emoteLoop end
    if state.applyStyle then state.applyStyle()end
end)
state.uiOptions.emoteLoop={button=loopButton,text="Повтор локальной эмоции"}
local emoteBindButton=button("Бинд эмоции: не назначен",9610,function()beginCapture("emote")end)
button("Обновить список эмоций",9652,function()scanEmotes();emoteChoice:refresh();status.Text="Каталог VD дополнен ассетами клиента."end)
state.refreshAvatarUI=function()
    forwardBind.Text=state.capturingBind=="moonForward"and "Нажми клавишу · Backspace убрать"or "Бинд вперёд: "..bindLabel(state.moonForwardBind)
    backwardBind.Text=state.capturingBind=="moonBackward"and "Нажми клавишу · Backspace убрать"or "Бинд назад: "..bindLabel(state.moonBackwardBind)
    emoteBindButton.Text=state.capturingBind=="emote"and "Нажми клавишу · Backspace убрать"or "Бинд эмоции: "..bindLabel(state.emoteBind)
    emoteChoice:refresh();textControls[9400].sync(state.emoteId)
end
connect(Input.InputBegan,function(input,processed)
    if Input:GetFocusedTextBox()then return end
    if state.capturingBind=="emote"then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local code=input.KeyCode
        if code==Enum.KeyCode.Escape then state.capturingBind=nil
        elseif code==Enum.KeyCode.Backspace then state.emoteBind=Enum.KeyCode.Unknown;state.capturingBind=nil
        elseif code~=Enum.KeyCode.Unknown and code~=Enum.KeyCode.Space and code~=Enum.KeyCode.LeftShift
            and code~=state.menuBind and code~=state.parryBind and code~=state.hiddenBind and code~=state.selfHealBind
            and code~=state.moonForwardBind and code~=state.moonBackwardBind and code.Name~=state.parryInput then
            state.emoteBind=code;state.capturingBind=nil
        else status.Text="Клавиша занята."end
        state.refreshAvatarUI();return
    end
    if not processed and not state.capturingBind and not state.dropdownOpen and state.emoteBind~=Enum.KeyCode.Unknown and input.KeyCode==state.emoteBind then state.playSelectedEmote()end
end)
state.refreshAvatarUI()
connect(RunService.Heartbeat,function()
    if not emoteTrack then return end
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if player.Character~=emoteCharacter or not hum or hum.Health<=0 then stopEmote()end
end)

end

-- Local world styling, user background and conservative vault animation adapter.
do
local Lighting=game:GetService("Lighting")
local shaderPresets={
 Soft={name="Мягкий",contrast=.08,saturation=.08,brightness=.01,tint={244,247,255},bloom=.12},
 Cinema={name="Кино",contrast=.18,saturation=-.12,brightness=-.01,tint={235,240,255},bloom=.18},
 Cold={name="Холодный",contrast=.1,saturation=-.08,brightness=.01,tint={215,235,255},bloom=.1},
 Warm={name="Тёплый",contrast=.07,saturation=.12,brightness=.02,tint={255,235,210},bloom=.14},
 Noir={name="Чёрно-белый",contrast=.2,saturation=-1,brightness=.02,tint={255,255,255},bloom=.05},
 Vibrant={name="Насыщенный",contrast=.12,saturation=.32,brightness=.01,tint={255,248,248},bloom=.16},
 Night={name="Ночной",contrast=.05,saturation=-.18,brightness=.14,tint={215,230,255},bloom=.04},
 Clear={name="Чёткий",contrast=.1,saturation=.02,brightness=.035,tint={255,255,255},bloom=0},
}
local shaderChoice,appliedShader,displayedShader
local effects,tracks={},setmetatable({},{__mode="k"})
local animator,animationConnection
local background=Instance.new("ImageLabel");background.Name="MenuBackground";background.BackgroundTransparency=1
background.Size=UDim2.fromScale(1,1);background.ScaleType=Enum.ScaleType.Crop;background.ImageTransparency=0.72
background.ZIndex=0;background.Visible=false;background.Parent=panel;panel.ZIndex=0
local rounding=Instance.new("UICorner");rounding.CornerRadius=UDim.new(0,10);rounding.Parent=background
local backgroundBox
local appliedImage,loadedImage="",nil
local vaultIds={['83873880822918']=true,['136962284480779']=true}
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local animationQueue,animationHead,animationTail={},1,0
local animationExpanded=setmetatable({},{__mode="k"})
local function rememberVaultAnimation(item)
    if item:IsA("Animation")and item.Name:lower():find("vault",1,true)then
        local id=tostring(item.AnimationId):match("%d+");if id then vaultIds[id]=true end
    end
end
pcall(function()connect(ReplicatedStorage.DescendantAdded,rememberVaultAnimation)end)
local function collectVaultIds()
    if not animationExpanded[ReplicatedStorage]then
        animationExpanded[ReplicatedStorage]=true
        animationTail=animationTail+1;animationQueue[animationTail]=ReplicatedStorage
    end
    local count=0
    while animationHead<=animationTail and count<48 do
        local item=animationQueue[animationHead];animationQueue[animationHead]=nil;animationHead=animationHead+1;count=count+1
        rememberVaultAnimation(item)
        for _,child in ipairs(item:GetChildren())do if not animationExpanded[child]then
            animationExpanded[child]=true;animationTail=animationTail+1;animationQueue[animationTail]=child
        end end
    end
    if animationHead>animationTail then animationQueue,animationHead,animationTail={},1,0 end
end
local ownsVaultShift=false
local vaultTargetDuration=.48 -- experimental target duration
local vaultTargetSpeed=1.4166667/vaultTargetDuration -- observed walking animation length / target
local vaultMotion=nil
local finesseTrack=nil
local vaultSpeedEntry=nil
local function restoreVaultSpeed()
    local entry=vaultSpeedEntry;vaultSpeedEntry=nil
    if entry and entry.char.Parent then pcall(function()
        if entry.char:GetAttribute("vaultspeed")==entry.applied then entry.char:SetAttribute("vaultspeed",entry.original)end
    end)end
end
state.updateVaultSpeed=function()
    local char=player.Character
    if not state.alive or not state.vaultSpeedEnabled or not char then restoreVaultSpeed();return end
    if vaultSpeedEntry and vaultSpeedEntry.char~=char then restoreVaultSpeed()end
    if not vaultSpeedEntry then vaultSpeedEntry={char=char,original=char:GetAttribute("vaultspeed")}end
    local value=state.vaultSpeedValue
    if vaultSpeedEntry.applied==value then return end
    local ok=pcall(function()char:SetAttribute("vaultspeed",value)end)
    if ok then vaultSpeedEntry.applied=value end
end
local vaultSpeedElapsed=0
connect(RunService.Heartbeat,function(dt)
    vaultSpeedElapsed=vaultSpeedElapsed+dt;if vaultSpeedElapsed<.2 then return end;vaultSpeedElapsed=0
    state.updateVaultSpeed()
end)
local vaultFlow=nil
local function restoreVaultFlow()
    local entry=vaultFlow;vaultFlow=nil
    if not entry then return end
    if entry.connection then entry.connection:Disconnect()end
    if not entry.changed and entry.char.Parent and entry.char:GetAttribute("Flowstate")==true then
        pcall(function()entry.writing=true;entry.char:SetAttribute("Flowstate",entry.original);entry.writing=false end)
    end
end
local function prepareVaultFlow(char)
    if vaultFlow and vaultFlow.char~=char then restoreVaultFlow()end
    if vaultFlow then return end
    local value=char:GetAttribute("Flowstate")
    if value==true or(value~=nil and type(value)~="boolean")then return end
    local entry={char=char,original=value,writing=true,changed=false}
    local ok=pcall(function()entry.connection=char:GetAttributeChangedSignal("Flowstate"):Connect(function()
        if not entry.writing and char:GetAttribute("Flowstate")~=true then entry.changed=true end
    end)end)
    if not ok then return end
    vaultFlow=entry
    local applied=pcall(function()char:SetAttribute("Flowstate",true)end)
    entry.writing=false
    if not applied then restoreVaultFlow()end
end
local windowParts={}
local vaultHistory={}
state.vaultRuntime={history=vaultHistory}
local vaultEvaluator=nil
local function restoreVaultEvaluator()
    local entry=vaultEvaluator;vaultEvaluator=nil
    if entry then pcall(function()if entry.module.evaluate==entry.wrapper then entry.module.evaluate=entry.original end end)end
end
local function installVaultEvaluator()
    if vaultEvaluator then return end
    local ok,module=pcall(function()
        return require(game:GetService("ReplicatedStorage").Modules.Survivors.SurvivorVault)
    end)
    if not ok or type(module)~="table"or type(module.evaluate)~="function"then
        state.vaultRuntime.evaluator={installed=false,error="module unavailable"};return
    end
    local original=module.evaluate
    local wrapper=function(samples,context)
        if state.alive and state.fastVault and state.vaultNearWindow and not state.isDowned()
            and not isKiller(player)and type(context)=="table"and context.blocked==false then
            state.vaultRuntime.evaluator.triggered=true
            return true,"ready"
        end
        return original(samples,context)
    end
    local installed,err=pcall(function()module.evaluate=wrapper end)
    state.vaultRuntime.evaluator={installed=installed,error=not installed and tostring(err)or nil}
    if installed then vaultEvaluator={module=module,original=original,wrapper=wrapper}end
end
local function vaultStatus(reason,distance,count)
    local runtime=state.vaultRuntime
    runtime.reason=reason;runtime.nearestStuds=distance;runtime.windows=count
    runtime.nearWindow=state.vaultNearWindow;runtime.mobileRequested=state.vaultSprint
    runtime.touch=Input.TouchEnabled;runtime.keyboard=Input.KeyboardEnabled
    if runtime.lastRecorded~=reason then
        runtime.lastRecorded=reason
        vaultHistory[#vaultHistory+1]={t=os.clock(),reason=reason,nearestStuds=distance,windows=count}
        if #vaultHistory>30 then table.remove(vaultHistory,1)end
    end
end
local function restoreVaultShift()
    state.vaultSprint=false;state.vaultNearWindow=false
    if ownsVaultShift then pcall(function()virtualInput:SendKeyEvent(false,Enum.KeyCode.LeftShift,false,game)end);ownsVaultShift=false end
end
local function prepareVault()
    state.vaultNearWindow=false;state.vaultSprint=false
    if not state.fastVault then restoreVaultEvaluator();restoreVaultFlow();return end
    installVaultEvaluator()
    if state.isDowned()or Input:GetFocusedTextBox()or state.capturingBind then restoreVaultFlow();vaultStatus("blocked by state or menu",nil,0);return end
    local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root or root.Anchored then restoreVaultFlow();vaultStatus("missing or anchored character",nil,0);return end
    local action=char:GetAttribute("ActionState")
    if type(action)=="string"and action~=""and not action:lower():find("vault",1,true)then restoreVaultFlow();vaultStatus("other action: "..action,nil,0);return end
    local nearest,count=nil,0
    for _,part in ipairs(state.getWindowAnchors and state.getWindowAnchors()or {})do
        if part.Parent then
            local distance=(part.Position-root.Position).Magnitude;count=count+1
            if not nearest or distance<nearest then nearest=distance end
        end
    end
    if nearest and nearest<=10 then
            state.vaultNearWindow=true
            state.vaultSprint=Input.TouchEnabled and not Input.KeyboardEnabled
            prepareVaultFlow(char)
            vaultStatus("near window",nearest,count);return
    end
    restoreVaultFlow();vaultStatus(count==0 and "no indexed windows"or "window out of range",nearest,count)
end
local function restoreVault()
    restoreVaultEvaluator()
    if finesseTrack then pcall(function()finesseTrack:Stop();finesseTrack:Destroy()end);finesseTrack=nil end
    restoreVaultFlow()
    vaultMotion=nil
    state.restoreGameRate("vault")
    restoreVaultShift()
    for track,speed in pairs(tracks)do
        pcall(function()if track.IsPlaying and math.abs(track.Speed-vaultTargetSpeed)<.001 then track:AdjustSpeed(speed)end end)
        tracks[track]=nil
    end
    if animationConnection then animationConnection:Disconnect();animationConnection=nil end
    animator=nil
end
local function resetShaders()
    for _,effect in ipairs(effects)do pcall(function()effect:Destroy()end)end;effects={};appliedShader=nil
end
state.resetPresentation=function()restoreVault();restoreVaultSpeed();resetShaders()end
local function vault(track)
    local animation=track.Animation
    local id=animation and tostring(animation.AnimationId):match("%d+")
    if id=="126081405469607"then
        state.vaultRuntime.check={fastVault=state.fastVault,downed=state.isDowned(),killer=isKiller(player),playing=track.IsPlaying,speed=track.Speed,tracked=tracks[track]~=nil}
    end
    if not state.fastVault or state.isDowned()or isKiller(player)then return end
    -- Only the exact walking-vault animation observed in the user's report.
    if id~="126081405469607"or not track.IsPlaying or tracks[track]then return end
    local speed=track.Speed
    if type(speed)~="number"or speed<=0 then return end
    local ok=pcall(function()if speed<vaultTargetSpeed then track:AdjustSpeed(vaultTargetSpeed)end end)
    state.vaultRuntime.lastAnimation={asset=id,originalSpeed=speed,requestedSpeed=vaultTargetSpeed,targetDuration=vaultTargetDuration,accepted=ok}
    if ok then
        tracks[track]=speed
        local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
        if animator then
            if finesseTrack then pcall(function()finesseTrack:Stop();finesseTrack:Destroy()end);finesseTrack=nil end
            local animationObject=Instance.new("Animation")
            animationObject.AnimationId="rbxassetid://136962284480779"
            local loaded,result=pcall(function()return animator:LoadAnimation(animationObject)end)
            animationObject:Destroy()
            if loaded and result then
                finesseTrack=result
                local started,err=pcall(function()
                    result.Priority=Enum.AnimationPriority.Action4
                    result:Play(0)
                end)
                state.vaultRuntime.finesse={loaded=true,started=started,error=not started and tostring(err)or nil}
                if started then
                    task.spawn(function()
                        local deadline=os.clock()+1
                        while result.Length<=0 and result.IsPlaying and os.clock()<deadline do task.wait()end
                        if result.IsPlaying and result.Length>0 then
                            pcall(function()result:AdjustSpeed(result.Length/vaultTargetDuration)end)
                            state.vaultRuntime.finesse.length=result.Length
                        end
                    end)
                    task.delay(vaultTargetDuration,function()pcall(function()result:Stop(0)end)end)
                end
            else
                state.vaultRuntime.finesse={loaded=false,error=tostring(result)}
            end
        end
        if root and not root.Anchored and state.vaultNearWindow then
            local look=root.CFrame.LookVector;local direction=Vector3.new(look.X,0,look.Z)
            if direction.Magnitude>.1 then
                vaultMotion={track=track,root=root,char=char,direction=direction/direction.Magnitude,start=os.clock()}
                state.vaultRuntime.motion={targetSpeed=14,duration=vaultTargetDuration,started=true}
            end
        end
    end
end
connect(RunService.Heartbeat,function()
    local m=vaultMotion;if not m then return end
    local root=m.root
    if not state.alive or not state.fastVault or player.Character~=m.char or state.isDowned(m.char)
        or not root.Parent or root.Anchored or not m.track.IsPlaying or os.clock()-m.start>=vaultTargetDuration then
        vaultMotion=nil;return
    end
    local ok=pcall(function()
        local current=root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity=Vector3.new(m.direction.X*14,current.Y,m.direction.Z*14)
    end)
    if not ok then vaultMotion=nil;state.vaultRuntime.motion.error="velocity unavailable"end
end)
local function updateVault()
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    state.vaultRuntime.update={alive=state.alive,fastVault=state.fastVault,killer=isKiller(player),downed=state.isDowned(),humanoid=hum~=nil,health=hum and hum.Health}
    if not state.fastVault or isKiller(player)or state.isDowned()or not hum or hum.Health<=0 then restoreVault();return end
    local current=hum:FindFirstChildOfClass("Animator")
    if current~=animator then
        restoreVault();animator=current
        if animator then animationConnection=animator.AnimationPlayed:Connect(function(track)
            state.recentAnimations=state.recentAnimations or {}
            local animation=track.Animation
            table.insert(state.recentAnimations,1,{name=tostring(track.Name),asset=animation and tostring(animation.AnimationId)or "",source=animation and tostring(animation.Name)or ""})
            while #state.recentAnimations>12 do table.remove(state.recentAnimations)end
            vault(track)
        end)end
    end
    state.restoreGameRate("vault",char)
    if not animator then return end
    for track in pairs(tracks)do if not track.IsPlaying then tracks[track]=nil end end
    for _,track in ipairs(animator:GetPlayingAnimationTracks())do vault(track)end
end
state.refreshPresentation=function()
    if state.shaders and appliedShader~=state.shaderPreset then resetShaders()end
    if shaderChoice and displayedShader~=state.shaderPreset then shaderChoice:refresh();displayedShader=state.shaderPreset end
    if not state.shaders then if #effects>0 then resetShaders()end
    elseif #effects==0 then
        local preset=shaderPresets[state.shaderPreset]or shaderPresets.Soft
        local ok=pcall(function()
            local tone=Instance.new("ColorCorrectionEffect");effects[#effects+1]=tone
            tone.Name="SeterageTone";tone.Contrast=preset.contrast;tone.Saturation=preset.saturation;tone.Brightness=preset.brightness
            tone.TintColor=Color3.fromRGB(preset.tint[1],preset.tint[2],preset.tint[3]);tone.Parent=Lighting
            local bloom=Instance.new("BloomEffect");effects[#effects+1]=bloom
            bloom.Name="SeterageBloom";bloom.Intensity=preset.bloom;bloom.Size=18;bloom.Threshold=1.6;bloom.Parent=Lighting
        end)
        if not ok then resetShaders();status.Text="Шейдеры недоступны в этом клиенте."else appliedShader=state.shaderPreset end
    end
    if appliedImage~=state.backgroundImage then
        appliedImage=state.backgroundImage;loadedImage=nil
        if appliedImage:match("^%d+$")then loadedImage="rbxassetid://"..appliedImage
        elseif appliedImage:match("^rbxassetid://%d+$")then loadedImage=appliedImage
        elseif appliedImage:sub(1,6)=="local:"then
            -- Explicit user-supplied image file only; no directory scans or downloads.
            local asset=type(getcustomasset)=="function"and getcustomasset or nil
            local relative=appliedImage:sub(7)
            if relative:find("..",1,true)or relative:sub(1,1)=="/"then status.Text="Фон: укажи относительный путь без .."
            elseif asset then local ok,result=pcall(asset,relative);if ok and type(result)=="string"then loadedImage=result else status.Text="Локальная картинка недоступна."end
            else status.Text="Клиент не поддерживает локальный фон. Используй ID картинки Roblox."end
        end
        background.Image=loadedImage or ""
    end
    background.Visible=state.backgroundEnabled and loadedImage~=nil
    if backgroundBox and backgroundBox.Text~=state.backgroundImage and Input:GetFocusedTextBox()~=backgroundBox then
        textControls[5860].sync(state.backgroundImage)
    end
    if not state.fastVault then restoreVault()end
end
toggle("shaders","Шейдеры",4550)
shaderChoice=state.dropdown(4552,"Пресет",function()
    local list={};for _,id in ipairs({"Soft","Cinema","Cold","Warm","Noir","Vibrant","Night","Clear"})do list[#list+1]={value=id,label=shaderPresets[id].name}end;return list
end,function()return state.shaderPreset end,function(value)state.shaderPreset=value;state.refreshPresentation()end,"shaders")
label("Локальные цветокоррекция и мягкое свечение.",4592,28)
toggle("backgroundEnabled","Своя картинка в меню",5776)
label("ID картинки Roblox или local:images/menu.png",5818,28)
backgroundBox=textSetting(5860,"",function(text)
    local value=text:match("^%s*(.-)%s*$")
    if #value>240 or(value~=""and not value:match("^%d+$")and not value:match("^rbxassetid://%d+$")and not value:match("^local:[%w _%./%-]+$"))then status.Text="Фон: ID картинки или local:путь.png";return end
    if value:sub(1,6)=="local:"and(value:find("..",7,true)or value:sub(7,7)=="/")then status.Text="Нужен относительный путь без ..";return end
    state.backgroundImage=value;state.refreshPresentation();return value
end)
backgroundBox.Name="BackgroundImage"
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<0.1 then return end;elapsed=0
    if state.fastVault then collectVaultIds()end
    updateVault();prepareVault();state.refreshPresentation()
end)
end

-- No RNG prediction: display a next-round announcement only if the game publishes it.
do
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local text=label("Следующий раунд: нет опубликованных данных.",4676,60)
text.Name="NextRoundInfo"
toggle("nextRound","Объявленные киллер / карта",4634)
toggle("showNextHud","Следующий раунд на экране",4635)
toggle("nextRoundMap","Следующая карта на экране",4636)
toggle("nextRoundKiller","Следующий киллер на экране",4637)
local mapPreparing=false
local mapPreparingAt=0
local preparedMap=nil
local loadConnection,loadRemote
local function watchMapPreparation()
    local remotes=ReplicatedStorage:FindFirstChild("Remotes")
    local remote=remotes and remotes:FindFirstChild("Load")
    if remote==loadRemote then return end
    if loadConnection then loadConnection:Disconnect();loadConnection=nil end
    loadRemote=remote
    if remote and remote:IsA("RemoteEvent")then
        loadConnection=connect(remote.OnClientEvent,function(action)
            if action=="PrepareMap"then
                mapPreparing=true;mapPreparingAt=os.clock();preparedMap=nil
            end
        end)
    end
end
local function preparedMapName()
    if not mapPreparing then return nil end
    if preparedMap and preparedMap.Parent~=Workspace then
        mapPreparing=false;preparedMap=nil;return nil
    end
    local map=preparedMap or Workspace:FindFirstChild("Map")
    if not map then
        if os.clock()-mapPreparingAt>60 then mapPreparing=false end
        return nil
    end
    preparedMap=map
    local name=map:GetAttribute("StreamMapName")
    if type(name)=="string"and name~=""then return name end
    local scene=map:FindFirstChild("Camerascene1",true)
    name=scene and scene:GetAttribute("title")
    if type(name)=="string"and name~=""then return name end
end
local function read(names)
    for _,name in ipairs(names)do for _,root in ipairs({ReplicatedStorage,Workspace})do
        local value=root:GetAttribute(name)
        if(type(value)=="string"and value~="")or type(value)=="number"then return tostring(value)end
        local item=root:FindFirstChild(name,true)
        if item and(item:IsA("StringValue")or item:IsA("IntValue"))and tostring(item.Value)~=""then return tostring(item.Value)end
        if item and item:IsA("ObjectValue")and item.Value then return item.Value.Name end
    end end
end
local function bestKillerChance()
    local best,candidates=nil,{}
    for _,who in ipairs(Players:GetPlayers())do
        local chance=tonumber(who:GetAttribute("KillerChance"))
        if who:GetAttribute("AllowKiller")==true and chance and chance>0 then
            if not best or chance>best then best=chance;candidates={}end
            if chance==best then candidates[#candidates+1]=who end
        end
    end
    if not best then return nil end
    table.sort(candidates,function(a,b)return a.Name:lower()<b.Name:lower()end)
    local names={}
    for i=1,math.min(3,#candidates)do
        local who=candidates[i];local selected=who:GetAttribute("SelectedKiller")
        local name=who.DisplayName or who.Name
        if type(selected)=="string"and selected~=""then name=name.." · "..selected end
        names[#names+1]=name
    end
    if #candidates>3 then names[#names+1]="ещё "..(#candidates-3)end
    return "Наибольший шанс ("..tostring(best).."): "..table.concat(names,", ")
end
state.nextRoundDiagnostics=function()
    local report={candidates={},mapPreparing=mapPreparing,preparedMap=preparedMapName()}
    for _,root in ipairs({ReplicatedStorage,Workspace,player.PlayerGui})do
        local rootAttributes={}
        for key,value in pairs(root:GetAttributes())do
            local name=key:lower()
            if name:find("next",1,true)or name:find("upcoming",1,true)then rootAttributes[key]=tostring(value)end
        end
        if next(rootAttributes)then report.candidates[#report.candidates+1]={path=root:GetFullName(),attributes=rootAttributes}end
        for _,item in ipairs(root:GetDescendants())do
            local name=item.Name:lower()
            if(name:find("next",1,true)or name:find("upcoming",1,true))
                and(name:find("map",1,true)or name:find("killer",1,true)or name:find("round",1,true))then
                local row={path=item:GetFullName(),class=item.ClassName}
                if item:IsA("StringValue")or item:IsA("IntValue")or item:IsA("NumberValue")then row.value=tostring(item.Value)
                elseif item:IsA("ObjectValue")and item.Value then row.value=item.Value.Name
                elseif item:IsA("TextLabel")then row.value=item.Text end
                report.candidates[#report.candidates+1]=row
                if #report.candidates>=80 then return report end
            end
            local attributes={}
            for key,value in pairs(item:GetAttributes())do
                local field=key:lower()
                if(field:find("next",1,true)or field:find("upcoming",1,true))
                    and(field:find("map",1,true)or field:find("killer",1,true))then attributes[key]=tostring(value)end
            end
            if next(attributes)then
                report.candidates[#report.candidates+1]={path=item:GetFullName(),attributes=attributes}
                if #report.candidates>=80 then return report end
            end
        end
    end
    return report
end
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0
    watchMapPreparation()
    local showBoth=state.nextRound or state.showNextHud
    local showMap=showBoth or state.nextRoundMap
    local showKiller=showBoth or state.nextRoundKiller
    state.nextRoundHud.Visible=showMap or showKiller
    if not showMap and not showKiller then text.Text="Следующий раунд: выключено.";return end
    local killer=read({"NextKiller","NextKillerName","UpcomingKiller"})
    local map=read({"NextMap","NextMapName","UpcomingMap"})
    local preparing=not map and preparedMapName()or nil
    local lines={}
    if showKiller then lines[#lines+1]=killer and("Киллер: "..killer)or bestKillerChance()or "Киллер: нет данных"end
    if showMap then
        lines[#lines+1]=map and("Следующая карта: "..map)or(preparing and("Карта раунда: "..preparing)or "Карта: нет данных")
    end
    local value=table.concat(lines,"\n")
    text.Text="Данные игры\n"..value
    state.nextRoundHudText.Text="Следующий раунд · данные игры\n"..value
end)
end

-- FOV visibility is owned by its ability. Turning the ability off removes its visuals.
do
local ring=Instance.new("Frame");ring.Name="ParryFov";ring.BackgroundTransparency=1
ring.Size=UDim2.fromScale(1,1);ring.Position=UDim2.fromOffset(0,0);ring.Visible=false;ring.Parent=crossGui
local segments={};local segmentCount=144
for i=1,segmentCount do
    local segment=Instance.new("Frame");segment.Name="ParryRadiusSegment";segment.BorderSizePixel=0
    segment.AnchorPoint=Vector2.new(0.5,0.5);segment.Visible=false;segment.BackgroundColor3=Color3.fromRGB(15,10,25)
    segment.Parent=ring
    local edgeRound=Instance.new("UICorner");edgeRound.CornerRadius=UDim.new(0,2);edgeRound.Parent=segment
    local core=Instance.new("Frame");core.Name="Core";core.BorderSizePixel=0
    core.AnchorPoint=Vector2.new(0,0.5);core.Position=UDim2.new(0,0,0.5,0);core.Size=UDim2.new(1,0,0,2)
    core.Parent=segment
    local coreRound=Instance.new("UICorner");coreRound.CornerRadius=UDim.new(0,1);coreRound.Parent=core
    segments[i]={segment=segment,core=core}
end
state.parryCircle=ring
local line=Instance.new("Frame");line.Name="HiddenTargetLine";line.AnchorPoint=Vector2.new(0,0.5)
line.BorderSizePixel=0;line.Visible=false;line.Parent=crossGui
state.hiddenTargetLine=line
connect(RunService.RenderStepped,function()
    ring.Visible=false;line.Visible=false
    local cam=Workspace.CurrentCamera;if not cam then return end
    local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if state.parry and state.showParryFov and not isKiller(player)and root and hum and hum.Health>0 then
        local height=(hum.HipHeight or 0)+(root.Size and type(root.Size.Y)=="number" and root.Size.Y/2 or 0)
        local center=root.Position-Vector3.new(0,height,0)
        local previous,previousVisible
        for i=0,segmentCount do
            local angle=2*math.pi*i/segmentCount
            local world=center+Vector3.new(math.cos(angle)*state.parryRadius,0,math.sin(angle)*state.parryRadius)
            local point,onScreen=cam:WorldToViewportPoint(world)
            if i>0 then
                local part=segments[i].segment;local core=segments[i].core
                local dx,dy=point.X-previous.X,point.Y-previous.Y
                local length=math.sqrt(dx*dx+dy*dy)
                part.Visible=previous.Z>0 and point.Z>0 and length>0 and length<math.max(cam.ViewportSize.X,cam.ViewportSize.Y)*2
                if part.Visible then
                    part.Position=UDim2.fromOffset((previous.X+point.X)/2,(previous.Y+point.Y)/2);part.Size=UDim2.fromOffset(length+1,4)
                    part.Rotation=math.deg(math.atan2(dy,dx));core.BackgroundColor3=state.espColors.parryFov
                end
            end
            previous,previousVisible=point,onScreen
        end
        ring.Visible=true
    end
    local target=state.hiddenSelectedTarget
    if state.hiddenAim and state.showTargetLine and isKiller(player)and target and target.Parent then
        local point,onScreen=cam:WorldToViewportPoint(target.Position)
        if onScreen and point.Z>0 then
            local center=state.widgetPositions.hiddenFov or {0.5,0.5}
            local x,y=cam.ViewportSize.X*center[1],cam.ViewportSize.Y*center[2]
            local dx,dy=point.X-x,point.Y-y;local length=math.sqrt(dx*dx+dy*dy)
            line.Position=UDim2.fromOffset(x,y);line.Size=UDim2.fromOffset(length,1.5)
            line.Rotation=math.deg(math.atan2(dy,dx));line.BackgroundColor3=state.espColors.hiddenFov;line.Visible=length>1
        end
    end
end)
end

-- Sprint uses native controls; no WalkSpeed writes or forced forward movement.
do
local ownsShift,sending=false,false
local lastMobile=-math.huge
local mobileButton,mobileCharacter,mobileStarted=nil,nil,false
local sprintInfo=label("Спринт работает при движении. Скорость задаёт игра.",3726,44)
sprintInfo.Name="SprintInfo"
local function shift(down)
    if not virtualInput then return false end
    sending=true
    local ok=pcall(function()virtualInput:SendKeyEvent(down,Enum.KeyCode.LeftShift,false,game)end)
    sending=false
    if ok then ownsShift=down end
    return ok
end
local function mobileState(button)
    for _,object in ipairs({player.Character,button})do
        if object then for _,name in ipairs({"Sprinting","IsSprinting","Running","IsRunning","SprintEnabled"})do
            local value=object:GetAttribute(name)
            if type(value)=="boolean"then return value end
            local child=object:FindFirstChild(name)
            if child and child:IsA("BoolValue")then return child.Value end
        end end
    end
end
local function findSprint()
    for _,item in ipairs(player.PlayerGui:GetDescendants())do
        if item:IsA("TextButton")or item:IsA("ImageButton")then
            local name=item.Name:lower():gsub("[^a-z]","")
            if(name=="sprint"or name=="sprintbutton"or name=="run"or name=="runbutton")and visibleUI(item)then return item end
        end
    end
end
local function tap(button)
    if not button or not button.Parent or not virtualInput or not visibleUI(button)then return false end
    local point=button.AbsolutePosition+button.AbsoluteSize/2+game:GetService("GuiService"):GetGuiInset()
    local ok=pcall(function()virtualInput:SendTouchEvent(8824,0,point.X,point.Y)end)
    pcall(function()virtualInput:SendTouchEvent(8824,2,point.X,point.Y)end)
    return ok
end
local function resetMobile()
    if mobileStarted and mobileCharacter==player.Character and mobileButton and mobileState(mobileButton)==true then tap(mobileButton)end
    mobileStarted=false;mobileButton=nil;mobileCharacter=nil
end
state.resetSprint=function()
    if ownsShift then shift(false)end
    resetMobile()
end
toggle("autoRunPC","auto run(pc)",3642)
toggle("autoRunMobile","auto run(mobile)",3684)
connect(Input.InputEnded,function(input)
    if not sending and input.KeyCode==Enum.KeyCode.LeftShift then ownsShift=false end
end)
local focused=true
pcall(function()connect(Input.WindowFocusReleased,function()focused=false;state.resetSprint()end)end)
pcall(function()connect(Input.WindowFocused,function()focused=true end)end)
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<0.1 then return end;elapsed=0
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local moving=hum and hum.MoveDirection and hum.MoveDirection.Magnitude>0.05
    local vaultReady=state.fastVault and state.vaultNearWindow
    local allowed=state.alive and focused and hum and hum.Health>0 and (moving or vaultReady)and not Input:GetFocusedTextBox()
        and not state.selfHealing and not state.capturingBind and not state.dropdownOpen and not state.draggingWidget
        and not state.isDowned(char)
    if state.vaultRuntime and state.fastVault then
        state.vaultRuntime.moving=moving and true or false
        state.vaultRuntime.sprintAllowed=allowed and true or false
        state.vaultRuntime.shiftOwned=ownsShift
        state.vaultRuntime.mobileButtonFound=mobileButton~=nil
        if mobileButton then state.vaultRuntime.mobileSprintState=mobileState(mobileButton)
        else state.vaultRuntime.mobileSprintState=nil end
    end
    if (state.autoRunPC or(state.fastVault and state.vaultNearWindow))and Input.KeyboardEnabled and not((state.autoRunMobile or state.vaultSprint)and Input.TouchEnabled)and allowed then
        if not ownsShift then
            local physical=false;pcall(function()physical=Input:IsKeyDown(Enum.KeyCode.LeftShift)end)
            if not physical and not shift(true)then sprintInfo.Text="PC: виртуальный Shift недоступен."end
        end
    elseif ownsShift then shift(false)end
    if not(state.autoRunMobile or state.vaultSprint)or not Input.TouchEnabled or not allowed then
        resetMobile();return
    end
    if mobileCharacter~=char then resetMobile();mobileCharacter=char end
    local button=findSprint()
    if not button then sprintInfo.Text="Mobile: штатная кнопка Sprint не найдена.";return end
    if mobileButton and mobileButton~=button then resetMobile();mobileCharacter=char end
    mobileButton=button
    local running=mobileState(button)
    if running==nil then sprintInfo.Text="Mobile: нет доступного индикатора спринта; повторные нажатия заблокированы.";return end
    if running==false and os.clock()-lastMobile>=1 then
        lastMobile=os.clock()
        if tap(button)then mobileStarted=true;sprintInfo.Text="Mobile: отправлено нажатие Sprint."
        else sprintInfo.Text="Mobile: симуляция касания недоступна."end
    end
end)
end

-- Native survival helpers. These do not alter health or grant items/perks.
do
local slowHum,slowOriginal,slowApplied
local speedHum,normalSpeed,sprintSpeed
local healSession
local healInfo=label("Самохил: нажми кнопку, когда ранен и не нокнут.",3894,34);healInfo.Name="SelfHealInfo";state.healInfo=healInfo
local function boolFlag(object,name)
    if not object then return false end
    local value=object:GetAttribute(name)
    if value==true or(type(value)=="number"and value>0)then return true end
    local child=object:FindFirstChild(name)
    return child and(child:IsA("BoolValue")and child.Value==true or(child:IsA("NumberValue")and child.Value>0))or false
end
local function anyFlag(char,hum,names)
    for _,name in ipairs(names)do if boolFlag(char,name)or boolFlag(hum,name)then return true end end
    return false
end
local function slowed(char,hum)
    return anyFlag(char,hum,{"Slowed","Hindered","Slowdown","Slow","MovementDebuff","SpeedDebuff","SlowStacks"})
end
local function busy(char,hum)
    return state.selfHealing or anyFlag(char,hum,{"Hooked","IsHooked","Carried","BeingCarried","Stunned","Frozen","Repairing","Healing","Vaulting","IsVaulting","UsingItem","Attacking"})
end
local function sprinting(char,hum)
    if boolFlag(char,"Sprinting")or boolFlag(hum,"Sprinting")then return true end
    local held=false;pcall(function()held=Input:IsKeyDown(Enum.KeyCode.LeftShift)end);return held
end
local function releaseSlow(ended)
    if slowHum then pcall(function()
        if not ended and slowHum.WalkSpeed==slowApplied then slowHum.WalkSpeed=slowOriginal end
    end)end
    slowHum,slowOriginal,slowApplied=nil,nil,nil
end
local function stopHealing()
    local session=healSession;healSession=nil;state.selfHealing=false
    if session then pcall(function()
        session.remote:FireServer(session.root,false,session.requestId,session.char)
    end)end
end
state.resetSurvival=function()releaseSlow(false);stopHealing()end
local function injured(char,hum)
    return not state.isDowned(char)and hum.Health>50 and hum.Health<95 and hum.Health<hum.MaxHealth
end
toggle("noSlowdown","No slowdown",3800)
label("Восстанавливает обычную скорость при распознанном замедлении.",3840,28)
local function toggleSelfHeal()
    if healSession then stopHealing();healInfo.Text="Самохил остановлен.";return end
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not root or isKiller(player)or not injured(char,hum)then
        healInfo.Text="Самохил доступен раненому игроку без нокдауна.";return
    end
    if hum.MoveDirection.Magnitude>.05 or busy(char,hum)then
        healInfo.Text="Остановись и заверши текущее действие.";return
    end
    local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local healing=remotes and remotes:FindFirstChild("Healing")
    local remote=healing and healing:FindFirstChild("HealEvent")
    if not remote or not remote:IsA("RemoteEvent")then healInfo.Text="Запрос лечения не найден.";return end
    local requestId=game:GetService("HttpService"):GenerateGUID(false)
    local ok=pcall(function()remote:FireServer(root,true,requestId,char)end)
    if not ok then healInfo.Text="Не удалось отправить запрос лечения.";return end
    healSession={remote=remote,root=root,char=char,hum=hum,requestId=requestId,start=os.clock()}
    state.selfHealing=true
    healInfo.Text="Запрос отправлен. Ждём результат игры."
end
button("Самохил / остановить",3860,toggleSelfHeal)
local healBindButton
state.refreshHealBind=function()
    if healBindButton then
        healBindButton.Text=state.capturingBind=="selfHeal"and "Нажми клавишу · Backspace убрать · Esc отмена"
            or "Бинд самохила: "..bindLabel(state.selfHealBind)
    end
end
healBindButton=button("Бинд самохила: не назначен",3861,function()
    waitingBind=false;bindButton.Text="Бинд авто парирования: "..bindLabel(state.parryBind)
    state.capturingBind="selfHeal";state.refreshHealBind()
end)
connect(Input.InputBegan,function(input,processed)
    if Input:GetFocusedTextBox()then return end
    if state.capturingBind=="selfHeal"then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local key=input.KeyCode
        if key==Enum.KeyCode.Escape then state.capturingBind=nil
        elseif key==Enum.KeyCode.Backspace then state.selfHealBind=Enum.KeyCode.Unknown;state.capturingBind=nil
        elseif key~=Enum.KeyCode.Unknown and key~=Enum.KeyCode.Space and key~=Enum.KeyCode.LeftShift
            and key~=state.menuBind and key~=state.parryBind and key~=state.hiddenBind
            and key~=state.moonForwardBind and key~=state.moonBackwardBind and key~=state.emoteBind
            and key.Name~=state.parryInput then
            state.selfHealBind=key;state.capturingBind=nil
        else status.Text="Клавиша занята."end
        state.refreshHealBind();return
    end
    if not processed and not state.capturingBind and not state.dropdownOpen
        and state.selfHealBind~=Enum.KeyCode.Unknown and input.KeyCode==state.selfHealBind then
        toggleSelfHeal()
    end
end)
state.refreshHealBind()
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local active=state.alive and hum and hum.Health>0 and not state.isDowned(char)
    if hum~=speedHum then releaseSlow(false);speedHum=hum;normalSpeed,sprintSpeed=nil,nil;stopHealing()end
    local hasSlow=active and slowed(char,hum)
    local isBusy=active and busy(char,hum)
    if active and not hasSlow and not isBusy and hum.WalkSpeed>=4 then
        if sprinting(char,hum)then sprintSpeed=hum.WalkSpeed else normalSpeed=hum.WalkSpeed end
    end
    if active and state.noSlowdown and hasSlow and not isBusy and hum.WalkSpeed>0 then
        local baseline=(sprinting(char,hum)and sprintSpeed or normalSpeed)
            or hum:GetAttribute("BaseWalkSpeed")or char:GetAttribute("BaseWalkSpeed")
        if type(baseline)=="number"and baseline>0 and baseline<=40 then
            if slowHum~=hum then releaseSlow(false);slowHum=hum;slowOriginal=hum.WalkSpeed end
            if slowApplied and hum.WalkSpeed~=slowApplied then slowOriginal=hum.WalkSpeed end
            slowApplied=baseline
            if hum.WalkSpeed<baseline then hum.WalkSpeed=baseline end
            state.slowdownStatus="ordinary speed restored locally"
        else state.slowdownStatus="waiting for ordinary speed sample"end
    else releaseSlow(active and not hasSlow)end
    if healSession then
        if player.Character~=healSession.char or not active or isKiller(player)
            or hum.MoveDirection.Magnitude>.05
            or anyFlag(char,hum,{"Hooked","IsHooked","Carried","BeingCarried","Stunned","Frozen","Repairing","Vaulting","IsVaulting","Attacking"})then
            stopHealing();healInfo.Text="Самохил остановлен."
        elseif not injured(char,hum)then
            stopHealing();healInfo.Text="Здоровье восстановлено."
        elseif os.clock()-healSession.start>30 then
            stopHealing();healInfo.Text="Самохил не подтверждён игрой."
        end
    end
end)
end

-- Named profiles are stored in a single data-only JSON index.
do
local nameBox
local choice=state.dropdown(3450,"Конфиг",function()
    local names={};for name in pairs(state.profiles)do names[#names+1]=name end
    if not state.profiles[state.profileName]then names[#names+1]=state.profileName end
    table.sort(names,function(a,b)return a:lower()<b:lower()end)
    local result={};for _,name in ipairs(names)do result[#result+1]={value=name,label=name}end;return result
end,function()return state.profileName end,function(name)
    if state.switchProfile then local ok,reason=state.switchProfile(name);status.Text=ok and("Конфиг: "..name)or tostring(reason)end
end,"profiles")
label("Название конфига",3484,24)
nameBox=textSetting(3520,"Default",function(value)
    value=value:match("^%s*(.-)%s*$")
    if #value==0 or #value>48 or value:find("[%z\1-\31]")then status.Text="Название: 1–48 символов.";return end
    state.profileDraft=value;return value
end)
nameBox.Name="ProfileName"
button("Сохранить как",3554,function()
    local name=state.profileDraft or state.profileName
    if state.saveProfileAs then local ok,reason=state.saveProfileAs(name);status.Text=ok and("Сохранён конфиг: "..name)or tostring(reason)end
end)
state.refreshProfileUI=function()
    choice:refresh()
    if Input:GetFocusedTextBox()~=nameBox then textControls[3520].sync(state.profileName);state.profileDraft=state.profileName end
end
end

-- Passive, bounded observation of the player's animations for diagnostics.
do
local observedAnimator,observer
local recent={}
local capture
state.vaultObservations=recent
local function disconnect()
    if observer then observer:Disconnect();observer=nil end
    observedAnimator=nil;capture=nil
end
state.resetVaultObserver=disconnect
local function record(track)
    local anim=track.Animation
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local row={name=tostring(track.Name or ""),asset=anim and tostring(anim.AnimationId)or "",
        source=anim and tostring(anim.Name)or "",speed=track.Speed,
        action=char and char:GetAttribute("ActionState"),
        vaultspeed=char and char:GetAttribute("vaultspeed"),anchored=root and root.Anchored}
    table.insert(recent,1,row);while #recent>20 do table.remove(recent)end
    local text=(row.name.." "..row.source):lower();local id=row.asset:match("%d+")
    if root and(text:find("vault",1,true)or id=="83873880822918"or id=="136962284480779")then
        row.samples={};capture={row=row,track=track,root=root,start=root.Position,time=os.clock()}
    end
end
local sampleElapsed=0
connect(RunService.Heartbeat,function(dt)
    if not capture then return end
    sampleElapsed=sampleElapsed+dt;if sampleElapsed<.1 then return end;sampleElapsed=0
    local c=capture;local root=c.root;local char=player.Character
    if not root.Parent or not char or os.clock()-c.time>10 or #c.row.samples>=80 then capture=nil;return end
    local delta=root.Position-c.start
    local hum=char:FindFirstChildOfClass("Humanoid")
    local velocity=root.AssemblyLinearVelocity
    c.row.samples[#c.row.samples+1]={t=os.clock()-c.time,x=delta.X,y=delta.Y,z=delta.Z,
        anchored=root.Anchored,playing=c.track.IsPlaying,timePosition=c.track.TimePosition,
        velocity={velocity.X,velocity.Y,velocity.Z},walkSpeed=hum and hum.WalkSpeed,
        moveDirection=hum and {hum.MoveDirection.X,hum.MoveDirection.Y,hum.MoveDirection.Z},
        humanoidState=hum and tostring(hum:GetState()),platformStand=hum and hum.PlatformStand,
        action=char:GetAttribute("ActionState"),vaultspeed=char:GetAttribute("vaultspeed")}
    if not c.track.IsPlaying then
        if not c.stoppedAt then c.stoppedAt=os.clock();c.row.animationStoppedAt=c.stoppedAt-c.time end
        if os.clock()-c.stoppedAt>=.8 then capture=nil end
    else c.stoppedAt=nil end
end)
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    local animator=hum and hum:FindFirstChildOfClass("Animator")
    if animator~=observedAnimator then
        disconnect();observedAnimator=animator
        if animator then observer=animator.AnimationPlayed:Connect(record)end
    end
end)
end

-- Local diagnostics: object/UI metadata only, no input logging or network upload.
do
local Http=game:GetService("HttpService")
local function path(item)
    local names={};local depth=0
    while item and item~=Workspace and item~=player.PlayerGui and depth<6 do
        table.insert(names,1,item.Name);item=item.Parent;depth=depth+1
    end
    return table.concat(names,"/")
end
state.inspectSkillUI=function(check)
    local result={path=path(check),nodes={}}
    local list={check};for _,item in ipairs(check:GetDescendants())do if #list>=80 then break end;list[#list+1]=item end
    for _,item in ipairs(list)do
        if item:IsA("GuiObject")or item:IsA("NumberValue")or item:IsA("IntValue")then
            local row={name=item.Name,class=item.ClassName,attributes={}}
            for name,value in pairs(item:GetAttributes())do if type(value)=="number"or type(value)=="boolean"or(type(value)=="string"and #value<120)then row.attributes[name]=value end end
            if item:IsA("GuiObject")then
                row.visible=item.Visible;row.rotation=item.Rotation;row.size={item.AbsoluteSize.X,item.AbsoluteSize.Y};row.position={item.AbsolutePosition.X,item.AbsolutePosition.Y}
                if item:IsA("ImageLabel")or item:IsA("ImageButton")then row.image=item.Image end
            else row.value=item.Value end
            result.nodes[#result.nodes+1]=row
        end
    end
    return result
end
state.diagnosticReport=function()
    local report={schema="SETERAGE_DIAGNOSTICS",version=2,features={fastBreak=state.fastBreak,breakMultiplier=state.breakMultiplier,fastVault=state.fastVault,autoSkill=state.autoSkill,
        skillMode=state.skillMode,stretch=state.stretch,stretchMode=state.stretchMode,antiKnock=state.antiKnock},
        role=player.Team and player.Team.Name or "unknown",rates=state.rateAdapters,performance=state.perf,cameraAdapter=state.cameraAdapter,zoneSource=state.skillZoneSource,skillUI=state.lastSkillUI,
        animations=state.vaultObservations or {},skillTrace=state.skillTrace,windowESP=state.windowEspDiagnostics and state.windowEspDiagnostics()or nil,
        parry=state.parryDiagnostics and state.parryDiagnostics()or nil,vault=state.vaultRuntime,spikeVault=state.spikeVaultDiagnostics,
        audio=state.audioDiagnostics and state.audioDiagnostics()or nil,
        nextRound=state.nextRoundDiagnostics and state.nextRoundDiagnostics()or nil,
        killerPerks=state.perkDiagnostics and state.perkDiagnostics()or nil,objects={}}
    local camera=Workspace.CurrentCamera
    if camera then report.camera={viewport={camera.ViewportSize.X,camera.ViewportSize.Y},fov=camera.FieldOfView}
        pcall(function()report.camera.viewStretch=camera.ViewStretch end)
    end
    local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid")
    report.character={downed=state.isDowned(),health=hum and hum.Health,walkSpeed=hum and hum.WalkSpeed,flags={}}
    if char then
        report.character.stateAttributes={}
        for name,value in pairs(char:GetAttributes())do
            local key=name:lower()
            if key:find("state",1,true)or key:find("status",1,true)or key:find("down",1,true)or key:find("knock",1,true)or key:find("crawl",1,true)or key:find("slow",1,true)or key:find("hinder",1,true)or key:find("speed",1,true)then
                if type(value)=="number"or type(value)=="boolean"or(type(value)=="string"and #value<120)then report.character.stateAttributes[name]=value end
            end
        end
    end
    if char then for _,name in ipairs({"Downed","IsDowned","Knocked","IsKnocked","Dying","Crawling","Hooked","Carried"})do report.character.flags[name]=char:GetAttribute(name)end end
    local root=char and char:FindFirstChild("HumanoidRootPart");local nearby={}
    if root then
        report.character.anchored=root.Anchored;report.character.platformStand=hum and hum.PlatformStand
        local velocity=root.AssemblyLinearVelocity
        if velocity then report.character.velocity={velocity.X,velocity.Y,velocity.Z}end
        report.character.requestedSpeed=state.godRequestedSpeed
    end
    report.slowdown=state.slowdownStatus
    report.emotes=state.emoteDiagnostics and state.emoteDiagnostics()or nil
    report.healing={active=state.selfHealing or false,status=state.healInfo and state.healInfo.Text or nil,equipped={}}
    if char then for _,item in ipairs(char:GetChildren())do if item:IsA("Tool")then
        report.healing.equipped[#report.healing.equipped+1]={name=item.Name,action=item:GetAttribute("UseAction")or item:GetAttribute("Action"),selfHealOnActivate=item:GetAttribute("SelfHealOnActivate")}
    end end end
    local generators={}
    if root and state.getIndexedObjects then for _,entry in ipairs(state.getIndexedObjects())do
        if entry.part then
            local distance=(entry.part.Position-root.Position).Magnitude
            nearby[#nearby+1]={kind=entry.kind,path=path(entry.item),distance=distance}
            if entry.kind=="generators"then generators[#generators+1]={item=entry.item,distance=distance}end
        end
    end end
    table.sort(nearby,function(a,b)return a.distance<b.distance end)
    for i=1,math.min(16,#nearby)do report.objects[i]=nearby[i]end
    table.sort(generators,function(a,b)return a.distance<b.distance end)
    report.generatorStates={}
    for i=1,math.min(3,#generators)do
        local item=generators[i].item;local attrs={}
        for key,value in pairs(item:GetAttributes())do
            if type(value)=="number"or type(value)=="boolean"or(type(value)=="string"and #value<120)then attrs[key]=value end
        end
        report.generatorStates[#report.generatorStates+1]={path=path(item),attributes=attrs}
    end
    return Http:JSONEncode(report)
end
button("Скопировать диагностику",5882,function()
    local ok,text=pcall(state.diagnosticReport)
    if not ok then status.Text="Не удалось собрать диагностику.";return end
    state.presentDiagnostic(text)
    local copied=type(setclipboard)=="function"and pcall(setclipboard,text)
    status.Text=copied and "Диагностика скопирована. Приложи её к сообщению."or "Диагностика в поле JSON. Скопируй текст вручную."
end)
local capturedCheck,capturedGoal
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    local gui=player.PlayerGui:FindFirstChild("SkillCheckPromptGui")
    local check=gui and gui:FindFirstChild("Check")
    if check and visibleUI(check)then
        local goal=check:FindFirstChild("Goal");local rotation=goal and goal.Rotation
        if check~=capturedCheck or rotation~=capturedGoal then
            capturedCheck,capturedGoal=check,rotation
            state.lastSkillUI=state.inspectSkillUI(check);state.perf.skillSnapshots=state.perf.skillSnapshots+1
        end
    else capturedCheck,capturedGoal=nil,nil end
end)
end

-- Local utilities; server-controlled capabilities remain unavailable without an adapter.
do
local Lighting=game:GetService("Lighting")
local light
local savedZoom
local warning=Instance.new("TextLabel");warning.Name="KillerWarning";warning.BackgroundTransparency=1
warning.Size=UDim2.fromOffset(150,40);warning.Position=UDim2.new(.5,-75,.2,0)
warning.Text="! Киллер рядом";warning.TextColor3=Color3.fromRGB(255,85,105);warning.TextSize=18
warning.Font=Enum.Font.GothamBold;warning.Visible=false;warning.Parent=crossGui
local function restore()
    if light then light:Destroy();light=nil end
    if savedZoom then pcall(function()player.CameraMaxZoomDistance=savedZoom end);savedZoom=nil end
    warning.Visible=false
end
state.resetUtilities=restore
toggle("fullbright","Fullbright",4800)
toggle("killerWarn","Киллер рядом",4842)
toggle("antiAfk","Anti AFK",9700)
toggle("maxZoom","Дальний зум",9742)
label("Работает, если клиент поддерживает виртуальный ввод.",9784,30)
pcall(function()connect(player.Idled,function()
    if not state.antiAfk or Input:GetFocusedTextBox()then return end
    local ok,vu=pcall(function()return game:GetService("VirtualUser")end)
    if ok and vu then pcall(function()vu:CaptureController();vu:Button2Down(Vector2.new(0,0),Workspace.CurrentCamera.CFrame);vu:Button2Up(Vector2.new(0,0),Workspace.CurrentCamera.CFrame)end)end
end)end)
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    if state.fullbright and not light then
        pcall(function()light=Instance.new("ColorCorrectionEffect");light.Name="SeterageFullbright";light.Brightness=.25;light.Contrast=-.1;light.Parent=Lighting end)
    elseif not state.fullbright and light then light:Destroy();light=nil end
    if state.maxZoom then
        pcall(function()if not savedZoom then savedZoom=player.CameraMaxZoomDistance end;player.CameraMaxZoomDistance=400 end)
    elseif savedZoom then pcall(function()player.CameraMaxZoomDistance=savedZoom end);savedZoom=nil end
    warning.Visible=false
    if state.killerWarn and not isKiller(player)then
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then for _,who in ipairs(Players:GetPlayers())do
            local enemy=who~=player and isKiller(who)and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
            if enemy and(enemy.Position-root.Position).Magnitude<=60 then warning.Visible=true;break end
        end end
    end
end)
end

-- Left navigation and responsive content layout.
do
local sections={"survival","killer","esp","config"}
local pages,tabButtons,buckets,scrollPositions={},{},{survival={},killer={},esp={},config={}},{ }
local hints={
    [182]="Нажимает в выбранной зоне скиллчека.",
    [522]="Растягивает 3D-вид. Разрешение не меняет.",
    [730]="Только доступные клиенту перки.",
    [782]="Роли определяются по командам игроков.",
    [1286]="Клавиша меню меняется в Config.",
    [1552]="1 — точно на тебя. −1 — любое направление.",
    [1852]="Сразу по доступной анимации атаки. Нужен даггер.",
    [2024]="Без конфига функции выключены, бинды не заданы.",
    [2242]="Параметр BreakSpeed + анимация. ×1 — без ускорения.",
    [2482]="Бег в нокдауне; действия не разблокируются. Сервер может корректировать движение.",
    [2576]="Только киллер. Скрывает известные эффекты Blind.",
    [2670]="Локальный вид ноги R15.",
    [2980]="Наведение только во время известной Hidden M2.",
    [3438]="Импорт восстанавливает настройки и бинды из JSON.",
    [4362]="Метры приблизительные. Объекты ищутся по именам.",
    [5976]="Скрой меню и перетащи рамку.",
}
local shortLabels={
    [230]="КАМЕРА",[302]="FOV: 40–120",[456]="Сила растяжения: 0.5–2",[616]="Радиус радара, студы",
    [920]="ПРИЦЕЛ И МЕНЮ",[992]="Размер прицела",[1146]="Масштаб меню: 0.6–1.5",
    [1340]="ДАГГЕР",[1412]="Расстояние до убийцы: 2–25 студов",[1482]="Направление взгляда убийцы: −1…1",
    [1782]="Пауза между попытками: 0.2–5 с",
    [2090]="ПАЛЕТЫ",[2162]="Множитель анимации: 1–10",
    [2312]="Доп. ID разрушения палет",[2410]="АБИЛКИ",[2726]="HIDDEN M2",[2798]="FOV: 35–400 пикселей",
    [2868]="Скорость наведения: 1–40",[3154]="КОНФИГ",[4286]="Дальность ESP: 10–1500 м",
}
local function route(y)
    if y==2490 or y==2493 or y==2494 or y==2495 or y==2496 or y==2497 then return "survival"end
    if y>=7000 and y<9300 then return "survival"end
    if y>=3600 and y<=3900 then return "survival"end
    if y>=6000 and y<7000 then return "esp"end
    if y>=5000 then return "config"end
    if (y>=230 and y<=560)or(y>=920 and y<=1105)then return "esp"end
    if y==52 or y==53 or y==53.5 or y==1105 or(y>=574 and y<=842)or y>=4000 then return "esp"end
    if(y>=96 and y<=182)or(y>=1340 and y<=1932)or(y>=2410 and y<=2482)then return "survival"end
    if(y>=2090 and y<=2350)or(y>=2534 and y<=2576)or(y>=2726 and y<=3024)then return "killer"end
    return "config"
end
for index,child in ipairs(content:GetChildren())do
    if child:IsA("GuiObject")then
        local y=child.Position.Y.Offset
        local duplicateHeaders={[230]=true,[920]=true,[1340]=true,[2090]=true,[2410]=true,[2726]=true,[3154]=true,[4000]=true,[5000]=true,[6000]=true}
        if y==3036 or y==3076 or duplicateHeaders[y]then child:Destroy()
        else
            if hints[y]then child.Text=hints[y];child.Name="Hint_"..y;child.Size=UDim2.new(1,-28,0,26)end
            if shortLabels[y]then child.Text=shortLabels[y];child.Size=UDim2.new(1,-28,0,24)end
            buckets[route(y)][#buckets[route(y)]+1]={item=child,y=y,index=index,hint=hints[y]~=nil}
        end
    end
end
tabBar=Instance.new("Frame")
tabBar.Name="SectionTabs"
tabBar.BackgroundTransparency=0.15
tabBar.BorderSizePixel=0
tabBar.Parent=panel
content.Position=UDim2.fromOffset(state.sideWidth+16,52)
content.Size=UDim2.new(1,-state.sideWidth-20,1,-96)
status.Parent=panel
status.TextSize=11
status.Size=UDim2.new(1,-state.sideWidth-46,0,32)
status.Position=UDim2.new(0,state.sideWidth+30,1,-38)
local titleText=title
local outline=Instance.new("UIStroke");outline.Thickness=1;outline.Transparency=0.45;outline.Color=Color3.fromRGB(70,64,90);outline.Parent=panel
local sidebarCorner=Instance.new("UICorner");sidebarCorner.CornerRadius=UDim.new(0,10);sidebarCorner.Parent=tabBar
local sidebarOutline=Instance.new("UIStroke");sidebarOutline.Thickness=1;sidebarOutline.Transparency=.75;sidebarOutline.Parent=tabBar
local current="survival"
local baseSizes=setmetatable({},{__mode="k"})
local rowSizes=setmetatable({},{__mode="k"})
local textService
pcall(function()textService=game:GetService("TextService")end)
local fontPairs={
    Gotham={Enum.Font.Gotham,Enum.Font.GothamBold},
    SourceSans={Enum.Font.SourceSans,Enum.Font.SourceSansSemibold},
    Ubuntu={Enum.Font.Ubuntu,Enum.Font.Ubuntu},
    RobotoMono={Enum.Font.RobotoMono,Enum.Font.RobotoMono},
    Arial={Enum.Font.Arial,Enum.Font.ArialBold},
}
for _,name in ipairs({"Roboto","Oswald","FredokaOne","Nunito","TitilliumWeb","Code","Cartoon"})do
    local ok,font=pcall(function()return Enum.Font[name]end)
    if ok and font then fontPairs[name]={font,font}end
end
local themes={
    Graphite={panel=Color3.fromRGB(15,16,23),button=Color3.fromRGB(27,29,40),text=Color3.fromRGB(236,237,245),muted=Color3.fromRGB(150,153,172)},
    Midnight={panel=Color3.fromRGB(12,17,29),button=Color3.fromRGB(24,33,50),text=Color3.fromRGB(232,239,251),muted=Color3.fromRGB(155,175,201)},
    Light={panel=Color3.fromRGB(236,240,246),button=Color3.fromRGB(215,223,234),text=Color3.fromRGB(28,38,54),muted=Color3.fromRGB(75,92,115)},
}
local groupsByPage={}
state.groupIds={}
local function groupFor(section,y)
    if section=="survival"then
        if y>=3800 and y<=3900 then return "survivalTools","Скорость и лечение",7 end
        if y>=3600 and y<=3799 then return "sprint","Спринт",6 end
        if y>=9000 then return "moonwalk","Moonwalk",6 end
        if y>=8000 then return "customAudio","Кастомные звуки",7 end
        if y>=7400 then return "skillchecks","Скиллчеки",1 end
        if y>=7000 or y<200 then return "skillchecks","Скиллчеки",1 end
        if y>=2410 then return "survivorProtection","Абилки",5 end
        return "dagger","Даггер",4
    elseif section=="killer"then
        if y>=2726 then return "hiddenM2","Hidden M2",3 end
        if y>=2534 then return "killerProtection","Абилки",2 end
        return "palletBreak","Палеты",1
    elseif section=="esp"then
        if y>=4550 and y<=4700 then return "worldStyle","Мир и раунд",5 end
        if y>=6000 then return "espColors","Цвета",6 end
        if y>=4000 then return "worldEsp","Объекты",3 end
        if y>=920 then return "screenHud","Экран",4 end
        if y>=230 and y<=560 then return "camera","Камера",2 end
        return "worldEsp","Объекты",3
    end
    if y==5882 then return "diagnostics","Диагностика",8 end
    if y>=9700 then return "utilities","Утилиты",9 end
    if y>=9300 then return "emotes","Эмоции",7 end
    if y>=5890 and y<6000 then return "hudLayout","Виджеты",4 end
    if(y>=3154 and y<=3555)or(y>=5078 and y<=5204)then return "profiles","Конфиг",3 end
    if y==3496 or y==5036 then return "binds","Клавиши",2 end
    if y>=2628 and y<=2670 then return "cosmetic","Персонаж",5 end
    if y==1980 or y==2024 or y==3560 then return "actions","Управление",6 end
    return "appearance","Оформление",1
end
for _,name in ipairs(sections)do
    local page=Instance.new("Frame");page.Name="Section_"..name
    page.BackgroundTransparency=1;page.Visible=name==current;page.Parent=content;pages[name]=page
    table.sort(buckets[name],function(a,b)return a.y<b.y or(a.y==b.y and a.index<b.index)end)
    local map,list={},{}
    for _,entry in ipairs(buckets[name])do
        rowSizes[entry.item]=entry.item.Size.Y.Offset;entry.item.Parent=page
        local id,caption,order=groupFor(name,entry.y)
        if not map[id]then
            local header=Instance.new("TextButton");header.Name="Group_"..id
            header.Font=Enum.Font.GothamBold;header.TextSize=12;header.TextXAlignment=Enum.TextXAlignment.Left
            header.TextColor3=Color3.fromRGB(225,228,240);header.Text="− "..caption;header.Parent=page
            local outline=Instance.new("UIStroke");outline.Thickness=1;outline.Transparency=0.8;outline.Color=Color3.fromRGB(90,80,120);outline.Parent=header
            local group={id=id,title=caption,order=order,header=header,entries={}}
            map[id]=group;list[#list+1]=group;state.groupIds[id]=true
            connect(header.Activated,function()
                state.collapsedGroups[id]=not state.collapsedGroups[id]
                state.applyStyle()
            end)
        end
        map[id].entries[#map[id].entries+1]=entry
    end
    table.sort(list,function(a,b)return a.order<b.order end)
    groupsByPage[name]=list
end
local function measuredHeight(item,width,minimum)
    local height=minimum
    if textService and item.TextWrapped and item.Text~=""then
        local ok,size=pcall(function()return textService:GetTextSize(item.Text,item.TextSize,item.Font,Vector2.new(width,1000))end)
        if ok and size then height=math.max(height,size.Y+6)end
    end
    return height
end
local function relayout()
    state.sideWidth=math.clamp(math.floor(state.uiWidth*0.2),96,128)
    panel.Size=UDim2.fromOffset(state.uiWidth,collapsed and 46 or state.uiHeight)
    tabBar.Position=UDim2.fromOffset(8,52)
    tabBar.Size=UDim2.new(0,state.sideWidth,1,-60)
    content.Position=UDim2.fromOffset(state.sideWidth+16,52)
    content.Size=UDim2.new(1,-state.sideWidth-20,1,-96)
    status.Position=UDim2.new(0,state.sideWidth+30,1,-38)
    status.Size=UDim2.new(1,-state.sideWidth-46,0,32)
    local width=state.uiWidth-state.sideWidth-48
    for _,name in ipairs(sections)do
        local y=8
        for _,group in ipairs(groupsByPage[name])do
            local closed=state.collapsedGroups[group.id]==true
            group.header.Text=(closed and "+ "or "− ")..group.title
            group.header.Position=UDim2.fromOffset(14,y);group.header.Size=UDim2.new(1,-28,0,32)
            y=y+40
            for _,entry in ipairs(group.entries)do
                local item=entry.item
                item.Visible=not closed and(not entry.hint or state.showHints)
                if item.Visible then
                    local height=rowSizes[item]
                    if item:IsA("TextLabel")then height=measuredHeight(item,width,item.Name=="ESPObjectInfo"and 50 or(entry.hint and 22 or 24))
                    elseif item:IsA("TextButton")then height=measuredHeight(item,width-54,math.max(34,item.TextSize+16))end
                    item.Position=UDim2.fromOffset(14,y);item.Size=UDim2.new(1,-28,0,height)
                    y=y+height+6
                end
            end
            y=y+10
        end
        pages[name].Size=UDim2.new(1,0,0,y+8)
    end
    content.CanvasSize=UDim2.fromOffset(0,pages[current].Size.Y.Offset)
    fit()
    local size=gui.AbsoluteSize
    if size.X<=0 or size.Y<=0 then
        panel.Position=UDim2.fromScale(state.menuX,state.menuY)
        return
    end
    local halfX=state.uiWidth*scale.Scale/2
    local halfY=(collapsed and 46 or state.uiHeight)*scale.Scale/2
    local x=math.clamp(state.menuX*size.X,halfX,math.max(halfX,size.X-halfX))
    local y=math.clamp(state.menuY*size.Y,halfY,math.max(halfY,size.Y-halfY))
    panel.Position=UDim2.fromOffset(x,y)
    state.menuX=x/math.max(size.X,1);state.menuY=y/math.max(size.Y,1)
end
local applying=false
state.applyStyle=function()
    if applying then return end;applying=true
    local palette=themes[state.uiTheme]or themes.Graphite
    local font=fontPairs[state.uiFont]or fontPairs.Gotham
    if state.refreshUiOptions then state.refreshUiOptions()end
    if state.refreshHealBind then state.refreshHealBind()end
    panel.BackgroundColor3=palette.panel
    tabBar.BackgroundColor3=palette.button
    outline.Color=state.uiAccentColor:Lerp(palette.panel,.55)
    sidebarOutline.Color=state.uiAccentColor:Lerp(palette.button,.5)
    for _,item in ipairs(panel:GetDescendants())do
        if item:IsA("TextLabel")or item:IsA("TextButton")or item:IsA("TextBox")then
            local base=baseSizes[item]
            if not base then base={size=item.TextSize,bold=item.Font==Enum.Font.GothamBold};baseSizes[item]=base end
            if item.Name~="ConfigJSON"then item.Font=font[base.bold and 2 or 1]end
            item.TextSize=math.clamp(math.floor(base.size*state.uiTextScale+0.5),10,26)
            item.TextColor3=item.Name:match("^Hint_")and palette.muted or palette.text
            if item:IsA("TextButton")or item:IsA("TextBox")then
                item.BackgroundColor3=palette.button
                item.BackgroundTransparency=state.menuAlpha
                item.TextWrapped=true
                if item.Name=="SliderHit"then item.BackgroundTransparency=1 end
            end
        elseif item:IsA("UICorner")then
            local parent=item.Parent
            if parent and(parent==panel or parent:IsDescendantOf(panel))then item.CornerRadius=UDim.new(0,state.uiRadius)end
        end
    end
    if state.renderSwitches then state.renderSwitches()end
    for _,name in ipairs(sections)do
        tabButtons[name].BackgroundColor3=name==current and state.uiAccentColor or palette.button
        tabButtons[name].TextColor3=name==current and Color3.new(1,1,1)or palette.muted
        tabButtons[name].BackgroundTransparency=name==current and .12 or .35
    end

    if state.updateLogo then state.updateLogo()end
    if state.applyEspColors then state.applyEspColors()end
    if state.syncResizeHandles then state.syncResizeHandles()end
    if state.refreshPresentation then state.refreshPresentation()end
    relayout()
    if state.applyHudPositions then state.applyHudPositions()end
    applying=false
end
local function selectSection(name)
    if not pages[name]then return end
    scrollPositions[current]=content.CanvasPosition
    current=name
    for _,section in ipairs(sections)do pages[section].Visible=section==name end
    content.CanvasPosition=scrollPositions[name]or Vector2.new(0,0)
    state.applyStyle()
end
state.selectSection=selectSection
local tabLabels={survival="Выживший",killer="Убийца",esp="ESP",config="Настройки"}
for i,name in ipairs(sections)do
    local tab=Instance.new("TextButton")
    tab.Name="Tab_"..name
    tab.Position=UDim2.fromOffset(6,8+(i-1)*44)
    tab.Size=UDim2.new(1,-12,0,38)
    tab.Font=Enum.Font.GothamBold;tab.TextSize=12;tab.Text=tabLabels[name]
    tab.TextColor3=Color3.fromRGB(240,245,255);tab.Parent=tabBar
    local corner=Instance.new("UICorner");corner.Parent=tab
    tabButtons[name]=tab
    connect(tab.Activated,function()selectSection(name)end)
end
connect(gui:GetPropertyChangedSignal("AbsoluteSize"),function()state.applyStyle()end)
state.applyStyle()
end

-- Named profile persistence with legacy single-file migration and atomic validation.
do
local Http=game:GetService("HttpService")
local path="vd_helper_config.json"
local indexPath="seterage_profiles.json"
local reader=type(readfile)=="function"and readfile or nil
local writer=type(writefile)=="function"and writefile or nil
local loading,blocked=false,false
local lastSaved,pending,pendingAt=nil,nil,0
local function fingerprint(value)
    if type(value)~="table"then
        if type(value)=="number"then return string.format("%.17g",value)end
        if type(value)=="boolean"then return value and "true"or "false"end
        if type(value)=="string"then return #value..":"..value end
        return "nil"
    end
    local keys={};for k in pairs(value)do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local parts={};for _,k in ipairs(keys)do parts[#parts+1]=tostring(k)..":"..fingerprint(value[k])end
    return "{"..table.concat(parts,",").."}"
end
local function currentConfig()
    local text,document=state.exportConfig();return text,fingerprint(document)
end
local function writeIndex(profiles,selected)
    if not writer then return false,"Запись файлов недоступна; профили доступны до перезапуска."end
    if blocked then return false,"Индекс профилей повреждён и сохранён без перезаписи. Используй JSON Export."end
    local ok=pcall(function()writer(indexPath,Http:JSONEncode({schema="SETERAGE_PROFILES",version=1,selected=selected,profiles=profiles}))end)
    return ok,ok and nil or "Не удалось сохранить список конфигов."
end
state.saveConfigFile=function()
    local ok,text,signature=pcall(currentConfig)
    if not ok then return false,"Ошибка экспорта конфига."end
    local nextProfiles={};for name,value in pairs(state.profiles)do nextProfiles[name]=value end
    nextProfiles[state.profileName]=text
    local saved,reason=writeIndex(nextProfiles,state.profileName)
    if not saved then
        if not writer then state.profiles=nextProfiles;if state.refreshProfileUI then state.refreshProfileUI()end end
        return false,reason
    end
    state.profiles=nextProfiles;lastSaved=signature;pending=nil
    local legacyOk=pcall(writer,path,text)
    state.fileInfo.Text=legacyOk and "Конфиг сохранён."or "Профиль сохранён; резервный файл недоступен."
    if state.refreshProfileUI then state.refreshProfileUI()end
    return true
end
local function applyText(text)
    loading=true;local called,valid,reason=pcall(state.importConfig,text);loading=false
    if not called or not valid then return false,"Конфиг отклонён: "..tostring(reason or valid)end
    local ok,_,signature=pcall(currentConfig);if ok then lastSaved=signature;pending=nil end
    return true
end
state.loadConfigFile=function()
    local text=state.profiles[state.profileName]
    if not text and reader then local ok,value=pcall(reader,path);if ok and type(value)=="string"then text=value end end
    if not text then return false,"Сохранённого конфига нет."end
    local ok,reason=applyText(text)
    if ok then state.fileInfo.Text="Конфиг загружен.";if state.refreshProfileUI then state.refreshProfileUI()end end
    return ok,reason
end
state.flushConfig=function()
    if not state.autoSave or loading then return true end
    local ok,_,signature=pcall(currentConfig)
    if ok and signature~=lastSaved then return state.saveConfigFile()end
    return true
end
state.switchProfile=function(name)
    local text=state.profiles[name]
    if not text then return false,"Профиль не найден."end
    local ok,reason=state.flushConfig();if not ok and writer then return false,reason end
    ok,reason=applyText(text);if not ok then return false,reason end
    state.profileName=name
    local saved,saveReason=writeIndex(state.profiles,name)
    if state.refreshProfileUI then state.refreshProfileUI()end
    if not saved then state.fileInfo.Text=saveReason end
    return true
end
state.saveProfileAs=function(name)
    if type(name)~="string"or #name==0 or #name>48 or name:find("[%z\1-\31]")then return false,"Название: 1–48 символов."end
    local count=0;for _ in pairs(state.profiles)do count=count+1 end
    if count>=64 and not state.profiles[name]then return false,"Можно сохранить до 64 профилей."end
    local previous=state.profileName;state.profileName=name
    local ok,reason=state.saveConfigFile()
    if not ok and writer then state.profileName=previous end
    if state.refreshProfileUI then state.refreshProfileUI()end
    return ok,reason
end
if reader then
    local readOk,index=pcall(reader,indexPath)
    if readOk and type(index)=="string"then
        local parsed,decoded=false,nil
        if #index<=4400000 then parsed,decoded=pcall(function()return Http:JSONDecode(index)end)end
        local valid=parsed and type(decoded)=="table"and decoded.schema=="SETERAGE_PROFILES"and decoded.version==1
            and type(decoded.profiles)=="table"and type(decoded.selected)=="string"and #index<=4400000
        local count=0
        if valid then for name,text in pairs(decoded.profiles)do
            count=count+1
            if count>64 or type(name)~="string"or #name<1 or #name>48 or name:find("[%z\1-\31]")or type(text)~="string"or #text>65536 then valid=false;break end
        end end
        if valid and decoded.profiles[decoded.selected]then state.profiles=decoded.profiles;state.profileName=decoded.selected
        else blocked=true;state.fileInfo.Text="Индекс профилей повреждён; файл не перезаписывается."end
    end
    if not next(state.profiles)then
        local ok,text=pcall(reader,path)
        if ok and type(text)=="string"and #text<=65536 then state.profiles.Default=text end
    end
end
local selected=state.profiles[state.profileName]
if selected then
    local decodedOk,decoded=pcall(function()return Http:JSONDecode(selected)end)
    if decodedOk and type(decoded)=="table"and type(decoded.settings)=="table"and decoded.settings.autoLoad==false then
        state.autoLoad=false
        if type(decoded.settings.autoSave)=="boolean"then state.autoSave=decoded.settings.autoSave end
        state.fileInfo.Text="Автозагрузка выключена."
    else local ok,reason=state.loadConfigFile();if not ok then state.fileInfo.Text=reason end end
elseif not reader then state.fileInfo.Text="Файлы недоступны. Используй JSON Import / Export."
else state.fileInfo.Text="Создай первый конфиг через «Сохранить как»."end
local ok,_,signature=pcall(currentConfig);if ok then lastSaved=signature end
if state.refreshProfileUI then state.refreshProfileUI()end
local elapsed=0
connect(RunService.Heartbeat,function(dt)
    if not state.alive or loading or not state.autoSave or not writer then return end
    elapsed=elapsed+dt;if elapsed<0.75 then return end;elapsed=0
    local ok,text,signature=pcall(currentConfig);if not ok then return end
    if signature==lastSaved then pending=nil;return end
    if pending~=signature then pending=signature;pendingAt=os.clock();return end
    if os.clock()-pendingAt>=1 then
        local saved,reason=state.saveConfigFile();if not saved then state.fileInfo.Text=reason;pendingAt=os.clock()+5 end
    end
end)
state.applyStyle()
end
