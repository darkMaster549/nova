-- ============================================================
-- NovaCrypt Obfuscator
-- steps/NumbersToExpressions.lua
-- ============================================================
local Ast = require("src.ast")
local visitast = require("src.visitast")
local AstKind = Ast.AstKind

local NumbersToExpressions = {}
NumbersToExpressions.Name = "NumbersToExpressions"

function NumbersToExpressions:new(settings)
    local s = setmetatable({}, {__index=self})
    s.maxDepth = (settings and settings.maxDepth) or 4
    return s
end

-- Splits a number into a random math expression that evaluates to the same value
local function splitNumber(n, depth, maxDepth)
    if depth >= maxDepth then return Ast.NumberExpression(n) end
    if n ~= math.floor(n) or math.abs(n) > 1e12 then return Ast.NumberExpression(n) end

    local choice = math.random(1, 3)

    if choice == 1 then
        -- a + b = n  =>  pick random a, b = n - a
        local a = math.random(-99999, 99999)
        local b = n - a
        return Ast.AddExpression(
            splitNumber(a, depth+1, maxDepth),
            splitNumber(b, depth+1, maxDepth)
        )
    elseif choice == 2 then
        -- a - b = n  =>  pick random b, a = n + b
        local b = math.random(-99999, 99999)
        local a = n + b
        return Ast.SubExpression(
            splitNumber(a, depth+1, maxDepth),
            splitNumber(b, depth+1, maxDepth)
        )
    else
        -- a * b = n  =>  only if n divisible
        if n ~= 0 then
            local factors = {}
            for i = 2, math.min(math.abs(n), 50) do
                if n % i == 0 then table.insert(factors, i) end
            end
            if #factors > 0 then
                local b = factors[math.random(1, #factors)]
                local a = n / b
                return Ast.MulExpression(
                    splitNumber(a, depth+1, maxDepth),
                    splitNumber(b, depth+1, maxDepth)
                )
            end
        end
        local a = math.random(-99999, 99999)
        local b = n - a
        return Ast.AddExpression(
            splitNumber(a, depth+1, maxDepth),
            splitNumber(b, depth+1, maxDepth)
        )
    end
end

function NumbersToExpressions:apply(ast, pipeline)
    local maxDepth = self.maxDepth
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            local v = node.value
            if type(v) == "number" and v == math.floor(v) and math.abs(v) <= 1e12 then
                return splitNumber(v, 0, maxDepth)
            end
        end
    end, {})
end

return NumbersToExpressions
