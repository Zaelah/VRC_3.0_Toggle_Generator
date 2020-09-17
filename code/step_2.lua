
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local os = require "os"
local string = require "string"
local table = require "table"

local pairs = pairs
local tostring = tostring

local MAX_ENTRIES_PER_MENU = 8

local MENU_ENTRY_TYPE_TOGGLE = "102"
local MENU_ENTRY_TYPE_SUBMENU = "103"

local check = io.open("generated/_CHECK_UNITY_META.meta")
if not check then
    io.write("ERROR: Open or give focus to the Unity project and wait for it to generate .meta files!\n")
    return
end
check:close()
os.remove("generated/_CHECK_UNITY_META")
os.remove("generated/_CHECK_UNITY_META.meta")

local MENU_HEADER = common.file_to_str("template/static_templates/menu_header.template")
local MENU_ENTRY = common.file_to_str("template/static_templates/menu_entry.template")
local PARAM_HEADER = common.file_to_str("template/static_templates/parameters_header.template")
local PARAM_ENTRY = common.file_to_str("template/static_templates/parameters_entry.template")
local PARAM_DRIVER_HEADER = common.file_to_str("template/static_templates/param_driver_header.template")
local PARAM_DRIVER_ENTRY = common.file_to_str("template/static_templates/param_driver_entry.template")
local CTRL_PARAM_ENTRY = common.file_to_str("template/static_templates/param_entry.template")
local CTRL_TOGGLE_ENTRY = common.file_to_str("template/static_templates/anim_toggle.template")
local CTRL_ANIM_STATE_ENTRY = common.file_to_str("template/static_templates/anim_state_id_entry.template")
local CTRL_BEGIN_STATE_ENTRY = common.file_to_str("template/static_templates/begin_state_id_entry.template")

local function get_guid(path)
    local str = common.file_to_str(path .. ".meta")
    local guid = string.match(str, "guid:%s*([^%s]+)")
    if not guid then
        common.errfmt("no guid for file '%s'", path)
    end
    return guid
end

local file_id = 2000000000000000000ULL
local function next_file_id()
    file_id = file_id + 1
    return string.sub(tostring(file_id), 1, -4) -- remove "ULL" suffix
end

local ctrl_params = {}
local ctrl_toggles = {}
local ctrl_anim_state_ids = {}
local ctrl_begin_state_ids = {}
local param_entries = {}
local param_letter_by_driver_id = {}

