-- ============================================================
--  Attack & Defend — Spectator  (v2.0)
-- ============================================================
local spectating    = false
local spectateTarget = nil
local spectateList  = {}

-- ============================================================
--  START SPECTATING
-- ============================================================
RegisterNetEvent("ad:startSpectate", function()
    spectating     = true
    spectateTarget = nil

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    NetworkSetInSpectatorMode(false, ped)

    SendNUIMessage({ action = "spectateMode", active = true })

    Wait(500)
    SpectateNext()
end)

-- ============================================================
--  STOP SPECTATING
-- ============================================================
local function StopSpectate()
    spectating     = false
    spectateTarget = nil
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    SetEntityVisible(ped, true, true)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SendNUIMessage({ action = "spectateMode", active = false })
end

RegisterNetEvent("ad:stopSpectate", function()
    StopSpectate()
end)

-- ============================================================
--  NEXT / PREV
-- ============================================================
function SpectateNext()
    local players = GetActivePlayers()
    spectateList = {}
    for _, pid in ipairs(players) do
        if pid ~= PlayerId() then spectateList[#spectateList + 1] = pid end
    end

    if #spectateList == 0 then StopSpectate() return end

    local idx = 1
    if spectateTarget then
        for i, pid in ipairs(spectateList) do
            if pid == spectateTarget then
                idx = (i % #spectateList) + 1
                break
            end
        end
    end

    spectateTarget = spectateList[idx]
    NetworkSetInSpectatorMode(true, GetPlayerPed(spectateTarget))
    SendNUIMessage({ action = "spectateTarget", name = GetPlayerName(spectateTarget) })
end

function SpectatePrev()
    if #spectateList == 0 then return end
    local idx = #spectateList
    if spectateTarget then
        for i, pid in ipairs(spectateList) do
            if pid == spectateTarget then
                idx = i - 1
                if idx < 1 then idx = #spectateList end
                break
            end
        end
    end
    spectateTarget = spectateList[idx]
    NetworkSetInSpectatorMode(true, GetPlayerPed(spectateTarget))
    SendNUIMessage({ action = "spectateTarget", name = GetPlayerName(spectateTarget) })
end

-- ============================================================
--  KEY HANDLER  (E = next, Q = prev)
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if spectating then
            if IsControlJustReleased(0, 38) then SpectateNext()
            elseif IsControlJustReleased(0, 44) then SpectatePrev() end
        end
    end
end)
