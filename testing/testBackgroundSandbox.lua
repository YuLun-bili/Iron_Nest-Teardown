function init()
	initDone = false
	imagePathStr = ""
	imageValid = false
	scaleX, scaleY = 1, 1
end

function initDraw()
	local screenSelf = UiGetScreen()
	imagePathStr = GetTagValue(screenSelf, "imagePath")
	imageValid = UiHasImage(imagePathStr)
	if not imageValid then initDone = true return end
	local imageW, imageH = UiGetImageSize(imagePathStr)
	local screenW, screenH = GetProperty(screenSelf, "resolution")
	scaleX, scaleY = screenW/imageW, screenH/imageH
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
end
