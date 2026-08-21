#version 2

local TOOL_ID = "iron_nest_explosion_weapon"
local TOOL_NAME = "Explosion Weapon"
local TOOL_GROUP = 4
local DEFAULT_EXPLOSION_RADIUS = 10
local RADIUS_CHANGE_RATE = 5
local AIM_DISTANCE = 10000
local DESTRUCTION_LAYER_STEP = 0.5
local DISTANCE_EPSILON = 0.001
local PARTICLE_COUNT_MULTIPLIER = 1
local SIZE_TRANSITION = 4
local MUSHROOM_MIN_SIZE = 6
local PARTICLE_SPATIAL_MULTIPLIER = 2
local SHOCKWAVE_RANGE_MULTIPLIER = 6
local SHOCKWAVE_REFERENCE_DURATION = 0.6
local SHOCKWAVE_SPEED = DEFAULT_EXPLOSION_RADIUS * 4 / SHOCKWAVE_REFERENCE_DURATION * 2
local SHOCKWAVE_DENSITY_MULTIPLIER =
	(SHOCKWAVE_RANGE_MULTIPLIER / PARTICLE_SPATIAL_MULTIPLIER) ^ 2
local PUSH_RADIUS_MULTIPLIER = 4
local PUSH_VELOCITY_PER_RADIUS = 7

local playerExplosionRadii = {}
local pendingExplosionPushes = {}
local activeExplosionEffects = {}
local localExplosionRadius = DEFAULT_EXPLOSION_RADIUS

local function randomUnitVector()
	local vertical = GetRandomFloat(-1, 1)
	local angle = GetRandomFloat(0, math.pi * 2)
	local horizontal = math.sqrt(math.max(0, 1 - vertical * vertical))
	return Vec(horizontal * math.cos(angle), vertical, horizontal * math.sin(angle))
end

local function takeEmissionCount(effect, key, rate, dt)
	local total = (effect.emission[key] or 0) + rate * dt
	local count = math.floor(total)
	effect.emission[key] = total - count
	return count
end

local function adjustExplosionRadius(radius, dt, playerId)
	local direction = 0
	if InputDown("9", playerId) then direction = direction - 1 end
	if InputDown("0", playerId) then direction = direction + 1 end
	return radius + direction * RADIUS_CHANGE_RATE * dt
end

local function createLayeredDestruction(position, radius, playerId)
	local layerCount = math.floor(radius / DESTRUCTION_LAYER_STEP)
	for layer = 1, layerCount do
		Shoot(position, Vec(0, -1, 0), "gun", layer * DESTRUCTION_LAYER_STEP)
	end
	if radius - layerCount * DESTRUCTION_LAYER_STEP > DISTANCE_EPSILON then
		Shoot(position, Vec(0, -1, 0), "gun", radius)
	end
	--Explosion(position, radius, playerId)
end

