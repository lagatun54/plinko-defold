local view = require("entities.plinko.scripts.plinko_view")

local M = {}
M.__index = M

local BUTTONS_OFFSET_Y = 205
local DEFAULT_NODE_PREFIX = "plinko/"
local LAUNCH_BALL = hash("launch_ball")
local LAUNCH_BALLS = hash("launch_balls")
local ADD_TEST_BALL = hash("add_test_ball")
local SET_BOARD_TRANSFORM = hash("set_board_transform")
local SET_BALL_COUNT = hash("set_ball_count")

local function post_renderer(self, message_id, payload)
    if not self.renderer_url then return false end
    msg.post(self.renderer_url, message_id, payload)
    return true
end

function M.sync_board_transform(self)
    if not self.renderer_url then return end
    local board_position = gui.get_screen_position(self.board_node)
    local button_position = gui.get_screen_position(self.scale_reference_node)
    local scale = math.abs(button_position.y - board_position.y) / BUTTONS_OFFSET_Y
    if scale <= 0 then return end
    if self.board_position and self.board_position.x == board_position.x
        and self.board_position.y == board_position.y
        and self.board_scale == scale then
        return
    end
    self.board_position = board_position
    self.board_scale = scale
    post_renderer(self, SET_BOARD_TRANSFORM, {
        position = board_position,
        scale = scale,
    })
end

function M.new(owner, options)
    options = options or {}
    local prefix = options.node_prefix or DEFAULT_NODE_PREFIX
    local self = setmetatable({
        board_node = gui.get_node(prefix .. "board"),
        scale_reference_node = gui.get_node(prefix .. "drop_2/root"),
    }, M)
    self.view = view.new(owner, {
        node_prefix = prefix,
        on_drop = function(ball_type)
            return post_renderer(self, LAUNCH_BALL, { ball_type = ball_type })
        end,
        on_drop_many = function(launch_type)
            return post_renderer(self, LAUNCH_BALLS, { ball_type = launch_type })
        end,
        on_add_test_ball = function()
            post_renderer(self, ADD_TEST_BALL)
        end,
        on_transform_changed = function()
            self:sync_board_transform()
        end,
    })
    self.view:bind()
    return self
end

function M.configure(self, renderer_url)
    self.renderer_url = renderer_url
    self:sync_board_transform()
end

function M.set_ball_count(self, available, maximum, restore_remaining)
    self.view:set_ball_count(available, maximum, restore_remaining)
end

function M.update(self, dt)
    self.view:update(dt)
end

function M.on_input(self, action_id, action)
    return self.view:on_input(action_id, action)
end

function M.on_message(self, message_id, message, sender)
    if message_id == SET_BALL_COUNT then
        self:set_ball_count(message.available, message.maximum, message.restore_remaining)
    end
    self.view:on_message(message_id, message, sender)
end

function M.final(self)
    self.view:final()
end

return M
