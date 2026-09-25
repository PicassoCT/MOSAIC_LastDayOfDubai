
-->generates a Pieces List 
function generatepiecesTableAndArrayCode(unitID, boolLoud)
	bLoud = boolLoud or false
	
	if bLoud == true then
		Spring.Echo("")
		Spring.Echo("--PIECESLIST::BEGIN |>----------------------------")
		Spring.Echo("piecesTable={}")
		piecesTable = {}
		piecesTable = Spring.GetUnitPieceList(unitID)
		--Spring.Echo("local piecesTable={}")
		if piecesTable ~= nil then
			for i = 1, #piecesTable, 1 do
				workingString = piecesTable[i]
				Spring.Echo("" .. piecesTable[i] .. " = piece(\"" .. piecesTable[i] .. "\")\n piecesTable[#piecesTable+1]= " .. piecesTable[i])
			end
		end
		
		Spring.Echo("PIECESLIST::END |>-----------------------------")
	end
	
	
	return makePieceTable(unitID)
end


--> finds GenericNames and Creates Tables with them
function makePiecesTablesByNameGroups(boolMakePiecesTable, boolSilent)
	
	boolSilentRun = boolSilent or true
	pieceMap = Spring.GetUnitPieceMap(unitID)
	piecesTable = Spring.GetUnitPieceList(unitID)
	
	TableByName = {}
	NameAndNumber = {}
	ReturnTable = {}
	
	for i = 1, #piecesTable, 1 do
		s = string.reverse(piecesTable[i])
		
		for w in string.gmatch(s, "%d+") do
			if w then
				s = string.sub(s, string.len(w), string.len(s))
				NameAndNumber[i] = {
					name = string.sub(piecesTable[i], 1, string.len(piecesTable[i]) - string.len(w)),
					number = string.reverse(w)
				}
				
				if TableByName[NameAndNumber[i].name] then
					TableByName[NameAndNumber[i].name] = TableByName[NameAndNumber[i].name] + 1
				else
					TableByName[NameAndNumber[i].name] = 1
				end
				break
			end
		end
		if not NameAndNumber[i] then NameAndNumber[i] = { name = string.reverse(s) } end
	end
	
	
	if boolSilentRun == false then
		for k, v in pairs(TableByName) do
			if v > 1 then
				Spring.Echo(k .. " = {}")
			end
		end
		
		
		for k, v in pairs(NameAndNumber) do
			
			if v and v.number then
				Spring.Echo(v.name .. v.number .. " = piece\"" .. v.name .. v.number .. "\"")
				Spring.Echo(v.name .. "[" .. v.number .. "]= " .. v.name .. v.number)
			else
				Spring.Echo(v.name .. " = piece(" .. v.name .. ")")
			end
		end
		
		if boolMakePiecesTable and boolMakePiecesTable == true then
			generatepiecesTableAndArrayCode(unitID)
		end
		
	else
		
		--pack the piecesTables in a UeberTable by Name
		for tableName, _ in pairs(TableByName) do
			local PackedAllNames = {}
			--Add the Pieces to the Table
			for k, v in pairs(NameAndNumber) do
				
				if v and v.number and v.name == tableName then
					piecename = v.name .. v.number
					if lib_boolDebug == true then
						if lib_boolDebug == true and pieceMap[piecename] then
							Spring.Echo(v.name .. "[" .. v.number .. "] = " .. piecename .. " Piecenumber: " .. pieceMap[piecename])
						else
							Spring.Echo("pieceMap contains no piece named " .. piecename)
						end
					end
					convertToNumber = tonumber(v.number)
					PackedAllNames[convertToNumber] = pieceMap[piecename]
				end
			end
			ReturnTable[tableName] = PackedAllNames
		end
		
		return ReturnTable
	end
end


-->Reset a Table of Pieces at speed

function resetT(tableName, speed, ShowAll, boolWait, boolIstantUpdate, interValStart, interValEnd)
	lboolWait = boolWait or false
	lspeed = speed or 0
	interValStart= interValStart or 1
	interValEnd = interValEnd or #tableName
	
	assert(tableName, "libAnimation::resetT: No valid Table")
	
	for i = interValStart, interValEnd do
		
		reset(tableName[i], lspeed, false, boolIstantUpdate)
		if ShowAll and tableName[i] then
			Show(tableName[i])
		end
	end
	
	if lboolWait == true then
		WaitForTurns(tableName)
	end
end

