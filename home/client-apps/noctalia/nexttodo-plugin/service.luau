--!nonstrict

local inFlight = false

local function intervalMs()
  local minutes = tonumber(noctalia.getConfig("refresh_minutes")) or 5
  if minutes ~= minutes or minutes == math.huge or minutes == -math.huge then minutes = 5 end
  minutes = math.max(1, math.min(60, minutes))
  return math.floor(minutes * 60000)
end

local function limitValue()
  local limit = tonumber(noctalia.getConfig("limit")) or 8
  if limit ~= limit or limit == math.huge or limit == -math.huge then limit = 8 end
  return math.max(1, math.min(50, math.floor(limit)))
end

local function refresh()
  if inFlight then return end
  inFlight = true
  noctalia.state.set("polling", true)
  noctalia.setUpdateInterval(intervalMs())
  local started = noctalia.runAsync(
    "nexttodo next --json --limit " .. tostring(limitValue()),
    function(result)
      inFlight = false
      noctalia.state.set("polling", false)
      local decoded = result ~= nil
        and not result.timedOut
        and noctalia.json.decode(result.stdout or "")
        or nil
      if type(decoded) == "table" and type(decoded.tasks) == "table" then
        noctalia.state.set("report", decoded)
        noctalia.state.set("error", "")
      else
        local detail = result ~= nil and noctalia.string.trim(tostring(result.stderr or "")) or ""
        noctalia.state.set("error", detail ~= "" and detail or "nexttodo 读取失败")
      end
    end,
    30000
  )
  if not started then
    inFlight = false
    noctalia.state.set("polling", false)
    noctalia.state.set("error", "无法启动 nexttodo")
  end
end

noctalia.state.watch("command", function(value)
  if type(value) == "table" and value.action == "refresh" then refresh() end
end)

function update()
  if inFlight then return end
  refresh()
end

function onConfigChanged()
  refresh()
end
