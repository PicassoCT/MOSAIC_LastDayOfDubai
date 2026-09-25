--[[  OPTION DEFINITION FILES

  CustomMapOptions.lua
  - belongs in the map archive
  - options that get used by LuaGaia

  CustomModOptions.lua
  - belongs in the mod archive
  - options that get used by LuaRules

--]]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--  NOTES:
--  - using an enumerated table lets you specify the options order

--
--  These keywords must be lowercase for LuaParser to read them.
--
--  key:      the string used in the script.txt
--  name:     the displayed name
--  desc:     the description (could be used as a tooltip)
--  type:     the option type
--  def:      the default value
--  min:      minimum value for number options
--  max:      maximum value for number options
--  step:     quantization step, aligned to the def value
--  maxlen:   the maximum string length for string options
--  items:    array of item strings for list options
--  scope:    'all', 'player', 'team', 'allyteam'      <<< not supported yet >>>
--

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local options = {
    {
        key = 'dhubai_sky', name = 'Dhubai skybox', type = 'list', def = 'clear-day',
        desc = 'Static sky background; does not change game time, lighting or rainfall.',
        items = {
            {key='clear-day', name='Clear daylight'},
            {key='overcast-day', name='Overcast daylight'},
            {key='sunset-sandstorm', name='Sunset and sandstorm'},
            {key='rainy-night', name='Rainy night'},
            {key='original', name='Original desert'},
        },
    },
    {
        key = 'dhubai_splats', name = 'Terrain normal detail', type = 'list', def = 'subtle',
        desc = 'Compare terrain normal strength without changing texture scale or distribution.',
        items = {
            {key='subtle', name='Subtle'},
            {key='original', name='Original strength'},
            {key='off', name='Off (diagnostic)'},
        },
    },
 	--[[{
	    key    = 'Roads',
	    name   = 'Roads',
	    desc   = 'Enables speed boosts for units on roads',
		type   = 'bool',
	    def    = true,
 	}, ]]--
	--[[
		key    = 'WaterDamage',
		name   = 'Water Damage',
		desc   = 'Enables acidic water',
	 	type   = 'bool',
	 	def    = false,
	},]]--
	{
		key    = 'Dry',
		name   = 'Dry',
		desc   = 'Should the map be dry?',
		type   = 'number',
		def    = 0,
		min    = 0,
		max    = 1,
		step   = 1,  -- quantization is aligned to the def value
				-- (step <= 0) means that there is no quantization
	},
}

return options
