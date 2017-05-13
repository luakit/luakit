local lfs = require "lfs"
local lousy = { util = require "lib.lousy.util" }
local markdown = require "lib.markdown"

local text_macros = {
    available = function (arg)
        return ({
            both = '<div class="alert good">This module is available from both UI and web process Lua states.</div>',
              ui = '<div class="alert warn">This module is only available from the UI process Lua state.</div>',
             web = '<div class="alert warn">This module is only available from web process Lua states.</div>',
        })[arg] or error("available macro: expected ui, web, or both as argument")
    end,
    alert = function (str)
        return '<div class="alert warn">' .. str .. '</div>'
    end,
}
local format_text = function (text)
    local ret = text:gsub("DOCMACRO%((%w+):?([^%)]-)%)", function (macro, args)
        if not text_macros[macro] then error("Bad macro '" .. macro .. "'") end
        return (text_macros[macro])(args)
    end)
    -- Format with markdown
    ret = markdown(ret)
    ret = ret:gsub("<pre><code>(.-)</code></pre>", function (code)
        -- Fix < and > being escaped inside code -_- fail
        code = lousy.util.unescape(code)
        -- Add syntax highlighting if lxsh is installed
        local ok, lxsh = pcall(require, "lxsh")
        if ok then code = lxsh.highlighters.lua(code, { formatter = lxsh.formatters.html, external = true }) end
        return code
    end)
    return ret
end

local generate_typestr_html = function (typestr)
    if not typestr then return "<span class=any_type>any type</span>" end
    local alts = {}
    for sub in typestr:gmatch("[^%|]+") do
        table.insert(alts, "<span class=type>" .. sub .. "</span>")
    end
    return table.concat(alts, " or ")
end

local html_unwrap_first_p = function (html)
    return html:gsub("</?p>", "", 2) -- Remove first two open/closing p tags
end

local generate_deprecated_html = function (item)
    if not item.deprecated then return "" end
    return text_macros.alert("Deprecated: " .. html_unwrap_first_p(format_text(item.deprecated)))
end

local generate_function_param_html = function (param)
    local html_template = [==[
        <li class=parameter>
            <div class=two-col>
                <div>
                    <span class=parameter>{name}</span>
                    <div>{typestr}</div>
                    <div>{default}</div>
                </div>
                <div>{desc}</div>
            </div>
        </li>
    ]==]
    local html = string.gsub(html_template, "{(%w+)}", {
        name = param.name,
        typestr = "Type: " .. generate_typestr_html(param.typestr),
        desc = html_unwrap_first_p(format_text(param.desc)),
        default = param.default and "Default: " .. html_unwrap_first_p(format_text(param.default)) or "",
    })
    return html
end

local generate_function_return_html = function (ret)
    local html_template = [==[
        <li>
            <div class=two-col>
                <div>{typestr}</div><div>{desc}</div>
            </div>
        </li>
    ]==]
    local html = string.gsub(html_template, "{(%w+)}", {
        typestr = generate_typestr_html(ret.typestr),
        desc = html_unwrap_first_p(format_text(ret.desc)),
    })
    return html
end

local generate_function_params_html = function (params)
    if #params == 0 then return "" end
    local param_html = {"<h4>Parameters</h4>"}
    table.insert(param_html, "<ul>")
    for _, param in ipairs(params) do
        table.insert(param_html, generate_function_param_html(param))
    end
    table.insert(param_html, "</ul>")
    return table.concat(param_html, "\n")
end

local generate_function_returns_html = function (returns)
    if #returns == 0 then return "" end
    local return_html = {"<h4>Return Values</h4>"}
    table.insert(return_html, "<ul>")
    for _, ret in ipairs(returns) do
        table.insert(return_html, generate_function_return_html(ret))
    end
    table.insert(return_html, "</ul>")
    return table.concat(return_html, "\n")
end

local generate_function_body_html = function (func)
    local html_template = [==[
        <div class=function>
            {deprecated}
            {desc}
            {params}
            {returns}
        </div>
    ]==]
    local html = string.gsub(html_template, "{([%w_]+)}", {
        deprecated = generate_deprecated_html(func),
        desc = format_text(func.desc),
        params = generate_function_params_html(func.params),
        returns = generate_function_returns_html(func.returns),
    })
    return html
end

local generate_function_html = function (func, prefix)
    local html_template = [==[
        <h3 class=function id="{prefix}{name}">
            <a href="#{prefix}{name}">{prefix}{name} ({param_names})</a>
        </h3>
    ]==]

    local param_names = {}
    for _, param in ipairs(func.params) do
        table.insert(param_names, (param.opt and "["..param.name.."]" or param.name))
    end

    local html = string.gsub(html_template, "{([%w_]+)}", {
        prefix = prefix,
        name = func.name,
        param_names = table.concat(param_names, ", "),
    }) .. generate_function_body_html(func)
    return html
