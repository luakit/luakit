--- Test settings.
--
-- @copyright 2017 Aidan Holm <aidanholm@gmail.com>

local assert = require "luassert"

local settings = require "settings"

local T = {}

T.test_settings = function ()
    assert.is_table(settings)

    settings.register_settings({
        ["test.setting.with.long.path"] = {
            default = "foo",
        }
    })

    assert.equal(settings.test.setting.with.long.path, "foo")
    settings.test.setting.with.long.path = "bar"
    assert.equal(settings.test.setting.with.long.path, "bar")
    assert.has_error(function () settings.test.setting = "baz" end)

    assert.has_error(function () settings.non_existent_setting = 1 end)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
