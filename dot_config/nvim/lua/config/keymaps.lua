-- LazyVim loads local keymaps from this file on the VeryLazy event.
--
-- Almost everything is LazyVim's default set. ~/.vim/plugin/keymaps.vim
-- mirrors that set for Vim; docs/keybindings.md is the parity table. Anything
-- added here has to be added there too, or the two drift.

-- The one binding that came from the Vim side.
vim.keymap.set("i", "jk", "<Esc>", { desc = "Escape" })
