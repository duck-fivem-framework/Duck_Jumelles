local fov_max = 150.0
local fov_min = 7.0    -- max zoom (plus petit = plus fort zoom)
local speed_lr = 8.0   -- rotation gauche/droite
local speed_ud = 8.0   -- rotation haut/bas
local zoomstep = 5.0


local helicam = false
local fov = (fov_max + fov_min) * 0.5
local vision_state = 0  -- 0=normal, 1=nightmode, 2=thermal

-- état interne pour l’init/cleanup
local _heliInit    = false
local _scaleform   = nil
local _cam         = nil

local function exitJumelles()
    if _heliInit then
        RenderScriptCams(false, false, 0, true)
        ClearTimecycleModifier()
        SetNightvision(false)
        SetSeethrough(false)

        if _cam then
            DestroyCam(_cam, false)
            _cam = nil
        end
        if _scaleform then
            SetScaleformMovieAsNoLongerNeeded(_scaleform)
            _scaleform = nil
        end

        ClearPedTasks(PlayerPedId())
        fov = (fov_max + fov_min) * 0.5
        _heliInit = false

        local ped = PlayerPedId()

        -- joue le son de fermeture
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
        -- enlève l’animation
        ClearPedTasks(ped)
        -- passe le flag à false pour déclencher le cleanup
        helicam = false
    end

    -- SendNUIMessage({action = 'close'}) -- Si je trouve une solution pour passer le scaleform en NUI

end

-- Incrémente le zoom

local function zoomIncrement()
    print("duckJumelleZoomIncrement")
        
    if helicam and _cam then
        fov = math.max(fov_min, fov - zoomstep)
        SetCamFov(_cam, fov)
    end
end

local function zoomDecrement()
    print("duckJumelleZoomDecrement")
    if helicam and _cam then
        fov = math.min(fov_max, fov + zoomstep)
        SetCamFov(_cam, fov)
    end
end

RegisterCommand('+duckJumellesZoomDecrement', zoomDecrement)
RegisterCommand('+duckJumellesZoomIncrement', zoomIncrement)
RegisterCommand('+duckJumellesExit', exitJumelles)
-- KeyMappings pour binder les touches A/E
RegisterKeyMapping('+duckJumellesZoomIncrement', 'Jumelles Zoom +', 'keyboard', 'E')
RegisterKeyMapping('+duckJumellesZoomDecrement', 'Jumelles Zoom -', 'keyboard', 'Q')
RegisterKeyMapping('+duckJumellesExit', 'Quitter Jumelles', 'keyboard', 'A')

--EVENTS--

local visionSettings = {
    normal  = { nightvision = false, seethrough = false },
    night   = { nightvision = true,  seethrough = false },
    thermal = { nightvision = true,  seethrough = true },
}

local function checkRotation()
    if helicam and _cam then
        local zoomNorm = (fov - fov_min) / (fov_max - fov_min)
        local rx, ry, rz = table.unpack(GetCamRot(_cam, 2))
        local ax = GetDisabledControlNormal(0, 220)
        local ay = GetDisabledControlNormal(0, 221)
        if ax ~= 0.0 or ay ~= 0.0 then
            rz = rz - ax * speed_ud * (zoomNorm + 0.1)
            rx = math.max(math.min(20.0, rx - ay * speed_lr * (zoomNorm + 0.1)), -89.5)
            SetCamRot(_cam, rx, 0.0, rz, 2)
        end
    end
end

local function DuckThreadJumelles()
    local ped = PlayerPedId()

    -- arrêt auto si mort
    if IsEntityDead(ped) then
        exitJumelles()
    else
        -- rotation uniquement (le zoom est géré ailleurs)
        checkRotation()
        -- display les lunettes sur le screen
        DrawScaleformMovieFullscreen(_scaleform, 255, 255, 255, 255)
    end
end
-- FONCTION GÉNÉRIQUE DE SWITCH DE VISION
local function setVision(vision)
    -- si vision invalide, on désactive tout
    local s = visionSettings[vision]

    if not s then
        SetNightvision(false)
        SetSeethrough(false)
        helicam = false
        return
    end

    -- si re-clic sur le même mode, on désactive
    if vision_state == vision then
        SetNightvision(false)
        SetSeethrough(false)
        helicam = false
        vision_state = 0
        return
    end

    -- sinon, on applique le nouveau mode
    SetNightvision(s.nightvision)
    SetSeethrough(s.seethrough)
    vision_state = vision
    helicam = true
    

    local ped = PlayerPedId()

    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_BINOCULARS", 0, true)
    PlayAmbientSpeech1(ped, "GENERIC_CURSE_MED", "SPEECH_PARAMS_FORCE")

    SetTimecycleModifier("heliGunCam")
    SetTimecycleModifierStrength(0.3)

    _scaleform = RequestScaleformMovie("BINOCULARS")
    while not HasScaleformMovieLoaded(_scaleform) do
        Citizen.Wait(0)
    end

    _cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(_cam, ped, 0.0, 0.0, 1.0, true)
    SetCamRot(_cam, 0.0, 0.0, GetEntityHeading(ped))
    SetCamFov(_cam, fov)
    RenderScriptCams(true, false, 0, true)

    PushScaleformMovieFunction(_scaleform, "SET_CAM_LOGO")
    PushScaleformMovieFunctionParameterInt(0)
    PopScaleformMovieFunctionVoid()

    _heliInit = true
    
    -- SendNUIMessage({action = 'open'}) -- Si je trouve une solution pour passer le scaleform en NUI

    Citizen.CreateThread(function()
        while helicam do
            DuckThreadJumelles()
            Citizen.Wait(0)
        end
    end)
end


-- ON ÉCOUTE L’ÉVÉNEMENT POUR CHANGER DE VISION
RegisterNetEvent('duck:jumelles:active')
AddEventHandler('duck:jumelles:active', function(vision)
    setVision(vision)
end)
