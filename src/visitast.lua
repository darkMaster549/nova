-- ============================================================
-- NovaCrypt Obfuscator
-- visitast.lua
-- ============================================================
local Ast = require("src.ast")
local AstKind = Ast.AstKind

local function visitNode(node, preVisit, postVisit, data)
    if not node or type(node)~="table" then return node end

    local newNode = preVisit and preVisit(node, data) or node
    if newNode ~= nil then node = newNode end

    local k = node.kind

    if k==AstKind.Block then
        for i,stmt in ipairs(node.statements) do
            node.statements[i] = visitNode(stmt, preVisit, postVisit, data) or stmt
        end
    elseif k==AstKind.TopNode then
        node.body = visitNode(node.body, preVisit, postVisit, data) or node.body
    elseif k==AstKind.DoStatement then
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.WhileStatement or k==AstKind.RepeatStatement then
        node.condition=visitNode(node.condition,preVisit,postVisit,data) or node.condition
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.ForStatement then
        node.initialValue=visitNode(node.initialValue,preVisit,postVisit,data) or node.initialValue
        node.finalValue=visitNode(node.finalValue,preVisit,postVisit,data) or node.finalValue
        node.incrementBy=visitNode(node.incrementBy,preVisit,postVisit,data) or node.incrementBy
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.ForInStatement then
        for i,e in ipairs(node.expressions) do node.expressions[i]=visitNode(e,preVisit,postVisit,data) or e end
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.IfStatement then
        node.condition=visitNode(node.condition,preVisit,postVisit,data) or node.condition
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
        for i,eif in ipairs(node.elseifs) do
            eif.condition=visitNode(eif.condition,preVisit,postVisit,data) or eif.condition
            eif.body=visitNode(eif.body,preVisit,postVisit,data) or eif.body
        end
        if node.elsebody then node.elsebody=visitNode(node.elsebody,preVisit,postVisit,data) or node.elsebody end
    elseif k==AstKind.FunctionDeclaration or k==AstKind.LocalFunctionDeclaration then
        for i,a in ipairs(node.args) do node.args[i]=visitNode(a,preVisit,postVisit,data) or a end
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.FunctionLiteralExpression then
        for i,a in ipairs(node.args) do node.args[i]=visitNode(a,preVisit,postVisit,data) or a end
        node.body=visitNode(node.body,preVisit,postVisit,data) or node.body
    elseif k==AstKind.LocalVariableDeclaration then
        for i,e in ipairs(node.expressions) do node.expressions[i]=visitNode(e,preVisit,postVisit,data) or e end
    elseif k==AstKind.AssignmentStatement then
        for i,e in ipairs(node.lhs) do node.lhs[i]=visitNode(e,preVisit,postVisit,data) or e end
        for i,e in ipairs(node.rhs) do node.rhs[i]=visitNode(e,preVisit,postVisit,data) or e end
    elseif k==AstKind.ReturnStatement then
        for i,e in ipairs(node.args) do node.args[i]=visitNode(e,preVisit,postVisit,data) or e end
    elseif k==AstKind.FunctionCallStatement then
        node.base=visitNode(node.base,preVisit,postVisit,data) or node.base
        for i,a in ipairs(node.args) do node.args[i]=visitNode(a,preVisit,postVisit,data) or a end
    elseif k==AstKind.PassSelfFunctionCallStatement then
        node.base=visitNode(node.base,preVisit,postVisit,data) or node.base
        for i,a in ipairs(node.args) do node.args[i]=visitNode(a,preVisit,postVisit,data) or a end
    elseif k==AstKind.FunctionCallExpression or k==AstKind.PassSelfFunctionCallExpression then
        node.base=visitNode(node.base,preVisit,postVisit,data) or node.base
        for i,a in ipairs(node.args) do node.args[i]=visitNode(a,preVisit,postVisit,data) or a end
    elseif k==AstKind.IndexExpression or k==AstKind.AssignmentIndexing then
        node.base=visitNode(node.base,preVisit,postVisit,data) or node.base
        node.index=visitNode(node.index,preVisit,postVisit,data) or node.index
    elseif k==AstKind.TableConstructorExpression then
        for i,entry in ipairs(node.entries) do
            if entry.kind==AstKind.KeyedTableEntry then
                entry.key=visitNode(entry.key,preVisit,postVisit,data) or entry.key
            end
            entry.value=visitNode(entry.value,preVisit,postVisit,data) or entry.value
        end
    elseif node.lhs and node.rhs then
        node.lhs=visitNode(node.lhs,preVisit,postVisit,data) or node.lhs
        node.rhs=visitNode(node.rhs,preVisit,postVisit,data) or node.rhs
    elseif node.rhs then
        node.rhs=visitNode(node.rhs,preVisit,postVisit,data) or node.rhs
    end

    local result = postVisit and postVisit(node, data) or node
    if result ~= nil then node = result end
    return node
end

return function(ast, preVisit, postVisit, data)
    data = data or {}
    visitNode(ast, preVisit, postVisit, data)
end
