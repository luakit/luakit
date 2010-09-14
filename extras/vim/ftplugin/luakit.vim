" Vim filetype plugin
" Language:     luakit configuration
" Maintainer:   Gregor Uhlenheuer &lt;kongo2002@googlemail.com&gt;
" Last Change:  Tue 14 Sep 2010 01:18:20 PM CEST

" Custom configuration:
"
"   Set 'g:luakit_prefix' to the path prefix where the system-wide
"   luakit configuration files are installed to. The default is set to
"   something like '/etc/xdg' or '/usr/share/xdg'.
"   If this variable is not defined the path is tried to determine via the
"   environment variable $XDG_CONFIG_DIRS
"
"       let g:luakit_prefix = '/etc/xdg'
"
"   Defined mappings (buffer-local):
"
"       <Leader>ld  Diff current config file with its system-wide counterpart

if exists('b:did_luakit')
    finish
endif
let b:did_luakit = 1

if !exists('g:luakit_prefix')
    let g:luakit_prefix = '/etc/xdg'
endif

function! s:GetFile()
    let fcomponents = []
    if $XDG_CONFIG_DIRS != ''
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
            echom 'Could not find system-wide luakit '''.expand('%:t').''' file'
            echom 'Please define ''g:luakit_prefix'''
            echohl None
        endif
    endfunction
endif

com! -buffer LuakitDiff call CompareLuakitFile()
nmap <buffer> <Leader>ld :LuakitDiff<CR>

runtime! ftplugin/lua.vim
