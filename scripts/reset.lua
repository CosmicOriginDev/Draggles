function init()
	resetButton=FindShape("resetButton")
end
function detectInteract()
	if InputDown("interact") then
		return GetPlayerInteractShape()
	else
		return -1
	end
end
function tick()
	if detectInteract()==resetButton then
		SetString("savegame.mod.dragon.weapon1","bite")
		SetString("savegame.mod.dragon.weapon2","none")
		SetString("savegame.mod.dragon.weapon3","none")
		SetString("savegame.mod.dragon.weapon4","none")
		SetBool("savegame.mod.dragon.bite",true)
		SetBool("savegame.mod.dragon.fire",false)
		SetInt("savegame.mod.dragon.fireLvl",0)
		SetBool("savegame.mod.dragon.rocket",false)
		SetInt("savegame.mod.dragon.rocketLvl",0)
		SetBool("savegame.mod.dragon.minigun",false)
		SetInt("savegame.mod.dragon.minigunLvl",0)
		SetBool("savegame.mod.dragon.booster",false)
		SetInt("savegame.mod.dragon.boosterLvl",0)
		SetBool("savegame.mod.dragon.laser",false)
		SetInt("savegame.mod.dragon.laserLvl",0)
		SetBool("savegame.mod.dragon.grenade",false)
		SetInt("savegame.mod.dragon.grenadeLvl",0)
		SetBool("savegame.mod.dragon.welderMod",false)
		SetBool("savegame.mod.dragon.fuelPlant",false)
		SetInt("savegame.mod.dragon.maxammo",0)
		SetInt("savegame.mod.dragon.maxHP",0)
		Restart()
	end
	
	
end