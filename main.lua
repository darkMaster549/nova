-- ============================================================
-- NovaCrypt Obfuscator
-- main.lua  ( CLI )
-- ============================================================
local Pipeline              = require("pipeline")
local NumbersToExpressions  = require("steps/NumbersToExpressions")
local EncryptStrings        = require("steps/EncryptStrings")
local RenameVariables       = require("steps/RenameVariables")

local inputFile  = arg and arg[1] or "input.lua"
local outputFile = arg and arg[2] or "output.lua"

local f = io.open(inputFile, "r")
if not f then
    print("ERROR: Cannot open " .. inputFile)
    os.exit(1)
end
local code = f:read("*a")
f:close()

local pipeline = Pipeline:new()
pipeline:addStep(EncryptStrings:new({}))
pipeline:addStep(NumbersToExpressions:new({ maxDepth = 4 }))
pipeline:addStep(RenameVariables:new({}))

print("NovaCrypt: Obfuscating " .. inputFile .. " ...")
local result = pipeline:apply(code)

local out = io.open(outputFile, "w")
out:write(result)
out:close()

print("NovaCrypt: Done! Output -> " .. outputFile)