-->Waits for anyTurnToComplete
function WaitForTurns(...)
	local arg = arg
	if (not arg) then arg = {...}; arg.n = #arg end
	if not arg then echo("No arguments for WaitForTurns"); return end
	
	typeArg = type(arg)
	
	if typeArg == "table" then
		
		for k, v in pairs(arg) do
			if type(v) == "number" then
				WaitForTurn(v, x_axis)
				WaitForTurn(v, y_axis)
				WaitForTurn(v, z_axis)
			end
		end
		return
	elseif typeArg == "number" then
		WaitForTurn(arg, x_axis)
		WaitForTurn(arg, y_axis)
		WaitForTurn(arg, z_axis)
	end
end

-->Turns a piece in wind direction with offset
function TurnTowardsWind(piecename, speed, offset)
	offSet = offset or 0
	dx, dy, dz = Spring.GetWind()
	headRad = math.atan2(dx, dz)
	Turn(piecename, y_axis, headRad + offSet, speed)
	return headRad
end

-->itterates over a table, executing a function with a argumentTable
function elementWise(T, fooNction, ArghT)
	reTable = {}
	
	for k, v in pairs(T) do
		reTable[k] = fooNction(T[k], ArghT)
	end
	
	return reTable
end

--> takes a Table, and executes Function on it
-- non Function Values are handed to the function following it
-- returning nil removes a element from the process chain
function process(Table, ...)
	local arg = { ... }
	local arg = arg; if (not arg) then arg = { ... }; arg.n = #arg end
	T = {}
	if Table then
		T = Table
	else
		if lib_boolDebug == true then
			echo("Lua:lib_UnitScript:Process: No Table handed over")
			return
		end
	end
	if not arg then echo("No args in process") return end
	if type(arg) == "function" then return elementWise(T, arg) end
	
	
	TempArg = {}
	TempFunc = {}
	--if not arg then return Table end
	
	for _, f in pairs(arg) do
		if type(f) == "function" then
			T = elementWise(T, f, TempArg)
			TempArg = {}
		else
			TempArg[#TempArg + 1] = f
		end
	end
	return T
end


--> Hides a PiecesTable, 
function hideT(tablename, lowLimit, upLimit, delay)
	if not tablename then return end
	boolDebugActive = (lib_boolDebug == true and lowLimit and type(lowLimit) ~= "string")
	
	if lowLimit and upLimit then
		for i = upLimit, lowLimit, -1 do
			if tablename[i] then
				Hide(tablename[i])
			elseif boolDebugActive == true then
				echo("In HideT, table " .. lowLimit .. " contains a empty entry")
			end
			
			if delay and delay > 0 then Sleep(delay) end
		end
		
	else
		for i = 1, table.getn(tablename), 1 do
			if tablename[i] then
				Hide(tablename[i])
			elseif boolDebugActive == true then
				echo("In HideT, table " .. lowLimit .. " contains a empty entry")
			end
		end
	end
end
-->Shows a Pieces Table
function showT(tablename, lowLimit, upLimit, delay)
	if not tablename then Spring.Echo("No table given as argument for showT") return end
	
	if lowLimit and upLimit then
		for i = lowLimit, upLimit, 1 do
			if tablename[i] then
				Show(tablename[i])
			end
			if delay and delay > 0 then Sleep(delay) end
		end
		
	else
		for i = 1, table.getn(tablename), 1 do
			if tablename[i] then
				Show(tablename[i])
			end
		end
	end
end

function pseudoRandom(seedstring, preSeed)
	preSeed= preSeed or 0
	seedstring = seedstring or "lore ipsum" 
	
	seed=0
	for i=1 ,#seedstring do
		seed = seed +string.byte(seedstring,i)
	end
	
	seed= seed +preSeed
	
	values={1,57,20,81,59,48,36,90,83,75,18,86,72,52,31,2,10,37,15,17,
		99,45,12,1,1,38,54,58,61,61,
		17,67,46,36,6,61,79,81,52,31,
		88,73,96,93,54,15,47,24,87,21,
		78,85,100,100,62,40,27,30,85,3,
		38,10,68,6,1,92,28,28,59,70,
		84,73,49,21,75,47,46,95,75,11,
		60,39,74,61,58,37,16,23,43,81,
		52,99,76,35,17,66,50,7,70,51,
		15,95,15,91,70,31,43,8,97,69,
		16,88,83,59,20,18,82,48,16,51,
		74,41,28,57,69,76,73,48,13,37,
		84,4,52,67,43,11,95,93,55,35,
		48,38,85,32,46,28,99,30,74,57,
		20,77,84,40,51,90,3,100,58,6,
		54,20,85,63,66,20,85,13,11,75,
		32,95,29,34,15,74,84,71,61,75,
		26,15,1,7,81,86,22,12,56,2,
		12,46,76,69,55,8,44,21,70,30,
		44,24,58,54,63,17,51,97,70,93,
		19,34,18,100,46,100,10,63,10,44,
		94,5,90,30,23,77,42,21,63,61,
		46,47,60,64,86,83,63,73,57,38,
		19,74,56,91,25,19,61,70,59,36,
		50,9,75,62,63,70,81,15,58,87,
		92,62,73,5,67,98,32,57,31,18,
		11,87,86,75,16,33,8,8,65,83,
		55,45,41,30,47,51,16,33,74,32,
		83,96,88,73,31,95,13,7,79,53,
		61,96,8,88,66,33,11,51,23,30,
		92,56,67,12,50,38,50,80,51,39,
		69,54,61,40,1,71,11,63,87,50,
		75,50,39,79,56,36,96,64,18,38,
		14,75,96,62,3,33,6,64,14,85,
		87,60,73,86,2,13,71,62,22,7,
		17,63,35,32,37,67,81,81,53,62,
		80,91,15,64,41,26,14,86,7,43,
		58,31,55,23,32,12,81,14,29,79,
		90,79,75,62,37,86,23,87,23,25,
		55,99,6,9,53,43,10,26,90,24,
		15,13,94,9,5,6,34,92,40,44,
		95,84,54,85,70,40,26,1,53,96,
		40,25,59,26,69,95,44,90,1,95,
		61,79,58,15,23,39,1,42,9,66,
		86,7,82,67,70,81,54,69,15,69,
		73,78,4,87,65,71,9,56,95,6,
		28,15,99,62,30,93,37,70,22,16,
		25,53,91,11,91,45,9,79,18,98,
		78,88,22,46,1,76,12,41,32,100,
		4,26,19,25,16,63,89,94,20,78,
		65,66,91,46,93,67,16,64,57,43,
		95,55,58,54,26,40,36,4,80,20,
		8,39,60,8,20,16,65,46,61,70,
		45,69,40,84,60,20,95,88,40,99,
		19,90,58,45,63,71,5,29,27,41,
		90,72,73,90,40,40,91,31,39,58,
		36,74,75,74,74,14,21,28,69,92,
		37,52,11,91,21,52,66,44,69,10,
		8,8,3,36,31,70,15,40,7,68,
		73,20,70,62,66,55,10,55,5,98,
		47,97,73,54,68,70,38,39,5,81,
		17,7,32,79,22,33,49,1,44,51,
		61,76,41,35,85,95,63,100,6,57,
		87,39,31,29,3,62,40,2,4,46,
		86,94,41,73,62,81,88,59,60,8,
		80,47,60,59,57,82,68,35,2,27,
		35,24,78,38,87,12,73,63,90,19,
		54,91,79,97,20,91,80,96,85,90,
		63,19,62,27,26,74,79,18,72,49,
		9,81,86,13,31,58,48,77,20,73,
		100,2,65,70,18,8,28,68,84,56,
		38,78,24,64,24,21,98,29,3,77,
		16,5,1,35,65,35,42,42,10,55,
		70,34,66,88,54,58,6,47,26,43,
		87,49,9,57,71,78,87,86,30,87,
		65,75,83,77,88,91,92,53,45,11,
		36,83,43,17,1,66,78,7,9,39,
		69,81,16,15,5,35,2,98,65,6,
		92,64,44,3,25,40,66,79,3,83,
		14,64,56,99,47,22,31,79,35,49,
		61,11,99,76,16,46,72,100,78,65,
		63,95,69,29,57,30,55,72,25,55,
		50,96,67,77,63,45,80,75,99,21,
		63,91,60,92,51,49,45,89,95,19,
		26,21,74,95,63,5,65,4,56,55,
		45,7,100,13,61,6,18,67,34,32,
		66,42,43,23,68,17,50,51,81,44,
		1,34,38,13,83,74,90,65,66,52,
		74,74,96,47,37,12,91,83,46,11,
		87,77,4,42,94,7,17,22,12,60,
		12,62,59,70,74,92,67,30,81,38,
		100,78,21,18,39,19,59,20,97,20,
		39,31,13,20,5,78,77,89,1,45,
		43,81,47,50,75,24,56,10,93,90,
		86,6,50,64,75,76,26,91,80,20,
		56,6,53,80,71,3,74,56,92,88,
		80,31,40,49,6,66,1,77,76,22,
		16,6,68,4,35,70,80,44,99,64,
	30,48,88,8,11,15,15,92,31,38}
	
	
	return values[math.max(1,math.min(#values,(seed%#values) +1))], preSeed
	
end