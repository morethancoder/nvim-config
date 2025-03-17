-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Check if Packer is installed, and if not, install it
local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.api.nvim_command('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
end

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

require("packer").init({
    max_jobs = nil,
})

return require('packer').startup(function(use)
    -- Packer can manage itself
    use { 'wbthomason/packer.nvim' }
    use('nvim-treesitter/nvim-treesitter', { run = ':TSUpdate' })
    use('mbbill/undotree')
    use('theprimeagen/harpoon')
    use('tpope/vim-fugitive')
    use { 'nvim-lualine/lualine.nvim' }
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' },             -- Required
            { 'williamboman/mason.nvim' },           -- Optional
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },     -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
            { 'L3MON4D3/LuaSnip' },     -- Required
        }
    }
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.2',
        -- or                            , branch = '0.1.x',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    use 'eddyekofo94/gruvbox-flat.nvim' -- Or with configuration
    use { 'ellisonleao/gruvbox.nvim' }

    use({
        'dracula/vim',
        as = 'dracula',
    })

    use { 'windwp/nvim-ts-autotag' }
    use({ 'projekt0n/github-nvim-theme' })
    use({
        "catppuccin/nvim",
        as = "catppuccin",
        -- config = function()
        --     vim.cmd('colorscheme catppuccin')
        -- end
    })
    use { 'mattn/emmet-vim' }
    use { 'terrortylor/nvim-comment' }
    use { 'mhartington/formatter.nvim' }
    use "EdenEast/nightfox.nvim"
    use "folke/tokyonight.nvim"
    use({ 'rose-pine/neovim', as = 'rose-pine' })
    use {
        "loctvl842/monokai-pro.nvim",
        config = function()
            require("monokai-pro").setup()
        end
    }
    -- use({ "iamcco/markdown-preview.nvim", run = "cd app && bun install", setup = function() vim.g.mkdp_filetypes = {
    --         "markdown" } end, ft = { "markdown" }, })
    use {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup {}
        end
    }
    use "rebelot/kanagawa.nvim"
    use 'lervag/vimtex'
    -- Remove the `use` here if you're using folke/lazy.nvim.
    use {
        'Exafunction/codeium.vim',
        config = function()
            -- Change '<C-g>' here to any keycode you like.
            vim.keymap.set('i', '<C-g>', function() return vim.fn['codeium#Accept']() end, { expr = true, silent = true })
            vim.keymap.set('i', '<c-;>', function() return vim.fn['codeium#CycleCompletions'](1) end,
                { expr = true, silent = true })
            vim.keymap.set('i', '<c-,>', function() return vim.fn['codeium#CycleCompletions'](-1) end,
                { expr = true, silent = true })
            vim.keymap.set('i', '<c-x>', function() return vim.fn['codeium#Clear']() end, { expr = true, silent = true })
        end
    }
end)
