---@meta

--- Presenterm.lua: A Neovim plugin for Presenterm presentations
--- @author Mariano Zunino
--- @module 'presenterm'

local M = {}

--- Configuration options for the Presenterm plugin
--- @class PresentermConfig
--- @field executable string|nil Presenterm executable path (optional, default: "presenterm")
--- @field patterns string[] File patterns to recognize as Presenterm files
--- @field auto_launch boolean Automatically launch presentations when detected
--- @field terminal_cmd string|nil Custom terminal command with placeholders: {cmd}, {file}, {title}

--- Default configuration
--- @type PresentermConfig
M.config = {
  executable = 'presenterm', -- set to nil or "" to use only terminal_cmd
  patterns = {
    '*.presenterm',
    '*.pterm',
    '*.md',
  },
  auto_launch = false,
  terminal_cmd = nil,
}

--- Running jobs table to track launched presentations
--- @type table<string, number[]>
M.running_jobs = {}

--- Determines if a file is likely a Presenterm presentation
--- @param file_path string The path to the file to check
--- @return boolean is_presenterm Whether the file is a Presenterm presentation
function M.is_presenterm_file(file_path)
  for _, pattern in ipairs(M.config.patterns) do
    if file_path:match(pattern:gsub('*', '.*')) then
      if file_path:match('%.md$') then
        local file = io.open(file_path, 'r')
        if not file then
          return false
        end

        local content = file:read('*all')
        file:close()

        -- Check for presenter metadata
        if content:match('^%s*%-%-%-') and content:match('presenter:') then
          return true
        end

        -- Improved pattern for horizontal rules (slide separators)
        if
          content:match('\n%-%-%-\n')
          or content:match('\n%-%-%-%-+\n')
          or content:match('\n%%%s*\n')
        then
          return true
        end

        return false
      end
      return true
    end
  end
  return false
end

--- Launches a Presenterm presentation in an external terminal
--- @param file_path string|nil The path to the presentation file (optional, uses current buffer if nil)
function M.launch_presenterm(file_path)
  file_path = file_path or vim.fn.expand('%:p')

  if vim.fn.filereadable(file_path) == 0 then
    vim.notify("File doesn't exist or isn't readable", vim.log.levels.ERROR)
    return
  end

  local cmd = ''
  local term_cmd = ''
  local title = vim.fn.fnamemodify(file_path, ':t')

  -- Build command with executable if provided
  if M.config.executable and M.config.executable ~= '' then
    cmd = M.config.executable .. ' ' .. vim.fn.shellescape(file_path)
  else
    cmd = vim.fn.shellescape(file_path)
  end

  if M.config.terminal_cmd then
    term_cmd = M.config.terminal_cmd
    term_cmd = term_cmd:gsub('{cmd}', cmd)
    term_cmd = term_cmd:gsub('{file}', vim.fn.shellescape(file_path))
    term_cmd = term_cmd:gsub('{title}', title)
  else
    if vim.fn.executable('kitty') == 1 then
      term_cmd = "kitty --title 'Presenterm: " .. title .. "' " .. cmd
    elseif vim.fn.executable('alacritty') == 1 then
      term_cmd = 'alacritty -e ' .. cmd
    elseif vim.fn.executable('gnome-terminal') == 1 then
      term_cmd = 'gnome-terminal -- ' .. cmd
    elseif vim.fn.executable('konsole') == 1 then
      term_cmd = 'konsole -e ' .. cmd
    elseif vim.fn.executable('xterm') == 1 then
      term_cmd = 'xterm -e ' .. cmd
    elseif vim.fn.executable('cmd.exe') == 1 then
      term_cmd = 'cmd.exe /c start cmd.exe /c ' .. cmd
    elseif vim.fn.executable('open') == 1 then
      term_cmd = 'open -a Terminal.app ' .. cmd
    else
      vim.notify(
        'No supported terminal found. Please install a supported terminal or configure terminal_cmd.',
        vim.log.levels.ERROR
      )
      return
    end
  end

  local job_id = vim.fn.jobstart(term_cmd, { detach = true })
  if job_id > 0 then
    if not M.running_jobs[file_path] then
      M.running_jobs[file_path] = {}
    end
    table.insert(M.running_jobs[file_path], job_id)
    vim.notify('Launched Presenterm in external terminal', vim.log.levels.INFO)
  else
    vim.notify('Failed to launch external terminal', vim.log.levels.ERROR)
  end
end

