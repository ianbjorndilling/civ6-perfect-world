include("Utils")
include("Constants")

-------------------------------------------------------------------------
--RiverMap class
-------------------------------------------------------------------------
RiverMap = inheritsFrom(nil)

function RiverMap:New(elevationMap)
    local new_inst = {}
    setmetatable(new_inst, {__index = RiverMap});

    new_inst.elevationMap = elevationMap
    new_inst.riverData = {}
    for y = 0,new_inst.elevationMap.height - 1,1 do
        for x = 0,new_inst.elevationMap.width - 1,1 do
            local i = new_inst.elevationMap:GetIndex(x,y)
            new_inst.riverData[i] = RiverHex:New(x,y)
        end
    end

    return new_inst
end

function RiverMap:GetJunction(x,y,isNorth)
    local i = self.elevationMap:GetIndex(x,y)
    if isNorth then
        return self.riverData[i].northJunction
    else
        return self.riverData[i].southJunction
    end
end

function RiverMap:GetJunctionNeighbor(direction,junction)
    local xx = nil
    local yy = nil
    local ii = nil
    local neighbor = nil
    local odd = junction.y % 2
    if direction == FlowDirections.NOFLOW then
        error("can't get junction neighbor in direction NOFLOW")
    elseif direction == FlowDirections.WESTFLOW then
        xx = junction.x + odd - 1
        if junction.isNorth then
            yy = junction.y + 1
        else
            yy = junction.y - 1
        end
        ii = self.elevationMap:GetIndex(xx,yy)
        if ii ~= -1 then
            neighbor = self:GetJunction(xx,yy,not junction.isNorth)
            return neighbor
        end
    elseif direction == FlowDirections.EASTFLOW then
        xx = junction.x + odd
        if junction.isNorth then
            yy = junction.y + 1
        else
            yy = junction.y - 1
        end
        ii = self.elevationMap:GetIndex(xx,yy)
        if ii ~= -1 then
            neighbor = self:GetJunction(xx,yy,not junction.isNorth)
            return neighbor
        end
    elseif direction == FlowDirections.VERTFLOW then
        xx = junction.x
        if junction.isNorth then
            yy = junction.y + 2
        else
            yy = junction.y - 2
        end
        ii = self.elevationMap:GetIndex(xx,yy)
        if ii ~= -1 then
            neighbor = self:GetJunction(xx,yy,not junction.isNorth)
            return neighbor
        end
    end

    return nil --neighbor off map
end

--Get the west or east hex neighboring this junction
function RiverMap:GetRiverHexNeighbor(junction,westNeighbor)
    local xx = nil
    local yy = nil
    local ii = nil
    local odd = junction.y % 2
    if junction.isNorth then
        yy = junction.y + 1
    else
        yy = junction.y - 1
    end
    if westNeighbor then
        xx = junction.x + odd - 1
    else
        xx = junction.x + odd
    end

    ii = self.elevationMap:GetIndex(xx,yy)
    if ii ~= -1 then
        return self.riverData[ii]
    end

    return nil
end

function RiverMap:SetJunctionAltitudes()
    for y = 0,self.elevationMap.height - 1,1 do
        for x = 0,self.elevationMap.width - 1,1 do
            local i = self.elevationMap:GetIndex(x,y)
            local vertAltitude = self.elevationMap.data[i]
            local westAltitude = nil
            local eastAltitude = nil
            local vertNeighbor = self.riverData[i]
            local westNeighbor = nil
            local eastNeighbor = nil
            local xx = nil
            local yy = nil
            local ii = nil

            --first do north
            westNeighbor = self:GetRiverHexNeighbor(vertNeighbor.northJunction,true)
            eastNeighbor = self:GetRiverHexNeighbor(vertNeighbor.northJunction,false)

            if westNeighbor ~= nil then
                ii = self.elevationMap:GetIndex(westNeighbor.x,westNeighbor.y)
            else
                ii = -1
            end

            if ii ~= -1 then
                westAltitude = self.elevationMap.data[ii]
            else
                westAltitude = vertAltitude
            end

            if eastNeighbor ~= nil then
                ii = self.elevationMap:GetIndex(eastNeighbor.x, eastNeighbor.y)
            else
                ii = -1
            end

            if ii ~= -1 then
                eastAltitude = self.elevationMap.data[ii]
            else
                eastAltitude = vertAltitude
            end

            vertNeighbor.northJunction.altitude = math.min(math.min(vertAltitude,westAltitude),eastAltitude)

            --then south
            westNeighbor = self:GetRiverHexNeighbor(vertNeighbor.southJunction,true)
            eastNeighbor = self:GetRiverHexNeighbor(vertNeighbor.southJunction,false)

            if westNeighbor ~= nil then
                ii = self.elevationMap:GetIndex(westNeighbor.x,westNeighbor.y)
            else
                ii = -1
            end

            if ii ~= -1 then
                westAltitude = self.elevationMap.data[ii]
            else
                westAltitude = vertAltitude
            end

            if eastNeighbor ~= nil then
                ii = self.elevationMap:GetIndex(eastNeighbor.x, eastNeighbor.y)
            else
                ii = -1
            end

            if ii ~= -1 then
                eastAltitude = self.elevationMap.data[ii]
            else
                eastAltitude = vertAltitude
            end

            vertNeighbor.southJunction.altitude = math.min(math.min(vertAltitude,westAltitude),eastAltitude)
        end
    end
