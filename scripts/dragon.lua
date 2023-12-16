#include "script/common.lua"
------------------------------------------------------------------------------------
-- ROBOT SCRIPT
------------------------------------------------------------------------------------
--[[
The robot script should be parent of all bodies that make up the robot. 
Configure the robot with the type parameter that can be combinations of the following words:
investigate: investigate sounds in the environment
chase: chase player when seen, this is the most common configuration
nooutline: no outline when close and hidden
alarm: trigger alarm when player is seen and lit by light for 2.0 seconds 
stun: electrocute player when close or grabbed
avoid: avoid player (should not be combined chase, requires patrol locations)
aggressive: always know where player is (even through walls)
The following robot parts are supported:
body (type body: required)
This is the main part of the robomett and should be the hevaiest part
head (type body: required)
The head should be jointed to the body (hinge joint with or without limits). 
heardist=<value> - Maximum hearing distance in meters, default 100
eye (type light: required)
Represents robot vision. The direction of light source determines what the robot can see. Can be placed on head or body
viewdist=<value> - View distance in meters. Default 25.
viewfov=<value> - View field of view in degrees. Default 150.
aim (type body: optional)
This part will be directed towards the player when seen and is usually equipped with weapons. Should be jointed to body or head with ball joint. There can be multiple aims.
leg (type body: optional)
Legs should be jointed between body and feet. All legs will have collisions disabled when walking and enabled in rag doll mode. There can be multiple legs.
foot (type body: optional)
Foot bodies are animated with respect to the body when walking. They only collide with the environment in rag doll mode.
tag force - Movement force scale, default is 1. Can also be two values to separate linear and angular, for example: 2,0.5
weapon (type location: optional)
Usually placed on aim head or body. There are several types of weapons:
weapon=fire - Emit fire when player is close and seen
weapon=gun - Regular shot
weapon=rocket - Fire rockets
strength=<value> - The scaling factor which controls how much damage it makes (default is 1.0)
The following tags are used to control the weapon behavior (only affect gun and rocket):
idle=<seconds> - Idle time in between rounds
charge=<seconds> - Charge time before firing
cooldown=<seconds> - Cooldown between each shot in a round
count=<number> - Number of shots in a round
spread=<fraction> - How much each shot may deviates from optimal direction (for instance: 0.05 to deviate up to 5%)
maxdist=<meters> - How far away target can be to trigger shot. Default is 100
patrol (type location: optional)
If present the robot will patrol these locations. Make sure to place near walkable ground. Targets are visited in the same order they appear in scene explorer. Avoid type robots MUST have patrol targets.
roam (type trigger: optional)
If there are no patrol locations, the robot will roam randomly within this trigger.
limit (type trigger: optional)
If present the robot will try stay within this trigger volume. If robot ends up outside trigger, it will automatically navigate back inside.
investigate (type trigger: optional)
If present and the robot has type investigate it will only react to sounds within this trigger.
activate (type trigger: optional)
If present, robot will start inactive and become activated when player enters trigger
]]
------------------------------------------------------------------------------------
function VecDist(a, b)
	return VecLength(VecSub(a, b))
end
function getTagParameter(entity, name, default)
	local v = tonumber(GetTagValue(entity, name))
	if v then
		return v
	else
		return default
	end
end
function getTagParameter2(entity, name, default)
	local s = splitString(GetTagValue(entity, name), ",")
	if #s == 1 then
		local v = tonumber(s[1])
		if v then
			return v, v
		else
			return default, default
		end
	elseif #s == 2 then
		local v1 = tonumber(s[1])
		local v2 = tonumber(s[2])
		if v1 and v2 then
			return v1, v2
		else
			return default, default
		end
	else
		return default, default
	end
end
pType = GetStringParam("type", "")
pSpeed = GetFloatParam("speed", 3.5)
pTurnSpeed = GetFloatParam("turnspeed", pSpeed)
config = {}
config.hasVision = false
config.viewDistance = 25
config.viewFov = 150
config.canHearPlayer = false
config.canSeePlayer = false
config.patrol = false
config.sensorDist = 200
config.speed = pSpeed
config.turnSpeed = 999
config.huntPlayer = false
config.huntSpeedScale = 1.6
config.avoidPlayer = false
config.triggerAlarmWhenSeen = false
config.visibilityTimer = 0.3 --Time player must be seen to be identified as enemy (ideal condition)
config.lostVisibilityTimer = 5.0 --Time player is seen after losing visibility
config.outline = 13
config.aimTime = 5.0
config.maxSoundDist = 100.0
config.aggressive = false
config.stepSound = "l"
config.practice = false
PATH_NODE_TOLERANCE = 0.8
function configInit()
	local eye = FindLight("eye")
	local head = FindBody("head")
	config.patrol = FindLocation("patrol") ~= 0
	config.hasVision = eye ~= 0
	config.viewDistance = getTagParameter(eye, "viewdist", config.viewDistance)
	config.viewFov = getTagParameter(eye, "viewfov", config.viewFov)
	config.maxSoundDist = getTagParameter(head, "heardist", config.maxSoundDist)
	if hasWord(pType, "investigate") then
		config.canHearPlayer = true
		config.canSeePlayer = true
	end
	if hasWord(pType, "chase") then
		config.canHearPlayer = true
		config.canSeePlayer = true
		config.huntPlayer = true
	end
	if hasWord(pType, "avoid") and config.patrol then
		config.avoidPlayer = true
		config.canSeePlayer = true
	end
	if hasWord(pType, "alarm") then
		config.triggerAlarmWhenSeen = true
	end
	if hasWord(pType, "nooutline") then
		config.outline = 0
	end
	if hasWord(pType, "aggressive") then
		config.aggressive = true
	end
	if hasWord(pType, "practice") then
		config.canSeePlayer = true
		config.practice = true
	end
	local body = FindBody("body")
	if HasTag(body, "stepsound") then
		config.stepSound = GetTagValue(body, "stepsound")
	end
end
------------------------------------------------------------------------
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end
function rnd(mi, ma)
	local v = math.random(0,1000) / 1000
	return mi + (ma-mi)*v
end
function rejectAllBodies(bodies)
	for i=1, #bodies do
		QueryRejectBody(bodies[i])
	end
end
------------------------------------------------------------------------
robot = {}
robot.body = 0
robot.transform = Transform()
robot.axes = {}
robot.bodyCenter = Vec()
robot.navigationCenter = Vec()
robot.dir = Vec(0, 0, -1)
robot.speed = 0
robot.blocked = 0
robot.mass = 0
robot.allBodies = {}
robot.allShapes = {}
robot.allJoints = {}
robot.initialBodyTransforms = {}
robot.enabled = true
robot.deleted = false
robot.speedScale = 1
robot.breakAll = false
robot.breakAllTimer = 0
robot.distToPlayer = 100
robot.dirToPlayer = 0
robot.roamTrigger = 0
robot.limitTrigger = 0
robot.investigateTrigger = 0
robot.activateTrigger = 0
robot.stunned = 0
robot.outlineAlpha = 0
robot.canSensePlayer = false
robot.targetPos = Vec()
function robotSetAxes()
	robot.transform = GetBodyTransform(robot.body)
	robot.axes[1] = TransformToParentVec(robot.transform, Vec(1, 0, 0))
	robot.axes[2] = TransformToParentVec(robot.transform, Vec(0, 1, 0))
	robot.axes[3] = TransformToParentVec(robot.transform, Vec(0, 0, 1))
end
function robotInit()
	robot.body = FindBody("body")
	robot.allBodies = FindBodies()
	robot.allShapes = FindShapes()
	robot.allJoints = FindJoints()
	robot.roamTrigger = FindTrigger("roam")
	robot.limitTrigger = FindTrigger("limit")
	robot.investigateTrigger = FindTrigger("investigate")
	robot.activateTrigger = FindTrigger("activate")
	if robot.activateTrigger ~= 0 then
		SetTag(robot.body, "inactive")
	end
	for i=1, #robot.allBodies do
		robot.initialBodyTransforms[i] = GetBodyTransform(robot.allBodies[i])
	end
	robotSetAxes()
end
function robotTurnTowards(pos)
	robot.dir = VecNormalize(VecSub(pos, robot.transform.pos))
end
function robotSetDirAngle(angle)
	robot.dir[1] = math.cos(angle)
	robot.dir[3] = math.sin(angle)
end
function robotGetDirAngle()
	return math.atan2(robot.dir[3], robot.dir[1])
end
function robotUpdate(dt)
	
	
	
	
	dragonUpdate(dt)
	if dragon.HP<=0 then 
		dragon.dead=true
		PlaySound(dragon.sound.death,GetPlayerCameraTransform().pos,10)
	end
	local vel = GetBodyVelocity(robot.body)
	local fwdSpeed = VecDot(vel, robot.dir)
	local blocked = 0
	if robot.speed > 0 and fwdSpeed > -0.1 then
		blocked = 1.0 - clamp(fwdSpeed/0.5, 0.0, 1.0)
	end
	robot.blocked = robot.blocked * 0.95 + blocked * 0.05
	--Always blocked if fall is detected
	if sensor.detectFall > 0 then
		robot.blocked=1
	end
	--Evaluate mass every frame since robots can break
	robot.mass = 0
	local bodies = FindBodies()
	for i=1, #bodies do
		robot.mass = robot.mass + GetBodyMass(bodies[i])
	end
	
	robot.navigationCenter = TransformToParentPoint(robot.transform, Vec(0, -hover.distTarget, 0))
	--Handle break all
	robot.breakAllTimer = math.max(0.0, robot.breakAllTimer - dt)
	if not robot.breakAll and robot.breakAllTimer > 0.0 then
		for i=1, #robot.allShapes do
			SetTag(robot.allShapes[i], "breakall")
		end
		robot.breakAll = true
	end
	if robot.breakAll and robot.breakAllTimer <= 0.0 then
		for i=1, #robot.allShapes do
			RemoveTag(robot.allShapes[i], "breakall")
		end
		robot.breakAll = false
	end
	--Distance and direction to player
	local pp = VecAdd(robot.targetPos, Vec(0, 1, 0))
	local d = VecSub(pp, robot.bodyCenter)
	robot.distToPlayer = VecLength(d)
	robot.dirToPlayer = VecScale(d, 1.0/robot.distToPlayer)
	--Sense player if player is close and there is nothing in between
	robot.canSensePlayer = false
	if robot.distToPlayer < 3.0 then
		rejectAllBodies(robot.allBodies)
		if not QueryRaycast(robot.bodyCenter, robot.dirToPlayer, robot.distToPlayer) then
			robot.canSensePlayer = true
		end
	end
	--Robot body sounds
	if robot.enabled and hover.contact > 0 then
		local vol
		vol = clamp(VecLength(GetBodyVelocity(robot.body)) * 0.4, 0.0, 1.0)
		if vol > 0 then
			PlayLoop(walkLoop, robot.transform.pos, vol)
		end
		vol = clamp(VecLength(GetBodyAngularVelocity(robot.body)) * 0.4, 0.0, 1.0)
		if vol > 0 then
			PlayLoop(turnLoop, robot.transform.pos, vol)
		end
	end
end
------------------------------------------------------------------------
hover = {}
hover.hitBody = 0
hover.contact = 0.0
hover.distTarget = 1.1
hover.distPadding = 0.01
hover.timeSinceContact = 0.0
function hoverInit()
	local f = FindBodies("foot")
	if #f > 0 then
		hover.distTarget = 0
		for i=1, #f do
			local ft = GetBodyTransform(f[i])
			local fp = TransformToLocalPoint(robot.transform, ft.pos)
			hover.distTarget = math.max(hover.distTarget, -fp[2])
		end
	else
		QueryRequire("physical large")
		rejectAllBodies(robot.allBodies)
		local maxDist = 2.0
		local hit, dist = QueryRaycast(robot.transform.pos, VecScale(robot.axes[2], -1), maxDist)
		if hit then
			hover.distTarget = dist
			hover.distPadding = math.min(0.3, dist*0.5)
		end
	end
end
function hoverFloat()
	if hover.contact > 0 then
		local d = clamp(hover.distTarget - hover.currentDist, -0.2, 0.2)
		local v = d * 10
		local f = hover.contact * math.max(0, d*robot.mass*5.0) + robot.mass*0.2
		ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, Vec(0,1,0), v, 0 , f)
	end
end
UPRIGHT_STRENGTH = 10	-- Spring strength
UPRIGHT_MAX = 100	-- Max spring force
UPRIGHT_BASE = 10		-- Fraction of max spring force to always apply (less springy)
function hoverUpright()
	local fwd = VecScale(robot.axes[3], -1)
	local up = VecCross(robot.axes[2], VecAdd(VecScale(fwd,-dragon.sitOffset),Vec(0,1,0)))
	axes = {}
	axes[1] = Vec(1,0,0)
	axes[2] = Vec(0,1,0)
	axes[3] = Vec(0,0,1)
	for a = 1, 3, 2 do
		local d = VecDot(up, axes[a])
		local v = math.clamp(d * 15, -2, 2)
		local f = math.clamp(math.abs(d)*UPRIGHT_STRENGTH, -UPRIGHT_MAX, UPRIGHT_MAX)
		f = f + UPRIGHT_MAX * UPRIGHT_BASE
		f = f * robot.mass
		--f = f * hover.contact
		--f = 10000
		ConstrainAngularVelocity(robot.body, hover.hitBody, axes[a], v, -f , f)
		
	end
end
function hoverGetUp()
	local up = VecCross(robot.axes[2], VecAdd(Vec(0,1,0)))
	axes = {}
	axes[1] = Vec(1,0,0)
	axes[2] = Vec(0,1,0)
	axes[3] = Vec(0,0,1)
	for a = 1, 3, 2 do
		local d = VecDot(up, axes[a])
		local v = math.clamp(d * 15, -2, 2)
		local f = math.clamp(math.abs(d)*UPRIGHT_STRENGTH, -UPRIGHT_MAX, UPRIGHT_MAX)
		f = f + UPRIGHT_MAX * UPRIGHT_BASE
		f = f * robot.mass
		ConstrainAngularVelocity(robot.body, hover.hitBody, axes[a], v, -f , f)
	end
