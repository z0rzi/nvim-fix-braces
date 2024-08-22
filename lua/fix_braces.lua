-- Finds the range on which we should work.
-- Bases itself on the last selection marker and the current position
local function determinate_search_range()
    -- The start_line is where the [ mark is
    local start_line = vim.fn.getpos("'[")[2] or 1
    local end_line = vim.fn.line(".") or 1

    return { start_line, end_line }
end

local function countBraces(from, to, pairs)
    -- Searching for all the characters matching the pairs.
    -- We want to remember the order of the pairs, so we can
    -- match them later.
    local regex = "⏺"
    for _, pair in ipairs(pairs) do
        regex = regex .. pair[1] .. pair[2]
    end
    regex = "[^" .. regex .. "]+"

    local current_lnum = vim.fn.line(".") or 1

    local all_lines = ""
    for linenum = from, to do
        local line = vim.fn.getline(linenum)
        if linenum == current_lnum then
            line = line .. "⏺"
        end
        all_lines = all_lines .. line
    end

    -- Removing all the characters that are not part of the pairs from all_lines
    local braces = all_lines:gsub(regex, "")

    -- removing all matching braces (e.g. '{}' or '()' or '[]') recursively
    while true do
        local new_braces = braces
        for _, pair in ipairs(pairs) do
            local rx = pair[1] .. pair[2]
            new_braces = new_braces:gsub(rx, "")
        end
        if new_braces == braces then
            break
        end
        braces = new_braces
    end

    -- removing opening braces at the end of the line
    local closing_braces_rx = ""
    local opening_braces_rx = ""
    for _, pair in ipairs(pairs) do
        opening_braces_rx = opening_braces_rx .. pair[1]
        closing_braces_rx = closing_braces_rx .. pair[2]
    end
    braces = braces:gsub("[" .. opening_braces_rx .. "]+$", "")
    braces = braces:gsub("^[" .. closing_braces_rx .. "]+", "")
    print(braces)

    -- separating the braces before and after the cursor.
    local cursor_pos = braces:find("⏺")
    local braces_before = braces:sub(1, cursor_pos - 1)
    local braces_after = braces:sub(cursor_pos + 3):reverse()

    -- Removing all the matching braces from the braces_before and braces_after
    while true do
        local prev_brace = braces_before:sub(-1)
        local next_brace = braces_after:sub(-1)
        local found_pair = false
        for _, pair in ipairs(pairs) do
            if prev_brace:match(pair[1]) and next_brace:match(pair[2]) then
                braces_before = braces_before:sub(1, -2)
                braces_after = braces_after:sub(1, -2)
                found_pair = true
                break
            end
        end
        if not found_pair then
            break
        end
    end

    -- Doing the same thing, but from the end of the strings
    braces_before = braces_before:reverse()
    braces_after = braces_after:reverse()
    while true do
        local prev_brace = braces_before:sub(-1)
        local next_brace = braces_after:sub(-1)
        local found_pair = false
        for _, pair in ipairs(pairs) do
            if prev_brace:match(pair[1]) and next_brace:match(pair[2]) then
                braces_before = braces_before:sub(1, -2)
                braces_after = braces_after:sub(1, -2)
                found_pair = true
                break
            end
        end
        if not found_pair then
            break
        end
    end

    local add_stack = ''
    local remove_stack = ''

    -- Adding the missing braces to the stacks
    while braces_before:len() > 0 do
        local prev_brace = braces_before:sub(-1)
        for _, pair in ipairs(pairs) do
            if prev_brace:match(pair[1]) then
                add_stack = add_stack .. pair[2]:sub(-1)
                break
            end
            if prev_brace:match(pair[2]) then
                -- There's an extra cosing brace before the cursor... We try to
                -- remove them if they are on the current line
                remove_stack = remove_stack .. pair[2]:sub(-1)
                break
            end
        end
        braces_before = braces_before:sub(1, -2)
    end
    while braces_after:len() > 0 do
        local next_brace = braces_after:sub(-1)
        for _, pair in ipairs(pairs) do
            if next_brace:match(pair[2]) then
                add_stack = add_stack .. pair[1]:sub(-1)
                break
            end
            if next_brace:match(pair[1]) then
                -- There's an extra opening brace after the cursor... We don't
                -- do anything about it.
                break
            end
        end
        braces_after = braces_after:sub(1, -2)
    end

    return { add_stack, remove_stack };
end

local function fix_braces()
    local range = determinate_search_range()

    local start_line = range[1]
    local end_line = range[2]

    local pairs = {
        { "{",  "}" },
        { "%(", "%)" },
        { "%[", "%]" },
    }
    -- % for escaping special characters

    local charas = countBraces(start_line, end_line, pairs)
    local add_stack = charas[1]
    local remove_stack = charas[2]

    local current_line = vim.fn.getline(".") or 1

    -- Removing the characters from remove_stack if they are present on the current line

    -- We want to remove the last character first, so we reverse the string
    current_line = current_line:reverse()
    while remove_stack:len() > 0 do
        local pos = current_line:find(remove_stack)
        if pos then
            current_line = current_line:sub(1, pos - 1) .. current_line:sub(pos + 1)
        end
        remove_stack = remove_stack:sub(1, -2)
    end
    current_line = current_line:reverse()

    -- Adding the characters at the end of the current line, before the ';' if there is one
    add_stack = add_stack:reverse()
    local pos = current_line:find(";")
    if pos then
        current_line = current_line:sub(1, pos - 1) .. add_stack .. current_line:sub(pos)
    else
        current_line = current_line .. add_stack
    end
    vim.fn.setline(".", current_line)
end

return {
    fix_braces = fix_braces
}
