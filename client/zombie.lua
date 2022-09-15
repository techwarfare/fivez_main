zombies = {}
local zombiesAttacking = {}

AddRelationshipGroup("zombie")

SetRelationshipBetweenGroups(5, GetHashKey("zombie"), GetHashKey("PLAYER"))
SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), GetHashKey("zombie"))


SetAiMeleeWeaponDamageModifier(2.0)

Citizen.CreateThread(function()
    while true do
        --Supress potential to be run over
        SuppressShockingEventTypeNextFrame(62)
        Citizen.Wait(1)
    end
end)
--Block ped speaking
Citizen.CreateThread(function()
    while true do
        if #zombies >= 1 then
            for k,v in pairs(zombies) do
                if DoesEntityExist(v) then
                    StopPedSpeaking(v, true)
                end
            end
        end
        Citizen.Wait(1)
    end
end)

RegisterNetEvent("fivez:ZombieWalk", function(zombieNetId)
    local zombie = NetworkGetEntityFromNetworkId(zombieNetId)
    if zombie then
        print(GetPedConfigFlag(zombie, 183, true), GetPedConfigFlag(zombie, 224, true), GetPedConfigFlag(zombie, 224, 1))
        print(GetPedConfigFlag(zombie, 100, true), GetPedConfigFlag(zombie, 100, 1)) --Check if ped is still drunk?
        SetPedConfigFlag(zombie, 183, false) --Is agitated
        SetPedConfigFlag(zombie, 224, false) --Melee combat
        SetPedUsingActionMode(zombie, false, -1, 0)
    end
end)

RegisterNetEvent("fivez:ZombieStoppedAttacking", function(zombieNetId)
    local zombie = NetworkGetEntityFromNetworkId(zombieNetId)
    if zombie then
        RequestAnimSet("move_m@drunk@verydrunk")
        while not HasAnimSetLoaded("move_m@drunk@verydrunk") do
            Citizen.Wait(0)
        end
        SetPedMovementClipset(zombie, "move_m@drunk@verydrunk", 1.0)
        
        TaskWanderStandard(zombie, 10.0, 10)
        for k,v in pairs(zombiesAttacking) do
            if v.zombie == zombie then
                v.brain = nil
                table.remove(zombiesAttacking, k)
            end
        end
    end
end)

RegisterNetEvent("fivez:ZombieStartedAttacking", function(zombieNetId, targetPed)
    local zombie = NetworkGetEntityFromNetworkId(zombieNetId)
    if zombie then
        RequestAnimSet("move_m@drunk@verydrunk")
        while not HasAnimSetLoaded("move_m@drunk@verydrunk") do
            Citizen.Wait(0)
        end
        SetPedMovementClipset(zombie, "move_m@drunk@verydrunk", 1.0)
        
        table.insert(zombiesAttacking, {zombie = zombie, target = targetPed, started = GetGameTimer(), brain = zombieBrain})
    end
end)

RegisterNetEvent("fivez:DeleteZombie", function(zombieNetId)
    print("Deleting zombie")
    local zomPed = NetworkGetEntityFromNetworkId(zombieNetId)
    if DoesEntityExist(zomPed) then
        --DeleteEntity(zomPed)
        for k,v in pairs(zombies) do
            if v == zomPed then
                table.remove(zombies, k)
            end
        end
    end
end)

RegisterNetEvent("fivez:GetGroundForZombie", function(zombieCoords)
    local coords = json.decode(zombieCoords)
    local ground, groundPos = GetSafeCoordForPed(coords.x, coords.y, coords.z, true, 16)
    print("Got safe coords", groundPos)
    if ground then
        TriggerServerEvent("fivez:GetGroundForZombieCB", json.encode(groundPos))
        return
    end
    TriggerServerEvent('fivez:GetGroundForZombieCB', json.encode(false))
end)

RegisterNetEvent("fivez:SpawnZombie", function(zombieNetId)
    local zombie = NetworkGetEntityFromNetworkId(tonumber(zombieNetId))
    if DoesEntityExist(zombie) then
        table.insert(zombies, zombie)
        SetupZombie(zombie)
    end
end)

RegisterNetEvent("fivez:SpawnZombieHorde", function(zombieHordeData)
    local zombieHorde = json.decode(zombieHordeData)
    for k,v in pairs(zombieHorde) do
        local zom = NetworkGetEntityFromNetworkId(tonumber(v))
        if DoesEntityExist(zom) then
            table.insert(zombies, zom)
            SetupZombie(zom)
            print("Zombie setup")
        end
    end
end)

RegisterNetEvent("fivez:SyncZombieState", function(syncZombiesData)
    print("Sync zombie event triggered")
    local syncZombies = json.decode(syncZombiesData)
    --If the client side zombies table length is not equal to the syncZombies
    if #zombies ~= #syncZombies then
        if #zombies < #syncZombies then
            for k,syncZom in pairs(syncZombies) do
                local syncZomEnt = NetworkGetEntityFromNetworkId(tonumber(syncZom))
                local alreadySynced = false
                --Check all zombies already on client side
                for k,zom in pairs(zombies) do
                    --If the zombie we are trying to sync already exists
                    if syncZomEnt == zom then
                        alreadySynced = true
                    end
                end
                
                --If the zombie is not already synced
                if not alreadySynced then
                    table.insert(zombies, syncZomEnt)
                end
            end
        elseif #zombies > #syncZombies then
            --If the client side zombies table has more items then the new syncZombies
            --Loop through client side zombies to find out what zombie has been removed
            for k,zom in pairs(zombies) do
                local exists = false
                for k,syncZom in pairs(syncZombies) do
                    if zom == NetworkGetEntityFromNetworkId(syncZom) then
                        exists = true
                    end
                end

                --If the client side zombie wasn't found in the new syncZombies table, remove it
                if not exists then
                    --? Not sure if we remove the entity since we still want dead bodies
                    --DeleteEntity(zom)
                    table.remove(zombies, k)
                end
            end
        end
    end

    SetupZombieStates()
end)

