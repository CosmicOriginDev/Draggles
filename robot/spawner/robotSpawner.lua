function init()
	head=FindBody("head")
	headTargetPos=Vec()
	body=FindBody("body")
	nextSpawnTime=GetTime()+3
	active=false
	path=GetStringParam("spawn","MOD/robot/mech-guns.xml")
	dead=false
end

function tick()
	HP=tonumber(GetTagValue(head,"HP"))
	if HP>0 then
		t=GetTime()
		local headTrans=GetBodyTransform(head)
		local bodyTrans=GetBodyTransform(body)
		local playerDiff=VecSub(GetPlayerTransform().pos,bodyTrans.pos)
		local headTargetPos=Vec(playerDiff[1],8,playerDiff[3])
		active = VecLength(VecSub(bodyTrans.pos,GetPlayerTransform().pos))<60
		if active then
			ConstrainPosition(head,body,headTrans.pos,TransformToParentPoint(bodyTrans,headTargetPos),3)
			ConstrainOrientation(head,0,headTrans.rot,QuatLookAt(headTrans.pos,VecAdd(GetPlayerTransform().pos,Vec(0,3,0))),3)
			--spawn robots
			if t>=nextSpawnTime then
				local spawnTransform=TransformToParentTransform(headTrans,Transform(Vec(0,0,-3),Quat()))
				Spawn(path,spawnTransform,true)
				nextSpawnTime=t+3
			end
		end
	else --die
		if not dead then
			local bodies=FindBodies()
			local joints=FindJoints()
			local shapes=FindShapes()
			for j=1,#joints do 
				Delete(joints[j])
			end
			for s=1,#shapes do
				SetShapeEmissiveScale(shapes[s], 0)
			end
			for b=1,#bodies do 
				
				ApplyBodyImpulse(bodies[b],GetBodyTransform(bodies[b]).pos,Vec(math.random(-10,10),100000,math.random(-10,10)))
			end
			dead=true
		end
	end
end

