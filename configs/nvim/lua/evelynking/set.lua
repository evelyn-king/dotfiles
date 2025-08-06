-- Set.lua for Evelyn King

-- Set the leader at the start
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

-- set linenumbers
vim.opt.number = true
-- Use relative line numbers
vim.opt.relativenumber = true

-- Enable mouse mode, for emergencies
vim.opt.mouse = "a"

-- Don't show the mode
vim.opt.showmode = false
vim.opt.guicursor = ""

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- Case-insensitive searching unless \C or one or more capital letters are in
-- the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep the signcolumn on
vim.opt.signcolumn = "yes"

-- Decrease update time
vim.opt.updatetime = 50

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 200

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Set how whitespace is displayed
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of lines to keep above and below cursor
vim.opt.scrolloff = 10

-- if performing an operation that could fail, get confirmation
vim.opt.confirm = true

-- Expand tabs to spaces
vim.opt.expandtab = true

-- terminalguicolors
vim.opt.termguicolors = true

