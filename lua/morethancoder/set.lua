-- Enable clipboard support using xclip
vim.cmd('set clipboard=unnamedplus')

vim.opt.guicursor = ""
vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

-- text wrap options
-- vim.opt.wrap = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

-- vim.opt.colorcolumn = "115"

vim.g.mapleader = ' '
vim.g.codeium_enabled = false

-- clear the LSP log on startup once it grows past 10MB
local lsp_log = vim.fn.stdpath("state") .. "/lsp.log"
local lsp_log_stat = vim.uv.fs_stat(lsp_log)
if lsp_log_stat and lsp_log_stat.size > 10 * 1024 * 1024 then
    local f = io.open(lsp_log, "w")
    if f then f:close() end
end

vim.cmd("set termbidi")

