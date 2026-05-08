-- ============================================================
-- NovaCrypt Obfuscator
-- steps/EncryptStrings.lua
-- ============================================================
local Ast = require("src.ast")
local visitast = require("src.visitast")
local AstKind = Ast.AstKind

local EncryptStrings = {}
EncryptStrings.Name = "EncryptStrings"

function EncryptStrings:new(settings)
    return setmetatable({}, {__index=self})
end

local function fakeVar(name)
    return {
        kind = AstKind.VariableExpression,
        scope = {
            getVariableName = function(self, id) return id end,
            addReference = function() end,
            addReferenceToHigherScope = function() end,
            isGlobal = false,
        },
        id = name,
        isConstant = false,
    }
end

local function buildDecryptNode(s)
    local charNodes = {}
    for i = 1, #s do
        table.insert(charNodes, Ast.NumberExpression(s:byte(i)))
    end
    local strVar = fakeVar("string")
    local charFuncNode = Ast.IndexExpression(strVar, Ast.StringExpression("char"))
    return Ast.FunctionCallExpression(charFuncNode, charNodes)
end

function EncryptStrings:apply(ast, pipeline)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            local s = node.value
            if s and #s > 0 and #s < 200 then
                return buildDecryptNode(s)
            end
        end
    end, {})
end

return EncryptStrings
