# json-cmp

nvim-cmp source for completing values from local JSON files.

## Installation

```lua
-- lazy.nvim
{
  "hrsh7th/nvim-cmp",
  dependencies = {
    { "joe-dil/json-cmp" },
    -- ... other deps
  },
  config = function()
    local cmp = require("cmp")

    local json_completions = require("json_completions")({
      directory = vim.fn.stdpath("config") .. "/lua/data/completions",
    })

    cmp.register_source("json_completions", json_completions)

    cmp.setup({
      sources = {
        { name = "json_completions", keyword_length = 3, max_item_count = 9 },
        -- ... other sources
      },
    })
  end,
}
```

## Options

| Option | Type | Description |
|--------|------|-------------|
| `directory` | `string` | Path to a directory — all `.json` files inside are loaded |
| `file_paths` | `string[]` | Explicit list of `.json` file paths |
| `name` | `string` | Source name (default: `"json_completions"`) |
| `priority` | `number` | Completion priority (default: `1000`) |

## License

MIT
