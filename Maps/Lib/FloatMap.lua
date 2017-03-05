include("Utils")
include("Constants")

-----------------------------------------------------------------------------
-- FloatMap class
-- This is for storing 2D map data. The 'data' field is a zero based, one
-- dimensional array. To access map data by x and y coordinates, use the
-- GetIndex method to obtain the 1D index, which will handle any needs for
-- wrapping in the x and y directions.
-----------------------------------------------------------------------------
FloatMap = inheritsFrom(nil)

function FloatMap:New(width, height, wrapX, wrapY)
    local new_inst = {}
    setmetatable(new_inst, {__index = FloatMap});	--setup metatable

    new_inst.width = width
    new_inst.height = height
    new_inst.wrapX = wrapX
    new_inst.wrapY = wrapY
    new_inst.length = width*height

    --These fields are used to access only a subset of the map
    --with the GetRectIndex function. This is useful for
    --making Perlin noise wrap without generating separate
    --noise fields for each octave
    new_inst.rectX = 0
    new_inst.rectY = 0
    new_inst.rectWidth = width
    new_inst.rectHeight = height

    new_inst.data = {}
    for i = 0,width*height - 1,1 do
        new_inst.data[i] = 0.0
    end

    return new_inst
end

function FloatMap:GetNeighbor(x,y,dir)
    local xx
    local yy
    local odd = y % 2
    if dir == Directions.NONE then
        return x,y
    elseif dir == Directions.WEST then
        xx = x - 1
        yy = y
        return xx,yy
    elseif dir == Directions.NORTH_WEST then
        xx = x - 1 + odd
        yy = y + 1
        return xx,yy
    elseif dir == Directions.NORHT_EAST then
        xx = x + odd
        yy = y + 1
        return xx,yy
    elseif dir == Directions.EAST then
        xx = x + 1
        yy = y
        return xx,yy
    elseif dir == Directions.SOUTH_EAST then
        xx = x + odd
        yy = y - 1
        return xx,yy
    elseif dir == Directions.SOUTH_WEST then
        xx = x - 1 + odd
        yy = y - 1
        return xx,yy
    else
        error("Bad direction in FloatMap:GetNeighbor")
    end
    return -1,-1
end

function FloatMap:GetIndex(x,y)
    local xx
    if self.wrapX then
        xx = x % self.width
    elseif x < 0 or x > self.width - 1 then
        return -1
    else
        xx = x
    end

    if self.wrapY then
        yy = y % self.height
    elseif y < 0 or y > self.height - 1 then
        return -1
    else
        yy = y
    end

    return yy * self.width + xx
end

function FloatMap:GetXYFromIndex(i)
    local x = i % self.width
    local y = (i - x)/self.width
    return x,y
end

--quadrants are labeled
--A B
--D C
function FloatMap:GetQuadrant(x,y)
    if x < self.width/2 then
        if y < self.height/2 then
            return "A"
        else
            return "D"
        end
    else
        if y < self.height/2 then
            return "B"
        else
            return "C"
        end
    end
end

--Gets an index for x and y based on the current
--rect settings. x and y are local to the defined rect.
--Wrapping is assumed in both directions
function FloatMap:GetRectIndex(x,y)
    local xx = x % self.rectWidth
    local yy = y % self.rectHeight

    xx = self.rectX + xx
    yy = self.rectY + yy

    return self:GetIndex(xx,yy)
end

function FloatMap:Normalize()
    --find highest and lowest values
    local maxAlt = -1000.0
    local minAlt = 1000.0
    for i = 0,self.length - 1,1 do
        local alt = self.data[i]
        if alt > maxAlt then
            maxAlt = alt
        end
        if alt < minAlt then
            minAlt = alt
        end

    end
    --subtract minAlt from all values so that
    --all values are zero and above
    for i = 0, self.length - 1, 1 do
        self.data[i] = self.data[i] - minAlt
    end

    --subract minAlt also from maxAlt
    maxAlt = maxAlt - minAlt

    --determine and apply scaler to whole map
    local scaler
    if maxAlt == 0.0 then
        scaler = 0.0
    else
        scaler = 1.0/maxAlt
    end

    for i = 0,self.length - 1,1 do
        self.data[i] = self.data[i] * scaler
    end

