# json-cmp

A Neovim plugin that provides completion items for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) based on column definitions in JSON schema files.

## Features

- Parse column definitions from JSON schema files
- Provide completion items with proper documentation
- Auto-refresh when JSON files are modified
- Configurable file paths and pattern matching
- Customizable JSON field mapping for flexible schema support
- Modern configuration API with easy-to-use defaults
- Simplified configuration with sensible defaults

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "joe-dil/json-cmp",
  dependencies = {
    "hrsh7th/nvim-cmp",
  },
  opts = {
    paths = { vim.fn.stdpath("config") .. "/lua/data/completions" },
  },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "joe-dil/json-cmp",
  requires = { "hrsh7th/nvim-cmp" },
  config = function()
    require("json-cmp").setup({
      paths = { vim.fn.stdpath("config") .. "/lua/data/completions" },
    })
  end
}
```

## JSON Schema Format

The plugin expects JSON files with the following structure by default, but all field paths are configurable:

```json
{
  "type": "SourceType",
  "fields": [
    {
      "column": "column_name",
      "fieldType": {
        "type": "string",
        "options": ["option1", "option2"]
      }
    },
    {
      "column": "another_column",
      "fieldType": {
        "type": "integer"
      }
    }
  ]
}
```

## Configuration Options

### Simplified Configuration

You can use the simplified configuration option by just providing the paths to your JSON files:

```lua
require("json-cmp").setup({
  paths = { "/path/to/dir" },
})
```

This will use the following sensible defaults:
- Auto-register with nvim-cmp
- Watch for file changes in the provided directories
- Use standard JSON schema format
- Set reasonable formatting and field mappings

### Detailed Configuration

For more control, you can use the full configuration:

```lua
require("json-cmp").setup({
  -- Core settings
  autoRegister = true,            -- Auto-register with nvim-cmp
  sourceName = "json_completions", -- Name for the completion source
  priority = 1000,                -- Priority in nvim-cmp
  
  -- Source settings
  sources = {
    enabled = true,               -- Enable/disable the source
    jsonFiles = {
      paths = { "/path/to/dir" }, -- Paths to dirs or files
      pattern = "%.json$",        -- Pattern for JSON files
    },
    watchDir = true,              -- Watch for file changes
    watchDirPath = nil,           -- Custom dir to watch (defaults to first in paths)
  },
  
  -- Formatting settings
  formatting = {
    typeFormat = "`%s`",          -- Format for type display
    docFormat = "*%s*",           -- Format for documentation
  },
  
  -- Field mapping
  mapping = {
    labelField = "column",        -- Field for completion text
    typeField = "fieldType.type", -- Field for type information
    docField = "fieldType.options", -- Field for documentation
    fallbackDocField = "type",    -- Fallback doc field
    detailField = "type",         -- Field for detail display
    fieldsContainer = "fields",   -- Container for fields array
  },
})
```

## Example Configurations

### Simplified Setup

```lua
-- Get all completion files from a directory
local completions_dir = vim.fn.stdpath("config") .. "/lua/data/completions"

require("json-cmp").setup({
  paths = { completions_dir },
})
```

### Basic Setup

```lua
-- Get all completion files from a directory
local completions_dir = vim.fn.stdpath("config") .. "/lua/data/completions"

require("json-cmp").setup({
  autoRegister = true,
  sources = {
    jsonFiles = {
      paths = { completions_dir },
    },
    watchDir = true,
  },
})
```

### Custom JSON Schema Format

```lua
require("json-cmp").setup({
  autoRegister = true,
  sourceName = "db_columns",
  sources = {
    jsonFiles = {
      paths = { "/path/to/db_schemas" },
    },
  },
  -- Custom field mappings for a different JSON structure
  mapping = {
    labelField = "name",          -- Use "name" field as the completion label
    typeField = "dataType",       -- Get type from "dataType" field
    docField = "description",     -- Use "description" field for documentation
    fallbackDocField = "comment", -- Fallback to "comment" field
    detailField = "table",        -- Show the "table" field in the detail
    fieldsContainer = "columns",  -- Look for columns in the "columns" array
  },
  -- Custom formatting
  formatting = {
    typeFormat = "Type: %s",      -- Custom format for type display
    docFormat = "%s",             -- No special formatting for documentation
  },
})
```

This configuration would work with a JSON schema like:

```json
{
  "table": "Users",
  "columns": [
    {
      "name": "id",
      "dataType": "int",
      "description": "Primary key"
    },
    {
      "name": "username",
      "dataType": "varchar",
      "description": "User's login name",
      "comment": "Must be unique"
    }
  ]
}
```

### Multiple Completion Sources

```lua
-- Standard column completions
local columns_source = require("json-cmp").setup({
  sourceName = "columns",
  sources = {
    jsonFiles = {
      paths = { vim.fn.stdpath("config") .. "/lua/data/column_schemas" },
    },
  },
})

-- Register with nvim-cmp
require("cmp").register_source("columns", columns_source)

-- Database schema completions with different format
local db_source = require("json-cmp").setup({
  sourceName = "db_fields",
  sources = {
    jsonFiles = {
      paths = { vim.fn.stdpath("config") .. "/lua/data/db_schemas" },
    },
  },
  mapping = {
    labelField = "name",
    typeField = "dataType",
    fieldsContainer = "columns",
  },
})

-- Register second source
require("cmp").register_source("db_fields", db_source)
```

## Helper Functions

```lua
-- Get all JSON files in a directory
local json_files = require("json-cmp").get_json_files("/path/to/dir", "%.json$")

-- Setup auto-reload for a directory
local source = require("json-cmp").setup({...})
require("json-cmp").setup_watch_dir("/path/to/dir", source, "%.json$")
```

## Repository

This plugin is available at [https://github.com/joe-dil/json-cmp](https://github.com/joe-dil/json-cmp)

## License

MIT 