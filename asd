--[[
═══════════════════════════════════════════════════════════════════════════════
    AUTO FISHING + ELEMENT SYSTEM v5.3 TURBO (ZERO ANIMATIONS OPTIMIZED)

    Features:
    - Auto Fishing with Toggle ON/OFF
    - Auto Element (Quest Tracking + Auto Teleport)
    - Auto Weather (Wind, Cloudy, Storm)
    - Teleport System
    - Inventory Detection (Fish & Items)
    - WindUI Integration

    REMOVED IN THIS VERSION:
    ✘ Animation system (disabled for performance)
    ✘ Auto Farm (Element Tab) - use main Auto Farm tab instead

    V4.9.1 TURBO UPDATES (ZERO ANIMATION MODE):
    ✅ AnimationController hook - disables ALL fishing animations when auto farm ON
    ✅ PlayAnimation hook - blocks 12+ fishing animations dynamically
    ✅ StopAnimation hook - prevents animation stop errors
    ✅ IsDisabled hook - reports fishing animations as disabled
    ✅ Auto-reinstall hooks on character respawn
    ✅ Animations work normally when auto farm is OFF
    ✅ Speed improvement: 2-3x faster (saves ~1.4s per fishing cycle)

    Animations disabled during auto farm:
    - StartRodCharge, LoopedRodCharge (charging animations)
    - RodThrow (critical ~0.6s delay animation)
    - ReelIntermission, ReelStart (reel animations)
    - FishCaught, FishingFailure (completion animations)
    - EquipIdle, EquipIdleFake (idle animations)
    - HoldFish, IdleLoop, WalkLoop (misc animations)

    V5 UPDATES (Anti-Drown & Death Protection):
    ✅ Enhanced position lock (999999 force, 50000 P value)
    ✅ Y-axis drift detection (0.5 stud threshold)
    ✅ Overall position drift detection (2 stud threshold)
    ✅ Death detection system with auto-cleanup
    ✅ Emergency unfreeze on death
    ✅ Character validation before each cycle
    ✅ Health check during cycles
    ✅ Auto-resume after respawn

    V5.2 UPDATES (ANIMATION OPTIMIZATION):
    ✅ State-based animation blocking (no per-cycle checks)
    ✅ Animation blocks set once at start, not every frame
    ✅ Removed animation spam prints for cleaner console
    ✅ Optimized hooks for better performance
    ✅ Simplified fishing logic for faster execution

    V5.3 UPDATES (AUTO-DELETE ANIMATIONS & FPS UNLOCK):
    ✅ Auto-delete ALL animations on script execution (walk, jump, fall, climb, swim, fishing)
    ✅ Auto-delete animations on character respawn
    ✅ Removed manual "Delete Animations" button - fully automatic now
    ✅ FPS Unlock button (setfpscap to 240)
    ✅ Freeze Character toggle remains separate from Auto Farm
    ✅ GPU Saver fully functional with white screen overlay

    Structure:
    1. DEPENDENCIES & SETUP
    2. AUTO FARM MODULE
    3. INVENTORY MODULE
    4. AUTO ELEMENT MODULE (V5)
    5. AUTO WEATHER MODULE
    6. TELEPORT MODULE
    7. UI MODULE
    8. MAIN EXECUTION

    Usage:
    loadstring(readfile("auto_farm_v5_elemen.lua"))()
═══════════════════════════════════════════════════════════════════════════════
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO FISHING SYSTEM v5.3 TURBO (NO KEY PROTECTION)
-- ═══════════════════════════════════════════════════════════════════════════

print(string.rep("=", 80))
print("🚀 AUTO FISHING SYSTEM v5.3 TURBO (ZERO ANIMATIONS OPTIMIZED)")
print("✅ Animation Hook System | 2-3x Faster | Optimized Performance")
print(string.rep("=", 80))
print("\n⏳ Loading optimized modules...\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: DEPENDENCIES & SETUP
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    This section handles all service references and initial setup.
    DO NOT MODIFY unless you need to add new services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Global State Variables
_G.AUTO_FARM_ENABLED = false
_G.FARM_SUCCESS_DELAY = 1
_G.AUTO_FARM_V2_ENABLED = false   -- Jung V2 Fast Auto Farm
_G.AUTO_ARTIFACT_ENABLED = false  -- Auto Artifact state
_G.AUTO_SELL_ENABLED = false      -- Auto Sell state
_G.AUTO_SELL_DELAY = 60           -- Auto Sell delay in seconds (default 60s)
_G.AUTO_ELEMENT_ENABLED = false   -- Auto Element state
_G.AUTO_ELEMENT_FARM_ENABLED = false  -- Auto Farm (Element Tab) state
_G.ELEMENT_FARM_WAIT = 1          -- Custom wait before complete (default 1s)
_G.ELEMENT_FARM_AFTER_COMPLETE_WAIT = 1  -- Custom wait after complete before loop restart (default 1s)
_G.AUTO_WEATHER_ENABLED = false   -- Auto Weather state
_G.WEATHER_PURCHASE_DELAY = 32    -- Delay between weather purchase cycles (default 32s)
_G.FREEZE_CHAR_ENABLED = false    -- Freeze Character state
_G.GPU_SAVER_ENABLED = false       -- GPU Saver state
_G.AUTO_UPGRADE_ROD_ENABLED = false  -- Auto Upgrade Rod state
_G.AUTO_UPGRADE_BAIT_ENABLED = false -- Auto Upgrade Bait state

-- Jung V2 State Variables (Auto Farm V2)
_G.JUNG_V2_STATE = {
    isRunning = false,
    fishCaught = 0,
    cycleCount = 0,
    startTime = 0,

    -- Custom Delays
    delayReel = 1.5,        -- Base delay before each cycle
    delayComplete = 0.7,    -- Base delay after server return

    -- Stats
    pendingCompletes = 0,
    totalRequests = 0,

    -- Ping Compensation
    autoPingCompensation = true,
    currentPing = 0,
    baseDelayReel = 1.5,
    baseDelayComplete = 0.7,
}

-- Freeze Character state variables
local freezeCharBodyVelocity = nil
local freezeCharBodyGyro = nil
local freezeCharLockedCFrame = nil
local freezeCharLockConnection = nil
local freezeCharLockActive = false

print("✅ Services loaded")

-- Required Modules
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
local VendorUtility = require(ReplicatedStorage.Shared.VendorUtility)
local Replion = require(ReplicatedStorage.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")

print("✅ Game modules loaded")

-- Network Events
local Net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
local EquipToolEvent = Net["RE/EquipToolFromHotbar"]
local ChargeEvent = Net["RF/ChargeFishingRod"]
local RequestEvent = Net["RF/RequestFishingMinigameStarted"]
local CompletedEvent = Net["RE/FishingCompleted"]
local CancelEvent = Net["RF/CancelFishingInputs"]
local EquipItemEvent = Net["RE/EquipItem"]

print("✅ Network events loaded\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- GPU SAVER MODULE
-- ═══════════════════════════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local workspace = game:GetService("Workspace")

-- GPU Saver Variables
local gpuSaverEnabled = false
local originalSettings = {}
local whiteScreenGui = nil
local connections = {}

-- Session stats for white screen display
local startTime = os.time()
local sessionStats = {
    totalFish = 0,
    totalValue = 0,
    bestFish = {name = "None", value = 0},
    fishTypes = {}
}

-- Helper Functions
local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function FormatNumber(num)
    local formatted = tostring(math.floor(tonumber(num) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function FormatCoins(coins)
    local num = tonumber(coins) or 0
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

local function getCurrentCoins()
    local success, result = pcall(function()
        if PlayerData then
            local coins = PlayerData:GetExpect("Coins")
            return tonumber(coins) or 0
        end
        return 0
    end)
    return success and result or 0
end

local function getCurrentLevel()
    local success, result = pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return "Lvl 0" end
        local xpFrame = playerGui:FindFirstChild("XP")
        if not xpFrame then return "Lvl 0" end
        local frame = xpFrame:FindFirstChild("Frame")
        if not frame then return "Lvl 0" end
        local levelCount = frame:FindFirstChild("LevelCount")
        if not levelCount then return "Lvl 0" end
        return levelCount.Text or "Lvl 0"
    end)
    return success and result or "Lvl 0"
end

local function getQuestText(labelName)
    local success, result = pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return "No Quest" end
        local quests = playerGui:FindFirstChild("Quests")
        if not quests then return "No Quest" end
        local main = quests:FindFirstChild("Main")
        if not main then return "No Quest" end
        local content = main:FindFirstChild("Content")
        if not content then return "No Quest" end
        local label = content:FindFirstChild(labelName)
        if not label then return "No Quest" end

        local questText = label:FindFirstChild("QuestText")
        if not questText then return "No Quest" end

        return questText.Text or "No Quest"
    end)
    return success and result or "No Quest"
end

-- VRAM Optimization Functions
local function ultimatePerformance()
    pcall(function()
        local terrain = workspace:FindFirstChild("Terrain")
        if terrain then
            local clouds = terrain:FindFirstChild("Clouds")
            if clouds then
                clouds:ClearAllChildren()
            end
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
        end

        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        Lighting.Technology = Enum.Technology.Compatibility
        Lighting:ClearAllChildren()
    end)
end

local function optimizeMaterials()
    pcall(function()
        local materialsOptimized = 0
        local function optimizePart(part)
            if part:IsA("BasePart") then
                part.Material = Enum.Material.Plastic
                part.Reflectance = 0
                part.Transparency = part.Transparency > 0.5 and 1 or part.Transparency
                materialsOptimized = materialsOptimized + 1
            end
        end

        for _, descendant in ipairs(workspace:GetDescendants()) do
            pcall(function()
                optimizePart(descendant)
            end)
        end
    end)
end

local function removeTextures()
    pcall(function()
        local texturesRemoved = 0
        for _, descendant in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if descendant:IsA("Decal") or descendant:IsA("Texture") or descendant:IsA("SurfaceAppearance") then
                    descendant:Destroy()
                    texturesRemoved = texturesRemoved + 1
                end
            end)
        end
    end)
end

local function destroyParticlesAndEffects()
    pcall(function()
        local effectsDestroyed = 0
        for _, descendant in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if descendant:IsA("ParticleEmitter") or
                   descendant:IsA("Fire") or
                   descendant:IsA("Smoke") or
                   descendant:IsA("Sparkles") or
                   descendant:IsA("Trail") or
                   descendant:IsA("Beam") then
                    descendant:Destroy()
                    effectsDestroyed = effectsDestroyed + 1
                end
            end)
        end
    end)
end

local function optimizeMeshes()
    pcall(function()
        local meshesOptimized = 0
        for _, descendant in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if descendant:IsA("SpecialMesh") or descendant:IsA("MeshPart") then
                    if descendant:IsA("SpecialMesh") then
                        descendant.TextureId = ""
                    elseif descendant:IsA("MeshPart") then
                        descendant.TextureID = ""
                    end
                    meshesOptimized = meshesOptimized + 1
                end
            end)
        end
    end)
end

local function cleanupEnvironment()
    pcall(function()
        local waves = workspace:FindFirstChild("!! WAVES ")
        if waves then
            waves:ClearAllChildren()
        end
    end)

    pcall(function()
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                otherPlayer.Character:Destroy()
            end
        end
    end)
end

-- White Screen Functions
local function createWhiteScreen()
    if whiteScreenGui then return end

    whiteScreenGui = Instance.new("ScreenGui")
    whiteScreenGui.Name = "GPUSaverScreen"
    whiteScreenGui.ResetOnSpawn = false
    whiteScreenGui.IgnoreGuiInset = true
    whiteScreenGui.DisplayOrder = 999999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    frame.BorderSizePixel = 0
    frame.Parent = whiteScreenGui

    -- Main title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0, 600, 0, 100)
    titleLabel.Position = UDim2.new(0.5, -300, 0, 50)
    titleLabel.BackgroundTransparency = 1
    local totalCaught = (player.leaderstats and player.leaderstats.Caught and player.leaderstats.Caught.Value) or 0
    local bestCaught = (player.leaderstats and player.leaderstats["Rarest Fish"] and player.leaderstats["Rarest Fish"].Value) or "None"
    titleLabel.Text = "🟢 " .. player.Name .. "\nTotal Caught: " .. totalCaught .. "\nBest Caught: " .. bestCaught
    titleLabel.TextColor3 = Color3.new(0, 1, 0)
    titleLabel.TextScaled = false
    titleLabel.TextSize = 32
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.Parent = frame

    -- Session time
    local sessionLabel = Instance.new("TextLabel")
    sessionLabel.Name = "SessionLabel"
    sessionLabel.Size = UDim2.new(0, 400, 0, 40)
    sessionLabel.Position = UDim2.new(0.5, -200, 0, 180)
    sessionLabel.BackgroundTransparency = 1
    sessionLabel.Text = "⏱️ Uptime: 00:00:00"
    sessionLabel.TextColor3 = Color3.new(1, 1, 1)
    sessionLabel.TextSize = 22
    sessionLabel.Font = Enum.Font.SourceSansBold
    sessionLabel.TextXAlignment = Enum.TextXAlignment.Center
    sessionLabel.Parent = frame

    -- FPS Label
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPSLabel"
    fpsLabel.Size = UDim2.new(0, 400, 0, 40)
    fpsLabel.Position = UDim2.new(0.5, -200, 0, 220)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "📊 FPS: 0"
    fpsLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    fpsLabel.TextSize = 22
    fpsLabel.Font = Enum.Font.SourceSansBold
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Center
    fpsLabel.Parent = frame

    -- Fish stats
    local fishStatsLabel = Instance.new("TextLabel")
    fishStatsLabel.Name = "FishStatsLabel"
    fishStatsLabel.Size = UDim2.new(0, 400, 0, 40)
    fishStatsLabel.Position = UDim2.new(0.5, -200, 0, 260)
    fishStatsLabel.BackgroundTransparency = 1
    fishStatsLabel.Text = "🎣 Fish Caught: " .. FormatNumber(sessionStats.totalFish)
    fishStatsLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    fishStatsLabel.TextSize = 22
    fishStatsLabel.Font = Enum.Font.SourceSans
    fishStatsLabel.TextXAlignment = Enum.TextXAlignment.Center
    fishStatsLabel.Parent = frame

    -- Coin display
    local coinLabel = Instance.new("TextLabel")
    coinLabel.Name = "CoinLabel"
    coinLabel.Size = UDim2.new(0, 400, 0, 40)
    coinLabel.Position = UDim2.new(0.5, -200, 0, 300)
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "💰 Coins: " .. FormatCoins(getCurrentCoins())
    coinLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    coinLabel.TextSize = 22
    coinLabel.Font = Enum.Font.SourceSans
    coinLabel.TextXAlignment = Enum.TextXAlignment.Center
    coinLabel.Parent = frame

    -- Level display
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(0, 400, 0, 40)
    levelLabel.Position = UDim2.new(0.5, -200, 0, 340)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "⭐ " .. getCurrentLevel()
    levelLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    levelLabel.TextSize = 22
    levelLabel.Font = Enum.Font.SourceSans
    levelLabel.TextXAlignment = Enum.TextXAlignment.Center
    levelLabel.Parent = frame

    -- Auto features status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0, 600, 0, 40)
    statusLabel.Position = UDim2.new(0.5, -300, 0, 420)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🤖 Auto Farm: " .. (_G.AUTO_FARM_ENABLED and "🟢 ON" or "🔴 OFF") ..
                      " | Auto Sell: " .. (_G.AUTO_SELL_ENABLED and "🟢 ON" or "🔴 OFF")
    statusLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    statusLabel.TextSize = 16
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    statusLabel.Parent = frame

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 200, 0, 50)
    closeButton.Position = UDim2.new(0.5, -100, 1, -80)
    closeButton.AnchorPoint = Vector2.new(0, 1)
    closeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "⚠️ Disable GPU Saver"
    closeButton.TextColor3 = Color3.new(1, 0.8, 0)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = frame

    closeButton.MouseButton1Click:Connect(function()
        disableGPUSaver()
    end)

    -- Update loop
    task.spawn(function()
        local lastUpdate = tick()
        local frameCount = 0

        connections.renderConnection = RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local currentTime = tick()

            if currentTime - lastUpdate >= 1 then
                local fps = frameCount / (currentTime - lastUpdate)

                pcall(function()
                    if fpsLabel and fpsLabel.Parent then
                        fpsLabel.Text = string.format("📊 FPS: %.0f", fps)
                    end
                end)

                pcall(function()
                    if sessionLabel and sessionLabel.Parent then
                        local currentUptime = math.max(0, os.time() - startTime)
                        sessionLabel.Text = "⏱️ Uptime: " .. FormatTime(currentUptime)
                    end
                end)

                pcall(function()
                    if fishStatsLabel and fishStatsLabel.Parent then
                        local fishCount = math.max(0, sessionStats.totalFish)
                        fishStatsLabel.Text = "🎣 Fish Caught: " .. FormatNumber(fishCount)
                    end
                end)

                pcall(function()
                    if coinLabel and coinLabel.Parent then
                        coinLabel.Text = "💰 Coins: " .. FormatCoins(getCurrentCoins())
                    end
                end)

                pcall(function()
                    if levelLabel and levelLabel.Parent then
                        levelLabel.Text = "⭐ " .. getCurrentLevel()
                    end
                end)

                pcall(function()
                    if statusLabel and statusLabel.Parent then
                        statusLabel.Text = "🤖 Auto Farm: " .. (_G.AUTO_FARM_ENABLED and "🟢 ON" or "🔴 OFF") ..
                                         " | Auto Sell: " .. (_G.AUTO_SELL_ENABLED and "🟢 ON" or "🔴 OFF")
                    end
                end)

                pcall(function()
                    if titleLabel and titleLabel.Parent then
                        local currentCaught = (player.leaderstats and player.leaderstats.Caught and player.leaderstats.Caught.Value) or 0
                        local currentBest = (player.leaderstats and player.leaderstats["Rarest Fish"] and player.leaderstats["Rarest Fish"].Value) or "None"
                        titleLabel.Text = "🟢 " .. player.Name .. "\nTotal Caught: " .. FormatNumber(currentCaught) .. "\nBest Caught: " .. currentBest
                    end
                end)

                frameCount = 0
                lastUpdate = currentTime
            end
        end)
    end)

    whiteScreenGui.Parent = game:GetService("CoreGui")
end

local function removeWhiteScreen()
    if whiteScreenGui then
        whiteScreenGui:Destroy()
        whiteScreenGui = nil
    end

    if connections.renderConnection then
        connections.renderConnection:Disconnect()
        connections.renderConnection = nil
    end
end

-- Main GPU Saver Functions
function enableGPUSaver()
    if gpuSaverEnabled then return end
    gpuSaverEnabled = true
    _G.GPU_SAVER_ENABLED = true

    print("[GPU Saver] ✅ Enabling GPU Saver...")

    -- Apply VRAM optimizations
    pcall(ultimatePerformance)
    pcall(cleanupEnvironment)
    pcall(optimizeMaterials)
    pcall(removeTextures)
    pcall(optimizeMeshes)
    pcall(destroyParticlesAndEffects)

    -- Store original settings
    originalSettings.GlobalShadows = Lighting.GlobalShadows
    originalSettings.FogEnd = Lighting.FogEnd
    originalSettings.Brightness = Lighting.Brightness
    originalSettings.QualityLevel = settings().Rendering.QualityLevel

    -- Apply GPU saving settings
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1
        Lighting.Brightness = 0

        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
                v.Enabled = false
            end
        end

        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    end)

    createWhiteScreen()
    print("[GPU Saver] ✅ GPU Saver enabled successfully!")
end

function disableGPUSaver()
    if not gpuSaverEnabled then return end
    gpuSaverEnabled = false
    _G.GPU_SAVER_ENABLED = false

    print("[GPU Saver] ⚠️ Disabling GPU Saver...")

    -- Restore settings
    pcall(function()
        if originalSettings.QualityLevel then
            settings().Rendering.QualityLevel = originalSettings.QualityLevel
        end

        Lighting.GlobalShadows = originalSettings.GlobalShadows or true
        Lighting.FogEnd = originalSettings.FogEnd or 100000
        Lighting.Brightness = originalSettings.Brightness or 1

        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

        if workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = 70
        end
    end)

    removeWhiteScreen()
    print("[GPU Saver] ❌ GPU Saver disabled!")
end

