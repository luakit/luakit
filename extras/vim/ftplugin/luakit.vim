" Vim filetype plugin
" Language:     luakit configuration
" Maintainer:   Gregor Uhlenheuer &lt;kongo2002@googlemail.com&gt;
" Last Change:  Tue 14 Sep 2010 12:27:45 PM CEST

if exists('b:did_luakit')
    finish
endif
let b:did_luakit = 1

function! s:GetFile()
    let fcomponents = []
    if !exists('g:luakit_prefix')
        call add(fcomponents, $XDG_CONFIG_DIRS)
    else
        call add(fcomponents, g:luakit_prefix)
    endif
    call add(fcomponents, "luakit")
    call add(fcomponents, expand('%:t'))
    let config_file = join(fcomponents, '/')
    if filereadable(config_file)
        return config_file
    endif
    return ''
endfunction

if !exists('*CompareLuakitFile')
    function! CompareLuakitFile()
        let file = <SID>GetFile()
        if file != ''
            if file != expand('%:p')
                exe 'vert diffsplit' file
                wincmd p
            else
                echohl WarningMsg
                echom 'You cannot compare the file with itself'
                echohl None
            endif
        else
            echohl WarningMsg
            echom 'Could not find system-wide luakit '.expand('%:t').' file'
            echom 'Define g:luakit_prefix'
            echohl None
        endif
    endfunction
endif

com! -buffer LuakitDiff call CompareLuakitFile()
nmap <buffer> <Leader>ld :LuakitDiff<CR>

runtime! ftplugin/lua.vim
