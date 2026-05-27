Config = {}

-- ============================================================
--  TEAMS
-- ============================================================
Config.Teams = {
    [1] = { name = "Attackers", label = "ATK" },
    [2] = { name = "Defenders", label = "DEF" },
}

-- ============================================================
--  LOBBY SPAWNS (where players wait before/after rounds)
-- ============================================================
Config.LobbySpawns = {
    attack = { x = 688.26,    y = 614.73,   z = 128.91, w = 0.0 },
    defend = { x = -1734.61,  y = -728.21,  z = 10.42,  w = 0.0 },
}

-- ============================================================
--  DEFAULT WEAPONS
-- ============================================================
Config.DefaultWeapons = {
    { weapon = "WEAPON_KNIFE",         ammo = 1   },
    { weapon = "WEAPON_PISTOL50",      ammo = 64  },
    { weapon = "WEAPON_PUMPSHOTGUN",   ammo = 32  },
    { weapon = "WEAPON_MICROSMG",      ammo = 120 },
    { weapon = "WEAPON_CARBINERIFLE",  ammo = 120 },
}

-- ============================================================
--  MAPS / BASES
-- ============================================================
Config.Bases = {
    [1] = {
        name        = "Legion Square",
        attSpawn    = vector4(87.54,   -1046.57, 29.44, 90.0),
        defSpawn    = vector4(309.0,   -763.8,   29.28, 270.0),
        objective   = vector3(206.14,  -926.35,  30.69),
        objRadius   = 5.0,
        arenaCenter = vector3(206.14,  -926.35,  30.69),
        arenaRadius = 220.0,
        blip = { sprite = 280, color = 1, scale = 0.8 },
    },
    [2] = {
        name        = "Mirror Park",
        attSpawn    = vector4(1190.07, -424.26,  67.37, 185.0),
        defSpawn    = vector4(1198.83, -725.23,  59.19, 5.0),
        objective   = vector3(1175.29, -579.66,  64.3),
        objRadius   = 3.0,
        arenaCenter = vector3(1190.0,  -567.0,   65.0),
        arenaRadius = 180.0,
        blip = { sprite = 280, color = 3, scale = 0.8 },
    },
    [3] = {
        name        = "Vespucci Beach",
        attSpawn    = vector4(-1358.48, -1249.43, 4.9,  60.0),
        defSpawn    = vector4(-1441.54, -950.4,   8.05, 220.0),
        objective   = vector3(-1392.0,  -1113.0,  4.0),
        objRadius   = 3.5,
        arenaCenter = vector3(-1392.0,  -1112.0,  4.0),
        arenaRadius = 180.0,
        blip = { sprite = 280, color = 49, scale = 0.8 },
    },
    [4] = {
        name        = "Sandy Shores Airfield",
        attSpawn    = vector4(1494.89, 3190.47, 40.41, 90.0),
        defSpawn    = vector4(1276.07, 3131.48, 40.41, 90.0),
        objective   = vector3(1400.52, 3171.27, 40.41),
        objRadius   = 5.0,
        arenaCenter = vector3(1400.52, 3171.27, 40.41),
        arenaRadius = 200.0,
        blip = { sprite = 280, color = 6, scale = 0.8 },
    },
}

-- ============================================================
--  ROUND SETTINGS
-- ============================================================
Config.RoundSettings = {
    maxRounds        = 3,
    roundTime        = 180,     -- seconds per round
    intermissionTime = 15,      -- seconds between rounds
    minPlayers       = 1,       -- minimum to start
    maxPerTeam       = 8,
    spawnProtection  = 5,       -- seconds of invincibility on spawn
    captureTime      = 5,       -- seconds to capture objective
    friendlyFire     = false,
    autoBalance      = true,
    outOfBoundsTime  = 30,      -- seconds before OOB kill
}

-- ============================================================
--  HEALTH & ARMOR
-- ============================================================
Config.StartHealth = 200
Config.StartArmor  = 100

-- ============================================================
--  TEAM SKINS
-- ============================================================
Config.TeamSkins = {
    [1] = {
        model      = 1885233650,
        components = { ["0"]=0,["1"]=0,["2"]=14,["3"]=194,["4"]=86,["5"]=0,["6"]=12,["7"]=112,["8"]=5,["9"]=0,["10"]=0,["11"]=220 },
        texture    = { ["0"]=0,["1"]=0,["2"]=4, ["3"]=7,  ["4"]=4, ["5"]=0,["6"]=12,["7"]=0,  ["8"]=0,["9"]=0,["10"]=0,["11"]=4  },
        props      = { ["0"]=58,["1"]=30,["2"]=-1,["3"]=-1,["4"]=-1,["5"]=-1,["6"]=-1,["7"]=-1 },
        propTex    = { ["0"]=0, ["1"]=0 },
    },
    [2] = {
        model      = -1667301416,
        components = { ["0"]=0,["1"]=169,["2"]=26,["3"]=15, ["4"]=135,["5"]=0,["6"]=76,["7"]=0,["8"]=161,["9"]=0,["10"]=0,["11"]=184 },
        texture    = { ["0"]=0,["1"]=2,  ["2"]=0, ["3"]=0,  ["4"]=4,  ["5"]=0,["6"]=24,["7"]=0,["8"]=3,  ["9"]=0,["10"]=0,["11"]=1   },
        props      = { ["0"]=5, ["1"]=-1,["2"]=-1,["3"]=-1, ["4"]=-1, ["5"]=-1,["6"]=-1,["7"]=-1 },
        propTex    = { ["0"]=1 },
    },
}

-- ============================================================
--  EXP VALUES
-- ============================================================
Config.Exp = {
    kill       = 50,
    winRound   = 100,
    loseRound  = 20,
    drawRound  = 50,
}

-- ============================================================
--  COMMANDS
-- ============================================================
Config.Commands = {
    join  = "ad",
    admin = "adm",
}

-- ============================================================
--  DATABASE
-- ============================================================
Config.Database = {
    enabled = true,
    table   = "ad_stats",
}

-- ============================================================
--  TEST NPC  (set enabled = false in production)
-- ============================================================
Config.TestNPC = {
    enabled    = true,
    model      = "s_m_y_swat_01",
    weapon     = "WEAPON_CARBINERIFLE",
    health     = 150,
    armor      = 0,
    accuracy   = 70,
}

-- ============================================================
--  ADMIN PERMISSION LEVEL
-- ============================================================
Config.AdminPermission = "user"
