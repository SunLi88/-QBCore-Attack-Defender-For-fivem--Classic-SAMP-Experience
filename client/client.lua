-- ============================================================
--  Attack & Defend — Client  (v2.0 clean rewrite)
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  STATE
-- ============================================================
local inMatch        = false
local myTeam         = 0
local myKills        = 0
local myDeaths       = 0
local myExp          = 0
local currentBase    = nil
local menuOpen       = false
local protTimer      = 0          -- game-timer ms until prot expires
local oobTimer       = 0.0        -- accumulated OOB seconds
local oobWarned      = false
local nearObj        = false
local capActive      = false
local arenaBlip      = nil
local arenaIconBlip  = nil
local spawnedNPCs    = {}

-- ============================================================
--  BLIP HELPERS
-- ============================================================
local function CreateArenaBlip(base)
    if arenaBlip      and DoesBlipExist(arenaBlip)      then RemoveBlip(arenaBlip)      end
    if arenaIconBlip  and DoesBlipExist(arenaIconBlip)  then RemoveBlip(arenaIconBlip)  end
    arenaBlip, arenaIconBlip = nil, nil
    if not base or not base.arenaCenter then return end

    local c = base.arenaCenter
    arenaBlip = AddBlipForRadius(c.x, c.y, c.z, base.arenaRadius)
    SetBlipColour(arenaBlip, 1)
    SetBlipAlpha(arenaBlip, 100)

    arenaIconBlip = AddBlipForCoord(c.x, c.y, c.z)
    local bc = base.blip or {}
    SetBlipSprite(arenaIconBlip, bc.sprite or 280)
    SetBlipColour(arenaIconBlip, bc.color  or 1)
    SetBlipScale(arenaIconBlip,  bc.scale  or 0.8)
    SetBlipAsShortRange(arenaIconBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(base.name or "Arena")
    EndTextCommandSetBlipName(arenaIconBlip)
end

local function RemoveArenaBlip()
    if arenaBlip     and DoesBlipExist(arenaBlip)     then RemoveBlip(arenaBlip)     end
    if arenaIconBlip and DoesBlipExist(arenaIconBlip) then RemoveBlip(arenaIconBlip) end
    arenaBlip, arenaIconBlip = nil, nil
end

-- ============================================================
--  NUI HELPERS
-- ============================================================
local function NUI(msg)   SendNUIMessage(msg)    end
local function NUIFocus(v) SetNuiFocus(v, v)    end

-- ============================================================
--  SKIN
-- ============================================================
local function ApplySkin(team)
    local sk = Config.TeamSkins[team]
    if not sk then return end
    RequestModel(sk.model)
    local t = 0
    while not HasModelLoaded(sk.model) and t < 50 do Wait(100); t = t + 1 end
    if not HasModelLoaded(sk.model) then return end
    SetPlayerModel(PlayerId(), sk.model)
    SetModelAsNoLongerNeeded(sk.model)
    Wait(300)  -- wait for new ped to exist
    local ped = PlayerPedId()
    for comp, draw in pairs(sk.components) do
        SetPedComponentVariation(ped, tonumber(comp), draw, sk.texture[comp] or 0, 2)
    end
    for prop, draw in pairs(sk.props) do
        local idx = tonumber(prop)
        if draw == -1 then ClearPedProp(ped, idx)
        else SetPedPropIndex(ped, idx, draw, sk.propTex[prop] or 0, true) end
    end
end

-- ============================================================
--  WEAPONS
-- ============================================================
local function GiveWeapons(list)
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, false)
    for _, w in ipairs(list or {}) do
        GiveWeaponToPed(ped, GetHashKey(w.weapon), w.ammo or 0, false, true)
    end
end

local function StripWeapons()
    RemoveAllPedWeapons(PlayerPedId(), false)
end

-- ============================================================
--  FULL CLEANUP (leave / match end)
-- ============================================================
local function DoCleanup()
    inMatch      = false
    myTeam       = 0
    currentBase  = nil
    nearObj      = false
    capActive    = false
    protTimer    = 0
    oobTimer     = 0.0
    oobWarned    = false
    SetEntityInvincible(PlayerPedId(), false)
    StripWeapons()
    RemoveArenaBlip()
    NUI({ action = "hideHUD"           })
    NUI({ action = "nearObjective",     near      = false })
    NUI({ action = "objectiveContested",contested = false })
    NUI({ action = "spectateMode",      active    = false })
    for k, npc in pairs(spawnedNPCs) do
        if DoesEntityExist(npc) then DeleteEntity(npc) end
        spawnedNPCs[k] = nil
    end
