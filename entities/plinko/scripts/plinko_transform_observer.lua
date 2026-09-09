local component = require("druid.component")

---@class plinko.transform_observer: druid.component
---@field on_transform_changed fun()
local M = component.create("plinko_transform_observer")

---@param on_transform_changed fun()
function M:init(on_transform_changed)
    self.on_transform_changed = on_transform_changed
end

function M:on_window_resized()
    self.on_transform_changed()
end

function M:on_layout_change()
    self.on_transform_changed()
end

return M
