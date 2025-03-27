# Presenterm.nvim

A Neovim plugin to detect and launch [Presenterm](https://github.com/mzunino/presenterm) presentations in an external terminal window.

## Features

- Automatically detects Presenterm files (`.presenterm`, `.pterm`, and compatible Markdown files)
- Launches presentations in your preferred terminal
- Supports custom terminal commands with placeholders
- Automatically cleans up processes when closing buffers or exiting Neovim

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "mzunino/presenterm.nvim",
  config = function()
    require("presenterm").setup({
      -- your configuration options here
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "mzunino/presenterm.nvim",
  config = function()
    require("presenterm").setup()
  end
}
```

## Configuration

The plugin comes with these default settings:

```lua
require("presenterm").setup({
  -- Presenterm executable path (optional, can be nil)
  executable = "presenterm", -- set to nil or "" to use only terminal_cmd

  -- File patterns that should be recognized as Presenterm files
  patterns = {
    "*.presenterm",
    "*.pterm",
    "*.md", -- Markdown files can be Presenterm files too
  },

  -- Auto detection and launch
  auto_launch = false,

  -- Custom terminal command with placeholders
  -- {cmd} = The presenterm command with file path
  -- {file} = The file path
  -- {title} = The file title (filename without path)
  terminal_cmd = nil,
})
```

### Configuration Examples

#### Auto-launch with default terminal:

```lua
require("presenterm").setup({
  auto_launch = true
})
```

#### Use a specific terminal (kitty):

```lua
require("presenterm").setup({
  terminal_cmd = "kitty --title 'Presenterm: {title}' {cmd}"
})
```

#### Launch using tmux:

```lua
require("presenterm").setup({
  terminal_cmd = "tmux new-window -n 'Presenterm' '{cmd}'"
})
```

#### Custom launcher without presenterm:

```lua
require("presenterm").setup({
  executable = nil,
  terminal_cmd = "my-custom-launcher {file}"
})
```

## Usage

### Commands

- `:PresentermLaunch` - Launch the current buffer in Presenterm

### File Detection

Files are detected as Presenterm presentations if:

1. They have a `.presenterm` or `.pterm` extension
2. They are Markdown (`.md`) files with one of the following:
   - YAML frontmatter containing a "presenter:" field
   - Horizontal rules (`---` or `%`) used as slide separators

## Development

### Testing

The plugin includes tests using the Busted framework. To run tests:

```bash
cd /path/to/presenterm.nvim
nvim --headless -c "lua require('plenary.test_harness').test_directory('test', {minimal_init = 'test/minimal_init.lua'})"
```

## License

MIT
