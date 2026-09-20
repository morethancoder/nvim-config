-- ~/.config/nvim/after/plugins/todo-comments.lua

require('todo-comments').setup {
    keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
        -- markdown blocks for AI agents, see human-notes.lua
        HUMAN_CONTEXT = { icon = " ", color = "hint" },
        HUMAN_REQUEST = { icon = " ", color = "warning" },
    },
    highlight = {
        pattern = {
            [[//\s*(KEYWORDS):]],                     -- match Go single-line comments
            [[\<!--\s*(HUMAN_CONTEXT|HUMAN_REQUEST)]], -- match human-notes blocks in markdown
        },
        keyword = "wide",
        after = "fg",
        comments_only = true,
    },
    search = {
        command = "rg",
        args = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column" },
        pattern = [[\b(KEYWORDS):|<!--\s*(HUMAN_CONTEXT|HUMAN_REQUEST)]],
    },
}

-- Keymaps
vim.keymap.set("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next todo comment" })
vim.keymap.set("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Previous todo comment" })

