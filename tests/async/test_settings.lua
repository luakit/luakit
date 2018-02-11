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
            type = "string",
        },
        ["foo.bar"] = {
            type = "number",
        },
    })

    assert.equal(settings.test.setting.with.long.path, "foo")
    settings.test.setting.with.long.path = "bar"
    assert.equal(settings.test.setting.with.long.path, "bar")
    assert.has_error(function () settings.test.setting = "baz" end)

    assert.has_error(function () settings.non_existent_setting = 1 end)
    assert.has_error(function () return settings.on["foo"].on["foo"] end)

    settings.foo.bar = 1
    assert.equal(settings.foo.bar, 1)
    settings.on["example.com"].foo.bar = 2
    assert.equal(settings.foo.bar, 1)
    assert.equal(settings.on["example.com"].foo.bar, 2)
    assert.equal(settings.on[".com"].foo.bar, nil)
end

return T

-- vim: et:sw=4:ts=8:sts=4:tw=80
