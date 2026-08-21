local TOOL_ID = "iron_nest_map_arrow"
local TOOL_NAME = "Map Pens"
local TOOL_GROUP = 2
local PREVIOUS_MODE_INPUT = "leftarrow"
local NEXT_MODE_INPUT = "rightarrow"

local MAP_BODY_TAG = "iron_nest_map"
local MAP_PLANE_TAG = "iron_nest_map_plane"
local MAP_SCREEN_TAG = "iron_nest_map_screen"
local MAP_LABEL_TAG = "iron_nest_map_label"

local RAYCAST_DISTANCE = 10
local PLANE_EPSILON = 0.0001
local MIN_VALID_ARROW_LENGTH = 0.01
local MIN_VALID_COMPASS_RADIUS = 0.01
local MAP_ELEMENT_DELETE_DISTANCE = 0.02
local MAP_LABEL_PICK_DISTANCE = 0.18
local MAP_LABEL_HALF_WIDTH = 0.15
local MAP_LABEL_HALF_HEIGHT = 0.1
local SPRITE_SURFACE_OFFSET = 0.002
local COMPASS_GUIDE_SURFACE_OFFSET = 0.0025
local COMPASS_SURFACE_OFFSET = 0.003
local BORDER_SURFACE_OFFSET = 0.0035
local MAP_MARKER_SURFACE_OFFSET = 0.004
local ARROW_SPRITE_PIXEL_WIDTH = 32
local ARROW_SPRITE_PIXEL_HEIGHT = 32
local ARROW_SPRITE_SCALE = 0.5
local TEXT_SURFACE_OFFSET = 0.004
local COMPASS_TEXT_SURFACE_OFFSET = 0.006
local COMPASS_DASH_LENGTH_HEAD_SCALE = 3
local COMPASS_DASH_GAP_HEAD_SCALE = 1
local COMPASS_DASH_PIECE_COUNT = 3
local COMPASS_MIN_DASH_COUNT = 4
local COMPASS_MAX_DASH_COUNT = 64
local COMPASS_DASH_WIDTH_SCALE = 0.5
local COMPASS_PIECE_OVERLAP_HEAD_SCALE = 0.04
local GLYPH_CHARACTERS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz."
local GLYPH_SPRITE_SIZE = 0.04
local GLYPH_ADVANCE = 0.024
local LABEL_GAP = 0.04
local MAP_METERS_PER_KILOMETER = 0.05
local MEASUREMENT_LOG_LEFT = 24
local MEASUREMENT_LOG_TOP = 24
local MEASUREMENT_LOG_FONT_SIZE = 24
local MEASUREMENT_LOG_LINE_HEIGHT = 28
local MODE_INDICATOR_LEFT = 24
local MODE_INDICATOR_BOTTOM = 24
local MODE_INDICATOR_FONT_SIZE = 24
local DEGREE_SYMBOL = string.char(194, 176)

local DRAWING_MODES = {
	RED_PEN = "red",
	YELLOW_PEN = "yellow",
	WHITE_PEN = "white",
	COMPASS = "compass",
}

local DRAWING_MODE_ORDER = {
	DRAWING_MODES.RED_PEN,
	DRAWING_MODES.YELLOW_PEN,
	DRAWING_MODES.WHITE_PEN,
	DRAWING_MODES.COMPASS,
}

local DRAWING_MODE_NAMES = {
	[DRAWING_MODES.RED_PEN] = "Red Pen",
	[DRAWING_MODES.YELLOW_PEN] = "Yellow Pen",
	[DRAWING_MODES.WHITE_PEN] = "White Pen",
	[DRAWING_MODES.COMPASS] = "Compass",
}

local PEN_STYLES = {
	[DRAWING_MODES.RED_PEN] = {
		color = { red = 1, green = 0, blue = 0 },
		drawWorldMeasurement = true,
		recordUiMeasurement = true,
	},
	[DRAWING_MODES.YELLOW_PEN] = {
		color = { red = 1, green = 1, blue = 0 },
		drawWorldMeasurement = true,
		recordUiMeasurement = false,
	},
	[DRAWING_MODES.WHITE_PEN] = {
		color = { red = 1, green = 1, blue = 1 },
		drawWorldMeasurement = false,
		recordUiMeasurement = false,
	},
}

local COMPASS_COLOR = { red = 1, green = 1, blue = 1 }
local BLACK_BORDER_COLOR = { red = 0, green = 0, blue = 0 }
local DELETE_BORDER_COLOR = { red = 1, green = 0, blue = 0 }

local mapBody = 0
local mapPlane = 0
local mapScreen = 0
local mapPlaneLocalTransform = nil
local mapScreenWidth = 0
local mapScreenHeight = 0
local mapLabels = {}
local mapLabelsParentBody = 0
local activeMapLabel = nil
local arrows = {}
local compassCircles = {}
local measurementLogEntries = {}
local activeArrow = nil
local activeCompass = nil
local selectedModeIndex = 1
local nextElementId = 1
local deleteTargetType = nil
local deleteTargetId = 0