print("✅ GPU Saver module loaded\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK NOTIFIER MODULE (TIER-BASED EVENT-DRIVEN)
-- ═══════════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")

-- Get ObtainedNewFishNotification event (deferred loading)
local newFishEvent = nil

-- Function to initialize event (called later after UI loads)
local function initializeWebhookEvent()
    task.spawn(function()
        local success, result = pcall(function()
            -- Method 1: Use Net module (correct path from notifcontroller.lua)
            local netModule = require(ReplicatedStorage:WaitForChild("Packages", 5):WaitForChild("Net", 5))
            if netModule and netModule.RemoteEvent then
                newFishEvent = netModule:RemoteEvent("ObtainedNewFishNotification")
                if newFishEvent then
                    print("[Webhook] ✅ ObtainedNewFishNotification event found (via Net module)")
                    return true
                end
            end
            return false
        end)

        if not success or not result then
            warn("[Webhook] ⚠️ ObtainedNewFishNotification event not available - webhook detection disabled")
            warn("[Webhook] Error: " .. tostring(result))
        end
    end)
end

-- Webhook setup
local webhookLastSendTime = {}
local WEBHOOK_COOLDOWN = 1
_G.WEBHOOK_SECRET = _G.WEBHOOK_SECRET or ""

-- Function to get webhook URL
local function getWebhookURL()
    return type(_G.WEBHOOK_SECRET) == "string" and _G.WEBHOOK_SECRET or ""
end

-- Unified webhook function (Mythic & SECRET fish only)
local function sendUnifiedWebhook(webhookType, data)
    local UNIFIED_WEBHOOK_URL = getWebhookURL()

    if not UNIFIED_WEBHOOK_URL or UNIFIED_WEBHOOK_URL == "" then
        warn('[Webhook] URL not configured!')
        return
    end

    -- Rate limiting
    local currentTime = tick()
    local lastTime = webhookLastSendTime[webhookType] or 0
    if currentTime - lastTime < WEBHOOK_COOLDOWN then
        return
    end

    local embed = {}

    if webhookType == "rare_fish_caught" then
        local embedColor = 16711680
        local embedTitle = "🎣 RARE FISH CAUGHT!"

        if data.tier == 7 then
            embedColor = 0x17FF97
            embedTitle = "✨ SECRET FISH CAUGHT!"
        elseif data.tier == 6 then
            embedColor = 0xFF1818
            embedTitle = "🔥 MYTHIC FISH CAUGHT!"
        end

        embed = {
            title = embedTitle,
            description = string.format("**%s** has been caught!", data.fishId),
            color = embedColor,
            fields = {
                { name = "🏆 Tier", value = data.tierName or "Unknown", inline = true },
                { name = "🐟 Fish", value = data.fishId, inline = true },
                { name = "✨ Rarity", value = string.format("1 in %.1f", data.rarity), inline = true },
                { name = "⚖️ Weight", value = tostring(data.weight) .. " kg", inline = true },
                { name = "🎨 Variant", value = data.variant, inline = true },
                { name = "🕒 Time", value = os.date("%H:%M:%S"), inline = true },
                { name = "👤 Player", value = player.DisplayName or player.Name or "Unknown", inline = false },
            },
            footer = { text = "Mythic/SECRET Fish Detector • Auto Fish" }
        }

        -- Add fish thumbnail
        if data.fishIcon and data.fishIcon ~= "" then
            local thumbnailUrl = nil

            if string.match(data.fishIcon, "^rbxassetid://") then
                local assetId = string.match(data.fishIcon, "rbxassetid://(%d+)")
                if assetId then
                    local success, result = pcall(function()
                        local apiUrl = string.format("https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=768x432&format=Png&isCircular=false", assetId)
                        local req = syn and syn.request or http_request or (fluxus and fluxus.request) or request
                        if req then
                            local response = req({ Url = apiUrl, Method = "GET" })
                            if response and response.StatusCode == 200 and response.Body then
                                local data = HttpService:JSONDecode(response.Body)
                                if data and data.data and data.data[1] and data.data[1].imageUrl then
                                    return data.data[1].imageUrl
                                end
                            end
                        end
                        return nil
                    end)

                    thumbnailUrl = (success and result) or string.format("https://assetdelivery.roblox.com/v1/asset/?id=%s", assetId)
                end
            elseif string.match(data.fishIcon, "^https?://") then
                thumbnailUrl = data.fishIcon
            end

            if thumbnailUrl then
                embed.thumbnail = { url = thumbnailUrl }
            end
        end
    end

    -- Prepare payload
    local payload = { embeds = {embed}, wait = true }
    local body = HttpService:JSONEncode(payload)

    -- Retry logic
    local maxRetries = 3
    local retryDelay = 2
    local overallSuccess = false
    local lastError = nil

    for attempt = 1, maxRetries do
        if attempt > 1 then
            task.wait(retryDelay)
        end

        local sendSuccess, response = pcall(function()
            local req = syn and syn.request or http_request or (fluxus and fluxus.request) or request
            if not req then error("No HTTP library") end

            return req({
                Url = UNIFIED_WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
        end)

        if sendSuccess and response then
            local statusCode = response.StatusCode or response.status_code or 0
            if statusCode == 200 or statusCode == 204 then
                webhookLastSendTime[webhookType] = tick()
                overallSuccess = true
                break
            else
                lastError = string.format("HTTP %d", statusCode)
                warn(string.format("[Webhook] ⚠️ Status %d (attempt %d/%d)", statusCode, attempt, maxRetries))
            end
        else
            lastError = tostring(response)
            warn(string.format("[Webhook] ⚠️ Failed: %s (attempt %d/%d)", lastError, attempt, maxRetries))
        end
    end

    if not overallSuccess then
        warn(string.format("[Webhook] ❌ %s failed after %d attempts: %s", webhookType, maxRetries, tostring(lastError)))
    end
end

-- Setup fish detection
local function setupRareFishDetection()
    if not newFishEvent then
        warn("[Rare Fish Detection] ❌ ObtainedNewFishNotification event not available")
        return
    end

    newFishEvent.OnClientEvent:Connect(function(fishId, fishData, textNotif, isNewItem)
        pcall(function()
            local itemUtility = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("ItemUtility", 5))
            if not itemUtility then return end

            local itemData = itemUtility:GetItemData(fishId)
            if not itemData then return end

            if itemData and (itemData.Probability or itemData.ForcedProbability) then
                local rarity = itemData.Probability or itemData.ForcedProbability
                local TierUtility = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TierUtility", 5))

                local tierInfo = nil
                if rarity.Chance then
                    tierInfo = TierUtility:GetTierFromRarity(rarity.Chance)
                end

                -- Check if Mythic (Tier 6) or SECRET (Tier 7) only
                if tierInfo and (tierInfo.Tier == 6 or tierInfo.Tier == 7) then
                    local rarityRatio = math.round(1 / rarity.Chance * 10) / 10
                    local weight = fishData and fishData.Weight or "unknown"
                    local variant = fishData and fishData.VariantId or "none"
                    local fishIcon = itemData.Data and itemData.Data.Icon or nil
                    local fishName = itemData.Data and itemData.Data.Name or tostring(fishId)

                    local webhookURL = getWebhookURL()
                    if webhookURL and webhookURL ~= "" then
                        sendUnifiedWebhook("rare_fish_caught", {
                            fishId = fishName,
                            rarity = rarityRatio,
                            weight = weight,
                            variant = variant,
                            isNew = isNewItem,
                            fishIcon = fishIcon,
                            tier = tierInfo.Tier,
                            tierName = tierInfo.Name
                        })
                    else
                        warn("[Rare Fish Detection] ⚠️ Webhook URL not configured")
                    end
                end
            end
        end)
    end)
end

-- Webhook State
_G.WEBHOOK_ENABLED = false
local webhookInitialized = false

-- Start Webhook System
function startWebhookNotifier()
    if webhookInitialized then
        print("[Webhook] ⚠️ Already initialized")
        return
    end

    if not _G.WEBHOOK_SECRET or _G.WEBHOOK_SECRET == "" then
        warn("[Webhook] ❌ Webhook URL not configured!")
        return
    end

    print("[Webhook] 🔄 Initializing tier-based webhook system...")

    task.spawn(function()
        task.wait(2)

        -- Initialize event connection first
        initializeWebhookEvent()
        task.wait(1)

        -- Initialize tier-based rare fish notifier
        setupRareFishDetection()

        webhookInitialized = true
        _G.WEBHOOK_ENABLED = true
        print("[Webhook] ✅ Tier-based fish notifier started!")
        print("[Webhook] 📡 Monitoring for Mythic (Tier 6) & SECRET (Tier 7) fish...")
    end)
end

-- Stop Webhook System
function stopWebhookNotifier()
    _G.WEBHOOK_ENABLED = false
    webhookInitialized = false
    print("[Webhook] ⚠️ Webhook notifier disabled")
end

print("✅ Discord Webhook Notifier module loaded (Tier-Based Detection)\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO SAVE & LOAD CONFIG SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG_FOLDER = "ConfigFishIt"
local CONFIG_FILE = nil

-- Ensure config folder exists
local function ensureConfigFolder()
    if not isfolder then return false end
    if not isfolder(CONFIG_FOLDER) then
        local success = pcall(function()
            makefolder(CONFIG_FOLDER)
        end)
        return success
    end
    return true
end

-- Get config file path based on username and userid
local function getConfigFilePath()
    if CONFIG_FILE then return CONFIG_FILE end

    local playerName = player.Name
    local userId = player.UserId
    CONFIG_FILE = CONFIG_FOLDER .. "/" .. playerName .. "_" .. userId .. "_config.json"

    return CONFIG_FILE
end

-- Save config
function saveConfig()
    if not writefile then
        warn("[Config] writefile not available - cannot save config")
        return false
    end

    ensureConfigFolder()

    local config = {
        -- Auto Farm Settings
        AUTO_FARM_ENABLED = _G.AUTO_FARM_ENABLED,
        FARM_SUCCESS_DELAY = _G.FARM_SUCCESS_DELAY,

        -- Auto Farm V2 Settings
        AUTO_FARM_V2_ENABLED = _G.AUTO_FARM_V2_ENABLED,
        JUNG_V2_STATE = {
            delayReel = _G.JUNG_V2_STATE.baseDelayReel,
            delayComplete = _G.JUNG_V2_STATE.baseDelayComplete,
            autoPingCompensation = _G.JUNG_V2_STATE.autoPingCompensation
        },

        -- Auto Sell Settings
        AUTO_SELL_ENABLED = _G.AUTO_SELL_ENABLED,
        AUTO_SELL_DELAY = _G.AUTO_SELL_DELAY,

        -- Auto Artifact Settings
        AUTO_ARTIFACT_ENABLED = _G.AUTO_ARTIFACT_ENABLED,
        artifactSkipToggles = artifactSkipToggles,

        -- Auto Element Settings
        AUTO_ELEMENT_ENABLED = _G.AUTO_ELEMENT_ENABLED,
        AUTO_ELEMENT_FARM_ENABLED = _G.AUTO_ELEMENT_FARM_ENABLED,
        ELEMENT_FARM_WAIT = _G.ELEMENT_FARM_WAIT,
        ELEMENT_FARM_AFTER_COMPLETE_WAIT = _G.ELEMENT_FARM_AFTER_COMPLETE_WAIT,

        -- Auto Weather Settings
        AUTO_WEATHER_ENABLED = _G.AUTO_WEATHER_ENABLED,
        WEATHER_PURCHASE_DELAY = _G.WEATHER_PURCHASE_DELAY,

        -- Auto Upgrade Settings
        AUTO_UPGRADE_ROD_ENABLED = _G.AUTO_UPGRADE_ROD_ENABLED,
        AUTO_UPGRADE_BAIT_ENABLED = _G.AUTO_UPGRADE_BAIT_ENABLED,

        -- Freeze Character
        FREEZE_CHAR_ENABLED = _G.FREEZE_CHAR_ENABLED,

        -- GPU Saver
        GPU_SAVER_ENABLED = _G.GPU_SAVER_ENABLED,

        -- Webhook Settings
        WEBHOOK_ENABLED = _G.WEBHOOK_ENABLED,
        WEBHOOK_SECRET = _G.WEBHOOK_SECRET,

        -- Metadata
        playerName = player.Name,
        userId = player.UserId,
        lastSave = os.time(),
        version = "v5.3"
    }

    local success, err = pcall(function()
        writefile(getConfigFilePath(), HttpService:JSONEncode(config))
    end)

    if success then
        print("[Config] ✅ Config saved successfully")
        return true
    else
        warn("[Config] ❌ Failed to save config:", err)
        return false
    end
end

-- Load config (only reads the file and returns config data)
function loadConfig()
    if not readfile or not isfile then
        warn("[Config] readfile/isfile not available - cannot load config")
        return nil
    end

    local configPath = getConfigFilePath()

    if not isfile(configPath) then
        print("[Config] ℹ️ No saved config found for this account")
        return nil
    end

    local success, config = pcall(function()
        return HttpService:JSONDecode(readfile(configPath))
    end)

    if not success or not config then
        warn("[Config] ❌ Failed to load config")
        return nil
    end

    print("[Config] ✅ Config file loaded successfully")
    print(string.format("[Config] 📋 Found settings for %s (ID: %s)", config.playerName or player.Name, config.userId or player.UserId))

    return config
end

-- Apply loaded config (called AFTER UI is created)
function applyLoadedConfig(config)
    if not config then
        return false
    end

    print("[Config] 🔄 Applying saved configuration...")
    print(string.rep("=", 70))

    -- Disable auto-save temporarily while loading
    local originalAutoSave = autoSaveConfig
    autoSaveConfig = function() end -- Temporarily disable

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 1: AUTO FARM - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] 📋 Loading Auto Farm settings...")

    -- Update Ping Compensation Toggle UI
    if config.JUNG_V2_STATE and config.JUNG_V2_STATE.autoPingCompensation ~= nil then
        pcall(function()
            Window.Flags.AutoPingCompensation = config.JUNG_V2_STATE.autoPingCompensation
        end)
        print(string.format("  📶 Auto Ping Compensation: %s", config.JUNG_V2_STATE.autoPingCompensation and "ENABLED" or "DISABLED"))
        task.wait(0.1)
    end

    -- Update Auto Farm V2 Toggle UI
    if config.AUTO_FARM_V2_ENABLED then
        pcall(function()
            Window.Flags.AutoFarmV2Enabled = true
        end)
        print("  ✅ Auto Farm V2: TOGGLED ON")
        task.wait(0.15)
    end

    -- Update Auto Farm V1 Toggle UI
    if config.AUTO_FARM_ENABLED then
        pcall(function()
            Window.Flags.AutoFarmEnabled = true
        end)
        print("  ✅ Auto Farm V1: TOGGLED ON")
        task.wait(0.15)
    end

    -- Update Auto Sell Toggle UI
    if config.AUTO_SELL_ENABLED then
        pcall(function()
            Window.Flags.AutoSellEnabled = true
        end)
        print("  💰 Auto Sell: TOGGLED ON")
        task.wait(0.15)
    end

    -- Update Artifact Skip Toggles UI
    if config.artifactSkipToggles then
        if config.artifactSkipToggles[1] then
            pcall(function() Window.Flags.SkipHourglassDiamond = true end)
            task.wait(0.1)
        end
        if config.artifactSkipToggles[2] then
            pcall(function() Window.Flags.SkipArrowArtifact = true end)
            task.wait(0.1)
        end
        if config.artifactSkipToggles[3] then
            pcall(function() Window.Flags.SkipDiamondArtifact = true end)
            task.wait(0.1)
        end
        if config.artifactSkipToggles[4] then
            pcall(function() Window.Flags.SkipCrescentArtifact = true end)
            task.wait(0.1)
        end
        print(string.format("  ⏭️ Artifact Skip: [%s, %s, %s, %s]",
            config.artifactSkipToggles[1] and "T1✓" or "T1✗",
            config.artifactSkipToggles[2] and "T2✓" or "T2✗",
            config.artifactSkipToggles[3] and "T3✓" or "T3✗",
            config.artifactSkipToggles[4] and "T4✓" or "T4✗"))
    end

    -- Update Auto Artifact Toggle UI
    if config.AUTO_ARTIFACT_ENABLED then
        pcall(function()
            Window.Flags.AutoArtifactEnabled = true
        end)
        print("  🎯 Auto Artifact: TOGGLED ON")
        task.wait(0.15)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 2: AUTO ELEMENT - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] 🔮 Loading Auto Element settings...")

    if config.AUTO_ELEMENT_ENABLED then
        pcall(function()
            Window.Flags.AutoElementEnabled = true
        end)
        print("  ✅ Auto Element: TOGGLED ON")
        task.wait(0.15)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 3: AUTO WEATHER - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] 🌤️ Loading Auto Weather settings...")

    if config.AUTO_WEATHER_ENABLED then
        pcall(function()
            Window.Flags.AutoWeatherEnabled = true
        end)
        print("  ✅ Auto Weather: TOGGLED ON")
        task.wait(0.15)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 3.5: AUTO UPGRADE - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] ⬆️ Loading Auto Upgrade settings...")

    if config.AUTO_UPGRADE_ROD_ENABLED then
        pcall(function()
            Window.Flags.AutoUpgradeRodEnabled = true
        end)
        print("  ✅ Auto Upgrade Rod: TOGGLED ON")
        task.wait(0.15)
    end

    if config.AUTO_UPGRADE_BAIT_ENABLED then
        pcall(function()
            Window.Flags.AutoUpgradeBaitEnabled = true
        end)
        print("  ✅ Auto Upgrade Bait: TOGGLED ON")
        task.wait(0.15)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 4: MISC (FREEZE CHAR & GPU SAVER) - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] ⚡ Loading Misc settings...")

    if config.FREEZE_CHAR_ENABLED then
        pcall(function()
            Window.Flags.FreezeCharEnabled = true
        end)
        print("  🔒 Freeze Character: TOGGLED ON")
        task.wait(0.15)
    end

    if config.GPU_SAVER_ENABLED then
        pcall(function()
            Window.Flags.GPUSaverEnabled = true
        end)
        print("  ✅ GPU Saver: TOGGLED ON")
        task.wait(0.15)
    end

    -- ═════════════════════════════════════════════════════════════════════════
    -- TAB 5: WEBHOOK - UPDATE UI TOGGLES
    -- ═════════════════════════════════════════════════════════════════════════

    print("[Config] 🔗 Loading Webhook settings...")

    if config.WEBHOOK_ENABLED then
        pcall(function()
            Window.Flags.WebhookEnabled = true
        end)
        print("  ✅ Webhook: TOGGLED ON")
        task.wait(0.15)
    end

    -- Re-enable auto-save
    autoSaveConfig = originalAutoSave

    print(string.rep("=", 70))
    print("[Config] ✅ All saved settings applied successfully!")
    print(string.rep("=", 70) .. "\n")

    return true
end

-- Auto-save when settings change
local autoSaveDebounce = false
function autoSaveConfig()
    if autoSaveDebounce then return end
    autoSaveDebounce = true

    task.spawn(function()
        task.wait(2) -- Wait 2 seconds before saving (debounce)
        saveConfig()
        autoSaveDebounce = false
    end)
end

-- UI Component References (for updating values when loading config)
local UIComponents = {
    -- Auto Farm Tab
    AutoFarmToggle = nil,
    SuccessDelayInput = nil,
    AutoFarmV2Toggle = nil,
    PingCompensationToggle = nil,
    BaseDelayReelInput = nil,
    BaseDelayCompleteInput = nil,
    FreezeCharToggle = nil,
    AutoSellToggle = nil,
    SellDelayInput = nil,
    AutoArtifactToggle = nil,
    SkipHourglassToggle = nil,
    SkipArrowToggle = nil,
    SkipDiamondToggle = nil,
    SkipCrescentToggle = nil,

    -- Element Tab
    AutoElementToggle = nil,

    -- Weather Tab
    AutoWeatherToggle = nil,
    WeatherDelayInput = nil,

    -- Misc Tab
    FreezeCharToggle = nil,
    GPUSaverToggle = nil,

    -- Webhook Tab
    WebhookURLInput = nil,
    WebhookToggle = nil
}

print("✅ Auto Save & Load Config system loaded\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- ANIMATION CONTROLLER HOOK (DISABLE ALL FISHING ANIMATIONS)
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    This hook intercepts the AnimationController and disables ALL fishing animations
    when auto farm is activated (animationBlocksActive = true).

    OPTIMIZED: Animation blocks are set ONCE at start, not checked every cycle.

    Animations disabled:
    - StartRodCharge, LoopedRodCharge
    - RodThrow (critical 0.6s delay)
    - ReelIntermission, ReelStart, FishCaught
    - FishingFailure
    - EquipIdle, EquipIdleFake
    - HoldFish (dynamic)

    Based on analysis of fishingcontroller.lua
]]

local AnimationControllerHooked = false

-- Animation state tracking (declared before hooks)
local animationBlocksActive = false
local blockedAnimationTracks = {}

-- List of all fishing animations to disable
local FISHING_ANIMATIONS = {
    "StartRodCharge",
    "LoopedRodCharge",
    "RodThrow",
    "ReelIntermission",  -- This is the problematic one!
    "ReelStart",
    "FishCaught",
    "FishingFailure",
    "EquipIdle",
    "EquipIdleFake",
    "HoldFish",
    "IdleLoop",
    "WalkLoop",
    "Reel"  -- Add base "Reel" to catch all Reel* animations
}

local function setupAnimationHook()
    if AnimationControllerHooked then
        print("⚠️ Animation hook already installed")
        return
    end

    local success, err = pcall(function()
        -- Get AnimationController from Controllers
        local AnimController = require(ReplicatedStorage.Controllers.AnimationController)

        if not AnimController then
            warn("⚠️ AnimationController not found")
            return
        end

        print("🔧 Hooking AnimationController methods...")

        -- Hook IsDisabled FIRST (most important for FishCaught)
        if AnimController.IsDisabled then
            local originalIsDisabled = AnimController.IsDisabled

            AnimController.IsDisabled = function(self, animationName, ...)
                -- Only check if animation blocks are active (set once at start)
                if animationBlocksActive then
                    for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                        if animationName == fishingAnim or animationName:find(fishingAnim) then
                            return true -- Report as disabled
                        end
                    end
                end

                return originalIsDisabled(self, animationName, ...)
            end

            print("✅ IsDisabled hooked")
        end

        -- Hook PlayAnimation
        if AnimController.PlayAnimation then
            local originalPlayAnimation = AnimController.PlayAnimation

            AnimController.PlayAnimation = function(self, animationName, ...)
                if animationBlocksActive then
                    for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                        if animationName == fishingAnim or animationName:find(fishingAnim) then
                            return nil -- Skip animation completely
                        end
                    end
                end

                -- Allow non-fishing animations or when blocks inactive
                return originalPlayAnimation(self, animationName, ...)
            end

            print("✅ PlayAnimation hooked")
        end

        -- Hook StopAnimation
        if AnimController.StopAnimation then
            local originalStopAnimation = AnimController.StopAnimation

            AnimController.StopAnimation = function(self, animationName, ...)
                if _G.AUTO_FARM_ENABLED then
                    for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                        if animationName == fishingAnim or animationName:find(fishingAnim) then
                            return -- Skip stop call
                        end
                    end
                end

                return originalStopAnimation(self, animationName, ...)
            end

            print("✅ StopAnimation hooked")
        end

        -- Hook DestroyActiveAnimationTracks
        if AnimController.DestroyActiveAnimationTracks then
            local originalDestroy = AnimController.DestroyActiveAnimationTracks

            AnimController.DestroyActiveAnimationTracks = function(self, ...)
                -- Silent destroy - no print spam
                return originalDestroy(self, ...)
            end

            print("✅ DestroyActiveAnimationTracks hooked")
        end

        -- Hook AddAnimation to intercept at creation level
        if AnimController.AddAnimation then
            local originalAddAnimation = AnimController.AddAnimation

            AnimController.AddAnimation = function(self, animationName, ...)
                if animationBlocksActive then
                    -- Check if this is a fishing animation
                    for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                        if animationName == fishingAnim or animationName:find(fishingAnim) then
                            -- Return a fake animation track that does nothing
                            local fakeTrack = {
                                Play = function() end,
                                Stop = function() end,
                                Destroy = function() end,
                                IsPlaying = false,
                                TimePosition = 0,
                                Length = 0
                            }
                            return fakeTrack, nil
                        end
                    end
                end

                return originalAddAnimation(self, animationName, ...)
            end

            print("✅ AddAnimation hooked")
        end

        AnimationControllerHooked = true
        print("✅ AnimationController fully hooked - animations will be disabled during auto farm")

    end)

    if not success then
        warn("⚠️ Failed to hook AnimationController:", err)
    end
end

-- Install hook immediately
task.spawn(setupAnimationHook)

-- Hook MarkerListener Signal to block linked animations
task.spawn(function()
    task.wait(1)

    local success, err = pcall(function()
        local AnimController = require(ReplicatedStorage.Controllers.AnimationController)

        if AnimController and AnimController.MarkerListener then
            local originalMarkerListenerFire = AnimController.MarkerListener.Fire

            -- Hook the Fire method to intercept marker-triggered animations
            AnimController.MarkerListener.Fire = function(self, markerName, ...)
                if animationBlocksActive then
                    return -- Block the signal completely
                end

                return originalMarkerListenerFire(self, markerName, ...)
            end

            print("✅ MarkerListener.Fire hooked (blocks linked animations)")
        end
    end)

    if not success then
        warn("⚠️ Failed to hook MarkerListener:", err)
    end
end)

-- ALTERNATIVE METHOD: Directly disable animations in Animations module
task.spawn(function()
    task.wait(1) -- Wait for modules to load

    local success, err = pcall(function()
        local AnimationsModule = ReplicatedStorage.Modules:FindFirstChild("Animations")
        if AnimationsModule then
            local Animations = require(AnimationsModule)

            print("🔧 Disabling animations in Animations module...")

            local disabledCount = 0
            for animName, animData in pairs(Animations) do
                -- Disable all fishing animations
                for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                    if animName:find(fishingAnim) then
                        if animData and type(animData) == "table" then
                            animData.Disabled = true
                            disabledCount = disabledCount + 1
                            print("   ✅ Disabled:", animName)
                        end
                    end
                end
            end

            print(string.format("✅ Disabled %d animations in Animations module", disabledCount))
        end
    end)

    if not success then
        warn("⚠️ Could not modify Animations module:", err)
    end
end)

-- Reinstall hook on character respawn
player.CharacterAdded:Connect(function()
    task.wait(2) -- Wait for character to fully load
    AnimationControllerHooked = false
    setupAnimationHook()
end)

-- NUCLEAR OPTION: Hook Humanoid Animator directly to catch ALL animation plays
task.spawn(function()
    task.wait(2)

    local success, err = pcall(function()
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:WaitForChild("Humanoid", 5)
        local animator = humanoid and humanoid:FindFirstChildWhichIsA("Animator")

        if animator then
            local originalLoadAnimation = animator.LoadAnimation

            -- Hook LoadAnimation to intercept at lowest level
            animator.LoadAnimation = function(self, animation)
                local track = originalLoadAnimation(self, animation)

                if track then
                    local originalPlay = track.Play

                    -- Hook the track's Play method
                    track.Play = function(trackSelf, ...)
                        if animationBlocksActive then
                            -- Check if this is a fishing animation
                            local animName = animation.Name or ""

                            for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                                if animName:find(fishingAnim) then
                                    return -- Block the play
                                end
                            end
                        end

                        return originalPlay(trackSelf, ...)
                    end
                end

                return track
            end

            print("✅ Humanoid Animator hooked (nuclear option)")
        end
    end)

    if not success then
        warn("⚠️ Failed to hook Animator:", err)
    end
end)

-- Function to stop all fishing animations once
local function stopAllFishingAnimations()
    if animationBlocksActive then return end -- Already stopped

    pcall(function()
        local char = player.Character
        if not char then return end

        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not humanoid then return end

        local animator = humanoid:FindFirstChildWhichIsA("Animator")
        if not animator then return end

        -- Stop all currently playing fishing animations
        local playingTracks = animator:GetPlayingAnimationTracks()
        local stoppedCount = 0

        for _, track in ipairs(playingTracks) do
            if track.IsPlaying and track.Animation then
                local animName = track.Animation.Name or ""

                for _, fishingAnim in ipairs(FISHING_ANIMATIONS) do
                    if animName:find(fishingAnim) then
                        track:Stop(0)
                        track:Destroy()
                        stoppedCount = stoppedCount + 1
                        break
                    end
                end
            end
        end

        if stoppedCount > 0 then
            print(string.format("✅ Stopped %d fishing animations", stoppedCount))
        end

        animationBlocksActive = true
    end)
end

-- Function to cleanup when auto farm is disabled
local function cleanupAnimationBlocks()
    animationBlocksActive = false
    blockedAnimationTracks = {}
end

print("✅ Animation hook system initialized (optimized - blocks only when enabled)")

-- ═══════════════════════════════════════════════════════════════════════════
-- FREEZE CHARACTER POSITION SYSTEM (V5: Anti-Drown & Position Lock)
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Character position freeze system - locks character position in place

    Features:
    - BodyVelocity for position lock (anti-gravity & anti-drown)
    - BodyGyro for rotation lock
    - Heartbeat connection for drift correction
    - Y-axis drift detection (prevent drowning)
    - Overall position drift detection

    Based on element farm lock system from auto_farm_v4_elemen.lua
]]

local function freezeCharPosition()
    local char = player.Character
    if not char then
        print("❌ [Freeze Char] Character not found")
        return false
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        print("❌ [Freeze Char] HumanoidRootPart not found")
        return false
    end

    -- Store locked position
    freezeCharLockedCFrame = root.CFrame
    freezeCharLockActive = true

    -- Create BodyVelocity to lock position (STRONG anti-gravity & anti-drown)
    freezeCharBodyVelocity = Instance.new("BodyVelocity")
    freezeCharBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    freezeCharBodyVelocity.MaxForce = Vector3.new(999999, 999999, 999999)  -- Strong force
    freezeCharBodyVelocity.P = 50000  -- High P value for stronger lock
    freezeCharBodyVelocity.Parent = root

    -- Create BodyGyro to prevent rotation
    freezeCharBodyGyro = Instance.new("BodyGyro")
    freezeCharBodyGyro.CFrame = freezeCharLockedCFrame
    freezeCharBodyGyro.MaxTorque = Vector3.new(999999, 999999, 999999)  -- Strong torque
    freezeCharBodyGyro.P = 50000  -- High P value
    freezeCharBodyGyro.Parent = root

    -- AGGRESSIVE position correction (prevent ANY drift, especially Y-axis)
    freezeCharLockConnection = RunService.Heartbeat:Connect(function()
        if not root or not root.Parent or not freezeCharLockActive then
            if freezeCharLockConnection then
                freezeCharLockConnection:Disconnect()
                freezeCharLockConnection = nil
            end
            return
        end

        -- Check Y-axis drift (prevent sinking/drowning)
        local yDiff = math.abs(root.Position.Y - freezeCharLockedCFrame.Position.Y)
        if yDiff > 0.5 then  -- If Y-axis drifts more than 0.5 studs
            root.CFrame = freezeCharLockedCFrame
            if freezeCharBodyVelocity then
                freezeCharBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end

        -- Check overall position drift
        if (root.Position - freezeCharLockedCFrame.Position).Magnitude > 2 then  -- Threshold 2 studs
            root.CFrame = freezeCharLockedCFrame
            if freezeCharBodyVelocity then
                freezeCharBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end)

    print("[Freeze Char] 🔒 Position FROZEN (Anti-Drown Active)")
    return true
