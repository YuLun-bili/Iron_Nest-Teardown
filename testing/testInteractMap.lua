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
	mapTablePanAccMax = 4

	mapCamPlayer3rd = GetBool("game.thirdperson")
	mapCamLerpStart = Transform()
	mapCamLerpEnd = Transform()
	mapFovLerpStart = tempPlayerFov
	mapFovLerpEnd = mapTableFov
	mapFovLerpTrack = tempPlayerFov

	mapPanSpeedVec = Vec()
	mapWasDrawing = false
	mapLineStartPos = {}
	mapLineEndPos = {}
	mapLineType = 0
	mapLineMarkerPos = {}
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
	if useMapCamLerp == 0 then
		if mapWasDrawing then clientLocalResetMapDrawing() end
		return
	end
	local clientLocalPlayerId = GetLocalPlayer()
	UiPush()
		UiMakeInteractive()
		if useMapCamLerp == 1 then
			local tempOldSpeedVal = VecLength(mapPanSpeedVec)
			local tempScaleMaxVel = 0.05
			local tempOldViewPos = VecCopy(mapTableViewPos)
			local tempInputRawX = InputValue("right")-InputValue("left")
			local tempInputRawZ = InputValue("down")-InputValue("up")
			local tempAnyInput = (tempInputRawX ~= 0 or tempInputRawZ ~= 0)
			local tempInputNewSpeed = Vec()
			local tempSlowFactor = tempAnyInput and 1.25 or 4.5
			if tempAnyInput and (tempOldSpeedVal < tempScaleMaxVel) then
				tempInputNewSpeed = VecScale(VecNormalize(Vec(tempInputRawX, 0, tempInputRawZ)), math.min(1, tempOldSpeedVal/mapTablePanAccMax+0.1)*dt)
				tempSlowFactor = 0
			end
			local tempNewSpeedVel = VecAdd(VecScale(mapPanSpeedVec, 1-tempSlowFactor*dt), tempInputNewSpeed)

			mapTableViewPos = VecAdd(mapTableViewPos, tempNewSpeedVel)
			mapTableViewPos[1] = math.min(math.max(0, mapTableViewPos[1]), mapTableWidth)
			mapTableViewPos[3] = math.min(math.max(0+mapTableHeightOff, mapTableViewPos[3]), mapTableHeight+mapTableHeightOff)
			mapPanSpeedVec = VecSub(mapTableViewPos, tempOldViewPos)
		else
			mapPanSpeedVec = Vec()
		end

		if useMapCamLerp ~= 1 then
			UiPop()
			if shared.mapLineList[clientLocalPlayerId] then ServerCall("server.playerCancelMapLine", clientLocalPlayerId) end
			if mapWasDrawing then clientLocalResetMapDrawing() end
			return
		end

		
	UiPop()
end

function clientLocalResetMapDrawing()
	mapWasDrawing = false
	mapLineStartPos = {}
	mapLineEndPos = {}
	mapLineType = 0
	mapLineMarkerPos = {}
end

function server.init()
	shared.mapLineIndex = 0
	shared.mapLineList = {}
	shared.mapPlayerLineList = {}
end

function server.playerDrawMapLine(playerId, startPos, endPos, lineType, markerPos)
	shared.mapPlayerLineList[playerId] = {startPos, endPos, lineType, markerPos}
end

function server.playerFinishMapLine(playerId)
	if not shared.mapPlayerLineList[playerId] then return end
	server.addMapLine(shared.mapPlayerLineList[playerId])
	server.playerCancelMapLine(playerId)
end

function server.playerCancelMapLine(playerId)
	shared.mapPlayerLineList[playerId] = nil
end

function server.addMapLine(lineData)
	local startPos = lineData[1]
	local endPos = lineData[2]
	local lineType = lineData[3]
	local markerPos = lineData[4]
	local tempNewIndex = shared.mapLineIndex + 1
	shared.mapLineIndex = tempNewIndex
	shared.mapLineList[tempNewIndex] = {startPos, endPos, lineType, markerPos}
end

function server.editMapLineMarkerPos(lineIndex, markerPos)
	shared.mapLineList[lineIndex][4] = markerPos
end

function server.clearMapLine(lineIndex)
	if not shared.mapLineList[lineIndex] then return end
	shared.mapLineList[lineIndex] = nil
end