local function add_param_bookkeeping(name, driver_id)
    ctrl_params[#ctrl_params + 1] = string.gsub(CTRL_PARAM_ENTRY, "$PARAM_NAME", name)
    param_entries[#param_entries + 1] = string.gsub(PARAM_ENTRY, "$NAME", name)
    param_letter_by_driver_id[driver_id] = name
end

add_param_bookkeeping("GestureLeft", next_file_id())
add_param_bookkeeping("GestureRight", next_file_id())

local param_letter = string.char(string.byte("A") - 1)
local param_value = 255
local param_driver_id
local function next_param()
    param_value = param_value + 1
    if param_value > 255 then
        param_letter = string.char(string.byte(param_letter) + 1)
        param_value = 1
        param_driver_id = next_file_id()
        
        add_param_bookkeeping(param_letter, param_driver_id)
    end
    return param_letter, tostring(param_value), param_driver_id
end

local emotes = {}
for filename in common.directory("template/emotes/") do
    local name = string.match(filename, "(.+)%.lua")
    emotes[#emotes + 1] = name
end
table.sort(emotes)

if #emotes > MAX_ENTRIES_PER_MENU then
    io.write(string.format('ERROR: too many emotes in "template/emotes/", max is %d, got %d\n',
        MAX_ENTRIES_PER_MENU, #emotes))
    return
end

local function gen_submenu(name, guid)
    local entry = MENU_ENTRY
    entry = string.gsub(entry, "$NAME", name)
    entry = string.gsub(entry, "$ENTRY_TYPE", MENU_ENTRY_TYPE_SUBMENU)
    entry = string.gsub(entry, "$PARAM_NAME", " ")
    entry = string.gsub(entry, "$PARAM_VALUE", "1")
    local submenu = string.format("{fileID: 11400000, guid: %s, type: 2}", guid)
    entry = string.gsub(entry, "$SUBMENU", submenu)
    return entry
end

local function gen_state_machine_entry(param_name, param_value, anim_guid, param_driver_id)
    local begin_id = next_file_id()
    local end_id = next_file_id()
    local anim_id = next_file_id()
    
    local toggle = CTRL_TOGGLE_ENTRY
    toggle = string.gsub(toggle, "$PARAM_NAME", param_name)
    toggle = string.gsub(toggle, "$PARAM_VALUE", param_value)
    toggle = string.gsub(toggle, "$ANIM_GUID", anim_guid)
    toggle = string.gsub(toggle, "$ANIM_NAME", param_name .. param_value)
    toggle = string.gsub(toggle, "$BEGIN_STATE_ID", begin_id)
    toggle = string.gsub(toggle, "$END_STATE_ID", end_id)
    toggle = string.gsub(toggle, "$ANIM_STATE_ID", anim_id)
    local param_driver = param_driver_id and ("\n  - {fileID: ".. param_driver_id .."}")
    toggle = string.gsub(toggle, "$PARAM_DRIVER_ID", param_driver or " []")
    ctrl_toggles[#ctrl_toggles + 1] = toggle
    
    local begin_entry = CTRL_BEGIN_STATE_ENTRY
    begin_entry = string.gsub(begin_entry, "$BEGIN_STATE_ID", begin_id)
    ctrl_begin_state_ids[#ctrl_begin_state_ids + 1] = begin_entry
    
    local anim_entry = CTRL_ANIM_STATE_ENTRY
    anim_entry = string.gsub(anim_entry, "$ANIM_STATE_ID", anim_id)
    ctrl_anim_state_ids[#ctrl_anim_state_ids + 1] = anim_entry
end

local function gen_menu_toggle_entry(name, guid)
    local param_letter, param_value, param_driver_id = next_param()
    
    local entry = MENU_ENTRY
    entry = string.gsub(entry, "$NAME", name)
    entry = string.gsub(entry, "$ENTRY_TYPE", MENU_ENTRY_TYPE_TOGGLE)
    entry = string.gsub(entry, "$PARAM_NAME", param_letter)
    entry = string.gsub(entry, "$PARAM_VALUE", param_value)
    entry = string.gsub(entry, "$SUBMENU", "{fileID: 0}")
    
    -- create corresponding state machine entry for this anim
    gen_state_machine_entry(param_letter, param_value, guid, param_driver_id)
    return entry
end

local function gen_single_gesture_state_machine(path, param_name, param_value)
    local guid = get_guid(path)
    gen_state_machine_entry(param_name, param_value, guid)
end

local function gen_state_machine_entries_for_gesture(name, param_value)
    local input_dir = "template/gestures/" .. name .. "/"
    local output_dir = "generated/gestures/" .. name .. "/"
    
    local left, right
    
    for filename, path, is_dir in common.directory(input_dir) do
        if not is_dir then
            local lower = string.lower(filename)
            
            if not left and string.find(lower, "left") then
                left = true
                gen_single_gesture_state_machine(output_dir .. "left.anim", "GestureLeft", param_value)
            end
            
            if not right and string.find(lower, "right") then
                right = true
                gen_single_gesture_state_machine(output_dir .. "right.anim", "GestureRight", param_value)
            end
            
            if left and right then return end
        end
    end
end

-- The function that does most of the heavy lifting.
--
-- We know all of our anim files have already been generated by step_1.lua and sorted into directories
-- under generated/. Here we are tracing the same path, only this time we are generating menu-entries
-- for each animation, and all of the intermediate menus leading to them.
--
-- For each child directory or combo file we find under 'template/combos':
--     * If it's a child directory, create a _menu.asset file underneath the corresponding child directory
--       under generated/, and add a submenu entry pointing to it to the menu representing the directory
--       we are currently traversing. Then recurse into that child directory and repeat in order to
--       fill up the newly created _menu.asset.
--
--     * If it's a combo file and we have emotes under 'template/emotes', create a _menu.asset file in the
--       directory under generated/ corresponding to that combo file, and create menu entries pointing to
--       each animation (one for each emote under 'template/emotes') in that menu file. This is also where
--       parameter names and values are assigned for each animation. This is also also where a state
--       machine entry for each animation is created in the FXLayer animation controller.
--
--     * If it's a combo file and we don't have emotes under 'template/emotes', create an entry in the
--       menu representing the directory currently being traversed corresponding to that combo's anim
--       file and do all the plumping work for the parameter names and values, and FXLayer animation
--       controller.
local function dir_recurse(input_path, output_path, menu_name)
    local entries = {}
    
    for filename, path, is_dir in common.directory(input_path) do
        -- for directories, create a new menu file under that directory and recurse to fill it up
        if is_dir then
            local out_path = output_path .. filename .. "/"
            local menu_path = out_path .. "_menu.asset"
            
            -- each directory should already contain a "_menu.asset" file with its own meta file
            local guid = get_guid(menu_path)
            entries[#entries + 1] = gen_submenu(filename, guid)
            
            dir_recurse(path .. "/", out_path)
            goto continue
        end
        
        local combo_name = string.match(filename, "(.+)%.txt")
        
        if #emotes == 0 then
            -- for combo files without emotes, create one menu entry for the combo anim
            local anim_path = output_path .. combo_name .. ".anim"
            local guid = get_guid(anim_path)
            entries[#entries + 1] = gen_menu_toggle_entry(combo_name, guid)
        else
            -- for combo files with emotes, create a menu corresponding to the combo file
            -- and fill it with toggles for each emote
            local output_emote_path = output_path .. combo_name .. "/"
            local guid = get_guid(output_emote_path .. "_menu.asset")
            entries[#entries + 1] = gen_submenu(combo_name, guid)
            
            local entries = {}
            
            for i = 1, #emotes do
                local emote_name = emotes[i]
                local guid = get_guid(output_emote_path .. emote_name .. ".anim")
                entries[#entries + 1] = gen_menu_toggle_entry(emote_name, guid)
            end
            
            local data = MENU_HEADER
            data = string.gsub(data, "$NAME", "Menu")
            data = string.gsub(data, "$ENTRIES", table.concat(entries))
            common.write_file(output_emote_path .. "_menu.asset", data)
        end
        
        ::continue::
    end
    
    if #entries > MAX_ENTRIES_PER_MENU then
        io.write(string.format('ERROR: too many combo files and/or folders in "%s", max is %d, got %d\n',
            input_path, MAX_ENTRIES_PER_MENU, #entries))
        os.exit()
    end
    
    menu_name = menu_name or "_menu.asset"
    local pretty_name = string.match(menu_name, "(.+)%.asset")
    local data = MENU_HEADER
    data = string.gsub(data, "$NAME", pretty_name)
    data = string.gsub(data, "$ENTRIES", table.concat(entries))
    common.write_file(output_path .. menu_name, data)
end

io.write("Generating Menu.asset...\n")
dir_recurse("template/combos/", "generated/combos/", "../Menu.asset")

io.write("Generating Gestures (if any)...\n")
common.for_each_gesture_name_and_value(gen_state_machine_entries_for_gesture)

-- generate parameter drivers
local ctrl_param_drivers = {}
local entries_by_letter = {}
for _, a in pairs(param_letter_by_driver_id) do
    local e = {}
    entries_by_letter[a] = e
    for _, b in pairs(param_letter_by_driver_id) do
        if a ~= b then
            e[#e + 1] = string.gsub(PARAM_DRIVER_ENTRY, "$PARAM_NAME", b)
        end
    end
end

for driver_id, letter in pairs(param_letter_by_driver_id) do
    local header = PARAM_DRIVER_HEADER
    header = string.gsub(header, "$PARAM_DRIVER_ID", driver_id)
    local entries = entries_by_letter[letter]
    local entries_str = #entries > 0 and ("\n" .. table.concat(entries, "\n")) or " []"
    header = string.gsub(header, "$ENTRIES", entries_str)
    ctrl_param_drivers[#ctrl_param_drivers + 1] = header
end

-- generate parameter file
io.write("Generating Parameters.asset...\n")
local slots = 16 - 5 -- leave 5 default VRChat params in place
if #param_entries > slots then
    common.errfmt("Too many parameters, max is %d, got %d", slots, #param_entries)
end
for i = #param_entries + 1, slots do
    param_entries[i] = string.gsub(PARAM_ENTRY, "$NAME", "")
end

local data = PARAM_HEADER
data = string.gsub(data, "$NAME", "Parameters")
data = string.gsub(data, "$ENTRIES", table.concat(param_entries, "\n"))
common.write_file("generated/Parameters.asset", data)

-- generate FXLayer
io.write("Generating FXLayer.controller...\n")
local ctrl = common.file_to_str("template/static_templates/anim_controller.template")
ctrl = string.gsub(ctrl, "$PARAMS", table.concat(ctrl_params, "\n"))
ctrl = string.gsub(ctrl, "$PARAM_DRIVERS", table.concat(ctrl_param_drivers, "\n"))
ctrl = string.gsub(ctrl, "$TOGGLES", table.concat(ctrl_toggles, "\n"))
ctrl = string.gsub(ctrl, "$ANIM_STATE_ID_ENTRIES", table.concat(ctrl_anim_state_ids, "\n"))
ctrl = string.gsub(ctrl, "$BEGIN_STATE_ID_ENTRIES", table.concat(ctrl_begin_state_ids, "\n"))
common.write_file("generated/FXLayer.controller", ctrl)

io.write("Done\n")
