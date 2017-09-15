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

let g:splfy_debug = 0


"----------------
" Functions {{{1
"----------------

" s:SaveHLGroup {{{2
function! s:SaveHLGroup(hlgroup)
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
function! s:RestoreHLGroup(hlgroup, save)
  silent! exe 'hi!' a:save
endfun

" s:SetSplfyCursorLine {{{2
function! s:SetSplfyCursorLine()
  call <Sid>Dbg("SetSplfyCursorLine IN:")
  if !&cursorline
    call <Sid>Dbg("  SetSplfyCursorLine setting custom hlgroup:")
    let b:splfy_cul_hlgroup = <Sid>SaveHLGroup('CursorLine')
    silent! hi! link CursorLine SplfyTransparentCursorLine
    silent! set cursorline
  endif
  call <Sid>Dbg("SetSplfyCursorLine OUT:")
endfun

" s:RestoreCursorLine {{{2
function! s:RestoreCursorLine()
  call <Sid>Dbg("RestoreCursorLine IN:")
  if exists('b:splfy_cul_hlgroup')
    call <Sid>Dbg("  RestoreCursorLine IN: restoring cul")
    call <Sid>RestoreHLGroup('CursorLine', b:splfy_cul_hlgroup)
    unlet b:splfy_cul_hlgroup
    set nocursorline
  endif
  call <Sid>Dbg("RestoreCursorLine OUT:")
endfun

" s:ClearMatches {{{2
function! s:ClearMatches()
  silent! if has_key(b:, 'splfy_matches') && !empty(b:splfy_matches)
    " clear matches
    for matchid in values(b:splfy_matches)
      silent! call matchdelete(matchid)
    endfor
    let b:splfy_matches = {}
  endif
endfun

" s:CheckHL() {{{2
function! s:CheckHL()
  call <Sid>Dbg("CheckHL IN:",
        \ get(b:, 'splfy_keephls', ''),
        \ get(b:, 'splfy_ctab_pat', ''),
        \ v:hlsearch
        \)
  if !v:hlsearch
    " hls has been turned off (eg. with :noh), so keephls isn't relevant
    " anymore for now
    call <Sid>Dbg("  CheckHL reset keephls:")
    let b:splfy_keephls = 0
    " no need for special hili either
    call <Sid>RestoreCursorLine()
  endif
  if has_key(b:, 'splfy_ctab_pat') && b:splfy_ctab_pat !=# @/
    " new search since last c<Tab>, reset things
    call <Sid>Dbg("  CheckHL reset keephls & ctab_pat:")
    let b:splfy_keephls = 0
    unlet b:splfy_ctab_pat
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
        call <Sid>Dbg("  CheckHL stopping hili:")
        call <Sid>StopHL()
      endif
    else
      " cursor on a match
      call <Sid>Dbg("  CheckHL starting hili:")
      if get(g:, 'splfy_curmatch', 1)
        " special hili for current occurrence
        call <Sid>SetSplfyCursorLine()
        let target_pat = '\c\%#\%('.@/.'\)'
        if !exists('b:splfy_matches')
          let b:splfy_matches = {}
        endif
        if !has_key(b:splfy_matches, @/)
          call <Sid>Dbg("  CheckHL matchadd:")
          let matchid = matchadd(
                \ get(g:, 'splfy_curmatch_hlgroup', 'IncSearch'),
                \ target_pat,
                \ 101)
          let b:splfy_matches[@/] = matchid
        else
          call <Sid>Dbg("  CheckHL already in b:splfy_matches:")
        endif
        " redraw
      endif
    endif
  else
    call <Sid>Dbg("  CheckHL nop:")
  endif
  call <Sid>Dbg("CheckHL OUT:")
endfun

" s:StopHL() {{{2
function! s:StopHL()
  call <Sid>Dbg("StopHL IN:",
        \ get(b:, 'splfy_keephls', ''),
        \ get(b:, 'splfy_ctab_pat', ''),
        \ v:hlsearch
        \)
  call <Sid>RestoreCursorLine()
  " keep matches if c<Tab> in progress
  if get(b:, 'splfy_ctab_pat', '') == ''
    call <Sid>Dbg("  StopHL clearmatches:")
    call <SID>ClearMatches()
  endif
  if !v:hlsearch || mode() isnot 'n'
        \ || get(b:, 'splfy_keephls', 0)
        \ || get(g:, 'splfy_keephls', 0)
    call <Sid>Dbg("StopHL OUT:")
    return
  else
    " xfer execution out of func, so that nohls be not reset
    call <Sid>Dbg("  StopHL nohls:")
    silent! call feedkeys("\<Plug>(spotlightify)nohls", 'mi')
  endif
  call <Sid>Dbg("StopHL OUT:")
endfun

" s:ChangedHLSearch() {{{2
function! s:ChangedHLSearch(old, new)
  call <Sid>Dbg("ChangedHLSearch IN:")
  if a:old == 0 && a:new == 1
    " set hls
    call <Sid>Dbg("  ChangedHLSearch: set hls")
    noremap  <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999) . ""
    noremap! <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999)

    autocmd Spotlightify CursorMoved * call <SID>CheckHL()
    autocmd Spotlightify InsertEnter * call <SID>StopHL()
  elseif a:old == 1 && a:new == 0
    " unset hls
    call <Sid>Dbg("  ChangedHLSearch: unset hls")

    call <SID>ClearMatches()

    unmap  <Plug>(spotlightify)nohls
    unmap! <Plug>(spotlightify)nohls

    autocmd! Spotlightify CursorMoved
    autocmd! Spotlightify InsertEnter
  else
    call <Sid>Dbg("  ChangedHLSearch: nop")
    return
  endif
  call <Sid>Dbg("ChangedHLSearch OUT:")
endfun

" s:SplfyGn {{{2
function! SplfyGn(dir)
  call <Sid>Dbg("SplfyGn IN:")
  let b:splfy_ctab_pat = @/
  let b:splfy_keephls = 1
  silent! set hls
  " call <SID>CheckHL()
  silent! exe 'norm!' (a:dir==-1 ? 'gN' : 'gn')
  call <Sid>Dbg("SplfyGn OUT:")
endfun

" s:Dbg {{{2
function! s:Dbg(msg, ...)
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
      \ :let b:splfy_keephls=1<cr>*g``c:
      \let v:hlsearch=1<Bar>call SplfyGn(1)<cr>

      " \let b:splfy_keephls=1<Bar>set hls<Bar>norm! gn<cr>

nnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :let b:splfy_keephls=1<cr>*g``c:
      \let v:hlsearch=1<Bar>call SplfyGn(-1)<cr>
      " \let b:splfy_keephls=1<Bar>set hls<Bar>norm! gN<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacefwd
      \ :<C-u>let @/=strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \<cr>c:let v:hlsearch=1<Bar>call SplfyGn(1)<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :<C-u>let @/=strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \<cr>c:let v:hlsearch=1<Bar>call SplfyGn(-1)<cr>


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


"----------------
" HL groups {{{1
"----------------

hi SplfyTransparentCursorLine
      \                           term=NONE 
      \ ctermfg=NONE ctermbg=NONE cterm=NONE 
      \ guifg=NONE   guibg=NONE   gui=NONE


"-----------
" Init {{{1
"-----------

augroup Spotlightify
  au!
  autocmd OptionSet hlsearch
        \ call <SID>ChangedHLSearch(v:option_old, v:option_new)
augroup END

call <SID>ChangedHLSearch(0, &hlsearch)

let &cpo = s:save_cpo

" vim: et sw=2:
