-- ============================================================
-- NovaCrypt Obfuscator
-- parser.lua
-- ============================================================
local Tokenizer = require("src.tokenizer")
local Ast = require("src.ast")
local Scope = require("src.scope")

local AstKind = Ast.AstKind
local Parser = {}

local function err(self, msg)
    local tk = self.tokens[math.min(self.index, self.length)] or {}
    error("Parse error at line "..(tk.line or "?")..": "..msg)
end

local function peek(self, n)
    local i = self.index + (n or 0) + 1
    if i > self.length then return Tokenizer.EOF_TOKEN end
    return self.tokens[i]
end

local function get(self)
    if self.index >= self.length then err(self,"Unexpected EOF") end
    self.index = self.index + 1
    return self.tokens[self.index]
end

local function is(self, kind, src, n)
    local token = peek(self, n or 0)
    if type(src)=="number" then n=src; src=nil; token=peek(self,n) end
    if token.kind~=kind then return false end
    if src and token.source~=src then return false end
    return true
end

local function consume(self, kind, src)
    if is(self, kind, src) then self.index=self.index+1; return true end
    return false
end

local function expect(self, kind, src)
    if is(self, kind, src) then return get(self) end
    local tk=peek(self)
    err(self, string.format("expected <%s> %s, got <%s> '%s'", kind, src or "", tk.kind, tk.source))
end

function Parser:new()
    local p = {
        tokenizer=Tokenizer:new(), tokens={}, length=0, index=0
    }
    setmetatable(p,self); self.__index=self
    return p
end

function Parser:parse(code)
    self.tokens = self.tokenizer:scanAll(code)
    self.length = #self.tokens
    self.index = 0
    local gs = Scope:newGlobal()
    local body = self:block(gs, false)
    expect(self,"Eof")
    self.tokens={}; self.index=0; self.length=0
    return Ast.TopNode(body, gs)
end

function Parser:block(parentScope, currentLoop, scope)
    scope = scope or Scope:new(parentScope)
    local stmts = {}
    repeat
        local stmt, isTerm = self:statement(scope, currentLoop)
        if stmt then table.insert(stmts, stmt) end
    until isTerm or not stmt
    consume(self,"Symbol",";")
    return Ast.Block(stmts, scope)
end

