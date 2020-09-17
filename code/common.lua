
local io = require "io"
local string = require "string"

local assert = assert
local error = error

local exclude_file_patterns = {
    "^%.", -- current directory, partent directory, and dotfiles like .gitignore
    "%.meta$", -- Unity meta files
}

return {
    errfmt = function(fmt, ...)
        return error(string.format(fmt, ...))
    end,
    
    file_to_str = function(path)
        local file = assert(io.open(path, "rb"))
        local str = file:read("*a")
        file:close()
        return str
    end,
    
    is_excluded_filename = function(filename)
        for i = 1, #exclude_file_patterns do
            if string.find(filename, exclude_file_patterns[i]) then return true end
        end
        return false
    end,
    
    write_file = function(path, data)
        local file = assert(io.open(path, "wb+"))
        file:write(data)
        file:close()
    end,
}