local arrowSprite = 0
local lineSprite = 0
local arrowBorderSprite = 0
local lineBorderSprite = 0
local compassDashSprites = {}
local compassDashBorderSprites = {}
local mapMarkerSprite = 0
local glyphSprites = {}
local arrowSpriteWidth = 0
local arrowSpriteHeight = 0
local entitySearchTimer = 0

local function readPairProperty(handle, property)
	local first, second = GetProperty(handle, property)
	if type(first) == "table" then
		return first[1], first[2]
	end
	return first, second
end

local function updateArrowSpriteSize()
	mapScreenWidth = 0
	mapScreenHeight = 0
	if mapScreen == 0 or not IsHandleValid(mapScreen) then return end

	local screenWidth, screenHeight = readPairProperty(mapScreen, "size")
	local resolutionWidth, resolutionHeight = readPairProperty(mapScreen, "resolution")
	if not screenWidth or not screenHeight or not resolutionWidth or not resolutionHeight then return end
	if resolutionWidth <= 0 or resolutionHeight <= 0 then return end

	mapScreenWidth = screenWidth
	mapScreenHeight = screenHeight
	arrowSpriteWidth = ARROW_SPRITE_PIXEL_WIDTH * screenWidth / resolutionWidth * ARROW_SPRITE_SCALE
	arrowSpriteHeight = ARROW_SPRITE_PIXEL_HEIGHT * screenHeight / resolutionHeight * ARROW_SPRITE_SCALE
end

local function findMapEntities()
	local previousBody = mapBody
	local previousPlane = mapPlane

	if mapBody == 0 or not IsHandleValid(mapBody) then
		mapBody = FindBody(MAP_BODY_TAG, true)
	end
	if mapPlane == 0 or not IsHandleValid(mapPlane) then
		mapPlane = FindLocation(MAP_PLANE_TAG, true)
	end
	if mapScreen == 0 or not IsHandleValid(mapScreen) then
		mapScreen = FindScreen(MAP_SCREEN_TAG, true)
		updateArrowSpriteSize()
	end

	if mapBody ~= 0 and IsHandleValid(mapBody) and mapPlane ~= 0 and IsHandleValid(mapPlane)
		and (not mapPlaneLocalTransform or mapBody ~= previousBody or mapPlane ~= previousPlane) then
		mapPlaneLocalTransform = TransformToLocalTransform(GetBodyTransform(mapBody), GetLocationTransform(mapPlane))
	end
end

local function mapIsReady()
	return mapBody ~= 0 and IsHandleValid(mapBody)
		and mapPlane ~= 0 and IsHandleValid(mapPlane)
		and mapPlaneLocalTransform ~= nil
end

local function getWorldEyeRay()
	local eyeTransform = GetPlayerEyeTransform()
	local direction = TransformToParentVec(eyeTransform, Vec(0, 0, -1))
	return eyeTransform.pos, VecNormalize(direction)
end

local function getWorldMapPlane()
	if not mapIsReady() then return nil, nil end

	local planeTransform = TransformToParentTransform(GetBodyTransform(mapBody), mapPlaneLocalTransform)
	local normal = TransformToParentVec(planeTransform, Vec(0, 0, 1))
	return planeTransform.pos, VecNormalize(normal)
end

local function getLocalMapAxes()
	if not mapIsReady() then return nil end
	return VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(1, 0, 0))),
		VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(0, 1, 0))),
		VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(0, 0, 1)))
end

local function forgetMapLabels()
	mapLabels = {}
	mapLabelsParentBody = 0
	activeMapLabel = nil
end

local function initializeMapLabels()
	forgetMapLabels()
	if not mapIsReady() then return end

	local mapTransform = GetBodyTransform(mapBody)
	local bodies = FindBodies(MAP_LABEL_TAG, true)
	table.sort(bodies)
	for i = 1, #bodies do
		local body = bodies[i]
		if body ~= mapBody and IsHandleValid(body) then
			mapLabels[#mapLabels + 1] = {
				body = body,
				localTransform = TransformToLocalTransform(mapTransform, GetBodyTransform(body)),
			}
		end
	end
	mapLabelsParentBody = mapBody
end

local function syncMapLabelsToMap()
	if not mapIsReady() or mapLabelsParentBody ~= mapBody then return end

	local mapTransform = GetBodyTransform(mapBody)
	for i = 1, #mapLabels do
		local label = mapLabels[i]
		if IsHandleValid(label.body) then
			SetBodyTransform(label.body,
				TransformToParentTransform(mapTransform, label.localTransform))
		end
	end
end

