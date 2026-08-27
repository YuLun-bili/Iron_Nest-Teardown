#version 2

function client.init()
	useMap = false
	useMapCamLerp = 0
	useMapCamLerpTime = 0.275

	mapTableShape = FindShape("mapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape) -- magicavoxel z up
	mapTableWidth = mapTableVX*mapTableScale
	mapTableHeight = mapTableVZ*mapTableScale
	mapTableThickness = mapTableVY*mapTableScale
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
	mapLineMarkerPos = 0

	clientLocalTrackMapLineList = {}
	clientLocalTrackPlayerMapLineList = {}
end

function client.tick(dt)
	SetInt("ironNest.mapLineIndex", shared.mapLineIndex)
	for i=1, shared.mapLineIndex do
		local tempCheckLine = shared.mapLineList[i]
		local tempCheckLocalLine = clientLocalTrackMapLineList[i]
		if tempCheckLine and not tempCheckLocalLine then
			SetFloat("ironNest.mapLine."..i..".startPos.x", tempCheckLine[1][1])
			SetFloat("ironNest.mapLine."..i..".startPos.y", tempCheckLine[1][2])
			SetFloat("ironNest.mapLine."..i..".endPos.x", tempCheckLine[2][1])
			SetFloat("ironNest.mapLine."..i..".endPos.y", tempCheckLine[2][2])
			SetInt("ironNest.mapLine."..i..".lineType", tempCheckLine[3])
			SetFloat("ironNest.mapLine."..i..".markerPos", tempCheckLine[4])
			clientLocalTrackMapLineList[i] = true
		elseif tempCheckLocalLine and not tempCheckLine then
			ClearKey("ironNest.mapLine."..i)
			clientLocalTrackMapLineList[i] = nil
		end
	end

	local clientLocalAllPlayers = GetAllPlayers()
	for p=1, #clientLocalAllPlayers do
		local tempPlayerId = clientLocalAllPlayers[p]
		local tempCheckLine = shared.mapPlayerLineList[tempPlayerId]
		local tempCheckLocalLine = clientLocalTrackPlayerMapLineList[tempPlayerId]
		if tempCheckLine then
			SetFloat("ironNest.playerMapLine."..tempPlayerId..".startPos.x", tempCheckLine[1][1])
			SetFloat("ironNest.playerMapLine."..tempPlayerId..".startPos.y", tempCheckLine[1][2])
			SetFloat("ironNest.playerMapLine."..tempPlayerId..".endPos.x", tempCheckLine[2][1])
			SetFloat("ironNest.playerMapLine."..tempPlayerId..".endPos.y", tempCheckLine[2][2])
			SetInt("ironNest.playerMapLine."..tempPlayerId..".lineType", tempCheckLine[3])
			SetFloat("ironNest.playerMapLine."..tempPlayerId..".markerPos", tempCheckLine[4])
			clientLocalTrackPlayerMapLineList[tempPlayerId] = true
		elseif tempCheckLocalLine and not tempCheckLine then
			ClearKey("ironNest.playerMapLine."..tempPlayerId)
			clientLocalTrackPlayerMapLineList[tempPlayerId] = nil
		end
	end

	local clientLocalRemovedPlayers = GetRemovedPlayers()
	for p=1, #clientLocalRemovedPlayers do
		local tempPlayerId = clientLocalRemovedPlayers[p]
		ClearKey("ironNest.playerMapLine."..tempPlayerId)
		clientLocalTrackPlayerMapLineList[tempPlayerId] = nil
	end

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
			DisableMotionBlur()
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

		if InputDown("usetool") then
			local tempMapTableShapeTrans = GetShapeWorldTransform(mapTableShape)
			local tempCamTrans = GetCameraTransform()
			if not mapWasDrawing then
				local mousePointingDir = TransformToLocalVec(tempMapTableShapeTrans, UiPixelToWorld(UiGetMousePos()))
				local camLocalPos = TransformToLocalPoint(tempMapTableShapeTrans, tempCamTrans.pos)
				local camDirScale = (mapTableThickness-camLocalPos[2])/mousePointingDir[2]
				mapWasDrawing = true
				mapLineStartPos = {camLocalPos[1]+mousePointingDir[1]*camDirScale, camLocalPos[3]+mousePointingDir[3]*camDirScale}
				mapLineEndPos = mapLineStartPos
				mapLineType = 1
			else
				local mousePointingDir = TransformToLocalVec(tempMapTableShapeTrans, UiPixelToWorld(UiGetMousePos()))
				local camLocalPos = TransformToLocalPoint(tempMapTableShapeTrans, tempCamTrans.pos)
				local camDirScale = (mapTableThickness-camLocalPos[2])/mousePointingDir[2]
				mapLineEndPos = {camLocalPos[1]+mousePointingDir[1]*camDirScale, camLocalPos[3]+mousePointingDir[3]*camDirScale}
			end
			local tempMapLineLenX = mapLineEndPos[1]-mapLineStartPos[1]
			local tempMapLineLenY = mapLineEndPos[2]-mapLineStartPos[2]
			local tempMapLineLength = math.sqrt(tempMapLineLenX*tempMapLineLenX+tempMapLineLenY*tempMapLineLenY)
			mapLineMarkerPos = (tempMapLineLength-0.1)/tempMapLineLength
			ServerCall("server.playerDrawMapLine", clientLocalPlayerId, mapLineStartPos, mapLineEndPos, mapLineType, mapLineMarkerPos)
		elseif InputReleased("usetool") then
			ServerCall("server.playerFinishMapLine", clientLocalPlayerId)
			clientLocalResetMapDrawing()
		end
	UiPop()
end

function clientLocalResetMapDrawing()
	mapWasDrawing = false
	mapLineStartPos = {}
	mapLineEndPos = {}
	mapLineType = 0
	mapLineMarkerPos = 0
end

function client.updateMapLineMarkerPos(lineIndex)
	if not clientLocalTrackMapLineList[lineIndex] then return end
	clientLocalTrackMapLineList[lineIndex] = false
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
	ClientCall(0, "client.updateMapLineMarkerPos", lineIndex)
end

function server.clearMapLine(lineIndex)
	if not shared.mapLineList[lineIndex] then return end
	shared.mapLineList[lineIndex] = nil
end