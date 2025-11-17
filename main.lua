--i know this shitty paste and claude axxx so dont be agro niggers
local repo =
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager =
    loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Suomi',
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab('Aiming'),
    Visuals = Window:AddTab('Visuals'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local Camera = workspace.CurrentCamera
local UserInputService = game:GetService('UserInputService')
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')

local Client = {}
local maxAttempts = 10
local attemptCount = 0
local success = false

while attemptCount < maxAttempts and not success do
    attemptCount = attemptCount + 1
    success = true

    for _, v in next, getgc(true) do
        if type(v) == 'table' then
            if
                rawget(v, 'Fire')
                and type(rawget(v, 'Fire')) == 'function'
                and not Client.Bullet
            then
                Client.Bullet = v
            elseif rawget(v, 'HiddenUpdate') then
                local successUpvalue, players = pcall(function()
                    return debug.getupvalue(rawget(v, 'new'), 9)
                end)

                if successUpvalue and players then
                    Client.Players = players
                else
                    success = false
                end
            end
        end
    end

    if not Client.Bullet or not Client.Players then
        wait(0.5)
    end
end

if not success then
    return
end

local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 100,
        ShowFOV = false,
    },
    ESP = {
        Enabled = false,
        Color = Color3.fromRGB(0, 191, 255),
    },
}

local espObjects = {}
local currentTarget = nil
local fovCircle = nil

-- Create FOV Circle
local function createFOVCircle()
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.NumSides = 64
        fovCircle.Radius = Config.Aimbot.FOV
        fovCircle.Filled = false
        fovCircle.Transparency = 1
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Visible = false
    end
end

local function updateFOVCircle()
    if fovCircle then
        local mouseLocation = UserInputService:GetMouseLocation()
        fovCircle.Position = Vector2.new(mouseLocation.X, mouseLocation.Y)
        fovCircle.Radius = Config.Aimbot.FOV
        fovCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled
    end
end

createFOVCircle()

function Client:GetPlayerHitbox(player, hitbox)
    for _, player_hitbox in next, player.Hitboxes do
        if player_hitbox._name == hitbox then
            return player_hitbox
        end
    end
end

function Client:GetClosestPlayerFromScreen()
    local nearest_player, min_combined_score = nil, math.huge
    local camera_position = Camera.CFrame.Position
    local cursor_position = UserInputService:GetMouseLocation()

    for _, player in next, Client.Players do
        local model = player.PlayerModel and player.PlayerModel.Model
        if model and model.Head.Transparency ~= 1 then
            local screen_pos, is_visible =
                Camera:WorldToViewportPoint(player.Position)
            if is_visible then
                local distance_to_camera = (player.Position - camera_position).Magnitude
                local distance_to_cursor = (cursor_position - Vector2.new(
                    screen_pos.X,
                    screen_pos.Y
                )).Magnitude

                -- Check if within FOV
                if distance_to_cursor <= Config.Aimbot.FOV then
                    local combined_score = distance_to_camera * 0.7
                        + distance_to_cursor * 0.3

                    if combined_score < min_combined_score then
                        min_combined_score = combined_score
                        nearest_player = player
                    end
                end
            end
        end
    end

    return nearest_player
end

local last_hitbox = nil

function Client:GetTargetHitbox(target)
    if last_hitbox and last_hitbox.Parent == target.PlayerModel.Model then
        return last_hitbox
    end

    for _, hitbox_name in
        next,
        { 'Head', 'Torso', 'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg' }
    do
        local player_hitbox = Client:GetPlayerHitbox(target, hitbox_name)
        if player_hitbox then
            last_hitbox = player_hitbox
            return player_hitbox
        end
    end

    last_hitbox = nil
    return nil
end

local function createESP(player)
    if Config.ESP.Enabled and player.PlayerModel then
        local highlight = Instance.new('Highlight')
        highlight.Parent = player.PlayerModel.Model
        highlight.FillColor = Config.ESP.Color
        highlight.FillTransparency = 0.8
        highlight.OutlineColor = Config.ESP.Color
        highlight.OutlineTransparency = 0.7

        espObjects[player] = { highlight = highlight }

        local tweenInfoIn =
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tweenIn = TweenService:Create(
            highlight,
            tweenInfoIn,
            { FillTransparency = 0.7 }
        )
        tweenIn:Play()

        local colorTweenInfo = TweenInfo.new(
            2,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut,
            -1,
            true
        )
        local colorTween = TweenService:Create(
            highlight,
            colorTweenInfo,
            { OutlineColor = Color3.new(1, 0, 0) }
        )
        colorTween:Play()
    end
end

local function cleanupESP(player)
    if espObjects[player] then
        local highlight = espObjects[player].highlight
        highlight:Destroy()
        espObjects[player] = nil
    end
end

local function updateESP()
    for _, player in next, Client.Players do
        if
            player.PlayerModel
            and not player.Dead
            and not espObjects[player]
        then
            createESP(player)
        elseif not player.PlayerModel or player.Dead then
            cleanupESP(player)
        end
    end
end

