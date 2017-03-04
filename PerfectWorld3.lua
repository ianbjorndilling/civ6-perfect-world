--------------------------------------------------------------------------------
--PerfectWorld3.lua map script (c)2010 Rich Marinaccio
--version 4
--------------------------------------------------------------------------------
--This map script uses various manipulations of Perlin noise to create
--landforms, and generates climate based on a simplified model of geostrophic
--and monsoon wind patterns. Rivers are generated along accurate drainage paths
--governed by the elevation map used to create the landforms.
--
--Version History
--4 - A working version of v3
--
--3 - Placed Atolls. Shrank the huge map size based on advice from Sirian.
--
--2 - Shrank the map sizes except for huge. Added a better way to adjust river
--lengths. Used the continent art styles in a more diverse way. Cleaned up the
--mountain ranges a bit.
--
--1 - initial release! 11/24/2010

include("MapEnums");
include("MapUtilities");
include("AssignStartingPlots")
include("ResourceGenerator")
include("NaturalWonderGenerator")
include("MountainsCliffs");

MapConstants = {}

function MapConstants:New()
    local mconst = {}
    setmetatable(mconst, self)
    self.__index = self

    --Percent of land tiles on the map.
    mconst.landPercent = 0.28

    --Percent of dry land that is below the hill elevation deviance threshold.
    mconst.hillsPercent = 0.50

    --Percent of dry land that is below the mountain elevation deviance
    --threshold.
    mconst.mountainsPercent = 0.85

    --Percent of land that is below the desert rainfall threshold.
    mconst.desertPercent = 0.36
    --Coldest absolute temperature allowed to be desert, plains if colder.
    mconst.desertMinTemperature = 0.34

    --Percent of land that is below the plains rainfall threshold.
    mconst.plainsPercent = 0.56

    --Percent of land that is below the rainfall threshold where no trees
    --can appear.
    mconst.zeroTreesPercent = 0.30
    --Coldest absolute temperature where trees appear.
    mconst.treesMinTemperature = 0.27

    --Percent of land below the jungle rainfall threshold.
    mconst.junglePercent = 0.75
    --Coldest absolute temperature allowed to be jungle, forest if colder.
    mconst.jungleMinTemperature = 0.70

    --Percent of land below the marsh rainfall threshold.
    mconst.marshPercent = 0.92

    --Absolute temperature below which is snow.
    mconst.snowTemperature = 0.25

    --Absolute temperature below which is tundra.
    mconst.tundraTemperature = 0.30

    --North and south ice latitude limits.
    mconst.iceNorthLatitudeLimit = 60
    mconst.iceSouthLatitudeLimit = -60

    --North and south atoll latitude limits.
    mconst.atollNorthLatitudeLimit = 20
    mconst.atollSouthLatitudeLimit = -20
    mconst.atollMinDeepWaterNeighbors = 4

    --percent of river junctions that are large enough to become rivers.
    mconst.riverPercent = 0.19

    --This value is multiplied by each river step. Values greater than one favor
    --watershed size. Values less than one favor actual rain amount.
    mconst.riverRainCheatFactor = 1.6

    --These attenuation factors lower the altitude of the map edges. This is
    --currently used to prevent large continents in the uninhabitable polar
    --regions. East/west attenuation is set to zero, but modded maps may
    --have need for them.
    mconst.northAttenuationFactor = 0.75
    mconst.northAttenuationRange = 0.15 --percent of the map height.
    mconst.southAttenuationFactor = 0.75
    mconst.southAttenuationRange = 0.15

    --east west attenuation may be desired for flat maps.
    mconst.eastAttenuationFactor = 0.0
    mconst.eastAttenuationRange = 0.0 --percent of the map width.
    mconst.westAttenuationFactor = 0.0
    mconst.westAttenuationRange = 0.0

    --These set the water temperature compression that creates the land/sea
    --seasonal temperature differences that cause monsoon winds.
    mconst.minWaterTemp = 0.10
    mconst.maxWaterTemp = 0.60

    --Top and bottom map latitudes.
    mconst.topLatitude = 70
    mconst.bottomLatitude = -70

    --Important latitude markers used for generating climate.
    mconst.polarFrontLatitude = 60
    mconst.tropicLatitudes = 23
    mconst.horseLatitudes = 28 -- I shrunk these a bit to emphasize temperate lattitudes

    --Strength of geostrophic climate generation versus monsoon climate
    --generation.
    mconst.geostrophicFactor = 3.0

    mconst.geostrophicLateralWindStrength = 0.6

    --Fill in any lakes smaller than this. It looks bad to have large
    --river systems flowing into a tiny lake.
    mconst.minOceanSize = 50

    --Weight of the mountain elevation map versus the coastline elevation map.
    mconst.mountainWeight = 0.8

    --Crazy rain tweaking variables. I wouldn't touch these if I were you.
    mconst.minimumRainCost = 0.0001
    mconst.upLiftExponent = 4
    mconst.polarRainBoost = 0.00

    --default frequencies for map of width 128. Adjusting these frequences
    --will generate larger or smaller map features.
    mconst.twistMinFreq = 0.02
    mconst.twistMaxFreq = 0.12
    mconst.twistVar = 0.042
    mconst.mountainFreq = 0.078

    --mconst.useCivRands = true --not ready for this yet

    -----------------------------------------------------------------------
    --Below are map constants that should not be altered.

    --directions
    mconst.C = 0
    mconst.W = 1
    mconst.NW = 2
    mconst.NE = 3
    mconst.E = 4
    mconst.SE = 5
    mconst.SW = 6

    --flow directions
    mconst.NOFLOW = 0
    mconst.WESTFLOW = 1
    mconst.EASTFLOW = 2
    mconst.VERTFLOW = 3

    --wind zones
    mconst.NOZONE = -1
    mconst.NPOLAR = 0
    mconst.NTEMPERATE = 1
    mconst.NEQUATOR = 2
    mconst.SEQUATOR = 3
    mconst.STEMPERATE = 4
    mconst.SPOLAR = 5

    --Hex maps are shorter in the y direction than they are
    --wide per unit by this much. We need to know this to sample the perlin
    --maps properly so they don't look squished.
    mconst.YtoXRatio = 1.5/(math.sqrt(0.75) * 2)

    return mconst
end

function MapConstants:GetOppositeDir(dir)
    return ((dir + 2) % 6) + 1
end

