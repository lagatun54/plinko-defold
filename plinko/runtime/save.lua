local M = {}

local APPLICATION_ID = "com.hgpoint.plinko"
local FILE_NAME = "plinko-session.json"

local function save_path()
    return sys.get_save_file(APPLICATION_ID, FILE_NAME)
end

function M.load()
    local file = io.open(save_path(), "rb")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    if not contents or contents == "" then return nil end
    local ok, data = pcall(json.decode, contents)
    if ok and type(data) == "table" then return data end
    return nil
end

function M.save(snapshot)
    if type(snapshot) ~= "table" then return false end
    local ok, contents = pcall(json.encode, snapshot)
    if not ok then return false end
    local file = io.open(save_path(), "wb")
    if not file then return false end
    local written = file:write(contents)
    if written then file:flush() end
    file:close()
    return written and true or false
end

return M
