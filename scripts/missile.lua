function init()
	body=FindBody("body")
	shape=FindShape("shape")
	initTrans=GetBodyTransform(body)
	lastTrans=initTrans
	spent=false
	digtick=0
	lifetime=0
end

function tick()
	lifetime=lifetime+1
	if lifetime>100 and spent==false then
		Explosion(GetBodyTransform(body)["pos"],2)
		spent=true
	end
	if IsShapeBroken(shape) then
		if spent==false then
			if digtick<1 then
				Explosion(GetBodyTransform(body)["pos"],2)
			end
			if digtick<16 then
				MakeHole(lastTrans["pos"],10,10,10)
				digtick=digtick+1
			else
				spent=true
			end
		end
	else
		lastTrans=GetBodyTransform(body)
		ApplyBodyImpulse(body,lastTrans["pos"],QuatRotateVec(initTrans["rot"],Vec(0,0,-200)))
		ConstrainOrientation(body,0,GetBodyTransform(body)["rot"],initTrans["rot"])
	end
end
