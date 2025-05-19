-- Source implementation for json-cmp

local cmp = require('cmp')
local uv = vim.loop
local json_decode = vim.fn.json_decode

local JsonCompletionSource = {}
JsonCompletionSource.__index = JsonCompletionSource

-- Maximum number of error notifications to display
local MAX_ERRORS = 10

-- Constructor
function JsonCompletionSource.new(opts)
    local self = setmetatable({}, JsonCompletionSource)
    self.name = opts.name or 'json_completions'
    self.priority = opts.priority or 1000
    self.file_paths = opts.file_paths or {}
    self.columns = {}
    self.file_mtimes = {}
    self.error_count = 0
    
    -- JSON field mapping configurations
    self.field_mappings = {
        -- Define which JSON field is used for completion label
        label_field = opts.label_field or "column",
        
        -- Define which JSON field is used for type information
        type_field = opts.type_field or "fieldType.type",
        
        -- Define which JSON field is used for documentation
        doc_field = opts.doc_field or "fieldType.options",
        
        -- Define which JSON field is used as a fallback for documentation
        fallback_doc_field = opts.fallback_doc_field or "type",
        
        -- Define which JSON field is used for additional details
        detail_field = opts.detail_field or "type",
        
        -- Define which JSON field contains the fields array
        fields_container = opts.fields_container or "fields"
    }
    
    -- Format strings for documentation
    self.format = {
        type_format = opts.type_format or "`%s`",
        doc_format = opts.doc_format or "*%s*"
    }
    
    self:load_columns()
    return self
end

-- Helper function to handle notifications with a limit
local function notify(self, message, level)
    if self.error_count < MAX_ERRORS then
        vim.notify(message, level)
        self.error_count = self.error_count + 1
        if self.error_count == MAX_ERRORS then
            vim.notify("Maximum error limit reached. Additional errors suppressed.", vim.log.levels.WARN)
        end
    end
end

-- Helper function to get nested fields using a dot notation path
local function get_nested_field(obj, path)
    if not path or path == "" then return nil end
    
    local parts = vim.split(path, ".", {plain = true})
    local current = obj
    
    for _, part in ipairs(parts) do
        if type(current) ~= "table" then return nil end
        current = current[part]
        if current == nil then return nil end
    end
    
    return current
end

-- Load and parse the JSON files
function JsonCompletionSource:load_columns()
    self.columns = {} -- Reset columns
    local column_map = {} -- Map of column name to { documentation, sources, type }
    self.error_count = 0 -- Reset error count for new load
    
    local label_field = self.field_mappings.label_field
    local type_field = self.field_mappings.type_field
    local doc_field = self.field_mappings.doc_field
    local fallback_doc_field = self.field_mappings.fallback_doc_field
    local detail_field = self.field_mappings.detail_field
    local fields_container = self.field_mappings.fields_container

    for _, path in ipairs(self.file_paths) do
        -- Check if file exists
        local stat = uv.fs_stat(path)
        if not stat then
            notify(self, "Failed to stat " .. path, vim.log.levels.ERROR)
        else
            local mtime = stat.mtime.sec

            -- Check if file has been modified since last load
            if not self.file_mtimes[path] or self.file_mtimes[path] < mtime then
                -- Update the last modified time
                self.file_mtimes[path] = mtime

                -- Open and read the file
                local file, err = io.open(path, "r")
                if not file then
                    notify(self, "Failed to open " .. path .. ": " .. err, vim.log.levels.ERROR)
                else
                    local content = file:read("*a")
                    file:close()

                    -- Attempt to decode JSON
                    local success, data = pcall(json_decode, content)
                    if not success then
                        notify(self, "Failed to parse JSON in " .. path .. ": " .. data, vim.log.levels.ERROR)
                    else
                        -- Extract fields from the configured container
                        local fields = get_nested_field(data, fields_container)
                        if fields and type(fields) == 'table' then
                            for _, field in ipairs(fields) do
                                local column_name = get_nested_field(field, label_field)
                                
                                if column_name and type(column_name) == 'string' then
                                    -- Initialize the column entry if it doesn't exist
                                    if not column_map[column_name] then
                                        column_map[column_name] = {
                                            documentation = '',
                                            sources = {},
                                            -- Get type information from the configured path
                                            type = get_nested_field(field, type_field) or ''
                                        }
                                    end

                                    -- Append the current source type
                                    local detail_value = get_nested_field(data, detail_field)
                                    if detail_value and type(detail_value) == 'string' then
                                        table.insert(column_map[column_name].sources, detail_value)
                                    else
                                        table.insert(column_map[column_name].sources, "UnknownType")
                                    end

                                    -- Update documentation based on configured doc field
                                    local doc_value = get_nested_field(field, doc_field)
                                    if doc_value then
                                        if type(doc_value) == 'table' then
                                            column_map[column_name].documentation = table.concat(doc_value, ', ')
                                        elseif type(doc_value) == 'string' then
                                            column_map[column_name].documentation = doc_value
                                        end
                                    end

                                    -- Fallback: if documentation is empty but there's a fallback field
                                    if column_map[column_name].documentation == '' then
                                        local fallback_value = get_nested_field(field, fallback_doc_field)
                                        if fallback_value and type(fallback_value) == 'string' then
                                            column_map[column_name].documentation = fallback_value
                                        end
                                    end
                                else
                                    notify(self,
                                    "Invalid field entry in " .. path ..
                                    ", missing '" .. label_field .. "' or it is not a string.",
                                    vim.log.levels.WARN
                                    )
                                end
                            end
                        else
                            notify(self, "No '" .. fields_container .. "' array found in " .. path, vim.log.levels.WARN)
                        end
                    end
                end
            end
        end
    end

    for column, info in pairs(column_map) do
        local sources_str = table.concat(info.sources, ', ')
        local doc_parts = {}
        
        -- Add type information if available
        if info.type and #info.type > 0 then
            table.insert(doc_parts, string.format(self.format.type_format, info.type))
        end

        -- If documentation is non-empty, add it with formatting
        if info.documentation and #info.documentation > 0 then
            table.insert(doc_parts, string.format(self.format.doc_format, info.documentation))
        end

        local documentation = table.concat(doc_parts, "\n")

        table.insert(self.columns, {
            label = column,
            kind = cmp.lsp.CompletionItemKind.Field,
            documentation = documentation,
            detail = sources_str,
        })
    end
end

-- Refresh method to reload the JSON files (called by autocmd)
function JsonCompletionSource:refresh()
    self:load_columns()
end

-- Required 'complete' method
function JsonCompletionSource:complete(_, callback)
    callback({
        items = self.columns,
        isIncomplete = false,
    })
end

-- Return a constructor function
return function(opts)
    return JsonCompletionSource.new(opts)
end 