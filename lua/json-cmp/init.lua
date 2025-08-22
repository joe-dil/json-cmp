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

-- Default mapping configurations for common formats
local DEFAULT_MAPPINGS = {
  generic = {
    labelField = {"column", "name", "label"},
    typeField = {"fieldType.type", "type", "dataType"},
    docField = {"fieldType.options", "description", "doc"},
    fallbackDocField = {"type", "comment"},
    detailField = {"type", "category"},
    fieldsContainer = {"fields", "columns", "items"}
  },
  swagger = {
    labelField = {"name"},
    typeField = {"schema.type", "type"},
    docField = {"description"},
    fallbackDocField = {"summary"},
    detailField = {"in"},
    fieldsContainer = {"parameters"}
  },
  json_schema = {
    labelField = {"name", "key"},
    typeField = {"type"},
    docField = {"description"},
    fallbackDocField = {"title"},
    detailField = {"format"},
    fieldsContainer = {"properties"}
  }
}

-- Process configuration with defaults
function M.setup(opts)
  -- Handle simplified case where opts is just a list of paths
  if type(opts) == "table" and opts.paths ~= nil and not opts.autoRegister and not opts.sources then
    opts = { sources = {{ jsonFiles = { paths = opts.paths } }} }
  end

  opts = opts or {}
  
  -- Handle legacy single source format
  if opts.sources and opts.sources.jsonFiles and not opts.sources[1] then
    opts.sources = { opts.sources }
  end
  
  -- If no sources specified, create empty array
  if not opts.sources then
    opts.sources = {}
  end
  
  local registered_sources = {}
  local source_instances = {}
  
  -- Process each source configuration
  for i, source_config in ipairs(opts.sources) do
    local source_name = source_config.name or (opts.sourceName or "json_completions") .. (i > 1 and "_" .. i or "")
    
    -- Set defaults for this source
    local source_options = {
      autoRegister = opts.autoRegister ~= nil and opts.autoRegister or true,
      sourceName = source_name,
      priority = source_config.priority or opts.priority or 1000,
      jsonFiles = {
        paths = source_config.jsonFiles and source_config.jsonFiles.paths or source_config.paths or {},
        pattern = source_config.jsonFiles and source_config.jsonFiles.pattern or source_config.pattern or "%.json$"
      },
      watchDir = source_config.watchDir ~= nil and source_config.watchDir or true,
      watchDirPath = source_config.watchDirPath,
      formatting = {
        typeFormat = source_config.formatting and source_config.formatting.typeFormat or 
                    opts.formatting and opts.formatting.typeFormat or "`%s`",
        docFormat = source_config.formatting and source_config.formatting.docFormat or 
                   opts.formatting and opts.formatting.docFormat or "*%s*"
      }
    }
    
    -- Handle mapping configuration with presets
    local mapping_preset = source_config.preset or "generic"
    local base_mapping = DEFAULT_MAPPINGS[mapping_preset] or DEFAULT_MAPPINGS.generic
    
    source_options.mapping = {}
    for field_name, default_value in pairs(base_mapping) do
      source_options.mapping[field_name] = 
        (source_config.mapping and source_config.mapping[field_name]) or
        (opts.mapping and opts.mapping[field_name]) or
        default_value
    end
    
    -- Get file paths from directories if specified
    local processed_paths = {}
    if source_options.jsonFiles.paths and #source_options.jsonFiles.paths > 0 then
      for _, path_or_dir in ipairs(source_options.jsonFiles.paths) do
        -- Check if it's a directory
        local stat = uv.fs_stat(path_or_dir)
        if stat and stat.type == "directory" then
          -- Get all JSON files in this directory
          local dir_files = M.get_json_files(path_or_dir, source_options.jsonFiles.pattern)
          for _, file_path in ipairs(dir_files) do
            table.insert(processed_paths, file_path)
          end
        else
          -- Assume it's a file path
          table.insert(processed_paths, path_or_dir)
        end
      end
    end
    
    -- Initialize the source with processed options
    local source_instance = require('json-cmp.source')({
      name = source_options.sourceName,
      priority = source_options.priority,
      file_paths = processed_paths,
      label_field = source_options.mapping.labelField,
      type_field = source_options.mapping.typeField,
      doc_field = source_options.mapping.docField,
      fallback_doc_field = source_options.mapping.fallbackDocField,
      detail_field = source_options.mapping.detailField,
      fields_container = source_options.mapping.fieldsContainer,
      type_format = source_options.formatting.typeFormat,
      doc_format = source_options.formatting.docFormat
    })
    
    table.insert(source_instances, source_instance)
    
    -- Auto-register if requested
    if source_options.autoRegister then
      require('cmp').register_source(source_options.sourceName, source_instance)
      table.insert(registered_sources, source_options.sourceName)
    end
    
    -- Setup watch dir if enabled
    if source_options.watchDir then
      local watch_dir = source_options.watchDirPath
      if not watch_dir and #source_options.jsonFiles.paths > 0 then
        -- Use the first directory as watch dir if not specified
        local first_path = source_options.jsonFiles.paths[1]
        local stat = uv.fs_stat(first_path)
        if stat and stat.type == "directory" then
          watch_dir = first_path
        end
      end
      
      if watch_dir then
        M.setup_watch_dir(watch_dir, source_instance, source_options.jsonFiles.pattern)
      end
    end
  end
  
  -- Store reference to all instances
  source_instance = source_instances[1] -- For backward compatibility
  
  -- Return info about registered sources
  return {
    sources = source_instances,
    registered = registered_sources
  }
end

return M 