
function tick()
	local robots=FindBodies("HP",true)
	DebugPrint(#robots)
	if #robots > 10 then
		removeOldestRobot()
	end
end

function removeOldestRobot()
	local robots=FindBodies("HP",true)
	local dragon=FindBody("dragonBrain",true)
	--remove draggles from list
	for r=1,#robots do
		if robots[r]==dragon then 
			table.remove(robots,r)
		end
	end
	--find the oldest robot (lowest handle)
	local lowest=999999999999999
	for r=1,#robots do
		if robots[r]<lowest then
			lowest=robots[r]
		end
	end
	SetTag(lowest,"HP",0)
end