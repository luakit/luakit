local lfs = require "lfs"
local lousy = { util = require "lib.lousy.util" }
local markdown = require "lib.markdown"

local index = {}

local text_macros = {
    available = function (arg)
        return ({
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
    ret = ret:gsub('@ref{([^}]+)}', function (ref)
        local r, reftext = ref:match("^(.*)%|(.*)$")
        ref, reftext = r or ref, reftext or ref:gsub(".*/", "")
        assert(index[ref] ~= false, "ambiguous ref '" .. ref .. "', prefix with doc/")
        assert(index[ref], "invalid ref '" .. ref .. "'")
        local doc, item = index[ref].doc, index[ref].item
        local group, name = doc.module and "modules" or "classes", doc.name
        local fragment = item and ("#%s-%s"):format(item.type, item.name) or ""
        return ('<a href="../%s/%s.html%s">`%s`</a>'):format(group, name, fragment, reftext)
    end)
    -- Format with markdown
    ret = markdown(ret)
    ret = ret:gsub("<pre><code>(.-)</code></pre>", function (code)
        -- Add syntax highlighting if lxsh is installed
        local ok, lxsh = pcall(require, "lxsh")
        if ok then
            code = lxsh.highlighters.lua(
                lousy.util.unescape(code),  -- Fix < and > being escaped inside code -_- fail
                { formatter = lxsh.formatters.html, external = true }
            )
        else
            code = "<pre class='sourcecode lua'>" .. code .. "</pre>"
        end
        return code
    end)
    return ret
end

local shift_hdr = function (text, n)
    return ("\n"..text):gsub("\n#", "\n" .. string.rep("#", n+1)):sub(2)
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
                    <div>{optional}</div>
                    <div>{default}</div>
                </div>
                <div>{desc}</div>
            </div>
        </li>
    ]==]
    local html = string.gsub(html_template, "{(%w+)}", {
        name = param.name,
        typestr = "Type: " .. generate_typestr_html(param.typestr),
        desc = html_unwrap_first_p(format_text(shift_hdr(param.desc, 3))),
        optional = param.optional and "Optional" or "",
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
        desc = html_unwrap_first_p(format_text(shift_hdr(ret.desc, 3))),
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
        <div>
            {deprecated}
            {desc}
            {params}
            {returns}
        </div>
    ]==]
    local html = string.gsub(html_template, "{([%w_]+)}", {
        deprecated = generate_deprecated_html(func),
        desc = format_text(shift_hdr(func.desc, 3)),
        params = generate_function_params_html(func.params),
        returns = generate_function_returns_html(func.returns),
    })
    return html
end

local generate_function_html = function (func, prefix)
    if func.name == "__call" then
        prefix = prefix:gsub(".$", "")
        func.name = ""
    end
    local html_template = [==[
        <div class=function id="{type}-{name}">
            <h3>
                <a href="#{type}-{name}">{prefix}{name} ({param_names})</a>
            </h3>
            {body}
        </div>
    ]==]

    local param_names = {}
    for _, param in ipairs(func.params) do
        table.insert(param_names, (param.opt and "["..param.name.."]" or param.name))
    end

    local html = string.gsub(html_template, "{([%w_]+)}", {
        prefix = prefix,
        type = func.type,
        name = func.name,
        param_names = table.concat(param_names, ", "),
        body = generate_function_body_html(func),
    })
    return html
end

local generate_signal_html = function (func)
    local html_template = [==[
        <div class=function id="signal-{name}">
            <h3>
                <a href="#signal-{name}">"{name}"</a>
            </h3>
            {body}
        </div>
    ]==]

    local html = string.gsub(html_template, "{([%w_]+)}", {
        name = func.name,
        body = generate_function_body_html(func),
    })
    return html
end

local generate_attribution_html = function (doc)
    if #doc.copyright == 0 then return "" end
    local html = { "<h2>Attribution</h2>" }
    table.insert(html, "<div class=attr-wrap>")
    table.insert(html, "    <h4>Copyright</h4><ul class=copyright>")
    for _, copy in ipairs(doc.copyright) do
        copy = copy:gsub(" %<.-%>$", ""):gsub("(%d+)%-(%d+)", "%1&ndash;%2")
        table.insert(html, "        <li>" .. copy)
    end
    table.insert(html, "    </ul>")
    table.insert(html, "</div>")

    return table.concat(html, "\n")
end

local generate_property_html = function (prop, prefix)
    local html_template = [==[
        <div class=property id="property-{name}">
            <h3>
                <a href="#property-{name}">{prefix}{name}</a>
            </h3>
            {deprecated}
            <div class="two-col property-body">
                <div>
                    <div>{typestr}</div>
                    <div>{default}</div>
                    <div>{readwrite}</div>
                </div>
                <div>{desc}</div>
            </div>
        </div>
    ]==]

    assert(prop.readonly or prop.readwrite, "Property " .. prop.name .. " missing RO/RW annotation")

    local html = string.gsub(html_template, "{([%w_]+)}", {
        prefix = prefix,
        name = prop.name,
        deprecated = generate_deprecated_html(prop),
        typestr = "Type: " .. generate_typestr_html(prop.typestr),
        desc = html_unwrap_first_p(format_text(shift_hdr(prop.desc, 3))),
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

local generate_doc_html = function (doc)
    local html_template = [==[
        <h1>{type} <code>{title}</code></h1>
        <!-- status indicator -->
        <span class=tagline>{tagline}</span>
        {desc}
        {functions}
        {attribution}
    ]==]

    -- Determine function name prefix
    local prefix = doc.prefix or doc.name
    local func_prefix, method_prefix = prefix .. ".", prefix .. ":"

    local fhtml = ""
        .. "<!-- modes and binds -->"
        .. generate_list_html("Functions", doc.functions, generate_function_html, func_prefix)
        .. generate_list_html("Methods", doc.methods, generate_function_html, method_prefix)
        .. generate_list_html("Properties", doc.properties, generate_property_html, func_prefix)
        .. generate_list_html("Signals", doc.signals, generate_signal_html)
        .. generate_list_html("Callback Types", doc.callbacks, generate_function_html, "")

    local html = string.gsub(html_template, "{(%w+)}", {
        type = doc.module and "Module" or "Class",
        title = doc.name,
        tagline = doc.tagline:gsub("%.$",""),
        desc = format_text(shift_hdr(doc.desc, 1)),
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
        html = html .. "<ul class=" .. name .. ">\n"
        for _, doc in ipairs(section) do
            if doc == current_doc then
                html = html .. ('    <li><span>%s</span></li>\n'):format(doc.name)
            else
                html = html .. ('    <li><a href="../%s/%s.html">%s</a></li>\n'):format(name,
                    doc.filename or doc.name, doc.name)
            end
        end
        html = html .. "</ul>\n"
    end
    return html
end

local generate_pagination_html = function (pagination)
    return ("<div style='display:none'>{prv}{nxt}</div>"):gsub("{(%w+)}", {
        prv = pagination.prv and ("<a rel=prev href='../" .. pagination.prv .. "'></a>") or "",
        nxt = pagination.nxt and ("<a rel=next href='../" .. pagination.nxt .. "'></a>") or "",
    })
end

local generate_module_html = function (doc, style, docs, pagination)
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
            {pagination}
        </div>
    </body>
    ]==]

    local html = string.gsub(html_template, "{(%w+)}", {
        title = doc.name,
        style = style,
        section = doc.module and "Modules" or doc.class and "Classes" or "Pages",
        body = generate_doc_html(doc),
        sidebar = generate_sidebar_html(docs, doc),
        pagination = generate_pagination_html(pagination),
    })
    return html
end

local generate_page_html = function (doc, style, docs, pagination)
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
            {pagination}
        </div>
    </body>
    ]==]

    local html = string.gsub(html_template, "{(%w+)}", {
        title = doc.name,
        style = style,
        body = format_text(assert(doc.text, "No page text")),
        sidebar = generate_sidebar_html(docs, doc),
        pagination = generate_pagination_html(pagination),
    })
    return html
end

local generate_index_html = function (style, docs)
    local html_template = [==[
    <!doctype html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Luakit Documentation</title>
        <style>
        {style}
        #wrap { padding-top: 0; }
        ul { column-count: 3; list-style-position: inside; padding-left: 1.5rem; }
        @media (max-width: 650px) { ul { column-count: 2; } }
        @media (max-width: 400px) { ul { column-count: 1; } }
        </style>
    </head>
    <body>
        <div id=hdr>
            <h1>Luakit Documentation &nbsp;&nbsp;/&nbsp;&nbsp; Index</h1>
        </div>
        <div id=wrap>
            <div id=content>
                <h2>Pages</h2>
                {pages}
                <h2>Modules</h2>
                {modules}
                <h2>Classes</h2>
                {classes}
            </div>
        </div>
    </body>
    ]==]

    local lists = {}
    for _, name in ipairs{"pages", "modules", "classes"} do
        local html = ""
        local section = assert(docs[name], "Missing " .. name .. " section")
        html = html .. "<ul>\n"
        for _, doc in ipairs(section) do
            html = html .. ('    <li><a href="%s/%s.html">%s</a></li>\n'):format(name,
                doc.filename or doc.name, doc.name)
        end
        for _=1,(3-#section%3)%3 do html = html .. '    <li class=dummy></li>\n' end
        lists[name] = html .. "</ul>\n"
    end

    local html = string.gsub(html_template, "{(%w+)}", {
        style = style,
        pages = lists.pages,
        modules = lists.modules,
        classes = lists.classes,
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

    -- Build symbol index
    do
        local add_index_obj = function (doc, item)
            local name = item and (item.type == "signal" and '"'..item.name..'"' or item.name)
            local short_name = name or doc.name
            local long_name = doc.name .. "/" .. (name or "")
            -- Always allow using the long name
            assert(not index[long_name], "Name conflict for " .. long_name)
            index[long_name] = { doc = doc, item = item }
            -- Allow using the short name, but blacklist it on collision
            if index[short_name] == nil then
                index[short_name] = { doc = doc, item = item }
            else
                index[short_name] = false
            end
        end
        for _, doc in ipairs(lousy.util.table.join(docs.modules, docs.classes)) do
            add_index_obj(doc)
            for _, t in ipairs {"functions", "methods", "properties", "signals", "callbacks"} do
                for _, item in ipairs(doc[t] or {}) do
                    add_index_obj(doc, item)
                end
            end
        end
    end

    local pages = {}
    mkdir(out_dir .. "pages")
    for _, page in ipairs(docs.pages) do
        pages[#pages+1] = {
            doc = page, gen = generate_page_html,
            path = "pages/" .. page.filename .. ".html",
        }
    end
    for _, section_name in ipairs{"modules", "classes"} do
        mkdir(out_dir .. section_name)
        local section_docs = docs[section_name]
        for _, doc in ipairs(section_docs) do
            pages[#pages+1] = {
                doc = doc, gen = generate_module_html,
                path = section_name .. "/" .. doc.name .. ".html",
            }
        end
    end

    for i, page in ipairs(pages) do
        print("Generating '" .. page.path .. "'...")
        local pagination = {
            nxt = (pages[i+1] or {}).path,
            prv = (pages[i-1] or {}).path,
        }
        write_file(out_dir .. page.path, page.gen(page.doc, style, docs, pagination))
    end

    -- Generate index
    local path = out_dir .. "index.html"
    print("Generating '" .. path .. "'...")
    write_file(path, generate_index_html(style, docs))
end

return {
    generate_documentation = generate_documentation,
}

-- vim: et:sw=4:ts=8:sts=4:tw=80
