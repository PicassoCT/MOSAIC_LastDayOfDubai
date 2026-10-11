-- Run from the map repository root with Lua 5.1+.
-- Optionally set MOSAIC_GAME_ROOT to exercise the paired game's real policy.
local function loadEnv(path, env)
    setmetatable(env, {__index = _G})
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(path, 't', env))
    end
    return chunk()
end

local function noop() end
local authored = dofile('mapconfig/cityplacer/set.lua')
local names = {map_placements_complete = true, decoration = true, landmark = true}
for _, list in ipairs({authored.unitlist, authored.buildinglist}) do
    for _, entry in pairs(list) do names[entry.name] = true end
end
local defs, byName, candidates, ruins = {}, {}, {}, {}
local sortedNames = {}
for name in pairs(names) do sortedNames[#sortedNames + 1] = name end
table.sort(sortedNames)
for id, name in ipairs(sortedNames) do
    defs[id] = {id = id, name = name}
    byName[name] = defs[id]
    -- Fixture membership only. The production map consumes lib_mosaic sets.
    if name == 'house_ruin' then ruins[id] = true
    elseif name:match('^house_') then candidates[id] = true end
end

local function house(name, x, z, rot)
    return {name = name, x = x, z = z or 100, rot = rot or 0}
end

local fixture = {
    objectlist = {{name = 'tree', x = 9, z = 9, rot = 90}},
    unitlist = {
        house('house_western0', 100, 100, 90),
        house('house_arab0', 100), -- same plot, different intact type
        house('house_ruin', 200),
        house('decoration', 300), house('decoration', 300),
        house('landmark', 350),
        house('house_asian1', 401), house('house_asian1', 402),
        house('house_asian1', 403), house('house_asian1', 404),
        house('house_asian1', 405),
    },
    buildinglist = {
        house('house_ruin', 100), -- duplicate across the two input lists
        house('house_arab0', 500, 600, 180),
    },
}

local function run(config, options)
    options = options or {}
    local records, attempts, rolls, features = {}, {}, {}, {}
    local locationReads, imports, policyImports = 0, 0, 0
    local env = {gadget = {}, GG = {}, UnitDefs = defs, UnitDefNames = byName,
        Game = {mapName = options.mapName or 'MOSAIC_LastDayOfDubai_V1', mapSizeX = 8192, mapSizeZ = 8192},
        gadgetHandler = {IsSyncedCode = function() return true end}}
    local shared = {
        getCityGeography = function()
            locationReads = locationReads + 1
            return {hash = 456, latitude = 25.2}
        end,
        getCityRuinConfig = function() return {protectedMinimums = {house_asian1 = 3}} end,
        getCityRuinCandidateTypeTable = function() return candidates end,
        getCityRuinTypeTable = function() return ruins end,
    }
    local function get(id)
        assert(id and records[id], 'metadata setter received a failed/duplicate creation')
        return records[id]
    end
    env.Spring = {
        Echo = noop, GetGameFrame = function() return 0 end,
        GetGaiaTeamID = function() return 7 end, GetGroundHeight = function() return 12 end,
        CreateUnit = function(name, x, y, z, facing, team)
            if type(name) == 'number' then name = defs[name].name end
            attempts[#attempts + 1] = {name = name, x = x, z = z}
            if options.failX == x then return nil end
            local id = #records + 1
            records[id] = {name = name, x = x, y = y, z = z, facing = facing, team = team}
            return id
        end,
        SetUnitNeutral = function(id, value) get(id).neutral = value end,
        SetUnitAlwaysVisible = function(id, value) get(id).visible = value end,
        SetUnitRotation = function(id, x, y, z) get(id).rotation = {x, y, z} end,
        SetUnitBlocking = function(id) get(id) end,
        CreateFeature = function(name, x, y, z, rotation)
            features[#features + 1] = {name = name, x = x, y = y, z = z, rotation = rotation}
            return #features
        end,
        SetFeatureBlocking = function(id) assert(features[id]) end,
        DestroyUnit = function() error('initial placement must never destroy or reconstruct units') end,
    }
    env.VFS = {
        FileExists = function(path)
            return path == 'mapconfig/cityplacer/config.lua' or options.mode ~= 'missing'
        end,
        Include = function(path, importEnv)
            if path == 'mapconfig/cityplacer/config.lua' then return config end
            if path == 'scripts/lib_mosaic.lua' then
                imports = imports + 1
                assert(importEnv and importEnv.MOSAIC_CONFIG_ONLY, 'import ran synced game initialization')
                if options.mode == 'old' then return {} end
                if options.gameRoot then
                    importEnv.Game, importEnv.UnitDefs = env.Game, defs
                    importEnv.VFS = {
                        FileExists = function(file)
                            return file == 'mosaic/location.lua' and not options.withoutMetadata
                        end,
                        Include = function(file)
                            if file == 'mosaic/location.lua' then return dofile(file) end
                            return dofile(options.gameRoot .. '/' .. file)
                        end,
                    }
                    local realShared = loadEnv(options.gameRoot .. '/' .. path, importEnv)
                    local resolve = realShared.getCityGeography
                    realShared.getCityGeography = function(...)
                        locationReads = locationReads + 1
                        local location = resolve(...)
                        assert(location.country == 'United Arab Emirates' and location.latitude == 25.2)
                        assert(location.region == 'MiddleEast')
                        assert(location.source == (options.withoutMetadata and 'named-map' or 'map-metadata'))
                        return location
                    end
                    return realShared
                end
                return shared
            end
            assert(path == 'scripts/lib_city_ruins.lua', 'unexpected dependency: ' .. path)
            policyImports = policyImports + 1
            if options.gameRoot then return dofile(options.gameRoot .. '/' .. path) end
            return {ShouldRuin = function(hash, x, z, latitude, cfg)
                assert(hash == 456 and latitude == 25.2, 'map did not use shared geography')
                assert(cfg.protectedMinimums.house_asian1 == 3)
                rolls[#rolls + 1] = {x = x, z = z}
                return options.ruin ~= false
            end}
        end,
    }
    loadEnv('LuaGaia/Gadgets/cityplacer.lua', env)
    env.gadget:Initialize()
    return {records = records, attempts = attempts, rolls = rolls, features = features,
        env = env, locationReads = locationReads, imports = imports, policyImports = policyImports}
end

local function at(result, x, z)
    local found = {}
    for _, record in ipairs(result.records) do
        if record.x == x and record.z == (z or 100) then found[#found + 1] = record end
    end
    return found
end

-- The same final plot is claimed before another list can create an overlapping
-- ruin or intact house. Non-house stackings and map metadata remain authored.
local result = run(fixture, {failX = 401})
assert(#at(result, 100) == 1 and at(result, 100)[1].name == 'house_ruin')
assert(#at(result, 300) == 2, 'intentional non-house stacking was removed')
assert(at(result, 350)[1].name == 'landmark')
assert(at(result, 200)[1].name == 'house_ruin', 'explicit ruin disappeared')
assert(#at(result, 401) == 0)
for x = 402, 404 do assert(at(result, x)[1].name == 'house_asian1', 'failed creation consumed a minimum') end
assert(at(result, 405)[1].name == 'house_ruin', 'extra arcology ignored geography policy')
assert(result.locationReads == 1 and result.imports == 1 and result.policyImports == 1)
assert(#result.rolls == 3, 'duplicate, protected or explicit ruin plot consumed another roll')
local first, building = at(result, 100)[1], at(result, 500, 600)[1]
assert(first.team == 7 and first.y == 0 and first.facing == 0)
assert(first.rotation[2] == math.rad(90) and first.neutral and first.visible)
assert(building.name == 'house_ruin' and building.facing == math.rad(180))
assert(building.neutral and building.visible)
local registered
for _, data in pairs(result.env.GG.storedSpawnedHouses) do
    if data.x == 500 and data.z == 600 and data.y == 0 then registered = true end
end
assert(registered, 'authored building metadata was lost when its selected type changed')
assert(#result.features == 1 and result.features[1].y == 17)
assert(fixture.unitlist[1].name == 'house_western0', 'selection mutated source placement records')

-- A zero ruin rate still reserves one occupant per civilian plot and preserves
-- authored ruins. Compatibility with both absent helpers and older exports
-- preserves the original CreateUnit requests and metadata.
local intact = run(fixture, {ruin = false})
assert(#at(intact, 100) == 1 and at(intact, 100)[1].name == 'house_western0')
assert(at(intact, 200)[1].name == 'house_ruin')
for _, mode in ipairs({'missing', 'old'}) do
    local legacy = run(fixture, {mode = mode})
    assert(#legacy.records == #fixture.unitlist + #fixture.buildinglist + 1)
    assert(at(legacy, 100)[1].name == 'house_western0')
    assert(at(legacy, 100)[1].rotation[2] == math.rad(90))
    assert(at(legacy, 500, 600)[1].name == 'house_arab0')
    assert(legacy.locationReads == 0 and legacy.policyImports == 0)
end

-- The actual authored map must itself contain no repeated house plot, even
-- when paired with an older game. Retain all three explicit war ruins.
local houseCount, explicitRuins, positions = 0, 0, {}
for _, entry in ipairs(authored.unitlist) do
    local defID = byName[entry.name].id
    if candidates[defID] or ruins[defID] then
        local key = entry.x .. ':' .. entry.z
        assert(not positions[key], 'duplicate authored city plot at ' .. key)
        positions[key] = true
        houseCount = houseCount + 1
        if ruins[defID] then explicitRuins = explicitRuins + 1 end
    end
end
assert(houseCount == 199 and explicitRuins == 3, 'authored city content changed unexpectedly')
local actual = run(authored)
local remainingArcologies, selectedRuins = 0, 0
for _, record in ipairs(actual.records) do
    if record.name == 'house_asian1' then remainingArcologies = remainingArcologies + 1 end
    if record.name == 'house_ruin' then selectedRuins = selectedRuins + 1 end
end
assert(remainingArcologies == 3 and selectedRuins == 196)
assert(#actual.records == #authored.unitlist + #authored.buildinglist + 1)
assert(#actual.features == #authored.objectlist)

local gameRoot = os.getenv('MOSAIC_GAME_ROOT')
if gameRoot then
    local a, b = run(authored, {gameRoot = gameRoot}), run(authored, {gameRoot = gameRoot})
    assert(#a.records == #b.records and #a.records == #actual.records)
    local actualRuins, arcs = 0, 0
    for i, record in ipairs(a.records) do
        assert(record.name == b.records[i].name, 'paired game policy changed across identical map loads')
        if record.name == 'house_ruin' then actualRuins = actualRuins + 1 end
        if record.name == 'house_asian1' then arcs = arcs + 1 end
    end
    assert(actualRuins > 3 and actualRuins < 196 and arcs >= 3, 'paired game policy not applied to actual city')
    assert(a.locationReads == 1 and b.locationReads == 1)
    local fallback = run(authored, {gameRoot = gameRoot, withoutMetadata = true})
    for i, record in ipairs(a.records) do
        assert(record.name == fallback.records[i].name, 'named-map metadata fallback changed city geography')
    end
    run(authored, {gameRoot = gameRoot, mapName = 'Renamed city archive'})
    print('PASS: paired game policy; ' .. actualRuins .. '/199 authored plots are ruins; ' .. arcs .. ' arcology candidates retained')
end
print('PASS: pre-spawn ruin choice, unique civilian plots, protected minima, authored metadata, fallback and complete map data')
