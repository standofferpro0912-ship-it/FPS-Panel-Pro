--========================================================
-- FPS PANEL - Enhanced UI/UX
-- Only keyboard shortcut: O = Open / Close
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local AIM_RENDER_NAME = "FPSPanel_Aimbot_Render"
local CAMERA_RENDER_NAME = "FPSPanel_Camera_Render"
local MAIN_RENDER_NAME = "FPSPanel_Main_Render"
pcall(function()
    RunService:UnbindFromRenderStep(AIM_RENDER_NAME)
    RunService:UnbindFromRenderStep(CAMERA_RENDER_NAME)
    RunService:UnbindFromRenderStep(MAIN_RENDER_NAME)
end)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    local old = PlayerGui:FindFirstChild("FPSPanel")
    if old then old:Destroy() end
    local oldHUD = PlayerGui:FindFirstChild("FPSClientHUD")
    if oldHUD then oldHUD:Destroy() end
    local oldColor = game:GetService("Lighting"):FindFirstChild("FPSPanelLocalColor")
    if oldColor then oldColor:Destroy() end
    local oldESP = PlayerGui:FindFirstChild("FPSESPOverlay")
    if oldESP then oldESP:Destroy() end
end)

local graphicsDirty=true
local particleReductionDirty=true

local Config = {
    Aimbot = false,
    ESP = false,
    Speed = false,
    NoClip = false,
    Invisibility = false,
    AimFOV = 180,
    MaxAimDistance = 150,
    SpeedValue = 32,

    -- Extra client-only features
    FOV = 80,
    FullBright = false,
    NoFog = false,
    Crosshair = true,
    CrosshairSize = 8,
    CrosshairGap = 4,
    CrosshairThickness = 2,
    InfiniteJump = false,
    ThirdPerson = false,
    CameraBob = true,
    FPSCounter = true,
    PingCounter = true,
    Coordinates = false,
    LowGraphics = false,
    TeamCheck = false,
    AimSmooth = false,
    AimSmoothness = 8,
    AimPrediction = false,
    AimPredictionAmount = 0.08,
    AimSticky = false,
    AimDeadzone = 0,
    AimTargetPart = "Head",
    AimTargetLock = true, -- keep one target while it remains valid; prevents target flicker
    AimRetargetDelay = 0, -- seconds to wait before acquiring a different target after loss
    AimTargetMode = "ClosestToCursor",
    PersistenceEnabled = true,
    PersistenceFile = "FPSPanel_profiles.json",
    ActiveProfile = "Default",

    -- ESP 5.0
    ESPBoxes = true,
    ESPTracers = true,
    ESPSkeleton = true,
    ESPNames = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPOffscreen = true,
    ESPHeadDot = false,
    ESPTeamColor = true,
    ESPMaxDistance = 600,
    ESPUpdateRate = 0.06,

    AutoSprint = false,
    FOVKick = false,
    FOVKickAmount = 8,
    CameraShake = false,
    CameraShakeAmount = 0.15,
    ReduceParticles = false,
    DisablePostFX = false,
    Saturation = 0,
    Contrast = 0,
    ColorBoost = 0,
    LocalTime = false,
    PanelKey = Enum.KeyCode.O,

    --====================================================
    -- ENHANCEMENT PACK 7.0 DEFAULTS
    --====================================================
    ThemeName = "Night Purple",
    CustomAccentR = 130,
    CustomAccentG = 92,
    CustomAccentB = 255,
    UseCustomAccent = false,

    ESPBoxStyle = "Corners",
    ESPLineStyle = "Bottom",
    ESPSkeletonThickness = 2,
    ESPJointSize = 4,
    ESPFade = true,
    ESPFadeDistance = 600,
    ESPHealthBar = true,
    ESPNameOutline = true,
    ESPDistanceUnits = "Studs",
    ESPShowDisplayName = true,
    ESPShowUsername = false,
    ESPShowState = true,

    FOVRing = true,
    FOVRingThickness = 1,
    FOVRingSegments = 48,
    FOVRingAlpha = 0.18,

    Radar = true,
    RadarSize = 150,
    RadarRange = 180,
    RadarRotate = true,
    RadarBlips = true,
    RadarGrid = true,

    Compass = true,
    CompassScale = 1,
    ThreatWarning = true,
    ThreatDistance = 55,
    ThreatPulse = true,
    TargetHUD = true,
    TargetHUDCompact = false,
    DamageFeed = true,
    DamageTextDuration = 0.85,
    DeathFeed = true,
    FeedLimit = 5,
    Watermark = true,
    WatermarkText = "FPS PANEL PRO",
    AdaptiveESP = true,
    AdaptiveRadar = true,
    HUDSafeZone = true,
    HUDOpacity = 0.96,

}

--========================================================
-- SAVED PROFILES / PERSISTENCE
--========================================================
-- Re-execution persistence:
-- 1) Uses executor file APIs when available (readfile/writefile/isfile).
-- 2) Falls back to getgenv() / _G for same-runtime persistence.
-- Multiple named profiles are supported.

local HttpService = game:GetService("HttpService")
local Env = _G

pcall(function()
    if type(getgenv) == "function" then
        Env = getgenv()
    end
end)

Env.FPSPanelProfiles = Env.FPSPanelProfiles or {}

local function ConfigSnapshot()
    local snapshot = {}
    for key, value in pairs(Config) do
        local kind = typeof(value)
        if kind == "boolean" or kind == "number" or kind == "string" then
            snapshot[key] = value
        end
    end
    return snapshot
end

local function ApplySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    for key, value in pairs(snapshot) do
        if Config[key] ~= nil then
            local expected = typeof(Config[key])
            local actual = typeof(value)
            if expected == actual then
                Config[key] = value
            end
        end
    end
end

local function SaveProfilesToDisk()
    if not Config.PersistenceEnabled then
        return false
    end

    if type(writefile) ~= "function" then
        return false
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Env.FPSPanelProfiles)
    end)

    if not ok then
        return false
    end

    return pcall(function()
        writefile(Config.PersistenceFile, encoded)
    end)
end

local function LoadProfilesFromDisk()
    if not Config.PersistenceEnabled then
        return false
    end

    if type(readfile) ~= "function"
        or type(isfile) ~= "function"
        or not isfile(Config.PersistenceFile) then
        return false
    end

    local ok, raw = pcall(function()
        return readfile(Config.PersistenceFile)
    end)

    if not ok or type(raw) ~= "string" or raw == "" then
        return false
    end

    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not decodedOk or type(decoded) ~= "table" then
        return false
    end

    Env.FPSPanelProfiles = decoded
    return true
end

local function SaveProfile(name)
    name = tostring(name or Config.ActiveProfile or "Default")
    Env.FPSPanelProfiles = Env.FPSPanelProfiles or {}
    Env.FPSPanelProfiles[name] = ConfigSnapshot()
    Config.ActiveProfile = name
    Env.FPSPanelLastActiveProfile = name
    local ok = SaveProfilesToDisk()
    return ok
end

local function LoadProfile(name)
    name = tostring(name or "Default")
    local snapshot = Env.FPSPanelProfiles[name]
    if type(snapshot) ~= "table" then
        return false
    end

    ApplySnapshot(snapshot)
    Config.ActiveProfile = name
    return true
end

local function GetProfileNames()
    local names = {}
    for name in pairs(Env.FPSPanelProfiles) do
        table.insert(names, tostring(name))
    end
    table.sort(names)
    return names
end

-- Default profile behavior: load the last active profile on every re-execution.
if Config.PersistenceEnabled then
    LoadProfilesFromDisk()

    local savedActive = Env.FPSPanelLastActiveProfile or Config.ActiveProfile or "Default"

    if not LoadProfile(savedActive) then
        if Env.FPSPanelProfiles.Default then
            LoadProfile("Default")
        else
            SaveProfile("Default")
        end
    end
end

local C = {
    Bg = Color3.fromRGB(9,10,13),
    Surface = Color3.fromRGB(16,17,22),
    Surface2 = Color3.fromRGB(22,23,29),
    Surface3 = Color3.fromRGB(29,30,38),
    Border = Color3.fromRGB(46,48,58),
    Text = Color3.fromRGB(245,245,248),
    Sub = Color3.fromRGB(150,153,163),
    Muted = Color3.fromRGB(94,97,107),
    Accent = Color3.fromRGB(130,92,255),
    Accent2 = Color3.fromRGB(93,63,190),
    Good = Color3.fromRGB(67,204,126),
    Bad = Color3.fromRGB(232,82,88),
}

local function New(class, props, parent)
    local x = Instance.new(class)
    for k,v in pairs(props or {}) do x[k] = v end
    x.Parent = parent
    return x
