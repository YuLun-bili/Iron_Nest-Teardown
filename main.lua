local TOOL_ID = "iron_nest_map_arrow"
local TOOL_NAME = "Map Arrow"
local TOOL_GROUP = 2

local MAP_BODY_TAG = "iron_nest_map"
local MAP_PLANE_TAG = "iron_nest_map_plane"
local MAP_SCREEN_TAG = "iron_nest_map_screen"

local RAYCAST_DISTANCE = 10
local PLANE_EPSILON = 0.0001
local MIN_VALID_ARROW_LENGTH = 0.01
local SPRITE_SURFACE_OFFSET = 0.002
local ARROW_SPRITE_PIXEL_WIDTH = 32
local ARROW_SPRITE_PIXEL_HEIGHT = 32
local ARROW_SPRITE_SCALE = 0.5
local TEXT_SURFACE_OFFSET = 0.004
local GLYPH_CHARACTERS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz."
local GLYPH_SPRITE_SIZE = 0.04
local GLYPH_ADVANCE = 0.024
local LABEL_GAP = 0.04
local MAP_METERS_PER_KILOMETER = 0.05

local mapBody = 0
local mapPlane = 0
local mapScreen = 0
local mapPlaneLocalTransform = nil
local arrows = {}
local activeArrow = nil

local arrowSprite = 0
local lineSprite = 0
local outlinedArrowSprite = 0
local outlinedLineSprite = 0
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
	if mapScreen == 0 or not IsHandleValid(mapScreen) then return end

	local screenWidth, screenHeight = readPairProperty(mapScreen, "size")
	local resolutionWidth, resolutionHeight = readPairProperty(mapScreen, "resolution")
	if not screenWidth or not screenHeight or not resolutionWidth or not resolutionHeight then return end
	if resolutionWidth <= 0 or resolutionHeight <= 0 then return end

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

local function getLocalMapNormal()
	if not mapIsReady() then return nil end
	return VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(0, 0, 1)))
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

local function beginArrow()
	if not mapIsReady() then return end

	local rayOrigin, rayDirection = getWorldEyeRay()
	local hit, hitDistance, _, shape = QueryRaycast(rayOrigin, rayDirection, RAYCAST_DISTANCE)
	if not hit or shape == 0 or GetShapeBody(shape) ~= mapBody then return end

	local hitPoint = VecAdd(rayOrigin, VecScale(rayDirection, hitDistance))
	local localPoint = projectWorldPointOntoMapPlane(hitPoint)
	if not localPoint then return end

	activeArrow = {
		localStartPoint = VecCopy(localPoint),
		localEndPoint = VecCopy(localPoint)
	}
end

local function updateActiveArrow()
	if not activeArrow then return end

	local rayOrigin, rayDirection = getWorldEyeRay()
	local localPoint = intersectWorldRayWithMapPlane(rayOrigin, rayDirection)
	if localPoint then
		activeArrow.localEndPoint = localPoint
	end
end

local function finishArrow()
	if not activeArrow then return end

	local delta = VecSub(activeArrow.localEndPoint, activeArrow.localStartPoint)
	if VecLength(delta) >= MIN_VALID_ARROW_LENGTH then
		arrows[#arrows + 1] = activeArrow
	end
	activeArrow = nil
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

local function drawSpriteText(text, appendDegree, center, right, rotation, bodyTransform)
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
			1, 1, 1, 1, true, false, false)
		offset = offset + GLYPH_ADVANCE
	end
	if appendDegree then
		local localPosition = VecAdd(center, VecScale(right, offset))
		local worldTransform = TransformToParentTransform(bodyTransform, Transform(localPosition, rotation))
		DrawSprite(glyphSprites.degree, worldTransform, GLYPH_SPRITE_SIZE, GLYPH_SPRITE_SIZE,
			1, 1, 1, 1, true, false, false)
	end
end

local function getLabelHalfExtent(textWidth, direction, right, up)
	return math.abs(VecDot(direction, right)) * textWidth * 0.5
		+ math.abs(VecDot(direction, up)) * GLYPH_SPRITE_SIZE * 0.5
end