function Parser:statement(scope, currentLoop)
    while consume(self,"Symbol",";") do end

    if consume(self,"Keyword","break") then
        return Ast.BreakStatement(currentLoop,scope), true
    end
    if consume(self,"Keyword","continue") then
        return Ast.ContinueStatement(currentLoop,scope), true
    end
    if consume(self,"Keyword","do") then
        local body=self:block(scope,currentLoop)
        expect(self,"Keyword","end")
        return Ast.DoStatement(body)
    end
    if consume(self,"Keyword","while") then
        local cond=self:expression(scope)
        expect(self,"Keyword","do")
        local stat=Ast.WhileStatement(nil,cond,scope)
        stat.body=self:block(scope,stat)
        expect(self,"Keyword","end")
        return stat
    end
    if consume(self,"Keyword","repeat") then
        local rscope=Scope:new(scope)
        local stat=Ast.RepeatStatement(nil,nil,scope)
        stat.body=self:block(nil,stat,rscope)
        expect(self,"Keyword","until")
        stat.condition=self:expression(rscope)
        return stat
    end
    if consume(self,"Keyword","return") then
        local args={}
        if not is(self,"Keyword","end") and not is(self,"Keyword","elseif")
        and not is(self,"Keyword","else") and not is(self,"Symbol",";")
        and not is(self,"Eof") then
            args=self:exprList(scope)
        end
        return Ast.ReturnStatement(args), true
    end
    if consume(self,"Keyword","if") then
        local cond=self:expression(scope)
        expect(self,"Keyword","then")
        local body=self:block(scope,currentLoop)
        local elseifs={}
        while consume(self,"Keyword","elseif") do
            local ec=self:expression(scope)
            expect(self,"Keyword","then")
            local eb=self:block(scope,currentLoop)
            table.insert(elseifs,{condition=ec,body=eb})
        end
        local elsebody=nil
        if consume(self,"Keyword","else") then
            elsebody=self:block(scope,currentLoop)
        end
        expect(self,"Keyword","end")
        return Ast.IfStatement(cond,body,elseifs,elsebody)
    end
    if consume(self,"Keyword","function") then
        local obj=self:funcName(scope)
        local fscope=Scope:new(scope)
        expect(self,"Symbol","(")
        local args=self:funcArgList(fscope)
        expect(self,"Symbol",")")
        if obj.passSelf then
            local id=fscope:addVariable("self",obj.token)
            table.insert(args,1,Ast.VariableExpression(fscope,id))
        end
        local body=self:block(nil,false,fscope)
        expect(self,"Keyword","end")
        return Ast.FunctionDeclaration(obj.scope,obj.id,obj.indices,args,body)
    end
    if consume(self,"Keyword","local") then
        if consume(self,"Keyword","function") then
            local ident=expect(self,"Ident")
            local id=scope:addVariable(ident.value,ident)
            local fscope=Scope:new(scope)
            expect(self,"Symbol","(")
            local args=self:funcArgList(fscope)
            expect(self,"Symbol",")")
            local body=self:block(nil,false,fscope)
            expect(self,"Keyword","end")
            return Ast.LocalFunctionDeclaration(scope,id,args,body)
        end
        local ids=self:nameList(scope)
        local exprs={}
        if consume(self,"Symbol","=") then exprs=self:exprList(scope) end
        self:enableNameList(scope,ids)
        return Ast.LocalVariableDeclaration(scope,ids,exprs)
    end
    if consume(self,"Keyword","for") then
        if is(self,"Symbol","=",1) then
            local fscope=Scope:new(scope)
            local ident=expect(self,"Ident")
            local vid=fscope:addDisabledVariable(ident.value,ident)
            expect(self,"Symbol","=")
            local init=self:expression(scope)
            expect(self,"Symbol",",")
            local fin=self:expression(scope)
            local inc=Ast.NumberExpression(1)
            if consume(self,"Symbol",",") then inc=self:expression(scope) end
            local stat=Ast.ForStatement(fscope,vid,init,fin,inc,nil,scope)
            fscope:enableVariable(vid)
            expect(self,"Keyword","do")
            stat.body=self:block(nil,stat,fscope)
            expect(self,"Keyword","end")
            return stat
        end
        local fscope=Scope:new(scope)
        local ids=self:nameList(fscope)
        expect(self,"Keyword","in")
        local exprs=self:exprList(scope)
        self:enableNameList(fscope,ids)
        expect(self,"Keyword","do")
        local stat=Ast.ForInStatement(fscope,ids,exprs,nil,scope)
        stat.body=self:block(nil,stat,fscope)
        expect(self,"Keyword","end")
        return stat
    end

    local expr=self:primaryExpression(scope)
    if expr then
        if expr.kind==AstKind.FunctionCallExpression then
            return Ast.FunctionCallStatement(expr.base,expr.args)
        end
        if expr.kind==AstKind.PassSelfFunctionCallExpression then
            return Ast.PassSelfFunctionCallStatement(expr.base,expr.passSelfFunctionName,expr.args)
        end
        if expr.kind==AstKind.IndexExpression or expr.kind==AstKind.VariableExpression then
            if expr.kind==AstKind.IndexExpression then expr.kind=AstKind.AssignmentIndexing end
            if expr.kind==AstKind.VariableExpression then expr.kind=AstKind.AssignmentVariable end
            local lhs={expr}
            while consume(self,"Symbol",",") do
                local e=self:primaryExpression(scope)
                if e.kind==AstKind.IndexExpression then e.kind=AstKind.AssignmentIndexing end
                if e.kind==AstKind.VariableExpression then e.kind=AstKind.AssignmentVariable end
                table.insert(lhs,e)
            end
            expect(self,"Symbol","=")
            local rhs=self:exprList(scope)
            return Ast.AssignmentStatement(lhs,rhs)
        end
    end
    return nil
end

function Parser:primaryExpression(scope)
    local saved=self.index
    local ok,val=pcall(function() return self:exprFuncCall(scope) end)
    if ok then return val end
    self.index=saved
    return nil
end

function Parser:exprList(scope)
    local exprs={self:expression(scope)}
    while consume(self,"Symbol",",") do table.insert(exprs,self:expression(scope)) end
    return exprs
end

function Parser:nameList(scope)
    local ids={}
    local ident=expect(self,"Ident")
    table.insert(ids,scope:addDisabledVariable(ident.value,ident))
    while consume(self,"Symbol",",") do
        ident=expect(self,"Ident")
        table.insert(ids,scope:addDisabledVariable(ident.value,ident))
    end
    return ids
end

function Parser:enableNameList(scope,list)
    for _,id in ipairs(list) do scope:enableVariable(id) end
end

function Parser:funcName(scope)
    local ident=expect(self,"Ident")
    local bscope,bid=scope:resolve(ident.value)
    local indices={}; local passSelf=false
    while consume(self,"Symbol",".") do table.insert(indices,expect(self,"Ident").value) end
    if consume(self,"Symbol",":") then
        table.insert(indices,expect(self,"Ident").value)
        passSelf=true
    end
    return {scope=bscope,id=bid,indices=indices,passSelf=passSelf,token=ident}
