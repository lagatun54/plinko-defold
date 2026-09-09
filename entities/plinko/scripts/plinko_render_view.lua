local config = require("plinko.config.config")
local layout = require("plinko.core.layout")
local object_pool = require("plinko.runtime.object_pool")

local M = {}
M.__index = M

local BALL_ANIMATION = hash("ball_1")
local BALL_ANIMATION_MESSAGE = { animation = BALL_ANIMATION }
local SET_ALPHA = hash("set_alpha")
local SET_ANIMATION = hash("set_animation")
local SET_BASE_SCALE = hash("set_base_scale")
local SET_TINT = hash("set_tint")
local CONFIGURE_BASKET = hash("configure_basket")
local BALL_LANDED = hash("ball_landed")
local IMPACT = hash("impact")

local BALL_TEXTURE_SIZE = 40
local PIN_TEXTURE_SIZE = 44
local BASKET_TEXTURE_SIZE = 64
local BASKET_HEIGHT = 24
local PIN_TINT = vmath.vector4(0.95, 0.95, 1, 0.9)
local BASKET_TINT = vmath.vector4(0.1, 0.7, 0.35, 0.45)

local function world_position(self, x, y, z)
    return vmath.vector3(self.board_center.x + x * self.board_scale,
        self.board_center.y + y * self.board_scale, z or 0)
end

local function scaled(self, scale)
    return vmath.vector3(scale.x * self.board_scale, scale.y * self.board_scale, scale.z)
end

local function texture_scale(width, height, texture_size)
    return vmath.vector3(width / texture_size, height / texture_size, 1)
end