end

local generate_signal_html = function (func)
    local html_template = [==[
        <h3 class=function id="signal-{name}">
            <a href="#signal-{name}">"{name}"</a>
        </h3>
    ]==]

    local html = string.gsub(html_template, "{([%w_]+)}", {
        name = func.name,
    }) .. generate_function_body_html(func)
    return html
end

local generate_attribution_html = function (doc)
    local html = {}
    table.insert(html, "<div class=attr-wrap>")
    table.insert(html, "    <h4>Authors</h4>")
    table.insert(html, "    <ul class=authors>")
    for _, author in ipairs(doc.author) do
        table.insert(html, "        <li>" .. author)
    end
    table.insert(html, "    </ul>")
    table.insert(html, "</div>")

    table.insert(html, "<div class=attr-wrap>")
    table.insert(html, "    <h4>Copyright</h4><ul class=copyright>")
    for _, copy in ipairs(doc.copyright) do
        table.insert(html, "        <li>" .. copy)
    end
    table.insert(html, "    </ul>")
    table.insert(html, "</div>")

    return table.concat(html, "\n")
end

local generate_property_html = function (prop, prefix)
    local html_template = [==[
        <h3 class=property id="property-{name}">
            <a href="#property-{name}">{prefix}{name}</a>
        </h3>
        <div class="two-col property">
            <div>
                <div>{typestr}</div>
                <div>{default}</div>
                <div>{readwrite}</div>
            </div>
            <div>{desc}</div>
        </div>
    ]==]

    local html = string.gsub(html_template, "{([%w_]+)}", {
        prefix = prefix,
        name = prop.name,
        typestr = "Type: " .. generate_typestr_html(prop.typestr),
        desc = html_unwrap_first_p(format_text(prop.desc)),
        default = prop.default and "Default: " .. html_unwrap_first_p(format_text(prop.default)) or "",
        readwrite = (prop.readonly and "Read-only") or (prop.readwrite and "Read-write")
    })
    return html
end

local generate_list_html = function (heading, list, item_func, ...)
    if not list or #list == 0 then return "" end
    local html = "<h2>" .. heading .. "</h2>\n"
    for _, item in ipairs(list) do
        html = html .. "\n" .. item_func(item, ...)
    end
    return html
end

local generate_binds_and_modes_html = function (doc)
    local n = 0
    for _, binds in pairs(doc.bind_info or {}) do n = n + #binds end
    if n == 0 then return "" end

    local html = "<h2>Binds and Modes</h2>\n"
    for mode_name, binds in pairs(doc.bind_info) do
        if #binds > 0 then
            html = html .. ("<h3><code>%s</code> mode</h3>\n"):format(mode_name)
            html = html .. "<ul class=binds>\n"
            for _, bind in ipairs(binds) do
                html = html .. "<li><div class=two-col><ul class=triggers>"
                local names = type(bind.name) == "string" and {bind.name} or bind.name
                for i, name in ipairs(names) do
                    names[i] = ("<li>%s"):format(lousy.util.escape(name))
                end
                local desc = bind.desc or "<i>No description</i>"
                desc = html_unwrap_first_p(format_text(lousy.util.string.dedent(desc)))
                html = html .. table.concat(names, "") .. "</ul><div class=desc>" .. desc .. "</div></div>"
            end
            html = html .. "</ul>\n"
        end
    end
    return html
end

local generate_field_html = function (field, prefix)
    local html_template = [==[
        <h3 class=field id="field-{name}">
            <a href="#field-{name}">{prefix}{name}</a>
        </h3>
        <div class="two-col field">
            <div>
                <div>{typestr}</div>
                <div>{default}</div>
                <div>{readwrite}</div>
            </div>
            <div>{desc}</div>
        </div>
    ]==]

    local html = string.gsub(html_template, "{([%w_]+)}", {
        prefix = prefix,
        name = field.name,
        typestr = "Type: " .. generate_typestr_html(field.typestr),
        desc = html_unwrap_first_p(format_text(field.desc)),
        default = field.default and "Default: " .. html_unwrap_first_p(format_text(field.default)) or "",
        readwrite = (field.readonly and "Read-only") or (field.readwrite and "Read-write"),
    })
    return html
end

