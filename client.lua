local fov_max = 150.0
local fov_min = 7.0    -- max zoom (plus petit = plus fort zoom)
local zoomspeed = 10.0 -- vitesse de zoom
local speed_lr = 8.0   -- rotation gauche/droite
local speed_ud = 8.0   -- rotation haut/bas

local toggle_helicam    = 51  -- INPUT_CONTEXT (E)
local toggle_rappel    = 154  -- INPUT_DUCK (X)
local toggle_spotlight = 183  -- INPUT_PHONE_CAMERA_GRID (G)
local toggle_lock_on   = 22   -- INPUT_SPRINT (SPACE)

local helicam = false
local polmav_hash = GetHashKey("pcj")
local fov = (fov_max + fov_min) * 0.5
local vision_state = 0  -- 0=normal, 1=nightmode, 2=thermal

-- état interne pour l’init/cleanup
local _heliInit    = false
local _scaleform   = nil
local _cam         = nil
local _heliEntity  = nil

Citizen.CreateThread(function()
    while true do
        if helicam then
            -- ## INITIALISATION (une seule fois)
            if not _heliInit then
                local ped = PlayerPedId()
                _heliEntity = GetVehiclePedIsIn(ped, false)

                -- animation & son
                TaskStartScenarioInPlace(ped, "WORLD_HUMAN_BINOCULARS", 0, true)
                PlayAmbientSpeech1(ped, "GENERIC_CURSE_MED", "SPEECH_PARAMS_FORCE")

                -- filtre visuel
                SetTimecycleModifier("heliGunCam")
                SetTimecycleModifierStrength(0.3)

                -- scaleform
                _scaleform = RequestScaleformMovie("BINOCULARS")
                while not HasScaleformMovieLoaded(_scaleform) do
                    Citizen.Wait(0)
                end

                -- création caméra
                _cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
                AttachCamToEntity(_cam, ped, 0.0, 0.0, 1.0, true)
                SetCamRot(_cam, 0.0, 0.0, GetEntityHeading(ped))
                SetCamFov(_cam, fov)
                RenderScriptCams(true, false, 0, true)

                -- logo jumelles
                PushScaleformMovieFunction(_scaleform, "SET_CAM_LOGO")
                PushScaleformMovieFunctionParameterInt(0)
                PopScaleformMovieFunctionVoid()

                _heliInit = true
            end

            -- ## BOUCLE ACTIVE
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            -- arrêt automatique si mort ou sortie du véhicule
            if IsEntityDead(ped) or veh ~= _heliEntity then
                helicam = false
            else
                -- sortie manuelle (touche “croix”)
                if IsControlJustPressed(0, 177) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                    ClearPedTasks(ped)
                    helicam = false
                else
                    -- rotation, zoom, affichage
                    local zoomNorm = (fov - fov_min) / (fov_max - fov_min)
                    CheckInputRotation(_cam, zoomNorm)
                    HandleZoom(_cam)
                    HideHUDThisFrame()
                    DrawScaleformMovieFullscreen(_scaleform, 255, 255, 255, 255)
                end
            end

            Citizen.Wait(0)  -- réactif quand actif

        else
            -- ## CLEANUP (une seule fois)
            if _heliInit then
                -- retour à la caméra jeu
                RenderScriptCams(false, false, 0, true)

                -- supprime filtres et visions
                ClearTimecycleModifier()
                SetNightvision(false)
                SetSeethrough(false)

                -- détruit la caméra scriptée et la scaleform
                if _cam then
                    DestroyCam(_cam, false)
                    _cam = nil
                end
                if _scaleform then
                    SetScaleformMovieAsNoLongerNeeded(_scaleform)
                    _scaleform = nil
                end

                -- remet la posture du joueur
                ClearPedTasks(PlayerPedId())

                -- reset zoom & état
                fov = (fov_max + fov_min) * 0.5
                _heliInit = false
            end

            Citizen.Wait(500)  -- faible charge CPU quand inactif
        end
    end
end)

--EVENTS--

