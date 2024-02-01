local ffi = require("ffi")

-- Load libarchive shared library
local lib_names = { "libarchive", "libarchive.so.13" }
local lib 
for _, l in ipairs(lib_names) do
  local pok, perr = pcall(ffi.load, l)
  if pok then
    lib = perr
    break
  end
end

if not lib then
  error("Unable to load libarchive")
end

-- Define structs and enums
ffi.cdef[[
typedef struct archive archive;
typedef struct archive_entry archive_entry;
typedef unsigned int mode_t;

enum {
  ARCHIVE_OK = 0,
  ARCHIVE_EOF = 1,
  ARCHIVE_RETRY = -10,
  ARCHIVE_WARN = -20,
  ARCHIVE_FAILED = -25,
  ARCHIVE_FATAL = -30
};

enum {
  AE_IFMT = 0170000,
  AE_IFREG = 0100000,
  AE_IFLNK = 0120000,
  AE_IFSOCK = 0140000,
  AE_IFCHR = 0020000,
  AE_IFBLK = 0060000,
  AE_IFDIR = 0040000,
  AE_IFIFO = 0010000
};

// read
archive *archive_read_new(void);
int archive_read_close(archive *);
int archive_read_free(archive *);

int archive_read_support_filter_all(archive *);
int archive_read_support_format_all(archive *);
int archive_read_support_filter_by_name(archive *, const char *name);
int archive_read_support_format_by_name(archive *, const char *name);
int archive_read_support_format_raw(archive *);

int archive_read_open_filename(archive *, const char *filename, size_t block_size);
int archive_read_open_memory(archive*,  const	void  *buff, size_t size);

int archive_read_next_header(archive *, archive_entry **);
int archive_read_data(archive *, void *, size_t);
int archive_read_add_passphrase(struct archive *, const char	*passphrase);

// write
archive *archive_write_new(void);
int archive_write_close(archive *);
int archive_write_free(archive *);

int archive_write_add_filter_by_name(archive *, const char *name);
int archive_write_set_format_by_name(archive *, const char *name);  
int archive_write_set_options(struct archive *, const char *options);

int archive_write_open_filename(archive *, const char *);   

int archive_write_header(archive *, archive_entry *);
int archive_write_data(archive *, const void *, size_t);

// entry
archive_entry *archive_entry_new(void);
archive_entry *archive_entry_clone(struct archive_entry	*);
archive_entry *archive_entry_clear(struct archive_entry	*);
void archive_entry_free(struct archive_entry *);

int archive_entry_size(archive_entry *);
void archive_entry_set_size(archive_entry *, size_t);
const char *archive_entry_pathname(archive_entry *);
void archive_entry_set_pathname(struct archive_entry *a, const char *path);
mode_t archive_entry_filetype(struct archive_entry *);
void archive_entry_set_filetype(struct archive_entry *, mode_t type);
mode_t archive_entry_perm(struct archive_entry *a);
void archive_entry_set_perm(struct archive_entry *a, mode_t mode);
int archive_entry_is_encrypted(archive_entry *);

// utils
int archive_errno(struct archive *);
const char * archive_error_string(struct archive *);
int64_t archive_position_compressed(struct archive *);

int archive_version_number(void);
]]

if lib.archive_version_number() < 3000000 then
  error("libarchive version 3.0 or higher required")
end

local function format_error(self, prefix)
  if self.ctx == nil then
    error("ctx is nil")
  end

  local code = lib.archive_errno(self.ctx)
  if code ~= 0 then
    prefix = prefix .. ": " .. tonumber(code)
  end

  local err = lib.archive_error_string(self.ctx)
  if err ~= nil then
    prefix = prefix .. ": " .. ffi.string(err)
  end

  return prefix
end

return {
  clib = lib,
  format_error = format_error,
}