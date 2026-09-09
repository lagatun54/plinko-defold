local M = {}
M.__index = M

function M.new(size, create, on_release)
    local self = setmetatable({
        free = {}, active = {}, created = 0,
        create = create, on_release = on_release,
    }, M)
    self:grow(size)
    return self
end

function M:grow(count)
    count = count or 1
    for _ = 1, count do
        self.created = self.created + 1
        self.free[#self.free + 1] = self.create(self.created)
    end
end

function M:acquire(key)
    local item = self.active[key]
    if item then return item end
    item = table.remove(self.free)
    if not item then
        self:grow(1)
        item = table.remove(self.free)
    end
    self.active[key] = item
    return item
end

function M:release(key)
    local item = self.active[key]
    if not item then return nil end
    self.active[key] = nil
    if self.on_release then self.on_release(item, key) end
    self.free[#self.free + 1] = item
    return item
end

function M:release_all()
    while true do
        local key = next(self.active)
        if not key then return end
        self:release(key)
    end
end

function M:destroy(destroy)
    self:release_all()
    if destroy then
        for i = 1, #self.free do destroy(self.free[i]) end
    end
    self.free, self.active = {}, {}
end

return M
