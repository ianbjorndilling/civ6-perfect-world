include("FloatMap")
include("Utils")

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
            --found the right end of a line segment
        elseif lineFound == 1 then
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

