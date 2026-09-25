
local warmingwarmemorial = Building:New{
	corpse					= "",
	maxDamage        	= 3500,
	mass           		= 500,
	buildCostEnergy    	= 5,
	buildCostMetal    	= 5,
	explodeAs				= "none",
	name = "Warming Wars memorial 2016-2035",
	description = "Never again! In memoria of the billions who died in the warming wars. Lest we forget! Yuritch",

	Builder					= true,
	levelground				= true,
	FootprintX = 8,
	FootprintZ = 8,
	script 				= "warmingwarmemorialscript.lua",
	objectName       	= "WarmingWarMemorial.dae",

	
	
		
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
	["warmingwarmemorial"] = warmingwarmemorial:New()
	
})
