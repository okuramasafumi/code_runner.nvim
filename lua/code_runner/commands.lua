-- Import options
local o = require("code_runner.options").get()

-- Create prefix for run commands
local prefix = string.format("%s %dsplit term://", o.term.position, o.term.size)

-- Replace json variables with vim variables in command.
-- If a command has no arguments, one is added with the current file path
-- @param command command to run the path
-- @param path absolute path
-- @return command with variables replaced by modifiers
local function re_jsonvar_with_vimvar(command, path)
  local no_sub_command = command

  command = command:gsub("$fileNameWithoutExt", vim.fn.fnamemodify(path, ":t:r"))
  command = command:gsub("$fileName", vim.fn.fnamemodify(path, ":t"))
  command = command:gsub("$file", path)
  command = command:gsub("$dir", vim.fn.fnamemodify(path, ":p:h"))

  if command == no_sub_command then
    command = command .. " " .. path
  end
  return command
end

-- Check if current buffer is in project
-- if a project return table of project
local function get_project_rootpath()
  local path = "%:p:~:h"
  local expand = ""
  while expand ~= "~" do
    expand = vim.fn.expand(path)
    local project = vim.g.projectManager[expand]
    if project then
      project["path"] = expand
      return project
    end
    path = path .. ":h"
  end
  return nil
end

-- Return a command for filetype
-- @param filetype filetype of path
-- @param path absolute path to file
-- @return command
local function get_command(filetype, path)
  local nvim_files = {
    lua = "luafile %",
    vim = "source %",
  }
  path = path or vim.fn.expand("%:p")
  local command = vim.g.fileCommands[filetype]
  if command then
    local command_vim = re_jsonvar_with_vimvar(command, path)
    return prefix .. command_vim
  end
  return nvim_files[filetype]
end

-- Run command in project context
local function run_project(context)
  local command = ""
  if context.file_name then
    local file = context.path .. "/" .. context.file_name
    if context.command then
      command = prefix .. re_jsonvar_with_vimvar(context.command, file)
    else
      local filetype = require'plenary.filetype'
      local current_filetype = filetype.detect_from_extension(file)
      command = get_command(current_filetype, file)
    end
  else
    command = prefix .. "cd " .. context.path .. " &&" .. context.command
  end
  vim.cmd(command)
end

local M = {}

-- Execute filetype or project
function M.run(...)
  local json_key_select = select(1,...)
  if json_key_select ~= "" then
    -- since we have reached here, means we have our command key
    local cmd_to_execute = get_command(json_key_select)
    vim.cmd(cmd_to_execute)
    return
  end

  --  procede here if no input arguments
  local is_a_project = M.run_project()
  if not is_a_project then
    M.run_filetype()
  end
end

-- Execute filetype
function M.run_filetype()
  local filetype = vim.bo.filetype
  local command = get_command(filetype) or ""
  vim.cmd(command)
end

-- Execute project
function M.run_project()
  local context = nil
  if vim.g.projectManager then
    context = get_project_rootpath()
  end
  if context then
    run_project(context)
    return true
  end
  return false
end

return M
