-- Save payload round-trip and the D19 rule: missing or corrupt → room 0.
local Save = require("save")

local ROOMS = 2

describe("save payload", function()
    it("round-trips a valid room id", function()
        assert.are.equal(1, Save.decode(Save.encode(1, "abc"), ROOMS))
    end)

    it("falls back to room 0 when missing, corrupt or out of range", function()
        assert.are.equal(0, Save.decode(nil, ROOMS))
        assert.are.equal(0, Save.decode("", ROOMS))
        assert.are.equal(0, Save.decode("\0\255garbage", ROOMS))
        assert.are.equal(0, Save.decode("room_id=7\n", ROOMS))
        assert.are.equal(0, Save.decode("room_id=-1\n", ROOMS))
        assert.are.equal(0, Save.decode("room_id=1", ROOMS)) -- truncated write
    end)
end)
