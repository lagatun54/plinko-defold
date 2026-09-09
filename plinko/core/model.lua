local config = require("plinko.config.config")
local layout = require("plinko.core.layout")
local physics = require("plinko.core.physics.simulation")
local snapshot = require("plinko.core.snapshot")
local distribution = require("plinko.core.slot_distribution")
local points = require("plinko.core.slot_points")
local selection = require("plinko.core.slot_selection")

local BOARD_TOP = config.BOARD_TOP
local STARTS = config.STARTS
local TIMER_EPSILON = 1e-12

local M = {}

local function restore_interval()
    local value = config.BALL_RESTORE_INTERVAL
    assert(type(value) == "number" and value > 0 and value < math.huge,
        "BALL_RESTORE_INTERVAL must be a finite positive number")
    return value
end

local function initial_reserve()
    local maximum, initial = config.MAX_BALLS, config.START_BALLS
    assert(type(maximum) == "number" and maximum >= 0 and maximum % 1 == 0
        and maximum < math.huge, "MAX_BALLS must be a finite non-negative integer")
    assert(type(initial) == "number" and initial >= 0 and initial % 1 == 0
        and initial <= maximum and initial < math.huge,
        "START_BALLS must be a finite non-negative integer no greater than MAX_BALLS")
    return initial
end

local function land(self, ball, slot)
    ball.vx, ball.vy = 0, 0
    ball.state, ball.slot = "landed", slot
    self.events[#self.events + 1] = {
        type = "ball_landed", ball_id = ball.id,
        ball_type = ball.ball_type, slot = slot, points = self.points[slot],
    }
end

local function drain(self, field)
    local events = self[field]
    if #events == 0 then return {} end
    self[field] = {}
    return events
end

function M.new(random)
    local geometry = layout.new(config)
    local available_balls = initial_reserve()
    local interval = restore_interval()
    local self = {
        random = random or math.random, balls = {},
        available_balls = available_balls,
        restore_remaining = available_balls < config.MAX_BALLS and interval or 0,
        events = {}, pin_events = {}, next_id = 0,
        layout = geometry,
        distribution = distribution.new(config.SLOT_WEIGHTS, geometry.slot_count),
        points = points.new(config.SLOT_POINTS, geometry.slot_count),
        batch_slot_credit = selection.new_credit(geometry.slot_count),
    }
    self.pins = physics.create_pins()
    return self
end

function M.launch(self, ball_type, target_slot)
    if not STARTS[ball_type] then return nil, "invalid_ball_type" end
    if self.available_balls <= 0 then return nil, "capacity_reached" end
    self.available_balls = self.available_balls - 1
    if self.available_balls < config.MAX_BALLS and self.restore_remaining <= 0 then
        self.restore_remaining = restore_interval()
    end
    self.next_id = self.next_id + 1
    local ball = {
        id = self.next_id, ball_type = ball_type, state = "falling",
        x = STARTS[ball_type], y = BOARD_TOP,
        vx = (self.random() - 0.5) * config.START_HORIZONTAL_SPEED,
        vy = config.START_VERTICAL_SPEED, landed_for = 0,
        target_slot = target_slot or selection.choose(self),
        radius = self.layout.ball_radius,
        route_sway = ((self.next_id - 1) % 3 - 1) * config.COLUMN_STEP * 1.15,
    }
    if ball.target_slot then
        ball.vx = ball.vx + physics.initial_horizontal_velocity(ball, self.layout)
    end
    self.balls[#self.balls + 1] = ball
    return ball.id
end

function M.restore_ball(self)
    if self.available_balls >= config.MAX_BALLS then return false end
    self.available_balls = self.available_balls + 1
    self.restore_remaining = self.available_balls < config.MAX_BALLS and restore_interval() or 0
    return true
end

function M.add_ball(self, count)
    count = count or 1
    if type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
        return false, "invalid_count"
    end
    self.available_balls = self.available_balls + count
    if self.available_balls >= config.MAX_BALLS then
        self.restore_remaining = 0
    elseif self.restore_remaining <= 0 then
        self.restore_remaining = restore_interval()
    end
    return count > 0
end

function M.launch_many(self, ball_type, count)
    local launched = {}
    for _ = 1, count do
        local id = M.launch(self, ball_type)
        if not id then break end
        launched[#launched + 1] = id
    end
    return launched
end

function M.fixed_update(self, dt)
    assert(type(dt) == "number" and dt > 0 and dt < math.huge, "invalid dt")
    local restored = 0
    if self.available_balls < config.MAX_BALLS then
        self.restore_remaining = self.restore_remaining - dt
        while self.restore_remaining <= TIMER_EPSILON
            and self.available_balls < config.MAX_BALLS do
            self.available_balls = self.available_balls + 1
            restored = restored + 1
            if self.available_balls < config.MAX_BALLS then
                self.restore_remaining = self.restore_remaining + restore_interval()
            else
                self.restore_remaining = 0
            end
        end
    else
        self.restore_remaining = 0
    end
    local remove_after = config.LANDED_DURATION + config.FADE_DURATION
    for index = #self.balls, 1, -1 do
        local ball = self.balls[index]
        if ball.state == "falling" then
            local slot = physics.step(self, ball, dt)
            if slot then land(self, ball, slot) end
        else
            ball.landed_for = ball.landed_for + dt
            if ball.landed_for >= remove_after then
                table.remove(self.balls, index)
            end
        end
    end
    return restored
end

function M.snapshot(self)
    return snapshot.capture(self)
end

function M.restore(self, data)
    return snapshot.apply(self, data)
end

function M.drain_events(self)
    return drain(self, "events")
end

function M.drain_pin_events(self)
    return drain(self, "pin_events")
end

return M
