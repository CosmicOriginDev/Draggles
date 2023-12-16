function draw()
	if UiGetScreen() ~= 0 then
		UiColor(0,0,0)
		UiRect(UiWidth(), UiHeight())

		local y={
			tonumber(GetTagValue(UiGetScreen(),"y1")),
			tonumber(GetTagValue(UiGetScreen(),"y2")),
			tonumber(GetTagValue(UiGetScreen(),"y3")),
			tonumber(GetTagValue(UiGetScreen(),"y4"))
		}
		local selected=tonumber(GetTagValue(UiGetScreen(),"sel"))
		UiAlign("center middle")
		UiColor(1,1,1)
		UiTranslate(64,64)
		UiScale(2,2)
		UiColor(1,1,1)
		UiTranslate(0,-16)
		if selected==1 then
			UiImage("MOD/images/weaponScreenCursor.png",0,0,20,20)
		end
		UiImage("MOD/images/dragon-weapons.png",0,y[1],16,y[1]+16)
		UiTranslate(0,16)
		UiTranslate(16,0)
		if selected==2 then
			UiImage("MOD/images/weaponScreenCursor.png",0,0,20,20)
		end
		UiImage("MOD/images/dragon-weapons.png",0,y[2],16,y[2]+16)
		UiTranslate(-16,0)
		UiTranslate(0,16)
		if selected==3 then
			UiImage("MOD/images/weaponScreenCursor.png",0,0,20,20)
		end
		UiImage("MOD/images/dragon-weapons.png",0,y[3],16,y[3]+16)
		UiTranslate(0,-16)
		UiTranslate(-16,0)
		if selected==4 then
			UiImage("MOD/images/weaponScreenCursor.png",0,0,20,20)
		end
		UiImage("MOD/images/dragon-weapons.png",0,y[4],16,y[4]+16)
	end
end