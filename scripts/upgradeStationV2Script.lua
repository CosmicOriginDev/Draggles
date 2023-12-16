function init()

	whirSound=LoadSound("MOD/sounds/upgradeStationWhir.ogg")
	whir=true
	clickSound=LoadSound("MOD/sounds/upgradeStationClick.ogg")
	click=true
	upgradeSound=LoadSound("MOD/sounds/upgrade.ogg")
	dockTrigger=FindTrigger("dockTrigger")
	resetTrigger=FindTrigger("resetTrigger")
	dockMotor=FindJoint("dockMotor")
	dockBase=FindBody("dockBase")
	dragonBody=FindBody("dragonBody",true)
	upgradeTarget=FindShape("upgradeTarget",true)
	reset=true
	dragonBrain=FindBody("dragonBrain",true)
	upgradeScreen=FindScreen("upgradeScreen",true)
	upgradeTerminal=FindShape("upgradeTerminal",true)
	storedWeapons={
	GetBool("savegame.mod.dragon.bite"),
	GetBool("savegame.mod.dragon.fire"),
	GetBool("savegame.mod.dragon.rocket"),
	GetBool("savegame.mod.dragon.minigun"),
	GetBool("savegame.mod.dragon.laser"),
	GetBool("savegame.mod.dragon.grenade")
	}
	equipment={
	GetBool("savegame.mod.dragon.booster"),
	GetBool("savegame.mod.dragon.fuelPlant"),
	GetBool("savegame.mod.dragon.welderMod")
	}
	SetTag(upgradeScreen,"storage",tableToBitString(storedWeapons))
	SetTag(upgradeScreen,"equipment",tableToBitString(equipment))
	descriptions={
	
	"HYDRAULIC JAWS:\n\nPOWERFUL HYDRAULIC MECHANISMS ALLOWS THESE JAWS TO CRUSH ALMOST ANYTHING.\nDOES NOT REQUIRE FUEL TO OPERATE.",
	"FIREBREATH:\n\nFIRES A SPRAY OF IGNITED FUEL. HIGHLY EFFECTIVE AGAINST WOOD AND BRUSH.",
	"ROCKETS:\n\nTHESE ROCKETS FLY MUCH FASTER THAN MOST MILLITARY GRADE ROCKETS.\nGOOD FOR LONG DISTANCE PERCISE STRIKES.",
	"MINIGUN:\n\nSHREDS TARGETS WITH A HAIL OF BULLETS.\nIDEAL FOR COMBAT.",
	"HYPERBEAM:\n\nFIRES AN ENERGY BLAST ONCE FULLY CHARGED.\nHOLD LMB TO CHARGE.\nABLE TO DESTROY ROBOT FACTORIES.",
	"GRENADE LAUNCHER:\n\nA CANNON WHICH FIRES GRENADES IN ARCS.\nTAKE CAUTION AS GRENADES CAN DAMAGE DRAGGLES."
	
	}
	equipmentDescriptions={
	"AFTERBURNER:\n\nUSES A CONTROLLED EXPLOSION TO PROPEL DRAGGLES THROUGH THE AIR.\nHOLD SHIFT TO ACTIVATE.",
	"FUEL PLANT:\n\nUSES A SPECIAL BACTERIA TO CONVERT ORGANICS INTO FUEL.\nREQUIRES HYDRAULIC JAWS TO FUNCTION.",
	"REPAIR MODULE:\n\nUSES NANOBOTS TO REPAIR DRAGGLES WHEN DAMAGED.\nREQUIRES HYDRAULIC JAWS TO CONSUME MATERIALS."
	}
	
end
function tableToBitString(table)
	local bits=""
	for i=1,#table do
		if table[i] then
			bits=bits.."1"
		else
			bits=bits.."0"
		end
	end
	return bits