end
function hoverTurn()
	local fwd = VecScale(robot.axes[3], -1)
	local c = VecCross(fwd, robot.dir)
	local d = VecDot(c, robot.axes[2])
	local angVel = clamp(d*10, -config.turnSpeed * robot.speedScale * 10, config.turnSpeed * robot.speedScale * 10)
	local curr = VecDot(robot.axes[2], GetBodyAngularVelocity(robot.body))
	angVel = curr + clamp(angVel - curr, -1*robot.speedScale, 1*robot.speedScale)
	ConstrainAngularVelocity(robot.body, hover.hitBody, robot.axes[2], angVel,-999999,999999)
end
function hoverMove(dir)
	local desiredSpeed = robot.speed * robot.speedScale
	local fwd = VecScale(dir, -1)
	fwd[2] = 0
	fwd = VecNormalize(fwd)
	local side = VecCross(Vec(0,1,0), fwd)
	local currSpeed = VecDot(fwd, GetBodyVelocityAtPos(robot.body, robot.bodyCenter))
	local speed = currSpeed + clamp(desiredSpeed - currSpeed, -0.05*robot.speedScale, 0.05*robot.speedScale)
	local f = robot.mass*0.2 * hover.contact
	if robot.speed~=0 and currentCommand~="sit" then
		ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, fwd, speed, -f , f)
		ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, side, 0, -f , f)
	else
		ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, fwd, 0, -f , f)
		ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, side, 0, -f , f)
	end
