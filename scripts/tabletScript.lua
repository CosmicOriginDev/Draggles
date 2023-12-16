function init()
	prepare()
end
function setup()
	prepare()
end
function prepare()
	if FindBody("dragonBrain",true)==0 then --check if there is already a dragon
		Spawn("MOD/prefab/robodragon.xml",Transform(Vec(0,GetPlayerCameraTransform()["pos"][2]+100,0)))
	end
	if FindBody("NOSPAWNDRAGONMODLOOT",true)==0 then
		Spawn("MOD/prefab/canisterSpawn.xml",Transform())
	end
	if FindBody("dimensionManager",true)==0 then
		Spawn("MOD/prefab/dimensionManager.xml",Transform())
	end
	
	tabletBody=FindBody("TabletBody")
	screen=FindScreen("screen")
	commandId=1
	commands={"sit","come"}
	dragonBrain=FindBody("dragonBrain",true)
	targetPos=Vec(0,0,0)
	SetTag(dragonBrain,"currentCommand","ride")
	selectSound=LoadSound("MOD/sounds/select.ogg")
	transmitSound=LoadSound("MOD/sounds/transmit.ogg")
end

function tick()

	local selected = GetString("game.player.tool") == "dragonTablet"
	local toolTransform = GetBodyTransform(GetToolBody())
	if selected then
		
		local toolRotVec = Vec()
		toolRotVec[1], toolRotVec[2], toolRotVec[3] =GetQuatEuler(toolTransform.rot)
		SetBodyTransform(tabletBody, Transform(toolTransform.pos,QuatEuler(toolRotVec[1]+90,toolRotVec[2],toolRotVec[3])))
		if InputPressed("rmb") then
			PlaySound(selectSound,toolTransform["pos"],100)
			commandId=commandId+1
			if commandId > #commands then
			 commandId=1
			end
		end
		if InputPressed("lmb") then
				PlaySound(transmitSound,toolTransform["pos"],100)
				SetTag(dragonBrain,"currentCommand",commands[commandId])
				--DebugPrint(GetTagValue(dragonBrain,"currentCommand"))
				
		end
		
		SetTag(screen,"command",commands[commandId])
		
	else
		SetBodyTransform(tabletBody,Transform(Vec(0,-999,0)))
	end
	ammo=tonumber(GetTagValue(dragonBrain,"ammo"))
	local maxammo=tonumber(GetTagValue(dragonBrain,"maxammo"))
	ammoText=""
	local ammoPercent=ammo/maxammo
	
	for i=1,6 do
		if i<=math.floor(ammoPercent*6) then
			ammoText=ammoText.."#"
		else
			ammoText=ammoText.."_"
		end
	end
	ammoText=ammoText.."["..math.floor(ammo).."/"..math.floor(maxammo).."]"
	HP=tonumber(GetTagValue(dragonBrain,"HP"))
	local maxHP=tonumber(GetTagValue(dragonBrain,"maxHP"))
	HPText=""
	local HPPercent=HP/maxHP
	local reviveTime=GetTagValue(dragonBrain,"reviveTime")
	SetTag(screen,"reviveTime",reviveTime)
	if HP<=0 then
		SetTag(screen,"dead")
	else
		RemoveTag(screen,"dead")
	end
	for i=1,6 do
		if i<=math.floor(HPPercent*6) then
			HPText=HPText.."#"
		else
			HPText=HPText.."_"
		end
	end
	HPText=HPText.."["..math.floor(HP).."/"..math.floor(maxHP).."]"
	status=GetTagValue(dragonBrain,"status")
	--DebugPrint(ammo)
	SetTag(screen,"ammo",ammoText)
	SetTag(screen,"HP",HPText)
	SetTag(screen,"status",status)
	SetTag(screen,"emote",GetTagValue(dragonBrain,"expression"))
end


