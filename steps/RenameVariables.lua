-- ============================================================
-- NovaCrypt Obfuscator
-- steps/RenameVariables.lua
-- ============================================================
local AstKind = require("src.ast").AstKind

local RenameVariables = {}
RenameVariables.Name = "RenameVariables"

local HEX = "0123456789abcdef"
local function generateName(id)
    local s = "_N"
    local n = id
    repeat
        local d = (n % 16) + 1
        s = s .. HEX:sub(d,d)
        n = math.floor(n / 16)
    until n == 0
    s = s .. "_"
    return s
end

function RenameVariables:new(settings)
    return setmetatable({}, {__index=self})
end

function RenameVariables:apply(ast, pipeline)
    local keywords = {
        -- Lua keywords
        "and","break","do","else","elseif","end","false","for",
        "function","if","in","local","nil","not","or","repeat",
        "return","then","true","until","while","continue",
        -- Lua standard globals
        "string","table","math","io","os","print","require",
        "pairs","ipairs","next","type","tostring","tonumber",
        "pcall","xpcall","error","assert","select","unpack",
        "rawget","rawset","rawequal","rawlen",
        "setmetatable","getmetatable","collectgarbage",
        "load","loadfile","dofile","loadstring",
        "coroutine","package","debug","utf8",
        "bit32","bit","jit",
        -- Roblox globals
        "game","workspace","script","plugin",
        "Instance","Vector3","Vector2","CFrame",
        "Color3","BrickColor","UDim","UDim2",
        "Ray","Axes","Faces","Region3",
        "TweenInfo","NumberSequence","ColorSequence",
        "NumberRange","Rect","PhysicalProperties",
        "Random","DateTime","task","warn",
        "tick","time","wait","delay","spawn",
        "Enum","shared","_G","_VERSION",
    }

    local counter = 0
    ast.globalScope:renameVariables({
        Keywords = keywords,
        generateName = function(id, scope, original)
            counter = counter + 1
            return generateName(counter)
        end,
        prefix = "",
    })
end

return RenameVariables
