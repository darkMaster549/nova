-- ============================================================
-- NovaCrypt Obfuscator
-- scope.lua
-- ============================================================
local Scope = {}

local nameIdx = 0
local function nextScopeName()
    nameIdx = nameIdx + 1
    return "scope_" .. nameIdx
end

local varIdx = 1

function Scope:new(parent)
    local s = {
        isGlobal=false, parentScope=parent,
        variables={}, variablesLookup={},
        referenceCounts={}, skipIdLookup={},
        variablesFromHigherScopes={},
        children={}, name=nextScopeName(),
        level=(parent.level or 0)+1,
    }
    setmetatable(s,self); self.__index=self
    parent:addChild(s)
    return s
end

function Scope:newGlobal()
    local s = {
        isGlobal=true, parentScope=nil,
        variables={}, variablesLookup={},
        referenceCounts={}, skipIdLookup={},
        variablesFromHigherScopes={},
        children={}, name="global_scope", level=0,
    }
    setmetatable(s,self); self.__index=self
    return s
end

function Scope:addVariable(name, token)
    if not name then
        name = string.format("v%d", varIdx); varIdx=varIdx+1
    end
    table.insert(self.variables, name)
    local id = #self.variables
    self.variablesLookup[name] = id
    return id
end

function Scope:addDisabledVariable(name, token)
    if not name then
        name = string.format("v%d", varIdx); varIdx=varIdx+1
    end
    table.insert(self.variables, name)
    return #self.variables
end

function Scope:enableVariable(id)
    local name = self.variables[id]
    if name then self.variablesLookup[name] = id end
end

function Scope:hasVariable(name)
    if self.isGlobal then
        if not self.variablesLookup[name] then self:addVariable(name) end
        return true
    end
    return self.variablesLookup[name] ~= nil
end

function Scope:resolve(name)
    if self:hasVariable(name) then return self, self.variablesLookup[name] end
    assert(self.parentScope, "No global scope!")
    local scope,id = self.parentScope:resolve(name)
    self:addReferenceToHigherScope(scope,id,nil,true)
    return scope,id
end

function Scope:resolveGlobal(name)
    if self.isGlobal and self:hasVariable(name) then return self, self.variablesLookup[name] end
    assert(self.parentScope, "No global scope!")
    local scope,id = self.parentScope:resolveGlobal(name)
    self:addReferenceToHigherScope(scope,id,nil,true)
    return scope,id
end

function Scope:getVariableName(id) return self.variables[id] end
function Scope:removeVariable(id)
    local name=self.variables[id]
    self.variables[id]=nil; self.variablesLookup[name]=nil
    self.skipIdLookup[id]=true
end

function Scope:addReference(id)
    self.referenceCounts[id]=(self.referenceCounts[id] or 0)+1
end
function Scope:removeReference(id)
    self.referenceCounts[id]=(self.referenceCounts[id] or 0)-1
end
function Scope:getReferences(id) return self.referenceCounts[id] or 0 end
function Scope:resetReferences(id) self.referenceCounts[id]=0 end

function Scope:addReferenceToHigherScope(scope,id,n,b)
    n=n or 1
    if self.isGlobal then return end
    if scope==self then self.referenceCounts[id]=(self.referenceCounts[id] or 0)+n; return end
    if not self.variablesFromHigherScopes[scope] then self.variablesFromHigherScopes[scope]={} end
    local r=self.variablesFromHigherScopes[scope]
    r[id]=(r[id] or 0)+n
    if not b then self.parentScope:addReferenceToHigherScope(scope,id,n) end
end

function Scope:addChild(child)
    for scope,ids in pairs(child.variablesFromHigherScopes) do
        for id,count in pairs(ids) do
            if count and count>0 then self:addReferenceToHigherScope(scope,id,count) end
        end
    end
    table.insert(self.children,child)
end

function Scope:setParent(parent)
    self.parentScope:removeChild(self)
    parent:addChild(self)
    self.parentScope=parent
    self.level=parent.level+1
end

function Scope:removeChild(child)
    for i,v in ipairs(self.children) do
        if v==child then table.remove(self.children,i); return end
    end
end

function Scope:getMaxId() return #self.variables end
function Scope:clearReferences() self.referenceCounts={}; self.variablesFromHigherScopes={} end

function Scope:renameVariables(settings)
    if not self.isGlobal then
        local forbidden={}
        for _,kw in pairs(settings.Keywords) do forbidden[kw]=true end
        for scope,ids in pairs(self.variablesFromHigherScopes) do
            for id,count in pairs(ids) do
                if count and count>0 then
                    local n=scope:getVariableName(id)
                    if n then forbidden[n]=true end
                end
            end
        end
        self.variablesLookup={}
        local i=0
        for id,originalName in pairs(self.variables) do
            if not self.skipIdLookup[id] and (self.referenceCounts[id] or 0)>=0 then
                local name
                repeat
                    name=(settings.prefix or "")..settings.generateName(i,self,originalName)
                    i=i+1
                until not forbidden[name]
                self.variables[id]=name
                self.variablesLookup[name]=id
            end
        end
    end
    for _,child in pairs(self.children) do child:renameVariables(settings) end
end

return Scope