end

-- ============================================================
--  MENU TOGGLE  (F5 = control 166)
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, 166) then
            menuOpen = not menuOpen
            NUI({ action = menuOpen and "openMenu" or "closeMenu" })
            NUIFocus(menuOpen)
        end
    end
end)

RegisterNUICallback("closeUI", function(_, cb)
    menuOpen = false
    NUIFocus(false)
    cb({})
end)

RegisterNUICallback("joinTeam", function(data, cb)
    TriggerServerEvent("ad:server:join", tonumber(data.team))
    cb({})
end)

RegisterNUICallback("leaveGame", function(_, cb)
    TriggerServerEvent("ad:server:leave")
    cb({})
end)

RegisterNUICallback("getLeaderboard", function(_, cb)
    TriggerServerEvent("ad:server:getLeaderboard")
    cb({})
end)

-- ============================================================
--  SPAWN PLAYER  (lobby or round start)
-- ============================================================
RegisterNetEvent("ad:spawnPlayer", function(data)
    if not data or not data.coords then return end

    inMatch     = (data.round or 0) > 0
    myTeam      = data.team or myTeam
    currentBase = data.base   -- nil when lobby spawn

    local coords = data.coords
    local ped    = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(600)

    -- Teleport first (before skin change to avoid ghost teleport)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w or 0.0)

    ApplySkin(myTeam)
    ped = PlayerPedId()   -- new ped after model change

    -- Health & armor
    SetEntityHealth(ped, math.floor((data.health or Config.StartHealth) / 200 * 200) + 100)
    SetPedArmour(ped, data.armor or 0)

    GiveWeapons(data.weapons)

    -- Spawn protection
    if (data.round or 0) > 0 then
        protTimer = GetGameTimer() + (Config.RoundSettings.spawnProtection * 1000)
        SetEntityInvincible(ped, true)
        CreateArenaBlip(currentBase)
    else
        protTimer = 0
        SetEntityInvincible(ped, false)
        RemoveArenaBlip()
    end

    DoScreenFadeIn(500)
    NUI({ action = "showHUD" })
    NUI({ action = "expUpdate", kills = myKills, deaths = myDeaths, exp = myExp })
end)

-- ============================================================
--  RESPAWN TO LOBBY
-- ============================================================
RegisterNetEvent("ad:respawnLobby", function(team)
    CreateThread(function()
        local lobby = team == 1 and Config.LobbySpawns.attack or Config.LobbySpawns.defend
        if not lobby then return end

        DoScreenFadeOut(300)
        Wait(400)

        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        StripWeapons()

        -- Clear match state before teleport to avoid OOB false-positives
        inMatch      = false
        currentBase  = nil
        oobTimer     = 0.0
        oobWarned    = false
        RemoveArenaBlip()

        ApplySkin(myTeam ~= 0 and myTeam or team)
        ped = PlayerPedId()

        -- Wait for collision at destination
        RequestCollisionAtCoord(lobby.x, lobby.y, lobby.z)
        local att = 0
        while not HasCollisionLoadedAroundEntity(ped) and att < 60 do Wait(50); att = att + 1 end

        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, lobby.x, lobby.y, lobby.z, false, false, false)
        SetEntityHeading(ped, lobby.w or 0.0)
        Wait(100)
        SetEntityHealth(ped, 300)   -- full 200 HP (engine: health+100)
        SetPedArmour(ped, 0)
        FreezeEntityPosition(ped, false)

        DoScreenFadeIn(300)
    end)
end)

-- ============================================================
--  SPAWN PROTECTION THREAD
-- ============================================================
CreateThread(function()
    while true do
        Wait(500)
        if protTimer > 0 and GetGameTimer() >= protTimer then
            protTimer = 0
            SetEntityInvincible(PlayerPedId(), false)
        end
    end
end)

