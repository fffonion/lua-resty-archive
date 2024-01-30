local ffi = require("ffi")

local clib = require "resty.archive.clib"
local lib = clib.clib
local format_error = clib.format_error

local _M = {
  format_error = format_error,
}

local entry_mt = {__index = _M}

local buf = ffi.new("char[?]", 10240)

function _M.new()
  local ctx = lib.archive_entry_new()
  if ctx == nil then
    return nil, "entry.new: failed to create entry"
  end

  ffi.gc(ctx, lib.archive_entry_free)

  return setmetatable({
    ctx = ctx,
  }, entry_mt)
end

function _M.wrap(ctx, archive)
  return setmetatable({
    ctx = ctx,
    actx = archive,
    aposition = lib.archive_position_compressed(archive),
  }, entry_mt)
end

function _M:clone()
  local ctx = lib.archive_entry_clone(self.ctx)
  if ctx == nil then
    return nil, self:format_error("entry:clone")
  end

  return _M.wrap(ctx)
end

function _M:clear()
  if lib.archive_entry_clear(self.ctx) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("entry:clear")
  end

  return self
end

function _M:get_size()
  local sz = lib.archive_entry_size(self.ctx)
  if sz < 0 then
    return nil, self:format_error("entry:size")
  end

  return tonumber(sz)
end
_M.size = _M.get_size

function _M:set_size(sz)
  if lib.archive_entry_set_size(self.ctx, sz) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("entry:set_size")
  end

  return true
end

function _M:get_pathname()
  local pathname = lib.archive_entry_pathname(self.ctx)
  if pathname == nil then
    return nil, self:format_error("entry:pathname")
  end

  return ffi.string(pathname)
end
_M.pathname = _M.get_pathname

function _M:set_pathname(pathname)
  if lib.archive_entry_set_pathname(self.ctx, pathname) ~= lib.ARCHIVE_OK then
    return nil, self:format_error("entry:set_pathname")
  end

  return true
end

function _M:is_encrypted()
  return lib.archive_entry_is_encrypted(self.ctx) == 1
end

function _M:read_data()
  if not self.actx or not self.aposition then
    return nil, "entry:read_data: entry created without archive doesn't support extract"
  end

  if lib.archive_position_compressed(self.actx) ~= self.aposition then
    return nil, self:format_error("entry:read_data: archive position mismatch")
  end

  local data = {}
  local read
  while true do
    read = lib.archive_read_data(self.actx, buf, 10240)
    if read < 0 then
      return nil, self:format_error("entry:read_data")
    elseif read == 0 then
      break
    end

    table.insert(data, ffi.string(buf, read))
  end

  return table.concat(data, "")
end

return _M