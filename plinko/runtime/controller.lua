local config = require("plinko.config.config")
local model = require("plinko.core.model")
local M = {}

local function positive_integer(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

local function restore_last_result(game, result)
    if type(result) ~= "table"
        or result.type ~= "ball_landed"
        or not positive_integer(result.ball_id)
        or result.ball_id > game.next_id
        or not positive_integer(result.ball_type)
        or config.STARTS[result.ball_type] == nil
        or not positive_integer(result.slot)
        or result.slot > game.layout.slot_count
        or type(result.points) ~= "number"
        or result.points ~= game.points[result.slot] then
        return nil
    end

    return {
        type = "ball_landed",
        ball_id = result.ball_id,
        ball_type = result.ball_type,
        slot = result.slot,
        points = result.points,
    }
end

function M.new(view, random)
    local game = model.new(random)
    local bucket_hits = {}
    for slot = 1, game.layout.slot_count do bucket_hits[slot] = 0 end
    local self = {
        game = game, view = view,
        total_points = 0, total_hits = 0, bucket_hits = bucket_hits,
        pending_pin_events = {}, pending_landing_events = {},
        statistics_dirty = true,
    }
    view:bind(self.game.pins)
    return self
end

function M.launch(self, ball_type)
    return model.launch(self.game, ball_type)
end

function M.launch_many(self, ball_type, count)
    local available = self.game.available_balls
    if count == nil then
        local maximum = math.min(config.BATCH_MAX_BALLS, available)
        local minimum = math.min(config.BATCH_MIN_BALLS, maximum)
        if maximum == 0 then return {} end
        local random = math.max(0, math.min(0.999999999, self.game.random()))
        count = minimum + math.floor(random * (maximum - minimum + 1))
    end
    return model.launch_many(self.game, ball_type, math.min(math.max(0, math.floor(count)), available))
end

function M.restore_ball(self)
    return model.restore_ball(self.game)
end

function M.add_test_ball(self)
    return model.add_ball(self.game)
end

function M.get_available_balls(self)
    return self.game.available_balls
end

function M.get_restore_remaining(self)
    return self.game.restore_remaining
end

function M.snapshot(self)
    local hits = {}
    for slot = 1, self.game.layout.slot_count do hits[slot] = self.bucket_hits[slot] end
    return {
        version = 1, game = model.snapshot(self.game),
        total_points = self.total_points, total_hits = self.total_hits,
        bucket_hits = hits, last_result = self.last_result,
    }
end

function M.restore(self, snapshot)
    if type(snapshot) ~= "table" or snapshot.version ~= 1
        or type(snapshot.total_points) ~= "number" or snapshot.total_points < 0
        or type(snapshot.total_hits) ~= "number" or snapshot.total_hits < 0
        or snapshot.total_points % 1 ~= 0 or snapshot.total_hits % 1 ~= 0
        or type(snapshot.bucket_hits) ~= "table" then
        return false
    end
    local hits, sum = {}, 0
    for slot = 1, self.game.layout.slot_count do
        local hit = snapshot.bucket_hits[slot]
        if type(hit) ~= "number" or hit < 0 or hit % 1 ~= 0 then return false end
        hits[slot], sum = hit, sum + hit
    end
    if sum ~= snapshot.total_hits or not model.restore(self.game, snapshot.game) then return false end
    self.total_points, self.total_hits, self.bucket_hits = snapshot.total_points, snapshot.total_hits, hits
    self.last_result = restore_last_result(self.game, snapshot.last_result)
    self.pending_pin_events, self.pending_landing_events = {}, {}
    self.statistics_dirty = true
    return true
end

function M.fixed_update(self, dt)
    local restored = model.fixed_update(self.game, dt)
    local state_changed = restored > 0
    local pin_events = model.drain_pin_events(self.game)
    for i = 1, #pin_events do
        self.pending_pin_events[#self.pending_pin_events + 1] = pin_events[i]
    end
    local events = model.drain_events(self.game)
    for i = 1, #events do
        local event = events[i]
        if event.type == "ball_landed" then
            state_changed = true
            self.last_result = event
            self.total_points = self.total_points + event.points
            self.total_hits = self.total_hits + 1
            self.bucket_hits[event.slot] = self.bucket_hits[event.slot] + 1
            self.statistics_dirty = true
            self.pending_landing_events[#self.pending_landing_events + 1] = event
        end
    end
    return state_changed
end

function M.update(self, dt)
    if self.view.on_pin_hit then
        for i = 1, #self.pending_pin_events do
            local event = self.pending_pin_events[i]
            self.view:on_pin_hit(event.pin_id, event.strength)
        end
    end
    self.pending_pin_events = {}
    if self.view.on_ball_landed then
        for i = 1, #self.pending_landing_events do
            self.view:on_ball_landed(self.pending_landing_events[i].slot)
        end
    end
    self.pending_landing_events = {}
    if self.view.update then
        self.view:update(dt)
    end
    self.view:render(self.game.balls)
end

function M.get_statistics(self)
    local hits = {}
    for slot = 1, self.game.layout.slot_count do hits[slot] = self.bucket_hits[slot] end
    return {
        total_hits = self.total_hits,
        total_points = self.total_points,
        bucket_hits = hits,
        bucket_count = self.game.layout.slot_count,
    }
end

function M.get_statistics_text(self)
    if not self.statistics_dirty then return self.statistics_text end
    local lines = {
        string.format("Hits: %d    Points: %d", self.total_hits, self.total_points),
        "Basket statistics:",
    }
    for slot = 1, self.game.layout.slot_count do
        local hits = self.bucket_hits[slot]
        local percentage = self.total_hits > 0 and hits / self.total_hits * 100 or 0
        lines[#lines + 1] = string.format("Basket %02d: %d (%.1f%%)", slot, hits, percentage)
    end
    self.statistics_text = table.concat(lines, "\n")
    self.statistics_dirty = false
    return self.statistics_text
end

function M.on_input(self, action_id, action)
    return self.view:on_input(action_id, action)
end

function M.final(self)
    self.view:final()
end

return M
