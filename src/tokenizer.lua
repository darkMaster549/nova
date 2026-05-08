-- ============================================================
-- NovaCrypt Obfuscator
-- tokenizer.lua
-- ============================================================
local Tokenizer = {}

local Keywords = {
    "and","break","do","else","elseif","end","false","for",
    "function","if","in","local","nil","not","or","repeat",
    "return","then","true","until","while","continue"
}

local function lookupify(tb)
    local out = {}
    for _, v in ipairs(tb) do out[v] = true end
    return out
end

Tokenizer.Keywords = Keywords
Tokenizer.KeywordLookup = lookupify(Keywords)
Tokenizer.TokenKind = {
    Eof="Eof", Keyword="Keyword", Ident="Ident",
    Number="Number", String="String", Symbol="Symbol",
}
Tokenizer.EOF_TOKEN = { kind="Eof", value="", source="" }

function Tokenizer:new()
    local t = { src="", pos=1, line=1, linePos=1 }
    setmetatable(t, self); self.__index = self
    return t
end

function Tokenizer:peek(o)
    return self.src:sub(self.pos+(o or 0), self.pos+(o or 0))
end

function Tokenizer:get()
    local c = self.src:sub(self.pos, self.pos)
    self.pos = self.pos + 1
    if c == "\n" then self.line=self.line+1; self.linePos=1
    else self.linePos=self.linePos+1 end
    return c
end

function Tokenizer:skipWhitespaceAndComments()
    while self.pos <= #self.src do
        local c = self:peek()
        if c==" " or c=="\t" or c=="\r" or c=="\n" then self:get()
        elseif c=="-" and self:peek(1)=="-" then
            self.pos = self.pos + 2
            if self:peek()=="[" then
                local level=0; local p=self.pos+1
                while self.src:sub(p,p)=="=" do level=level+1; p=p+1 end
                if self.src:sub(p,p)=="[" then
                    self.pos=p+1
                    local close="]"..string.rep("=",level).."]"
                    local e=self.src:find(close,self.pos,true)
                    self.pos=e and (e+#close) or (#self.src+1)
                else
                    while self.pos<=#self.src and self:peek()~="\n" do self:get() end
                end
            else
                while self.pos<=#self.src and self:peek()~="\n" do self:get() end
            end
        else break end
    end
end

function Tokenizer:readString(delim)
    self.pos=self.pos+1
    local s=""
    while self.pos<=#self.src do
        local c=self:get()
        if c==delim then break
        elseif c=="\\" then
            local e=self:get()
            if e=="n" then s=s.."\n"
            elseif e=="t" then s=s.."\t"
            elseif e=="r" then s=s.."\r"
            elseif e=="\\" then s=s.."\\"
            elseif e=="\"" then s=s.."\""
            elseif e=="\'" then s=s.."\'"
            elseif e:match("%d") then
                local num=e
                if self:peek():match("%d") then num=num..self:get() end
                if self:peek():match("%d") then num=num..self:get() end
                s=s..string.char(tonumber(num))
            else s=s..e end
        else s=s..c end
    end
    return s
end

function Tokenizer:readLongString()
    local level=0
    self.pos=self.pos+1
    while self:peek()=="=" do level=level+1; self.pos=self.pos+1 end
    self.pos=self.pos+1
    local close="]"..string.rep("=",level).."]"
    local start=self.pos
    local e=self.src:find(close,start,true)
    local s=self.src:sub(start, e and (e-1) or #self.src)
    self.pos=e and (e+#close) or (#self.src+1)
    s=s:gsub("^\n","")
    return s
end

function Tokenizer:next()
    self:skipWhitespaceAndComments()
    if self.pos>#self.src then return Tokenizer.EOF_TOKEN end
    local line=self.line
    local c=self:peek()

    if c=="[" and (self:peek(1)=="[" or self:peek(1)=="=") then
        local save=self.pos; local lvl=0; local p=self.pos+1
        while self.src:sub(p,p)=="=" do lvl=lvl+1; p=p+1 end
        if self.src:sub(p,p)=="[" then
            local s=self:readLongString()
            return {kind="String",value=s,source=s,line=line}
        else self.pos=save end
    end

    if c=="\"" or c=="'" then
        local s=self:readString(c)
        return {kind="String",value=s,source=s,line=line}
    end

    if c:match("%d") or (c=="." and self:peek(1):match("%d")) then
        local s=""
        while self.pos<=#self.src and self:peek():match("[%d%.xXa-fA-F_eEpP%+%-]") do
            s=s..self:get()
        end
        return {kind="Number",value=tonumber(s) or 0,source=s,line=line}
    end

    if c:match("[%a_]") then
        local s=""
        while self.pos<=#self.src and self:peek():match("[%w_]") do s=s..self:get() end
        local kind=Tokenizer.KeywordLookup[s] and "Keyword" or "Ident"
        return {kind=kind,value=s,source=s,line=line}
    end

    local multiSymbols={"...","..","==","~=","<=",">=","+=","-=","*=","/=","//","%=","^=","..="}
    for _,sym in ipairs(multiSymbols) do
        if self.src:sub(self.pos,self.pos+#sym-1)==sym then
            self.pos=self.pos+#sym
            return {kind="Symbol",value=sym,source=sym,line=line}
        end
    end

    local sym=self:get()
    return {kind="Symbol",value=sym,source=sym,line=line}
end

function Tokenizer:scanAll(src)
    self.src=src; self.pos=1; self.line=1; self.linePos=1
    local tokens={}
    while true do
        local tk=self:next()
        table.insert(tokens,tk)
        if tk.kind=="Eof" then break end
    end
    return tokens
end

return Tokenizer
