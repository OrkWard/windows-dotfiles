local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local session = require 'session'
local config = wezterm.config_builder()
local home = wezterm.home_dir

-- Keep local sessions alive when the GUI detaches.
config.mux_enable_ssh_agent = false
config.unix_domains = {
  { name = 'unix' },
}
config.default_gui_startup_args = { 'connect', 'unix' }

config.default_prog = {
  home .. '\\.local\\bin\\elvish.exe',
}
config.default_cwd = home
config.set_environment_variables = {
  LANG = 'en_US.UTF-8',
  LC_TIME = 'en_US.UTF-8',
  PATHEXT = '.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.NU',
}

config.font = wezterm.font 'iA Writer Mono S'
config.font_size = 12.0
config.freetype_load_target = 'HorizontalLcd'
config.freetype_render_target = 'HorizontalLcd'
config.default_cursor_style = 'SteadyBar'
config.window_padding = { left = '2px', right = '2px', top = '2px', bottom = '2px' }

config.colors = {
  foreground = '#2A2C33',
  background = '#FAFAFA',
  cursor_bg = '#5C78E2',
  cursor_fg = '#FAFAFA',
  cursor_border = '#5C78E2',
  selection_bg = '#D4DBF4',
  selection_fg = '#2A2C33',
  split = '#2F5AF3',
  compose_cursor = '#2F5AF3',
  ansi = {
    '#000000', '#DE3E35', '#3F953A', '#D2B67C',
    '#2F5AF3', '#950095', '#0997B3', '#BBBBBB',
  },
  brights = {
    '#000000', '#DE3E35', '#3F953A', '#D2B67C',
    '#2F5AF3', '#A00095', '#0BBCD6', '#FFFFFF',
  },
  copy_mode_active_highlight_bg = { Color = '#2F5AF3' },
  copy_mode_active_highlight_fg = { Color = '#FFFFFF' },
  copy_mode_inactive_highlight_bg = { Color = '#5C78E2' },
  copy_mode_inactive_highlight_fg = { Color = '#FFFFFF' },
  quick_select_label_bg = { Color = '#3F953A' },
  quick_select_label_fg = { Color = '#FFFFFF' },
  quick_select_match_bg = { Color = '#D2B67C' },
  quick_select_match_fg = { Color = '#000000' },
  input_selector_label_bg = { Color = '#3F953A' },
  input_selector_label_fg = { Color = '#FFFFFF' },
  launcher_label_bg = { Color = '#3F953A' },
  launcher_label_fg = { Color = '#FFFFFF' },
  tab_bar = {
    background = '#3F953A',
    active_tab = {
      bg_color = '#3F953A',
      fg_color = '#FFFFFF',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#3F953A',
      fg_color = '#FAFAFA',
    },
    inactive_tab_hover = {
      bg_color = '#2F5AF3',
      fg_color = '#FFFFFF',
    },
    new_tab = {
      bg_color = '#3F953A',
      fg_color = '#FFFFFF',
    },
    new_tab_hover = {
      bg_color = '#2F5AF3',
      fg_color = '#FFFFFF',
    },
  },
}

config.command_palette_bg_color = '#2F5AF3'
config.command_palette_fg_color = '#FFFFFF'
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
config.show_tab_index_in_tab_bar = true
config.tab_and_split_indices_are_zero_based = false
config.switch_to_last_active_tab_when_closing_tab = true
config.scrollback_lines = 50000
config.status_update_interval = 1000

config.leader = { key = 'F1', mods = 'NONE', timeout_milliseconds = 2000 }

local function tab_title(tab)
  local title = tab:get_title()
  if title == '' then
    title = tab:active_pane():get_title()
  end
  return title
end

