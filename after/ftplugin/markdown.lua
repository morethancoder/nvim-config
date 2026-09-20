-- Readable pipe tables in markdown source.
--
--   :MdTableAlign / <leader>ta   pad every table in the buffer so columns line up
--   on save                      same, disable with `vim.g.markdown_table_autoalign = false`
--   cursor on a table row        line wrap is turned off, so a wide table scrolls
--                                sideways instead of wrapping and breaking the grid

local bufnr = vim.api.nvim_get_current_buf()

-- Split a table row into trimmed cells; `\|` does not split.
local function split_row(line)
    local s = vim.trim(line)
    if s:sub(1, 1) == '|' then s = s:sub(2) end
    if s:sub(-1) == '|' and s:sub(-2, -2) ~= '\\' then s = s:sub(1, -2) end

    local cells, cur, i = {}, {}, 1
    while i <= #s do
        local c = s:sub(i, i)
        if c == '\\' and s:sub(i + 1, i + 1) == '|' then
            cur[#cur + 1] = '\\|'
            i = i + 2
        elseif c == '|' then
            cells[#cells + 1] = vim.trim(table.concat(cur))
            cur = {}
            i = i + 1
        else
            cur[#cur + 1] = c
            i = i + 1
        end
    end
    cells[#cells + 1] = vim.trim(table.concat(cur))
    return cells
end

local function is_delimiter_row(cells)
    for _, c in ipairs(cells) do
        if not c:match('^:?%-+:?$') then return false end
    end
    return #cells > 0
end

local function pad(text, width, align)
    local gap = width - vim.fn.strdisplaywidth(text)
    if align == 'right' then return string.rep(' ', gap) .. text end
    if align == 'center' then
        local left = math.floor(gap / 2)
        return string.rep(' ', left) .. text .. string.rep(' ', gap - left)
    end
    return text .. string.rep(' ', gap)
end

-- Returns the aligned lines, or nil if the block is not a table.
local function format_table(lines)
    if #lines < 2 then return nil end
    local rows = {}
    for i, line in ipairs(lines) do rows[i] = split_row(line) end
    if not is_delimiter_row(rows[2]) then return nil end

    local ncol = 0
    for _, r in ipairs(rows) do ncol = math.max(ncol, #r) end

    local aligns, widths = {}, {}
    for c = 1, ncol do
        local d = rows[2][c] or '---'
        local left, right = d:sub(1, 1) == ':', d:sub(-1) == ':'
        aligns[c] = (left and right) and 'center' or right and 'right' or left and 'left' or 'none'
        widths[c] = 3
    end
    for i, r in ipairs(rows) do
        if i ~= 2 then
            for c = 1, ncol do
                widths[c] = math.max(widths[c], vim.fn.strdisplaywidth(r[c] or ''))
            end
        end
    end

    local indent = lines[1]:match('^%s*')
    local out = {}
    for i, r in ipairs(rows) do
        local cells = {}
        for c = 1, ncol do
            if i == 2 then
                local a, w = aligns[c], widths[c]
                local dashes = string.rep('-', w - ((a == 'left' or a == 'center') and 1 or 0) - ((a == 'right' or a == 'center') and 1 or 0))
                cells[c] = ((a == 'left' or a == 'center') and ':' or '') .. dashes .. ((a == 'right' or a == 'center') and ':' or '')
            else
                cells[c] = pad(r[c] or '', widths[c], aligns[c])
            end
        end
        out[i] = indent .. '| ' .. table.concat(cells, ' | ') .. ' |'
    end
    return out
end

-- Find table blocks (consecutive lines starting with `|`), skipping fenced code.
local function align_buffer()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local blocks, start, fence = {}, nil, nil

    for i, line in ipairs(lines) do
        local marker = line:match('^%s*(```)') or line:match('^%s*(~~~)')
        if marker then
            if not fence then fence = marker elseif fence == marker then fence = nil end
        end
        if not fence and not marker and line:match('^%s*|') then
            start = start or i
        elseif start then
            blocks[#blocks + 1] = { start, i - 1 }
            start = nil
        end
    end
    if start then blocks[#blocks + 1] = { start, #lines } end

    local view = vim.fn.winsaveview()
    local changed = 0
    for n = #blocks, 1, -1 do -- bottom-up so earlier line numbers stay valid
        local first, last = blocks[n][1], blocks[n][2]
        local block = vim.list_slice(lines, first, last)
        local formatted = format_table(block)
        if formatted and not vim.deep_equal(formatted, block) then
            vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, formatted)
            changed = changed + 1
        end
    end
    vim.fn.winrestview(view)
    return changed
end

vim.api.nvim_buf_create_user_command(bufnr, 'MdTableAlign', function()
    local n = align_buffer()
    vim.notify(n == 0 and 'Tables already aligned' or ('Aligned ' .. n .. (n == 1 and ' table' or ' tables')))
end, { desc = 'Align markdown pipe tables in this buffer' })

vim.keymap.set('n', '<leader>ta', '<cmd>MdTableAlign<CR>', { buffer = bufnr, desc = 'Align markdown tables' })

local group = vim.api.nvim_create_augroup('MdTables' .. bufnr, { clear = true })

vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    buffer = bufnr,
    callback = function()
        if vim.g.markdown_table_autoalign ~= false then align_buffer() end
    end,
})

-- Wide aligned rows must not wrap, or the columns drift apart again.
-- Set with local scope only, so the global 'wrap' (prose) is never overwritten.
local function set_wrap(value)
    vim.api.nvim_set_option_value('wrap', value, { scope = 'local', win = 0 })
end

local function sync_wrap()
    local on_table = vim.api.nvim_get_current_line():match('^%s*|') ~= nil
    set_wrap((not on_table) and vim.go.wrap)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorMoved', 'CursorMovedI' }, {
    group = group,
    buffer = bufnr,
    callback = sync_wrap,
})
vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = bufnr,
    callback = function() set_wrap(vim.go.wrap) end,
})
