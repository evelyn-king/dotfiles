require("mason").setup()

local function get_python_path()
  local conda_env = os.getenv("CONDA_DEFAULT_ENV")
  if conda_env then
    return MAMBA_ROOT_PREFIX .. "/envs/" .. conda_env .. "/bin/python"
  else
    return "python"
  end
end

mason_lsp = require("mason-lspconfig")
mason_lsp.setup_handlers {
  function(server_name)
    if server_name == "pyright" then
      require("lspconfig").pyright.setup {
        cmd = { get_python_path(), "-m", "pyright-langserver", "--stdio" },
      }
    end
  end,
}
mason_lsp.setup()

local lsp = require("lsp-zero").preset()

lsp.on_attach(function(client, bufnr)
  lsp.default_keymaps({buffer = bufnr})
end)

-- (Optional) Configure lua language server for neovim
require("lspconfig").lua_ls.setup(lsp.nvim_lua_ls())

lsp.setup()