end

local function unfreezeCharPosition()
    freezeCharLockActive = false
    freezeCharLockedCFrame = nil

    if freezeCharLockConnection then
        freezeCharLockConnection:Disconnect()
        freezeCharLockConnection = nil
    end

    -- Remove BodyVelocity and BodyGyro
    if freezeCharBodyVelocity then
        freezeCharBodyVelocity:Destroy()
        freezeCharBodyVelocity = nil
    end
    if freezeCharBodyGyro then
        freezeCharBodyGyro:Destroy()
        freezeCharBodyGyro = nil
    end

    print("[Freeze Char] 🔓 Position UNFROZEN")
end

-- Character respawn handler (cleanup freeze on death/respawn)
player.CharacterAdded:Connect(function(newChar)
    if freezeCharLockActive then
        print("[Freeze Char] ⚠️ Character respawned, cleaning up freeze system")
        unfreezeCharPosition()
        _G.FREEZE_CHAR_ENABLED = false
    end
end)

print("✅ Freeze character system initialized")

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO DELETE ALL ANIMATIONS (Performance Optimization)
-- ═══════════════════════════════════════════════════════════════════════════

local function deleteAllAnimations()
    local success, animCount = pcall(function()
        if not character then
            return 0
        end

        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if not humanoid then
            return 0
        end

        local animator = humanoid:FindFirstChildWhichIsA("Animator")
        if not animator then
            return 0
        end

        local count = 0

        -- Stop and destroy all loaded animation tracks
        local tracks = animator:GetPlayingAnimationTracks()
        for _, track in pairs(tracks) do
            track:Stop()
            track:Destroy()
            count = count + 1
        end

        -- Destroy ALL default Roblox animations
        local animateScript = character:FindFirstChild("Animate")
        if animateScript then
            animateScript:Destroy()
            count = count + 1
        end

        -- Reset Humanoid animation states to remove built-in animations
        for _, animState in pairs(Enum.HumanoidStateType:GetEnumItems()) do
            pcall(function()
                humanoid:ChangeState(animState)
            end)
        end

        -- Remove all Animation instances from character
        for _, desc in pairs(character:GetDescendants()) do
            if desc:IsA("Animation") then
                desc:Destroy()
                count = count + 1
            end
        end

        -- Destroy the Animator to prevent new animations from loading
        animator:Destroy()
        count = count + 1

        return count
    end)

    if success and animCount > 0 then
        print(string.format("✅ Auto-deleted %d animation components", animCount))
        print("✅ ALL animations removed (walk, jump, fall, climb, swim, fishing)")
    end
end

-- Execute animation deletion on script load
deleteAllAnimations()

-- Re-execute on character respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.wait(1) -- Wait for character to fully load
    deleteAllAnimations()
end)

print("✅ Auto animation deletion system initialized")

-- ─────────────────────────────────────────────────────────────────────────
-- ALTERNATIVE: Hook via FishingController Module Modification
-- ─────────────────────────────────────────────────────────────────────────
--[[
    Since task.wait is readonly, we'll use a different approach:
    1. The AnimationController hook already eliminates RodThrow animation (~0.6s saved)
    2. We can't easily bypass the 0.75s wait without modifying the game module
    3. But disabling RodThrow animation alone gives massive speedup

    Total speed improvement from animation removal:
    - RodThrow animation: ~0.6s saved
    - ReelStart animation: ~0.3s saved
    - FishCaught animation: ~0.5s saved
    - Total: ~1.4 seconds saved per cycle

    Note: The 0.75s wait at line 605 cannot be bypassed due to readonly protection.
    However, removing animations alone provides 2-3x speedup.
]]

print("ℹ️ Animation removal provides 2-3x speed boost (0.75s wait bypass not possible)\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO UPGRADE SYSTEM (ROD & BAIT)
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Upgrade System - Automatic Rod & Bait purchasing and upgrading

    Features:
    - Currency parsing (2.99M -> 2990000)
    - Inventory detection (detect owned rods/baits)
    - Auto purchase next affordable rod/bait
    - Auto equip after purchase
    - Integration with Auto Farm (pause/resume)
]]

print("🔧 Loading Auto Upgrade System...")

-- Network Events for Upgrade System
local UnequipToolEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/UnequipToolFromHotbar"]
local EquipItemEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/EquipItem"]
local EquipBaitEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/EquipBait"]

-- Purchase events
local PurchaseRodEvent = nil
local PurchaseBaitEvent = nil

pcall(function()
    PurchaseRodEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseFishingRod"]
end)

pcall(function()
    PurchaseBaitEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseBait"]
end)

-- Rod Prices (ordered from cheapest to most expensive)
local rodPrices = {
    {id = 79, price = 300, name = "Luck Rod"},
    {id = 76, price = 900, name = "Carbon Rod"},
    {id = 85, price = 1500, name = "Grass Rod"},
    {id = 77, price = 3000, name = "Demascus Rod"},
    {id = 78, price = 5000, name = "Ice Rod"},
    {id = 4, price = 15000, name = "Lucky Rod"},
    {id = 80, price = 50000, name = "Midnight Rod"},
    {id = 6, price = 215000, name = "Steampunk Rod"},
    {id = 7, price = 437000, name = "Chrome Rod"},
    {id = 5, price = 1000000, name = "Astral Rod"},
    {id = 126, price = 2500000, name = "Ares Rod"},
    {id = 168, price = 8000000, name = "Angler Rod"}
}

-- Bait Prices (ordered from cheapest to most expensive)
local baitPrices = {
    {id = 10, price = 100, name = "Topwater Bait"},
    {id = 2, price = 1000, name = "Luck Bait"},
    {id = 3, price = 3000, name = "Midnight Bait"},
    {id = 17, price = 83500, name = "Deep Bait"},
    {id = 6, price = 290000, name = "Chroma Bait"},
    {id = 8, price = 630000, name = "Dark Matter Bait"},
    {id = 15, price = 1150000, name = "Corrupt Bait"},
    {id = 16, price = 3700000, name = "Aether Bait"}
}

-- Auto Upgrade State
local upgradeState = {
    isPurchasing = false, -- Global lock to prevent both running simultaneously
    rod = {
        running = false,
        currentTarget = nil,
        ownedRods = {},
        nextRodIndex = 1
    },
    bait = {
        running = false,
        currentTarget = nil,
        ownedBaits = {},
        nextBaitIndex = 1
    }
}

-- Helper: Parse currency text to number (2.99M -> 2990000, 1.5K -> 1500)
local function parseCurrency(text)
    if not text or text == "" then return 0 end

    text = text:gsub(",", "") -- Remove commas
    text = text:upper() -- Convert to uppercase

    local multiplier = 1
    if text:find("K") then
        multiplier = 1000
        text = text:gsub("K", "")
    elseif text:find("M") then
        multiplier = 1000000
        text = text:gsub("M", "")
    elseif text:find("B") then
        multiplier = 1000000000
        text = text:gsub("B", "")
    end

    local number = tonumber(text)
    if not number then return 0 end

    return math.floor(number * multiplier)
end

-- Helper: Get current coins
local function getCurrentCoinsUpgrade()
    local success, coins = pcall(function()
        local playerGui = player:WaitForChild("PlayerGui", 5)
        if not playerGui then return 0 end

        local events = playerGui:FindFirstChild("Events")
        if not events then return 0 end

        local frame = events:FindFirstChild("Frame")
        if not frame then return 0 end

        local currencyCounter = frame:FindFirstChild("CurrencyCounter")
        if not currencyCounter then return 0 end

        local counter = currencyCounter:FindFirstChild("Counter")
        if not counter then return 0 end

        return parseCurrency(counter.Text)
    end)

    return success and coins or 0
end

