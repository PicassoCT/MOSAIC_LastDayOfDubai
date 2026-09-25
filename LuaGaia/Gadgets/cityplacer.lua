function gadget:GetInfo()
	return {
		name      = "Objective spawner placer",
		desc      = "Spawns Features and Units",
		author    = "Gnome, Smoth",
		date      = "August 2008",
		license   = "PD",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

Spring.Echo("Cityplacer loaded")

if (Spring.GetGameFrame() >= 1) then
  return false
end

local SetUnitNeutral        = Spring.SetUnitNeutral
local SetUnitBlocking       = Spring.SetUnitBlocking
local SetUnitRotation       = Spring.SetUnitRotation
local SetUnitAlwaysVisible  = Spring.SetUnitAlwaysVisible
local CreateUnit            = Spring.CreateUnit
local CreateFeature         = Spring.CreateFeature

local objectivecfg
local featureslist
local buildinglist
local unitlist


if VFS.FileExists("mapconfig/cityplacer/config.lua") then
	objectivecfg = VFS.Include("mapconfig/cityplacer/config.lua")
	
	featureslist = objectivecfg.objectlist
	buildinglist = objectivecfg.buildinglist
	unitlist     = objectivecfg.unitlist
else
	Spring.Echo("missing file")
	Spring.Echo("No features loaded")
end

function gadget:GameStart()
	Spring.PlaySoundFile("sounds/intro.ogg", 0.1)
end

function gadget:Initialize()
	local gaiaID = Spring.GetGaiaTeamID()
	GG.storedSpawnedHouses= {}
	if ( objectivecfg ) then
			Spring.Echo("Cityplacer Gadget started")


		if ( featureslist ) then
			for i,fDef in pairs(featureslist) do
				local flagID = CreateFeature(fDef.name, fDef.x, Spring.GetGroundHeight(fDef.x,fDef.z)+5, fDef.z, math.rad(fDef.rot or 0))
				Spring.SetFeatureBlocking(flagID, false, false, false, true, false, false, false)
			end
		end

		if ( unitlist ) then
			local los_status = {los=true, prevLos=true, contRadar=true, radar=true}
			for i,uDef in pairs(unitlist) do
				local flagID = CreateUnit(uDef.name, uDef.x, 0, uDef.z, 0, gaiaID)
				SetUnitRotation(flagID, 0, math.rad(uDef.rot or 0) , 0)
				SetUnitNeutral(flagID,true)
				SetUnitAlwaysVisible(flagID,true)
			end
		end

		if ( buildinglist ) then
			local los_status = {los=true, prevLos=true, contRadar=true, radar=true}
			for i,bDef in pairs(buildinglist) do
				local flagID = CreateUnit(bDef.name, bDef.x, 0, bDef.z, math.rad(bDef.rot or 0), gaiaID)
				if bDef.name == "house_western0" or bDef.name == "house_arab0" then
				 	GG.storedSpawnedHouses[flagID] = {x=bDef.x, y=0, z = bDef.z}
				end
				SetUnitNeutral(flagID,true)
				SetUnitAlwaysVisible(flagID,true)
			end
		end
	end
	
	Spring.Echo("Cityplacer Gadget completed")
	Spring.CreateUnit(UnitDefNames["map_placements_complete"].id, 1,1,1, 1, gaiaID)
	GG.MapDefinedHouseType = {3,4}
	return false --unload
end
	