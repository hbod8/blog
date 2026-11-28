#!/usr/bin/env lua
-- Scrape product prices (USD) for the bulk-rolling post.
-- Usage: lua scrape.lua [prices.yaml] [output.yaml]
-- Needs only Lua 5.1+ and curl. See README.md for the schema.
--
-- Scrapes every material and film supplier url in prices.yaml and records
-- {date, usd} in its `prices` list, updating the file in place (or writing to
-- output.yaml if given). Comments in the file are not preserved.

local in_path  = arg[1] or "prices.yaml"
local out_path = arg[2] or in_path
local TODAY = os.date("%Y-%m-%d")
local UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        .. "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"

local NULL = setmetatable({}, { __tostring = function() return "null" end })

---------------------------------------------------------------------------
-- Minimal YAML subset: nested maps, lists, and scalars. Comments and blank
-- lines are ignored. Maps remember key order in m.__order.
---------------------------------------------------------------------------
local function scalar(v)
  local s = v:match('^"(.*)"$')
  if s then return (s:gsub('\\"', '"'):gsub("\\\\", "\\")) end
  s = v:match("^'(.*)'$")
  if s then return s end
  if v == "null" or v == "~" then return NULL end
  if v == "[]" then return {} end
  return tonumber(v) or v
end

local function set(m, k, v)
  if m[k] == nil then m.__order[#m.__order + 1] = k end
  m[k] = v
end

local function read_yaml(path)
  local lines = {}
  for raw in io.lines(path) do
    if raw:match("%S") and not raw:match("^%s*#") then
      lines[#lines + 1] = { indent = #raw:match("^ *"), text = raw:match("^%s*(.-)%s*$") }
    end
  end

  local pos = 1
  local block
  local function child(indent)
    local nxt = lines[pos]
    if nxt and (nxt.indent > indent or (nxt.indent == indent and nxt.text:match("^%- "))) then
      return block(nxt.indent)
    end
    return NULL
  end

  function block(indent)
    if lines[pos].text:match("^%- ") then
      local list = {}
      while lines[pos] and lines[pos].indent == indent and lines[pos].text:match("^%- ") do
        local rest = lines[pos].text:sub(3)
        if rest:match("^[%w_]+:") then
          -- "- key: v" starts a map whose keys sit two columns further in
          lines[pos] = { indent = indent + 2, text = rest }
          list[#list + 1] = block(indent + 2)
        else
          pos = pos + 1
          list[#list + 1] = scalar(rest)
        end
      end
      return list
    end
    local map = { __order = {} }
    while lines[pos] and lines[pos].indent == indent and not lines[pos].text:match("^%- ") do
      local k, v = lines[pos].text:match("^([%w_]+):%s*(.*)$")
      assert(k, "cannot parse YAML line: " .. lines[pos].text)
      pos = pos + 1
      set(map, k, v ~= "" and scalar(v) or child(indent))
    end
    return map
  end

  return block(lines[1].indent)
end

local function quote(s) return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end

-- Prices (the `usd` key) always print rounded to the cent with two decimals
-- ("189.00"); other numbers (iso, count, constants) keep their natural form.
local function fmt(v, key)
  if v == NULL then return "null" end
  if type(v) == "number" then
    if key == "usd" then return string.format("%.2f", v) end
    return (string.format("%.2f", v):gsub("%.00$", ""))
  end
  if tostring(v):match("^%d%d%d%d%-%d%d%-%d%d$") then return v end -- bare date
  return quote(tostring(v))
end

local function emit(v, indent, out)
  local pad = string.rep(" ", indent)
  if v.__order then
    for _, k in ipairs(v.__order) do
      local x = v[k]
      if type(x) == "table" and x ~= NULL and next(x) == nil then
        out[#out + 1] = pad .. k .. ": []"
      elseif type(x) == "table" and x ~= NULL then
        out[#out + 1] = pad .. k .. ":"
        emit(x, indent + 2, out)
      else
        out[#out + 1] = pad .. k .. ": " .. fmt(x, k)
      end
    end
  else
    for _, item in ipairs(v) do
      if type(item) == "table" and item ~= NULL then
        local sub = {}
        emit(item, indent + 2, sub)
        sub[1] = pad .. "- " .. sub[1]:sub(indent + 3)
        for _, l in ipairs(sub) do out[#out + 1] = l end
      else
        out[#out + 1] = pad .. "- " .. fmt(item)
      end
    end
  end
end

---------------------------------------------------------------------------
-- Scraping
---------------------------------------------------------------------------
local function fetch(url)
  local cmd = string.format("curl -sL --max-time 30 -A %q -H %q %q",
    UA, "Accept-Language: en-US,en;q=0.9", url)
  local p = io.popen(cmd)
  local body = p:read("*a")
  p:close()
  return body
end

-- Try the usual structured places a store puts the price, most reliable first.
local function extract_price(html)
  local patterns = {
    'property="product:price:amount"%s+content="([%d,%.]+)"',
    'content="([%d,%.]+)"%s+property="product:price:amount"',
    'property="og:price:amount"%s+content="([%d,%.]+)"',
    'itemprop="price"%s+content="([%d,%.]+)"',
    'content="([%d,%.]+)"%s+itemprop="price"',
    -- decimal only: Shopify also emits integer cents ("price":19995)
    '"price"%s*:%s*"(%d[%d,]*%.%d+)"',
    '"price"%s*:%s*(%d[%d,]*%.%d+)[^%d]',
    '"amount"%s*:%s*(%d[%d,]*%.%d+)[^%d]',
    'data%-selenium="pricingPrice"[^>]*>%s*%$?([%d,%.]+)',
  }
  for _, pat in ipairs(patterns) do
    local m = html:match(pat)
    if m then
      -- European "149,90": a comma followed by exactly two digits is a decimal
      -- point (and means the store served EUR, not USD, so skip it).
      if m:match(",%d%d$") and not m:match("%.") then return nil end
      local n = tonumber((m:gsub(",", "")))
      if n and n > 0 then return n end
    end
  end
end

local cache = {}
local function price_for(label, url)
  if cache[url] == nil then
    local html = fetch(url)
    local price = extract_price(html)
    local status = price and string.format("$%.2f", price)
      or (html:find("Just a moment", 1, true) and "BLOCKED (bot challenge)")
      or "NOT FOUND"
    io.stderr:write(string.format("%-60s %s\n", label, status))
    cache[url] = price or false
  end
  return cache[url] or nil
end

-- Record today's price on item.prices; a second run on the same day replaces
-- that day's entry rather than adding a duplicate. No price -> no entry.
local function record(item, price)
  if not price then return end
  price = math.floor(price * 100 + 0.5) / 100 -- nearest cent
  if type(item.prices) ~= "table" or item.prices == NULL then set(item, "prices", {}) end
  local last = item.prices[#item.prices]
  if last and last.date == TODAY then
    last.usd = price
  else
    local e = { __order = {} }
    set(e, "date", TODAY)
    set(e, "usd", price)
    item.prices[#item.prices + 1] = e
  end
end

local data = read_yaml(in_path)

for _, item in ipairs(data.materials or {}) do
  record(item, price_for(item.name .. " @ " .. item.supplier, item.url))
end

local film_tables = { "commerciallyavailible", "cinema", "cinemabonus" }

for _, tname in ipairs(film_tables) do
  for _, stock in ipairs(data[tname] or {}) do
    -- formats is a map: format name -> { supplier, url, prices }
    local formats = stock.formats or {}
    for _, fname in ipairs(formats.__order or {}) do
      local f = formats[fname]
      local rolls = data.constants.rolls_36exp[fname]
      assert(rolls, "format not in constants.rolls_36exp: " .. tostring(fname))
      -- Entries without a url (e.g. mail-order cinema stock) are tracked by hand.
      if f.url and f.url ~= NULL then
        local price = price_for(stock.name .. " [" .. fname .. "] @ " .. f.supplier, f.url)
        record(f, price)
        if price then
          io.stderr:write(string.format("%60s $%.2f per 36exp roll\n", "", price / rolls))
        end
      end
    end
  end
end

local out = { "# Price tracking data. See README.md for the schema; updated by scrape.lua." }
emit(data, 0, out)
local fh = assert(io.open(out_path, "w"))
fh:write(table.concat(out, "\n"), "\n")
fh:close()
