local ffi = require("ffi")

local clib = require "resty.archive.clib"
local entry_lib = require "resty.archive.entry"
local lib = clib.clib
local format_error = clib.format_error

local _M = {
  format_error = format_error,
}
local writer_mt = {__index = _M}

local entry_tmp

local function writer_close(ctx)
  if ctx == nil then
    return
  end

  lib.archive_write_close(ctx)
  lib.archive_write_free(ctx)
end

local function writer_new(format, filter, options)
  local ctx = lib.archive_write_new()
  if ctx == nil then
    return nil, "failed to create writer"
  end

  ffi.gc(ctx, writer_close)

  format = format or "zip"

  if filter then
    if lib.archive_write_add_filter_by_name(ctx, filter) ~= lib.ARCHIVE_OK then
      return nil, "No such filter: " .. filter
    end
  end

  if lib.archive_write_set_format_by_name(ctx, format) ~= lib.ARCHIVE_OK then
    return nil, "No such format: " .. format
  end

  if options then
    if lib.archive_write_set_options(ctx, options) ~= lib.ARCHIVE_OK then
      return nil, "failed to set options: " .. options
    end
  end

  return setmetatable({
    ctx = ctx,
  }, writer_mt), nil
end

function _M.open_filename(filename, format, filter, options)
  if type(filename) ~= "string" then
    return false, "writer:open_filename: except a string at #1"
  end

  local self, err = writer_new(format, filter, options)
  if not self then
    return nil, "writer.open_filename: " .. err
  end

  if lib.archive_write_open_filename(self.ctx, filename) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("writer:open_filename")
  end

  return self
end

function _M.open_memory(buff, format, filter, options)
  if type(buff) ~= "string" then
    return false, "writer:open_memory: except a string at #1"
  end

  local self, err = writer_new(format, filter, options)
  if not self then
    return nil, "writer.open_memory: " .. err
  end

  local buf_ptr = ffi.cast("const void *", buff)
  if lib.archive_write_open_memory(self.ctx, buf_ptr, #buff) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("writer:open_memory")
  end

  return self
end

function _M:write_entry(data, entry)
  if type(data) ~= "string" then
    return false, "expect a string at #1"
  elseif not entry_lib.istype(entry) then
    return false, "expect an entry instance at #2"
  end

  local _, err = lib.archive_entry_set_size(entry.ctx, #data)
  if err then
    return false, self:format_error("writer:write_entry:archive_entry_set_size")
  end

  _, err = lib.archive_write_header(self.ctx, entry.ctx)
  if err then
    return false, self:format_error("writer:write_entry:archive_write_header")
  end

  _, err = lib.archive_write_data(self.ctx, data, #data)
  if err then
    return false, self:format_error("writer:write_entry:archive_write_data")
  end

  return true
end

function _M:write_data(data, path)
  if type(data) ~= "string" then
    return false, "expect a string at #1"
  elseif type(path) ~= "string" then
    return false, "expect a string at #2"
  end

  local _, err
  if not entry_tmp then
    entry_tmp, err = entry_lib.new()
  else
    _, err = entry_tmp:clear()
  end

  if err then
    return false, "writer:write_data: " .. err
  end

  _, err = lib.archive_entry_set_pathname(entry_tmp.ctx, path)
  if err then
    return false, self:format_error("writer:write_data:archive_entry_set_pathname")
  end

  _, err = lib.archive_entry_set_filetype(entry_tmp.ctx, lib.AE_IFREG)
  if err then
    return false, self:format_error("writer:write_data:archive_entry_set_filetype")
  end

  _, err = lib.archive_entry_set_perm(entry_tmp.ctx, 0644)
  if err then
    return false, self:format_error("writer:write_data:archive_entry_set_mode")
  end

  return self:write_entry(data, entry_tmp)
end

function _M:close()
  writer_close(self.ctx)
  self.ctx = nil
end

return _M