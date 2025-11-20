local setup = require("dailynote.setup")

describe("Setup Module", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname()
    os.execute("mkdir " .. test_dir)
  end)

  after_each(function()
    os.execute("rm -r " .. test_dir)
  end)

  describe("setup function", function()
    it("creates DailyNote command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).DailyNote)
    end)

    it("creates DailyNoteRepeat command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).DailyNoteRepeat)
    end)

    it("creates TomorrowNote command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).TomorrowNote)
    end)

    it("creates TomorrowNoteRepeat command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).TomorrowNoteRepeat)
    end)

    it("creates PreviousDailyNote command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).PreviousDailyNote)
    end)

    it("creates NextDailyNote command", function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
      assert.truthy(vim.api.nvim_get_commands({}).NextDailyNote)
    end)
  end)

  describe("create_today function", function()
    before_each(function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
    end)

    describe("given existing daily note", function()
      it("edits existing daily note", function()
        local today = os.date("%Y-%m-%d")
        local today_file = test_dir .. "/" .. today .. ".md"
        vim.fn.writefile({ "Existing content" }, today_file)

        setup.create_today("test", false)
        vim.wait(100)

        assert.are.equal(today_file, vim.fn.expand("%:p"))
      end)
    end)

    describe("given NOT existing daily note", function()
      describe("given should_recur is false", function()
        describe("given no previous files", function()
          it("creates new daily note with default template", function()
            local today = os.date("%Y-%m-%d")
            local expected_file = test_dir .. "/" .. today .. ".md"

            setup.create_today("test", false)
            vim.wait(100)

            assert.is_true(vim.fn.filereadable(expected_file) == 1)
            local content = vim.fn.readfile(expected_file)
            assert.are.equal("# " .. today, content[1])
            assert.are.equal("", content[2])
            assert.are.equal("## Tasks", content[3])
            assert.are.equal("", content[4])
            assert.are.equal("## Notes", content[5])
          end)
        end)

        describe("given previous files exist", function()
          it("creates new daily note with default template", function()
            local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
            local today = os.date("%Y-%m-%d")
            local yesterday_file = test_dir .. "/" .. yesterday .. ".md"
            local today_file = test_dir .. "/" .. today .. ".md"

            vim.fn.writefile({ "xx task recur", "ongoing" }, yesterday_file)

            setup.create_today("test", false)
            vim.wait(100)

            assert.is_true(vim.fn.filereadable(today_file) == 1)
            local content = vim.fn.readfile(today_file)
            assert.are.equal("# " .. today, content[1])
            assert.are.equal("", content[2])
            assert.are.equal("## Tasks", content[3])
            assert.are.equal("", content[4])
            assert.are.equal("## Notes", content[5])
          end)
        end)
      end)

      describe("given should_recur is true", function()
        describe("given no previous files", function()
          it("creates new daily note with default template", function()
            local today = os.date("%Y-%m-%d")
            local expected_file = test_dir .. "/" .. today .. ".md"

            setup.create_today("test", true)
            vim.wait(100)

            assert.is_true(vim.fn.filereadable(expected_file) == 1)
            local content = vim.fn.readfile(expected_file)
            assert.are.equal("# " .. today, content[1])
            assert.are.equal("", content[2])
            assert.are.equal("## Tasks", content[3])
            assert.are.equal("", content[4])
            assert.are.equal("## Notes", content[5])
          end)
        end)

        describe("given previous file exists", function()
          it("repeats content from previous day", function()
            setup.setup({
              workspaces = {
                { name = "test", path = test_dir },
              },
              recur_words = { "recur" },
              done_markers = { "xx " },
            })

            local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
            local today = os.date("%Y-%m-%d")
            local yesterday_file = test_dir .. "/" .. yesterday .. ".md"
            local today_file = test_dir .. "/" .. today .. ".md"

            vim.fn.writefile({ "xx task recur", "xx done task", "ongoing" }, yesterday_file)

            setup.create_today("test", true)
            vim.wait(100)

            local content = vim.fn.readfile(today_file)
            assert.are.same({ "task recur", "ongoing" }, content)
          end)
        end)
      end)
    end)
  end)

  describe("create_tmr function", function()
    before_each(function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
    end)

    describe("given should_recur is false", function()
      it("creates tomorrow's note with default template", function()
        local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
        local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

        setup.create_tmr("test", false)
        vim.wait(100)

        assert.is_true(vim.fn.filereadable(tomorrow_file) == 1)
        local content = vim.fn.readfile(tomorrow_file)
        assert.are.equal("# " .. tomorrow, content[1])
        assert.are.equal("", content[2])
        assert.are.equal("## Tasks", content[3])
        assert.are.equal("", content[4])
        assert.are.equal("## Notes", content[5])
        assert.are.equal(tomorrow_file, vim.fn.expand("%:p"))
      end)
    end)

    describe("given should_recur is true", function()
      describe("given today's file exists", function()
        it("repeats today's content for tomorrow", function()
          local today = os.date("%Y-%m-%d")
          local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
          local today_file = test_dir .. "/" .. today .. ".md"
          local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

          vim.fn.writefile({ "xx task recur", "regular task" }, today_file)

          setup.create_tmr("test", true)
          vim.wait(100)

          local content = vim.fn.readfile(tomorrow_file)
          assert.are.same({ "task recur", "regular task" }, content)
        end)
      end)

      describe("given today's file does not exist", function()
        it("creates tomorrow's note with default template", function()
          local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
          local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

          setup.create_tmr("test", true)
          vim.wait(100)

          assert.is_true(vim.fn.filereadable(tomorrow_file) == 1)
          local content = vim.fn.readfile(tomorrow_file)
          assert.are.equal("# " .. tomorrow, content[1])
          assert.are.equal("", content[2])
          assert.are.equal("## Tasks", content[3])
          assert.are.equal("", content[4])
          assert.are.equal("## Notes", content[5])
        end)
      end)
    end)
  end)

  describe("show_prev function", function()
    before_each(function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
    end)

    describe("given previous note exists", function()
      it("opens previous note", function()
        local today = os.date("%Y-%m-%d")
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        local yesterday_file = test_dir .. "/" .. yesterday .. ".md"
        local today_file = test_dir .. "/" .. today .. ".md"

        vim.fn.writefile({ "Yesterday's content" }, yesterday_file)
        vim.fn.writefile({ "Today's content" }, today_file)

        vim.cmd("edit " .. today_file)
        vim.wait(100)
        setup.show_prev("test")
        vim.wait(100)

        assert.are.equal(yesterday_file, vim.fn.expand("%:p"))
      end)
    end)

    describe("given no previous note exists", function()
      it("notifies when no previous note exists", function()
        local today = os.date("%Y-%m-%d")
        local today_file = test_dir .. "/" .. today .. ".md"
        vim.fn.writefile({ "Today's content" }, today_file)

        local notification = nil
        local original_notify = vim.notify
        vim.notify = function(msg, level)
          notification = { msg = msg, level = level }
        end

        vim.cmd("edit " .. today_file)
        vim.wait(100)
        setup.show_prev("test")
        vim.wait(100)

        vim.notify = original_notify

        assert.is_not_nil(notification)
        assert.are.equal("No previous daily notes found", notification.msg)
        assert.are.equal(vim.log.levels.WARN, notification.level)
      end)
    end)
  end)

  describe("show_next function", function()
    before_each(function()
      setup.setup({
        workspaces = {
          { name = "test", path = test_dir },
        },
      })
    end)

    describe("given next note exists", function()
      it("opens next note", function()
        local today = os.date("%Y-%m-%d")
        local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
        local today_file = test_dir .. "/" .. today .. ".md"
        local tomorrow_file = test_dir .. "/" .. tomorrow .. ".md"

        vim.fn.writefile({ "Today's content" }, today_file)
        vim.fn.writefile({ "Tomorrow's content" }, tomorrow_file)

        vim.cmd("edit " .. today_file)
        vim.wait(100)
        setup.show_next("test")
        vim.wait(100)

        assert.are.equal(tomorrow_file, vim.fn.expand("%:p"))
      end)
    end)

    describe("given no next note exists", function()
      it("notifies when no next note exists", function()
        local today = os.date("%Y-%m-%d")
        local today_file = test_dir .. "/" .. today .. ".md"
        vim.fn.writefile({ "Today's content" }, today_file)

        local notification = nil
        local original_notify = vim.notify
        vim.notify = function(msg, level)
          notification = { msg = msg, level = level }
        end

        vim.cmd("edit " .. today_file)
        vim.wait(100)
        setup.show_next("test")
        vim.wait(100)

        vim.notify = original_notify

        assert.is_not_nil(notification)
        assert.are.equal("No next daily notes found", notification.msg)
        assert.are.equal(vim.log.levels.WARN, notification.level)
      end)
    end)
  end)

  describe("workspace handling", function()
    describe("given specified workspace", function()
      it("uses specified workspace", function()
        setup.setup({
          workspaces = {
            { name = "work",     path = test_dir .. "/work" },
            { name = "personal", path = test_dir .. "/personal", default = true },
          },
        })
        os.execute("mkdir " .. test_dir .. "/work")
        os.execute("mkdir " .. test_dir .. "/personal")

        local today = os.date("%Y-%m-%d")
        local expected_file = test_dir .. "/work/" .. today .. ".md"

        setup.create_today("work", false)
        vim.wait(100)

        assert.is_true(vim.fn.filereadable(expected_file) == 1)
      end)
    end)

    describe("given no workspace specified", function()
      it("falls back to default workspace", function()
        setup.setup({
          workspaces = {
            { name = "work",     path = test_dir .. "/work" },
            { name = "personal", path = test_dir .. "/personal", default = true },
          },
        })
        os.execute("mkdir " .. test_dir .. "/work")
        os.execute("mkdir " .. test_dir .. "/personal")

        local today = os.date("%Y-%m-%d")
        local expected_file = test_dir .. "/personal/" .. today .. ".md"

        vim.cmd("edit " .. test_dir .. "/random/file.txt")
        vim.wait(100)
        setup.create_today(nil, false)
        vim.wait(100)

        assert.is_true(vim.fn.filereadable(expected_file) == 1)
      end)
    end)
  end)
end)
