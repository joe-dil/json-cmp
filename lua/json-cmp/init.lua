-- json-cmp: JSON-based completions for nvim-cmp
-- Provides auto-completions from JSON schema files

local M = {}
local uv = vim.loop

-- Source instance for reference
local source_instance = nil

-- Setup watch functionality for a given directory
function M.setup_watch_dir(dir, source, pattern)
  pattern = pattern or '%.json$'
  
  -- Create autocmd to refresh the source when JSON files change
  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = dir .. '/*' .. pattern,
    callback = function()
      if source and source.refresh then
        source:refresh()
        vim.notify('JSON completions reloaded', vim.log.levels.INFO)
      end
    end,
  })
end

-- Helper to get all JSON files in a directory
function M.get_json_files(dir, pattern)
  pattern = pattern or '%.json$'
  local paths = {}
  local handle = uv.fs_scandir(dir)
  if handle then
    while true do
      local name, type = uv.fs_scandir_next(handle)
      if not name then break end
      if type == 'file' and name:match(pattern) then
        table.insert(paths, dir .. '/' .. name)
      end
    end
  else
    vim.notify('Failed to scan dir for JSON files: ' .. dir, vim.log.levels.ERROR)
  end
  return paths
end

-- Process configuration with defaults
function M.setup(opts)
  -- Handle simplified case where opts is just a list of paths
  if type(opts) == "table" and opts.paths ~= nil and not opts.autoRegister then
    opts = { sources = { jsonFiles = { paths = opts.paths } } }
  end

  opts = opts or {}
  
  -- Set defaults
  local options = {
    autoRegister = opts.autoRegister ~= nil and opts.autoRegister or true,  -- Default to auto-register
    sourceName = opts.sourceName or "json_completions",
    priority = opts.priority or 1000,
    sources = {
      enabled = opts.sources and opts.sources.enabled ~= nil and opts.sources.enabled or true,
      jsonFiles = {
        paths = opts.sources and opts.sources.jsonFiles and opts.sources.jsonFiles.paths or {},
        pattern = opts.sources and opts.sources.jsonFiles and opts.sources.jsonFiles.pattern or "%.json$"
      },
      watchDir = opts.sources and opts.sources.watchDir ~= nil and opts.sources.watchDir or true,  -- Default to true
      watchDirPath = opts.sources and opts.sources.watchDirPath or nil
    },
    formatting = {
      typeFormat = opts.formatting and opts.formatting.typeFormat or "`%s`",
      docFormat = opts.formatting and opts.formatting.docFormat or "*%s*"
    },
    mapping = {
      labelField = opts.mapping and opts.mapping.labelField or "column",
      typeField = opts.mapping and opts.mapping.typeField or "fieldType.type",
      docField = opts.mapping and opts.mapping.docField or "fieldType.options",
      fallbackDocField = opts.mapping and opts.mapping.fallbackDocField or "type",
      detailField = opts.mapping and opts.mapping.detailField or "type",
      fieldsContainer = opts.mapping and opts.mapping.fieldsContainer or "fields"
    }
  }
  
  -- Get file paths from directories if specified
  if options.sources.enabled and options.sources.jsonFiles.paths and #options.sources.jsonFiles.paths > 0 then
    local processed_paths = {}
    
    for _, path_or_dir in ipairs(options.sources.jsonFiles.paths) do
      -- Check if it's a directory
      local stat = uv.fs_stat(path_or_dir)
      if stat and stat.type == "directory" then
        -- Get all JSON files in this directory
        local dir_files = M.get_json_files(path_or_dir, options.sources.jsonFiles.pattern)
        for _, file_path in ipairs(dir_files) do
          table.insert(processed_paths, file_path)
        end
      else
        -- Assume it's a file path
        table.insert(processed_paths, path_or_dir)
      end
    end
    
    options.sources.jsonFiles.processed_paths = processed_paths
  else
    options.sources.jsonFiles.processed_paths = {}
  end
  
  -- Initialize the source with processed options
  source_instance = require('json-cmp.source')({
    name = options.sourceName,
    priority = options.priority,
    file_paths = options.sources.jsonFiles.processed_paths,
    label_field = options.mapping.labelField,
    type_field = options.mapping.typeField,
    doc_field = options.mapping.docField,
    fallback_doc_field = options.mapping.fallbackDocField,
    detail_field = options.mapping.detailField,
    fields_container = options.mapping.fieldsContainer,
    type_format = options.formatting.typeFormat,
    doc_format = options.formatting.docFormat
  })
  
  -- Auto-register if requested
  if options.autoRegister then
    require('cmp').register_source(options.sourceName, source_instance)
  end
  
  -- Setup watch dir if enabled
  if options.sources.watchDir then
    local watch_dir = options.sources.watchDirPath
    if not watch_dir and #options.sources.jsonFiles.paths > 0 then
      -- Use the first directory as watch dir if not specified
      local first_path = options.sources.jsonFiles.paths[1]
      local stat = uv.fs_stat(first_path)
      if stat and stat.type == "directory" then
        watch_dir = first_path
      end
    end
    
    if watch_dir then
      M.setup_watch_dir(watch_dir, source_instance, options.sources.jsonFiles.pattern)
    end
  end
  
  return source_instance
end

return M 