" keymaps.vim - the Vim half of a keymap shared with Neovim.
"
" Neovim is the reference. These mirror LazyVim's defaults so that muscle
" memory carries between the two editors; the parity table, and the list of
" keys deliberately left unmapped here, are in docs/keybindings.md.
"
" Vim sources this before the pack plugins, so the leader and
" g:NERDCreateDefaultMappings live in ~/.vimrc instead. Mappings onto plugin
" <Plug> targets use nmap/xmap so they resolve at use time, not load time.

if exists('g:loaded_evelyn_keymaps')
  finish
endif
let g:loaded_evelyn_keymaps = 1

" Alt is the one family of keys terminal Vim does not decode on its own: it
" arrives as <Esc> followed by the key. Neovim needs none of this.
if !has('gui_running')
  execute "set <M-j>=\ej"
  execute "set <M-k>=\ek"
endif

" --- Insert escape ------------------------------------------------------
" The one binding that travelled the other way; Neovim copies it.
inoremap jk <Esc>

" --- Better up/down: display lines unless a count is given ---------------
nnoremap <silent><expr> j v:count == 0 ? 'gj' : 'j'
xnoremap <silent><expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <silent><expr> k v:count == 0 ? 'gk' : 'k'
xnoremap <silent><expr> k v:count == 0 ? 'gk' : 'k'
nnoremap <silent><expr> <Down> v:count == 0 ? 'gj' : 'j'
xnoremap <silent><expr> <Down> v:count == 0 ? 'gj' : 'j'
nnoremap <silent><expr> <Up> v:count == 0 ? 'gk' : 'k'
xnoremap <silent><expr> <Up> v:count == 0 ? 'gk' : 'k'

" --- Windows ------------------------------------------------------------
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap <silent> <C-Up> :resize +2<CR>
nnoremap <silent> <C-Down> :resize -2<CR>
nnoremap <silent> <C-Left> :vertical resize -2<CR>
nnoremap <silent> <C-Right> :vertical resize +2<CR>

" which-key makes <leader>w a proxy for <C-w> in Neovim; this is that proxy.
nnoremap <leader>w <C-w>
nnoremap <leader>wd <C-w>c
nnoremap <leader>- <C-w>s
nnoremap <leader><Bar> <C-w>v
nnoremap <silent> <leader>wm :call <SID>ToggleZoom()<CR>
nnoremap <silent> <leader>uZ :call <SID>ToggleZoom()<CR>

" --- Move lines ---------------------------------------------------------
nnoremap <silent> <M-j> :<C-u>execute 'move .+' . v:count1<CR>==
nnoremap <silent> <M-k> :<C-u>execute 'move .-' . (v:count1 + 1)<CR>==
inoremap <silent> <M-j> <Esc>:move .+1<CR>==gi
inoremap <silent> <M-k> <Esc>:move .-2<CR>==gi
xnoremap <silent> <M-j> :<C-u>execute "'<,'>move '>+" . v:count1<CR>gv=gv
xnoremap <silent> <M-k> :<C-u>execute "'<,'>move '<-" . (v:count1 + 1)<CR>gv=gv

