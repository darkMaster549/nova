-- ============================================================
-- NovaCrypt Obfuscator
-- unparser.lua
-- ============================================================
local Ast = require("src.ast")
local AstKind = Ast.AstKind

local Keywords = {
    "and","break","do","else","elseif","end","false","for",
    "function","if","in","local","nil","not","or","repeat",
    "return","then","true","until","while","continue"
}
local kwLookup={}
for _,v in ipairs(Keywords) do kwLookup[v]=true end

local Unparser = {}

local function escapeStr(s)
    s=s:gsub("\\","\\\\")
    s=s:gsub("\"","\\\"")
    s=s:gsub("\n","\\n")
    s=s:gsub("\r","\\r")
    s=s:gsub("\t","\\t")
    s=s:gsub("([^\32-\126])", function(c)
        return string.format("\\%03d", c:byte())
    end)
    return s
end

local function isValidIdent(s)
    if kwLookup[s] then return false end
    return s:match("^[%a_][%w_]*$") ~= nil
end

function Unparser:new()
    local u={}; setmetatable(u,self); self.__index=self; return u
end

function Unparser:unparse(ast)
    assert(ast.kind==AstKind.TopNode,"Expected TopNode")
    return self:unparseBlock(ast.body)
end

function Unparser:unparseBlock(block)
    local parts={}
    for _,stmt in ipairs(block.statements) do
        if stmt.kind~=AstKind.NopStatement then
            table.insert(parts, self:unparseStatement(stmt))
        end
    end
    return table.concat(parts,"\n")
end

function Unparser:unparseStatement(stmt)
    local k=stmt.kind
    if k==AstKind.BreakStatement then
        return "break"
    elseif k==AstKind.ContinueStatement then
        return "continue"
    elseif k==AstKind.DoStatement then
        return "do\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.WhileStatement then
        return "while "..self:unparseExpr(stmt.condition).." do\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.RepeatStatement then
        return "repeat\n"..self:unparseBlock(stmt.body).."\nuntil "..self:unparseExpr(stmt.condition)
    elseif k==AstKind.ReturnStatement then
        if #stmt.args==0 then return "return" end
        local parts={}
        for _,a in ipairs(stmt.args) do table.insert(parts,self:unparseExpr(a)) end
        return "return "..table.concat(parts,",")
    elseif k==AstKind.ForStatement then
        local s="for "..stmt.scope:getVariableName(stmt.id).."="
        s=s..self:unparseExpr(stmt.initialValue)..","..self:unparseExpr(stmt.finalValue)
        if stmt.incrementBy then s=s..","..self:unparseExpr(stmt.incrementBy) end
        return s.." do\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.ForInStatement then
        local vars={}
        for _,id in ipairs(stmt.ids) do table.insert(vars,stmt.scope:getVariableName(id)) end
        local exprs={}
        for _,e in ipairs(stmt.expressions) do table.insert(exprs,self:unparseExpr(e)) end
        return "for "..table.concat(vars,",").." in "..table.concat(exprs,",").." do\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.IfStatement then
        local s="if "..self:unparseExpr(stmt.condition).." then\n"..self:unparseBlock(stmt.body)
        for _,eif in ipairs(stmt.elseifs) do
            s=s.."\nelseif "..self:unparseExpr(eif.condition).." then\n"..self:unparseBlock(eif.body)
        end
        if stmt.elsebody then s=s.."\nelse\n"..self:unparseBlock(stmt.elsebody) end
        return s.."\nend"
    elseif k==AstKind.FunctionDeclaration then
        local name=stmt.scope:getVariableName(stmt.id)
        for _,idx in ipairs(stmt.indices) do name=name.."."..idx end
        local args={}
        for _,a in ipairs(stmt.args) do
            if a.kind==AstKind.VarargExpression then table.insert(args,"...")
            else table.insert(args,a.scope:getVariableName(a.id)) end
        end
        return "function "..name.."("..table.concat(args,",")..")\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.LocalFunctionDeclaration then
        local name=stmt.scope:getVariableName(stmt.id)
        local args={}
        for _,a in ipairs(stmt.args) do
            if a.kind==AstKind.VarargExpression then table.insert(args,"...")
            else table.insert(args,a.scope:getVariableName(a.id)) end
        end
        return "local function "..name.."("..table.concat(args,",")..")\n"..self:unparseBlock(stmt.body).."\nend"
    elseif k==AstKind.LocalVariableDeclaration then
        local vars={}
        for _,id in ipairs(stmt.ids) do table.insert(vars,stmt.scope:getVariableName(id)) end
        local s="local "..table.concat(vars,",")
        if #stmt.expressions>0 then
            local exprs={}
            for _,e in ipairs(stmt.expressions) do table.insert(exprs,self:unparseExpr(e)) end
            s=s.."="..table.concat(exprs,",")
        end
        return s
    elseif k==AstKind.FunctionCallStatement then
        local base
        if stmt.base.kind==AstKind.IndexExpression or stmt.base.kind==AstKind.VariableExpression then
            base=self:unparseExpr(stmt.base)
        else
            base="("..self:unparseExpr(stmt.base)..")"
        end
        local args={}
        for _,a in ipairs(stmt.args) do table.insert(args,self:unparseExpr(a)) end
        return base.."("..table.concat(args,",")..")"
    elseif k==AstKind.PassSelfFunctionCallStatement then
        local base
        if stmt.base.kind==AstKind.IndexExpression or stmt.base.kind==AstKind.VariableExpression then
            base=self:unparseExpr(stmt.base)
        else
            base="("..self:unparseExpr(stmt.base)..")"
        end
        local args={}
        for _,a in ipairs(stmt.args) do table.insert(args,self:unparseExpr(a)) end
        return base..":"..stmt.passSelfFunctionName.."("..table.concat(args,",")..")"
    elseif k==AstKind.AssignmentStatement then
        local lhs={}; local rhs={}
        for _,e in ipairs(stmt.lhs) do table.insert(lhs,self:unparseExpr(e)) end
        for _,e in ipairs(stmt.rhs) do table.insert(rhs,self:unparseExpr(e)) end
        return table.concat(lhs,",").."="..table.concat(rhs,",")
    end
    return ""
