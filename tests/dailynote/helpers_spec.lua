local helpers = require("dailynote.helpers")

describe("Helpers Module", function()
  local test_dir
  local config

  before_each(function()
    test_dir = vim.fn.tempname()
    os.execute("mkdir " .. test_dir)
    config = {
      workspaces = {
        { name = "test",     path = test_dir },
        { name = "work",     path = test_dir .. "/work" },
        { name = "personal", path = test_dir .. "/personal", default = true },
      },
      done_markers = { "- [x] " },
      recur_words = { "recur: " },
    }
  end)

  after_each(function()
    os.execute("rm -r " .. test_dir)
  end)

  describe("get_ws function", function()
    describe("given workspace name provided", function()
      it("returns workspace by name", function()
        local ws = helpers.get_ws("test", config)
        assert.are.equal("test", ws.name)
        assert.are.equal(test_dir, ws.path)
      end)

      it("returns nil for non-existent workspace", function()
        local ws = helpers.get_ws("nonexistent", config)
        assert.is_nil(ws)
      end)
    end)

    describe("given no workspace name provided", function()
      describe("given current file in workspace", function()
        it("returns current workspace based on file path", function()
          os.execute("mkdir " .. test_dir .. "/work")
          vim.cmd("edit " .. test_dir .. "/work/test.md")
          vim.wait(100)
          local ws = helpers.get_ws(nil, config)
          assert.are.equal("work", ws.name)
        end)
      end)

      describe("given current file not in workspace", function()
        it("returns default workspace", function()
          local ws = helpers.get_ws(nil, config)
          assert.are.equal("personal", ws.name)
        end)
      end)
    end)
  end)

  describe("file_exists function", function()
    describe("given existing file", function()
      it("returns true", function()
        local test_file = test_dir .. "/test.txt"
        vim.fn.writefile({ "content" }, test_file)
        assert.is_true(helpers.file_exists(test_file))
      end)
    end)

    describe("given non-existing file", function()
      it("returns false", function()
        assert.is_false(helpers.file_exists(test_dir .. "/nonexistent.txt"))
      end)
    end)
  end)

  describe("open_file function", function()
    it("opens file in editor", function()
      local test_file = test_dir .. "/test.md"
      vim.fn.writefile({ "content" }, test_file)

      helpers.open_file(test_file)

      assert.are.equal(test_file, vim.fn.expand("%:p"))
    end)
  end)

  describe("filter_content function", function()
    describe("given done tasks without recur", function()
      it("removes done tasks", function()
        local content = { "- [x] done task", "- [ ] todo task" }
        local filtered = helpers.filter_content(content, config)
        assert.are.same({ "- [ ] todo task" }, filtered)
      end)
    end)

    describe("given done tasks with recur", function()
      it("keeps recurring done tasks and removes done marker", function()
        local content = { "- [x] done task recur: daily", "- [x] done task" }
        local filtered = helpers.filter_content(content, config)
        assert.are.same({ "done task recur: daily" }, filtered)
      end)
    end)

    describe("given non-done tasks", function()
      it("keeps all non-done content", function()
        local content = { "- [ ] todo task", "regular text" }
        local filtered = helpers.filter_content(content, config)
        assert.are.same({ "- [ ] todo task", "regular text" }, filtered)
      end)
    end)
  end)

  describe("normalize_ws function", function()
    describe("given minimal workspace config", function()
      it("normalizes workspace with defaults", function()
        local ws = { name = "test" }
        local normalized = helpers.normalize_ws(ws)
        assert.are.equal("test", normalized.name)
        assert.are.equal(vim.fn.stdpath("data") .. "/dailynote/test", normalized.path)
        assert.are.equal("%Y-%m-%d", normalized.date_format)
        assert.is_false(normalized.default)
        assert.are.equal("# {{date}}\n\n## Tasks\n\n## Notes\n", normalized.template)
      end)
    end)

    describe("given complete workspace config", function()
      it("preserves provided values", function()
        local ws = {
          name = "custom",
          path = "/custom/path",
          date_format = "%d-%m-%Y",
          default = true,
          template = "Custom template",
        }
        local normalized = helpers.normalize_ws(ws)
        assert.are.equal("custom", normalized.name)
        assert.are.equal("/custom/path", normalized.path)
        assert.are.equal("%d-%m-%Y", normalized.date_format)
        assert.is_true(normalized.default)
        assert.are.equal("Custom template", normalized.template)
      end)
    end)
  end)

  describe("apply_template function", function()
    describe("given workspace with template", function()
      it("applies template with date substitution", function()
        local ws = { template = "# {{date}}\n\nContent" }
        local filename = test_dir .. "/2023-12-25.md"
        helpers.apply_template(ws, filename)

        local content = vim.fn.readfile(filename)
        assert.are.equal("# 2023-12-25", content[1])
        assert.are.equal("", content[2])
        assert.are.equal("Content", content[3])
      end)
    end)

    describe("given workspace without template", function()
      it("does nothing", function()
        local ws = {}
        local filename = test_dir .. "/test.md"
        vim.fn.writefile({ "original" }, filename)

        helpers.apply_template(ws, filename)

        local content = vim.fn.readfile(filename)
        assert.are.same({ "original" }, content)
      end)
    end)
  end)

  describe("get_current_file function", function()
    it("returns current file path", function()
      local test_file = test_dir .. "/current.md"
      vim.fn.writefile({ "content" }, test_file)
      vim.cmd("edit " .. test_file)

      assert.are.equal(test_file, helpers.get_current_file())
    end)
  end)

  describe("get_files function", function()
    it("returns markdown files in workspace", function()
      local ws = { path = test_dir }
      vim.fn.writefile({ "content" }, test_dir .. "/file1.md")
      vim.fn.writefile({ "content" }, test_dir .. "/file2.md")
      vim.fn.writefile({ "content" }, test_dir .. "/file.txt")

      local files = helpers.get_files(ws)
      table.sort(files)

      assert.are.equal(2, #files)
      assert.is_true(vim.endswith(files[1], "file1.md"))
      assert.is_true(vim.endswith(files[2], "file2.md"))
    end)
  end)

  describe("create_tmr_note function", function()
    describe("given no today file", function()
      it("creates tomorrow note with template", function()
        local ws = {
          path = test_dir,
          template = "# {{date}}\n\nTasks"
        }
        local tomorrow_file = test_dir .. "/tomorrow.md"

        helpers.create_tmr_note(ws, tomorrow_file, false, config)

        local content = vim.fn.readfile(tomorrow_file)
        assert.are.equal("# tomorrow", content[1])
        assert.are.equal("", content[2])
        assert.are.equal("Tasks", content[3])
      end)
    end)

    describe("given today file exists and should_recur is true", function()
      it("repeats today's content", function()
        local ws = { path = test_dir }
        local today_file = test_dir .. "/" .. os.date("%Y-%m-%d") .. ".md"
        local tomorrow_file = test_dir .. "/tomorrow.md"

        vim.fn.writefile({ "- [x] done recur: daily", "- [ ] todo" }, today_file)

        local test_config = {
          done_markers = { "- [x] " },
          recur_words = { "recur: " },
        }

        helpers.create_tmr_note(ws, tomorrow_file, true, test_config)

        local content = vim.fn.readfile(tomorrow_file)
        assert.are.same({ "done recur: daily", "- [ ] todo" }, content)
      end)
    end)
  end)

  describe("find_latest_file function", function()
    describe("given files before today", function()
      it("finds most recent file", function()
        local files = {
          test_dir .. "/2023-12-20.md",
          test_dir .. "/2023-12-22.md",
          test_dir .. "/2023-12-21.md",
        }
        for _, file in ipairs(files) do
          vim.fn.writefile({ "content" }, file)
        end

        local latest = helpers.find_latest_file(files, "2023-12-25")
        assert.are.equal(test_dir .. "/2023-12-22.md", latest)
      end)
    end)

    describe("given no files before today", function()
      it("returns nil", function()
        local files = { test_dir .. "/2023-12-26.md" }
        vim.fn.writefile({ "content" }, files[1])

        local latest = helpers.find_latest_file(files, "2023-12-25")
        assert.is_nil(latest)
      end)
    end)
  end)

  describe("find_next_file function", function()
    describe("given files after current", function()
      it("finds next file", function()
        local files = {
          test_dir .. "/2023-12-20.md",
          test_dir .. "/2023-12-22.md",
          test_dir .. "/2023-12-24.md",
        }

        local next_file = helpers.find_next_file(files, test_dir .. "/2023-12-21.md")
        assert.are.equal(test_dir .. "/2023-12-22.md", next_file)
      end)
    end)

    describe("given no files after current", function()
      it("returns nil", function()
        local files = { test_dir .. "/2023-12-20.md" }

        local next_file = helpers.find_next_file(files, test_dir .. "/2023-12-25.md")
        assert.is_nil(next_file)
      end)
    end)
  end)

  describe("find_previous_file function", function()
    describe("given files before current", function()
      it("finds previous file", function()
        local files = {
          test_dir .. "/2023-12-20.md",
          test_dir .. "/2023-12-22.md",
          test_dir .. "/2023-12-24.md",
        }

        local prev_file = helpers.find_previous_file(files, test_dir .. "/2023-12-23.md")
        assert.are.equal(test_dir .. "/2023-12-22.md", prev_file)
      end)
    end)

    describe("given no files before current", function()
      it("returns nil", function()
        local files = { test_dir .. "/2023-12-25.md" }

        local prev_file = helpers.find_previous_file(files, test_dir .. "/2023-12-20.md")
        assert.is_nil(prev_file)
      end)
    end)
  end)

  describe("create_directory function", function()
    describe("given directory doesn't exist", function()
      it("creates directory", function()
        local new_dir = test_dir .. "/new_directory"
        helpers.create_directory(new_dir)
        assert.are.equal(1, vim.fn.isdirectory(new_dir))
      end)
    end)

    describe("given directory exists", function()
      it("does nothing", function()
        helpers.create_directory(test_dir)
        assert.are.equal(1, vim.fn.isdirectory(test_dir))
      end)
    end)
  end)

  describe("create_today_note function", function()
    describe("given no previous file", function()
      it("creates today note with template", function()
        local ws = {
          name = "test",
          path = test_dir,
          template = "# {{date}}\n\nTasks"
        }
        local today_file = test_dir .. "/today.md"
        local today_date = "2023-12-25"

        helpers.create_today_note(ws, today_file, today_date, false, config)

        local content = vim.fn.readfile(today_file)
        assert.are.equal("# today", content[1])
        assert.are.equal("", content[2])
        assert.are.equal("Tasks", content[3])
      end)
    end)

    describe("given previous file exists and should_recur is true", function()
      it("repeats content from previous day", function()
        local ws = { name = "test", path = test_dir }
        local yesterday_file = test_dir .. "/2023-12-24.md"
        local today_file = test_dir .. "/today.md"
        local today_date = "2023-12-25"

        vim.fn.writefile({ "- [x] done recur: daily", "- [ ] todo" }, yesterday_file)

        helpers.create_today_note(ws, today_file, today_date, true, config)

        local content = vim.fn.readfile(today_file)
        assert.are.same({ "done recur: daily", "- [ ] todo" }, content)
      end)
    end)

    describe("given previous file has no recurring content", function()
      it("creates empty file with template", function()
        local ws = {
          name = "test",
          path = test_dir,
          template = "# {{date}}\n\nTasks"
        }
        local yesterday_file = test_dir .. "/2023-12-24.md"
        local today_file = test_dir .. "/today.md"
        local today_date = "2023-12-25"

        vim.fn.writefile({ "- [x] done task" }, yesterday_file)

        helpers.create_today_note(ws, today_file, today_date, true, config)

        local content = vim.fn.readfile(today_file)
        assert.are.equal("# today", content[1])
        assert.are.equal("", content[2])
        assert.are.equal("Tasks", content[3])
      end)
    end)
  end)
end)
