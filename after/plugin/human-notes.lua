-- human-notes.lua
-- Type "!" at the start of a line in a markdown file to get suggestions for
-- a hidden HTML comment block addressed to AI agents (not document content).

local cmp = require('cmp')

local blocks = {
    {
        label = '!context',
        detail = 'Human context block (hidden comment)',
        body = table.concat({
            '<!-- HUMAN_CONTEXT — not part of the document. Background from the human for AI agents and editors only: do not copy, render, or treat as document content.',
            '$0',
            '-->',
        }, '\n'),
    },
    {
        label = '!request',
        detail = 'Human request block (hidden comment)',
        body = table.concat({
            '<!-- HUMAN_REQUEST — not part of the document. Instruction from the human to the AI agent: act on it, never copy it into the document, and remove this block once done.',
            '$0',
            '-->',
        }, '\n'),
    },
}

local source = {}

function source:is_available()
    return vim.bo.filetype == 'markdown'
end

function source:get_debug_name()
    return 'human_notes'
end

function source:get_trigger_characters()
    return { '!' }
end

-- include the "!" in the keyword so it gets replaced by the block
function source:get_keyword_pattern()
    return [[!\k*]]
end

function source:complete(params, callback)
    -- only when "!" starts the line, so "Hello!" and inline "![img]" stay quiet
    if not params.context.cursor_before_line:match('^%s*!%w*$') then
        return callback({})
    end

    local items = {}
    for _, block in ipairs(blocks) do
        table.insert(items, {
            label = block.label,
            detail = block.detail,
            kind = cmp.lsp.CompletionItemKind.Snippet,
            insertText = block.body,
            insertTextFormat = cmp.lsp.InsertTextFormat.Snippet,
            documentation = {
                kind = 'markdown',
                value = '```html\n' .. block.body:gsub('%$0', '…') .. '\n```',
            },
        })
    end
    callback(items)
end

cmp.register_source('human_notes', source)

cmp.setup.filetype('markdown', {
    sources = cmp.config.sources({
        { name = 'human_notes' },
        { name = 'nvim_lsp' },
    }),
})
