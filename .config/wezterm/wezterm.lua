local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local session = require 'session'
local config = wezterm.config_builder()
local home = wezterm.home_dir
local nu_config = home .. '\\.config\\nushell'

-- Keep local sessions alive when the GUI detaches.
config.mux_enable_ssh_agent = false
config.unix_domains = {
  { name = 'unix' },
}
config.default_gui_startup_args = { 'connect', 'unix' }

config.default_prog = {
  home .. '\\scoop\\apps\\nu\\current\\nu.exe',
  '--config-home',
  nu_config,
  '--env-config',
  nu_config .. '\\env.nu',
}
config.default_cwd = home

config.font = wezterm.font 'iA Writer Mono S'
config.font_size = 12.0
config.freetype_load_target = 'HorizontalLcd'
config.freetype_render_target = 'HorizontalLcd'
config.default_cursor_style = 'SteadyBar'

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
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
config.show_tab_index_in_tab_bar = true
config.tab_and_split_indices_are_zero_based = true
config.switch_to_last_active_tab_when_closing_tab = true
config.scrollback_lines = 50000
config.status_update_interval = 1000
config.debug_key_events = true

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

local function show_tabs(window, pane)
  local choices = {}
  local targets = {}
  for index, tab in ipairs(window:mux_window():tabs()) do
    local id = tostring(index)
    targets[id] = tab
    table.insert(choices, {
      id = id,
      label = string.format('%d: %s (%d panes)', index - 1, tab_title(tab), #tab:panes()),
    })
  end

  window:perform_action(act.InputSelector {
    title = 'Switch tab',
    fuzzy = true,
    choices = choices,
    action = wezterm.action_callback(function(_, _, id)
      if id and targets[id] then
        targets[id]:activate()
      end
    end),
  }, pane)
end

local function workspace_counts(name)
  local windows = 0
  local tabs = 0
  for _, mux_window in ipairs(mux.all_windows()) do
    if mux_window:get_workspace() == name then
      windows = windows + 1
      tabs = tabs + #mux_window:tabs()
    end
  end
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
        inner_window:perform_action(act.SwitchToWorkspace { name = id }, inner_pane)
      end
    end),
  }, pane)
end

local function show_tree(window, pane)
  local choices = {}
  local targets = {}
  local next_id = 0

  local function add(label, target)
    next_id = next_id + 1
    local id = tostring(next_id)
    targets[id] = target
    table.insert(choices, { id = id, label = label })
  end

  for _, workspace in ipairs(mux.get_workspace_names()) do
    local windows, tabs = workspace_counts(workspace)
    add(string.format('%s (%d windows, %d tabs)', workspace, windows, tabs), {
      kind = 'workspace',
      workspace = workspace,
    })

    for _, mux_window in ipairs(mux.all_windows()) do
      if mux_window:get_workspace() == workspace then
        for tab_index, tab in ipairs(mux_window:tabs()) do
          add(string.format('  %d: %s (%d panes)', tab_index - 1, tab_title(tab), #tab:panes()), {
            kind = 'tab',
            workspace = workspace,
            mux_window = mux_window,
            tab = tab,
          })

          for _, info in ipairs(tab:panes_with_info()) do
            add(string.format('    %d: %s — %s', info.index, process_name(info.pane), pane_cwd(info.pane)), {
              kind = 'pane',
              workspace = workspace,
              mux_window = mux_window,
              pane = info.pane,
            })
          end
        end
      end
    end
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
      if target.kind == 'workspace' then
        inner_window:perform_action(act.SwitchToWorkspace { name = target.workspace }, inner_pane)
        return
      end

      mux.set_active_workspace(target.workspace)
      if target.kind == 'tab' then
        target.tab:activate()
      else
        target.pane:activate()
      end
      local gui_window = target.mux_window:gui_window()
      if gui_window then
        gui_window:focus()
      end
    end),
  }, pane)
end

local rename_tab = act.PromptInputLine {
  description = 'Rename tab',
  prompt = '> ',
  action = wezterm.action_callback(function(window, _, line)
    if line then
      window:active_tab():set_title(line)
    end
  end),
}

local function save_and_detach(window, pane)
  session.save(window, false)
  window:perform_action(act.DetachDomain 'CurrentPaneDomain', pane)
end

local function copy_previous_prompt(window, pane)
  window:perform_action(act.ActivateCopyMode, pane)
  window:perform_action(act.CopyMode { MoveBackwardZoneOfType = 'Prompt' }, pane)
  window:perform_action(act.CopyMode { MoveBackwardZoneOfType = 'Prompt' }, pane)