end

function Parser:funcArgList(scope)
    local args={}
    if consume(self,"Symbol","...") then table.insert(args,Ast.VarargExpression()); return args end
    if is(self,"Ident") then
        local ident=get(self)
        local id=scope:addVariable(ident.value,ident)
        table.insert(args,Ast.VariableExpression(scope,id))
        while consume(self,"Symbol",",") do
            if consume(self,"Symbol","...") then table.insert(args,Ast.VarargExpression()); return args end
            ident=get(self); id=scope:addVariable(ident.value,ident)
            table.insert(args,Ast.VariableExpression(scope,id))
        end
    end
    return args
end

function Parser:expression(scope) return self:exprOr(scope) end

function Parser:exprOr(scope)
    local lhs=self:exprAnd(scope)
    if consume(self,"Keyword","or") then return Ast.OrExpression(lhs,self:exprOr(scope),true) end
    return lhs
end
function Parser:exprAnd(scope)
    local lhs=self:exprCmp(scope)
    if consume(self,"Keyword","and") then return Ast.AndExpression(lhs,self:exprAnd(scope),true) end
    return lhs
end
function Parser:exprCmp(scope)
    local curr=self:exprStrCat(scope)
    local found=true
    while found do
        found=false
        if consume(self,"Symbol","<") then curr=Ast.LessThanExpression(curr,self:exprStrCat(scope),true); found=true end
        if consume(self,"Symbol",">") then curr=Ast.GreaterThanExpression(curr,self:exprStrCat(scope),true); found=true end
        if consume(self,"Symbol","<=") then curr=Ast.LessThanOrEqualsExpression(curr,self:exprStrCat(scope),true); found=true end
        if consume(self,"Symbol",">=") then curr=Ast.GreaterThanOrEqualsExpression(curr,self:exprStrCat(scope),true); found=true end
        if consume(self,"Symbol","~=") then curr=Ast.NotEqualsExpression(curr,self:exprStrCat(scope),true); found=true end
        if consume(self,"Symbol","==") then curr=Ast.EqualsExpression(curr,self:exprStrCat(scope),true); found=true end
    end
    return curr
end
function Parser:exprStrCat(scope)
    local lhs=self:exprAddSub(scope)
    if consume(self,"Symbol","..") then return Ast.StrCatExpression(lhs,self:exprStrCat(scope),true) end
    return lhs
end
function Parser:exprAddSub(scope)
    local curr=self:exprMulDiv(scope)
    local found=true
    while found do
        found=false
        if consume(self,"Symbol","+") then curr=Ast.AddExpression(curr,self:exprMulDiv(scope),true); found=true end
        if consume(self,"Symbol","-") then curr=Ast.SubExpression(curr,self:exprMulDiv(scope),true); found=true end
    end
    return curr
end
function Parser:exprMulDiv(scope)
    local curr=self:exprUnary(scope)
    local found=true
    while found do
        found=false
        if consume(self,"Symbol","*") then curr=Ast.MulExpression(curr,self:exprUnary(scope),true); found=true end
        if consume(self,"Symbol","/") then curr=Ast.DivExpression(curr,self:exprUnary(scope),true); found=true end
        if consume(self,"Symbol","%") then curr=Ast.ModExpression(curr,self:exprUnary(scope),true); found=true end
    end
    return curr
end
function Parser:exprUnary(scope)
    if consume(self,"Keyword","not") then return Ast.NotExpression(self:exprUnary(scope),true) end
    if consume(self,"Symbol","#") then return Ast.LenExpression(self:exprUnary(scope),true) end
    if consume(self,"Symbol","-") then return Ast.NegateExpression(self:exprUnary(scope),true) end
    return self:exprPow(scope)
end
function Parser:exprPow(scope)
    local lhs=self:tableOrFuncLiteral(scope)
    if consume(self,"Symbol","^") then return Ast.PowExpression(lhs,self:exprPow(scope),true) end
    return lhs
end
function Parser:tableOrFuncLiteral(scope)
    if is(self,"Symbol","{") then return self:tableConstructor(scope) end
    if is(self,"Keyword","function") then return self:funcLiteral(scope) end
    return self:exprFuncCall(scope)
end
function Parser:funcLiteral(scope)
    expect(self,"Keyword","function")
    local fscope=Scope:new(scope)
    expect(self,"Symbol","(")
    local args=self:funcArgList(fscope)
    expect(self,"Symbol",")")
    local body=self:block(nil,false,fscope)
    expect(self,"Keyword","end")
    return Ast.FunctionLiteralExpression(args,body)
