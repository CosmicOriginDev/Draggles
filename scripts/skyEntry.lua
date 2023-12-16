function init()
	entryTrigger=FindTrigger("entryTrigger")
	dragonBody=FindBody("dragonBody",true)
	gSandbox = 
	{		
		{ id="lee_sandbox", level="lee", name="Lee Chemicals", image="menu/level/lee.png", file="lee.xml", layers="sandbox"},
		{ id="marina_sandbox", level="marina", name="Marina", image="menu/level/marina.png", file="marina.xml", layers="sandbox"},
		{ id="mansion_sandbox", level="mansion", name="Villa Gordon", image="menu/level/mansion.png", file="mansion.xml", layers="sandbox"},
		{ id="caveisland_sandbox", level="caveisland", name="Hollowrock", image="menu/level/caveisland.png", file="caveisland.xml", layers="sandbox"},
		{ id="mall_sandbox", level="mall", name="Evertides", image="menu/level/mall.png", file="mall.xml", layers="sandbox"},
		{ id="frustrum_sandbox", level="frustrum", name="Frustrum", image="menu/level/frustrum.png", file="frustrum.xml", layers="sandbox"},
		{ id="hub_carib_sandbox", level="hub_carib", name="Muratori Beach", image="menu/level/hub_carib.png", file="hub_carib.xml", layers="sandbox"},
		{ id="carib_sandbox", level="carib", name="Isla Estocastica", image="menu/level/carib.png", file="carib.xml", layers="sandbox"},
		{ id="factory_sandbox", level="factory", name="Quilez Security", image="menu/level/factory.png", file="factory.xml", layers="sandbox"},
		{ id="cullington_sandbox", level="cullington", name="Cullington", image="menu/level/cullington.png", file="cullington.xml", layers="sandbox"},
	}
	selectedLevel=GetIntParam("map",1)
	border=GetBoolParam("border",false)
end
function tick()
	if border then
		if not IsBodyInTrigger(entryTrigger,dragonBody) then
			StopMusic()
			StartLevel("sky", "MOD/sky.xml","",true)
		end
	else
		if IsBodyInTrigger(entryTrigger,dragonBody) then
		
			StopMusic()
			local i=selectedLevel
			if i==0 then 
				 StartLevel("lab", "MOD/lab.xml","",true)
			else
				StartLevel(gSandbox[i].id, gSandbox[i].file, gSandbox[i].layers, true)
			end
		end
		
	end
end