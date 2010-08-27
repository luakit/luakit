" Vim syntax file
" Language:     luakit configuration
" Maintainer:   Gregor Uhlenheuer &lt;kongo2002@googlemail.com&gt;
" Last Change:  Fri 27 Aug 2010 09:46:46 PM CEST

if exists('b:current_syntax')
    finish
endif

runtime! syntax/lua.vim
unlet b:current_syntax

syntax include @JAVASCRIPT syntax/javascript.vim
try | syntax include @JAVASCRIPT after/syntax/javascript.vim | catch | endtry

syntax region jsBLOCK matchgroup=jsBLOCKMATCH start=/\[\[/ end=/\]\]/ contains=@JAVASCRIPT

hi link jsBLOCKMATCH SpecialComment

let b:current_syntax = 'luakit'
