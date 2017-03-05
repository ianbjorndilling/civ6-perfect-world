--Returns a value along a bell curve from a 0 - 1 range
function MapConstants:GetBellCurve(value)
    return math.sin(value * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5
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