local function pane_cwd(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then
    return ''
  end
  return cwd.file_path or tostring(cwd)
end

local function process_name(pane)
  local name = pane:get_foreground_process_name() or pane:get_title()
  return name:gsub('.*[/\\]', '')
end

-- tmux display-message: shown on the left of the tab bar for a few seconds.
local function show_message(text)
  wezterm.GLOBAL.message = text
  wezterm.GLOBAL.message_until = os.time() + 4
end

-- Track the previous workspace for F1 ' / F1 L (tmux switch-client -l).
local function remember_workspace(from, to)
  if from and to and from ~= to then
    wezterm.GLOBAL.previous_workspace = from
  end
  wezterm.GLOBAL.current_workspace = to
end

local function switch_workspace(window, pane, name)
  remember_workspace(window:active_workspace(), name)
  window:perform_action(act.SwitchToWorkspace { name = name }, pane)
end

-- target = { workspace, mux_window, tab or pane }
local function activate_target(window, target)
  remember_workspace(window:active_workspace(), target.workspace)
  mux.set_active_workspace(target.workspace)
  local object = target.tab or target.pane
  object:activate()
  local gui_window = target.mux_window:gui_window()
  if gui_window then
    gui_window:focus()
  end
end

local function each_workspace_window(workspace, fn)
  for _, mux_window in ipairs(mux.all_windows()) do
    if mux_window:get_workspace() == workspace then
      fn(mux_window)
    end
  end
end

-- tmux switch-mode -w: tabs of every workspace.
local function show_tabs(window, pane)
  local choices = {}
  local targets = {}
  for _, workspace in ipairs(mux.get_workspace_names()) do
    each_workspace_window(workspace, function(mux_window)
      for index, tab in ipairs(mux_window:tabs()) do
        local id = tostring(#choices + 1)
        targets[id] = { workspace = workspace, mux_window = mux_window, tab = tab }
        table.insert(choices, {
          id = id,
          label = string.format('%s: %d: %s (%d panes)', workspace, index, tab_title(tab), #tab:panes()),
        })
      end
    end)
  end

  window:perform_action(act.InputSelector {
    title = 'Switch tab',
    fuzzy = true,
    choices = choices,
    action = wezterm.action_callback(function(inner_window, _, id)
      local target = id and targets[id]
      if target then
        activate_target(inner_window, target)
      end
    end),
  }, pane)
end

local function workspace_counts(name)
  local windows = 0
  local tabs = 0
  each_workspace_window(name, function(mux_window)
    windows = windows + 1
    tabs = tabs + #mux_window:tabs()
  end)
  return windows, tabs
end

local function show_workspaces(window, pane)
  local choices = {}
  for _, name in ipairs(mux.get_workspace_names()) do
    local windows, tabs = workspace_counts(name)
    table.insert(choices, {
      id = name,
      label = string.format('%s (%d windows, %d tabs)', name, windows, tabs),
    })
  end

  window:perform_action(act.InputSelector {
    title = 'Switch workspace',
    fuzzy = true,
    choices = choices,
    action = wezterm.action_callback(function(inner_window, inner_pane, id)
      if id then
        switch_workspace(inner_window, inner_pane, id)
      end
    end),
  }, pane)
end

local function show_tree(window, pane)
  local choices = {}
  local targets = {}

  local function add(label, target)
    local id = tostring(#choices + 1)
    targets[id] = target
    table.insert(choices, { id = id, label = label })
  end

  for _, workspace in ipairs(mux.get_workspace_names()) do
    local windows, tabs = workspace_counts(workspace)
    add(string.format('%s (%d windows, %d tabs)', workspace, windows, tabs), {
      workspace = workspace,
    })

    each_workspace_window(workspace, function(mux_window)
      for tab_index, tab in ipairs(mux_window:tabs()) do
        add(string.format('  %d: %s (%d panes)', tab_index, tab_title(tab), #tab:panes()), {
          workspace = workspace,
          mux_window = mux_window,
          tab = tab,
        })

        for _, info in ipairs(tab:panes_with_info()) do
          add(string.format('    %d: %s — %s', info.index + 1, process_name(info.pane), pane_cwd(info.pane)), {
            workspace = workspace,
            mux_window = mux_window,
            pane = info.pane,
          })
        end
      end
    end)
  end

  window:perform_action(act.InputSelector {
    title = 'Switch tree',
    fuzzy = true,
    choices = choices,
    action = wezterm.action_callback(function(inner_window, inner_pane, id)
      local target = id and targets[id]
      if not target then
        return
      end
      if target.mux_window then
        activate_target(inner_window, target)
      else
        switch_workspace(inner_window, inner_pane, target.workspace)
      end
    end),
  }, pane)
end

-- tmux command-prompt -I "#W" { rename-window }
local function rename_tab(window, pane)
  window:perform_action(act.PromptInputLine {
    description = 'Rename tab',
    prompt = '> ',
    initial_value = tab_title(window:active_tab()),
    action = wezterm.action_callback(function(inner_window, _, line)
      if line then
        inner_window:active_tab():set_title(line)
      end
    end),
  }, pane)
end

-- tmux command-prompt -I "#S" { rename-session }
local function rename_workspace(window, pane)
  local old = window:active_workspace()
  window:perform_action(act.PromptInputLine {
    description = 'Rename workspace',
    prompt = '> ',
    initial_value = old,
    action = wezterm.action_callback(function(_, _, line)
      if not line or line == '' or line == old then
        return
      end
      mux.rename_workspace(old, line)
      if wezterm.GLOBAL.current_workspace == old then
        wezterm.GLOBAL.current_workspace = line
      end
      if wezterm.GLOBAL.previous_workspace == old then
        wezterm.GLOBAL.previous_workspace = line
      end
    end),
  }, pane)
end

-- tmux switch-client -l
local function last_workspace(window, pane)
  local previous = wezterm.GLOBAL.previous_workspace
  if previous and previous ~= window:active_workspace() then
    for _, name in ipairs(mux.get_workspace_names()) do
      if name == previous then
        switch_workspace(window, pane, name)
        return
      end
    end
  end
  show_message('No last workspace')
end

-- Active pane per tab, polled from update-status, for F1 ; (tmux last-pane).
local function track_pane(tab)
  local key = 'pane_' .. tostring(tab:tab_id())
  local current = tab:active_pane():pane_id()
  local seen = wezterm.GLOBAL[key .. '_cur']
  if seen ~= current then
    if seen then
      wezterm.GLOBAL[key .. '_prev'] = seen
    end
    wezterm.GLOBAL[key .. '_cur'] = current
  end
end

local function last_pane(window, pane)
  local tab = window:active_tab()
  track_pane(tab)
  local previous = wezterm.GLOBAL['pane_' .. tostring(tab:tab_id()) .. '_prev']
  for _, candidate in ipairs(tab:panes()) do
    if candidate:pane_id() == previous and previous ~= pane:pane_id() then
      candidate:activate()
      track_pane(tab)
      return
    end
  end
  show_message('No last pane')
end

-- tmux: kill-pane directly at a shell prompt, confirm while a command runs.
-- elvish publishes the running command, '' at the prompt; unknown counts as busy.
local function kill_pane(window, pane)
  local busy = pane:get_user_vars().WEZTERM_LAST_COMMAND ~= ''
  window:perform_action(act.CloseCurrentPane { confirm = busy }, pane)
end

-- tmux break-pane
local function break_pane(_, pane)
  local tab = pane:tab()
  if not tab or #tab:panes() < 2 then
    show_message('Pane is already alone in its tab')
    return
  end
  local new_tab = pane:move_to_new_tab()
  new_tab:activate()
end

-- tmux bind S: move the tab into a new workspace named after it, renamed
-- 'origin'. WezTerm can only move panes, so only the active pane moves.
local function tab_to_workspace(window, pane)
  local tab = pane:tab()
  if not tab then
    return
  end
  local name = tab_title(tab)
  local left_behind = #tab:panes() - 1
  local old = window:active_workspace()
  local new_tab = pane:move_to_new_window(name)
  new_tab:set_title('origin')
  remember_workspace(old, name)
  mux.set_active_workspace(name)
  if left_behind > 0 then
    show_message(string.format('Moved active pane only; %d left in %s', left_behind, old))
  end
end

local function restore_session(_, pane)
  local _, message = session.restore { manual = true, domain = pane:get_domain_name() }
  show_message(message)
end

local function save_and_detach(window, pane)
  session.save(window, false)
  window:perform_action(act.DetachDomain 'CurrentPaneDomain', pane)
end

local function copy_previous_prompt(window, pane)
  window:perform_action(act.ActivateCopyMode, pane)
  window:perform_action(act.CopyMode { MoveBackwardZoneOfType = 'Prompt' }, pane)
  window:perform_action(act.CopyMode { MoveBackwardZoneOfType = 'Prompt' }, pane)
end

-- Like tmux's bell flag: mark tabs that rang while inactive, clear on visit.
local function bell_key(tab_id)
  return 'bell_' .. tostring(tab_id)
end

-- tmux next-window -a / previous-window -a
local function bell_tab(direction)
  return function(window)
    local tabs = window:mux_window():tabs()
    local current = window:active_tab():tab_id()
    local index = 1
    for i, tab in ipairs(tabs) do
      if tab:tab_id() == current then
        index = i
      end
    end
    for step = 1, #tabs - 1 do
      local tab = tabs[(index - 1 + direction * step) % #tabs + 1]
      if wezterm.GLOBAL[bell_key(tab:tab_id())] == true then
        tab:activate()
        return
      end
    end
    show_message('No window with alert')
  end
end

local cb = wezterm.action_callback

-- tmux select-pane -L/-D/-U/-R: at the edge, wrap to the far side.
local function move_pane(direction)
  return cb(function(window)
    local tab = window:active_tab()
    local target = tab:get_pane_direction(direction)
    if not target then
      local infos = tab:panes_with_info()
      local current
      for _, info in ipairs(infos) do
        if info.is_active then
          current = info
        end
      end
      if not current then
        return
      end
      local horizontal = direction == 'Left' or direction == 'Right'
      local best_edge
      for _, info in ipairs(infos) do
        local overlap
        if horizontal then
          overlap = info.top < current.top + current.height and current.top < info.top + info.height
        else
          overlap = info.left < current.left + current.width and current.left < info.left + info.width
        end
        if overlap and info.pane:pane_id() ~= current.pane:pane_id() then
          -- Wrapping Left lands on the rightmost pane, Right on the leftmost, etc.
          local edge = ({
            Left = info.left + info.width,
            Right = -info.left,
            Up = info.top + info.height,
            Down = -info.top,
          })[direction]
          if not best_edge or edge > best_edge then
            target, best_edge = info.pane, edge
          end
        end
      end
    end
    if target then
      target:activate()
    end
  end)
end

-- tmux bind -r: arrows keep working for repeat-time (500ms) after the first.
local pane_repeat = act.ActivateKeyTable {
  name = 'pane_repeat',
  one_shot = false,
  timeout_milliseconds = 500,
  until_unknown = true,
  replace_current = true,
}
local pane_repeat_keys = {}
local arrows = {
  { 'LeftArrow', 'Left' },
  { 'DownArrow', 'Down' },
  { 'UpArrow', 'Up' },
  { 'RightArrow', 'Right' },
}

config.keys = {
  { key = 'd', mods = 'LEADER|CTRL', action = cb(save_and_detach) },
  { key = 's', mods = 'LEADER|CTRL', action = cb(function(window)
    session.save(window, true)
  end) },
  { key = 'r', mods = 'LEADER|CTRL', action = cb(restore_session) },

  { key = 'u', mods = 'LEADER', action = cb(copy_previous_prompt) },

  { key = 'h', mods = 'LEADER', action = move_pane 'Left' },
  { key = 'j', mods = 'LEADER', action = move_pane 'Down' },
  { key = 'k', mods = 'LEADER', action = move_pane 'Up' },
  { key = 'l', mods = 'LEADER', action = move_pane 'Right' },
  { key = 'o', mods = 'LEADER', action = act.TogglePaneZoomState },

  { key = 'D', mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'n', mods = 'LEADER', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  { key = 'N', mods = 'LEADER|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'LEADER', action = cb(kill_pane) },
  { key = 'r', mods = 'LEADER', action = cb(rename_tab) },

  { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },
  { key = '6', mods = 'LEADER', action = act.ActivateTab(5) },
  { key = '7', mods = 'LEADER', action = act.ActivateTab(6) },
  { key = '8', mods = 'LEADER', action = act.ActivateTab(7) },
  { key = '9', mods = 'LEADER', action = act.ActivateTab(8) },
  { key = '0', mods = 'LEADER', action = act.ActivateTab(9) },

  { key = 'p', mods = 'LEADER', action = cb(show_tabs) },
  { key = 't', mods = 'LEADER', action = cb(show_tree) },
  { key = "'", mods = 'LEADER', action = cb(last_workspace) },
  { key = 'S', mods = 'LEADER|SHIFT', action = cb(tab_to_workspace) },
  { key = ',', mods = 'LEADER', action = act.ReloadConfiguration },

  { key = '?', mods = 'LEADER|SHIFT', action = act.Search { CaseSmartString = '' } },
  { key = 'u', mods = 'LEADER|CTRL', action = act.Multiple {
    act.ActivateCopyMode,
    act.CopyMode { MoveByPage = -0.5 },
  } },
  { key = 'c', mods = 'LEADER', action = act.QuickSelect },

  -- tmux defaults not overridden by tmux.conf.
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },
  { key = ']', mods = 'LEADER', action = act.PasteFrom 'Clipboard' },
  { key = 'PageUp', mods = 'LEADER', action = act.Multiple {
    act.ActivateCopyMode,
    act.CopyMode 'PageUp',
  } },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = '&', mods = 'LEADER|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'q', mods = 'LEADER', action = act.PaneSelect },
  { key = ';', mods = 'LEADER', action = cb(last_pane) },
  { key = '"', mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = '%', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '!', mods = 'LEADER|SHIFT', action = cb(break_pane) },
  { key = '{', mods = 'LEADER|SHIFT', action = act.RotatePanes 'CounterClockwise' },
  { key = '}', mods = 'LEADER|SHIFT', action = act.RotatePanes 'Clockwise' },
  { key = 'o', mods = 'LEADER|CTRL', action = act.RotatePanes 'CounterClockwise' },
  { key = 'o', mods = 'LEADER|ALT', action = act.RotatePanes 'Clockwise' },
  { key = 'n', mods = 'LEADER|ALT', action = cb(bell_tab(1)) },
  { key = 'p', mods = 'LEADER|ALT', action = cb(bell_tab(-1)) },
  { key = '$', mods = 'LEADER|SHIFT', action = cb(rename_workspace) },
  { key = '(', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(-1) },
  { key = ')', mods = 'LEADER|SHIFT', action = act.SwitchWorkspaceRelative(1) },
  { key = 'L', mods = 'LEADER|SHIFT', action = cb(last_workspace) },
  { key = ':', mods = 'LEADER|SHIFT', action = act.ActivateCommandPalette },

  -- Windows equivalents of the Cmd bindings in the Ghostty config.
  -- Ctrl+Shift; punctuation uses phys: so Shift doesn't turn it into </:.
  { key = 'phys:Comma', mods = 'CTRL|SHIFT', action = act.ReloadConfiguration },
  { key = 's', mods = 'CTRL|SHIFT', action = cb(show_workspaces) },
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'h', mods = 'CTRL|SHIFT', action = move_pane 'Left' },
  { key = 'j', mods = 'CTRL|SHIFT', action = move_pane 'Down' },
  { key = 'k', mods = 'CTRL|SHIFT', action = move_pane 'Up' },
  { key = 'l', mods = 'CTRL|SHIFT', action = move_pane 'Right' },
  { key = 'n', mods = 'CTRL|SHIFT', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  { key = 'p', mods = 'CTRL|SHIFT', action = cb(show_tabs) },
  { key = 'phys:Semicolon', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Prev' },
  { key = 'o', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },
  { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseSmartString = '' } },
  { key = 'r', mods = 'CTRL|SHIFT', action = cb(rename_tab) },
  { key = 'F1', mods = 'LEADER', action = act.ActivateCommandPalette },
}

-- Leader + arrow / C-arrow / M-arrow: select or resize, then repeatable.
for _, arrow in ipairs(arrows) do
  local key, direction = arrow[1], arrow[2]
  for mods, action in pairs {
    NONE = move_pane(direction),
    CTRL = act.AdjustPaneSize { direction, 1 },
    ALT = act.AdjustPaneSize { direction, 5 },
  } do
    local repeated = act.Multiple { action, pane_repeat }
    local leader_mods = mods == 'NONE' and 'LEADER' or ('LEADER|' .. mods)
    table.insert(config.keys, { key = key, mods = leader_mods, action = repeated })
    table.insert(pane_repeat_keys, { key = key, mods = mods, action = repeated })
  end
end

config.key_tables = { pane_repeat = pane_repeat_keys }

if wezterm.gui then
  local copy_mode = wezterm.gui.default_key_tables().copy_mode
  table.insert(copy_mode, {
    key = 'Escape',
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(act.ClearSelection, pane)
        window:perform_action(act.CopyMode 'ClearSelectionMode', pane)
      else
        window:perform_action(act.Multiple {
          act.ScrollToBottom,
          act.CopyMode 'Close',
        }, pane)
      end
    end),
  })
  -- tmux vi: Enter = copy-pipe-and-cancel
  table.insert(copy_mode, {
    key = 'Enter',
    mods = 'NONE',
    action = act.Multiple {
      act.CopyTo 'ClipboardAndPrimarySelection',
      act.ScrollToBottom,
      act.CopyMode 'Close',
    },
  })
  table.insert(copy_mode, {
    key = 'u',
    mods = 'NONE',
    action = act.CopyMode { MoveBackwardZoneOfType = 'Prompt' },
  })
  table.insert(copy_mode, {
    key = 'd',
    mods = 'NONE',
    action = act.CopyMode { MoveForwardZoneOfType = 'Prompt' },
  })
  config.key_tables.copy_mode = copy_mode
end

wezterm.on('mux-startup', function()
  session.restore()
end)

wezterm.on('window-config-reloaded', function(window)
  session.save(window, false)
end)

wezterm.on('bell', function(_, pane)
  local tab = pane:tab()
  local mux_window = tab and tab:window()
  if not tab or not mux_window then
    return
  end
  if mux_window:active_tab():tab_id() ~= tab:tab_id() then
    wezterm.GLOBAL[bell_key(tab:tab_id())] = true
  end
end)

wezterm.on('format-tab-title', function(tab, _, _, _, _, max_width)
  local key = bell_key(tab.tab_id)
  local flagged = wezterm.GLOBAL[key] == true
  if tab.is_active and flagged then
    wezterm.GLOBAL[key] = false
    flagged = false
  end

  local title = tab.tab_title
  if title == '' then
    title = tab.active_pane.title
  end
  local text = string.format(' %d: %s%s ', tab.tab_index + 1, title, flagged and '!' or '')
  text = wezterm.truncate_right(text, max_width)
  if flagged then
    return {
      { Attribute = { Intensity = 'Bold' } },
      { Background = { Color = '#FFFFFF' } },
      { Foreground = { Color = '#3F953A' } },
      { Text = text },
    }
  end
  return text
end)

wezterm.on('update-status', function(window)
  session.autosave(window)
  remember_workspace(wezterm.GLOBAL.current_workspace, window:active_workspace())
  track_pane(window:active_tab())

  local left = { { Foreground = { Color = '#FFFFFF' } } }
  local modes = { copy_mode = ' COPY ', search_mode = ' SEARCH ' }
  local mode = modes[window:active_key_table() or '']
  if mode then
    table.insert(left, { Background = { Color = '#2F5AF3' } })
    table.insert(left, { Attribute = { Intensity = 'Bold' } })
    table.insert(left, { Text = mode })
    table.insert(left, 'ResetAttributes')
    table.insert(left, { Foreground = { Color = '#FFFFFF' } })
  end
  local text = window:leader_is_active() and ' F1 ' or ''
  if wezterm.GLOBAL.message and os.time() <= (wezterm.GLOBAL.message_until or 0) then
    text = text .. ' ' .. wezterm.GLOBAL.message .. ' '
  end
  table.insert(left, { Text = text })
  window:set_left_status(wezterm.format(left))
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#FFFFFF' } },
    { Text = ' ' .. window:active_workspace() .. ' ' },
  })
end)

return config