end
BALANCE_RADIUS = 1
function hoverUpdate(dt)
	local dir = VecScale(robot.axes[2], -1)
	--Shoot rays from four locations downwards
	local hit = false
	local dist = 0
	local normal = Vec(0,0,0)
	local shape = 0
	local samples = {}
	samples[#samples+1] = Vec(-BALANCE_RADIUS,0,0)
	samples[#samples+1] = Vec(BALANCE_RADIUS,0,0)
	samples[#samples+1] = Vec(0,0,BALANCE_RADIUS)
	samples[#samples+1] = Vec(0,0,-BALANCE_RADIUS)
	local castRadius = 0.14
	local maxDist = hover.distTarget + hover.distPadding
	for i=1, #samples do
		QueryRequire("physical large")
		rejectAllBodies(robot.allBodies)
		local origin = TransformToParentPoint(robot.transform, samples[i])
		local rhit, rdist, rnormal, rshape = QueryRaycast(origin, dir, maxDist, castRadius)
		if rhit then
			hit = true
			dist = dist + rdist + castRadius
			if rdist == 0 then
				--Raycast origin in geometry, normal unsafe. Assume upright
				rnormal = Vec(0,1,0)
			end
			if shape == 0 then
				shape = rshape
			else
				local b = GetShapeBody(rshape)
				local bb = GetShapeBody(shape)
				--Prefer new hit if it's static or has more mass than old one
				if not IsBodyDynamic(b) or (IsBodyDynamic(bb) and GetBodyMass(b) > GetBodyMass(bb)) then
					shape = rshape
				end
			end
			normal = VecAdd(normal, rnormal)
		else
			dist = dist + maxDist
		end
	end
	--Use average of rays to determine contact and height
	if hit then
		dist = dist / #samples
		normal = VecNormalize(normal)
		hover.hitBody = GetShapeBody(shape)
		if IsBodyDynamic(hover.hitBody) and GetBodyMass(hover.hitBody) < 300 then
			--Hack alert! Treat small bodies as static to avoid sliding and glitching around on debris
			hover.hitBody = 0
		end
		hover.currentDist = dist
		hover.contact = clamp(1.0 - (dist - hover.distTarget) / hover.distPadding, 0.0, 1.0)
		hover.contact = hover.contact * math.max(0, normal[2])
	else
		hover.hitBody = 0
		hover.currentDist = maxDist
		hover.contact = 0
	end
	--Limit body angular velocity magnitude to 10 rad/s at max contact
	if hover.contact > 0 then
		local maxAngVel = 10.0 / hover.contact
		local angVel = GetBodyAngularVelocity(robot.body)
		local angVelLength = VecLength(angVel)
		if angVelLength > maxAngVel then
			SetBodyAngularVelocity(robot.body, VecScale(maxAngVel / angVelLength))
		end
	end
	if hover.contact > 0 then
		hover.timeSinceContact = 0
	else
		hover.timeSinceContact = hover.timeSinceContact + dt
	end
	hoverFloat()
	hoverUpright()
	hoverTurn()
end
------------------------------------------------------------------------
feet = {}
function feetInit()
	local f = FindBodies("foot")
	for i=1, #f do
		local foot = {}
		foot.body = f[i]
		local t = GetBodyTransform(foot.body)
		local rayOrigin = TransformToParentPoint(t, Vec(0, 0.9, 0))
		local rayDir = TransformToParentVec(t, Vec(0, -1, 0))
		foot.lastTransform = TransformCopy(t)
		foot.targetTransform = TransformCopy(t)
		foot.candidateTransform = TransformCopy(t)
		foot.worldTransform = TransformCopy(t)
		foot.stepAge = 1
		foot.stepLifeTime = 1
		foot.localRestTransform = TransformToLocalTransform(robot.transform, t)
		foot.localTransform = TransformCopy(foot.localRestTransform)
		foot.rayOrigin = TransformToLocalPoint(robot.transform, rayOrigin)
		foot.rayDir = TransformToLocalVec(robot.transform, rayDir)
		foot.rayDist = hover.distTarget + hover.distPadding
		foot.contact = true
		local mass = GetBodyMass(foot.body)
		foot.linForce = 20 * mass
		foot.angForce = 1 * mass
		local linScale, angScale = getTagParameter2(foot.body, "force", 1.0)
		foot.linForce = foot.linForce * linScale
		foot.angForce = foot.angForce * angScale
		feet[i] = foot
	end
end
function feetCollideLegs(enabled)
	local mask = 0
	if enabled then
		mask = 253
	end
	local feet = FindBodies("foot")
	for i=1, #feet do
		local shapes = GetBodyShapes(feet[i])
		for j=1, #shapes do
			SetShapeCollisionFilter(shapes[j], 2, mask)
		end
	end
	local legs = FindBodies("leg")
	for i=1, #legs do
		local shapes = GetBodyShapes(legs[i])
		for j=1, #shapes do
			SetShapeCollisionFilter(shapes[j], 2, mask)
		end
	end
end
function feetUpdate(dt)
	if robot.stunned > 0 then
		feetCollideLegs(true)
		return
	else
		feetCollideLegs(false)
	end
	local vel = GetBodyVelocity(robot.body)
	local velLength = VecLength(vel)
	local stepLength = clamp(velLength*2, 0.35, 3)
	local stepTime = math.min(stepLength / velLength * 0.5, 0.5)
	local stepHeight = stepLength * 0.3
	local inStep = false
	for i=1, #feet do
		local q = feet[i].stepAge/feet[i].stepLifeTime
		if feet[i].stepLifeTime > stepTime then
			feet[i].stepLifeTime = stepTime
		end
		if q < 0.8 then
			inStep = true
		end
	end
	for i=1, #feet do
		local foot = feet[i]
		if not inStep then
			--Find candidate footstep
			local tPredict = TransformCopy(robot.transform)
			tPredict.pos = VecAdd(tPredict.pos, VecScale(VecLerp(VecScale(robot.dir, robot.speed), vel, 0.5), stepTime*1.5))
			local rayOrigin = TransformToParentPoint(tPredict, foot.rayOrigin)
			local rayDir = TransformToParentVec(tPredict, foot.rayDir)
			QueryRequire("physical large")
			rejectAllBodies(robot.allBodies)
			local hit, dist, normal, shape = QueryRaycast(rayOrigin, rayDir, foot.rayDist)
			local targetTransform = TransformToParentTransform(robot.transform, foot.localRestTransform)
			if hit then
				targetTransform.pos = VecAdd(rayOrigin, VecScale(rayDir, dist))
			end
			foot.candidateTransform = targetTransform
		end
		--Animate foot
		if hover.contact > 0 then
			if foot.stepAge < foot.stepLifeTime then
				foot.stepAge = math.min(foot.stepAge + dt, foot.stepLifeTime)
				local q = foot.stepAge / foot.stepLifeTime
				q = q * q * (3.0 - 2.0 * q) -- smoothstep
				local p = VecLerp(foot.lastTransform.pos, foot.targetTransform.pos, q)
				p[2] = p[2] + math.sin(math.pi * q)*stepHeight
				local r = QuatSlerp(foot.lastTransform.rot, foot.targetTransform.rot, q)
				foot.worldTransform = Transform(p, r)
				foot.localTransform = TransformToLocalTransform(robot.transform, foot.worldTransform)
				if foot.stepAge == foot.stepLifeTime then
					PlaySound(stepSound, p, 0.5, false)
				end
			end
			ConstrainPosition(foot.body, robot.body, GetBodyTransform(foot.body).pos, foot.worldTransform.pos, 8, foot.linForce)
			ConstrainOrientation(foot.body, robot.body, GetBodyTransform(foot.body).rot, foot.worldTransform.rot, 16, foot.angForce)
		end
	end
	if not inStep then
		--Find best step candidate
		local bestFoot = 0
		local bestDist = 0
		for i=1, #feet do
			local foot = feet[i]
			local dist = VecLength(VecSub(foot.targetTransform.pos, foot.candidateTransform.pos))
			if dist > stepLength and dist > bestDist then
				bestDist = dist
				bestFoot = i
			end
		end
		--Initiate best footstep
		if bestFoot ~= 0 then
			local foot = feet[bestFoot]
			foot.lastTransform = TransformCopy(GetBodyTransform(foot.body))
			foot.targetTransform = TransformCopy(foot.candidateTransform)
			foot.stepAge = 0
			foot.stepLifeTime = stepTime
		end
	end
end
------------------------------------------------------------------------
function getPerpendicular(dir)
	local perp = VecNormalize(Vec(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)))
	perp = VecNormalize(VecSub(perp, VecScale(dir, VecDot(dir, perp))))
	return perp
end
------------------------------------------------------------------------
aims = {}
function aimsInit()
	local bodies = FindBodies("aim")
	for i=1, #bodies do
		local aim = {}
		aim.body = bodies[i]
		aims[i] = aim
	end
end
function aimsUpdate(dt)
	for i=1, #aims do
		local aim = aims[i]
		local playerPos = VecCopy(robot.targetPos)
		local toPlayer = VecNormalize(VecSub(playerPos, GetBodyTransform(aim.body).pos))
		local fwd = TransformToParentVec(GetBodyTransform(robot.body), Vec(0, 0, -1))
		if (head.canSeePlayer and VecDot(fwd, toPlayer) > 0.5) or robot.distToPlayer < 4.0 then
			--Should aim
			local v = 2
			local f = 20
			local wt = GetBodyTransform(aim.body)
			local toPlayerOrientation = QuatLookAt(wt.pos, playerPos)
			ConstrainOrientation(aim.body, robot.body, wt.rot, toPlayerOrientation, v, f)
		else
			--Should not aim
			local rd = TransformToParentVec(GetBodyTransform(robot.body), Vec(0, 0, -1))
			local wd = TransformToParentVec(GetBodyTransform(aim.body), Vec(0, 0, -1))
			local angle = clamp(math.acos(VecDot(rd, wd)), 0, 1)
			local v = 2
			local f = math.abs(angle) * 10 + 3
			ConstrainOrientation(robot.body, aim.body, GetBodyTransform(robot.body).rot, GetBodyTransform(aim.body).rot, v, f)
		end
	end
end	
------------------------------------------------------------------------
sensor = {}
sensor.blocked = 0
sensor.blockedLeft = 0
sensor.blockedRight = 0
sensor.detectFall = 0
function sensorInit()
end
function sensorGetBlocked(dir, maxDist)
	dir = VecNormalize(VecAdd(dir, rndVec(0.3)))
	local origin = TransformToParentPoint(robot.transform, Vec(0, 0.8, 0))
	QueryRequire("physical large")
	rejectAllBodies(robot.allBodies)
	local hit, dist = QueryRaycast(origin, dir, maxDist)
	return 1.0 - dist/maxDist
end
function sensorDetectFall()
	dir = Vec(0, -1, 0)
	local lookAheadDist = 0.6 + clamp(VecLength(GetBodyVelocity(robot.body))/6.0, 0.0, 0.6)
	local origin = TransformToParentPoint(robot.transform, Vec(0, 0.5, -lookAheadDist))
	QueryRequire("physical large")
	rejectAllBodies(robot.allBodies)
	local maxDist = hover.distTarget + 1.0
	local hit, dist = QueryRaycast(origin, dir, maxDist, 0.2)
	return not hit
end
function sensorUpdate(dt)
	local maxDist = config.sensorDist
	local blocked = sensorGetBlocked(TransformToParentVec(robot.transform, Vec(0, 0, -1)), maxDist)
	if sensorDetectFall() then
		sensor.detectFall = 1.0
	else
		sensor.detectFall = 0.0
	end
	sensor.blocked = sensor.blocked * 0.9 + blocked * 0.1
	local blockedLeft = sensorGetBlocked(TransformToParentVec(robot.transform, Vec(-0.5, 0, -1)), maxDist)
	sensor.blockedLeft = sensor.blockedLeft * 0.9 + blockedLeft * 0.1
	local blockedRight = sensorGetBlocked(TransformToParentVec(robot.transform, Vec(0.5, 0, -1)), maxDist)
	sensor.blockedRight = sensor.blockedRight * 0.9 + blockedRight * 0.1
end
------------------------------------------------------------------------
head = {}
head.body = 0
head.eye = 0
head.dir = Vec(0,0,-1)
head.lookOffset = 0
head.lookOffsetTimer = 0
head.canSeePlayer = false
head.lastSeenPos = Vec(0,0,0)
head.timeSinceLastSeen = 999
head.seenTimer = 0
head.alarmTimer = 0
head.alarmTime = 2.0
head.aim = 0	-- 1.0 = perfect aim, 0.0 = will always miss player. This increases when robot sees player based on config.aimTime
function headInit()
	head.body = FindBody("head")
	head.eye = FindLight("eye")
	head.joint = FindJoint("head")
	head.alarmTime = getTagParameter(head.eye, "alarm", 2.0)
end
function headTurnTowards(pos)
	head.dir = VecNormalize(VecSub(pos, GetBodyTransform(head.body).pos))
end
function headUpdate(dt)
	local t = GetBodyTransform(head.body)
	local fwd = TransformToParentVec(t, Vec(0, 0, -1))
	--Check if head can see player
	local et = GetLightTransform(head.eye)
	local pp = VecCopy(robot.targetPos)
	local toPlayer = VecSub(pp, et.pos)
	local distToPlayer = VecLength(toPlayer)
	toPlayer = VecNormalize(toPlayer)
	--Determine player visibility
	local playerVisible = false
	if config.hasVision and config.canSeePlayer then
		if distToPlayer < config.viewDistance then	--Within view distance
			local limit = math.cos(config.viewFov * 0.5 * math.pi / 180)
			if VecDot(toPlayer, fwd) > limit then --In view frustum
				rejectAllBodies(robot.allBodies)
				QueryRejectVehicle(GetPlayerVehicle())
				if not QueryRaycast(et.pos, toPlayer, distToPlayer, 0, true) then --Not blocked
					playerVisible = true
				end
			end
		end
	end
	if config.aggressive then
		playerVisible = true
	end
	--If player is visible it takes some time before registered as seen
	--If player goes out of sight, head can still see for some time second (approximation of motion estimation)
	if playerVisible then
		local distanceScale = clamp(1.0 - distToPlayer/config.viewDistance, 0.5, 1.0)
		local angleScale = clamp(VecDot(toPlayer, fwd), 0.5, 1.0)
		local delta = (dt * distanceScale * angleScale) / (config.visibilityTimer / 0.5)
		head.seenTimer = math.min(1.0, head.seenTimer + delta)
	else
		head.seenTimer = math.max(0.0, head.seenTimer - dt / config.lostVisibilityTimer)
	end
	head.canSeePlayer = (head.seenTimer > 0.5)
	if head.canSeePlayer then
		head.lastSeenPos = pp
		head.timeSinceLastSeen = 0
	else
		head.timeSinceLastSeen = head.timeSinceLastSeen + dt
	end
	if playerVisible and head.canSeePlayer then
		head.aim = math.min(1.0, head.aim + dt / config.aimTime)
	else
		head.aim = math.max(0.0, head.aim - dt / config.aimTime)
	end
	if config.triggerAlarmWhenSeen then
		local red = false
		if GetBool("level.alarm") then
			red = math.mod(GetTime(), 0.5) > 0.25
		else
			if playerVisible and IsPointAffectedByLight(head.eye, pp) then
				red = true
				head.alarmTimer = head.alarmTimer + dt
				PlayLoop(chargeLoop, robot.transform.pos)
				if head.alarmTimer > head.alarmTime and playerVisible then
					SetString("hud.notification", "Detected by robot. Alarm triggered.")
					SetBool("level.alarm", true)
				end
			else
				head.alarmTimer = math.max(0.0, head.alarmTimer - dt)
			end
		end
		if red then
			SetLightColor(head.eye, 1, 0, 0)
		else
			SetLightColor(head.eye, 1, 1, 1)
		end
	end
	--Rotate head to head.dir
	local fwd = TransformToParentVec(t, Vec(0, 0, -1))
	if playerVisible then
		headTurnTowards(pp)
	end
	head.dir = VecNormalize(head.dir)
	--end
	local c = VecCross(fwd, head.dir)
	local d = VecDot(c, robot.axes[2])
	local angVel = clamp(d*10, -3, 3)
	local f = 100
	mi, ma = GetJointLimits(head.joint)
	local ang = GetJointMovement(head.joint)
	if ang < mi+1 and angVel < 0 then
		angVel = 0
	end
	if ang > ma-1 and angVel > 0 then
		angVel = 0
	end
	ConstrainAngularVelocity(head.body, robot.body, robot.axes[2], angVel, -f , f)
	local vol = clamp(math.abs(angVel)*0.3, 0.0, 1.0)
	if vol > 0 then
		PlayLoop(headLoop, robot.transform.pos, vol)
	end
end
------------------------------------------------------------------------
hearing = {}
hearing.lastSoundPos = Vec(0, -100, 0)
hearing.lastSoundVolume = 0
hearing.timeSinceLastSound = 0
hearing.hasNewSound = false
function hearingInit()
end
function hearingUpdate(dt)
	hearing.timeSinceLastSound = hearing.timeSinceLastSound + dt
	if config.canHearPlayer then
		local vol, pos = GetLastSound()
		local dist = VecDist(robot.transform.pos, pos)
		if vol > 0.1 and dist > 4.0 and dist < config.maxSoundDist then
			local valid = true
			--If there is an investigation trigger, the robot is in it and the sound is not, ignore sound
			if robot.investigateTrigger ~= 0 and IsPointInTrigger(robot.investigateTrigger, robot.bodyCenter) and not IsPointInTrigger(robot.investigateTrigger, pos) then
				valid = false
			end
			--React if time has passed since last sound or if it's substantially stronger
			if valid and (hearing.timeSinceLastSound > 2.0 or vol > hearing.lastSoundVolume*2.0) then
				local attenuation = 5.0 / math.max(5.0, dist)
				attenuation = attenuation * attenuation
				local heardVolume = vol * attenuation
				if heardVolume > 0.05 then
					hearing.lastSoundVolume = vol
					hearing.lastSoundPos = pos
					hearing.timeSinceLastSound = 0
					hearing.hasNewSound = true
				end
			end
		end
	end
end
function hearingConsumeSound()
	hearing.hasNewSound = false
end
------------------------------------------------------------------------
navigation = {}
navigation.state = "done"
navigation.path = {}
navigation.target = Vec()
navigation.hasNewTarget = false
navigation.resultRetrieved = true
navigation.deviation = 0		-- Distance to path
navigation.blocked = 0
navigation.unblockTimer = 0		-- Timer that ticks up when blocked. If reaching limit, unblock kicks in and timer resets
navigation.unblock = 0			-- If more than zero, navigation is in unblock mode (reverse direction)
navigation.vertical = 0
navigation.thinkTime = 0
navigation.timeout = 1
navigation.lastQueryTime = 0
navigation.timeSinceProgress = 0
function navigationInit()
	navigation.pathType = "standard"
end
--Prune path backwards so robot don't need to go backwards
function navigationPrunePath()
	if #navigation.path > 0 then
		for i=#navigation.path, 1, -1 do
			local p = navigation.path[i]
			local dv = VecSub(p, robot.transform.pos)
			local d = VecLength(dv)
			if d < PATH_NODE_TOLERANCE then
				--Keep everything after this node and throw out the rest
				local newPath = {}
				for j=i, #navigation.path do
					newPath[#newPath+1] = navigation.path[j]
				end
				navigation.path = newPath
				return
			end
		end
	end
end
function navigationClear()
	AbortPath()
	navigation.state = "done"
	navigation.path = {}
	navigation.hasNewTarget = false
	navigation.resultRetrieved = true
	navigation.deviation = 0
	navigation.blocked = 0
	navigation.unblock = 0
	navigation.vertical = 0
	navigation.target = Vec(0, -100, 0)
	navigation.thinkTime = 0
	navigation.lastQueryTime = 0
	navigation.unblockTimer = 0
	navigation.timeSinceProgress = 0
end
function navigationSetTarget(pos, timeout)
	pos = truncateToGround(pos)
	if VecDist(navigation.target, pos) > 2.0 then
		navigation.target = VecCopy(pos)
		navigation.hasNewTarget = true
		navigation.state = "move"
	end
	navigation.timeout = timeout
	navigation.timeSinceProgress = 0
end
function navigationUpdate(dt)
	if currentCommand~="ride" then
		if GetPathState() == "busy" then
			dragonExpress("thinking")
			robot.speed=0
			navigation.timeSinceProgress = 0
			navigation.thinkTime = navigation.thinkTime + dt
			if navigation.thinkTime > navigation.timeout then
				AbortPath()
			end
		end
	if GetPathState() ~= "busy" then
		if GetPathState() == "done" or GetPathState() == "fail" then
			if not navigation.resultRetrieved then
				if GetPathLength() > 0.5 then
					for l=0.2, GetPathLength(), 0.2 do
						navigation.path[#navigation.path+1] = GetPathPoint(l)
					end
				end			
				navigation.lastQueryTime = navigation.thinkTime
				navigation.resultRetrieved = true
				navigation.state = "move"
				navigationPrunePath()
			end
		end
		navigation.thinkTime = 0
	end
	if navigation.thinkTime == 0 and navigation.hasNewTarget then
		local startPos
		if #navigation.path > 0 and VecDist(navigation.path[1], robot.navigationCenter) < 2.0 then
			--Keep a little bit of the old path and use last point of that as start position
			--Use previous query's time as an estimate for the next
			local distToKeep = VecLength(GetBodyVelocity(robot.body))*navigation.lastQueryTime
			local nodesToKeep = math.clamp(math.ceil(distToKeep / 0.2), 1, 15)			
			local newPath = {}
			for i=1, math.min(nodesToKeep, #navigation.path) do
				newPath[i] = navigation.path[i]
			end
			navigation.path = newPath
			startPos = navigation.path[#navigation.path]
		else
			startPos = truncateToGround(robot.transform.pos)
			navigation.path = {}
		end
		local targetRadius = 5
		if GetPlayerVehicle()~=0 then
			targetRadius = 8
		end
		local target = navigation.target
		if robot.limitTrigger ~= 0 then
			target = GetTriggerClosestPoint(robot.limitTrigger, target)
			target = truncateToGround(target)
		end
		QueryRequire("physical large")
		rejectAllBodies(robot.allBodies)
		QueryPath(startPos, target, 100, targetRadius, navigation.pathType)
		navigation.timeSinceProgress = 0
		navigation.hasNewTarget = false
		navigation.resultRetrieved = false
		navigation.state = "move"
	end
	navigationMove(dt)
	if GetPathState() ~= "busy" and #navigation.path == 0 and not navigation.hasNewTarget then
		if GetPathState() == "done" or GetPathState() == "idle" then
			navigation.state = "done"
		else
			navigation.state = "fail"
		end
	end
end
end
function navigationMove(dt)

	if #navigation.path > 0 then
		if navigation.resultRetrieved then
			robot.speed=config.speed
			--If we have a finished path and didn't progress along it for five seconds, recompute
			--Should probably only do this for a limited time until giving up
			navigation.timeSinceProgress = navigation.timeSinceProgress + dt
			if navigation.timeSinceProgress > 5.0 then
				navigation.hasNewTarget = true
				navigation.path = {}
			end
		end
		if navigation.unblock > 0 then
			robot.speed = -10
			navigation.unblock = navigation.unblock - dt
		else
			local target = navigation.path[1]
			local dv = VecSub(target, robot.navigationCenter)
			local distToFirstPathPoint = VecLength(dv)
			dv[2] = 0
			local d = VecLength(dv)
			if distToFirstPathPoint < 2.5 then
				if d < PATH_NODE_TOLERANCE then
					if #navigation.path > 1 then
						--Measure verticality which should decrease speed
						local diff = VecSub(navigation.path[2], navigation.path[1])
						navigation.vertical = diff[2] / (VecLength(diff)+0.001)
						--Remove the first one
						local newPath = {}
						for i=2, #navigation.path do
							newPath[#newPath+1] = navigation.path[i]
						end
						navigation.path = newPath
						navigation.timeSinceProgress = 0
					else
						--We're done
						navigation.path = {}
						robot.speed = 0
						return
					end
				else
					--Walk towards first point on path
					robot.speed=config.speed
					robot.dir = VecCopy(VecNormalize(VecSub(target, robot.transform.pos)))
					local dirDiff = VecDot(VecScale(robot.axes[3], -1), robot.dir)
					local speedScale = math.max(0.25, dirDiff)
					speedScale = speedScale * clamp(1.0 - navigation.vertical, 0.3, 1.0)
					
				end
			else
				--Went off path, scrap everything and recompute
				navigation.hasNewTarget = true
				navigation.path = {}
			end
			--Check if stuck
			if robot.blocked > 0.2 then
				navigation.blocked = navigation.blocked + dt
				if navigation.blocked > 0.2 then
					robot.breakAllTimer = 0.1
					navigation.blocked = 0.0
				end
				navigation.unblockTimer = navigation.unblockTimer + dt
				if navigation.unblockTimer > 1 and navigation.unblock <= 0.0 then
					navigation.unblock = 1.0
					navigation.unblockTimer = 0
				end
			else
				navigation.blocked = 0
				navigation.unblockTimer = 0
			end
		end
	end
end
------------------------------------------------------------------------
stack = {}
stack.list = {}
function stackTop()
	return stack.list[#stack.list]
end
function stackPush(id)
	local index = #stack.list+1
	stack.list[index] = {}
	stack.list[index].id = id
	stack.list[index].totalTime = 0
	stack.list[index].activeTime = 0
	return stack.list[index]
end
function stackPop(id)
	if id then
		while stackHas(id) do
			stackPop()
		end
	else
		if #stack.list > 1 then
			stack.list[#stack.list] = nil
		end
	end
end
function stackHas(s)
	return stackGet(s) ~= nil
end
function stackGet(id)
	for i=1,#stack.list do
		if stack.list[i].id == id then
			return stack.list[i]
		end
	end
	return nil
end
function stackClear(s)
	stack.list = {}
	stackPush("none")
end
function stackInit()
	stackClear()
end
function stackUpdate(dt)
	if #stack.list > 0 then
		for i=1, #stack.list do
			stack.list[i].totalTime = stack.list[i].totalTime + dt
		end
		--Tick total time
		stack.list[#stack.list].activeTime = stack.list[#stack.list].activeTime + dt
	end
end
function getClosestPatrolIndex()
	local bestIndex = 1
	local bestDistance = 999
	for i=1, #patrolLocations do
		local pt = GetLocationTransform(patrolLocations[i]).pos
		local d = VecLength(VecSub(pt, robot.transform.pos))
		if d < bestDistance then
			bestDistance = d
			bestIndex = i
		end
	end
	return bestIndex
end
function getDistantPatrolIndex(currentPos)
	local bestIndex = 1
	local bestDistance = 0
	for i=1, #patrolLocations do
		local pt = GetLocationTransform(patrolLocations[i]).pos
		local d = VecLength(VecSub(pt, currentPos))
		if d > bestDistance then
			bestDistance = d
			bestIndex = i
		end
	end
	return bestIndex
end
function getNextPatrolIndex(current)
	local i = current + 1
	if i > #patrolLocations then
		i = 1	
	end
	return i
end
function markPatrolLocationAsActive(index)
	for i=1, #patrolLocations do
		if i==index then
			SetTag(patrolLocations[i], "active")
		else
			RemoveTag(patrolLocations[i], "active")
		end
	end
end
function debugState()
	local state = stackTop()
	DebugWatch("state", state.id)
	DebugWatch("activeTime", state.activeTime)
	DebugWatch("totalTime", state.totalTime)
	DebugWatch("navigation.state", navigation.state)
	DebugWatch("#navigation.path", #navigation.path)
	DebugWatch("navigation.hasNewTarget", navigation.hasNewTarget)
	DebugWatch("robot.blocked", robot.blocked)
	DebugWatch("robot.speed", robot.speed)
	DebugWatch("navigation.blocked", navigation.blocked)
	DebugWatch("navigation.unblock", navigation.unblock)
	DebugWatch("navigation.unblockTimer", navigation.unblockTimer)
	DebugWatch("navigation.thinkTime", navigation.thinkTime)
	DebugWatch("GetPathState()", GetPathState())
end
function init()
	
	configInit()
	robotInit()
	dragonInit(true)
	hoverInit()
	headInit()
	sensorInit()
	feetInit()
	aimsInit()
	navigationInit()
	hearingInit()
	stackInit()
	patrolLocations = FindLocations("patrol")
	shootSound = LoadSound("tools/gun0.ogg", 8.0)
	rocketSound = LoadSound("tools/launcher0.ogg", 7.0)
	local nomDist = 7.0
	if config.stepSound == "s" then nomDist = 5.0 end
	if config.stepSound == "l" then nomDist = 9.0 end
	stepSound = LoadSound("robot/step-" .. config.stepSound .. "0.ogg", nomDist)
	headLoop = LoadLoop("robot/head-loop.ogg", 7.0)
	turnLoop = LoadLoop("robot/turn-loop.ogg", 7.0)
	walkLoop = LoadLoop("robot/walk-loop.ogg", 7.0)
	rollLoop = LoadLoop("robot/roll-loop.ogg", 7.0)
	chargeLoop = LoadLoop("robot/charge-loop.ogg", 8.0)
	alertSound = LoadSound("robot/alert.ogg", 9.0)
	huntSound = LoadSound("robot/hunt.ogg", 9.0)
	idleSound = LoadSound("robot/idle.ogg", 9.0)
	fireLoop = LoadLoop("tools/blowtorch-loop.ogg")
	disableSound = LoadSound("robot/disable0.ogg")
end
function update(dt)
	
	robotSetAxes()
	robot.bodyCenter = TransformToParentPoint(robot.transform, GetBodyCenterOfMass(robot.body))
	
	if robot.deleted then 
		return
	else 
		if not IsHandleValid(robot.body) then
			for i=1, #robot.allBodies do
				Delete(robot.allBodies[i])
			end
			for i=1, #robot.allJoints do
				Delete(robot.allJoints[i])
			end
			robot.deleted = true
		end
	end
	if robot.activateTrigger ~= 0 then 
		if IsPointInTrigger(robot.activateTrigger, GetPlayerCameraTransform().pos) then
			RemoveTag(robot.body, "inactive")
			robot.activateTrigger = 0
		end
	end
	if HasTag(robot.body, "inactiveDRAGON") then
		robot.inactive = true
		return
	else
		if robot.inactive then
			robot.inactive = false
			--Reset robot pose
			local sleep = HasTag(robot.body, "sleeping")
			for i=1, #robot.allBodies do
				SetBodyTransform(robot.allBodies[i], robot.initialBodyTransforms[i])
				SetBodyVelocity(robot.allBodies[i], Vec(0,0,0))
				SetBodyAngularVelocity(robot.allBodies[i], Vec(0,0,0))
				if sleep then
					--If robot is sleeping make sure to not wake it up
					SetBodyActive(robot.allBodies[i], false)
				end
			end
		end
	end
	if HasTag(robot.body, "sleeping") then
		if IsBodyActive(robot.body) then
			wakeUp = true
		end
		local vol, pos = GetLastSound()
		if vol > 0.2 then
			if robot.investigateTrigger == 0 or IsPointInTrigger(robot.investigateTrigger, pos) then
				wakeUp = true
			end
		end	
		if wakeUp then
			RemoveTag(robot.body, "sleeping")
		end
		return
	end
	if dragon.dead then
		dragonExpress("dead")
		return
	end
	robotUpdate(dt)
	if not robot.enabled then
		return
	end
	
	feetUpdate(dt)
	--[[
	if IsPointInWater(robot.bodyCenter) then
		PlaySound(disableSound, robot.bodyCenter, 1.0, false)
		for i=1, #robot.allShapes do
			SetShapeEmissiveScale(robot.allShapes[i], 0)
		end
		SetTag(robot.body, "disabled")
		robot.enabled = false
	end
	]]--
	robot.stunned = clamp(robot.stunned - dt, 0.0, 6.0)
	if robot.stunned > 0 then
		head.seenTimer = 0
		weaponsReset()
		return
	end
	
	hoverUpdate(dt)
	headUpdate(dt)
	sensorUpdate(dt)
	aimsUpdate(dt)
	hearingUpdate(dt)
	stackUpdate(dt)
	if GetTagValue(dragon.brain,"currentCommand")=="ride" then
		ridingCameraUpdate()
	end
	robot.speedScale = 1
	robot.speed = 0
	local state = stackTop()
	SetTag(robot.body, "state", state.id)
	if state.id == "none" then
		if config.patrol then
			stackPush("patrol")
		else
			stackPush("roam")
		end
	end
	if state.id == "roam" then
		if not state.nextAction then
			state.nextAction = "move"
		elseif state.nextAction == "move" then
			local randomPos
			if robot.roamTrigger ~= 0 then
				randomPos = getRandomPosInTrigger(robot.roamTrigger)
				randomPos = truncateToGround(randomPos)
			else
				local rndAng = rnd(0, 2*math.pi)
				randomPos = VecAdd(robot.transform.pos, Vec(math.cos(rndAng)*6.0, 0, math.sin(rndAng)*6.0))
			end
			local s = stackPush("navigate")
			s.timeout = 1
			s.pos = randomPos
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.nextAction = "move"
		end
	end
	if state.id == "patrol" then
		if not state.nextAction then
			state.index = getClosestPatrolIndex()
			state.nextAction = "move"
		elseif state.nextAction == "move" then
			markPatrolLocationAsActive(state.index)
			local nav = stackPush("navigate")
			nav.pos = GetLocationTransform(patrolLocations[state.index]).pos
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.index = getNextPatrolIndex(state.index)
			state.nextAction = "move"
		end
	end
	if state.id == "search" then
		if state.activeTime > 2.5 then
			if not state.turn then
				robotSetDirAngle(robotGetDirAngle() + math.random(2, 4))
				state.turn = true
			end
			if state.activeTime > 6.0 then
				stackPop()
			end
		end
		if state.activeTime < 1.5 or state.activeTime > 3 and state.activeTime < 4.5 then
			head.dir = TransformToParentVec(robot.transform, Vec(-5, 0, -1))
		else
			head.dir = TransformToParentVec(robot.transform, Vec(5, 0, -1))
		end
	end
	if state.id == "investigate" then
		if not state.nextAction then
			local pos = state.pos
			robotTurnTowards(state.pos)
			headTurnTowards(state.pos)
			local nav = stackPush("navigate")
			nav.pos = state.pos
			nav.timeout = 1
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.nextAction = "done"
		elseif state.nextAction == "done" then
			PlaySound(idleSound, robot.bodyCenter, 1.0, false)
			stackPop()
		end	
	end
	if state.id == "move" then
		robotTurnTowards(state.pos)
		
		head.dir = VecCopy(robot.dir)
		local d = VecLength(VecSub(state.pos, robot.transform.pos))
		if d < 2 then
			robot.speed = 0
			stackPop()
		else
			if robot.blocked > 0.5 then
				stackPush("unblock")
			end
		end
	end
	if state.id == "unblock" then
		if not state.dir then
			if math.random(0, 10) < 5 then
				state.dir = TransformToParentVec(robot.transform, Vec(-1, 0, -1))
			else
				state.dir = TransformToParentVec(robot.transform, Vec(1, 0, -1))
			end
			state.dir = VecNormalize(state.dir)
		else
			robot.dir = state.dir
			robot.speed = -math.min(config.speed, 2.0)
			if state.activeTime > 1 then
				stackPop()
			end
		end
	end
	--Hunt player
	if state.id == "hunt" then
		if not state.init then
			navigationClear()
			state.init = true
			state.headAngle = 0
			state.headAngleTimer = 0
		end
		if robot.distToPlayer < 4.0 then
			robot.dir = VecCopy(robot.dirToPlayer)
			head.dir = VecCopy(robot.dirToPlayer)
			robot.speed = 0
			navigationClear()
		else
			navigationSetTarget(GetPlayerTransform().pos, 2)
			robot.speedScale = config.huntSpeedScale
			navigationUpdate(dt)
			if head.canSeePlayer then
				head.dir = VecCopy(robot.dirToPlayer)
				state.headAngle = 0
				state.headAngleTimer = 0
			else
				state.headAngleTimer = state.headAngleTimer + dt
				if state.headAngleTimer > 1.0 then
					if state.headAngle > 0.0 then
						state.headAngle = rnd(-1.0, -0.5)
					elseif state.headAngle < 0 then
						state.headAngle = rnd(0.5, 1.0)
					else
						state.headAngle = rnd(-1.0, 1.0)
					end
					state.headAngleTimer = 0
				end
				head.dir = QuatRotateVec(QuatEuler(0, state.headAngle, 0), robot.dir)
			end
		end
		if navigation.state ~= "move" and head.timeSinceLastSeen < 2 then
			--Turn towards player if not moving
			robot.dir = VecCopy(robot.dirToPlayer)
		end
		if navigation.state ~= "move" and head.timeSinceLastSeen > 2 and state.activeTime > 3.0 and VecLength(GetBodyVelocity(robot.body)) < 1 then
			if VecDist(head.lastSeenPos, robot.bodyCenter) > 3.0 then
				stackClear()
				local s = stackPush("investigate")
				s.pos = VecCopy(head.lastSeenPos)		
			else
				stackClear()
				stackPush("huntlost")
			end
		end
	end
	if state.id == "huntlost" then
		if not state.timer then
			state.timer = 6
			state.turnTimer = 1
		end
		state.timer = state.timer - dt
		head.dir = VecCopy(robot.dir)
		if state.timer < 0 then
			PlaySound(idleSound, robot.bodyCenter, 1.0, false)
			stackPop()
		else
			state.turnTimer = state.turnTimer - dt
			if state.turnTimer < 0 then
				robotSetDirAngle(robotGetDirAngle() + math.random(2, 4))
				state.turnTimer = rnd(0.5, 1.5)
			end
		end
	end
	--Avoid player
	if state.id == "avoid" then
		if not state.init then
			navigationClear()
			state.init = true
			state.headAngle = 0
			state.headAngleTimer = 0
		end
		local distantPatrolIndex = getDistantPatrolIndex(GetPlayerTransform().pos)
		local avoidTarget = GetLocationTransform(patrolLocations[distantPatrolIndex]).pos
		navigationSetTarget(avoidTarget, 1.0)
		robot.speedScale = config.huntSpeedScale
		navigationUpdate(dt)
		if head.canSeePlayer then
			head.dir = VecNormalize(VecSub(head.lastSeenPos, robot.transform.pos))
			state.headAngle = 0
			state.headAngleTimer = 0
		else
			state.headAngleTimer = state.headAngleTimer + dt
			if state.headAngleTimer > 1.0 then
				if state.headAngle > 0.0 then
					state.headAngle = rnd(-1.0, -0.5)
				elseif state.headAngle < 0 then
					state.headAngle = rnd(0.5, 1.0)
				else
					state.headAngle = rnd(-1.0, 1.0)
				end
				state.headAngleTimer = 0
			end
			head.dir = QuatRotateVec(QuatEuler(0, state.headAngle, 0), robot.dir)
		end
		if navigation.state ~= "move" and head.timeSinceLastSeen > 2 and state.activeTime > 3.0 then
			stackClear()
		end
	end
	--Get up player
	if state.id == "getup" then
		if not state.time then 
			state.time = 0 
		end
		state.time = state.time + dt
		hover.timeSinceContact = 0
		if state.time > 2.0 then
			stackPop()
		else
			hoverGetUp()
		end
	end
	if state.id == "navigate" then
		if not state.initialized then
			if not state.timeout then state.timeout = 10 end
			navigationClear()
			navigationSetTarget(state.pos, state.timeout)
			state.initialized = true
		else
			head.dir = VecCopy(robot.dir)
			navigationUpdate(dt)
			if navigation.state == "done" or navigation.state == "fail" then
				stackPop()
			end
		end
	end
	--React to sound
	if not stackHas("hunt") then
		if hearing.hasNewSound and hearing.timeSinceLastSound < 1.0 then
			stackClear()
			PlaySound(alertSound, robot.bodyCenter, 1.0, false)
			local s = stackPush("investigate")
			s.pos = hearing.lastSoundPos	
			hearingConsumeSound()
		end
	end
	--Seen player
	if config.huntPlayer and not stackHas("hunt") then
		if config.canSeePlayer and head.canSeePlayer or robot.canSensePlayer then
			stackClear()
			PlaySound(huntSound, robot.bodyCenter, 1.0, false)
			stackPush("hunt")
		end
	end
	--Seen player
	if config.avoidPlayer and not stackHas("avoid") then
		if config.canSeePlayer and head.canSeePlayer or robot.distToPlayer < 2.0 then
			stackClear()
			stackPush("avoid")
		end
	end
	--Get up
	if hover.timeSinceContact > 3.0 and not stackHas("getup") then
		stackPush("getup")
	end
	if IsShapeBroken(GetLightShape(head.eye)) then
		config.hasVision = false
		config.canSeePlayer = false
	end
	--debugState()
end
function canBeSeenByPlayer()
	for i=1, #robot.allShapes do
		if IsShapeVisible(robot.allShapes[i], config.outline, true) then
			return true
		end
	end
	return false
end
function tick(dt)
	if GetTagValue(dragon.brain,"currentCommand")=="ride" then
	
		ridingCameraUpdate()
		if InputPressed("interact") then
			SetPlayerTransform(Transform(VecAdd(robot.bodyCenter,Vec(0,2,0)),Quat()))
			SetTag(dragon.brain,"currentCommand","sit")
		end
	else
		checkIfRiding()
	end
	
	if dragon.dead then
		SetTag(dragon.brain,"reviveTime",math.floor(dragon.reviveTime-GetTime()))
		if GetTime()>=dragon.reviveTime then
			SetTag(dragon.brain,"HP",dragon.maxHP)
			dragon.dead = false
			teleport(VecAdd(GetPlayerCameraTransform().pos,Vec(0,50,0)))
		end
		return
	end
	dragon.reviveTime=GetTime()+60
	if not robot.enabled then
		return
	end
	if HasTag(robot.body, "turnhostile") then
		RemoveTag(robot.body, "turnhostile")
		config.canHearPlayer = true
		config.canSeePlayer = true
		config.huntPlayer = true
		config.aggressive = true
		config.practice = false
	end
	--Outline
	local dist = VecDist(robot.bodyCenter, GetPlayerCameraTransform().pos)
	if dist < config.outline then
		local a = clamp((config.outline - dist) / 5.0, 0.0, 1.0)
		if canBeSeenByPlayer() then
			a = 0
		end
		robot.outlineAlpha = robot.outlineAlpha + clamp(a - robot.outlineAlpha, -0.1, 0.1)
		for i=1, #robot.allBodies do
			DrawBodyOutline(robot.allBodies[i], 1, 1, 1, robot.outlineAlpha*0.5)
		end
	end
	--Remove planks and wires after some time
	local tags = {"plank", "wire"}
	local removeTimeOut = 10
	for i=1, #robot.allShapes do
		local shape = robot.allShapes[i]
		local joints = GetShapeJoints(shape)
		for j=1, #joints do
			local joint = joints[j]
			for t=1, #tags do
				local tag = tags[t]
				if HasTag(joint, tag) then
					local t = tonumber(GetTagValue(joint, tag)) or 0
					t = t + dt
					if t > removeTimeOut then
						if GetJointType(joint) == "rope" then
							DetachJointFromShape(joint, shape)
						else
							Delete(joint)
						end
						break
					else
						SetTag(joint, tag, t)
					end
				end
			end
		end
	end
	
end
---------------------------------------------------------------------------------
function truncateToGround(pos)
	rejectAllBodies(robot.allBodies)
	QueryRejectVehicle(GetPlayerVehicle())
	hit, dist = QueryRaycast(pos, Vec(0, -1, 0), 5, 0.2)
	if hit then
		pos = VecAdd(pos, Vec(0, -dist, 0))
	end
	return pos
end
function getRandomPosInTrigger(trigger)
	local mi, ma = GetTriggerBounds(trigger)
	local minDist = math.max(ma[1]-mi[1], ma[3]-mi[3])*0.25
	minDist = math.min(minDist, 5.0)
	for i=1, 100 do
		local probe = Vec()
		for j=1, 3 do
			probe[j] = mi[j] + (ma[j]-mi[j])*rnd(0,1)
		end
		if IsPointInTrigger(trigger, probe) then
			return probe
		end
	end
	return VecLerp(mi, ma, 0.5)
end
function handleCommand(cmd)
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
			checkIfShot(x,y,z,dx,dy,dz,strength)
		end
	end
end
function checkIfShot(x,y,z,dx,dy,dz,strength)
	if dragon.minigun.cooldown<=0 then --prevents dragon from shooting itself with minigun
		local dir=Vec(dx,dy,dz)
		local dirToDragon=VecSub(robot.bodyCenter,Vec(x,y,z))
		if VecDot(dir,dirToDragon)>0.5 then
			if VecLength(VecSub(Vec(x,y,z),robot.bodyCenter))<5 then
				
				if dragon.invince<=0 then 
					PlaySound(dragon.sound.damage,robot.bodyCenter,2,false)
					SetTag(dragon.brain,"HP",dragon.HP-1)
					dragon.invince=50
					SetTag(dragon.brain,"invince")
				end
			end
		end
	end
end
function checkIfExploded(x,y,z,strength)
	if VecLength(VecSub(Vec(x,y,z),robot.bodyCenter))<5 then
		
		if dragon.invince<=0 then 
			PlaySound(dragon.sound.damage,robot.bodyCenter,2,false)	
			SetTag(dragon.brain,"HP",dragon.HP-2)
			dragon.invince=50
			SetTag(dragon.brain,"invince")
		end
	end
end
------------------------------ D R A G O N   F U N C T I O N S ------------------------------
dragon={}
player={}
dragon.neck={}
dragon.tail={}
dragon.anim={}
dragon.target={}
dragon.modules={}
dragon.camera={}
function dragonInit(i)
	--detect first time
	if GetBool("savegame.mod.dragon.bite")==false then
		SetBool("savegame.mod.dragon.bite",true)
		SetString("savegame.mod.dragon.weapon1","bite")
		
	end
	dragon.dead=false
	dragon.reviveTime=GetTime()+60
	dragon.doors=FindShape("doors")
	dragon.camera.x=0
	dragon.camera.y=0
	dragon.camera.pos=Vec()
	dragon.camera.rot=Quat()
	dragon.camera.zoom=0
	dragon.aimQuat=Quat()
	dragon.crosshareSprite = LoadSprite("MOD/images/crosshare.png")
	dragon.flashSprite = LoadSprite("/gfx/glare.png")
	dragon.brain=FindBody("dragonBrain")
	dragon.visualHead=FindBody("dragonHead")
	dragon.blink=0
	dragon.neck.lower=FindJoint("neckLower")
	dragon.neck.middle=FindJoint("neckMiddle")
	dragon.neck.upper=FindJoint("neckUpper")
	dragon.neck.yaw=FindJoint("headYawJoint")
	dragon.headTurnAmount=0
	dragon.headPitchAmount=0
	dragon.height=0
	dragon.vSpeed=7
	speedZoom=0
	speedFov=90
	dragon.tail.base=FindJoint("tailPivotBase")
	dragon.tail.lower=FindJoint("tailPivotLower")
	dragon.tail.curl=FindJoint("tailPivotCurl")
	dragon.tail.upper=FindJoint("tailPivotUpper")
	dragon.feedingLight=FindLight("feedingLight")
	dragon.eyeScreen=FindScreen("EyeScreen")
	dragon.maxAmmo=GetInt("savegame.mod.dragon.maxammo")
	if dragon.maxAmmo<=0 then 
		SetInt("savegame.mod.dragon.maxammo",5)
		dragon.maxAmmo=5
	end
	dragon.ammo=dragon.maxAmmo
	dragon.maxHP=GetInt("savegame.mod.dragon.maxHP")
	if dragon.maxHP<=0 then 
		SetInt("savegame.mod.dragon.maxHP",10)
		dragon.maxHP=10
	end
	SetTag(dragon.brain,"HP",dragon.maxHP)
	dragon.HP=tonumber(GetTagValue(dragon.brain,"HP"))
	dragon.invince=0
	dragon.leftWingPivot=FindJoint("leftWingPivot")
	dragon.rightWingPivot=FindJoint("rightWingPivot")
	dragon.leftRotor=FindShape("rotorL")
	dragon.rightRotor=FindShape("rotorR")
	dragon.leftRotorJoint=FindJoint("rotorLJoint")
	dragon.rightRotorJoint=FindJoint("rotorRJoint")
	dragon.flightMode=false
	dragon.neck.yaw=FindJoint("headYawJoint")
	dragon.jawPivot=FindJoint("jawPivot")
	dragon.defaultRestTime=10
	dragon.restTime=dragon.defaultRestTime
	dragon.flyToPlayer=false
	dragon.sitOffset=0
	dragon.anim.id=1
	dragon.anim.timeCounter=0
	dragon.anim.rearTime=100
	SetJointMotorTarget(dragon.jawPivot,0)
	dragon.cameraTarget=Vec()
	dragon.lockRot=Quat()
	dragon.target.player=false
	dragon.target.handle=0
	dragon.target.searchState="none"
	dragon.threats={}
	dragon.sound={}
	dragon.sound.reload=LoadSound("/tool_pickup.ogg")
	dragon.sound.canisterAquire=LoadSound("/valuable.ogg")
	dragon.sound.boosterLoop=LoadLoop("tools/booster-loop.ogg")
	dragon.sound.rotorLoop=LoadLoop("/chopper-loop.ogg")
	dragon.sound.fireLoop=LoadLoop("/tools/blowtorch-loop.ogg")
	dragon.sound.laserLoop=LoadLoop("MOD/sounds/laser.ogg")
	dragon.sound.laserCharge=LoadLoop("MOD/sounds/laser-charge.ogg")
	dragon.sound.repairAquire=LoadSound("MOD/sounds/repair.ogg")
	dragon.sound.alarmSound=LoadLoop("MOD/sounds/alarm.ogg")
	dragon.sound.selectSound=LoadSound("MOD/sounds/select.ogg")
	dragon.sound.noammoSound=LoadSound("/clickdown.ogg")
	dragon.sound.petSound=LoadSound("MOD/sounds/pet.ogg")
	dragon.sound.grenadePop=LoadSound("MOD/sounds/grenadeLaunch.ogg")
	dragon.sound.death=LoadSound("MOD/sounds/death.ogg")
	dragon.sound.damage=LoadSound("/bullet-hit0")
	--module data
	--grenade launcher
	dragon.launcher={}
	dragon.launcher.shape=FindShape("launcher")
	dragon.launcher.base=FindShape("launcherBase")
	dragon.launcher.cooldown=30
	dragon.launcher.level=GetInt("savegame.mod.dragon.grenadeLvl")
	
	--minigun
	dragon.minigun={}
	dragon.minigun.base=FindShape("minigunBase")
	dragon.minigun.L=FindShape("Lmini")
	dragon.minigun.R=FindShape("Rmini")
	dragon.minigun.cooldown=2
	dragon.minigun.level=GetInt("savegame.mod.dragon.minigunLvl")
	if i then
		dragon.modules.minigunTransform=GetShapeLocalTransform(dragon.minigun.base)--store transform on body
		dragon.modules.minigunTransformL=GetShapeLocalTransform(dragon.minigun.L)
		dragon.modules.minigunTransformR=GetShapeLocalTransform(dragon.minigun.R)
		dragon.modules.launcherTransform=GetShapeLocalTransform(dragon.launcher.shape)
		dragon.modules.launcherBaseTransform=GetShapeLocalTransform(dragon.launcher.base)
	end
	--laser
	dragon.laser={}
	dragon.laser.charge=0
	dragon.laser.chargeSprites={}
	for i=1,4 do
		table.insert(dragon.laser.chargeSprites,LoadSprite("MOD/images/laser/charge"..i..".png"))
	end
	dragon.laser.cooldown=200
	dragon.laser.timeUntilNextChargeSound=GetTime()
	dragon.laser.finishingChargeLoop=false
	dragon.laser.level=GetInt("savegame.mod.dragon.laserLvl")
	dragon.laser.anim=1
	--rocket
	dragon.rocket={}
	dragon.rocket.cooldown=100
	dragon.rocket.level=GetInt("savegame.mod.dragon.rocketLvl")
	--booster
	dragon.booster={}
	dragon.booster.shape=FindShape("booster")
	dragon.booster.flameSprite=LoadSprite("MOD/images/afterburnerFlame.png")
	dragon.booster.enabled=GetBool("savegame.mod.dragon.booster")
	dragon.booster.level=GetInt("savegame.mod.dragon.boosterLvl")
	--fuelPlant
	dragon.fuelPlant={}
	dragon.fuelPlant.enabled=GetBool("savegame.mod.dragon.fuelPlant")
	dragon.fuelPlant.level=GetInt("savegame.mod.dragon.fuelPlantLvl")
	--repairMod
	dragon.repairMod={}
	dragon.repairMod.enabled=GetBool("savegame.mod.dragon.welderMod")
	dragon.repairMod.level=GetInt("savegame.mod.dragon.repairModLvl")
	--fire
	dragon.fire={}
	dragon.fire.level=GetInt("savegame.mod.dragon.fireLvl")
	if i then
		dragon.modules.boosterTransform=GetShapeLocalTransform(dragon.booster.shape)--store transform on body
	end
	dragon.weapons={}
	dragon.weapons.enabled={GetString("savegame.mod.dragon.weapon1"),GetString("savegame.mod.dragon.weapon2"),GetString("savegame.mod.dragon.weapon3"),GetString("savegame.mod.dragon.weapon4")}
	--
	SetShapeLocalTransform(dragon.minigun.base,Transform(Vec(0,-9999,0),Quat()))--hide minigun
	SetShapeLocalTransform(dragon.minigun.L,Transform(Vec(0,-9999,0),Quat()))
	SetShapeLocalTransform(dragon.minigun.R,Transform(Vec(0,-9999,0),Quat()))
	SetShapeLocalTransform(dragon.launcher.shape,Transform(Vec(0,-9999,0),Quat()))--hide launcher
	SetShapeLocalTransform(dragon.launcher.base,Transform(Vec(0,-9999,0),Quat()))
	for i=1,#dragon.weapons.enabled do
		if 	dragon.weapons.enabled[i]=="minigun" then
			SetShapeLocalTransform(dragon.minigun.base,dragon.modules.minigunTransform)--show minigun
			SetShapeLocalTransform(dragon.minigun.L,dragon.modules.minigunTransformL)
			SetShapeLocalTransform(dragon.minigun.R,dragon.modules.minigunTransformR)
		end
		if 	dragon.weapons.enabled[i]=="grenade" then
			SetShapeLocalTransform(dragon.launcher.shape,dragon.modules.launcherTransform)--show launcher
			SetShapeLocalTransform(dragon.launcher.base,dragon.modules.launcherBaseTransform)
		end
	end
	if dragon.booster.enabled then
		SetShapeLocalTransform(dragon.booster.shape,dragon.modules.boosterTransform)--show booster
	else
		SetShapeLocalTransform(dragon.booster.shape,Transform(Vec(0,-9999,0),Quat()))--hide booster
	end
	dragon.weapons.selected=dragon.weapons.enabled[1]
	dragon.weapons.screen=FindScreen("weaponScreen")
	dragonStowWings()
	SetTag(dragon.brain,"currentCommand","come")
	SetTag(dragon.brain,"status","normal")
	SetTag(dragon.brain,"maxammo",dragon.maxAmmo)
	SetTag(dragon.brain,"maxHP",dragon.maxHP)
	weaponSelectorInit()
end
function mapDistToPlayer()
	local mp=Vec(GetPlayerTransform().pos[1],0,GetPlayerTransform().pos[3])
	local pp = VecAdd(mp, Vec())
	local rm=Vec(robot.bodyCenter[1],0,robot.bodyCenter[3])
	local d = VecSub(mp, rm)
	return VecLength(d)
end
function dragonUpdate(dt)
	dragonExpress("neutral")
	--control blinking
	
	--
	SetTag(dragon.brain,"ammo",dragon.ammo)

	if tonumber(GetTagValue(dragon.brain,"HP"))<dragon.HP and dragon.invince<=0 then --check if draggles was damaged
		PlaySound(dragon.sound.damage,robot.bodyCenter,2,false)
		dragon.invince=50
		SetTag(dragon.brain,"invince")
		
	end
	dragon.HP=tonumber(GetTagValue(dragon.brain,"HP"))
	if dragon.invince>0 then --reduce invinciblity 
		dragon.invince=dragon.invince-1
		--DebugPrint("sheild:"..dragon.invince)
	else
		RemoveTag(dragon.brain,"invince")
	end
	if dragon.HP<5 then PlayLoop(dragon.sound.alarmSound,GetPlayerCameraTransform().pos,50,false) end
	if dragon.ammo<dragon.maxAmmo then
		dragonEatFuel()
	end
	dragonEatUpgrade()
	dragonEatRepairKit()
	currentCommand=GetTagValue(dragon.brain,"currentCommand")
	--DebugPrint(currentCommand)
	--DebugPrint(dragon.restTime)
	if currentCommand~="ride" then
		
		if GetTagValue(dragon.brain,"status")=="manual" then
			SetTag(dragon.brain,"status","normal")
		end
		if currentCommand ~= "defend" then
			dragonAimV3(QuatLookAt(GetBodyTransform(dragon.visualHead)["pos"],GetPlayerCameraTransform()["pos"]))
		end
		hoverMove(robot.axes[3])
		if currentCommand=="sit" then	
			dragon.flightMode=false
			dragonExpress("neutral")
			config.huntPlayer = false
			config.aggressive = false
			robot.speed=0
		--	DebugPrint(robot.speed)
			config.turnSpeed=0
			dragonMoveTail(dragonIdleTail()[1],dragonIdleTail()[2],dragonIdleTail()[3],dragon.sitOffset*90)
			--dragonLookAtValuable(2)
		
			if GetPlayerInteractBody()==dragon.visualHead and InputDown("interact") then
				if InputPressed("interact") then
					PlaySound(dragon.sound.petSound)
				end
				--DebugPrint("petting")
				dragonExpress("happy")
				dragonMoveTail((math.random()*90-45),(math.random()*90-45),(math.random()*90-45))
			end	
		end
		if currentCommand=="come" then
			--determine walk or flight
			robot.targetPos=GetPlayerTransform()["pos"]
			config.huntPlayer = true
			config.aggressive = true
			config.turnSpeed=4
			robot.speed = config.speed
			if GetPathState()=="fail" or math.abs(robot.targetPos[2]-robot.bodyCenter[2])>50 then
				dragon.flightMode=true
				dragon.height=robot.targetPos[2]+clamp(mapDistToPlayer()-10,5,100)
				robot.dir=robot.dirToPlayer
				dragonFlyMove(robot.axes[3])
				if robot.distToPlayer<10 then
					dragon.flightMode=false
				end
			end
			if robot.distToPlayer<10 then
				SetTag(dragon.brain,"currentCommand","sit")
			end
			--retrievePath()
			--drawPath()
			
		end
		
		
	else
		mountUpdate()
	end


	--DebugPrint(dragon.height)
	
	dragonThreatSystem("monitor")
	if IsPointInWater(robot.bodyCenter) then
		dragonFly(10,10)
	end
	--fly if flightmode is engaged
	if dragon.flightMode then
		dragonFly(dragon.height,dragon.vSpeed)
		dragonFlapWings()
	else
		dragonStowWings()
	end
	--cool weapons 1 unit each update
	if dragon.minigun.cooldown>=0 then
		dragon.minigun.cooldown=dragon.minigun.cooldown-1
	end
	if dragon.laser.cooldown>=0 then
		dragon.laser.cooldown=dragon.laser.cooldown-1
		
	end
	if dragon.rocket.cooldown>=0 then
		dragon.rocket.cooldown=dragon.rocket.cooldown-1
	end
	if dragon.launcher.cooldown>=0 then
		dragon.launcher.cooldown=dragon.launcher.cooldown-1
	end
	--reinitalize stats when upgraded
	if currentCommand=="updateStats" then
		dragonInit(false)
		SetTag(dragon.brain,"currentCommand","sit")
		
	end
	--DebugPrint(robot.bodyCenter[1])
	
end

function mountUpdate()
		if robot.bodyCenter[2]>300 then
			StartLevel("sky","MOD/sky.xml","",true)
		end
		--dragonStrikeNeck(-45)
		
		SetTag(dragon.brain,"status","manual")
		dragon.headTurnAmount=0
		
		config.turnSpeed=2.5
		dragon.sitOffset=0
		local cameraRot=dragon.camera.rot
		local cameraPos=dragon.camera.pos
		
	
	
		robot.dir = QuatRotateVec(cameraRot,Vec(0,0,-1))
		local targetDir=QuatRotateVec(cameraRot,Vec(0,0,-1))
		for b=1,#robot.allBodies do
			QueryRejectBody(robot.allBodies[b])
		end
		QueryRejectShape(dragon.leftRotor)
		QueryRejectShape(dragon.rightRotor)
		local hit, dist = QueryRaycast(cameraPos,targetDir,100)
		dragon.cameraTarget=VecAdd(cameraPos,QuatRotateVec(cameraRot,Vec(0,0,-dist+2)))
		dragon.aimQuat=QuatLookAt(GetBodyTransform(dragon.visualHead)["pos"],dragon.cameraTarget)
		dragonAimV3(dragon.aimQuat)
		DrawSprite(dragon.crosshareSprite,Transform(dragon.cameraTarget,cameraRot),2,2,1,0,0,1,true,false)
		dragonWalkInputs(dragon.camera.rot)
		weaponSelector()
		if InputDown("vehicleraise") then
			dragonAttack()
		end
		
		if InputDown("vehiclelower")==false and InputDown("vehicleraise")==false then
			SetJointMotorTarget(dragon.jawPivot,0)
			dragon.laser.charge=0
			
		end
		
		
		--flight mode controls
		if dragon.flightMode==false then
			if InputPressed("space") then
				dragon.flightMode=true
			end
		else
			if InputDown("space") then
				dragon.height=robot.bodyCenter[2]+2
			end
			if InputDown("ctrl") then
				dragon.height=robot.bodyCenter[2]-2
				--check if landing
				if hover.contact>0.5 then
					dragon.flightMode=false
				end
			end
		end
		
end
function dragonAttack()
		if  dragon.ammo>0 then
				dragonExpress("angry")
				SetJointMotorTarget(dragon.jawPivot,-60)
				if dragon.weapons.selected=="rocket" then
					rocket()
					
				end
				if dragon.weapons.selected=="fire" then
					fireBreath()
					dragon.ammo=dragon.ammo-0.01
				end
				if dragon.weapons.selected=="minigun" then
					minigun()
					dragon.ammo=dragon.ammo-0.01
				end
				if dragon.weapons.selected=="laser" then
					
					laser()
				
					
				end
				if dragon.weapons.selected=="grenade" then
					grenadeLauncher()
					
					
				end
			elseif dragon.weapons.selected~="bite" then
				PlaySound(dragon.sound.noammoSound,GetCameraTransform()["pos"],10)
			end
			if dragon.weapons.selected=="bite" then
				dragonExpress("angry")
				dragonBite()
			end
end
function dragonWalk(scale, direction, camDirection)
	robot.speed = config.speed
	robot.speedScale=scale
	local camDir = QuatRotateVec(camDirection,direction)
	if dragon.flightMode then
		dragonFlyMove(camDir)
	else
		hoverMove(camDir)
	end
	
end
function dragonWalkInputs(cameraRot)
		local walkSpeed=2
		local walkDir=Vec()
	
		dragon.vSpeed=7
		
		if InputDown("shift") then
			walkSpeed=3	
			if dragon.booster.enabled and dragon.ammo >0 then
				boost()
				dragon.ammo=dragon.ammo-0.01
			end
		else
		
			SetValue("speedZoom",0,"easeout",0.8)
			SetValue("speedFov",90,"easeout",0.8)
		end
		if InputDown("up") then
			walkDir[3]=1
		elseif InputDown("down") then
			walkDir[3]=-1
		else
			walkDir[3]=0
		end
		if InputDown("left") then
			walkDir[1]=1	
		elseif InputDown("right") then
			walkDir[1]=-1
		else
			walkDir[1]=0
		end
		if walkDir[1]~=0 or walkDir[3]~=0 then
			dragonWalk(walkSpeed, walkDir,cameraRot)
		else
			walkSpeed=0
			ConstrainVelocity(robot.body, 0, robot.bodyCenter, Vec(1,0,0), 0,-100000,100000)
			ConstrainVelocity(robot.body, 0, robot.bodyCenter, Vec(0,0,1), 0,-100000,100000)
		end
		
end
function dragonFly(height,Vspeed)
		--DebugPrint(hover.contact)
		--dragon.sitOffset=0.5
		ConstrainAngularVelocity(robot.body, 0, Vec(1, 0, 0), 0)
		ConstrainAngularVelocity(robot.body, 0, Vec(0, 0, 1), 0)
		local d = clamp(dragon.height-robot.transform.pos[2], -1, 1)
		local v = d * Vspeed
		local f = math.min(math.max(0, d*robot.mass*5.0) + robot.mass*0.2,1000000)
		ConstrainVelocity(robot.body, 0, robot.bodyCenter, Vec(0,1,0), v, -f,f)
		
		hoverUpright()
end
function dragonFlyMove(dir)
	local desiredSpeed = robot.speed * robot.speedScale
	local fwd = VecScale(dir, -1)
	fwd[2] = 0
	fwd = VecNormalize(fwd)
	local side = VecCross(Vec(0,1,0), fwd)
	local currSpeed = VecDot(fwd, GetBodyVelocityAtPos(robot.body, robot.bodyCenter))
	local speed = 0
	local f = robot.mass
	if InputDown("shift") and dragon.booster.enabled and dragon.ammo>0 then
		speed = currSpeed + clamp(desiredSpeed - currSpeed, -robot.speedScale, robot.speedScale)
	else
		speed = currSpeed + clamp(desiredSpeed - currSpeed, -0.05*robot.speedScale, 0.05*robot.speedScale)
	end
	ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, fwd, speed, -f , f)
	ConstrainVelocity(robot.body, hover.hitBody, robot.bodyCenter, side, 0, -f , f)
end
function dragonFlapWings()
	SetJointMotorTarget(dragon.leftWingPivot,0)
	SetJointMotorTarget(dragon.rightWingPivot,0)
	SetJointMotor(dragon.leftRotorJoint,20)
	SetJointMotor(dragon.rightRotorJoint,20)
	PlayLoop(dragon.sound.rotorLoop,robot.bodyCenter,20)
end
function dragonStowWings()
	SetJointMotorTarget(dragon.leftWingPivot,-60)
	SetJointMotorTarget(dragon.rightWingPivot,-60)
	SetJointMotor(dragon.leftRotorJoint,0)
	SetJointMotor(dragon.rightRotorJoint,0)
end
function dragonMoveNeck(angle)
	SetJointMotorTarget(dragon.neck.lower,angle)
	SetJointMotorTarget(dragon.neck.middle,angle)
	SetJointMotorTarget(dragon.neck.upper,angle)
end
function dragonYawNeck(angle)
	SetJointMotorTarget(dragon.neck.yaw,angle)
end
function dragonStrikeNeck(angle)
	SetJointMotorTarget(dragon.neck.lower,angle)
	SetJointMotorTarget(dragon.neck.middle,0)
	SetJointMotorTarget(dragon.neck.upper,angle)
end
function dragonMoveTail(upperangle,lowerangle,curlangle,baseAngle)
	SetJointMotorTarget(dragon.tail.lower,lowerangle)
	SetJointMotorTarget(dragon.tail.curl,curlangle)
	SetJointMotorTarget(dragon.tail.upper,upperangle)
	SetJointMotorTarget(dragon.tail.base,baseAngle)
end


function dragonBite()
	SetJointMotorTarget(dragon.jawPivot,math.abs(math.sin(GetTime()*10))*-60)
	local weak= MakeHole(GetBodyTransform(dragon.visualHead)["pos"],5,0,0,false)
	local mid = MakeHole(GetBodyTransform(dragon.visualHead)["pos"],5,5,0,false)
	local hard= MakeHole(GetBodyTransform(dragon.visualHead)["pos"],5,5,5,false)
	if dragon.fuelPlant.enabled then
		local ammoIncrease=weak/10000
		if dragon.ammo<dragon.maxAmmo then
			dragon.ammo=dragon.ammo+ammoIncrease
		end
	end
	if dragon.repairMod.enabled then
		local HPIncrease=(hard+mid)/10000
		if dragon.HP<dragon.maxHP then
			SetTag(dragon.brain,"HP",dragon.HP+HPIncrease)
		end
	end
	--Shoot(GetBodyTransform(dragon.visualHead)["pos"],QuatRotateVec(dragon.aimQuat,Vec(0,0,-1)),"gun",0,3)
	local robots=FindBodies("HP",true)
	--DebugPrint(#robots)
	for r=1,#robots do
		if VecLength(VecSub(GetBodyTransform(dragon.visualHead)["pos"],GetBodyTransform(robots[r])["pos"]))<10 then
			dealDamage(robots[r],1)
			--DebugPrint("bit")
		end
	end
end
function dragonIdleTail()
	local currTime=GetTime()
	local lEq=7.5-math.sin(currTime*0.5)*15
	local uEq=3.25-math.sin(currTime*0.5)*7
	local cEq=7.5-math.cos(currTime*0.5)*15
	return {lEq, uEq, cEq}
end


function dragonCircleDir()
	local centerVec=VecSub(robot.bodyCenter,Vec(0,robot.bodyCenter[2],0))
	local dir = VecCross(centerVec,Vec(0,1,0))
	return dir
end
function dragonEatFuel()
	local target=checkIfPreyInRange("shape","explosive",20,false)
 	if not HasTag(target,"NOEAT") then
		dragon.target.handle=target
		robot.targetPos = GetShapeWorldTransform(target).pos
		--DebugCross(GetShapeWorldTransform(target).pos)
		if target~= -1 then
			local val = tonumber(GetTagValue(target,"explosive"))
			if val==0 then
				val = 1
			end
			PlaySound(dragon.sound.reload,GetCameraTransform().pos,100)
			if val ~=nil then 
				dragon.ammo=dragon.ammo+(val*10)
			elseif GetTagValue(target,"explosive") then
				dragon.ammo=dragon.ammo+10
			end
			--remove excess ammo if it exceeds Max
			if dragon.ammo>dragon.maxAmmo then
				dragon.ammo=dragon.maxAmmo
			end
			Delete(target)
			SetJointMotorTarget(dragon.jawPivot,-60)
			SetJointMotorTarget(dragon.jawPivot,0)
		end
	end
end
function dragonEatUpgrade()
	local target=checkIfPreyInRange("body","upgradeCan",6,true)
	if target~=-1 then
		PlaySound(dragon.sound.canisterAquire,GetCameraTransform().pos,100)
		if HasTag(target,"fuelUP") then
			increaseSaveDataInt("savegame.mod.dragon.maxammo",5)
		end
		if HasTag(target,"HPUP") then
			increaseSaveDataInt("savegame.mod.dragon.maxHP",5)
		end	
		if HasTag(target,"boosterUP") then
			if GetBool("savegame.mod.dragon.booster") then
				increaseSaveDataInt("savegame.mod.dragon.boosterLvl",1)
			end
			SetBool("savegame.mod.dragon.booster",true)
		end
		if HasTag(target,"minigunUP") then
			if GetBool("savegame.mod.dragon.minigun") then
				increaseSaveDataInt("savegame.mod.dragon.minigunLvl",1)
			end
		SetBool("savegame.mod.dragon.minigun",true)
		end
		if HasTag(target,"rocketUP") then
			if GetBool("savegame.mod.dragon.rocket") then
				increaseSaveDataInt("savegame.mod.dragon.rocketLvl",1)
			end
			SetBool("savegame.mod.dragon.rocket",true)
		end
		if HasTag(target,"fireUP") then
			if GetBool("savegame.mod.dragon.fire") then
				increaseSaveDataInt("savegame.mod.dragon.fireLvl",1)
			end
			SetBool("savegame.mod.dragon.fire",true)
		end
		if HasTag(target,"hyperBeamUP") then
			if GetBool("savegame.mod.dragon.laser") then
				increaseSaveDataInt("savegame.mod.dragon.laserLvl",1)
			end
			SetBool("savegame.mod.dragon.laser",true)
		end
		if HasTag(target,"grenadeUP") then
			if GetBool("savegame.mod.dragon.grenade") then
				increaseSaveDataInt("savegame.mod.dragon.grenadeLvl",1)
			end
			SetBool("savegame.mod.dragon.grenade",true)
		end
		if HasTag(target,"fuelPlantUP") then
			SetBool("savegame.mod.dragon.fuelPlant",true)
		end
		if HasTag(target,"welderModUP") then
			SetBool("savegame.mod.dragon.welderMod",true)
		end
		Delete(target)
		SetJointMotorTarget(dragon.jawPivot,-60)
		SetJointMotorTarget(dragon.jawPivot,0)
	end
end
function dragonEatRepairKit()
	local target=checkIfPreyInRange("body","repairKit",6,false)
	if target~=-1 then
		PlaySound(dragon.sound.repairAquire,GetCameraTransform().pos,100)
		SetTag(dragon.brain,"HP",dragon.maxHP)
		Delete(target)
		SetJointMotorTarget(dragon.jawPivot,-60)
		SetJointMotorTarget(dragon.jawPivot,0)
	end
end
function dragonGetRandomExplosive()
	local e = {}
	local e = FindShapes("explosive",true)
	return e[math.random(#e)]
end
function checkIfPreyInRange(Ptype,tag,dist,tail)
	local target=-1
	if Ptype=="shape" then
		local possibleShapes=FindShapes(tag,true)
		local maxDist=dist
		local closeDist=999
		local index=1
		local closestIndex=1
		for i=1,#possibleShapes do
			local checkDist=VecLength(VecSub(GetShapeWorldTransform(possibleShapes[i]).pos,robot.bodyCenter))
			if checkDist<maxDist then
				maxDist=checkDist
				index=i
			end
			if checkDist<closeDist then
				closeDist=checkDist
				closestIndex=i
			end
		end
		local extail=((50-math.min(closeDist,50))/50)*90
		if tail then 
			dragonMoveTail(dragonIdleTail()[1],dragonIdleTail()[2],dragonIdleTail()[3],extail)
		end
		if maxDist==dist then
			return -1
		end
		target=possibleShapes[index]
		return target
	elseif Ptype=="body" then
		local possibleBodies=FindBodies(tag,true)
		local maxDist=dist
		local closeDist=999
		local index=1
		local closestIndex=1
		for i=1,#possibleBodies do
			local checkDist=VecLength(VecSub(GetBodyTransform(possibleBodies[i]).pos,robot.bodyCenter))
			if checkDist<maxDist then
				maxDist=checkDist
				index=i
			end
			if checkDist<closeDist then
				closeDist=checkDist
				closestIndex=i
			end
		end
		local extail=((50-math.min(closeDist,50))/50)*90
		if tail then 
			dragonMoveTail(dragonIdleTail()[1],dragonIdleTail()[2],dragonIdleTail()[3],extail)
		end
		--DebugPrint(extail)
	if maxDist==dist then
			return -1
		end
		target=possibleBodies[index]
		return target
	end
end
function dragonThreatSystem(mode)
	local nearestThreat = checkIfPreyInRange("body","aim",40,false)
	
	if nearestThreat ~= -1 then
		dragonExpress("guarding")
		if mode=="attack" then
			local cameraRot=GetCameraTransform()["rot"]
			local cameraPos=GetCameraTransform()["pos"]
			robot.dir=VecSub(GetBodyTransform(nearestThreat)["pos"],robot.bodyCenter)
			dragonAimV3(QuatLookAt(GetBodyTransform(dragon.visualHead)["pos"],GetBodyTransform(nearestThreat)["pos"]))
			--figure out if player is outside of blast range
			if VecLength(VecSub(GetBodyTransform(nearestThreat)["pos"],cameraPos))>10 then
				dragon.weapons.selected=dragon.weapons.enabled[3]--switch to rockets if available
			else
				dragon.weapons.selected=dragon.weapons.enabled[1]--switch to bite if player will get injured by blast
				if VecLength(VecSub(GetBodyTransform(nearestThreat)["pos"],robot.bodyCenter))<6 then
					local trans = GetBodyTransform(dragon.visualHead)
					local pos=trans.pos
					local dir=QuatRotateVec(trans.rot,Vec(0,0,-3))
					Shoot(VecAdd(pos,dir),dir,"gun",10)
				end
			end
			dragonAttack()
			robot.speed=config.speed
			robot.speedScale=15
			robot.targetPos=GetBodyTransform(nearestThreat)["pos"]
			robot.aggressive=true
		end
	end
end


function dragonAimV3(a)
	local headTransform=GetBodyTransform(dragon.visualHead)
	--ConstrainPosition(dragon.visualHead,robot.head,Vec(0.0 3.51 -19.82),
	ConstrainOrientation(dragon.visualHead,0,headTransform["rot"],a)
	local dir=QuatRotateVec(a,Vec(0,0,-1))
	dragonMoveNeck(math.asin(dir[2])*(180/math.pi))
end
function dragonExpress(expression)

	if expression=="neutral" then
		SetTag(dragon.eyeScreen,"eyeY","0")
	elseif expression=="blink" then
		SetTag(dragon.eyeScreen,"eyeY","8")
	elseif expression=="guarding" then
		SetTag(dragon.eyeScreen,"eyeY","16")
	elseif expression=="angry" then
		SetTag(dragon.eyeScreen,"eyeY","24")
	elseif expression=="happy" then
		SetTag(dragon.eyeScreen,"eyeY","32")
	elseif expression=="love" then
		SetTag(dragon.eyeScreen,"eyeY","40")
	elseif expression=="thinking" then
		SetTag(dragon.eyeScreen,"eyeY","48")
	elseif expression=="dead" then
		SetTag(dragon.eyeScreen,"eyeY","56")
	else
		SetTag(dragon.eyeScreen,"eyeY","0")
	end
	--blinking control
	dragon.blink=dragon.blink+1
	--DebugPrint(dragon.blink)
	if dragon.blink>500 and expression~="dead" and expression~="angry" and expression~="happy" then --cant blink when dead or with scary eyes
		SetTag(dragon.eyeScreen,"eyeY","8")
	end
	if dragon.blink>525 then
		dragon.blink=0
	end
	--
	SetTag(dragon.brain,"expression",expression)
end
function makeLandingSpace()
	MakeHole(robot.bodyCenter,80,0,0)
end
function weaponSelectorInit()
	--tag setup
	--translate names into y coords for weapon screen
	local y={0,0,0,0}
	for i=1,#y do
		if dragon.weapons.enabled[i]=="none" then
			y[i]=0
		elseif dragon.weapons.enabled[i]=="bite" then
			y[i]=16
		elseif dragon.weapons.enabled[i]=="fire" then
			y[i]=32
		elseif dragon.weapons.enabled[i]=="rocket" then
			y[i]=48
		elseif dragon.weapons.enabled[i]=="minigun" then
			y[i]=64
		elseif dragon.weapons.enabled[i]=="laser" then
			y[i]=80
		elseif dragon.weapons.enabled[i]=="grenade" then
			y[i]=96
		else 
			y[i]=0
		end
	end
	SetTag(dragon.weapons.screen,"y1",y[1])
	SetTag(dragon.weapons.screen,"y2",y[2])
	SetTag(dragon.weapons.screen,"y3",y[3])
	SetTag(dragon.weapons.screen,"y4",y[4])
end
function weaponSelector()
	local playerPos=GetPlayerCameraTransform().pos
	if InputPressed("uparrow") then
		dragon.weapons.selected=dragon.weapons.enabled[1]
		SetTag(dragon.weapons.screen,"sel",1)
		PlaySound(dragon.sound.selectSound,GetCameraTransform().pos,100)
	end
	if InputPressed("rightarrow") then
		dragon.weapons.selected=dragon.weapons.enabled[2]
		SetTag(dragon.weapons.screen,"sel",2)
		PlaySound(dragon.sound.selectSound,GetCameraTransform().pos,100)
	end
	if InputPressed("downarrow") then
		dragon.weapons.selected=dragon.weapons.enabled[3]
		SetTag(dragon.weapons.screen,"sel",3)
		PlaySound(dragon.sound.selectSound,GetCameraTransform().pos,100)
	end
	if InputPressed("leftarrow") then
		dragon.weapons.selected=dragon.weapons.enabled[4]
		SetTag(dragon.weapons.screen,"sel",4)
		PlaySound(dragon.sound.selectSound,GetCameraTransform().pos,100)
	end
end

-- UPGRADE MODULES
--rocket
function rocket()

	local trans = GetBodyTransform(dragon.visualHead)
	local pos=trans.pos
	local dir=QuatRotateVec(trans.rot,Vec(0,0,-3))
	if dragon.rocket.cooldown<=0 then
		dragon.ammo=dragon.ammo-1
		Spawn("MOD/prefab/rocket.xml",Transform(VecAdd(pos,dir),trans.rot))
		dragon.rocket.cooldown=50/math.max(dragon.rocket.level,1)--prevent div by 0
	end
end
--minigun
function minigun()
	local left=TransformToParentPoint(GetShapeWorldTransform(dragon.minigun.L),Vec(0.25,-0.5,0.25))
	local right=TransformToParentPoint(GetShapeWorldTransform(dragon.minigun.R),Vec(0.25,-0.5,0.25))
	if dragon.minigun.cooldown<=0 then
		PlaySound(shootSound)
		Shoot(left,VecAdd(QuatRotateVec(dragon.aimQuat,Vec(0,0,-1)),rndVec(0.1)),"bullet",(dragon.minigun.level*0.1)+1)
		DrawSprite(dragon.flashSprite,Transform(left,GetPlayerCameraTransform().rot),4,4,1,0.7,0.5,1,true,true)
		Shoot(right,VecAdd(QuatRotateVec(dragon.aimQuat,Vec(0,0,-1)),rndVec(0.1)),"bullet",(dragon.minigun.level*0.1)+1)
		DrawSprite(dragon.flashSprite,Transform(right,GetPlayerCameraTransform().rot),4,4,1,0.7,0.5,1,true,true)
		dragon.minigun.cooldown=2
	end
end
--laser
function laser()

	local barrelPos= TransformToParentPoint(GetBodyTransform(dragon.visualHead),Vec(0,0,-3))
	local fireCharge=5/GetTimeStep()
	
		PlayLoop(dragon.sound.laserCharge,barrelPos,10)
		dragon.laser.charge=dragon.laser.charge+math.max(dragon.laser.level,1)--prevent div by 0
		dragon.ammo=dragon.ammo-0.05
		dragon.laser.anim=dragon.laser.anim+0.5
		if dragon.laser.anim>4 then dragon.laser.anim=0 end
		DrawSprite(dragon.laser.chargeSprites[math.ceil(dragon.laser.anim)],Transform(barrelPos,QuatEuler(0,90,0)),dragon.laser.charge/50,dragon.laser.charge/50,1,1,1,1,true,true)
		DrawSprite(dragon.laser.chargeSprites[math.ceil(dragon.laser.anim)],Transform(barrelPos,QuatEuler(90,0,0)),dragon.laser.charge/50,dragon.laser.charge/50,1,1,1,1,true,true)
		DrawSprite(dragon.laser.chargeSprites[math.ceil(dragon.laser.anim)],Transform(barrelPos,Quat()),dragon.laser.charge/50,dragon.laser.charge/50,1,1,1,1,true,true)
		if dragon.laser.charge>fireCharge then
			Spawn("MOD/prefab/laserBeam.xml",Transform(barrelPos,dragon.aimQuat),true)
			dragon.laser.charge=0
			local onlyLaserKills=FindBodies("onlyLaser",true)
			for l=1,#onlyLaserKills do
				local dist=VecLength(VecSub(dragon.cameraTarget,GetBodyTransform(onlyLaserKills[l]).pos))
				if dist<5 then
					SetTag(onlyLaserKills[l],"HP",0)
				end
			end
		end
	
end

--grenadeLauncher
function grenadeLauncher()
	local barrelPos=TransformToParentPoint(GetShapeWorldTransform(dragon.launcher.shape),Vec(0,-1,1))
	if dragon.launcher.cooldown<=0 then
		PlaySound(dragon.sound.grenadePop)
		dragon.ammo=dragon.ammo-1
		
		Spawn("MOD/prefab/grenade.xml",Transform(barrelPos,Quat()))
		local grenadeBody=FindBody("grenadeBody",true)
		--DebugPrint(grenadeBody)
		local g=9.8--gravity
		local t=3--time
		local vup=0
		local vfwd=0
		local danger=true
		while danger or t>10 do
			vup = (dragon.cameraTarget[2]-barrelPos[2]+0.5*g*math.pow(t,2))/t
			vfwd= VecLength(VecSub(Vec(dragon.cameraTarget[1],0,dragon.cameraTarget[3]),Vec(barrelPos[1],0,barrelPos[3])))/t
			t=t+1
			if vup/vfwd>1 then
				danger=false
			end
		end
		local dir=QuatRotateVec(dragon.aimQuat,Vec(0,0,-1))
		local hdir=VecNormalize(Vec(dir[1],0,dir[3]))
		local vel=Vec(hdir[1]*vfwd,vup,hdir[3]*vfwd)
		SetBodyVelocity(grenadeBody,vel)
		SetBodyAngularVelocity(grenadeBody,Vec(math.random(-10,10),math.random(-10,10),math.random(-10,10)))
		RemoveTag(grenadeBody,"grenadeBody")--remove tag so we dont push grenade again
		ParticleReset()
		ParticleType("smoke")
		ParticleTile(5)
		for s=0,5 do
			SpawnParticle(VecAdd(barrelPos,Vec(math.random(),math.random(),math.random())), VecScale(VecNormalize(vel),30), 1)
		end
		dragon.launcher.cooldown=30/math.max(dragon.launcher.level,1)--prevent div by 0

	end
end
--fire
function fireBreath()
	local trans = GetBodyTransform(dragon.visualHead)
	local pos=trans.pos
	local dir=QuatRotateVec(trans.rot,Vec(0,0,-1))
	local vel=VecScale(dir,100)
	firePlume(pos,vel,1)
	--spawn fire
	local startPos=VecAdd(pos,VecScale(dir,3))
	local hit, dist = QueryRaycast(startPos,dir,10*(dragon.fire.level+1))
--	DebugPrint(hit)
	if hit==true then
		local py=QuatRotateVec(trans.rot,Vec(0,1,0))
		local px=QuatRotateVec(trans.rot,Vec(1,0,0))
		for a=-0.15,0.15,0.05 do
			for b=-0.15,0.15,0.05 do
				for c=0,3 do
					local relDir=VecAdd(VecAdd(VecScale(px,a),VecScale(py,b)),dir)
					local firePos=VecAdd(pos,VecScale(relDir,dist+c))
					SpawnFire(firePos)
					--DebugCross(firePos)
				end
			end
		end
	end
	PlayLoop(dragon.sound.fireLoop,robot.bodyCenter,100)
end
--booster
function boost()
	if dragon.booster.enabled then
		
		dragon.vSpeed=40
		robot.speed=10000000*dragon.booster.level
		robot.desiredSpeed=10000000*(dragon.booster.level+1)
		--ApplyBodyImpulse(robot.body,robot.bodyCenter,VecScale(robot.axes[3],-10000))
		local velocity=GetBodyVelocity(robot.body)
		boosterEffects()
		PlayLoop(dragon.sound.boosterLoop,robot.bodyCenter,10)
		local impact=math.min(math.pow(VecLength(velocity)*10,2),1000)
		MakeHole(robot.bodyCenter,impact,impact,impact)
		dragon.height=dragon.height+QuatRotateVec(dragon.aimQuat,Vec(0,0,-dragon.vSpeed))[2]
		if dragon.flightMode then
			local x,y,z=GetQuatEuler(dragon.aimQuat)/90
			dragon.sitOffset=x
		else
			dragon.sitOffset=0
		end
		--DebugPrint(VecLength(velocity))
	end
end
function boosterEffects()
	local boosterTransform=GetShapeWorldTransform(dragon.booster.shape)
	local thrusterLpos=TransformToParentPoint(boosterTransform,Vec(0.3,6,0.4))
	local thrusterRpos=TransformToParentPoint(boosterTransform,Vec(1.8,6,0.4))
	--smokeTrail(thrusterLpos,10)
	--smokeTrail(thrusterRpos,10)
	---fireTrail(thrusterLpos,10)
	--fireTrail(thrusterRpos,10)
	local flameDistort=math.sin(GetTime()*100)*(dragon.booster.level+1)
	DrawSprite(dragon.booster.flameSprite,Transform(thrusterLpos,boosterTransform.rot),1,10+flameDistort,1,1,1,1,true)
	DrawSprite(dragon.booster.flameSprite,Transform(thrusterLpos,QuatRotateQuat(boosterTransform.rot,QuatAxisAngle(Vec(0,1,0),90))),1,10+flameDistort,1,1,1,1,true)
	DrawSprite(dragon.booster.flameSprite,Transform(thrusterRpos,boosterTransform.rot),1,10+flameDistort,1,1,1,1,true)
	DrawSprite(dragon.booster.flameSprite,Transform(thrusterRpos,QuatRotateQuat(boosterTransform.rot,QuatAxisAngle(Vec(0,1,0),90))),1,10+flameDistort,1,1,1,1,true)
end
-- EFFECTS
function smokeTrail(pos,lifeTime)
	ParticleReset()
	ParticleType("smoke")
	ParticleTile(5)
	SpawnParticle(pos, Vec(), lifeTime)
end
function fireTrail(pos,lifeTime)
	ParticleReset()
	ParticleType("smoke")
	ParticleTile(5)
	ParticleColor(1,0.5,0)
	ParticleEmissive(1, 0)
	ParticleCollide(0)
	SpawnParticle(pos, Vec(), lifeTime)
end
function firePlume(pos,vel,lifeTime)
	ParticleReset()
	ParticleType("plain")
	ParticleTile(5)
	ParticleGravity(-0.1)
	ParticleCollide(0)
	ParticleColor(1,0.5,0)
	ParticleEmissive(1, 0)
	ParticleRadius(0.1,10)
	SpawnParticle(pos, vel, lifeTime)
end
function lerp(a,b,t)
	return a+(b-a)*t
end
function increaseSaveDataInt(address,amount)
	local a=GetInt(address)
	local b=a+amount
	SetInt(address,b)
end

--custom "vehicle" functions

function checkIfRiding()
	if GetPlayerInteractShape()==dragon.doors and InputPressed("interact") then
		SetTag(dragon.brain,"currentCommand","ride")
		
	end
end

function ridingCameraUpdate()
	SetPostProcessingProperty("colorbalance", 1, 1-dragon.invince/50, 1-dragon.invince/50)--turn red when hit
	robot.bodyCenter = TransformToParentPoint(robot.transform, GetBodyCenterOfMass(robot.body))
	SetPlayerHealth(1)
	local trans = GetBodyTransform(robot.body)
	--DebugPrint(dragon.speedZoom)
	dragon.camera.pos=VecAdd(TransformToParentPoint(trans,Vec(0,1.1,-3.4+speedZoom)),QuatRotateVec(dragon.camera.rot,Vec(-dragon.camera.zoom/5,dragon.camera.zoom/5,dragon.camera.zoom)))
	local xin=InputValue("camerax")
	local yin=InputValue("cameray")
	local zin=InputValue("mousewheel")
	dragon.camera.x=dragon.camera.x-xin*24
	dragon.camera.y=dragon.camera.y-yin*24
	dragon.camera.zoom=math.max(0,dragon.camera.zoom-zin)
	dragon.camera.rot=QuatEuler(dragon.camera.y,dragon.camera.x,0)
	local camTrans=Transform(VecAdd(dragon.camera.pos,VecScale(GetBodyVelocity(robot.body),GetTimeStep())),dragon.camera.rot)
	SetCameraTransform(camTrans)
	SetPlayerTransform(camTrans)
	SetPlayerVelocity(Vec())
	SetPlayerGroundVelocity(Vec())
	SetString("game.player.tool", 'sledge')
	if dragon.booster.enabled and InputDown("shift") and dragon.ammo>0 then
		SetValue("speedFov",110,"easeout",10)
		if dragon.camera.zoom>0 then
			SetValue("speedZoom",0.1*dragon.camera.zoom,"easeout",10)
		else
			SetValue("speedZoom",0.1,"easeout",10)
		end
	end
	SetCameraFov(speedFov)
end
-- damage functions

function dealDamage(handle, damage)
	if not HasTag(handle, "dragonBrain") and HasTag(handle, "HP") then
		local getHP=tonumber(GetTagValue(handle, "HP"))
		local newHP=getHP-damage
		SetTag(handle,"HP",newHP)
	end
end
function teleport(newPos)
	local diff=VecSub(newPos,robot.bodyCenter)
	for b=1,#robot.allBodies do
		local currentRot=GetBodyTransform(robot.allBodies[b]).rot
		local currentPos=GetBodyTransform(robot.allBodies[b]).pos
		SetBodyTransform(robot.allBodies[b],Transform(VecAdd(currentPos,diff),currentRot))
		robot.initialBodyTransforms[b] = GetBodyTransform(robot.allBodies[b])
	end

end

--helper functions
function truncate(value,place)
	return math.floor((value * (1/place)) + 0.5) / (1/place)
end

--This function retrieves the most recent path and stores it in lastPath
function retrievePath()
	lastPath = {}
	local length=GetPathLength()
	local l=0
	while l < length do
		lastPath[#lastPath+1] = GetPathPoint(l)
		l = l + 0.2
	end
end


--This function will draw the content of lastPath as a line
function drawPath()
	for i=1, #lastPath-1 do
		DrawLine(lastPath[i], lastPath[i+1])
	end
end