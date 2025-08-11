-- Pet Warriors (Refactored: reduced redundant locals, consolidated services/modules at top)

-- UI Libraries
local Library = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

-- Core services and aliases
local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = workspace,
    StarterPlayer = game:GetService("StarterPlayer")
}

local RS = Services.ReplicatedStorage
local Players = Services.Players
local LocalPlayer = Players.LocalPlayer

-- Knit
local Knit = require(RS.Shared.Packages.Knit)
if not Knit.Started then
    Knit.OnStart():await()
end

-- Shortcuts for Knit Services path and GetService
local KServices = RS.Shared.Packages.Knit.Services
local GetService = Knit.GetService

-- Optional vendor modules
local AFKModule
pcall(function()
    AFKModule = require(RS.Shared.Vendor.AFKModule)
end)

-- Enums
local BreakablesEnum = require(RS.Shared.Enums.Breakables)
local BackpackCategory = require(RS.Shared.Enums.BackpackCategory)
local BackpackCurrencyTypes = require(RS.Shared.Enums.BackpackCurrencyTypes)
local BossesEnumOK, BossesEnum = pcall(function()
    return require(RS.Shared.Enums.Bosses)
end)
local EggTypesOK, EggTypesEnum = pcall(function()
    return require(RS.Shared.Enums.EggTypes)
end)
local PetsEnum = require(RS.Shared.Enums.Pets)
local ItemTiersEnum = require(RS.Shared.Enums.ItemTiers)
local PotionTypes = require(RS.Shared.Enums.PotionTypes)
local EnchantmentTypes = require(RS.Shared.Enums.EnchantmentTypes)
local UpgradeTreeTypes = require(RS.Shared.Enums.UpgradeTreeTypes)

-- Balancing/Data modules
local UpgradeTree = require(RS.Shared.Balancing.Shared.UpgradeTree)
local EggsModule = require(RS.Shared.Balancing.Shared.Eggs)
local PlotData = require(RS.Shared.Balancing.Shared.Crafting.PlotData)
local SeedData = require(RS.Shared.Balancing.Shared.Crafting.SeedData)
local VendingMachines = require(RS.Shared.Balancing.Shared.VendingMachines)
local Potions = require(RS.Shared.Balancing.Shared.Items.Potions)
local PotionUpgradeMachine = require(RS.Shared.Balancing.Shared.Machines.PotionUpgradeMachine)
local Enchantments = require(RS.Shared.Balancing.Shared.Items.Enchantments)

-- Common vendor
local RomanModule = require(RS.Shared.Vendor.RomanModule)

-- Controllers via Knit
local WorldController = Knit.GetController("WorldController")
local ZoneController = Knit.GetController("ZoneController")
local DataController = Knit.GetController("DataController")
local PotionController = Knit.GetController("PotionController")
local EnchantmentController = Knit.GetController("EnchantmentController")
local BackpackController = Knit.GetController("BackpackController")
local PetController = Knit.GetController("PetController")

-- Controllers via PlayerScripts requires
local BreakableController = require(LocalPlayer.PlayerScripts.Client.Controllers.Normal.Breakables.BreakableController)
local BattleAutoFightController = require(LocalPlayer.PlayerScripts.Client.Controllers.Normal.Battling.BattleAutoFightController)
local BattleNpcController = require(LocalPlayer.PlayerScripts.Client.Controllers.Normal.Battling.BattleNpcController)
local UpgradeTreeController = require(LocalPlayer.PlayerScripts.Client.Controllers.Shared.Core.UpgradeTree.UpgradeTreeController)
local QuestController = require(LocalPlayer.PlayerScripts.Client.Controllers.Shared.Core.QuestController)

-- Upgrade unlock checks
local tier3Unlocked = UpgradeTreeController:hasUnlocked(UpgradeTreeTypes.Node116)
local tier4Unlocked = UpgradeTreeController:hasUnlocked(UpgradeTreeTypes.Node117)

-- Small helpers
local function romanToNumber(roman)
    if roman == "I" then return 1 end
    if roman == "II" then return 2 end
    if roman == "III" then return 3 end
    if roman == "IV" then return 4 end
    if roman == "V" then return 5 end
    if roman == "VI" then return 6 end
    if roman == "VII" then return 7 end
    if roman == "VIII" then return 8 end
    if roman == "IX" then return 9 end
    if roman == "X" then return 10 end
    return 1
end

-- Window
local Window = Library:Window{
    Title = "Pet Warriors",
    SubTitle = "Script Hub",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Resize = false,
    Acrylic = true,
    Theme = "Vynixu",
    MinimizeKey = Enum.KeyCode.LeftShift
}

