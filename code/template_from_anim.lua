
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local string = require "string"
local table = require "table"

if not arg or not arg[1] then
    io.write("Usage: drag and drop a Unity .anim file onto MAKE_TEMPLATE_FROM_ANIM.bat\n")
    return
end

local function get_refname(path)
    return (string.match(path, "([^/\\]+)%.anim$"))
end

local function process(str)
    if string.find(str, "[ ]*%[%]") then
        return nil
    end
    return (string.match(str, "[\r\n]*(.+)"))
end

local count = 0
local out_paths = {}
local ref_names = {}
local function generate_template(path)
    local refname = get_refname(path)
    if not refname then return end
    count = count + 1
    
    local str = common.file_to_str(path)

    local float, pptr = string.match(str, "m_FloatCurves:(.-)[ ]*m_PPtrCurves:(.-)[ ]*m_SampleRate:")

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

    local outpath = "template/states/" .. refname .. ".lua"
    common.write_file(outpath, out)
    out_paths[count] = outpath
    ref_names[count] = refname
end

for i = 1, #arg do
    generate_template(arg[i])
end

if count == 1 then
    io.write(string.format([[
Created animation template "%s"

To combine this template into a toggleable animation in VRChat, add this line
to a combo text file under "template/combos/", an emote text file under
"template/emotes/", or a gesture text file under "template/gestures/":

%s

]], out_paths[1], ref_names[1]))
elseif count > 1 then
    io.write(string.format([[
Created animation templates:

%s

]], table.concat(ref_names, "\n")))
end