end

function Unparser:unparseExpr(expr, parentPriority)
    parentPriority = parentPriority or 0
    local k=expr.kind
    local pri=Ast.exprPriority(k)

    if k==AstKind.BooleanExpression then
        return expr.value and "true" or "false"
    elseif k==AstKind.NilExpression then
        return "nil"
    elseif k==AstKind.VarargExpression then
        return "..."
    elseif k==AstKind.NumberExpression then
        local s=tostring(expr.value)
        if s=="inf" then return "2e1024" end
        if s=="-inf" then return "-2e1024" end
        return s
    elseif k==AstKind.StringExpression then
        return '"'..escapeStr(expr.value)..'"'
    elseif k==AstKind.VariableExpression or k==AstKind.AssignmentVariable then
        return expr.scope:getVariableName(expr.id)
    elseif k==AstKind.IndexExpression or k==AstKind.AssignmentIndexing then
        local base=self:unparseExpr(expr.base)
        if expr.index.kind==AstKind.StringExpression and isValidIdent(expr.index.value) then
            return base.."."..expr.index.value
        end
        return base.."["..self:unparseExpr(expr.index).."]"
    elseif k==AstKind.FunctionCallExpression then
        local base
        if expr.base.kind==AstKind.IndexExpression or expr.base.kind==AstKind.VariableExpression then
            base=self:unparseExpr(expr.base)
        else
            base="("..self:unparseExpr(expr.base)..")"
        end
        local args={}
        for _,a in ipairs(expr.args) do table.insert(args,self:unparseExpr(a)) end
        return base.."("..table.concat(args,",")..")"
    elseif k==AstKind.PassSelfFunctionCallExpression then
        local base
        if expr.base.kind==AstKind.IndexExpression or expr.base.kind==AstKind.VariableExpression then
            base=self:unparseExpr(expr.base)
        else
            base="("..self:unparseExpr(expr.base)..")"
        end
        local args={}
        for _,a in ipairs(expr.args) do table.insert(args,self:unparseExpr(a)) end
        return base..":"..expr.passSelfFunctionName.."("..table.concat(args,",")..")"
    elseif k==AstKind.FunctionLiteralExpression then
        local args={}
        for _,a in ipairs(expr.args) do
            if a.kind==AstKind.VarargExpression then table.insert(args,"...")
            else table.insert(args,a.scope:getVariableName(a.id)) end
        end
        return "function("..table.concat(args,",")..")\n"..self:unparseBlock(expr.body).."\nend"
    elseif k==AstKind.TableConstructorExpression then
        if #expr.entries==0 then return "{}" end
        local parts={}
        for _,entry in ipairs(expr.entries) do
            if entry.kind==AstKind.KeyedTableEntry then
                local key=entry.key
                if key.kind==AstKind.StringExpression and isValidIdent(key.value) then
                    table.insert(parts,key.value.."="..self:unparseExpr(entry.value))
                else
                    table.insert(parts,"["..self:unparseExpr(key).."]="..self:unparseExpr(entry.value))
                end
            else
                table.insert(parts,self:unparseExpr(entry.value))
            end
        end
        return "{"..table.concat(parts,",").."}"
    elseif k==AstKind.NotExpression then
        return "not "..self:unparseExpr(expr.rhs,5)
    elseif k==AstKind.NegateExpression then
        local rhs=self:unparseExpr(expr.rhs,5)
        if rhs:sub(1,1)=="-" then
            return "-("..rhs..")"
        end
        return "-"..rhs
    elseif k==AstKind.LenExpression then
        return "#"..self:unparseExpr(expr.rhs,5)
    else
        local ops={
            [AstKind.OrExpression]="or",
            [AstKind.AndExpression]="and",
            [AstKind.LessThanExpression]="<",
            [AstKind.GreaterThanExpression]=">",
            [AstKind.LessThanOrEqualsExpression]="<=",
            [AstKind.GreaterThanOrEqualsExpression]=">=",
            [AstKind.NotEqualsExpression]="~=",
            [AstKind.EqualsExpression]="==",
            [AstKind.StrCatExpression]="..",
            [AstKind.AddExpression]="+",
            [AstKind.SubExpression]="-",
            [AstKind.MulExpression]="*",
            [AstKind.DivExpression]="/",
            [AstKind.ModExpression]="%",
            [AstKind.PowExpression]="^",
        }
        local op=ops[k]
        if op then
            local lhs=self:unparseExpr(expr.lhs,pri)
            local rhs=self:unparseExpr(expr.rhs,pri)

            local s
            if op=="or" or op=="and" then
                -- keywords need spaces
                s=lhs.." "..op.." "..rhs
            elseif op=="-" and (rhs:sub(1,1)=="-" or rhs:sub(1,1)=="(") then
                -- prevent -- becoming comment
                s=lhs.."-("..rhs..")"
            elseif op==".." then
                -- prevent ..X being parsed wrong if X starts with dot or number
                s=lhs..".."..rhs
            else
                s=lhs..op..rhs
            end

            if pri>0 and parentPriority>0 and pri>=parentPriority then
                return "("..s..")"
            end
            return s
        end
    end
    return "nil"
end

return Unparser
