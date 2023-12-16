function init()
	trigger=FindTrigger("portalTrigger")
	destination=GetIntParam("dest",0)
	teleportSound=LoadSound("MOD/sounds/teleport.ogg")
	active=true
end
function tick()
	local playerPos=GetPlayerTransform().pos
	if IsPointInTrigger(trigger, playerPos) then
		if active then
			SetInt("savegame.mod.dragon.dimension",destination)
			SetBool("savegame.mod.dragon.dimensionUpdate",true)
		--	DebugPrint(GetInt("savegame.mod.dragon.dimension"))
			PlaySound(teleportSound)
			ParticleReset()
			ParticleColor(1,0.5,1)
			ParticleEmissive(0.5)
			for i=0,20 do
				SpawnParticle(VecAdd(playerPos,Vec(math.random(-1,1),math.random(-1,1),math.random(-1,1))),Vec(0,10,0),1)
			end
			active=false
		end
	else
		active=true
	end
end