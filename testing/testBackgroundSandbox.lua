function init()
	initDone = false
	imagePathStr = ""
	imageValid = false
	scaleX, scaleY = 1, 1
	pixelsPerMetre = 10
	subMapIndex = 0
	pixelOffX, pixelOffY = 0, 0
	coordOffX, coordOffY = 0, 0

	mapTableShape = FindShape("INmapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape) -- magicavoxel z up
	mapTableThickness = mapTableVY*mapTableScale

	ownMapLineList = {}
	ownMapLineSkipList = {}
	ownMapLineValidMax = 1
	ownMapLineRemoveMax = 1
	ownMapLineFirstIndex = 1

	mapScaleRatio = 10
	lineWidth = 4
	labelSize = 24
	labelSpacing = 12
	labelApproxSize = 150
	lineHalfWidth = lineWidth/2
end

function initDraw()
	local screenSelf = UiGetScreen()
	imagePathStr = GetTagValue(screenSelf, "imagePath")
	imageValid = UiHasImage(imagePathStr)
	if not imageValid then initDone = true return end
	local allSubMaps = FindScreens("INsubMap", true)
	local subMapChunks = #allSubMaps
	local subMapChunkSide = math.sqrt(subMapChunks)
	for i=1, subMapChunks do
		local tempCheckSubMap = allSubMaps[i]
		if tempCheckSubMap == screenSelf then subMapIndex = i-1 break end
	end
	local imageW, imageH = UiGetImageSize(imagePathStr)
	local screenW, screenH = GetProperty(screenSelf, "resolution")
	screenSize = GetProperty(screenSelf, "size")
	scaleX, scaleY = subMapChunkSide*screenW/imageW, subMapChunkSide*screenH/imageH
	local cropImgUnitX, cropImgUnitY = imageW/subMapChunkSide, imageH/subMapChunkSide
	local cropSubX, cropSubY = subMapIndex%subMapChunkSide, math.floor(subMapIndex/subMapChunkSide)
	cropImgX0, cropImgY0 = cropSubX*cropImgUnitX, cropSubY*cropImgUnitY
	cropImgX1, cropImgY1 = cropImgX0+cropImgUnitX, cropImgY0+cropImgUnitY
	pixelOffX, pixelOffY = cropSubX*screenW, cropSubY*screenH
	coordOffX, coordOffY = cropSubX*screenSize[1], cropSubY*screenSize[2]
	pixelsPerMetre = screenW/screenSize[1]
	labelApproxSizeMetre = labelApproxSize/pixelsPerMetre
	lineSizeMetre = lineWidth/pixelsPerMetre
	initDone = true
end

function draw()
	if not initDone then initDraw() end
	if not imageValid then return end
	UiPush()
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle())
		UiColor(0.32, 0.32, 0.32, 1)
		UiScale(scaleX, scaleY)
		UiImage(imagePathStr, cropImgX0, cropImgY0, cropImgX1, cropImgY1)
	UiPop()

	-- map lines
	local allMapLineIndex = GetInt("ironNest.mapLineIndex")
	local mapLineStartIndex = math.min(ownMapLineValidMax, ownMapLineRemoveMax, ownMapLineFirstIndex)
	for i=mapLineStartIndex, allMapLineIndex do
		repeat
			local tempCheckLine = HasKey("ironNest.mapLine."..i)
			local tempCheckLocalLine = ownMapLineList[i]
			if tempCheckLine and not tempCheckLocalLine then
				local tempStartPos = {GetFloat("ironNest.mapLine."..i..".startPos.x"), GetFloat("ironNest.mapLine."..i..".startPos.y")}
				local tempEndPos = {GetFloat("ironNest.mapLine."..i..".endPos.x"), GetFloat("ironNest.mapLine."..i..".endPos.y")}
				local tempLineType = GetInt("ironNest.mapLine."..i..".lineType")
				local tempMarkerPos = GetFloat("ironNest.mapLine."..i..".markerPos")
				local tempLineX, tempLineY = tempEndPos[2]-tempStartPos[2], tempEndPos[1]-tempStartPos[1]
				
				-- check for line
				local checkX0, checkY0 = tempStartPos[1]-coordOffX, tempStartPos[2]-coordOffY
				local checkX1, checkY1 = tempEndPos[1]-coordOffX, tempEndPos[2]-coordOffY
				local checkUpperX, checkUpperY = screenSize[1]+lineSizeMetre, screenSize[2]+lineSizeMetre
				local checkBitX0 = (checkX0 > checkUpperX) and 1 or (checkX0 < -lineSizeMetre) and -1 or 0
				local checkBitY0 = (checkY0 > checkUpperY) and 1 or (checkY0 < -lineSizeMetre) and -1 or 0
				local checkBitX1 = (checkX1 > checkUpperX) and 1 or (checkX1 < -lineSizeMetre) and -1 or 0
				local checkBitY1 = (checkY1 > checkUpperY) and 1 or (checkY1 < -lineSizeMetre) and -1 or 0
				repeat
					if (checkBitX0+checkBitY0 == checkBitX0*checkBitY0) or (checkBitX1+checkBitY1 == checkBitX1*checkBitY1) then break end
					local checkP0, checkP1 = {checkX0, checkY0}, {checkX1, checkY1}
					local checkIntersectionA = CalculateSegmentIntersection2d({-lineSizeMetre, -lineSizeMetre}, {checkUpperX, checkUpperY}, checkP0, checkP1)
					local checkIntersectionB = CalculateSegmentIntersection2d({-lineSizeMetre, checkUpperY}, {checkUpperX, -lineSizeMetre}, checkP0, checkP1)
					if (checkIntersectionA <= 1 and checkIntersectionA >= 0) or (checkIntersectionB <= 1 and checkIntersectionB >= 0) then break end
					ownMapLineList[i] = true
					ownMapLineSkipList[i] = true
				until true

				-- check for label
				repeat
					if not ownMapLineSkipList[i] then break end
					ownMapLineList[i] = nil
					ownMapLineSkipList[i] = nil
					local checkLabelX, checkLabelY = checkX0*(1-tempMarkerPos)+checkX1*tempMarkerPos, checkY0*(1-tempMarkerPos)+checkY1*tempMarkerPos
					local checkUpperX, checkUpperY = screenSize[1]+labelApproxSizeMetre, screenSize[2]+labelApproxSizeMetre
					local checkBitX0 = (checkX0 > checkUpperX) and 1 or (checkX0 < -labelApproxSizeMetre) and -1 or 0
					local checkBitY0 = (checkY0 > checkUpperY) and 1 or (checkY0 < -labelApproxSizeMetre) and -1 or 0
					local checkBitX1 = (checkX1 > checkUpperX) and 1 or (checkX1 < -labelApproxSizeMetre) and -1 or 0
					local checkBitY1 = (checkY1 > checkUpperY) and 1 or (checkY1 < -labelApproxSizeMetre) and -1 or 0
					if (checkBitX0+checkBitY0 == checkBitX0*checkBitY0) or (checkBitX1+checkBitY1 == checkBitX1*checkBitY1) then break end
					ownMapLineList[i] = true
					ownMapLineSkipList[i] = true
				until true

				if ownMapLineSkipList[i] then break end
				local tempStartPixelPos = {tempStartPos[1]*pixelsPerMetre-pixelOffX, tempStartPos[2]*pixelsPerMetre-pixelOffY}
				local tempLineLen = math.sqrt(tempLineX*tempLineX+tempLineY*tempLineY)*pixelsPerMetre
				local tempLineAngle = math.deg(math.atan2(tempLineX, tempLineY))*-1 -- UI is anticlockwise
				ownMapLineList[i] = {tempLineType, tempMarkerPos, tempStartPixelPos, tempLineLen, tempLineAngle}
				ownMapLineValidMax = math.max(ownMapLineValidMax, i)
			elseif tempCheckLocalLine and not tempCheckLine then
				ownMapLineList[i] = nil
				ownMapLineSkipList[i] = nil
				ownMapLineRemoveMax = math.max(ownMapLineRemoveMax, i)
			end
			local drawMapLine = ownMapLineList[i]
			if not drawMapLine then
				if mapLineStartIndex == i then ownMapLineFirstIndex = math.huge end
				break
			end
			if ownMapLineSkipList[i] then break end
			ownMapLineFirstIndex = math.min(ownMapLineFirstIndex, i)
			local startX, startY = drawMapLine[3][1], drawMapLine[3][2]
			local lineRot = drawMapLine[5]
			local lineLen = drawMapLine[4]
			local markerPos = lineLen*drawMapLine[2]
			local lineDist = lineLen/pixelsPerMetre*mapScaleRatio
			UiPush()
				UiTranslate(startX, startY)
				UiRotate(lineRot)
				UiPush()
					UiAlign("left middle")
					UiTranslate(-lineHalfWidth, 0)
					UiRoundedRect(lineLen+lineWidth, lineWidth, lineHalfWidth)
				UiPop()
				UiPush()
					UiTranslate(markerPos, 0)
					local displayBearing = (450-lineRot)%360
					if displayBearing > 180 then UiRotate(180) end
					UiFont("regular.ttf", labelSize)
					UiPush()
						UiTranslate(0, -labelSpacing)
						UiAlign("center bottom")
						UiText(string.format("%.2f km", lineDist))
					UiPop()
					UiPush()
						UiTranslate(0, labelSpacing)
						UiAlign("center top")
						UiText(string.format("%.1f°", displayBearing))
					UiPop()
				UiPop()
			UiPop()
		until true
	end

	-- player drawing map lines
	local allPlayerMapLines = ListKeys("ironNest.playerMapLine")
	for ip=1, #allPlayerMapLines do
		local tempCheckKey = "ironNest.playerMapLine."..allPlayerMapLines[ip]
		local tempStartPos = {GetFloat(tempCheckKey..".startPos.x"), GetFloat(tempCheckKey..".startPos.y")}
		local tempEndPos = {GetFloat(tempCheckKey..".endPos.x"), GetFloat(tempCheckKey..".endPos.y")}
		local tempLineType = GetInt(tempCheckKey..".lineType")
		local tempMarkerPos = GetFloat(tempCheckKey..".markerPos")
		local tempLineX, tempLineY = tempEndPos[2]-tempStartPos[2], tempEndPos[1]-tempStartPos[1]
		local startX, startY = tempStartPos[1]*pixelsPerMetre-pixelOffX, tempStartPos[2]*pixelsPerMetre-pixelOffY
		local lineLen = math.sqrt(tempLineX*tempLineX+tempLineY*tempLineY)*pixelsPerMetre
		local lineRot = math.deg(math.atan2(tempLineX, tempLineY))*-1 -- UI is anticlockwise
		local markerPos = lineLen*tempMarkerPos
		local lineDist = lineLen/pixelsPerMetre*mapScaleRatio
		UiPush()
			UiTranslate(startX, startY)
			UiRotate(lineRot)
			UiPush()
				UiAlign("left middle")
				UiTranslate(-lineHalfWidth, 0)
				UiRoundedRect(lineLen+lineWidth, lineWidth, lineHalfWidth)
			UiPop()
			UiPush()
				UiTranslate(markerPos, 0)
				local displayBearing = (450-lineRot)%360
				if displayBearing > 180 then UiRotate(180) end
				UiFont("regular.ttf", labelSize)
				UiPush()
					UiTranslate(0, -labelSpacing)
					UiAlign("center bottom")
					UiText(string.format("%.2f km", lineDist))
				UiPop()
				UiPush()
					UiTranslate(0, labelSpacing)
					UiAlign("center top")
					UiText(string.format("%.1f°", displayBearing))
				UiPop()
			UiPop()
		UiPop()
	end
end

function CalculateSegmentIntersection2d(p0, p1, p2, p3)
	local x0, x1, x2, x3 = p0[1], p1[1], p2[1], p3[1]
	local y0, y1, y2, y3 = p0[2], p1[2], p2[2], p3[2]
	local tempA = (y3-y2)*(x0-x2)+(x3-x2)*(y2-y0)
	local tempB = (x3-x2)*(y1-y0)-(y3-y2)*(x1-x0)
	return tempA/tempB
end
