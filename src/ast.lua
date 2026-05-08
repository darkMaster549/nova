-- ============================================================
-- NovaCrypt Obfuscator
-- ast.lua
-- ============================================================
local Ast = {}

local AstKind = {
    TopNode="TopNode", Block="Block",
    BreakStatement="BreakStatement", ContinueStatement="ContinueStatement",
    DoStatement="DoStatement", WhileStatement="WhileStatement",
    RepeatStatement="RepeatStatement", ReturnStatement="ReturnStatement",
    ForStatement="ForStatement", ForInStatement="ForInStatement",
    IfStatement="IfStatement", FunctionDeclaration="FunctionDeclaration",
    LocalFunctionDeclaration="LocalFunctionDeclaration",
    LocalVariableDeclaration="LocalVariableDeclaration",
    FunctionCallStatement="FunctionCallStatement",
    PassSelfFunctionCallStatement="PassSelfFunctionCallStatement",
    AssignmentStatement="AssignmentStatement",
    AssignmentIndexing="AssignmentIndexing", AssignmentVariable="AssignmentVariable",
    BooleanExpression="BooleanExpression", NumberExpression="NumberExpression",
    StringExpression="StringExpression", NilExpression="NilExpression",
    VarargExpression="VarargExpression", OrExpression="OrExpression",
    AndExpression="AndExpression", LessThanExpression="LessThanExpression",
    GreaterThanExpression="GreaterThanExpression",
    LessThanOrEqualsExpression="LessThanOrEqualsExpression",
    GreaterThanOrEqualsExpression="GreaterThanOrEqualsExpression",
    NotEqualsExpression="NotEqualsExpression", EqualsExpression="EqualsExpression",
    StrCatExpression="StrCatExpression", AddExpression="AddExpression",
    SubExpression="SubExpression", MulExpression="MulExpression",
    DivExpression="DivExpression", ModExpression="ModExpression",
    NotExpression="NotExpression", LenExpression="LenExpression",
    NegateExpression="NegateExpression", PowExpression="PowExpression",
    IndexExpression="IndexExpression", FunctionCallExpression="FunctionCallExpression",
    PassSelfFunctionCallExpression="PassSelfFunctionCallExpression",
    VariableExpression="VariableExpression",
    FunctionLiteralExpression="FunctionLiteralExpression",
    TableConstructorExpression="TableConstructorExpression",
    TableEntry="TableEntry", KeyedTableEntry="KeyedTableEntry",
    NopStatement="NopStatement",
}

local exprPriority = {
    [AstKind.OrExpression]=12, [AstKind.AndExpression]=11,
    [AstKind.LessThanExpression]=10, [AstKind.GreaterThanExpression]=10,
    [AstKind.LessThanOrEqualsExpression]=10, [AstKind.GreaterThanOrEqualsExpression]=10,
    [AstKind.NotEqualsExpression]=10, [AstKind.EqualsExpression]=10,
    [AstKind.StrCatExpression]=9, [AstKind.AddExpression]=8,
    [AstKind.SubExpression]=8, [AstKind.MulExpression]=7,
    [AstKind.DivExpression]=7, [AstKind.ModExpression]=7,
    [AstKind.NotExpression]=5, [AstKind.LenExpression]=5,
    [AstKind.NegateExpression]=5, [AstKind.PowExpression]=4,
    [AstKind.IndexExpression]=1, [AstKind.AssignmentIndexing]=1,
    [AstKind.FunctionCallExpression]=2, [AstKind.PassSelfFunctionCallExpression]=2,
    [AstKind.FunctionLiteralExpression]=3, [AstKind.TableConstructorExpression]=3,
    [AstKind.VariableExpression]=0, [AstKind.AssignmentVariable]=0,
    [AstKind.BooleanExpression]=0, [AstKind.NumberExpression]=0,
    [AstKind.StringExpression]=0, [AstKind.NilExpression]=0,
    [AstKind.VarargExpression]=0,
}

Ast.AstKind = AstKind
function Ast.exprPriority(kind) return exprPriority[kind] or 100 end

