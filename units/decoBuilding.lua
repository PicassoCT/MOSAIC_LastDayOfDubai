
local decoBuilding = Building:New{
	corpse					= "",
	maxDamage        	= 3500,
	mass           		= 500,
	buildCostEnergy    	= 5,
	buildCostMetal    	= 5,
	explodeAs				= "none",
	name = "House",
	description = "houses civilians",

	Builder					= true,
	levelground				= true,
	FootprintX = 8,
	FootprintZ = 8,
	script 				= "decoBuildingscript.lua",
	objectName       	= "decobuilding.dae",
		
	YardMap =  [[yooooooy
				oooooooo
				oooooooo
				oooooooo
				oooooooo
				oooooooo
				oooooooo
				yooooooy]]	,  
	

	customparams = {	
		normaltex = "unittextures/house_asian_normal.dds",
		helptext			= "Civilian Building",
		baseclass			= "Building", -- TODO: hacks
    },
	
	buildoptions = 
	{
	"civilian_arab0"
	},
	usepiececollisionvolumes = false,
	collisionVolumeType = "box",
	collisionvolumescales = "130 120 130",
	category = [[NOTARGET]],

}

return lowerkeys({
	--Temp
	["decobuilding"] = decoBuilding:New()
	
})
