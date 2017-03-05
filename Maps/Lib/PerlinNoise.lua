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

