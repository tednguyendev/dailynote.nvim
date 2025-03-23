local M = {}

local config = {
  workspaces = {},
  done_markers = { "- [x] " },
  recur_words = { "recur: " },
}

local function get_first_workspace()
  if #config.workspaces > 0 then
    return config.workspaces[1].name
  end
  return nil
end

local function get_default_workspace()
  for _, ws in ipairs(config.workspaces) do
    if ws.default then
      return ws.name
    end
  end
  -- If no workspace is marked as default, fall back to the first one
  return get_first_workspace()
end

local function get_current_workspace()
  local current_file = vim.fn.expand("%:p")
  for _, ws in ipairs(config.workspaces) do
    if current_file:match(ws.path) then
      return ws.name
    end
  end
  return get_default_workspace()
end

local function get_workspace_by_name(name)
  for _, ws in ipairs(config.workspaces) do
    if ws.name == name then
      return ws
    end
  end
  return nil
end

function filter_content(content)
  local filtered = {}

  -- Add this helper function
  local function escape_pattern(str)
    return str:gsub("([^%w])", "%%%1")
  end

  for _, line in ipairs(content) do
    local is_done = false
    for _, marker in ipairs(config.done_markers) do
      -- Escape the marker
      local pattern = escape_pattern(marker)
      if line:match(pattern) then
        is_done = true
        break
      end
    end

    if is_done then
      local is_recurring = false
      for _, word in ipairs(config.recur_words) do
        if line:match(word) then
          is_recurring = true
          break
        end
      end

      if is_recurring then
        -- Use escaped pattern here too
        for _, marker in ipairs(config.done_markers) do
          local pattern = escape_pattern(marker)
          line = line:gsub(pattern .. "%s*", "")
        end
      else
        goto continue
      end
    end
    table.insert(filtered, line)
    ::continue::
  end
  return filtered
end

local function apply_template(ws, filename)
  if not ws.template then
    return
  end

  local date = vim.fn.fnamemodify(filename, ":t:r")
  local content = ws.template:gsub("{{date}}", date)
  vim.fn.writefile(vim.split(content, "\n"), filename)
end

local function normalize_workspace(ws)
  -- Apply default values for workspace fields
  return {
    name = ws.name, -- No default for name
    path = ws.path or (vim.fn.stdpath("data") .. "/dailynote/" .. ws.name),
    date_format = ws.date_format or "%Y-%m-%d",
    default = ws.default or false,
    template = ws.template or "# {{date}}\n\n## Tasks\n\n## Notes\n",
  }
end

function M.create_daily_note(workspace_name, repeat_content)
  workspace_name = workspace_name or get_current_workspace()
  local ws = get_workspace_by_name(workspace_name)
  if not ws then
    vim.notify("Workspace not found: " .. (workspace_name or "nil"), vim.log.levels.ERROR)
    return
  end

  local today = os.date(ws.date_format)
  local today_file = ws.path .. "/" .. today .. ".md"

  if vim.fn.isdirectory(ws.path) == 0 then
    vim.fn.mkdir(ws.path, "p")
  end

  if vim.fn.filereadable(today_file) == 0 then
    local files = vim.fn.glob(ws.path .. "/*.md", false, true)
    local latest_file = nil
    local latest_date = 0

    for _, file in ipairs(files) do
      local filename = vim.fn.fnamemodify(file, ":t:r")
      if filename ~= today then -- Skip today's file
        local year, month, day = filename:match("(%d+)%-(%d+)%-(%d+)")
        if year and month and day then
          local file_date = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
          if file_date and file_date < os.time() and (latest_date == 0 or file_date > latest_date) then
            latest_date = file_date
            latest_file = file
          end
        end
      end
    end

    local last_file = latest_file

    if last_file and repeat_content then
      local content = vim.fn.readfile(last_file)
      vim.fn.writefile(filter_content(content), today_file)
    else
      vim.fn.writefile({}, today_file)
      apply_template(ws, today_file)
    end
    vim.notify("Created today's note in " .. workspace_name)
  end

  vim.cmd("edit " .. today_file)
