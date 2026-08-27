function init()
	initDone = false
	imagePathStr = ""
	imageValid = false
	scaleX, scaleY = 1, 1
	pixelsPerMetre, pixelsPerMetre = 10, 10

	mapTableShape = FindShape("mapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape) -- magicavoxel z up
	mapTableThickness = mapTableVY*mapTableScale
	ownMapLineList = {}
	ownPlayerMapLineList = {}
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

	local allMapLineIndex = GetInt("ironNest.mapLineIndex")
	for i=1, allMapLineIndex do
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
		elseif tempCheckLocalLine and not tempCheckLine then
			ownMapLineList[i] = nil
		end
	end
	for i=1, allMapLineIndex do
		local drawMapLine = ownMapLineList[i]
		if drawMapLine then
			UiPush()
				UiTranslate(drawMapLine[5][1], drawMapLine[5][2])
				UiRotate(drawMapLine[7])
				UiPush()
					UiAlign("left middle")
					UiTranslate(-2, 0)
					UiRoundedRect(drawMapLine[6], 4, 2)
					UiAlign("center bottom")
					UiTranslate(2+drawMapLine[4]*drawMapLine[6], -6)
					UiFont("regular.ttf", 20)
					UiText(string.format("%.2f", drawMapLine[6]/10))
				UiPop()
			UiPop()
		end
	end
end
