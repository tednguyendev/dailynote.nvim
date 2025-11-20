# dailynote.nvim

A Neovim plugin for managing daily notes across workspaces.

https://github.com/user-attachments/assets/fcb55eda-de7d-4f63-884e-3cbe9a6afd92

https://github.com/user-attachments/assets/f87247d4-d34e-40f4-9a65-96ed430ddf82

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use 'tednguyendev/dailynote.nvim'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
  'tednguyendev/dailynote.nvim',
  config = function()
    require('dailynote').setup({
      workspaces = {
        {
          name = "work"
        }
      },
    })
  end
}
```

## Features

- Manage multiple note workspaces
- Create daily notes with customizable templates
- Automatically carry over incomplete tasks
- Navigate between daily notes
- Support for recurring tasks

## Commands

- `:DailyNote [workspace]` - Create or open today's note
- `:DailyNoteRepeat [workspace]` - Create or open today's note with content from previous note
- `:TomorrowNote [workspace]` - Create or open tomorrow's note
- `:TomorrowNoteRepeat [workspace]` - Create or open tomorrow's note with content from today's note
- `:PreviousDailyNote [workspace]` - Navigate to the previous daily note
- `:NextDailyNote [workspace]` - Navigate to the next daily note

## Configuration

### Configuration

```lua
require('dailynote').setup({
  workspaces = {
    {
      name = "personal",
    },
    {
      name = "work",
      path = "~/work/notes/daily",
      date_format = "%Y-%m-%d",
      default = true,
      template = "# {{date}}\n\n## Tasks\n\n## Notes\n"
    },
  },
  recur_words = { "daily:" },
  done_markers = { "- [x]" }
})
```

## Credits

Thanks to [ellisonleao](https://github.com/ellisonleao) for creating the [nvim-plugin-template](https://github.com/ellisonleao/nvim-plugin-template).
