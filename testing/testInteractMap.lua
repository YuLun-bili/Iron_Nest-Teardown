#version 2

function client.init()
	useMap = false
	useMapCamTrans = 0
	useMapCamTransTime = 0.5

	mapTableShape = FindShape("mapTable", true)
	local mapTableVX, mapTableVY, mapTableVZ, mapTableScale = GetShapeSize(mapTableShape) -- magicaVoxel z up
	mapTableWidth = mapTableVX*mapTableScale
	mapTableHeight = mapTableVY*mapTableScale
	mapTableViewPos = Vec(0, 0, 1)
	mapTableFov = GetInt("options.gfx.fov")
end

function client.tick(dt)
	if InputPressed("p") then
		useMap = not useMap
		if useMap then
			SetValue(useMapCamTrans, 1, "linear", useMapCamTransTime*(1-useMapCamTrans))
		else
			SetValue(useMapCamTrans, 0, "linear", useMapCamTransTime*useMapCamTrans)
		end
	end
end

function client.draw(dt)
	
end