local ffi = require("ffi")

local clib = require "resty.archive.clib"
local lib = clib.clib
local format_error = clib.format_error
local entry_lib = require "resty.archive.entry"

local entry_ptr = ffi.new("archive_entry *[1]")

local _M = {
  format_error = format_error,
}
local reader_mt = {__index = _M}

local function reader_close(ctx)
  if ctx == nil then
    return
  end

  lib.archive_read_close(ctx)
  lib.archive_read_free(ctx)
end

local function reader_new(filter, format)
  if filter and filter ~= "all" then
    return nil, "only automatic detected filter is supported"
  end

  if format and format ~= "all" and format ~= "raw" then
    return nil, "only automatic detected or raw format is supported"
  end

  local ctx = lib.archive_read_new()
  if ctx == nil then
    return nil, "failed to create reader"
  end

  ffi.gc(ctx, reader_close)

  local code

  if not filter or filter == "all" then
    code = lib.archive_read_support_filter_all(ctx)
  else
    return nil, "only automatic detected filter is supported"
  end

  if code ~= lib.ARCHIVE_OK then
    return nil, "failed to add \"" .. filter .. "\" filter:"
  end

  if not format or format == "all" then
    code = lib.archive_read_support_format_all(ctx)
  elseif format == "raw" then
    code = lib.archive_read_support_format_raw(ctx)
  else
    return nil, "only automatic detected or raw format is supported"
  end

  if code ~= lib.ARCHIVE_OK then
    return nil, "failed to add \"" .. filter .. "\" format:"
  end

  return setmetatable({
    ctx = ctx,
  }, reader_mt), nil
end

function _M.open_filename(filename, blocksize, format, filter)
  if type(filename) ~= "string" then
    return false, "reader:open_filename: except a string at #1"
  end

  local self, err = reader_new(format, filter)
  if not self then
    return nil, "reader.open_filename: " .. err
  end

  if lib.archive_read_open_filename(self.ctx, filename, blocksize or 10240) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("reader:open_filename")
  end

  return self
end

function _M.open_memory(buff, format, filter)
  if type(buff) ~= "string" then
    return false, "reader:open_memory: except a string at #1"
  end

  local self, err = reader_new(format, filter)
  if not self then
    return nil, "reader.open_memory: " .. err
  end

  local buf_ptr = ffi.cast("const void *", buff)
  if lib.archive_read_open_memory(self.ctx, buf_ptr, #buff) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("reader:open_memory")
  end

  return self
end

function _M:add_passphrase(passphrase)
  if type(passphrase) ~= "string" then
    return false, "reader:add_passphrase: except a string at #1"
  end

  if lib.archive_read_add_passphrase(self.ctx, passphrase) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("reader:add_passphrase")
  end

  return true
end

function _M:read_entry(pathname, basename_only, is_pattern)
  while true do
    local r = lib.archive_read_next_header(self.ctx, entry_ptr)
    if r == ffi.C.ARCHIVE_EOF then
      break
    elseif r < ffi.C.ARCHIVE_OK then
      return nil, self:format_error("reader:read_entry: error reading archive")
    end

    local current = entry_ptr[0]
    local ep = lib.archive_entry_pathname(current)
    local eps = ep and ffi.string(ep)
    eps = basename_only and eps:match("[^/]+$") or eps
    if ep ~= nil and ((not is_pattern and eps == pathname) or (is_pattern and eps:match(pathname))) then
      return entry_lib.wrap(current, self.ctx)
    end
  end

  return nil -- not found
end

function _M:read_data(...)
  local entry, err = self:read_entry(...)
  if not entry then
    return nil, err
  end
  return entry:read_data()
end

function _M:close()
  reader_close(self.ctx)
  self.ctx = nil
end

return _M