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

-- LuaGaia has its own state. Read the game's pure policy directly, before any
-- unit scripts, attachments or reconstruction callbacks can run for a plot.
-- Older game versions retain the authored city when the policy is unavailable.
local ruinPolicy
local function loadRuinPolicy()
	if not VFS.FileExists("scripts/lib_mosaic.lua")
		or not VFS.FileExists("scripts/lib_city_ruins.lua") then return end
	local shared = VFS.Include("scripts/lib_mosaic.lua",
		setmetatable({MOSAIC_CONFIG_ONLY = true}, {__index = _G}))
	if type(shared) ~= "table"
		or type(shared.getCityGeography) ~= "function"
		or type(shared.getCityRuinConfig) ~= "function"
		or type(shared.getCityRuinCandidateTypeTable) ~= "function"
		or type(shared.getCityRuinTypeTable) ~= "function" then return end
	local policy = VFS.Include("scripts/lib_city_ruins.lua")
	if type(policy) ~= "table" or type(policy.ShouldRuin) ~= "function" then return end
	local ruins = shared.getCityRuinTypeTable(UnitDefs)
	local ruinDefID
	for defID in pairs(ruins) do
		if not ruinDefID or defID < ruinDefID then ruinDefID = defID end
	end
	if not ruinDefID then return end
	ruinPolicy = {
		location = shared.getCityGeography(Game),
		config = shared.getCityRuinConfig(),
		candidates = shared.getCityRuinCandidateTypeTable(UnitDefs),
		ruins = ruins,
		ruinName = UnitDefs[ruinDefID].name,
		shouldRuin = policy.ShouldRuin,
		occupiedPlots = {},
		protectedCounts = {},
	}
end

local function createAuthoredUnit(authored, facing, teamID)
	local name = authored.name
	local sourceDef = UnitDefNames[name]
	local sourceDefID = sourceDef and sourceDef.id
	local isHouse = ruinPolicy and sourceDefID
		and (ruinPolicy.candidates[sourceDefID] or ruinPolicy.ruins[sourceDefID])
	local reserved
	if isHouse then
		local row = ruinPolicy.occupiedPlots[authored.x]
		-- Only civilian houses own exclusive plots; other authored units may
		-- intentionally share a location (decoration, objectives, and effects).
		if row and row[authored.z] then return end
		local minimums = ruinPolicy.config.protectedMinimums or {}
		local minimum = minimums[name] or 0
		reserved = (ruinPolicy.protectedCounts[name] or 0) < minimum
		if not reserved and ruinPolicy.candidates[sourceDefID]
			and ruinPolicy.shouldRuin(ruinPolicy.location.hash, authored.x,
				authored.z, ruinPolicy.location.latitude, ruinPolicy.config) then
			name = ruinPolicy.ruinName
		end
	end
	local id = CreateUnit(name, authored.x, 0, authored.z, facing, teamID)
	if id and isHouse then
		local row = ruinPolicy.occupiedPlots[authored.x] or {}
		ruinPolicy.occupiedPlots[authored.x] = row
		row[authored.z] = id
		if reserved then
			ruinPolicy.protectedCounts[authored.name] =
				(ruinPolicy.protectedCounts[authored.name] or 0) + 1
		end
	end
	return id
end


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
	loadRuinPolicy()
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
			for i,uDef in ipairs(unitlist) do
				local flagID = createAuthoredUnit(uDef, 0, gaiaID)
				if flagID then
					SetUnitRotation(flagID, 0, math.rad(uDef.rot or 0) , 0)
					SetUnitNeutral(flagID,true)
					SetUnitAlwaysVisible(flagID,true)
				end
			end
		end

		if ( buildinglist ) then
			local los_status = {los=true, prevLos=true, contRadar=true, radar=true}
			for i,bDef in ipairs(buildinglist) do
				local flagID = createAuthoredUnit(bDef, math.rad(bDef.rot or 0), gaiaID)
				if flagID then
					if bDef.name == "house_western0" or bDef.name == "house_arab0" then
						GG.storedSpawnedHouses[flagID] = {x=bDef.x, y=0, z = bDef.z}
					end
					SetUnitNeutral(flagID,true)
					SetUnitAlwaysVisible(flagID,true)
				end
			end
		end
	end
	
	Spring.Echo("Cityplacer Gadget completed")
	Spring.CreateUnit(UnitDefNames["map_placements_complete"].id, 1,1,1, 1, gaiaID)
	GG.MapDefinedHouseType = {3,4}
	return false --unload
end
