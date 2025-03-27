-- Minimal configuration for running tests
local plugin_path = vim.fn.expand('~/Dev/mzunino/presenterm.nvim')

-- Add the plugin to the runtimepath
vim.cmd('set rtp+=' .. plugin_path)

-- If you're using plenary for testing
local plenary_path = vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim')
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.cmd('set rtp+=' .. plenary_path)
end

-- This ensures package.path includes your plugin's lua directory
package.path = plugin_path .. '/lua/?.lua;' .. plugin_path .. '/lua/?/init.lua;' .. package.path
