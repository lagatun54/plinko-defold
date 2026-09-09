local druid = require("druid.druid")
local config = require("plinko.config.config")
local button_widget = require("widgets.button.button")
local transform_observer = require("entities.plinko.scripts.plinko_transform_observer")

local M = {}
M.__index = M

local DEFAULT_NODE_PREFIX = "plinko/"
local BUTTONS = {
    { node_id = "drop_1", launch_type = 2, text = "drop n", kind = "drop_many" },
    { node_id = "drop_2", launch_type = 2, text = "drop 1", kind = "drop" },
    { node_id = "drop_3", text = "+1", kind = "add_test" },
}

local function node_id(self, id)
    return self.node_prefix .. id
end

local function click(self, spec)
    if spec.kind == "drop_many" and self.handlers.on_drop_many then
        return self.handlers.on_drop_many(spec.launch_type)
    end
    if spec.kind == "add_test" and self.handlers.on_add_test_ball then
        return self.handlers.on_add_test_ball()
    end
    return self.handlers.on_drop(spec.launch_type)
end

local function press(self, button)
    if self.pressed_button and self.pressed_button ~= button then
        self.pressed_button:set_pressed(false)
    end
    self.pressed_button = button
end

local function release(self, button)
    if self.pressed_button == button then
        self.pressed_button = nil
    end
end

function M.new(owner, options)
    options = options or {}
    local prefix = options.node_prefix or DEFAULT_NODE_PREFIX
    gui.set_enabled(gui.get_node(prefix .. "root"), true)
    local self = setmetatable({
        druid = druid.new(owner),
        node_prefix = prefix,
        handlers = {
            on_drop = options.on_drop,
            on_drop_many = options.on_drop_many,
            on_add_test_ball = options.on_add_test_ball,
        },
    }, M)
    if options.on_transform_changed then
        self.transform_observer = self.druid:new(transform_observer, options.on_transform_changed)
    end
    if self.druid.new_timer then
        self.restore_timer = self.druid:new_timer(node_id(self, "timer"),
            config.BALL_RESTORE_INTERVAL, 0)
        self.restore_timer:set_state(false)
    end
    return self
end

function M.bind(self, handlers)
    if handlers then
        for key, value in pairs(handlers) do
            self.handlers[key] = value
        end
    end
    self.pressed_button = nil
    self.buttons = {}
    for _, spec in ipairs(BUTTONS) do
        local template_id = node_id(self, spec.node_id)
        local button
        button = self.druid:new_widget(button_widget, template_id, nil,
            gui.get_node(template_id .. "/text"), spec.text, function()
                return click(self, spec)
            end, function()
                press(self, button)
            end, function()
                release(self, button)
            end)
        self.buttons[#self.buttons + 1] = button
    end
end

function M.set_ball_count(self, available, maximum, restore_remaining)
    if type(available) ~= "number" or type(maximum) ~= "number" then return end
    self.ball_count = available
    self.ball_maximum = maximum
    gui.set_text(gui.get_node(node_id(self, "ball_count")),
        string.format("Balls: %d / %d", available, maximum))
    if self.restore_timer then
        self.restore_timer:set_state(false)
        local remaining = available < maximum
            and math.max(0, math.ceil(tonumber(restore_remaining) or config.BALL_RESTORE_INTERVAL))
            or 0
        self.restore_timer:set_value(remaining)
    end
end

function M.update(self, dt)
    self.druid:update(dt)
end

function M.on_input(self, action_id, action)
    return self.druid:on_input(action_id, action)
end

function M.on_message(self, message_id, message, sender)
    self.druid:on_message(message_id, message, sender)
end

function M.final(self)
    self.druid:final()
end

return M