local function constrainMapLabelPoint(localPoint)
	if mapScreenWidth <= MAP_LABEL_HALF_WIDTH * 2
		or mapScreenHeight <= MAP_LABEL_HALF_HEIGHT * 2 then return end

	local mapRight, mapUp = getLocalMapAxes()
	if not mapRight then return end

	local relativePoint = VecSub(localPoint, mapPlaneLocalTransform.pos)
	local rightAmount = VecDot(relativePoint, mapRight)
	local upAmount = VecDot(relativePoint, mapUp)
	local screenHalfWidth = mapScreenWidth * 0.5
	local screenHalfHeight = mapScreenHeight * 0.5
	if math.abs(rightAmount) > screenHalfWidth + PLANE_EPSILON
		or math.abs(upAmount) > screenHalfHeight + PLANE_EPSILON then return end

	local maxRightAmount = screenHalfWidth - MAP_LABEL_HALF_WIDTH
	local maxUpAmount = screenHalfHeight - MAP_LABEL_HALF_HEIGHT
	rightAmount = math.max(-maxRightAmount, math.min(maxRightAmount, rightAmount))
	upAmount = math.max(-maxUpAmount, math.min(maxUpAmount, upAmount))
	return VecAdd(mapPlaneLocalTransform.pos, VecAdd(
		VecScale(mapRight, rightAmount),
		VecScale(mapUp, upAmount)
	))
end

local function intersectWorldRayWithMapPlane(origin, direction)
	if not mapIsReady() then return nil end

	local planePoint, planeNormal = getWorldMapPlane()
	if not planePoint then return nil end

	local denominator = VecDot(direction, planeNormal)
	if math.abs(denominator) < PLANE_EPSILON then return nil end

	local distance = VecDot(VecSub(planePoint, origin), planeNormal) / denominator
	if distance < 0 then return nil end

	local worldPoint = VecAdd(origin, VecScale(direction, distance))
	return TransformToLocalPoint(GetBodyTransform(mapBody), worldPoint)
end

local function projectWorldPointOntoMapPlane(worldPoint)
	if not mapIsReady() then return nil end

	local planePoint, planeNormal = getWorldMapPlane()
	if not planePoint then return nil end

	local height = VecDot(VecSub(worldPoint, planePoint), planeNormal)
	local projectedPoint = VecSub(worldPoint, VecScale(planeNormal, height))
	return TransformToLocalPoint(GetBodyTransform(mapBody), projectedPoint)
end

local function getArrowDirectionAndLength(data)
	local delta = VecSub(data.localEndPoint, data.localStartPoint)
	local length = VecLength(delta)
	if length <= PLANE_EPSILON then return nil, 0 end
	return VecScale(delta, 1 / length), length
end

local function calculateArrowMeasurement(direction, length, mapRight, mapUp)
	local bearingDegrees = math.deg(math.atan2(
		VecDot(direction, mapRight),
		VecDot(direction, mapUp)
	))
	if bearingDegrees < 0 then
		bearingDegrees = bearingDegrees + 360
	end

	bearingDegrees = math.floor(bearingDegrees * 10 + 0.5) / 10
	if bearingDegrees >= 360 then
		bearingDegrees = 0
	end

	return {
		bearingDegrees = bearingDegrees,
		distanceKilometers = length / MAP_METERS_PER_KILOMETER,
	}
end

local function formatMeasurementLogEntry(measurement)
	return string.format("%.1f%s/%.1fkm",
		measurement.bearingDegrees,
		DEGREE_SYMBOL,
		measurement.distanceKilometers
	)
end

local function getMapPointUnderCrosshair()
	if not mapIsReady() then return end

	local rayOrigin, rayDirection = getWorldEyeRay()
	for i = 1, #mapLabels do
		local labelBody = mapLabels[i].body
		if IsHandleValid(labelBody) then
			QueryRejectBody(labelBody)
		end
	end
	local hit, hitDistance, _, shape = QueryRaycast(rayOrigin, rayDirection, RAYCAST_DISTANCE)
	if not hit or shape == 0 or GetShapeBody(shape) ~= mapBody then return end

	local hitPoint = VecAdd(rayOrigin, VecScale(rayDirection, hitDistance))
	return projectWorldPointOntoMapPlane(hitPoint)
end

local function findNearestMapLabel(localPoint)
	local nearestLabel = nil
	local nearestDistance = MAP_LABEL_PICK_DISTANCE
	for i = 1, #mapLabels do
		local label = mapLabels[i]
		if IsHandleValid(label.body) then
			local distance = VecLength(VecSub(localPoint, label.localTransform.pos))
			if distance <= nearestDistance then
				nearestLabel = label
				nearestDistance = distance
			end
		end
	end
	return nearestLabel
end

local function beginMapLabelDrag()
	local localPoint = getMapPointUnderCrosshair()
	if not localPoint then return false end

	local constrainedPoint = constrainMapLabelPoint(localPoint)
	if not constrainedPoint then return false end

	local label = findNearestMapLabel(localPoint)
	if not label then return false end
	label.localTransform.pos = constrainedPoint
	activeMapLabel = label
	return true
end

local function updateActiveMapLabel()
	if not activeMapLabel or not IsHandleValid(activeMapLabel.body) then
		activeMapLabel = nil
		return
	end

	local localPoint = getMapPointUnderCrosshair()
	if not localPoint then return end
	local constrainedPoint = constrainMapLabelPoint(localPoint)
	if constrainedPoint then
		activeMapLabel.localTransform.pos = constrainedPoint
	end
