function draw()

	if UiGetScreen() ~=0 then

		if HasTag(UiGetScreen(),"activate") then
			UiAlign("left top")
			if UiBlankButton(UiWidth(),UiHeight()) then
				SetTag(UiGetScreen(),"cancel")
			end
			
			UiImage("MOD/images/upgradeBG.png",0,0,UiWidth(),UiHeight())
			UiTranslate(160,120)
			--draw equipped weapons
			
			local y={
				tonumber(GetTagValue(UiGetScreen(),"y1")),
				tonumber(GetTagValue(UiGetScreen(),"y2")),
				tonumber(GetTagValue(UiGetScreen(),"y3")),
				tonumber(GetTagValue(UiGetScreen(),"y4"))
			}
			UiAlign("left middle")
			UiColor(1,1,1)
			UiTranslate(108,-8)
			UiColor(1,1,1)
			UiTranslate(0,-4)
			
			UiImage("MOD/images/dragon-weapons.png",0,y[1],16,y[1]+16)
			if UiBlankButton(16,16) then
				SetTag(UiGetScreen(),"selectedWeapon",1)
				UiRect(16,16)
			end
			UiTranslate(0,21)
			UiTranslate(21,0)
			
			UiImage("MOD/images/dragon-weapons.png",0,y[2],16,y[2]+16)
			if UiBlankButton(16,16) then
				SetTag(UiGetScreen(),"selectedWeapon",2)
				UiRect(16,16)
			end
			UiTranslate(-21,0)
			UiTranslate(0,21)
			
			UiImage("MOD/images/dragon-weapons.png",0,y[3],16,y[3]+16)
			if UiBlankButton(16,16) then
				SetTag(UiGetScreen(),"selectedWeapon",3)
				UiRect(16,16)
			end
			UiTranslate(0,-21)
			UiTranslate(-21,0)
			
			UiImage("MOD/images/dragon-weapons.png",0,y[4],16,y[4]+16)
			if UiBlankButton(16,16) then
				SetTag(UiGetScreen(),"selectedWeapon",4)
				UiRect(16,16)
			end
			
			--draw stored weapons
			UiTranslate(-72,-22)
			local storage=GetTagValue(UiGetScreen(),"storage")
			local w=16
			local i=1
			for c=1,2 do
				for r=1,4 do
					if string.sub(storage,i,i)=="1" then
						UiImage("MOD/images/dragon-weapons.png",0,w,16,w+16)
						if UiBlankButton(16,16) then 
							SetTag(UiGetScreen(),"selectedStorage",i)
							UiRect(16,16)
						end
					end
				
					UiTranslate(0,22)
					w=w+16
					i=i+1
				end
				UiTranslate(0,-22*4)
				UiTranslate(22,0)
			end
			--draw descriptions
			UiAlign("left top")
			UiTranslate(-200,-72)
			UiFont("MOD/font/mechfontsmall.ttf",1)
			UiWordWrap(125)
			local level=(GetTagValue(UiGetScreen(),"level"))
			UiText("LVL:"..level.."\n\n"..GetTagValue(UiGetScreen(),"weaponText"))
			--upgrade button
			UiTranslate(151,158)
			
			if UiBlankButton(140,37) then
				UiRect(140,37)
				SetTag(UiGetScreen(),"done")
				
			end
		--drqw equipment
			UiTranslate(3,-153)
			local equipment=GetTagValue(UiGetScreen(),"equipment")
			local w=16
			local i=1
		
			for r=1,3 do
				if string.sub(equipment,i,i)=="1" then
					UiImage("MOD/images/dragon-equipment.png",0,w,16,w+16)
					if UiBlankButton(16,16) then 
						SetTag(UiGetScreen(),"selectedEquipment",i)
						UiRect(16,16)
					end
				end
			
				UiTranslate(22,0)
				w=w+16
				i=i+1
			end
			
			
		else
			UiAlign("left top")
			UiImage("MOD/images/noDragglesInDock.png",0,0,UiWidth(),UiHeight())
		end
		
		--cursor
		if HasTag(UiGetScreen(),"selectedStorage") then
			local x,y=UiGetMousePos()
			local ss=tonumber(GetTagValue(UiGetScreen(),"selectedStorage"))
			UiTranslate(x,y)
			UiImage("MOD/images/dragon-weapons.png",0,ss*16,16,(ss*16)+16)
		end

		
	end
end

