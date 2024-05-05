local M = {}

M.config = {}

local output_bufnr = -1

local function open_buffer()
	local buffer_visible = vim.fn.bufwinnr(output_bufnr) ~= -1
	if output_bufnr == -1 or not buffer_visible then
		vim.cmd("botright split POSTGRES_RESULTS")
		output_bufnr = vim.api.nvim_get_current_buf()
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

	local url = M.config.databaseUrl.value
	vim.fn.jobstart({ "psql", url, "-c", query, "-P", "border=2" }, {
		stdout_buffered = true,
		on_stdout = append_to_buf,
		on_stderr = append_to_buf,
	})
end

local function get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = math.abs(s_end[2] - s_start[2]) + 1
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
	lines[1] = string.sub(lines[1], s_start[3], -1)
	if n_lines == 1 then
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
	else
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
	end
	return table.concat(lines, "\n")
end

M.execute_under_cursor = function()
	local text = get_visual_selection()
	local result = M.execute(text)
	print(result)
end

M.setup = function(opts)
	if opts then
		if opts.database_url then
			M.config.url = opts.database_url
		elseif opts.env_var then
			M.config.url = os.getenv(opts.env_var)
		end
	end
	vim.api.nvim_create_user_command("PgExecute", function()
		M.execute_under_cursor()
	end, {})
end

return M
