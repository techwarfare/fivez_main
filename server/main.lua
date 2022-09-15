joinedPlayers = {}

local deadPlayers = {}

function GetClosestDeadPlayer(coords)
    local closestPlayer = -1
    local closestDistance = -1
    if #deadPlayers >= 1 then
        for k,v in pairs(deadPlayers) do
            local targetPed = GetPlayerPed(v)
            if DoesEntityExist(targetPed) and GetEntityHealth(targetPed) <= 0 then
                local pedCoords = GetEntityCoords(targetPed)
                local dist = #(pedCoords - coords)
                if closestDistance == -1 or dist < closestDistance then
                    closestDistance = dist
                    closestPlayer = v.ply
                end
            end
        end
    end

    return closestDistance, closestPlayer
end

--Event to know when a player dies
RegisterNetEvent("baseevents:onPlayerDied", function(killedBy, pos)
    local source = source
    local alreadyDead = false
    for k,v in pairs(deadPlayers) do
        if v.ply == source or v.ply == killedBy then
            print("Player is already dead", v.ply)
            alreadyDead = true
        end
    end
    --If the dead player is already dead or the killer is dead?
    if alreadyDead then return end
    if killedBy > 0 then
        local killerData = GetJoinedPlayer(killedBy)
        if killerData then
            killerData.humanity = killerData.humanity - Config.HumanityRates["killplayer"]
        end
    end
    table.insert(deadPlayers, {ply = source, died = GetGameTimer() + Config.RespawnTimer})
end)
--Thread to respawn player after certain time
Citizen.CreateThread(function()
    while true do
        if #GetPlayers() >= 1 then
            for k,v in pairs(deadPlayers) do
                if GetGameTimer() > v.died then
                    local playerData = GetJoinedPlayer(v.ply)
                    if Config.LoseItemsOnDeath then
                        if Config.DropItemsOnDeath then
                            RegisterNewInventory("deadbody:"..v.ply, "inventory", "Dead Player", playerData.characterData.inventory.weight, playerData.characterData.inventory.maxweight, playerData.characterData.inventory.maxslots, playerData.characterData.inventory.items, GetEntityCoords(GetPlayerPed(v.ply)))
                        end
                        SQL_ClearCharacterInventoryItems(playerData.characterData.Id)
                        for k,v in pairs(playerData.characterData.inventory.items) do
                            v = EmptySlot()
                        end
                    end
                    print("Respawning player", v.ply)
                    TriggerClientEvent("fivez:RespawnPlayer", v.ply)
                    playerData.characterData.health = 100
                    playerData.characterData.armor = 0
                    playerData.characterData.hunger = 100
                    playerData.characterData.thirst = 100
                    playerData.characterData.stress = 0
                    playerData.characterData.humanity = 0
                    
                    table.remove(deadPlayers, k)
                end
            end
        else
            Citizen.Wait(Config.DelayServerTick)
        end
        Citizen.Wait(1000)
    end
end)
RegisterNetEvent("fivez:RevivePlayer", function(targetPly)
    local source = source
    local reviverPed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetPly)
    local dist = #(GetEntityCoords(reviverPed) - GetEntityCoords(targetPed))
    if dist <= Config.InteractWithPlayersDistance then
        local plyDead = false
        for k,v in pairs(deadPlayers) do
            if v.ply == targetPly then
                plyDead = true
            end
        end

        if plyDead then
            local reviverData = GetJoinedPlayer(source)
            reviverData.humanity = reviverData.humanity + Config.HuamnityRates["revive"]
            local targetData = GetJoinedPlayer(targetPly)
            targetData.characterData.health = 100
            targetData.characterData.armor = 0
            targetData.characterData.hunger = 100
            targetData.characterData.thirst = 100
            targetData.characterData.stress = 0
            targetData.characterData.humanity = 0
            TriggerClientEvent("fivez:RevivePlayerCB", targetPed)
        end
    end
end)
--Stops auto-created peds spawning on default routing bucket
SetRoutingBucketPopulationEnabled(0, false)
--Restrict spawning objects to server only
SetRoutingBucketEntityLockdownMode(0, "strict")

function CheckRoutingBucket(ply)
    if GetPlayerRoutingBucket(ply) == 0 then
        return true
    end
    return false
end

--Use steam identifier to get player from joinedPlayers table
function GetJoinedPlayerWithSteam(source)
    local steamIdentifier = ""
    local identifiers = GetPlayerIdentifiers(source)

    for k,v in pairs(identifiers) do
        if string.match(v, "steam:") then
            steamIdentifier = v
            break
        end
    end

    for k,v in pairs(joinedPlayers) do
        if v.steam == steamIdentifier then
            if v.source == nil then
                v.source = tonumber(source)
            end

            return v
        end
    end
end
--Use custom id to get player from joinedPlayers table
function GetJoinedPlayerWithId(id)
    for k,v in pairs(joinedPlayers) do
        if v.Id == id then
            return v
        end
    end
end
--Use source to get player from joinedPlayers table
function GetJoinedPlayer(source)
    for k,v in pairs(joinedPlayers) do
        if v.source then
            if tonumber(v.source) == tonumber(source) then
                return v
            end
        end
    end
end

RegisterNetEvent("fivez:PlayerPedRespawned", function()
    local source = source
    local playerData = GetJoinedPlayer(source)
    if playerData then
        
    end
end)

