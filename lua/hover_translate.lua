local M = {}
local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util
local translator = require("translator")

-- Default configuration
M.config = {
	translator = {
		target_lang = "ja",
		provider = "google", -- "google" or "deepl"
		api_key = nil,
	},
	silent = false,
	hover_window = {}, -- options for vim.util.open_floating_preview()
}

-- Merge user config with validation
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

	translator.setup(M.config.translator)
end

-- Override hover to translate contents asynchronously
function M.hover(config)
	config = config or {}
	config.silent = M.config.silent
	config.hover_window = M.config.hover_window

	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if vim.tbl_isempty(clients) then
		if not config.silent then
			vim.notify("[hover-translate.nvim] No LSP client available", vim.log.levels.WARN)
		end
		return
	end

	local client = clients[1] -- TODO: refine client selection
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

	lsp.buf_request_all(0, "textDocument/hover", params, function(results, ctx)
		if api.nvim_get_current_buf() ~= ctx.bufnr then
			return
		end

		-- Collect first non-error hover content
		local raw = {}
		for _, resp in pairs(results) do
			if not resp.err and resp.result then
				raw = resp.result.contents
				break
			end
		end
		if vim.tbl_isempty(raw) then
			if not config.silent then
				vim.notify("[hover-translate.nvim] No hover information", vim.log.levels.WARN)
			end
			return
		end

		-- Convert to markdown text
		local lines = util.convert_input_to_markdown_lines(raw)
		local text = table.concat(lines, "\n")

		-- Async translate and then show floating
		translator.translate(text, function(translated)
			local tlines = vim.split(translated, "\n")
			local opts = vim.tbl_deep_extend("force", {
				focusable = true,
				focus_id = "hover-translate",
			}, config.hover_window or {})
			util.open_floating_preview(tlines, "markdown", opts)
		end)
	end)
end

return M
