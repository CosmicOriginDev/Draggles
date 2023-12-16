function draw()
	if UiGetScreen() ~= 0 then
		UiImage("MOD/images/dragon-eyes.png",0,tonumber(GetTagValue(UiGetScreen(),"eyeY")),16,tonumber(GetTagValue(UiGetScreen(),"eyeY"))+8)
	end
end