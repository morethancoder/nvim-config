-- ~/.config/nvim/after/plugin/bufferline.lua

-- does nothing unless bufferline is enabled in lua/morethancoder/packer.lua
local ok, bufferline = pcall(require, 'bufferline')
if not ok then return end

-- termguicolors is already set in lua/morethancoder/set.lua
bufferline.setup {
    options = {
        diagnostics = "nvim_lsp",
        -- leave room above the file tree instead of drawing tabs over it
        offsets = {
            { filetype = "NvimTree", text = "Files", separator = true },
        },
    },
}

-- Keymaps
vim.keymap.set('n', '<S-l>', vim.cmd.BufferLineCycleNext, { desc = "Next buffer tab" })
vim.keymap.set('n', '<S-h>', vim.cmd.BufferLineCyclePrev, { desc = "Previous buffer tab" })
vim.keymap.set('n', '<leader>bd', vim.cmd.bdelete, { desc = "Close current buffer" })