" --- Buffers ------------------------------------------------------------
nnoremap <silent> <S-h> :bprevious<CR>
nnoremap <silent> <S-l> :bnext<CR>
nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> <leader>bb :edit #<CR>
nnoremap <silent> <leader>` :edit #<CR>
nnoremap <silent> <leader>bd :call <SID>BufDelete()<CR>
nnoremap <silent> <leader>bD :bdelete<CR>
nnoremap <silent> <leader>bo :call <SID>BufDeleteOthers()<CR>

" --- Search -------------------------------------------------------------
nnoremap <silent> <Esc> :nohlsearch<CR>
nnoremap <silent> <leader>ur :nohlsearch<Bar>diffupdate<Bar>normal! <C-l><CR>

" n and N always move in the same on-screen direction.
nnoremap <expr> n 'Nn'[v:searchforward] . 'zv'
xnoremap <expr> n 'Nn'[v:searchforward]
onoremap <expr> n 'Nn'[v:searchforward]
nnoremap <expr> N 'nN'[v:searchforward] . 'zv'
xnoremap <expr> N 'nN'[v:searchforward]
onoremap <expr> N 'nN'[v:searchforward]

" --- Editing ------------------------------------------------------------
" Undo break-points, so one undo does not swallow a whole sentence.
inoremap , ,<C-g>u
inoremap . .<C-g>u
inoremap ; ;<C-g>u

nnoremap <silent> <C-s> :write<CR>
inoremap <silent> <C-s> <Esc>:write<CR>
xnoremap <silent> <C-s> <Esc>:write<CR>

xnoremap < <gv
xnoremap > >gv

nnoremap <silent> <leader>K :normal! K<CR>
nnoremap <silent> <leader>fn :enew<CR>

" --- Quickfix and location list -----------------------------------------
nnoremap <silent> <leader>xq :call <SID>ToggleQuickfix()<CR>
nnoremap <silent> <leader>xl :call <SID>ToggleLocList()<CR>
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]q :cnext<CR>

" --- Tabs ---------------------------------------------------------------
nnoremap <silent> <leader><Tab><Tab> :tabnew<CR>
nnoremap <silent> <leader><Tab>d :tabclose<CR>
nnoremap <silent> <leader><Tab>f :tabfirst<CR>
nnoremap <silent> <leader><Tab>l :tablast<CR>
nnoremap <silent> <leader><Tab>o :tabonly<CR>
nnoremap <silent> <leader><Tab>] :tabnext<CR>
nnoremap <silent> <leader><Tab>[ :tabprevious<CR>

" --- UI toggles ---------------------------------------------------------
nnoremap <silent> <leader>us :setlocal invspell<CR>
nnoremap <silent> <leader>uw :setlocal invwrap<CR>
nnoremap <silent> <leader>ul :setlocal invnumber<CR>
nnoremap <silent> <leader>uL :setlocal invrelativenumber<CR>
nnoremap <silent> <leader>uc :call <SID>ToggleConceal()<CR>
nnoremap <silent> <leader>ub :call <SID>ToggleBackground()<CR>

" --- Quit ---------------------------------------------------------------
nnoremap <silent> <leader>qq :qall<CR>

" --- Commenting (nerdcommenter) -----------------------------------------
" Neovim's built-in gc is an operator; nerdcommenter has no operator-pending
" support, so gcc and visual gc carry over and bare gc{motion} does not.
nmap gcc <Plug>NERDCommenterToggle
xmap gc <Plug>NERDCommenterToggle
nmap gbc <Plug>NERDCommenterMinimal
xmap gb <Plug>NERDCommenterMinimal
nnoremap <silent> gco o<Esc>Vcx<Esc>:normal gcc<CR>fxa<BS>
nnoremap <silent> gcO O<Esc>Vcx<Esc>:normal gcc<CR>fxa<BS>

" --- Surround (vim-surround on mini.surround's keys) --------------------
nmap gsa <Plug>Ysurround
xmap gsa <Plug>VSurround
nmap gsd <Plug>Dsurround
nmap gsr <Plug>Csurround

" --- Explorer (nerdtree) ------------------------------------------------
" NERDTreeToggleVCS opens at the repository root, matching Neovim's root-dir
" explorer; NERDTreeToggle opens at the cwd.
nnoremap <silent> <leader>e :NERDTreeToggleVCS<CR>
nnoremap <silent> <leader>E :NERDTreeToggle<CR>
nnoremap <silent> <leader>fe :NERDTreeToggleVCS<CR>
nnoremap <silent> <leader>fE :NERDTreeToggle<CR>

" --- Git (fugitive, gitui) ----------------------------------------------
nnoremap <silent> <leader>gb :Git blame<CR>
nnoremap <silent> <leader>gL :Git log<CR>
nnoremap <silent> <leader>gg :call <SID>Gitui()<CR>
nnoremap <silent> <leader>gG :call <SID>Gitui()<CR>

" --- Terminal -----------------------------------------------------------
nnoremap <silent> <leader>ft :terminal<CR>
nnoremap <silent> <leader>fT :terminal<CR>

" --- Picker fallbacks ---------------------------------------------------
" No fuzzy finder in Vim. These leave the command line open on the nearest
" built-in equivalent rather than leaving the keys dead.
nnoremap <leader><Space> :find<Space>
nnoremap <leader>ff :find<Space>
nnoremap <leader>fF :find<Space>
nnoremap <leader>, :buffer<Space>
nnoremap <silent> <leader>fr :browse oldfiles<CR>
nnoremap <leader>/ :grep!<Space>
nnoremap <leader>sg :grep!<Space>
nnoremap <leader>sG :grep!<Space>
nnoremap <leader>sw :grep! <C-r><C-w><CR>
xnoremap <leader>sw y:grep! <C-r>"<CR>

" --- Functions ----------------------------------------------------------

" Delete the buffer but keep the window, the way Snacks.bufdelete does in
" Neovim. Plain :bdelete closes the window too; that is <leader>bD.
function! s:BufDelete() abort
  let l:target = bufnr('%')
  let l:here = winnr()
  for l:win in range(1, winnr('$'))
    if winbufnr(l:win) != l:target
      continue
    endif
    execute l:win . 'wincmd w'
    let l:alt = bufnr('#')
    if l:alt > 0 && l:alt != l:target && buflisted(l:alt)
      buffer #
    else
      bnext
    endif
    if bufnr('%') == l:target
      enew
    endif
  endfor
  execute l:here . 'wincmd w'
  if buflisted(l:target)
    execute 'bdelete' l:target
  endif
endfunction

function! s:BufDeleteOthers() abort
  let l:keep = bufnr('%')
  for l:buf in range(1, bufnr('$'))
    if buflisted(l:buf) && l:buf != l:keep && !getbufvar(l:buf, '&modified')
      execute 'bdelete' l:buf
    endif
  endfor
endfunction

function! s:ToggleQuickfix() abort
  if getqflist({'winid': 0}).winid != 0
    cclose
  else
    copen
  endif
endfunction

function! s:ToggleLocList() abort
  if getloclist(0, {'winid': 0}).winid != 0
    lclose
  else
    try
      lopen
    catch /E776/
      echohl ErrorMsg | echomsg 'No location list' | echohl None
    endtry
  endif
endfunction

function! s:ToggleZoom() abort
  if exists('t:evelyn_zoom_restore')
    execute t:evelyn_zoom_restore
    unlet t:evelyn_zoom_restore
  elseif winnr('$') > 1
    let t:evelyn_zoom_restore = winrestcmd()
    wincmd _
    wincmd |
  endif
endfunction

function! s:ToggleConceal() abort
  let &l:conceallevel = &l:conceallevel > 0 ? 0 : 2
endfunction

function! s:ToggleBackground() abort
  let &background = &background ==# 'dark' ? 'light' : 'dark'
endfunction

function! s:Gitui() abort
  if !executable('gitui')
    echohl ErrorMsg | echomsg 'gitui is not installed' | echohl None
    return
  endif
  if has('terminal')
    tab terminal ++close gitui
  else
    silent !gitui
    redraw!
  endif
endfunction
