local config = require("plinko.config.config")

local STARTS = config.STARTS
local M = {}

local function finite(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

local function int(value, lo, hi)
    return type(value) == "number" and value % 1 == 0 and value >= lo
        and (hi == nil or value <= hi)
end

local function valid_slot(value, count, optional)
    return (optional and value == nil) or int(value, 1, count)
end

local function copy_ball(ball)
    local out = {
        id = ball.id, ball_type = ball.ball_type, state = ball.state,
        x = ball.x, y = ball.y, vx = ball.vx, vy = ball.vy,
        landed_for = ball.landed_for, target_slot = ball.target_slot,
        radius = ball.radius, route_sway = ball.route_sway,
        floor_contacted = ball.floor_contacted, slot = ball.slot,
        guide_direction = ball.guide_direction,
    }
    if ball.guide_pin then out.guide_pin_id = ball.guide_pin.id end
    local approach = ball.approach
    if approach then
        out.approach = {
            x = approach.x, vx = approach.vx,
            elapsed = approach.elapsed, duration = approach.duration,
        }
    end
    return out
end

function M.capture(self)
    local credits = {}
    local available_balls = self.available_balls
    for _, ball in ipairs(self.balls) do
        if ball.state == "falling" then
            available_balls = available_balls + 1
        end
    end
    for slot = 1, self.layout.slot_count do credits[slot] = self.batch_slot_credit[slot] end
    return {
        version = 4, slot_count = self.layout.slot_count,
        available_balls = available_balls, next_id = self.next_id,
        restore_remaining = available_balls < config.MAX_BALLS and self.restore_remaining or 0,
        balls = {}, batch_slot_credit = credits,
    }
end

function M.apply(self, snapshot)
    local count = self.layout.slot_count
    if type(snapshot) ~= "table"
        or (snapshot.version ~= 1 and snapshot.version ~= 2
            and snapshot.version ~= 3 and snapshot.version ~= 4)
        or snapshot.slot_count ~= count
        or not int(snapshot.available_balls, 0)
        or not int(snapshot.next_id, 0)
        or (snapshot.version == 1
            and (not finite(snapshot.accumulator) or snapshot.accumulator < 0))
        or ((snapshot.version == 3 or snapshot.version == 4)
            and (not finite(snapshot.restore_remaining) or snapshot.restore_remaining < 0
                or snapshot.restore_remaining > config.BALL_RESTORE_INTERVAL
                or (snapshot.available_balls >= config.MAX_BALLS
                    and snapshot.restore_remaining ~= 0)))
        or type(snapshot.balls) ~= "table"
        or type(snapshot.batch_slot_credit) ~= "table" then
        return false
    end

    local credits = {}
    for slot = 1, count do
        if not finite(snapshot.batch_slot_credit[slot]) then return false end
        credits[slot] = snapshot.batch_slot_credit[slot]
    end

    local pins_by_id = {}
    for _, pin in ipairs(self.pins) do pins_by_id[pin.id] = pin end

    local balls, ids, highest_id = {}, {}, 0
    for index, saved in ipairs(snapshot.balls) do
        if type(saved) ~= "table" or not int(saved.id, 1) or ids[saved.id]
            or not STARTS[saved.ball_type]
            or (saved.state ~= "falling" and saved.state ~= "landed")
            or not finite(saved.x) or not finite(saved.y)
            or not finite(saved.vx) or not finite(saved.vy)
            or not finite(saved.landed_for) or saved.landed_for < 0
            or not finite(saved.radius) or saved.radius <= 0
            or not finite(saved.route_sway)
            or not valid_slot(saved.target_slot, count, true)
            or not valid_slot(saved.slot, count, saved.state ~= "landed")
            or (saved.floor_contacted ~= nil and type(saved.floor_contacted) ~= "boolean")
            or (saved.guide_direction ~= nil
                and saved.guide_direction ~= -1 and saved.guide_direction ~= 1) then
            return false
        end
        local ball = copy_ball(saved)
        if saved.guide_pin_id then
            ball.guide_pin = pins_by_id[saved.guide_pin_id]
            if not ball.guide_pin then return false end
        end
        local approach = saved.approach
        if approach then
            if type(approach) ~= "table" or not finite(approach.x)
                or not finite(approach.vx) or not finite(approach.elapsed)
                or not finite(approach.duration) or approach.elapsed < 0
                or approach.duration <= 0 then
                return false
            end
            ball.approach = {
                x = approach.x, vx = approach.vx,
                elapsed = approach.elapsed, duration = approach.duration,
            }
        end
        balls[index], ids[saved.id] = ball, true
        highest_id = math.max(highest_id, saved.id)
    end
    if snapshot.next_id < highest_id then return false end

    self.available_balls, self.next_id = snapshot.available_balls, snapshot.next_id
    self.restore_remaining = (snapshot.version == 3 or snapshot.version == 4)
        and snapshot.restore_remaining
        or (snapshot.available_balls < config.MAX_BALLS and config.BALL_RESTORE_INTERVAL or 0)
    self.balls, self.batch_slot_credit = {}, credits
    self.events, self.pin_events = {}, {}
    return true
end

return M
