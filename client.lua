-- commandes de zoom
local zoomLevel = 60         -- FOV initial
local zoomStep  = 5          -- Step du zoom
local zoomMin   = 5         -- FOV max (fort zoom)
local zoomMax   = 60         -- FOV min (zoom arrière)

local currentVision = nil
local helicamActive   = false
local scaleform       = nil
local cam             = nil

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

local function initHelicam()
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_BINOCULARS", 0, true)
    PlayAmbientSpeech1(ped, "GENERIC_CURSE_MED", "SPEECH_PARAMS_FORCE")

    SetTimecycleModifier("heliGunCam")
    SetTimecycleModifierStrength(0.3)

    scaleform = RequestScaleformMovie("BINOCULARS")
    while not HasScaleformMovieLoaded(scaleform) do
        Citizen.Wait(0)
    end

    cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(cam, ped, 0.0, 0.0, 1.0, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped))
    SetCamFov(cam, zoomLevel)
    RenderScriptCams(true, false, 0, true)

    PushScaleformMovieFunction(scaleform, "SET_CAM_LOGO")
    PushScaleformMovieFunctionParameterInt(0)
    PopScaleformMovieFunctionVoid()

    helicamActive = true
end

local function stopHelicam()
    helicamActive = false
    ClearTimecycleModifier()
    SetNightvision(false)
    SetSeethrough(false)

    -- remise à zéro du zoom
    zoomLevel = (zoomMin + zoomMax) * 0.5
    SetGameplayCamRawFov(zoomLevel)

    RenderScriptCams(false, false, 0, true)
    if scaleform then
        SetScaleformMovieAsNoLongerNeeded(scaleform)
        scaleform = nil
    end
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
    ClearPedTasks(PlayerPedId())
    currentVision = nil
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if helicamActive then
            local ped  = PlayerPedId()
            local veh  = GetVehiclePedIsIn(ped, false)

            -- conditions d'arrêt automatiques
            if IsEntityDead(ped) or not IsPedInAnyVehicle(ped, false) then
                stopHelicam()
            end

            -- sortie helicam avec croix (INPUT_CELLPHONE_CANCEL = 177)
            if IsControlJustPressed(0, 177) then
                stopHelicam()
            end

            -- rotation caméra
            local zoomNorm = (1.0 / (zoomMax - zoomMin)) * (zoomLevel - zoomMin)
            CheckInputRotation(cam, zoomNorm)
				
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
	else
		Citizen.Wait(1000)
        end
    end
end)

RegisterCommand('+duckJumelleZoomIncrement', function()
    if helicamActive then
        zoomLevel = math.max(zoomMin, zoomLevel - zoomStep)
        SetGameplayCamRawFov(zoomLevel)
    end
end)

RegisterCommand('+duckJumelleZoomDecrement', function()
    if helicamActive then
        zoomLevel = math.min(zoomMax, zoomLevel + zoomStep)
        SetGameplayCamRawFov(zoomLevel)
    end
end)

RegisterCommand('+duckJumelleEnableNormal',  function() setVision('normal')   end)
RegisterCommand('+duckJumelleEnableNight',   function() setVision('night')    end)
RegisterCommand('+duckJumelleEnableThermal', function() setVision('thermal')  end)
RegisterCommand('+duckJumelleDisable', function() stopHelicam()  end)

RegisterKeyMapping('+duckJumelleZoomIncrement', 'Jumelles Zoom +', 'keyboard', 'A')
RegisterKeyMapping('+duckJumelleZoomDecrement', 'Jumelles Zoom -', 'keyboard', 'E')