local function spawnExplosionParticles(effect, dt)
	local position = effect.position
	local radius = effect.radius
	local age = effect.age
	local sizeRatio = radius / SIZE_TRANSITION
	local fireScale = math.sqrt(sizeRatio)
	local smokeScale = sizeRatio
	local smokeTimeScale = math.max(0.25, smokeScale)
	local fireRadius = SIZE_TRANSITION * PARTICLE_SPATIAL_MULTIPLIER * fireScale
	local smokeRadius = radius * PARTICLE_SPATIAL_MULTIPLIER
	local smokeMotionScale = smokeRadius / smokeTimeScale
	local particleScale = PARTICLE_COUNT_MULTIPLIER
	local flashDuration = 0.18
	local fireballDuration = 0.5
	local shockRange = radius * SHOCKWAVE_RANGE_MULTIPLIER
	local shockDuration = shockRange / SHOCKWAVE_SPEED
	local sparkDuration = 0.38
	local debrisDuration = 0.5
	local dustStart = 0.08
	local dustDuration = smokeTimeScale
	local mushroomTimeScale = radius / MUSHROOM_MIN_SIZE
	local smokeStart = 0.24 * mushroomTimeScale
	local smokeDuration = 3.4 * mushroomTimeScale
	local effectDuration = math.max(fireballDuration, sparkDuration, debrisDuration, dustStart + dustDuration)
	if radius >= MUSHROOM_MIN_SIZE then
		effectDuration = math.max(effectDuration, smokeDuration)
	end
	local count
	local direction
	local spawnPosition
	local velocity
	local distance

	if IsPointInWater(position) then
		local waterTimeScale = math.max(0.5, fireScale)
		local waterDuration = 1.2 * waterTimeScale
		if age <= waterDuration then
			local progress = math.max(0, math.min(1, age / waterDuration))
			local expansion = 1 - (1 - progress) ^ 3
			local waterRadius = smokeRadius * expansion

			count = takeEmissionCount(effect, "waterSpray", 900 * smokeScale * particleScale, dt)
			ParticleReset()
			ParticleType("plain")
			ParticleColor(0.88, 0.95, 1, 0.3, 0.48, 0.62)
			ParticleEmissive(0)
			ParticleRadius(smokeRadius * 0.025, smokeRadius * 0.1, "easeout")
			ParticleAlpha(1, 0)
			ParticleCollide(0)
			ParticleDrag(0.18)
			ParticleGravity(-smokeRadius * 0.8)
			ParticleStretch(5)
			for index = 1, count do
				ParticleTile(index % 2 == 0 and 1 or 14)
				direction = randomUnitVector()
				distance = waterRadius * GetRandomFloat(0, 1) ^ (1 / 3)
				spawnPosition = VecAdd(position, VecScale(direction, distance))
				velocity = VecScale(direction, smokeMotionScale * GetRandomFloat(0.5, 1.4))
				velocity[2] = math.abs(velocity[2]) + smokeMotionScale * GetRandomFloat(0.8, 1.8)
				SpawnParticle(spawnPosition, velocity, GetRandomFloat(0.6, 1.5) * waterTimeScale)
			end

			count = takeEmissionCount(effect, "waterMist", 700 * smokeScale * particleScale, dt)
			ParticleReset()
			ParticleType("smoke")
			ParticleTile(0)
			ParticleColor(0.72, 0.82, 0.88, 0.24, 0.34, 0.4)
			ParticleRadius(smokeRadius * 0.06, smokeRadius * 0.24, "easeout")
			ParticleAlpha(0.82, 0)
			ParticleCollide(0)
			ParticleSticky(0.1)
			ParticleDrag(0.5, 0.18)
			ParticleGravity(0)
			ParticleStretch(1)
			for _ = 1, count do
				direction = randomUnitVector()
				distance = waterRadius * GetRandomFloat(0, 1) ^ (1 / 3)
				spawnPosition = VecAdd(position, VecScale(direction, distance))
				velocity = VecScale(direction, smokeMotionScale * GetRandomFloat(0.12, 0.42))
				velocity[2] = math.abs(velocity[2]) + smokeMotionScale * GetRandomFloat(0.18, 0.55)
				SpawnParticle(spawnPosition, velocity, GetRandomFloat(2, 4.5) * waterTimeScale)
			end

			count = takeEmissionCount(effect, "waterBubbles", 300 * smokeScale * particleScale, dt)
			ParticleReset()
			ParticleType("plain")
			ParticleTile(2)
			ParticleColor(0.82, 0.92, 1, 0.35, 0.55, 0.72)
			ParticleRadius(smokeRadius * 0.012, smokeRadius * 0.05, "easeout")
			ParticleAlpha(0.9, 0)
			ParticleCollide(0)
			ParticleDrag(0.5)
			ParticleGravity(0)
			ParticleStretch(1)
			for _ = 1, count do
				direction = randomUnitVector()
				distance = waterRadius * GetRandomFloat(0, 1) ^ (1 / 3)
				spawnPosition = VecAdd(position, VecScale(direction, distance))
				velocity = VecScale(direction, smokeMotionScale * GetRandomFloat(0.04, 0.18))
				velocity[2] = math.abs(velocity[2]) + smokeMotionScale * GetRandomFloat(0.2, 0.7)
				SpawnParticle(spawnPosition, velocity, GetRandomFloat(1.5, 4) * waterTimeScale)
			end
		end
		return waterDuration
	end

	-- Initial flash: brief, bright and dominant on small explosions.
	if age <= flashDuration then
		local fade = 1 - age / flashDuration
		PointLight(position, 1, 0.45, 0.12, fireRadius * 60 * fade * fade)

		count = takeEmissionCount(effect, "flash", 700 * fireScale * particleScale, dt)
		ParticleReset()
		ParticleType("plain")
		ParticleTile(0)
		ParticleColor(1, 0.82, 0.42, 1, 0.1, 0.02)
		ParticleEmissive(22, 2, "easeout")
		ParticleRadius(fireRadius * 0.07, fireRadius * 0.3, "easeout")
		ParticleAlpha(1, 0, "easeout")
		ParticleCollide(0)
		ParticleSticky(0)
		ParticleDrag(0.45)
		ParticleGravity(0)
		ParticleStretch(2)
		for _ = 1, count do
			direction = randomUnitVector()
			distance = fireRadius * (1 - fade) * GetRandomFloat(0, 0.35) ^ (1 / 3)
			spawnPosition = VecAdd(position, VecScale(direction, distance))
			SpawnParticle(
				spawnPosition,
				VecScale(direction, fireRadius * GetRandomFloat(0.25, 0.7)),
				GetRandomFloat(0.12, 0.32)
			)
		end
	end

	-- Fireball: volume-uniform samples fill an expanding sphere all the way to the configured radius.
	if age <= fireballDuration then
		local progress = math.max(0, math.min(1, age / fireballDuration))
		local expansion = 1 - (1 - progress) ^ 3
		local fireballRadius = fireRadius * expansion
		local expansionSpeed = fireRadius / fireballDuration
		PointLight(position, 1, 0.32, 0.06, fireRadius * 27.5 * (1 - progress))

		count = takeEmissionCount(effect, "fireball", 1000 * fireScale * particleScale, dt)
		ParticleReset()
		ParticleType("smoke")
		ParticleTile(5)
		ParticleColor(1, 0.48, 0.1, 0.24, 0.16, 0.14)
		ParticleEmissive(14, 0, "easeout")
		ParticleRadius(
			fireRadius * 0.06,
			fireRadius * 0.17,
			"easeout"
		)
		ParticleAlpha(1, 0, "easeout")
		ParticleCollide(0)
		ParticleSticky(0.12)
		ParticleDrag(0.32, 0.12)
		ParticleGravity(0)
		ParticleStretch(2)
		for _ = 1, count do
			direction = randomUnitVector()
			distance = fireballRadius * GetRandomFloat(0, 1) ^ (1 / 3)
			spawnPosition = VecAdd(position, VecScale(direction, distance))
			velocity = VecScale(direction, expansionSpeed * GetRandomFloat(0.08, 0.28))
			velocity[2] = velocity[2] + fireRadius * GetRandomFloat(0.03, 0.14)
			SpawnParticle(spawnPosition, velocity, GetRandomFloat(0.5, 1.05))
		end
	end

	-- Fixed-speed shockwave: every generation stays on r = SHOCKWAVE_SPEED * currentAge.
	if age < shockDuration then
		local waveRadius = SHOCKWAVE_SPEED * age
		local shockVisibility = math.max(0, math.min(1, radius / DEFAULT_EXPLOSION_RADIUS))
		local shockEmissionDt = math.min(dt, shockDuration - age)
		count = takeEmissionCount(
			effect,
			"shockwave",
			2000 * particleScale * SHOCKWAVE_DENSITY_MULTIPLIER
				* SHOCKWAVE_REFERENCE_DURATION / shockDuration,
			shockEmissionDt
		)

		ParticleReset()
		ParticleType("plain")
		ParticleTile(0)
		ParticleColor(0.9, 0.84, 0.72, 0.3, 0.29, 0.28)
		ParticleEmissive(1.5 * shockVisibility, 0, "easeout")
		ParticleRadius(
			smokeRadius * 0.014,
			smokeRadius * 0.08,
			"easeout"
		)
		ParticleAlpha(shockVisibility, 0, "easeout")
		ParticleCollide(0)
		ParticleSticky(0)
		ParticleDrag(0)
		ParticleGravity(0)
		ParticleStretch(1)
		for _ = 1, count do
			direction = randomUnitVector()
			spawnPosition = VecAdd(position, VecScale(direction, waveRadius))
			SpawnParticle(
				spawnPosition,
				VecScale(direction, SHOCKWAVE_SPEED),
				shockDuration - age
			)
		end
	end

	-- Sparks and hot fragments lead small explosions, then become accents on large ones.
	if age <= sparkDuration then
		count = takeEmissionCount(effect, "sparks", 1200 * fireScale * particleScale, dt)
		ParticleReset()
		ParticleType("plain")
		ParticleTile(6)
		ParticleColor(1, 0.58, 0.14, 0.6, 0.12, 0.02)
		ParticleEmissive(9, 0, "easeout")
		ParticleAlpha(1, 0)
		ParticleCollide(0.25)
		ParticleSticky(0.15)
		ParticleDrag(0.16)
		ParticleGravity(-fireRadius * 1.2)
		ParticleStretch(32, 6)
		for _ = 1, count do
			ParticleRadius(fireRadius * GetRandomFloat(0.004, 0.011), 0, "easeout")
			direction = randomUnitVector()
			spawnPosition = VecAdd(position, VecScale(direction, fireRadius * GetRandomFloat(0.02, 0.18)))
			velocity = VecScale(direction, fireRadius * GetRandomFloat(3, 7))
			velocity[2] = velocity[2] + fireRadius * GetRandomFloat(0.2, 0.9)
			SpawnParticle(spawnPosition, velocity, GetRandomFloat(0.4, 1.1))
		end
	end

	if age <= debrisDuration then
		count = takeEmissionCount(effect, "debris", 300 * smokeScale * particleScale, dt)
		ParticleReset()
		ParticleType("plain")
		ParticleTile(4)
		ParticleColor(0.42, 0.34, 0.23, 0.07, 0.065, 0.06)
		ParticleEmissive(2, 0, "easeout")
		ParticleAlpha(1, 0)
		ParticleCollide(0.45)
		ParticleSticky(0.3)
		ParticleDrag(0.12)
		ParticleGravity(-smokeRadius * 1.8)
		ParticleStretch(2)
		for _ = 1, count do
			ParticleRadius(smokeRadius * GetRandomFloat(0.008, 0.02), smokeRadius * 0.004, "easeout")
			direction = randomUnitVector()
			spawnPosition = VecAdd(position, VecScale(direction, smokeRadius * GetRandomFloat(0.04, 0.3)))
			velocity = VecScale(direction, smokeMotionScale * GetRandomFloat(0.9, 2.8))
			velocity[2] = velocity[2] + smokeMotionScale * GetRandomFloat(0.1, 0.6)
			SpawnParticle(spawnPosition, velocity, GetRandomFloat(1.4, 3.8))
		end
	end

	-- Dust scales linearly in space and lifetime, so it overtakes sqrt-scaled fire above size four.
	if age >= dustStart and age <= dustStart + dustDuration then
		local progress = math.max(0, math.min(1, (age - dustStart) / dustDuration))
		local expansion = 1 - (1 - progress) ^ 3
		local dustRadius = smokeRadius * (0.12 + 0.88 * expansion)
		count = takeEmissionCount(effect, "dust", 1080 * smokeScale * particleScale, dt)

		ParticleReset()
		ParticleType("smoke")
		ParticleTile(0)
		ParticleColor(0.42, 0.36, 0.29, 0.09, 0.09, 0.095)
		ParticleEmissive(0)
		ParticleRadius(
			smokeRadius * 0.05,
			smokeRadius * 0.17,
			"easeout"
		)
		ParticleAlpha(0.92, 0)
		ParticleCollide(0)
		ParticleSticky(0.15)
		ParticleDrag(0.58, 0.2)
		ParticleGravity(0)
		ParticleStretch(1)
		for _ = 1, count do
			direction = randomUnitVector()
			distance = dustRadius * GetRandomFloat(0, 1) ^ (1 / 3)
			spawnPosition = VecAdd(position, VecScale(direction, distance))
			velocity = VecScale(direction, smokeMotionScale * GetRandomFloat(0.08, 0.28))
			velocity[2] = velocity[2] + smokeMotionScale * GetRandomFloat(0.08, 0.3)
			SpawnParticle(spawnPosition, velocity, GetRandomFloat(2.4, 5.2) * smokeTimeScale)
		end
	end

	-- Mushroom-cloud size and lifetime grow together; inverse emission rate preserves density.
	if radius >= MUSHROOM_MIN_SIZE and age >= smokeStart and age <= smokeDuration then
		local progress = math.max(0, math.min(1, (age - smokeStart) / (smokeDuration - smokeStart)))
		local stemHeight = smokeRadius * (0.15 + 1.05 * progress)
		local stemRadius = smokeRadius * (0.1 + 0.2 * progress)
		local crownRadius = smokeRadius * (0.16 + 0.48 * progress)
		local crownChance = 0.25 + 0.55 * progress
		local mushroomMotionScale = smokeRadius / mushroomTimeScale
		count = takeEmissionCount(effect, "column", 500 / mushroomTimeScale * particleScale, dt)

		ParticleReset()
		ParticleType("smoke")
		ParticleTile(0)
		ParticleColor(0.3, 0.28, 0.27, 0.075, 0.075, 0.08)
		ParticleEmissive(0)
		ParticleRadius(
			smokeRadius * 0.075 * (0.8 + 0.4 * progress),
			smokeRadius * 0.2 * (1 + 0.5 * progress),
			"easeout"
		)
		ParticleAlpha(0.9, 0)
		ParticleCollide(0)
		ParticleSticky(0.18)
		ParticleDrag(0.7, 0.28)
		ParticleGravity(0)
		ParticleStretch(1)
		for _ = 1, count do
			if GetRandomFloat(0, 1) < crownChance then
				direction = randomUnitVector()
				spawnPosition = VecAdd(
					position,
					Vec(
						direction[1] * crownRadius,
						stemHeight * 0.8 + direction[2] * crownRadius * 0.55,
						direction[3] * crownRadius
					)
				)
			else
				local angle = GetRandomFloat(0, math.pi * 2)
				local horizontalRadius = stemRadius * math.sqrt(GetRandomFloat(0, 1))
				spawnPosition = VecAdd(
					position,
					Vec(
						math.cos(angle) * horizontalRadius,
						GetRandomFloat(0, stemHeight),
						math.sin(angle) * horizontalRadius
					)
				)
			end
			velocity = Vec(
				GetRandomFloat(-0.08, 0.08) * mushroomMotionScale,
				mushroomMotionScale * GetRandomFloat(0.12, 0.34),
				GetRandomFloat(-0.08, 0.08) * mushroomMotionScale
			)
			SpawnParticle(spawnPosition, velocity, GetRandomFloat(3.2, 6.5) * mushroomTimeScale)
		end
	end

	return effectDuration
