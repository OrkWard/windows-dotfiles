local wezterm = require 'wezterm'
local mux = wezterm.mux

local M = {}
local state_path = wezterm.home_dir .. '/.local/state/wezterm-session.json'
local saving = false
local last_save = 0

local function cwd_for(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then
    return wezterm.home_dir
  end
  return cwd.file_path or tostring(cwd)
end

local function bounds(leaves)
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = 0, 0
  for _, leaf in ipairs(leaves) do
    min_x = math.min(min_x, leaf.x)
    min_y = math.min(min_y, leaf.y)
    max_x = math.max(max_x, leaf.x + leaf.width)
    max_y = math.max(max_y, leaf.y + leaf.height)
  end
  return min_x, min_y, max_x, max_y
end

local function partition(leaves, axis, split)
  local first, second = {}, {}
  for _, leaf in ipairs(leaves) do
    local start = axis == 'x' and leaf.x or leaf.y
    local finish = start + (axis == 'x' and leaf.width or leaf.height)
    if finish <= split then
      table.insert(first, leaf)
    elseif start >= split then
      table.insert(second, leaf)
    else
      return nil
    end
  end
  if #first == 0 or #second == 0 then
    return nil
  end
  return first, second
end

local function layout_tree(leaves)
  if #leaves == 1 then
    local leaf = leaves[1]
    return {
      kind = 'leaf',
      id = leaf.id,
      cwd = leaf.cwd,
      command = leaf.command,
      active = leaf.active,
      zoomed = leaf.zoomed,
    }
  end

  local min_x, min_y, max_x, max_y = bounds(leaves)
  for _, axis in ipairs { 'x', 'y' } do
    local candidates = {}
    local seen = {}
    for _, leaf in ipairs(leaves) do
      local value = axis == 'x' and leaf.x or leaf.y
      local minimum = axis == 'x' and min_x or min_y
      if value > minimum and not seen[value] then
        seen[value] = true
        table.insert(candidates, value)
      end
    end
    table.sort(candidates)
    for _, split in ipairs(candidates) do
      local first, second = partition(leaves, axis, split)
      if first then
        local maximum = axis == 'x' and max_x or max_y
        local minimum = axis == 'x' and min_x or min_y
        local ratio = (maximum - split) / (maximum - minimum)
        ratio = math.max(0.05, math.min(0.95, ratio))
        return {
          kind = 'split',
          axis = axis,
          ratio = ratio,
          first = layout_tree(first),
          second = layout_tree(second),
        }
      end
    end
  end

  local first = table.remove(leaves, 1)
  return {
    kind = 'split',
    axis = 'x',
    ratio = #leaves / (#leaves + 1),
    first = layout_tree { first },
    second = layout_tree(leaves),
  }
end

local function capture_tab(tab_info)
  local leaves = {}
  local width, height = 1, 1
  for index, info in ipairs(tab_info.tab:panes_with_info()) do
    local vars = info.pane:get_user_vars()
    local command = vars.WEZTERM_LAST_COMMAND or ''
    if #command > 16000 then
      command = command:sub(1, 16000)
    end
    local leaf = {
      id = index,
      x = info.left,
      y = info.top,
      width = info.width,
      height = info.height,
      cwd = cwd_for(info.pane),
      command = command,
      active = info.is_active,
      zoomed = info.is_zoomed,
    }
    width = math.max(width, info.left + info.width)
    height = math.max(height, info.top + info.height)
    table.insert(leaves, leaf)
  end
  return {
    title = tab_info.tab:get_title(),
    active = tab_info.is_active,
    width = width,
    height = height,
    layout = layout_tree(leaves),
  }
end

local function capture_state(gui_window)
  local active_window_id
  if gui_window then
    active_window_id = gui_window:mux_window():window_id()
  end

  local state = {
    version = 1,
    active_workspace = mux.get_active_workspace(),
    windows = {},
  }
  for _, mux_window in ipairs(mux.all_windows()) do
    local saved_window = {
      workspace = mux_window:get_workspace(),
      title = mux_window:get_title(),
      active = mux_window:window_id() == active_window_id,
      tabs = {},
    }
    for _, tab_info in ipairs(mux_window:tabs_with_info()) do
      table.insert(saved_window.tabs, capture_tab(tab_info))
    end
    if #saved_window.tabs > 0 then
      table.insert(state.windows, saved_window)
    end
  end
  return state
end

local function write_state(state)
  local temporary = state_path .. '.tmp'
  local file, err = io.open(temporary, 'wb')
  if not file then
    return false, err
  end
  local ok, encoded = pcall(wezterm.serde.json_encode, state)
  if not ok then
    file:close()
    os.remove(temporary)
    return false, encoded
  end
  file:write(encoded)
  file:flush()
  file:close()
  os.remove(state_path)
  local renamed, rename_err = os.rename(temporary, state_path)
  if not renamed then
    os.remove(temporary)
    return false, rename_err
  end
  return true
end

function M.save(window, notify)
  if saving then
    return false
  end
  saving = true
  local ok, result, err = pcall(function()
    local state = capture_state(window)
    if #state.windows == 0 then
      return false, 'no windows to save'
    end
    return write_state(state)
  end)
  saving = false

  local saved = ok and result
  local message = saved and 'Session saved' or ('Save failed: ' .. tostring(ok and err or result))
  if notify and window then
    window:toast_notification('WezTerm session', message, nil, 4000)
  end
  if not saved then
    wezterm.log_error(message)
  end
  return saved
end

function M.autosave(window)
  local now = os.time()
  if now - last_save >= 15 then
    last_save = now
    M.save(window, false)
  end
end

local function read_state()
  local file = io.open(state_path, 'rb')
  if not file then
    return nil
  end
  local encoded = file:read('*a')
  file:close()
  if #encoded > 5 * 1024 * 1024 then
    return nil, 'snapshot is too large'
  end
  local ok, state = pcall(wezterm.serde.json_decode, encoded)
  if not ok then
    return nil, state
  end
  if type(state) ~= 'table' or state.version ~= 1 or type(state.windows) ~= 'table' then
    return nil, 'invalid snapshot'
  end
  return state
end

local function valid_leaf(node)
  return type(node) == 'table'
    and node.kind == 'leaf'
    and type(node.id) == 'number'
    and type(node.cwd) == 'string'
    and type(node.command) == 'string'
end

local function valid_layout(node, depth)
  if depth > 64 or type(node) ~= 'table' then
    return false
  end
  if node.kind == 'leaf' then
    return valid_leaf(node)
  end
  return node.kind == 'split'
    and (node.axis == 'x' or node.axis == 'y')
    and type(node.ratio) == 'number'
    and node.ratio > 0
    and node.ratio < 1
    and valid_layout(node.first, depth + 1)
    and valid_layout(node.second, depth + 1)
end

local function validate(state)
  if #state.windows == 0 or #state.windows > 64 then
    return false
  end
  for _, window in ipairs(state.windows) do
    if type(window.workspace) ~= 'string'
      or type(window.title) ~= 'string'
      or type(window.tabs) ~= 'table'
      or #window.tabs == 0
      or #window.tabs > 128 then
      return false
    end
    for _, tab in ipairs(window.tabs) do
      if type(tab.title) ~= 'string'
        or type(tab.width) ~= 'number'
        or type(tab.height) ~= 'number'
        or not valid_layout(tab.layout, 0) then
        return false
      end
    end
  end
  return true
end

local function first_leaf(node)
  while node.kind == 'split' do
    node = node.first
  end
  return node
end

local function spawn_options(leaf)
  local command = leaf.command:gsub('%z', '')
  local options = { cwd = leaf.cwd ~= '' and leaf.cwd or wezterm.home_dir }
  if command ~= '' then
    options.set_environment_variables = { WEZTERM_RESTORE_COMMAND = command }
  end
  return options
end

local function split_pane(pane, node, restored)
  if node.kind == 'leaf' then
    restored[node.id] = pane
    return
  end

  local options = spawn_options(first_leaf(node.second))
  options.direction = node.axis == 'x' and 'Right' or 'Bottom'
  options.size = node.ratio
  local ok, new_pane = pcall(function()
    return pane:split(options)
  end)
  if not ok then
    options.cwd = wezterm.home_dir
    ok, new_pane = pcall(function()
      return pane:split(options)
    end)
  end
  if not ok then
    wezterm.log_error('Session split failed: ' .. tostring(new_pane))
    return
  end

  split_pane(pane, node.first, restored)
  split_pane(new_pane, node.second, restored)
end

local function restore_tab(tab, pane, saved_tab)
  local restored = {}
  split_pane(pane, saved_tab.layout, restored)
  tab:set_title(saved_tab.title)

  local active
  local zoomed
  local function inspect(node)
    if node.kind == 'leaf' then
      if node.active then
        active = restored[node.id]
      end
      if node.zoomed then
        zoomed = restored[node.id]
      end
      return
    end
    inspect(node.first)
    inspect(node.second)
  end
  inspect(saved_tab.layout)
  if active then
    active:activate()
  end
  return zoomed
end

local function spawn_window(saved_window)
  local first_tab = saved_window.tabs[1]
  local options = spawn_options(first_leaf(first_tab.layout))
  options.workspace = saved_window.workspace
  options.width = math.max(1, math.floor(first_tab.width))
  options.height = math.max(1, math.floor(first_tab.height))

  local ok, tab, pane, mux_window = pcall(mux.spawn_window, options)
  if not ok then
    options.cwd = wezterm.home_dir
    ok, tab, pane, mux_window = pcall(mux.spawn_window, options)
  end
  if not ok then
    wezterm.log_error('Session window restore failed: ' .. tostring(tab))
    return nil
  end

  mux_window:set_title(saved_window.title)
  local active_tab = first_tab.active and tab or nil
  restore_tab(tab, pane, first_tab)

  for index = 2, #saved_window.tabs do
    local saved_tab = saved_window.tabs[index]
    local tab_options = spawn_options(first_leaf(saved_tab.layout))
    local tab_ok, new_tab, new_pane = pcall(function()
      return mux_window:spawn_tab(tab_options)
    end)
    if not tab_ok then
      tab_options.cwd = wezterm.home_dir
      tab_ok, new_tab, new_pane = pcall(function()
        return mux_window:spawn_tab(tab_options)
      end)
    end
    if tab_ok then
      restore_tab(new_tab, new_pane, saved_tab)
      if saved_tab.active then
        active_tab = new_tab
      end
    else
      wezterm.log_error('Session tab restore failed: ' .. tostring(new_tab))
    end
  end

  if active_tab then
    active_tab:activate()
  end
  return mux_window
end

function M.restore()
  if #mux.all_windows() > 0 then
    return false
  end
  local state, err = read_state()
  if not state then
    if err then
      wezterm.log_error('Session restore failed: ' .. tostring(err))
    end
    return false
  end
  if not validate(state) then
    wezterm.log_error('Session restore failed: invalid snapshot structure')
    return false
  end

  for _, saved_window in ipairs(state.windows) do
    spawn_window(saved_window)
  end
  if type(state.active_workspace) == 'string' then
    pcall(mux.set_active_workspace, state.active_workspace)
  end
  return #mux.all_windows() > 0
end

return M
