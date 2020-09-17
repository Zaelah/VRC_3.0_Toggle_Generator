
package.path = package.path .. ";code/?.lua"

local common = require "common"
local io = require "io"
local lfs = require "lfs"
local os = require "os"
local string = require "string"
local table = require "table"

local assert = assert
local error = error
local pairs = pairs
local tostring = tostring

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
        error(string.format("no guid for file '%s'", path))
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

local param_letter = string.char(string.byte("A") - 1)
local param_value = 255
local param_driver_id
local function next_param()
    param_value = param_value + 1
    if param_value > 255 then
        param_letter = string.char(string.byte(param_letter) + 1)
        param_value = 1
        param_driver_id = next_file_id()
        
        ctrl_params[#ctrl_params + 1] = string.gsub(CTRL_PARAM_ENTRY, "$PARAM_NAME", param_letter)
        param_entries[#param_entries + 1] = string.gsub(PARAM_ENTRY, "$NAME", param_letter)
        param_letter_by_driver_id[param_driver_id] = param_letter
    end
    return param_letter, tostring(param_value), param_driver_id
end

local emotes = {}
for path in lfs.dir("template/emotes/") do
    if common.is_excluded_filename(path) then
        goto continue
    end
    
    local name = string.match(path, "(.+)%.lua")
    emotes[#emotes + 1] = name
    
    ::continue::
end
table.sort(emotes)

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

local function dir_recurse(input_path, output_path, menu_name)
    local entries = {}
    
    for filename in lfs.dir(input_path) do
        if common.is_excluded_filename(filename) then goto continue end
        local path = input_path .. filename
        
        if lfs.attributes(path, "mode") == "directory" then
            local out_path = output_path .. filename .. "/"
            local menu_path = out_path .. "_menu.asset"
            
            -- each directory should already contain a "_menu.asset" file with its own meta file
            local guid = get_guid(menu_path)
            entries[#entries + 1] = gen_submenu(filename, guid)
            
            dir_recurse(path .. "/", out_path)
            goto continue
        end
        
        -- each file should have a corresponding .anim file and .anim.meta file
        local stripped = string.match(filename, "(.+)%.txt")
        local output_emote_path = output_path .. stripped .. "/"
        
        local guid = get_guid(output_emote_path .. "_menu.asset")
        entries[#entries + 1] = gen_submenu(stripped, guid)
        
        local entries = {}
        
        for i = 1, #emotes do
            local emote_name = emotes[i]
            local param_letter, param_value, param_driver_id = next_param()
            
            local guid = get_guid(output_emote_path .. emote_name .. ".anim")
            local entry = MENU_ENTRY
            entry = string.gsub(entry, "$NAME", emote_name)
            entry = string.gsub(entry, "$ENTRY_TYPE", MENU_ENTRY_TYPE_TOGGLE)
            entry = string.gsub(entry, "$PARAM_NAME", param_letter)
            entry = string.gsub(entry, "$PARAM_VALUE", param_value)
            entry = string.gsub(entry, "$SUBMENU", "{fileID: 0}")
            entries[#entries + 1] = entry
            
            -- create corresponding state machine entry for this anim
            local begin_id = next_file_id()
            local end_id = next_file_id()
            local anim_id = next_file_id()
            
            local toggle = CTRL_TOGGLE_ENTRY
            toggle = string.gsub(toggle, "$PARAM_NAME", param_letter)
            toggle = string.gsub(toggle, "$PARAM_VALUE", param_value)
            toggle = string.gsub(toggle, "$ANIM_GUID", guid)
            toggle = string.gsub(toggle, "$ANIM_NAME", param_letter .. param_value)
            toggle = string.gsub(toggle, "$BEGIN_STATE_ID", begin_id)
            toggle = string.gsub(toggle, "$END_STATE_ID", end_id)
            toggle = string.gsub(toggle, "$ANIM_STATE_ID", anim_id)
            toggle = string.gsub(toggle, "$PARAM_DRIVER_ID", param_driver_id)
            ctrl_toggles[#ctrl_toggles + 1] = toggle
            
            local begin_entry = CTRL_BEGIN_STATE_ENTRY
            begin_entry = string.gsub(begin_entry, "$BEGIN_STATE_ID", begin_id)
            ctrl_begin_state_ids[#ctrl_begin_state_ids + 1] = begin_entry
            
            local anim_entry = CTRL_ANIM_STATE_ENTRY
            anim_entry = string.gsub(anim_entry, "$ANIM_STATE_ID", anim_id)
            ctrl_anim_state_ids[#ctrl_anim_state_ids + 1] = anim_entry
        end
        
        local data = MENU_HEADER
        data = string.gsub(data, "$NAME", "Menu")
        data = string.gsub(data, "$ENTRIES", table.concat(entries))
        common.write_file(output_emote_path .. "_menu.asset", data)
        
        ::continue::
    end
    
    menu_name = menu_name or "_menu.asset"
    local pretty_name = string.match(menu_name, "(.+)%.asset")
    local data = MENU_HEADER
    data = string.gsub(data, "$NAME", pretty_name)
    data = string.gsub(data, "$ENTRIES", table.concat(entries))
    common.write_file(output_path .. menu_name, data)
end

io.write("Generating Menu.asset...\n")
dir_recurse("template/combos/", "generated/", "Menu.asset")

-- generate parameter drivers
local ctrl_param_drivers = {}
local entries_by_letter = {}
for a = string.byte("A"), string.byte(param_letter) do
    local e = {}
    entries_by_letter[string.char(a)] = e
    for b = string.byte("A"), string.byte(param_letter) do
        if a ~= b then
            e[#e + 1] = string.gsub(PARAM_DRIVER_ENTRY, "$PARAM_NAME", string.char(b))
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
local slots = 16 - 3 -- leave 3 default VRChat params in place
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