end

config.keys = {
  { key = 'd', mods = 'LEADER|CTRL', action = wezterm.action_callback(save_and_detach) },
  { key = 's', mods = 'LEADER|CTRL', action = wezterm.action_callback(function(window)
    session.save(window, true)
  end) },

  { key = 'u', mods = 'LEADER', action = wezterm.action_callback(copy_previous_prompt) },

  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'o', mods = 'LEADER', action = act.TogglePaneZoomState },

  { key = 'D', mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'n', mods = 'LEADER', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  { key = 'N', mods = 'LEADER|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'LEADER', action = act.CloseCurrentTab { confirm = false } },
  { key = 'r', mods = 'LEADER', action = rename_tab },

  { key = '0', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '1', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(4) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(5) },
  { key = '6', mods = 'LEADER', action = act.ActivateTab(6) },
  { key = '7', mods = 'LEADER', action = act.ActivateTab(7) },
  { key = '8', mods = 'LEADER', action = act.ActivateTab(8) },
  { key = '9', mods = 'LEADER', action = act.ActivateTab(9) },

  { key = 'p', mods = 'LEADER', action = wezterm.action_callback(show_tabs) },
  { key = 't', mods = 'LEADER', action = wezterm.action_callback(show_tree) },
  { key = 's', mods = 'LEADER', action = wezterm.action_callback(show_workspaces) },
  { key = ',', mods = 'LEADER', action = act.ReloadConfiguration },

  { key = '?', mods = 'LEADER|SHIFT', action = act.Search { CaseSmartString = '' } },
  { key = 'u', mods = 'LEADER|CTRL', action = act.Multiple {
    act.ActivateCopyMode,
    act.CopyMode { MoveByPage = -0.5 },
  } },
  { key = 'c', mods = 'LEADER', action = act.QuickSelect },

  -- Windows equivalents of the Cmd bindings in the Ghostty config.
  { key = ',', mods = 'CTRL|ALT', action = act.ReloadConfiguration },
  { key = '0', mods = 'CTRL|ALT', action = act.ActivateTab(0) },
  { key = '1', mods = 'CTRL|ALT', action = act.ActivateTab(1) },
  { key = '2', mods = 'CTRL|ALT', action = act.ActivateTab(2) },
  { key = '3', mods = 'CTRL|ALT', action = act.ActivateTab(3) },
  { key = '4', mods = 'CTRL|ALT', action = act.ActivateTab(4) },
  { key = '5', mods = 'CTRL|ALT', action = act.ActivateTab(5) },
  { key = '6', mods = 'CTRL|ALT', action = act.ActivateTab(6) },
  { key = '7', mods = 'CTRL|ALT', action = act.ActivateTab(7) },
  { key = '8', mods = 'CTRL|ALT', action = act.ActivateTab(8) },
  { key = '9', mods = 'CTRL|ALT', action = act.ActivateTab(9) },
  { key = 'd', mods = 'CTRL|ALT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'CTRL|ALT|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'w', mods = 'CTRL|ALT', action = act.CloseCurrentTab { confirm = false } },
  { key = 's', mods = 'CTRL|ALT', action = wezterm.action_callback(show_workspaces) },
  { key = 'h', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'n', mods = 'CTRL|ALT', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  { key = 'N', mods = 'CTRL|ALT|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'p', mods = 'CTRL|ALT', action = wezterm.action_callback(show_tabs) },
  { key = ';', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Prev' },
  { key = 'o', mods = 'CTRL|ALT', action = act.TogglePaneZoomState },
  { key = 'f', mods = 'CTRL|ALT', action = act.Search { CaseSmartString = '' } },
  { key = 'r', mods = 'CTRL|ALT', action = rename_tab },
  { key = ':', mods = 'CTRL|ALT|SHIFT', action = act.ActivateCommandPalette },
}

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
  config.key_tables = { copy_mode = copy_mode }
end

wezterm.on('mux-startup', function()
  session.restore()
end)

wezterm.on('window-config-reloaded', function(window)
  session.save(window, false)
end)

wezterm.on('update-status', function(window)
  session.autosave(window)
  local leader = window:leader_is_active() and ' F1 ' or ''
  window:set_left_status(leader)
  window:set_right_status(' ' .. window:active_workspace() .. ' ')
end)

return config
