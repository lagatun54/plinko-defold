local M = {}

local NORMAL_TEXTURE = hash("btn_green_normal")
local PRESSED_TEXTURE = hash("btn_green_push")

local function show(widget, texture)
    gui.play_flipbook(widget.node, texture)
end

function M:init(text_node, text, callback, on_pressed, on_released)
    self.node = self:get_node("root")
    self.text_node = text_node or self:get_node("text")
    self.on_pressed_callback = on_pressed
    self.on_released_callback = on_released
    self.pressed = false

    gui.set_text(self.text_node, text or "")

    self.button = self.druid:new_button("root", callback)
    self.button:set_animations_disabled()

    self.button.on_pressed:subscribe(function()
        self:set_pressed(true)
        if self.on_pressed_callback then self.on_pressed_callback(self) end
    end)
    local function release()
        self:set_pressed(false)
        if self.on_released_callback then self.on_released_callback(self) end
    end
    self.button.on_click:subscribe(release)
    self.button.on_click_outside:subscribe(release)
end

function M.set_pressed(self, pressed)
    self.pressed = not not pressed
    show(self, self.pressed and PRESSED_TEXTURE or NORMAL_TEXTURE)
end

return M
