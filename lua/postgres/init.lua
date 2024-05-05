local M = {}

M.options = {}

local output_bufnr = -1

local function open_buffer()
	local buffer_visible = vim.fn.bufwinnr(output_bufnr) ~= -1
	if output_bufnr == -1 or not buffer_visible then
		vim.cmd("botright split POSTGRES_RESULTS")
		output_bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_option(output_bufnr, "buftype", "nofile")
		vim.opt_local.readonly = true
	end
end

local function clear_buf()
	vim.api.nvim_buf_set_option(output_bufnr, "readonly", false)
	vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, true, {})
	vim.api.nvim_buf_set_option(output_bufnr, "readonly", true)
end

local function append_to_buf(_, data)
	if data then
		vim.api.nvim_buf_set_option(output_bufnr, "readonly", false)
		vim.api.nvim_buf_set_lines(output_bufnr, -1, -1, true, data)
		vim.api.nvim_buf_set_option(output_bufnr, "readonly", true)
		vim.api.nvim_buf_set_option(output_bufnr, "modified", false)

		local win = vim.fn.bufwinnr(output_bufnr)
		local line_count = vim.api.nvim_buf_line_count(output_bufnr)
		vim.api.nvim_win_set_cursor(win, { line_count, 0 })
	end
end

M.execute = function(query)
	open_buffer()
	clear_buf()

	local url = M.options.url
	vim.fn.jobstart({ "psql", url, "-c", query, "-P", "border=2" }, {
		stdout_buffered = true,
		on_stdout = append_to_buf,
		on_stderr = append_to_buf,
	})
end

local function get_visual_selection()
	local oldreg = vim.fn.getreg("v")
	vim.cmd('noau normal! "vy')
	local visual_selection = vim.fn.getreg("v")
	vim.fn.setreg("v", oldreg)
	return visual_selection
end

M.execute_visual = function()
	local text = get_visual_selection()
	M.execute(text)
end

M.execute_current = function()
	local ts_utils = require("nvim-treesitter.ts_utils")
	local node = ts_utils.get_node_at_cursor()
	while node do
		if node:type() == "statement" then
			break
		end
		node = node:parent()
	end
	if not node then
		print("No query under cursor")
	end
	local nodetext = ts_utils.get_node_text(node)
	local text = table.concat(nodetext, "\n")
	M.execute(text)
end

M.setup = function(opts)
	if opts then
		if opts.database_url then
			M.options.url = opts.database_url
		elseif opts.env_var then
			M.options.url = os.getenv(opts.env_var)
		end
	end
	vim.api.nvim_create_user_command("PgExecute", function()
		if vim.fn.mode() == "v" then
			M.execute_visual()
		elseif vim.fn.mode() == "n" then
			M.execute_current()
		end
	end, {})
end

return M
