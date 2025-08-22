# json-cmp

Neovim auto-completion for JSON schemas. Works with Swagger/OpenAPI docs, database schemas, and custom JSON formats.

## Installation

```lua
{
  "joe-dil/json-cmp",
  dependencies = { "hrsh7th/nvim-cmp" },
  opts = { paths = { "/path/to/json" } }
}
```

## Quick Start

### Single Directory
```lua
require("json-cmp").setup({
  paths = { "/path/to/json/files" }
})
```

### Multiple Sources with Presets
```lua
require("json-cmp").setup({
  sources = {
    { name = "swagger", paths = { "/api/docs" }, preset = "swagger" },
    { name = "db", paths = { "/db/schemas" }, preset = "generic" }
  }
})
```

## Presets

- **`swagger`**: Swagger/OpenAPI parameters (`name`, `description`, `schema.type`)
- **`generic`**: Standard schemas (`column`, `fieldType.type`, `fieldType.options`)  
- **`json_schema`**: JSON Schema properties (`name`, `type`, `description`)

## Swagger Example

JSON:
```json
{
  "paths": {
    "/users": {
      "get": {
        "parameters": [
          {
            "name": "limit",
            "description": "Max results",
            "schema": { "type": "integer" }
          }
        ]
      }
    }
  }
}
```

Config:
```lua
require("json-cmp").setup({
  sources = {
    { name = "api", paths = { "/api/swagger" }, preset = "swagger" }
  }
})
```

## Advanced Configuration

### Custom Field Mappings
```lua
require("json-cmp").setup({
  sources = {
    {
      name = "custom",
      paths = { "/path/to/schemas" },
      mapping = {
        labelField = {"name", "column"},
        typeField = {"dataType", "type"},
        docField = {"description"},
        fieldsContainer = {"columns", "fields"}
      }
    }
  }
})
```

### Manual Registration
```lua
local result = require("json-cmp").setup({
  autoRegister = false,
  sources = {
    { name = "my_source", paths = { "/path" } }
  }
})

-- Register manually
require("cmp").register_source("my_source", result.sources[1])
```

## License

MIT