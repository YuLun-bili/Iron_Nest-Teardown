#version 2

function client.init()
	useMap = false
	useMapCamLerp = 0
	useMapCamLerpTime = 0.275

	mapTableShape = FindShape("mapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape)
	mapTableWidth = mapTableVX*mapTableScale
	mapTableHeight = mapTableVZ*mapTableScale
	mapTableHeightOff = 0.21
	mapTableViewPosRaw = Vec(mapTableWidth/2, 2.5, mapTableHeight/2+mapTableHeightOff)
	mapTableViewPos = VecCopy(mapTableViewPosRaw)
	local tempPlayerFov = GetInt("options.gfx.fov")
	mapTableFov = 70
	mapTablePanSpeedMax = 4

	mapCamPlayer3rd = GetBool("game.thirdperson")
	mapCamLerpStart = Transform()
	mapCamLerpEnd = Transform()
	mapFovLerpStart = tempPlayerFov
	mapFovLerpEnd = mapTableFov
	mapFovLerpTrack = tempPlayerFov

	mapPanSpeedVec = Vec()
end

function client.tick(dt)
	if InputPressed("interact") then
		useMap = not useMap
		local tempOldCamLerp = useMapCamLerp
		if useMap then
			-- 0 -> 1, start -> end
			if tempOldCamLerp == 0 then
				mapCamPlayer3rd = GetBool("game.thirdperson")
				mapTableViewPos = VecCopy(mapTableViewPosRaw)
			end
			useMapCamLerp = 0
			SetValue("useMapCamLerp", 1, "linear", useMapCamLerpTime*(1-tempOldCamLerp))
			mapCamLerpStart = GetCameraTransform()
			mapCamLerpEnd = TransformToParentTransform(GetShapeWorldTransform(mapTableShape), Transform(mapTableViewPos, QuatEuler(-85, 0, 0)))
			mapFovLerpStart = mapFovLerpTrack
			mapFovLerpEnd = mapTableFov
		else
			-- 1 -> 0, end -> start
			useMapCamLerp = 1
			SetValue("useMapCamLerp", 0, "linear", useMapCamLerpTime*tempOldCamLerp)
			mapCamLerpStart = mapCamPlayer3rd and GetPlayerCameraTransform() or GetPlayerEyeTransform()
			mapCamLerpEnd = GetCameraTransform()
			mapFovLerpStart = GetInt("options.gfx.fov")
			mapFovLerpEnd = mapFovLerpTrack
		end
	end

	if mapCamPlayer3rd then return end
	QueryRequire("player")
	local tempAllPlayers = GetAllPlayers()
	for p=1, #tempAllPlayers do
		local tempPlayerId = tempAllPlayers[p]
		if tempPlayerId ~= 0 then QueryRejectPlayer(tempPlayerId) end
	end
	if not QueryClosestPoint(GetCameraTransform().pos, 0.1) then return end
	SetPlayerHidden()
end

function client.render(dt)
	if GetInt("game.screenshot") > 0 then return end
	if useMapCamLerp == 0 then return end
	SetCameraTransform(TransformToParentTransform(GetShapeWorldTransform(mapTableShape), Transform(mapTableViewPos, QuatEuler(-85, 0, 0))), mapFovLerpTrack)
	if useMapCamLerp == 1 then return end

	local tempLerpCamVec = VecLerp(mapCamLerpStart.pos, mapCamLerpEnd.pos, useMapCamLerp)
	local tempSlerpCamQuat = QuatSlerp(mapCamLerpStart.rot, mapCamLerpEnd.rot, useMapCamLerp)
	mapFovLerpTrack = mapFovLerpStart*(1-useMapCamLerp) + mapFovLerpEnd*useMapCamLerp

	SetCameraTransform(Transform(tempLerpCamVec, tempSlerpCamQuat), mapFovLerpTrack)
end

function client.draw(dt)
	if useMapCamLerp == 0 then return end
	UiPush()
		UiMakeInteractive()
		if useMapCamLerp == 1 then
			local tempOldSpeedVal = VecLength(mapPanSpeedVec)
			local tempOldViewPos = VecCopy(mapTableViewPos)
			local tempInputRawX = InputValue("right")-InputValue("left")
			local tempInputRawZ = InputValue("down")-InputValue("up")
			local tempAnyInput = (tempInputRawX ~= 0 or tempInputRawZ ~= 0)
			local tempInputNewSpeed = tempAnyInput and VecNormalize(Vec(tempInputRawX, 0, tempInputRawZ)) or Vec()
			tempInputNewSpeed = VecScale(tempInputNewSpeed, math.min(1, tempOldSpeedVal/mapTablePanSpeedMax+0.1)*dt)
			local tempNewSpeedVel = VecAdd(VecScale(mapPanSpeedVec, 1-(tempAnyInput and 1.25 or 3.5)*dt), tempInputNewSpeed)

			mapTableViewPos = VecAdd(mapTableViewPos, tempNewSpeedVel)
			mapTableViewPos[1] = math.min(math.max(0, mapTableViewPos[1]), mapTableWidth)
			mapTableViewPos[3] = math.min(math.max(0+mapTableHeightOff, mapTableViewPos[3]), mapTableHeight+mapTableHeightOff)
			mapPanSpeedVec = VecSub(mapTableViewPos, tempOldViewPos)
		else
			mapPanSpeedVec = Vec()
		end
	UiPop()
end