end

function FloatMap:GenerateNoise()
    for i = 0,self.length - 1,1 do
        self.data[i] = PWRand()
    end

end

function FloatMap:GenerateBinaryNoise()
    for i = 0,self.length - 1,1 do
        if PWRand() > 0.5 then
            self.data[i] = 1
        else
            self.data[i] = 0
        end
    end

end

function FloatMap:FindThresholdFromPercent(percent, greaterThan, excludeZeros)
    local mapList = {}
    local percentage = percent * 100

    if greaterThan then
        percentage = 100 - percentage
    end

    if percentage >= 100 then
        return 1.01 --whole map
    elseif percentage <= 0 then
        return -0.01 --none of the map
    end

    for i = 0,self.length - 1,1 do
        if not (self.data[i] == 0.0 and excludeZeros) then
            table.insert(mapList,self.data[i])
        end
    end

    table.sort(mapList, function (a,b) return a < b end)
    local threshIndex = math.floor((#mapList * percentage)/100)

    return mapList[threshIndex - 1]

end

function FloatMap:GetLatitudeForY(y)
    local range = g_TOP_LATITUDE - g_BOTTOM_LATITUDE
    return y / self.height * range + g_BOTTOM_LATITUDE
end

function FloatMap:GetYForLatitude(lat)
    local range = g_TOP_LATITUDE - g_BOTTOM_LATITUDE
    return math.floor(((lat - g_BOTTOM_LATITUDE) /range * self.height) + 0.5)
end

function FloatMap:GetZone(y)
    local lat = self:GetLatitudeForY(y)
    if y < 0 or y >= self.height then
        return WindZones.NOZONE
    end
    if lat > g_POLAR_FRONT_LATITUDE then
        return WindZones.NPOLAR
    elseif lat >= g_HORSE_LATITUDES then
        return WindZones.NTEMPERATE
    elseif lat >= 0.0 then
        return WindZones.NEQUATOR
    elseif lat > -g_HORSE_LATITUDES then
        return WindZones.SEQUATOR
    elseif lat >= -g_POLAR_FRONT_LATITUDE then
        return WindZones.STEMPERATE
    else
        return WindZones.SPOLAR
    end
end

function FloatMap:GetYFromZone(zone, bTop)
    if bTop then
        for y=self.height - 1,0,-1 do
            if zone == self:GetZone(y) then
                return y
            end
        end
    else
        for y=0,self.height - 1,1 do
            if zone == self:GetZone(y) then
                return y
            end
        end
    end
    return -1
end

function FloatMap:GetGeostrophicWindDirections(zone)

    if zone == WindZones.NPOLAR then
        return Directions.SOUTH_WEST, Directions.WEST
    elseif zone == WindZones.NTEMPERATE then
        return Directions.NORTH_EAST, Directions.EAST
    elseif zone == WindZones.NEQUATOR then
        return Directions.SOUTH_WEST, Directions.WEST
    elseif zone == WindZones.SEQUATOR then
        return Directions.NORTH_WEST, Directions.WEST
    elseif zone == WindZones.STEMPERATE then
        return Directions.SOUTH_EAST, Directions.EAST
    else
        return Directions.NORTH_WEST, Directions.WEST
    end
    return -1,-1
end

function FloatMap:GetGeostrophicPressure(lat)
    local latRange = nil
    local latPercent = nil
    local pressure = nil
    if lat > g_POLAR_FRONT_LATITUDE then
        latRange = 90.0 - g_POLAR_FRONT_LATITUDE
        latPercent = (lat - g_POLAR_FRONT_LATITUDE)/latRange
        pressure = 1.0 - latPercent
    elseif lat >= g_HORSE_LATITUDES then
        latRange = g_POLAR_FRONT_LATITUDE - g_HORSE_LATITUDES
        latPercent = (lat - g_HORSE_LATITUDES)/latRange
        pressure = latPercent
    elseif lat >= 0.0 then
        latRange = g_HORSE_LATITUDES - 0.0
        latPercent = (lat - 0.0)/latRange
        pressure = 1.0 - latPercent
    elseif lat > -g_HORSE_LATITUDES then
        latRange = 0.0 + g_HORSE_LATITUDES
        latPercent = (lat + g_HORSE_LATITUDES)/latRange
        pressure = latPercent
    elseif lat >= -g_POLAR_FRONT_LATITUDE then
        latRange = -g_HORSE_LATITUDES + g_POLAR_FRONT_LATITUDE
        latPercent = (lat + g_POLAR_FRONT_LATITUDE)/latRange
        pressure = 1.0 - latPercent
    else
        latRange = -g_POLAR_FRONT_LATITUDE + 90.0
        latPercent = (lat + 90)/latRange
        pressure = latPercent
    end
    --print(pressure)
    return pressure
end

function FloatMap:ApplyFunction(func)
    for i = 0,self.length - 1,1 do
        self.data[i] = func(self.data[i])
    end
end

function FloatMap:GetRadiusAroundHex(x,y,radius)
    local list = {}
    table.insert(list,{x,y})
    if radius == 0 then
        return list
    end

    local hereX = x
    local hereY = y

    --make a circle for each radius
    for r = 1,radius,1 do
        --start 1 to the west
        hereX,hereY = self:GetNeighbor(hereX,hereY,Directions.WEST)
        if self:IsOnMap(hereX,hereY) then
            table.insert(list,{hereX,hereY})
        end
        --Go r times to the NE
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.NORTH_EAST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the E
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.EAST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the SE
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.SOUTH_EAST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the SW
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.SOUTH_WEST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the W
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.WEST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r - 1 times to the NW!!!!!
        for z = 1,r - 1,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.NORTH_WEST)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --one extra NW to set up for next circle
        hereX, hereY = self:GetNeighbor(hereX,hereY,Directions.NORTH_WEST)
    end
    return list
end

function FloatMap:GetAverageInHex(x,y,radius)
    local list = self:GetRadiusAroundHex(x,y,radius)
    local avg = 0.0
    for n = 1,#list,1 do
        local hex = list[n]
        local xx = hex[1]
        local yy = hex[2]
        local i = self:GetIndex(xx,yy)
        avg = avg + self.data[i]
    end
    avg = avg/#list

    return avg
end

function FloatMap:GetStdDevInHex(x,y,radius)
    local list = self:GetRadiusAroundHex(x,y,radius)
    local avg = 0.0
    for n = 1,#list,1 do
        local hex = list[n]
        local xx = hex[1]
        local yy = hex[2]
        local i = self:GetIndex(xx,yy)
        avg = avg + self.data[i]
    end
    avg = avg/#list

    local deviation = 0.0
    for n = 1,#list,1 do
        local hex = list[n]
        local xx = hex[1]
        local yy = hex[2]
        local i = self:GetIndex(xx,yy)
        local sqr = self.data[i] - avg
        deviation = deviation + (sqr * sqr)
    end
    deviation = math.sqrt(deviation/ #list)
    return deviation
end

function FloatMap:Smooth(radius)
    local dataCopy = {}
    for y = 0,self.height - 1,1 do
        for x = 0, self.width - 1,1 do
            local i = self:GetIndex(x,y)
            dataCopy[i] = self:GetAverageInHex(x,y,radius)
        end
    end
    self.data = dataCopy
end

function FloatMap:Deviate(radius)
    local dataCopy = {}
    for y = 0,self.height - 1,1 do
        for x = 0, self.width - 1,1 do
            local i = self:GetIndex(x,y)
            dataCopy[i] = self:GetStdDevInHex(x,y,radius)
        end
    end
    self.data = dataCopy
end

function FloatMap:IsOnMap(x,y)
    local i = self:GetIndex(x,y)
    if i == -1 then
        return false
    end
    return true
end

function FloatMap:Save(name)
    print("saving " .. name .. "...")
    local str = self.width .. "," .. self.height
    for i = 0,self.length - 1,1 do
        str = str .. "," .. self.data[i]
    end
    local file = io.open(name,"w+")
    file:write(str)
    file:close()
    print("bitmap saved as " .. name .. ".")
end

