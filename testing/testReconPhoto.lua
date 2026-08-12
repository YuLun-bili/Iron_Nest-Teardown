#version 2

local MAP_IMAGE = "ui/terminal/map.jpg"
local PHOTO_BORDER_IMAGE = "MOD/checkbox_empty_ico.png"
local MAP_WIDTH_METERS = 3.2
local MAP_HEIGHT_METERS = 1.8
local MAP_IMAGE_WIDTH_PIXELS = 1920
local MAP_IMAGE_HEIGHT_PIXELS = 1080
local PHOTO_SCREEN_WIDTH_METERS = 0.6
local PHOTO_SCREEN_HEIGHT_METERS = 0.4
local PHOTO_SCREEN_HALF_WIDTH_METERS = PHOTO_SCREEN_WIDTH_METERS * 0.5
local PHOTO_SCREEN_HALF_HEIGHT_METERS = PHOTO_SCREEN_HEIGHT_METERS * 0.5
local PHOTO_BORDER_SLICE = 4
local PHOTO_SOURCE_PADDING_PIXELS = 2
local MAP_METERS_PER_PIXEL_X = MAP_WIDTH_METERS / MAP_IMAGE_WIDTH_PIXELS
local MAP_METERS_PER_PIXEL_Z = MAP_HEIGHT_METERS / MAP_IMAGE_HEIGHT_PIXELS
local MAP_IMAGE_CENTER_X = MAP_IMAGE_WIDTH_PIXELS * 0.5
local MAP_IMAGE_CENTER_Y = MAP_IMAGE_HEIGHT_PIXELS * 0.5

local PHOTO_CONFIGS = {
	{ tag = "recon_photo_01", x = -1.20, z = -0.48, yaw =  -75.0 },
	{ tag = "recon_photo_02", x = -0.72, z = -0.48, yaw =  -45.0 },
	{ tag = "recon_photo_03", x = -0.24, z = -0.48, yaw =  -15.0 },
	{ tag = "recon_photo_04", x =  0.24, z = -0.48, yaw =   15.0 },
	{ tag = "recon_photo_05", x =  0.72, z = -0.48, yaw =   45.0 },
	{ tag = "recon_photo_06", x =  1.20, z = -0.48, yaw =   75.0 },
	{ tag = "recon_photo_07", x = -1.20, z =  0.00, yaw = -150.0 },
	{ tag = "recon_photo_08", x = -0.72, z =  0.00, yaw = -120.0 },
	{ tag = "recon_photo_09", x = -0.24, z =  0.00, yaw =  -90.0 },
	{ tag = "recon_photo_10", x =  0.24, z =  0.00, yaw =  -60.0 },
	{ tag = "recon_photo_11", x =  0.72, z =  0.00, yaw =  -30.0 },
	{ tag = "recon_photo_12", x =  1.20, z =  0.00, yaw =    0.0 },
	{ tag = "recon_photo_13", x = -1.20, z =  0.48, yaw =  150.0 },
	{ tag = "recon_photo_14", x = -0.72, z =  0.48, yaw =  120.0 },
	{ tag = "recon_photo_15", x = -0.24, z =  0.48, yaw =   90.0 },
	{ tag = "recon_photo_16", x =  0.24, z =  0.48, yaw =   60.0 },
	{ tag = "recon_photo_17", x =  0.72, z =  0.48, yaw =   30.0 },
	{ tag = "recon_photo_18", x =  1.20, z =  0.48, yaw =  180.0 },
}

local activePhotoConfig = nil

local function calculateSourceCrop(config, cosYaw, sinYaw)
	local sourceMinX = math.huge
	local sourceMinY = math.huge
	local sourceMaxX = -math.huge
	local sourceMaxY = -math.huge

	for cornerX = -1, 1, 2 do
		for cornerY = -1, 1, 2 do
			local localX = cornerX * PHOTO_SCREEN_HALF_WIDTH_METERS
			local localZ = cornerY * PHOTO_SCREEN_HALF_HEIGHT_METERS
			local mapX = config.x + localX * cosYaw - localZ * sinYaw
			local mapZ = config.z + localX * sinYaw + localZ * cosYaw
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

local function preparePhotoConfig(config)
	local yaw = math.rad(config.yaw)
	local cosYaw = math.cos(yaw)
	local sinYaw = math.sin(yaw)
	local cropX0, cropY0, cropX1, cropY1 = calculateSourceCrop(config, cosYaw, sinYaw)

	return {
		yaw = config.yaw,
		mapOffsetX = -config.x * cosYaw + config.z * sinYaw,
		mapOffsetZ = -config.x * sinYaw - config.z * cosYaw,
		cropX0 = cropX0,
		cropY0 = cropY0,
		cropX1 = cropX1,
		cropY1 = cropY1,
		cropOffsetX = (cropX0 + cropX1) * 0.5 - MAP_IMAGE_CENTER_X,
		cropOffsetY = (cropY0 + cropY1) * 0.5 - MAP_IMAGE_CENTER_Y,
	}
end

local function resolvePhotoConfig()
	local currentScreen = UiGetScreen()
	for i = 1, #PHOTO_CONFIGS do
		local config = PHOTO_CONFIGS[i]
		if FindScreen(config.tag, true) == currentScreen then
			return preparePhotoConfig(config)
		end
	end
	return nil
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
		UiRotate(-config.yaw)
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
		UiImageBox(
			PHOTO_BORDER_IMAGE,
			width,
			height,
			PHOTO_BORDER_SLICE,
			PHOTO_BORDER_SLICE
		)
	UiPop()
end

function draw()
	if not activePhotoConfig then
		activePhotoConfig = resolvePhotoConfig()
	end

	local canvasWidth = UiWidth()
	local canvasHeight = UiHeight()
	if activePhotoConfig then
		drawMapFragment(activePhotoConfig, canvasWidth, canvasHeight)
	end
	drawPhotoBorder(canvasWidth, canvasHeight)
end
