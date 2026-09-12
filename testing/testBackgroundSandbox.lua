function init()
	initDone = false
	imagePathStr = ""
	imageValid = false
	scaleX, scaleY = 1, 1
	pixelsPerMetre = 10

	mapTableShape = FindShape("mapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape) -- magicavoxel z up
	mapTableThickness = mapTableVY*mapTableScale
	ownMapLineList = {}
	ownMapLineValidMax = 1
	ownMapLineRemoveMax = 1
	ownMapLineFirstIndex = 1

	mapScaleRatio = 10
	lineWidth = 2
	labelSize = 12
	labelSpacing = 6
	lineHalfWidth = lineWidth/2
end

function initDraw()
	local screenSelf = UiGetScreen()
	imagePathStr = GetTagValue(screenSelf, "imagePath")
	imageValid = UiHasImage(imagePathStr)
	if not imageValid then initDone = true return end
	local imageW, imageH = UiGetImageSize(imagePathStr)
	local screenW, screenH = GetProperty(screenSelf, "resolution")
	local screenSize = GetProperty(screenSelf, "size")
	scaleX, scaleY = screenW/imageW, screenH/imageH
	pixelsPerMetre = screenW/screenSize[1]
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
		UiImage(imagePathStr)
	UiPop()

	-- map lines
	local allMapLineIndex = GetInt("ironNest.mapLineIndex")
	local mapLineStartIndex = math.min(ownMapLineValidMax, ownMapLineRemoveMax, ownMapLineFirstIndex)
	for i=mapLineStartIndex, allMapLineIndex do
		local tempCheckLine = HasKey("ironNest.mapLine."..i)
		local tempCheckLocalLine = ownMapLineList[i]
		if tempCheckLine and not tempCheckLocalLine then
			local tempStartPos = {GetFloat("ironNest.mapLine."..i..".startPos.x"), GetFloat("ironNest.mapLine."..i..".startPos.y")}
			local tempEndPos = {GetFloat("ironNest.mapLine."..i..".endPos.x"), GetFloat("ironNest.mapLine."..i..".endPos.y")}
			local tempLineType = GetInt("ironNest.mapLine."..i..".lineType")
			local tempMarkerPos = GetFloat("ironNest.mapLine."..i..".markerPos")
			local tempLineX, tempLineY = tempEndPos[2]-tempStartPos[2], tempEndPos[1]-tempStartPos[1]
			local tempStartPixelPos = {tempStartPos[1]*pixelsPerMetre, tempStartPos[2]*pixelsPerMetre}
			local tempLineLen = math.sqrt(tempLineX*tempLineX+tempLineY*tempLineY)*pixelsPerMetre
			local tempLineAngle = math.deg(math.atan2(tempLineX, tempLineY))*-1 -- UI is anticlockwise for some reasons
			ownMapLineList[i] = {tempStartPos, tempEndPos, tempLineType, tempMarkerPos, tempStartPixelPos, tempLineLen, tempLineAngle}
			ownMapLineValidMax = math.max(ownMapLineValidMax, i)
		elseif tempCheckLocalLine and not tempCheckLine then
			ownMapLineList[i] = nil
			ownMapLineRemoveMax = math.max(ownMapLineRemoveMax, i)
		end
		local drawMapLine = ownMapLineList[i]
		repeat
			if not drawMapLine then
				if mapLineStartIndex == i then ownMapLineFirstIndex = math.huge end
				break
			end
			ownMapLineFirstIndex = math.min(ownMapLineFirstIndex, i)
			local startX, startY = drawMapLine[5][1], drawMapLine[5][2]
			local lineRot = drawMapLine[7]
			local lineLen = drawMapLine[6]
			local markerPos = lineLen*drawMapLine[4]
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
					UiFont("regular.ttf", labelSize)
					UiPush()
						UiTranslate(0, -labelSpacing)
						UiAlign("center bottom")
						UiText(string.format("%.2f km", lineDist))
					UiPop()
					UiPush()
						UiTranslate(0, labelSpacing)
						UiAlign("center top")
						UiText(string.format("%.1f°", (450-lineRot)%360))
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
		local startX, startY = tempStartPos[1]*pixelsPerMetre, tempStartPos[2]*pixelsPerMetre
		local lineLen = math.sqrt(tempLineX*tempLineX+tempLineY*tempLineY)*pixelsPerMetre
		local lineRot = math.deg(math.atan2(tempLineX, tempLineY))*-1 -- UI is anticlockwise for some reasons
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
				UiFont("regular.ttf", labelSize)
				UiPush()
					UiTranslate(0, -labelSpacing)
					UiAlign("center bottom")
					UiText(string.format("%.2f km", lineDist))
				UiPop()
				UiPush()
					UiTranslate(0, labelSpacing)
					UiAlign("center top")
					UiText(string.format("%.1f°", (450-lineRot)%360))
				UiPop()
			UiPop()
		UiPop()
	end
end
