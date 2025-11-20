local helpers = require("dailynote.helpers")
local M = {}

local config = {
  workspaces = {},
  done_markers = { "- [x] " },
  recur_words = { "recur: " },
}

local function create_note(ws_name, should_recur, type)
  local ws = helpers.get_ws(ws_name, config)
  if not ws then return end

  local date_offset = type == "tmr" and 1 or 0
  local date = os.date(ws.date_format, os.time() + date_offset * 86400)
  local file = ws.path .. "/" .. date .. ".md"

  helpers.create_directory(ws.path)

  if helpers.file_exists(file) then
    helpers.open_file(file)

    return
  end

  if type == "tmr" then
    helpers.create_tmr_note(ws, file, should_recur, config)
  else
    helpers.create_today_note(ws, file, date, should_recur, config)
  end

  helpers.open_file(file)
end

function M.create_today(ws_name, should_recur)
  create_note(ws_name, should_recur, "today")
end

function M.create_tmr(ws_name, should_recur)
  create_note(ws_name, should_recur, "tmr")
end

local function navigate_note(ws_name, direction)
  local ws = helpers.get_ws(ws_name, config)
  if not ws then return end

  local files = helpers.get_files(ws)
  local current_file = helpers.get_current_file()
  local file = direction == "next" and
      helpers.find_next_file(files, current_file) or
      helpers.find_previous_file(files, current_file)

  if file then
    helpers.open_file(file)
  else
    vim.notify("No " .. direction .. " daily notes found", vim.log.levels.WARN)
  end
end

function M.show_prev(ws_name)
  navigate_note(ws_name, "previous")
end

function M.show_next(ws_name)
  navigate_note(ws_name, "next")
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  for i, ws in ipairs(config.workspaces) do
    config.workspaces[i] = helpers.normalize_ws(ws)
  end

  local function get_ws_names()
    return vim.tbl_map(function(ws) return ws.name end, config.workspaces)
  end

  local function parse_ws_arg(cmd)
    return cmd.args ~= "" and cmd.args or nil
  end

  local command_opts = { nargs = "?", complete = get_ws_names }

  local commands = {
    { "DailyNote",          function(cmd) M.create_today(parse_ws_arg(cmd), false) end },
    { "DailyNoteRepeat",    function(cmd) M.create_today(parse_ws_arg(cmd), true) end },
    { "TomorrowNote",       function(cmd) M.create_tmr(parse_ws_arg(cmd), false) end },
    { "TomorrowNoteRepeat", function(cmd) M.create_tmr(parse_ws_arg(cmd), true) end },
    { "PreviousDailyNote",  function(cmd) M.show_prev(parse_ws_arg(cmd)) end },
    { "NextDailyNote",      function(cmd) M.show_next(parse_ws_arg(cmd)) end },
  }

  for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd[1], cmd[2], command_opts)
  end
end

return M
