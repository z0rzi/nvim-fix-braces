if exists('g:loaded_fix_braces') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" command to run our plugin
command! FixBraces lua require'fix_braces'.fix_braces()

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_fix_braces = 1