--Triggered when a new character is created
RegisterNetEvent("fivez:NewCharacterCreated", function()
    local source = source
    SetPlayerRoutingBucket(source, 0)
    local playerData = GetJoinedPlayer(source)
    if playerData then
        playerData.playerSpawned = true
        TriggerClientEvent("fivez:LoadCharacterData", source, json.encode(playerData.characterData))
    end
end)
--Triggered when a players ped is spawned
RegisterNetEvent("fivez:PlayerPedSpawned", function()
    local source = source
    local playerData = GetJoinedPlayer(source)

    if playerData then
        if not playerData.isNew then
            playerData.playerSpawned = true
            local charAppearance = playerData.characterData.appearance
            SetPedHeadBlendData(GetPlayerPed(source), charAppearance.parents.fatherShape, charAppearance.parents.motherShape, 0, charAppearance.parents.fatherSkin, charAppearance.parents.motherSkin, 0, charAppearance.parents.shapeMix, charAppearance.parents.skinMix, 0, false)
            LoadCharacterAppearanceData(source, charAppearance)
        end
        SyncZombieStates(source)
        TriggerClientEvent("fivez:LoadInventoryMarkers", source, json.encode(GetAllInventoryMarkers()))
        if playerData.characterData.gender == 1 then
            playerData.characterData.health = playerData.characterData.health - 100
        end
        SetPedArmour(GetPlayerPed(source), playerData.characterData.armor)
        --Update last position when player ped is spawned
        --SQL_UpdateCharacterPosition(playerData.Id, GetEntityCoords(GetPlayerPed(source)))
    end
end)
--Also triggered when player ped has been spawned
AddEventHandler("entityCreated", function(handle)
    print("Entity has been created!", handle, DoesEntityExist(handle), NetworkGetNetworkIdFromEntity(handle))
    if DoesEntityExist(handle) then
        if #joinedPlayers == 1 then
            TriggerEvent("weathersync:setWeather", "blizzard", 0.0, false, false)
            Citizen.Wait(100)
            TriggerEvent("weathersync:setWeather", "foggy", 0.0, true, false)
        end
        print("Entity type", GetEntityType(handle))
        if GetEntityType(handle) == 2 then
            local damageData = {}
            for k,v in pairs(spawnedVehicles) do
                if v.veh == handle then
                    damageData = {
                        enginehealth = v.enginehealth,
                        tyres = v.tyres,
                        bodyhealth = v.bodyhealth,
                        fuellevel = v.fuellevel
                    }
                    break
                end
            end
            print("Getting vehicle damage data", damageData.tyres, damageData.enginehealth)
            TriggerClientEvent("fivez:SyncVehicleState", -1, NetworkGetNetworkIdFromEntity(handle), json.encode(damageData))
        end
    end
end)
--Triggered when a players NUI is loaded
RegisterNetEvent("fivez:NUILoaded", function()
    local source = source
    --Have to use steam identifier, since source is not server id until this point
    local playerData = GetJoinedPlayerWithSteam(source)
    if playerData.isNew then
        --Tell player to get a new spawn
        TriggerClientEvent("fivez:NewSpawn", source, playerData.characterData.gender)
        --Set the player to a routing bucket depending on how many players are joined
        SetPlayerRoutingBucket(source, #joinedPlayers+1)
        --Disable population so we don't get spam for entity created
        SetRoutingBucketPopulationEnabled(#joinedPlayers+1, false)
    elseif not playerData.isNew then
        
        TriggerClientEvent("fivez:SpawnAtLastLoc", source, playerData.characterData.gender, json.encode(playerData.characterData.lastposition))
        TriggerClientEvent("fivez:LoadCharacterData", source, json.encode(playerData.characterData))
    end
end)

RegisterNetEvent("fivez:DecayCharacter", function(runningAmount)
    --If the running amount is not 0 and the running amount isn't the config amount
    if runningAmount ~= 0 and runningAmount ~= Config.RunningDecayIncrease then print("Something fishy going on with ", GetPlayerName(source), GetJoinedPlayer(source).Id, GetPlayerIdentifiers(source)[1]) return end
    local source = source
    local playerData = GetJoinedPlayer(source)
    if playerData then
        local plyChar = playerData.characterData

        plyChar.hunger = plyChar.hunger - (Config.HungerDecay + runningAmount)
        plyChar.thirst = plyChar.thirst - (Config.ThirstDecay + runningAmount)
    end
end)

--Loop through active players
--Updates character position every 30 seconds
Citizen.CreateThread(function()
    while true do
        local players = GetPlayers()
        if #players >= 1 then
            for k,v in pairs(players) do
                local playerPed = GetPlayerPed(v)
                if DoesEntityExist(playerPed) then
                    local pedCoords = GetEntityCoords(playerPed)
                    local playerData = GetJoinedPlayer(v)
                    --If player has moved a certain distance from last position
                    if not playerData then break end
                    if playerData.characterData.lastposition then
                        local lastPos = vector3(playerData.characterData.lastposition.x, playerData.characterData.lastposition.y, playerData.characterData.lastposition.z)
                        if #(pedCoords - lastPos) > 10 then
                            SQL_UpdateCharacterPosition(playerData.Id, pedCoords)
                        end
                    else
                        playerData.characterData.lastposition = pedCoords
                    end
                end
                --Wait 0.5 seconds between players
                Citizen.Wait(500)
            end
            --30 seconds per loop for checking players coords
            Citizen.Wait(30000)
        else
            Citizen.Wait(Config.DelayServerTick)
        end
        Citizen.Wait(0)
    end
end)