local function getArrowDirectionAndLength(data)
	local delta = VecSub(data.localEndPoint, data.localStartPoint)
	local length = VecLength(delta)
	if length <= PLANE_EPSILON then return nil, 0 end
	return VecScale(delta, 1 / length), length
end

local function drawArrowLabels(data, direction, length, context)
	if length < MIN_VALID_ARROW_LENGTH then return end

	local bearing = math.deg(math.atan2(
		VecDot(direction, context.mapRight),
		VecDot(direction, context.mapUp)
	))
	if bearing < 0 then
		bearing = bearing + 360
	end
	bearing = math.floor(bearing * 10 + 0.5) / 10
	if bearing >= 360 then
		bearing = 0
	end

	local angleText = string.format("%.1f", bearing)
	local distanceText = string.format("%.1fkm", length / MAP_METERS_PER_KILOMETER)
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
		context.mapRight, context.textRotation, context.bodyTransform)
	drawSpriteText(angleText, true, angleCenter,
		context.mapRight, context.textRotation, context.bodyTransform)
end

local function drawArrow(data, direction, length, headSprite, shaftSprite, context)
	local surfaceOffset = VecScale(context.mapNormal, SPRITE_SURFACE_OFFSET)
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
			arrowSpriteWidth, shaftLength, 1, 1, 1, 1, true, false, false)
	end
	local headTransform = TransformToParentTransform(context.bodyTransform, Transform(headCenter, rotation))
	DrawSprite(headSprite, headTransform, headWidth, headHeight, 1, 1, 1, 1, true, false, false)
end

local function drawArrowWithLabels(data, headSprite, shaftSprite, context)
	local direction, length = getArrowDirectionAndLength(data)
	if not direction then return end
	drawArrow(data, direction, length, headSprite, shaftSprite, context)
	drawArrowLabels(data, direction, length, context)
end

local function drawArrows()
	if not mapIsReady() or arrowSpriteWidth <= 0 or arrowSpriteHeight <= 0 then return end

	local mapNormal = getLocalMapNormal()
	if not mapNormal then return end
	local mapRight = VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(1, 0, 0)))
	local context = {
		bodyTransform = GetBodyTransform(mapBody),
		mapNormal = mapNormal,
		mapRight = mapRight,
		mapUp = VecNormalize(TransformToParentVec(mapPlaneLocalTransform, Vec(0, 1, 0))),
		textRotation = QuatAlignXZ(mapRight, mapNormal),
	}

	for i = 1, #arrows do
		drawArrowWithLabels(arrows[i], arrowSprite, lineSprite, context)
	end
	if activeArrow then
		drawArrowWithLabels(activeArrow, outlinedArrowSprite, outlinedLineSprite, context)
	end
end

function init()
	RegisterTool(TOOL_ID, TOOL_NAME, "", TOOL_GROUP)
	SetBool("game.tool." .. TOOL_ID .. ".enabled", true)

	arrowSprite = LoadSprite("MOD/data/hud/uparrow.png")
	lineSprite = LoadSprite("MOD/data/hud/line.png")
	outlinedArrowSprite = LoadSprite("MOD/data/hud/uparrow-outlined.png")
	outlinedLineSprite = LoadSprite("MOD/data/hud/line-outlined.png")
	loadGlyphSprites()

	findMapEntities()
end

function tick(dt)
	entitySearchTimer = entitySearchTimer - dt
	if entitySearchTimer <= 0 and (not mapIsReady() or mapScreen == 0 or not IsHandleValid(mapScreen)) then
		findMapEntities()
		entitySearchTimer = 0.5
	end
	if not mapIsReady() then
		mapPlaneLocalTransform = nil
		activeArrow = nil
	end

	local toolSelected = GetString("game.player.tool") == TOOL_ID
	local canUseTool = GetBool("game.player.canusetool") and GetPlayerVehicle() == 0
	if toolSelected and canUseTool then
		if InputPressed("usetool") then
			beginArrow()
		end
		if activeArrow then
			updateActiveArrow()
			if InputReleased("usetool") then
				finishArrow()
			end
		end
	elseif activeArrow then
		activeArrow = nil
	end
end

function render(dt)
	drawArrows()
end