local function remember(self, instance, x, y, base_scale)
    self.placed[#self.placed + 1] = instance
    self.local_positions[instance] = vmath.vector3(x, y, 0)
    self.base_scales[instance] = base_scale
end

local function spawn(self, factory_url, x, y, base_scale)
    return factory.create(factory_url, world_position(self, x, y), nil, nil, scaled(self, base_scale))
end

local function create_ball_pool(self)
    if self.ball_pool then return end
    local hidden_position = world_position(self, 0, 0, -1)
    local diameter = self.layout.ball_radius * 2
    self.ball_base_scale = texture_scale(diameter, diameter, BALL_TEXTURE_SIZE)
    self.ball_pool = object_pool.new(config.MAX_BALLS, function()
        local instance = factory.create("#ball_factory", hidden_position, nil, nil,
            scaled(self, self.ball_base_scale))
        msg.post(instance, SET_ALPHA, { alpha = 0 })
        return instance
    end, function(instance)
        msg.post(instance, SET_ALPHA, { alpha = 0 })
    end)
end

local function spawn_pins(self, pins)
    local base_scale = texture_scale(config.PIN_RADIUS * 2, config.PIN_RADIUS * 2, PIN_TEXTURE_SIZE)
    for _, pin in ipairs(pins) do
        local instance = spawn(self, "#pin_factory", pin.x, pin.y, base_scale)
        msg.post(instance, SET_TINT, { tint = PIN_TINT })
        remember(self, instance, pin.x, pin.y, base_scale)
        self.pins[pin.id] = instance
    end
end

local function spawn_baskets(self)
    local height_scale = BASKET_HEIGHT / BASKET_TEXTURE_SIZE
    for slot = 1, self.layout.slot_count do
        local base_scale = vmath.vector3(self.layout.slot_width / BASKET_TEXTURE_SIZE, height_scale, 1)
        local x = layout.slot_x(self.layout, slot)
        local instance = spawn(self, "#basket_factory", x, self.layout.slot_y, base_scale)
        remember(self, instance, x, self.layout.slot_y, base_scale)
        self.baskets[slot] = instance
        msg.post(instance, CONFIGURE_BASKET, {
            slot = slot,
            points = config.SLOT_POINTS[slot],
        })
        msg.post(instance, SET_TINT, { tint = BASKET_TINT })
    end
end

local function ball_alpha(ball)
    local faded = 1 - math.max(0, ball.landed_for - config.LANDED_DURATION) / config.FADE_DURATION
    return math.max(0, faded)
end

local function acquire_ball(self, ball_id)
    local instance = self.balls[ball_id]
    if instance then return instance end
    if not self.ball_pool then create_ball_pool(self) end
    instance = self.ball_pool:acquire(ball_id)
    self.balls[ball_id] = instance
    go.set_scale(scaled(self, self.ball_base_scale), instance)
    msg.post(instance, SET_ANIMATION, BALL_ANIMATION_MESSAGE)
    return instance
end

local function sync_ball_alpha(self, ball_id, instance, alpha)
    if self.ball_alphas[ball_id] == alpha then return end
    self.ball_alphas[ball_id] = alpha
    local message = self.ball_alpha_messages[ball_id]
    if not message then
        message = { alpha = alpha }
        self.ball_alpha_messages[ball_id] = message
    else
        message.alpha = alpha
    end
    msg.post(instance, SET_ALPHA, message)
end

local function release_unseen_balls(self, generation)
    for id, _ in pairs(self.balls) do
        if self.ball_seen[id] ~= generation then
            self.ball_pool:release(id)
            self.balls[id] = nil
            self.ball_seen[id] = nil
            self.ball_alphas[id] = nil
            self.ball_alpha_messages[id] = nil
        end
    end
end

local function spawn_playfield(self)
    if self.playfield_spawned or not self.pending_pins or not self.transform_ready then
        return
    end
    create_ball_pool(self)
    spawn_pins(self, self.pending_pins)
    spawn_baskets(self)
    self.playfield_spawned = true
    self.pending_pins = nil
end

function M.new(owner)
    return setmetatable({
        owner = owner,
        board_center = vmath.vector3(0, 0, 0),
        board_scale = 1,
        transform_ready = false,
        playfield_spawned = false,
        layout = layout.new(config),
        balls = {},
        pins = {},
        baskets = {},
        placed = {},
        local_positions = {},
        base_scales = {},
        render_generation = 0,
        ball_seen = {},
        ball_alphas = {},
        ball_alpha_messages = {},
        ball_position = vmath.vector3(0, 0, 0),
    }, M)
end

function M.set_board_transform(self, position, scale)
    if not position then return end
    self.board_center.x = position.x
    self.board_center.y = position.y
    self.board_center.z = position.z or 0
    self.board_scale = tonumber(scale) or self.board_scale
    self.transform_ready = true
    spawn_playfield(self)

    for _, instance in ipairs(self.placed) do
        local local_position = self.local_positions[instance]
        go.set_position(world_position(self, local_position.x, local_position.y, local_position.z), instance)
        local instance_scale = scaled(self, self.base_scales[instance])
        go.set_scale(instance_scale, instance)
        msg.post(instance, SET_BASE_SCALE, { scale = instance_scale })
    end
    if self.ball_pool then
        local ball_scale = scaled(self, self.ball_base_scale)
        for _, instance in pairs(self.balls) do go.set_scale(ball_scale, instance) end
    end
end

function M.bind(self, pins)
    self.pending_pins = pins
    spawn_playfield(self)
end

function M.on_ball_landed(self, slot)
    local basket = self.baskets[slot]
    if basket then
        msg.post(basket, BALL_LANDED)
    end
end

function M.on_pin_hit(self, pin_id, strength)
    local instance = self.pins[pin_id]
    if instance then
        msg.post(instance, IMPACT, { strength = strength })
    end
end

function M.render(self, balls)
    if not self.transform_ready then return end
    self.render_generation = self.render_generation + 1
    local generation = self.render_generation
    local position = self.ball_position
    for _, ball in ipairs(balls) do
        self.ball_seen[ball.id] = generation
        local instance = acquire_ball(self, ball.id)
        position.x = self.board_center.x + ball.x * self.board_scale
        position.y = self.board_center.y + ball.y * self.board_scale
        position.z = 0
        go.set_position(position, instance)
        sync_ball_alpha(self, ball.id, instance, ball_alpha(ball))
    end
    release_unseen_balls(self, generation)
end

function M.final(self)
    for _, instance in ipairs(self.placed) do go.delete(instance) end
    if self.ball_pool then
        self.ball_pool:destroy(function(instance) go.delete(instance) end)
    end
    self.balls, self.ball_pool = {}, nil
    self.placed, self.local_positions, self.base_scales = {}, {}, {}
    self.pins, self.baskets = {}, {}
    self.pending_pins, self.playfield_spawned, self.transform_ready = nil, false, false
    self.ball_seen, self.ball_alphas, self.ball_alpha_messages = {}, {}, {}
end

return M
