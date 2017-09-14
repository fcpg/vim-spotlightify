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


"----------------
" Functions {{{1
"----------------

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

" s:CheckHL() {{{2
function! s:CheckHL()
  if !v:hlsearch
    let b:splfy_keephls = 0
  endif
  silent! if v:hlsearch
        \ || (has_key(b:, 'splfy_matches')
        \     && !empty(b:splfy_matches))
    if has_key(b:, 'splfy_ctab_pat')
          \ && b:splfy_ctab_pat !=# @/
      " new search
      let b:splfy_keephls = 0
    endif
    if @/ ==# '' || !search('\%#\zs'.@/,'cnW')
      " moved from a match, stop hls
      if exists('b:splfy_cul_hlgroup')
        call <Sid>RestoreHLGroup('CursorLine', b:splfy_cul_hlgroup)
        unlet b:splfy_cul_hlgroup
        set nocursorline
      endif
      call <SID>StopHL()
    else
      if get(g:, 'splfy_curmatch', 1)
        " on a match, special hili for current one
        if !&cursorline
          " cursorline helps redrawing lines
          let b:splfy_cul_hlgroup = <Sid>SaveHLGroup('CursorLine')
          silent! hi! link CursorLine SplfyTransparentCursorLine
          silent! set cursorline
        endif
        let target_pat = '\c\%#\%('.@/.'\)'
        if !exists('b:splfy_matches')
          let b:splfy_matches = {}
        endif
        if !has_key(b:splfy_matches, @/)
          let matchid = matchadd(
                \ get(g:, 'splfy_curmatch_hlgroup', 'IncSearch'),
                \ target_pat,
                \ 101)
          let b:splfy_matches[@/] = matchid
        endif
        " redraw
      endif
    endif
  endif
endfun

" s:StopHL() {{{2
function! s:StopHL()
  call <SID>ClearMatches()
  if !v:hlsearch || mode() isnot 'n'
        \ || get(b:, 'splfy_keephls', 0)
        \ || get(g:, 'splfy_keephls', 0)
    return
  else
    " xfer execution out of func, so that nohls be not reset
    silent! call feedkeys("\<Plug>(spotlightify)nohls", 'mi')
  endif
endfun

" s:ChangedHLSearch() {{{2
function! s:ChangedHLSearch(old, new)
  if a:old == 0 && a:new == 1
    " set hls
    noremap  <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999) . ""
    noremap! <expr> <Plug>(spotlightify)nohls
          \ strpart(execute('nohlsearch'), 999)

    autocmd Spotlightify CursorMoved * call <SID>CheckHL()
    autocmd Spotlightify InsertEnter * call <SID>StopHL()
  elseif a:old == 1 && a:new == 0
    " unset hls
    call <SID>ClearMatches()

    unmap  <Plug>(spotlightify)nohls
    unmap! <Plug>(spotlightify)nohls

    autocmd! Spotlightify CursorMoved
    autocmd! Spotlightify InsertEnter
  else
    return
  endif
endfun

" s:SplfyGn {{{2
function! SplfyGn(dir)
  let b:splfy_keephls=1
  silent! set hls
  silent! exe 'norm!' (a:dir==-1 ? 'gN' : 'gn')
endfun


"-----------
" Maps {{{1
"-----------

" Plugs {{{2
nnoremap <silent> <Plug>(spotlightify)searchreplacefwd
      \ :let b:splfy_keephls=1<cr>*g``:let b:splfy_ctab_pat=@/<cr>c:
      \call SplfyGn(1)<cr>

      " \let b:splfy_keephls=1<Bar>set hls<Bar>norm! gn<cr>

nnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :let b:splfy_keephls=1<cr>*g``:let b:splfy_ctab_pat=@/<cr>c:
      \call SplfyGn(-1)<cr>
      " \let b:splfy_keephls=1<Bar>set hls<Bar>norm! gN<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacefwd
      \ :<C-u>let @/=strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \<cr>c:call SplfyGn(1)<cr>

xnoremap <silent> <Plug>(spotlightify)searchreplacebak
      \ :<C-u>let @/=strpart(getline('.'),
      \  col("'<")-1, (line('.')==line("'>")?col("'>"):col("$")) - col("'<")+1)
      \<cr>c:call SplfyGn(-1)<cr>


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
