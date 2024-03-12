local M = {}

function M.setup(opts)
  config = opts or {}
  vim.api.nvim_create_user_command(
    'Run',
    M.run,
    {desc = 'Search projects folder', range = '%'  }
  )
end

-- local commands_config = {
--   curl = {
--     multi_line = false,
--     multi_line_lf = ' ',
--     trim_start = true,
--     split_first_line = true,
--   },
--   http = {
--     cmd = { "http", "--verify", "no", "--ignore-stdin", "--pretty",  "all",  "-vv", "--timeout", "1000", "--follow" },
--     multi_line = false,
--     multi_line_lf = ' ',
--     trim_start = true,
--     split_first_line = true,
--   },
--   redis_graph = {
--     cmd = { "redis-cli", "--raw", "GRAPH.RO_QUERY", "graph" },
--     multi_line = true,
--     multi_line_lf = ' ',
--     trim_start = false,
--     split_first_line = false,
--   },
--   ['redis-cli'] = {
--     multi_line = true,
--     multi_line_lf = ' ',
--     trim_start = false,
--     split_first_line = false,
--   },
--   sh = {
--     cmd = { "bash", "-c" },
--     multi_line = true,
--     multi_line_lf = '\n',
--     trim_start = false,
--     split_first_line = false,
--   },
--   bash = {
--     cmd = { "bash", "-c" },
--     multi_line = true,
--     multi_line_lf = '\n',
--     trim_start = false,
--     split_first_line = false,
--   },
--   default = {
--     multi_line = false,
--     multi_line_lf = ' ',
--     trim_start = true,
--     split_first_line = false,
--   },
-- }

M.cmd = function()
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local filetype = vim.bo.filetype
  local all_lines = vim.api.nvim_buf_get_lines(0, 0, cur_line, false)
  local cmd = {}
  for i=cur_line, 1, -1 do
    local line = all_lines[i]
    if line:sub(0, 3) == '---' then
      if line ~= "---" then
        for value in string.gmatch(line:sub(4, -1), "%S+") do
          table.insert(cmd, value)
        end
        break
      end
    end
  end
  if next(cmd) == nil then
    cmd = { filetype }
  end
  local cmd_alias = config.cmds[cmd[1]]
  if cmd_alias ~= nil then
    if cmd_alias.cmd ~= nil then
      table.remove(cmd, 1)
      for i, param in ipairs(cmd_alias.cmd) do
        table.insert(cmd, i, param)
      end
    end
  else
    cmd_alias = config.cmds["default"]
  end
  return { cmd, cmd_alias }
end

M.parse_args = function(args, config)
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local start_line = args.line1
  local end_line = args.line2
  local result = {}
  if args.count == -1 then
    local all_lines = vim.api.nvim_buf_get_lines(0, start_line-1, end_line, false)
    for i=cur_line, start_line - 1, -1 do
      line = all_lines[i]
      if line:sub(0, 3) == '---' then
        start_line = i + 1
        if line ~= "---" then trap_line = i end
        break
      end
    end
    for i=cur_line + 1, end_line do
      line = all_lines[i]
      if line:sub(0, 3) == '---' then
        end_line = i - 1
        break
      end
    end
  end
  local all_lines = vim.api.nvim_buf_get_lines(0, start_line-1, end_line, false)

  local content = ""
  local is_in_multi_line = config.multi_line
  for i,line in ipairs(all_lines) do
    if line:find("^%s*//") ~= nil then goto continue end
    if line:find("^%s*$") ~= nil then goto continue end
    line = line:gsub('$%$','\0'):gsub('${([%w_]+)}', os.getenv):gsub('$([%w_]+)', os.getenv):gsub('%z','$')
    if config.trim_start then line = line:gsub("^%s+", "") end
    if i == 1 and config.split_first_line == true then
      for value in string.gmatch(line, "%S+") do
        table.insert(result, value)
      end
      goto continue
    end
    if is_in_multi_line == false and line:sub(1, 3) == "```" then
      is_in_multi_line = true
      goto continue
    end
    if is_in_multi_line == true and line:sub(1, 3) == "```" then
      is_in_multi_line = config.multi_line
      table.insert(result, content)
      content = ''
      goto continue
    end
    if is_in_multi_line then
      content = content .. line .. config.multi_line_lf
    else
      table.insert(result, line)
    end
    ::continue::
  end
  if content ~= "" then table.insert(result, content) end
  return result
end

M.execute = function(cmd)
  if cmd == nil then
    return {}
  end
  local gheight = vim.api.nvim_list_uis()[1].height
  local gwidth = vim.api.nvim_list_uis()[1].width
  local buf = vim.api.nvim_create_buf(false, true)
  local width = gwidth - 10
  local height = gheight - 4
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (gheight - height) * 0.5,
    col = (gwidth - width) * 0.5,
    -- style = "minimal",
    border = "rounded",
  })
  local term = vim.api.nvim_open_term(buf,{})
  local h = vim.fn.jobstart(cmd, {
    width = width,
    on_stdout = function(chan, data) vim.api.nvim_chan_send(term,table.concat(data, "\r\n")) end,
    on_stderr = function(chan, data) vim.api.nvim_chan_send(term,table.concat(data, "\r\n")) end
  })
end

M.run = function(args)
  local cmd_result = M.cmd()
  local cmd = cmd_result[1]

  local cmd_args = M.parse_args(args, cmd_result[2])
  for _,v in ipairs(cmd_args) do
    table.insert(cmd, v)
  end
  -- print("[execute]" .. vim.inspect(cmd))
  M.execute(cmd)
end

return M