-- Helper: Detect owned rods from inventory
local function detectOwnedRods()
    local ownedRods = {}

    local success = pcall(function()
        if not PlayerData then return end

        local inventory = PlayerData:GetExpect("Inventory")
        if not inventory then return end

        local rods = inventory["Fishing Rods"] or {}

        for _, rod in ipairs(rods) do
            if rod and rod.Id then
                table.insert(ownedRods, rod.Id)
            end
        end
    end)

    if success then
        print(string.format("[Auto Upgrade] ✅ Detected %d owned rods", #ownedRods))
    else
        warn("[Auto Upgrade] ⚠️ Failed to detect owned rods")
    end

    return ownedRods
end

-- Helper: Detect owned baits from inventory
local function detectOwnedBaits()
    local ownedBaits = {}

    local success = pcall(function()
        if not PlayerData then return end

        local inventory = PlayerData:GetExpect("Inventory")
        if not inventory then return end

        local baits = inventory.Baits or {}

        for _, bait in ipairs(baits) do
            if bait and bait.Id then
                table.insert(ownedBaits, bait.Id)
            end
        end
    end)

    if success then
        print(string.format("[Auto Upgrade] ✅ Detected %d owned baits", #ownedBaits))
    else
        warn("[Auto Upgrade] ⚠️ Failed to detect owned baits")
    end

    return ownedBaits
end

-- Helper: Check if rod is owned
local function isRodOwned(rodId, ownedList)
    for _, id in ipairs(ownedList) do
        if id == rodId then return true end
    end
    return false
end

-- Helper: Find next rod to buy
local function findNextRodTarget(ownedRods)
    for i, rod in ipairs(rodPrices) do
        if not isRodOwned(rod.id, ownedRods) then
            return rod, i
        end
    end
    return nil, nil
end

-- Helper: Find next bait to buy
local function findNextBaitTarget(ownedBaits)
    for i, bait in ipairs(baitPrices) do
        if not isRodOwned(bait.id, ownedBaits) then
            return bait, i
        end
    end
    return nil, nil
end

-- Helper: Unequip tool
local function unequipTool()
    local success = pcall(function()
        UnequipToolEvent:FireServer()
    end)

    if success then
        print("[Auto Upgrade] 🔓 Tool unequipped")
    else
        warn("[Auto Upgrade] ⚠️ Failed to unequip tool")
    end

    return success
end

-- Helper: Equip rod (from hotbar)
local function equipRodHotbar()
    local success = pcall(function()
        EquipToolEvent:FireServer(1)
    end)

    if success then
        print("[Auto Upgrade] 🎣 Rod equipped (hotbar)")
    else
        warn("[Auto Upgrade] ⚠️ Failed to equip rod from hotbar")
    end

    return success
end

-- Helper: Buy rod
local function buyRod(rodId, rodName)
    if not PurchaseRodEvent then
        warn("[Auto Upgrade] ❌ PurchaseRodEvent not available")
        return false
    end

    local success, result = pcall(function()
        return PurchaseRodEvent:InvokeServer(rodId)
    end)

    if success and result then
        print(string.format("[Auto Upgrade] ✅ Purchased: %s (ID: %d)", rodName, rodId))
        return true
    else
        warn(string.format("[Auto Upgrade] ❌ Failed to purchase: %s (ID: %d) - %s", rodName, rodId, tostring(result)))
        return false
    end
end

-- Helper: Buy bait
local function buyBait(baitId, baitName)
    if not PurchaseBaitEvent then
        warn("[Auto Upgrade] ❌ PurchaseBaitEvent not available")
        return false
    end

    local success, result = pcall(function()
        return PurchaseBaitEvent:InvokeServer(baitId)
    end)

    if success and result then
        print(string.format("[Auto Upgrade] ✅ Purchased: %s (ID: %d)", baitName, baitId))
        return true
    else
        warn(string.format("[Auto Upgrade] ❌ Failed to purchase: %s (ID: %d) - %s", baitName, baitId, tostring(result)))
        return false
    end
end

-- Helper: Equip specific rod by UUID (after purchase)
local function equipSpecificRod(rodUUID)
    local success = pcall(function()
        EquipItemEvent:FireServer(rodUUID, "Fishing Rods")
    end)

    if success then
        print(string.format("[Auto Upgrade] 🎣 Rod equipped (UUID: %s)", rodUUID))
    else
        warn("[Auto Upgrade] ⚠️ Failed to equip specific rod")
    end

    return success
end

-- Helper: Equip specific bait by ID
local function equipSpecificBait(baitId)
    local success = pcall(function()
        EquipBaitEvent:FireServer(baitId)
    end)

    if success then
        print(string.format("[Auto Upgrade] 🪱 Bait equipped (ID: %d)", baitId))
    else
        warn("[Auto Upgrade] ⚠️ Failed to equip bait")
    end

    return success
end

-- Helper: Get latest rod UUID by ID
local function getLatestRodUUID(rodId)
    local uuid = nil

    pcall(function()
        if not PlayerData then return end

        local inventory = PlayerData:GetExpect("Inventory")
        if not inventory then return end

        local rods = inventory["Fishing Rods"] or {}

        -- Find the latest rod with matching ID
        for i = #rods, 1, -1 do
            if rods[i] and rods[i].Id == rodId and rods[i].UUID then
                uuid = rods[i].UUID
                break
            end
        end
    end)

    return uuid
end

-- Helper: Get best (most expensive) owned rod
local function getBestOwnedRod()
    local ownedRods = detectOwnedRods()
    local bestRod = nil
    local bestPrice = 0

    for _, rod in ipairs(rodPrices) do
        for _, ownedId in ipairs(ownedRods) do
            if rod.id == ownedId and rod.price > bestPrice then
                bestRod = rod
                bestPrice = rod.price
            end
        end
    end

    return bestRod
end

-- Helper: Get best (most expensive) owned bait
local function getBestOwnedBait()
    local ownedBaits = detectOwnedBaits()
    local bestBait = nil
    local bestPrice = 0

    for _, bait in ipairs(baitPrices) do
        for _, ownedId in ipairs(ownedBaits) do
            if bait.id == ownedId and bait.price > bestPrice then
                bestBait = bait
                bestPrice = bait.price
            end
        end
    end

    return bestBait
end

-- Helper: Find all affordable items (batch purchase)
local function findAffordableRods(currentCoins, ownedRods)
    local affordableRods = {}
    local totalCost = 0

    for _, rod in ipairs(rodPrices) do
        local isOwned = false
        for _, ownedId in ipairs(ownedRods) do
            if rod.id == ownedId then
                isOwned = true
                break
            end
        end

        if not isOwned and (totalCost + rod.price) <= currentCoins then
            table.insert(affordableRods, rod)
            totalCost = totalCost + rod.price
        end
    end

    return affordableRods, totalCost
end

local function findAffordableBaits(currentCoins, ownedBaits)
    local affordableBaits = {}
    local totalCost = 0

    for _, bait in ipairs(baitPrices) do
        local isOwned = false
        for _, ownedId in ipairs(ownedBaits) do
            if bait.id == ownedId then
                isOwned = true
                break
            end
        end

        if not isOwned and (totalCost + bait.price) <= currentCoins then
            table.insert(affordableBaits, bait)
            totalCost = totalCost + bait.price
        end
    end

    return affordableBaits, totalCost
end

-- Helper: Initial check and equip best rod/bait (run once at start)
local function initialEquipBestItems()
    print(string.rep("=", 70))
    print("🔍 INITIAL CHECK - Equipping Best Items")
    print(string.rep("=", 70))

    -- Step 1: Save current auto farm state
    local autoFarmWasEnabled = _G.AUTO_FARM_ENABLED
    local autoFarmV2WasEnabled = _G.AUTO_FARM_V2_ENABLED

    -- Step 2: Disable auto farm if running
    if autoFarmWasEnabled or autoFarmV2WasEnabled then
        print("[Initial Check] ⏸️ Pausing auto farm...")

        if autoFarmWasEnabled then
            _G.AUTO_FARM_ENABLED = false
            task.wait(3)
        end

        if autoFarmV2WasEnabled then
            _G.AUTO_FARM_V2_ENABLED = false
            task.wait(3)
        end

        task.wait(2) -- Additional wait to ensure fully stopped
    end

    -- Step 3: Unequip current tool
    print("[Initial Check] 🔓 Unequipping current tool...")
    unequipTool()
    task.wait(1.5)

    -- Step 4: Detect and equip best rod
    local bestRod = getBestOwnedRod()
    if bestRod then
        print(string.format("[Initial Check] 🎣 Best Rod: %s (Price: %s)", bestRod.name, FormatNumber(bestRod.price)))

        local rodUUID = getLatestRodUUID(bestRod.id)
        if rodUUID then
            equipSpecificRod(rodUUID)
            task.wait(1.5)
        else
            equipRodHotbar()
            task.wait(1.5)
        end
    else
        print("[Initial Check] ⚠️ No rod found in inventory, equipping default")
        equipRodHotbar()
        task.wait(1.5)
    end

    -- Step 5: Detect and equip best bait
    local bestBait = getBestOwnedBait()
    if bestBait then
        print(string.format("[Initial Check] 🪱 Best Bait: %s (Price: %s)", bestBait.name, FormatNumber(bestBait.price)))
        equipSpecificBait(bestBait.id)
        task.wait(1.5)
    else
        print("[Initial Check] ⚠️ No bait found in inventory")
    end

    -- Step 6: Re-enable auto farm if it was running before
    if autoFarmWasEnabled or autoFarmV2WasEnabled then
        print("[Initial Check] ▶️ Resuming auto farm...")

        if autoFarmWasEnabled then
            _G.AUTO_FARM_ENABLED = true
        end

        if autoFarmV2WasEnabled then
            _G.AUTO_FARM_V2_ENABLED = true
        end
    end

    print(string.rep("=", 70))
    print("✅ INITIAL CHECK COMPLETE - Best items equipped!")
    print(string.rep("=", 70) .. "\n")
end

-- Main: Auto Upgrade Rod Loop
local function autoUpgradeRodLoop()
    if upgradeState.rod.running then
        warn("[Auto Upgrade Rod] ⚠️ Already running!")
        return
    end

    upgradeState.rod.running = true
    print(string.rep("=", 70))
    print("🚀 AUTO UPGRADE ROD - STARTED")
    print(string.rep("=", 70))

    -- Run initial check once
    task.wait(2)
    initialEquipBestItems()

    task.spawn(function()
        while _G.AUTO_UPGRADE_ROD_ENABLED do
            -- Wait if bait is currently purchasing
            while upgradeState.isPurchasing and _G.AUTO_UPGRADE_ROD_ENABLED do
                task.wait(1)
            end

            if not _G.AUTO_UPGRADE_ROD_ENABLED then break end

            -- Step 1: Detect owned rods
            upgradeState.rod.ownedRods = detectOwnedRods()

            -- Step 2: Find ALL affordable rods (batch purchase)
            local currentCoins = getCurrentCoinsUpgrade()
            local affordableRods, totalCost = findAffordableRods(currentCoins, upgradeState.rod.ownedRods)

            if #affordableRods == 0 then
                print("[Auto Upgrade Rod] ✅ All rods purchased! Auto upgrade complete.")
                _G.AUTO_UPGRADE_ROD_ENABLED = false
                break
            end

            print(string.format("[Auto Upgrade Rod] 🎯 Found %d affordable rods | Total Cost: %s",
                #affordableRods,
                FormatNumber(totalCost)))

            -- Show list of rods to purchase
            for i, rod in ipairs(affordableRods) do
                print(string.format("  %d. %s - %s coins", i, rod.name, FormatNumber(rod.price)))
            end

            -- Step 3: Wait until we have enough coins for batch purchase
            while currentCoins < totalCost and _G.AUTO_UPGRADE_ROD_ENABLED do
                print(string.format("[Auto Upgrade Rod] 💰 Farming... Current: %s | Need: %s",
                    FormatCoins(currentCoins),
                    FormatCoins(totalCost)))

                task.wait(10) -- Check every 10 seconds
                currentCoins = getCurrentCoinsUpgrade()

                -- Re-calculate affordable rods in case prices changed
                affordableRods, totalCost = findAffordableRods(currentCoins, upgradeState.rod.ownedRods)
            end

            if not _G.AUTO_UPGRADE_ROD_ENABLED then break end

            -- Lock purchasing
            upgradeState.isPurchasing = true

            -- Step 4: We have enough coins, pause auto farm
            print(string.format("[Auto Upgrade Rod] ✅ Enough coins! Purchasing %d rods...", #affordableRods))

            local autoFarmWasEnabled = _G.AUTO_FARM_ENABLED
            local autoFarmV2WasEnabled = _G.AUTO_FARM_V2_ENABLED

            if autoFarmWasEnabled then
                _G.AUTO_FARM_ENABLED = false
                task.wait(3)
            end

            if autoFarmV2WasEnabled then
                _G.AUTO_FARM_V2_ENABLED = false
                task.wait(3)
            end

            task.wait(2)

            -- Step 5: Unequip tool
            unequipTool()
            task.wait(1.5)

            -- Step 6: BATCH PURCHASE - Buy all affordable rods
            local purchasedCount = 0
            local lastPurchasedRod = nil

            for _, rod in ipairs(affordableRods) do
                print(string.format("[Auto Upgrade Rod] 🛒 Purchasing %d/%d: %s...",
                    purchasedCount + 1, #affordableRods, rod.name))

                local success = buyRod(rod.id, rod.name)
                if success then
                    purchasedCount = purchasedCount + 1
                    lastPurchasedRod = rod
                    task.wait(2) -- Wait between purchases
                else
                    warn(string.format("[Auto Upgrade Rod] ⚠️ Failed to purchase %s, skipping...", rod.name))
                end
            end

            print(string.format("[Auto Upgrade Rod] ✅ Batch Purchase Complete: %d/%d rods purchased",
                purchasedCount, #affordableRods))

            task.wait(2)

            -- Step 7: Equip BEST rod (most expensive owned)
            local bestRod = getBestOwnedRod()
            if bestRod then
                print(string.format("[Auto Upgrade Rod] 🎣 Equipping Best Rod: %s", bestRod.name))

                local rodUUID = getLatestRodUUID(bestRod.id)
                if rodUUID then
                    equipSpecificRod(rodUUID)
                else
                    equipRodHotbar()
                end
                task.wait(1.5)
            else
                equipRodHotbar()
                task.wait(1.5)
            end

            -- Step 8: Resume auto farm
            print("[Auto Upgrade Rod] ♻️ Resuming auto farm...")

            if autoFarmWasEnabled then
                _G.AUTO_FARM_ENABLED = true
            end

            if autoFarmV2WasEnabled then
                _G.AUTO_FARM_V2_ENABLED = true
            end

            -- Unlock purchasing
            upgradeState.isPurchasing = false

            task.wait(10)
        end

        upgradeState.rod.running = false
        print(string.rep("=", 70))
        print("🛑 AUTO UPGRADE ROD - STOPPED")
        print(string.rep("=", 70))
    end)
end

-- Main: Auto Upgrade Bait Loop
local function autoUpgradeBaitLoop()
    if upgradeState.bait.running then
        warn("[Auto Upgrade Bait] ⚠️ Already running!")
        return
    end

    upgradeState.bait.running = true
    print(string.rep("=", 70))
    print("🚀 AUTO UPGRADE BAIT - STARTED")
    print(string.rep("=", 70))

    task.spawn(function()
        while _G.AUTO_UPGRADE_BAIT_ENABLED do
            -- Wait if rod is currently purchasing
            while upgradeState.isPurchasing and _G.AUTO_UPGRADE_BAIT_ENABLED do
                task.wait(1)
            end

            if not _G.AUTO_UPGRADE_BAIT_ENABLED then break end

            -- Step 1: Detect owned baits
            upgradeState.bait.ownedBaits = detectOwnedBaits()

            -- Step 2: Find ALL affordable baits (batch purchase)
            local currentCoins = getCurrentCoinsUpgrade()
            local affordableBaits, totalCost = findAffordableBaits(currentCoins, upgradeState.bait.ownedBaits)

            if #affordableBaits == 0 then
                print("[Auto Upgrade Bait] ✅ All baits purchased! Auto upgrade complete.")
                _G.AUTO_UPGRADE_BAIT_ENABLED = false
                break
            end

            print(string.format("[Auto Upgrade Bait] 🎯 Found %d affordable baits | Total Cost: %s",
                #affordableBaits,
                FormatNumber(totalCost)))

            -- Show list of baits to purchase
            for i, bait in ipairs(affordableBaits) do
                print(string.format("  %d. %s - %s coins", i, bait.name, FormatNumber(bait.price)))
            end

            -- Step 3: Wait until we have enough coins for batch purchase
            while currentCoins < totalCost and _G.AUTO_UPGRADE_BAIT_ENABLED do
                print(string.format("[Auto Upgrade Bait] 💰 Farming... Current: %s | Need: %s",
                    FormatCoins(currentCoins),
                    FormatCoins(totalCost)))

                task.wait(10) -- Check every 10 seconds
                currentCoins = getCurrentCoinsUpgrade()

                -- Re-calculate affordable baits
                affordableBaits, totalCost = findAffordableBaits(currentCoins, upgradeState.bait.ownedBaits)
            end

            if not _G.AUTO_UPGRADE_BAIT_ENABLED then break end

            -- Lock purchasing
            upgradeState.isPurchasing = true

            -- Step 4: We have enough coins, pause auto farm
            print(string.format("[Auto Upgrade Bait] ✅ Enough coins! Purchasing %d baits...", #affordableBaits))

            local autoFarmWasEnabled = _G.AUTO_FARM_ENABLED
            local autoFarmV2WasEnabled = _G.AUTO_FARM_V2_ENABLED

            if autoFarmWasEnabled then
                _G.AUTO_FARM_ENABLED = false
                task.wait(3)
            end

            if autoFarmV2WasEnabled then
                _G.AUTO_FARM_V2_ENABLED = false
                task.wait(3)
            end

            task.wait(2)

            -- Step 5: Unequip tool
            unequipTool()
            task.wait(1.5)

            -- Step 6: BATCH PURCHASE - Buy all affordable baits
            local purchasedCount = 0

            for _, bait in ipairs(affordableBaits) do
                print(string.format("[Auto Upgrade Bait] 🛒 Purchasing %d/%d: %s...",
                    purchasedCount + 1, #affordableBaits, bait.name))

                local success = buyBait(bait.id, bait.name)
                if success then
                    purchasedCount = purchasedCount + 1
                    task.wait(2) -- Wait between purchases
                else
                    warn(string.format("[Auto Upgrade Bait] ⚠️ Failed to purchase %s, skipping...", bait.name))
                end
            end

            print(string.format("[Auto Upgrade Bait] ✅ Batch Purchase Complete: %d/%d baits purchased",
                purchasedCount, #affordableBaits))

            task.wait(2)

            -- Step 7: Equip BEST bait (most expensive owned)
            local bestBait = getBestOwnedBait()
            if bestBait then
                print(string.format("[Auto Upgrade Bait] 🪱 Equipping Best Bait: %s", bestBait.name))
                equipSpecificBait(bestBait.id)
                task.wait(1.5)
            else
                task.wait(1.5)
            end

            -- Step 8: Equip best rod
            local bestRod = getBestOwnedRod()
            if bestRod then
                local rodUUID = getLatestRodUUID(bestRod.id)
                if rodUUID then
                    equipSpecificRod(rodUUID)
                else
                    equipRodHotbar()
                end
                task.wait(1.5)
            else
                equipRodHotbar()
                task.wait(1.5)
            end

            -- Step 9: Resume auto farm
            print("[Auto Upgrade Bait] ♻️ Resuming auto farm...")

            if autoFarmWasEnabled then
                _G.AUTO_FARM_ENABLED = true
            end

            if autoFarmV2WasEnabled then
                _G.AUTO_FARM_V2_ENABLED = true
            end

            -- Unlock purchasing
            upgradeState.isPurchasing = false

            task.wait(10)
        end

        upgradeState.bait.running = false
        print(string.rep("=", 70))
        print("🛑 AUTO UPGRADE BAIT - STOPPED")
        print(string.rep("=", 70))
    end)
end

-- Start/Stop Functions (called from UI)
function startAutoUpgradeRod()
    if not _G.AUTO_UPGRADE_ROD_ENABLED then return end
    autoUpgradeRodLoop()
end

function stopAutoUpgradeRod()
    _G.AUTO_UPGRADE_ROD_ENABLED = false
    upgradeState.rod.running = false
end

function startAutoUpgradeBait()
    if not _G.AUTO_UPGRADE_BAIT_ENABLED then return end
    autoUpgradeBaitLoop()
end

function stopAutoUpgradeBait()
    _G.AUTO_UPGRADE_BAIT_ENABLED = false
    upgradeState.bait.running = false
end

print("✅ Auto Upgrade System loaded\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: AUTO FARM MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Farm Module - Main fishing automation logic

    EDIT START: Line below this marker
    EDIT END: Before next section marker

    Key Functions:
    - startReelIntermissionLoop() - Start fishing animation
    - stopReelIntermissionLoop() - Stop fishing animation
    - runMainLoop() - Main fishing cycle
]]

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM: Animation System (DISABLED - No Animations)
-- ─────────────────────────────────────────────────────────────────────────

-- Animation system removed for performance optimization
-- All animation functions are now no-op (do nothing)

local function startReelIntermissionLoop()
    -- Stop all fishing animations once when auto farm starts
    stopAllFishingAnimations()
end

local function stopReelIntermissionLoop()
    -- Cleanup animation blocks when auto farm stops
    cleanupAnimationBlocks()
end

_G.StopReelIntermissionLoop = stopReelIntermissionLoop

print("✅ Animation system disabled (no animations)")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM: FishCaught Path Deletion
-- ─────────────────────────────────────────────────────────────────────────

local function deleteFishCaughtPath()
    pcall(function()
        local playerGui = player:WaitForChild("PlayerGui")
        if playerGui:FindFirstChild("FishCaught") then
            playerGui.FishCaught:Destroy()
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        deleteFishCaughtPath()
    end
end)

print("✅ FishCaught deletion active")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM: Core Fishing Functions
-- ─────────────────────────────────────────────────────────────────────────

function equip_tool()
    EquipToolEvent:FireServer(1)
end

function charge_rod()
    -- Simple charge - just sync server time
    local serverTime = workspace:GetServerTimeNow()
    local success, adjustedTime = ChargeEvent:InvokeServer(nil, nil, nil, serverTime)

    return success, adjustedTime
end

function request_fishing()
    local serverTime = workspace:GetServerTimeNow()
    local posY = math.random() * 2 - 1  -- Random -1 to 1
    local power = math.random()  -- Random 0 to 1

    return RequestEvent:InvokeServer(posY, power, serverTime)
end

function fishing_completed()
    CompletedEvent:FireServer()
end

function cancel_inputs_bypass()
    task.spawn(function()
        CancelEvent:InvokeServer()
    end)
end

print("✅ Fishing functions loaded")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM: Main Loop
-- ─────────────────────────────────────────────────────────────────────────

_G.MAIN_LOOP_RUNNING = false

function runMainLoop()
    if _G.MAIN_LOOP_RUNNING then
        return
    end

    _G.MAIN_LOOP_RUNNING = true

    local cycleCount = 0
    local successCount = 0

    while _G.MAIN_LOOP_RUNNING do
        -- Wait for farm to be enabled
        while not _G.AUTO_FARM_ENABLED and _G.MAIN_LOOP_RUNNING do
            task.wait(0.5)
        end

        if not _G.MAIN_LOOP_RUNNING then break end
        if not _G.AUTO_FARM_ENABLED then continue end

        cycleCount = cycleCount + 1

        -- Fishing cycle
        equip_tool()
        charge_rod()
        task.wait(0.01)  -- Small delay for server sync

        local success, result = request_fishing()

        if success then
            successCount = successCount + 1
            task.wait(_G.FARM_SUCCESS_DELAY)
            fishing_completed()
        end

        task.wait(0.2)
        cancel_inputs_bypass()
        task.wait(0.01)
    end

    -- Cleanup
    stopReelIntermissionLoop()
    _G.MAIN_LOOP_RUNNING = false
end

print("✅ Auto farm V1 module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2.4: AUTO FARM V2 MODULE (JUNG V2 - FAST)
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Farm V2 Module - Jung V2 fast auto farm logic

    Features:
    - Independent main loop (doesn't wait for completion)
    - Server-based completion handler (parallel)
    - Ping compensation system (auto-adjust delays)
    - Fixed parameters: RequestFishingMinigame(-1, 0) for OK rating
    - Custom delays: Delay Reel + Delay Complete

    Key Functions:
    - startAutoFarmV2() - Start Jung V2 auto farm
    - stopAutoFarmV2() - Stop Jung V2 auto farm
    - mainFishingLoopV2() - Main independent loop
]]

print("📦 Loading Auto Farm V2 (Jung V2 - Fast)...")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM V2: Ping Measurement & Compensation
-- ─────────────────────────────────────────────────────────────────────────

local function measurePing()
    local pingStart = tick()
    pcall(function()
        workspace:GetServerTimeNow()
    end)
    return (tick() - pingStart) * 1000  -- Convert to milliseconds
end

local function calculateCompensatedDelays()
    local State = _G.JUNG_V2_STATE

    if not State.autoPingCompensation then
        State.delayReel = State.baseDelayReel
        State.delayComplete = State.baseDelayComplete
        return
    end

    State.currentPing = measurePing()
    local referencePing = 55  -- ms
    local pingDelta = State.currentPing - referencePing

    if pingDelta > 0 then
        local compensation = (pingDelta / 1000) * 2
        State.delayReel = State.baseDelayReel + (compensation * 0.3)
        State.delayComplete = State.baseDelayComplete + (compensation * 0.7)
    else
        State.delayReel = State.baseDelayReel
        State.delayComplete = State.baseDelayComplete
    end

    State.delayReel = math.round(State.delayReel * 100) / 100
    State.delayComplete = math.round(State.delayComplete * 100) / 100
end

-- Update ping periodically
task.spawn(function()
    while true do
        task.wait(5)
        if _G.JUNG_V2_STATE.isRunning and _G.JUNG_V2_STATE.autoPingCompensation then
            calculateCompensatedDelays()
        end
    end
end)

print("✅ Ping compensation system ready")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM V2: Fish Caught Listener
-- ─────────────────────────────────────────────────────────────────────────

local fishNotificationEvent = Net["RE/ObtainedNewFishNotification"]
fishNotificationEvent.OnClientEvent:Connect(function(fishId, fishData, itemData, isNew)
    if _G.JUNG_V2_STATE.isRunning then
        _G.JUNG_V2_STATE.fishCaught = _G.JUNG_V2_STATE.fishCaught + 1
    end

    -- Update session stats for GPU Saver white screen
    sessionStats.totalFish = sessionStats.totalFish + 1
end)

print("✅ Fish caught listener (V2) ready")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM V2: Main Loop Logic
-- ─────────────────────────────────────────────────────────────────────────

local function mainFishingLoopV2()
    local State = _G.JUNG_V2_STATE

    while State.isRunning do
        -- Wait first (delayReel)
        task.wait(State.delayReel)

        if not State.isRunning then break end

        State.cycleCount = State.cycleCount + 1

        -- Step 1: Cancel
        pcall(function()
            CancelEvent:InvokeServer()
        end)
        task.wait(0.01)

        -- Step 2: Charge
        pcall(function()
            local timestamp = workspace:GetServerTimeNow()
            ChargeEvent:InvokeServer(timestamp)
        end)
        task.wait(0.01)

        -- Step 3: Request (with server return handler)
        task.spawn(function()
            local success, result = pcall(function()
                -- Fixed parameters: -1, 0 (low power = OK rating)
                return RequestEvent:InvokeServer(-1, 0)
            end)

            if success and result then
                State.totalRequests = State.totalRequests + 1

                -- Handle server return in separate thread
                task.spawn(function()
                    State.pendingCompletes = State.pendingCompletes + 1
                    task.wait(State.delayComplete)

                    pcall(function()
                        CompletedEvent:FireServer()
                    end)

                    State.pendingCompletes = State.pendingCompletes - 1
                end)
            end
        end)

        -- Loop continues immediately!
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM V2: Start/Stop Functions
-- ─────────────────────────────────────────────────────────────────────────

function startAutoFarmV2()
    local State = _G.JUNG_V2_STATE

    if State.isRunning then
        return
    end

    -- Stop V1 if running
    if _G.AUTO_FARM_ENABLED then
        _G.AUTO_FARM_ENABLED = false
    end

    State.isRunning = true
    State.fishCaught = 0
    State.cycleCount = 0
    State.totalRequests = 0
    State.pendingCompletes = 0
    State.startTime = tick()

    -- Stop animations
    startReelIntermissionLoop()

    if State.autoPingCompensation then
        calculateCompensatedDelays()
    end

    -- Equip rod
    pcall(function()
        EquipToolEvent:FireServer(1)
    end)
    task.wait(0.5)

    task.spawn(mainFishingLoopV2)
end

function stopAutoFarmV2()
    local State = _G.JUNG_V2_STATE

    if not State.isRunning then
        return
    end

    State.isRunning = false
    stopReelIntermissionLoop()
end

print("✅ Auto Farm V2 module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2.5: AUTO ARTIFACT MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Artifact Module - Automatic artifact collection from 4 temples

    Features:
    - Sequential temple farming (Temple 1 → 2 → 3 → 4)
    - Auto-favorite artifacts to prevent auto-sell
    - Webhook notifications for each artifact found
    - Automatic teleportation between temples
    - Inventory-based detection system

    Key Functions:
    - AutoArtifact.initialize() - Start the system
    - AutoArtifact.startArtifactChecker() - Main checker loop
    - AutoArtifact.hasArtifactInInventory() - Check for artifacts
    - AutoArtifact.favoriteArtifact() - Auto-favorite found artifacts
]]

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ARTIFACT: State Variables
-- ─────────────────────────────────────────────────────────────────────────

local isAutoArtifactOn = false
local artifactCurrentTemple = 1
local artifactCollected = {false, false, false, false}

-- Skip toggles for each artifact (user can manually mark as "already obtained")
local artifactSkipToggles = {
    [1] = false, -- Hourglass Diamond Artifact
    [2] = false, -- Arrow Artifact
    [3] = false, -- Diamond Artifact
    [4] = false  -- Crescent Artifact
}

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ARTIFACT: Temple Configuration
-- ─────────────────────────────────────────────────────────────────────────

local ARTIFACT_CONFIG = {
    -- Temple 1: Hourglass Diamond Artifact
    {
        templeName = "Temple 1",
        targetArtifact = "Hourglass Diamond Artifact",
        cframe = CFrame.new(1490.12305, 6.62499952, -850.539307, -0.982308805, -4.67861128e-09, -0.187268242, -7.57854224e-09, 1, 1.47694985e-08, 0.187268242, 1.59274283e-08, -0.982308805)
    },
    -- Temple 2: Arrow Artifact
    {
        templeName = "Temple 2",
        targetArtifact = "Arrow Artifact",
        cframe = CFrame.new(883.964233, 6.62499952, -360.91275, -0.128746182, 9.21072107e-09, 0.991677582, -4.92979968e-09, 1, -9.92803972e-09, -0.991677582, -6.16696871e-09, -0.128746182)
    },
    -- Temple 3: Diamond Artifact
    {
        templeName = "Temple 3",
        targetArtifact = "Diamond Artifact",
        cframe = CFrame.new(1836.77136, 6.62499952, -288.573303, 0.25269559, 7.76984699e-09, -0.967545807, 3.12285877e-08, 1, 1.61864921e-08, 0.967545807, -3.43053443e-08, 0.25269559)
    },
    -- Temple 4: Crescent Artifact
    {
        templeName = "Temple 4",
        targetArtifact = "Crescent Artifact",
        cframe = CFrame.new(1405.67358, 6.17587185, 119.126236, -0.951030135, -6.02376886e-08, 0.309098154, -8.03642095e-08, 1, -5.23817469e-08, -0.309098154, -7.4657045e-08, -0.951030135)
    }
}

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ARTIFACT: Inventory Background System
-- ─────────────────────────────────────────────────────────────────────────

local InventoryBackgroundSystem = {}
do
    -- Keep inventory tiles loaded in background for artifact detection
    local inventoryController = nil
    local originalDestroyTiles = nil
    local isInventoryHooked = false
    local isLoadingInventory = false

    -- Get InventoryController module
    local function getInventoryController()
        if inventoryController then return inventoryController end

        local success, result = pcall(function()
            local controllers = ReplicatedStorage:WaitForChild("Controllers", 5)
            local invModule = controllers:WaitForChild("InventoryController", 5)
            return require(invModule)
        end)

        if success then
            inventoryController = result
            return inventoryController
        end

        return nil
    end

    -- Hook DestroyTiles to prevent inventory from being destroyed
    local function hookInventoryController()
        if isInventoryHooked then return true end

        local ctrl = getInventoryController()
        if not ctrl then
            warn("[Inventory Background] Failed to get InventoryController")
            return false
        end

        -- Backup original DestroyTiles function
        originalDestroyTiles = ctrl.DestroyTiles

        -- Override with empty function to prevent destruction
        ctrl.DestroyTiles = function()
            -- Do nothing - keep tiles alive
            return
        end

        isInventoryHooked = true
        print("[Inventory Background] ✅ Hooked DestroyTiles successfully")
        return true
    end

    -- Refresh inventory tiles without opening GUI
    local function refreshInventoryTiles(onCompleteCallback)
        if isLoadingInventory then return end
        isLoadingInventory = true

        local ctrl = getInventoryController()
        if ctrl and ctrl.InventoryStateChanged then
            pcall(function()
                -- Fire state change to refresh tiles
                ctrl.InventoryStateChanged:Fire("Items")
            end)
        end

        task.wait(0.1)
        if onCompleteCallback then
            pcall(onCompleteCallback)
        end
        isLoadingInventory = false
    end

    -- Initial load of inventory tiles (opens GUI briefly then hides)
    local function initialLoadInventoryTiles(onCompleteCallback)
        if isLoadingInventory then return end
        isLoadingInventory = true

        local ctrl = getInventoryController()
        if not ctrl then
            warn("[Inventory Background] InventoryController not available")
            isLoadingInventory = false
            return
        end

        local playerGui = player:WaitForChild("PlayerGui")
        local inventoryGUI = playerGui:FindFirstChild("Inventory")
        local mainFrame = inventoryGUI and inventoryGUI:FindFirstChild("Main")

        if not mainFrame then
            warn("[Inventory Background] Inventory GUI not found")
            isLoadingInventory = false
            return
        end

        -- Save previous state
        local previousEnabled = inventoryGUI.Enabled
        local previousVisible = mainFrame.Visible

        -- Temporarily show inventory to load tiles
        inventoryGUI.Enabled = true
        mainFrame.Visible = true
        task.wait(0.2)

        -- Set to Items category to load artifact tiles
        pcall(function()
            if ctrl.SetPage then ctrl.SetPage(ctrl, "Items") end
            if ctrl.SetCategory then ctrl.SetCategory(ctrl, "Items") end
            if ctrl.InventoryStateChanged then
                ctrl.InventoryStateChanged:Fire("Items")
            end
        end)

        task.wait(0.5)

        -- Restore previous state (hide GUI again)
        inventoryGUI.Enabled = previousEnabled
        mainFrame.Visible = previousVisible

        print("[Inventory Background] ✅ Initial inventory tiles loaded")

        if onCompleteCallback then
            pcall(onCompleteCallback)
        end
        isLoadingInventory = false
    end

    -- Public function to start the background inventory system
    function InventoryBackgroundSystem.start(onRefreshCallback)
        if isInventoryHooked then
            print("[Inventory Background] ⚠️ Already initialized")
            return
        end

        print("[Inventory Background] 🚀 Starting background inventory system...")

        task.spawn(function()
            -- Hook the controller first
            if hookInventoryController() then
                task.wait(1)

                -- Initial load of tiles
                initialLoadInventoryTiles(onRefreshCallback)

                -- Setup auto-refresh on inventory close
                pcall(function()
                    local GuiControl = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GuiControl"))
                    local invGUI = player.PlayerGui:FindFirstChild("Inventory")

                    GuiControl.GuiUnfocusedSignal:Connect(function(closedGui)
                        if closedGui == invGUI then
                            -- Refresh tiles when inventory closes
                            task.delay(0.5, function()
                                refreshInventoryTiles(onRefreshCallback)
                            end)
                        end
                    end)

                    print("[Inventory Background] ✅ Auto-refresh on close enabled")
                end)

                -- Setup refresh on fish caught
                pcall(function()
                    local fishCaughtEvent = Net["RE/FishCaught"]
                    if fishCaughtEvent then
                        fishCaughtEvent.OnClientEvent:Connect(function()
                            task.delay(1, function()
                                refreshInventoryTiles(onRefreshCallback)
                            end)
                        end)
                        print("[Inventory Background] ✅ Auto-refresh on fish caught enabled")
                    end
                end)

                print("[Inventory Background] ✅ Background inventory system active")
            else
                warn("[Inventory Background] ❌ Failed to hook InventoryController")
            end
        end)
    end

    -- Public function to manually refresh tiles
    function InventoryBackgroundSystem.refresh(callback)
        refreshInventoryTiles(callback)
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ARTIFACT: Main Module
-- ─────────────────────────────────────────────────────────────────────────

local AutoArtifact = {}
do
    local HttpService = game:GetService("HttpService")

    -- Webhook URL (optional - set to nil if you don't want webhooks)
    local WEBHOOK_URL = nil -- Change to your webhook URL if needed

    -- Use already loaded modules from SECTION 1
    local FavoriteItemEvent = Net["RE/FavoriteItem"]

    -- Function to get artifact UUID from PlayerData inventory
    function AutoArtifact.getArtifactUUID(artifactName)
        if not PlayerData then return nil end

        local success, result = pcall(function()
            local inventoryItems = PlayerData:GetExpect("Inventory").Items
            for _, item in ipairs(inventoryItems) do
                local itemData = ItemUtility:GetItemData(item.Id)
                if itemData and itemData.Data.Name then
                    local itemName = itemData.Data.Name
                    -- Exact match - case-insensitive
                    if itemName:lower() == artifactName:lower() then
                        return item.UUID, itemName
                    end
                end
            end
            return nil
        end)

        if success and result then
            return result
        else
            return nil
        end
    end

    -- Function to favorite an artifact using UUID
    function AutoArtifact.favoriteArtifact(artifactUUID, artifactName)
        if not artifactUUID then
            warn("[Auto Artifact] Cannot favorite - UUID is nil")
            return false
        end

        local success = pcall(function()
            FavoriteItemEvent:FireServer(artifactUUID)
        end)

        if success then
            print(string.format("[Auto Artifact] ⭐ Favorited: %s", artifactName))
            return true
        else
            warn(string.format("[Auto Artifact] ❌ Failed to favorite: %s", artifactName))
            return false
        end
    end

    -- Check if an item is already favorited
    function AutoArtifact.isItemFavorited(itemUUID)
        if not PlayerData then return false end

        local success, result = pcall(function()
            local inventoryItems = PlayerData:GetExpect("Inventory").Items
            for _, item in ipairs(inventoryItems) do
                if item.UUID == itemUUID then
                    return item.Favorited == true
                end
            end
            return false
        end)

        return success and result or false
    end

    -- Function to auto-favorite all artifacts in inventory
    function AutoArtifact.autoFavoriteAllArtifacts()
        local artifactNames = {
            "Arrow Artifact",
            "Crescent Artifact",
            "Diamond Artifact",
            "Hourglass Diamond Artifact"
        }

        local favorited = 0
        local skipped = 0

        for _, artifactName in ipairs(artifactNames) do
            local uuid, fullName = AutoArtifact.getArtifactUUID(artifactName)
            if uuid then
                -- Check if already favorited
                if AutoArtifact.isItemFavorited(uuid) then
                    skipped = skipped + 1
                else
                    task.wait(0.5)
                    local success = AutoArtifact.favoriteArtifact(uuid, fullName or artifactName)
                    if success then
                        favorited = favorited + 1
                    end
                end
            end
        end

        if favorited > 0 then
            print(string.format("[Auto Artifact] ⭐ Favorited %d new artifacts", favorited))
        end
        if skipped > 0 then
            print(string.format("[Auto Artifact] ⏭️ Skipped %d already favorited", skipped))
        end

        return favorited
    end

    -- Check if artifact exists in inventory (GUI-based check)
    function AutoArtifact.hasArtifactInInventory(artifactName)
        local playerGui = player:FindFirstChild("PlayerGui")
        local invContainer = playerGui and playerGui:FindFirstChild("Inventory")
        invContainer = invContainer and invContainer:FindFirstChild("Main")
        invContainer = invContainer and invContainer:FindFirstChild("Content")
        invContainer = invContainer and invContainer:FindFirstChild("Pages")
        invContainer = invContainer and invContainer:FindFirstChild("Inventory")

        if not invContainer then return false end

        for _, tile in ipairs(invContainer:GetChildren()) do
            if tile.Name == "Tile" and tile:FindFirstChild("ItemName") then
                local itemName = tile.ItemName.Text
                -- Exact match - case-insensitive
                if itemName:lower() == artifactName:lower() then
                    return true, itemName
                end
            end
        end

        return false
    end

    -- Send webhook notification for artifact found
    function AutoArtifact.sendArtifactFoundWebhook(templeName, artifactName, templeNumber)
        if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

        local embed = {
            title = "🏺 Artifact Found!",
            description = string.format("**%s** collected from **%s**", artifactName, templeName),
            color = 16776960, -- Yellow/Gold color
            fields = {
                { name = "👤 Player", value = player.Name, inline = true },
                { name = "🏛️ Temple", value = templeName, inline = true },
                { name = "🏺 Artifact", value = artifactName, inline = true },
                { name = "📍 Progress", value = string.format("%d/4 Temples Completed", templeNumber), inline = false },
                { name = "🕒 Time", value = os.date("%H:%M:%S"), inline = false }
            },
            footer = { text = "Auto Artifact System" }
        }

        local payload = { embeds = {embed} }

        pcall(function()
            local req = (syn and syn.request) or http_request
            if req then
                req({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(payload)
                })
            end
        end)
    end

    -- Send webhook notification when all artifacts collected
    function AutoArtifact.sendAllArtifactsCompleteWebhook()
        if not WEBHOOK_URL or WEBHOOK_URL == "" then return end

        local embed = {
            title = "✅ ALL ARTIFACTS COLLECTED!",
            description = "**All 4 artifacts have been successfully collected!**",
            color = 65280, -- Green color
            fields = {
                { name = "👤 Player", value = player.Name, inline = true },
                { name = "🏆 Status", value = "COMPLETE", inline = true },
                { name = "🏺 Artifacts", value = "4/4 Collected", inline = true },
                { name = "🕒 Completed At", value = os.date("%H:%M:%S"), inline = false }
            },
            footer = { text = "Auto Artifact System - Farm Complete!" }
        }

        local payload = { embeds = {embed} }

        pcall(function()
            local req = (syn and syn.request) or http_request
            if req then
                req({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(payload)
                })
            end
        end)
    end

    -- Teleport player to temple location
    function AutoArtifact.teleportToTemple(cframeData)
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return false end

        pcall(function()
            humanoidRootPart.CFrame = cframeData
        end)

        return true
    end

    -- Main artifact checker loop
    function AutoArtifact.startArtifactChecker()
        task.spawn(function()
            print("[Auto Artifact] " .. string.rep("=", 60))
            print("[Auto Artifact] 🔍 Artifact Checker Loop Started!")
            print("[Auto Artifact] " .. string.rep("=", 60))

            local lastCheckLog = 0
            local LOG_INTERVAL = 60 -- Log every 60 seconds

            while isAutoArtifactOn and artifactCurrentTemple <= 4 do
                -- Get current temple config
                local currentConfig = ARTIFACT_CONFIG[artifactCurrentTemple]

                -- Check if this temple is marked as "skip"
                if artifactSkipToggles[artifactCurrentTemple] then
                    print("[Auto Artifact] " .. string.rep("=", 60))
                    print(string.format("[Auto Artifact] ⏭️ SKIPPED: %s (manually marked)", currentConfig.targetArtifact))
                    print(string.format("[Auto Artifact] 🏛️ Temple: %s", currentConfig.templeName))
                    print("[Auto Artifact] " .. string.rep("=", 60))

                    -- Mark as collected and move to next
                    artifactCollected[artifactCurrentTemple] = true
                    artifactCurrentTemple = artifactCurrentTemple + 1

                    if artifactCurrentTemple <= 4 then
                        local nextConfig = ARTIFACT_CONFIG[artifactCurrentTemple]
                        print("[Auto Artifact] " .. string.rep("=", 60))
                        print(string.format("[Auto Artifact] 📍 NEXT: %s", nextConfig.templeName))
                        print(string.format("[Auto Artifact] 🎯 TARGET: %s", nextConfig.targetArtifact))
                        print("[Auto Artifact] " .. string.rep("=", 60))

                        -- Teleport to next temple
                        task.wait(1)
                        AutoArtifact.teleportToTemple(nextConfig.cframe)
                        print("[Auto Artifact] ✅ Teleported to next temple!")
                        task.wait(3)
                    end

                    -- Continue to next iteration
                    task.wait(0.5)
                    continue
                end

                -- Log status every 60 seconds
                if tick() - lastCheckLog >= LOG_INTERVAL then
                    print(string.format("[Auto Artifact] 🔍 Checking for %s at %s (Temple %d/4)",
                        currentConfig.targetArtifact,
                        currentConfig.templeName,
                        artifactCurrentTemple))
                    lastCheckLog = tick()
                end

                if not artifactCollected[artifactCurrentTemple] then
                    -- Check if target artifact is in inventory
                    local hasArtifact, fullName = AutoArtifact.hasArtifactInInventory(currentConfig.targetArtifact)

                    if hasArtifact then
                        print("[Auto Artifact] " .. string.rep("=", 60))
                        print(string.format("[Auto Artifact] ✅ ARTIFACT FOUND: %s", fullName))
                        print(string.format("[Auto Artifact] 🏛️ Location: %s", currentConfig.templeName))
                        print("[Auto Artifact] " .. string.rep("=", 60))

                        -- Mark as collected
                        artifactCollected[artifactCurrentTemple] = true

                        -- Auto-favorite the artifact
                        print("[Auto Artifact] 🌟 Checking if artifact needs favoriting...")
                        task.wait(1)

                        local artifactUUID, artifactFullName = AutoArtifact.getArtifactUUID(currentConfig.targetArtifact)
                        if artifactUUID then
                            if AutoArtifact.isItemFavorited(artifactUUID) then
                                print(string.format("[Auto Artifact] ⏭️ '%s' already favorited", artifactFullName or fullName))
                            else
                                print(string.format("[Auto Artifact] 🌟 Favoriting: %s", artifactFullName or fullName))
                                AutoArtifact.favoriteArtifact(artifactUUID, artifactFullName or fullName)
                            end
                        else
                            warn("[Auto Artifact] ⚠️ Could not find artifact UUID")
                        end

                        task.wait(1)

                        -- Send webhook notification
                        AutoArtifact.sendArtifactFoundWebhook(
                            currentConfig.templeName,
                            fullName or currentConfig.targetArtifact,
                            artifactCurrentTemple
                        )

                        print("[Auto Artifact] 📤 Webhook sent (if configured)")
                        task.wait(2)

                        -- Move to next temple
                        artifactCurrentTemple = artifactCurrentTemple + 1

                        if artifactCurrentTemple <= 4 then
                            local nextConfig = ARTIFACT_CONFIG[artifactCurrentTemple]
                            print("[Auto Artifact] " .. string.rep("=", 60))
                            print(string.format("[Auto Artifact] 📍 NEXT: %s", nextConfig.templeName))
                            print(string.format("[Auto Artifact] 🎯 TARGET: %s", nextConfig.targetArtifact))
                            print("[Auto Artifact] " .. string.rep("=", 60))

                            -- Teleport to next temple
                            task.wait(1)
                            AutoArtifact.teleportToTemple(nextConfig.cframe)
                            print("[Auto Artifact] ✅ Teleported to next temple!")
                            task.wait(3)
                        else
                            -- All artifacts collected!
                            print("[Auto Artifact] " .. string.rep("=", 60))
                            print("[Auto Artifact] 🎉🎉🎉 ALL ARTIFACTS COLLECTED! 🎉🎉🎉")
                            print("[Auto Artifact] " .. string.rep("=", 60))

                            -- Send completion webhook
                            AutoArtifact.sendAllArtifactsCompleteWebhook()
                            print("[Auto Artifact] 📤 Completion webhook sent!")

                            -- Stop the system
                            isAutoArtifactOn = false
                            _G.AUTO_ARTIFACT_ENABLED = false
                            print("[Auto Artifact] ✅ System completed successfully!")
                            break
                        end
                    end
                end

                task.wait(5) -- Check every 5 seconds
            end

            if artifactCurrentTemple > 4 then
                print("[Auto Artifact] " .. string.rep("=", 60))
                print("[Auto Artifact] System stopped - All artifacts collected")
                print("[Auto Artifact] " .. string.rep("=", 60))
            end
        end)
    end

    -- Initialize and start system
    function AutoArtifact.initialize()
        if not isAutoArtifactOn then
            print("[Auto Artifact] ⚠️ System not enabled")
            return
        end

        print("[Auto Artifact] 🚀 Initializing Auto Artifact System...")

        -- Reset state if restarting
        if artifactCurrentTemple > 4 then
            artifactCurrentTemple = 1
            artifactCollected = {false, false, false, false}
            print("[Auto Artifact] 🔄 Reset progress (restarting)")
        end

        -- Auto-favorite any existing artifacts
        task.wait(2)
        AutoArtifact.autoFavoriteAllArtifacts()
        task.wait(1)

        -- Find first temple that is not skipped
        local startTemple = artifactCurrentTemple
        while startTemple <= 4 and artifactSkipToggles[startTemple] do
            print(string.format("[Auto Artifact] ⏭️ Skipping %s (marked as obtained)", ARTIFACT_CONFIG[startTemple].targetArtifact))
            artifactCollected[startTemple] = true
            startTemple = startTemple + 1
        end

        -- Update current temple
        artifactCurrentTemple = startTemple

        -- Check if all temples are skipped
        if artifactCurrentTemple > 4 then
            print("[Auto Artifact] ⚠️ All artifacts are marked as skip!")
            print("[Auto Artifact] ⚠️ Nothing to farm. System will not start.")
            isAutoArtifactOn = false
            _G.AUTO_ARTIFACT_ENABLED = false
            return
        end

        -- Teleport to first non-skipped temple
        local currentConfig = ARTIFACT_CONFIG[artifactCurrentTemple]
        print(string.format("[Auto Artifact] 📍 Starting at %s", currentConfig.templeName))
        print(string.format("[Auto Artifact] 🎯 Target: %s", currentConfig.targetArtifact))

        task.wait(1)
        AutoArtifact.teleportToTemple(currentConfig.cframe)
        print("[Auto Artifact] ✅ Teleported to temple!")
        task.wait(2)

        -- Start the checker loop
        AutoArtifact.startArtifactChecker()
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ARTIFACT: Control Functions
-- ─────────────────────────────────────────────────────────────────────────

local function startAutoArtifact()
    if isAutoArtifactOn then
        print("⚠️ Auto Artifact already enabled!")
        return
    end

    print("\n🎯 Starting Auto Artifact System...")
    isAutoArtifactOn = true
    _G.AUTO_ARTIFACT_ENABLED = true

    -- Start background inventory system first
    task.spawn(function()
        print("[Auto Artifact] 🔄 Initializing background inventory...")
        InventoryBackgroundSystem.start(function()
            -- Callback after inventory refresh
            print("[Auto Artifact] 📦 Inventory refreshed")
        end)

        -- Wait for inventory to be ready
        task.wait(3)

        -- Start the artifact system
        AutoArtifact.initialize()
    end)

    print("✅ Auto Artifact ENABLED\n")
end

local function stopAutoArtifact()
    if not isAutoArtifactOn then
        print("⚠️ Auto Artifact already stopped!")
        return
    end

    print("\n🛑 Stopping Auto Artifact System...")
    isAutoArtifactOn = false
    _G.AUTO_ARTIFACT_ENABLED = false

    print("✅ Auto Artifact stopped\n")
end

print("✅ Auto artifact module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2.6: AUTO SELL MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Sell Module - Automatic item selling with custom delay

    Key Functions:
    - startAutoSell() - Start auto sell loop
    - stopAutoSell() - Stop auto sell loop
    - runAutoSellLoop() - Main selling loop
]]

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO SELL: State Variables
-- ─────────────────────────────────────────────────────────────────────────

local isAutoSellRunning = false

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO SELL: Main Functions
-- ─────────────────────────────────────────────────────────────────────────

local function runAutoSellLoop()
    if isAutoSellRunning then
        print("⚠️ Auto Sell loop already running!")
        return
    end

    isAutoSellRunning = true
    print(string.rep("=", 70))
    print("💰 AUTO SELL LOOP - STARTING")
    print(string.rep("=", 70) .. "\n")

    local cycleCount = 0
    local sellSuccessCount = 0
    local sellFailCount = 0

    -- Get SellAllItems event
    local SellAllItemsEvent = Net["RF/SellAllItems"]

    while isAutoSellRunning and _G.AUTO_SELL_ENABLED do
        cycleCount = cycleCount + 1

        print(string.format("[Auto Sell #%d] 💰 Attempting to sell all items...", cycleCount))

        -- Invoke sell event
        local success, result = pcall(function()
            return SellAllItemsEvent:InvokeServer()
        end)

        if success then
            if result then
                sellSuccessCount = sellSuccessCount + 1
                print(string.format("[Auto Sell #%d] ✅ Items sold successfully", cycleCount))
            else
                sellFailCount = sellFailCount + 1
                print(string.format("[Auto Sell #%d] ⚠️ No items to sell or sell failed", cycleCount))
            end
        else
            sellFailCount = sellFailCount + 1
            warn(string.format("[Auto Sell #%d] ❌ Error selling items: %s", cycleCount, tostring(result)))
        end

        -- Stats every 5 cycles
        if cycleCount % 5 == 0 then
            print(string.format("\n📊 [AUTO SELL STATS] Cycles: %d | Success: %d | Failed: %d | Delay: %ds | Status: %s\n",
                cycleCount,
                sellSuccessCount,
                sellFailCount,
                _G.AUTO_SELL_DELAY,
                _G.AUTO_SELL_ENABLED and "🟢 ON" or "🔴 OFF"
            ))
        end

        -- Wait for the specified delay
        local delayRemaining = _G.AUTO_SELL_DELAY
        while delayRemaining > 0 and isAutoSellRunning and _G.AUTO_SELL_ENABLED do
            task.wait(1)
            delayRemaining = delayRemaining - 1
        end
    end

    -- Cleanup
    print("\n" .. string.rep("=", 70))
    print("🛑 AUTO SELL LOOP STOPPED")
    print(string.rep("=", 70))
    if cycleCount > 0 then
        print(string.format("\n📊 FINAL STATS: %d cycles | %d success | %d failed\n",
            cycleCount, sellSuccessCount, sellFailCount))
    end

    isAutoSellRunning = false
end

local function startAutoSell()
    if _G.AUTO_SELL_ENABLED then
        print("⚠️ Auto Sell already enabled!")
        return
    end

    print("\n💰 Starting Auto Sell...")
    _G.AUTO_SELL_ENABLED = true

    -- Start the auto sell loop
    if not isAutoSellRunning then
        task.spawn(runAutoSellLoop)
    end

    print(string.format("✅ Auto Sell ENABLED (Delay: %ds)\n", _G.AUTO_SELL_DELAY))
end

local function stopAutoSell()
    if not _G.AUTO_SELL_ENABLED then
        print("⚠️ Auto Sell already stopped!")
        return
    end

    print("\n🛑 Stopping Auto Sell...")
    _G.AUTO_SELL_ENABLED = false

    print("✅ Auto Sell stopped successfully\n")
end

print("✅ Auto sell module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2.7: AUTO ELEMENT MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Auto Element Module - Automatic element collection

    Key Functions:
    - startAutoElement() - Start auto element system
    - stopAutoElement() - Stop auto element system
    - runAutoElementLoop() - Main element collection loop
]]

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: State Variables
-- ─────────────────────────────────────────────────────────────────────────

local isAutoElementRunning = false

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: Location Configuration
-- ─────────────────────────────────────────────────────────────────────────

local ELEMENT_LOCATIONS = {
    ["Ancient Jungle"] = CFrame.new(1490.12305, 6.62499952, -850.539307, -0.982308805, -4.67861128e-09, -0.187268242, -7.57854224e-09, 1, 1.47694985e-08, 0.187268242, 1.59274283e-08, -0.982308805),
    ["Sacred Temple"] = CFrame.new(1466.92151, -21.8750591, -622.835693, -0.764787138, 8.14444334e-09, 0.644283056, 2.31097452e-08, 1, 1.4791004e-08, -0.644283056, 2.6201187e-08, -0.764787138)
}

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: Element Tracker Functions
-- ─────────────────────────────────────────────────────────────────────────

local function getElementTrackerLabels()
    local success, result = pcall(function()
        local menuRings = workspace:FindFirstChild("!!! MENU RINGS")
        if not menuRings then return nil end

        local elementTracker = menuRings:FindFirstChild("Element Tracker")
        if not elementTracker then return nil end

        local board = elementTracker:FindFirstChild("Board")
        if not board then return nil end

        local gui = board:FindFirstChild("Gui")
        if not gui then return nil end

        local content = gui:FindFirstChild("Content")
        if not content then return nil end

        -- Read Label1 to Label4
        local labels = {}
        for i = 1, 4 do
            local label = content:FindFirstChild("Label" .. i)
            if label and label.Text then
                labels[i] = label.Text
            else
                labels[i] = ""
            end
        end

        return labels
    end)

    if success and result then
        return result
    else
        return nil
    end
end

local function getElementTrackerStatus()
    local labels = getElementTrackerLabels()

    if not labels then
        return "❌ Error reading tracker"
    end

    local statusText = ""
    for i = 1, 4 do
        if labels[i] and labels[i] ~= "" then
            statusText = statusText .. labels[i]
            if i < 4 then statusText = statusText .. "\n" end
        else
            statusText = statusText .. "Label" .. i .. ": N/A"
            if i < 4 then statusText = statusText .. "\n" end
        end
    end

    return statusText
end

-- Parse quest text to extract location and progress
local function parseQuestText(questText)
    if not questText or questText == "" then
        return nil, nil
    end

    -- Debug: Print raw quest text
    print(string.format("[Debug] Raw quest text: '%s'", questText))

    -- Extract location (e.g., "Ancient Jungle", "Sacred Temple")
    -- Pattern matches: "at [location name] - [percentage]"
    local location = questText:match("at%s+([^%-]+)%s*%-")

    if location then
        -- Trim whitespace
        location = location:match("^%s*(.-)%s*$")
    end

    -- Extract progress percentage (e.g., "0%", "50%", "100%")
    local progress = questText:match("(%d+)%%")

    -- Debug output
    print(string.format("[Debug] Extracted -> Location: '%s', Progress: %s%%",
        location or "nil",
        progress or "nil"))

    return location, tonumber(progress)
end

-- Quest completion tracker (to handle Label2 -> Label3 priority)
local completedQuests = {
    Label2 = false,  -- Track if Label2 was completed
    Label3 = false   -- Track if Label3 was completed
}

-- Check if quest is incomplete (0%)
local function isQuestIncomplete(questText)
    local location, progress = parseQuestText(questText)
    return location ~= nil and progress == 0
end

-- Get target location for incomplete quest
local function getTargetLocation()
    local labels = getElementTrackerLabels()

    if not labels then
        print("[Auto Element] ❌ Failed to get tracker labels")
        return nil, nil
    end

    print(string.rep("-", 70))
    print("[Auto Element] 🔍 Checking quests for incomplete (0%) status...")

    local label2Location, label2Progress = nil, nil
    local label3Location, label3Progress = nil, nil

    -- Check Label2 (index 2)
    if labels[2] and labels[2] ~= "" then
        print(string.format("[Auto Element] Checking Label2: '%s'", labels[2]))
        label2Location, label2Progress = parseQuestText(labels[2])

        if label2Location and label2Progress ~= nil then
            print(string.format("[Auto Element] Label2 -> Location: '%s', Progress: %d%%", label2Location, label2Progress))

            -- Detect completion: progress went from 0% to >0%
            if label2Progress > 0 and not completedQuests.Label2 then
                completedQuests.Label2 = true
                print(string.format("[Auto Element] ✅ Label2 marked as COMPLETED (%d%%)", label2Progress))
            end

            -- Reset completion flag if quest resets back to 0% (new quest)
            if label2Progress == 0 and completedQuests.Label2 then
                completedQuests.Label2 = false
                print(string.format("[Auto Element] 🔄 Label2 reset to 0%% - marked as NEW QUEST"))
            end
        else
            print("[Auto Element] ⚠️ Label2 parse failed or no location found")
        end
    else
        print("[Auto Element] ⚠️ Label2 is empty or not found")
    end

    -- Check Label3 (index 3)
    if labels[3] and labels[3] ~= "" then
        print(string.format("[Auto Element] Checking Label3: '%s'", labels[3]))
        label3Location, label3Progress = parseQuestText(labels[3])

        if label3Location and label3Progress ~= nil then
            print(string.format("[Auto Element] Label3 -> Location: '%s', Progress: %d%%", label3Location, label3Progress))

            -- Detect completion: progress went from 0% to >0%
            if label3Progress > 0 and not completedQuests.Label3 then
                completedQuests.Label3 = true
                print(string.format("[Auto Element] ✅ Label3 marked as COMPLETED (%d%%)", label3Progress))
            end

            -- Reset completion flag if quest resets back to 0% (new quest)
            if label3Progress == 0 and completedQuests.Label3 then
                completedQuests.Label3 = false
                print(string.format("[Auto Element] 🔄 Label3 reset to 0%% - marked as NEW QUEST"))
            end
        else
            print("[Auto Element] ⚠️ Label3 parse failed or no location found")
        end
    else
        print("[Auto Element] ⚠️ Label3 is empty or not found")
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- PRIORITY SYSTEM: Label2 first, then Label3 (skip if already completed)
    -- ═══════════════════════════════════════════════════════════════════════

    -- Priority 1: Label2 at 0% and NOT completed yet
    if label2Location and label2Progress == 0 and not completedQuests.Label2 then
        print(string.format("[Auto Element] 🎯 PRIORITY 1: Label2 at 0%% (not completed) -> %s", label2Location))
        print(string.rep("-", 70))
        return label2Location, "Label2"
    end

    -- Priority 2: Label3 at 0% and NOT completed yet (Label2 either completed or not at 0%)
    if label3Location and label3Progress == 0 and not completedQuests.Label3 then
        if completedQuests.Label2 then
            print(string.format("[Auto Element] 🎯 PRIORITY 2: Label3 at 0%% (Label2 already completed) -> %s", label3Location))
        else
            print(string.format("[Auto Element] 🎯 PRIORITY 2: Label3 at 0%% (Label2 not at 0%%) -> %s", label3Location))
        end
        print(string.rep("-", 70))
        return label3Location, "Label3"
    end

    -- No quest available
    if label2Location and label2Progress == 0 and completedQuests.Label2 then
        print(string.format("[Auto Element] ⏭️ Label2 at 0%% but already completed, skipping"))
    end

    if label3Location and label3Progress == 0 and completedQuests.Label3 then
        print(string.format("[Auto Element] ⏭️ Label3 at 0%% but already completed, skipping"))
    end

    print("[Auto Element] ℹ️ No incomplete quests found (all completed or in progress)")
    print(string.rep("-", 70))
    return nil, nil
end

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: Auto Farm (Element Tab) - REMOVED
-- ─────────────────────────────────────────────────────────────────────────
--[[
    NOTICE: The "Auto Farm (Element Tab)" feature has been REMOVED.

    This feature included:
    - Back-to-back teleport farming system
    - Position freeze with anti-drown protection
    - Element quest location detection

    Reason for removal: Simplified version focuses only on main Auto Farm tab.
    If you need element farming, use auto_farm_v5.lua or v5.1 instead.
]]

print("ℹ️ Element Farm feature removed (use main Auto Farm tab only)\n")

--[[
    All Element Farm functions have been removed from this file.
    This includes:
    - freezeElementPosition()
    - unfreezeElementPosition()
    - jumpCharacter()
    - setupDeathDetection()
    - runElementFarmLoop()
    - startElementFarm()
    - stopElementFarm()

    Use auto_farm_v5.lua or v5.1 if you need element farming capability.
]]

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO WEATHER: Weather Purchase Functions
-- ─────────────────────────────────────────────────────────────────────────

_G.WEATHER_LOOP_RUNNING = false

-- Weather types to purchase
local WEATHER_TYPES = {"Wind", "Cloudy", "Storm"}

-- Purchase single weather
local function purchaseWeather(weatherType)
    local success, result = pcall(function()
        local Event = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseWeatherEvent"]
        return Event:InvokeServer(weatherType)
    end)

    if success then
        print(string.format("[Auto Weather] ✅ Purchased: %s", weatherType))
        return true
    else
        warn(string.format("[Auto Weather] ❌ Failed to purchase: %s", weatherType))
        return false
    end
end

-- Purchase all weather types (Wind, Cloudy, Storm)
local function purchaseAllWeathers()
    print(string.rep("-", 70))
    print("[Auto Weather] 🌤️ Purchasing all weather types...")

    local successCount = 0
    local failCount = 0

    for i, weatherType in ipairs(WEATHER_TYPES) do
        local success = purchaseWeather(weatherType)

        if success then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end

        -- 10ms delay between each purchase
        if i < #WEATHER_TYPES then
            task.wait(0.01)
        end
    end

    print(string.format("[Auto Weather] 📊 Batch complete: %d success, %d failed", successCount, failCount))
    print(string.rep("-", 70))

    return successCount, failCount
end

-- Auto weather loop
local function runAutoWeatherLoop()
    if _G.WEATHER_LOOP_RUNNING then
        print("⚠️ Auto Weather loop already running!")
        return
    end

    _G.WEATHER_LOOP_RUNNING = true

    print(string.rep("=", 70))
    print("🌤️ AUTO WEATHER - STARTING")
    print(string.rep("=", 70) .. "\n")

    local cycleCount = 0
    local totalSuccess = 0
    local totalFailed = 0

    while _G.WEATHER_LOOP_RUNNING do
        -- Wait for auto weather to be enabled
        while not _G.AUTO_WEATHER_ENABLED and _G.WEATHER_LOOP_RUNNING do
            task.wait(0.5)
        end

        if not _G.WEATHER_LOOP_RUNNING then break end
        if not _G.AUTO_WEATHER_ENABLED then continue end

        cycleCount = cycleCount + 1

        print(string.format("\n[Auto Weather #%d] 🌤️ Starting weather purchase cycle...", cycleCount))

        -- Purchase all weathers
        local success, failed = purchaseAllWeathers()
        totalSuccess = totalSuccess + success
        totalFailed = totalFailed + failed

        -- Stats every 5 cycles
        if cycleCount % 5 == 0 then
            print(string.rep("=", 70))
            print(string.format("📊 [AUTO WEATHER STATS]"))
            print(string.format("   Cycles: %d", cycleCount))
            print(string.format("   Total Purchases: %d", totalSuccess))
            print(string.format("   Total Failed: %d", totalFailed))
            print(string.format("   Delay: %ds", _G.WEATHER_PURCHASE_DELAY))
            print(string.format("   Status: %s", _G.AUTO_WEATHER_ENABLED and "🟢 ON" or "🔴 OFF"))
            print(string.rep("=", 70) .. "\n")
        end

        -- Wait before next cycle
        print(string.format("[Auto Weather #%d] ⏳ Waiting %ds before next purchase...\n", cycleCount, _G.WEATHER_PURCHASE_DELAY))
        task.wait(_G.WEATHER_PURCHASE_DELAY)
    end

    -- Cleanup
    print("\n" .. string.rep("=", 70))
    print("🛑 AUTO WEATHER STOPPED")
    print(string.rep("=", 70))
    if cycleCount > 0 then
        print(string.format("\n📊 FINAL: %d cycles | %d purchases | %d failed\n", cycleCount, totalSuccess, totalFailed))
    end

    _G.WEATHER_LOOP_RUNNING = false
end

-- Start auto weather
local function startAutoWeather()
    if _G.AUTO_WEATHER_ENABLED then
        print("⚠️ Auto Weather already enabled!")
        return
    end

    print("\n🌤️ Starting Auto Weather...")
    _G.AUTO_WEATHER_ENABLED = true

    if not _G.WEATHER_LOOP_RUNNING then
        task.spawn(runAutoWeatherLoop)
    end

    print("✅ Auto Weather ENABLED\n")
end

-- Stop auto weather
local function stopAutoWeather()
    if not _G.AUTO_WEATHER_ENABLED then
        print("⚠️ Auto Weather already stopped!")
        return
    end

    print("\n🛑 Stopping Auto Weather...")
    _G.AUTO_WEATHER_ENABLED = false

    print("✅ Auto Weather stopped successfully\n")
end

print("✅ Auto weather module ready\n")

-- ─────────────────────────────────────────────────────────────────────────
-- TELEPORT: Location Database & Functions
-- ─────────────────────────────────────────────────────────────────────────

-- Teleport locations (dapat ditambahkan lebih banyak di sini)
local TELEPORT_LOCATIONS = {
    ["Kohana Volcano"] = CFrame.new(-572.879456, 22.4521465, 148.355331, -0.995764792, -6.67705606e-08, 0.0919371247, -5.74611505e-08, 1, 1.03905414e-07, -0.0919371247, 9.81825394e-08, -0.995764792),
    ["Sisyphus Statue"] = CFrame.new(-3728.21606, -135.074417, -1012.12744, -0.977224171, 7.74980258e-09, -0.212209702, 1.566994e-08, 1, -3.5640408e-08, 0.212209702, -3.81539813e-08, -0.977224171),
    ["Coral Reefs"] = CFrame.new(-3114.78198, 1.32066584, 2237.52295, -0.304758579, 1.6556676e-08, -0.952429652, -8.50574935e-08, 1, 4.46003305e-08, 0.952429652, 9.46036067e-08, -0.304758579),
    ["Esoteric Depths"] = CFrame.new(3248.37109, -1301.53027, 1403.82727, -0.920208454, 7.76270355e-08, 0.391428679, 4.56261056e-08, 1, -9.10549289e-08, -0.391428679, -6.5930152e-08, -0.920208454),
    ["Crater Island"] = CFrame.new(1016.49072, 20.0919304, 5069.27295, 0.838976264, 3.30379857e-09, -0.544168055, 2.63538391e-09, 1, 1.01344115e-08, 0.544168055, -9.93662219e-09, 0.838976264),
    ["Spawn"] = CFrame.new(45.2788086, 252.562927, 2987.10913, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    ["Lost Isle"] = CFrame.new(-3618.15698, 240.836655, -1317.45801, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    ["Weather Machine"] = CFrame.new(-1488.51196, 83.1732635, 1876.30298, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    ["Tropical Grove"] = CFrame.new(-2095.34106, 197.199997, 3718.08008),
    ["Mount Hallow"] = CFrame.new(2136.62305, 78.9163895, 3272.50439, -0.977613986, -1.77645827e-08, 0.210406482, -2.42338203e-08, 1, -2.81680421e-08, -0.210406482, -3.26364251e-08, -0.977613986),
    ["Treasure Room"] = CFrame.new(-3606.34985, -266.57373, -1580.97339, 0.998743415, 1.12141152e-13, -0.0501160324, -1.56847693e-13, 1, -8.88127842e-13, 0.0501160324, 8.94872392e-13, 0.998743415),
    ["Kohana"] = CFrame.new(-663.904236, 3.04580712, 718.796875, -0.100799225, -2.14183729e-08, -0.994906783, -1.12300391e-08, 1, -2.03902459e-08, 0.994906783, 9.11752096e-09, -0.100799225),
    ["Underground Cellar"] = CFrame.new(2109.52148, -94.1875076, -708.609131, 0.418592364, 3.34794485e-08, -0.908174217, -5.24141512e-08, 1, 1.27060247e-08, 0.908174217, 4.22825366e-08, 0.418592364),
    ["Ancient Jungle"] = CFrame.new(1490.12305, 6.62499952, -850.539307, -0.982308805, -4.67861128e-09, -0.187268242, -7.57854224e-09, 1, 1.47694985e-08, 0.187268242, 1.59274283e-08, -0.982308805),
    ["Sacred Temple"] = CFrame.new(1466.92151, -21.8750591, -622.835693, -0.764787138, 8.14444334e-09, 0.644283056, 2.31097452e-08, 1, 1.4791004e-08, -0.644283056, 2.6201187e-08, -0.764787138),
}

-- Teleport to location
local function teleportToLocation(locationName)
    local cframeData = TELEPORT_LOCATIONS[locationName]

    if not cframeData then
        warn(string.format("[Teleport] ❌ Location '%s' not found!", locationName))
        return false
    end

    local success = pcall(function()
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = cframeData
            print(string.format("[Teleport] ✅ Teleported to: %s", locationName))
        else
            warn("[Teleport] ❌ HumanoidRootPart not found!")
        end
    end)

    if not success then
        warn(string.format("[Teleport] ❌ Failed to teleport to: %s", locationName))
        return false
    end

    return true
end

print("✅ Teleport module ready\n")

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: Teleport Functions
-- ─────────────────────────────────────────────────────────────────────────

-- Teleport 3x to ensure accurate positioning
local function tripleTeleport(cframeData, locationName)
    local teleportSuccess = 0
    local teleportFailed = 0

    print(string.format("[Auto Element] 🔄 Starting triple teleport to %s...", locationName))

    for i = 1, 3 do
        local success = pcall(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = cframeData
            end
        end)

        if success then
            teleportSuccess = teleportSuccess + 1
            print(string.format("[Auto Element] ✅ Teleport #%d/%d successful", i, 3))
        else
            teleportFailed = teleportFailed + 1
            warn(string.format("[Auto Element] ❌ Teleport #%d/%d failed", i, 3))
        end

        -- Wait between teleports (except after the last one)
        if i < 3 then
            task.wait(0.3) -- 300ms delay between each teleport
        end
    end

    -- Final result
    if teleportSuccess == 3 then
        print(string.format("[Auto Element] ✅ Triple teleport completed successfully! (3/3)"))
        return true
    elseif teleportSuccess > 0 then
        warn(string.format("[Auto Element] ⚠️ Partial teleport success (%d/3)", teleportSuccess))
        return true
    else
        warn(string.format("[Auto Element] ❌ All teleports failed (0/3)"))
        return false
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO ELEMENT: Main Functions
-- ─────────────────────────────────────────────────────────────────────────

local function runAutoElementLoop()
    if isAutoElementRunning then
        print("⚠️ Auto Element loop already running!")
        return
    end

    isAutoElementRunning = true
    print(string.rep("=", 70))
    print("🔮 AUTO ELEMENT LOOP - STARTING")
    print(string.rep("=", 70) .. "\n")

    local cycleCount = 0
    local teleportCount = 0
    local currentQuestLocation = nil  -- Track current quest location
    local hasTeleported = false       -- Track if we've already teleported for current quest
    local currentLabelSource = nil    -- Track which label (Label2 or Label3)

    while isAutoElementRunning and _G.AUTO_ELEMENT_ENABLED do
        cycleCount = cycleCount + 1

        print(string.format("\n[Auto Element #%d] 🔮 Checking quest status...", cycleCount))

        -- Get target location from tracker
        local targetLocation, labelSource = getTargetLocation()

        if targetLocation then
            -- Check if this is a NEW quest (different from current one)
            local isNewQuest = (targetLocation ~= currentQuestLocation) or (labelSource ~= currentLabelSource)

            if isNewQuest then
                -- Reset teleport flag for new quest
                hasTeleported = false
                currentQuestLocation = targetLocation
                currentLabelSource = labelSource
                print(string.format("[Auto Element] 🆕 NEW QUEST DETECTED: %s (from %s)", targetLocation, labelSource))
            end

            -- Only teleport if we haven't teleported for this quest yet
            if not hasTeleported then
                local cframeData = ELEMENT_LOCATIONS[targetLocation]

                if cframeData then
                    print(string.rep("=", 70))
                    print(string.format("[Auto Element] 📍 TARGET: %s (from %s)", targetLocation, labelSource))
                    print(string.format("[Auto Element] 🚀 Preparing triple teleport in 3 seconds...", targetLocation))
                    task.wait(3) -- 3 second cooldown before teleport

                    -- Execute triple teleport for accuracy
                    local success = tripleTeleport(cframeData, targetLocation)

                    if success then
                        teleportCount = teleportCount + 1
                        hasTeleported = true  -- Mark as teleported
                        print(string.format("[Auto Element] ✅ Teleport complete! Now tracking quest progress..."))
                        print(string.format("[Auto Element] 📊 Total teleport cycles: %d", teleportCount))
                        print(string.rep("=", 70) .. "\n")
                    else
                        warn(string.format("[Auto Element] ❌ Triple teleport failed, will retry next cycle"))
                    end
                else
                    warn(string.rep("=", 70))
                    warn(string.format("[Auto Element] ⚠️ Location '%s' not found in config!", targetLocation))

                    -- List available locations
                    local availableLocations = {}
                    for locName, _ in pairs(ELEMENT_LOCATIONS) do
                        table.insert(availableLocations, locName)
                    end
                    warn(string.format("[Auto Element] Available locations: %s", table.concat(availableLocations, ", ")))
                    warn(string.rep("=", 70))
                end
            else
                -- Already teleported, just track progress
                print(string.format("[Auto Element] 📍 Current quest: %s (from %s)", targetLocation, labelSource))
                print(string.format("[Auto Element] ⏳ Waiting for quest completion (0%% → 100%%)..."))
            end
        else
            -- No quest at 0% found
            if hasTeleported and currentQuestLocation then
                -- Previous quest completed!
                print(string.rep("=", 70))
                print(string.format("[Auto Element] ✅ QUEST COMPLETED: %s", currentQuestLocation))
                print(string.format("[Auto Element] 🎉 Quest finished! Ready for next quest..."))
                print(string.rep("=", 70) .. "\n")
            else
                print("[Auto Element] ℹ️ No incomplete quests found (Label2 & Label3 not at 0%)")
            end

            -- Reset tracking
            currentQuestLocation = nil
            currentLabelSource = nil
            hasTeleported = false
        end

        -- Wait 30 seconds before next check
        print(string.format("[Auto Element] ⏳ Next check in 30 seconds...\n"))
        task.wait(30)

        -- Stats every 5 cycles
        if cycleCount % 5 == 0 then
            print(string.rep("=", 70))
            print(string.format("📊 [AUTO ELEMENT STATS]"))
            print(string.format("   Cycles: %d", cycleCount))
            print(string.format("   Total Teleports: %d", teleportCount))
            print(string.format("   Current Quest: %s", currentQuestLocation or "None"))
            print(string.format("   Quest Source: %s", currentLabelSource or "None"))
            print(string.format("   Teleported: %s", hasTeleported and "Yes" or "No"))
            print(string.format("   Status: %s", _G.AUTO_ELEMENT_ENABLED and "🟢 ON" or "🔴 OFF"))
            print(string.rep("=", 70) .. "\n")
        end
    end

    -- Cleanup
    print("\n" .. string.rep("=", 70))
    print("🛑 AUTO ELEMENT LOOP STOPPED")
    print(string.rep("=", 70))
    if cycleCount > 0 then
        print(string.format("\n📊 FINAL STATS: %d cycles | %d teleports\n", cycleCount, teleportCount))
    end

    isAutoElementRunning = false
end

local function startAutoElement()
    if _G.AUTO_ELEMENT_ENABLED then
        print("⚠️ Auto Element already enabled!")
        return
    end

    print("\n🔮 Starting Auto Element...")
    _G.AUTO_ELEMENT_ENABLED = true

    -- Start the auto element loop
    if not isAutoElementRunning then
        task.spawn(runAutoElementLoop)
    end

    print("✅ Auto Element ENABLED\n")
end

local function stopAutoElement()
    if not _G.AUTO_ELEMENT_ENABLED then
        print("⚠️ Auto Element already stopped!")
        return
    end

    print("\n🛑 Stopping Auto Element...")
    _G.AUTO_ELEMENT_ENABLED = false

    print("✅ Auto Element stopped successfully\n")
end

print("✅ Auto element module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: INVENTORY MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Inventory Module - Fish & Items detection system

    EDIT START: Line below this marker
    EDIT END: Before next section marker

    Key Functions:
    - detectFish() - Detect fish from inventory
    - detectItems() - Detect items from inventory
    - formatPrice() - Format price with commas
]]

-- ─────────────────────────────────────────────────────────────────────────
-- INVENTORY: Helper Functions
-- ─────────────────────────────────────────────────────────────────────────

local function trim(s)
    if not s then return nil end
    return s:match("^%s*(.-)%s*$")
end

local function formatPrice(price)
    if not price or price == 0 then return "0" end
    local formatted = tostring(math.floor(price))
    formatted = formatted:reverse():gsub("(%d%d%d)", "%1,")
    formatted = formatted:reverse():gsub("^,", "")
    return formatted
end

-- ─────────────────────────────────────────────────────────────────────────
-- INVENTORY: Detection System
-- ─────────────────────────────────────────────────────────────────────────

local detectedFish = {}
local detectedItems = {}
local currentCategory = "Fishes" -- "Fishes" or "Items"
local isDetecting = false

-- Grouping System State
local isGroupingEnabled = false  -- Start with list view (backward compatibility)
local expandedGroups = {}        -- Track which groups are expanded: {[baseName] = true/false}
local currentDisplayedCategory = nil  -- Track currently displayed category: "Fishes" or "Items"

local function detectInventory(category)
    local detected = {}
    isDetecting = true

    print(string.format("[Inventory] Starting %s detection...", category))

    if not PlayerData then
        warn("[Inventory] PlayerData not available")
        isDetecting = false
        return detected
    end

    local success, inventory = pcall(function()
        return PlayerData:Get("Inventory")
    end)

    if not success or not inventory then
        warn("[Inventory] Failed to get inventory")
        isDetecting = false
        return detected
    end

    local itemsCategory = inventory["Items"]
    if not itemsCategory or type(itemsCategory) ~= "table" then
        warn("[Inventory] Items category not found")
        isDetecting = false
        return detected
    end

    print(string.format("[Inventory] Found %d total items", #itemsCategory))

    local itemCount = 0
    for i, item in ipairs(itemsCategory) do
        local itemData = ItemUtility:GetItemData(item.Id)
        if itemData and itemData.Data then
            local itemType = itemData.Data.Type
            local itemName = trim(itemData.Data.Name)
            local itemUUID = item.UUID

            local shouldInclude = false
            if category == "Fishes" and itemType == "Fish" then
                shouldInclude = true
            elseif category == "Items" and itemType ~= "Fish" then
                shouldInclude = true
            end

            if shouldInclude then
                local mutation = nil
                local originalName = itemName

                -- Detect Big mutation
                if string.find(itemName, "^Big ") then
                    mutation = "Big"
                    itemName = trim(string.gsub(itemName, "^Big ", ""))
                -- Detect Shiny mutation
                elseif string.find(itemName, "^Shiny ") then
                    mutation = "Shiny"
                    itemName = trim(string.gsub(itemName, "^Shiny ", ""))
                end

                -- Detect variant mutations
                if not mutation and item.Metadata and item.Metadata.VariantId then
                    local variantData = ItemUtility:GetVariantData(item.Metadata.VariantId)
                    if variantData and variantData.Data.Name and variantData.Data.Name ~= "Ghoulish" then
                        mutation = variantData.Data.Name
                    end
                end

                local itemPrice = VendorUtility:GetSellPrice(item) or 0
                local basePrice = itemData.SellPrice or 0

                table.insert(detected, {
                    index = itemCount + 1,
                    name = itemName,
                    originalName = originalName,
                    mutation = mutation,
                    uuid = itemUUID,
                    category = category,
                    itemType = itemType,
                    price = itemPrice,
                    basePrice = basePrice
                })
                itemCount = itemCount + 1
            end
        end
    end

    print(string.format("[Inventory] Detected %d %s", itemCount, category))
    isDetecting = false
    return detected
end

local function detectFish()
    detectedFish = detectInventory("Fishes")
    return detectedFish
end

local function detectItems()
    detectedItems = detectInventory("Items")
    return detectedItems
end

-- ─────────────────────────────────────────────────────────────────────────
-- INVENTORY: Grouping System
-- ─────────────────────────────────────────────────────────────────────────

local function groupInventoryItems(items)
    local groups = {}
    local groupOrder = {}

    for i, item in ipairs(items) do
        local baseName = item.name  -- Base name for grouping

        -- Create new group if doesn't exist
        if not groups[baseName] then
            groups[baseName] = {
                baseName = baseName,
                items = {},
                totalCount = 0,
                totalValue = 0,
                avgPrice = 0,
                maxPrice = 0,
                minPrice = 999999999,
                isExpanded = expandedGroups[baseName] or false
            }
            table.insert(groupOrder, baseName)
        end

        -- Preserve original index
        local itemWithIndex = {}
        for k, v in pairs(item) do
            itemWithIndex[k] = v
        end
        itemWithIndex.originalIndex = i

        -- Add item to group
        table.insert(groups[baseName].items, itemWithIndex)
        groups[baseName].totalCount = groups[baseName].totalCount + 1

        -- Update statistics
        local itemPrice = item.price or 0
        groups[baseName].totalValue = groups[baseName].totalValue + itemPrice

        if itemPrice > groups[baseName].maxPrice then
            groups[baseName].maxPrice = itemPrice
        end

        if itemPrice < groups[baseName].minPrice then
            groups[baseName].minPrice = itemPrice
        end
    end

    -- Calculate averages
    for _, group in pairs(groups) do
        if group.totalCount > 0 then
            group.avgPrice = math.floor(group.totalValue / group.totalCount)
        end
    end

    return groups, groupOrder
end

print("✅ Inventory module ready\n")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: UI MODULE
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    UI Module - WindUI interface

    EDIT START: Line below this marker
    EDIT END: Before next section marker

    Tabs:
    - Auto Farm: Toggle ON/OFF, Custom Delay
    - Inventory: Fish/Items detection
]]

-- ─────────────────────────────────────────────────────────────────────────
-- UI: Load WindUI
-- ─────────────────────────────────────────────────────────────────────────

print("📦 Loading WindUI...")
local WindUI
local uiSuccess, uiError = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not uiSuccess then
    warn("❌ Failed to load WindUI: " .. tostring(uiError))
    warn("⚠️ Running without UI - Auto Farm enabled by default")
    _G.AUTO_FARM_ENABLED = true
    task.spawn(runMainLoop)
    return
end

print("✅ WindUI loaded successfully\n")

-- ─────────────────────────────────────────────────────────────────────────
-- UI: Create Window
-- ─────────────────────────────────────────────────────────────────────────

local Window = WindUI:CreateWindow({
    Title = "Auto Fishing Hub v2",
    Author = "by Daryl",
    Folder = "AutoFishingHub",
    Icon = "fish",
    Size = UDim2.fromOffset(520, 500),
    Resizable = false,
    Theme = "Dark"
})

print("✅ Window created")

-- Set toggle keybind (RightShift to toggle window)
Window:SetToggleKey(Enum.KeyCode.RightShift)
print("✅ Toggle keybind set: RightShift")

-- Define restore button functions first (before callbacks)
-- Will be defined below in the visibility control section

print("✅ Window created, waiting to register callbacks...")

-- ─────────────────────────────────────────────────────────────────────────
-- UI: Visibility Control System (Using Native WindUI Methods)
-- ─────────────────────────────────────────────────────────────────────────

local restoreButtonGui = nil

-- Function to create restore button with custom icon
local function createRestoreButton()
    print("[UI] 📍 [DEBUG] createRestoreButton() called")

    if restoreButtonGui then
        print("[UI] ⚠️ Restore button already exists, skipping")
        return
    end

    print("[UI] 🔨 Creating restore button with custom icon...")

    local success, err = pcall(function()
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        print("[UI] ✅ PlayerGui obtained")

        -- Create ScreenGui for restore button
        restoreButtonGui = Instance.new("ScreenGui")
        restoreButtonGui.Name = "RestoreUIButton"
        restoreButtonGui.ResetOnSpawn = false
        restoreButtonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        restoreButtonGui.DisplayOrder = 999999
        restoreButtonGui.Parent = playerGui
        print("[UI] ✅ ScreenGui created and parented")

    -- Create background frame
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "IconFrame"
    bgFrame.Size = UDim2.fromOffset(80, 80)
    bgFrame.Position = UDim2.new(0.5, -40, 0, 30)
    bgFrame.AnchorPoint = Vector2.new(0.5, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = restoreButtonGui
    print("[UI] ✅ Background frame created")

    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = bgFrame
    print("[UI] ✅ Corner radius added")

    -- Add border glow
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 150, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = bgFrame
    print("[UI] ✅ Border stroke added")

    -- Create ImageLabel for your custom icon
    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "CustomIcon"
    iconImage.Size = UDim2.fromScale(0.8, 0.8)
    iconImage.Position = UDim2.fromScale(0.5, 0.5)
    iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit  -- Fixed: ScaleType not ImageScaleType
    iconImage.Parent = bgFrame
    print("[UI] ✅ ImageLabel created")

    -- Try loading icon from local file with auto-download from GitHub
    local iconLoaded = false
    local iconPath = "WindUI/AutoFishingHub/assets/icon.PNG"
    local githubIconUrl = "https://raw.githubusercontent.com/DarylLoudi/njs/main/icon.PNG"

    print("[UI] 🔍 Checking for icon file...")

    -- Function to download icon from GitHub
    local function downloadIconFromGitHub()
        print("[UI] 📥 Downloading icon from GitHub...")
        print("[UI] 🔗 URL:", githubIconUrl)

        local success, iconData = pcall(function()
            local httpService = game:GetService("HttpService")

            -- Try different HTTP methods based on executor
            if syn and syn.request then
                print("[UI] 🌐 Using syn.request")
                local response = syn.request({
                    Url = githubIconUrl,
                    Method = "GET"
                })
                if response.StatusCode == 200 then
                    return response.Body
                end
            elseif http_request then
                print("[UI] 🌐 Using http_request")
                local response = http_request({
                    Url = githubIconUrl,
                    Method = "GET"
                })
                if response.StatusCode == 200 then
                    return response.Body
                end
            elseif request then
                print("[UI] 🌐 Using request")
                local response = request({
                    Url = githubIconUrl,
                    Method = "GET"
                })
                if response.StatusCode == 200 then
                    return response.Body
                end
            else
                print("[UI] 🌐 Using HttpService:GetAsync")
                return httpService:GetAsync(githubIconUrl)
            end
            return nil
        end)

        if success and iconData and #iconData > 0 then
            print("[UI] ✅ Icon downloaded successfully (" .. #iconData .. " bytes)")

            -- Create directories if they don't exist
            if makefolder then
                pcall(function()
                    makefolder("WindUI")
                    print("[UI] 📁 Created: WindUI/")
                end)
                pcall(function()
                    makefolder("WindUI/AutoFishingHub")
                    print("[UI] 📁 Created: WindUI/AutoFishingHub/")
                end)
                pcall(function()
                    makefolder("WindUI/AutoFishingHub/assets")
                    print("[UI] 📁 Created: WindUI/AutoFishingHub/assets/")
                end)
            end

            -- Save icon to file
            if writefile then
                local saveSuccess = pcall(function()
                    writefile(iconPath, iconData)
                    print("[UI] 💾 Icon saved to:", iconPath)
                end)

                if saveSuccess then
                    print("[UI] ✅ Icon file saved successfully")
                    return true
                else
                    print("[UI] ⚠️ Failed to save icon file")
                    return false
                end
            else
                print("[UI] ⚠️ writefile not available")
                return false
            end
        else
            print("[UI] ❌ Failed to download icon:", tostring(iconData))
            return false
        end
    end

    -- Check if icon file exists locally
    local fileExists = false
    if isfile then
        fileExists = isfile(iconPath)
        if fileExists then
            print("[UI] ✅ Icon file found locally at:", iconPath)
        else
            print("[UI] ℹ️ Icon file not found locally, will download from GitHub")
            -- Download icon from GitHub
            local downloaded = downloadIconFromGitHub()
            if downloaded then
                task.wait(0.2)  -- Wait for file to be written
                fileExists = true
            end
        end
    else
        print("[UI] ⚠️ isfile not available, cannot check for local icon")
    end

    -- Try to load icon using getcustomasset
    print("[UI] 🔍 Attempting to load icon with getcustomasset...")
    if getcustomasset then
        print("[UI] ✅ getcustomasset is available")
        local success, result = pcall(function()
            local assetUrl = getcustomasset(iconPath)
            print("[UI] 🔗 Asset URL:", assetUrl)
            iconImage.Image = assetUrl
            iconLoaded = true
            print("[UI] ✅ Icon loaded successfully from:", iconPath)
        end)

        if not success then
            print("[UI] ⚠️ getcustomasset failed:", result)
        end
    else
        print("[UI] ⚠️ getcustomasset NOT available")
    end

    -- Fallback to emoji if icon load failed
    if not iconLoaded then
        print("[UI] 📋 Using emoji fallback (icon not loaded)")
        iconImage:Destroy()

        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Size = UDim2.fromScale(1, 1)
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Text = "👁️"
        fallbackLabel.TextSize = 40
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        fallbackLabel.Font = Enum.Font.GothamBold
        fallbackLabel.Parent = bgFrame
        print("[UI] ✅ Fallback emoji created")
    end

    -- Create invisible button for clicking
    local clickButton = Instance.new("TextButton")
    clickButton.Name = "ClickDetector"
    clickButton.Size = UDim2.fromScale(1, 1)
    clickButton.Position = UDim2.fromScale(0, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.ZIndex = 10
    clickButton.Parent = bgFrame
    print("[UI] ✅ Click button created")

    -- Click handler to restore UI using Window:Open()
    clickButton.MouseButton1Click:Connect(function()
        print("[UI] 🖱️ Restore button clicked!")

        -- Use native WindUI method to open window
        Window:Open()
        print("[UI] ✅ UI restored using Window:Open()")

        -- Destroy restore button
        if restoreButtonGui then
            restoreButtonGui:Destroy()
            restoreButtonGui = nil
            print("[UI] 🗑️ Restore button removed")
        end
    end)
    print("[UI] ✅ Click handler connected")

    -- Hover effects
    clickButton.MouseEnter:Connect(function()
        bgFrame.Size = UDim2.fromOffset(85, 85)
        stroke.Thickness = 3
        stroke.Transparency = 0
    end)

    clickButton.MouseLeave:Connect(function()
        bgFrame.Size = UDim2.fromOffset(80, 80)
        stroke.Thickness = 2
        stroke.Transparency = 0.3
    end)
    print("[UI] ✅ Hover effects connected")

        print("[UI] ✅ All UI elements created")
        print("[UI] 🎉 Restore button created at center-top!")
    end)

    if not success then
        warn("[UI] ❌ ERROR creating restore button: " .. tostring(err))
        restoreButtonGui = nil
    else
        print("[UI] 🎊 Restore button creation SUCCESS!")
    end
end

-- Function to destroy restore button
local function destroyRestoreButton()
    print("[UI] 🗑️ [DEBUG] destroyRestoreButton() called")

    if restoreButtonGui then
        print("[UI] 🔍 Restore button exists, destroying...")
        restoreButtonGui:Destroy()
        restoreButtonGui = nil
        print("[UI] ✅ Restore button removed successfully")
    else
        print("[UI] ℹ️ No restore button to remove")
    end
end

-- Global functions for UI visibility control (using native WindUI methods)
_G.ShowUI = function()
    print("[UI] 👁️ [CONSOLE] _G.ShowUI() called")
    Window:Open()
    destroyRestoreButton()
    print("[UI] ✅ UI shown using Window:Open()")
end

_G.HideUI = function()
    print("[UI] 🙈 [CONSOLE] _G.HideUI() called")
    Window:Close()
    createRestoreButton()
    print("[UI] ✅ UI hidden using Window:Close() - Click icon to restore")
end

_G.ToggleUI = function()
    print("[UI] 🔄 [CONSOLE] _G.ToggleUI() called")
    Window:Toggle()

    -- Check if window is now closed, if so create restore button
    task.wait(0.1)
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local windUI = playerGui:FindFirstChild("Wind")
    if windUI and not windUI.Enabled then
        createRestoreButton()
        print("[UI] ✅ UI toggled OFF - Icon shown")
    else
        destroyRestoreButton()
        print("[UI] ✅ UI toggled ON")
    end
end

-- Register Window event callbacks AFTER functions are defined
print("[UI] 📋 Registering Window event callbacks...")

Window:OnClose(function()
    print("[UI] 🔔 Window:OnClose() event triggered")
    print("[UI] 🔍 Calling createRestoreButton()...")

    task.spawn(function()
        task.wait(0.2)
        pcall(function()
            createRestoreButton()
            print("[UI] ✅ createRestoreButton() completed")
        end)
    end)
end)

Window:OnOpen(function()
    print("[UI] 🔔 Window:OnOpen() event triggered")
    print("[UI] 🔍 Calling destroyRestoreButton()...")

    pcall(function()
        destroyRestoreButton()
        print("[UI] ✅ destroyRestoreButton() completed")
    end)
end)

print("[UI] ✅ Window event callbacks registered successfully")

print("[UI] ===============================================")
print("[UI] 📌 Global Functions Available:")
print("[UI]    _G.ShowUI()    - Show the UI (Window:Open)")
print("[UI]    _G.HideUI()    - Hide UI and show icon (Window:Close)")
print("[UI]    _G.ToggleUI()  - Toggle UI visibility (Window:Toggle)")
print("[UI]")
print("[UI] 🧪 Test the restore button:")
print("[UI]    1. Go to Config tab")
print("[UI]    2. Toggle OFF 'Show/Hide UI'")
print("[UI]    3. Icon should appear at center-top")
print("[UI]    4. Click icon to restore")
print("[UI]    Or: Press RightShift to toggle")
print("[UI]    Or: Use test buttons in Config tab")
print("[UI] ===============================================")

-- ═══════════════════════════════════════════════════════════════════════════
-- LOAD SAVED CONFIG (BEFORE UI CREATION)
-- ═══════════════════════════════════════════════════════════════════════════
local savedConfig = loadConfig()

-- ─────────────────────────────────────────────────────────────────────────
-- UI: AUTO FARM TAB
-- ─────────────────────────────────────────────────────────────────────────

local FarmTab = Window:Tab({
    Title = "Auto Farm",
    Icon = "zap"
})

FarmTab:Section({
    Title = "⚙️ Farm Controls"
})


-- Stop function
local function stopAutoFarm()
    _G.AUTO_FARM_ENABLED = false

    task.spawn(function()
        pcall(function()
            CancelEvent:InvokeServer()
        end)
    end)
end

-- Start function
local function startAutoFarm()
    _G.AUTO_FARM_ENABLED = true

    startReelIntermissionLoop()

    if not _G.MAIN_LOOP_RUNNING then
        task.spawn(runMainLoop)
    end
end

-- Toggle
UIComponents.AutoFarmToggle = FarmTab:Toggle({
    Title = "Auto Farm",
    Desc = "Enable/disable automatic fishing",
    Type = "Toggle",
    Default = false,
    Flag = "AutoFarmEnabled",
    Callback = function(state)
        if state then
            startAutoFarm()
        else
            stopAutoFarm()
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Delay Input V1
UIComponents.SuccessDelayInput = FarmTab:Input({
    Title = "Success Delay",
    Desc = "Delay after successful fishing (seconds)",
    Type = "Input",
    Placeholder = "1",
    Value = savedConfig and savedConfig.FARM_SUCCESS_DELAY and tostring(savedConfig.FARM_SUCCESS_DELAY) or "1",
    InputIcon = "timer",
    Callback = function(value)
        local delay = tonumber(value)
        if delay and delay > 0 then
            _G.FARM_SUCCESS_DELAY = delay
            print(string.format("⏱️ Success delay: %.2fs", delay))
        else
            print("❌ Invalid delay! Using default: 1s")
            _G.FARM_SUCCESS_DELAY = 1
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 20 })

FarmTab:Divider()

FarmTab:Space({ Size = 15 })

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM TAB: Auto Farm V2 (Fast) Section
-- ─────────────────────────────────────────────────────────────────────────

FarmTab:Section({
    Title = "⚡ Auto Farm V2 (Fast)"
})

FarmTab:Paragraph({
    Title = "Jung V2 - Independent Loop",
    Desc = "Faster fishing with independent loop + server-based complete\nParallel execution, ping compensation, fixed OK rating"
})

FarmTab:Space({ Size = 10 })

-- Auto Farm V2 Toggle
UIComponents.AutoFarmV2Toggle = FarmTab:Toggle({
    Title = "Auto Farm V2 (Fast)",
    Desc = "Enable/disable Jung V2 fast auto farm",
    Type = "Toggle",
    Default = false,
    Flag = "AutoFarmV2Enabled",
    Callback = function(state)
        _G.AUTO_FARM_V2_ENABLED = state
        if state then
            startAutoFarmV2()
        else
            stopAutoFarmV2()
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Ping Compensation Toggle
UIComponents.PingCompensationToggle = FarmTab:Toggle({
    Title = "Auto Ping Compensation",
    Desc = "Automatically adjust delays based on ping",
    Type = "Toggle",
    Default = savedConfig and savedConfig.JUNG_V2_STATE and savedConfig.JUNG_V2_STATE.autoPingCompensation or true,
    Flag = "AutoPingCompensation",
    Callback = function(state)
        _G.JUNG_V2_STATE.autoPingCompensation = state
        if state then
            calculateCompensatedDelays()
            print("📶 Ping Compensation ENABLED")
            print(string.format("   Ping: %.0fms | Delays: %.2fs/%.2fs",
                _G.JUNG_V2_STATE.currentPing,
                _G.JUNG_V2_STATE.delayReel,
                _G.JUNG_V2_STATE.delayComplete))
        else
            print("📶 Ping Compensation DISABLED")
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Base Delay Reel Input
UIComponents.BaseDelayReelInput = FarmTab:Input({
    Title = "Base Delay Reel",
    Desc = "Base wait time before each cycle (seconds)",
    Type = "Input",
    Placeholder = "1.5",
    Value = savedConfig and savedConfig.JUNG_V2_STATE and savedConfig.JUNG_V2_STATE.delayReel and tostring(savedConfig.JUNG_V2_STATE.delayReel) or "1.5",
    InputIcon = "timer",
    Callback = function(value)
        local delay = tonumber(value)
        if delay and delay >= 0 then
            _G.JUNG_V2_STATE.baseDelayReel = delay
            _G.JUNG_V2_STATE.delayReel = delay
            print(string.format("⏱️ Base Delay Reel: %.2fs", delay))
            if _G.JUNG_V2_STATE.autoPingCompensation then
                calculateCompensatedDelays()
                print(string.format("   Auto-adjusted: %.2fs (ping: %.0fms)",
                    _G.JUNG_V2_STATE.delayReel,
                    _G.JUNG_V2_STATE.currentPing))
            end
        else
            print("❌ Invalid delay! Using default: 1.5s")
            _G.JUNG_V2_STATE.baseDelayReel = 1.5
            _G.JUNG_V2_STATE.delayReel = 1.5
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Base Delay Complete Input
UIComponents.BaseDelayCompleteInput = FarmTab:Input({
    Title = "Base Delay Complete",
    Desc = "Base wait time after server return (seconds)",
    Type = "Input",
    Placeholder = "0.7",
    Value = savedConfig and savedConfig.JUNG_V2_STATE and savedConfig.JUNG_V2_STATE.delayComplete and tostring(savedConfig.JUNG_V2_STATE.delayComplete) or "0.7",
    InputIcon = "clock",
    Callback = function(value)
        local delay = tonumber(value)
        if delay and delay >= 0 then
            _G.JUNG_V2_STATE.baseDelayComplete = delay
            _G.JUNG_V2_STATE.delayComplete = delay
            print(string.format("⏱️ Base Delay Complete: %.2fs", delay))
            if _G.JUNG_V2_STATE.autoPingCompensation then
                calculateCompensatedDelays()
                print(string.format("   Auto-adjusted: %.2fs (ping: %.0fms)",
                    _G.JUNG_V2_STATE.delayComplete,
                    _G.JUNG_V2_STATE.currentPing))
            end
        else
            print("❌ Invalid delay! Using default: 0.7s")
            _G.JUNG_V2_STATE.baseDelayComplete = 0.7
            _G.JUNG_V2_STATE.delayComplete = 0.7
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- V2 Stats Display
local v2StatsLabel = FarmTab:Paragraph({
    Title = "Auto Farm V2 Stats",
    Desc = "Fish: 0 | Cycles: 0 | Requests: 0 | Pending: 0 | Ping: 0ms\nDelays: 0.00s/0.00s | Runtime: 0s | Rate: 0.0/min"
})

-- Stats updater for V2
task.spawn(function()
    while true do
        task.wait(1)
        if _G.JUNG_V2_STATE.isRunning then
            local State = _G.JUNG_V2_STATE
            local runtime = tick() - State.startTime
            local fishPerMin = runtime > 0 and (State.fishCaught / runtime) * 60 or 0

            v2StatsLabel:SetDesc(string.format(
                "Fish: %d | Cycles: %d | Requests: %d | Pending: %d | Ping: %.0fms\nDelays: %.2fs/%.2fs | Runtime: %.0fs | Rate: %.1f/min",
                State.fishCaught,
                State.cycleCount,
                State.totalRequests,
                State.pendingCompletes,
                State.currentPing,
                State.delayReel,
                State.delayComplete,
                runtime,
                fishPerMin
            ))
        end
    end
end)

FarmTab:Space({ Size = 10 })

FarmTab:Paragraph({
    Title = "ℹ️ V2 Info",
    Desc = "Independent loop = doesn't wait for completion\nServer-based complete = parallel execution\nPing compensation = auto-adjust for high ping\nFixed params (-1, 0) = always OK rating"
})

FarmTab:Space({ Size = 20 })

FarmTab:Divider()

FarmTab:Space({ Size = 15 })

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM TAB: Auto Sell Section
-- ─────────────────────────────────────────────────────────────────────────

FarmTab:Section({
    Title = "💰 Auto Sell"
})

-- Auto Sell Toggle
UIComponents.AutoSellToggle = FarmTab:Toggle({
    Title = "Auto Sell",
    Desc = "Automatically sell all items periodically",
    Type = "Toggle",
    Default = false,
    Flag = "AutoSellEnabled",
    Callback = function(state)
        if state then
            startAutoSell()
        else
            stopAutoSell()
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Auto Sell Delay Input
UIComponents.SellDelayInput = FarmTab:Input({
    Title = "Sell Delay",
    Desc = "Delay between auto-sell cycles (seconds)",
    Type = "Input",
    Placeholder = "60",
    Value = savedConfig and savedConfig.AUTO_SELL_DELAY and tostring(savedConfig.AUTO_SELL_DELAY) or "60",
    InputIcon = "timer",
    Callback = function(value)
        local delay = tonumber(value)
        if delay and delay >= 10 then
            _G.AUTO_SELL_DELAY = delay
            print(string.format("💰 Auto Sell delay set to: %ds", delay))
        else
            print("❌ Invalid delay! Minimum 10 seconds. Using default: 60s")
            _G.AUTO_SELL_DELAY = 60
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 20 })

FarmTab:Divider()

FarmTab:Space({ Size = 15 })

-- ─────────────────────────────────────────────────────────────────────────
-- AUTO FARM TAB: Auto Artifact Section
-- ─────────────────────────────────────────────────────────────────────────

FarmTab:Section({
    Title = "🎯 Auto Artifact"
})

-- Auto Artifact Toggle
UIComponents.AutoArtifactToggle = FarmTab:Toggle({
    Title = "Auto Artifact",
    Desc = "Enable/disable automatic artifact collection",
    Type = "Toggle",
    Default = false,
    Flag = "AutoArtifactEnabled",
    Callback = function(state)
        if state then
            startAutoArtifact()
        else
            stopAutoArtifact()
        end
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

-- Artifact Skip Toggles Section
FarmTab:Section({
    Title = "🎯 Artifact Skip Settings"
})

FarmTab:Paragraph({
    Title = "Skip Artifacts",
    Desc = "Toggle ON to skip artifacts you already have"
})

FarmTab:Space({ Size = 5 })

-- Temple 1: Hourglass Diamond Artifact
UIComponents.SkipHourglassToggle = FarmTab:Toggle({
    Title = "⏭️ Skip Hourglass Diamond",
    Desc = "Temple 1 - Mark as already obtained",
    Type = "Toggle",
    Default = savedConfig and savedConfig.artifactSkipToggles and savedConfig.artifactSkipToggles[1] or false,
    Flag = "SkipHourglassDiamond",
    Callback = function(state)
        artifactSkipToggles[1] = state
        local status = state and "WILL SKIP" or "WILL FARM"
        print(string.format("[Skip Settings] Hourglass Diamond: %s", status))
        autoSaveConfig()
    end
})

-- Temple 2: Arrow Artifact
UIComponents.SkipArrowToggle = FarmTab:Toggle({
    Title = "⏭️ Skip Arrow Artifact",
    Desc = "Temple 2 - Mark as already obtained",
    Type = "Toggle",
    Default = savedConfig and savedConfig.artifactSkipToggles and savedConfig.artifactSkipToggles[2] or false,
    Flag = "SkipArrowArtifact",
    Callback = function(state)
        artifactSkipToggles[2] = state
        local status = state and "WILL SKIP" or "WILL FARM"
        print(string.format("[Skip Settings] Arrow Artifact: %s", status))
        autoSaveConfig()
    end
})

-- Temple 3: Diamond Artifact
UIComponents.SkipDiamondToggle = FarmTab:Toggle({
    Title = "⏭️ Skip Diamond Artifact",
    Desc = "Temple 3 - Mark as already obtained",
    Type = "Toggle",
    Default = savedConfig and savedConfig.artifactSkipToggles and savedConfig.artifactSkipToggles[3] or false,
    Flag = "SkipDiamondArtifact",
    Callback = function(state)
        artifactSkipToggles[3] = state
        local status = state and "WILL SKIP" or "WILL FARM"
        print(string.format("[Skip Settings] Diamond Artifact: %s", status))
        autoSaveConfig()
    end
})

-- Temple 4: Crescent Artifact
UIComponents.SkipCrescentToggle = FarmTab:Toggle({
    Title = "⏭️ Skip Crescent Artifact",
    Desc = "Temple 4 - Mark as already obtained",
    Type = "Toggle",
    Default = savedConfig and savedConfig.artifactSkipToggles and savedConfig.artifactSkipToggles[4] or false,
    Flag = "SkipCrescentArtifact",
    Callback = function(state)
        artifactSkipToggles[4] = state
        local status = state and "WILL SKIP" or "WILL FARM"
        print(string.format("[Skip Settings] Crescent Artifact: %s", status))
        autoSaveConfig()
    end
})

FarmTab:Space({ Size = 10 })

FarmTab:Divider()

FarmTab:Space({ Size = 15 })

-- Manual Teleport Section
FarmTab:Section({
    Title = "🗺️ Manual Temple Teleport"
})

FarmTab:Paragraph({
    Title = "Quick Teleport",
    Desc = "Teleport to temples manually without auto-farm"
})

FarmTab:Space({ Size = 5 })

-- Temple 1: Hourglass Diamond Artifact
FarmTab:Button({
    Title = "📍 Temple 1 - Hourglass Diamond",
    Desc = "Teleport to Temple 1 location",
    Callback = function()
        local success = pcall(function()
            local rootPart = player.Character.HumanoidRootPart
            rootPart.CFrame = CFrame.new(1490.12305, 6.62499952, -850.539307, -0.982308805, -4.67861128e-09, -0.187268242, -7.57854224e-09, 1, 1.47694985e-08, 0.187268242, 1.59274283e-08, -0.982308805)
            print("[Teleport] ✅ Teleported to Temple 1 (Hourglass Diamond)")
        end)
        if not success then
            warn("[Teleport] ❌ Failed to teleport to Temple 1")
        end
    end
})

-- Temple 2: Arrow Artifact
FarmTab:Button({
    Title = "📍 Temple 2 - Arrow Artifact",
    Desc = "Teleport to Temple 2 location",
    Callback = function()
        local success = pcall(function()
            local rootPart = player.Character.HumanoidRootPart
            rootPart.CFrame = CFrame.new(883.964233, 6.62499952, -360.91275, -0.128746182, 9.21072107e-09, 0.991677582, -4.92979968e-09, 1, -9.92803972e-09, -0.991677582, -6.16696871e-09, -0.128746182)
            print("[Teleport] ✅ Teleported to Temple 2 (Arrow Artifact)")
        end)
        if not success then
            warn("[Teleport] ❌ Failed to teleport to Temple 2")
        end
    end
})

-- Temple 3: Diamond Artifact
FarmTab:Button({
    Title = "📍 Temple 3 - Diamond Artifact",
    Desc = "Teleport to Temple 3 location",
    Callback = function()
        local success = pcall(function()
            local rootPart = player.Character.HumanoidRootPart
            rootPart.CFrame = CFrame.new(1836.77136, 6.62499952, -288.573303, 0.25269559, 7.76984699e-09, -0.967545807, 3.12285877e-08, 1, 1.61864921e-08, 0.967545807, -3.43053443e-08, 0.25269559)
            print("[Teleport] ✅ Teleported to Temple 3 (Diamond Artifact)")
        end)
        if not success then
            warn("[Teleport] ❌ Failed to teleport to Temple 3")
        end
    end
})

-- Temple 4: Crescent Artifact
FarmTab:Button({
    Title = "📍 Temple 4 - Crescent Artifact",
    Desc = "Teleport to Temple 4 location",
    Callback = function()
        local success = pcall(function()
            local rootPart = player.Character.HumanoidRootPart
            rootPart.CFrame = CFrame.new(1405.67358, 6.17587185, 119.126236, -0.951030135, -6.02376886e-08, 0.309098154, -8.03642095e-08, 1, -5.23817469e-08, -0.309098154, -7.4657045e-08, -0.951030135)
            print("[Teleport] ✅ Teleported to Temple 4 (Crescent Artifact)")
        end)
        if not success then
            warn("[Teleport] ❌ Failed to teleport to Temple 4")
        end
    end
})

print("✅ Auto Farm tab created")

-- ─────────────────────────────────────────────────────────────────────────
-- UI: INVENTORY TAB
-- ─────────────────────────────────────────────────────────────────────────

local InventoryTab = Window:Tab({
    Title = "Inventory",
    Icon = "package"
})

InventoryTab:Section({
    Title = "📦 Inventory Detection"
})

-- Detection status label
local detectionStatus = nil
local fishListLabels = {}
local itemListLabels = {}
local allInventoryUIComponents = {}  -- Track ALL created UI components

-- Helper function to clear list (IMPROVED)
local function clearList(listTable)
    for _, label in ipairs(listTable) do
        if label then
            pcall(function() label:Destroy() end)
        end
    end
    table.clear(listTable)
end

-- Clear ALL inventory UI components
local function clearAllInventoryUI()
    for _, component in ipairs(allInventoryUIComponents) do
        if component then
            pcall(function() component:Destroy() end)
        end
    end
    table.clear(allInventoryUIComponents)
    table.clear(fishListLabels)
    table.clear(itemListLabels)
end

-- Refresh Inventory Display (Main rendering function)
local function refreshInventoryDisplay(category)
    -- Clear previous UI
    clearAllInventoryUI()

    -- Get current items based on category
    local currentItems = (category == "Fishes") and detectedFish or detectedItems

    if #currentItems == 0 then
        local noItemsLabel = InventoryTab:Paragraph({
            Title = string.format("No %s detected yet", category:lower()),
            Desc = string.format("Click 'Detect %s' button to scan", category)
        })
        table.insert(allInventoryUIComponents, noItemsLabel)
        return
    end

    -- Calculate statistics
    local totalValue = 0
    local mutatedCount = 0
    for _, item in ipairs(currentItems) do
        totalValue = totalValue + (item.price or 0)
        if category == "Fishes" and item.mutation and item.mutation ~= "" then
            mutatedCount = mutatedCount + 1
        end
    end

    -- Update detection status
    local statusText
    if category == "Fishes" then
        statusText = string.format(
            "🐟 Fish: %d | 💎 Mutated: %d\n💰 Total Value: %s C$",
            #currentItems,
            mutatedCount,
            formatPrice(totalValue)
        )
    else
        statusText = string.format(
            "📦 Items: %d\n💰 Total Value: %s C$",
            #currentItems,
            formatPrice(totalValue)
        )
    end

    if detectionStatus then
        detectionStatus:SetDesc(statusText)
    end

    -- GROUPED VIEW
    if isGroupingEnabled then
        local groups, groupOrder = groupInventoryItems(currentItems)

        print(string.format("[Inventory] Rendering GROUPED view: %d groups", #groupOrder))

        for _, groupName in ipairs(groupOrder) do
            local group = groups[groupName]

            -- Group Header Button
            local expandIcon = group.isExpanded and "📂" or "📁"
            local headerTitle = string.format(
                "%s %s | Count: %d | Total: %s C$ | Avg: %s C$",
                expandIcon,
                groupName,
                group.totalCount,
                formatPrice(group.totalValue),
                formatPrice(group.avgPrice)
            )

            local groupHeader = InventoryTab:Button({
                Title = headerTitle,
                Desc = "Click to expand/collapse",
                Callback = function()
                    -- Toggle expand state
                    expandedGroups[groupName] = not expandedGroups[groupName]
                    refreshInventoryDisplay(category)
                end
            })
            table.insert(allInventoryUIComponents, groupHeader)

            -- Child Items (if expanded)
            if group.isExpanded then
                -- Sort items by price (highest first)
                table.sort(group.items, function(a, b) return (a.price or 0) > (b.price or 0) end)

                for idx, item in ipairs(group.items) do
                    local itemTitle = string.format(
                        "  → %s%s - %s C$",
                        item.originalName or item.name,
                        item.mutation and (" (" .. item.mutation .. ")") or "",
                        formatPrice(item.price)
                    )

                    local itemEntry = InventoryTab:Paragraph({
                        Title = itemTitle,
                        Desc = ""
                    })
                    table.insert(allInventoryUIComponents, itemEntry)

                    -- Limit display to prevent UI overflow
                    if idx >= 50 then
                        local moreLabel = InventoryTab:Paragraph({
                            Title = string.format("    ... and %d more items in this group", group.totalCount - 50),
                            Desc = ""
                        })
                        table.insert(allInventoryUIComponents, moreLabel)
                        break
                    end
                end
            end
        end

    -- LIST VIEW
    else
        print(string.format("[Inventory] Rendering LIST view: %d items", #currentItems))

        -- Sort by price (highest first)
        local sortedItems = {}
        for i, item in ipairs(currentItems) do
            local itemCopy = {}
            for k, v in pairs(item) do itemCopy[k] = v end
            itemCopy.originalIndex = i
            table.insert(sortedItems, itemCopy)
        end
        table.sort(sortedItems, function(a, b) return (a.price or 0) > (b.price or 0) end)

        -- Display items (limit to 50 to prevent UI overflow)
        local displayLimit = math.min(50, #sortedItems)
        for i = 1, displayLimit do
            local item = sortedItems[i]
            local itemTitle = string.format(
                "%d. %s%s - %s C$",
                i,
                item.originalName or item.name,
                item.mutation and (" (" .. item.mutation .. ")") or "",
                formatPrice(item.price)
            )

            local itemEntry = InventoryTab:Paragraph({
                Title = itemTitle,
                Desc = ""
            })
            table.insert(allInventoryUIComponents, itemEntry)
        end

        -- Show "more items" indicator
        if #sortedItems > 50 then
            local moreLabel = InventoryTab:Paragraph({
                Title = string.format("... and %d more items", #sortedItems - 50),
                Desc = ""
            })
            table.insert(allInventoryUIComponents, moreLabel)
        end
    end
end

-- Helper function to create fish/item entry (DEPRECATED - kept for backward compatibility)
local function createListEntry(tab, name, mutation, price, index)
    local displayText = string.format(
        "%d. %s%s - %s C$",
        index,
        name,
        mutation and (" (" .. mutation .. ")") or "",
        formatPrice(price)
    )

    return tab:Paragraph({
        Title = displayText,
        Desc = ""
    })
end

-- Grouping Toggle Button
InventoryTab:Button({
    Title = isGroupingEnabled and "📋 Switch to List View" or "📦 Switch to Group View",
    Desc = "Toggle between grouped and list display",
    Callback = function()
        isGroupingEnabled = not isGroupingEnabled
        print(string.format("[Inventory] Switched to %s view", isGroupingEnabled and "GROUPED" or "LIST"))

        -- Refresh display if items are already loaded
        if currentDisplayedCategory then
            refreshInventoryDisplay(currentDisplayedCategory)
        end
    end
})

InventoryTab:Space({ Size = 10 })

-- Detect Fish Button
InventoryTab:Button({
    Title = "🐟 Detect Fish",
    Desc = "Scan inventory for all fish",
    Callback = function()
        print("\n[Inventory] Starting fish detection...")

        -- Set status to loading
        if detectionStatus then
            detectionStatus:SetDesc("⏳ Detecting fish...")
        end

        -- Detect fish from inventory
        local fish = detectFish()
        print(string.format("[Inventory] ✅ Detected %d fish", #fish))

        -- Update current category and refresh display
        currentDisplayedCategory = "Fishes"
        refreshInventoryDisplay("Fishes")
    end
})

InventoryTab:Space({ Size = 5 })

-- Detect Items Button
InventoryTab:Button({
    Title = "📦 Detect Items",
    Desc = "Scan inventory for all items (non-fish)",
    Callback = function()
        print("\n[Inventory] Starting items detection...")

        -- Set status to loading
        if detectionStatus then
            detectionStatus:SetDesc("⏳ Detecting items...")
        end

        -- Detect items from inventory
        local items = detectItems()
        print(string.format("[Inventory] ✅ Detected %d items", #items))

        -- Update current category and refresh display
        currentDisplayedCategory = "Items"
        refreshInventoryDisplay("Items")
    end
})

InventoryTab:Space({ Size = 15 })

InventoryTab:Divider()

InventoryTab:Space({ Size = 10 })

-- Status Display
InventoryTab:Section({
    Title = "📊 Detection Status"
})

detectionStatus = InventoryTab:Paragraph({
    Title = "Status",
    Desc = "⚪ No detection run yet\nClick 'Detect Fish' or 'Detect Items' to start"
})

print("✅ Inventory tab created")

-- ─────────────────────────────────────────────────────────────────────────
-- UI: AUTO ELEMENT TAB
-- ─────────────────────────────────────────────────────────────────────────

local ElementTab = Window:Tab({
    Title = "Auto Element",
    Icon = "star"
})

ElementTab:Section({
    Title = "🔮 Element Controls"
})

-- Auto Element Toggle
UIComponents.AutoElementToggle = ElementTab:Toggle({
    Title = "Auto Element",
    Desc = "Enable/disable automatic element collection",
    Type = "Toggle",
    Default = false,
    Flag = "AutoElementEnabled",
    Callback = function(state)
        if state then
            startAutoElement()
        else
            stopAutoElement()
        end
        autoSaveConfig()
    end
})

ElementTab:Space({ Size = 20 })

ElementTab:Divider()

ElementTab:Space({ Size = 15 })

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTE: Auto Farm (Element Tab) has been REMOVED from this version
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    The simplified auto farming feature in Element tab has been removed.
    Use the main "Auto Farm" tab for all fishing automation.

    If you need element-specific farming, use auto_farm_v5.lua or v5.1 instead.
]]

ElementTab:Space({ Size = 15 })

ElementTab:Section({
    Title = "ℹ️ Element Tracker Info"
})

-- Element Tracker Status Paragraph
local elementTrackerStatus = ElementTab:Paragraph({
    Title = "📊 Quest Status",
    Desc = "⏳ Loading tracker data..."
})

-- Auto-update Element Tracker every 31 seconds (ONLY if Auto Element is enabled)
task.spawn(function()
    while true do
        task.wait(31)

        -- Only update if Auto Element is enabled
        if _G.AUTO_ELEMENT_ENABLED then
            local status = getElementTrackerStatus()

            if elementTrackerStatus then
                pcall(function()
                    elementTrackerStatus:SetDesc(status)
                end)
            end

            print("[Element Tracker] Updated: " .. os.date("%H:%M:%S"))
        end
    end
end)

-- Initial update (immediate) - ONLY if Auto Element is enabled
task.spawn(function()
    task.wait(2) -- Wait for UI to fully load

    if _G.AUTO_ELEMENT_ENABLED then
        local status = getElementTrackerStatus()
        if elementTrackerStatus then
            pcall(function()
                elementTrackerStatus:SetDesc(status)
            end)
        end
        print("[Element Tracker] Initial update completed")
    end
end)

print("✅ Auto Element tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4.5: WEATHER TAB
-- ═══════════════════════════════════════════════════════════════════════════

local WeatherTab = Window:Tab({
    Title = "Weather",
    Icon = "cloud"
})

WeatherTab:Section({
    Title = "🌤️ Weather Controls"
})

-- Auto Weather Toggle
UIComponents.AutoWeatherToggle = WeatherTab:Toggle({
    Title = "Auto Weather",
    Desc = "Auto-purchase Wind, Cloudy, and Storm weather",
    Type = "Toggle",
    Default = false,
    Flag = "AutoWeatherEnabled",
    Callback = function(state)
        if state then
            startAutoWeather()
        else
            stopAutoWeather()
        end
        autoSaveConfig()
    end
})

WeatherTab:Space({ Size = 10 })

-- Purchase Delay Input
UIComponents.WeatherDelayInput = WeatherTab:Input({
    Title = "Purchase Delay",
    Desc = "Delay between weather purchase cycles (seconds)",
    Type = "Input",
    Placeholder = "32",
    Value = savedConfig and savedConfig.WEATHER_PURCHASE_DELAY and tostring(savedConfig.WEATHER_PURCHASE_DELAY) or "32",
    InputIcon = "clock",
    Callback = function(value)
        local delay = tonumber(value)
        if delay and delay > 0 then
            _G.WEATHER_PURCHASE_DELAY = delay
            print(string.format("⏱️ Weather purchase delay: %ds", delay))
        else
            print("❌ Invalid delay! Using default: 32s")
            _G.WEATHER_PURCHASE_DELAY = 32
        end
        autoSaveConfig()
    end
})

WeatherTab:Space({ Size = 20 })

WeatherTab:Divider()

WeatherTab:Space({ Size = 15 })

WeatherTab:Section({
    Title = "ℹ️ Weather Info"
})

WeatherTab:Paragraph({
    Title = "📋 Purchase Order",
    Desc = "1. Wind\n2. Cloudy\n3. Storm\n\nDelay: 0.01s between each weather\nCycle delay: Custom (default 32s)"
})

WeatherTab:Space({ Size = 15 })

WeatherTab:Paragraph({
    Title = "⚙️ How It Works",
    Desc = "When enabled, this will automatically purchase Wind, Cloudy, and Storm weather in sequence every X seconds (configurable delay).\n\nUse this to keep weather effects active continuously."
})

print("✅ Auto Weather tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4.6: TELEPORT TAB
-- ═══════════════════════════════════════════════════════════════════════════

local TeleportTab = Window:Tab({
    Title = "Teleport",
    Icon = "map-pin"
})

TeleportTab:Section({
    Title = "📍 Teleport Locations"
})

-- Kohana Volcano Button
TeleportTab:Button({
    Title = "Kohana Volcano",
    Desc = "Teleport to Kohana Volcano",
    Callback = function()
        teleportToLocation("Kohana Volcano")
    end
})

TeleportTab:Space({ Size = 10 })

-- Sisyphus Statue Button
TeleportTab:Button({
    Title = "Sisyphus Statue",
    Desc = "Teleport to Sisyphus Statue",
    Callback = function()
        teleportToLocation("Sisyphus Statue")
    end
})

TeleportTab:Space({ Size = 10 })

-- Coral Reefs Button
TeleportTab:Button({
    Title = "Coral Reefs",
    Desc = "Teleport to Coral Reefs",
    Callback = function()
        teleportToLocation("Coral Reefs")
    end
})

TeleportTab:Space({ Size = 10 })

-- Esoteric Depths Button
TeleportTab:Button({
    Title = "Esoteric Depths",
    Desc = "Teleport to Esoteric Depths",
    Callback = function()
        teleportToLocation("Esoteric Depths")
    end
})

TeleportTab:Space({ Size = 10 })

-- Crater Island Button
TeleportTab:Button({
    Title = "Crater Island",
    Desc = "Teleport to Crater Island",
    Callback = function()
        teleportToLocation("Crater Island")
    end
})

TeleportTab:Space({ Size = 10 })

-- Spawn Button
TeleportTab:Button({
    Title = "Spawn",
    Desc = "Teleport to Spawn",
    Callback = function()
        teleportToLocation("Spawn")
    end
})

TeleportTab:Space({ Size = 10 })

-- Lost Isle Button
TeleportTab:Button({
    Title = "Lost Isle",
    Desc = "Teleport to Lost Isle",
    Callback = function()
        teleportToLocation("Lost Isle")
    end
})

TeleportTab:Space({ Size = 10 })

-- Weather Machine Button
TeleportTab:Button({
    Title = "Weather Machine",
    Desc = "Teleport to Weather Machine",
    Callback = function()
        teleportToLocation("Weather Machine")
    end
})

TeleportTab:Space({ Size = 10 })

-- Tropical Grove Button
TeleportTab:Button({
    Title = "Tropical Grove",
    Desc = "Teleport to Tropical Grove",
    Callback = function()
        teleportToLocation("Tropical Grove")
    end
})

TeleportTab:Space({ Size = 10 })

-- Mount Hallow Button
TeleportTab:Button({
    Title = "Mount Hallow",
    Desc = "Teleport to Mount Hallow",
    Callback = function()
        teleportToLocation("Mount Hallow")
    end
})

TeleportTab:Space({ Size = 10 })

-- Treasure Room Button
TeleportTab:Button({
    Title = "Treasure Room",
    Desc = "Teleport to Treasure Room",
    Callback = function()
        teleportToLocation("Treasure Room")
    end
})

TeleportTab:Space({ Size = 10 })

-- Kohana Button
TeleportTab:Button({
    Title = "Kohana",
    Desc = "Teleport to Kohana",
    Callback = function()
        teleportToLocation("Kohana")
    end
})

TeleportTab:Space({ Size = 10 })

-- Underground Cellar Button
TeleportTab:Button({
    Title = "Underground Cellar",
    Desc = "Teleport to Underground Cellar",
    Callback = function()
        teleportToLocation("Underground Cellar")
    end
})

TeleportTab:Space({ Size = 10 })

-- Ancient Jungle Button
TeleportTab:Button({
    Title = "Ancient Jungle",
    Desc = "Teleport to Ancient Jungle",
    Callback = function()
        teleportToLocation("Ancient Jungle")
    end
})

TeleportTab:Space({ Size = 10 })

-- Sacred Temple Button
TeleportTab:Button({
    Title = "Sacred Temple",
    Desc = "Teleport to Sacred Temple",
    Callback = function()
        teleportToLocation("Sacred Temple")
    end
})

TeleportTab:Space({ Size = 10 })

-- Placeholder untuk lokasi tambahan (bisa ditambahkan nanti)
--[[
TeleportTab:Button({
    Title = "Ancient Jungle",
    Desc = "Teleport to Ancient Jungle",
    Callback = function()
        teleportToLocation("Ancient Jungle")
    end
})

TeleportTab:Space({ Size = 10 })
]]

TeleportTab:Divider()

TeleportTab:Space({ Size = 15 })

TeleportTab:Section({
    Title = "ℹ️ Info"
})

TeleportTab:Paragraph({
    Title = "📌 Available Locations",
    Desc = "• Sacred Temple\n\nMore locations can be added to TELEPORT_LOCATIONS table in the code."
})

TeleportTab:Space({ Size = 15 })

TeleportTab:Paragraph({
    Title = "⚙️ How to Add Locations",
    Desc = "1. Find the location's CFrame coordinates\n2. Add to TELEPORT_LOCATIONS table (line ~1770)\n3. Add button in this tab UI\n\nFormat:\n[\"Location Name\"] = CFrame.new(...)"
})

print("✅ Teleport tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4.7: CONFIG TAB (PRESETS)
-- ═══════════════════════════════════════════════════════════════════════════

local ConfigTab = Window:Tab({
    Title = "Config",
    Icon = "settings"
})

ConfigTab:Section({
    Title = "⚙️ Preset Configurations"
})

-- Preset 1: Full Auto Mode
local preset1Running = false

local function activatePreset1()
    if preset1Running then
        print("⚠️ Preset 1 already running!")
        return
    end

    preset1Running = true

    print(string.rep("=", 70))
    print("🚀 PRESET 1 - ACTIVATING FULL AUTO MODE")
    print(string.rep("=", 70))
    print("Sequence: Weather → Auto Element → Element Farm → Auto Sell\n")

    task.spawn(function()
        -- Step 1: Auto Weather
        print("[Preset 1] Step 1/4: Activating Auto Weather...")
        if not _G.AUTO_WEATHER_ENABLED then
            startAutoWeather()
            print("[Preset 1] ✅ Auto Weather activated")
        else
            print("[Preset 1] ⏭️ Auto Weather already active")
        end
        task.wait(2)

        -- Step 2: Auto Element
        print("[Preset 1] Step 2/4: Activating Auto Element...")
        if not _G.AUTO_ELEMENT_ENABLED then
            startAutoElement()
            print("[Preset 1] ✅ Auto Element activated")
        else
            print("[Preset 1] ⏭️ Auto Element already active")
        end
        task.wait(2)

        -- Step 3: Auto Sell (Element Farm REMOVED)
        print("[Preset 1] Step 3/3: Activating Auto Sell...")
        if not _G.AUTO_SELL_ENABLED then
            startAutoSell()
            print("[Preset 1] ✅ Auto Sell activated")
        else
            print("[Preset 1] ⏭️ Auto Sell already active")
        end

        print(string.rep("=", 70))
        print("🎉 PRESET 1 - FULL AUTO MODE ACTIVATED!")
        print(string.rep("=", 70))
        print("Active features:")
        print("  ✅ Auto Weather (Wind, Cloudy, Storm)")
        print("  ✅ Auto Element (Quest tracking & teleport)")
        print("  ✅ Auto Sell (Inventory management)")
        print("  ℹ️ Element Farm removed - use main Auto Farm tab")
        print(string.rep("=", 70) .. "\n")

        preset1Running = false
    end)
end

local function deactivatePreset1()
    print(string.rep("=", 70))
    print("🛑 PRESET 1 - DEACTIVATING FULL AUTO MODE")
    print(string.rep("=", 70))

    -- Stop all features
    if _G.AUTO_WEATHER_ENABLED then
        stopAutoWeather()
        print("[Preset 1] ✅ Auto Weather stopped")
    end

    if _G.AUTO_ELEMENT_ENABLED then
        stopAutoElement()
        print("[Preset 1] ✅ Auto Element stopped")
    end

    -- Element Farm removed - no longer available

    if _G.AUTO_SELL_ENABLED then
        stopAutoSell()
        print("[Preset 1] ✅ Auto Sell stopped")
    end

    print(string.rep("=", 70))
    print("✅ PRESET 1 - ALL FEATURES DEACTIVATED")
    print(string.rep("=", 70) .. "\n")

    preset1Running = false
end

-- Preset 1 Toggle
ConfigTab:Toggle({
    Title = "Preset 1: Full Auto",
    Desc = "Activate: Weather → Element → Farm → Sell",
    Type = "Toggle",
    Default = false,
    Flag = "Preset1Enabled",
    Callback = function(state)
        if state then
            activatePreset1()
        else
            deactivatePreset1()
        end
    end
})

ConfigTab:Space({ Size = 15 })

ConfigTab:Divider()

ConfigTab:Space({ Size = 15 })

ConfigTab:Section({
    Title = "ℹ️ Preset Info"
})

ConfigTab:Paragraph({
    Title = "📋 Preset 1 Details",
    Desc = "Full Auto Mode activates all farming features in sequence:\n\n1. Auto Weather (32s cycle)\n2. Auto Element (Quest tracking)\n3. Element Farm (Back-to-back TP)\n4. Auto Sell (60s cycle)\n\nThis preset is designed for fully automated farming with minimal user interaction."
})

ConfigTab:Space({ Size = 15 })

ConfigTab:Paragraph({
    Title = "⚠️ Important Notes",
    Desc = "• Make sure you have a quest active (Label2/Label3)\n• Ensure you're at the correct location before starting\n• Monitor the first few cycles to ensure everything works\n• You can toggle individual features off if needed"
})

print("✅ Config tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- MISC TAB
-- ═══════════════════════════════════════════════════════════════════════════

local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "sliders"
})

-- Freeze Character Section
MiscTab:Section({
    Title = "🔒 Character Position"
})

UIComponents.FreezeCharToggle = MiscTab:Toggle({
    Title = "Freeze Char",
    Desc = "Lock character position to prevent drift/drowning (Anti-Drown enabled)",
    Type = "Toggle",
    Default = savedConfig and savedConfig.FREEZE_CHAR_ENABLED or false,
    Flag = "FreezeCharEnabled",
    Callback = function(state)
        _G.FREEZE_CHAR_ENABLED = state
        if state then
            freezeCharPosition()
        else
            unfreezeCharPosition()
        end
        autoSaveConfig()
    end
})

MiscTab:Space({ Size = 10 })

MiscTab:Paragraph({
    Title = "ℹ️ Freeze Character Info",
    Desc = "Locks your character position with strong anti-gravity and anti-drown protection. Prevents Y-axis drift and overall position drift. Automatically unfreezes on death/respawn."
})

MiscTab:Space({ Size = 20 })

MiscTab:Divider()

MiscTab:Space({ Size = 15 })

-- GPU Saver Section
MiscTab:Section({
    Title = "⚡ GPU Saver"
})

UIComponents.GPUSaverToggle = MiscTab:Toggle({
    Title = "GPU Saver",
    Desc = "Reduce VRAM usage without FPS limit. Shows white screen with stats overlay.",
    Type = "Toggle",
    Default = savedConfig and savedConfig.GPU_SAVER_ENABLED or false,
    Flag = "GPUSaverEnabled",
    Callback = function(state)
        if state then
            enableGPUSaver()
        else
            disableGPUSaver()
        end
        autoSaveConfig()
    end
})

MiscTab:Space({ Size = 20 })

MiscTab:Divider()

MiscTab:Space({ Size = 15 })

-- ═════════════════════════════════════════════════════════════════════════
-- PERFORMANCE OPTIMIZATION SECTION
-- ═════════════════════════════════════════════════════════════════════════

MiscTab:Section({
    Title = "⚡ Performance Optimization"
})

-- Remove Island Button
MiscTab:Button({
    Title = "Remove Islands",
    Desc = "Delete all island models from workspace to improve performance",
    Callback = function()
        local success, removed = pcall(function()
            local count = 0
            local Islands = game:GetService("Workspace"):FindFirstChild("Islands")
            if Islands then
                for _, island in pairs(Islands:GetChildren()) do
                    island:Destroy()
                    count = count + 1
                end
            end
            return count
        end)

        if success and removed > 0 then
            print(string.format("✅ Removed %d islands from workspace", removed))
        elseif success then
            print("⚠️ No islands found to remove")
        else
            warn("❌ Failed to remove islands")
        end
    end
})

MiscTab:Space({ Size = 10 })

-- Unlock FPS Button
MiscTab:Button({
    Title = "Unlock FPS",
    Desc = "Set FPS cap to 240 for maximum performance",
    Callback = function()
        local success = pcall(function()
            setfpscap(240)
        end)

        if success then
            print("✅ FPS unlocked to 240")
        else
            warn("❌ Failed to unlock FPS (setfpscap not supported)")
        end
    end
})

print("✅ Misc tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- UPGRADE TAB
-- ═══════════════════════════════════════════════════════════════════════════

local UpgradeTab = Window:Tab({
    Title = "Upgrade",
    Icon = "arrow-up"
})

-- Auto Upgrade Section
UpgradeTab:Section({
    Title = "⬆️ Auto Upgrade System"
})

UpgradeTab:Paragraph({
    Title = "Auto Upgrade Information",
    Desc = "Automatically upgrade your Fishing Rods and Baits\nRequires sufficient coins and materials"
})

UpgradeTab:Space({ Size = 15 })

-- Auto Upgrade Rod Toggle
local autoUpgradeRodToggle = UpgradeTab:Toggle({
    Title = "Auto Upgrade Rod",
    Desc = "Automatically upgrade fishing rods when possible",
    Type = "Toggle",
    Default = false,
    Flag = "AutoUpgradeRodEnabled",
    Callback = function(state)
        _G.AUTO_UPGRADE_ROD_ENABLED = state
        if state then
            print("[Auto Upgrade] ✅ Auto Upgrade Rod ENABLED")
            startAutoUpgradeRod()
        else
            print("[Auto Upgrade] ❌ Auto Upgrade Rod DISABLED")
            stopAutoUpgradeRod()
        end
        autoSaveConfig()
    end
})

UpgradeTab:Space({ Size = 10 })

-- Auto Upgrade Bait Toggle
local autoUpgradeBaitToggle = UpgradeTab:Toggle({
    Title = "Auto Upgrade Bait",
    Desc = "Automatically upgrade baits when possible",
    Type = "Toggle",
    Default = false,
    Flag = "AutoUpgradeBaitEnabled",
    Callback = function(state)
        _G.AUTO_UPGRADE_BAIT_ENABLED = state
        if state then
            print("[Auto Upgrade] ✅ Auto Upgrade Bait ENABLED")
            startAutoUpgradeBait()
        else
            print("[Auto Upgrade] ❌ Auto Upgrade Bait DISABLED")
            stopAutoUpgradeBait()
        end
        autoSaveConfig()
    end
})

UpgradeTab:Space({ Size = 20 })

UpgradeTab:Divider()

UpgradeTab:Space({ Size = 15 })

-- Status Section
UpgradeTab:Section({
    Title = "📊 Upgrade Status"
})

UpgradeTab:Paragraph({
    Title = "How It Works",
    Desc = "1. Enable Auto Upgrade Rod/Bait toggle\n2. System detects current inventory\n3. Finds next affordable rod/bait to buy\n4. Auto farm continues until enough coins\n5. Pauses farm, buys item, equips it\n6. Resumes farm and repeats\n\n⚠️ Make sure Auto Farm is enabled!"
})

UpgradeTab:Space({ Size = 10 })

UpgradeTab:Paragraph({
    Title = "Purchase Order",
    Desc = "Rods: Luck → Carbon → Grass → Demascus → Ice → Lucky → Midnight → Steampunk → Chrome → Astral → Ares → Angler\n\nBaits: Topwater → Luck → Midnight → Deep → Chroma → Dark Matter → Corrupt → Aether"
})

print("✅ Upgrade tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- WEBHOOK TAB
-- ═══════════════════════════════════════════════════════════════════════════

local WebhookTab = Window:Tab({
    Title = "Webhook",
    Icon = "bell"
})

-- Webhook Configuration Section
WebhookTab:Section({
    Title = "🔗 Webhook Configuration"
})

-- Secret Webhook Input
UIComponents.WebhookURLInput = WebhookTab:Input({
    Title = "Webhook URL",
    Desc = "Discord webhook URL for rare fish notifications",
    Placeholder = "https://discord.com/api/webhooks/...",
    Value = savedConfig and savedConfig.WEBHOOK_SECRET or "",
    Callback = function(value)
        _G.WEBHOOK_SECRET = value
        if value ~= "" then
            print("[Webhook] Webhook configured!")
        else
            print("[Webhook] Webhook cleared")
        end
        autoSaveConfig()
    end
})

WebhookTab:Space({ Size = 15 })

-- Enable Webhook Toggle
UIComponents.WebhookToggle = WebhookTab:Toggle({
    Title = "Enable Webhook",
    Desc = "Start monitoring for rare fish and send Discord notifications",
    Type = "Toggle",
    Default = false,
    Flag = "WebhookEnabled",
    Callback = function(state)
        if state then
            startWebhookNotifier()
        else
            stopWebhookNotifier()
        end
        autoSaveConfig()
    end
})

WebhookTab:Space({ Size = 15 })

WebhookTab:Divider()

WebhookTab:Space({ Size = 15 })

-- Webhook Info Section
WebhookTab:Section({
    Title = "ℹ️ Webhook Information"
})

WebhookTab:Paragraph({
    Title = "📋 How to Use Webhooks",
    Desc = "1. Create Discord Webhook:\n   • Go to Discord Server Settings\n   • Integrations → Webhooks → New Webhook\n   • Copy the Webhook URL\n\n2. Paste webhook URL in the input box above\n\n3. Toggle 'Enable Webhook' to start monitoring\n\n4. You'll receive notifications when rare fish are caught!"
})

WebhookTab:Space({ Size = 10 })

WebhookTab:Paragraph({
    Title = "⚠️ Important Notes",
    Desc = "• Keep your webhook URL private and secure\n• Don't share webhook URLs with others\n• Event-driven detection (no inventory scanning)\n• Webhook settings are auto-saved per account"
})

WebhookTab:Space({ Size = 10 })

WebhookTab:Paragraph({
    Title = "🐟 Tier-Based Detection System",
    Desc = "Webhooks automatically detect fish by tier:\n\n🔥 Mythic (Tier 6): Rarity 1 in 50,000+\n✨ SECRET (Tier 7): Rarity 1 in 250,000+\n\nAll fish matching these tiers will be detected automatically - no whitelist needed!"
})

print("✅ Webhook tab created")

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: MAIN EXECUTION
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    Main Execution - Auto-start and initialization

    DO NOT MODIFY unless changing startup behavior
]]

-- Start the main loop thread (waits for AUTO_FARM_ENABLED)
task.spawn(runMainLoop)

print(string.rep("=", 80))
print("✅ ALL SYSTEMS LOADED!")
print(string.rep("=", 80))
print("\n🎮 UI is ready!")
print("📋 Features:")
print("  ✅ Auto Farm Tab - Toggle & Custom Delay")
print("  ✅ Auto Element Tab - Element Collection System")
print("  ✅ Inventory Tab - Fish & Items Detection")
print(string.rep("=", 80) .. "\n")

-- Load and apply saved config (after UI is ready)
task.spawn(function()
    task.wait(2) -- Wait for UI to be fully ready
    if savedConfig then
        applyLoadedConfig(savedConfig)
    end
end)
