function init()
	local dim=GetInt("savegame.mod.dragon.dimension")
	local camPos=GetCameraTransform().pos
	local dist=400
	for s=1,2000 do
		local randPos=Vec(math.random()*dist,math.random()*dist,math.random()*dist)
		local checkPos=VecAdd(randPos)
		local rand= math.floor(math.random()*100)
		if checkIfIndoors(checkPos) then
			if dim==0 then --normal
				if rand<10 then
					Spawn("MOD/prefab/minigunUpgrade.xml",Transform(checkPos,Quat()))
					--DebugPrint("spawned minigun")
				elseif rand<20 then
					Spawn("MOD/prefab/rocketUpgrade.xml",Transform(checkPos,Quat()))
					--DebugPrint("spawned rocket")
				elseif rand<30 then
					Spawn("MOD/prefab/boosterUpgrade.xml",Transform(checkPos,Quat()))
				   -- DebugPrint("spawned booster")
				elseif rand<40 then
					Spawn("MOD/prefab/fireUpgrade.xml",Transform(checkPos,Quat()))
					--DebugPrint("spawned fire")
				
				else
					Spawn("MOD/prefab/fuelUpgrade.xml",Transform(checkPos,Quat()))
					--DebugPrint("spawned fuel")
				end
			elseif dim==1 then --robot
				if rand<20 then
					Spawn("MOD/prefab/hyperBeamUpgrade.xml",Transform(checkPos,Quat()))
				--DebugPrint("spawned hyperbeam")
				elseif rand<40 then
					Spawn("MOD/prefab/grenadeUpgrade.xml",Transform(checkPos,Quat()))
				--	DebugPrint("spawned grenade")
				elseif rand<60 then
					Spawn("MOD/prefab/fuelPlantUpgrade.xml",Transform(checkPos,Quat()))
				--	DebugPrint("spawned fuel plant")
				elseif rand<80 then
					Spawn("MOD/prefab/welderModUpgrade.xml",Transform(checkPos,Quat()))
				--	DebugPrint("spawned repair mod")
				else
					Spawn("MOD/prefab/HPUpgrade.xml",Transform(checkPos,Quat()))
				--	DebugPrint("spawned HP")
				end
			end
		end
	end
end

function checkIfIndoors(pos)
	
	--do 6 raycasts to check if there is are walls in 4 directions, a floor, and a ceiling.
	--QueryRequire("large")--make sure hits only apply to large static objects most likey to be buildings
	--check sides
	for cs=1,4 do 
		QueryRequire("physical large static")
		local dir=QuatRotateVec(QuatAxisAngle(Vec(0,1,0),cs*90),Vec(1,0,0))
		local hit = QueryRaycast(pos,dir,10)
		if hit==false then --exit function if an open space is detected
			return false
		end
	end
	--check top and bottom
	QueryRequire("physical large static")
	local hit = QueryRaycast(pos,Vec(0,1,0),10)
	if hit==false then --exit function if an open space is detected
		return false
	end
	QueryRequire("physical large static")
	local hit = QueryRaycast(pos,Vec(0,-1,0),10)
	if hit==false then --exit function if an open space is detected
		return false
	end
	-- if it hasn't exited already, it must be indoors! :)
	return true
end