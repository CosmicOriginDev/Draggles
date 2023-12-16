--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function init()
--Register tool and enable it
	RegisterTool("dragonTablet", "Dragon Tablet", "MOD/vox/dragonTabletProxy.vox")
	SetBool("game.tool.dragonTablet.enabled", true)
	
	Spawn("MOD/prefab/TabletPrefab.xml",Transform(Vec(0,0,0)))
	
	
end

function tick(dt)

	
	if GetString("game.player.tool") == "dragonTablet" then
		local toolBody = GetToolBody()
		local s = GetBodyShapes(toolBody)
		for i=1, #s do
			SetTag(s[i], "invisible")
		end
	
	end
	
end


function update(dt)
end


function draw(dt)
end


