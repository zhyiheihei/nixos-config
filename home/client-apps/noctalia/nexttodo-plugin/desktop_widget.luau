--!nonstrict

local WIDTH = 240
local PADDING = 12
local GAP = 6
local HEADER_HEIGHT = 22

local report = noctalia.state.get("report") or {}
local errorText = noctalia.state.get("error") or ""

local function headerRow(count, failed)
  return ui.row({ gap = 6, align = "center", height = HEADER_HEIGHT }, {
    ui.glyph({ name = "list-check", size = 14, color = failed and "error" or "primary" }),
    ui.label({ text = "NextTodo", fontSize = 12, color = "on_surface" }),
    ui.label({
      text = failed and "!" or tostring(count),
      fontSize = 11,
      color = failed and "error" or "on_surface_variant",
    }),
  })
end

local function taskRow(task)
  local children = {
    ui.label({
      text = "#" .. tostring(task.number or "?"),
      fontSize = 11,
      color = "on_surface_variant",
      width = 26,
    }),
    ui.label({ text = tostring(task.title or "?"), fontSize = 12, maxLines = 2 }),
  }
  local folder = tostring(task.folder or "/")
  if folder ~= "/" then
    children[3] = ui.label({ text = folder, fontSize = 10, color = "on_surface_variant", maxLines = 1 })
  end
  return ui.row({ gap = 6, align = "center" }, children)
end

local function render()
  local tasks = type(report) == "table"
    and type(report.tasks) == "table"
    and report.tasks
    or {}
  local failed = errorText ~= ""

  local children = { headerRow(#tasks, failed) }

  if failed then
    children[2] = ui.label({ text = errorText, fontSize = 11, color = "error", maxLines = 3 })
  elseif #tasks == 0 then
    children[2] = ui.label({ text = "暂无待办", fontSize = 11, color = "on_surface_variant" })
  else
    for _, task in ipairs(tasks) do
      children[#children + 1] = taskRow(task)
    end
  end

  desktopWidget.render(ui.column({
    width = WIDTH,
    gap = GAP,
    padding = PADDING,
    align = "stretch",
  }, children))
end

noctalia.state.watch("report", function(value)
  if type(value) == "table" then
    report = value
    errorText = ""
    render()
  end
end)

noctalia.state.watch("error", function(value)
  errorText = type(value) == "string" and value or noctalia.string.trim(tostring(value or ""))
  render()
end)

function update()
  render()
end

function onConfigChanged()
  render()
end

render()
