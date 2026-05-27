-- ============================================================
--  Attack & Defend — Server  (v2.0 clean rewrite)
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  GAME STATE
-- ============================================================
local Game = {
    active       = false,
    base         = nil,
    round        = 0,
    score        = { [1] = 0, [2] = 0 },
    phase        = "waiting",   -- waiting | active | intermission | ended
    timeLeft     = 0,
    capProgress  = 0,
    capTeam      = 0,
    capSrc       = 0,
    capRunning   = false,
    roundRunning = false,
    intermActive = false,
    roundEnding  = false,
}

local Players         = {}   -- [src] = { team, alive, kills, deaths, damage, roundKills, hp, exp, license, name, dbKills, dbDeaths, dbExp }
local npcSpawnedRound = false

-- ============================================================
--  UTILITIES
-- ============================================================
local function Log(msg) print("[AttackDefend] " .. tostring(msg)) end

local function Notify(src, msg, t)
    TriggerClientEvent("QBCore:Notify", src, msg, t or "primary", 4000)
end

local function SendAll(ev, ...)
    for src in pairs(Players) do TriggerClientEvent(ev, src, ...) end
end

local function TeamCount(team)
    local n = 0
    for _, d in pairs(Players) do if d.team == team then n = n + 1 end end
    return n
end

local function AliveCount(team)
    local n = 0
    for _, d in pairs(Players) do if d.team == team and d.alive then n = n + 1 end end
    return n
end

local function GetLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == "license:" then return id end
    end
    return nil
end

local function GetCharName(src)
    local p = QBCore.Functions.GetPlayer(src)
    if p then
        local ci = p.PlayerData.charinfo
        return (ci.firstname or "Player") .. " " .. (ci.lastname or tostring(src))
    end
    return "Player " .. tostring(src)
end

-- ============================================================
--  RATE LIMITER  (per-player per-event)
-- ============================================================
local _cd = {}
local function CD(src, ev, secs)
    local k   = src .. "_" .. ev
    local now = os.time()
    if _cd[k] and now - _cd[k] < secs then return false end
    _cd[k] = now
    return true
end