end

function RiverMap:isLake(junction)

    --first exclude the map edges that don't have neighbors
    if junction.y == 0 and junction.isNorth == false then
        return false
    elseif junction.y == self.elevationMap.height - 1 and junction.isNorth == true then
        return false
    end

    --exclude altitudes below sea level
    if junction.altitude < self.elevationMap.seaLevelThreshold then
        return false
    end

    --print(string.format("junction = (%d,%d) N = %s, alt = %f",junction.x,junction.y,tostring(junction.isNorth),junction.altitude))

    local vertNeighbor = self:GetJunctionNeighbor(FlowDirections.VERTFLOW,junction)
    local vertAltitude = nil
    if vertNeighbor == nil then
        vertAltitude = junction.altitude
        --print("--vertNeighbor == nil")
    else
        vertAltitude = vertNeighbor.altitude
        --print(string.format("--vertNeighbor = (%d,%d) N = %s, alt = %f",vertNeighbor.x,vertNeighbor.y,tostring(vertNeighbor.isNorth),vertNeighbor.altitude))
    end

    local westNeighbor = self:GetJunctionNeighbor(FlowDirections.WESTFLOW,junction)
    local westAltitude = nil
    if westNeighbor == nil then
        westAltitude = junction.altitude
        --print("--westNeighbor == nil")
    else
        westAltitude = westNeighbor.altitude
        --print(string.format("--westNeighbor = (%d,%d) N = %s, alt = %f",westNeighbor.x,westNeighbor.y,tostring(westNeighbor.isNorth),westNeighbor.altitude))
    end

    local eastNeighbor = self:GetJunctionNeighbor(FlowDirections.EASTFLOW,junction)
    local eastAltitude = nil
    if eastNeighbor == nil then
        eastAltitude = junction.altitude
        --print("--eastNeighbor == nil")
    else
        eastAltitude = eastNeighbor.altitude
        --print(string.format("--eastNeighbor = (%d,%d) N = %s, alt = %f",eastNeighbor.x,eastNeighbor.y,tostring(eastNeighbor.isNorth),eastNeighbor.altitude))
    end

    local lowest = math.min(vertAltitude,math.min(westAltitude,math.min(eastAltitude,junction.altitude)))

    if lowest == junction.altitude then
        --print("--is lake")
        return true
    end
    --print("--is not lake")
    return false
end

--get the average altitude of the two lowest neighbors that are higher than
--the junction altitude.
function RiverMap:GetLowerNeighborAverage(junction)
    local vertNeighbor = self:GetJunctionNeighbor(FlowDirections.VERTFLOW,junction)
    local vertAltitude = nil
    if vertNeighbor == nil then
        vertAltitude = junction.altitude
    else
        vertAltitude = vertNeighbor.altitude
    end

    local westNeighbor = self:GetJunctionNeighbor(FlowDirections.WESTFLOW,junction)
    local westAltitude = nil
    if westNeighbor == nil then
        westAltitude = junction.altitude
    else
        westAltitude = westNeighbor.altitude
    end

    local eastNeighbor = self:GetJunctionNeighbor(FlowDirections.EASTFLOW,junction)
    local eastAltitude = nil
    if eastNeighbor == nil then
        eastAltitude = junction.altitude
    else
        eastAltitude = eastNeighbor.altitude
    end

    local nList = {vertAltitude,westAltitude,eastAltitude}
    table.sort(nList)
    local avg = nil
    if nList[1] > junction.altitude then
        avg = (nList[1] + nList[2])/2.0
    elseif nList[2] > junction.altitude then
        avg = (nList[2] + nList[3])/2.0
    elseif nList[3] > junction.altitude then
        avg = (nList[3] + junction.altitude)/2.0
    else
        avg = junction.altitude --all neighbors are the same height. Dealt with later
    end
    return avg