local generate_doc_html = function (doc)
    local html_template = [==[
        <h1>Module <code>{title}</code></h1>
        <h2 class=tagline>{tagline}</h2>
        {desc}
        {functions}
        <h2>Attribution</h2>
        {attribution}
    ]==]

    -- Determine function name prefix
    local prefix, method_name_prefix
    if doc.methods then
        prefix = ""
        method_name_prefix = doc.name .. ":"
    else
        prefix = doc.name .. "."
    end

    local fhtml = ""
        .. generate_binds_and_modes_html(doc)
        .. generate_list_html("Functions", doc.functions, generate_function_html, prefix)
        .. generate_list_html("Methods", doc.methods, generate_function_html, method_name_prefix)
        .. generate_list_html("Properties", doc.properties, generate_property_html, doc.name .. ".")
        .. generate_list_html("Signals", doc.signals, generate_signal_html)
        .. generate_list_html("Fields", doc.fields, generate_field_html, prefix)

    local html = string.gsub(html_template, "{(%w+)}", {
        title = doc.name,
        tagline = doc.tagline:gsub("%.$",""),
        desc = format_text(doc.desc),
        functions = fhtml,
        attribution = generate_attribution_html(doc)
    })
    return html
end

local generate_sidebar_html = function (docs, current_doc)
    local html = ""
    for _, name in ipairs{"pages", "modules", "classes"} do
        local section = assert(docs[name], "Missing " .. name .. " section")
        html = html .. ("<h3>%s</h3>\n"):format(name:gsub("^%l", string.upper))
        html = html .. "<ul>\n"
        for _, doc in ipairs(section) do
            if doc == current_doc then
                html = html .. ('    <li><span>%s</span></li>\n'):format(doc.name)
            else
                html = html .. ('    <li><a href="../%s/%s.html">%s</a></li>\n'):format(name, doc.name, doc.name)
            end
        end
        html = html .. "</ul>\n"
    end
    return html
end

local generate_module_html = function (doc, style, docs)
    local html_template = [==[
    <!doctype html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>{title} - Luakit</title>
        <style>{style}</style>
    </head>
    <body>
        <div id=hdr>
            <h1>Luakit Documentation &nbsp;&nbsp;/&nbsp;&nbsp; {section} &nbsp;&nbsp;/ &nbsp;&nbsp;{title}</h1>
        </div>
        <div id=wrap>
            <div id=sidebar>
                <h2>Table of Contents</h2>
                {sidebar}
            </div>
            <div id=content>
                {body}
            </div>
        </div>
    </body>
    ]==]

    local sidebar_html = generate_sidebar_html(docs, doc)

    local html = string.gsub(html_template, "{(%w+)}", {
        title = doc.name,
        style = style,
        section = doc.module and "Modules" or doc.class and "Classes" or "Pages",
        body = generate_doc_html(doc),
        sidebar = sidebar_html,
    })
    return html
end

local generate_page_html = function (doc, style, docs)
    local html_template = [==[
    <!doctype html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>{title} - Luakit</title>
        <style>{style}</style>
    </head>
    <body>
        <div id=hdr>
            <h1>Luakit Documentation &nbsp;&nbsp;/&nbsp;&nbsp; Pages &nbsp;&nbsp;/ &nbsp;&nbsp;{title}</h1>
        </div>
        <div id=wrap>
            <div id=sidebar>
                <h2>Table of Contents</h2>
                {sidebar}
            </div>
            <div id=content>
                {body}
            </div>
        </div>
    </body>
    ]==]

    local sidebar_html = generate_sidebar_html(docs, doc)

    local html = string.gsub(html_template, "{(%w+)}", {
        title = doc.name,
        style = style,
        body = format_text(assert(doc.text, "No page text")),
        sidebar = sidebar_html,
    })
    return html
end

local generate_documentation = function (docs, out_dir)
    -- Utility functions
    local mkdir = function (path)
        if lfs.attributes(path, "mode") == "directory" then return end
        assert(lfs.mkdir(path))
    end
    local write_file = function (path, html)
        local f = assert(io.open(path, "w"))
        f:write(html)
        f:close()
    end

    -- Load doc stylesheet
    local f = assert(io.open(docs.stylesheet, "r"), "no stylesheet found")
    local style = f:read("*a")
    f:close()

    -- Create output directory
    assert(out_dir, "no output directory specified")
    out_dir = out_dir:match("/$") and out_dir or out_dir .. "/"
    mkdir(out_dir)

    -- Generate module and class pages
    for _, section_name in ipairs{"modules", "classes"} do
        mkdir(out_dir .. section_name)
        local section_docs = docs[section_name]
        for _, doc in ipairs(section_docs) do
            local path = out_dir .. section_name .. "/" .. doc.name .. ".html"
            print("Generating '" .. path .. "'...")
            write_file(path, generate_module_html(doc, style, docs))
        end
    end

    -- Generate markdown pages
    mkdir(out_dir .. "pages")
    for _, page in ipairs(docs.pages) do
        local path = out_dir .. "pages/" .. page.name .. ".html"
        print("Generating '" .. path .. "'...")
        write_file(path, generate_page_html(page, style, docs))
    end
end

return {
    generate_documentation = generate_documentation,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