--Returns a value along a bell curve from a 0 - 1 range
function MapConstants:GetBellCurve(value)
    return math.sin(value * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5
end

-----------------------------------------------------------------------------
--Interpolation and Perlin functions
-----------------------------------------------------------------------------
function CubicInterpolate(v0,v1,v2,v3,mu)
    local mu2 = mu * mu
    local a0 = v3 - v2 - v0 + v1
    local a1 = v0 - v1 - a0
    local a2 = v2 - v0
    local a3 = v1

    return (a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3)
end

function BicubicInterpolate(v,muX,muY)
    local a0 = CubicInterpolate(v[1],v[2],v[3],v[4],muX);
    local a1 = CubicInterpolate(v[5],v[6],v[7],v[8],muX);
    local a2 = CubicInterpolate(v[9],v[10],v[11],v[12],muX);
    local a3 = CubicInterpolate(v[13],v[14],v[15],v[16],muX);

    return CubicInterpolate(a0,a1,a2,a3,muY)
end

function CubicDerivative(v0,v1,v2,v3,mu)
    local mu2 = mu * mu
    local a0 = v3 - v2 - v0 + v1
    local a1 = v0 - v1 - a0
    local a2 = v2 - v0
    --local a3 = v1

    return (3 * a0 * mu2 + 2 * a1 * mu + a2)
end

function BicubicDerivative(v,muX,muY)
    local a0 = CubicInterpolate(v[1],v[2],v[3],v[4],muX);
    local a1 = CubicInterpolate(v[5],v[6],v[7],v[8],muX);
    local a2 = CubicInterpolate(v[9],v[10],v[11],v[12],muX);
    local a3 = CubicInterpolate(v[13],v[14],v[15],v[16],muX);

    return CubicDerivative(a0,a1,a2,a3,muY)
end

--This function gets a smoothly interpolated value from srcMap.
--x and y are non-integer coordinates of where the value is to
--be calculated, and wrap in both directions. srcMap is an object
--of type FloatMap.
function GetInterpolatedValue(X,Y,srcMap)
    local points = {}
    local fractionX = X - math.floor(X)
    local fractionY = Y - math.floor(Y)

    --wrappedX and wrappedY are set to -1,-1 of the sampled area
    --so that the sample area is in the middle quad of the 4x4 grid
    local wrappedX = ((math.floor(X) - 1) % srcMap.rectWidth) + srcMap.rectX
    local wrappedY = ((math.floor(Y) - 1) % srcMap.rectHeight) + srcMap.rectY

    local x
    local y

    for pY = 0, 4-1,1 do
        y = pY + wrappedY
        for pX = 0,4-1,1 do
            x = pX + wrappedX
            local srcIndex = srcMap:GetRectIndex(x, y)
            points[(pY * 4 + pX) + 1] = srcMap.data[srcIndex]
        end
    end

    local finalValue = BicubicInterpolate(points,fractionX,fractionY)

    return finalValue

end

function GetDerivativeValue(X,Y,srcMap)
    local points = {}
    local fractionX = X - math.floor(X)
    local fractionY = Y - math.floor(Y)

    --wrappedX and wrappedY are set to -1,-1 of the sampled area
    --so that the sample area is in the middle quad of the 4x4 grid
    local wrappedX = ((math.floor(X) - 1) % srcMap.rectWidth) + srcMap.rectX
    local wrappedY = ((math.floor(Y) - 1) % srcMap.rectHeight) + srcMap.rectY

    local x
    local y

    for pY = 0, 4-1,1 do
        y = pY + wrappedY
        for pX = 0,4-1,1 do
            x = pX + wrappedX
            local srcIndex = srcMap:GetRectIndex(x, y)
            points[(pY * 4 + pX) + 1] = srcMap.data[srcIndex]
        end
    end

    local finalValue = BicubicDerivative(points,fractionX,fractionY)

    return finalValue

end

--This function gets Perlin noise for the destination coordinates. Note
--that in order for the noise to wrap, the area sampled on the noise map
--must change to fit each octave.
function GetPerlinNoise(x,y,destMapWidth,destMapHeight,initialFrequency,initialAmplitude,amplitudeChange,octaves,noiseMap)
    local finalValue = 0.0
    local frequency = initialFrequency
    local amplitude = initialAmplitude
    local frequencyX --slight adjustment for seamless wrapping
    local frequencyY --''
    for i = 1,octaves,1 do
        if noiseMap.wrapX then
            noiseMap.rectX = math.floor(noiseMap.width/2 - (destMapWidth * frequency)/2)
            noiseMap.rectWidth = math.max(math.floor(destMapWidth * frequency),1)
            frequencyX = noiseMap.rectWidth/destMapWidth
        else
            noiseMap.rectX = 0
            noiseMap.rectWidth = noiseMap.width
            frequencyX = frequency
        end
        if noiseMap.wrapY then
            noiseMap.rectY = math.floor(noiseMap.height/2 - (destMapHeight * frequency)/2)
            noiseMap.rectHeight = math.max(math.floor(destMapHeight * frequency),1)
            frequencyY = noiseMap.rectHeight/destMapHeight
        else
            noiseMap.rectY = 0
            noiseMap.rectHeight = noiseMap.height
            frequencyY = frequency
        end

        finalValue = finalValue + GetInterpolatedValue(x * frequencyX, y * frequencyY, noiseMap) * amplitude
        frequency = frequency * 2.0
        amplitude = amplitude * amplitudeChange
    end
    finalValue = finalValue/octaves
    return finalValue
end

function GetPerlinDerivative(x,y,destMapWidth,destMapHeight,initialFrequency,initialAmplitude,amplitudeChange,octaves,noiseMap)
    local finalValue = 0.0
    local frequency = initialFrequency
    local amplitude = initialAmplitude
    local frequencyX --slight adjustment for seamless wrapping
    local frequencyY --''
    for i = 1,octaves,1 do
        if noiseMap.wrapX then
            noiseMap.rectX = math.floor(noiseMap.width/2 - (destMapWidth * frequency)/2)
            noiseMap.rectWidth = math.floor(destMapWidth * frequency)
            frequencyX = noiseMap.rectWidth/destMapWidth
        else
            noiseMap.rectX = 0
            noiseMap.rectWidth = noiseMap.width
            frequencyX = frequency
        end
        if noiseMap.wrapY then
            noiseMap.rectY = math.floor(noiseMap.height/2 - (destMapHeight * frequency)/2)
            noiseMap.rectHeight = math.floor(destMapHeight * frequency)
            frequencyY = noiseMap.rectHeight/destMapHeight
        else
            noiseMap.rectY = 0
            noiseMap.rectHeight = noiseMap.height
            frequencyY = frequency
        end

        finalValue = finalValue + GetDerivativeValue(x * frequencyX, y * frequencyY, noiseMap) * amplitude
        frequency = frequency * 2.0
        amplitude = amplitude * amplitudeChange
    end
    finalValue = finalValue/octaves
    return finalValue
end

function Push(a,item)
    table.insert(a,item)
end

function Pop(a)
    return table.remove(a)
end
------------------------------------------------------------------------
--inheritance mechanism from http://www.gamedev.net/community/forums/topic.asp?topic_id=561909
------------------------------------------------------------------------
function inheritsFrom( baseClass )

    local new_class = {}
    local class_mt = { __index = new_class }

    function new_class:create()
        local newinst = {}
        setmetatable( newinst, class_mt )
        return newinst
    end

    if nil ~= baseClass then
        setmetatable( new_class, { __index = baseClass } )
    end

    -- Implementation of additional OO properties starts here --

    -- Return the class object of the instance
    function new_class:class()
        return new_class;
    end

    -- Return the super class object of the instance, optional base class of the given class (must be part of hiearchy)
    function new_class:baseClass(class)
        return new_class:_B(class);
    end

    -- Return the super class object of the instance, optional base class of the given class (must be part of hiearchy)
    function new_class:_B(class)
        if (class==nil) or (new_class==class) then
            return baseClass;
        elseif(baseClass~=nil) then
            return baseClass:_B(class);
        end
        return nil;
    end

    -- Return true if the caller is an instance of theClass
    function new_class:_ISA( theClass )
        local b_isa = false

        local cur_class = new_class

        while ( nil ~= cur_class ) and ( false == b_isa ) do
            if cur_class == theClass then
                b_isa = true
            else
                cur_class = cur_class:baseClass()
            end
        end

        return b_isa
    end

    return new_class
end

-----------------------------------------------------------------------------
-- Random functions will use lua rands for stand alone script running
-- and Map.rand for in game.
-----------------------------------------------------------------------------
function PWRand()
    return math.random()
end

function PWRandSeed(fixedseed)
    local seed
    if fixedseed == nil then
        seed = os.time()
    else
        seed = fixedseed
    end
    math.randomseed(seed)
    print("random seed for this map is " .. seed)
end

--range is inclusive, low and high are possible results
function PWRandint(low, high)
    return math.random(low, high)
end
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
    if dir == mc.C then
        return x,y
    elseif dir == mc.W then
        xx = x - 1
        yy = y
        return xx,yy
    elseif dir == mc.NW then
        xx = x - 1 + odd
        yy = y + 1
        return xx,yy
    elseif dir == mc.NE then
        xx = x + odd
        yy = y + 1
        return xx,yy
    elseif dir == mc.E then
        xx = x + 1
        yy = y
        return xx,yy
    elseif dir == mc.SE then
        xx = x + odd
        yy = y - 1
        return xx,yy
    elseif dir == mc.SW then
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
    local range = mc.topLatitude - mc.bottomLatitude
    return y / self.height * range + mc.bottomLatitude
end

function FloatMap:GetYForLatitude(lat)
    local range = mc.topLatitude - mc.bottomLatitude
    return math.floor(((lat - mc.bottomLatitude) /range * self.height) + 0.5)
end

function FloatMap:GetZone(y)
    local lat = self:GetLatitudeForY(y)
    if y < 0 or y >= self.height then
        return mc.NOZONE
    end
    if lat > mc.polarFrontLatitude then
        return mc.NPOLAR
    elseif lat >= mc.horseLatitudes then
        return mc.NTEMPERATE
    elseif lat >= 0.0 then
        return mc.NEQUATOR
    elseif lat > -mc.horseLatitudes then
        return mc.SEQUATOR
    elseif lat >= -mc.polarFrontLatitude then
        return mc.STEMPERATE
    else
        return mc.SPOLAR
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

    if zone == mc.NPOLAR then
        return mc.SW,mc.W
    elseif zone == mc.NTEMPERATE then
        return mc.NE,mc.E
    elseif zone == mc.NEQUATOR then
        return mc.SW,mc.W
    elseif zone == mc.SEQUATOR then
        return mc.NW,mc.W
    elseif zone == mc.STEMPERATE then
        return mc.SE, mc.E
    else
        return mc.NW,mc.W
    end
    return -1,-1
end

function FloatMap:GetGeostrophicPressure(lat)
    local latRange = nil
    local latPercent = nil
    local pressure = nil
    if lat > mc.polarFrontLatitude then
        latRange = 90.0 - mc.polarFrontLatitude
        latPercent = (lat - mc.polarFrontLatitude)/latRange
        pressure = 1.0 - latPercent
    elseif lat >= mc.horseLatitudes then
        latRange = mc.polarFrontLatitude - mc.horseLatitudes
        latPercent = (lat - mc.horseLatitudes)/latRange
        pressure = latPercent
    elseif lat >= 0.0 then
        latRange = mc.horseLatitudes - 0.0
        latPercent = (lat - 0.0)/latRange
        pressure = 1.0 - latPercent
    elseif lat > -mc.horseLatitudes then
        latRange = 0.0 + mc.horseLatitudes
        latPercent = (lat + mc.horseLatitudes)/latRange
        pressure = latPercent
    elseif lat >= -mc.polarFrontLatitude then
        latRange = -mc.horseLatitudes + mc.polarFrontLatitude
        latPercent = (lat + mc.polarFrontLatitude)/latRange
        pressure = 1.0 - latPercent
    else
        latRange = -mc.polarFrontLatitude + 90.0
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
        hereX,hereY = self:GetNeighbor(hereX,hereY,mc.W)
        if self:IsOnMap(hereX,hereY) then
            table.insert(list,{hereX,hereY})
        end
        --Go r times to the NE
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NE)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the E
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.E)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the SE
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.SE)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the SW
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.SW)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r times to the W
        for z = 1,r,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.W)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --Go r - 1 times to the NW!!!!!
        for z = 1,r - 1,1 do
            hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NW)
            if self:IsOnMap(hereX,hereY) then
                table.insert(list,{hereX,hereY})
            end
        end
        --one extra NW to set up for next circle
        hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NW)
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
------------------------------------------------------------------------
--ElevationMap class
------------------------------------------------------------------------
ElevationMap = inheritsFrom(FloatMap)

function ElevationMap:New(width, height, wrapX, wrapY)
    local new_inst = FloatMap:New(width,height,wrapX,wrapY)
    setmetatable(new_inst, {__index = ElevationMap});	--setup metatable
    return new_inst
end
function ElevationMap:IsBelowSeaLevel(x,y)
    local i = self:GetIndex(x,y)
    if self.data[i] < self.seaLevelThreshold then
        return true
    else
        return false
    end
end
-------------------------------------------------------------------------
--AreaMap class
-------------------------------------------------------------------------
PWAreaMap = inheritsFrom(FloatMap)

function PWAreaMap:New(width,height,wrapX,wrapY)
    local new_inst = FloatMap:New(width,height,wrapX,wrapY)
    setmetatable(new_inst, {__index = PWAreaMap});	--setup metatable

    new_inst.areaList = {}
    new_inst.segStack = {}
    return new_inst
end

