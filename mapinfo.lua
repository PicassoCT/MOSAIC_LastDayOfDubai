--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
		
local mapinfo = {
	name        = "MOSAIC_LastDayOfDubai_V3",
	shortname   = "Dubai",
	description = "a 2 vs 2 Map",
	author      = "PicassoCt",
	version     = "1",
	--mutator   = "deployment";
	--mapfile   = "", --// location of smf/sm3 file (optional)
	modtype     = 3, --// 1=primary, 0=hidden, 3=map
	depend      = {"Map Helper v1"},
	replace     = {},

	--startpic   = "", --// deprecated
	--StartMusic = "", --// deprecated

	maphardness     = 400,
	notDeformable   = false,
	gravity         = 100,
	tidalStrength   = 15,
	maxMetal        = 0.615,
	extractorRadius = 100.0,
	voidWater       = false,
	autoShowMetal   = true,


	smf = {
		minheight = -100.0,
		maxheight = 100,
		smtFileName0 = "MOSAIC_LastDayOfDubai_V1.smt",
		--smtFileName1 = "",
		--smtFileName.. = "",
		--smtFileNameN = "",
	},

	sound = {
		--// Sets the _reverb_ preset (= echo parameters),
		--// passfilter (the direct sound) is unchanged.
		--//
		--// To get a list of all possible presets check:
		--//   https://github.com/spring/spring/blob/master/rts/System/Sound/OpenAL/EFXPresets.cpp
		--//
		--// Hint:
		--// You can change the preset at runtime via:
		--//   /tset UseEFX [1|0]
		--//   /tset snd_eaxpreset preset_name   (may change to a real cmd in the future)
		--//   /tset snd_filter %gainlf %gainhf  (may    "   "  "  "    "  "   "    "   )
		preset = "default",

		passfilter = {
			--// Note, you likely want to set these
			--// tags due to the fact that they are
			--// _not_ set by `preset`!
			--// So if you want to create a muffled
			--// sound you need to use them.
			gainlf = 1.0,
			gainhf = 1.0,
		},

		reverb = {
			--// Normally you just want use the `preset` tag
			--// but you can use handtweak a preset if wanted
			--// with the following tags.
			--// To know their function & ranges check the
			--// official OpenAL1.1 SDK document.
			
			--density
			--diffusion
			--gain
			--gainhf
			--gainlf
			--decaytime
			--decayhflimit
			--decayhfratio
			--decaylfratio
			--reflectionsgain
			--reflectionsdelay
			--reflectionspan
			--latereverbgain
			--latereverbdelay
			--latereverbpan
			--echotime
			--echodepth
			--modtime
			--moddepth
			--airabsorptiongainhf
			--hfreference
			--lfreference
			--roomrollofffactor
		},
	},

	resources = {
		--grassBladeTex = "grass_blade_tex.tga", --blade texture
		--grassShadingTex = "grass_shading_tex.tga", --defaults to minimap
		detailTex = "detailtexblurred.bmp",
		-- specularTex = "dubai_specular.png",
		-- Explicit neutral diffuse detail; the old placeholder did not exist.
		splatDetailTex = "splat_detail_neutral.png",
		splatDistrTex = "LastDayOfDubai_distribution.dds", --Rock, sand, tar, grass, rock
		--detailNormalTex = "detail_normal.dds", --holy crap we can do 8K?
		--skyReflectModTex = "dubai_specular.png",
		splatDetailNormalDiffuseAlpha = false,
		----splatDetailNormalTex1 = "Ground_MossSolid_1k_dnts.tga";
		--the order is cliffs, pebbles, grass, metalspots

		splatDetailNormalTex1 = "Normal_Detail_Rocky.png", -- broad stone, no dune ridges
		splatDetailNormalTex2 = "Normal_Detail_Rocky.png", --r	
		splatDetailNormalTex3 = "Normal_Detail_Tar.png", --b
		splatDetailNormalTex4 = "Normal_Detail_Grass.png", -- a
		lightEmissionTex = "LightEmission.tga",

	},

	splats = {
		texScales = {0.0125, 0.025, 0.006125, 0.625},
		texMults  = {0.12, 0.12, 0.17, 0.20}, -- broad stone, rock, tar, grass
	},

	atmosphere = {
		minWind      = 1,
		maxWind      = 19,

		fogStart     = 0.8,
		fogEnd       = 1.0,

		cloudColor = {
		  0.89999998,
		  0.89999998,
		  0.89999998,
		},
		fogColor = {
		  0.80000001,
		  0.80000001,
		  0.5,
		},
		skyColor = {
		  0.42879999,
		  0.58016002,
		  0.63999999,
		},
		sunColor = {
		  1,
		  0.92,
		  0.78,
    },
		-- Recoil expects axis-angle in radians; quarter-turn around world up.
		skyAxisAngle = {0.0, 1.0, 0.0, math.pi / 2},
		skyBox       = "skyboxes/clear-day.dds",

		cloudDensity = 0.25,
	},

	grass = {
		bladeWaveScale = 1.0,
		bladeWidth  = 0.82,
		bladeHeight = 8.0,
		bladeAngle  = 2.57,
		bladeColor  = {0.59, 0.81, 0.57}, --// does nothing when `grassBladeTex` is set
	},
	lighting = {
		--// dynsun
		--sunStartAngle = 0.0,
		--sunOrbitTime  = 1440.0, --how do i turn this off?
		    sunDir = {
      1.3,
      0.95,
      0.62,
    },

		--// unit & ground lighting
         groundambientcolor            = { 0.5, 0.5, 0.6 },
         grounddiffusecolor            = { 0.85, 0.85, 0.55 },
		 groudspecularcolor            = {0.7,0.7,0.7    },
         groundshadowdensity           = 0.65,    
		 unitAmbientColor = {
			  0.56999999,
			  0.56942999,
			  0.56942999,
		},    
		unitDiffuseColor = {
			  1,
			  0.98533332,
			  0.92000002,
			},
		unitSpecularColor = {
			  0.8,
			  0.60000001,
			  0.60000001,
		},
         unitshadowdensity          = 0.9,
		 specularsuncolor           = { 1.0, 1.0, 1.0 },
		 
		specularExponent    = 100.0,
	},
		water = { --regular water settings
		damage =  0,

		repeatX = 0.0,
		repeatY = 0.0,

		absorb    = { 0.08, 0.005, 0.001 }, --absorbption coefficient per elmo of water depth
		basecolor = { 1.0, 1.0, 1.0 }, -- the color shallow water starts out at
		mincolor  = { 0.1, 0.3, 0.4 },

		ambientFactor  = 1.0,
		diffuseFactor  = 1.0,
		specularFactor = 1.4,
		specularPower  = 40.0,

		surfacecolor  = { 0.67, 0.8, 1.0 }, --color of the water texture
		surfaceAlpha  = 0.1,
		diffuseColor  = {0.0, 0.0, 0.0},
		specularColor = {0.5, 0.5, 0.5},
		planeColor = {0.00, 0.15, 0.15}, --outside water plane color

		fresnelMin   = 0.2,
		fresnelMax   = 1.6,
		fresnelPower = 8.0,

		reflectionDistortion = 1.0,

		blurBase      = 2.0,
		blurExponent = 1.5,

		perlinStartFreq  =  8.0,
		perlinLacunarity = 3.0,
		perlinAmplitude  =  0.9,
		windSpeed = 1.0, --// does nothing yet

		shoreWaves = true,
		forceRendering = false,
		
		hasWaterPlane = true, --specifies whether the outside of the map has an extended water plane

		--// undefined == load them from resources.lua!
		--texture =       "",
		--foamTexture =   "",
		--normalTexture = "",
		--caustics = {
		--	"",
		--	"",
		--},
	},
	
	--[[
	-- lovely acid water settings:
	water = {
		damage =  50,

		repeatX = 0.0,
		repeatY = 0.0,

		absorb    = { 0.01, 0.08, 0.01 },
		basecolor = { 0.8, 0.4, 0.8 }, --or 0.4 0.0 0.4
		mincolor  = { 0.2, 0.0, 0.2 },

		ambientFactor  = 1.0,
		diffuseFactor  = 1.0,
		specularFactor = 1.4,
		specularPower  = 40.0,

		surfacecolor  = { 1.0, 0.65, 1.0 },
		surfaceAlpha  = 0.1,
		diffuseColor  = {0.0, 0.0, 0.0},
		specularColor = {0.5, 0.5, 0.5},
		planeColor = {0.02, 0.035, 0.02},

		fresnelMin   = 0.2,
		fresnelMax   = 1.6,
		fresnelPower = 8.0,

		reflectionDistortion = 1.0,

		blurBase      = 2.0,
		blurExponent = 1.5,

		perlinStartFreq  =  8.0,
		perlinLacunarity = 3.0,
		perlinAmplitude  =  0.9,
		windSpeed = 1.0, --// does nothing yet

		shoreWaves = true,
		forceRendering = false,
		
		hasWaterPlane = true,

		--// undefined == load them from resources.lua!
		--texture =       "",
		--foamTexture =   "",
		--normalTexture = "",
		--caustics = {
		--	"",
		--	"",
		--},
	},]]--

	teams = {
		[0] = {startPos = {x = 8075, z = 2381}},
		[1] = {startPos = {x = 7403, z = 6853}},
		[2] = {startPos = {x = 2761, z = 6913}},
		[3] = {startPos = {x = 917, z = 4497}},
		[4] = {startPos = {x = 340, z = 1327}},
		[5] = {startPos = {x = 5107, z = 365}},
		[6] = {startPos = {x = 8075, z = 2381}},
	},

	terrainTypes = {
		[0] = {
			name = "Ground",
			hardness = 1.0,
			receiveTracks = true,
			moveSpeeds = {
				vehicle = 0.75,
				bipedal = 1.0,
				quadruped = 1.0,
				airunit = 1.0,
				tank  = 0.75,
				kbot  = 0.75,
				hover = 0.75,
				ship  = 0.75,
			},
		},	
		[255]= {
			name = "Street",
			hardness = 1.0,
			receiveTracks = false,
			moveSpeeds = {
				vehicle = 1.0,
				bipedal = 1.0,
				quadruped = 1.0,
				airunit = 1.0,
				tank  = 1.0,
				kbot  = 1.0,
				hover = 1.0,
				ship  = 1.0,
			},
		}
	},

	custom = {
		fog = {
			color    = {0.26, 0.30, 0.41},
			height   = "80%", --// allows either absolue sizes or in percent of map's MaxHeight
			fogatten = 0.003,
		},
		--[[
		precipitation = {
			density   = 30000,
			size      = 1.5,
			speed     = 50,
			windscale = 1.2,
			texture   = 'LuaGaia/effects/snowflake.png',
		},]]--
	},
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper

local function lowerkeys(ta)
	local fix = {}
	for i,v in pairs(ta) do
		if (type(i) == "string") then
			if (i ~= i:lower()) then
				fix[#fix+1] = i
			end
		end
		if (type(v) == "table") then
			lowerkeys(v)
		end
	end
	
	for i=1,#fix do
		local idx = fix[i]
		ta[idx:lower()] = ta[idx]
		ta[idx] = nil
	end
end

lowerkeys(mapinfo)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Map Options

if (Spring) then
	local function tmerge(t1, t2)
		for i,v in pairs(t2) do
			if (type(v) == "table") then
				t1[i] = t1[i] or {}
				tmerge(t1[i], v)
			else
				t1[i] = v
			end
		end
	end

	-- make code safe in unitsync
	if (not Spring.GetMapOptions) then
		Spring.GetMapOptions = function() return {} end
	end
	function tobool(val)
		local t = type(val)
		if (t == 'nil') then
			return false
		elseif (t == 'boolean') then
			return val
		elseif (t == 'number') then
			return (val ~= 0)
		elseif (t == 'string') then
			return ((val ~= '0') and (val ~= 'false'))
		end
		return false
	end

	getfenv()["mapinfo"] = mapinfo
		local files = VFS.DirList("mapconfig/mapinfo/", "*.lua")
		table.sort(files)
		for i=1,#files do
			local newcfg = VFS.Include(files[i])
			if newcfg then
				lowerkeys(newcfg)
				tmerge(mapinfo, newcfg)
			end
		end
	getfenv()["mapinfo"] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return mapinfo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
