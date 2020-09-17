
local io = require "io"
local lfs = require "lfs"
local string = require "string"

local assert = assert
local error = error
local pairs = pairs

local exclude_file_patterns = {
    "^%.", -- current directory, parent directory, and dotfiles like .gitignore
    "%.meta$", -- Unity meta files
}

local function is_excluded_filename (filename)
    for i = 1, #exclude_file_patterns do
        if string.find(filename, exclude_file_patterns[i]) then return true end
    end
    return false
end

local gesture_names_to_values = {
    neutral = 0,
    fist = 1,
    open_hand = 2,
    finger_point = 3,
    peace_sign = 4,
    rock_n_roll = 5,
    finger_gun = 6,
    thumbs_up = 7,
}

return {
    directory = function(dir_path)
        if not string.find(dir_path, "[/\\]$") then
            dir_path = dir_path .. "/"
        end
        
        local iter, invariant = lfs.dir(dir_path)
        return function()
            while true do
                local filename = iter(invariant)
                if not filename then return end
                if not is_excluded_filename(filename) then
                    local path = dir_path .. filename
                    return filename, path, lfs.attributes(path, "mode") == "directory"
                end
            end
        end
    end,
    
    errfmt = function(fmt, ...)
        return error(string.format(fmt, ...))
    end,
    
    file_to_str = function(path)
        local file = assert(io.open(path, "rb"))
        local str = file:read("*a")
        file:close()
        return str
    end,
    
    filename_remove_extension = function(filename)
        return (string.match(filename, "(.+)%."))
    end,
    
    for_each_gesture_name_and_value = function(func)
        for gesture_name, value in pairs(gesture_names_to_values) do
            func(gesture_name, value)
        end
    end,
    
    write_file = function(path, data)
        local file = assert(io.open(path, "wb+"))
        file:write(data)
        file:close()
    end,
}
