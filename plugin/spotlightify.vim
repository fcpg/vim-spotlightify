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
  let hlsave = split(execute('hi '.a:hlgroup, "silent!"), '\n')[0]
  if match(hlsave, "links to") != -1
    let hlsave = substitute(hlsave, '^.*links to ', 'link '.a:hlgroup.' ', '')
  else
    let hlsave = substitute(hlsave, '^\W*\(\w\+\)\s\+xxx', '\1', '')
  endif
  return hlsave
endfun

" s:RestoreHLGroup {{{2
function! s:RestoreHLGroup(save) abort
  silent! exe 'hi!' a:save
endfun

" s:SetSplfyCursorLine {{{2
" Args: optional non-zero to bypass setting option
function! s:SetSplfyCursorLine(...) abort
  "call <Sid>Dbg("SetSplfyCursorLine IN:")
  if !&l:cursorline
    "call <Sid>Dbg("  SetSplfyCursorLine setting custom cul hlgroup:")
    let g:splfy_cul_hlgroup = <Sid>SaveHLGroup('CursorLine')
    hi! link CursorLine SplfyTransparentCursorLine
    if !a:0 || !a:1
      "call <Sid>Dbg("  SetSplfyCursorLine setting cul", bufname(''))
      noauto setl cursorline
      let b:splfy_cul = 1
    endif
  endif
  "call <Sid>Dbg("SetSplfyCursorLine OUT:")
endfun

" s:SetSplfyCursorColumn {{{2
" Args: optional non-zero to bypass setting option
function! s:SetSplfyCursorColumn(...) abort
  "call <Sid>Dbg("SetSplfyCursorColumn IN:")
  if !&l:cursorcolumn
    "call <Sid>Dbg("  SetSplfyCursorColumn setting custom cuc hlgroup:")
    let g:splfy_cuc_hlgroup = <Sid>SaveHLGroup('CursorColumn')
    hi! link CursorColumn SplfyTransparentCursorColumn
    if !a:0 || !a:1
      "call <Sid>Dbg("  SetSplfyCursorColumn setting cuc", bufname(''))
      noauto setl cursorcolumn
      let b:splfy_cuc = 1
    endif
  endif
  "call <Sid>Dbg("SetSplfyCursorColumn OUT:")
endfun

" s:SetSplfyCursorLineCol {{{2
function! s:SetSplfyCursorLineCol() abort
  call <Sid>SetSplfyCursorLine()
  call <Sid>SetSplfyCursorColumn()
endfun

" s:RestoreCursorLine {{{2
" Args: optional non-zero to bypass unsetting option
function! s:RestoreCursorLine(...) abort
  "call <Sid>Dbg("RestoreCursorLine IN:")
  if exists('g:splfy_cul_hlgroup')
    "call <Sid>Dbg("  RestoreCursorLine IN: restoring cul hl")
    call <Sid>RestoreHLGroup(g:splfy_cul_hlgroup)
    unlet g:splfy_cul_hlgroup
  endif
  if exists('b:splfy_cul')
    if !a:0 || !a:1
      "call <Sid>Dbg("  RestoreCursorLine IN: restoring cul", bufname(''))
      noauto setl nocursorline
      unlet b:splfy_cul
    endif
  endif
  "call <Sid>Dbg("RestoreCursorLine OUT:")
endfun

" s:RestoreCursorColumn {{{2
" Args: optional non-zero to bypass unsetting option
function! s:RestoreCursorColumn(...) abort
  "call <Sid>Dbg("RestoreCursorColumn IN:")
  if exists('g:splfy_cuc_hlgroup')
    "call <Sid>Dbg("  RestoreCursorColumn IN: restoring cuc hl")
    call <Sid>RestoreHLGroup(g:splfy_cuc_hlgroup)
    unlet g:splfy_cuc_hlgroup
  endif
  if exists('b:splfy_cuc')
    if !a:0 || !a:1
      "call <Sid>Dbg("  RestoreCursorColumn IN: restoring cuc", bufname(''))
      noauto setl nocursorcolumn
      unlet b:splfy_cuc
    endif
  endif
  "call <Sid>Dbg("RestoreCursorColumn OUT:")