--- Stop a specific Presenterm process or all processes for a file
--- @param file_path string|nil The path to the presentation file (optional, uses current buffer if nil)
--- @param job_index number|nil The specific job index to stop (optional, stops all jobs for the file if nil)
function M.stop_presenterm(file_path, job_index)
  file_path = file_path or vim.fn.expand('%:p')

  if not M.running_jobs[file_path] or #M.running_jobs[file_path] == 0 then
    vim.notify('No running presentations found for this file', vim.log.levels.INFO)
    return
  end

  if job_index and M.running_jobs[file_path][job_index] then
    local job_id = M.running_jobs[file_path][job_index]
    if M._stop_job(job_id) then
      table.remove(M.running_jobs[file_path], job_index)
      vim.notify('Stopped presentation instance ' .. job_index, vim.log.levels.INFO)
    end
  else
    local stop_count = 0
    for i = #M.running_jobs[file_path], 1, -1 do
      local job_id = M.running_jobs[file_path][i]
      if M._stop_job(job_id) then
        stop_count = stop_count + 1
        table.remove(M.running_jobs[file_path], i)
      end
    end

    if stop_count > 0 then
      vim.notify('Stopped ' .. stop_count .. ' presentation instances', vim.log.levels.INFO)
    else
      vim.notify('Failed to stop any presentation instances', vim.log.levels.WARN)
    end
  end

  if #M.running_jobs[file_path] == 0 then
    M.running_jobs[file_path] = nil
  end
end

--- Helper function to stop a single job
--- @param job_id number The job ID to stop
--- @return boolean success Whether the job was successfully stopped
function M._stop_job(job_id)
  if type(job_id) ~= 'number' or job_id <= 0 then
    return false
  end

  local pid
  local pid_success, _ = pcall(function()
    pid = vim.fn.jobpid(job_id)
  end)

  local success = pcall(vim.fn.jobstop, job_id)

  if pid_success and pid and pid > 0 then
    pcall(function()
      if vim.fn.has('unix') == 1 then
        vim.fn.system('pkill -P ' .. pid .. ' 2>/dev/null')
        vim.fn.system('kill -TERM ' .. pid .. ' 2>/dev/null')
      elseif vim.fn.has('win32') == 1 then
        vim.fn.system('taskkill /F /T /PID ' .. pid .. ' 2>nul')
      end
    end)
  end

  return success
end

--- Kills all running Presenterm processes
function M.kill_all_processes()
  local total_stopped = 0

  for _, jobs in pairs(M.running_jobs) do
    for _, job_id in ipairs(jobs) do
      if M._stop_job(job_id) then
        total_stopped = total_stopped + 1
      end
    end
  end

  M.running_jobs = {}

  if total_stopped > 0 then
    vim.notify('Stopped ' .. total_stopped .. ' presentation instances', vim.log.levels.INFO)
  end
end

--- List all running presentation instances
function M.list_presentations()
  local count = 0
  local output = {}

  for file_path, jobs in pairs(M.running_jobs) do
    local title = vim.fn.fnamemodify(file_path, ':t')
    table.insert(output, title .. ' (' .. file_path .. '):')

    for i, job_id in ipairs(jobs) do
      local pid
      pcall(function()
        pid = vim.fn.jobpid(job_id)
      end)
      table.insert(output, '  ' .. i .. '. Job ID: ' .. job_id .. (pid and ', PID: ' .. pid or ''))
      count = count + 1
    end
  end

  if count > 0 then
    vim.notify(
      'Running presentations (' .. count .. '):\n' .. table.concat(output, '\n'),
      vim.log.levels.INFO
    )
  else
    vim.notify('No running presentations', vim.log.levels.INFO)
  end
end

--- Sets up the Presenterm plugin with user configuration
--- @param user_config PresentermConfig|nil Custom user configuration (optional)
function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend('force', M.config, user_config)
  end

  vim.api.nvim_create_user_command('PresentermLaunch', function()
    M.launch_presenterm()
  end, {})

  vim.api.nvim_create_user_command('PresentermStop', function()
    M.stop_presenterm()
  end, {})

  vim.api.nvim_create_user_command('PresentermList', function()
    M.list_presentations()
  end, {})

  if M.config.auto_launch then
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
      pattern = M.config.patterns,
      callback = function(ev)
        local file_path = ev.match
        if file_path and M.is_presenterm_file(file_path) then
          vim.schedule(function()
            if M.config.auto_launch then
              M.launch_presenterm(file_path)
            else
              vim.notify('Presenterm file detected. Use :PresentermLaunch to start presentation.')
            end
          end)
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    callback = function()
      M.kill_all_processes()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufUnload' }, {
    pattern = '*',
    callback = function(ev)
      local file_path = ev.match
      if M.running_jobs[file_path] then
        M.stop_presenterm(file_path)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = { '*.presenterm', '*.pterm' },
    callback = function()
      vim.bo.filetype = 'markdown'
    end,
  })

  vim.filetype.add({
    extension = {
      presenterm = 'markdown',
      pterm = 'markdown',
    },
    filename = {},
    pattern = {},
  })
end

return M
