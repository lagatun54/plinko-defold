local M = {}

local function copy_nonneg(values, count, name)
    assert(type(values) == "table", name .. " must be a table")
    for key in pairs(values) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
            name .. " must contain exactly SLOT_COUNT entries (" .. count .. ")")
    end
    local copy = {}
    for slot = 1, count do
        local value = values[slot]
        assert(type(value) == "number" and value >= 0 and value < math.huge,
            name .. "[" .. slot .. "] must be a finite non-negative number")
        copy[slot] = value
    end
    return copy
end

function M.new(weights, count)
    if weights == nil then return nil end
    local values = copy_nonneg(weights, count, "SLOT_WEIGHTS")
    local cumulative, total = {}, 0
    for slot = 1, count do
        total = total + values[slot]
        cumulative[slot] = total
    end
    assert(total > 0 and total < math.huge, "SLOT_WEIGHTS sum must be finite and positive")
    return { cumulative = cumulative, total = total }
end

return M
