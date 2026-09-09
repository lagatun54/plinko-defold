local config = require("plinko.config.config")
local layout = require("plinko.core.layout")

local BOARD_TOP, BOARD_HALF_WIDTH = config.BOARD_TOP, config.BOARD_HALF_WIDTH
local ROW_STEP, ROWS, COLUMN_STEP = config.ROW_STEP, config.ROWS, config.COLUMN_STEP
local PIN_RADIUS, FLOOR_Y, GRAVITY = config.PIN_RADIUS, config.FLOOR_Y, config.GRAVITY
local BOUNCINESS, PIN_BOUNCINESS = config.BOUNCINESS, config.PIN_BOUNCINESS
local PIN_MAX_UPWARD_SPEED = config.PIN_MAX_UPWARD_SPEED
local PIN_MAX_HORIZONTAL_SPEED = config.PIN_MAX_HORIZONTAL_SPEED
local PIN_ROLL_SPEED, PIN_REST_SPEED = config.PIN_ROLL_SPEED, config.PIN_REST_SPEED
local MAX_BALL_SPEED = config.MAX_BALL_SPEED
local FLOOR_MAX_UPWARD_SPEED = config.FLOOR_MAX_UPWARD_SPEED
local FLOOR_FRICTION, FLOOR_REST_SPEED = config.FLOOR_FRICTION, config.FLOOR_REST_SPEED

local M = {}

local function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

local function route_x_for(ball, target_x, progress)
    local sway = ball.route_sway * math.sin(math.pi * progress)
    local wall = BOARD_HALF_WIDTH - ball.radius
    return clamp(target_x * progress + sway, -wall, wall)
end

local function guide_ball(world, ball, dt)
    if not ball.target_slot or ball.floor_contacted then return end
    local target_x = layout.slot_x(world.layout, ball.target_slot)
    local last_pin_bottom = BOARD_TOP - ROWS * ROW_STEP - PIN_RADIUS - ball.radius
    if ball.y < last_pin_bottom and ball.vy < 0 and not ball.approach then
        local height = ball.y - (FLOOR_Y + ball.radius)
        local velocity = ball.vy + GRAVITY * dt * 0.5
        local duration = (velocity + math.sqrt(velocity * velocity
            - 2 * GRAVITY * math.max(0, height))) / -GRAVITY
        ball.approach = { x = ball.x, vx = ball.vx, elapsed = 0, duration = math.max(dt, duration) }
    end
    if ball.approach then
        local path = ball.approach
        path.elapsed = math.min(path.duration, path.elapsed + dt)
        local t = path.elapsed / path.duration
        local t2, t3 = t * t, t * t * t
        local x = (2 * t3 - 3 * t2 + 1) * path.x
            + (t3 - 2 * t2 + t) * path.duration * path.vx
            + (-2 * t3 + 3 * t2) * target_x
        ball.vx = (x - ball.x) / dt
        return
    end
    local progress = clamp((BOARD_TOP - ball.y) / ((ROWS - 2) * ROW_STEP), 0, 1)
    local route_x = route_x_for(ball, target_x, progress)
    local reach = ball.radius + PIN_RADIUS
    if ball.guide_pin and ball.y < ball.guide_pin.y - reach then ball.guide_pin = nil end
    if not ball.guide_pin then
        local pins = world.pins
        for i = 1, #pins do
            local pin = pins[i]
            local dy = ball.y - pin.y
            if dy >= 0 and dy < ROW_STEP and math.abs(ball.x - pin.x) < reach then
                ball.guide_pin, ball.guide_direction = pin, route_x < pin.x and -1 or 1
                if math.abs(pin.x + ball.guide_direction * (reach + 2))
                    > BOARD_HALF_WIDTH - ball.radius then
                    ball.guide_direction = -ball.guide_direction
                end
                break
            end
        end
    end
    if ball.guide_pin then route_x = ball.guide_pin.x + ball.guide_direction * (reach + 2) end
    local acceleration = clamp((route_x - ball.x) * 36 - ball.vx * 12, -600, 600)
    ball.vx = clamp(ball.vx + acceleration * dt, -180, 180)