function PWAreaMap:DefineAreas(matchFunction)
    --zero map data
    for i = 0,self.width*self.height - 1,1 do
        self.data[i] = 0.0
    end

    self.areaList = {}
    local currentAreaID = 0
    for y = 0, self.height - 1,1 do
        for x = 0, self.width - 1,1 do
            local i = self:GetIndex(x,y)
            if self.data[i] == 0 then
                currentAreaID = currentAreaID + 1
                local area = PWArea:New(currentAreaID,x,y,matchFunction(x,y))
                --str = string.format("Filling area %d, matchFunction(x = %d,y = %d) = %s",area.id,x,y,tostring(matchFunction(x,y)))
                --print(str)
                self:FillArea(x,y,area,matchFunction)
                table.insert(self.areaList, area)

            end
        end
    end
end

function PWAreaMap:FillArea(x,y,area,matchFunction)
    self.segStack = {}
    local seg = LineSeg:New(y,x,x,1)
    Push(self.segStack,seg)
    seg = LineSeg:New(y + 1,x,x,-1)
    Push(self.segStack,seg)
    while #self.segStack > 0 do
        seg = Pop(self.segStack)
        self:ScanAndFillLine(seg,area,matchFunction)
    end
end

function PWAreaMap:ScanAndFillLine(seg,area,matchFunction)

    --str = string.format("Processing line y = %d, xLeft = %d, xRight = %d, dy = %d -------",seg.y,seg.xLeft,seg.xRight,seg.dy)
    --print(str)
    if self:ValidateY(seg.y + seg.dy) == -1 then
        return
    end

    local odd = (seg.y + seg.dy) % 2
    local notOdd = seg.y % 2
    --str = string.format("odd = %d, notOdd = %d",odd,notOdd)
    --print(str)

    local lineFound = 0
    local xStop = nil
    if self.wrapX then
        xStop = 0 - (self.width * 30)
    else
        xStop = -1
    end
    local leftExtreme = nil
    for leftExt = seg.xLeft - odd,xStop + 1,-1 do
        leftExtreme = leftExt --need this saved
        --str = string.format("leftExtreme = %d",leftExtreme)
        --print(str)
        local x = self:ValidateX(leftExtreme)
        local y = self:ValidateY(seg.y + seg.dy)
        local i = self:GetIndex(x,y)
        --str = string.format("x = %d, y = %d, area.trueMatch = %s, matchFunction(x,y) = %s",x,y,tostring(area.trueMatch),tostring(matchFunction(x,y)))
        --print(str)
        if self.data[i] == 0 and area.trueMatch == matchFunction(x,y) then
            self.data[i] = area.id
            area.size = area.size + 1
            --print("adding to area")
            lineFound = 1
        else
            --if no line was found, then leftExtreme is fine, but if
            --a line was found going left, then we need to increment
            --xLeftExtreme to represent the inclusive end of the line
            if lineFound == 1 then
                leftExtreme = leftExtreme + 1
                --print("line found, adding 1 to leftExtreme")
            end
            break
        end
    end
    --str = string.format("leftExtreme = %d",leftExtreme)
    --print(str)
    local rightExtreme = nil
    --now scan right to find extreme right, place each found segment on stack
    if self.wrapX then
        xStop = self.width * 20
    else
        xStop = self.width
    end
    for rightExt = seg.xLeft + lineFound - odd,xStop - 1,1 do
        rightExtreme = rightExt --need this saved
        --str = string.format("rightExtreme = %d",rightExtreme)
        --print(str)
        local x = self:ValidateX(rightExtreme)
        local y = self:ValidateY(seg.y + seg.dy)
        local i = self:GetIndex(x,y)
        --str = string.format("x = %d, y = %d, area.trueMatch = %s, matchFunction(x,y) = %s",x,y,tostring(area.trueMatch),tostring(matchFunction(x,y)))
        --print(str)
        if self.data[i] == 0 and area.trueMatch == matchFunction(x,y) then
            self.data[i] = area.id
            area.size = area.size + 1
            --print("adding to area")
            if lineFound == 0 then
                lineFound = 1 --starting new line
                leftExtreme = rightExtreme
            end
        elseif lineFound == 1 then --found the right end of a line segment
        --print("found right end of line")
        lineFound = 0
        --put same direction on stack
        local newSeg = LineSeg:New(y,leftExtreme,rightExtreme - 1,seg.dy)
        Push(self.segStack,newSeg)
        --str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",y,leftExtreme,rightExtreme - 1,seg.dy)
        --print(str)
        --determine if we must put reverse direction on stack
        if leftExtreme < seg.xLeft - odd or rightExtreme >= seg.xRight + notOdd then
            --out of shadow so put reverse direction on stack
            newSeg = LineSeg:New(y,leftExtreme,rightExtreme - 1,-seg.dy)
            Push(self.segStack,newSeg)
            --str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",y,leftExtreme,rightExtreme - 1,-seg.dy)
            --print(str)
        end
        if(rightExtreme >= seg.xRight + notOdd) then
            break
        end
    elseif lineFound == 0 and rightExtreme >= seg.xRight + notOdd then
        break --past the end of the parent line and no line found
    end
    --continue finding segments
end
if lineFound == 1 then --still needing a line to be put on stack
    print("still need line segments")
    lineFound = 0
    --put same direction on stack
    local newSeg = LineSeg:New(seg.y + seg.dy,leftExtreme,rightExtreme - 1,seg.dy)
    Push(self.segStack,newSeg)
    str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",seg.y + seg.dy,leftExtreme,rightExtreme - 1,seg.dy)
    print(str)
    --determine if we must put reverse direction on stack
    if leftExtreme < seg.xLeft - odd or rightExtreme >= seg.xRight + notOdd then
        --out of shadow so put reverse direction on stack
        newSeg = LineSeg:New(seg.y + seg.dy,leftExtreme,rightExtreme - 1,-seg.dy)
        Push(self.segStack,newSeg)
        str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",seg.y + seg.dy,leftExtreme,rightExtreme - 1,-seg.dy)
        print(str)
    end
end
end

function PWAreaMap:GetAreaByID(id)
    for i = 1,#self.areaList,1 do
        if self.areaList[i].id == id then
            return self.areaList[i]
        end
    end
    error("Can't find area id in AreaMap.areaList")
end

function PWAreaMap:ValidateY(y)
    local yy = nil
    if self.wrapY then
        yy = y % self.height
    elseif y < 0 or y >= self.height then
        return -1
    else
        yy = y
    end
    return yy
end

function PWAreaMap:ValidateX(x)
    local xx = nil
    if self.wrapX then
        xx = x % self.width
    elseif x < 0 or x >= self.width then
        return -1
    else
        xx = x
    end
    return xx
end

function PWAreaMap:PrintAreaList()
    for i=1,#self.areaList,1 do
        local id = self.areaList[i].id
        local seedx = self.areaList[i].seedx
        local seedy = self.areaList[i].seedy
        local size = self.areaList[i].size
        local trueMatch = self.areaList[i].trueMatch
        local str = string.format("area id = %d, trueMatch = %s, size = %d, seedx = %d, seedy = %d",id,tostring(trueMatch),size,seedx,seedy)
        print(str)
    end
end
-------------------------------------------------------------------------
--Area class
-------------------------------------------------------------------------
PWArea = inheritsFrom(nil)

function PWArea:New(id,seedx,seedy,trueMatch)
    local new_inst = {}
    setmetatable(new_inst, {__index = PWArea});	--setup metatable

    new_inst.id = id
    new_inst.seedx = seedx
    new_inst.seedy = seedy
    new_inst.trueMatch = trueMatch
    new_inst.size = 0

    return new_inst
end
-------------------------------------------------------------------------
--LineSeg class
-------------------------------------------------------------------------
LineSeg = inheritsFrom(nil)

function LineSeg:New(y,xLeft,xRight,dy)
    local new_inst = {}
    setmetatable(new_inst, {__index = LineSeg});	--setup metatable

    new_inst.y = y
    new_inst.xLeft = xLeft
    new_inst.xRight = xRight
    new_inst.dy = dy

    return new_inst
end

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
    if direction == mc.NOFLOW then
        error("can't get junction neighbor in direction NOFLOW")
    elseif direction == mc.WESTFLOW then
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
    elseif direction == mc.EASTFLOW then
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
    elseif direction == mc.VERTFLOW then
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

    local vertNeighbor = self:GetJunctionNeighbor(mc.VERTFLOW,junction)
    local vertAltitude = nil
    if vertNeighbor == nil then
        vertAltitude = junction.altitude
        --print("--vertNeighbor == nil")
    else
        vertAltitude = vertNeighbor.altitude
        --print(string.format("--vertNeighbor = (%d,%d) N = %s, alt = %f",vertNeighbor.x,vertNeighbor.y,tostring(vertNeighbor.isNorth),vertNeighbor.altitude))
    end

    local westNeighbor = self:GetJunctionNeighbor(mc.WESTFLOW,junction)
    local westAltitude = nil
    if westNeighbor == nil then
        westAltitude = junction.altitude
        --print("--westNeighbor == nil")
    else
        westAltitude = westNeighbor.altitude
        --print(string.format("--westNeighbor = (%d,%d) N = %s, alt = %f",westNeighbor.x,westNeighbor.y,tostring(westNeighbor.isNorth),westNeighbor.altitude))
    end

    local eastNeighbor = self:GetJunctionNeighbor(mc.EASTFLOW,junction)
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
    local vertNeighbor = self:GetJunctionNeighbor(mc.VERTFLOW,junction)
    local vertAltitude = nil
    if vertNeighbor == nil then
        vertAltitude = junction.altitude
    else
        vertAltitude = vertNeighbor.altitude
    end

    local westNeighbor = self:GetJunctionNeighbor(mc.WESTFLOW,junction)
    local westAltitude = nil
    if westNeighbor == nil then
        westAltitude = junction.altitude
    else
        westAltitude = westNeighbor.altitude
    end

    local eastNeighbor = self:GetJunctionNeighbor(mc.EASTFLOW,junction)
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

        for dir = mc.WESTFLOW,mc.VERTFLOW,1 do
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
            junction.flow = mc.NOFLOW
        end
    end
end

