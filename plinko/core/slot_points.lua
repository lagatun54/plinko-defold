local M = {}

function M.new(values, count)
    assert(type(values) == "table", "SLOT_POINTS must be a table")
    for key in pairs(values) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
            "SLOT_POINTS must contain exactly SLOT_COUNT entries (" .. count .. ")")
    end
    local points = {}
    for slot = 1, count do
        local value = values[slot]
        assert(type(value) == "number" and value >= 0 and value < math.huge,
            "SLOT_POINTS[" .. slot .. "] must be a finite non-negative number")
        points[slot] = value
    end
    return points
end

return M
