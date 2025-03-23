local M = require("dailynote")

describe("Daily Notes Module", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname()
    os.execute("mkdir " .. test_dir)
    M.setup({
      workspaces = {
        {
          name = "test",
          path = test_dir,
        },
      },
      recur_words = { "recur" },
      done_markers = { "xx " },
    })
  end)

  after_each(function()
    os.execute("rm -r " .. test_dir)
  end)

  describe("commands", function()
    it("creates DailyNote command", function()
      assert.truthy(vim.api.nvim_get_commands({}).DailyNote)
    end)

    it("creates DailyNoteRepeat command", function()
      assert.truthy(vim.api.nvim_get_commands({}).DailyNoteRepeat)
    end)

    it("creates TomorrowNote command", function()
      assert.truthy(vim.api.nvim_get_commands({}).TomorrowNote)
    end)

    it("creates TomorrowNoteRepeat command", function()
      assert.truthy(vim.api.nvim_get_commands({}).TomorrowNoteRepeat)
    end)

    it("creates PreviousDailyNote command", function()
      assert.truthy(vim.api.nvim_get_commands({}).PreviousDailyNote)
    end)

    it("creates NextDailyNote command", function()
      assert.truthy(vim.api.nvim_get_commands({}).NextDailyNote)
    end)
  end)

  describe("DailyNote command", function()
    it("creates new daily note with default template", function()
      local today = os.date("%Y-%m-%d")
      local expected_file = test_dir .. "/" .. today .. ".md"

      vim.cmd("DailyNote")
      vim.wait(100)

      assert.is_true(vim.fn.filereadable(expected_file) == 1)
      local content = vim.fn.readfile(expected_file)
      -- Check content starts with expected template
      assert.are.equal("# " .. today, content[1])
      assert.are.equal("", content[2])
      assert.are.equal("## Tasks", content[3])
      assert.are.equal("", content[4])
      assert.are.equal("## Notes", content[5])
    end)

    it("edits existing daily note", function()
      local today = os.date("%Y-%m-%d")
      local today_file = test_dir .. "/" .. today .. ".md"
      vim.fn.writefile({ "Existing content" }, today_file)

      vim.cmd("DailyNote")
      vim.wait(100)

      assert.are.equal(today_file, vim.fn.expand("%:p"))
    end)
  end)

  describe("DailyNoteRepeat command", function()
    it("repeats content from previous day", function()
      local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
      local today = os.date("%Y-%m-%d")
      local yesterday_file = test_dir .. "/" .. yesterday .. ".md"
      local today_file = test_dir .. "/" .. today .. ".md"

      vim.fn.writefile({ "xx task recur", "xx done task", "ongoing" }, yesterday_file)

      vim.cmd("DailyNoteRepeat")
      vim.wait(100)

      local content = vim.fn.readfile(today_file)
      assert.are.same({ "task recur", "ongoing" }, content)
    end)
  end)

  describe("TomorrowNote command", function()
    it("creates tomorrow's note with default template", function()
      local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
      local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

      vim.cmd("TomorrowNote")
      vim.wait(100)

      assert.is_true(vim.fn.filereadable(tomorrow_file) == 1)
      local content = vim.fn.readfile(tomorrow_file)
      -- Check content starts with expected template
      assert.are.equal("# " .. tomorrow, content[1])
      assert.are.equal("", content[2])
      assert.are.equal("## Tasks", content[3])
      assert.are.equal("", content[4])
      assert.are.equal("## Notes", content[5])
      assert.are.equal(tomorrow_file, vim.fn.expand("%:p"))
    end)
  end)

  describe("TomorrowNoteRepeat command", function()
    it("repeats today's content for tomorrow", function()
      local today = os.date("%Y-%m-%d")
      local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
      local today_file = test_dir .. "/" .. today .. ".md"
      local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

      vim.fn.writefile({ "xx task recur", "regular task" }, today_file)

      vim.cmd("TomorrowNoteRepeat")
      vim.wait(100)

      local content = vim.fn.readfile(tomorrow_file)
      assert.are.same({ "task recur", "regular task" }, content)
    end)
  end)

  describe("PreviousDailyNote command", function()
    it("opens previous note", function()
      local today = os.date("%Y-%m-%d")
      local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
      local yesterday_file = test_dir .. "/" .. yesterday .. ".md"
      local today_file = test_dir .. "/" .. today .. ".md"

      vim.fn.writefile({ "Yesterday's content" }, yesterday_file)
      vim.fn.writefile({ "Today's content" }, today_file)

      vim.cmd("edit " .. today_file)
      vim.wait(100)
      vim.cmd("PreviousDailyNote")
      vim.wait(100)

      assert.are.equal(yesterday_file, vim.fn.expand("%:p"))
    end)

    it("notifies when no previous note exists", function()
      local today = os.date("%Y-%m-%d")
      local today_file = test_dir .. "/" .. today .. ".md"
      vim.fn.writefile({ "Today's content" }, today_file)

      -- Capture notification
      local notification = nil
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notification = { msg = msg, level = level }
      end

      vim.cmd("edit " .. today_file)
      vim.wait(100)
      vim.cmd("PreviousDailyNote")
      vim.wait(100)

      -- Restore original notify function
      vim.notify = original_notify

      assert.is_not_nil(notification)
      assert.are.equal("No previous daily notes found", notification.msg)
      assert.are.equal(vim.log.levels.WARN, notification.level)
    end)
  end)

  describe("NextDailyNote command", function()
    it("opens next note", function()
      local today = os.date("%Y-%m-%d")
      local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
      local today_file = test_dir .. "/" .. today .. ".md"
      local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

      vim.fn.writefile({ "Today's content" }, today_file)
      vim.fn.writefile({ "Tomorrow's content" }, tomorrow_file)

      vim.cmd("edit " .. today_file)
      vim.wait(100)
      vim.cmd("NextDailyNote")
      vim.wait(100)

      assert.are.equal(tomorrow_file, vim.fn.expand("%:p"))
    end)

    it("notifies when no next note exists", function()
      local today = os.date("%Y-%m-%d")
      local today_file = test_dir .. "/" .. today .. ".md"
      vim.fn.writefile({ "Today's content" }, today_file)

      -- Capture notification
      local notification = nil
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notification = { msg = msg, level = level }
      end

      vim.cmd("edit " .. today_file)
      vim.wait(100)
      vim.cmd("NextDailyNote")
      vim.wait(100)

      -- Restore original notify function
      vim.notify = original_notify

      assert.is_not_nil(notification)
      assert.are.equal("No next daily notes found", notification.msg)
      assert.are.equal(vim.log.levels.WARN, notification.level)
    end)
  end)

  describe("workspace handling", function()
    before_each(function()
      M.setup({
        workspaces = {
          { name = "work", path = test_dir .. "/work" }, -- No date_format or template, uses defaults
          { name = "personal", path = test_dir .. "/personal", default = true },
        },
      })
      os.execute("mkdir " .. test_dir .. "/work")
      os.execute("mkdir " .. test_dir .. "/personal")
    end)

    it("uses specified workspace", function()
      local today = os.date("%Y-%m-%d")
      local expected_file = test_dir .. "/work/" .. today .. ".md"

      vim.cmd("DailyNote work")
      vim.wait(100)

      assert.is_true(vim.fn.filereadable(expected_file) == 1)
    end)

    it("falls back to default workspace", function()
      local today = os.date("%Y-%m-%d")
      local expected_file = test_dir .. "/personal/" .. today .. ".md"

      vim.cmd("edit " .. test_dir .. "/random/file.txt")
      vim.wait(100)
      vim.cmd("DailyNote")
      vim.wait(100)

      assert.is_true(vim.fn.filereadable(expected_file) == 1)
    end)
  end)
end)
