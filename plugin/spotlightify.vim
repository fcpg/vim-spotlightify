" spotlightify - highlighted search results, improved 
" Author: fcpg
" Credits: orig. repo (auto nohls): @romainl

if exists("g:loaded_spotlightify") || v:version < 703 || &compatible
      \ || !exists('*execute') || !exists('##OptionSet')
  finish
endif
let g:loaded_spotlightify = 1

let s:save_cpo = &cpo
set cpo&vim

"------------
" Debug {{{1
"------------
let g:splfy_debug = 0
if 0
append
  " comment out all dbg calls
  :g,\c^\s*call <Sid>Dbg(,s/call/"call/
  " uncomment
  :g,\c^\s*"call <Sid>Dbg(,s/"call/call/
.
endif


"----------------
" Functions {{{1
"----------------

" s:SaveHLGroup {{{2
function! s:SaveHLGroup(hlgroup) abort
  redir => hlsave
  silent! exe 'hi' a:hlgroup
  redir END
  if match(hlsave, "links to") != -1
    let hlsave = substitute(hlsave, '^.*links to ', 'link '.a:hlgroup.' ', '')
  else
    let hlsave = substitute(hlsave, '^\W*\(\w\+\)\s\+xxx', '\1', '')
  endif
  return hlsave
endfun

" s:RestoreHLGroup {{{2
function! s:RestoreHLGroup(hlgroup, save) abort
  silent! exe 'hi!' a:save
endfun

" s:SetSplfyCursorLine {{{2
function! s:SetSplfyCursorLine() abort
  "call <Sid>Dbg("SetSplfyCursorLine IN:")
  if !&cursorline
    "call <Sid>Dbg("  SetSplfyCursorLine setting custom hlgroup:")
    let g:splfy_cul_hlgroup = <Sid>SaveHLGroup('CursorLine')
    silent! hi! link CursorLine SplfyTransparentCursorLine
    silent! set cursorline
  endif
  "call <Sid>Dbg("SetSplfyCursorLine OUT:")
endfun

" s:RestoreCursorLine {{{2
function! s:RestoreCursorLine() abort
  "call <Sid>Dbg("RestoreCursorLine IN:")
  if exists('g:splfy_cul_hlgroup')
    "call <Sid>Dbg("  RestoreCursorLine IN: restoring cul")
    call <Sid>RestoreHLGroup('CursorLine', g:splfy_cul_hlgroup)
    unlet g:splfy_cul_hlgroup
    set nocursorline
  endif
  "call <Sid>Dbg("RestoreCursorLine OUT:")
endfun

" s:ClearMatches {{{2
function! s:ClearMatches() abort
  "call <Sid>Dbg("ClearMatches IN:")
  silent! if has_key(b:, 'splfy_matches') && !empty(b:splfy_matches)
    " clear matches
    for matchid in values(b:splfy_matches)
      silent! call matchdelete(matchid)
    endfor
    let b:splfy_matches = {}
  endif
  "call <Sid>Dbg("ClearMatches OUT:")
endfun

" s:CheckHL() {{{2
function! s:CheckHL() abort
  "call <Sid>Dbg("CheckHL IN:",
        \ get(b:, 'splfy_keephls', ''),
        \ get(b:, 'splfy_ctab_pat', ''),
        \ v:hlsearch
        \)
  " unset E from cpo if we set it
  if exists('g:splfy_cpo_E')
    let &cpo = substitute(&cpo, '\CE', '', 'g')
    unlet g:splfy_cpo_E
  endif
  if !v:hlsearch
    " hls has been turned off (eg. with :noh)
    " keephls & ctab_pat aren't relevant anymore for now
    "call <Sid>Dbg("  CheckHL hls off:")
    "call <Sid>Dbg("  CheckHL reset keephls:", get(b:, 'splfy_keephls', ''))
    silent! unlet b:splfy_keephls
    "call <Sid>Dbg("  CheckHL reset ctab_pat:", get(b:, 'splfy_ctab_pat', ''))
    silent! unlet b:splfy_ctab_pat
    " turn off whatever hl remains (cul, matches)
    call <Sid>StopHL()
  endif
  if has_key(b:, 'splfy_ctab_pat') && b:splfy_ctab_pat !=# @/
    " new search since last c<Tab>, reset things
    "call <Sid>Dbg("  CheckHL new search:")
    "call <Sid>Dbg("  CheckHL reset keephls:", get(b:, 'splfy_keephls', ''))
    silent! unlet b:splfy_keephls
    "call <Sid>Dbg("  CheckHL reset ctab_pat:", get(b:, 'splfy_ctab_pat', ''))
    silent! unlet b:splfy_ctab_pat
  endif
  " conditions to start checking hl:
  "   - hls is on
  "   - OR there's a matchadd defined
  " otherwise, nothing is done
  silent! if v:hlsearch
        \ || (has_key(b:, 'splfy_matches')
        \     && !empty(b:splfy_matches))
    if @/ ==# '' || !search('\%#\zs'.@/,'cnW')
      " moved out of a match or @/ reset, stop hls (unless c<Tab> in progress)
      if !has_key(b:, 'splfy_ctab_pat')
        "call <Sid>Dbg("  CheckHL stopping hili:")
        call <Sid>StopHL()
      endif
    else
      " cursor on a match
      "call <Sid>Dbg("  CheckHL starting hili:")
      if get(g:, 'splfy_curmatch', 1)
        " special hili for current occurrence
        call <Sid>SetSplfyCursorLine()
        let target_pat = (&ic?'\c':'\C').'\%#\%('.@/.'\)'
        if !exists('b:splfy_matches')
          let b:splfy_matches = {}
        endif
        if !has_key(b:splfy_matches, @/)
          "call <Sid>Dbg("  CheckHL matchadd:")
          silent! let matchid = matchadd(
                \ 'SplfyCurrentMatch',
                \ target_pat,
                \ 101)
          if matchid >= 0
            let b:splfy_matches[@/] = matchid
          else
            "call <Sid>Dbg("  CheckHL error in matchadd:")
          endif
        else
          "call <Sid>Dbg("  CheckHL already in b:splfy_matches:")
        endif
        " redraw
      endif
    endif
  else
    "call <Sid>Dbg("  CheckHL nop:")
  endif
  "call <Sid>Dbg("CheckHL OUT:")
