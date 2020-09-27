
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local lfs = require "lfs"
local os = require "os"
local string = require "string"
local table = require "table"

local assert = assert
local loadfile = loadfile
local pairs = pairs
local setfenv = setfenv

local ANIM_TEMPLATE = common.file_to_str("template/static_templates/anim.template")
local template_params = {}

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
    for filename, path, is_dir in common.directory(dir) do
        if not is_dir then
            local name = common.filename_remove_extension(filename)
            tbl[name] = open_template(path)
        end
    end
    return tbl
end

io.write("Loading templates...\n")
local states_by_name = templates_by_name("template/states/")

local generated_anim_count = 0
local generated_emote_set_count = 0

local function read_combo_file(path)
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

local function open_combo(path)
    local float_curves = {}
    local pptr_curves = {}
    
    local list = read_combo_file(path)
    for i = 1, #list do
        local state = states_by_name[list[i]]
        
        if not state then
            common.errfmt('Unknown state "%s" found in "%s"', list[i], path)
        end
        
        float_curves[#float_curves + 1] = state.float_curves
        pptr_curves[#pptr_curves + 1] = state.pptr_curves
    end
    
    local float = #float_curves > 0 and ("\n" .. table.concat(float_curves, "\n"))
    local pptr = #pptr_curves > 0 and ("\n" .. table.concat(pptr_curves, "\n"))
    
    return float, pptr
end

local emote_count = 0
local function emote_read_recurse(dir)
    local ret = { data_by_name = {}, directories = {} }
    for filename, path, is_dir in common.directory(dir) do
        if not is_dir then
            local float, pptr = open_combo(path)
            local name = common.filename_remove_extension(filename)
            ret.data_by_name[name] = { float = float, pptr = pptr }
            emote_count = emote_count + 1
        else
            ret.directories[filename] = emote_read_recurse(dir .. filename .. "/")
        end
    end
    return ret
end
local emotes = emote_read_recurse("template/emotes/")

local function write_anim_file(path, name, float, pptr)
    template_params.NAME = name
    template_params.FLOAT_CURVES = float or " []"
    template_params.PPTR_CURVES = pptr or " []"
    local data = common.template_replace(ANIM_TEMPLATE, template_params)
    common.write_file(path, data)
end

local function gen_single_gesture_anim(input_path, output_path, name)
    local float, pptr = open_combo(input_path)
    write_anim_file(output_path, name, float, pptr)
    generated_anim_count = generated_anim_count + 1
end

local function gen_anims_for_gesture(name)
    local input_dir = "template/gestures/" .. name .. "/"
    local output_dir = "generated/gestures/" .. name .. "/"
    lfs.mkdir(output_dir)
    
    local left, right
    
    for filename, path, is_dir in common.directory(input_dir) do
        if not is_dir then
            local lower = string.lower(filename)
            
            if not left and string.find(lower, "left") then
                left = true
                gen_single_gesture_anim(path, output_dir .. "left.anim", name .. "_left")
            end
            
            if not right and string.find(lower, "right") then
                right = true
                gen_single_gesture_anim(path, output_dir .. "right.anim", name .. "_right")
            end
            
            if left and right then return end
        end
    end
end

local function emote_gen_recurse(emotes, dir, name, states_float, states_pptr)
    local out_dir = dir .. name .. "/"
    lfs.mkdir(out_dir)
    touch(out_dir .. "_menu.asset")
    
    for emote_name, emote_data in pairs(emotes.data_by_name) do
        local float, pptr
        
        if states_float or emote_data.float then
            float = (states_float or "") .. (emote_data.float or "")
        end
        if states_pptr or emote_data.pptr then
            pptr = (states_pptr or "") .. (emote_data.pptr or "")
        end
        
        local path = out_dir .. emote_name .. ".anim"
        local name = name .." ".. emote_name
        write_anim_file(path, name, float, pptr)
    end
    
    for name, tbl in pairs(emotes.directories) do
        emote_gen_recurse(tbl, out_dir, name, states_float, states_pptr)
    end
end

local function gen_anims_for_combo(filename, input_path, output_path)
    local combo_name = common.filename_remove_extension(filename)
    local states_float, states_pptr = open_combo(input_path)
    
    if emote_count == 0 then
        -- no emotes specified, just make a single animation for this combo
        local path = output_path .. combo_name .. ".anim"
        write_anim_file(path, combo_name, states_float, states_pptr)
        generated_anim_count = generated_anim_count + 1
    else
        -- generate a full set of emotes for each combo
        emote_gen_recurse(emotes, output_path, combo_name, states_float, states_pptr)
        
        generated_emote_set_count = generated_emote_set_count + 1
        generated_anim_count = generated_anim_count + emote_count
    end
end

local function dir_recurse(input_path, output_path)
    for filename, path, is_dir in common.directory(input_path) do
        if is_dir then
            local out_path = output_path .. filename .. "/"
            lfs.mkdir(out_path)
            touch(out_path .. "_menu.asset")
            dir_recurse(path .. "/", out_path)
        else
            gen_anims_for_combo(filename, path, output_path)
        end
    end
end

io.write("Generating animation files...\n")
lfs.mkdir("generated/gestures/")
common.for_each_gesture_name_and_value(gen_anims_for_gesture)

lfs.mkdir("generated/combos/")
dir_recurse("template/combos/", "generated/combos/")

touch("generated/_CHECK_UNITY_META")

-- post-generation report --
io.write(string.format("Generated %d anims in %d emote sets (%0.3f sec)\n", 
                        generated_anim_count,
                        generated_emote_set_count,
                        os.clock()))

-- reminder
io.write('\nFOCUS YOUR UNITY PROJECT AND WAIT A FEW SECONDS FOR IT TO FINISH "Importing small assets" BEFORE RUNNING STEP 2\n')