end
function Parser:exprFuncCall(scope, base)
    base=base or self:exprIndex(scope)
    if is(self,"String") then
        local args={Ast.StringExpression(get(self).value)}
        return self:exprFuncCall(scope, Ast.FunctionCallExpression(base,args))
    elseif is(self,"Symbol","{") then
        local args={self:tableConstructor(scope)}
        return self:exprFuncCall(scope, Ast.FunctionCallExpression(base,args))
    elseif consume(self,"Symbol","(") then
        local args={}
        if not is(self,"Symbol",")") then args=self:exprList(scope) end
        expect(self,"Symbol",")")
        local node=Ast.FunctionCallExpression(base,args)
        if is(self,"Symbol",".") or is(self,"Symbol","[") or is(self,"Symbol",":") then
            return self:exprFuncCall(scope, self:exprIndex(scope,node))
        end
        if is(self,"Symbol","(") or is(self,"Symbol","{") or is(self,"String") then
            return self:exprFuncCall(scope,node)
        end
        return node
    end
    return base
end
function Parser:exprIndex(scope, base)
    base=base or self:exprLiteral(scope)
    while consume(self,"Symbol","[") do
        local expr=self:expression(scope)
        expect(self,"Symbol","]")
        base=Ast.IndexExpression(base,expr)
    end
    while consume(self,"Symbol",".") do
        local ident=expect(self,"Ident")
        base=Ast.IndexExpression(base,Ast.StringExpression(ident.value))
        while consume(self,"Symbol","[") do
            local expr=self:expression(scope)
            expect(self,"Symbol","]")
            base=Ast.IndexExpression(base,expr)
        end
    end
    if consume(self,"Symbol",":") then
        local name=expect(self,"Ident").value
        local args={}
        if is(self,"String") then args={Ast.StringExpression(get(self).value)}
        elseif is(self,"Symbol","{") then args={self:tableConstructor(scope)}
        else
            expect(self,"Symbol","(")
            if not is(self,"Symbol",")") then args=self:exprList(scope) end
            expect(self,"Symbol",")")
        end
        local node=Ast.PassSelfFunctionCallExpression(base,name,args)
        if is(self,"Symbol",".") or is(self,"Symbol","[") or is(self,"Symbol",":") then
            return self:exprFuncCall(scope,self:exprIndex(scope,node))
        end
        if is(self,"Symbol","(") or is(self,"Symbol","{") or is(self,"String") then
            return self:exprFuncCall(scope,node)
        end
        return node
    end
    if is(self,"Symbol","(") or is(self,"Symbol","{") or is(self,"String") then
        return self:exprFuncCall(scope,base)
    end
    return base
end
function Parser:exprLiteral(scope)
    if consume(self,"Symbol","(") then
        local expr=self:expression(scope); expect(self,"Symbol",")")
        return expr
    end
    if is(self,"String") then return Ast.StringExpression(get(self).value) end
    if is(self,"Number") then return Ast.NumberExpression(get(self).value) end
    if consume(self,"Keyword","true") then return Ast.BooleanExpression(true) end
    if consume(self,"Keyword","false") then return Ast.BooleanExpression(false) end
    if consume(self,"Keyword","nil") then return Ast.NilExpression() end
    if consume(self,"Symbol","...") then return Ast.VarargExpression() end
    if is(self,"Ident") then
        local ident=get(self)
        local sc,id=scope:resolve(ident.value)
        return Ast.VariableExpression(sc,id)
    end
    error("Unexpected token '"..peek(self).source.."' at line "..(peek(self).line or "?"))
end
function Parser:tableConstructor(scope)
    local entries={}
    expect(self,"Symbol","{")
    while not consume(self,"Symbol","}") do
        if consume(self,"Symbol","[") then
            local k=self:expression(scope); expect(self,"Symbol","]"); expect(self,"Symbol","=")
            local v=self:expression(scope); table.insert(entries,Ast.KeyedTableEntry(k,v))
        elseif is(self,"Ident",0) and is(self,"Symbol","=",1) then
            local k=Ast.StringExpression(get(self).value); expect(self,"Symbol","=")
            local v=self:expression(scope); table.insert(entries,Ast.KeyedTableEntry(k,v))
        else
            table.insert(entries,Ast.TableEntry(self:expression(scope)))
        end
        if not consume(self,"Symbol",";") and not consume(self,"Symbol",",") and not is(self,"Symbol","}") then
            err(self,"expected ',' or ';'")
        end
    end
    return Ast.TableConstructorExpression(entries)
end

return Parser