-- ============================================================
--  HEALTH MONITOR + DEATH DETECTION + OOB
-- ============================================================
CreateThread(function()
    local lastHp = Config.StartHealth
    while true do
        Wait(500)
        if not inMatch or myTeam == 0 then
            lastHp = Config.StartHealth
            goto next
        end

        local ped = PlayerPedId()
        local hp  = math.max(0, GetEntityHealth(ped) - 100)

        -- Death detection
        if hp <= 0 and lastHp > 0 then
            lastHp = 0
            local killerNet = 0
            local killPed   = GetPedSourceOfDeath(ped)
            if killPed and killPed ~= 0 then
                local kpIdx = NetworkGetPlayerIndexFromPed(killPed)
                if kpIdx then
                    local kSrv = GetPlayerServerId(kpIdx)
                    if kSrv and kSrv > 0 then killerNet = kSrv end
                end
            end
            TriggerServerEvent("ad:server:playerDied", killerNet)
        end

        -- HP sync (only on meaningful change)
        if math.abs(hp - lastHp) >= 5 then
            TriggerServerEvent("ad:server:hpUpdate", hp)
            if hp < lastHp then
                TriggerServerEvent("ad:server:damageDone", lastHp - hp)
            end
            lastHp = hp
        end

        -- Out-of-bounds
        if currentBase and currentBase.arenaCenter then
            local pos    = GetEntityCoords(ped)
            local center = currentBase.arenaCenter
            local dist   = #(vector2(pos.x, pos.y) - vector2(center.x, center.y))
            if dist > currentBase.arenaRadius then
                oobTimer = oobTimer + 0.5
                if oobTimer >= Config.RoundSettings.outOfBoundsTime and not oobWarned then
                    oobWarned = true
                    TriggerServerEvent("ad:server:outOfBounds")
                end
            else
                oobTimer  = 0.0
                oobWarned = false
            end
        end

        ::next::
    end
end)

-- ============================================================
--  OBJECTIVE ZONE CHECK
-- ============================================================
CreateThread(function()
    while true do
        Wait(500)
        if not inMatch or myTeam ~= 1 or not currentBase then goto objnext end

        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)
        local obj  = currentBase.objective
        local dist = #(vector3(pos.x, pos.y, pos.z) - obj)
        local inside = dist <= currentBase.objRadius

        if inside and not nearObj then
            nearObj = true
            TriggerServerEvent("ad:server:objectiveEnter")
            NUI({ action = "nearObjective", near = true })
        elseif not inside and nearObj then
            nearObj = false
            TriggerServerEvent("ad:server:objectiveLeave")
            NUI({ action = "nearObjective", near = false })
        end

        ::objnext::
    end
end)

-- ============================================================
--  DRAW MARKERS
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if not inMatch or not currentBase then goto drawNext end

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- Arena boundary ring
        if currentBase.arenaCenter then
            local c    = currentBase.arenaCenter
            local r    = currentBase.arenaRadius
            local dist = #(vector2(pos.x, pos.y) - vector2(c.x, c.y))
            if dist <= r + 60.0 then
                DrawMarker(25, c.x, c.y, pos.z - 0.5,
                    0,0,0, 0,0,0,
                    r * 2.0, r * 2.0, 4.0,
                    255, 60, 60, 180,
                    false, false, 2, false, nil, nil, false)
            end
        end

        -- Objective marker (attackers only)
        if myTeam == 1 and currentBase.objective then
            local obj  = currentBase.objective
            local dist = #(vector3(pos.x, pos.y, pos.z) - obj)
            if dist < 50.0 then
                DrawMarker(1, obj.x, obj.y, obj.z,
                    0,0,0, 0,0,0,
                    currentBase.objRadius * 2.0, currentBase.objRadius * 2.0, 1.0,
                    255, 45, 120, 120,
                    false, false, 2, false, nil, nil, false)
            end
        end

        ::drawNext::
    end
end)

-- ============================================================
--  NET EVENTS — HUD
-- ============================================================
RegisterNetEvent("ad:joined", function(info, hudData)
    myTeam  = type(info) == "table" and info.team or info
    inMatch = true
    NUI({ action = "joined",    team = myTeam, myId = type(info) == "table" and info.myId or nil })
    NUI({ action = "updateHUD", data = hudData })
    NUI({ action = "expUpdate", kills = myKills, deaths = myDeaths, exp = myExp })
end)

RegisterNetEvent("ad:updateHUD", function(data)
    NUI({ action = "updateHUD", data = data })
end)

RegisterNetEvent("ad:roundStart", function(round, timeLeft)
    NUI({ action = "roundStart", round = round, timeLeft = timeLeft })
    nearObj   = false
    capActive = false
end)

RegisterNetEvent("ad:roundEnd", function(winnerTeam, score, matchOver, playerStats, atkList, defList)
    NUI({ action = "roundEnd", winnerTeam = winnerTeam, score = score,
          matchOver = matchOver, playerStats = playerStats,
          atkList = atkList, defList = defList })
    StripWeapons()
end)