function Ast.ConstantNode(v)
    if type(v)=="nil" then return Ast.NilExpression()
    elseif type(v)=="string" then return Ast.StringExpression(v)
    elseif type(v)=="number" then return Ast.NumberExpression(v)
    elseif type(v)=="boolean" then return Ast.BooleanExpression(v) end
end

function Ast.TopNode(body,gs) return {kind=AstKind.TopNode,body=body,globalScope=gs} end
function Ast.Block(stmts,scope) return {kind=AstKind.Block,statements=stmts,scope=scope} end
function Ast.NopStatement() return {kind=AstKind.NopStatement} end
function Ast.BreakStatement(loop,scope) return {kind=AstKind.BreakStatement,loop=loop,scope=scope} end
function Ast.ContinueStatement(loop,scope) return {kind=AstKind.ContinueStatement,loop=loop,scope=scope} end
function Ast.DoStatement(body) return {kind=AstKind.DoStatement,body=body} end
function Ast.WhileStatement(body,cond,ps) return {kind=AstKind.WhileStatement,body=body,condition=cond,parentScope=ps} end
function Ast.RepeatStatement(cond,body,ps) return {kind=AstKind.RepeatStatement,body=body,condition=cond,parentScope=ps} end
function Ast.ReturnStatement(args) return {kind=AstKind.ReturnStatement,args=args} end
function Ast.ForStatement(scope,id,init,fin,inc,body,ps) return {kind=AstKind.ForStatement,scope=scope,id=id,initialValue=init,finalValue=fin,incrementBy=inc,body=body,parentScope=ps} end
function Ast.ForInStatement(scope,vars,exprs,body,ps) return {kind=AstKind.ForInStatement,scope=scope,ids=vars,vars=vars,expressions=exprs,body=body,parentScope=ps} end
function Ast.IfStatement(cond,body,elseifs,elsebody) return {kind=AstKind.IfStatement,condition=cond,body=body,elseifs=elseifs,elsebody=elsebody} end
function Ast.FunctionDeclaration(scope,id,indices,args,body) return {kind=AstKind.FunctionDeclaration,scope=scope,baseScope=scope,id=id,baseId=id,indices=indices,args=args,body=body} end
function Ast.LocalFunctionDeclaration(scope,id,args,body) return {kind=AstKind.LocalFunctionDeclaration,scope=scope,id=id,args=args,body=body} end
function Ast.LocalVariableDeclaration(scope,ids,exprs) return {kind=AstKind.LocalVariableDeclaration,scope=scope,ids=ids,expressions=exprs} end
function Ast.FunctionCallStatement(base,args) return {kind=AstKind.FunctionCallStatement,base=base,args=args} end
function Ast.PassSelfFunctionCallStatement(base,name,args) return {kind=AstKind.PassSelfFunctionCallStatement,base=base,passSelfFunctionName=name,args=args} end
function Ast.AssignmentStatement(lhs,rhs) return {kind=AstKind.AssignmentStatement,lhs=lhs,rhs=rhs} end
function Ast.VarargExpression() return {kind=AstKind.VarargExpression,isConstant=false} end
function Ast.BooleanExpression(v) return {kind=AstKind.BooleanExpression,isConstant=true,value=v} end
function Ast.NilExpression() return {kind=AstKind.NilExpression,isConstant=true,value=nil} end
function Ast.NumberExpression(v) return {kind=AstKind.NumberExpression,isConstant=true,value=v} end
function Ast.StringExpression(v) return {kind=AstKind.StringExpression,isConstant=true,value=v} end
function Ast.TableEntry(v) return {kind=AstKind.TableEntry,value=v} end
function Ast.KeyedTableEntry(k,v) return {kind=AstKind.KeyedTableEntry,key=k,value=v} end
function Ast.TableConstructorExpression(entries) return {kind=AstKind.TableConstructorExpression,entries=entries} end
function Ast.IndexExpression(base,idx) return {kind=AstKind.IndexExpression,base=base,index=idx,isConstant=false} end
function Ast.AssignmentIndexing(base,idx) return {kind=AstKind.AssignmentIndexing,base=base,index=idx,isConstant=false} end
function Ast.FunctionCallExpression(base,args) return {kind=AstKind.FunctionCallExpression,base=base,args=args} end
function Ast.PassSelfFunctionCallExpression(base,name,args) return {kind=AstKind.PassSelfFunctionCallExpression,base=base,passSelfFunctionName=name,args=args} end
function Ast.FunctionLiteralExpression(args,body) return {kind=AstKind.FunctionLiteralExpression,args=args,body=body} end
function Ast.VariableExpression(scope,id) scope:addReference(id); return {kind=AstKind.VariableExpression,scope=scope,id=id} end
function Ast.AssignmentVariable(scope,id) scope:addReference(id); return {kind=AstKind.AssignmentVariable,scope=scope,id=id} end

