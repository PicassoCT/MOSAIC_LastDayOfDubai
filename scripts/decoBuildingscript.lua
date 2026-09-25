TablesOfPiecesGroups = {}

function hashSign(hash)
    if hash % 2== 1 then return -1 end
    return 1
end

function randShowHide(T, hash, maxNr)
    nr= count(T)
    result = {}
    for k=1, maxNr do
        index = math.random(1,#T)
        counter=0
        for num, val in pairs(T) do 
            counter= counter+1
            if counter == index then
                Show(val)
                result[#result+1] = val
                break
            end       
        end
    end
    return result
end 

offsetGrid={}
for x=-1,1 do
    offsetGrid[x] = {}
    for y=-1,1 do
        offsetGrid[x][y]= false
    end
end

function getGridPostion(x,y)
    if offsetGrid[x][y] == false then
        offsetGrid[x][y] = true
        return x,y
    else
        for ax=x,1 do
            for ay=y,1 do
                if offsetGrid[ax][ay] == false then
                   offsetGrid[ax][ay] = true
                   return ax,ay
               end
           end
        end
        for ax=-1,x do
            for ay=-1,y do
                if offsetGrid[ax][ay] == false then
                   offsetGrid[ax][ay] = true
                   return ax,ay
               end
           end
        end
    end
end

function turnPerHourSpeed(degree)
    return math.rad(degree)/(60*60)
end

function delayedSetup()
    Sleep(100)
    -- generatepiecesTableAndArrayCode(unitID)
    TablesOfPiecesGroups = getPieceTableByNameGroups(false, true)
    x,y,z = Spring.GetUnitPosition(unitID)
    hash = x + y * z
    name, description = getNameTooltipNotPlayableBuilding(hash)
    tooltip = name.." : "..description
    Spring.SetUnitTooltip(unitID, tooltip)
    --Spring.Echo("Deploying Dune ")
    dunes = randShowHide(TablesOfPiecesGroups["base"], hash, 1)
    for i=1,#dunes do
        ranDir = (dunes[i]* unitID) %360
        value = dunes[i]/unitID
        Move(dunes[i], z_axis, value, 0)
        Turn(dunes[i], y_axis, math.rad(ranDir),0)
        if i % 2 == 0 then
            sign =  (-1^dunes[i])
            spinValue = turnPerHourSpeed(270)*sign
            Spin(dunes[i], y_axis, spinValue, 0.01)
        end
    end
    --Spring.Echo("Deploying Foyer ")
    randShowHide(TablesOfPiecesGroups["Foyer"], hash, 1)

    if math.random(1,100) <= 99 then
        randShowHide(TablesOfPiecesGroups["Building"], hash, (unitID % 2)+3)

        for k, buildPiece in pairs (TablesOfPiecesGroups["Building"]) do
            xValue =((buildPiece + unitID) % 2) *hashSign(unitID * hash + buildPiece + k)
            zValue = ((k + unitID + xValue) % 2) * hashSign(unitID + buildPiece + xValue)
            ax,az= getGridPostion(xValue, zValue)
            if ax then
                Move(buildPiece, 1, ax * 900 ,0)
                Move(buildPiece, 3, az * 900 ,0)
            end
                Turn(buildPiece, 3, math.rad((unitID%9)*45),0)
        end
    else
        randShowHide(TablesOfPiecesGroups["Single"], hash, 1)    
    end

    defID = Spring.GetUnitDefID(unitID)
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
                Show(v)
                return v
        end
    end
end

-- > Counts the number of elements in a dictionary
function count(T)
    if not T then return 0 end
    local index = 0
    for k, v in pairs(T) do if v then index = index + 1 end end
    return index
end


function hideAll(id)
    if not unitID then unitID = id end

    pieceMap = Spring.GetUnitPieceMap(unitID)
    for k, v in pairs(pieceMap) do Hide(v) end
end



-- >Returns randomized Boolean
function maRa() return math.random(0, 1) == 1 end


function showOneOrAllPiece(T)
    if not T then return end
    
    if math.random(1,10) > 5 then
        return showOnePiece(T)
    else
        for num, val in pairs(T) do 
            Show(val)
        end
        return
    end
end

-- Spring.SetUnitNanoPieces(unitID, { center })
function getNameTooltipNotPlayableBuilding(hash)    
    index = math.floor((hash ) % 8) + 1
    name = "Building"
    description = "Inaccessible to non-citizens"

    if index == 1 then     
        reasons = {"Owner Missing", "mined during the permawars", "hedgehog invested", "Investment Scam",
         "Black market", "Crypto farm", "Money Laundering", "Under Construction", "Police Surveilance Outpost"}
        return "Sealed Block", reasons[math.floor((hash+math.random(1,#reasons))% #reasons)+1]
    end

    if index == 2 then
        name = "Vertical camp:"
        occupants = {"Refugee",  "Generational Contract Workers","Slave Slum", "Prison Block", "Squatters", "Tourist Hostel", "Animalfarm"}

        return name, occupants[math.floor((hash+math.random(1,#occupants)) % #occupants)+1].." Building"
    end

    if index == 3 then
        name = "Condemned for"
        plagues = {"Plague","Covid27", "H5N1",  "Runaway Nanotech","Ebola","HyperAmbrosia", 
        "Memetic Viruses", "Wetbulb AC failure", "flies, rats & bones", "Cyberrot", "Hostile CareTaker AI"}
        description = plagues[math.floor((hash+math.random(1,#plagues)) % #plagues)+1].." Building"
        return name, description
    end

    if index == 4 then
        local descriptions = { "Surveilance Embracing Community", "Sealed Crime Site", "BigBrother Inc", "Dilemma-Prison","Heat death camp", "Passportless Minwageworkers"}
        return "PanoptiCondos", descriptions[math.floor((hash+math.random(1,#descriptions)) % #descriptions)+1]
    end

    if index == 5 then
        local crimetypes= {"drug","slave", "weapons", "organs","drug", "cyber-ripping"}
        return "Crime Hotspot", "Location known for "..crimetypes[math.floor((hash+math.random(1,#crimetypes)) % #crimetypes)+1].." trade" 
    end

    if index == 6 then

            insanity = {
                "Graveyard", "Old MassGrave", "Mamas as mumies", "Warming Wars memorial", "InstaInfluenca-labourcamp",
                "Potemkin Building","Crumbling Building", "Ruin dangerous to inhabit", "Your-Advertisement-could-be-here",
              "Promotional Building", "Architect Skylineporn", "The Line", "Megalomania",
            "Invest Incest", "Derelict to keep the value", "Propertitty Pokerchips", "Monero Blockchain Endpoint"}

            inaninty = { "★★★★★ best place ever. Can recommend", "sponsored by [TODO_NAME]", "What comes next will shock you!", "Build your buisness today with us!", "agile blockchained NFT", "Cryto-Boolshit"}

        return insanity[math.floor(hash % #insanity)+1], inaninty[math.floor((hash+math.random(1,#inaninty)) % #inaninty)+1]
    end

    if index == 7  then
        cults ={
        "Scientology","Agapemonites","Alamo Christian Foundation","Anti-cult movement","Aleph ",
        "Kalki Bhagawan","Branch Davidians","Buddhafield ","The Circle of Friends","Adi Da",
        "Diehard Duterte Supporters","Doomsday cult","Élan School","The Family International",
        "The Finders ","Heaven's Gate ","Heterodox teachings ","Love Has Won","Manson Family",
        "Orgycult","Church of Malloc", "NXIVM","Order of the Solar Temple","Parliamentary Commission on Cults in France",
        "Pastel QAnon","Peoples Temple","QAnon","Rulaizong","Scientology","Brother Stair","Synanon",
        "Trinity Foundation (Dallas)", "Kalkbrennerkultisten","Greenwar",
        "Children of Elon", "Mr.Rogersendero Enclave", "Cooperate Dictatorship", "Mad Max Millenials", "Technotribalists",
        "Twelve Tribes communities","Universal Medicine","Zendik Farm", "Cool Aid Cult", "Beheriths Armed Rebellion", "Pagans", "Hammerites"
        }
        return "Radical Religous Community", cults[math.floor((hash+math.random(1,#cults)) % #cults)+1]
    end


    if index == 8 then
        corp= {"su","ku","yi","ka","ma","le","ro","to","mi"}
       generatedName= ""
       for i=1, math.random(2,7) do
        generatedName = generatedName..corp[math.random(1,#corp)]
       end

       generatedName = (generatedName:gsub("^%l", string.upper))
       status = {"defunct", "foreclosed", "bankrupt", "THRIVING - never been better", "★★★★★ best place ever. Can recommend",
                 "temporary closed due to riches"}
       return generatedName, "Limited Co. ["..status[math.floor(hash % #status)+1].."]"
    end

    return  name, description
end


function getUnitPieceByName(id, Name)
    pieceMap = Spring.GetUnitPieceMap(id)

    for name, number in pairs(pieceMap) do
        if name == Name then return number end
    end
end

function getUnitPieceVolume(unit, Piece)
    vx, vy, vz = Spring.GetUnitPieceCollisionVolumeD
    if vx then return math.abs(vx * vy * vz) end
    return 0
end

-- > finds GenericNames and Creates Tables with them
function getPieceTableByNameGroups(boolMakePiecesTable, boolSilent)
    Spring.SetUnitBlocking(unitID, false)
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
    StartThread(delayedSetup)
end