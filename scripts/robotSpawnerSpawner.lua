function init()
	
	local camPos=GetCameraTransform().pos
	local dist=400
	for s=1,20 do --spawners
		local randPos=Vec(math.random(-dist,dist)+camPos[1],100,math.random(-dist,dist)+camPos[3])
		QueryRequire("static large")
		local hit, d = QueryRaycast(randPos,Vec(0,-1,0),200)
		if hit then
			local spawnPos=VecAdd(randPos,Vec(0,-d,0))
			local spawnType=math.floor(math.random(0,1)+0.5)
			if spawnType==0 then
				Spawn("MOD/robot/spawner/spawnerGuns.xml",Transform(spawnPos,Quat()),true)
			elseif spawnType==1 then
				Spawn("MOD/robot/spawner/spawnerRockets.xml",Transform(spawnPos,Quat()),true)
			end
			--DebugPrint("spawned")
		end
	end
	for d=1,100 do --decorations
		local randPos=Vec(math.random(-dist,dist)+camPos[1],100,math.random(-dist,dist)+camPos[3])
		QueryRequire("static large")
		local hit, d = QueryRaycast(randPos,Vec(0,-1,0),200)
		if hit then
			local spawnPos=VecAdd(randPos,Vec(0,-d,0))
			local spawnType=math.floor(math.random(0,3)+0.5)
			if spawnType==0 then
				Spawn("MOD/robot/decorations/ruinedTank.xml",Transform(spawnPos,Quat()),true)
			elseif spawnType==1 then
				Spawn("MOD/robot/decorations/ruinedTracked.xml",Transform(spawnPos,Quat()),true)
			elseif spawnType==2 then
				Spawn("MOD/robot/decorations/ruinedTruck.xml",Transform(spawnPos,Quat()),true)
			elseif spawnType==3 then
				Spawn("MOD/robot/decorations/ruinedAtv.xml",Transform(spawnPos,Quat()),true)
			end
			--DebugPrint("spawned")
		end
	end
end

