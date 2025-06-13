RegisterCommand('+duckJumelleZoomIncrement', function()
	
end)
RegisterCommand('+duckJumelleZoomDecrement', function()
	
end)

RegisterKeyMapping('+duckJumelleZoomIncrement', 'Jumelles Zoom+', 'keyboard', 'A')
RegisterKeyMapping('+duckJumelleZoomDecrement', 'Jumelles Zoom-', 'keyboard', 'E')

local currentVision = nil

-- Configuration des différents modes de vision
local visionSettings = {
    normal = { nightvision = false, seethrough = false },
    night  = { nightvision = true,  seethrough = false },
    thermal = { nightvision = true,  seethrough = true },
}

local thermal = false
local night = false
local normal = false
local helicam = false
RegisterNetEvent('duck:jumelles:active')
AddEventHandler('duck:jumelles:active', function(vision)
    local settings = visionSettings[vision]

    -- Si le mode demandé n'existe pas, on sort
    if not settings then return end

    -- Si on demande le même mode que celui actif, on désactive tout
    if currentVision == vision then
        SetNightvision(false)
        SetSeethrough(false)
        currentVision = nil
        return
    end

    -- Sinon, on change de mode : on désactive d'abord l'ancien
    if currentVision then
        SetNightvision(false)
        SetSeethrough(false)
    end

    Wait(100)

    SetNightvision(settings.nightvision)
    SetSeethrough(settings.seethrough)
    currentVision = vision
    Wait(100)
end)