end

--this function alters the drainage pattern
function RiverMap:SiltifyLakes()
    local lakeList = {}
    local onQueueMapNorth = {}
    local onQueueMapSouth = {}
    for y = 0,self.elevationMap.height - 1,1 do
        for x = 0,self.elevationMap.width - 1,1 do
            local i = self.elevationMap:GetIndex(x,y)
            onQueueMapNorth[i] = false
            onQueueMapSouth[i] = false
            if self:isLake(self.riverData[i].northJunction) then
                Push(lakeList,self.riverData[i].northJunction)
                onQueueMapNorth[i] = true
            end
            if self:isLake(self.riverData[i].southJunction) then
                Push(lakeList,self.riverData[i].southJunction)
                onQueueMapSouth[i] = true
            end
        end
    end

    local longestLakeList = #lakeList
    local shortestLakeList = #lakeList
    local iterations = 0
    local debugOn = false
    --print(string.format("initial lake count = %d",longestLakeList))
    while #lakeList > 0 do
        --print(string.format("length of lakeList = %d",#lakeList))
        iterations = iterations + 1
        if #lakeList > longestLakeList then
            longestLakeList = #lakeList
        end

        if #lakeList < shortestLakeList then
            shortestLakeList = #lakeList
            --print(string.format("shortest lake list = %d, iterations = %d",shortestLakeList,iterations))
            iterations = 0
        end

        if iterations > 1000000 then
            debugOn = true
        end

        if iterations > 1001000 then
            error("endless loop in lake siltification. check logs")
        end

        local junction = Pop(lakeList)
        local i = self.elevationMap:GetIndex(junction.x,junction.y)
        if junction.isNorth then
            onQueueMapNorth[i] = false
        else
            onQueueMapSouth[i] = false
        end

        if debugOn then
            print(string.format("processing (%d,%d) N=%s alt=%f",junction.x,junction.y,tostring(junction.isNorth),junction.altitude))
        end

        local avgLowest = self:GetLowerNeighborAverage(junction)

        if debugOn then
            print(string.format("--avgLowest == %f",avgLowest))
        end

        if avgLowest < junction.altitude + 0.005 then --cant use == in fp comparison
            junction.altitude = avgLowest + 0.005
            if debugOn then
                print("--adding 0.005 to avgLowest")
            end
        else
            junction.altitude = avgLowest
        end

        if debugOn then
            print(string.format("--changing altitude to %f",junction.altitude))
        end

        for dir = FlowDirections.WESTFLOW,FlowDirections.VERTFLOW,1 do
            local neighbor = self:GetJunctionNeighbor(dir,junction)
            if debugOn and neighbor == nil then
                print(string.format("--nil neighbor at direction = %d",dir))
            end
            if neighbor ~= nil and self:isLake(neighbor) then
                local i = self.elevationMap:GetIndex(neighbor.x,neighbor.y)
                if neighbor.isNorth == true and onQueueMapNorth[i] == false then
                    Push(lakeList,neighbor)
                    onQueueMapNorth[i] = true
                    if debugOn then
                        print(string.format("--pushing (%d,%d) N=%s alt=%f",neighbor.x,neighbor.y,tostring(neighbor.isNorth),neighbor.altitude))
                    end
                elseif neighbor.isNorth == false and onQueueMapSouth[i] == false then
                    Push(lakeList,neighbor)
                    onQueueMapSouth[i] = true
                    if debugOn then
                        print(string.format("--pushing (%d,%d) N=%s alt=%f",neighbor.x,neighbor.y,tostring(neighbor.isNorth),neighbor.altitude))
                    end
                end
            end
        end
    end
    --print(string.format("longestLakeList = %d",longestLakeList))

    --print(string.format("sea level = %f",self.elevationMap.seaLevelThreshold))

    local belowSeaLevelCount = 0
    local riverTest = FloatMap:New(self.elevationMap.width,self.elevationMap.height,self.elevationMap.xWrap,self.elevationMap.yWrap)
    local lakesFound = false
    for y = 0,self.elevationMap.height - 1,1 do
        for x = 0,self.elevationMap.width - 1,1 do
            local i = self.elevationMap:GetIndex(x,y)

            local northAltitude = self.riverData[i].northJunction.altitude
            local southAltitude = self.riverData[i].southJunction.altitude
            if northAltitude < self.elevationMap.seaLevelThreshold then
                belowSeaLevelCount = belowSeaLevelCount + 1
            end
            if southAltitude < self.elevationMap.seaLevelThreshold then
                belowSeaLevelCount = belowSeaLevelCount + 1
            end
            riverTest.data[i] = (northAltitude + southAltitude)/2.0

            if self:isLake(self.riverData[i].northJunction) then
                local junction = self.riverData[i].northJunction
                print(string.format("lake found at (%d, %d) isNorth = %s, altitude = %f!",junction.x,junction.y,tostring(junction.isNorth),junction.altitude))
                riverTest.data[i] = 1.0
                lakesFound = true
            end
            if self:isLake(self.riverData[i].southJunction) then
                local junction = self.riverData[i].southJunction
                print(string.format("lake found at (%d, %d) isNorth = %s, altitude = %f!",junction.x,junction.y,tostring(junction.isNorth),junction.altitude))
                riverTest.data[i] = 1.0
                lakesFound = true
            end
        end
    end

    if lakesFound then
        error("Failed to siltify lakes. check logs")
    end
    --riverTest:Normalize()
    --	riverTest:Save("riverTest.csv")
end

function RiverMap:SetFlowDestinations()
    junctionList = {}
    for y = 0,self.elevationMap.height - 1,1 do
        for x = 0,self.elevationMap.width - 1,1 do
            local i = self.elevationMap:GetIndex(x,y)
            table.insert(junctionList,self.riverData[i].northJunction)
            table.insert(junctionList,self.riverData[i].southJunction)
        end
    end

    table.sort(junctionList,function (a,b) return a.altitude > b.altitude end)

    for n=1,#junctionList do
        local junction = junctionList[n]
        local validList = self:GetValidFlows(junction)
        if #validList > 0 then
            local choice = PWRandint(1,#validList)
            junction.flow = validList[choice]
        else
            junction.flow = FlowDirections.NOFLOW
        end
    end
end

function RiverMap:GetValidFlows(junction)
    local validList = {}
    for dir = FlowDirections.WESTFLOW,FlowDirections.VERTFLOW,1 do
        neighbor = self:GetJunctionNeighbor(dir,junction)
        if neighbor ~= nil and neighbor.altitude < junction.altitude then
            table.insert(validList,dir)
        end
    end
    return validList
end

function RiverMap:IsTouchingOcean(junction)

    if elevationMap:IsBelowSeaLevel(junction.x,junction.y) then
        return true
    end
    local westNeighbor = self:GetRiverHexNeighbor(junction,true)
    local eastNeighbor = self:GetRiverHexNeighbor(junction,false)

    if westNeighbor == nil or elevationMap:IsBelowSeaLevel(westNeighbor.x,westNeighbor.y) then
        return true
    end
    if eastNeighbor == nil or elevationMap:IsBelowSeaLevel(eastNeighbor.x,eastNeighbor.y) then
        return true
    end
    return false
end

function RiverMap:SetRiverSizes(rainfallMap)
    local junctionList = {} --only include junctions not touching ocean in this list
    for y = 0,self.elevationMap.height - 1,1 do
        for x = 0,self.elevationMap.width - 1,1 do
            local i = self.elevationMap:GetIndex(x,y)
            if not self:IsTouchingOcean(self.riverData[i].northJunction) then
                table.insert(junctionList,self.riverData[i].northJunction)
            end
            if not self:IsTouchingOcean(self.riverData[i].southJunction) then
                table.insert(junctionList,self.riverData[i].southJunction)
            end
        end
    end

    table.sort(junctionList,function (a,b) return a.altitude > b.altitude end)

    for n=1,#junctionList do
        local junction = junctionList[n]
        local nextJunction = junction
        local i = self.elevationMap:GetIndex(junction.x,junction.y)
        while true do
            nextJunction.size = (nextJunction.size + rainfallMap.data[i]) * g_RIVER_RAIN_CHEAT_FACTOR
            if nextJunction.flow == FlowDirections.NOFLOW or self:IsTouchingOcean(nextJunction) then
                nextJunction.size = 0.0
                break
            end
            nextJunction = self:GetJunctionNeighbor(nextJunction.flow,nextJunction)
        end
    end

    --now sort by river size to find river threshold
    table.sort(junctionList,function (a,b) return a.size > b.size end)
    local riverIndex = math.floor(g_RIVER_PERCENT * #junctionList)
    self.riverThreshold = junctionList[riverIndex].size
    print(string.format("river threshold = %f",self.riverThreshold))

    --~ 	local riverMap = FloatMap:New(self.elevationMap.width,self.elevationMap.height,self.elevationMap.xWrap,self.elevationMap.yWrap)
    --~ 	for y = 0,self.elevationMap.height - 1,1 do
    --~ 		for x = 0,self.elevationMap.width - 1,1 do
    --~ 			local i = self.elevationMap:GetIndex(x,y)
    --~ 			riverMap.data[i] = math.max(self.riverData[i].northJunction.size,self.riverData[i].southJunction.size)
    --~ 		end
    --~ 	end
    --~ 	riverMap:Normalize()
    --riverMap:Save("riverSizeMap.csv")
end

--This function returns the flow directions needed by civ
function RiverMap:GetFlowDirections(x,y)
    --print(string.format("Get flow dirs for %d,%d",x,y))
    local i = elevationMap:GetIndex(x,y)

    local WOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
    local xx,yy = elevationMap:GetNeighbor(x,y,Directions.NORTH_EAST
    local ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].southJunction.flow == FlowDirections.VERTFLOW and self.riverData[ii].southJunction.size > self.riverThreshold then
        --print(string.format("--NE(%d,%d) south flow=%d, size=%f",xx,yy,self.riverData[ii].southJunction.flow,self.riverData[ii].southJunction.size))
        WOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTH
    end
    xx,yy = elevationMap:GetNeighbor(x,y,Directions.SOUTH_EAST)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == FlowDirections.VERTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        --print(string.format("--SE(%d,%d) north flow=%d, size=%f",xx,yy,self.riverData[ii].northJunction.flow,self.riverData[ii].northJunction.size))
        WOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTH
    end

    local NWOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
    xx,yy = elevationMap:GetNeighbor(x,y,Directions.SOUTH_EAST)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == FlowDirections.WESTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST
    end
    if self.riverData[i].southJunction.flow == FlowDirections.EASTFLOW and self.riverData[i].southJunction.size > self.riverThreshold then
        NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST
    end

    local NEOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
    xx,yy = elevationMap:GetNeighbor(x,y,Directions.SOUTH_WEST)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == FlowDirections.EASTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        NEOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST
    end
    if self.riverData[i].southJunction.flow == FlowDirections.WESTFLOW and self.riverData[i].southJunction.size > self.riverThreshold then
        NEOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST
    end

    return WOfRiver,NWOfRiver,NEOfRiver
end
-------------------------------------------------------------------------
--RiverHex class
-------------------------------------------------------------------------
RiverHex = inheritsFrom(nil)

function RiverHex:New(x, y)
    local new_inst = {}
    setmetatable(new_inst, {__index = RiverHex});

    new_inst.x = x
    new_inst.y = y
    new_inst.northJunction = RiverJunction:New(x,y,true)
    new_inst.southJunction = RiverJunction:New(x,y,false)

    return new_inst
end

-------------------------------------------------------------------------
--RiverHex class
-------------------------------------------------------------------------
RiverHex = inheritsFrom(nil)

function RiverHex:New(x, y)
    local new_inst = {}
    setmetatable(new_inst, {__index = RiverHex});

    new_inst.x = x
    new_inst.y = y
    new_inst.northJunction = RiverJunction:New(x,y,true)
    new_inst.southJunction = RiverJunction:New(x,y,false)

    return new_inst
end

-------------------------------------------------------------------------
--RiverJunction class
-------------------------------------------------------------------------
RiverJunction = inheritsFrom(nil)

function RiverJunction:New(x,y,isNorth)
    local new_inst = {}
    setmetatable(new_inst, {__index = RiverJunction});

    new_inst.x = x
    new_inst.y = y
    new_inst.isNorth = isNorth
    new_inst.altitude = 0.0
    new_inst.flow = FlowDirections.NOFLOW
    new_inst.size = 0.0

    return new_inst
end