end

local function beginMapDrawing()
	local localPoint = getMapPointUnderCrosshair()
	if not localPoint then return end

	local mode = DRAWING_MODE_ORDER[selectedModeIndex]
	if mode == DRAWING_MODES.COMPASS then
		activeCompass = {
			localCenterPoint = VecCopy(localPoint),
			localHeadPoint = VecCopy(localPoint),
		}
		return
	end

	activeArrow = {
		penType = mode,
		localStartPoint = VecCopy(localPoint),
		localEndPoint = VecCopy(localPoint),
	}
end

local function updateActiveDrawing()
	if not activeArrow and not activeCompass then return end

	local rayOrigin, rayDirection = getWorldEyeRay()
	local localPoint = intersectWorldRayWithMapPlane(rayOrigin, rayDirection)
	if not localPoint then return end

	if activeArrow then
		activeArrow.localEndPoint = localPoint
	else
		activeCompass.localHeadPoint = localPoint
	end
end

local function allocateElementId()
	local id = nextElementId
	nextElementId = nextElementId + 1
	return id
end

local function finishArrow()
	if not activeArrow then return end

	local direction, length = getArrowDirectionAndLength(activeArrow)
	if direction and length >= MIN_VALID_ARROW_LENGTH then
		local penStyle = PEN_STYLES[activeArrow.penType]
		activeArrow.id = allocateElementId()
		if penStyle.drawWorldMeasurement or penStyle.recordUiMeasurement then
			local mapRight, mapUp = getLocalMapAxes()
			activeArrow.measurement = calculateArrowMeasurement(direction, length, mapRight, mapUp)
		end
		arrows[#arrows + 1] = activeArrow
		if penStyle.recordUiMeasurement then
			measurementLogEntries[#measurementLogEntries + 1] = formatMeasurementLogEntry(
				activeArrow.measurement
			)
		end
	end
	activeArrow = nil
end

local function finishCompass()
	if not activeCompass then return end

	local radius = VecLength(VecSub(activeCompass.localHeadPoint, activeCompass.localCenterPoint))
	if radius >= MIN_VALID_COMPASS_RADIUS then
		activeCompass.id = allocateElementId()
		activeCompass.radius = radius
		activeCompass.radiusKilometers = radius / MAP_METERS_PER_KILOMETER
		compassCircles[#compassCircles + 1] = activeCompass
	end
	activeCompass = nil
end

local function finishActiveDrawing()
	if activeArrow then
		finishArrow()
	elseif activeCompass then
		finishCompass()
	end
end

local function cancelActiveDrawing()
	activeArrow = nil
	activeCompass = nil
end

local function isDrawing()
	return activeArrow ~= nil or activeCompass ~= nil
end

local function cycleSelectedMode(direction)
	selectedModeIndex = ((selectedModeIndex - 1 + direction) % #DRAWING_MODE_ORDER) + 1
end

local function distanceFromPointToSegment(point, startPoint, endPoint)
	local segment = VecSub(endPoint, startPoint)
	local lengthSquared = VecDot(segment, segment)
	if lengthSquared <= PLANE_EPSILON * PLANE_EPSILON then
		return VecLength(VecSub(point, startPoint))
	end

	local amount = VecDot(VecSub(point, startPoint), segment) / lengthSquared
	amount = math.max(0, math.min(1, amount))
	local nearestPoint = VecAdd(startPoint, VecScale(segment, amount))
	return VecLength(VecSub(point, nearestPoint))
end

local function clearDeleteTarget()
	deleteTargetType = nil
	deleteTargetId = 0
end

local function findNearestMapElement()
	local localPoint = getMapPointUnderCrosshair()
	if not localPoint then return end

	local bestType = nil
	local bestDistance = MAP_ELEMENT_DELETE_DISTANCE
	local bestId = -1

	for i = 1, #arrows do
		local arrow = arrows[i]
		local distance = distanceFromPointToSegment(
			localPoint, arrow.localStartPoint, arrow.localEndPoint
		)
		if distance <= MAP_ELEMENT_DELETE_DISTANCE
			and (distance < bestDistance
				or (math.abs(distance - bestDistance) <= PLANE_EPSILON and arrow.id > bestId)) then
			bestType = "arrow"
			bestDistance = distance
			bestId = arrow.id
		end
	end

	for i = 1, #compassCircles do
		local compass = compassCircles[i]
		local distance = math.abs(
			VecLength(VecSub(localPoint, compass.localCenterPoint)) - compass.radius
		)
		if distance <= MAP_ELEMENT_DELETE_DISTANCE
			and (distance < bestDistance
				or (math.abs(distance - bestDistance) <= PLANE_EPSILON and compass.id > bestId)) then
			bestType = "compass"
			bestDistance = distance
			bestId = compass.id
		end
	end

	return bestType, bestId
end

local function updateDeleteTarget()
	local elementType, elementId = findNearestMapElement()
	deleteTargetType = elementType
	deleteTargetId = elementId or 0
end

local function hasDeleteTarget()
	return deleteTargetType ~= nil and deleteTargetId ~= 0
end

local function isDeleteTarget(elementType, elementId)
	return deleteTargetType == elementType and deleteTargetId == elementId
end

local function deleteTarget()
	local elements = nil
	if deleteTargetType == "arrow" then
		elements = arrows
	elseif deleteTargetType == "compass" then
		elements = compassCircles
	end

	if elements then
		for i = 1, #elements do
			if elements[i].id == deleteTargetId then
				table.remove(elements, i)
				clearDeleteTarget()
				return true
			end
		end
	end

	clearDeleteTarget()
	return false
end

local function getGlyphFilename(character)
	local byte = string.byte(character)
	if byte >= 48 and byte <= 57 then
		return "digit_" .. character .. ".png"
	elseif byte >= 65 and byte <= 90 then
		return "uppercase_" .. character .. ".png"
	elseif byte >= 97 and byte <= 122 then
		return "lowercase_" .. character .. ".png"
	end
	return "period.png"
end

local function loadGlyphSprites()
	for i = 1, #GLYPH_CHARACTERS do
		local character = string.sub(GLYPH_CHARACTERS, i, i)
		glyphSprites[character] = LoadSprite("MOD/data/hud/glyphs/" .. getGlyphFilename(character))
	end
	glyphSprites.degree = LoadSprite("MOD/data/hud/glyphs/degree.png")
end

local function getSpriteTextWidth(text, appendDegree)
	local glyphCount = #text
	if appendDegree then
		glyphCount = glyphCount + 1
	end
	if glyphCount == 0 then return 0 end
	return (glyphCount - 1) * GLYPH_ADVANCE + GLYPH_SPRITE_SIZE
end

local function drawSpriteText(text, appendDegree, center, right, rotation, bodyTransform, color)
	local glyphCount = #text
	if appendDegree then
		glyphCount = glyphCount + 1
	end
	if glyphCount == 0 then return end

	local offset = -(glyphCount - 1) * GLYPH_ADVANCE * 0.5
	for i = 1, #text do
		local character = string.sub(text, i, i)
		local localPosition = VecAdd(center, VecScale(right, offset))
		local worldTransform = TransformToParentTransform(bodyTransform, Transform(localPosition, rotation))
		DrawSprite(glyphSprites[character], worldTransform, GLYPH_SPRITE_SIZE, GLYPH_SPRITE_SIZE,
			color.red, color.green, color.blue, 1, true, false, true)
		offset = offset + GLYPH_ADVANCE
	end
	if appendDegree then
		local localPosition = VecAdd(center, VecScale(right, offset))
		local worldTransform = TransformToParentTransform(bodyTransform, Transform(localPosition, rotation))
		DrawSprite(glyphSprites.degree, worldTransform, GLYPH_SPRITE_SIZE, GLYPH_SPRITE_SIZE,
			color.red, color.green, color.blue, 1, true, false, true)
	end
end

local function getLabelHalfExtent(textWidth, direction, right, up)
	return math.abs(VecDot(direction, right)) * textWidth * 0.5
		+ math.abs(VecDot(direction, up)) * GLYPH_SPRITE_SIZE * 0.5
end

local function drawArrowLabels(data, direction, length, context, color)
	if length < MIN_VALID_ARROW_LENGTH then return end

	local measurement = data.measurement
		or calculateArrowMeasurement(direction, length, context.mapRight, context.mapUp)
	local angleText = string.format("%.1f", measurement.bearingDegrees)
	local distanceText = string.format("%.1fkm", measurement.distanceKilometers)
	local angleExtent = getLabelHalfExtent(
		getSpriteTextWidth(angleText, true), direction, context.mapRight, context.mapUp
	)
	local distanceExtent = getLabelHalfExtent(
		getSpriteTextWidth(distanceText, false), direction, context.mapRight, context.mapUp
	)
	local headHeight = math.min(arrowSpriteHeight, length)
	local surfaceOffset = VecScale(context.mapNormal, TEXT_SURFACE_OFFSET)
	local angleCenter = VecAdd(VecSub(data.localEndPoint,
		VecScale(direction, headHeight + LABEL_GAP + angleExtent)), surfaceOffset)
	local distanceCenter = VecSub(angleCenter,
		VecScale(direction, angleExtent + LABEL_GAP + distanceExtent))

	drawSpriteText(distanceText, false, distanceCenter,
		context.mapRight, context.textRotation, context.bodyTransform, color)
	drawSpriteText(angleText, true, angleCenter,
		context.mapRight, context.textRotation, context.bodyTransform, color)
end

local function drawArrow(data, direction, length, headSprite, shaftSprite, context, color,
	surfaceOffsetAmount)
	local surfaceOffset = VecScale(context.mapNormal, surfaceOffsetAmount or SPRITE_SURFACE_OFFSET)
	local startPoint = VecAdd(data.localStartPoint, surfaceOffset)
	local endPoint = VecAdd(data.localEndPoint, surfaceOffset)
	-- The sprite's local Z follows the map normal; local Y runs toward the endpoint.
	local spriteZ = context.mapNormal
	local spriteX = VecNormalize(VecCross(direction, spriteZ))
	local rotation = QuatAlignXZ(spriteX, spriteZ)

	local headHeight = math.min(arrowSpriteHeight, length)
	local headWidth = arrowSpriteWidth * headHeight / arrowSpriteHeight
	local headCenter = VecSub(endPoint, VecScale(direction, headHeight * 0.5))
	local shaftTop = VecSub(endPoint, VecScale(direction, headHeight))
	local shaftLength = length - headHeight

	if shaftLength > PLANE_EPSILON then
		local shaftCenter = VecLerp(startPoint, shaftTop, 0.5)
		local shaftTransform = TransformToParentTransform(
			context.bodyTransform, Transform(shaftCenter, rotation)
		)
		DrawSprite(shaftSprite, shaftTransform,
			arrowSpriteWidth, shaftLength,
			color.red, color.green, color.blue, 1, true, false, true)
	end
	local headTransform = TransformToParentTransform(context.bodyTransform, Transform(headCenter, rotation))
	DrawSprite(headSprite, headTransform, headWidth, headHeight,
		color.red, color.green, color.blue, 1, true, false, true)
end

local function drawMapMarker(localPoint, color, context)
	local markerSize = math.min(arrowSpriteWidth, arrowSpriteHeight)
	local position = VecAdd(localPoint,
		VecScale(context.mapNormal, MAP_MARKER_SURFACE_OFFSET))
	local worldTransform = TransformToParentTransform(
		context.bodyTransform, Transform(position, context.textRotation)
	)
	DrawSprite(mapMarkerSprite, worldTransform, markerSize, markerSize,
		color.red, color.green, color.blue, 1, true, false, true)
end

local function drawArrowWithLabels(data, context)
	local penStyle = PEN_STYLES[data.penType]
	drawMapMarker(data.localStartPoint, penStyle.color, context)

	local direction, length = getArrowDirectionAndLength(data)
	if not direction then return end

	drawArrow(data, direction, length, arrowSprite, lineSprite, context, penStyle.color)
	if penStyle.drawWorldMeasurement then
		drawArrowLabels(data, direction, length, context, penStyle.color)
	end
end

local function drawArrowBorder(data, color, context)
	local direction, length = getArrowDirectionAndLength(data)
	if not direction then return end

	drawArrow(data, direction, length, arrowBorderSprite, lineBorderSprite,
		context, color, BORDER_SURFACE_OFFSET)
end

local function drawSegmentSprite(sprite, startPoint, endPoint, width, context, color, surfaceOffset)
	local delta = VecSub(endPoint, startPoint)
	local length = VecLength(delta)
	if length <= PLANE_EPSILON then return end

	local direction = VecScale(delta, 1 / length)
	local spriteX = VecNormalize(VecCross(direction, context.mapNormal))
	local rotation = QuatAlignXZ(spriteX, context.mapNormal)
	local center = VecAdd(VecLerp(startPoint, endPoint, 0.5),
		VecScale(context.mapNormal, surfaceOffset))
	local worldTransform = TransformToParentTransform(
		context.bodyTransform, Transform(center, rotation)
	)
	DrawSprite(sprite, worldTransform, width, length,
		color.red, color.green, color.blue, 1, true, false, true)
end

local function getCompassRadiusAndDirection(data)
	local delta = VecSub(data.localHeadPoint, data.localCenterPoint)
	local radius = VecLength(delta)
	if radius <= PLANE_EPSILON then return 0, nil end
	return radius, VecScale(delta, 1 / radius)
end

local function getCompassPoint(center, radius, angle, context)
	local rightOffset = VecScale(context.mapRight, math.sin(angle) * radius)
	local upOffset = VecScale(context.mapUp, math.cos(angle) * radius)
	return VecAdd(center, VecAdd(rightOffset, upOffset))
end

local function getCompassDashLayout(radius)
	local desiredPeriodLength = arrowSpriteHeight
		* (COMPASS_DASH_LENGTH_HEAD_SCALE + COMPASS_DASH_GAP_HEAD_SCALE)
	local circumference = 2 * math.pi * radius
	local dashCount = math.floor(circumference / desiredPeriodLength + 0.5)
	dashCount = math.max(COMPASS_MIN_DASH_COUNT, math.min(COMPASS_MAX_DASH_COUNT, dashCount))

	local periodAngle = 2 * math.pi / dashCount
	local dashDutyCycle = COMPASS_DASH_LENGTH_HEAD_SCALE
		/ (COMPASS_DASH_LENGTH_HEAD_SCALE + COMPASS_DASH_GAP_HEAD_SCALE)
	return dashCount, periodAngle, periodAngle * dashDutyCycle
end

local function drawCompassDashPiece(sprite, startPoint, endPoint, pieceIndex, context,
	color, surfaceOffset)
	local delta = VecSub(endPoint, startPoint)
	local length = VecLength(delta)
	if length <= PLANE_EPSILON then return end

	local direction = VecScale(delta, 1 / length)
	local overlap = math.min(
		arrowSpriteHeight * COMPASS_PIECE_OVERLAP_HEAD_SCALE,
		length * 0.1
	)
	if pieceIndex > 1 then
		startPoint = VecSub(startPoint, VecScale(direction, overlap))
	end
	if pieceIndex < COMPASS_DASH_PIECE_COUNT then
		endPoint = VecAdd(endPoint, VecScale(direction, overlap))
	end

	drawSegmentSprite(sprite, startPoint, endPoint,
		arrowSpriteWidth * COMPASS_DASH_WIDTH_SCALE,
		context, color, surfaceOffset)
end

local function drawCompassDashes(data, radius, radialDirection, dashSprites, context,
	color, surfaceOffset)
	local dashCount, periodAngle, dashAngle = getCompassDashLayout(radius)
	local headAngle = math.atan2(
		VecDot(radialDirection, context.mapRight),
		VecDot(radialDirection, context.mapUp)
	)
	local pieceAngle = dashAngle / COMPASS_DASH_PIECE_COUNT

	for dashIndex = 0, dashCount - 1 do
		local dashHeadAngle = headAngle + dashIndex * periodAngle
		local dashTailAngle = dashHeadAngle - dashAngle
		for pieceIndex = 1, COMPASS_DASH_PIECE_COUNT do
			local startAngle = dashTailAngle + (pieceIndex - 1) * pieceAngle
			local endAngle = startAngle + pieceAngle
			local startPoint = getCompassPoint(data.localCenterPoint, radius, startAngle, context)
			local endPoint = getCompassPoint(data.localCenterPoint, radius, endAngle, context)
			drawCompassDashPiece(
				dashSprites[pieceIndex], startPoint, endPoint, pieceIndex,
				context, color, surfaceOffset
			)
		end
	end
end

local function drawCompassRadiusLabel(data, radius, radialDirection, context)
	local radiusKilometers = data.radiusKilometers or radius / MAP_METERS_PER_KILOMETER
	local radiusText = string.format("%.1fkm", radiusKilometers)
	local clockwiseDirection = VecNormalize(VecCross(radialDirection, context.mapNormal))
	local labelExtent = getLabelHalfExtent(
		getSpriteTextWidth(radiusText, false),
		clockwiseDirection,
		context.mapRight,
		context.mapUp
	)
	local labelCenter = VecAdd(data.localHeadPoint,
		VecScale(clockwiseDirection, arrowSpriteHeight + LABEL_GAP + labelExtent))
	labelCenter = VecAdd(labelCenter,
		VecScale(context.mapNormal, COMPASS_TEXT_SURFACE_OFFSET))

	drawSpriteText(radiusText, false, labelCenter,
		context.mapRight, context.textRotation, context.bodyTransform, COMPASS_COLOR)
end

local function drawCompass(data, drawGuide, context)
	drawMapMarker(data.localCenterPoint, COMPASS_COLOR, context)

	local radius, radialDirection = getCompassRadiusAndDirection(data)
	if not radialDirection then return end

	if drawGuide then
		drawSegmentSprite(lineSprite, data.localCenterPoint, data.localHeadPoint,
			arrowSpriteWidth, context, COMPASS_COLOR, COMPASS_GUIDE_SURFACE_OFFSET)
	end
	drawCompassDashes(data, radius, radialDirection, compassDashSprites,
		context, COMPASS_COLOR, COMPASS_SURFACE_OFFSET)
	drawCompassRadiusLabel(data, radius, radialDirection, context)
end

local function drawCompassBorder(data, color, context)
	local radius, radialDirection = getCompassRadiusAndDirection(data)
	if not radialDirection then return end
	drawCompassDashes(data, radius, radialDirection,
		compassDashBorderSprites, context, color, BORDER_SURFACE_OFFSET)
end

local function getMapRenderContext()
	if not mapIsReady() or arrowSpriteWidth <= 0 or arrowSpriteHeight <= 0 then return end

	local mapRight, mapUp, mapNormal = getLocalMapAxes()
	if not mapRight then return end
	return {
		bodyTransform = GetBodyTransform(mapBody),
		mapNormal = mapNormal,
		mapRight = mapRight,
		mapUp = mapUp,
		textRotation = QuatAlignXZ(mapRight, mapNormal),
	}
end

local function drawMapElements()
	local context = getMapRenderContext()
	if not context then return end

	for i = 1, #arrows do
		local arrow = arrows[i]
		drawArrowWithLabels(arrow, context)
		if isDeleteTarget("arrow", arrow.id) then
			drawArrowBorder(arrow, DELETE_BORDER_COLOR, context)
		end
	end
	if activeArrow then
		drawArrowWithLabels(activeArrow, context)
		drawArrowBorder(activeArrow, BLACK_BORDER_COLOR, context)
	end

	for i = 1, #compassCircles do
		local compass = compassCircles[i]
		drawCompass(compass, false, context)
		if isDeleteTarget("compass", compass.id) then
			drawCompassBorder(compass, DELETE_BORDER_COLOR, context)
		end
	end
	if activeCompass then
		drawCompass(activeCompass, true, context)
		drawCompassBorder(activeCompass, BLACK_BORDER_COLOR, context)
	end
end

local function drawMeasurementLog()
	UiPush()
		UiTranslate(MEASUREMENT_LOG_LEFT, MEASUREMENT_LOG_TOP)
		UiAlign("left top")
		UiFont("regular.ttf", MEASUREMENT_LOG_FONT_SIZE)
		UiColor(0, 0, 0, 1)

		for i = 1, #measurementLogEntries do
			UiText(measurementLogEntries[i])
			UiTranslate(0, MEASUREMENT_LOG_LINE_HEIGHT)
		end
	UiPop()
end

local function drawModeIndicator()
	if GetString("game.player.tool") ~= TOOL_ID then return end

	local mode = DRAWING_MODE_ORDER[selectedModeIndex]
	UiPush()
		UiTranslate(MODE_INDICATOR_LEFT, UiHeight() - MODE_INDICATOR_BOTTOM)
		UiAlign("left bottom")
		UiFont("regular.ttf", MODE_INDICATOR_FONT_SIZE)
		UiColor(0, 0, 0, 1)
		UiText(DRAWING_MODE_NAMES[mode])
	UiPop()
end

function init()
	RegisterTool(TOOL_ID, TOOL_NAME, "", TOOL_GROUP)
	SetBool("game.tool." .. TOOL_ID .. ".enabled", true)

	arrowSprite = LoadSprite("MOD/data/hud/uparrow.png")
	lineSprite = LoadSprite("MOD/data/hud/line.png")
	-- Border assets are white masks tinted black while drawing and red while deleting.
	arrowBorderSprite = LoadSprite("MOD/data/hud/uparrow-red-outlined.png")
	lineBorderSprite = LoadSprite("MOD/data/hud/line-red-outlined.png")
	-- Dash pieces are stored in drawing order from the counterclockwise tail to the clockwise head.
	compassDashSprites[1] = LoadSprite("MOD/data/hud/dashed-line-tail.png")
	compassDashSprites[2] = LoadSprite("MOD/data/hud/dashed-line-middle.png")
	compassDashSprites[3] = LoadSprite("MOD/data/hud/dashed-line-head.png")
	compassDashBorderSprites[1] = LoadSprite("MOD/data/hud/dashed-line-red-outlined-tail.png")
	compassDashBorderSprites[2] = LoadSprite("MOD/data/hud/dashed-line-red-outlined-middle.png")
	compassDashBorderSprites[3] = LoadSprite("MOD/data/hud/dashed-line-red-outlined-head.png")
	mapMarkerSprite = LoadSprite("MOD/data/hud/map-marker.png")
	loadGlyphSprites()

	findMapEntities()
	initializeMapLabels()
end

function tick(dt)
	entitySearchTimer = entitySearchTimer - dt
	if entitySearchTimer <= 0 and (not mapIsReady() or mapScreen == 0 or not IsHandleValid(mapScreen)) then
		findMapEntities()
		entitySearchTimer = 0.5
	end
	if not mapIsReady() then
		mapPlaneLocalTransform = nil
		cancelActiveDrawing()
		forgetMapLabels()
	elseif mapLabelsParentBody ~= mapBody then
		initializeMapLabels()
	end

	local toolSelected = GetString("game.player.tool") == TOOL_ID
	local canUseTool = GetBool("game.player.canusetool") and GetPlayerVehicle() == 0
	local useToolPressed = toolSelected and InputPressed("usetool")
	local deletedElement = false
	if toolSelected then
		ReleasePlayerGrab()
	end
	if activeMapLabel then
		clearDeleteTarget()
		if toolSelected and canUseTool then
			updateActiveMapLabel()
		end
		syncMapLabelsToMap()
		if not toolSelected or not canUseTool or InputReleased("usetool") then
			activeMapLabel = nil
		end
		return
	end

	if toolSelected and not isDrawing() then
		updateDeleteTarget()
		if InputPressed(PREVIOUS_MODE_INPUT) then
			cycleSelectedMode(-1)
		elseif InputPressed(NEXT_MODE_INPUT) then
			cycleSelectedMode(1)
		end
		if canUseTool and useToolPressed and beginMapLabelDrag() then
			clearDeleteTarget()
			syncMapLabelsToMap()
			return
		end
		if hasDeleteTarget() and (useToolPressed or InputPressed("rmb")) then
			deletedElement = deleteTarget()
		end
	else
		clearDeleteTarget()
	end

	if toolSelected and canUseTool then
		if useToolPressed and not deletedElement then
			clearDeleteTarget()
			beginMapDrawing()
		end
		if isDrawing() then
			updateActiveDrawing()
			if InputReleased("usetool") then
				finishActiveDrawing()
			end
		end
	elseif isDrawing() then
		cancelActiveDrawing()
	end
	syncMapLabelsToMap()
end

function render(dt)
	drawMapElements()
end

function draw()
	drawMeasurementLog()
	drawModeIndicator()
end
