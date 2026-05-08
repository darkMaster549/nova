-- ============================================================
-- NovaCrypt Obfuscator
-- pipeline.lua
-- ============================================================
local Parser   = require("src.parser")
local Unparser = require("src.unparser")

local Pipeline = {}

function Pipeline:new()
    local p = {
        parser   = Parser:new(),
        unparser = Unparser:new(),
        steps    = {},
    }
    setmetatable(p, self); self.__index = self
    return p
end

function Pipeline:addStep(step)
    table.insert(self.steps, step)
end

function Pipeline:apply(code)
    math.randomseed(os.time())

    
    local ast = self.parser:parse(code)

    
    for _, step in ipairs(self.steps) do
        step:apply(ast, self)
    end

    
    return self.unparser:unparse(ast)
end

return Pipeline