function RiverMap:GetValidFlows(junction)
    local validList = {}
    for dir = mc.WESTFLOW,mc.VERTFLOW,1 do
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
            nextJunction.size = (nextJunction.size + rainfallMap.data[i]) * mc.riverRainCheatFactor
            if nextJunction.flow == mc.NOFLOW or self:IsTouchingOcean(nextJunction) then
                nextJunction.size = 0.0
                break
            end
            nextJunction = self:GetJunctionNeighbor(nextJunction.flow,nextJunction)
        end
    end

    --now sort by river size to find river threshold
    table.sort(junctionList,function (a,b) return a.size > b.size end)
    local riverIndex = math.floor(mc.riverPercent * #junctionList)
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
    local xx,yy = elevationMap:GetNeighbor(x,y,mc.NE)
    local ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].southJunction.flow == mc.VERTFLOW and self.riverData[ii].southJunction.size > self.riverThreshold then
        --print(string.format("--NE(%d,%d) south flow=%d, size=%f",xx,yy,self.riverData[ii].southJunction.flow,self.riverData[ii].southJunction.size))
        WOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTH
    end
    xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.VERTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        --print(string.format("--SE(%d,%d) north flow=%d, size=%f",xx,yy,self.riverData[ii].northJunction.flow,self.riverData[ii].northJunction.size))
        WOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTH
    end

    local NWOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
    xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.WESTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST
    end
    if self.riverData[i].southJunction.flow == mc.EASTFLOW and self.riverData[i].southJunction.size > self.riverThreshold then
        NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST
    end

    local NEOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
    xx,yy = elevationMap:GetNeighbor(x,y,mc.SW)
    ii = elevationMap:GetIndex(xx,yy)
    if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.EASTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold then
        NEOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST
    end
    if self.riverData[i].southJunction.flow == mc.WESTFLOW and self.riverData[i].southJunction.size > self.riverThreshold then
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
    new_inst.flow = mc.NOFLOW
    new_inst.size = 0.0

    return new_inst
end

------------------------------------------------------------------------------
--Global functions
------------------------------------------------------------------------------
function GenerateTwistedPerlinMap(width, height, xWrap, yWrap,minFreq,maxFreq,varFreq)
    local inputNoise = FloatMap:New(width,height,xWrap,yWrap)
    inputNoise:GenerateNoise()
    inputNoise:Normalize()

    local freqMap = FloatMap:New(width,height,xWrap,yWrap)
    for y = 0, freqMap.height - 1,1 do
        for x = 0,freqMap.width - 1,1 do
            local i = freqMap:GetIndex(x,y)
            local odd = y % 2
            local xx = x + odd * 0.5
            freqMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,freqMap.width,freqMap.height * mc.YtoXRatio,varFreq,1.0,0.1,8,inputNoise)
        end
    end
    freqMap:Normalize()
    --	freqMap:Save("freqMap.csv")

    local twistMap = FloatMap:New(width,height,xWrap,yWrap)
    for y = 0, twistMap.height - 1,1 do
        for x = 0,twistMap.width - 1,1 do
            local i = twistMap:GetIndex(x,y)
            local freq = freqMap.data[i] * (maxFreq - minFreq) + minFreq
            local mid = (maxFreq - minFreq)/2 + minFreq
            local coordScale = freq/mid
            local offset = (1.0 - coordScale)/mid
            --print("1-coordscale = " .. (1.0 - coordScale) .. ", offset = " .. offset)
            local ampChange = 0.85 - freqMap.data[i] * 0.5
            local odd = y % 2
            local xx = x + odd * 0.5
            twistMap.data[i] = GetPerlinNoise(xx + offset,(y + offset) * mc.YtoXRatio,twistMap.width,twistMap.height * mc.YtoXRatio,mid,1.0,ampChange,8,inputNoise)
        end
    end

    twistMap:Normalize()
    --twistMap:Save("twistMap.csv")
    return twistMap
end

function ShuffleList(list)
    local len = #list
    for i=0,len - 1,1 do
        local k = PWRandint(0,len-1)
        list[i], list[k] = list[k], list[i]
    end
end

function GenerateMountainMap(width,height,xWrap,yWrap,initFreq)
    local inputNoise = FloatMap:New(width,height,xWrap,yWrap)
    inputNoise:GenerateBinaryNoise()
    inputNoise:Normalize()
    local inputNoise2 = FloatMap:New(width,height,xWrap,yWrap)
    inputNoise2:GenerateNoise()
    inputNoise2:Normalize()

    local mountainMap = FloatMap:New(width,height,xWrap,yWrap)
    local stdDevMap = FloatMap:New(width,height,xWrap,yWrap)
    local noiseMap = FloatMap:New(width,height,xWrap,yWrap)
    for y = 0, mountainMap.height - 1,1 do
        for x = 0,mountainMap.width - 1,1 do
            local i = mountainMap:GetIndex(x,y)
            local odd = y % 2
            local xx = x + odd * 0.5
            mountainMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,mountainMap.width,mountainMap.height * mc.YtoXRatio,initFreq,1.0,0.4,8,inputNoise)
            noiseMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,mountainMap.width,mountainMap.height * mc.YtoXRatio,initFreq,1.0,0.4,8,inputNoise2)
            stdDevMap.data[i] = mountainMap.data[i]
        end
    end
    mountainMap:Normalize()
    stdDevMap:Deviate(7)
    stdDevMap:Normalize()
    --stdDevMap:Save("stdDevMap.csv")
    --mountainMap:Save("mountainCloud.csv")
    noiseMap:Normalize()
    --noiseMap:Save("noiseMap.csv")

    local moundMap = FloatMap:New(width,height,xWrap,yWrap)
    for y = 0, mountainMap.height - 1,1 do
        for x = 0,mountainMap.width - 1,1 do
            local i = mountainMap:GetIndex(x,y)
            local val = mountainMap.data[i]
            moundMap.data[i] = (math.sin(val*math.pi*2-math.pi*0.5)*0.5+0.5) * GetAttenuationFactor(mountainMap,x,y)
            if val < 0.5 then
                val = val^1 * 4
            else
                val = (1 - val)^1 * 4
            end
            --mountainMap.data[i] = val
            mountainMap.data[i] = moundMap.data[i]
        end
    end
    mountainMap:Normalize()
    --mountainMap:Save("premountMap.csv")
    --moundMap:Save("moundMap.csv")

    for y = 0, mountainMap.height - 1,1 do
        for x = 0,mountainMap.width - 1,1 do
            local i = mountainMap:GetIndex(x,y)
            local val = mountainMap.data[i]
            --mountainMap.data[i] = (math.sin(val * 2 * math.pi + math.pi * 0.5)^8 * val) + moundMap.data[i] * 2 + noiseMap.data[i] * 0.6
            mountainMap.data[i] = (math.sin(val * 3 * math.pi + math.pi * 0.5)^16 * val)^0.5
            if mountainMap.data[i] > 0.2 then
                mountainMap.data[i] = 1.0
            else
                mountainMap.data[i] = 0.0
            end
        end
    end
    --mountainMap:Save("premountMap.csv")

    local stdDevThreshold = stdDevMap:FindThresholdFromPercent(mc.landPercent,true,false)

    for y = 0, mountainMap.height - 1,1 do
        for x = 0,mountainMap.width - 1,1 do
            local i = mountainMap:GetIndex(x,y)
            local val = mountainMap.data[i]
            local dev = 2.0 * stdDevMap.data[i] - 2.0 * stdDevThreshold
            --mountainMap.data[i] = (math.sin(val * 2 * math.pi + math.pi * 0.5)^8 * val) + moundMap.data[i] * 2 + noiseMap.data[i] * 0.6
            mountainMap.data[i] = (val + moundMap.data[i]) * dev
        end
    end

    mountainMap:Normalize()
    --mountainMap:Save("mountainMap.csv")
    return mountainMap
end

function waterMatch(x,y)
    if elevationMap:IsBelowSeaLevel(x,y) then
        return true
    end
    return false
end

function GetAttenuationFactor(map,x,y)
    local southY = map.height * mc.southAttenuationRange
    local southRange = map.height * mc.southAttenuationRange
    local yAttenuation = 1.0
    if y < southY then
        yAttenuation = mc.southAttenuationFactor + (y/southRange) * (1.0 - mc.southAttenuationFactor)
    end

    local northY = map.height - (map.height * mc.northAttenuationRange)
    local northRange = map.height * mc.northAttenuationRange
    if y > northY then
        yAttenuation = mc.northAttenuationFactor + ((map.height - y)/northRange) * (1.0 - mc.northAttenuationFactor)
    end

    local eastY = map.width - (map.width * mc.eastAttenuationRange)
    local eastRange = map.width * mc.eastAttenuationRange
    local xAttenuation = 1.0
    if x > eastY then
        xAttenuation = mc.eastAttenuationFactor + ((map.width - x)/eastRange) * (1.0 - mc.eastAttenuationFactor)
    end

    local westY = map.width * mc.westAttenuationRange
    local westRange = map.width * mc.westAttenuationRange
    if x < westY then
        xAttenuation = mc.westAttenuationFactor + (x/westRange) * (1.0 - mc.westAttenuationFactor)
    end

    return yAttenuation * xAttenuation
end

function GenerateElevationMap(width,height,xWrap,yWrap)
    local twistMinFreq = 128/width * mc.twistMinFreq --0.02/128
    local twistMaxFreq = 128/width * mc.twistMaxFreq --0.12/128
    local twistVar = 128/width * mc.twistVar --0.042/128
    local mountainFreq = 128/width * mc.mountainFreq --0.05/128
    local twistMap = GenerateTwistedPerlinMap(width,height,xWrap,yWrap,twistMinFreq,twistMaxFreq,twistVar)
    local mountainMap = GenerateMountainMap(width,height,xWrap,yWrap,mountainFreq)
    local elevationMap = ElevationMap:New(width,height,xWrap,yWrap)
    for y = 0,height - 1,1 do
        for x = 0,width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local tVal = twistMap.data[i]
            tVal = (math.sin(tVal*math.pi-math.pi*0.5)*0.5+0.5)^0.25 --this formula adds a curve flattening the extremes
            elevationMap.data[i] = (tVal + ((mountainMap.data[i] * 2) - 1) * mc.mountainWeight)
        end
    end

    elevationMap:Normalize()

    --attentuation should not break normalization
    for y = 0,height - 1,1 do
        for x = 0,width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local attenuationFactor = GetAttenuationFactor(elevationMap,x,y)
            elevationMap.data[i] = elevationMap.data[i] * attenuationFactor
        end
    end

    elevationMap.seaLevelThreshold = elevationMap:FindThresholdFromPercent(mc.landPercent,true,false)

    return elevationMap