local function updateESPColors()
    for player, data in pairs(espObjects) do
        if data and data.highlight then
            data.highlight.FillColor = Config.ESP.Color
            data.highlight.OutlineColor = Config.ESP.Color
        end
    end
end

local function updateTargetHighlight(target)
    for player, data in pairs(espObjects) do
        local highlight = data.highlight
        if player == target then
            highlight.OutlineColor = Color3.new(1.000000, 0.400000, 0.000000)
        else
            highlight.OutlineColor = Config.ESP.Color
        end
    end
end

local originalFire = Client.Bullet.Fire
Client.Bullet.Fire = function(self, ...)
    local args = { ... }

    if Config.Aimbot.Enabled then
        local target = Client:GetClosestPlayerFromScreen()
        local targetHitbox = target and Client:GetTargetHitbox(target)

        if targetHitbox and target.Health > 0 then
            args[2] = (targetHitbox.CFrame.Position - Camera.CFrame.Position).Unit
            currentTarget = target
            updateTargetHighlight(target)
        else
            currentTarget = nil
            updateTargetHighlight(nil)
            return originalFire(self, ...)
        end
    else
        return originalFire(self, ...)
    end

    return originalFire(self, unpack(args))
end

RunService.RenderStepped:Connect(function()
    if Config.ESP.Enabled then
        updateESP()
    end
    updateFOVCircle()
end)

-- Aiming Tab
local AimingLeft = Tabs.Main:AddLeftGroupbox('Silent Aimbot')

AimingLeft:AddToggle('SilentAim', {
    Text = 'Enabled',
    Default = false,
    Tooltip = 'Toggle silent aimbot',
})

Toggles.SilentAim:OnChanged(function()
    Config.Aimbot.Enabled = Toggles.SilentAim.Value
end)

AimingLeft:AddToggle('ShowFOV', {
    Text = 'Show FOV Circle',
    Default = false,
    Tooltip = 'Show FOV circle on screen',
})

Toggles.ShowFOV:OnChanged(function()
    Config.Aimbot.ShowFOV = Toggles.ShowFOV.Value
end)

AimingLeft:AddSlider('FOVSize', {
    Text = 'FOV Size',
    Default = 100,
    Min = 20,
    Max = 500,
    Rounding = 0,
    Compact = false,
})

Options.FOVSize:OnChanged(function()
    Config.Aimbot.FOV = Options.FOVSize.Value
end)

-- Visuals Tab
local VisualsLeft = Tabs.Visuals:AddLeftGroupbox('ESP')

VisualsLeft:AddToggle('ESPToggle', {
    Text = 'Enabled',
    Default = false,
    Tooltip = 'Toggle wallhack/ESP',
})

Toggles.ESPToggle:OnChanged(function()
    Config.ESP.Enabled = Toggles.ESPToggle.Value

    if not Config.ESP.Enabled then
        for _, esp in pairs(espObjects) do
            if esp then
                esp.highlight:Destroy()
            end
        end
        espObjects = {}
    end
end)

VisualsLeft:AddLabel('ESP Color'):AddColorPicker('ESPColor', {
    Default = Color3.fromRGB(0, 191, 255),
    Title = 'ESP Color',
    Transparency = 0,
})

Options.ESPColor:OnChanged(function()
    Config.ESP.Color = Options.ESPColor.Value
    updateESPColors()
end)

local VisualsRight = Tabs.Visuals:AddRightGroupbox('Performance')

VisualsRight:AddToggle('FPSBoost', {
    Text = 'FPS Boost',
    Default = false,
    Tooltip = 'Disable shadows and effects for better performance',
})

Toggles.FPSBoost:OnChanged(function()
    local l = game.Lighting

    if Toggles.FPSBoost.Value then
        l.GlobalShadows = false
        l.Ambient = Color3.fromRGB(255, 255, 255)
        l.Brightness = 1
        l.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        l.Technology = Enum.Technology.Voxel

        for _, effect in ipairs(l:GetChildren()) do
            if
                effect:IsA('BloomEffect')
                or effect:IsA('DepthOfFieldEffect')
                or effect:IsA('SunRaysEffect')
            then
                effect.Enabled = false
            end
        end
    else
        l.GlobalShadows = true
        l.Technology = Enum.Technology.ShadowMap

        for _, effect in ipairs(l:GetChildren()) do
            if
                effect:IsA('BloomEffect')
                or effect:IsA('DepthOfFieldEffect')
                or effect:IsA('SunRaysEffect')
            then
                effect.Enabled = true
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent then
        if input.KeyCode == Enum.KeyCode.T then
            Toggles.SilentAim:SetValue(not Toggles.SilentAim.Value)
        elseif input.KeyCode == Enum.KeyCode.P then
            Toggles.ESPToggle:SetValue(not Toggles.ESPToggle.Value)
        end
    end
end)

Library:SetWatermarkVisibility(false)

Library.KeybindFrame.Visible = false

Library:OnUnload(function()
    Library.Unloaded = true
    if fovCircle then
        fovCircle:Remove()
    end
end)

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function()
    Library:Unload()
end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker(
    'MenuKeybind',
    { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' }
)
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('Suomi')
SaveManager:SetFolder('Suomi/Config')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
