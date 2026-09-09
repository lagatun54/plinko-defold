local M = {}

function M.new_credit(count)
    local credit = {}
    for slot = 1, count do credit[slot] = 0 end
    return credit
end

function M.choose(self)
    if not self.distribution then return nil end
    local value = self.random()
    assert(type(value) == "number" and value >= 0 and value < 1, "random must return a number in [0, 1)")
    local threshold = value * self.distribution.total
    for slot, bound in ipairs(self.distribution.cumulative) do
        if threshold < bound then return slot end
    end
    return #self.distribution.cumulative
end

function M.choose_batch(self)
    if not self.distribution then return nil end
    local selected, highest, previous = nil, nil, 0
    for slot, bound in ipairs(self.distribution.cumulative) do
        local weight = bound - previous
        previous = bound
        self.batch_slot_credit[slot] = self.batch_slot_credit[slot] + weight
        if not highest or self.batch_slot_credit[slot] > highest then
            selected, highest = slot, self.batch_slot_credit[slot]
        end
    end
    if not selected then return nil end
    self.batch_slot_credit[selected] = self.batch_slot_credit[selected] - self.distribution.total
    return selected
end

return M