-- ============================================================
--  HUD BUILDER
-- ============================================================
local function BuildHUD()
    local atk, def = {}, {}
    for src, d in pairs(Players) do
        local row = { id = src, name = d.name, kills = d.roundKills, alive = d.alive, hp = d.hp, exp = d.exp }
        if d.team == 1 then atk[#atk+1] = row else def[#def+1] = row end
    end
    return {
        round       = Game.round,
        maxRounds   = Config.RoundSettings.maxRounds,
        score       = Game.score,
        phase       = Game.phase,
        timeLeft    = Game.timeLeft,
        capProgress = Game.capProgress,
        capTeam     = Game.capTeam,
        baseName    = Game.base and Game.base.name or "",
        attackers   = atk,
        defenders   = def,
    }
end

local function BroadcastHUD()
    SendAll("ad:updateHUD", BuildHUD())
end

-- ============================================================
--  EXP SYNC
-- ============================================================
local function SyncStats(src)
    local d = Players[src]
    if not d then return end
    TriggerClientEvent("ad:expUpdate", src, {
        kills  = (d.dbKills  or 0) + d.kills,
        deaths = (d.dbDeaths or 0) + d.deaths,
        exp    = (d.dbExp    or 0) + d.exp,
    })
end

local function AddExp(src, amount)
    if not Players[src] then return end
    Players[src].exp = Players[src].exp + amount
    SyncStats(src)
end

-- ============================================================
--  CAPTURE
-- ============================================================
local function CancelCapture()
    if not Game.capRunning then return end
    Game.capRunning  = false
    Game.capTeam     = 0
    Game.capSrc      = 0
    Game.capProgress = 0
    SendAll("ad:objectiveContested", false, 0)
    BroadcastHUD()
end

-- ============================================================
--  DATABASE
-- ============================================================
local function SaveStats(winner)
    if not Config.Database.enabled then return end
    for src, d in pairs(Players) do
        if not d.license then goto continue end
        local won  = (winner ~= 0 and d.team == winner) and 1 or 0
        local lost = (winner ~= 0 and d.team ~= winner) and 1 or 0
        exports.oxmysql:query([[
            INSERT INTO ad_stats (license, name, kills, deaths, wins, losses, matches, damage, exp, last_team)
            VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                name    = VALUES(name),
                kills   = kills   + VALUES(kills),
                deaths  = deaths  + VALUES(deaths),
                wins    = wins    + VALUES(wins),
                losses  = losses  + VALUES(losses),
                matches = matches + 1,
                damage  = damage  + VALUES(damage),
                exp     = exp     + VALUES(exp),
                last_team = VALUES(last_team)
        ]], { d.license, d.name, d.kills, d.deaths, won, lost, d.damage, d.exp, d.team })
        ::continue::
    end
end

-- ============================================================
--  END MATCH
-- ============================================================
local function EndMatch()
    if not Game.active then return end
    Game.active = false
    Game.phase  = "ended"

    local w = Game.score[1] > Game.score[2] and 1
           or Game.score[2] > Game.score[1] and 2
           or 0

    local atkList, defList = {}, {}
    for src, d in pairs(Players) do
        local row = { name = d.name, kills = d.kills, deaths = d.deaths, exp = d.exp }
        if d.team == 1 then atkList[#atkList+1] = row else defList[#defList+1] = row end
    end

    SendAll("ad:matchEnd", w, Game.score, atkList, defList)
    SaveStats(w)

    -- Reset after delay
    SetTimeout(6000, function()
        -- send everyone to lobby
        for src, d in pairs(Players) do
            TriggerClientEvent("ad:respawnLobby", src, d.team)
            TriggerClientEvent("ad:cleanup", src)
        end
        Players         = {}
        npcSpawnedRound = false
        Game.active       = false
        Game.base         = nil
        Game.round        = 0
        Game.score        = { [1] = 0, [2] = 0 }
        Game.phase        = "waiting"
        Game.timeLeft     = 0
        Game.capProgress  = 0
        Game.capTeam      = 0
        Game.capSrc       = 0
        Game.capRunning   = false
        Game.roundRunning = false
        Game.intermActive = false
        Game.roundEnding  = false
        Log("Match ended and state reset.")
    end)
end

-- ============================================================
--  END ROUND
-- ============================================================
local function EndRound(winnerTeam)
    if Game.roundEnding  then return end
    if Game.phase ~= "active" then return end

    Game.roundEnding  = true
    Game.phase        = "intermission"
    Game.roundRunning = false
    Game.capRunning   = false
    Game.capTeam      = 0
    Game.capSrc       = 0
    Game.capProgress  = 0

    if winnerTeam == 1 or winnerTeam == 2 then
        Game.score[winnerTeam] = Game.score[winnerTeam] + 1
    end

    -- Award EXP
    for src, d in pairs(Players) do
        local amt = Config.Exp.drawRound
        if winnerTeam ~= 0 then
            amt = d.team == winnerTeam and Config.Exp.winRound or Config.Exp.loseRound
        end
        AddExp(src, amt)
    end

    local need     = math.ceil(Config.RoundSettings.maxRounds / 2)
    local matchEnd = Game.score[1] >= need or Game.score[2] >= need
                  or Game.round >= Config.RoundSettings.maxRounds

    BroadcastHUD()

    local atkList, defList = {}, {}
    for src, d in pairs(Players) do
        local row = { name = d.name, kills = d.kills, deaths = d.deaths, exp = d.exp }
        if d.team == 1 then atkList[#atkList+1] = row else defList[#defList+1] = row end
    end

    for src, d in pairs(Players) do
        TriggerClientEvent("ad:roundEnd", src, winnerTeam, Game.score, matchEnd,
            { name = d.name, kills = d.kills, deaths = d.deaths, exp = d.exp },
            atkList, defList)
    end

    -- Send to lobby after short delay (let round-end screen show)
    SetTimeout(3500, function()
        for src, d in pairs(Players) do
            TriggerClientEvent("ad:respawnLobby", src, d.team)
        end
    end)

    npcSpawnedRound = false

    -- Wait intermission then start next round or end match
    SetTimeout(Config.RoundSettings.intermissionTime * 1000, function()
        if not Game.intermActive then return end   -- guard
        Game.intermActive = false
        Game.roundEnding  = false
        if matchEnd then
            EndMatch()
        else
            TriggerEvent("ad:startRound")
        end
    end)
    Game.intermActive = true
end

-- ============================================================
--  START ROUND
-- ============================================================
AddEventHandler("ad:startRound", function()
    if not Game.active then return end

    Game.round       = Game.round + 1
    Game.phase       = "active"
    Game.timeLeft    = Config.RoundSettings.roundTime
    Game.capProgress = 0
    Game.capTeam     = 0
    Game.capSrc      = 0
    Game.capRunning  = false
    Game.roundRunning= true

    for _, d in pairs(Players) do
        d.alive      = true
        d.roundKills = 0
        d.hp         = Config.StartHealth
    end

    for src, d in pairs(Players) do
        local sp = d.team == 1 and Game.base.attSpawn or Game.base.defSpawn
        TriggerClientEvent("ad:spawnPlayer", src, {
            coords  = { x = sp.x, y = sp.y, z = sp.z, w = sp.w or 0.0 },
            team    = d.team,
            weapons = Config.DefaultWeapons,
            health  = Config.StartHealth,
            armor   = Config.StartArmor,
            base    = Game.base,
            round   = Game.round,
        })
    end

    BroadcastHUD()
    SendAll("ad:roundStart", Game.round, Config.RoundSettings.roundTime)

    -- Test NPC
    if Config.TestNPC.enabled and not npcSpawnedRound then
        npcSpawnedRound = true
        local sentAtk, sentDef = false, false
        for src, d in pairs(Players) do
            if d.team == 1 and not sentAtk then
                TriggerClientEvent("ad:spawnNPC", src, { team = 1, base = Game.base })
                sentAtk = true
            elseif d.team == 2 and not sentDef then
                TriggerClientEvent("ad:spawnNPC", src, { team = 2, base = Game.base })
                sentDef = true
            end
            if sentAtk and sentDef then break end
        end
    end

    -- Round timer
    CreateThread(function()
        while Game.roundRunning do
            Wait(1000)
            if not Game.roundRunning then break end
            Game.timeLeft = Game.timeLeft - 1
            BroadcastHUD()
            if Game.timeLeft <= 0 then
                Game.roundRunning = false
                EndRound(Game.capRunning and 2 or 0)
                break
            end
        end
    end)
end)

-- ============================================================
--  START MATCH
-- ============================================================
local function StartMatch(baseID)
    if Game.active then return false, "A match is already running. Use /adm stop first." end
    local base = Config.Bases[tonumber(baseID)]
    if not base then return false, "Invalid base ID." end
    if TeamCount(1) + TeamCount(2) < Config.RoundSettings.minPlayers then
        return false, ("Need at least %d player(s)."):format(Config.RoundSettings.minPlayers)
    end

    Game.active       = true
    Game.base         = base
    Game.round        = 0
    Game.score        = { [1] = 0, [2] = 0 }
    Game.roundEnding  = false
    Game.intermActive = false
    npcSpawnedRound   = false

    TriggerEvent("ad:startRound")
    return true
end

-- ============================================================
--  STOP GAME
-- ============================================================
local function StopGame()
    Game.roundRunning = false
    Game.capRunning   = false
    Game.intermActive = false
    Game.roundEnding  = false
    Game.active       = false
    Game.phase        = "waiting"
    Game.score        = { [1] = 0, [2] = 0 }
    Game.round        = 0
    Game.timeLeft     = 0
    Game.capProgress  = 0
    Game.capTeam      = 0
    Game.capSrc       = 0
    Game.base         = nil
    npcSpawnedRound   = false

    for src, d in pairs(Players) do
        TriggerClientEvent("ad:respawnLobby", src, d.team)
        TriggerClientEvent("ad:cleanup", src)
    end
    Players = {}
    Log("Game stopped.")
end

-- ============================================================
--  EVENTS: JOIN
-- ============================================================
RegisterNetEvent("ad:server:join", function(wantTeam)
    local src = source
    if not CD(src, "join", 3) then return end

    -- Already in match during active round — deny switch
    if Players[src] and Game.phase == "active" then
        Notify(src, "Cannot change teams during an active round.", "error")
        return
    end

    -- Already in — remove first (team switch outside active round)
    if Players[src] then
        if Game.capSrc == src then CancelCapture() end
        Players[src] = nil
        TriggerClientEvent("ad:cleanup", src)
    end

    local t1, t2 = TeamCount(1), TeamCount(2)
    local team   = (wantTeam == 1 or wantTeam == 2) and tonumber(wantTeam) or nil

    -- Auto-balance if no preference
    if not team then
        team = (t1 <= t2) and 1 or 2
    end

    -- Overflow: push to other team
    if team == 1 and t1 >= Config.RoundSettings.maxPerTeam then
        if t2 < Config.RoundSettings.maxPerTeam then team = 2
        else Notify(src, "Both teams are full.", "error") return end
    end
    if team == 2 and t2 >= Config.RoundSettings.maxPerTeam then
        if t1 < Config.RoundSettings.maxPerTeam then team = 1
        else Notify(src, "Both teams are full.", "error") return end
    end

    local license = GetLicense(src)
    local name    = GetCharName(src)

    Players[src] = {
        team       = team,
        alive      = false,
        kills      = 0,
        deaths     = 0,
        damage     = 0,
        roundKills = 0,
        hp         = 100,
        exp        = 0,
        license    = license,
        name       = name,
        dbKills    = 0,
        dbDeaths   = 0,
        dbExp      = 0,
    }

    TriggerClientEvent("ad:joined", src, { team = team, myId = src }, BuildHUD())
    Notify(src, "Joined " .. Config.Teams[team].name .. "!", "success")
    BroadcastHUD()

    -- Load DB stats async
    if license and Config.Database.enabled then
        exports.oxmysql:query("SELECT kills, deaths, exp FROM ad_stats WHERE license = ?", { license },
            function(rows)
                if rows and rows[1] and Players[src] then
                    Players[src].dbKills  = rows[1].kills  or 0
                    Players[src].dbDeaths = rows[1].deaths or 0
                    Players[src].dbExp    = rows[1].exp    or 0
                end
                SyncStats(src)
            end)
    else
        SyncStats(src)
    end

    -- Spawn in lobby
    local lobby = team == 1 and Config.LobbySpawns.attack or Config.LobbySpawns.defend
    TriggerClientEvent("ad:spawnPlayer", src, {
        coords  = { x = lobby.x, y = lobby.y, z = lobby.z, w = lobby.w or 0.0 },
        team    = team,
        weapons = {},
        health  = Config.StartHealth,
        armor   = 0,
        base    = nil,
        round   = 0,
    })
end)

-- ============================================================
--  EVENTS: LEAVE
-- ============================================================
RegisterNetEvent("ad:server:leave", function()
    local src = source
    if not CD(src, "leave", 2) then return end
    if not Players[src] then Notify(src, "You are not in a match.", "error") return end
    if Game.capSrc == src then CancelCapture() end
    Players[src] = nil
    TriggerClientEvent("ad:cleanup", src)
    Notify(src, "You left the match.", "primary")
    BroadcastHUD()
end)

-- ============================================================
--  EVENTS: PLAYER DIED
-- ============================================================
RegisterNetEvent("ad:server:playerDied", function(killerNetId)
    local src = source
    if not CD(src, "died", 2) then return end
    if Game.phase ~= "active" or Game.roundEnding then return end
    local d = Players[src]
    if not d or not d.alive then return end

    if Game.capSrc == src then CancelCapture() end

    d.alive  = false
    d.deaths = d.deaths + 1
    d.hp     = 0

    local ksrc = tonumber(killerNetId)
    if ksrc and ksrc > 0 and ksrc ~= src and Players[ksrc] then
        Players[ksrc].kills      = Players[ksrc].kills + 1
        Players[ksrc].roundKills = Players[ksrc].roundKills + 1
        AddExp(ksrc, Config.Exp.kill)
        SendAll("ad:killFeed", { killer = ksrc, victim = src,
            killerTeam = Players[ksrc].team, victimTeam = d.team })
    end

    BroadcastHUD()
    TriggerClientEvent("ad:playerDied", src)

    if AliveCount(1) == 0 and TeamCount(1) > 0 then EndRound(2)
    elseif AliveCount(2) == 0 and TeamCount(2) > 0 then EndRound(1) end
end)

-- ============================================================
--  EVENTS: HP UPDATE
-- ============================================================
RegisterNetEvent("ad:server:hpUpdate", function(hp)
    local src = source
    if not CD(src, "hp", 1) then return end
    if Players[src] then
        Players[src].hp = math.max(0, math.min(Config.StartHealth, tonumber(hp) or 0))
    end
end)

-- ============================================================
--  EVENTS: DAMAGE DONE
-- ============================================================
RegisterNetEvent("ad:server:damageDone", function(amount)
    local src = source
    if not CD(src, "dmg", 1) then return end
    local dmg = tonumber(amount) or 0
    if dmg <= 0 or dmg > 500 then return end
    if Players[src] then Players[src].damage = Players[src].damage + dmg end
end)

-- ============================================================
--  EVENTS: OBJECTIVE ENTER / LEAVE
-- ============================================================
RegisterNetEvent("ad:server:objectiveEnter", function()
    local src = source
    if not CD(src, "obj", 1) then return end
    if Game.phase ~= "active" or Game.roundEnding then return end
    if Game.capRunning then return end
    local d = Players[src]
    if not d or d.team ~= 1 or not d.alive then return end

    Game.capRunning  = true
    Game.capTeam     = 1
    Game.capSrc      = src
    Game.capProgress = 0
    SendAll("ad:objectiveContested", true, 1)

    local total = Config.RoundSettings.captureTime * 10   -- ticks at 100ms
    local ticks = 0
    CreateThread(function()
        while Game.capRunning and Game.phase == "active" do
            Wait(100)
            ticks = ticks + 1
            Game.capProgress = math.floor((ticks / total) * 100)
            BroadcastHUD()
            if Game.capProgress >= 100 then
                Game.capRunning = false
                EndRound(1)
                break
            end
        end
    end)
end)

RegisterNetEvent("ad:server:objectiveLeave", function()
    local src = source
    if Game.capSrc == src then CancelCapture() end
end)

-- ============================================================
--  EVENTS: OUT OF BOUNDS
-- ============================================================
RegisterNetEvent("ad:server:outOfBounds", function()
    local src = source
    if not CD(src, "oob", 5) then return end
    if Game.phase ~= "active" or Game.roundEnding then return end
    local d = Players[src]
    if not d or not d.alive then return end

    if Game.capSrc == src then CancelCapture() end
    Notify(src, "Eliminated: Left the combat zone!", "error")
    d.alive  = false
    d.deaths = d.deaths + 1
    d.hp     = 0
    BroadcastHUD()
    TriggerClientEvent("ad:playerDied", src)

    if AliveCount(1) == 0 and TeamCount(1) > 0 then EndRound(2)
    elseif AliveCount(2) == 0 and TeamCount(2) > 0 then EndRound(1) end
end)

-- ============================================================
--  EVENTS: NPC KILLED (test mode)
-- ============================================================
RegisterNetEvent("ad:server:npcKilled", function(killerTeam)
    local src = source
    if not CD(src, "npc", 5) then return end
    if Game.phase ~= "active" or Game.roundEnding then return end
    if not Players[src] then return end
    local kt = tonumber(killerTeam)
    if kt ~= 1 and kt ~= 2 then return end
    EndRound(kt)
end)

-- ============================================================
--  EVENTS: LEADERBOARD
-- ============================================================
RegisterNetEvent("ad:server:getLeaderboard", function()
    local src = source
    if not CD(src, "lb", 5) then return end
    if not Config.Database.enabled then
        TriggerClientEvent("ad:leaderboard", src, {})
        return
    end
    exports.oxmysql:query(
        "SELECT name, kills, deaths, wins, matches, exp FROM ad_stats ORDER BY exp DESC LIMIT 10",
        {}, function(rows) TriggerClientEvent("ad:leaderboard", src, rows or {}) end)
end)

-- ============================================================
--  PLAYER DROPPED
-- ============================================================
AddEventHandler("playerDropped", function()
    local src = source
    if Players[src] then
        if Game.capSrc == src then CancelCapture() end
        Players[src] = nil
        BroadcastHUD()
    end
end)

-- ============================================================
--  ADMIN COMMAND
-- ============================================================
RegisterCommand(Config.Commands.admin, function(src, args)
    if src == 0 then return end
    local act = (args[1] or "help"):lower()

    if act == "start" then
        local bid = tonumber(args[2]) or 1
        local ok, err = StartMatch(bid)
        Notify(src, ok and ("Match started: " .. (Config.Bases[bid] and Config.Bases[bid].name or "?"))
                      or ("Error: " .. (err or "?")), ok and "success" or "error")

    elseif act == "stop" then
        StopGame()
        Notify(src, "Match stopped.", "primary")

    elseif act == "map" then
        local bid = tonumber(args[2])
        if not bid or not Config.Bases[bid] then
            Notify(src, "Usage: /" .. Config.Commands.admin .. " map [1-" .. #Config.Bases .. "]", "error")
            return
        end
        StopGame()
        SetTimeout(500, function()
            local ok, err = StartMatch(bid)
            Notify(src, ok and ("Map changed to: " .. Config.Bases[bid].name)
                          or ("Error: " .. (err or "?")), ok and "success" or "error")
        end)

    elseif act == "kick" then
        local tid = tonumber(args[2])
        if tid and Players[tid] then
            if Game.capSrc == tid then CancelCapture() end
            Players[tid] = nil
            TriggerClientEvent("ad:cleanup", tid)
            Notify(src, "Player kicked from match.", "success")
        else
            Notify(src, "Player not found.", "error")
        end

    elseif act == "bases" then
        local list = "Bases: "
        for i, b in ipairs(Config.Bases) do list = list .. i .. "=" .. b.name .. "  " end
        Notify(src, list, "primary")

    elseif act == "status" then
        Notify(src, ("Phase: %s | Round: %d/%d | ATK %d - DEF %d | Players: %d"):format(
            Game.phase, Game.round, Config.RoundSettings.maxRounds,
            Game.score[1], Game.score[2],
            TeamCount(1) + TeamCount(2)), "primary")

    else
        Notify(src, "Commands: start [id] | stop | map [id] | kick [id] | bases | status", "primary")
    end
end, false)

Log("v2.0 loaded | /ad to join | /" .. Config.Commands.admin .. " to manage")
