#include "script/common.lua"
function init()
	--data for all the robots
	robots={}
	dragonHead=FindBody("dragonBrain",true)
	dragonBody=FindBody("dragonBody",true)
	--bullets
	bullets={}
	bullets.pos={}
	bullets.vel={}
	bullets.age={}
	bullets.type={}
	--sound
	shootSound = LoadSound("tools/gun0.ogg", 80)
	rocketSound = LoadSound("tools/launcher0.ogg", 70)
	explodeSound=LoadSound("explosion/l2.ogg",100)
	explosionSprite = LoadSprite("/gfx/glare.png")
end

function update()
	robots=FindBodies("enemyBot",true)
	if tonumber(GetTagValue(dragonHead,"HP"))<=0 then
		if #robots>0 then
			for i=1,#robots do 
				Delete(robots[i])
			end
		end
	end
	local playerTransform=GetBodyTransform(dragonBody)
	for b=1,#robots do
		
		local currentPos=GetBodyTransform(robots[b]).pos
		local moveTo=moveTowardsPlayer(robots[b],0.5)
		local newPos=VecAdd(currentPos,moveTo)
		SetBodyTransform(robots[b],Transform(newPos,QuatLookAt(currentPos,playerTransform.pos)))
		local robotType=GetTagValue(robots[b],"type")
		if robotType=="guns" then
			if math.random()<=0.01 then 
				shootGuns(robots[b])
			end
		elseif robotType=="rockets" then
			if math.random()<=0.005 then 
				shootRockets(robots[b])
			end
		end
		checkIfDead(robots[b])
	end
	--updare bullets
	local b=1
	local dragonPos=GetBodyTransform(dragonBody).pos
	while b<#bullets.pos do
		if bullets.age[b]<100 then
			bullets.pos[b]=VecAdd(bullets.pos[b],bullets.vel[b])
			bullets.age[b]=bullets.age[b]+1
			if bullets.type[b]=="bullet" then
				DrawLine(bullets.pos[b],VecAdd(bullets.pos[b],VecNormalize(bullets.vel[b])))
				if VecLength(VecSub(bullets.pos[b],dragonPos))<5 then
					dealDamage(1)
					bullets.age[b]=999
				end
			elseif bullets.type[b]=="rocket" then
				DrawLine(bullets.pos[b],VecAdd(bullets.pos[b],VecNormalize(bullets.vel[b])),1,0,0)
				if VecLength(VecSub(bullets.pos[b],dragonPos))<5 then
					dealDamage(2)
					Explosion(bullets.pos[b],1)
					bullets.age[b]=999
					
				end
			end
			
		else
			table.remove(bullets.pos,b)
			table.remove(bullets.vel,b)
			table.remove(bullets.age,b)
			table.remove(bullets.type,b)
		end
		b=b+1
		
	end
end


function handleCommand(cmd) --used to detect bullets
	--DebugPrint(cmd)
	words = splitString(cmd, " ")
	if #words == 5 then
		if words[1] == "explosion" then
			local strength = tonumber(words[2])
			local x = tonumber(words[3])
			local y = tonumber(words[4])
			local z = tonumber(words[5])
			checkIfExploded(x,y,z,strength)
		end
	end
	if #words == 8 then
		if words[1] == "shot" then
			local strength = tonumber(words[2])
			local x = tonumber(words[3])
			local y = tonumber(words[4])
			local z = tonumber(words[5])
			local dx = tonumber(words[6])
			local dy = tonumber(words[7])
			local dz = tonumber(words[8])
			checkIfShot(x,y,z,strength)
		end
	end
end
function checkIfShot(x,y,z,s)
	for b=1,#robots do
		local testVec=Vec(x,y,z)
		local d = VecLength(VecSub(testVec,GetBodyTransform(robots[b]).pos))
		if d<20 then
			takeDamage(robots[b],s) --take damage
		end
	end
end
function checkIfExploded(x,y,z,s)
	for b=1,#robots do
		local testVec=Vec(x,y,z)
		local d = VecLength(VecSub(testVec,GetBodyTransform(robots[b]).pos))
		if d<20 then
			takeDamage(robots[b],s) --take damage
		end
	end
end
function takeDamage(body, damage)
	local getHP=tonumber(GetTagValue(body, "HP"))
	local newHP=getHP-damage
	SetTag(body,"HP",newHP)
end
function checkIfDead(body)
	local HP=tonumber(GetTagValue(body,"HP"))
	if HP==nil then
		Delete(body)
		robots=FindBodies("enemyBot",true)
	elseif HP<=0 then
		PlaySound(explodeSound,GetBodyTransform(body).pos,100)
		DrawSprite(explosionSprite,Transform(GetBodyTransform(body).pos,GetPlayerCameraTransform().rot),20,20,4,1,0.7,0.5,1,true,true)
		Delete(body)
		robots=FindBodies("enemyBot",true)
	end
end
function moveTowardsPlayer(body,speed)
	local trans=GetBodyTransform(body)
	local diff=VecSub(GetPlayerTransform().pos,trans.pos)
	
	local dir=VecNormalize(diff)
	local vel=VecScale(dir,speed*math.random(0.5,1))
	if VecLength(diff)>20 then
		return vel
	else
		return VecCross(vel,Vec(0,1,0))
	end
end

function shootGuns(body)
	PlaySound(shootSound,GetBodyTransform(body).pos,10)
	spawnBullet(GetBodyTransform(body).pos,QuatRotateVec(GetBodyTransform(body).rot,Vec(math.random(-0.1,0.1),math.random(-0.1,0.1),-1)))
end
function shootRockets(body)
	PlaySound(rocketSound,GetBodyTransform(body).pos,10)
	spawnRocket(GetBodyTransform(body).pos,QuatRotateVec(GetBodyTransform(body).rot,Vec(0,0,-1)))
end
function spawnBullet(pos,vel)
	table.insert(bullets.pos,pos)
	table.insert(bullets.vel,vel)
	table.insert(bullets.age,0)
	table.insert(bullets.type,"bullet")
end
function spawnRocket(pos,vel)
	table.insert(bullets.pos,pos)
	table.insert(bullets.vel,vel)
	table.insert(bullets.age,0)
	table.insert(bullets.type,"rocket")
end
function dealDamage(damage)
	if not HasTag(dragonHead,"invince") then --make sure draggles is not invincible
		local getHP=tonumber(GetTagValue(dragonHead, "HP"))
		local newHP=getHP-damage
		SetTag(dragonHead,"HP",newHP)
	end
end