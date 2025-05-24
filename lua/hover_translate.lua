---@class hover_translate.Config
---@field translator? TranslatorOpts
---@field silent? boolean
---@field hover_window? vim.lsp.util.open_floating_preview.Opts

---@class TranslatorOpts
---@field target_lang? string
---@field provider? "google"|"deepl"
---@field api_key? string

local M = {}
local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util
local translator = require("translator")

---@class hover_translate.InternalConfig
M.config = {
	---@class hover_translate.TranslatorInternalConfig
	translator = {
		---@type string
		target_lang = "ja",

		---@type "google" | "deepl"
		provider = "google", -- "google" or "deepl"

		---@type string
		api_key = "",
	},

	---@type boolean
	silent = false,

	---@type vim.lsp.util.open_floating_preview.Opts
	hover_window = {},
}

---@param user_config hover_translate.Config
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

function M.hover()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if vim.tbl_isempty(clients) then
		if not M.config.silent then
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
			if not M.config.silent then
				vim.notify("[hover-translate.nvim] No hover information", vim.log.levels.WARN)
			end
			return
		end

		-- Convert to markdown text
		local lines = util.convert_input_to_markdown_lines(raw)
		local text = table.concat(lines, "\n")

		-- Async translate and then show floating
		translator.translate(text, M.config.translator, function(translated)
			local tlines = vim.split(translated, "\n")
			local opts = vim.tbl_deep_extend("force", {
				focusable = true,
				focus_id = "hover-translate",
			}, M.config.hover_window or {})
			util.open_floating_preview(tlines, "markdown", opts)
		end)
	end)
end

return M