local function binExpr(kind)
    return function(lhs,rhs,simplify)
        if simplify and lhs.isConstant and rhs.isConstant then
            local ops={
                [AstKind.AddExpression]=function(a,b) return a+b end,
                [AstKind.SubExpression]=function(a,b) return a-b end,
                [AstKind.MulExpression]=function(a,b) return a*b end,
                [AstKind.DivExpression]=function(a,b) if b~=0 then return a/b end end,
                [AstKind.ModExpression]=function(a,b) return a%b end,
                [AstKind.PowExpression]=function(a,b) return a^b end,
                [AstKind.StrCatExpression]=function(a,b) return a..b end,
                [AstKind.EqualsExpression]=function(a,b) return a==b end,
                [AstKind.NotEqualsExpression]=function(a,b) return a~=b end,
                [AstKind.LessThanExpression]=function(a,b) return a<b end,
                [AstKind.GreaterThanExpression]=function(a,b) return a>b end,
                [AstKind.LessThanOrEqualsExpression]=function(a,b) return a<=b end,
                [AstKind.GreaterThanOrEqualsExpression]=function(a,b) return a>=b end,
                [AstKind.AndExpression]=function(a,b) return a and b end,
                [AstKind.OrExpression]=function(a,b) return a or b end,
            }
            local f=ops[kind]
            if f then
                local ok,v=pcall(f,lhs.value,rhs.value)
                if ok and v~=nil then return Ast.ConstantNode(v) end
            end
        end
        return {kind=kind,lhs=lhs,rhs=rhs,isConstant=false}
    end
end

Ast.OrExpression=binExpr(AstKind.OrExpression)
Ast.AndExpression=binExpr(AstKind.AndExpression)
Ast.LessThanExpression=binExpr(AstKind.LessThanExpression)
Ast.GreaterThanExpression=binExpr(AstKind.GreaterThanExpression)
Ast.LessThanOrEqualsExpression=binExpr(AstKind.LessThanOrEqualsExpression)
Ast.GreaterThanOrEqualsExpression=binExpr(AstKind.GreaterThanOrEqualsExpression)
Ast.NotEqualsExpression=binExpr(AstKind.NotEqualsExpression)
Ast.EqualsExpression=binExpr(AstKind.EqualsExpression)
Ast.StrCatExpression=binExpr(AstKind.StrCatExpression)
Ast.AddExpression=binExpr(AstKind.AddExpression)
Ast.SubExpression=binExpr(AstKind.SubExpression)
Ast.MulExpression=binExpr(AstKind.MulExpression)
Ast.DivExpression=binExpr(AstKind.DivExpression)
Ast.ModExpression=binExpr(AstKind.ModExpression)
Ast.PowExpression=binExpr(AstKind.PowExpression)

function Ast.NotExpression(rhs,simplify)
    if simplify and rhs.isConstant then
        local ok,v=pcall(function() return not rhs.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.NotExpression,rhs=rhs,isConstant=false}
end
function Ast.NegateExpression(rhs,simplify)
    if simplify and rhs.isConstant then
        local ok,v=pcall(function() return -rhs.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.NegateExpression,rhs=rhs,isConstant=false}
end
function Ast.LenExpression(rhs,simplify)
    if simplify and rhs.isConstant then
        local ok,v=pcall(function() return #rhs.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.LenExpression,rhs=rhs,isConstant=false}
end

return Ast
