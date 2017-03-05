include("FloatMap")
include("Utils")

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
