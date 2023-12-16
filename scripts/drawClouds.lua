function init()
	clouds=LoadSprite("MOD/images/cloudTexture.png")
	size=256
	
end
function tick()
	for a=-8,8 do
		for b=-8,8 do
			DrawSprite(clouds,Transform(Vec(a*size,150,b*size),QuatEuler(90,0,0)),size,size,1,1,1,0.5,true)
		end
	end
end