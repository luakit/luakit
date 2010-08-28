" Vim syntax file
" Language:     luakit configuration
" Maintainer:   Gregor Uhlenheuer &lt;kongo2002@googlemail.com&gt;
" Last Change:  Fri 27 Aug 2010 09:46:46 PM CEST

if exists('b:current_syntax')
    finish
endif

runtime! syntax/lua.vim

" Javascript between [=[ & ]=] regions
unlet b:current_syntax
syntax include @JAVASCRIPT syntax/javascript.vim
try | syntax include @JAVASCRIPT after/syntax/javascript.vim | catch | endtry
syntax region jsBLOCK matchgroup=jsBLOCKMATCH start=/\[=\[/ end=/\]=\]/ contains=@JAVASCRIPT
hi link jsBLOCKMATCH SpecialComment

" HTML between [==[ & ]==] regions
unlet b:current_syntax
syntax include @HTML syntax/html.vim
try | syntax include @HTML after/syntax/html.vim | catch | endtry
syntax region htmlBLOCK matchgroup=htmlBLOCKMATCH start=/\[==\[/ end=/\]==\]/ contains=@HTML
hi link htmlBLOCKMATCH SpecialComment

" CSS between [===[ & ]===] regions
unlet b:current_syntax
syntax include @CSS syntax/css.vim
try | syntax include @CSS after/syntax/css.vim | catch | endtry
syntax region cssBLOCK matchgroup=cssBLOCKMATCH start=/\[===\[/ end=/\]===\]/ contains=@CSS
hi link cssBLOCKMATCH SpecialComment

let b:current_syntax = 'luakit'
