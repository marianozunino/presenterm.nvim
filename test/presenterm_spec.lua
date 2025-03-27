local presenterm = require('presenterm')
local stub = require('luassert.stub')

describe('presenterm.nvim', function()
  -- Helper to create a temporary file
  local function create_temp_file(content, extension)
    extension = extension or '.presenterm'
    local tmp_name = os.tmpname() .. extension
    local f = io.open(tmp_name, 'w')
    f:write(content)
    f:close()
    return tmp_name
  end

  -- Clean up after tests
  after_each(function()
    -- Reset config to defaults
    presenterm.config = {
      executable = 'presenterm',
      patterns = { '*.presenterm', '*.pterm', '*.md' },
      auto_launch = false,
      terminal_cmd = nil,
    }

    -- Clear running jobs
    presenterm.running_jobs = {}
  end)

  describe('is_presenterm_file()', function()
    it('detects presenterm extension', function()
      local file = create_temp_file('test content', '.presenterm')
      local result = presenterm.is_presenterm_file(file)
      assert.is_true(result)
      os.remove(file)
    end)

    it('detects pterm extension', function()
      local file = create_temp_file('test content', '.pterm')
      local result = presenterm.is_presenterm_file(file)
      assert.is_true(result)
      os.remove(file)
    end)

    it('detects markdown with slide separators', function()
      local content = '# Slide 1\n\n---\n\n# Slide 2'
      local file = create_temp_file(content, '.md')

      local result = presenterm.is_presenterm_file(file)
      assert.is_true(result)
      os.remove(file)
    end)

    it('detects markdown with presenter field', function()
      local file = create_temp_file('---\npresenter: John Doe\n---\n\n# Presentation', '.md')
      local result = presenterm.is_presenterm_file(file)
      assert.is_true(result)
      os.remove(file)
    end)

    it('ignores regular markdown files', function()
      local file = create_temp_file('# Just a regular markdown\n\nNothing special here.', '.md')
      local result = presenterm.is_presenterm_file(file)
      assert.is_false(result)
      os.remove(file)
    end)
  end)

  describe('launch_presenterm()', function()
    before_each(function()
      stub(vim.fn, 'jobstart').returns(12345)
      stub(vim.fn, 'shellescape').returns('escaped_path')
      stub(vim.fn, 'expand').returns('/path/to/file.presenterm')
      stub(vim.fn, 'filereadable').returns(1)
      stub(vim.fn, 'fnamemodify').returns('file.presenterm')
      stub(vim.fn, 'executable').returns(1)
      stub(vim, 'notify')
    end)

    after_each(function()
      -- Reset all the stubs
      vim.fn.jobstart:revert()
      vim.fn.shellescape:revert()
      vim.fn.expand:revert()
      vim.fn.filereadable:revert()
      vim.fn.fnamemodify:revert()
      vim.fn.executable:revert()
      vim.notify:revert()
    end)

    it('uses executable when provided', function()
      presenterm.config.executable = 'test-presenterm'
      presenterm.launch_presenterm()

      assert.stub(vim.fn.jobstart).was_called()
      local args = vim.fn.jobstart.calls[1].refs[1]
      assert.truthy(args:match('test%-presenterm'))
    end)

    it('works without executable', function()
      presenterm.config.executable = nil
      presenterm.launch_presenterm()

      assert.stub(vim.fn.jobstart).was_called()

      local args = vim.fn.jobstart.calls[1].refs[1]

      assert.truthy(args:match('escaped_path'))
    end)

    it('uses custom terminal command when provided', function()
      presenterm.config.terminal_cmd = 'custom-term -e {cmd}'
      presenterm.launch_presenterm()

      assert.stub(vim.fn.jobstart).was_called()
      local args = vim.fn.jobstart.calls[1].refs[1]
      assert.truthy(args:match('custom%-term %-e'))
    end)

    it('supports placeholders in custom terminal commands', function()
      presenterm.config.terminal_cmd = "tmux new-window '{cmd}' # {title} from {file}"
      presenterm.launch_presenterm()

      assert.stub(vim.fn.jobstart).was_called()
      local args = vim.fn.jobstart.calls[1].refs[1]
      assert.truthy(args:match('tmux new%-window'))
      assert.truthy(args:match('file%.presenterm from escaped_path'))
    end)
  end)

  describe('kill_all_processes()', function()
    it('attempts to kill all running jobs', function()
      stub(vim.fn, 'jobstop')
      stub(vim.fn, 'jobpid').returns(54321)
      stub(vim.fn, 'has').returns(1)
      stub(vim.fn, 'system')

      presenterm.running_jobs = {
        ['/path/to/file.presenterm'] = 12345,
      }

      presenterm.kill_all_processes()

      assert.stub(vim.fn.jobstop).was_called(1)
      assert.stub(vim.fn.jobstop).was_called_with(12345)

      assert.equals(0, #presenterm.running_jobs)

      vim.fn.jobstop:revert()
      vim.fn.jobpid:revert()
      vim.fn.has:revert()
      vim.fn.system:revert()
    end)
  end)
end)
