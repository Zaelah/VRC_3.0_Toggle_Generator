
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local lfs = require "lfs"
local os = require "os"
local string = require "string"
local table = require "table"

local assert = assert
local error = error
local loadfile = loadfile
local pairs = pairs
local setfenv = setfenv

local ANIM_TEMPLATE = common.file_to_str("template/static_templates/anim.template")

local function touch(path)
    local file = assert(io.open(path, "wb+"))
    file:close()
end

local function open_template(path)
    local env = {}
    local func = assert(loadfile(path))
    setfenv(func, env)
    func()
    if env.float_curves then
        env.float_curves = (string.gsub(env.float_curves, "%s+$", ""))
    end
    if env.pptr_curves then
        env.pptr_curves = (string.gsub(env.pptr_curves, "%s+$", ""))
    end
    return env
end

local function templates_by_name(dir)
    local tbl = {}
    for path in lfs.dir(dir) do
        if common.is_excluded_filename(path) then
            goto continue
        end
        
        local name = string.match(path, "(.+)%.lua")
        tbl[name] = open_template(dir .. path)
        
        ::continue::
    end
    return tbl
end

io.write("Loading templates...\n")
local emotes_by_name = templates_by_name("template/emotes/")
local states_by_name = templates_by_name("template/states/")

local generated_anim_count = 0
local generated_combo_count = 0

local function newline_str_or_blank(str)
    if str and str ~= "" then
        return "\n" .. str
    end
    return ""
end

local function open_combo(path)
    -- one entry per line, lines starting with '#' are comments
    local ret = {}
    for line in io.lines(path) do
        local str = string.match(line, "^%s*(.-)%s*$")
        if str and #str > 0 and not string.find(str, "^#") then
            ret[#ret + 1] = str
        end
    end
    return ret
end

local function gen_anims_for_combo(filename, input_path, output_path)
    local dir_name = string.match(filename, "(.+)%.txt")
    local out_dir = output_path .. dir_name .. "/"
    lfs.mkdir(out_dir)
    touch(out_dir .. "_menu.asset")
    
    local states_list = open_combo(input_path)
    local states_data = {}
    local anim_count = 0
    
    local state_float_curves = {}
    local state_pptr_curves = {}
    
    for i = 1, #states_list do
        local state = states_by_name[states_list[i]]
        
        if not state then
            common.errfmt('Unknown state "%s" found in "%s"', states_list[i], input_path)
        end
        
        state_float_curves[#state_float_curves + 1] = state.float_curves
        state_pptr_curves[#state_pptr_curves + 1] = state.pptr_curves
    end
    
    local states_float = #state_float_curves > 0 and table.concat(state_float_curves, "\n")
    local states_pptr = #state_pptr_curves > 0 and table.concat(state_pptr_curves, "\n")
    for emote_name, emote_data in pairs(emotes_by_name) do
        local float, pptr
        
        if states_float or emote_data.float_curves then
            float = newline_str_or_blank(states_float) .. newline_str_or_blank(emote_data.float_curves)
        end
        if states_pptr or emote_data.pptr_curves then
            pptr = newline_str_or_blank(states_pptr) .. newline_str_or_blank(emote_data.pptr_curves)
        end
        
        local data = ANIM_TEMPLATE
        
        data = string.gsub(data, "$NAME", dir_name .." ".. emote_name)
        data = string.gsub(data, "$FLOAT_CURVES", float or " []")
        data = string.gsub(data, "$PPTR_CURVES", pptr or " []")
        
        local file = assert(io.open(out_dir .. emote_name .. ".anim", "wb+"))
        file:write(data)
        file:close()
        
        anim_count = anim_count + 1
    end
    
    generated_anim_count = generated_anim_count + anim_count
    generated_combo_count = generated_combo_count + 1
end

local function dir_recurse(input_path, output_path)
    for filename in lfs.dir(input_path) do
        if common.is_excluded_filename(filename) then goto continue end
        local path = input_path .. filename
        
        if lfs.attributes(path, "mode") == "directory" then
            local out_path = output_path .. filename .. "/"
            lfs.mkdir(out_path)
            touch(out_path .. "_menu.asset")
            dir_recurse(path .. "/", out_path)
            goto continue
        end
        
        gen_anims_for_combo(filename, path, output_path)
        
        ::continue::
    end
end

io.write("Generating animation files...\n")
dir_recurse("template/combos/", "generated/")

touch("generated/_CHECK_UNITY_META")

-- post-generation report --
io.write(string.format("Generated %d anims in %d sets (%0.3f sec)\n", 
                        generated_anim_count,
                        generated_combo_count,
                        os.clock()))