RegisterNetEvent("ad:matchEnd", function(winner, score, atkList, defList)
    NUI({ action = "matchEnd", winner = winner, score = score,
          atkList = atkList or {}, defList = defList or {} })
    StripWeapons()
    myKills  = 0
    myDeaths = 0
    myExp    = 0
end)

RegisterNetEvent("ad:playerDied", function()
    NUI({ action = "playerDied" })
end)

RegisterNetEvent("ad:killFeed", function(data)
    -- Resolve names from active players list
    local kname, vname = "Player", "Player"
    for _, pid in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(pid)
        if sid == data.killer then kname = GetPlayerName(pid) end
        if sid == data.victim then vname = GetPlayerName(pid) end
    end
    NUI({ action = "killFeed", data = {
        killer = kname, victim = vname,
        killerTeam = data.killerTeam, victimTeam = data.victimTeam,
    }})

    -- Track own kills locally
    local myNetId = GetPlayerServerId(PlayerId())
    if data.killer == myNetId then
        myKills = myKills + 1
        NUI({ action = "expUpdate", kills = myKills, deaths = myDeaths, exp = myExp })
    end
end)

RegisterNetEvent("ad:expUpdate", function(data)
    if type(data) ~= "table" then return end
    myKills  = tonumber(data.kills)  or myKills
    myDeaths = tonumber(data.deaths) or myDeaths
    myExp    = tonumber(data.exp)    or myExp
    NUI({ action = "expUpdate", kills = myKills, deaths = myDeaths, exp = myExp })
end)

RegisterNetEvent("ad:objectiveContested", function(contested, capTeam)
    capActive = contested and capTeam == 1
    NUI({ action = "objectiveContested", contested = contested })
end)

RegisterNetEvent("ad:leaderboard", function(rows)
    NUI({ action = "leaderboard", data = rows or {} })
end)

RegisterNetEvent("ad:cleanup", function()
    DoCleanup()
end)

-- ============================================================
--  TEST NPC SPAWN
-- ============================================================
RegisterNetEvent("ad:spawnNPC", function(data)
    if not Config.TestNPC or not Config.TestNPC.enabled then return end
    local base = data.base
    if not base then return end

    local key = tostring(data.team) .. "_npc"
    if spawnedNPCs[key] and DoesEntityExist(spawnedNPCs[key]) then return end

    local spawn = data.team == 1 and base.defSpawn or base.attSpawn
    local model = GetHashKey(Config.TestNPC.model)

    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 40 do Wait(100); t = t + 1 end
    if not HasModelLoaded(model) then return end

    local npc = CreatePed(4, model, spawn.x, spawn.y, spawn.z, spawn.w or 0, true, true)
    spawnedNPCs[key] = npc

    SetEntityHealth(npc, (Config.TestNPC.health or 150) + 100)
    SetPedArmour(npc, Config.TestNPC.armor or 0)

    local wHash = GetHashKey(Config.TestNPC.weapon)
    GiveWeaponToPed(npc, wHash, 9999, false, true)
    SetPedAmmo(npc, wHash, 9999)
    SetPedAccuracy(npc, Config.TestNPC.accuracy or 70)

    SetPedCombatAbility(npc, 100)
    SetPedCombatRange(npc, 2)
    SetPedCombatAttributes(npc, 0,  true)
    SetPedCombatAttributes(npc, 1,  true)
    SetPedCombatAttributes(npc, 5,  true)
    SetPedCombatAttributes(npc, 46, true)
    SetPedFleeAttributes(npc, 0, false)

    local hateGroup = GetHashKey("HATES_PLAYER")
    SetPedRelationshipGroupHash(npc, hateGroup)
    SetRelationshipBetweenGroups(5, hateGroup, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), hateGroup)

    TaskCombatPed(npc, PlayerPedId(), 0, 16)
    SetModelAsNoLongerNeeded(model)

    local kt = data.team
    CreateThread(function()
        while DoesEntityExist(npc) and not IsPedDeadOrDying(npc) do
            Wait(500)
            if not IsPedInCombat(npc, PlayerPedId()) then
                TaskCombatPed(npc, PlayerPedId(), 0, 16)
            end
        end
        if DoesEntityExist(npc) and IsPedDeadOrDying(npc) and inMatch then
            TriggerServerEvent("ad:server:npcKilled", kt)
        end
        Wait(3000)
        if DoesEntityExist(npc) then DeleteEntity(npc) end
        spawnedNPCs[key] = nil
    end)
end)
