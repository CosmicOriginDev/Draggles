function init()
	--get inital environment properties
	keys={"template","skybox","skyboxtint","skyboxbrightness","constant","ambient","ambientexposure","fogColor","fogParams","sunBrightness","sunColorTint","sunDir","sunSpread","sunLength","sunFogScale","sunGlare","exposure","brightness","wetness","puddleamount","puddlesize","rain","nightlight","ambience","fogscale","slippery","waterhurt","snowdir","snowamount","wind"}
	values={}
	for p=1,#keys do
		local a,b,c,d= GetEnvironmentProperty(keys[p])
		values[p]={a,b,c,d}
	end
	SetBool("savegame.mod.dragon.dimensionUpdate",true)
	StopMusic()
end

function tick()
	
	--update dimension
	if GetBool("savegame.mod.dragon.dimensionUpdate") then
		levelid=GetString("game.levelid")
		dragonHead=FindBody("dragonBrain",true)
		dim=GetInt("savegame.mod.dragon.dimension")
		if dim==0 then --normal world
			for p=1,#keys do
				if values[p]==nil then
					SetEnvironmentProperty(keys[p],"")
				else
					SetEnvironmentProperty(keys[p],values[p][1],values[p][2],values[p][3],values[p][4])
					--DebugPrint(keys[p].."---"..values[p][1].." "..values[p][2].." "..values[p][3].." "..values[p][4])
				end
				
			end
		elseif dim==1 then --robot dimension
			SetEnvironmentProperty("skybox","MOD/images/robot-sky.dds")--
			if FindBody("NOROBOTS",true)==0 and FindBody("robotSpawnerSpawner",true)==0 then --spawn robot spawner 
				Spawn("MOD/prefab/robotSpawn.xml",Transform())
				Spawn("MOD/robot/predatorBot/predatorBot.xml",Transform())
			end
			
		end
		SetBool("savegame.mod.dragon.dimensionUpdate",false)
	end
	--music
	if levelid=="sky" then
		PlayMusic("MOD/music/Soaring.ogg")
	else
		if levelid~="lab" then
			if dim==1 then
				if tonumber(GetTagValue(dragonHead,"HP"))>0 then		
					PlayMusic("MOD/music/robotInvasion.ogg")			
				else
					PlayMusic("MOD/music/dragglesPredatorChase.ogg")
				end
			end
		end
	end
end