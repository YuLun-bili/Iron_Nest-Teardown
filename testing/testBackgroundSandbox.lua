#version 2

local MAP_IMAGE = "ui/terminal/map.jpg"
local MAP_IMAGE_WIDTH_PIXELS = 1920
local MAP_IMAGE_HEIGHT_PIXELS = 1080

function draw()
	UiPush()
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle())
		UiScale(
			UiWidth() / MAP_IMAGE_WIDTH_PIXELS,
			UiHeight() / MAP_IMAGE_HEIGHT_PIXELS
		)
		UiImage(MAP_IMAGE)
	UiPop()
end
