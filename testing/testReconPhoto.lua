local MAP_IMAGE = "ui/terminal/map.jpg"
local MAP_WIDTH_METERS = 3.2
local MAP_HEIGHT_METERS = 1.8
local MAP_IMAGE_WIDTH_PIXELS = 1920
local MAP_IMAGE_HEIGHT_PIXELS = 1080
local MAP_METERS_PER_PIXEL_X = MAP_WIDTH_METERS / MAP_IMAGE_WIDTH_PIXELS
local MAP_METERS_PER_PIXEL_Z = MAP_HEIGHT_METERS / MAP_IMAGE_HEIGHT_PIXELS
local MAP_IMAGE_CENTER_X = MAP_IMAGE_WIDTH_PIXELS * 0.5
local MAP_IMAGE_CENTER_Y = MAP_IMAGE_HEIGHT_PIXELS * 0.5

local PHOTO_SCREEN_WIDTH_METERS = 0.6
local PHOTO_SCREEN_HEIGHT_METERS = 0.4
local PHOTO_BORDER_SLICE = 4
local PHOTO_SOURCE_PADDING_PIXELS = 2
local PHOTO_BORDER_IMAGE = "ui/common/checkbox_empty_ico.png"

local activePhotoConfig = nil

local function calculateSourceCrop(centreX, centreY, cosRot, sinRot)
	local sourceMinX = math.huge
	local sourceMinY = math.huge
	local sourceMaxX = -math.huge
	local sourceMaxY = -math.huge

	for cornerX = -1, 1, 2 do
		for cornerY = -1, 1, 2 do
			local localX = cornerX * PHOTO_SCREEN_WIDTH_METERS/2
			local localZ = cornerY * PHOTO_SCREEN_HEIGHT_METERS/2
			local mapX = centreX + localX * cosRot - localZ * sinRot
			local mapZ = centreY + localX * sinRot + localZ * cosRot
			local sourceX = MAP_IMAGE_CENTER_X + mapX / MAP_METERS_PER_PIXEL_X
			local sourceY = MAP_IMAGE_CENTER_Y + mapZ / MAP_METERS_PER_PIXEL_Z

			sourceMinX = math.min(sourceMinX, sourceX)
			sourceMinY = math.min(sourceMinY, sourceY)
			sourceMaxX = math.max(sourceMaxX, sourceX)
			sourceMaxY = math.max(sourceMaxY, sourceY)
		end
	end

	local cropX0 = math.max(0, math.floor(sourceMinX - PHOTO_SOURCE_PADDING_PIXELS))
	local cropY0 = math.max(0, math.floor(sourceMinY - PHOTO_SOURCE_PADDING_PIXELS))
	local cropX1 = math.min(
		MAP_IMAGE_WIDTH_PIXELS,
		math.ceil(sourceMaxX + PHOTO_SOURCE_PADDING_PIXELS)
	)
	local cropY1 = math.min(
		MAP_IMAGE_HEIGHT_PIXELS,
		math.ceil(sourceMaxY + PHOTO_SOURCE_PADDING_PIXELS)
	)

	return cropX0, cropY0, cropX1, cropY1
end

local function initPhoto()
	local currentScreen = UiGetScreen()
	local parentShape = GetScreenShape(currentScreen)
	local xSize, ySize, zSize, shapeScale = GetShapeSize(parentShape) -- magicaVoxel z up
	local shapeLocalTrans = GetShapeLocalTransform(parentShape)
	local reconCentrePos = TransformToParentPoint(shapeLocalTrans, Vec(xSize*shapeScale/2, ySize*shapeScale/2, 0)) -- magicaVoxel z up
	local screenSize = GetProperty(currentScreen, "size")
	PHOTO_SCREEN_WIDTH_METERS = screenSize[1]
	PHOTO_SCREEN_HEIGHT_METERS = screenSize[2]

	local reconX, reconZ = reconCentrePos[1], reconCentrePos[3]
	local _, reconRot = GetQuatEuler(shapeLocalTrans.rot)
	local reconRotRad = math.rad(reconRot)
	local cosRot = math.cos(reconRotRad)
	local sinRot = math.sin(reconRotRad)
	local cropX0, cropY0, cropX1, cropY1 = calculateSourceCrop(reconX, reconZ, cosRot, sinRot)

	return {
		rot = reconRot,
		mapOffsetX = -reconX * cosRot + reconZ * sinRot,
		mapOffsetZ = -reconX * sinRot - reconZ * cosRot,
		cropX0 = cropX0,
		cropY0 = cropY0,
		cropX1 = cropX1,
		cropY1 = cropY1,
		cropOffsetX = (cropX0 + cropX1) * 0.5 - MAP_IMAGE_CENTER_X,
		cropOffsetY = (cropY0 + cropY1) * 0.5 - MAP_IMAGE_CENTER_Y,
	}
end

local function drawMapFragment(config, canvasWidth, canvasHeight)
	local screenPixelsPerMeterX = canvasWidth / PHOTO_SCREEN_WIDTH_METERS
	local screenPixelsPerMeterZ = canvasHeight / PHOTO_SCREEN_HEIGHT_METERS
	-- Screen positions use their geometric center, while UI coordinates start at the top-left.
	local imageCenterX = canvasWidth * 0.5 + config.mapOffsetX * screenPixelsPerMeterX
	local imageCenterY = canvasHeight * 0.5 + config.mapOffsetZ * screenPixelsPerMeterZ

	UiPush()
		UiTranslate(imageCenterX, imageCenterY)
		UiScale(screenPixelsPerMeterX, screenPixelsPerMeterZ)
		UiRotate(-config.rot)
		UiScale(MAP_METERS_PER_PIXEL_X, MAP_METERS_PER_PIXEL_Z)
		-- Preserve each source pixel's full-map position while avoiding rotated-image culling.
		UiTranslate(config.cropOffsetX, config.cropOffsetY)
		UiAlign("center middle")
		UiColor(1, 1, 1, 1)
		UiImage(MAP_IMAGE, config.cropX0, config.cropY0, config.cropX1, config.cropY1)
	UiPop()
end

local function drawPhotoBorder(width, height)
	UiPush()
		UiAlign("left top")
		UiColor(1, 1, 1, 1)
		UiImageBox(PHOTO_BORDER_IMAGE, width, height, PHOTO_BORDER_SLICE, PHOTO_BORDER_SLICE)
	UiPop()
end

function draw()
	if not activePhotoConfig then
		activePhotoConfig = initPhoto()
	end

	local canvasWidth = UiWidth()
	local canvasHeight = UiHeight()
	if activePhotoConfig then
		drawMapFragment(activePhotoConfig, canvasWidth, canvasHeight)
	end
	drawPhotoBorder(canvasWidth, canvasHeight)
end
