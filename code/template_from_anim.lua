
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local string = require "string"

local path = arg and arg[1]
if not path then
    io.write("Usage: drag and drop a Unity .anim file onto MAKE_TEMPLATE_FROM_ANIM.bat\n")
    return
end

local str = common.file_to_str(path)

local float, pptr = string.match(str, "m_FloatCurves:(.-)[ ]*m_PPtrCurves:(.-)[ ]*m_SampleRate:")

local function process(str)
    if string.find(str, "[ ]*%[%]") then
        return nil
    end
    return (string.match(str, "[\r\n]*(.+)"))
end

float = process(float)
pptr = process(pptr)

if not float and not pptr then
    local fmt = "ERROR: animation file does not contain any Blendshapes, Mesh toggles, or Material swaps: %s\n"
    io.write(string.format(fmt, path))
    return
end

local out = ""
if float then
    out = out .. "float_curves = [[\n" .. float .. "]]\n"
end
if pptr then
    out = out .. "pptr_curves = [[\n" .. pptr .. "]]\n"
end

local refname = string.match(path, "([^/\\]+)%.anim")
local outpath = "template/states/" .. refname .. ".lua"
common.write_file(outpath, out)

io.write(string.format([[
Created animation template "%s"

To combine this template into a toggleable animation in VRChat, add this line
to a combo text file under "template/combos/", an emote text file under
"template/emotes/", or a gesture text file under "template/gestures/":

%s

]], outpath, refname))
