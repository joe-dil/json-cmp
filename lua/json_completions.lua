local cmp = require('cmp')
local uv = vim.loop
local json_decode = vim.fn.json_decode

-- Helper function to scan directory for JSON files
local function get_json_file_paths(dir)
    local paths = {}
    local handle = uv.fs_scandir(dir)
    if handle then
        while true do
            local name, type = uv.fs_scandir_next(handle)
            if not name then
                break
            end
            if type == "file" and name:match("%.json$") then
                table.insert(paths, dir .. "/" .. name)
            end
        end
    end
    return paths
end

local CustomColumnsSource = {}
CustomColumnsSource.__index = CustomColumnsSource

-- Maximum number of error notifications to display
local MAX_ERRORS = 10

-- Constructor
function CustomColumnsSource.new(opts)
    local self = setmetatable({}, CustomColumnsSource)
    self.name = opts.name or 'columns'
    self.priority = opts.priority or 1000
    self.error_count = 0

    -- Handle both directory string and file_paths array
    if opts.directory and type(opts.directory) == 'string' then
        self.directory = opts.directory
        self.file_paths = get_json_file_paths(opts.directory)
    elseif opts.file_paths and type(opts.file_paths) == 'table' then
        self.file_paths = opts.file_paths
        self.directory = nil
    else
        self.file_paths = {}
        self.directory = nil
    end

    self.columns = {}
    self.file_mtimes = {}
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

-- Load and parse the JSON files
function CustomColumnsSource:load_columns()
    self.columns = {} -- Reset columns
    local column_map = {} -- Map of column name to { documentation, sources, type }
    self.error_count = 0 -- Reset error count for new load

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
                        -- Extract 'column' values from 'fields'
                        if data.fields and type(data.fields) == 'table' then
                            for _, field in ipairs(data.fields) do
                                if field.column and type(field.column) == 'string' then
                                    -- Initialize the column entry if it doesn't exist
                                    if not column_map[field.column] then
                                        column_map[field.column] = {
                                            documentation = '',
                                            sources = {},
                                            -- Store in 'type' to match `detail = info.type` below
                                            type = (field.fieldType and field.fieldType.type) or ''
                                        }
                                    end

                                    -- Append the current source type
                                    if data.type and type(data.type) == 'string' then
                                        table.insert(column_map[field.column].sources, data.type)
                                    else
                                        table.insert(column_map[field.column].sources, "UnknownType")
                                    end

                                    -- Update documentation based on field.fieldType
                                    if field.fieldType and type(field.fieldType) == 'table' then
                                        if field.fieldType.options and type(field.fieldType.options) == 'table' then
                                            column_map[field.column].documentation =
                                            table.concat(field.fieldType.options, ', ')
                                        elseif field.fieldType.name and type(field.fieldType.name) == 'string' then
                                            -- column_map[field.column].documentation = field.fieldType.name
                                            column_map[field.column].documentation = ''
                                        end
                                    end

                                    -- Fallback: if documentation is empty but there's a known field name/type
                                    if column_map[field.column].documentation == '' and field.type then
                                        -- Use `field.type` as a last resort
                                        column_map[field.column].documentation = field.type
                                    end
                                else
                                    notify(self,
                                    "Invalid field entry in " .. path ..
                                    ", missing 'column' or 'column' is not a string.",
                                    vim.log.levels.WARN
                                    )
                                end
                            end
                        else
                            notify(self, "No 'fields' array found in " .. path, vim.log.levels.WARN)
                        end
                    end
                end
            end
        end
    end

    for column, info in pairs(column_map) do
        local sources_str = table.concat(info.sources, ', ')
        local doc_parts = { string.format("`%s`", info.type) }

        -- If documentation is non-empty, add it (in italics) as a new line
        if info.documentation and #info.documentation > 0 then
            table.insert(doc_parts, string.format("*%s*", info.documentation))
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
function CustomColumnsSource:refresh()
    -- Re-scan directory if we have one
    if self.directory then
        self.file_paths = get_json_file_paths(self.directory)
    end
    self:load_columns()
end

-- Required 'complete' method
function CustomColumnsSource:complete(_, callback)
    callback({
        items = self.columns,
        isIncomplete = false,
    })
end

-- Return a constructor function
return function(opts)
    return CustomColumnsSource.new(opts)
end