end

function M.create_tomorrow_note(workspace_name, repeat_content)
  workspace_name = workspace_name or get_current_workspace()
  local ws = get_workspace_by_name(workspace_name)
  if not ws then
    vim.notify("Workspace not found: " .. (workspace_name or "nil"), vim.log.levels.ERROR)
    return
  end

  local tomorrow = os.date(ws.date_format, os.time() + 86400)
  local tomorrow_file = ws.path .. "/" .. tomorrow .. ".md"

  if vim.fn.filereadable(tomorrow_file) == 1 then
    vim.cmd("edit " .. tomorrow_file)
    return
  end

  local today_file = ws.path .. "/" .. os.date(ws.date_format) .. ".md"
  if vim.fn.filereadable(today_file) == 1 and repeat_content then
    local content = vim.fn.readfile(today_file)
    vim.fn.writefile(filter_content(content), tomorrow_file)
  else
    vim.fn.writefile({}, tomorrow_file)
    apply_template(ws, tomorrow_file)
  end

  vim.cmd("edit " .. tomorrow_file)
end

function M.open_previous_daily_note(workspace_name)
  workspace_name = workspace_name or get_current_workspace()
  local ws = get_workspace_by_name(workspace_name)
  if not ws then
    vim.notify("Workspace not found: " .. (workspace_name or "nil"), vim.log.levels.ERROR)
    return
  end

  local current_file = vim.fn.expand("%:p")

  -- Get all markdown files in the workspace
  local files = vim.fn.glob(ws.path .. "/*.md", false, true)
  table.sort(files, function(a, b)
    return a > b
  end) -- Sort in descending order

  local previous_file = nil
  for i, file in ipairs(files) do
    if file < current_file then
      previous_file = file
      break
    end
  end

  if previous_file then
    vim.cmd("edit " .. previous_file)
  else
    vim.notify("No previous daily notes found", vim.log.levels.WARN)
  end
end

function M.open_next_daily_note(workspace_name)
  workspace_name = workspace_name or get_current_workspace()
  local ws = get_workspace_by_name(workspace_name)
  if not ws then
    vim.notify("Workspace not found: " .. (workspace_name or "nil"), vim.log.levels.ERROR)
    return
  end

  local current_file = vim.fn.expand("%:p")

  -- Get all markdown files in the workspace
  local files = vim.fn.glob(ws.path .. "/*.md", false, true)
  table.sort(files) -- Sort in ascending order

  local next_file = nil
  for i, file in ipairs(files) do
    if file > current_file then
      next_file = file
      break
    end
  end

  if next_file then
    vim.cmd("edit " .. next_file)
  else
    vim.notify("No next daily notes found", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Normalize workspaces with default values
  for i, ws in ipairs(config.workspaces) do
    config.workspaces[i] = normalize_workspace(ws)
  end

  vim.api.nvim_create_user_command("DailyNote", function(cmd)
    M.create_daily_note(cmd.args ~= "" and cmd.args or nil, false)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("DailyNoteRepeat", function(cmd)
    M.create_daily_note(cmd.args ~= "" and cmd.args or nil, true)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("TomorrowNote", function(cmd)
    M.create_tomorrow_note(cmd.args ~= "" and cmd.args or nil, false)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("TomorrowNoteRepeat", function(cmd)
    M.create_tomorrow_note(cmd.args ~= "" and cmd.args or nil, true)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("PreviousDailyNote", function(cmd)
    M.open_previous_daily_note(cmd.args ~= "" and cmd.args or nil)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("NextDailyNote", function(cmd)
    M.open_next_daily_note(cmd.args ~= "" and cmd.args or nil)
  end, {
    nargs = "?",
    complete = function()
      local names = {}
      for _, ws in ipairs(config.workspaces) do
        table.insert(names, ws.name)
      end
      return names
    end,
  })
end

return M
