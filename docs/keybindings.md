# Editor keybindings

Neovim and Vim share one keymap as far as plain Vim reaches.

Neovim is the reference. It runs LazyVim, so its bindings are LazyVim's
defaults, and `dot_config/nvim/lua/config/keymaps.lua` adds exactly one thing.
Vim mirrors that set from `dot_vim/plugin/keymaps.vim`. Leader is `<Space>` and
localleader is `\` in both.

Two consequences worth stating plainly:

- Changing a keymap means changing it in both files. There is no shared source
  to generate one from; Vimscript and Lua are too far apart for that to pay off.
- Upgrading LazyVim can move a default out from under the Vim half. When a key
  starts behaving differently between the two, LazyVim's
  `lua/lazyvim/config/keymaps.lua` is the thing that moved.

## Where the leader and the plugin flags live

`dot_vim/plugin/keymaps.vim` is sourced after `~/.vimrc` but *before* the pack
plugins in `~/.vim/pack/plugins/start/`. So `mapleader` and
`g:NERDCreateDefaultMappings` are set in `.vimrc`, where the plugins will read
them, and only mappings live in `keymaps.vim`. Mappings onto plugin `<Plug>`
targets use `nmap`/`xmap` rather than `nnoremap`, so they resolve when pressed
rather than when the file loads.

## Shared

Identical behaviour in both editors, no plugin involved.

| Key | Action |
| --- | --- |
| `j` `k` `<Down>` `<Up>` | Move by display line unless a count is given |
| `<C-h/j/k/l>` | Go to the window left/below/above/right |
| `<C-Up/Down/Left/Right>` | Resize the window |
| `<M-j>` `<M-k>` | Move the line or selection down/up (normal, insert, visual) |
| `H` `L`, `[b` `]b` | Previous / next buffer |
| ``<leader>bb``, ``<leader>` `` | Switch to the alternate buffer |
| `<leader>bd` | Delete the buffer, keep the window |
| `<leader>bD` | Delete the buffer and its window |
| `<leader>bo` | Delete the other buffers |
| `<Esc>` | Clear the search highlight |
| `<leader>ur` | Clear highlight, update diffs, redraw |
| `n` `N` | Next / previous match, always in the same on-screen direction |
| `,` `.` `;` | Insert an undo break-point (insert mode) |
| `<C-s>` | Write the file |
| `<` `>` | Indent and keep the visual selection |
| `<leader>K` | Keywordprg on the word under the cursor |
| `<leader>fn` | New file |
| `<leader>xq` `<leader>xl` | Toggle the quickfix / location list |
| `[q` `]q` | Previous / next quickfix entry |
| `<leader>w` | Prefix for `<C-w>`; `<leader>wd` closes, `<leader>wm` zooms |
| `<leader>-` `<leader>\|` | Split below / right |
| `<leader><Tab>` + `<Tab> d f l o ] [` | Tabs: new, close, first, last, only, next, previous |
| `<leader>u` + `s w l L c b` | Toggle spell, wrap, number, relativenumber, conceal, background |
| `<leader>qq` | Quit all |
| `jk` | Escape from insert mode |

`jk` is the one binding that went the other way: it was in `.vimrc` first, and
Neovim now copies it. LazyVim does not claim `jk`, so nothing collides.

## Same key, equivalent plugin

The key matches; the implementation differs, and so does the fine detail.

| Key | Neovim | Vim | Difference |
| --- | --- | --- | --- |
| `gcc`, visual `gc` | Built-in commenting | nerdcommenter | — |
| `gbc`, visual `gb` | Built-in block comment | `NERDCommenterMinimal` | — |
| `gco` `gcO` | Comment line below / above | Same trick, ported | — |
| `gc{motion}` | Built-in operator | *unmapped* | nerdcommenter has no operator-pending support |
| `gsa` `gsd` `gsr` | mini.surround | vim-surround `<Plug>` targets | Vim also keeps its native `ys`/`ds`/`cs`, which Neovim has no equivalent for |
| `<leader>e` `<leader>fe` | Explorer at the root dir | `:NERDTreeToggleVCS` | — |
| `<leader>E` `<leader>fE` | Explorer at the cwd | `:NERDTreeToggle` | — |
| `<leader>gg` `<leader>gG` | gitui in a Snacks terminal | gitui in a terminal tab | LazyVim's `util.gitui` extra puts gitui here, not lazygit |
| `<leader>gb` | Snacks git log for the line | `:Git blame` (fugitive) | Whole-file blame, not one line |
| `<leader>gL` | Snacks git log | `:Git log` (fugitive) | — |
| `<leader>ft` `<leader>fT` | Floating terminal | `:terminal` in a split | Vim has no root-dir/cwd distinction here |

## Fallbacks

Vim has no fuzzy finder. Rather than leave the picker keys dead, they open the
command line on the nearest built-in, backed by `path+=**` and `grepprg=rg` in
`.vimrc`. Wildmenu completion, not fuzzy matching — the key lands somewhere
useful, but it does not feel the same.

| Key | Neovim | Vim |
| --- | --- | --- |
| `<leader><Space>` `<leader>ff` `<leader>fF` | Find files | `:find ` |
| `<leader>,` | Buffer picker | `:buffer ` |
| `<leader>fr` | Recent files | `:browse oldfiles` |
| `<leader>/` `<leader>sg` `<leader>sG` | Grep | `:grep! ` |
| `<leader>sw` | Grep the word or selection | `:grep!` on `<cword>` or the selection |

A `QuickFixCmdPost` autocommand in `.vimrc` opens the quickfix window after a
grep, so these behave like one command rather than two.

## Not ported

Deliberately unmapped in Vim. Every one of these needs something Vim does not
have, and a key that behaves differently is worse than a key that does nothing.

- **LSP**: `gd`, `gr`, `gI`, `gy`, `<leader>ca`, `<leader>cr`, `<leader>cd`,
  `]d` `[d`, `]e` `[e`, `]w` `[w`
- **Formatting**: `<leader>cf`, `<leader>uf`, `<leader>uF`
- **Pickers beyond the fallbacks above**: `<leader>sb`, `<leader>ss`, and the
  rest of `<leader>s*`
- **flash.nvim**: `s`, `S`, `r`, `R`
- **harpoon**: `<leader>H`, `<leader>h`, `<leader>1`–`<leader>5`
- **Snacks-specific toggles**: `<leader>ud`, `<leader>uh`, `<leader>uT`,
  `<leader>ug`, `<leader>uS`, `<leader>ua`, `<leader>uD`, `<leader>uz`
- **LazyVim itself**: `<leader>l`, `<leader>L`, `<leader>dp*`

## Terminal caveats

- **Alt keys.** Terminal Vim does not decode Alt on its own; it arrives as
  `<Esc>` then the key. `keymaps.vim` declares `<M-j>` and `<M-k>` as terminal
  key codes to fix that, and `.vimrc` sets `ttimeoutlen=10` so the `<Esc>`
  mapping stays responsive alongside them. Neovim needs none of this.
- **`<C-s>`.** Terminal flow control eats it unless the shell has run
  `stty -ixon`.