end

local function bounce_from_pin(world, ball, pin)
    local dx, dy = ball.x - pin.x, ball.y - pin.y
    local minimum_distance = ball.radius + PIN_RADIUS
    if dx > minimum_distance or dx < -minimum_distance
        or dy > minimum_distance or dy < -minimum_distance then
        return
    end
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance >= minimum_distance then return end
    local nx = distance > 0.001 and dx / distance or (world.random() < 0.5 and -1 or 1)
    local ny = distance > 0.001 and dy / distance or 0
    ball.x = ball.x + nx * (minimum_distance - distance)
    ball.y = ball.y + ny * (minimum_distance - distance)
    local normal_speed = ball.vx * nx + ball.vy * ny
    if normal_speed >= 0 then return end
    if pin.id then
        world.pin_events[#world.pin_events + 1] = {
            pin_id = pin.id,
            strength = math.min(1, -normal_speed / PIN_MAX_UPWARD_SPEED),
        }
    end
    local impulse = (1 + PIN_BOUNCINESS) * normal_speed
    ball.vx, ball.vy = ball.vx - nx * impulse, ball.vy - ny * impulse
    ball.vx = clamp(ball.vx, -PIN_MAX_HORIZONTAL_SPEED, PIN_MAX_HORIZONTAL_SPEED)
    ball.vy = math.min(ball.vy, PIN_MAX_UPWARD_SPEED)
    if ny > 0.8 and math.abs(ball.vx) < PIN_ROLL_SPEED * 0.8
        and math.abs(normal_speed) < PIN_REST_SPEED then
        local direction = math.abs(ball.vx) < 0.001 and (world.random() < 0.5 and -1 or 1)
            or (ball.vx < 0 and -1 or 1)
        ball.vx = direction * PIN_ROLL_SPEED
    end
    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
    if speed > MAX_BALL_SPEED then
        local scale = MAX_BALL_SPEED / speed
        ball.vx, ball.vy = ball.vx * scale, ball.vy * scale
    end
end

function M.create_pins()
    local pins = {}
    for row = 1, ROWS do
        for column = 0, row - 1 do
            pins[#pins + 1] = {
                id = #pins + 1,
                x = (column - (row - 1) * 0.5) * COLUMN_STEP,
                y = BOARD_TOP - row * ROW_STEP,
            }
        end
    end
    return pins
end

function M.initial_horizontal_velocity(ball, board_layout)
    if not ball.target_slot then return 0 end
    return (route_x_for(ball, layout.slot_x(board_layout, ball.target_slot), 0.22) - ball.x) / 0.5
end

function M.step(world, ball, dt)
    guide_ball(world, ball, dt)
    ball.vy = ball.vy + GRAVITY * dt
    ball.x, ball.y = ball.x + ball.vx * dt, ball.y + ball.vy * dt
    local pins = world.pins
    for i = 1, #pins do bounce_from_pin(world, ball, pins[i]) end
    local wall = BOARD_HALF_WIDTH - ball.radius
    if ball.x < -wall then ball.x, ball.vx = -wall, math.abs(ball.vx) * BOUNCINESS
    elseif ball.x > wall then ball.x, ball.vx = wall, -math.abs(ball.vx) * BOUNCINESS end
    if ball.y > FLOOR_Y + ball.radius then return nil end
    ball.y = FLOOR_Y + ball.radius
    if ball.target_slot and not ball.floor_contacted then ball.floor_contacted, ball.vx = true, 0 end
    if ball.vy < 0 then
        ball.vy = math.min(-ball.vy * BOUNCINESS, FLOOR_MAX_UPWARD_SPEED)
        ball.vx = ball.vx * FLOOR_FRICTION
    end
    if ball.vy >= FLOOR_REST_SPEED then return nil end
    return layout.slot_at(world.layout, ball.x)
end

return M