local visionSettings = {
    normal  = { nightvision = false, seethrough = false },
    night   = { nightvision = true,  seethrough = false },
    thermal = { nightvision = true,  seethrough = true },
}

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
end


-- ON ÉCOUTE L’ÉVÉNEMENT POUR CHANGER DE VISION
RegisterNetEvent('duck:jumelles:active')
AddEventHandler('duck:jumelles:active', function(vision)
    -- vision doit être un string "normal", "night" ou "thermal"
    setVision(vision)
end)

--FUNCTIONS--

function IsPlayerInPolmav()
	local lPed = GetPlayerPed(-1)
	local vehicle = GetVehiclePedIsIn(lPed)
	return IsVehicleModel(vehicle, polmav_hash)
end


function HideHUDThisFrame()
	HideHelpTextThisFrame()
	HideHudComponentThisFrame(19) -- weapon wheel
	HideHudComponentThisFrame(1) -- Wanted Stars
	HideHudComponentThisFrame(2) -- Weapon icon
	HideHudComponentThisFrame(3) -- Cash
	HideHudComponentThisFrame(4) -- MP CASH
	HideHudComponentThisFrame(13) -- Cash Change
	HideHudComponentThisFrame(11) -- Floating Help Text
	HideHudComponentThisFrame(12) -- more floating help text
	HideHudComponentThisFrame(15) -- Subtitle Text
	HideHudComponentThisFrame(18) -- Game Stream
end

function CheckInputRotation(cam, zoomvalue)
	local rightAxisX = GetDisabledControlNormal(0, 220)
	local rightAxisY = GetDisabledControlNormal(0, 221)
	local rotation = GetCamRot(cam, 2)
	if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
		new_z = rotation.z + rightAxisX*-1.0*(speed_ud)*(zoomvalue+0.1)
		new_x = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(speed_lr)*(zoomvalue+0.1)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
		SetCamRot(cam, new_x, 0.0, new_z, 2)
	end
end

function HandleZoom(cam)
	local lPed = GetPlayerPed(-1)
	if not ( IsPedSittingInAnyVehicle( lPed ) ) then

		if IsControlJustPressed(0,32) then -- Scrollup
			fov = math.max(fov - zoomspeed, fov_min)
		end
		if IsControlJustPressed(0,8) then
			fov = math.min(fov + zoomspeed, fov_max) -- ScrollDown		
		end
		local current_fov = GetCamFov(cam)
		if math.abs(fov-current_fov) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
			fov = current_fov
		end
		SetCamFov(cam, current_fov + (fov - current_fov)*0.05) -- Smoothing of camera zoom
	else
		if IsControlJustPressed(0,241) then -- Scrollup
			fov = math.max(fov - zoomspeed, fov_min)
		end
		if IsControlJustPressed(0,242) then
			fov = math.min(fov + zoomspeed, fov_max) -- ScrollDown		
		end
		local current_fov = GetCamFov(cam)
		if math.abs(fov-current_fov) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
			fov = current_fov
		end
		SetCamFov(cam, current_fov + (fov - current_fov)*0.05) -- Smoothing of camera zoom
	end
end

function GetVehicleInView(cam)
	local coords = GetCamCoord(cam)
	local forward_vector = RotAnglesToVec(GetCamRot(cam, 2))
	--DrawLine(coords, coords+(forward_vector*100.0), 255,0,0,255) -- debug line to show LOS of cam
	local rayhandle = CastRayPointToPoint(coords, coords+(forward_vector*200.0), 10, GetVehiclePedIsIn(GetPlayerPed(-1)), 0)
	local _, _, _, _, entityHit = GetRaycastResult(rayhandle)
	if entityHit>0 and IsEntityAVehicle(entityHit) then
		return entityHit
	else
		return nil
	end
end

function RotAnglesToVec(rot) -- input vector3
	local z = math.rad(rot.z)
	local x = math.rad(rot.x)
	local num = math.abs(math.cos(x))
	return vector3(-math.sin(z)*num, math.cos(z)*num, math.sin(x))
end
