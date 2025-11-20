local M = {}

local function get_first_ws(config)
  if #config.workspaces > 0 then
    return config.workspaces[1].name
  end

  return nil
end

local function get_default_ws(config)
  for _, ws in ipairs(config.workspaces) do
    if ws.default then
      return ws.name
    end
  end

  return get_first_ws(config)
end

local function get_current_ws_name(config)
  local current_file = vim.fn.expand("%:p")
  local sorted_workspaces = {}

  for _, ws in ipairs(config.workspaces) do
    table.insert(sorted_workspaces, ws)
  end

  table.sort(sorted_workspaces, function(a, b)
    return #a.path > #b.path
  end)

  for _, ws in ipairs(sorted_workspaces) do
    if current_file:find(ws.path, 1, true) == 1 then
      return ws.name
    end
  end

  return get_default_ws(config)
end

local function get_ws_by_name(name, config)
  for _, ws in ipairs(config.workspaces) do
    if ws.name == name then
      return ws
    end
  end

  return nil
end

function M.get_ws(ws_name, config)
  ws_name = ws_name or get_current_ws_name(config)
  local ws = get_ws_by_name(ws_name, config)

  if not ws then
    vim.notify("Workspace not found: " .. (ws_name or "nil"), vim.log.levels.ERROR)
    return nil
  end

  return ws
end

function M.file_exists(filepath)
  return vim.fn.filereadable(filepath) == 1
end

function M.open_file(file)
  vim.cmd("edit " .. file)
end

function M.filter_content(content, config)
  local filtered = {}

  local function escape_pattern(str)
    return str:gsub("([^%w])", "%%%1")
  end

  local function is_done_line(line, config)
    for _, marker in ipairs(config.done_markers) do
      local pattern = escape_pattern(marker)
      if line:match(pattern) then
        return true
      end
    end
    return false
  end

  local function is_recurring_line(line, config)
    for _, word in ipairs(config.recur_words) do
      if line:match(word) then
        return true
      end
    end
    return false
  end

  local function remove_done_markers(line, config)
    for _, marker in ipairs(config.done_markers) do
      local pattern = escape_pattern(marker)
      line = line:gsub(pattern .. "%s*", "")
    end
    return line
  end

  for _, line in ipairs(content) do
    if is_done_line(line, config) then
      if is_recurring_line(line, config) then
        line = remove_done_markers(line, config)
        table.insert(filtered, line)
      end
    else
      table.insert(filtered, line)
    end
  end

  return filtered
end

function M.normalize_ws(ws)
  return {
    name = ws.name,
    path = ws.path or (vim.fn.stdpath("data") .. "/dailynote/" .. ws.name),
    date_format = ws.date_format or "%Y-%m-%d",
    default = ws.default or false,
    template = ws.template or "# {{date}}\n\n## Tasks\n\n## Notes\n",
  }
end

function M.apply_template(ws, filename)
  if not ws.template then
    return
  end

  local date = vim.fn.fnamemodify(filename, ":t:r")
  local content = ws.template:gsub("{{date}}", date)

  vim.fn.writefile(vim.split(content, "\n"), filename)
end

function M.get_current_file()
  return vim.fn.expand("%:p")
end

function M.get_files(ws)
  return vim.fn.glob(ws.path .. "/*.md", false, true)
end

function M.create_tmr_note(ws, tomorrow_file, should_recur, config)
  local date_format = ws.date_format or "%Y-%m-%d"
  local today_file = ws.path .. "/" .. os.date(date_format) .. ".md"

  if M.file_exists(today_file) and should_recur then
    local content = vim.fn.readfile(today_file)

    vim.fn.writefile(M.filter_content(content, config), tomorrow_file)
  else
    vim.fn.writefile({}, tomorrow_file)
    M.apply_template(ws, tomorrow_file)
  end
end

function M.find_latest_file(files, today)
  local latest_file = nil
  local latest_date = 0

  local function parse_date_string(date_str)
    local year, month, day = date_str:match("(%d+)%-(%d+)%-(%d+)")
    if year and month and day then
      return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
    end
    return nil
  end

  local function is_valid_file(file, today_time)
    local filename = vim.fn.fnamemodify(file, ":t:r")
    if filename == today then
      return false
    end

    local file_date = parse_date_string(filename)
    return file_date and file_date < today_time
  end

  local function is_more_recent(file_date, latest_date)
    return latest_date == 0 or file_date > latest_date
  end

  local today_time = parse_date_string(today)
  if not today_time then
    return nil
  end

  for _, file in ipairs(files) do
    if is_valid_file(file, today_time) then
      local filename = vim.fn.fnamemodify(file, ":t:r")
      local file_date = parse_date_string(filename)

      if file_date and is_more_recent(file_date, latest_date) then
        latest_date = file_date
        latest_file = file
      end
    end
  end

  return latest_file
end

function M.find_next_file(files, current_file)
  table.sort(files)

  for _, file in ipairs(files) do
    if file > current_file then
      return file
    end
  end

  return nil
end

function M.find_previous_file(files, current_file)
  table.sort(files, function(a, b)
    return a > b
  end)

  for _, file in ipairs(files) do
    if file < current_file then
      return file
    end
  end

  return nil
end

function M.create_directory(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

function M.create_today_note(ws, file, date, should_recur, config)
  local files = M.get_files(ws)
  local last_file = M.find_latest_file(files, date)
  local content = nil

  if last_file and should_recur then
    content = M.filter_content(vim.fn.readfile(last_file), config)
  end

  if content and #content > 0 then
    vim.fn.writefile(content, file)
  else
    vim.fn.writefile({}, file)
    M.apply_template(ws, file)
  end

  vim.notify("Created today's note in " .. ws.name)
end

return M
