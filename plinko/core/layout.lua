local M = {}

function M.new(config)
    local count = config.SLOT_COUNT
    assert(type(count) == "number" and count % 1 == 0 and count >= 2 and count <= 32,
        "SLOT_COUNT must be an integer from 2 to 32")
    local half_span = config.BOARD_HALF_WIDTH - 12
    local step = half_span * 2 / (count - 1)
    local width = math.min(24, step - 3)
    local radius = math.min(config.BALL_RADIUS, width * 0.5)
    return {
        slot_count = count, slot_step = step, slot_width = width,
        half_span = half_span, ball_radius = radius,
        slot_y = config.FLOOR_Y + radius + 1,
    }
end

function M.slot_x(layout, slot)
    return (slot - 1 - (layout.slot_count - 1) * 0.5) * layout.slot_step
end

function M.slot_at(layout, x)
    return math.max(1, math.min(layout.slot_count,
        math.floor(x / layout.slot_step + (layout.slot_count - 1) * 0.5 + 0.5) + 1))
end

return M
