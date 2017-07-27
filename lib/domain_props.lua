--- Automatically apply per-domain webview properties.
--
-- This module allows you to have site-specific settings. For example, you can
-- choose to enable WebGL only on certain specific sites, or enable JavaScript
-- only on a sub-domain of a website without enabling JavaScript for the root
-- domain.
--
-- ### Example `domain_props` rules
--
--     globals.domain_props = {
--         ["all"] = {
--             enable_scripts = false,
--             enable_plugins = false,
--         },
--         ["youtube.com"] = {
--             enable_scripts = true,
--         },
--         ["m.youtube.com"] = {
--             enable_scripts = false,
--         },
--     }
--
-- #### Explanation
--
-- There are three rules in the example. From top to bottom, they are
-- least-specific to most-specific:
--
--  - [m.youtube.com](https://m.youtube.com):  Any webpages on this domain will
--  have JavaScript disabled.
--  - [youtube.com](https://youtube.com): Any webpages on this
--  domain will have JavaScript enabled,_except for webpages on
--  [m.youtube.com](https://m.youtube.com)_. This is because the rule
--  for [m.youtube.com](https://m.youtube.com) is more specific than the
--  rule for [youtube.com](https://youtube.com), so its value for
--  `enable_scripts` is used for those sites.
--  - `all`: Any other webpages will have JavaScript disabled. In addition,
--  _all_ web pages will have plugins disabled, since no more-specific rules
--  specified a value for `enable_plugins`. This rule is less specific than all other rules.
--
-- ### Rule application
--
-- The order that rules are specified in the file does not matter, although
-- in the default the "all" rule is listed first. All properties in _any_ matching
-- rules are applied, but the value that is used is the one specified in the
-- most specific rule. If a property is not applied in any rule, it is not
-- changed.
--
-- ### Available properties
--
--  <ul style="column-count: 2">
--  <li> `allow_modal_dialogs`
--  <li> `auto_load_images`
--  <li> `cursive_font_family`
--  <li> `default_charset`
--  <li> `default_font_family`
--  <li> `default_font_size`
--  <li> `default_monospace_font_size`
--  <li> `draw_compositing_indicators`
--  <li> `editable`
--  <li> `enable_accelerated_2d_canvas`
--  <li> `enable_caret_browsing`
--  <li> `enable_developer_extras`
--  <li> `enable_dns_prefetching`
--  <li> `enable_frame_flattening`
--  <li> `enable_fullscreen`
--  <li> `enable_html5_database`
--  <li> `enable_html5_local_storage`
--  <li> `enable_hyperlink_auditing`
--  <li> `enable_java`
--  <li> `enable_javascript`
--  <li> `enable_mediasource`
--  <li> `enable_media_stream`
--  <li> `enable_offline_web_application_cache`
--  <li> `enable_page_cache`
--  <li> `enable_plugins`
--  <li> `enable_private_browsing`
--  <li> `enable_resizable_text_areas`
--  <li> `enable_site_specific_quirks`
--  <li> `enable_smooth_scrolling`
--  <li> `enable_spatial_navigation`
--  <li> `enable_tabs_to_links`
--  <li> `enable_webaudio`
--  <li> `enable_webgl`
--  <li> `enable_write_console_messages_to_stdout`
--  <li> `enable_xss_auditor`
--  <li> `fantasy_font_family`
--  <li> `javascript_can_access_clipboard`
--  <li> `javascript_can_open_windows_automatically`
--  <li> `load_icons_ignoring_image_load_setting`
--  <li> `media_playback_allows_inline`
--  <li> `media_playback_requires_user_gesture`
--  <li> `minimum_font_size`
--  <li> `monospace_font_family`
--  <li> `pictograph_font_family`
--  <li> `print_backgrounds`
--  <li> `sans_serif_font_family`
--  <li> `serif_font_family`
--  <li> `user_agent`
--  <li> `zoom_level`
--  <li> `zoom_text_only`
--  </ul>
--
-- @module domain_props
-- @author Mason Larobina
-- @copyright 2012 Mason Larobina

local lousy = require("lousy")
local webview = require("webview")
local globals = require("globals")
local domain_props = globals.domain_props

local _M = {}

webview.add_signal("init", function (view)
    view:add_signal("load-status", function (v, status)
        if status ~= "committed" or v.uri == "about:blank" then return end
        -- Get domain
        local domain = lousy.uri.parse(v.uri).host
        -- Strip leading www.
        domain = string.match(domain or "", "^www%.(.+)") or domain or "all"
        -- Build list of domain props tables to join & load.
        -- I.e. for example.com load { .example.com, example.com, .com }
        local prop_sets = { { domain = "all", props = domain_props.all or {} } }
        if domain ~= "all" then
            table.insert(prop_sets, { domain = domain, props = domain_props[domain] or {} })
        end
        repeat
            table.insert(prop_sets, { domain = "."..domain, props = domain_props["."..domain] or {} })
            domain = string.match(domain, "%.(.+)")
        until not domain

        -- Sort by rule precedence: "all" first, then by increasing specificity
        table.sort(prop_sets, function (a, b)
            if a.domain == "all" then return true end
            if b.domain == "all" then return false end
            return #a.domain < #b.domain
        end)

        -- Apply all properties
        for _, props in ipairs(prop_sets) do
            for k, prop in pairs(props.props) do
                msg.info("setting property %s = %s (matched %s)", k, prop, props.domain)
                view[k] = prop
            end
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
