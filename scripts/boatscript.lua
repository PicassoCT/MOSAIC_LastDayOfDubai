

TablesOfPiecesGroups = {}

function hashSign(hash)
    if hash % 2== 1 then return -1 end
    return 1
end

function assertNr(v)
 assert(type(v)== "number")
end

-- > Hide all Pieces of a Unit
function hideAll(id)
    if not unitID then unitID = id end

    pieceMap = Spring.GetUnitPieceMap(unitID)
    for k, v in pairs(pieceMap) do 
        assertNr(v)
        Hide(v) end
end

function getPieceTableByNameGroups()


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
                    name = string.sub(piecesTable[i], 1, string.len(
                                          piecesTable[i]) - string.len(w)),
                    number = string.reverse(w)
                }

                if TableByName[NameAndNumber[i].name] then
                    TableByName[NameAndNumber[i].name] =
                        TableByName[NameAndNumber[i].name] + 1
                else
                    TableByName[NameAndNumber[i].name] = 1
                end
                break
            end
        end
        if not NameAndNumber[i] then
            NameAndNumber[i] = {name = string.reverse(s)}
        end
    end



        -- pack the piecesTables in a UeberTable by Name
        for tableName, _ in pairs(TableByName) do
            local PackedAllNames = {}
            -- Add the Pieces to the Table
            for k, v in pairs(NameAndNumber) do

                if v and v.number and v.name == tableName then
                    piecename = v.name .. v.number
                    if lib_boolDebug == true then
                        if lib_boolDebug == true and pieceMap[piecename] then
                            Spring.Echo(v.name .. "[" .. v.number .. "] = " ..
                                            piecename .. " Piecenumber: " ..
                                            pieceMap[piecename])
                        else
                            Spring.Echo("pieceMap contains no piece named " ..
                                            piecename)
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


function script.Create()
    Spring.SetUnitAlwaysVisible(unitID,true)
    hideAll(unitID)    
    x,y,z = Spring.GetUnitPosition(unitID)
    Spring.SetUnitRotation(unitID, 0, math.rad(x+ y + z),0)

    -- generatepiecesTableAndArrayCode(unitID)
    TablesOfPiecesGroups = getPieceTableByNameGroups(false, true)
  
    dice = showOnePiece(TablesOfPiecesGroups["Boat"], unitID)
    Turn(dice, 3, math.rad(unitID/math.pi), 0)
    if dice == 3 then
        Show(TablesOfPiecesGroups["Sail"][1])
        Show(TablesOfPiecesGroups["Sail"][2])
    end

end

function showOnePiece(T, hash)
    if not T then return end
        countNrElments = count(T)
        dice = 1
    if hash then
        dice = (hash % countNrElments) +1
    else        
        dice = (unitID % countNrElments) +1
    end
    
    c = 0
    for k, v in pairs(T) do
        if k and v then c = c + 1 end
        if c == dice then
                assertNr(v)
                Show(v)
                return v
        end
    end
    return dice
end

-- > Counts the number of elements in a dictionary
function count(T)
    if not T then return 0 end
    local index = 0
    for k, v in pairs(T) do if v then index = index + 1 end end
    return index
end

