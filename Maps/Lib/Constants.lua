
--Percent of land tiles on the map.
g_LAND_PERCENT = 0.28

--Percent of dry land that is below the hill elevation deviance threshold.
g_HILL_PERCENT = 0.50

--Percent of dry land that is below the mountain elevation deviance
--threshold.
g_MOUNTAIN_PERCENT = 0.85


--Percent of land that is below the desert rainfall threshold.
g_DESERT_PERCENT = 0.36
--Coldest absolute temperature allowed to be desert, plains if colder.
g_DESERT_MIN_TEMP = 0.34

--Percent of land that is below the plains rainfall threshold.
g_PLAINS_PERCENT = 0.56

--Absolute temperature below which is snow.
g_SNOW_TEMP = 0.25

--Absolute temperature below which is tundra.
g_TUNDRA_TEMP = 0.30

--North and south ice latitude limits.
g_ICE_NORTH_LAT_LIMIT = 60
g_ICE_SOUTH_LAT_LIMIT = -60

--percent of river junctions that are large enough to become rivers.
g_RIVER_PERCENT = 0.19

--This value is multiplied by each river step. Values greater than one favor
--watershed size. Values less than one favor actual rain amount.
g_RIVER_RAIN_CHEAT_FACTOR = 1.6

--These attenuation factors lower the altitude of the map edges. This is
--currently used to prevent large continents in the uninhabitable polar
--regions. East/west attenuation is set to zero, but modded maps may
--have need for them.
g_NORTH_ATTENUATION_FACTOR = 0.75
g_NORTH_ATTENUATION_RANGE = 0.15 --percent of the map height.
g_SOUTH_ATTENUATION_FACTOR = 0.75
g_SOUTH_ATTENUATION_RANGE = 0.15

--east west attenuation may be desired for flat maps.
g_EAST_ATTENUATION_FACTOR = 0.0
g_EAST_ATTENUATION_RANGE = 0.0 --percent of the map width.
g_WEST_ATTENUATION_FACTOR = 0.0
g_WEST_ATTENUATION_RANGE = 0.0

--These set the water temperature compression that creates the land/sea
--seasonal temperature differences that cause monsoon winds.
g_MIN_WATER_TEMP = 0.10
g_MAX_WATER_TEMP = 0.60

--Top and bottom map latitudes.
g_TOP_LATITUDE = 70
g_BOTTOM_LATITUDE = -70

--Important latitude markers used for generating climate.
g_POLAR_FRONT_LATITUDE = 60
g_TROPICAL_LATITUDES = 23
g_HORSE_LATITUDES = 28 -- I shrunk these a bit to emphasize temperate lattitudes

--Strength of geostrophic climate generation versus monsoon climate
--generation.
g_GEOSTROPHIC_FACTOR = 3.0

g_GEOSTROPHIC_LATERAL_WIND_STRENGH = 0.6

--Fill in any lakes smaller than this. It looks bad to have large
--river systems flowing into a tiny lake.
g_MIN_OCEAN_SIZE = 50

--Weight of the mountain elevation map versus the coastline elevation map.
g_MOUNTAIN_WEIGHT = 0.8

--Crazy rain tweaking variables. I wouldn't touch these if I were you.
g_MIN_RAIN_COST = 0.0001
g_UPLIFT_EXPONENT = 4
g_POLAR_RAIN_BOOST = 0.0

--default frequencies for map of width 128. Adjusting these frequences
--will generate larger or smaller map features.
g_TWIST_MIN_FREQ = 0.02
g_TWIST_MAX_FREQ = 0.12
g_TWIST_VAR = 0.042
g_MOUNTAIN_FREQ = 0.078

-----------------------------------------------------------------------
--Below are map constants that should not be altered.

--directions
Directions = {
    NONE = 0,
    WEST = 1,
    NORTH_WEST = 2,
    NORHT_EAST = 3,
    EAST = 4,
    SOUTH_EAST = 5,
    SOUTH_WEST = 6,
}

g_DIRECTION_COUNT = 6

function GetOppositeDir(dir)
    return ((dir + 2) % 6) + 1
end

--flow directions
FlowDirections = {
    NOFLOW = 0,
    WESTFLOW = 1,
    EASTFLOW = 2,
    VERTFLOW = 3,
};

--wind zones
WindZones = {
    NOZONE = -1,
    NPOLAR = 0,
    NTEMPERATE = 1,
    NEQUATOR = 2,
    SEQUATOR = 3,
    STEMPERATE = 4,
    SPOLAR = 5,
}

--Hex maps are shorter in the y direction than they are
--wide per unit by this much. We need to know this to sample the perlin
--maps properly so they don't look squished.
Y_TO_X_RATIO = 1.5/(math.sqrt(0.75) * 2)
