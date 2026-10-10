-- Follow the current Omarchy theme: `theme set` on Windows (see
-- docs/windows-themes.md) or `omarchy theme set` renders its lazy.nvim spec
-- here. Gruvbox until a theme has been set.
local current = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
if (vim.uv or vim.loop).fs_stat(current) then
  return dofile(current)
end

return {
  { "ellisonleao/gruvbox.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
