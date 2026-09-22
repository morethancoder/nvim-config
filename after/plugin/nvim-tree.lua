-- ~/.config/nvim/after/plugin/nvim-tree.lua

local ok, nvim_tree = pcall(require, 'nvim-tree')
if not ok then return end

nvim_tree.setup {
    -- keep netrw so <leader><leader> (:Ex) still works
    hijack_netrw = false,
    view = {
        width = 32,
    },
    renderer = {
        group_empty = true,
    },
    -- highlight the current file in the tree when switching buffers
    update_focused_file = {
        enable = true,
    },
}

-- Keymaps
vim.keymap.set('n', '<leader>t', vim.cmd.NvimTreeToggle, { desc = "Toggle file tree" })
vim.keymap.set('n', '<leader>T', vim.cmd.NvimTreeFindFile, { desc = "Reveal current file in tree" })