endfun

" s:RestoreCursorLineCol {{{2
function! s:RestoreCursorLineCol() abort
  "call <Sid>Dbg("RestoreCursorLineCol IN:", bufname(''))
  call <Sid>RestoreCursorLine()
  call <Sid>RestoreCursorColumn()
  "call <Sid>Dbg("  RestoreCursorLineCol:", &l:cursorline, &l:cursorcolumn,
        \ &cursorline, &cursorcolumn)
  "call <Sid>Dbg("RestoreCursorLineCol OUT:", bufname(''))
endfun

" s:ClearMatches {{{2
function! s:ClearMatches() abort
  "call <Sid>Dbg("ClearMatches IN:", bufname(''))
  let m = getmatches()
  if has_key(b:, 'splfy_matches') && !empty(b:splfy_matches)
    " clear matches
    if empty(m)
      "call <Sid>Dbg("  ClearMatches: getmatches() empty")
      return
    else
      let mid = {}
      for d in m
        let mid[d['id']] = 1
      endfor
    endif
    for matchid in values(b:splfy_matches)
      if has_key(mid, matchid)
        "call <Sid>Dbg("  ClearMatches: deleting id:", matchid)
        call matchdelete(matchid)
      else
        "call <Sid>Dbg("  ClearMatches: matchid not found in getmatches():",
              \ matchid)
      endif
    endfor
    let b:splfy_matches = {}
  else
    "call <Sid>Dbg("  ClearMatches: splfy_matches null or empty")
  endif
  "call <Sid>Dbg("ClearMatches OUT:")
endfun

" s:ShowMatchInfo() {{{2
" Args: optional non-zero for ctab, 1/-1 for direction
function! s:ShowMatchInfo(...) abort
  if get(g:, 'splfy_no_matchinfo', 0)
    return
  endif
  let curpos = getcurpos()
  let ctab = a:0 ? a:1 : 0
  try
    let back = (ctab == -1)
          \ || (!v:searchforward && !get(g:, 'splfy_matchinfo_fwd_only', 1))
    let matchesleft = 0
    if back
      silent! 1,.s##\=execute('let matchesleft +=1')#gen
    else
      silent! .,$s##\=execute('let matchesleft +=1')#gen
    endif
    let totalmatches = 0
    silent! %s##\=execute('let totalmatches +=1')#gen
    if curpos[2] == 1 && !back
      let linepart    = ''
      let linematches = 0
    else
      let linepart = back
            \ ? strpart(getline('.'), curpos[2])
            \ : strpart(getline('.'), 0, curpos[2]-1)
      " count # of occurrences on the left/right, splitting and substracting one
      let linematches = len(split(
            \ linepart,
            \ (&ic&&(!&scs||match(@/,'\C\u')==-1)?'\c':'\C').@/, 1)) - 1
    endif
    " +1 for one-based index
    let linewise_matchnr = totalmatches - matchesleft + 1
    let matchnr = linewise_matchnr + linematches
    " dbg
    " let g:splfy_match = {'totm': totalmatches, 'mleft': matchesleft,
          \ 'lpart': linepart, 'lmatch': linematches, 'bak': back}
    redraw
    if ctab
      " adjust by one, since we just removed an occurrence
      let ctab_left = totalmatches - matchnr + (back? 0 : 1)
      let ctab_tot  = max([0, totalmatches - 1])
      echo printf("%d matches left (total: %d)",
            \ ctab_left,
            \ ctab_tot)
    else
      echo printf("match (%d/%d)", matchnr, totalmatches)
    endif
  finally
    call setpos('.', curpos)
  endtry
endfun

" s:IsCursorOnMatch() {{{2
function! s:IsCursorOnMatch(pat)
  let p = a:pat
  if !strlen(p)
    return 0
  endif
  if p[0] == '^'
    let p = '^\%#\zs'.p[1:]
  else
    let p = '\%#\zs'.p
  endif
  return search(p,'cnW')