end

function FillInLakes()
    local areaMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
    areaMap:DefineAreas(waterMatch)
    for i=1,#areaMap.areaList,1 do
        local area = areaMap.areaList[i]
        if area.trueMatch and area.size < mc.minOceanSize then
            for n = 0,areaMap.length,1 do
                if areaMap.data[n] == area.id then
                    elevationMap.data[n] = elevationMap.seaLevelThreshold
                end
            end
        end
    end
end

function GenerateTempMaps(elevationMap)

    local aboveSeaLevelMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = aboveSeaLevelMap:GetIndex(x,y)
            if elevationMap:IsBelowSeaLevel(x,y) then
                aboveSeaLevelMap.data[i] = 0.0
            else
                aboveSeaLevelMap.data[i] = elevationMap.data[i] - elevationMap.seaLevelThreshold
            end
        end
    end
    aboveSeaLevelMap:Normalize()
    --aboveSeaLevelMap:Save("aboveSeaLevelMap.csv")

    local summerMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    local zenith = mc.tropicLatitudes
    local topTempLat = mc.topLatitude + zenith
    local bottomTempLat = mc.bottomLatitude
    local latRange = topTempLat - bottomTempLat
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = summerMap:GetIndex(x,y)
            local lat = summerMap:GetLatitudeForY(y)
            --print("y=" .. y ..",lat=" .. lat)
            local latPercent = (lat - bottomTempLat)/latRange
            --print("latPercent=" .. latPercent)
            local temp = (math.sin(latPercent * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5)
            if elevationMap:IsBelowSeaLevel(x,y) then
                temp = temp * mc.maxWaterTemp + mc.minWaterTemp
            end
            summerMap.data[i] = temp
        end
    end
    summerMap:Smooth(math.floor(elevationMap.width/8))
    summerMap:Normalize()

    local winterMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    zenith = -mc.tropicLatitudes
    topTempLat = mc.topLatitude
    bottomTempLat = mc.bottomLatitude + zenith
    latRange = topTempLat - bottomTempLat
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = winterMap:GetIndex(x,y)
            local lat = winterMap:GetLatitudeForY(y)
            local latPercent = (lat - bottomTempLat)/latRange
            local temp = math.sin(latPercent * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5
            if elevationMap:IsBelowSeaLevel(x,y) then
                temp = temp * mc.maxWaterTemp + mc.minWaterTemp
            end
            winterMap.data[i] = temp
        end
    end
    winterMap:Smooth(math.floor(elevationMap.width/8))
    winterMap:Normalize()

    local temperatureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = temperatureMap:GetIndex(x,y)
            temperatureMap.data[i] = (winterMap.data[i] + summerMap.data[i]) * (1.0 - aboveSeaLevelMap.data[i])
        end
    end
    temperatureMap:Normalize()

    return summerMap,winterMap,temperatureMap
end

function GenerateRainfallMap(elevationMap)
    local summerMap,winterMap,temperatureMap = GenerateTempMaps(elevationMap)
    --summerMap:Save("summerMap.csv")
    --winterMap:Save("winterMap.csv")
    --temperatureMap:Save("temperatureMap.csv")
    local geoMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local lat = elevationMap:GetLatitudeForY(y)
            local pressure = elevationMap:GetGeostrophicPressure(lat)
            geoMap.data[i] = pressure
        end
    end
    geoMap:Normalize()
    --geoMap:Save("geoMap.csv")

    local sortedSummerMap = {}
    local sortedWinterMap = {}
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            sortedSummerMap[i + 1] = {x,y,summerMap.data[i]}
            sortedWinterMap[i + 1] = {x,y,winterMap.data[i]}
        end
    end
    table.sort(sortedSummerMap, function (a,b) return a[3] < b[3] end)
    table.sort(sortedWinterMap, function (a,b) return a[3] < b[3] end)

    local sortedGeoMap = {}
    local xStart = 0
    local xStop = 0
    local yStart = 0
    local yStop = 0
    local incX = 0
    local incY = 0
    local geoIndex = 1
    local str = ""
    for zone=0,5,1 do
        local topY = elevationMap:GetYFromZone(zone,true)
        local bottomY = elevationMap:GetYFromZone(zone,false)
        if not (topY == -1 and bottomY == -1) then
            if topY == -1 then
                topY = elevationMap.height - 1
            end
            if bottomY == -1 then
                bottomY = 0
            end
            --str = string.format("topY = %d, bottomY = %d",topY,bottomY)
            --print(str)
            local dir1,dir2 = elevationMap:GetGeostrophicWindDirections(zone)
            --str = string.format("zone = %d, dir1 = %d",zone,dir1)
            --print(str)
            if (dir1 == mc.SW) or (dir1 == mc.SE) then
                yStart = topY
                yStop = bottomY --- 1
                incY = -1
            else
                yStart = bottomY
                yStop = topY --+ 1
                incY = 1
            end
            if dir2 == mc.W then
                xStart = elevationMap.width - 1
                xStop = 0---1
                incX = -1
            else
                xStart = 0
                xStop = elevationMap.width
                incX = 1
            end
            --str = string.format("yStart = %d, yStop = %d, incY = %d",yStart,yStop,incY)
            --print(str)
            --str = string.format("xStart = %d, xStop = %d, incX = %d",xStart,xStop,incX)
            --print(str)

            for y = yStart,yStop ,incY do
                --str = string.format("y = %d",y)
                --print(str)
                --each line should start on water to avoid vast areas without rain
                local xxStart = xStart
                local xxStop = xStop
                for xx = xStart,xStop - incX, incX do
                    local i = elevationMap:GetIndex(xx,y)
                    if elevationMap:IsBelowSeaLevel(xx,y) then
                        xxStart = xx
                        xxStop = xx + elevationMap.width * incX
                        break
                    end
                end
                for x = xxStart,xxStop - incX,incX do
                    local i = elevationMap:GetIndex(x,y)
                    sortedGeoMap[geoIndex] = {x,y,geoMap.data[i]}
                    geoIndex = geoIndex + 1
                end
            end
        end
    end
    --	table.sort(sortedGeoMap, function (a,b) return a[3] < b[3] end)
    --print(#sortedGeoMap)
    --print(#geoMap.data)

    local rainfallSummerMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    local moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for i = 1,#sortedSummerMap,1 do
        local x = sortedSummerMap[i][1]
        local y = sortedSummerMap[i][2]
        local pressure = sortedSummerMap[i][3]
        DistributeRain(x,y,elevationMap,temperatureMap,summerMap,rainfallSummerMap,moistureMap,false)
    end

    local rainfallWinterMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    local moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for i = 1,#sortedWinterMap,1 do
        local x = sortedWinterMap[i][1]
        local y = sortedWinterMap[i][2]
        local pressure = sortedWinterMap[i][3]
        DistributeRain(x,y,elevationMap,temperatureMap,winterMap,rainfallWinterMap,moistureMap,false)
    end

    local rainfallGeostrophicMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    --print("----------------------------------------------------------------------------------------")
    --print("--GEOSTROPHIC---------------------------------------------------------------------------")
    --print("----------------------------------------------------------------------------------------")
    for i = 1,#sortedGeoMap,1 do
        local x = sortedGeoMap[i][1]
        local y = sortedGeoMap[i][2]
        --~ 		if y == 35 or y == 40 then
        --~ 			str = string.format("x = %d, y = %d",x,y)
        --~ 			print(str)
        --~ 		end
        DistributeRain(x,y,elevationMap,temperatureMap,geoMap,rainfallGeostrophicMap,moistureMap,true)
    end
    --zero below sea level for proper percent threshold finding
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            if elevationMap:IsBelowSeaLevel(x,y) then
                rainfallSummerMap.data[i] = 0.0
                rainfallWinterMap.data[i] = 0.0
                rainfallGeostrophicMap.data[i] = 0.0
            end
        end
    end

    rainfallSummerMap:Normalize()
    --rainfallSummerMap:Save("rainFallSummerMap.csv")
    rainfallWinterMap:Normalize()
    --rainfallWinterMap:Save("rainFallWinterMap.csv")
    rainfallGeostrophicMap:Normalize()
    --rainfallGeostrophicMap:Save("rainfallGeostrophicMap.csv")

    local rainfallMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
    for y = 0,elevationMap.height - 1,1 do
        for x = 0,elevationMap.width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            rainfallMap.data[i] = rainfallSummerMap.data[i] + rainfallWinterMap.data[i] + (rainfallGeostrophicMap.data[i] * mc.geostrophicFactor)
        end
    end
    rainfallMap:Normalize()

    return rainfallMap, temperatureMap
end

function DistributeRain(x,y,elevationMap,temperatureMap,pressureMap,rainfallMap,moistureMap,boolGeostrophic)

    local i = elevationMap:GetIndex(x,y)
    local upLiftSource = math.max(math.pow(pressureMap.data[i],mc.upLiftExponent),1.0 - temperatureMap.data[i])
    --local str = string.format("geo=%s,x=%d, y=%d, srcPressure uplift = %f, upliftSource = %f",tostring(boolGeostrophic),x,y,math.pow(pressureMap.data[i],mc.upLiftExponent),upLiftSource)
    --print(str)
    if elevationMap:IsBelowSeaLevel(x,y) then
        moistureMap.data[i] = math.max(moistureMap.data[i], temperatureMap.data[i])
        --print("water tile = true")
    end
    --print(string.format("moistureMap.data[i] = %f",moistureMap.data[i]))

    --make list of neighbors
    local nList = {}
    if boolGeostrophic then
        local zone = elevationMap:GetZone(y)
        local dir1,dir2 = elevationMap:GetGeostrophicWindDirections(zone)
        local x1,y1 = elevationMap:GetNeighbor(x,y,dir1)
        local ii = elevationMap:GetIndex(x1,y1)
        --neighbor must be on map and in same wind zone
        if ii >= 0 and (elevationMap:GetZone(y1) == elevationMap:GetZone(y)) then
            table.insert(nList,{x1,y1})
        end
        local x2,y2 = elevationMap:GetNeighbor(x,y,dir2)
        ii = elevationMap:GetIndex(x2,y2)
        if ii >= 0 then
            table.insert(nList,{x2,y2})
        end
    else
        for dir = 1,6,1 do
            local xx,yy = elevationMap:GetNeighbor(x,y,dir)
            local ii = elevationMap:GetIndex(xx,yy)
            if ii >= 0 and pressureMap.data[i] <= pressureMap.data[ii] then
                table.insert(nList,{xx,yy})
            end
        end
    end
    if #nList == 0 or boolGeostrophic and #nList == 1 then
        local cost = moistureMap.data[i]
        rainfallMap.data[i] = cost
        return
    end
    local moisturePerNeighbor = moistureMap.data[i]/#nList
    --drop rain and pass moisture to neighbors
    for n = 1,#nList,1 do
        local xx = nList[n][1]
        local yy = nList[n][2]
        local ii = elevationMap:GetIndex(xx,yy)
        local upLiftDest = math.max(math.pow(pressureMap.data[ii],mc.upLiftExponent),1.0 - temperatureMap.data[ii])
        local cost = GetRainCost(upLiftSource,upLiftDest)
        local bonus = 0.0
        if (elevationMap:GetZone(y) == mc.NPOLAR or elevationMap:GetZone(y) == mc.SPOLAR) then
            bonus = mc.polarRainBoost
        end
        if boolGeostrophic and #nList == 2 then
            if n == 1 then
                moisturePerNeighbor = (1.0 - mc.geostrophicLateralWindStrength) * moistureMap.data[i]
            else
                moisturePerNeighbor = mc.geostrophicLateralWindStrength * moistureMap.data[i]
            end
        end
        --print(string.format("---xx=%d, yy=%d, destPressure uplift = %f, upLiftDest = %f, cost = %f, moisturePerNeighbor = %f, bonus = %f",xx,yy,math.pow(pressureMap.data[ii],mc.upLiftExponent),upLiftDest,cost,moisturePerNeighbor,bonus))
        rainfallMap.data[i] = rainfallMap.data[i] + cost * moisturePerNeighbor + bonus
        --pass to neighbor.
        --print(string.format("---moistureMap.data[ii] = %f",moistureMap.data[ii]))
        moistureMap.data[ii] = moistureMap.data[ii] + moisturePerNeighbor - (cost * moisturePerNeighbor)
        --print(string.format("---dropping %f rain",cost * moisturePerNeighbor + bonus))
        --print(string.format("---passing on %f moisture",moisturePerNeighbor - (cost * moisturePerNeighbor)))
    end

end

function GetRainCost(upLiftSource,upLiftDest)
    local cost = mc.minimumRainCost
    cost = math.max(mc.minimumRainCost, cost + upLiftDest - upLiftSource)
    if cost < 0.0 then
        cost = 0.0
    end
    return cost
end

function GetDifferenceAroundHex(x,y)
    local avg = elevationMap:GetAverageInHex(x,y,1)
    local i = elevationMap:GetIndex(x,y)
    return elevationMap.data[i] - avg
    --~ 	local nList = elevationMap:GetRadiusAroundHex(x,y,1)
    --~ 	local i = elevationMap:GetIndex(x,y)
    --~ 	local biggestDiff = 0.0
    --~ 	for n=1,#nList do
    --~ 		local xx = nList[n][1]
    --~ 		local yy = nList[n][2]
    --~ 		local ii = elevationMap:GetIndex(xx,yy)
    --~ 		local diff = nil
    --~ 		if elevationMap:IsBelowSeaLevel(x,y) then
    --~ 			diff = elevationMap.data[i] - elevationMap.seaLevelThreshold
    --~ 		else
    --~ 			diff = elevationMap.data[i] - elevationMap.data[ii]
    --~ 		end
    --~ 		if diff > biggestDiff then
    --~ 			biggestDiff = diff
    --~ 		end
    --~ 	end
    --~ 	if biggestDiff < 0.0 then
    --~ 		biggestDiff = 0.0
    --~ 	end
    --~ 	return biggestDiff
end

function PlacePossibleOasis(x,y)
    local terrainDesert	= g_TERRAIN_TYPE_DESERT
    local featureOasis = g_FEATURE_OASIS
    local tiles = elevationMap:GetRadiusAroundHex(x,y,1)
    local plot = Map.GetPlot(x,y)
    if not plot:IsHills() and not plot:IsMountain() and plot:GetTerrainType() == terrainDesert then
        local canPlace = true
        for n=1,#tiles do
            local xx = tiles[n][1]
            local yy = tiles[n][2]
            local nPlot = Map.GetPlot(xx,yy)
            if nPlot:GetTerrainType() ~= terrainDesert then
                canPlace = false
                break
            elseif nPlot:GetFeatureType() ~= g_NO_FEATURE then
                canPlace = false
                break
            end
        end
        if canPlace then
            TerrainBuilder.SetFeatureType(plot, featureOasis)
        end
    end
end

function PlacePossibleIce(x,y)
    local featureIce = g_FEATURE_ICE
    local plot = Map.GetPlot(x,y)
    local i = temperatureMap:GetIndex(x,y)
    if plot:IsWater() then
        local temp = temperatureMap.data[i]
        local latitude = temperatureMap:GetLatitudeForY(y)
        --local randval = PWRand() * (mc.iceMaxTemperature - mc.minWaterTemp) + mc.minWaterTemp * 2
        local randvalNorth = PWRand() * (mc.iceNorthLatitudeLimit - mc.topLatitude) + mc.topLatitude - 2
        local randvalSouth = PWRand() * (mc.bottomLatitude - mc.iceSouthLatitudeLimit) + mc.iceSouthLatitudeLimit
        --print(string.format("lat = %f, randvalNorth = %f, randvalSouth = %f",latitude,randvalNorth,randvalSouth))
        if latitude > randvalNorth  or latitude < randvalSouth then
            TerrainBuilder.SetFeatureType(plot, featureIce)
        end
    end
end

function PlacePossibleAtoll(x,y)
    local shallowWater = GameDefines.SHALLOW_WATER_TERRAIN
    local deepWater = GameDefines.DEEP_WATER_TERRAIN
    local featureAtoll = nil
    for thisFeature in GameInfo.Features() do
        if thisFeature.Type == "FEATURE_ATOLL" then
            featureAtoll = thisFeature.ID;
        end
    end
    local plot = Map.GetPlot(x,y)
    local i = temperatureMap:GetIndex(x,y)
    if plot:GetTerrainType() == shallowWater then
        local temp = temperatureMap.data[i]
        local latitude = temperatureMap:GetLatitudeForY(y)
        if latitude < mc.atollNorthLatitudeLimit and latitude > mc.atollSouthLatitudeLimit then
            local tiles = elevationMap:GetRadiusAroundHex(x,y,1)
            local deepCount = 0
            for n=1,#tiles do
                local xx = tiles[n][1]
                local yy = tiles[n][2]
                local nPlot = Map.GetPlot(xx,yy)
                if nPlot:GetTerrainType() == deepWater then
                    deepCount = deepCount + 1
                end
            end
            if deepCount >= mc.atollMinDeepWaterNeighbors then
                plot:SetFeatureType(featureAtoll,-1)
            end
        end
    end
end
-------------------------------------------------------------------------------
--functions that Civ needs
-------------------------------------------------------------------------------
function GetMapScriptInfo()
    local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
    return {
        Name = "PerfectWorld 3",
        Description = "Simulated semi-psuedo-quasi-realistic climate",
        IsAdvancedMap = 0,
        SupportsMultiplayer = false,
        IconIndex = 1,
        SortIndex = 1,
        CustomOptions = {
            {
                Name = "Start Placement",
                Values = {
                    "Start Anywhere",
                    "Largest Continent"
                },
                DefaultValue = 1,
                SortPriority = 1,
            },
            resources
        },
    };
end

--[[
function GetMapInitData(worldSize)
    local worldsizes = {
        [GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {42, 28},
        [GameInfo.Worlds.WORLDSIZE_TINY.ID] = {50, 36},
        [GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {60, 42},
        [GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {80, 56},
        [GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {100, 70},
        [GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {120, 84}
    }
    --~ 	local worldsizes = {
    --~ 		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {50, 36},
    --~ 		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {60, 42},
    --~ 		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {80, 56},
    --~ 		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {100, 70},
    --~ 		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {120, 84},
    --~ 		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {140, 98}
    --~ 		}
    local grid_size = worldsizes[worldSize];
    --
    local world = GameInfo.Worlds[worldSize];
    if(world ~= nil) then
        return {
            Width = grid_size[1],
            Height = grid_size[2],
            WrapX = true,
        };
    end
end
--]]

function GeneratePlotTypes()
    print("Creating initial map data - PerfectWorld3")
    local gridWidth, gridHeight = Map.GetGridSize();
    --first do all the preliminary calculations in this function
    print(string.format("map size: width=%d, height=%d",gridWidth,gridHeight))


    --now gen plot types
    print("Generating plot types - PerfectWorld3")
    local diffMap = FloatMap:New(gridWidth,gridHeight,true,false)
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = diffMap:GetIndex(x,y)
            if elevationMap:IsBelowSeaLevel(x,y) then
                diffMap.data[i] = 0.0
            else
                diffMap.data[i] = GetDifferenceAroundHex(x,y)
            end
        end
    end

    diffMap:Normalize()

    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = diffMap:GetIndex(x,y)
            if elevationMap:IsBelowSeaLevel(x,y) then
                diffMap.data[i] = 0.0
            else
                diffMap.data[i] = diffMap.data[i] + elevationMap.data[i] * 1.1
            end
        end
    end

    diffMap:Normalize()

    --find exact thresholds
    local hillsThreshold = diffMap:FindThresholdFromPercent(mc.hillsPercent,false,true)
    local mountainsThreshold = diffMap:FindThresholdFromPercent(mc.mountainsPercent,false,true)

    local plotTypes = {}

    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = diffMap:GetIndex(x,y)
            if elevationMap:IsBelowSeaLevel(x,y) then
                plotTypes[i] = g_PLOT_TYPE_OCEAN
            elseif diffMap.data[i] < hillsThreshold then
                plotTypes[i] = g_PLOT_TYPE_LAND
            elseif diffMap.data[i] < mountainsThreshold then
                plotTypes[i] = g_PLOT_TYPE_HILLS
            else
                plotTypes[i] = g_PLOT_TYPE_MOUNTAIN
            end
        end
    end

    --Needs to be implemented and executed in GenerateTerrain
    --GenerateCoasts();

    return plotTypes

end

function GenerateTerrain(plotTypes)
    print("Generating terrain - PerfectWorld3")
    local terrainDesert	= g_TERRAIN_TYPE_DESERT
    local terrainPlains	= g_TERRAIN_TYPE_PLAINS
    local terrainSnow	= g_TERRAIN_TYPE_SNOW
    local terrainTundra	= g_TERRAIN_TYPE_TUNDRA
    local terrainGrass	= g_TERRAIN_TYPE_GRASS

    local gridWidth, gridHeight = Map.GetGridSize();
    --first find minimum rain above sea level for a soft desert transition
    local minRain = 100.0
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            if not elevationMap:IsBelowSeaLevel(x,y) then
                if rainfallMap.data[i] < minRain then
                    minRain = rainfallMap.data[i]
                end
            end
        end
    end

    --find exact thresholds
    local desertThreshold = rainfallMap:FindThresholdFromPercent(mc.desertPercent,false,true)
    local plainsThreshold = rainfallMap:FindThresholdFromPercent(mc.plainsPercent,false,true)

    local terrainTypes = {}

    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            if not elevationMap:IsBelowSeaLevel(x,y) then
                if rainfallMap.data[i] < desertThreshold then
                    if temperatureMap.data[i] < mc.snowTemperature then
                        terrainTypes[i] = terrainSnow
                    elseif temperatureMap.data[i] < mc.tundraTemperature then
                        terrainTypes[i] = terrainTundra
                    elseif temperatureMap.data[i] < mc.desertMinTemperature then
                        terrainTypes[i] = terrainPlains
                    else
                        --if rainfallMap.data[i] < (PWRand() * (desertThreshold - minRain) + desertThreshold - minRain)/2.0 + minRain then
                        terrainTypes[i] = terrainDesert
                        --else
                        --plot:SetTerrainType(terrainPlains,false,false)
                        --end
                    end
                elseif rainfallMap.data[i] < plainsThreshold then
                    if temperatureMap.data[i] < mc.snowTemperature then
                        terrainTypes[i] = terrainSnow
                    elseif temperatureMap.data[i] < mc.tundraTemperature then
                        terrainTypes[i] = terrainTundra
                    else
                        if rainfallMap.data[i] < (PWRand() * (plainsThreshold - desertThreshold) + plainsThreshold - desertThreshold)/2.0 + desertThreshold then
                            terrainTypes[i] = terrainPlains
                        else
                            terrainTypes[i] = terrainGrass
                        end
                    end
                else
                    if temperatureMap.data[i] < mc.snowTemperature then
                        terrainTypes[i] = terrainSnow
                    elseif temperatureMap.data[i] < mc.tundraTemperature then
                        terrainTypes[i] = terrainTundra
                    else
                        terrainTypes[i] = terrainGrass
                    end
                end
            else
                if IsAdjacentToLand(plotTypes, x, y) then
                    terrainTypes[i] = g_TERRAIN_TYPE_COAST
                else
                    terrainTypes[i] = g_TERRAIN_TYPE_OCEAN
                end
            end
        end
    end

    return terrainTypes

end

function FinishingTouches(plotTypes, terrainTypes)
    --now we fix things up so that the border of tundra and ice regions are hills
    --this looks a bit more believable. Also keep desert away from tundra and ice
    --by turning it into plains
    local gridWidth, gridHeight = Map.GetGridSize();

    local terrainDesert	= g_TERRAIN_TYPE_DESERT
    local terrainPlains	= g_TERRAIN_TYPE_PLAINS
    local terrainSnow	= g_TERRAIN_TYPE_SNOW
    local terrainTundra	= g_TERRAIN_TYPE_TUNDRA
    local terrainGrass	= g_TERRAIN_TYPE_GRASS

    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            if not elevationMap:IsBelowSeaLevel(x,y) then
                if terrainTypes[i] == terrainSnow then
                    local lowerFound = false
                    for dir = mc.W,mc.SW,1 do
                        local xx,yy = elevationMap:GetNeighbor(x,y,dir)
                        local ii = elevationMap:GetIndex(xx,yy)
                        if ii ~= -1 then
                            local terrainVal = terrainTypes[ii]
                            if not elevationMap:IsBelowSeaLevel(xx,yy) and terrainVal ~= terrainSnow then
                                lowerFound = true
                            end
                            if terrainVal == terrainDesert then
                                plotTypes[ii] = terrainPlains
                            end
                        end
                    end
                    if lowerFound and plotTypes[i] == g_PLOT_TYPE_LAND then
                        plotTypes[i] = g_PLOT_TYPE_HILLS
                    end
                elseif terrainTypes[i] == terrainTundra then
                    local lowerFound = false
                    for dir = mc.W,mc.SW,1 do
                        local xx,yy = elevationMap:GetNeighbor(x,y,dir)
                        local ii = elevationMap:GetIndex(xx,yy)
                        if ii ~= -1 then
                            local terrainVal = terrainTypes[ii]
                            if not elevationMap:IsBelowSeaLevel(xx,yy) and terrainVal ~= terrainSnow and terrainVal ~= terrainTundra then
                                lowerFound = true
                            end
                            if terrainVal == terrainDesert then
                                terrainTypes[ii] = terrainPlains
                            end
                        end
                    end
                    if lowerFound and plotTypes[i] == g_PLOT_TYPE_LAND then
                        plotTypes[i] = g_PLOT_TYPE_HILLS
                    end
                else
                    local higherFound = false
                    for dir = mc.W,mc.SW,1 do
                        local xx,yy = elevationMap:GetNeighbor(x,y,dir)
                        local ii = elevationMap:GetIndex(xx,yy)
                        if ii ~= -1 then
                            local terrainVal = terrainTypes[ii]
                            if terrainVal == terrainSnow or terrainVal == terrainTundra then
                                higherFound = true
                            end
                        end
                    end
                    if higherFound and plotTypes[i] == g_PLOT_TYPE_HILLS then
                        plotTypes[i] = g_PLOT_TYPE_LAND
                    end
                end
            end
        end
    end
end
------------------------------------------------------------------------------
function AddFeatures()
    print("Adding Features PerfectWorld3");

    local terrainPlains	= g_TERRAIN_TYPE_PLAINS
    local featureFloodPlains = g_FEATURE_FLOODPLAINS
    local featureIce = g_FEATURE_ICE
    local featureJungle = g_FEATURE_JUNGLE
    local featureForest = g_FEATURE_FOREST
    local featureOasis = g_FEATURE_OASIS
    local featureMarsh = g_FEATURE_MARSH

    local gridWidth, gridHeight = Map.GetGridSize();

    local zeroTreesThreshold = rainfallMap:FindThresholdFromPercent(mc.zeroTreesPercent,false,true)
    local jungleThreshold = rainfallMap:FindThresholdFromPercent(mc.junglePercent,false,true)
    --local marshThreshold = rainfallMap:FindThresholdFromPercent(marshPercent,false,true)
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local plot = Map.GetPlot(x, y)
            if not plot:IsWater() then
                if rainfallMap.data[i] < jungleThreshold then
                    if not plot:IsMountain() then
                        local treeRange = jungleThreshold - zeroTreesThreshold
                        if rainfallMap.data[i] > PWRand() * treeRange + zeroTreesThreshold then
                            if temperatureMap.data[i] > mc.treesMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureForest)
                            end
                        end
                    end
                else
                    local marshRange = 1.0 - jungleThreshold
                    if rainfallMap.data[i] > PWRand() * marshRange + jungleThreshold and temperatureMap.data[i] > mc.treesMinTemperature then
                        TerrainBuilder.SetTerrainType(plot, g_TERRAIN_TYPE_GRASS)
                        TerrainBuilder.SetFeatureType(plot, featureMarsh)
                    else
                        if not plot:IsMountain() then
                            if temperatureMap.data[i] < mc.jungleMinTemperature and temperatureMap.data[i] > mc.treesMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureForest)
                            elseif temperatureMap.data[i] >= mc.jungleMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureJungle)
                            end
                        end
                    end
                end
                if TerrainBuilder.CanHaveFeature(plot, featureFloodPlains) then
                    TerrainBuilder.SetFeatureType(plot, featureFloodPlains)
                end
            end
        end
    end
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local plot = Map.GetPlot(x, y)
            if not plot:IsWater() then
                PlacePossibleOasis(x,y)
            else
                PlacePossibleIce(x,y)
            end
        end
    end
end

function AddRivers()
    local gridWidth, gridHeight = Map.GetGridSize();
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local plot = Map.GetPlot(x, y)

            local WOfRiver, NWOfRiver, NEOfRiver = riverMap:GetFlowDirections(x,y)

            if WOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION then
                TerrainBuilder.SetWOfRiver(plot, false, WOfRiver)
            else
                local xx,yy = elevationMap:GetNeighbor(x,y,mc.E)
                local nPlot = Map.GetPlot(xx,yy)
                if plot:IsMountain() and nPlot:IsMountain() then
                    TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 2)
                end
                TerrainBuilder.SetWOfRiver(plot, true, WOfRiver)
                --print(string.format("(%d,%d)WOfRiver = true dir=%d",x,y,WOfRiver))
            end

            if NWOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION then
                TerrainBuilder.SetNWOfRiver(plot, false, NWOfRiver)
            else
                local xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
                local nPlot = Map.GetPlot(xx,yy)
                if plot:IsMountain() and nPlot:IsMountain() then
                    TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 2)
                end
                TerrainBuilder.SetNWOfRiver(plot, true, NWOfRiver)
                --print(string.format("(%d,%d)NWOfRiver = true dir=%d",x,y,NWOfRiver))
            end

            if NEOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION then
                TerrainBuilder.SetNEOfRiver(plot, false, NEOfRiver)
            else
                local xx,yy = elevationMap:GetNeighbor(x,y,mc.SW)
                local nPlot = Map.GetPlot(xx,yy)
                if plot:IsMountain() and nPlot:IsMountain() then
                    TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 2)
                end
                TerrainBuilder.SetNEOfRiver(plot, true, NEOfRiver)
                --print(string.format("(%d,%d)NEOfRiver = true dir=%d",x,y,NEOfRiver))
            end
        end
    end
end

function ApplyTerrain(plotTypes, terrainTypes)
    local iW, iH = Map.GetGridSize()
    for i = 0, (iW * iH) - 1, 1 do
        local pPlot = Map.GetPlotByIndex(i)
        if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
            terrainTypes[i] = terrainTypes[i] + 1
        elseif (plotTypes[i] == g_PLOT_TYPE_MOUNTAIN) then
            terrainTypes[i] = terrainTypes[i] + 2
        end
        TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i])
    end
end

function GenerateMap()

    mc = MapConstants:New()
    PWRandSeed()

    local iW, iH = Map.GetGridSize()
    elevationMap = GenerateElevationMap(iW,iH,true,false)
    FillInLakes()
    --elevationMap:Save("elevationMap.csv")

    rainfallMap, temperatureMap = GenerateRainfallMap(elevationMap)
    --rainfallMap:Save("rainfallMap.csv")

    riverMap = RiverMap:New(elevationMap)
    riverMap:SetJunctionAltitudes()
    riverMap:SiltifyLakes()
    riverMap:SetFlowDestinations()
    riverMap:SetRiverSizes(rainfallMap)

    local plotTypes = GeneratePlotTypes()
    local terrainTypes = GenerateTerrain(plotTypes)

    FinishingTouches(plotTypes, terrainTypes)
    ApplyTerrain(plotTypes, terrainTypes)

    AddRivers()
    AddFeatures()
	AreaBuilder.Recalculate()
	AddCliffs(plotTypes, terrainTypes)
	
	local nwGen = NaturalWonderGenerator.Create({
		numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders,
	});

    AreaBuilder.Recalculate()
    TerrainBuilder.AnalyzeChokepoints()
    TerrainBuilder.StampContinents()
	
	resourcesConfig = MapConfiguration.GetValue("resources");
	local resGen = ResourceGenerator.Create({
		resources = resourcesConfig,
		bLandBias = true,
	});

	print("Creating start plot database.");
	local startConfig = MapConfiguration.GetValue("start");
    local start_plot_database = AssignStartingPlots.Create({
		MIN_MAJOR_CIV_FERTILITY = 300,
		MIN_MINOR_CIV_FERTILITY = 50, 
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		START_CONFIG = startConfig,
		LAND = true,
	})

    AddGoodies(iW, iH);

end

--[[
function oceanMatch(x,y)
    local plot = Map.GetPlot(x,y)
    if plot:GetPlotType() == g_PLOT_TYPE_OCEAN then
        return true
    end
    return false
end

function jungleMatch(x,y)
    local terrainGrass	= g_TERRAIN_TYPE_GRASS
    local plot = Map.GetPlot(x,y)
    if plot:GetFeatureType() == g_FEATURE_JUNGLE then
        return true
        --include any mountains on the border as part of the desert.
    elseif (plot:GetFeatureType() == g_FEATURE_MARSH or plot:GetFeatureType() == g_FEATURE_FOREST) and plot:GetTerrainType() == terrainGrass then
        local nList = elevationMap:GetRadiusAroundHex(x,y,1)
        for n=1,#nList do
            local xx = nList[n][1]
            local yy = nList[n][2]
            local ii = elevationMap:GetIndex(xx,yy)
            if 11 ~= -1 then
                local nPlot = Map.GetPlot(xx,yy)
                if nPlot:GetFeatureType() == g_FEATURE_JUNGLE then
                    return true
                end
            end
        end
    end
    return false
end

function desertMatch(x,y)
    local terrainDesert	= g_TERRAIN_TYPE_DESERT
    local plot = Map.GetPlot(x,y)
    if plot:GetTerrainType() == terrainDesert then
        return true
        --include any mountains on the border as part of the desert.
    elseif plot:GetPlotType() == g_PLOT_TYPE_MOUNTAIN then
        local nList = elevationMap:GetRadiusAroundHex(x,y,1)
        for n=1,#nList do
            local xx = nList[n][1]
            local yy = nList[n][2]
            local ii = elevationMap:GetIndex(xx,yy)
            if 11 ~= -1 then
                local nPlot = Map.GetPlot(xx,yy)
                if nPlot:GetPlotType() ~= g_PLOT_TYPE_MOUNTAIN and nPlot:GetTerrainType() == terrainDesert then
                    return true
                end
            end
        end
    end
    return false
end

function DetermineContinents()
    print("Determining continents for art purposes (PerfectWorld)")
    -- Each plot has a continent art type. Mixing and matching these could look
    -- extremely bad, but there is nothing technical to prevent it. The worst
    -- that will happen is that it can't find a blend and draws red checkerboards.

    -- Command for setting the art type for a plot is: <plot object>:SetContinentArtType(<art_set_number>)

    -- CONTINENTAL ART SETS
    -- 0) Ocean
    -- 1) America
    -- 2) Asia
    -- 3) Africa
    -- 4) Europe

    -- Here is an example that sets all land in the world to use the European art set.

    --~ 	for i, plot in Plots() do
    --~ 		if plot:IsWater() then
    --~ 			plot:SetContinentArtType(0)
    --~ 		else
    --~ 			plot:SetContinentArtType(4)
    --~ 		end
    --~ 	end

    local continentMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
    continentMap:DefineAreas(oceanMatch)
    table.sort(continentMap.areaList,function (a,b) return a.size > b.size end)

    --check for jungle
    for y=0,elevationMap.height - 1,1 do
        for x=0,elevationMap.width - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local area = continentMap:GetAreaByID(continentMap.data[i])
            area.hasJungle = false
        end
    end
    for y=0,elevationMap.height - 1,1 do
        for x=0,elevationMap.width - 1,1 do
            local plot = Map.GetPlot(x,y)
            if plot:GetFeatureType() == FeatureTypes.FEATURE_JUNGLE then
                local i = elevationMap:GetIndex(x,y)
                local area = continentMap:GetAreaByID(continentMap.data[i])
                area.hasJungle = true
            end
        end
    end
    local firstArtStyle = PWRandint(1,3)
    print("firstArtStyle = %d",firstArtStyle)
    for n=1,#continentMap.areaList do
        --print(string.format("area[%d] size = %d",n,desertMap.areaList[n].size))
        --		if not continentMap.areaList[n].trueMatch and not continentMap.areaList[n].hasJungle then
        if not continentMap.areaList[n].trueMatch then
            continentMap.areaList[n].artStyle = (firstArtStyle % 4) + 1
            --print(string.format("area[%d] size = %d, artStyle = %d",n,continentMap.areaList[n].size,continentMap.areaList[n].artStyle))
            firstArtStyle = firstArtStyle + 1
        end
    end
    for y=0,elevationMap.height - 1,1 do
        for x=0,elevationMap.width - 1,1 do
            local plot = Map.GetPlot(x,y)
            local i = elevationMap:GetIndex(x,y)
            local area = continentMap:GetAreaByID(continentMap.data[i])
            local artStyle = area.artStyle
            if plot:IsWater() then
                plot:SetContinentArtType(0)
            elseif jungleMatch(x,y) then
                plot:SetContinentArtType(4)
            else
                plot:SetContinentArtType(artStyle)
            end
        end
    end
    --Africa has the best looking deserts, so for the biggest
    --desert use Africa. America has a nice dirty looking desert also, so
    --that should be the second biggest desert.
    local desertMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
    desertMap:DefineAreas(desertMatch)
    table.sort(desertMap.areaList,function (a,b) return a.size > b.size end)
    local largestDesertID = nil
    local secondLargestDesertID = nil
    for n=1,#desertMap.areaList do
        --print(string.format("area[%d] size = %d",n,desertMap.areaList[n].size))
        if desertMap.areaList[n].trueMatch then
            if largestDesertID == nil then
                largestDesertID = desertMap.areaList[n].id
            else
                secondLargestDesertID = desertMap.areaList[n].id
                break
            end
        end
    end
    for y=0,elevationMap.height - 1,1 do
        for x=0,elevationMap.width - 1,1 do
            local plot = Map.GetPlot(x,y)
            local i = elevationMap:GetIndex(x,y)
            if desertMap.data[i] == largestDesertID then
                plot:SetContinentArtType(3)
            elseif desertMap.data[i] == secondLargestDesertID then
                plot:SetContinentArtType(1)
            end
        end
    end

end
--]]

------------------------------------------------------------------------------

--~ mc = MapConstants:New()
--~ PWRandSeed()

--~ elevationMap = GenerateElevationMap(100,70,true,false)
--~ FillInLakes()
--~ elevationMap:Save("elevationMap.csv")

--~ rainfallMap, temperatureMap = GenerateRainfallMap(elevationMap)
--~ temperatureMap:Save("temperatureMap.csv")
--~ rainfallMap:Save("rainfallMap.csv")

--~ riverMap = RiverMap:New(elevationMap)
--~ riverMap:SetJunctionAltitudes()
--~ riverMap:SiltifyLakes()
--~ riverMap:SetFlowDestinations()
--~ riverMap:SetRiverSizes(rainfallMap)