function SetupZombie(zomPed)
    if DoesEntityExist(zomPed) then
        --Check if ped is already a zombie/playing zombie animation
        if tonumber(GetPedRelationshipGroupHash(zomPed)) ~= tonumber(GetHashKey("zombie")) then
            SetPedMaxHealth(zomPed, 300.0)
            SetEntityMaxHealth(zomPed, 300.0)
            SetPedSeeingRange(zomPed, 45.0)
            SetEntityMaxSpeed(zomPed, 3.0)
            SetPedAccuracy(zomPed, 25.0)
            SetPedHearingRange(zomPed, 20.0)
            
            SetPedFleeAttributes(zomPed, 0, false)
            SetPedCombatAttributes(zomPed, 4, true) --Can commandeer vehicles
            SetPedCombatAttributes(zomPed, 5, true) -- Can Fight armed peds when not armed / Can Do drive bys
            SetPedCombatAttributes(zomPed, 16, true) --Can Use peeking Variations?
            SetPedCombatAttributes(zomPed, 17, false) --Can use vehicles?
            SetPedCombatAttributes(zomPed, 46, true) --Always fight
            SetPedCombatAttributes(zomPed, 1424, false) --Can use firing weapons
            
            
            SetPedAlertness(zomPed, 0.0)
            SetAmbientVoiceName(zomPed, "ALIENS")
            SetPedEnableWeaponBlocking(zomPed, true)
            SetPedRelationshipGroupHash(zomPed, GetHashKey("zombie"))
            DisablePedPainAudio(zomPed, true)
            SetPedDiesInWater(zomPed, true)
            SetPedDiesWhenInjured(zomPed, false)
            
            SetPedDiesInstantlyInWater(zomPed, true)
            --Stop zombies from being pushed around
            SetPedCanRagdollFromPlayerImpact(zomPed, false)

            SetPedConfigFlag(zomPed, 424, true) --Falls like aircraft
            
            SetPedConfigFlag(zomPed, 430, true) --Ignore being on fire
            SetPedConfigFlag(zomPed, 140, false) --Can attack friendlies

            SetPedConfigFlag(zomPed, 281, false) --Write mode
            SetPedConfigFlag(zomPed, 100, true) --Is drunk
            SetPedConfigFlag(zomPed, 33, false) --Dies when ragdoll
            SetPedConfigFlag(zomPed, 128, false) --Can be agitated
            SetPedConfigFlag(zomPed, 188, true) --Disable hurt
            --SetPedConfigFlag(zomPed, 223, true) --Shrink

            SetPedConfigFlag(zomPed, 294, true) --Disable shocking events
            SetPedConfigFlag(zomPed, 329, true) --Disable talk to
            SetPedConfigFlag(zomPed, 421, true) --Flaming footprints

            RequestAnimSet("move_m@drunk@verydrunk")
            while not HasAnimSetLoaded("move_m@drunk@verydrunk") do
                Citizen.Wait(0)
            end

            SetPedMovementClipset(zomPed, "move_m@drunk@verydrunk", 1.0)
            ApplyPedDamagePack(zomPed, "BigHitByVehicle", 0.0, 9.0)
            ApplyPedDamagePack(zomPed, "SCR_Dumpster", 0.0, 9.0)
            ApplyPedDamagePack(zomPed, "SCR_Torture", 0.0, 9.0)

            SetPedCombatRange(zomPed, 0)
            --SetPedCombatMovement(zomPed, 3.0)

            TaskWanderStandard(zomPed, 1.0, 10)
            print("Setup spawned zombie")
            return
        end
    end
end

function SetupZombieStates()
    for k,v in pairs(zombies) do
        local zomPed = v
        if DoesEntityExist(zomPed) then
            SetupZombie(zomPed)
        end
    end
end

local debugzombies = false
Citizen.CreateThread(function()
    while true do
        while not debugzombies do
            Citizen.Wait(0)
        end
        local plyPos = GetEntityCoords(GetPlayerPed(-1))
        for k,v in pairs(zombies) do
            local zomPed = v
            if DoesEntityExist(zomPed) then
                local zomPos = GetEntityCoords(zomPed)
                DrawLine(plyPos.x, plyPos.y, plyPos.z, zomPos.x, zomPos.y, zomPos.z, 255, 255, 255, 255)
                Draw3DText(zomPos.x, zomPos.y, zomPos.z, "Zombie:"..zomPed, 4, 1.0, 1.0)
            end
        end

        Citizen.Wait(0)
    end
end)

RegisterCommand("debugzombies", function()
    debugzombies = not debugzombies
end, false)