end

local function processExplosionParticleEffects(dt)
	for index = #activeExplosionEffects, 1, -1 do
		local effect = activeExplosionEffects[index]
		local effectDuration = spawnExplosionParticles(effect, dt)
		effect.age = effect.age + dt
		if effect.age > effectDuration then
			activeExplosionEffects[index] = activeExplosionEffects[#activeExplosionEffects]
			activeExplosionEffects[#activeExplosionEffects] = nil
		end
	end
end

local function applyExplosionPush(position, radius)
	local pushRadius = radius * PUSH_RADIUS_MULTIPLIER
	local extent = Vec(pushRadius, pushRadius, pushRadius)
	QueryRequire("dynamic physical")
	local players = GetAllPlayers()
	for index = 1, #players do
		local playerId = players[index]
		QueryRejectPlayer(playerId)
		local toolBody = GetToolBody(playerId)
		if toolBody ~= 0 then QueryRejectBody(toolBody) end
	end
	local bodies = QueryAabbBodies(VecSub(position, extent), VecAdd(position, extent))
	for index = 1, #bodies do
		local body = bodies[index]
		local center = TransformToParentPoint(GetBodyTransform(body), GetBodyCenterOfMass(body))
		local delta = VecSub(center, position)
		local distance = VecLength(delta)
		if distance < pushRadius then
			local direction = distance > DISTANCE_EPSILON
				and VecScale(delta, 1 / distance) or randomUnitVector()
			direction = VecNormalize(VecAdd(direction, Vec(0, 0.18, 0)))
			local deltaVelocity = PUSH_VELOCITY_PER_RADIUS * radius * (1 - (distance / pushRadius) ^ 2)
			ApplyBodyImpulse(body, center, VecScale(direction, GetBodyMass(body) * deltaVelocity))
		end
	end
end

local function processPendingExplosionPushes()
	local pending = pendingExplosionPushes
	pendingExplosionPushes = {}
	for index = 1, #pending do
		local explosion = pending[index]
		applyExplosionPush(explosion.position, explosion.radius)
	end
end

local function customExplosion(position, radius, playerId)
	radius = radius or DEFAULT_EXPLOSION_RADIUS
	if radius <= 0 then return end

	createLayeredDestruction(position, radius, playerId)
	activeExplosionEffects[#activeExplosionEffects + 1] = {
		position = VecCopy(position),
		radius = radius,
		age = 0,
		emission = {},
	}
	pendingExplosionPushes[#pendingExplosionPushes + 1] = {
		position = VecCopy(position),
		radius = radius,
	}
end

local function getPlayerAimPosition(playerId)
	local eyeTransform = GetPlayerEyeTransform(playerId)
	local _, _, endPosition = GetPlayerAimInfo(eyeTransform.pos, AIM_DISTANCE, playerId)
	return endPosition
end

local function updatePlayer(playerId, dt)
	local radius = playerExplosionRadii[playerId]
	if radius == nil then
		radius = DEFAULT_EXPLOSION_RADIUS
		playerExplosionRadii[playerId] = radius
		SetToolEnabled(TOOL_ID, true, playerId)
	end
	if GetPlayerTool(playerId) ~= TOOL_ID or GetPlayerVehicle(playerId) ~= 0 then return end

	radius = adjustExplosionRadius(radius, dt, playerId)
	playerExplosionRadii[playerId] = radius

	if InputPressed("usetool", playerId) then
		customExplosion(getPlayerAimPosition(playerId), radius, playerId)
	end
end

function server.init()
	RegisterTool(TOOL_ID, TOOL_NAME, "", TOOL_GROUP)
end

function server.tick(dt)
	processPendingExplosionPushes()

	local removedPlayers = GetRemovedPlayers()
	for index = 1, #removedPlayers do
		playerExplosionRadii[removedPlayers[index]] = nil
	end

	local players = GetAllPlayers()
	for index = 1, #players do
		updatePlayer(players[index], dt)
	end

	processExplosionParticleEffects(dt)
end

function client.tick(dt)
	local playerId = GetLocalPlayer()
	if GetPlayerTool(playerId) == TOOL_ID and GetPlayerVehicle(playerId) == 0 then
		localExplosionRadius = adjustExplosionRadius(localExplosionRadius, dt, playerId)
	end
end

function client.draw()
	local playerId = GetLocalPlayer()
	if GetPlayerTool(playerId) ~= TOOL_ID or GetPlayerVehicle(playerId) ~= 0 then return end

	UiPush()
		UiTranslate(20, UiHeight() - 20)
		UiAlign("left bottom")
		UiFont("bold.ttf", 20)
		UiColor(1, 1, 1, 1)
		UiTextOutline(0, 0, 0, 0.9, 0.2)
		UiText(string.format("Power: %.1f", localExplosionRadius))
	UiPop()
end