-- Tabs
local Tabs = {
    AutoFarm = Window:AddTab({ Title = "Main", Icon = "sword" }),
    Eggs = Window:AddTab({ Title = "Hatch", Icon = "egg" }),
    Upgrades = Window:AddTab({ Title = "Upgrades", Icon = "star" }),
    Machines = Window:AddTab({ Title = "Machines", Icon = "cog" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "rocket" }),
    Plant = Window:AddTab({ Title = "Gardening", Icon = "phosphor-plant-bold" }),
    Potion = Window:AddTab({ Title = "Potion Crafting", Icon = "flask-conical" }),
    Enchant = Window:AddTab({ Title = "Enchant Upgrades", Icon = "book-open" }),
    Minigames = Window:AddTab({ Title = "Minigames", Icon = "phosphor-game-controller-light" }),
    Gifts = Window:AddTab({ Title = "Misc", Icon = "gift" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- =============== Auto Train ===============
local AutoCollectSection = Tabs.AutoFarm:AddSection("Auto Train")

-- Collect breakable names for dropdown, exclude hearts with sizes
local breakableNames, uniqueItems = {}, {}
for enumName, enumId in pairs(BreakablesEnum) do
    local name = enumName:match("^W%d+_Z%d+_(.+)$") or enumName
    local lowerName = name:lower()
    local isHeartSize = (lowerName:find("small") and lowerName:find("hearts"))
        or (lowerName:find("medium") and lowerName:find("hearts"))
        or (lowerName:find("large") and lowerName:find("hearts"))
    if not isHeartSize and not uniqueItems[name] then
        uniqueItems[name] = enumId
        table.insert(breakableNames, name)
    end
end
 table.sort(breakableNames)

-- UI Paragraph to show priority list
local breakablePriorityParagraph = AutoCollectSection:AddParagraph("BreakablePriority", {
    Title = "Target Priority",
    Content = "No breakables selected",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

-- Breakable priorities storage: name -> priority (lower = higher priority)
local breakablePriorities, nextPriority = {}, 1

local function updateBreakablePriorityDisplay()
    local prioritized = {}
    for name, priority in pairs(breakablePriorities) do
        table.insert(prioritized, { name = name, priority = priority })
    end
    table.sort(prioritized, function(a, b) return a.priority < b.priority end)

    if #prioritized == 0 then
        breakablePriorityParagraph:SetValue("No breakables selected")
        return
    end

    local text = "Priority order:\n"
    for i, item in ipairs(prioritized) do
        text ..= i .. ". " .. item.name .. "\n"
    end
    breakablePriorityParagraph:SetValue(text)
end

local breakableDropdown = AutoCollectSection:AddDropdown("BreakableSelect", {
    Title = "Select what to aim for",
    Description = "Items will be prioritized in the order selected. First = highest priority.",
    Values = breakableNames,
    Multi = true,
    Searchable = true,
    Default = {},
    Callback = function(value)
        local currentlySelected = {}
        for name, selected in pairs(value) do
            if selected then currentlySelected[name] = true end
        end
        for name in pairs(breakablePriorities) do
            if not currentlySelected[name] then
                breakablePriorities[name] = nil
            end
        end
        for name, selected in pairs(value) do
            if selected and not breakablePriorities[name] then
                breakablePriorities[name] = nextPriority
                nextPriority += 1
            end
        end
        updateBreakablePriorityDisplay()
    end
})

local function getBreakablesInCurrentZone()
    local currentWorld = WorldController.Current or "World1"
    local worldNumber = tonumber(currentWorld:match("World(%d+)")) or 1
    local currentZone = ZoneController.Current or 1

    local breakableObjectsByName = {}

    if BreakableController.Breakables then
        for _, breakable in pairs(BreakableController.Breakables) do
            local worldNum = tonumber(tostring(breakable.World):match("World(%d+)")) or tonumber(breakable.World) or 1
            if worldNum == worldNumber and breakable.Zone == currentZone then
                local id = breakable.ID
                local name = "Unknown"
                for enumName, enumId in pairs(BreakablesEnum) do
                    if enumId == id then
                        name = enumName:match("^W%d+_Z%d+_(.+)$") or enumName
                        break
                    end
                end
                breakableObjectsByName[name] = breakableObjectsByName[name] or {}
                table.insert(breakableObjectsByName[name], breakable)
            end
        end
    end

    return breakableObjectsByName
end

local function teleportToBreakable(breakable)
    if not breakable or not breakable.Position then return false end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(breakable.Position + Vector3.new(0, 3, 0))
        if AFKModule then pcall(function() AFKModule.Set("Breakables") end) end
        return true
    end
    return false
end

local function findClosestPriorityBreakable()
    local breakableObjects = getBreakablesInCurrentZone()
    if not breakableObjects or not next(breakableObjects) then return nil end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local charPos = hrp.Position

    local closestBreakable, closestDistance = nil, math.huge
    for name, objects in pairs(breakableObjects) do
        if breakablePriorities[name] and #objects > 0 then
            for _, obj in ipairs(objects) do
                local dist = (obj.Position - charPos).Magnitude
                if dist < closestDistance then
                    closestDistance, closestBreakable = dist, obj
                end
            end
        end
    end
    return closestBreakable
end

local function attackBreakable()
    pcall(function()
        local AttackService = KServices.BreakableAttackService
        if AttackService and AttackService.RF and AttackService.RF.attack then
            AttackService.RF.attack:InvokeServer()
        end
    end)
end

local autoTrainEnabled = false
local autoTrainThread

AutoCollectSection:AddToggle("AutoTrainToggle", {
    Title = "Auto Train",
    Description = "Automatically teleport to and attack breakables based on priority",
    Default = false,
    Callback = function(enabled)
        autoTrainEnabled = enabled
        if enabled then
            autoTrainThread = task.spawn(function()
                while autoTrainEnabled do
                    local target = findClosestPriorityBreakable()
                    if not target then
                        local breakableObjects = getBreakablesInCurrentZone()
                        local sizeKeywords = { "LARGE", "MEDIUM", "SMALL" }
                        local foundFallback = false
                        for _, size in ipairs(sizeKeywords) do
                            for name, objects in pairs(breakableObjects) do
                                if name:upper():find(size) and #objects > 0 then
                                    target = objects[1]
                                    foundFallback = true
                                    break
                                end
                            end
                            if foundFallback then break end
                        end
                        if not foundFallback then
                            for _, objects in pairs(breakableObjects) do
                                if #objects > 0 then
                                    target = objects[1]
                                    break
                                end
                            end
                        end
                    end

                    if target then teleportToBreakable(target) end

                    local attackStart = tick()
                    while autoTrainEnabled and tick() - attackStart < 0.01 do
                        attackBreakable()
                        task.wait(0.001)
                    end
                    task.wait()
                end
            end)
        else
            if autoTrainThread then task.cancel(autoTrainThread) autoTrainThread = nil end
        end
    end
})

updateBreakablePriorityDisplay()

-- Auto Collect Drops
local autoCollectEnabled = false
local autoCollectThread

AutoCollectSection:AddToggle("AutoCollectDrops", {
    Title = "Auto Collect Drops",
    Description = "Collect Dropped Items/Strength",
    Default = false,
    Callback = function(enabled)
        autoCollectEnabled = enabled
        if enabled then
            autoCollectThread = task.spawn(function()
                while autoCollectEnabled do
                    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
                    local drops = Services.Workspace:FindFirstChild("__DROPS__") or Services.Workspace:WaitForChild("__DROPS__")
                    for _, drop in ipairs(drops:GetChildren()) do
                        if drop:IsA("BasePart") then
                            drop.CFrame = hrp.CFrame
                        end
                    end
                    task.wait(3)
                end
            end)
        else
            if autoCollectThread then task.cancel(autoCollectThread) autoCollectThread = nil end
        end
    end
})

-- =============== OP Auto Fight ===============
local AutoFightSection = Tabs.AutoFarm:AddSection("OP Auto Fight")

local function getWorldAndBossNumber(key)
    local world, boss = string.match(tostring(key), "World(%d+)Boss(%d+)")
    if world and boss then
        return world, boss
    end
    return nil, nil
end

local bossNames, bossKeyMap = {}, {}
if BossesEnumOK and BossesEnum then
    for bossName, bossValue in pairs(BossesEnum) do
        table.insert(bossNames, bossName)
        bossKeyMap[bossName] = bossValue
    end
    table.sort(bossNames, function(a, b)
        local aWorld, aBoss = string.match(a, "World(%d+)Boss(%d+)")
        local bWorld, bBoss = string.match(b, "World(%d+)Boss(%d+)")
        aWorld, aBoss = tonumber(aWorld), tonumber(aBoss)
        bWorld, bBoss = tonumber(bWorld), tonumber(bBoss)
        if aWorld == bWorld then
            return aBoss < bBoss
        end
        return aWorld < bWorld
    end)
end

local BossDropdown = AutoFightSection:AddDropdown("BossSelect", {
    Title = "Select Boss",
    Description = "Choose a boss to auto fight.",
    Values = bossNames,
    Multi = false,
    Searchable = true,
    Default = bossNames[1] or nil,
    Callback = function(_) end
})

local autoFightEnabled = false
AutoFightSection:AddToggle("AutoFightToggle", {
    Title = "Auto Fight",
    Description = "Automatically fights the selected boss repeatedly.",
    Default = false,
    Callback = function(enabled)
        autoFightEnabled = enabled

        local selectedBoss = BossDropdown.Value
        local bossKey = bossKeyMap[selectedBoss]
        local worldNum, bossNum = getWorldAndBossNumber(bossKey or "")
        local worldName = worldNum and ("World" .. tostring(worldNum)) or nil
        local isFighting = false

        local function startBattle()
            if worldName and bossNum and not isFighting then
                isFighting = true
                local args = { worldName, tonumber(bossNum) }
                local ok = pcall(function()
                    KServices.BattleService.RF.startPvE:InvokeServer(unpack(args))
                end)
                if not ok then isFighting = false end
            end
        end

        local function attackBoss(bossId, npc)
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp and npc and npc:FindFirstChild("HumanoidRootPart") then
                hrp.CFrame = CFrame.new(npc.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
                local args = { { tostring(bossId) } }
                pcall(function()
                    KServices.BattleAttackService.RF.attack:InvokeServer(unpack(args))
                end)
            end
        end

        if autoFightEnabled then
            BattleAutoFightController:KnitStart()
            startBattle()

            if not BattleNpcController._originalOnSpawnBosses then
                BattleNpcController._originalOnSpawnBosses = BattleNpcController.onSpawnBosses
            end

            BattleNpcController.onSpawnBosses = function(self, ...)
                local originalBosses = {}
                for k, v in pairs(self.Bosses) do originalBosses[k] = v end
                local result = BattleNpcController._originalOnSpawnBosses(self, ...)
                for bossId, bossData in pairs(self.Bosses) do
                    if not originalBosses[bossId] and bossData.NPC then
                        attackBoss(bossId, bossData.NPC)
                    end
                end
                return result
            end

            local BattleService = GetService("BattleService")
            if BattleService and BattleService.onBattleEnded then
                BattleService.onBattleEnded:Connect(function()
                    isFighting = false
                    if autoFightEnabled then
                        task.delay(0.5, function()
                            if autoFightEnabled then startBattle() end
                        end)
                    end
                end)
            end

            task.spawn(function()
                while autoFightEnabled do
                    local character = LocalPlayer.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local closestBossId, closestBossNpc, shortestDist = nil, nil, math.huge
                        for bossId, bossData in pairs(BattleNpcController.Bosses) do
                            local npc = bossData.NPC
                            if npc and npc:FindFirstChild("HumanoidRootPart") then
                                local dist = (hrp.Position - npc.HumanoidRootPart.Position).Magnitude
                                if dist < shortestDist then
                                    shortestDist, closestBossId, closestBossNpc = dist, bossId, npc
                                end
                            end
                        end
                        if closestBossId and closestBossNpc then
                            attackBoss(closestBossId, closestBossNpc)
                        end
                    end
                    task.wait(0.2)
                end
            end)
        else
            isFighting = false
            if BattleNpcController._originalOnSpawnBosses then
                BattleNpcController.onSpawnBosses = BattleNpcController._originalOnSpawnBosses
            end
        end
    end
})

AutoFightSection:AddButton({
    Title = "Never Lose",
    Description = "You will no longer take damage from bosses (rejoining resets this).",
    Callback = function()
        if getgenv().NamecallBlocked then return end
        getgenv().NamecallBlocked = true
        local attackRemote = KServices.BattleAttackService.RF.attackPlayer
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == attackRemote and method == "InvokeServer" then
                return nil
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
})

local AutoFightSection1 = Tabs.AutoFarm:AddSection("Glitch Fix (Respawn)")
AutoFightSection1:AddButton({
    Title = "Respawn",
    Description = "Sometimes the player can't move after turning off this toggle. This should fix it.",
    Callback = function()
        local character = LocalPlayer.Character
        if character then character:BreakJoints() end
    end
})

-- =============== Eggs ===============
local EggsSection = Tabs.Eggs:AddSection("Eggs")
EggsSection:AddParagraph("Note", {
    Title = "Note",
    Content = "For the eggs/sword chests, W = World, and Z = Zone.",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

if not EggTypesOK then return end

-- Build egg entries
local eggEntries = {}
for key, value in pairs(EggTypesEnum) do
    if type(value) == "string" then
        local w, z = string.match(value, "^W(%d+)_Z(%d+)")
        if w and z then
            table.insert(eggEntries, { key = key, value = value, w = tonumber(w), z = tonumber(z) })
        end
    end
end

 table.sort(eggEntries, function(a, b)
    if a.w == b.w then return a.z < b.z end
    return a.w < b.w
end)

local eggNames = {}
for _, entry in ipairs(eggEntries) do table.insert(eggNames, entry.key) end
if #eggNames == 0 then return end

local SelectedEggValue = nil
local hatchAmount = 1
local autoBuyEggsEnabled = false
local autoBuyEggsThread

local EggDropdown = EggsSection:AddDropdown("EggSelect", {
    Title = "Select Egg",
    Values = eggNames,
    Multi = false,
    Searchable = true,
    Default = eggNames[1],
    Callback = function(value)
        for _, entry in ipairs(eggEntries) do
            if entry.key == value then
                SelectedEggValue = entry.value
                break
            end
        end
    end
})

if eggNames[1] then
    for _, entry in ipairs(eggEntries) do
        if entry.key == eggNames[1] then
            SelectedEggValue = entry.value
            break
        end
    end
end

EggsSection:AddInput("HatchAmountInput", {
    Title = "Hatch Amount",
    Description = "Enter the number of eggs to hatch\n(must own).",
    Placeholder = "1",
    Numeric = true,
    Default = "1",
    Callback = function(value)
        local num = tonumber(value)
        hatchAmount = (num and num > 0) and math.floor(num) or 1
    end
})

EggsSection:AddToggle("AutoBuyEggToggle", {
    Title = "Auto Buy Egg",
    Description = "Automatically buys the selected egg with the specified hatch amount.",
    Default = false,
    Callback = function(enabled)
        autoBuyEggsEnabled = enabled
        if enabled then
            autoBuyEggsThread = task.spawn(function()
                while autoBuyEggsEnabled do
                    if SelectedEggValue and hatchAmount > 0 then
                        pcall(function()
                            KServices.EggService.RF.purchaseEgg:InvokeServer(SelectedEggValue, hatchAmount, false)
                        end)
                    end
                    task.wait(0.1)
                end
            end)
        else
            if autoBuyEggsThread then task.cancel(autoBuyEggsThread) autoBuyEggsThread = nil end
        end
    end
})

-- =============== Sword Chests ===============
local ChestSection = Tabs.Eggs:AddSection("Sword Chests")

local chestEggEntries = {}
for key, value in pairs(EggTypesEnum) do
    if type(value) == "string" then
        local w, z = string.match(value, "^W(%d+)_Z(%d+)")
        if w and z then
            local wNum, zNum = tonumber(w), tonumber(z)
            if wNum and zNum then
                table.insert(chestEggEntries, { key = key, value = value, w = wNum, z = zNum })
            end
        end
    end
end

 table.sort(chestEggEntries, function(a, b)
    if a.w == b.w then return a.z < b.z end
    return a.w < b.w
end)

local chestNames = {}
for _, entry in ipairs(chestEggEntries) do
    if entry and entry.key and type(entry.key) == "string" then
        table.insert(chestNames, (entry.key:gsub("_", "")))
    end
end

local ChestDropdown = ChestSection:AddDropdown("SelectChestDropdown", {
    Title = "Select Chest",
    Description = "Choose a sword chest.",
    Values = chestNames,
    Multi = false,
    Default = chestNames[1] or nil,
    Callback = function(_) end
})

local autoOpenChestsEnabled = false
local autoOpenChestsThread

ChestSection:AddToggle("AutoOpenChestToggle", {
    Title = "Auto Open",
    Description = "Automatically opens the selected sword chest.",
    Default = false,
    Callback = function(enabled)
        autoOpenChestsEnabled = enabled
        if enabled then
            autoOpenChestsThread = task.spawn(function()
                while autoOpenChestsEnabled do
                    local crateArg = ChestDropdown.Value
                    if crateArg then
                        pcall(function()
                            KServices.SwordCrateService.RF.open:InvokeServer(crateArg)
                        end)
                    end
                    task.wait(1)
                end
            end)
        else
            if autoOpenChestsThread then task.cancel(autoOpenChestsThread) autoOpenChestsThread = nil end
        end
    end
})

-- =============== Upgrades ===============
local UpgradesSection = Tabs.Upgrades:AddSection("Stats")
local statsInfo = UpgradesSection:AddParagraph("UpgradeStats", {
    Title = "Upgrade Statistics",
    Content = "Loading...",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updateStats()
    local ownedUpgrades = DataController:GetValue({ "UpgradeTree" }) or {}
    local currentPoints = DataController:GetValue({ "UpgradePoints" }) or 0

    local totalUpgrades, totalCost = 0, 0
    local ownedLookup = {}
    for _, id in pairs(ownedUpgrades) do ownedLookup[id] = true end

    for _, upgrade in pairs(UpgradeTree) do
        if type(upgrade) == "table" and not upgrade.Back then
            totalUpgrades += 1
            if not ownedLookup[upgrade.ID] then
                local cost = (type(upgrade.Cost) == "table" and upgrade.Cost.Amount) or 0
                totalCost += cost
            end
        end
    end

    local ownedCount = #ownedUpgrades
    local missingCount = totalUpgrades - ownedCount

    statsInfo:SetValue(string.format(
        "\nCurrent Upgrade Points: %d\n\nOwned Upgrades: %d\nMissing Upgrades: %d\nTotal Upgrades: %d\n\nTotal Cost for Missing Upgrades: %d",
        currentPoints, ownedCount, missingCount, totalUpgrades, totalCost
    ))
end

updateStats()

task.spawn(function()
    while true do
        task.wait(5)
        updateStats()
    end
end)

local autoBuyUpgradesEnabled = false
local autoBuyUpgradesThread

UpgradesSection:AddToggle("AutoBuyUpgrades", {
    Title = "Auto Buy Upgrades",
    Description = "Automatically buy affordable upgrades.",
    Default = false,
    Callback = function(enabled)
        autoBuyUpgradesEnabled = enabled
        if enabled then
            autoBuyUpgradesThread = task.spawn(function()
                while autoBuyUpgradesEnabled do
                    local ownedUpgrades = DataController:GetValue({ "UpgradeTree" }) or {}
                    local currentPoints = DataController:GetValue({ "UpgradePoints" }) or 0
                    local ownedLookup = {}
                    for _, id in pairs(ownedUpgrades) do ownedLookup[id] = true end

                    local boughtAny = false
                    for _, upgrade in pairs(UpgradeTree) do
                        if type(upgrade) == "table" and not upgrade.Back and not ownedLookup[upgrade.ID] then
                            local cost = (type(upgrade.Cost) == "table" and upgrade.Cost.Amount) or 0
                            if currentPoints >= cost and cost > 0 then
                                pcall(function() KServices.UpgradeTreeService.RF.unlock:InvokeServer(upgrade.ID) end)
                                boughtAny = true
                                task.wait(1)
                                break
                            end
                        end
                    end
                    if not boughtAny then task.wait(3) end
                end
            end)
        else
            if autoBuyUpgradesThread then task.cancel(autoBuyUpgradesThread) autoBuyUpgradesThread = nil end
        end
    end
})

-- =============== Quests ===============
local QuestsFolder = RS.Shared.Data.Core.Quests

local questTitles, questMap, moduleInfo = {}, {}, {}
for _, questModule in pairs(QuestsFolder:GetChildren()) do
    local quest = require(questModule)
    local ok, title = pcall(function() return quest:GetTitle() end)
    if ok and title then
        moduleInfo[quest.ID] = { title = title, module = questModule.Name, event = quest.Event, id = quest.ID }
        table.insert(questTitles, title)
        questMap[title] = quest.ID
    end
end
 table.sort(questTitles)

local function getQuestData(questId)
    for _, activeQuest in pairs(QuestController.Current) do
        if activeQuest.Name and activeQuest.Type == questId then
            return activeQuest
        end
    end
    return nil
end

local QuestSection = Tabs.Upgrades:AddSection("Auto Quest")
QuestSection:AddParagraph("QuestNote", {
    Title = "Note",
    Content = "Quests that involve hatching, breaking, bosses, etc, will use your selected values from other dropdowns. If the quest requires you to gold pets, this will hatch the selected egg and gold the EASY pets from it.",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local selectedQuests = {}
local QuestDropdown = QuestSection:AddDropdown("QuestSelect", {
    Title = "Select Quest",
    Description = "Choose which quest to auto-complete",
    Values = questTitles,
    Multi = true,
    Searchable = true,
    Default = {},
    Callback = function(value) selectedQuests = value or {} end
})

QuestSection:AddButton({
    Title = "Select All",
    Description = "Select all available quests",
    Callback = function()
        local allSelected = {}
        for _, title in ipairs(questTitles) do allSelected[title] = true end
        QuestDropdown:SetValue(allSelected)
    end
})

local autoCompleteEnabled = false

local function completeQuest(questName, questData)
    if not questData or questData.Completed then return end

    if questName == "Swing Sword" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                KServices.SwordAttackService.RF.swing:InvokeServer()
                task.wait(0.25)
            end
        end)
    end

    if questName == "Upgrade Pets" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                local egg = EggsModule.Eggs[SelectedEggValue]
                if egg and egg.Loot and egg.Loot.Rewards then
                    local commonPets = {}
                    for petId, chance in pairs(egg.Loot.Rewards) do
                        if type(petId) ~= "string" and chance > 15 then
                            for petName, enumId in pairs(PetsEnum) do
                                if enumId == petId then
                                    table.insert(commonPets, { id = tostring(enumId) .. "-1", chance = chance })
                                    break
                                end
                            end
                        end
                    end
                    KServices.EggService.RF.purchaseEgg:InvokeServer(SelectedEggValue, hatchAmount, false)
                    if #commonPets > 0 then
                        local randomPet = commonPets[math.random(1, #commonPets)]
                        pcall(function()
                            KServices.GoldMachineService.RF.craft:InvokeServer(randomPet.id, 5)
                        end)
                    end
                end
                task.wait(1)
            end
        end)
    end

    if questName == "Kill Bosses" or questName == "Win Battles" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                if not Tabs.AutoFarm.Elements.AutoFightToggle.Value then
                    Tabs.AutoFarm.Elements.AutoFightToggle:SetValue(true)
                end
                if questData.Progress >= questData.Goal then
                    Tabs.AutoFarm.Elements.AutoFightToggle:SetValue(false)
                    break
                end
                task.wait(1)
            end
        end)
    end

    if questName == "Open Sword Chests" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                pcall(function()
                    KServices.SwordCrateService.RF.open:InvokeServer(ChestDropdown.Value or "W1Z1")
                end)
                task.wait(1)
            end
        end)
    end

    if questName == "Hatch Eggs" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                pcall(function()
                    KServices.EggService.RF.purchaseEgg:InvokeServer(SelectedEggValue or "W1_Z1", hatchAmount or 1, false)
                end)
                task.wait(1)
            end
        end)
    end

    if questName == "Open Gifts" then
        task.spawn(function()
            while autoCompleteEnabled and not questData.Completed do
                local ok, BackpackInventoryController = pcall(function()
                    return require(Services.StarterPlayer.StarterPlayerScripts.Client.Controllers.Shared:GetChildren()[13].Backpack.BackpackInventoryController)
                end)
                if ok and BackpackInventoryController then
                    local giftCategory = BackpackInventoryController.Amounts.GiftConsumables or {}
                    local maxAmount, bestGiftBag = 0, nil
                    for itemName, data in pairs(giftCategory) do
                        if type(data) == "table" then
                            for nestedName, nestedAmount in pairs(data) do
                                if nestedAmount > maxAmount then maxAmount, bestGiftBag = nestedAmount, nestedName end
                            end
                        else
                            if data > maxAmount then maxAmount, bestGiftBag = data, itemName end
                        end
                    end
                    if bestGiftBag then
                        local giftsToOpen = math.max(0, (questData.Goal - (questData.Progress or 0)))
                        if giftsToOpen > 0 and maxAmount > 0 then
                            pcall(function()
                                KServices.GiftBagService.RF.openGift:InvokeServer(bestGiftBag, giftsToOpen)
                            end)
                        end
                    end
                end
                task.wait(1)
            end
        end)
    end
end

QuestSection:AddToggle("AutoCompleteQuest", {
    Title = "Auto Complete Quest",
    Description = "Automatically complete selected quests",
    Default = false,
    Callback = function(enabled)
        autoCompleteEnabled = enabled
        if enabled then
            task.spawn(function()
                while autoCompleteEnabled do
                    for title, isSelected in pairs(selectedQuests) do
                        if isSelected then
                            local questId = questMap[title]
                            local questData = getQuestData(questId)
                            if questData and not questData.Completed then
                                completeQuest(title, questData)
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

local questInfoParagraph = QuestSection:AddParagraph("QuestInfo", {
    Title = "Selected Quests Progress",
    Content = "Select quests to see progress",
})

task.spawn(function()
    while true do
        local progressEntries, progressText = {}, ""
        for title, isSelected in pairs(selectedQuests) do
            if isSelected then
                local questId = questMap[title]
                local questData = getQuestData(questId)
                if questData then
                    table.insert(progressEntries, { title = title, text = string.format("%s: %d/%d (Active Quest)", title, questData.Progress or 0, questData.Goal or 0) })
                else
                    table.insert(progressEntries, { title = title, text = title .. " (Not Currently Active)" })
                end
            end
        end
        table.sort(progressEntries, function(a, b) return a.title < b.title end)
        for _, entry in ipairs(progressEntries) do progressText ..= entry.text .. "\n" end
        questInfoParagraph:SetValue(progressText ~= "" and progressText or "No quests selected")
        task.wait(5)
    end
end)

-- =============== Teleport ===============
local TeleportSection = Tabs.Teleport:AddSection("Breakable Spawns")
local breakablesFolder = Services.Workspace:WaitForChild("Core_Game"):WaitForChild("Breakables")

local function addSpawnButtons(parent, prefix)
    prefix = prefix or ""
    for _, child in pairs(parent:GetChildren()) do
        local path = prefix .. child.Name
        if child.Name == "Spawn" then
            local world, zone = string.match(path, "World(%d+)%.(%d+)%.Spawn")
            local buttonTitle = (world and zone) and ("World " .. world .. " Zone " .. zone) or path
            TeleportSection:AddButton({
                Title = buttonTitle,
                Description = "Teleport to " .. buttonTitle,
                Callback = function()
                    local character = LocalPlayer.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(child.Position) end
                end
            })
        end
        if #child:GetChildren() > 0 then
            addSpawnButtons(child, path .. ".")
        end
    end
end
addSpawnButtons(breakablesFolder)

-- =============== Machines (Gold) ===============
local MachinesSection = Tabs.Machines:AddSection("Gold Machine")

local TierNames = {}
for name, number in pairs(ItemTiersEnum) do TierNames[number] = name end

local function collectUnlockedTier1PetsFromGui()
    local petDataStore = PetController.Pets
    local gui = LocalPlayer.PlayerGui
    local inventory = gui.GameUI.MainFrames.Inventory.Inner.Holder.Inner.Pages.Pets.Contents.Contents.Inventory
    local equippedInventory = gui.GameUI.MainFrames.Inventory.Inner.Holder.Inner.Pages.Pets.Contents.Contents.Equipped_Inventory

    local pets, seenNames = {}, {}

    local function collect(folder)
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("ImageButton") then
                local id = child:GetAttribute("ID")
                local tier = child:GetAttribute("Tier")
                if id and tier and tonumber(tier) == 1 then
                    local fullKey = id .. "-" .. tier
                    local petData = petDataStore[fullKey]
                    if petData and petData.L == false then
                        local guiName = string.match(child.Name, "^nil%-(.-)%-.") or "Unknown"
                        local tierName = TierNames[tonumber(tier)] or "Unknown"
                        local fullName = (tierName ~= "Normal" and tierName .. " " or "") .. guiName
                        if not seenNames[fullName] then
                            seenNames[fullName] = true
                            table.insert(pets, { Name = fullName, Quantity = petData.Q or 0, ID = id, Tier = tonumber(tier) })
                        end
                    end
                end
            end
        end
    end

    collect(inventory)
    collect(equippedInventory)
    return pets
end

local unlockedTier1Pets = collectUnlockedTier1PetsFromGui()

local function getPetNames()
    local petNames, nameSet = {}, {}
    for _, pet in ipairs(unlockedTier1Pets) do
        if not nameSet[pet.Name] then
            table.insert(petNames, pet.Name)
            nameSet[pet.Name] = true
        end
    end
    return petNames
end

local petInfoParagraph = MachinesSection:AddParagraph("PetInfo", {
    Title = "Pet Info",
    Content = "Selected Pets",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updatePetInfoDisplay(selectedNamesDict, previousSelection)
    unlockedTier1Pets = collectUnlockedTier1PetsFromGui()
    local lines, nameSet = {}, {}
    for selectedName, isSelected in pairs(selectedNamesDict) do
        if isSelected and not nameSet[selectedName] then
            for _, pet in ipairs(unlockedTier1Pets) do
                if pet.Name == selectedName then
                    table.insert(lines, string.format("%s - %dx", pet.Name, pet.Quantity))
                    nameSet[selectedName] = true
                    break
                end
            end
        end
    end
    petInfoParagraph:SetValue(#lines > 0 and table.concat(lines, "\n") or "Select pets to see their name and quantity.")
end

local previousSelection = {}
local petDropdown = MachinesSection:AddDropdown("UnlockedTier1PetsDropdown", {
    Title = "Select Pets to turn Golden",
    Description = "Select unlocked pets.",
    Values = getPetNames(),
    Multi = true,
    Default = {},
    Callback = function(selectedNamesDict)
        updatePetInfoDisplay(selectedNamesDict, previousSelection)
        previousSelection = {}
        for name, isSelected in pairs(selectedNamesDict) do previousSelection[name] = isSelected end
    end
})

MachinesSection:AddButton({
    Title = "Refresh Pet List",
    Description = "Update the list of available pets",
    Callback = function()
        unlockedTier1Pets = collectUnlockedTier1PetsFromGui()
        petDropdown:SetValues(getPetNames())
        local currentSelection = petDropdown.Value or {}
        updatePetInfoDisplay(currentSelection, previousSelection)
        previousSelection = {}
        for name, isSelected in pairs(currentSelection) do previousSelection[name] = isSelected end
    end
})

local autoGoldEnabled = false
local autoGoldConn
MachinesSection:AddToggle("AutoGoldPets", {
    Title = "Auto Gold Pets",
    Description = "Automatically gold selected pets (if enough pets are owned).",
    Default = false,
    Callback = function(enabled)
        autoGoldEnabled = enabled
        if enabled then
            autoGoldConn = Services.RunService.Heartbeat:Connect(function()
                if not autoGoldEnabled then return end
                local selectedPets = petDropdown.Value or {}
                for petName, isSelected in pairs(selectedPets) do
                    if isSelected then
                        for _, pet in ipairs(unlockedTier1Pets) do
                            if pet.Name == petName and pet.Quantity >= 5 then
                                local petId = pet.ID .. "-" .. pet.Tier
                                pcall(function()
                                    KServices.GoldMachineService.RF.craft:InvokeServer(petId, 5)
                                end)
                                break
                            end
                        end
                    end
                end
                task.wait(1)
            end)
        else
            if autoGoldConn then autoGoldConn:Disconnect() autoGoldConn = nil end
        end
    end
})

spawn(function()
    while true do
        local currentSelection = petDropdown.Value or {}
        if currentSelection and next(currentSelection) then
            updatePetInfoDisplay(currentSelection, previousSelection)
        end
        task.wait(3)
    end
end)

-- =============== Gardening ===============
local Plots = Tabs.Plant:AddSection("Garden Plots")
local isBuyingPlots = false

Plots:AddToggle("AutoBuyPlot", {
    Title = "Auto Buy Plot(s)",
    Description = "Automatically buy affordable plots.",
    Default = false,
    Callback = function(enabled)
        isBuyingPlots = enabled
        if enabled then
            task.spawn(function()
                while isBuyingPlots do
                    local success, gems = pcall(function()
                        local textLabel = LocalPlayer.PlayerGui.GameUI.HUDS.Top_Middle.Inner.Currency:GetChildren()[14].TextLabel
                        local text = textLabel.Text
                        return tonumber(text:gsub(",", ""))
                    end)
                    local currentGems = success and gems or 0

                    local purchased = DataController:GetValue({ "GardenPlots", "Purchased" }) or {}
                    local missingPlots = {}
                    for plotName in pairs(PlotData.Plots) do
                        if not purchased[plotName] then table.insert(missingPlots, plotName) end
                    end
                     table.sort(missingPlots)

                    if #missingPlots > 0 then
                        local nextPlotName = missingPlots[1]
                        local nextPlotPrice = PlotData.Prices[#purchased + 1]
                        if currentGems >= nextPlotPrice then
                            pcall(function() KServices.PlotService.RF.purchaseSlot:InvokeServer(nextPlotName) end)
                            task.wait(1)
                        else
                            task.wait(5)
                        end
                    else
                        task.wait(5)
                    end
                end
            end)
        end
    end
})

local AutoPlant = Tabs.Plant:AddSection("Auto Plant")

local allSeedNames = {}
for seedName in pairs(SeedData) do table.insert(allSeedNames, seedName) end
 table.sort(allSeedNames)

local selectedSeedsToPlant = {}
AutoPlant:AddDropdown("SelectSeedsToPlant", {
    Title = "Select Seeds to Plant",
    Description = "These will be planted in available plots.",
    Values = allSeedNames,
    Multi = true,
    Default = {},
    Callback = function(selected)
        selectedSeedsToPlant = {}
        for seedName, isSelected in pairs(selected) do if isSelected then table.insert(selectedSeedsToPlant, seedName) end end
    end
})

local autoPlantEnabled = false
local autoPlantThread

AutoPlant:AddToggle("AutoPlant", {
    Title = "Auto Plant Seeds",
    Description = "Automatically plant selected seeds in available plots.",
    Default = false,
    Callback = function(enabled)
        autoPlantEnabled = enabled
        if enabled then
            autoPlantThread = task.spawn(function()
                while autoPlantEnabled do
                    local seeds = BackpackController:get(BackpackCategory.Seeds)
                    local plantsData = DataController:GetValue({ "GardenPlots", "Plants" }) or {}
                    local purchasedPlots = DataController:GetValue({ "GardenPlots", "Purchased" }) or {}

                    local availablePlots = {}
                    for plotName in pairs(purchasedPlots) do
                        local plotPlants = plantsData[plotName]
                        local count = 0
                        if type(plotPlants) == "table" then
                            for _ in pairs(plotPlants) do count += 1 end
                        end
                        if count < 10 then
                            table.insert(availablePlots, { name = plotName, count = count })
                        end
                    end
                     table.sort(availablePlots, function(a, b) return a.count < b.count end)

                    local planted = false
                    if #availablePlots > 0 then
                        for _, seedName in ipairs(selectedSeedsToPlant) do
                            if seeds[seedName] and seeds[seedName] > 0 then
                                for _, plot in ipairs(availablePlots) do
                                    pcall(function()
                                        KServices.PlantService.RF.plant:InvokeServer(plot.name, seedName, { 1, 1 })
                                    end)
                                    planted = true
                                    task.wait(0.5)
                                    break
                                end
                            end
                        end
                    end

                    task.wait(planted and 1 or 5)
                end
            end)
        else
            if autoPlantThread then task.cancel(autoPlantThread) autoPlantThread = nil end
        end
    end
})

local AutoHarvest = Tabs.Plant:AddSection("Auto Harvest")

local allPlotNames = {}
for plotName in pairs(PlotData.Plots) do table.insert(allPlotNames, plotName) end
 table.sort(allPlotNames)

AutoHarvest:AddParagraph("Note", {
    Title = "Note",
    Content = "The plots won't visually show as harvested until you rejoin, but you will still gain the items and continue to be able to plant.",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local selectedPlotsToHarvest = {}
AutoHarvest:AddDropdown("SelectPlotsToHarvest", {
    Title = "Select Plots to Auto Harvest",
    Description = "Choose plots to auto harvest (multi-select).",
    Values = allPlotNames,
    Multi = true,
    Default = {},
    Callback = function(selected) selectedPlotsToHarvest = selected or {} end
})

local autoHarvestEnabled = false
local autoHarvestThread

AutoHarvest:AddToggle("AutoHarvest", {
    Title = "Auto Harvest",
    Description = "Automatically harvests the selected plots.",
    Default = false,
    Callback = function(enabled)
        autoHarvestEnabled = enabled
        if enabled then
            autoHarvestThread = task.spawn(function()
                while autoHarvestEnabled do
                    for plotName, isSelected in pairs(selectedPlotsToHarvest) do
                        if isSelected then
                            pcall(function() KServices.PlotService.RF.harvest:InvokeServer(plotName) end)
                            task.wait(0.5)
                        end
                    end
                    task.wait(2)
                end
            end)
        else
            if autoHarvestThread then task.cancel(autoHarvestThread) autoHarvestThread = nil end
        end
    end
})

-- Auto Buy Seeds
local AutoBuySeeds = Tabs.Plant:AddSection("Auto Buy Seeds")

local seedDropdownValues = {}
for seedName in pairs(SeedData) do seedDropdownValues[seedName] = seedName end

local selectedSeedToBuy
local seedPurchaseAmount = 1
local autoBuySeedsEnabled = false
local autoBuySeedsThread

AutoBuySeeds:AddDropdown("SelectSeedToBuy", {
    Title = "Select Seed",
    Description = "Choose which seed to purchase.",
    Values = seedDropdownValues,
    Multi = false,
    Default = next(seedDropdownValues),
    Callback = function(selected) selectedSeedToBuy = selected end
})

AutoBuySeeds:AddInput("SeedPurchaseAmount", {
    Title = "Purchase Amount",
    Description = "The number of seeds you wish\nto buy.",
    Placeholder = "1",
    Numeric = true,
    Default = "1",
    Callback = function(value)
        local num = tonumber(value)
        seedPurchaseAmount = (num and num > 0) and math.floor(num) or 1
    end
})

AutoBuySeeds:AddButton({
    Title = "Buy Selected Seeds",
    Description = "Purchases the selected seed the chosen number of times.",
    Callback = function()
        if not selectedSeedToBuy then return end
        autoBuySeedsEnabled = true
        autoBuySeedsThread = task.spawn(function()
            for _ = 1, seedPurchaseAmount do
                if not autoBuySeedsEnabled then break end
                pcall(function() KServices.SeedStoreService.RF.purchase:InvokeServer(selectedSeedToBuy) end)
                task.wait(0.5)
            end
            autoBuySeedsEnabled = false
            autoBuySeedsThread = nil
        end)
    end
})

AutoBuySeeds:AddButton({
    Title = "Emergency Stop Buying",
    Description = "Force stops seed purchases instantly.",
    Callback = function()
        autoBuySeedsEnabled = false
        if autoBuySeedsThread then task.cancel(autoBuySeedsThread) autoBuySeedsThread = nil end
    end
})

-- =============== Potion Crafting ===============
local AutoPotionSection = Tabs.Potion:AddSection("Potion Crafting")

local function potionNameToIdTier(fullName)
    local enumKey, displayName, roman = fullName:match("^([%w_]+)%s+%((.+)%)%s+([IVX]+)$")
    if not enumKey then
        displayName, roman = fullName:match("(.+) ([IVX]+)$")
        if displayName then enumKey = nil end
    end
    if not roman then return nil, nil end
    local tier = romanToNumber(roman)

    if enumKey and PotionTypes[enumKey] then return PotionTypes[enumKey], tier end
    if displayName then
        local mapped
        for k, v in pairs(PotionTypes) do
            local pd = Potions[v]
            if pd and pd.Name == displayName then mapped = v break end
        end
        if mapped then return mapped, tier end
    end
    return nil, nil
end

local function getPotionsList()
    local allPotions = {}
    local storage = PotionController.Storage or {}
    for potionId, tiers in pairs(storage) do
        local enumKey = ""; local realName = (Potions[potionId] and Potions[potionId].Name) or "Unknown"
        for k, v in pairs(PotionTypes) do if v == potionId then enumKey = k break end end
        for tier, amount in pairs(tiers) do
            if typeof(tier) == "string" then tier = tonumber(tier) or tier end
            if amount and amount > 0 then
                local name = string.format("%s (%s) %s", enumKey ~= "" and enumKey or tostring(potionId), realName, RomanModule.NumberToRoman(tonumber(tier) or 1))
                table.insert(allPotions, { name = name, id = potionId, tier = tier, amount = amount, enumKey = enumKey ~= "" and enumKey or tostring(potionId), realName = realName })
            end
        end
    end
    table.sort(allPotions, function(a, b)
        if a.enumKey == b.enumKey then return (tonumber(a.tier) or 0) < (tonumber(b.tier) or 0) end
        return a.enumKey < b.enumKey
    end)
    return allPotions
end

local function getPotionNames()
    local names = {}
    for _, potion in ipairs(getPotionsList()) do table.insert(names, potion.name) end
    return names
end

local selectedPotions = {}
local potionCraftCount = 4 -- in base items; input multiplies by 4

local potionInfoParagraph = AutoPotionSection:AddParagraph("PotionInfo", {
    Title = "Potion Crafting Info",
    Content = "Select potions to see crafting information",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updatePotionInfo(selected)
    if not selected or not next(selected) then
        potionInfoParagraph:SetValue("Select potions to see crafting information")
        return
    end
    local storage = PotionController.Storage or {}
    local infoText = ""
    for potionName, isSelected in pairs(selected) do
        if isSelected then
            local potionId, tier = potionNameToIdTier(potionName)
            if not potionId then
                infoText ..= "Unable to find data for " .. potionName .. "\n\n"
            else
                local amount = storage[potionId] and (storage[potionId][tier] or storage[potionId][tostring(tier)]) or 0
                local maxCraftable = math.floor(amount / 4)
                local nextTier = (tonumber(tier) or 1) + 1
                local tierUnlocked = not ((nextTier == 3 and not tier3Unlocked) or (nextTier == 4 and not tier4Unlocked) or (nextTier > 4))
                infoText ..= string.format("%s:\n• Current amount: %d\n• Can craft: %s\n• Max craftable: %d\n• Crafting Tier unlocked: %s\n\n",
                    potionName, amount, (maxCraftable >= 1 and "Yes" or "No"), maxCraftable, (tierUnlocked and "Yes" or "No (crafting won't work)"))
            end
        end
    end
    potionInfoParagraph:SetValue(infoText ~= "" and infoText or "No valid potions selected")
end

local potionDropdown = AutoPotionSection:AddDropdown("PotionSelect", {
    Title = "Select Potions",
    Description = "Choose which potions to craft (multi-select)",
    Values = getPotionNames(),
    Multi = true,
    Default = {},
    Callback = function(value) selectedPotions = value updatePotionInfo(value) end
})

AutoPotionSection:AddInput("CraftAmount", {
    Title = "Craft Amount",
    Description = "Number of potions to craft",
    Placeholder = "--",
    Numeric = true,
    Default = "",
    Callback = function(value)
        local num = tonumber(value)
        potionCraftCount = (num and num > 0) and math.floor(num * 4) or 4
    end
})

AutoPotionSection:AddButton({
    Title = "Craft Selected Potions",
    Description = "Craft the selected amount of each selected potion",
    Callback = function()
        if not next(selectedPotions) then return end
        for potionName, isSelected in pairs(selectedPotions) do
            if isSelected then
                local potionId, tier = potionNameToIdTier(potionName)
                if potionId and tier then
                    pcall(function() KServices.PotionUpgradeService.RF.upgrade:InvokeServer(potionId, tier, potionCraftCount) end)
                    task.wait(0.2)
                end
            end
        end
        task.wait(0.5)
        updatePotionInfo(selectedPotions)
    end
})

AutoPotionSection:AddButton{
    Title = "Craft All",
    Description = "Craft all your selected potions.",
    Callback = function()
        if not next(selectedPotions) then return end
        local storage = PotionController.Storage or {}
        local potionsToCraft = {}
        for potionName, isSelected in pairs(selectedPotions) do
            if isSelected then
                local potionId, tier = potionNameToIdTier(potionName)
                if potionId and tier then
                    local amount = (storage[potionId] and (storage[potionId][tier] or storage[potionId][tostring(tier)])) or 0
                    if amount > 0 then table.insert(potionsToCraft, { id = potionId, tier = tier, amount = amount, name = potionName }) end
                end
            end
        end
        if #potionsToCraft == 0 then return end
        Window:Dialog{
            Title = "Confirm Crafting",
            Content = ("Are you sure you want to craft all of your selected potions?"),
            Buttons = {
                { Title = "Confirm", Callback = function()
                    for _, potion in ipairs(potionsToCraft) do
                        pcall(function() KServices.PotionUpgradeService.RF.upgrade:InvokeServer(potion.id, potion.tier, potion.amount) end)
                        task.wait(0.2)
                    end
                    task.wait(0.5)
                    updatePotionInfo(selectedPotions)
                end },
                { Title = "Cancel", Callback = function() end }
            }
        }
    end
}

-- Active Potions Section
local ActivePotionsSection = Tabs.Potion:AddSection("Active Potions")
local activePotionsParagraph = ActivePotionsSection:AddParagraph("ActivePotions", {
    Title = "Current Active Potions",
    Content = "Loading...",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updateActivePotions()
    local activeList = {}
    if PotionController.Active then
        for potionId, tiers in pairs(PotionController.Active) do
            for tier, duration in pairs(tiers) do
                if typeof(tier) == "string" then tier = tonumber(tier) or tier end
                if duration and duration > 0 then
                    local enumKey = ""; local realName = (Potions[potionId] and Potions[potionId].Name) or "Unknown"
                    for k, v in pairs(PotionTypes) do if v == potionId then enumKey = k break end end
                    local name = string.format("%s (%s) %s", enumKey ~= "" and enumKey or tostring(potionId), realName, RomanModule.NumberToRoman(tonumber(tier) or 1))
                    table.insert(activeList, { name = name, duration = duration, sortKey = string.lower(enumKey ~= "" and enumKey or tostring(potionId)) .. string.format("%03d", tonumber(tier) or 0) })
                end
            end
        end
    end
    table.sort(activeList, function(a, b) return a.sortKey < b.sortKey end)
    local activeText = ""
    if #activeList == 0 then
        activeText = "No active potions"
    else
        for _, potion in ipairs(activeList) do activeText ..= potion.name .. ": " .. math.floor(potion.duration) .. "s remaining\n" end
    end
    activePotionsParagraph:SetValue(activeText)
end

updateActivePotions()

task.spawn(function()
    while true do
        task.wait(15)
        updateActivePotions()
    end
end)

-- =============== Enchantment Crafting ===============
local AutoEnchantSection = Tabs.Enchant:AddSection("Enchantment Crafting")

local function enchantNameToIdTier(fullName)
    local enumKey, displayName, roman = fullName:match("^([%w_]+)%s+%((.+)%)%s+([IVX]+)$")
    if not enumKey then
        displayName, roman = fullName:match("(.+) ([IVX]+)$")
        if displayName then enumKey = nil end
    end
    if not roman then return nil, nil end
    local tier = romanToNumber(roman)

    if enumKey and EnchantmentTypes[enumKey] then return EnchantmentTypes[enumKey], tier end
    if displayName then
        for id, data in pairs(Enchantments) do
            if data.Name == displayName then return id, tier end
        end
    end
    return nil, nil
end

local function getEnchantmentNames()
    local names = {}
    local storage = EnchantmentController.Storage or {}
    local list = {}
    for enchantId, tiers in pairs(storage) do
        local enumKey = ""; local realName = (Enchantments[enchantId] and Enchantments[enchantId].Name) or "Unknown"
        for k, v in pairs(EnchantmentTypes) do if v == enchantId then enumKey = k break end end
        for tier, amount in pairs(tiers) do
            if typeof(tier) == "string" then tier = tonumber(tier) or tier end
            if amount and amount > 0 then
                local name = string.format("%s (%s) %s", enumKey ~= "" and enumKey or tostring(enchantId), realName, RomanModule.NumberToRoman(tonumber(tier) or 1))
                table.insert(list, { name = name, enumKey = enumKey ~= "" and enumKey or tostring(enchantId), tier = tier })
            end
        end
    end
    table.sort(list, function(a, b)
        if a.enumKey == b.enumKey then return (tonumber(a.tier) or 0) < (tonumber(b.tier) or 0) end
        return a.enumKey < b.enumKey
    end)
    for _, e in ipairs(list) do table.insert(names, e.name) end
    return names
end

local selectedEnchantments = {}
local enchantCraftCount = 5 -- base items; input multiplies by 5

local enchantInfoParagraph = AutoEnchantSection:AddParagraph("EnchantInfo", {
    Title = "Enchantment Crafting Info",
    Content = "Select enchantments to see crafting information",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updateEnchantInfo(selected)
    if not selected or not next(selected) then
        enchantInfoParagraph:SetValue("Select enchantments to see crafting information")
        return
    end
    local storage = EnchantmentController.Storage or {}
    local infoText = ""
    for enchantName, isSelected in pairs(selected) do
        if isSelected then
            local enchantId, tier = enchantNameToIdTier(enchantName)
            if not enchantId then
                infoText ..= "Unable to find data for " .. enchantName .. "\n\n"
            else
                local amount = storage[enchantId] and (storage[enchantId][tier] or storage[enchantId][tostring(tier)]) or 0
                local maxCraftable = math.floor(amount / 5)
                local nextTier = (tonumber(tier) or 1) + 1
                local tierUnlocked = not ((nextTier == 3 and not tier3Unlocked) or (nextTier == 4 and not tier4Unlocked) or (nextTier > 4))
                infoText ..= string.format("%s:\n• Current amount: %d\n• Can craft: %s\n• Max craftable: %d\n• Crafting Tier unlocked: %s\n\n",
                    enchantName, amount, (maxCraftable >= 1 and "Yes" or "No"), maxCraftable, (tierUnlocked and "Yes" or "No (crafting won't work)"))
            end
        end
    end
    enchantInfoParagraph:SetValue(infoText ~= "" and infoText or "No valid enchantments selected")
end

local enchantDropdown = AutoEnchantSection:AddDropdown("EnchantSelect", {
    Title = "Select Enchantments",
    Description = "Choose which enchantments to craft (multi-select)",
    Values = getEnchantmentNames(),
    Multi = true,
    Default = {},
    Callback = function(value) selectedEnchantments = value updateEnchantInfo(value) end
})

AutoEnchantSection:AddInput("EnchantCraftAmount", {
    Title = "Craft Amount",
    Description = "Number of enchants to upgrade",
    Placeholder = "--",
    Numeric = true,
    Default = "",
    Callback = function(value)
        local num = tonumber(value)
        enchantCraftCount = (num and num > 0) and math.floor(num * 5) or 5
    end
})

AutoEnchantSection:AddButton({
    Title = "Craft Selected Enchantments",
    Description = "Craft the selected amount of each selected enchantment",
    Callback = function()
        if not next(selectedEnchantments) then return end
        for enchantName, isSelected in pairs(selectedEnchantments) do
            if isSelected then
                local enchantId, tier = enchantNameToIdTier(enchantName)
                if enchantId and tier then
                    pcall(function() KServices.EnchantmentUpgradeService.RF.upgrade:InvokeServer(enchantId, tier, enchantCraftCount) end)
                    task.wait(0.2)
                end
            end
        end
        task.wait(0.5)
        updateEnchantInfo(selectedEnchantments)
    end
})

AutoEnchantSection:AddButton({
    Title = "Craft All",
    Description = "Craft all your selected enchantments.",
    Callback = function()
        if not next(selectedEnchantments) then return end
        local storage = EnchantmentController.Storage or {}
        local enchantsToCraft = {}
        for enchantName, isSelected in pairs(selectedEnchantments) do
            if isSelected then
                local enchantId, tier = enchantNameToIdTier(enchantName)
                if enchantId and tier then
                    local amount = (storage[enchantId] and (storage[enchantId][tier] or storage[enchantId][tostring(tier)])) or 0
                    if amount > 0 then table.insert(enchantsToCraft, { id = enchantId, tier = tier, amount = amount, name = enchantName }) end
                end
            end
        end
        if #enchantsToCraft == 0 then return end
        Window:Dialog({
            Title = "Confirm Crafting",
            Content = ("Are you sure you want to craft all of your selected enchantments?"),
            Buttons = {
                { Title = "Confirm", Callback = function()
                    for _, enchant in ipairs(enchantsToCraft) do
                        pcall(function() KServices.EnchantmentUpgradeService.RF.upgrade:InvokeServer(enchant.id, enchant.tier, enchant.amount) end)
                        task.wait(0.2)
                    end
                    task.wait(0.5)
                    updateEnchantInfo(selectedEnchantments)
                end },
                { Title = "Cancel", Callback = function() end }
            }
        })
    end
})

AutoEnchantSection:AddButton({
    Title = "Refresh Enchantment List",
    Description = "Update the list of available enchantments",
    Callback = function()
        enchantDropdown:SetValues(getEnchantmentNames())
        updateEnchantInfo(selectedEnchantments)
    end
})

-- =============== Minigames ===============
local minigameKeys = 0
local MinigamesStatus = Tabs.Minigames:AddParagraph("MinigameKeys", {
    Title = "Minigame Keys",
    Content = "Loading minigame key count...",
    TitleAlignment = "Middle",
    ContentAlignment = Enum.TextXAlignment.Left
})

local function updateMinigameKeyCount()
    local function getCurrencyAmount(category, currencyType)
        if BackpackController and BackpackController.get then
            return BackpackController:get(category, currencyType) or 0
        end
        return 0
    end
    minigameKeys = getCurrencyAmount(BackpackCategory.BackpackCurrency, BackpackCurrencyTypes.MinigameKey)
    MinigamesStatus:SetValue("🔑 Minigame Keys: " .. minigameKeys)
end

updateMinigameKeyCount()

task.spawn(function()
    while true do
        task.wait(5)
        updateMinigameKeyCount()
    end
end)

local ObbySection = Tabs.Minigames:AddSection("Parkour Obby")

local autoObbyEnabled = false
local autoObbyThread

ObbySection:AddToggle("AutoObby", {
    Title = "Auto Complete Obby",
    Description = "Automatically completes the parkour Obby. If you get stuck when you turn this toggle off, respawn.",
    Default = false,
    Callback = function(enabled)
        autoObbyEnabled = enabled
        if enabled and minigameKeys > 0 then
            autoObbyThread = task.spawn(function()
                while autoObbyEnabled do
                    pcall(function() KServices.ObbyService.RF.enter:InvokeServer("OBBY_W2Z3") end)
                    task.wait(0.1)
                    local function teleportToEnd()
                        local obby = Services.Workspace:FindFirstChild("Obby")
                        local node = obby and obby:FindFirstChild("OBBY_W2Z3")
                        local endPart = node and node:FindFirstChild("Important") and node.Important:FindFirstChild("End")
                        local character = LocalPlayer.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        if endPart and hrp then
                            hrp.CFrame = endPart.CFrame + Vector3.new(0, 1, 0)
                            return true
                        end
                        return false
                    end
                    local success = teleportToEnd()
                    if not success then
                        for _ = 1, 2 do
                            task.wait(0.3)
                            if teleportToEnd() then break end
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            if autoObbyThread then task.cancel(autoObbyThread) autoObbyThread = nil end
        end
    end
})

-- =============== Gifts & Vending ===============
local AutoClaimSection = Tabs.Gifts:AddSection("Auto Claim")

local autoClaimEnabled = false
local autoClaimThread

AutoClaimSection:AddToggle("AutoClaimGifts", {
    Title = "Auto Claim Gifts",
    Description = "Automatically claim availble gifts (won't visually show as claimed until you rejoin).",
    Default = false,
    Callback = function(enabled)
        autoClaimEnabled = enabled
        if enabled then
            autoClaimThread = task.spawn(function()
                while autoClaimEnabled do
                    for i = 1, 12 do
                        pcall(function() KServices.TimedRewardsService.RF.claim:InvokeServer(i) end)
                        task.wait(0.5)
                    end
                    task.wait(20)
                end
            end)
        else
            if autoClaimThread then task.cancel(autoClaimThread) autoClaimThread = nil end
        end
    end
})

local autoDailyEnabled = false
local autoDailyThread

AutoClaimSection:AddToggle("AutoDailyDaily", {
    Title = "Auto Claim Daily Rewards",
    Description = "Automatically claim daily rewards (won't visually show as claimed until you rejoin).",
    Default = false,
    Callback = function(enabled)
        autoDailyEnabled = enabled
        if enabled then
            autoDailyThread = task.spawn(function()
                while autoDailyEnabled do
                    for i = 1, 7 do
                        pcall(function() KServices.DailyService.RF.claim:InvokeServer(i) end)
                        task.wait(1)
                    end
                    task.wait(30)
                end
            end)
        else
            if autoDailyThread then task.cancel(autoDailyThread) autoDailyThread = nil end
        end
    end
})

local vending = Tabs.Gifts:AddSection("Vending Machines")

local vendingNames, vendingKeyMap = {}, {}
for vendingKey, config in pairs(VendingMachines) do
    local world = config.World or "World?"
    local zone = config.Zone or "Zone?"
    local displayName = tostring(world) .. "_Zone" .. tostring(zone)
    table.insert(vendingNames, displayName)
    vendingKeyMap[displayName] = vendingKey
end
 table.sort(vendingNames)

local selectedVending = {}
local vendingDropdown = vending:AddDropdown("VendingSelect", {
    Title = "Select Vending Machine",
    Description = "Choose vending machines to auto buy from.",
    Values = vendingNames,
    Multi = true,
    Default = {},
    Callback = function(selected) selectedVending = selected or {} end
})

local autoBuyVendingEnabled = false
local autoBuyVendingThread

vending:AddToggle("AutoBuyVending", {
    Title = "Auto Buy",
    Description = "Automatically buys from selected vending machines until stock runs out.",
    Default = false,
    Callback = function(enabled)
        autoBuyVendingEnabled = enabled
        if enabled then
            autoBuyVendingThread = task.spawn(function()
                while autoBuyVendingEnabled do
                    for vendingName, isSelected in pairs(selectedVending) do
                        if isSelected and autoBuyVendingEnabled then
                            local vendingKey = vendingKeyMap[vendingName]
                            local config = VendingMachines[vendingKey]
                            local stock = config and config.Stock or 0
                            local purchases = 0
                            while stock > 0 and purchases < 3 and autoBuyVendingEnabled do
                                pcall(function() KServices.VendingMachineService.RF.purchase:InvokeServer(vendingKey) end)
                                purchases += 1
                                task.wait(1)
                                config = VendingMachines[vendingKey]
                                stock = config and config.Stock or 0
                            end
                        end
                    end
                    task.wait(1801)
                end
            end)
        else
            if autoBuyVendingThread then task.cancel(autoBuyVendingThread) autoBuyVendingThread = nil end
        end
    end
})

-- =============== Settings ===============
local antiafk = Tabs.Settings:AddSection("Anti AFK")
Tabs.Settings:AddButton({
    Title = "Anti Afk",
    Description = "Never get kicked for being inactive.",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/SenhorLDS/ProjectLDSHUB/refs/heads/main/Anti%20AFK"))()
    end
})

-- Managers
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes{}

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab("Settings")