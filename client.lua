-- commandes de zoom
local zoomLevel = 60         -- FOV initial
local zoomStep  = 5          -- pas de zoom
local zoomMin   = 15         -- FOV max (fort zoom)
local zoomMax   = 60         -- FOV min (zoom arrière)

RegisterCommand('+duckJumelleZoomIncrement', function()
    if currentVision then
        zoomLevel = math.max(zoomMin, zoomLevel - zoomStep)
        SetGameplayCamRawFov(zoomLevel)
    end
end)

RegisterCommand('+duckJumelleZoomDecrement', function()
    if currentVision then
        zoomLevel = math.min(zoomMax, zoomLevel + zoomStep)
        SetGameplayCamRawFov(zoomLevel)
    end
end)

RegisterCommand('+duckJumelleEnableNormal', function()
	setVision('normal')
end)

RegisterCommand('+duckJumelleEnableNight', function()
	setVision('night')
end)

RegisterCommand('+duckJumelleEnableThermal', function()
	setVision('thermal')
end)

RegisterKeyMapping('+duckJumelleZoomIncrement', 'Jumelles Zoom +', 'keyboard', 'A')
RegisterKeyMapping('+duckJumelleZoomDecrement', 'Jumelles Zoom -', 'keyboard', 'E')

local currentVision = nil

local visionSettings = {
    normal  = { nightvision = false, seethrough = false },
    night   = { nightvision = true,  seethrough = false },
    thermal = { nightvision = true,  seethrough = true },
}

local function setVision(vision)
    local s = visionSettings[vision]
    if not s then return end

    if currentVision == vision then
        SetNightvision(false)
        SetSeethrough(false)
        SetGameplayCamRawFov(zoomMax)
        currentVision = nil
        return
    end

    if currentVision then
        SetNightvision(false)
        SetSeethrough(false)
    end

    Wait(100)
    SetNightvision(s.nightvision)
    SetSeethrough(s.seethrough)
    currentVision = vision

    zoomLevel = zoomMax
    SetGameplayCamRawFov(zoomLevel)
end

RegisterNetEvent('duck:jumelles:active')
AddEventHandler('duck:jumelles:active', setVision)