end
function update()
	if IsShapeInTrigger(dockTrigger,upgradeTarget)==true and reset==true then --check if mech is in upgrade dock and already reset
		SetTag(upgradeScreen,"activate")
		if whir then
			PlaySound(whirSound)
			whir=false
		end
		if click and GetJointMovement(dockMotor)==2 then
			PlaySound(clickSound)
			click=false
		end
		
		local targetPos=VecAdd(GetBodyTransform(dockBase)["pos"],Vec(0,2.25,0))
		local targetRot=QuatRotateQuat(GetBodyTransform(dockBase)["rot"],QuatAxisAngle(Vec(0,1,0),180))
		ConstrainPosition(dragonBody,0,GetBodyTransform(dragonBody)["pos"],targetPos)
		ConstrainOrientation(dragonBody,0,GetBodyTransform(dragonBody)["rot"],targetRot)
		SetJointMotorTarget(dockMotor,1.4,2)
		if detectInteract()==upgradeTerminal then
			SetPlayerScreen(upgradeScreen)
			
		end
	end
	if IsShapeInTrigger(resetTrigger,upgradeTarget)==false then
		reset=true
		whir=true
		click=true
	end
	--terminal
	
	updateEquippedWeaponsOnScreen()
	
	if HasTag(upgradeScreen,"done") then
		RemoveTag(upgradeScreen,"selectedStorage")
		RemoveTag(upgradeScreen,"selectedWeapon")
		RemoveTag(upgradeScreen,"cancel")
		SetJointMotorTarget(dockMotor,0,2)
		if reset then
			PlaySound(whirSound)
			PlaySound(clickSound)
		end
		reset=false
		RemoveTag(upgradeScreen,"activate")
		RemoveTag(upgradeScreen,"done")
		
	end
	local cancel=HasTag(upgradeScreen,"cancel")
	if cancel then
		RemoveTag(upgradeScreen,"selectedStorage")
		RemoveTag(upgradeScreen,"selectedWeapon")
		RemoveTag(upgradeScreen,"selectedEquipment")
		RemoveTag(upgradeScreen,"cancel")
	end
	if HasTag(upgradeScreen,"selectedStorage") then 
		RemoveTag(upgradeScreen,"selectedEquipment")
		local selectedStorage=tonumber(GetTagValue(upgradeScreen,"selectedStorage"))
		SetTag(upgradeScreen,"weaponText",descriptions[selectedStorage])
		local weaponName={"bite","fire","rocket","minigun","laser","grenade"}
		SetTag(upgradeScreen,"level",GetInt("savegame.mod.dragon."..weaponName[selectedStorage].."Lvl")+1)
	end
	if HasTag(upgradeScreen,"selectedEquipment") then
		local selectedEquipment=tonumber(GetTagValue(upgradeScreen,"selectedEquipment"))
		SetTag(upgradeScreen,"weaponText",equipmentDescriptions[selectedEquipment])
		local equipmentName={"booster","fuelPlant","welderMod"}
		SetTag(upgradeScreen,"level",GetInt("savegame.mod.dragon."..equipmentName[selectedEquipment].."Lvl")+1)
	end
	if HasTag(upgradeScreen,"selectedWeapon") then
		local selectedStorage=tonumber(GetTagValue(upgradeScreen,"selectedStorage"))
		local selectedWeapon=GetTagValue(upgradeScreen,"selectedWeapon")
		local weaponName={"bite","fire","rocket","minigun","laser","grenade"}
		SetString("savegame.mod.dragon.weapon"..selectedWeapon,weaponName[selectedStorage])
		
		SetTag(dragonBrain,"currentCommand","updateStats")
		SetTag(upgradeScreen,"cancel")
	end
	
	--DebugPrint(selectedStorage)
	--DebugPrint(selectedWeapon)
end

function detectInteract()
	if InputDown("interact") then
		return GetPlayerInteractShape()
	else
		return -1
	end
end

function updateEquippedWeaponsOnScreen()
	--tag setup
	--translate names into y coords for weapon screen
	local enabledWeapons={GetString("savegame.mod.dragon.weapon1"),GetString("savegame.mod.dragon.weapon2"),GetString("savegame.mod.dragon.weapon3"),GetString("savegame.mod.dragon.weapon4")}
	local y={0,0,0,0}
	for i=1,#y do
		if enabledWeapons[i]=="none" then
			y[i]=0
		elseif enabledWeapons[i]=="bite" then
			y[i]=16
		elseif enabledWeapons[i]=="fire" then
			y[i]=32
		elseif enabledWeapons[i]=="rocket" then
			y[i]=48
		elseif enabledWeapons[i]=="minigun" then
			y[i]=64
		elseif enabledWeapons[i]=="laser" then
			y[i]=80
		elseif enabledWeapons[i]=="grenade" then
			y[i]=96
		else 
			y[i]=0
		end
	end
	SetTag(upgradeScreen,"y1",y[1])
	SetTag(upgradeScreen,"y2",y[2])
	SetTag(upgradeScreen,"y3",y[3])
	SetTag(upgradeScreen,"y4",y[4])
end


function increaseSaveDataInt(address,amount)
	local a=GetInt(address)
	local b=a+amount
	SetInt(address,b)
end
