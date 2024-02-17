local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "shaunsingh/nord.nvim", priority=1000 },
  {
    "nvim-telescope/telescope.nvim", tag = "0.1.5",
    dependencies = { "nvim-lua/plenary.nvim" }
  },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  "theprimeagen/harpoon",
  "mbbill/undotree",
  "tpope/vim-fugitive",
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v2.x",
    dependencies = {
      -- LSP Support
      {"neovim/nvim-lspconfig"},  -- Required
      {                           -- Optional
        "williamboman/mason.nvim",      
        build = function()
          pcall(vim.cmd, "MasonUpdate")
        end,
      },
      {"williamboman/mason-lspconfig.nvim"},

      -- Autocompletion
      {"hrsh7th/nvim-cmp"},       -- Required
      {"hrsh7th/cmp-nvim-lsp"},   -- Required
      {"L3MON4D3/LuaSnip"},       -- Required
    }
  }
})