endfun

" s:StopHL() {{{2
function! s:StopHL() abort
  "call <Sid>Dbg("StopHL IN:",
        \ get(b:, 'splfy_keephls', ''),
        \ get(b:, 'splfy_ctab_pat', ''),
        \ v:hlsearch
        \)
  call <Sid>RestoreCursorLine()
  call <Sid>ClearMatches()
  " only call nohls if hls is on, in normal mode
  if !v:hlsearch || mode() isnot 'n'
        \ || get(b:, 'splfy_keephls', 0)
        \ || get(g:, 'splfy_keephls', 0)
    "call <Sid>Dbg("StopHL OUT:")
    return
  else
    " set nohls out of func, otherwise it's reset
    "call <Sid>Dbg("  StopHL nohls:")
    silent! call feedkeys("\<Plug>(spotlightify)nohls", 'mi')
  endif
  "call <Sid>Dbg("StopHL OUT:")
endfun

" s:ChangedHLSearch() {{{2
function! s:ChangedHLSearch(old, new) abort
  "call <Sid>Dbg("ChangedHLSearch IN:")
  if a:old == 0 && a:new == 1
    " set hls
    "call <Sid>Dbg("  ChangedHLSearch: set hls")
    noremap  <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999) . ""
    noremap! <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999)

    autocmd Spotlightify CursorMoved * call <Sid>CheckHL()
    autocmd Spotlightify InsertEnter * call <Sid>StopHL()
  elseif a:old == 1 && a:new == 0
    " unset hls
    "call <Sid>Dbg("  ChangedHLSearch: unset hls")

    call <Sid>ClearMatches()

    unmap  <Plug>(spotlightify)nohls
    unmap! <Plug>(spotlightify)nohls

    autocmd! Spotlightify CursorMoved
    autocmd! Spotlightify InsertEnter
  else
    "call <Sid>Dbg("  ChangedHLSearch: nop")
    return
  endif
  "call <Sid>Dbg("ChangedHLSearch OUT:")
endfun

