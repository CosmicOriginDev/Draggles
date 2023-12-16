function init()
	local camPos=GetCameraTransform().pos
	local dist=400
	s=0--spawned
	a=0--attempts to spawn
	repeat 
		local randPos=Vec(math.random(-dist,dist),100,math.random(-dist,dist))
		local checkPos=VecAdd(randPos)
		QueryRequire("static large")
		local hit, d = QueryRaycast(checkPos,Vec(0,-1,0),dist)
		if hit then
			Spawn("MOD/prefab/repairKit.xml",Transform(VecAdd(checkPos,Vec(0,-d,0))))
			s=s+1
			
		end
		a=a+1
	--	DebugPrint("spawns"..s)
	until(s>10 or a>100)--loop until there are 10 spawns or 100 attempts to prevent overflow
end

