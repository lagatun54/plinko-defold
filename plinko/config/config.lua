local M = {
    BOARD_TOP = 142,
    ROW_STEP = 31,
    ROWS = 8,
    SLOT_COUNT = 10,
    COLUMN_STEP = 28,
    BALL_RADIUS = 9,
    PIN_RADIUS = 3,
    GRAVITY = -210,
    BOUNCINESS = 0.62,
    FLOOR_FRICTION = 0.82,
    FLOOR_MAX_UPWARD_SPEED = 65,
    FLOOR_REST_SPEED = 45,
    PIN_ROLL_SPEED = 10,
    PIN_REST_SPEED = 15,
    PIN_BOUNCINESS = 0.58,
    PIN_MAX_UPWARD_SPEED = 65,
    PIN_MAX_HORIZONTAL_SPEED = 85,
    MAX_BALL_SPEED = 240,
    BOARD_HALF_WIDTH = 124,
    FLOOR_Y = -158,
    FIXED_DT = 1 / 120,
    START_BALLS = 3,
    MAX_BALLS = 5,
    BALL_RESTORE_INTERVAL = 60,

    BATCH_MIN_BALLS = 2,
    BATCH_MAX_BALLS = 6,
    LANDED_DURATION = 1.5,
    FADE_DURATION = 0.35,
    START_VERTICAL_SPEED = -12,
    START_HORIZONTAL_SPEED = 14,
    STARTS = { -75, 1, 76 },

    SLOT_POINTS = { 100, 50, 20, 10, 5, 5, 10, 20, 50, 100 },
}

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

function M.parse_slot_count(raw)
    if raw == nil then return nil end
    local number = raw
    if type(raw) == "string" then
        raw = trim(raw)
        if raw == "" then return nil end
        number = tonumber(raw)
    end
    assert(type(number) == "number" and number % 1 == 0 and number >= 2 and number <= 32,
        "SLOT_COUNT must be an integer from 2 to 32")
    return number
end

function M.parse_slot_weights(raw)
    if raw == nil then return nil end
    assert(type(raw) == "string", "SLOT_WEIGHTS must be a comma-separated list")
    raw = trim(raw)
    if raw == "" or raw == "nil" then return nil end
    local values, start = {}, 1
    while true do
        local comma = raw:find(",", start, true)
        local token = trim(raw:sub(start, comma and comma - 1 or #raw))
        local number = tonumber(token)
        assert(type(number) == "number" and number >= 0 and number < math.huge,
            "SLOT_WEIGHTS must contain finite non-negative numbers")
        values[#values + 1] = number
        if not comma then break end
        start = comma + 1
        assert(start <= #raw, "SLOT_WEIGHTS must contain finite non-negative numbers")
    end
    return values
end

function M.apply_project_settings(read)
    if type(read) ~= "function" then return M end
    local count = M.parse_slot_count(read("plinko.slot_count"))
    if count ~= nil then
        M.SLOT_COUNT = count
    end
    local raw = read("plinko.slot_weights")
    if raw ~= nil then
        M.SLOT_WEIGHTS = M.parse_slot_weights(raw)
    end
    return M
end

local engine = rawget(_G, "sys")
if type(engine) == "table" then
    local read = engine.get_config_string or engine.get_config
    if type(read) == "function" then
        M.apply_project_settings(function(key)
            return read(key)
        end)
    end
end

return M