" SplfyGn {{{2
function! SplfyGn(dir) abort
  "call <Sid>Dbg("SplfyGn IN:")
  " remember search pattern, and keep hls on (for repeating cgn)
  let b:splfy_ctab_pat = @/
  let b:splfy_keephls = 1
  " save cpo and set E (error/nop on empty region)
  if stridx(&cpo, 'E') == -1
    let g:splfy_cpo_E = 1
    set cpo+=E
  endif
  if a:dir == -1
    .,1s###en
  else
    .,$s###en
  endif
  silent! set hls
  silent! exe 'norm!' (a:dir==-1 ? 'gN' : 'gn')
  if mode() !=? 'v'
    " didn't move, abort
    echohl WarningMsg
    echo "No more matches"
    echohl NONE
    " call feedkeys("\<Esc>cgn", 'tin')
  endif
  "call <Sid>Dbg("SplfyGn OUT:")
endfun

" SplfyPreGn {{{2
function! SplfyPreGn(dir, mode)
  let curpos_regex = '\%(\%#.\)\@<!'
  let b:splfy_keephls = 1
  if a:mode == 'n'
    let @/ = expand('<cword>').curpos_regex
  elseif a:mode == 'x'
    let @/ = strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \ . curpos_regex
  endif
  if len(@/) == len(curpos_regex)+1
    let ww_bak = &ww
    set ww&vim
    if a:dir == 1
      exe "norm! \<Bs>"
    else
      exe "norm! 1\<Space>"
    endif
    let &ww = ww_bak
    unlet ww_bak
  endif
endfun

" s:Dbg {{{2
function! s:Dbg(msg, ...) abort
  if g:splfy_debug
    let m = a:msg." /".@/."/"
    if a:0
      let m .= " [".join(a:000, "] [")."]"
    endif
    echom m
  endif
endfun


"-----------
" Maps {{{1
"-----------

" Plugs {{{2
nnoremap <silent> <Plug>(spotlightify)searchreplacefwd
      \ :call SplfyPreGn(1,'n')<cr>
      \c:let v:hlsearch=1<Bar>call SplfyGn(1)<cr>

nnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :call SplfyPreGn(-1,'n')<cr>
      \c:let v:hlsearch=1<Bar>call SplfyGn(-1)<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacefwd
      \ :<C-u>call SplfyPreGn(1,'x')<cr>
      \c:let v:hlsearch=1<Bar>call SplfyGn(1)<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :<C-u>call SplfyPreGn(-1,'x')<cr>
      \c:let v:hlsearch=1<Bar>call SplfyGn(-1)<cr>


" c/g<Tab> {{{2
if get(g:, 'splfy_setmaps', 1)
  if !hasmapto('<Plug>(spotlightify)searchreplacefwd', 'n')
    silent! nmap <unique><silent>  c<Tab>
          \ <Plug>(spotlightify)searchreplacefwd
  endif
  if !hasmapto('<Plug>(spotlightify)searchreplacebak', 'n')
    silent! nmap <unique><silent>  c<S-Tab>
          \ <Plug>(spotlightify)searchreplacebak
  endif
  if !hasmapto('<Plug>(spotlightify)searchreplacefwd', 'v')
    silent! xmap <unique><silent>  g<Tab>
          \ <Plug>(spotlightify)searchreplacefwd
  endif
  if !hasmapto('<Plug>(spotlightify)searchreplacebak', 'v')
    silent! xmap <unique><silent>  g<S-Tab>
          \ <Plug>(spotlightify)searchreplacebak
  endif
endif


"---------------
" Commands {{{1
"---------------

com! -bar Nohls
      \ nohls|call <Sid>StopHL()


"----------------
" HL groups {{{1
"----------------

hi SplfyTransparentCursorLine
      \                           term=NONE 
      \ ctermfg=NONE ctermbg=NONE cterm=NONE 
      \ guifg=NONE   guibg=NONE   gui=NONE

hi default link SplfyCurrentMatch IncSearch


"-----------
" Init {{{1
"-----------

augroup Spotlightify
  au!
  autocmd OptionSet hlsearch
        \ call <Sid>ChangedHLSearch(v:option_old, v:option_new)
augroup END

call <Sid>ChangedHLSearch(0, &hlsearch)

let &cpo = s:save_cpo

" vim: et sw=2:
