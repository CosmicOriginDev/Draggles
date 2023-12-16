function draw()
	if UiGetScreen() ~= 0 then
		UiColor(0,0,0)
		UiRect(UiWidth(), UiHeight())
		if not HasTag(UiGetScreen(),"dead") then
			--normal screen
			UiAlign("top left")
			UiFont("MOD/font/mechfont.ttf", 50)
			local commandText=string.upper(GetTagValue(UiGetScreen(),"command"))
			local ammoText=GetTagValue(UiGetScreen(),"ammo")
			local HPText=GetTagValue(UiGetScreen(),"HP")
			local statusText=string.upper(GetTagValue(UiGetScreen(),"status"))
			UiColor(0.33,1,0.33)
			UiText(commandText,true)
			UiColor(1,1,0.33)
			UiText("f:"..ammoText,true)
			UiColor(1,0.33,0.33)
			UiText("h:"..HPText,true)
			UiColor(1,1,1)
			UiText("STATUS:"..statusText)
			local emoteY=0
			local expression=GetTagValue(UiGetScreen(),"emote")
			if expression=="neutral" then
				emoteY=0
			elseif expression=="blink" then
				emoteY=27
			elseif expression=="guarding" then
				emoteY=54
			elseif expression=="angry" then
				emoteY=81
			elseif expression=="happy" then
				emoteY=108
			elseif expression=="love" then
				emoteY=135
			elseif expression=="thinking" then
				emoteY=162
			elseif expression=="dead" then
				emoteY=170
			else
				emoteY=0
			end
			UiTranslate(500,90)
			
			
			UiScale(10)
			UiImage("MOD/images/dragonUIemotes.png",0,emoteY,27,emoteY+27)
			UiText()
		else
			--draggles is dead
			local TimeText=GetTagValue(UiGetScreen(),"reviveTime")
			UiAlign("top left")
			UiColor(1,1,1)
			UiFont("MOD/font/mechfont.ttf", 50)
			UiText()
			UiText("MECH FAILURE!\nNEW MECH IN:"..TimeText.."S")
			UiText()
		end
	end
end