end
local function Corner(x,r) New("UICorner",{CornerRadius=UDim.new(0,r or 10)},x) end
local function Outline(x,color,thick,trans) New("UIStroke",{Color=color or C.Border,Thickness=thick or 1,Transparency=trans or 0},x) end
local function T(x,props,time)
    TweenService:Create(x,TweenInfo.new(time or .16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
end

--========================================================
-- ROOT + RESPONSIVE SCALE
--========================================================
local Gui = New("ScreenGui",{
    Name="FPSPanel",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PlayerGui)
local Scale = New("UIScale",{},Gui)
local function Resize()
    local cam=workspace.CurrentCamera
    if cam then
        local s=math.min(cam.ViewportSize.X,cam.ViewportSize.Y)
        Scale.Scale=math.clamp(s/700,.62,1)
    end
end
Resize()
local camConn
local function BindCamera()
    if camConn then camConn:Disconnect() end
    local cam=workspace.CurrentCamera
    if not cam then return end
    Resize()
    camConn=cam:GetPropertyChangedSignal("ViewportSize"):Connect(Resize)
end
BindCamera()
local currentCamConn=workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.defer(BindCamera) end)

--========================================================
-- FLOATING OPEN/CLOSE BUTTON
--========================================================
local Open = New("TextButton",{
    Size=UDim2.fromOffset(100,42),Position=UDim2.new(0,15,.5,-21),
    BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,
},Gui)
Corner(Open,12); Outline(Open,C.Border)
local Dot=New("Frame",{Size=UDim2.fromOffset(7,7),Position=UDim2.new(0,13,.5,-3),BackgroundColor3=C.Accent,BorderSizePixel=0},Open); Corner(Dot,8)
local OpenLabel=New("TextLabel",{Size=UDim2.new(1,-32,1,0),Position=UDim2.fromOffset(27,0),BackgroundTransparency=1,Text="OPEN  [O]",TextColor3=C.Text,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Open)

--========================================================
-- WINDOW
--========================================================
local Main=New("Frame",{
    Size=UDim2.fromOffset(470,545),Position=UDim2.new(.5,-235,.5,-272.5),
    BackgroundColor3=C.Bg,BorderSizePixel=0,ClipsDescendants=true,
},Gui)
Corner(Main,18); Outline(Main,C.Border)

local Header=New("Frame",{Size=UDim2.new(1,0,0,70),BackgroundColor3=C.Surface,BorderSizePixel=0},Main)
New("Frame",{Size=UDim2.fromOffset(3,50),Position=UDim2.fromOffset(10,10),BackgroundColor3=C.Accent,BorderSizePixel=0},Header); Corner(Header:FindFirstChildOfClass("Frame"),4)
New("TextLabel",{Size=UDim2.new(1,-145,0,26),Position=UDim2.fromOffset(25,10),BackgroundTransparency=1,Text="FPS PANEL",TextColor3=C.Text,TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Header)
New("TextLabel",{Size=UDim2.new(1,-145,0,17),Position=UDim2.fromOffset(26,37),BackgroundTransparency=1,Text="ADVANCED CONTROL CENTER",TextColor3=C.Sub,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Header)
New("TextLabel",{Size=UDim2.fromOffset(78,18),Position=UDim2.new(1,-122,0,11),BackgroundTransparency=1,Text="O  MENU",TextColor3=C.Sub,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right},Header)
local Close=New("TextButton",{Size=UDim2.fromOffset(32,32),Position=UDim2.new(1,-43,.5,-2),BackgroundColor3=C.Surface3,Text="×",TextColor3=C.Sub,TextSize=21,Font=Enum.Font.Gotham,AutoButtonColor=false,BorderSizePixel=0},Header); Corner(Close,9)

-- draggable header
local dragging=false; local dragStart; local startPos
Header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; startPos=Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-dragStart
        Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

--========================================================
-- SIDEBAR + PAGES
--========================================================
local Sidebar=New("Frame",{Size=UDim2.new(0,132,1,-82),Position=UDim2.fromOffset(10,76),BackgroundColor3=C.Surface,BorderSizePixel=0},Main); Corner(Sidebar,14); Outline(Sidebar,C.Border)
New("TextLabel",{Size=UDim2.new(1,-20,0,22),Position=UDim2.fromOffset(10,10),BackgroundTransparency=1,Text="SECTIONS",TextColor3=C.Muted,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},Sidebar)
local TabList=New("Frame",{Size=UDim2.new(1,-14,1,-40),Position=UDim2.fromOffset(7,36),BackgroundTransparency=1},Sidebar)
New("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},TabList)
local Area=New("Frame",{Size=UDim2.new(1,-152,1,-82),Position=UDim2.fromOffset(145,76),BackgroundTransparency=1,ClipsDescendants=true},Main)

local tabDefs={
    {id="Combat",label="Combat",icon="⊙",desc="Targeting"},
    {id="Visuals",label="Visuals",icon="◉",desc="ESP"},
    {id="Movement",label="Movement",icon="↗",desc="Speed"},
    {id="Player",label="Player",icon="●",desc="Character"},
    {id="Client",label="Client",icon="◇",desc="Local only"},
    {id="Performance",label="Performance",icon="≋",desc="FPS"},
    {id="Camera",label="Camera",icon="◌",desc="View"},
    {id="Interface",label="Interface",icon="▦",desc="HUD"},
    {id="Graphics",label="Graphics",icon="◈",desc="Visuals"},
    {id="Utility",label="Utility",icon="◆",desc="Quality of life"},
    {id="Settings",label="Settings",icon="⚙",desc="Interface"},
}
local Tabs={}; local Pages={}; local CurrentTab="Combat"; local Refreshers={}

local function Page(id,title,desc)
    local p=New("ScrollingFrame",{Name=id.."Page",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Accent,ScrollBarImageTransparency=.25,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false},Area)
    New("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,7),PaddingBottom=UDim.new(0,10)},p)
    New("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},p)
    local h=New("Frame",{Size=UDim2.new(1,0,0,52),BackgroundTransparency=1},p)
    New("TextLabel",{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},h)
    New("TextLabel",{Size=UDim2.new(1,0,0,18),Position=UDim2.fromOffset(0,29),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},h)
    Pages[id]=p; return p
end
for n,d in ipairs(tabDefs) do
    local b=New("TextButton",{Size=UDim2.new(1,0,0,43),BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=n},TabList); Corner(b,10)
    local bar=New("Frame",{Size=UDim2.fromOffset(3,24),Position=UDim2.new(0,0,.5,-12),BackgroundColor3=C.Accent,BackgroundTransparency=1,BorderSizePixel=0},b); Corner(bar,4)
    local icon=New("TextLabel",{Size=UDim2.fromOffset(26,43),Position=UDim2.fromOffset(9,0),BackgroundTransparency=1,Text=d.icon,TextColor3=C.Sub,TextSize=15,Font=Enum.Font.GothamBold},b)
    local lab=New("TextLabel",{Size=UDim2.new(1,-41,1,0),Position=UDim2.fromOffset(38,0),BackgroundTransparency=1,Text=d.label,TextColor3=C.Sub,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},b)
    Tabs[d.id]={b=b,bar=bar,icon=icon,lab=lab}
end
for _,d in ipairs(tabDefs) do Page(d.id,d.label,d.desc) end

local function SelectTab(id)
    CurrentTab=id
    for k,t in pairs(Tabs) do
        local active=k==id
        T(t.b,{BackgroundColor3=active and C.Surface3 or C.Surface},.12)
        T(t.icon,{TextColor3=active and C.Text or C.Sub},.12)
        T(t.lab,{TextColor3=active and C.Text or C.Sub},.12)
        T(t.bar,{BackgroundTransparency=active and 0 or 1},.12)
    end
    for k,p in pairs(Pages) do p.Visible=(k==id) end
end
for id,t in pairs(Tabs) do
    t.b.Activated:Connect(function() SelectTab(id) end)
    t.b.MouseEnter:Connect(function() if CurrentTab~=id then T(t.b,{BackgroundColor3=C.Surface2},.1) end end)
    t.b.MouseLeave:Connect(function() if CurrentTab~=id then T(t.b,{BackgroundColor3=C.Surface},.1) end end)
end

--========================================================
-- COMPONENTS
--========================================================
local function Section(p,title,sub)
    local f=New("Frame",{Size=UDim2.new(1,0,0,45),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(f,11); Outline(f,C.Border)
    New("TextLabel",{Size=UDim2.new(1,-18,0,19),Position=UDim2.fromOffset(10,6),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},f)
    New("TextLabel",{Size=UDim2.new(1,-18,0,14),Position=UDim2.fromOffset(10,25),BackgroundTransparency=1,Text=sub or "",TextColor3=C.Muted,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},f)
    return f
end
local function Toggle(p,title,desc,get,set)
    local r=New("Frame",{Size=UDim2.new(1,0,0,66),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,11); Outline(r,C.Border)
    New("TextLabel",{Size=UDim2.new(1,-85,0,21),Position=UDim2.fromOffset(12,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    New("TextLabel",{Size=UDim2.new(1,-85,0,19),Position=UDim2.fromOffset(12,31),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},r)
    local sw=New("TextButton",{Size=UDim2.fromOffset(48,26),Position=UDim2.new(1,-60,.5,-13),BackgroundColor3=C.Surface3,Text="",AutoButtonColor=false,BorderSizePixel=0},r); Corner(sw,14)
    local knob=New("Frame",{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.Sub,BorderSizePixel=0},sw); Corner(knob,10)
    local function refresh()
        local on=get()
        T(sw,{BackgroundColor3=on and C.Accent or C.Surface3},.12)
        T(knob,{Position=on and UDim2.new(1,-23,0,3) or UDim2.fromOffset(3,3),BackgroundColor3=on and Color3.new(1,1,1) or C.Sub},.12)
    end
    sw.Activated:Connect(function() set(not get()); refresh(); SaveProfile(Config.ActiveProfile) end)
    refresh(); table.insert(Refreshers,refresh); return refresh
end
local function Slider(p,title,desc,min,max,step,get,set)
    local r=New("Frame",{Size=UDim2.new(1,0,0,87),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,11); Outline(r,C.Border)
    New("TextLabel",{Size=UDim2.new(1,-70,0,20),Position=UDim2.fromOffset(12,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    local val=New("TextLabel",{Size=UDim2.fromOffset(58,20),Position=UDim2.new(1,-70,0,8),BackgroundTransparency=1,TextColor3=C.Accent,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right},r)
    New("TextLabel",{Size=UDim2.new(1,-24,0,16),Position=UDim2.fromOffset(12,29),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},r)
    local tr=New("Frame",{Size=UDim2.new(1,-24,0,7),Position=UDim2.new(0,12,1,-20),BackgroundColor3=C.Surface3,BorderSizePixel=0},r); Corner(tr,6)
    local fill=New("Frame",{Size=UDim2.new(),BackgroundColor3=C.Accent,BorderSizePixel=0},tr); Corner(fill,6)
    local knob=New("TextButton",{Size=UDim2.fromOffset(18,18),Position=UDim2.new(0,-9,.5,-9),BackgroundColor3=Color3.new(1,1,1),Text="",AutoButtonColor=false,BorderSizePixel=0},tr); Corner(knob,9); Outline(knob,C.Accent)
    local slide=false
    local function setX(x)
        local a=math.clamp((x-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        local v=math.floor(((min+(max-min)*a)/step)+.5)*step
        set(math.clamp(v,min,max))
    end
    local function refresh()
        local v=get(); local a=(v-min)/(max-min)
        val.Text=tostring(v); fill.Size=UDim2.new(a,0,1,0); knob.Position=UDim2.new(a,-9,.5,-9)
    end
    tr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then slide=true; setX(i.Position.X); refresh() end end)
    UserInputService.InputChanged:Connect(function(i) if slide and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setX(i.Position.X); refresh() end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then slide=false; SaveProfile(Config.ActiveProfile) end end)
    refresh(); table.insert(Refreshers,refresh); return refresh
end
local function Info(p,title,desc,accent)
    local r=New("Frame",{Size=UDim2.new(1,0,0,57),BackgroundColor3=C.Surface,BorderSizePixel=0},p); Corner(r,11); Outline(r,C.Border)
    local line=New("Frame",{Size=UDim2.fromOffset(3,31),Position=UDim2.fromOffset(10,13),BackgroundColor3=accent or C.Accent,BorderSizePixel=0},r); Corner(line,3)
    New("TextLabel",{Size=UDim2.new(1,-38),Position=UDim2.fromOffset(20,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},r)
    New("TextLabel",{Size=UDim2.new(1,-38),Position=UDim2.fromOffset(20,28),BackgroundTransparency=1,Text=desc,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},r)
    return r
end
local function Action(p,title,desc,callback,color)
    local b=New("TextButton",{Size=UDim2.new(1,0,0,57),BackgroundColor3=C.Surface,Text="",AutoButtonColor=false,BorderSizePixel=0,Active=true},p); Corner(b,11); Outline(b,C.Border)
    local line=New("Frame",{Size=UDim2.fromOffset(3,31),Position=UDim2.fromOffset(10,13),BackgroundColor3=color or C.Accent,BorderSizePixel=0},b); Corner(line,3)
    New("TextLabel",{Size=UDim2.new(1,-55,0,21),Position=UDim2.fromOffset(20,8),BackgroundTransparency=1,Text=title,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=false},b)
    local descLabel=New("TextLabel",{Size=UDim2.new(1,-55,0,19),Position=UDim2.fromOffset(20,28),BackgroundTransparency=1,Text="",TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Active=false},b)
    local function refresh()
        local value = type(desc)=="function" and desc() or desc
        descLabel.Text=tostring(value or "")
    end
    refresh()
    local a=New("TextLabel",{Size=UDim2.fromOffset(24,57),Position=UDim2.new(1,-31,0,0),BackgroundTransparency=1,Text="›",TextColor3=C.Muted,TextSize=22,Font=Enum.Font.Gotham,Active=false},b)
    b.Activated:Connect(function()
        callback()
        refresh()
    end)
    b.MouseEnter:Connect(function() T(b,{BackgroundColor3=C.Surface2},.1); T(a,{TextColor3=C.Text},.1) end)
    b.MouseLeave:Connect(function() T(b,{BackgroundColor3=C.Surface},.1); T(a,{TextColor3=C.Muted},.1) end)
    table.insert(Refreshers,refresh)
    return b,refresh
end

--========================================================
-- FORWARD DECLARATIONS
--========================================================
-- Some UI callbacks are created before their implementations below.
-- Keep them as upvalues so callbacks never resolve to a missing global.
local UpdateESP
local ClearAllESP
local ResetAimState
local Invisibility
local espObjects

--========================================================
-- BUILD TABS
--========================================================
Section(Pages.Combat,"TARGETING","Aim behaviour and target selection")
Toggle(Pages.Combat,"Aimbot","Tracks the closest visible target inside your FOV.",function() return Config.Aimbot end,function(v) Config.Aimbot=v; if not v then ResetAimState() end end)
Slider(Pages.Combat,"Aim FOV","Screen-space target radius.",50,500,10,function() return Config.AimFOV end,function(v) Config.AimFOV=v end)
Slider(Pages.Combat,"Max Distance","Maximum target distance.",25,500,5,function() return Config.MaxAimDistance end,function(v) Config.MaxAimDistance=v end)
Toggle(Pages.Combat,"Team Check","Prevents aimbot from selecting teammates using team/faction checks.",function() return Config.TeamCheck end,function(v) Config.TeamCheck=v end)
Action(Pages.Combat,"Aim Body Part",function()
    return "Target: "..tostring(Config.AimTargetPart).." • tap to cycle."
end,function()
    local parts={"Head","UpperTorso","Torso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg","HumanoidRootPart"}
    local i=table.find(parts,Config.AimTargetPart) or 1
    Config.AimTargetPart=parts[(i % #parts)+1]
    ResetAimState()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Action(Pages.Combat,"Target Priority",function()
    return "Mode: "..tostring(Config.AimTargetMode).." • tap to cycle."
end,function()
    local modes={"ClosestToCursor","ClosestToPlayer","LowestHealth"}
    local i=table.find(modes,Config.AimTargetMode) or 1
    Config.AimTargetMode=modes[(i % #modes)+1]
    ResetAimState()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Toggle(Pages.Combat,"Stable Target Lock","Keeps the current valid target and prevents target flicker.",function() return Config.AimTargetLock end,function(v) Config.AimTargetLock=v; ResetAimState() end)
Slider(Pages.Combat,"Reacquire Delay","Delay before selecting another target after loss.",0,0.30,0.01,function() return Config.AimRetargetDelay end,function(v) Config.AimRetargetDelay=v end)
Toggle(Pages.Combat,"Smooth Aim","Moves the camera toward the target instead of snapping instantly.",function() return Config.AimSmooth end,function(v) Config.AimSmooth=v end)
Slider(Pages.Combat,"Aim Smoothness","Higher values feel faster and more responsive.",1,20,1,function() return Config.AimSmoothness end,function(v) Config.AimSmoothness=v end)
Info(Pages.Combat,"Target validation","Requires a live, visible and on-screen player.",C.Good)

Section(Pages.Visuals,"PLAYER ESP 5.0","Premium tactical ESP — clean, responsive and independently switchable")
Toggle(Pages.Visuals,"ESP","Master switch for the complete player ESP system.",function() return Config.ESP end,function(v)
    Config.ESP=v
    if v then task.defer(function() pcall(UpdateESP) end) else pcall(ClearAllESP) end
end)
Toggle(Pages.Visuals,"2D Boxes","Corner boxes locked to the projected character bounds.",function() return Config.ESPBoxes end,function(v) Config.ESPBoxes=v; task.defer(function() pcall(UpdateESP) end) end)
Toggle(Pages.Visuals,"Tracers","Screen-space lines from the bottom-center to each visible target.",function() return Config.ESPTracers end,function(v) Config.ESPTracers=v; task.defer(function() pcall(UpdateESP) end) end)
Toggle(Pages.Visuals,"Skeleton","Lightweight R6/R15 bone overlay.",function() return Config.ESPSkeleton end,function(v) Config.ESPSkeleton=v; task.defer(function() pcall(UpdateESP) end) end)
Toggle(Pages.Visuals,"Nameplates","Player name, distance and health in a compact card.",function() return Config.ESPNames or Config.ESPHealth or Config.ESPDistance end,function(v)
    Config.ESPNames=v; Config.ESPHealth=v; Config.ESPDistance=v; task.defer(function() pcall(UpdateESP) end)
end)
Toggle(Pages.Visuals,"Off-Screen Arrows","Directional indicators for players outside the viewport.",function() return Config.ESPOffscreen end,function(v) Config.ESPOffscreen=v; task.defer(function() pcall(UpdateESP) end) end)
Toggle(Pages.Visuals,"Head Dot","Small precise head marker.",function() return Config.ESPHeadDot end,function(v) Config.ESPHeadDot=v; task.defer(function() pcall(UpdateESP) end) end)
Toggle(Pages.Visuals,"Team Colors","Use Roblox TeamColor for each player's ESP.",function() return Config.ESPTeamColor end,function(v) Config.ESPTeamColor=v; task.defer(function() pcall(UpdateESP) end) end)
Slider(Pages.Visuals,"Max Distance","Do not render ESP beyond this range.",50,1500,10,function() return Config.ESPMaxDistance end,function(v) Config.ESPMaxDistance=v; task.defer(function() pcall(UpdateESP) end) end)
Info(Pages.Visuals,"ESP 5.0","Independent screen-space primitives, deterministic cleanup, R6/R15 support, respawn-safe object ownership and mobile-safe scaling.",C.Good)

Section(Pages.Movement,"MOVEMENT","Movement and collision controls")
Toggle(Pages.Movement,"Speed","Changes Humanoid WalkSpeed while enabled.",function() return Config.Speed end,function(v) Config.Speed=v end)
Slider(Pages.Movement,"WalkSpeed","Movement speed value.",1,150,1,function() return Config.SpeedValue end,function(v) Config.SpeedValue=v end)
Toggle(Pages.Movement,"NoClip","Disables character collision while enabled.",function() return Config.NoClip end,function(v) Config.NoClip=v end)
Toggle(Pages.Movement,"Infinite Jump","Allows jump requests while airborne on the local client.",function() return Config.InfiniteJump end,function(v) Config.InfiniteJump=v end)

Section(Pages.Player,"CHARACTER","Character presentation")
Toggle(Pages.Player,"Invisibility","Makes your character locally transparent on this client.",function() return Config.Invisibility end,function(v) Config.Invisibility=v; Invisibility(v) end)
Info(Pages.Player,"Client-side","Invisibility uses local transparency and is not server-authoritative.",C.Accent)

Section(Pages.Client,"CAMERA","Local camera controls")
Slider(Pages.Client,"Field of View","Local camera field of view.",40,120,1,function() return Config.FOV end,function(v) Config.FOV=v end)
Toggle(Pages.Client,"Third Person","Switches the local camera to a simple third-person view.",function() return Config.ThirdPerson end,function(v) Config.ThirdPerson=v end)
Toggle(Pages.Client,"Camera Bob","Keeps normal first-person camera movement enabled.",function() return Config.CameraBob end,function(v) Config.CameraBob=v end)

Section(Pages.Client,"CROSSHAIR","Custom local crosshair")
Toggle(Pages.Client,"Crosshair","Shows a clean custom crosshair in the center of the screen.",function() return Config.Crosshair end,function(v) Config.Crosshair=v end)
Slider(Pages.Client,"Crosshair Size","Length of each crosshair arm.",4,20,1,function() return Config.CrosshairSize end,function(v) Config.CrosshairSize=v end)
Slider(Pages.Client,"Crosshair Gap","Center gap size.",0,14,1,function() return Config.CrosshairGap end,function(v) Config.CrosshairGap=v end)
Slider(Pages.Client,"Crosshair Thickness","Line thickness.",1,5,1,function() return Config.CrosshairThickness end,function(v) Config.CrosshairThickness=v end)

Section(Pages.Client,"LOCAL VISUALS","Client-only lighting and world presentation")
Toggle(Pages.Client,"Full Bright","Removes local darkness by increasing client lighting.",function() return Config.FullBright end,function(v) Config.FullBright=v end)
Toggle(Pages.Client,"No Fog","Extends local fog distance to make the map clearer.",function() return Config.NoFog end,function(v) Config.NoFog=v end)

Section(Pages.Performance,"MONITOR","Live client performance information")
Toggle(Pages.Performance,"FPS Counter","Shows your current client FPS.",function() return Config.FPSCounter end,function(v) Config.FPSCounter=v end)
Toggle(Pages.Performance,"Ping Counter","Shows the local player's reported ping.",function() return Config.PingCounter end,function(v) Config.PingCounter=v end)
Toggle(Pages.Performance,"Coordinates","Shows your current character coordinates.",function() return Config.Coordinates end,function(v) Config.Coordinates=v end)
Toggle(Pages.Performance,"Safe Low Graphics","Cheap, reversible local optimization; does not scan the whole workspace.",function() return Config.LowGraphics end,function(v) Config.LowGraphics=v end)
Info(Pages.Performance,"Performance first","All options in this tab are designed to affect the local client only.",C.Good)

Section(Pages.Settings,"INTERFACE","Quality-of-life controls")
Info(Pages.Settings,"Keyboard shortcut","O is the ONLY keyboard shortcut: open / close the panel.",C.Accent)
Action(Pages.Settings,"Center panel","Restore the window to the center of the screen.",function() Main.Position=UDim2.new(.5,-235,.5,-272.5) end,C.Good)
Action(Pages.Settings,"Reset features","Turn every gameplay feature off and restore movement state.",function()
    Config.Aimbot=false; Config.ESP=false; Config.Speed=false; Config.NoClip=false; Config.Invisibility=false
    ResetAimState()
    Invisibility(false)
    for _,refresh in ipairs(Refreshers) do refresh() end
    SaveProfile(Config.ActiveProfile)
end,C.Bad)
Section(Pages.Settings,"PROFILES","Keep your preferred panel setup between re-executions")
Action(Pages.Settings,"Save Profile",function()
    return "Save the current configuration as "..tostring(Config.ActiveProfile).."."
end,function()
    SaveProfile(Config.ActiveProfile)
end,C.Good)
Action(Pages.Settings,"Load Profile",function()
    return "Load the saved "..tostring(Config.ActiveProfile).." configuration."
end,function()
    if LoadProfile(Config.ActiveProfile) then
        Env.FPSPanelLastActiveProfile=Config.ActiveProfile
        for _,refresh in ipairs(Refreshers) do refresh() end
        task.defer(UpdateESP)
    end
end,C.Accent)
Action(Pages.Settings,"New Profile","Switch profile name by editing ActiveProfile in the Config block, then save.",function()
    SaveProfile(Config.ActiveProfile)
end,C.Accent)
Info(Pages.Settings,"Persistence","Uses file APIs when available; otherwise uses the current runtime environment.",C.Good)
Action(Pages.Settings,"Mobile optimized","Responsive scaling, touch toggles, sliders, scrolling and drag support.",function() Resize() end,C.Good)


--========================================================
-- ADDITIONAL CLIENT FEATURES
--========================================================

Section(Pages.Combat,"AIM ADVANCED","More precise local target handling")
Toggle(Pages.Combat,"Sticky Aim","Keeps the selected target while it remains valid.",function() return Config.AimSticky end,function(v) Config.AimSticky=v end)
Toggle(Pages.Combat,"Prediction","Uses target velocity for a small local lead.",function() return Config.AimPrediction end,function(v) Config.AimPrediction=v end)
Slider(Pages.Combat,"Prediction","Prediction amount.",0,0.30,0.01,function() return Config.AimPredictionAmount end,function(v) Config.AimPredictionAmount=v end)
Slider(Pages.Combat,"Deadzone","Ignore tiny aim corrections.",0,30,1,function() return Config.AimDeadzone end,function(v) Config.AimDeadzone=v end)
Info(Pages.Combat,"Smoothness fixed","Smoothing is now frame-rate independent.",C.Good)

Section(Pages.Movement,"MOVEMENT EXTRAS","More local quality-of-life controls")
Toggle(Pages.Movement,"Auto Sprint","Marks the client as sprint-ready while moving.",function() return Config.AutoSprint end,function(v) Config.AutoSprint=v end)

Section(Pages.Client,"CAMERA FEEL","Extra local camera effects")
Toggle(Pages.Client,"FOV Kick","Adds a small movement-based FOV pulse.",function() return Config.FOVKick end,function(v) Config.FOVKick=v end)
Slider(Pages.Client,"FOV Kick Amount","Maximum extra FOV.",0,20,1,function() return Config.FOVKickAmount end,function(v) Config.FOVKickAmount=v end)
Toggle(Pages.Client,"Camera Shake","Adds subtle local camera feedback.",function() return Config.CameraShake end,function(v) Config.CameraShake=v end)
Slider(Pages.Client,"Shake Amount","Camera shake strength.",0,1,0.01,function() return Config.CameraShakeAmount end,function(v) Config.CameraShakeAmount=v end)

Section(Pages.Camera,"CAMERA","Dedicated camera controls")
Slider(Pages.Camera,"Field of View","Local camera FOV.",40,120,1,function() return Config.FOV end,function(v) Config.FOV=v end)
Toggle(Pages.Camera,"Third Person","Use a local third-person view.",function() return Config.ThirdPerson end,function(v) Config.ThirdPerson=v end)
Toggle(Pages.Camera,"Camera Bob","Add subtle movement bob.",function() return Config.CameraBob end,function(v) Config.CameraBob=v end)
Info(Pages.Camera,"Smooth aim","Uses frame-rate independent interpolation.",C.Good)

Section(Pages.Interface,"CROSSHAIR","Local reticle and HUD")
Toggle(Pages.Interface,"Crosshair","Show a custom local crosshair.",function() return Config.Crosshair end,function(v) Config.Crosshair=v end)
Slider(Pages.Interface,"Size","Crosshair arm length.",4,24,1,function() return Config.CrosshairSize end,function(v) Config.CrosshairSize=v end)
Slider(Pages.Interface,"Gap","Crosshair center gap.",0,20,1,function() return Config.CrosshairGap end,function(v) Config.CrosshairGap=v end)
Slider(Pages.Interface,"Thickness","Crosshair thickness.",1,6,1,function() return Config.CrosshairThickness end,function(v) Config.CrosshairThickness=v end)
Toggle(Pages.Interface,"FPS Counter","Show live client FPS.",function() return Config.FPSCounter end,function(v) Config.FPSCounter=v end)
Toggle(Pages.Interface,"Ping Counter","Show local network ping.",function() return Config.PingCounter end,function(v) Config.PingCounter=v end)
Toggle(Pages.Interface,"Coordinates","Show character coordinates.",function() return Config.Coordinates end,function(v) Config.Coordinates=v end)
Toggle(Pages.Interface,"Local Time","Show local time.",function() return Config.LocalTime end,function(v) Config.LocalTime=v end)

Section(Pages.Graphics,"LIGHTING","Client-side visual improvements")
Toggle(Pages.Graphics,"Full Bright","Brighten local lighting.",function() return Config.FullBright end,function(v) Config.FullBright=v end)
Toggle(Pages.Graphics,"No Fog","Extend local fog distance.",function() return Config.NoFog end,function(v) Config.NoFog=v end)
Toggle(Pages.Graphics,"Reduce Particles","Disable common local particles, beams and trails.",function() return Config.ReduceParticles end,function(v) Config.ReduceParticles=v; particleReductionDirty=true end)
Toggle(Pages.Graphics,"Disable Post FX","Disable common local post-processing.",function() return Config.DisablePostFX end,function(v) Config.DisablePostFX=v; graphicsDirty=true end)
Slider(Pages.Graphics,"Saturation","Local saturation.",-1,1,0.05,function() return Config.Saturation end,function(v) Config.Saturation=v; graphicsDirty=true end)
Slider(Pages.Graphics,"Contrast","Local contrast.",-1,1,0.05,function() return Config.Contrast end,function(v) Config.Contrast=v; graphicsDirty=true end)
Slider(Pages.Graphics,"Color Boost","Local brightness boost.",-0.5,0.5,0.05,function() return Config.ColorBoost end,function(v) Config.ColorBoost=v; graphicsDirty=true end)

Section(Pages.Utility,"UTILITY","Small client-only quality-of-life tools")
Toggle(Pages.Utility,"Infinite Jump","Allow repeated local jump requests.",function() return Config.InfiniteJump end,function(v) Config.InfiniteJump=v end)
Toggle(Pages.Utility,"Auto Sprint","Keep the player sprint-ready locally.",function() return Config.AutoSprint end,function(v) Config.AutoSprint=v end)
Info(Pages.Utility,"Client-only","These controls are designed for local presentation and convenience.",C.Accent)

SelectTab("Combat")

--========================================================
-- OPEN / CLOSE
--========================================================
local visible=true
local openPos=Main.Position
local closedPos=UDim2.new(openPos.X.Scale,openPos.X.Offset,openPos.Y.Scale,openPos.Y.Offset+14)
local function SetVisible(v)
    visible=v
    if v then
        Main.Visible=true; Main.Position=closedPos; Main.BackgroundTransparency=1
        T(Main,{Position=openPos,BackgroundTransparency=0},.19)
        OpenLabel.Text="CLOSE  [O]"; Dot.BackgroundColor3=C.Good
    else
        local tw=TweenService:Create(Main,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=closedPos,BackgroundTransparency=1})
        tw.Completed:Connect(function() if not visible then Main.Visible=false end end); tw:Play()
        OpenLabel.Text="OPEN  [O]"; Dot.BackgroundColor3=C.Accent
    end
end
Open.Activated:Connect(function() SetVisible(not visible) end)
Close.Activated:Connect(function() SetVisible(false) end)
Open.MouseEnter:Connect(function() T(Open,{BackgroundColor3=C.Surface2},.1) end); Open.MouseLeave:Connect(function() T(Open,{BackgroundColor3=C.Surface},.1) end)
Close.MouseEnter:Connect(function() T(Close,{BackgroundColor3=C.Bad,TextColor3=Color3.new(1,1,1)},.1) end); Close.MouseLeave:Connect(function() T(Close,{BackgroundColor3=C.Surface3,TextColor3=C.Sub},.1) end)

-- ONLY hotkey: O
ContextActionService:BindActionAtPriority("FPSPanel_OpenClose",function(_,state)
    if state==Enum.UserInputState.Begin then SetVisible(not visible) end
    return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value,Config.PanelKey)


--========================================================
-- CLIENT HUD
--========================================================
local ClientHUD=New("ScreenGui",{Name="FPSClientHUD",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=101,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},PlayerGui)

local Crosshair=New("Frame",{Name="Crosshair",Size=UDim2.fromOffset(1,1),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1},ClientHUD)
local ChTop=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair); local ChBottom=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair)
local ChLeft=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair); local ChRight=New("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},Crosshair)
local Status=New("TextLabel",{Size=UDim2.fromOffset(210,58),Position=UDim2.new(1,-225,0,14),BackgroundTransparency=.35,BackgroundColor3=C.Surface,TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text=""},ClientHUD); Corner(Status,10); Outline(Status,C.Border)
New("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingTop=UDim.new(0,7),PaddingRight=UDim.new(0,6)},Status)

local function UpdateCrosshair()
    Crosshair.Visible=Config.Crosshair
    local size=Config.CrosshairSize; local gap=Config.CrosshairGap; local thick=Config.CrosshairThickness
    ChTop.Size=UDim2.fromOffset(thick,size); ChTop.Position=UDim2.new(.5,-thick/2,0,-gap-size)
    ChBottom.Size=UDim2.fromOffset(thick,size); ChBottom.Position=UDim2.new(.5,-thick/2,0,gap)
    ChLeft.Size=UDim2.fromOffset(size,thick); ChLeft.Position=UDim2.new(0,-gap-size,.5,-thick/2)
    ChRight.Size=UDim2.fromOffset(size,thick); ChRight.Position=UDim2.new(0,gap,.5,-thick/2)
end
UpdateCrosshair()

local LightBackup={Ambient=nil,Brightness=nil,ClockTime=nil,FogEnd=nil,FogStart=nil,GlobalShadows=nil}
local TerrainBackup={WaveSize=nil,WaveSpeed=nil,Reflectance=nil,Transparency=nil}
local ParticleBackup={}
local Lighting=game:GetService("Lighting")
local function ApplyLocalVisuals()
    if Config.FullBright then
        if LightBackup.Ambient==nil then
            LightBackup.Ambient=Lighting.Ambient; LightBackup.Brightness=Lighting.Brightness; LightBackup.ClockTime=Lighting.ClockTime; LightBackup.GlobalShadows=Lighting.GlobalShadows
        end
        Lighting.Ambient=Color3.new(1,1,1); Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false
    elseif LightBackup.Ambient~=nil then
        Lighting.Ambient=LightBackup.Ambient; Lighting.Brightness=LightBackup.Brightness; Lighting.ClockTime=LightBackup.ClockTime; Lighting.GlobalShadows=LightBackup.GlobalShadows
        LightBackup.Ambient=nil
    end
    if Config.NoFog then
        if LightBackup.FogEnd==nil then LightBackup.FogEnd=Lighting.FogEnd; LightBackup.FogStart=Lighting.FogStart end
        Lighting.FogStart=0; Lighting.FogEnd=100000
    elseif LightBackup.FogEnd~=nil then
        Lighting.FogEnd=LightBackup.FogEnd; Lighting.FogStart=LightBackup.FogStart; LightBackup.FogEnd=nil
    end
end

local bobTime=0
local savedCameraOffset=nil
local lastCharacterForCamera=nil
local function ApplyCameraSettings(dt)
    local cam=workspace.CurrentCamera
    if not cam then return end

    local c=Character()
    local h=Humanoid()

    if c~=lastCharacterForCamera then
        lastCharacterForCamera=c
        savedCameraOffset=nil
    end

    if h then
        if savedCameraOffset==nil then
            savedCameraOffset=h.CameraOffset
        end

        if Config.CameraBob and not Config.ThirdPerson and h.MoveDirection.Magnitude>0.05 then
            bobTime+=(dt or 0.016)
            local speed=math.max(h.WalkSpeed,1)
            local amount=math.clamp(speed/32,0.65,1.8)
            local base=savedCameraOffset or Vector3.new(0,0,0)
            h.CameraOffset=base+Vector3.new(0,math.sin(bobTime*10)*0.035*amount,0)
        else
            if savedCameraOffset~=nil then
                h.CameraOffset=savedCameraOffset
            end
        end
    end

    if Config.ThirdPerson then
        local root=c and c:FindFirstChild("HumanoidRootPart")
        if root then
            local target=root.Position-root.CFrame.LookVector*8+Vector3.new(0,3,0)
            cam.CFrame=CFrame.lookAt(target,root.Position+Vector3.new(0,1.5,0))
        end
    end

    -- FOV and camera feel are applied here; the aimbot runs at Camera+1
    -- so it gets the final camera state and can snap without being overwritten.
    local baseFOV=tonumber(Config.FOV) or 80
    local extraFOV=0
    if Config.FOVKick and h then
        local move=math.clamp(h.MoveDirection.Magnitude,0,1)
        extraFOV=(tonumber(Config.FOVKickAmount) or 0)*move
    end
    local targetFOV=math.clamp(baseFOV+extraFOV,40,120)
    cam.FieldOfView=targetFOV

    if Config.CameraShake and h then
        local amount=math.clamp(tonumber(Config.CameraShakeAmount) or 0,0,1)
        if amount>0 then
            local t=time()
            local x=math.sin(t*31.0)*amount*0.0025
            local y=math.cos(t*27.0)*amount*0.0020
            local z=math.sin(t*23.0)*amount*0.0015
            cam.CFrame=cam.CFrame*CFrame.Angles(x,y,z)
        end
    end
end

--========================================================
-- SAFE GRAPHICS / PERFORMANCE
--========================================================
-- IMPORTANT: Low Graphics deliberately does NOT scan workspace descendants.
-- Large descendant scans and heavy work inside render-related loops can stall
-- the client, so Low Graphics is now limited to cheap, reversible settings.
local lowGraphicsApplied=false
local reduceParticlesApplied=false
local reducedParticleBackup={}

local function ApplyLowGraphics()
    local terrain=workspace:FindFirstChildOfClass("Terrain")
    if Config.LowGraphics then
        if terrain and TerrainBackup.WaveSize==nil then
            TerrainBackup.WaveSize=terrain.WaterWaveSize
            TerrainBackup.WaveSpeed=terrain.WaterWaveSpeed
            TerrainBackup.Reflectance=terrain.WaterReflectance
            TerrainBackup.Transparency=terrain.WaterTransparency
        end
        if terrain then
            terrain.WaterWaveSize=0
            terrain.WaterWaveSpeed=0
            terrain.WaterReflectance=0
            terrain.WaterTransparency=.5
        end
        lowGraphicsApplied=true
    else
        if terrain and TerrainBackup.WaveSize~=nil then
            terrain.WaterWaveSize=TerrainBackup.WaveSize
            terrain.WaterWaveSpeed=TerrainBackup.WaveSpeed
            terrain.WaterReflectance=TerrainBackup.Reflectance
            terrain.WaterTransparency=TerrainBackup.Transparency
            TerrainBackup.WaveSize=nil
            TerrainBackup.WaveSpeed=nil
            TerrainBackup.Reflectance=nil
            TerrainBackup.Transparency=nil
        end
        lowGraphicsApplied=false
    end
end

local function ApplyAdvancedGraphics()
    if not graphicsDirty then return end
    LocalColor.Enabled =
        Config.Saturation ~= 0
        or Config.Contrast ~= 0
        or Config.ColorBoost ~= 0

    LocalColor.Saturation=Config.Saturation
    LocalColor.Contrast=Config.Contrast
    LocalColor.Brightness=Config.ColorBoost

    if Config.DisablePostFX then
        for _,effect in ipairs(Lighting:GetChildren()) do
            if effect ~= LocalColor and (
                effect:IsA("BloomEffect")
                or effect:IsA("BlurEffect")
                or effect:IsA("ColorCorrectionEffect")
                or effect:IsA("DepthOfFieldEffect")
                or effect:IsA("SunRaysEffect")
            ) then
                if PostFXBackup[effect]==nil then
                    PostFXBackup[effect]=effect.Enabled
                end
                effect.Enabled=false
            end
        end
    else
        for effect,enabled in pairs(PostFXBackup) do
            if effect and effect.Parent then effect.Enabled=enabled end
        end
        table.clear(PostFXBackup)
    end
    graphicsDirty=false
end

-- Explicit particle reduction remains separate from Low Graphics and runs only
-- when the user enables it. It does NOT attach a global DescendantAdded hook.
local function ApplyParticleReduction()
    if not particleReductionDirty then return end
    if Config.ReduceParticles then
        if not reduceParticlesApplied then
            table.clear(reducedParticleBackup)
            for _,object in ipairs(workspace:GetDescendants()) do
                if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
                    reducedParticleBackup[object]=object.Enabled
                    object.Enabled=false
                end
            end
            reduceParticlesApplied=true
        end
    elseif reduceParticlesApplied then
        for object,enabled in pairs(reducedParticleBackup) do
            if object and object.Parent then object.Enabled=enabled end
        end
        table.clear(reducedParticleBackup)
        reduceParticlesApplied=false
    end
    particleReductionDirty=false
end

--========================================================
-- GAMEPLAY FEATURES
--========================================================
local savedSpeed=nil
local savedCollision={}

--========================================================
-- AIM / GAMEPLAY CORE
--========================================================
local function Character(player)
    player = player or LocalPlayer
    return player and player.Character
end

local function Humanoid(player)
    local c = Character(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsTeammate(player)
    if not player or player==LocalPlayer then return true end
    if LocalPlayer.Team ~= nil and player.Team ~= nil then
        return LocalPlayer.Team == player.Team
    end
    if LocalPlayer.TeamColor and player.TeamColor then
        return LocalPlayer.TeamColor == player.TeamColor
    end
    for _, key in ipairs({"Team","TeamName","Faction","Side","Squad"}) do
        local mine = LocalPlayer:GetAttribute(key)
        local theirs = player:GetAttribute(key)
        if mine ~= nil and theirs ~= nil and mine ~= "" and theirs ~= "" then
            return tostring(mine) == tostring(theirs)
        end
    end
    return false
end

local function GetAimPart(character)
    if not character then return nil end
    local requested = tostring(Config.AimTargetPart or "Head")
    local aliases = {
        LeftArm={"LeftUpperArm","LeftArm"},
        RightArm={"RightUpperArm","RightArm"},
        LeftLeg={"LeftUpperLeg","LeftLeg"},
        RightLeg={"RightUpperLeg","RightLeg"},
        Torso={"UpperTorso","Torso"},
    }
    local direct = character:FindFirstChild(requested)
    if direct and direct:IsA("BasePart") then return direct end
    local list = aliases[requested]
    if list then
        for _, name in ipairs(list) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then return part end
        end
    end
    local fallback = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    return fallback and fallback:IsA("BasePart") and fallback or nil
end

local aimRayParams=RaycastParams.new()
aimRayParams.FilterType=Enum.RaycastFilterType.Exclude
aimRayParams.IgnoreWater=true

local CurrentAimPlayer=nil
local CurrentAimPart=nil
local aimLostUntil=0

ResetAimState=function()
    CurrentAimPlayer=nil
    CurrentAimPart=nil
    aimLostUntil=0
end

local function IsTargetVisible(camera,targetPart,targetCharacter)
    if not camera or not targetPart or not targetCharacter then return false end
    local origin=camera.CFrame.Position
    local destination=targetPart.Position
    local direction=destination-origin
    if direction.Magnitude<=0.001 then return true end

    aimRayParams.FilterDescendantsInstances={Character()}
    local result=workspace:Raycast(origin,direction,aimRayParams)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetCharacter)
end

local function GetTargetPoint(targetPart)
    if not targetPart then return nil end
    if Config.AimPrediction then
        local velocity=targetPart.AssemblyLinearVelocity
        return targetPart.Position+velocity*math.max(0,tonumber(Config.AimPredictionAmount) or 0)
    end
    return targetPart.Position
end

local function IsValidAimTarget(camera,player)
    if not camera or not player or player==LocalPlayer then return false,nil end
    if Config.TeamCheck and IsTeammate(player) then return false,nil end

    local character=Character(player)
    local humanoid=Humanoid(player)
    local targetPart=GetAimPart(character)
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local localCharacter=Character()
    local localRoot=localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health<=0 or not targetPart or not root then
        return false,nil
    end

    local distance=localRoot and (root.Position-localRoot.Position).Magnitude or math.huge
    if distance>Config.MaxAimDistance then return false,nil end

    local screen,onScreen=camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen or screen.Z<=0 then return false,nil end

    local center=Vector2.new(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
    local screenPos=Vector2.new(screen.X,screen.Y)
    if (screenPos-center).Magnitude>Config.AimFOV then return false,nil end

    if not IsTargetVisible(camera,targetPart,character) then return false,nil end
    return true,targetPart
end

local function GetAimbotTarget(camera)
    if not camera then return nil,nil end

    -- Stable target lock prevents the camera from bouncing between targets.
    if Config.AimTargetLock and CurrentAimPlayer then
        local valid,part=IsValidAimTarget(camera,CurrentAimPlayer)
        if valid then
            CurrentAimPart=part
            return CurrentAimPlayer,part
        end
        CurrentAimPlayer=nil
        CurrentAimPart=nil
        aimLostUntil=time()+(tonumber(Config.AimRetargetDelay) or 0)
    end

    if time()<aimLostUntil then
        return nil,nil
    end

    local viewport=camera.ViewportSize
    local center=Vector2.new(viewport.X*.5,viewport.Y*.5)
    local localCharacter=Character()
    local localRoot=localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local bestPlayer,bestPart,bestMetric=nil,nil,nil

    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local valid,targetPart=IsValidAimTarget(camera,player)
            if valid and targetPart then
                local character=Character(player)
                local humanoid=Humanoid(player)
                local root=character and character:FindFirstChild("HumanoidRootPart")
                local distance=localRoot and root and (root.Position-localRoot.Position).Magnitude or math.huge
                local screen=camera:WorldToViewportPoint(targetPart.Position)
                local cursorDistance=(Vector2.new(screen.X,screen.Y)-center).Magnitude
                local metric
                if Config.AimTargetMode=="ClosestToPlayer" then
                    metric=distance
                elseif Config.AimTargetMode=="LowestHealth" then
                    metric=humanoid.Health*100000+distance
                else
                    metric=cursorDistance
                end
                if bestMetric==nil or metric<bestMetric then
                    bestMetric=metric
                    bestPlayer=player
                    bestPart=targetPart
                end
            end
        end
    end

    CurrentAimPlayer=bestPlayer
    CurrentAimPart=bestPart
    return bestPlayer,bestPart
end

local function Aimbot(_dt)
    if not Config.Aimbot then
        ResetAimState()
        return
    end

    local camera=workspace.CurrentCamera
    if not camera then return end

    local player,targetPart=GetAimbotTarget(camera)
    if not player or not targetPart then
        -- IMPORTANT: do not touch Camera.CFrame here.
        -- The player is free to move the camera manually after target loss.
        return
    end

    local aimPoint=GetTargetPoint(targetPart)
    if not aimPoint then return end

    if Config.AimDeadzone and Config.AimDeadzone>0 then
        local screen=camera:WorldToViewportPoint(aimPoint)
        if screen.Z>0 then
            local center=Vector2.new(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
            if (Vector2.new(screen.X,screen.Y)-center).Magnitude<=Config.AimDeadzone then
                return
            end
        end
    end

    local cameraPosition=camera.CFrame.Position
    local direction=aimPoint-cameraPosition
    if direction.Magnitude<=0.001 then return end

    local desired=CFrame.lookAt(cameraPosition,aimPoint)
    if Config.AimSmooth then
        local smoothness=math.max(1,tonumber(Config.AimSmoothness) or 8)
        local alpha=1-math.exp(-smoothness*6*(_dt or (1/60)))
        camera.CFrame=camera.CFrame:Lerp(desired,math.clamp(alpha,0,1))
    else
        -- Instant snap. Never restore an old camera orientation.
        camera.CFrame=desired
    end
end

local function UpdateSpeed()
    local h=Humanoid()
    if not h then return end
    if Config.Speed then
        if savedSpeed==nil then savedSpeed=h.WalkSpeed end
        h.WalkSpeed=Config.SpeedValue
    elseif savedSpeed~=nil then
        h.WalkSpeed=savedSpeed
        savedSpeed=nil
    end
end

local function UpdateNoClip()
    local c=Character()
    if not c then return end
    if Config.NoClip then
        for _,obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BasePart") then
                if savedCollision[obj]==nil then savedCollision[obj]=obj.CanCollide end
                obj.CanCollide=false
            end
        end
    else
        for obj,canCollide in pairs(savedCollision) do
            if obj and obj.Parent then obj.CanCollide=canCollide end
        end
        table.clear(savedCollision)
    end
end

local invisBackup={}
Invisibility=function(enabled)
    local c=Character()
    if not c then return end
    if enabled then
        for _,obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") then
                if invisBackup[obj]==nil then invisBackup[obj]=obj.Transparency end
                obj.Transparency=1
            end
        end
    else
        for obj,transparency in pairs(invisBackup) do
            if obj and obj.Parent then obj.Transparency=transparency end
        end
        table.clear(invisBackup)
    end
end

--========================================================
-- ESP SYSTEM 7.0 — premium tactical renderer
--========================================================
-- Goals:
--   * no dead-player ghosting
--   * character lifecycle aware cleanup
--   * readable silhouette instead of stick-like skeletons
--   * team/custom colors
--   * distance fade without destroying visibility
--   * deterministic ownership of every created UI primitive
--   * zero camera writes from ESP

local function DestroyOldESPOverlays()
    pcall(function()
        for _,obj in ipairs(PlayerGui:GetChildren()) do
            if obj.Name=="FPSESPOverlay" or obj.Name=="FPSPremiumESP" then
                obj:Destroy()
            end
        end
    end)
    pcall(function()
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Highlight") and obj:GetAttribute("FPSESPManaged") then
                obj:Destroy()
            end
        end
    end)
end
DestroyOldESPOverlays()

local ESPGui=Instance.new("ScreenGui")
ESPGui.Name="FPSESPOverlay"
ESPGui.ResetOnSpawn=false
ESPGui.IgnoreGuiInset=true
ESPGui.DisplayOrder=2000
ESPGui.ZIndexBehavior=Enum.ZIndexBehavior.Global
ESPGui.Parent=PlayerGui
ESPGui:SetAttribute("FPSESPManaged",true)

local espCanvas=Instance.new("Frame")
espCanvas.Name="Canvas"
espCanvas.Size=UDim2.fromScale(1,1)
espCanvas.BackgroundTransparency=1
espCanvas.BorderSizePixel=0
espCanvas.Active=false
espCanvas.Parent=ESPGui

local espObjects={}
local RemoveESP

local R15Bones={
    {"Head","UpperTorso","HeadNeck"},
    {"UpperTorso","LowerTorso","Spine"},
    {"UpperTorso","LeftUpperArm","LShoulder"},
    {"LeftUpperArm","LeftLowerArm","LElbow"},
    {"LeftLowerArm","LeftHand","LWrist"},
    {"UpperTorso","RightUpperArm","RShoulder"},
    {"RightUpperArm","RightLowerArm","RElbow"},
    {"RightLowerArm","RightHand","RWrist"},
    {"LowerTorso","LeftUpperLeg","LHip"},
    {"LeftUpperLeg","LeftLowerLeg","LKnee"},
    {"LeftLowerLeg","LeftFoot","LAnkle"},
    {"LowerTorso","RightUpperLeg","RHip"},
    {"RightUpperLeg","RightLowerLeg","RKnee"},
    {"RightLowerLeg","RightFoot","RAnkle"},
    {"UpperTorso","LowerTorso","Chest"},
}
local R6Bones={
    {"Head","Torso","HeadNeck"},
    {"Torso","Left Arm","LShoulder"},
    {"Torso","Right Arm","RShoulder"},
    {"Torso","Left Leg","LHip"},
    {"Torso","Right Leg","RHip"},
    {"Torso","HumanoidRootPart","Spine"},
}
local R15Joints={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
local R6Joints={"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg","HumanoidRootPart"}

local function ESPColor(player)
    if Config.ESPTeamColor and player and player.TeamColor then
        return player.TeamColor.Color
    end
    return C.Accent
end

local function ESPAlpha(distance)
    if not Config.ESPFade then return 0 end
    local maxD=math.max(1,tonumber(Config.ESPFadeDistance) or tonumber(Config.ESPMaxDistance) or 600)
    local t=math.clamp(distance/maxD,0,1)
    return math.clamp(0.02+t*0.36,0.02,0.40)
end

local function NewESPFrame(parent,z)
    local f=Instance.new("Frame")
    f.BackgroundColor3=C.Accent
    f.BackgroundTransparency=0
    f.BorderSizePixel=0
    f.Visible=false
    f.Active=false
    f.ZIndex=z or 10
    f.Parent=parent
    f:SetAttribute("FPSESPManaged",true)
    return f
end

local function HideObject(obj)
    if obj then obj.Visible=false end
end

local function SetLine(line,a,b,thickness,color,transparency)
    if not line then return end
    local d=b-a
    local length=d.Magnitude
    if length < 0.35 then
        line.Visible=false
        return
    end
    line.AnchorPoint=Vector2.new(0.5,0.5)
    line.Position=UDim2.fromOffset((a.X+b.X)*0.5,(a.Y+b.Y)*0.5)
    line.Size=UDim2.fromOffset(length,math.max(1,thickness))
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3=color
    line.BackgroundTransparency=math.clamp(transparency or 0,0,1)
    line.Visible=true
end

local function MakeLinePair(parent,z,color)
    local shadow=NewESPFrame(parent,z)
    shadow.BackgroundColor3=Color3.fromRGB(0,0,0)
    shadow.BackgroundTransparency=.08
    local main=NewESPFrame(parent,z+1)
    main.BackgroundColor3=color or C.Accent
    main.BackgroundTransparency=0
    return {main=main,shadow=shadow}
end

local function HidePair(pair)
    if pair then
        HideObject(pair.main)
        HideObject(pair.shadow)
    end
end

local function MakeJoint(parent,z)
    local outer=NewESPFrame(parent,z)
    outer.BackgroundColor3=Color3.fromRGB(0,0,0)
    outer.AnchorPoint=Vector2.new(.5,.5)
    local outerCorner=Instance.new("UICorner")
    outerCorner.CornerRadius=UDim.new(1,0)
    outerCorner.Parent=outer
    local inner=NewESPFrame(parent,z+1)
    inner.AnchorPoint=Vector2.new(.5,.5)
    local innerCorner=Instance.new("UICorner")
    innerCorner.CornerRadius=UDim.new(1,0)
    innerCorner.Parent=inner
    return {outer=outer,inner=inner}
end

local function HideJoint(j)
    if not j then return end
    HideObject(j.outer)
    HideObject(j.inner)
end

local function SetJoint(j,point,size,color,transparency)
    if not j then return end
    local s=math.clamp(size,3,9)
    j.outer.Size=UDim2.fromOffset(s+2,s+2)
    j.inner.Size=UDim2.fromOffset(s,s)
    j.outer.Position=UDim2.fromOffset(point.X,point.Y)
    j.inner.Position=UDim2.fromOffset(point.X,point.Y)
    j.outer.BackgroundTransparency=math.clamp(transparency or 0,0,1)
    j.inner.BackgroundColor3=color
    j.inner.BackgroundTransparency=math.clamp(transparency or 0,0,1)
    j.outer.Visible=true
    j.inner.Visible=true
end

local function BuildEntry(player,char)
    local old=espObjects[player]
    if old and old.character==char then return old end
    if old then
        if old.diedConn then old.diedConn:Disconnect() end
        if old.charRemovingConn then old.charRemovingConn:Disconnect() end
        if old.highlight then pcall(function() old.highlight:Destroy() end) end
        for _,obj in ipairs(old.owned or {}) do pcall(function() obj:Destroy() end) end
    end

    local owned={}
    local e={
        player=player,
        character=char,
        owned=owned,
        box={},
        skeleton={},
        joints={},
        lastHealth=nil,
        deathReported=false,
        createdAt=time(),
    }

    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    local highlight=Instance.new("Highlight")
    highlight.Name="FPSPanelPlayerHighlight"
    highlight.Adornee=char
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency=.84
    highlight.OutlineTransparency=0
    highlight.FillColor=ESPColor(player)
    highlight.OutlineColor=ESPColor(player)
    highlight.Enabled=false
    highlight:SetAttribute("FPSESPManaged",true)
    highlight.Parent=workspace
    e.highlight=highlight

    local card=NewESPFrame(espCanvas,80)
    card.Size=UDim2.fromOffset(196,59)
    card.BackgroundColor3=Color3.fromRGB(10,12,17)
    card.BackgroundTransparency=.08
    card.ZIndex=80
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(62,67,80)
    stroke.Thickness=1
    stroke.Transparency=.1
    stroke.Parent=card
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,8)
    corner.Parent=card
    local accent=NewESPFrame(card,81)
    accent.Size=UDim2.fromOffset(3,41)
    accent.Position=UDim2.fromOffset(8,9)
    accent.BackgroundColor3=ESPColor(player)
    local name=Instance.new("TextLabel")
    name.BackgroundTransparency=1
    name.Position=UDim2.fromOffset(18,5)
    name.Size=UDim2.fromOffset(116,17)
    name.TextColor3=Color3.new(1,1,1)
    name.TextSize=11
    name.Font=Enum.Font.GothamBold
    name.TextXAlignment=Enum.TextXAlignment.Left
    name.TextTruncate=Enum.TextTruncate.AtEnd
    name.ZIndex=82
    name.Parent=card
    local dist=Instance.new("TextLabel")
    dist.BackgroundTransparency=1
    dist.Position=UDim2.fromOffset(132,5)
    dist.Size=UDim2.fromOffset(54,17)
    dist.TextColor3=Color3.fromRGB(191,197,209)
    dist.TextSize=8
    dist.Font=Enum.Font.GothamBold
    dist.TextXAlignment=Enum.TextXAlignment.Right
    dist.ZIndex=82
    dist.Parent=card
    local hpBack=NewESPFrame(card,81)
    hpBack.Size=UDim2.fromOffset(168,5)
    hpBack.Position=UDim2.fromOffset(18,29)
    hpBack.BackgroundColor3=Color3.fromRGB(38,41,49)
    hpBack.BackgroundTransparency=.1
    local hp=NewESPFrame(hpBack,82)
    hp.Size=UDim2.fromScale(1,1)
    local hpCorner=Instance.new("UICorner")
    hpCorner.CornerRadius=UDim.new(0,4)
    hpCorner.Parent=hp
    local state=Instance.new("TextLabel")
    state.BackgroundTransparency=1
    state.Position=UDim2.fromOffset(18,38)
    state.Size=UDim2.fromOffset(168,14)
    state.TextColor3=Color3.fromRGB(170,177,190)
    state.TextSize=8
    state.Font=Enum.Font.Gotham
    state.TextXAlignment=Enum.TextXAlignment.Left
    state.ZIndex=82
    state.Parent=card
    local user=Instance.new("TextLabel")
    user.BackgroundTransparency=1
    user.Position=UDim2.fromOffset(18,16)
    user.Size=UDim2.fromOffset(116,12)
    user.TextColor3=Color3.fromRGB(132,138,150)
    user.TextSize=7
    user.Font=Enum.Font.Gotham
    user.TextXAlignment=Enum.TextXAlignment.Left
    user.TextTruncate=Enum.TextTruncate.AtEnd
    user.ZIndex=82
    user.Parent=card
    e.card=card;e.name=name;e.user=user;e.dist=dist;e.hpBack=hpBack;e.hp=hp;e.state=state;e.accent=accent

    local dot=NewESPFrame(espCanvas,90)
    dot.Size=UDim2.fromOffset(7,7)
    dot.AnchorPoint=Vector2.new(.5,.5)
    local dc=Instance.new("UICorner");dc.CornerRadius=UDim.new(1,0);dc.Parent=dot
    e.headDot=dot

    local arrow=Instance.new("TextLabel")
    arrow.BackgroundTransparency=1
    arrow.AnchorPoint=Vector2.new(.5,.5)
    arrow.Size=UDim2.fromOffset(30,30)
    arrow.Text="▲"
    arrow.TextSize=20
    arrow.Font=Enum.Font.GothamBlack
    arrow.TextStrokeColor3=Color3.fromRGB(0,0,0)
    arrow.TextStrokeTransparency=.2
    arrow.ZIndex=95
    arrow.Visible=false
    arrow.Parent=espCanvas
    arrow:SetAttribute("FPSESPManaged",true)
    e.arrow=arrow

    for i=1,6 do e.box[i]=MakeLinePair(espCanvas,70,ESPColor(player)) end
    e.tracer=MakeLinePair(espCanvas,60,ESPColor(player))
    for i=1,math.max(#R15Bones,#R6Bones) do e.skeleton[i]=MakeLinePair(espCanvas,65,ESPColor(player)) end
    for i=1,15 do e.joints[i]=MakeJoint(espCanvas,68) end

    e.diedConn=hum.Died:Connect(function()
        if espObjects[player]~=e then return end
        e.deathReported=true
        RemoveESP(player)
    end)
    e.charRemovingConn=player.CharacterRemoving:Connect(function(removed)
        if removed==char then RemoveESP(player) end
    end)
    e.lastHealth=hum.Health

    local ownedList={card,accent,name,user,dist,hpBack,hp,state,dot,arrow}
    for _,pair in ipairs(e.box) do ownedList[#ownedList+1]=pair.main;ownedList[#ownedList+1]=pair.shadow end
    ownedList[#ownedList+1]=e.tracer.main;ownedList[#ownedList+1]=e.tracer.shadow
    for _,pair in ipairs(e.skeleton) do ownedList[#ownedList+1]=pair.main;ownedList[#ownedList+1]=pair.shadow end
    for _,joint in ipairs(e.joints) do ownedList[#ownedList+1]=joint.outer;ownedList[#ownedList+1]=joint.inner end
    e.owned=ownedList
    espObjects[player]=e
    return e
end

RemoveESP=function(player)
    local e=espObjects[player]
    if not e then return end
    espObjects[player]=nil
    if e.diedConn then pcall(function() e.diedConn:Disconnect() end) end
    if e.charRemovingConn then pcall(function() e.charRemovingConn:Disconnect() end) end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    for _,obj in ipairs(e.owned or {}) do pcall(function() obj:Destroy() end) end
end

ClearAllESP=function()
    local players={}
    for player in pairs(espObjects) do players[#players+1]=player end
    for _,player in ipairs(players) do RemoveESP(player) end
    table.clear(espObjects)
    pcall(function()
        for _,obj in ipairs(espCanvas:GetChildren()) do
            if obj:GetAttribute("FPSESPManaged") then obj:Destroy() end
        end
    end)
    pcall(function()
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Highlight") and obj:GetAttribute("FPSESPManaged") then obj:Destroy() end
        end
    end)
end

local function GetBounds(cam,char,view)
    local ok,cf,size=pcall(function() return char:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    local hx,hy,hz=size.X*.5,size.Y*.5,size.Z*.5
    local minX,minY=math.huge,math.huge
    local maxX,maxY=-math.huge,-math.huge
    local visibleCorners=0
    for sx=-1,1,2 do
        for sy=-1,1,2 do
            for sz=-1,1,2 do
                local world=(cf*CFrame.new(sx*hx,sy*hy,sz*hz)).Position
                local p=cam:WorldToViewportPoint(world)
                if p.Z>0 then
                    visibleCorners+=1
                    minX=math.min(minX,p.X);minY=math.min(minY,p.Y)
                    maxX=math.max(maxX,p.X);maxY=math.max(maxY,p.Y)
                end
            end
        end
    end
    if visibleCorners==0 then return nil end
    minX=math.clamp(minX,-90,view.X+90)
    maxX=math.clamp(maxX,-90,view.X+90)
    minY=math.clamp(minY,-90,view.Y+90)
    maxY=math.clamp(maxY,-90,view.Y+90)
    if maxX-minX<5 or maxY-minY<9 then return nil end
    return minX,minY,maxX,maxY
end

local function UpdateBox(e,b,color,alpha)
    if not Config.ESPBoxes or not b then
        for _,pair in ipairs(e.box) do HidePair(pair) end
        return
    end
    local minX,minY,maxX,maxY=table.unpack(b)
    local w=maxX-minX
    local h=maxY-minY
    if w<5 or h<9 then for _,pair in ipairs(e.box) do HidePair(pair) end return end
    local t=math.clamp(math.floor(math.min(w,h)*.009+.5),1,2)
    local s=t+1
    local style=tostring(Config.ESPBoxStyle or "Corners")
    local defs
    if style=="Full" then
        defs={
            {Vector2.new(minX,minY),Vector2.new(maxX,minY)},
            {Vector2.new(maxX,minY),Vector2.new(maxX,maxY)},
            {Vector2.new(maxX,maxY),Vector2.new(minX,maxY)},
            {Vector2.new(minX,maxY),Vector2.new(minX,minY)},
            {Vector2.new(minX+1,minY+2),Vector2.new(maxX-1,minY+2)},
            {Vector2.new(minX+1,maxY-2),Vector2.new(maxX-1,maxY-2)},
        }
    elseif style=="Bracket" then
        local cx=math.min(w*.26,34);local cy=math.min(h*.19,42)
        defs={
            {Vector2.new(minX,minY),Vector2.new(minX+cx,minY)},
            {Vector2.new(minX,minY),Vector2.new(minX,minY+cy)},
            {Vector2.new(maxX,minY),Vector2.new(maxX-cx,minY)},
            {Vector2.new(maxX,minY),Vector2.new(maxX,minY+cy)},
            {Vector2.new(minX,maxY),Vector2.new(minX+cx,maxY)},
            {Vector2.new(minX,maxY),Vector2.new(minX,maxY-cy)},
        }
    else
        local cx=math.min(w*.30,42);local cy=math.min(h*.22,52)
        defs={
            {Vector2.new(minX,minY),Vector2.new(minX+cx,minY)},
            {Vector2.new(minX,minY),Vector2.new(minX,minY+cy)},
            {Vector2.new(maxX,minY),Vector2.new(maxX-cx,minY)},
            {Vector2.new(maxX,minY),Vector2.new(maxX,minY+cy)},
            {Vector2.new(minX,maxY),Vector2.new(minX+cx,maxY)},
            {Vector2.new(maxX,maxY),Vector2.new(maxX-cx,maxY)},
        }
    end
    for i,pair in ipairs(e.box) do
        local def=defs[i]
        if not def then HidePair(pair) else
            SetLine(pair.shadow,def[1]+Vector2.new(1,1),def[2]+Vector2.new(1,1),s,Color3.fromRGB(0,0,0),math.clamp(alpha*.85,0,.65))
            SetLine(pair.main,def[1],def[2],t,color,alpha)
        end
    end
end

local function UpdateTracer(e,point,color,view,alpha)
    if not Config.ESPTracers or not point then HidePair(e.tracer);return end
    local from
    local style=tostring(Config.ESPLineStyle or "Bottom")
    if style=="Center" then from=Vector2.new(view.X*.5,view.Y*.5)
    elseif style=="Crosshair" then from=Vector2.new(view.X*.5,view.Y*.5)
    else from=Vector2.new(view.X*.5,view.Y-2) end
    local to=Vector2.new(math.clamp(point.X,-50,view.X+50),math.clamp(point.Y,-50,view.Y+50))
    if (to-from).Magnitude<5 then HidePair(e.tracer);return end
    SetLine(e.tracer.shadow,from+Vector2.new(1,1),to+Vector2.new(1,1),2.5,Color3.fromRGB(0,0,0),math.clamp(alpha*.85,0,.7))
    SetLine(e.tracer.main,from,to,1,color,alpha)
end

local function JointMap(bones)
    local map={}
    for _,bone in ipairs(bones) do
        map[bone[1]]=true;map[bone[2]]=true
    end
    return map
end

local function UpdateSkeleton(e,char,color,cam,view,alpha)
    if not Config.ESPSkeleton then
        for _,pair in ipairs(e.skeleton) do HidePair(pair) end
        for _,joint in ipairs(e.joints) do HideJoint(joint) end
        return
    end
    local isR15=char:FindFirstChild("UpperTorso")~=nil
    local defs=isR15 and R15Bones or R6Bones
    local joints=isR15 and R15Joints or R6Joints
    local jointCount=0
    local thickness=math.clamp(tonumber(Config.ESPSkeletonThickness) or 2,1,3)
    local jointSize=math.clamp(tonumber(Config.ESPJointSize) or 4,3,8)
    local jointMap=JointMap(defs)

    for i,pair in ipairs(e.skeleton) do
        local bone=defs[i]
        if not bone then HidePair(pair) else
            local a=char:FindFirstChild(bone[1])
            local b=char:FindFirstChild(bone[2])
            if not a or not b or not a:IsA("BasePart") or not b:IsA("BasePart") then HidePair(pair) else
                local pa=cam:WorldToViewportPoint(a.Position)
                local pb=cam:WorldToViewportPoint(b.Position)
                local av=pa.Z>0 and pa.X>-90 and pa.X<view.X+90 and pa.Y>-90 and pa.Y<view.Y+90
                local bv=pb.Z>0 and pb.X>-90 and pb.X<view.X+90 and pb.Y>-90 and pb.Y<view.Y+90
                if not av or not bv then HidePair(pair) else
                    local va=Vector2.new(pa.X,pa.Y);local vb=Vector2.new(pb.X,pb.Y)
                    SetLine(pair.shadow,va+Vector2.new(1,1),vb+Vector2.new(1,1),thickness+2,Color3.fromRGB(0,0,0),math.clamp(alpha*.75,0,.75))
                    SetLine(pair.main,va,vb,thickness,color,alpha)
                end
            end
        end
    end

    for _,name in ipairs(joints) do
        local part=char:FindFirstChild(name)
        local joint=e.joints[jointCount+1]
        if joint and part and part:IsA("BasePart") then
            local p=cam:WorldToViewportPoint(part.Position)
            if p.Z>0 and p.X>-60 and p.X<view.X+60 and p.Y>-60 and p.Y<view.Y+60 then
                jointCount+=1
                SetJoint(joint,Vector2.new(p.X,p.Y),jointSize,color,alpha)
            end
        end
    end
    for i=jointCount+1,#e.joints do HideJoint(e.joints[i]) end
end

local function UpdateArrow(e,point,color,view,behind,alpha)
    if not Config.ESPOffscreen or not point then HideObject(e.arrow);return end
    local center=Vector2.new(view.X*.5,view.Y*.5)
    local d=Vector2.new(point.X,point.Y)-center
    if behind then d=-d end
    if d.Magnitude<1 then HideObject(e.arrow);return end
    local n=d.Unit
    local maxX=view.X*.5-26;local maxY=view.Y*.5-26
    local tx=math.abs(n.X)>.001 and maxX/math.abs(n.X) or math.huge
    local ty=math.abs(n.Y)>.001 and maxY/math.abs(n.Y) or math.huge
    local p=center+n*math.min(tx,ty)
    e.arrow.Position=UDim2.fromOffset(p.X,p.Y)
    e.arrow.Rotation=math.deg(math.atan2(n.Y,n.X))+90
    e.arrow.TextColor3=color
    e.arrow.TextTransparency=math.clamp(alpha+.05,0,.72)
    e.arrow.Visible=true
end

UpdateESP=function()
    if not Config.ESP then ClearAllESP();return end
    local cam=workspace.CurrentCamera
    local mine=Character()
    local myRoot=mine and mine:FindFirstChild("HumanoidRootPart")
    if not cam or not myRoot then ClearAllESP();return end
    local view=cam.ViewportSize
    local origin=myRoot.Position
    local seen={}

    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local head=char and char:FindFirstChild("Head")
            if char and char.Parent and hum and hum.Parent and hum.Health>0 and root then
                local distance=(root.Position-origin).Magnitude
                if distance<=Config.ESPMaxDistance then
                    local e=BuildEntry(player,char)
                    if e then
                        seen[player]=true
                        local color=ESPColor(player)
                        local alpha=ESPAlpha(distance)
                        e.highlight.Adornee=char
                        e.highlight.FillColor=color
                        e.highlight.OutlineColor=color
                        e.highlight.FillTransparency=math.clamp(.80+alpha*.35,.80,.97)
                        e.highlight.OutlineTransparency=math.clamp(alpha*.45,0,.55)
                        e.highlight.Enabled=Config.ESP
                        e.accent.BackgroundColor3=color

                        HideObject(e.card);HideObject(e.headDot);HideObject(e.arrow)
                        for _,pair in ipairs(e.box) do HidePair(pair) end
                        HidePair(e.tracer)
                        for _,pair in ipairs(e.skeleton) do HidePair(pair) end
                        for _,joint in ipairs(e.joints) do HideJoint(joint) end

                        local rootP=cam:WorldToViewportPoint(root.Position)
                        local headP=head and cam:WorldToViewportPoint(head.Position) or rootP
                        local inFront=rootP.Z>0
                        local onScreen=inFront and rootP.X>=0 and rootP.X<=view.X and rootP.Y>=0 and rootP.Y<=view.Y
                        local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)

                        if e.lastHealth and hum.Health<e.lastHealth and Config.DamageFeed then
                            local amount=e.lastHealth-hum.Health
                            if amount>0.5 then
                                e.lastDamage=amount
                                e.lastDamageTime=time()
                            end
                        end
                        e.lastHealth=hum.Health

                        if onScreen then
                            if Config.ESPNames or Config.ESPHealth or Config.ESPDistance then
                                e.card.Visible=true
                                e.card.Position=UDim2.fromOffset(math.floor(headP.X+8),math.floor(headP.Y-62))
                            end
                            e.name.Visible=Config.ESPNames and Config.ESPShowDisplayName
                            e.name.Text=player.DisplayName
                            e.user.Visible=Config.ESPNames and Config.ESPShowUsername
                            e.user.Text="@"..player.Name
                            e.dist.Visible=Config.ESPDistance
                            e.dist.Text=(Config.ESPDistanceUnits=="Meters" and string.format("%.0fm",distance) or string.format("%.0f",distance))
                            e.hpBack.Visible=Config.ESPHealth and Config.ESPHealthBar
                            e.hp.Visible=e.hpBack.Visible
                            e.hp.Size=UDim2.new(ratio,0,1,0)
                            e.hp.BackgroundColor3=Color3.new(1-ratio,ratio,0)
                            local stateText=""
                            if Config.ESPShowState then
                                local state=hum:GetState()
                                stateText=tostring(state):gsub("Enum.HumanoidStateType.","")
                                if stateText=="RunningNoPhysics" then stateText="Running" end
                            end
                            e.state.Visible=Config.ESPShowState
                            e.state.Text=string.format("HP %d/%d%s",math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5),stateText~="" and (" • "..stateText) or "")
                            e.headDot.Visible=Config.ESPHeadDot and headP.Z>0
                            if e.headDot.Visible then e.headDot.Position=UDim2.fromOffset(headP.X,headP.Y);e.headDot.BackgroundColor3=color;e.headDot.BackgroundTransparency=alpha end
                            local minX,minY,maxX,maxY=GetBounds(cam,char,view)
                            if minX then UpdateBox(e,{minX,minY,maxX,maxY},color,alpha) else UpdateBox(e,nil,color,alpha) end
                            UpdateTracer(e,Vector2.new(rootP.X,rootP.Y),color,view,alpha)
                            UpdateSkeleton(e,char,color,cam,view,alpha)
                        else
                            UpdateArrow(e,headP,color,view,not inFront,alpha)
                            for _,joint in ipairs(e.joints) do HideJoint(joint) end
                        end
                    end
                end
            end
        end
    end

    for player in pairs(espObjects) do
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not seen[player] or not char or not char.Parent or not hum or hum.Health<=0 then
            RemoveESP(player)
        end
    end
end

local ESPConnections={}
local function HookPlayerESP(player)
    if player==LocalPlayer or ESPConnections[player] then return end
    local c={};ESPConnections[player]=c
    c.characterAdded=player.CharacterAdded:Connect(function(char)
        RemoveESP(player)
        if Config.ESP then
            task.defer(function()
                if player.Character==char then
                    local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",2)
                    if hum and hum.Health>0 then BuildEntry(player,char) end
                end
            end)
        end
    end)
    c.characterRemoving=player.CharacterRemoving:Connect(function(char)
        local e=espObjects[player]
        if e and e.character==char then RemoveESP(player) end
    end)
end

for _,player in ipairs(Players:GetPlayers()) do HookPlayerESP(player) end
Players.PlayerAdded:Connect(HookPlayerESP)
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    local c=ESPConnections[player]
    if c then
        for _,conn in pairs(c) do pcall(function() conn:Disconnect() end) end
        ESPConnections[player]=nil
    end
end)

local fpsValue=60
local fpsAccum=0
local fpsFrames=0
local function UpdateFPSClock(dt)
    fpsAccum+=(dt or 0)
    fpsFrames+=1
    if fpsAccum>=.5 then
        fpsValue=math.floor(fpsFrames/fpsAccum+.5)
        fpsAccum=0
        fpsFrames=0
    end
end

local function RenderStatus()
    local lines={}
    if Config.FPSCounter then table.insert(lines,"FPS   "..tostring(fpsValue)) end
    if Config.PingCounter then
        local ok,ping=pcall(function() return LocalPlayer:GetNetworkPing()*1000 end)
        if ok then table.insert(lines,"PING  "..tostring(math.floor(ping+0.5)).." ms") end
    end
    if Config.Coordinates then
        local c=Character(); local r=c and c:FindFirstChild("HumanoidRootPart")
        if r then table.insert(lines,string.format("POS   %d, %d, %d",r.Position.X,r.Position.Y,r.Position.Z)) end
    end
    if Config.LocalTime then
        table.insert(lines,"TIME  "..os.date("%H:%M:%S"))
    end
    Status.Text=table.concat(lines,"\n")
    Status.Visible=#lines>0
end

local function ApplyClientSettings(dt)
    ApplyCameraSettings(dt)
end

UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local h=Humanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

--========================================================
-- LIGHTWEIGHT LOOP
--========================================================
local espT=0
local speedT=0
local noclipT=0
local invisT=0
local visualT=0
local graphicsT=0
local hudT=0
local lastSprintState=nil

-- Camera work is intentionally bound AFTER Roblox's camera priority.
-- Roblox documents Camera as priority 200; Camera+1 runs after default camera updates.
RunService:BindToRenderStep(CAMERA_RENDER_NAME,Enum.RenderPriority.Camera.Value+1,function(dt)
    ApplyClientSettings(dt)
end)

RunService:BindToRenderStep(AIM_RENDER_NAME,Enum.RenderPriority.Camera.Value+2,function(dt)
    Aimbot(dt)
end)

task.defer(function()
    UpdateCrosshair()
    ApplyLocalVisuals()
    ApplyLowGraphics()
    ApplyAdvancedGraphics()
    ApplyParticleReduction()
    if Config.ESP then UpdateESP() end
end)

RunService:BindToRenderStep(MAIN_RENDER_NAME,Enum.RenderPriority.Character.Value+1,function(dt)
    espT+=dt
    speedT+=dt
    noclipT+=dt
    invisT+=dt
    visualT+=dt
    graphicsT+=dt
    hudT+=dt

    UpdateFPSClock(dt)

    if visualT>=0.10 then
        visualT=0
        UpdateCrosshair()
        ApplyLocalVisuals()
    end

    if graphicsT>=0.50 then
        graphicsT=0
        if lowGraphicsApplied ~= Config.LowGraphics then ApplyLowGraphics() end
        ApplyAdvancedGraphics()
        ApplyParticleReduction()
    end

    if hudT>=0.20 then
        hudT=0
        RenderStatus()
    end

    if lastSprintState~=Config.AutoSprint then
        lastSprintState=Config.AutoSprint
        pcall(function() LocalPlayer:SetAttribute("FPSPanelSprint",lastSprintState) end)
    end

    if espT>=math.max(0.03,(function() local base=tonumber(Config.ESPUpdateRate) or 0.06; if not Config.AdaptiveESP then return base end; local fps=tonumber(fpsValue) or 60; if fps<30 then return math.max(base,.16) elseif fps<40 then return math.max(base,.12) elseif fps<50 then return math.max(base,.09) else return base end end)()) then
        espT=0
        if Config.ESP or next(espObjects) then UpdateESP() end
    end

    if speedT>=.08 then
        speedT=0
        if Config.Speed or savedSpeed~=nil then UpdateSpeed() end
    end

    if noclipT>=.05 then
        noclipT=0
        if Config.NoClip or next(savedCollision) then UpdateNoClip() end
    end

    if invisT>=.20 then
        invisT=0
        if Config.Invisibility then Invisibility(true) end
    end
end)



--========================================================
-- ENHANCEMENT PACK 7.0
-- THEMES / RADAR / FOV RING / THREAT HUD / FEEDS / UX
--========================================================
-- Wrapped in its own function to avoid Luau top-level local-register exhaustion.
FPSPanel_InitEnhancements = function()
-- This layer is intentionally client-only and self-contained.
-- It never rewrites the aimbot camera logic.

local Enhancement={}
Enhancement.__index=Enhancement

local ThemePalettes={
    ["Night Purple"]={
        Bg=Color3.fromRGB(9,10,13),Surface=Color3.fromRGB(16,17,22),Surface2=Color3.fromRGB(22,23,29),Surface3=Color3.fromRGB(29,30,38),
        Border=Color3.fromRGB(46,48,58),Text=Color3.fromRGB(245,245,248),Sub=Color3.fromRGB(150,153,163),Muted=Color3.fromRGB(94,97,107),
        Accent=Color3.fromRGB(130,92,255),Accent2=Color3.fromRGB(93,63,190),Good=Color3.fromRGB(67,204,126),Bad=Color3.fromRGB(232,82,88),
    },
    ["Crimson"]={
        Bg=Color3.fromRGB(13,9,10),Surface=Color3.fromRGB(22,15,17),Surface2=Color3.fromRGB(31,20,23),Surface3=Color3.fromRGB(42,25,29),
        Border=Color3.fromRGB(61,43,48),Text=Color3.fromRGB(248,244,245),Sub=Color3.fromRGB(168,151,156),Muted=Color3.fromRGB(105,83,89),
        Accent=Color3.fromRGB(255,78,96),Accent2=Color3.fromRGB(191,42,63),Good=Color3.fromRGB(78,214,138),Bad=Color3.fromRGB(255,99,105),
    },
    ["Cyan"]={
        Bg=Color3.fromRGB(7,12,14),Surface=Color3.fromRGB(12,20,24),Surface2=Color3.fromRGB(18,29,34),Surface3=Color3.fromRGB(24,39,45),
        Border=Color3.fromRGB(39,61,69),Text=Color3.fromRGB(239,250,252),Sub=Color3.fromRGB(143,171,180),Muted=Color3.fromRGB(80,111,122),
        Accent=Color3.fromRGB(52,220,255),Accent2=Color3.fromRGB(19,150,183),Good=Color3.fromRGB(81,222,151),Bad=Color3.fromRGB(255,105,115),
    },
    ["Emerald"]={
        Bg=Color3.fromRGB(7,12,10),Surface=Color3.fromRGB(12,20,16),Surface2=Color3.fromRGB(17,30,23),Surface3=Color3.fromRGB(23,40,29),
        Border=Color3.fromRGB(41,65,50),Text=Color3.fromRGB(240,250,244),Sub=Color3.fromRGB(145,170,154),Muted=Color3.fromRGB(83,113,92),
        Accent=Color3.fromRGB(54,220,136),Accent2=Color3.fromRGB(27,151,92),Good=Color3.fromRGB(84,225,148),Bad=Color3.fromRGB(245,96,105),
    },
    ["Gold"]={
        Bg=Color3.fromRGB(13,11,7),Surface=Color3.fromRGB(22,19,12),Surface2=Color3.fromRGB(32,27,17),Surface3=Color3.fromRGB(43,35,21),
        Border=Color3.fromRGB(66,57,35),Text=Color3.fromRGB(250,247,238),Sub=Color3.fromRGB(177,166,141),Muted=Color3.fromRGB(110,98,70),
        Accent=Color3.fromRGB(246,187,58),Accent2=Color3.fromRGB(177,124,20),Good=Color3.fromRGB(84,221,141),Bad=Color3.fromRGB(242,101,92),
    },
    ["Ice"]={
        Bg=Color3.fromRGB(8,10,14),Surface=Color3.fromRGB(15,19,26),Surface2=Color3.fromRGB(22,28,38),Surface3=Color3.fromRGB(30,38,51),
        Border=Color3.fromRGB(49,62,82),Text=Color3.fromRGB(241,246,255),Sub=Color3.fromRGB(154,167,188),Muted=Color3.fromRGB(92,109,136),
        Accent=Color3.fromRGB(132,194,255),Accent2=Color3.fromRGB(74,137,201),Good=Color3.fromRGB(98,225,170),Bad=Color3.fromRGB(255,105,120),
    },
    ["Mono"]={
        Bg=Color3.fromRGB(10,10,10),Surface=Color3.fromRGB(18,18,18),Surface2=Color3.fromRGB(25,25,25),Surface3=Color3.fromRGB(34,34,34),
        Border=Color3.fromRGB(55,55,55),Text=Color3.fromRGB(245,245,245),Sub=Color3.fromRGB(160,160,160),Muted=Color3.fromRGB(96,96,96),
        Accent=Color3.fromRGB(235,235,235),Accent2=Color3.fromRGB(150,150,150),Good=Color3.fromRGB(125,235,160),Bad=Color3.fromRGB(245,100,100),
    },
}

local function ColorMultiply(c,m)
    local r,g,b=c.R,c.G,c.B
    return Color3.new(math.clamp(r*m,0,1),math.clamp(g*m,0,1),math.clamp(b*m,0,1))
end

local function BuildCustomPalette()
    local r=math.clamp(tonumber(Config.CustomAccentR) or 130,0,255)/255
    local g=math.clamp(tonumber(Config.CustomAccentG) or 92,0,255)/255
    local b=math.clamp(tonumber(Config.CustomAccentB) or 255,0,255)/255
    local accent=Color3.new(r,g,b)
    return {
        Bg=Color3.fromRGB(9,10,13),Surface=Color3.fromRGB(16,17,22),Surface2=Color3.fromRGB(22,23,29),Surface3=Color3.fromRGB(29,30,38),
        Border=Color3.fromRGB(46,48,58),Text=Color3.fromRGB(245,245,248),Sub=Color3.fromRGB(150,153,163),Muted=Color3.fromRGB(94,97,107),
        Accent=accent,Accent2=ColorMultiply(accent,.72),Good=Color3.fromRGB(67,204,126),Bad=Color3.fromRGB(232,82,88),
    }
end

local function CopyPalette(p)
    local c={}
    for k,v in pairs(p) do c[k]=v end
    return c
end

local function SameColor(a,b)
    if typeof(a)~="Color3" or typeof(b)~="Color3" then return false end
    return math.abs(a.R-b.R)<0.002 and math.abs(a.G-b.G)<0.002 and math.abs(a.B-b.B)<0.002
end

local function ApplyPaletteToRoot(root,oldPalette,newPalette)
    if not root then return end
    local all={root}
    for _,d in ipairs(root:GetDescendants()) do all[#all+1]=d end
    for _,obj in ipairs(all) do
        if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ScrollingFrame") then
            local bg=obj.BackgroundColor3
            for key in pairs(newPalette) do
                local old=oldPalette[key]
                if SameColor(bg,old) then obj.BackgroundColor3=newPalette[key];break end
            end
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local tc=obj.TextColor3
            for key in pairs(newPalette) do
                local old=oldPalette[key]
                if SameColor(tc,old) then obj.TextColor3=newPalette[key];break end
            end
        end
        if obj:IsA("UIStroke") then
            local sc=obj.Color
            for key in pairs(newPalette) do
                local old=oldPalette[key]
                if SameColor(sc,old) then obj.Color=newPalette[key];break end
            end
        end
        if obj:IsA("ScrollingFrame") then
            if SameColor(obj.ScrollBarImageColor3,oldPalette.Accent) then obj.ScrollBarImageColor3=newPalette.Accent end
        end
    end
end

local paletteCache=CopyPalette(C)
local CurrentPaletteName=Config.ThemeName

local function ApplyTheme(name)
    local palette
    if name=="Custom" then palette=BuildCustomPalette() else palette=ThemePalettes[name] or ThemePalettes["Night Purple"];name=ThemePalettes[name] and name or "Night Purple" end
    local old=CopyPalette(C)
    for key,value in pairs(palette) do C[key]=value end
    ApplyPaletteToRoot(Gui,old,palette)
    local hudRoots={ClientHUD,ESPGui}
    for _,root in ipairs(hudRoots) do ApplyPaletteToRoot(root,old,palette) end
    local color=palette.Accent
    if Dot then Dot.BackgroundColor3=color end
    if Crosshair then
        for _,obj in ipairs(Crosshair:GetChildren()) do
            if obj:IsA("Frame") then obj.BackgroundColor3=Color3.new(1,1,1) end
        end
    end
    CurrentPaletteName=name
    Config.ThemeName=name
    paletteCache=CopyPalette(C)
    for _,refresh in ipairs(Refreshers) do pcall(refresh) end
    pcall(function() SaveProfile(Config.ActiveProfile) end)
end

local function CycleTheme()
    local names={"Night Purple","Crimson","Cyan","Emerald","Gold","Ice","Mono","Custom"}
    local current=Config.ThemeName
    local i=table.find(names,current) or 1
    local nextName=names[(i % #names)+1]
    ApplyTheme(nextName)
end

local function SetCustomAccent(r,g,b)
    Config.CustomAccentR=math.floor(math.clamp(r,0,255)+.5)
    Config.CustomAccentG=math.floor(math.clamp(g,0,255)+.5)
    Config.CustomAccentB=math.floor(math.clamp(b,0,255)+.5)
    Config.UseCustomAccent=true
    ApplyTheme("Custom")
end

--========================================================
-- ENHANCEMENT HUD ROOT
--========================================================
local CombatHUD=New("ScreenGui",{
    Name="FPSCombatHUD",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=1900,ZIndexBehavior=Enum.ZIndexBehavior.Global,
},PlayerGui)
CombatHUD:SetAttribute("FPSESPManaged",true)


local function RoundFrame(parent,size,pos,z)
    local f=New("Frame",{Size=size,Position=pos,BackgroundColor3=C.Surface,BackgroundTransparency=1-Config.HUDOpacity,BorderSizePixel=0,ZIndex=z or 100},parent)
    Corner(f,10);Outline(f,C.Border)
    return f
end

local FOVRingHolder=New("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false},CombatHUD)
local FOVSegments={}
local function RebuildFOVRing()
    for _,obj in ipairs(FOVSegments) do pcall(function() obj:Destroy() end) end
    table.clear(FOVSegments)
    local segments=math.clamp(math.floor(tonumber(Config.FOVRingSegments) or 48),24,96)
    for i=1,segments do
        local seg=New("Frame",{Size=UDim2.fromOffset(2,1),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.Accent,BackgroundTransparency=.18,BorderSizePixel=0,Visible=false,ZIndex=105},FOVRingHolder)
        table.insert(FOVSegments,seg)
    end
end
RebuildFOVRing()

local function UpdateFOVRing()
    local visible=Config.FOVRing and Config.Aimbot
    local center=Vector2.new((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 0)*.5,(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 0)*.5)
    local radius=math.clamp(tonumber(Config.AimFOV) or 180,10,600)
    local n=#FOVSegments
    if not visible or n==0 then
        for _,seg in ipairs(FOVSegments) do seg.Visible=false end
        return
    end
    local thick=math.clamp(tonumber(Config.FOVRingThickness) or 1,1,3)
    for i,seg in ipairs(FOVSegments) do
        local a=((i-1)/n)*math.pi*2
        local nextA=(i/n)*math.pi*2
        local p1=center+Vector2.new(math.cos(a),math.sin(a))*radius
        local p2=center+Vector2.new(math.cos(nextA),math.sin(nextA))*radius
        local d=p2-p1
        seg.Position=UDim2.fromOffset((p1.X+p2.X)*.5,(p1.Y+p2.Y)*.5)
        seg.Size=UDim2.fromOffset(math.max(1,d.Magnitude+1),thick)
        seg.Rotation=math.deg(math.atan2(d.Y,d.X))
        seg.BackgroundColor3=C.Accent
        seg.BackgroundTransparency=math.clamp(tonumber(Config.FOVRingAlpha) or .18,.02,.75)
        seg.Visible=true
    end
end

--========================================================
-- RADAR
--========================================================
local RadarRoot=RoundFrame(CombatHUD,UDim2.fromOffset(Config.RadarSize,Config.RadarSize),UDim2.fromOffset(18,18),120)
RadarRoot.AnchorPoint=Vector2.new(0,0)
local RadarTitle=New("TextLabel",{Size=UDim2.new(1,-16,0,18),Position=UDim2.fromOffset(8,6),BackgroundTransparency=1,Text="TACTICAL RADAR",TextColor3=C.Text,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=121},RadarRoot)
local RadarRangeLabel=New("TextLabel",{Size=UDim2.fromOffset(70,18),Position=UDim2.new(1,-78,0,6),BackgroundTransparency=1,Text="180",TextColor3=C.Muted,TextSize=7,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=121},RadarRoot)
local RadarCanvas=New("Frame",{Size=UDim2.new(1,-16,1,-31),Position=UDim2.fromOffset(8,25),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=120},RadarRoot)
local RadarCenter=New("Frame",{Size=UDim2.fromOffset(5,5),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.Good,BorderSizePixel=0,ZIndex=124},RadarCanvas);Corner(RadarCenter,9)
local RadarGridItems={}
local function MakeRadarGrid()
    for _,obj in ipairs(RadarGridItems) do pcall(function() obj:Destroy() end) end
    table.clear(RadarGridItems)
    local c1=New("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.fromScale(0,.5),BackgroundColor3=C.Border,BackgroundTransparency=.45,BorderSizePixel=0,ZIndex=121},RadarCanvas)
    local c2=New("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.fromScale(.5,0),BackgroundColor3=C.Border,BackgroundTransparency=.45,BorderSizePixel=0,ZIndex=121},RadarCanvas)
    table.insert(RadarGridItems,c1);table.insert(RadarGridItems,c2)
    for k=.25,.75,.25 do
        local h=New("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.fromScale(0,k),BackgroundColor3=C.Border,BackgroundTransparency=.78,BorderSizePixel=0,ZIndex=121},RadarCanvas)
        local v=New("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.fromScale(k,0),BackgroundColor3=C.Border,BackgroundTransparency=.78,BorderSizePixel=0,ZIndex=121},RadarCanvas)
        table.insert(RadarGridItems,h);table.insert(RadarGridItems,v)
    end
end
MakeRadarGrid()
local RadarBlips={}
local function GetRadarBlip(player)
    local b=RadarBlips[player]
    if b and b.Parent then return b end
    local dot=New("Frame",{Size=UDim2.fromOffset(6,6),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.Accent,BorderSizePixel=0,ZIndex=125,Visible=false},RadarCanvas)
    Corner(dot,9)
    local txt=New("TextLabel",{Size=UDim2.fromOffset(46,11),Position=UDim2.fromOffset(6,-5),BackgroundTransparency=1,TextColor3=C.Text,TextSize=6,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=126,Visible=false},RadarCanvas)
    RadarBlips[player]={dot=dot,text=txt}
    return RadarBlips[player]
end
local function ClearRadarBlip(player)
    local b=RadarBlips[player]
    if b then
        if b.dot then b.dot:Destroy() end
        if b.text then b.text:Destroy() end
        RadarBlips[player]=nil
    end
end
Players.PlayerRemoving:Connect(ClearRadarBlip)

local function UpdateRadar()
    RadarRoot.Visible=Config.Radar
    if not Config.Radar then
        for _,b in pairs(RadarBlips) do b.dot.Visible=false;b.text.Visible=false end
        return
    end
    local cam=workspace.CurrentCamera
    local mine=Character()
    local myRoot=mine and mine:FindFirstChild("HumanoidRootPart")
    if not cam or not myRoot then return end
    RadarRoot.Size=UDim2.fromOffset(math.clamp(tonumber(Config.RadarSize) or 150,100,230),math.clamp(tonumber(Config.RadarSize) or 150,100,230))
    RadarRangeLabel.Text=tostring(math.floor(tonumber(Config.RadarRange) or 180))
    RadarGridItems[1].Visible=Config.RadarGrid;RadarGridItems[2].Visible=Config.RadarGrid
    for i=3,#RadarGridItems do RadarGridItems[i].Visible=Config.RadarGrid end
    local size=RadarCanvas.AbsoluteSize
    local halfX=math.max(1,size.X*.5-5);local halfY=math.max(1,size.Y*.5-5)
    local range=math.max(20,tonumber(Config.RadarRange) or 180)
    local right=cam.CFrame.RightVector
    local forward=cam.CFrame.LookVector
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local b=GetRadarBlip(player)
            if char and hum and hum.Health>0 and root and Config.RadarBlips then
                local rel=root.Position-myRoot.Position
                local x=rel:Dot(right)
                local y=rel:Dot(forward)
                if not Config.RadarRotate then
                    local worldX=rel.X;local worldY=rel.Z
                    x=worldX;y=-worldY
                end
                local px=math.clamp((x/range)*halfX,-halfX,halfX)
                local py=math.clamp((-y/range)*halfY,-halfY,halfY)
                local dist=rel.Magnitude
                if dist<=range then
                    b.dot.Position=UDim2.fromOffset(size.X*.5+px,size.Y*.5+py)
                    b.dot.BackgroundColor3=ESPColor(player)
                    b.dot.Visible=true
                    b.text.Text=string.format("%s %d",player.DisplayName:sub(1,7),math.floor(dist+.5))
                    b.text.Position=UDim2.fromOffset(size.X*.5+px+6,size.Y*.5+py-5)
                    b.text.Visible=dist<range*.62
                else
                    b.dot.Visible=false;b.text.Visible=false
                end
            else
                b.dot.Visible=false;b.text.Visible=false
            end
        end
    end
end

--========================================================
-- THREAT WARNING
--========================================================
local Threat=RoundFrame(CombatHUD,UDim2.fromOffset(286,54),UDim2.new(.5,-143,0,18),140)
local ThreatTitle=New("TextLabel",{Size=UDim2.new(1,-22,0,18),Position=UDim2.fromOffset(11,7),BackgroundTransparency=1,Text="THREAT MONITOR",TextColor3=C.Text,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=141},Threat)
local ThreatText=New("TextLabel",{Size=UDim2.new(1,-22,0,20),Position=UDim2.fromOffset(11,25),BackgroundTransparency=1,Text="NO IMMEDIATE THREATS",TextColor3=C.Good,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=141},Threat)
local threatPulseT=0
local function UpdateThreat(dt)
    if not Config.ThreatWarning then Threat.Visible=false;return end
    Threat.Visible=true
    local mine=Character();local root=mine and mine:FindFirstChild("HumanoidRootPart")
    if not root then ThreatText.Text="WAITING FOR CHARACTER";ThreatText.TextColor3=C.Muted;return end
    local nearest=nil;local nearestDist=math.huge
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer and (not Config.TeamCheck or not IsTeammate(player)) then
            local char=player.Character;local hum=char and char:FindFirstChildOfClass("Humanoid");local r=char and char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health>0 and r then
                local d=(r.Position-root.Position).Magnitude
                if d<nearestDist then nearest=player;nearestDist=d end
            end
        end
    end
    local limit=math.max(10,tonumber(Config.ThreatDistance) or 55)
    if nearest and nearestDist<=limit then
        ThreatText.Text=string.format("%s  •  %dm",nearest.DisplayName,math.floor(nearestDist+.5))
        ThreatText.TextColor3=C.Bad
        if Config.ThreatPulse then
            threatPulseT+=(dt or .016)
            local pulse=(math.sin(threatPulseT*8)+1)*.5
            Threat.BackgroundTransparency=math.clamp((1-Config.HUDOpacity)+pulse*.12,0,.7)
        end
    else
        ThreatText.Text="NO IMMEDIATE THREATS"
        ThreatText.TextColor3=C.Good
        Threat.BackgroundTransparency=1-Config.HUDOpacity
    end
end

--========================================================
-- TARGET HUD
--========================================================
local TargetPanel=RoundFrame(CombatHUD,UDim2.fromOffset(286,82),UDim2.new(.5,-143,1,-100),145)
local TargetName=New("TextLabel",{Size=UDim2.new(1,-22,0,20),Position=UDim2.fromOffset(11,7),BackgroundTransparency=1,Text="NO TARGET",TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=146},TargetPanel)
local TargetMeta=New("TextLabel",{Size=UDim2.new(1,-22,0,16),Position=UDim2.fromOffset(11,28),BackgroundTransparency=1,Text="AIM ASSIST • IDLE",TextColor3=C.Sub,TextSize=7,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=146},TargetPanel)
local TargetBack=New("Frame",{Size=UDim2.new(1,-22,0,8),Position=UDim2.fromOffset(11,53),BackgroundColor3=C.Surface3,BorderSizePixel=0,ZIndex=146},TargetPanel);Corner(TargetBack,8)
local TargetHP=New("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Good,BorderSizePixel=0,ZIndex=147},TargetBack);Corner(TargetHP,8)
local function UpdateTargetHUD()
    if not Config.TargetHUD then TargetPanel.Visible=false;return end
    TargetPanel.Visible=true
    local p=CurrentAimPlayer
    local char=p and p.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not p or not hum or hum.Health<=0 or not root then
        TargetName.Text="NO TARGET";TargetMeta.Text="AIM ASSIST • IDLE";TargetHP.Size=UDim2.new(0,0,1,0);return
    end
    local me=Character();local myRoot=me and me:FindFirstChild("HumanoidRootPart")
    local d=myRoot and (root.Position-myRoot.Position).Magnitude or 0
    local ratio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
    TargetName.Text=p.DisplayName
    TargetMeta.Text=string.format("LOCKED • %dm • %d/%d HP",math.floor(d+.5),math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5))
    TargetHP.Size=UDim2.new(ratio,0,1,0)
    TargetHP.BackgroundColor3=ratio>.5 and C.Good or ratio>.25 and Color3.fromRGB(238,194,75) or C.Bad
end

--========================================================
-- DAMAGE / DEATH FEED
--========================================================
local FeedRoot=RoundFrame(CombatHUD,UDim2.fromOffset(270,158),UDim2.new(1,-288,1,-176),130)
local FeedTitle=New("TextLabel",{Size=UDim2.new(1,-18,0,18),Position=UDim2.fromOffset(9,6),BackgroundTransparency=1,Text="COMBAT FEED",TextColor3=C.Text,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=131},FeedRoot)
local FeedList=New("Frame",{Size=UDim2.new(1,-18,1,-31),Position=UDim2.fromOffset(9,27),BackgroundTransparency=1,ZIndex=131},FeedRoot)
New("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},FeedList)
local FeedItems={}

local function PushFeed(text,kind)
    local item=New("TextLabel",{Size=UDim2.new(1,0,0,22),BackgroundColor3=C.Surface2,BackgroundTransparency=.15,Text=text,TextColor3=kind=="death" and C.Bad or kind=="damage" and Color3.fromRGB(255,213,99) or C.Text,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=132,TextTruncate=Enum.TextTruncate.AtEnd},FeedList)
    Corner(item,6);Outline(item,C.Border,1,.45)
    New("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,5)},item)
    table.insert(FeedItems,1,item)
    while #FeedItems>math.max(1,math.floor(tonumber(Config.FeedLimit) or 5)) do
        local old=table.remove(FeedItems)
        pcall(function() old:Destroy() end)
    end
end

local LastHealth={}
local LastAlive={}
local function ScanCombatFeed()
    if not Config.DamageFeed and not Config.DeathFeed then FeedRoot.Visible=false;return end
    FeedRoot.Visible=true
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                local hp=hum.Health
                local old=LastHealth[player]
                if old and hp<old and Config.DamageFeed then
                    local delta=old-hp
                    if delta>=1 then PushFeed(string.format("DAMAGE  %s  -%d",player.DisplayName,math.floor(delta+.5)),"damage") end
                end
                if old and old>0 and hp<=0 and Config.DeathFeed then
                    PushFeed(string.format("DOWN  %s",player.DisplayName),"death")
                end
                LastHealth[player]=hp
                LastAlive[player]=hp>0
            end
        end
    end
end
Players.PlayerRemoving:Connect(function(player) LastHealth[player]=nil;LastAlive[player]=nil end)

--========================================================
-- COMPASS
--========================================================
local CompassRoot=New("Frame",{Size=UDim2.fromOffset(360,30),Position=UDim2.new(.5,-180,0,83),BackgroundTransparency=1,Visible=true,ZIndex=135},CombatHUD)
local CompassLabels={}
for i,labelText in ipairs({"N","NE","E","SE","S","SW","W","NW"}) do
    local l=New("TextLabel",{Size=UDim2.fromOffset(38,22),Position=UDim2.fromOffset((i-1)*45,4),BackgroundTransparency=1,Text=labelText,TextColor3=C.Sub,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=136},CompassRoot)
    table.insert(CompassLabels,l)
end
local function CameraHeading()
    local cam=workspace.CurrentCamera
    if not cam then return 0 end
    local look=cam.CFrame.LookVector
    local angle=math.deg(math.atan2(-look.X,-look.Z))
    return (angle%360+360)%360
end
local function UpdateCompass()
    if not Config.Compass then CompassRoot.Visible=false;return end
    CompassRoot.Visible=true
    local heading=CameraHeading()
    local dirs={"N","NE","E","SE","S","SW","W","NW"}
    local exact=heading/45
    for i,l in ipairs(CompassLabels) do
        local idx=math.floor(exact+(i-1)-3.5)%8+1
        local off=((i-1)-3.5)*45-(exact-math.floor(exact))*45
        l.Position=UDim2.fromOffset(161+off,4)
        l.Text=dirs[idx]
        local distance=math.abs(off)
        l.TextColor3=distance<24 and C.Text or C.Sub
        l.TextTransparency=math.clamp(distance/180,.05,.75)
    end
end

--========================================================
-- WATERMARK
--========================================================
local Watermark=New("TextLabel",{Size=UDim2.fromOffset(220,26),Position=UDim2.new(1,-235,0,12),BackgroundTransparency=1,Text=Config.WatermarkText,TextColor3=C.Sub,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=150},CombatHUD)
local WatermarkAccent=New("Frame",{Size=UDim2.fromOffset(3,13),Position=UDim2.new(1,-230,0,6),BackgroundColor3=C.Accent,BorderSizePixel=0,ZIndex=150},CombatHUD);Corner(WatermarkAccent,3)

local function UpdateHUDOpacity()
    local alpha=1-math.clamp(tonumber(Config.HUDOpacity) or .96,0,.99)
    if RadarRoot then RadarRoot.BackgroundTransparency=alpha end
    if Threat then Threat.BackgroundTransparency=alpha end
    if TargetPanel then TargetPanel.BackgroundTransparency=alpha end
    if FeedRoot then FeedRoot.BackgroundTransparency=alpha end
end

local function UpdateWatermark()
    Watermark.Visible=Config.Watermark
    Watermark.Text=tostring(Config.WatermarkText or "FPS PANEL PRO")
    Watermark.TextColor3=C.Sub
    WatermarkAccent.Visible=Config.Watermark
    WatermarkAccent.BackgroundColor3=C.Accent
    UpdateHUDOpacity()
end

--========================================================
-- MOBILE SAFE ZONE
--========================================================
local function ApplyHUDSafeZone()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local inset=Config.HUDSafeZone and 8 or 0
    RadarRoot.Position=UDim2.fromOffset(18,inset+18)
    Threat.Position=UDim2.new(.5,-143,inset+18)
    CompassRoot.Position=UDim2.new(.5,-180,inset+83)
end

--========================================================
-- THEME UI
--========================================================
Section(Pages.Settings,"THEMES","Switch the panel palette or build a custom accent color")
Action(Pages.Settings,"Cycle Theme",function()
    return "Theme: "..tostring(Config.ThemeName).." • tap to switch."
end,function()
    CycleTheme()
end,C.Accent)
Toggle(Pages.Settings,"Custom Accent","Use the RGB accent below as the active theme.",function() return Config.UseCustomAccent end,function(v)
    Config.UseCustomAccent=v
    if v then
        ApplyTheme("Custom")
    else
        local restore="Night Purple"
        if ThemePalettes[Config.ThemeName] and Config.ThemeName~="Custom" then restore=Config.ThemeName end
        ApplyTheme(restore)
    end
    SaveProfile(Config.ActiveProfile)
end)

local ThemePreview=New("Frame",{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.Surface,BorderSizePixel=0},Pages.Settings);Corner(ThemePreview,11);Outline(ThemePreview,C.Border)
local ThemePreviewDot=New("Frame",{Size=UDim2.fromOffset(28,28),Position=UDim2.fromOffset(11,10),BackgroundColor3=C.Accent,BorderSizePixel=0},ThemePreview);Corner(ThemePreviewDot,14)
local ThemePreviewText=New("TextLabel",{Size=UDim2.new(1,-58,0,17),Position=UDim2.fromOffset(50,7),BackgroundTransparency=1,Text="ACTIVE ACCENT",TextColor3=C.Text,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},ThemePreview)
local ThemePreviewValue=New("TextLabel",{Size=UDim2.new(1,-58,0,17),Position=UDim2.fromOffset(50,24),BackgroundTransparency=1,Text="130 / 92 / 255",TextColor3=C.Sub,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},ThemePreview)

local function ThemePreviewRefresh()
    ThemePreviewDot.BackgroundColor3=C.Accent
    ThemePreviewValue.Text=string.format("%d / %d / %d",math.floor(Config.CustomAccentR),math.floor(Config.CustomAccentG),math.floor(Config.CustomAccentB))
end
table.insert(Refreshers,ThemePreviewRefresh)

Slider(Pages.Settings,"Accent Red","Custom accent red channel.",0,255,1,function() return Config.CustomAccentR end,function(v)
    Config.CustomAccentR=v
    if Config.UseCustomAccent then ApplyTheme("Custom") else ThemePreviewRefresh() end
end)
Slider(Pages.Settings,"Accent Green","Custom accent green channel.",0,255,1,function() return Config.CustomAccentG end,function(v)
    Config.CustomAccentG=v
    if Config.UseCustomAccent then ApplyTheme("Custom") else ThemePreviewRefresh() end
end)
Slider(Pages.Settings,"Accent Blue","Custom accent blue channel.",0,255,1,function() return Config.CustomAccentB end,function(v)
    Config.CustomAccentB=v
    if Config.UseCustomAccent then ApplyTheme("Custom") else ThemePreviewRefresh() end
end)
Action(Pages.Settings,"Apply Custom Accent","Apply the RGB values to the full interface.",function()
    ApplyTheme("Custom")
end,C.Accent)

--========================================================
-- ESP ADVANCED UI
--========================================================
Section(Pages.Visuals,"ESP ENHANCER 7.0","Precision styling, readable joints, adaptive fade and lifecycle cleanup")
Action(Pages.Visuals,"Box Style",function() return "Style: "..tostring(Config.ESPBoxStyle).." • tap to cycle." end,function()
    local modes={"Corners","Bracket","Full"};local i=table.find(modes,Config.ESPBoxStyle) or 1;Config.ESPBoxStyle=modes[i%#modes+1];SaveProfile(Config.ActiveProfile)
end,C.Accent)
Action(Pages.Visuals,"Tracer Origin",function() return "Origin: "..tostring(Config.ESPLineStyle).." • tap to cycle." end,function()
    local modes={"Bottom","Center","Crosshair"};local i=table.find(modes,Config.ESPLineStyle) or 1;Config.ESPLineStyle=modes[i%#modes+1];SaveProfile(Config.ActiveProfile)
end,C.Accent)
Slider(Pages.Visuals,"Skeleton Thickness","Readable bone width.",1,3,1,function() return Config.ESPSkeletonThickness end,function(v) Config.ESPSkeletonThickness=v end)
Slider(Pages.Visuals,"Joint Size","Joint node diameter.",3,8,1,function() return Config.ESPJointSize end,function(v) Config.ESPJointSize=v end)
Toggle(Pages.Visuals,"ESP Fade","Softens distant overlays without hiding them.",function() return Config.ESPFade end,function(v) Config.ESPFade=v end)
Slider(Pages.Visuals,"Fade Distance","Distance at which fade reaches maximum.",100,1500,10,function() return Config.ESPFadeDistance end,function(v) Config.ESPFadeDistance=v end)
Toggle(Pages.Visuals,"Health Bar","Show the compact health bar inside the ESP card.",function() return Config.ESPHealthBar end,function(v) Config.ESPHealthBar=v end)
Toggle(Pages.Visuals,"Display State","Show movement/state below player name.",function() return Config.ESPShowState end,function(v) Config.ESPShowState=v end)
Toggle(Pages.Visuals,"Display Username","Show @username under the display name.",function() return Config.ESPShowUsername end,function(v) Config.ESPShowUsername=v end)

--========================================================
-- HUD FEATURE UI
--========================================================
Section(Pages.Interface,"TACTICAL HUD","Live information that stays outside the aimbot camera path")
Toggle(Pages.Interface,"FOV Ring","Render a clean segmented FOV guide around the cursor.",function() return Config.FOVRing end,function(v) Config.FOVRing=v end)
Slider(Pages.Interface,"Ring Thickness","FOV ring line thickness.",1,3,1,function() return Config.FOVRingThickness end,function(v) Config.FOVRingThickness=v;RebuildFOVRing() end)
Slider(Pages.Interface,"Ring Segments","Smoothness of the FOV ring.",24,96,4,function() return Config.FOVRingSegments end,function(v) Config.FOVRingSegments=v;RebuildFOVRing() end)
Toggle(Pages.Interface,"Tactical Radar","Top-left proximity map.",function() return Config.Radar end,function(v) Config.Radar=v end)
Slider(Pages.Interface,"Radar Size","Radar footprint.",100,230,5,function() return Config.RadarSize end,function(v) Config.RadarSize=v end)
Slider(Pages.Interface,"Radar Range","Maximum radar range.",50,500,10,function() return Config.RadarRange end,function(v) Config.RadarRange=v end)
Toggle(Pages.Interface,"Radar Grid","Show the tactical grid.",function() return Config.RadarGrid end,function(v) Config.RadarGrid=v;MakeRadarGrid() end)
Toggle(Pages.Interface,"Rotate Radar","Orient radar with the camera heading.",function() return Config.RadarRotate end,function(v) Config.RadarRotate=v end)
Toggle(Pages.Interface,"Compass","Show a subtle heading compass.",function() return Config.Compass end,function(v) Config.Compass=v end)
Toggle(Pages.Interface,"Threat Warning","Show the nearest enemy warning.",function() return Config.ThreatWarning end,function(v) Config.ThreatWarning=v end)
Slider(Pages.Interface,"Threat Distance","Distance for the threat warning.",20,150,5,function() return Config.ThreatDistance end,function(v) Config.ThreatDistance=v end)
Toggle(Pages.Interface,"Threat Pulse","Pulse the threat card when an enemy is close.",function() return Config.ThreatPulse end,function(v) Config.ThreatPulse=v end)
Toggle(Pages.Interface,"Target HUD","Show the currently locked target.",function() return Config.TargetHUD end,function(v) Config.TargetHUD=v end)
Toggle(Pages.Interface,"Damage Feed","Show observed enemy health reductions.",function() return Config.DamageFeed end,function(v) Config.DamageFeed=v end)
Toggle(Pages.Interface,"Death Feed","Show observed player deaths.",function() return Config.DeathFeed end,function(v) Config.DeathFeed=v end)
Slider(Pages.Interface,"Feed Limit","Maximum combat feed entries.",2,8,1,function() return Config.FeedLimit end,function(v) Config.FeedLimit=v end)
Toggle(Pages.Interface,"Watermark","Show a small panel watermark.",function() return Config.Watermark end,function(v) Config.Watermark=v end)
Action(Pages.Interface,"Reset HUD Layout","Restore tactical HUD positions and safe margins.",function()
    RadarRoot.Position=UDim2.fromOffset(18,18);Threat.Position=UDim2.new(.5,-143,0,18);CompassRoot.Position=UDim2.new(.5,-180,0,83);Watermark.Position=UDim2.new(1,-235,0,12)
end,C.Good)
Slider(Pages.Interface,"HUD Opacity","Transparency balance for tactical panels.",0.55,1,0.05,function() return Config.HUDOpacity end,function(v) Config.HUDOpacity=v;UpdateHUDOpacity() end)
Toggle(Pages.Interface,"Mobile Safe Zone","Adds extra top safe-area spacing.",function() return Config.HUDSafeZone end,function(v) Config.HUDSafeZone=v end)

Section(Pages.Performance,"ADAPTIVE RENDERING","Scale overlay work down slightly on slower clients")
Toggle(Pages.Performance,"Adaptive ESP","Reduce ESP update pressure as FPS falls.",function() return Config.AdaptiveESP end,function(v) Config.AdaptiveESP=v end)
Toggle(Pages.Performance,"Adaptive Radar","Skip radar refreshes on low FPS.",function() return Config.AdaptiveRadar end,function(v) Config.AdaptiveRadar=v end)

--========================================================
-- THEME INITIALIZATION
--========================================================
if Config.UseCustomAccent then
    ApplyTheme("Custom")
elseif ThemePalettes[Config.ThemeName] then
    ApplyTheme(Config.ThemeName)
else
    Config.ThemeName="Night Purple"
    ApplyTheme("Night Purple")
end
ThemePreviewRefresh()
UpdateWatermark()
ApplyHUDSafeZone()

--========================================================
-- DYNAMIC CROSSHAIR ENHANCEMENT
--========================================================
local CrosshairPulse=0
local function UpdateEnhancedCrosshair(dt)
    CrosshairPulse+=(dt or .016)
    local h=Humanoid()
    local moving=h and h.MoveDirection.Magnitude or 0
    local dynamic=Config.Crosshair and (moving>.05 and 1 or 0)
    local pulse=Config.Crosshair and (math.sin(CrosshairPulse*7)*.75+.75) or 0
    local size=tonumber(Config.CrosshairSize) or 8
    local gap=tonumber(Config.CrosshairGap) or 4
    if dynamic>0 then size=size+math.floor(pulse*2+.5);gap=gap+math.floor(pulse+1) end
    local thick=tonumber(Config.CrosshairThickness) or 2
    ChTop.Size=UDim2.fromOffset(thick,size);ChTop.Position=UDim2.new(.5,-thick/2,0,-gap-size)
    ChBottom.Size=UDim2.fromOffset(thick,size);ChBottom.Position=UDim2.new(.5,-thick/2,0,gap)
    ChLeft.Size=UDim2.fromOffset(size,thick);ChLeft.Position=UDim2.new(0,-gap-size,.5,-thick/2)
    ChRight.Size=UDim2.fromOffset(size,thick);ChRight.Position=UDim2.new(0,gap,.5,-thick/2)
    Crosshair.Visible=Config.Crosshair
end

--========================================================
-- PANEL MICRO-ANIMATION QUALITY
--========================================================
local panelPulse=0
local function UpdatePanelMicro(dt)
    panelPulse+=(dt or .016)
    local glow=.5+.5*math.sin(panelPulse*1.7)
    Dot.BackgroundColor3=C.Accent
    if visible then
        local a=.25+.06*glow
        Dot.BackgroundTransparency=a
    else
        Dot.BackgroundTransparency=0
    end
end

--========================================================
-- PROFILE INTEGRATION
--========================================================
local function SaveEnhancedProfile()
    Config.ThemeName=CurrentPaletteName
    Config.UseCustomAccent=(CurrentPaletteName=="Custom")
    SaveProfile(Config.ActiveProfile)
end

-- Add explicit save action after enhancements are installed.
Action(Pages.Settings,"Save Theme + HUD","Persist the current theme, ESP styling and tactical HUD layout.",function()
    SaveEnhancedProfile()
end,C.Good)

--========================================================
-- SAFE LIFE-CYCLE REFRESH
--========================================================
local lastCharacterEnhance=nil
local function EnhancementCharacterRefresh()
    local c=Character()
    if c~=lastCharacterEnhance then
        lastCharacterEnhance=c
        table.clear(LastHealth)
        table.clear(LastAlive)
    end
end

--========================================================
-- ADAPTIVE TIMERS
--========================================================
local enhancedRadarT=0
local enhancedFeedT=0
local enhancedHudT=0
local enhancedThemeT=0
local function GetEnhancedESPInterval()
    local base=math.max(.03,tonumber(Config.ESPUpdateRate) or .06)
    if not Config.AdaptiveESP then return base end
    local fps=tonumber(fpsValue) or 60
    if fps<30 then return math.max(base,.16) end
    if fps<40 then return math.max(base,.12) end
    if fps<50 then return math.max(base,.09) end
    return base
end

--========================================================
-- OVERRIDE THE EXISTING ESP TIMER WITH ADAPTIVE INTERVAL
--========================================================
-- The main loop itself remains untouched; the exported config value is adjusted
-- transiently here and restored after the frame so other UI keeps the user value.
--========================================================
-- ENHANCEMENT UPDATE LOOP
--========================================================
RunService:BindToRenderStep("FPSPanel_EnhancementHUD",Enum.RenderPriority.Last.Value,function(dt)
    dt=dt or .016
    EnhancementCharacterRefresh()
    UpdateEnhancedCrosshair(dt)
    UpdateFOVRing()
    enhancedRadarT+=dt
    enhancedFeedT+=dt
    enhancedHudT+=dt
    enhancedThemeT+=dt

    local radarInterval=.075
    if Config.AdaptiveRadar then
        local fps=tonumber(fpsValue) or 60
        if fps<30 then radarInterval=.20 elseif fps<45 then radarInterval=.12 end
    end
    if enhancedRadarT>=radarInterval then
        enhancedRadarT=0
        UpdateRadar()
    end
    if enhancedFeedT>=.25 then
        enhancedFeedT=0
        ScanCombatFeed()
    end
    if enhancedHudT>=.08 then
        enhancedHudT=0
        UpdateThreat(dt)
        UpdateTargetHUD()
        UpdateCompass()
        UpdateWatermark()
        ApplyHUDSafeZone()
    end
    if enhancedThemeT>=.65 then
        enhancedThemeT=0
        if Config.ThemeName~=CurrentPaletteName then
            if Config.ThemeName=="Custom" then ApplyTheme("Custom") elseif ThemePalettes[Config.ThemeName] then ApplyTheme(Config.ThemeName) end
        end
    end
end)

--========================================================
-- NON-REENTRANT RESPAWN / OVERLAY GUARD
--========================================================
local enhancementAlive=true
local function EnhancementCleanup()
    if not enhancementAlive then return end
    enhancementAlive=false
    pcall(function() RunService:UnbindFromRenderStep("FPSPanel_EnhancementHUD") end)
    for _,b in pairs(RadarBlips) do
        if b.dot then pcall(function() b.dot:Destroy() end) end
        if b.text then pcall(function() b.text:Destroy() end) end
    end
    table.clear(RadarBlips)
end
Players.LocalPlayer.CharacterRemoving:Connect(function()
    task.defer(function()
        if not LocalPlayer.Character then
            table.clear(LastHealth)
            table.clear(LastAlive)
        end
    end)
end)

--========================================================
-- FINAL FEATURE STATUS INFO
--========================================================
Info(Pages.Settings,"Enhancement 7.0","Themes, custom RGB, tactical radar, FOV ring, threat monitor, target HUD, damage/death feed, adaptive rendering and lifecycle-safe ESP.",C.Good)
Info(Pages.Visuals,"Skeleton upgrade","Joints, shoulders, elbows, wrists, hips, knees and ankles now use a clean outlined bone model instead of bare stick segments.",C.Good)
Info(Pages.Interface,"Tactical layer","All HUD modules run in their own ScreenGui and never write to Camera.CFrame.",C.Accent)

--========================================================
-- VALIDATION GUARDS
--========================================================
local function GuardNumber(name,minValue,maxValue)
    local v=tonumber(Config[name])
    if not v then Config[name]=minValue;return end
    Config[name]=math.clamp(v,minValue,maxValue)
end
GuardNumber("CustomAccentR",0,255)
GuardNumber("CustomAccentG",0,255)
GuardNumber("CustomAccentB",0,255)
GuardNumber("ESPSkeletonThickness",1,3)
GuardNumber("ESPJointSize",3,8)
GuardNumber("ESPFadeDistance",100,1500)
GuardNumber("FOVRingThickness",1,3)
GuardNumber("FOVRingSegments",24,96)
GuardNumber("FOVRingAlpha",.02,.75)
GuardNumber("RadarSize",100,230)
GuardNumber("RadarRange",50,500)
GuardNumber("ThreatDistance",20,150)
GuardNumber("FeedLimit",2,8)
GuardNumber("HUDOpacity",.55,1)
GuardNumber("DamageTextDuration",.35,2)

--========================================================
-- EXTRA QUALITY HELPERS (small, reusable, non-invasive)
--========================================================
local function SafeVisible(obj,v)
    if obj then obj.Visible=not not v end
end
local function SafeText(obj,text)
    if obj then obj.Text=tostring(text or "") end
end
local function SafeColor(obj,color)
    if obj and typeof(color)=="Color3" then obj.BackgroundColor3=color end
end
local function SafeTextColor(obj,color)
    if obj and typeof(color)=="Color3" then obj.TextColor3=color end
end
local function SafeDisconnect(conn)
    if conn then pcall(function() conn:Disconnect() end) end
end
local function SafeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end
local function IsAlivePlayer(player)
    local char=player and player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return char and char.Parent and hum and hum.Parent and hum.Health>0
end
local function PlayerDistance(player,origin)
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root or typeof(origin)~="Vector3" then return math.huge end
    return (root.Position-origin).Magnitude
end
local function CurrentLocalRoot()
    local c=Character();return c and c:FindFirstChild("HumanoidRootPart")
end
local function ViewportPoint(point)
    local cam=workspace.CurrentCamera
    if not cam or typeof(point)~="Vector3" then return nil end
    local p=cam:WorldToViewportPoint(point)
    return Vector2.new(p.X,p.Y),p.Z>0
end
local function ClampScreenPoint(point,margin)
    local cam=workspace.CurrentCamera
    if not cam then return point end
    local view=cam.ViewportSize
    local m=margin or 0
    return Vector2.new(math.clamp(point.X,m,view.X-m),math.clamp(point.Y,m,view.Y-m))
end
local function ThemeAccent()
    return C.Accent
end
local function ThemeGood()
    return C.Good
end
local function ThemeBad()
    return C.Bad
end
local function ThemeSurface()
    return C.Surface
end
local function ThemeBorder()
    return C.Border
end
local function ThemeText()
    return C.Text
end
local function ThemeMuted()
    return C.Muted
end
local function ThemeSub()
    return C.Sub
end

--========================================================
-- DEEP CLEANUP SWEEP
--========================================================
local function SweepManagedESP()
    pcall(function()
        for _,obj in ipairs(PlayerGui:GetChildren()) do
            if obj.Name=="FPSPremiumESP" or obj.Name=="FPSESPOverlay" then
                if obj~=ESPGui then obj:Destroy() end
            end
        end
    end)
    pcall(function()
        for _,obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Highlight") and obj:GetAttribute("FPSESPManaged") and obj.Parent==workspace then
                local adornee=obj.Adornee
                local hum=adornee and adornee:FindFirstChildOfClass("Humanoid")
                if not adornee or not adornee.Parent or not hum or hum.Health<=0 then obj:Destroy() end
            end
        end
    end)
end

local sweepT=0
RunService:BindToRenderStep("FPSPanel_ESPCleanupGuard",Enum.RenderPriority.Last.Value-1,function(dt)
    sweepT+=(dt or .016)
    if sweepT>=2 then
        sweepT=0
        SweepManagedESP()
    end
end)

--========================================================
-- SETTINGS REFRESH PATCH
--========================================================
local function RefreshEnhancementWidgets()
    ThemePreviewRefresh()
    UpdateWatermark()
    UpdateFOVRing()
    UpdateRadar()
    UpdateCompass()
end

table.insert(Refreshers,RefreshEnhancementWidgets)

--========================================================
-- LOAD-SAFETY MIGRATION
--========================================================
-- Profiles written by older versions simply miss the new keys.
local EnhancementDefaults={
    ThemeName="Night Purple",CustomAccentR=130,CustomAccentG=92,CustomAccentB=255,UseCustomAccent=false,
    ESPBoxStyle="Corners",ESPLineStyle="Bottom",ESPSkeletonThickness=2,ESPJointSize=4,ESPFade=true,ESPFadeDistance=600,
    ESPHealthBar=true,ESPNameOutline=true,ESPDistanceUnits="Studs",ESPShowDisplayName=true,ESPShowUsername=false,ESPShowState=true,
    FOVRing=true,FOVRingThickness=1,FOVRingSegments=48,FOVRingAlpha=.18,Radar=true,RadarSize=150,RadarRange=180,RadarRotate=true,
    RadarBlips=true,RadarGrid=true,Compass=true,CompassScale=1,ThreatWarning=true,ThreatDistance=55,ThreatPulse=true,
    TargetHUD=true,TargetHUDCompact=false,DamageFeed=true,DamageTextDuration=.85,DeathFeed=true,FeedLimit=5,Watermark=true,
    WatermarkText="FPS PANEL PRO",AdaptiveESP=true,AdaptiveRadar=true,HUDSafeZone=true,HUDOpacity=.96,
}
for key,value in pairs(EnhancementDefaults) do
    if Config[key]==nil then Config[key]=value end
end

--========================================================
-- FINAL THEME SYNC AFTER MIGRATION
--========================================================
if Config.UseCustomAccent then ApplyTheme("Custom") else ApplyTheme(Config.ThemeName) end
ThemePreviewRefresh()

--========================================================
end

FPSPanel_InitEnhancements()

-- END ENHANCEMENT PACK 7.0
--========================================================
print("FPS PANEL PRO 7.0 loaded | Enhanced ESP / Themes / Radar / Threat HUD / FOV Ring | Only hotkey: O")


-- Remember the active profile for the next execution in the same environment.
Env.FPSPanelLastActiveProfile = Config.ActiveProfile
SaveProfile(Config.ActiveProfile)
