function init()
	laserLoc=FindLocation("laserLoc")
	laserTrans=GetLocationTransform(laserLoc)
	length=100
	radius=10
	l=0
	sound=LoadLoop("MOD/sounds/laser.ogg")
	
end
function update()
	
end
function tick()
	if l<length then
		PlayLoop(sound)
		ParticleReset()
		ParticleType("plain")
		ParticleRadius(4)
		ParticleTile(4)
		ParticleColor(1,0.05,0.05)
		ParticleAlpha(0.5)
		ParticleEmissive(50)
		ParticleStretch(5)
		ParticleCollide(0)
		SpawnParticle(laserTrans.pos,QuatRotateVec(laserTrans.rot,Vec(0,0,-500)),1)
		ParticleReset()
		ParticleType("plain")
		ParticleRadius(3)
		ParticleTile(4)
		ParticleAlpha(1)
		ParticleColor(1,0.5,0.5)
		ParticleEmissive(50)
		ParticleStretch(5)
		ParticleCollide(0)
		SpawnParticle(laserTrans.pos,QuatRotateVec(laserTrans.rot,Vec(0,0,-500)),1)
		local holePos=VecAdd(laserTrans.pos,QuatRotateVec(laserTrans.rot,Vec(0,0,-l-10)))
	
		Explosion(holePos,3)
		for h=0,5 do
			MakeHole(holePos,radius,radius,radius,true)
			
		end
		l=l+radius/2
	--	DebugPrint(l)
	end
end