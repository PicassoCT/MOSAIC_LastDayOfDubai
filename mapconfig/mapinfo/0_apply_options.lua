

if Spring.GetMapOptions then
  local mapOptions = Spring.GetMapOptions() or {}
  local skies = {
    ['clear-day'] = 'skyboxes/clear-day.dds',
    ['overcast-day'] = 'skyboxes/overcast-day.dds',
    ['sunset-sandstorm'] = 'skyboxes/sunset-sandstorm.dds',
    ['rainy-night'] = 'skyboxes/rainy-night.dds',
    original = 'cleardesert.dds',
  }
  mapinfo.atmosphere.skybox = skies[mapOptions.dhubai_sky] or skies['clear-day']
  if mapOptions.dhubai_splats == 'original' then
    mapinfo.splats.texmults = {0.95, 0.35, 0.86, 0.5}
  elseif mapOptions.dhubai_splats == 'off' then
    mapinfo.splats.texmults = {0, 0, 0, 0}
  end
  --Spring.Echo("Spring.GetMapOptions Selected mapOptions: Waterdamage:",mapOptions.waterdamage,"Dry:",mapOptions.dry)
  if mapOptions.waterdamage == "1" or mapOptions.waterdamage == true  then
	mapinfo.water.damage = 50
	mapinfo.water.absorb    = { 0.01, 0.08, 0.01 }
	mapinfo.water.basecolor = { 0.8, 0.4, 0.8 } --or 0.4 0.0 0.4
	mapinfo.water.mincolor  = { 0.2, 0.0, 0.2 }--or 0.4 0.0 0.4
	mapinfo.water.surfacecolor  = { 1.0, 0.65, 1.0 }
  else
    mapinfo.water.damage = 0
  end
  if mapOptions.roads == "0" then
    --set all typemaps modifiers to 1
    for terrainIndex in pairs(mapinfo.terraintypes) do
      for unitType in pairs(mapinfo.terraintypes[terrainIndex].movespeeds) do
        mapinfo.terraintypes[terrainIndex].movespeeds[unitType] = 1
      end
    end
  end
  --we intentionally put default out of bounds so that existance check will fail and map won't be altered
	if mapOptions.dry then
	  local waterLevel = tonumber(mapOptions.dry or "0") 
	  if waterLevel ==1 then
		mapinfo.smf.minheight = 200
		mapinfo.smf.maxheight = 1200
	  end
	end
end
