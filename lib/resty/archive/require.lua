local Reader = require "resty.archive.reader"
local to_hex = require "resty.string".to_hex

local _M = {}

local package_paths = {}
local package_cached = {}

local function endswith(s, e)
  return s and e and e ~= "" and s:sub(#s-#e+1, #s) == e
end

local rockspec_fenv = {}

local hasher

local function from_hex(s)
  local hex_to_char = {}
  for idx = 0, 255 do
  hex_to_char[("%02X"):format(idx)] = string.char(idx)
  hex_to_char[("%02x"):format(idx)] = string.char(idx)
  end

  return s:gsub("(..)", hex_to_char)
end

local function verify_checksum(path, sha256sum, cached)
  local c
  if cached and package_cached[path] then
    c = package_cached[path]
  else
    local f, err = io.open(path, "rb")
    if not f then
      return false, "failed to open file: " .. path .. ": " .. err
    end

    c = f:read("*a")

    if cached and not package_cached[path] then
      package_cached[path] = c
    end
  end

  if sha256sum == true then
    return true
  end

  if not hasher then
    local digest = require "resty.openssl.digest"
    hasher = digest.new("sha256")
  end
  assert(hasher:reset())

  local d
  if c then
    d = hasher:final(c)
    if d == sha256sum then
      return true
    end
  end

  return false, "checksum mismatch for " .. path .. ": " .. to_hex(d) .. " expecting: " .. to_hex(sha256sum)
end

local function loader(name)
  -- first find any file that exists
  local errors = {}
  for p, sha256sum in pairs(package_paths) do
    local filepath = name:gsub("%.", "/") .. ".lua"
    local content
    local rd
    local pcache = package_cached[p]

    if sha256sum ~= true then
      local ok, err = verify_checksum(p, sha256sum)
      if not ok then
        table.insert(errors, "\n\t" .. err)
        goto next_please
      end
    end

    rd = pcache and Reader.open_memory(pcache) or Reader.open_filename(p)

    -- handle filelist defined in .roskspec
    if endswith(p, ".rock") and rd then
      local rockspec = rd:read_data("%.rockspec$", true, true)
      if rockspec then
        local pok, rvarsf = pcall(loadstring, rockspec .. "\nreturn { m = build.modules, p = package }")
        if pok and rvarsf then
          setfenv(rvarsf, rockspec_fenv)
          local pok, rvars = pcall(rvarsf)
          if pok and rvars then
            local rfp = rvars.m[name] or rvars.m[name .. ".init"]
            filepath = rfp and (rvars.p .. "/" .. rfp ) or filepath
          end
        end
      end

      -- re-open the file
      rd = pcache and Reader.open_memory(pcache) or Reader.open_filename(p)
    end

    if not rd then
      goto next_please
    end

    content = rd:read_data(filepath)
    if not content then -- try /?/init.lua
      filepath = filepath:gsub("%.lua$", "/init.lua")
      rd = pcache and Reader.open_memory(pcache) or Reader.open_filename(p)
      if rd then
        content = rd:read_data(filepath)
      end
    end

    if content then
      local pok, lf = pcall(loadstring, content, p .. ":" .. name)
      if pok and lf then
        return lf
      else
        table.insert(errors, "\n\tunable to load from " .. p .. ":" .. filepath .. ": " .. lf)
      end
    end

::next_please::
    table.insert(errors, "\n\tno such module '" .. name .. "' in " .. p)
    -- return assert(loadstring(content, filename))
  end

  return table.concat(errors)
end

function _M.add_package_path(path, sha256sum, cached)
  sha256sum = sha256sum and from_hex(sha256sum) or true
  package_paths[path] = sha256sum
  return verify_checksum(path, sha256sum, cached)
end

function _M.register_loader()
  for _, f in ipairs(package.loaders) do
    if f == loader then
      return
    end
  end

  package.loaders[#package.loaders + 1] = loader

  return true
end

return _M