function ColorMyCode(color)
    color = color or 'github_dark_high_contrast'

    vim.cmd.colorscheme(color)
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    require('lualine').setup {
        options = {
            icons_enabled = true,
            theme = 'auto',  -- lualine may not have a matching theme, 'auto' is safer
        },
        sections = {
            lualine_a = {
                {
                    'filename',
                    path = 1,
                }
            }
        }
    }
end
ColorMyCode()