endfun

" s:CheckHL() {{{2
" called on CursorMoved
function! s:CheckHL() abort
  "call <Sid>Dbg("CheckHL IN:",
        \ get(b:, 'splfy_keephls', ''),
        \ get(b:, 'splfy_ctab_pat', ''),
        \ v:hlsearch
        \)
  " unset E from cpo if it was set
  if exists('g:splfy_cpo_E')
    let &cpo = substitute(&cpo, '\CE', '', 'g')
    unlet g:splfy_cpo_E
  endif
  if !v:hlsearch
    " hls has been turned off (eg. with :noh)
    " keephls & ctab_pat aren't relevant anymore for now
    "call <Sid>Dbg("  CheckHL hls is off:")
    "call <Sid>Dbg("  CheckHL resetting keephls:", get(b:, 'splfy_keephls', ''))
    unlet! b:splfy_keephls
    "call <Sid>Dbg("  CheckHL resetting ctab_pat:", get(b:, 'splfy_ctab_pat', ''))
    unlet! b:splfy_ctab_pat
    " turn off whatever hl remains (cul, matches)
    call <Sid>StopHL()
  endif
  if has_key(b:, 'splfy_ctab_pat') && b:splfy_ctab_pat !=# @/
    " new search since last c<Tab>, reset things
    "call <Sid>Dbg("  CheckHL new search:")
    "call <Sid>Dbg("  CheckHL resetting keephls:", get(b:, 'splfy_keephls', ''))
    unlet! b:splfy_keephls
    "call <Sid>Dbg("  CheckHL resetting ctab_pat:", get(b:, 'splfy_ctab_pat', ''))
    unlet! b:splfy_ctab_pat
  endif
  " conditions to start checking hl:
  "   - hls is on
  "   - OR there's a matchadd defined
  " otherwise, nothing is done
  silent! if v:hlsearch
        \ || (has_key(b:, 'splfy_matches')
        \     && !empty(b:splfy_matches))
    if @/ ==# '' || !<Sid>IsCursorOnMatch(@/)
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
        call <Sid>SetSplfyCursorLineCol()
        let target_pat = (&ic&&(!&scs||match(@/,'\C\u')==-1)?'\c':'\C').
              \ (@/[0:1] is '\v' ? '\v%#%('.@/[2:].')' : '\%#\%('.@/.'\)')
        if !exists('b:splfy_matches')
          let b:splfy_matches = {}
        endif
        if !has_key(b:splfy_matches, @/)
          "call <Sid>Dbg("  CheckHL calling matchadd:", bufname(''))
          let matchid = matchadd(
                \ 'SplfyCurrentMatch',
                \ target_pat,
                \ 101)
          if matchid >= 0
            "call <Sid>Dbg("  CheckHL match added:", matchid, string(getmatches()))
            let b:splfy_matches[@/] = matchid
          else
            "call <Sid>Dbg("  CheckHL error in matchadd:")
          endif
        else
          "call <Sid>Dbg("  CheckHL already in b:splfy_matches:")
        endif
        call <Sid>ShowMatchInfo()
        " redraw
      endif
    endif
  else
    " no hl
    "call <Sid>Dbg("  CheckHL v:hls is off: no check, restoring cul/cuc if need be",
          \ get(b:, 'splfy_cul', ''),
          \ get(b:, 'splfy_cuc', ''),
          \ &l:cursorline,
          \ &l:cursorcolumn
          \ )
    " reset cul/cuc if modified by splfy
    if has_key(b:, 'splfy_cul') && &l:cursorline
      call <Sid>RestoreCursorLine()
    endif
    if has_key(b:, 'splfy_cuc') && &l:cursorcolumn
      call <Sid>RestoreCursorColumn()
    endif
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
  call <Sid>RestoreCursorLineCol()
  call <Sid>ClearMatches()
  " only call nohls if hls is on, in normal mode
  " or if arg == 1
  if !v:hlsearch || mode() isnot 'n'
        \ || get(b:, 'splfy_keephls', 0)
        \ || get(g:, 'splfy_keephls', 0)
    "call <Sid>Dbg("StopHL OUT:")
    return
  else
    " set nohls out of func, otherwise it's reset
    "call <Sid>Dbg("  StopHL: sending nohls via feedkeys()", bufname(''))
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

