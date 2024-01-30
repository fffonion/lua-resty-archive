local ffi = require("ffi")

local clib = require "resty.archive.clib"
local lib = clib.clib
local format_error = clib.format_error

local _M = {
  format_error = format_error,
}
local writer_mt = {__index = _M}

local function write_close(ctx)
  lib.archive_write_close(ctx)
  lib.archive_write_free(ctx)
end

local function writer_new(format, filter)
  local ctx = lib.archive_write_new()
  if ctx == nil then
    return nil, "failed to create writer"
  end

  ffi.gc(ctx, write_close)

  filter = filter or "gzip"
  format = format or "zip"

  if lib.archive_write_add_filter_by_name(ctx, filter) ~= lib.ARCHIVE_OK then
    return nil, "No such filter: " .. filter
  end

  if lib.archive_write_set_format_by_name(ctx, format) ~= lib.ARCHIVE_OK then
    return nil, "No such format: " .. format
  end

  return setmetatable({
    ctx = ctx,
  }, writer_mt), nil
end

-- local function archive_write(filename, entries)
--   local a = lib.archive_write_new()
--   lib.archive_write_add_filter_gzip(a)
--   lib.archive_write_set_format_zip(a)
--   lib.archive_write_open_filename(a, filename)

--   for _, entry in ipairs(entries) do
--     local e = lib.archive_entry_new()
--     lib.archive_entry_set_size(e, entry.size)
--     lib.archive_write_header(a, e)
--     if entry.data then
--       lib.archive_write_data(a, entry.data, #entry.data)
--     end
--   end

--   lib.archive_write_free(a)
-- end

function _M.open_filename(filename, blocksize, format, filter)
  if type(filename) ~= "string" then
    return false, "writer:open_filename: except a string at #1"
  end

  local self, err = writer_new(format, filter)
  if not self then
    return nil, "writer.open_filename: " .. err
  end

  if lib.archive_write_open_filename(self.ctx, filename, blocksize or 10240) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("writer:open_filename")
  end

  return self
end

function _M.open_memory(buff, format, filter)
  if type(buff) ~= "string" then
    return false, "writer:open_memory: except a string at #1"
  end

  local self, err = writer_new(format, filter)
  if not self then
    return nil, "writer.open_memory: " .. err
  end

  local buf_ptr = ffi.cast("const void *", buff)
  if lib.archive_write_open_memory(self.ctx, buf_ptr, #buff) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("writer:open_memory")
  end

  return self
end

return _M