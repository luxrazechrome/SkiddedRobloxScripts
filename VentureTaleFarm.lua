
--[[
    ventureAI 
    
    by saucekid (https://discord.gg/eX5k7TKN4F)
    
    CREDITS:
    - sukaretto#8874 (https://discord.gg/PFuQMWMhQQ)
    - ObscureScapter (https://v3rmillion.net/member.php?action=profile&uid=387561)
--]]

_G.safemode = _G.safemode or true

repeat wait() until game:IsLoaded()

local game = game;
local httpGet = game.HttpGet;

local quick = loadstring(httpGet(game, 'https://raw.githubusercontent.com/Belkworks/quick/master/init.lua'))();
local broom = loadstring(httpGet(game, 'https://raw.githubusercontent.com/Belkworks/broom/master/init.lua'))();
local pathing = loadstring(httpGet(game, 'https://raw.githubusercontent.com/V3N0M-Z/RBLX-SimplePath/main/src/SimplePath.lua'))(); pathing.Visualize = true

-- services.
local s = quick.Service;
local workspace = s.Workspace;
local replicatedStorage = s.ReplicatedStorage;
local runService = s.RunService;

-- indexing.
local cf, v3 = CFrame.new, Vector3.new;

local findFirstChild, waitForChild = game.FindFirstChild, game.WaitForChild;
local getChildren, getPartsByRadius = game.GetChildren, workspace.GetPartBoundsInRadius;

local create, destroy = Instance.new, game.Destroy;
local fire, fireServer = create'BindableEvent'.Fire, create'RemoteEvent'.FireServer;

local string_find = string.find;
local string_format = string.format;

local jsonE, jsonD = function(o) return game.HttpService:JSONEncode(o) end, function(o) return game.HttpService:JSONDecode(o) end

local c = game.Loaded;
local connect, cwait = c.Connect, c.Wait;
local render, step = runService.RenderStepped, runService.Stepped;

-- client.
local client = quick.User;
local character = client.Character or cwait(client.CharacterAdded);
local root = waitForChild(character, 'HumanoidRootPart');
local gyro = waitForChild(root, 'BodyGyro')
local humanoid = waitForChild(character, 'Humanoid');

local distanceFromCharacter = client.DistanceFromCharacter;
local characterPathing = pathing.new(character, {
    Costs = {
        Water = math.huge,
        Neon = math.huge
    }}, {
    TIME_VARIANCE = 0.01,
    COMPARISON_CHECKS = 2,
    JUMP_WHEN_STUCK = true
});

for i,v in pairs(getconnections(client.Idled)) do
    v:Disable()
end

if _G.safemode and game.PlaceVersion > 923 then client:Kick("\nGame Updated.\nWait For Script Update!") return end

-- things.
local map = workspace.Map;
local projectiles = workspace.Projectiles;
local rangeIndicators = workspace.RangeIndicators
local IPDFunctions = require(replicatedStorage.Modules.IPDFunctions)

-- remotes&attacking.
local remotes = replicatedStorage.Remotes;
local action = remotes.Action;

local attackRemotes = {
    Melee = action.MeleeAttack,
    Magic = action.MagicAttack,
    Bow = action.BowAttack
}
local useAbility =  action.ActivateAbility;
local dungeonVoting = remotes.UI.EndDungeon.EndOfDungeonVote;

-- weapon calculation.
local Weapons = {
    [1] = { hitDelay = 1.2, range = 100 }, 
    [2] = { hitDelay = 1.2, range = 100 }
}
local WeaponTypes = {
    Melee = {
        "Hammer",
        "Dagger",
        "Axe",
        "Spear",
        "Sword",
        "Rapier",
        "Polearm",
        "Greatsword",
        "Katana",
    },
    Bow = {
        "Bow",
        "Crossbow",
    },
    Magic   = {
        "Staff",
        "Wand",
        "Book",
    }
} do
    local function calculate(weapon)
        local weaponType = weapon.ItemType.Value;
        local weaponIndex = weapon.Name:gsub("Wep", "")
        
        local weaponTypeFolder = replicatedStorage.ItemData[weaponType];
        local weaponData = quick.find(getChildren(weaponTypeFolder), function(w) return w.Name == weapon.ItemID.Value end);
        
        local Tags = findFirstChild(weaponData, "Tags");
        local attackBoost = IPDFunctions:GetBoostValue(character, "AttackSpeedBoost");
        if Tags then
            for q, c in pairs(Tags:GetChildren()) do
                attackBoost = attackBoost + IPDFunctions:GetBoostValue(character, c.Name .. "AttackSpeedBoost")
            end
        end
                
        local attackType 
        for i,class in pairs(WeaponTypes) do
            if table.find(class, weaponType) then
                attackType = i
            end
        end
        
        local equippedWeapon = Weapons[tonumber(weaponIndex)]
        local otherWeapon = tonumber(weaponIndex) == 1 and Weapons[2] or Weapons[1]
        if weaponData and attackType then
            equippedWeapon.Type = attackType
            equippedWeapon.remote = attackRemotes[attackType]
            equippedWeapon.range = findFirstChild(weaponData, "Range") and weaponData.Range.Value or equippedWeapon.range;
            equippedWeapon.hitDelay = 1 / (weaponData.AttackSpeed.Value * 1.03 ^ (weapon.Rarity.Value - weaponData.BaseRarity.Value) * (1 + attackBoost / 100))--findFirstChild(weaponData, "HitDelay") and weaponData.HitDelay.Value * weaponData.AttackSpeed.Value / 100 or 1 / (weaponData.AttackSpeed.Value * 1.03 ^ (weapon.Rarity.Value - weaponData.BaseRarity.Value) * (1 + attackBoost / 100))

            if not otherWeapon.remote then
                for i,v in pairs(equippedWeapon) do
                    otherWeapon[i] = v
                end
            end
        else
            equippedWeapon.remote = nil
        end;
    end;
    
    local function weaponChanged(w)
        calculate(w);
        connect(w.ItemID.Changed, function() calculate(w) end);
    end;
    
    local clientEquipped = client.stats.Equipped;
    quick.each(getChildren(clientEquipped), function(v) if string_find(v.Name, 'Wep') then weaponChanged(v) end end);
    connect(clientEquipped.ChildAdded, function(v)
        if string_find(v.Name, 'Wep') then
            weaponChanged(v);
        end;
    end);
end;

-- classes.
local hostile = ({params=(function()
    local _ = OverlapParams.new()
        _.FilterDescendantsInstances = { workspace.NPCS }
        _.FilterType = Enum.RaycastFilterType.Whitelist;
    
    return _;
end)(), filtered = {
    ['GoblinBashWatermelon'] = true
}}); do
    function hostile:group()
        local parts = quick.map(getPartsByRadius(workspace, root.Position, Weapons[1].range, self.params), function(p)
            return p.Parent;
        end);
        
        return quick.uniq(quick.filter(parts, function(p) return not self.filtered[p.Name] and p.Parent == workspace.NPCS end));
    end;
    
    function hostile:nearest()
        local d, h = math.huge;
        for _, v in next, getChildren(workspace.NPCS) do
            if self.filtered[v.Name] or (not findFirstChild(v, 'HumanoidRootPart')) then continue end;

            local magnitude = distanceFromCharacter(client, v.HumanoidRootPart.Position);
            if magnitude <= d then
                d = magnitude;
                h = v;
            end
        end;
        
        return h, d;
    end;
end;


local ability = {} do
    function ability.cooldown(a)
        local attributes = findFirstChild(character, 'Attributes');
        return attributes and findFirstChild(attributes.Value, 'Cooldowns') and findFirstChild((attributes.Value).Cooldowns, string_format('Wep%dAbilityCD', a)) ~= nil;
    end;
    
    function ability:use(a)
        if (not self.cooldown(a)) then
            task.spawn(fireServer, useAbility, a);
            return true;
        end;
        return false;
    end;
end;

local function attack(group)
    local targetMap = #group > 0 and quick.map(group, function(v)
        return { TargetCharacter = v, KnockbackDirection = cf(v3(root.Position.X, v.HumanoidRootPart.Position.Y, root.Position.Z), v.HumanoidRootPart.Position).LookVector }
    end);
    
    if not targetMap then return end;
    for i = 1, 2 do
        local w = Weapons[i]
        if w.remote then
            fireServer(w.remote, i, { Targets = targetMap });
            ability:use(i);
        end
    end;
end;


-- file system.
local folderpath = [[ventureAI/]]

if makefolder then
	makefolder("ventureAI")
end

local function existsFile(name)
	if not readfile then return end
	return pcall(function()
		return readfile(folderpath .. name)
	end)
end

function load(name, settings)
	if not existsFile(name) then return end
	local _, Result = pcall(readfile, folderpath .. name);
	if _ then
		local _, Loaded = pcall(game.HttpService.JSONDecode, game.HttpService, Result);
		if _ then
	        for i, v in pairs(Loaded) do
                settings[i] = v;
                pcall(settings[i], v);
            end
		end
	end
end

function save(table, name)
	if writefile then
		writefile(folderpath .. name, jsonE(table));
	end
end

-- flags.
local autoDungeon, ignore = create'BindableEvent';
    
local flags = {
    killAura = true,
    autoDungeon = false,
    autoPotion = true,
    autoDodge = true,
    dashWarp = true,
    jumping = true
}; load("dungeon.json", flags)


-- auto execute.
client.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.Started and syn then
        syn.queue_on_teleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/luxrazechrome/SkiddedRobloxScripts/main/VentureTaleFarm.lua"))()]])
    end
end)