" s:ChangedCursorLineCol() {{{2
function! s:ChangedCursorLineCol(type, old, new) abort
  "call <Sid>Dbg("ChangedCursorLineCol IN:", a:type)
  if a:old == 0 && a:new == 1
    " set
    "call <Sid>Dbg("  ChangedCursorLineCol: nop (set)", a:type, a:old, a:new)
  elseif a:old == 1 && a:new == 0
    " unset
    "call <Sid>Dbg("  ChangedCursorLineCol: nop (unset)", a:type, a:old, a:new)
  elseif a:old == 1 && a:new == 1
    " option has been set while it was splfy-controlled
    "call <Sid>Dbg("  ChangedCursorLineCol: restoring (set twice)", a:type)
    if a:type == 'line'
      call <Sid>RestoreCursorLine(1)
    elseif a:type == 'col'
      call <Sid>RestoreCursorColumn(1)
    endif
  elseif a:old == 0 && a:new == 0
    "call <Sid>Dbg("  ChangedCursorLineCol: nop (unset twice)", a:type)
  else
    "call <Sid>Dbg("  ChangedCursorLineCol: nop", a:type)
    return
  endif
  "call <Sid>Dbg("ChangedCursorLineCol OUT:", a:type)
endfun

function! s:ChangedCursorLine(old, new) abort
  call <Sid>ChangedCursorLineCol('line', a:old, a:new)
endfunction

function! s:ChangedCursorColumn(old, new) abort
  call <Sid>ChangedCursorLineCol('col', a:old, a:new)
endfunction

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
  set hls
  silent! exe 'norm!' (a:dir==-1 ? 'gN' : 'gn')
  if mode() !=? 'v'
    " didn't move, abort
    echohl WarningMsg
    echo "No more matches"
    echohl NONE
  else
    call <Sid>ShowMatchInfo(a:dir)
  endif
  "call <Sid>Dbg("SplfyGn OUT:")
endfun

" SplfyPreGn {{{2
function! SplfyPreGn(dir, mode) abort
  let curpos_regex = '\%(\%#.\)\@<!'
  let b:splfy_keephls = 1
  if a:mode == 'n'
    let @/ = expand('<cword>').curpos_regex
  elseif a:mode == 'x'
    let @/ = strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \ . curpos_regex
  endif
  " check if cursor is at last char of pattern
  " necessary if replacement ends with original text
  if len(@/) == len(curpos_regex)+1
    " temporarily reset whichwrap to defaults to ensure wrapping
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

hi SplfyTransparentCursorColumn
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
  autocmd OptionSet cursorline
        \ call <Sid>ChangedCursorLine(v:option_old, v:option_new)
  autocmd OptionSet cursorcolumn
        \ call <Sid>ChangedCursorColumn(v:option_old, v:option_new)
  autocmd BufLeave,WinLeave,TabLeave *
        \ nohls|call <Sid>StopHL()
  " autocmd BufLeave *
  "       \ echom "leaving bufname:".bufname('')
  "       \|nohls|call <Sid>StopHL()
  " autocmd BufEnter *
  "       \ echom "entering bufname:".bufname('')
  "       \|echom '[' &l:cursorline &l:cursorcolumn &cursorline &cursorcolumn ']'
  "       \|echom '[' get(b:, 'splfy_cul', 'N') get(b:, 'splfy_cuc', 'N') ']'
augroup END

call <Sid>ChangedHLSearch(0, &hlsearch)

let &cpo = s:save_cpo

" vim: et sw=2:
