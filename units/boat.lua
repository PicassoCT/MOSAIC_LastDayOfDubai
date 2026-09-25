
local boat = Building:New{
	corpse					= "",
	maxDamage        	= 3500,
	mass           		= 500,
	buildCostEnergy    	= 5,
	buildCostMetal    	= 5,
	explodeAs				= "none",
	name = "Boat",
	description = "houses civilians",

	Builder					= true,
	levelground				= true,
	FootprintX = 8,
	FootprintZ = 8,
	script 				= "boatscript.lua",
	objectName       	= "boat.dae",

	
	
		

	customparams = {	
		normaltex = "unittextures/house_europe_normal.dds",
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
	floater = true,
	waterline = 0.0,

}

return lowerkeys({
	--Temp
	["decoboat"] = boat:New()
	
})