-- lib.
local lib = loadstring(httpGet(game, 'https://raw.githubusercontent.com/saucekid/UI-Libraries/main/ArrowsUIlib.lua'))(); do
    _G["Theme"] = {
        ["UI_Position"] = Vector2.new(50, 200),
        ["Text_Size"] = 16,
    
        ["Category_Text"] = Color3.fromRGB(255, 255, 255),
        ["Category_Back"] = Color3.fromRGB(0, 0, 0),
        ["Category_Back_Transparency"] = 0.5,
    
        ["Option_Text"] = Color3.fromRGB(255, 255, 255),
        ["Option_Back"] = Color3.fromRGB(0, 0, 0),
        ["Option_Back_Transparency"] = 0,
        ["Selected_Color"] = Color3.fromRGB(128,128,128)
    }
    
    
    if game.PlaceId == 4809447488 then 
        flags = {
            selectedDungeon = "Goblin Cave", 
            selectedDifficulty = "Easy", 
            hardCore = false
        }; load("lobby.json", flags)
        
        local dungeons, realDungeons, difficulties = 
        {"Goblin Cave", "Enchanted Forest", "Bandit Castle"}, 
        {
            ["Goblin Cave"] = "GoblinCave",
            ["Enchanted Forest"] = "EnchantedForest",
            ["Bandit Castle"] = "BanditCastle"
        }, 
        {"Easy", "Normal", "Hard", "Raid", "Endless"}
        
        local dungeonTab = lib:NewCategory("Lobby"); do
            dungeonTab:NewButton(
                'Start Solo',
                function()
                    remotes.UI.Lobby.StartLobby:FireServer(realDungeons[flags.selectedDungeon], flags.selectedDifficulty, flags.hardCore, "Solo")
                end
            );
            
            dungeonTab:NewButton(
                'Create Lobby',
                function()
                    remotes.UI.Lobby.CreateLobby:FireServer(realDungeons[flags.selectedDungeon], flags.selectedDifficulty, flags.hardCore)
                end
            );
            
            dungeonTab:NewDropdown("Dungeon", dungeons, table.find(dungeons, flags.selectedDungeon), function(option) 
                flags.selectedDungeon = option
            end)
            
            dungeonTab:NewDropdown("Difficulty", difficulties, table.find(difficulties, flags.selectedDifficulty), function(option) 
                flags.selectedDifficulty = option
            end)
            
            dungeonTab:NewToggle(
                'Hardcore',
                hardCore,
                function(state)
                    flags.hardCore = state
                end
            );
        end
        
        connect(game.Players.PlayerRemoving, function(plr)
            if plr == client then
                save(flags, "lobby.json")
            end
        end)
        return
    end

    local adTab = lib:NewCategory("ventureAI"); do
        adTab:NewToggle(
            'on/off',
            flags.autoDungeon,
            function(state)
                flags.autoDungeon = state
                fire(autoDungeon, state);
            end
        );

        adTab:NewToggle(
            'Kill Aura',
            flags.killAura,
             function(state)
                flags.killAura = state;
                coroutine.wrap(function()
                    while flags.killAura do
                        local hostiles = hostile:group();
                        attack(hostiles);
                        task.wait((#hostiles == 0 and 0) or Weapons[1].hitDelay);
                    end;
                end)()
            end
        );
    
        adTab:NewToggle(
            'Auto Potion',
            flags.autoPotion,
            function(state)
                flags.autoPotion = state
            end
        );
    
        adTab:NewToggle(
            'Auto Dodge',
            flags.autoDodge,
            function(state)
                flags.autoDodge = state
            end
        );
    
        adTab:NewToggle(
            'Dash Warp',
            flags.dashWarp,
            function(state)
                flags.dashWarp = state
            end
        );
    
        adTab:NewToggle(
            'Smart Jump',
            flags.jumping,
            function(state)
                flags.jumping = state
                characterPathing._settings.JUMP_WHEN_STUCK = state
            end
        );
    
        adTab:NewToggle(
            'Visualize Path',
            pathing.Visualize,
            function(state)
                pathing.Visualize = state
            end
        );
    end


    local miscTab = lib:NewCategory("Misc.") do
        miscTab:NewButton(
            'Join Lobby',
            function()
                game.TeleportService:Teleport(4809447488, client)
            end
        );
    end
end

do
    local mousePos
    local faceCF

    local function inAttackRadius()
        for _,indicator in pairs(rangeIndicators:GetChildren()) do
            if indicator.Name == "LingeringSpear" then continue end
            if indicator:IsA("Folder") then indicator = findFirstChild(indicator, 'Main') or indicator:FindFirstChildOfClass("BasePart") end
            
            indicator.Position = Vector3.new(indicator.Position.X, root.Position.Y, indicator.Position.Z)
            if not findFirstChild(indicator, "TouchInterest") then
                indicator.Touched:Connect(function() end) 
            end
            local touching = indicator:GetTouchingParts()
            for i,v in pairs(touching) do
		        if v.Parent == character then
		        	return true
		        end
	        end
        end
		return false
    end
    
    local function dashWarp(cf)
        if not flags.dashWarp then return end
        local res = ability:use(999);
        if res then
            task.wait(0.250);
            character:PivotTo(cf);
        end;
    end;
    
    local autoDungeon_broom = broom();
    connect(autoDungeon.Event, function(state)
        if not state then return autoDungeon_broom:clean() end;
        for _,v in pairs(map.Segments:GetDescendants()) do
            if v:IsA("BasePart") and v.Transparency < 1 and (v.Parent.Name == "Balustrade1_Angled_Variant1" or v.Parent.Name == "Balustrade1_Straight_Variant2" or not v.Name:find("Wall") and not v.Name:find("Bricks") and not v.Name:find("Floor") and not v.Parent.Name:find("Floor") and not v.Name:lower():find("coin")) then
                v.CanCollide = false
            end
        end
        
        autoDungeon_broom:GiveTask(connect(gyro:GetPropertyChangedSignal("CFrame"), function()
             pcall(function() gyro.CFrame = CFrame.new(root.Position, faceCF) end)
        end))
        
        autoDungeon_broom:GiveTask(connect(render, function()
            if not root or (humanoid and humanoid.Health == 0) then return end;
            
            local heal, dodge = (flags.autoPotion and (humanoid.Health <= humanoid.MaxHealth/2 and not ability.cooldown(6))) and true, flags.autoDodge and inAttackRadius()
            local hostile, distance = hostile:nearest();
            local gate, loot = (findFirstChild(projectiles, 'WaitingForPlayers') or findFirstChild(projectiles, 'BossWaitingForPlayers')), findFirstChild(map, 'LootPrompt', true);
            --local dungeonFailed = replicatedStorage.ControlSettings.Failed.Value;
            
            faceCF = hostile and hostile.HumanoidRootPart.Position or client:GetMouse().Hit.Position
    
            characterPathing._settings.JUMP_WHEN_STUCK = (flags.jumping and not dodge) and true or false
            
            if gate then
                root.CFrame = gate.CFrame + Vector3.yAxis;
                return;
            elseif loot then
                fireproximityprompt(loot);
                fireServer(dungeonVoting, 'ReplayDungeon');
            elseif heal then
                ability:use(6)
            elseif dodge then
                ability:use(3)
                ability:use(999)
                characterPathing:Run(root.Position + root.CFrame.rightVector * -8);
                
                mousePos = root.Position + root.CFrame.rightVector * -5
            elseif hostile then
                local waiting = findFirstChild(hostile, 'Waiting' .. hostile.Name);
                if not findFirstChild(character, 'ForceField') and (waiting or (distance >= 50)) then --[[and not (distance <= Weapons[1].range))) then]]
                    dashWarp(hostile.HumanoidRootPart.CFrame);
                end;
                
                mousePos = hostile.HumanoidRootPart.Position
                humanoid.MaxSlopeAngle = math.huge;
                
                local waterMelon = findFirstChild(workspace.NPCS, "GoblinBashWatermelon") 
                if (Weapons[1].Type == "Bow"  or Weapons[1].Type == "Magic") and waterMelon then
                    return characterPathing:Run(waterMelon:GetPivot().Position);
                end
                
                characterPathing:Run(hostile.HumanoidRootPart.Position + hostile.HumanoidRootPart.CFrame.lookVector * -math.clamp(Weapons[1].range, 0, 10));
            end;
        end));
    end);

    connect(client.CharacterAdded, function(newCharacter)
        character = newCharacter;
        root = waitForChild(newCharacter, 'HumanoidRootPart');
        gyro = waitForChild(root, "BodyGyro");
        humanoid = waitForChild(newCharacter, 'Humanoid');
        characterPathing = pathing.new(newCharacter, {
            Costs = {
                Water = math.huge,
                Neon = math.huge
            }}, {
            TIME_VARIANCE = 0.01,
            COMPARISON_CHECKS = 2,
            JUMP_WHEN_STUCK = true
        });
        if flags.autoDungeon then
            autoDungeon_broom:GiveTask(connect(gyro:GetPropertyChangedSignal("CFrame"), function()
                pcall(function() gyro.CFrame = CFrame.new(root.Position, faceCF)  end)
            end))
        end
    end);
    
    fire(autoDungeon, flags.autoDungeon);
    
    oldNamecall = hookfunction(getrawmetatable(game).__namecall, newcclosure(function(self, ...)
        local Args    = {...}
        local callMethod = getnamecallmethod()
        if callMethod == "FireServer" and self.Name == "UpdateMouseDirection" and flags.autoDungeon then
            Args[1]  = mousePos
        end
        return oldNamecall(self, unpack(Args))
    end))

    connect(game.Players.PlayerRemoving, function(plr)
        if plr == client then
            save(flags, "dungeon.json")
        end
    end)

    local DungeonGui = client.PlayerGui.DungeonClear
    connect(DungeonGui.DungeonClearLabel:GetPropertyChangedSignal("Visible"), function()
        if DungeonGui.DungeonClearLabel.Visible then
            fireServer(dungeonVoting, 'ReplayDungeon');
        end
    end)
end;
