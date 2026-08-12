function init()
	drawInit = false
	r, g, b = 1, 1, 1
end

function draw()
	DebugCross(GetShapeWorldTransform(GetScreenShape(UiGetScreen())).pos)
	DrawShapeOutline(GetScreenShape(UiGetScreen()), 1)
	UiPush()
		UiAlign("middle center")
		UiColor(r, g, b, 1)
		UiTranslate(UiCenter(), UiMiddle())
		UiRect(UiWidth(), UiHeight())
	UiPop()
	if drawInit then return end
	drawInit = true
	math.randomseed(UiGetScreen())
	r, g, b = math.random(), math.random(), math.random()
end