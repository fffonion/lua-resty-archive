local Reader = require "resty.archive.reader"
-- local Writer = require "resty.archive.writer"

local function read_archive_entry(filename, entry, basename_only)
  local r, err = Reader.open_filename(filename)
  if not r then
    return nil, "failed to open archive:" .. err
  end

  return r:read_data(entry, basename_only)
end


return {
  read_archive_entry = read_archive_entry,
  _VERSION = '1.2.0',
}